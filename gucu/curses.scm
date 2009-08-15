;; -*- Mode: scheme; -*-
(define-module (gucu curses)
  #:use-module (ice-9 optargs)
  #:export ( 
	    assume-default-colors
	    addch
	    addchstr
	    addstr
	    attr-get
	    attr-off!
	    attr-on!
	    attr-set!
	    baudrate
	    beep
	    bkgd
	    bkgdset
	    border
	    box
	    can-change-color?
	    cbreak
	    chgat
	    clearok!
	    clear
	    clrtobot
	    clrtoeol
	    color-pair
	    color-set!
	    copywin
	    curs-set
	    curses-version
	    def-prog-mode
	    def-shell-mode
	    define-key
	    delay-output
	    delch
	    deleteln
	    delscreen
	    derwin
	    doupdate
	    dupwin
	    echo
	    echochar
	    endwin
	    erasechar
	    erase
	    %filter
	    flash
	    flushinp
	    getbkgd
	    getch
	    getmaxy
	    getmaxyx
	    getnstr
	    getwin
	    halfdelay
	    has-colors?
	    has-ic?
	    has-il?
	    has-key?
	    hline
	    idcok!
	    idlok!
	    immedok!
	    inch
	    inchstr
	    initscr
	    init-color
	    init-pair
	    insch
	    insdelln
	    insertln
	    insstr
	    instr
	    intrflush
	    isendwin?
	    is-linetouched?
	    is-wintouched?
	    key-f
	    key-defined
	    keyname
	    keypad!
	    killchar
	    leaveok!
	    longname
	    meta
	    mouseinterval
	    move
	    mvcur
	    mvderwin
	    mvwin
	    napms
	    newpad
	    newwin
	    nl
	    nocbreak
	    nodelay!
	    noecho
	    nonl
	    nooutrefresh
	    noutrefresh
	    noqiflush
	    noraw
	    notimeout!
	    overlay
	    overwrite
	    pair-number
	    pechochar
	    pnoutrefresh
	    prefresh
	    putwin
	    qiflush
	    raw
	    redrawwin
	    redrawln
	    refresh
	    reset-prog-mode
	    reset-shell-mode
	    resetty
	    savetty
	    scr-dump
	    scr-init
	    scrl
	    scroll
	    scrollok!
	    scr-restore
	    scr-set
	    setscrreg!
	    set-term
	    setsyx
	    standend!
	    standout!
	    start-color
	    subpad
	    subwin
	    syncok!
	    termattrs
	    termname
	    timeout!
	    touchline
	    touchwin
	    typeahead
	    ungetch
	    untouchline
	    untouchwin
	    use-default-colors
	    use-env
	    vline
	    wcursyncup
	    wenclose?
	    wsyncup
	    wsyncdown
	    EOF
	    ERR
	    FALSE
	    OK
	    TRUE
	    A_ALTCHARSET
	    A_ATTRIBUTES
	    A_BLINK
	    A_BOLD
	    A_CHARTEXT
	    A_COLOR
	    A_DIM
	    A_INVIS
	    A_NORMAL
	    A_PROTECT
	    A_REVERSE
	    A_STANDOUT
	    A_UNDERLINE
            A_HORIZONTAL
            A_LEFT
            A_LOW
            A_RIGHT
            A_TOP
            A_VERTICAL
	    COLOR_BLACK
	    COLOR_GREEN
	    COLOR_RED
	    COLOR_YELLOW
	    COLOR_BLUE
	    COLOR_MAGENTA
	    COLOR_CYAN
	    COLOR_WHITE
	    KEY_CODE_YES
	    KEY_MIN
	    KEY_BREAK
	    KEY_SRESET
	    KEY_RESET
	    KEY_DOWN
	    KEY_UP
	    KEY_LEFT
	    KEY_RIGHT
	    KEY_HOME
	    KEY_BACKSPACE
	    KEY_F0
	    KEY_DL
	    KEY_IL
	    KEY_DC
	    KEY_IC
	    KEY_EIC
	    KEY_CLEAR
	    KEY_EOS
	    KEY_EOL
	    KEY_SF
	    KEY_SR
	    KEY_NPAGE
	    KEY_PPAGE
	    KEY_STAB
	    KEY_CTAB
	    KEY_CATAB
	    KEY_ENTER
	    KEY_PRINT
	    KEY_LL
	    KEY_A1
	    KEY_A3
	    KEY_B2
	    KEY_C1
	    KEY_C3
	    KEY_BTAB
	    KEY_BEG
	    KEY_CANCEL
	    KEY_CLOSE
	    KEY_COMMAND
	    KEY_COPY
	    KEY_CREATE
	    KEY_END
	    KEY_EXIT
	    KEY_FIND
	    KEY_HELP
	    KEY_MARK
	    KEY_MESSAGE
	    KEY_MOVE
	    KEY_NEXT
	    KEY_OPEN
	    KEY_OPTIONS
	    KEY_PREVIOUS
	    KEY_REDO
	    KEY_REFERENCE
	    KEY_REFRESH
	    KEY_REPLACE
	    KEY_RESTART
	    KEY_RESUME
	    KEY_SAVE
	    KEY_SBEG
	    KEY_SCANCEL
	    KEY_SCOMMAND
	    KEY_SCOPY
	    KEY_SCREATE
	    KEY_SDC
	    KEY_SDL
	    KEY_SELECT
	    KEY_SEND
	    KEY_SEOL
	    KEY_SEXIT
	    KEY_SFIND
	    KEY_SHELP
	    KEY_SHOME
	    KEY_SIC
	    KEY_SLEFT
	    KEY_SMESSAGE
	    KEY_SMOVE
	    KEY_SNEXT
	    KEY_SOPTIONS
	    KEY_SPREVIOUS
	    KEY_SPRINT
	    KEY_SREDO
	    KEY_SREPLACE
	    KEY_SRIGHT
	    KEY_SRSUME
	    KEY_SSAVE
	    KEY_SSUSPEND
	    KEY_SUNDO
	    KEY_SUSPEND
	    KEY_UNDO
	    KEY_MOUSE
	    KEY_RESIZE
	    KEY_EVENT
	    BUTTON1_PRESSED
	    BUTTON1_RELEASED
	    BUTTON1_CLICKED
	    BUTTON1_DOUBLE_CLICKED
	    BUTTON1_TRIPLE_CLICKED
	    BUTTON2_PRESSED
	    BUTTON2_RELEASED
	    BUTTON2_CLICKED
	    BUTTON2_DOUBLE_CLICKED
	    BUTTON2_TRIPLE_CLICKED
	    BUTTON3_PRESSED
	    BUTTON3_RELEASED
	    BUTTON3_CLICKED
	    BUTTON3_DOUBLE_CLICKED
	    BUTTON3_TRIPLE_CLICKED
	    BUTTON4_PRESSED
	    BUTTON4_RELEASED
	    BUTTON4_CLICKED
	    BUTTON4_DOUBLE_CLICKED
	    BUTTON4_TRIPLE_CLICKED
	    BUTTON_SHIFT
	    BUTTON_CTRL
	    BUTTON_ALT
	    ALL_MOUSE_EVENTS
	    REPORT_MOUSE_POSITION
	    color-content
	    delwin
	    getmouse
	    mousemask
	    mouse-trafo
	    pair-content
	    ungetmouse
	    getbegyx
	    getparyx
	    getsyx
	    getyx
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
	    lines
	    cols
	    colors
	    color-pairs
	    tabsize
	    set-tabsize
	    stdscr
	    curscr
	    window?
	    screen?
	    open-curses-port
))

