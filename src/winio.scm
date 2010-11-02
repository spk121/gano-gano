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
  #:use-module (gano config)
  #:use-module (gano CBuffer)
  #:use-module (gano CFunction)
  #:use-module (gano CShortcut)
  #:use-module (gano CText)
  #:use-module (gano chars)
  #:use-module (gano flags)
  #:use-module (gano global)
  #:use-module (gano nano-h)
  #:use-module (gano utils)
  #:use-module (ncurses curses)
  #:use-module (ncurses extra)
  #:export (
	    do_cursorpos
	    BlankEditor
	    BlankShortcutList
	    BlankStatusbar
            BlankTitlebar
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
            update_line
            ))

(if %have-rnrs-control
    (use-modules (rnrs control))
    ;; else
    (use-modules (gano control)))

(define PACKAGE_STRING "Gano 0.0")

;; Should we temporarily disable constant cursor position display?
(define disable_cursorpos #f)
;; The number of keystrokes left after we call statusbar() before we
;; actually blank the statusbar.
(define statusblank 0)

;; move to x,y and write over a line with N spaces
(define (BlankLine win y x n)
  "Erase all the text on the given line"
  (move win y x)
  (addstr win (make-string n #\space)))

(define (BlankEditor)
  "Erase all the text on the editor window"
  (do ([i 0 (1+ i)]) ([= i editwinrows])
    (BlankLine vWinEdit i 0 (cols))))

;; If the NO_HELP flag isn't set, blank the last two lines of the bottom
;; portion of the window.
(define (BlankShortcutList)
  "Erase all the text in the shortcut list window"
  (unless (ISSET NO_HELP)
    (BlankLine vWinBottom 1 0 (cols))
    (BlankLine vWinBottom 2 0 (cols))))

;; Clear the status bar
(define (BlankStatusbar)
  (BlankLine vWinBottom 0 0 (cols)))

;; Blank the first line of the top portion of the window.
(define (BlankTitlebar)
  (BlankLine vWinTop 0 0 (cols)))

;; Display the shortcut list in S on the last two rows of the bottom
;; portion of the window
(define (DisplayShortcutList menu)
  (cond
   ((ISSET NO_HELP)
    #t)
   (else
    (let* ((slen (min MAIN_VISIBLE (CountEntriesInMenu menu)))
           ;; There will be this many characters per column, except
           ;; for the last two, which will be longer by (COLS %
           ;; colwidth) columns so as to not waste space.  We need at
           ;; least three columns to display anything properly
	   (xLim (cadr (getmaxyx vWinMain)))
           (colwidth (quotient xLim (+ (quotient slen 2) (remainder slen 2)))))
      (BlankShortcutList)

      (format (current-error-port) "In bottombars, and cols == \"~a\" (should be 80)~%" xLim)
      (format (current-error-port) "In bottombars, and slen == \"~a\" (should be 12)~%" slen)
      (format (current-error-port) "In bottombars, and colwidth == \"~a\" (should be 13)~%" colwidth)
      (let loop ((i 0)
                 (n 0))
        (if (and (< n (length vrgFunctions))
                 (< i slen))
            (begin
              (let ((func (list-ref vrgFunctions n)))

                (format (current-error-port) "Checking menu item....~%");

                (if (and (logtest menu (GetFunctionMenus func))
                         (GetFunctionDesc func)
                         (not (string-null? (GetFunctionDesc func))))
                    (begin
                      (format (current-error-port) "found one! f->menus = ~a, desc = \"~a\"~%"
                              (GetFunctionMenus func) (GetFunctionDesc func))
                      (let ((s (FindFirstShortcut menu (GetFunctionId func))))
                        (begin
                          (if (not s)
                              (begin
                                (format (current-error-port) "Whoops, gues not, no shortcut key found fo func!~%")
                                (loop i (+ n 1)))
                              ;; else
                              (begin
                                (move vWinBottom (+ 1 (remainder i 2))
                                      (* colwidth (quotient i 2)))
                                (format (current-error-port) "Calling onekey with keystr \"~a\" and desc \"~a\"~%"
                                        (GetShortcutKeyStr s) (GetFunctionDesc func))
                                (onekey (GetShortcutKeyStr s) (GetFunctionDesc func)
                                        (+ colwidth (remainder (cols) colwidth)))
                                (loop (+ i 1) (+ n 1)))))))
                    ;; else
                    (loop i (+ n 1)))))))
      (noutrefresh vWinBottom)
      (reset_cursor)
      (noutrefresh vWinEdit)))))

;; Display a message on the statusbar, and set disable_cursorpos to
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

      (let* ((foo_len (CountCellsInString full-msg))
             (start_x (quotient (+ (cols) (- foo_len) -4) 2)))
        (move vWinBottom 0 start_x)
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

        (set! disable_cursorpos #t)
        ;; If we're doing quick statusbar blanking, and constant
        ;; cursor position display is off, blank the statusbar after
        ;; only one keystroke.  Otherwise, blank it after twenty-six
        ;; keystrokes, as Pico does.
        (set! statusblank
              (if (and (ISSET QUICK_BLANK)
                       (not (ISSET CONST_UPDATE)))
                  1
                  26)
              ))))))

;; If path is NULL, we're in normal editing mode, so display the
;; current version of nano, the current filename, and whether the
;; current file has been modified on the titlebar.  If path isn't
;; NULL, we're in the file browser, and path contains the directory to
;; start the file browser in, so display the current version of nano
;; and the contents of path on the titlebar
(define (DisplayTitlebar path)
  (when (string-null? path)
    (set! path #f))
  (let ((space (cols))      ; The space we have available for display.
	;; The length of the version message in columns, plus one for padding.
        (verlen (+ 1 (CountCellsInString PACKAGE_STRING)))
	;; "DIR:", "File:", or "New Buffer".  Goes before filename.
        (prefix #f)
	;; The length of the prefix in columns, plus one for padding.
        (prefixlen #f)
	;; "Modified", "View", or "".  Shows the state of this  buffer.
        (state #f)
	;; The length of the state in columns, or the length of
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
        ;; Limit verlen to 1/3 the length of the screen incolumns, minus
        ;; 3 columns for spaces
        (when (> verlen (- (quotient (cols) 3) 3))
	  (set! verlen (- (quotient (cols) 3) 3))))

    (when (>= space 4)
      ;; Add a space after the version message, and account for both it and
      ;; the two spaces before it
      (addstr vWinTop PACKAGE_STRING #:y 0 #:x 2 #:n (GetIndexFromStringCell PACKAGE_STRING verlen))
      (set! verlen (+ verlen 3))
      ;; Account for the full length of the version message.
      (set! space (- space verlen)))

    ;; Don't display the state if we're in the file browser. */
    (when path
      (set! state #f))

    (unless path
      (set! state (if (IsBufferModified?)
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
	      (start_col 0))

	  ;; Dont' set dots to true if we have fewer than eight columns
	  ;; (one col for padding, seven for a name)
	  (set! dots (and (>= space 8) (>= lenpt space)))

	  (if dots
	      (begin
		(set! start_col (+ lenpt (- space) 3))
		(set! space (- space 3)))
	      ;; else
	      (set! start_col 0))

	  (set! exppath (display_string path start_col space #f))))

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

;; Initialize the three window portions that nano uses.
(define (InitWindow)
  (set! editwinrows (+ (lines) -5 (no_more_space) (no_help)))
  (when (or (< (cols) MIN_EDITOR_COLS)
            (< editwinrows MIN_EDITOR_ROWS))
    (error (_ "Window size is too small for nano...~%")))

  ;; Set up fill column, based on the screen width
  (set! viColFill viColWrap)
  (when (<= viColFill 0)
    (set! viColFill (+ viColFill (cols))))
  (when (< viColFill 0)
    (set! viColFill 0))


  (when vWinTop
    (delwin vWinTop))
  (when vWinEdit
    (delwin vWinEdit))
  (when vWinBottom
    (delwin vWinBottom))

  (set! vWinTop (newwin (- 2 (no_more_space))
                       (cols)
                       0
                       0))
  (set! vWinEdit (newwin editwinrows
                     (cols)
                     (- 2 (no_more_space))
                     0))
  (set! vWinBottom (newwin (- 3 (no_help))
                          (cols)
                          (+ editwinrows 2 (- (no_more_space)))
                          0))

  ;; Turn on the keypad for the windows, if necessary
  (unless (ISSET REBIND_KEYPAD)
    (keypad! vWinTop #t)
    (keypad! vWinEdit #t)
    (keypad! vWinBottom #t)))

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

;; Convert buf into a string that can be displayed on screen.  The
;; caller wants to display buf starting with column start_col, and
;; extending for at most len columns.  start_col is zero-based.  len
;; is one-based, so len == 0 means you get "" returned.  The returned
;; string is dynamically allocated, and should be freed.  If dollars
;; is TRUE, the caller might put "$" at the beginning or end of the
;; line if it's too long.
(define (display_string buf start_col len dollars)
  ;; If dollars is true, make room for the '$' at the end of the line.
  (when (and dollars (> len 0) (> (CountCellsInString buf) (+ start_col len)))
    (set! len (- len 1)))
  (cond
   ((= len 0)
    "")
   (else
    (let* ((start_index (GetIndexFromStringCell buf start_col))
           (column (CountCellsInSubstring buf start_index))
           (index 0)
           (converted ""))
      ;; OK.  START_INDEX is the number of characters skipped so far
      ;; in this string, and COLUMN is the number of terminal
      ;; character cells skipped so far in this string.  If COLUMN is
      ;; less that START_COL, then the first character to be printed
      ;; takes more than once cell, and some of this character's
      ;; cells are not visible (left of the screen).

      ;; Check if some of this character's text starts to the left of
      ;; the screen
      (when (and (< start_index (string-length buf))
		 (not (eq? #\tab (string-ref buf start_index)))
		 (or (< column start_col)
		     (and dollars
			  (> column 0))))
        ;; We don't display all of this character since it start to
        ;; the left of the screen.
        (let ((initial_char (string-ref buf start_index)))
          (if (IsControlChar? initial_char)
              ;; For control characters like '^C', this means we're
              ;; skipping the '^'
              (when (< column start_col)
		(set! converted (string-append converted (string (GetDisplayCharFromControlChar initial_char))))
		(set! index (+ index 1))
		(set! start_col (+ start_col 1))
		(set! start_index (+ start_index 1)))
              ;; else
              ;; for two-cell characters like kanji, we can't print just the second-half
              ;; of the character, so we print a space instead.
              (when (= 2 (wcwidth initial_char))
		(set! converted (string-append converted " "))
		(set! index (+ index 1))
		(set! start_col (+ start_col 1))
		(set! start_index (+ start_index 1))))))

      ;; Now for the rest of the characters
      (while (< start_index (string-length buf))
	(let ((c (string-ref buf start_index)))

	  (cond

	   ;; Tabs characters
	   ((eq? c #\tab)
	    (if (ISSET WHITESPACE_DISPLAY)
		(begin
		  ;; Extract the alternate screen representation of #\tab
		  (let* ((white-len (list-ref vWhiteSpaceLen 0))
			 (white (string-take vWhiteSpace white-len)))
		    (set! converted (string-append converted white))
		    (set! index white-len)
		    (set! start_col (+ start_col 1))))
		;; else
		(begin
		  ;; Make sure #\tab creates at least 1 space
		  (set! converted (string-append converted " "))
		  (set! index (+ index 1))
		  (set! start_col (+ start_col 1))

		  ;; advance to the next tab column
		  (let ((n (- vTabSize (remainder start_col vTabSize))))
		    (format (current-error-port) "do tab: index ~a start_col ~a vTabSize ~a~%" index start_col vTabSize)
		    (set! converted (string-append converted (make-string n #\space)))
		    (set! start_col (+ start_col n))
		    (set! index (+ index n))))))

	   ;; Control characters
	   ((IsControlChar? c)
	    ;; First write the hat
	    (set! converted (string-append converted "^"))
	    (set! start_col (+ start_col 1))
	    (set! index (+ index 1))
	    ;; Then the modified character
	    (set! converted (string-append converted (string (GetDisplayCharFromControlChar c))))
	    (set! index (+ index 1))
	    (set! start_col (+ start_col (wcwidth (GetDisplayCharFromControlChar c)))))

	   ;; Space characters
	   ((eq? c #\space)
	    (if (ISSET WHITESPACE_DISPLAY)
		;; Extract the alternate screen representation of #\space
		(let* ((white-len (list-ref vWhiteSpaceLen 1))
		       (white (substring vWhiteSpace
					 (list-ref vWhiteSpaceLen 0)
					 (+ (list-ref vWhiteSpaceLen 0)
					    white-len))))
		  (set! converted (string-append converted white))
		  (set! index white-len)
		  (set! start_col (+ start_col 1)))
		;; else
		;;  write a space
		(begin
		  (set! converted (string-append converted " "))
		  (set! index (+ index 1))
		  (set! start_col (+ start_col 1)))))

	   ;; Non-control, non-space characters
	   (else
	    (set! converted (string-append converted (string c)))
	    (set! start_col (+ start_col (wcwidth c)))
	    (set! index (+ index 1)))))

	(set! start_index (+ start_index 1)))

      ;; Make sure converted takes up no more than len columns
      (format (current-error-port) "before trunc: str ~s len ~s~%"
	      converted len)
      (set! converted (string-take converted (GetIndexFromStringCell converted len)))
      converted))))


;; Reset current_y, based on the position of current, and put the cursor
;; in the edit window at (current_y, current_x).
(define (reset_cursor)
  (cond
   ;; If we haven't opened any files yet, put the cursor in the top
   ;; left corner of the edit window and get out.
   [(null? vrgBuffers)
    (move vWinEdit 0 0)]

   [else
    (let ([xpt (GetPpFromBufferPdCur)])
      (if (ISSET SOFTWRAP)
	  (error "implement me!")
	  ;; else
	  (begin
            (format (current-error-port) "resetCursor: before YCur ~s ICur ~s ITop ~s xpt ~s~%"
                    (GetBufferYCur) (GetBufferLCur) (GetBufferLFrame) xpt)
	    (SetBufferYCur! (- (GetBufferLCur) (GetBufferLFrame)))
	    (when (< (GetBufferYCur) editwinrows)
	      (move vWinEdit (GetBufferYCur) (- xpt (get_page_start xpt))))
            (format (current-error-port) "resetCursor: after YCur ~s ICur ~s ITop ~s~%"
                    (GetBufferYCur) (GetBufferLCur) (GetBufferLFrame)))))]))



;; Refresh the screen without changing the position of lines.  Use
;; this if we'ved moved and changed text.

(define (RefreshEditor)
  (let ([cn (GetBufferLCur)]
        [en (GetBufferLFrame)]
        [maxrows (ComputeMaxRows)]
        [nblanks 0])
    (when (or (< cn en) (>= cn (+ en maxrows)))
      ;; Put the top line of the edit window in range of the current line
      (edit_update CENTER))

    (do ([nlines 0 nlines] [index (GetBufferLFrame) (1+ index)])
        ([or (>= nlines editwinrows) (>= index (GetBufferLLim))])
      (set! nlines (+ nlines (update_line index (if (= index (GetBufferLCur))
                                                    (GetBufferPdCur)
                                                    0))))
      (set! nblanks nlines))
    (do ([nblanks nblanks (1+ nblanks)]) ([>= nblanks editwinrows])
      (BlankLine vWinEdit nblanks 0 (cols)))

    (reset_cursor)
    (noutrefresh vWinEdit)))

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
		  (min (GetBufferYCur)
		       (1- editwinrows)))]
	[index (GetBufferLCur)])

    (while (and (> goal 0) (>= index 0))
      (set! index (1- index))
      (set! goal (1- goal))
      ;; Reduce the goal line to account for wrapped lines
      (when (ISSET SOFTWRAP)
	(set! goal (- goal (quotient (CountCellsInString (GetBufferLine index)) (cols))))))

    (SetBufferLFrame! index)

    (format (current-error-port) "edit_update(), setting edittop to lineno ~a~%"
	    (GetBufferLFrame))
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
        (let loop ((buffer-index (GetBufferLFrame))
                   (screen-line 0))
	  (if (and (< buffer-index (GetBufferLLim))
		   (< buffer-index n))
	      (loop (1+ buffer-index) (quotient (CountCellsInString (GetBufferLine index))
						(cols)))
	      ;; else
	      (set! line screen-line)))
        ;;else
        (set! line (- n (GetBufferLFrame))))

    (unless (or (< line 0) (>= line editwinrows))
      ;; First, blank out the line.
      (BlankLine vWinEdit line 0 (cols)))

    ;; Now to decide on the horizontal scroll position.  onvert
    ;; variables that index the line to their equivalent positions in
    ;; the expanded line.
    (if (ISSET SOFTWRAP)
	(set! index 0)
	;; else
	(set! index (CountCellsInSubstring (GetBufferLine n) index)))
    (set! page_start (get_page_start index))

    ;; Expand the line, replacing tabs with spaces and control chars
    ;; with display forms
    (format (current-error-port)
	    "before edit_draw: n = ~a page_start = ~a cols = ~a~%"
	    n page_start (cols))
    (format (current-error-port)
	    "before edit_draw: orig_string = ~s~%"
	    (GetBufferLine n))
    (set!
     converted
     (display_string (GetBufferLine n)
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
	  (when (> (CountCellsInString (GetBufferLine n))
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
	  [index (GetBufferLFrame)]
	  [eof (GetBufferLLim)]
          [maxrows 0])
      (while #t
	(if (and (< n editwinrows)
		 (< index eof))
	    (begin
	      (set! maxrows (+ maxrows 1))
	      (set! n (+ n (CountCellsInString (GetBufferLine index))))
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
(define (check_statusblank)
  (when (> statusblank 0)
    (set! statusblank (- statusblank 1))
    (when (and (= statusblank 0)
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
  (when (not (IsBufferModified?))
    (SetBufferModified! #t)
    (DisplayTitlebar "")))

;; If constant is TRUE, we display the current cursor position only if
;; disable_cursorpos is FALSE.  Otherwise, we display it
;; unconditionally and set disable_cursorpos to FALSE.  If constant is
;; TRUE and disable_cursorpos is TRUE, we also set disable_cursorpos to
;; FALSE, so that we leave the current statusbar alone this time, and
;; display the current cursor position next time.
(define (do_cursorpos constant)
  (unless (and constant disable_cursorpos)
    (let* ((line-cur (GetBufferLCur))
	   (line-max (GetBufferLLim))
	   (line-ratio (if (zero? line-max)
			   0
			   (quotient (* 100 line-cur) line-max)))
	   (col-cur (1+ (GetPpFromBufferPdCur)))
	   (col-max (1+ (CountCellsInString (GetBufferLineCur))))
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

  (set! disable_cursorpos #f))


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
                       (max n (GetBufferLFrame))]
                      [(eqv? direction 'down)
                       (min n (- (GetBufferLLim) (GetBufferLFrame)))])])
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
