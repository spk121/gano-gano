#!/usr/bin/env guile
!#

;;; Gano Text Editor - Minimum Viable Product
;;; A simple but functional text editor with nano-style interface

(add-to-load-path ".")

(use-modules (gano cbuf)
	     (gano char)
             (gano frame)
             (gano keys)
             (gano terminal)
             (gano statusbar)
             (srfi srfi-1)
             (srfi srfi-9)
             (ice-9 format)
             (ice-9 ftw)
             (ice-9 textual-ports))

;;; =================================================================
;;; EDITOR STATE
;;; =================================================================

(define-record-type <editor-state>
  (%make-editor-state cbuf frame filename terminal-width terminal-height 
                     dirty? quit? status-message minibuffer-active?
                     minibuffer-prompt minibuffer-input)
  editor-state?
  (cbuf editor-cbuf set-editor-cbuf!)
  (frame editor-frame set-editor-frame!)
  (filename editor-filename set-editor-filename!)
  (terminal-width editor-terminal-width set-editor-terminal-width!)
  (terminal-height editor-terminal-height set-editor-terminal-height!)
  (dirty? editor-dirty? set-editor-dirty?!)
  (quit? editor-quit? set-editor-quit?!)
  (status-message editor-status-message set-editor-status-message!)
  (minibuffer-active? editor-minibuffer-active? set-editor-minibuffer-active?!)
  (minibuffer-prompt editor-minibuffer-prompt set-editor-minibuffer-prompt!)
  (minibuffer-input editor-minibuffer-input set-editor-minibuffer-input!))

