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


(define-module (schematic gtk geometry)
  #:use-module (rnrs bytevectors)
  #:use-module (system foreign)

  #:use-module (lepton config)

  #:use-module (schematic ffi gtk)

  #:export (restore-gtk-window-geometry
            save-gtk-window-geometry))


;;; Default sizes of any GtkWindow.
(define %default-window-width 800)
(define %default-window-height 600)


(define (save-gtk-window-geometry *window config-group)
  "Save geometry of GtkWindow *WINDOW in CONFIG-GROUP of the cache
config context."
  (define (get-int bv)
    (bytevector-sint-ref bv 0 (native-endianness) (sizeof int)))
  (define x-bv (make-bytevector (sizeof int) 0))
  (define y-bv (make-bytevector (sizeof int) 0))
  (define width-bv (make-bytevector (sizeof int) 0))
  (define height-bv (make-bytevector (sizeof int) 0))

  (gtk_window_get_position *window
                           (bytevector->pointer x-bv)
                           (bytevector->pointer y-bv))

  (gtk_window_get_size *window
                       (bytevector->pointer width-bv)
                       (bytevector->pointer height-bv))

  (let ((config (cache-config-context))
        (x (get-int x-bv))
        (y (get-int y-bv))
        (width (get-int width-bv))
        (height (get-int height-bv)))
    (set-config! config config-group "x" x)
    (set-config! config config-group "y" y)
    (set-config! config config-group "width" width)
    (set-config! config config-group "height" height)

    (config-save! config)))


(define (restore-gtk-window-geometry *window config-group)
  "Restore the previous geometry of GtkWindow *WINDOW from
CONFIG-GROUP of the cache config context.  Unless valid
configuration values are read, the default width and height are
used."
  (define cache-config (cache-config-context))
  (define x (config-int cache-config config-group "x"))
  (define y (config-int cache-config config-group "y"))
  (define width (config-int cache-config config-group "width"))
  (define height (config-int cache-config config-group "height"))

  (when (and (> x 0) (> y 0))
    (gtk_window_move *window x y))

  (if (and (> width 0) (> height 0))
      (gtk_window_resize *window width height)
      (gtk_window_resize *window
                         %default-window-width
                         %default-window-height)))
