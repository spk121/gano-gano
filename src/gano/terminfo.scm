;;; terminfo.scm --- GNU Guile library for working with terminfo S-JSON data
;;;
;;; Copyright (C) 2025
;;;
;;; This library is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU Lesser General Public
;;; License as published by the Free Software Foundation; either
;;; version 3 of the License, or (at your option) any later version.

(define-module (gano terminfo)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 regex)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:export (load-terminfo-sjson
            get-string-capability
            get-numeric-capability
            get-boolean-capability
            
            ;; Cursor movement functions
            emit-cursor-up
            emit-cursor-down
            emit-cursor-left
            emit-cursor-right
            emit-cursor-home
            emit-cursor-to-ll
            emit-cursor-address
            emit-save-cursor
            emit-restore-cursor
            
            ;; Screen clearing functions
            emit-clear-screen
            emit-clr-eol
            emit-clr-eos
            
            ;; Character/line manipulation
            emit-delete-character
            emit-delete-line
            emit-insert-character
            emit-insert-line
            
            ;; Mode functions
            emit-enter-bold-mode
            emit-enter-dim-mode
            emit-enter-blink-mode
            emit-enter-reverse-mode
            emit-enter-standout-mode
            emit-exit-standout-mode
            emit-enter-underline-mode
            emit-exit-underline-mode
            emit-exit-attribute-mode
            emit-enter-insert-mode
            emit-exit-insert-mode
            emit-enter-delete-mode
            emit-exit-delete-mode
            
            ;; Special functions
            emit-bell
            emit-back-tab
            emit-scroll-forward
            emit-scroll-reverse
            emit-set-attributes
            
            ;; Additional cursor functions
            emit-cursor-invisible
            emit-cursor-normal
            emit-cursor-visible
            emit-column-address
            emit-row-address
            
            ;; Additional screen functions
            emit-clr-bol
            emit-erase-chars
            emit-flash-screen
            emit-newline
            
            ;; Additional editing functions
            emit-parm-dch
            emit-parm-delete-line
            emit-parm-ich
            emit-parm-insert-line
            emit-parm-index
            emit-parm-rindex
            
            ;; Additional mode functions
            emit-enter-secure-mode
            emit-enter-italics-mode
            emit-exit-italics-mode
            emit-enter-alt-charset-mode
            emit-exit-alt-charset-mode
            emit-enter-am-mode
            emit-exit-am-mode
            emit-enter-ca-mode
            emit-exit-ca-mode
            emit-keypad-xmit
            emit-keypad-local
            emit-meta-on
            emit-meta-off
            
            ;; Color functions
            emit-set-a-background
            emit-set-a-foreground
            emit-set-background
            emit-set-foreground
            emit-orig-pair
            
            ;; Tab functions
            emit-tab
            emit-set-tab
            emit-clear-all-tabs
            
            ;; Printer functions
            emit-print-screen
            emit-prtr-on
            emit-prtr-off
            
            ;; Margin functions
            emit-set-left-margin-parm
            emit-set-lr-margin
            emit-set-right-margin-parm
            emit-clear-margins
            
            ;; Memory functions
            emit-memory-lock
            emit-memory-unlock
            
            ;; Parameterized cursor movement
            emit-parm-up-cursor
            emit-parm-down-cursor
            emit-parm-left-cursor
            emit-parm-right-cursor
            emit-change-scroll-region
            
            ;; Special keys with modifiers
            emit-key-sdc
            emit-key-send
            emit-key-shome
            emit-key-sic
            emit-key-sleft
            emit-key-snext
            emit-key-sprevious
            emit-key-sright
            emit-key-a1
            emit-key-a3
            emit-key-b2
            emit-key-beg
            emit-key-c1
            emit-key-c3
            emit-key-btab
            emit-key-mouse
            emit-key-ppage
            emit-key-npage
            emit-key-sf
            emit-key-sr
            
            ;; Initialization and reset functions
            emit-init-2string
            emit-reset-1string
            emit-reset-2string
            
            ;; Character set functions
            emit-acs-chars
            
            ;; User-defined sequences
            emit-user6
            emit-user7
            emit-user8
            emit-user9
            
            ;; Status line functions
            emit-dis-status-line
            emit-from-status-line
            emit-to-status-line
            
            ;; Initialization and file functions
            emit-init-file
            emit-init-3string
            emit-reset-file
            emit-reset-3string
            
            ;; Character set and special mode functions
            emit-ena-acs
            emit-enter-pc-charset-mode
            emit-exit-pc-charset-mode
            emit-enter-shadow-mode
            emit-exit-shadow-mode
            emit-enter-subscript-mode
            emit-exit-subscript-mode
            emit-enter-superscript-mode
            emit-exit-superscript-mode
            
            ;; Color initialization and original colors
            emit-initialize-color
            emit-orig-colors
            
            ;; Input parsing functions
            make-input-parser
            parse-input-byte
            reset-input-parser
            get-parser-state
            
            ;; Input parser state symbols
            ;; Returns: character, symbol (like 'key_f5), 'incomplete, 'incorrect
            
            ;; Utility functions
            terminfo-get-columns
            terminfo-get-lines
            terminfo-has-color
            decode-escape-sequence))

