;;; Gano Commands Module
;;; A registry of editor commands.
;;;
;;; Every command has
;;;
;;;   - a short name, at most 11 characters, by which it can be run from
;;;     an extended command prompt (like Emacs's M-x);
;;;   - a one-line help string of at most 40 characters;
;;;   - the procedure that does the work;
;;;   - the editor modes it is available in (MMAIN, MSEARCH, ...), and
;;;     for each of those modes the keyboard shortcuts that run it.  A
;;;     command with no shortcuts in a mode can still be run there by
;;;     name;
;;;   - the inputs it must ask the user for before it can run (a yes/no
;;;     answer, a search string, a line number, ...).  A command with no
;;;     inputs needs nothing beyond the current editor state.
;;;
;;; A command procedure is called as (PROC CONTEXT INPUT ...), where
;;; CONTEXT is a <command-context> holding the buffer and frame the
;;; command acts on (and, for commands an editor adds, the editor), and the INPUTs are the user's answers, in the order
;;; the command's inputs are listed.  Whatever PROC returns is returned
;;; by run-command (search commands return whether they found a match,
;;; for instance).  A command may also have a report procedure that
;;; turns that result into a message for the user ("Not found"), or #f
;;; for no message.
;;;
;;; Shortcuts are written in (gano keys) notation ("^K", "A-u",
;;; "pagedown") and stored under key-binding-name, which makes an Alt
;;; letter case-insensitive: "A-u" also covers Alt+U, as in nano.
;;;
;;; The modes and the idea of keeping functions and their shortcuts in
;;; one table come from nano (see attic/module/gano/global.scm).
;;;
;;; standard-commands is a table holding a command for each buffer
;;; (cbuf) editing, motion and selection operation and each frame
;;; (view) operation.

(define-module (gano commands)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:use-module (ice-9 match)
  #:use-module (gano keys)
  #:use-module (gano buffer)
  #:use-module (gano frame)
  #:export (
    ;; Editor modes
    MMAIN MSEARCH MREPLACE MREPLACEWITH MGOTOLINE MWRITEFILE
    MINSERTFILE MEXTCMD MHELP MYESNO MPROMPT
    all-modes
    text-prompt-modes
    mode?

    ;; Limits
    command-name-max-length
    command-help-max-length

    ;; Inputs a command asks the user for
    make-command-input
    command-input?
    command-input-kind
    command-input-prompt
    command-input-choices
    command-input-mode
    input-kinds

    ;; Commands
    make-command
    command?
    command-name
    command-help
    command-procedure
    command-inputs
    command-needs-input?
    command-modes
    command-in-mode?
    command-shortcuts
    command-extended-only?
    command-report
    command-result-message

    ;; What a command acts on
    make-command-context
    command-context?
    command-context-cbuf
    command-context-frame
    command-context-editor

    ;; Running commands
    run-command

    ;; Tables of commands
    make-command-table
    command-table?
    command-table-add!
    command-table-ref
    command-table-key-ref
    command-table-commands
    command-table-names
    command-table-shortcuts
    command-table-count
    command-table-override

    ;; Shortcut keys
    key-binding-name

    ;; The standard table
    standard-commands))

;;; =================================================================
;;; MODES
;;; =================================================================