;; These functions may not exist depending on the 
;; compile time options
(if (defined? 'newterm)
    (export newterm))

;; Range checks

(defmacro check-char (ch)
  `(if (not (char? ,ch))
       (scm-error 'wrong-type-arg fname 
                  "Not a character: ~S" (list ,ch) (list ,ch))))

(defmacro check-char-or-rendered-char (ch)
  `(if (not (or (integer? ,ch) (char? ,ch)))
       (scm-error 'wrong-type-arg fname 
                  "Not a character or a rendered character: ~S" (list ,ch) (list ,ch))))

(defmacro check-integer (n)
  `(if (not (integer? ,n))
       (scm-error 'wrong-type-arg fname 
                  "Not an integer: ~S" (list ,n) (list ,n))))

(defmacro check-integer-and-range-check (n lo hi)
  `(cond
    ((not (integer? ,n))
     (scm-error 'wrong-type-arg fname 
                "Not an integer: ~S" (list ,n) (list ,n)))
    ((or (< ,n ,lo) (> ,n ,hi))
     (scm_error 'out-of-range fname
                "N value out of range ~S to ~S: ~S" (list ,lo ,hi ,n) (list ,n)))))

(defmacro check-position-and-move (win y x)
  `(if (and ,y ,x)
       (begin
         (check-integer ,x)
         (check-integer ,y)
         (check-x ,win ,x)
         (check-y ,win ,y)
         (%wmove ,win (inexact->exact ,y) (inexact->exact ,x)))
       #t))

;; This doesn't check every member of the list.  
(defmacro check-string-or-rendered-string (str)
  `(if (not (or (string? ,str) 
                (and (list? ,str) (or (null? ,str) 
                                      (integer? (list-ref ,str 0))))))
       (scm-error 'wrong-type-arg fname 
                  "Not a string or a rendered string: ~S" (list ,str) (list ,str))))

(defmacro check-window (win)
  `(if (not (window? ,win))
       (scm-error 'wrong-type-arg fname 
                  "Not a window: ~S" (list ,win) (list ,win))))

(defmacro check-x (win x)
  `(let ((maxyx (getmaxyx ,win)))
     (if (or (< ,x 0) (>= ,x (cadr maxyx)))
         (scm-error 'out-of-range fname 
                    "X value out of range: ~S" (list ,x) (list ,x)))))

(defmacro check-y (win y)
  `(let ((maxyx (getmaxyx ,win)))
     (if (or (< ,y 0) (>= ,y (car maxyx)))
         (scm-error 'out-of-range fname 
                    "Y value out of range: ~S" (list ,y) (list ,y)))))

;; decorators

(defmacro render-char-if-necessary (ch)
  `(if (char? ,ch)
       (char->integer ,ch)
       (inexact->exact ,ch)))

(defmacro render-string-if-necessary (str)
  `(if (string? ,str)
       (map char->integer (string->list ,str))
       ,str))

(defmacro string-length-or-length (str)
  `(if (string? ,str)
       (string-length ,str)
       (length ,str)))
  
;; declaration outlines

(defmacro WIN-RCH-KEY-YX (func primitive-func)
  `(define* (,func win ch #:key y x)
     (let ((fname (symbol->string ',func)))
       (check-window win)
       (check-char-or-rendered-char ch)
       (and (check-position-and-move win y x)
            (,primitive-func win (render-char-if-necessary ch))))))

(defmacro WIN-RST-KEY-YX-N (func primitive-func)
  `(define* (,func win str #:key y x (n -1))
     (let ((fname (symbol->string ',func)))
       (check-window win)
       (check-string-or-rendered-string str)
       (check-integer-and-range-check n -1 (string-length-or-length str))
       (and (check-position-and-move win y x)
            (,primitive-func win 
                             (render-string-if-necessary str) 
                             (inexact->exact n))))))

;; Scheme calling wrappers for C functions

;; CURSES NAME                          ALTERNATE NAME
(WIN-RCH-KEY-YX addch %waddch)          (WIN-RCH-KEY-YX add-rendered-char %waddch)
(WIN-RST-KEY-YX-N addchstr %waddchnstr) (WIN-RST-KEY-YX-N add-rendered-string %waddchnstr)
(WIN-RCH-KEY-YX echochar %wechochar)    (WIN-RCH-KEY-YX echo-rendered-char %wechochar)

(define* (addstr win str #:key y x (n -1))
  (and (if (and y x)
	   (%wmove win y x)
	   #t)
       (%waddnstr win str n)))

(define (attr-get win)
  (let* ((ac (%wattr-get win))
	 (attr (car ac))
	 (color (cadr ac)))
    (list
     (logand attr (logior A_STANDOUT
			  A_UNDERLINE
			  A_REVERSE
			  A_BLINK
			  A_DIM
			  A_BOLD
			  A_ALTCHARSET
			  A_INVIS
			  A_PROTECT
			  WA_HORIZONTAL
			  WA_LEFT
			  WA_LOW
			  WA_RIGHT
			  WA_TOP
			  WA_VERTICAL))
     color)))

(define* (attr-set! win attr #:optional color)
  (if color
      (%attr-set! win attr color)
      (%attr-set! win attr (pair-number attr))))

(define (box win v h)
  (border win v v h h 0 0 0 0))

(define* (chgat win n attr color #:key y x)
  (and
   (if (and y x)
       (%wmove win y x)
       #t)
   (%wchgat win n attr color)))

(define* (delch win #:key y x)
  (and
   (if (and y x)
       (%wmove win y x)
       #t)
   (%wdelch win)))

(define* (deleteln win #:key y x)
  (and
   (if (and y x)
       (%wmove win y x)
       #t)
   (%winsdelln win -1)))

(define* (getch win #:key y x)
  (and (if (and y x)
	   (%wmove win y x)
	   #t)
       (%wgetch win)))

(define (getmaxy win)
  (car (getmaxyx win)))

(define* (getnstr win n #:key y x)
  (and (if (and y x)
	   (%wmove win y x)
	   #t)
       (%wgetnstr win n)))
  
(define* (hline win ch n #:key y x)
  (and (if (and y x)
	   (%wmove win y x)
	   #t)
       (%whline win ch n)))

(define* (inch win #:key y x)
  (and (if (and y x)
	   (%wmove win y x)
	   #t)
       (%winch win)))

(define* (inchstr win #:key y x (n -1))
  (and (if (and y x)
	   (%wmove win y x)
	   #t)
       (%winchnstr win n)))

(define* (insch win ch #:key y x)
  (and (if (and y x)
	   (%wmove win y x)
	   #t)
       (%winsch win ch)))

(define* (instr win #:key y x (n -1))
  (and (if (and y x)
	   (%wmove win y x)
	   #t)
       (%winnstr win n)))

(define* (insdelln win n #:key y x)
  (and
   (if (and y x)
       (%wmove win y x)
       #t)
   (%winsdelln win n)))

(define* (insertln win #:key y x)
  (and
   (if (and y x)
       (%wmove win y x)
       #t)
   (%winsdelln win 1)))

(define* (insstr win str #:key y x (n -1))
  (and
   (if (and y x)
       (%wmove win y x)
       #t))
  (%winsnstr win str n))

(define (move win y x)
  (%wmove win y x))

;; I hate it when people are 'clever' with dropping letters
(define (nooutrefresh win)
  (noutrefresh win))

(define (redrawln win beg_line end_line)
  (%wredrawln win beg_line end_line))
  
(define (scroll win)
  (scrl win 1))

(define (touchwin win)
  (%wtouchln win 0 (getmaxy win) #t))

(define (untouchwin win)
  (%wtouchln win 0 (getmaxy win) #f))

(define* (touchline win start #:optional (count 1))
  (%wtouchln win start count #t))

(define* (untouchline win start #:optional (count 1))
  (%wtouchln win start count #f))

(define (typeahead port-or-fd)
  (cond 
   ((port? port-or-fd) (%typeahead (fileno port-or-fd)))
   (else (%typeahead port-or-fd))))

(define* (vline win ch n #:key y x)
  (and (if (and y x)
	   (%wmove win y x)
	   #t)
       (%wvline win ch n)))


		

(load-extension "libguile-gucu" "gucu_init")
