(define-module (gucu core)
  #:use-module (ice-9 optargs)
  #:export (
	    ;; add-character
	    add-character
	    echo-character
	    add-character-string
	    add-string 
	    attributes-off
	    attributes-on
	    attributes-set
	    color-set
	    standout-end
	    standout
	    attributes-get
	    change-attributes
	    beep
	    flash
	    background-set
	    get-background
	    border
	    box
	    horizontal-line
	    vertical-line
	    clear-all
	    clear-to-bottom
	    clear-to-end-of-line
	    delete-character
	    initialize-screen
	    end-window
	    end-window?
	    new-terminal
	    set-terminal
	    delete-screen
	    refresh
	    do-update
	    redraw-window
	    redraw-line
	    new-window
	    delete-window
	    move-window
	    ))

	    


(use-modules ((gucu raw) :renamer (symbol-prefix-proc 'raw:)))

(define *stdscr* #f)

;; These are the helper functions

(define (any->curses-character x)
  (cond
   ((integer? x) x)
   ((char? x) (char->integer x))
   (else (error "Cannot convert ~S to a curses character" x))))

(define (any->curses-character-string x)
  (cond
   ((list? x) x)
   ((string? x) (map-in-order char->integer (string->list x)))
   ((integer? x) (list x))
   ((char? x) (list (char->integer x)))
   (else (error "Cannot convert ~s to a curses character" x))))


(define (ok/err->bool x)
  (cond
   ((eqv? x raw:OK) #t)
   ((eqv? x raw:ERR) #f)
   (else (error "~S is neither OK nor ERR" x))))

(define (err->false x)
  (if (eqv? x ERR)
      #f
      x))

;;; add-wide-character is a in (gucu wide)
;;; add-wide-character-string is in (gucu wide)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; add-character functions


;; Takes CHAR, an 8-bit character or ACS character with attribute
;; flags and adds it to the screen.  Returns #t or #f to indicate
;; success.
(define* (add-character char #:key 
			(window #f)
			(x #f)
			(y #f))
  (let ((ch (any->curses-character char)))
    (cond
     ((not (or window x y))
      (ok/err->bool (raw:addch ch)))
     ((and window (not x) (not y))
      (ok/err->bool (raw:waddch window ch)))
     ((and (not window) x y)
      (ok/err->bool (raw:mvaddch y x ch)))
     ((and window x y)
      (ok/err->bool (raw:mvwaddch window y x ch)))
     (else
      (error "Invalid arguments")))))

;; Takes CHAR, an 8-bit character or ACS character with attribute
;; flags and adds it to the screen, updating immediately.  Returns #t
;; or #f to indicate success.
(define* (echo-character char #:key 
			 (window #f))
  (let ((ch (any->curses-character char)))
    (if window
	(ok/err->bool (raw:wechochar window ch))
	(ok/err->bool (raw:echochar ch)))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; add-character-string functions

;; Takes CHAR, an 8-bit character or ACS character with attribute
;; flags and adds it to the screen.  Returns #t or #f to indicate
;; success.

(define* (add-character-string rawstr #:key 
			       (window #f)
			       (x #f)
			       (y #f)
			       (n #f))
  (let ((str (any->curses-character-string rawstr)))
    (cond
     ((not (or window x y n))
      (ok/err->bool (raw:addchstr str)))
     ((and (not window) (not x) (not y) n)
      (ok/err->bool (raw:addchnstr str n)))
     ((and window (not x) (not y) (not n))
      (ok/err->bool (raw:waddchstr window str)))
     ((and window (not x) (not y) n)
      (ok/err->bool (raw:waddchnstr window str n)))
     ((and (not window) x y (not n))
      (ok/err->bool (raw:mvaddchstr y x str)))
     ((and (not window) x y n)
      (ok/err->bool (raw:mvaddchnstr y x str n)))
     ((and window x y (not n))
      (ok/err->bool (raw:mvwaddchstr window y x str)))
     ((and window x y n)
      (ok/err->bool (raw:mvwaddchnstr window y x str n)))
     (else
      (error "Invalid arguments")))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; add-string functions


(define* (add-string str #:key 
		     (window #f)
		     (x #f)
		     (y #f)
		     (n #f))
  (cond
   ((not (or window x y n))
    (ok/err->bool (raw:addstr str)))
   ((and (not window) (not x) (not y) n)
    (ok/err->bool (raw:addnstr str n)))
   ((and window (not x) (not y) (not n))
    (ok/err->bool (raw:waddstr window str)))
   ((and window (not x) (not y) n)
    (ok/err->bool (raw:waddnstr window str n)))
   ((and (not window) x y (not n))
      (ok/err->bool (raw:mvaddstr y x str)))
   ((and (not window) x y n)
    (ok/err->bool (raw:mvaddnstr y x str n)))
   ((and window x y (not n))
    (ok/err->bool (raw:mvwaddstr window y x str)))
   ((and window x y n)
    (ok/err->bool (raw:mvwaddnstr window y x str n)))
   (else
    (error "Invalid arguments"))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; attribute functions

(define* (attributes-off attr #:key 
			 (window #f))
  
  (cond
   ((not window)
    (ok/err->bool (raw:attroff attr)))
   (window
    (ok/err->bool (raw:wattroff window attr)))
   (else
    (error "Invalid arguments"))))

(define* (attributes-on attr #:key (window #f))
  (cond
   ((not window)
    (ok/err->bool (raw:attron attr)))
   (window
    (ok/err->bool (raw:wattron window attr)))
   (else
    (error "Invalid arguments"))))

(define* (attributes-set attr #:key (window #f))
  (cond
   ((not window)
    (ok/err->bool (raw:attrset attr)))
   (window
    (ok/err->bool (raw:wattrset window attr)))
   (else
    (error "Invalid arguments"))))

(define* (color-set pair-id #:key (window #f))
  (cond
   ((not window)
    (ok/err->bool (raw:color-set pair-id #f)))
   (window
    (ok/err->bool (raw:wcolor-set window pair-id #f)))
   (else
    (error "Invalid arguments"))))

(define* (standout-end #:key (window #f))
  (cond
   ((not window)
    (ok/err->bool (raw:standend)))
   (window
    (ok/err->bool (raw:wstandend (window))))))

(define* (standout #:key (window #f))
  (cond
   ((not window)
    (ok/err->bool (raw:standout)))
   (window
    (ok/err->bool (raw:wstandout (window))))))

(define* (attributes-get #:key (window #f))
  (cond
   ((not window)
    (raw:attr_get))
   (window
    (raw:wattr_get))))

(define* (change-attributes attr color #:key 
			    (window #f)
			    (x #f)
			    (y #f)
			    (n 1))
  (cond
   ((and (not window) (not x) (not y))
    (ok/err->bool (raw:chgat n attr color #f)))
   ((and window (not x) (not y))
    (ok/err->bool (raw:wchgat window n attr color #f)))
   ((and (not window) x y)
    (ok/err->bool (raw:mvchgat y x n attr color #f)))
   ((and window x y)
    (ok/err->bool (raw:mvwchgat window y x n attr color #f)))
   (else
    (error "Invalid arguments"))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; beep functions

(define (beep)
  (ok/err->bool (raw:beep)))

(define (flash)
  (ok/err->bool (raw:flash)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; background functions

(define* (background-set x #:key 
			 (window #f)
			 (global #f))
  (let ((ch (any->curses-character x)))
    (cond
     ((and (not window) (not global))
      (bkgdset ch))
     ((and window (not global))
      (wbkgdset window ch))
     ((and (not window) global)
      (ok/err->bool (raw:bkgd ch)))
     ((and window global)
      (ok/err->bool (raw:wbkgd window ch))))))

(define* (get-background #:key (window #f))
  (cond
   (window 
    (raw:getbkgd window))
   (else
    (raw:getbkgd *stdscr*))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; border functions

(define* (border left right top bottom 
		 top-left top-right bottom-left bottom-right 
		 #:key (window #f))
  (cond
   (window
    (ok/err->bool (raw:wborder window left right top bottom 
			       top-left top-right bottom-left bottom-right)))
   (else
    (ok/err->bool (raw:border left right top bottom 
			      top-left top-right bottom-left bottom-right)))))

(define* (box vert horiz
	      #:key (window #f))
  (cond
   (window
    (ok/err->bool (raw:box window vert horiz)))
   (else
    (ok/err->bool (raw:box *stdscr* vert horiz)))))

(define* (horizontal-line ch #:key 
			  (window #f)
			  (x #f)
			  (y #f)
			  (n (raw:COLS)))
  (cond
   ((and (not window) (not x) (not y))
    (ok/err->bool (raw:hline ch n)))
   ((and window (not x) (not y))
    (ok/err->bool (raw:whline window y x n)))
   ((and (not window) x y)
    (ok/err->bool (raw:mvhline y x ch n)))
   ((and window x y)
    (ok/err->bool (raw:mvwhline window y x ch n)))
   (else
    (error "Invalid arguments"))))

(define* (vertical-line ch #:key 
			(window #f)
			(x #f)
			(y #f)
			(n (raw:LINES)))
  (cond
   ((and (not window) (not x) (not y))
    (ok/err->bool (raw:hline ch n)))
   ((and window (not x) (not y))
    (ok/err->bool (raw:whline window y x n)))
   ((and (not window) x y)
    (ok/err->bool (raw:mvhline y x ch n)))
   ((and window x y)
    (ok/err->bool (raw:mvwhline window y x ch n)))
   (else
    (error "Invalid arguments"))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; clear functions

(define* (clear-all #:key 
		    (window #f)
		    (repaint #f))
  (cond
   ((and (not window) (not repaint))
    (ok/err->bool (raw:erase)))
   ((and window (not repaint))
    (ok/err->bool (raw:werase window)))
   ((and (not window) repaint)
    (ok/err->bool (raw:clear)))
   ((and window repaint)
    (ok/err->bool (raw:wclear window)))))

(define* (clear-to-bottom #:key (window #f))
  (cond
   (window
    (ok/err->bool (raw:wclrtobot window)))
   (else
    (ok/err->bool (raw:clrtobot)))))

(define* (clear-to-end-of-line #:key (window #f))
  (cond
   (window
    (ok/err->bool (raw:wclrtoeol window)))
   (else
    (ok/err->bool (raw:clrtoeol)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; color functions

(define (start-color)
  (ok/err->bool (raw:start-color)))

(define (init-pair pair-id foreground-color background-color)
  (ok/err->bool (raw:init-pair pair-id foreground-color background-color)))

(define (init-color color-id red green blue)
  (ok/err->bool (raw:init-color color-id red green blue)))

(define (has-colors?)
  (raw:has-colors))

(define (can-change-color?)
  (raw:can-change-color))

(define (color-content color-id)
  (raw:color-content color-id))

(define (pair-content pair-id)
  (raw:pair-content pair-id))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; delete-character functions

(define* (delete-character #:key 
			   (window #f)
			   (x #f)
			   (y #f))
  (cond
   ((and (not window) (not x) (not y))
    (ok/err->bool (raw:delch)))
   ((and window (not x) (not y))
    (ok/err->bool (raw:wdelch window)))
   ((and (not window) x y)
    (ok/err->bool (raw:mvdelch y x)))
   ((and window x y)
    (ok/err->bool (raw:mvwdelch window y x)))
   (else
    (error "Invalid arguments"))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; delete-line functions

(define* (delete-line #:key (window #f))
  (cond
   (window
    (ok/err->bool (raw:wdeleteln window)))
   (else
    (ok/err->bool (raw:deleteln)))))

(define* (insert-line #:key (window #f))
  (cond
   (window
    (ok/err->bool (raw:winsertln window)))
   (else
    (ok/err->bool (raw:insertln)))))

(define* (insert-lines n #:key (window #f))
  (cond
   (window
    (ok/err->bool (raw:winsdelln window n)))
   (else
    (ok/err->bool (raw:insdelln n)))))

(define* (delete-lines n #:key (window #f))
  (cond
   (window
    (ok/err->bool (raw:winsdelln window (- n))))
   (else
    (ok/err->bool (raw:insdelln (- n))))))
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; extended functions

(define (curses-version)
  (raw:curses-version))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; get-character functions

(define* (get-character #:key 
			(window #f)
			(x #f)
			(y #f))
  (cond
   ((and (not window) (not x) (not y))
    (err->false (raw:getch)))
   ((and window (not x) (not y))
    (err->false (raw:wgetch window)))
   ((and (not window) x y)
    (err->false (raw:mvgetch y x)))
   ((and window x y)
    (err->false (raw:mvwgetch window y x)))
   (else
    (error "Invalid arguments"))))

(define (return-character-to-queue ch)
  (ok/err->bool (raw:ungetch ch)))

(define (has-key? ch)
  (raw:has-key ch))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; get-string functions

(define* (get-string #:key
		     (window #f)
		     (x #f)
		     (y #f)
		     (n #f))
  (cond
   ((and (not window) (not x) (not y) (not n))
    (raw:getstr))
   ((and window (not x) (not y) (not n))
    (raw:wgetstr window))
   ((and (not window) x y (not n))
    (raw:mvgetstr y x))
   ((and window x y (not n))
    (raw:mvwgetstr win y x))
   ((and (not window) (not x) (not y) n)
    (raw:getnstr n))
   ((and window (not x) (not y) n)
    (raw:wgetnstr win n))
   ((and (not window) x y n)
    (raw:mvgetnstr y x n))
   ((and window x y n)
    (raw:mvwgetnstr win y x n))
   (else
    (error "Invalid arguments"))))
		     

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; get-yx functions

(define (get-cursor-coordinates #:key (window *stdscr*))
  (raw:getyx window))

(define (get-window-coordinates-relative-to-parent #:key (window *stdscr*))
  (raw:getparyx window))

(define (get-window-coordinates #:key (window *stdscr*))
  (raw:getbegyx))

(define (get-window-size #:key (window *stdscr*))
  (raw:getmaxyx))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; inch functions

(define (get-character-from-window #:key 
				   (window #f)
				   (x #f)
				   (y #f))
  (cond
   ((and (not window) (not x) (not y))
    (raw:inch))
   ((and window (not x) (not y))
    (raw:winch window))
   ((and (not window) x y)
    (raw:mvinch y x))
   ((and window x y)
    (raw:mvwinch window y x))
   (else
    (error "Invalid arguments"))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; inchstr functions
(define (get-characters-from-window #:key 
				    (window #f)
				    (x #f)
				    (y #f)
				    (n #f))
  (cond
   ((and (not window) (not x) (not y) (not n))
    (raw:inchstr))
   ((and window (not x) (not y) (not n))
    (raw:winchstr window))
   ((and (not window) x y (not n))
    (raw:mvinchstr y x))
   ((and window x y (not n))
    (raw:mvwinchstr window y x))
   ((and (not window) (not x) (not y) n)
    (raw:inchnstr))
   ((and window (not x) (not y) n)
    (raw:winchnstr window))
   ((and (not window) x y n)
    (raw:mvinchnstr y x))
   ((and window x y n)
    (raw:mvwinchnstr window y x))
   (else
    (error "Invalid arguments"))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; initialize-screen functions

(define (initialize-screen)
  (set! *stdscr* (raw:initscr)))

(define (end-window)
  (ok/err->bool (raw:endwin)))

(define (end-window? w)
  (raw:isendwin x))

(define (new-terminal type out in)
  (raw:newterm type out in))

(define (set-terminal new)
  (raw:setterm new))

(define (delete-screen sc)
  (raw:delscreen sc))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; input-options functions

(define (screen-newline-on)
  (ok/err->bool (raw:nl)))

(define (screen-newline-off)
  (ok/err->bool (raw:nonl)))

(define (screen-raw-on)
  (ok/err->bool (raw:raw)))

(define (screen-raw-off)
  (ok/err->bool (raw:noraw)))

(define (screen-cbreak-on)
  (ok/err->bool (raw:cbreak)))

(define (screen-cbreak-off)
  (ok/err->bool (raw:nocbreak)))

(define (screen-cbreak-half-delay t)
  (ok/err->bool (raw:halfdelay t)))

(define (screen-echo-on)
  (ok/err->bool (raw:echo)))

(define (screen-echo-off)
  (ok/err->bool (raw:noecho)))

(define (screen-meta-on)
  (ok/err->bool (raw:meta *stdscr* #t)))

(define (screen-meta-off)
  (ok/err->bool (raw:meta *stdscr* #f)))

(define (screen-keypad-on)
  (ok/err->bool (raw:keypad *stdscr* #t)))

(define (screen-keypad-off)
  (ok/err->bool (raw:keypad *stdscr #f)))

(define (screen-queue-flush-on-interrupt-on)
  (ok/err->bool (raw:qiflush)))

(define (screen-queue-flush-on-interrupt-off)
  (ok/err->bool (raw:noqiflush)))

(define (window-input-delay-on window)
  (ok/err->bool (raw:nodelay window #f)))

(define (window-input-delay-off window)
  (ok/err->bool (raw:nodelay window #t)))

(define (window-timeout-off window)
  (ok/err->bool (raw:notimeout window #t)))

(define (window-timeout-on window)
  (ok/err->bool (raw:notimeout window #f)))

(define (window-timeout-timer window t)
  (ok/err->bool (raw:wtimeout window t)))


(define (flush-on-interrupt)
  (ok/err->bool (raw:intrflush *stdscr* #t)))

(define (no-flush-on-interrupt)
  (ok/err->bool (raw:intrflush *stdscr* #f)))

(define* ( #:key (window *stdscr*))
  (ok/err->bool (raw:keypad window #t)))

(define* (disable-keypad #:key (window *stdscr*))
  (ok/err->bool (raw:keypad window #f)))

(define (enable-eight-bit-input)
  (ok/err->bool (raw:meta *stdscr* #t)))

(define (enable-seven-bit-input)
  (ok/err->bool (raw:meta *stdscr* #f)))

(define (enable-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; refresh functions

(define* (refresh #:key 
		  (window #f)
		  (no-output #f))
  (cond
   ((and (not window) (not no-output))
    (ok/err->bool (raw:refresh)))
   ((and window (not no-output))
    (ok/err->bool (raw:wrefresh window)))
   ((and (not window) no-output)
    (ok/err->bool (raw:noutrefresh *stdscr*)))
   ((and window no-output)
    (ok/err->bool (raw:noutrefresh win)))))

(define (do-update)
  (ok/err->bool (raw:doupdate)))

(define* (redraw-window #:key (window #f))
  (cond
   (window
    (ok/err->bool (raw:redrawwin window)))
   (else
    (ok/err->bool (raw:redrawwin *stdscr*)))))


(define* (redraw-line line #:key (window #f) (n 1))
  (cond
   (window
    (ok/err->bool (raw:wredrawln window line n)))
   (else
    (ok/err->bool (raw:wredrawln *stdscr* line n)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; window functions

(define (new-window num-lines num-cols begin-y begin-x)
  (raw:newwin num-lines num-cols begin-y begin-x))

(define (delete-window window)
  (ok/err->bool (raw:delwin window)))

(define (move-window window y x)
  (ok/err->bool (rawmvwin window y x)))






  