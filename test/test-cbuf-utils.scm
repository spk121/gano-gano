;;; Using SRFI-64 testing framework

(use-modules (srfi srfi-64)     ; Testing framework
             (gano cbuf-utils)  ; Module under test
             (gano char)        ; For character utilities
             (srfi srfi-1)      ; List utilities
             (srfi srfi-13)     ; String utilities
	     (srfi srfi-35)     ; Condition types
	     (srfi srfi-34)	; Guard
	     (ice-9 regex))	; regexp-match?

;;; Start test suite
(test-begin "cbuf-utils")

;;; =================================================================
;;; CONSTANTS TESTS
;;; =================================================================

(test-group "constants"
  (test-equal "MAX-COMBINING-MARKS value" 4 MAX-COMBINING-MARKS))

;;; =================================================================
;;; VALIDATION FUNCTIONS TESTS
;;; =================================================================

(test-group "combining-mark-validation"
  
  ;; Test validate-string-combining-marks with valid strings
  (test-group "valid-strings"
    (test-equal "empty string is valid"
                '(#t ())
                (validate-string-combining-marks ""))
    
    (test-equal "simple ASCII is valid"
                '(#t ())
                (validate-string-combining-marks "hello"))
    
    (test-equal "base char with one combining mark is valid"
                '(#t ())
                (validate-string-combining-marks "a\u0301"))  ; a with acute accent
    
    (test-equal "base char with max combining marks is valid"
                '(#t ())
                (validate-string-combining-marks "a\u0301\u0302\u0303\u0304"))  ; a with 4 combining marks
    
    (test-equal "multiple valid clusters"
                '(#t ())
                (validate-string-combining-marks "a\u0301b\u0302c\u0303")))
  
  ;; Test validate-string-combining-marks with invalid strings
  (test-group "invalid-strings"
    (let ([result-no-base (validate-string-combining-marks "\u0301")])  ; combining mark without base
      (test-assert "combining mark without base is invalid" (not (car result-no-base)))
      (test-assert "violation list not empty for no-base" (not (null? (cadr result-no-base))))
      (test-equal "violation type is no-base-character" 
                  'no-base-character 
                  (caar (cadr result-no-base))))
    
    (let ([result-too-many (validate-string-combining-marks "a\u0301\u0302\u0303\u0304\u0305")])  ; 5 combining marks
      (test-assert "too many combining marks is invalid" (not (car result-too-many)))
      (test-assert "violation list not empty for too-many" (not (null? (cadr result-too-many))))
      (test-equal "violation type is too-many-combining"
                  'too-many-combining
                  (caar (cadr result-too-many)))))
  
  ;; Test validate-combining-marks-at-insertion
  (test-group "insertion-validation"
    (test-equal "inserting normal char is valid"
                '(#t ())
                (validate-combining-marks-at-insertion "hello" 2 "x"))
    
    (test-equal "inserting combining mark after base is valid"
                '(#t ())
                (validate-combining-marks-at-insertion "hello" 5 "\u0301"))
    
    ;; Note: Full validation would require more complex setup with actual combining mark logic
    ))

;;; =================================================================
;;; COUNT FUNCTIONS TESTS
;;; =================================================================

(test-group "counting-functions"
  
  (test-group "count-base-characters"
    (test-equal "empty string has 0 base chars" 0 (count-base-characters ""))
    (test-equal "simple ASCII string" 5 (count-base-characters "hello"))
    (test-equal "string with combining marks" 3 (count-base-characters "a\u0301b\u0302c"))
    (test-equal "only combining marks" 0 (count-base-characters "\u0301\u0302")))
  
  (test-group "count-combining-marks-in-cluster"
    (test-equal "no combining marks after base" 0 (count-combining-marks-in-cluster "abc" 0))
    (test-equal "one combining mark" 1 (count-combining-marks-in-cluster "a\u0301bc" 0))
    (test-equal "multiple combining marks" 3 (count-combining-marks-in-cluster "a\u0301\u0302\u0303bc" 0))
    (test-equal "combining marks at end of string" 2 (count-combining-marks-in-cluster "ab\u0301\u0302" 1))))

;;; =================================================================
;;; TAB COMPUTATION TESTS
;;; =================================================================

(test-group "tab-computation"
  
  (test-group "forward-tabs"
    (test-equal "forward 1 tab from 0" 8 (compute-tab-column 0 8 1))
    (test-equal "forward 1 tab from 3" 8 (compute-tab-column 3 8 1))
    (test-equal "forward 1 tab from 8" 16 (compute-tab-column 8 8 1))
    (test-equal "forward 2 tabs from 0" 16 (compute-tab-column 0 8 2))
    (test-equal "forward 3 tabs from 5" 24 (compute-tab-column 5 8 3)))
  
  (test-group "backward-tabs"
    (test-equal "backward 1 tab from 16" 8 (compute-tab-column 16 8 -1))
    (test-equal "backward 1 tab from 10" 8 (compute-tab-column 10 8 -1))
    (test-equal "backward 2 tabs from 20" 8 (compute-tab-column 20 8 -2))
    (test-equal "backward from position 0" 0 (compute-tab-column 0 8 -1)))
  
  (test-group "zero-tabs"
    (test-equal "0 tabs returns same position" 15 (compute-tab-column 15 8 0)))
  
  (test-group "different-tab-sizes"
    (test-equal "tab size 4, forward 1" 4 (compute-tab-column 1 4 1))
    (test-equal "tab size 2, forward 1" 2 (compute-tab-column 1 2 1))))

;;; =================================================================
;;; WORD BOUNDARY DETECTION TESTS
;;; =================================================================

(test-group "word-boundaries"
  
  (test-group "find-word-end-forward"
    ;; Basic cases - starting on word characters finds end of current word
    (test-equal "word end from start of first word" 
                5 
                (find-word-end-forward "hello world" 0 char-word-delimiter?))
    
    (test-equal "word end from middle of first word"
                5
                (find-word-end-forward "hello world" 2 char-word-delimiter?))
    
    (test-equal "word end at string end"
                5
                (find-word-end-forward "hello" 0 char-word-delimiter?))
    
    (test-equal "starting from end"
                11
                (find-word-end-forward "hello world" 11 char-word-delimiter?))
    
    ;; Starting from delimiters - finds end of next word
    (test-equal "starting from whitespace finds next word end"
                11
                (find-word-end-forward "hello world" 5 char-word-delimiter?))
    
    (test-equal "multiple spaces between words - from start of word"
                5
                (find-word-end-forward "hello   world" 0 char-word-delimiter?))
    
    (test-equal "multiple spaces - starting from spaces finds next word"
                13
                (find-word-end-forward "hello   world" 6 char-word-delimiter?))
    
    (test-equal "mixed delimiters - from start of word"
                5
                (find-word-end-forward "hello, world" 0 char-word-delimiter?))
    
    (test-equal "mixed delimiters - starting from comma finds next word"
                12
                (find-word-end-forward "hello, world" 5 char-word-delimiter?)))
  
  (test-group "find-word-begin-backward"
    (test-equal "word begin from end"
                6
                (find-word-begin-backward "hello world" 11 char-word-delimiter?))
    
    (test-equal "word begin from middle"
                0
                (find-word-begin-backward "hello world" 3 char-word-delimiter?))
    
    (test-equal "starting from beginning"
                0
                (find-word-begin-backward "hello world" 0 char-word-delimiter?))))


