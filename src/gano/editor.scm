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
;;; Keys are looked up in a command table (see (gano commands)) under
;;; the editor's current mode: MMAIN while editing, or the mode of the
;;; open prompt (MSEARCH, MGOTOLINE, MYESNO, ...).  The table is the
;;; standard one with the editor's own commands put in place of the
;;; standard commands of the same names: saving and exiting; versions
;;; of search, go to line, cut, paste, undo and redo that know about the
;;; editor's state; the prompt keys (accept, cancel, ...); and A-x, which
;;; runs any main-mode command by name.  A command that needs input from
;;; the user gets it through prompts in the status line before it runs.
;;; Printable characters and Tab are typed directly, into the text or
;;; into the open prompt.
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
  #:use-module (gano commands)      ; Command table: names, modes, shortcuts
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-9)        ; Record types
  #:use-module (srfi srfi-13)       ; String utilities
  #:use-module (ice-9 format)
  #:use-module (ice-9 match)
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
            editor-mode
            editor-commands

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
;;   mode      the editor mode while the prompt is open
(define-record-type <prompt>
  (make-prompt kind label input on-done mode)
  prompt?
  (kind prompt-kind)
  (label prompt-label)
  (input prompt-input set-prompt-input!)
  (on-done prompt-on-done)
  (mode prompt-mode))

(define-record-type <editor-state>
  (%make-editor-state cbuf frame filename width height quit? status-message
                      prompt typing-run saved-undo-top last-command
                      clipboard last-search base-mode help)
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
  (last-search editor-last-search set-editor-last-search!)
  ;; The mode when no prompt is open
  (base-mode editor-base-mode set-editor-base-mode!)
  ;; While the help screen is shown, (CBUF . FRAME) holding the help
  ;; text; otherwise #f
  (help editor-help set-editor-help!))

(define (text-area-height height)
  (max 1 (- height reserved-rows)))

