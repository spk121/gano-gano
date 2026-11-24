;;; Test suite for cbuf-basic MVP operations
;;; Using SRFI-64 testing framework

(use-modules (srfi srfi-64)         ; Testing framework
             (gano cbuf-basic)      ; Module under test
             (gano cbuf-core)       ; Core functionality
             (srfi srfi-1)          ; List utilities
             (srfi srfi-13)         ; String utilities
             (gano text-metrics))   ; SGR lists

;;; Start test suite
(test-begin "cbuf-basic")

;;; =================================================================
;;; CHARACTER OPERATIONS TESTS
;;; =================================================================

(test-group "character-operations"

  (test-group "cbuf-insert-char!"
    (let ([cbuf (make-cbuf)])
      (cbuf-insert-char! cbuf #\a)
      (test-equal "insert single char" "a" (cbuf-text-cur cbuf))
      (test-equal "cursor moved forward" 1 (cbuf-x-data cbuf))
      (test-assert "buffer marked modified" (cbuf-modified? cbuf))

      (cbuf-insert-char! cbuf #\b)
      (test-equal "insert second char" "ab" (cbuf-text-cur cbuf))
      (test-equal "cursor at end" 2 (cbuf-x-data cbuf))))

  (test-group "cbuf-delete-char!"
    (let ([cbuf (make-cbuf #:initial-text "hello")])
      (cbuf-set-x! cbuf 1 'data)  ; Position at 'e'
      (cbuf-delete-char! cbuf)
      (test-equal "delete char" "hllo" (cbuf-text-cur cbuf))
      (test-equal "cursor position unchanged" 1 (cbuf-x-data cbuf))

      ;; Test at end of line
      (cbuf-set-x! cbuf 4 'data)  ; At end
      (cbuf-delete-char! cbuf)    ; Should not crash
      (test-equal "no delete at end" "hllo" (cbuf-text-cur cbuf))))

  (test-group "cbuf-backspace!"
    (let ([cbuf (make-cbuf #:initial-text "hello")])
      (cbuf-set-x! cbuf 2 'data)  ; Position after 'e'
      (cbuf-backspace! cbuf)
      (test-equal "backspace char" "hllo" (cbuf-text-cur cbuf))
      (test-equal "cursor moved back" 1 (cbuf-x-data cbuf))

      ;; Test at beginning of line
      (cbuf-set-x! cbuf 0 'data)
      (cbuf-backspace! cbuf)      ; Should not crash
      (test-equal "no backspace at beginning" "hllo" (cbuf-text-cur cbuf)))))

;;; =================================================================
;;; LINE OPERATIONS TESTS
;;; =================================================================

(test-group "line-operations"

  (test-group "cbuf-insert-newline!"
    (let ([cbuf (make-cbuf #:initial-text "hello")])
      (cbuf-set-x! cbuf 2 'data)  ; Position after 'e'
      (cbuf-insert-newline! cbuf)
      (test-equal "line count increased" 2 (cbuf-line-count cbuf))
      (test-equal "first line split" "he" (cbuf-get-line-text cbuf 0))
      (test-equal "second line content" "llo" (cbuf-get-line-text cbuf 1))
      (test-equal "cursor on new line" 1 (cbuf-line-cur cbuf))
      (test-equal "cursor at beginning" 0 (cbuf-x-data cbuf))))

  (test-group "cbuf-delete-line!"
    (let ([cbuf (make-cbuf #:initial-text "line1\nline2\nline3")])
      (cbuf-set-y! cbuf 1)  ; Position on second line
      (cbuf-delete-line! cbuf)
      (test-equal "line count decreased" 2 (cbuf-line-count cbuf))
      (test-equal "first line unchanged" "line1" (cbuf-get-line-text cbuf 0))
      (test-equal "third line moved up" "line3" (cbuf-get-line-text cbuf 1))

      ;; Test single line buffer (should not delete)
      (let ([single-cbuf (make-cbuf #:initial-text "only line")])
        (cbuf-delete-line! single-cbuf)
        (test-equal "single line not deleted" 1 (cbuf-line-count single-cbuf)))))

  (test-group "cbuf-join-lines!"
    (let ([cbuf (make-cbuf #:initial-text "first\nsecond")])
      (cbuf-join-lines! cbuf)  ; Join from first line
      (test-equal "lines joined" "firstsecond" (cbuf-text-cur cbuf))
      (test-equal "line count decreased" 1 (cbuf-line-count cbuf))

      ;; Test on last line (should not crash)
      (cbuf-join-lines! cbuf)
      (test-equal "no change on last line" "firstsecond" (cbuf-text-cur cbuf)))))

;;; =================================================================
;;; NAVIGATION OPERATIONS TESTS
;;; =================================================================

(test-group "navigation-operations"

  (test-group "character-navigation"
    (let ([cbuf (make-cbuf #:initial-text "hello")])
      (test-equal "initial position" 0 (cbuf-x-data cbuf))

      (cbuf-forward-char! cbuf)
      (test-equal "forward one char" 1 (cbuf-x-data cbuf))

      (cbuf-forward-char! cbuf)
      (test-equal "forward again" 2 (cbuf-x-data cbuf))

      (cbuf-backward-char! cbuf)
      (test-equal "backward one char" 1 (cbuf-x-data cbuf))

      ;; Test boundaries
      (cbuf-set-x! cbuf 5 'data)  ; At end
      (cbuf-forward-char! cbuf)   ; Should not move
      (test-equal "no move past end" 5 (cbuf-x-data cbuf))

      (cbuf-set-x! cbuf 0 'data)  ; At beginning
      (cbuf-backward-char! cbuf)  ; Should not move
      (test-equal "no move before beginning" 0 (cbuf-x-data cbuf))))

  (test-group "line-navigation"
    (let ([cbuf (make-cbuf #:initial-text "line1\nline2\nline3")])
      (test-equal "initial line" 0 (cbuf-line-cur cbuf))

      (cbuf-next-line! cbuf)
      (test-equal "next line" 1 (cbuf-line-cur cbuf))

      (cbuf-previous-line! cbuf)
      (test-equal "previous line" 0 (cbuf-line-cur cbuf))

      ;; Test boundaries
      (cbuf-set-y! cbuf 2)        ; Last line
      (cbuf-next-line! cbuf)      ; Should not move
      (test-equal "no move past last line" 2 (cbuf-line-cur cbuf))

      (cbuf-set-y! cbuf 0)        ; First line
      (cbuf-previous-line! cbuf)  ; Should not move
      (test-equal "no move before first line" 0 (cbuf-line-cur cbuf))))

  (test-group "line-boundary-navigation"
    (let ([cbuf (make-cbuf #:initial-text "hello world")])
      (cbuf-set-x! cbuf 5 'data)  ; Middle of line

      (cbuf-beginning-of-line! cbuf)
      (test-equal "beginning of line" 0 (cbuf-x-data cbuf))

      (cbuf-end-of-line! cbuf)
      (test-equal "end of line" 11 (cbuf-x-data cbuf))))

  (test-group "buffer-boundary-navigation"
    (let ([cbuf (make-cbuf #:initial-text "line1\nline2\nline3")])
      (cbuf-set-y! cbuf 1)        ; Middle line
      (cbuf-set-x! cbuf 2 'data)  ; Middle of line

      (cbuf-beginning-of-buffer! cbuf)
      (test-equal "beginning of buffer line" 0 (cbuf-line-cur cbuf))
      (test-equal "beginning of buffer column" 0 (cbuf-x-data cbuf))

      (cbuf-end-of-buffer! cbuf)
      (test-equal "end of buffer line" 2 (cbuf-line-cur cbuf))
      (test-equal "end of buffer column" 5 (cbuf-x-data cbuf)))))

;;; =================================================================
;;; STRING OPERATIONS TESTS
;;; =================================================================

(test-group "string-operations"

  (test-group "cbuf-insert-string!"
    (let ([cbuf (make-cbuf)])
      ;; Single line insertion
      (cbuf-insert-string! cbuf "hello")
      (test-equal "insert string" "hello" (cbuf-text-cur cbuf))
      (test-equal "cursor at end" 5 (cbuf-x-data cbuf))

      ;; Insert in middle
      (cbuf-set-x! cbuf 2 'data)
      (cbuf-insert-string! cbuf "XX")
      (test-equal "insert in middle" "heXXllo" (cbuf-text-cur cbuf))
      (test-equal "cursor after insertion" 4 (cbuf-x-data cbuf)))

    ;; Multi-line insertion
    (let ([cbuf (make-cbuf)])
      (cbuf-insert-string! cbuf "line1\nline2")
      (test-equal "multiline insertion line count" 2 (cbuf-line-count cbuf))
      (test-equal "first line after multiline" "line1" (cbuf-get-line-text cbuf 0))
      (test-equal "second line after multiline" "line2" (cbuf-get-line-text cbuf 1))))

  (test-group "cbuf-delete-region!"
    (let ([cbuf (make-cbuf #:initial-text "hello world")])
      ;; Single line deletion
      (cbuf-delete-region! cbuf 0 2 0 7)  ; Delete "llo wo"
      (test-equal "region deleted" "heorld" (cbuf-text-cur cbuf))
      (test-equal "cursor at deletion start" 2 (cbuf-x-data cbuf)))))

;;; =================================================================
;;; MARK/SELECTION OPERATIONS TESTS
;;; =================================================================

(test-group "mark-selection-operations"

  (test-group "cbuf-set-mark!"
    (let ([cbuf (make-cbuf #:initial-text "hello world")])
      (cbuf-set-x! cbuf 5 'data)
      (cbuf-set-mark! cbuf)

      (test-assert "mark is set" (cbuf-mark-set? cbuf))
      (test-equal "mark line position" 0 (cbuf-mark-line cbuf))
      (test-equal "mark data position" 5 (cbuf-mark-x-data cbuf))))

  (test-group "cbuf-exchange-point-and-mark!"
    (let ([cbuf (make-cbuf #:initial-text "hello world")])
      (cbuf-set-x! cbuf 5 'data)
      (cbuf-set-mark! cbuf)
      (cbuf-set-x! cbuf 8 'data)  ; Move cursor

      (cbuf-exchange-point-and-mark! cbuf)
      (test-equal "cursor moved to mark" 5 (cbuf-x-data cbuf))
      (test-equal "mark moved to old cursor" 8 (cbuf-mark-x-data cbuf))))

  (test-group "cbuf-get-region-text"
    (let ([cbuf (make-cbuf #:initial-text "hello world")])
      (cbuf-set-x! cbuf 2 'data)
      (cbuf-set-mark! cbuf)
      (cbuf-set-x! cbuf 7 'data)

      (test-equal "region text extracted" "llo w" (cbuf-get-region-text cbuf)))))

(test-group "enhanced-region-text"

  (test-group "single-line-selection"
    (let ([cbuf (make-cbuf #:initial-text "hello world")])
      (cbuf-set-x! cbuf 2 'data)
      (cbuf-set-mark! cbuf)
      (cbuf-set-x! cbuf 7 'data)

      (test-equal "single line region" "llo w" (cbuf-get-region-text cbuf))

      ;; Test reverse selection (mark after cursor)
      (cbuf-exchange-point-and-mark! cbuf)
      (test-equal "reverse selection same result" "llo w" (cbuf-get-region-text cbuf))))

  (test-group "multi-line-selection"
    (let ([cbuf (make-cbuf #:initial-text "first line\nsecond line\nthird line")])
      ;; Select from middle of first line to middle of third line
      (cbuf-set-x! cbuf 6 'data)  ; After "first "
      (cbuf-set-mark! cbuf)
      (cbuf-next-line! cbuf)
      (cbuf-next-line! cbuf)
      (cbuf-set-x! cbuf 5 'data)  ; After "third"

      (let ([region (cbuf-get-region-text cbuf)])
        (test-assert "multi-line region contains newlines"
                     (string-contains region "\n"))
        (test-assert "multi-line region starts correctly"
                     (string-prefix? "line" region))
        (test-assert "multi-line region includes middle line"
                     (string-contains region "second line"))
        (test-assert "multi-line region ends correctly"
                     (string-suffix? "third" region))))

    ;; Test complete line selection
    (let ([cbuf (make-cbuf #:initial-text "line1\nline2\nline3")])
      (cbuf-beginning-of-line! cbuf)
      (cbuf-set-mark! cbuf)
      (cbuf-next-line! cbuf)
      (cbuf-end-of-line! cbuf)

      (let ([region (cbuf-get-region-text cbuf)])
        (test-equal "complete line region" "line1\nline2" region))))

  (test-group "edge-case-selections"
    (let ([cbuf (make-cbuf #:initial-text "single")])
      ;; Empty selection
      (cbuf-set-x! cbuf 3 'data)
      (cbuf-set-mark! cbuf)
      (test-equal "empty selection" "" (cbuf-get-region-text cbuf))

      ;; No mark set
      (cbuf-clear-mark! cbuf)
      (test-equal "no mark set" "" (cbuf-get-region-text cbuf)))

    ;; Test with empty lines
    (let ([cbuf (make-cbuf #:initial-text "line1\n\nline3")])
      (cbuf-beginning-of-line! cbuf)
      (cbuf-set-mark! cbuf)
      (cbuf-end-of-buffer! cbuf)

      (let ([region (cbuf-get-region-text cbuf)])
        (test-equal "selection with empty line" "line1\n\nline3" region)))))

;;; =================================================================
;;; BUFFER OPERATIONS TESTS
;;; =================================================================

(test-group "buffer-operations"

  (test-group "cbuf-clear!"
    (let ([cbuf (make-cbuf #:initial-text "some content\nmore content")])
      (cbuf-clear! cbuf)
      (test-equal "buffer cleared line count" 1 (cbuf-line-count cbuf))
      (test-equal "buffer cleared content" "" (cbuf-text-cur cbuf))
      (test-equal "cursor reset line" 0 (cbuf-line-cur cbuf))
      (test-equal "cursor reset position" 0 (cbuf-x-data cbuf))
      (test-assert "mark cleared" (not (cbuf-mark-set? cbuf)))))

  (test-group "cbuf-load-from-string!"
    (let ([cbuf (make-cbuf #:initial-text "old content")])
      (cbuf-set-final-newline-policy! cbuf 'never-add)
      (cbuf-apply-final-newline-policy cbuf)
      (cbuf-load-from-string! cbuf "new\ncontent\nhere")
      (test-equal "new content line count" 3 (cbuf-line-count cbuf))
      (test-equal "new content first line" "new" (cbuf-get-line-text cbuf 0))
      (test-equal "new content second line" "content" (cbuf-get-line-text cbuf 1))
      (test-equal "new content third line" "here" (cbuf-get-line-text cbuf 2))
      (test-equal "cursor at beginning" 0 (cbuf-line-cur cbuf))
      (test-equal "cursor at start" 0 (cbuf-x-data cbuf))))

  (test-group "cbuf-save-to-string"
    (let ([cbuf (make-cbuf #:initial-text "line1\nline2\nline3")])
      (test-equal "save to string" "line1\nline2\nline3\n" (cbuf-save-to-string cbuf))))

  (test-group "round-trip-save-load"
    (let ([original-text "first line\nsecond line\nthird line"]
          [cbuf1 (make-cbuf)]
          [cbuf2 (make-cbuf)])

      ;; Load, save, and load again
      (cbuf-load-from-string! cbuf1 original-text)
      (let ([saved-text (cbuf-save-to-string cbuf1)])
        (cbuf-load-from-string! cbuf2 saved-text)
        (test-equal "round trip preserves content"
                    (cbuf-text cbuf1)
                    (cbuf-text cbuf2))))))

;;; =================================================================
;;; UNDO SYSTEM TESTS
;;; =================================================================

(test-group "undo-system"

  (test-group "basic-undo"
    (let ([cbuf (make-cbuf #:initial-text "hello")])
      (test-assert "can undo after modification"
                   (begin (cbuf-insert-char! cbuf #\!) (cbuf-can-undo? cbuf)))

      (cbuf-undo cbuf)
      (test-equal "undo restores content" "hello" (cbuf-text-cur cbuf))
      (test-equal "undo restores position" 0 (cbuf-x-data cbuf))))

  (test-group "multiple-operations-undo"
    (let ([cbuf (make-cbuf)])
      (cbuf-insert-char! cbuf #\a)
      (cbuf-insert-char! cbuf #\b)
      (cbuf-insert-char! cbuf #\c)

      (cbuf-undo cbuf)  ; Undo 'c'
      (test-equal "undo last char" "ab" (cbuf-text-cur cbuf))

      (cbuf-undo cbuf)  ; Undo 'b'
      (test-equal "undo second char" "a" (cbuf-text-cur cbuf))

      (cbuf-undo cbuf)  ; Undo 'a'
      (test-equal "undo first char" "" (cbuf-text-cur cbuf))))

  (test-group "line-operations-undo"
    (let ([cbuf (make-cbuf #:initial-text "single line")])
      (cbuf-set-x! cbuf 6 'data)
      (cbuf-insert-newline! cbuf)
      (test-equal "newline inserted" 2 (cbuf-line-count cbuf))

      (cbuf-undo cbuf)
      (test-equal "newline undone line count" 1 (cbuf-line-count cbuf))
      (test-equal "newline undone content" "single line" (cbuf-text-cur cbuf))
      (test-equal "newline undone position" 6 (cbuf-x-data cbuf)))))

;;; =================================================================
;;; INTEGRATION TESTS
;;; =================================================================

(test-group "integration"

  (test-group "editing-session"
    ;; Simulate a realistic editing session
    (let ([cbuf (make-cbuf)])
      ;; Type some text
      (cbuf-insert-string! cbuf "Hello")
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-string! cbuf "World")

      ;; Go back and edit
      (cbuf-previous-line! cbuf)
      (cbuf-end-of-line! cbuf)
      (cbuf-insert-char! cbuf #\!)

      ;; Check result
      (test-equal "editing session line 1" "Hello!" (cbuf-get-line-text cbuf 0))
      (test-equal "editing session line 2" "World" (cbuf-get-line-text cbuf 1))))

  (test-group "mark-and-edit"
    (let ([cbuf (make-cbuf #:initial-text "The quick brown fox")])
      ;; Set mark and select "quick"
      (cbuf-set-x! cbuf 4 'data)
      (cbuf-set-mark! cbuf)
      (cbuf-set-x! cbuf 9 'data)

      ;; Verify selection
      (test-equal "selected text" "quick" (cbuf-get-region-text cbuf))

      ;; Exchange point and mark
      (cbuf-exchange-point-and-mark! cbuf)
      (test-equal "exchanged position" 4 (cbuf-x-data cbuf)))))

;;; =================================================================
;;; ERROR HANDLING TESTS
;;; =================================================================

(test-group "error-handling"

  (test-group "boundary-conditions"
    (let ([cbuf (make-cbuf)])
      ;; Test operations on empty buffer
      (test-assert "delete on empty buffer doesn't crash"
                   (begin (cbuf-delete-char! cbuf) #t))
      (test-assert "backspace on empty buffer doesn't crash"
                   (begin (cbuf-backspace! cbuf) #t))
      (test-assert "join lines on single line doesn't crash"
                   (begin (cbuf-join-lines! cbuf) #t))))

  (test-group "position-validation"
    (let ([cbuf (make-cbuf #:initial-text "test")])
      ;; Test that operations handle invalid positions gracefully
      (cbuf-set-x! cbuf 100 'data)  ; Way past end
      (test-assert "large position gets clamped"
                   (<= (cbuf-x-data cbuf) (cbuf-text-cur-base-length cbuf))))))


;;; Expanded test suite for cbuf-basic.scm
;;; Add these test groups to your existing test suite

;;; =================================================================
;;; GRAPHEME-AWARE DELETION TESTS
;;; =================================================================

(test-group "grapheme-aware-deletion"

  (test-group "delete-combining-marks"
    (let ([cbuf (make-cbuf #:initial-text "a\u0301b\u0302c")])  ; á b̂ c
      (test-equal "initial text with combining marks" 3 (cbuf-text-cur-base-length cbuf))
      (test-equal "initial codepoint length" 5 (string-length (cbuf-text-cur cbuf)))

      ;; Delete first grapheme cluster (á)
      (cbuf-set-x! cbuf 0 'data)
      (cbuf-delete-char! cbuf)
      (test-equal "after deleting first cluster" "b\u0302c" (cbuf-text-cur cbuf))
      (test-equal "base length after deletion" 2 (cbuf-text-cur-base-length cbuf))
      (test-equal "cursor position after deletion" 0 (cbuf-x-data cbuf))))

  (test-group "backspace-combining-marks"
    (let ([cbuf (make-cbuf #:initial-text "a\u0301b\u0302c")])  ; á b̂ c
      ;; Position after second base character and backspace
      (cbuf-set-x! cbuf 2 'data)  ; After b̂
      (cbuf-backspace! cbuf)
      (test-equal "after backspacing cluster" "a\u0301c" (cbuf-text-cur cbuf))
      (test-equal "base length after backspace" 2 (cbuf-text-cur-base-length cbuf))
      (test-equal "cursor position after backspace" 1 (cbuf-x-data cbuf))))

  (test-group "deletion-boundaries"
    (let ([cbuf (make-cbuf #:initial-text "test")])
      ;; Test deletion at boundaries
      (cbuf-end-of-line! cbuf)
      (cbuf-delete-char! cbuf)  ; Should not crash
      (test-equal "delete at end of line" "test" (cbuf-text-cur cbuf))

      (cbuf-beginning-of-line! cbuf)
      (cbuf-backspace! cbuf)  ; Should not crash
      (test-equal "backspace at beginning of line" "test" (cbuf-text-cur cbuf)))))

;;; =================================================================
;;; ENHANCED VALIDATION TESTS
;;; =================================================================

(test-group "enhanced-validation"

  (test-group "combining-mark-validation"
    (let ([cbuf (make-cbuf)])
      ;; Test valid combining mark insertion
      (cbuf-insert-char! cbuf #\a)
      (cbuf-insert-char! cbuf #\x0301)  ; Should work
      (test-equal "valid combining mark insertion" "a\u0301" (cbuf-text-cur cbuf))

      ;; Test invalid combining mark at start
      (let ([cbuf2 (make-cbuf)])
        (test-assert "inserting combining mark at start should error"
                     (catch #t
                       (lambda () (cbuf-insert-char! cbuf2 #\x0301) #f)
                       (lambda (key . args) #t))))))

  (test-group "string-validation"
    (let ([cbuf (make-cbuf)])
      ;; Test valid string insertion
      (cbuf-insert-string! cbuf "hello")
      (test-equal "valid string insertion" "hello" (cbuf-text-cur cbuf))

      ;; Test string with valid combining marks
      (cbuf-clear! cbuf)
      (cbuf-insert-string! cbuf "caf\u0301")  ; café
      (test-equal "string with combining marks" "caf\u0301" (cbuf-text-cur cbuf)))))

;;; =================================================================
;;; WORD NAVIGATION TESTS
;;; =================================================================

#;(test-group "word-navigation"

  (test-group "forward-word"
    (let ([cbuf (make-cbuf #:initial-text "hello world test")])
      (cbuf-beginning-of-line! cbuf)

      (cbuf-forward-word! cbuf)
      (test-equal "forward to first word end" 5 (cbuf-x-data cbuf))

      (cbuf-forward-word! cbuf)
      (test-equal "forward to second word end" 11 (cbuf-x-data cbuf))

      (cbuf-forward-word! cbuf)
      (test-equal "forward to third word end" 16 (cbuf-x-data cbuf))))

  (test-group "backward-word"
    (let ([cbuf (make-cbuf #:initial-text "hello world test")])
      (cbuf-end-of-line! cbuf)

      (cbuf-backward-word! cbuf)
      (test-equal "backward to word beginning" 12 (cbuf-x-data cbuf))

      (cbuf-backward-word! cbuf)
      (test-equal "backward to second word beginning" 6 (cbuf-x-data cbuf))

      (cbuf-backward-word! cbuf)
      (test-equal "backward to first word beginning" 0 (cbuf-x-data cbuf))))

  (test-group "word-boundaries"
    (let ([cbuf (make-cbuf #:initial-text "word1,word2;word3")])
      (cbuf-beginning-of-line! cbuf)

      ;; Forward through punctuation-separated words
      (cbuf-forward-word! cbuf)
      (test-equal "forward past first word" 5 (cbuf-x-data cbuf))

      (cbuf-forward-word! cbuf)
      (test-equal "forward past punctuation" 11 (cbuf-x-data cbuf))

      (cbuf-forward-word! cbuf)
      (test-equal "forward to end" 17 (cbuf-x-data cbuf)))))

;;; =================================================================
;;; TAB HANDLING TESTS
;;; =================================================================

(test-group "tab-handling"

  (test-group "tab-insertion"
    (let ([cbuf (make-cbuf #:tab-size 4)])
      (cbuf-insert-string! cbuf "ab")
      (cbuf-handle-tab! cbuf)

      ;; Should insert 2 spaces to reach next tab stop (position 4)
      (test-equal "tab expands to spaces" "ab  " (cbuf-text-cur cbuf))
      (test-equal "cursor at tab stop" 4 (cbuf-x-cell cbuf))))

  (test-group "tab-alignment"
    (let ([cbuf (make-cbuf #:tab-size 8)])
      (cbuf-handle-tab! cbuf)  ; From position 0
      (test-equal "tab from start" 8 (cbuf-x-cell cbuf))

      (cbuf-insert-char! cbuf #\x)
      (cbuf-handle-tab! cbuf)  ; From position 9
      (test-equal "tab from middle" 16 (cbuf-x-cell cbuf)))))

;;; =================================================================
;;; ENHANCED POSITION MANAGEMENT TESTS
;;; =================================================================

(test-group "enhanced-position-management"

  (test-group "position-consistency"
    (let ([cbuf (make-cbuf #:initial-text "hello\tworld")])
      ;; Test that x-data, x-cell, and x-goal stay consistent
      (cbuf-set-x! cbuf 2 'data)
      (test-equal "x-data set correctly" 2 (cbuf-x-data cbuf))
      (test-equal "x-cell updated automatically" 2 (cbuf-x-cell cbuf))
      (test-equal "x-goal synchronized" 2 (cbuf-x-goal cbuf))

      ;; Move to tab character
      (cbuf-set-x! cbuf 5 'data)  ; On tab
      (test-equal "x-data on tab" 5 (cbuf-x-data cbuf))
      (test-equal "x-cell at tab start" 5 (cbuf-x-cell cbuf))))

  (test-group "goal-preservation"
    (let ([cbuf (make-cbuf #:initial-text "short\nvery long line\nshort")])
      ;; Set goal on long line
      (cbuf-next-line! cbuf)  ; Go to long line
      (cbuf-set-x! cbuf 10 'data)
      (let ([goal (cbuf-x-goal cbuf)])

        ;; Move to short line
        (cbuf-next-line! cbuf)
        (test-equal "goal preserved on short line" goal (cbuf-x-goal cbuf))

        ;; Move back to long line
        (cbuf-previous-line! cbuf)
        (test-equal "goal restored on long line" 10 (cbuf-x-data cbuf))))))

;;; =================================================================
;;; LINE ENDING DETECTION TESTS
;;; =================================================================

(test-group "line-ending-detection"

  (test-group "detect-different-endings"
    (let ([cbuf-unix (make-cbuf)]
          [cbuf-windows (make-cbuf)]
          [cbuf-mac (make-cbuf)])

      (cbuf-load-from-string! cbuf-unix "line1\nline2\nline3")
      (test-equal "Unix line ending detected" "\n" (cbuf-line-ending cbuf-unix))

      (cbuf-load-from-string! cbuf-windows "line1\r\nline2\r\nline3")
      (test-equal "Windows line ending detected" "\r\n" (cbuf-line-ending cbuf-windows))

      (cbuf-load-from-string! cbuf-mac "line1\rline2\rline3")
      (test-equal "Mac line ending detected" "\r" (cbuf-line-ending cbuf-mac))))

  (test-group "save-with-detected-ending"
    (let ([cbuf (make-cbuf)])
      (cbuf-load-from-string! cbuf "line1\r\nline2")
      (let ([saved (cbuf-save-to-string cbuf)])
        (test-assert "saved with correct line ending"
                     (string-contains saved "\r\n"))))))

;;; =================================================================
;;; MULTI-LINE OPERATIONS TESTS
;;; =================================================================

(test-group "multi-line-operations"

  (test-group "multi-line-insertion"
    (let ([cbuf (make-cbuf #:initial-text "line1")])
      (cbuf-end-of-line! cbuf)
      (cbuf-insert-string! cbuf "\nline2\nline3")

      (test-equal "multi-line insertion line count" 3 (cbuf-line-count cbuf))
      (test-equal "first line preserved" "line1" (cbuf-get-line-text cbuf 0))
      (test-equal "second line inserted" "line2" (cbuf-get-line-text cbuf 1))
      (test-equal "third line inserted" "line3" (cbuf-get-line-text cbuf 2))
      (test-equal "cursor on last line" 2 (cbuf-line-cur cbuf))))

  (test-group "complex-editing-session"
    ;; Simulate a realistic editing session
    (let ([cbuf (make-cbuf)])
      ;; Type a function
      (cbuf-insert-string! cbuf "(define (factorial n)")
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-string! cbuf "  (if (= n 0)")
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-string! cbuf "      1")
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-string! cbuf "      (* n (factorial (- n 1)))))")

      ;; Check structure
      (test-equal "function line count" 4 (cbuf-line-count cbuf))
      (test-assert "function content correct"
                   (string-contains (cbuf-get-line-text cbuf 0) "factorial"))

      ;; Edit the function
      (cbuf-set-y! cbuf 0)
      (cbuf-end-of-line! cbuf)
      (cbuf-backspace! cbuf)  ; Remove last paren
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-string! cbuf "  \"Calculate factorial of n\"")

      ;; Verify edit
      (test-equal "edited line count" 5 (cbuf-line-count cbuf))
      (test-assert "docstring inserted"
                   (string-contains (cbuf-get-line-text cbuf 1) "Calculate")))))

;;; =================================================================
;;; UNDO SYSTEM COMPREHENSIVE TESTS
;;; =================================================================

(test-group "comprehensive-undo"

(test-group "undo-complex-operations"
  (let ([cbuf (make-cbuf)])
    ;; Perform several operations
    (cbuf-insert-string! cbuf "first")
    (cbuf-insert-newline! cbuf)
    (cbuf-insert-string! cbuf "second")
    (cbuf-set-mark! cbuf)		; NOT undoable
    (cbuf-beginning-of-buffer! cbuf)	; NOT undoable

    ;; Verify state
    (test-equal "complex setup line count" 2 (cbuf-line-count cbuf))
    (test-assert "mark is set" (cbuf-mark-set? cbuf))

    ;; Undo and verify each step (only content changes)
    (cbuf-undo cbuf)			; Undo "second" insertion
    (test-equal "after undo string insertion" 2 (cbuf-line-count cbuf))
    (test-equal "cursor on second line after string undo" 1 (cbuf-line-cur cbuf))
    (test-equal "second line now empty" "" (cbuf-text-cur cbuf))

    (cbuf-undo cbuf)			; Undo newline
    (test-equal "newline undone" 1 (cbuf-line-count cbuf))
    (test-equal "content after newline undo" "first" (cbuf-text-cur cbuf))

    (cbuf-undo cbuf)			; Undo "first" insertion
    (test-equal "back to empty buffer" "" (cbuf-text-cur cbuf))))

  (test-group "undo-grouping-behavior"
    ;; Test that individual character insertions are separate undo operations
    (let ([cbuf (make-cbuf)])
      (cbuf-insert-char! cbuf #\a)
      (cbuf-insert-char! cbuf #\b)
      (cbuf-insert-char! cbuf #\c)

      (cbuf-undo cbuf)
      (test-equal "undo single char" "ab" (cbuf-text-cur cbuf))

      (cbuf-undo cbuf)
      (test-equal "undo another char" "a" (cbuf-text-cur cbuf))

      (cbuf-undo cbuf)
      (test-equal "undo final char" "" (cbuf-text-cur cbuf)))))

;;; =================================================================
;;; ERROR HANDLING AND BOUNDARY TESTS
;;; =================================================================

(test-group "enhanced-error-handling"

  (test-group "combining-mark-errors"
    (let ([cbuf (make-cbuf)])
      ;; Test combining mark without base
      (test-assert "combining mark at start raises error"
                   (catch #t
                     (lambda () (cbuf-insert-char! cbuf #\x0301) #f)
                     (lambda (key . args) #t)))

      ;; Test too many combining marks
      (cbuf-insert-char! cbuf #\a)
      (cbuf-insert-char! cbuf #\x0301)
      (cbuf-insert-char! cbuf #\x0302)
      (cbuf-insert-char! cbuf #\x0303)
      (cbuf-insert-char! cbuf #\x0304)  ; 4 combining marks - at limit

      ;; Fifth should fail
      (test-assert "too many combining marks raises error"
                   (catch #t
                     (lambda () (cbuf-insert-char! cbuf #\x0305) #f)
                     (lambda (key . args) #t)))))

  (test-group "boundary-validation"
    (let ([cbuf (make-cbuf #:initial-text "test")])
      ;; Test all boundary conditions
      (cbuf-beginning-of-buffer! cbuf)
      (test-equal "at beginning" 0 (cbuf-x-data cbuf))

      (cbuf-end-of-buffer! cbuf)
      (test-equal "at end" 4 (cbuf-x-data cbuf))

      ;; Operations at boundaries should be safe
      (cbuf-beginning-of-buffer! cbuf)
      (cbuf-backward-char! cbuf)  ; Should not move
      (test-equal "backward at start" 0 (cbuf-x-data cbuf))

      (cbuf-end-of-buffer! cbuf)
      (cbuf-forward-char! cbuf)  ; Should not move
      (test-equal "forward at end" 4 (cbuf-x-data cbuf)))))

;;; =================================================================
;;; NEW MVP CLIPBOARD OPERATIONS TESTS
;;; =================================================================

(test-group "mvp-clipboard-operations"

  (test-group "cbuf-clear-mark!"
    (let ([cbuf (make-cbuf #:initial-text "hello world")])
      (cbuf-set-x! cbuf 5 'data)
      (cbuf-set-mark! cbuf)
      (test-assert "mark is set initially" (cbuf-mark-set? cbuf))

      (cbuf-clear-mark! cbuf)
      (test-assert "mark is cleared" (not (cbuf-mark-set? cbuf)))
      (test-equal "mark line reset" 0 (cbuf-mark-line cbuf))
      (test-equal "mark position reset" 0 (cbuf-mark-x-data cbuf))))

  (test-group "cbuf-copy-region!"
    (let ([cbuf (make-cbuf #:initial-text "hello world")])
      ;; Test copy with selection
      (cbuf-set-x! cbuf 2 'data)
      (cbuf-set-mark! cbuf)
      (cbuf-set-x! cbuf 7 'data)

      (cbuf-copy-region! cbuf)
      (test-equal "text copied to kill buffer" '("llo w") (cbuf-cut-buffer cbuf))
      (test-assert "mark still active after copy" (cbuf-mark-set? cbuf))
      (test-equal "original text unchanged" "hello world" (cbuf-text-cur cbuf))

      ;; Test copy with no selection
      (cbuf-clear-mark! cbuf)
      (set-cbuf-cut-buffer! cbuf '())  ; Clear buffer
      (cbuf-copy-region! cbuf)
      (test-equal "no copy without selection" '() (cbuf-cut-buffer cbuf)))

    ;; Test multi-line copy
    (let ([cbuf (make-cbuf #:initial-text "line1\nline2\nline3")])
      (cbuf-set-x! cbuf 2 'data)  ; Middle of line1
      (cbuf-set-mark! cbuf)
      (cbuf-next-line! cbuf)
      (cbuf-next-line! cbuf)
      (cbuf-set-x! cbuf 3 'data)  ; Middle of line3

      (cbuf-copy-region! cbuf)
      (let ([copied (car (cbuf-cut-buffer cbuf))])
        (test-assert "multi-line copy includes newlines"
                     (string-contains copied "\n"))
        (test-assert "multi-line copy starts correctly"
                     (string-prefix? "ne1" copied))
        (test-assert "multi-line copy ends correctly"
                     (string-suffix? "lin" copied)))))

  (test-group "cbuf-cut-region!"
    (let ([cbuf (make-cbuf #:initial-text "hello world")])
      ;; Test cut with selection
      (cbuf-set-x! cbuf 2 'data)
      (cbuf-set-mark! cbuf)
      (cbuf-set-x! cbuf 7 'data)

      (cbuf-cut-region! cbuf)
      (test-equal "text cut to kill buffer" '("llo w") (cbuf-cut-buffer cbuf))
      (test-assert "mark cleared after cut" (not (cbuf-mark-set? cbuf)))
      (test-equal "text removed from buffer" "heorld" (cbuf-text-cur cbuf))
      (test-equal "cursor at cut start" 2 (cbuf-x-data cbuf))

      ;; Test cut with no selection
      (let ([cbuf2 (make-cbuf #:initial-text "test")])
        (set-cbuf-cut-buffer! cbuf2 '())
        (cbuf-cut-region! cbuf2)
        (test-equal "no cut without selection" '() (cbuf-cut-buffer cbuf2))
        (test-equal "text unchanged without selection" "test" (cbuf-text-cur cbuf2))))

    ;; Test multi-line cut
    (let ([cbuf (make-cbuf #:initial-text "line1\nline2\nline3")])
      (cbuf-set-x! cbuf 2 'data)  ; Middle of line1
      (cbuf-set-mark! cbuf)
      (cbuf-next-line! cbuf)
      (cbuf-next-line! cbuf)
      (cbuf-set-x! cbuf 3 'data)  ; Middle of line3

      (cbuf-cut-region! cbuf)
      (test-equal "multi-line cut reduces line count" 1 (cbuf-line-count cbuf))
      (test-equal "multi-line cut result" "lie3" (cbuf-text-cur cbuf))
      (test-equal "cursor positioned correctly" 2 (cbuf-x-data cbuf))))

  (test-group "cbuf-paste!"
    (let ([cbuf (make-cbuf #:initial-text "hello world")])
      ;; Set up kill buffer
      (set-cbuf-cut-buffer! cbuf '("PASTE"))

      (cbuf-set-x! cbuf 5 'data)  ; Between hello and world
      (cbuf-paste! cbuf)
      (test-equal "text pasted" "helloPASTE world" (cbuf-text-cur cbuf))
      (test-equal "cursor after paste" 10 (cbuf-x-data cbuf))

      ;; Test paste with active mark (should clear mark)
      (cbuf-set-mark! cbuf)
      (cbuf-paste! cbuf)
      (test-assert "mark cleared after paste" (not (cbuf-mark-set? cbuf)))

      ;; Test paste with empty kill buffer
      (let ([cbuf2 (make-cbuf #:initial-text "test")])
        (set-cbuf-cut-buffer! cbuf2 '())
        (cbuf-paste! cbuf2)
        (test-equal "no paste with empty buffer" "test" (cbuf-text-cur cbuf2)))

      ;; Test paste with empty string in kill buffer
      (let ([cbuf3 (make-cbuf #:initial-text "test")])
        (set-cbuf-cut-buffer! cbuf3 '(""))
        (cbuf-paste! cbuf3)
        (test-equal "no paste with empty string" "test" (cbuf-text-cur cbuf3))))

    ;; Test multi-line paste
    (let ([cbuf (make-cbuf #:initial-text "start")])
      (set-cbuf-cut-buffer! cbuf '("line1\nline2"))
      (cbuf-end-of-line! cbuf)
      (cbuf-paste! cbuf)

      (test-equal "multi-line paste line count" 2 (cbuf-line-count cbuf))
      (test-equal "multi-line paste first line" "startline1" (cbuf-get-line-text cbuf 0))
      (test-equal "multi-line paste second line" "line2" (cbuf-get-line-text cbuf 1))))

  (test-group "clipboard-integration-workflow"
    ;; Test realistic copy/cut/paste workflow
    (let ([cbuf (make-cbuf #:initial-text "The quick brown fox")])
      ;; Copy "quick"
      (cbuf-set-x! cbuf 4 'data)
      (cbuf-set-mark! cbuf)
      (cbuf-set-x! cbuf 9 'data)
      (cbuf-copy-region! cbuf)

      ;; Go to end and paste
      (cbuf-end-of-line! cbuf)
      (cbuf-paste! cbuf)
      (test-equal "copy-paste workflow" "The quick brown foxquick" (cbuf-text-cur cbuf))

      ;; Select "brown" and cut
      (cbuf-set-x! cbuf 10 'data)
      (cbuf-set-mark! cbuf)
      (cbuf-set-x! cbuf 15 'data)
      (cbuf-cut-region! cbuf)
      (test-equal "after cut in workflow" "The quick  foxquick" (cbuf-text-cur cbuf))

      ;; Paste "brown" at beginning
      (cbuf-beginning-of-line! cbuf)
      (cbuf-paste! cbuf)
      (test-equal "final workflow result" "brownThe quick  foxquick" (cbuf-text-cur cbuf)))))

;;; =================================================================
;;; PERFORMANCE AND STRESS TESTS
;;; =================================================================

(test-group "performance-tests"

  (test-group "large-document-handling"
    ;; Test with a reasonably large document
    (let* ([large-lines (map (lambda (i) (format #f "Line ~a with content here" i))
                            (iota 200))]
           [large-text (string-join large-lines "\n")]
           [cbuf (make-cbuf)])

      (cbuf-load-from-string! cbuf large-text)
      (cbuf-set-final-newline-policy! cbuf 'never-add)
      (cbuf-apply-final-newline-policy cbuf)
      (test-equal "large document loaded" 200 (cbuf-line-count cbuf))

      ;; Test navigation performance
      (cbuf-end-of-buffer! cbuf)
      (test-equal "navigated to end" 199 (cbuf-line-cur cbuf))

      ;; Test editing in large document
      (cbuf-beginning-of-buffer! cbuf)
      (cbuf-next-line! cbuf)
      (cbuf-next-line! cbuf)  ; Line 2
      (cbuf-end-of-line! cbuf)
      (cbuf-insert-string! cbuf " MODIFIED")

      (test-assert "edit in large document"
                   (string-contains (cbuf-text-cur cbuf) "MODIFIED"))))

  (test-group "many-operations"
    ;; Test many consecutive operations
    (let ([cbuf (make-cbuf)])
      ;; Insert many characters
      (let loop ([i 100])
        (when (> i 0)
          (cbuf-insert-char! cbuf #\x)
          (loop (- i 1))))

      (test-equal "many insertions" 100 (cbuf-text-cur-length cbuf))

      ;; Undo them all
      (let loop ([i 100])
        (when (and (> i 0) (cbuf-can-undo? cbuf))
          (cbuf-undo cbuf)
          (loop (- i 1))))

      (test-equal "many undos" "" (cbuf-text-cur cbuf)))))

;;; =================================================================
;;; INTEGRATION TESTS WITH REAL-WORLD SCENARIOS
;;; =================================================================

(test-group "real-world-scenarios"

  (test-group "code-editing-session"
    (let ([cbuf (make-cbuf)])
      ;; Type some code
      (cbuf-insert-string! cbuf "#include <stdio.h>")
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-string! cbuf "int main() {")
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-string! cbuf "    printf(\"Hello, world!\\n\");")
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-string! cbuf "    return 0;")
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-string! cbuf "}")

      ;; Go back and add a comment
      (cbuf-set-y! cbuf 3)  ; printf line
      (cbuf-beginning-of-line! cbuf)
      (cbuf-insert-string! cbuf "    // Print greeting")
      (cbuf-insert-newline! cbuf)

      ;; Verify the edit
      (test-equal "code editing line count" 7 (cbuf-line-count cbuf))
      (test-assert "comment inserted"
                   (string-contains (cbuf-get-line-text cbuf 3) "greeting"))))

  #;(test-group "document-editing-session"
    (let ([cbuf (make-cbuf)])
      ;; Type a document
      (cbuf-insert-string! cbuf "Chapter 1: Introduction")
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-string! cbuf "This document describes the implementation")
      (cbuf-insert-string! cbuf " of a character buffer system.")

      ;; Use mark to select and replace text
      (cbuf-set-y! cbuf 2)
      (cbuf-forward-word! cbuf)  ; After "This"
      (cbuf-set-mark! cbuf)
      (cbuf-forward-word! cbuf)  ; After "document"

      (let ([selected (cbuf-get-region-text cbuf)])
        (test-equal "selected text" " document" selected))

      ;; Continue editing
      (cbuf-end-of-buffer! cbuf)
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-string! cbuf "The buffer supports Unicode text,")
      (cbuf-insert-string! cbuf " combining characters, and various")
      (cbuf-insert-string! cbuf " terminal control operations.")

      (test-equal "document final line count" 5 (cbuf-line-count cbuf)))))

;;; =================================================================
;;; UNICODE AND INTERNATIONAL TEXT TESTS
;;; =================================================================

(test-group "unicode-text-handling"

  (test-group "international-characters"
    (let ([cbuf (make-cbuf)])
      ;; Insert various international characters
      (cbuf-insert-string! cbuf "Héllo Wörld")  ; Latin with diacritics
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-string! cbuf "こんにちは")      ; Japanese
      (cbuf-insert-newline! cbuf)
      (cbuf-insert-string! cbuf "🌟✨🌈")          ; Emoji

      (test-equal "international text line count" 3 (cbuf-line-count cbuf))
      (test-assert "handles diacritics"
                   (string-contains (cbuf-get-line-text cbuf 0) "Héllo"))
      (test-assert "handles CJK"
                   (string-contains (cbuf-get-line-text cbuf 1) "こんにちは"))
      (test-assert "handles emoji"
                   (string-contains (cbuf-get-line-text cbuf 2) "🌟"))))

  (test-group "complex-unicode-editing"
    (let ([cbuf (make-cbuf)])
      ;; Test editing with combining characters
      (cbuf-insert-string! cbuf "cafe\u0301")  ; café with combining acute
      (cbuf-set-x! cbuf 3 'data)  ; Position on 'e'
      (cbuf-delete-char! cbuf)    ; Should delete 'é' (e + combining acute)

      (test-equal "complex unicode deletion" "caf" (cbuf-text-cur cbuf))
      (test-equal "cursor after unicode deletion" 3 (cbuf-x-data cbuf)))))

;;; End test suite
;;; =================================================================
;;; STRICT TESTS
;;; =================================================================

(define (buf text) (make-cbuf #:initial-text text))
(define (pos b) (list (cbuf-line-cur b) (cbuf-x-data b)))
(define (goto! b line x) (cbuf-set-y! b line) (cbuf-set-x! b x 'data))

(define (state b)
  "Everything an undo should put back."
  (list (cbuf-text b) (pos b) (cbuf-x-cell b) (cbuf-modified? b) (cbuf-final-newline? b)
        (cbuf-mark-set? b) (cbuf-mark-line b) (cbuf-mark-x-data b) (cbuf-line-ending b)))

(define-syntax-rule (undo-test name text (line x) op)
  ;; Run OP on a buffer holding TEXT with the cursor at (LINE, X), undo
  ;; it, and check the buffer is exactly as before.
  (let ([b (buf text)])
    (goto! b line x)
    (let ([before (state b)])
      (op b)
      (cbuf-undo b)
      (test-equal (string-append "undo restores: " name) before (state b)))))

(test-group "strict: inserting characters"
  (let ([b (buf "ac")])
    (goto! b 0 1)
    (cbuf-insert-char! b #\b)
    (test-equal "inserted" "abc" (cbuf-text-cur b))
    (test-equal "cursor after it" '(0 2) (pos b)))
  (let ([b (buf "e")])
    (goto! b 0 1)
    (cbuf-insert-char! b #\x0301)
    (test-equal "combining mark joins its base" '("é") (cbuf-text b))
    (test-equal "cursor still after the cluster" '(0 1) (pos b)))
  (let ([b (buf "éx")])
    (goto! b 0 1)                          ; between é and x (string index 2)
    (cbuf-insert-char! b #\y)
    (test-equal "insert after a cluster uses the right index" "éyx" (cbuf-text-cur b)))
  (let ([b (buf "é̂̃̄x")])
    (goto! b 0 1)
    (test-error "a fifth combining mark is refused" #t (cbuf-insert-char! b #\x0305)))
  (let ([b (buf "é́̂̃x")])   ; é + 3 marks, then x
    (goto! b 0 1)
    (cbuf-insert-char! b #\x0304)
    (test-equal "a fourth mark after a precomposed char is allowed"
                "é́̂̃̄x" (cbuf-text-cur b)))
  (let ([b (buf "ab")])
    (goto! b 0 1)
    (cbuf-insert-char! b #\newline)
    (test-equal "inserting a newline character splits the line" '("a" "b") (cbuf-text b))
    (test-equal "and moves to the new line" '(1 0) (pos b))))

(test-group "strict: deleting characters"
  (let ([b (buf "abé́c")])
    (goto! b 0 2)
    (cbuf-delete-char! b)
    (test-equal "delete removes the whole cluster" "abc" (cbuf-text-cur b))
    (cbuf-backspace! b)
    (test-equal "backspace" "ac" (cbuf-text-cur b))
    (test-equal "cursor" '(0 1) (pos b)))
  (let ([b (buf "ab")])
    (goto! b 0 2)
    (cbuf-delete-char! b)
    (test-equal "delete at end of line does nothing" "ab" (cbuf-text-cur b))
    (test-equal "and records no undo" 0 (cbuf-get-undo-count b))
    (goto! b 0 0)
    (cbuf-backspace! b)
    (test-equal "backspace at start does nothing" "ab" (cbuf-text-cur b))
    (test-assert "buffer not modified" (not (cbuf-modified? b)))))

(test-group "strict: lines"
  (let ([b (buf "abc")])
    (goto! b 0 3)
    (cbuf-insert-newline! b)
    (test-equal "newline at the end of the buffer adds an empty line" '("abc" "") (cbuf-text b))
    (test-equal "but doesn't change final-newline?" #f (cbuf-final-newline? b))
    (test-equal "saved text" "abc\n" (cbuf-save-to-string (begin (set-cbuf-final-newline-policy! b 'preserve) b))))
  (let ([b (buf "a\nb\n")])
    (goto! b 1 0)
    (cbuf-delete-line! b)
    (test-equal "delete last line" '("a") (cbuf-text b))
    (test-equal "final-newline? is a property of the file, unchanged" #t (cbuf-final-newline? b))
    (test-equal "cursor moves to the new last line" '(0 0) (pos b)))
  (let ([b (buf "only")])
    (cbuf-delete-line! b)
    (test-equal "the only line is not deleted" '("only") (cbuf-text b)))
  (let ([b (buf "ab\ncd")])
    (goto! b 0 1)
    (cbuf-join-lines! b)
    (test-equal "join" '("abcd") (cbuf-text b))
    (test-equal "join keeps the cursor" '(0 1) (pos b))
    (cbuf-join-lines! b)
    (test-equal "join on the last line does nothing" '("abcd") (cbuf-text b))))

(test-group "strict: inserting strings"
  (let ([b (buf "xy")])
    (goto! b 0 1)
    (cbuf-insert-string! b "a b\tc")
    (test-equal "with spaces and tabs" "xa b\tcy" (cbuf-text-cur b))
    (test-equal "cursor after the inserted text" '(0 6) (pos b)))
  (let ([b (buf "xy")])
    (goto! b 0 1)
    (cbuf-insert-string! b "1\n2\n3")
    (test-equal "multi-line" '("x1" "2" "3y") (cbuf-text b))
    (test-equal "cursor after the last inserted line" '(2 1) (pos b)))
  (let ([b (buf "xy")])
    (goto! b 0 1)
    (cbuf-insert-string! b "1\r2\r\n3 4")
    (test-equal "all line endings split" '("x1" "2" "3" "4y") (cbuf-text b)))
  (let ([b (buf "xy")])
    (goto! b 0 1)
    (cbuf-insert-string! b "1\n")
    (test-equal "trailing newline" '("x1" "y") (cbuf-text b))
    (test-equal "cursor at the start of the next line" '(1 0) (pos b)))
  (let ([b (buf "éx")])
    (goto! b 0 1)
    (cbuf-insert-string! b "̂")
    (test-equal "a combining string attaches to the cluster before" "é̂x"
                (cbuf-text-cur b))))

(test-group "strict: deleting regions"
  (let ([b (buf "abc\ndef\nghi")])
    (goto! b 0 0)                          ; cursor elsewhere
    (cbuf-delete-region! b 2 1 2 2)
    (test-equal "single-line region on another line" '("abc" "def" "gi") (cbuf-text b))
    (test-equal "cursor at the start of the deletion" '(2 1) (pos b)))
  (let ([b (buf "abc\ndef\nghi")])
    (cbuf-delete-region! b 0 1 2 2)
    (test-equal "multi-line region" '("ai") (cbuf-text b))
    (test-equal "cursor" '(0 1) (pos b)))
  (let ([b (buf "abc\ndef")])
    (cbuf-delete-region! b 1 2 0 1)
    (test-equal "reversed endpoints" '("af") (cbuf-text b)))
  (let ([b (buf "abc\ndef")])
    (cbuf-delete-region! b 0 1 1 0)
    (test-equal "up to the start of the next line removes the newline" '("adef") (cbuf-text b)))
  (let ([b (buf "abc")])
    (test-error "line out of range" #t (cbuf-delete-region! b 0 0 3 0))
    (cbuf-delete-region! b 0 2 0 99)
    (test-equal "column past the end is clamped" '("ab") (cbuf-text b))))

(test-group "strict: mark, cut, copy, paste"
  (let ([b (buf "hello world")])
    (goto! b 0 6)
    (cbuf-set-mark! b)
    (goto! b 0 11)
    (test-equal "region text" "world" (cbuf-get-region-text b))
    (cbuf-copy-region! b)
    (test-equal "copy" '("world") (cbuf-cut-buffer b))
    (test-assert "copy keeps the mark" (cbuf-mark-set? b))
    (cbuf-exchange-point-and-mark! b)
    (test-equal "exchange: cursor at old mark" '(0 6) (pos b))
    (test-equal "exchange: mark at old cursor" 11 (cbuf-mark-x-data b))
    (cbuf-cut-region! b)
    (test-equal "cut" "hello " (cbuf-text-cur b))
    (test-assert "cut clears the mark" (not (cbuf-mark-set? b)))
    (goto! b 0 0)
    (cbuf-paste! b)
    (test-equal "paste" "worldhello " (cbuf-text-cur b))
    (test-equal "cursor after paste" '(0 5) (pos b)))
  (let ([b (buf "a\r\nb\r\n")])
    (goto! b 0 0)
    (cbuf-set-mark! b)
    (goto! b 1 1)
    (test-equal "region uses the buffer's line ending" "a\r\nb" (cbuf-get-region-text b)))
  (let ([b (buf "abc")])
    (test-equal "no mark: empty region" "" (cbuf-get-region-text b))
    (cbuf-cut-region! b)
    (test-equal "no mark: cut does nothing" "abc" (cbuf-text-cur b))
    (cbuf-paste! b)
    (test-equal "empty cut buffer: paste does nothing" "abc" (cbuf-text-cur b))))

(test-group "strict: final newline policy"
  (let ([b (make-cbuf #:final-newline-policy 'always-add)])
    (cbuf-load-from-string! b "abc")
    (test-equal "load doesn't add lines for always-add" '("abc") (cbuf-text b))
    (test-equal "save adds the newline" "abc\n" (cbuf-save-to-string b)))
  (let ([b (make-cbuf #:final-newline-policy 'never-add)])
    (cbuf-load-from-string! b "abc\n")
    (test-equal "load doesn't drop lines for never-add" '("abc") (cbuf-text b))
    (test-equal "save drops the newline" "abc" (cbuf-save-to-string b)))
  (let ([b (make-cbuf #:final-newline-policy 'preserve)])
    (cbuf-load-from-string! b "a\n\n")
    (test-equal "blank last line survives a round trip" "a\n\n" (cbuf-save-to-string b)))
  (let ([b (buf "abc")])
    (cbuf-set-final-newline-policy! b 'always-add)
    (test-equal "changing policy doesn't change the text" '("abc") (cbuf-text b))
    (test-equal "it sets the flag" #t (cbuf-final-newline? b))
    (cbuf-set-final-newline-policy! b 'never-add)
    (test-equal "and clears it" #f (cbuf-final-newline? b))
    (test-error "bad policy" #t (cbuf-set-final-newline-policy! b 'maybe)))
  (let ([b (make-cbuf #:final-newline-policy 'preserve)])
    (cbuf-load-from-string! b "x\r\ny")
    (test-equal "load detects CRLF" "\r\n" (cbuf-line-ending b))
    (test-equal "round trip" "x\r\ny" (cbuf-save-to-string b))
    (test-assert "load leaves the buffer unmodified" (not (cbuf-modified? b)))
    (test-equal "and the cursor at the start" '(0 0) (pos b))))

(test-group "strict: navigation"
  (let ([b (buf "a日b\nabcd")])
    (goto! b 0 2)                          ; after 日, cell 3
    (cbuf-next-line! b)
    (test-equal "goal column kept on the next line" '(1 3) (pos b))
    (goto! b 1 2)                          ; cell 2, inside 日 on line 0
    (cbuf-previous-line! b)
    (test-equal "a goal inside a wide character lands on it" '(0 1) (pos b))
    (cbuf-end-of-buffer! b)
    (test-equal "end of buffer" '(1 4) (pos b))
    (test-assert "end-of-buffer?" (cbuf-end-of-buffer? b))
    (cbuf-beginning-of-buffer! b)
    (test-assert "beginning-of-buffer?" (cbuf-beginning-of-buffer? b)))
  (let ([b (buf "x")])
    (cbuf-set-x! b 5 'data)
    (test-equal "data position is clamped" 1 (cbuf-x-data b))
    (cbuf-set-x! b -3 'data)
    (test-equal "negative data position is clamped" 0 (cbuf-x-data b))
    (test-error "bad position type" #t (cbuf-set-x! b 0 'pixels))))

(test-group "strict: pages"
  (let ([b (make-cbuf #:initial-text (string-join (map number->string (iota 13)) "\n")
                      #:form-size 10)])
    (test-assert "line 3 is on the first page" (cbuf-on-first-page? b))
    (goto! b 3 0)
    (test-assert "line 3 is not on the last page (lines 10-12 follow)"
                 (not (cbuf-on-last-page? b)))
    (goto! b 10 0)
    (test-assert "line 10 is on the last page" (cbuf-on-last-page? b))
    (test-assert "and not the first" (not (cbuf-on-first-page? b)))))

(test-group "strict: tab"
  (let ([b (buf "ab")])
    (goto! b 0 1)
    (cbuf-handle-tab! b)
    (test-equal "spaces to the next tab stop" "a       b" (cbuf-text-cur b))
    (test-equal "cursor after them" '(0 8) (pos b))))

(test-group "strict: undo restores everything"
  (undo-test "insert char" "abc" (0 1) (lambda (b) (cbuf-insert-char! b #\x)))
  (undo-test "insert combining mark" "abc" (0 1) (lambda (b) (cbuf-insert-char! b #\x0301)))
  (undo-test "delete char" "abc" (0 1) (lambda (b) (cbuf-delete-char! b)))
  (undo-test "delete cluster" "éx" (0 0) (lambda (b) (cbuf-delete-char! b)))
  (undo-test "backspace" "abc" (0 2) (lambda (b) (cbuf-backspace! b)))
  (undo-test "newline mid-line" "abc\ndef" (0 1) (lambda (b) (cbuf-insert-newline! b)))
  (undo-test "newline at start" "abc" (0 0) (lambda (b) (cbuf-insert-newline! b)))
  (undo-test "newline at end of buffer" "abc" (0 3) (lambda (b) (cbuf-insert-newline! b)))
  (undo-test "delete first line" "a\nb\nc" (0 0) (lambda (b) (cbuf-delete-line! b)))
  (undo-test "delete middle line" "a\nb\nc" (1 1) (lambda (b) (cbuf-delete-line! b)))
  (undo-test "delete last line" "a\nb\nc\n" (2 0) (lambda (b) (cbuf-delete-line! b)))
  (undo-test "join lines" "ab\ncd\nef" (1 1) (lambda (b) (cbuf-join-lines! b)))
  (undo-test "insert string" "abc" (0 1) (lambda (b) (cbuf-insert-string! b "xyz")))
  (undo-test "insert multi-line string" "abc\ndef" (0 1) (lambda (b) (cbuf-insert-string! b "1\n2\n3")))
  (undo-test "insert string with CR endings" "abc\ndef" (0 1) (lambda (b) (cbuf-insert-string! b "1\r2")))
  (undo-test "insert string with CRLF" "abc" (0 1) (lambda (b) (cbuf-insert-string! b "1\r\n2")))
  (undo-test "insert string ending in newline" "abc" (0 1) (lambda (b) (cbuf-insert-string! b "1\n")))
  (undo-test "delete region on one line" "abc\ndef" (0 0) (lambda (b) (cbuf-delete-region! b 1 0 1 2)))
  (undo-test "delete region over lines" "abc\ndef\nghi\njkl" (3 1)
             (lambda (b) (cbuf-delete-region! b 0 1 2 2)))
  (undo-test "delete region to next line start" "abc\ndef" (0 0)
             (lambda (b) (cbuf-delete-region! b 0 3 1 0)))
  (let ([b (buf "hello world\nnext")])
    (goto! b 0 2) (cbuf-set-mark! b) (goto! b 1 2)
    (let ([before (state b)])
      (cbuf-cut-region! b)
      (cbuf-undo b)
      (test-equal "undo restores: cut region (text, cursor and mark)" before (state b))))
  (let ([b (buf "abc\ndef")])
    (set-cbuf-cut-buffer! b '("1\n2"))
    (goto! b 0 1)
    (let ([before (state b)])
      (cbuf-paste! b)
      (cbuf-undo b)
      (test-equal "undo restores: paste" before (state b))))
  (undo-test "clear" "abc\ndef" (1 2) (lambda (b) (cbuf-clear! b)))
  (undo-test "load from string" "abc" (0 2) (lambda (b) (cbuf-load-from-string! b "x\r\ny\r\n")))
  (undo-test "tab" "ab" (0 1) (lambda (b) (cbuf-handle-tab! b)))
  ;; a sequence, undone step by step
  (let* ([b (buf "start\nend")]
         [s0 (state b)])
    (goto! b 0 5)
    (cbuf-insert-string! b " here")
    (cbuf-insert-newline! b)
    (cbuf-insert-char! b #\!)
    (goto! b 0 0)
    (cbuf-delete-char! b)
    (cbuf-join-lines! b)
    (test-equal "five edits recorded" 5 (cbuf-get-undo-count b))
    (let loop () (when (cbuf-can-undo? b) (cbuf-undo b) (loop)))
    (test-equal "undoing all edits restores the text" (car s0) (car (state b)))
    (test-assert "and the modified flag" (not (cbuf-modified? b))))
  (let ([b (buf "abc")])
    (cbuf-undo b)
    (test-equal "undo with nothing to undo is harmless" '("abc") (cbuf-text b))))

(test-group "strict: attributes follow the text"
  (let* ([b (buf "ab")]
         [bold ((@ (gano rendering) make-sgr) #:intensity 'intensity-bold)]
         [bold? (lambda (sgr) (eq? ((@ (gano rendering) sgr-intensity) sgr) 'intensity-bold))]
         [line-bold (lambda (n) (map bold? (text-metrics-sgr-list (list-ref (cbuf-text-metrics b) n))))])
    (set-cbuf-current-sgr! b bold)
    (goto! b 0 1)
    (cbuf-insert-char! b #\x)
    (cbuf-insert-string! b "yz")
    (test-equal "new text gets the current SGR" '(#f #t #t #t #f) (line-bold 0))
    (goto! b 0 2)
    (cbuf-insert-newline! b)
    (test-equal "split keeps attributes: left" '(#f #t) (line-bold 0))
    (test-equal "split keeps attributes: right" '(#t #t #f) (line-bold 1))
    (goto! b 0 2)
    (cbuf-join-lines! b)
    (test-equal "join keeps attributes" '(#f #t #t #t #f) (line-bold 0))))

(test-group "strict: undo registry"
  (test-assert "built-in operations are registered"
               (every (lambda (op) (memq op (cbuf-list-registered-operations)))
                      '(insert-char delete-char backspace insert-newline insert-string
                        delete-region delete-line join-lines clear-buffer)))
  (let ([b (buf "abc")])
    (test-error "saving an unregistered operation fails" #t (cbuf-save-undo! b 'no-such-op))
    (cbuf-insert-char! b #\x)
    (cbuf-clear-undo-history! b)
    (test-assert "clear history" (not (cbuf-can-undo? b))))
  (let ([b (buf "")])
    (cbuf-set-max-undo-operations! 3)
    (for-each (lambda (c) (cbuf-insert-char! b c)) (string->list "abcdef"))
    (test-equal "history is capped" 3 (cbuf-get-undo-count b))
    (cbuf-set-max-undo-operations! 1000)
    (test-error "the cap must be a positive integer" #t (cbuf-set-max-undo-operations! 0))))

(test-end "cbuf-basic")