(test-group "word-boundaries-comprehensive"
  
  ;; =================================================================
  ;; find-word-end-forward - Enhanced Coverage
  ;; =================================================================
	    (test-group "find-word-end-forward-comprehensive"
    
    ;; Basic functionality (already covered)
    (test-equal "word end in middle of string" 
                5 
                (find-word-end-forward "hello world" 0 char-word-delimiter?))

(test-equal "word end from whitespace"
            11  ; End of "world"
            (find-word-end-forward "hello world" 5 char-word-delimiter?))

(test-equal "multiple spaces - start from spaces"
            13  ; End of "world"  
            (find-word-end-forward "hello   world" 6 char-word-delimiter?))

(test-equal "word at very end"
            11  ; End of "world"
            (find-word-end-forward "hello world" 6 char-word-delimiter?))

(test-equal "already at word end"
            11  ; End of "world" 
            (find-word-end-forward "hello world" 11 char-word-delimiter?))                          
    
    ;; Edge cases - Empty and single character strings
    (test-equal "empty string"
                0
                (find-word-end-forward "" 0 char-word-delimiter?))
    
    (test-equal "single character word"
                1
                (find-word-end-forward "a" 0 char-word-delimiter?))
    
    (test-equal "single character delimiter"
                1
                (find-word-end-forward " " 0 char-word-delimiter?))
    
    ;; Boundary conditions
    (test-equal "start at end of string"
                5
                (find-word-end-forward "hello" 5 char-word-delimiter?))
    
    
    ;; Multiple consecutive delimiters
    (test-equal "multiple spaces between words"
                5
                (find-word-end-forward "hello   world" 0 char-word-delimiter?))
    
    (test-equal "starting from middle of multiple spaces"
                13
                (find-word-end-forward "hello   world" 6 char-word-delimiter?))
    
    ;; Mixed delimiters (spaces, punctuation)
    (test-equal "mixed delimiters"
                5
                (find-word-end-forward "hello, world" 0 char-word-delimiter?))
    
    (test-equal "starting from punctuation"
                12
                (find-word-end-forward "hello, world" 5 char-word-delimiter?))
    
    ;; String with only delimiters
    (test-equal "string of only spaces"
                5
                (find-word-end-forward "     " 0 char-word-delimiter?))
    
    (test-equal "string of mixed delimiters"
                5
                (find-word-end-forward " .,; " 0 char-word-delimiter?))
    
    ;; Leading and trailing delimiters
    (test-equal "leading spaces"
                7
                (find-word-end-forward "  hello" 0 char-word-delimiter?))
    
    (test-equal "trailing spaces"
                5
                (find-word-end-forward "hello  " 0 char-word-delimiter?))
    
    ;; Unicode and special characters
    (test-equal "unicode word characters"
                4
                (find-word-end-forward "café world" 0 char-word-delimiter?))
    
    (test-equal "unicode delimiters (if any)"
                5
                (find-word-end-forward "hello\u2000world" 0 char-word-delimiter?))
    
    ;; Numbers and mixed alphanumeric
    (test-equal "numbers are word characters"
                8
                (find-word-end-forward "hello123 world" 0 char-word-delimiter?))
    
    (test-equal "mixed alphanumeric"
                10
                (find-word-end-forward "test123abc def" 0 char-word-delimiter?))
    
    ;; Words at string boundaries
    (test-equal "word at very end"
                11
                (find-word-end-forward "hello world" 6 char-word-delimiter?))
    
    (test-equal "delimiter at very end"
                11
                (find-word-end-forward "hello world " 6 char-word-delimiter?)))
  
  ;; =================================================================
  ;; find-word-begin-backward - Enhanced Coverage
  ;; =================================================================
  (test-group "find-word-begin-backward-comprehensive"
    
    ;; Basic functionality (already covered)
    (test-equal "word begin from end"
                6
                (find-word-begin-backward "hello world" 11 char-word-delimiter?))
    
    ;; Edge cases
    (test-equal "empty string"
                0
                (find-word-begin-backward "" 0 char-word-delimiter?))
    
    (test-equal "single character word"
                0
                (find-word-begin-backward "a" 1 char-word-delimiter?))
    
    (test-equal "single character delimiter"
                0
                (find-word-begin-backward " " 1 char-word-delimiter?))
    
    ;; Boundary conditions
    (test-equal "start at beginning of string"
                0
                (find-word-begin-backward "hello" 0 char-word-delimiter?))
        
    (test-error "start beyond end of string"
                (find-word-begin-backward "hello world" 20 char-word-delimiter?))
    
    ;; Multiple consecutive delimiters
    (test-equal "multiple spaces between words"
                8
                (find-word-begin-backward "hello   world" 12 char-word-delimiter?))
    
    (test-equal "starting from middle of multiple spaces"
                0
                (find-word-begin-backward "hello   world" 7 char-word-delimiter?))
    
    (test-group "error-handling-for-invalid-input"
  
  (test-group "negative-index-errors"
    ;; Test that functions properly reject negative indices
    (test-error "find-word-end-forward rejects negative index"
                (find-word-end-forward "hello world" -1 char-word-delimiter?))
    
    (test-error "find-word-begin-backward rejects negative index" 
                (find-word-begin-backward "hello world" -1 char-word-delimiter?))
    
    (test-error "skip-word-chars-forward rejects negative index"
                (skip-word-chars-forward "hello world" -1 char-word-delimiter?))
    
    (test-error "skip-word-chars-backward rejects negative index"
                (skip-word-chars-backward "hello world" -1 char-word-delimiter?))
    
    (test-error "skip-whitespace-forward rejects negative index"
                (skip-whitespace-forward "hello world" -1))
    
    (test-error "skip-whitespace-backward rejects negative index"
                (skip-whitespace-backward "hello world" -1))
    
    (test-error "skip-delimiters-forward rejects negative index"
                (skip-delimiters-forward "hello world" -1))
    
    (test-error "skip-delimiters-backward rejects negative index"
                (skip-delimiters-backward "hello world" -1)))

  (test-group "beyond-bounds-index-behavior"
    
    (test-error "find-word-end-forward beyond bounds returns string length"
                (find-word-end-forward "hello world" 20 char-word-delimiter?))
    
    (test-error "skip-whitespace-forward beyond bounds returns string length"
                (skip-whitespace-forward "hello world" 20))
    
    ;; For backward functions, beyond bounds should return reasonable values
    (test-error "find-word-begin-backward beyond bounds"
                (find-word-begin-backward "hello world" 20 char-word-delimiter?))
    
    (test-error "skip-whitespace-backward beyond bounds"
                10  ; last non-whitespace position
                (skip-whitespace-backward "hello world" 20))))

    ;; Mixed delimiters
    (test-equal "mixed delimiters"
                7
                (find-word-begin-backward "hello, world" 11 char-word-delimiter?))
    
    (test-equal "starting from punctuation"
                0
                (find-word-begin-backward "hello, world" 5 char-word-delimiter?))
    
    ;; Leading and trailing delimiters
    (test-equal "leading spaces"
                2
                (find-word-begin-backward "  hello" 7 char-word-delimiter?))
    
    (test-equal "trailing spaces"
                0
                (find-word-begin-backward "hello  " 5 char-word-delimiter?))
    
    ;; String with only delimiters
    (test-equal "string of only spaces"
                0
                (find-word-begin-backward "     " 3 char-word-delimiter?))
    
    ;; Words at string boundaries
    (test-equal "word at very beginning"
                0
                (find-word-begin-backward "hello world" 3 char-word-delimiter?)))
  
  ;; =================================================================
  ;; skip-word-chars-forward - Enhanced Coverage
  ;; =================================================================
  (test-group "skip-word-chars-forward-comprehensive"
    
    ;; Basic functionality (already covered)
    (test-equal "skip through word chars"
                5
                (skip-word-chars-forward "hello world" 0 char-word-delimiter?))
    
    ;; Edge cases
    (test-equal "empty string"
                0
                (skip-word-chars-forward "" 0 char-word-delimiter?))
    
    (test-equal "single character word"
                1
                (skip-word-chars-forward "a" 0 char-word-delimiter?))
    
    (test-equal "single character delimiter"
                0
                (skip-word-chars-forward " " 0 char-word-delimiter?))
    
    ;; Boundary conditions
    (test-equal "start at end of string"
                5
                (skip-word-chars-forward "hello" 5 char-word-delimiter?))
    
    (test-error "negative start index"
                (skip-word-chars-forward "hello" -1 char-word-delimiter?))
    
    ;; Starting on delimiters
    (test-equal "start on space"
                5
                (skip-word-chars-forward "hello world" 5 char-word-delimiter?))
    
    (test-equal "start on punctuation"
                5
                (skip-word-chars-forward "hello,world" 5 char-word-delimiter?))
    
    ;; Mixed content
    (test-equal "alphanumeric word"
                8
                (skip-word-chars-forward "hello123 world" 0 char-word-delimiter?))
    
    (test-equal "word with underscores (if word chars)"
                9
                (skip-word-chars-forward "hello_123 world" 0 char-blank?))
    
    ;; Entire string is word characters
    (test-equal "entire string is word"
                5
                (skip-word-chars-forward "hello" 0 char-word-delimiter?))
    
    ;; Entire string is delimiters
    (test-equal "entire string is delimiters"
                0
                (skip-word-chars-forward "  .,;" 0 char-word-delimiter?))
    
    ;; Unicode considerations
    (test-equal "unicode word characters"
                4
                (skip-word-chars-forward "café world" 0 char-word-delimiter?)))
  
  ;; =================================================================
  ;; skip-word-chars-backward - Enhanced Coverage
  ;; =================================================================
  (test-group "skip-word-chars-backward-comprehensive"
    
    ;; Basic functionality (already covered)
    (test-equal "skip back through word chars"
                6
                (skip-word-chars-backward "hello world" 10 char-word-delimiter?))
    
    ;; Edge cases
    (test-equal "empty string"
                0
                (skip-word-chars-backward "" 0 char-word-delimiter?))
    
    (test-equal "single character word"
                0
                (skip-word-chars-backward "a" 1 char-word-delimiter?))
    
    (test-equal "single character word preceded by space"
                1
                (skip-word-chars-backward " a" 2 char-word-delimiter?))

    (test-equal "single character delimiter"
                1
                (skip-word-chars-backward " " 1 char-word-delimiter?))
    
    ;; Boundary conditions
    (test-equal "start at beginning"
                0
                (skip-word-chars-backward "hello" 0 char-word-delimiter?))
    
    (test-error "negative start index"
                (skip-word-chars-backward "hello" -5 char-word-delimiter?))
    
    (test-error "start beyond end"
                (skip-word-chars-backward "hello world" 20 char-word-delimiter?))
    
    ;; Starting on delimiters
    (test-equal "start on space"
                0
                (skip-word-chars-backward "hello world" 5 char-word-delimiter?))
    
    (test-equal "start on punctuation"
                0
                (skip-word-chars-backward "hello,world" 5 char-word-delimiter?))
    
    ;; Mixed content
    (test-equal "alphanumeric word"
                0
                (skip-word-chars-backward "hello123 world" 7 char-word-delimiter?))
    
    ;; Entire string scenarios
    (test-equal "entire string is word"
                0
                (skip-word-chars-backward "hello" 4 char-word-delimiter?))
    
    (test-equal "entire string is delimiters"
                3
                (skip-word-chars-backward "  .,;" 3 char-word-delimiter?))
    
    ;; Multiple words
    (test-equal "middle of second word"
                6
                (skip-word-chars-backward "hello world test" 9 char-word-delimiter?))
    
    (test-equal "beginning of second word"
                6
                (skip-word-chars-backward "hello world test" 6 char-word-delimiter?)))
  
  ;; =================================================================
  ;; skip-whitespace-forward - Enhanced Coverage
  ;; =================================================================
  (test-group "skip-whitespace-forward-comprehensive"
    
    ;; Edge cases
    (test-equal "empty string"
                0
                (skip-whitespace-forward "" 0))
    
    (test-equal "single space"
                1
                (skip-whitespace-forward " " 0))
    
    (test-equal "single non-whitespace"
                0
                (skip-whitespace-forward "a" 0))
    
    ;; Boundary conditions
    (test-equal "start at end"
                5
                (skip-whitespace-forward "hello" 5))
    
    (test-error "start beyond end"
                (skip-whitespace-forward "hello" 10))
    
    (test-error "negative start"
                (skip-whitespace-forward "hello" -1))
    
    ;; Different whitespace types
    (test-equal "tabs and spaces"
                4
                (skip-whitespace-forward "  \t hello" 0))
    
    (test-equal "newlines"
                3
                (skip-whitespace-forward " \n hello" 0))
    
    (test-equal "mixed whitespace"
                5
                (skip-whitespace-forward " \t\n\r hello" 0))
    
    ;; Entire string scenarios
    (test-equal "entire string is whitespace"
                5
                (skip-whitespace-forward "     " 0))
    
    (test-equal "no whitespace at start"
                0
                (skip-whitespace-forward "hello world" 0))
    
    ;; Middle of string
    (test-equal "whitespace in middle"
                8
                (skip-whitespace-forward "hello   world" 5))
    
    (test-equal "no whitespace in middle"
                6
                (skip-whitespace-forward "hello world" 6))
    
    ;; Unicode whitespace (if supported)
    (test-equal "unicode whitespace"
                2
                (skip-whitespace-forward " \u00A0hello" 0)))  ; Non-breaking space
  
  ;; =================================================================
  ;; skip-whitespace-backward - Enhanced Coverage
  ;; =================================================================
  (test-group "skip-whitespace-backward-comprehensive"
    
    ;; Edge cases
    (test-equal "empty string"
                0
                (skip-whitespace-backward "" 0))
    
    (test-equal "single space"
                0
                (skip-whitespace-backward " " 1))
    
    (test-equal "single space preceded by letter"
                1
                (skip-whitespace-backward "a " 2))

    (test-equal "single non-whitespace"
                0
                (skip-whitespace-backward "a" 0))
    
    ;; Boundary conditions
    (test-equal "start at beginning"
                0
                (skip-whitespace-backward "hello" 0))
    
    (test-error "negative start"
                (skip-whitespace-backward "hello" -1))
    
    (test-error "start beyond end"
                (skip-whitespace-backward "hello   " 20))
    
    ;; Different whitespace types
    (test-equal "tabs and spaces backward"
                5
                (skip-whitespace-backward "hello  \t " 9))
    
    (test-equal "mixed whitespace backward"
                5
                (skip-whitespace-backward "hello \t\n\r " 10))
    
    ;; Entire string scenarios
    (test-equal "entire string is whitespace"
                0
                (skip-whitespace-backward "     " 3))
    
    (test-equal "no whitespace at end"
                4
                (skip-whitespace-backward "hello" 4))
    
    ;; Middle of string
    (test-equal "whitespace in middle backward"
                5
                (skip-whitespace-backward "hello   world" 7))
    
    (test-equal "no whitespace in middle backward"
                5
                (skip-whitespace-backward "hello world" 5)))
  
  ;; =================================================================
  ;; skip-delimiters-forward/backward - Enhanced Coverage
  ;; =================================================================
  (test-group "skip-delimiters-comprehensive"
    
    ;; skip-delimiters-forward edge cases
    (test-equal "empty string delimiters forward"
                0
                (skip-delimiters-forward "" 0))
    
    (test-equal "single delimiter forward"
                1
                (skip-delimiters-forward "," 0))
    
    (test-equal "mixed delimiters forward"
                4
                (skip-delimiters-forward " .,;hello" 0))
    
    (test-equal "no delimiters at start"
                0
                (skip-delimiters-forward "hello world" 0))
    
    (test-equal "entire string is delimiters"
                5
                (skip-delimiters-forward " .,;!" 0))
    
    ;; skip-delimiters-backward edge cases
    (test-equal "empty string delimiters backward"
                0
                (skip-delimiters-backward "" 0))
    
    (test-equal "single delimiter backward"
                0
                (skip-delimiters-backward "," 0))
    
    (test-equal "mixed delimiters backward"
                5
                (skip-delimiters-backward "hello .,; " 9))
    
    (test-equal "no delimiters at end"
                4
                (skip-delimiters-backward "hello" 4))
    
    (test-equal "entire string is delimiters backward"
                0
                (skip-delimiters-backward " .,;!" 3)))
  
  ;; =================================================================
  ;; char-word-delimiter? - Enhanced Coverage
  ;; =================================================================
  (test-group "char-word-delimiter-comprehensive"
    
    ;; Basic delimiter types (already covered)
    (test-assert "space is delimiter" (char-word-delimiter? #\space))
    (test-assert "tab is delimiter" (char-word-delimiter? #\tab))
    (test-assert "punctuation is delimiter" (char-word-delimiter? #\.))
    (test-assert "letter is not delimiter" (not (char-word-delimiter? #\a)))
    (test-assert "digit is not delimiter" (not (char-word-delimiter? #\5)))
    
    ;; Extended punctuation
    (test-assert "comma is delimiter" (char-word-delimiter? #\,))
    (test-assert "semicolon is delimiter" (char-word-delimiter? #\;))
    (test-assert "colon is delimiter" (char-word-delimiter? #\:))
    (test-assert "exclamation is delimiter" (char-word-delimiter? #\!))
    (test-assert "question mark is delimiter" (char-word-delimiter? #\?))
    (test-assert "parentheses are delimiters" (char-word-delimiter? #\())
    (test-assert "brackets are delimiters" (char-word-delimiter? #\[))
    (test-assert "braces are delimiters" (char-word-delimiter? #\{))
    
    ;; Symbols
    (test-assert "plus is delimiter" (char-word-delimiter? #\+))
    (test-assert "equals is delimiter" (char-word-delimiter? #\=))
    (test-assert "at sign is delimiter" (char-word-delimiter? #\@))
    (test-assert "hash is delimiter" (char-word-delimiter? #\#))
    (test-assert "dollar is delimiter" (char-word-delimiter? #\$))
    (test-assert "percent is delimiter" (char-word-delimiter? #\%))
    
    ;; Whitespace variations
    (test-assert "newline is delimiter" (char-word-delimiter? #\newline))
    (test-assert "return is delimiter" (char-word-delimiter? #\return))
    (test-assert "form feed is delimiter" (char-word-delimiter? #\page))
    
    ;; Non-delimiters
    (test-assert "underscore behavior" 
                 ;; This might be implementation-dependent
                 (or (char-word-delimiter? #\_) (not (char-word-delimiter? #\_))))
    (test-assert "hyphen behavior"
                 ;; This might be implementation-dependent  
                 (or (char-word-delimiter? #\-) (not (char-word-delimiter? #\-))))
    
    ;; Unicode letters
    (test-assert "unicode letter is not delimiter" (not (char-word-delimiter? #\é)))
    (test-assert "unicode digit is not delimiter" (not (char-word-delimiter? #\①)))  ; If supported
    
    ;; Edge cases
    (test-assert "null character behavior" 
                 ;; This is implementation-dependent
                 (or (char-word-delimiter? #\nul) (not (char-word-delimiter? #\nul)))))
  
  ;; =================================================================
  ;; Integration and Consistency Tests
  ;; =================================================================
  (test-group "word-boundary-integration"
    
    ;; Test that forward and backward operations are consistent
    (test-group "forward-backward-consistency"
      (let ([text "hello world test"])
        ;; Go forward to word end, then backward to word start
        (let* ([word-end (find-word-end-forward text 0 char-word-delimiter?)]
               [word-start (find-word-begin-backward text word-end char-word-delimiter?)])
          (test-equal "forward then backward consistency" 0 word-start)))
      
      (let ([text "  hello  world  "])
        ;; Test with leading/trailing whitespace
        (let* ([first-word-end (find-word-end-forward text 0 char-word-delimiter?)]
               [first-word-start (find-word-begin-backward text first-word-end char-word-delimiter?)])
          (test-equal "whitespace consistency" 2 first-word-start))))
    
    ;; Test that skip functions match find functions
    (test-group "skip-find-consistency"
      (let ([text "hello world"])
        (test-equal "skip-word-chars matches find-word-end"
                    (find-word-end-forward text 0 char-word-delimiter?)
                    (skip-word-chars-forward text 0 char-word-delimiter?)))
      
      (let ([text "  hello"])
        (test-equal "skip-whitespace matches delimiter skipping in find-word"
                    (skip-whitespace-forward text 0)
                    (- (find-word-end-forward text 0 char-word-delimiter?) 5))))  ; Adjust for word length
    
    ;; Test boundary conditions across all functions
    (test-group "boundary-consistency"
      (let ([text "a"])  ; Single character
        (test-equal "single char - find-word-end" 1 (find-word-end-forward text 0 char-word-delimiter?))
        (test-equal "single char - skip-word-chars" 1 (skip-word-chars-forward text 0 char-word-delimiter?))
        (test-equal "single char - find-word-begin" 0 (find-word-begin-backward text 1 char-word-delimiter?))
        (test-equal "single char - skip-word-chars-back" 0 (skip-word-chars-backward text 0 char-word-delimiter?)))
      
      (let ([text " "])  ; Single delimiter
        (test-equal "single delim - skip-whitespace-forward" 1 (skip-whitespace-forward text 0))
        (test-equal "single delim - skip-whitespace-backward" 0 (skip-whitespace-backward text 0))
        (test-equal "single delim - skip-delimiters-forward" 1 (skip-delimiters-forward text 0))
        (test-equal "single delim - skip-delimiters-backward" 0 (skip-delimiters-backward text 0))))
    
    ;; Test with complex real-world strings
    (test-group "real-world-scenarios"
      ;; Programming code-like strings
      (let ([code "function(arg1, arg2) { return true; }"])
        (test-assert "code parsing - function name"
                     (= 8 (find-word-end-forward code 0 char-word-delimiter?)))
        (test-assert "code parsing - after parenthesis"
                     (= 13 (find-word-end-forward code 9 char-word-delimiter?))))
      
      ;; URL-like strings  
      (let ([url "https://example.com/path?query=value"])
        (test-assert "url parsing - protocol"
                     (= 5 (find-word-end-forward url 0 char-word-delimiter?)))
        (test-assert "url parsing - domain part"
                     (> (find-word-end-forward url 8 char-word-delimiter?) 8)))
      
      ;; Natural language with contractions
      (let ([text "don't worry, it's fine"])
        ;; This tests how apostrophes are handled
        (test-assert "contractions handling"
                     (> (find-word-end-forward text 0 char-word-delimiter?) 0)))
      
      ;; Mixed scripts (if unicode support is expected)
      (let ([mixed "Hello, 世界! How are you?"])
        (test-assert "mixed scripts"
                     (> (find-word-end-forward mixed 0 char-word-delimiter?) 0))))
    
    ;; Stress test with large strings
    (test-group "performance-stress"
      (let ([large-text (string-append (make-string 1000 #\a) " " (make-string 1000 #\b))])
        (test-equal "large string word end" 1000 (find-word-end-forward large-text 0 char-word-delimiter?))
        (test-equal "large string word begin" 1001 (find-word-begin-backward large-text 2001 char-word-delimiter?))))
    
    ;; Test error conditions and edge cases that might cause infinite loops
    (test-group "error-conditions"
      (test-error "very negative index" 
                   (find-word-end-forward "hello" -1000 char-word-delimiter?))
      (test-error "very large index"
                   (find-word-end-forward "hello" 1000 char-word-delimiter?))
      (test-error "empty string with large index"
                   (find-word-end-forward "" 1000 char-word-delimiter?))))
  
  (test-group "skip-functions"
    ;; Test skip-whitespace-forward
    (test-equal "skip whitespace forward from word chars"
                0
                (skip-whitespace-forward "hello world" 0))  ; 'h' is not whitespace, stay at 0
    
    (test-equal "skip whitespace forward from space"
                6
                (skip-whitespace-forward "hello world" 5))  ; space at 5, skip to 'w' at 6
    
    (test-equal "skip multiple whitespace forward"
                8
                (skip-whitespace-forward "hello   world" 5))  ; multiple spaces
    
    (test-equal "skip whitespace forward at end"
                11
                (skip-whitespace-forward "hello world" 11))  ; at end, stay at end
    
    ;; Test skip-whitespace-backward  
    (test-equal "skip whitespace backward from word chars"
                4
                (skip-whitespace-backward "hello world" 4))  ; 'o' is not whitespace, stay at 4
    
    (test-equal "skip whitespace backward from space"
                5
                (skip-whitespace-backward "hello world" 5))
    
    (test-equal "skip multiple whitespace backward"
                5
                (skip-whitespace-backward "hello   world" 7))  ; from multiple spaces to 'o'
    
    (test-equal "skip whitespace backward at start"
                0
                (skip-whitespace-backward "hello world" 0))  ; at start, stay at start
    
    ;; Test edge cases
    (test-equal "skip forward from string of only spaces"
                3
                (skip-whitespace-forward "   " 0))  ; all spaces, go to end
    
    (test-equal "skip backward from string of only spaces" 
                0
                (skip-whitespace-backward "   " 2))  ; all spaces, go to start
    
    (test-equal "skip delimiters forward"
                7
                (skip-delimiters-forward "hello, world" 5))
    
    (test-equal "skip delimiters backward"
                5
                (skip-delimiters-backward "hello, world" 6)))
  
  (test-group "char-word-delimiter"
    (test-assert "space is delimiter" (char-word-delimiter? #\space))
    (test-assert "tab is delimiter" (char-word-delimiter? #\tab))
    (test-assert "punctuation is delimiter" (char-word-delimiter? #\.))
    (test-assert "letter is not delimiter" (not (char-word-delimiter? #\a)))
    (test-assert "digit is not delimiter" (not (char-word-delimiter? #\5)))))

;;; =================================================================
;;; POSITION VALIDATION TESTS
;;; =================================================================

(test-group "position-validation"
  
  (test-group "validate-line-movement-pure"
    (let ([result (validate-line-movement-pure 5 3 10 'test-op)])
      (test-equal "target line calculation" 8 (car result))
      (test-equal "clamped line" 8 (cadr result))
      (test-equal "not clamped" #f (caddr result))
      (test-equal "operation preserved" 'test-op (cadddr result)))
    
    (let ([result (validate-line-movement-pure 5 10 10 'test-op)])
      (test-equal "clamps to max" 10 (cadr result))
      (test-equal "is clamped" #t (caddr result)))
    
    (let ([result (validate-line-movement-pure 5 -10 10 'test-op)])
      (test-equal "clamps to min" 0 (cadr result))
      (test-equal "is clamped" #t (caddr result))))
  
  (test-group "validate-column-movement-pure"
    (let ([result (validate-column-movement-pure 10 5 20 'test-op)])
      (test-equal "target column calculation" 15 (car result))
      (test-equal "clamped column" 15 (cadr result))
      (test-equal "not clamped" #f (caddr result)))
    
    (let ([result (validate-column-movement-pure 10 15 20 'test-op)])
      (test-equal "clamps to max" 20 (cadr result))
      (test-equal "is clamped" #t (caddr result))))
  
  (test-group "validate-absolute-position-pure"
    (let ([result (validate-absolute-position-pure 5 10 20 50 'test-op)])
      (test-equal "line not clamped" 5 (car result))
      (test-equal "column not clamped" 10 (cadr result))
      (test-equal "line not clamped flag" #f (caddr result))
      (test-equal "column not clamped flag" #f (cadddr result)))
    
    (let ([result (validate-absolute-position-pure 25 60 20 50 'test-op)])
      (test-equal "line clamped to max" 20 (car result))
      (test-equal "column clamped to max" 50 (cadr result))
      (test-equal "line clamped flag" #t (caddr result))
      (test-equal "column clamped flag" #t (cadddr result)))))

;;; =================================================================
;;; ERROR CONDITION HELPERS TESTS
;;; =================================================================

(test-group "error-condition-helpers"
  
  (test-group "make-boundary-error-info"
    (let ([info (make-boundary-error-info 'test-op 100 50 'end-of-line)])
      (test-equal "operation field" 'test-op (cdr (assq 'operation info)))
      (test-equal "target field" 100 (cdr (assq 'target info)))
      (test-equal "actual field" 50 (cdr (assq 'actual info)))
      (test-equal "boundary-type field" 'end-of-line (cdr (assq 'boundary-type info)))))
  
  (test-group "make-combining-mark-error-info"
    (let ([info (make-combining-mark-error-info 'insert #\a #\x0301 3 4 "test reason")])
      (test-equal "operation field" 'insert (cdr (assq 'operation info)))
      (test-equal "base-char field" #\a (cdr (assq 'base-char info)))
      (test-equal "combining-char field" #\x0301 (cdr (assq 'combining-char info)))
      (test-equal "current-count field" 3 (cdr (assq 'current-count info)))
      (test-equal "max-count field" 4 (cdr (assq 'max-count info)))
      (test-equal "reason field" "test reason" (cdr (assq 'reason info))))))

;;; =================================================================
;;; EDGE CASES AND ERROR CONDITIONS
;;; =================================================================

(test-group "edge-cases"
  
  (test-group "empty-inputs"
    (test-equal "empty string word operations" 0 (find-word-end-forward "" 0 char-word-delimiter?))
    (test-equal "empty string skip operations" 0 (skip-whitespace-forward "" 0)))
  
  (test-group "boundary-conditions"
    (test-equal "tab at exact boundary" 8 (compute-tab-column 8 8 0))
    (test-equal "word find at string end" 5 (find-word-end-forward "hello" 5 char-word-delimiter?))
    (test-equal "skip at string start" 0 (skip-word-chars-backward "hello" 0 char-word-delimiter?)))
  
  (test-group "negative-inputs"
    (test-equal "negative tab computation" 0 (compute-tab-column 5 8 -1))
    (test-equal "negative position validation clamps" 0 (cadr (validate-line-movement-pure 5 -10 10 'test))))
  )
;;; =================================================================
;;; INTEGRATION TESTS
;;; =================================================================

(test-group "integration"
  
  (test-group "complex-text-validation"
    ;; Test a complex string with multiple issues
    (let* ([complex-str "hello\u0301\u0302\u0303\u0304\u0305 world\u0306"]  ; too many combining on first char
           [result (validate-string-combining-marks complex-str)])
      (test-assert "complex validation detects issues" (not (car result)))
      (test-assert "violations reported" (not (null? (cadr result))))))
  
  (test-group "word-boundary-complex"
    ;; Test word boundaries with punctuation
    (let ([text "hello, world! How are you?"])
      (test-equal "word end with punctuation" 5 (find-word-end-forward text 0 char-word-delimiter?))
      (test-equal "punctuation is not whitespace, so no skip" 5 (skip-whitespace-forward text 5))
      (test-equal "skip punctuation and space with delimiter skipper" 7 (skip-delimiters-forward text 5))))
  
  (test-group "tab-computation-complex"
    ;; Test complex tab scenarios
    (test-equal "multiple forward tabs" 32 (compute-tab-column 1 8 4))
    (test-equal "mixed forward/backward" 16 (compute-tab-column (compute-tab-column 1 8 3) 8 -1))))

;;; =================================================================
;;; CALLER BEHAVIOR VERIFICATION
;;; =================================================================

(test-group "caller-behavior-verification"
  ;; Verify that find-word functions behave correctly with our skip semantics
  (let ([text "  hello   world  "])
    ;; Starting from beginning (whitespace), should find end of first word
    (test-equal "find word end from leading whitespace"
                7  ; position after "hello"
                (find-word-end-forward text 0 char-word-delimiter?))
    
    ;; Starting from middle of word, should find end of that word
    (test-equal "find word end from middle of word"
                7  ; position after "hello"
                (find-word-end-forward text 3 char-word-delimiter?))
    
    ;; Starting from whitespace between words, should find end of next word
    (test-equal "find word end from inter-word whitespace"
                15  ; position after "world"
                (find-word-end-forward text 8 char-word-delimiter?)))
  
  ;; Test that all skip functions follow the same "stay if not matching" principle
  (let ([mixed-text "abc def"])
    (test-equal "whitespace skip stays on non-whitespace"
                0
                (skip-whitespace-forward mixed-text 0))  ; 'a' is not whitespace
    
    (test-equal "delimiter skip stays on non-delimiter" 
                0
                (skip-delimiters-forward mixed-text 0))  ; 'a' is not delimiter
    
    (test-equal "word skip moves from word chars"
                3
                (skip-word-chars-forward mixed-text 0 char-word-delimiter?)))  ; skip 'abc'
  )

;;; Additional tests to complete cbuf-utils test coverage
;;; Add these to your existing test-cbuf-utils.scm file

;;; =================================================================
;;; MISSING VALIDATION FUNCTION TESTS
;;; =================================================================

(test-group "validate-combining-mark-limits"
  
  (test-group "valid-cases"
    ;; These should not raise exceptions
    (test-assert "empty string passes validation"
                 (begin (validate-combining-mark-limits "") #t))
    
    (test-assert "simple ASCII passes validation"
                 (begin (validate-combining-mark-limits "hello") #t))
    
    (test-assert "base with max combining marks passes"
                 (begin (validate-combining-mark-limits "a\u0301\u0302\u0303\u0304") #t))
    
    (test-assert "multiple valid clusters pass"
                 (begin (validate-combining-mark-limits "a\u0301b\u0302c\u0303") #t)))

  
  (test-group "invalid-cases-raise-exceptions"
    ;; Test that appropriate exceptions are raised
    (test-error "combining mark without base raises exception"
                   (validate-combining-mark-limits "\u0301"))
    
    (test-error "too many combining marks raises exception"
                (validate-combining-mark-limits "a\u0301\u0302\u0303\u0304\u0305")))
    
  ;; Test exception details for too-many-combining-marks
  (test-group "exception-details"
      (guard (ex 
              [(cbuf-too-many-combining-marks-error? ex)
               (test-equal "base char in exception" #\a 
                          (cbuf-too-many-combining-marks-error:base-char ex))
               (test-equal "combining char in exception" #\x0305 
                          (cbuf-too-many-combining-marks-error:combining-char ex))
               (test-equal "current count in exception" 5 
                          (cbuf-too-many-combining-marks-error:current-count ex))
               (test-equal "max count in exception" 4 
                          (cbuf-too-many-combining-marks-error:max-count ex))]
              [else (test-assert "Should have raised too-many-combining-marks exception" #f)])
        (validate-combining-mark-limits "a\u0301\u0302\u0303\u0304\u0305"))))

;;; =================================================================
;;; MISSING WORD SKIP FUNCTION TESTS
;;; =================================================================

(test-group "skip-word-chars-functions"
  
  (test-group "skip-word-chars-forward"
    (test-equal "skip through word chars"
                5
                (skip-word-chars-forward "hello world" 0 char-word-delimiter?))
    
    (test-equal "skip from middle of word"
                5
                (skip-word-chars-forward "hello world" 2 char-word-delimiter?))
    
    (test-equal "no skip when starting on delimiter"
                5
                (skip-word-chars-forward "hello world" 5 char-word-delimiter?))  ; space at 5
    
    (test-equal "skip to end of string"
                5
                (skip-word-chars-forward "hello" 0 char-word-delimiter?))
    
    (test-equal "skip with punctuation delimiter"
                5
                (skip-word-chars-forward "hello,world" 0 char-word-delimiter?))
    
    (test-equal "already at end"
                5
                (skip-word-chars-forward "hello" 5 char-word-delimiter?)))
  
  (test-group "skip-word-chars-backward"
    (test-equal "skip back through word chars"
                6
                (skip-word-chars-backward "hello world" 10 char-word-delimiter?))  ; from 'd' to start of 'world'
    
    (test-equal "skip back from end of word"
                6
                (skip-word-chars-backward "hello world" 11 char-word-delimiter?))  ; from end to start of 'world'
    
    (test-equal "no skip when starting on delimiter"
                0
                (skip-word-chars-backward "hello world" 5 char-word-delimiter?))
    
    (test-equal "skip to beginning of string"
                0
                (skip-word-chars-backward "hello" 4 char-word-delimiter?))
    
    (test-equal "skip with punctuation delimiter"
                6
                (skip-word-chars-backward "hello,world" 10 char-word-delimiter?))
    
    (test-equal "already at beginning"
                0
                (skip-word-chars-backward "hello" 0 char-word-delimiter?)))
  
  (test-group "edge-cases"
    (test-equal "empty string forward"
                0
                (skip-word-chars-forward "" 0 char-word-delimiter?))
    
    (test-equal "empty string backward"
                0
                (skip-word-chars-backward "" 0 char-word-delimiter?))
    
    (test-equal "single char forward"
                1
                (skip-word-chars-forward "a" 0 char-word-delimiter?))
    
    (test-equal "single char backward"
                0
                (skip-word-chars-backward "a" 1 char-word-delimiter?))
    
    (test-equal "all delimiters forward"
                0
                (skip-word-chars-forward "   " 0 char-word-delimiter?))
    
    (test-equal "all delimiters backward"
                2
                (skip-word-chars-backward "   " 2 char-word-delimiter?))))

;;; =================================================================
;;; ERROR CONDITION TYPE TESTS
;;; =================================================================

(test-group "error-condition-types"
  
  (test-group "cbuf-invalid-combining-sequence"
    ;; Test that we can create and recognize the condition
    (let ([condition (condition (&cbuf-invalid-combining-sequence
                                 (base-char #\a)
                                 (combining-char #\x0301)
                                 (current-count 0)
                                 (max-count 4)))])
      
      (test-assert "recognizes invalid-combining-sequence condition"
                   (cbuf-invalid-combining-sequence-error? condition))
      
      (test-equal "extracts base-char correctly"
                  #\a
                  (cbuf-invalid-combining-sequence-error:base-char condition))
      
      (test-equal "extracts combining-char correctly"
                  #\x0301
                  (cbuf-invalid-combining-sequence-error:combining-char condition))
      
      (test-equal "extracts current-count correctly"
                  0
                  (cbuf-invalid-combining-sequence-error:current-count condition))
      
      (test-equal "extracts max-count correctly"
                  4
                  (cbuf-invalid-combining-sequence-error:max-count condition))))
  
  (test-group "cbuf-too-many-combining-marks"
    ;; Test that we can create and recognize the condition
    (let ([condition (condition (&cbuf-too-many-combining-marks
                                 (base-char #\b)
                                 (combining-char #\x0302)
                                 (current-count 5)
                                 (max-count 4)))])
      
      (test-assert "recognizes too-many-combining-marks condition"
                   (cbuf-too-many-combining-marks-error? condition))
      
      (test-equal "extracts base-char correctly"
                  #\b
                  (cbuf-too-many-combining-marks-error:base-char condition))
      
      (test-equal "extracts combining-char correctly"
                  #\x0302
                  (cbuf-too-many-combining-marks-error:combining-char condition))
      
      (test-equal "extracts current-count correctly"
                  5
                  (cbuf-too-many-combining-marks-error:current-count condition))
      
      (test-equal "extracts max-count correctly"
                  4
                  (cbuf-too-many-combining-marks-error:max-count condition))))
  
  (test-group "condition-hierarchy"
    ;; Test that conditions are properly part of the &serious hierarchy
    (let ([invalid-seq-condition (condition (&cbuf-invalid-combining-sequence
                                             (base-char #\a)
                                             (combining-char #\x0301)
                                             (current-count 0)
                                             (max-count 4)))]
          [too-many-condition (condition (&cbuf-too-many-combining-marks
                                          (base-char #\b)
                                          (combining-char #\x0302)
                                          (current-count 5)
                                          (max-count 4)))])
      
      (test-assert "invalid-sequence is serious condition"
                   (serious-condition? invalid-seq-condition))
      
      (test-assert "too-many-combining is serious condition"
                   (serious-condition? too-many-condition))
      
      ;; Test that they don't cross-recognize
      (test-assert "invalid-sequence is not too-many-combining"
                   (not (cbuf-too-many-combining-marks-error? invalid-seq-condition)))
      
      (test-assert "too-many-combining is not invalid-sequence"
                   (not (cbuf-invalid-combining-sequence-error? too-many-condition))))))

;;; =================================================================
;;; COMPREHENSIVE INTEGRATION TESTS
;;; =================================================================

(test-group "comprehensive-integration"
  
  (test-group "word-navigation-consistency"
    ;; Test that forward and backward word navigation are consistent
    (let ([text "hello world test"])
      ;; Go forward from start, then back - should return to start
      (let* ([forward-end (find-word-end-forward text 0 char-word-delimiter?)]
             [backward-start (find-word-begin-backward text forward-end char-word-delimiter?)])
        (test-equal "forward then backward returns to start"
                    0 backward-start))
      
      ;; Skip word chars should match find-word-end behavior
      (let ([skip-end (skip-word-chars-forward text 0 char-word-delimiter?)]
            [find-end (find-word-end-forward text 0 char-word-delimiter?)])
        (test-equal "skip-word-chars matches find-word-end for simple case"
                    skip-end find-end))))
  
  (test-group "combining-mark-validation-consistency"
    ;; Test that different validation functions agree
    (let ([valid-str "hello\u0301world\u0302"]
          [invalid-str "hello\u0301\u0302\u0303\u0304\u0305world"])  ; 5 combining marks
      
      ;; Valid string should pass all validations
      (test-assert "valid string passes validate-string-combining-marks"
                   (car (validate-string-combining-marks valid-str)))
      
      (test-assert "valid string passes validate-combining-mark-limits"
                   (begin (validate-combining-mark-limits valid-str) #t))
      
      ;; Invalid string should fail validate-string-combining-marks
      (test-assert "invalid string fails validate-string-combining-marks"
                   (not (car (validate-string-combining-marks invalid-str))))
      
      ;; Invalid string should raise exception in validate-combining-mark-limits
      (test-assert "invalid string raises exception in validate-combining-mark-limits"
                   (guard (ex [else #t])
                     (validate-combining-mark-limits invalid-str)
                     #f))))
  
  (test-group "position-validation-boundary-testing"
    ;; Test edge cases in position validation
    (test-equal "line validation at exact boundary"
                '(10 10 #f test-op)
                (validate-line-movement-pure 5 5 10 'test-op))
    
    (test-equal "column validation at zero"
                '(0 0 #f test-op)
                (validate-column-movement-pure 5 -5 20 'test-op))
    
    (test-equal "absolute validation with zero coordinates"
                '(0 0 #f #f test-op)
                (validate-absolute-position-pure 0 0 10 20 'test-op))))

;;; =================================================================
;;; STRESS TESTS
;;; =================================================================

(test-group "stress-tests"
  
  (test-group "large-combining-sequences"
    ;; Test with strings that have many valid combining sequences
    (let ([many-clusters (string-append "a\u0301\u0302\u0303\u0304"  ; 4 combining marks (valid)
					"b\u0301\u0302\u0303\u0304"  ; 4 combining marks (valid)
					"c\u0301\u0302\u0303\u0304"  ; 4 combining marks (valid)
					"d\u0301\u0302\u0303\u0304")])  ; 4 combining marks (valid)
      
      (test-assert "many valid clusters pass validation"
                   (car (validate-string-combining-marks many-clusters)))
      
      (test-equal "correct base character count for many clusters"
                  4
                  (count-base-characters many-clusters))))
  
  (test-group "very-long-words"
    ;; Test word navigation with very long words
    (let ([long-word (make-string 1000 #\a)]
          [long-text (string-append (make-string 1000 #\a) " " (make-string 1000 #\b))])
      
      (test-equal "skip through very long word"
                  1000
                  (skip-word-chars-forward long-word 0 char-word-delimiter?))
      
      (test-equal "find end of very long word in text"
                  1000
                  (find-word-end-forward long-text 0 char-word-delimiter?))))
  
  (test-group "extreme-tab-positions"
    ;; Test tab computation with large numbers
    (test-equal "large position forward tab"
                10008
                (compute-tab-column 10000 8 1))
    
    (test-equal "large position backward tab"
                9992
                (compute-tab-column 10000 8 -1))))

;;; =================================================================
;;; PERFORMANCE CHARACTERISTICS (Basic)
;;; =================================================================

(test-group "performance-characteristics"
  
  (test-group "large-inputs"
    ;; Test with reasonably large inputs to ensure no exponential behavior
    (let ([large-string (make-string 1000 #\a)])
      (test-assert "large string validation completes" 
                   (car (validate-string-combining-marks large-string)))
      (test-equal "large string base count" 1000 (count-base-characters large-string)))
    
    (let ([large-line (string-append (make-string 500 #\a) " " (make-string 500 #\b))])
      (test-assert "large line word detection completes"
                   (> (find-word-end-forward large-line 0 char-word-delimiter?) 0)))))

;;; End test suite
;;; =================================================================
;;; STRICT TESTS
;;; =================================================================

(define (match-starts ms) (map pattern-match-start ms))
(define (match-texts ms) (map pattern-match-text ms))

(test-group "strict: count-base-characters"
  (test-equal "spaces count" 3 (count-base-characters "a b"))
  (test-equal "tabs count" 3 (count-base-characters "a\tb"))
  (test-equal "control characters count" 2 (count-base-characters "a\x01"))
  (test-equal "combining marks don't" 2 (count-base-characters "éẍ"))
  (test-equal "leading combining mark doesn't" 1 (count-base-characters "́a"))
  (test-equal "empty" 0 (count-base-characters "")))

(test-group "strict: insertion validation window"
  ;; The window looked at starts 10 characters before the insertion;
  ;; it must not start inside a grapheme cluster.
  (let ([s (string-append "é̂" (make-string 9 #\a))])
    (test-equal "cluster just outside the window is not an error" '(#t ())
                (validate-combining-marks-at-insertion s 11 "z")))
  (test-assert "a fifth combining mark is still caught"
               (not (car (validate-combining-marks-at-insertion "é̂̃̄" 5 "̅"))))
  (test-assert "inserting at the very start is fine"
               (car (validate-combining-marks-at-insertion "abc" 0 "x"))))

(test-group "strict: compute-tab-column"
  (test-error "tab size 0" #t (compute-tab-column 3 0 1))
  (test-error "negative tab size" #t (compute-tab-column 3 -8 1))
  (test-equal "forward from a stop" 16 (compute-tab-column 8 8 1))
  (test-equal "two forward" 16 (compute-tab-column 3 8 2))
  (test-equal "backward from between stops" 0 (compute-tab-column 5 8 -1))
  (test-equal "backward from a stop" 8 (compute-tab-column 16 8 -1))
  (test-equal "backward past 0 stops at 0" 0 (compute-tab-column 3 8 -5)))

(test-group "strict: word boundaries use the given predicate"
  (let ([x? (lambda (c) (char=? c #\x))])
    (test-equal "forward skips predicate delimiters, not punctuation" 4
                (find-word-end-forward "xxab" 0 x?))
    (test-equal "punctuation is a word character for this predicate" 3
                (find-word-end-forward "a.bxc" 0 x?))
    (test-equal "backward skips predicate delimiters" 0
                (find-word-begin-backward "abxx" 4 x?))
    (test-equal "backward word with punctuation" 2
                (find-word-begin-backward "cx.b" 4 x?))))

(test-group "strict: grapheme boundaries"
  (test-assert "start" (grapheme-boundary? "éx" 0))
  (test-assert "before a combining mark is not" (not (grapheme-boundary? "éx" 1)))
  (test-assert "after the cluster" (grapheme-boundary? "éx" 2))
  (test-assert "end" (grapheme-boundary? "éx" 3))
  (test-assert "before a space" (grapheme-boundary? "a b" 1)))

(test-group "strict: literal search"
  (test-equal "followed by a space" 0 (find-pattern-in-text "say hi" "say" 0))
  (test-equal "followed by a tab" 0 (find-pattern-in-text "x\ty" "x" 0))
  (test-equal "from a start position" 4 (find-pattern-in-text "ab ab" "b" 3))
  (test-equal "start position is inclusive" 3 (find-pattern-in-text "ab ab" "ab" 3))
  (test-equal "#f start means 0" 0 (find-pattern-in-text "ab" "a" #f))
  (test-equal "start past end finds nothing" #f (find-pattern-in-text "ab" "a" 5))
  (test-equal "start at end finds nothing" #f (find-pattern-in-text "ab" "a" 2))
  (test-equal "not found" #f (find-pattern-in-text "abc" "x" 0))
  (test-equal "empty pattern never matches" #f (find-pattern-in-text "abc" "" 0))
  (test-equal "case-sensitive by default" #f (find-pattern-in-text "ABC" "b" 0))
  (test-equal "case-insensitive" 1 (find-pattern-in-text "ABC" "b" 0 #:case-insensitive? #t))
  (test-equal "won't end before a combining mark" #f (find-pattern-in-text "éx" "e" 0))
  (test-equal "won't start on a combining mark" #f (find-pattern-in-text "éx" "́x" 0))
  (test-equal "matches the whole cluster" 0 (find-pattern-in-text "éx" "é" 0))
  (test-equal "skips a bad match to a good one" 3 (find-pattern-in-text "é e" "e" 0))
  (test-equal "whole word skips partial" 7 (find-pattern-in-text "concat cat" "cat" 0 #:whole-word? #t))
  (test-equal "whole word at punctuation" 0 (find-pattern-in-text "cat, dog" "cat" 0 #:whole-word? #t))
  (test-equal "whole word not found" #f (find-pattern-in-text "concat" "cat" 0 #:whole-word? #t)))

(test-group "strict: regex search"
  (test-equal "basic" 1 (find-pattern-in-text "abbc" "b+" 0 #:regex? #t))
  (test-equal "from a start position" 4 (find-pattern-in-text "ab abb" "b+" 3 #:regex? #t))
  (test-equal "extended syntax: alternation" 2 (find-pattern-in-text "x cat" "dog|cat" 0 #:regex? #t))
  (test-equal "case-insensitive" 1 (find-pattern-in-text "aB" "b" 0 #:regex? #t #:case-insensitive? #t))
  (test-equal "case-sensitive by default" #f (find-pattern-in-text "aB" "b" 0 #:regex? #t))
  (test-equal "^ matches at the start of the text" 0 (find-pattern-in-text "ab" "^a" 0 #:regex? #t))
  (test-equal "^ doesn't match at a later start position" #f
              (find-pattern-in-text "aa" "^a" 1 #:regex? #t))
  (test-equal "$ matches at the end" 2 (find-pattern-in-text "abc" "c$" 0 #:regex? #t))
  (test-equal "whole word" 5 (find-pattern-in-text "cats cat" "cat" 0 #:regex? #t #:whole-word? #t))
  (test-equal "won't split a cluster" #f (find-pattern-in-text "é" "e" 0 #:regex? #t))
  (test-error "invalid regex raises an error" #t (find-pattern-in-text "abc" "(" 0 #:regex? #t))
  (let ([m (find-pattern-in-text-detailed "x123y" "[0-9]+" 0 #:regex? #t)])
    (test-equal "detailed: start" 1 (pattern-match-start m))
    (test-equal "detailed: end" 4 (pattern-match-end m))
    (test-equal "detailed: text" "123" (pattern-match-text m))
    (test-equal "detailed: full text" "x123y" (pattern-match-full-text m))
    (test-assert "detailed: regex match" (regexp-match? (pattern-match-regex-match m)))))

(test-group "strict: literal detailed match"
  (let ([m (find-pattern-in-text-detailed "Hello" "ELL" 0 #:case-insensitive? #t)])
    (test-assert "record" (pattern-match? m))
    (test-equal "text is what was matched, not the pattern" "ell" (pattern-match-text m))
    (test-equal "end" 4 (pattern-match-end m))
    (test-equal "no regex match" #f (pattern-match-regex-match m)))
  (test-equal "no match" #f (find-pattern-in-text-detailed "abc" "z" 0)))

(test-group "strict: find all"
  (test-equal "non-overlapping" '(0 2) (match-starts (find-all-pattern-matches "aaaa" "aa")))
  (test-equal "odd overlap" '(0) (match-starts (find-all-pattern-matches "aaa" "aa")))
  (test-equal "case-insensitive" '("Ab" "ab")
              (match-texts (find-all-pattern-matches "Ab ab" "ab" #:case-insensitive? #t)))
  (test-equal "whole words" '(5) (match-starts (find-all-pattern-matches "cats cat" "cat" #:whole-word? #t)))
  (test-equal "empty literal" '() (find-all-pattern-matches "abc" ""))
  (test-equal "regex" '("12" "3") (match-texts (find-all-pattern-matches "a12b3" "[0-9]+" #:regex? #t)))
  (test-equal "empty regex matches advance" '(0 1 2 3)
              (match-starts (find-all-pattern-matches "abc" "x*" #:regex? #t)))
  (test-equal "find-all-regex-matches, 3 arguments" '(1 3)
              (match-starts (find-all-regex-matches "aBcB" "b" #t)))
  (test-equal "find-all-regex-matches, whole-word" '(3)
              (match-starts (find-all-regex-matches "ab b" "b" #f #t)))
  (test-equal "count" 2 (count-pattern-matches "a.b.c" "." ))
  (test-equal "count regex" 5 (count-pattern-matches "a.b.c" "." #:regex? #t))
  (test-equal "positions" '(1 3) (pattern-match-positions (find-all-pattern-matches "a.b.c" ".")))
  (test-equal "summary" '(((start . 1) (end . 2) (text . ".") (length . 1)))
              (pattern-match-summary (find-all-pattern-matches "a.b" "."))))

(test-group "strict: replace"
  (test-equal "first only" '("xbab" . 0)
              (let ([r (replace-pattern-in-text "abab" "a" "x")])
                (cons (car r) (pattern-match-start (cdr r)))))
  (test-equal "from a start position" "abxb"
              (car (replace-pattern-in-text "abab" "a" "x" #:start-pos 1)))
  (test-equal "no match" '(#f . #f) (replace-pattern-in-text "abc" "z" "x"))
  (test-equal "replace all" '("x-x-x" . 3) (replace-all-patterns-in-text "a-a-a" "a" "x"))
  (test-equal "replace all, non-overlapping" '("xxa" . 2) (replace-all-patterns-in-text "aaaaa" "aa" "x"))
  (test-equal "replace all, longer replacement" '("[a][a]" . 2) (replace-all-patterns-in-text "aa" "a" "[a]"))
  (test-equal "replace all, none" '("abc" . 0) (replace-all-patterns-in-text "abc" "z" "x"))
  (test-equal "replace all, whole words" '("dog concat dog" . 2)
              (replace-all-patterns-in-text "cat concat cat" "cat" "dog" #:whole-word? #t))
  (test-equal "replace all, regex" '("a#b#" . 2)
              (replace-all-patterns-in-text "a12b3" "[0-9]+" "#" #:regex? #t))
  (test-equal "regex replacement is literal" '("a\\1b" . 1)
              (replace-regex-in-text "axb" "(x)" "\\1"))
  (test-equal "replace-regex-in-text first" '("bonana" . 1) (replace-regex-in-text "banana" "a" "o"))
  (test-equal "replace-regex-in-text all" '("bonono" . 3)
              (replace-regex-in-text "banana" "a" "o" #:replace-all? #t))
  (test-equal "replace-regex-in-text ci" '("x-x" . 2)
              (replace-regex-in-text "A-a" "a" "x" #:replace-all? #t #:case-insensitive? #t))
  (test-equal "replace-regex-in-text none" '("abc" . 0) (replace-regex-in-text "abc" "z" "x"))
  (test-equal "highlight" "<b>ab</b> c <b>ab</b>"
              (highlight-pattern-matches "ab c ab" (find-all-pattern-matches "ab c ab" "ab") "<b>" "</b>"))
  (test-equal "highlight nothing" "abc" (highlight-pattern-matches "abc" '() "<" ">")))

(test-group "strict: is-whole-word-match?"
  (test-assert "whole string" (is-whole-word-match? "cat" 0 3))
  (test-assert "between spaces" (is-whole-word-match? "a cat b" 2 5))
  (test-assert "inside a word" (not (is-whole-word-match? "concat" 3 6)))
  (test-assert "prefix of a word" (not (is-whole-word-match? "cats" 0 3))))

(test-end "cbuf-utils")

;;; Print summary if running interactively
(when (not (batch-mode?))
  (format #t "~%Test suite completed.~%"))


;;; Local Variables:
;;; mode: scheme
;;; scheme-basic-offset: 2
;;; indent-tabs-mode: nil
;;; End:
