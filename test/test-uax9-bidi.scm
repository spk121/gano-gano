;;; -*- mode: scheme; coding: utf-8; -*-

;;;; Copyright (C) 1996-2025 Michael L. Gran
;;;; License GPL 3+

;;; Test suite for Gano UAX #9 Bidirectional Algorithm Module
;;; Using SRFI-64 testing framework

(use-modules (srfi srfi-64)        ; Testing framework
	     (srfi srfi-1)         ; List utilities
	     (srfi srfi-11)	   ; let-values
             (gano uax9-bidi)      ; Module under test
             (gano char))          ; For bidi class constants

;;; Test suite setup
(test-begin "gano-uax9-bidi")

;;; =================================================================
;;; RTL TEXT FRAGMENTS FOR TESTING
;;; =================================================================

;; Hebrew text fragments
(define hebrew-hello "שלום")           ; Hebrew "hello"
(define hebrew-alef "א")               ; Hebrew letter Alef
(define hebrew-world "עולם")           ; Hebrew "world"
(define hebrew-text "עברית")           ; Hebrew "Hebrew"

;; Arabic text fragments  
(define arabic-hello "مرحبا")          ; Arabic "hello"
(define arabic-text "عربي")           ; Arabic "Arabic"
(define arabic-alef "ا")              ; Arabic letter Alef

;; Combined test strings
(define mixed-hello-world (string-append "Hello " hebrew-hello))
(define mixed-hello-world-rtl-first (string-append hebrew-hello " Hello"))
(define mixed-numbers-hebrew (string-append "123 " hebrew-hello))
(define mixed-punct-arabic (string-append "!!! " arabic-hello))
(define mixed-english-hebrew-world (string-append "Hello " hebrew-hello " world"))
(define mixed-rtl-brackets (string-append hebrew-hello " (test) " hebrew-text))
(define mixed-english-arabic (string-append "English " hebrew-hello " (test) " arabic-text))
(define mixed-arabic-digits "العدد123")  ; Note: keeping this as one string since it's a common test pattern

;;; =================================================================
;;; BIDI STATE RECORD TESTS
;;; =================================================================

