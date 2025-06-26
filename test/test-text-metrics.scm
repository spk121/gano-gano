#!/usr/bin/env guile
;;; Test suite for text-metrics bidirectional text support
;;; Uses SRFI-64 testing framework

(use-modules (srfi srfi-64)        ; Testing framework
             (gano text-metrics)   ; Module under test
             (gano rendering)      ; For SGR records
             (gano uax9-bidi))     ; For bidi state records

;;; =================================================================
;;; Test Configuration
;;; =================================================================

(test-begin "text-metrics-bidi")

;;; =================================================================
;;; Helper Functions for Testing
;;; =================================================================

(define (make-test-string . chars)
  "Create a test string from character list"
  (list->string chars))

(define (positions-only metrics)
  "Extract just the cell positions from text-metrics for easier testing"
  (text-metrics-cell-positions metrics))

(define (positions-without-final metrics)
  "Get cell positions without the final end-of-string position"
  (let ([positions (text-metrics-cell-positions metrics)])
    (take positions (string-length (text-metrics-string metrics)))))

(define (make-ltr-char)
  "Create a simple LTR character (narrow)"
  #\a)

(define (make-rtl-char) 
  "Create a simple RTL character (narrow Hebrew Alef)"
  #\x05D0)

(define (make-wide-char)
  "Create a wide character (CJK)"
  #\x4E00)

;; Hebrew character constants for readability
(define hebrew-alef #\x05D0)      ; א
(define hebrew-bet #\x05D1)       ; ב  
(define hebrew-gimel #\x05D2)     ; ג
(define hebrew-dalet #\x05D3)     ; ד

;; CJK character constants
(define cjk-one #\x4E00)         ; 一 (Chinese "one")
(define cjk-two #\x4E8C)         ; 二 (Chinese "two") 
(define cjk-three #\x4E09)       ; 三 (Chinese "three")
(define cjk-four #\x56DB)        ; 四 (Chinese "four")
(define cjk-five #\x4E94)        ; 五 (Chinese "five")

;; Combining mark constants
(define combining-acute #\x0301)  ; Combining acute accent
(define zero-width-space #\x200B) ; Zero-width space

;;; =================================================================
;;; Basic Functionality Tests
;;; =================================================================

(test-group "basic-text-metrics-creation"
  (test "empty string"
    '(0)
    (positions-only (compute-text-metrics "" 8)))
  
  (test "single LTR character"
    '(0 1)
    (positions-only (compute-text-metrics "a" 8)))
  
  (test "single wide character"
    '(0 2)
    (positions-only (compute-text-metrics "中" 8 #:cjk? #t))))

;;; =================================================================
;;; Pure LTR Text Tests
;;; =================================================================

(test-group "pure-ltr-text"
  (test "three narrow LTR characters"
    '(0 1 2 3)
    (positions-only (compute-text-metrics "abc" 8)))
  
  (test "mixed narrow and wide LTR"
    '(0 1 3 4)  ; a=0, b=1, 中=3 (width 2), c=4
    (positions-only (compute-text-metrics "ab中c" 8 #:cjk? #t)))
  
  (test "LTR with tab"
    '(0 8 9)    ; a=0, tab->8, b=9
    (positions-only (compute-text-metrics "a\tb" 8))))

;;; =================================================================
;;; Pure RTL Text Tests
;;; =================================================================

(test-group "pure-rtl-text"
  (test "three narrow RTL characters (Hebrew)"
    '(2 1 0 3)  ; RTL: positions go right-to-left, final position is total width
    (positions-only (compute-text-metrics 
                     (string hebrew-alef hebrew-bet hebrew-gimel) 8)))
  
  (test "RTL with different character widths"
    ;; Two Hebrew characters: Alef + Bet
    '(1 0 2)
    (positions-only (compute-text-metrics 
                     (string hebrew-alef hebrew-bet) 8))))

;;; =================================================================
;;; Mixed Bidi Text Tests - The Main Challenge
;;; =================================================================

(test-group "mixed-bidi-text"
  ;; The classic example: 3 LTR narrow + 4 RTL narrow + 5 LTR wide
  ;; Expected: 0, 1, 2, 6, 5, 4, 3, 7, 9, 11, 13, 15
  
  (test "LTR + RTL + LTR example"
    ;; This is the test case from the human's description
    ;; 3 LTR narrow (abc) + 4 RTL narrow + 5 LTR wide
    '(0 1 2 6 5 4 3 7 9 11 13 15 17)
    (positions-only (compute-text-metrics 
                     (string-append "abc"
                                   (string hebrew-alef hebrew-bet hebrew-gimel hebrew-dalet)
                                   (string cjk-one cjk-two cjk-three cjk-four cjk-five))
                     8 #:cjk? #t)))
  
  (test "simple LTR-RTL boundary"
    ;; "ab" + Hebrew Alef+Bet should be: a=0, b=1, Alef=3, Bet=2, final=4  
    '(0 1 3 2 4)
    (positions-only (compute-text-metrics 
                     (string-append "ab" (string hebrew-alef hebrew-bet)) 8)))
  
  (test "RTL in middle of LTR"
    ;; "a" + Hebrew Alef+Bet + "c" should be: a=0, Alef=3, Bet=2, c=4, final=5
    '(0 3 2 4 5)
    (positions-only (compute-text-metrics 
                     (string-append "a" (string hebrew-alef hebrew-bet) "c") 8)))
  
  (test "multiple bidi runs"
    ;; "ab" + Hebrew Alef+Bet + "cd" + Hebrew Gimel+Dalet
    ;; LTR: a=0,b=1  RTL: Alef=3,Bet=2  LTR: c=4,d=5  RTL: Dalet=7,Gimel=6  final=8
    '(0 1 3 2 4 5 7 6 8)
    (positions-only (compute-text-metrics 
                     (string-append "ab" 
                                   (string hebrew-alef hebrew-bet)
                                   "cd"
                                   (string hebrew-gimel hebrew-dalet)) 8))))

;;; =================================================================
;;; Tab Handling in Bidi Context
;;; =================================================================

(test-group "tabs-in-bidi-context"
  (test "tab in LTR context"
    '(0 8 9)  ; a=0, tab->8, b=9
    (positions-only (compute-text-metrics "a\tb" 8)))
  
  (test "tab in RTL context"
    ;; Hebrew Alef + tab + Hebrew Bet in RTL context
    ;; The tab calculation needs to consider the visual layout
    '(1 8 0 9)  ; Complex case - may need adjustment
    (positions-only (compute-text-metrics 
                     (string hebrew-alef #\tab hebrew-bet) 8))))

;;; =================================================================
;;; Combining Marks Tests
;;; =================================================================

(test-group "combining-marks-bidi"
  (test "LTR base with combining mark"
    '(0 0 1)  ; base=0, combining mark=0 (same position), final=1
    (positions-only (compute-text-metrics 
                     (string #\a combining-acute) 8))) ; a + combining acute
  
  (test "RTL base with combining mark"
    '(0 0 1)  ; RTL base and its combining mark
    (positions-only (compute-text-metrics 
                     (string hebrew-alef combining-acute) 8))))

;;; =================================================================
;;; Edge Cases and Error Conditions
;;; =================================================================

(test-group "edge-cases"
  (test "empty string positions"
    '(0)
    (positions-only (compute-text-metrics "" 8)))
  
  (test "single character positions count"
    2  ; Should have 2 positions: start + end
    (length (positions-only (compute-text-metrics "a" 8))))
  
  (test "bidi state list length matches string"
    #t
    (let* ([str (string-append "abc" (string hebrew-alef hebrew-bet hebrew-gimel))]
           [metrics (compute-text-metrics str 8)])
      (= (string-length str)
         (length (text-metrics-bidi-state-list metrics)))))
  
  (test "sgr list length matches string"
    #t
    (let* ([str (string-append "abc" (string hebrew-alef hebrew-bet hebrew-gimel))]
           [metrics (compute-text-metrics str 8)])
      (= (string-length str)
         (length (text-metrics-sgr-list metrics))))))

;;; =================================================================
;;; Bidi State Access Tests
;;; =================================================================

(test-group "bidi-state-access"
  (test "get bidi state at valid index"
    #t
    (let* ([metrics (compute-text-metrics 
                     (string-append "abc" (string hebrew-alef hebrew-bet hebrew-gimel)) 8)]
           [state (text-metrics-get-bidi-state-at-index metrics 0)])
      (bidi-state? state)))
  
  (test "get bidi state at invalid index returns default"
    #t
    (let* ([metrics (compute-text-metrics "abc" 8)]
           [state (text-metrics-get-bidi-state-at-index metrics 10)])
      (and (bidi-state? state)
           (= (bidi-state-embedding-level state) 0))))
  
  (test "set bidi state returns new metrics"
    #t
    (let* ([metrics (compute-text-metrics "abc" 8)]
           [new-state (make-bidi-state 2 'L 'none)]
           [new-metrics (text-metrics-set-bidi-state-at-index metrics 1 new-state)])
      (not (eq? metrics new-metrics)))))

;;; =================================================================
;;; Text Modification with Bidi Tests
;;; =================================================================

(test-group "text-modification-bidi"
  (test "insert character maintains bidi state count"
    4  ; Original 3 chars + 1 inserted = 4
    (let* ([original (compute-text-metrics "abc" 8)]
           [new-state (make-bidi-state 0 'neutral 'none)]
           [modified (text-metrics-insert-char-with-sgr-and-bidi 
                     original 1 #\x new-state (make-default-sgr))])
      (length (text-metrics-bidi-state-list modified))))
  
  (test "delete range maintains synchronization"
    #t
    (let* ([original (compute-text-metrics "abcde" 8)]
           [modified (text-metrics-delete-range original 1 3)]) ; Delete "bc"
      (and (= (string-length (text-metrics-string modified))
              (length (text-metrics-sgr-list modified)))
           (= (string-length (text-metrics-string modified))
              (length (text-metrics-bidi-state-list modified)))))))

;;; =================================================================
;;; Bidirectional Utility Function Tests  
;;; =================================================================

(test-group "bidi-utilities"
  (test "paragraph direction detection - LTR"
    'ltr
    (text-metrics-get-paragraph-direction (compute-text-metrics "abc" 8)))
  
  (test "paragraph direction detection - RTL"
    'rtl
    (text-metrics-get-paragraph-direction (compute-text-metrics 
                                          (string hebrew-alef hebrew-bet hebrew-gimel) 8)))
  
  (test "RTL position detection"
    #f  ; First character in LTR text should not be RTL
    (text-metrics-is-rtl-at-position (compute-text-metrics "abc" 8) 0))
  
  (test "resolved levels list length"
    3
    (length (text-metrics-get-resolved-levels (compute-text-metrics "abc" 8)))))

;;; =================================================================
;;; Performance and Stress Tests
;;; =================================================================

(test-group "performance-tests"
  (test "large string processing"
    #t
    (let* ([large-str (make-string 1000 #\a)]
           [metrics (compute-text-metrics large-str 8)])
      (= (length (text-metrics-cell-positions metrics)) 1001))) ; 1000 chars + final
  
  (test "mixed large bidi string"
    #t
    (let* ([ltr-part (make-string 500 #\a)]
           [rtl-part (make-string 500 hebrew-alef)] ; Hebrew Alef
           [mixed-str (string-append ltr-part rtl-part)]
           [metrics (compute-text-metrics mixed-str 8)])
      (= (string-length mixed-str)
         (length (text-metrics-bidi-state-list metrics))))))

;;; =================================================================
;;; Integration Tests with Rendering
;;; =================================================================

(test-group "rendering-integration"
  (test "render line with bidi text"
    #t
    (let* ([metrics (compute-text-metrics 
                     (string-append "abc" (string hebrew-alef hebrew-bet hebrew-gimel)) 8)])
      (let-values ([(rendered-str sgr-list bidi-list)
                    (text-metrics-render-line metrics 0 10)])
        (and (string? rendered-str)
             (list? sgr-list)
             (list? bidi-list)
             (= (string-length rendered-str)
                (length sgr-list)
                (length bidi-list))))))
  
  (test "render line string only"
    #t
    (let* ([metrics (compute-text-metrics "abc" 8)]
           [rendered (text-metrics-render-line-string-only metrics 0 5)])
      (string? rendered)))
  
  (test "get rendered spans"
    #t
    (let* ([metrics (compute-text-metrics "abc" 8)]
           [spans (text-metrics-get-rendered-spans metrics)])
      (and (list? spans)
           (every (lambda (span) 
                   (and (pair? span)
                        (string? (car span))))
                 spans)))))

;;; =================================================================
;;; Regression Tests for Known Issues
;;; =================================================================

(test-group "regression-tests"
  ;; Add specific test cases for any bugs discovered during development
  
  (test "zero-width characters don't break positioning"
    '(0 0 1)  ; Zero-width char should stay at same position
    (positions-only (compute-text-metrics 
                     (string #\a zero-width-space #\b) 8))) ; a + ZWSP + b
  
  (test "final position is always last"
    #t
    (let* ([metrics (compute-text-metrics 
                     (string-append "abc" (string hebrew-alef hebrew-bet hebrew-gimel)) 8)]
           [positions (text-metrics-cell-positions metrics)])
      (= (last positions)
         (apply max positions)))))

;;; =================================================================
;;; Test Execution and Cleanup
;;; =================================================================

;; Helper function to run specific test groups
(define (run-test-group group-name)
  "Run a specific test group by name"
  (format #t "Running test group: ~a~%" group-name)
  ;; SRFI-64 doesn't have built-in group filtering, so we run all tests
  ;; In a real implementation, you might want to add filtering capability
  )

;; Print test summary information
(define (print-test-summary)
  "Print summary of test results"
  (format #t "~%=== Test Summary ===~%")
  (format #t "Total tests: ~a~%" (test-runner-test-count (test-runner-current)))
  (format #t "Passed: ~a~%" (test-runner-pass-count (test-runner-current)))
  (format #t "Failed: ~a~%" (test-runner-fail-count (test-runner-current)))
  (format #t "Skipped: ~a~%" (test-runner-skip-count (test-runner-current)))
  (format #t "Expected failures: ~a~%" (test-runner-xfail-count (test-runner-current))))

;; Main test execution
(test-end "text-metrics-bidi")

;; Print results summary
(print-test-summary)

;; Exit with appropriate code
(exit (if (zero? (test-runner-fail-count (test-runner-current))) 0 1))
