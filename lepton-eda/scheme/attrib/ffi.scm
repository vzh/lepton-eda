;;; Lepton EDA Schematic Capture
;;; Scheme API
;;; Copyright (C) 2026 Lepton EDA Contributors
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
;;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

(define-module (attrib ffi)
  #:use-module (system foreign)

  #:use-module (lepton ffi lff)
  #:use-module (lepton ffi lib)
  #:use-module (lepton m4)

  #:export (gtk_sheet_set_active_cell
            gtk_sheet_column_button_get_label
            gtk_sheet_delete_columns
            gtk_sheet_insert_columns

            attrib_get_notebook
            attrib_get_sheet
            attrib_set_sheet_data
            attrib_get_sheet_data
            attrib_get_sheets_number
            attrib_get_toplevel
            attrib_set_toplevel
            attrib_get_window
            attrib_set_window

            s_attrib_get_refdes
            s_attrib_name_in_list

            s_misc_remaining_string
            set_verbose_mode
            u_basic_breakup_string

            x_fileselect_open

            x_dialog_about_dialog
            x_dialog_confirm_overwrite
            x_dialog_fatal_error
            x_dialog_unimplemented_feature
            x_dialog_unsaved_data

            x_gtksheet_add_cell_item
            x_gtksheet_add_col_labels
            x_gtksheet_add_row_labels
            x_gtksheet_get_max_col
            x_gtksheet_get_min_col
            x_gtksheet_init

            s_object_add_comp_attrib_to_object
            s_object_add_pin_attrib_to_object
            s_object_remove_attrib_in_object
            s_object_replace_attrib_in_object

            attrib_sheet_data_new
            attrib_sheet_data_get_changed
            attrib_sheet_data_set_changed
            attrib_sheet_data_get_component_attrib_count
            attrib_sheet_data_set_component_attrib_count
            attrib_sheet_data_get_component_attrib_counter_address
            attrib_sheet_data_get_component_attrib_list
            attrib_sheet_data_set_component_attrib_list
            attrib_sheet_data_get_component_attrib_list_address
            attrib_sheet_data_get_component_count
            attrib_sheet_data_set_component_count
            attrib_sheet_data_get_component_list
            attrib_sheet_data_set_component_list
            attrib_sheet_data_get_component_table
            attrib_sheet_data_set_component_table
            attrib_sheet_data_get_net_attrib_count
            attrib_sheet_data_set_net_attrib_count
            attrib_sheet_data_get_net_attrib_list
            attrib_sheet_data_set_net_attrib_list
            attrib_sheet_data_get_net_count
            attrib_sheet_data_set_net_count
            attrib_sheet_data_get_net_list
            attrib_sheet_data_set_net_list
            attrib_sheet_data_get_net_table
            attrib_sheet_data_set_net_table
            attrib_sheet_data_get_pin_attrib_count
            attrib_sheet_data_set_pin_attrib_count
            attrib_sheet_data_get_pin_attrib_list
            attrib_sheet_data_set_pin_attrib_list
            attrib_sheet_data_get_pin_count
            attrib_sheet_data_set_pin_count
            attrib_sheet_data_get_pin_list
            attrib_sheet_data_set_pin_list
            attrib_sheet_data_get_pin_table
            attrib_sheet_data_set_pin_table
            s_sheet_data_add_master_comp_list_items
            s_sheet_data_add_master_comp_attrib_list_items
            s_sheet_data_add_master_pin_list_items
            s_sheet_data_add_master_pin_attrib_list_items
            s_sheet_data_set_changed

            attrib_string_list_get_data
            attrib_string_list_get_next
            s_string_list_new
            s_string_list_add_item
            s_string_list_delete_item
            s_string_list_duplicate_string_list
            s_string_list_find_in_list
            s_string_list_get_data_at_index
            s_string_list_in_list
            s_string_list_sort_master_comp_list
            s_string_list_sort_master_comp_attrib_list
            s_string_list_sort_master_net_list
            s_string_list_sort_master_net_attrib_list
            s_string_list_sort_master_pin_list
            s_string_list_sort_master_pin_attrib_list

            attrib_table_get_attrib_value
            attrib_table_get_show_name_value
            attrib_table_get_visibility
            s_table_copy
            s_table_create_attrib_pair
            s_table_destroy
            s_table_get_index
            s_table_new
            s_table_add_toplevel_comp_items_to_comp_table
            s_table_add_toplevel_net_items_to_net_table
            s_table_add_toplevel_pin_items_to_pin_table
            s_table_gtksheet_to_all_tables
            s_table_resize

            s_visibility_set_invisible
            s_visibility_set_name_and_value
            s_visibility_set_name_only
            s_visibility_set_value_only

            attrib_run
            attrib_window_new
            attrib_window_sheets_new
            attrib_window_set_menu_callback
            x_window_init
            ))

