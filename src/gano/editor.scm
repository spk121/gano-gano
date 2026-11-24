;;; Gano Text Editor - Minimum Viable Product
;;; A simple but functional text editor with a nano-style interface.
;;;
;;; The editor is split into a pure part and a terminal part so that it
;;; can be tested without a terminal:
;;;
;;;   - make-editor-state / handle-key change the editor state in
;;;     response to key objects from (gano keys);
;;;   - render-screen turns the state into a string of ANSI output;
;;;   - editor-main wires those to the real terminal.
;;;
;;; Screen layout (H = terminal height):
;;;
;;;   rows 1 .. H-3   text area (a (gano frame) viewport on the buffer)
;;;   row  H-2        status line (reverse video)
;;;   rows H-1, H     key help

(define-module (gano editor)
  #:use-module (gano buffer)        ; Character buffer (all layers)
  #:use-module (gano frame)         ; Viewport onto the buffer
  #:use-module (gano keys)          ; Key objects
  #:use-module (gano char)          ; char-graphic?
  #:use-module (gano terminal)      ; Raw mode, ANSI output, key input
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-9)        ; Record types
  #:use-module (srfi srfi-13)       ; String utilities
  #:use-module (ice-9 format)
  #:use-module (ice-9 textual-ports)
  #:export (make-editor-state
            editor-state?
            editor-cbuf
            editor-frame
            editor-filename
            editor-width
            editor-height
            editor-quit?
            editor-status-message
            set-editor-status-message!
            editor-modified?

            load-buffer
            save-buffer
            handle-key
            editor-resize!
            render-screen
            editor-main))

;;; =================================================================
;;; EDITOR STATE
;;; =================================================================

;; Rows used below the text area: status line + two help lines.
(define reserved-rows 3)

(define-record-type <editor-state>
  (%make-editor-state cbuf frame filename width height quit? status-message)
  editor-state?
  (cbuf editor-cbuf set-editor-cbuf!)
  (frame editor-frame set-editor-frame!)
  (filename editor-filename set-editor-filename!)
  (width editor-width set-editor-width!)
  (height editor-height set-editor-height!)
  (quit? editor-quit? set-editor-quit?!)
  (status-message editor-status-message set-editor-status-message!))

(define (text-area-height height)
  (max 1 (- height reserved-rows)))

