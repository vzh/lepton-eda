/* Lepton EDA library - Scheme API
 * Copyright (C) 2010-2011 Peter Brett <peter@peter-b.co.uk>
 * Copyright (C) 2010-2016 gEDA Contributors
 * Copyright (C) 2017-2021 Lepton EDA Contributors
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

/*!
 * \file scheme_attrib.c
 * \brief Scheme API attribute manipulation procedures.
 */

#include <config.h>

#include "liblepton_priv.h"
#include "libleptonguile_priv.h"

SCM_SYMBOL (attribute_format_sym, "attribute-format");

/*! \brief Parse an attribute text object into name and value strings.
 * \par Function Description
 * Tries to parse the underlying string of the text object \a text_s
 * into name and value strings.  If successful, returns a pair of the
 * form <tt>(name . value)</tt>.  Otherwise, raises an
 * <tt>attribute-format</tt> error.
 *
 * \note Scheme API: Implements the %attrib-parse procedure of the
 * (lepton core attrib) module.
 *
 * \param text_s text object to attempt to split.
 * \return name/value pair, or SCM_BOOL_F.
 */
SCM_DEFINE (parse_attrib, "%parse-attrib", 1, 0, 0,
            (SCM text_s), "Parse attribute name and value from text object.")
{
  gchar *name = NULL;
  gchar *value = NULL;
  SCM result = SCM_BOOL_F;

  SCM_ASSERT (edascm_is_object_type (text_s, OBJ_TEXT), text_s,
              SCM_ARG1, s_parse_attrib);

  LeptonObject *text = edascm_to_object (text_s);

  scm_dynwind_begin ((scm_t_dynwind_flags) 0);
  scm_dynwind_unwind_handler (g_free, name, SCM_F_WIND_EXPLICITLY);
  scm_dynwind_unwind_handler (g_free, value, SCM_F_WIND_EXPLICITLY);

  if (o_attrib_get_name_value (text, &name, &value)) {
    result = scm_cons (scm_from_utf8_string (name),
                       scm_from_utf8_string (value));
  } else {
    scm_error (attribute_format_sym, s_parse_attrib,
               _("~A is not a valid attribute: invalid string '~A'."),
               scm_list_2 (text_s,
                           scm_from_utf8_string (lepton_text_object_get_string (text))),
               SCM_EOL);
  }
  scm_dynwind_end ();

  return result;
}

/*! \brief Parse an attribute text object into a name string.
 * \par Function Description
 * Tries to parse the underlying string of the text object \a text_s
 * as an attribute, to obtain the attribute name.  If successful,
 * returns the name as a string.  Otherwise, raises an
 * <tt>attribute-format</tt> error.
 *
 * \note Scheme API: Implements the %attrib-name procedure of the
 * (lepton core attrib) module.
 *
 * \param text_s text object to parse
 * \return name, or SCM_BOOL_F.
 */
SCM_DEFINE (attrib_name, "%attrib-name", 1, 0, 0,
            (SCM text_s), "Parse attribute name from text object.")
{
  SCM_ASSERT (edascm_is_object_type (text_s, OBJ_TEXT), text_s,
              SCM_ARG1, s_attrib_name);

  LeptonObject *text = edascm_to_object (text_s);
  const gchar *name = o_attrib_get_name (text);

  if (!name) {
    scm_error (attribute_format_sym, s_parse_attrib,
               _("~A is not a valid attribute: invalid string '~A'."),
               scm_list_2 (text_s,
                           scm_from_utf8_string (lepton_text_object_get_string (text))),
               SCM_EOL);
  }

  return scm_from_utf8_string (name);
}

/*! \brief Get a list of an object's attributes.
 * \par Function Description
 * Retrieves the attributes of the smob \a obj_s as a Scheme list of
 * #LeptonObject smobs.
 *
 * \note Scheme API: Implements the %object-attribs procedure of the
 * (lepton core attrib) module.
 *
 * \param obj_s object to get attributes for.
 * \return a list of #LeptonObject smobs.
 */
