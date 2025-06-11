;;; Test suite for cbuf-basic MVP operations
;;; Using SRFI-64 testing framework

(use-modules (srfi srfi-64)         ; Testing framework
             (gano cbuf-basic)      ; Module under test
             (gano cbuf-core)       ; Core functionality
             (srfi srfi-1)          ; List utilities
             (srfi srfi-13))        ; String utilities

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

(test-group "word-navigation"
  
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
      (test-assert "x-cell expands for tab" (> (cbuf-x-cell cbuf) 5))))
  
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
      (cbuf-set-mark! cbuf)
      (cbuf-beginning-of-buffer! cbuf)
      
      ;; Verify state
      (test-equal "complex setup line count" 2 (cbuf-line-count cbuf))
      (test-assert "mark is set" (cbuf-mark-set? cbuf))
      
      ;; Undo and verify each step
      (cbuf-undo cbuf)  ; Undo mark setting
      (test-equal "position restored" 0 (cbuf-line-cur cbuf))
      
      (cbuf-undo cbuf)  ; Undo "second" insertion
      (test-equal "second line removed" "second" (cbuf-text-cur cbuf))
      
      (cbuf-undo cbuf)  ; Undo newline
      (test-equal "newline undone" 1 (cbuf-line-count cbuf))
      
      (cbuf-undo cbuf)  ; Undo "first" insertion
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
  
  (test-group "document-editing-session"
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
(test-end "cbuf-basic")

