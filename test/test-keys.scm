;;; Test suite for Gano Keys Module (No Meta)
;;; Using SRFI-64 testing framework

(use-modules (srfi srfi-64)     ; Testing framework
             (srfi srfi-1)      ; List utilities for every
             (gano keys))       ; Module under test

;;; Test suite setup
(test-begin "gano-keys")

;;; =================================================================
;;; KEY RECORD TESTS
;;; =================================================================

;;; Tests for key record creation and accessors
(test-group "key-record"
  (test-assert "make-key creates key"
    (key? (make-key #:char #\a)))
  
  (test-equal "key-char accessor works"
    #\a
    (key-char (make-key #:char #\a)))
  
  (test-equal "key-symbol accessor works"
    'up
    (key-symbol (make-key #:symbol 'up)))
  
  (test-assert "key-ctrl? accessor works"
    (key-ctrl? (make-key #:char #\a #:ctrl? #t)))
  
  (test-assert "key-alt? accessor works"
    (key-alt? (make-key #:char #\a #:alt? #t)))
  
  (test-assert "key-shift? accessor works"
    (key-shift? (make-key #:char #\a #:shift? #t)))
  
  (test-equal "key with no modifiers"
    #f
    (key-ctrl? (make-key #:char #\a))))

;;; =================================================================
;;; KEY PARSING TESTS
;;; =================================================================

;;; Tests for string->key parsing
(test-group "string->key"
  ;; Simple character keys
  (test-equal "parse simple character"
    #\a
    (key-char (string->key "a")))
  
  (test-equal "parse digit character"
    #\5
    (key-char (string->key "5")))
  
  (test-equal "parse punctuation"
    #\!
    (key-char (string->key "!")))
  
  ;; Control keys - traditional ^X notation
  (test-assert "parse control key ^C"
    (let ([key (string->key "^C")])
      (and (key-ctrl? key)
           (char=? (key-char key) #\C))))
  
  (test-assert "parse control key ^X"
    (let ([key (string->key "^X")])
      (and (key-ctrl? key)
           (char=? (key-char key) #\X))))
  
  ;; Control keys - C- notation
  (test-assert "parse control key C-a"
    (let ([key (string->key "C-a")])
      (and (key-ctrl? key)
           (char=? (key-char key) #\a))))
  
  ;; Alt keys
  (test-assert "parse alt key A-a"
    (let ([key (string->key "A-a")])
      (and (key-alt? key)
           (char=? (key-char key) #\a))))
  
  ;; Shift keys
  (test-assert "parse shift key S-F1"
    (let ([key (string->key "S-F1")])
      (and (key-shift? key)
           (eq? (key-symbol key) 'f1))))
  
  ;; Function keys
  (test-equal "parse function key F1"
    'f1
    (key-symbol (string->key "F1")))
  
  (test-equal "parse function key F12"
    'f12
    (key-symbol (string->key "F12")))
  
  ;; Special keys
  (test-equal "parse up arrow"
    'up
    (key-symbol (string->key "up")))
  
  (test-equal "parse down arrow"
    'down
    (key-symbol (string->key "down")))
  
  (test-equal "parse enter key"
    'enter
    (key-symbol (string->key "enter")))
  
  ;; Combined modifiers
  (test-assert "parse C-A-a"
    (let ([key (string->key "C-A-a")])
      (and (key-ctrl? key)
           (key-alt? key)
           (char=? (key-char key) #\a))))
  
  (test-assert "parse C-S-F1"
    (let ([key (string->key "C-S-F1")])
      (and (key-ctrl? key)
           (key-shift? key)
           (eq? (key-symbol key) 'f1))))
  
  (test-assert "parse C-A-S-a"
    (let ([key (string->key "C-A-S-a")])
      (and (key-ctrl? key)
           (key-alt? key)
           (key-shift? key)
           (char=? (key-char key) #\a))))
  
  ;; Error cases
  (test-error "invalid key string throws error"
    (string->key "invalid-key-name")))

;;; =================================================================
;;; KEY FORMATTING TESTS
;;; =================================================================

;;; Tests for key->string formatting
(test-group "key->string"
  ;; Simple characters
  (test-equal "format simple character"
    "a"
    (key->string (make-key #:char #\a)))
  
  ;; Control keys should use ^X notation for simple cases
  (test-equal "format control key as ^C"
    "^C"
    (key->string (make-key #:char #\C #:ctrl? #t)))
  
  ;; Function keys
  (test-equal "format function key F1"
    "F1"
    (key->string (make-key #:symbol 'f1)))
  
  ;; Special keys
  (test-equal "format up arrow"
    "up"
    (key->string (make-key #:symbol 'up)))
  
  ;; Alt keys
  (test-equal "format alt key"
    "A-a"
    (key->string (make-key #:char #\a #:alt? #t)))
  
  ;; Complex combinations
  (test-equal "format complex combination"
    "C-A-S-a"
    (key->string (make-key #:char #\a #:ctrl? #t #:alt? #t #:shift? #t))))

;;; =================================================================
;;; ROUNDTRIP TESTS
;;; =================================================================

;;; Tests for string->key->string roundtrip consistency
(test-group "roundtrip"
  (define test-keys
    '("a" "^C" "A-a" "F1" "F12" "up" "down" "C-A-a" "S-F1" "C-S-up"))
  
  (test-assert "all test keys roundtrip correctly"
    (every (lambda (key-str)
             (string=? key-str (key->string (string->key key-str))))
           test-keys))
  
  (test-assert "roundtrip preserves key properties"
    (every (lambda (key-str)
             (let* ([original-key (string->key key-str)]
                    [roundtrip-key (string->key (key->string original-key))])
               (key-equivalent? original-key roundtrip-key)))
           test-keys)))

;;; =================================================================
;;; KEY SEQUENCE TESTS
;;; =================================================================

;;; Tests for key sequence parsing and operations
(test-group "key-sequences"
  ;; Sequence parsing
  (test-equal "parse simple key sequence"
    2
    (length (parse-key-sequence "^C ^X")))
  
  (test-assert "parse key sequence correctly"
    (let ([seq (parse-key-sequence "C-x C-f A-a")])
      (and (= (length seq) 3)
           (key-ctrl? (first seq))
           (char=? (key-char (first seq)) #\x)
           (key-ctrl? (second seq))
           (char=? (key-char (second seq)) #\f)
           (key-alt? (third seq))
           (char=? (key-char (third seq)) #\a))))
  
  ;; Sequence formatting
  (test-equal "format key sequence"
    "^C ^X"
    (key-sequence->string (list (make-key #:char #\C #:ctrl? #t)
                               (make-key #:char #\X #:ctrl? #t))))
  
  ;; Sequence operations
  (test-equal "key sequence length"
    3
    (key-sequence-length (parse-key-sequence "a b c")))
  
  ;; Prefix testing
  (test-assert "prefix detection works"
    (let ([prefix (parse-key-sequence "^C ^X")]
          [sequence (parse-key-sequence "^C ^X ^F")])
      (key-sequence-prefix? prefix sequence)))
  
  (test-assert "non-prefix detection works"
    (let ([prefix (parse-key-sequence "^C ^Y")]
          [sequence (parse-key-sequence "^C ^X ^F")])
      (not (key-sequence-prefix? prefix sequence))))
  
  (test-assert "starts-with works"
    (let ([prefix (parse-key-sequence "^C ^X")]
          [sequence (parse-key-sequence "^C ^X ^F")])
      (key-sequence-starts-with? sequence prefix)))
  
  ;; Empty sequences
  (test-equal "empty sequence length"
    0
    (key-sequence-length '()))
  
  (test-assert "empty prefix matches any sequence"
    (key-sequence-prefix? '() (parse-key-sequence "a b c"))))

;;; =================================================================
;;; KEY PREDICATES TESTS
;;; =================================================================

;;; Tests for key classification predicates
(test-group "key-predicates"
  ;; Printable keys
  (test-assert "regular character is printable"
    (key-printable? (make-key #:char #\a)))
  
  (test-assert "control character is not printable"
    (not (key-printable? (make-key #:char #\a #:ctrl? #t))))
  
  (test-assert "space is printable"
    (key-printable? (make-key #:char #\space)))
  
  ;; Special keys
  (test-assert "arrow key is special"
    (key-special? (make-key #:symbol 'up)))
  
  (test-assert "regular character is not special"
    (not (key-special? (make-key #:char #\a))))
  
  ;; Function keys
  (test-assert "F1 is function key"
    (key-function? (make-key #:symbol 'f1)))
  
  (test-assert "arrow key is not function key"
    (not (key-function? (make-key #:symbol 'up))))
  
  ;; Arrow keys
  (test-assert "up is arrow key"
    (key-arrow? (make-key #:symbol 'up)))
  
  (test-assert "down is arrow key"
    (key-arrow? (make-key #:symbol 'down)))
  
  (test-assert "function key is not arrow key"
    (not (key-arrow? (make-key #:symbol 'f1))))
  
  ;; Modifier detection
  (test-assert "control key has modifiers"
    (key-modifier? (make-key #:char #\a #:ctrl? #t)))
  
  (test-assert "alt key has modifiers"
    (key-modifier? (make-key #:char #\a #:alt? #t)))
  
  (test-assert "plain key has no modifiers"
    (not (key-modifier? (make-key #:char #\a)))))

;;; =================================================================
;;; KEY EQUIVALENCE TESTS
;;; =================================================================

;;; Tests for key equivalence
(test-group "key-equivalence"
  (test-assert "identical keys are equivalent"
    (key-equivalent? (make-key #:char #\a #:ctrl? #t)
                     (make-key #:char #\a #:ctrl? #t)))
  
  (test-assert "different characters are not equivalent"
    (not (key-equivalent? (make-key #:char #\a)
                          (make-key #:char #\b))))
  
  (test-assert "different modifiers are not equivalent"
    (not (key-equivalent? (make-key #:char #\a #:ctrl? #t)
                          (make-key #:char #\a #:alt? #t))))
  
  (test-assert "different symbols are not equivalent"
    (not (key-equivalent? (make-key #:symbol 'up)
                          (make-key #:symbol 'down))))
  
  (test-assert "char vs symbol keys are not equivalent"
    (not (key-equivalent? (make-key #:char #\a)
                          (make-key #:symbol 'a)))))

;;; =================================================================
;;; VALIDATION TESTS
;;; =================================================================

;;; Tests for key string validation
(test-group "validation"
  ;; Valid keys
  (test-assert "simple character is valid"
    (valid-key-string? "a"))
  
  (test-assert "control key is valid"
    (valid-key-string? "^C"))
  
  (test-assert "function key is valid"
    (valid-key-string? "F1"))
  
  (test-assert "complex combination is valid"
    (valid-key-string? "C-A-S-a"))
  
  ;; Invalid keys
  (test-assert "invalid key string is not valid"
    (not (valid-key-string? "invalid-key")))
  
  (test-assert "empty string is not valid"
    (not (valid-key-string? "")))
  
  ;; Normalization
  (test-equal "normalize removes whitespace"
    "a"
    (normalize-key-string "  a  ")))

;;; =================================================================
;;; UTILITY FUNCTION TESTS
;;; =================================================================

;;; Tests for utility functions
(test-group "utilities"
  ;; Key description
  (test-assert "describe-key returns string"
    (string? (describe-key (make-key #:char #\a))))
  
  (test-assert "describe-key handles control keys"
    (string-contains (describe-key (make-key #:char #\a #:ctrl? #t)) "Control"))
  
  (test-assert "describe-key handles function keys"
    (string-contains (describe-key (make-key #:symbol 'f1)) "F1"))
  
  ;; Key combination string
  (test-assert "key-combination->string returns string"
    (string? (key-combination->string (make-key #:char #\a #:ctrl? #t))))
  
  ;; Special key names
  (test-assert "get-special-key-names returns list"
    (list? (get-special-key-names)))
  
  (test-assert "special key names are strings"
    (every string? (get-special-key-names)))
  
  (test-assert "function key names are strings"
    (every string? (get-function-key-names))))

;;; =================================================================
;;; CONVENIENCE FUNCTION TESTS
;;; =================================================================

;;; Tests for convenience constructors
(test-group "convenience-functions"
  ;; Ctrl key
  (test-assert "ctrl-key creates control key"
    (let ([key (ctrl-key #\c)])
      (and (key-ctrl? key)
           (char=? (key-char key) #\c))))
  
  (test-assert "ctrl-key has no other modifiers"
    (let ([key (ctrl-key #\a)])
      (and (not (key-alt? key))
           (not (key-shift? key)))))
  
  ;; Alt key
  (test-assert "alt-key creates alt key"
    (let ([key (alt-key #\a)])
      (and (key-alt? key)
           (char=? (key-char key) #\a))))
  
  (test-assert "alt-key has no other modifiers"
    (let ([key (alt-key #\b)])
      (and (not (key-ctrl? key))
           (not (key-shift? key)))))
  
  ;; Function key
  (test-assert "function-key creates function key"
    (let ([key (function-key 1)])
      (eq? (key-symbol key) 'f1)))
  
  (test-assert "function-key 12 works"
    (let ([key (function-key 12)])
      (eq? (key-symbol key) 'f12)))
  
  (test-error "function-key validates range (too low)"
    (function-key 0))
  
  (test-error "function-key validates range (too high)"
    (function-key 13))
  
  ;; Special key
  (test-assert "special-key creates special key"
    (let ([key (special-key "up")])
      (eq? (key-symbol key) 'up)))
  
  (test-assert "special-key creates enter key"
    (let ([key (special-key "enter")])
      (eq? (key-symbol key) 'enter)))
  
  (test-error "special-key validates name"
    (special-key "invalid")))

;;; Tests for predefined key constants
(test-group "predefined-constants"
  ;; Basic constants exist and are keys
  (test-assert "key-enter is defined and is a key"
    (and (defined? 'key-enter) (key? key-enter)))
  
  (test-assert "key-escape is defined and is a key"
    (and (defined? 'key-escape) (key? key-escape)))
  
  (test-assert "key-tab is defined and is a key"
    (and (defined? 'key-tab) (key? key-tab)))
  
  (test-assert "key-backspace is defined and is a key"
    (and (defined? 'key-backspace) (key? key-backspace)))
  
  (test-assert "key-delete is defined and is a key"
    (and (defined? 'key-delete) (key? key-delete)))
  
  ;; Arrow keys
  (test-assert "arrow keys are defined and are keys"
    (and (defined? 'key-up) (key? key-up)
         (defined? 'key-down) (key? key-down)
         (defined? 'key-left) (key? key-left)
         (defined? 'key-right) (key? key-right)))
  
  ;; Test that constants have correct symbols
  (test-equal "key-enter has enter symbol"
    'enter
    (key-symbol key-enter))
  
  (test-equal "key-escape has escape symbol"
    'escape
    (key-symbol key-escape))
  
  (test-equal "key-tab has tab symbol"
    'tab
    (key-symbol key-tab))
  
  (test-equal "key-backspace has backspace symbol"
    'backspace
    (key-symbol key-backspace))
  
  (test-equal "key-delete has delete symbol"
    'delete
    (key-symbol key-delete))
  
  (test-equal "key-up has up symbol"
    'up
    (key-symbol key-up))
  
  (test-equal "key-down has down symbol"
    'down
    (key-symbol key-down))
  
  (test-equal "key-left has left symbol"
    'left
    (key-symbol key-left))
  
  (test-equal "key-right has right symbol"
    'right
    (key-symbol key-right))
  
  ;; Test that constants have no modifiers
  (test-assert "predefined constants have no modifiers"
    (let ([constants (list key-enter key-escape key-tab key-backspace key-delete
                          key-up key-down key-left key-right)])
      (every (lambda (key)
               (and (not (key-ctrl? key))
                    (not (key-alt? key))
                    (not (key-shift? key))))
             constants)))
  
  ;; Test that constants can be used in key sequences
  (test-assert "constants work in key sequences"
    (let ([seq (list (ctrl-key #\c) key-enter (alt-key #\a) key-escape)])
      (= (key-sequence-length seq) 4))))

;;; Tests for debug and testing functions
(test-group "debug-functions"
  ;; key-debug-info
  (test-assert "key-debug-info returns association list"
    (let ([debug-info (key-debug-info (make-key #:char #\a #:ctrl? #t))])
      (and (list? debug-info)
           (every pair? debug-info))))
  
  (test-assert "key-debug-info contains expected keys"
    (let ([debug-info (key-debug-info (make-key #:char #\a #:ctrl? #t))])
      (and (assq 'char debug-info)
           (assq 'symbol debug-info)
           (assq 'ctrl? debug-info)
           (assq 'string debug-info)
           (assq 'description debug-info))))
  
  (test-assert "key-debug-info has correct char info"
    (let ([debug-info (key-debug-info (make-key #:char #\x))])
      (char=? (cadr (assq 'char debug-info)) #\x)))
  
  ;; test-key-parsing (just test it doesn't crash)
  (test-assert "test-key-parsing runs without error"
    (catch #t
      (lambda ()
        (with-output-to-string
          (lambda () (test-key-parsing)))
        #t)
      (lambda (key . args) #f))))

;;; =================================================================
;;; SPECIAL CASES AND EDGE CASES
;;; =================================================================

(test-group "edge-cases"
  ;; Case sensitivity
  (test-assert "control keys are case-sensitive in parsing"
    (not (key-equivalent? (string->key "^c") (string->key "^C"))))
  
  ;; Function key bounds
  (test-assert "F1 through F12 are valid"
    (every (lambda (n)
             (valid-key-string? (format #f "F~a" n)))
           (iota 12 1)))
  
  ;; Multiple character sequences should fail
  (test-error "multi-character base key fails"
    (string->key "abc"))
  
  ;; Whitespace handling
  (test-equal "whitespace is normalized"
    (key->string (string->key " a "))
    "a"))

;;; =================================================================
;;; INTEGRATION TESTS
;;; =================================================================

(test-group "integration"
  ;; Complex workflow test
  (test-assert "complex key manipulation workflow"
    (let* ([key-str "C-A-S-F12"]
           [parsed-key (string->key key-str)]
           [formatted-key (key->string parsed-key)]
           [reparsed-key (string->key formatted-key)])
      (and (key-equivalent? parsed-key reparsed-key)
           (string=? key-str formatted-key))))
  
  ;; Key sequence workflow
  (test-assert "key sequence manipulation workflow"
    (let* ([seq-str "^C ^X A-a F1 up"]
           [parsed-seq (parse-key-sequence seq-str)]
           [formatted-seq (key-sequence->string parsed-seq)]
           [reparsed-seq (parse-key-sequence formatted-seq)])
      (and (= (length parsed-seq) (length reparsed-seq))
           (every key-equivalent? parsed-seq reparsed-seq))))
  
  ;; All special keys can be parsed and formatted
  (test-assert "all special keys roundtrip"
    (every (lambda (key-name)
             (string=? key-name 
                      (key->string (string->key key-name))))
           (get-special-key-names)))
  
  ;; All function keys can be parsed and formatted  
  (test-assert "all function keys roundtrip"
    (every (lambda (key-name)
             (string=? key-name
                      (key->string (string->key key-name))))
           (get-function-key-names))))

;;; Test suite cleanup
(test-end "gano-keys")
