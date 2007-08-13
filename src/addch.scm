;;; addch.scm -- wrapper for curses functions that add a character
;;; (with attributes) to a curses window and then advance the cursor

;;; $Id: addch.scm,v 1.1 2007/08/13 05:04:10 spike_gran Exp $

(define-module (ncurses core addch)
  #:use-module (ice-9 optargs)
  #:use-module (ncurses config)
  #:export (	   
	    ;; From addch.c
	    mvwaddch
	    waddch
	    wechochar
	    get-tabsize
	    set-tabsize
	    
	    acs-block 
	    acs-board 
	    acs-btee
	    acs-bullet	   
	    acs-ckboard
	    acs-darrow
	    acs-degree
	    acs-diamond
	    acs-gequal
	    acs-hline 
	    acs-lantern
	    acs-larrow
	    acs-lequal
	    acs-llcorner 
	    acs-lrcorner 
	    acs-ltee
	    acs-nequal
	    acs-pi 
	    acs-plminus
	    acs-plus
	    acs-rarrow
	    acs-rtee
	    acs-s1 
	    acs-s3
	    acs-s7
	    acs-s9
	    acs-sterling
	    acs-ttee
	    acs-uarrow
	    acs-ulcorner
	    acs-urcorner
	    acs-vline

	    ;; From this
	    add-ch
	    echo-char

	    ))

(load-extension corelib "gnc_init_addch")

(define* (add-ch #:key 
		 (win (stdscr))
		 (x #f)
		 (y #f)
		 (ch #f))
  (cond
   ((and x y ch) (mvwaddch win y x ch))
   (ch (waddch win ch))
   (else #f)))


(define* (echo-char #:key
		    (win (stdscr))
		    (ch #f))
  (cond 
   (ch (wechochar win ch))
   (else #f)))
		 
