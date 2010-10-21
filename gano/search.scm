;;; search.scm
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

(define-module (gano search)
  #:use-module (gano records)
  #:use-module (gano global)
  #:use-module (srfi srfi-1)
  #:export (
	    history_init
	    do_gotolinecolumn
	    ))

(define (history_init)
  "Initialize the search and replace history lists."
  (set! search_history (list (make_new_node #f)))
  (filestruct-data-set! (first search_history) "")
  (set! search_history_index 0)

  (set! replace_history (list (make_new_node #f)))
  (filestruct-data-set! (first replace_history) "")
  (set! replace_history_index 0))

;; Go to the specified line and column, or ask for them if interactive
;; is TRUE.  Save the x-coordinate and y-coordinate if save_pos is TRUE.
;; Update the screen afterwards if allow_update is TRUE.  Note that both
;; the line and column numbers should be one-based. */
(define (do_gotolinecolumn line column use_answer interactive save_pos
			   allow_update)
  (error "implement me!"))
