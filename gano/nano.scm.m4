m4_include(`config.m4')

(use-modules 
 (gano chars)
 (gano global)
 (gano nano-h)
 (ice-9 getopt-long)
 (ice-9 i18n)
 (rnrs control)
 )
(use-syntax (ice-9 syncase))

m4_ifdef({DISABLE_MOUSE},{},
         {
          ;; Used to store the user's original mouse click interval
          (define oldinterval 1)
          })

m4_ifdef({ENABLE_NANORC},
         {
          ;; Should we ignore all rc files?
          (define no_rcfiles #f)
          })

;; The user's original terminal settings
(define oldterm #f)
;; Used to set up all out fun signal handlers
(define act #f)

;; Create a new filestruct node.  Note that we do not set prevnode->next
;; to the new line
(define (make_new_node prevnode)
  (let ((newnode (make-filestruct)))
    (filestruct-data-set! newnode #f)
    (filestruct-prev-set! newnode prevnode)
    (filestruct-next-set! newnode #f)
    (filestruct-lineno-set! newnode (if prevnode 
                                        (+ 1 (filestruct-lineno prev))
                                        1))
    m4_ifdef({ENABLE_COLOR},{
    (filestruct-multidata-set! newnode #f)
    })
    newnode))

;; Make a copy of a filestruct node.
(define (copy_node src)
  (if (not src) (error "assertion failed, src != #f"))
  
  (let ((dst (make-filestruct)))
    (filestruct-data-set! dst (string-copy (filestruct-data src)))
    (filestruct-next-set! dst (filestruct-next src))
    (filestruct-prev-set! dst (filestruct-prev src))
    (filestruct-lineno-set! dst (filestruct-lineno src))
    m4_ifdef({ENABLE_COLOR},{
    (filestruct-multidata-set! dst #f)
    })
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
       m4_ifdef({ENABLE_COLOR},{
       (when (filestruct-multidata fileptr)
       (filestruct-multidata-set! fileptr #f))
       })
       (set! fileptr #f)))))
  
;; Display a warning about a key disabled in view mode
(define (print_view_warning)
  (statusbar (_ "Key invalid in view mode")))

;; Explain how to properly use nano's command line options
(define (usage)
  (format #t "Usage: nano [OPTIONS} [[+LINE,COLUMN] FILE]...~%~%")
  m4_ifdef({HAVE_GETOPT_LONG}, 
           {
            (format #t (_ "Option\t\tGNU long option\t\tMeaning\n"))
            },
           {
            (format #t (_ "Option\t\tMeaning~%"))
            })
  (print-opt "-h, -?" "--help" (N_ "Show this message"))
  (print-opt (_ "+LINE,COLUMN") "" (N_ "Start at line LINE, column COLUMN"))
  m4_ifdef({NANO_TINY},{},
           {
            (print-opt "-A" "--smarthome" (N_ "Enable smart home key"))
            (print-opt "-B" "--backup", (N_ "Save backups of existing files"))
            (print-opt (_ "-C <dir>") (_ "--backupdir=<dir>") 
                       (N_ "Directory for saving unique backup files"))
            })
  (print-opt "-D" "--boldtext" (N_ "Use bold instead of reverse video text"))
  m4_ifdef({NANO_TINY},{},
           {
            (print-opt "-E" "--tabstospaces" (N_ "Convert typed tabs to spaces"))
            })
  m4_ifdef({ENABLE_MULTIBUFFER},
           {
            (print-opt "-F" "--multibuffer" (N_ "Enable multiple file buffers"))
            })
  m4_ifdef({ENABLE_NANORC},
           {
            m4_ifdef({NANO_TINY},{},
                     {
                      (print-opt "-H" "--historylog" (N_ "Log & read search/replace string history"))
                      })
                    (print-opt "-I" "--ignorercfiles" (N_ "Don't look at nanorc files"))
                    })
  (print-opt "-K" "--rebindkeypad" (N_ "Fix numeric keypad key confusion problem"))
  (print-opt "-L" "--nonewlines" (N_ "Don't add newlines to the ends of files"))
  m4_ifdef({ENABLE_NANORC},{},
           {
            (print-opt "-N" "--noconvert" (N_ "Don't convert files from DOS/Mac format"))
            })
  (print_opt "-O" "--morespace" (N_ "Use one more line for editing"))
  m4_ifdef({DISABLE_JUSTIFY},{},
           {
            (print-opt (_ "-Q <str>") (_ "--quotestr=<str>") (N_ "Quoting string"))
            })
  (print-opt "-R" "--restricted" (N_ "Restricted mode"))
  m4_ifdef({NANO_TINY},{},
           {
            (print-opt "-S" "--smooth" (N_ "Scroll by line instead of half-screen"))
            })
  (print-opt (_ "-T <#cols>") (_ "--tabsize=<#cols>") (N_ "Set width of a tab to #cols columns"))
  m4_ifdef({NANO_TINY},{},
           {
            (print-opt "-U" "--quickblank" (N_ "Do quick statusbar blanking"))
            })
  (print-opt "-V" "--version" (N_ "Print version information and exit"))
  m4_ifdef({NANO_TINY},{},
           {
            (print-opt "-W" "--wordbounds" (N_ "Detect word boundaries more accurately"))
            })
  m4_ifdef({ENABLE_COLOR},{
  (print-opt (_ "-Y <str>") (_ "--syntax=<str>") (N_ "Syntax definition to use for coloring"))
  })
  (print-opt "-c" "--const" (N_ "Constantly show cursor position"))
  (print-opt "-d" "--rebinddelete" (N_ "Fix Backspace/Delete confusion problem"))
  m4_ifdef({NANO_TINY},{},
           {
            (print-opt "-i" "--autoindent" (N_ "Automatically indent new lines"))
            (print-opt "-k" "--cut" (N_ "Cut from cursor to end of line"))
            })
  (print-opt "-l" "--nofollow" (N_ "Don't follow symbolic links, overwrite"))
  m4_ifdef({DISABLE_MOUSE},{},
           {
            (print-opt "-m" "--mouse" (N_ "Enable the use of the mouse"))
            })
  m4_ifdef({DISABLE_OPERATINGDIR},{},
           {
            (print-opt (_ "-o <dir>") (_"--operatingdir=<dir>") (N_ "Set operating directory"))
            })
  (print-opt "-p" "--preserve" (N_ "Preserve XON (^Q) and XOFF (^S) keys"))
  (print-opt "-q" "--quiet" (N_ "Silently ignore startup issues like rc file errors"))
  m4_ifdef({DISABLE_WRAPJUSTIFY},{},
           {
            (print-opt (_ "-r <#cols>") (_ "--fill=<#cols>") (N_ "Set wrapping point at column #cols"))
            })
  m4_ifdef({DISABLE_SPELLER},{},
           {
            (print-opt (_ "-s <prog>") (_ "--speller=<prog>") (N_ "Enable alternate speller"))
            })
  (print-opt "-t" "--tempfile" (N_ "Auto save on exit, don't prompt"))
  m4_ifdef({NANO_TINY},{},
           {
            (print-opt "-u" "--undo" (N_ "Allow generic undo [EXPERIMENTAL]"))
            })
  (print-opt "-v" "--view" (N_ "View mode (read-only)"))
  m4_ifdef({DISABLE_WRAPPING},{},
           {
            (print-opt "-w" "--nowrap" (N_ "Don't wrap long lines"))
            })
  (print-opt "-x" "--nohelp" (N_ "Don't show the two help lines"))
  (print-opt "-z" "--suspend" (N_ "Enable suspension"))
  (print-opt "-$" "--softwrap" (N_ "Enable soft line wrapping"))
  
  ;;
  (print-opt "-a, -b, -e," "" #f)
  (print-opt "-f, -g, -j" "" (N_ "(ignored, for Pico compatibility)"))
  (exit 0))

;; Display the current version of nano, the date and time it was
;; compiled, contact information for it, and the configuration options
;; it was compiled with.
(define (version)
  (format #t (_  "GNU nano version ~A (compiled ~A, ~A)~%"
                 m4_version
                 m4_syscmd({date +"\"%H:%M:%S\""}) 
                 m4_syscmd({date +"\"%x\""})
                 ))
  (format #t " (C) 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007,~%")
  (format #t " 2008, 2009 Free Software Foundation, Inc.~%")
  (format #t (_ " Email: nano@nano-editor.org Web: http://www.nano-editor.org~%"))
  (format #t (_ "Compiled options:"))
  
  m4_ifdef({DISABLE_BROWSER},
           {
            (format #t " --disable-browser")
            })
  m4_ifdef({DISABLE_HELP},
           {
            (format #t " --disable-help")
            })
  m4_ifdef({DISABLE_JUSTIFY},
           {
            (format #t " --disable-justify")
            })
  m4_ifdef({DISABLE_MOUSE},
           {
            (format #t " --disable-mouse")
            })
  m4_ifdef({ENABLE_NLS},{},
           {
            (format #t " --disable-nls")
            })
  m4_ifdef({DISABLE_OPERATINGDIR},
           {
            (format #t " --disable-operatingdir")
            })
  m4_ifdef({DISABLE_SPELLER},
           {
            (format #t " --disable-speller")
            })
  m4_ifdef({DISABLE_TABCOMP},
           {
            (format #t " --disable-tabcomp")
            })
  m4_ifdef({DISABLE_WRAPPING},
           {
            (format #t " --disable-wrapping")
            })
  m4_ifdef({DISABLE_ROOTWRAPPING},
           {
            (format #t " --disable-wrapping-as-root")
            })
  m4_ifdef({ENABLE_COLOR},{
  (format #t " --enable-color")
  })
  m4_ifdef({DEBUG},
           {
            (format #t " --enable-debug")
            })
  m4_ifdef({NANO_EXTRA},
           {
            (format #t " --enable-extra")
            })
  m4_ifdef({ENABLE_MULTIBUFFER},
           {
            (format #t " --enable-multibuffer")
            })
  m4_ifdef({ENABLE_NANORC},
           {
            (format #t " --enable-nanorc")
            })
  m4_ifdef({NANO_TINY},
           {
            (format #t " --enable-tiny")
            })
  m4_ifdef({ENABLE_UTF8},
           {
            (format #t " --enable-utf8")
            })
  m4_ifdef({USE_SLANG},
           {
            (format #t " --with-slang")
            })
  (format #t "~%"))

(define (main args)
  (let* ((optchr #f)
         ;; Line to try and start at
         (startline 1)
         ;; Column to try and start at
         (startcol 1)
         m4_ifdef({DISABLE_WRAPJUSTIFY},{},{
         ;; Was the fill option used?
         (fill_used #f)})
         m4_ifdef({ENABLE_MULTIBUFFER},{
         ;; The old value of the multibuffer option,
         ;; restored after we load all files on the command
         ;; line
         (old_multibuffer #f)   
         })
         ;; m4_ifdef({HAVE_GETOPT_LONG},
         ;;       {
         (long-options 
          '((help (single-char #\h) (value #f))
            (boldtext (single-char #\D) (value #f))
            m4_ifdef({ENABLE_MULTIBUFFER},{
            (multibuffer (single-char #\F) (value #f))
            })
            m4_ifdef({ENABLE_NANORC},{
            (ignorercfiles (single-char #\I) (value #f))
            })
            (rebindkeypad (single-char #\K) (value #f))
            (nonewlines (single-char #\L) (value #f))
            (morespace (single-char #\O) (value #f))
            m4_ifdef({DISABLE_JUSTIFY},{},{
            (quotestr (single-char #\Q) (value #t))
            })
            (restricted (single-char #\R) (value #f))
            (tabsize (single-char #\T) (value #t))
            (version (single-char #\V) (value #f))
            m4_ifdef({ENABLE_COLOR},{
            (syntax (single-char #\Y) (value #t))
            })
            (const (single-char #\c) (value #f))
            (rebinddelete (single-char #\d) (value #f))
            (nofollow (single-char #\l) (value #f))
            m4_ifdef({DISABLE_MOUSE},{},{
            (mouse (single-char #\m) (value #f))
            })
            m4_ifdef({DISABLE_OPERATINGDIR},{},{
            (operatingdir (single-char #\o) (value #t))
            })
            (preserve (single-char #\p) (value #f))
            (quiet (single-char #\q) (value #f))
            m4_ifdef({DISABLE_WRAPJUSTIFY},{},{
            (fill (single-char #\r) (value #t))
            })
            m4_ifdef({DISABLE_SPELLER},{},{
            (speller (single-char #\s) (value #t))
            })
            (tempfile (single-char #\t) (value #f))
            (view (single-char #\v) (value #f))
            m4_ifdef({DISABLE_WRAPPING},{},{
            (nowrap (single-char #\w) (value #f))
            })
            (nohelp (single-char #\x) (value #f))
            (suspend (single-char #\z) (value #f))
            m4_ifdef({NANO_TINY},{},{
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
            })
            ))
         (options (getopt-long args long-options))
    ;; })
         (locale (setlocale LC_ALL "")))
    m4_ifdef({ENABLE_UTF8},{
    ;; If the locale set exists and uses UTF-8, we should use UTF-8
    (when (and locale
               (string-ci=? (locale-encoding) "UTF-8"))
          m4_ifdef({USE_SLANG},{
          (SLutf8_enable 1)
          })
          (utf8_init))
    })
    m4_ifdef({ENABLE_NLS},{
    (bindtextdomain PACKAGE LOCALEDIR)
    (textdomain PACKAGE)
    })
    m4_ifdef({ENABLE_NANORC},{},{
    m4_ifdef({DISABLE_ROOTWRAPPING},{
    ;; If we don't have rcfile support, --disable-wrapping-as-root is
    ;; used, and we're root, then turn wrapping off
    (when (= NANO_ROOT_ID (geteuid))
          (SET NO_WRAP))
    })
    })

    m4_ifdef({NANO_TINY},{},{
    (when (option-ref options 'smarthome #f)
          (SET SMART_HOME))
    (when (option-ref options 'backup #f)
          (SET BACKUP_FILE))
    (let ((d (option-ref options 'backupdir #f)))
      (if d (set! backup_dir (option-ref options 'backupdir))))
    })
    (when (option-ref options 'boldtext #f)
          (SET BOLD_TEXT))
    m4_ifdef({NANO_TINY},{},{
    (when (option-ref options 'tabstospaces #f)
          (SET TABS_TO_SPACES))
    })
    m4_ifdef({ENABLE_MULTIBUFFER},{
    (when (option-ref options 'multibuffer #f)
          (SET MULTIBUFFER))
    })
    m4_ifdef({ENABLE_NANORC},{
    m4_ifdef({NANO_TINY},{},{
    (when (option-ref options 'historylog #f)
          (SET HISTORYLOG))
    })
    (when (option-ref options 'ignorercfiles #f)
          (set! no_rcfiles #t))
    })
    (when (option-ref options 'rebindkeypad #f)
          (SET REBIND_KEYPAD))
    (when (option-ref options 'nonewlines #f)
          (SET NO_NEWLINES))
    m4_ifdef({NANO_TINY},{},{
    (when (option-ref options 'noconvert #f)
          (SET NO_CONVERT))
    })
    (when (option-ref options 'morespace #f)
          (SET MORE_SPACE))
    m4_ifdef({DISABLE_JUSTIFY},{},{
    (let ((q (option-ref options 'quotestr #f)))
      (if q (set! quotestr q)))
    })
    (when (option-ref options 'restricted #f)
          (SET RESTRICTED))
    m4_ifdef({NANO_TINY},{},{
    (when (option-ref options 'smooth #f)
          (SET SMOOTH_SCROLL))
    })
    (let ((tabsizestr (option-ref options 'tabsize #f)))
      (when tabsizestr
            (set! tabsize (string->number tabsizestr))
            (when (or (not tabsize)
                      (<= tabsize 0))
                  (format (current-error-port) 
                          (_ "Requested tab size \"~A\" is invalid~%")
                          tabsizestr)
                  (exit 1))))
    m4_ifdef({NANO_TINY},{},{
    (when (option-ref options 'quickblank #f)
          (SET QUICK_BLANK))
    })
    (when (option-ref options 'version #f)
          (version)
          (exit 0))
    m4_ifdef({NANO_TINY},{},{
    (when (option-ref options 'wordbounds #f)
          (SET WORD_BOUNDS))
    })
    m4_ifdef({ENABLE_COLOR},{
    (set! syntaxstr (option-ref options 'syntax #f))
    })
    (when (option-ref options 'const #f)
          (SET CONST_UPDATE))
    (when (option-ref options 'rebinddelete #f)
          (SET REBIND_DELETE))
    m4_ifdef({NANO_TINY},{},{
    (when (option-ref options 'autoindent #f)
          (SET AUTOINDENT))
    (when (option-ref options 'cut #f)
          (SET CUT_TO_END))
    })
    (when (option-ref options 'nofollow #f)
          (SET NOFOLLOW_SYMLINKS))
    m4_ifdef({DISABLE_MOUSE},{},{
    (when (option-ref options 'mouse #f)
          (SET USE_MOUSE))
    })
    m4_ifdef({DISABLE_OPERATINGDIR},{},{
    (set! operating_dir (option-ref options 'operating #f))
    })
    (when (option-ref options 'preserve #f)
          (SET PRESERVE))
    (when (option-ref options 'quiet #f)
          (SET QUITE))
    m4_ifdef({DISABLE_WRAPJUSTIFY},{},{
    (let ((w (option-ref options 'fill #f)))
      (when w
            (set! wrap_at (string->number w))
            (when (not wrap_at)
                  (format (current-error-port) "Requested fill size \"~s\" is invalid!%"
                          wrap_at)
                  (exit 1))
            (set! fill_used #t)))
    })
    m4_ifdef({DISABLE_SPELLER},{},{
    (set! alt_speller (option-ref options 'speller #f))
    })
    (when (option-ref options 'tempfile #f)
          (SET TEMP_FILE))
    m4_ifdef({NANO_TINY},{},{
    (when (option-ref options 'undo #f)
          (SET UNDOABLE))
    })
    (when (option-ref options 'view #f)
          (SET VIEW_MODE))
    m4_ifdef({DISABLE_WRAPPING},{},{
    (when (option-ref options 'nowrap #f)
          (SET NO_WRAP)
          (set! fill_used #f))
    })
    (when (option-ref options 'nohelp #f)
          (SET NO_HELP))
    (when (option-ref options 'suspend #f)
          (SET SUSPEND))
    m4_ifdef({NANO_TINY},{},{
    (when (option-ref options 'softwrap #f)
          (SET SOFTWRAP))
    })
    ;; If the executable filename starts with 'r', enable restricted mode
    (when (eq? (string-ref (basename (car (command-line))) 0) #\r)
          (SET RESTRICTED))
  
    ;; If we're using restricted mode, disable suspending, backups, and reading
    ;; rcfiles, since they all would allow reading from or writing to files
    ;; not specified on the command line
    (when (ISSET RESTRICTED)
          (UNSET SUSPEND)
          (UNSET BACKUP_FILE)
          m4_ifdef({ENABLE_NANORC},{
          (set! no_rcfiles #t)
          }))
  
  
    ;; Set up the shortcut lists.  Need to to this before the rcfile.
    (shortcut_init #f)
    
    ;; We've read through the command line options.  Now back up the
    ;; flags and values that are set, and read the rcfile(s).  If
    ;; the values haven't changed afterward, restore the backed-up
    ;; values.
    m4_ifdef({ENABLE_NANORC},{
    (if (not no_files)
        (let (
              m4_ifdef({DISABLE_OPERATINGDIR},{},{
              (operating_dir_cpy (string-copy operating_dir))
              })
              m4_ifdef({DISABLE_WRAPJUSTIFY},{},{
              (wrap_at_cpy wrap_at)
              })
              m4_ifdef({NANO_TINY},{},{
              (backup_dir_cpy backup_dir)
              })
              m4_ifdef({DISABJE_JUSTIFY},{},{
              (quotestr_cpy quotestr)
              })
              m4_ifdef({DISABLE_SPELLER},{},{
              (alt_speller_cpy alt_speller)
              })
              (tabsize_cpy tabsize)
              (flags_cpy (list-copy flags)))
          (begin
            m4_ifdef({DISABLE_OPERATINGDIR},{},{
            (set! operating_dir #f)
            })
            m4_ifdef({NANO_TINY},{},{
            (set! backup_dir #f)
            })
            m4_ifdef({DISABLE_JUSTIFY},{},{
            (set! quotestr #f)
            })
            m4_ifdef({DISABLE_SPELLER},{},{
            (set! alt_speller #f)
            })
            (do_rcfile)
            m4_ifdef({DEBUG},{
            (format (current-error-port) "After rebinding keys...~%")
            (print_sclist)
            })
            m4_ifdef({DISABLE_OPERATINGDIR},{},{
            (when operating_dir_cpy
                  (set! operating_dir operating_dir_cpy))
            })
            m4_ifdef({DISABLE_WRAPJUSTIFY},{},{
            (when fill_used
                  (set! wrap_at wrap_at_cpy))
            })
            m4_ifdef({NANO_TINY},{},{
            (when backup_dir_cpy
                  (set! backup_dir backup_dir_cpy))
            })
            m4_ifdef({DISABLE_JUSTIFY},{},{
            (when quotestr_cpy
                  (set! quotestr quotestr_cpy))
            })
            m4_ifdef({DISABLE_SPELLER},{},{
            (when alt_speller_cpy
                  (set! alt_speller alt_speller_cpy))
            })
            (unless (= -1 tabsize_cpy)
                    (set! tabsize tabsize_cpy))
            (let loop ((i 0))
              (list-set! flags i (logior (list-ref flags i)
                                         (list-ref flags_cpy i)))
              (when (< i 4)
                    (loop (+ i 1))))))
        m4_ifdef({DISABLE_ROOTWRAPPING},{
        ;; else
        (when (eq? NANO_ROOT_ID (geteuid))
              (SET NO_WRAP))
        })
        )
    })
  
    m4_ifdef({DISABLE_WRAPPING},{},{
    ;; Overwrite an rcfile "set nowrap" or
    ;; --disable-wrapping-as-root if a --fill option was
    ;; received on the command line
    (when fill_used 
          (UNSET NO_WRAP))
    })

    ;; If we're using bold text instead of reverse video text, set it up now
    (when (ISSET BOLD_TEXT)
          (set! reverse_attr A_BOLD))
    
    m4_ifdef({NANO_TINY},{},{
    ;; Set up the search/replace history
    (history-init)
    m4_ifdef({ENABLE_NANORC},{
    (unless (or no_rcfiles
                (not (ISSET HISTORYLOG)))
            (load-history))
    })
    })
    m4_ifdef({NANO_TINY},{},{
    ;; Set up the backup directory (unless we're using
    ;; restricted mode, in which case backups are disabled,
    ;; since they would allow reading from or writing to
    ;; files not specified on the command line).  This
    ;; entails making sure it exists and is a directory, so
    ;; that backup files will be saved there.
    (unless (ISSET RESTRICTED)
            (init_backup_dir))
    })

    m4_ifdef({DISABLE_OPERATINGDIR},{},{
    ;; Set up the operating directory.  This entains chdir'ing there,
    ;; So that the file reads and writes will all be based there
    (init-operating-dir)
    })
  
    m4_ifdef({DISABLE_JUSTIFY},{},{
    ;; If punct wasn't specified, set its default value
    (unless punct
            (set! punct "!.?"))
    ;; If brackets wasn't specified, set its default value
    (unless brackets
            (set! brackets "\"')>]\x7D"))
    ;; If quotestr wasn't specified, set its default value
    (unless quotestr
            (set! quotestr
                  m4_ifdef({HAVE_REGEX_H},
                           {"^([ \t]*[#:>|\x7D])+"},
                           {"> "})))
    m4_ifdef({HAVE_REGEX_H},{
    (set! quoterc (regcomp quotereg quotestr REG_EXTENDED))
    (if (not quoterc)
        ;; We no longer need quotestr, just quotereg
        (set! quotestr #f)
        ;;else
        (regerror))},
             {(set! quotelen (string-length quotestr))})
    })

    m4_ifdef({DISABLE_SPELLER},{},{
    ;; If we don't have an alternative spell checker after reading
    ;; the command line and/or rcfile(s), check $SPELL for one, as
    ;; Pico does (unless we're using restricted mode, in which case
    ;; spell checking is disabled, since it would allow reading from
    ;; or writing to files not specified on the command line).
    (when (and (not (ISSET RESTRICTED))
               (not alt_speller))
          (let ((spellenv (getenv "SPELL")))
            (when spellenv
                  (set! alt_speller (string-copy spellenv)))))
    })

    m4_ifdef({NANO_TINY},{},{
    ;; If matchbrackets wasn't specified, set its default value
    (unless matchbrackets
            (set! matchbrackets "(<[{)>]}"))
    })
    m4_ifdef({NANO_TINY},{},{
    m4_ifdef({ENABLE_NANORC},{
    ;; If whitespace wasn't specified, set its default value
    (unless whitespace
            (set! whitespace "  ")
            (set! whitespace_len '(1 1)))
    })
    })
    
    ;; If tabsize wasn't specified, set its default value
    (when (= -1 tabsize)
          (set! tabsize WIDTH_OF_TAB))
  
    ;; Back up the old terminal settings so that they can be restored
    (set! oldterm (tcgetattr 0))
    
    ;; Initialize curses mode.  If this fails, get out. 
    (define! stdscr (initscr))
    (unless stdscr
            (exit 1))
    
    ;; Set up the terminal state
    (terminal_init)
    
    ;; Turn on the cursor for sure
    (curs-set 1)
    
    m4_ifdef({DEBUG},{
    (format (current-error-port) "Main: set up windows~%")
    })
  
    ;; Initialize all the windows based on the current screen dimensions
    (window_init)
    
    ;; Set up the signal handlers
    (signal_init)
  
    m4_ifdef({DISABLE_MOUSE},{},{
    ;; Initialize mouse support
    (mouse_init)
    })
  
    m4_ifdef({DEBUG},{
    (format (current-error-port) "Main: open file~%")
    })
  
    ;; Parse the remaining command line options
    (let* ((argv (options-ref options '()))
           (argc (length optarg))
           (optind 0))
      
      ;; If there's a +LINE or +LINE,COLUMN flag here, it is the first
      ;; non-option argument, and it is followed by at least one other
      ;; argument, the filename it applies to. */
      (when (and (< 0 optind)
                 (< optind (- argc 1))
                 (eq? (string-ref (list-ref argv optind) ) #\+))
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
      
      m4_ifdef({ENABLE_MULTIBUFFER},{
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
                    (open_buffer (list-ref argv i))
                    (when (or (> iline 1)
                              (> icol 1))
                          (do_gotolinecolumn iline icol #f #f #f #f)
                          (set! iline 1)
                          (set! icol 1))))
              (loop (+ i 1)
                    iline
                    icol))))
      })
    
    
      ;; Read the first file on the command line into either the current buffer
      ;; or a new buffer, depending on whether multibuffer mode is enabled
      (if (< optind argc)
          (open_buffer (list-ref argv optind) #f))
      
      ;; We didn't open any files in all the command line arguements were
      ;; invalid files like directories or if there were no command line
      ;; arguments given.  In this case, we have to load a blank buffer.
      ;; Also, we unset view mode to allow editing
      (when (not openfile)
            (open_buffer "" #f)
            (UNSET VIEW_MODE))
      
      m4_ifdef({ENABLE_MULTIBUFFER},{
      (unless old_multibuffer
              (UNSET MULTIBUFFER))
      })
      
      m4_ifdef({DEBUG},{
      (format (current-error-port) "Main: top and bottom win~%")
      })
    
      m4_ifdef({ENABLE_COLOR},{
      (when (and (filestruct-syntax openfile)
                 (> (syntax-nmultis (filestruct-syntax openfile) 0)))
            (precalc_multicolorinfo))
      })
    
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
               (wnoutrefresh edit)
               
               m4_ifdef({NANO_TINY},{},{
               (unless jump_buf_main
                       ;; If we haven't already, we're going to set
                       ;; jump_buf so that we return here after a
                       ;; SIGWINCH.  Indicate this.
                       (set! jump_buf_main #t)
                       ;; Return here after a sigwinch
                       (sigsetjump jump_buf 1))
               })
               
               ;; Just in case we were at the statusbar prompt, make sure that
               ;; the statusbar cursor position is reset
               (do_prompt_abort)
               
               ;; If constant cursor position display is on, and there are no
               ;; keys waiting in the input buffer, display the current
               ;; cursor position on the statusbar
               (when (and (ISSET CONST_UPDATE)
                          (= 0 (get_key_buffer_len)))
                     (do_cursorpos #t))
               
               (set! currmenu MMAIN)
               
               ;; Read and interpret characters
               (do_input meta_key func_key s_or_t ran_func finished #t)))
      
      
      ;; We should never get here
      (error "assertion failed, #f"))))
