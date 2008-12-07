
;; -*- Mode: scheme; -*-
(define-module (gucu curses)
  #:use-module (ice-9 optargs)
  #:export ( 
	    assume-default-colors
	    addch
	    addchstr
	    addstr
	    attr-get
	    attr-off
	    attr-on
	    attr-set
	    baudrate
	    beep
	    bkgd
	    bkgdset
	    border
	    box
	    can-change-color?
	    cbreak
	    chgat
	    clearok
	    clear
	    clrtobot
	    clrtoeol
	    color-pair
	    color-set
	    copywin
	    curs-set
	    def-prog-mode
	    def-shell-mode
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
	    ;; filter
	    flash
	    flushinp
	    getbkgd
	    getch
	    getwin
	    halfdelay
	    has-colors?
	    has-ic
	    has-il
	    hline
	    idcok
	    idlok
	    immedok
	    inch
	    initscr
	    init-color
	    init-pair
	    insch
	    insdelln
	    insertln
	    insnstr
	    insstr
	    intrflush
	    isendwin
	    is-linetouched
	    is-wintouched
	    key-f
	    keyname
	    keypad
	    killchar
	    leaveok
	    longname
	    meta
	    mouseinterval
	    move
	    mvcur
	    mvdelch
	    mvderwin
	    mvgetch
	    mvhline
	    mvinch
	    mvinsch
	    mvinsnstr
	    mvinsstr
	    mvvline
	    mvwdelch
	    mvwgetch
	    mvwhline
	    mvwin
	    mvwinch
	    mvwinsch
	    mvwinsnstr
	    mvwinsstr
	    mvwvline
	    napms
	    newpad
	    newwin
	    nl
	    nocbreak
	    nodelay
	    noecho
	    nonl
	    noqiflush
	    noraw
	    notimeout
	    overlay
	    overwrite
	    pair-number
	    pechochar
	    pnoutrefresh
	    prefresh
	    putp
	    putwin
	    qiflush
	    raw
	    redrawwin
	    refresh
	    reset-prog-mode
	    reset-shell-mode
	    resetty
	    savetty
	    scr-dump
	    scr-init
	    scrl
	    scroll
	    scrollok
	    scr-restore
	    scr-set
	    setscrreg
	    set-term
	    slk-attr-off
	    slk-attroff
	    slk-attr-on
	    slk-attron
	    slk-attr-set
	    slk-attrset
	    slk-clear
	    slk-color
	    slk-init
	    slk-label
	    slk-noutrefresh
	    slk-refresh
	    slk-restore
	    slk-set
	    slk-touch
	    standend
	    standout
	    start-color
	    subpad
	    subwin
	    syncok
	    termattrs
	    termname
	    tgetent
	    tigetflag
	    tigetnum
	    tigetstr
	    timeout
	    touchline
	    touchwin
	    typeahead
	    ungetch
	    untouchwin
	    use-default-colors
	    use-env
	    vidattr
	    vline
	    wbkgd
	    wbkgdset
	    wborder
	    wclear
	    wclrtobot
	    wclrtoeol
	    wcursyncup
	    wdelch
	    wdeleteln
	    wenclose
	    werase
	    wgetch
	    whline
	    winch
	    winsch
	    winsdelln
	    winsertln
	    winsnstr
	    winsstr
	    wmove
	    wnoutrefresh
	    wredrawln
	    wrefresh
	    wscrl
	    wsetscrreg
	    wsyncup
	    wsyncdown
	    wtimeout
	    wtouchln
	    wvline
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
	    WA_ALTCHARSET
	    WA_BLINK
	    WA_BOLD
	    WA_DIM
	    WA_HORIZONTAL
	    WA_LEFT
	    WA_LOW
	    WA_PROTECT
	    WA_REVERSE
	    WA_RIGHT
	    WA_STANDOUT
	    WA_TOP
	    WA_UNDERLINE
	    WA_VERTICAL
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
	    attr-set
	    color-content
	    delwin
	    getmouse
	    getnstr
	    inchnstr
	    innstr
	    instr
	    mousemask
	    mouse-trafo
	    mvgetnstr
	    mvwgetnstr
	    mvinchnstr
	    mvinnstr
	    mvinstr
	    mvwinchnstr
	    mvwinnstr
	    mvwinstr
	    newterm
	    newterm-port
	    pair-content
	    ungetmouse
	    wgetnstr
	    winchnstr
	    winnstr
	    winstr
	    wmouse-trafo
	    getbegyx
	    getmaxyx
	    getparyx
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
	    fopen
	    fclose
	    lines
	    cols
	    colors
	    color-pairs
	    tabsize
	    set-tabsize
	    stdscr
	    curscr
	    window?
	    open-curses-port
))

(define* (addch ch #:key (win (stdscr)) y x)
  (and (if (and y x)
	   (wmove win y x)
	   #t)
       (%waddch win ch)))

(define* (addchstr chstr #:key (win (stdscr)) y x (n -1))
  (and (if (and y x)
	   (wmove win y x)
	   #t)
       (%waddchnstr win chstr n)))

(define* (addstr str #:key (win (stdscr)) y x (n -1))
  (and (if (and y x)
	   (wmove win y x)
	   #t)
       (%waddnstr win str n)))

(define* (attr-get #:key (win (stdscr)))
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

(define* (attr-off attr #:key (win (stdscr)))
  (%wattr-off win attr))
	
(define* (attr-on attr #:key (win (stdscr)))
  (%wattr-on win attr))

(define* (attr-set attr #:key (color 0) (win (stdscr)))
  (%wattr-set win attr color))

(define* (color-set pair #:key (win (stdscr)))
  (%wcolor-set win pair))

(define* (echochar ch #:key (win (stdscr)))
  (%wechochar win ch))

(define* (standend #:key (win (stdscr)))
  (%wstandend win))

(define* (standout #:key (win (stdscr)))
  (%wstandout win))

(define* (chgat n attr color #:key (win (stdscr)) y x)
  (and
   (if (and y x)
       (wmove win y x)
       #t)
   (%wchgat win n attr color)))

		

(load-extension "libguile-gucu-curses-v-0" "gucu_init")
