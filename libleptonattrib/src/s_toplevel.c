/* Lepton EDA attribute editor
 * Copyright (C) 2003-2010 Stuart D. Brorson.
 * Copyright (C) 2003-2014 gEDA Contributors
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
 *  \brief Functions to manipulate the LeptonToplevel struct.
 *
 * This file holds functions involved in manipulating the LeptonToplevel data
 * structure.  LeptonToplevel is the data structure inherited from gEDA's
 * other programs, and holds all info about a project in a form
 * native to gEDA.
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
#include <liblepton/libleptonguile.h>
#include "../include/struct.h"     /* typdef and struct declarations */
#include "../include/prototype.h"  /* function prototypes */
#include "../include/globals.h"
#include "../include/gettext.h"


/*------------------------------------------------------------------*/
/*! \brief Get pin attributes
 *
 * This function takes a pointer to the LeptonObject pin, and
 * returns a list of attribs found attached to the pin.  The
 * returned list is a STRING_LIST where the ->data holds a
 * name=value string.
 * The algorithm is as follows:
 * -# Form refdes:pinnumber label for this pin.
 * -# Get row number of this refdes:pinnumber
 * -# Create a list of name=value pairs from entries in the pin_table
 *    on this row.
 * -# Return list of name=value pairs found.
 *
 * \param refdes Ref des string
 * \param pin Pin object
 * \returns name=value pair as a STRING_LIST
 */
STRING_LIST *s_toplevel_get_pin_attribs_in_sheet(char *refdes, LeptonObject *pin)
{
  STRING_LIST *new_attrib_list;
  STRING_LIST *local_attrib_list;
  int i;
  int row = -1;
  int count = 0;
  char *pinnumber;
  char *row_label;
  char *name_value_pair;
  char *new_attrib_value;
  char *new_attrib_name;

  g_debug ("==== Enter s_toplevel_get_pin_attribs_in_sheet()\n");

  /* First find pos of this pin in the master pin list */
  /* first convert refdes, pin to refdes:pinno text string. Then call table_get_index.  */

  pinnumber = lepton_attrib_search_object_attribs_by_name (pin, "pinnumber", 0);

  if ( (refdes != NULL) && (pinnumber != NULL) ) {
    row_label = g_strconcat(refdes, ":", pinnumber, NULL);
  } else {
    fprintf (stderr, "s_toplevel_get_pin_attribs_in_sheet: ");
    fprintf (stderr, _("Either refdes or pinnumber of object missing.\n"));
    return NULL;
  }
  row = s_table_get_index (attrib_sheet_data_get_pin_list (sheet_head), row_label);

  /* Sanity check */
  if (row == -1) {
    /* we didn't find the item in the list */
    fprintf (stderr, "s_toplevel_get_pin_attribs_in_sheet: ");
    fprintf (stderr, _("We didn't find the refdes:pin in the master list.\n"));
    return NULL;
  }

  /* Now get all attribs associated with this refdes (in TABLE, indexed
   * by position), and insert them into new_attrib_list.  */
  new_attrib_list = s_string_list_new();  /* init new_attrib_list */

  i = 0;
  local_attrib_list = attrib_sheet_data_get_pin_attrib_list (sheet_head);
  while (local_attrib_list != NULL) {  /* iterate over all possible attribs */
    new_attrib_name = g_strdup(local_attrib_list->data);  /* take attrib name from column headings */

    if (((attrib_sheet_data_get_pin_table (sheet_head))[row][i]).attrib_value)
    {
      new_attrib_value = g_strdup(((attrib_sheet_data_get_pin_table (sheet_head))[row][i]).attrib_value);
      name_value_pair = g_strconcat(new_attrib_name, "=", new_attrib_value, NULL);
      g_free(new_attrib_value);
    } else {
      name_value_pair = g_strconcat(new_attrib_name, "=", NULL);  /* empty attrib */
    }
    s_string_list_add_item(new_attrib_list, &count, name_value_pair);  /* add name=value to new list */
    g_free(new_attrib_name);
    g_free(name_value_pair);

    /* Sanity check */
    if (count != i+1) {
      /* for some reason, we have lost a name_value_pair somewhere . . .  */
      fprintf (stderr, "s_toplevel_get_pin_attribs_in_sheet: ");
      fprintf (stderr, "count != i.\n");
      exit(-1);
    }

    /* iterate */
    i++;
    local_attrib_list = local_attrib_list->next;
  } /* while (local_attrib_list != NULL)  */

  return new_attrib_list;
}