(define* (make-editor-state filename #:key (initial-text ""))
  "Create new editor state"
  (let* ([cbuf (if (string-null? initial-text)
                   (make-cbuf)
                   (text->cbuf initial-text))]
         [term-size (terminal-get-size)]
         [width (car term-size)]
         [height (cdr term-size)]
         [frame (make-frame width (- height 3))])  ; Reserve 3 rows for status
    
    (%make-editor-state cbuf frame filename width height #f #f "" #f "" "")))

;;; =================================================================
;;; FILE OPERATIONS
;;; =================================================================

(define (load-file filename)
  "Load file content, return text or empty string if file doesn't exist"
  (if (file-exists? filename)
      (call-with-input-file filename get-string-all)
      ""))

(define (save-file editor-state)
  "Save current buffer to file"
  (let ([filename (editor-filename editor-state)]
        [content (cbuf->text (editor-cbuf editor-state))])
    (call-with-output-file filename
      (lambda (port)
        (display content port)))
    (set-editor-dirty?! editor-state #f)
    (set-editor-status-message! editor-state 
                               (format #f "Wrote ~a lines to ~a" 
                                      (cbuf-line-count (editor-cbuf editor-state))
                                      filename))))

;;; =================================================================
;;; COMMAND IMPLEMENTATIONS
;;; =================================================================

(define (cmd-save editor-state)
  "Save file command"
  (if (editor-filename editor-state)
      (begin
        (save-file editor-state)
        editor-state)
      (begin
        (set-editor-status-message! editor-state "No filename specified")
        editor-state)))

(define (cmd-quit editor-state)
  "Quit editor command"
  (if (editor-dirty? editor-state)
      (begin
        (set-editor-status-message! editor-state 
                                   "Buffer modified. Save first or use Ctrl+Q to force quit")
        editor-state)
      (begin
        (set-editor-quit?! editor-state #t)
        editor-state)))

(define (cmd-force-quit editor-state)
  "Force quit without saving"
  (set-editor-quit?! editor-state #t)
  editor-state)

(define (cmd-cursor-up editor-state)
  "Move cursor up"
  (let ([cbuf (editor-cbuf editor-state)])
    (cbuf-cursor-up cbuf 1)
    (editor-ensure-cursor-visible editor-state)
    editor-state))

(define (cmd-cursor-down editor-state)
  "Move cursor down"
  (let ([cbuf (editor-cbuf editor-state)])
    (cbuf-cursor-down cbuf 1)
    (editor-ensure-cursor-visible editor-state)
    editor-state))

(define (cmd-cursor-left editor-state)
  "Move cursor left"
  (let ([cbuf (editor-cbuf editor-state)])
    (cbuf-cursor-backward cbuf 1)
    (editor-ensure-cursor-visible editor-state)
    editor-state))

(define (cmd-cursor-right editor-state)
  "Move cursor right"
  (let ([cbuf (editor-cbuf editor-state)])
    (cbuf-cursor-forward cbuf 1)
    (editor-ensure-cursor-visible editor-state)
    editor-state))

(define (cmd-backspace editor-state)
  "Delete character before cursor"
  (let* ([cbuf (editor-cbuf editor-state)]
         [x-data (cbuf-x-data cbuf)]
         [line (cbuf-line-cur cbuf)])
    (cond
     ;; At beginning of line - join with previous line
     [(and (= x-data 0) (> line 0))
      (cbuf-delete-newline cbuf)
      (set-editor-dirty?! editor-state #t)
      (editor-ensure-cursor-visible editor-state)]
     
     ;; Delete character before cursor
     [(> x-data 0)
      (cbuf-delete-preceding-character cbuf 1)
      (set-editor-dirty?! editor-state #t)
      (editor-ensure-cursor-visible editor-state)])
    
    editor-state))

(define (cmd-delete editor-state)
  "Delete character at cursor"
  (let* ([cbuf (editor-cbuf editor-state)]
         [x-data (cbuf-x-data cbuf)]
         [line-len (cbuf-text-cur-base-length cbuf)])
    (cond
     ;; At end of line - join with next line
     [(= x-data line-len)
      (cbuf-delete-newline cbuf)
      (set-editor-dirty?! editor-state #t)]
     
     ;; Delete character at cursor
     [else
      (cbuf-delete-character cbuf 1)
      (set-editor-dirty?! editor-state #t)])
    
    (editor-ensure-cursor-visible editor-state)
    editor-state))

(define (cmd-enter editor-state)
  "Insert newline"
  (let ([cbuf (editor-cbuf editor-state)])
    (cbuf-insert-newline cbuf)
    (set-editor-dirty?! editor-state #t)
    (editor-ensure-cursor-visible editor-state)
    editor-state))

(define (cmd-insert-char editor-state char)
  "Insert character at cursor"
  (let ([cbuf (editor-cbuf editor-state)])
    (cbuf-insert-codepoint cbuf char)
    (set-editor-dirty?! editor-state #t)
    (editor-ensure-cursor-visible editor-state)
    editor-state))

(define (cmd-show-position editor-state)
  "Show cursor position"
  (let* ([cbuf (editor-cbuf editor-state)]
         [line (+ (cbuf-line-cur cbuf) 1)]
         [col (+ (cbuf-x-data cbuf) 1)]
         [total-lines (cbuf-line-count cbuf)])
    (set-editor-status-message! editor-state
                               (format #f "Line ~d, Column ~d (~d total lines)"
                                      line col total-lines))
    editor-state))

;;; =================================================================
;;; INPUT HANDLING
;;; =================================================================

(define (handle-key editor-state key)
  "Handle a single key input"
  (cond
   ;; Minibuffer is active - different handling
   [(editor-minibuffer-active? editor-state)
    (handle-minibuffer-key editor-state key)]
   
   ;; Control keys
   [(and (key-ctrl? key) (key-char key))
    (case (key-char key)
      [(#\s) (cmd-save editor-state)]           ; Ctrl+S - Save
      [(#\x) (cmd-quit editor-state)]           ; Ctrl+X - Quit
      [(#\q) (cmd-force-quit editor-state)]     ; Ctrl+Q - Force quit
      [(#\c) (cmd-show-position editor-state)]  ; Ctrl+C - Show position
      [else 
       (set-editor-status-message! editor-state 
                                  (format #f "Unknown command: ~a" (key->string key)))
       editor-state])]
   
   ;; Special keys
   [(key-symbol key)
    (case (key-symbol key)
      [(up) (cmd-cursor-up editor-state)]
      [(down) (cmd-cursor-down editor-state)]
      [(left) (cmd-cursor-left editor-state)]
      [(right) (cmd-cursor-right editor-state)]
      [(backspace) (cmd-backspace editor-state)]
      [(delete) (cmd-delete editor-state)]
      [(enter) (cmd-enter editor-state)]
      [else 
       (set-editor-status-message! editor-state 
                                  (format #f "Unknown key: ~a" (key->string key)))
       editor-state])]
   
   ;; Regular printable characters
   [(and (key-char key)
	 (or (char-blank? (key-char key))
	     (char-graphic? (key-char key)))
	 (not (key-modifier? key)))
    (cmd-insert-char editor-state (key-char key))
    ]
   
   ;; Unknown key
   [else
    (set-editor-status-message! editor-state 
                               (format #f "Unknown key: ~a" (key->string key)))
    editor-state]))

(define (handle-minibuffer-key editor-state key)
  "Handle key input when minibuffer is active"
  ;; For MVP, we don't have minibuffer functionality yet
  ;; Just cancel on escape
  (cond
   [(and (key-symbol key) (eq? (key-symbol key) 'escape))
    (set-editor-minibuffer-active?! editor-state #f)
    (set-editor-status-message! editor-state "Cancelled")
    editor-state]
   [else editor-state]))

;;; =================================================================
;;; DISPLAY MANAGEMENT
;;; =================================================================

(define (editor-ensure-cursor-visible editor-state)
  "Ensure cursor is visible in frame"
  (let ([cbuf (editor-cbuf editor-state)]
        [frame (editor-frame editor-state)])
    (frame-update-frame cbuf frame)))

(define (update-terminal-size editor-state)
  "Update terminal size and adjust frame"
  (let* ([size (terminal-get-size)]
         [width (car size)]
         [height (cdr size)]
         [text-height (- height 3)])  ; Reserve 3 rows for status
    
    (set-editor-terminal-width! editor-state width)
    (set-editor-terminal-height! editor-state height)
    (set-frame-width! (editor-frame editor-state) width)
    (set-frame-height! (editor-frame editor-state) text-height)))

(define (draw-editor editor-state)
  "Redraw entire editor screen"
  (terminal-clear-screen)
  
  ;; Draw text area
  (draw-text-area editor-state)
  
  ;; Draw status bar
  (draw-status-area editor-state)
  
  ;; Position cursor
  (position-cursor editor-state)
  
  (terminal-refresh))

(define (draw-text-area editor-state)
  "Draw the main text editing area"
  (let* ([cbuf (editor-cbuf editor-state)]
         [frame (editor-frame editor-state)]
         [lines (frame-render-frame cbuf frame)])
    
    (let loop ([lines lines] [row 1])
      (unless (null? lines)
        (terminal-cursor-position row 1)
        (display (car lines))
        (loop (cdr lines) (+ row 1))))))

(define (draw-status-area editor-state)
  "Draw status line and command menu"
  (let* ([width (editor-terminal-width editor-state)]
         [height (editor-terminal-height editor-state)]
         [status-row (- height 2)]
         [menu-row1 (- height 1)]
         [menu-row2 height])
    
    ;; Status line
    (terminal-cursor-position status-row 1)
    (terminal-set-background 7)  ; Light gray
    (terminal-set-foreground 0)  ; Black
    (let ([status-text (format-status-line-simple editor-state width)])
      (display status-text))
    (terminal-reset-attributes)
    
    ;; Menu lines
    (terminal-cursor-position menu-row1 1)
    (terminal-set-background 0)  ; Black
    (terminal-set-foreground 7)  ; White
    (display (format-menu-line-1 width))
    
    (terminal-cursor-position menu-row2 1)
    (display (format-menu-line-2 width))
    (terminal-reset-attributes)))

(define (format-status-line-simple editor-state width)
  "Format a simple status line for MVP"
  (let* ([cbuf (editor-cbuf editor-state)]
         [filename (or (editor-filename editor-state) "New Buffer")]
         [modified? (editor-dirty? editor-state)]
         [line-num (+ (cbuf-line-cur cbuf) 1)]
         [col-num (+ (cbuf-x-data cbuf) 1)]
         [total-lines (cbuf-line-count cbuf)]
         [status-msg (editor-status-message editor-state)]
         
         [left-part (format #f "~a~a" 
                           (if (string-contains filename "/")
                               (last (string-split filename #\/))
                               filename)
                           (if modified? "*" ""))]
         [right-part (format #f "Ln ~d, Col ~d" line-num col-num)]
         [middle-part (if (string-null? status-msg) "" (string-append " " status-msg " "))]
         
         [left-len (string-length left-part)]
         [right-len (string-length right-part)]
         [middle-len (string-length middle-part)]
         [padding (max 1 (- width left-len right-len middle-len))])
    
    (string-append left-part middle-part 
                   (make-string padding #\space) 
                   right-part)))

(define (format-menu-line-1 width)
  "Format first menu line"
  (let* ([entries '("^S Save" "^X Exit" "^C Cur Pos")]
         [entry-width (quotient width (length entries))]
	 [menu-line (apply string-append 
			   (map (lambda (entry) 
				  (string-pad-right entry entry-width))
				entries))]
	 [menu-line-width (string-length menu-line)])
    (string-take menu-line (min width menu-line-width))))

(define (format-menu-line-2 width)
  "Format second menu line"
  (let* ([entries '("Arrow Keys: Move Cursor" "Backspace: Delete" "Enter: New Line")]
         [entry-width (quotient width (length entries))]
	 [menu-line (apply string-append
			   (map (lambda (entry)
				  (string-pad-right entry entry-width))
				entries))]
	 [menu-line-width (string-length menu-line)])
    (string-take menu-line (min width menu-line-width))))

(define (position-cursor editor-state)
  "Position terminal cursor at editor cursor location"
  (let* ([cbuf (editor-cbuf editor-state)]
         [frame (editor-frame editor-state)])
    (if (frame-cursor-visible? cbuf frame)
        (let* ([pos (frame-get-cursor-position cbuf frame)]
               [screen-row (+ (cdr pos) 1)]    ; Convert to 1-based
               [screen-col (+ (car pos) 1)])   ; Convert to 1-based
          (terminal-cursor-position screen-row screen-col))
        ;; Cursor not visible, hide it
        (terminal-hide-cursor))))

;;; =================================================================
;;; MAIN EVENT LOOP
;;; =================================================================

(define (main-loop editor-state)
  "Main editor event loop"
  (draw-editor editor-state)
  (terminal-show-cursor)
  
  (let loop ([state editor-state])
    (unless (editor-quit? state)
      ;; Clear status message after displaying
      (when (not (string-null? (editor-status-message state)))
        (set-editor-status-message! state ""))
      
      ;; Read and handle input
      (let* ([key (terminal-read-key)]
             [new-state (handle-key state key)])
        
        ;; Redraw and continue
        (draw-editor new-state)
        (loop new-state)))))

;;; =================================================================
;;; MAIN PROGRAM
;;; =================================================================

(define (main args)
  "Main program entry point"
  (let ([filename (if (> (length args) 1) (cadr args) #f)])
    
    (unless filename
      (format #t "Usage: ~a <filename>~%" (car args))
      (exit 1))
    
    ;; Load file content
    (let* ([content (load-file filename)]
           [editor-state (make-editor-state filename #:initial-text content)])
      
      ;; Initialize terminal
      (call-with-raw-terminal
       (lambda ()
         (terminal-alternate-screen-enter)
         (terminal-hide-cursor)
         
         ;; Update terminal size
         (update-terminal-size editor-state)
         
         ;; Show welcome message
         (set-editor-status-message! editor-state
                                    (if (string-null? content)
                                        (format #f "New file: ~a" filename)
                                        (format #f "Loaded ~a (~d lines)" 
                                               filename 
                                               (cbuf-line-count (editor-cbuf editor-state)))))
         
         ;; Run main loop
         (main-loop editor-state)
         
         ;; Cleanup
         (terminal-show-cursor)
         (terminal-alternate-screen-exit))))))

;;; Run the program
(when (defined? 'command-line)
  (main (command-line)))
