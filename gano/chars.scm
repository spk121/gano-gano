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
  #:use-module (ncurses extra)
  #:export (
	    utf8_init
	    char-width
	    is_ascii_cntrl_char
	    is_cntrl_char
	    control_rep
	    ))

;; Whether we've enabled UTF-8 support.  In Gano (and not in Nano)
;; if this is true, we assume Guile 2.0.x and UCS-4 chars.  If this
;; is false, we assume Guile 1.8.x and 8-bit locale chars.  Otherwise,
;; we don't do any of the mbchar processing.
(define use_utf8 #f)

(define (utf8_init)
  "Enable UTF-8 support."
  (set! use_utf8 #t))

#!
;; Is UTF-8 support enabled?
(define (using_utf8)
  use_utf8)
!#

#!
;; Return #t if c is in byte range.
(define (is_byte c)
  (< (char->integer c) 256))
!#

;; Return #t for the C0 ASCII control characters
(define (is_ascii_cntrl_char c)
  (let ((n (char->integer c)))
    (and (<= 0 n) (< n 32))))

;; Return #t for all control 8-bit characters
(define (is_cntrl_char c)
  (char-set-contains? char-set:iso-control c))

;; c is a control character.  It displays as ^@, ^?, or ^[ch] where
;; ch is c + 64.
(define (control_rep c)
  ;; Treat newlines embedded in a line as encoded nulls
  (cond
   ((eq? c #\newline)
    #\@)
   ((eq? c #\delete)
    (#\?))
   (else
    (integer->char (+ (char->integer c) 64)))))

;; Given a character CHR and the current column COL, this procedure
;; returns the number of cells that this character will take up.
;; This is usually 1, but, can be more for wide characters, kanji,
;; tabs, etc.
(define (char-width chr col tabsizelen)
  (cond
   ((eq? chr #\nul)
    0)
   ((eq? chr #\tab)
    (+ tabsizelen (- (modulo col tabsizelen))))
   ((is_cntrl_char chr)
    (+ 1 (control_rep chr)))
   (else
    (wcwidth chr))))