(define* (make-editor-state #:key (filename #f) (cbuf (make-cbuf))
                            (width 80) (height 24))
  "Create editor state for CBUF, shown on a WIDTH x HEIGHT screen."
  (let ([state (%make-editor-state cbuf
                                   (make-frame width (text-area-height height))
                                   filename width height #f ""
                                   #f #f (undo-top cbuf) #f "" "" MMAIN #f)])
    (set-cbuf-form-size! cbuf (text-area-height height))   ; page size
    state))

(define (undo-top cbuf)
  (let ([records (cbuf-undo-list cbuf)])
    (and (pair? records) (car records))))

(define (editor-modified? state)
  "Has the buffer changed since it was loaded or last saved?"
  (cbuf-modified? (editor-cbuf state)))

(define (editor-mode state)
  "The mode keys are looked up in: the open prompt's, else the base mode"
  (let ([p (editor-prompt state)])
    (if p (prompt-mode p) (editor-base-mode state))))

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
  (for-each (lambda (cbuf+frame)
              (set-frame-width! (cdr cbuf+frame) width)
              (set-frame-height! (cdr cbuf+frame) (text-area-height height))
              (set-cbuf-form-size! (car cbuf+frame) (text-area-height height)))
            (cons (cons (editor-cbuf state) (editor-frame state))
                  (if (editor-help state) (list (editor-help state)) '()))))

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

(define* (ask-text! state label default on-done #:key (mode MPROMPT))
  "Open a text prompt in MODE showing LABEL, with DEFAULT already typed."
  (set-editor-prompt! state (make-prompt 'text label default on-done mode)))

(define (ask-yes-no! state label on-done)
  "Open a Y/N prompt showing LABEL."
  (set-editor-prompt! state (make-prompt 'yes-no label "" on-done MYESNO)))

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

(define (prompt-accept! state)
  (finish-prompt! state (prompt-input (editor-prompt state))))

(define (prompt-backspace! state)
  (let* ([p (editor-prompt state)]
         [input (prompt-input p)])
    (unless (string-null? input)
      (set-prompt-input! p (substring input 0 (- (string-length input) 1))))))

(define (prompt-clear! state)
  (set-prompt-input! (editor-prompt state) ""))

(define (prompt-type! state char)
  (let ([p (editor-prompt state)])
    (set-prompt-input! p (string-append (prompt-input p) (string char)))))

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
                   (write-file-as! state name then)))
             #:mode MWRITEFILE))

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
                                    'data)))))
             #:mode MGOTOLINE))

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
                             (when (third hit) (message! state "Search wrapped"))]))))))
               #:mode MSEARCH)))

;; --- Editing ---

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
                             (if (equal? (editor-last-command state) "cut-line")
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

;; The editor's own commands.  They take their state from the command
;; context and ask any questions themselves.
(define (editor-command name help proc . keys)
  (make-command name help (lambda (ctx) (proc (command-context-editor ctx)))
                #:modes `((,MMAIN ,@keys))))

;; A command for the keys KEYS in each of MODES
(define (prompt-command name help proc modes . keys)
  (make-command name help (lambda (ctx) (proc (command-context-editor ctx)))
                #:modes (map (lambda (mode) (cons mode keys)) modes)))

;; --- The help screen (^G) ---

(define (pad str width)
  (if (>= (string-length str) width)
      (string-append str " ")
      (string-append str (make-string (- width (string-length str)) #\space))))

(define (help-entry command mode)
  (string-append (pad (command-name command) 12)
                 (pad (string-join (command-shortcuts command mode) " ") 16)
                 (command-help command)))

(define (help-text)
  "The help screen's text, made from the command table"
  (let ([prompt-commands
         (filter (lambda (c) (and (not (command-in-mode? c MMAIN))
                                  (or (command-in-mode? c MPROMPT) (command-in-mode? c MYESNO))))
                 (command-table-commands editor-commands))])
    (string-join
     (append
      (list "gano help"
            ""
            "^ means Ctrl and A- means Alt.  A-x runs any command by name, and"
            "Tab completes the name.  Close this help with ^G, ^X or q."
            ""
            "Editing"
            "")
      (map (lambda (c) (help-entry c MMAIN)) (command-table-commands editor-commands MMAIN))
      (list "" "At a prompt" "")
      (map (lambda (c) (help-entry c (if (command-in-mode? c MPROMPT) MPROMPT MYESNO)))
           prompt-commands))
     "\n")))

(define (cmd-help state)
  "Show the help screen"
  (let* ([rows (text-area-height (editor-height state))]
         [cbuf (make-cbuf #:initial-text (help-text) #:form-size rows)])
    (set-editor-help! state (cons cbuf (make-frame (editor-width state) rows)))
    (set-editor-base-mode! state MHELP)))

(define (cmd-help-exit state)
  (set-editor-help! state #f)
  (set-editor-base-mode! state MMAIN))

;; --- Extended commands (A-x) ---

(define (main-command-names)
  (command-table-names editor-commands MMAIN))

(define (common-prefix strings)
  (fold (lambda (s prefix) (substring prefix 0 (string-prefix-length prefix s)))
        (car strings) (cdr strings)))

(define (cmd-complete state)
  "Complete the command name typed at the prompt as far as it is
   unambiguous; list the choices if there are several"
  (let* ([p (editor-prompt state)]
         [typed (prompt-input p)]
         [matches (filter (lambda (name) (string-prefix? typed name)) (main-command-names))])
    (cond
     [(null? matches)
      (message! state "No command starts with \"~a\"" typed)]
     [(null? (cdr matches))
      (set-prompt-input! p (car matches))]
     [else
      (set-prompt-input! p (common-prefix matches))
      (message! state "~a" (string-join matches " "))])))

(define (cmd-extended state)
  "Ask for a command name and run that command"
  (ask-text! state "Command: " ""
             (lambda (state name)
               (let* ([name (string-trim-both name)]
                      [command (command-table-ref editor-commands name)])
                 (cond
                  [(string-null? name) (message! state "Cancelled")]
                  [(and command (command-in-mode? command MMAIN))
                   (execute-command! state command)
                   (set-editor-last-command! state name)]
                  [else (message! state "No command called \"~a\"" name)])))
             #:mode MEXTCMD))

(define editor-commands
  (command-table-override
   standard-commands
   (list
    (editor-command "save"      "Save the file" cmd-save "^S")
    (editor-command "write-out" "Save the file under a name" cmd-write-out "^O")
    (editor-command "exit"      "Close the file, asking to save it" cmd-exit "^X")
    (editor-command "discard"   "Quit without saving" cmd-force-quit "^Q")
    (editor-command "location"  "Show the cursor position" cmd-show-position "^C")
    (editor-command "command"   "Run a command by name" cmd-extended "A-x")
    (editor-command "help"      "Show the list of commands and keys" cmd-help "^G" "F1")
    (prompt-command "help-exit" "Close the help screen" cmd-help-exit
                    (list MHELP) "^G" "^X" "q" "escape")
    ;; At prompts:
    (prompt-command "accept"    "Accept the answer" prompt-accept!
                    text-prompt-modes "enter")
    (prompt-command "cancel"    "Cancel" cancel-prompt!
                    (cons MYESNO text-prompt-modes) "^C" "escape")
    (prompt-command "input-bksp" "Delete the last character typed" prompt-backspace!
                    text-prompt-modes "backspace")
    (prompt-command "clear-input" "Clear the answer" prompt-clear!
                    text-prompt-modes "^U")
    (prompt-command "complete"  "Complete the command name" cmd-complete
                    (list MEXTCMD) "tab")
    (prompt-command "yes"       "Answer yes" (lambda (state) (finish-prompt! state #t))
                    (list MYESNO) "y" "Y")
    (prompt-command "no"        "Answer no" (lambda (state) (finish-prompt! state #f))
                    (list MYESNO) "n" "N")
    ;; In place of the standard commands of these names:
    (editor-command "search"    "Search forward for text, wrapping" cmd-search "^W" "F6")
    (editor-command "goto-line" "Go to a line and column" cmd-goto-line "^_" "A-g")
    (editor-command "cut-line"  "Cut the current line" cmd-cut-line "^K")
    (editor-command "paste"     "Paste the cut text" cmd-paste "^U")
    (editor-command "undo"      "Undo the last change" cmd-undo "A-u")
    (editor-command "redo"      "Redo the last undone change" cmd-redo "A-e"))))

(define (command-context state)
  "What commands act on: the help text while it is shown, else the buffer"
  (let ([view (or (editor-help state) (cons (editor-cbuf state) (editor-frame state)))])
    (make-command-context (car view) (cdr view) #:editor state)))

(define (error-text key args)
  "A short description of an error raised as (throw KEY . ARGS)"
  (match (cons key args)
    [((or 'misc-error 'wrong-type-arg 'out-of-range) _ (? string? msg) (? list? margs) . _)
     (apply format #f msg margs)]
    [_ (format #f "~a" key)]))

(define (run-in-editor! state command values)
  "Run COMMAND with the input VALUES, reporting an error in the status
   line rather than letting it end the editor"
  (catch #t
    (lambda ()
      (let ([message (command-result-message
                      command (apply run-command command (command-context state) values))])
        (when message (message! state "~a" message))))
    (lambda (key . args)
      (message! state "~a: ~a" (command-name command) (error-text key args)))))

(define (input-label input)
  (let ([prompt (command-input-prompt input)])
    (case (command-input-kind input)
      [(yes-no) (string-append prompt " (Y/N) ")]
      [(choice) (format #f "~a (~a): " prompt
                        (string-join (command-input-choices input) "/"))]
      [else (string-append prompt ": ")])))

(define (parse-input input answer)
  "Convert the prompt ANSWER for INPUT; returns (VALUE) or an error
   message string."
  (case (command-input-kind input)
    [(string) (list answer)]
    [(integer) (let ([n (string->number (string-trim-both answer))])
                 (if (exact-integer? n) (list n) (format #f "Not a whole number: ~a" answer)))]
    [(char) (if (= (string-length answer) 1)
                (list (string-ref answer 0))
                "Type one character")]
    [(choice) (if (member answer (command-input-choices input))
                  (list answer)
                  (format #f "Not one of the choices: ~a" answer))]
    [else (format #f "Cannot ask for ~a" (command-input-kind input))]))

(define (execute-command! state command)
  "Ask for COMMAND's inputs one by one, then run it.  An empty answer
   or ^C cancels it."
  (let ask ([inputs (command-inputs command)] [values '()])
    (if (null? inputs)
        (run-in-editor! state command (reverse values))
        (let ([input (car inputs)])
          (if (eq? (command-input-kind input) 'yes-no)
              (ask-yes-no! state (input-label input)
                           (lambda (state yes?) (ask (cdr inputs) (cons yes? values))))
              (ask-text! state (input-label input) ""
                         (lambda (state answer)
                           (if (string-null? answer)
                               (message! state "Cancelled")
                               (let ([parsed (parse-input input answer)])
                                 (if (string? parsed)
                                     (message! state "~a" parsed)
                                     (ask (cdr inputs) (cons (car parsed) values))))))
                         #:mode (command-input-mode input)))))))

(define (handle-prompt-key state key)
  "A key while a prompt is open: a command of the prompt's mode, or a
   character typed into a text prompt"
  (let ([command (command-table-key-ref editor-commands (editor-mode state) key)])
    (cond
     [(and command (command-needs-input? command))
      (message! state "~a cannot run at a prompt" (command-name command))]
     [command
      (run-in-editor! state command '())]
     [(and (eq? (prompt-kind (editor-prompt state)) 'text)
           (or (insertable-char? key) (key-is? key "tab")))
      (prompt-type! state (or (key-char key) #\tab))]
     [else #f])))                       ; ignore anything else

(define (handle-key state key)
  "Update STATE in response to KEY.  Returns STATE."
  (cond
   [(eq? (key-symbol key) 'eof)           ; input closed: nothing more to do
    (when (editor-prompt state) (cancel-prompt! state))
    (cmd-force-quit state)]
   [(editor-prompt state)
    (handle-prompt-key state key)]
   [(and (eq? (editor-mode state) MMAIN)
         (or (insertable-char? key) (key-is? key "tab")))
    (cmd-insert-char state (or (key-char key) #\tab))
    (set-editor-last-command! state 'insert)]
   [(command-table-key-ref editor-commands (editor-mode state) key)
    => (lambda (command)
         (set-editor-typing-run! state #f)
         (execute-command! state command)
         ;; Running a command by name counts as running that command
         (unless (equal? (command-name command) "command")
           (set-editor-last-command! state (command-name command))))]
   [else
    (set-editor-typing-run! state #f)
    (unknown-key state key)
    (set-editor-last-command! state #f)])
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
         [name (cond [(editor-help state) "Help"]
                     [(editor-filename state) (basename (editor-filename state))]
                     [else "New Buffer"])]
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

;; The commands shown in the help rows while editing; in other modes
;; every command with a shortcut there is shown.
(define main-help-commands
  '(("help" "save" "search" "cut-line" "paste" "undo")
    ("exit" "write-out" "goto-line" "command" "location" "redo")))

(define (help-label command mode)
  "\"KEY name\" for COMMAND's first shortcut in MODE"
  (string-append (car (command-shortcuts command mode)) " " (command-name command)))

(define (help-rows mode)
  "The two help rows for MODE, as lists of labels"
  (if (eq? mode MMAIN)
      (map (lambda (names)
             (filter-map (lambda (name)
                           (let ([c (command-table-ref editor-commands name)])
                             (and c (pair? (command-shortcuts c mode)) (help-label c mode))))
                         names))
           main-help-commands)
      (let* ([labels (filter-map (lambda (c) (and (pair? (command-shortcuts c mode))
                                                  (help-label c mode)))
                                 (command-table-commands editor-commands mode))]
             [half (quotient (+ (length labels) 1) 2)])
        (list (take labels half) (drop labels half)))))

(define (help-line entries width)
  (let ([cell (max 1 (quotient width (max 1 (length entries))))])
    (fit (string-concatenate (map (lambda (e) (fit e cell)) entries)) width)))

(define (render-screen state)
  "Return the ANSI output that redraws the whole screen for STATE.
   Also scrolls the frame so the cursor is visible."
  (let* ([help-view (editor-help state)]
         [cbuf (if help-view (car help-view) (editor-cbuf state))]
         [frame (if help-view (cdr help-view) (editor-frame state))]
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
          (let ([help (help-rows (editor-mode state))]
                [msg (editor-status-message state)])
            ;; Status line or prompt, in reverse video
            (terminal-cursor-position (- height 2) 1)
            (display (sgr->ansi-sequence reverse-video))
            (display (printable-string
                      (if prompt
                          (fit (string-append (prompt-label prompt) (prompt-input prompt)) width)
                          (status-line state))))
            (terminal-reset-attributes)
            ;; While a prompt is open, a message (such as the choices
            ;; for a completion) takes the first help line.
            (terminal-cursor-position (- height 1) 1)
            (display (if (and prompt (not (string-null? msg)))
                         (fit (printable-string msg) width)
                         (help-line (first help) width)))
            (terminal-cursor-position height 1)
            (display (help-line (second help) width))))
        ;; Cursor: in the prompt if one is open, else in the text
        (if (and prompt (> height reserved-rows))
            (begin
              (terminal-cursor-position (- height 2)
                                        (min width (+ 1 (string-length (prompt-label prompt))
                                                      (string-length (prompt-input prompt)))))
              (terminal-show-cursor))
            (let ([pos (and (not help-view) (frame-get-cursor-position cbuf frame))])
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
