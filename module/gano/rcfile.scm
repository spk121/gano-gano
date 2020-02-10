;;; rcfile.scm
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

(define-module (gano rcfile)
  #:use-module (gano config)
  #:use-module (gano flags)
  #:use-module (gano config)
  #:use-module (gano utils)
  #:use-module (gano global)
  #:use-module (rnrs control)
  #:export (
	    load-rcfile
	    ))

;; The main rcfile function.  It tried to open the system-wide rcfile, followed
;; by the current user's rcfile.
(define (load-rcfile)
  "Parse the system-wide rcfile, followed by the current user's rcfile"
  (let* ([systemRc (string-append %vDirSysConf "/ganorc")])

    (when (is-regular-file? systemRc)
	  ;; (format #t "Is ~a a regular file? ~a~%" systemRc (is-regular-file? systemRc))
	  (primitive-load systemRc)))

  ;; We already read the system ganorc, if it's there.  If we're root,
  ;; and --disable-wrapping-as-root is used, turn wrapping off anew.
  (when (eq? (geteuid) 0)
    (SET NO_WRAP))

  (InitDirHome)

  (if (not vDirHome)
      (format (current-error-port) "Can't find home directory.~%")
      ;; else
      (let ([ganoRc (string-append vDirHome "/.nanorc")])
        (when (is-regular-file? ganoRc)
	      (primitive-load ganoRc)))))

;; Returns #t if FILENAME is a regular file
(define (is-regular-file? fileName)
  (let ([fileInfo (false-if-exception (stat fileName))])
    ;; Don't open directories, character files, or block files
    (if (and fileInfo
             (member (stat:type fileInfo)
                     '(directory block-special char-special)))
        ;; Don't open directories, character files, or block files
        (begin
          (if (eq? 'directory (stat:type fileInfo))
              (format (current-error-port) "\"~a\" is a directory" fileName)
              (format (current-error-port) "\"~a\" is a device file" fileName))
          #f)
        ;; else
        (file-exists? fileName))))