SCM_DEFINE (object_attribs, "%object-attribs", 1, 0, 0,
            (SCM obj_s), "Get an object's attributes.")
{
  /* Ensure that the argument is an object */
  SCM_ASSERT (EDASCM_OBJECTP (obj_s), obj_s,
              SCM_ARG1, s_object_attribs);

  LeptonObject *obj = edascm_to_object (obj_s);

  return edascm_from_object_glist (obj->attribs);
}

/*! \brief Get the object that an attribute is attached to.
 * \par Function Description
 * Returns the #LeptonObject smob that \a attrib_s is attached to.  If \a
 * attrib_s is not attached as an attribute, returns SCM_BOOL_F.
 *
 * \note Scheme API: Implements the %attrib-attachment procedure of
 * the (lepton core attrib) module.
 *
 * \param attrib_s the object to get attribute attachment for.
 * \return the object to which \a attrib_s is attached, or SCM_BOOL_F.
 */
SCM_DEFINE (attrib_attachment, "%attrib-attachment", 1, 0, 0,
            (SCM attrib_s), "Get the object that an attribute is attached to.")
{
  /* Ensure that the argument is an object */
  SCM_ASSERT (EDASCM_OBJECTP (attrib_s), attrib_s,
              SCM_ARG1, s_attrib_attachment);

  LeptonObject *obj = edascm_to_object (attrib_s);

  if (obj->attached_to == NULL) {
    return SCM_BOOL_F;
  } else {
    return edascm_from_object (obj->attached_to);
  }
}

/*! \brief Attach an attribute to an object.
 * \par Function Description
 * Attach \a attrib_s to \a obj_s.  The following conditions must be
 * satisfied:
 *
 * - Neither \a obj_s nor \a attrib_s may be already attached as an
 *   attribute.
 * - Both \a obj_s and \a attrib_s must be part of the same page
 *   and/or component object. (They can't be "loose" objects).
 * - \a attrib_s must be a text object.
 *
 * These restrictions are intentionally harsher than those of the C
 * API, and are required in order to ensure that the Scheme API is
 * safe.
 *
 * If \a attrib_s is already attached to \a obj_s, does nothing
 * successfully.
 *
 * \note Scheme API: Implements the %attach-attrib! procedure of
 * the (lepton core attrib) module.
 *
 * \param obj_s the object to which to attach an attribute.
 * \param attrib_s the attribute to attach.
 * \return \a obj_s.
 */
SCM_DEFINE (attach_attrib_x, "%attach-attrib!", 2, 0, 0,
            (SCM obj_s, SCM attrib_s), "Attach an attribute to an object.")
{
  SCM_ASSERT (EDASCM_OBJECTP (obj_s), obj_s,
              SCM_ARG1, s_attach_attrib_x);
  SCM_ASSERT (edascm_is_object_type (attrib_s, OBJ_TEXT), attrib_s,
              SCM_ARG2, s_attach_attrib_x);

  LeptonObject *obj = edascm_to_object (obj_s);
  LeptonObject *attrib = edascm_to_object (attrib_s);

  /* Check that attachment doesn't already exist */
  if (attrib->attached_to == obj) return obj_s;

  /* Check that both are in the same page and/or component object */
  if ((obj->parent != attrib->parent)
      || (lepton_object_get_page (obj) != lepton_object_get_page (attrib))
      || ((obj->parent == NULL) && (lepton_object_get_page (obj) == NULL))) {
    scm_error (edascm_object_state_sym, s_attach_attrib_x,
               _("Objects ~A and ~A are not part of the same page and/or component object"),
               scm_list_2 (obj_s, attrib_s), SCM_EOL);
  }

  /* Check that neither is already an attached attribute */
  if (obj->attached_to != NULL) {
    scm_error (edascm_object_state_sym, s_attach_attrib_x,
               _("Object ~A is already attached as an attribute"),
               scm_list_1 (obj_s), SCM_EOL);
  }
  if (attrib->attached_to != NULL) {
    scm_error (edascm_object_state_sym, s_attach_attrib_x,
               _("Object ~A is already attached as an attribute"),
               scm_list_1 (attrib_s), SCM_EOL);
  }

  /* Carry out the attachment */
  lepton_object_emit_pre_change_notify (attrib);
  o_attrib_attach (attrib, obj, TRUE);
  lepton_object_emit_change_notify (attrib);

  lepton_object_page_set_changed (obj);

  scm_remember_upto_here_1 (attrib_s);
  return obj_s;
}

