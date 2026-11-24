;;; Gano Keys Module
;;; Key representation, parsing, and binding system

;;;; Key Representation System
;;;
;;; This module provides a comprehensive system for representing and
;;; manipulating keyboard input in a text editor context. It handles:
;;;
;;; - String representation of keys (e.g., "^C", "A-a", "F6")
;;; - Conversion between string and internal representations
;;; - Key sequence parsing and validation
;;; - Modifier key combinations
;;; - Special and function keys
;;;
;;; Key String Format:
;;; - Single characters: "a", "1", "!", and "space" for the space bar
;;; - Control keys: "^A", "^C", "C-a" (Control + key).  A terminal sends
;;;   the same byte for Ctrl+a and Ctrl+A, so control letters are always
;;;   lower case: "^A", "^a" and "C-a" are the same key.
;;; - Alt keys: "A-a", "A-1" (Alt + key)
;;; - Function keys: "F1", "F2", ..., "F12"
;;; - Named special keys: "kup", "kdown", "kleft", "kright", etc.
;;; - Shift combinations: "S-F1", "S-kup"
;;; - Complex combinations: "C-A-a" (Control + Alt + a)

(define-module (gano keys)
  #:use-module (gano char)
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-9)        ; Record types
  #:use-module (srfi srfi-13)       ; String utilities
  #:use-module (ice-9 format)       ; Format function
  #:use-module (ice-9 regex)        ; Regular expressions
  #:export (
    ;; Key representation
    <key>
    make-key
    key?
    key-char
    key-symbol
    key-ctrl?
    key-alt?
    key-shift?
    
    ;; Key parsing and formatting
    string->key
    key->string
    parse-key-sequence
    key-sequence->string
    
    ;; Key predicates and queries
    key-printable?
    key-special?
    key-function?
    key-arrow?
    key-modifier?
    key-equivalent?
    
    ;; Key sequence operations
    key-sequence-length
    key-sequence-prefix?
    key-sequence-starts-with?
    
    ;; Validation
    valid-key-string?
    normalize-key-string
    
    ;; Named key mappings
    get-special-key-names
    get-function-key-names
    
    ;; Utility functions
    describe-key
    key-combination->string
    parse-modifiers
    
    ;; Convenience constructors
    ctrl-key
    alt-key
    function-key
    special-key
    
    ;; Predefined key constants
    key-enter
    key-escape
    key-tab
    key-backspace
    key-delete
    key-up
    key-down
    key-left
    key-right
    
    ;; Debug and testing
    key-debug-info
    test-key-parsing))

;;; =================================================================
;;; KEY REPRESENTATION
;;; =================================================================

;;; Key record type
(define-record-type <key>
  (%make-key char symbol ctrl? alt? shift?)
  key?
  (char key-char set-key-char!)         ; character for printable keys
  (symbol key-symbol set-key-symbol!)   ; symbol for special keys
  (ctrl? key-ctrl? set-key-ctrl!)       ; Control modifier
  (alt? key-alt? set-key-alt!)          ; Alt modifier  
  (shift? key-shift? set-key-shift!))   ; Shift modifier

