;;; Gano Terminal Module
;;; ANSI terminal control and input handling

;;;; ANSI Terminal Interface
;;;
;;; This module provides terminal control using ANSI escape sequences
;;; and integrates with the gano keys module for input handling.
;;; 
;;; Features:
;;; - Raw mode terminal setup/cleanup
;;; - ANSI escape sequence generation
;;; - Terminal input parsing to key objects
;;; - Screen management (cursor, clearing, colors)
;;; - Terminal size detection
;;;
;;; Design Philosophy:
;;; - Minimal but sufficient ANSI support
;;; - Integration with existing frame/buffer system
;;; - Clean separation between input parsing and terminal control

(define-module (gano terminal)
  #:use-module (gano char)
  #:use-module (gano keys)          ; Key representation
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-9)        ; Record types
  #:use-module (srfi srfi-11)       ; let-values
  #:use-module (ice-9 format)       ; Format function
  #:use-module (ice-9 rdelim)       ; Line reading
  #:use-module (ice-9 binary-ports) ; Binary I/O
  #:use-module (ice-9 regex)
  #:use-module (ice-9 popen)        ; stty
  #:export (
    ;; Terminal setup/cleanup
    terminal-raw-mode-enter
    terminal-raw-mode-exit
    terminal-save-state
    terminal-restore-state
    call-with-raw-terminal
    
    ;; Screen control
    terminal-clear-screen
    terminal-clear-to-eol
    terminal-clear-to-eos
    terminal-cursor-home
    terminal-cursor-position
    terminal-cursor-up
    terminal-cursor-down
    terminal-cursor-left
    terminal-cursor-right
    terminal-show-cursor
    terminal-hide-cursor
    
    ;; Alternate screen
    terminal-alternate-screen-enter
    terminal-alternate-screen-exit
    
    ;; Terminal info
    terminal-get-size
    terminal-get-cursor-position
    
    ;; Input handling
    terminal-read-key
    terminal-key-available?
    terminal-read-input-sequence
    
    ;; Colors and attributes
    terminal-set-foreground
    terminal-set-background
    terminal-reset-attributes
    terminal-bold
    terminal-dim
    terminal-italic
    terminal-underline
    
    ;; High-level interface
    terminal-init
    terminal-cleanup
    terminal-refresh))

;;; =================================================================
;;; TERMINAL STATE MANAGEMENT
;;; =================================================================