/*! \brief Detach an attribute from an object.
 * \par Function Description
 * Detach \a attrib_s from \a obj_s.  If \a attrib_s is not attached
 * as an attribute, does nothing silently.  If \a attrib_s is attached
 * as an attribute of an object other than \a obj_s, throws a Scheme
 * error.
 *
 * \note Scheme API: Implements the %detach-attrib! procedure of
 * the (lepton core attrib) module.
 *
 * \param obj_s the object from which to detach an attribute.
 * \param attrib_s the attribute to detach.
 * \return \a attrib_s.
 */
SCM_DEFINE (detach_attrib_x, "%detach-attrib!", 2, 0, 0,
            (SCM obj_s, SCM attrib_s), "Detach an attribute to an object.")
{
  SCM_ASSERT (EDASCM_OBJECTP (obj_s), obj_s,
              SCM_ARG1, s_detach_attrib_x);
  SCM_ASSERT (edascm_is_object_type (attrib_s, OBJ_TEXT), attrib_s,
              SCM_ARG2, s_detach_attrib_x);

  LeptonObject *obj = edascm_to_object (obj_s);
  LeptonObject *attrib = edascm_to_object (attrib_s);

  /* If attrib isn't attached, do nothing */
  if (attrib->attached_to == NULL) {
    return obj_s;
  }

  /* Check that attrib isn't attached elsewhere */
  if (attrib->attached_to != obj) {
    scm_error (edascm_object_state_sym, s_detach_attrib_x,
               _("Object ~A is attribute of wrong object"),
               scm_list_1 (attrib_s), SCM_EOL);
  }

  /* Detach object */
  lepton_object_emit_pre_change_notify (attrib);
  o_attrib_remove (&obj->attribs, attrib);
  lepton_object_set_color (attrib, DETACHED_ATTRIBUTE_COLOR);
  lepton_object_emit_change_notify (attrib);

  lepton_object_page_set_changed (obj);

  scm_remember_upto_here_1 (attrib_s);
  return obj_s;
}

/*! \brief Get a component object's promotable attribs.
 * \par Function Description
 * Returns the promotable attributes of \a component_s, according to the
 * current gEDA configuration.
 *
 * \param component_s the component object for which to get promotable
 *                    attributes.
 * \return a list of promotable attributes.
 */
SCM_DEFINE (promotable_attribs, "%promotable-attribs", 1, 0, 0,
            (SCM component_s), "Get a component's promotable attributes")
{
  SCM_ASSERT (edascm_is_object_type (component_s, OBJ_COMPONENT), component_s,
              SCM_ARG1, s_promotable_attribs);

  LeptonObject *obj = edascm_to_object (component_s);

  GList *lst = o_component_get_promotable (obj, FALSE);

  return edascm_from_object_glist (lst);
}


/*!
 * \brief Create the (lepton core attrib) Scheme module.
 * \par Function Description
 * Defines procedures in the (lepton core attrib) module. The module can
 * be accessed using (use-modules (lepton core attrib)).
 */
static void
init_module_lepton_core_attrib (void *unused)
{
  /* Register the functions */
  #include "scheme_attrib.x"

  /* Add them to the module's public definitions. */
  scm_c_export (s_parse_attrib, s_object_attribs, s_attrib_attachment,
                s_attach_attrib_x, s_detach_attrib_x,
                s_promotable_attribs, s_attrib_name,
                NULL);
}

/*!
 * \brief Initialise the basic gEDA attribute manipulation procedures.
 * \par Function Description
 * Registers some Scheme procedures for working with
 * attributes. Should only be called by edascm_init().
 */
void
edascm_init_attrib ()
{
  /* Define the (lepton core attrib) module */
  scm_c_define_module ("lepton core attrib",
                       (void (*)(void*)) init_module_lepton_core_attrib,
                       NULL);
}
