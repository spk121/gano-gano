;;; terminfo.scm -- guile wrapper for curses function that query the
;;; terminfo database

;; $Id: terminfo.scm,v 1.1 2007/08/17 14:27:57 spike_gran Exp $

(define-module (ncurses terminfo)
  #:use-module (ncurses config)
  #:export (
	    ;; From terminfo.c
	    setupterm
	    ))

(load-extension (string-append libdir "/" corelib) "gnc_init_terminfo")

