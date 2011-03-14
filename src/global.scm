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

(define vBuffer #f)

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
(define quotelen 0)

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
;;(define *functions* '())

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

(define vMenuCur #f)
;; Return the number of entries in the shortcut list S for
;; a given menu
(define (CountEntriesInMenu menu)
  (count (lambda (fn)
           (logtest (GetFunctionMenus fn) menu))
         *functions*))

(define (FindFirstShortcut menu funcId)
  (let ([nonMetaSc (find (lambda (sc)
                           (and (DoesShortcutMatchMenuAndFuncId? sc menu funcId)
                                (not (sc-does-shortcut-use-meta-key? sc))))
                         vrgShortcuts)]
        [metaSc (find (lambda (sc)
                        (and (DoesShortcutMatchMenuAndFuncId? sc menu funcId)
                             (sc-does-shortcut-use-meta-key? sc)))
                      vrgShortcuts)])
    (or nonMetaSc
        metaSc)))

;; Add a string to the new shortcut list implementation.
(define (sc-add-shortcut menu keyStr funcId toggleId fExecute)
  ;; (format (current-error-port) "sc-add-shortcut shortcut_list ~s~%" vrgShortcuts)

  (let* ([sc (sc-create-shortcut menu keyStr funcId toggleId fExecute)]
         [matchingSc (find (lambda (sc)
                             (sc-does-shortcut-match-context-and-func-id? sc menu funcId))
                           vrgShortcuts)])
    (format (current-error-port)
            "sc-add-shortcut menu ~s keyStr ~s funcId ~s toggleId ~s fExecute ~s~%"
            menu keyStr (GetFuncIdNameFromFuncId funcId) toggleId fExecute)
    (format (current-error-port)
            "sc-add-shortcut meta ~s key ~s~%" (sc-does-shortcut-use-meta-key? sc)
            (false-if-exception (keyname (sc-get-key sc))))
    (when matchingSc
      (format (current-error-port) "~s is duplicate shortcut ~s on menu ~s and function ~s~%"
              (sc-get-key-string matchingSc) keyStr menu funcId))

    (set! vrgShortcuts (append! vrgShortcuts (list sc)))))

(define (global-print-sc-list)
  (for-each
   (lambda (s)
     (let ([f (GetFunctionFromShortcut s)])
       (if f
           (log-debug
            (format #f "global-print-sc-list: \"~a\", function: ~a, menus ~a"
                    (sc-get-key-string s) (GetFunctionDesc f) (GetFunctionMenus f)))
           (log-warning
            (format #f "global-print-sc-list: shortcut \"~a\" has no function"
                    (sc-get-key-string s))))))
   *shortcuts*))

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
  ;; Clear out the old function list, if any
  (set! *functions* '())
  (gc)

  (func-add-function DO_HELP_VOID
                     (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE
                             MWRITEFILE MINSERTFILE MEXTCMD MSPELL MBROWSER
                             MWHEREISFILE MGOTODIR)
                     "Get Help" "Display this help text" #f VIEW)

  (func-add-function CANCEL_MSG
                     (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MWRITEFILE
                             MINSERTFILE MEXTCMD MSPELL MWHEREISFILE MGOTODIR
                             MYESNO)
                     "Cancel" "Cancel the current function" #f VIEW)

  (func-add-function DO_EXIT
                     MMAIN "Close" "Close the current file buffer / Exit from nano"#f VIEW)

  (func-add-function DO_EXIT
                     MBROWSER
                     "Exit" "Exit from the file browser" #f VIEW)

  ;; TRANSLATORS: Try to keep this at most 10 characters.
  (func-add-function DO_WRITEOUT_VOID
                     MMAIN
                     "WriteOut" "Write the current file to disk" #f NOVIEW)

  ;; TRANSLATORS: Try to keep this at most 10 characters.
  (func-add-function DO_JUSTIFY_VOID
                     MMAIN
                     "Justify" "Justify the current paragraph" #t NOVIEW)

  ;; We allow inserting files in view mode if multibuffers are
  ;; available, so that we can view multiple files.  If we're using
  ;; restricted mode, inserting files is disabled, since it allows
  ;; reading from or writing to files not specified on the command
  ;; line.
  (func-add-function (if (ISSET RESTRICTED) NANO_DISABLED_MSG DO_INSERTFILE_VOID)
                     MMAIN
                     "Read File" "Insert another file into the current one" #f VIEW)

  (func-add-function DO_SEARCH
                     (logior MMAIN MBROWSER)
                     "Where Is" "Search for a string or a regular expression" #f VIEW)
  (func-add-function DO_PAGE_UP
                     (logior MMAIN MHELP MBROWSER)
                     "Prev Page" "Go to previous screen" #f VIEW)
  (func-add-function DO_PAGE_DOWN
                     (logior MMAIN MHELP MBROWSER)
                     "Next Page" "Go to next screen" #t VIEW)

  ;; TRANSLATORS: Try to keep this at most 10 characters.
  (func-add-function DO_CUT_TEXT_VOID
                     MMAIN
                     "Cut Text" "Cut the current line and store it in the cutbuffer" #f NOVIEW)
  (if fUnjustify
      ;; TRANSLATORS: Try to keep this at most 10 characters.
      (func-add-function DO_UNCUT_TEXT
                         MMAIN (N_ "UnJustify") "" #f NOVIEW)
      ;; else
      (func-add-function DO_UNCUT_TEXT
                         MMAIN "UnCut Text" "Uncut from the cutbuffer into the current line"
                         #f  NOVIEW))

  ;; TRANSLATORS: Try to keep this at most 10 characters.
  (func-add-function DO_CURSORPOS_VOID
                     MMAIN
                     "Cur Pos" "Display the position of the cursor" #f VIEW)

  ;; If we're using restricted mode, spell checking is disabled
  ;; because it allows reading from or writing to files not specified
  ;; on the command line.
  (if (not (ISSET RESTRICTED))
      ;; TRANSLATORS: Try to keep this at most 10 characters.
      (func-add-function DO_SPELL
                         MMAIN
                         "To Spell" "Invoke the spell checker, if available" #t NOVIEW))

  (func-add-function DO_FIRST_LINE
                     (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE)
                     "First Line" "Go to the first line of the file" #f VIEW)

  (func-add-function DO_LAST_LINE
                     (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE)
                     "Last Line" "Go to the last line of the file" #t VIEW)

  (func-add-function DO_GOTOLINECOLUMN_VOID
                     (logior MMAIN MWHEREIS)
                     "Go To Line" "Go to line and column number" #f VIEW)

  (func-add-function DO_REPLACE
                     (logior MMAIN MWHEREIS)
                     "Replace" "Replace a string or regular expression" #f NOVIEW)

  (func-add-function DO_MARK MMAIN "Mark Text" "Mark text at the current position" #f VIEW)
  (func-add-function DO_RESEARCH (logior MMAIN MBROWSER) "WhereIs Next"
                     "Repeat last search" #t VIEW)
  (func-add-function DO_COPY_TEXT MMAIN "Copy Text" "Copy the current line and store it in the cutbuffer" #f NOVIEW)
  (func-add-function DO_INDENT_VOID MMAIN "Indent Text" "Indent the current line" #f NOVIEW)
  (func-add-function DO_UNINDENT MMAIN "Unindent Text" "Unindent the current line" #f NOVIEW)

  (if (ISSET UNDOABLE)
      (begin
        (func-add-function DO_UNDO MMAIN "Undo" "Undo the last operation" #f NOVIEW)
        (func-add-function DO_REDO MMAIN "Redo" "Redo the last undone operation" #t NOVIEW)))

  (func-add-function DO_RIGHT MMAIN "Forward" "Go forward one character" #f VIEW)
  (func-add-function DO_RIGHT MBROWSER "Forward" "Go to the next file in the list" #f VIEW)
  (func-add-function DO_RIGHT MALL "" "" #f VIEW)
  (func-add-function DO_LEFT MMAIN "Back" "Go back one character" #f VIEW)
  (func-add-function DO_LEFT MBROWSER "Back" "Go to the previous file in the list" #f VIEW)
  (func-add-function DO_LEFT MALL "" "" FALSE VIEW)
  (func-add-function DO_NEXT_WORD_VOID MMAIN "Next Word" "Go forward one word" #f VIEW)
  (func-add-function DO_PREV_WORD_VOID MMAIN "Prev Word" "Go back one word" #f VIEW)
  (func-add-function DO_UP_VOID (logior MMAIN MHELP MBROWSER)
                     "Prev Line" "Go to previous line" #f VIEW)
  (func-add-function DO_DOWN_VOID (logior MMAIN MHELP MBROWSER)
                     "Next Line" "Go to next line" #t VIEW)
  (func-add-function DO_HOME MMAIN "Home" "Go to beginning of current line" #f VIEW)
  (func-add-function DO_END MMAIN "End" "Go to end of current line" #f VIEW)
  (func-add-function DO_PARA_BEGIN_VOID (logior MMAIN MWHEREIS)
                     "Beg of Par"
                     "Go to beginning of paragraph; then of previous paragraph" #f VIEW)
  (func-add-function DO_PARA_END_VOID (logior MMAIN MWHEREIS)
                     "End of Par"
                     "Go just beyond end of paragraph; then of next paragraph" #f VIEW)
  (func-add-function DO_FIND_BRACKET MMAIN "Find Other Bracket" "Go to the matching bracket"
                     #f VIEW)
  (func-add-function DO_SCROLL_UP
                     MMAIN
                     "Scroll Up" "Scroll up one line without scrolling the cursor" #f VIEW)

  (func-add-function DO_SCROLL_DOWN
                     MMAIN
                     "Scroll Down" "Scroll down one line without scrolling the cursor" #f VIEW)
  (func-add-function SWITCH_TO_PREV_BUFFER_VOID
                     MMAIN
                     "Previous File" "Switch to the previous file buffer" #f VIEW)
  (func-add-function SWITCH_TO_NEXT_BUFFER_VOID
                     MMAIN
                     "Next File" "Switch to the next file buffer" #t VIEW)
  (func-add-function DO_VERBATIM_INPUT
                     MMAIN
                     "Verbatim Input" "Insert the next keystroke verbatim" #f
                     NOVIEW)
  (func-add-function DO_VERBATIM_INPUT
                     (logior MWHEREIS MREPLACE MREPLACE2 MEXTCMD MSPELL)
                     ""  ""  #f  NOVIEW)
  (func-add-function DO_TAB
                     MMAIN
                     "Tab" "Insert a tab character at the cursor position" #f NOVIEW)
  (func-add-function DO_TAB
                     MALL
                     ""  ""  #f  NOVIEW)
  (func-add-function DO_ENTER
                     MMAIN
                     "Enter" "Insert a newline at the cursor position" #f  NOVIEW)
  (func-add-function DO_ENTER
                     MALL
                     ""  ""  #f  NOVIEW)
  (func-add-function DO_DELETE
                     MMAIN
                     "Delete" "Delete the character under the cursor" #f NOVIEW)
  (func-add-function DO_DELETE
                     MALL
                     ""  ""  #f  NOVIEW)
  (func-add-function DO_BACKSPACE
                     MMAIN
                     "Backspace" "Delete the character to the left of the cursor" #t NOVIEW)
  (func-add-function DO_BACKSPACE
                     MALL
                     ""  ""
                     #t NOVIEW)

  (func-add-function DO_CUT_TILL_END
                     MMAIN
                     "CutTillEnd" "Cut from the cursor position to the end of the file" #t
                     NOVIEW)
  (func-add-function XON_COMPLAINT
                     MMAIN
                     ""  ""  #f  VIEW);
  (func-add-function XOFF_COMPLAINT
                     MMAIN
                     ""  ""  #f  VIEW);

  (func-add-function DO_FULL_JUSTIFY
                     (logior MMAIN MWHEREIS)
                     "FullJstify" "Justify the entire file" #f NOVIEW)
  (func-add-function DO_WORDLINECHAR_COUNT
                     MMAIN
                     "Word Count" "Count the number of words, lines, and characters" #f VIEW)
  (func-add-function TOTAL_REFRESH
                     (logior MMAIN MHELP)
                     "Refresh" "Refresh (redraw) the current screen" #f VIEW)

  (func-add-function DO_SUSPEND_VOID
                     MMAIN
                     "Suspend" "Suspend the editor (if suspend is enabled)" #t VIEW)
  (func-add-function CASE_SENS_MSG
                     (logior MWHEREIS MREPLACE MWHEREISFILE)
                     "Case Sens" "Toggle the case sensitivity of the search" #f VIEW)

  (func-add-function BACKWARDS_MSG
                     (logior MWHEREIS MREPLACE MWHEREISFILE)
                     "Backwards" "Reverse the direction of the search" #f VIEW)
  (func-add-function REGEXP_MSG
                     (logior MWHEREIS MREPLACE MWHEREISFILE)
                     "Regexp" "Toggle the use of regular expressions" #f VIEW)
  (func-add-function PREV_HISTORY_MSG
                     (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
                     "PrevHstory" "Recall the previous search/replace string" #f VIEW)
  (func-add-function NEXT_HISTORY_MSG
                     (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
                     "NextHstory" "Recall the next search/replace string" #f VIEW)
  (func-add-function NO_REPLACE_MSG
                     MREPLACE
                     "No Replace" "" #f VIEW)

  (func-add-function GOTOTEXT_MSG
                     MGOTOLINE
                     "Go To Text" "" #t VIEW)
  (if (not (ISSET RESTRICTED))
      (func-add-function TO_FILES_MSG
                         (logior MGOTOLINE MINSERTFILE)
                         "To Files" "Go to file browser" #f VIEW))

  ;; If we're using restricted mode, the DOS format, Mac format,
  ;; append, prepend, and backup toggles are disabled.  The first and
  ;; second are useless since inserting files is disabled, the third
  ;; and fourth are disabled because they allow writing to files not
  ;; specified on the command line, and the fifth is useless since
  ;; backups are disabled.
  (unless (ISSET RESTRICTED)
    (func-add-function DOS_FORMAT_MSG
                       MWRITEFILE
                       "DOS Format" "Toggle the use of DOS format" #f NOVIEW)
    (func-add-function MAC_FORMAT_MSG
                       MWRITEFILE
                       "Mac Format" "Toggle the use of Mac format" #f  NOVIEW)
    (func-add-function APPEND_MSG
                       MWRITEFILE
                       "Append" "Toggle appending" #f NOVIEW)
    (func-add-function PREPEND_MSG
                       MWRITEFILE
                       "Prepend" "Toggle prepending" #f NOVIEW)
    (func-add-function BACKUP_FILE_MSG MWRITEFILE
                       "Backup File" "Toggle backing up of the original file" #f
                       NOVIEW))

  ;; If we're using restricted mode, command execution is disabled.
  ;; It's useless since inserting files is disabled.
  (if (not (ISSET RESTRICTED))
      (func-add-function EXT_CMD_MSG
                         MINSERTFILE
                         "Execute Command" "Execute external command" #f NOVIEW))

  ;; If we're using restricted mode  the multibuffer toggle is
  ;; disabled.  It's useless since inserting files is disabled.
  (if (not (ISSET RESTRICTED))
      (func-add-function NEW_BUFFER_MSG
                         MINSERTFILE
                         "New Buffer" "Toggle the use of a new buffer" #f
                         NOVIEW))
  (func-add-function  INSERT_FILE_MSG
                      MEXTCMD
                      "Insert File" "Insert another file into the current one" #f VIEW)

  (func-add-function NEW_BUFFER_MSG
                     MEXTCMD
                     "New Buffer" "Toggle the use of a new buffer" #f NOVIEW)
  (func-add-function REFRESH_MSG
                     MHELP
                     "Refresh" "Refresh (redraw) the entire screen" #f VIEW)

  (func-add-function DO_EXIT
                     MHELP
                     "Exit" "Close the current file buffer / Exit from nano" #f VIEW)
  (func-add-function FIRST_FILE_MSG
                     (logior MBROWSER MWHEREISFILE)
                     "First File" "Go to the first file in the list" #f VIEW)

  (func-add-function LAST_FILE_MSG
                     (logior MBROWSER MWHEREISFILE)
                     "Last File" "Go to the last file in the list" #f VIEW)

  (func-add-function GOTO_DIR_MSG
                     MBROWSER
                     "Go To Dir" "Go to directory" #f VIEW)

  (set! vMenuCur MMAIN)

  (sc-add-shortcut (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE
                           MWRITEFILE MINSERTFILE MEXTCMD MSPELL MBROWSER
                           MWHEREISFILE MGOTODIR)
                   "^G" DO_HELP_VOID 0 #t)
  (sc-add-shortcut (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE
                           MWRITEFILE MINSERTFILE MEXTCMD MSPELL MBROWSER
                           MWHEREISFILE MGOTODIR)
                   "F1" DO_HELP_VOID 0 #t)
  (sc-add-shortcut (logior MMAIN MHELP MBROWSER)
                   "^X" DO_EXIT 0 #t)
  (sc-add-shortcut (logior MMAIN MHELP MBROWSER)
                   "F2" DO_EXIT 0 #t)
  (sc-add-shortcut MMAIN "^_" DO_GOTOLINECOLUMN_VOID 0 #t)
  (sc-add-shortcut MMAIN "F13" DO_GOTOLINECOLUMN_VOID 0 #t)
  (sc-add-shortcut MMAIN "M-G" DO_GOTOLINECOLUMN_VOID 0 #t)
  (sc-add-shortcut MMAIN "^O" DO_WRITEOUT_VOID 0 #t)
  (sc-add-shortcut MMAIN "F3" DO_WRITEOUT_VOID 0 #t)
  ;; (sc-add-shortcut MMAIN "^J" DO_JUSTIFY_VOID 0 #t)
  (sc-add-shortcut MMAIN "F4" DO_JUSTIFY_VOID 0 #t)
  (sc-add-shortcut MMAIN "^R" DO_INSERTFILE_VOID 0 #t)
  (sc-add-shortcut MMAIN "F5" DO_INSERTFILE_VOID 0 #t)
  (sc-add-shortcut MMAIN "kinsert" DO_INSERTFILE_VOID 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER)
                   "^W" DO_SEARCH 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER)
                   "F6" DO_SEARCH 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE)
                   "^Y" DO_PAGE_UP 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE)
                   "F7" DO_PAGE_UP 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE)
                   "kpup" DO_PAGE_UP 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE)
                   "^V" DO_PAGE_DOWN 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE)
                   "F8" DO_PAGE_DOWN 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE)
                   "kpdown" DO_PAGE_DOWN 0 #t)
  (sc-add-shortcut MMAIN "^K" DO_CUT_TEXT_VOID 0 #t)
  (sc-add-shortcut MMAIN "F9" DO_CUT_TEXT_VOID 0 #t)
  (sc-add-shortcut MMAIN "^U" DO_UNCUT_TEXT 0 #t)
  (sc-add-shortcut MMAIN "F10" DO_UNCUT_TEXT 0 #t)
  (sc-add-shortcut MMAIN "^C" DO_CURSORPOS_VOID 0 #t)
  (sc-add-shortcut MMAIN "F11" DO_CURSORPOS_VOID 0 #t)
  (sc-add-shortcut MMAIN "^T" DO_SPELL 0 #t)
  (sc-add-shortcut MMAIN "F12" DO_SPELL 0 #t)
  (sc-add-shortcut MMAIN "^\\" DO_REPLACE 0 #t)
  (sc-add-shortcut MMAIN "F14" DO_REPLACE 0 #t)
  (sc-add-shortcut MMAIN "M-R" DO_REPLACE 0 #t)
  (sc-add-shortcut MWHEREIS "^R" DO_REPLACE 0 #f)
  (sc-add-shortcut MREPLACE "^R" NO_REPLACE_MSG 0 #f)
  (sc-add-shortcut MWHEREIS "^T" DO_GOTOLINECOLUMN_VOID 0 #f)
  (sc-add-shortcut MMAIN "^^" DO_MARK 0 #t)
  (sc-add-shortcut MMAIN "F15" DO_MARK 0 #t)
  (sc-add-shortcut MMAIN "M-A" DO_MARK 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER) "M-W" DO_RESEARCH 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER) "F16" DO_RESEARCH 0 #t)
  (sc-add-shortcut MMAIN "M-^" DO_COPY_TEXT 0 #t)
  (sc-add-shortcut MMAIN "M-6" DO_COPY_TEXT 0 #t)
  (sc-add-shortcut MMAIN "M-\x7D" DO_INDENT_VOID 0 #t)
  (sc-add-shortcut MMAIN "M-\x7B" DO_UNINDENT 0 #t)
  (if (ISSET UNDOABLE)
      (begin
        (sc-add-shortcut MMAIN "M-U" DO_UNDO 0 #t)
        (sc-add-shortcut MMAIN "M-E" DO_REDO 0 #t)))
  (sc-add-shortcut MALL "^F" DO_RIGHT 0 #t)
  (sc-add-shortcut MALL "^B" DO_LEFT 0 #t)
  (sc-add-shortcut MMAIN "^Space" DO_NEXT_WORD_VOID 0 #t)
  (sc-add-shortcut MMAIN "M-Space" DO_PREV_WORD_VOID 0 #t)
  (sc-add-shortcut MALL "kright" DO_RIGHT 0 #t)
  (sc-add-shortcut MALL "kleft" DO_LEFT 0 #t)
  (sc-add-shortcut MMAIN "^Q" XON_COMPLAINT 0 #t)
  (sc-add-shortcut MMAIN "^S" XOFF_COMPLAINT 0 #t)
  (sc-add-shortcut (logior MMAIN MHELP MBROWSER) "^P" DO_UP_VOID 0 #t)
  (sc-add-shortcut (logior MMAIN MHELP MBROWSER) "kup" DO_UP_VOID 0 #t)
  (sc-add-shortcut (logior MMAIN MHELP MBROWSER) "^N" DO_DOWN_VOID 0 #t)
  (sc-add-shortcut (logior MMAIN MHELP MBROWSER) "kdown" DO_DOWN_VOID 0 #t)
  (sc-add-shortcut MALL "^A" DO_HOME 0 #t)
  (sc-add-shortcut MALL "khome" DO_HOME 0 #t)
  (sc-add-shortcut MALL "^E" DO_END 0 #t)
  (sc-add-shortcut MALL "kend" DO_END 0 #t)
  (sc-add-shortcut (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
                   "^P"  PREV_HISTORY_MSG 0 #f)
  (sc-add-shortcut (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
                   "kup"  PREV_HISTORY_MSG 0 #f)
  (sc-add-shortcut (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
                   "^N"  NEXT_HISTORY_MSG 0 #f)
  (sc-add-shortcut (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
                   "kdown"  NEXT_HISTORY_MSG 0 #f)
  (sc-add-shortcut (logior MWHEREIS MREPLACE MREPLACE2)
                   "^W" DO_PARA_BEGIN_VOID 0 #t)
  (sc-add-shortcut (logior MWHEREIS MREPLACE MREPLACE2)
                   "^O" DO_PARA_END_VOID 0 #t)
  (sc-add-shortcut MALL "M-(" DO_PARA_BEGIN_VOID 0 #t)
  (sc-add-shortcut MALL "M-9" DO_PARA_BEGIN_VOID 0 #t)
  (sc-add-shortcut MALL "M-)" DO_PARA_END_VOID 0 #t)
  (sc-add-shortcut MALL "M-0" DO_PARA_END_VOID 0 #t)
  (sc-add-shortcut MWHEREIS "M-C" CASE_SENS_MSG 0 #f)
  (sc-add-shortcut MREPLACE "M-C" CASE_SENS_MSG 0 #f)
  (sc-add-shortcut MREPLACE2 "M-C" CASE_SENS_MSG 0 #f)
  (sc-add-shortcut (logior MWHEREIS MREPLACE MREPLACE2)
                   "M-B" BACKWARDS_MSG 0 #f)
  (sc-add-shortcut (logior MWHEREIS MREPLACE MREPLACE2)
                   "M-R" REGEXP_MSG 0 #f)

  (sc-add-shortcut MMAIN "M-\\" DO_FIRST_LINE 0 #t)
  (sc-add-shortcut MMAIN "M-|" DO_FIRST_LINE 0 #t)
  (sc-add-shortcut MMAIN "M-/" DO_LAST_LINE 0 #t)
  (sc-add-shortcut MMAIN "M-?" DO_LAST_LINE 0 #t)
  (sc-add-shortcut (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MHELP)
                   "^Y" DO_FIRST_LINE 0 #t)
  (sc-add-shortcut (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MHELP)
                   "^V" DO_LAST_LINE 0 #t)

  (sc-add-shortcut (logior MBROWSER MWHEREISFILE) "M-\\"  FIRST_FILE_MSG 0 #t)
  (sc-add-shortcut (logior MBROWSER MWHEREISFILE) "M-|"  FIRST_FILE_MSG 0 #t)
  (sc-add-shortcut (logior MBROWSER MWHEREISFILE) "M-/"  LAST_FILE_MSG 0 #t)
  (sc-add-shortcut (logior MBROWSER MWHEREISFILE) "M-?"  LAST_FILE_MSG 0 #t)
  (sc-add-shortcut (logior MBROWSER MWHEREISFILE) "^_"  GOTO_DIR_MSG 0 #t)
  (sc-add-shortcut (logior MBROWSER MWHEREISFILE) "F13"  GOTO_DIR_MSG 0 #t)
  (sc-add-shortcut (logior MBROWSER MWHEREISFILE) "M-G"  GOTO_DIR_MSG 0 #t)
  (sc-add-shortcut MMAIN "M-]" DO_FIND_BRACKET 0 #t)
  (sc-add-shortcut MMAIN "M--" DO_SCROLL_UP 0 #t)
  (sc-add-shortcut MMAIN "M-_" DO_SCROLL_UP 0 #t)
  (sc-add-shortcut MMAIN "M-+" DO_SCROLL_DOWN 0 #t)
  (sc-add-shortcut MMAIN "M-=" DO_SCROLL_DOWN 0 #t)
  (sc-add-shortcut MMAIN "M-<" SWITCH_TO_PREV_BUFFER_VOID 0 #t)
  (sc-add-shortcut MMAIN "M-," SWITCH_TO_PREV_BUFFER_VOID 0 #t)
  (sc-add-shortcut MMAIN "M->" SWITCH_TO_NEXT_BUFFER_VOID 0 #t)
  (sc-add-shortcut MMAIN "M-." SWITCH_TO_NEXT_BUFFER_VOID 0 #t)
  (sc-add-shortcut MALL "M-V" DO_VERBATIM_INPUT 0 #t)
  (sc-add-shortcut MALL "M-T" DO_CUT_TILL_END 0 #t)
  (sc-add-shortcut MALL "M-J" DO_FULL_JUSTIFY 0 #t)
  (sc-add-shortcut MMAIN "M-D" DO_WORDLINECHAR_COUNT 0 #t)
  (sc-add-shortcut MMAIN "M-X" DO_TOGGLE NO_HELP #t)
  (sc-add-shortcut MMAIN "M-C" DO_TOGGLE CONST_UPDATE #t)
  (sc-add-shortcut MMAIN "M-O" DO_TOGGLE MORE_SPACE #t)
  (sc-add-shortcut MMAIN "M-S" DO_TOGGLE SMOOTH_SCROLL #t)
  (sc-add-shortcut MMAIN "M-P" DO_TOGGLE WHITESPACE_DISPLAY #t)
  (sc-add-shortcut MMAIN "M-Y" DO_TOGGLE NO_COLOR_SYNTAX #t)
  (sc-add-shortcut MMAIN "M-H" DO_TOGGLE SMART_HOME #t)
  (sc-add-shortcut MMAIN "M-I" DO_TOGGLE AUTOINDENT #t)
  (sc-add-shortcut MMAIN "M-K" DO_TOGGLE CUT_TO_END #t)
  (sc-add-shortcut MMAIN "M-L" DO_TOGGLE NO_WRAP #t)
  (sc-add-shortcut MMAIN "M-Q" DO_TOGGLE TABS_TO_SPACES #t)
  (sc-add-shortcut MMAIN "M-B" DO_TOGGLE BACKUP_FILE #t)
  (sc-add-shortcut MMAIN "M-F" DO_TOGGLE MULTIBUFFER #t)
  (sc-add-shortcut MMAIN "M-M" DO_TOGGLE USE_MOUSE #t)
  (sc-add-shortcut MMAIN "M-N" DO_TOGGLE NO_CONVERT #t)
  (sc-add-shortcut MMAIN "M-Z" DO_TOGGLE SUSPEND #t)
  (sc-add-shortcut MMAIN "M-$" DO_TOGGLE SOFTWRAP #t)
  (sc-add-shortcut MGOTOLINE "^T"  GOTOTEXT_MSG 0 #f)
  (sc-add-shortcut (logior MINSERTFILE MEXTCMD)
                   "M-F"  NEW_BUFFER_MSG 0 #f)
  (sc-add-shortcut (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MWRITEFILE
                           MINSERTFILE MEXTCMD MSPELL MWHEREISFILE MGOTODIR
                           MYESNO)
                   "^C" CANCEL_MSG 0 #f)
  (sc-add-shortcut MWRITEFILE "M-D"  DOS_FORMAT_MSG 0 #f)
  (sc-add-shortcut MWRITEFILE "M-M"  MAC_FORMAT_MSG 0 #f)
  (sc-add-shortcut MWRITEFILE "M-A"  APPEND_MSG 0 #f)
  (sc-add-shortcut MWRITEFILE "M-P"  PREPEND_MSG 0 #f)
  (sc-add-shortcut MWRITEFILE "M-B"  BACKUP_FILE_MSG 0 #f)
  (sc-add-shortcut MWRITEFILE "^T"  TO_FILES_MSG 0 #f)
  (sc-add-shortcut MINSERTFILE "^T"  TO_FILES_MSG 0 #f)
  (sc-add-shortcut MINSERTFILE "^X"  EXT_CMD_MSG 0 #f)
  (sc-add-shortcut MMAIN "^Z" DO_SUSPEND_VOID 0 #f)
  (sc-add-shortcut MMAIN "^L" TOTAL_REFRESH 0 #t)
  (sc-add-shortcut MALL "^I" DO_TAB 0 #t)
  (sc-add-shortcut MALL "^M" DO_ENTER 0 #t)
  (sc-add-shortcut MALL "kenter" DO_ENTER 0 #t)
  (sc-add-shortcut MALL "^J" DO_ENTER 0 #t)
  (sc-add-shortcut MALL "^D" DO_DELETE 0 #t)
  (sc-add-shortcut MALL "kdel" DO_DELETE 0 #t)
  (sc-add-shortcut MALL "^H" DO_BACKSPACE 0 #t)
  (sc-add-shortcut MALL "kbsp" DO_BACKSPACE 0 #t)

  (global-print-sc-list))

(define (GetFunctionFromShortcut s)
  (find (lambda (f)
          (eqv? (GetFunctionId f) (sc-get-function-id s)))
        *functions*))

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