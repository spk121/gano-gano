;;; Gano Text Editor
;;; A simple text editor with a nano-style interface.
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
;;;   row  H-2        status line, or the prompt while one is open
;;;   rows H-1, H     key help
;;;
;;; Undo and redo use the buffer's own undo history (cbuf-undo,
;;; cbuf-redo!).  Typing is undone a word at a time: the first character
;;; of a run of typing records an undo step, and the characters typed
;;; straight after it are inserted with #:undo? #f, so that step covers
;;; the whole run.

(define-module (gano editor)
  #:use-module (gano buffer)        ; Character buffer (all layers)
  #:use-module (gano frame)         ; Viewport onto the buffer
  #:use-module (gano keys)          ; Key objects and key names
  #:use-module (gano terminal)      ; Raw mode, ANSI output, key input
  #:use-module (gano rendering)     ; SGR attributes -> ANSI
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
            editor-prompt-label
            editor-prompt-input
            editor-clipboard

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

;; An open prompt in the status line.
;;   kind      'text (type a line, Enter accepts) or 'yes-no
;;   label     shown before the input, e.g. "Search: "
;;   input     what has been typed so far
;;   on-done   (lambda (state answer)) called with the input string,
;;             or #t/#f for a yes-no prompt.  Not called on cancel.
(define-record-type <prompt>
  (make-prompt kind label input on-done)
  prompt?
  (kind prompt-kind)
  (label prompt-label)
  (input prompt-input set-prompt-input!)
  (on-done prompt-on-done))

(define-record-type <editor-state>
  (%make-editor-state cbuf frame filename width height quit? status-message
                      prompt typing-run saved-undo-top last-command
                      clipboard last-search)
  editor-state?
  (cbuf editor-cbuf set-editor-cbuf!)
  (frame editor-frame set-editor-frame!)
  (filename editor-filename set-editor-filename!)
  (width editor-width set-editor-width!)
  (height editor-height set-editor-height!)
  (quit? editor-quit? set-editor-quit?!)
  (status-message editor-status-message set-editor-status-message!)
  (prompt editor-prompt set-editor-prompt!)
  ;; While a run of typing is going on, the (line . x-data) where the
  ;; next typed character continues it; otherwise #f.
  (typing-run editor-typing-run set-editor-typing-run!)
  ;; The buffer's newest undo record when the file was last loaded or
  ;; saved (#f if there was none): after an undo or redo, the buffer
  ;; matches the file exactly when that record is on top again.
  (saved-undo-top editor-saved-undo-top set-editor-saved-undo-top!)
  ;; Name of the previous command; consecutive ^K cuts accumulate.
  (last-command editor-last-command set-editor-last-command!)
  (clipboard editor-clipboard set-editor-clipboard!)
  (last-search editor-last-search set-editor-last-search!))

(define (text-area-height height)
  (max 1 (- height reserved-rows)))

(define* (make-editor-state #:key (filename #f) (cbuf (make-cbuf))
                            (width 80) (height 24))
  "Create editor state for CBUF, shown on a WIDTH x HEIGHT screen."
  (let ([state (%make-editor-state cbuf
                                   (make-frame width (text-area-height height))
                                   filename width height #f ""
                                   #f #f (undo-top cbuf) #f "" "")])
    (set-cbuf-form-size! cbuf (text-area-height height))   ; page size
    state))

(define (undo-top cbuf)
  (let ([records (cbuf-undo-list cbuf)])
    (and (pair? records) (car records))))

(define (editor-modified? state)
  "Has the buffer changed since it was loaded or last saved?"
  (cbuf-modified? (editor-cbuf state)))

(define (editor-prompt-label state)
  "The label of the open prompt, or #f if no prompt is open."
  (let ([p (editor-prompt state)]) (and p (prompt-label p))))

(define (editor-prompt-input state)
  "What has been typed at the open prompt, or #f if none is open."
  (let ([p (editor-prompt state)]) (and p (prompt-input p))))

(define (editor-resize! state width height)
  "Adapt the editor to a WIDTH x HEIGHT terminal."
  (set-editor-width! state width)
  (set-editor-height! state height)
  (set-frame-width! (editor-frame state) width)
  (set-frame-height! (editor-frame state) (text-area-height height))
  (set-cbuf-form-size! (editor-cbuf state) (text-area-height height)))

(define (message! state fmt . args)
  (set-editor-status-message! state (apply format #f fmt args)))

;;; =================================================================
;;; FILE OPERATIONS
;;; =================================================================

(define (load-buffer filename)
  "Return a fresh cbuf holding the contents of FILENAME (UTF-8), or an
   empty cbuf if FILENAME is #f or the file does not exist.  An existing
   file's line ending and presence or absence of a final newline are
   kept when it is saved; a new file is saved with a final newline."
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
    (set-editor-saved-undo-top! state (undo-top cbuf))
    (let ([n (cbuf-line-count cbuf)])
      (message! state "Wrote ~d line~a to ~a" n (if (= n 1) "" "s") filename))))

(define (try-save state)
  "Save, reporting any error in the status line.  Returns #t on success."
  (catch 'system-error
    (lambda () (save-buffer state) #t)
    (lambda (key . args)
      (message! state "Error writing ~a: ~a" (editor-filename state)
                (strerror (system-error-errno (cons key args))))
      #f)))

;;; =================================================================
;;; PROMPTS
;;; =================================================================

(define (ask-text! state label default on-done)
  "Open a text prompt showing LABEL, with DEFAULT already typed."
  (set-editor-prompt! state (make-prompt 'text label default on-done)))

(define (ask-yes-no! state label on-done)
  "Open a Y/N prompt showing LABEL."
  (set-editor-prompt! state (make-prompt 'yes-no label "" on-done)))

(define (cancel-prompt! state)
  (set-editor-prompt! state #f)
  (message! state "Cancelled"))

(define (finish-prompt! state answer)
  "Close the prompt, then call its continuation (which may open another)."
  (let ([on-done (prompt-on-done (editor-prompt state))])
    (set-editor-prompt! state #f)
    (on-done state answer)))

(define (key-is? key name)
  "Is KEY the key called NAME (in (gano keys) notation, e.g. \"^C\")?"
  (key-equivalent? key (string->key name)))

(define (handle-prompt-key state key)
  (let* ([p (editor-prompt state)]
         [ch (key-char key)])
    (cond
     ;; ^C, Escape or end of input cancels any prompt
     [(or (key-is? key "^C") (key-is? key "escape") (eq? (key-symbol key) 'eof))
      (cancel-prompt! state)
      (when (eq? (key-symbol key) 'eof) (set-editor-quit?! state #t))]

     [(eq? (prompt-kind p) 'yes-no)
      (cond
       [(or (key-is? key "y") (key-is? key "Y")) (finish-prompt! state #t)]
       [(or (key-is? key "n") (key-is? key "N")) (finish-prompt! state #f)]
       [else #f])]                      ; ignore anything else

     [(key-is? key "enter")
      (finish-prompt! state (prompt-input p))]
     [(key-is? key "backspace")
      (let ([input (prompt-input p)])
        (unless (string-null? input)
          (set-prompt-input! p (substring input 0 (- (string-length input) 1)))))]
     [(key-is? key "^U")                         ; ^U clears the line
      (set-prompt-input! p "")]
     [(insertable-char? key)
      (set-prompt-input! p (string-append (prompt-input p) (string ch)))]
     [(key-is? key "tab")
      (set-prompt-input! p (string-append (prompt-input p) "\t"))]
     [else #f])))

;;; =================================================================
;;; UNDO
;;; =================================================================

(define (sync-modified! state)
  "After an undo or redo: modified unless back at the saved state"
  (let ([cbuf (editor-cbuf state)])
    (set-cbuf-modified?! cbuf (not (eq? (undo-top cbuf) (editor-saved-undo-top state))))))

(define (cmd-undo state)
  (let ([cbuf (editor-cbuf state)])
    (if (cbuf-can-undo? cbuf)
        (begin
          (cbuf-undo cbuf)
          (sync-modified! state)
          (message! state "Undid edit"))
        (message! state "Nothing to undo"))))

(define (cmd-redo state)
  (let ([cbuf (editor-cbuf state)])
    (if (cbuf-can-redo? cbuf)
        (begin
          (cbuf-redo! cbuf)
          (sync-modified! state)
          (message! state "Redid edit"))
        (message! state "Nothing to redo"))))

;;; =================================================================
;;; COMMANDS
;;; =================================================================
;;; Each command takes the editor state and changes it in place.

;; --- Files and exiting ---

(define (write-file-as! state name then)
  "Save the buffer as NAME (asking before overwriting another existing
   file) and call THEN with the state if the save succeeds."
  (let ([do-write (lambda (state)
                    (set-editor-filename! state name)
                    (when (try-save state) (then state)))])
    (if (and (file-exists? name)
             (not (equal? name (editor-filename state))))
        (ask-yes-no! state (format #f "File \"~a\" exists; overwrite? (Y/N) " name)
                     (lambda (state yes?)
                       (if yes? (do-write state) (message! state "Cancelled"))))
        (do-write state))))

(define* (cmd-write-out state #:optional (then (lambda (state) #f)))
  "Ask for a file name and save under it; THEN runs after a good save."
  (ask-text! state "File Name to Write: " (or (editor-filename state) "")
             (lambda (state name)
               (if (string-null? name)
                   (message! state "Cancelled")
                   (write-file-as! state name then)))))

(define (cmd-save state)
  (if (editor-filename state)
      (try-save state)
      (cmd-write-out state)))

(define (cmd-exit state)
  (if (editor-modified? state)
      (ask-yes-no! state "Save modified buffer? (Y/N, ^C to cancel) "
                   (lambda (state yes?)
                     (if yes?
                         (cmd-write-out state (lambda (state) (set-editor-quit?! state #t)))
                         (set-editor-quit?! state #t))))
      (set-editor-quit?! state #t)))

(define (cmd-force-quit state)
  (set-editor-quit?! state #t))

;; --- Information ---

(define (cmd-show-position state)
  (let ([cbuf (editor-cbuf state)])
    (message! state "line ~d/~d, col ~d"
              (+ (cbuf-line-cur cbuf) 1)
              (cbuf-line-count cbuf)
              (+ (cbuf-x-data cbuf) 1))))

;; --- Movement ---

(define (cmd-cursor-up state)    (cbuf-previous-line! (editor-cbuf state)))
(define (cmd-cursor-down state)  (cbuf-next-line! (editor-cbuf state)))
(define (cmd-home state)         (cbuf-beginning-of-line! (editor-cbuf state)))
(define (cmd-end state)          (cbuf-end-of-line! (editor-cbuf state)))
(define (cmd-page-up state)      (cbuf-page-up! (editor-cbuf state)))
(define (cmd-page-down state)    (cbuf-page-down! (editor-cbuf state)))

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

(define (goto-position! cbuf line index)
  "Put the cursor on LINE (0-based) at string INDEX of that line."
  (cbuf-set-y! cbuf line)
  (cbuf-set-x! cbuf (cbuf-x-index->x-data cbuf index) 'data))

(define (cmd-goto-line state)
  (ask-text! state "Enter line number, column number: " ""
             (lambda (state answer)
               (let* ([fields (map string-trim-both (string-split answer #\,))]
                      [line (and (pair? fields) (string->number (car fields)))]
                      [col (if (and (pair? fields) (pair? (cdr fields)))
                               (string->number (cadr fields))
                               1)]
                      [cbuf (editor-cbuf state)])
                 (if (not (and (exact-integer? line) (exact-integer? col)))
                     (message! state "Invalid line or column number")
                     (begin
                       (cbuf-set-y! cbuf (max 0 (min (- line 1) (- (cbuf-line-count cbuf) 1))))
                       (cbuf-set-x! cbuf (max 0 (min (- col 1) (cbuf-text-cur-base-length cbuf)))
                                    'data)))))))

;; --- Search ---

(define (find-next cbuf pattern)
  "Find PATTERN (ignoring case) after the cursor, wrapping at the end of
   the buffer.  Returns (line index wrapped?) or #f."
  (let* ([lines (list->vector (cbuf-text cbuf))]
         [n (vector-length lines)]
         [line0 (cbuf-line-cur cbuf)]
         [index0 (cbuf-x-data->x-index cbuf (cbuf-x-data cbuf))])
    (define (search-line line start)
      (let ([text (vector-ref lines line)])
        (and (<= start (string-length text))
             (string-contains-ci text pattern start))))
    (let loop ([i 0])
      (and (<= i n)                     ; n+1 lines: line0 is visited twice
           (let* ([line (modulo (+ line0 i) n)]
                  [start (if (= i 0) (+ index0 1) 0)]
                  [hit (search-line line start)])
             (cond
              ;; on the second visit to line0 only matches up to the cursor count
              [(and hit (= i n) (> hit index0)) #f]
              [hit (list line hit (or (> (+ line0 i) (- n 1)) (= i n)))]
              [else (loop (+ i 1))]))))))

(define (cmd-search state)
  (let ([previous (editor-last-search state)])
    (ask-text! state
               (if (string-null? previous)
                   "Search: "
                   (format #f "Search [~a]: " previous))
               ""
               (lambda (state answer)
                 (let ([pattern (if (string-null? answer) previous answer)]
                       [cbuf (editor-cbuf state)])
                   (if (string-null? pattern)
                       (message! state "Cancelled")
                       (begin
                         (set-editor-last-search! state pattern)
                         (let ([start (list (cbuf-line-cur cbuf)
                                            (cbuf-x-data->x-index cbuf (cbuf-x-data cbuf)))]
                               [hit (find-next cbuf pattern)])
                           (cond
                            [(not hit)
                             (message! state "\"~a\" not found" pattern)]
                            [(equal? (take hit 2) start)
                             (message! state "This is the only occurrence")]
                            [else
                             (goto-position! cbuf (first hit) (second hit))
                             (when (third hit) (message! state "Search wrapped"))])))))))))

;; --- Editing ---

(define (cmd-backspace state)
  "Delete the character before the cursor, joining with the previous
   line when at the start of a line."
  (let ([cbuf (editor-cbuf state)])
    (cond
     [(not (cbuf-beginning-of-line? cbuf))
      (cbuf-backspace! cbuf)]
     [(> (cbuf-line-cur cbuf) 0)
      ;; record undo before moving, so undo puts the cursor back here
      (let ([line (cbuf-line-cur cbuf)])
        (cbuf-save-line-range-undo! cbuf (- line 1) line)
        (cbuf-previous-line! cbuf)
        (cbuf-end-of-line! cbuf)
        (cbuf-join-lines! cbuf #:undo? #f))])))

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
  "Insert CHAR.  Continuing a run of typing (no other key since, cursor
   where the run left it) adds to the run's undo step; whitespace ends
   the run."
  (let* ([cbuf (editor-cbuf state)]
         [continue? (equal? (editor-typing-run state)
                            (cons (cbuf-line-cur cbuf) (cbuf-x-data cbuf)))])
    (cbuf-insert-char! cbuf char #:undo? (not continue?))
    (set-editor-typing-run! state
                            (and (not (char-whitespace? char))
                                 (cons (cbuf-line-cur cbuf) (cbuf-x-data cbuf))))))

(define (cmd-cut-line state)
  "Cut the current line.  Consecutive cuts are collected together, so
   that one paste puts them all back."
  (let* ([cbuf (editor-cbuf state)]
         [last-line? (= (cbuf-line-cur cbuf) (- (cbuf-line-count cbuf) 1))]
         [text (string-append (cbuf-text-cur cbuf) (if last-line? "" "\n"))])
    (unless (and last-line? (string-null? text))
      (if last-line?
          ;; The last line has no newline to take: just empty it.
          (begin (cbuf-save-line-range-undo! cbuf (cbuf-line-cur cbuf) (cbuf-line-cur cbuf))
                 (cbuf-beginning-of-line! cbuf)
                 (cbuf-delete-to-end-of-line! cbuf #:undo? #f))
          (cbuf-cut-line! cbuf))
      (set-editor-clipboard! state
                             (if (eq? (editor-last-command state) 'cmd-cut-line)
                                 (string-append (editor-clipboard state) text)
                                 text)))))

(define (cmd-paste state)
  (let ([text (editor-clipboard state)])
    (if (string-null? text)
        (message! state "Nothing to paste")
        (cbuf-insert-string! (editor-cbuf state) text))))

;;; =================================================================
;;; KEY HANDLING
;;; =================================================================

(define (unknown-key state key)
  (message! state "Unknown key: ~a" (key->string key)))

(define (insertable-char? key)
  "Does KEY type a character into the text?"
  (or (key-printable? key)
      ;; characters char-graphic? doesn't cover (combining marks etc.)
      (let ([ch (key-char key)])
        (and ch (not (key-modifier? key)) (> (char->integer ch) 127)))))

;; Key bindings, by key name in (gano keys) notation.  Alt+letter is
;; case-insensitive, as in nano ("A-u" also covers Alt+U).
(define bindings
  `(("^S" . ,cmd-save)
    ("^O" . ,cmd-write-out)
    ("^X" . ,cmd-exit)
    ("^Q" . ,cmd-force-quit)
    ("^C" . ,cmd-show-position)
    ("^W" . ,cmd-search)
    ("^_" . ,cmd-goto-line)
    ("A-g" . ,cmd-goto-line)
    ("^K" . ,cmd-cut-line)
    ("^U" . ,cmd-paste)
    ("A-u" . ,cmd-undo)
    ("A-e" . ,cmd-redo)
    ("^A" . ,cmd-home)
    ("^E" . ,cmd-end)
    ("^Y" . ,cmd-page-up)
    ("^V" . ,cmd-page-down)
    ("up" . ,cmd-cursor-up)
    ("down" . ,cmd-cursor-down)
    ("left" . ,cmd-cursor-left)
    ("right" . ,cmd-cursor-right)
    ("home" . ,cmd-home)
    ("end" . ,cmd-end)
    ("pageup" . ,cmd-page-up)
    ("pagedown" . ,cmd-page-down)
    ("backspace" . ,cmd-backspace)
    ("delete" . ,cmd-delete)
    ("enter" . ,cmd-enter)
    ("eof" . ,cmd-force-quit)))         ; input closed: nothing more to do

(define (binding-name key)
  "The canonical name KEY is bound under"
  (key->string
   (if (and (key-alt? key) (key-char key) (not (key-ctrl? key)))
       (make-key #:char (char-downcase (key-char key)) #:alt? #t #:shift? (key-shift? key))
       key)))

(define binding-table
  (let ([table (make-hash-table)])
    (for-each (lambda (b)
                (hash-set! table
                           (if (string=? (car b) "eof") "eof" (binding-name (string->key (car b))))
                           (cdr b)))
              bindings)
    table))

(define (key-command key)
  "The command bound to KEY, or #f"
  (hash-ref binding-table (binding-name key) #f))

(define (handle-key state key)
  "Update STATE in response to KEY.  Returns STATE."
  (if (editor-prompt state)
      (handle-prompt-key state key)
      (let ([command (key-command key)])
        (cond
         [(or (insertable-char? key) (key-is? key "tab"))
          (cmd-insert-char state (or (key-char key) #\tab))
          (set-editor-last-command! state 'insert)]
         [command
          (set-editor-typing-run! state #f)
          (command state)
          (set-editor-last-command! state (procedure-name command))]
         [else
          (set-editor-typing-run! state #f)
          (unknown-key state key)
          (set-editor-last-command! state #f)])))
  state)

;;; =================================================================
;;; RENDERING
;;; =================================================================

(define reverse-video (make-sgr #:polarity 'polarity-negative))

(define (printable-string str)
  "Replace control characters, which would be interpreted by the
   terminal, with '?'.  (Buffer text is already made printable by
   text-metrics; this is for file names and prompt input.)"
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

(define editing-help
  '(("^S Save" "^O Write Out" "^W Where Is" "^K Cut" "^U Paste" "M-U Undo")
    ("^X Exit" "^Q Discard" "^_ Go To Line" "^C Location" "^A/^E Home/End" "M-E Redo")))

(define text-prompt-help
  '(("Enter Accept") ("^C Cancel")))

(define yes-no-help
  '(("Y Yes") ("N No" "^C Cancel")))

(define (help-line entries width)
  (let ([cell (max 1 (quotient width (max 1 (length entries))))])
    (fit (string-concatenate (map (lambda (e) (fit e cell)) entries)) width)))

(define (render-screen state)
  "Return the ANSI output that redraws the whole screen for STATE.
   Also scrolls the frame so the cursor is visible."
  (let* ([cbuf (editor-cbuf state)]
         [frame (editor-frame state)]
         [width (editor-width state)]
         [height (editor-height state)]
         [text-rows (frame-height frame)]
         [prompt (editor-prompt state)])
    (frame-update-frame cbuf frame)
    (with-output-to-string
      (lambda ()
        (terminal-hide-cursor)             ; while drawing
        ;; Text area, with the text's attributes
        (let loop ([lines (frame-render-frame-with-sgr cbuf frame)] [row 1])
          (when (and (pair? lines) (<= row text-rows))
            (terminal-cursor-position row 1)
            (display (sgr-render-text (car (car lines)) (cdr (car lines))))
            (terminal-clear-to-eol)
            (loop (cdr lines) (+ row 1))))
        (when (> height reserved-rows)
          (let ([help (cond [(not prompt) editing-help]
                            [(eq? (prompt-kind prompt) 'yes-no) yes-no-help]
                            [else text-prompt-help])])
            ;; Status line or prompt, in reverse video
            (terminal-cursor-position (- height 2) 1)
            (display (sgr->ansi-sequence reverse-video))
            (display (printable-string
                      (if prompt
                          (fit (string-append (prompt-label prompt) (prompt-input prompt)) width)
                          (status-line state))))
            (terminal-reset-attributes)
            (terminal-cursor-position (- height 1) 1)
            (display (help-line (first help) width))
            (terminal-cursor-position height 1)
            (display (help-line (second help) width))))
        ;; Cursor: in the prompt if one is open, else in the text
        (if (and prompt (> height reserved-rows))
            (begin
              (terminal-cursor-position (- height 2)
                                        (min width (+ 1 (string-length (prompt-label prompt))
                                                      (string-length (prompt-input prompt)))))
              (terminal-show-cursor))
            (let ([pos (frame-get-cursor-position cbuf frame)])
              (when pos
                (terminal-cursor-position (+ (cdr pos) 1) (+ (car pos) 1))
                (terminal-show-cursor))))))))

;;; =================================================================
;;; MAIN PROGRAM
;;; =================================================================

(define (draw state)
  (display (render-screen state))
  (force-output))

(define (check-size! state)
  "Re-read the terminal size; return #t if it changed."
  (let ([size (terminal-get-size)])
    (and (not (and (= (car size) (editor-width state))
                   (= (cdr size) (editor-height state))))
         (begin (editor-resize! state (car size) (cdr size)) #t))))

(define (wait-for-key port timeout-us)
  "Return #t once a key is waiting on PORT, or #f after TIMEOUT-US
   microseconds.  (Guile defers signal handlers while blocked in
   read-char, so waiting here is what lets a resize redraw promptly.)"
  (or (char-ready? port)
      (catch 'system-error
        (lambda ()
          (pair? (car (select (list port) '() '() 0 timeout-us))))
        (lambda _ #f))))                 ; EINTR: let the caller look again

(define (main-loop state)
  ;; SIGWINCH only sets a flag; the loop notices it between waits.
  (let ([old-handler (sigaction SIGWINCH)]
        [resized? #f]
        [port (current-input-port)])
    (dynamic-wind
      (lambda ()
        (sigaction SIGWINCH (lambda (sig) (set! resized? #t))))
      (lambda ()
        (draw state)
        (let loop ()
          (unless (editor-quit? state)
            (when resized?
              (set! resized? #f)
              (when (check-size! state) (draw state)))
            (when (wait-for-key port 250000)
              (let ([key (terminal-read-key)])
                ;; A message is shown until the next key press.
                (set-editor-status-message! state "")
                (handle-key state key)
                ;; Skip redrawing while more input is queued (e.g. a paste).
                (unless (and (not (editor-quit? state)) (char-ready? port))
                  (draw state))))
            (loop))))
      (lambda ()
        (sigaction SIGWINCH (car old-handler) (cdr old-handler))))))

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