(test-group "bidi-state-record"
  (test-assert "make-bidi-state creates valid record"
    (let ([state (make-bidi-state 2 BC-L BC-LRI)])
      (and (bidi-state? state)
           (= (bidi-state-embedding-level state) 2)
           (eq? (bidi-state-override-status state) BC-L)
           (eq? (bidi-state-isolate-status state) BC-LRI))))
  
  (test-assert "default bidi state"
    (let ([state (make-bidi-state 0 'neutral 'none)])
      (and (= (bidi-state-embedding-level state) 0)
           (eq? (bidi-state-override-status state) 'neutral)
           (eq? (bidi-state-isolate-status state) 'none))))
  
  (test-assert "high embedding level"
    (let ([state (make-bidi-state 125 BC-R BC-RLI)])
      (and (= (bidi-state-embedding-level state) 125)
           (eq? (bidi-state-override-status state) BC-R)
           (eq? (bidi-state-isolate-status state) BC-RLI)))))

;;; =================================================================
;;; PARAGRAPH BASE DIRECTION TESTS
;;; =================================================================

(test-group "paragraph-base-direction"
  ;; Test LTR detection
  (test-equal "ASCII text is LTR"
	      'ltr (paragraph-base-direction "Hello World"))
  
  (test-equal "text starting with ASCII letter is LTR"
	      'ltr (paragraph-base-direction "English text with numbers 123"))
  
  (test-equal "empty string defaults to LTR"
	      'ltr (paragraph-base-direction ""))
  
  (test-equal "only numbers defaults to LTR"
	      'ltr (paragraph-base-direction "12345"))
  
  (test-equal "only punctuation defaults to LTR"
	      'ltr (paragraph-base-direction "!@#$%"))
  
  ;; Test RTL detection
  (test-equal "Hebrew text is RTL"
	      'rtl (paragraph-base-direction hebrew-hello))
  
  (test-equal "Arabic text is RTL"
	      'rtl (paragraph-base-direction arabic-hello))
  
  (test-equal "text starting with Hebrew is RTL"
	      'rtl (paragraph-base-direction mixed-hello-world-rtl-first))
  
  (test-equal "text starting with Arabic is RTL"
	      'rtl (paragraph-base-direction (string-append arabic-hello " world")))
  
  ;; Test mixed content - first strong character wins
  (test-equal "English first, then Hebrew is LTR"
	      'ltr (paragraph-base-direction (string-append "Hello " hebrew-hello)))
  
  (test-equal "numbers then Hebrew is RTL"
	      'rtl (paragraph-base-direction mixed-numbers-hebrew))
  
  (test-equal "punctuation then Arabic is RTL"
	      'rtl (paragraph-base-direction mixed-punct-arabic)))

;;; =================================================================
;;; EXPLICIT LEVEL RESOLUTION TESTS
;;; =================================================================

(test-group "resolve-explicit-levels"
  ;; Test basic ASCII text
  (test-assert "ASCII text has base level 0"
    (let ([levels (resolve-explicit-levels "Hello" 0)])
      (every (lambda (level-info) (= (car level-info) 0)) levels)))
  
  (test-assert "RTL base level 1"
    (let ([levels (resolve-explicit-levels "Hello" 1)])
      (every (lambda (level-info) (= (car level-info) 1)) levels)))
  
  ;; Test embedding controls
  (test-assert "LRE increases embedding level"
    (let* ([text (string #\a (integer->char #x202A) #\b)]  ; a LRE b
           [levels (resolve-explicit-levels text 0)])
      (pk 'foo 'text text 'levels levels)
      (and (= (length levels) 3)
           (= (car (first levels)) 0)    ; 'a' at level 0
           (= (car (second levels)) 0)   ; LRE marked as BN at level 0
           (= (car (third levels)) 2))))  ; 'b' at level 2
  
  (test-assert "RLE increases embedding level to odd"
    (let* ([text (string #\a (integer->char #x202B) #\b)]  ; a RLE b
           [levels (resolve-explicit-levels text 0)])
      (and (= (car (first levels)) 0)    ; 'a' at level 0
           (= (car (third levels)) 1))))  ; 'b' at level 1
  
  ;; Test PDF restoration
  (test-assert "PDF restores previous level"
    (let* ([text (pk 'alpha (string #\a (integer->char #x202A) #\b (integer->char #x202C) #\c))]  ; a LRE b PDF c
           [levels (pk 'bravo (resolve-explicit-levels text 0))])
      (pk 'bar 'text text 'levels levels)
      (and (= (car (first levels)) 0)     ; 'a' at level 0
           (= (car (third levels)) 2)     ; 'b' at level 2
           (= (car (fifth levels)) 0))))  ; 'c' back to level 0
  
  ;; Test isolate controls
  (test-assert "LRI creates isolate context"
    (let* ([text (string #\a (integer->char #x2066) #\b (integer->char #x2069) #\c)]  ; a LRI b PDI c
           [levels (resolve-explicit-levels text 0)])
      (pk 'hotel 'text text 'levels levels)
      (and (= (car (first levels)) 0)     ; 'a' at level 0
           (= (car (third levels)) 2)     ; 'b' at level 2
           (= (car (fifth levels)) 0)))))  ; 'c' back to level 0

;;; =================================================================
;;; WEAK TYPE RESOLUTION TESTS
;;; =================================================================

(test-group "resolve-weak-types"
  ;; Test NSM resolution (W1)
  (test-assert "NSM takes type of preceding character"
    (let* ([text (string #\a (integer->char #x0301))]  ; a + combining acute
           [levels '((0 . neutral) (0 . neutral))]
           [types (resolve-weak-types text levels 0)])
      ;; Both characters should have same type after W1
      (equal? (first types) (second types))))
  
  ;; Test EN after AL becomes AN (W2)
  (test-assert "EN after AL becomes AN"
    (let* ([text mixed-arabic-digits]  ; Arabic text with digits
           [levels (map (lambda (i) (cons 1 'neutral)) (iota (string-length text)))]
           [types (resolve-weak-types text levels 1)])
      ;; The digits after Arabic should become AN
      (member BC-AN types))))

;;; =================================================================
;;; BRACKET PAIR DETECTION TESTS
;;; =================================================================

(test-group "bracket-pair-detection"
  ;; Test basic bracket type detection
  (test-equal "opening parenthesis detected"
	      'open (get-bracket-type #\())
  
  (test-equal "closing parenthesis detected"
	      'close (get-bracket-type #\)))
  
  (test-equal "regular character not a bracket"
	      #f (get-bracket-type #\a))
  
  ;; Test simple bracket pair finding
  (test-assert "find simple parentheses pair"
    (let* ([text "a(b)c"]
           [types (map (lambda (c) (char-get-bidi-class c)) (string->list text))]
           [levels '(0 0 0 0 0)]
           [pairs (find-bracket-pairs text types levels)])
      (and (= (length pairs) 1)
           (let ([pair (first pairs)])
             (and (= (bracket-pair-open-pos pair) 1)
                  (= (bracket-pair-close-pos pair) 3)
                  (char=? (bracket-pair-open-char pair) #\()
                  (char=? (bracket-pair-close-char pair) #\)))))))
  
  (test-assert "find nested bracket pairs"
    (let* ([text "a(b[c]d)e"]
           [types (map (lambda (c) (char-get-bidi-class c)) (string->list text))]
           [levels '(0 0 0 0 0 0 0 0 0)]
           [pairs (find-bracket-pairs text types levels)])
      (= (length pairs) 2)))  ; Should find both () and [] pairs
  
  (test-assert "unmatched opening bracket"
    (let* ([text "a(b"]
           [types (map (lambda (c) (char-get-bidi-class c)) (string->list text))]
           [levels '(0 0 0)]
           [pairs (find-bracket-pairs text types levels)])
      (= (length pairs) 0)))  ; No complete pairs
  
  (test-assert "unmatched closing bracket"
    (let* ([text "a)b"]
           [types (map (lambda (c) (char-get-bidi-class c)) (string->list text))]
           [levels '(0 0 0)]
           [pairs (find-bracket-pairs text types levels)])
      (= (length pairs) 0)))  ; No complete pairs
  
  (test-assert "mismatched bracket types"
    (let* ([text "a(b]c"]
           [types (map (lambda (c) (char-get-bidi-class c)) (string->list text))]
           [levels '(0 0 0 0 0)]
           [pairs (find-bracket-pairs text types levels)])
      (= (length pairs) 0))))  ; No matching pairs

;;; =================================================================
;;; MAIN ALGORITHM TESTS
;;; =================================================================

(test-group "resolve-paragraph-bidi"
  ;; Test empty string
  (test-equal "empty string returns empty list"
	      '() (resolve-paragraph-bidi ""))
  
  ;; Test simple LTR text
  (test-assert "simple LTR text has level 0"
    (let ([levels (resolve-paragraph-bidi "Hello")])
      (and (= (length levels) 5)
           (every (lambda (level) (= level 0)) levels))))
  
  ;; Test simple RTL text
  (test-assert "simple RTL text has level 1"
    (let ([levels (resolve-paragraph-bidi hebrew-hello)])
      (and (= (length levels) 4)
           (every (lambda (level) (= level 1)) levels))))
  
  ;; Test mixed LTR/RTL
  (test-assert "mixed text has varying levels"
    (let ([levels (resolve-paragraph-bidi mixed-english-hebrew-world)])
      (and (> (length levels) 0)
           (not (every (lambda (level) (= level 0)) levels)))))
  
  ;; Test with numbers
  (test-assert "text with numbers resolves correctly"
    (let ([levels (resolve-paragraph-bidi "Hello 123 world")])
      (and (= (length levels) 15)
           (every (lambda (level) (>= level 0)) levels))))
  
  ;; Test with brackets
  (test-assert "text with brackets resolves correctly"
    (let ([levels (resolve-paragraph-bidi "Hello (world) test")])
      (and (= (length levels) 18)
           (every (lambda (level) (>= level 0)) levels)))))

;;; =================================================================
;;; BIDI STATE TRACKING TESTS
;;; =================================================================

(test-group "get-bidi-state-at-position"
  ;; Test basic positions
  (test-assert "state at beginning of text"
    (let ([state (get-bidi-state-at-position "Hello" 0)])
      (and (= (bidi-state-embedding-level state) 0)
           (eq? (bidi-state-override-status state) 'neutral)
           (eq? (bidi-state-isolate-status state) 'none))))
  
  (test-assert "state at end of text"
    (let ([state (get-bidi-state-at-position "Hello" 5)])
      (and (= (bidi-state-embedding-level state) 0)
           (eq? (bidi-state-override-status state) 'neutral)
           (eq? (bidi-state-isolate-status state) 'none))))
  
  (test-assert "state beyond text length"
    (let ([state (get-bidi-state-at-position "Hello" 10)])
      (and (= (bidi-state-embedding-level state) 0)
           (eq? (bidi-state-override-status state) 'neutral)
           (eq? (bidi-state-isolate-status state) 'none))))
  
  (test-assert "state before text start"
    (let ([state (get-bidi-state-at-position "Hello" -1)])
      (and (= (bidi-state-embedding-level state) 0)
           (eq? (bidi-state-override-status state) 'neutral)
           (eq? (bidi-state-isolate-status state) 'none))))
  
  ;; Test with embedding controls
  (test-assert "state after LRE"
    (let* ([text (string #\a (integer->char #x202A) #\b)]  ; a LRE b
           [state (get-bidi-state-at-position text 2)])
      (> (bidi-state-embedding-level state) 0)))
  
  ;; Test with isolate controls
  (test-assert "state after LRI"
    (let* ([text (string #\a (integer->char #x2066) #\b)]  ; a LRI b
           [state (get-bidi-state-at-position text 2)])
      (and (> (bidi-state-embedding-level state) 0)
           (eq? (bidi-state-isolate-status state) 'BC-LRI)))))

;;; =================================================================
;;; LINE SPLITTING TESTS
;;; =================================================================

(test-group "split-line-with-bidi-controls"
  ;; Test basic splitting
  (test-assert "split simple text"
    (let-values ([(first second) (split-line-with-bidi-controls "Hello World" 6)])
      (and (string=? first "Hello ")
           (string=? second "World"))))
  
  (test-assert "split at beginning"
    (let-values ([(first second) (split-line-with-bidi-controls "Hello" 0)])
      (and (string=? first "")
           (string=? second "Hello"))))
  
  (test-assert "split at end"
    (let-values ([(first second) (split-line-with-bidi-controls "Hello" 5)])
      (and (string=? first "Hello")
           (string=? second ""))))
  
  (test-assert "split beyond end"
    (let-values ([(first second) (split-line-with-bidi-controls "Hello" 10)])
      (and (string=? first "Hello")
           (string=? second ""))))
  
  ;; Test splitting with bidi controls
  (test-assert "split preserves bidi state"
    (let ([text (string #\a (integer->char #x202A) #\b #\c)])  ; a LRE b c
      ;; Should add controls to maintain state
      (call-with-values
          (lambda () (split-line-with-bidi-controls text 3))
        (lambda (str1 str2)
          (pk 'split-bidi 'str1 str1 'str2 str2)
          (and (= (string-length str1) 4)       ; Add pop: a LRE b PDF
               (= (string-length str2) 2))))))) ; Add push: LRE c

;;; =================================================================
;;; BRACKET CONTEXT TESTS
;;; =================================================================

(test-group "bracket-context"
  ;; Test bracket context creation
  (test-assert "make empty bracket context"
    (let ([context (make-bracket-context '() '() '())])
      (and (bracket-context? context)
           (null? (bracket-context-open-brackets context))
           (null? (bracket-context-line-pairs context))
           (null? (bracket-context-unclosed-brackets context)))))
  
  ;; Test open bracket record
  (test-assert "make open bracket record"
    (let ([bracket (make-open-bracket #\( 0 5 10 100)])
      (and (open-bracket? bracket)
           (char=? (open-bracket-char bracket) #\()
           (= (open-bracket-level bracket) 0)
           (= (open-bracket-line-number bracket) 5)
           (= (open-bracket-line-position bracket) 10)
           (= (open-bracket-global-position bracket) 100))))
  
  ;; Test multi-line bracket pair
  (test-assert "make multi-line bracket pair"
    (let* ([open-bracket (make-open-bracket #\[ 1 2 5 25)]
           [pair (make-multi-line-bracket-pair open-bracket 15 #\] 1 #t)])
      (and (multi-line-bracket-pair? pair)
           (eq? (multi-line-bracket-pair-open-bracket pair) open-bracket)
           (= (multi-line-bracket-pair-close-position pair) 15)
           (char=? (multi-line-bracket-pair-close-char pair) #\])
           (= (multi-line-bracket-pair-close-level pair) 1)
           (multi-line-bracket-pair-spans-lines? pair)))))

;;; =================================================================
;;; UTILITY FUNCTION TESTS
;;; =================================================================

(test-group "utility-functions"
  ;; Test find-matching-pdi
  (test-assert "find matching PDI"
    (let* ([text (string (integer->char #x2066) #\a (integer->char #x2069))]  ; LRI a PDI
           [result (find-matching-pdi text 0)])
      (= result 2)))
  
  (test-assert "no matching PDI"
    (let* ([text (string (integer->char #x2066) #\a)]  ; LRI a (no PDI)
           [result (find-matching-pdi text 0)])
      (not result)))
  
  ;; Test bracket matching utilities
  (test-assert "find matching bracket position in simple text"
    (let ([pos (find-matching-bracket-position "a(b)c" 1)])
      (= pos 3)))
  
  (test-assert "no matching bracket"
    (let ([pos (find-matching-bracket-position "a(b" 1)])
      (not pos)))
  
  (test-assert "get bracket nesting level"
    (let ([level (get-bracket-nesting-level "a(b(c)d)e" 4)])
      (= level 2)))  ; Position 4 is 'c', nested in two bracket pairs
  
  (test-assert "bracket nesting at start"
    (let ([level (get-bracket-nesting-level "a(b)c" 0)])
      (pk 'bracket-nesting-start 'level level)
      (= level 0)))  ; Position 0 is 'a', not nested
  
  ;; Test bracket validation
  (test-assert "validate correct bracket structure"
    (let ([result (validate-bracket-structure "a(b[c]d)e")])
      (car result)))  ; Should be valid
  
  (test-assert "detect bracket errors"
    (let ([result (validate-bracket-structure "a(b[c)d]e")])
      (pk 'detect-bracket-errors 'result result)
      (not (car result)))))  ; Should be invalid due to mismatch

;;; =================================================================
;;; INTEGRATION TESTS
;;; =================================================================

(test-group "integration-tests"
  ;; Test complete bidi processing pipeline
  (test-assert "complete pipeline for mixed text"
    (let* ([text mixed-english-arabic]
           [levels (resolve-paragraph-bidi text)])
      (and (= (length levels) (string-length text))
           (every (lambda (level) (and (integer? level) (>= level 0))) levels))))
  
  ;; Test bracket processing with bidi
  (test-assert "brackets with RTL text"
    (let* ([text mixed-rtl-brackets]
           [pairs (find-all-bracket-pairs text)])
      (>= (length pairs) 0)))  ; Should not crash, may or may not find pairs
  
  ;; Test state consistency
  (test-assert "bidi state consistency across positions"
    (let* ([text "Hello World"]
           [positions (iota (string-length text))]
           [states (map (lambda (pos) (get-bidi-state-at-position text pos)) positions)])
      (every bidi-state? states)))
  
  ;; Test line splitting consistency
  (test-assert "line splitting preserves total length"
    (let* ([text "Hello World Test"]
           [split-pos 6])
      (let-values ([(first second) (split-line-with-bidi-controls text split-pos)])
        ;; Total characters should be preserved (plus any added controls)
        (>= (+ (string-length first) (string-length second)) (string-length text))))))

;;; =================================================================
;;; EDGE CASES AND BOUNDARY TESTS
;;; =================================================================

(test-group "edge-cases"
  ;; Test with empty strings
  (test-equal "empty string paragraph direction"
	      'ltr (paragraph-base-direction ""))
  
  (test-equal "empty string bidi resolution"
	      '() (resolve-paragraph-bidi ""))
  
  ;; Test with single characters
  (test-assert "single ASCII character"
    (let ([levels (resolve-paragraph-bidi "A")])
      (and (= (length levels) 1)
           (= (first levels) 0))))
  
  (test-assert "single RTL character"
    (let ([levels (resolve-paragraph-bidi hebrew-alef)])
      (and (= (length levels) 1)
           (= (first levels) 1))))
  
  ;; Test with only neutral characters
  (test-assert "only neutral characters"
    (let ([levels (resolve-paragraph-bidi "123!@#")])
      (every (lambda (level) (>= level 0)) levels)))
  
  ;; Test boundary positions for state tracking
  (test-assert "state at negative position"
    (let ([state (get-bidi-state-at-position "test" -5)])
      (bidi-state? state)))
  
  (test-assert "state far beyond text"
    (let ([state (get-bidi-state-at-position "test" 1000)])
      (bidi-state? state)))
  
  ;; Test very long embedding levels
  (test-assert "handle max embedding levels"
    (let* ([many-lre (make-string 60 (integer->char #x202A))]  ; Many LRE characters
           [levels (resolve-explicit-levels (string-append "a" many-lre "b") 0)])
      (every (lambda (level-info) 
	       (and (integer? (car level-info)) 
                    (<= (car level-info) 125))) levels))))

;;; Test suite cleanup
(test-end "gano-uax9-bidi")

;; Local Variables:
;; eval: (put 'test-group 'scheme-indent-function 1)
;; eval: (put 'test-assert 'scheme-indent-function 1)
;; eval: (put 'let-values 'scheme-indent-function 1)
;; End:
