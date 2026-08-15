;;; Lepton EDA attribute editor
;;; Copyright (C) 2003-2010 Stuart D. Brorson.
;;; Copyright (C) 2005-2016 gEDA Contributors
;;; Copyright (C) 2017-2026 Lepton EDA Contributors
;;;
;;; This program is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, write to the Free Software
;;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

(use-modules (ice-9 format)
             (ice-9 getopt-long)
             (ice-9 receive)
             (rnrs bytevectors)
             (srfi srfi-1)
             (system foreign)

             (lepton attrib)
             (lepton config)
             (lepton ffi boolean)
             (lepton ffi glib)
             (lepton ffi gobject)
             (lepton ffi)
             (lepton file-system)
             (lepton init)
             (lepton log)
             (lepton page foreign)
             (lepton page)
             (lepton object foreign)
             (lepton object)
             (lepton rc)
             (lepton toplevel foreign)
             (lepton toplevel)
             (lepton version)

             (schematic ffi gtk)
             (schematic gtk geometry)
             (schematic gtk helper)

             (attrib ffi))


(define %program-basename (basename (car (program-arguments))))
(define %theme-icon-name "lepton-attrib")


;;; liblepton/include/liblepton/defines.h
(define LEAVE_NAME_VALUE_ALONE -1)
(define SHOW_NAME_VALUE 0)
(define SHOW_VALUE 1)
(define SHOW_NAME 2)

(define LEAVE_VISIBILITY_ALONE -1)
(define INVISIBLE 0)
(define VISIBLE 1)


;;; Consider using the configuration key schematic.gui::text-size
;;; instead.
;;; liblepton/include/liblepton/text_object.h:
(define DEFAULT_TEXT_SIZE 10)


;;; Initialize liblepton library.
(init-liblepton)


;;; Localization.
(define %textdomain "libleptonattrib")
(bindtextdomain %textdomain %lepton-localedir)
(textdomain %textdomain)
(bind-textdomain-codeset %textdomain "UTF-8")
(setlocale LC_ALL "")
(setlocale LC_NUMERIC "C")

(define (G_ msg) (gettext msg %textdomain))

