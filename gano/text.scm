;;; text.scm
;;;
;;; Copyright (C) 2010 Michael L. Gran
;;; Copyright (C) 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009 Free Software Foundation, Inc.

;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundation; either version 3, or
;;; (at your option) any later version.

;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, write to the Free Software
;;; Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
;;; 02110-1301, USA.

;;; This file incorporates code from GNU Nano
(define-module (gano text)
  #:use-module (gano records)
  #:use-module (gano flags)
  #:use-module (gano utils)
  #:use-module (rnrs control)
  #:use-module (srfi srfi-1)
  #:export (
	    do_enter
	    wrap_reset
	    ))


;; Should we prepend wrapped text to the next line?
(define prepend_wrap #f)

;; Someone hits Enter *gasp!*
(define (do_enter undoing)
  (format (current-error-port) "do_enter(): ~s~%" undoing)
  ;;(unless undoing
 ;;	  (add_undo ENTER))
  (let ([newnode (make_new_node (openfile-current))]
	;; Do auto-indenting, like the neolithic Turbo Pascal editor.
	;; If we are breaking the line in the indentation, the new
	;; indentation should have only current_x characters, and
	;; current_x should not change.
	[extra (if (ISSET AUTOINDENT)
		   (min (openfile-current_x)
			(indent_length (openfile-current-data)))
		   0)])
    (format (current-error-port) "do_enter(): orig_line was ~s, orig x was ~s~%" (openfile-current-data) (openfile-current_x))
    (filestruct-data-set! newnode (string-append
				   (make-string extra #\space)
				   (string-copy (openfile-current-data)
						(openfile-current_x))))

    (format (current-error-port) "do_enter(): new node is ~s~%" (filestruct-data newnode))
    (openfile-current-data-set! (substring (openfile-current-data)
					   0
					   (openfile-current_x)))
    (format (current-error-port) "do_enter(): orig_line is now ~s~%" (openfile-current-data))

    (openfile-totsize-set! (+ (openfile-totsize) extra))

    (when (and (openfile-mark_set)
	       (eq? (openfile-current_index) (openfile-mark_begin_index))
	       (< (openfile-current_x) (openfile-mark_begin_x)))
      (openfile-mark_begin_index-set! (1+ (openfile-current_index)))
      (openfile-mark_begin_x-set! (+ (openfile-mark_begin_x)
				     extra
				     (- (openfile-current_x)))))
    (openfile-current_x-set! extra)

    (openfile-fileage-set!
     (append (take (openfile-fileage) (1+ (openfile-current_index)))
	     (list newnode)
	     (drop (openfile-fileage) (1+ (openfile-current_index)))))

    ;; (renumber (openfile-current_index))
    (openfile-current_index-set! (1+ (openfile-current_index)))
    (format (current-error-port) "do_enter(): new line is ~s, new x is ~s~%" (openfile-current-data) (openfile-current_x))

    (openfile-totsize-set! (1+ (openfile-totsize)))
    ;; (set_modified)
    (openfile-placewewant-set! (xplustabs))
    ;; (set! edit_refresh_needed #t)
    )
    )


;; Update an undo item, or determine whether a new one is really
;; needed and bounce the data to add_undo instead.  The latter
;; functionality just feels gimmicky and may just be more hassle than
;; it's worth, so it should be axed if needed.
(define (update_undo action)
  (let ((len 0))
    (cond
     ((not (ISSET UNDOABLE))
      #f)
     (else
      (error "implement me!")))))

;; Unset the prepend_wrap flag.  We need to do this as soo as we do
;; something other than type text.
(define (wrap_reset)
  (set! prepend_wrap #f))