;;; -*- mode: scheme; coding: utf-8; -*-

;;;; Copyright (C) 1996-2025 Michael L. Gran
;;;; License GPL 3+

;;; Test suite for Gano UAX #9 Brackets Module
;;; Using SRFI-64 testing framework

(use-modules (srfi srfi-64)        ; Testing framework
	     (srfi srfi-1)         ; List utilities
	     (srfi srfi-11)	   ; let-values
             (gano uax9-core)      ; Core module for basic functionality
             (gano uax9-brackets)  ; Brackets module under test
             (gano char))          ; For bidi class constants

;;; Test suite setup
(test-begin "gano-uax9-brackets")

;;; =================================================================
;;; TEST DATA FOR BRACKET PROCESSING
;;; =================================================================

;; Hebrew text fragments for bracket testing
(define hebrew-hello "שלום")           ; Hebrew "hello"
(define hebrew-text "עברית")           ; Hebrew "Hebrew"

;; Arabic text fragments  
(define arabic-hello "مرحبا")          ; Arabic "hello"
(define arabic-text "عربي")           ; Arabic "Arabic"

;; Complex bracket test strings
(define mixed-rtl-brackets (string-append hebrew-hello " (test) " hebrew-text))
(define mixed-english-arabic (string-append "English " hebrew-hello " (test) " arabic-text))
(define nested-brackets "a(b[c{d}e]f)g")
(define mismatched-brackets "a(b]c[d)e")
(define multiple-brackets "first(a)second[b]third{c}")

;;; =================================================================
;;; BRACKET RECORD TESTS
;;; =================================================================

