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
;;; Undo and redo are done here rather than with the cbuf's own undo
;;; records: the buffer's line list is made of immutable text-metrics
;;; records, so a snapshot of the list (plus the cursor) is cheap and
;;; restores exactly.

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

;; Most undo steps kept.
(define max-undo-steps 1000)

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

;; Undo snapshot of the buffer.
(define-record-type <snapshot>
  (make-snapshot metrics line x-data modified?)
  snapshot?
  (metrics snapshot-metrics)
  (line snapshot-line)
  (x-data snapshot-x-data)
  (modified? snapshot-modified?))

(define-record-type <editor-state>
  (%make-editor-state cbuf frame filename width height quit? status-message
                      prompt undo-stack redo-stack last-edit last-command
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
  (undo-stack editor-undo-stack set-editor-undo-stack!)
  (redo-stack editor-redo-stack set-editor-redo-stack!)
  ;; Kind of the edit made by the previous key ('typing, 'cut, ...), or
  ;; #f if that key didn't edit.  Used to group undo steps.
  (last-edit editor-last-edit set-editor-last-edit!)
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
                                   #f '() '() #f #f "" "")])
    (set-cbuf-form-size! cbuf (text-area-height height))   ; page size
    state))

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

(define (handle-prompt-key state key)
  (let* ([p (editor-prompt state)]
         [ch (key-char key)]
         [sym (key-symbol key)])
    (cond
     ;; ^C, Escape or end of input cancels any prompt
     [(or (and (key-ctrl? key) (eqv? ch #\c))
          (memq sym '(escape eof)))
      (cancel-prompt! state)
      (when (eq? sym 'eof) (set-editor-quit?! state #t))]

     [(eq? (prompt-kind p) 'yes-no)
      (cond
       [(and ch (not (key-modifier? key)) (memv ch '(#\y #\Y)))
        (finish-prompt! state #t)]
       [(and ch (not (key-modifier? key)) (memv ch '(#\n #\N)))
        (finish-prompt! state #f)]
       [else #f])]                      ; ignore anything else

     [(eq? sym 'enter)
      (finish-prompt! state (prompt-input p))]
     [(eq? sym 'backspace)
      (let ([input (prompt-input p)])
        (unless (string-null? input)
          (set-prompt-input! p (substring input 0 (- (string-length input) 1)))))]
     [(and (key-ctrl? key) (eqv? ch #\u))        ; ^U clears the line
      (set-prompt-input! p "")]
     [(insertable-char? key)
      (set-prompt-input! p (string-append (prompt-input p) (string ch)))]
     [(eq? sym 'tab)
      (set-prompt-input! p (string-append (prompt-input p) "\t"))]
     [else #f])))

;;; =================================================================
;;; UNDO
;;; =================================================================

(define (take-snapshot cbuf)
  (make-snapshot (cbuf-text-metrics cbuf) (cbuf-line-cur cbuf)
                 (cbuf-x-data cbuf) (cbuf-modified? cbuf)))

(define (restore-snapshot! cbuf snap)
  (set-cbuf-text-metrics! cbuf (snapshot-metrics snap))
  (set-cbuf-mark-set?! cbuf #f)
  (cbuf-set-y! cbuf (snapshot-line snap))
  (cbuf-set-x! cbuf (min (snapshot-x-data snap) (cbuf-text-cur-base-length cbuf)) 'data)
  (set-cbuf-modified?! cbuf (snapshot-modified? snap)))

(define (push-limited item stack)
  (let ([stack (cons item stack)])
    (if (> (length stack) max-undo-steps) (take stack max-undo-steps) stack)))

(define (edit! state kind thunk)
  "Run THUNK, which may change the buffer, as an undoable edit of KIND.
   Consecutive 'typing edits are undone together, up to a space."
  (let* ([cbuf (editor-cbuf state)]
         [before (take-snapshot cbuf)])
    (thunk)
    (if (eq? (cbuf-text-metrics cbuf) (snapshot-metrics before))
        (set-editor-last-edit! state #f)          ; nothing changed
        (begin
          (unless (and (eq? kind 'typing) (eq? (editor-last-edit state) 'typing))
            (set-editor-undo-stack! state (push-limited before (editor-undo-stack state))))
          (set-editor-redo-stack! state '())
          (set-editor-last-edit! state kind)))))

(define (cmd-undo state)
  (let ([stack (editor-undo-stack state)]
        [cbuf (editor-cbuf state)])
    (if (null? stack)
        (message! state "Nothing to undo")
        (begin
          (set-editor-redo-stack! state (cons (take-snapshot cbuf) (editor-redo-stack state)))
          (restore-snapshot! cbuf (car stack))
          (set-editor-undo-stack! state (cdr stack))
          (message! state "Undid edit")))))

(define (cmd-redo state)
  (let ([stack (editor-redo-stack state)]
        [cbuf (editor-cbuf state)])
    (if (null? stack)
        (message! state "Nothing to redo")
        (begin
          (set-editor-undo-stack! state (cons (take-snapshot cbuf) (editor-undo-stack state)))
          (restore-snapshot! cbuf (car stack))
          (set-editor-redo-stack! state (cdr stack))
          (message! state "Redid edit")))))

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

(define (cmd-cut-line state)
  "Cut the current line.  Consecutive cuts are collected together, so
   that one paste puts them all back."
  (let* ([cbuf (editor-cbuf state)]
         [last-line? (= (cbuf-line-cur cbuf) (- (cbuf-line-count cbuf) 1))]
         [text (string-append (cbuf-text-cur cbuf) (if last-line? "" "\n"))])
    (unless (and last-line? (string-null? text))
      (if last-line?
          ;; The last line has no newline to take: just empty it.
          (begin (cbuf-beginning-of-line! cbuf)
                 (cbuf-delete-to-end-of-line! cbuf))
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
  (let ([ch (key-char key)])
    (and ch
         (not (key-modifier? key))
         (or (char=? ch #\space)
             (char-graphic? ch)
             ;; combining marks etc. are not char-graphic? in all locales
             (> (char->integer ch) 127)))))

;; Key bindings: each entry is (KEY-SPEC COMMAND EDIT-KIND), where
;; KEY-SPEC is (ctrl . CHAR), (alt . CHAR) or a key symbol, and EDIT-KIND
;; is #f for commands that don't change the buffer, otherwise the undo
;; kind passed to edit!.
(define bindings
  `(((ctrl . #\s) ,cmd-save #f)
    ((ctrl . #\o) ,cmd-write-out #f)
    ((ctrl . #\x) ,cmd-exit #f)
    ((ctrl . #\q) ,cmd-force-quit #f)
    ((ctrl . #\c) ,cmd-show-position #f)
    ((ctrl . #\w) ,cmd-search #f)
    ((ctrl . #\_) ,cmd-goto-line #f)
    ((alt . #\g) ,cmd-goto-line #f)
    ((ctrl . #\k) ,cmd-cut-line cut-line)
    ((ctrl . #\u) ,cmd-paste paste)
    ((alt . #\u) ,cmd-undo #f)
    ((alt . #\e) ,cmd-redo #f)
    ((ctrl . #\a) ,cmd-home #f)
    ((ctrl . #\e) ,cmd-end #f)
    ((ctrl . #\y) ,cmd-page-up #f)
    ((ctrl . #\v) ,cmd-page-down #f)
    (up ,cmd-cursor-up #f)
    (down ,cmd-cursor-down #f)
    (left ,cmd-cursor-left #f)
    (right ,cmd-cursor-right #f)
    (home ,cmd-home #f)
    (end ,cmd-end #f)
    (page-up ,cmd-page-up #f)
    (page-down ,cmd-page-down #f)
    (backspace ,cmd-backspace delete)
    (delete ,cmd-delete delete)
    (enter ,cmd-enter newline)
    (tab ,(lambda (state) (cmd-insert-char state #\tab)) typing)
    (eof ,cmd-force-quit #f)))          ; input closed: nothing more to do

(define (key-spec key)
  (let ([ch (key-char key)])
    (cond
     [(and ch (key-ctrl? key) (not (key-alt? key))) (cons 'ctrl (char-downcase ch))]
     [(and ch (key-alt? key) (not (key-ctrl? key))) (cons 'alt (char-downcase ch))]
     [else (key-symbol key)])))

(define (handle-key state key)
  "Update STATE in response to KEY.  Returns STATE."
  (if (editor-prompt state)
      (handle-prompt-key state key)
      (let ([binding (assoc (key-spec key) bindings)])
        (cond
         [binding
          (let ([command (second binding)]
                [kind (third binding)])
            (if kind
                (edit! state kind (lambda () (command state)))
                (begin
                  (command state)
                  (set-editor-last-edit! state #f)))
            (set-editor-last-command! state (procedure-name command)))]
         [(insertable-char? key)
          (let ([ch (key-char key)])
            (edit! state 'typing (lambda () (cmd-insert-char state ch)))
            ;; a space ends the current group of typing
            (when (char-whitespace? ch) (set-editor-last-edit! state #f)))
          (set-editor-last-command! state 'insert)]
         [else
          (unknown-key state key)
          (set-editor-last-command! state #f)])))
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
    (let ([out (open-output-string)])
      (define (emit . strs) (for-each (lambda (s) (display s out)) strs))
      (emit (esc "?25l"))                ; hide cursor while drawing
      ;; Text area
      (let loop ([lines (frame-render-frame cbuf frame)] [row 1])
        (when (and (pair? lines) (<= row text-rows))
          (emit (goto row 1) (printable-string (car lines)) (esc "K"))
          (loop (cdr lines) (+ row 1))))
      (when (> height reserved-rows)
        (let ([help (cond [(not prompt) editing-help]
                          [(eq? (prompt-kind prompt) 'yes-no) yes-no-help]
                          [else text-prompt-help])])
          ;; Status line or prompt
          (emit (goto (- height 2) 1) (esc "7m")
                (printable-string
                 (if prompt
                     (fit (string-append (prompt-label prompt) (prompt-input prompt)) width)
                     (status-line state)))
                (esc "0m")
                (goto (- height 1) 1) (help-line (first help) width)
                (goto height 1) (help-line (second help) width))))
      ;; Cursor: in the prompt if one is open, else in the text
      (if (and prompt (> height reserved-rows))
          (emit (goto (- height 2)
                      (min width (+ 1 (string-length (prompt-label prompt))
                                    (string-length (prompt-input prompt)))))
                (esc "?25h"))
          (let ([pos (frame-get-cursor-position cbuf frame)])
            (when pos
              (emit (goto (+ (cdr pos) 1) (+ (car pos) 1)) (esc "?25h")))))
      (get-output-string out))))

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