;;; Simplify definition of functions by omitting the library
;;; argument.
(define libleptonattrib
  (dynamic-link (or (getenv "LIBLEPTONATTRIB") %libleptonattrib)))

(define-syntax-rule (define-lff arg ...)
  (define-lff-lib arg ... libleptonattrib))

(define-syntax-rule (define-lfc arg ...)
  (define-lfc-lib arg ... libleptonattrib))


(define %libgtksheet
  (if %m4-use-gtk3 "libgtksheet-4.0" "libgtkextra-x11-3.0"))

(define libgtksheet (dynamic-link %libgtksheet))

(define-lff-lib gtk_sheet_set_active_cell int (list '* int int) libgtksheet)
(define-lff-lib gtk_sheet_column_button_get_label '* (list '* int) libgtksheet)
(define-lff-lib gtk_sheet_delete_columns void (list '* unsigned-int unsigned-int) libgtksheet)
(define-lff-lib gtk_sheet_insert_columns void (list '* unsigned-int unsigned-int) libgtksheet)

;;; attrib.c
(define-lff attrib_get_notebook '* '())
(define-lff attrib_get_sheet '* (list int))
(define-lff attrib_set_sheet_data void '(*))
(define-lff attrib_get_sheet_data '* '())
(define-lff attrib_get_sheets_number int '())
(define-lff attrib_get_toplevel '* '())
(define-lff attrib_set_toplevel void '(*))
(define-lff attrib_get_window '* '())
(define-lff attrib_set_window void '(*))

;; s_attrib.c
(define-lff s_attrib_get_refdes '* '(*))
(define-lff s_attrib_name_in_list int '(* *))

;;; s_misc.c
(define-lff s_misc_remaining_string '* (list '* int int))
(define-lff set_verbose_mode void '())
(define-lff u_basic_breakup_string '* (list '* int int))

;;; x_fileselect.c
(define-lff x_fileselect_open '* '())

;;; x_dialog.c
(define-lff x_dialog_about_dialog void '(* * *))
(define-lff x_dialog_confirm_overwrite int '(*))
(define-lff x_dialog_fatal_error void (list '* int))
(define-lff x_dialog_unimplemented_feature void '())
(define-lff x_dialog_unsaved_data '* '())

;;; x_gtksheet.c
(define-lff x_gtksheet_add_cell_item void (list '* int int '* int int))
(define-lff x_gtksheet_add_col_labels void (list '* int '*))
(define-lff x_gtksheet_add_row_labels void (list '* int '*))
(define-lff x_gtksheet_get_max_col int '(*))
(define-lff x_gtksheet_get_min_col int '(*))
(define-lff x_gtksheet_init void '())

;;; s_object.c
(define-lff s_object_add_comp_attrib_to_object void (list '* '* '* '* int int))
(define-lff s_object_add_pin_attrib_to_object void '(* * * *))
(define-lff s_object_remove_attrib_in_object void '(* * *))
(define-lff s_object_replace_attrib_in_object void (list '* '* '* int int))

;;; s_sheet_data.c
(define-lff attrib_sheet_data_new '* '())
(define-lff attrib_sheet_data_get_changed int '(*))
(define-lff attrib_sheet_data_set_changed void (list '* int))
(define-lff attrib_sheet_data_get_component_attrib_count int '(*))
(define-lff attrib_sheet_data_set_component_attrib_count void (list '* int))
(define-lff attrib_sheet_data_get_component_attrib_counter_address '* '(*))
(define-lff attrib_sheet_data_get_component_attrib_list '* '(*))
(define-lff attrib_sheet_data_set_component_attrib_list void '(* *))
(define-lff attrib_sheet_data_get_component_attrib_list_address '* '(*))
(define-lff attrib_sheet_data_get_component_count int '(*))
(define-lff attrib_sheet_data_set_component_count void (list '* int))
(define-lff attrib_sheet_data_get_component_list '* '(*))
(define-lff attrib_sheet_data_set_component_list void '(* *))
(define-lff attrib_sheet_data_get_component_table '* '(*))
(define-lff attrib_sheet_data_set_component_table void '(* *))
(define-lff attrib_sheet_data_get_net_attrib_count int '(*))
(define-lff attrib_sheet_data_set_net_attrib_count void (list '* int))
(define-lff attrib_sheet_data_get_net_attrib_list '* '(*))
(define-lff attrib_sheet_data_set_net_attrib_list void '(* *))
(define-lff attrib_sheet_data_get_net_count int '(*))
(define-lff attrib_sheet_data_set_net_count void (list '* int))
(define-lff attrib_sheet_data_get_net_list '* '(*))
(define-lff attrib_sheet_data_set_net_list void '(* *))
(define-lff attrib_sheet_data_get_net_table '* '(*))
(define-lff attrib_sheet_data_set_net_table void '(* *))
(define-lff attrib_sheet_data_get_pin_attrib_count int '(*))
(define-lff attrib_sheet_data_set_pin_attrib_count void (list '* int))
(define-lff attrib_sheet_data_get_pin_attrib_list '* '(*))
(define-lff attrib_sheet_data_set_pin_attrib_list void '(* *))
(define-lff attrib_sheet_data_get_pin_count int '(*))
(define-lff attrib_sheet_data_set_pin_count void (list '* int))
(define-lff attrib_sheet_data_get_pin_list '* '(*))
(define-lff attrib_sheet_data_set_pin_list void '(* *))
(define-lff attrib_sheet_data_get_pin_table '* '(*))
(define-lff attrib_sheet_data_set_pin_table void '(* *))
(define-lff s_sheet_data_add_master_comp_list_items void '(*))
(define-lff s_sheet_data_add_master_comp_attrib_list_items void '(*))
(define-lff s_sheet_data_add_master_pin_list_items void '(*))
(define-lff s_sheet_data_add_master_pin_attrib_list_items void '(*))
(define-lff s_sheet_data_set_changed void (list '* int))

;;; s_string_list.c
(define-lff attrib_string_list_get_data '* '(*))
(define-lff attrib_string_list_get_next '* '(*))
(define-lff s_string_list_new '* '())
(define-lff s_string_list_add_item void '(* * *))
(define-lff s_string_list_delete_item void '(* * *))
(define-lff s_string_list_duplicate_string_list '* '(*))
(define-lff s_string_list_find_in_list int '(* *))
(define-lff s_string_list_get_data_at_index '* (list '* int))
(define-lff s_string_list_in_list int '(* *))
(define-lff s_string_list_sort_master_comp_list void '())
(define-lff s_string_list_sort_master_comp_attrib_list void '())
(define-lff s_string_list_sort_master_net_list void '())
(define-lff s_string_list_sort_master_net_attrib_list void '())
(define-lff s_string_list_sort_master_pin_list void '())
(define-lff s_string_list_sort_master_pin_attrib_list void '())

;;; s_table.c
(define-lff attrib_table_get_attrib_value '* (list '* int int))
(define-lff attrib_table_get_show_name_value int (list '* int int))
(define-lff attrib_table_get_visibility int (list '* int int))
(define-lff s_table_copy '* (list '* int int int))
(define-lff s_table_create_attrib_pair '* (list '* '* '* int))
(define-lff s_table_destroy void (list '* int int))
(define-lff s_table_get_index int '(* *))
(define-lff s_table_new '* (list int int))
(define-lff s_table_add_toplevel_comp_items_to_comp_table void '(*))
(define-lff s_table_add_toplevel_net_items_to_net_table void '(*))
(define-lff s_table_add_toplevel_pin_items_to_pin_table void '(*))
(define-lff s_table_gtksheet_to_all_tables void '())
(define-lff s_table_resize '* (list '* int int int))

;;; s_visibility.c
(define-lff s_visibility_set_invisible void '(* * *))
(define-lff s_visibility_set_name_and_value void '(* * *))
(define-lff s_visibility_set_name_only void '(* * *))
(define-lff s_visibility_set_value_only void '(* * *))

;;; x_window.c
(define-lff attrib_run int '(* *))
(define-lff attrib_window_new '* '(*))
(define-lff attrib_window_sheets_new void '())
(define-lff attrib_window_set_menu_callback void '(* *))
(define-lff x_window_init void '())
