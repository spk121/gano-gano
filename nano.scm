;;; nano.scm
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

(use-modules
 (gano chars)
 (gano flags)
 (gano files)
 (gano global)
 (gano nano-h)
 (gano winio)
 (gano input)
 (gano utils)
 (gano nano-h)
 (gano text)
 (gano prompt)
 (gano search)
 (gano rcfile)
 (gano cut)
 (gano color)
 (ice-9 getopt-long)
 (ice-9 i18n)
 (ncurses curses)
 (ncurses extra)
 (rnrs control)
 )
(use-syntax (ice-9 syncase))

(define PACKAGE "gano")
(define LOCALEDIR "/usr/local/share/locale")

;; Used to store the user's original mouse click interval
(define oldinterval -1)

;; Should we ignore all rc files?
(define no_rcfiles #f)

;; The user's original terminal settings
(define oldterm #f)
;; A port containing the terminal
(define terminal-port 0)
;; Used to set up all out fun signal handlers
(define act #f)


;; Make a copy of a filestruct node.
(define (copy_node src)
  (if (not src) (error "assertion failed, src != #f"))

  (let ((dst (make-filestruct)))
    (filestruct-data-set! dst (filestruct-data src))
    (filestruct-next-set! dst (filestruct-next src))
    (filestruct-prev-set! dst (filestruct-prev src))
    (filestruct-lineno-set! dst (filestruct-lineno src))
    (filestruct-multidata-set! dst #f)

    dst))

;; Splice a node into an existing filestruct
(define (splice_node begin newnode end)
  (when (not newnode) (error "assertion failed: newnode != #f"))
  (when (not begin) (error "assertion failed: begin != #f"))
  (filestruct-next-set! newnode end)
  (filestruct-prev-set! newnode begin)
  (filestruct-next-set! begin newnode)
  (when end
    (filestruct-prev-set! end newnode)))

;; Unlink a node from the rest of the filestruct
(define (unlink_node fileptr)
  (when (not fileptr) (error "assertion failed: fileptr != #f"))
  (when (filestruct-prev fileptr)
    (filestruct-next-set! (filestruct-prev fileptr) (filestruct-next fileptr)))
  (when (filestruct-next fileptr)
    (filestruct-prev-set! (filestruct-next fileptr) (filestruct-prev fileptr))))

;; Delete a node from the filestruct
(define-syntax delete_node
  (syntax-rules ()
    ((_ fileptr)
     (begin
       (when (not fileptr) (error "assertion failed: fileptr != #f"))
       (when (not (filestruct-data fileptr)) (error "assertion failed: fileptr->data != #f"))
       (when (filestruct-data fileptr)
         (filestruct-data-set! fileptr #f))
       (when (filestruct-multidata fileptr)
         (filestruct-multidata-set! fileptr #f))

       (set! fileptr #f)))))

;; Display a warning about a key disabled in view mode
(define (print_view_warning)
  (statusbar (_ "Key invalid in view mode")))

;; Initialize the three window portions that nano uses.
(define (window_init)
  (set! editwinrows (+ (lines) -5 (no_more_space) (no_help)))
  (when (or (< (cols) MIN_EDITOR_COLS)
            (< editwinrows MIN_EDITOR_ROWS))
    (error (_ "Window size is too small for nano...~%")))

  ;; Set up fill column, based on the screen width
  (set! fill wrap_at)
  (when (<= fill 0)
    (set! fill (+ fill (cols))))
  (when (< fill 0)
    (set! fill 0))


  (when topwin
    (delwin topwin))
  (when edit
    (delwin edit))
  (when bottomwin
    (delwin bottomwin))

  (set! topwin (newwin (- 2 (no_more_space))
                       (cols)
                       0
                       0))
  (set! edit (newwin editwinrows
                     (cols)
                     (- 2 (no_more_space))
                     0))
  (set! bottomwin (newwin (- 3 (no_help))
                          (cols)
                          (+ editwinrows 2 (- (no_more_space)))
                          0))

  ;; Turn on the keypad for the windows, if necessary
  (unless (ISSET REBIND_KEYPAD)
    (keypad! topwin #t)
    (keypad! edit #t)
    (keypad! bottomwin #t)))

;; Print one usage string to the screen.  This cuts down on duplicate
;; strings to translate, and leaves out the parts that shouldn't be
;; translatable (i.e. the flag names).
(define (print_opt shortflag longflag desc)
  (format #t " ~a\t" shortflag)
  (when (< (strlenpt shortflag) 8)
    (format #t "\t"))

  (format #t "~a\t" longflag)
  (cond
   ((< (strlenpt longflag) 8)
    (format #t "\t\t"))
   ((< (strlenpt longflag) 16)
    (format #t "\t")))

  (when desc
    (format #t "~a" desc))

  (format #t "~%"))

;; Explain how to properly use nano's command line options
(define (usage)
  (format #t "Usage: nano [OPTIONS} [[+LINE,COLUMN] FILE]...~%~%")
  (format #t (_ "Option\t\tGNU long option\t\tMeaning~%"))

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

  (print_opt "-u" "--undo" (N_ "Allow generic undo [EXPERIMENTAL]"))

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
  (format #t (_  "GNU nano version ~A (compiled ~A, ~A)~%")
	  "blah" "blah" "blah")
  (format #t " (C) 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007,~%")
  (format #t " 2008, 2009 Free Software Foundation, Inc.~%")
  (format #t (_ " Email: nano@nano-editor.org Web: http://www.nano-editor.org~%"))
  (format #t "~%"))

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

;; Initialize the signal handlers.
(define (signal_init)
  ;; Trap SIGINT and SIGQUIT because we want them to do useful things.
  (sigaction SIGINT SIG_IGN)
  (sigaction SIGQUIT SIG_IGN)

  ;; Trap SIGHUP and SIGTERM because we want to write the file out.
  (sigaction SIGHUP handle_hupterm)
  (sigaction SIGTERM handle_hupterm)

  ;; Trap SIGWINCH because we want to handle window resizes.
  (sigaction SIGWINCH handle_sigwinch)
  (allow_pending_sigwinch #f)

  ;; Trap normal suspend (^Z) so we can handle it ourselves.
  (if (ISSET SUSPEND)
      (sigaction SIGSTOP SIG_IGN)
      ;; else
      ;; Block all other signals in the suspend and continue handlers.
      ;; If we don't do this, other stuff interrupts them!

      ;; FIXME: sigfillset(&act.sa_mask);
      (begin
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
  (move mainwin (- (lines) 1) 0)
  (endwin)

  ;; Display our helpful message.
  (display (_ "Use \"fg\" to return to nano.~%"))
  (force-output)

  ;; Restore the old terminal settings.
  (tcsetattr terminal-port TCSANOW old_terminal)

  ;; Trap SIGHUP and SIGTERM so we can properly deal with them while
  ;; suspended.
  (sigaction SIGHUP handle_hupterm)
  (sigaction SIGTERM handle_hupterm)

  ;; Do what mutt does: send ourselves a SIGSTOP. */
  (kill terminal-port SIGSTOP))

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
  (terminal_init)

  ;; Turn the cursor back on for sure.
  (curs-set 1)

  ;; Redraw the contents of the windows that need it.
  (blank_statusbar)
  (noutrefresh bottomwin)
  (total_refresh)

  )

(define (main args)
  (let* ((optchr #f)
         ;; Line to try and start at
         (startline 1)
         ;; Column to try and start at
         (startcol 1)
         ;; Was the fill option used?
         (fill_used #f)
         ;; The old value of the multibuffer option,
         ;; restored after we load all files on the command
         ;; line
         (old_multibuffer #f)
         (long-options
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
            ))
         (options (getopt-long args long-options))
         (locale (setlocale LC_ALL "")))

    ;; If the locale set exists and uses UTF-8, we should use UTF-8
    (when (and locale
               (string-ci=? (locale-encoding) "UTF-8"))
      (utf8_init))

    (bindtextdomain PACKAGE LOCALEDIR)
    (textdomain PACKAGE)

    (when (option-ref options 'smarthome #f)
      (SET SMART_HOME))
    (when (option-ref options 'backup #f)
      (SET BACKUP_FILE))
    (let ((d (option-ref options 'backupdir #f)))
      (if d (set! backup_dir d)))
    (when (option-ref options 'boldtext #f)
      (SET BOLD_TEXT))
    (when (option-ref options 'tabstospaces #f)
      (SET TABS_TO_SPACES))
    (when (option-ref options 'multibuffer #f)
      (SET MULTIBUFFER))
    (when (option-ref options 'historylog #f)
      (SET HISTORYLOG))
    (when (option-ref options 'ignorercfiles #f)
      (set! no_rcfiles #t))
    (when (option-ref options 'rebindkeypad #f)
      (SET REBIND_KEYPAD))
    (when (option-ref options 'nonewlines #f)
      (SET NO_NEWLINES))
    (when (option-ref options 'noconvert #f)
      (SET NO_CONVERT))
    (when (option-ref options 'morespace #f)
      (SET MORE_SPACE))
    (let ((q (option-ref options 'quotestr #f)))
      (if q (set! quotestr q)))
    (when (option-ref options 'restricted #f)
      (SET RESTRICTED))
    (when (option-ref options 'smooth #f)
      (SET SMOOTH_SCROLL))
    (let ((tabsizestr (option-ref options 'tabsize #f)))
      (when tabsizestr
        (set! tabsizelen (string->number tabsizestr))
        (when (or (not tabsizelen)
                  (<= tabsizelen 0))
          (format (current-error-port)
                  (_ "Requested tab size \"~A\" is invalid~%")
                  tabsizestr)
          (exit 1))))
    (when (option-ref options 'quickblank #f)
      (SET QUICK_BLANK))
    (when (option-ref options 'version #f)
      (version)
      (exit 0))
    (when (option-ref options 'wordbounds #f)
      (SET WORD_BOUNDS))
    (set! syntaxstr (option-ref options 'syntax #f))
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
    (set! operating_dir (option-ref options 'operating #f))
    (when (option-ref options 'preserve #f)
      (SET PRESERVE))
    (when (option-ref options 'quiet #f)
      (SET QUIET))
    (let ((w (option-ref options 'fill #f)))
      (when w
        (set! wrap_at (string->number w))
        (when (not wrap_at)
          (format (current-error-port) "Requested fill size \"~s\" is invalid!%"
                  wrap_at)
          (exit 1))
        (set! fill_used #t)))
    (set! alt_speller (option-ref options 'speller #f))
    (when (option-ref options 'tempfile #f)
      (SET TEMP_FILE))
    (when (option-ref options 'undo #f)
      (SET UNDOABLE))
    (when (option-ref options 'view #f)
      (SET VIEW_MODE))
    (when (option-ref options 'nowrap #f)
      (SET NO_WRAP)
      (set! fill_used #f))
    (when (option-ref options 'nohelp #f)
      (SET NO_HELP))
    (when (option-ref options 'suspend #f)
      (SET SUSPEND))
    (when (option-ref options 'softwrap #f)
      (SET SOFTWRAP))
    ;; If the executable filename starts with 'r', enable restricted mode
    (when (eq? (string-ref (basename (car (command-line))) 0) #\r)
      (SET RESTRICTED))

    ;; If we're using restricted mode, disable suspending, backups, and reading
    ;; rcfiles, since they all would allow reading from or writing to files
    ;; not specified on the command line
    (when (ISSET RESTRICTED)
      (UNSET SUSPEND)
      (UNSET BACKUP_FILE)
      (set! no_rcfiles #t))

    ;; Set up the shortcut lists.  Need to to this before the rcfile.
    (shortcut_init #f)

    ;; We've read through the command line options.  Now back up the
    ;; flags and values that are set, and read the rcfile(s).  If
    ;; the values haven't changed afterward, restore the backed-up
    ;; values.
    (if (not no_rcfiles)
        (let ((operating_dir_cpy operating_dir)
              (wrap_at_cpy wrap_at)
              (backup_dir_cpy backup_dir)
              (quotestr_cpy quotestr)
              (alt_speller_cpy alt_speller)
              (tabsizelen_cpy tabsizelen)
              (flags_cpy (list-copy flags)))
          (begin
            (set! operating_dir #f)
            (set! backup_dir #f)
            (set! quotestr #f)
            (set! alt_speller #f)
            (do_rcfile)
            (format (current-error-port) "After rebinding keys...~%")
            (print_sclist)
            (when operating_dir_cpy
              (set! operating_dir operating_dir_cpy))
            (when fill_used
              (set! wrap_at wrap_at_cpy))
            (when backup_dir_cpy
              (set! backup_dir backup_dir_cpy))
            (when quotestr_cpy
              (set! quotestr quotestr_cpy))
            (when alt_speller_cpy
              (set! alt_speller alt_speller_cpy))
            (unless (= -1 tabsizelen_cpy)
              (set! tabsizelen tabsizelen_cpy))
	    (for-each (lambda (i)
			(list-set! flags i (logior (list-ref flags i)
						   (list-ref flags_cpy i))))
		      (iota 4))
	    ;; else
	    (when (eq? 0 (geteuid))
	      (SET NO_WRAP))
	    )

	  ;; Overwrite an rcfile "set nowrap" or
	  ;; --disable-wrapping-as-root if a --fill option was
	  ;; received on the command line
	  (when fill_used
	    (UNSET NO_WRAP))

	  ;; If we're using bold text instead of reverse video text, set it up now
	  (when (ISSET BOLD_TEXT)
	    (set! reverse_attr A_BOLD))

	  ;; Set up the search/replace history

	  (history_init)
	  (unless (or no_rcfiles
		      (not (ISSET HISTORYLOG)))
	    (load-history))

	  ;; Set up the backup directory (unless we're using
	  ;; restricted mode, in which case backups are disabled,
	  ;; since they would allow reading from or writing to
	  ;; files not specified on the command line).  This
	  ;; entails making sure it exists and is a directory, so
	  ;; that backup files will be saved there.

	  (unless (ISSET RESTRICTED)
	    (init_backup_dir))

	  ;; Set up the operating directory.  This entains chdir'ing there,
	  ;; So that the file reads and writes will all be based there

	  (init_operating_dir)

	  ;; If punct wasn't specified, set its default value
	  (unless punct
	    (set! punct "!.?"))
	  ;; If brackets wasn't specified, set its default value
	  (unless brackets
	    (set! brackets "\"')>]}"))
	  ;; If quotestr wasn't specified, set its default value
	  (unless quotestr
	    (set! quotestr "^([ \t]*[#:>|}])+"))

	  (set! quotereg (make-regexp quotestr regexp/extended))
	  ;; We no longer need quotestr, just quotereg
	  (set! quotestr #f)

	  ;; If we don't have an alternative spell checker after reading
	  ;; the command line and/or rcfile(s), check $SPELL for one, as
	  ;; Pico does (unless we're using restricted mode, in which case
	  ;; spell checking is disabled, since it would allow reading from
	  ;; or writing to files not specified on the command line).
	  (when (and (not (ISSET RESTRICTED))
		     (not alt_speller))
	    (let ((spellenv (getenv "SPELL")))
	      (when spellenv
		(set! alt_speller spellenv))))

	  ;; If matchbrackets wasn't specified, set its default value
	  (unless matchbrackets
	    (set! matchbrackets "(<[{)>]}"))

	  ;; If whitespace wasn't specified, set its default value
	  (unless whitespace
	    (set! whitespace "  ")
	    (set! whitespace_len '(1 1)))

	  ;; If tabsize wasn't specified, set its default value
	  (when (= -1 tabsizelen)
	    (set! tabsizelen WIDTH_OF_TAB))

	  ;; Set the output terminal.  Normally this is stdin/stdout, but,
	  ;; if this is running in guile-ncurses-shell, use that terminal
	  ;; instead
	  (if (defined? '%guile-ncurses-shell-read-port)
	      (set! terminal-port %guile-ncurses-shell-read-port)
	      ;; else
	      (set! terminal-port 0))

	  ;; Back up the old terminal settings so that they can be restored
	  (set! oldterm (tcgetattr terminal-port))
	  ;; (%termios-debug oldterm)

	  ;; Initialize curses mode.  If this fails, get out.  Curses may
	  ;; already be initialized if this is running in
	  ;; guile-ncurses-shell.  In that case, %stdscr will already be
	  ;; defined
	  (if (defined? '%guile-ncurses-shell-stdscr)
	      (set! mainwin %guile-ncurses-shell-stdscr)
	      (set! mainwin (initscr)))
	  (unless mainwin
	    (exit 1))

	  ;; Set up the terminal state
	  (terminal_init)

	  ;; Turn on the cursor for sure
	  (curs-set 1)

	  (format (current-error-port) "Main: set up windows~%")

	  ;; Initialize all the windows based on the current screen dimensions
	  (window_init)

	  ;; Set up the signal handlers
	  ;; (signal_init)

	  ;; Initialize mouse support
	  ;; (mouse_init)
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
	      (parse_line_column (string-drop (list-ref argv optind) 1)
				 startline
				 startcol)
	      (set! optind (+ optind 1)))

	    (when (and (< optind argc)
		       (not (string=? (list-ref argv optind)
				      "-")))
	      (stdin_pager)
	      (set_modified)
	      (set! optind (+ optind 1)))

	    (set! old_multibuffer (ISSET MULTIBUFFER))
	    (SET MULTIBUFFER)

	    ;; Read all the files after the first one on the command line into
	    ;; new buffers
	    (let loop ((i (+ optind 1))
		       (iline 1)
		       (icol 1))
	      (if (< i argc)
		  (begin
		    ;; If there is a +LINE or +LINE,COLUMN flag here, it is
		    ;; followeb by at least one other argument, the filename
		    ;; it applies to
		    (if (and (< i (- argc 1))
			     (eq? (string-ref (list-ref argv i) 0) #\+)
			     (eq? iline 1)
			     (eq? icol 1))
			(parse_line_column (string-drop (list-ref argv i) 1)
					   iline icol)
			;; else
			(begin
			  (open_buffer (list-ref argv i) #f)
			  (when (or (> iline 1)
				    (> icol 1))
			    (do_gotolinecolumn iline icol #f #f #f #f)
			    (set! iline 1)
			    (set! icol 1))))
		    (loop (+ i 1)
			  iline
			  icol))))


	    ;; Read the first file on the command line into either the current buffer
	    ;; or a new buffer, depending on whether multibuffer mode is enabled
	    (if (< optind argc)
		(open_buffer (list-ref argv optind) #f))

	    ;; We didn't open any files in all the command line arguements were
	    ;; invalid files like directories or if there were no command line
	    ;; arguments given.  In this case, we have to load a blank buffer.
	    ;; Also, we unset view mode to allow editing
	    (format (current-error-port) "2614: openfile = ~a~%" (openfile?))
	    (when (not (openfile?))
	      (format (current-error-port) "2614: load blank buffer~%")
	      (open_buffer "" #f)
	      (UNSET VIEW_MODE))

	    (unless old_multibuffer
	      (UNSET MULTIBUFFER))

	    (format (current-error-port) "Main: top and bottom win~%")

#!
	    (when (and (openfile-syntax)
		       (> (syntaxtype-nmultis (openfile-syntax)) 0))
	      (precalc_multicolorinfo))
!#
	    (when (or (> startline 1) (> startcol 1))
	      (do_gotolinecolumn startline startcol #f #f #f #f))

	    (display_main_list)

	    (display_buffer)

	    (let ((meta_key #f)
		  (func_key #f)
		  (s_or_t #f)
		  (ran_func #f)
		  (finished #f))
	      (while #t
		;; Make sure cursor is in the edit window
		(reset_cursor)
		(noutrefresh edit)

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
		(do_prompt_abort)

		;; If constant cursor position display is on, and there are no
		;; keys waiting in the input buffer, display the current
		;; cursor position on the statusbar
		(when (ISSET CONST_UPDATE)
		  (do_cursorpos #t))

		(set! currmenu MMAIN)

		;; Read and interpret characters
		(do_input #t)))


	    ;; We should never get here
	    (error "assertion failed, #f"))))))


;; Disable extended input and output processing in our terminal
;; settings.
(define (disable_extended_io)
  (let ((term (tcgetattr terminal-port)))
    (termios-lflag-set! term (logand (termios-lflag term)
				     (lognot IEXTEN)))
    (termios-oflag-set! term (logand (termios-oflag term)
				     (lognot OPOST)))
    (tcsetattr! terminal-port TCSANOW term)
    (%termios-debug term)))

;; Disable interpretation of the special control keys in our terminal
;; settings.
(define (disable_signals)
  (let ((term (tcgetattr terminal-port)))
    (termios-lflag-set! term (logand (termios-lflag term)
				     (lognot ISIG)))
    (tcsetattr! terminal-port TCSANOW term)))

;; Enable interpretation of the special control keys in our terminal
;; settings.
(define (enable_signals)
  (let ((term (tcgetattr terminal-port)))
    (termios-cflag-set! term (logior (termios-lflag term)
				     ISIG))
    (tcsetattr! terminal-port TCSANOW term)))

;; Disable interpretation of the flow control characters in our terminal
;; settings.
(define (disable_flow_control)
  (let ((term (tcgetattr terminal-port)))
    (termios-iflag-set! term (logand (termios-iflag term)
				     (lognot ISIG)))
    (tcsetattr! terminal-port TCSANOW term)))

;; Enable interpretation of the flow control characters in our terminal
;; settings.
(define (enable_flow_control)
  (let ((term (tcgetattr terminal-port)))
    (termios-cflag-set! term (logior (termios-cflag term)
				     IXON))
    (tcsetattr! terminal-port TCSANOW term)))

;; Set up the terminal state.  Put the terminal in raw mode (read one
;; character at a time, disable the special control keys, and disable
;; the flow control characters), disable translation of carriage return
;; (^M) into newline (^J) so that we can tell the difference between the
;; Enter key and Ctrl-J, and disable echoing of characters as they're
;; typed.  Finally, disable extended input and output processing, and,
;; if we're not in preserve mode, reenable interpretation of the flow
;; control characters.
(define (terminal_init)
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
;; a meta sequence, set func_key to TRUE if the character is a
;; function key, set s_or_t to TRUE if the character is a shortcut or
;; toggle key, set ran_func to TRUE if we ran a function associated
;; with a shortcut key, and set finished to TRUE if we're done after
;; running or trying to run a function associated with a shortcut key.
;; If allow_funcs is FALSE, don't actually run any functions
;; associated with shortcut keys.
(define (do_input allow_funcs)
  (let ((meta_key #f)
	(func_key #f)
	(input #f)
	(s_or_t #f)
	(ran_func #f)
	(finished #f)
	(cut_copy #f)
	(kbinput #f))

    ;; Read in a character
    (let ((input-list (get_kbinput edit)))
      (cond
       ((and input-list (char? input-list))
	(set! input input-list))

       ((and input-list (integer? input-list))
	(set! input input-list)
	(set! func_key #t))

       ((and input-list
	     (list? input-list)
	     (eq? 'meta (car input-list))
	     (char? (cadr input-list)))
	(set! input (char->integer (char-downcase (cadr input-list))))
	(set! meta_key #t))

       ((and input-list
	     (list? input-list)
	     (eq? 'meta (car input-list))
	     (integer? (cadr input-list)))
	(set! input (cadr input-list))
	(set! meta_key #t)
	(set! func_key #t))

       (else
	;; unhandled input type
	(set! input -1)))

      ;; Check for a shortcut in the main list
      (let ((s (get_shortcut MMAIN input meta_key func_key))
	     ;; If we have a shortcut from the main list, or a
	     ;; "universal" edit window shortcut, set have_shortcut
	     ;; to true
	    (have_shortcut #f))
	(set! have_shortcut (not (not s)))
	;; If we got a non-high-bit control key, a meta key sequence,
	;; or a function key, and it's not a shortcut or toggle,
	;; throw it out.
	(unless have_shortcut
	  (when (or (is_ascii_cntrl_char input)
		    meta_key
		    func_key)
	    (statusbar "Unknown Command")
	    (beep)
	    (set! meta_key #f)
	    (set! func_key #f)
	    (set! input ERR)))

	(when allow_funcs
	  ;; If we got a character, and it isn't a shortcut or
	  ;; toggle, it's a normal text character.  Display the
	  ;; warning if we're in view mode, or add the character
	  ;; to the input buffer if we're not.
	  (when (and (not (eq? input ERR))
		     (not have_shortcut))
	    (if (ISSET VIEW_MODE)
		(print_view_warning)
		;; else
		(set! kbinput input)))

	;; If we got a shortcut or toggle, or if there aren't any
	;; other characters waiting after the one we read in, we need
	;; to output all the characters in the input buffer if it
	;; isn't empty.  Note that it should be empty if we're in
	;; view mode
	(when #t
	  ;; If we got a shortcut or toggle, and it's not the
	  ;; shortcut for verbatim input, turn off prepending of
	  ;; wrapped text.
	  (when (and have_shortcut
		     (or (not have_shortcut)
			 (not s)
			 (not (eq? (sc-scfunc s) DO_VERBATIM_INPUT))))
	    (wrap_reset))

	  (when kbinput
	    ;; Display all the characters in the input buffer
	    ;; at once, filtering out control characters.
	    (if (char<? kbinput (integer->char 32))
		(do_output #\nul #f)
		(do_output kbinput #f))))

	(when have_shortcut
	  ;; Handle the normal edit window shortcuts, setting
	  ;; ran_func to TRUE if we try to run their associated
	  ;; functions and setting finished to TRUE to indicate
	  ;; that we're done after running or trying to run their
	  ;; associated functions.

	  ;; FIXME: that'd go here

	  ;; If the function associated with this shortcut is
	  ;; cutting or copying text, indicate this. */
	  (when (or (eq? (sc-scfunc s) DO_CUT_TEXT_VOID)
		    (eq? (sc-scfunc s) DO_COPY_TEXT)
		    (eq? (sc-scfunc s) DO_CUT_TILL_END))
	    (set! cut_copy #t))

	  (when (and (sc-scfunc s) (not (zero? (sc-scfunc s))))
	    (let ((f (sctofunc s)))
	      (set! ran_func #t)
	      (if (and (ISSET VIEW_MODE)
		       f
		       (not (subnfunc-viewok f)))
		  (print_view_warning)
		  ;; else
		  (begin
		    (if (eq? (sc-scfunc s) DO_TOGGLE)
			(do_toggle (sc-scfunc s))
			;; else
			(begin
			  (iso_me_harder_funcmap (sc-scfunc s))
			  (when (and f
				     (not (subnfunc-viewok f))
				     (openfile-syntax)
				     (> (openfile-syntax-nmultis) 0))
			    (reset_multis (openfile-current) #f))
			  (when edit_refresh_needed
			    (edit_refresh)
			    (set! edit_refresh_needed #f)))))))
	  (set! finished #t))))


	;; If we aren't cutting or copying text, blow away the text in the
	;; cutbuffer
	(unless cut_copy
	  (cutbuffer_reset))

      input))))


;; The user typed output_len multibyte characters.  Add them to the edit
;; buffer, filtering out all ASCII control characters if allow_cntrls is
;; TRUE.
(define (do_output c allow_controls?)
  (let ((orig_lenpt (strlenpt (openfile-current-data))))
    (cond

     ;; C is null
     ((and allow_controls? (char=? c #\newline))
      (do_enter #f))

     ((and (not allow_controls?) (is_ascii_cntrl_char c))
      ;; do nothing
      #f)

     (else
      ;; Output it:  yeah!

      (when (char=? c #\nul)
	(set! c #\newline))

      ;; If the NO_NEWLINES flag isn't set, when a character is added to
      ;; the magicline, it means we need a new magicline.
      (when (and (not (ISSET NO_NEWLINES))
		 (= (openfile-current_index) (1- (length (openfile-fileage)))))
	(new_magicline))

      ;; Insert that char
      (format (current-error-port)
	      "before current-index ~s~%" (openfile-current_index))
      (format (current-error-port)
	      "before current-data ~s~%" (openfile-current-data))
      (format (current-error-port)
	      "before current-x ~s~%" (openfile-current_x))
      (format (current-error-port)
	      "before c ~s~%" c)
      (format (current-error-port)
	      "before totsize ~s~%" (openfile-totsize))

      (openfile-current-data-set!
       (string-append (substring (openfile-current-data) 0 (openfile-current_x))
		      (string c)
		      (substring (openfile-current-data) (openfile-current_x))))
      (openfile-totsize-set! (1+ (openfile-totsize)))
      (set_modified)


      ;; (update_undo ADD)

      ;; Note that current_x has not yet been incremented
      (when (and (openfile-mark_set)
		 (eq? (openfile-mark_begin_index) (openfile-current_index))
		 (< (openfile-current_x) (openfile-mark_begin_x)))
	(openfile-mark_begin_x-set! (1+ (openfile-mark_begin_x))))

      (openfile-current_x-set! (1+ (openfile-current_x)))
      (format (current-error-port)
	      "after current-index ~s~%" (openfile-current_index))
      (format (current-error-port)
	      "after current-data ~s~%" (openfile-current-data))
      (format (current-error-port)
	      "after current-x ~s~%" (openfile-current_x))
      (format (current-error-port)
	      "after c ~s~%" c)
      (format (current-error-port)
	      "after totsize ~s~%" (openfile-totsize))

      ;; If we're wrapping text, we need to call edit_refresh
      ;;(unless (ISSET NO_WRAP)
	;;(when (do_wrap (openfile-current_index) #f)
	 ;; (set! edit_refresh_needed #t)))

      ;; If color syntaxes are available and turned on, call
      ;; edit_refresh
      (when (and (openfile-colorstrings)
		 (not (ISSET NO_COLOR_SYNTAX)))
	(set! edit_refresh_needed #t))

      ;; Well we might also need a full refresh if we've changed the
      ;; line length to be a new multiple of COLS
      (when (and (ISSET SOFTWRAP)
		 (not edit_refresh_needed)
		 (not (= (quotient (strlenpt (openfile-current-data)) (cols))
			 (quotient orig_lenpt (cols)))))
	(set! edit_refresh_needed #t))

      (openfile-placewewant-set! (xplustabs))

      #!
      #ifdef ENABLE_COLOR
      reset_multis(openfile->current, FALSE);
      #endif
      !#

      (if edit_refresh_needed
	  (begin
	    (edit_refresh)
	    (set! edit_refresh_needed #f))
	  ;;
	  (update_line (openfile-current_index) (openfile-current_x)))))))

(define (allow_pending_sigwinch allow)
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
    (mouse_init))
   ((or (= flag MORE_SPACE) (= flag NO_HELP))
    (window_init)
    (total_refresh))
   ((= flag SUSPEND)
    (signal_init))
   ((= flag WHITESPACE_DISPLAY)
    (titlebar #f)
    (edit_refresh))
   ((= flag NO_COLOR_SYNTAX)
    (edit_refresh))
   ((= flag SOFTWRAP)
    (total_refresh))))