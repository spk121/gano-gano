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
	    InitUtf8
            CountCellsInChar
            GetDisplayCharFromControlChar
            IsAsciiControlChar?
            IsBlankChar?
            IsControlChar?
            IsLatin1Char?
            ))

;; Whether we've enabled UTF-8 support.  In Gano (and not in Nano)
;; if this is true, we assume Guile 2.0.x and UCS-4 chars.  If this
;; is false, we assume Guile 1.8.x and 8-bit locale chars.  Otherwise,
;; we don't do any of the mbchar processing.
(define vfUtf8Enabled #f)

(define (InitUtf8)
  "Enable UTF-8 support."
  (set! vfUtf8Enabled #t))

#!
;; Is UTF-8 support enabled?
(define (using_utf8)
  Utf8EnabledP)
!#

;; Return #t if c is in byte range.
(define (IsLatin1Char? c)
  (< (char->integer c) 256))

;; Return #t for the C0 ASCII control characters
(define (IsAsciiControlChar? c)
  "#t for codepoints 0 to 31"
  (< (char->integer c) 32))

;; Return #t for all control 8-bit characters
(define (IsControlChar? c)
  "#t if this is an ISO control character"
  (char-set-contains? char-set:iso-control c))

(define (IsBlankChar? c)
  "#t if this is an ISO control character"
  (char-set-contains? char-set:blank c))

(define (GetDisplayCharFromControlChar c)
  "The character to use when display controls in \"^X\" form"
  (integer->char (+ (char->integer c) 64)))

;; Given a character CHR and the current column COL, this procedure
;; returns the number of cells that this character will take up.
;; This is usually 1, but, can be 2 for kanji or 1-8 for tabs.
(define (CountCellsInChar chr x tabSize)
  "Number of cells a character CHR at column X would take up"
  (cond
   [(eqv? chr #\nul)
    0]
   [(eqv? chr #\tab)
    (- tabSize (modulo x tabSize))]
   [(IsControlChar? chr)
    ;; Add 1 for the caret '^'
    (1+ (wcwidth (GetDisplayCharFromControlChar chr)))]
   [else
    (wcwidth chr)]))

