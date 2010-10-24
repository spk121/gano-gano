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
  #:use-module (gano CText)
  #:use-module (gano CBuffer)
  #:use-module (srfi srfi-1)
  #:use-module (gano chars)
  #:use-module (gano nano-h)
  #:use-module (gano global)
  #:use-module (ncurses curses)
  #:use-module (rnrs control)
  #:export (
            GetIndexFromStringCell
            CountCellsInString
            CountCellsInSubstring
            get_page_start
            GetBufferXGoalFromXCur
	    InitDirHome
	    ParseLineColumn
            ))

;; Return the index in s of the character displayed at the given]
;; column, i.e. the largest value such that strnlenpt(s, actual_x(s,
;; column)) <= column.
(define (GetIndexFromStringCell str xLim)
  (let ([i 0]                       ; The position in s
        [x 0]                    ; The screen display width to s[i]
	[iLim (string-length str)])
    (while (< i iLim)
      ;; (format (current-error-port) "actual_x: s ~a col ~a~%" s column)
      ;; (format (current-error-port) "actual_x: i ~a iLim ~a~%" i iLim)
      ;; (format (current-error-port) "actual_x: len ~a c ~s~%" len (string-ref s i))
      ;; (format (current-error-port) "actual_x: vTabSize ~a~%" vTabSize)

      (set! x (+ x (CountCellsInChar (string-ref str i) x vTabSize)))
      (if (> x xLim)
	  (break))
      (set! i (+ i 1)))
    i))

;; Returns the number of cells that the first MAXLEN characters
;; takes up
(define (CountCellsInSubstring str n)
  "Number of screen cells occupied by the first N characters of a string"
  (CountCellsInString (substring str 0 n)))

;; Returns the number of character cells that the string takes up,
;; with tabs and multicolumn character factored in.
(define (CountCellsInString str)
  "Number of screen cells occupied by a string"
  (let ([iLim (string-length str)]
        [x 0])
    (do ([i 0 (1+ i)]) ([>= i iLim])
      (set! x (+ x (CountCellsInChar (string-ref str i) x vTabSize))))
    (format (current-error-port) "CountCellsInString: str ~s count ~s~%" str x)
    x))

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
(define (GetBufferXGoalFromXCur)
  (let* ([st (GetLineText (GetBufferLineCur))]
         [x (GetBufferXCur)]
         [goal (CountCellsInSubstring (GetLineText (GetBufferLineCur)) x)])
    (format (current-error-port) "GetBufferXGoal... st ~s x ~s goal ~s~%" st x goal)
    goal))

;; Initialize the global variable containing the user's home
;; directory.  We use $HOME, else fall back to the home directory of
;; the effective user ID.
(define (InitDirHome)
  (when (not vDirHome)
    (let ([h (getenv "HOME")]
          [pw (false-if-exception (getpwuid (geteuid)))])
      (cond [h (set! vDirHome h)]
            [pw (set! vDirHome (passwd:dir pw))]))))

;; Append a new empty line to the bottom of the file.  Don't know why this
;; is called a magic line.
(define (ParseLineColumn str line column)
  (error "Implement me"))