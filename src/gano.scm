;;; gano.scm
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


;; Used to store the user's original mouse click interval
(define oldinterval -1)

;; Should we ignore all rc files?
(define fRcFileEnable #t)

;; The user's original terminal settings
(define vTermAttr #f)
;; A port containing the terminal
(define vTerminalPort 0)
;; Used to set up all out fun signal handlers
(define act #f)

;; Display a warning about a key disabled in view mode
(define (print_view_warning)
  (winio-statusbar (_ "Key invalid in view mode")))


;; Print one usage string to the screen.  This cuts down on duplicate
;; strings to translate, and leaves out the parts that shouldn't be
;; translatable (i.e. the flag names).
(define (print_opt shortflag longflag desc)
  (format #t " ~a\t" shortflag)
  (when (< (CountCellsInString shortflag) 8)
    (format #t "\t"))

  (format #t "~a\t" longflag)
  (cond
   ((< (CountCellsInString longflag) 8)
    (format #t "\t\t"))
   ((< (CountCellsInString longflag) 16)
    (format #t "\t")))

  (when desc
    (format #t "~a" desc))

  (format #t "~%"))

;; Explain how to properly use nano's command line options
(define (usage)
  (format #t "Usage: nano (OPTIONS} ((+LINE,COLUMN) FILE)...~%~%")
  (format #t "Option\t\tGNU long option\t\tMeaning~%")

  (print_opt "-h, -?" "--help" (N_ "Show this message"))
  (print_opt (_ "+LINE,COLUMN") "" (N_ "Start at line LINE, column COLUMN"))
  (print_opt "-A" "--smarthome" (N_ "Enable smart home key"))
  (print_opt "-B" "--backup" (N_ "Save backups of existing files"))
  (print_opt (_ "-C <dir>") (_ "--backupdir=<dir>")
             (N_ "Directory for saving unique backup files"))

  (print_opt "-D" "--boldtext" (N_ "Use bold instead of reverse video text"))
  (print_opt "-E" "--tabstospaces" (N_ "Convert typed tabs to spaces"))

  (print_opt "-F" "--multibuffer" (N_ "Enable multiple file buffers"))

  (print_opt "-H" "--historylog" (N_ "Log & read search/replace string history"))

  (print_opt "-I" "--ignorercfiles" (N_ "Don't look at nanorc files"))

  (print_opt "-K" "--rebindkeypad" (N_ "Fix numeric keypad key confusion problem"))
  (print_opt "-L" "--nonewlines" (N_ "Don't add newlines to the ends of files"))
  (print_opt "-N" "--noconvert" (N_ "Don't convert files from DOS/Mac format"))

  (print_opt "-O" "--morespace" (N_ "Use one more line for editing"))
  (print_opt (_ "-Q <str>") (_ "--quotestr=<str>") (N_ "Quoting string"))

  (print_opt "-R" "--restricted" (N_ "Restricted mode"))
  (print_opt "-S" "--smooth" (N_ "Scroll by line instead of half-screen"))

  (print_opt (_ "-T <#cols>") (_ "--tabsize=<#cols>") (N_ "Set width of a tab to #cols columns"))
  (print_opt "-U" "--quickblank" (N_ "Do quick statusbar blanking"))

  (print_opt "-V" "--version" (N_ "Print version information and exit"))
  (print_opt "-W" "--wordbounds" (N_ "Detect word boundaries more accurately"))

  (print_opt (_ "-Y <str>") (_ "--syntax=<str>") (N_ "Syntax definition to use for coloring"))

  (print_opt "-c" "--const" (N_ "Constantly show cursor position"))
  (print_opt "-d" "--rebinddelete" (N_ "Fix Backspace/Delete confusion problem"))
  (print_opt "-i" "--autoindent" (N_ "Automatically indent new lines"))
  (print_opt "-k" "--cut" (N_ "Cut from cursor to end of line"))

  (print_opt "-l" "--nofollow" (N_ "Don't follow symbolic links, overwrite"))
  (print_opt "-m" "--mouse" (N_ "Enable the use of the mouse"))

  (print_opt (_ "-o <dir>") (_"--operatingdir=<dir>") (N_ "Set operating directory"))

  (print_opt "-p" "--preserve" (N_ "Preserve XON (^Q) and XOFF (^S) keys"))
  (print_opt "-q" "--quiet" (N_ "Silently ignore startup issues like rc file errors"))
  (print_opt (_ "-r <#cols>") (_ "--fill=<#cols>") (N_ "Set wrapping point at column #cols"))

  (print_opt (_ "-s <prog>") (_ "--speller=<prog>") (N_ "Enable alternate speller"))

  (print_opt "-t" "--tempfile" (N_ "Auto save on exit, don't prompt"))

  (print_opt "-u" "--undo" (N_ "Allow generic undo (EXPERIMENTAL)"))

  (print_opt "-v" "--view" (N_ "View mode (read-only)"))
  (print_opt "-w" "--nowrap" (N_ "Don't wrap long lines"))

  (print_opt "-x" "--nohelp" (N_ "Don't show the two help lines"))
  (print_opt "-z" "--suspend" (N_ "Enable suspension"))
  (print_opt "-$" "--softwrap" (N_ "Enable soft line wrapping"))

  ;;
  (print_opt "-a, -b, -e," "" #f)
  (print_opt "-f, -g, -j" "" (N_ "(ignored, for Pico compatibility)"))
  (exit 0))

;; Display the current version of nano, the date and time it was
;; compiled, contact information for it, and the configuration options
;; it was compiled with.
(define (version)
  (format #t "GNU nano version ~A (compiled ~A, ~A)~%"
          "blah" "blah" "blah")
  (format #t " (C) 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007,~%")
  (format #t " 2008, 2009 Free Software Foundation, Inc.~%")
  (format #t " Email: nano@nano-editor.org Web: http://www.nano-editor.org~%")
  (format #t "~%"))


;; Initialize the signal handlers.
(define (InitSignal)
  ;; Trap SIGINT and SIGQUIT because we want them to do useful things.
  (sigaction SIGINT SIG_IGN)
  (sigaction SIGQUIT SIG_IGN)

  ;; Trap SIGHUP and SIGTERM because we want to write the file out.
  (sigaction SIGHUP handle_hupterm)
  (sigaction SIGTERM handle_hupterm)

  ;; Trap SIGWINCH because we want to handle window resizes.
  (sigaction SIGWINCH handle_sigwinch)
  (gano-allow-pending-sigwinch #f)

  ;; Trap normal suspend (^Z) so we can handle it ourselves.
  (cond ((¬ (ISSET SUSPEND))
         (sigaction SIGSTOP SIG_IGN))
        ;; else
        ;; Block all other signals in the suspend and continue handlers.
        ;; If we don't do this, other stuff interrupts them!

        ;; FIXME: sigfillset(&act.sa_mask);
        (else
         (sigaction SIGTSTP do_suspend)
         (sigaction SIGCONT do_continue))))

;; Handler for SIGHUP (hangup) and SIGTERM (terminate)
(define (handle_hupterm signal)
  (error (_ "Received SIGHUP or SIGTERM")))

;; Handler for SIGTSTP (suspend).
(define (do_suspend signal)
  ;; Turn mouse support off.
  (disable_mouse_support)


  ;; Move the cursor to the last line of the screen.
  (move vWinMain (- (lines) 1) 0)
  (endwin)

  ;; Display our helpful message.
  (display (_ "Use \"fg\" to return to nano.~%"))
  (force-output)

  ;; Restore the old terminal settings.
  (tcsetattr! vTerminalPort TCSANOW old_terminal)

  ;; Trap SIGHUP and SIGTERM so we can properly deal with them while
  ;; suspended.
  (sigaction SIGHUP handle_hupterm)
  (sigaction SIGTERM handle_hupterm)

  ;; Do what mutt does: send ourselves a SIGSTOP. */
  (kill vTerminalPort SIGSTOP))

;; Handler for SIGCONT (continue after suspend).
(define (do_continue signal)
  ;; Turn mouse support back on if it was on before.
  (when (ISSET USE_MOUSE)
    (enable_mouse_support))


  ;; Perhaps the user resized the window while we slept.  Handle it,
  ;; and restore the terminal to its previous state and update the
  ;; screen in the process.
  (handle_sigwinch 0)
  ;; Restore the terminal to its previous state.
  (InitTerminal)

  ;; Turn the cursor back on for sure.
  (curs-set 1)

  ;; Redraw the contents of the windows that need it.
  (winio-blank-statusbar)
  (noutrefresh vWinBottom)
  (total_refresh)

  )

(define (main args)
  "Main entry point for the Gano editor"
  (let* ((optchr #f)
         ;; Line to try and start at, beginning at 1.
         (rowStart 1)
         ;; Column to try and start at, beginning at 1.
         (colStart 1)
         ;; Was the fill option used?
         (fFillUsed #f)
         ;; The old value of the multibuffer option,
         ;; restored after we load all files on the command
         ;; line
         (fMultibufferSav #f)
         (rgOptionsLong
          '((help (single-char #\h) (value #f))
            (boldtext (single-char #\D) (value #f))
            (multibuffer (single-char #\F) (value #f))
            (ignorercfiles (single-char #\I) (value #f))
            (rebindkeypad (single-char #\K) (value #f))
            (nonewlines (single-char #\L) (value #f))
            (morespace (single-char #\O) (value #f))
            (quotestr (single-char #\Q) (value #t))
            (restricted (single-char #\R) (value #f))
            (tabsizelen (single-char #\T) (value #t))
            (version (single-char #\V) (value #f))
            (syntax (single-char #\Y) (value #t))
            (const (single-char #\c) (value #f))
            (rebinddelete (single-char #\d) (value #f))
            (nofollow (single-char #\l) (value #f))
            (mouse (single-char #\m) (value #f))
            (operatingdir (single-char #\o) (value #t))
            (preserve (single-char #\p) (value #f))
            (quiet (single-char #\q) (value #f))
            (fill (single-char #\r) (value #t))
            (speller (single-char #\s) (value #t))
            (tempfile (single-char #\t) (value #f))
            (view (single-char #\v) (value #f))
            (nowrap (single-char #\w) (value #f))
            (nohelp (single-char #\x) (value #f))
            (suspend (single-char #\z) (value #f))
            (smarthome (single-char #\A) (value #f))
            (backup (single-char #\B) (value #f))
            (backupdir (single-char #\C) (value #t))
            (tabstospaces (single-char #\E) (value #f))
            (historylog (single-char #\H) (value #f))
            (noconvert (single-char #\N) (value #f))
            (smooth (single-char #\S) (value #f))
            (quickblank (single-char #\U) (value #f))
            (undo (single-char #\u) (value #f))
            (wordbounds (single-char #\W) (value #f))
            (autoindent (single-char #\i) (value #f))
            (cut (single-char #\k) (value #f))
            (softwrap (single-char #\$) (value #f))
            (rundebug (single-char #\e) (value #t))))
         (options (getopt-long args rgOptionsLong)))

    ;;(bindtextdomain vPackage vDirLocale)
    ;;(textdomain vPackage)

;;; INITIALIZATION:
;;; 1. Default parameters: lowest priority
;;; 2. RC File
;;; 3. Command line options
;;; 4. Options based on the name of the executable
;;; 5. Run Script File: highest priority


    ;; Set up the shortcut lists.  Need to to this before the rcfile.
    (InitShortcuts #f)
    ;; Load the RC file
    (when (option-ref options 'ignorercfiles #f)
      (set! fRcFileEnable #f))
    (when (and (not (char=? #\r (string-ref (first args) 0)))
               fRcFileEnable)
      ;;(LoadRcFile)
      #f)

    ;; Command line options
    (when (option-ref options 'smarthome #f)
      (SET SMART_HOME))
    (when (option-ref options 'backup #f)
      (SET BACKUP_FILE))
    (let ((d (option-ref options 'backupdir #f)))
      (if d (set! vDirBackup d)))
    (when (option-ref options 'boldtext #f)
      (SET BOLD_TEXT))
    (when (option-ref options 'tabstospaces #f)
      (SET TABS_TO_SPACES))
    (when (option-ref options 'multibuffer #f)
      (SET MULTIBUFFER))
    (when (option-ref options 'historylog #f)
      (SET HISTORYLOG))
    (when (option-ref options 'rebindkeypad #f)
      (SET REBIND_KEYPAD))
    (when (option-ref options 'nonewlines #f)
      (SET NO_NEWLINES))
    (when (option-ref options 'noconvert #f)
      (SET NO_CONVERT))
    (when (option-ref options 'morespace #f)
      (SET MORE_SPACE))
    (let ((q (option-ref options 'quotestr #f)))
      (if q (set! vQuoteStr q)))
    (when (option-ref options 'restricted #f)
      (SET RESTRICTED))
    (when (option-ref options 'smooth #f)
      (SET SMOOTH_SCROLL))
    (let ((tabsizestr (option-ref options 'tabsize #f)))
      (when tabsizestr
        (set! vTabSize (string->number tabsizestr))
        (when (or (not vTabSize)
                  (<= vTabSize 0))
          (format (current-error-port)
                  "Requested tab size \"~A\" is invalid~%"
                  tabsizestr)
          (exit 1))))
    (when (option-ref options 'quickblank #f)
      (SET QUICK_BLANK))
    (when (option-ref options 'version #f)
      (version)
      (exit 0))
    (when (option-ref options 'wordbounds #f)
      (SET WORD_BOUNDS))
    (set! vSyntaxStr (option-ref options 'syntax #f))
    (when (option-ref options 'const #f)
      (SET CONST_UPDATE))
    (when (option-ref options 'rebinddelete #f)
      (SET REBIND_DELETE))
    (when (option-ref options 'autoindent #f)
      (SET AUTOINDENT))
    (when (option-ref options 'cut #f)
      (SET CUT_TO_END))
    (when (option-ref options 'nofollow #f)
      (SET NOFOLLOW_SYMLINKS))
    (when (option-ref options 'mouse #f)
      (SET USE_MOUSE))
    (set! vDirOperating (option-ref options 'operating #f))
    (when (option-ref options 'preserve #f)
      (SET PRESERVE))
    (when (option-ref options 'quiet #f)
      (SET QUIET))
    (let ((w (option-ref options 'fill #f)))
      (when w
        (set! viColWrap (string->number w))
        (when (not viColWrap)
          (format (current-error-port) "Requested fill size \"~s\" is invalid!%"
                  viColWrap)
          (exit 1))
        (set! fFillUsed #t)))
    (set! vSpellerAlt (option-ref options 'speller #f))
    (when (option-ref options 'tempfile #f)
      (SET TEMP_FILE))
    (when (option-ref options 'undo #f)
      (SET UNDOABLE))
    (when (option-ref options 'view #f)
      (SET VIEW_MODE))
    (when (option-ref options 'nowrap #f)
      (SET NO_WRAP)
      (set! fFillUsed #f))
    (when (option-ref options 'nohelp #f)
      (SET NO_HELP))
    (when (option-ref options 'suspend #f)
      (SET SUSPEND))
    (when (option-ref options 'softwrap #f)
      (SET SOFTWRAP))

    ;; If the executable filename starts with 'r', enable restricted mode
    (when (eq? (string-ref (first (command-line)) 0) #\r)
      (SET RESTRICTED))

    ;; If we're using restricted mode, disable suspending, backups, and reading
    ;; rcfiles, since they all would allow reading from or writing to files
    ;; not specified on the command line
    (when (ISSET RESTRICTED)
      (UNSET SUSPEND)
      (UNSET BACKUP_FILE)
      (set! fRcFileEnable #f))

    ;; Usually, we don't wrap when root unless specifically requested
    (when (and (eq? 0 (geteuid))
               (not fFillUsed))
      (SET NO_WRAP))

    ;; If we're using bold text instead of reverse video text, set it up now
    (when (ISSET BOLD_TEXT)
      (set! vAttrReverse A_BOLD))

    ;; Set up the search/replace history
    ;;(InitHistory)
    ;;(when (and fRcFileEnable (ISSET HISTORYLOG))
    ;;  (load-history))

    ;; Set up the backup directory (unless we're using restricted
    ;; mode, in which case backups are disabled, since they would
    ;; allow reading from or writing to files not specified on the
    ;; command line).  This entails making sure it exists and is a
    ;; directory, so that backup files will be saved there.
    (unless (ISSET RESTRICTED)
      (InitBackupDir))

    ;; Set up the operating directory.  This entains chdir'ing there,
    ;; So that the file reads and writes will all be based there
    (InitOperatingDir)

    ;; If punct wasn't specified, set its default value
    (unless vPunct
      (set! vPunct "!.?"))
    ;; If brackets wasn't specified, set its default value
    (unless vBrackets
      (set! vBrackets "\"')>)}"))
    ;; If quotestr wasn't specified, set its default value
    (unless vQuoteStr
      (set! vQuoteStr "^(( \t)*(#:>|}))+"))

    (set! vQuoteReg (make-regexp vQuoteStr regexp/extended))
    ;; We no longer need vQuoteStr, just quotereg
    (set! vQuoteStr #f)

    ;; If we don't have an alternative spell checker after reading
    ;; the command line and/or rcfile(s), check $SPELL for one, as
    ;; Pico does (unless we're using restricted mode, in which case
    ;; spell checking is disabled, since it would allow reading from
    ;; or writing to files not specified on the command line).
    (when (and (not (ISSET RESTRICTED))
               (not vSpellerAlt))
      (let ((spellenv (getenv "SPELL")))
        (when spellenv
          (set! vSpellerAlt spellenv))))

    ;; If matchbrackets wasn't specified, set its default value
    (unless vMatchBrackets
      (set! vMatchBrackets "(<({)>)}"))

    ;; If whitespace wasn't specified, set its default value
    (unless vWhiteSpace
      (set! vWhiteSpace "  ")
      (set! vWhiteSpaceLen '(1 1)))

    ;; If tabsize wasn't specified, set its default value
    (when (= -1 vTabSize)
      (set! vTabSize WIDTH_OF_TAB))

    ;; Set the output terminal.  Normally this is stdin/stdout, but,
    ;; if this is running in guile-ncurses-shell, use that terminal
    ;; instead
    (if (defined? '%guile-ncurses-shell-read-port)
        (set! vTerminalPort %guile-ncurses-shell-read-port)
        ;; else
        (set! vTerminalPort 0))

    ;; Back up the old terminal settings so that they can be restored
    (set! vTermAttr (tcgetattr vTerminalPort))
    ;; (%termios-debug oldterm)

    ;; Initialize curses mode.  If this fails, get out.  Curses may
    ;; already be initialized if this is running in
    ;; guile-ncurses-shell.  In that case, %stdscr will already be
    ;; defined
    (if (defined? '%guile-ncurses-shell-stdscr)
        (set! vWinMain %guile-ncurses-shell-stdscr)
        (set! vWinMain (initscr)))
    (unless vWinMain
      (exit 1))

    ;; Set up the terminal state
    (InitTerminal)

    ;; Turn on the cursor for sure
    (curs-set 1)

    (format (current-error-port) "Main: set up windows~%")

    ;; Initialize all the windows based on the current screen dimensions
    (InitWindow)

    ;; Set up the signal handlers
    ;; (InitSignal)

    ;; Initialize mouse support
    ;; (InitMouse)
    (format (current-error-port) "Main: open file~%")

    ;; Parse the remaining command line options
    (let* ((argv (option-ref options '() '()))
           (argc (length argv))
           (optind 0))

      ;; If there's a +LINE or +LINE,COLUMN flag here, it is the first
      ;; non-option argument, and it is followed by at least one other
      ;; argument, the filename it applies to. */
      (when (and (< 0 optind)
                 (< optind (- argc 1))
                 (eq? (string-ref (list-ref argv optind) 0) #\+))
        (ParseLineColumn (string-drop (list-ref argv optind) 1)
                         rowStart
                         colStart)
        (set! optind (+ optind 1)))

      (when (and (< optind argc)
                 (not (string=? (list-ref argv optind)
                                "-")))
        (stdin_pager)
        (set_modified)
        (set! optind (+ optind 1)))

      (set! fMultibufferSav (ISSET MULTIBUFFER))
      (SET MULTIBUFFER)

      ;; Read all the files after the first one on the command line into
      ;; new buffers
      (let loop ((i (+ optind 1))
                 (iLine 1)
                 (iCol 1))
        (if (< i argc)
            (begin
              ;; If there is a +LINE or +LINE,COLUMN flag here, it is
              ;; followeb by at least one other argument, the filename
              ;; it applies to
              (if (and (< i (- argc 1))
                       (eq? (string-ref (list-ref argv i) 0) #\+)
                       (eq? iLine 1)
                       (eq? iCol 1))
                  (ParseLineColumn (string-drop (list-ref argv i) 1)
                                   iLine iCol)
                  ;; else
                  (begin
                    (OpenBuffer (list-ref argv i) #f)
                    (when (or (> iLine 1)
                              (> iCol 1))
                      (GoToLineColumn iLine iCol #f #f #f #f)
                      (set! iLine 1)
                      (set! iCol 1))))
              (loop (+ i 1)
                    iLine
                    iCol))))


      ;; Read the first file on the command line into either the current buffer
      ;; or a new buffer, depending on whether multibuffer mode is enabled
      (if (< optind argc)
          (OpenBuffer (list-ref argv optind) #f))

      ;; We didn't open any files in all the command line arguements were
      ;; invalid files like directories or if there were no command line
      ;; arguments given.  In this case, we have to load a blank buffer.
      ;; Also, we unset view mode to allow editing
      (when (null? *openfile-list*)
            (format (current-error-port) "load blank buffer~%")
            (OpenBuffer "" #f)
            (UNSET VIEW_MODE))

      (unless fMultibufferSav
        (UNSET MULTIBUFFER))

      (format (current-error-port) "Main: top and bottom win~%")

      #!
      (when (and (openfile-syntax)
                 (> (syntaxtype-nmultis (openfile-syntax)) 0))
        (precalc_multicolorinfo))
      !#
      (when (or (> rowStart 1) (> colStart 1))
        (GoToLineColumn rowStart colStart #f #f #f #f))

      (winio-bottombars MMAIN)
      (DisplayBuffer)

      ;; Run the debug script
      (when (option-ref options 'rundebug #f)
        (primitive-load (option-ref options 'rundebug #f))
        (endwin)
        (tcsetattr! vTerminalPort TCSANOW vTermAttr)
        (exit 0))

      (let ((meta_key #f)
            (ran_func #f)
            (finished #f))
        (while #t
          ;; Make sure cursor is in the edit window
          (winio-reset-cursor)
          (noutrefresh vWinEdit)

          (unless jump_buf_main
            ;; If we haven't already, we're going to set
            ;; jump_buf so that we return here after a
            ;; SIGWINCH.  Indicate this.
            (set! jump_buf_main #t)
            ;; Return here after a sigwinch
            ;;(sigsetjump jump_buf 1)
            )

          ;; Just in case we were at the statusbar prompt, make sure that
          ;; the statusbar cursor position is reset
          ;; (do_prompt_abort)

          ;; If constant cursor position display is on, and there are no
          ;; keys waiting in the input buffer, display the current
          ;; cursor position on the statusbar
          (when (ISSET CONST_UPDATE)
            (do_cursorpos #t))

          (set! vMenuCur MMAIN)

          ;; Read and interpret characters
          (gano-do-input #t)))


      ;; We should never get here
      (error "assertion failed, #f"))))


;; Disable extended input and output processing in our terminal
;; settings.
(define (disable_extended_io)
  (let ((term (tcgetattr vTerminalPort)))
    (termios-lflag-set! term (logand (termios-lflag term)
                                     (lognot IEXTEN)))
    (termios-oflag-set! term (logand (termios-oflag term)
                                     (lognot OPOST)))
    (tcsetattr! vTerminalPort TCSANOW term)
    (%termios-debug term)))

;; Disable interpretation of the special control keys in our terminal
;; settings.
(define (disable_signals)
  (let ((term (tcgetattr vTerminalPort)))
    (termios-lflag-set! term (logand (termios-lflag term)
                                     (lognot ISIG)))
    (tcsetattr! vTerminalPort TCSANOW term)))

;; Enable interpretation of the special control keys in our terminal
;; settings.
(define (enable_signals)
  (let ((term (tcgetattr vTerminalPort)))
    (termios-cflag-set! term (logior (termios-lflag term)
                                     ISIG))
    (tcsetattr! vTerminalPort TCSANOW term)))

;; Disable interpretation of the flow control characters in our terminal
;; settings.
(define (disable_flow_control)
  (let ((term (tcgetattr vTerminalPort)))
    (termios-iflag-set! term (logand (termios-iflag term)
                                     (lognot ISIG)))
    (tcsetattr! vTerminalPort TCSANOW term)))

;; Enable interpretation of the flow control characters in our terminal
;; settings.
(define (enable_flow_control)
  (let ((term (tcgetattr vTerminalPort)))
    (termios-cflag-set! term (logior (termios-cflag term)
                                     IXON))
    (tcsetattr! vTerminalPort TCSANOW term)))

;; Set up the terminal state.  Put the terminal in raw mode (read one
;; character at a time, disable the special control keys, and disable
;; the flow control characters), disable translation of carriage return
;; (^M) into newline (^J) so that we can tell the difference between the
;; Enter key and Ctrl-J, and disable echoing of characters as they're
;; typed.  Finally, disable extended input and output processing, and,
;; if we're not in preserve mode, reenable interpretation of the flow
;; control characters.
(define (InitTerminal)
  #!
  (raw!)
  (nonl!)
  (noecho!)
  (disable_extended_io)
  (when (ISSET PRESERVE)
    (enable_flow_control))
  (disable_signals)
  !#

  #f)

;; Read in a character, interpret it as a shortcut or toggle if
;; necessary, and return it.  Set meta_key to TRUE if the character is
;; a meta sequence, set ran_func to TRUE if we ran a function associated
;; with a shortcut key, and set finished to TRUE if we're done after
;; running or trying to run a function associated with a shortcut key.
;; If allow_funcs is FALSE, don't actually run any functions
;; associated with shortcut keys.
(define (gano-do-input allow_funcs)
  (let ([meta_key #f] [input #f] [ran_func #f] [cut_copy #f] [kbinput #f])

    ;; Read in a character.  get_kbinput returns a qualifier and a key.
    ;; The qualifier is either 'raw or 'meta.  The key is
    ;; either a char or a ncurses keycode.
    (let ([kbinput (input-get-kbinput vWinEdit)])
      (log-debug (format #f "gano-do-input: received kbinput \"~s\"" kbinput))
      (cond
       [(not kbinput)
        ;; no valid input.  We're done
        #f]

       [else
        (let ([qualifier (first kbinput)]
              [input (second kbinput)])
          (set! meta_key (eq? qualifier 'meta))

          ;; Meta keys are not case sensitive
          (when (and meta_key (char? input))
            (set! input (char-downcase input)))

          (log-debug (format #f "gano-do-input: qualifier \"~s\" input \"~s\"" qualifier input))
          ;; Check for a shortcut in the main list
          (let* ([s (winio-get-shortcut MMAIN input meta_key)]
                 ;; If we have a shortcut from the main list, or a
                 ;; "universal" edit window shortcut, set
                 ;; have_shortcut to true
                 [have_shortcut (not (not s))]
                 [funcId (if s (sc-get-function-id s) 0)])

            (log-debug (format #f "gano-do-input: have_shortcut \"~s\" funcId \"~s\"" s funcId))
            ;; If this wasn't a shortcut, and it isn't a regular character, quit
            (unless have_shortcut
              (when (or meta_key (not (char? input)))
                (winio-statusbar "Unknown Command")
                (beep)
                (set! meta_key #f)
                (set! input ERR)))

            (when allow_funcs
              ;; FIXME: view mode processing

              ;; If it is a regular character, output it
              (when (and (not have_shortcut) (not (eq? ERR input)))
                (log-debug (format #f "gano-do-input: dispatch ICP ~s" input))
                (dsp-id-dispatch! 'ICP (openfile-BFS) input)
                (winio-edit-refresh))

              ;; If we got a shortcut or toggle, and it's not the
              ;; shortcut for verbatim input, turn off prepending
              ;; of wrapped text.
              ;; (when (and have_shortcut
              ;;            (not (eq? funcId DO_VERBATIM_INPUT)))
              ;;   (ResetWrap))

              ;; Finally, process the shortcuts
              (when have_shortcut
                ;; Handle the normal edit window shortcuts

                ;; If the function associated with this shortcut is
                ;; cutting or copying text, indicate this.
                (when (member funcId '(DO_CUT_TEXT_VOID DO_COPY_TEXT DO_CUT_TILL_END))
                  (set! cut_copy #t))

                (when (and funcId (not (zero? funcId)))
                  (let ([f funcId])
                    (set! ran_func #t)
                    (cond
                     [(and (ISSET VIEW_MODE) f (not (IsFunctionReadOnly? f)))
                      (print_view_warning)]

                     [else
                      (gano-dispatch vBuffer funcId)])))))))])

    ;; If we aren't cutting or copying text, blow away the text in the
      ;; cutbuffer
      (unless cut_copy
        ;;(cutbuffer_reset)
        #t))))

#!
;; The user typed the character 'CH'.  Add them to the edit buffer,
;; filtering out all ASCII control characters if allow_cntrls is TRUE.
(define (DoOutput c fAllowControls)
  (format (current-error-port) "DoOutput () ~s ~s~%" c fAllowControls)
  (cond
   ((and (not fAllowControls) (IsAsciiControlChar? c))
    ;; do nothing
    (format (current-error-port) "Ignoring control character~%"))
   (else
    DoCharInsert c)))
!#

(define (gano-allow-pending-sigwinch allow)
  "If allow is true, block any SIGWINCH signal that we get, so that we
can deal with them later.  If allow is #f, unblock an SIGWINCH signals
so we can deal with them now."
  ;; FIXME: need sigprocmask primitives
  #f)

;; precalculate the multi-line start and end regex info so we can
;; speed rendering
(define (precalc_multicolorinfo)
  (error "implement me!"))

;; Handle the global toggle
(define (do_toggle flag)
  (TOGGLE flag)
  (cond
   ((= flag USE_MOUSE)
    (InitMouse))
   ((or (= flag MORE_SPACE) (= flag NO_HELP))
    (InitWindow)
    (RefreshAll))
   ((= flag SUSPEND)
    (InitSignal))
   ((= flag WHITESPACE_DISPLAY)
    (winio-titlebar #f)
    (winio-edit-refresh))
   ((= flag NO_COLOR_SYNTAX)
    (winio-edit-refresh))
   ((= flag SOFTWRAP)
    (total_refresh))))

;; Return 1 if the MORE_SPACE flag is set, and 0 otherwise.  This is
;; used to calculate the relative screen position while taking this
;; flag into account, since it adds one line to the edit window.
(define (gano-no-more-space)
  (if (ISSET MORE_SPACE)
      1
      0))

;; Return 2 if the NO_HELP flag is set, and 0 otherwise.  This is used
;; to calculate the relative screen position while taking this flag
;; into account, since it removes two lines from the edit window.
(define (gano-no-help)
  (if (ISSET NO_HELP)
      2
      0))


(define (gano-dispatch buf funcId)
  "Given a function ID, call an API function"
  (log-debug (format #f "gano-dispatch: ~s~%" (GetFuncIdNameFromFuncId funcId)))
  (cond
   ((= funcId DO_ENTER)
    (dsp-id-dispatch! 'INL (openfile-BFS))
    (winio-edit-refresh))
   ((= funcId TOTAL_REFRESH) (DoTotalRefresh buf))
   ((= funcId DO_FIRST_LINE) (DoLineFirst buf))
   ((= funcId DO_LAST_LINE) (DoLineLast buf))
   ((= funcId DO_SCROLL_UP) (DoScrollUp buf))
   ((= funcId DO_SCROLL_DOWN) (DoScrollDown buf))
   ((= funcId DO_UP_VOID) (DoLinePrev buf (ISSET SMOOTH_SCROLL)))
   ((= funcId DO_DOWN_VOID) (DoLineNext buf (ISSET SMOOTH_SCROLL)))
   ((= funcId DO_LEFT) (DoCharPrev buf))
   ((= funcId DO_RIGHT) (DoCharNext buf))
   ((= funcId DO_DELETE) (DoCharDelete buf))
   ((= funcId DO_PAGE_UP) (DoPagePrev buf (ISSET SMOOTH_SCROLL)))
   ((= funcId DO_PAGE_DOWN) (DoPageNext buf (ISSET SMOOTH_SCROLL)))
   ((= funcId DO_END) (DoLineEnd buf))
   ((= funcId DO_HOME) (DoLineBeginning buf))
   ((= funcId DO_BACKSPACE) (DoCharDeleteLeft buf))
   ((= funcId DO_HELP_VOID)
    (DoHelp MMAIN)
    (DoTotalRefresh buf))))
