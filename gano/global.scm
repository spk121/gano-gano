;;; global.scm
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

(define-module (gano global)
  #:use-module (gano records)
  #:use-module (gano flags)
  #:use-module (gano nano-h)
  #:use-module (ncurses curses)
  #:use-module (rnrs control)
  #:use-module (srfi srfi-1)
  #:export (
            operating_dir
	    search_history
	    syntaxes
	    search_history_index
	    replace_history
	    replace_history_index
	    homedir
            print_sclist
            punct
            brackets
            whitespace
            whitespace_len
	    sctofunc
            quotestr
            quotereg
            quoteerr
            quotelen
            regcomp
            backup_dir
            alt_speller
            syntaxstr
            jump_buf
            jump_buf_main
            fill
            wrap_at
            first_sc_for
            last_search
            last_replace
            tabsizelen
            mainwin
            topwin
            edit
            bottomwin
            editwinrows
            shortcut_init
            reverse_attr
            length_of_list
            allfuncs
            maxrows
            currmenu
            sclist
            edit_refresh_needed
	    matchbrackets
	    iso_me_harder_funcmap
            ))

;; Used to return to either main or the unjustify routing
;; in do justify after a SIGWINCH
(define jump_buf #f)
;; Have we set jump_buf so that we return to main after
;; a SIGWINCH?
(define jump_buf_main #f)

;; The columns at which we will wrap lines.
(define fill 0)
;; The position where we will wrap lines.  fill is equal to this if
;; it's greater than zero, and equal to (COLS + this) if it isn't.

;; FIXME: In C, this uses CHARS_FROM_EOL which is a #define
(define wrap_at -8)

;; The last string we searched for
(define last_search #f)
;; The last replacement string we searched for
(define last_replace #f)


;; The standard ncurses screen
(define mainwin #f)
;; The top portion of the window, where we display the version
;; number of nano, the name of the current file, and whether
;; the current file has been modified
(define topwin #f)
;; The middle portion of the window, where we display the
;; file we're editing
(define edit #f)
;; The bottom portion of the window, where we display statusbar
;; messages, the statusbar primpt, and a list of shortcuts
(define bottomwin #f)
;; How many rows does the window take up
(define editwinrows 0)
;; How many usable lines are there (due to soft wrapping)
(define maxrows 0)

;; The buffer where we store cut text
(define cutbuffer #f)
(define cutbottom #f)
;; The buffer where we store unjustified text
(define jusbuffer #f)
;; The partition where we store a portion of the current file
(define filepart #f)


;; The opening and closing brackets that can be found by bracket
;; searches
(define matchbrackets #f)

;; The characters used when display the first characters of tabs
;; and spaces
(define whitespace #f)
;; The length of these characters
(define whitespace_len '(0 0))

;; The closing punctuation that can end sentences
(define punct #f)
;; The closing brackets that can follow closing punctuation and
;; can end sentences
(define brackets #f)
;; The quoting string
(define quotestr #f)
;; The compiled regular expression from the quoting string
(define quotereg #f)
;; Whether it compiled successfully
(define quoterc 0)
;; The error message, if it didn't
(define quoteerr #f)
;; The length of the quoting string in bytes
(define quotelen)

;; Are we in nodelay mode (checking for a cancel while doing something)
(define nodelay_mode #f)

;; The answer string used by the statusbar prompt
(define answer #f)

;; The width of a tab in spaces.  The default is set in main
(define tabsizelen -1)

;; The directory where we store backup files
(define backup_dir #f)
;; The relative path to the operating directory, which
;; we can't move outside of
(define operating_dir #f)
;; The full path
(define full_operating_dir #f)

;; The command to use for the alternate spell checker
(define alt_speller #f)

;; The global list of color syntaxes
(define syntaxes #f)
;; The color syntax name specified on the command line
(define syntaxstr #f)

;; Did a command mangle enough of the buffer refresh that we should
;; repaing the screen
(define edit_refresh_needed #f)

;; The current shortcut list we're using
(define currshortcut #f)
;; The currently loaded menu
(define currmenu #f)

;; The shortcut key struct: a list of sc's
(define sclist #f)

;; The main function list: a list of subnfunc's
(define allfuncs #f)

;; The search string history list
(define search_history #f)
;; The top of the search string history list
(define search_history_index #f)
;; The bottom of the search string history list
;;(define searchbot #f)
;; The replace string history list
(define replace_history #f)
;; Top of the replace string history list
(define replace_history_index #f)
;; Bottom of the replace string history list
;;(define replacebot #f)

;; The compiled regular expressionto use in searches
(define search_regexp #f)
;; The match positions for parenthetical subexpressions,
;; 10 maximum, used in regular expression searches
(define regmatches #f)

;; The curses attribute for reverse video
(define reverse_attr A_REVERSE)

;; The user's home directory: from $HOME or /etc/passwd
(define homedir #f)

;; Return the number of entries in the shortcut list S for
;; a given menu
(define (length_of_list menu)
  (let loop ((index 0)
             (count 0))
    (if (< index (length allfuncs))
        (begin
          (let ((f (list-ref allfuncs index)))
            (if (not f)
                count
                ;; else
                (if (and menu
                         (subnfunc-menus f)
                         )
                    (loop (+ index 1) (+ count 1))
                    ;; else
                    (loop (+ index 1) count)))))
        count)))

;; Set type of function based on the string
(define (strtokeytype str)
  (let ((first-char (string-ref str 0)))
    (cond
     ((char-ci=? #\m first-char)
      META)
     ((char=? #\^ first-char)
      CONTROL)
     ((char-ci=? #\f first-char)
      FKEY)
     (else
      RAW))))

;; Add a string to the new function list struct.
(define (add_to_funcs func menus desc help blank_after viewok)
  (let ((f #f))
    (if (not allfuncs)
        ;; Initialization of allfuncs global
        (set! allfuncs (list (make-subnfunc)))
        ;; else
        (set! allfuncs (append! allfuncs (list (make-subnfunc)))))
    (set! f (last allfuncs))
    (subnfunc-next-set! f #f)
    (subnfunc-scfunc-set! f func)
    (subnfunc-menus-set! f menus)
    (subnfunc-desc-set! f desc)
    (subnfunc-viewok-set! f viewok)
    (subnfunc-help-set! f help)
    (subnfunc-blank_after-set! f blank_after)

    (format (current-error-port) "Added func \"~a\"" (subnfunc-desc f))))

(define (first_sc_for menu func)
  (let ((metasc #f)
        (sc #f)
	(len (length sclist)))
    (let loop ((i 0))
      (if (< i len)
          (let ((s (list-ref sclist i)))
            (if (and (logtest (sc-menu s) menu)
		     (eq? (sc-scfunc s) func))
		(if (eq? (sc-type s) META)
		    (begin
		      (set! metasc s)
		      (loop (+ i 1)))
		    ;; else
		    (set! sc s)
		    ;; and stop looping
		    )
		;; else
		(loop (+ i 1))))))
    ;; If we are here we have only found meta sequences.  If so, use
    ;; one.
    (cond
     (sc
      sc)
     (metasc
      metasc)
     (else
      (format (current-error-port) "Whoops, returning null given func ~a in menu ~a~%"
              func menu)
      #f))))




;; Add a string to the new shortcut list implementation.
(define (add_to_sclist menu scstring func toggle execute)
  (let ((s #f))
    (if (not sclist)
        ;; Initialize the shortcut list if, if necessary
        (begin
          (set! sclist (list (make-sc)))
          (set! s (car sclist)))
        ;; else, fast forward to a matching entry or the end of the list
        (begin
          (let ((match (find (lambda (x)
                               (and (eq? (sc-menu x) menu)
                                    (string=? (sc-keystr x) scstring)))
                             sclist)))
            (if match
                (set! s match)
                ;; else
                ;; add a new shortcut to the end of the list
                (begin
                  ;; This is not a replace
                  (format (current-error-port) "No match found...~%")
                  (set! sclist (append sclist (list (make-sc))))
                  (set! s (last sclist)))))))

    (sc-type-set! s (strtokeytype scstring))
    (sc-menu-set! s menu)
    (sc-toggle-set! s toggle)
    (sc-keystr-set! s scstring)
    (sc-scfunc-set! s func)
    (sc-execute-set! s execute)
    (assign_keyinfo s)

    (format (current-error-port) "list val = ~a~%" (sc-menu s))
    (format (current-error-port)
            "Hey, set sequence to ~a for shortcut \"~a\"~%"
            (sc-seq s) scstring)
    ))

(define (assign_keyinfo s)
  ;; Assign the info to the shortcut struct.  Assumes keystr is already
  ;; assigned, naturally.
  (let ((type (sc-type s))
        (keystr (sc-keystr s)))
    (cond
     ((eq? type CONTROL)
      (sc-seq-set! s (- (char->integer (string-ref keystr 1)) 64)))
     ((eq? type META)
      (sc-seq-set! s (char->integer (char-downcase (string-ref keystr 2)))))
     ((eq? type FKEY)
      (sc-seq-set! s (key-f (string->number (string-drop keystr 1)))))
     (else
      (sc-seq-set! s (char->integer (string-ref keystr 0)))))

    ;; Override some keys that don't bind as nicely as one would like.
    (cond
     ((and (eq? (sc-type s) CONTROL)
           (string-ci=? "space" (string-drop keystr 1)))
      (sc-seq-set! s 0))
     ((and (eq? (sc-type s) META)
           (string-ci=? "space" (string-drop keystr 2)))
      (sc-seq-set! s (char->integer #\space)))
     ((and (eq? (sc-type s) RAW)
           (string-ci=? "kup" keystr))
      (sc-seq-set! s KEY_UP))
     ((and (eq? (sc-type s) RAW)
           (string-ci=? "kdown" keystr))
      (sc-seq-set! s KEY_DOWN))
     ((and (eq? (sc-type s) RAW)
           (string-ci=? "kleft" keystr))
      (sc-seq-set! s KEY_LEFT))
     ((and (eq? (sc-type s) RAW)
           (string-ci=? "kright" keystr))
      (sc-seq-set! s KEY_RIGHT))
     ((and (eq? (sc-type s) RAW)
           (string-ci=? "kinser" keystr))
      (sc-seq-set! s KEY_IC))
     ((and (eq? (sc-type s) RAW)
           (string-ci=? "kdel" keystr))
      (sc-seq-set! s KEY_DC))
     ((and (eq? (sc-type s) RAW)
           (string-ci=? "kbsp" keystr))
      (sc-seq-set! s KEY_BACKSPACE))
     ((and (eq? (sc-type s) RAW)
           (string-ci=? "kenter" keystr))
      (sc-seq-set! s KEY_ENTER))
     ((and (eq? (sc-type s) RAW)
           (string-ci=? "kpup" keystr))
      (sc-seq-set! s KEY_PPAGE))
     ((and (eq? (sc-type s) RAW)
           (string-ci=? "kpdown" keystr))
      (sc-seq-set! s KEY_NPAGE))
     ((and (eq? (sc-type s) RAW)
           (string-ci=? "khome" keystr))
      (sc-seq-set! s KEY_HOME))
     ((and (eq? (sc-type s) RAW)
           (string-ci=? "kend" keystr))
      (sc-seq-set! s KEY_END))
     )))

(define (print_sclist)
  (for-each (lambda (s)
              (let ((f (sctofunc s)))
                (if f
                    (format (current-error-port)
                            "Shortcut \"~a\", function: ~a, menus ~a\n"
                            (sc-keystr s) (subnfunc-desc f) (subnfunc-menus f))
                    (format (current-error-port)
                            "Hmm, didnt find a func for \"~a\"\n" (sc-keystr s)))))
            sclist))

;; Stuff we need to make at least static here so we can access it
;; below.
(define cancel_msg (N_ "Cancel"))
(define replace_msg (N_ "Replace"))
(define no_replace_msg (N_ "No Replace"))

(define case_sens_msg (N_ "Case Sens"))
(define backwards_msg (N_ "Backwards"))
(define regexp_msg (N_ "Regexp"))

(define prev_history_msg (N_ "PrevHstory"))
(define next_history_msg (N_ "NextHstory"))
(define gototext_msg (N_ "Go To Text"))
;; TRANSLATORS: Try to keep the next three strings at most 12 characters.
(define whereis_next_msg (N_ "WhereIs Next"))
(define first_file_msg (N_ "First File"))
(define last_file_msg (N_ "Last File"))
;; TRANSLATORS: Try to keep the next nine strings at most 16 characters.
(define to_files_msg (N_ "To Files"))
(define dos_format_msg (N_ "DOS Format"))
(define mac_format_msg (N_ "Mac Format"))
(define append_msg (N_ "Append"))
(define prepend_msg (N_ "Prepend"))
(define backup_file_msg (N_ "Backup File"))
(define ext_cmd_msg (N_ "Execute Command"))
(define new_buffer_msg (N_ "New Buffer"))
(define goto_dir_msg (N_ "Go To Dir"))

(define (shortcut_init unjustify)
  "Initialize all shortcut lists.  If unjustify is #t, replace the
the \"Uncut\" key with the \"Unjustify\" command"
  (let (
        ;; TRANSLATORS: Try to keep the following strings at most 10
        ;; characters.
        (get_help_msg (N_ "Get Help"))
        (exit_msg (N_ "Exit"))
        (whereis_msg (N_ "Where Is"))
        (prev_page_msg (N_ "Prev Page"))
        (next_page_msg (N_ "Next Page"))
        (first_line_msg (N_ "First Line"))
        (last_line_msg (N_ "Last Line"))
        (suspend_msg (N_ "Suspend"))
        (beg_of_par_msg (N_ "Beg of Par"))
        (end_of_par_msg (N_ "End of Par"))
        (fulljustify_msg (N_ "FullJstify"))
        (refresh_msg (N_ "Refresh"))
        (insert_file_msg (N_ "Insert File"))
        (go_to_line_msg (N_ "Go To Line"))
        (nano_justify_msg (N_ "Justify the current paragraph"))

        ;;TRANSLATORS: The next long series of strings are shortcut
        ;;descriptions; they are best kept shorter than 56 characters,
        ;;but may be longer
        (nano_cancel_msg (N_ "Cancel the current function"))
        (nano_help_msg (N_ "Display this help text"))
        (nano_exit_msg
         (N_ "Close the current file buffer / Exit from nano"))

        (nano_writeout_msg (N_ "Write the current file to disk"))
        (nano_insert_msg (N_ "Insert another file into the current one"))
        (nano_whereis_msg (N_ "Search for a string or a regular expression"))
        (nano_prevpage_msg (N_ "Go to previous screen"))
        (nano_nextpage_msg (N_ "Go to next screen"))
        (nano_cut_msg (N_ "Cut the current line and store it in the cutbuffer"))
        (nano_uncut_msg (N_ "Uncut from the cutbuffer into the current line"))
        (nano_cursorpos_msg (N_ "Display the position of the cursor"))
        (nano_spell_msg
         (N_ "Invoke the spell checker, if available"))
        (nano_replace_msg
         (N_ "Replace a string or a regular expression"))
        (nano_gotoline_msg  (N_ "Go to line and column number"))
        (nano_mark_msg  (N_ "Mark text at the cursor position"))
        (nano_whereis_next_msg  (N_ "Repeat last search"))
        (nano_copy_msg
         (N_ "Copy the current line and store it in the cutbuffer"))
        (nano_indent_msg  (N_ "Indent the current line"))
        (nano_unindent_msg  (N_ "Unindent the current line"))
        (nano_undo_msg  (N_ "Undo the last operation"))
        (nano_redo_msg  (N_ "Redo the last undone operation"))
        (nano_forward_msg  (N_ "Go forward one character"))
        (nano_back_msg  (N_ "Go back one character"))
        (nano_nextword_msg  (N_ "Go forward one word"))
        (nano_prevword_msg  (N_ "Go back one word"))
        (nano_prevline_msg  (N_ "Go to previous line"))
        (nano_nextline_msg  (N_ "Go to next line"))
        (nano_home_msg  (N_ "Go to beginning of current line"))
        (nano_end_msg  (N_ "Go to end of current line"))
        (nano_parabegin_msg
         (N_ "Go to beginning of paragraph; then of previous paragraph"))
        (nano_paraend_msg
         (N_ "Go just beyond end of paragraph; then of next paragraph"))
        (nano_firstline_msg (N_ "Go to the first line of the file"))
        (nano_lastline_msg (N_ "Go to the last line of the file"))
        (nano_bracket_msg  (N_ "Go to the matching bracket"))
        (nano_scrollup_msg
         (N_ "Scroll up one line without scrolling the cursor"))
        (nano_scrolldown_msg
         (N_ "Scroll down one line without scrolling the cursor"))
        (nano_prevfile_msg (N_ "Switch to the previous file buffer"))
        (nano_nextfile_msg (N_ "Switch to the next file buffer"))
        (nano_verbatim_msg (N_ "Insert the next keystroke verbatim"))
        (nano_tab_msg (N_ "Insert a tab at the cursor position"))
        (nano_enter_msg (N_ "Insert a newline at the cursor position"))
        (nano_delete_msg (N_ "Delete the character under the cursor"))
        (nano_backspace_msg
         (N_ "Delete the character to the left of the cursor"))
        (nano_cut_till_end_msg
         (N_ "Cut from the cursor position to the end of the file"))
        (nano_fulljustify_msg  (N_ "Justify the entire file"))
        (nano_wordcount_msg
         (N_ "Count the number of words, lines, and characters"))
        (nano_refresh_msg (N_ "Refresh (redraw) the current screen"))
        (nano_suspend_msg
         (N_ "Suspend the editor (if suspend is enabled)"))
        (nano_case_msg (N_ "Toggle the case sensitivity of the search"))
        (nano_reverse_msg (N_ "Reverse the direction of the search"))
        (nano_regexp_msg (N_ "Toggle the use of regular expressions"))
        (nano_prev_history_msg
         (N_ "Recall the previous search/replace string"))
        (nano_next_history_msg
         (N_ "Recall the next search/replace string"))
        (nano_tofiles_msg  (N_ "Go to file browser"))
        (nano_dos_msg  (N_ "Toggle the use of DOS format"))
        (nano_mac_msg  (N_ "Toggle the use of Mac format"))
        (nano_append_msg  (N_ "Toggle appending"))
        (nano_prepend_msg  (N_ "Toggle prepending"))
        (nano_backup_msg
         (N_ "Toggle backing up of the original file"))
        (nano_execute_msg  (N_ "Execute external command"))
        (nano_multibuffer_msg (N_ "Toggle the use of a new buffer"))
        (nano_exitbrowser_msg  (N_ "Exit from the file browser"))
        (nano_firstfile_msg (N_ "Go to the first file in the list"))
        (nano_lastfile_msg (N_ "Go to the last file in the list"))
        (nano_forwardfile_msg  (N_ "Go to the next file in the list"))
        (nano_backfile_msg  (N_ "Go to the previous file in the list"))
        (nano_gotodir_msg (N_ "Go to directory")))

    ;; Clear out the old function list, if any
    (set! allfuncs #f)
    (gc)

    (add_to_funcs DO_HELP_VOID
                  (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE
                          MWRITEFILE MINSERTFILE MEXTCMD MSPELL MBROWSER
                          MWHEREISFILE MGOTODIR)
                  get_help_msg nano_help_msg #f VIEW)

    (add_to_funcs CANCEL_MSG
                  (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MWRITEFILE
                          MINSERTFILE MEXTCMD MSPELL MWHEREISFILE MGOTODIR
                          MYESNO)
                  cancel_msg nano_cancel_msg #f VIEW);

    (add_to_funcs DO_EXIT
                  MMAIN
                  ;; TRANSLATORS: Try to keep this at most 10 characters.
                  (if (and (openfile?) (> (openfile-count) 1))
		      (N_ "Close") exit_msg)
		  nano_exit_msg #f VIEW)

    (add_to_funcs DO_EXIT
		  MBROWSER
		  exit_msg nano_exitbrowser_msg #f VIEW)

    ;; TRANSLATORS: Try to keep this at most 10 characters.
    (add_to_funcs DO_WRITEOUT_VOID
		  MMAIN
		  (N_ "WriteOut") nano_writeout_msg #f NOVIEW)

    ;; TRANSLATORS: Try to keep this at most 10 characters.
    (add_to_funcs DO_JUSTIFY_VOID
		  MMAIN
		  (N_ "Justify") nano_justify_msg #t NOVIEW)

    ;; We allow inserting files in view mode if multibuffers are
    ;; available, so that we can view multiple files.  If we're using
    ;; restricted mode, inserting files is disabled, since it allows
    ;; reading from or writing to files not specified on the command
    ;; line.
    (add_to_funcs (if (ISSET RESTRICTED) NANO_DISABLED_MSG DO_INSERTFILE_VOID)
		  MMAIN
		  (N_ "Read File") nano_insert_msg #f VIEW)

    (add_to_funcs DO_SEARCH
		  (logior MMAIN MBROWSER)
		  whereis_msg nano_whereis_msg #f VIEW)
    (add_to_funcs DO_PAGE_UP
		  (logior MMAIN MHELP MBROWSER)
		  prev_page_msg nano_prevpage_msg #f VIEW)
    (add_to_funcs DO_PAGE_DOWN
		  (logior MMAIN MHELP MBROWSER)
		  next_page_msg nano_nextpage_msg #t VIEW)

    ;; TRANSLATORS: Try to keep this at most 10 characters.
    (add_to_funcs DO_CUT_TEXT_VOID
		  MMAIN
		  (N_ "Cut Text") nano_cut_msg #f NOVIEW)
    (if unjustify
	;; TRANSLATORS: Try to keep this at most 10 characters.
	(add_to_funcs DO_UNCUT_TEXT
		      MMAIN (N_ "UnJustify") "" #f NOVIEW)
	;; else
	(add_to_funcs DO_UNCUT_TEXT
		      MMAIN (N_ "UnCut Text") nano_uncut_msg
		      #f  NOVIEW))

    ;; TRANSLATORS: Try to keep this at most 10 characters.
    (add_to_funcs DO_CURSORPOS_VOID
		  MMAIN
		  (N_ "Cur Pos") nano_cursorpos_msg #f VIEW)

    ;; If we're using restricted mode, spell checking is disabled
    ;; because it allows reading from or writing to files not specified
    ;; on the command line.
    (if (not (ISSET RESTRICTED))
	;; TRANSLATORS: Try to keep this at most 10 characters.
	(add_to_funcs DO_SPELL
		      MMAIN
		      (N_ "To Spell") nano_spell_msg #t NOVIEW))

    (add_to_funcs DO_FIRST_LINE
		  (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE)
		  first_line_msg nano_firstline_msg #f VIEW)

    (add_to_funcs DO_LAST_LINE
		  (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE)
		  last_line_msg nano_lastline_msg #t VIEW)

    (add_to_funcs DO_GOTOLINECOLUMN_VOID
		  (logior MMAIN MWHEREIS)
		  go_to_line_msg nano_gotoline_msg #f VIEW)

    (add_to_funcs DO_REPLACE
		  (logior MMAIN MWHEREIS)
		  replace_msg nano_replace_msg #f NOVIEW)

    (add_to_funcs DO_MARK MMAIN (N_ "Mark Text") nano_mark_msg #f VIEW)
    (add_to_funcs DO_RESEARCH (logior MMAIN MBROWSER) whereis_next_msg
		  nano_whereis_next_msg #t VIEW)
    (add_to_funcs DO_COPY_TEXT MMAIN (N_ "Copy Text") nano_copy_msg #f NOVIEW)
    (add_to_funcs DO_INDENT_VOID MMAIN (N_ "Indent Text") nano_indent_msg #f NOVIEW)
    (add_to_funcs DO_UNINDENT MMAIN (N_ "Unindent Text") nano_unindent_msg #f NOVIEW)

    (when (ISSET UNDOABLE)
      (add_to_funcs DO_UNDO MMAIN (N_ "Undo") nano_undo_msg #f NOVIEW)
      (add_to_funcs DO_REDO MMAIN (N_ "Redo") nano_redo_msg #t NOVIEW))

    (add_to_funcs DO_RIGHT MMAIN (N_ "Forward") nano_forward_msg #f VIEW)
    (add_to_funcs DO_RIGHT MBROWSER (N_ "Forward") nano_forwardfile_msg #f VIEW)
    (add_to_funcs DO_RIGHT MALL "" "" #f VIEW)
    (add_to_funcs DO_LEFT MMAIN (N_ "Back") nano_back_msg #f VIEW)
    (add_to_funcs DO_LEFT MBROWSER (N_ "Back") nano_backfile_msg #f VIEW)
    (add_to_funcs DO_LEFT MALL "" "" FALSE VIEW)
    (add_to_funcs DO_NEXT_WORD_VOID MMAIN (N_ "Next Word") nano_nextword_msg #f VIEW)
    (add_to_funcs DO_PREV_WORD_VOID MMAIN (N_ "Prev Word") nano_prevword_msg #f VIEW)
    (add_to_funcs DO_UP_VOID (logior MMAIN MHELP MBROWSER)
		  (N_ "Prev Line") nano_prevline_msg #f VIEW)
    (add_to_funcs DO_DOWN_VOID (logior MMAIN MHELP MBROWSER)
		  (N_ "Next Line") nano_nextline_msg #t VIEW)
    (add_to_funcs DO_HOME MMAIN (N_ "Home") nano_home_msg #f VIEW)
    (add_to_funcs DO_END MMAIN (N_ "End") nano_end_msg #f VIEW)
    (add_to_funcs DO_PARA_BEGIN_VOID (logior MMAIN MWHEREIS)
		  beg_of_par_msg nano_parabegin_msg #f VIEW)
    (add_to_funcs DO_PARA_END_VOID (logior MMAIN MWHEREIS)
		  end_of_par_msg nano_paraend_msg #f VIEW)
    (add_to_funcs DO_FIND_BRACKET MMAIN (_ "Find Other Bracket") nano_bracket_msg #f VIEW)
    (add_to_funcs DO_SCROLL_UP
		  MMAIN
		  (N_ "Scroll Up") nano_scrollup_msg #f VIEW)

    (add_to_funcs DO_SCROLL_DOWN
		  MMAIN
		  (N_ "Scroll Down") nano_scrolldown_msg #f VIEW)
    (add_to_funcs SWITCH_TO_PREV_BUFFER_VOID
		  MMAIN
		  (_ "Previous File") nano_prevfile_msg #f VIEW)
    (add_to_funcs SWITCH_TO_NEXT_BUFFER_VOID
		  MMAIN
		  (N_ "Next File") nano_nextfile_msg #t VIEW)
    (add_to_funcs DO_VERBATIM_INPUT
		  MMAIN
		  (N_ "Verbatim Input") nano_verbatim_msg #f
		  NOVIEW)
    (add_to_funcs DO_VERBATIM_INPUT
		  (logior MWHEREIS MREPLACE MREPLACE2 MEXTCMD MSPELL)
		  ""  ""  #f  NOVIEW)
    (add_to_funcs DO_TAB
		  MMAIN
		  (N_ "Tab") nano_tab_msg #f NOVIEW)
    (add_to_funcs DO_TAB
		  MALL
		  ""  ""  #f  NOVIEW)
    (add_to_funcs DO_ENTER
		  MMAIN
		  (N_ "Enter") nano_enter_msg #f  NOVIEW)
    (add_to_funcs DO_ENTER
		  MALL
		  ""  ""  #f  NOVIEW)
    (add_to_funcs DO_DELETE
		  MMAIN
		  (N_ "Delete") nano_delete_msg #f NOVIEW)
    (add_to_funcs DO_DELETE
		  MALL
		  ""  ""  #f  NOVIEW)
    (add_to_funcs DO_BACKSPACE
		  MMAIN
		  (N_ "Backspace") nano_backspace_msg #t NOVIEW)
    (add_to_funcs DO_BACKSPACE
		  MALL
		  ""  ""
		  #t NOVIEW)

    (add_to_funcs DO_CUT_TILL_END
		  MMAIN
		  (N_ "CutTillEnd") nano_cut_till_end_msg #t
		  NOVIEW)
    (add_to_funcs XON_COMPLAINT
		  MMAIN
		  ""  ""  #f  VIEW);
    (add_to_funcs XOFF_COMPLAINT
		  MMAIN
		  ""  ""  #f  VIEW);

    (add_to_funcs DO_FULL_JUSTIFY
		  (logior MMAIN MWHEREIS)
		  (N_ "Justify") nano_fulljustify_msg #f NOVIEW)
    (add_to_funcs DO_WORDLINECHAR_COUNT
		  MMAIN
		  (N_ "Word Count") nano_wordcount_msg #f VIEW)
    (add_to_funcs TOTAL_REFRESH
		  (logior MMAIN MHELP)
		  refresh_msg nano_refresh_msg #f VIEW)

    (add_to_funcs DO_SUSPEND_VOID
		  MMAIN
		  suspend_msg nano_suspend_msg #t VIEW)
    (add_to_funcs CASE_SENS_MSG
		  (logior MWHEREIS MREPLACE MWHEREISFILE)
		  case_sens_msg nano_case_msg #f VIEW)

    (add_to_funcs BACKWARDS_MSG
		  (logior MWHEREIS MREPLACE MWHEREISFILE)
		  backwards_msg nano_reverse_msg #f VIEW)
    (add_to_funcs REGEXP_MSG
		  (logior MWHEREIS MREPLACE MWHEREISFILE)
		  regexp_msg nano_regexp_msg #f VIEW)
    (add_to_funcs PREV_HISTORY_MSG
		  (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
		  prev_history_msg nano_prev_history_msg #f VIEW)
    (add_to_funcs NEXT_HISTORY_MSG
		  (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
		  next_history_msg nano_next_history_msg #f VIEW)
    (add_to_funcs NO_REPLACE_MSG
		  MREPLACE
		  no_replace_msg nano_whereis_msg #f VIEW)

    (add_to_funcs GOTOTEXT_MSG
		  MGOTOLINE
		  gototext_msg nano_whereis_msg #t VIEW)
    (if (not (ISSET RESTRICTED))
	(add_to_funcs TO_FILES_MSG
		      (logior MGOTOLINE MINSERTFILE)
		      to_files_msg nano_tofiles_msg #f VIEW))

    ;; If we're using restricted mode, the DOS format, Mac format,
    ;; append, prepend, and backup toggles are disabled.  The first and
    ;; second are useless since inserting files is disabled, the third
    ;; and fourth are disabled because they allow writing to files not
    ;; specified on the command line, and the fifth is useless since
    ;; backups are disabled.
    (unless (ISSET RESTRICTED)
      (add_to_funcs DOS_FORMAT_MSG
		    MWRITEFILE
		    dos_format_msg nano_dos_msg #f NOVIEW)
      (add_to_funcs MAC_FORMAT_MSG
		    MWRITEFILE
		    mac_format_msg nano_mac_msg #f  NOVIEW)
      (add_to_funcs APPEND_MSG
		    MWRITEFILE
		    append_msg nano_append_msg #f NOVIEW)
      (add_to_funcs PREPEND_MSG
		    MWRITEFILE
		    prepend_msg nano_prepend_msg #f NOVIEW)
      (add_to_funcs BACKUP_FILE_MSG MWRITEFILE
		    backup_file_msg nano_backup_msg #f
		    NOVIEW))

    ;; If we're using restricted mode, command execution is disabled.
    ;; It's useless since inserting files is disabled.
    (if (not (ISSET RESTRICTED))
	(add_to_funcs EXT_CMD_MSG
		      MINSERTFILE
		      ext_cmd_msg nano_execute_msg #f NOVIEW))

    ;; If we're using restricted mode  the multibuffer toggle is
    ;; disabled.  It's useless since inserting files is disabled.
    (if (not (ISSET RESTRICTED))
	(add_to_funcs NEW_BUFFER_MSG
		      MINSERTFILE
		      new_buffer_msg nano_multibuffer_msg #f
		      NOVIEW))
    (add_to_funcs  INSERT_FILE_MSG
		   MEXTCMD
		   insert_file_msg nano_insert_msg #f VIEW)

    (add_to_funcs NEW_BUFFER_MSG
		  MEXTCMD
		  new_buffer_msg nano_multibuffer_msg #f NOVIEW)
    (add_to_funcs REFRESH_MSG
		  MHELP
		  refresh_msg nano_refresh_msg #f VIEW)

    (add_to_funcs DO_EXIT
		  MHELP
		  exit_msg nano_exit_msg #f VIEW)
    (add_to_funcs FIRST_FILE_MSG
		  (logior MBROWSER MWHEREISFILE)
		  first_file_msg nano_firstfile_msg #f VIEW)

    (add_to_funcs LAST_FILE_MSG
		  (logior MBROWSER MWHEREISFILE)
		  last_file_msg nano_lastfile_msg #f VIEW)

    (add_to_funcs GOTO_DIR_MSG
		  MBROWSER
		  goto_dir_msg nano_gotodir_msg #f VIEW)

    (set! currmenu MMAIN)

    (add_to_sclist (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE
			   MWRITEFILE MINSERTFILE MEXTCMD MSPELL MBROWSER
			   MWHEREISFILE MGOTODIR)
		   "^G" DO_HELP_VOID 0 #t)
    (add_to_sclist (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE
			   MWRITEFILE MINSERTFILE MEXTCMD MSPELL MBROWSER
			   MWHEREISFILE MGOTODIR)
		   "F1" DO_HELP_VOID 0 #t)
    (add_to_sclist (logior MMAIN MHELP MBROWSER)
		   "^X" DO_EXIT 0 #t)
    (add_to_sclist (logior MMAIN MHELP MBROWSER)
		   "F2" DO_EXIT 0 #t)
    (add_to_sclist MMAIN "^_" DO_GOTOLINECOLUMN_VOID 0 #t)
    (add_to_sclist MMAIN "F13" DO_GOTOLINECOLUMN_VOID 0 #t)
    (add_to_sclist MMAIN "M-G" DO_GOTOLINECOLUMN_VOID 0 #t)
    (add_to_sclist MMAIN "^O" DO_WRITEOUT_VOID 0 #t)
    (add_to_sclist MMAIN "F3" DO_WRITEOUT_VOID 0 #t)
    (add_to_sclist MMAIN "^J" DO_JUSTIFY_VOID 0 #t)
    (add_to_sclist MMAIN "F4" DO_JUSTIFY_VOID 0 #t)
    (add_to_sclist MMAIN "^R" DO_INSERTFILE_VOID 0 #t)
    (add_to_sclist MMAIN "F5" DO_INSERTFILE_VOID 0 #t)
    (add_to_sclist MMAIN "kinsert" DO_INSERTFILE_VOID 0 #t)
    (add_to_sclist (logior MMAIN MBROWSER)
		   "^W" DO_SEARCH 0 #t)
    (add_to_sclist (logior MMAIN MBROWSER)
		   "F6" DO_SEARCH 0 #t)
    (add_to_sclist (logior MMAIN MBROWSER MHELP MWHEREISFILE)
		   "^Y" DO_PAGE_UP 0 #t)
    (add_to_sclist (logior MMAIN MBROWSER MHELP MWHEREISFILE)
		   "F7" DO_PAGE_UP 0 #t)
    (add_to_sclist (logior MMAIN MBROWSER MHELP MWHEREISFILE)
		   "kpup" DO_PAGE_UP 0 #t)
    (add_to_sclist (logior MMAIN MBROWSER MHELP MWHEREISFILE)
		   "^V" DO_PAGE_DOWN 0 #t)
    (add_to_sclist (logior MMAIN MBROWSER MHELP MWHEREISFILE)
		   "F8" DO_PAGE_DOWN 0 #t)
    (add_to_sclist (logior MMAIN MBROWSER MHELP MWHEREISFILE)
		   "kpdown" DO_PAGE_DOWN 0 #t)
    (add_to_sclist MMAIN "^K" DO_CUT_TEXT_VOID 0 #t)
    (add_to_sclist MMAIN "F9" DO_CUT_TEXT_VOID 0 #t)
    (add_to_sclist MMAIN "^U" DO_UNCUT_TEXT 0 #t)
    (add_to_sclist MMAIN "F10" DO_UNCUT_TEXT 0 #t)
    (add_to_sclist MMAIN "^C" DO_CURSORPOS_VOID 0 #t)
    (add_to_sclist MMAIN "F11" DO_CURSORPOS_VOID 0 #t)
    (add_to_sclist MMAIN "^T" DO_SPELL 0 #t)
    (add_to_sclist MMAIN "F12" DO_SPELL 0 #t)
    (add_to_sclist MMAIN "^\\" DO_REPLACE 0 #t)
    (add_to_sclist MMAIN "F14" DO_REPLACE 0 #t)
    (add_to_sclist MMAIN "M-R" DO_REPLACE 0 #t)
    (add_to_sclist MWHEREIS "^R" DO_REPLACE 0 #f)
    (add_to_sclist MREPLACE "^R" NO_REPLACE_MSG 0 #f)
    (add_to_sclist MWHEREIS "^T" DO_GOTOLINECOLUMN_VOID 0 #f)
    (add_to_sclist MMAIN "^^" DO_MARK 0 #t)
    (add_to_sclist MMAIN "F15" DO_MARK 0 #t)
    (add_to_sclist MMAIN "M-A" DO_MARK 0 #t)
    (add_to_sclist (logior MMAIN MBROWSER) "M-W" DO_RESEARCH 0 #t)
    (add_to_sclist (logior MMAIN MBROWSER) "F16" DO_RESEARCH 0 #t)
    (add_to_sclist MMAIN "M-^" DO_COPY_TEXT 0 #t)
    (add_to_sclist MMAIN "M-6" DO_COPY_TEXT 0 #t)
    (add_to_sclist MMAIN "M-\x7D" DO_INDENT_VOID 0 #t)
    (add_to_sclist MMAIN "M-\x7B" DO_UNINDENT 0 #t)
    (when (ISSET UNDOABLE)
      (add_to_sclist MMAIN "M-U" DO_UNDO 0 #t)
      (add_to_sclist MMAIN "M-E" DO_REDO 0 #t))
    (add_to_sclist MALL "^F" DO_RIGHT 0 #t)
    (add_to_sclist MALL "^B" DO_LEFT 0 #t)
    (add_to_sclist MMAIN "^Space" DO_NEXT_WORD_VOID 0 #t)
    (add_to_sclist MMAIN "M-Space" DO_PREV_WORD_VOID 0 #t)
    (add_to_sclist MALL "kright" DO_RIGHT 0 #t)
    (add_to_sclist MALL "kleft" DO_LEFT 0 #t)
    (add_to_sclist MMAIN "^Q" XON_COMPLAINT 0 #t)
    (add_to_sclist MMAIN "^S" XOFF_COMPLAINT 0 #t)
    (add_to_sclist (logior MMAIN MHELP MBROWSER) "^P" DO_UP_VOID 0 #t)
    (add_to_sclist (logior MMAIN MHELP MBROWSER) "kup" DO_UP_VOID 0 #t)
    (add_to_sclist (logior MMAIN MHELP MBROWSER) "^N" DO_DOWN_VOID 0 #t)
    (add_to_sclist (logior MMAIN MHELP MBROWSER) "kdown" DO_DOWN_VOID 0 #t)
    (add_to_sclist MALL "^A" DO_HOME 0 #t)
    (add_to_sclist MALL "khome" DO_HOME 0 #t)
    (add_to_sclist MALL "^E" DO_END 0 #t)
    (add_to_sclist MALL "kend" DO_END 0 #t)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
		   "^P"  PREV_HISTORY_MSG 0 #f)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
		   "kup"  PREV_HISTORY_MSG 0 #f)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
		   "^N"  NEXT_HISTORY_MSG 0 #f)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
		   "kdown"  NEXT_HISTORY_MSG 0 #f)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2)
		   "^W" DO_PARA_BEGIN_VOID 0 #t)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2)
		   "^O" DO_PARA_END_VOID 0 #t)
    (add_to_sclist MALL "M-(" DO_PARA_BEGIN_VOID 0 #t)
    (add_to_sclist MALL "M-9" DO_PARA_BEGIN_VOID 0 #t)
    (add_to_sclist MALL "M-)" DO_PARA_END_VOID 0 #t)
    (add_to_sclist MALL "M-0" DO_PARA_END_VOID 0 #t)
    (add_to_sclist MWHEREIS "M-C" CASE_SENS_MSG 0 #f)
    (add_to_sclist MREPLACE "M-C" CASE_SENS_MSG 0 #f)
    (add_to_sclist MREPLACE2 "M-C" CASE_SENS_MSG 0 #f)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2)
		   "M-B" BACKWARDS_MSG 0 #f)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2)
		   "M-R" REGEXP_MSG 0 #f)

    (add_to_sclist MMAIN "M-\\" DO_FIRST_LINE 0 #t)
    (add_to_sclist MMAIN "M- " DO_FIRST_LINE 0 #t)
    (add_to_sclist MMAIN "M-/" DO_LAST_LINE 0 #t)
    (add_to_sclist MMAIN "M-?" DO_LAST_LINE 0 #t)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MHELP)
		   "^Y" DO_FIRST_LINE 0 #t)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MHELP)
		   "^V" DO_LAST_LINE 0 #t)

    (add_to_sclist (logior MBROWSER MWHEREISFILE) "M-\\"  FIRST_FILE_MSG 0 #t)
    (add_to_sclist (logior MBROWSER MWHEREISFILE) "M- "  FIRST_FILE_MSG 0 #t)
    (add_to_sclist (logior MBROWSER MWHEREISFILE) "M-/"  LAST_FILE_MSG 0 #t)
    (add_to_sclist (logior MBROWSER MWHEREISFILE) "M-?"  LAST_FILE_MSG 0 #t)
    (add_to_sclist (logior MBROWSER MWHEREISFILE) "^_"  GOTO_DIR_MSG 0 #t)
    (add_to_sclist (logior MBROWSER MWHEREISFILE) "F13"  GOTO_DIR_MSG 0 #t)
    (add_to_sclist (logior MBROWSER MWHEREISFILE) "M-G"  GOTO_DIR_MSG 0 #t)
    (add_to_sclist MMAIN "M-]" DO_FIND_BRACKET 0 #t)
    (add_to_sclist MMAIN "M--" DO_SCROLL_UP 0 #t)
    (add_to_sclist MMAIN "M-_" DO_SCROLL_UP 0 #t)
    (add_to_sclist MMAIN "M-+" DO_SCROLL_DOWN 0 #t)
    (add_to_sclist MMAIN "M-=" DO_SCROLL_DOWN 0 #t)
    (add_to_sclist MMAIN "M-<" SWITCH_TO_PREV_BUFFER_VOID 0 #t)
    (add_to_sclist MMAIN "M-," SWITCH_TO_PREV_BUFFER_VOID 0 #t)
    (add_to_sclist MMAIN "M->" SWITCH_TO_NEXT_BUFFER_VOID 0 #t)
    (add_to_sclist MMAIN "M-." SWITCH_TO_NEXT_BUFFER_VOID 0 #t)
    (add_to_sclist MALL "M-V" DO_VERBATIM_INPUT 0 #t)
    (add_to_sclist MALL "M-T" DO_CUT_TILL_END 0 #t)
    (add_to_sclist MALL "M-J" DO_FULL_JUSTIFY 0 #t)
    (add_to_sclist MMAIN "M-D" DO_WORDLINECHAR_COUNT 0 #t)
    (add_to_sclist MMAIN "M-X" DO_TOGGLE NO_HELP #t)
    (add_to_sclist MMAIN "M-C" DO_TOGGLE CONST_UPDATE #t)
    (add_to_sclist MMAIN "M-O" DO_TOGGLE MORE_SPACE #t)
    (add_to_sclist MMAIN "M-S" DO_TOGGLE SMOOTH_SCROLL #t)
    (add_to_sclist MMAIN "M-P" DO_TOGGLE WHITESPACE_DISPLAY #t)
    (add_to_sclist MMAIN "M-Y" DO_TOGGLE NO_COLOR_SYNTAX #t)
    (add_to_sclist MMAIN "M-H" DO_TOGGLE SMART_HOME #t)
    (add_to_sclist MMAIN "M-I" DO_TOGGLE AUTOINDENT #t)
    (add_to_sclist MMAIN "M-K" DO_TOGGLE CUT_TO_END #t)
    (add_to_sclist MMAIN "M-L" DO_TOGGLE NO_WRAP #t)
    (add_to_sclist MMAIN "M-Q" DO_TOGGLE TABS_TO_SPACES #t)
    (add_to_sclist MMAIN "M-B" DO_TOGGLE BACKUP_FILE #t)
    (add_to_sclist MMAIN "M-F" DO_TOGGLE MULTIBUFFER #t)
    (add_to_sclist MMAIN "M-M" DO_TOGGLE USE_MOUSE #t)
    (add_to_sclist MMAIN "M-N" DO_TOGGLE NO_CONVERT #t)
    (add_to_sclist MMAIN "M-Z" DO_TOGGLE SUSPEND #t)
    (add_to_sclist MMAIN "M-$" DO_TOGGLE SOFTWRAP #t)
    (add_to_sclist MGOTOLINE "^T"  GOTOTEXT_MSG 0 #f)
    (add_to_sclist (logior MINSERTFILE MEXTCMD)
		   "M-F"  NEW_BUFFER_MSG 0 #f)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MWRITEFILE
			   MINSERTFILE MEXTCMD MSPELL MWHEREISFILE MGOTODIR
			   MYESNO)
		   "^C" CANCEL_MSG 0 #f)
    (add_to_sclist MHELP "^X" DO_EXIT 0 #t)
    (add_to_sclist MHELP "F2" DO_EXIT 0 #t)
    (add_to_sclist MWRITEFILE "M-D"  DOS_FORMAT_MSG 0 #f)
    (add_to_sclist MWRITEFILE "M-M"  MAC_FORMAT_MSG 0 #f)
    (add_to_sclist MWRITEFILE "M-A"  APPEND_MSG 0 #f)
    (add_to_sclist MWRITEFILE "M-P"  PREPEND_MSG 0 #f)
    (add_to_sclist MWRITEFILE "M-B"  BACKUP_FILE_MSG 0 #f)
    (add_to_sclist MWRITEFILE "^T"  TO_FILES_MSG 0 #f)
    (add_to_sclist MINSERTFILE "^T"  TO_FILES_MSG 0 #f)
    (add_to_sclist MINSERTFILE "^X"  EXT_CMD_MSG 0 #f)
    (add_to_sclist MMAIN "^Z" DO_SUSPEND_VOID 0 #f)
    (add_to_sclist MMAIN "^L" TOTAL_REFRESH 0 #t)
    (add_to_sclist MALL "^I" DO_TAB 0 #t)
    (add_to_sclist MALL "^M" DO_ENTER 0 #t)
    (add_to_sclist MALL "kenter" DO_ENTER 0 #t)
    (add_to_sclist MALL "^D" DO_DELETE 0 #t)
    (add_to_sclist MALL "kdel" DO_DELETE 0 #t)
    (add_to_sclist MALL "^H" DO_BACKSPACE 0 #t)
    (add_to_sclist MALL "kbsp" DO_BACKSPACE 0 #t)

    (print_sclist)))

(define (sctofunc s)
  (if (list? allfuncs)
      (find (lambda (f)
	      (eq? (subnfunc-scfunc f) (sc-scfunc s)))
	    allfuncs)
      #f))

;; This is the main dispatch
(define (iso_me_harder_funcmap func)
  (error "implement me!?"))