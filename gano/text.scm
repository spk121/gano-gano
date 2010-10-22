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
  #:use-module (gano CText)
  #:use-module (gano CBuffer)
  #:use-module (gano chars)
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
  (let ([newnode (MakeLine "")]
	;; Do auto-indenting, like the neolithic Turbo Pascal editor.
	;; If we are breaking the line in the indentation, the new
	;; indentation should have only current_x characters, and
	;; current_x should not change.
	[extra (if (ISSET AUTOINDENT)
		   (min (GetBufferXCur)
			(GetIndentILim (GetBufferLineTextCur)))
		   0)])
    (format (current-error-port) "do_enter(): orig_line was ~s, orig x was ~s~%" (GetBufferLineTextCur)
            (GetBufferXCur))
    (SetLineText! newnode (string-append (make-string extra #\space)
                                         (string-copy (GetBufferLineTextCur) (GetBufferXCur))))

    (format (current-error-port) "do_enter(): new node is ~s~%" (GetLineText newnode))
    (SetBufferLineTextCur! (substring (GetBufferLineTextCur) 0 (GetBufferXCur)))
    (format (current-error-port) "do_enter(): orig_line is now ~s~%" (GetBufferLineTextCur))

    (IncreaseBufferTotalSize! extra)

    (when (and (IsBufferMarkSet?)
	       (eq? (GetBufferICur) (GetBufferIMarkBegin))
	       (< (GetBufferXCur) (GetBufferXMarkBegin)))
      (IncreaseBufferIMarkBegin! 1)
      (IncreaseBufferXMarkBegin! (- extra (GetBufferXCur))))

    (SetBufferXCur! extra)

    (SetBufferLines!
     (append (take (GetBufferLines) (1+ (GetBufferICur)))
	     (list newnode)
	     (drop (GetBufferLines) (1+ (GetBufferICur)))))

    ;; (renumber (openfile-current_index))
    (IncreaseBufferICur! 1)

    (format (current-error-port) "do_enter(): new line is ~s, new x is ~s~%" (GetBufferLineTextCur)
            (GetBufferXCur))

    (IncreaseBufferTotalSize! 1)
    ;; (set_modified)
    (SetBufferXGoal! (GetBufferXGoalFromXCur))
    ;; (set! edit_refresh_needed #t)
    ))


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

;; Get index of the first character that isn't whitespace indentation
(define (GetIndentILim str)
  (string-index str (lambda (c) (not (IsBlankChar? c)))))