(define (usage)
  (format #t
          (G_ "Usage: ~A [OPTIONS] FILE ...

~A: Lepton EDA attribute editor.
Presents schematic attributes in easy-to-edit spreadsheet format.

Options:
  -v, --verbose          Verbose mode on
  -V, --version          Show version information
  -h, --help             This help menu

Report bugs at ~S
Lepton EDA homepage: ~S
")
          %program-basename
          %program-basename
          (lepton-version-ref 'bugs)
          (lepton-version-ref 'url))

  (exit 0))


(define (report-unreadable filename)
  (format (current-error-port)
          "Could not open file ~S.\n"
          filename))


(define (process-gafrc* name)
  (process-gafrc "lepton-attrib" name))


;;; Verifies the entire design by looping through all objects in
;;; the design looking for missing components, that is, those
;;; components for which no corresponding symbol files was found.
(define (design-has-missing-symbols?)
  (define (missing-symbol? object)
    ;; Look for object, and verify that it has a symbol file
    ;; attached and signal that problem exists.
    (and (component? object)
         (true? (lepton_component_object_get_missing
                 (object->pointer object)))))

  (define (page-with-missing-symbol? page)
    (any missing-symbol? (page-contents page)))

  (any page-with-missing-symbol? (active-pages)))


(define (save-page page filename)
  "Saves PAGE under FILENAME returning #t on success, or #f on
failure."
  (define *page (check-page page 1))
  (true? (f_save *page (string->pointer filename) %null-pointer)))


;;; Saves all toplevel pages.
(define (save-pages)
  (define (save page)
    (let ((filename (page-filename page)))
      (if (save-page page filename)
          (begin
            (log! 'message (G_ "Saved ~S") filename)
            ;; Reset the changed state of page.
            (set-page-dirty! page #f))

          (log! 'message (G_ "Could NOT save ~S") filename))))

  (for-each save (active-pages)))


(define (show-name-value->symbol snv)
  (cond
   ((= snv SHOW_NAME_VALUE) 'both)
   ((= snv SHOW_NAME) 'name)
   ((= snv SHOW_VALUE) 'value)
   (else (error "Invalid text name/value visibility."))))


(define (visibility->symbol visible?)
  (if (= visible? VISIBLE) #t #f))


;;; Attaches an attribute produced from NAME-VALUE-PAIR to
;;; OBJECT applying the properties VISIBILITY and SHOW-NAME-VALUE
;;; to the attribute.
(define (add-object-attrib object
                           name-value-pair
                           visibility
                           show-name-value)
  ;; Choose position for a new object attrib.
  (define (attrib-position object)
    (cond
     ((component? object)
      (component-position object))
     ((or (net? object)
          (pin? object))
      (line-start object))
     (else (error "Object type is not supported: ~A"
                  (object-type object)))))

  (if (or (component? object)
          (net? object))
      ;; Creating a toplevel or unattached attribute.
      (let ((attrib
             (make-text (attrib-position object)
                        'lower-left
                        0
                        name-value-pair
                        DEFAULT_TEXT_SIZE
                        (visibility->symbol visibility)
                        (show-name-value->symbol show-name-value))))
        (page-append! (object-page object) attrib)
        ;; Attach the attribute to the object.
        (attach-attribs! object attrib)

        attrib)
      (error "Trying to add attrib to non-component or non-net.")))


;;; Searches for the instance of *NEW_ATTRIB_NAME on *OBJECT, and
;;; replaces its value with the *NEW_ATTRIB_VALUE.  The arguments
;;; VISIBILITY and SHOW-NAME-VALUE set the corresponding
;;; properties of the found attribute.
(define (replace-attrib *object
                        *new-attrib-name
                        *new-attrib-value
                        visibility
                        show-name-value)
  (let loop ((*attrib-ls
              (glist->list (lepton_object_get_attribs *object)
                           identity)))
    (if (null? *attrib-ls)
        (begin
          ;; If we get here, it's because we have failed to find
          ;; the attrib on the component.  This is an error
          ;; condition.
          (format (current-error-port) "replace-attrib: ")
          (format (current-error-port)
                  (G_ "Failed to find the attrib ~S on the component.\n")
                  (pointer->string *new-attrib-name))
          (exit -1))
        (let ((*attrib (car *attrib-ls)))
          (if (and (true? (lepton_object_is_text *attrib))
                   (not (null-pointer? (lepton_object_get_text *attrib))))
              ;; Found an attribute.
              (let* ((*old-attrib-text
                      (g_strdup (lepton_text_object_get_string *attrib)))
                     (*old-attrib-name
                      (u_basic_breakup_string *old-attrib-text
                                              (char->integer #\=)
                                              0)))
                (if (string= (pointer->string *old-attrib-name)
                             (pointer->string *new-attrib-name))
                    ;; Create attrib=value text string.
                    (let ((*new-attrib-text
                           (string->pointer
                            (string-append (pointer->string *new-attrib-name)
                                           "="
                                           (pointer->string *new-attrib-value)))))
                      (lepton_text_object_set_string *attrib *new-attrib-text)
                      (unless (= visibility LEAVE_VISIBILITY_ALONE)
                        (lepton_text_object_set_visibility *attrib visibility))
                      (unless (= show-name-value LEAVE_NAME_VALUE_ALONE)
                        (lepton_text_object_set_show *attrib show-name-value))
                      ;; We are done -- leave.
                      (g_free *old-attrib-text)
                      (g_free *old-attrib-name))
                    (begin
                      (g_free *old-attrib-text)
                      (g_free *old-attrib-name)
                      (loop (cdr *attrib-ls)))))
              (loop (cdr *attrib-ls)))))))


;; Remove an attribute with *ATTRIB-NAME from *OBJECT in
;; *TOPLEVEL.
(define (remove-attrib *toplevel *object *attrib-name)
  (let loop ((*attrib-ls
              (glist->list (lepton_object_get_attribs *object)
                           identity)))
    (if (null? *attrib-ls)
        (begin
          ;; If we get here, it's because we have failed to find
          ;; the attrib on the component.  This is an error
          ;; condition.
          (format (current-error-port) "remove-attrib(): ")
          (format (current-error-port)
                  (G_ "Failed to find the attrib ~S on the component.\n")
                  (pointer->string *attrib-name))
          (exit -1))
        (let ((*attrib (car *attrib-ls)))
          (if (and (true? (lepton_object_is_text *attrib))
                   (not (null-pointer? (lepton_object_get_text *attrib))))
              ;; Found an attribute.
              (let* ((*old-attrib-text
                      (g_strdup (lepton_text_object_get_string *attrib)))
                     (*old-attrib-name
                      (u_basic_breakup_string *old-attrib-text
                                              (char->integer #\=)
                                              0)))
                (if (string= (pointer->string *old-attrib-name)
                             (pointer->string *attrib-name))
                    ;; We've found the attrib.  Delete it and then
                    ;; return.
                    (let ((*active-page
                           (lepton_toplevel_get_page_current *toplevel)))
                      (lepton_object_delete *attrib)
                      (lepton_page_set_changed *active-page 1)
                      ;; We are done -- leave.
                      (g_free *old-attrib-text)
                      (g_free *old-attrib-name))
                    (begin
                      (g_free *old-attrib-text)
                      (g_free *old-attrib-name)
                      (loop (cdr *attrib-ls)))))

              (loop (cdr *attrib-ls)))))))

;;; Updates *OBJECT component attributes in *TOPLEVEL using the
;;; value held in the list of name=value attribute pairs
;;; *NEW-COMPONENT-ATTRIB-LIST.
;;;
;;; For each attrib string attached to the component, update it
;;; using the value held in *NEW-COMPONENT-ATTRIB-LIST.
;;; Algorithm:
;;; - Form list of all component attribs held on both the component
;;;    (*OBJECT), as well as in the attrib list of sheet data.
;;; - Loop over name=value pairs held in
;;;   *complete-component-attrib-list.
;;; - For each name=value pair, look for corresponding attrib on
;;;   *OBJECT.
;;; - For each name=value pair, look for the corresponding attrib
;;;   in *new-component-attrib-list.
;;; - If the attrib exists on *OBJECT and in
;;;   *NEW-COMPONENT-ATTRIB-PAIR-LIST, write the new value (from
;;;   *NEW-COMPONENT-ATTRIB-PAIR-LIST) into *OBJECT.
;;; - If the attrib exists on *OBJECT, but is NULL in name=value
;;;   pair, delete the attrib from *OBJECT .
;;; - If the attribs doesn't exist on *OBJECT, but is non-NULL in
;;;   the name=value pair, create an attrib object and add it to
;;;   the part on *OBJECT.
(define (update-component-attribs *toplevel
                                  *object
                                  *new-component-attrib-pair-list)
  (define *sheet-data (attrib_get_sheet_data))
  ;; To remove dead attribs from an object, we need to form a
  ;; complete list of unique attribs by taking the union of the
  ;; new attribs from the sheet data, and the old attribs living
  ;; on the object.  That's what we're doing here.  Later, we can
  ;; delete those attribs in the object which don't appear in
  ;; *new-component-attrib-pair-list.

  ;; First duplicate the list.
  (define *complete-component-attrib-list
    (s_string_list_duplicate_string_list *new-component-attrib-pair-list))
  ;; This is to fake out a function called later.
  (define *count (bytevector->pointer (make-bytevector (sizeof int) 0)))

  (when (null-pointer? *object)
    (error "NULL object."))

  ;; Now create a complete list of unique attribute names.  This
  ;; will be used in the loop below when updating attributes.
  (for-each
   (lambda (*attrib)
     (when (and (true? (lepton_object_is_text *attrib))
                (not (null-pointer? (lepton_object_get_text *attrib))))
       (let* ((*old-name-value-pair
               (g_strdup (lepton_text_object_get_string *attrib)))
              (*old-attrib-name
               (u_basic_breakup_string *old-name-value-pair
                                       (char->integer #\=)
                                       0))
              (old-attrib-name (if (null-pointer? *old-attrib-name)
                                   ""
                                   (pointer->string *old-attrib-name))))
         ;; Found a name=value attribute pair.

         ;; Don't put "refdes" or "slot" into list.
         ;; Don't put old name=value pair into list if a
         ;; new one is already in there.
         (when (and (not (string= old-attrib-name "refdes"))
                    (not (string= old-attrib-name "net"))
                    (not (string= old-attrib-name "slot"))
                    (false? (s_attrib_name_in_list
                             *new-component-attrib-pair-list
                             *old-attrib-name)))
           (s_string_list_add_item *complete-component-attrib-list
                                   *count
                                   *old-name-value-pair))

         (g_free *old-name-value-pair)
         (g_free *old-attrib-name))))
   (glist->list (lepton_object_get_attribs *object) identity))

  ;; Now the main business of this function: updating the attribs
  ;; attached to this object.  Loop on name=value pairs held in
  ;; *complete-component-attrib-list, and then use this to get the
  ;; name=value pairs out of *new-component-attrib-pair-list and
  ;; from object.

  ;; First handle a special case: the component has no attribs
  ;; (beside refdes).
  (unless (null-pointer?
           (attrib_string_list_get_data *complete-component-attrib-list))
    ;; Now the normal case.
    (let loop ((*local-list *complete-component-attrib-list))
      (unless (null-pointer? *local-list)
        ;; Now get the old attrib name & value from
        ;; *complete-component-attrib-list and value from object.
        (let* ((*old-attrib-name
                (u_basic_breakup_string
                 (attrib_string_list_get_data *local-list)
                 (char->integer #\=)
                 0))
               (*old-attrib-value
                (lepton_attrib_search_attached_attribs_by_name
                 *object
                 *old-attrib-name
                 0))
               ;; Next try to get this attrib from
               ;; *new-component-attrib-list.
               (*new-attrib-name
                (u_basic_breakup_string
                 (attrib_string_list_get_data *local-list)
                 (char->integer #\=)
                 0))
               ;; Now get row and column where this new attrib
               ;; lives.  Then get visibility of the new attrib
               ;; stored in the component table We'll need this
               ;; later.
               (*refdes (g_strdup (s_attrib_get_refdes *object)))
               (row (s_table_get_index
                     (attrib_sheet_data_get_component_list
                      *sheet-data)
                     *refdes))
               (column (s_table_get_index
                        (attrib_sheet_data_get_component_attrib_list
                         *sheet-data)
                        *new-attrib-name))
               (*new-attrib-value
                ;; If attribute has been deleted from the sheet,
                ;; here is where we detect that.  The attrib will
                ;; be deleted below.
                (if (or (= row -1)
                        (= column -1))
                    %null-pointer
                    (if (true? (s_string_list_in_list
                                *new-component-attrib-pair-list
                                (attrib_string_list_get_data
                                 *local-list)))
                        (s_misc_remaining_string
                         (attrib_string_list_get_data *local-list)
                         (char->integer #\=)
                         1)
                        %null-pointer)))
               ;; We need a better place to get this info since the
               ;; TABLE can be out of date.
               (visibility
                (if (null-pointer? *new-attrib-value)
                    0
                    (attrib_table_get_visibility
                     (attrib_sheet_data_get_component_table *sheet-data)
                     row
                     column)))
               (show-name-value
                (if (null-pointer? *new-attrib-value)
                    0
                    (attrib_table_get_show_name_value
                     (attrib_sheet_data_get_component_table *sheet-data)
                     row
                     column))))
          (g_free *refdes)

          ;; Four cases to consider: Case 1.
          (if (and (not (null-pointer? *old-attrib-value))
                   (not (null-pointer? *new-attrib-value))
                   (not (string-null? (pointer->string *new-attrib-value))))
              ;; simply write new attrib into place of old one.
              (replace-attrib *object
                              *new-attrib-name
                              *new-attrib-value
                              visibility
                              show-name-value)

              ;; Four cases to consider: Case 2.
              (if (and (not (null-pointer? *old-attrib-value))
                       (null-pointer? *new-attrib-value))
                  ;; Remove attrib from component.
                  (remove-attrib *toplevel *object *old-attrib-name)
                  ;; Four cases to consider: Case 3.
                  (if (and (null-pointer? *old-attrib-value)
                           (not (null-pointer? *new-attrib-value))
                           ;; One last sanity check, then add attrib.
                           (not (string-null? (pointer->string *new-attrib-value))))
                      ;; Add new attrib to component.
                      (let ((name-value-pair
                             (string-append (pointer->string *new-attrib-name)
                                            "="
                                            (pointer->string *new-attrib-value))))
                        (add-object-attrib (pointer->object *object)
                                           name-value-pair
                                           visibility
                                           show-name-value))
                      ;; Four cases to consider: Case 4.
                      (begin
                        ;; Do nothing.
                        #f))))

          ;; Toggle attribute visibility and name/value setting.

          ;; free everything and iterate
          (g_free *new-attrib-name)
          (g_free *new-attrib-value)
          (g_free *old-attrib-name)
          (g_free *old-attrib-value)
          (loop (attrib_string_list_get_next *local-list)))))))


(define (update-design-components *toplevel *page)
  (define *sheet-data (attrib_get_sheet_data))
  ;; Work from a copy list, as objects can be deleted from the
  ;; list during iteration over the list.
  (define *copy-list (g_list_copy (lepton_page_objects *page)))

  (for-each
   (lambda (*object)
     ;; Object is a component.  Handle component attributes.
     (when (true? (lepton_object_is_component *object))
       (let ((*graphical
              (lepton_attrib_search_object_attribs_by_name
               *object
               (string->pointer "graphical")
               0)))
         (if (not (null-pointer? *graphical))
             ;; Ignore graphical components.
             (g_free *graphical)

             (let ((*temp-uref (s_attrib_get_refdes *object)))
               (if (not (null-pointer? *temp-uref))
                   (let ((*new-component-attrib-pair-list
                          (s_table_create_attrib_pair
                           *temp-uref
                           (attrib_sheet_data_get_component_table *sheet-data)
                           (attrib_sheet_data_get_component_list *sheet-data)
                           (attrib_sheet_data_get_component_attrib_count *sheet-data))))
                     ;; Must create a name=value pair list for
                     ;; each particular component which we can
                     ;; pass to function updating *OBJECT.  This
                     ;; function places all attribs found in the
                     ;; row into *new-component-attrib-pair-list.

                     ;; Now update attribs in toplevel using this
                     ;; list.
                     (update-component-attribs
                      *toplevel
                      *object
                      *new-component-attrib-pair-list)

                     (g_free *temp-uref))

                   (log! 'debug
                         "update-design(): Found component with no refdes. id = ~A"
                         (lepton_object_get_id *object))))))))

   ;; Iterate backwards since attributes are attached after their
   ;; parent objects in the list. Attributes can get deleted
   ;; during the iteration.
   (reverse (glist->list *copy-list identity)))

  (g_list_free *copy-list))


(define (update-design-nets *toplevel *page)
  ;; Not implemented yet.
  #f)



;;; Returns a list of attributes attached to *PIN of the component
;;; with reference designator *REFDES.  The returned list is a
;;; STRING_LIST where the data holds a name=value string.
;;; The algorithm is as follows:
;;; - Form refdes:pinnumber label for this pin.
;;; - Get row number of this refdes:pinnumber
;;; - Create a list of name=value pairs from entries in the
;;;   pin table on this row.
;;; - Return list of name=value pairs found.
(define (pin->pin-attrib-list *refdes *pin)
  (define *sheet-data (attrib_get_sheet_data))
  (define count-bv (make-bytevector (sizeof int) 0))
  (define *count (bytevector->pointer count-bv))
  (define *pinnumber
    (lepton_attrib_search_object_attribs_by_name
     *pin
     (string->pointer "pinnumber")
     0))

  ;; First find position of this pin in the master pin list.

  ;; First convert refdes-pin pair to 'refdes:pinnumber' text
  ;; string. Then call s_table_get_index().
  (if (and (not (null-pointer? *refdes))
           (not (null-pointer? *pinnumber)) )
      (let* ((*row-label
              (string->pointer
               (string-append (pointer->string *refdes)
                              ":"
                              (pointer->string *pinnumber))))
             (row (s_table_get_index
                   (attrib_sheet_data_get_pin_list *sheet-data)
                   *row-label)))

        ;; Sanity check.
        (if (= row -1)
            (begin
              ;; We didn't find the item in the list.
              (format (current-error-port) "pin->pin-attrib-list(): ")
              (format (current-error-port)
                      (G_ "We didn't find the refdes:pin in the master list.\n"))
              %null-pointer)

            ;; Now get all attribs associated with this refdes
            ;; (in TABLE, indexed by position), and insert them
            ;; into new attrib list.

            ;; Init the new attrib list.
            (let loop ((*new-attrib-list (s_string_list_new))
                       (i 0)
                       (*local-attrib-list
                        (attrib_sheet_data_get_pin_attrib_list *sheet-data)))
              (if (null-pointer? *local-attrib-list)
                  *new-attrib-list

                  ;; Iterate over all possible attribs.  Take
                  ;; attrib name from column headings.
                  (let* ((new-attrib-name
                          (pointer->string
                           (attrib_string_list_get_data *local-attrib-list)))
                         (*table-value
                          (attrib_table_get_attrib_value
                           (attrib_sheet_data_get_pin_table *sheet-data) row i))
                         (new-attrib-value
                          (if (not (null-pointer? *table-value))
                              (pointer->string *table-value)
                              ;; Empty attrib.
                              ""))
                         (name-value-pair
                          (string-append new-attrib-name "=" new-attrib-value))
                         (*name-value-pair (string->pointer name-value-pair)))

                    ;; Add name=value to the new list.
                    (s_string_list_add_item *new-attrib-list *count *name-value-pair)

                    ;; Sanity check
                    (let ((count (bytevector-sint-ref count-bv 0 (native-endianness) (sizeof int))))
                      (if (not (= count (1+ i)))
                          (begin
                            ;; For some reason, we have lost a
                            ;; *name-value-pair somewhere...
                            (format (current-error-port) "pin->pin-attrib-list(): ")
                            (format (current-error-port) "count != i.\n")
                            (exit -1))

                          ;; Iterate.
                          (loop *new-attrib-list
                                (1+ i)
                                (attrib_string_list_get_next *local-attrib-list)))))))))

      (begin
        (format (current-error-port) "pin->pin-attrib-list(): ")
        (format (current-error-port)
                (G_ "Either refdes or pinnumber of object missing.\n"))
        %null-pointer)))


;;; Updates attributes of *PIN in *TOPLEVEL using new
;;; *PIN-ATTRIB-LIST.  The *REFDES argument is unused.
;;;
;;; For each attrib string attached to the pin, the function
;;; updates it using the value held in new_pin_attrib_list.
;;; Algorithm:
;;; - Loop over name=value pairs held in new *PIN-ATTRIB-LIST.
;;; - For each name=value pair, look for corresponding attrib on
;;;   *PIN.
;;; - If the attrib exists on pin and in name=value pair, write
;;;   the new value in.
;;; - If the attrib exists on pin, but is NULL in name=value pair,
;;;   delete the attrib.
;;; - If the attrib doesn't exist on pin, but is non-NULL in the
;;;   name=value pair, create an attrib object and add it to the
;;;   pin.
(define (update-pin-attribs *toplevel *refdes *pin *pin-attrib-list)
  (when (null-pointer? *pin)
    (error "NULL pin."))

  ;; Loop on name=value pairs held in the pin attrib list.
  (let loop ((*local-list *pin-attrib-list))
    (unless (null-pointer? *local-list)
      (let* ((*new-name-value-pair
              (g_strdup (attrib_string_list_get_data *local-list)))
             (*new-attrib-name
              (u_basic_breakup_string *new-name-value-pair
                                      (char->integer #\=)
                                      0))
             (*value (u_basic_breakup_string *new-name-value-pair
                                             (char->integer #\=)
                                             1))
             (*new-attrib-value
              (if (or (null-pointer? *value)
                      (string-null? (pointer->string *value)))
                  (begin
                    (g_free *value)
                    ;; s_misc_remaining_string() doesn't return
                    ;; NULL for empty substring.
                    %null-pointer)
                  *value))
             (*old-attrib-value
              (lepton_attrib_search_attached_attribs_by_name
               *pin
               *new-attrib-name
               0)))
        ;; Four cases to consider: Case 1: old and new attribs exist
        (if (and (not (null-pointer? *old-attrib-value))
                 (not (null-pointer? *new-attrib-value))
                 (not (string-null? (pointer->string *new-attrib-value))))
            ;; Simply write new attrib into place of old one.
            (replace-attrib *pin
                            *new-attrib-name
                            *new-attrib-value
                            LEAVE_VISIBILITY_ALONE
                            LEAVE_NAME_VALUE_ALONE)
            ;; Four cases to consider: Case 2: old attrib exists, new one
            ;; doesn't.
            (if (and (not (null-pointer? *old-attrib-value))
                     (null-pointer? *new-attrib-value))
                ;; Remove attrib from pin.
                (remove-attrib *toplevel *pin *new-attrib-name)
                ;; Four cases to consider: Case 3: No old attrib, new one
                ;; exists.
                (if (and (null-pointer? *old-attrib-value)
                         (not (null-pointer? *new-attrib-value))
                         ;; One last sanity check.
                         (not (string-null? (pointer->string *new-attrib-value))))
                    ;; Add new attrib to pin.
                    (let ((name-value-pair
                           (string-append (pointer->string *new-attrib-name)
                                          "="
                                          (pointer->string *new-attrib-value))))
                      (add-object-attrib (pointer->object *pin)
                                         name-value-pair
                                         INVISIBLE
                                         SHOW_NAME_VALUE))
                    ;; Four cases to consider: Case 4
                    ;; Do nothing.
                    #f)))

        ;; Free everything and iterate.
        (g_free *new-name-value-pair)
        (g_free *new-attrib-name)
        (g_free *new-attrib-value)
        (g_free *old-attrib-value)
        (loop (attrib_string_list_get_next *local-list))))))


(define (update-design-pins *toplevel *page)
  (define *sheet-data (attrib_get_sheet_data))
  ;; Work from a copy list in case objects are deleted from the
  ;; list during its iteration.
  (define *copy-list (g_list_copy (lepton_page_objects *page)))

  (for-each
   (lambda (*object)
     ;; Object is a component.  Handle pins by looking for all
     ;; pins attached to a component.
     (when (true? (lepton_object_is_component *object))
       ;;  Upon finding a component, here's what to do:
       ;;  0.  Get refdes of component.
       ;;  1.  Loop over primitive objects, looking for pins.
       ;;  2.  When a pin is found, create refdes:pinnumber pair
       ;;      used in searching TABLE.
       ;;  3.  Search TABLE using refdes:pinnumber as key, and get
       ;;      list of attribs corresponding to this
       ;;      refdes:pinnumber
       ;;  4.  Stick the attribs into the LeptonToplevel data
       ;;      structure.
       (let ((*temp-uref (s_attrib_get_refdes *object)))
         ;; Make sure object component has a refdes.
         (unless (null-pointer? *temp-uref)
           (for-each
            (lambda (*component-primitive-object)
              (when (true? (lepton_object_is_pin *component-primitive-object))
                (let ((*new-pin-attrib-list
                       (pin->pin-attrib-list *temp-uref
                                             *component-primitive-object)))
                  (update-pin-attribs
                   *toplevel
                   *temp-uref
                   *component-primitive-object
                   *new-pin-attrib-list))))
            (glist->list (lepton_component_object_get_contents *object)
                         identity)))

         (g_free *temp-uref))))
   (reverse (glist->list *copy-list identity)))

  (g_list_free *copy-list))


;;; Copies sheet data content to *PAGE of *TOPLEVEL.
;;;
;;; This function loops through all objects on *PAGE It takes the
;;; updated sheet data table and then updates the objects with the
;;; new attribs and attrib values.  For each component, it updates
;;; the attached attrib values using the updated values held in
;;; the sheet data table structure.  It does so in three steps:
;;; - First find and update component attribs.
;;; - Then find and update net attribs.
;;; - Finally find and update pin attribs.
(define (update-design *toplevel *page)
  ;; First deal with all components on the page.
  (update-design-components *toplevel *page)
  ;; Next deal with all nets on the page.
  (update-design-nets *toplevel *page)
  ;; Finally deal with all pins on the page.
  (update-design-pins *toplevel *page))


;;; Copies data from gtksheet into LeptonToplevel struct.  The
;;; function is called when the user invokes File -> Save.  It
;;; first places all data from gtksheet into SHEET_DATA.  Then it
;;; loops through all pages and saves them.
(define (save-sheet)
  (define *toplevel (attrib_get_toplevel))

  (when (null-pointer? *toplevel)
    (error "NULL toplevel."))

  ;; Extract the attribs from the gtksheet widget cells, and place
  ;; them back into SHEET_DATA.
  (s_table_gtksheet_to_all_tables)

  ;; Iterate over all pages in design.
  (for-each
   (lambda (*page)
     ;; Only traverse pages which are toplevel.
     (when (zero? (lepton_page_get_page_control *page))
       ;; Add all objects from page.
       (update-design *toplevel *page)))
   (glist->list
    (lepton_list_get_glist (lepton_toplevel_get_pages *toplevel))
    identity))

  ;; Save all pages in design.
  (save-pages)
  (s_sheet_data_set_changed (attrib_get_sheet_data) FALSE))


(define (callback-file-save *action *parameter *data)
  (save-sheet))
(define *callback-file-save
  (procedure->pointer void callback-file-save '(* * *)))


(define gtk_file_chooser_dialog_new_8
  (let ((proc (delay (pointer->procedure
                      '*
                      (dynamic-func "gtk_file_chooser_dialog_new" libgtk)
                      (list '* '* int '* int '* int '*)))))
    (force proc)))

(define gtk_file_chooser_dialog_new
  (case-lambda
    ((*title *parent action *button-text1 response1 *button-text2 response2 end)
     (gtk_file_chooser_dialog_new_8 *title
                                    *parent
                                    action
                                    *button-text1
                                    response1
                                    *button-text2
                                    response2
                                    %null-pointer))))


;;; Export design components to CSV for external processing.
(define (export-components)
  (define *sheet-data (attrib_get_sheet_data))
  (define rows-number
    (attrib_sheet_data_get_component_count *sheet-data))
  (define columns-number
    (attrib_sheet_data_get_component_attrib_count *sheet-data))
  (define *component-table
    (attrib_sheet_data_get_component_table *sheet-data))

  (define (id->attrib-name id)
    (pointer->string
     (s_string_list_get_data_at_index
      (attrib_sheet_data_get_component_attrib_list
       *sheet-data)
      id)))

  (define (id->component-refdes id)
    (pointer->string
     (s_string_list_get_data_at_index
      (attrib_sheet_data_get_component_list *sheet-data)
      id)))

  (define (ids->attrib-value i j)
    (define *val
      (attrib_table_get_attrib_value *component-table i j))
    (if (null-pointer? *val)
        ""
        ;; Found a string.  Make a copy of the text, escaping any
        ;; special chars, like double quotes.
        (let* ((*text (g_strescape *val (string->pointer "")))
               (text (pointer->string *text)))
          (g_free *text)
          ;; If there's a comma anywhere in the field, wrap the
          ;; field in double quotes.
          (if (string-any #\, text)
              (string-append "\"" text "\"")
              text))))

  (define (list->record ls)
    (string-join ls ", " 'infix))

  ;; Export the contents of the sheet.
  (display
   (string-join
    (map list->record
         (cons
          ;; Make a list of attribute names.  "refdes" is always
          ;; the first column.
          (cons "refdes"
                (map id->attrib-name (iota columns-number)))
          (map (lambda (i)
                 ;; Export the component refdes.
                 (cons (id->component-refdes i)
                       (map
                        ;; Export the attrib values.
                        (lambda (j) (ids->attrib-value i j))
                        (iota columns-number))))
               (iota rows-number))))
    "\n"
    'suffix)))


;;; Runs the Export file dialog.  It asks for the filename for the
;;; CSV export file and then does the exporting.
(define (export-file-dialog)
  (define *dialog
    (gtk_file_chooser_dialog_new
     (string->pointer (G_ "Export CSV"))
     %null-pointer
     (symbol->gtk-file-chooser-action 'save)
     (string->pointer (G_ "_Cancel"))
     GTK_RESPONSE_CANCEL
     (string->pointer (G_ "_Save"))
     GTK_RESPONSE_ACCEPT
     %null-pointer))

  ;; Check that we are on the component page.
  (define current-page-id
    (gtk_notebook_get_current_page (attrib_get_notebook)))

  (gtk_dialog_set_default_response *dialog GTK_RESPONSE_ACCEPT)

  (let ((response (gtk_dialog_run *dialog)))
    (cond
     ((= response GTK_RESPONSE_ACCEPT)
      (let ((*filename (gtk_file_chooser_get_filename *dialog)))
        (unless (null-pointer? *filename)
          (when (true? (x_dialog_confirm_overwrite *filename))
            (if (zero? current-page-id)
                ;; Only export the component table.
                (catch 'system-error
                  (lambda ()
                    (with-output-to-file (pointer->string *filename)
                      export-components))
                  (lambda (key subr message args rest)
                    (let ((msg (format #f
                                       (G_ "Failed to save file: ~?\n")
                                       message
                                       args)))
                      (log! 'warning msg)
                      (let ((*dialog (gtk_message_dialog_new %null-pointer
                                                             GTK_DIALOG_MODAL
                                                             (symbol->gtk-message-type 'error)
                                                             (symbol->gtk-buttons-type 'ok)
                                                             (string->pointer msg))))
                        (gtk_window_set_title *dialog
                                              (string->pointer (G_ "Export error")))
                        (gtk_dialog_run *dialog)
                        (gtk_widget_destroy *dialog)))))
                (x_dialog_unimplemented_feature)))
          (g_free *filename))))
     (else #f)))

  (gtk_widget_destroy *dialog))


(define (export-csv)
  "Export component table info in the CSV format."
  (define *notebook (attrib_get_notebook))
  (define current-page-id (gtk_notebook_get_current_page *notebook))

  ;; Check that we are on components page.
  (if (zero? current-page-id)
      (export-file-dialog)
      ;; We only support export of components now
      (x_dialog_unimplemented_feature)))


(define (callback-file-export-csv *action *parameter *data)
  (export-csv))
(define *callback-file-export-csv
  (procedure->pointer void callback-file-export-csv '(* * *)))


(define (quit-program return-code)
  "Unconditionally quit the program with the given RETURN-CODE."
  (s_clib_free)

  (unless %m4-use-gtk3
    (gtk_main_quit))

  (exit return-code))



(define (unsaved-data-dialog)
  (define *dialog (x_dialog_unsaved_data))

  (gtk_dialog_set_default_response *dialog GTK_RESPONSE_YES)

  (let ((response (gtk_dialog_run *dialog)))
    (cond
     ((= response GTK_RESPONSE_NO)
      (quit-program 0))
     ((= response GTK_RESPONSE_YES)
      (save-sheet)
      (quit-program 0))
     (else #f)))

  (gtk_widget_destroy *dialog))


;;; Quit the program using the UI. On execution, the function
;;; checks for unsaved changes before calling quit-program() to
;;; quit the program.
(define (callback-file-quit *action *parameter *data)
  ;; Save main window's geometry to the cache config context.
  (save-gtk-window-geometry (attrib_get_window)
                            "attrib.window-geometry")
  ;; Deactivate the current cell to trigger "deactivate" signal.
  ;; This allows changing of the sheet_head->CHANGED flag in the
  ;; on_deactivate() handler function if needed.
  (for-each
   (lambda (i)
     (let ((*sheet (attrib_get_sheet i)))
       (unless (null-pointer? *sheet)
         (gtk_sheet_set_active_cell *sheet -1 -1))))
   (iota (attrib_get_sheets_number)))

  (if (true? (attrib_sheet_data_get_changed (attrib_get_sheet_data)))
      (unsaved-data-dialog)
      (quit-program 0)))

(define *callback-file-quit
  (procedure->pointer void callback-file-quit '(* * *)))

(define gtk_dialog_add_buttons_6
  (let ((proc (delay (pointer->procedure
                      '*
                      (dynamic-func "gtk_dialog_add_buttons" libgtk)
                      (list '* '* int '* int '*)))))
    (force proc)))

(define gtk_dialog_add_buttons
  (case-lambda
    ((*dialog *button-text1 response1 *button-text2 response2 end)
     (gtk_dialog_add_buttons_6 *dialog
                               *button-text1
                               response1
                               *button-text2
                               response2
                               %null-pointer))))

(define gtk_dialog_new_with_buttons_8
  (let ((proc (delay (pointer->procedure
                      '*
                      (dynamic-func "gtk_dialog_new_with_buttons" libgtk)
                      (list '* '* int '* int '* int '*)))))
    (force proc)))

(define gtk_dialog_new_with_buttons
  (case-lambda
    ((*title *parent flags *button-text1 response1 *button-text2 response2 end)
     (gtk_dialog_new_with_buttons_8 *title
                                    *parent
                                    flags
                                    *button-text1
                                    response1
                                    *button-text2
                                    response2
                                    %null-pointer))))



;;; Adds a new attribute to the component sheet.
(define (add-attrib-column *name)
  (define *sheet-data (attrib_get_sheet_data))
  (define *notebook (attrib_get_notebook))
  (define current-page-id (gtk_notebook_get_current_page *notebook))

  ;; Only component sheet is supported yet.
  (when (zero? current-page-id)
    ;; Eventually, I want to just resize the table to accomodate
    ;; the new attrib.  However, that is difficult.  Therefore, I
    ;; will just destroy the old table and recreate it for now.
    (let ((old-component-attrib-count
           (attrib_sheet_data_get_component_attrib_count *sheet-data)))

      (s_string_list_add_item
       (attrib_sheet_data_get_component_attrib_list *sheet-data)
       (attrib_sheet_data_get_component_attrib_counter_address *sheet-data)
       *name)
      (s_string_list_sort_master_comp_attrib_list)

      ;; Now, determine what index the new attrib ended up at.
      ;; This is necessary to tell gtk_sheet_insert_columns
      ;; where the data should be shifted.
      (let ((new-index
             (s_string_list_find_in_list
              (attrib_sheet_data_get_component_attrib_list *sheet-data)
              *name)))

        ;; Resize table to accomodate new attrib column.
        (attrib_sheet_data_set_component_table
         *sheet-data
         (s_table_resize
          (attrib_sheet_data_get_component_table *sheet-data)
          (attrib_sheet_data_get_component_count *sheet-data)
          old-component-attrib-count
          (attrib_sheet_data_get_component_attrib_count *sheet-data)))

        ;; Fill out new sheet with new stuff from gtksheet.
        (gtk_sheet_insert_columns (attrib_get_sheet 0) new-index 1)
        (x_gtksheet_add_col_labels
         (attrib_get_sheet 0)
         (attrib_sheet_data_get_component_attrib_count *sheet-data)
         (attrib_sheet_data_get_component_attrib_list *sheet-data))))))


;;; Runs the Add attribute dialog.  It asks for the name of the
;;; attrib column to insert and then inserts the column.
(define (add-attrib-dialog)
  ;; Create the dialog.
  (define *dialog
    (gtk_dialog_new_with_buttons
     (string->pointer (G_"Add new attribute"))
     %null-pointer
     GTK_DIALOG_MODAL
     (string->pointer (G_ "_OK"))
     GTK_RESPONSE_OK
     (string->pointer (G_ "_Cancel"))
     GTK_RESPONSE_CANCEL
     %null-pointer))
  ;; Create a text label for the dialog window.
  (define *label
    (gtk_label_new (string->pointer (G_ "Enter new attribute name"))))
  ;; Create the attrib text entry area.
  (define *attrib-entry (gtk_entry_new))

  (gtk_dialog_set_default_response *dialog GTK_RESPONSE_OK)
  (gtk_box_pack_start (gtk_dialog_get_content_area *dialog)
                      *label
                      FALSE
                      FALSE
                      0)

  (gtk_entry_set_max_length *attrib-entry 1024)
  (gtk_box_pack_start (gtk_dialog_get_content_area *dialog)
                      *attrib-entry
                      TRUE
                      TRUE
                      5)
  (gtk_widget_set_size_request *dialog 260 140)

  (gtk_widget_show_all *dialog)

  (let ((response (gtk_dialog_run *dialog)))
    (cond
     ((= response GTK_RESPONSE_OK)
      (let ((*entry-text
             (g_strdup (gtk_entry_get_text *attrib-entry))))
        (unless (null-pointer? *entry-text)
          (add-attrib-column *entry-text)
          (g_free *entry-text))))
     (else #f)))

  (gtk_widget_destroy *dialog))


(define (add-attrib)
  (define *notebook (attrib_get_notebook))
  (define current-page-id (gtk_notebook_get_current_page *notebook))

  ;; Check that we are on components page.
  (when (zero? current-page-id)
    (add-attrib-dialog)))


(define (callback-edit-add-attrib *action *parameter *data)
  (add-attrib))
(define *callback-edit-add-attrib
  (procedure->pointer void callback-edit-add-attrib '(* * *)))


(define (delete-component-attrib-column *sheet num)
  (define *sheet-data (attrib_get_sheet_data))
  ;; Get name (label) of the column to delete from the gtk sheet.
  (define *attrib-name
    (g_strdup (gtk_sheet_column_button_get_label *sheet num)))

  (if (null-pointer? *attrib-name)
      (begin
        (format (current-error-port) "delete-component-attrib-column: ")
        (format (current-error-port) (G_ "Can't get attrib name\n")))

      ;; Eventually, I want to just resize the table after
      ;; deleting the attrib.  However, that is difficult.
      ;; Therefore, I will just destroy the old table and recreate
      ;; it for now.

      ;; Make a copy of the TABLE array, minus data in column to
      ;; delete.
      (let ((*new-table
             (s_table_copy
              (attrib_sheet_data_get_component_table *sheet-data)
              num
              (attrib_sheet_data_get_component_count *sheet-data)
              (attrib_sheet_data_get_component_attrib_count *sheet-data))))
        ;; Destroy the current TABLE array:
        (s_table_destroy
         (attrib_sheet_data_get_component_table *sheet-data)
         (attrib_sheet_data_get_component_count *sheet-data)
         (attrib_sheet_data_get_component_attrib_count *sheet-data))

        (s_string_list_delete_item
         (attrib_sheet_data_get_component_attrib_list_address *sheet-data)
         (attrib_sheet_data_get_component_attrib_counter_address *sheet-data)
         *attrib-name)
        ;; This renumbers list also.
        (s_string_list_sort_master_comp_attrib_list)

        (g_free *attrib-name)

        ;; Use the copy made above as the current TABLE array.
        (attrib_sheet_data_set_component_table *sheet-data *new-table)

        ;; Delete column on gtksheet.
        (gtk_sheet_delete_columns *sheet num 1)

        ;; Set changed flag so user is prompted when exiting.
        (s_sheet_data_set_changed *sheet-data TRUE))))


;;; Delete an attribute column.
(define (delete-attrib-column)
  (define *sheet-data (attrib_get_sheet_data))
  (define current-page-id
    (gtk_notebook_get_current_page (attrib_get_notebook)))
  (define *sheet (attrib_get_sheet current-page-id))
  (unless (null-pointer? *sheet)
    (let ((mincol (x_gtksheet_get_min_col *sheet))
          (maxcol (x_gtksheet_get_max_col *sheet)))
      (unless (or (not (= mincol maxcol))
                  (= mincol -1)
                  (= maxcol -1))
        (cond
         ;; Component sheet.
         ((= current-page-id 0)
          (delete-component-attrib-column *sheet mincol))
         ;; Net sheet.
         ((= current-page-id 1)
          ;; Delete column on gtksheet.
          (gtk_sheet_delete_columns *sheet mincol 1)
          ;; Set changed flag so user is prompted when exiting.
          (s_sheet_data_set_changed *sheet-data TRUE))
         ;; Pin sheet.
         ((= current-page-id 2)
          ;; Delete column on gtksheet.
          (gtk_sheet_delete_columns *sheet mincol 1)
          ;; Set changed flag so user is prompted when exiting.
          (s_sheet_data_set_changed *sheet-data TRUE)))))))


;; Runs the Delete attribute dialog.
(define (delete-attrib)
  ;; First verify that exactly one column is selected.
  (define current-page-id
    (gtk_notebook_get_current_page (attrib_get_notebook)))
  (define *sheet (attrib_get_sheet current-page-id))
  (unless (null-pointer? *sheet)
    (let ((mincol (x_gtksheet_get_min_col *sheet))
          (maxcol (x_gtksheet_get_max_col *sheet)))
      ;; Check improper selection.
      (unless (or (not (= mincol maxcol))
                  (= mincol -1)
                  (= maxcol -1))
        ;; Create the dialog.
        (let ((*dialog
               (gtk_message_dialog_new
                %null-pointer
                GTK_DIALOG_MODAL
                (symbol->gtk-message-type 'question)
                (symbol->gtk-buttons-type 'yes-no)
                (string->pointer
                 (G_ "Are you sure you want to delete this attribute?")))))

          (gtk_window_set_title *dialog
                                (string->pointer (G_ "Delete attribute")))
          (gtk_dialog_set_default_response *dialog GTK_RESPONSE_NO)

          (let ((response (gtk_dialog_run *dialog)))
            (cond
             ((= response GTK_RESPONSE_YES)
              ;; Actually delete the attrib column.  This function
              ;; figures out which column to delete.
              (delete-attrib-column))
             (else #f)))

          (gtk_widget_destroy *dialog))))))


;;; Runs the Missing symbol dialog.  It offers the user the chance
;;; to close the project without saving because the program read a
;;; schematic with a missing symbol file.
(define (missing-symbol-dialog)
  (define message
    (G_ "One or more components have been found with missing symbol files!

This probably happened because lepton-attrib couldn't find your
component libraries, perhaps because your gafrc files are misconfigured.

Choose \"Quit\" to leave lepton-attrib and fix the problem, or
\"Forward\" to continue working with lepton-attrib."))

  ;; Create the *dialog.
  (define *dialog
    (gtk_message_dialog_new %null-pointer
                            GTK_DIALOG_MODAL
                            (symbol->gtk-message-type 'warning)
                            (symbol->gtk-buttons-type 'none)
                            (string->pointer message)))

  (gtk_dialog_add_buttons *dialog
                          (string->pointer (G_ "_Quit"))
                          GTK_RESPONSE_REJECT
                          (string->pointer (G_ "_Forward"))
                          GTK_RESPONSE_ACCEPT
                          %null-pointer)

  (gtk_window_set_title
   *dialog
   (string->pointer (G_ "Missing symbol file found for component!")))
  (gtk_dialog_set_default_response *dialog GTK_RESPONSE_REJECT)

  (let ((response (gtk_dialog_run *dialog)))
    (cond
     ;; Continue with the execution.
     ((= response GTK_RESPONSE_ACCEPT)
      'accept)
     ;; Terminate.
     (else (exit 0))))

  (gtk_widget_destroy *dialog))


(define (callback-edit-delete-attrib *action *parameter *data)
  (delete-attrib))
(define *callback-edit-delete-attrib
  (procedure->pointer void callback-edit-delete-attrib '(* * *)))

(define (callback-visibility-invisible *action *parameter *data)
  (s_visibility_set_invisible *action *parameter *data))
(define *callback-visibility-invisible
  (procedure->pointer void callback-visibility-invisible '(* * *)))

(define (callback-visibility-name-only *action *parameter *data)
  (s_visibility_set_name_only *action *parameter *data))
(define *callback-visibility-name-only
  (procedure->pointer void callback-visibility-name-only '(* * *)))

(define (callback-visibility-value-only *action *parameter *data)
  (s_visibility_set_value_only *action *parameter *data))
(define *callback-visibility-value-only
  (procedure->pointer void callback-visibility-value-only '(* * *)))

(define (callback-visibility-name-value *action *parameter *data)
  (s_visibility_set_name_and_value *action *parameter *data))
(define *callback-visibility-name-value
  (procedure->pointer void callback-visibility-name-value '(* * *)))

(define (callback-help-about *action *parameter *data)
  (x_dialog_about_dialog *action *parameter *data))
(define *callback-help-about
  (procedure->pointer void callback-help-about '(* * *)))


(define (init-callbacks)
  (attrib_window_set_menu_callback (string->pointer "file-save")
                                   *callback-file-save)
  (attrib_window_set_menu_callback (string->pointer "file-export-csv")
                                   *callback-file-export-csv)
  (attrib_window_set_menu_callback (string->pointer "file-quit")
                                   *callback-file-quit)
  (attrib_window_set_menu_callback (string->pointer "edit-add-attrib")
                                   *callback-edit-add-attrib)
  (attrib_window_set_menu_callback (string->pointer "edit-delete-attrib")
                                   *callback-edit-delete-attrib)
  (attrib_window_set_menu_callback (string->pointer "visibility-invisible")
                                   *callback-visibility-invisible)
  (attrib_window_set_menu_callback (string->pointer "visibility-name-only")
                                   *callback-visibility-name-only)
  (attrib_window_set_menu_callback (string->pointer "visibility-value-only")
                                   *callback-visibility-value-only)
  (attrib_window_set_menu_callback (string->pointer "visibility-name-value")
                                   *callback-visibility-name-value)
  (attrib_window_set_menu_callback (string->pointer "help-about")
                                   *callback-help-about))

(define (init-window)
  (define *window-widget (attrib_get_window))

  (g_signal_connect *window-widget
                    (string->pointer "delete_event")
                    *callback-file-quit
                    %null-pointer)

  ;; Init menu functions.
  (init-callbacks)

  (x_window_init)

  ;; Create the array of sheets.
  (attrib_window_sheets_new)

  ;; Restore main window's geometry.
  (restore-gtk-window-geometry *window-widget "attrib.window-geometry"))


;;; Adds all items to the top level window.
(define (add-items)
  (define *sheet-data (attrib_get_sheet_data))
  (define *window (attrib_get_window))

  (define *component-table
    (attrib_sheet_data_get_component_table *sheet-data))
  (define (component-sheet)
    (attrib_get_sheet 0))
  (define component-count
    (attrib_sheet_data_get_component_count *sheet-data))
  (define component-attrib-count
    (attrib_sheet_data_get_component_attrib_count *sheet-data))
  (define *pin-table (attrib_sheet_data_get_pin_table *sheet-data))
  (define (pin-sheet)
    (attrib_get_sheet 2))
  (define pin-count (attrib_sheet_data_get_pin_count *sheet-data))
  (define pin-attrib-count
    (attrib_sheet_data_get_pin_attrib_count *sheet-data))
  (define *net-table (attrib_sheet_data_get_net_table *sheet-data))
  (define (net-sheet)
    (attrib_get_sheet 1))
  (define net-count (attrib_sheet_data_get_net_count *sheet-data))
  (define net-attrib-count
    (attrib_sheet_data_get_net_attrib_count *sheet-data))

  ;; Do sanity checks.
  (when (zero? component-count)
    (let ((error-string
           (G_ "No components found in entire design!
Do you have refdeses on your components?")))
      (x_dialog_fatal_error (string->pointer error-string) 1)))

  (when (zero? component-attrib-count)
    (let ((error-string
           (G_ "No configurable component attributes found in entire design!
Please attach at least some attributes before running lepton-attrib.")))
      (x_dialog_fatal_error (string->pointer error-string) 2)))

  (when (zero? pin-count)
    (let ((error-string
           (G_ "No pins found on any components!
Please check your design.")))
      (x_dialog_fatal_error (string->pointer error-string) 3)))


  ;; Initialize the gtksheet.  This creates a new gtksheet having
  ;; dimensions specified in component-count etc.
  (x_gtksheet_init)

  (when (> component-count 0)
    (x_gtksheet_add_row_labels
     (component-sheet)
     component-count
     (attrib_sheet_data_get_component_list *sheet-data))
    (x_gtksheet_add_col_labels
     (component-sheet)
     component-attrib-count
     (attrib_sheet_data_get_component_attrib_list *sheet-data)))

  ;; This is not ready.  Processing of net attributes ('net' and
  ;; 'netname') has to be implemented.
  (if (> net-count 0)
      (begin
        (x_gtksheet_add_row_labels
         (net-sheet)
         net-count
         (attrib_sheet_data_get_net_list *sheet-data))
        (x_gtksheet_add_col_labels
         (net-sheet)
         net-attrib-count
         (attrib_sheet_data_get_net_attrib_list *sheet-data)))
      (begin
        (x_gtksheet_add_row_labels (net-sheet)
                                   1
                                   %null-pointer)
        (x_gtksheet_add_col_labels (net-sheet)
                                   1
                                   %null-pointer)))

  (when (> pin-count 0)
    (x_gtksheet_add_row_labels
     (pin-sheet)
     pin-count
     (attrib_sheet_data_get_pin_list *sheet-data))
    (x_gtksheet_add_col_labels
     (pin-sheet)
     pin-attrib-count
     (attrib_sheet_data_get_pin_attrib_list *sheet-data)))

  ;; Component sheet: put values in the individual cells.
  (for-each
   (lambda (i)
     (for-each
      (lambda (j)
        (let ((*text
               (attrib_table_get_attrib_value *component-table i j))
              (visibility
               (attrib_table_get_visibility *component-table i j))
              (show-name-value
               (attrib_table_get_show_name_value *component-table i j)))
          (unless (null-pointer? *text)
            ;; NULL = no entry.
            (x_gtksheet_add_cell_item (component-sheet)
                                      i
                                      j
                                      *text
                                      visibility
                                      show-name-value))))
      (iota component-attrib-count)))
   (iota component-count))

  ;; Net sheet: put values in the individual cells
  (for-each
   (lambda (i)
     (for-each
      (lambda (j)
        (let ((*text (attrib_table_get_attrib_value *net-table i j))
              (visibility
               (attrib_table_get_visibility *net-table i j))
              (show-name-value
               (attrib_table_get_show_name_value *net-table i j)))
          (unless (null-pointer? *text)
            ;; NULL = no entry.
            (x_gtksheet_add_cell_item (net-sheet)
                                      i
                                      j
                                      *text
                                      visibility
                                      show-name-value))))
      (iota net-attrib-count)))
   (iota net-count))

  ;; Pin sheet: put pin attribs in the individual cells.
  (for-each
   (lambda (i)
     (for-each
      (lambda (j)
        (let ((*text (attrib_table_get_attrib_value *pin-table i j))
              (visibility
               (attrib_table_get_visibility *pin-table i j))
              (show-name-value
               (attrib_table_get_show_name_value *pin-table i j)))
          (unless (null-pointer? *text)
            ;; NULL = no entry.
            (x_gtksheet_add_cell_item (pin-sheet)
                                      i
                                      j
                                      *text
                                      visibility
                                      show-name-value))))
      (iota pin-attrib-count)))
   (iota pin-count))

  (gtk_widget_show_all *window))


;;; Creates and returns an initialised but empty SHEET_DATA
;;; instance.
(define (make-sheet-data)
  (define *sheet-data (attrib_sheet_data_new))

  ;; We will malloc and fill out the component table later.
  (attrib_sheet_data_set_component_table *sheet-data %null-pointer)

  ;; We will malloc and fill out the net table later.
  (attrib_sheet_data_set_net_table *sheet-data %null-pointer)

  ;; We will malloc and fill out the pin table later.
  (attrib_sheet_data_set_pin_table *sheet-data %null-pointer)

  ;; Now we create the first cell in each master list.
  (attrib_sheet_data_set_component_list *sheet-data
                                        (s_string_list_new))
  (attrib_sheet_data_set_component_attrib_list *sheet-data
                                               (s_string_list_new))
  (attrib_sheet_data_set_component_count *sheet-data 0)
  (attrib_sheet_data_set_component_attrib_count *sheet-data 0)

  (attrib_sheet_data_set_net_list *sheet-data
                                  (s_string_list_new))
  (attrib_sheet_data_set_net_attrib_list *sheet-data
                                         (s_string_list_new))
  (attrib_sheet_data_set_net_count *sheet-data 0)
  (attrib_sheet_data_set_net_attrib_count *sheet-data 0)

  (attrib_sheet_data_set_pin_list *sheet-data
                                  (s_string_list_new))
  (attrib_sheet_data_set_pin_attrib_list *sheet-data
                                         (s_string_list_new))
  (attrib_sheet_data_set_pin_count *sheet-data 0)
  (attrib_sheet_data_set_pin_attrib_count *sheet-data 0)

  (attrib_sheet_data_set_changed *sheet-data FALSE)

  *sheet-data)


(define (add-components *objects)
  (s_sheet_data_add_master_comp_list_items *objects))


(define (add-component-attribs *objects)
  (s_sheet_data_add_master_comp_attrib_list_items *objects))


;;; Adds the list of nets by running through the individual cells
;;; and recording the names it discovers.  Not implemented yet.
(define (add-nets *objects)
  #f)


;;; Adds net attribs.  Not implemented yet.
(define (add-net-attribs *objects)
  #f)


(define (add-pins *objects)
  (s_sheet_data_add_master_pin_list_items *objects))


(define (add-pin-attribs *objects)
  (s_sheet_data_add_master_pin_attrib_list_items *objects))


(define (activate *app *toplevel)
  (define *window-widget (attrib_window_new *app))
  (define *sheet-data (make-sheet-data))
  (define *pages
    (lepton_list_get_glist (lepton_toplevel_get_pages *toplevel)))

  (attrib_set_window *window-widget)

  (attrib_set_toplevel *toplevel)

  ;; Initialize GTK window.
  (init-window)

  ;; Initialize main sheet data structure.
  (attrib_set_sheet_data *sheet-data)

  (for-each
   (lambda (*page)
     (let ((*objects (lepton_page_objects *page)))
       (lepton_toplevel_set_page_current *toplevel *page)

       ;; Now add all items found to the master lists
       (add-components *objects)
       (add-component-attribs *objects)
       ;; Note that this must be changed.  We need to input the
       ;; entire project before doing anything with the nets because
       ;; we need to first determine where they are all connected!
       (add-nets *objects)
       (add-net-attribs *objects)

       (add-pins *objects)
       (add-pin-attribs *objects)))

   (glist->list *pages identity))

  ;; Sort the master lists.
  (s_string_list_sort_master_comp_list)
  (s_string_list_sort_master_comp_attrib_list)

  ;; Note that this must be changed.  We need to input the
  ;; entire project before doing anything with the nets because
  ;; we need to first determine where they are all connected!
  (s_string_list_sort_master_net_list)
  (s_string_list_sort_master_net_attrib_list)

  (s_string_list_sort_master_pin_list)
  (s_string_list_sort_master_pin_attrib_list)

  ;; Create and load the tables.
  (attrib_sheet_data_set_component_table
   *sheet-data
   (s_table_new (attrib_sheet_data_get_component_count *sheet-data)
                (attrib_sheet_data_get_component_attrib_count *sheet-data)))
  (attrib_sheet_data_set_net_table
   *sheet-data
   (s_table_new (attrib_sheet_data_get_net_count *sheet-data)
                (attrib_sheet_data_get_net_attrib_count *sheet-data)))
  (attrib_sheet_data_set_pin_table
   *sheet-data
   (s_table_new (attrib_sheet_data_get_pin_count *sheet-data)
                (attrib_sheet_data_get_pin_attrib_count *sheet-data)))

  ;; Must iterate over all pages in design.
  (for-each
   (lambda (*page)
     ;; Only traverse pages which are toplevel.
     (when  (zero? (lepton_page_get_page_control *page))
       ;; Adds all components from page to the component table.
       (s_table_add_toplevel_comp_items_to_comp_table (lepton_page_objects *page))

       ;; Note that this must be changed.  We need to input the
       ;; entire project before doing anything with the nets
       ;; because we need to first determine where they are all
       ;; connected!

       ;; Adds all nets from page to the net table.
       (s_table_add_toplevel_net_items_to_net_table (lepton_page_objects *page))

       ;; Adds all pins from page to the pin table.
       (s_table_add_toplevel_pin_items_to_pin_table (lepton_page_objects *page))))

   (glist->list *pages identity))

  ;; Update windows.
  ;; This updates the top level stuff, and then calls another
  ;; function to update the GtkSheet itself.
  (add-items)
  ;; Verify correctness of entire design.
  (when (design-has-missing-symbols?)
    ;; Dialog gives user option to quit.
    (missing-symbol-dialog))

  ;; Set the main window's title.
  (let ((page-count (length (active-pages))))
    (gtk_window_set_title
     *window-widget
     (string->pointer
      (cond
       ((= page-count 1)
        (string-append (basename (page-filename (car (active-pages))))
                       " - "
                       %program-basename))
       ((> page-count 1)
        (string-append (G_ "Multiple files") " - " %program-basename))
       (else %program-basename)))))

  ;; Set default icon.
  (gtk_window_set_default_icon_name (string->pointer %theme-icon-name))

  (gtk_widget_show_all *window-widget))


;;; Sets up file filters for the File chooser dialog *FILE-CHOOSER.
(define (setup-file-chooser-filters *file-chooser)
  ;; File filter for schematic files (*.sch).
  (let ((*filter (gtk_file_filter_new)))
    (gtk_file_filter_set_name *filter
                              (string->pointer (G_ "Schematics")))
    (gtk_file_filter_add_pattern *filter (string->pointer "*.sch"))
    (gtk_file_chooser_add_filter *file-chooser *filter))
  ;; File filter for symbol files (*.sym).
  (let ((*filter (gtk_file_filter_new)))
    (gtk_file_filter_set_name *filter
                              (string->pointer (G_ "Symbols")))
    (gtk_file_filter_add_pattern *filter (string->pointer "*.sym"))
    (gtk_file_chooser_add_filter *file-chooser *filter))
  ;; File filter for both symbol and schematic files (*.sym+*.sch).
  (let ((*filter (gtk_file_filter_new)))
    (gtk_file_filter_set_name *filter
                              (string->pointer (G_ "Schematics and symbols")))
    (gtk_file_filter_add_pattern *filter (string->pointer "*.sym"))
    (gtk_file_filter_add_pattern *filter (string->pointer "*.sch"))
    (gtk_file_chooser_add_filter *file-chooser *filter))
  ;; File filter that matches any file.
  (let ((*filter (gtk_file_filter_new)))
    (gtk_file_filter_set_name *filter
                              (string->pointer (G_ "All files")))
    (gtk_file_filter_add_pattern *filter (string->pointer "*"))
    (gtk_file_chooser_add_filter *file-chooser *filter)))


;;; Opens a file chooser dialog in *WINDOW and waits for the user
;;; to select at least one file to load as a new page.  *WINDOW is
;;; the main program window or NULL.  Returns a GSList list of
;;; files to be opened, or NULL if the user cancelled the dialog.
(define (file-chooser-dialog *window)
  (define *dialog
    (gtk_file_chooser_dialog_new (string->pointer (G_ "Open..."))
                                 *window
                                 (symbol->gtk-file-chooser-action 'open)
                                 (string->pointer (G_ "_Cancel"))
                                 GTK_RESPONSE_CANCEL
                                 (string->pointer (G_ "_Open"))
                                 GTK_RESPONSE_ACCEPT
                                 %null-pointer))

  (gtk_file_chooser_set_select_multiple *dialog TRUE)

  ;; Add file filters to the dialog.
  (setup-file-chooser-filters *dialog)
  (gtk_widget_show *dialog)

  (let ((*filenames
         (if (= (gtk_dialog_run *dialog) GTK_RESPONSE_ACCEPT)
             (gtk_file_chooser_get_filenames *dialog)
             %null-pointer)))
    (gtk_widget_destroy *dialog)
    *filenames))


;;; Init logging.
(init-log "attrib")
(display-lepton-version #:print-name #t #:log #t)


(let* ((option-spec '((help (single-char #\h))
                      (verbose (single-char #\v))
                      (version (single-char #\V))))

       (options (getopt-long (program-arguments) option-spec))
       (help (option-ref options 'help #f))
       (version (option-ref options 'version #f))
       (files (option-ref options '() '()))
       (verbose? (option-ref options 'verbose #f)))

  (when help (usage))
  ;; Output version to stdout and exit, if requested.
  (when version
    (display-lepton-version #:print-name #t #:copyright #t)
    (exit 0))
  (when verbose? (set_verbose_mode))

  (receive (readable-files unreadable-files)
      (partition file-readable? files)
    (if (null? unreadable-files)
        ;; Main procedure.
        (begin
          ;; Initialize GTK.
          (gtk_init %null-pointer %null-pointer)
          (let ((files (if (null? readable-files)
                           ;; No files specified on the command
                           ;; line, pop up the File open dialog.
                           (gslist->list
                            (file-chooser-dialog %null-pointer)
                            pointer->string 'free)
                           readable-files)))
            (if (null? files)
                (exit 0)
                (with-toplevel (make-toplevel)
                 (lambda ()
                   (for-each process-gafrc* files)
                   ;; Open all files.
                   (for-each file->page files)
                   ;; Run attribute editor.
                   (exit (if %m4-use-gtk3
                             (attrib_run (procedure->pointer void activate '(* *))
                                         (toplevel->pointer (current-toplevel)))
                             (let ((*toplevel (toplevel->pointer (current-toplevel))))
                               (activate %null-pointer *toplevel)
                               (attrib_run %null-pointer *toplevel)))))))))

        ;; There are non-existing or unreadable files.  Report and
        ;; exit.
        (begin
          (for-each report-unreadable unreadable-files)
          (exit 1)))))
