;;; Using SRFI-64 testing framework

(use-modules (srfi srfi-64)     ; Testing framework
             (gano cbuf-utils)  ; Module under test
             (gano char)        ; For character utilities
             (srfi srfi-1)      ; List utilities
             (srfi srfi-13)     ; String utilities
	     (srfi srfi-35)     ; Condition types
	     (srfi srfi-34))	; Guard

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
                (find-word-begin-backward "hello world" 0 char-word-delimiter?)))
  
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
                4
                (skip-whitespace-backward "hello world" 5))  ; space at 5, skip to 'o' at 4
    
    (test-equal "skip multiple whitespace backward"
                4
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
                4
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
  
  (test-group "error-handling"
    ;; Test that functions properly reject negative indices with errors
    (test-error "find-word-end-forward rejects negative index"
                (find-word-end-forward "hello world" -1 char-word-delimiter?))
    
    (test-error "skip-whitespace-forward rejects negative index"
                (skip-whitespace-forward "hello world" -1))
    
    ;; Test beyond-bounds indices (should not error, but return reasonable values)
    (test-equal "find-word-end beyond bounds"
                11  ; string length
                (find-word-end-forward "hello world" 20 char-word-delimiter?))
    
    (test-equal "skip-whitespace beyond bounds"
                11
                (skip-whitespace-forward "hello world" 20)))
  
  (test-group "negative-inputs"
    (test-equal "negative tab computation" 0 (compute-tab-column 5 8 -1))
    (test-equal "negative position validation clamps" 0 (cadr (validate-line-movement-pure 5 -10 10 'test))))
  )

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
                6
                (skip-word-chars-backward "hello world" 5 char-word-delimiter?))  ; space at 5, move to after space
    
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
                3
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
(test-end "cbuf-utils")

;;; Print summary if running interactively
(when (not (batch-mode?))
  (format #t "~%Test suite completed.~%"))