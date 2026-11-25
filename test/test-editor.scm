;;; Tests for the (gano editor) MVP: drive the editor with key objects
;;; and check the buffer, the saved file and the rendered screen.

(define-module (test editor)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-64)
  #:use-module (gano editor)
  #:use-module (gano buffer)
  #:use-module (gano keys)
  #:use-module (gano commands)
  #:use-module (gano screen)
  #:use-module (ice-9 textual-ports)
  #:use-module (ice-9 binary-ports)
  #:use-module (ice-9 popen)
  #:use-module (rnrs bytevectors))

(setlocale LC_ALL "C.UTF-8")

;;; Helpers

(define (char-key ch) (make-key #:char ch))
(define (sym-key s) (make-key #:symbol s))
(define (ctrl-key* ch) (make-key #:char ch #:ctrl? #t))
(define (alt-key ch) (make-key #:char ch #:alt? #t))

(define (type! state . items)
  "Feed ITEMS to the editor: strings are typed character by character,
   symbols are special keys, and (ctrl . #\\x) / (alt . #\\x) pairs are
   control / alt keys."
  (for-each
   (lambda (item)
     (cond
      [(string? item) (string-for-each (lambda (ch) (handle-key state (char-key ch))) item)]
      [(symbol? item) (handle-key state (sym-key item))]
      [(and (pair? item) (eq? (car item) 'ctrl)) (handle-key state (ctrl-key* (cdr item)))]
      [(and (pair? item) (eq? (car item) 'alt)) (handle-key state (alt-key (cdr item)))]
      [else (error "bad item" item)]))
   items)
  state)

(define (temp-file contents)
  "Create a temporary file holding CONTENTS (or no file if #f); return its name."
  (let* ([port (mkstemp "/tmp/gano-test-XXXXXX")]
         [name (port-filename port)])
    (if contents
        (begin (set-port-encoding! port "UTF-8") (display contents port) (close-port port))
        (begin (close-port port) (delete-file name)))
    name))

(define (read-file name)
  (call-with-input-file name get-string-all #:encoding "UTF-8"))

(define* (open-editor contents #:key (width 40) (height 10))
  (let ([name (temp-file contents)])
    (make-editor-state #:filename name #:cbuf (load-buffer name)
                       #:width width #:height height)))

(define (buffer-text state) (cbuf->text (editor-cbuf state)))
(define (cursor state)
  (let ([cbuf (editor-cbuf state)])
    (list (cbuf-line-cur cbuf) (cbuf-x-data cbuf))))

(test-begin "editor")

(test-group "load and save"
  (let ([st (open-editor "hello\nworld\n")])
    (test-equal "loaded text" "hello\nworld\n" (buffer-text st))
    (test-assert "not modified after load" (not (editor-modified? st)))
    (type! st 'down 'right 'right "XY")
    (test-assert "modified after typing" (editor-modified? st))
    (type! st '(ctrl . #\s))
    (test-equal "saved file" "hello\nwoXYrld\n" (read-file (editor-filename st)))
    (test-assert "not modified after save" (not (editor-modified? st)))
    (test-assert "save reported" (string-prefix? "Wrote 2 lines" (editor-status-message st)))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "no newline at end")])
    (type! st "> " '(ctrl . #\s))
    (test-equal "missing final newline is preserved" "> no newline at end"
                (read-file (editor-filename st)))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "dos\r\nlines\r\n")])
    (type! st 'end-of-nothing 'down "2" '(ctrl . #\s))
    (test-equal "CRLF line endings are preserved" "dos\r\n2lines\r\n"
                (read-file (editor-filename st)))
    (delete-file (editor-filename st)))

  (let ([st (open-editor #f)])
    (test-equal "new file starts empty" 1 (cbuf-line-count (editor-cbuf st)))
    (type! st "first" 'enter "second" '(ctrl . #\s))
    (test-equal "new file gets a final newline" "first\nsecond\n"
                (read-file (editor-filename st)))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "café 日本\n")])
    (type! st 'right 'right 'right 'right "!" '(ctrl . #\s))
    (test-equal "UTF-8 round trip" "café! 日本\n"
                (read-file (editor-filename st)))
    (delete-file (editor-filename st))))

(test-group "editing"
  (let ([st (open-editor "ab\ncd\n")])
    (type! st 'down 'backspace)
    (test-equal "backspace at line start joins lines" "abcd\n" (buffer-text st))
    (test-equal "cursor at join point" '(0 2) (cursor st))
    (type! st 'backspace)
    (test-equal "backspace deletes previous char" "acd\n" (buffer-text st))
    (type! st 'delete)
    (test-equal "delete deletes char under cursor" "ad\n" (buffer-text st))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "ab\ncd\n")])
    (type! st 'right 'right 'delete)
    (test-equal "delete at line end joins lines" "abcd\n" (buffer-text st))
    (type! st 'enter)
    (test-equal "enter splits line" "ab\ncd\n" (buffer-text st))
    (test-equal "cursor on new line" '(1 0) (cursor st))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "x\n")])
    (type! st 'backspace 'up 'left)
    (test-equal "backspace/up/left at buffer start do nothing" "x\n" (buffer-text st))
    (test-equal "cursor still at start" '(0 0) (cursor st))
    (type! st 'right 'delete 'delete 'down 'right)
    (test-equal "delete/down/right at buffer end do nothing" "x\n" (buffer-text st))
    (delete-file (editor-filename st))))

(test-group "movement"
  (let ([st (open-editor "abc\nd\nefgh\n")])
    (type! st 'right 'right 'right 'right)
    (test-equal "right at line end wraps to next line" '(1 0) (cursor st))
    (type! st 'left)
    (test-equal "left at line start wraps to previous line end" '(0 3) (cursor st))
    (type! st 'down 'down)
    (test-equal "down keeps goal column" '(2 3) (cursor st))
    (delete-file (editor-filename st))))

(test-group "quitting"
  (let ([st (open-editor "text\n")])
    (type! st '(ctrl . #\x))
    (test-assert "^X quits a clean buffer" (editor-quit? st))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "text\n")])
    (type! st "more" '(ctrl . #\x))
    (test-assert "^X with unsaved changes asks first" (not (editor-quit? st)))
    (test-assert "asks to save" (string-prefix? "Save modified buffer?" (editor-prompt-label st)))
    (type! st '(ctrl . #\c))
    (test-assert "^C cancels the question" (not (editor-prompt-label st)))
    (test-assert "and doesn't quit" (not (editor-quit? st)))
    (type! st '(ctrl . #\x) "n")
    (test-assert "N quits without saving" (editor-quit? st))
    (test-equal "file untouched" "text\n" (read-file (editor-filename st)))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "text\n")])
    (type! st "more " '(ctrl . #\x) "y")
    (test-equal "Y offers the file name" (editor-filename st) (editor-prompt-input st))
    (type! st 'enter)
    (test-assert "then saves and quits" (editor-quit? st))
    (test-equal "saved" "more text\n" (read-file (editor-filename st)))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "text\n")])
    (type! st "more" '(ctrl . #\q))
    (test-assert "^Q quits without asking" (editor-quit? st))
    (test-equal "file untouched by ^Q" "text\n" (read-file (editor-filename st)))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "text\n")])
    (type! st "more" 'eof)
    (test-assert "end of input quits" (editor-quit? st))
    (delete-file (editor-filename st))))

(test-group "keys that do nothing"
  (let ([st (open-editor "text\n")])
    (type! st 'unknown '(ctrl . #\z) 'f5)
    (test-equal "unknown keys leave the buffer alone" "text\n" (buffer-text st))
    (test-assert "and are reported" (string-prefix? "Unknown key" (editor-status-message st)))
    (delete-file (editor-filename st))))

(test-group "rendering"
  (let* ([st (open-editor "first line\nsecond line\n" #:width 30 #:height 8)]
         [screen (render-screen st)])
    (test-assert "text is drawn" (string-contains screen "first line"))
    (test-assert "file name in status line"
                 (string-contains screen (basename (editor-filename st))))
    (test-assert "help is drawn (cut to fit)" (string-contains screen "^G he"))
    (test-assert "cursor placed at top left" (string-suffix? "\x1b[1;1H\x1b[?25h" screen))
    (type! st 'down 'right 'right)
    (render-screen st)
    (test-equal "rendering does not move the cursor" '(1 2) (cursor st))
    (test-assert "cursor drawn at row 2 col 3"
                 (string-suffix? "\x1b[2;3H\x1b[?25h" (render-screen st)))
    (type! st "!")
    (test-assert "status shows modified" (string-contains (render-screen st) "(modified)"))
    (delete-file (editor-filename st)))

  (let ([st (open-editor (string-append (make-string 50 #\a) "END\n") #:width 20 #:height 6)])
    (let loop ([i 0]) (when (< i 53) (type! st 'right) (loop (+ i 1))))
    (let ([screen (render-screen st)])
      (test-assert "long line scrolls horizontally" (string-contains screen "aEND"))))

  (let ([st (open-editor (string-join (map number->string (iota 30)) "\n" 'suffix)
                         #:width 20 #:height 8)])
    (let loop ([i 0]) (when (< i 20) (type! st 'down) (loop (+ i 1))))
    (let ([screen (render-screen st)])
      ;; 5 text rows; the frame re-centres so the cursor line is 2/3 down
      (test-assert "scrolls down to show cursor line" (string-contains screen "\x1b[4;1H20"))
      (test-assert "cursor drawn on that line" (string-suffix? "\x1b[4;1H\x1b[?25h" screen))
      (test-assert "lines above scrolled off" (not (string-contains screen "H16 "))))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "tab\there\n")])
    (test-assert "tabs are expanded" (string-contains (render-screen st) "tab     here"))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "bell\a!\n")])
    (test-assert "control characters are not sent to the terminal"
                 (not (string-index (render-screen st) #\alarm)))
    (delete-file (editor-filename st))))

;;; ---------------------------------------------------------------
;;; Phase 3 commands
;;; ---------------------------------------------------------------

(test-group "home end page"
  (let ([st (open-editor (string-join (map (lambda (i) (format #f "line ~a" i)) (iota 40))
                                      "\n" 'suffix)
                         #:width 40 #:height 13)])       ; 10 text rows
    (type! st 'right 'right 'end)
    (test-equal "End" '(0 6) (cursor st))
    (type! st 'home)
    (test-equal "Home" '(0 0) (cursor st))
    (type! st '(ctrl . #\e))
    (test-equal "^E" '(0 6) (cursor st))
    (type! st '(ctrl . #\a))
    (test-equal "^A" '(0 0) (cursor st))
    (type! st 'page-down)
    (test-equal "PgDn moves one screen" 10 (car (cursor st)))
    (type! st '(ctrl . #\v) 'page-up)
    (test-equal "^V and PgUp" 10 (car (cursor st)))
    (type! st '(ctrl . #\y))
    (test-equal "^Y" 0 (car (cursor st)))
    (delete-file (editor-filename st))))

(test-group "tab"
  (let ([st (open-editor "ab\n")])
    (type! st 'right 'tab)
    (test-equal "Tab inserts a tab" "a\tb\n" (buffer-text st))
    (test-assert "and it is drawn as spaces" (string-contains (render-screen st) "a       b"))
    (delete-file (editor-filename st))))

(test-group "cut and paste"
  (let ([st (open-editor "one\ntwo\nthree\nfour\n")])
    (type! st 'down '(ctrl . #\k) '(ctrl . #\k))
    (test-equal "two cuts" "one\nfour\n" (buffer-text st))
    (test-equal "clipboard collects consecutive cuts" "two\nthree\n" (editor-clipboard st))
    (type! st '(ctrl . #\u))
    (test-equal "paste puts both back" "one\ntwo\nthree\nfour\n" (buffer-text st))
    (test-equal "cursor after the pasted text" '(3 0) (cursor st))
    (type! st 'up 'up '(ctrl . #\k) 'down '(ctrl . #\k))
    (test-equal "a cut after moving starts a new clipboard" "four" (editor-clipboard st))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "a\nlast")])
    (type! st 'down '(ctrl . #\k))
    (test-equal "cutting the last line empties it" "a\n" (buffer-text st))
    (test-equal "clipboard has the text" "last" (editor-clipboard st))
    (type! st '(ctrl . #\k))
    (test-equal "cutting an empty last line does nothing" "a\n" (buffer-text st))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "x\n")])
    (type! st '(ctrl . #\u))
    (test-equal "nothing to paste" "Nothing to paste" (editor-status-message st))
    (delete-file (editor-filename st))))

(test-group "undo and redo"
  (let ([st (open-editor "start\n")])
    (type! st "hello world")
    (test-equal "typed" "hello worldstart\n" (buffer-text st))
    (type! st '(alt . #\u))
    (test-equal "undo removes the last word" "hello start\n" (buffer-text st))
    (type! st '(alt . #\u))
    (test-equal "undo again removes the first" "start\n" (buffer-text st))
    (test-assert "back to unmodified" (not (editor-modified? st)))
    (test-equal "cursor restored" '(0 0) (cursor st))
    (type! st '(alt . #\u))
    (test-equal "nothing more to undo" "Nothing to undo" (editor-status-message st))
    (type! st '(alt . #\e) '(alt . #\e))
    (test-equal "redo twice" "hello worldstart\n" (buffer-text st))
    (test-equal "cursor after redo" '(0 11) (cursor st))
    (type! st '(alt . #\u) "X" '(alt . #\e))
    (test-equal "an edit clears redo" "Nothing to redo" (editor-status-message st))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "one\ntwo\nthree\n")])
    (type! st 'down '(ctrl . #\k) 'enter 'backspace 'delete)
    (test-equal "after edits" "one\nhree\n" (buffer-text st))
    (type! st '(alt . #\u) '(alt . #\u) '(alt . #\u) '(alt . #\u))
    (test-equal "each edit undone in turn" "one\ntwo\nthree\n" (buffer-text st))
    (type! st 'down 'down '(alt . #\u))
    (test-equal "movement isn't an edit" "Nothing to undo" (editor-status-message st))
    (delete-file (editor-filename st))))

(test-group "undo uses the buffer's history"
  (let ([st (open-editor "x\n")])
    (type! st "ab" '(ctrl . #\s))
    (test-assert "saved" (not (editor-modified? st)))
    (type! st '(alt . #\u))
    (test-assert "undo after saving: differs from the file" (editor-modified? st))
    (type! st '(alt . #\e))
    (test-assert "redo back to the saved text: unmodified" (not (editor-modified? st)))
    (type! st "c" '(alt . #\u))
    (test-assert "undo a new edit back to the saved text: unmodified" (not (editor-modified? st)))
    (delete-file (editor-filename st)))

  ;; (an existing empty file has no final newline, and keeps it that way)
  (let ([st (open-editor "")])
    (type! st "ab" 'enter "cd")
    (type! st '(alt . #\u))
    (test-equal "Enter ends a run of typing" "ab\n" (buffer-text st))
    (type! st '(alt . #\u))
    (test-equal "then the newline" "ab" (buffer-text st))
    (type! st '(alt . #\u))
    (test-equal "then the first word" "" (buffer-text st))
    (type! st '(alt . #\e) '(alt . #\e) '(alt . #\e))
    (test-equal "redo all" "ab\ncd" (buffer-text st))
    (test-equal "cursor after redo" '(1 2) (cursor st))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "")])
    (type! st "ab" 'left 'right "cd" '(alt . #\u))
    (test-equal "moving ends a run, even back to the same place" "ab" (buffer-text st))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "")])
    (type! st "ab" 'tab "cd" '(alt . #\u))
    (test-equal "tab ends a run like a space" "ab\t" (buffer-text st))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "one\ntwo\n")])
    (type! st 'down 'backspace)
    (test-equal "joined" "onetwo\n" (buffer-text st))
    (type! st '(alt . #\u))
    (test-equal "undo backspace at a line start" "one\ntwo\n" (buffer-text st))
    (test-equal "cursor back where Backspace was pressed" '(1 0) (cursor st))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "a\nlast")])
    (type! st 'down 'right '(ctrl . #\k) '(alt . #\u))
    (test-equal "undo cutting the last line" "a\nlast" (buffer-text st))
    (test-equal "cursor back where ^K was pressed" '(1 1) (cursor st))
    (delete-file (editor-filename st)))

  (let ([st (open-editor "abc\n")])
    (type! st 'right '(ctrl . #\k) '(ctrl . #\u) '(alt . #\u) '(alt . #\u))
    (test-equal "cut and paste undone in two steps" "abc\n" (buffer-text st))
    (test-equal "cursor restored" '(0 1) (cursor st))
    (delete-file (editor-filename st))))

(test-group "search"
  (let ([st (open-editor "alpha beta\ngamma BETA\ndelta\n")])
    (type! st '(ctrl . #\w))
    (test-equal "search prompt" "Search: " (editor-prompt-label st))
    (type! st "beta" 'enter)
    (test-equal "found, cursor at start of match" '(0 6) (cursor st))
    (type! st '(ctrl . #\w))
    (test-equal "prompt offers previous search" "Search [beta]: " (editor-prompt-label st))
    (type! st 'enter)
    (test-equal "Enter repeats it; case is ignored" '(1 6) (cursor st))
    (type! st '(ctrl . #\w) 'enter)
    (test-equal "wraps to the top" '(0 6) (cursor st))
    (test-equal "and says so" "Search wrapped" (editor-status-message st))
    (type! st '(ctrl . #\w) "delt" 'enter)
    (test-equal "another word" '(2 0) (cursor st))
    (type! st '(ctrl . #\w) 'enter)
    (test-equal "only one" "This is the only occurrence" (editor-status-message st))
    (type! st '(ctrl . #\w) "zzz" 'enter)
    (test-equal "not found" "\"zzz\" not found" (editor-status-message st))
    (test-equal "cursor stays" '(2 0) (cursor st))
    (type! st '(ctrl . #\w) "abc" 'backspace 'backspace)
    (test-equal "backspace edits the prompt" "a" (editor-prompt-input st))
    (type! st '(ctrl . #\c))
    (test-equal "^C cancels" "Cancelled" (editor-status-message st))
    (test-equal "search text isn't typed into the buffer"
                "alpha beta\ngamma BETA\ndelta\n" (buffer-text st))
    (delete-file (editor-filename st))))

(test-group "go to line"
  (let ([st (open-editor "a\nbb\nccc\ndddd\n")])
    (type! st '(ctrl . #\_) "3" 'enter)
    (test-equal "line 3" '(2 0) (cursor st))
    (type! st '(alt . #\g) "4,3" 'enter)
    (test-equal "line 4 column 3" '(3 2) (cursor st))
    (type! st '(ctrl . #\_) "99,99" 'enter)
    (test-equal "clamped to the end" '(3 4) (cursor st))
    (type! st '(ctrl . #\_) "x" 'enter)
    (test-equal "bad number" "Invalid line or column number" (editor-status-message st))
    (delete-file (editor-filename st))))

(test-group "write out"
  (let* ([st (open-editor "text\n")]
         [other (temp-file #f)])
    (type! st "new " '(ctrl . #\o))
    (test-equal "prompt shows current name" (editor-filename st) (editor-prompt-input st))
    (type! st '(ctrl . #\u))
    (test-equal "^U clears the prompt" "" (editor-prompt-input st))
    (string-for-each (lambda (c) (type! st (string c))) other)
    (type! st 'enter)
    (test-equal "written under the new name" "new text\n" (read-file other))
    (test-equal "which becomes the file name" other (editor-filename st))
    (test-assert "saved" (not (editor-modified? st)))
    (delete-file other))

  (let* ([st (open-editor "mine\n")]
         [mine (editor-filename st)]
         [other (temp-file "theirs\n")])
    (type! st '(ctrl . #\o) '(ctrl . #\u))
    (string-for-each (lambda (c) (type! st (string c))) other)
    (type! st 'enter)
    (test-assert "asks before overwriting another file"
                 (string-contains (editor-prompt-label st) "exists"))
    (type! st "n")
    (test-equal "N leaves it alone" "theirs\n" (read-file other))
    (type! st '(ctrl . #\o) '(ctrl . #\u))
    (string-for-each (lambda (c) (type! st (string c))) other)
    (type! st 'enter "y")
    (test-equal "Y overwrites" "mine\n" (read-file other))
    (delete-file other)
    (delete-file mine))

  (let ([st (make-editor-state)])
    (type! st "untitled" '(ctrl . #\s))
    (test-equal "^S with no file name asks for one" "File Name to Write: "
                (editor-prompt-label st))
    (let ([name (temp-file #f)])
      (string-for-each (lambda (c) (type! st (string c))) name)
      (type! st 'enter)
      (test-equal "and saves there" "untitled\n" (read-file name))
      (delete-file name)))

  (let* ([st (open-editor "x\n")]
         [mine (editor-filename st)])
    (type! st "y" '(ctrl . #\o) '(ctrl . #\u))
    (string-for-each (lambda (c) (type! st (string c))) "/nonexistent-dir/file")
    (type! st 'enter)
    (test-assert "write errors are reported" (string-prefix? "Error writing" (editor-status-message st)))
    (test-assert "buffer still modified" (editor-modified? st))
    (delete-file mine)))

(test-group "keys and attributes through the shared modules"
  (let ([st (open-editor "x\n")])
    (type! st "ab" '(alt . #\U))
    (test-equal "Alt+Shift+U is undo too" "x\n" (buffer-text st))
    (handle-key st (make-key #:symbol 'f5))
    (test-equal "unknown keys are named with key->string" "Unknown key: F5"
                (editor-status-message st))
    (handle-key st (make-key #:symbol 'up #:ctrl? #t #:shift? #t))
    (test-equal "modified keys too" "Unknown key: C-S-up" (editor-status-message st))
    (delete-file (editor-filename st)))
  (let* ([st (open-editor "" #:width 20 #:height 6)]
         [cbuf (editor-cbuf st)])
    (set-cbuf-current-sgr! cbuf ((@ (gano rendering) make-sgr) #:intensity 'intensity-bold))
    (type! st "hi")
    (test-assert "text attributes reach the screen"
                 (string-contains (render-screen st) "\x1b[1;1H\x1b[1mhi\x1b[22m"))
    (delete-file (editor-filename st))))

(test-group "the command table drives main mode"
  (test-eq "the editor starts in main mode" MMAIN (editor-mode (open-editor #f)))
  (test-equal "editor commands are in the table" "Save the file"
              (command-help (command-table-ref editor-commands "save")))
  (test-equal "they replace standard commands of the same name" "Search forward for text, wrapping"
              (command-help (command-table-ref editor-commands "search")))
  (test-equal "standard commands are there too" "sort-lines"
              (command-name (command-table-ref editor-commands "sort-lines")))
  (test-equal "^S runs the editor's save" "save"
              (command-name (command-table-key-ref editor-commands MMAIN "^S")))
  (let ([st (open-editor "one two\nthree\n")])
    (handle-key st (make-key #:symbol 'right #:ctrl? #t))
    (test-equal "C-right: next word, a standard shortcut" '(0 4) (cursor st))
    (type! st '(alt . #\}))
    (test-equal "A-}: indent (tab size 8)" "        one two\nthree\n" (buffer-text st))
    (type! st '(alt . #\{))
    (test-equal "A-{: unindent" "one two\nthree\n" (buffer-text st))
    (type! st '(alt . #\d))
    (test-equal "A-d: duplicate the line" "one two\none two\nthree\n" (buffer-text st))
    (type! st '(alt . #\u))
    (test-equal "A-u still undoes a standard command" "one two\nthree\n" (buffer-text st))
    (type! st '(alt . #\u) '(alt . #\u))
    (test-assert "undoing the indent too leaves the buffer clean" (not (editor-modified? st)))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "cat dog cat\n")])
    (cbuf-end-of-line! (editor-cbuf st))
    (type! st '(alt . #\q))
    (test-equal "a command needing a string asks for it" "Search backward: "
                (editor-prompt-label st))
    (type! st "cat" 'enter)
    (test-equal "then runs with the answer" '(0 8) (cursor st))
    (test-assert "and the prompt is closed" (not (editor-prompt-label st)))
    (cbuf-beginning-of-line! (editor-cbuf st))
    (type! st '(ctrl . #\\))
    (test-equal "replace asks first for the search text" "Search (to replace): "
                (editor-prompt-label st))
    (type! st "dog" 'enter)
    (test-equal "then for the replacement" "Replace with: " (editor-prompt-label st))
    (type! st "cow" 'enter)
    (test-eq "then asks at the match" MREPLACEASK (editor-mode st))
    (type! st "y")
    (test-equal "and replaces" "cat cow cat\n" (buffer-text st))
    (test-equal "reporting it" "Replaced 1 occurrence" (editor-status-message st))
    (type! st '(ctrl . #\\) "cat" 'enter '(ctrl . #\c))
    (test-equal "^C at any prompt cancels the command" "cat cow cat\n" (buffer-text st))
    (test-equal "and says so" "Cancelled" (editor-status-message st))
    (type! st '(alt . #\x) "insert-text" 'enter 'enter)
    (test-equal "an empty answer cancels too" "Cancelled" (editor-status-message st))
    (type! st '(alt . #\v))
    (test-equal "a character input" "Verbatim input: " (editor-prompt-label st))
    (type! st "xy" 'enter)
    (test-equal "must be one character" "Type one character" (editor-status-message st))
    (test-equal "and nothing is inserted" "cat cow cat\n" (buffer-text st))
    (type! st '(alt . #\v) "!" 'enter)
    (test-equal "verbatim insert (after the replacement)" "cat cow! cat\n" (buffer-text st))
    (delete-file (editor-filename st)))
  (let ([st (open-editor (string-join (map number->string (iota 30)) "\n" 'suffix)
                         #:width 20 #:height 8)])
    (type! st '(alt . #\z))
    (test-equal "an unbound Alt key is unknown" "Unknown key: A-z" (editor-status-message st))
    (handle-key st (make-key #:symbol 'down #:alt? #t))
    (test-equal "A-down scrolls the view" 1
                ((@ (gano frame) frame-y-start) (editor-frame st)))
    (test-equal "taking the cursor along when it would leave" '(1 0) (cursor st))
    (render-screen st)
    (test-equal "so drawing does not scroll back" 1
                ((@ (gano frame) frame-y-start) (editor-frame st)))
    (delete-file (editor-filename st))))

(test-group "prompt modes"
  (let ([st (open-editor "aa\nbb\ncc\n")])
    (type! st 'down 'down '(ctrl . #\w))
    (test-eq "the search prompt is in search mode" MSEARCH (editor-mode st))
    (type! st '(ctrl . #\y))
    (test-equal "^Y at the search prompt goes to the first line" '(0 0) (cursor st))
    (test-equal "and the prompt stays open" "Search: " (editor-prompt-label st))
    (type! st '(ctrl . #\v))
    (test-equal "^V goes to the last line" 2 (car (cursor st)))
    (type! st '(ctrl . #\c))
    (test-eq "closing the prompt goes back to main mode" MMAIN (editor-mode st))
    (type! st '(ctrl . #\_))
    (test-eq "go to line has its own mode" MGOTOLINE (editor-mode st))
    (type! st '(ctrl . #\y))
    (test-equal "^Y works there too" '(0 0) (cursor st))
    (type! st "3" 'enter)
    (test-equal "and the answer still works" '(2 0) (cursor st))
    (type! st '(ctrl . #\o))
    (test-eq "write out" MWRITEFILE (editor-mode st))
    (type! st '(ctrl . #\y))
    (test-equal "^Y is not a prompt key when writing" '(2 0) (cursor st))
    (type! st '(ctrl . #\c) '(ctrl . #\\))
    (test-eq "replace" MREPLACE (editor-mode st))
    (type! st "b" 'enter)
    (test-eq "replace with" MREPLACEWITH (editor-mode st))
    (type! st '(ctrl . #\c) "x" '(ctrl . #\x))
    (test-eq "a yes/no question" MYESNO (editor-mode st))
    (type! st "q")
    (test-eq "other keys are ignored there" MYESNO (editor-mode st))
    (type! st '(ctrl . #\c))
    (type! st '(alt . #\q) "a" 'backspace "c")
    (test-equal "backspace edits the answer" "c" (editor-prompt-input st))
    (type! st '(ctrl . #\u))
    (test-equal "^U clears it" "" (editor-prompt-input st))
    (type! st 'tab)
    (test-equal "tab is typed into a text prompt" "\t" (editor-prompt-input st))
    (type! st '(alt . #\}))
    (test-equal "main-mode keys do nothing at a prompt" "\t" (editor-prompt-input st))
    (type! st 'escape)
    (test-assert "escape cancels" (not (editor-prompt-label st)))
    (delete-file (editor-filename st))))

(test-group "extended commands"
  (let ([st (open-editor "b\na\n")])
    (type! st '(alt . #\x))
    (test-equal "A-x asks for a command" "Command: " (editor-prompt-label st))
    (test-eq "in the extended command mode" MEXTCMD (editor-mode st))
    (type! st "select-all" 'enter "\x00")
    (test-assert "runs the command" (cbuf-mark-set? (editor-cbuf st)))
    (type! st '(alt . #\x) "sort-lines" 'enter)
    (test-equal "commands with no shortcut can be run" "a\nb\n" (buffer-text st))
    (type! st '(alt . #\x) "nonsense" 'enter)
    (test-equal "an unknown name" "No command called \"nonsense\"" (editor-status-message st))
    (type! st '(alt . #\x) "accept" 'enter)
    (test-equal "prompt commands are not main commands" "No command called \"accept\""
                (editor-status-message st))
    (type! st '(alt . #\x) 'enter)
    (test-equal "an empty name cancels" "Cancelled" (editor-status-message st))
    (type! st '(alt . #\x) "goto-l" 'tab)
    (test-equal "Tab completes a unique prefix" "goto-line" (editor-prompt-input st))
    (type! st 'enter)
    (test-eq "a command that asks then asks" MGOTOLINE (editor-mode st))
    (type! st "2" 'enter)
    (test-equal "and runs" 1 (car (cursor st)))
    (type! st '(alt . #\x) "sel" 'tab)
    (test-equal "Tab completes to the common prefix" "sel" (editor-prompt-input st))
    (type! st "ect-" 'tab)
    (test-equal "still ambiguous" "select-" (editor-prompt-input st))
    (test-equal "the choices are listed" "select-all select-line select-para select-sent select-word"
                (editor-status-message st))
    (test-assert "on the screen" (string-contains (render-screen st) "select-all select-line"))
    (set-editor-status-message! st "")
    (type! st "zz" 'tab)
    (test-equal "no match" "No command starts with \"select-zz\"" (editor-status-message st))
    (type! st '(ctrl . #\c))
    (type! st '(alt . #\x) "save" 'tab)
    (test-equal "a full name stays" "save" (editor-prompt-input st))
    (type! st '(ctrl . #\c))
    (type! st '(alt . #\\) '(alt . #\x) "cut-line" 'enter '(alt . #\x) "cut-line" 'enter)
    (test-equal "cut-line run by name still collects lines" "a\nb" (editor-clipboard st))
    (delete-file (editor-filename st))))

(test-group "help from the command table"
  (let* ([st (open-editor "abc\n" #:width 80 #:height 10)]
         [screen (render-screen st)])
    (test-assert "main help row 1" (string-contains screen "^G help"))
    (test-assert "main help row 2" (string-contains screen "A-x command"))
    (type! st '(alt . #\q))
    (test-assert "prompt rows list the mode's keys"
                 (string-contains (render-screen st) "enter accept"))
    (type! st '(ctrl . #\c) "x" '(ctrl . #\x))
    (test-assert "yes/no rows" (string-contains (render-screen st) "n no"))
    (type! st '(ctrl . #\c))
    (type! st '(ctrl . #\g))
    (test-eq "^G opens the help screen" MHELP (editor-mode st))
    (let ([screen (render-screen st)])
      (test-assert "help text is drawn" (string-contains screen "gano help"))
      (test-assert "the status line says so" (string-contains screen " Help"))
      (test-assert "help rows show the help mode's keys" (string-contains screen "^G help-exit"))
      (test-assert "the cursor is not shown" (not (string-contains screen "\x1b[?25h"))))
    (type! st "z" 'tab)
    (test-equal "typing does not reach the buffer" "xabc\n" (buffer-text st))
    (handle-key st (make-key #:symbol 'pagedown))
    (test-assert "and shows later commands"
                 (not (string-contains (render-screen st) "gano help")))
    (handle-key st (make-key #:symbol 'pageup))
    (test-assert "PgUp goes back" (string-contains (render-screen st) "gano help"))
    (type! st "q")
    (test-eq "q closes it" MMAIN (editor-mode st))
    (test-assert "and the text is back" (string-contains (render-screen st) "xabc"))
    (type! st '(ctrl . #\g) '(ctrl . #\x))
    (test-eq "^X closes it too" MMAIN (editor-mode st))
    (test-assert "without quitting" (not (editor-quit? st)))
    (type! st '(alt . #\x) "help" 'enter)
    (test-eq "help by name" MHELP (editor-mode st))
    (editor-resize! st 60 12)
    (type! st 'escape)
    (test-eq "Escape closes it" MMAIN (editor-mode st))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "x\n" #:width 80 #:height 200)])
    (type! st '(ctrl . #\g))
    (let ([screen (render-screen st)])
      (test-assert "every main command is listed with its keys"
                   (string-contains screen "save        ^S"))
      (test-assert "with its help" (string-contains screen "Save the file")))
    (delete-file (editor-filename st))))

(test-group "result messages"
  (let ([st (open-editor "cat\n")])
    (type! st '(alt . #\q) "dog" 'enter)
    (test-equal "a failed search says so" "Not found" (editor-status-message st))
    (type! st '(alt . #\x) "replace-all" 'enter "a" 'enter "o" 'enter "y")
    (test-equal "replace-all counts" "Replaced 1 occurrence" (editor-status-message st))
    (test-equal "and replaced" "cot\n" (buffer-text st))
    (delete-file (editor-filename st))))

(define (replace! st search replacement . answers)
  "Start an interactive replace of SEARCH by REPLACEMENT and give the answers"
  (apply type! st '(ctrl . #\\) search 'enter replacement 'enter answers))

(test-group "interactive replace"
  (let ([st (open-editor "a1 a2 a3 a4\n")])
    (replace! st "a" "b")
    (test-eq "asks at the first match" MREPLACEASK (editor-mode st))
    (test-equal "the question" "Replace this instance? (Y/N/A, ^C to stop) " (editor-prompt-label st))
    (test-equal "with the match selected" "a" (cbuf-get-region-text (editor-cbuf st)))
    (test-equal "the first one" '(0 1) (cursor st))
    (type! st "y")
    (test-equal "Y replaces it" "b1 a2 a3 a4\n" (buffer-text st))
    (test-equal "and moves on to the next" '(0 4) (cursor st))
    (type! st "n")
    (test-equal "N skips it" "b1 a2 a3 a4\n" (buffer-text st))
    (type! st "q" "Y")
    (test-equal "other keys are ignored; Y works too" "b1 a2 b3 a4\n" (buffer-text st))
    (type! st "n")
    (test-assert "after the last match it stops" (not (editor-prompt-label st)))
    (test-equal "and reports" "Replaced 2 occurrences" (editor-status-message st))
    (test-assert "with nothing left selected" (not (cbuf-mark-set? (editor-cbuf st))))
    (test-equal "the cursor stays after the last replacement" '(0 7) (cursor st))
    (type! st '(alt . #\u))
    (test-equal "each replacement is its own undo step" "b1 a2 a3 a4\n" (buffer-text st))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "x x\nx x\n")])
    (replace! st "x" "yy" "n" "a")
    (test-equal "A replaces this one and all the rest" "x yy\nyy yy\n" (buffer-text st))
    (test-equal "counting them" "Replaced 3 occurrences" (editor-status-message st))
    (test-assert "without asking again" (not (editor-prompt-label st)))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "x x x\n")])
    (replace! st "x" "y" "y" '(ctrl . #\c))
    (test-equal "^C stops" "y x x\n" (buffer-text st))
    (test-equal "saying what was done" "Replaced 1 occurrence" (editor-status-message st))
    (test-assert "closing the prompt" (not (editor-prompt-label st)))
    (test-assert "and the selection" (not (cbuf-mark-set? (editor-cbuf st))))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "x1 x2\nx3 x4\n")])
    (type! st 'down 'right 'right 'right)            ; on x4
    (replace! st "x" "X")
    (test-equal "starts at the cursor" '(1 3) (list (cbuf-mark-line (editor-cbuf st))
                                                    (cbuf-mark-x-data (editor-cbuf st))))
    (type! st "n")
    (test-equal "then wraps round to the start" '(0 0) (list (cbuf-mark-line (editor-cbuf st))
                                                         (cbuf-mark-x-data (editor-cbuf st))))
    (type! st "y" "y" "y")
    (test-assert "and stops where it began, not asking about x4 again"
                 (not (editor-prompt-label st)))
    (test-equal "replacing the rest" "X1 X2\nX3 x4\n" (buffer-text st))
    (test-equal "counting them" "Replaced 3 occurrences" (editor-status-message st))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "ab ab ab\n")])
    (type! st 'right 'right 'right 'right)            ; inside the second ab
    (replace! st "ab" "abab" "a")
    ;; The match that starts before the cursor belongs to the wrapped
    ;; part; replacing the first match moves the starting point along,
    ;; so it is still reached, and the first match is not revisited.
    (test-equal "a growing replacement before the start on the start line"
                "abab abab abab\n" (buffer-text st))
    (test-equal "moves the starting point with it" "Replaced 3 occurrences"
                (editor-status-message st))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "Cat CAT cat\n")])
    (replace! st "cat" "dog" "a")
    (test-equal "matches ignore case, as search does" "dog dog dog\n" (buffer-text st))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "aaa\n")])
    (replace! st "a" "aa" "a")
    (test-equal "a replacement containing the text does not loop" "aaaaaa\n" (buffer-text st))
    (test-equal "3 replaced" "Replaced 3 occurrences" (editor-status-message st))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "a-b-c\n")])
    (replace! st "-" "" "a")
    (test-equal "the replacement may be empty" "abc\n" (buffer-text st))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "abc\n")])
    (replace! st "zz" "y")
    (test-equal "nothing to replace" "\"zz\" not found" (editor-status-message st))
    (test-assert "nothing asked" (not (editor-prompt-label st)))
    (test-equal "cursor unmoved" '(0 0) (cursor st))
    (type! st '(ctrl . #\\))
    (test-equal "the last search is offered" "Search (to replace) [zz]: " (editor-prompt-label st))
    (type! st 'enter)
    (test-equal "and used for an empty answer" "Replace with: " (editor-prompt-label st))
    (type! st '(ctrl . #\c))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "one two\n" #:width 40 #:height 10)])
    (replace! st "two" "2")
    (let ([screen (render-screen st)])
      (test-assert "the match is shown in reverse video"
                   (string-contains screen "one \x1b[7mtwo\x1b[27m"))
      (test-assert "the help rows offer the answers" (string-contains screen "a all")))
    (type! st '(ctrl . #\c))
    (test-assert "and is normal again afterwards"
                 (not (string-contains (render-screen st) "\x1b[7mtwo")))
    (delete-file (editor-filename st))))

(test-group "selection highlight"
  (let ([st (open-editor "abcdef\nghij\n" #:width 40 #:height 10)])
    (type! st 'right '(ctrl . #\^) 'right 'right)
    (test-assert "the selection is shown in reverse video"
                 (string-contains (render-screen st) "a\x1b[7mbc\x1b[27mdef"))
    (type! st 'down)
    (let ([screen (render-screen st)])
      (test-assert "across lines: the end of the first line"
                   (string-contains screen "a\x1b[7mbcdef"))
      (test-assert "and the start of the next" (string-contains screen "\x1b[7mghi\x1b[27mj")))
    (type! st 'up 'left 'left 'left)
    (test-assert "a selection backwards from the mark"
                 (string-contains (render-screen st) "\x1b[7ma\x1b[27mbcdef"))
    (delete-file (editor-filename st))))

(define (temp-bytes bytes)
  (let* ([port (mkstemp "/tmp/gano-test-XXXXXX")]
         [name (port-filename port)])
    (put-bytevector port bytes)
    (close-port port)
    name))

(define (file-bytes name) (call-with-input-file name get-bytevector-all #:binary #t))

(test-group "files that are not valid UTF-8"
  (let ([name (temp-bytes #vu8(111 107 10 255 254 98 10))])        ; "ok\n" FF FE "b\n"
    (call-with-values (lambda () (read-buffer name))
      (lambda (cbuf valid?)
        (test-eq "read-buffer says it is not valid" #f valid?)
        (test-equal "bad bytes become U+FFFD" '("ok" "\ufffd\ufffdb") (cbuf-text cbuf))
        (test-assert "and the buffer is clean" (not (cbuf-modified? cbuf)))))
    (let ([st (make-editor-state #:filename name #:cbuf (load-buffer name) #:valid-utf-8? #f)])
      (test-equal "the editor remembers the file" name (editor-bad-utf-8-file st))
      (type! st "x" '(ctrl . #\s))
      (test-assert "^S asks before saving over it"
                   (string-contains (editor-prompt-label st) "was not valid UTF-8"))
      (type! st "n")
      (test-equal "N does not save" "Not saved" (editor-status-message st))
      (test-equal "the file is untouched" #vu8(111 107 10 255 254 98 10) (file-bytes name))
      (type! st '(ctrl . #\s) "y")
      (test-equal "Y saves" (string-append "xok\n\ufffd\ufffdb\n")
                  (call-with-input-file name get-string-all #:encoding "UTF-8"))
      (test-eq "after which the file is valid" #f (editor-bad-utf-8-file st))
      (type! st "y" '(ctrl . #\s))
      (test-assert "so the next save does not ask" (not (editor-prompt-label st)))
      (delete-file name)))
  (let* ([name (temp-bytes #vu8(255 10))]
         [other (temp-file #f)]
         [st (make-editor-state #:filename name #:cbuf (load-buffer name) #:valid-utf-8? #f)])
    (type! st '(ctrl . #\o) '(ctrl . #\u) other 'enter)
    (test-assert "writing to another name does not ask" (not (editor-prompt-label st)))
    (test-assert "and writes it" (file-exists? other))
    (test-equal "the original keeps its bytes" #vu8(255 10) (file-bytes name))
    (type! st '(ctrl . #\o) '(ctrl . #\u) name 'enter "y")
    (test-assert "writing back over the original asks"
                 (and (editor-prompt-label st)
                      (string-contains (editor-prompt-label st) "was not valid UTF-8")))
    (type! st '(ctrl . #\c))
    (test-equal "and can be refused" #vu8(255 10) (file-bytes name))
    (delete-file name) (delete-file other))
  (let ([name (temp-bytes #vu8(226 130 172 10))])                     ; "€\n"
    (call-with-values (lambda () (read-buffer name))
      (lambda (cbuf valid?)
        (test-eq "valid UTF-8 is valid" #t valid?)
        (test-equal "and read as such" '("€") (cbuf-text cbuf))))
    (delete-file name))
  (let ([name (temp-bytes #vu8())])
    (call-with-values (lambda () (read-buffer name))
      (lambda (cbuf valid?)
        (test-eq "an empty file is valid" #t valid?)
        (test-equal "and empty" "" (cbuf->text cbuf))))
    (delete-file name)))

;;; The command line, by running bin/gano (standard input is not a
;;; terminal, so it stops before starting the editor).
(define top (dirname (dirname (current-filename))))

(define (gano . args)
  "Run bin/gano with ARGS and no terminal; return (status . output)"
  (let* ([port (apply open-pipe* OPEN_READ "sh" "-c"
                      "exec \"$0\" \"$@\" </dev/null 2>&1"
                      (string-append top "/bin/gano") args)]
         [output (get-string-all port)]
         [status (status:exit-val (close-pipe port))])
    (cons status (if (eof-object? output) "" output))))

(test-group "command line"
  (test-equal "--version" (cons 0 (string-append "gano " gano-version "\n")) (gano "--version"))
  (test-equal "-V" (cons 0 (string-append "gano " gano-version "\n")) (gano "-V"))
  (let ([r (gano "--help")])
    (test-eqv "--help succeeds" 0 (car r))
    (test-assert "and shows the usage" (string-prefix? "Usage: gano [FILE]" (cdr r)))
    (test-assert "and the options" (string-contains (cdr r) "--version")))
  (let ([r (gano "-z")])
    (test-eqv "an unknown option fails" 1 (car r))
    (test-assert "saying so" (string-prefix? "gano: unknown option -z\n" (cdr r))))
  (test-eqv "two files fail" 1 (car (gano "a" "b")))
  (test-equal "a directory is reported plainly" (cons 1 "gano: /tmp: Is a directory\n")
              (gano "/tmp"))
  (test-equal "-- ends the options" (cons 1 "gano: standard input is not a terminal\n")
              (gano "--" "-z"))
  (test-equal "no terminal" (cons 1 "gano: standard input is not a terminal\n") (gano)))

(test-group "cut and copy with a selection (as nano)"
  (let ([st (open-editor "one two three\nfour\n")])
    (type! st 'right 'right 'right 'right '(ctrl . #\^) 'right 'right 'right 'right)
    (type! st '(ctrl . #\k))
    (test-equal "^K cuts the selection" "one three\nfour\n" (buffer-text st))
    (test-equal "into the clipboard" "two " (editor-clipboard st))
    (test-assert "and the selection is gone" (not (cbuf-mark-set? (editor-cbuf st))))
    (test-equal "the cursor is where the selection was" '(0 4) (cursor st))
    (type! st '(ctrl . #\k))
    (test-equal "the next ^K cuts the line" "four\n" (buffer-text st))
    (test-equal "adding to the clipboard" "two one three\n" (editor-clipboard st))
    (type! st '(ctrl . #\u))
    (test-equal "one paste puts both back" "two one three\nfour\n" (buffer-text st))
    (type! st '(alt . #\u))
    (test-equal "undoing the paste" "four\n" (buffer-text st))
    (type! st '(alt . #\u))
    (test-equal "the line cut" "one three\nfour\n" (buffer-text st))
    (type! st '(alt . #\u))
    (test-equal "and the selection cut, one step each" "one two three\nfour\n" (buffer-text st))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "abc\ndef\n")])
    (type! st 'down '(ctrl . #\^) '(ctrl . #\k))
    (test-equal "^K with an empty selection cuts nothing" "abc\ndef\n" (buffer-text st))
    (test-assert "and clears the mark" (not (cbuf-mark-set? (editor-cbuf st))))
    (type! st '(ctrl . #\k))
    (test-equal "after which ^K cuts the line again (the last line is emptied)" "abc\n\n"
                (buffer-text st))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "abc\ndef\n")])
    (type! st '(ctrl . #\^) 'down)
    (type! st '(ctrl . #\k))
    (test-equal "a selection across lines" "def\n" (buffer-text st))
    (test-equal "is cut with its line break" "abc\n" (editor-clipboard st))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "hello world\n")])
    (type! st '(ctrl . #\^) 'right 'right 'right 'right 'right '(alt . #\6))
    (test-equal "A-6 copies the selection" "hello" (editor-clipboard st))
    (test-equal "leaving the text" "hello world\n" (buffer-text st))
    (test-assert "and clearing the mark" (not (cbuf-mark-set? (editor-cbuf st))))
    (type! st 'end '(ctrl . #\u))
    (test-equal "^U pastes what A-6 copied" "hello worldhello\n" (buffer-text st))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "one\ntwo\nthree\n")])
    (type! st '(alt . #\6) '(alt . #\6))
    (test-equal "A-6 without a selection copies lines, one after another" "one\ntwo\n"
                (editor-clipboard st))
    (test-equal "moving down" '(2 0) (cursor st))
    (test-equal "and changing nothing" "one\ntwo\nthree\n" (buffer-text st))
    (type! st 'right '(alt . #\6))
    (test-equal "anything in between starts a new copy" "three" (editor-clipboard st))
    (delete-file (editor-filename st))))

(test-group "prompt rendering"
  (let ([st (open-editor "x\n" #:width 40 #:height 10)])
    (type! st '(ctrl . #\w) "ab")
    (let ([screen (render-screen st)])
      (test-assert "prompt drawn on the status row" (string-contains screen "\x1b[8;1H\x1b[7mSearch: ab"))
      (test-assert "prompt help, from the search mode's shortcuts" (string-contains screen "^C cancel"))
      (test-assert "cursor in the prompt" (string-suffix? "\x1b[8;11H\x1b[?25h" screen)))
    (delete-file (editor-filename st))))

;;; ---------------------------------------------------------------
;;; The screen, and updating the terminal
;;; ---------------------------------------------------------------

(define (screen-rows-of st)
  (let ([screen (editor-screen st)])
    (map (lambda (r) (string-trim-right (screen-row-string screen r)))
         (iota (screen-height screen)))))

(test-group "editor screen"
  (let* ([st (open-editor "first line\nsecond\tline\n" #:width 30 #:height 8)]
         [screen (editor-screen st)]
         [rows (screen-rows-of st)])
    (test-equal "the size of the terminal" '(30 8)
                (list (screen-width screen) (screen-height screen)))
    (test-equal "text rows" '("first line" "second  line" "" "" "") (list-head rows 5))
    (test-assert "status row" (string-prefix? (string-append " " (basename (editor-filename st)))
                                              (list-ref rows 5)))
    (test-eq "in reverse video" 'polarity-negative
             ((@ (gano rendering) sgr-polarity) (screen-cell-sgr screen 5 0)))
    (test-assert "help rows" (and (string-prefix? "^G he" (list-ref rows 6))
                                  (string-prefix? "^X ex" (list-ref rows 7))))
    (type! st 'down 'right 'right)
    (let ([screen (editor-screen st)])
      (test-equal "the cursor" '(1 2 #t)
                  (list (screen-cursor-row screen) (screen-cursor-col screen)
                        (screen-cursor-visible? screen))))
    (type! st '(ctrl . #\w) "ab")
    (let ([screen (editor-screen st)])
      (test-assert "an open prompt is on the status row"
                   (string-prefix? "Search: ab" (screen-row-string screen 5)))
      (test-equal "with the cursor after its input" '(5 10)
                  (list (screen-cursor-row screen) (screen-cursor-col screen))))
    (type! st '(ctrl . #\c) '(ctrl . #\g))
    (test-assert "the cursor is hidden on the help screen"
                 (not (screen-cursor-visible? (editor-screen st))))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "abcdef\n" #:width 40 #:height 10)])
    (type! st 'right '(ctrl . #\^) 'right 'right)
    (let ([screen (editor-screen st)])
      (test-equal "the selection is in reverse video"
                  '(polarity-positive polarity-negative polarity-negative polarity-positive)
                  (map (lambda (col)
                         ((@ (gano rendering) sgr-polarity) (screen-cell-sgr screen 0 col)))
                       '(0 1 2 3))))
    (delete-file (editor-filename st)))
  (let ([st (open-editor "x\n" #:width 20 #:height 2)])
    (test-equal "a terminal too short for the status and help rows" '("x" "")
                (screen-rows-of st))
    (delete-file (editor-filename st))))

(test-group "updating the terminal"
  ;; Edit a file as a user would, keeping a terminal up to date with
  ;; screen-update, as the editor's main loop does.
  (let* ([text (string-concatenate
                (map (lambda (i)
                       (format #f "~a: ~a~%" i
                               (list-ref '("It was the best of times, it was the worst of times,"
                                           "it was the age of wisdom,"
                                           ""
                                           "    it was the age of foolishness, it was the epoch"
                                           "we had everything before us, we had nothing before us")
                                         (modulo (* i 7) 5))))
                     (iota 120)))]
         [st (open-editor text #:width 60 #:height 20)]
         [terminal #f]                  ; the screen the terminal shows
         [sizes '()])
    (define (draw! . keys)
      "Type KEYS, update the terminal, and return the bytes sent"
      (apply type! st keys)
      (let* ([screen (editor-screen st)]
             [ops (screen-update terminal screen)])
        (set! terminal (screen-apply-ops (or terminal (make-screen 60 20)) ops))
        (unless (screen-equal? terminal screen) (error "the terminal is out of date after" keys))
        (ops-byte-count ops)))
    (define redraw (draw!))
    (test-assert "the first draw" (> redraw 500))
    (test-equal "no change, nothing sent" 0 (draw!))
    (test-assert "typing a character" (< (draw! "x") 50))
    (test-assert "and another" (< (draw! "y") 30))
    (test-assert "moving the cursor" (< (draw! 'right) 30))
    (test-assert "deleting a character" (< (draw! 'backspace) 30))
    (test-assert "a new line moves the rows below down" (< (draw! 'enter) 120))
    (test-assert "joining lines moves them back up" (< (draw! 'backspace) 120))
    (test-assert "cutting a line" (< (draw! '(ctrl . #\k)) 150))
    (test-assert "paging down scrolls the rows still in view"
                 (< (draw! 'pagedown) (* 0.7 redraw)))
    (test-assert "the end of a long line: the text slides sideways"
                 (begin (type! st 'down 'down 'down)
                        (< (draw! 'end) (* 0.5 redraw))))
    (test-assert "and back" (< (draw! 'home) (* 0.7 redraw)))
    (test-assert "selecting" (< (draw! '(ctrl . #\^) 'right 'right 'down) 150))
    (test-assert "opening a prompt" (< (draw! '(ctrl . #\c) '(ctrl . #\w)) 250))
    (test-assert "typing in it" (< (draw! "w") 15))
    (test-equal "^L (redraw) changes nothing on the screen" 0 (draw! '(ctrl . #\l)))
    (test-equal "nor at a prompt, which stays open" MSEARCH
                (begin (draw! '(ctrl . #\l)) (editor-mode st)))
    (test-assert "the help screen and back" (and (draw! '(ctrl . #\c) '(ctrl . #\g))
                                                 (draw! "q")))
    ;; a long session
    (let ([total 0] [count 0])
      (for-each
       (lambda (keys)
         (set! total (+ total (apply draw! keys)))
         (set! count (+ count 1)))
       (append-map (lambda (i)
                     (list '(down) '(down) '(right) '("a") '(enter) '("b" "c") '(up) '(end)
                           '(backspace) '(home) '((ctrl . #\k)) '(pagedown) '(down) '((ctrl . #\u))
                           '(pageup) '(pagedown) '((alt . #\u)) '(left) '("  ") '(down)))
                   (iota 12)))
      (test-assert "over a long session, a small part of redrawing every time"
                   (< total (* 0.15 count redraw))))
    (delete-file (editor-filename st))))

(test-end "editor")
