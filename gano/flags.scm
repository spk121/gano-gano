;;; (gano flags)
;;; Because of circular dependency problems with the modules,
;;; the flags get their own special module.

(define-module (gano flags)
  #:export (
            ;; global variable
            vFlags

            ;; constants
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

            ;; macros
            IGNORE_CALL_RESULT
            FLAGOFF
            FLAGMASK
            FLAGS
            SET
            UNSET
            ISSET
            TOGGLE
            ))

;; Our flag containing the states of all the global options
(define vFlags '(0 0 0 0))

;; Macros for flags.
;; FIXME: replace this with an Alist
(define sizeof-unsigned 32)
(define (FLAGOFF flag)
  (quotient flag sizeof-unsigned))
(define (FLAGMASK flag)
  (ash 1 (modulo flag sizeof-unsigned)))
(define (FLAGS flag)
  (list-ref vFlags (FLAGOFF flag)))
(define (SET flag)
  "Set Gano flags"
  (list-set! vFlags (FLAGOFF flag)
	     (logior (FLAGS flag)
		     (FLAGMASK flag))))
(define (UNSET flag)
  (list-set! vFlags (FLAGOFF flag)
	     (logand (FLAGS flag)
		     (lognot (FLAGMASK flag)))))
(define (ISSET flag)
  (logtest (FLAGS flag) (FLAGMASK flag)))
(define (TOGGLE flag)
  (list-set! vFlags (FLAGOFF flag)
	     (logxor (FLAGS flag)
		     (FLAGMASK flag))))

;; Enumeration to be used in vFlags table. See FLAGBIT and FLAGOFF
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
