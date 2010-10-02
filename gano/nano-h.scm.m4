m4_include(`config.m4')

(define-module (gano nano-h)
  #:use-module (gano global)		; flags
  #:use-module (rnrs records syntactic)
  #:use-module (ncurses curses)
  #:export (
            ;; constants
            NANO_ROOT_UID

            NIX_FILE
            DOS_FILE
            MAC_FILE

            OVERWRITE
            APPEND
            PREPEND

            UP_DIR
            DOWN_DIR

            CENTER
            NONE

            CONTROL
            META
            FKEY
            RAW

            ADD
            DEL
            REPLACE
            SPLIT
            UNSPLIT
            CUT
            UNCUT
            ENTER
            INSERT
            OTHER

            CNONE
            CBEGINBEFORE
            CENDAFTER
            CWHOLELINE
            CSTARTENDHERE
            CWTF

            ;; flags
            DONTUSE
            CASE_SENSITIVE
            CONST_UPDATE
            NO_HELP
            NOFOLLOW_SYMLINKS
            SUSPEND
            NO_WRAP
            AUTOINDENT
            VIEW_MODE
            USE_MOUSE 
            USE_REGEXP
            TEMP_FILE
            CUT_TO_END
            BACKWARDS_SEARCH
            MULTIBUFFER
            SMOOTH_SCROLL
            REBIND_DELETE
            REBIND_KEYPAD
            NO_CONVERT
            BACKUP_FILE
            INSECURE_BACKUP
            NO_COLOR_SYNTAX
            PRESERVE
            HISTORYLOG
            RESTRICTED
            SMART_HOME
            WHITESPACE_DISPLAY
            MORE_SPACE
            TABS_TO_SPACES
            QUICK_BLANK
            WORD_BOUNDS
            NO_NEWLINES
            BOLD_TEXT
            QUIET
            UNDOABLE
            SOFTWRAP
            
            ;; menus
            MMAIN
            MWHEREIS
            MREPLACE
            MREPLACE2
            MGOTOLINE
            MWRITEFILE
            MINSERTFILE
            MEXTCMD
            MHELP
            MSPELL
            MBROWSER
            MWHEREISFILE
            MGOTODIR
            MYESNO
            MALL
            
            ;; subroutine and function IDs
            CASE_SENS_MSG
            BACKWARDS_MSG
            REGEXP_MSG
            WHEREIS_NEXT_MSG
            FIRST_FILE_MSG
            LAST_FILE_MSG
            GOTO_DIR_MSG
            TOTAL_REFRESH
            DO_HELP_VOID
            DO_SEARCH
            DO_PAGE_UP
            DO_PAGE_DOWN
            DO_UP_VOID
            DO_LEFT
            DO_DOWN_VOID
            DO_RIGHT
            DO_ENTER
            DO_EXIT
            NEW_BUFFER_MSG
            EXT_CMD_MSG
            TO_FILES_MSG
            DOS_FORMAT_MSG
            MAC_FORMAT_MSG
            BACKUP_FILE_MSG
            PREPEND_MSG
            APPEND_MSG
            DO_FIRST_LINE
            DO_LAST_LINE
            DO_TOGGLE
            GOTOTEXT_MSG
            NO_REPLACE_MSG
            DO_BACKSPACE
            DO_DELETE
            DO_TAB
            DO_VERBATIM_INPUT
            SWITCH_TO_NEXT_BUFFER_VOID
            SWITCH_TO_PREV_BUFFER_VOID
            DO_END
            DO_HOME
            NEXT_HISTORY_MSG
            PREV_HISTORY_MSG
            DO_REDO
            DO_UNDO
            DO_WORDLINECHAR_COUNT
            DO_FIND_BRACKET
            DO_PREV_WORD_VOID
            DO_SUSPEND_VOID
            CANCEL_MSG
            DO_WRITEOUT_VOID
            DO_INSERTFILE_VOID
            DO_CUT_TEXT_VOID
            DO_UNCUT_TEXT
            DO_CURSORPOS_VOID
            DO_GOTOLINECOLUMN_VOID
            DO_REPLACE
            DO_JUSTIFY_VOID
            DO_PARA_BEGIN_VOID
            DO_PARA_END_VOID
            DO_FULL_JUSTIFY
            DO_MARK
            DO_RESEARCH
            DO_COPY_TEXT
            DO_INDENT_VOID
            DO_UNINDENT
            DO_SCROLL_UP
            DO_SCROLL_DOWN
            DO_NEXT_WORD_VOID
            DO_CUT_TILL_END
            NANO_GOTODIR_MSG
            NANO_LASTFILE_MSG
            NANO_FIRSTFILE_MSG
            INSERT_FILE_MSG
            NANO_MULTIBUFFER_MSG
            NANO_EXECUTE_MSG
            NANO_BACKUP_MSG
            NANO_PREPEND_MSG
            NANO_APPEND_MSG
            NANO_MAC_MSG
            NANO_DOS_MSG
            NANO_TOFILES_MSG
            NANO_NEXT_HISTORY_MSG
            NANO_PREV_HISTORY_MSG
            NANO_REGEXP_MSG
            NANO_REVERSE_MSG
            NANO_CASE_MSG
            NANO_SUSPEND_MSG
            SUSPEND_MSG
            NANO_REFRESH_MSG
            REFRESH_MSG
            NANO_WORDCOUNT_MSG
            NANO_FULLJUSTIFY_MSG
            FULLJSTIFY_MSG
            XOFF_COMPLAINT
            XON_COMPLAINT
            NANO_CUT_TILL_END_MSG
            NANO_BACKSPACE_MSG
            NANO_DELETE_MSG
            NANO_ENTER_MSG
            NANO_TAB_MSG
            NANO_VERBATIM_MSG
            NANO_NEXTFILE_MSG
            NANO_PREVFILE_MSG
            NANO_SCROLLDOWN_MSG
            NANO_SCROLLUP_MSG
            NANO_BRACKET_MSG
            NANO_PARAEND_MSG
            END_OF_PAR_MSG
            NANO_PARABEGIN_MSG
            BEG_OF_PAR_MSG
            NANO_END_MSG
            NANO_HOME_MSG
            NANO_NEXTLINE_MSG
            NANO_PREVLINE_MSG
            NANO_PREVWORD_MSG
            NANO_NEXTWORD_MSG
            NANO_BACK_MSG
            NANO_FORWARD_MSG
            NANO_REDO_MSG
            NANO_UNDO_MSG
            NANO_UNINDENT_MSG
            NANO_INDENT_MSG
            NANO_COPY_MSG
            NANO_WHEREIS_NEXT_MSG
            NANO_MARK_MSG
            NANO_REPLACE_MSG
            REPLACE_MSG
            NANO_GOTOLINE_MSG
            NANO_LASTLINE_MSG
            NANO_FIRSTLINE_MSG
            NANO_SPELL_MSG
            DO_SPELL
            NANO_CURSORPOS_MSG
            NANO_UNCUT_MSG
            GET_HELP_MSG
            NANO_HELP_MSG
            NANO_CANCEL_MSG
            NANO_EXIT_MSG
            EXIT_MSG
            NANO_EXITBROWSER_MSG
            NANO_WRITEOUT_MSG
            NANO_DISABLED_MSG
            NANO_INSERT_MSG
            WHEREIS_MSG
            NANO_WHEREIS_MSG
            NANO_PREVPAGE_MSG
            NANO_NEXTPAGE_MSG
            NANO_CUT_MSG
            DO_CUT_TEXT
            DO_NEXT_WORD
            DO_PREV_WORD

            VIEW
            NOVIEW

            MAIN_VISIBLE

            MIN_EDITOR_COLS
            MIN_EDITOR_ROWS

            CHARS_FROM_EOL

            WIDTH_OF_TAB

            MAX_SEARCH_HISTORY

            MAX_BUF_SIZE

            ;; macros
            IGNORE_CALL_RESULT
            FLAGOFF
            FLAGMASK
            FLAGS
            SET
            UNSET
            ISSET
            TOGGLE
            _
            N_
            P_

            ;; records
            make-sc
            sc?
            sc-keystr
            sc-keystr-set!
            sc-type
            sc-type-set!
            sc-seq
            sc-seq-set!
            sc-menu
            sc-menu-set!
            sc-scfunc
            sc-scfunc-set!
            sc-toggle
            sc-toggle-set!
            sc-execute
            sc-execute-set!
            sc-next
            sc-next-set!

            make-subnfunc
            subnfunc?
            subnfunc-scfunc
            subnfunc-scfunc-set!
            subnfunc-menus
            subnfunc-menus-set!
            subnfunc-desc
            subnfunc-desc-set!
            m4_ifdef({DISABLE_HELP},{},{
            subnfunc-help
            subnfunc-help-set!
            subnfunc-blank_after
            subnfunc-blank_after-set!
            })
            subnfunc-viewok
            subnfunc-viewok-set!
            subnfunc-toggle
            subnfunc-toggle-set!
            subnfunc-next
            subnfunc-next-set!
            ))

m4_ifdef({__TANDEM},{
(define NANO_ROOT_UID 65535)
},{
(define NANO_ROOT_UID 0)
})

;; UNNECESSARY: for supressing C warnings for
;; __attribute__((warn_unused_result))
(define (IGNORE_CALL_RESULT thunk)
  (thunk)
  *unspecified*)

;; Macros for flags.
;; FIXME: replace this with an Alist
(define sizeof-unsigned 32)
(define (FLAGOFF flag) 
  (quotient flag sizeof-unsigned))
(define (FLAGMASK flag) 
  (ash 1 (modulo flag sizeof-unsigned)))
(define (FLAGS flag) 
  (list-ref flags (FLAGOFF flag)))
(define (SET flag) 
  (list-set! flags (FLAGOFF flag) 
	     (logior (FLAGS flag)
		     (FLAGMASK flag))))
(define (UNSET flag)
  (list-set! flags (FLAGOFF flag)
	     (logand (FLAGS flag) 
		     (lognot (FLAGMASK flag)))))
(define (ISSET flag)
  (logtest (FLAGS flag) (FLAGMASK flag)))
(define (TOGGLE flag)
  (list-set! flags (FLAGOFF flag)
	     (logxor (FLAGS flag)
		     (FLAGMASK flag))))

;; Macros for character allocation and more.
(define (charalloc howmuch)
  (make-string howmuch))
(define-syntax charealloc
  (syntax-rules ()
    ((_ ptr howmuch)
     (if (< howmuch (string-length ptr))
	 (set! ptr (substring ptr 0 howmuch))
	 (set! ptr (string-append ptr (make-string (- howmuch (string-length ptr) #\nul))))))))
(define (charmove dest src n)
  (string-copy! dest 0 src 0 n))
(define (charset dest src n)
  (string-copy! dest 0 src 0 n))

;; Set a default value for PATH_MAX if there isn't one.
(define PATH_MAX 4096)

m4_ifdef({USE_SLANG},{
;; Slang curses emulation brain damage, part 3: Slang doesn't define the
;; curses equivalents of the Insert or Delete keys.
(define KEY_DC SL_KEY_DELETE)
(define KEY_IC SL_KEY_IC)
})

;; Native language support
m4_ifdef({ENABLE_NLS},{
(define (_ str) 
  (gettext str))
(define (P_ singular plural number)
  (ngettext singular plural number))
(define (N_ str) 
  (gettext str))
},{
(define (_ str)
  str)
(define (P_ singular plural number)
  (if (= number 1)
      singular
      plural))
(define (N_ str)
  str)
})

m4_ifdef({DISABLE_WRAPPING},{
m4_ifdef({DISABLE_JUSTIFY},{
m4_define({DISABLE_WRAPJUSTIFY},{1})
})
})

;; Enumeration types

;; file_format
(define NIX_FILE 0)
(define DOS_FILE 1)
(define MAC_FILE 2)

;; append_type
(define OVERWRITE 0)
(define APPEND 1)
(define PREPEND 2)

;; scroll_dir
(define UP_DIR 0)
(define DOWN_DIR 1)

;; update_type
(define CENTER 0)
(define NONE 1)

;; function_type
(define CONTROL 0)
(define META 1)
(define FKEY 2)
(define RAW 3)

;; undo_type
(define ADD 0)
(define DEL 1)
(define REPLACE 2)
(define SPLIT 3)
(define UNSPLIT 4)
(define CUT 5)
(define UNCUT 6)
(define ENTER 7)
(define INSERT 8)
(define OTHER 9)

m4_ifdef({ENABLE_COLOR},{
(define-record-type colortype
  (fields
   ;; This syntax's foreground color
   (mutable fg)
   ;; This syntax's background color
   (mutable bg)
   ;; Is this color A_BOLD?
   (mutable bright)
   ;; Is this regex string case insensitive?
   (mutable icase)
   ;; The color pair number used for this pair
   (mutable pairnum)
   ;; The start (or all) of the regex string
   (mutable start_regex)
   ;; The compiled start (or all) of the regex string
   (mutable start)
   ;; The end (if any) of the regex string
   (mutable end-regex)
   ;; The compiled end (if any) of the regex string
   (mutable end)
   ;; Next set of colors
   (mutable next)
   ;; Basic id for assigning to lines later
   (mutable id)
   ))

(define-record-type exttype
  (fields
   ;; The extension that match this syntax
   (mutable ext_regex)
   ;; The compiled extensions that match this syntax
   (mutable ext)
   ;; Next set of extensions
   (mutable next)))

(define-record-type syntaxtype
  (fields
   ;; The name of this syntax
   (mutable desc)
   ;; The list of extensions that this syntax applies to
   (mutable extensions)
   ;; Regexes to match on the 'header' (1st line) of the file
   (mutable headers)
   ;; The colors used in this syntax
   (mutable color)
   ;; How many multi line strings this syntax has
   (mutable nmultis)
   ;; Next Syntax
   (mutable next)
   ))

;; Yay, regex doesn't apply to this line at all!
(define CNONE (ash 1 1))
;; Regex starts on an earlier line, ends on this one
(define CBEGINBEFORE (ash 1 2))
;; regex starts on this line and ends on a later one
(define CENDAFTER (ash 1 3))
;; whole line engulfed by the regex
(define CWHOLELINE (ash 1 4))
;; regex starts and ends within this line
(define CSTARTENDHERE (ash 1 5))
;; Something else
(define CWTF (ash 1 6))

})

(define-record-type filestruct
  (fields
   ;; The text of this line
   (mutable data)
   ;; The numer of this line
   (mutable lineno)
   ;; Next node
   (mutable next)
   ;; Previous node
   (mutable prev)
m4_ifdef({ENABLE_COLOR},{
   ;;Array of which multi-line regexes apply to this line
   (mutable multidata)
})
  ))


(define-record-type partition
  (fields
   ;; The top line of this portion of the file.
   (mutable fileage)
   ;; The line before the top line of this portion of the file.
   (mutable top_prev)
   ;; The text before the beginning of the top line of this portion of the file.
   (mutable top_prev)
   ;; The bottom line of this portion of the file
   (mutable filebot)
   ;; The line after the bottom line of this portion of the file
   (mutable bot_next)
   ;; The text after the end of the bottom line of this portion of the file
   (mutable bot_data)))

m4_ifdef({NANO_TINY},{},{
(define-record-type undo
  (fields
   (mutable lineno)
   ;; What type of undo was this
   (mutable type)
   ;; Where did this action begin or end
   (mutable begin)
   ;; String type data we will use for copying the affected line back
   (mutable strdata)
   (mutable strdata2)
   (mutable xflags)

   ;; Cut specific stuff we need

   ;; Copy of the cutbuffer
   (mutable cutbuffer)
   ;; Copy of the cutbottom
   (mutable cutbottom)
   ;; Was the marker set when we cut
   (mutable mark_set)
   ;; Was this a cut to the end
   (mutable to_end)
   (mutable mark_begin_lineno)
   (mutable mark_begin_x)
   (mutable next)))
})

(define-record-type openfilestruct
  (fields
   ;; The current file's name
   (mutable filename)
   ;; The current file's first line
   (mutable fileage)
   ;; The current file's last line
   (mutable filebot)
   ;; The current top of the edit window. 
   (mutable edittop)
   ;; The current file's current line. 
   (mutable current)
   ;; The current file's total number of characters. 
   (mutable totsize)
   ;; The current file's x-coordinate position. 
   (mutable current_x)
   ;; The current file's place we want. 
   (mutable placewewant)
   ;; The current file's y-coordinate position. 
   (mutable current_y)
   ;; Whether the current file has been modified. 
   (mutable modified)
m4_ifdef({NANO_TINY},{},{
   ;; Whether the mark is on in the current file. 
   (mutable mark_set)
   ;; The current file's beginning marked line, if any. 
   (mutable mark_begin)
   ;; The current file's beginning marked line's x-coordinate
   ;; position, if any.
   (mutable  mark_begin_x)
   ;; The current file's format.
   (mutable fmt)
   ;; The current file's stat. 
   (mutable current_stat)
   ;; Top of the undo list 
   (mutable undotop)
   ;; The current (i.e. n ext) level of undo 
   (mutable current_undo)
   (mutable last_action)
})
m4_ifdef({ENABLE_COLOR},{
    ;; The  syntax struct for this file, if any 
    (mutable syntax)
    ;; The current file's associated colors. 
    (mutable colorstrings)
})
    ;; Next node. 
    (mutable next)
    ;; Previous node
    (mutable prev)))

(define-record-type shortcut
  (fields
   ;; The function's description
   (mutable desc)
m4_ifdef({DISABLE_HELP},{},{   
   ;; The help file entry text for this function
   (mutable help)
   ;; Whether there should be a blank line after the help entry text
   (mutable blank_after)
})			    
    ;; Note: Key values that aren't used should be set to NANO_NO_KEY.
    
    ;; The special sentinel key or control key we want bound, if any
    (mutable ctrlval)
    ;; The meta key we want bound, if any
    (mutable metaval)
    ;; The function key we want bound, if any
    (mutable funcval)
    ;; The other meta key we want bound, if any
    (mutable miscval)
    ;; Is this function allowe when in view mode?
    (mutable viewok)
    ;; The function to call when we get this key
    (mutable func)
    ;; Next shortcut
    (mutable next)))

m4_ifdef({ENABLE_NANORC},{
(define-record-type rcoption
  (fields
    ;; The name of the rcfile option
    (mutable name)
    ;; The flag associated with it, if any
    (mutable flag)))
})

(define-record-type (sc make-sc sc?)
  (fields
   ;; The shortcut key for a function, ASCII version 
   (mutable keystr)
   ;; What kind of function key is it for convenience later 
   (mutable type)
   ;; The actual sequence to check on the the type is determined 
   (mutable seq)
   ;; What list does this apply to 
   (mutable menu)
   ;; The function we're going to run 
   (mutable scfunc)
   ;; If a toggle, what we're toggling 
   (mutable toggle)
	;; Whether to execute the function in question or just return
	;; so the sequence can be caught by the calling code
   (mutable execute)
   ;; Next in the list 
   (mutable next)))

(define-record-type (subnfunc make-subnfunc subnfunc?)
  (fields
   ;; What function is this 
   (mutable scfunc)
   ;; In what menus does this function applu 
   (mutable menus)
   ;; The function's description, e.g. "Page Up". 
   (mutable desc)
m4_ifdef({DISABLE_HELP},{},{
   ;; The help file entry text for this function. 
   (mutable help)
   ;; Whether there should be a blank line after the help entry
   ;; text for this function.
   (mutable blank_after)
})
   ;; Is this function allowed when in view mode? 
   (mutable viewok)
   ;; If this is a toggle, if nonzero what toggle to set 
   (mutable toggle)
   ;; next item in the list 
   (mutable next)
   ))


;; Enumeration to be used in flags table. See FLAGBIT and FLAGOFF 
;; definitions.
(define    DONTUSE 1)
(define    CASE_SENSITIVE 2)
(define    CONST_UPDATE 3)
(define    NO_HELP 4)
(define    NOFOLLOW_SYMLINKS 5)
(define    SUSPEND 6)
(define    NO_WRAP 7)
(define    AUTOINDENT 8)
(define    VIEW_MODE 9)
(define    USE_MOUSE 10)
(define    USE_REGEXP 11)
(define    TEMP_FILE 12)
(define    CUT_TO_END 13)
(define    BACKWARDS_SEARCH 14)
(define    MULTIBUFFER 15)
(define    SMOOTH_SCROLL 16)
(define    REBIND_DELETE 17)
(define    REBIND_KEYPAD 18)
(define    NO_CONVERT 19)
(define    BACKUP_FILE 20)
(define    INSECURE_BACKUP 21)
(define    NO_COLOR_SYNTAX 22)
(define    PRESERVE 23)
(define    HISTORYLOG 24)
(define    RESTRICTED 25)
(define    SMART_HOME 26)
(define    WHITESPACE_DISPLAY 27)
(define    MORE_SPACE 28)
(define    TABS_TO_SPACES 29)
(define    QUICK_BLANK 30)
(define    WORD_BOUNDS 31)
(define    NO_NEWLINES 32)
(define    BOLD_TEXT 33)
(define    QUIET 34)
(define    UNDOABLE 35)
(define    SOFTWRAP 36)            


;; Flags for which menus in which a given function should be present
(define MMAIN				(ash 1 0))
(define	MWHEREIS			(ash 1 1))
(define	MREPLACE			(ash 1 2))
(define	MREPLACE2			(ash 1 3))
(define	MGOTOLINE			(ash 1 4))
(define	MWRITEFILE			(ash 1 5))
(define	MINSERTFILE			(ash 1 6))
(define	MEXTCMD				(ash 1 7))
(define	MHELP				(ash 1 8))
(define	MSPELL				(ash 1 9))
(define	MBROWSER			(ash 1 10))
(define	MWHEREISFILE			(ash 1 11))
(define MGOTODIR			(ash 1 12))
(define MYESNO				(ash 1 13))
;; This really isnt all but close enough
(define	MALL				(logior MMAIN MWHEREIS MREPLACE MREPLACE2 MGOTOLINE MWRITEFILE MINSERTFILE MEXTCMD MSPELL MBROWSER MWHEREISFILE MGOTODIR MHELP))

;; Control key sequences.  Changing these would be very, very bad.
(define NANO_CONTROL_SPACE 0)
(define NANO_CONTROL_A 1)
(define NANO_CONTROL_B 2)
(define NANO_CONTROL_C 3)
(define NANO_CONTROL_D 4)
(define NANO_CONTROL_E 5)
(define NANO_CONTROL_F 6)
(define NANO_CONTROL_G 7)
(define NANO_CONTROL_H 8)
(define NANO_CONTROL_I 9)
(define NANO_CONTROL_J 10)
(define NANO_CONTROL_K 11)
(define NANO_CONTROL_L 12)
(define NANO_CONTROL_M 13)
(define NANO_CONTROL_N 14)
(define NANO_CONTROL_O 15)
(define NANO_CONTROL_P 16)
(define NANO_CONTROL_Q 17)
(define NANO_CONTROL_R 18)
(define NANO_CONTROL_S 19)
(define NANO_CONTROL_T 20)
(define NANO_CONTROL_U 21)
(define NANO_CONTROL_V 22)
(define NANO_CONTROL_W 23)
(define NANO_CONTROL_X 24)
(define NANO_CONTROL_Y 25)
(define NANO_CONTROL_Z 26)
(define NANO_CONTROL_3 27)
(define NANO_CONTROL_4 28)
(define NANO_CONTROL_5 29)
(define NANO_CONTROL_6 30)
(define NANO_CONTROL_7 31)
(define NANO_CONTROL_8 127)

;; Meta key sequences.
(define NANO_META_SPACE #\space)
(define NANO_META_LPARENTHESIS #\()
(define NANO_META_RPARENTHESIS #\))
(define NANO_META_PLUS #\+)
(define NANO_META_COMMA #\,)
(define NANO_META_MINUS #\-)
(define NANO_META_PERIOD #\.)
(define NANO_META_SLASH #\/)
(define NANO_META_0 #\0)
(define NANO_META_6 #\6)
(define NANO_META_9 #\9)
(define NANO_META_LCARET #\<)
(define NANO_META_EQUALS #\=)
(define NANO_META_RCARET #\>)
(define NANO_META_QUESTION #\?)
(define NANO_META_BACKSLASH #\\)
(define NANO_META_RBRACKET #\])
(define NANO_META_CARET #\^)
(define NANO_META_UNDERSCORE #\_)
(define NANO_META_A #\a)
(define NANO_META_B #\b)
(define NANO_META_C #\c)
(define NANO_META_D #\d)
(define NANO_META_E #\e)
(define NANO_META_F #\f)
(define NANO_META_G #\g)
(define NANO_META_H #\h)
(define NANO_META_I #\i)
(define NANO_META_J #\j)
(define NANO_META_K #\k)
(define NANO_META_L #\l)
(define NANO_META_M #\m)
(define NANO_META_N #\n)
(define NANO_META_O #\o)
(define NANO_META_P #\p)
(define NANO_META_Q #\q)
(define NANO_META_R #\r)
(define NANO_META_S #\s)
(define NANO_META_T #\t)
(define NANO_META_U #\u)
(define NANO_META_V #\v)
(define NANO_META_W #\w)
(define NANO_META_X #\x)
(define NANO_META_Y #\y)
(define NANO_META_Z #\z)
(define NANO_META_LCURLYBRACKET #\x7b)
(define NANO_META_PIPE #\|)
(define NANO_META_RCURLYBRACKET #\x7d)

;; Some semi-changeable keybindings; don't play with these unless you're)
;; sure you know what you're doing.  Assume ERR is defined as -1.

;; No key at all.
(define NANO_NO_KEY			-2)

;; Normal keys.
(define NANO_XON_KEY			NANO_CONTROL_Q)
(define NANO_XOFF_KEY			NANO_CONTROL_S)
(define NANO_CANCEL_KEY			NANO_CONTROL_C)
(define NANO_EXIT_KEY			NANO_CONTROL_X)
(define NANO_EXIT_FKEY			(key-f 2))
(define NANO_INSERTFILE_KEY		NANO_CONTROL_R)
(define NANO_INSERTFILE_FKEY		(key-f 5))
(define NANO_TOOTHERINSERT_KEY		NANO_CONTROL_X)
(define NANO_WRITEOUT_KEY		NANO_CONTROL_O)
(define NANO_WRITEOUT_FKEY		(key-f 3))
(define NANO_GOTOLINE_KEY		NANO_CONTROL_7)
(define NANO_GOTOLINE_FKEY		(key-f 13))
(define NANO_GOTOLINE_METAKEY		NANO_META_G)
(define NANO_GOTODIR_KEY		NANO_CONTROL_7)
(define NANO_GOTODIR_FKEY		(key-f 13))
(define NANO_GOTODIR_METAKEY		NANO_META_G)
(define NANO_TOGOTOLINE_KEY		NANO_CONTROL_T)
(define NANO_HELP_KEY			NANO_CONTROL_G)
(define NANO_HELP_FKEY			(key-f 1))
(define NANO_WHEREIS_KEY		NANO_CONTROL_W)
(define NANO_WHEREIS_FKEY		(key-f 6))
(define NANO_WHEREIS_NEXT_KEY		NANO_META_W)
(define NANO_WHEREIS_NEXT_FKEY		(key-f 16))
(define NANO_TOOTHERWHEREIS_KEY		NANO_CONTROL_T)
(define NANO_REGEXP_KEY			NANO_META_R)
(define NANO_REPLACE_KEY		NANO_CONTROL_4)
(define NANO_REPLACE_FKEY		(key-f 14))
(define NANO_REPLACE_METAKEY		NANO_META_R)
(define NANO_TOOTHERSEARCH_KEY		NANO_CONTROL_R)
(define NANO_PREVPAGE_KEY		NANO_CONTROL_Y)
(define NANO_PREVPAGE_FKEY		(key-f 7))
(define NANO_NEXTPAGE_KEY		NANO_CONTROL_V)
(define NANO_NEXTPAGE_FKEY		(key-f 8))
(define NANO_CUT_KEY			NANO_CONTROL_K)
(define NANO_CUT_FKEY			(key-f 9))
(define NANO_COPY_KEY			NANO_META_CARET)
(define NANO_COPY_METAKEY		NANO_META_6)
(define NANO_UNCUT_KEY			NANO_CONTROL_U)
(define NANO_UNCUT_FKEY			(key-f 10))
(define NANO_CURSORPOS_KEY		NANO_CONTROL_C)
(define NANO_CURSORPOS_FKEY		(key-f 11))
(define NANO_SPELL_KEY			NANO_CONTROL_T)
(define NANO_SPELL_FKEY			(key-f 12))
(define NANO_FIRSTLINE_KEY		NANO_PREVPAGE_KEY)
(define NANO_FIRSTLINE_FKEY		NANO_PREVPAGE_FKEY)
(define NANO_FIRSTLINE_METAKEY		NANO_META_BACKSLASH)
(define NANO_FIRSTLINE_METAKEY2		NANO_META_PIPE)
(define NANO_FIRSTFILE_KEY		NANO_FIRSTLINE_KEY)
(define NANO_FIRSTFILE_FKEY		NANO_FIRSTLINE_FKEY)
(define NANO_FIRSTFILE_METAKEY		NANO_FIRSTLINE_METAKEY)
(define NANO_FIRSTFILE_METAKEY2		NANO_FIRSTLINE_METAKEY2)
(define NANO_LASTLINE_KEY		NANO_NEXTPAGE_KEY)
(define NANO_LASTLINE_FKEY		NANO_NEXTPAGE_FKEY)
(define NANO_LASTLINE_METAKEY		NANO_META_SLASH)
(define NANO_LASTLINE_METAKEY2		NANO_META_QUESTION)
(define NANO_LASTFILE_KEY		NANO_LASTLINE_KEY)
(define NANO_LASTFILE_FKEY		NANO_LASTLINE_FKEY)
(define NANO_LASTFILE_METAKEY		NANO_LASTLINE_METAKEY)
(define NANO_LASTFILE_METAKEY2		NANO_LASTLINE_METAKEY2)
(define NANO_REFRESH_KEY		NANO_CONTROL_L)
(define NANO_JUSTIFY_KEY		NANO_CONTROL_J)
(define NANO_JUSTIFY_FKEY		(key-f 4))
(define NANO_UNJUSTIFY_KEY		NANO_UNCUT_KEY)
(define NANO_UNJUSTIFY_FKEY		NANO_UNCUT_FKEY)
(define NANO_PREVLINE_KEY		NANO_CONTROL_P)
(define NANO_NEXTLINE_KEY		NANO_CONTROL_N)
(define NANO_FORWARD_KEY		NANO_CONTROL_F)
(define NANO_BACK_KEY			NANO_CONTROL_B)
(define NANO_MARK_KEY			NANO_CONTROL_6)
(define NANO_MARK_METAKEY		NANO_META_A)
(define NANO_MARK_FKEY			(key-f 15))
(define NANO_HOME_KEY			NANO_CONTROL_A)
(define NANO_END_KEY			NANO_CONTROL_E)
(define NANO_DELETE_KEY			NANO_CONTROL_D)
(define NANO_BACKSPACE_KEY		NANO_CONTROL_H)
(define NANO_TAB_KEY			NANO_CONTROL_I)
(define NANO_INDENT_KEY			NANO_META_RCURLYBRACKET)
(define NANO_UNINDENT_KEY		NANO_META_LCURLYBRACKET)
(define NANO_SUSPEND_KEY		NANO_CONTROL_Z)
(define NANO_ENTER_KEY			NANO_CONTROL_M)
(define NANO_TOFILES_KEY		NANO_CONTROL_T)
(define NANO_APPEND_KEY			NANO_META_A)
(define NANO_PREPEND_KEY		NANO_META_P)
(define NANO_PREVFILE_KEY		NANO_META_LCARET)
(define NANO_PREVFILE_METAKEY		NANO_META_COMMA)
(define NANO_NEXTFILE_KEY		NANO_META_RCARET)
(define NANO_NEXTFILE_METAKEY		NANO_META_PERIOD)
(define NANO_BRACKET_KEY		NANO_META_RBRACKET)
(define NANO_NEXTWORD_KEY		NANO_CONTROL_SPACE)
(define NANO_PREVWORD_KEY		NANO_META_SPACE)
(define NANO_WORDCOUNT_KEY		NANO_META_D)
(define NANO_SCROLLUP_KEY		NANO_META_MINUS)
(define NANO_SCROLLDOWN_KEY		NANO_META_PLUS)
(define NANO_SCROLLUP_METAKEY		NANO_META_UNDERSCORE)
(define NANO_SCROLLDOWN_METAKEY		NANO_META_EQUALS)
(define NANO_CUTTILLEND_METAKEY		NANO_META_T)
(define NANO_PARABEGIN_KEY		NANO_CONTROL_W)
(define NANO_PARABEGIN_METAKEY		NANO_META_LPARENTHESIS)
(define NANO_PARABEGIN_METAKEY2		NANO_META_9)
(define NANO_PARAEND_KEY		NANO_CONTROL_O)
(define NANO_PARAEND_METAKEY		NANO_META_RPARENTHESIS)
(define NANO_PARAEND_METAKEY2		NANO_META_0)
(define NANO_FULLJUSTIFY_KEY		NANO_CONTROL_U)
(define NANO_FULLJUSTIFY_METAKEY	NANO_META_J)
(define NANO_VERBATIM_KEY		NANO_META_V)


m4_ifdef({NANO_TINY},{},{
;; Toggles do not exist if NANO_TINY is defined.

;; No toggle at all.
(define TOGGLE_NO_KEY			-2)

;; Normal toggles.
(define TOGGLE_NOHELP_KEY		NANO_META_X)
(define TOGGLE_CONST_KEY		NANO_META_C)
(define TOGGLE_MORESPACE_KEY		NANO_META_O)
(define TOGGLE_SMOOTH_KEY		NANO_META_S)
(define TOGGLE_WHITESPACE_KEY		NANO_META_P)
(define TOGGLE_SYNTAX_KEY		NANO_META_Y)
(define TOGGLE_SMARTHOME_KEY		NANO_META_H)
(define TOGGLE_AUTOINDENT_KEY		NANO_META_I)
(define TOGGLE_CUTTOEND_KEY		NANO_META_K)
(define TOGGLE_WRAP_KEY			NANO_META_L)
(define TOGGLE_TABSTOSPACES_KEY		NANO_META_Q)
(define TOGGLE_BACKUP_KEY		NANO_META_B)
(define TOGGLE_MULTIBUFFER_KEY		NANO_META_F)
(define TOGGLE_MOUSE_KEY		NANO_META_M)
(define TOGGLE_NOCONVERT_KEY		NANO_META_N)
(define TOGGLE_SUSPEND_KEY		NANO_META_Z)
(define TOGGLE_CASE_KEY			NANO_META_C)
(define TOGGLE_BACKWARDS_KEY		NANO_META_B)
(define TOGGLE_DOS_KEY			NANO_META_D)
(define TOGGLE_MAC_KEY			NANO_META_M)

;; Extra bits for the undo function
(define UNDO_DEL_DEL		(ash 1 0))
(define UNDO_DEL_BACKSPACE	(ash 1 1))
(define UNDO_SPLIT_MADENEW	(ash 1 2))

})


;; Since in ISO C you can't pass around function pointers anymore,
;; let's make some integer macros for function names, and then I can
;; go cut my wrists after writing the big switch statement that will
;; necessitate.


(define CASE_SENS_MSG 1)
(define BACKWARDS_MSG 2)
(define REGEXP_MSG 3)
(define WHEREIS_NEXT_MSG 4)
(define FIRST_FILE_MSG 5)
(define LAST_FILE_MSG 6)
(define GOTO_DIR_MSG 7)
(define TOTAL_REFRESH 8)
(define DO_HELP_VOID 9)
(define DO_SEARCH 10)
(define DO_PAGE_UP 11)
(define DO_PAGE_DOWN 12)
(define DO_UP_VOID 13)
(define DO_LEFT 14)
(define DO_DOWN_VOID 15)
(define DO_RIGHT 16)
(define DO_ENTER 17)
(define DO_EXIT 18)
(define NEW_BUFFER_MSG 19)
(define EXT_CMD_MSG 20)
(define TO_FILES_MSG 21)
(define DOS_FORMAT_MSG 23)
(define MAC_FORMAT_MSG 24)
(define BACKUP_FILE_MSG 25)
(define PREPEND_MSG 26)
(define APPEND_MSG 27)
(define DO_FIRST_LINE 28)
(define DO_LAST_LINE 29)
(define DO_TOGGLE 30)
(define GOTOTEXT_MSG 31)
(define NO_REPLACE_MSG 32)
(define DO_BACKSPACE 33)
(define DO_DELETE 34)
(define DO_TAB 35)
(define DO_VERBATIM_INPUT 36)
(define SWITCH_TO_NEXT_BUFFER_VOID 37)
(define SWITCH_TO_PREV_BUFFER_VOID 38)
(define DO_END 39)
(define DO_HOME 40)
(define NEXT_HISTORY_MSG 41)
(define PREV_HISTORY_MSG 42)
(define DO_REDO 43)
(define DO_UNDO 44)
(define DO_WORDLINECHAR_COUNT 45)
(define DO_FIND_BRACKET 46)
(define DO_PREV_WORD_VOID 47)
(define DO_SUSPEND_VOID 48)
(define CANCEL_MSG 49)
(define DO_WRITEOUT_VOID 50)
(define DO_INSERTFILE_VOID 51)
(define DO_CUT_TEXT_VOID 52)
(define DO_UNCUT_TEXT 53)
(define DO_CURSORPOS_VOID 54)
(define DO_GOTOLINECOLUMN_VOID 55)
(define DO_REPLACE 56)
(define DO_JUSTIFY_VOID 57)
(define DO_PARA_BEGIN_VOID 58)
(define DO_PARA_END_VOID 59)
(define DO_FULL_JUSTIFY 60)
(define DO_MARK 61)
(define DO_RESEARCH 62)
(define DO_COPY_TEXT 63)
(define DO_INDENT_VOID 64)
(define DO_UNINDENT 65)
(define DO_SCROLL_UP 66)
(define DO_SCROLL_DOWN 67)
(define DO_NEXT_WORD_VOID 68)
(define DO_CUT_TILL_END 69)
(define NANO_GOTODIR_MSG 70)
(define NANO_LASTFILE_MSG 71)
(define NANO_FIRSTFILE_MSG 72)
(define INSERT_FILE_MSG 73)
(define NANO_MULTIBUFFER_MSG 74)
(define NANO_EXECUTE_MSG 75)
(define NANO_BACKUP_MSG 76)
(define NANO_PREPEND_MSG 77)
(define NANO_APPEND_MSG 78)
(define NANO_MAC_MSG 79)
(define NANO_DOS_MSG 80)
(define NANO_TOFILES_MSG 81)
(define NANO_NEXT_HISTORY_MSG 82)
(define NANO_PREV_HISTORY_MSG 83)
(define NANO_REGEXP_MSG 84)
(define NANO_REVERSE_MSG 85)
(define NANO_CASE_MSG 86)
(define NANO_SUSPEND_MSG 87)
(define SUSPEND_MSG 88)
(define NANO_REFRESH_MSG 89)
(define REFRESH_MSG 90)
(define NANO_WORDCOUNT_MSG 91)
(define NANO_FULLJUSTIFY_MSG 92)
(define FULLJSTIFY_MSG 93)
(define XOFF_COMPLAINT 94)
(define XON_COMPLAINT 95)
(define NANO_CUT_TILL_END_MSG 96)
(define NANO_BACKSPACE_MSG 97)
(define NANO_DELETE_MSG 98)
(define NANO_ENTER_MSG 99)
(define NANO_TAB_MSG 100)
(define NANO_VERBATIM_MSG 101)
(define NANO_NEXTFILE_MSG 102)
(define NANO_PREVFILE_MSG 103)
(define NANO_SCROLLDOWN_MSG 104)
(define NANO_SCROLLUP_MSG 105)
(define NANO_BRACKET_MSG 106)
(define NANO_PARAEND_MSG 107)
(define END_OF_PAR_MSG 108)
(define NANO_PARABEGIN_MSG 109)
(define BEG_OF_PAR_MSG 110)
(define NANO_END_MSG 111)
(define NANO_HOME_MSG 112)
(define NANO_NEXTLINE_MSG 113)
(define NANO_PREVLINE_MSG 114)
(define NANO_PREVWORD_MSG 115)
(define NANO_NEXTWORD_MSG 116)
(define NANO_BACK_MSG 117)
(define NANO_FORWARD_MSG 118)
(define NANO_REDO_MSG 119)
(define NANO_UNDO_MSG 120)
(define NANO_UNINDENT_MSG 121)
(define NANO_INDENT_MSG 122)
(define NANO_COPY_MSG 123)
(define NANO_WHEREIS_NEXT_MSG 124)
(define NANO_MARK_MSG 125)
(define NANO_REPLACE_MSG 126)
(define REPLACE_MSG 127)
(define NANO_GOTOLINE_MSG 128)
(define NANO_LASTLINE_MSG 129)
(define NANO_FIRSTLINE_MSG 130)
(define NANO_SPELL_MSG 131)
(define DO_SPELL 132)
(define NANO_CURSORPOS_MSG 133)
(define NANO_UNCUT_MSG 134)
(define GET_HELP_MSG 135)
(define NANO_HELP_MSG 136)
(define NANO_CANCEL_MSG 137)
(define NANO_EXIT_MSG 138)
(define EXIT_MSG 139)
(define NANO_EXITBROWSER_MSG 140)
(define NANO_WRITEOUT_MSG 141)
(define NANO_DISABLED_MSG 142)
(define NANO_INSERT_MSG 143)
(define WHEREIS_MSG 144)
(define NANO_WHEREIS_MSG 145)
(define NANO_PREVPAGE_MSG 146)
(define NANO_NEXTPAGE_MSG 147)
(define NANO_CUT_MSG 148)
(define DO_CUT_TEXT 149)
(define DO_NEXT_WORD 150)
(define DO_PREV_WORD 151)


(define VIEW #t)
(define NOVIEW #f)

;; The maximum number of entries displayed in the main shortcut list.
(define MAIN_VISIBLE 12)

;; The minimum editor window columns and rows required for nano to
;; work correctly.
(define MIN_EDITOR_COLS 4)
(define MIN_EDITOR_ROWS 1)

;; The default number of characters from the end of the line where
;; wrapping occurs.
(define CHARS_FROM_EOL 8)

;; The default width of a tab in spaces.
(define WIDTH_OF_TAB 8)

;; The maximum number of search/replace history strings saved, not
;; counting the blank lines at their ends.
(define MAX_SEARCH_HISTORY 100)

;; The maximum number of bytes buffered at one time.
(define MAX_BUF_SIZE 128)