(define* (make-key #:key char symbol (ctrl? #f) (alt? #f) (shift? #f))
  "Create a new key: either CHAR (a character) or SYMBOL (a special key
   name such as 'up or 'f1), plus modifier flags."
  (unless (if char (and (char? char) (not symbol)) (symbol? symbol))
    (error "make-key: give exactly one of #:char (a character) or #:symbol (a symbol)"
           char symbol))
  (%make-key char symbol (and ctrl? #t) (and alt? #t) (and shift? #t)))

;;; =================================================================
;;; SPECIAL KEY MAPPINGS
;;; =================================================================

(define *special-keys*
  '(;; Arrow keys
    ("up" . up)
    ("down" . down) 
    ("left" . left)
    ("right" . right)
    
    ;; Editing keys
    ("insert" . insert)
    ("delete" . delete)
    ("backspace" . backspace)
    ("home" . home)
    ("end" . end)
    ("pageup" . page-up)
    ("pagedown" . page-down)
    
    ;; Other special keys
    ("tab" . tab)
    ("enter" . enter)
    ("escape" . escape)
    
    ;; Keypad (keep kp prefix as it makes sense)
    ("kp0" . keypad-0) ("kp1" . keypad-1) ("kp2" . keypad-2)
    ("kp3" . keypad-3) ("kp4" . keypad-4) ("kp5" . keypad-5)
    ("kp6" . keypad-6) ("kp7" . keypad-7) ("kp8" . keypad-8)
    ("kp9" . keypad-9) ("kp." . keypad-period) ("kp+" . keypad-plus)
    ("kp-" . keypad-minus) ("kp*" . keypad-multiply) ("kp/" . keypad-divide)
    ("kpenter" . keypad-enter)))

(define *function-keys*
  '(("F1" . f1) ("F2" . f2) ("F3" . f3) ("F4" . f4)
    ("F5" . f5) ("F6" . f6) ("F7" . f7) ("F8" . f8)
    ("F9" . f9) ("F10" . f10) ("F11" . f11) ("F12" . f12)))

(define (get-special-key-names)
  "Get list of all special key names"
  (map car *special-keys*))

(define (get-function-key-names)
  "Get list of all function key names"
  (map car *function-keys*))

;;; =================================================================
;;; KEY PARSING
;;; =================================================================

(define (parse-modifiers key-string)
  "Parse modifier prefixes (^, C-, A-, S-, in any order) from a key
   string.  Returns ((ctrl? alt? shift?) . base-key).  A prefix is only a
   modifier if something follows it, so \"^\" and \"C-\" ... are plain keys."
  (let loop ([str key-string]
             [ctrl? #f]
             [alt? #f]
             [shift? #f])
    (define (prefix? p) (and (string-prefix? p str) (> (string-length str) (string-length p))))
    (cond
     [(prefix? "^") (loop (substring str 1) #t alt? shift?)]
     [(prefix? "C-") (loop (substring str 2) #t alt? shift?)]
     [(prefix? "A-") (loop (substring str 2) ctrl? #t shift?)]
     [(prefix? "S-") (loop (substring str 2) ctrl? alt? #t)]
     [else (cons (list ctrl? alt? shift?) str)])))

(define (string->key key-string)
  "Convert key string to key record"
  (let* ([normalized (normalize-key-string key-string)]
         [parsed (parse-modifiers normalized)]
         [modifiers (car parsed)]
         [base-key (cdr parsed)]
         [ctrl? (first modifiers)]
         [alt? (second modifiers)]
         [shift? (third modifiers)])
    
    (cond
     ;; Function keys
     [(assoc base-key *function-keys*)
      => (lambda (entry)
           (make-key #:symbol (cdr entry) #:ctrl? ctrl? #:alt? alt? 
                    #:shift? shift?))]
     
     ;; Special named keys
     [(assoc base-key *special-keys*)
      => (lambda (entry)
           (make-key #:symbol (cdr entry) #:ctrl? ctrl? #:alt? alt?
                    #:shift? shift?))]

     ;; The space bar is the character #\space
     [(string=? base-key "space")
      (make-key #:char #\space #:ctrl? ctrl? #:alt? alt? #:shift? shift?)]
     
     ;; Single character (control letters are lower case)
     [(= (string-length base-key) 1)
      (let ([ch (string-ref base-key 0)])
        (make-key #:char (if ctrl? (char-downcase ch) ch)
                  #:ctrl? ctrl? #:alt? alt? #:shift? shift?))]
     
     ;; Invalid key string
     [else
      (error "Invalid key string" key-string)])))

(define (key->string key)
  "Convert key record to string representation"
  (let* ([modifiers (string-append
                    (if (key-ctrl? key) "C-" "")
                    (if (key-alt? key) "A-" "")
                    (if (key-shift? key) "S-" ""))]
         [base (cond
                [(eqv? (key-char key) #\space) "space"]
                [(key-char key)
                 (string (key-char key))]
                [(key-symbol key)
                 (let ([entry (find (lambda (entry) (eq? (cdr entry) (key-symbol key)))
                                    (append *special-keys* *function-keys*))])
                   (if entry
                       (car entry)
                       (symbol->string (key-symbol key))))]
                [else "?"])])
    
    ;; Plain control keys use nano's ^X notation: ^A .. ^Z, ^@ ^[ ^\ ^] ^^ ^_
    (if (and (key-ctrl? key) 
             (not (key-alt? key)) 
             (not (key-shift? key))
             (key-char key)
             (or (char-alphabetic? (key-char key))
                 (memv (key-char key) '(#\@ #\[ #\\ #\] #\^ #\_))))
        (string-append "^" (string (char-upcase (key-char key))))
        (string-append modifiers base))))

(define (normalize-key-string str)
  "Normalize key string format"
  (string-trim-both str))

(define (valid-key-string? str)
  "Check if string represents a valid key"
  (catch #t
    (lambda ()
      (string->key str)
      #t)
    (lambda (key . args)
      #f)))

;;; =================================================================
;;; KEY SEQUENCE OPERATIONS
;;; =================================================================

(define (parse-key-sequence seq-string)
  "Parse whitespace-separated key sequence string into list of keys"
  (map string->key (string-tokenize seq-string)))

(define (key-sequence->string key-list)
  "Convert list of keys to space-separated string"
  (string-join (map key->string key-list) " "))

(define (key-sequence-length key-list)
  "Get length of key sequence"
  (length key-list))

(define (key-sequence-prefix? prefix sequence)
  "Check if prefix is a prefix of sequence"
  (and (<= (length prefix) (length sequence))
       (every key-equivalent? prefix (take sequence (length prefix)))))

(define (key-sequence-starts-with? sequence prefix)
  "Check if sequence starts with prefix"
  (key-sequence-prefix? prefix sequence))

;;; =================================================================
;;; KEY PREDICATES
;;; =================================================================

(define (key-printable? key)
  "Check if key represents a printable character"
  (let ([ch (key-char key)])
    (and ch
         (not (key-ctrl? key))
         (not (key-alt? key))
         (or (char-graphic? ch) (char=? ch #\space))
         #t)))

(define (key-special? key)
  "Check if key is a special named key"
  (and (key-symbol key)
       (memq (key-symbol key) (map cdr *special-keys*))
       #t))

(define (key-function? key)
  "Check if key is a function key"
  (and (key-symbol key)
       (memq (key-symbol key) (map cdr *function-keys*))
       #t))

(define (key-arrow? key)
  "Check if key is an arrow key"
  (and (key-symbol key)
       (memq (key-symbol key) '(up down left right))
       #t))

(define (key-modifier? key)
  "Check if key has any modifiers"
  (or (key-ctrl? key) (key-alt? key) (key-shift? key)))

(define (key-equivalent? key1 key2)
  "Check if two keys are equivalent"
  (and (equal? (key-char key1) (key-char key2))
       (equal? (key-symbol key1) (key-symbol key2))
       (equal? (key-ctrl? key1) (key-ctrl? key2))
       (equal? (key-alt? key1) (key-alt? key2))
       (equal? (key-shift? key1) (key-shift? key2))))

;;; =================================================================
;;; UTILITY FUNCTIONS
;;; =================================================================

(define (describe-key key)
  "Generate human-readable description of key"
  (let* ([modifiers (filter identity
                           (list (and (key-ctrl? key) "Control")
                                (and (key-alt? key) "Alt") 
                                (and (key-shift? key) "Shift")))]
         [base-desc (cond
                     [(eqv? (key-char key) #\space) "Space"]
                     [(key-char key)
                      (format #f "'~a'" (key-char key))]
                     [(key-symbol key)
                      (case (key-symbol key)
                        [(up) "Up Arrow"]
                        [(down) "Down Arrow"]
                        [(left) "Left Arrow"]
                        [(right) "Right Arrow"]
                        [(enter) "Enter"]
                        [(escape) "Escape"]
                        [(space) "Space"]
                        [(tab) "Tab"]
                        [(backspace) "Backspace"]
                        [(delete) "Delete"]
                        [(home) "Home"]
                        [(end) "End"]
                        [(page-up) "Page Up"]
                        [(page-down) "Page Down"]
                        [(insert) "Insert"]
                        [(f1) "F1"] [(f2) "F2"] [(f3) "F3"] [(f4) "F4"]
                        [(f5) "F5"] [(f6) "F6"] [(f7) "F7"] [(f8) "F8"]
                        [(f9) "F9"] [(f10) "F10"] [(f11) "F11"] [(f12) "F12"]
                        [else (symbol->string (key-symbol key))])]
                     [else "Unknown Key"])])
    
    (if (null? modifiers)
        base-desc
        (format #f "~a + ~a" (string-join modifiers " + ") base-desc))))

(define (key-combination->string key)
  "Convert key to readable combination string (alternative to key->string)"
  (let* ([ctrl-str (if (key-ctrl? key) "Ctrl+" "")]
         [alt-str (if (key-alt? key) "Alt+" "")]
         [shift-str (if (key-shift? key) "Shift+" "")]
         [base-str (cond
                    [(key-char key) (string (key-char key))]
                    [(key-symbol key) (symbol->string (key-symbol key))]
                    [else "?"])])
    (string-append ctrl-str alt-str shift-str base-str)))

;;; =================================================================
;;; DEBUGGING AND TESTING
;;; =================================================================

(define (key-debug-info key)
  "Return debug information about a key"
  `((char ,(key-char key))
    (symbol ,(key-symbol key))
    (ctrl? ,(key-ctrl? key))
    (alt? ,(key-alt? key))
    (shift? ,(key-shift? key))
    (string ,(key->string key))
    (description ,(describe-key key))))

(define (test-key-parsing)
  "Test key parsing functionality"
  (let ([test-keys '("a" "^C" "A-a" "F6" "up" "C-A-a" "S-F1" "^X")])
    (format #t "Key Parsing Tests:~%")
    (for-each (lambda (key-str)
                (let ([key (string->key key-str)])
                  (format #t "  '~a' -> ~a -> '~a'~%"
                         key-str
                         (describe-key key)
                         (key->string key))))
              test-keys)))

;;; =================================================================
;;; CONVENIENCE FUNCTIONS
;;; =================================================================

(define (ctrl-key char)
  "Create a control key combination (letters are made lower case)"
  (make-key #:char (char-downcase char) #:ctrl? #t))

(define (alt-key char)
  "Create an alt key combination"
  (make-key #:char char #:alt? #t))

(define (function-key n)
  "Create a function key (F1-F12)"
  (if (and (exact-integer? n) (>= n 1) (<= n 12))
      (make-key #:symbol (string->symbol (format #f "f~a" n)))
      (error "Invalid function key number" n)))

(define (special-key name)
  "Create a special key by name"
  (let ([entry (assoc name *special-keys*)])
    (if entry
        (make-key #:symbol (cdr entry))
        (error "Unknown special key" name))))

;;; Export some common keys as constants
(define key-enter (make-key #:symbol 'enter))
(define key-escape (make-key #:symbol 'escape))
(define key-tab (make-key #:symbol 'tab))
(define key-backspace (make-key #:symbol 'backspace))
(define key-delete (make-key #:symbol 'delete))
(define key-up (make-key #:symbol 'up))
(define key-down (make-key #:symbol 'down))
(define key-left (make-key #:symbol 'left))
(define key-right (make-key #:symbol 'right))
