m4_include(`config.m4')
m4_define({IFSCHELP},m4_ifdef({DISABLE_HELP},{""},{$1}))

(define-module (gano global)
  #:use-module (gano records)
  #:use-module (gano flags)
  #:use-module (gano nano-h)
  #:use-module (ncurses curses)
  #:use-module (rnrs control)
  #:use-module (srfi srfi-1)
  #:export (
            m4_ifdef({NANO_TINY},{},{
            jump_buf
            jump_buf_main
            })
            m4_ifdef({DISABLE_WRAPJUSTIFY},{},{
            fill
            wrap_at
            })
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
            ))

m4_ifdef({NANO_TINY},{},{
;; Used to return to either main or the unjustify routing 
;; in do justify after a SIGWINCH
(define jump_buf #f)
;; Have we set jump_buf so that we return to main after
;; a SIGWINCH?
(define jump_buf_main #f)
})

m4_ifdef({DISABLE_WRAPJUSTIFY},{},{
;; The columns at which we will wrap lines.
(define fill 0)
;; The position where we will wrap lines.  fill is equal to this if
;; it's greater than zero, and equal to (COLS + this) if it isn't.

;; FIXME: In C, this uses CHARS_FROM_EOL which is a #define
(define wrap_at -8)
})

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
m4_ifdef({DISABLE_JUSTIFY},{},{
;; The buffer where we store unjustified text
(define jusbuffer #f)
})
;; The partition where we store a portion of the current file
(define filepart #f)


m4_ifdef({NANO_TINY},{},{
;; The opening and closing brackets that can be found by bracket
;; searches
(define matchbrackets #f)
})

m4_ifdef({NANO_TINY},{},{
m4_ifdef({ENABLE_NANORC},{
;; The characters used when display the first characters of tabs
;; and spaces
(define whitespace #f)
;; The length of these characters
(define whitespace_len '(0 0))
})
})

m4_ifdef({DISABLE_JUSTIFY},{},{
;; The closing punctuation that can end sentences
(define punct #f)
;; The closing brackets that can follow closing punctuation and
;; can end sentences
(define brackets #f)
;; The quoting string
(define quotestr #f)
m4_ifdef({HAVE_REGEX_H},{
;; The compiled regular expression from the quoting string
(define quotereg #f)
;; Whether it compiled successfully
(define quoterc 0)
;; The error message, if it didn't
(define quoteerr #f)
},{
;; The length of the quoting string in bytes
(define quotelen)
})
})

;; Are we in nodelay mode (checking for a cancel while doing something)
(define nodelay_mode #f)

;; The answer string used by the statusbar prompt
(define answer #f)

;; The width of a tab in spaces.  The default is set in main
(define tabsizelen -1)

m4_ifdef({NANO_TINY},{},{
;; The directory where we store backup files
(define backup_dir #f)
})
m4_ifdef({DISABLE_OPERATINGDIR},{},{
;; The relative path to the operating directory, which
;; we can't move outside of
(define operating_dir #f)
;; The full path
(define full_operating_dir #f)
})

m4_ifdef({DISABLE_SPELLER},{},{
;; The command to use for the alternate spell checker
(define alt_speller #f)
})

m4_ifdef({ENABLE_COLOR},{
;; The global list of color syntaxes
(define syntaxes #f)
;; The color syntax name specified on the command line
(define syntaxstr #f)
})

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

m4_ifdef({NANO_TINY},{},{
;; The search string history list
(define search_history #f)
;; The top of the search string history list
(define searchage #f)
;; The bottom of the search string history list
(define searchbot #f)
;; The replace string history list
(define replace_history #f)
;; Top of the replace string history list
(define replaceage #f)
;; Bottom of the replace string history list
(define replacebot #f)
})

m4_ifdef({HAVE_REGEX_H},{
;; The compiled regular expressionto use in searches
(define search_regexp #f)
;; The match positions for parenthetical subexpressions,
;; 10 maximum, used in regular expression searches
(define regmatches #f)
})

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
        (set! allfuncs (append allfuncs (list (make-subnfunc)))))
    (set! f (last allfuncs))
    (subnfunc-next-set! f #f)
    (subnfunc-scfunc-set! f func)
    (subnfunc-menus-set! f menus)
    (subnfunc-desc-set! f desc)
    (subnfunc-viewok-set! f viewok)
    m4_ifdef({DISABLE_HELP},{},{
    (subnfunc-help-set! f help)
    (subnfunc-blank_after-set! f blank_after)
    })

    m4_ifdef({DEBUG},{
    (format (current-error-port) "Added func \"~a\"~%" (subnfunc-desc f))
    })
    ))
        
(define (first_sc_for menu func)
  (let ((metasc #f)
        (sc #f))
    (let loop ((i 0))
      (if (< i (length sclist))
          (let ((s (list-ref sclist i)))
            (when (and (logtest (sc-menu s) menu)
                       (eq? (sc-scfunc s)))
                  (if (eq? (sc-type s) META)
                      (begin
                        (set! metasc s)
                        (loop (+ i 1)))
                      ;; else 
                      (set! sc s)
                      ;; and stop looping
                      ))
            (loop (+ i 1)))))
    ;; If we are here we have only found meta sequences.  If so, use
    ;; one.
    (cond
     (sc
      sc)
     (metasc
      sc)
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
                  m4_ifdef({DEBUG},{
                  (format (current-error-port) "No match found...~%")
                  })
                  (set! sclist (append sclist (list (make-sc))))
                  (set! s (last sclist)))))))

    (sc-type-set! s (strtokeytype scstring))
    (sc-menu-set! s menu)
    (sc-toggle-set! s toggle)
    (sc-keystr-set! s scstring)
    (sc-scfunc-set! s func)
    (sc-execute-set! s execute)
    (assign_keyinfo s)
    
    m4_ifdef({DEBUG},{
    (format (current-error-port) "list val = ~a~%" (sc-menu s))
    (format (current-error-port) 
            "Hey, set sequence to ~a for shortcut \"~a\"~%" 
            (sc-seq s) scstring)
    })
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
     m4_ifdef({KEY_HOME},{
     ((and (eq? (sc-type s) RAW)
           (string-ci=? "khome" keystr))
      (sc-seq-set! s KEY_HOME))
     })
     m4_ifdef({KEY_END},{
     ((and (eq? (sc-type s) RAW)
           (string-ci=? "kend" keystr))
      (sc-seq-set! s KEY_END))
     })
     )))

m4_ifdef({DEBUG},{
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
})

;; Stuff we need to make at least static here so we can access it
;; below.
(define cancel_msg (N_ "Cancel"))
(define replace_msg (N_ "Replace"))
(define no_replace_msg (N_ "No Replace"))

m4_ifdef({NANO_TINY},{},{
(define case_sens_msg (N_ "Case Sens"))
(define backwards_msg (N_ "Backwards"))
})

m4_ifdef({HAVE_REGEX_H},{
(define regexp_msg (N_ "Regexp"))
})

;; Stuff we want to just stun out if we're in TINY mode
m4_ifdef({NANO_TINY},{
(define gototext_msg "")
(define do_para_begin_msg "")
(define do_para_end_msg "")
(define case_sens_msg "")
(define backwards_msg "")
(define do_cut_till_end "")
(define dos_format_msg "")
(define mac_format_msg "")
(define append_msg "")
(define prepend_msg "")
(define backup_file_msg "")
(define to_files_msg "")
(define first_file_msg "")
(define whereis_next_msg "")
(define last_file_msg "")
(define new_buffer_msg "")
(define goto_dir_msg)
(define ext_cmd_msg "")
},{
;; TRANSLATORS: Try to keep the next five strings at most 10 characters.
(define prev_history_msg (N_ "PrevHstory"))
(define next_history_msg (N_ "NextHstory"))
(define gototext_msg (N_ "Go To Text"))
;; TRANSLATORS: Try to keep the next three strings at most 12 characters.
(define whereis_next_msg (N_ "WhereIs Next"))
m4_ifdef({DISABLE_BROWSER},{},{
(define first_file_msg (N_ "First File"))
(define last_file_msg (N_ "Last File"))
;; TRANSLATORS: Try to keep the next nine strings at most 16 characters.
(define to_files_msg (N_ "To Files"))
})
(define dos_format_msg (N_ "DOS Format"))
(define mac_format_msg (N_ "Mac Format"))
(define append_msg (N_ "Append"))
(define prepend_msg (N_ "Prepend"))
(define backup_file_msg (N_ "Backup File"))
(define ext_cmd_msg (N_ "Execute Command"))
m4_ifdef({ENABLE_MULTIBUFFER},{
(define new_buffer_msg (N_ "New Buffer"))
})
(define goto_dir_msg (N_ "Go To Dir"))
})


;; Initialize all shortcut lists.  If unjustify is TRUE, replace the
;; Uncut shortcut in the main shortcut list with UnJustify.
(define (shortcut_init unjustify)
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
        m4_ifdef({DISABLE_JUSTIFY},{},{
        (beg_of_par_msg (N_ "Beg of Par"))
        (end_of_par_msg (N_ "End of Par"))
        (fulljustify_msg (N_ "FullJstify"))
        })
        (refresh_msg (N_ "Refresh"))
        m4_ifdef({NANO_TINY},{},{
        (insert_file_msg (N_ "Insert File"))
        })
        (go_to_line_msg (N_ "Go To Line"))
        m4_ifdef({DISABLE_JUSTIFY},{},{
        (nano_justify_msg (N_ "Justify the current paragraph"))
        })
        m4_ifdef({DISABLE_HELP},{},{
        ;;TRANSLATORS: The next long series of strings are shortcut
        ;;descriptions; they are best kept shorter than 56 characters,
        ;;but may be longer
        (nano_cancel_msg (N_ "Cancel the current function"))
        (nano_help_msg (N_ "Display this help text"))
        (nano_exit_msg 
         m4_ifdef({ENABLE_MULTIBUFFER},{
         (N_ "Close the current file buffer / Exit from nano")
         },{
         (N_ "Exit from nano")
         }))
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
        m4_ifdef({NANO_TINY},{},{
        (nano_mark_msg  (N_ "Mark text at the cursor position"))
        (nano_whereis_next_msg  (N_ "Repeat last search"))
        (nano_copy_msg 
         (N_ "Copy the current line and store it in the cutbuffer"))
        (nano_indent_msg  (N_ "Indent the current line"))
        (nano_unindent_msg  (N_ "Unindent the current line"))
        (nano_undo_msg  (N_ "Undo the last operation"))
        (nano_redo_msg  (N_ "Redo the last undone operation"))
        })
        (nano_forward_msg  (N_ "Go forward one character"))
        (nano_back_msg  (N_ "Go back one character"))
        m4_ifdef({NANO_TINY},{},{
        (nano_nextword_msg  (N_ "Go forward one word"))
        (nano_prevword_msg  (N_ "Go back one word"))
        })
        (nano_prevline_msg  (N_ "Go to previous line"))
        (nano_nextline_msg  (N_ "Go to next line"))
        (nano_home_msg  (N_ "Go to beginning of current line"))
        (nano_end_msg  (N_ "Go to end of current line"))
        m4_ifdef({DISABLE_JUSTIFY},{},{
        (nano_parabegin_msg 
         (N_ "Go to beginning of paragraph; then of previous paragraph"))
        (nano_paraend_msg 
         (N_ "Go just beyond end of paragraph; then of next paragraph"))
        })
        (nano_firstline_msg (N_ "Go to the first line of the file"))
        (nano_lastline_msg (N_ "Go to the last line of the file"))
        m4_ifdef({NANO_TINY},{},{
        (nano_bracket_msg  (N_ "Go to the matching bracket"))
        (nano_scrollup_msg 
         (N_ "Scroll up one line without scrolling the cursor"))
        (nano_scrolldown_msg 
         (N_ "Scroll down one line without scrolling the cursor"))
        })
        m4_ifdef({ENABLE_MULTIBUFFER},{
        (nano_prevfile_msg (N_ "Switch to the previous file buffer"))
        (nano_nextfile_msg (N_ "Switch to the next file buffer"))
        })
        (nano_verbatim_msg (N_ "Insert the next keystroke verbatim"))
        (nano_tab_msg (N_ "Insert a tab at the cursor position"))
        (nano_enter_msg (N_ "Insert a newline at the cursor position"))
        (nano_delete_msg (N_ "Delete the character under the cursor"))
        (nano_backspace_msg 
         (N_ "Delete the character to the left of the cursor"))
        m4_ifdef({NANO_TINY},{},{
        (nano_cut_till_end_msg  
         (N_ "Cut from the cursor position to the end of the file"))
        })
        m4_ifdef({DISABLE_JUSTIFY},{},{
        (nano_fulljustify_msg  (N_ "Justify the entire file"))
        })
        m4_ifdef({NANO_TINY},{},{
        (nano_wordcount_msg 
         (N_ "Count the number of words, lines, and characters"))
        })
        (nano_refresh_msg (N_ "Refresh (redraw) the current screen"))
        (nano_suspend_msg 
         (N_ "Suspend the editor (if suspend is enabled)"))
        m4_ifdef({NANO_TINY},{},{
        (nano_case_msg (N_ "Toggle the case sensitivity of the search"))
        (nano_reverse_msg (N_ "Reverse the direction of the search"))
        })
        m4_ifdef({HAVE_REGEX_H},{
        (nano_regexp_msg (N_ "Toggle the use of regular expressions"))
        })
        m4_ifdef({NANO_TINY},{},{
        (nano_prev_history_msg 
         (N_ "Recall the previous search/replace string"))
        (nano_next_history_msg 
         (N_ "Recall the next search/replace string"))
        })
        m4_ifdef({DISABLE_BROWSER},{},{
        (nano_tofiles_msg  (N_ "Go to file browser"))
        })
        m4_ifdef({NANO_TINY},{},{
        (nano_dos_msg  (N_ "Toggle the use of DOS format"))
        (nano_mac_msg  (N_ "Toggle the use of Mac format"))
        })
        (nano_append_msg  (N_ "Toggle appending"))
        (nano_prepend_msg  (N_ "Toggle prepending"))
        m4_ifdef({NANO_TINY},{},{
        (nano_backup_msg 
         (N_ "Toggle backing up of the original file"))
        (nano_execute_msg  (N_ "Execute external command"))
        })
        m4_ifdef({NANO_TINY},{},{
        m4_ifdef({ENABLE_MULTIBUFFER},{
        (nano_multibuffer_msg (N_ "Toggle the use of a new buffer"))
        })
        })
        m4_ifdef({DISABLE_BROWSER},{},{
        (nano_exitbrowser_msg  (N_ "Exit from the file browser"))
        (nano_firstfile_msg (N_ "Go to the first file in the list"))
        (nano_lastfile_msg (N_ "Go to the last file in the list"))
        (nano_forwardfile_msg  (N_ "Go to the next file in the list"))
        (nano_backfile_msg  (N_ "Go to the previous file in the list"))
        (nano_gotodir_msg  (N_ "Go to directory"))
        })
        }) ;; disable help
        )

    ;; Clear out the old function list, if any
    (set! allfuncs #f)
    (gc)

    (add_to_funcs DO_HELP_VOID 
                  (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE 
                          MWRITEFILE MINSERTFILE MEXTCMD MSPELL MBROWSER 
                          MWHEREISFILE MGOTODIR)
                  get_help_msg IFSCHELP(nano_help_msg) #f VIEW)
    
    (add_to_funcs CANCEL_MSG 
                   (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MWRITEFILE 
                           MINSERTFILE MEXTCMD MSPELL MWHEREISFILE MGOTODIR 
                           MYESNO) 
                   cancel_msg IFSCHELP(nano_cancel_msg) FALSE VIEW);

    (add_to_funcs DO_EXIT 
                  MMAIN
                  m4_ifdef({ENABLE_MULTIBUFFER},{
                  ;; TRANSLATORS: Try to keep this at most 10 characters.
                  (if (and openfile (filestruct-next openfile))
                      (N_ "Close")
                      exit_msg)
                  },{
                  exit_msg
                  })
                  IFSCHELP(nano_exit_msg)
                  FALSE VIEW)
    m4_ifdef({DISABLE_BROWSER},{},{
    (add_to_funcs DO_EXIT 
                  MBROWSER 
                  exit_msg IFSCHELP(nano_exitbrowser_msg) FALSE VIEW)
    })

    ;; TRANSLATORS: Try to keep this at most 10 characters.
    (add_to_funcs DO_WRITEOUT_VOID 
                  MMAIN 
                  (N_ "WriteOut") IFSCHELP(nano_writeout_msg)  FALSE  NOVIEW)

    m4_ifdef({DISABLE_JUSTIFY},{},{
    ;; TRANSLATORS: Try to keep this at most 10 characters.
    (add_to_funcs DO_JUSTIFY_VOID  
                  MMAIN 
                  (N_ "Justify") nano_justify_msg  TRUE  NOVIEW)
    })

    ;; We allow inserting files in view mode if multibuffers are
    ;; available, so that we can view multiple files.  If we're using
    ;; restricted mode, inserting files is disabled, since it allows
    ;; reading from or writing to files not specified on the command
    ;; line.
    (add_to_funcs (if (ISSET RESTRICTED) NANO_DISABLED_MSG DO_INSERTFILE_VOID)
                  MMAIN  
                  (N_ "Read File")  IFSCHELP(nano_insert_msg)  FALSE 
                  m4_ifdef({ENABLE_MULTIBUFFER},{VIEW},{NOVIEW}))

    (add_to_funcs DO_SEARCH 
                  (logior MMAIN MBROWSER)  
                  whereis_msg IFSCHELP(nano_whereis_msg) FALSE VIEW)
    (add_to_funcs DO_PAGE_UP  
                  (logior MMAIN MHELP MBROWSER)
                  prev_page_msg  IFSCHELP(nano_prevpage_msg) FALSE VIEW)
    (add_to_funcs DO_PAGE_DOWN  
                  (logior MMAIN MHELP MBROWSER)
                  next_page_msg  IFSCHELP(nano_nextpage_msg) TRUE VIEW)

    ;; TRANSLATORS: Try to keep this at most 10 characters.
    (add_to_funcs DO_CUT_TEXT_VOID
                  MMAIN
                  (N_ "Cut Text") IFSCHELP(nano_cut_msg) FALSE NOVIEW)
    (if unjustify
	;; TRANSLATORS: Try to keep this at most 10 characters.
	(add_to_funcs DO_UNCUT_TEXT
                      MMAIN (N_ "UnJustify") "" FALSE NOVIEW)
	(add_to_funcs DO_UNCUT_TEXT 
                      MMAIN (N_ "UnCut Text") IFSCHELP(nano_uncut_msg) 
                      FALSE  NOVIEW))

    m4_ifdef({NANO_TINY},{},{
    ;; TRANSLATORS: Try to keep this at most 10 characters.
    (add_to_funcs DO_CURSORPOS_VOID
                  MMAIN 
                  (N_ "Cur Pos") IFSCHELP(nano_cursorpos_msg) FALSE VIEW)
    })

    m4_ifdef({DISABLE_SPELLER},{},{
    ;; If we're using restricted mode, spell checking is disabled
    ;; because it allows reading from or writing to files not specified
    ;; on the command line.
    (if (not (ISSET RESTRICTED))
    ;; TRANSLATORS: Try to keep this at most 10 characters.
        (add_to_funcs DO_SPELL
                      MMAIN
                      (N_ "To Spell") IFSCHELP(nano_spell_msg) TRUE NOVIEW))
    })

    (add_to_funcs DO_FIRST_LINE 
                  (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE) 
                  first_line_msg IFSCHELP(nano_firstline_msg) FALSE VIEW)

    (add_to_funcs DO_LAST_LINE 
                  (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE) 
                  last_line_msg IFSCHELP(nano_lastline_msg) TRUE VIEW)

    (add_to_funcs DO_GOTOLINECOLUMN_VOID
                  (logior MMAIN MWHEREIS) 
                  go_to_line_msg IFSCHELP(nano_gotoline_msg) FALSE VIEW)

    m4_ifdef({NANO_TINY},{
    ;; TRANSLATORS: Try to keep this at most 10 characters.
    (add_to_funcs DO_CURSORPOS_VOID
                  MMAIN 
                  (N_ "Cur Pos") IFSCHELP(nano_cursorpos_msg) FALSE VIEW)
    })

    (add_to_funcs DO_REPLACE
                  (logior MMAIN MWHEREIS) 
                  replace_msg IFSCHELP(nano_replace_msg) 
                  m4_ifdef({NANO_TINY},{TRUE},{FALSE})
                  NOVIEW)

    m4_ifdef({NANO_TINY},{},{
    (add_to_funcs DO_MARK 
                  MMAIN 
                  (N_ "Mark Text") IFSCHELP(nano_mark_msg) FALSE VIEW)
    (add_to_funcs DO_RESEARCH
                  (logior MMAIN MBROWSER)  
                  whereis_next_msg IFSCHELP(nano_whereis_next_msg) TRUE VIEW)
    (add_to_funcs DO_COPY_TEXT
                  MMAIN 
                  (N_ "Copy Text") IFSCHELP(nano_copy_msg) FALSE NOVIEW)
    (add_to_funcs DO_INDENT_VOID 
                  MMAIN 
                  (N_ "Indent Text") IFSCHELP(nano_indent_msg) FALSE NOVIEW)
    (add_to_funcs DO_UNINDENT 
                  MMAIN 
                  (N_ "Unindent Text") IFSCHELP(nano_unindent_msg) FALSE NOVIEW)
    (when (ISSET UNDOABLE)
          (add_to_funcs DO_UNDO 
                        MMAIN 
                        (N_ "Undo") IFSCHELP(nano_undo_msg) FALSE NOVIEW)
          (add_to_funcs DO_REDO 
                        MMAIN 
                        (N_ "Redo") IFSCHELP(nano_redo_msg) TRUE NOVIEW))
    })

    (add_to_funcs DO_RIGHT 
                  MMAIN 
                  (N_ "Forward") IFSCHELP(nano_forward_msg) FALSE VIEW)

    m4_ifdef({DISABLE_BROWSER},{},{
    (add_to_funcs DO_RIGHT 
                  MBROWSER 
                  (N_ "Forward") IFSCHELP(nano_forwardfile_msg) FALSE VIEW)
    })

    (add_to_funcs DO_RIGHT 
                  MALL 
                  "" "" FALSE VIEW)

    (add_to_funcs DO_LEFT MMAIN 
                  (N_ "Back") IFSCHELP(nano_back_msg) FALSE VIEW)

    m4_ifdef({DISABLE_BROWSER},{},{
    (add_to_funcs DO_LEFT 
                  MBROWSER 
                  (N_ "Back") IFSCHELP(nano_backfile_msg) FALSE VIEW)
    })

    (add_to_funcs DO_LEFT 
                  MALL 
                  "" "" FALSE VIEW)

    m4_ifdef({NANO_TINY},{},{
    (add_to_funcs DO_NEXT_WORD_VOID 
                  MMAIN 
                  (N_ "Next Word") IFSCHELP(nano_nextword_msg) FALSE VIEW)

    (add_to_funcs DO_PREV_WORD_VOID 
                  MMAIN 
                  (N_ "Prev Word") IFSCHELP(nano_prevword_msg) FALSE VIEW)
    })

    (add_to_funcs DO_UP_VOID 
                  (logior MMAIN MHELP MBROWSER) 
                  (N_ "Prev Line") IFSCHELP(nano_prevline_msg) FALSE VIEW)

    (add_to_funcs DO_DOWN_VOID 
                  (logior MMAIN MHELP MBROWSER) 
                  (N_ "Next Line") IFSCHELP(nano_nextline_msg) TRUE VIEW)

    (add_to_funcs DO_HOME 
                  MMAIN (N_ "Home") IFSCHELP(nano_home_msg) FALSE VIEW)

    (add_to_funcs DO_END 
                  MMAIN 
                  (N_ "End") IFSCHELP(nano_end_msg) FALSE VIEW)

    m4_ifdef({DISABLE_JUSTIFY},{},{
    (add_to_funcs DO_PARA_BEGIN_VOID 
                  (logior MMAIN MWHEREIS) 
                  beg_of_par_msg IFSCHELP(nano_parabegin_msg) FALSE VIEW)
    (add_to_funcs DO_PARA_END_VOID 
                  (logior MMAIN MWHEREIS) 
                  end_of_par_msg IFSCHELP(nano_paraend_msg) FALSE VIEW)
    })

    m4_ifdef({NANO_TINY},{},{
    (add_to_funcs DO_FIND_BRACKET 
                  MMAIN 
                  (_ "Find Other Bracket") IFSCHELP(nano_bracket_msg) FALSE 
                  VIEW)
    (add_to_funcs DO_SCROLL_UP 
                  MMAIN 
                  (N_ "Scroll Up") IFSCHELP(nano_scrollup_msg) FALSE VIEW)

    (add_to_funcs DO_SCROLL_DOWN
                  MMAIN 
                  (N_ "Scroll Down") IFSCHELP(nano_scrolldown_msg) FALSE VIEW)
    })

    m4_ifdef({ENABLE_MULTIBUFFER},{
    (add_to_funcs SWITCH_TO_PREV_BUFFER_VOID 
                  MMAIN  
                  (_ "Previous File") IFSCHELP(nano_prevfile_msg) FALSE VIEW)
    (add_to_funcs SWITCH_TO_NEXT_BUFFER_VOID 
                  MMAIN 
                  (N_ "Next File") IFSCHELP(nano_nextfile_msg) TRUE VIEW)
    })

    (add_to_funcs DO_VERBATIM_INPUT 
                  MMAIN 
                  (N_ "Verbatim Input") IFSCHELP(nano_verbatim_msg) FALSE 
                  NOVIEW)
    (add_to_funcs DO_VERBATIM_INPUT 
                  (logior MWHEREIS MREPLACE MREPLACE2 MEXTCMD MSPELL)
                  ""  ""  FALSE  NOVIEW)
    (add_to_funcs DO_TAB 
                  MMAIN 
                  (N_ "Tab") IFSCHELP(nano_tab_msg) FALSE NOVIEW)
    (add_to_funcs DO_TAB 
                  MALL 
                  ""  ""  FALSE  NOVIEW)
    (add_to_funcs DO_ENTER 
                  MMAIN 
                  (N_ "Enter") IFSCHELP(nano_enter_msg) FALSE  NOVIEW)
    (add_to_funcs DO_ENTER 
                  MALL  
                  ""  ""  FALSE  NOVIEW)
    (add_to_funcs DO_DELETE 
                  MMAIN 
                  (N_ "Delete") IFSCHELP(nano_delete_msg) FALSE NOVIEW)
    (add_to_funcs DO_DELETE 
                  MALL 
                  ""  ""  FALSE  NOVIEW)
    (add_to_funcs DO_BACKSPACE 
                  MMAIN 
                  (N_ "Backspace") IFSCHELP(nano_backspace_msg) 
                  m4_ifdef({NANO_TINY},{TRUE},{FALSE}) NOVIEW)
    (add_to_funcs DO_BACKSPACE 
                  MALL  
                  ""  "" 
                  m4_ifdef({NANO_TINY},{TRUE},{FALSE}) NOVIEW)

    m4_ifdef({NANO_TINY},{},{
    (add_to_funcs DO_CUT_TILL_END 
                  MMAIN 
                  (N_ "CutTillEnd") IFSCHELP(nano_cut_till_end_msg) TRUE 
                  NOVIEW)
    })

    (add_to_funcs XON_COMPLAINT 
                  MMAIN  
                  ""  ""  FALSE  VIEW);
    (add_to_funcs XOFF_COMPLAINT 
                  MMAIN  
                  ""  ""  FALSE  VIEW);

    m4_ifdef({DISABLE_JUSTIFY},{},{
    (add_to_funcs DO_FULL_JUSTIFY 
                  (logior MMAIN MWHEREIS) 
                  fulljstify_msg IFSCHELP(nano_fulljustify_msg) FALSE NOVIEW)
    })

    m4_ifdef({NANO_TINY},{},{
    (add_to_funcs DO_WORDLINECHAR_COUNT 
                  MMAIN 
                  (N_ "Word Count") IFSCHELP(nano_wordcount_msg) FALSE VIEW)
    })

    (add_to_funcs TOTAL_REFRESH 
                  (logior MMAIN MHELP) 
                  refresh_msg IFSCHELP(nano_refresh_msg) FALSE VIEW)

    (add_to_funcs DO_SUSPEND_VOID 
                  MMAIN 
                  suspend_msg IFSCHELP(nano_suspend_msg) TRUE VIEW)

    m4_ifdef({NANO_TINY},{},{
    (add_to_funcs CASE_SENS_MSG 
                  (logior MWHEREIS MREPLACE MWHEREISFILE) 
                  case_sens_msg IFSCHELP(nano_case_msg) FALSE VIEW)

    (add_to_funcs BACKWARDS_MSG 
                  (logior MWHEREIS MREPLACE MWHEREISFILE) 
                  backwards_msg IFSCHELP(nano_reverse_msg) FALSE VIEW)
    })

    m4_ifdef({HAVE_REGEX_H},{
    (add_to_funcs REGEXP_MSG 
                  (logior MWHEREIS MREPLACE MWHEREISFILE) 
                  regexp_msg IFSCHELP(nano_regexp_msg) FALSE VIEW)
    })

    m4_ifdef({NANO_TINY},{},{
    (add_to_funcs PREV_HISTORY_MSG 
                  (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE) 
                  prev_history_msg IFSCHELP(nano_prev_history_msg) FALSE VIEW)
    (add_to_funcs NEXT_HISTORY_MSG 
                  (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE) 
                  next_history_msg IFSCHELP(nano_next_history_msg) FALSE VIEW)
    })

    (add_to_funcs NO_REPLACE_MSG 
                  MREPLACE 
                  no_replace_msg IFSCHELP(nano_whereis_msg) FALSE VIEW)

    (add_to_funcs GOTOTEXT_MSG 
                  MGOTOLINE 
                  gototext_msg IFSCHELP(nano_whereis_msg) TRUE VIEW)

    m4_ifdef({DISABLE_BROWSER},{},{
    (if (not (ISSET RESTRICTED))
	(add_to_funcs TO_FILES_MSG 
                      (logior MGOTOLINE MINSERTFILE) 
                      to_files_msg IFSCHELP(nano_tofiles_msg) FALSE VIEW))
    })

    m4_ifdef({NANO_TINY},{},{
    ;; If we're using restricted mode, the DOS format, Mac format,
    ;; append, prepend, and backup toggles are disabled.  The first and
    ;; second are useless since inserting files is disabled, the third
    ;; and fourth are disabled because they allow writing to files not
    ;; specified on the command line, and the fifth is useless since
    ;; backups are disabled.
    (unless (ISSET RESTRICTED)
            (add_to_funcs DOS_FORMAT_MSG 
                          MWRITEFILE 
                          dos_format_msg IFSCHELP(nano_dos_msg) FALSE NOVIEW)
            (add_to_funcs MAC_FORMAT_MSG 
                          MWRITEFILE 
                          mac_format_msg IFSCHELP(nano_mac_msg) FALSE  NOVIEW)
            (add_to_funcs APPEND_MSG 
                          MWRITEFILE 
                          append_msg IFSCHELP(nano_append_msg) FALSE NOVIEW)
            (add_to_funcs PREPEND_MSG 
                          MWRITEFILE 
                          prepend_msg IFSCHELP(nano_prepend_msg) FALSE NOVIEW)
            (add_to_funcs BACKUP_FILE_MSG M
                          WRITEFILE 
                          backup_file_msg IFSCHELP(nano_backup_msg) FALSE 
                          NOVIEW))
    })

    m4_ifdef({NANO_TINY},{},{
    ;; If we're using restricted mode, command execution is disabled.
    ;; It's useless since inserting files is disabled.
    (if (not (ISSET RESTRICTED))
        (add_to_funcs EXT_CMD_MSG 
                      MINSERTFILE 
                      ext_cmd_msg IFSCHELP(nano_execute_msg) FALSE NOVIEW))

    m4_ifdef({ENABLE_MULTIBUFFER},{
    ;; If we're using restricted mode  the multibuffer toggle is
    ;; disabled.  It's useless since inserting files is disabled.
    (if (not (ISSET RESTRICTED))
	(add_to_funcs NEW_BUFFER_MSG
                      MINSERTFILE 
                      new_buffer_msg IFSCHELP(nano_multibuffer_msg) FALSE 
                      NOVIEW))
    })

    (add_to_funcs  INSERT_FILE_MSG 
                   MEXTCMD 
                   insert_file_msg IFSCHELP(nano_insert_msg) FALS  VIEW)

    m4_ifdef({ENABLE_MULTIBUFFER},{
    (add_to_funcs NEW_BUFFER_MSG 
                  MEXTCMD 
                  new_buffer_msg IFSCHELP(nano_multibuffer_msg) FALSE NOVIEW)
    }) ;; enable multibuffer
    }) ;; not nano tiny

    m4_ifdef({DISABLE_HELP},{},{
    (add_to_funcs REFRESH_MSG 
                  MHELP 
                  refresh_msg nano_refresh_msg FALSE VIEW)

    (add_to_funcs DO_EXIT 
                  MHELP 
                  exit_msg IFSCHELP(nano_exit_msg) FALSE VIEW)
    }) ;; not disable help

    m4_ifdef({DISABLE_BROWSER},{},{
    (add_to_funcs FIRST_FILE_MSG 
                  (logior MBROWSER MWHEREISFILE) 
                  first_file_msg IFSCHELP(nano_firstfile_msg) FALSE VIEW)

    (add_to_funcs LAST_FILE_MSG 
                  (logior MBROWSER MWHEREISFILE) 
                  last_file_msg IFSCHELP(nano_lastfile_msg) FALSE VIEW)

    (add_to_funcs GOTO_DIR_MSG  
                  MBROWSER 
                  goto_dir_msg IFSCHELP(nano_gotodir_msg) FALSE VIEW)
    }) ;; not disable browser

    (set! currmenu MMAIN)

    (add_to_sclist (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE
                           MWRITEFILE MINSERTFILE MEXTCMD MSPELL MBROWSER
                           MWHEREISFILE MGOTODIR)
                   "^G" DO_HELP_VOID 0 TRUE)
    (add_to_sclist (logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE
                           MWRITEFILE MINSERTFILE MEXTCMD MSPELL MBROWSER
                           MWHEREISFILE MGOTODIR)
                   "F1" DO_HELP_VOID 0 TRUE)
    (add_to_sclist (logior MMAIN MHELP MBROWSER)
                   "^X" DO_EXIT 0 TRUE)
    (add_to_sclist (logior MMAIN MHELP MBROWSER)
                   "F2" DO_EXIT 0 TRUE)
    (add_to_sclist MMAIN "^_" DO_GOTOLINECOLUMN_VOID 0 TRUE)
    (add_to_sclist MMAIN "F13" DO_GOTOLINECOLUMN_VOID 0 TRUE)
    (add_to_sclist MMAIN "M-G" DO_GOTOLINECOLUMN_VOID 0 TRUE)
    (add_to_sclist MMAIN "^O" DO_WRITEOUT_VOID 0 TRUE)
    (add_to_sclist MMAIN "F3" DO_WRITEOUT_VOID 0 TRUE)
    m4_ifdef({DISABLE_JUSTIFY},{},{
    (add_to_sclist MMAIN "^J" DO_JUSTIFY_VOID 0 TRUE)
    (add_to_sclist MMAIN "F4" DO_JUSTIFY_VOID 0 TRUE)
    })
    (add_to_sclist MMAIN "^R" DO_INSERTFILE_VOID 0 TRUE)
    (add_to_sclist MMAIN "F5" DO_INSERTFILE_VOID 0 TRUE)
    (add_to_sclist MMAIN "kinsert" DO_INSERTFILE_VOID 0 TRUE)
    (add_to_sclist (logior MMAIN MBROWSER) 
                   "^W" DO_SEARCH 0 TRUE)
    (add_to_sclist (logior MMAIN MBROWSER) 
                   "F6" DO_SEARCH 0 TRUE)
    (add_to_sclist (logior MMAIN MBROWSER MHELP MWHEREISFILE) 
                   "^Y" DO_PAGE_UP 0 TRUE)
    (add_to_sclist (logior MMAIN MBROWSER MHELP MWHEREISFILE)
                   "F7" DO_PAGE_UP 0 TRUE)
    (add_to_sclist (logior MMAIN MBROWSER MHELP MWHEREISFILE) 
                   "kpup" DO_PAGE_UP 0 TRUE)
    (add_to_sclist (logior MMAIN MBROWSER MHELP MWHEREISFILE) 
                   "^V" DO_PAGE_DOWN 0 TRUE)
    (add_to_sclist (logior MMAIN MBROWSER MHELP MWHEREISFILE)
                   "F8" DO_PAGE_DOWN 0 TRUE)
    (add_to_sclist (logior MMAIN MBROWSER MHELP MWHEREISFILE)
                   "kpdown" DO_PAGE_DOWN 0 TRUE)
    (add_to_sclist MMAIN "^K" DO_CUT_TEXT_VOID 0 TRUE)
    (add_to_sclist MMAIN "F9" DO_CUT_TEXT_VOID 0 TRUE)
    (add_to_sclist MMAIN "^U" DO_UNCUT_TEXT 0 TRUE)
    (add_to_sclist MMAIN "F10" DO_UNCUT_TEXT 0 TRUE)
    (add_to_sclist MMAIN "^C" DO_CURSORPOS_VOID 0 TRUE)
    (add_to_sclist MMAIN "F11" DO_CURSORPOS_VOID 0 TRUE)
    m4_ifdef({DISABLE_SPELLER},{},{
    (add_to_sclist MMAIN "^T" DO_SPELL 0 TRUE)
    (add_to_sclist MMAIN "F12" DO_SPELL 0 TRUE)
    })
    (add_to_sclist MMAIN "^\\" DO_REPLACE 0 TRUE)
    (add_to_sclist MMAIN "F14" DO_REPLACE 0 TRUE)
    (add_to_sclist MMAIN "M-R" DO_REPLACE 0 TRUE)
    (add_to_sclist MWHEREIS "^R" DO_REPLACE 0 FALSE)
    (add_to_sclist MREPLACE "^R" NO_REPLACE_MSG 0 FALSE)
    (add_to_sclist MWHEREIS "^T" DO_GOTOLINECOLUMN_VOID 0 FALSE)
    m4_ifdef({NANO_TINY},{},{
    (add_to_sclist MMAIN "^^" DO_MARK 0 TRUE)
    (add_to_sclist MMAIN "F15" DO_MARK 0 TRUE)
    (add_to_sclist MMAIN "M-A" DO_MARK 0 TRUE)
    (add_to_sclist (logior MMAIN MBROWSER) "M-W" DO_RESEARCH 0 TRUE)
    (add_to_sclist (logior MMAIN MBROWSER) "F16" DO_RESEARCH 0 TRUE)
    (add_to_sclist MMAIN "M-^" DO_COPY_TEXT 0 TRUE)
    (add_to_sclist MMAIN "M-6" DO_COPY_TEXT 0 TRUE)
    (add_to_sclist MMAIN "M-\x7D" DO_INDENT_VOID 0 TRUE)
    (add_to_sclist MMAIN "M-\x7B" DO_UNINDENT 0 TRUE)
    (when (ISSET UNDOABLE)
          (add_to_sclist MMAIN "M-U" DO_UNDO 0 TRUE)
          (add_to_sclist MMAIN "M-E" DO_REDO 0 TRUE))
    (add_to_sclist MALL "^F" DO_RIGHT 0 TRUE)
    (add_to_sclist MALL "^B" DO_LEFT 0 TRUE)
    (add_to_sclist MMAIN "^Space" DO_NEXT_WORD_VOID 0 TRUE)
    (add_to_sclist MMAIN "M-Space" DO_PREV_WORD_VOID 0 TRUE)
    }) ;; nano tiny
    (add_to_sclist MALL "kright" DO_RIGHT 0 TRUE)
    (add_to_sclist MALL "kleft" DO_LEFT 0 TRUE)
    (add_to_sclist MMAIN "^Q" XON_COMPLAINT 0 TRUE)
    (add_to_sclist MMAIN "^S" XOFF_COMPLAINT 0 TRUE)
    (add_to_sclist (logior MMAIN MHELP MBROWSER) "^P" DO_UP_VOID 0 TRUE)
    (add_to_sclist (logior MMAIN MHELP MBROWSER) "kup" DO_UP_VOID 0 TRUE)
    (add_to_sclist (logior MMAIN MHELP MBROWSER) "^N" DO_DOWN_VOID 0 TRUE)
    (add_to_sclist (logior MMAIN MHELP MBROWSER) "kdown" DO_DOWN_VOID 0 TRUE)
    (add_to_sclist MALL "^A" DO_HOME 0 TRUE)
    (add_to_sclist MALL "khome" DO_HOME 0 TRUE)
    (add_to_sclist MALL "^E" DO_END 0 TRUE)
    (add_to_sclist MALL "kend" DO_END 0 TRUE)
    m4_ifdef({NANO_TINY},{},{
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE) 
                   "^P"  PREV_HISTORY_MSG 0 FALSE)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE) 
                   "kup"  PREV_HISTORY_MSG 0 FALSE)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE)
                   "^N"  NEXT_HISTORY_MSG 0 FALSE)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2 MWHEREISFILE) 
                   "kdown"  NEXT_HISTORY_MSG 0 FALSE)
    })
    m4_ifdef({DISABLE_JUSTIFY},{},{
    (add_to_sclist MWHEREIS MREPLACE MREPLACE2
	"^W" DO_PARA_BEGIN_VOID 0 TRUE)
    (add_to_sclist MWHEREIS MREPLACE MREPLACE2
	"^O" DO_PARA_END_VOID 0 TRUE)
    (add_to_sclist MALL "M-(" DO_PARA_BEGIN_VOID 0 TRUE)
    (add_to_sclist MALL "M-9" DO_PARA_BEGIN_VOID 0 TRUE)
    (add_to_sclist MALL "M-)" DO_PARA_END_VOID 0 TRUE)
    (add_to_sclist MALL "M-0" DO_PARA_END_VOID 0 TRUE)
    })
    (add_to_sclist MWHEREIS "M-C" CASE_SENS_MSG 0 FALSE)
    (add_to_sclist MREPLACE "M-C" CASE_SENS_MSG 0 FALSE)
    (add_to_sclist MREPLACE2 "M-C" CASE_SENS_MSG 0 FALSE)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2)
                   "M-B" BACKWARDS_MSG 0 FALSE)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2)
                   "M-R" REGEXP_MSG 0 FALSE)

    (add_to_sclist MMAIN "M-\\" DO_FIRST_LINE 0 TRUE)
    (add_to_sclist MMAIN "M- " DO_FIRST_LINE 0 TRUE)
    (add_to_sclist MMAIN "M-/" DO_LAST_LINE 0 TRUE)
    (add_to_sclist MMAIN "M-?" DO_LAST_LINE 0 TRUE)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MHELP)
                   "^Y" DO_FIRST_LINE 0 TRUE)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MHELP)
                   "^V" DO_LAST_LINE 0 TRUE)

    (add_to_sclist (logior MBROWSER MWHEREISFILE) "M-\\"  FIRST_FILE_MSG 0 TRUE)
    (add_to_sclist (logior MBROWSER MWHEREISFILE) "M- "  FIRST_FILE_MSG 0 TRUE)
    (add_to_sclist (logior MBROWSER MWHEREISFILE) "M-/"  LAST_FILE_MSG 0 TRUE)
    (add_to_sclist (logior MBROWSER MWHEREISFILE) "M-?"  LAST_FILE_MSG 0 TRUE)
    (add_to_sclist (logior MBROWSER MWHEREISFILE) "^_"  GOTO_DIR_MSG 0 TRUE)
    (add_to_sclist (logior MBROWSER MWHEREISFILE) "F13"  GOTO_DIR_MSG 0 TRUE)
    (add_to_sclist (logior MBROWSER MWHEREISFILE) "M-G"  GOTO_DIR_MSG 0 TRUE)
    m4_ifdef({NANO_TINY},{},{
    (add_to_sclist MMAIN "M-]" DO_FIND_BRACKET 0 TRUE)
    (add_to_sclist MMAIN "M--" DO_SCROLL_UP 0 TRUE)
    (add_to_sclist MMAIN "M-_" DO_SCROLL_UP 0 TRUE)
    (add_to_sclist MMAIN "M-+" DO_SCROLL_DOWN 0 TRUE)
    (add_to_sclist MMAIN "M-=" DO_SCROLL_DOWN 0 TRUE)
    })

    m4_ifdef({ENABLE_MULTIBUFFER},{
    (add_to_sclist MMAIN "M-<" SWITCH_TO_PREV_BUFFER_VOID 0 TRUE)
    (add_to_sclist MMAIN "M-" SWITCH_TO_PREV_BUFFER_VOID 0 TRUE)
    (add_to_sclist MMAIN "M->" SWITCH_TO_NEXT_BUFFER_VOID 0 TRUE)
    (add_to_sclist MMAIN "M-." SWITCH_TO_NEXT_BUFFER_VOID 0 TRUE)
    })
    (add_to_sclist MALL "M-V" DO_VERBATIM_INPUT 0 TRUE)
    m4_ifdef({NANO_TINY},{},{
    (add_to_sclist MALL "M-T" DO_CUT_TILL_END 0 TRUE)
    m4_ifdef({DISABLE_JUSTIFY},{},{
    (add_to_sclist MALL "M-J" DO_FULL_JUSTIFY 0 TRUE)
    }) ;; disable justify
    (add_to_sclist MMAIN "M-D" DO_WORDLINECHAR_COUNT 0 TRUE)
    (add_to_sclist MMAIN "M-X" DO_TOGGLE NO_HELP TRUE)
    (add_to_sclist MMAIN "M-C" DO_TOGGLE CONST_UPDATE TRUE)
    (add_to_sclist MMAIN "M-O" DO_TOGGLE MORE_SPACE TRUE)
    (add_to_sclist MMAIN "M-S" DO_TOGGLE SMOOTH_SCROLL TRUE)
    (add_to_sclist MMAIN "M-P" DO_TOGGLE WHITESPACE_DISPLAY TRUE)
    (add_to_sclist MMAIN "M-Y" DO_TOGGLE NO_COLOR_SYNTAX TRUE)
    (add_to_sclist MMAIN "M-H" DO_TOGGLE SMART_HOME TRUE)
    (add_to_sclist MMAIN "M-I" DO_TOGGLE AUTOINDENT TRUE)
    (add_to_sclist MMAIN "M-K" DO_TOGGLE CUT_TO_END TRUE)
    (add_to_sclist MMAIN "M-L" DO_TOGGLE NO_WRAP TRUE)
    (add_to_sclist MMAIN "M-Q" DO_TOGGLE TABS_TO_SPACES TRUE)
    (add_to_sclist MMAIN "M-B" DO_TOGGLE BACKUP_FILE TRUE)
    (add_to_sclist MMAIN "M-F" DO_TOGGLE MULTIBUFFER TRUE)
    (add_to_sclist MMAIN "M-M" DO_TOGGLE USE_MOUSE TRUE)
    (add_to_sclist MMAIN "M-N" DO_TOGGLE NO_CONVERT TRUE)
    (add_to_sclist MMAIN "M-Z" DO_TOGGLE SUSPEND TRUE)
    (add_to_sclist MMAIN "M-$" DO_TOGGLE SOFTWRAP TRUE)
    }) ;; nano tiny
    (add_to_sclist MGOTOLINE "^T"  GOTOTEXT_MSG 0 FALSE)
    (add_to_sclist (logior MINSERTFILE MEXTCMD) 
                   "M-F"  NEW_BUFFER_MSG 0 FALSE)
    (add_to_sclist (logior MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MWRITEFILE
                           MINSERTFILE MEXTCMD MSPELL MWHEREISFILE MGOTODIR
                           MYESNO)
                   "^C" CANCEL_MSG 0 FALSE)
    (add_to_sclist MHELP "^X" DO_EXIT 0 TRUE)
    (add_to_sclist MHELP "F2" DO_EXIT 0 TRUE)
    (add_to_sclist MWRITEFILE "M-D"  DOS_FORMAT_MSG 0 FALSE)
    (add_to_sclist MWRITEFILE "M-M"  MAC_FORMAT_MSG 0 FALSE)
    (add_to_sclist MWRITEFILE "M-A"  APPEND_MSG 0 FALSE)
    (add_to_sclist MWRITEFILE "M-P"  PREPEND_MSG 0 FALSE)
    (add_to_sclist MWRITEFILE "M-B"  BACKUP_FILE_MSG 0 FALSE)
    (add_to_sclist MWRITEFILE "^T"  TO_FILES_MSG 0 FALSE)
    (add_to_sclist MINSERTFILE "^T"  TO_FILES_MSG 0 FALSE)
    (add_to_sclist MINSERTFILE "^X"  EXT_CMD_MSG 0 FALSE)
    (add_to_sclist MMAIN "^Z" DO_SUSPEND_VOID 0 FALSE)
    (add_to_sclist MMAIN "^L" TOTAL_REFRESH 0 TRUE)
    (add_to_sclist MALL "^I" DO_TAB 0 TRUE)
    (add_to_sclist MALL "^M" DO_ENTER 0 TRUE)
    (add_to_sclist MALL "kenter" DO_ENTER 0 TRUE)
    (add_to_sclist MALL "^D" DO_DELETE 0 TRUE)
    (add_to_sclist MALL "kdel" DO_DELETE 0 TRUE)
    (add_to_sclist MALL "^H" DO_BACKSPACE 0 TRUE)
    (add_to_sclist MALL "kbsp" DO_BACKSPACE 0 TRUE)

    m4_ifdef({DEBUG},{
    (print_sclist)
    })
    ))

(define (sctofunc s)
  (if (list? allfuncs)
      (find (lambda (f)
              (eq? (subnfunc-scfunc f) (sc-scfunc s)))
            allfuncs)
      #f))
