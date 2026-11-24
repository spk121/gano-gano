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
    
    ;; tab size 4: the tab is at cells 5-7, "w" at 8
    (cbuf-move-to-column! cbuf 6) ; inside the tab
    (test-equal "move-to-column tab" 5 (cbuf-x-data cbuf))
    (cbuf-move-to-column! cbuf 8)
    (test-equal "move-to-column after tab" 6 (cbuf-x-data cbuf))
    
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
    (test-equal "forward-sentence second" 26 (cbuf-x-data cbuf)) ; "I am fine."
    
    (cbuf-backward-sentence! cbuf)
    (test-equal "backward-sentence" 13 (cbuf-x-data cbuf))))

(test-group "international sentence terminators"
  (let ([cbuf (make-test-cbuf "Hello world。 This is Chinese period.")])
    (cbuf-forward-sentence! cbuf)
    (test-equal "chinese-period sentence" 13 (cbuf-x-data cbuf)))) ; "This"

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
    
    ;; columns 0-20 (limit-pos is the last column): 21 columns, so
    ;; "hello" gets 8 columns on each side
    (cbuf-center-line! cbuf)
    (test-equal "center-line result" "        hello" (cbuf-text-cur cbuf))))

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
    ;; tab size 4: "world" is at column 17, after stops at 12 and 16
    (test-equal "tabify-buffer" "\thello\t\t world" (cbuf-get-all-text cbuf))))

(test-group "untabify tests"
  (let ([cbuf (make-test-cbuf "\thello\tworld")])
    (cbuf-untabify-buffer! cbuf)
    ;; the second tab starts at column 9 and runs to 12
    (test-equal "untabify-buffer" "    hello   world" (cbuf-get-all-text cbuf))))

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

;;; =================================================================
;;; STRICT TESTS
;;; =================================================================

(test-begin "cbuf-extra-strict")

