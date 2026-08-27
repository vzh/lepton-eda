;;; Lepton EDA attribute editor
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


(define-module (attrib dialog)
  #:use-module (system foreign)

  #:use-module (lepton gettext)
  #:use-module (lepton version)

  #:use-module (schematic ffi gtk)

  #:export (about-dialog))


(define (about-dialog program-name)
  "Runs the About dialog."
  (define *dialog (gtk_about_dialog_new))

  (gtk_about_dialog_set_program_name
   *dialog
   (string->pointer program-name))

  (gtk_about_dialog_set_comments
   *dialog
   (string->pointer
    (G_ "Lepton Electronic Design Automation")))

   (let ((version-string
          (format #f
                  "~A (git: ~A)"
                  (lepton-version-ref 'dotted)
                  (lepton-version-ref 'git7))))
     (gtk_about_dialog_set_version *dialog
                                   (string->pointer version-string)))

   (gtk_about_dialog_set_copyright
    *dialog
    (string->pointer
     (G_ "Copyright © 2003-2006 Stuart D. Brorson
Copyright © 2003-2016 gEDA Contributors
Copyright © 2017-2026 Lepton EDA Contributors")))

   (gtk_about_dialog_set_license
    *dialog
    (string->pointer
     (G_ "Lepton EDA is freely distributable under the
GNU Public License (GPL) version 2.0 or (at your option) any later version.
See the COPYING file for the full text of the license.")))

   (gtk_about_dialog_set_website
    *dialog
    (string->pointer (lepton-version-ref 'url)))

   (gtk_widget_show_all *dialog)
   (gtk_dialog_run *dialog)

   (gtk_widget_destroy *dialog))
