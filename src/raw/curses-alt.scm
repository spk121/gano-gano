;; -*- Mode: scheme; -*-
(define-module (gucu curses-alt)
  #:use-module (ice-9 optargs)
  #:use-module (gucu curses)
  #:re-export ( 
	       ;; from addch
	       *a-altcharset*
	       *a-attributes*
	       *a-blink*
	       *a-bold*
	       *a-chartext*
	       *a-color*
	       *a-dim*
	       *a-invis*
	       *a-normal*
	       *a-protect*
	       *a-reverse*
	       *a-standout*
	       *a-underline*
	       acs-block
	       acs-board
	       acs-btee
	       acs-bullet
	       acs-ckboard
	       acs-darrow
	       acs-degree
	       acs-diamond
	       acs-hline
	       acs-lantern
	       acs-larrow
	       acs-llcorner
	       acs-lrcorner
	       acs-ltee
	       acs-plminus
	       acs-plus
	       acs-rarrow
	       acs-rtee
	       acs-s1
	       acs-s9
	       acs-ttee
	       acs-uarrow
	       acs-ulcorner
	       acs-urcorner
	       acs-vline
	       tabsize
	       set-tabsize

	       ;; from colors
	       color-content
	       pair-content
	       colors
	       color-pairs
	       *color-black*
	       *color-green*
	       *color-red*
	       *color-yellow*
	       *color-blue*
	       *color-magenta*
	       *color-cyan*
	       *color-white*

	       ;; from extend
	       curses-version

	       ;; from getch
	       *key-code-yes*
	       *key-min*
	       *key-break*
	       *key-sreset*
	       *key-reset*
	       *key-down*
	       *key-up*
	       *key-left*
	       *key-right*
	       *key-home*
	       *key-backspace*
	       *key-f0*
	       *key-dl*
	       *key-il*
	       *key-dc*
	       *key-ic*
	       *key-eic*
	       *key-clear*
	       *key-eos*
	       *key-eol*
	       *key-sf*
	       *key-sr*
	       *key-npage*
	       *key-ppage*
	       *key-stab*
	       *key-ctab*
	       *key-catab*
	       *key-enter*
	       *key-print*
	       *key-ll*
	       *key-a1*
	       *key-a3*
	       *key-b2*
	       *key-c1*
	       *key-c3*
	       *key-btab*
	       *key-beg*
	       *key-cancel*
	       *key-close*
	       *key-command*
	       *key-copy*
	       *key-create*
	       *key-end*
	       *key-exit*
	       *key-find*
	       *key-help*
	       *key-mark*
	       *key-message*
	       *key-move*
	       *key-next*
	       *key-open*
	       *key-options*
	       *key-previous*
	       *key-redo*
	       *key-reference*
	       *key-refresh*
	       *key-replace*
	       *key-restart*
	       *key-resume*
	       *key-save*
	       *key-sbeg*
	       *key-scancel*
	       *key-scommand*
	       *key-scopy*
	       *key-screate*
	       *key-sdc*
	       *key-sdl*
	       *key-select*
	       *key-send*
	       *key-seol*
	       *key-sexit*
	       *key-sfind*
	       *key-shelp*
	       *key-shome*
	       *key-sic*
	       *key-sleft*
	       *key-smessage*
	       *key-smove*
	       *key-snext*
	       *key-soptions*
	       *key-sprevious*
	       *key-sprint*
	       *key-sredo*
	       *key-sreplace*
	       *key-sright*
	       *key-srsume*
	       *key-ssave*
	       *key-ssuspend*
	       *key-sundo*
	       *key-suspend*
	       *key-undo*
	       *key-mouse*
	       *key-resize*
	       *key-event*

	       )
  #:export (
	    ;; from addch
	    add-rendered-char
	    echo-rendered-char

	    ;; from addchstr
	    add-rendered-string

	    ;; from addstr
	    add-string

	    ;; from attr
	    attributes-get
	    attributes-on
	    attributes-off
	    attributes-set
	    attributes-clear
	    attributes-standout
	    color-pair-get
	    color-pair-set
	    change-rendition

	    ;; from beep
	    beep
	    flash

	    ;; from bkgd
	    get-background
	    set-background
	    apply-background

	    ;; from border
	    border
	    box
	    hline
	    vline

	    ;; from clear
	    erase
	    clear
	    clear-to-bottom
	    clear-to-eol

	    ;; from color
	    start-color
	    set-color-pair!
	    set-color!
	    has-colors?
	    can-change-color?

	    ;; from delch
	    delete-char

	    ;; from deleteln
	    delete-line
	    insert-line
	    insert-or-delete-lines

	    ;; from getch
	    get-char
	    unget-char
	    has-key

	    ;; from getstr
	    get-string

	    ;; from getyx
	    cursor-position
	    window-position-relative-to-parent
	    window-position
	    window-size

	    ;; from inch
	    extract-rendered-char

	    ;; from inchstr
	    extract-rendered-string

	    ;; from initscr
	    initialize-windows
	    suspend-windows
	    windows-suspended?
	    new-terminal
	    set-terminal
	    delete-terminal

	    ;; from inopts
	    cbreak
	    no-cbreak
	    echo
	    no-echo
	    raw
	    no-raw
	    queue-interrupt-flush
	    no-queue-interrupt-flush
	    interrupt-flush
	    keypad
	    meta
	    no-delay
	    no-timeout
	    timeout
	    type-ahead
	    
	    ;; from insch
	    insert-char

	    ;; from insstr
	    insert-string
	    
	    ;; from instr
	    extract-string

	    ;; from kernel
	    define-program-mode
	    define-shell-mode
	    reset-program-mode
	    reset-shell-mode
	    reset-tty
	    save-tty
	    virtual-cursor-position
	    set-virtual-cursor-position
	    

	    ;; from mouse
	    get-mouse
	    unget-mouse
	    mouse-mask
	    is-in-window?
	    stdscr-pos->screen-pos
	    mouse-click-interval

	    ;; from move
	    set-cursor-position
	    
	    ))


