;;; Gano Status Bar Module
;;; Bottom menu, status line, and minibuffer formatting

;;;; Status Bar Layout (nano-style)
;;;
;;; The bottom of the screen consists of 3 areas:
;;; 
;;; Row -3: Status line (file info, position, modified flag)
;;; Row -2: Command menu (first row)  
;;; Row -1: Command menu (second row) / Minibuffer
;;;
;;; Command menu shows the most important commands with their keybindings,
;;; formatted as "^X Exit  ^O WriteOut  ^R Read File" etc.
;;; Each command entry is limited to 12 characters maximum.

(define-module (gano statusbar)
  #:use-module (gano keys)          ; Key representation
  #:use-module (gano terminal)      ; Terminal control
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-9)        ; Record types
  #:use-module (srfi srfi-13)       ; String utilities
  #:use-module (ice-9 format)       ; Format function
  #:export (
    ;; Status line formatting
    format-status-line
    format-file-info
    format-position-info
    format-buffer-state
    
    ;; Command menu
    format-command-menu
    format-menu-entry
    layout-menu-entries
    
    ;; Minibuffer
    format-minibuffer
    format-prompt
    
    ;; Menu entry record
    <menu-entry>
    make-menu-entry
    menu-entry?
    menu-entry-key
    menu-entry-command
    menu-entry-description
    
    ;; High-level interface
    draw-status-bar
    draw-command-menu
    draw-minibuffer
    
    ;; Default menu configurations
    get-default-menu-entries
    get-help-menu-entries
    get-search-menu-entries))

;;; =================================================================
;;; MENU ENTRY RECORD
;;; =================================================================

(define-record-type <menu-entry>
  (make-menu-entry key command description)
  menu-entry?
  (key menu-entry-key)              ; Key object or string
  (command menu-entry-command)      ; Symbol
  (description menu-entry-description)) ; String

;;; =================================================================
;;; STATUS LINE FORMATTING
;;; =================================================================

