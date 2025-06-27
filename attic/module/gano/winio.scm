;;; winio.scm
;;;
;;; Copyright (C) 2010 Michael L. Gran
;;; Copyright (C) 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009 Free Software Foundation, Inc.

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

(define-module (gano winio)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  ;; #:use-module (gano config)
  ;; #:use-module (gano CBuffer)
  ;; #:use-module (gano CFunction)
  ;; #:use-module (gano CShortcut)
  ;; #:use-module (gano CText)
  #:use-module (gano chars)
  #:use-module (gano utils)
  ;; #:use-module (gano flags)
  ;; #:use-module (gano global)
  ;; #:use-module (gano nano-h)
  ;; #:use-module (gano utils)
  ;; #:use-module (rnrs control)
  ;; #:use-module (mlg logging)
  #:use-module (ncurses curses)
  #:use-module (ncurses extra)
  #:export (
            
            make-winio
            winio?
            initialize-ncurses
            initialize-keyboard-handling
            turn-on-cursor
            move-cursor-to-last-line-and-endwin
            initialize-windows
            init-winio!
            initialize-mouse-support
            
            display-string
            
            blank-editor
            blank-shortcut-list
            blank-statusbar
            blank-titlebar

            get-main-win
            get-top-win
            get-edit-win
            get-bottom-win
            get-top-win-lines
            get-edit-win-lines
            get-bottom-win-lines
            get-cols

            display-titlebar
            read-titlebar
            display-statusbar
            read-statusbar
            display-shortcut-list
            read-shortcut-list
            display-editor
            read-editor

            handle-sigwinch

            save-terminal-settings
            restore-terminal-settings
            disable-terminal-extended-io
            disable-terminal-signals
            enable-terminal-signals
            disable-terminal-flow-control
            enable-terminal-flow-control

            get-kbinput
            #|
            check-statusblank

            do_cursorpos
            DisplayShortcutList
            DisplayStatusbar
            DisplayTitlebar
            GetShortcutFromMenuKey
            InitWindow
            NeedVerticalUpdate?
            RefreshEditor
            display_string
            onekey
            reset_cursor
            set_modified
            update_line |#
            )
  )

  ;; The maximum number of bytes buffered at one time.
(define MAX_TRIES 128)

