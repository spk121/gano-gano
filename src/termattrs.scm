;;; termattrs.scm -- guile wrapper for curses functions that query the
;;; environment

;;; $Id: termattrs.scm,v 1.1 2007/08/13 13:58:54 spike_gran Exp $

(define-module (ncurses core termattrs)
  #:use-module (ncurses config)
  #:export (	   
	    ;; From termattrs.c
	    baudrate
	    ))

(display "Loading (ncurses core termattrs)")
(newline)

(load-extension (string-append libdir "/" corelib) "gnc_init_termattrs")


