;;; chars.scm
;;;
;;; Copyright (C) 2010 Michael L. Gran
;;; Copyright (C) 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009 Free Software Foundation, Inc.

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

(define-module (gano chars)
  ;;#:use-module (gano nano-h)
  #:use-module ((ncurses extra) #:select (wcwidth))
  #:export (
            is-ascii-control-char?
            is-control-char?
            is-blank-char?
            get-display-char-from-control-char
            count-cells-in-char
            compute-pp-list-from-string
            ))


;; Return #t for the C0 ASCII control characters
(define (is-ascii-control-char? c)
  "#t for codepoints 0 to 31"
  (< (char->integer c) 32))

;; Return #t for all control 8-bit characters
(define (is-control-char? c)
  "#t if this is an ISO control character"
  (char-set-contains? char-set:iso-control c))

(define (is-blank-char? c)
  "#t if this is an blank character"
  (char-set-contains? char-set:blank c))

(define (get-display-char-from-control-char c)
  "The character to use when display controls in \"^X\" form"
  (integer->char (+ (char->integer c) 64)))

;; Given a character CHR and the current column COL, this procedure
;; returns the number of cells that this character will take up.
;; This is usually 1, but, can be 2 for kanji or 1-8 for tabs.
(define* (count-cells-in-char chr #:optional (x 0) (tabSize 8))
  "Number of cells a character CHR at column X would take up. Usually 1, but
can be 2 for kanji or 1-8 for tabs."
  (cond
   ((eqv? chr #\nul)
    0)
   ((eqv? chr #\tab)
    (- tabSize (modulo x tabSize)))
   ((is-control-char? chr)
    ;; Add 1 for the caret '^'
    (1+ (wcwidth (get-display-char-from-control-char chr))))
   (else
    (wcwidth chr))))

;; Given a string, this returns a vector containing the Presentation
;; Position (Pp) of each character of the line
(define* (compute-pp-list-from-string str #:optional (tabsize 8))
  "Given a string, return a list containing the presentation position
of each character in the line"
  (let loop ([pp 0] [lst '()] [str str])
    (cond
     [(not (string-null? str))
      (loop (+ pp (count-cells-in-char (string-ref str 0) pp tabsize))
            (append lst (list pp))
            (string-drop str 1))]
     [else
      ;; return list
      (append lst (list pp))])))
