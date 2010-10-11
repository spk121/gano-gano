m4_include(`config.m4')

(define-module (gano winio)
  #:use-module (gano chars)
  #:use-module (gano flags)
  #:use-module (gano global)
  #:use-module (gano nano-h)
  #:use-module (gano utils)
  #:use-module (ncurses curses)
  #:use-module (rnrs control)
  #:export (
            statusbar
            onekey
            display_string
            display_main_list
            blank_bottombars
            reset_cursor
            titlebar
            blank_titlebar
            edit_refresh
            ))

;; Should we temporarily disable constant cursor position display?
(define disable_cursorpos #f)
;; The number of keystrokes left after we call statusbar() before we
;; actually blank the statusbar.
(define statusblank 0)

;; move to x,y and write over a line with N spaces
(define (blank_line win y x n)
  (move win y x)
  (addstr win (make-string n #\space)))

(define (blank_statusbar)
  (blank_line bottomwin 0 0 (cols)))



;; Display a message on the statusbar, and set disable_cursorpos to
;; TRUE, so that the message won't be immediately overwritten if
;; constant cursor position display is on.
(define (statusbar full-msg)
  (let ((old_whitespace #f))
    ;; If curses mode is off, just use regular printing
    (cond 
     ((isendwin?)
      (display full-msg (current-error-port))
      (newline (current-error-port)))

     (else
      (blank_statusbar)
      m4_ifdef({NANO_TINY},{},{
      m4_ifdef({ENABLE_NANORC},{
      (set! old_whitespace (ISSET WHITESPACE_DISPLAY))
      (UNSET WHITESPACE_DISPLAY)
      })
      })

      (set! full-msg (display_string full-msg 0 (- (cols) 4) #f))

      m4_ifdef({NANO_TINY},{},{
      m4_ifdef({ENABLE_NANORC},{
      (if old_whitespace
          (SET WHITESPACE_DISPLAY))
      })
      })

      (let* ((foo_len (strlenpt full-msg))
             (start_x (quotient (+ (cols) (- foo_len) -4) 2)))
        (move bottomwin 0 start_x)
        (attr-on! bottomwin reverse_attr)
        (addstr bottomwin "[ ")
        (addstr bottomwin full-msg)
        (addstr bottomwin " ]")
        (attr-off! bottomwin reverse_attr)
        (noutrefresh bottomwin)
        (reset_cursor)

        ;; Leave the cursor at its position in the edit window, not
        ;; in the statusber
        (noutrefresh edit)

        (set! disable_cursorpos #t)
        ;; If we're doing quick statusbar blanking, and constant
        ;; cursor position display is off, blank the statusbar after
        ;; only one keystroke.  Otherwise, blank it after twenty-six
        ;; keystrokes, as Pico does.
        (set! statusblank 
              m4_ifdef({NANO_TINY},{
              26
              },{
              (if (and (ISSET QUICK_BLANK)
                       (not (ISSET CONST_UPDATE)))
                  1
                  26)
              })
              ))))))

;; Write a shortcut key to the help area at the bottom of the window.
;; keystroke is e.g. "^G" and desc is e.g. "Get Help".  We are careful
;; to write at most len characters, even if len is very small and
;; keystroke and desc are long.  Note that waddnstr(,,(size_t)-1) adds
;; the whole string!  We do not bother padding the entry with blanks.
(define (onekey keystroke desc len)
  (let ((keystroke_len (+ 1(strlenpt keystroke))))
    (attr-on! bottomwin reverse_attr)
    (addstr bottomwin keystroke #:n (actual_x keystroke len))
    (attr-on! bottomwin reverse_attr)

    (if (> len keystroke_len)
        (set! len (- len keystroke_len))
        (set! len 0))
    (when (> len 0)
        (addch bottomwin (normal #\space))
        (addstr bottomwin desc #:n (actual_x desc len)))))

;; Convert buf into a string that can be displayed on screen.  The
;; caller wants to display buf starting with column start_col, and
;; extending for at most len columns.  start_col is zero-based.  len
;; is one-based, so len == 0 means you get "" returned.  The returned
;; string is dynamically allocated, and should be freed.  If dollars
;; is TRUE, the caller might put "$" at the beginning or end of the
;; line if it's too long.
(define (display_string buf start_col len dollars)
  ;; If dollars is true, make room for the '$' at the end of the line.
  (when (and dollars (> len 0) (> (strlenpt buf) (+ start_col len)))
        (set! len (- len 1)))
  (cond 
   ((= len 0)
    "")
   (else
    (let* ((start_index (actual_x buf start_col))
           (column (strnlenpt buf start_index))
           (index 0)
           (converted ""))
      (cond

       ;; OK.  START_INDEX is the number of characters skipped so far
       ;; in this string, and COLUMN is the number of terminal
       ;; character cells skipped so far in this string.  If COLUMN is
       ;; less that START_COL, then the first character to be printed
       ;; takes more than once cell, and some of this character's
       ;; cells are not visible (left of the screen).

       ;; Check if some of this character's text starts to the left of
       ;; the screen
       ((and (< start_index (string-length buf))
             (not (eq? #\tab (string-ref buf start_index)))
             (or (< column start_col)
                 (and dollars
                      (> column 0))))
        ;; We don't display all of this character since it start to 
        ;; the left of the screen.
        (let ((initial_char (string-ref buf start_index)))
          (if (is_cntrl_char initial_char)
              ;; For control characters like '^C', this means we're
              ;; skipping the '^'
              (when (< column start_col)
                    (set! converted (string-append converted (string (control_ref initial_char))))
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
                    (set! start_index (+ start_index 1))))

          (set! start_index (+ start_index 1))

       ;; Now for the rest of the characters
       (while (< start_index (string-length buf))
              (let ((buf_mb (string-ref buf start_index)))
                
                (cond

                 ;; Tabs characters
                 ((eq? buf_mb #\tab)
                  m4_ifdef({NANO_TINY},{
                  (set! converted (string-append converted " ")) 
                  (set! index (+ index 1))
                  (set! start_col (+ start_col 1))
                  },{
                  m4_ifdef({ENABLE_NANORC},{
                  (if (ISSET WHITESPACE_DISPLAY)
                      (begin
                        (set! converted (string-append 
                                         converted 
                                         (string-take whitespace (list-ref whitespace-len 0))))
                        (set! index (+ index (list-ref whitespace-len 0)))
                        (set! start_col (+ start_col 1)))
                      ;; else
                      (begin
                        (set! converted (string-append converted " "))
                        (set! index (+ index 1))
                        (set! start_col (+ start_col 1))))
                  },{
                  (set! converted (string-append converted " "))
                  (set! index (+ index 1))
                  (set! start_col (+ start_col 1))
                  })
                  })
                  ;; advance to the next tab column
                  (let ((n (remainder start_col tabsizelen)))
                    (set! converted (string-append (make-string n #\space)))
                    (set! start_col (+ start_col n))
                    (set! index (+ index n))))
                 
                 ;; Control characters
                 ((is_cntrl_char buf_mb)
                  ;; First write the hat
                  (set! converted (string-append converted "^"))
                  (set! start_col (+ start_col 1))
                  (set! index (+ index 1))
                  ;; Then the modified character
                  (set! converted (string-append converted (string (control_rep buf_mb))))
                  (set! index (+ index 1))
                  (set! start_col (+ start_col (wcwidth (control_rep buf_mb)))))

                 ;; Space characters
                 ((eq? buf_mb #\space)
                  m4_ifdef({NANO_TINY},{
                  (set! converted (string-append converted " "))
                  (set! index (+ index 1))
                  (set! start_col (+ start_col 1))
                  },{
                  m4_ifdef({ENABLE_NANORC},{
                  (if (ISSET WHITESPACE_DISPLAY)
                      (begin
                        (set! converted (string-append 
                                         converted 
                                         (substring whitespace 
                                                    (list-ref whitespace_len 0)
                                                    (+ (list-ref whitespace_len 0)
                                                       (list-ref whitespace_len 1)))))
                        (set! index (+ index (list-ref whitespace-len 1)))
                        (set! start_col (+ start_col 1)))
                      ;; else
                      (begin
                        (set! converted (string-append converted " "))
                        (set! index (+ index 1))
                        (set! start_col (+ start_col 1))))
                  },{
                  (set! converted (string-append converted " "))
                  (set! index (+ index 1))
                  (set! start_col (+ start_col 1))
                  })
                  })
                  )

                 ;; Non-control, non-space characters
                 (else
                  (set! converted (string-append converted (string buf_mb)))
                  (set! start_col (+ start_col wcwidth buf_mb))
                  (set! index (+ index 1)))))
              (set! start_index (+ start_index 1))))))

      ;; Make sure converted takes up no more than len columns
      (set! converted (string-take converted (actual_x converted len)))
      converted))))

;; Display the shortcut list in S on the last two rows of the bottom 
;; portion of the window
(define (bottombars menu)
  (cond
   ((ISSET NO_HELP)
    #t)
   (else
    (let* ((slen (min MAIN_VISIBLE (length_of_list menu)))
           ;; There will be this many characters per column, except
           ;; for the last two, which will be longer by (COLS %
           ;; colwidth) columns so as to not waste space.  We need at
           ;; least three columns to display anything properly
           (colwidth (quotient (cols) (+ (quotient slen 2) (remainder slen 2)))))
      (blank_bottombars)

      m4_ifdef({DEBUG}, {
      (format (current-error-port) "In bottombars, and slen == \"~a\"~%" slen)
      })
      (let loop ((i 0)
                 (n 0))
        (if (and (< i (length allfuncs))
                 (< i slen))
            (begin
              (let ((func (list-ref allfuncs n)))
                m4_ifdef({DEBUG},{
                (format (current-error-port) "Checking menu iterm....");
                })
                (if (and (logtest menu (subnfunc-menus func))
                         (subnfunc-desc func)
                         (not (string-null? (subnfunc-desc func))))
                    (begin
                      (format (current-error-port) "found one! f->menus = ~a, desc = \"~a\"~%"
                              (subnfunc-menus func) (subnfunc-desc func))
                      (let ((s (first_sc_for menu (subnfunc-scfunc func))))
                        (begin
                          (if (not s)
                              (begin
                                (format (current-error-port) "Whoops, gues not, no shortcut key found fo func!~%")
                                (loop i (+ n 1)))
                              ;; else
                              (begin
                                (move bottomwin (+ 1 (remainder i 2))
                                      (* colwidth (quotient i 2)))
                                (format (current-error-port) "Calling onekey with keystr \"~a\" and desc \"~a\"~%"
                                        (sc-keystr s) (subnfunc-desc func))
                                (onekey (sc-keystr s) (subnfunc-desc func)
                                        (+ colwidth (remainder (cols) colwidth)))
                                (loop (+ i 1) (+ n 1)))))))
                    ;; else
                    (loop i (+ n 1)))))))
      (noutrefresh bottomwin)
      (reset_cursor)
      (noutrefresh edit)))))

;; If the NO_HELP flag isn't set, blank the last two lines of the bottom
;; portion of the window.
(define (blank_bottombars)
  (unless (ISSET NO_HELP)
          (blank_line bottomwin 1 0 (cols))
          (blank_line bottomwin 2 0 (cols))))
                
;; Reset current_y, based on the position of current, and put the cursor
;; in the edit window at (current_y, current_x).
(define (reset_cursor)
  (cond

    ;; If we haven't opened any files yet, put the cursor in the top
    ;; left corner of the edit window and get out.
   ((not (openfile?))
    (move edit 0 0))

   (else
    (refresh edit)
    (refresh bottomwin)
    (sleep 1)
    (display "implementme!!!"))))
#!
    (let ((xpt (xplustabs)))
      (if (ISSET SOFTWRAP)
          (begin
            ;; set the current y to the number of screen lines it takes to
            ;; display the the buffer up to this point
            (openfilestruct-current_y-set! (openfile)
                                           (map 
                                            (lambda (line) (+ 1 (quotient (strlenpt line) (cols))))
                                            (take (openfilestruct-edittop (openfile)) 
                                                  (openfilestruct-current (openfile)))))
	for (tmp = openfile->edittop; tmp && tmp != openfile->current; tmp = tmp->next)
	    openfile->current_y += 1 + strlenpt(tmp->data) / COLS;

	openfile->current_y += xplustabs() / COLS;
	if (openfile->current_y < editwinrows)
	    wmove(edit, openfile->current_y, xpt % COLS);
    } else {
	openfile->current_y = openfile->current->lineno -
	    openfile->edittop->lineno;

	if (openfile->current_y < editwinrows)
	    wmove(edit, openfile->current_y, xpt - get_page_start(xpt));
    }
}

          
!#           

;; Display the main shortcut list on the last two rows of the bottom
;; portion of the window
(define (display_main_list)
  (bottombars MMAIN))

;; If path is NULL, we're in normal editing mode, so display the
;; current version of nano, the current filename, and whether the
;; current file has been modified on the titlebar.  If path isn't
;; NULL, we're in the file browser, and path contains the directory to
;; start the file browser in, so display the current version of nano
;; and the contents of path on the titlebar
(define (titlebar path)
  (let ((space (cols))      ; The space we have available for display.
	;; The length of the version message in columns, plus one for padding.
        (verlen (+ 1 (strlenpt PACKAGE_STRING)))
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
    (attr-on! topwin reverse_attr)
    (blank_titlebar)

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
          (addstr topwin PACKAGE_STRING #:y 0 #:x 2 #:n (actual_x PACKAGE_STRING verlen))
          (set! verlen (+ verlen 3))
          ;; Account for the full length of the version message. 
          (set! space (- space verlen)))

    m4_ifdef({DISABLE_BROWSER},{},{
    ;; Don't display the state if we're in the file browser. */
    (when path
        (set! state #f))
    })

    (unless path
            (set! state (if (and (openfile?) (openfile-modified))
                            "Modified"
                            (if (ISSET VIEW_MODE)
                                "View"
                                ""))))
    (set! statelen (strlenpt (if (and (not state) (not path))
                                 "Modified"
                                 state)))

    ;; If possible, add a space before state.
    (if (and (> space 0) (< statelen space))
        (set! statelen (+ 1 statelen)))

    (display "fixme!\n")

    (addstr topwin state #:x 0 #:y 0)
    (attr-off! topwin reverse_attr)
    (noutrefresh topwin)
    (reset_cursor)
    (noutrefresh edit)))

;; Blank the first line of the top portion of the window.
(define (blank_titlebar)
  (blank_line topwin 0 0 (cols)))

;; Refresh the screen without changing the position of lines.  Use
;; this if we'ved moved and changed text.

(define (edit_refresh)
  (compute_maxrows)
  (let ((cn (openfile-current-lineno))
        (en (openfile-edittop-lineno)))
  (when (or (< cn en) (>= cn (+ en maxrows)))
        m4_ifdef({DEBUG},{
        (format (current-error-port) "edit_refresh(): line = ~a, edittop ~a + maxrows ~a\n"
                cn en maxrows)
        })
        ;; Put the top line of the edit window in range of the current line
        (edit_update CENTER))
  
  (let ((index (openfile-edittop-index))
        (nblanks 0))
    m4_ifdef({DEBUG},{
    (format (current-error-port) "edit_refresh(): edittop->lineno = ~a\n" en)
    })
    (let loop ((index index) (nlines 0))
      (if (and (< nlines editwinrows)
               (< index (length (openfile-fileage))))
          (loop (+ index 1) 
                (+ nlines (update_line (+ index
                                          (if (= index (openfile-current-index))
                                              (openfile-current_x)
                                              0)))))
          ;; else
          (set! nblanks nlines)))
    (let loop2 ((nblanks nblanks))
      (if (< nblanks editwinrows)
          (begin
            (blank_line edit nblanks 0 (cols))
            (loop2 (+ nblanks 1)))))
          ;;
    (reset_cursor)
    (noutrefresh edit))))

;; Just update the Nth line of the document if it is on the screen.
;; This is basically a wrapper for edit_draw().  Returns: Number of
;; additional lines consumed (needed for SOFTWRAP)
(define (update_line n . maxlen)
  (let ((line 0)
        (extralinesused 0)
        (converted #f)
        (page_start #f)
        (index 0)
        (tmp #f))
    (if (ISSET SOFTWRAP)
        ;; Find the screen line number of this line, taking into account
        ;; the fact that some lines could have wrapped
        (let loop ((buffer-index (openfile-edittop-index))
                   (screen-line 0))
               (if (and (< buffer-index (length (openfile-fileage)))
                        (< buffer-index n))
                   (loop (1+ buffer-index) (quotient (strlenpt (list-ref (openfile-fileage) buffer-index))
                                                     (cols)))
                   ;; else
                   (set! line screen-line)))
        ;;else
        (set! line (- n (openfile-edittop-index))))

    ;; First, blank out the line.
    (blank_line edit line 0 (cols))


    ;; Now to decide on the horizontal scroll position.  onvert
    ;; variables that index the line to their equivalent positions in
    ;; the expanded line.
    (if (ISSET SOFTWRAP)
        (set! index 0)
        ;; else
        (set! index 0))
        ;;(set! index (strnlenpt (filestruct-data (list-ref (openfile-fileage) n)) maxlen)))
    (set! page_start (get_page_start index))


    ;; Expande the line, replacing tabs with spaces and contro chars with display forms
    (set! converted (display_string (filestruct-data (list-ref (openfile-fileage) n))
                                    page_start (cols) (not (ISSET SOFTWRAP))))

    m4_ifdef({DEBUG},{
    (format (current-error-port) "update_line(): converted(1) line = ~a~%" converted)
    })

    ;; Paint the line.
    (edit_draw n converted line page_start)

    (if (not (ISSET SOFTWRAP))
        (begin
          (when (> page_start 0)
                (addch edit #\$ #:y line #:x 0))
          (when (> (strlenpt (filestruct-data (list-ref (openfile-fileage) n)))
                   (+ page_start (cols)))
                (addch edit #\$ #:y line #:x (- (cols) 1))))
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
;; corresponds to character number actual_x(fileptr->data, start) of the
;; line.
(define (edit_draw fp converted line start)
    ;; Just paint the string in any case (we'll add color or reverse on
    ;; just the text that needs it). */
    (addstr edit converted #:y line #:x 0))


;; When edittop changes, try and figure out how many lines we really
;; have to work with (i.e. set maxrows)
(define (compute_maxrows)
  (format #t "compute maxrows~%")
  (if (not (openfile?))
      (set! maxrows editwinrows)
      ;; else
      (let ((i (openfile-edittop-index)))
        (display i)
        (cond 
         ((not (ISSET SOFTWRAP))
          (set! maxrows editwinrows))
         
         (else
          (display "3:")
          
          (set! maxrows 0)
          (let loop ((dummy 0))
            (if (and (< n editwinrows)
                     (< index (length (openfile-fileage))))
                (begin
                  (set! maxrows (+ maxrows 1))
                  (set! n (+ n (strlenpt (filestruct-data (list-ref (openfile-fileage) i)))))
                  (set! i (+ i 1))
                  (loop 0))))
          (if (< n editwinrows)
              (set! maxrows (+ maxrows (- editwinrows n))))
          m4_ifdef({DEBUG},{
         (format (current-error-port) "compute_maxrows(): maxrows ~a\n" maxrows)
         })
          )))))

