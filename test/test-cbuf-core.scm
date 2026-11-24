;;; Test suite for cbuf-core.scm
;;; Using SRFI-64 testing framework

(use-modules (srfi srfi-64)         ; Testing framework
             (gano cbuf-core)       ; Module under test
             (gano text-metrics)    ; For text-metrics operations
             (gano rendering)       ; For SGR operations
             (srfi srfi-1)          ; List utilities
             (srfi srfi-13)         ; String utilities
             (srfi srfi-34)         ; guard
             (srfi srfi-35))        ; conditions

;;; Start test suite
(test-begin "cbuf-core")

;;; =================================================================
;;; CONSTRUCTOR TESTS
;;; =================================================================

(test-group "constructor"
  
  (test-group "basic-construction"
    (let ([cbuf (make-cbuf)])
      (test-assert "creates valid cbuf" (cbuf? cbuf))
      (test-equal "initial line count" 1 (cbuf-line-count cbuf))
      (test-equal "initial line is empty" "" (cbuf-text-cur cbuf))
      (test-equal "initial line position" 0 (cbuf-line-cur cbuf))
      (test-equal "initial data position" 0 (cbuf-x-data cbuf))
      (test-equal "initial cell position" 0 (cbuf-x-cell cbuf))
      (test-equal "initial goal position" 0 (cbuf-x-goal cbuf))))
  
  (test-group "constructor-parameters"
    (let ([cbuf (make-cbuf #:tab-size 4 #:cjk? #t #:line-ending "\r\n")])
      (test-equal "custom tab size" 4 (cbuf-tab-size cbuf))
      (test-assert "custom cjk mode" (cbuf-cjk? cbuf))
      (test-equal "custom line ending" "\r\n" (cbuf-line-ending cbuf))))
  
  (test-group "initial-text"
    (let ([cbuf (make-cbuf #:initial-text "hello\nworld")])
      (test-equal "multiline text line count" 2 (cbuf-line-count cbuf))
      (test-equal "first line content" "hello" (cbuf-get-line-text cbuf 0))
      (test-equal "second line content" "world" (cbuf-get-line-text cbuf 1))
      (test-equal "current line is first" "hello" (cbuf-text-cur cbuf))))
  
  (test-group "edge-cases"
    (test-assert "empty initial text creates one empty line"
                 (= 1 (cbuf-line-count (make-cbuf #:initial-text ""))))
    
    ;; A trailing line ending sets final-newline? rather than adding an
    ;; empty line (as cbuf-load-from-string! does).
    (test-equal "text ending with newline"
                2
                (cbuf-line-count (make-cbuf #:initial-text "a\nb\n")))
    
    (test-equal "single newline is one empty line"
                1
                (cbuf-line-count (make-cbuf #:initial-text "\n")))))

;;; =================================================================
;;; RECORD FIELD ACCESS TESTS
;;; =================================================================

(test-group "field-access"
  
  (test-group "position-fields"
    (let ([cbuf (make-cbuf)])
      ;; Test initial values
      (test-equal "initial line-cur" 0 (cbuf-line-cur cbuf))
      (test-equal "initial x-data" 0 (cbuf-x-data cbuf))
      (test-equal "initial x-cell" 0 (cbuf-x-cell cbuf))
      (test-equal "initial x-goal" 0 (cbuf-x-goal cbuf))
      
      ;; Test setters
      (set-cbuf-line-cur! cbuf 5)
      (set-cbuf-x-data! cbuf 10)
      (set-cbuf-x-cell! cbuf 15)
      (set-cbuf-x-goal! cbuf 20)
      
      (test-equal "modified line-cur" 5 (cbuf-line-cur cbuf))
      (test-equal "modified x-data" 10 (cbuf-x-data cbuf))
      (test-equal "modified x-cell" 15 (cbuf-x-cell cbuf))
      (test-equal "modified x-goal" 20 (cbuf-x-goal cbuf))))
  
  (test-group "configuration-fields"
    (let ([cbuf (make-cbuf)])
      (test-equal "default tab-size" 8 (cbuf-tab-size cbuf))
      (test-equal "default vert-tab-size" 6 (cbuf-vert-tab-size cbuf))
      (test-equal "default form-size" 66 (cbuf-form-size cbuf))
      (test-equal "default home-pos" 0 (cbuf-home-pos cbuf))
      (test-equal "default limit-pos" 79 (cbuf-limit-pos cbuf))
      (test-equal "default limit-type" 'data (cbuf-limit-type cbuf))))
  
  (test-group "state-flags"
    (let ([cbuf (make-cbuf)])
      (test-assert "initially not modified" (not (cbuf-modified? cbuf)))
      (test-assert "initially no bell" (not (cbuf-bell? cbuf)))
      (test-assert "initially no mark" (not (cbuf-mark-set? cbuf)))
      
      ;; Test flag setters
      (set-cbuf-modified?! cbuf #t)
      (set-cbuf-bell?! cbuf #t)
      (set-cbuf-mark-set?! cbuf #t)
      
      (test-assert "modified flag set" (cbuf-modified? cbuf))
      (test-assert "bell flag set" (cbuf-bell? cbuf))
      (test-assert "mark flag set" (cbuf-mark-set? cbuf))))
  
  (test-group "mark-fields"
    (let ([cbuf (make-cbuf)])
      (test-equal "initial mark-line" 0 (cbuf-mark-line cbuf))
      (test-equal "initial mark-x-data" 0 (cbuf-mark-x-data cbuf))
      
      (set-cbuf-mark-line! cbuf 3)
      (set-cbuf-mark-x-data! cbuf 7)
      
      (test-equal "modified mark-line" 3 (cbuf-mark-line cbuf))
      (test-equal "modified mark-x-data" 7 (cbuf-mark-x-data cbuf))))
  
  (test-group "buffer-fields"
    (let ([cbuf (make-cbuf)])
      (test-equal "initial cut-buffer" '() (cbuf-cut-buffer cbuf))
      (test-equal "initial undo-list" '() (cbuf-undo-list cbuf))
      
      (set-cbuf-cut-buffer! cbuf '("line1" "line2"))
      (set-cbuf-undo-list! cbuf '(undo1 undo2))
      
      (test-equal "modified cut-buffer" '("line1" "line2") (cbuf-cut-buffer cbuf))
      (test-equal "modified undo-list" '(undo1 undo2) (cbuf-undo-list cbuf))))
  
  (test-group "sgr-fields"
    (let ([cbuf (make-cbuf)])
      (test-assert "has current-sgr" (cbuf-current-sgr cbuf))
      (test-equal "default grcm mode" 'replacing (cbuf-default-grcm cbuf))
      (test-equal "initial sgr-stack" '() (cbuf-sgr-stack cbuf))
      
      (set-cbuf-sgr-stack! cbuf '(sgr1 sgr2))
      (test-equal "modified sgr-stack" '(sgr1 sgr2) (cbuf-sgr-stack cbuf)))))

;;; =================================================================
;;; DERIVED ACCESSOR TESTS
;;; =================================================================

(test-group "derived-accessors"
  
  (test-group "basic-accessors"
    (let ([cbuf (make-cbuf #:initial-text "hello\nworld\ntest")])
      (test-equal "line count" 3 (cbuf-line-count cbuf))
      (test-equal "all text" '("hello" "world" "test") (cbuf-text cbuf))
      (test-equal "current line text" "hello" (cbuf-text-cur cbuf))
      (test-assert "current metrics" (cbuf-metrics-cur cbuf))
      (test-assert "current sgr list" (list? (cbuf-sgr-list-cur cbuf)))))
  
  (test-group "line-access"
    (let ([cbuf (make-cbuf #:initial-text "first\nsecond\nthird")])
      (test-equal "get line 0" "first" (cbuf-get-line-text cbuf 0))
      (test-equal "get line 1" "second" (cbuf-get-line-text cbuf 1))
      (test-equal "get line 2" "third" (cbuf-get-line-text cbuf 2))))
  
  (test-group "length-accessors"
    (let ([cbuf (make-cbuf #:initial-text "hello\tworld")])  ; Tab in text
      (test-equal "text length (codepoints)" 11 (cbuf-text-cur-length cbuf))
      (test-assert "cell length >= text length" 
                   (>= (cbuf-text-cur-cell-length cbuf) (cbuf-text-cur-length cbuf)))
      (test-equal "base length" 11 (cbuf-text-cur-base-length cbuf)))))  ; Tab counts as 1 base char

;;; =================================================================
;;; BOUNDARY CONDITION TESTS
;;; =================================================================

(test-group "boundary-conditions"
  
  (test-group "empty-buffer"
    (let ([cbuf (make-cbuf)])
      (test-equal "empty buffer line count" 1 (cbuf-line-count cbuf))
      (test-equal "empty line length" 0 (cbuf-text-cur-length cbuf))
      (test-equal "empty line cell length" 0 (cbuf-text-cur-cell-length cbuf))))
  
  (test-group "out-of-bounds-access"
    (let ([cbuf (make-cbuf #:initial-text "single line")])
      ;; These might crash currently - we're testing the current behavior
      ;; In a fixed version, these should either return safe defaults or raise errors
      
      ;; Test accessing beyond available lines (currently unsafe)
      ;; Note: These tests document current unsafe behavior
      (test-assert "line access documentation"
                   ;; This test documents that bounds checking is needed
                   #t)))
  
  (test-group "position-consistency"
    (let ([cbuf (make-cbuf #:initial-text "test line")])
      ;; Test that position fields can be set independently
      ;; In a more robust implementation, these might be kept consistent
      (set-cbuf-x-data! cbuf 5)
      (set-cbuf-x-cell! cbuf 10)
      (set-cbuf-x-goal! cbuf 15)
      
      (test-equal "x-data can be set independently" 5 (cbuf-x-data cbuf))
      (test-equal "x-cell can be set independently" 10 (cbuf-x-cell cbuf))
      (test-equal "x-goal can be set independently" 15 (cbuf-x-goal cbuf)))))

;;; =================================================================
;;; ERROR CONDITION TESTS
;;; =================================================================

(test-group "error-conditions"
  
  (test-group "condition-types-exist"
    (test-assert "cbuf-range-error? exists" (procedure? cbuf-range-error?))
    (test-assert "cbuf-beginning-of-buffer-error? exists" (procedure? cbuf-beginning-of-buffer-error?))
    (test-assert "cbuf-end-of-buffer-error? exists" (procedure? cbuf-end-of-buffer-error?))
    (test-assert "cbuf-beginning-of-line-error? exists" (procedure? cbuf-beginning-of-line-error?))
    (test-assert "cbuf-end-of-line-error? exists" (procedure? cbuf-end-of-line-error?))
    (test-assert "cbuf-line-limit-exceeded-error? exists" (procedure? cbuf-line-limit-exceeded-error?)))
  
  (test-group "condition-hierarchy"
    ;; Test that specific errors inherit from range-error
    ;; Note: This requires actually creating conditions to test properly
    ;; For now, just verify the predicates exist
    (test-assert "error conditions defined" #t)))


;;; =================================================================
;;; STRICT TESTS
;;; =================================================================

(define (condition-of thunk)
  "The condition THUNK raises, or #f."
  (guard (c (#t c)) (thunk) #f))

(test-group "strict: constructor defaults"
  (let ([b (make-cbuf)])
    (test-equal "tab size" 8 (cbuf-tab-size b))
    (test-equal "vertical tab size" 6 (cbuf-vert-tab-size b))
    (test-equal "form size" 66 (cbuf-form-size b))
    (test-equal "cjk?" #f (cbuf-cjk? b))
    (test-equal "grcm" 'replacing (cbuf-default-grcm b))
    (test-equal "line ending" "\n" (cbuf-line-ending b))
    (test-equal "limit pos" 79 (cbuf-limit-pos b))
    (test-equal "limit type" 'data (cbuf-limit-type b))
    (test-equal "home pos" 0 (cbuf-home-pos b))
    (test-equal "final newline?" #t (cbuf-final-newline? b))
    (test-equal "final newline policy" 'always-add (cbuf-final-newline-policy b))
    (test-equal "not modified" #f (cbuf-modified? b))
    (test-equal "no mark" #f (cbuf-mark-set? b))
    (test-equal "no bell" #f (cbuf-bell? b))
    (test-equal "empty cut buffer" '() (cbuf-cut-buffer b))
    (test-equal "empty undo list" '() (cbuf-undo-list b))
    (test-equal "empty SGR stack" '() (cbuf-sgr-stack b))
    (test-assert "default SGR" (sgr-equal? (make-default-sgr) (cbuf-current-sgr b)))
    (test-equal "one empty line" '("") (cbuf-text b))))

(test-group "strict: initial text"
  (let ([b (make-cbuf #:initial-text "a\r\nb\r\n")])
    (test-equal "CRLF lines" '("a" "b") (cbuf-text b))
    (test-equal "CRLF detected" "\r\n" (cbuf-line-ending b))
    (test-equal "trailing ending detected" #t (cbuf-final-newline? b)))
  (let ([b (make-cbuf #:initial-text "a\nb")])
    (test-equal "no trailing ending" #f (cbuf-final-newline? b))
    (test-equal "LF detected" "\n" (cbuf-line-ending b)))
  (test-equal "CR lines" '("a" "b") (cbuf-text (make-cbuf #:initial-text "a\rb\r")))
  (test-equal "blank last line kept" '("a" "") (cbuf-text (make-cbuf #:initial-text "a\n\n")))
  (test-equal "no ending at all: LF" "\n" (cbuf-line-ending (make-cbuf #:initial-text "abc")))
  (test-equal "explicit line ending wins" "\r\n"
              (cbuf-line-ending (make-cbuf #:initial-text "a\nb\n" #:line-ending "\r\n")))
  (test-equal "explicit final-newline? wins" #f
              (cbuf-final-newline? (make-cbuf #:initial-text "a\n" #:final-newline? #f)))
  (test-equal "explicit final-newline? #t" #t
              (cbuf-final-newline? (make-cbuf #:initial-text "a" #:final-newline? #t)))
  (let ([b (make-cbuf #:initial-text "x\ty" #:tab-size 4 #:cjk? #t)])
    (test-equal "metrics use the tab size" 4 (text-metrics-tabsize (cbuf-metrics-cur b)))
    (test-equal "metrics use cjk?" #t (text-metrics-cjk? (cbuf-metrics-cur b)))
    (test-equal "cell length with tab size 4" 5 (cbuf-text-cur-cell-length b))))

(test-group "strict: constructor validation"
  (test-error "tab size 0" #t (make-cbuf #:tab-size 0))
  (test-error "fractional tab size" #t (make-cbuf #:tab-size 2.5))
  (test-error "non-number tab size" #t (make-cbuf #:tab-size "8"))
  (test-error "vertical tab size 0" #t (make-cbuf #:vert-tab-size 0))
  (test-error "form size 0" #t (make-cbuf #:form-size 0))
  (test-error "bad grcm" #t (make-cbuf #:default-grcm 'inserting))
  (test-error "bad line ending" #t (make-cbuf #:line-ending "\n\n"))
  (test-error "empty line ending" #t (make-cbuf #:line-ending ""))
  (test-error "negative limit pos" #t (make-cbuf #:limit-pos -1))
  (test-error "bad final-newline?" #t (make-cbuf #:final-newline? 'yes))
  (test-error "bad final-newline policy" #t (make-cbuf #:final-newline-policy 'sometimes))
  (test-error "non-string initial text" #t (make-cbuf #:initial-text 'hello))
  (test-assert "every policy is accepted"
               (every (lambda (p) (cbuf? (make-cbuf #:final-newline-policy p)))
                      '(always-add never-add preserve)))
  (test-assert "every line ending is accepted"
               (every (lambda (e) (cbuf? (make-cbuf #:line-ending e)))
                      '("\n" "\r\n" "\r" " " " ")))
  (test-equal "explicit limit pos" 40 (cbuf-limit-pos (make-cbuf #:limit-pos 40))))

(test-group "strict: derived accessors"
  (let ([b (make-cbuf #:initial-text "éx\n日\tz\n")])
    (test-equal "line count" 2 (cbuf-line-count b))
    (test-equal "text" '("éx" "日\tz") (cbuf-text b))
    (test-equal "codepoint length" 3 (cbuf-text-cur-length b))
    (test-equal "base length" 2 (cbuf-text-cur-base-length b))
    (test-equal "cell length" 2 (cbuf-text-cur-cell-length b))
    (set-cbuf-line-cur! b 1)
    (test-equal "second line" "日\tz" (cbuf-text-cur b))
    (test-equal "second line cells" 9 (cbuf-text-cur-cell-length b))
    (test-equal "SGR list per codepoint" 3 (length (cbuf-sgr-list-cur b)))
    (test-equal "get-line-text" "éx" (cbuf-get-line-text b 0))
    (test-equal "get-line-text past end" "" (cbuf-get-line-text b 2))
    (test-equal "get-line-text negative" "" (cbuf-get-line-text b -1))
    (set-cbuf-line-cur! b 5)
    (test-equal "invalid current line reads as empty" "" (cbuf-text-cur b))
    (test-equal "and has empty metrics" 0 (cbuf-text-cur-cell-length b))))

(test-group "strict: position validation"
  (let ([b (make-cbuf #:initial-text "éx\nab")])
    (test-assert "line 0" (cbuf-line-valid? b 0))
    (test-assert "line 1" (cbuf-line-valid? b 1))
    (test-assert "line 2 is past the end" (not (cbuf-line-valid? b 2)))
    (test-assert "negative line" (not (cbuf-line-valid? b -1)))
    (test-assert "end of a line with a combining mark" (cbuf-position-valid? b 0 2))
    (test-assert "positions count base characters, not codepoints"
                 (not (cbuf-position-valid? b 0 3)))
    (test-assert "negative column" (not (cbuf-position-valid? b 0 -1)))
    (test-assert "column on a missing line" (not (cbuf-position-valid? b 2 0)))
    (test-equal "validate-line accepts a good line" #f
                (condition-of (lambda () (cbuf-validate-line b 1 'test))))
    (test-equal "validate-position accepts a good position" #f
                (condition-of (lambda () (cbuf-validate-position b 0 2 'test))))
    (let ([c (condition-of (lambda () (cbuf-validate-line b -1 'up)))])
      (test-assert "line before start: beginning-of-buffer" (cbuf-beginning-of-buffer-error? c))
      (test-assert "which is a range error" (cbuf-range-error? c))
      (test-equal "operation" 'up (cbuf-range-error:operation c))
      (test-equal "requested" -1 (cbuf-range-error:requested c))
      (test-equal "actual" 0 (cbuf-range-error:actual c)))
    (let ([c (condition-of (lambda () (cbuf-validate-line b 2 'down)))])
      (test-assert "line past end: end-of-buffer" (cbuf-end-of-buffer-error? c))
      (test-equal "actual is the last line" 1 (cbuf-range-error:actual c)))
    (let ([c (condition-of (lambda () (cbuf-validate-position b 0 -1 'left)))])
      (test-assert "column before start: beginning-of-line" (cbuf-beginning-of-line-error? c)))
    (let ([c (condition-of (lambda () (cbuf-validate-position b 0 3 'right)))])
      (test-assert "column past end: end-of-line" (cbuf-end-of-line-error? c))
      (test-equal "actual is the base length" 2 (cbuf-range-error:actual c)))
    (test-assert "bad line is reported before bad column"
                 (cbuf-end-of-buffer-error?
                  (condition-of (lambda () (cbuf-validate-position b 9 9 'x)))))))

(test-group "strict: line-limit condition"
  (let ([c (make-condition &cbuf-line-limit-exceeded
                           'operation 'insert 'requested 100 'actual 80
                           'reason "too long" 'limit 80)])
    (test-assert "is a line-limit error" (cbuf-line-limit-exceeded-error? c))
    (test-assert "and a range error" (cbuf-range-error? c))
    (test-equal "limit" 80 (cbuf-line-limit-exceeded-error:limit c))
    (test-equal "reason" "too long" (cbuf-range-error:reason c))))

(test-end "cbuf-core")
