;;; SRFI-64 Unit Tests for cbuf-extra module
;;; Tests for advanced text editing operations

(define-module (test cbuf-extra)
  #:use-module (srfi srfi-64)        ; Testing framework
  #:use-module (gano cbuf-core)      ; Core buffer functionality
  #:use-module (gano cbuf-basic)     ; Basic operations
  #:use-module ((gano cbuf-standard)  ; Standard operations (superseded
                #:hide (cbuf-upcase-region! cbuf-downcase-region! cbuf-select-word!)) ; by cbuf-extra)
  #:use-module (gano cbuf-extra)     ; Extra operations to test
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

;;; =================================================================
;;; WORD NAVIGATION TESTS
;;; =================================================================

(test-begin "cbuf-extra-word-navigation")

(test-group "beginning-of-word tests"
  (let ([cbuf (make-test-cbuf "hello world test")])
    (cbuf-set-x! cbuf 7 'data) ; Position in "world"
    (cbuf-beginning-of-word! cbuf)
    (test-equal "beginning-of-word position" 6 (cbuf-x-data cbuf))
    
    ;; Already at beginning - should go to previous word
    (cbuf-beginning-of-word! cbuf)
    (test-equal "beginning-of-word previous" 0 (cbuf-x-data cbuf))))

(test-group "end-of-word tests"
  (let ([cbuf (make-test-cbuf "hello world test")])
    (cbuf-set-x! cbuf 2 'data) ; Position in "hello"
    (cbuf-end-of-word! cbuf)
    (test-equal "end-of-word position" 5 (cbuf-x-data cbuf))
    
    ;; Already at end - should go to next word end
    (cbuf-end-of-word! cbuf)
    (test-equal "end-of-word next" 11 (cbuf-x-data cbuf))))

(test-end "cbuf-extra-word-navigation")

;;; =================================================================
;;; COLUMN POSITIONING TESTS
;;; =================================================================

(test-begin "cbuf-extra-column-positioning")

(test-group "move-to-column tests"
  (let ([cbuf (make-test-cbuf "hello\tworld")])
    (cbuf-move-to-column! cbuf 0)
    (test-equal "move-to-column 0" 0 (cbuf-x-data cbuf))
    
    (cbuf-move-to-column! cbuf 8) ; Should be at tab
    (test-equal "move-to-column tab" 5 (cbuf-x-data cbuf))
    
    (cbuf-move-to-column! cbuf 99) ; Beyond line
    (test-equal "move-to-column beyond" (cbuf-text-cur-base-length cbuf) (cbuf-x-data cbuf))))

(test-end "cbuf-extra-column-positioning")

;;; =================================================================
;;; PARAGRAPH NAVIGATION TESTS
;;; =================================================================

(test-begin "cbuf-extra-paragraph-navigation")

(test-group "paragraph navigation tests"
  (let ([cbuf (make-test-cbuf "First paragraph\nstill first\n\nSecond paragraph\nstill second")])
    (cbuf-forward-paragraph! cbuf)
    (test-equal "forward-paragraph" 3 (cbuf-line-cur cbuf))
    
    (cbuf-backward-paragraph! cbuf)
    (test-equal "backward-paragraph" 0 (cbuf-line-cur cbuf))))

(test-end "cbuf-extra-paragraph-navigation")

;;; =================================================================
;;; SENTENCE NAVIGATION TESTS
;;; =================================================================

(test-begin "cbuf-extra-sentence-navigation")

(test-group "sentence navigation tests"
  (let ([cbuf (make-test-cbuf "Hello world. How are you? I am fine.")])
    (cbuf-forward-sentence! cbuf)
    (test-equal "forward-sentence position" 13 (cbuf-x-data cbuf))
    
    (cbuf-forward-sentence! cbuf)
    (test-equal "forward-sentence second" 27 (cbuf-x-data cbuf))
    
    (cbuf-backward-sentence! cbuf)
    (test-equal "backward-sentence" 13 (cbuf-x-data cbuf))))

(test-group "international sentence terminators"
  (let ([cbuf (make-test-cbuf "Hello world。 This is Chinese period.")])
    (cbuf-forward-sentence! cbuf)
    (test-equal "chinese-period sentence" 14 (cbuf-x-data cbuf))))

(test-end "cbuf-extra-sentence-navigation")

;;; =================================================================
;;; LINE FORMATTING TESTS
;;; =================================================================

(test-begin "cbuf-extra-line-formatting")

(test-group "center-line tests"
  (let ([cbuf (make-test-cbuf "  hello  ")])
    (set-cbuf-limit-type! cbuf 'presentation)
    (set-cbuf-home-pos! cbuf 0)
    (set-cbuf-limit-pos! cbuf 20)
    
    (cbuf-center-line! cbuf)
    (let ([text (cbuf-text-cur cbuf)])
      (test-assert "center-line result" (string-prefix? "       hello" text)))))

(test-end "cbuf-extra-line-formatting")

;;; =================================================================
;;; SMART SELECTION TESTS
;;; =================================================================

(test-begin "cbuf-extra-smart-selection")

(test-group "select-paragraph tests"
  (let ([cbuf (make-test-cbuf "Para 1\nstill 1\n\nPara 2\nstill 2")])
    (cbuf-set-y! cbuf 1) ; On "still 1"
    (cbuf-select-paragraph! cbuf)
    (test-equal "select-paragraph result" "Para 1\nstill 1" (cbuf-get-region-text cbuf))))

(test-group "select-word tests"
  (let ([cbuf (make-test-cbuf "hello, world test")])
    (cbuf-set-x! cbuf 7 'data) ; On "world"
    (cbuf-select-word! cbuf)
    (test-equal "select-word result" "world" (cbuf-get-region-text cbuf))
    
    ;; Test delimiter selection
    (cbuf-set-x! cbuf 5 'data) ; On comma
    (cbuf-select-word! cbuf)
    (test-equal "select-word delimiter" "world" (cbuf-get-region-text cbuf))))

(test-end "cbuf-extra-smart-selection")

;;; =================================================================
;;; CASE CONVERSION TESTS
;;; =================================================================

(test-begin "cbuf-extra-case-conversion")

(test-group "case conversion tests"
  (let ([cbuf (make-test-cbuf "Hello World")])
    (cbuf-select-all! cbuf)
    (cbuf-upcase-region! cbuf)
    (test-equal "upcase-region" "HELLO WORLD" (cbuf-get-all-text cbuf)))
  
  (let ([cbuf (make-test-cbuf "Hello World")])
    (cbuf-select-all! cbuf)
    (cbuf-downcase-region! cbuf)
    (test-equal "downcase-region" "hello world" (cbuf-get-all-text cbuf)))
  
  (let ([cbuf (make-test-cbuf "hello world")])
    (cbuf-select-all! cbuf)
    (cbuf-titlecase-region! cbuf)
    (test-equal "titlecase-region" "Hello World" (cbuf-get-all-text cbuf))))

(test-end "cbuf-extra-case-conversion")

;;; =================================================================
;;; TAB CONVERSION TESTS
;;; =================================================================

(test-begin "cbuf-extra-tab-conversion")

(test-group "tabify tests"
  (let ([cbuf (make-test-cbuf "    hello        world")])
    (cbuf-tabify-buffer! cbuf)
    (test-equal "tabify-buffer" "\thello\t\tworld" (cbuf-get-all-text cbuf))))

(test-group "untabify tests"
  (let ([cbuf (make-test-cbuf "\thello\tworld")])
    (cbuf-untabify-buffer! cbuf)
    (test-equal "untabify-buffer" "    hello    world" (cbuf-get-all-text cbuf))))

(test-end "cbuf-extra-tab-conversion")

;;; =================================================================
;;; SWAPPING TESTS
;;; =================================================================

(test-begin "cbuf-extra-swapping")

(test-group "line swapping tests"
  (let ([cbuf (make-test-cbuf "line1\nline2\nline3")])
    (cbuf-set-y! cbuf 1) ; On "line2"
    (cbuf-swap-current-and-previous-line! cbuf)
    (test-equal "swap-previous-line result" "line2\nline1\nline3" (cbuf-get-all-text cbuf))
    (test-equal "swap-previous-line cursor" 0 (cbuf-line-cur cbuf)))
  
  (let ([cbuf (make-test-cbuf "line1\nline2\nline3")])
    (cbuf-set-y! cbuf 1) ; On "line2"
    (cbuf-swap-current-and-following-line! cbuf)
    (test-equal "swap-following-line result" "line1\nline3\nline2" (cbuf-get-all-text cbuf))
    (test-equal "swap-following-line cursor" 2 (cbuf-line-cur cbuf))))

(test-group "grapheme swapping tests"
  (let ([cbuf (make-test-cbuf "hello")])
    (cbuf-set-x! cbuf 2 'data) ; On "l"
    (cbuf-swap-current-and-previous-grapheme! cbuf)
    (test-equal "swap-previous-grapheme" "hlelo" (cbuf-get-all-text cbuf))
    (test-equal "swap-previous-grapheme cursor" 1 (cbuf-x-data cbuf))))

(test-end "cbuf-extra-swapping")

;;; =================================================================
;;; SORTING TESTS
;;; =================================================================

(test-begin "cbuf-extra-sorting")

(test-group "sort-lines tests"
  (let ([cbuf (make-test-cbuf "zebra\napple\nbanana")])
    (cbuf-select-all! cbuf)
    (cbuf-sort-lines-in-region! cbuf)
    (test-equal "sort-lines-basic" "apple\nbanana\nzebra" (cbuf-get-all-text cbuf)))
  
  ;; Test whitespace ignoring
  (let ([cbuf (make-test-cbuf "  zebra\napple\n    banana")])
    (cbuf-select-all! cbuf)
    (cbuf-sort-lines-in-region! cbuf)
    (test-equal "sort-lines-whitespace" "apple\n    banana\n  zebra" (cbuf-get-all-text cbuf))))

(test-end "cbuf-extra-sorting")

;;; =================================================================
;;; INDENTATION ALIGNMENT TESTS
;;; =================================================================

(test-begin "cbuf-extra-indentation")

(test-group "align-indents tests"
  (let ([cbuf (make-test-cbuf "    first line\n  second line\n        third line")])
    (cbuf-select-all! cbuf)
    (cbuf-align-indents-in-region! cbuf)
    (test-equal "align-indents result" "    first line\n    second line\n    third line" (cbuf-get-all-text cbuf))))

(test-end "cbuf-extra-indentation")

;;; =================================================================
;;; INTEGRATION TESTS
;;; =================================================================

(test-begin "cbuf-extra-integration")

(test-group "complex operations"
  (let ([cbuf (make-test-cbuf "hello WORLD\ntest LINE")])
    ;; Select first line and titlecase it
    (cbuf-select-line! cbuf)
    (cbuf-titlecase-region! cbuf)
    (test-equal "integration-1" "Hello World\ntest LINE" (cbuf-get-all-text cbuf))
    
    ;; Move to second line and swap with first
    (cbuf-set-y! cbuf 1)
    (cbuf-swap-current-and-previous-line! cbuf)
    (test-equal "integration-2" "test LINE\nHello World" (cbuf-get-all-text cbuf))))

(test-end "cbuf-extra-integration")

