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
  #:use-module (gano flags)
  #:use-module (gano color)
  #:use-module (rnrs control)
  #:use-module (gano nano-h)
  #:use-module (gano utils)
  #:use-module (gano global)
  #:export (
	    do_rcfile
	    ))

(define SYSCONFDIR "/usr/local/etc")
(define RCFILE_NAME ".nanorc")
;;  Whether we got any errors while parsing an rcfile.
(define errors #f)
;; If we did, the line number where the last error occurred.
(define lineno 0)
(define nanorc #f)
(define endsyntax #f)
(define endheader #f)
(define endcolor #f)

;; We have an error in some part of the rcfile.  Print the error message
;; on stderr, and then make the user hit Enter to continue starting
;; nano.
(define (rcfile_error msg)
  (when (not (ISSET QUIET))
    (format (current-error-port) "~%")
    (when (> lineno 0)
      (set! errors #t)
      (format (current-error-port) "Error in ~a on line ~a: " nanorc lineno))

    (format (current-error-port) "~a~%" msg)))

;; The main rcfile function.  It tried to open the system-wide rcfile, followed
;; by the current user's rcfile.
(define (do_rcfile)
  "Parse the system-wide rcfile, followed by the current user's rcfile"
  (let* ((nanorc (string-append SYSCONFDIR "/nanorc"))
	 (fileinfo (false-if-exception (stat nanorc))))
    ;; Don't open directories, character files, or block files
    (if (and fileinfo
	     (member (stat:type fileinfo)
		     '(directory block-special char-special)))
        ;; Don't open directories, character files, or block files
	(begin
	  (if (eq? 'directory (stat:type fileinfo))
	      (rcfile_error (format #f (_ "\"~a\" is a directory") nanorc))
	      (rcfile_error (format #f (_ "\"~a\" is a device file") nanorc))))
	;; else
	(when (file-exists? nanorc)
	  (with-input-from-file nanorc (lambda () (parse_rcfile #f))))))

  ;; We already read the system nanorc, if it's there.  If we're root,
  ;; and --disable-wrapping-as-root is used, turn wrapping off new
  (when (eq? (geteuid) 0)
    (SET NO_WRAP))

  (get_homedir)

  (if (not homedir)
      (rcfile_error (N_ "I can't find my home directory!  Wah!"))
      ;; else
      (let ((nanorc (string-append homedir "/" RCFILE_NAME))
	    (fileinfo (false-if-exception (stat nanorc))))
	;; Don't open directories, character files, or block files
	(if (and fileinfo
		 (member (stat:type fileinfo)
			 '(directory block-special char-special)))
	    (begin
	      (if (eq? 'directory (stat:type fileinfo))
		  (rcfile_error (format #f (_ "\"~a\" is a directory") nanorc))
		  (rcfile_error (format #f (_ "\"~a\" is a device file") nanorc))))
	    ;; else
	    (when (file-exists? nanorc)
	      (with-input-from-file nanorc (lambda () (parse_rcfile #f)))))))
  (when (and errors (not (ISSET QUIET)))
    (set! error #f)
    (format (current-error-port) (_ "Press Enter to continue starting nano!%"))
    (read-char (current-input-port)))

  (set_colorpairs))


;; Parse the rcfile, once it has been opened sucessfully.  If
;; syntax-only is true, only allow the file to contain color syntax
;; commands: syntax, color, and icolor
(define (parse_rcfile syntax_only)
  #t)