(define *terminal-saved-state* #f)
(define *terminal-raw-mode?* #f)

(define (stty-output . args)
  "Run stty with ARGS on the controlling terminal (our stdin) and return
   its first line of output, or #f if it failed."
  (catch #t
    (lambda ()
      ;; ARGS are fixed option strings from this module, never user input.
      (let* ([port (open-input-pipe
                    (string-append "stty " (string-join args " ") " 2>/dev/null"))]
             [line (read-line port)]
             [status (close-pipe port)])
        (and (zero? (status:exit-val status))
             (string? line)
             line)))
    (lambda _ #f)))

(define (terminal-save-state)
  "Save current terminal state (in memory, as printed by stty -g)"
  (set! *terminal-saved-state* (stty-output "-g")))

(define (terminal-restore-state)
  "Restore saved terminal state"
  (when *terminal-saved-state*
    (system* "stty" *terminal-saved-state*)
    (set! *terminal-saved-state* #f))
  (set! *terminal-raw-mode?* #f))

(define (terminal-raw-mode-enter)
  "Enter raw mode for character-by-character input"
  (unless *terminal-raw-mode?*
    (terminal-save-state)
    ;; Disable canonical mode, echo, signals and flow control (so that
    ;; ^C, ^Q, ^S, ^Z reach the editor as keys)
    (system* "stty" "raw" "-echo" "-isig" "-ixon")
    (set! *terminal-raw-mode?* #t)))

(define (terminal-raw-mode-exit)
  "Exit raw mode"
  (when *terminal-raw-mode?*
    (terminal-restore-state)))

(define (call-with-raw-terminal proc)
  "Execute proc with terminal in raw mode, ensuring cleanup"
  (dynamic-wind
    terminal-raw-mode-enter
    proc
    terminal-raw-mode-exit))

;;; =================================================================
;;; ANSI ESCAPE SEQUENCES
;;; =================================================================

(define (ansi-escape seq)
  "Generate ANSI escape sequence"
  (string-append "\x1b[" seq))

(define (ansi-csi . args)
  "Generate CSI (Control Sequence Introducer) sequence"
  (ansi-escape (apply format #f args)))

;;; Screen control
(define (terminal-clear-screen)
  "Clear entire screen"
  (display (ansi-escape "2J"))
  (terminal-cursor-home))

(define (terminal-clear-to-eol)
  "Clear from cursor to end of line"
  (display (ansi-escape "K")))

(define (terminal-clear-to-eos)
  "Clear from cursor to end of screen"
  (display (ansi-escape "J")))

(define (terminal-cursor-home)
  "Move cursor to home position (1,1)"
  (display (ansi-escape "H")))

(define (terminal-cursor-position row col)
  "Move cursor to specific position (1-based)"
  (display (ansi-csi "~d;~dH" row col)))

(define (terminal-cursor-up n)
  "Move cursor up N lines"
  (when (> n 0)
    (display (ansi-csi "~dA" n))))

(define (terminal-cursor-down n)
  "Move cursor down N lines" 
  (when (> n 0)
    (display (ansi-csi "~dB" n))))

(define (terminal-cursor-left n)
  "Move cursor left N columns"
  (when (> n 0)
    (display (ansi-csi "~dD" n))))

(define (terminal-cursor-right n)
  "Move cursor right N columns"
  (when (> n 0)
    (display (ansi-csi "~dC" n))))

(define (terminal-show-cursor)
  "Show cursor"
  (display (ansi-escape "?25h")))

(define (terminal-hide-cursor)
  "Hide cursor"
  (display (ansi-escape "?25l")))

;;; Alternate screen buffer
(define (terminal-alternate-screen-enter)
  "Enter alternate screen buffer"
  (display (ansi-escape "?1049h")))

(define (terminal-alternate-screen-exit)
  "Exit alternate screen buffer"
  (display (ansi-escape "?1049l")))

;;; =================================================================
;;; TERMINAL INFORMATION
;;; =================================================================

(define (terminal-get-size)
  "Get terminal size as (width . height).
   Asks stty first, then the COLUMNS/LINES environment variables, and
   falls back to 80x24."
  (define (env-number name)
    (let ([v (getenv name)])
      (and v (let ([n (string->number v)]) (and n (> n 0) n)))))
  (let* ([size (stty-output "size")]
         [fields (and size (map string->number (string-tokenize size)))])
    (if (and fields (= (length fields) 2) (every number? fields)
             (> (car fields) 0) (> (cadr fields) 0))
        (cons (cadr fields) (car fields))      ; stty prints "rows cols"
        (cons (or (env-number "COLUMNS") 80)
              (or (env-number "LINES") 24)))))
  ;; (let ([old-pos (terminal-get-cursor-position)])
  ;;   (display (ansi-csi "999;999H"))  ; Move to large position
  ;;   (let ([max-pos (terminal-get-cursor-position)])
  ;;     (terminal-cursor-position (car old-pos) (cdr old-pos))  ; Restore position
  ;;     max-pos)))

(define (terminal-get-cursor-position)
  "Get current cursor position as (row . col)"
  (display (ansi-escape "6n"))  ; Device Status Report
  (flush-all-ports)
  
  ;; Read response: ESC[{row};{col}R
  (let* ([response (terminal-read-input-sequence)]
         [match (string-match "\\[([0-9]+);([0-9]+)R" response)])
    (if match
        (cons (string->number (match:substring match 1))
              (string->number (match:substring match 2)))
        (cons 1 1))))  ; Default if parsing fails

;;; =================================================================
;;; COLOR AND ATTRIBUTES
;;; =================================================================

(define (terminal-set-foreground color)
  "Set foreground color (0-255 for 256-color mode)"
  (cond
   [(and (integer? color) (<= 0 color 7))
    ;; Standard colors
    (display (ansi-csi "~dm" (+ 30 color)))]
   [(and (integer? color) (<= 8 color 15))
    ;; Bright colors
    (display (ansi-csi "~dm" (+ 82 color)))]
   [(and (integer? color) (<= 0 color 255))
    ;; 256-color mode
    (display (ansi-csi "38;5;~dm" color))]
   [else
    (error "Invalid color" color)]))

(define (terminal-set-background color)
  "Set background color (0-255 for 256-color mode)"
  (cond
   [(and (integer? color) (<= 0 color 7))
    ;; Standard colors
    (display (ansi-csi "~dm" (+ 40 color)))]
   [(and (integer? color) (<= 8 color 15))
    ;; Bright colors
    (display (ansi-csi "~dm" (+ 92 color)))]
   [(and (integer? color) (<= 0 color 255))
    ;; 256-color mode
    (display (ansi-csi "48;5;~dm" color))]
   [else
    (error "Invalid color" color)]))

(define (terminal-reset-attributes)
  "Reset all attributes to default"
  (display (ansi-escape "0m")))

(define (terminal-bold)
  "Enable bold text"
  (display (ansi-escape "1m")))

(define (terminal-dim)
  "Enable dim text"
  (display (ansi-escape "2m")))

(define (terminal-italic)
  "Enable italic text"
  (display (ansi-escape "3m")))

(define (terminal-underline)
  "Enable underlined text"
  (display (ansi-escape "4m")))

;;; =================================================================
;;; INPUT HANDLING
;;; =================================================================

(define (terminal-key-available?)
  "Check if input is available without blocking"
  ;; Simple implementation - could be improved with select() or poll()
  (char-ready?))

(define (terminal-read-input-sequence)
  "Read a sequence of characters (for escape sequences)"
  (let loop ([chars '()]
             [timeout 10])  ; Simple timeout mechanism
    (cond
     [(= timeout 0) 
      (list->string (reverse chars))]
     [(char-ready?)
      (let ([ch (read-char)])
        (loop (cons ch chars) 10))]  ; Reset timeout on input
     [else
      (usleep 1000)  ; Sleep 1ms
      (loop chars (- timeout 1))])))

(define* (read-char-within ms)
  "Read a character if one arrives within MS milliseconds, else #f."
  (let loop ([ms ms])
    (cond
     [(char-ready?) (let ([ch (read-char)]) (if (eof-object? ch) #f ch))]
     [(<= ms 0) #f]
     [else (usleep 1000) (loop (- ms 1))])))

(define (terminal-read-key)
  "Read a single key and convert to key object.
   Returns a key with symbol 'eof if standard input is closed."
  (let ([ch (read-char)])
    (cond
     [(eof-object? ch)
      (make-key #:symbol 'eof)]

     ;; Escape sequence
     [(char=? ch #\escape)
      (if (char-ready?)
          (parse-escape-sequence)
          (make-key #:symbol 'escape))]
     
     ;; Control characters, including DEL (what most terminals send
     ;; for the Backspace key)
     [(or (< (char->integer ch) 32) (= (char->integer ch) 127))
      (parse-control-character ch)]
     
     ;; Printable characters
     [else
      (make-key #:char ch)])))

(define (parse-escape-sequence)
  "Parse escape sequence starting after ESC"
  (let ([next-char (read-char-within 50)])
    (cond
     [(not next-char)
      (make-key #:symbol 'escape)]

     ;; CSI sequence: ESC [
     [(char=? next-char #\[)
      (parse-csi-sequence)]
     
     ;; Function key / application cursor key sequence: ESC O
     ;; (checked before Alt+char, since O is graphic)
     [(char=? next-char #\O)
      (parse-function-sequence)]

     ;; Alt + character: ESC + char
     [(char-graphic? next-char)
      (make-key #:char next-char #:alt? #t)]
     
     ;; Unknown escape sequence
     [else
      (make-key #:symbol 'escape)])))

(define (parse-csi-sequence)
  "Parse CSI (Control Sequence Introducer) sequence.
   Reads parameter bytes up to and including the final byte (@ to ~),
   so keys typed right after the sequence are left unread."
  (let* ([sequence (let loop ([chars '()])
                     (let ([ch (read-char-within 50)])
                       (cond
                        [(not ch) (list->string (reverse chars))]
                        [(char<=? #\@ ch #\~) (list->string (reverse (cons ch chars)))]
                        [else (loop (cons ch chars))])))]
         [last-char (if (string-null? sequence)
                        #\nul
                        (string-ref sequence (- (string-length sequence) 1)))]
         ;; First numeric parameter, e.g. 3 in "3~" or "3;5~"
         [params (if (string-null? sequence)
                     ""
                     (substring sequence 0 (- (string-length sequence) 1)))]
         [first-param (let ([fields (string-split params #\;)])
                        (and (pair? fields) (string->number (car fields))))])
    
    (case last-char
      ;; Arrow keys
      [(#\A) (make-key #:symbol 'up)]
      [(#\B) (make-key #:symbol 'down)]
      [(#\C) (make-key #:symbol 'right)]
      [(#\D) (make-key #:symbol 'left)]
      
      ;; Other special keys
      [(#\H) (make-key #:symbol 'home)]
      [(#\F) (make-key #:symbol 'end)]
      
      ;; Function keys and other sequences
      [(#\~)
       (let ([code first-param])
         (case code
           [(1) (make-key #:symbol 'home)]
           [(2) (make-key #:symbol 'insert)]
           [(3) (make-key #:symbol 'delete)]
           [(4) (make-key #:symbol 'end)]
           [(5) (make-key #:symbol 'page-up)]
           [(6) (make-key #:symbol 'page-down)]
           [(15) (make-key #:symbol 'f5)]
           [(17) (make-key #:symbol 'f6)]
           [(18) (make-key #:symbol 'f7)]
           [(19) (make-key #:symbol 'f8)]
           [(20) (make-key #:symbol 'f9)]
           [(21) (make-key #:symbol 'f10)]
           [(23) (make-key #:symbol 'f11)]
           [(24) (make-key #:symbol 'f12)]
           [else (make-key #:symbol 'unknown)]))]
      
      ;; Unknown sequence
      [else (make-key #:symbol 'unknown)])))

(define (parse-function-sequence)
  "Parse function key sequence starting with ESC O"
  (let ([ch (read-char-within 50)])
    (case ch
      ;; Arrow/Home/End keys in application cursor mode
      [(#\A) (make-key #:symbol 'up)]
      [(#\B) (make-key #:symbol 'down)]
      [(#\C) (make-key #:symbol 'right)]
      [(#\D) (make-key #:symbol 'left)]
      [(#\H) (make-key #:symbol 'home)]
      [(#\F) (make-key #:symbol 'end)]
      [(#\P) (make-key #:symbol 'f1)]
      [(#\Q) (make-key #:symbol 'f2)]
      [(#\R) (make-key #:symbol 'f3)]
      [(#\S) (make-key #:symbol 'f4)]
      [else (make-key #:symbol 'unknown)])))

(define (parse-control-character ch)
  "Parse control character to key object"
  (let ([code (char->integer ch)])
    (cond
     ;; Common control characters
     [(= code 9) (make-key #:symbol 'tab)]
     [(= code 10) (make-key #:symbol 'enter)]
     [(= code 13) (make-key #:symbol 'enter)]  ; CR
     [(= code 127) (make-key #:symbol 'backspace)]  ; DEL
     [(= code 8) (make-key #:symbol 'backspace)]    ; BS
     
     ;; Control + letter combinations
     [(<= 1 code 26)
      (make-key #:char (integer->char (+ code 96)) #:ctrl? #t)]  ; ^A = 1, etc.

     ;; ^\ ^] ^^ ^_ (28-31)
     [(<= 28 code 31)
      (make-key #:char (integer->char (+ code 64)) #:ctrl? #t)]
     
     ;; Other control characters
     [else
      (make-key #:char ch)])))

;;; =================================================================
;;; HIGH-LEVEL INTERFACE
;;; =================================================================

(define (terminal-init)
  "Initialize terminal for editor use"
  (terminal-raw-mode-enter)
  (terminal-alternate-screen-enter)
  (terminal-hide-cursor)
  (terminal-clear-screen))

(define (terminal-cleanup)
  "Clean up terminal state"
  (terminal-show-cursor)
  (terminal-reset-attributes)
  (terminal-alternate-screen-exit)
  (terminal-raw-mode-exit))

(define (terminal-refresh)
  "Refresh terminal display"
  (flush-all-ports))

;;; =================================================================
;;; UTILITY FUNCTIONS
;;; =================================================================

(define (terminal-write-at row col text)
  "Write text at specific position"
  (terminal-cursor-position row col)
  (display text))

(define (terminal-fill-line row char)
  "Fill entire line with character"
  (let* ([size (terminal-get-size)]
         [width (car size)])
    (terminal-cursor-position row 1)
    (display (make-string width char))))

(define (terminal-center-text row text)
  "Center text on specified row"
  (let* ([size (terminal-get-size)]
         [width (car size)]
         [text-len (string-length text)]
         [start-col (max 1 (quotient (- width text-len) 2))])
    (terminal-write-at row start-col text)))

;;; =================================================================
;;; DEBUGGING AND TESTING
;;; =================================================================

(define (terminal-test-keys)
  "Test key input parsing"
  (format #t "Key input test - press keys (Ctrl+C to exit):~%")
  (call-with-raw-terminal
   (lambda ()
     (let loop ()
       (when (terminal-key-available?)
         (let ([key (terminal-read-key)])
           (format #t "Key: ~a (~a)~%" 
                  (key->string key) 
                  (describe-key key))
           (unless (and (key-ctrl? key) (char=? (key-char key) #\c))
             (loop))))))))

(define (terminal-test-display)
  "Test terminal display capabilities"
  (call-with-raw-terminal
   (lambda ()
     (terminal-clear-screen)
     
     ;; Test colors
     (terminal-cursor-position 1 1)
     (display "Color test: ")
     (let loop ([i 0])
       (when (< i 8)
         (terminal-set-background i)
         (display "  ")
         (terminal-reset-attributes)
         (loop (+ i 1))))
     
     ;; Test text attributes
     (terminal-cursor-position 3 1)
     (display "Normal text ")
     (terminal-bold)
     (display "Bold text ")
     (terminal-reset-attributes)
     (terminal-italic)
     (display "Italic text ")
     (terminal-reset-attributes)
     (terminal-underline)
     (display "Underlined text")
     (terminal-reset-attributes)
     
     ;; Test positioning
     (terminal-center-text 10 "Centered text")
     (terminal-cursor-position 20 1)
     (display "Press any key to exit...")
     (terminal-refresh)
     (terminal-read-key))))
     