;; The mode the editor is in decides which commands its keys run.
(define MMAIN        'main)          ; editing the buffer
(define MSEARCH      'search)        ; typing a search string
(define MREPLACE     'replace)       ; typing the string to replace
(define MREPLACEWITH 'replace-with)  ; typing its replacement
(define MGOTOLINE    'goto-line)     ; typing a line number
(define MWRITEFILE   'write-file)    ; typing a file name to save to
(define MINSERTFILE  'insert-file)   ; typing a file name to read
(define MEXTCMD      'extended)      ; typing a command name (M-x)
(define MHELP        'help)          ; reading the help text
(define MYESNO       'yes-no)        ; answering a yes/no question
(define MPROMPT      'prompt)        ; typing any other answer

(define all-modes
  (list MMAIN MSEARCH MREPLACE MREPLACEWITH MGOTOLINE MWRITEFILE
        MINSERTFILE MEXTCMD MHELP MYESNO MPROMPT))

;; The modes of a prompt where a line of text is typed
(define text-prompt-modes
  (list MSEARCH MREPLACE MREPLACEWITH MGOTOLINE MWRITEFILE MINSERTFILE
        MEXTCMD MPROMPT))

(define (mode? x) (and (memq x all-modes) #t))

;;; =================================================================
;;; INPUTS
;;; =================================================================

(define command-name-max-length 11)
(define command-help-max-length 40)

;; What the user can be asked for:
;;   yes-no   a yes or no answer, passed as #t or #f
;;   string   a line of text
;;   integer  a whole number (the prompt says whether counting from 1)
;;   char     a single character
;;   choice   one of a fixed list of strings, passed as the string
;;
;; Each input also names the mode the editor is in while asking for it,
;; which decides what keys do at that prompt: MYESNO for a yes-no input,
;; one of text-prompt-modes for the others (MPROMPT unless given).
(define input-kinds '(yes-no string integer char choice))

(define-record-type <command-input>
  (%make-command-input kind prompt choices mode)
  command-input?
  (kind command-input-kind)
  (prompt command-input-prompt)
  (choices command-input-choices)
  (mode command-input-mode))

(define* (make-command-input kind prompt #:key (choices '()) (mode #f))
  "An input of KIND (one of input-kinds) asked for with PROMPT in MODE.
   A 'choice input lists its CHOICES (strings)."
  (unless (memq kind input-kinds)
    (error "make-command-input: unknown input kind" kind))
  (unless (and (string? prompt) (not (string-null? prompt)))
    (error "make-command-input: prompt must be a non-empty string" prompt))
  (if (eq? kind 'choice)
      (unless (and (pair? choices) (every string? choices))
        (error "make-command-input: a choice needs a list of strings" choices))
      (unless (null? choices)
        (error "make-command-input: only a choice has choices" kind)))
  (let ([mode (or mode (if (eq? kind 'yes-no) MYESNO MPROMPT))])
    (if (eq? kind 'yes-no)
        (unless (eq? mode MYESNO)
          (error "make-command-input: a yes-no input is asked in MYESNO" mode))
        (unless (memq mode text-prompt-modes)
          (error "make-command-input: not a text prompt mode" mode)))
    (%make-command-input kind prompt choices mode)))

(define (input-value-ok? input value)
  (case (command-input-kind input)
    [(yes-no) (boolean? value)]
    [(string) (string? value)]
    [(integer) (exact-integer? value)]
    [(char) (char? value)]
    [(choice) (and (member value (command-input-choices input)) #t)]
    [else #f]))

;;; =================================================================
;;; SHORTCUT KEYS
;;; =================================================================

(define (key-binding-name key)
  "The canonical name a shortcut KEY (a key or a key string) is stored
   under.  An Alt letter is case-insensitive, so Alt+U is stored as
   \"A-u\"."
  (let ([key (if (string? key) (string->key key) key)])
    (key->string
     (if (and (key-alt? key) (key-char key) (not (key-ctrl? key)))
         (make-key #:char (char-downcase (key-char key)) #:alt? #t
                   #:shift? (key-shift? key))
         key))))

;;; =================================================================
;;; COMMANDS
;;; =================================================================

(define-record-type <command>
  (%make-command name help procedure inputs modes report)
  command?
  (name command-name)
  (help command-help)
  (procedure command-procedure)
  (inputs command-inputs)
  ;; An alist of (MODE KEY-NAME ...) in the order given
  (modes command-mode-alist)
  ;; (lambda (result)) -> message string or #f; or #f for no reports
  (report command-report set-command-report!))

(define (check-name name)
  (unless (and (string? name)
               (<= 1 (string-length name) command-name-max-length))
    (error (format #f "command name must be 1 to ~a characters"
                   command-name-max-length)
           name))
  (when (string-any char-whitespace? name)
    (error "command name must not contain spaces" name)))

(define (check-help name help)
  (unless (and (string? help)
               (<= 1 (string-length help) command-help-max-length))
    (error (format #f "help for ~a must be 1 to ~a characters"
                   name command-help-max-length)
           help)))

(define (normalize-modes name modes)
  "Check MODES, a list of (MODE KEY ...) or bare MODE entries, and
   return it as an alist of (MODE KEY-NAME ...)."
  (when (null? modes)
    (error "command must be available in at least one mode" name))
  (let ([alist
         (map (lambda (entry)
                (let ([mode (if (pair? entry) (car entry) entry)]
                      [keys (if (pair? entry) (cdr entry) '())])
                  (unless (mode? mode)
                    (error "command has an unknown mode" name mode))
                  (let ([names (map (lambda (k)
                                      (unless (and (string? k) (valid-key-string? k))
                                        (error "command has an invalid shortcut" name k))
                                      (key-binding-name k))
                                    keys)])
                    (unless (= (length names) (length (delete-duplicates names)))
                      (error "command repeats a shortcut" name mode keys))
                    (cons mode names))))
              modes)])
    (unless (= (length alist) (length (delete-duplicates (map car alist))))
      (error "command lists a mode twice" name))
    alist))

(define* (make-command name help procedure #:key (modes (list MMAIN)) (inputs '())
                       (report #f))
  "A command called NAME (at most 11 characters) with HELP (at most 40)
   that runs PROCEDURE.  MODES lists the modes it is available in, each
   either MODE (runnable there only by name) or (MODE KEY ...) giving
   its shortcuts there.  INPUTS lists the command-inputs it asks for;
   PROCEDURE is called with the context and one value per input.
   REPORT, if given, maps PROCEDURE's result to a message or #f."
  (check-name name)
  (check-help name help)
  (unless (procedure? procedure)
    (error "command procedure must be a procedure" name procedure))
  (unless (and (list? inputs) (every command-input? inputs))
    (error "command inputs must be a list of command-inputs" name inputs))
  (unless (or (not report) (procedure? report))
    (error "command report must be a procedure or #f" name report))
  (%make-command name help procedure inputs (normalize-modes name modes) report))

(define (command-result-message command result)
  "The message to show after COMMAND returned RESULT, or #f"
  (let ([report (command-report command)])
    (and report
         (let ([message (report result)])
           (and (string? message) message)))))

(define (command-needs-input? command)
  "Must the user be asked for something before COMMAND runs?"
  (pair? (command-inputs command)))

(define (command-modes command)
  "The modes COMMAND is available in"
  (map car (command-mode-alist command)))

(define (command-in-mode? command mode)
  (and (assq mode (command-mode-alist command)) #t))

(define (command-shortcuts command mode)
  "The shortcut key names for COMMAND in MODE ('() if it has none or is
   not available there)"
  (let ([entry (assq mode (command-mode-alist command))])
    (if entry (cdr entry) '())))

(define (command-extended-only? command mode)
  "Is COMMAND available in MODE only by name (no shortcut)?"
  (let ([entry (assq mode (command-mode-alist command))])
    (and entry (null? (cdr entry)))))

;;; =================================================================
;;; CONTEXT AND RUNNING
;;; =================================================================

(define-record-type <command-context>
  (%make-command-context cbuf frame editor)
  command-context?
  (cbuf command-context-cbuf)
  (frame command-context-frame)
  (editor command-context-editor))

(define* (make-command-context cbuf #:optional (frame #f) #:key (editor #f))
  "What a command acts on: the buffer CBUF and the FRAME showing it (#f
   if there is none; frame commands then fail).  EDITOR is whatever an
   editor wants its own commands to see (its state, say); the standard
   commands ignore it."
  (%make-command-context cbuf frame editor))

(define (run-command command context . values)
  "Run COMMAND on CONTEXT with VALUES, one for each of its inputs.
   Returns what the command procedure returns."
  (let ([inputs (command-inputs command)])
    (unless (= (length values) (length inputs))
      (error (format #f "~a takes ~a input(s)" (command-name command) (length inputs))
             values))
    (for-each (lambda (input value)
                (unless (input-value-ok? input value)
                  (error (format #f "~a: bad ~a input" (command-name command)
                                 (command-input-kind input))
                         value)))
              inputs values)
    (apply (command-procedure command) context values)))

;;; =================================================================
;;; TABLES
;;; =================================================================

(define-record-type <command-table>
  (%make-command-table by-name by-key order)
  command-table?
  (by-name table-by-name)                 ; name -> command
  (by-key table-by-key)                   ; (mode . key-name) -> command
  (order table-order set-table-order!))   ; commands, newest first

(define (make-command-table)
  (%make-command-table (make-hash-table) (make-hash-table) '()))

(define (command-table-add! table command)
  "Add COMMAND to TABLE.  It is an error for its name, or one of its
   shortcuts in a mode, to be taken already."
  (let ([name (command-name command)])
    (when (hash-ref (table-by-name table) name)
      (error "command name already in use" name))
    (for-each
     (match-lambda
       [(mode . keys)
        (for-each (lambda (k)
                    (let ([other (hash-ref (table-by-key table) (cons mode k))])
                      (when other
                        (error (format #f "~a in ~a mode already runs ~a"
                                       k mode (command-name other))
                               name))))
                  keys)])
     (command-mode-alist command))
    (hash-set! (table-by-name table) name command)
    (for-each (match-lambda
                [(mode . keys)
                 (for-each (lambda (k) (hash-set! (table-by-key table) (cons mode k) command))
                           keys)])
              (command-mode-alist command))
    (set-table-order! table (cons command (table-order table)))
    command))

(define (command-table-ref table name)
  "The command called NAME, or #f"
  (hash-ref (table-by-name table) name #f))

(define (command-table-key-ref table mode key)
  "The command KEY (a key or key string) runs in MODE, or #f"
  (hash-ref (table-by-key table) (cons mode (key-binding-name key)) #f))

(define* (command-table-commands table #:optional mode)
  "TABLE's commands in the order added; only those available in MODE if
   it is given"
  (let ([all (reverse (table-order table))])
    (if mode
        (filter (lambda (c) (command-in-mode? c mode)) all)
        all)))

(define* (command-table-names table #:optional mode)
  "The sorted names of TABLE's commands (in MODE, if given), as offered
   at an extended command prompt"
  (sort (map command-name (command-table-commands table mode)) string<?))

(define (command-table-shortcuts table mode)
  "The shortcuts of MODE as (KEY-NAME . COMMAND) pairs, in command
   order"
  (append-map (lambda (c) (map (lambda (k) (cons k c)) (command-shortcuts c mode)))
              (command-table-commands table mode)))

(define (command-table-count table)
  (length (table-order table)))

(define (command-table-override base commands)
  "A new table holding COMMANDS and those of BASE's commands whose names
   none of COMMANDS has, in BASE's order with COMMANDS after them.  BASE
   is not changed.  A shortcut of COMMANDS that one of BASE's remaining
   commands also has is an error, as in command-table-add!."
  (let ([table (make-command-table)]
        [names (map command-name commands)])
    (for-each (lambda (c)
                (unless (member (command-name c) names)
                  (command-table-add! table c)))
              (command-table-commands base))
    (for-each (lambda (c) (command-table-add! table c)) commands)
    table))

;;; =================================================================
;;; THE STANDARD COMMANDS
;;; =================================================================

(define (ctx-frame ctx)
  (or (command-context-frame ctx)
      (error "this command needs a frame" ctx)))

(define (delete-selection! cbuf)
  "Delete the selected text without putting it in the cut buffer"
  (when (cbuf-mark-set? cbuf)
    (let* ([mark (cons (cbuf-mark-line cbuf) (cbuf-mark-x-data cbuf))]
           [point (cons (cbuf-line-cur cbuf) (cbuf-x-data cbuf))]
           [before? (lambda (a b) (or (< (car a) (car b))
                                      (and (= (car a) (car b)) (<= (cdr a) (cdr b)))))]
           [start (if (before? mark point) mark point)]
           [end (if (before? mark point) point mark)])
      (cbuf-delete-region! cbuf (car start) (cdr start) (car end) (cdr end))
      (cbuf-clear-mark! cbuf))))

(define (forward-wrapping! cbuf)
  "Go forward a character; from the end of a line, to the start of the
   next"
  (if (and (cbuf-end-of-line? cbuf)
           (< (cbuf-line-cur cbuf) (- (cbuf-line-count cbuf) 1)))
      (begin (cbuf-next-line! cbuf)
             (cbuf-beginning-of-line! cbuf))
      (cbuf-forward-char! cbuf)))

(define (back-wrapping! cbuf)
  "Go back a character; from the start of a line, to the end of the
   previous"
  (if (and (cbuf-beginning-of-line? cbuf) (> (cbuf-line-cur cbuf) 0))
      (begin (cbuf-previous-line! cbuf)
             (cbuf-end-of-line! cbuf))
      (cbuf-backward-char! cbuf)))

(define (backspace-joining! cbuf)
  "Delete the character before the cursor; at the start of a line, join
   it to the previous line"
  (cond
   [(not (cbuf-beginning-of-line? cbuf))
    (cbuf-backspace! cbuf)]
   [(> (cbuf-line-cur cbuf) 0)
    ;; record undo before moving, so undo puts the cursor back here
    (let ([line (cbuf-line-cur cbuf)])
      (cbuf-save-line-range-undo! cbuf (- line 1) line)
      (cbuf-previous-line! cbuf)
      (cbuf-end-of-line! cbuf)
      (cbuf-join-lines! cbuf #:undo? #f))]))

(define (delete-joining! cbuf)
  "Delete the character under the cursor; at the end of a line, join the
   next line to it"
  (if (cbuf-end-of-line? cbuf)
      (cbuf-join-lines! cbuf)              ; does nothing on the last line
      (cbuf-delete-char! cbuf)))

(define (replace-next! cbuf search replace)
  "Select the next match of SEARCH and replace it with REPLACE.  Returns
   whether there was a match."
  (and (cbuf-search-forward! cbuf search)
       (cbuf-search-replace! cbuf search replace)))

(define standard-commands (make-command-table))

;; (buffer-command NAME HELP PROC MODE-SPEC ...) adds a command whose
;; procedure takes just the buffer.
(define (buffer-command name help proc . modes)
  (command-table-add!
   standard-commands
   (make-command name help (lambda (ctx) (proc (command-context-cbuf ctx)))
                 #:modes (if (null? modes) (list MMAIN) modes))))

;; After the view moves, keep the cursor on screen (as nano does), so
;; that bringing the cursor into view does not move the view back.
(define (keep-cursor-in-view! cbuf frame)
  (let* ([top (frame-y-start frame)]
         [bottom (min (- (cbuf-line-count cbuf) 1)
                      (+ top (frame-height frame) -1))]
         [left (frame-x-start frame)]
         [right (+ left (frame-width frame) -1)])
    (cond
     [(< (cbuf-line-cur cbuf) top) (cbuf-set-y! cbuf (min top bottom))]
     [(> (cbuf-line-cur cbuf) bottom) (cbuf-set-y! cbuf (max 0 bottom))])
    (cond
     [(< (cbuf-x-cell cbuf) left) (cbuf-set-x! cbuf left 'cell)]
     [(> (cbuf-x-cell cbuf) right) (cbuf-set-x! cbuf right 'cell)])))

(define (view-procedure proc)
  "A command procedure running (PROC CBUF FRAME . VALUES), then keeping
   the cursor in view"
  (lambda (ctx . values)
    (let ([cbuf (command-context-cbuf ctx)]
          [frame (ctx-frame ctx)])
      (apply proc cbuf frame values)
      (keep-cursor-in-view! cbuf frame))))

;; (frame-command NAME HELP PROC MODE-SPEC ...) adds a command whose
;; procedure takes the buffer and the frame.  The cursor is kept in
;; view.
(define (frame-command name help proc . modes)
  (command-table-add!
   standard-commands
   (make-command name help (view-procedure proc)
                 #:modes (if (null? modes) (list MMAIN) modes))))

;; (asking-command NAME HELP INPUTS PROC MODE-SPEC ...) adds a command
;; that asks for INPUTS; PROC takes the buffer and the answers.
(define (asking-command name help inputs proc . modes)
  (command-table-add!
   standard-commands
   (make-command name help
                 (lambda (ctx . values) (apply proc (command-context-cbuf ctx) values))
                 #:inputs inputs
                 #:modes (if (null? modes) (list MMAIN) modes))))

(define* (ask kind prompt #:key (mode #f) (choices '()))
  (make-command-input kind prompt #:mode mode #:choices choices))


;;; ---- Moving by character, line and page -------------------------

(buffer-command "forward"     "Go forward one character" forward-wrapping!
                `(,MMAIN "right" "^F"))
(buffer-command "back"        "Go back one character" back-wrapping!
                `(,MMAIN "left" "^B"))
(buffer-command "next-line"   "Go to the next line" cbuf-next-line!
                `(,MMAIN "down" "^N"))
(buffer-command "prev-line"   "Go to the previous line" cbuf-previous-line!
                `(,MMAIN "up" "^P"))
(buffer-command "line-start"  "Go to the start of the line" cbuf-beginning-of-line!
                `(,MMAIN "^A"))
(buffer-command "line-end"    "Go to the end of the line" cbuf-end-of-line!
                `(,MMAIN "^E" "end"))
(buffer-command "home"        "Go to the line's home position" cbuf-goto-home!
                `(,MMAIN "home"))
(buffer-command "limit"       "Go to the line's limit position" cbuf-goto-limit!)
(buffer-command "first-line"  "Go to the first line of the file" cbuf-beginning-of-buffer!
                `(,MMAIN "A-\\" "C-home")
                `(,MSEARCH "^Y") `(,MREPLACE "^Y") `(,MREPLACEWITH "^Y") `(,MGOTOLINE "^Y"))
(buffer-command "last-line"   "Go to the last line of the file" cbuf-end-of-buffer!
                `(,MMAIN "A-/" "C-end")
                `(,MSEARCH "^V") `(,MREPLACE "^V") `(,MREPLACEWITH "^V") `(,MGOTOLINE "^V"))
(buffer-command "page-up"     "Go up one screenful" cbuf-page-up!
                `(,MMAIN "pageup" "^Y"))
(buffer-command "page-down"   "Go down one screenful" cbuf-page-down!
                `(,MMAIN "pagedown" "^V"))
(asking-command "goto-line"   "Go to a line number"
                (list (ask 'integer "Enter line number" #:mode MGOTOLINE))
                (lambda (cbuf line) (cbuf-goto-line! cbuf (- line 1)))
                `(,MMAIN "^_" "A-g"))
(asking-command "goto-col"    "Go to a column number"
                (list (ask 'integer "Enter column number" #:mode MGOTOLINE))
                (lambda (cbuf column) (cbuf-move-to-column! cbuf (- column 1))))
(asking-command "set-line"    "Go to a line, keeping the column"
                (list (ask 'integer "Enter line number" #:mode MGOTOLINE))
                (lambda (cbuf line) (cbuf-set-y! cbuf (- line 1))))
(asking-command "set-index"   "Go to a character index on the line"
                (list (ask 'integer "Enter character index (from 0)" #:mode MGOTOLINE))
                (lambda (cbuf index) (cbuf-set-x! cbuf index 'index)))

;;; ---- Moving by word, sentence and paragraph ---------------------

(buffer-command "next-word"   "Go to the start of the next word" cbuf-forward-word!
                `(,MMAIN "C-right" "A-f"))
(buffer-command "prev-word"   "Go to the start of the previous word" cbuf-backward-word!
                `(,MMAIN "C-left" "A-b"))
(buffer-command "word-start"  "Go to the start of this word" cbuf-beginning-of-word!)
(buffer-command "word-end"    "Go to the end of this word" cbuf-end-of-word!)
(buffer-command "next-sent"   "Go to the start of the next sentence" cbuf-forward-sentence!)
(buffer-command "prev-sent"   "Go to the start of this sentence" cbuf-backward-sentence!)
(buffer-command "next-para"   "Go to the end of the paragraph" cbuf-forward-paragraph!
                `(,MMAIN "C-down" "A-)"))
(buffer-command "prev-para"   "Go to the start of the paragraph" cbuf-backward-paragraph!
                `(,MMAIN "C-up" "A-("))

;;; ---- Scrolling the view (frame) ---------------------------------

(frame-command "scroll-up"   "Scroll the text up one line"
               (lambda (cbuf frame) (frame-scroll-up cbuf frame 1))
               `(,MMAIN "A-down") `(,MHELP "down"))
(frame-command "scroll-down" "Scroll the text down one line"
               (lambda (cbuf frame) (frame-scroll-down frame 1))
               `(,MMAIN "A-up") `(,MHELP "up"))
(frame-command "scroll-left" "Scroll the text left one column"
               (lambda (cbuf frame) (frame-scroll-left frame 1))
               `(,MMAIN "A-right"))
(frame-command "scroll-rt"   "Scroll the text right one column"
               (lambda (cbuf frame) (frame-scroll-right frame 1))
               `(,MMAIN "A-left"))
(frame-command "view-next"   "Show the next page"
               (lambda (cbuf frame) (frame-next-page cbuf frame 1))
               `(,MMAIN "A-pagedown") `(,MHELP "pagedown" "^V" "space"))
(frame-command "view-prev"   "Show the previous page"
               (lambda (cbuf frame) (frame-preceding-page cbuf frame 1))
               `(,MMAIN "A-pageup") `(,MHELP "pageup" "^Y" "A-space"))
(frame-command "view-cursor" "Scroll so the cursor can be seen" frame-update-frame
               `(,MMAIN "^L"))
(command-table-add!
 standard-commands
 (make-command "view-page" "Show a page by number"
               (view-procedure
                (lambda (cbuf frame page)
                  (frame-page-position-absolute cbuf frame (- page 1))))
               #:inputs (list (ask 'integer "Enter page number" #:mode MGOTOLINE))))
(command-table-add!
 standard-commands
 (make-command "view-fwd"    "Show a page N pages on"
               (view-procedure
                (lambda (cbuf frame n) (frame-page-position-forward cbuf frame n)))
               #:inputs (list (ask 'integer "Number of pages forward" #:mode MGOTOLINE))))
(command-table-add!
 standard-commands
 (make-command "view-back"   "Show a page N pages back"
               (view-procedure
                (lambda (cbuf frame n) (frame-page-position-backward cbuf frame n)))
               #:inputs (list (ask 'integer "Number of pages back" #:mode MGOTOLINE))))

;;; ---- Inserting and deleting -------------------------------------

(asking-command "insert-char" "Insert a character typed verbatim"
                (list (ask 'char "Verbatim input"))
                cbuf-insert-char!
                `(,MMAIN "A-v"))
(asking-command "insert-text" "Insert a line of text"
                (list (ask 'string "Text to insert"))
                cbuf-insert-string!)
(buffer-command "newline"     "Insert a line break" cbuf-insert-newline!
                `(,MMAIN "enter"))
(buffer-command "newl-indent" "Insert a line break and indent" cbuf-newline-and-indent!)
(buffer-command "tab"         "Insert spaces to the next tab stop" cbuf-handle-tab!
                `(,MMAIN "tab"))
(buffer-command "delete"      "Delete the character under the cursor" delete-joining!
                `(,MMAIN "delete" "^D"))
(buffer-command "backspace"   "Delete the character before the cursor" backspace-joining!
                `(,MMAIN "backspace"))
(buffer-command "del-line"    "Delete the current line" cbuf-delete-line!)
(buffer-command "join-lines"  "Join this line and the next" cbuf-join-lines!)
(buffer-command "del-word"    "Delete the word after the cursor" cbuf-delete-word-forward!
                `(,MMAIN "C-delete"))
(buffer-command "del-word-bk" "Delete the word before the cursor" cbuf-delete-word-backward!
                `(,MMAIN "A-backspace"))
(buffer-command "del-to-end"  "Delete to the end of the line" cbuf-delete-to-end-of-line!)
(buffer-command "del-to-bol"  "Delete to the start of the line"
                cbuf-delete-to-beginning-of-line!)
(buffer-command "del-region"  "Delete the selected text" delete-selection!)
(asking-command "clear"       "Delete all text in the buffer"
                (list (ask 'yes-no "Delete all text in the buffer?"))
                (lambda (cbuf yes?) (when yes? (cbuf-clear! cbuf)) yes?))
(asking-command "set-text"    "Replace all text with a line of text"
                (list (ask 'string "New buffer text"))
                cbuf-load-from-string!)

;;; ---- Mark and selection -----------------------------------------

(buffer-command "set-mark"    "Start selecting text at the cursor" cbuf-set-mark!
                `(,MMAIN "^^" "A-a"))
(buffer-command "clear-mark"  "Stop selecting text" cbuf-clear-mark!)
(buffer-command "swap-mark"   "Swap the cursor and the mark" cbuf-exchange-point-and-mark!)
(buffer-command "select-all"  "Select the whole buffer" cbuf-select-all!)
(buffer-command "select-line" "Select the current line" cbuf-select-line!)
(buffer-command "select-word" "Select the word at the cursor" cbuf-select-word!)
(buffer-command "select-sent" "Select the current sentence" cbuf-select-sentence!)
(buffer-command "select-para" "Select the current paragraph" cbuf-select-paragraph!)
(buffer-command "sel-fwd-wrd" "Extend the selection one word forward"
                cbuf-extend-selection-forward-word!
                `(,MMAIN "C-S-right"))
(buffer-command "sel-bk-word" "Extend the selection one word back"
                cbuf-extend-selection-backward-word!
                `(,MMAIN "C-S-left"))

;;; ---- Cut, copy and paste ----------------------------------------

(buffer-command "cut"         "Cut the selected text" cbuf-cut-region!)
(buffer-command "copy"        "Copy the selected text" cbuf-copy-region!
                `(,MMAIN "A-6"))
(buffer-command "paste"       "Paste the cut buffer" cbuf-paste!
                `(,MMAIN "^U"))
(buffer-command "paste-prev"  "Paste the previously cut text" cbuf-paste-previous!)
(buffer-command "cut-line"    "Cut the current line" cbuf-cut-line!
                `(,MMAIN "^K"))
(buffer-command "copy-line"   "Copy the current line" cbuf-copy-line!)
(buffer-command "cut-word"    "Cut the word at the cursor" cbuf-cut-word!)
(buffer-command "copy-word"   "Copy the word at the cursor" cbuf-copy-word!)

;;; ---- Undo -------------------------------------------------------

(buffer-command "undo"        "Undo the last change" cbuf-undo
                `(,MMAIN "A-u"))
(buffer-command "redo"        "Redo the last undone change" cbuf-redo!
                `(,MMAIN "A-e"))

;;; ---- Search and replace -----------------------------------------

(asking-command "search"      "Search forward for text"
                (list (ask 'string "Search" #:mode MSEARCH))
                cbuf-search-forward!
                `(,MMAIN "^W" "F6"))
(asking-command "search-back" "Search backward for text"
                (list (ask 'string "Search backward" #:mode MSEARCH))
                cbuf-search-backward!
                `(,MMAIN "A-q"))
(asking-command "search-ci"   "Search forward, ignoring case"
                (list (ask 'string "Search (ignoring case)" #:mode MSEARCH))
                (lambda (cbuf pattern)
                  (cbuf-search-forward! cbuf pattern #:case-insensitive? #t)))
(asking-command "search-word" "Search forward for a whole word"
                (list (ask 'string "Search (whole word)" #:mode MSEARCH))
                (lambda (cbuf pattern)
                  (cbuf-search-forward! cbuf pattern #:whole-word? #t)))
(asking-command "replace"     "Replace the next match of some text"
                (list (ask 'string "Search (to replace)" #:mode MREPLACE)
                      (ask 'string "Replace with" #:mode MREPLACEWITH))
                replace-next!
                `(,MMAIN "^\\" "A-R"))
(asking-command "replace-sel" "Replace the selection if it matches"
                (list (ask 'string "Replace the selection if it is" #:mode MREPLACE)
                      (ask 'string "Replace with" #:mode MREPLACEWITH))
                cbuf-search-replace!)
(asking-command "replace-all" "Replace every match of some text"
                (list (ask 'string "Search (to replace all)" #:mode MREPLACE)
                      (ask 'string "Replace with" #:mode MREPLACEWITH)
                      (ask 'yes-no "Replace every match?"))
                (lambda (cbuf search replace yes?)
                  (and yes? (cbuf-search-replace-all! cbuf search replace))))

;;; ---- Lines ------------------------------------------------------

(buffer-command "dup-line"    "Duplicate the current line" cbuf-duplicate-line!
                `(,MMAIN "A-d"))
(buffer-command "line-up"     "Move the current line up" cbuf-move-line-up!
                `(,MMAIN "A-S-up"))
(buffer-command "line-down"   "Move the current line down" cbuf-move-line-down!
                `(,MMAIN "A-S-down"))
(buffer-command "swap-prev"   "Swap this line with the one above"
                cbuf-swap-current-and-previous-line!)
(buffer-command "swap-next"   "Swap this line with the one below"
                cbuf-swap-current-and-following-line!)
(buffer-command "swap-char-b" "Swap this character with the one before"
                cbuf-swap-current-and-previous-grapheme!
                `(,MMAIN "^T"))
(buffer-command "swap-char-f" "Swap this character with the one after"
                cbuf-swap-current-and-following-grapheme!)
(buffer-command "center"      "Center the current line" cbuf-center-line!)
(buffer-command "sort-lines"  "Sort the lines of the region" cbuf-sort-lines-in-region!)

;;; ---- Indentation and comments -----------------------------------

(buffer-command "indent"      "Indent the current line" cbuf-indent-line!
                `(,MMAIN "A-}"))
(buffer-command "outdent"     "Unindent the current line" cbuf-outdent-line!
                `(,MMAIN "A-{"))
(buffer-command "indent-reg"  "Indent the lines of the region" cbuf-indent-region!)
(buffer-command "outdent-reg" "Unindent the lines of the region" cbuf-outdent-region!
                `(,MMAIN "S-tab"))
(buffer-command "align"       "Align the region's indentation"
                cbuf-align-indents-in-region!)
(buffer-command "comment"     "Comment out the current line" cbuf-comment-line!
                `(,MMAIN "A-3"))
(buffer-command "comment-reg" "Comment the lines of the region" cbuf-comment-region!)
(buffer-command "uncomment"   "Uncomment the lines of the region" cbuf-uncomment-region!)
(command-table-add!
 standard-commands
 (make-command "set-comment" "Set the line comment string"
               (lambda (ctx str) (cbuf-set-comment-string! str))
               #:inputs (list (ask 'string "Comment string"))))

;;; ---- Case -------------------------------------------------------

(buffer-command "upcase"      "Make the region upper case" cbuf-upcase-region!)
(buffer-command "downcase"    "Make the region lower case" cbuf-downcase-region!)
(buffer-command "capitalize"  "Capitalize the region" cbuf-capitalize-region!)
(buffer-command "titlecase"   "Make the region title case" cbuf-titlecase-region!)

;;; ---- Whitespace -------------------------------------------------

(buffer-command "tabify"      "Turn spaces into tabs in the buffer" cbuf-tabify-buffer!)
(buffer-command "untabify"    "Turn tabs into spaces in the buffer" cbuf-untabify-buffer!)
(buffer-command "tabify-reg"  "Turn spaces into tabs in the region"
                cbuf-tabify-lines-in-selected-region!)
(buffer-command "untabify-rg" "Turn tabs into spaces in the region"
                cbuf-untabify-lines-in-selected-region!)
(buffer-command "trim-trail"  "Delete trailing whitespace"
                cbuf-delete-trailing-whitespace!)
(buffer-command "trim-region" "Trim whitespace around the selection"
                cbuf-trim-whitespace!)

;;; ---- Final newline ----------------------------------------------

(asking-command "final-nl"    "Set the final newline policy"
                (list (ask 'choice "Final newline" #:choices '("always-add" "never-add" "preserve")))
                (lambda (cbuf policy)
                  (cbuf-set-final-newline-policy! cbuf (string->symbol policy))))
(buffer-command "apply-fnl"   "Apply the final newline policy"
                cbuf-normalize-final-newline!)

;;; ---- Messages for results ---------------------------------------

(define (report! name report)
  (set-command-report! (command-table-ref standard-commands name) report))

(define (not-found found?) (and (not found?) "Not found"))

(for-each (lambda (name) (report! name not-found))
          '("search" "search-back" "search-ci" "search-word" "replace"))
(report! "replace-sel" (lambda (replaced?) (and (not replaced?) "The selection does not match")))
(report! "replace-all" (lambda (n)
                         (cond [(not n) #f]          ; answered no
                               [(zero? n) "Not found"]
                               [else (format #f "Replaced ~a occurrence~a" n
                                             (if (= n 1) "" "s"))])))
