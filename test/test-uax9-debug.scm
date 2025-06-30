;;; -*- mode: scheme; coding: utf-8; -*-

;;;; Copyright (C) 1996-2025 Michael L. Gran
;;;; License GPL 3+

;;; Test suite for Gano UAX #9 Debug Module
;;; Using SRFI-64 testing framework

(use-modules (srfi srfi-64)        ; Testing framework
	     (srfi srfi-1)         ; List utilities
             (gano uax9-core)      ; Core module
             (gano uax9-brackets)  ; Brackets module  
             (gano uax9-debug)     ; Debug module under test
             (gano char))          ; For bidi class constants

;;; Test suite setup
(test-begin "gano-uax9-debug")

;;; =================================================================
;;; TEST DATA FOR DEBUG ANALYSIS
;;; =================================================================

;; Simple test strings
(define simple-ltr "Hello World")
(define simple-rtl "שלום")
(define simple-mixed "Hello שלום World")

;; Complex test strings
(define complex-brackets "English (עברית [test] more) end")
(define complex-numbers "Text 123 עברית 456 more")
(define complex-controls (string #\a (integer->char #x202A) #\b (integer->char #x202C) #\c))

;; Multi-line test data
(define multiline-simple '("First line" "Second line" "Third line"))
(define multiline-brackets '("Start (" "middle content" ") end"))
(define multiline-mixed '("English text" "עברית טקסט" "More English"))

;;; =================================================================
;;; COMPREHENSIVE TEXT ANALYSIS TESTS
;;; =================================================================

(test-group "analyze-bidi-text"
  ;; Test analysis of simple LTR text
  (test-assert "analyze simple LTR text"
    (let ([analysis (analyze-bidi-text simple-ltr)])
      (and (string=? (assoc-ref analysis 'text) simple-ltr)
           (= (assoc-ref analysis 'length) 11)
           (eq? (assoc-ref analysis 'base-direction) 'ltr)
           (list? (assoc-ref analysis 'character-classes))
           (list? (assoc-ref analysis 'resolved-levels))
           (list? (assoc-ref analysis 'bracket-pairs)))))
  
  ;; Test analysis of RTL text
  (test-assert "analyze RTL text"
    (let ([analysis (analyze-bidi-text simple-rtl)])
      (and (eq? (assoc-ref analysis 'base-direction) 'rtl)
           (> (assoc-ref analysis 'length) 0))))
  
  ;; Test analysis of mixed text
  (test-assert "analyze mixed LTR/RTL text"
    (let ([analysis (analyze-bidi-text simple-mixed)])
      (and (> (assoc-ref analysis 'length) 0)
           (not (every (lambda (level) (= level 0)) 
                       (assoc-ref analysis 'resolved-levels))))))
  
  ;; Test analysis with brackets
  (test-assert "analyze text with brackets"
    (let ([analysis (analyze-bidi-text complex-brackets)])
      (and (list? (assoc-ref analysis 'bracket-pairs))
           (>= (length (assoc-ref analysis 'bracket-pairs)) 0))))
  
  ;; Test analysis with bidi controls
  (test-assert "analyze text with bidi controls"
    (let ([analysis (analyze-bidi-text complex-controls)])
      (and (> (assoc-ref analysis 'length) 0)
           (list? (assoc-ref analysis 'character-classes)))))
  
  ;; Test bracket validation in analysis
  (test-assert "bracket validation in analysis"
    (let* ([analysis (analyze-bidi-text "a(b)c")]
           [validation (assoc-ref analysis 'bracket-validation)])
      (car validation)))  ; Should be valid
  
  ;; Test empty string analysis
  (test-assert "analyze empty string"
    (let ([analysis (analyze-bidi-text "")])
      (and (= (assoc-ref analysis 'length) 0)
           (eq? (assoc-ref analysis 'base-direction) 'ltr)))))

;;; =================================================================
;;; PRINT ANALYSIS TESTS
;;; =================================================================

(test-group "print-bidi-analysis"
  ;; Test that print functions don't crash and produce output
  (test-assert "print simple text analysis"
    (let ([output (with-output-to-string
                    (lambda () (print-bidi-analysis simple-ltr)))])
      (and (string? output)
           (> (string-length output) 0)
           (string-contains output "Bidirectional Text Analysis"))))
  
  (test-assert "print RTL text analysis"
    (let ([output (with-output-to-string
                    (lambda () (print-bidi-analysis simple-rtl)))])
      (and (string? output)
           (string-contains output "RTL"))))
  
  (test-assert "print text with brackets"
    (let ([output (with-output-to-string
                    (lambda () (print-bidi-analysis "a(b)c")))])
      (and (string? output)
           (string-contains output "Bracket pairs"))))
  
  (test-assert "print empty string analysis"
    (let ([output (with-output-to-string
                    (lambda () (print-bidi-analysis "")))])
      (and (string? output)
           (string-contains output "0 characters")))))

;;; =================================================================
;;; CHARACTER-LEVEL DEBUGGING TESTS
;;; =================================================================

(test-group "character-level-debugging"
  ;; Test character class analysis
  (test-assert "analyze character classes"
    (let ([analysis (analyze-character-classes simple-mixed)])
      (and (>= (assoc-ref analysis 'total-characters) 0)
           (>= (assoc-ref analysis 'unique-classes) 1)
           (list? (assoc-ref analysis 'class-distribution))
           (>= (assoc-ref analysis 'strong-characters) 0)
           (>= (assoc-ref analysis 'weak-characters) 0)
           (>= (assoc-ref analysis 'neutral-characters) 0)
           (>= (assoc-ref analysis 'control-characters) 0))))
  
  (test-assert "character class distribution"
    (let* ([analysis (analyze-character-classes "Hello שלום 123")]
           [distribution (assoc-ref analysis 'class-distribution)])
      (and (list? distribution)
           (> (length distribution) 0)
           (every (lambda (entry) 
                    (and (pair? entry) 
                         (integer? (cdr entry))
                         (> (cdr entry) 0))) 
                  distribution))))
  
  ;; Test character breakdown printing
  (test-assert "print character breakdown"
    (let ([output (with-output-to-string
                    (lambda () (print-character-breakdown "Hello")))])
      (and (string? output)
           (> (string-length output) 0)
           (string-contains output "Character Breakdown"))))
  
  (test-assert "character breakdown with RTL"
    (let ([output (with-output-to-string
                    (lambda () (print-character-breakdown simple-rtl)))])
      (and (string? output)
           (string-contains output "Right-to-Left"))))
  
  (test-assert "character breakdown with controls"
    (let ([output (with-output-to-string
                    (lambda () (print-character-breakdown complex-controls)))])
      (and (string? output)
           (string-contains output "U+"))))  ; Should show Unicode code points
  
  ;; Test bidi class descriptions
  (test-assert "bidi class descriptions exist"
    (let ([desc-l (get-bidi-class-description BC-L)]
          [desc-r (get-bidi-class-description BC-R)]
          [desc-unknown (get-bidi-class-description 'unknown-class)])
      (and (string? desc-l)
           (string? desc-r)
           (string? desc-unknown)
           (string=? desc-unknown "Unknown")))))

;;; =================================================================
;;; BRACKET-SPECIFIC DEBUGGING TESTS
;;; =================================================================

(test-group "bracket-debugging"
  ;; Test bracket pair analysis
  (test-assert "analyze bracket pairs"
    (let ([analysis (analyze-bracket-pairs "a(b[c]d)e")])
      (and (>= (assoc-ref analysis 'total-pairs) 0)
           (>= (assoc-ref analysis 'max-nesting-level) 0)
           (list? (assoc-ref analysis 'bracket-positions))
           (list? (assoc-ref analysis 'nesting-at-positions))
           (list? (assoc-ref analysis 'pair-details)))))
  
  (test-assert "bracket analysis with nested pairs"
    (let ([analysis (analyze-bracket-pairs "a(b[c{d}e]f)g")])
      (and (> (assoc-ref analysis 'total-pairs) 1)
           (> (assoc-ref analysis 'max-nesting-level) 1))))
  
  (test-assert "bracket analysis with no brackets"
    (let ([analysis (analyze-bracket-pairs "hello world")])
      (and (= (assoc-ref analysis 'total-pairs) 0)
           (= (assoc-ref analysis 'max-nesting-level) 0))))
  
  ;; Test bracket analysis printing
  (test-assert "print bracket analysis"
    (let ([output (with-output-to-string
                    (lambda () (print-bracket-analysis "a(b)c")))])
      (and (string? output)
           (> (string-length output) 0)
           (string-contains output "Bracket Analysis"))))
  
  (test-assert "print complex bracket analysis"
    (let ([output (with-output-to-string
                    (lambda () (print-bracket-analysis "a(b[c]d)e")))])
      (and (string? output)
           (string-contains output "Nesting levels"))))
  
  (test-assert "print bracket analysis with no brackets"
    (let ([output (with-output-to-string
                    (lambda () (print-bracket-analysis "no brackets here")))])
      (and (string? output)
           (string-contains output "(no brackets)")))))

;;; =================================================================
;;; EMBEDDING LEVEL ANALYSIS TESTS
;;; =================================================================

(test-group "embedding-level-analysis"
  ;; Test level analysis
  (test-assert "analyze embedding levels"
    (let ([analysis (analyze-embedding-levels simple-mixed)])
      (and (>= (assoc-ref analysis 'text-length) 0)
           (>= (assoc-ref analysis 'min-level) 0)
           (>= (assoc-ref analysis 'max-level) 0)
           (>= (assoc-ref analysis 'level-range) 0)
           (>= (assoc-ref analysis 'level-changes) 0)
           (list? (assoc-ref analysis 'level-distribution))
           (list? (assoc-ref analysis 'levels)))))
  
  (test-assert "level analysis with simple LTR"
    (let ([analysis (analyze-embedding-levels simple-ltr)])
      (and (= (assoc-ref analysis 'min-level) 0)
           (= (assoc-ref analysis 'max-level) 0)
           (= (assoc-ref analysis 'level-range) 0)
           (= (assoc-ref analysis 'level-changes) 0))))
  
  (test-assert "level analysis with bidi controls"
    (let ([analysis (analyze-embedding-levels complex-controls)])
      (and (>= (assoc-ref analysis 'max-level) 0)
           (>= (assoc-ref analysis 'level-changes) 0))))
  
  ;; Test level distribution counting
  (test-assert "level distribution is accurate"
    (let* ([analysis (analyze-embedding-levels "aaa")]
           [distribution (assoc-ref analysis 'level-distribution)]
           [total-chars (fold + 0 (map cdr distribution))])
      (= total-chars (assoc-ref analysis 'text-length))))
  
  ;; Test level analysis printing
  (test-assert "print level analysis"
    (let ([output (with-output-to-string
                    (lambda () (print-level-analysis simple-mixed)))])
      (and (string? output)
           (> (string-length output) 0)
           (string-contains output "Embedding Level Analysis"))))
  
  (test-assert "print level analysis with uniform levels"
    (let ([output (with-output-to-string
                    (lambda () (print-level-analysis "Hello")))])
      (and (string? output)
           (string-contains output "Level 0"))))
  
  (test-assert "print level analysis with changes"
    (let ([output (with-output-to-string
                    (lambda () (print-level-analysis simple-mixed)))])
      (and (string? output)
           (string-contains output "Level changes")))))

;;; =================================================================
;;; DOCUMENT-LEVEL ANALYSIS TESTS
;;; =================================================================

(test-group "document-analysis"
  ;; Test document structure analysis
  (test-assert "analyze document structure"
    (let ([analysis (analyze-document-structure multiline-simple)])
      (and (= (assoc-ref analysis 'total-lines) 3)
           (> (assoc-ref analysis 'total-characters) 0)
           (>= (assoc-ref analysis 'average-line-length) 0)
           (list? (assoc-ref analysis 'base-directions))
           (>= (assoc-ref analysis 'mixed-direction-lines) 0)
           (alist? (assoc-ref analysis 'bracket-analysis))
           (list? (assoc-ref analysis 'line-analyses)))))
  
  (test-assert "document analysis with mixed directions"
    (let ([analysis (analyze-document-structure multiline-mixed)])
      (and (= (assoc-ref analysis 'total-lines) 3)
           (> (assoc-ref analysis 'mixed-direction-lines) 0))))
  
  (test-assert "document analysis with brackets"
    (let ([analysis (analyze-document-structure multiline-brackets)])
      (let ([bracket-analysis (assoc-ref analysis 'bracket-analysis)])
        (and (>= (assoc-ref bracket-analysis 'total-pairs) 0)
             (>= (assoc-ref bracket-analysis 'multi-line-pairs) 0)))))
  
  (test-assert "empty document analysis"
    (let ([analysis (analyze-document-structure '())])
      (and (= (assoc-ref analysis 'total-lines) 0)
           (= (assoc-ref analysis 'total-characters) 0))))
  
  ;; Test document analysis printing
  (test-assert "print document analysis"
    (let ([output (with-output-to-string
                    (lambda () (print-document-analysis multiline-simple)))])
      (and (string? output)
           (> (string-length output) 0)
           (string-contains output "Document Analysis"))))
  
  (test-assert "print document analysis with brackets"
    (let ([output (with-output-to-string
                    (lambda () (print-document-analysis multiline-brackets)))])
      (and (string? output)
           (string-contains output "bracket summary"))))
  
  (test-assert "print document analysis with mixed directions"
    (let ([output (with-output-to-string
                    (lambda () (print-document-analysis multiline-mixed)))])
      (and (string? output)
           (string-contains output "Base direction by line"))))
  
  (test-assert "print empty document analysis"
    (let ([output (with-output-to-string
                    (lambda () (print-document-analysis '())))])
      (and (string? output)
           (string-contains output "Total lines: 0")))))

;;; =================================================================
;;; UTILITY FUNCTION TESTS
;;; =================================================================

(test-group "debug-utilities"
  ;; Test Unicode character formatting
  (test-assert "format Unicode character"
    (let ([formatted (format-unicode-char #\A)])
      (and (string? formatted)
           (string-contains formatted "A")
           (string-contains formatted "U+0041"))))
  
  (test-assert "format Unicode character with RTL"
    (let ([formatted (format-unicode-char #\א)])  ; Hebrew Alef
      (and (string? formatted)
           (string-contains formatted "U+"))))
  
  ;; Test bidi class formatting
  (test-assert "format bidi class"
    (let ([formatted (format-bidi-class BC-L)])
      (and (string? formatted)
           (string-contains formatted "BC-L")
           (string-contains formatted "Left-to-Right"))))
  
  (test-assert "format unknown bidi class"
    (let ([formatted (format-bidi-class 'unknown)])
      (and (string? formatted)
           (string-contains formatted "Unknown"))))
  
  ;; Test that all bidi class descriptions work
  (test-assert "all bidi class descriptions"
    (let ([classes '(BC-L BC-R BC-AL BC-EN BC-ES BC-ET BC-AN BC-CS BC-NSM BC-BN
                     BC-B BC-S BC-WS BC-ON BC-LRE BC-LRO BC-RLE BC-RLO BC-PDF
                     BC-LRI BC-RLI BC-FSI BC-PDI)])
      (every (lambda (class)
               (let ([desc (get-bidi-class-description class)])
                 (and (string? desc)
                      (> (string-length desc) 0)
                      (not (string=? desc "Unknown")))))
             classes))))

;;; =================================================================
;;; COMPREHENSIVE DEBUG OUTPUT TESTS
;;; =================================================================

(test-group "comprehensive-debug-output"
  ;; Test complete analysis pipeline
  (test-assert "complete analysis with all features"
    (let* ([text "English (עברית) 123"]
           [analysis (analyze-bidi-text text)]
           [char-analysis (analyze-character-classes text)]
           [bracket-analysis (analyze-bracket-pairs text)]
           [level-analysis (analyze-embedding-levels text)])
      (and analysis char-analysis bracket-analysis level-analysis)))
  
  ;; Test that all print functions work together
  (test-assert "all print functions work"
    (let ([text "Test (עברית) text"])
      (with-output-to-string
        (lambda ()
          (print-bidi-analysis text)
          (print-character-breakdown text)
          (print-bracket-analysis text)
          (print-level-analysis text)))
      #t))  ; Just test that it doesn't crash
  
  ;; Test document-level debugging
  (test-assert "document-level debugging"
    (let ([lines '("English text" "עברית (test)" "More text")])
      (with-output-to-string
        (lambda ()
          (print-document-analysis lines)))
      #t))  ; Just test that it doesn't crash
  
  ;; Test debugging with complex nested structures
  (test-assert "debug complex nested brackets"
    (let ([text "outer(inner[deep{very_deep}back]up)done"])
      (with-output-to-string
        (lambda ()
          (print-bracket-analysis text)
          (print-level-analysis text)))
      #t))
  
  ;; Test debugging with bidi controls
  (test-assert "debug text with bidi controls"
    (let ([text (string #\a (integer->char #x202A) #\b (integer->char #x202C) #\c)])
      (with-output-to-string
        (lambda ()
          (print-bidi-analysis text)
          (print-character-breakdown text)))
      #t)))

;;; =================================================================
;;; ERROR HANDLING AND EDGE CASES
;;; =================================================================

(test-group "debug-edge-cases"
  ;; Test debugging empty inputs
  (test-assert "debug empty string"
    (let ([analysis (analyze-bidi-text "")])
      (and (= (assoc-ref analysis 'length) 0)
           (null? (assoc-ref analysis 'bracket-pairs)))))
  
  (test-assert "debug empty document"
    (let ([analysis (analyze-document-structure '())])
      (= (assoc-ref analysis 'total-lines) 0)))
  
  ;; Test debugging single characters
  (test-assert "debug single character"
    (let ([analysis (analyze-bidi-text "A")])
      (and (= (assoc-ref analysis 'length) 1)
           (eq? (assoc-ref analysis 'base-direction) 'ltr))))
  
  (test-assert "debug single RTL character"
    (let ([analysis (analyze-bidi-text "א")])
      (and (= (assoc-ref analysis 'length) 1)
           (eq? (assoc-ref analysis 'base-direction) 'rtl))))
  
  ;; Test debugging very long strings
  (test-assert "debug long string"
    (let* ([long-string (make-string 1000 #\a)]
           [analysis (analyze-bidi-text long-string)])
      (= (assoc-ref analysis 'length) 1000)))
  
  ;; Test debugging strings with only neutrals
  (test-assert "debug only neutral characters"
    (let ([analysis (analyze-bidi-text "123 !@# 456")])
      (and (> (assoc-ref analysis 'length) 0)
           (eq? (assoc-ref analysis 'base-direction) 'ltr))))
  
  ;; Test debugging malformed bracket structures
  (test-assert "debug malformed brackets"
    (let ([analysis (analyze-bracket-pairs "((([{{{]]]))}")])
      (>= (assoc-ref analysis 'total-pairs) 0)))  ; Should not crash
  
  ;; Test debugging with mixed line endings
  (test-assert "debug mixed line endings"
    (let ([lines '("line1\r\n" "line2\n" "line3\r")])
      (let ([analysis (analyze-document-structure lines)])
        (= (assoc-ref analysis 'total-lines) 3))))
  
  ;; Test that debug functions handle invalid input gracefully
  (test-assert "debug functions handle edge cases"
    (and 
      ;; Character breakdown with empty string
      (string? (with-output-to-string 
                 (lambda () (print-character-breakdown ""))))
      ;; Bracket analysis with no brackets
      (string? (with-output-to-string 
                 (lambda () (print-bracket-analysis "no brackets"))))
      ;; Level analysis with uniform levels
      (string? (with-output-to-string 
                 (lambda () (print-level-analysis "aaaaa"))))
      ;; Document analysis with empty document
      (string? (with-output-to-string 
                 (lambda () (print-document-analysis '())))))))

;;; =================================================================
;;; INTEGRATION WITH OTHER MODULES TESTS
;;; =================================================================

(test-group "integration-with-modules"
  ;; Test that debug functions work with core module results
  (test-assert "debug core module results"
    (let* ([text "Hello World"]
           [levels (resolve-paragraph-bidi text)]
           [analysis (analyze-bidi-text text)])
      (= (length (assoc-ref analysis 'resolved-levels))
         (length levels))))
  
  ;; Test that debug functions work with bracket module results
  (test-assert "debug bracket module results"
    (let* ([text "a(b)c"]
           [pairs (find-all-bracket-pairs text)]
           [analysis (analyze-bracket-pairs text)])
      (= (assoc-ref analysis 'total-pairs)
         (length pairs))))
  
  ;; Test debugging multi-line bracket processing
  (test-assert "debug multi-line bracket processing"
    (let* ([lines '("start(" "middle" ")end")]
           [contexts (process-multiple-lines lines)]
           [doc-analysis (analyze-document-structure lines)])
      (and (= (length contexts) 3)
           (= (assoc-ref doc-analysis 'total-lines) 3))))
  
  ;; Test that debug output includes all relevant information
  (test-assert "debug output completeness"
    (let* ([text "English (עברית) test"]
           [output (with-output-to-string
                     (lambda () (print-bidi-analysis text)))])
      (and (string-contains output "base direction")
           (string-contains output "Character breakdown")
           (string-contains output "Bracket pairs")
           (string-contains output "level="))))
  
  ;; Test debugging with inherited bracket context
  (test-assert "debug with inherited brackets"
    (let* ([inherited (list (make-open-bracket #\( 0 0 0 0))]
           [text "test)"]
           [pairs (find-all-bracket-pairs text #:inherited-brackets inherited)]
           [analysis (analyze-bracket-pairs text)])
      (and (>= (length pairs) 0)
           (>= (assoc-ref analysis 'total-pairs) 0)))))

;;; Test suite cleanup
(test-end "gano-uax9-debug")

;; Local Variables:
;; eval: (put 'test-group 'scheme-indent-function 1)
;; eval: (put 'test-assert 'scheme-indent-function 1)
;; eval: (put 'let-values 'scheme-indent-function 1)
;; End:
