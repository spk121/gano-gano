#!/usr/bin/guile \
--debug -s
!#

(use-modules (ice-9 getopt-long)
	     (ice-9 debug)
	     (gucu curses)
	     (gucu menu)
	     (srfi srfi-1))

(define (menu-virtualize c)
  (let ((char-n (char->integer #\n))
	(char-u (char->integer #\u))
	(char-d (char->integer #\d))
	(char-b (char->integer #\b))
	(char-f (char->integer #\f))
	(char-r (char->integer #\r))
	(req-exit (+ MAX_COMMAND 1)))

    ;; Convert a keypress into a menu request
    (cond 
     ((eqv? c char-n)                req-exit)
     ((eqv? c KEY_EXIT)              req-exit)
     ((eqv? c char-u)                REQ_SCR_ULINE)
     ((eqv? c char-d)                REQ_SCR_DLINE)
     ((eqv? c char-b)                REQ_SCR_UPAGE)
     ((eqv? c KEY_NPAGE)             REQ_SCR_UPAGE)
     ((eqv? c char-f)                REQ_SCR_DPAGE)
     ((eqv? c KEY_PPAGE)             REQ_SCR_DPAGE)
     ((eqv? c KEY_LEFT)              REQ_LEFT_ITEM)
     ((eqv? c char-r)                REQ_RIGHT_ITEM)
     ((eqv? c KEY_RIGHT)             REQ_RIGHT_ITEM)
     ((eqv? c KEY_UP)                REQ_PREV_ITEM)
     ((eqv? c KEY_DOWN)              REQ_NEXT_ITEM)
     (else c))))

;; Compute the first column of Nth submenu
(define (menu-offset menubar n)
  (let* ((ms (menu-spacing menubar))
	 (spc-rows (second ms)))
    (* n 
       (+ spc-rows (menu-itemlen menubar)))))

;; Create a single-row, horizontal menu at the top of screen
(define (menubar-create labels)
  (let* ((y 0)
	 (x 0)
	 (maxrow 1)
	 (items (map-in-order (lambda (name)
				(new-item name ""))
			      labels))
	 (m (new-menu items)))
    (if (has-colors?)
	(begin
	  (set-menu-fore! m (color-pair 1))
	  (set-menu-back! m (color-pair 2))))
    (set-menu-format! m maxrow (cols))
    (let* ((scale (scale-menu m))
	   (mrows (first scale))
	   (mcols (second scale))
	   (menuwin (newwin mrows mcols y x)))
      (set-menu-win! m menuwin)
      (keypad menuwin #t)
      (set-menu-sub! m (derwin menuwin mrows mcols 0 0)))
    (post-menu m)
    m))

;; Create a single-column, vertical menu that is aligned so that it is
;; under the NUMBERth entry in the MENUBAR. 
(define (submenu-create menubar labels number)
  (let* ((y 1)
	 (x (menu-offset menubar number))
	 (margin 1)
	 (maxrow (min (length labels)
		      (- (lines) 4)))
	 (items (map-in-order (lambda (name)
				(new-item name ""))
			      labels))
	 (m (new-menu items)))
    (if (has-colors?)
	(begin
	  (set-menu-fore! m (color-pair 1))
	  (set-menu-back! m (color-pair 2))))
    ;; Set the menu to be vertical 
    (set-menu-format! m maxrow 1)

    ;; Get the size of the menu from curses, and create the two
    ;; concentric windows.  The outer window contains the frame, and
    ;; the inner contains the menu items.
    (let* ((scale (scale-menu m))
	   (mrows (first scale))
	   (mcols ((lambda (temp-mcols)
		     (if (>= (+ temp-mcols 2 x) (cols))
			 (- (cols) (+ 2 x))
			 temp-mcols))
		   (second scale))) ; this is 'temp-mcols' for lambda
	   (menuwin (newwin (+ mrows 2)
			    (+ mcols 2)
			    y 
			    x)))
      (set-menu-win! m menuwin)
      (color-box menuwin 2)
      (set-menu-sub! m (derwin menuwin mrows mcols 1 1)))
    (post-menu m)
    m))

(define (menu-display menu)
  (let ((win (menu-win menu)))
    (touchwin win)
    (refresh win)))

;; Draws a box in keeping with a given color pair
(define (color-box win pairno)
  (if (has-colors?)
      (border win
	      (logior (acs-vline) (color-pair pairno)) 
	      (logior (acs-vline) (color-pair pairno)) 
	      (logior (acs-hline) (color-pair pairno))
	      (logior (acs-hline) (color-pair pairno))
	      (logior (acs-ulcorner) (color-pair pairno))
	      (logior (acs-urcorner) (color-pair pairno))
	      (logior (acs-llcorner) (color-pair pairno))
	      (logior (acs-lrcorner) (color-pair pairno)))
      (box win 0 0)))

;; Returns an numeric index of which submenu is current.
(define (menu-number menubar)
  (item-index (current-item menubar)))

;; Create the menubar, adding a mark and making sure that it
;; interprets the function keys.
(define (build-menubar labels)
  (let ((menubar (menubar-create labels)))
    (set-menu-mark! menubar ">")
    (keypad (menu-win menubar) #t)
    menubar))

;; The default driver returns a command code from the menu, or if an
;; item has been selected, it returns E_UNKNOWN_COMMAND.
(define (default-driver menu)
  (lambda (cmd)
    (menu-driver menu cmd)))

(define (show-status mainwin ch menu)
  (move mainwin (- (lines) 1) 0)
  (addstr mainwin (format #f "key ~a, mark ~a, match ~a"
			  (keyname ch)
			  (menu-mark menu)
			  (menu-pattern menu)))
  (clrtoeol mainwin)
  (refresh mainwin))

;; This is the main loop.
(define (perform-menus mainwin menubar submenus handlers)
  (let ((last-menu (first submenus))
	(this-menu (first submenus))
	(code E_UNKNOWN_COMMAND)
	(ch ERR))

    (menu-display last-menu)

    (while #t
	   (if (not (eqv? ch ERR))
	       (show-status mainwin ch last-menu)
	       #t)

	   (set! ch (getch (menu-win menubar)))

	   (let* ((cmd (menu-virtualize ch))
		  (code #f))

	     (cond 
	      ;; Handle moving left and right between submenus.  This
	      ;; request is always handled by the menubar.
	      ((or (eqv? cmd REQ_LEFT_ITEM) (eqv? cmd REQ_RIGHT_ITEM))
	       (begin
		 (set! code (menu-driver menubar cmd))

		 ;; "Denied" means you tried to move off the end of
		 ;; the menu.  This allows you to wrap around.
		 (if (eqv? code E_REQUEST_DENIED)
		     (if (> (menu-number menubar) 0)
			 (set! code (menu-driver menubar REQ_FIRST_ITEM))
			 (set! code (menu-driver menubar REQ_LAST_ITEM))))))
	      (else
	       ;; Other requests are handled by the submenu's handlers
	       (set! code ((list-ref handlers (menu-number menubar)) cmd))
	       (if (and (eqv? code E_REQUEST_DENIED) (eqv? cmd KEY_MOUSE))
		   (set! code (menu-driver menubar cmd)))))
	     
	     ;; If we've moved between submenus, redraw them
	     (if (eqv? code E_OK)
		 (begin
		   (set! this-menu (list-ref submenus (menu-number menubar)))
		   (if (not (eqv? this-menu last-menu))
		       (begin
			 (move mainwin 1 0)
			 (clrtobot mainwin)
			 (color-box (menu-win this-menu) 2)
			 (refresh mainwin)
			 (menu-display this-menu)
			 (set! last-menu this-menu)))))

	     ;; In any case, refresh the current menu
	     (refresh (menu-win last-menu))

	     ;; E_UNKNOWN_COMMAND means that a menu selection was made, 
	     ;; and the handler didn't intercept it or do anything with it.
	     (if (or (eqv? code E_UNKNOWN_COMMAND) (eqv? code E_NOT_POSTED))
		 (begin
		   (move mainwin 20 0)
		   (addstr mainwin 
			   (format #f "You selected ~S" 
				   (item-name (current-item this-menu))))
		   (refresh mainwin)
		   (beep)
		   (sleep 3)
		   (break)))
	     (if (eqv? code E_REQUEST_DENIED)
		 (beep))
	     (continue)))))

(define (destroy-menus)
  ;;(free-menu *m-file*)
  ;;(free-menu *m-select*)
  ;;(free-menu *m-banner*)
  #t
  )


(define (main args)
  (let* ((option-spec '((version (single-char #\v) (value #f))
			(help    (single-char #\h) (value #f))))
	 (options (getopt-long args option-spec))
	 (help-wanted (option-ref options 'help #f))
	 (version-wanted (option-ref options 'version #f)))
    (if (or version-wanted help-wanted)
	(begin
	  (if version-wanted
	      (display "demo_menus version 0.0\n"))
	  (if help-wanted
	      (display "\
     demo_menus [options]
       -v, --version    Display version
       -h, --help       Display this help
     "))))
    (setlocale LC_ALL "")
    (let ((mainwin (initscr)))
      (noraw)
      (cbreak)
      (noecho)
      (if (has-colors?)
	  (begin
	    (start-color)
	    (init-pair 1 COLOR_WHITE COLOR_BLUE)
	    (init-pair 2 COLOR_BLACK COLOR_WHITE)))
      (let* ((menubar (build-menubar '("File" "Edit" "Help")))
	     (menu-file (submenu-create menubar '("Open" "Close" "Exit") 0))
	     (menu-edit (submenu-create menubar '("Cut" "Copy" "Paste") 1))
	     (menu-help (submenu-create menubar '("Help" "About") 2))
	     (menu-driver-file (default-driver menu-file))
	     (menu-driver-edit (default-driver menu-edit))
	     (menu-driver-help (default-driver menu-help)))
	
	(perform-menus mainwin 
		       menubar 
		       (list menu-file 
			     menu-edit
			     menu-help)
		       (list menu-driver-file 
			     menu-driver-edit 
			     menu-driver-help))
	(destroy-menus)
	(endwin)))))



(main (program-arguments))