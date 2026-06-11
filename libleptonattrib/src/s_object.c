/* Lepton EDA attribute editor
 * Copyright (C) 2003-2010 Stuart D. Brorson.
 * Copyright (C) 2003-2016 gEDA Contributors
 * Copyright (C) 2017-2026 Lepton EDA Contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

/*------------------------------------------------------------------*/
/*! \file
 * \brief Functions for manipulating LeptonObjects.
 *
 * This file holds functions involved in manipulating the
 * LeptonObject data structure.  LeptonObject is defined in
 * liblepton.  An LeptonObject is a graphical primitive normally
 * used in lepton-schematic.  Example LeptonObjects: some text, a
 * component, a pin, a line, etc.
 *
 * The functions herein are functions which I wrote as wrappers to
 * the functions in liblepton.
 */

#include <config.h>

#include <stdio.h>
#ifdef HAVE_STRING_H
#include <string.h>
#endif
#include <math.h>

/*------------------------------------------------------------------
 * Gattrib specific includes
 *------------------------------------------------------------------*/
#include <liblepton/liblepton.h>
#include "../include/struct.h"     /* typdef and struct declarations */
#include "../include/prototype.h"  /* function prototypes */
#include "../include/globals.h"
#include "../include/gettext.h"


/*------------------------------------------------------------------
 * Gattrib specific defines
 *------------------------------------------------------------------*/
#define DEFAULT_TEXT_SIZE 10

/* ===================  Public Functions  ====================== */
/*------------------------------------------------------------------*/
/*! \brief Add a new attribute to an pin LeptonObject
 *
 * Add a new attribute to o_current, when o_current is a
 * pin.  It does it in the following
 * way:
 * -# It creates an object -- "attrib_graphic" -- and fills it in.
 * -# It gets the position info from o_current's refdes attrib and
 *    calls o_text_new() to add position info and name=value string
 *    to attrib_graphic.
 * -# It calls lepton_attrib_add() to wrap attrib_graphic with
 *    (attribute LeptonObject)
 * \param toplevel LeptonToplevel structure
 * \param o_current Pointer to pin object
 * \param new_attrib_name Name of attribute to add
 * \param new_attrib_value Value of attribute to add
 * \todo Do I really need separate fcns for comps, nets, and
 * pins???
 */
void
s_object_add_pin_attrib_to_object (LeptonToplevel *toplevel,
                                   LeptonObject *o_current,
                                   char *new_attrib_name,
                                   char *new_attrib_value)
{
  LeptonPage *active_page = NULL;
  char *name_value_pair;
  g_return_if_fail (o_current != NULL);

  active_page = lepton_toplevel_get_page_current (toplevel);

  /* One last sanity check */
  if (strlen(new_attrib_value) != 0) {
    name_value_pair = g_strconcat(new_attrib_name, "=", new_attrib_value, NULL);
    s_object_attrib_add_attrib_in_object (active_page,
                                          name_value_pair,
                                          INVISIBLE,
                                          SHOW_NAME_VALUE,
                                          o_current);
  }

  return;
}


/*------------------------------------------------------------------*/
/*!
 * \brief Remove attribute from object
 *
 * Remove an attribute from an object.
 * \param toplevel LeptonToplevel structure
 * \param o_current Object to remove attribute from
 * \param new_attrib_name Name of attribute to remove
 */
