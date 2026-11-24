;;; Tests for the (gano editor) MVP: drive the editor with key objects
;;; and check the buffer, the saved file and the rendered screen.

(define-module (test editor)
  #:use-module (srfi srfi-64)
  #:use-module (gano editor)
  #:use-module (gano buffer)
  #:use-module (gano keys)
  #:use-module (gano commands)
  #:use-module (ice-9 textual-ports))

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
    (test-assert "help is drawn" (string-contains screen "^S Sa"))
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
    (test-equal "and replaces" "cat cow cat\n" (buffer-text st))
    (type! st '(ctrl . #\\) "cat" 'enter '(ctrl . #\c))
    (test-equal "^C at any prompt cancels the command" "cat cow cat\n" (buffer-text st))
    (test-equal "and says so" "Cancelled" (editor-status-message st))
    (type! st '(ctrl . #\\) 'enter)
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
    (type! st '(alt . #\x))
    (test-equal "an unbound Alt key is unknown" "Unknown key: A-x" (editor-status-message st))
    (handle-key st (make-key #:symbol 'down #:alt? #t))
    (test-equal "A-down scrolls the view" 1
                ((@ (gano frame) frame-y-start) (editor-frame st)))
    (delete-file (editor-filename st))))

(test-group "prompt rendering"
  (let ([st (open-editor "x\n" #:width 40 #:height 10)])
    (type! st '(ctrl . #\w) "ab")
    (let ([screen (render-screen st)])
      (test-assert "prompt drawn on the status row" (string-contains screen "\x1b[8;1H\x1b[7mSearch: ab"))
      (test-assert "prompt help" (string-contains screen "^C Cancel"))
      (test-assert "cursor in the prompt" (string-suffix? "\x1b[8;11H\x1b[?25h" screen)))
    (delete-file (editor-filename st))))

(test-end "editor")