(define-class <winio> ()
  (m_MIN_EDITOR_COLS #:allocation #:class
                     #:init-value 20
                     #:getter get-min-editor-cols)
  (m_MIN_EDITOR_LINES #:allocation #:class
                      #:init-value 6
                      #:getter get-min-editor-lines)
  (m_MAIN_VISIBLE #:allocation #:class
                  #:init-value 12
                  #:getter get-main-visible)

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Screens
  
  ;; The standard ncurses screen
  (m-main-win #:init-value #f
              #:getter get-main-win
              #:setter set-main-win!)
  ;; The top portion of the window, where we display the version
  ;; number of nano, the name of the current file, and whether the
  ;; current file has been modified
  (m-top-win #:init-value #f
             #:getter get-top-win
             #:setter set-top-win!)
  ;; The middle portion of the window, where we display the file we're
  ;; editing
  (m-edit-win #:init-value #f
              #:getter get-edit-win
              #:setter set-edit-win!)
  ;; The bottom portion of the window, where we display statusbar
  ;; messages, the statusbar primpt, and a list of shortcuts
  (m-bottom-win #:init-value #f
                #:getter get-bottom-win
                #:setter set-bottom-win!)

  ;; The geometry of the windows
  (m-top-win-lines #:init-value 2
                   #:getter get-top-win-lines
                   #:setter set-top-win-lines!)
  (m-edit-win-lines #:init-value 19
                    #:getter get-edit-win-lines
                    #:setter set-edit-win-lines!)
  (m-bottom-win-lines #:init-value 3
                      #:getter get-bottom-win-lines
                      #:setter set-bottom-win-lines!)
  (m-cols #:init-value 80
          #:getter get-cols
          #:setter set-cols!)
  (m-fill-column #:init-value 80
                 #:getter get-fill-column
                 #:setter set-fill-column!)
  (m-tab-size #:init-value 8
              #:getter get-tab-size
              #:setter set-tab-size!)

  ;; When true, add space between the title and the editor
  (m-more-space-p #:init-value #t
                  #:getter get-more-space-p
                  #:setter set-more-space-p!)
  ;; When true, show the onscreen help
  (m-help-p #:init-value #t
            #:getter get-help-p
            #:setter set-help-p)

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; Terminal attributes
  
  ;; When true, flow control characters are not disabled
  (m-flow-control-p #:init-value #f
                    #:getter get-flow-control-p
                    #:setter set-flow-control-p!)
  ;; When true, mouse support is enabled
  (m-use-mouse-p #:init-value #f
                 #:getter get-use-mouse-p
                 #:setter set-use-mouse-p!)

  ;; Used to store the user's original mouse click interval
  (m-old-mouse-click-interval #:init-value -1
                              #:getter get-old-mouse-click-interval
                              #:setter set-old-mouse-click-interval!)
  ;; Used to store the user's original terminal settings
  (m-old-terminal-settings #:init-value (tcgetattr 0)
                           #:getter get-old-terminal-settings
                           #:setter set-old-terminal-settings!)

  (m-default-title #:init-value "Gano 0.0"
                   #:getter get-default-title
                   #:setter set-default-title!)
  ;; The number of keystrokes left until the statubar is blanked.
  ;; or #f if there is not message to blank in the statusbar.
  (m-status-blank #:init-value #f
                  #:getter get-status-blank
                  #:setter set-status-blank!))

(define (make-winio)
  "Creates a <winio> with a default empty text buffer."
  (make <winio>))

(define (winio? x)
  "Returns #t if argument is of type <winio>"
  (is-a? x <winio>))

(define-method (initialize-ncurses (winio <winio>))
  "Kick off ncurses"
  (if (get-main-win winio)
      (refresh (get-main-win winio))
      ;; else
      (begin
        (set-main-win! winio (initscr))
        (when (has-colors?)
          (start-color!)))))

(define-method (initalize-keyboard-handling (winio <winio>))
  "Set interpretation of keypresses to what we need."
  (unless (get-main-win winio)
    (error "terminal has not been initialized"))
  (raw!)
  (nonl!)
  (noecho!)
  (disable-terminal-extended-io)
  (when (get-flow-control-p winio)
    (enable-terminal-flow-control))
  (disable-terminal-signals))

(define (turn-on-cursor)
  ;; Turn the cursor on for sure
  (curs-set 1))

(define-method  (move-cursor-to-last-line-and-endwin (winio <winio>))
  (move (get-main-win winio)
        (- (lines) 1)
        0)
  (endwin))

(define-method (init-winio! (winio <winio>)
                            (lines <integer>)
                            (cols <integer>)
                            (more-space? <boolean>)
                            (help? <boolean>))
  "Initialize or reset the window"
  ;; There is a title bar which is one title line and maybe one blank
  ;; line (if more-space? is true).
  ;; There is a bottom region that is either one line, if help is
  ;; disabled, or three lines, if help is enabled.
  ;; And then the editor is the space remaining.
  (if more-space?
      (set-top-win-lines! winio 2)
      (set-top-win-lines! winio 1))
  (if help?
      (set-bottom-win-lines! winio 3)
      (set-bottom-win-lines! winio 1))
  (set-edit-win-lines! winio (max (get-min-editor-lines winio)
                                  (+ lines
                                     (- (get-top-win-lines winio))
                                     (- (get-bottom-win-lines winio)))))
  (set-cols! winio (max (get-min-editor-cols winio) cols))

  (and=> (get-top-win winio) delwin)
  (and=> (get-edit-win winio) delwin)
  (and=> (get-bottom-win winio) delwin)

  ;; Create these 3 stacked windows
  (set-top-win! winio (newwin (get-top-win-lines winio)
                              cols
                              0
                              0))
  (set-edit-win! winio (newwin (get-edit-win-lines winio)
                               cols
                               (get-top-win-lines winio)
                               0))
  (set-bottom-win! winio (newwin (get-bottom-win-lines winio)
                                 cols
                                 (+ (get-top-win-lines winio)
                                    (get-edit-win-lines winio))
                                 0))

  ;; (log-debug "Editor window ~a by ~a~%" cols (get-edit-win-lines winio))

  (keypad! (get-top-win winio) #t)
  (keypad! (get-edit-win winio) #t)
  (keypad! (get-bottom-win winio) #t))

(define-method (initialize-windows (winio <winio>))
    ;; Calling doupdate ensures that the stdscr has the rows, cols set
  ;; by any resizing operation.
  (doupdate)
  (init-winio! winio
               (car (getmaxyx (get-main-win winio)))
               (cadr (getmaxyx (get-main-win winio)))
               (get-more-space-p winio)
               (get-help-p winio)))


(define-method (set-fill-column! (winio <winio>) wrap-column)
  "Set up fill column, based on the screen width and the wrap column.
If the wrap column is positive, it indicates a fill column.  If it is
negative, it is an offset from the right column."
  (cond
   ((not (integer? wrap-column))
    (set-fill-column! winio (get-cols winio)))
   ((>= wrap-column 0)
    (set-fill-column! winio (min  wrap-column (get-cols winio))))
   (else
    (set-fill-column! winio (max 0 (+ wrap-column (get-cols winio)))))))

;; Convert buf into a string that can be displayed on screen.  The
;; caller wants to display buf starting with column start-col, and
;; extending for at most len cols.  start-col is zero-based.  len
;; is one-based, so len == 0 means you get "" returned.  The returned
;; string is dynamically allocated, and should be freed.  If dollars
;; is TRUE, the caller might put "$" at the beginning or end of the
;; line if it's too long.
(define* (display-string buf start-col len dollars #:optional (tabsize 8))
  ;; If dollars is true, make room for the '$' at the end of the line.
  (when (and dollars (> len 0) (> (count-cells-in-string buf) (+ start-col len)))
    (set! len (- len 1)))
  (cond
   ((= len 0)
    "")
   (else
    (let* ((start-index (get-index-from-string-cell buf start-col))
           (column (count-cells-in-substring buf start-index))
           (index 0)
           (converted ""))
      ;; OK.  START-INDEX is the number of characters skipped so far
      ;; in this string, and COLUMN is the number of terminal
      ;; character cells skipped so far in this string.  If COLUMN is
      ;; less that START-COL, then the first character to be printed
      ;; takes more than once cell, and some of this character's
      ;; cells are not visible (left of the screen).
      
      ;; Check if some of this character's text starts to the left of
      ;; the screen
      (when (and (< start-index (string-length buf))
                 (not (eq? #\tab (string-ref buf start-index)))
                 (or (< column start-col)
                     (and dollars
                          (> column 0))))
        ;; We don't display all of this character since it start to
        ;; the left of the screen.
        (let ((initial-char (string-ref buf start-index)))
          (if (is-control-char? initial-char)
              ;; For control characters like '^C', this means we're
              ;; skipping the '^'
              (when (< column start-col)
                (set! converted (string-append converted (string (get-display-char-from-control-char initial-char))))
                (set! index (+ index 1))
                (set! start-col (+ start-col 1))
                (set! start-index (+ start-index 1)))
              ;; else
              ;; for two-cell characters like kanji, we can't print just the second-half
              ;; of the character, so we print a space instead.
              (when (= 2 (wcwidth initial-char))
                (set! converted (string-append converted " "))
                (set! index (+ index 1))
                (set! start-col (+ start-col 1))
                (set! start-index (+ start-index 1))))))
      
      ;; Now for the rest of the characters
      (while (< start-index (string-length buf))
        (let ((c (string-ref buf start-index)))
          
          (cond
           ;; Tabs characters
           ((eq? c #\tab)
            ;; Make sure #\tab creates at least 1 space
            (set! converted (string-append converted " "))
            (set! index (+ index 1))
            (set! start-col (+ start-col 1))
            
            ;; advance to the next tab column
            (let ((n (- tabsize
                        (remainder start-col tabsize))))
              (set! converted (string-append converted (make-string n #\space)))
              (set! start-col (+ start-col n))
              (set! index (+ index n))))
           
           ;; Control characters
           ((is-control-char? c)
            ;; First write the hat
            (set! converted (string-append converted "^"))
            (set! start-col (+ start-col 1))
            (set! index (+ index 1))
            ;; Then the modified character
            (set! converted (string-append converted (string (get-display-char-from-control-char c))))
            (set! index (+ index 1))
            (set! start-col (+ start-col (wcwidth (get-display-char-from-control-char c)))))
           
           ;; Space characters
           ((eq? c #\space)
            (begin
              (set! converted (string-append converted " "))
              (set! index (+ index 1))
              (set! start-col (+ start-col 1))))
           
           ;; Non-control, non-space characters
           (else
            (set! converted (string-append converted (string c)))
            (set! start-col (+ start-col (wcwidth c)))
            (set! index (+ index 1)))))
        
        (set! start-index (+ start-index 1)))
      
      ;; Make sure converted takes up no more than len cols
      (set! converted (string-take converted (get-index-from-string-cell converted len)))
      converted))))

;; move to 0,y and write over a line with N spaces
(define (blank-line win y n)
  "Erase all the text on the given line"
  (move win y 0)
  (addstr win (make-string n #\space)))

(define (blank-lines win n cols)
  "Erases all the text in the first N lines of a screen-width window."
  (do ([i 0 (1+ i)])
      ([= i n])
    (blank-line win i cols)))

(define-method (blank-editor (winio <winio>))
  "Erase all the text on the editor window"
  (blank-lines (get-edit-win winio)
               (get-edit-win-lines winio)
               (get-cols winio)))

;; If we have a 3-line bottom window, blank the two lines where
;; shortcuts are written
(define-method (blank-shortcut-list (winio <winio>))
  "Erase all the text in the shortcut list area"
  (when (= 3 (get-bottom-win-lines winio))
    (blank-line (get-bottom-win winio) 1 (get-cols winio))
    (blank-line (get-bottom-win winio) 2 (get-cols winio))))

;; Clear the status bar
(define-method (blank-statusbar (winio <winio>))
  (blank-line (get-bottom-win winio) 0 (get-cols winio)))

;; Blank the first line of the top portion of the window.
(define-method (blank-titlebar (winio <winio>))
  (blank-line (get-top-win winio) 0 (get-cols winio)))

#|
;; Reset current_y, based on the position of current, and put the cursor
;; in the edit window at (current_y, current_x).
(define-method (reset-cursor (winio <winio>) (cbuf <CBuffer>))
  "Reset current-y, based on position of current, and put the cursor
in the edit window at that location"
  (let ([xpt (get-pp-from-pd-cur cbuf)]
        [y (- (get-line-cur cbuf) (get-line-frame cbuf))])
    ;; FIXME: softwrap should be handled here
    (when (< y (get-edit-win-lines winio))
      (move (get-edit-win winio) y
            (- xpt (get_page_start xpt))))))
|#

(define-method (display-titlebar (winio <winio>) path file? modified? readonly?)
  "Display the titlebar. When file? is true, assume PATH holds a
filename. If PATH is empty, assume this is a new file.  When file?
is false, assume PATH holds the path for a file browser. When, for
files, modified? is true, display the 'modified' label."
  (let* ((version (get-default-title winio))
         (prefix (cond
                  ((not file?)  "DIR:")
                  ((string-null? path) "New Buffer")
                  (else "File:")))
         (state (cond
                 ((not file?) "")
                 (readonly? "View")
                 (modified? "Modified")
                 (else "")))
         (cols-available (get-cols winio))
         (versionlen (count-cells-in-string version))
         (prefixlen (count-cells-in-string prefix))
         (statelen (count-cells-in-string state))
         (pathlen (count-cells-in-string path))
         ;; Depending on how many columns we've got available, let's print
         ;; as much information as we can
         (header
          (cond
           ((>= cols-available (+ 2 versionlen 2 prefixlen 1 statelen 1 pathlen 1))
            (format #f "  ~A  ~A ~A ~A " version prefix state path))
           ((>= cols-available (+ versionlen 1 prefixlen 1 statelen 1 pathlen))
            (format #f "~A ~A ~A ~A" version prefix state path))
           ((>= cols-available (+ prefixlen 1 statelen 1 pathlen))
            (format #f "~A ~A ~A" prefix state path))
           ((>= cols-available (+ prefixlen 1 pathlen))
            (format #f "~A ~A" prefix path))
           ((>= cols-available pathlen)
            (format #f "~A" pathlen))
           (else
            ""))))
    (attr-on! (get-top-win winio) A_REVERSE)
    (blank-titlebar winio)
    (addstr (get-top-win winio)
            header
            #:y 0 #:x 0)
    (attr-off! (get-top-win winio) A_REVERSE)
    (noutrefresh (get-top-win winio))
    ;; (reset-cursor)
    ;; (noutrefresh (get-edit-win winio))
    ))

(define-method (read-titlebar (winio <winio>))
  "Return a string containing the text currently in the titlebar"
  (instr (get-top-win winio) #:y 0 #:x 0))

(define-method (display-statusbar (winio <winio>) full-msg)
  "Display a message on the statusbar.  If constant cursor position display
is on, it is suspended."
  ;; If curses mode is off, just use regular printing
  (cond
   ((isendwin?)
    (format (current-error-port) "Error: ~S~%" full-msg))
   (else
    (blank-statusbar winio)
    ;;(set! full-msg (display-string full-msg 0 (- (get-cols winio) 4) #f))
    ;; (format #t "FULL MSG ~S~%" full-msg)
    (let* ((foo-len (count-cells-in-string full-msg))
           (start-x (quotient (+ (get-cols winio) (- foo-len) -4) 2)))
      (move (get-bottom-win winio) 0 start-x)
      (attr-on! (get-bottom-win winio) A_REVERSE)
      (addstr (get-bottom-win winio)"[ ")
      (addstr (get-bottom-win winio) full-msg)
      (addstr (get-bottom-win winio) " ]")
      (attr-off! (get-bottom-win winio) A_REVERSE)
      (noutrefresh (get-bottom-win winio))
      ;; Leave the cursor at its position in the edit window, not
      ;; in the statusber
      ;; (reset-cursor)
      (noutrefresh (get-edit-win winio))

      ;; Reset the statusbar clear counter to 26 keystrokes until
      ;; the message is removed.
      (set-status-blank! winio 26)))))

(define-method (read-statusbar (winio <winio>))
  "Return a string containing the text currently in the titlebar"
  (instr (get-bottom-win winio) #:y 0 #:x 0 #:n (get-cols winio)))

;; Write a shortcut key to the help area at the bottom of the window.
;; keystroke is e.g. "^G" and desc is e.g. "Get Help".  We are careful
;; to write at most len characters, even if len is very small and
;; keystroke and desc are long.  Note that waddnstr(,,(size_t)-1) adds
;; the whole string!  We do not bother padding the entry with blanks.
(define-method (onekey (winio <winio>) keystroke desc len)
  (let ((keystroke-len (+ 1 (count-cells-in-string keystroke))))
    (attr-on! (get-bottom-win winio) A_REVERSE)
    (addstr (get-bottom-win winio) keystroke #:n (get-index-from-string-cell keystroke len))
    (attr-off! (get-bottom-win winio) A_REVERSE)

    (if (> len keystroke-len)
        (set! len (- len keystroke-len))
        (set! len 0))
    (when (> len 0)
      (addch (get-bottom-win winio) (normal #\space))
      (addstr (get-bottom-win winio) desc
              #:n (get-index-from-string-cell desc len)))))

;; Display the shortcut list in S on the last two rows of the bottom
;; portion of the window
(define-method (display-shortcut-list (winio <winio>) shortcuts descriptions)
  "Given a list of keypress shortcuts and identical length list of function names,
display as many as will fit in the shortcut space."
  (when (= 3 (get-bottom-win-lines winio))
    (let* ((slen (min (get-main-visible winio) (length shortcuts)))
           ;; There will be this many characters per column, except
           ;; for the last two, which will be longer by (COLS %
           ;; colwidth) cols so as to not waste space.  We need at
           ;; least three cols to display anything properly
           (xLim (get-cols winio))
           (colwidth (quotient xLim (+ (quotient slen 2) (remainder slen 2)))))
      (blank-shortcut-list winio)
      (let loop ((i 0)
                 (n 0))
        (when (and (< n (length shortcuts))
                   (< i slen))
          (move (get-bottom-win winio) (+ 1 (remainder i 2)) (* colwidth (quotient i 2)))
          (onekey winio (list-ref shortcuts i) (list-ref descriptions i)
                  (+ colwidth (remainder (cols) colwidth)))
          (loop (+ i 1) (+ n 1))))
      (noutrefresh (get-bottom-win winio))
      ;; (reset_cursor)
      (noutrefresh (get-edit-win winio)))))

(define-method (read-shortcut-list (winio <winio>))
  "Return a string containing the text currently in the titlebar"
  (string-append (instr (get-bottom-win winio) #:y 1 #:x 0 #:n (get-cols winio))
                 "\n"
                 (instr (get-bottom-win winio) #:y 2 #:x 0 #:n (get-cols winio))))

;; Sets an attribute at the current position based on a string
(define (attr-set win name)
  (cond
   ((eqv? name "bold")
    (attr-on! win A_BOLD))
   ((eqv? name "/bold")
    (attr-off! win A_BOLD))
   ((eqv? name "reverse")
    (attr-on! win A_REVERSE))
   ((eqv? name "/reverse")
    (attr-off! win A_REVERSE))
   ((eqv? name "blink")
    (attr-on! win A_BLINK))
   ((eqv? name "/blink")
    (attr-off! win A_BLINK))
   ((eqv? name "dim")
    (attr-on! win A_DIM))
   ((eqv? name "/dim")
    (attr-off! win A_DIM))
   ((and (> 5 (string-length name))
         (string= "color" name 0 5 0 5))
    (let ((num (string->number (substring name 5))))
      (when (integer? num)
        (attr-on! win (color-pair num)))))
   ((and (> 6 (string-length name))
         (string= "/color" name 0 6 0 6))
    (let ((num (string->number (substring name 6))))
      (when (integer? num)
        (attr-off! win (color-pair num)))))))

;; Displays a string on a line of the editor, starting at a given
;; presentation ccolumn of the string.  If the string is wider than
;; the window, it is truncated.  If a list of tags is provided, it is
;; searched for decorators to be applied to the string.
(define-method (display-editor-line (winio <winio>) str line #|startcol tags|#)
  ;; FIXME: ove the cursor to the beginning of the screen line, and then
  ;; activate all the attributes up to startcol.
  ;; FIXME: print $ at the beginning of lines if startcol is not zero.
  (let ((displaystr (display-string str 0 (get-cols winio) #t)))
    ;; FIXME: iterating through the line, print the characters
    ;; one by one, activating attributes that appear in tags.
    (addstr (get-edit-win winio) displaystr #:y line #:x 0)
    ;; (noutrefresh (get-edit-win winio))
    )
  ;; FIXME: print $ at the end of lines that were truncated to fit.
  ;; FIXME: reset attributes
  )

;; Displays as many lines of strlist as will fit in the window, starting
;; at a given presentation column of the string.
(define-method (display-editor (winio <winio>) strlist startcol)
  (clear (get-edit-win winio))
  (for-each (lambda (i)
              (display-editor-line winio (list-ref strlist i) i))
            (iota (min (get-edit-win-lines winio)
                       (length strlist)))))

(define-method (read-editor (winio <winio>))
  (apply string-append
         (map (lambda (i)
                (string-append (instr (get-edit-win winio) #:y i #:x 0) "\n"))
              (iota (get-edit-win-lines winio)))))

(define-method (save-terminal-settings (winio <winio>))
  (set-old-terminal-settings! winio (tcgetattr 0)))

(define-method (restore-terminal-settings (winio <winio>))
  (tcsetattr! 0 TCSANOW (get-old-terminal-settings winio)))

;; Disable extended input and output processing in our terminal
;; settings.
(define (disable-terminal-extended-io)
  (let ((term (tcgetattr 0)))
    (termios-lflag-set! term (logand (termios-lflag term)
                                     (lognot IEXTEN)))
    (termios-oflag-set! term (logand (termios-oflag term)
                                     (lognot OPOST)))
    (tcsetattr! 0 TCSANOW term)))

;; Disable interpretation of the special control keys in our terminal
;; settings.
(define (disable-terminal-signals)
  (let ((term (tcgetattr 0)))
    (termios-lflag-set! term (logand (termios-lflag term)
                                     (lognot ISIG)))
    (tcsetattr! 0 TCSANOW term)))

;; Enable interpretation of the special control keys in our terminal
;; settings.
(define (enable-terminal-signals)
  (let ((term (tcgetattr 0)))
    (termios-cflag-set! term (logior (termios-lflag term)
                                     ISIG))
    (tcsetattr! 0 TCSANOW term)))

;; Disable interpretation of the flow control characters in our terminal
;; settings.
(define (disable-terminal-flow-control)
  (let ((term (tcgetattr 0)))
    (termios-iflag-set! term (logand (termios-iflag term)
                                     (lognot ISIG)))
    (tcsetattr! 0 TCSANOW term)))

;; Enable interpretation of the flow control characters in our terminal
;; settings.
(define (enable-terminal-flow-control)
  (let ((term (tcgetattr 0)))
    (termios-cflag-set! term (logior (termios-cflag term)
                                     IXON))
    (tcsetattr! 0 TCSANOW term)))

(define-method (disable-mouse-support (winio <winio>))
  "Disables mouse support and restores old mouseinterval"
  (mousemask 0)
  ;; Note that when oldinterval is -1, the mousinterval
  ;; is unchanged.
  (mouseinterval (get-old-mouse-click-interval winio)))

(define-method (enable-mouse-support (winio <winio>))
  "Enables mouse support and returns previous mouseinterval"
  (mousemask ALL_MOUSE_EVENTS)
  (set-old-mouse-click-interval! winio (mouseinterval 50)))

(define-method (initialize-mouse-support (winio <winio>))
  (if (get-use-mouse-p winio)
      (enable-mouse-support winio)
      (disable-mouse-support winio)))





;; Call the low-level getch() , trying up to MAX_TRIES times to get
;; a valid character.  Return ERR on failure.
(define (try-getch win max-tries)
  (let ((c (getch win)))
    (cond
     (c
      ;; sucessfully got key
      c)

     ((> max-tries 0)
      ;; try again
      (try-getch win (1- max-tries)))

     (else
      #f))))

;; Get a key.  If nodelay-mode is true, try only once.  If it is
;; false, try multiple times to get a valid character
(define (get-key-or-hangup win nodelay-mode)
  (if nodelay-mode
      (try-getch win 0)
      ;; else
      (let ((c (try-getch win MAX_TRIES)))
        (or c
            ;; If we've failed to get a character MAX-TRIES times in
            ;; a row, assume that the input source we were using is
            ;; gone and we'll need to die gracefully.
            'hangup))))

(define (allow-pending-sigwinch allow)
  ;; Don't know how to do this in Guile.
  #f)

;; Read in the first character, possibly with blocking input
(define (get-initial-key win block?)
  (if block?
      (nodelay! win #f)
      (nodelay! win #t))

  (allow-pending-sigwinch #t)

  ;; Just before reading in the first character, display any pending
  ;; screen updates.
  (doupdate)

  (let ((c (get-key-or-hangup win (not block?))))
    (when (eq? c 'hangup)
      (handle-hupterm 0))
    (allow-pending-sigwinch #f)
    (nodelay! win #t)
    (if (eq? c 'hangup)
        #f
        c)))

;; Read in subsequent characters with non-blocking input
(define (get-subsequent-key win)
  (nodelay! win #t)
  (allow-pending-sigwinch #t)
  (let ((c (get-key-or-hangup win #t)))
    (allow-pending-sigwinch #f)
    c))

(define (get-key-buffer win block?)
  (let ((initial (get-initial-key win block?)))
    (if (not initial)
        ;; No keys available, or port is dead
        #f

        ;; Found 1 key.  Look for more
        (let loop ((c (get-subsequent-key win))
                   (lst (list initial)))
          (if (not c)
              ;; no more keys waiting.  Return now.
              lst
              ;; else check for another key
              (loop (get-subsequent-key win) (append lst (list c))))))))

;; Buffer for unprocessed keypresses
(define key-buffer '())

(define (unget-key k)
  (set! key-buffer (append (list k) key-buffer)))

;; Update the keystroke buffer with any waiting characters, if any.
;; Then return the first INPUT-LEN characters of the buffer.  If less
;; than INPUT-LEN characters are available, just return what we have.
(define (get-input win input-len)
  (allow-pending-sigwinch #t)
  (allow-pending-sigwinch #f)

  (when win
    ;; Add any waiting keys to the key buffer.  If the key buffer
    ;; is empty, wait around for a key.
    (let ((new-keys (get-key-buffer win (null? key-buffer))))
      (when new-keys
        (set! key-buffer (append! key-buffer new-keys)))))

  (if (>= (length key-buffer) input-len)
      (let ((returned-keys (take key-buffer input-len)))
        (set! key-buffer (drop key-buffer input-len))
        returned-keys)
      ;; else
      (let ((returned-keys (list-copy key-buffer)))
        (set! key-buffer '())
        returned-keys)))

;; Translate ASCII characters, extended keypad values, and escape
;; sequences into their corresponding key values.
(define (parse-kbinput win)
  (let loop ((kbinput-list (get-input win 1))
             (escapes 0)
             (byte-digits 0))
    (let ((kbinput (if kbinput-list (car kbinput-list) #f)))
      (cond
       [(not kbinput)
        #f]

       [(eqv? kbinput KEY_MOUSE)
        (let ([m (getmouse)])
          (list 'mouse (second m) (third m) (fifth m)))]

       ;; The escape key prefixes an extended sequence.
       [(eq? kbinput #\esc)
        (loop (get-input win 1) (1+ (modulo escapes 3)) byte-digits)]

       [(= escapes 0)
        ;; A normal non-escaped input
        (list 'raw kbinput)]

       [(= escapes 1)
        (cond
         [(and (char? kbinput) (null? key-buffer))
          ;; One escape followed by a non-escape, and there aren't any
          ;; other keystrokes waiting.  Treat this as a meta key.
          (list 'meta (char-downcase kbinput))]

         [(null? key-buffer)
          ;; One escape followed by a control key.  Meta the control key
          (list 'meta kbinput)]

         [else
          ;; One escape followed by multiple keystrokes.  The multiple
          ;; keystrokes are some unhandled function key
          (unget-key kbinput)
          (and=> (parse-escape-seq-kbinput win)
                 (lambda (x)
                   (list 'raw x)))])]

       [(= escapes 2)
        (cond
         [(and (char? kbinput) (null? key-buffer))
          ;; Two escapes followed by a non-escape, and there aren't any
          ;; other keystrokes waiting.  Treat this as a meta key.
          (list 'meta (char-downcase kbinput))]

         [(null? key-buffer)
          ;; Two escapes followed by a control key.  Meta the control key
          (list 'meta kbinput)]

         [else
          ;; Two escapes followed by multiple keystrokes.  The multiple
          ;; keystrokes are some unhandled function key
          (unget-key kbinput)
          (and=> (parse-escape-seq-kbinput win)
                 (lambda (x)
                   (list 'raw x)))])]

       [(= escapes 3)
        (cond
         [(null? key-buffer)
          ;; Three escapes followed by a non escape with no other
          ;; character waiting just returns that character.
          (list 'raw kbinput)]

         [else
          ;; Three escapes followed by multiple keystrokes indicates
          ;; two escapes plus an unhandled function key.  Try to
          ;; parse the function key.  If yes, return the control'ed version
          ;; of that key.  If no, return #f.
          ;; (let ((seq (append (list kbinput) key-buffer)))
          ;;   (unget-key kbinput)
          ;;   (let ((k (parse-escape-seq-kbinput win)))
          ;;     (if k
          ;;         (list 'meta (get-control-kbinput k))
          ;;         (list 'raw #f))))])]))))
          #f])]))))

;; Translate escape sequences that ncurses didn't handle.  If the
;; terminfo for the terminal you are using were complete, you would
;; never fall into this function.  Any time you're in this function,
;; you've used the wrong terminfo or (much less likely) it is a bug
;; upstream.
(define escape-seq
  '(("\x1b01;2A" . KEY-SR)                ; shift-up on terminal
    ("\x1b01;2B" . KEY-SF)                ; shift-down on terminal
    ("\x1b01;2C" . KEY-SRIGHT)            ; shift-right on terminal
    ("\x1b01;2D" . KEY-SLEFT)             ; shift-left on terminal
    ("\x1b01;2P" . (key-f 13))            ; f13 on gnome+pcfkeys
    ("\x1b01;2Q" . (key-f 14))            ; f14 on
    ("\x1b01;2R" . (key-f 15))
    ("\x1b01;2S" . (key-f 16))
    ("\x1b01;5A" . kUP5)                  ; ctrl-up on Terminal
    ("\x1b01;5B" . kDN5)                  ; ctrl-down on Terminal
    ("\x1b01;5C" . kRIT5)                  ; ctrl-right on Terminal
    ("\x1b01;5D" . kLFT5)                  ; ctrl-left on Terminal
    ("\x1b02P" . (key-f 13))))               ; F13 on xterm-xf86-v40, xterm+pcf0

(define (parse-escape-seq-kbinput win)
  ;; We're here if we got an escape followed by an apparent escape sequence
  ;; that ncurses didn't handle
  (let ((key (assoc-ref escape-seq (apply string key-buffer))))
    (set! key-buffer '())
    key))

;; Translate a control character sequence: turn an ASCII non-control
;; character into its corresponding control character
(define (get-control-kbinput win)
  (let ((k (car key-buffer)))
    (set! key-buffer (drop key-buffer 1))
    (if (integer? k)
        ;; This is a keycode
        (list 'control k)
        ;; else
        (cond
         ((or (char=? k #\space) (char=? k #\2))
          #\nul)
         ((char=? k #\\)
          #\us)
         ((and (char>=? k #\3) (char<=? k #\7))
          (integer->char (- (char->integer k) 24)))
         ((or (char=? k #\8) (char=? k #\?))
          #\del)
         ((and (char>=? k #\@) (char<=? k #\-))
          (integer->char (- (char->integer k) 64)))
         ((and (char>=? k #\`) (char<=? k #\~))
          (integer->char (- (char->integer k) 96)))
         (else
          k)))))


;; Read in a single character.  If it's ignored, swallow it and go on.
;; Otherwise, try to translate it from ASCII, meta key sequences,
;; escape sequences, and/or extended keypad values.  Set meta-key to
;; TRUE when we get a meta key sequence, and set func-key to TRUE when
;; we get an extended keypad value.  Supported extended keypad values
;; consist of [arrow key], Ctrl-[arrow key], Shift-[arrow key], Enter,
;; Backspace, the editing keypad (Insert, Delete, Home, End, PageUp,
;; and PageDown), the function keypad (F1-F16), and the numeric keypad
;; with NumLock off.  Assume nodelay(win) is FALSE.
(define (get-kbinput win)
  ;; Read in a character and interpret it.  Continue doing this until
  ;; we get a recognized value or sequence. */
  (let ((kbinput (parse-kbinput win)))
    (if (not kbinput)
        (begin
          (usleep 100)
          (get-kbinput win))
        (begin
          #; (when (eq? win edit) (check-statusblank))
          kbinput))))




#|
;; Display a message on the statusbar, and set *disable-cursorpos* to
;; TRUE, so that the message won't be immediately overwritten if
;; constant cursor position display is on.
(define (DisplayStatusbar full-msg)
  (let ((old_whitespace #f))
    ;; If curses mode is off, just use regular printing
    (cond
     ((isendwin?)
      (display full-msg (current-error-port))
      (newline (current-error-port)))

     (else
      (BlankStatusbar)
      (set! old_whitespace (ISSET WHITESPACE_DISPLAY))
      (UNSET WHITESPACE_DISPLAY)

      (set! full-msg (display_string full-msg 0 (- (cols) 4) #f))

      (if old_whitespace
          (SET WHITESPACE_DISPLAY))

      (let* ((foo-len (CountCellsInString full-msg))
             (start-x (quotient (+ (cols) (- foo-len) -4) 2)))
        (move vWinBottom 0 start-x)
        (attr-on! vWinBottom vAttrReverse)
        (addstr vWinBottom "[ ")
        (addstr vWinBottom full-msg)
        (addstr vWinBottom " ]")
        (attr-off! vWinBottom vAttrReverse)
        (noutrefresh vWinBottom)
        (reset_cursor)

        ;; Leave the cursor at its position in the edit window, not
        ;; in the statusber
        (noutrefresh vWinEdit)

        (set! *disable-cursorpos* #t)
        ;; If we're doing quick statusbar blanking, and constant
        ;; cursor position display is off, blank the statusbar after
        ;; only one keystroke.  Otherwise, blank it after twenty-six
        ;; keystrokes, as Pico does.
        (set! *statusblank*
          (if (and (ISSET QUICK_BLANK)
                   (not (ISSET CONST_UPDATE)))
              1
              26)
          ))))))


;; Write a shortcut key to the help area at the bottom of the window.
;; keystroke is e.g. "^G" and desc is e.g. "Get Help".  We are careful
;; to write at most len characters, even if len is very small and
;; keystroke and desc are long.  Note that waddnstr(,,(size_t)-1) adds
;; the whole string!  We do not bother padding the entry with blanks.
(define (onekey keystroke desc len)
  (let ((keystroke_len (+ 1 (CountCellsInString keystroke))))
    (attr-on! vWinBottom vAttrReverse)
    (addstr vWinBottom keystroke #:n (GetIndexFromStringCell keystroke len))
    (attr-off! vWinBottom vAttrReverse)

    (if (> len keystroke_len)
        (set! len (- len keystroke_len))
        (set! len 0))
    (when (> len 0)
      (addch vWinBottom (normal #\space))
      (addstr vWinBottom desc #:n (GetIndexFromStringCell desc len)))))


;; If path is NULL, we're in normal editing mode, so display the
;; current version of nano, the current filename, and whether the
;; current file has been modified on the titlebar.  If path isn't
;; NULL, we're in the file browser, and path contains the directory to
;; start the file browser in, so display the current version of nano
;; and the contents of path on the titlebar
(define-method (display-file-titlebar (winio <winio>) 
"If mode is 'edit, display
(when (string-null? path)
(set! path #f))
(let ((space (cols))      ; The space we have available for display.
;; The length of the version message in cols, plus one for padding.
(verlen (+ 1 (CountCellsInString DEFAULT_TITLE)))
;; "DIR:", "File:", or "New Buffer".  Goes before filename.
(prefix #f)
;; The length of the prefix in cols, plus one for padding.
(prefixlen #f)
;; "Modified", "View", or "".  Shows the state of this  buffer.
(state #f)
;; The length of the state in cols, or the length of
;; "Modified" if the state is blank and we're not in the file
;; browser.
(statelen 0)
;; The filename, expanded for display
(exppath #f)
;; Do we say "new Buffer"
(newfie #f)
;; Do we put ellipsis before the path?
(dots #f))
(attr-on! vWinTop vAttrReverse)
(BlankTitlebar)

;; space has to be at least 4: two spaces before the version
;; message, at least one character of the version message, and one
;; space after the version message.
(if (< space 4)
(set! space 0)
;; else
;; Limit verlen to 1/3 the length of the screen incols, minus
;; 3 cols for spaces
(when (> verlen (- (quotient (cols) 3) 3))
(set! verlen (- (quotient (cols) 3) 3))))

(when (>= space 4)
;; Add a space after the version message, and account for both it and
;; the two spaces before it
(addstr vWinTop DEFAULT_TITLE #:y 0 #:x 2 #:n (GetIndexFromStringCell DEFAULT_TITLE verlen))
(set! verlen (+ verlen 3))
;; Account for the full length of the version message.
(set! space (- space verlen)))

;; Don't display the state if we're in the file browser. */
(when path
(set! state #f))

(unless path
(set! state (if #t ;;(is-modified? vBuffer)
"Modified"
(if (ISSET VIEW_MODE)
"View"
""))))
(set! statelen (CountCellsInString (if (and (string=? "" state) (not path))
"Modified"
state)))

;; If possible, add a space before state.
(cond
((and (> space 0) (< statelen space))
(set! statelen (+ 1 statelen)))

(else
(if (string-null? (GetBufferFileName))
(begin
(set! prefix "New Buffer")
(set! newfie #t))
;; else
(set! prefix "File:"))
(set! prefixlen (1+ (CountCellsInSubstring prefix (- space statelen))))

;; If newfie is #f, add a space after prefix
(when (and (not newfie) (< (+ prefixlen statelen) space))
(set! prefixlen (+ prefixlen 1)))

;; If we're not int he file browser, set path to the current
;; filename
(unless path
(set! path (GetBufferFileName)))

;; Account for the full lengths of the prefix and state
(if (>= space (+ prefixlen statelen))
(set! space (- state (+ prefixlen statelen)))
;; else
(set! space 0))

(unless newfie
(let ((lenpt (CountCellsInString path))
(start-col 0))

;; Dont' set dots to true if we have fewer than eight cols
;; (one col for padding, seven for a name)
(set! dots (and (>= space 8) (>= lenpt space)))

(if dots
(begin
(set! start-col (+ lenpt (- space) 3))
(set! space (- space 3)))
;; else
(set! start-col 0))

(set! exppath (display_string path start-col space #f))))

;; If dots is #t, we will display something like
;; "file: ...ename"
(if dots
(begin
(addstr vWinTop prefix #:x (1- verlen) #:y 0 #:n (GetIndexFromStringCell prefix prefixlen))
(if (not (or (<= space -3) newfie))
(begin
(addch vWinTop (normal #\space))
(addstr vWinTop "..." #:n (+ space 3))
(if (not (<= space 0))
(addstr vWinTop exppath)))))
;; else
(let ((exppathlen (if newfie 0 (CountCellsInString exppath))))
(addstr vWinTop prefix #:y 0 #:x (+ verlen (quotient (- space exppathlen) 3))
#:n (GetIndexFromStringCell prefix prefixlen))
(unless newfie
(addstr vWinTop " ")
(addstr vWinTop exppath))))))

(unless (string-null? state)
(if (>= statelen (- (cols) 1))
(addstr vWinTop state #:y 0 #:x 0 #:n (GetIndexFromStringCell state (cols)))
;; else
(addstr vWinTop state #:y 0 #:x (+ (cols) (- statelen) -1)
#:n (GetIndexFromStringCell state statelen))))

(attr-off! vWinTop vAttrReverse)
(noutrefresh vWinTop)
(reset_cursor)
(noutrefresh vWinEdit)))
|#


#|

(define vWinBottom #f)

(define DEFAULT_TITLE "Gano 0.0")

;; Should we temporarily disable constant cursor position display?
(define *disable-cursorpos* #f)

;; The number of keystrokes left after we call statusbar() before we
;; actually blank the statusbar.
(define *statusblank* 0)

;; The standard ncurses screen
(define vWinMain #f)
;; The top portion of the window, where we display the version
;; number of nano, the name of the current file, and whether
;; the current file has been modified
(define vWinTop #f)
;; The middle portion of the window, where we display the
;; file we're editing
(define vWinEdit #f)
;; The bottom portion of the window, where we display statusbar
;; messages, the statusbar primpt, and a list of shortcuts
(define vWinBottom #f)

;; How many rows does the window take up
(define editwinrows 0)

;; How many usable lines are there (due to soft wrapping)
(define maxrows 0)








;; Refresh the screen without changing the position of lines.  Use
;; this if we'ved moved and changed text.

(define (RefreshEditor)
(let* ([strings (render-frame vBuffer)]
[maxrows (min (length strings) (ComputeMaxRows))]
[nblanks 0])
(map
(lambda (y) 
(addstr vWinEdit (list-ref strings y) #:x 0 #:y y))
(iota maxrows))
(refresh vWinEdit)
;; (reset_cursor)
;; (refresh vWinEdit)
))

;; Move edittop to put it in range of current, keeping current in the
;; same place.  location determines how we move it: if it's CENTER, we
;; center current, and if it's NONE, we put current current_y lines
;; below edittop.

(define (edit_update location)
;; If location is CENTER, we move edittop up (editwinrows / 2)
;; lines.  This puts current at the center of the screen.  If
;; location is NONE, we move edittop up current_y lines if current_y
;; is in range of the screen, 0 lines if current_y is less than 0,
;; or (editwinrows - 1) lines if current_y is greater than
;; (editwinrows - 1).  This puts current at the same place on the
;; screen as before, or at the top or bottom of the screen if
;; edittop is beyond either.
(let ([goal (if (eq? location CENTER)
(quotient editwinrows 2)
;; else
(min (get-line-cur vBuffer)
(1- editwinrows)))]
[index (get-line-cur vBuffer)])

(while (and (> goal 0) (>= index 0))
(set! index (1- index))
(set! goal (1- goal))
;; Reduce the goal line to account for wrapped lines
(when (ISSET SOFTWRAP)
(set! goal (- goal (quotient (CountCellsInString (get-line-text vBuffer  index)) (cols))))))

(SetBufferLFrame! index)

(format (current-error-port) "edit_update(), setting edittop to lineno ~a~%"
(get-line-frame vBuffer))
(set! vfEditRefresh #t)))

;; Just update the Nth line of the document if it is on the screen.
;; This is basically a wrapper for edit_draw().  Returns: Number of
;; additional lines consumed (needed for SOFTWRAP)
(define (update_line n x)
(let ((line 0)
(extralinesused 0)
(converted #f)
(page_start #f)
(index 0)
(tmp #f))
(if (ISSET SOFTWRAP)
;; Find the screen line number of this line, taking into account
;; the fact that some lines could have wrapped
(let loop ((buffer-index (get-line-frame vBuffer))
(screen-line 0))
(if (and (< buffer-index (get-line-count vBuffer))
(< buffer-index n))
(loop (1+ buffer-index) (quotient (CountCellsInString (get-line-text vBuffer  index))
(cols)))
;; else
(set! line screen-line)))
;;else
(set! line (- n (get-line-frame vBuffer))))

(unless (or (< line 0) (>= line editwinrows))
;; First, blank out the line.
(blank-line vWinEdit line 0 (cols)))

;; Now to decide on the horizontal scroll position.  onvert
;; variables that index the line to their equivalent positions in
;; the expanded line.
(if (ISSET SOFTWRAP)
(set! index 0)
;; else
(set! index (CountCellsInSubstring (get-line-text vBuffer  n) index)))
(set! page_start (get_page_start index))

;; Expand the line, replacing tabs with spaces and control chars
;; with display forms
(format (current-error-port)
"before edit_draw: n = ~a page_start = ~a cols = ~a~%"
n page_start (cols))
(format (current-error-port)
"before edit_draw: orig_string = ~s~%"
(get-line-text vBuffer  n))
(set!
converted
(display_string (get-line-text vBuffer  n)
page_start
(cols)
(not (ISSET SOFTWRAP))))
(format (current-error-port)
"before edit_draw: converted_string = ~s ~%"
converted)


;; Paint the line.
(edit_draw n converted line page_start)

(if (not (ISSET SOFTWRAP))
(begin
(when (> page_start 0)
(addch vWinEdit (normal #\$) #:y line #:x 0))
(when (> (CountCellsInString (get-line-text vBuffer  n))
(+ page_start (cols)))
(addch vWinEdit (normal #\$) #:y line #:x (- (cols) 1))))
;; else
(begin
(error "implement me!!!")))

1))


;; edit_draw() takes care of the job of actually painting a line into
;; the edit window.  fileptr is the line to be painted, at row line of
;; the window.  converted is the actual string to be written to the
;; window, with tabs and control characters replaced by strings of
;; regular characters.  start is the column number of the first
;; character of this page.  That is, the first character of converted
;; corresponds to character number
;; GetIndexFromStringCell(fileptr->data, start) of the line.
(define (edit_draw fp converted line start)
;; Just paint the string in any case (we'll add color or reverse on
;; just the text that needs it). */
(addstr vWinEdit converted #:y line #:x 0))


;; When edittop changes, try and figure out how many lines we really
;; have to work with (i.e. set maxrows)
(define (ComputeMaxRows)
(cond
[(not (ISSET SOFTWRAP))
editwinrows]

[else
;; N is the line of the screen
;; INDEX is the line  of the file
(let ([n 0]
[index (get-line-frame vBuffer)]
[eof (get-line-count vBuffer)]
[maxrows 0])
(while #t
(if (and (< n editwinrows)
(< index eof))
(begin
(set! maxrows (+ maxrows 1))
(set! n (+ n (CountCellsInString (get-line-text vBuffer  index))))
(set! index (+ index 1)))
;; else
(break)))

(if (< n editwinrows)
(set! maxrows (+ maxrows (- editwinrows n))))

(format (current-error-port) "compute_maxrows(): maxrows ~a\n" maxrows)
maxrows)]))

;; Check if the number of keystrokes needed to blank the statusbar has
;; been pressed.  If so, blank the statusbar, unless constant cursor
;; position display is on. */
(define (check-statusblank)
(when (> *statusblank* 0)
(set! *statusblank* (- *statusblank* 1))
(when (and (= *statusblank* 0)
(not (ISSET CONST_UPDATE)))
(BlankStatusbar)
(noutrefresh vWinBottom)
(reset_cursor)
(noutrefresh vWinEdit))))

;; Return the shortcut corresponding to the values of kbinput (the key
;; itself), meta_key (whether the key is a meta sequence), and
;; func_key (whether the key is a function key), if any.  The shortcut
;; will be the first one in the list (control key, meta key sequence,
;; function key, other meta key sequence) for the corresponding
;; function.  For example, passing in a meta key sequence that
;; corresponds to a function with a control key, a function key, and a
;; meta key sequence will return the control key corresponding to that
;; function. */
(define (GetShortcutFromMenuKey menu kbinput meta_key)
(format (current-error-port) "get_shortcut(): kbinput ~s, meta_key ~s: "
kbinput meta_key)

(let ([shortcut (let loop ([i 0])
(if (< i (length vrgShortcuts))
(let ((s (list-ref vrgShortcuts i)))
;; (format (current-error-port) "\ttesting key ~a~s~%" (if (sc-meta s) "M-" "")
;;	  (sc-key s))
(if (and (logand menu (GetShortcutMenus s))
(eq? kbinput (GetShortcutKey s))
(eq? meta_key (IsShortcutMeta? s)))
s
;; else
(loop (+ i 1))))
;; else
#f))])
(if shortcut
(format (current-error-port) "FOUND ~s~%" shortcut)
(format (current-error-port) "no shortcut found~%"))

shortcut))

;; Mark the current file as modified if it isn't already, and then
;; update the titlebar to display the file's new status.
(define (set_modified)
(when (not (is-modified? vBuffer))
(SetBufferModified! #t)
(DisplayTitlebar "")))

;; If constant is TRUE, we display the current cursor position only if
;; *disable-cursorpos* is FALSE.  Otherwise, we display it
;; unconditionally and set *disable-cursorpos* to FALSE.  If constant is
;; TRUE and *disable-cursorpos* is TRUE, we also set *disable-cursorpos* to
;; FALSE, so that we leave the current statusbar alone this time, and
;; display the current cursor position next time.
(define (do_cursorpos constant)
(unless (and constant *disable-cursorpos*)
(let* ((line-cur (get-line-cur vBuffer))
(line-max (get-line-count vBuffer))
(line-ratio (if (zero? line-max)
0
(quotient (* 100 line-cur) line-max)))
(col-cur (1+ (get-pp-from-pd-cur vBuffer)))
(col-max (1+ (CountCellsInString (get-text-cur vBuffer))))
(col-ratio (if (zero? col-max)
0
(quotient (* 100 col-cur) col-max)))
(char-cur (GetBufferCCur))
(char-max (GetBufferCMax))
(char-ratio (if (zero? char-max)
0
(quotient (* 100 char-cur) char-max))))
(DisplayStatusbar (format #f "line ~a/~a (~a%), col ~a/~a (~a%), char ~a/~a (~a%)"
line-cur line-max line-ratio
col-cur col-max col-ratio
char-cur char-max char-ratio))))

(set! *disable-cursorpos* #f))


;; Return #t if a move up or down also requires a full update.  This
;; is true if the mark is set or if moving vertically would move the
;; cursor outside of the current edit window.
(define (NeedVerticalUpdate? xGoal)
(or (IsBufferMarkSet?)
(not (eqv? (get_page_start xGoal)
(get_page_start (GetBufferPpGoal))))))

;; This function needs optimization to be more like nano's function.
(define (ScrollEditor direction n)
(let ([nLines (cond [(eqv? direction 'up)
(max n (get-line-frame vBuffer))]
[(eqv? direction 'down)
(min n (- (get-line-count vBuffer) (get-line-frame vBuffer)))])])
(IncreaseBufferLFrame! (if (eq? direction 'up) (- n) n))
(set! vfEditRefresh #t)))
;; Return 1 if the MORE_SPACE flag is set, and 0 otherwise.  This is
;; used to calculate the relative screen position while taking this
;; flag into account, since it adds one line to the edit window.
(define (no_more_space)
(if (ISSET MORE_SPACE)
1
0))

;; Return 2 if the NO_HELP flag is set, and 0 otherwise.  This is used
;; to calculate the relative screen position while taking this flag
;; into account, since it removes two lines from the edit window.
(define (no_help)
(if (ISSET NO_HELP)
2
0))
|#