(define* (make-editor-state #:key (filename #f) (cbuf (make-cbuf))
                            (width 80) (height 24))
  "Create editor state for CBUF, shown on a WIDTH x HEIGHT screen."
  (%make-editor-state cbuf
                      (make-frame width (text-area-height height))
                      filename width height #f ""))

(define (editor-modified? state)
  "Has the buffer changed since it was loaded or last saved?"
  (cbuf-modified? (editor-cbuf state)))

(define (editor-resize! state width height)
  "Adapt the editor to a WIDTH x HEIGHT terminal."
  (set-editor-width! state width)
  (set-editor-height! state height)
  (set-frame-width! (editor-frame state) width)
  (set-frame-height! (editor-frame state) (text-area-height height)))

;;; =================================================================
;;; FILE OPERATIONS
;;; =================================================================

(define (load-buffer filename)
  "Return a fresh cbuf holding the contents of FILENAME (UTF-8), or an
   empty cbuf if FILENAME is #f or the file does not exist.  An existing file's line
   ending and presence or absence of a final newline are kept when it
   is saved; a new file is saved with a final newline."
  (let ([cbuf (if (and filename (file-exists? filename))
                  (text->cbuf (call-with-input-file filename get-string-all
                                #:encoding "UTF-8")
                              #:final-newline-policy 'preserve)
                  (make-cbuf))])
    ;; Loading is not an edit: nothing to undo, nothing unsaved.
    (cbuf-clear-undo-history! cbuf)
    (set-cbuf-modified?! cbuf #f)
    cbuf))

(define (save-buffer state)
  "Write the buffer to the editor's file and report it in the status line."
  (let ([filename (editor-filename state)]
        [cbuf (editor-cbuf state)])
    (call-with-output-file filename
      (lambda (port) (put-string port (cbuf->text cbuf)))
      #:encoding "UTF-8")
    (set-cbuf-modified?! cbuf #f)
    (let ([n (cbuf-line-count cbuf)])
      (set-editor-status-message!
       state (format #f "Wrote ~d line~a to ~a" n (if (= n 1) "" "s") filename)))))

;;; =================================================================
;;; COMMANDS
;;; =================================================================
;;; Each command takes the editor state and changes it in place.

(define (cmd-save state)
  (if (editor-filename state)
      (catch 'system-error
        (lambda () (save-buffer state))
        (lambda (key . args)
          (set-editor-status-message!
           state (format #f "Error writing ~a: ~a" (editor-filename state)
                         (strerror (system-error-errno (cons key args)))))))
      ;; Prompting for a name needs the minibuffer (not written yet).
      (set-editor-status-message! state "No file name: start gano with a file name to save")))

(define (cmd-quit state)
  (if (editor-modified? state)
      (set-editor-status-message!
       state "Buffer modified: ^S to save, ^Q to quit without saving")
      (set-editor-quit?! state #t)))

(define (cmd-force-quit state)
  (set-editor-quit?! state #t))

(define (cmd-show-position state)
  (let ([cbuf (editor-cbuf state)])
    (set-editor-status-message!
     state (format #f "line ~d/~d, col ~d"
                   (+ (cbuf-line-cur cbuf) 1)
                   (cbuf-line-count cbuf)
                   (+ (cbuf-x-data cbuf) 1)))))

(define (cmd-cursor-up state)    (cbuf-previous-line! (editor-cbuf state)))
(define (cmd-cursor-down state)  (cbuf-next-line! (editor-cbuf state)))

(define (cmd-cursor-left state)
  "Move left; at the start of a line, go to the end of the previous one."
  (let ([cbuf (editor-cbuf state)])
    (if (and (cbuf-beginning-of-line? cbuf) (> (cbuf-line-cur cbuf) 0))
        (begin (cbuf-previous-line! cbuf)
               (cbuf-end-of-line! cbuf))
        (cbuf-backward-char! cbuf))))

(define (cmd-cursor-right state)
  "Move right; at the end of a line, go to the start of the next one."
  (let ([cbuf (editor-cbuf state)])
    (if (and (cbuf-end-of-line? cbuf)
             (< (cbuf-line-cur cbuf) (- (cbuf-line-count cbuf) 1)))
        (begin (cbuf-next-line! cbuf)
               (cbuf-beginning-of-line! cbuf))
        (cbuf-forward-char! cbuf))))

(define (cmd-backspace state)
  "Delete the character before the cursor, joining with the previous
   line when at the start of a line."
  (let ([cbuf (editor-cbuf state)])
    (cond
     [(not (cbuf-beginning-of-line? cbuf))
      (cbuf-backspace! cbuf)]
     [(> (cbuf-line-cur cbuf) 0)
      (cbuf-previous-line! cbuf)
      (cbuf-end-of-line! cbuf)
      (cbuf-join-lines! cbuf)])))

(define (cmd-delete state)
  "Delete the character under the cursor, joining with the next line
   when at the end of a line."
  (let ([cbuf (editor-cbuf state)])
    (if (cbuf-end-of-line? cbuf)
        (cbuf-join-lines! cbuf)          ; no-op on the last line
        (cbuf-delete-char! cbuf))))

(define (cmd-enter state)
  (cbuf-insert-newline! (editor-cbuf state)))

(define (cmd-insert-char state char)
  (cbuf-insert-char! (editor-cbuf state) char))

;;; =================================================================
;;; KEY HANDLING
;;; =================================================================

(define (unknown-key state key)
  (set-editor-status-message!
   state (format #f "Unknown key: ~a" (key->string key))))

(define (insertable-char? key)
  (let ([ch (key-char key)])
    (and ch
         (not (key-modifier? key))
         (or (char=? ch #\space)
             (char-graphic? ch)
             ;; combining marks etc. are not char-graphic? in all locales
             (> (char->integer ch) 127)))))

(define (handle-key state key)
  "Update STATE in response to KEY.  Returns STATE."
  (cond
   ;; Control keys
   [(and (key-ctrl? key) (key-char key) (not (key-alt? key)))
    (case (key-char key)
      [(#\s) (cmd-save state)]
      [(#\x) (cmd-quit state)]
      [(#\q) (cmd-force-quit state)]
      [(#\c) (cmd-show-position state)]
      [else (unknown-key state key)])]

   ;; Special keys
   [(key-symbol key)
    (case (key-symbol key)
      [(up) (cmd-cursor-up state)]
      [(down) (cmd-cursor-down state)]
      [(left) (cmd-cursor-left state)]
      [(right) (cmd-cursor-right state)]
      [(backspace) (cmd-backspace state)]
      [(delete) (cmd-delete state)]
      [(enter) (cmd-enter state)]
      [(eof) (cmd-force-quit state)]     ; input closed: nothing more to do
      [else (unknown-key state key)])]

   [(insertable-char? key)
    (cmd-insert-char state (key-char key))]

   [else (unknown-key state key)])
  state)

;;; =================================================================
;;; RENDERING
;;; =================================================================

(define (esc . parts) (apply string-append "\x1b[" parts))
(define (goto row col) (esc (number->string row) ";" (number->string col) "H"))

(define (printable-string str)
  "Replace control characters, which would be interpreted by the
   terminal, with '?'."
  (string-map (lambda (ch)
                (let ([n (char->integer ch)])
                  (if (or (< n 32) (= n 127) (<= #x80 n #x9f)) #\? ch)))
              str))

(define (fit str width)
  "Pad or truncate STR to exactly WIDTH characters."
  (let ([len (string-length str)])
    (if (>= len width)
        (substring str 0 width)
        (string-append str (make-string (- width len) #\space)))))

(define (status-line state)
  (let* ([cbuf (editor-cbuf state)]
         [width (editor-width state)]
         [name (if (editor-filename state)
                   (basename (editor-filename state))
                   "New Buffer")]
         [left (string-append " " name (if (editor-modified? state) " (modified)" ""))]
         [right (format #f "Ln ~d, Col ~d "
                        (+ (cbuf-line-cur cbuf) 1) (+ (cbuf-x-data cbuf) 1))]
         [msg (editor-status-message state)]
         [middle (if (string-null? msg) "" (string-append "  [ " msg " ]"))]
         [left+middle (string-append left middle)]
         [gap (- width (string-length left+middle) (string-length right))])
    (if (>= gap 1)
        (string-append left+middle (make-string gap #\space) right)
        (fit left+middle width))))

(define help-lines
  '(("^S Save" "^X Exit" "^C Cur Pos")
    ("^Q Quit without saving" "Arrows Move" "Bksp/Del Delete")))

(define (help-line entries width)
  (let ([cell (max 1 (quotient width (length entries)))])
    (fit (string-concatenate (map (lambda (e) (fit e cell)) entries)) width)))

(define (render-screen state)
  "Return the ANSI output that redraws the whole screen for STATE.
   Also scrolls the frame so the cursor is visible."
  (let* ([cbuf (editor-cbuf state)]
         [frame (editor-frame state)]
         [width (editor-width state)]
         [height (editor-height state)]
         [text-rows (frame-height frame)])
    (frame-update-frame cbuf frame)
    (let ([out (open-output-string)])
      (define (emit . strs) (for-each (lambda (s) (display s out)) strs))
      (emit (esc "?25l"))                ; hide cursor while drawing
      ;; Text area
      (let loop ([lines (frame-render-frame cbuf frame)] [row 1])
        (when (and (pair? lines) (<= row text-rows))
          (emit (goto row 1) (printable-string (car lines)) (esc "K"))
          (loop (cdr lines) (+ row 1))))
      ;; Status line and help
      (when (> height reserved-rows)
        (emit (goto (- height 2) 1) (esc "7m")
              (printable-string (status-line state)) (esc "0m")
              (goto (- height 1) 1) (help-line (first help-lines) width)
              (goto height 1) (help-line (second help-lines) width)))
      ;; Cursor
      (let ([pos (frame-get-cursor-position cbuf frame)])
        (when pos
          (emit (goto (+ (cdr pos) 1) (+ (car pos) 1)) (esc "?25h"))))
      (get-output-string out))))

;;; =================================================================
;;; MAIN PROGRAM
;;; =================================================================

(define (draw state)
  (display (render-screen state))
  (force-output))

(define (main-loop state)
  (draw state)
  (let loop ()
    (unless (editor-quit? state)
      (let ([key (terminal-read-key)])
        ;; A message is shown until the next key press.
        (set-editor-status-message! state "")
        (handle-key state key)
        (unless (editor-quit? state)
          (let ([size (terminal-get-size)])
            (unless (and (= (car size) (editor-width state))
                         (= (cdr size) (editor-height state)))
              (editor-resize! state (car size) (cdr size)))))
        (draw state)
        (loop)))))

(define (usage program)
  (format (current-error-port) "Usage: ~a [FILE]~%" program))

(define (editor-main args)
  "Program entry point.  ARGS is the command line, program name first."
  (setlocale LC_ALL "")
  (let ([program (if (pair? args) (basename (car args)) "gano")]
        [files (if (pair? args) (cdr args) '())])
    (cond
     [(and (pair? files) (member (car files) '("-h" "--help")))
      (usage program)
      (exit 0)]
     [(> (length files) 1)
      (usage program)
      (exit 1)]
     [(not (isatty? (current-input-port)))
      (format (current-error-port) "~a: standard input is not a terminal~%" program)
      (exit 1)])
    (let* ([filename (and (pair? files) (car files))]
           [cbuf (catch #t
                   (lambda () (load-buffer filename))
                   (lambda (key . rest)
                     (format (current-error-port) "~a: cannot read ~a~%" program filename)
                     (exit 1)))]
           [size (terminal-get-size)]
           [state (make-editor-state #:filename filename #:cbuf cbuf
                                     #:width (car size) #:height (cdr size))])
      (set-port-encoding! (current-input-port) "UTF-8")
      (set-port-encoding! (current-output-port) "UTF-8")
      (set-editor-status-message!
       state (cond
              [(not filename) "New buffer"]
              [(file-exists? filename)
               (let ([n (cbuf-line-count cbuf)])
                 (format #f "Read ~d line~a" n (if (= n 1) "" "s")))]
              [else "New file"]))
      ;; An error inside the loop is caught and reported only after the
      ;; terminal is back to normal; otherwise the message would be
      ;; printed onto the alternate screen in raw mode and lost.
      (let ([failure #f])
        (call-with-raw-terminal
         (lambda ()
           (dynamic-wind
             (lambda ()
               (terminal-alternate-screen-enter)
               (terminal-clear-screen)
               (force-output))
             (lambda ()
               (catch #t
                 (lambda () (main-loop state))
                 (lambda (key . args) (set! failure (cons key args)))))
             (lambda ()
               (terminal-reset-attributes)
               (terminal-show-cursor)
               (terminal-alternate-screen-exit)
               (force-output)))))
        (when failure
          (format (current-error-port) "~a: internal error: ~s~%" program failure)
          (when (editor-modified? state)
            ;; Like nano, keep the user's work in FILE.save.
            (let ([backup (string-append (or filename "gano") ".save")])
              (catch #t
                (lambda ()
                  (call-with-output-file backup
                    (lambda (port) (put-string port (cbuf->text (editor-cbuf state))))
                    #:encoding "UTF-8")
                  (format (current-error-port) "~a: unsaved changes written to ~a~%"
                          program backup))
                (lambda _
                  (format (current-error-port) "~a: could not write ~a; unsaved changes lost~%"
                          program backup)))))
          (exit 1))))))