(define* (format-status-line editor-state #:key (width 80))
  "Format the main status line"
  (let* ([cbuf (editor-cbuf editor-state)]
         [filename (or (editor-filename editor-state) "New Buffer")]
         [modified? (editor-dirty? editor-state)]
         [line-num (+ (cbuf-line-cur cbuf) 1)]
         [col-num (+ (cbuf-x-data cbuf) 1)]
         [total-lines (cbuf-line-count cbuf)]
         
         ;; Format components
         [file-info (format-file-info filename modified?)]
         [pos-info (format-position-info line-num col-num total-lines)]
         [buffer-state (format-buffer-state cbuf)]
         
         ;; Calculate spacing
         [left-content (string-append file-info " " buffer-state)]
         [right-content pos-info]
         [content-len (+ (string-length left-content) (string-length right-content))]
         [padding (max 1 (- width content-len))])
    
    (string-append left-content 
                   (make-string padding #\space)
                   right-content)))

(define (format-file-info filename modified?)
  "Format filename with modification indicator"
  (let* ([basename (if (string-contains filename "/")
                      (last (string-split filename #\/))
                      filename)]
         [mod-indicator (if modified? "*" "")])
    (string-append basename mod-indicator)))

(define (format-position-info line-num col-num total-lines)
  "Format cursor position information"
  (format #f "Ln ~d, Col ~d (~d lines)" line-num col-num total-lines))

(define (format-buffer-state cbuf)
  "Format buffer state information"
  (let* ([encoding "UTF-8"]
         [line-ending (cbuf-line-ending cbuf)]
         [ending-name (cond
                       [(string=? line-ending "\n") "LF"]
                       [(string=? line-ending "\r\n") "CRLF"]
                       [(string=? line-ending "\r") "CR"]
                       [else "?"])])
    (format #f "[~a,~a]" encoding ending-name)))

;;; =================================================================
;;; COMMAND MENU FORMATTING
;;; =================================================================

(define* (format-command-menu menu-entries #:key (width 80) (rows 2))
  "Format command menu for bottom rows"
  (let* ([entries-per-row (quotient width 12)]  ; 12 chars per entry max
         [total-entries (* entries-per-row rows)]
         [displayed-entries (take menu-entries (min total-entries (length menu-entries)))]
         [rows-data (layout-menu-entries displayed-entries entries-per-row)])
    
    (map (lambda (row-entries)
           (format-menu-row row-entries width))
         rows-data)))

(define (layout-menu-entries entries entries-per-row)
  "Split menu entries into rows"
  (let loop ([remaining entries]
             [current-row '()]
             [rows '()]
             [count 0])
    (cond
     ;; No more entries
     [(null? remaining)
      (reverse (if (null? current-row) rows (cons (reverse current-row) rows)))]
     
     ;; Row is full
     [(>= count entries-per-row)
      (loop remaining '() (cons (reverse current-row) rows) 0)]
     
     ;; Add entry to current row
     [else
      (loop (cdr remaining) 
            (cons (car remaining) current-row)
            rows 
            (+ count 1))])))

(define (format-menu-row entries width)
  "Format a single row of menu entries"
  (let* ([entry-width (quotient width (length entries))]
         [formatted-entries (map (lambda (entry)
                                  (format-menu-entry entry entry-width))
                                entries)])
    (string-take (string-join formatted-entries "") width)))

(define (format-menu-entry entry max-width)
  "Format a single menu entry: ^X Exit"
  (let* ([key-str (cond
                   [(string? (menu-entry-key entry)) (menu-entry-key entry)]
                   [(key? (menu-entry-key entry)) (key->string (menu-entry-key entry))]
                   [else "?"])]
         [desc (menu-entry-description entry)]
         [combined (string-append key-str " " desc)]
         [truncated (if (> (string-length combined) (- max-width 1))
                       (string-append (substring combined 0 (- max-width 3)) "..")
                       combined)]
         [padded (string-pad-right truncated max-width)])
    padded))

;;; =================================================================
;;; MINIBUFFER FORMATTING
;;; =================================================================

(define* (format-minibuffer prompt input #:key (width 80))
  "Format minibuffer line"
  (let* ([prompt-len (string-length prompt)]
         [available-width (- width prompt-len)]
         [display-input (if (> (string-length input) available-width)
                           (string-append "..." 
                                         (substring input 
                                                   (- (string-length input) 
                                                      (- available-width 3))))
                           input)]
         [total-len (+ prompt-len (string-length display-input))]
         [padding (max 0 (- width total-len))])
    
    (string-append prompt display-input (make-string padding #\space))))

(define (format-prompt text)
  "Format prompt text with consistent styling"
  (string-append text " "))

;;; =================================================================
;;; DRAWING FUNCTIONS
;;; =================================================================

(define (draw-status-bar editor-state terminal-height terminal-width)
  "Draw the complete status bar area"
  (let* ([status-row (- terminal-height 2)]
         [menu-row1 (- terminal-height 1)]
         [menu-row2 terminal-height]
         [status-line (format-status-line editor-state #:width terminal-width)]
         [menu-entries (if (editor-minibuffer-active? editor-state)
                          (get-minibuffer-menu-entries)
                          (get-default-menu-entries))]
         [menu-lines (format-command-menu menu-entries #:width terminal-width)])
    
    ;; Draw status line
    (terminal-cursor-position status-row 1)
    (terminal-set-background 7)  ; Light gray background
    (terminal-set-foreground 0)  ; Black text
    (display status-line)
    (terminal-reset-attributes)
    
    ;; Draw menu lines
    (terminal-cursor-position menu-row1 1)
    (terminal-set-background 0)  ; Black background
    (terminal-set-foreground 7)  ; White text
    (display (first menu-lines))
    
    (when (> (length menu-lines) 1)
      (terminal-cursor-position menu-row2 1)
      (display (second menu-lines)))
    
    (terminal-reset-attributes)))

(define (draw-command-menu editor-state terminal-height terminal-width)
  "Draw just the command menu area"
  (let* ([menu-row1 (- terminal-height 1)]
         [menu-row2 terminal-height]
         [menu-entries (get-default-menu-entries)]
         [menu-lines (format-command-menu menu-entries #:width terminal-width)])
    
    (terminal-cursor-position menu-row1 1)
    (terminal-set-background 0)
    (terminal-set-foreground 7)
    (display (first menu-lines))
    
    (when (> (length menu-lines) 1)
      (terminal-cursor-position menu-row2 1)
      (display (second menu-lines)))
    
    (terminal-reset-attributes)))

(define (draw-minibuffer editor-state terminal-height terminal-width)
  "Draw minibuffer when active"
  (when (editor-minibuffer-active? editor-state)
    (let* ([minibuffer-row terminal-height]
           [prompt (editor-minibuffer-prompt editor-state)]
           [input (editor-minibuffer-input editor-state)]
           [formatted (format-minibuffer prompt input #:width terminal-width)])
      
      (terminal-cursor-position minibuffer-row 1)
      (terminal-set-background 0)
      (terminal-set-foreground 11)  ; Bright cyan
      (display formatted)
      (terminal-reset-attributes)
      
      ;; Position cursor at end of input
      (let ([cursor-col (+ (string-length prompt) (string-length input) 1)])
        (terminal-cursor-position minibuffer-row cursor-col)))))

;;; =================================================================
;;; DEFAULT MENU CONFIGURATIONS
;;; =================================================================

(define (get-default-menu-entries)
  "Get default command menu entries"
  (list
   (make-menu-entry "^G" 'goto-line "Go To Line")
   (make-menu-entry "^W" 'find-text "Where Is")
   (make-menu-entry "^K" 'cut-line "Cut Text")
   (make-menu-entry "^U" 'paste "Uncut Text")
   (make-menu-entry "^O" 'write-file "WriteOut")
   (make-menu-entry "^R" 'read-file "Read File")
   (make-menu-entry "^Y" 'prev-page "Prev Page")
   (make-menu-entry "^V" 'next-page "Next Page")
   (make-menu-entry "^C" 'show-position "Cur Pos")
   (make-menu-entry "^X" 'exit "Exit")
   (make-menu-entry "^J" 'justify "Justify")
   (make-menu-entry "^T" 'spell-check "To Spell")
   (make-menu-entry "M-U" 'undo "Undo")
   (make-menu-entry "M-A" 'select-all "Mark Text")
   (make-menu-entry "M-6" 'copy-text "Copy Text")
   (make-menu-entry "^H" 'help "Get Help")))

(define (get-help-menu-entries)
  "Get help screen menu entries"
  (list
   (make-menu-entry "^X" 'exit-help "Exit Help")
   (make-menu-entry "^Y" 'prev-page "Prev Page")
   (make-menu-entry "^V" 'next-page "Next Page")
   (make-menu-entry "^W" 'search-help "Where Is")
   (make-menu-entry "M-G" 'first-line "First Line")
   (make-menu-entry "M-C" 'last-line "Last Line")))

(define (get-search-menu-entries)
  "Get search context menu entries"
  (list
   (make-menu-entry "^C" 'cancel-search "Cancel")
   (make-menu-entry "^R" 'replace "Replace")
   (make-menu-entry "^T" 'goto-line "Go To Line")
   (make-menu-entry "^W" 'search-again "Search")
   (make-menu-entry "M-C" 'case-sensitive "Case Sens")
   (make-menu-entry "M-R" 'regexp "Regexp")
   (make-menu-entry "M-B" 'backwards "Backwards")
   (make-menu-entry "^P" 'prev-string "PrevHstory")
   (make-menu-entry "^N" 'next-string "NextHstory")))

(define (get-minibuffer-menu-entries)
  "Get menu entries when minibuffer is active"
  (list
   (make-menu-entry "Tab" 'complete "Complete")
   (make-menu-entry "^C" 'cancel "Cancel")
   (make-menu-entry "^P" 'prev-history "Prev")
   (make-menu-entry "^N" 'next-history "Next")
   (make-menu-entry "Enter" 'accept "Accept")))

;;; =================================================================
;;; UTILITY FUNCTIONS
;;; =================================================================

(define (truncate-string str max-len)
  "Truncate string to maximum length"
  (if (> (string-length str) max-len)
      (string-append (substring str 0 (- max-len 2)) "..")
      str))

(define (pad-string str width align)
  "Pad string to width with specified alignment (:left, :right, :center)"
  (let* ([len (string-length str)]
         [padding (max 0 (- width len))])
    (case align
      [(:left) (string-pad-right str width)]
      [(:right) (string-pad str width)]
      [(:center) 
       (let* ([left-pad (quotient padding 2)]
              [right-pad (- padding left-pad)])
         (string-append (make-string left-pad #\space)
                       str
                       (make-string right-pad #\space)))]
      [else str])))

(define (calculate-menu-layout width entry-count)
  "Calculate optimal layout for menu entries"
  (let* ([max-entry-width 12]
         [entries-per-row (quotient width max-entry-width)]
         [rows-needed (ceiling (/ entry-count entries-per-row))])
    (cons entries-per-row rows-needed)))

;;; =================================================================
;;; TESTING AND DEBUGGING
;;; =================================================================

(define (test-status-formatting)
  "Test status bar formatting functions"
  (let* ([test-entries (take (get-default-menu-entries) 10)]
         [status-line (format-status-line #f #:width 80)]
         [menu-lines (format-command-menu test-entries #:width 80)])
    
    (format #t "Status line test:~%~a~%~%" status-line)
    (format #t "Menu test:~%")
    (for-each (lambda (line)
               (format #t "~a~%" line))
             menu-lines)
    
    (format #t "~%Minibuffer test:~%")
    (let ([mb-line (format-minibuffer "Search for: " "example text" #:width 80)])
      (format #t "~a~%" mb-line))))
