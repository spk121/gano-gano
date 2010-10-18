;;; utils.scm
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

(define-module (gano utils)
  #:use-module (srfi srfi-1)
  #:use-module (gano chars)
  #:use-module (gano nano-h)
  #:use-module (gano global)
  #:use-module (ncurses curses)
  #:export (
            actual_x
            strlenpt
            strnlenpt
            get_page_start
            xplustabs
	    get_homedir
	    new_magicline
	    parse_line_column
            ))

;; Return the index in s of the character displayed at the given
;; column, i.e. the largest value such that strnlenpt(s, actual_x(s,
;; column)) <= column.
(define (actual_x s column)
  (let ((i 0)                       ; The position in s
        (len 0)                    ; The screen display width to s[i]
	(strlen (string-length s)))
    (while (< i strlen)
      ;; (format (current-error-port) "actual_x: s ~a col ~a~%" s column)
      ;; (format (current-error-port) "actual_x: i ~a strlen ~a~%" i strlen)
      ;; (format (current-error-port) "actual_x: len ~a c ~s~%" len (string-ref s i))
      ;; (format (current-error-port) "actual_x: tabsizelen ~a~%" tabsizelen)

      (set! len (+ len (char-width (string-ref s i) len tabsizelen)))
      (if (> len column)
	  (break))
      (set! i (+ i 1)))
    i))

;; Returns the number of cells that the first MAXLEN characters
;; takes up
(define (strnlenpt s maxlen)
  ;; (format #t "s ~a maxlen ~a~%" s maxlen)
  (let loop ((i 0) (width 0))
    ;; (format #t "i ~a width ~a~%" i width)
    (if (< i (min maxlen (string-length s)))
        (begin
          ;; (format #t "i ~a < min(~a,~a) width = ~a~%" i maxlen (string-length s) width)
          (loop (+ i 1) (+ width (char-width (string-ref s i) width tabsizelen))))
        (begin
          ;; (format #t "i ~a >= min(~a,~a)  width = ~a~%" i maxlen (string-length s) width)
          width))))

;; Returns the number of character cells that the string takes up,
;; with tabs and multicolumn character factored in.
(define (strlenpt s)
  (let loop ((i 0) (width 0))
    (if (< i (string-length s))
        (loop (+ i 1) (+ width (char-width (string-ref s i) width tabsizelen)))
        width)))

;; nano scrolls horizontally within a line in chunks.  Return the
;; column number of the first character displayed in the edit window
;; when the cursor is at the given column.  Note that (0 <= column -
;; get_page_start(column) < COLS).
(define (get_page_start column)
  (cond
   ((or (= column 0) (< column (1- (cols))))
    0)
   ((> (cols) 8)
    (+ column -7 (- (remainder (- column 7) (- (cols) 8)))))
   (else
    (- column (- (cols) 2)))))

;; Return the placewewant associated with current_x, i.e. the zero-based
;; column position of the cursor.  The value will be no smaller than
;; current_x.
(define (xplustabs)
  (strnlenpt (openfile-current-data) (openfile-current_x)))

;; Initialize the global variable containing the user's home
;; directory.  We use $HOME, else fall back to the home directory of
;; the effective user ID.
(define (get_homedir)
  (if (not homedir)
      (let ((h (getenv "HOME")))
	(if h
	    (set! homedir h)
	    ;; else
	    (let ((pw (false-if-exception (getpwuid (geteuid)))))
	      (if pw
		  (set! homedir (passwd:dir pw))
		  ;; else
		  ;;   don't know what to set the homedir to
		  ))))))

;; Append a new magicline to filebot
(define (new_magicline)
  (openfile-fileage-set! (append (openfile-fileage)
				 (list (make_new_node (last (openfile-fileage)))))))

(define (parse_line_column str line column)
  (error "Implement me"))