void
s_object_remove_attrib_in_object (LeptonToplevel *toplevel,
                                  LeptonObject *o_current,
                                  char *new_attrib_name)
{
  GList *a_iter;
  LeptonObject *a_current;
  LeptonObject *attribute_object;
  char *old_attrib_text;
  char *old_attrib_name;

  a_iter = lepton_object_get_attribs (o_current);
  while (a_iter != NULL) {
    a_current = (LeptonObject*) a_iter->data;
    if (lepton_object_is_text (a_current)
        && a_current->text != NULL) {  /* found an attribute */

      /* may need to check more thoroughly here. . . . */
      old_attrib_text = g_strdup (lepton_text_object_get_string (a_current));
      old_attrib_name = u_basic_breakup_string(old_attrib_text, '=', 0);

      if (strcmp(old_attrib_name, new_attrib_name) == 0) {
        /* We've found the attrib.  Delete it and then return. */

        g_debug ("s_object_remove_attrib_in_object: "
                 "Removing attrib with name = %1$s\n", old_attrib_name);

        attribute_object = a_current;
        s_object_delete_text_object_in_object (toplevel, attribute_object);

        g_free(old_attrib_text);
        g_free(old_attrib_name);
        return;     /* we are done -- leave. */
      }
    g_free(old_attrib_text);
    g_free(old_attrib_name);
    }
    a_iter = g_list_next (a_iter);
  }

  /* if we get here, it's because we have failed to find the attrib on the component.
   * This is an error condition. */
  fprintf (stderr, "s_object_remove_attrib_in_object: ");
  fprintf (stderr,
           _("Failed to find the attrib %1$s on the component.\n"),
           new_attrib_name);
  exit(-1);
}



/*------------------------------------------------------------------*/
/*! \brief Attach attribute to object.
 *
 * Attach the name=value pair to the LeptonObject "object". This function
 * was stolen from gschem/src/o_attrib.c:o_attrib_add_attrib and
 * hacked for gattrib.
 * \param active_page LeptonPage to operate on.
 * \param text_string
 * \param visibility
 * \param show_name_value
 * \param o_current
 * \returns pointer to the object
 * \todo Does it need to return LeptonObject?
 */
LeptonObject *
s_object_attrib_add_attrib_in_object (LeptonPage *active_page,
                                      char *text_string,
                                      int visibility,
                                      int show_name_value,
                                      LeptonObject * o_current)
{
  int world_x = -1, world_y = -1;
  int color;
  LeptonObject *new_obj;

  g_return_val_if_fail ((o_current != NULL), NULL);

  /* creating a toplevel or unattached attribute */
  /* get coordinates of where to place the text object */
  switch (lepton_object_get_type (o_current)) {
  case (OBJ_COMPONENT):
    world_x = lepton_component_object_get_x (o_current);
    world_y = lepton_component_object_get_y (o_current);
    color = ATTRIBUTE_COLOR;
    break;

  case (OBJ_NET):
    world_x = lepton_component_object_get_x (o_current);
    world_y = lepton_component_object_get_y (o_current);
    color = ATTRIBUTE_COLOR;
    break;

  default:
    fprintf (stderr, "s_object_attrib_add_attrib_in_object: ");
    fprintf (stderr, _("Trying to add attrib to non-component or non-net!\n"));
    exit(-1);
  }

  /* first create text item */
  g_debug ("s_object_attrib_add_attrib_in_object: "
           "About to attach new text attrib with properties:\n"
           "     color = %d\n"
           "     text_string = %s\n"
           "     visibility = %d\n"
           "     show_name_value = %d\n",
           color, text_string, visibility, show_name_value);

  new_obj = lepton_text_object_new (color,
                                    world_x,
                                    world_y,
                                    LOWER_LEFT,
                                    0, /* zero is angle */
                                    text_string,
                                    DEFAULT_TEXT_SIZE,
                                    visibility,
                                    show_name_value);
  lepton_page_append (active_page, new_obj);

  /* Now the current active page contains the new text item. */

  /* now attach the attribute to the object */
  /* remember that o_current contains the object to get the attribute */
  lepton_attrib_attach (new_obj, o_current, FALSE);

  lepton_page_set_changed (active_page, 1);

  return new_obj;
}




/*------------------------------------------------------------------*/
/*! \brief Delete text object
 *
 * Delete the text object pointed to by text_object.  This function
 * was shamelessly stolen from gschem/src/o_delete.c and hacked
 * for gattrib by SDB.
 * \param toplevel LeptonToplevel to be operated on.
 * \param text_object Text object to be deleted.
 */
void
s_object_delete_text_object_in_object (LeptonToplevel *toplevel,
                                       LeptonObject * text_object)
{
  LeptonPage *active_page = lepton_toplevel_get_page_current (toplevel);
  lepton_object_delete (text_object);
  lepton_page_set_changed (active_page, 1);
}
