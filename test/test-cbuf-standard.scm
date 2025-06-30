;;; SRFI-64 Unit Tests for cbuf-standard module
;;; Tests for standard text editing operations with Unicode/grapheme support

(define-module (test cbuf-standard)
  #:use-module (srfi srfi-64)        ; Testing framework
  #:use-module (gano cbuf-core)      ; Core buffer functionality
  #:use-module (gano cbuf-basic)     ; Basic operations
  #:use-module (gano cbuf-standard)  ; Standard operations to test
  #:use-module (gano text-metrics)   ; Text metrics
  #:use-module (gano rendering)      ; SGR support
  #:use-module (srfi srfi-1)         ; List utilities
  #:use-module (ice-9 format))       ; String formatting

;;; =================================================================
;;; TEST SETUP AND UTILITIES
;;; =================================================================

(define (make-test-cbuf text)
  "Create a test buffer with given text"
  (make-cbuf #:initial-text text #:tab-size 4))

(define (cbuf-get-all-text cbuf)
  "Get all text from buffer as single string"
  (string-join (cbuf-text cbuf) "\n"))

(define (cbuf-get-cursor-info cbuf)
  "Get cursor position info for debugging"
  (list 'line (cbuf-line-cur cbuf)
        'x-data (cbuf-x-data cbuf)
        'x-cell (cbuf-x-cell cbuf)))

(define (cbuf-get-selection cbuf)
  "Get selection info for debugging"
  (if (cbuf-mark-set? cbuf)
      (list 'mark-line (cbuf-mark-line cbuf)
            'mark-x-data (cbuf-mark-x-data cbuf)
            'selection (cbuf-get-region-text cbuf))
      'no-selection))

;;; =================================================================
;;; NAVIGATION TESTS
;;; =================================================================

(test-begin "cbuf-standard")

(test-group "goto-line tests"
  (let ([cbuf (make-test-cbuf "line1\nline2\nline3")])
    (cbuf-goto-line! cbuf 1)
    (test-equal "goto-line position" 1 (cbuf-line-cur cbuf))
    (test-equal "goto-line x-position" 0 (cbuf-x-data cbuf))))

(test-group "page navigation tests"
  (let ([cbuf (make-test-cbuf (string-join (make-list 100 "test line") "\n"))])
    (set-cbuf-form-size! cbuf 20)  ; Set page size to 20
    (cbuf-goto-line! cbuf 50)
    
    (cbuf-page-up! cbuf)
    (test-equal "page-up position" 30 (cbuf-line-cur cbuf))
    
    (cbuf-page-down! cbuf)
    (test-equal "page-down position" 50 (cbuf-line-cur cbuf))))

(test-group "word navigation tests"
  (let ([cbuf (make-test-cbuf "hello world test")])
    (cbuf-forward-word! cbuf)
    (test-equal "forward-word position" 6 (cbuf-x-data cbuf))
    
    (cbuf-forward-word! cbuf)
    (test-equal "forward-word second" 12 (cbuf-x-data cbuf))
    
    (cbuf-backward-word! cbuf)
    (test-equal "backward-word position" 6 (cbuf-x-data cbuf))))


;;; =================================================================
;;; SELECTION TESTS
;;; =================================================================


(test-group "select-all tests"
  (let ([cbuf (make-test-cbuf "line1\nline2\nline3")])
    (cbuf-select-all! cbuf)
    (test-assert "select-all mark set" (cbuf-mark-set? cbuf))
    (test-equal "select-all text" "line1\nline2\nline3" (cbuf-get-region-text cbuf))))

(test-group "select-word tests"
  (let ([cbuf (make-test-cbuf "hello world test")])
    (cbuf-set-x! cbuf 7 'data) ; Position in "world"
    (cbuf-select-word! cbuf)
    (test-equal "select-word text" "world" (cbuf-get-region-text cbuf))))

(test-group "select-line tests"
  (let ([cbuf (make-test-cbuf "line1\nline2\nline3")])
    (cbuf-set-y! cbuf 1)
    (cbuf-select-line! cbuf)
    (test-equal "select-line text" "line2" (cbuf-get-region-text cbuf))))


;;; =================================================================
;;; CUT/COPY/PASTE TESTS
;;; =================================================================


(test-group "cut/copy line tests"
  (let ([cbuf (make-test-cbuf "line1\nline2\nline3")])
    (cbuf-set-y! cbuf 1)
    (cbuf-cut-line! cbuf)
    (test-equal "copy-line buffer" "line2\n" (car (cbuf-cut-buffer cbuf)))
    (test-equal "cut-line result" "line1\nline3" (cbuf-get-all-text cbuf))))

(test-group "cut/copy word tests"
  (let ([cbuf (make-test-cbuf "hello world test")])
    (cbuf-set-x! cbuf 6 'data) ; Start of "world"
    (cbuf-copy-word! cbuf)
    (test-equal "copy-word buffer" "world" (car (cbuf-cut-buffer cbuf)))
    
    (cbuf-cut-word! cbuf)
    (test-equal "cut-word result" "hello  test" (cbuf-get-all-text cbuf))))


;;; =================================================================
;;; DELETION TESTS
;;; =================================================================


(test-group "delete word tests"
  (let ([cbuf (make-test-cbuf "hello world test")])
    (cbuf-set-x! cbuf 0 'data)
    (cbuf-delete-word-forward! cbuf)
    (test-equal "delete-word-forward" " world test" (cbuf-get-all-text cbuf))
    
    (cbuf-set-x! cbuf 6 'data) ; After "world"
    (cbuf-delete-word-backward! cbuf)
    (test-equal "delete-word-backward" "  test" (cbuf-get-all-text cbuf))))

(test-group "delete to end/beginning tests"
  (let ([cbuf (make-test-cbuf "hello world")])
    (cbuf-set-x! cbuf 6 'data) ; After "hello "
    (cbuf-delete-to-end-of-line! cbuf)
    (test-equal "delete-to-end" "hello " (cbuf-get-all-text cbuf)))
    
  (let ([cbuf (make-test-cbuf "hello world")])
    (cbuf-set-x! cbuf 6 'data) ; After "hello "
    (cbuf-delete-to-beginning-of-line! cbuf)
    (test-equal "delete-to-beginning" "world" (cbuf-get-all-text cbuf))))


;;; =================================================================
;;; SEARCH TESTS
;;; =================================================================


(test-group "basic search tests"
  (let ([cbuf (make-test-cbuf "hello world hello test")])
    (test-assert "search-forward found" 
                 (cbuf-search-forward! cbuf "world"))
    (test-equal "search-forward position" 11 (cbuf-x-data cbuf))
    (test-equal "search-forward selection" "world" (cbuf-get-region-text cbuf))
    
    (test-assert "search-forward second match"
                 (cbuf-search-forward! cbuf "hello"))
    (test-equal "search-forward second position" 17 (cbuf-x-data cbuf))))

(test-group "case-insensitive search tests"
  (let ([cbuf (make-test-cbuf "Hello WORLD hello")])
    (test-assert "case-insensitive search"
                 (cbuf-search-forward! cbuf "world" #:case-insensitive? #t))
    (test-equal "case-insensitive position" 11 (cbuf-x-data cbuf))
    (test-equal "case-insensitive selection" "WORLD" (cbuf-get-region-text cbuf))))

(test-group "whole-word search tests"
  (let ([cbuf (make-test-cbuf "cat catch dog")])
    (cbuf-beginning-of-buffer! cbuf)
    (test-assert "whole-word search found"
                 (cbuf-search-forward! cbuf "cat" #:whole-word? #t))
    (test-equal "whole-word position" 3 (cbuf-x-data cbuf))
    
    ;; Should not find "cat" in "catch"
    (test-assert "whole-word search next"
                 (not (cbuf-search-forward! cbuf "cat" #:whole-word? #t)))))

(test-group "grapheme-aware search tests"
  (let ([cbuf (make-test-cbuf "José cafe José́ test")])  ; José vs José́ (with combining acute)
    (cbuf-beginning-of-buffer! cbuf)
    (test-assert "grapheme search exact match"
                 (cbuf-search-forward! cbuf "José"))
    (test-equal "grapheme search position" 4 (cbuf-x-data cbuf))
    
    ;; Should not match José́ when searching for José
    (test-assert "grapheme search no partial match"
		 (begin
		   (let ([ret (cbuf-search-forward! cbuf "José")])
		     (pk 'xdata (cbuf-x-data cbuf))
		     (pk 'matchtext (cbuf-get-region-text cbuf))
                     (not ret ))))))


;;; =================================================================
;;; SEARCH AND REPLACE TESTS
;;; =================================================================


(test-group "basic replace tests"
  (let ([cbuf (make-test-cbuf "hello world hello")])
    (cbuf-search-forward! cbuf "world")
    (test-assert "basic replace"
                 (cbuf-search-replace! cbuf "world" "universe"))
    (test-equal "basic replace result" "hello universe hello" (cbuf-get-all-text cbuf))))

(test-group "replace-all tests"
  (let ([cbuf (make-test-cbuf "hello world hello world")])
    (let ([count (cbuf-search-replace-all! cbuf "hello" "hi")])
      (test-equal "replace-all count" 2 count)
      (test-equal "replace-all result" "hi world hi world" (cbuf-get-all-text cbuf)))))

(test-group "case-preserving replace tests"
  (let ([cbuf (make-test-cbuf "Hello HELLO hello HeLLo")])
    (let ([count (cbuf-search-replace-all! cbuf "hello" "world" 
                                          #:case-insensitive? #t 
                                          #:preserve-case? #t)])
      (test-equal "case-preserve count" 4 count)
      (test-equal "case-preserve result" "World WORLD world WoRLd" (cbuf-get-all-text cbuf)))))

(test-group "grapheme-aware replace tests"
  (let ([cbuf (make-test-cbuf "José café José́ test")])  ; Mixed José and José́
    ;; Replace José with John (same grapheme count)
    (cbuf-search-forward! cbuf "José")
    (test-assert "grapheme replace exact" 
                 (cbuf-search-replace! cbuf "José" "John" #:preserve-case? #t))
    (test-equal "grapheme replace result" "John café José́ test" (cbuf-get-all-text cbuf))))


;;; =================================================================
;;; CODE OPERATIONS TESTS
;;; =================================================================


(test-group "comment tests"
  (cbuf-set-comment-string! "//")
  (let ([cbuf (make-test-cbuf "int x = 5;\nint y = 10;")])
    (cbuf-comment-line! cbuf)
    (test-equal "comment-line result" "// int x = 5;\nint y = 10;" (cbuf-get-all-text cbuf))
    
    (cbuf-beginning-of-line! cbuf)
    (cbuf-select-all! cbuf)
    (cbuf-comment-region! cbuf)
    (test-equal "comment-region result" "// // int x = 5;\n// int y = 10;" (cbuf-get-all-text cbuf))))

(test-group "line manipulation tests"
  (let ([cbuf (make-test-cbuf "line1\nline2\nline3")])
    (cbuf-set-y! cbuf 1)
    (cbuf-duplicate-line! cbuf)
    (test-equal "duplicate-line result" "line1\nline2\nline2\nline3" (cbuf-get-all-text cbuf)))
    
  (let ([cbuf (make-test-cbuf "line1\nline2\nline3")])
    (cbuf-set-y! cbuf 1)
    (cbuf-move-line-up! cbuf)
    (test-equal "move-line-up result" "line2\nline1\nline3" (cbuf-get-all-text cbuf)))
    
  (let ([cbuf (make-test-cbuf "line1\nline2\nline3")])
    (cbuf-set-y! cbuf 0)
    (cbuf-move-line-down! cbuf)
    (test-equal "move-line-down result" "line2\nline1\nline3" (cbuf-get-all-text cbuf))))


;;; =================================================================
;;; INDENTATION TESTS
;;; =================================================================


(test-group "indentation level tests"
  (let ([cbuf (make-test-cbuf "    hello\n        world\nno indent")])
    (cbuf-set-y! cbuf 0)
    (test-equal "get-indentation spaces" 4 (cbuf-get-current-line-indentation cbuf))
    (test-equal "get-indentation level" 1 (cbuf-get-indentation-level cbuf))
    
    (cbuf-set-y! cbuf 1)
    (test-equal "get-indentation spaces 2" 8 (cbuf-get-current-line-indentation cbuf))
    (test-equal "get-indentation level 2" 2 (cbuf-get-indentation-level cbuf))))

(test-group "indent/outdent tests"
  (let ([cbuf (make-test-cbuf "hello\n    world")])
    (cbuf-indent-line! cbuf)
    (test-equal "indent-line result" "    hello\n    world" (cbuf-get-all-text cbuf))
    
    (cbuf-set-y! cbuf 1)
    (cbuf-outdent-line! cbuf)
    (test-equal "outdent-line result" "    hello\nworld" (cbuf-get-all-text cbuf))))

(test-group "newline-and-indent tests"
  (let ([cbuf (make-test-cbuf "    hello")])
    (cbuf-end-of-line! cbuf)
    (cbuf-newline-and-indent! cbuf)
    (test-equal "newline-and-indent result" "    hello\n    " (cbuf-get-all-text cbuf))))


;;; =================================================================
;;; TEXT TRANSFORMATION TESTS
;;; =================================================================


(test-group "case transformation tests"
  (let ([cbuf (make-test-cbuf "Hello World")])
    (cbuf-select-all! cbuf)
    (cbuf-upcase-region! cbuf)
    (test-equal "upcase-region result" "HELLO WORLD" (cbuf-get-all-text cbuf)))
    
  (let ([cbuf (make-test-cbuf "Hello World")])
    (cbuf-select-all! cbuf)
    (cbuf-downcase-region! cbuf)
    (test-equal "downcase-region result" "hello world" (cbuf-get-all-text cbuf)))
    
  (let ([cbuf (make-test-cbuf "hello world")])
    (cbuf-select-all! cbuf)
    (cbuf-capitalize-region! cbuf)
    (test-equal "capitalize-region result" "Hello World" (cbuf-get-all-text cbuf))))

(test-group "whitespace cleanup tests"
  (let ([cbuf (make-test-cbuf "line1   \nline2\t\t\nline3")])
    (cbuf-delete-trailing-whitespace! cbuf)
    (test-equal "delete-trailing-whitespace result" "line1\nline2\nline3" (cbuf-get-all-text cbuf)))
    
  (let ([cbuf (make-test-cbuf "  hello world  ")])
    (cbuf-select-all! cbuf)
    (cbuf-trim-whitespace! cbuf)
    (test-equal "trim-whitespace result" "hello world" (cbuf-get-all-text cbuf))))


;;; =================================================================
;;; GRAPHEME UTILITY TESTS
;;; =================================================================


(test-group "grapheme counting tests"
  ;; Test the internal grapheme counting function
  (let ([test-count (lambda (str expected)
                      (test-equal (format #f "grapheme count ~s" str) 
                                 expected
                                 (count-graphemes str)))])
    (test-count "hello" 5)           ; Basic ASCII
    (test-count "José" 4)            ; Single accented character  
    (test-count "José́" 4)            ; Base + combining acute
    (test-count "👨‍💻" 1)              ; Complex emoji sequence
    (test-count "नमस्ते" 4)))         ; Devanagari script

(test-group "grapheme boundary tests"
  ;; Test grapheme cluster boundary detection
  (let ([test-text "José́ café"])  ; José́ has combining mark
    (test-equal "cluster end José́" 5 (find-grapheme-cluster-end test-text 0))
    (test-equal "cluster start é" 9 (find-grapheme-cluster-start test-text 10))))


;;; =================================================================
;;; INTEGRATION TESTS
;;; =================================================================


(test-group "complex editing scenario"
  (let ([cbuf (make-test-cbuf "The café has José working\nSecond line here")])
    ;; Multi-step editing scenario
    (cbuf-search-forward! cbuf "José")
    (cbuf-search-replace! cbuf "José" "Maria" #:preserve-case? #t)  
    (cbuf-search-forward! cbuf "café")
    (cbuf-select-word! cbuf)
    (cbuf-upcase-region! cbuf)
    (cbuf-end-of-line! cbuf)
    (cbuf-newline-and-indent! cbuf)
    (cbuf-insert-string! cbuf "Third line added")
    
    (test-equal "complex scenario result" 
                "The CAFÉ has Maria working\nSecond line here\nThird line added"
                (cbuf-get-all-text cbuf))))

(test-group "undo integration"
  (let ([cbuf (make-test-cbuf "original text")])
    (cbuf-select-all! cbuf)
    (cbuf-upcase-region! cbuf)
    (test-equal "before undo" "ORIGINAL TEXT" (cbuf-get-all-text cbuf))
    
    (cbuf-undo cbuf)
    (test-equal "after undo" "original text" (cbuf-get-all-text cbuf))))

(test-end "cbuf-standard")

;;; =================================================================
;;; RUN ALL TESTS
;;; =================================================================

(define (run-all-tests)
  "Run all cbuf-standard tests and display results"
  (test-runner-current (test-runner-simple))
  
  (format #t "~%=== Running cbuf-standard Tests ===~%")
  
  ;; Run all test groups - they will execute when loaded
  (let ([runner (test-runner-current)])
    (format #t "~%=== Test Results ===~%")
    ;; (format #t "Tests run: ~a~%" (test-runner-test-count runner))
    (format #t "Passes: ~a~%" (test-runner-pass-count runner))  
    (format #t "Failures: ~a~%" (test-runner-fail-count runner))
    (format #t "Errors: ~a~%" (test-runner-xfail-count runner))
    
    (if (= (test-runner-fail-count runner) 0)
        (format #t "~%✓ All tests passed!~%")
        (format #t "~%✗ Some tests failed!~%"))))

;; Auto-run tests when module is loaded
(run-all-tests)
