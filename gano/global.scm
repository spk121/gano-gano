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
  #:use-module (oop goops)
  #:use-module (gano CFunction)
  #:use-module (gano CShortcut)
  #:use-module (gano flags)
  #:use-module (gano nano-h)
  #:use-module (gano text)
  #:use-module (ncurses curses)
  #:use-module (rnrs control)
  #:use-module (srfi srfi-1)
  #:export (
            vDirOperating
	    vrgSearchHistory
	    syntaxes
	    viSearchHistory
	    vrgReplaceHistory
            viReplaceHistory
	    vDirHome
            PrintScList
            vPunct
            vBrackets
            vWhiteSpace
            vWhiteSpaceLen
	    GetFunctionFromShortcut
            vQuoteStr
            vQuoteReg
            quoteerr
            quotelen
            regcomp
            vDirBackup
            vSpellerAlt
            vSyntaxStr
            jump_buf
            jump_buf_main
            viColFill
            viColWrap
            FindFirstShortcut
            last_search
            last_replace
            vTabSize
            vWinMain
            vWinTop
            vWinEdit
            vWinBottom
            editwinrows
            InitShortcuts
            vAttrReverse
            CountEntriesInMenu
            vrgFunctions
            maxrows
            vMenuCur
            vrgShortcuts
            vfEditRefresh
	    vMatchBrackets
            GetFuncIdNameFromFuncId
	    iso_me_harder_funcmap
            ))

;; Used to return to either main or the unjustify routing
;; in do justify after a SIGWINCH
(define jump_buf #f)
;; Have we set jump_buf so that we return to main after
;; a SIGWINCH?
(define jump_buf_main #f)

;; The columns at which we will wrap lines.
(define viColFill 0)
;; The position where we will wrap lines.  fill is equal to this if
;; it's greater than zero, and equal to (COLS + this) if it isn't.

;; FIXME: In C, this uses CHARS_FROM_EOL which is a #define
(define viColWrap -8)

;; The last string we searched for
(define last_search #f)
;; The last replacement string we searched for
(define last_replace #f)

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

;; The buffer where we store cut text
(define cutbuffer #f)
(define cutbottom #f)
;; The buffer where we store unjustified text
(define jusbuffer #f)
;; The partition where we store a portion of the current file
(define filepart #f)


;; The opening and closing brackets that can be found by bracket
;; searches
(define vMatchBrackets #f)

;; The characters used when display the first characters of tabs
;; and spaces
(define vWhiteSpace #f)
;; The length of these characters
(define vWhiteSpaceLen '(0 0))

;; The closing punctuation that can end sentences
(define vPunct #f)
;; The closing brackets that can follow closing punctuation and
;; can end sentences
(define vBrackets #f)
;; The quoting string
(define vQuoteStr #f)
;; The compiled regular expression from the quoting string
(define vQuoteReg #f)
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
(define vTabSize -1)

;; The directory where we store backup files
(define vDirBackup #f)
;; The relative path to the operating directory, which
;; we can't move outside of
(define vDirOperating #f)
;; The full path
(define full_operating_dir #f)

;; The command to use for the alternate spell checker
(define vSpellerAlt #f)

;; The global list of color syntaxes
(define syntaxes #f)
;; The color syntax name specified on the command line
(define vSyntaxStr #f)

;; Did a command mangle enough of the buffer refresh that we should
;; repaing the screen
(define vfEditRefresh #f)

;; The current shortcut list we're using
(define currshortcut #f)
;; The currently loaded menu
(define fMenuCur #f)

;; The shortcut key struct: a list of sc's
(define vrgShortcuts '())

;; The main function list: a list of subnfunc's
(define vrgFunctions '())

;; The search string history list
(define vrgSearchHistory #f)
;; The top of the search string history list
(define viSearchHistory #f)
;; The bottom of the search string history list
;;(define searchbot #f)
;; The replace string history list
(define vrgReplaceHistory #f)
;; Top of the replace string history list
(define viReplaceHistory #f)
;; Bottom of the replace string history list
;;(define replacebot #f)

;; The compiled regular expressionto use in searches
(define search_regexp #f)
;; The match positions for parenthetical subexpressions,
;; 10 maximum, used in regular expression searches
(define regmatches #f)

;; The curses attribute for reverse video
(define vAttrReverse A_REVERSE)

;; The user's home directory: from $HOME or /etc/passwd
(define vDirHome #f)

;; Return the number of entries in the shortcut list S for
;; a given menu
(define (CountEntriesInMenu menu)
  (count (lambda (fn)
           (logtest (GetFunctionMenus fn) menu))
         vrgFunctions))

;; Add information about an external function
(define (AddFunction func menus description help fBlankAfter fViewOk)
  (let ([fn (CreateFunction func menus description help fBlankAfter fViewOk)])
    (set! vrgFunctions (append! vrgFunctions (list fn)))
    (format (current-error-port) "Added func \"~a\"" description)))

(define (FindFirstShortcut menu funcId)
  (let ([nonMetaSc (find (lambda (sc)
                           (and (DoesShortcutMatchMenuAndFuncId? sc menu funcId)
                                (not (DoesShortcutUseMetaKey? sc))))
                         vrgShortcuts)]
        [metaSc (find (lambda (sc)
                           (and (DoesShortcutMatchMenuAndFuncId? sc menu funcId)
                                (DoesShortcutUseMetaKey? sc)))
                         vrgShortcuts)])
    (or nonMetaSc
        metaSc)))

;; Add a string to the new shortcut list implementation.
(define (AddShortcut menu keyStr funcId toggleId fExecute)
  ;; (format (current-error-port) "AddShortcut shortcut_list ~s~%" vrgShortcuts)

  (let* ([sc (CreateShortcut menu keyStr funcId toggleId fExecute)]
         [matchingSc (find (lambda (sc)
                             (DoesShortcutMatchMenuAndFuncId? sc menu funcId))
                           vrgShortcuts)])
    (format (current-error-port)
            "AddShortcut menu ~s keyStr ~s funcId ~s toggleId ~s fExecute ~s~%"
            menu keyStr (GetFuncIdNameFromFuncId funcId) toggleId fExecute)
    (format (current-error-port)
            "AddShortcut meta ~s key ~s~%" (DoesShortcutUseMetaKey? sc)
            (keyname (GetShortcutKey sc)))
    (when matchingSc
      (format (current-error-port) "~s is duplicate shortcut ~s on menu ~s and function ~s~%"
              (GetShortcutKeyStr matchingSc) keyStr menu funcId))

    (set! vrgShortcuts (append! vrgShortcuts (list sc)))))

(define (PrintScList)
  (for-each (lambda (s)
              (let ([f (GetFunctionFromShortcut s)])
                (if f
                    (format (current-error-port)
                            "Shortcut \"~a\", function: ~a, menus ~a\n"
                            (GetShortcutKeyStr s) (GetFunctionDesc f) (GetFunctionMenus f))
                    (format (current-error-port)
                            "Hmm, didnt find a func for \"~a\"\n" (GetShortcutKeyStr s)))))
            vrgShortcuts))

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

(define (InitShortcuts fUnjustify)
  "Initialize all shortcut lists.  If unjustify is #t, replace the
the \"Uncut\" key with the \"Unjustify\" command"
  (let ([getHelpMsg (N_ "Get Help")]
        [exitMsg (N_ "Exit")]
        [whereisMsg (N_ "Where Is")]
        [prevPageMsg (N_ "Prev Page")]
        [nextPageMsg (N_ "Next Page")]
        [firstLineMsg (N_ "First Line")]
        [lastLineMsg (N_ "Last Line")]
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
    (set! vrgFunctions '())
    (gc)

    (AddFunction DO_HELP_VOID
                  (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE
                          MWRITEFILE MINSERTFILE MEXTCMD MSPELL MBROWSER
                          MWHEREISFILE MGOTODIR)
                  getHelpMsg nano_help_msg #f VIEW)

    (AddFunction CANCEL_MSG
                  (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MWRITEFILE
                          MINSERTFILE MEXTCMD MSPELL MWHEREISFILE MGOTODIR
                          MYESNO)
                  cancel_msg nano_cancel_msg #f VIEW)

    (AddFunction DO_EXIT
                  MMAIN "Close" nano_exit_msg #f VIEW)

    (AddFunction DO_EXIT
		  MBROWSER
		  exitMsg nano_exitbrowser_msg #f VIEW)

    ;; TRANSLATORS: Try to keep this at most 10 characters.
    (AddFunction DO_WRITEOUT_VOID
		  MMAIN
		  (N_ "WriteOut") nano_writeout_msg #f NOVIEW)

    ;; TRANSLATORS: Try to keep this at most 10 characters.
    (AddFunction DO_JUSTIFY_VOID
		  MMAIN
		  (N_ "Justify") nano_justify_msg #t NOVIEW)

    ;; We allow inserting files in view mode if multibuffers are
    ;; available, so that we can view multiple files.  If we're using
    ;; restricted mode, inserting files is disabled, since it allows
    ;; reading from or writing to files not specified on the command
    ;; line.
    (AddFunction (if (ISSET RESTRICTED) NANO_DISABLED_MSG DO_INSERTFILE_VOID)
		  MMAIN
		  (N_ "Read File") nano_insert_msg #f VIEW)

    (AddFunction DO_SEARCH
		  (logior MMAIN MBROWSER)
		  whereisMsg nano_whereis_msg #f VIEW)
    (AddFunction DO_PAGE_UP
		  (logior MMAIN MHELP MBROWSER)
		  prevPageMsg nano_prevpage_msg #f VIEW)
    (AddFunction DO_PAGE_DOWN
		  (logior MMAIN MHELP MBROWSER)
		  nextPageMsg nano_nextpage_msg #t VIEW)

    ;; TRANSLATORS: Try to keep this at most 10 characters.
    (AddFunction DO_CUT_TEXT_VOID
		  MMAIN
		  (N_ "Cut Text") nano_cut_msg #f NOVIEW)
    (if fUnjustify
	;; TRANSLATORS: Try to keep this at most 10 characters.
	(AddFunction DO_UNCUT_TEXT
		      MMAIN (N_ "UnJustify") "" #f NOVIEW)
	;; else
	(AddFunction DO_UNCUT_TEXT
		      MMAIN (N_ "UnCut Text") nano_uncut_msg
		      #f  NOVIEW))

    ;; TRANSLATORS: Try to keep this at most 10 characters.
    (AddFunction DO_CURSORPOS_VOID
		  MMAIN
		  (N_ "Cur Pos") nano_cursorpos_msg #f VIEW)

    ;; If we're using restricted mode, spell checking is disabled
    ;; because it allows reading from or writing to files not specified
    ;; on the command line.
    (if (not (ISSET RESTRICTED))
	;; TRANSLATORS: Try to keep this at most 10 characters.
	(AddFunction DO_SPELL
		      MMAIN
		      (N_ "To Spell") nano_spell_msg #t NOVIEW))

    (AddFunction DO_FIRST_LINE
		  (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE)
		  firstLineMsg nano_firstline_msg #f VIEW)

    (AddFunction DO_LAST_LINE
		  (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE)
		  lastLineMsg nano_lastline_msg #t VIEW)

    (AddFunction DO_GOTOLINECOLUMN_VOID
		  (logior MMAIN MWHEREIS)
		  go_to_line_msg nano_gotoline_msg #f VIEW)

    (AddFunction DO_REPLACE
		  (logior MMAIN MWHEREIS)
		  replace_msg nano_replace_msg #f NOVIEW)

    (AddFunction DO_MARK MMAIN (N_ "Mark Text") nano_mark_msg #f VIEW)
    (AddFunction DO_RESEARCH (logior MMAIN MBROWSER) whereis_next_msg
		  nano_whereis_next_msg #t VIEW)
    (AddFunction DO_COPY_TEXT MMAIN (N_ "Copy Text") nano_copy_msg #f NOVIEW)
    (AddFunction DO_INDENT_VOID MMAIN (N_ "Indent Text") nano_indent_msg #f NOVIEW)
    (AddFunction DO_UNINDENT MMAIN (N_ "Unindent Text") nano_unindent_msg #f NOVIEW)

    (when (ISSET UNDOABLE)
      (AddFunction DO_UNDO MMAIN (N_ "Undo") nano_undo_msg #f NOVIEW)
      (AddFunction DO_REDO MMAIN (N_ "Redo") nano_redo_msg #t NOVIEW))

    (AddFunction DO_RIGHT MMAIN (N_ "Forward") nano_forward_msg #f VIEW)
    (AddFunction DO_RIGHT MBROWSER (N_ "Forward") nano_forwardfile_msg #f VIEW)
    (AddFunction DO_RIGHT MALL "" "" #f VIEW)
    (AddFunction DO_LEFT MMAIN (N_ "Back") nano_back_msg #f VIEW)
    (AddFunction DO_LEFT MBROWSER (N_ "Back") nano_backfile_msg #f VIEW)
    (AddFunction DO_LEFT MALL "" "" FALSE VIEW)
    (AddFunction DO_NEXT_WORD_VOID MMAIN (N_ "Next Word") nano_nextword_msg #f VIEW)
    (AddFunction DO_PREV_WORD_VOID MMAIN (N_ "Prev Word") nano_prevword_msg #f VIEW)
    (AddFunction DO_UP_VOID (logior MMAIN MHELP MBROWSER)
		  (N_ "Prev Line") nano_prevline_msg #f VIEW)
    (AddFunction DO_DOWN_VOID (logior MMAIN MHELP MBROWSER)
		  (N_ "Next Line") nano_nextline_msg #t VIEW)
    (AddFunction DO_HOME MMAIN (N_ "Home") nano_home_msg #f VIEW)
    (AddFunction DO_END MMAIN (N_ "End") nano_end_msg #f VIEW)
    (AddFunction DO_PARA_BEGIN_VOID (logior MMAIN MWHEREIS)
		  beg_of_par_msg nano_parabegin_msg #f VIEW)
    (AddFunction DO_PARA_END_VOID (logior MMAIN MWHEREIS)
		  end_of_par_msg nano_paraend_msg #f VIEW)
    (AddFunction DO_FIND_BRACKET MMAIN (_ "Find Other Bracket") nano_bracket_msg #f VIEW)
    (AddFunction DO_SCROLL_UP
		  MMAIN
		  (N_ "Scroll Up") nano_scrollup_msg #f VIEW)

    (AddFunction DO_SCROLL_DOWN
		  MMAIN
		  (N_ "Scroll Down") nano_scrolldown_msg #f VIEW)
    (AddFunction SWITCH_TO_PREV_BUFFER_VOID
		  MMAIN
		  (_ "Previous File") nano_prevfile_msg #f VIEW)
    (AddFunction SWITCH_TO_NEXT_BUFFER_VOID
		  MMAIN
		  (N_ "Next File") nano_nextfile_msg #t VIEW)
    (AddFunction DO_VERBATIM_INPUT
		  MMAIN
		  (N_ "Verbatim Input") nano_verbatim_msg #f
		  NOVIEW)
    (AddFunction DO_VERBATIM_INPUT
		  (logior MWHEREIS MREPLACE MREPLACE2 MEXTCMD MSPELL)
		  ""  ""  #f  NOVIEW)
    (AddFunction DO_TAB
		  MMAIN
		  (N_ "Tab") nano_tab_msg #f NOVIEW)
    (AddFunction DO_TAB
		  MALL
		  ""  ""  #f  NOVIEW)
    (AddFunction DO_ENTER
		  MMAIN
		  (N_ "Enter") nano_enter_msg #f  NOVIEW)
    (AddFunction DO_ENTER
		  MALL
		  ""  ""  #f  NOVIEW)
    (AddFunction DO_DELETE
		  MMAIN
		  (N_ "Delete") nano_delete_msg #f NOVIEW)
    (AddFunction DO_DELETE
		  MALL
		  ""  ""  #f  NOVIEW)
    (AddFunction DO_BACKSPACE
		  MMAIN
		  (N_ "Backspace") nano_backspace_msg #t NOVIEW)
    (AddFunction DO_BACKSPACE
		  MALL
		  ""  ""
		  #t NOVIEW)

    (AddFunction DO_CUT_TILL_END
		  MMAIN
		  (N_ "CutTillEnd") nano_cut_till_end_msg #t
		  NOVIEW)
    (AddFunction XON_COMPLAINT
		  MMAIN
		  ""  ""  #f  VIEW);
    (AddFunction XOFF_COMPLAINT
		  MMAIN
		  ""  ""  #f  VIEW);

    (AddFunction DO_FULL_JUSTIFY
		  (logior MMAIN MWHEREIS)
		  (N_ "Justify") nano_fulljustify_msg #f NOVIEW)
    (AddFunction DO_WORDLINECHAR_COUNT
		  MMAIN
		  (N_ "Word Count") nano_wordcount_msg #f VIEW)
    (AddFunction TOTAL_REFRESH
		  (logior MMAIN MHELP)
		  refresh_msg nano_refresh_msg #f VIEW)

    (AddFunction DO_SUSPEND_VOID
		  MMAIN
		  suspend_msg nano_suspend_msg #t VIEW)
    (AddFunction CASE_SENS_MSG
		  (logior MWHEREIS MREPLACE MWHEREISFILE)
		  case_sens_msg nano_case_msg #f VIEW)

    (AddFunction BACKWARDS_MSG
		  (logior MWHEREIS MREPLACE MWHEREISFILE)
		  backwards_msg nano_reverse_msg #f VIEW)
    (AddFunction REGEXP_MSG
		  (logior MWHEREIS MREPLACE MWHEREISFILE)
		  regexp_msg nano_regexp_msg #f VIEW)
    (AddFunction PREV_HISTORY_MSG
		  (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
		  prev_history_msg nano_prev_history_msg #f VIEW)
    (AddFunction NEXT_HISTORY_MSG
		  (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
		  next_history_msg nano_next_history_msg #f VIEW)
    (AddFunction NO_REPLACE_MSG
		  MREPLACE
		  no_replace_msg nano_whereis_msg #f VIEW)

    (AddFunction GOTOTEXT_MSG
		  MGOTOLINE
		  gototext_msg nano_whereis_msg #t VIEW)
    (if (not (ISSET RESTRICTED))
	(AddFunction TO_FILES_MSG
		      (logior MGOTOLINE MINSERTFILE)
		      to_files_msg nano_tofiles_msg #f VIEW))

    ;; If we're using restricted mode, the DOS format, Mac format,
    ;; append, prepend, and backup toggles are disabled.  The first and
    ;; second are useless since inserting files is disabled, the third
    ;; and fourth are disabled because they allow writing to files not
    ;; specified on the command line, and the fifth is useless since
    ;; backups are disabled.
    (unless (ISSET RESTRICTED)
      (AddFunction DOS_FORMAT_MSG
		    MWRITEFILE
		    dos_format_msg nano_dos_msg #f NOVIEW)
      (AddFunction MAC_FORMAT_MSG
		    MWRITEFILE
		    mac_format_msg nano_mac_msg #f  NOVIEW)
      (AddFunction APPEND_MSG
		    MWRITEFILE
		    append_msg nano_append_msg #f NOVIEW)
      (AddFunction PREPEND_MSG
		    MWRITEFILE
		    prepend_msg nano_prepend_msg #f NOVIEW)
      (AddFunction BACKUP_FILE_MSG MWRITEFILE
		    backup_file_msg nano_backup_msg #f
		    NOVIEW))

    ;; If we're using restricted mode, command execution is disabled.
    ;; It's useless since inserting files is disabled.
    (if (not (ISSET RESTRICTED))
	(AddFunction EXT_CMD_MSG
		      MINSERTFILE
		      ext_cmd_msg nano_execute_msg #f NOVIEW))

    ;; If we're using restricted mode  the multibuffer toggle is
    ;; disabled.  It's useless since inserting files is disabled.
    (if (not (ISSET RESTRICTED))
	(AddFunction NEW_BUFFER_MSG
		      MINSERTFILE
		      new_buffer_msg nano_multibuffer_msg #f
		      NOVIEW))
    (AddFunction  INSERT_FILE_MSG
		   MEXTCMD
		   insert_file_msg nano_insert_msg #f VIEW)

    (AddFunction NEW_BUFFER_MSG
		  MEXTCMD
		  new_buffer_msg nano_multibuffer_msg #f NOVIEW)
    (AddFunction REFRESH_MSG
		  MHELP
		  refresh_msg nano_refresh_msg #f VIEW)

    (AddFunction DO_EXIT
		  MHELP
		  exitMsg nano_exit_msg #f VIEW)
    (AddFunction FIRST_FILE_MSG
		  (logior MBROWSER MWHEREISFILE)
		  first_file_msg nano_firstfile_msg #f VIEW)

    (AddFunction LAST_FILE_MSG
		  (logior MBROWSER MWHEREISFILE)
		  last_file_msg nano_lastfile_msg #f VIEW)

    (AddFunction GOTO_DIR_MSG
		  MBROWSER
		  goto_dir_msg nano_gotodir_msg #f VIEW)

    (set! vMenuCur MMAIN)

    (AddShortcut (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE
			   MWRITEFILE MINSERTFILE MEXTCMD MSPELL MBROWSER
			   MWHEREISFILE MGOTODIR)
		   "^G" DO_HELP_VOID 0 #t)
    (AddShortcut (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE
			   MWRITEFILE MINSERTFILE MEXTCMD MSPELL MBROWSER
			   MWHEREISFILE MGOTODIR)
		   "F1" DO_HELP_VOID 0 #t)
    (AddShortcut (logior MMAIN MHELP MBROWSER)
		   "^X" DO_EXIT 0 #t)
    (AddShortcut (logior MMAIN MHELP MBROWSER)
		   "F2" DO_EXIT 0 #t)
    (AddShortcut MMAIN "^_" DO_GOTOLINECOLUMN_VOID 0 #t)
    (AddShortcut MMAIN "F13" DO_GOTOLINECOLUMN_VOID 0 #t)
    (AddShortcut MMAIN "M-G" DO_GOTOLINECOLUMN_VOID 0 #t)
    (AddShortcut MMAIN "^O" DO_WRITEOUT_VOID 0 #t)
    (AddShortcut MMAIN "F3" DO_WRITEOUT_VOID 0 #t)
    ;; (AddShortcut MMAIN "^J" DO_JUSTIFY_VOID 0 #t)
    (AddShortcut MMAIN "F4" DO_JUSTIFY_VOID 0 #t)
    (AddShortcut MMAIN "^R" DO_INSERTFILE_VOID 0 #t)
    (AddShortcut MMAIN "F5" DO_INSERTFILE_VOID 0 #t)
    (AddShortcut MMAIN "kinsert" DO_INSERTFILE_VOID 0 #t)
    (AddShortcut (logior MMAIN MBROWSER)
		   "^W" DO_SEARCH 0 #t)
    (AddShortcut (logior MMAIN MBROWSER)
		   "F6" DO_SEARCH 0 #t)
    (AddShortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE)
		   "^Y" DO_PAGE_UP 0 #t)
    (AddShortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE)
		   "F7" DO_PAGE_UP 0 #t)
    (AddShortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE)
		   "kpup" DO_PAGE_UP 0 #t)
    (AddShortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE)
		   "^V" DO_PAGE_DOWN 0 #t)
    (AddShortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE)
		   "F8" DO_PAGE_DOWN 0 #t)
    (AddShortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE)
		   "kpdown" DO_PAGE_DOWN 0 #t)
    (AddShortcut MMAIN "^K" DO_CUT_TEXT_VOID 0 #t)
    (AddShortcut MMAIN "F9" DO_CUT_TEXT_VOID 0 #t)
    (AddShortcut MMAIN "^U" DO_UNCUT_TEXT 0 #t)
    (AddShortcut MMAIN "F10" DO_UNCUT_TEXT 0 #t)
    (AddShortcut MMAIN "^C" DO_CURSORPOS_VOID 0 #t)
    (AddShortcut MMAIN "F11" DO_CURSORPOS_VOID 0 #t)
    (AddShortcut MMAIN "^T" DO_SPELL 0 #t)
    (AddShortcut MMAIN "F12" DO_SPELL 0 #t)
    (AddShortcut MMAIN "^\\" DO_REPLACE 0 #t)
    (AddShortcut MMAIN "F14" DO_REPLACE 0 #t)
    (AddShortcut MMAIN "M-R" DO_REPLACE 0 #t)
    (AddShortcut MWHEREIS "^R" DO_REPLACE 0 #f)
    (AddShortcut MREPLACE "^R" NO_REPLACE_MSG 0 #f)
    (AddShortcut MWHEREIS "^T" DO_GOTOLINECOLUMN_VOID 0 #f)
    (AddShortcut MMAIN "^^" DO_MARK 0 #t)
    (AddShortcut MMAIN "F15" DO_MARK 0 #t)
    (AddShortcut MMAIN "M-A" DO_MARK 0 #t)
    (AddShortcut (logior MMAIN MBROWSER) "M-W" DO_RESEARCH 0 #t)
    (AddShortcut (logior MMAIN MBROWSER) "F16" DO_RESEARCH 0 #t)
    (AddShortcut MMAIN "M-^" DO_COPY_TEXT 0 #t)
    (AddShortcut MMAIN "M-6" DO_COPY_TEXT 0 #t)
    (AddShortcut MMAIN "M-\x7D" DO_INDENT_VOID 0 #t)
    (AddShortcut MMAIN "M-\x7B" DO_UNINDENT 0 #t)
    (when (ISSET UNDOABLE)
      (AddShortcut MMAIN "M-U" DO_UNDO 0 #t)
      (AddShortcut MMAIN "M-E" DO_REDO 0 #t))
    (AddShortcut MALL "^F" DO_RIGHT 0 #t)
    (AddShortcut MALL "^B" DO_LEFT 0 #t)
    (AddShortcut MMAIN "^Space" DO_NEXT_WORD_VOID 0 #t)
    (AddShortcut MMAIN "M-Space" DO_PREV_WORD_VOID 0 #t)
    (AddShortcut MALL "kright" DO_RIGHT 0 #t)
    (AddShortcut MALL "kleft" DO_LEFT 0 #t)
    (AddShortcut MMAIN "^Q" XON_COMPLAINT 0 #t)
    (AddShortcut MMAIN "^S" XOFF_COMPLAINT 0 #t)
    (AddShortcut (logior MMAIN MHELP MBROWSER) "^P" DO_UP_VOID 0 #t)
    (AddShortcut (logior MMAIN MHELP MBROWSER) "kup" DO_UP_VOID 0 #t)
    (AddShortcut (logior MMAIN MHELP MBROWSER) "^N" DO_DOWN_VOID 0 #t)
    (AddShortcut (logior MMAIN MHELP MBROWSER) "kdown" DO_DOWN_VOID 0 #t)
    (AddShortcut MALL "^A" DO_HOME 0 #t)
    (AddShortcut MALL "khome" DO_HOME 0 #t)
    (AddShortcut MALL "^E" DO_END 0 #t)
    (AddShortcut MALL "kend" DO_END 0 #t)
    (AddShortcut (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
		   "^P"  PREV_HISTORY_MSG 0 #f)
    (AddShortcut (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
		   "kup"  PREV_HISTORY_MSG 0 #f)
    (AddShortcut (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
		   "^N"  NEXT_HISTORY_MSG 0 #f)
    (AddShortcut (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
		   "kdown"  NEXT_HISTORY_MSG 0 #f)
    (AddShortcut (logior MWHEREIS MREPLACE MREPLACE2)
		   "^W" DO_PARA_BEGIN_VOID 0 #t)
    (AddShortcut (logior MWHEREIS MREPLACE MREPLACE2)
		   "^O" DO_PARA_END_VOID 0 #t)
    (AddShortcut MALL "M-(" DO_PARA_BEGIN_VOID 0 #t)
    (AddShortcut MALL "M-9" DO_PARA_BEGIN_VOID 0 #t)
    (AddShortcut MALL "M-)" DO_PARA_END_VOID 0 #t)
    (AddShortcut MALL "M-0" DO_PARA_END_VOID 0 #t)
    (AddShortcut MWHEREIS "M-C" CASE_SENS_MSG 0 #f)
    (AddShortcut MREPLACE "M-C" CASE_SENS_MSG 0 #f)
    (AddShortcut MREPLACE2 "M-C" CASE_SENS_MSG 0 #f)
    (AddShortcut (logior MWHEREIS MREPLACE MREPLACE2)
		   "M-B" BACKWARDS_MSG 0 #f)
    (AddShortcut (logior MWHEREIS MREPLACE MREPLACE2)
		   "M-R" REGEXP_MSG 0 #f)

    (AddShortcut MMAIN "M-\\" DO_FIRST_LINE 0 #t)
    (AddShortcut MMAIN "M-|" DO_FIRST_LINE 0 #t)
    (AddShortcut MMAIN "M-/" DO_LAST_LINE 0 #t)
    (AddShortcut MMAIN "M-?" DO_LAST_LINE 0 #t)
    (AddShortcut (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MHELP)
		   "^Y" DO_FIRST_LINE 0 #t)
    (AddShortcut (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MHELP)
		   "^V" DO_LAST_LINE 0 #t)

    (AddShortcut (logior MBROWSER MWHEREISFILE) "M-\\"  FIRST_FILE_MSG 0 #t)
    (AddShortcut (logior MBROWSER MWHEREISFILE) "M-|"  FIRST_FILE_MSG 0 #t)
    (AddShortcut (logior MBROWSER MWHEREISFILE) "M-/"  LAST_FILE_MSG 0 #t)
    (AddShortcut (logior MBROWSER MWHEREISFILE) "M-?"  LAST_FILE_MSG 0 #t)
    (AddShortcut (logior MBROWSER MWHEREISFILE) "^_"  GOTO_DIR_MSG 0 #t)
    (AddShortcut (logior MBROWSER MWHEREISFILE) "F13"  GOTO_DIR_MSG 0 #t)
    (AddShortcut (logior MBROWSER MWHEREISFILE) "M-G"  GOTO_DIR_MSG 0 #t)
    (AddShortcut MMAIN "M-]" DO_FIND_BRACKET 0 #t)
    (AddShortcut MMAIN "M--" DO_SCROLL_UP 0 #t)
    (AddShortcut MMAIN "M-_" DO_SCROLL_UP 0 #t)
    (AddShortcut MMAIN "M-+" DO_SCROLL_DOWN 0 #t)
    (AddShortcut MMAIN "M-=" DO_SCROLL_DOWN 0 #t)
    (AddShortcut MMAIN "M-<" SWITCH_TO_PREV_BUFFER_VOID 0 #t)
    (AddShortcut MMAIN "M-," SWITCH_TO_PREV_BUFFER_VOID 0 #t)
    (AddShortcut MMAIN "M->" SWITCH_TO_NEXT_BUFFER_VOID 0 #t)
    (AddShortcut MMAIN "M-." SWITCH_TO_NEXT_BUFFER_VOID 0 #t)
    (AddShortcut MALL "M-V" DO_VERBATIM_INPUT 0 #t)
    (AddShortcut MALL "M-T" DO_CUT_TILL_END 0 #t)
    (AddShortcut MALL "M-J" DO_FULL_JUSTIFY 0 #t)
    (AddShortcut MMAIN "M-D" DO_WORDLINECHAR_COUNT 0 #t)
    (AddShortcut MMAIN "M-X" DO_TOGGLE NO_HELP #t)
    (AddShortcut MMAIN "M-C" DO_TOGGLE CONST_UPDATE #t)
    (AddShortcut MMAIN "M-O" DO_TOGGLE MORE_SPACE #t)
    (AddShortcut MMAIN "M-S" DO_TOGGLE SMOOTH_SCROLL #t)
    (AddShortcut MMAIN "M-P" DO_TOGGLE WHITESPACE_DISPLAY #t)
    (AddShortcut MMAIN "M-Y" DO_TOGGLE NO_COLOR_SYNTAX #t)
    (AddShortcut MMAIN "M-H" DO_TOGGLE SMART_HOME #t)
    (AddShortcut MMAIN "M-I" DO_TOGGLE AUTOINDENT #t)
    (AddShortcut MMAIN "M-K" DO_TOGGLE CUT_TO_END #t)
    (AddShortcut MMAIN "M-L" DO_TOGGLE NO_WRAP #t)
    (AddShortcut MMAIN "M-Q" DO_TOGGLE TABS_TO_SPACES #t)
    (AddShortcut MMAIN "M-B" DO_TOGGLE BACKUP_FILE #t)
    (AddShortcut MMAIN "M-F" DO_TOGGLE MULTIBUFFER #t)
    (AddShortcut MMAIN "M-M" DO_TOGGLE USE_MOUSE #t)
    (AddShortcut MMAIN "M-N" DO_TOGGLE NO_CONVERT #t)
    (AddShortcut MMAIN "M-Z" DO_TOGGLE SUSPEND #t)
    (AddShortcut MMAIN "M-$" DO_TOGGLE SOFTWRAP #t)
    (AddShortcut MGOTOLINE "^T"  GOTOTEXT_MSG 0 #f)
    (AddShortcut (logior MINSERTFILE MEXTCMD)
		   "M-F"  NEW_BUFFER_MSG 0 #f)
    (AddShortcut (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MWRITEFILE
			   MINSERTFILE MEXTCMD MSPELL MWHEREISFILE MGOTODIR
			   MYESNO)
		   "^C" CANCEL_MSG 0 #f)
    (AddShortcut MWRITEFILE "M-D"  DOS_FORMAT_MSG 0 #f)
    (AddShortcut MWRITEFILE "M-M"  MAC_FORMAT_MSG 0 #f)
    (AddShortcut MWRITEFILE "M-A"  APPEND_MSG 0 #f)
    (AddShortcut MWRITEFILE "M-P"  PREPEND_MSG 0 #f)
    (AddShortcut MWRITEFILE "M-B"  BACKUP_FILE_MSG 0 #f)
    (AddShortcut MWRITEFILE "^T"  TO_FILES_MSG 0 #f)
    (AddShortcut MINSERTFILE "^T"  TO_FILES_MSG 0 #f)
    (AddShortcut MINSERTFILE "^X"  EXT_CMD_MSG 0 #f)
    (AddShortcut MMAIN "^Z" DO_SUSPEND_VOID 0 #f)
    (AddShortcut MMAIN "^L" TOTAL_REFRESH 0 #t)
    (AddShortcut MALL "^I" DO_TAB 0 #t)
    ;;(AddShortcut MALL "^M" DO_ENTER 0 #t)
    (AddShortcut MALL "^J" DO_ENTER 0 #t)
    (AddShortcut MALL "kenter" DO_ENTER 0 #t)
    (AddShortcut MALL "^D" DO_DELETE 0 #t)
    (AddShortcut MALL "kdel" DO_DELETE 0 #t)
    (AddShortcut MALL "^H" DO_BACKSPACE 0 #t)
    (AddShortcut MALL "kbsp" DO_BACKSPACE 0 #t)

    ;;(PrintScList)
    ))

(define (GetFunctionFromShortcut s)
  (find (lambda (f)
          (eqv? (GetFunctionId f) (GetShortcutFuncId s)))
        vrgFunctions))

;; This is the main dispatch
(define (iso_me_harder_funcmap func)
  (format (current-error-port) "Dispatching ~s~%" func)
  (cond
   [(eqv? func DO_ENTER)
    (do_enter #f)]
   [else
    #f]))


(define (GetFuncIdNameFromFuncId funcId)
  (let ([rgFuncIdNames
         '(NUL CASE_SENS_MSG BACKWARDS_MSG REGEXP_MSG WHEREIS_NEXT_MSG
               FIRST_FILE_MSG LAST_FILE_MSG GOTO_DIR_MSG TOTAL_REFRESH DO_HELP_VOID
               DO_SEARCH DO_PAGE_UP DO_PAGE_DOWN DO_UP_VOID DO_LEFT DO_DOWN_VOID
               DO_RIGHT DO_ENTER DO_EXIT NEW_BUFFER_MSG EXT_CMD_MSG TO_FILES_MSG
               DOS_FORMAT_MSG MAC_FORMAT_MSG BACKUP_FILE_MSG PREPEND_MSG APPEND_MSG
               DO_FIRST_LINE DO_LAST_LINE DO_TOGGLE GOTOTEXT_MSG NO_REPLACE_MSG
               DO_BACKSPACE DO_DELETE DO_TAB DO_VERBATIM_INPUT
               SWITCH_TO_NEXT_BUFFER_VOID SWITCH_TO_PREV_BUFFER_VOID DO_END DO_HOME
               NEXT_HISTORY_MSG PREV_HISTORY_MSG DO_REDO DO_UNDO
               DO_WORDLINECHAR_COUNT DO_FIND_BRACKET DO_PREV_WORD_VOID
               DO_SUSPEND_VOID CANCEL_MSG DO_WRITEOUT_VOID DO_INSERTFILE_VOID
               DO_CUT_TEXT_VOID DO_UNCUT_TEXT DO_CURSORPOS_VOID
               DO_GOTOLINECOLUMN_VOID DO_REPLACE DO_JUSTIFY_VOID DO_PARA_BEGIN_VOID
               DO_PARA_END_VOID DO_FULL_JUSTIFY DO_MARK DO_RESEARCH DO_COPY_TEXT
               DO_INDENT_VOID DO_UNINDENT DO_SCROLL_UP DO_SCROLL_DOWN
               DO_NEXT_WORD_VOID DO_CUT_TILL_END NANO_GOTODIR_MSG NANO_LASTFILE_MSG
               NANO_FIRSTFILE_MSG INSERT_FILE_MSG NANO_MULTIBUFFER_MSG
               NANO_EXECUTE_MSG NANO_BACKUP_MSG NANO_PREPEND_MSG NANO_APPEND_MSG
               NANO_MAC_MSG NANO_DOS_MSG NANO_TOFILES_MSG NANO_NEXT_HISTORY_MSG
               NANO_PREV_HISTORY_MSG NANO_REGEXP_MSG NANO_REVERSE_MSG NANO_CASE_MSG
               NANO_SUSPEND_MSG SUSPEND_MSG NANO_REFRESH_MSG REFRESH_MSG
               NANO_WORDCOUNT_MSG NANO_FULLJUSTIFY_MSG FULLJSTIFY_MSG XOFF_COMPLAINT
               XON_COMPLAINT NANO_CUT_TILL_END_MSG NANO_BACKSPACE_MSG NANO_DELETE_MSG
               NANO_ENTER_MSG NANO_TAB_MSG NANO_VERBATIM_MSG NANO_NEXTFILE_MSG
               NANO_PREVFILE_MSG NANO_SCROLLDOWN_MSG NANO_SCROLLUP_MSG
               NANO_BRACKET_MSG NANO_PARAEND_MSG END_OF_PAR_MSG NANO_PARABEGIN_MSG
               BEG_OF_PAR_MSG NANO_END_MSG NANO_HOME_MSG NANO_NEXTLINE_MSG
               NANO_PREVLINE_MSG NANO_PREVWORD_MSG NANO_NEXTWORD_MSG NANO_BACK_MSG
               NANO_FORWARD_MSG NANO_REDO_MSG NANO_UNDO_MSG NANO_UNINDENT_MSG
               NANO_INDENT_MSG NANO_COPY_MSG NANO_WHEREIS_NEXT_MSG NANO_MARK_MSG
               NANO_REPLACE_MSG REPLACE_MSG NANO_GOTOLINE_MSG NANO_LASTLINE_MSG
               NANO_FIRSTLINE_MSG NANO_SPELL_MSG DO_SPELL NANO_CURSORPOS_MSG
               NANO_UNCUT_MSG GET_HELP_MSG NANO_HELP_MSG NANO_CANCEL_MSG
               NANO_EXIT_MSG EXIT_MSG NANO_EXITBROWSER_MSG NANO_WRITEOUT_MSG
               NANO_DISABLED_MSG NANO_INSERT_MSG WHEREIS_MSG NANO_WHEREIS_MSG
               NANO_PREVPAGE_MSG NANO_NEXTPAGE_MSG NANO_CUT_MSG DO_CUT_TEXT
               DO_NEXT_WORD DO_PREV_WORD )])
    (list-ref rgFuncIdNames funcId)))