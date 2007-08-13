;;; beep.scm -- guile wrapper for curses bell and screen flash functions 

;;; $Id: beep.scm,v 1.1 2007/08/13 13:58:54 spike_gran Exp $

(define-module (ncurses core beep)
  #:use-module (ncurses config)
  #:export (	   
	    ;; From beep.c
	    beep
	    flash
	    ))

(display "Loading (ncurses core beep)")
(newline)

(load-extension (string-append libdir "/" corelib) "gnc_init_beep")