/*------------------------------------------------------------------*/
/*! \brief Update pin attributes in toplevel
 *
 * For each attrib string attached to the pin, update it using the value
 * held in new_pin_attrib_list.  Algorithm:
 * -# Loop over name=value pairs held in new_pin_attrib_list.
 * -# For each name=value pair, look for corresponding attrib on pin.
 * -# If the attrib exists on pin and in name=value pair, write the
 *    new value in.
 * -# If the attrib exists on pin, but is null in name=value pair,
 *    delete the attrib.
 * -# If the attribs doesn't exist on pin, but is non-null in
 *    the name=value pair, create an attrib object and add it to the pin.
 * \param toplevel LeptonToplevel structure
 * \param refdes Unused - needs refactored out
 * \param [in,out] o_pin pin to update
 * \param [in] new_pin_attrib_list New pin attribute list to apply
 */
void
s_toplevel_update_pin_attribs_in_toplevel (LeptonToplevel *toplevel,
                                           char *refdes,
                                           LeptonObject *o_pin,
                                           STRING_LIST *new_pin_attrib_list)
{
  STRING_LIST *local_list;
  char *new_name_value_pair;
  char *new_attrib_name;
  char *new_attrib_value;
  char *old_attrib_value;

  g_return_if_fail (o_pin != NULL);

  g_debug ("==== Enter s_toplevel_update_pin_attribs_in_toplevel()\n");

  /* loop on name=value pairs held in new_pin_attrib_list */
  local_list = new_pin_attrib_list;
  while (local_list != NULL) {
    new_name_value_pair = g_strdup(local_list->data);
    g_debug ("s_toplevel_update_pin_attribs_in_toplevel: "
             "Handling entry in master list %s.\n",
             new_name_value_pair);

  new_attrib_name = u_basic_breakup_string(new_name_value_pair, '=', 0);
  new_attrib_value = u_basic_breakup_string(new_name_value_pair, '=', 1);

  if (strlen(new_attrib_value) == 0) {
    g_free(new_attrib_value);
    new_attrib_value = NULL;  /* s_misc_remaining_string doesn't return NULL for empty substring. */
  }
  old_attrib_value = lepton_attrib_search_attached_attribs_by_name (o_pin,
                                                                    new_attrib_name,
                                                                    0);

    /* -------  Four cases to consider: Case 1: old and new attribs exist ----- */
    if ( (old_attrib_value != NULL) && (new_attrib_value != NULL) && (strlen(new_attrib_value) != 0) ) {
      /* simply write new attrib into place of old one. */
      g_debug ("s_toplevel_update_pin_attribs_in_toplevel: "
               "About to replace old attrib with new one: name= %s, value= %s\n",
               new_attrib_name,
               new_attrib_value);
      s_object_replace_attrib_in_object (o_pin,
                                         new_attrib_name,
                                         new_attrib_value,
                                         LEAVE_VISIBILITY_ALONE,
                                         LEAVE_NAME_VALUE_ALONE);
    }

    /* -------  Four cases to consider: Case 2: old attrib exists, new one doesn't ----- */
    else if ( (old_attrib_value != NULL) && (new_attrib_value == NULL) ) {
      /* remove attrib from pin */
      g_debug ("s_toplevel_update_pin_attribs_in_toplevel: "
               "About to remove old attrib with name= %s, value= %s\n",
               new_attrib_name,
               old_attrib_value);
      s_object_remove_attrib_in_object (toplevel, o_pin, new_attrib_name);
    }

    /* -------  Four cases to consider: Case 3: No old attrib, new one exists. ----- */
    else if ( (old_attrib_value == NULL) && (new_attrib_value != NULL) ) {
      /* add new attrib to pin. */

      g_debug ("s_toplevel_update_pin_attribs_in_toplevel: "
               "About to add new attrib with name= %s, value= %s\n",
               new_attrib_name,
               new_attrib_value);

      s_object_add_pin_attrib_to_object (toplevel,
                                         o_pin,
                                         new_attrib_name,
                                         new_attrib_value);

      /* -------  Four cases to consider: Case 4 ----- */
    } else {
      /* Do nothing. */
      g_debug ("s_toplevel_update_pin_attribs_in_toplevel: "
               "Nothing needs to be done.\n");
    }

    /* free everything and iterate */
    g_free(new_name_value_pair);
    g_free(new_attrib_name);
    g_free(new_attrib_value);
    g_free(old_attrib_value);
    local_list = local_list->next;
  }   /*   while (local_list != NULL)  */

  return;
}
