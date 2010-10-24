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
	    ResetWrap
            GetIndentILim
            UpdateUndo
	    ))


;; Should we prepend wrapped text to the next line?
(define vfWrapPrepend #f)

;; Get index of the first character that isn't whitespace indentation
(define (GetIndentILim str)
  (string-index str (lambda (c) (not (IsBlankChar? c)))))

;; Unset the prepend_wrap flag.  We need to do this as soon as we do
;; something other than type text.
(define (ResetWrap)
  (set! vfWrapPrepend #f))

;; Update an undo item, or determine whether a new one is really
;; needed and bounce the data to add_undo instead.  The latter
;; functionality just feels gimmicky and may just be more hassle than
;; it's worth, so it should be axed if needed.
(define (UpdateUndo action)
  (let ((len 0))
    (cond
     ((not (ISSET UNDOABLE))
      #f)
     (else
      (error "implement me!")))))