(define (buf text) (make-cbuf #:initial-text text #:tab-size 4))
(define (pos b) (list (cbuf-line-cur b) (cbuf-x-data b)))
(define (goto! b line x) (cbuf-set-y! b line) (cbuf-set-x! b x 'data))
(define (select! b l1 x1 l2 x2) (goto! b l1 x1) (cbuf-set-mark! b) (goto! b l2 x2))
(define (state b)
  (list (cbuf-text b) (pos b) (cbuf-modified? b) (cbuf-mark-set? b)
        (cbuf-mark-line b) (cbuf-mark-x-data b)))
(define bold (make-sgr #:intensity 'intensity-bold))
(define (bold? sgr) (eq? (sgr-intensity sgr) 'intensity-bold))
(define (line-bold b n) (map bold? (text-metrics-sgr-list (list-ref (cbuf-text-metrics b) n))))

(define-syntax-rule (round-trip name text setup op)
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
(define (presentation! b) (set-cbuf-limit-type! b 'presentation)
  (set-cbuf-home-pos! b 0) (set-cbuf-limit-pos! b 20))

(test-group "undo and redo of every modifying command"
  (round-trip "align indents" "  a\nb\n\tc" (lambda (b) (select! b 0 0 2 0)) cbuf-align-indents-in-region!)
  (round-trip "sort lines" "c\na\nb" (lambda (b) (select! b 0 0 2 0)) cbuf-sort-lines-in-region!)
  (round-trip "swap with previous line" "a\nb\nc" (lambda (b) (goto! b 2 0)) cbuf-swap-current-and-previous-line!)
  (round-trip "swap with following line" "a\nb\nc" (lambda (b) (goto! b 0 0)) cbuf-swap-current-and-following-line!)
  (round-trip "swap with previous grapheme" "abc" (lambda (b) (goto! b 0 1)) cbuf-swap-current-and-previous-grapheme!)
  (round-trip "swap with following grapheme" "abc" (lambda (b) (goto! b 0 1)) cbuf-swap-current-and-following-grapheme!)
  (round-trip "tabify buffer" "a\n        x\nb" (lambda (b) (goto! b 1 3)) cbuf-tabify-buffer!)
  (round-trip "untabify buffer" "\tx\ny\n\tz" none cbuf-untabify-buffer!)
  (round-trip "tabify region" "        x\n        y" (lambda (b) (select! b 0 0 1 0)) cbuf-tabify-lines-in-selected-region!)
  (round-trip "untabify region" "\tx\n\ty" (lambda (b) (select! b 0 0 1 0)) cbuf-untabify-lines-in-selected-region!)
  (round-trip "upcase" "ab\ncd" (lambda (b) (select! b 0 1 1 1)) cbuf-upcase-region!)
  (round-trip "downcase" "AB" (lambda (b) (select! b 0 0 0 2)) cbuf-downcase-region!)
  (round-trip "titlecase" "hello world" (lambda (b) (select! b 0 0 0 11)) cbuf-titlecase-region!)
  (round-trip "center line" "  hi  " presentation! cbuf-center-line!))

(test-group "#:undo? #f records nothing"
  (let ([b (buf "  b\na\n        x\n\ty")])
    (select! b 0 0 1 0)
    (cbuf-sort-lines-in-region! b #:undo? #f)
    (select! b 0 0 1 0)
    (cbuf-align-indents-in-region! b #:undo? #f)
    (goto! b 1 0)
    (cbuf-swap-current-and-following-line! b #:undo? #f)
    (cbuf-swap-current-and-previous-line! b #:undo? #f)
    (goto! b 0 1)
    (cbuf-swap-current-and-following-grapheme! b #:undo? #f)
    (cbuf-swap-current-and-previous-grapheme! b #:undo? #f)
    (cbuf-tabify-buffer! b #:undo? #f)
    (cbuf-untabify-buffer! b #:undo? #f)
    (select! b 0 0 0 2)
    (cbuf-upcase-region! b #:undo? #f)
    (test-assert "edits happened" (cbuf-modified? b))
    (test-equal "nothing recorded" 0 (cbuf-get-undo-count b))))

(test-group "no-op commands record nothing"
  (let ([b (buf "ABC\nx")])
    (select! b 0 0 0 3)
    (cbuf-upcase-region! b)
    (test-equal "upcasing upper case" 0 (cbuf-get-undo-count b))
    (cbuf-tabify-buffer! b)
    (test-equal "tabify without spaces" 0 (cbuf-get-undo-count b))
    (goto! b 0 3)
    (cbuf-swap-current-and-following-grapheme! b)
    (cbuf-swap-current-and-previous-grapheme! b)
    (test-equal "grapheme swaps at the line end" 0 (cbuf-get-undo-count b))
    (test-equal "text unchanged" '("ABC" "x") (cbuf-text b))))

(test-group "tab conversion"
  (let ([b (buf "a  b")])
    (cbuf-tabify-buffer! b)
    (test-equal "spaces that don't reach a stop stay" "a  b" (cbuf-text-cur b)))
  (let ([b (buf "abc d")])
    (cbuf-tabify-buffer! b)
    (test-equal "a single space is never a tab" "abc d" (cbuf-text-cur b)))
  (let ([b (buf "ab  cd")])
    (cbuf-tabify-buffer! b)
    (test-equal "two spaces ending at a stop" "ab\tcd" (cbuf-text-cur b)))
  (let ([b (buf "日   x")])            ; wide char: spaces from column 2
    (cbuf-tabify-buffer! b)
    (test-equal "columns count wide characters" "日\t x" (cbuf-text-cur b)))
  (let ([b (buf "日\tx")])
    (cbuf-untabify-buffer! b)
    (test-equal "untabify after a wide character" "日  x" (cbuf-text-cur b)))
  (let ([b (buf "a\x01\tb")])
    (cbuf-untabify-buffer! b)
    (test-equal "untabify after a control character" "a\x01  b" (cbuf-text-cur b)))
  (let* ([b (buf "  \tx")])
    (set-cbuf-current-sgr! b bold)
    (cbuf-untabify-buffer! b)
    (test-equal "untabified spaces" "    x" (cbuf-text-cur b)))
  (let ([b (make-cbuf #:initial-text "x" #:tab-size 4)])
    ;; SGR: spaces from a tab take the tab's attributes
    (set-cbuf-current-sgr! b bold)
    (cbuf-insert-char! b #\tab)
    (cbuf-untabify-buffer! b)
    (test-equal "tab's SGR copied to its spaces" '(#t #t #t #t #f) (line-bold b 0)))
  (let ([b (buf "a\nb\n        x\nc\nd")])
    (goto! b 4 1)
    (cbuf-tabify-buffer! b)
    (test-equal "cursor keeps its place" '(4 1) (pos b))
    (cbuf-undo b)
    (test-equal "undo" '("a" "b" "        x" "c" "d") (cbuf-text b))))

(test-group "case conversion"
  (let ([b (buf "ab cd")])
    (set-cbuf-cut-buffer! b '("keep"))
    (set-cbuf-current-sgr! b bold)
    (select! b 0 0 0 5)
    (cbuf-titlecase-region! b)
    (test-equal "titlecase" "Ab Cd" (cbuf-text-cur b))
    (test-equal "cut buffer untouched" '("keep") (cbuf-cut-buffer b))
    (test-assert "mark cleared" (not (cbuf-mark-set? b))))
  (let ([b (buf "xy")])
    (set-cbuf-current-sgr! b bold)
    (goto! b 0 0) (cbuf-insert-char! b #\a) (set-cbuf-current-sgr! b (make-default-sgr))
    (select! b 0 0 0 3)
    (cbuf-upcase-region! b)
    (test-equal "upcase keeps each character's attributes" '(#t #f #f) (line-bold b 0)))
  (test-equal "titlecase handles punctuation" "Don'T Stop-Now"
              (let ([b (buf "don't stop-now")]) (select! b 0 0 0 14) (cbuf-titlecase-region! b) (cbuf-text-cur b))))

(test-group "lines and graphemes"
  (let ([b (buf "a\nb\nc")])
    (goto! b 1 0)
    (cbuf-swap-current-and-previous-line! b)
    (test-equal "swap with previous" '("b" "a" "c") (cbuf-text b))
    (test-equal "cursor follows the line" '(0 0) (pos b))
    (cbuf-swap-current-and-previous-line! b)
    (test-equal "nothing above line 0" '("b" "a" "c") (cbuf-text b)))
  (let ([b (buf "éxy")])
    (goto! b 0 1)
    (cbuf-swap-current-and-previous-grapheme! b)
    (test-equal "swap keeps clusters whole" "xéy" (cbuf-text-cur b))
    (test-equal "cursor follows the cluster" '(0 0) (pos b))
    (goto! b 0 0)
    (cbuf-swap-current-and-following-grapheme! b)
    (test-equal "swap forward" "éxy" (cbuf-text-cur b))
    (test-equal "cursor follows forward" '(0 1) (pos b))))

(test-group "sorting"
  (let ([b (buf "b\n  a\nB\nc")])
    (goto! b 2 0) (cbuf-set-mark! b) (goto! b 0 1)
    (cbuf-sort-lines-in-region! b)
    (test-equal "sorted, ignoring case and leading space; stable" '("  a" "b" "B" "c") (cbuf-text b))
    (test-equal "cursor follows its line" '(1 1) (pos b))
    (test-assert "mark cleared" (not (cbuf-mark-set? b))))
  (let ([b (buf "x\nx\na")])
    (goto! b 1 0) (cbuf-set-mark! b) (goto! b 2 0)
    (cbuf-sort-lines-in-region! b)
    (test-equal "only the selected lines" '("x" "a" "x") (cbuf-text b))
    (test-equal "cursor finds its own line among equal ones" '(1 0) (pos b))))

(test-group "alignment"
  (let ([b (buf "\t a\nb\n    c")])
    (select! b 0 0 2 0)
    (cbuf-align-indents-in-region! b)
    (test-equal "every line gets the first line's indentation" '("\t a" "\t b" "\t c") (cbuf-text b)))
  (let ([b (buf "a\n\nb")])
    (select! b 0 0 2 0)
    (cbuf-align-indents-in-region! b)
    (test-equal "no indentation to copy" '("a" "" "b") (cbuf-text b))))

(test-group "centering"
  (let ([b (buf "hello")])
    (test-error "needs presentation positioning" #t (cbuf-center-line! b)))
  (let ([b (buf "  日本  ")])
    (presentation! b)
    (cbuf-center-line! b)
    (test-equal "wide characters count as two columns" "        日本" (cbuf-text-cur b)))
  (let ([b (buf (make-string 25 #\x))])
    (presentation! b)
    (cbuf-center-line! b)
    (test-equal "too wide: left alone" (make-string 25 #\x) (cbuf-text-cur b)))
  (let ([b (buf "   ")])
    (presentation! b)
    (cbuf-center-line! b)
    (test-equal "blank line is emptied" "" (cbuf-text-cur b))))

(test-group "column, word, sentence and paragraph movement"
  (let ([b (buf "a日b")])
    (cbuf-move-to-column! b 2)
    (test-equal "column inside a wide char" '(0 1) (pos b))
    (cbuf-move-to-column! b -5)
    (test-equal "negative column" '(0 0) (pos b))
    (cbuf-move-to-column! b 99)
    (test-equal "past the end" '(0 3) (pos b)))
  (let ([b (buf "one two")])
    (goto! b 0 5)
    (cbuf-beginning-of-word! b)
    (test-equal "beginning of word" '(0 4) (pos b))
    (cbuf-end-of-word! b)
    (test-equal "end of word" '(0 7) (pos b)))
  (let ([b (buf "日本. Next one.\nLast.")])
    ;; sentence starts on a line other than the cursor's, after wide chars
    (goto! b 1 0)
    (cbuf-backward-sentence! b)
    (test-equal "backward sentence onto a line with wide chars" '(0 4) (pos b))
    (cbuf-forward-sentence! b)
    (test-equal "forward sentence onto the next line" '(1 0) (pos b)))
  (let ([b (buf "日日日日 ok\n日. Two.")])
    (goto! b 0 0)
    (cbuf-forward-sentence! b)
    (test-equal "next sentence on another line, positions in that line's data" '(1 3) (pos b)))
  (let ([b (buf "Zero.\nOne. Two.")])
    (goto! b 1 5)
    (cbuf-backward-sentence! b)
    (test-equal "back from an intraline sentence to the line's first sentence" '(1 0) (pos b))
    (cbuf-backward-sentence! b)
    (test-equal "then to the previous line" '(0 0) (pos b)))
  (let ([b (buf "p1\np1\n\n\np2\n\np3")])
    (cbuf-forward-paragraph! b)
    (test-equal "next paragraph" 4 (cbuf-line-cur b))
    (cbuf-forward-paragraph! b)
    (test-equal "and the next" 6 (cbuf-line-cur b))
    (cbuf-backward-paragraph! b)
    (test-equal "back" 4 (cbuf-line-cur b))))

(test-group "selection"
  (let ([b (buf "a\nb\n\nc")])
    (goto! b 0 0)
    (cbuf-select-paragraph! b)
    (test-equal "paragraph without the blank line" "a\nb" (cbuf-get-region-text b)))
  (let ([b (buf "a\n\nlast")])
    (goto! b 1 0)
    (cbuf-select-paragraph! b)
    (test-equal "from a blank line: the following paragraph" "last" (cbuf-get-region-text b)))
  (let ([b (buf "x ,\n  word here")])
    (goto! b 0 1)
    (cbuf-select-word! b)
    (test-equal "from delimiters at line end: next line's first word" "word" (cbuf-get-region-text b)))
  (let ([b (buf "One. Two three.")])
    (goto! b 0 7)
    (cbuf-select-sentence! b)
    (test-equal "sentence" "Two three." (cbuf-get-region-text b))))

(test-end "cbuf-extra-strict")