;;-------------------------
;; from addch

(define* (add-rendered-char ch #:key win y x)
  (if (eqv? *ok*
	    (cond
	     ((and (not win) (not y) (not x))
	      (addch ch))
	     ((and win (not y) (not x))
	      (waddch win ch))
	     ((and (not win) y x)
	      (mvaddch y x ch))
	     ((and win y x)
	      (mvwaddch win y x ch))
	     (else
	      "Invalid combination of optional arguments")))
      #t
      #f))

(define* (echo-rendered-char ch #:key win)
  (if (eqv? *ok*
	    (cond
	     (win
	      (wechochar win ch))
	     (else
	      (echochar win))))
      #t
      #f))

;;-------------------------
;; from addchstr

(define* (add-rendered-string chstr #:key win y x n)
  (if (eqv? *ok*
	    (cond
	     ((and (not win) (not y) (not x) (not n))
	      (addchstr chstr))
	     ((and (not win) (not y) (not x) n)
	      (addchnstr chstr n))
	     ((and win (not y) (not x) (not n))
	      (addchstr win chstr))
	     ((and win (not y) (not x) n)
	      (addchnstr win chstr n))
	     ((and (not win) y x (not n))
	      (mvaddchstr y x chstr))
	     ((and (not win) y x n)
	      (mvaddchnstr y x chstr n))
	     ((and win y x (not n))
	      (mvwaddchstr win y x chstr))
	     ((and win y x n)
	      (mvwaddchnstr win y x chstr n))
	     (else
	      (error "Invalid combination of optional arguments"))))
      #t
      #f))

;;-------------------------
;; from addstr

(define* (add-string str #:key win y x n)
  (if (eqv? *ok*
	    (cond
	     ((and (not win) (not y) (not x) (not n))
	      (addstr str))
	     ((and (not win) (not y) (not x) n)
	      (addnstr str n))
	     ((and win (not y) (not x) (not n))
	      (addstr win str))
	     ((and win (not y) (not x) n)
	      (addnstr win str n))
	     ((and (not win) y x (not n))
	      (mvaddstr y x str))
	     ((and (not win) y x n)
	      (mvaddnstr y x str n))
	     ((and win y x (not n))
	      (mvwaddstr win y x str))
	     ((and win y x n)
	      (mvwaddnstr win y x str n))
	     (else
	      (error "Invalid combination of optional arguments"))))x
      #t
      #f))

;;-------------------------
;; from attr

(define* (attributes-get #:optional win)
  (logior *a-attributes* 
	  (cond 
	   (win (car (wattr-get win)))
	   (else (car (attr-get))))))

(define* (attributes-on attrs #:optional win)
  (if (eqv? *ok*
	    (cond
	     (win (wattr-on win attrs))
	     (else (attr-on attrs))))
      #t
      #f))
	
(define* (attributes-off attrs #:optional win)
  (if (eqv? *ok*
	    (cond
	     (win (wattr-off win attrs))
	     (else (attr-off attrs))))
      #t
      #f))
	
(define* (attributes-set attrs #:optional win)
  (if (eqv? *ok*
	    (cond
	     (win (wattr-set win attrs))
	     (else (attr-set attrs))))
      #t
      #f))
      
(define* (attributes-clear #:optional win)
  (if (eqv? *ok*
	    (cond
	     (win (wstandend win))
	     (else (standend attrs))))
      #t
      #f))


(define* (attributes-standout #:optional win)
  (if (eqv? *ok*
	    (cond
	     (win (wstandout win))
	     (else (standout attrs))))
      #t
      #f))

(define* (color-pair-get #:optional win)
  (cond 
   (win (cdr (wattr-get win)))
   (else (cdr (attr-get)))))

(define* (color-pair-set color-pair #:optional win)
  (if (eqv? *ok*
	    (cond 
	     (win (wcolor-set win color-pair #t))
	     (else (color-set color-pair #t))))
      #t
      #f))

(define* (change-rendition attr color #:key win y x n)
  (if (eqv? *ok*
	    (cond
	     ((and (not win) (not y) (not x) (not n))
	      (chgat -1 attr color #t))
	     ((and (not win) (not y) (not x) n)
	      (chgat n attr color #t))
	     ((and win (not y) (not x) (not n))
	      (wchgat win -1 attr color #t))
	     ((and win (not y) (not x) n)
	      (wchgat win n attr color #t))
	     ((and (not win) y x (not n))
	      (mvchgat y x -1 attr color #t))
	     ((and (not win) y x n)
	      (mvchgat y x n attr color #t))
	     ((and win y x (not n))
	      (mvwchgat win y x -1 attr color #t))
	     ((and win y x n)
	      (mvgchgat win y x n attr color #t))
	     (else
	      (error "Invalid combination of optional arguments"))))
      #t
      #f))
	    
;;-------------------------
;; from beep

(define (beep)
  (if (eqv? *ok*
	    ((@ (gucu curses-raw) beep))) ; call the "beep" frun curses-raw
      #t
      #f))

(define (flash)
  (if (eqv? *ok*
	    ((@ (gucu curses-raw) flash))) ; cal the "flash" from curses-raw
      #t
      #f))


;;-------------------------
;; from bkgd

(define* (set-background ch #:key win)
  (cond
   (win (wbkgdset win ch))
   (else (bkgdset ch)))
  *unspecified*)

(define* (apply-background ch #:key win)
  (cond
   (win (wbkgd win ch))
   (else (bkgd ch)))
  *unspecified*)

(define* (get-background #:optional win)
  (cond
   (win (getbkgd win))
   (else (getbkgd (stdscr)))))

;;-------------------------
;; from border

(define* (border ls rs ts bs tl tr bl br #:key win)
  (cond
   (win (wborder win ls rs ts bs tl tr bl br))
   (else ((@ (gucu curses-raw) border) ls rs ts bs tl tr bl br)))
  *unspecified*)

(define* (box verch horch #:key win)
  (cond
   (win ((@ (gucu curses-raw) box) win verch horch))
   (else ((@ (gucu curses-raw) box) (stdscr) verch horch)))
  *unspecified*)

(define (hline ch #:key win y x n)
  (cond
   ((and (not win) (not y) (not x) (not n))
    ((@ (gucu curses-raw) hline) ch (cols)))
   ((and (not win) (not y) (not x) n)
    ((@ (gucu curses-raw) hline) ch n))
   ((and win (not y) (not x) (not n))
    (whline win ch (cols)))
   ((and win (not y) (not x) n)
    (whline win ch n))
   ((and (not win) y x (not n))
    (mvhline y x ch (cols)))
   ((and (not win) y x n)
    (mvhline y x ch n))
   ((and win y x (not n))
    (mvwhline win y x ch (cols)))
   ((and win y x n)
    (mvwhline win y x ch n))
   (else
    (error "Invalid combination of optional arguments")))
  *unspecified*)

(define (vline ch #:key win y x n)
  (cond
   ((and (not win) (not y) (not x) (not n))
    ((@ (gucu curses-raw) vline) ch (cols)))
   ((and (not win) (not y) (not x) n)
    ((@ (gucu curses-raw) vline) ch n))
   ((and win (not y) (not x) (not n))
    (wvline win ch (cols)))
   ((and win (not y) (not x) n)
    (wvline win ch n))
   ((and (not win) y x (not n))
    (mvvline y x ch (cols)))
   ((and (not win) y x n)
    (mvvline y x ch n))
   ((and win y x (not n))
    (mvwvline win y x ch (cols)))
   ((and win y x n)
    (mvwvline win y x ch n))
   (else
    (error "Invalid combination of optional arguments")))
  *unspecified*)

;;-------------------------
;; from clear

(define* (erase #:optional win)
  (if (eqv? *ok*
	    (cond
	     (win (werase win))
	     (else ((@ (gucu curses-raw) erase)))))
      #t
      #f))
		  
(define* (clear #:optional win)
  (if (eqv? *ok*
	    (cond
	     (win (wclear win))
	     (else ((@ (gucu curses-raw) clear)))))
      #t
      #f))
		  
(define* (clear-to-bottom #:optional win)
  (if (eqv? *ok*
	    (cond
	     (win (wclrtobot win))
	     (else (clrtobot))))
      #t
      #f))
		  
(define* (clear-to-eol #:optional win)
  (if (eqv? *ok*
	    (cond
	     (win (wclrtoeol win))
	     (else (clrtoeol))))
      #t
      #f))
		  
;;-------------------------
;; from color

(define (start-color)
  (if (eqv? *ok*
	    ((@ (gucu curses-raw) start-color)))
      #t
      #f))

(define (set-color-pair! pair f b)
  (if (eqv? *ok*
	    (init-pair pair f b))
      #t
      #f))

(define (set-color! color r g b)
  (if (eqv? *ok*
	    (init-color color r g b))
      #t
      #f))

(define (has-colors?)
  (has-colors))

;;-------------------------
;; from delch

(define* (delete-char #:key win y x)
  (if (eqv? *ok*
	    (cond
	     ((and (not win) (not y) (not x))
	      (delch))
	     ((and win (not y) (not x))
	      (wdelch win))
	     ((and (not win) y x)
	      (mvdelch y x))
	     ((and win y x)
	      (mvwdelch win y x))))
      #t
      #f))
  
;;-------------------------
;; from deleteln

(define* (delete-line #:key win)
  (if (eqv? *ok*
	    (cond
	     (win (wdeleteln win))
	     (else (deleteln))))
      #t
      #f))

(define* (insert-or-delete-lines n #:key win)
  (if (eqv? *ok*
	    (cond
	     (win (winsdelln win n))
	     (else (insdelln n))))
      #t
      #f))

(define* (insert-line #:key win)
  (if (eqv? *ok*
	    (cond
	     (win (winsertln win))
	     (else (insertln))))
      #t
      #f))


;;-------------------------
;; from getch

(define* (get-char #:key win y x)
  (let ((ch (cond
	     ((and (not win) (not y) (not x))
	      (getch))
	     ((and win (not y) (not x))
	      (wgetch win))
	     ((and (not win) y x)
	      (mvgetch y x))
	     ((and win y x)
	      (mvwgetch win y x))
	     (else
	      (error "Invalid combination of optional arguments")))))
    (cond
     ((eqv? ch *err*)
      (list 'none 0))
     ((<= 0 ch 255)
      (list 'char ch))
     (else
      (list 'key ch)))))

(define (unget-char ch)
  (if (eqv? *ok*
	    (ungetch ch))
      #t 
      #f))

(define (has-key? ch)
  (if (eqv? *true*
	    (has-key ch))
      #t
      #f))

;;-------------------------
;; from getstr

(define* (get-string #:key win y x n)
  (cond
   ((and (not win) (not y) (not x) (not n))
    (getstr wstr))
   ((and (not win) (not y) (not x) n)
    (getnstr wstr n))
   ((and win (not y) (not x) (not n))
    (wgetstr win wstr))
   ((and win (not y) (not x) n)
    (wgetnstr win wstr n))
   ((and (not win) y x (not n))
    (mvgetstr y x wstr))
   ((and (not win) y x n)
    (mvgetnstr y x wstr n))
   ((and win y x (not n))
    (mvwgetstr win y x wstr))
   ((and win y x n)
    (mvwgetnstr win y x wstr n))
   (else
    (error "Invalid combination of optional arguments"))))

;;-------------------------
;; from getyx

(define* (cursor-position #:optional win)
  (let* ((pos (cond
	       (win (getyx win))
	       (else (getyx (stdscr)))))
	 (y (car pos))
	 (x (cadr pos)))
    (list x y)))

(define (window-position-relative-to-parent win)
  (let* ((pos (getparyx win))
	 (y (car pos))
	 (x (cadr pos)))
    (list x y)))
  
(define (window-position win)
  (let* ((pos (getbegyx win))
	 (y (car pos))
	 (x (cadr pos)))
    (list x y)))

(define (window-size)
  (let* ((pos (getmaxyx win))
	 (y (car pos))
	 (x (cadr pos)))
    (list x y)))
  
;;-------------------------
;; from inch

(define* (extract-rendered-char #:key win y x)
  (cond
   ((and (not win) (not y) (not x))
    (inch))
   ((and win (not y) (not x))
    (winch win))
   ((and (not win) y x)
    (mvinch y x))
   ((and win y x)
    (mvwinch))
   (else
    (error "Invalid combination of optional arguments"))))

;;-------------------------
;; from inchstr

(define* (extract-rendered-string #:key win y x n)
  (cond
   ((and (not win) (not y) (not x) (not n))
    (inchstr))
   ((and (not win) (not y) (not x) n)
    (inchnstr n))
   ((and win (not y) (not x) (not n))
    (winchstr win))
   ((and win (not y) (not x) n)
    (winchnstr win n))
   ((and (not win) y x (not n))
    (mvinchstr y x))
   ((and (not win) y x n)
    (mvinchnstr y x n))
   ((and win y x (not n))
    (mvwinchstr win y x))
   ((and win y x n)
    (mvwinchnstr win y x n))
   (else
    (error "Invalid combination of optional arguments"))))
  
;;-------------------------
;; from initscr

(define (initialize-windows)
  (initscr))

(define (suspend-windows)
  (if (eqv? *ok*
	    (endwin))
      #t
      #f))

(define (windows-suspended?)
  (isendwin))

(define (new-terminal type out in)
  (newterm type out in))

(define (set-terminal new)
  (set-term new))

(define (delete-terminal sp)
  (delscreen sp))

;; from inopts
(define (cbreak)
  (if (eqv? *ok*
	    ((@ (gucu curses-raw) cbreak)))
      #t
      #f))

(define (no-cbreak)
  (if (eqv? *ok*
	    (nocbreak))
      #t
      #f))

(define (echo)
  (if (eqv? *ok*
	    ((@ (gucu curses-raw) echo)))
      #t
      #f))

(define (no-echo)
  (if (eqv? *ok*
	    (noecho))
      #t
      #f))

(define (raw)
  (if (eqv? *ok*
	    ((@ (gucu curses-raw) raw)))
      #t
      #f))

(define (no-raw)
  (if (eqv? *ok*
	    (noraw))
      #t
      #f))

(define (queue-interrupt-flush)
  (qiflush))

(define (no-queue-interrupt-flush)
  (noqiflush))

(define* (interrupt-flush bf #:key win)
  (if (eqv? *ok*
	    (cond
	     (win (intrflush win bf))
	     (else (intrflush (stdscr) bf))))
      #t
      #f))

(define* (keypad bf #:key win)
  (if (eqv? *ok*
	    (cond
	     (win ((@ (gucu curses-raw) keypad) win bf))
	     (else ((@ (gucu curses-raw) keypad) (stdscr) bf))))
      #t
      #f))

(define* (meta bf #:key win)
  (if (eqv? *ok*
	    (cond
	     (win ((@ (gucu curses-raw) meta) win bf))
	     (else ((@ (gucu curses-raw) meta) (stdscr) bf))))
      #t
      #f))

(define* (no-delay bf #:key win)
  (if (eqv? *ok*
	    (cond
	     (win (nodelay win bf))
	     (else (nodelay (stdscr) bf))))
      #t
      #f))

(define* (no-timeout bf #:key win)
  (if (eqv? *ok*
	    (cond
	     (win (notimeout win bf))
	     (else (notimeout (stdscr) bf))))
      #t
      #f))

(define* (timeout bf #:key win)
  (if (eqv? *ok*
	    (cond
	     (win (wtimeout win bf))
	     (else (timeout bf))))
      #t
      #f))

(define (type-ahead fd)
  (if (eqv? *ok*
	    (typeahead fd))
      #t
      #f))

;;-------------------------
;; from insch

(define* (insert-char ch #:key win y x )
  (if (eqv? *ok*
	    (cond
	     ((and (not win) (not y) (not x))
	      (insch ch))
	     ((and win (not y) (not x))
	      (winsch win ch))
	     ((and (not win) y x)
	      (mvinsch y x ch))
	     ((and win y x)
	      (mvwinsch win y x ch))
	     (else
	      (error "Invalid combination of optional arguments"))))
      #t
      #f))
  
;;-------------------------
;; from insstr

(define* (insert-string str #:key win y x n)
  (if (eqv? *ok*
	    (cond
	     ((and (not win) (not y) (not x) (not n))
	      (insstr str))
	     ((and (not win) (not y) (not x) n)
	      (insnstr str n))
	     ((and win (not y) (not x) (not n))
	      (winsstr win str))
	     ((and win (not y) (not x) n)
	      (winsnstr win str n))
	     ((and (not win) y x (not n))
	      (mvinsstr y x str))
	     ((and (not win) y x n)
	      (mvinsnstr y x str n))
	     ((and win y x (not n))
	      (mvwinsstr win y x str))
	     ((and win y x n)
	      (mvwinsnstr win y x str n))
	     (else
	      (error "Invalid combination of optional arguments"))))
      #t
      #f))
  
;;-------------------------
;; from instr

(define* (extract-string #:key win y x n)
  (cond
   ((and (not win) (not y) (not x) (not n))
    (instr))
   ((and (not win) (not y) (not x) n)
    (innstr n))
   ((and win (not y) (not x) (not n))
    (winstr win))
   ((and win (not y) (not x) n)
    (winnstr win n))
   ((and (not win) y x (not n))
    (mvinstr y x))
   ((and (not win) y x n)
    (mvinnstr y x n))
   ((and win y x (not n))
    (mvwinstr win y x))
   ((and win y x n)
    (mvwinnstr win y x n))
   (else
    (error "Invalid combination of optional arguments"))))
  
;;-------------------------
;; from kernel

(define (define-program-mode)
  (if (eqv? *ok*
	    (def-prog-mode))
      #t
      #f))

(define (define-shell-mode)
  (if (eqv? *ok*
	    (def-shell-mode))
      #t
      #f))

(define (reset-program-mode)
  (if (eqv? *ok*
	    (reset-program-mode))
      #t
      #f))

(define (reset-shell-mode)
  (if (eqv? *ok*
	    (reset-program-mode))
      #t
      #f))

(define (reset-tty)
  (if (eqv? *ok*
	    (resettty))
      #t
      #f))

(define (save-tty)
  (if (eqv? *ok*
	    (resettty))
      #t
      #f))

(define* (virtual-cursor-position)
  (let* ((pos (win (getsyx)))
	 (y (car pos))
	 (x (cadr pos)))
    (list x y)))

(define (set-virtual-cursor-position x y)
  (setsyx y x))

(define (set-cursor-visibility vis)
  (let ((old-vis (curs-set vis)))
    (if (eqv? *err* old-vis)
	#f
	old-vis)))

;;-------------------------
;; from mouse

(define (get-mouse)
  (getmouse))

(define (unget-mouse)
  (ungetmouse))

(define (mouse-mask x)
  (mousemask x))

(define (is-in-window? win x y)
  (wenclose win y x))

(define (stdscr-pos->screen-pos pos)
  (mouse-trafo pos))

(define (mouse-click-interval x)
  (mouseinterval x))

;;-------------------------
;; from move

(define (set-cursor-position x y #:key win)
  (if (eqv? *ok*
	    (cond
	     (win (wmove win y x))
	     (else (move y x))))
      #t
      #f))

;;-------------------------
;; from outputs

(define (set-clear bf#:key win)
  (cond
   (win (clearok win bf))
   (else (clearok (stcscr) bf)))
  *undefined*) 

(define (use-hardware-insert-delete-line bf #:key win)
  (cond
   (win (idlok win bf))
   (else (idlok (stcscr) bf)))
  *undefined*) 

(define (use-hardware-insert-delete-char bf #:key win)
  (cond
   (win (idcok win bf))
   (else (idcok (stcscr) bf)))
  *undefined*) 
	
(define (use-hardware-insert-delete-char bf #:key win)
  (cond
   (win (idcok win bf))
   (else (idcok (stcscr) bf)))
  *undefined*) 
	
(define (set-immediate bf #:key win)
  (cond
   (win (immedok win bf))
   (else (immedok (stcscr) bf)))
  *undefined*) 
	
(define (set-scroll bf #:key win)
  (cond
   (win (scrollok win bf))
   (else (scrollok (stcscr) bf)))
  *undefined*) 

(define (set-newline)
  (nl))

(define (unset-newline)
  (nonl))

;;-------------------------
;; from overlay
	
(define (overlay src dst)
  (if (eqv? *ok*
	    ((@ (gucu curses-raw) overlay) src dst))
      #t
      #f))

(define (overwrite src dst)
  (if (eqv? *ok*
	    ((@ (gucu curses-raw) overwrite) src dst))
      #t
      #f))

(define (copy-window src dst smr smc dmr dmc dxr dxc ov)
  (if (eqv? *ok*
	    (copywin src dst smr smc dmr dmc dxr dxc ov)
      #t
      #f))



	
