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


(test-group "complex editing scenario"
  (let ([cbuf (make-test-cbuf "The café has José working\nSecond line here")])
    ;; Multi-step editing scenario (searches don't wrap, so go back to
    ;; the top before looking for text earlier in the buffer)
    (cbuf-search-forward! cbuf "José")
    (cbuf-search-replace! cbuf "José" "Maria" #:preserve-case? #t)  
    (cbuf-beginning-of-buffer! cbuf)
    (cbuf-search-forward! cbuf "café")
    (cbuf-select-word! cbuf)
    (cbuf-upcase-region! cbuf)
    (cbuf-end-of-buffer! cbuf)
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

;;; =================================================================
;;; STRICT TESTS
;;; =================================================================

(define (buf text) (make-cbuf #:initial-text text))
(define (pos b) (list (cbuf-line-cur b) (cbuf-x-data b)))
(define (goto! b line x) (cbuf-set-y! b line) (cbuf-set-x! b x 'data))
(define (select! b l1 x1 l2 x2) (goto! b l1 x1) (cbuf-set-mark! b) (goto! b l2 x2))
(define (state b)
  (list (cbuf-text b) (pos b) (cbuf-modified? b) (cbuf-mark-set? b)
        (cbuf-mark-line b) (cbuf-mark-x-data b)))

(define-syntax-rule (round-trip name text setup op)
  ;; SETUP the buffer, run OP: one undo gives the state before OP, redo
  ;; the state after it, and undo again the state before.
  (let ([b (buf text)])
    (setup b)
    (let ([before (state b)] [count (cbuf-get-undo-count b)])
      (op b)
      (let ([after (state b)])
        (test-equal (string-append "one undo step: " name) (+ count 1) (cbuf-get-undo-count b))
        (cbuf-undo b)
        (test-equal (string-append "undo: " name) before (state b))
        (cbuf-redo! b)
        (test-equal (string-append "redo: " name) after (state b))
        (cbuf-undo b)
        (test-equal (string-append "undo again: " name) before (state b))))))

(define (none b) #t)

(test-group "strict: undo and redo of every modifying command"
  (round-trip "delete word forward" "one two three" (lambda (b) (goto! b 0 4)) cbuf-delete-word-forward!)
  (round-trip "delete word backward" "one two three" (lambda (b) (goto! b 0 6)) cbuf-delete-word-backward!)
  (round-trip "delete to end of line" "abc def" (lambda (b) (goto! b 0 3)) cbuf-delete-to-end-of-line!)
  (round-trip "delete to start of line" "abc def" (lambda (b) (goto! b 0 3)) cbuf-delete-to-beginning-of-line!)
  (round-trip "cut line" "a\nb\nc" (lambda (b) (goto! b 1 0)) cbuf-cut-line!)
  (round-trip "cut last line" "a\nb" (lambda (b) (goto! b 1 1)) cbuf-cut-line!)
  (round-trip "cut word" "one two" (lambda (b) (goto! b 0 5)) cbuf-cut-word!)
  (round-trip "paste previous" "x" (lambda (b) (set-cbuf-cut-buffer! b '("1" "2\n3"))) cbuf-paste-previous!)
  (round-trip "replace" "say hello" (lambda (b) (cbuf-search-forward! b "hello"))
              (lambda (b) (cbuf-search-replace! b "hello" "a\nb")))
  (round-trip "replace all" "aXa\nb\naa" none (lambda (b) (cbuf-search-replace-all! b "a" "<a>")))
  (round-trip "comment line" "code" none cbuf-comment-line!)
  (round-trip "comment region" "a\nb\nc" (lambda (b) (select! b 0 0 1 1)) cbuf-comment-region!)
  (round-trip "uncomment region" ";; a\n;;b\nc" (lambda (b) (select! b 0 0 2 0)) cbuf-uncomment-region!)
  (round-trip "duplicate line" "a\nb" (lambda (b) (goto! b 0 1)) cbuf-duplicate-line!)
  (round-trip "move line up" "a\nb\nc" (lambda (b) (goto! b 2 1)) cbuf-move-line-up!)
  (round-trip "move line down" "a\nb\nc" (lambda (b) (goto! b 0 1)) cbuf-move-line-down!)
  (round-trip "indent line" "x" none cbuf-indent-line!)
  (round-trip "indent region" "a\nb" (lambda (b) (select! b 0 0 1 0)) cbuf-indent-region!)
  (round-trip "outdent line" "    x" none cbuf-outdent-line!)
  (round-trip "outdent region" "    a\n\tb" (lambda (b) (select! b 0 0 1 0)) cbuf-outdent-region!)
  (round-trip "newline and indent" "  ab" (lambda (b) (goto! b 0 3)) cbuf-newline-and-indent!)
  (round-trip "upcase region" "ab\ncd" (lambda (b) (select! b 0 1 1 1)) cbuf-upcase-region!)
  (round-trip "downcase region" "AB" (lambda (b) (select! b 0 0 0 2)) cbuf-downcase-region!)
  (round-trip "capitalize region" "hello world" (lambda (b) (select! b 0 0 0 11)) cbuf-capitalize-region!)
  (round-trip "trim region" "  a  \n  b  " (lambda (b) (select! b 0 0 1 5)) cbuf-trim-whitespace!)
  (round-trip "delete trailing whitespace" "a \nb\nc\t\nd" (lambda (b) (goto! b 2 2))
              cbuf-delete-trailing-whitespace!))

(test-group "strict: #:undo? #f records nothing"
  (let ([b (buf "  one two\nthree\n;; four")])
    (goto! b 0 4)
    (cbuf-delete-word-forward! b #:undo? #f)
    (cbuf-move-line-down! b #:undo? #f)
    (cbuf-duplicate-line! b #:undo? #f)
    (cbuf-newline-and-indent! b #:undo? #f)
    (select! b 0 0 1 1)
    (cbuf-comment-region! b #:undo? #f)
    (cbuf-indent-region! b #:undo? #f)
    (cbuf-upcase-region! b #:undo? #f)
    (cbuf-search-replace-all! b "o" "0" #:undo? #f)
    (cbuf-delete-trailing-whitespace! b #:undo? #f)
    (test-assert "edits happened" (cbuf-modified? b))
    (test-equal "nothing recorded" 0 (cbuf-get-undo-count b))))

(test-group "strict: transformations leave the cut buffer alone"
  (let ([b (buf "Hello  ")])
    (set-cbuf-cut-buffer! b '("keep"))
    (select! b 0 0 0 7)
    (cbuf-upcase-region! b)
    (test-equal "upcase" "HELLO  " (cbuf-text-cur b))
    (select! b 0 0 0 7)
    (cbuf-trim-whitespace! b)
    (test-equal "trim" "HELLO" (cbuf-text-cur b))
    (test-equal "cut buffer untouched" '("keep") (cbuf-cut-buffer b))
    (test-assert "mark cleared" (not (cbuf-mark-set? b)))))

(test-group "strict: search"
  (let ([b (buf "say hi\nhi there hi\nnope")])
    (test-assert "forward finds a match followed by a space" (cbuf-search-forward! b "say"))
    (test-equal "selects it, cursor after" '((0 3) 0 0) (list (pos b) (cbuf-mark-line b) (cbuf-mark-x-data b)))
    (cbuf-search-forward! b "hi")
    (test-equal "next match on the same line" '(0 6) (pos b))
    (cbuf-search-forward! b "hi")
    (test-equal "then the next line" '(1 2) (pos b))
    (cbuf-search-forward! b "hi")
    (test-equal "repeating moves on" '(1 11) (pos b))
    (test-assert "no more matches" (not (cbuf-search-forward! b "hi")))
    (test-equal "cursor unchanged when not found" '(1 11) (pos b))
    (test-assert "backward" (cbuf-search-backward! b "hi"))
    (test-equal "backward: cursor at the start of the match" '(1 9) (pos b))
    (test-equal "with the mark after it" 11 (cbuf-mark-x-data b))
    (cbuf-search-backward! b "hi")
    (test-equal "repeating backward moves back" '(1 0) (pos b))
    (cbuf-search-backward! b "hi")
    (test-equal "to the previous line" '(0 4) (pos b))
    (test-assert "nothing before" (not (cbuf-search-backward! b "nope"))))
  (let ([b (buf "Hello hello")])
    (cbuf-search-forward! b "HELLO" #:case-insensitive? #t)
    (test-equal "case-insensitive" '(0 5) (pos b)))
  (let ([b (buf "cats cat")])
    (cbuf-search-forward! b "cat" #:whole-word? #t)
    (test-equal "whole word" '(0 8) (pos b)))
  (let ([b (buf "é e")])
    (cbuf-search-forward! b "e")
    (test-equal "never matches part of a cluster" '(0 3) (pos b))))

(test-group "strict: replace"
  (let ([b (buf "a b a")])
    (test-equal "replace needs a matching selection" #f (cbuf-search-replace! b "a" "x"))
    (cbuf-search-forward! b "a")
    (test-assert "replace the selected match" (cbuf-search-replace! b "a" "xyz"))
    (test-equal "replaced, not inserted" "xyz b a" (cbuf-text-cur b))
    (test-equal "cursor after the replacement" '(0 3) (pos b)))
  (let ([b (buf "Hello HELLO hello")])
    (test-equal "replace all returns the count" 3
                (cbuf-search-replace-all! b "hello" "world" #:case-insensitive? #t #:preserve-case? #t))
    (test-equal "preserving case" "World WORLD world" (cbuf-text-cur b)))
  (let ([b (buf "José JOSÉ")])
    (cbuf-search-replace-all! b "josé" "maria" #:case-insensitive? #t #:preserve-case? #t)
    (test-equal "different lengths: capitalised and all-caps kept" "Maria MARIA" (cbuf-text-cur b)))
  (let ([b (buf "aa")])
    (test-equal "replacement containing the pattern terminates" 2 (cbuf-search-replace-all! b "a" "aa"))
    (test-equal "text" "aaaa" (cbuf-text-cur b)))
  (let ([b (buf "x")])
    (test-equal "no matches: 0 and nothing recorded" '(0 0)
                (list (cbuf-search-replace-all! b "q" "z") (cbuf-get-undo-count b)))))

(test-group "strict: lines"
  (let ([b (buf "a\nb\nc")])
    (goto! b 1 1)
    (cbuf-move-line-up! b)
    (test-equal "move up" '("b" "a" "c") (cbuf-text b))
    (test-equal "cursor follows" '(0 1) (pos b))
    (cbuf-move-line-up! b)
    (test-equal "move up at top does nothing" '("b" "a" "c") (cbuf-text b))
    (goto! b 2 0)
    (cbuf-move-line-down! b)
    (test-equal "move down at bottom does nothing" '("b" "a" "c") (cbuf-text b)))
  (let ([b (buf "x\ny")])
    (cbuf-duplicate-line! b)
    (test-equal "duplicate" '("x" "x" "y") (cbuf-text b))
    (test-equal "cursor at the end of the copy" '(1 1) (pos b)))
  (let ([b (buf "a\nb\nc")])
    (goto! b 1 0)
    (cbuf-cut-line! b)
    (test-equal "cut line" '("a" "c") (cbuf-text b))
    (test-equal "cut buffer has the line and its ending" '("b\n") (cbuf-cut-buffer b))
    (cbuf-copy-line! b)
    (test-equal "copy line" '("c") (cbuf-cut-buffer b))))

(test-group "strict: words"
  (let ([b (buf "one two  three")])
    (cbuf-forward-word! b)
    (test-equal "forward word" '(0 4) (pos b))
    (cbuf-forward-word! b)
    (test-equal "forward word over extra spaces" '(0 9) (pos b))
    (goto! b 0 11)
    (cbuf-backward-word! b)
    (test-equal "backward word from inside a word: its start" '(0 9) (pos b))
    (cbuf-backward-word! b)
    (test-equal "backward word again: the previous word" '(0 4) (pos b)))
  (let ([b (buf "ab cd")])
    (goto! b 0 4)
    (cbuf-delete-word-backward! b)
    (test-equal "delete word backward deletes to the word's start" "ab d" (cbuf-text-cur b)))
  (let ([b (buf "end\nnext")])
    (goto! b 0 1)
    (cbuf-forward-word! b)
    (test-equal "forward from the last word goes to the next line" '(1 0) (pos b))
    (cbuf-backward-word! b)
    (test-equal "backward from a line start goes to the previous line end" '(0 3) (pos b))))

(test-group "strict: indentation"
  (let ([b (make-cbuf #:initial-text "\tx" #:tab-size 4)])
    (test-equal "tab counts to the tab stop" 4 (cbuf-get-current-line-indentation b))
    (cbuf-outdent-line! b)
    (test-equal "outdent removes one tab, not tab-size characters" "x" (cbuf-text-cur b)))
  (let ([b (make-cbuf #:initial-text "  \tx" #:tab-size 4)])
    (test-equal "spaces then tab" 4 (cbuf-get-current-line-indentation b))
    (test-equal "level" 1 (cbuf-get-indentation-level b)))
  (let ([b (make-cbuf #:initial-text "      x" #:tab-size 4)])
    (cbuf-outdent-line! b)
    (test-equal "outdent removes up to tab-size spaces" "  x" (cbuf-text-cur b))
    (cbuf-outdent-line! b)
    (test-equal "fewer spaces left" "x" (cbuf-text-cur b))
    (cbuf-outdent-line! b)
    (test-equal "nothing to remove" "x" (cbuf-text-cur b)))
  (let ([b (buf "  \tif x:")])
    (cbuf-end-of-line! b)
    (cbuf-newline-and-indent! b)
    (test-equal "new line copies the exact indentation" '("  \tif x:" "  \t") (cbuf-text b))
    (test-equal "cursor after it" '(1 3) (pos b)))
  (let ([b (buf "  ab")])
    (goto! b 0 1)
    (cbuf-newline-and-indent! b)
    (test-equal "only the indentation before the cursor" '(" " "  ab") (cbuf-text b))))

(test-group "strict: comments"
  (cbuf-set-comment-string! ";;")
  (let ([b (buf "a\n;; b\n;;c")])
    (select! b 0 0 2 0)
    (cbuf-uncomment-region! b)
    (test-equal "uncomment" '("a" "b" "c") (cbuf-text b))
    (select! b 0 0 1 0)
    (cbuf-comment-region! b)
    (test-equal "comment" '(";; a" ";; b" "c") (cbuf-text b)))
  (test-error "empty comment string" #t (cbuf-set-comment-string! ""))
  (cbuf-set-comment-string! "#")
  (let ([b (buf "x")])
    (cbuf-comment-line! b)
    (test-equal "custom comment string" "# x" (cbuf-text-cur b)))
  (cbuf-set-comment-string! ";;"))

(test-group "strict: trailing whitespace"
  (let ([b (buf "a  \nb\né \t")])
    (goto! b 0 3)
    (cbuf-delete-trailing-whitespace! b)
    (test-equal "trimmed" '("a" "b" "é") (cbuf-text b))
    (test-equal "cursor kept, clamped to its line" '(0 1) (pos b))))

(test-group "strict: navigation"
  (let ([b (make-cbuf #:initial-text (string-join (map number->string (iota 30)) "\n")
                      #:form-size 10)])
    (cbuf-page-down! b)
    (test-equal "page down" 10 (cbuf-line-cur b))
    (cbuf-page-down! b) (cbuf-page-down! b)
    (test-equal "page down clamps" 29 (cbuf-line-cur b))
    (cbuf-page-up! b)
    (test-equal "page up" 19 (cbuf-line-cur b))
    (cbuf-goto-line! b 5)
    (test-equal "goto line is 0-based" '(5 0) (pos b))
    (cbuf-goto-line! b 99)
    (test-equal "goto line clamps" 29 (cbuf-line-cur b))))

(test-end "cbuf-standard")