;;; Global variable to hold the loaded terminfo data
(define *terminfo-data* '())

;;; Record type for terminfo data structure
(define-record-type <terminfo>
  (make-terminfo primary-name terminal-names boolean-caps numeric-caps string-caps)
  terminfo?
  (primary-name terminfo-primary-name)
  (terminal-names terminfo-terminal-names)
  (boolean-caps terminfo-boolean-caps)
  (numeric-caps terminfo-numeric-caps)
  (string-caps terminfo-string-caps))

;;; Helper function to find a value in an association list
(define (alist-ref key alist default)
  "Find KEY in ALIST, returning associated value or DEFAULT if not found."
  (let ((pair (assoc key alist)))
    (if pair (cadr pair) default)))

;;; Load terminfo S-JSON data from file
(define (load-terminfo-sjson filename)
  "Load terminfo data from S-JSON file FILENAME and store it globally."
  (let* ((content (call-with-input-file filename get-string-all))
         (data (call-with-input-string content read)))
    (set! *terminfo-data* 
          (make-terminfo
           (alist-ref "primary_name" data "unknown")
           (alist-ref "terminal_names" data '())
           (alist-ref "boolean_capabilities" data '())
           (alist-ref "numeric_capabilities" data '())
           (alist-ref "string_capabilities" data '())))
    *terminfo-data*))

;;; Capability accessor functions
(define (get-string-capability name)
  "Get string capability NAME from loaded terminfo data."
  (if (terminfo? *terminfo-data*)
      (alist-ref name (terminfo-string-caps *terminfo-data*) #f)
      #f))

(define (get-numeric-capability name)
  "Get numeric capability NAME from loaded terminfo data."
  (if (terminfo? *terminfo-data*)
      (alist-ref name (terminfo-numeric-caps *terminfo-data*) #f)
      #f))

(define (get-boolean-capability name)
  "Get boolean capability NAME from loaded terminfo data."
  (if (terminfo? *terminfo-data*)
      (alist-ref name (terminfo-boolean-caps *terminfo-data*) #f)
      #f))

;;; Escape sequence decoder
(define (decode-escape-sequence seq)
  "Decode escape sequence SEQ from terminfo format to actual control characters."
  (if (not seq)
      ""
      (let ((result seq))
        ;; Replace common escape sequences
        (set! result (regexp-substitute/global #f "\\\\033" result 'pre "\033" 'post))
        (set! result (regexp-substitute/global #f "\\\\012" result 'pre "\012" 'post))
        (set! result (regexp-substitute/global #f "\\\\015" result 'pre "\015" 'post))
        (set! result (regexp-substitute/global #f "\\\\011" result 'pre "\011" 'post))
        (set! result (regexp-substitute/global #f "\\\\010" result 'pre "\010" 'post))
        (set! result (regexp-substitute/global #f "\\\\014" result 'pre "\014" 'post))
        (set! result (regexp-substitute/global #f "\\\\007" result 'pre "\007" 'post))
        result)))

;;; Parameter substitution for escape sequences with arguments
(define (substitute-params seq . params)
  "Substitute parameters PARAMS into escape sequence SEQ.
   Handles terminfo parameterized strings like cursor positioning."
  (if (not seq)
      ""
      (let ((result (decode-escape-sequence seq))
            (param-list params))
        ;; Simple parameter substitution - this is a basic implementation
        ;; Real terminfo parameter substitution is much more complex
        (let loop ((str result) (i 1) (remaining-params param-list))
          (cond
           ((null? remaining-params) str)
           (else
            (let* ((param-pattern (string-append "%d"))
                   (param-value (number->string (car remaining-params))))
              (set! str (regexp-substitute/global #f "%d" str 'pre param-value 'post))
              (loop str (+ i 1) (cdr remaining-params)))))))))

;;; Basic cursor movement functions
(define (emit-cursor-up . count)
  "Emit escape sequence to move cursor up COUNT rows (default 1)."
  (let ((seq (get-string-capability "cursor_up"))
        (n (if (null? count) 1 (car count))))
    (if (and seq (> n 1))
        ;; For multiple movements, repeat the sequence
        (apply string-append (make-list n (decode-escape-sequence seq)))
        (decode-escape-sequence seq))))

(define (emit-cursor-down . count)
  "Emit escape sequence to move cursor down COUNT rows (default 1)."
  (let ((seq (get-string-capability "cursor_down"))
        (n (if (null? count) 1 (car count))))
    (if (and seq (> n 1))
        (apply string-append (make-list n (decode-escape-sequence seq)))
        (decode-escape-sequence seq))))

(define (emit-cursor-left . count)
  "Emit escape sequence to move cursor left COUNT columns (default 1)."
  (let ((seq (get-string-capability "cursor_left"))
        (n (if (null? count) 1 (car count))))
    (if (and seq (> n 1))
        (apply string-append (make-list n (decode-escape-sequence seq)))
        (decode-escape-sequence seq))))

(define (emit-cursor-right . count)
  "Emit escape sequence to move cursor right COUNT columns (default 1)."
  (let ((seq (get-string-capability "cursor_right"))
        (n (if (null? count) 1 (car count))))
    (if (and seq (> n 1))
        (apply string-append (make-list n (decode-escape-sequence seq)))
        (decode-escape-sequence seq))))

(define (emit-cursor-home)
  "Emit escape sequence to move cursor to home position (0,0)."
  (decode-escape-sequence (get-string-capability "cursor_home")))

(define (emit-cursor-to-ll)
  "Emit escape sequence to move cursor to lower-left corner."
  (decode-escape-sequence (get-string-capability "cursor_to_ll")))

(define (emit-cursor-address row col)
  "Emit escape sequence to move cursor to ROW, COL position."
  (let ((seq (get-string-capability "cursor_address")))
    (if seq
        (substitute-params seq row col)
        "")))

(define (emit-save-cursor)
  "Emit escape sequence to save current cursor position."
  (decode-escape-sequence (get-string-capability "save_cursor")))

(define (emit-restore-cursor)
  "Emit escape sequence to restore saved cursor position."
  (decode-escape-sequence (get-string-capability "restore_cursor")))

;;; Screen clearing functions
(define (emit-clear-screen)
  "Emit escape sequence to clear entire screen."
  (decode-escape-sequence (get-string-capability "clear_screen")))

(define (emit-clr-eol)
  "Emit escape sequence to clear from cursor to end of line."
  (decode-escape-sequence (get-string-capability "clr_eol")))

(define (emit-clr-eos)
  "Emit escape sequence to clear from cursor to end of screen."
  (decode-escape-sequence (get-string-capability "clr_eos")))

;;; Character and line manipulation
(define (emit-delete-character . count)
  "Emit escape sequence to delete COUNT characters (default 1)."
  (let ((seq (get-string-capability "delete_character"))
        (n (if (null? count) 1 (car count))))
    (if (and seq (> n 1))
        (apply string-append (make-list n (decode-escape-sequence seq)))
        (decode-escape-sequence seq))))

(define (emit-delete-line . count)
  "Emit escape sequence to delete COUNT lines (default 1)."
  (let ((seq (get-string-capability "delete_line"))
        (n (if (null? count) 1 (car count))))
    (if (and seq (> n 1))
        (apply string-append (make-list n (decode-escape-sequence seq)))
        (decode-escape-sequence seq))))

(define (emit-insert-character . count)
  "Emit escape sequence to insert COUNT characters (default 1)."
  (let ((seq (get-string-capability "insert_character"))
        (n (if (null? count) 1 (car count))))
    (if (and seq (> n 1))
        (apply string-append (make-list n (decode-escape-sequence seq)))
        (decode-escape-sequence seq))))

(define (emit-insert-line . count)
  "Emit escape sequence to insert COUNT lines (default 1)."
  (let ((seq (get-string-capability "insert_line"))
        (n (if (null? count) 1 (car count))))
    (if (and seq (> n 1))
        (apply string-append (make-list n (decode-escape-sequence seq)))
        (decode-escape-sequence seq))))

;;; Text attribute modes
(define (emit-enter-bold-mode)
  "Emit escape sequence to enter bold text mode."
  (decode-escape-sequence (get-string-capability "enter_bold_mode")))

(define (emit-enter-dim-mode)
  "Emit escape sequence to enter dim text mode."
  (decode-escape-sequence (get-string-capability "enter_dim_mode")))

(define (emit-enter-blink-mode)
  "Emit escape sequence to enter blinking text mode."
  (decode-escape-sequence (get-string-capability "enter_blink_mode")))

(define (emit-enter-reverse-mode)
  "Emit escape sequence to enter reverse video mode."
  (decode-escape-sequence (get-string-capability "enter_reverse_mode")))

(define (emit-enter-standout-mode)
  "Emit escape sequence to enter standout mode."
  (decode-escape-sequence (get-string-capability "enter_standout_mode")))

(define (emit-exit-standout-mode)
  "Emit escape sequence to exit standout mode."
  (decode-escape-sequence (get-string-capability "exit_standout_mode")))

(define (emit-enter-underline-mode)
  "Emit escape sequence to enter underline mode."
  (decode-escape-sequence (get-string-capability "enter_underline_mode")))

(define (emit-exit-underline-mode)
  "Emit escape sequence to exit underline mode."
  (decode-escape-sequence (get-string-capability "exit_underline_mode")))

(define (emit-exit-attribute-mode)
  "Emit escape sequence to exit all attribute modes (reset to normal)."
  (decode-escape-sequence (get-string-capability "exit_attribute_mode")))

;;; Insert/delete modes
(define (emit-enter-insert-mode)
  "Emit escape sequence to enter insert mode."
  (decode-escape-sequence (get-string-capability "enter_insert_mode")))

(define (emit-exit-insert-mode)
  "Emit escape sequence to exit insert mode."
  (decode-escape-sequence (get-string-capability "exit_insert_mode")))

(define (emit-enter-delete-mode)
  "Emit escape sequence to enter delete mode."
  (decode-escape-sequence (get-string-capability "enter_delete_mode")))

(define (emit-exit-delete-mode)
  "Emit escape sequence to exit delete mode."
  (decode-escape-sequence (get-string-capability "exit_delete_mode")))

;;; Special functions
(define (emit-bell)
  "Emit escape sequence for audible bell."
  (decode-escape-sequence (get-string-capability "bell")))

(define (emit-back-tab)
  "Emit escape sequence for back tab."
  (decode-escape-sequence (get-string-capability "back_tab")))

(define (emit-scroll-forward . count)
  "Emit escape sequence to scroll forward COUNT lines (default 1)."
  (let ((seq (get-string-capability "scroll_forward"))
        (n (if (null? count) 1 (car count))))
    (if (and seq (> n 1))
        (apply string-append (make-list n (decode-escape-sequence seq)))
        (decode-escape-sequence seq))))

(define (emit-scroll-reverse . count)
  "Emit escape sequence to scroll reverse COUNT lines (default 1)."
  (let ((seq (get-string-capability "scroll_reverse"))
        (n (if (null? count) 1 (car count))))
    (if (and seq (> n 1))
        (apply string-append (make-list n (decode-escape-sequence seq)))
        (decode-escape-sequence seq))))

(define (emit-set-attributes . attrs)
  "Emit escape sequence to set multiple attributes.
   ATTRS should be a list of attribute numbers."
  (let ((seq (get-string-capability "set_attributes")))
    (if seq
        (apply substitute-params seq attrs)
        "")))

;;; Key sequences
(define (emit-key-up)
  "Get escape sequence for up arrow key."
  (decode-escape-sequence (get-string-capability "key_up")))

(define (emit-key-down)
  "Get escape sequence for down arrow key."
  (decode-escape-sequence (get-string-capability "key_down")))

(define (emit-key-left)
  "Get escape sequence for left arrow key."
  (decode-escape-sequence (get-string-capability "key_left")))

(define (emit-key-right)
  "Get escape sequence for right arrow key."
  (decode-escape-sequence (get-string-capability "key_right")))

(define (emit-key-home)
  "Get escape sequence for home key."
  (decode-escape-sequence (get-string-capability "key_home")))

(define (emit-key-end)
  "Get escape sequence for end key."
  (decode-escape-sequence (get-string-capability "key_end")))

(define (emit-key-backspace)
  "Get escape sequence for backspace key."
  (decode-escape-sequence (get-string-capability "key_backspace")))

(define (emit-key-enter)
  "Get escape sequence for enter key."
  (decode-escape-sequence (get-string-capability "key_enter")))

(define (emit-key-function n)
  "Get escape sequence for function key N (F1-F10+)."
  (let ((key-name (string-append "key_f" (number->string n))))
    (decode-escape-sequence (get-string-capability key-name))))

;;; Utility functions
(define (terminfo-get-columns)
  "Get the number of columns for the terminal."
  (or (get-numeric-capability "columns") 80))

(define (terminfo-get-lines)
  "Get the number of lines for the terminal."
  (or (get-numeric-capability "lines") 24))

;;; Additional cursor movement functions
(define (emit-cursor-invisible)
  "Emit escape sequence to make cursor invisible."
  (decode-escape-sequence (get-string-capability "cursor_invisible")))

(define (emit-cursor-normal)
  "Emit escape sequence to set cursor to normal visibility."
  (decode-escape-sequence (get-string-capability "cursor_normal")))

(define (emit-cursor-visible)
  "Emit escape sequence to make cursor highly visible."
  (decode-escape-sequence (get-string-capability "cursor_visible")))

(define (emit-column-address col)
  "Emit escape sequence to move cursor to column COL."
  (let ((seq (get-string-capability "column_address")))
    (if seq
        (substitute-params seq col)
        "")))

(define (emit-row-address row)
  "Emit escape sequence to move cursor to row ROW."
  (let ((seq (get-string-capability "row_address")))
    (if seq
        (substitute-params seq row)
        "")))

;;; Parameterized cursor movement
(define (emit-parm-up-cursor count)
  "Emit escape sequence to move cursor up COUNT rows."
  (let ((seq (get-string-capability "parm_up_cursor")))
    (if seq
        (substitute-params seq count)
        "")))

(define (emit-parm-down-cursor count)
  "Emit escape sequence to move cursor down COUNT rows."
  (let ((seq (get-string-capability "parm_down_cursor")))
    (if seq
        (substitute-params seq count)
        "")))

(define (emit-parm-left-cursor count)
  "Emit escape sequence to move cursor left COUNT columns."
  (let ((seq (get-string-capability "parm_left_cursor")))
    (if seq
        (substitute-params seq count)
        "")))

(define (emit-parm-right-cursor count)
  "Emit escape sequence to move cursor right COUNT columns."
  (let ((seq (get-string-capability "parm_right_cursor")))
    (if seq
        (substitute-params seq count)
        "")))

(define (emit-change-scroll-region top bottom)
  "Emit escape sequence to set scroll region from TOP to BOTTOM."
  (let ((seq (get-string-capability "change_scroll_region")))
    (if seq
        (substitute-params seq top bottom)
        "")))

;;; Additional screen clearing functions
(define (emit-clr-bol)
  "Emit escape sequence to clear from beginning of line to cursor."
  (decode-escape-sequence (get-string-capability "clr_bol")))

(define (emit-erase-chars count)
  "Emit escape sequence to erase COUNT characters."
  (let ((seq (get-string-capability "erase_chars")))
    (if seq
        (substitute-params seq count)
        "")))

(define (emit-flash-screen)
  "Emit escape sequence to flash the screen."
  (decode-escape-sequence (get-string-capability "flash_screen")))

(define (emit-newline)
  "Emit escape sequence for newline."
  (decode-escape-sequence (get-string-capability "newline")))

;;; Parameterized editing functions
(define (emit-parm-dch count)
  "Emit escape sequence to delete COUNT characters."
  (let ((seq (get-string-capability "parm_dch")))
    (if seq
        (substitute-params seq count)
        "")))

(define (emit-parm-delete-line count)
  "Emit escape sequence to delete COUNT lines."
  (let ((seq (get-string-capability "parm_delete_line")))
    (if seq
        (substitute-params seq count)
        "")))

(define (emit-parm-ich count)
  "Emit escape sequence to insert COUNT characters."
  (let ((seq (get-string-capability "parm_ich")))
    (if seq
        (substitute-params seq count)
        "")))

(define (emit-parm-insert-line count)
  "Emit escape sequence to insert COUNT lines."
  (let ((seq (get-string-capability "parm_insert_line")))
    (if seq
        (substitute-params seq count)
        "")))

(define (emit-parm-index count)
  "Emit escape sequence to scroll forward COUNT lines."
  (let ((seq (get-string-capability "parm_index")))
    (if seq
        (substitute-params seq count)
        "")))

(define (emit-parm-rindex count)
  "Emit escape sequence to scroll reverse COUNT lines."
  (let ((seq (get-string-capability "parm_rindex")))
    (if seq
        (substitute-params seq count)
        "")))

;;; Additional mode functions
(define (emit-enter-secure-mode)
  "Emit escape sequence to enter secure/invisible mode."
  (decode-escape-sequence (get-string-capability "enter_secure_mode")))

(define (emit-enter-italics-mode)
  "Emit escape sequence to enter italics mode."
  (decode-escape-sequence (get-string-capability "enter_italics_mode")))

(define (emit-exit-italics-mode)
  "Emit escape sequence to exit italics mode."
  (decode-escape-sequence (get-string-capability "exit_italics_mode")))

(define (emit-enter-alt-charset-mode)
  "Emit escape sequence to enter alternate character set mode."
  (decode-escape-sequence (get-string-capability "enter_alt_charset_mode")))

(define (emit-exit-alt-charset-mode)
  "Emit escape sequence to exit alternate character set mode."
  (decode-escape-sequence (get-string-capability "exit_alt_charset_mode")))

(define (emit-enter-am-mode)
  "Emit escape sequence to turn on automatic margins."
  (decode-escape-sequence (get-string-capability "enter_am_mode")))

(define (emit-exit-am-mode)
  "Emit escape sequence to turn off automatic margins."
  (decode-escape-sequence (get-string-capability "exit_am_mode")))

(define (emit-enter-ca-mode)
  "Emit escape sequence to enter cursor addressing mode."
  (decode-escape-sequence (get-string-capability "enter_ca_mode")))

(define (emit-exit-ca-mode)
  "Emit escape sequence to exit cursor addressing mode."
  (decode-escape-sequence (get-string-capability "exit_ca_mode")))

(define (emit-keypad-xmit)
  "Emit escape sequence to put keypad in transmit mode."
  (decode-escape-sequence (get-string-capability "keypad_xmit")))

(define (emit-keypad-local)
  "Emit escape sequence to put keypad in local mode."
  (decode-escape-sequence (get-string-capability "keypad_local")))

(define (emit-meta-on)
  "Emit escape sequence to turn on meta mode."
  (decode-escape-sequence (get-string-capability "meta_on")))

(define (emit-meta-off)
  "Emit escape sequence to turn off meta mode."
  (decode-escape-sequence (get-string-capability "meta_off")))

;;; Color functions
(define (emit-set-a-background color)
  "Emit escape sequence to set ANSI background COLOR."
  (let ((seq (get-string-capability "set_a_background")))
    (if seq
        (substitute-params seq color)
        "")))

(define (emit-set-a-foreground color)
  "Emit escape sequence to set ANSI foreground COLOR."
  (let ((seq (get-string-capability "set_a_foreground")))
    (if seq
        (substitute-params seq color)
        "")))

(define (emit-set-background color)
  "Emit escape sequence to set background COLOR."
  (let ((seq (get-string-capability "set_background")))
    (if seq
        (substitute-params seq color)
        "")))

(define (emit-set-foreground color)
  "Emit escape sequence to set foreground COLOR."
  (let ((seq (get-string-capability "set_foreground")))
    (if seq
        (substitute-params seq color)
        "")))

(define (emit-orig-pair)
  "Emit escape sequence to set original color pair."
  (decode-escape-sequence (get-string-capability "orig_pair")))

;;; Tab functions
(define (emit-tab)
  "Emit escape sequence for tab."
  (decode-escape-sequence (get-string-capability "tab")))

(define (emit-set-tab)
  "Emit escape sequence to set tab stop at current position."
  (decode-escape-sequence (get-string-capability "set_tab")))

(define (emit-clear-all-tabs)
  "Emit escape sequence to clear all tab stops."
  (decode-escape-sequence (get-string-capability "clear_all_tabs")))

;;; Printer functions
(define (emit-print-screen)
  "Emit escape sequence to print screen."
  (decode-escape-sequence (get-string-capability "print_screen")))

(define (emit-prtr-on)
  "Emit escape sequence to turn printer on."
  (decode-escape-sequence (get-string-capability "prtr_on")))

(define (emit-prtr-off)
  "Emit escape sequence to turn printer off."
  (decode-escape-sequence (get-string-capability "prtr_off")))

;;; Margin functions
(define (emit-set-left-margin-parm col)
  "Emit escape sequence to set left margin at column COL."
  (let ((seq (get-string-capability "set_left_margin_parm")))
    (if seq
        (substitute-params seq col)
        "")))

(define (emit-set-lr-margin left right)
  "Emit escape sequence to set left and right margins."
  (let ((seq (get-string-capability "set_lr_margin")))
    (if seq
        (substitute-params seq left right)
        "")))

(define (emit-set-right-margin-parm col)
  "Emit escape sequence to set right margin at column COL."
  (let ((seq (get-string-capability "set_right_margin_parm")))
    (if seq
        (substitute-params seq col)
        "")))

(define (emit-clear-margins)
  "Emit escape sequence to clear margins."
  (decode-escape-sequence (get-string-capability "clear_margins")))

;;; Memory functions
(define (emit-memory-lock)
  "Emit escape sequence to lock memory above cursor."
  (decode-escape-sequence (get-string-capability "memory_lock")))

(define (emit-memory-unlock)
  "Emit escape sequence to unlock memory."
  (decode-escape-sequence (get-string-capability "memory_unlock")))

;;; Special key sequences
(define (emit-key-sdc)
  "Get escape sequence for shift+delete key."
  (decode-escape-sequence (get-string-capability "key_sdc")))

(define (emit-key-send)
  "Get escape sequence for shift+end key."
  (decode-escape-sequence (get-string-capability "key_send")))

(define (emit-key-shome)
  "Get escape sequence for shift+home key."
  (decode-escape-sequence (get-string-capability "key_shome")))

(define (emit-key-sic)
  "Get escape sequence for shift+insert key."
  (decode-escape-sequence (get-string-capability "key_sic")))

(define (emit-key-sleft)
  "Get escape sequence for shift+left arrow key."
  (decode-escape-sequence (get-string-capability "key_sleft")))

(define (emit-key-snext)
  "Get escape sequence for shift+next key."
  (decode-escape-sequence (get-string-capability "key_snext")))

(define (emit-key-sprevious)
  "Get escape sequence for shift+previous key."
  (decode-escape-sequence (get-string-capability "key_sprevious")))

(define (emit-key-sright)
  "Get escape sequence for shift+right arrow key."
  (decode-escape-sequence (get-string-capability "key_sright")))

(define (emit-key-a1)
  "Get escape sequence for upper left of keypad."
  (decode-escape-sequence (get-string-capability "key_a1")))

(define (emit-key-a3)
  "Get escape sequence for upper right of keypad."
  (decode-escape-sequence (get-string-capability "key_a3")))

(define (emit-key-b2)
  "Get escape sequence for center of keypad."
  (decode-escape-sequence (get-string-capability "key_b2")))

(define (emit-key-beg)
  "Get escape sequence for begin key."
  (decode-escape-sequence (get-string-capability "key_beg")))

(define (emit-key-c1)
  "Get escape sequence for lower left of keypad."
  (decode-escape-sequence (get-string-capability "key_c1")))

(define (emit-key-c3)
  "Get escape sequence for lower right of keypad."
  (decode-escape-sequence (get-string-capability "key_c3")))

(define (emit-key-btab)
  "Get escape sequence for back-tab key."
  (decode-escape-sequence (get-string-capability "key_btab")))

(define (emit-key-mouse)
  "Get escape sequence for mouse event."
  (decode-escape-sequence (get-string-capability "key_mouse")))

(define (emit-key-ppage)
  "Get escape sequence for previous page key."
  (decode-escape-sequence (get-string-capability "key_ppage")))

(define (emit-key-npage)
  "Get escape sequence for next page key."
  (decode-escape-sequence (get-string-capability "key_npage")))

(define (emit-key-sf)
  "Get escape sequence for scroll forward key."
  (decode-escape-sequence (get-string-capability "key_sf")))

(define (emit-key-sr)
  "Get escape sequence for scroll reverse key."
  (decode-escape-sequence (get-string-capability "key_sr")))

;;; Initialization and reset functions
(define (emit-init-2string)
  "Emit initialization string 2."
  (decode-escape-sequence (get-string-capability "init_2string")))

(define (emit-reset-1string)
  "Emit reset string 1."
  (decode-escape-sequence (get-string-capability "reset_1string")))

(define (emit-reset-2string)
  "Emit reset string 2."
  (decode-escape-sequence (get-string-capability "reset_2string")))

;;; Character set functions
(define (emit-acs-chars)
  "Get alternate character set mapping."
  (decode-escape-sequence (get-string-capability "acs_chars")))

;;; User-defined sequences
(define (emit-user6)
  "Emit user-defined string 6."
  (decode-escape-sequence (get-string-capability "user6")))

(define (emit-user7)
  "Emit user-defined string 7."
  (decode-escape-sequence (get-string-capability "user7")))

(define (emit-user8)
  "Emit user-defined string 8."
  (decode-escape-sequence (get-string-capability "user8")))

(define (emit-user9)
  "Emit user-defined string 9."
  (decode-escape-sequence (get-string-capability "user9")))

;;; Repeat character function
(define (emit-repeat-char char count)
  "Emit escape sequence to repeat CHAR COUNT times."
  (let ((seq (get-string-capability "repeat_char")))
    (if seq
        (substitute-params seq (char->integer char) count)
        "")))

;;; Status line functions
(define (emit-dis-status-line)
  "Emit escape sequence to disable status line."
  (decode-escape-sequence (get-string-capability "dis_status_line")))

(define (emit-from-status-line)
  "Emit escape sequence to return from status line."
  (decode-escape-sequence (get-string-capability "from_status_line")))

(define (emit-to-status-line col)
  "Emit escape sequence to go to status line at column COL."
  (let ((seq (get-string-capability "to_status_line")))
    (if seq
        (substitute-params seq col)
        "")))

;;; Initialization and file functions
(define (emit-init-file)
  "Get initialization file path."
  (get-string-capability "init_file"))

(define (emit-init-3string)
  "Emit initialization string 3."
  (decode-escape-sequence (get-string-capability "init_3string")))

(define (emit-reset-file)
  "Get reset file path."
  (get-string-capability "reset_file"))

(define (emit-reset-3string)
  "Emit reset string 3."
  (decode-escape-sequence (get-string-capability "reset_3string")))

;;; Character set and special mode functions
(define (emit-ena-acs)
  "Emit escape sequence to enable alternate character set."
  (decode-escape-sequence (get-string-capability "ena_acs")))

(define (emit-enter-pc-charset-mode)
  "Emit escape sequence to enter PC character set mode."
  (decode-escape-sequence (get-string-capability "enter_pc_charset_mode")))

(define (emit-exit-pc-charset-mode)
  "Emit escape sequence to exit PC character set mode."
  (decode-escape-sequence (get-string-capability "exit_pc_charset_mode")))

(define (emit-enter-shadow-mode)
  "Emit escape sequence to enter shadow mode."
  (decode-escape-sequence (get-string-capability "enter_shadow_mode")))

(define (emit-exit-shadow-mode)
  "Emit escape sequence to exit shadow mode."
  (decode-escape-sequence (get-string-capability "exit_shadow_mode")))

(define (emit-enter-subscript-mode)
  "Emit escape sequence to enter subscript mode."
  (decode-escape-sequence (get-string-capability "enter_subscript_mode")))

(define (emit-exit-subscript-mode)
  "Emit escape sequence to exit subscript mode."
  (decode-escape-sequence (get-string-capability "exit_subscript_mode")))

(define (emit-enter-superscript-mode)
  "Emit escape sequence to enter superscript mode."
  (decode-escape-sequence (get-string-capability "enter_superscript_mode")))

(define (emit-exit-superscript-mode)
  "Emit escape sequence to exit superscript mode."
  (decode-escape-sequence (get-string-capability "exit_superscript_mode")))

;;; Color initialization and original colors
(define (emit-initialize-color color red green blue)
  "Emit escape sequence to initialize COLOR to RGB values."
  (let ((seq (get-string-capability "initialize_color")))
    (if seq
        (substitute-params seq color red green blue)
        "")))

(define (emit-orig-colors)
  "Emit escape sequence to restore original colors."
  (decode-escape-sequence (get-string-capability "orig_colors")))

;;; Additional key functions
(define (emit-key-find)
  "Get escape sequence for find key."
  (decode-escape-sequence (get-string-capability "key_find")))

(define (emit-key-select)
  "Get escape sequence for select key."
  (decode-escape-sequence (get-string-capability "key_select")))

;;; Updated utility functions
(define (terminfo-has-color)
  "Check if terminal supports color."
  (or (get-boolean-capability "has_colors")
      (> (or (get-numeric-capability "colors") 0) 0)))

(define (terminfo-get-max-colors)
  "Get the maximum number of colors supported."
  (or (get-numeric-capability "colors") 0))

(define (terminfo-get-max-pairs)
  "Get the maximum number of color pairs supported."
  (or (get-numeric-capability "max_color_pairs") 0))

;;; Input parser for terminal escape sequences
;;; This parser maintains state and processes input byte by byte

;;; Record type for input parser state
(define-record-type <input-parser>
  (make-input-parser-internal buffer key-map timeout)
  input-parser?
  (buffer parser-buffer set-parser-buffer!)
  (key-map parser-key-map)
  (timeout parser-timeout set-parser-timeout!))

;;; Global parser instance
(define *current-parser* #f)

(define (make-input-parser)
  "Create a new input parser with key mappings from loaded terminfo data."
  (let ((key-map (build-key-map)))
    (set! *current-parser* 
          (make-input-parser-internal '() key-map 0))
    *current-parser*))

(define (build-key-map)
  "Build a mapping of escape sequences to key symbols from terminfo data."
  (if (not (terminfo? *terminfo-data*))
      '()
      (let ((string-caps (terminfo-string-caps *terminfo-data*))
            (key-map '()))
        ;; Build map of escape sequences to key names
        (for-each
         (lambda (cap-pair)
           (let ((cap-name (car cap-pair))
                 (cap-value (cadr cap-pair)))
             (when (and cap-value 
                       (string-prefix? "key_" cap-name)
                       (> (string-length cap-value) 0))
               ;; Decode the escape sequence and map it to symbol
               (let ((decoded-seq (decode-escape-sequence cap-value))
                     (key-symbol (string->symbol cap-name)))
                 (when (> (string-length decoded-seq) 0)
                   (set! key-map (cons (cons decoded-seq key-symbol) key-map)))))))
         string-caps)
        
        ;; Sort by length (longest first) for proper matching
        (sort key-map (lambda (a b) (> (string-length (car a)) 
                                      (string-length (car b))))))))

(define (reset-input-parser)
  "Reset the input parser state."
  (when *current-parser*
    (set-parser-buffer! *current-parser* '())
    (set-parser-timeout! *current-parser* 0)))

(define (get-parser-state)
  "Get the current parser state as a string."
  (if *current-parser*
      (list->string (reverse (parser-buffer *current-parser*)))
      ""))

(define (parse-input-byte byte)
  "Parse a single input byte and return result.
   Returns: character, symbol (like 'key_f5), 'incomplete, or 'incorrect"
  
  (unless *current-parser*
    (make-input-parser))
  
  (let ((char (integer->char byte))
        (buffer (parser-buffer *current-parser*))
        (key-map (parser-key-map *current-parser*)))
    
    ;; Add byte to buffer
    (set-parser-buffer! *current-parser* (cons char buffer))
    (let ((current-seq (list->string (reverse (parser-buffer *current-parser*)))))
      
      (cond
       ;; Check for exact key match
       ((find-exact-key-match current-seq key-map)
        => (lambda (key-symbol)
             (reset-input-parser)
             key-symbol))
       
       ;; Check for complex modifier sequences before potential matches
       ((and (> (length (parser-buffer *current-parser*)) 5)
             (parse-complex-escape-sequence))
        => (lambda (complex-key)
             (reset-input-parser)
             complex-key))
       
       ;; Check if current sequence could be start of a key
       ((find-potential-key-match current-seq key-map)
        'incomplete)
       
       ;; Handle special cases
       ((= byte 127) ; DEL key
        (reset-input-parser)
        'key_backspace)
       
       ;; ESC - might be start of sequence or Alt+key combination
       ((= byte 27) ; ESC - might be start of sequence
        (if (= (length (parser-buffer *current-parser*)) 1)
            'incomplete  ; Just started ESC sequence
            (begin
              (reset-input-parser)
              #\escape)))  ; Single ESC
       
       ;; Check for Alt+key combinations (ESC followed by printable char)
       ((and (= (length (parser-buffer *current-parser*)) 2)
             (char=? (cadr (parser-buffer *current-parser*)) #\escape)
             (char-graphic? char))
        (reset-input-parser)
        (string->symbol (string-append "alt-" (string char))))
       
       ;; Check for Alt+function keys (ESC followed by function key sequence)
       ((and (> (length (parser-buffer *current-parser*)) 1)
             (char=? (car (reverse (parser-buffer *current-parser*))) #\escape))
        ;; This might be Alt+function key, continue parsing
        'incomplete)
       
       ;; Single printable character
       ((and (= (length (parser-buffer *current-parser*)) 1)
             (or (char-alphabetic? char)
                 (char-numeric? char)
                 (char-graphic? char)
                 (char-whitespace? char)))
        (reset-input-parser)
        char)
       
       ;; Control characters
       ((and (= (length (parser-buffer *current-parser*)) 1)
             (< byte 32))
        (reset-input-parser)
        (case byte
          ((1) 'ctrl-a)     ; Ctrl+A = SOH
          ((2) 'ctrl-b)     ; Ctrl+B = STX  
          ((3) 'ctrl-c)     ; Ctrl+C = ETX (interrupt)
          ((4) 'ctrl-d)     ; Ctrl+D = EOT (EOF)
          ((5) 'ctrl-e)     ; Ctrl+E = ENQ
          ((6) 'ctrl-f)     ; Ctrl+F = ACK
          ((7) 'ctrl-g)     ; Ctrl+G = BEL (bell)
          ((8) 'key_backspace) ; Ctrl+H = BS (backspace)
          ((9) #\tab)       ; Ctrl+I = HT (tab)
          ((10) #\newline)  ; Ctrl+J = LF (newline)
          ((11) 'ctrl-k)    ; Ctrl+K = VT (vertical tab)
          ((12) 'ctrl-l)    ; Ctrl+L = FF (form feed)
          ((13) #\return)   ; Ctrl+M = CR (carriage return)
          ((14) 'ctrl-n)    ; Ctrl+N = SO (shift out)
          ((15) 'ctrl-o)    ; Ctrl+O = SI (shift in)
          ((16) 'ctrl-p)    ; Ctrl+P = DLE
          ((17) 'ctrl-q)    ; Ctrl+Q = XON (flow control)
          ((18) 'ctrl-r)    ; Ctrl+R = DC2
          ((19) 'ctrl-s)    ; Ctrl+S = XOFF (flow control)
          ((20) 'ctrl-t)    ; Ctrl+T = DC4
          ((21) 'ctrl-u)    ; Ctrl+U = NAK
          ((22) 'ctrl-v)    ; Ctrl+V = SYN
          ((23) 'ctrl-w)    ; Ctrl+W = ETB
          ((24) 'ctrl-x)    ; Ctrl+X = CAN
          ((25) 'ctrl-y)    ; Ctrl+Y = EM
          ((26) 'ctrl-z)    ; Ctrl+Z = SUB (suspend)
          ((27) #\escape)   ; Ctrl+[ = ESC
          ((28) 'ctrl-backslash) ; Ctrl+\ = FS
          ((29) 'ctrl-right-bracket) ; Ctrl+] = GS
          ((30) 'ctrl-caret) ; Ctrl+^ = RS
          ((31) 'ctrl-underscore) ; Ctrl+_ = US
          (else char)))
       
       ;; Buffer too long or invalid sequence
       ((> (length (parser-buffer *current-parser*)) 10)
        (reset-input-parser)
        'incorrect)
       
       ;; Default: incorrect sequence
       (else
        (reset-input-parser)
        'incorrect)))))

(define (find-exact-key-match seq key-map)
  "Find exact match for sequence in key map."
  (let ((match (assoc seq key-map)))
    (if match (cdr match) #f)))

(define (find-potential-key-match seq key-map)
  "Check if sequence could be the beginning of a key sequence."
  (any (lambda (key-pair)
         (string-prefix? seq (car key-pair)))
       key-map))

(define (string-prefix? prefix str)
  "Check if PREFIX is a prefix of STR."
  (and (<= (string-length prefix) (string-length str))
       (string=? prefix (substring str 0 (string-length prefix)))))

;;; Mouse input parsing support
(define (parse-mouse-input byte)
  "Parse mouse input byte. Returns mouse event or 'incomplete."
  ;; This is a simplified mouse parser for standard X10/X11 mouse reporting
  ;; Real implementation would need to handle different mouse protocols
  (unless *current-parser*
    (make-input-parser))
  
  (let ((buffer (parser-buffer *current-parser*)))
    (set-parser-buffer! *current-parser* (cons (integer->char byte) buffer))
    (let ((current-seq (list->string (reverse (parser-buffer *current-parser*)))))
      
      (cond
       ;; Standard mouse sequence: ESC[M + 3 bytes
       ((and (>= (length buffer) 4)
             (string-prefix? "\033[M" current-seq))
        (let ((button (- (char->integer (list-ref buffer 3)) 32))
              (x (- (char->integer (list-ref buffer 2)) 32))
              (y (- (char->integer (list-ref buffer 1)) 32)))
          (reset-input-parser)
          `(mouse-event ,button ,x ,y)))
       
       ;; SGR mouse sequence: ESC[<...M or ESC[<...m
       ((and (string-prefix? "\033[<" current-seq)
             (or (string-suffix? "M" current-seq)
                 (string-suffix? "m" current-seq)))
        (reset-input-parser)
        'mouse-event-sgr)  ; Simplified for now
       
       ;; Incomplete mouse sequence
       ((or (string-prefix? "\033[M" current-seq)
            (string-prefix? "\033[<" current-seq))
        'incomplete)
       
       ;; Not a mouse sequence, fall back to regular parsing
       (else
        (set-parser-buffer! *current-parser* (cdr buffer)) ; Remove last byte
        (parse-input-byte byte))))))

(define (string-suffix? suffix str)
  "Check if SUFFIX is a suffix of STR."
  (and (<= (string-length suffix) (string-length str))
       (string=? suffix 
                 (substring str 
                           (- (string-length str) (string-length suffix))
                           (string-length str)))))

;;; Utility functions for input handling
(define (is-function-key? symbol)
  "Check if SYMBOL represents a function key."
  (and (symbol? symbol)
       (string-prefix? "key_f" (symbol->string symbol))))

(define (is-arrow-key? symbol)
  "Check if SYMBOL represents an arrow key."
  (and (symbol? symbol)
       (memq symbol '(key_up key_down key_left key_right))))

(define (is-special-key? symbol)
  "Check if SYMBOL represents a special key (not a regular character)."
  (and (symbol? symbol)
       (string-prefix? "key_" (symbol->string symbol))))

;;; Input processing examples and utilities
(define (process-input-string input-str)
  "Process a string of input bytes and return list of parsed results.
   Useful for testing the parser."
  (reset-input-parser)
  (map (lambda (char)
         (parse-input-byte (char->integer char)))
       (string->list input-str)))

(define (simulate-key-input key-symbol)
  "Simulate input for a specific key symbol. Returns the byte sequence."
  (if (not (terminfo? *terminfo-data*))
      #f
      (let ((key-name (symbol->string key-symbol)))
        (get-string-capability key-name))))

;;; Restore utility functions
;;; CJK and Unicode utility functions
(define (is-cjk-character? char)
  "Check if character is in CJK Unicode ranges (including extended blocks)."
  (let ((codepoint (char->integer char)))
    (or
     ;; Basic CJK Unified Ideographs (most common)
     (and (>= codepoint #x4E00) (<= codepoint #x9FFF))
     ;; Hiragana
     (and (>= codepoint #x3040) (<= codepoint #x309F))
     ;; Katakana  
     (and (>= codepoint #x30A0) (<= codepoint #x30FF))
     ;; Hangul Syllables
     (and (>= codepoint #xAC00) (<= codepoint #xD7AF))
     ;; CJK Symbols and Punctuation
     (and (>= codepoint #x3000) (<= codepoint #x303F))
     ;; Halfwidth and Fullwidth Forms
     (and (>= codepoint #xFF00) (<= codepoint #xFFEF))
     
     ;; Extended CJK Ideograph blocks (the obscure ones you mentioned)
     ;; CJK Unified Ideographs Extension B
     (and (>= codepoint #x20000) (<= codepoint #x2A6DF))
     ;; CJK Unified Ideographs Extension C  
     (and (>= codepoint #x2A700) (<= codepoint #x2B739))
     ;; CJK Unified Ideographs Extension D
     (and (>= codepoint #x2B740) (<= codepoint #x2B81D))
     ;; CJK Unified Ideographs Extension E
     (and (>= codepoint #x2B820) (<= codepoint #x2CEA1))
     ;; CJK Unified Ideographs Extension F
     (and (>= codepoint #x2CEB0) (<= codepoint #x2EBE0))
     ;; CJK Unified Ideographs Extension G
     (and (>= codepoint #x2EBF0) (<= codepoint #x2EE5D))
     ;; CJK Compatibility Ideographs Supplement
     (and (>= codepoint #x2F800) (<= codepoint #x2FA1D))
     ;; CJK Unified Ideographs Extension H
     (and (>= codepoint #x30000) (<= codepoint #x3134A))
     ;; CJK Unified Ideographs Extension I
     (and (>= codepoint #x31350) (<= codepoint #x323AF))
     
     ;; Additional CJK-related blocks for completeness
     ;; CJK Radicals Supplement
     (and (>= codepoint #x2E80) (<= codepoint #x2EFF))
     ;; Kangxi Radicals
     (and (>= codepoint #x2F00) (<= codepoint #x2FDF))
     ;; Ideographic Description Characters
     (and (>= codepoint #x2FF0) (<= codepoint #x2FFF))
     ;; CJK Compatibility Ideographs
     (and (>= codepoint #xF900) (<= codepoint #xFAFF))
     ;; Hangul Jamo (basic Korean components)
     (and (>= codepoint #x1100) (<= codepoint #x11FF))
     ;; Hangul Jamo Extended-A
     (and (>= codepoint #xA960) (<= codepoint #xA97F))
     ;; Hangul Jamo Extended-B  
     (and (>= codepoint #xD7B0) (<= codepoint #xD7FF))
     ;; Katakana Phonetic Extensions
     (and (>= codepoint #x31F0) (<= codepoint #x31FF))
     ;; CJK Strokes
     (and (>= codepoint #x31C0) (<= codepoint #x31EF)))))

(define (get-cjk-block-name codepoint)
  "Get the name of the CJK Unicode block for a given codepoint."
  (cond
   ;; Basic blocks
   ((and (>= codepoint #x4E00) (<= codepoint #x9FFF)) "CJK Unified Ideographs")
   ((and (>= codepoint #x3040) (<= codepoint #x309F)) "Hiragana")
   ((and (>= codepoint #x30A0) (<= codepoint #x30FF)) "Katakana")
   ((and (>= codepoint #xAC00) (<= codepoint #xD7AF)) "Hangul Syllables")
   ((and (>= codepoint #x3000) (<= codepoint #x303F)) "CJK Symbols and Punctuation")
   ((and (>= codepoint #xFF00) (<= codepoint #xFFEF)) "Halfwidth and Fullwidth Forms")
   
   ;; Extended ideograph blocks
   ((and (>= codepoint #x20000) (<= codepoint #x2A6DF)) "CJK Unified Ideographs Extension B")
   ((and (>= codepoint #x2A700) (<= codepoint #x2B739)) "CJK Unified Ideographs Extension C")
   ((and (>= codepoint #x2B740) (<= codepoint #x2B81D)) "CJK Unified Ideographs Extension D")
   ((and (>= codepoint #x2B820) (<= codepoint #x2CEA1)) "CJK Unified Ideographs Extension E")
   ((and (>= codepoint #x2CEB0) (<= codepoint #x2EBE0)) "CJK Unified Ideographs Extension F")
   ((and (>= codepoint #x2EBF0) (<= codepoint #x2EE5D)) "CJK Unified Ideographs Extension G")
   ((and (>= codepoint #x2F800) (<= codepoint #x2FA1D)) "CJK Compatibility Ideographs Supplement")
   ((and (>= codepoint #x30000) (<= codepoint #x3134A)) "CJK Unified Ideographs Extension H")
   ((and (>= codepoint #x31350) (<= codepoint #x323AF)) "CJK Unified Ideographs Extension I")
   
   ;; Additional blocks
   ((and (>= codepoint #x2E80) (<= codepoint #x2EFF)) "CJK Radicals Supplement")
   ((and (>= codepoint #x2F00) (<= codepoint #x2FDF)) "Kangxi Radicals")
   ((and (>= codepoint #x2FF0) (<= codepoint #x2FFF)) "Ideographic Description Characters")
   ((and (>= codepoint #xF900) (<= codepoint #xFAFF)) "CJK Compatibility Ideographs")
   ((and (>= codepoint #x1100) (<= codepoint #x11FF)) "Hangul Jamo")
   ((and (>= codepoint #xA960) (<= codepoint #xA97F)) "Hangul Jamo Extended-A")
   ((and (>= codepoint #xD7B0) (<= codepoint #xD7FF)) "Hangul Jamo Extended-B")
   ((and (>= codepoint #x31F0) (<= codepoint #x31FF)) "Katakana Phonetic Extensions")
   ((and (>= codepoint #x31C0) (<= codepoint #x31EF)) "CJK Strokes")
   
   (else "Not CJK")))

(define (get-character-info char)
  "Get comprehensive information about a character including CJK block."
  (let ((codepoint (char->integer char)))
    `((character . ,char)
      (codepoint . ,codepoint)
      (codepoint-hex . ,(string-upcase (number->string codepoint 16)))
      (utf8-bytes . ,(char->utf8-bytes char))
      (is-cjk . ,(is-cjk-character? char))
      (cjk-block . ,(get-cjk-block-name codepoint))
      (is-ascii . ,(< codepoint 128))
      (utf8-byte-count . ,(length (char->utf8-bytes char))))))

(define (char->utf8-bytes char)
  "Convert character to list of UTF-8 bytes."
  (let ((codepoint (char->integer char)))
    (cond
     ;; 1-byte (ASCII)
     ((<= codepoint #x7F)
      (list codepoint))
     
     ;; 2-byte
     ((<= codepoint #x7FF)
      (list (+ #b11000000 (ash codepoint -6))
            (+ #b10000000 (logand codepoint #b111111))))
     
     ;; 3-byte (most CJK)
     ((<= codepoint #xFFFF)
      (list (+ #b11100000 (ash codepoint -12))
            (+ #b10000000 (logand (ash codepoint -6) #b111111))
            (+ #b10000000 (logand codepoint #b111111))))
     
     ;; 4-byte
     (else
      (list (+ #b11110000 (ash codepoint -18))
            (+ #b10000000 (logand (ash codepoint -12) #b111111))
            (+ #b10000000 (logand (ash codepoint -6) #b111111))
            (+ #b10000000 (logand codepoint #b111111)))))))

;;; Enhanced testing functions for comprehensive CJK
(define (test-extended-cjk)
  "Test extended CJK character ranges including rare ideographs."
  (display "\n=== Extended CJK Character Testing ===\n")
  
  ;; Note: Many of these extended characters may not display properly
  ;; unless you have comprehensive CJK fonts installed
  (let ((test-ranges 
         `(("Basic CJK" #x4E00 #x4E01 #x4E02)           ; 一二三 area
           ("Hiragana" #x3042 #x3044 #x3046)            ; あいう
           ("Katakana" #x30A2 #x30A4 #x30A6)            ; アイウ  
           ("Hangul" #xAC00 #xAC01 #xAC02)              ; 가각간
           ("CJK Ext-B" #x20000 #x20001 #x20002)        ; Very rare
           ("CJK Ext-C" #x2A700 #x2A701 #x2A702)        ; Even rarer
           ("CJK Compat" #x2F800 #x2F801 #x2F802))))    ; Compatibility
    
    (for-each
     (lambda (range-info)
       (let ((name (car range-info))
             (codepoints (cdr range-info)))
         (format #t "\n~a:\n" name)
         (for-each
          (lambda (cp)
            (let* ((char (integer->char cp))
                   (info (get-character-info char)))
              (format #t "  U+~4,'0X: ~a → ~a\n" 
                     cp 
                     (if (< cp #x10000) char "?")  ; May not display
                     (assoc-ref info 'cjk-block))))
          codepoints)))
     test-ranges)))

(define (test-cjk-coverage)
  "Test the coverage of CJK character detection."
  (display "\n=== CJK Detection Coverage Test ===\n")
  
  ;; Test various Unicode ranges
  (let ((test-chars 
         `((#x0041 "Latin A" #f)              ; ASCII
           (#x00E9 "Latin é" #f)              ; Extended Latin
           (#x4E00 "CJK 一" #t)               ; Basic CJK
           (#x3042 "Hiragana あ" #t)          ; Hiragana
           (#x30A2 "Katakana ア" #t)          ; Katakana
           (#xAC00 "Hangul 가" #t)            ; Hangul
           (#x20000 "Ext-B" #t)              ; Extension B (rare)
           (#x2A700 "Ext-C" #t)              ; Extension C (very rare)
           (#x30000 "Ext-H" #t)              ; Extension H (newest)
           (#x1F600 "Emoji 😀" #f))))         ; Emoji (not CJK)
    
    (for-each
     (lambda (test-case)
       (let* ((codepoint (car test-case))
              (description (cadr test-case))
              (expected-cjk (caddr test-case))
              (char (integer->char codepoint))
              (actual-cjk (is-cjk-character? char))
              (status (if (eq? expected-cjk actual-cjk) "✓" "✗")))
         (format #t "~a U+~4,'0X ~a: CJK=~a (expected ~a)\n"
                status codepoint description actual-cjk expected-cjk)))
     test-chars)))

(define (show-cjk-statistics)
  "Show statistics about CJK Unicode blocks."
  (display "\n=== CJK Unicode Block Statistics ===\n")
  
  (let ((cjk-blocks
         `(("CJK Unified Ideographs" #x4E00 #x9FFF)
           ("CJK Extension B" #x20000 #x2A6DF)
           ("CJK Extension C" #x2A700 #x2B739)
           ("CJK Extension D" #x2B740 #x2B81D)
           ("CJK Extension E" #x2B820 #x2CEA1)
           ("CJK Extension F" #x2CEB0 #x2EBE0)
           ("CJK Extension G" #x2EBF0 #x2EE5D)
           ("CJK Extension H" #x30000 #x3134A)
           ("CJK Extension I" #x31350 #x323AF)
           ("Hiragana" #x3040 #x309F)
           ("Katakana" #x30A0 #x30FF)
           ("Hangul Syllables" #xAC00 #xD7AF))))
    
    (for-each
     (lambda (block)
       (let* ((name (car block))
              (start (cadr block))
              (end (caddr block))
              (count (+ 1 (- end start))))
         (format #t "~30a: U+~5,'0X-U+~5,'0X (~7d chars)\n" 
                name start end count)))
     cjk-blocks)
    
    (let ((total (apply + (map (lambda (block) 
                                (+ 1 (- (caddr block) (cadr block))))
                              cjk-blocks))))
      (format #t "\nTotal CJK characters supported: ~d\n" total))))

;;; Original CJK testing function (restored)
(define (test-cjk-input)
  "Test CJK character input parsing."
  (display "=== CJK Input Testing ===\n")
  (make-input-parser)
  
  ;; Test individual CJK characters
  (let ((test-chars '(#\あ #\漢 #\한 #\。)))
    (for-each
     (lambda (char)
       (let ((utf8-bytes (char->utf8-bytes char))
             (char-info (get-character-info char)))
         (format #t "\nTesting character: ~a\n" char)
         (format #t "Character info: ~a\n" char-info)
         (format #t "UTF-8 bytes: ~a\n" utf8-bytes)
         
         ;; Parse byte by byte
         (reset-input-parser)
         (let ((results (map parse-input-byte utf8-bytes)))
           (format #t "Parse results: ~a\n" results))))
     test-chars)))

(define (test-mixed-input)
  "Test mixed ASCII and CJK input."
  (display "\n=== Mixed Input Testing ===\n")
  (reset-input-parser)
  
  ;; Simulate "Hello こんにちは"
  (let ((mixed-string "Hello こんにちは"))
    (format #t "Testing string: ~s\n" mixed-string)
    
    ;; Convert to UTF-8 bytes
    (let ((utf8-bytes (string->utf8-bytes mixed-string)))
      (format #t "UTF-8 byte sequence: ~a\n" utf8-bytes)
      
      ;; Parse byte by byte
      (let ((results (map parse-input-byte utf8-bytes)))
        (format #t "Parse results: ~a\n" results)))))

(define (string->utf8-bytes str)
  "Convert string to list of UTF-8 bytes."
  (apply append (map char->utf8-bytes (string->list str))))

;;; IME simulation support
(define (simulate-ime-input romaji target-hiragana)
  "Simulate Input Method Editor behavior.
   In real terminals, this would involve complex escape sequences."
  (display "\n=== IME Simulation ===\n")
  (format #t "Romaji input: ~s\n" romaji)
  (format #t "Hiragana output: ~s\n" target-hiragana)
  (format #t "Note: Real IME involves complex terminal escape sequences\n")
  (format #t "      and application-level composition handling.\n")
  
  ;; Show the final character bytes
  (let ((hiragana-bytes (string->utf8-bytes target-hiragana)))
    (format #t "Final UTF-8 bytes: ~a\n" hiragana-bytes)
    (reset-input-parser)
    (let ((results (map parse-input-byte hiragana-bytes)))
      (format #t "Parser results: ~a\n" results))))

;;; Alternate Character Set (ACS) support
(define *acs-map* '())

(define (build-acs-map)
  "Build ACS character mapping from terminfo acsc capability."
  (let ((acsc-string (get-string-capability "acs_chars")))
    (if acsc-string
        (let ((decoded (decode-escape-sequence acsc-string)))
          (set! *acs-map* (parse-acsc-string decoded))
          *acs-map*)
        '())))

(define (parse-acsc-string acsc-str)
  "Parse acsc string into character mapping pairs."
  (let ((chars (string->list acsc-str))
        (mapping '()))
    (let loop ((remaining chars))
      (if (>= (length remaining) 2)
          (let ((input-char (car remaining))
                (output-char (cadr remaining)))
            (set! mapping (cons (cons input-char output-char) mapping))
            (loop (cddr remaining)))
          mapping))))

(define (get-acs-char input-char)
  "Get ACS character for input character, or return input if no mapping."
  (when (null? *acs-map*)
    (build-acs-map))
  (let ((mapping (assoc input-char *acs-map*)))
    (if mapping (cdr mapping) input-char)))

;;; Standard VT100 ACS character mappings (fallback if terminfo unavailable)
(define *vt100-acs-chars*
  '((#\j . "┘")    ; lower right corner  
    (#\k . "┐")    ; upper right corner
    (#\l . "┌")    ; upper left corner
    (#\m . "└")    ; lower left corner
    (#\n . "┼")    ; crossing lines
    (#\q . "─")    ; horizontal line
    (#\t . "├")    ; left tee
    (#\u . "┤")    ; right tee  
    (#\v . "┴")    ; bottom tee
    (#\w . "┬")    ; top tee
    (#\x . "│")    ; vertical line
    (#\a . "▒")    ; checker board (stipple)
    (#\f . "°")    ; degree symbol
    (#\g . "±")    ; plus/minus
    (#\h . "▒")    ; board of squares
    (#\i . "♦")    ; lantern symbol
    (#\o . "⎺")    ; scan line 1
    (#\p . "⎻")    ; scan line 3
    (#\r . "⎼")    ; scan line 7
    (#\s . "⎽")    ; scan line 9
    (#\0 . "█")    ; solid square block
    (#\` . "♦")    ; diamond
    (#\~ . "○")    ; bullet
    (#\, . "◢")    ; arrow pointing left
    (#\+ . "➤")    ; arrow pointing right
    (#\. . "▼")    ; arrow pointing down
    (#\- . "▲")    ; arrow pointing up
    (#\y . "≤")    ; less-than-or-equal-to
    (#\z . "≥")    ; greater-than-or-equal-to
    (#\{ . "π")    ; pi
    (#\| . "≠")    ; not-equal
    (#\} . "£")    ; UK pound sign
    (#\· . "·")))  ; centered dot

(define (get-vt100-acs-char input-char)
  "Get VT100 ACS character using built-in mapping."
  (let ((mapping (assoc input-char *vt100-acs-chars*)))
    (if mapping (cdr mapping) (string input-char))))

;;; ACS mode control functions
(define (emit-enter-acs-mode)
  "Emit escape sequence to enter alternate character set mode."
  (decode-escape-sequence (get-string-capability "enter_alt_charset_mode")))

(define (emit-exit-acs-mode)
  "Emit escape sequence to exit alternate character set mode."
  (decode-escape-sequence (get-string-capability "exit_alt_charset_mode")))

(define (draw-acs-string acs-input)
  "Convert ACS input string to output using terminfo mapping."
  (when (null? *acs-map*)
    (build-acs-map))
  (apply string
         (map (lambda (char)
                (let ((mapped (get-acs-char char)))
                  (if (char? mapped) mapped char)))
              (string->list acs-input))))

(define (draw-box x y width height)
  "Draw a box using ACS characters at position (x,y) with given dimensions."
  (let ((top-left (get-acs-char #\l))
        (top-right (get-acs-char #\k))
        (bottom-left (get-acs-char #\m))
        (bottom-right (get-acs-char #\j))
        (horizontal (get-acs-char #\q))
        (vertical (get-acs-char #\x)))
    
    ;; Enter ACS mode
    (display (emit-enter-acs-mode))
    
    ;; Draw top border
    (display (emit-cursor-address y x))
    (display top-left)
    (display (make-string (- width 2) horizontal))
    (display top-right)
    
    ;; Draw sides
    (do ((row (+ y 1) (+ row 1)))
        ((>= row (+ y height -1)))
      (display (emit-cursor-address row x))
      (display vertical)
      (display (emit-cursor-address row (+ x width -1)))
      (display vertical))
    
    ;; Draw bottom border
    (display (emit-cursor-address (+ y height -1) x))
    (display bottom-left)
    (display (make-string (- width 2) horizontal))
    (display bottom-right)
    
    ;; Exit ACS mode
    (display (emit-exit-acs-mode))))

(define (draw-simple-box x y width height)
  "Draw a simple box using Unicode box characters (modern alternative)."
  ;; Top border
  (display (emit-cursor-address y x))
  (display "┌")
  (display (make-string (- width 2) #\─))
  (display "┐")
  
  ;; Sides
  (do ((row (+ y 1) (+ row 1)))
      ((>= row (+ y height -1)))
    (display (emit-cursor-address row x))
    (display "│")
    (display (emit-cursor-address row (+ x width -1)))
    (display "│"))
  
  ;; Bottom border
  (display (emit-cursor-address (+ y height -1) x))
  (display "└")
  (display (make-string (- width 2) #\─))
  (display "┘"))

;;; ACS demonstration functions
(define (demo-acs-characters)
  "Demonstrate ACS character mappings."
  (display "\n=== ACS Character Demo ===\n")
  (build-acs-map)
  
  (if (null? *acs-map*)
      (begin
        (display "No ACS mapping in terminfo, using VT100 defaults:\n")
        (for-each
         (lambda (mapping)
           (let ((input (car mapping))
                 (output (cdr mapping)))
             (format #t "  '~a' → ~a\n" input output)))
         *vt100-acs-chars*))
      (begin
        (display "ACS mappings from terminfo:\n")
        (for-each
         (lambda (mapping)
           (let ((input (car mapping))
                 (output (cdr mapping)))
             (format #t "  '~a' → '~a'\n" input output)))
         *acs-map*)))
  
  (display "\nBox drawing characters:\n")
  (display "  ┌─┬─┐  (Unicode)\n")
  (display "  │ │ │\n") 
  (display "  ├─┼─┤\n")
  (display "  │ │ │\n")
  (display "  └─┴─┘\n")
  
  (display "\nACS mode box:\n")
  (display (emit-enter-acs-mode))
  (display "  ")
  (display (draw-acs-string "lqqqk"))
  (display "\n  ")
  (display (draw-acs-string "x   x"))
  (display "\n  ")
  (display (draw-acs-string "mqqqj"))
  (display (emit-exit-acs-mode))
  (display "\n"))

;;; Control character utility functions
(define (letter->ctrl-code letter)
  "Convert letter (A-Z or a-z) to control code value."
  (let ((upper-letter (char-upcase letter)))
    (if (and (char>=? upper-letter #\A) (char<=? upper-letter #\Z))
        (- (char->integer upper-letter) 64)
        #f)))

(define (ctrl-code->letter code)
  "Convert control code (1-26) back to letter."
  (if (and (>= code 1) (<= code 26))
      (integer->char (+ code 64))
      #f))

(define (is-ctrl-character? symbol)
  "Check if symbol represents a control character."
  (and (symbol? symbol)
       (string-prefix? "ctrl-" (symbol->string symbol))))

(define (ctrl-symbol->code symbol)
  "Convert control symbol to numeric code."
  (case symbol
    ('ctrl-a 1) ('ctrl-b 2) ('ctrl-c 3) ('ctrl-d 4) ('ctrl-e 5)
    ('ctrl-f 6) ('ctrl-g 7) ('ctrl-h 8) ('ctrl-i 9) ('ctrl-j 10)
    ('ctrl-k 11) ('ctrl-l 12) ('ctrl-m 13) ('ctrl-n 14) ('ctrl-o 15)
    ('ctrl-p 16) ('ctrl-q 17) ('ctrl-r 18) ('ctrl-s 19) ('ctrl-t 20)
    ('ctrl-u 21) ('ctrl-v 22) ('ctrl-w 23) ('ctrl-x 24) ('ctrl-y 25)
    ('ctrl-z 26) ('ctrl-backslash 28) ('ctrl-right-bracket 29) 
    ('ctrl-caret 30) ('ctrl-underscore 31)
    (else #f)))

(define (ctrl-code->symbol code)
  "Convert control code to symbol."
  (case code
    ((1) 'ctrl-a) ((2) 'ctrl-b) ((3) 'ctrl-c) ((4) 'ctrl-d) ((5) 'ctrl-e)
    ((6) 'ctrl-f) ((7) 'ctrl-g) ((8) 'ctrl-h) ((9) 'ctrl-i) ((10) 'ctrl-j)
    ((11) 'ctrl-k) ((12) 'ctrl-l) ((13) 'ctrl-m) ((14) 'ctrl-n) ((15) 'ctrl-o)
    ((16) 'ctrl-p) ((17) 'ctrl-q) ((18) 'ctrl-r) ((19) 'ctrl-s) ((20) 'ctrl-t)
    ((21) 'ctrl-u) ((22) 'ctrl-v) ((23) 'ctrl-w) ((24) 'ctrl-x) ((25) 'ctrl-y)
    ((26) 'ctrl-z) ((27) 'escape) ((28) 'ctrl-backslash) ((29) 'ctrl-right-bracket)
    ((30) 'ctrl-caret) ((31) 'ctrl-underscore)
    (else #f)))

(define (get-ctrl-description symbol)
  "Get human-readable description of control character."
  (case symbol
    ('ctrl-a "Start of Heading (SOH)")
    ('ctrl-b "Start of Text (STX)")
    ('ctrl-c "End of Text (ETX) - Interrupt")
    ('ctrl-d "End of Transmission (EOT) - EOF")
    ('ctrl-e "Enquiry (ENQ)")
    ('ctrl-f "Acknowledge (ACK)")
    ('ctrl-g "Bell (BEL)")
    ('ctrl-h "Backspace (BS)")
    ('ctrl-i "Horizontal Tab (HT)")
    ('ctrl-j "Line Feed (LF)")
    ('ctrl-k "Vertical Tab (VT)")
    ('ctrl-l "Form Feed (FF)")
    ('ctrl-m "Carriage Return (CR)")
    ('ctrl-n "Shift Out (SO)")
    ('ctrl-o "Shift In (SI)")
    ('ctrl-p "Data Link Escape (DLE)")
    ('ctrl-q "Device Control 1 (XON)")
    ('ctrl-r "Device Control 2")
    ('ctrl-s "Device Control 3 (XOFF)")
    ('ctrl-t "Device Control 4")
    ('ctrl-u "Negative Acknowledge (NAK)")
    ('ctrl-v "Synchronous Idle (SYN)")
    ('ctrl-w "End of Transmission Block (ETB)")
    ('ctrl-x "Cancel (CAN)")
    ('ctrl-y "End of Medium (EM)")
    ('ctrl-z "Substitute (SUB) - Suspend")
    ('ctrl-backslash "File Separator (FS)")
    ('ctrl-right-bracket "Group Separator (GS)")
    ('ctrl-caret "Record Separator (RS)")
    ('ctrl-underscore "Unit Separator (US)")
    (else "Unknown control character")))

;;; Control character testing and demonstration
(define (demo-control-characters)
  "Demonstrate control character recognition and mapping."
  (display "\n=== Control Character Demo ===\n")
  (display "Control key mappings (Ctrl+Letter = ASCII - 64):\n\n")
  
  ;; Show the mathematical relationship
  (for-each
   (lambda (letter)
     (let* ((upper (char-upcase letter))
            (ascii-val (char->integer upper))
            (ctrl-code (letter->ctrl-code letter))
            (symbol (ctrl-code->symbol ctrl-code)))
       (format #t "Ctrl+~a: ASCII ~d - 64 = ~d → ~a\n"
              upper ascii-val ctrl-code symbol)))
   '(#\A #\B #\C #\D #\E #\F #\G #\H #\I #\J #\K #\L #\M #\N #\O #\P 
     #\Q #\R #\S #\T #\U #\V #\W #\X #\Y #\Z))
  
  (display "\nCommon control characters and their meanings:\n")
  (for-each
   (lambda (symbol)
     (format #t "~a: ~a\n" symbol (get-ctrl-description symbol)))
   '(ctrl-c ctrl-d ctrl-g ctrl-h ctrl-i ctrl-j ctrl-m ctrl-q ctrl-s ctrl-z)))

(define (test-control-input)
  "Test control character input parsing."
  (display "\n=== Control Input Testing ===\n")
  (reset-input-parser)
  
  ;; Test common control characters
  (let ((test-codes '(1 3 4 8 9 10 13 17 19 26)))
    (for-each
     (lambda (code)
       (let* ((result (parse-input-byte code))
              (letter (ctrl-code->letter code))
              (description (if (symbol? result) 
                             (get-ctrl-description result)
                             "Special handling")))
         (format #t "Byte ~2d (Ctrl+~a): ~a - ~a\n" 
                code 
                (or letter "?")
                result 
                description)))
;;; Alt/Meta key utility functions
(define (is-alt-character? symbol)
  "Check if symbol represents an Alt+key combination."
  (and (symbol? symbol)
       (string-prefix? "alt-" (symbol->string symbol))))

(define (char->alt-symbol char)
  "Convert character to Alt+char symbol."
  (string->symbol (string-append "alt-" (string char))))

(define (alt-symbol->char symbol)
  "Extract character from Alt+char symbol."
  (let ((str (symbol->string symbol)))
    (if (string-prefix? "alt-" str)
        (string-ref str 4)  ; Get character after "alt-"
        #f)))

(define (char->8bit-meta char)
  "Convert character to 8-bit meta (high bit set) version."
  (let ((code (char->integer char)))
    (if (< code 128)
        (integer->char (+ code 128))
        char)))

(define (is-8bit-meta? char)
  "Check if character has 8th bit set (meta character)."
  (> (char->integer char) 127))

(define (strip-8bit-meta char)
  "Remove 8th bit from character."
  (let ((code (char->integer char)))
    (integer->char (logand code 127))))

;;; Meta mode configuration
(define *meta-sends-escape* #t)  ; Default: ESC+char mode

(define (set-meta-mode! escape-mode?)
  "Set meta key behavior: #t for ESC+char, #f for 8-bit mode."
  (set! *meta-sends-escape* escape-mode?))

(define (get-meta-mode)
  "Get current meta key mode."
  *meta-sends-escape*)

;;; Enhanced Alt+key parsing with mode awareness
(define (handle-meta-input byte)
  "Handle meta/alt input according to current mode."
  (if *meta-sends-escape*
      ;; ESC+char mode - handled by main parser
      #f
      ;; 8-bit meta mode
      (if (> byte 127)
          (let ((base-char (integer->char (- byte 128))))
            (reset-input-parser)
            (char->alt-symbol base-char))
          #f)))

;;; Demo and testing functions for Alt+key
(define (demo-alt-keys)
  "Demonstrate Alt+key combinations and modes."
  (display "\n=== Alt/Meta Key Demo ===\n")
  
  (display "Meta key behavior modes:\n")
  (format #t "Current mode: ~a\n" 
          (if *meta-sends-escape* "ESC+char (8-bit clean)" "8-bit meta"))
  
  (display "\nESC+char mode examples (most common):\n")
  (for-each
   (lambda (char)
     (format #t "Alt+~a → ESC+'~a' → 'alt-~a\n" char char char))
   '(#\a #\b #\c #\f #\x))
  
  (display "\n8-bit meta mode examples:\n")
  (for-each
   (lambda (char)
     (let* ((code (char->integer char))
            (meta-code (+ code 128))
            (meta-char (integer->char meta-code)))
       (format #t "Alt+~a → ~d (ASCII+128) → ~a\n" char meta-code meta-char)))
   '(#\a #\b #\c #\f #\x))
  
  (display "\nUtility functions:\n")
  (format #t "(char->alt-symbol #\\a) → ~a\n" (char->alt-symbol #\a))
  (format #t "(alt-symbol->char 'alt-a) → ~a\n" (alt-symbol->char 'alt-a))
  (format #t "(char->8bit-meta #\\a) → ~a\n" (char->8bit-meta #\a))
  (format #t "(is-8bit-meta? (char->8bit-meta #\\a)) → ~a\n" 
          (is-8bit-meta? (char->8bit-meta #\a))))

(define (test-alt-input)
  "Test Alt+key input parsing in both modes."
  (display "\n=== Alt Input Testing ===\n")
  
  ;; Test ESC+char mode
  (display "Testing ESC+char mode:\n")
  (set-meta-mode! #t)
  (reset-input-parser)
  
  ;; Simulate Alt+a (ESC + 'a')
  (let* ((esc-result (parse-input-byte 27))           ; ESC
         (a-result (parse-input-byte (char->integer #\a))))  ; 'a'
    (format #t "ESC → ~a, 'a' → ~a\n" esc-result a-result))
  
  ;; Test 8-bit meta mode
  (display "\nTesting 8-bit meta mode:\n")
  (set-meta-mode! #f)
  (reset-input-parser)
  
  ;; Simulate Alt+a (byte 225 = 97 + 128)
  (let ((result (handle-meta-input 225)))  ; 'a' + 128
    (format #t "Byte 225 (Alt+a in 8-bit mode) → ~a\n" result))
  
;;; Complex modifier key support (xterm-style)
;;; Based on xterm's PC-Style Function Keys specification

(define *modifier-codes*
  '((1 . none)                    ; No modifiers (placeholder)
    (2 . shift)                   ; Shift
    (3 . alt)                     ; Alt  
    (4 . shift-alt)               ; Shift + Alt
    (5 . ctrl)                    ; Control
    (6 . shift-ctrl)              ; Shift + Control  
    (7 . alt-ctrl)                ; Alt + Control
    (8 . shift-alt-ctrl)          ; Shift + Alt + Control
    (9 . meta)                    ; Meta
    (10 . meta-shift)             ; Meta + Shift
    (11 . meta-alt)               ; Meta + Alt
    (12 . meta-alt-shift)         ; Meta + Alt + Shift
    (13 . meta-ctrl)              ; Meta + Ctrl
    (14 . meta-ctrl-shift)        ; Meta + Ctrl + Shift
    (15 . meta-ctrl-alt)          ; Meta + Ctrl + Alt
    (16 . meta-ctrl-alt-shift)))  ; Meta + Ctrl + Alt + Shift

(define (modifier-code->symbol code)
  "Convert numeric modifier code to symbol."
  (let ((mapping (assoc code *modifier-codes*)))
    (if mapping (cdr mapping) 'unknown-modifier)))

(define (modifier-symbol->code symbol)
  "Convert modifier symbol to numeric code."
  (let ((mapping (rassoc symbol *modifier-codes*)))
    (if mapping (car mapping) 1)))

(define (parse-function-key-with-modifier seq)
  "Parse function key sequence with modifier codes.
   Expected format: CSI number ; modifier ~ or CSI 1 ; modifier letter"
  (let ((parts (string-split (substring seq 2) #\;)))  ; Remove CSI prefix
    (if (>= (length parts) 2)
        (let* ((key-num-str (car parts))
               (modifier-part (cadr parts))
               (modifier-code (string->number 
                              (if (string-suffix? "~" modifier-part)
                                  (substring modifier-part 0 
                                           (- (string-length modifier-part) 1))
                                  modifier-part)))
               (key-num (string->number key-num-str)))
          (if (and key-num modifier-code)
              (let ((modifier-sym (modifier-code->symbol modifier-code))
                    (key-name (function-key-number->name key-num)))
                (if key-name
                    (string->symbol (string-append 
                                   (symbol->string modifier-sym) "-" key-name))
                    #f))
              #f))
        #f)))

(define (function-key-number->name num)
  "Convert function key number to key name."
  (case num
    ((11) "f1") ((12) "f2") ((13) "f3") ((14) "f4") ((15) "f5")
    ((17) "f6") ((18) "f7") ((19) "f8") ((20) "f9") ((21) "f10")
    ((23) "f11") ((24) "f12") ((25) "f13") ((26) "f14") ((28) "f15")
    ((29) "f16") ((31) "f17") ((32) "f18") ((33) "f19") ((34) "f20")
    ((1) "home") ((2) "insert") ((3) "delete") ((4) "end") 
    ((5) "page-up") ((6) "page-down")
    (else #f)))

(define (parse-cursor-key-with-modifier seq)
  "Parse cursor key sequence with modifier codes.
   Expected format: CSI 1 ; modifier letter"
  (if (and (> (string-length seq) 4)
           (string-prefix? "\033[1;" seq))
      (let* ((modifier-char (string-ref seq 4))
             (final-char (string-ref seq 5))
             (modifier-code (- (char->integer modifier-char) (char->integer #\0))))
        (if (and (>= modifier-code 2) (<= modifier-code 16))
            (let ((modifier-sym (modifier-code->symbol modifier-code))
                  (key-name (case final-char
                              ((#\A) "up")
                              ((#\B) "down") 
                              ((#\C) "right")
                              ((#\D) "left")
                              ((#\H) "home")
                              ((#\F) "end")
                              (else #f))))
              (if key-name
                  (string->symbol (string-append 
                                 (symbol->string modifier-sym) "-" key-name))
                  #f))
            #f))
      #f))

;;; Enhanced parsing for complex escape sequences
(define (parse-complex-escape-sequence)
  "Parse complex escape sequences with modifiers."
  (let ((buffer (parser-buffer *current-parser*)))
    (if (>= (length buffer) 3)
        (let ((seq (list->string (reverse buffer))))
          (cond
           ;; CSI number ; modifier ~ (function keys)
           ((and (string-prefix? "\033[" seq)
                 (string-contains seq ";")
                 (string-suffix? "~" seq))
            (parse-function-key-with-modifier seq))
           
           ;; CSI 1 ; modifier letter (cursor keys)
           ((and (string-prefix? "\033[1;" seq)
                 (= (string-length seq) 6))
            (parse-cursor-key-with-modifier seq))
           
           ;; Other complex sequences can be added here
           (else #f)))
        #f)))

;;; Demo and testing functions for complex modifiers
(define (demo-complex-modifiers)
  "Demonstrate complex modifier key combinations."
  (display "\n=== Complex Modifier Keys Demo ===\n")
  
  (display "XTerm PC-Style Function Key Modifier Codes:\n")
  (for-each
   (lambda (mapping)
     (let ((code (car mapping))
           (symbol (cdr mapping)))
       (format #t "  ~2d: ~a\n" code symbol)))
   *modifier-codes*)
  
  (display "\nExample sequences:\n")
  (let ((examples 
         '(("Shift+F5" "\\033[15;2~" "shift-f5")
           ("Ctrl+F1" "\\033[11;5~" "ctrl-f1") 
           ("Alt+F12" "\\033[24;3~" "alt-f12")
           ("Shift+Ctrl+F10" "\\033[21;6~" "shift-ctrl-f10")
           ("Alt+Ctrl+F2" "\\033[12;7~" "alt-ctrl-f2")
           ("Shift+Alt+Ctrl+F3" "\\033[13;8~" "shift-alt-ctrl-f3")
           ("Ctrl+Up" "\\033[1;5A" "ctrl-up")
           ("Shift+Alt+Right" "\\033[1;4C" "shift-alt-right"))))
    (for-each
     (lambda (example)
       (let ((desc (car example))
             (seq (cadr example))
             (expected (caddr example)))
         (format #t "  ~20a: ~15s → ~a\n" desc seq expected)))
     examples)))

(define (test-complex-modifier-parsing)
  "Test parsing of complex modifier key sequences."
  (display "\n=== Complex Modifier Parsing Test ===\n")
  
  ;; Test function key with Shift+Ctrl (code 6)
  (display "Testing Shift+Ctrl+F5 (\\033[15;6~):\n")
  (reset-input-parser)
  (let* ((results (map parse-input-byte '(27 91 49 53 59 54 126))))  ; \033[15;6~
    (format #t "Parse results: ~a\n" results)
    (format #t "Expected: shift-ctrl-f5\n"))
  
  ;; Test cursor key with Alt+Ctrl (code 7)
  (display "\nTesting Alt+Ctrl+Up (\\033[1;7A):\n")
  (reset-input-parser)
  (let* ((results (map parse-input-byte '(27 91 49 59 55 65))))  ; \033[1;7A
    (format #t "Parse results: ~a\n" results)
    (format #t "Expected: alt-ctrl-up\n")))

;;; Restore utility function  
(define (terminfo-can-change-colors)
  "Check if terminal can change color definitions."
  (get-boolean-capability "can_change_colors"))

;;; Example usage and test functions
(define (demo-terminfo)
  "Demonstrate the terminfo library functionality."
  (display "=== Terminfo Library Demo ===\n")
  (display (format #f "Terminal: ~a\n" (terminfo-primary-name *terminfo-data*)))
  (display (format #f "Dimensions: ~ax~a\n" 
                   (terminfo-get-columns) 
                   (terminfo-get-lines)))
  (display (format #f "Has color: ~a\n" (terminfo-has-color)))
  
  (display "\nCursor movement:\n")
  (display "Moving to (5,10): ")
  (display (emit-cursor-address 5 10))
  (display "\nMoving up 3 lines: ")
  (display (emit-cursor-up 3))
  
  (display "\n\nText attributes:\n")
  (display "Bold text: ")
  (display (emit-enter-bold-mode))
  (display "BOLD")
  (display (emit-exit-attribute-mode))
  (display " normal\n"))