(test-group "bracket-records"
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
           (multi-line-bracket-pair-spans-lines? pair))))
  
  ;; Test single-line bracket pair
  (test-assert "make single-line bracket pair"
    (let* ([open-bracket (make-open-bracket #\{ 0 5 8 38)]
           [pair (make-multi-line-bracket-pair open-bracket 12 #\} 0 #f)])
      (and (multi-line-bracket-pair? pair)
           (not (multi-line-bracket-pair-spans-lines? pair))))))

;;; =================================================================
;;; ENHANCED BRACKET PROCESSING TESTS
;;; =================================================================

(test-group "enhanced-bracket-processing"
  ;; Test find-matching-open-bracket-strict
  (test-assert "strict bracket matching - valid match"
    (let* ([stack (list (list 2 #\( 0) (list 5 #\[ 0))]  ; Stack: (..., [...
           [result (find-matching-open-bracket-strict stack #\))])
      (and result
           (= (car (car result)) 2)      ; Position of matching (
           (char=? (cadr (car result)) #\()  ; Character is (
           (= (length (cdr result)) 1))))    ; One item remains in stack
  
  (test-assert "strict bracket matching - no match"
    (let* ([stack (list (list 5 #\[ 0))]  ; Stack has [, looking for )
           [result (find-matching-open-bracket-strict stack #\))])
      (not result)))
  
  (test-assert "strict bracket matching - empty stack"
    (let ([result (find-matching-open-bracket-strict '() #\))])
      (not result)))
  
  ;; Test find-strong-type-in-range
  (test-assert "find strong type in simple range"
    (let* ([text "!@# א $%&"]  ; Neutral chars, Hebrew Alef (strong R), Neutral chars
           [types-vector (list->vector (map char-get-bidi-class (string->list text)))]
           [levels (resolve-paragraph-bidi text)]
           [result (find-strong-type-in-range text types-vector levels 0 (string-length text))])
      (and result
           (eq? (car result) BC-R))))

  (test-assert "no strong type in range"
    (let* ([text "!@# $%& ()"]  ; Only neutral characters
           [types-vector (list->vector (map char-get-bidi-class (string->list text)))]
           [levels (resolve-paragraph-bidi text)]
           [result (find-strong-type-in-range text types-vector levels 0 (string-length text))])
      (not result)))

    (test-assert "strong type with isolate skipping"
    (let* ([text (string-append "a" 
                                (string (integer->char #x2066))  ; LRI
                                hebrew-hello 
                                (string (integer->char #x2069))  ; PDI
                                "b")]  ; a LRI hebrew PDI b
           [types-vector (list->vector (map char-get-bidi-class (string->list text)))]
           [levels (resolve-paragraph-bidi text)]
           [result (find-strong-type-in-range text types-vector levels 0 (string-length text))])
      (and result
           (eq? (car result) BC-L)))))  ; Should find 'a' or 'b', skipping isolate

;;; =================================================================
;;; BRACKET PAIRS WITH CONTEXT TESTS
;;; =================================================================

(test-group "bracket-pairs-with-context"
  ;; Test basic bracket pair finding with context
  (test-assert "find simple bracket pairs with context"
    (let* ([text "a(b)c"]
           [types (map char-get-bidi-class (string->list text))]
           [levels (resolve-paragraph-bidi text)]
           [context (find-bracket-pairs-with-context text types levels)])
      (and (bracket-context? context)
           (= (length (bracket-context-line-pairs context)) 1)
           (null? (bracket-context-unclosed-brackets context)))))
  
  (test-assert "unclosed brackets tracked correctly"
    (let* ([text "a(b[c"]  ; Two unclosed brackets
           [types (map char-get-bidi-class (string->list text))]
           [levels (resolve-paragraph-bidi text)]
           [context (find-bracket-pairs-with-context text types levels)])
      (and (= (length (bracket-context-unclosed-brackets context)) 2)
           (null? (bracket-context-line-pairs context)))))
  
  (test-assert "inherited brackets processed correctly"
    (let* ([inherited (list (make-open-bracket #\( 0 0 5 5))]
           [text "test)end"]  ; Closes the inherited bracket
           [types (map char-get-bidi-class (string->list text))]
           [levels (resolve-paragraph-bidi text)]
           [context (find-bracket-pairs-with-context 
                     text types levels 
                     #:inherited-brackets inherited
                     #:line-number 1)])
      (= (length (bracket-context-line-pairs context)) 1)))
  
  (test-assert "nested brackets with context"
    (let* ([text nested-brackets]  ; "a(b[c{d}e]f)g"
           [types (map char-get-bidi-class (string->list text))]
           [levels (resolve-paragraph-bidi text)]
           [context (find-bracket-pairs-with-context text types levels)])
      (= (length (bracket-context-line-pairs context)) 3))))  ; Should find 3 pairs

;;; =================================================================
;;; MULTI-LINE PROCESSING TESTS
;;; =================================================================

(test-group "multi-line-processing"
  ;; Test processing multiple lines
  (test-assert "process simple multi-line document"
    (let* ([lines '("first line" "second line" "third line")]
           [contexts (process-multiple-lines lines)])
      (and (= (length contexts) 3)
           (every bracket-context? contexts))))
  
  (test-assert "bracket state carries across lines"
    (let* ([lines '("start(" "middle" ")end")]  ; Bracket spans 3 lines
           [contexts (process-multiple-lines lines)])
      (and (= (length contexts) 3)
           ;; First line should have unclosed bracket
           (= (length (bracket-context-unclosed-brackets (first contexts))) 1)
           ;; Last line should have a multi-line pair
           (> (length (bracket-context-line-pairs (third contexts))) 0))))
  
  (test-assert "multiple bracket contexts"
    (let* ([lines '("first(a)" "second[b]" "third{c}")]  ; Each line has complete pair
           [contexts (process-multiple-lines lines)])
      (every (lambda (context)
	       (= (length (bracket-context-line-pairs context)) 1))
             contexts))))

;;; =================================================================
;;; LINE SPLITTING WITH BRACKET CONTEXT TESTS
;;; =================================================================

(test-group "line-splitting-with-brackets"
  ;; Test basic line splitting with bracket context
  (test-assert "split line with no brackets"
    (let* ([text "hello world test"]
           [context (make-bracket-context '() '() '())])
      (let-values ([(ctx1 ctx2 text1 text2) 
                    (split-line-with-bracket-context text 6 context)])
        (and (string=? text1 "hello ")
             (string=? text2 "world test")
             (bracket-context? ctx1)
             (bracket-context? ctx2)))))
  
  (test-assert "split line preserves bracket pairs"
    (let* ([text "a(b)c d(e)f"]  ; Two complete pairs
           [types (map char-get-bidi-class (string->list text))]
           [levels (resolve-paragraph-bidi text)]
           [context (find-bracket-pairs-with-context text types levels)])
      (let-values ([(ctx1 ctx2 text1 text2) 
                    (split-line-with-bracket-context text 6 context)])
        ;; First context should have one complete pair
        (= (length (bracket-context-line-pairs ctx1)) 1))))
  
  (test-assert "split line handles unclosed brackets"
    (let* ([text "a(b c(d"]  ; One complete pair, one unclosed
           [types (map char-get-bidi-class (string->list text))]
           [levels (resolve-paragraph-bidi text)]
           [context (find-bracket-pairs-with-context text types levels)])
      (let-values ([(ctx1 ctx2 text1 text2) 
                    (split-line-with-bracket-context text 4 context)])
        ;; Split should categorize brackets correctly
        (and (bracket-context? ctx1)
             (bracket-context? ctx2))))))

;;; =================================================================
;;; CODE EDITOR UTILITIES TESTS
;;; =================================================================

(test-group "code-editor-utilities"
  ;; Test find-all-bracket-pairs
  (test-assert "find all bracket pairs in complex text"
    (let* ([pairs (find-all-bracket-pairs nested-brackets)])
      (= (length pairs) 3)))  ; Should find all three pairs
  
  (test-assert "find bracket pairs with inherited context"
    (let* ([inherited (list (make-open-bracket #\[ 0 0 0 0))]
           [pairs (find-all-bracket-pairs "test]more" #:inherited-brackets inherited)])
      (= (length pairs) 1)))  ; Should complete the inherited bracket
  
  ;; Test validate-bracket-structure
  (test-assert "validate correct bracket structure"
    (let ([result (validate-bracket-structure nested-brackets)])
      (car result)))  ; Should be valid
  
  (test-assert "detect mismatched brackets"
    (let ([result (validate-bracket-structure mismatched-brackets)])
      ;; Should be valid but return unclosed brackets info
      (car result)))
  
  (test-assert "validation with inherited brackets"
    (let* ([inherited (list (make-open-bracket #\( 0 0 0 0))]
           [result (validate-bracket-structure "test)" #:inherited-brackets inherited)])
      (car result)))  ; Should be valid when bracket is closed
  
  ;; Test find-matching-bracket-position
  (test-assert "find matching bracket position"
    (let ([pos (find-matching-bracket-position "a(b)c" 1)])
      (= pos 3)))  ; Opening ( at 1 should match closing ) at 3
  
  (test-assert "find matching bracket for closing bracket"
    (let ([pos (find-matching-bracket-position "a(b)c" 3)])
      (= pos 1)))  ; Closing ) at 3 should match opening ( at 1
  
  (test-assert "no matching bracket"
    (let ([pos (find-matching-bracket-position "a(b" 1)])
      (not pos)))  ; Unclosed bracket should return #f
  
  (test-assert "matching with inherited brackets"
    (let* ([inherited (list (make-open-bracket #\[ 0 0 0 0))]
           [pos (find-matching-bracket-position "test]" 4 #:inherited-brackets inherited)])
      (pk 'inherited inherited 'pos pos)
      (eq? pos 'previous-line)))  ; Should indicate match is on previous line
  
  ;; Test get-bracket-nesting-level
  (test-assert "get bracket nesting level"
    (let ([level (get-bracket-nesting-level "a(b(c)d)e" 4)])
      (= level 2)))  ; Position 4 is 'c', nested in two bracket pairs
  
  (test-assert "bracket nesting at start"
    (let ([level (get-bracket-nesting-level "a(b)c" 0)])
      (= level 0)))  ; Position 0 is 'a', not nested
  
  (test-assert "nesting with inherited brackets"
    (let* ([inherited (list (make-open-bracket #\[ 0 0 0 0)
                            (make-open-bracket #\{ 0 0 0 0))]
           [level (get-bracket-nesting-level "(test)" 2 #:inherited-brackets inherited)])
      (= level 3)))  ; 2 inherited + 1 current = 3
  
  ;; Test find-enclosing-brackets
  (test-assert "find enclosing brackets"
    (let* ([result (find-enclosing-brackets "a(b[c]d)e" 4)])
      (and result
           (multi-line-bracket-pair? result))))  ; Should find the innermost pair
  
  (test-assert "no enclosing brackets"
    (let ([result (find-enclosing-brackets "a(b)c" 0)])
      (not result)))  ; Position 0 ('a') is not enclosed
  
  (test-assert "enclosing with inherited brackets"
    (let* ([inherited (list (make-open-bracket #\[ 0 0 0 0))]
           [result (find-enclosing-brackets "test" 2 #:inherited-brackets inherited)])
      (pk 'enclosing 'inherited inherited 'result result)
      result)))  ; Should find the inherited bracket as enclosing

;;; =================================================================
;;; DOCUMENT ANALYSIS TESTS
;;; =================================================================

(test-group "document-analysis"
  ;; Test analyze-document-brackets
  (test-assert "analyze simple document"
    (let* ([lines '("first(line)" "second[line]" "third{line}")]
           [analysis (analyze-document-brackets lines)])
      (and (= (assoc-ref analysis 'total-lines) 3)
           (= (assoc-ref analysis 'total-pairs) 3)
           (= (assoc-ref analysis 'single-line-pairs) 3)
           (= (assoc-ref analysis 'multi-line-pairs) 0))))
  
  (test-assert "analyze document with multi-line brackets"
    (let* ([lines '("start(" "middle" ")end")]
           [analysis (analyze-document-brackets lines)])
      (and (= (assoc-ref analysis 'total-lines) 3)
           (= (assoc-ref analysis 'multi-line-pairs) 1))))
  
  ;; Test find-bracket-errors-in-document  
  (test-assert "find errors in document"
    (let* ([lines '("unclosed(" "bracket")]
           [errors (find-bracket-errors-in-document lines)])
      (not (null? errors))))  ; Should detect unclosed bracket
  
  (test-assert "clean document has no errors"
    (let* ([lines '("clean(line)" "another[line]")]
           [errors (find-bracket-errors-in-document lines)])
      (null? errors)))  ; Should have no errors
  
  ;; Test get-bracket-context-for-line
  (test-assert "get bracket context for specific line"
    (let* ([lines '("first" "second(line)" "third")]
           [context (get-bracket-context-for-line lines 1)])
      (and context
           (bracket-context? context))))
  
  (test-assert "invalid line number returns #f"
    (let* ([lines '("first" "second")]
           [context (get-bracket-context-for-line lines 5)])
      (not context))))

;;; =================================================================
;;; UTILITY FUNCTIONS TESTS
;;; =================================================================

(test-group "bracket-utilities"
  ;; Test get-bracket-nesting-at-position
  (test-assert "nesting at position within bracket context"
    (let* ([text "a(b[c]d)e"]
           [types (map char-get-bidi-class (string->list text))]
           [levels (resolve-paragraph-bidi text)]
           [context (find-bracket-pairs-with-context text types levels)]
           [nesting (get-bracket-nesting-at-position context 4)])
      (= nesting 2)))  ; Position 4 ('c') should be nested 2 deep
  
  ;; Test analyze-bracket-context
  (test-assert "analyze bracket context"
    (let* ([inherited (list (make-open-bracket #\( 0 0 0 0))]
           [pairs (list (make-multi-line-bracket-pair
                         (make-open-bracket #\[ 0 1 2 12)
                         8 #\] 0 #f))]
           [unclosed (list (make-open-bracket #\{ 0 1 5 15))]
           [context (make-bracket-context inherited pairs unclosed)]
           [analysis (analyze-bracket-context context #:line-number 1)])
      (and (= (assoc-ref analysis 'line-number) 1)
           (= (length (assoc-ref analysis 'inherited-brackets)) 1)
           (= (assoc-ref analysis 'line-pairs) 1)
           (= (length (assoc-ref analysis 'unclosed-brackets)) 1))))
  
  ;; Test print-bracket-context (just ensure it doesn't crash)
  (test-assert "print bracket context"
    (let* ([context (make-bracket-context '() '() '())])
      (with-output-to-string
        (lambda ()
          (print-bracket-context context #:line-number 0)))
      #t)))  ; Just test that it doesn't crash

;;; =================================================================
;;; EDGE CASES AND BOUNDARY TESTS
;;; =================================================================

(test-group "bracket-edge-cases"
  ;; Test empty bracket contexts
  (test-assert "empty bracket context operations"
    (let* ([context (make-bracket-context '() '() '())]
           [nesting (get-bracket-nesting-at-position context 5)])
      (= nesting 0)))
  
  ;; Test with only unmatched brackets
  (test-assert "all unmatched opening brackets"
    (let* ([text "((([{"]
           [types (map char-get-bidi-class (string->list text))]
           [levels (resolve-paragraph-bidi text)]
           [context (find-bracket-pairs-with-context text types levels)])
      (and (null? (bracket-context-line-pairs context))
           (= (length (bracket-context-unclosed-brackets context)) 5))))
  
  ;; Test with only unmatched closing brackets  
  (test-assert "all unmatched closing brackets"
    (let* ([text "}]))]"]
           [types (map char-get-bidi-class (string->list text))]
           [levels (resolve-paragraph-bidi text)]
           [context (find-bracket-pairs-with-context text types levels)])
      (and (null? (bracket-context-line-pairs context))
           (null? (bracket-context-unclosed-brackets context)))))
  
  ;; Test extremely nested brackets
  (test-assert "deeply nested brackets"
    (let* ([text "((((((()))))))"]  ; 6 levels deep
           [types (map char-get-bidi-class (string->list text))]
           [levels (resolve-paragraph-bidi text)]
           [context (find-bracket-pairs-with-context text types levels)])
      (= (length (bracket-context-line-pairs context)) 6)))
  
  ;; Test boundary positions
  (test-assert "bracket operations at text boundaries"
    (let* ([text "(test)"]
           [level-start (get-bracket-nesting-level text 0)]
           [level-end (get-bracket-nesting-level text (string-length text))])
      (and (= level-start 0)  ; Before opening bracket
           (= level-end 0))))) ; After closing bracket

;;; =================================================================
;;; INTEGRATION WITH CORE MODULE TESTS
;;; =================================================================

(test-group "integration-with-core"
  ;; Test bracket processing with complex bidi text
  (test-assert "brackets with RTL text"
    (let* ([text mixed-rtl-brackets]
           [pairs (find-all-bracket-pairs text)])
      (>= (length pairs) 0)))  ; Should not crash, may or may not find pairs
  
  (test-assert "brackets with mixed LTR/RTL text"
    (let* ([text mixed-english-arabic]
           [pairs (find-all-bracket-pairs text)])
      (every multi-line-bracket-pair? pairs)))  ; All results should be bracket pairs
  
  ;; Test bracket validation with bidi controls
  (test-assert "bracket validation with embedding controls"
    (let* ([text (string #\( (integer->char #x202A) #\a (integer->char #x202C) #\))]  ; ( LRE a PDF )
           [result (validate-bracket-structure text)])
      (car result)))  ; Should be valid despite bidi controls
  
  ;; Test multi-line processing with bidi state
  (test-assert "multi-line brackets preserve bidi state"
    (let* ([lines (list (string #\( (integer->char #x202A) #\a)    ; ( LRE a
                        (string #\b (integer->char #x202C) #\)))]   ; b PDF )
           [contexts (process-multiple-lines lines)])
      (= (length contexts) 2))))

;;; Test suite cleanup
(test-end "gano-uax9-brackets")

;; Local Variables:
;; eval: (put 'test-group 'scheme-indent-function 1)
;; eval: (put 'test-assert 'scheme-indent-function 1)
;; eval: (put 'let-values 'scheme-indent-function 1)
;; End:
