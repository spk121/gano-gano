;;; Tests for the (gano editor) MVP: drive the editor with key objects
;;; and check the buffer, the saved file and the rendered screen.

(define-module (test editor)
  #:use-module (srfi srfi-64)
  #:use-module (gano editor)
  #:use-module (gano buffer)
  #:use-module (gano keys)
  #:use-module (ice-9 textual-ports))

(setlocale LC_ALL "C.UTF-8")

;;; Helpers

(define (char-key ch) (make-key #:char ch))
(define (sym-key s) (make-key #:symbol s))
(define (ctrl-key* ch) (make-key #:char ch #:ctrl? #t))

(define (type! state . items)
  "Feed ITEMS to the editor: strings are typed character by character,
   symbols are special keys, and (ctrl . #\\x) pairs are control keys."
  (for-each
   (lambda (item)
     (cond
      [(string? item) (string-for-each (lambda (ch) (handle-key state (char-key ch))) item)]
      [(symbol? item) (handle-key state (sym-key item))]
      [(and (pair? item) (eq? (car item) 'ctrl)) (handle-key state (ctrl-key* (cdr item)))]
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
    (test-assert "^X refuses with unsaved changes" (not (editor-quit? st)))
    (test-assert "and says why" (string-prefix? "Buffer modified" (editor-status-message st)))
    (type! st '(ctrl . #\q))
    (test-assert "^Q quits anyway" (editor-quit? st))
    (test-equal "file untouched" "text\n" (read-file (editor-filename st)))
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
    (test-assert "help is drawn" (string-contains screen "^X Exit"))
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

(test-end "editor")
