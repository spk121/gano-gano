#!/usr/bin/env guile
!#

;;; example.scm --- Example usage of the terminfo library
;;;
;;; This file demonstrates how to use the GNU Guile terminfo library
;;; to work with terminal capabilities loaded from S-JSON files.

(use-modules (terminfo)
             (ice-9 format))

;;; Main demonstration function
(define (main)
  "Main function demonstrating terminfo library usage."
  
  ;; Load terminfo data from S-JSON file
  ;; (First generate this file using: python terminfo_to_json.py -f sjson xterm)
  (display "Loading terminfo data...\n")
  (load-terminfo-sjson "xterm_terminfo.sexpr")
  
  ;; Display basic terminal information
  (display "\n=== Terminal Information ===\n")
  (format #t "Terminal type: ~a\n" (get-string-capability "primary_name"))
  (format #t "Screen size: ~a columns x ~a lines\n" 
          (terminfo-get-columns) 
          (terminfo-get-lines))
  (format #t "Has color support: ~a\n" (terminfo-has-color))
  
  ;; Demonstrate cursor movement
  (display "\n=== Cursor Movement Demo ===\n")
  (display "Clearing screen...")
  (display (emit-clear-screen))
  
  (display "Moving to position (5, 10)...")
  (display (emit-cursor-address 5 10))
  (display "You should see this at row 5, column 10")
  
  (display (emit-cursor-address 7 5))
  (display "Moving cursor up 2 positions...")
  (display (emit-cursor-up 2))
  (display "Now at row 5")
  
  (display (emit-cursor-address 10 1))
  (display "Moving right 20 positions...")
  (display (emit-cursor-right 20))
  (display "Moved right!")
  
  ;; Demonstrate text attributes
  (display (emit-cursor-address 12 1))
  (display "\n=== Text Attributes Demo ===\n")
  
  (display "Normal text ")
  (display (emit-enter-bold-mode))
  (display "BOLD text ")
  (display (emit-exit-attribute-mode))
  (display "back to normal\n")
  
  (display (emit-enter-underline-mode))
  (display "Underlined text ")
  (display (emit-exit-underline-mode))
  (display "no underline\n")
  
  (display (emit-enter-reverse-mode))
  (display "Reverse video ")
  (display (emit-exit-attribute-mode))
  (display "normal again\n")
  
  ;; Demonstrate line/character manipulation
  (display "\n=== Line Manipulation Demo ===\n")
  (display "This line will be deleted...")
  (display (emit-delete-line))
  (display "Line deleted! Inserting new line...\n")
  (display (emit-insert-line))
  (display "New line inserted above!\n")
  
  ;; Demonstrate special functions
  (display "\n=== Special Functions Demo ===\n")
  (display "Press any key to ring the bell...")
  (read-char)
  (display (emit-bell))
  
  ;; Demonstrate key sequences
  (display "\n=== Key Sequences ===\n")
  (format #t "Up arrow key sequence: ~s\n" (emit-key-up))
  (format #t "Down arrow key sequence: ~s\n" (emit-key-down))
  (format #t "F1 key sequence: ~s\n" (emit-key-function 1))
  (format #t "F10 key sequence: ~s\n" (emit-key-function 10))
  (format #t "Home key sequence: ~s\n" (emit-key-home))
  (format #t "End key sequence: ~s\n" (emit-key-end))
  
  ;; Reset terminal
  (display "\n=== Cleanup ===\n")
  (display "Resetting all attributes...")
  (display (emit-exit-attribute-mode))
  (display (emit-cursor-home))
  (display "Demo complete!\n"))

;;; Interactive terminal manipulation functions
(define (clear-and-home)
  "Clear screen and move cursor to home position."
  (display (emit-clear-screen))
  (display (emit-cursor-home)))

(define (goto row col)
  "Move cursor to specific ROW and COL."
  (display (emit-cursor-address row col)))

(define (bold-text text)
  "Display TEXT in bold."
  (display (emit-enter-bold-mode))
  (display text)
  (display (emit-exit-attribute-mode)))

(define (underline-text text)
  "Display TEXT with underline."
  (display (emit-enter-underline-mode))
  (display text)
  (display (emit-exit-underline-mode)))

(define (reverse-text text)
  "Display TEXT in reverse video."
  (display (emit-enter-reverse-mode))
  (display text)
  (display (emit-exit-attribute-mode)))

(define (draw-box top-left-row top-left-col width height)
  "Draw a simple ASCII box at the specified position."
  (let ((bottom-row (+ top-left-row height -1))
        (right-col (+ top-left-col width -1)))
    
    ;; Draw top border
    (goto top-left-row top-left-col)
    (display "+")
    (display (make-string (- width 2) #\-))
    (display "+")
    
    ;; Draw sides
    (do ((row (+ top-left-row 1) (+ row 1)))
        ((>= row bottom-row))
      (goto row top-left-col)
      (display "|")
      (goto row right-col)
      (display "|"))
    
    ;; Draw bottom border
    (goto bottom-row top-left-col)
    (display "+")
    (display (make-string (- width 2) #\-))
    (display "+")))

(define (interactive-demo)
  "Interactive demonstration of terminal capabilities."
  (display "Starting interactive demo...\n")
  (display "Commands:\n")
  (display "  (clear-and-home)     - Clear screen\n")
  (display "  (goto row col)       - Move cursor\n")
  (display "  (bold-text \"text\")   - Display bold text\n")
  (display "  (draw-box r c w h)   - Draw ASCII box\n")
  (display "  (exit)               - Exit demo\n")
  (display "\nExample: (draw-box 5 10 20 5)\n")
  (display "guile> "))

;;; Terminal animation example
(define (animate-cursor)
  "Simple cursor animation demo."
  (clear-and-home)
  (display "Cursor Animation Demo - Press Ctrl+C to stop\n\n")
  
  (let loop ((x 1) (y 3) (dx 1) (dy 1))
    (goto y x)
    (display "*")
    (usleep 50000)  ; 50ms delay
    (goto y x)
    (display " ")   ; Erase
    
    (let ((new-x (+ x dx))
          (new-y (+ y dy))
          (new-dx dx)
          (new-dy dy))
      
      ;; Bounce off edges
      (when (or (>= new-x (terminfo-get-columns)) (<= new-x 1))
        (set! new-dx (- dx)))
      (when (or (>= new-y (terminfo-get-lines)) (<= new-y 3))
        (set! new-dy (- dy)))
      
      (loop (+ x new-dx) (+ y new-dy) new-dx new-dy))))

;;; Interactive input parsing demo
(define (input-parsing-demo)
  "Demonstrate the input parsing functionality."
  (display "=== Input Parsing Demo ===\n")
  (load-terminfo-sjson "xterm_terminfo.sexpr")
  (make-input-parser)
  
  (display "Testing various input sequences:\n\n")
  
  ;; Test regular characters
  (display "Regular character 'a': ")
  (let ((result (parse-input-byte (char->integer #\a))))
    (format #t "~a\n" result))
  
  ;; Test escape sequence for F1 key (should be \EOP for xterm)
  (display "F1 key sequence (\\EOP): ")
  (reset-input-parser)
  (let* ((esc-result (parse-input-byte 27))    ; ESC
         (o-result (parse-input-byte (char->integer #\O)))  ; O
         (p-result (parse-input-byte (char->integer #\P))))  ; P
    (format #t "ESC->~a, O->~a, P->~a\n" esc-result o-result p-result))
  
  ;; Test arrow keys
  (display "Up arrow key sequence (\\E[A): ")
  (reset-input-parser)
  (let* ((esc-result (parse-input-byte 27))    ; ESC
         (bracket-result (parse-input-byte (char->integer #\[)))  ; [
         (a-result (parse-input-byte (char->integer #\A))))  ; A
    (format #t "ESC->~a, [->~a, A->~a\n" esc-result bracket-result a-result))
  
  ;; Test incomplete sequence
  (display "Incomplete sequence (just ESC): ")
  (reset-input-parser)
  (let ((result (parse-input-byte 27)))
    (format #t "~a\n" result))
  
  ;; Test control characters
  (display "Tab character (byte 9): ")
  (reset-input-parser)
  (let ((result (parse-input-byte 9)))
    (format #t "~a\n" result))
  
  ;; Test backspace
  (display "Backspace (DEL byte 127): ")
  (reset-input-parser)
  (let ((result (parse-input-byte 127)))
    (format #t "~a\n" result))
  
  ;; Test string processing
  (display "\nProcessing string \"Hello\\EOP\" (Hello + F1): ")
  (let ((results (process-input-string "Hello\033OP")))
    (format #t "~a\n" results)))

;;; Real-time input handler example
(define (start-input-handler)
  "Start a real-time input handler (conceptual example)."
  (display "=== Real-time Input Handler ===\n")
  (display "This would read from stdin byte by byte in a real implementation.\n")
  (display "For demo purposes, we'll simulate some input:\n\n")
  
  (make-input-parser)
  
  ;; Simulate reading bytes one at a time
  (define (simulate-byte-input byte-list)
    (for-each
     (lambda (byte)
       (let ((result (parse-input-byte byte)))
         (format #t "Byte ~a (char '~a') -> ~a\n" 
                byte 
                (if (and (>= byte 32) (<= byte 126))
                    (integer->char byte)
                    "ctrl")
                result)))
     byte-list))
  
  ;; Simulate typing "Hi" followed by F5 key
  (display "Simulating input: 'Hi' + F5 key\n")
  (let ((f5-seq (get-string-capability "key_f5")))
    (if f5-seq
        (let ((f5-bytes (map char->integer (string->list (decode-escape-sequence f5-seq)))))
          (simulate-byte-input 
           (append (list (char->integer #\H) (char->integer #\i))
                   f5-bytes)))
        (display "F5 key not available in terminfo\n"))))

;;; Mouse input demo
(define (mouse-input-demo)
  "Demonstrate mouse input parsing."
  (display "\n=== Mouse Input Demo ===\n")
  (make-input-parser)
  
  ;; Simulate standard mouse click at position (10, 5)
  (display "Simulating mouse click at (10, 5):\n")
  (reset-input-parser)
  (let* ((esc-result (parse-mouse-input 27))           ; ESC
         (bracket-result (parse-mouse-input (char->integer #\[)))  ; [
         (m-result (parse-mouse-input (char->integer #\M)))        ; M
         (button-result (parse-mouse-input (+ 32 0)))              ; button (left click)
         (x-result (parse-mouse-input (+ 32 10)))                  ; x coordinate + 32
         (y-result (parse-mouse-input (+ 32 5))))                  ; y coordinate + 32
    (format #t "Results: ~a ~a ~a ~a ~a ~a\n" 
            esc-result bracket-result m-result button-result x-result y-result)))

;;; Key combination detector
(define (detect-key-combinations input-bytes)
  "Detect if input represents key combinations or sequences."
  (reset-input-parser)
  (let ((results '()))
    (for-each
     (lambda (byte)
       (let ((result (parse-input-byte byte)))
         (set! results (cons result results))))
     input-bytes)
    (reverse results)))

;;; Enhanced main function
(define (main)
  "Enhanced main function with input parsing demos."
  
  ;; Load terminfo data
  (display "Loading terminfo data...\n")
  (load-terminfo-sjson "xterm_terminfo.sexpr")
  
  ;; Run original demos
  (display "\n=== Terminal Information ===\n")
  (format #t "Terminal type: ~a\n" (get-string-capability "primary_name"))
  (format #t "Screen size: ~a columns x ~a lines\n" 
          (terminfo-get-columns) 
          (terminfo-get-lines))
  (format #t "Has color support: ~a\n" (terminfo-has-color))
  (format #t "Max colors: ~a\n" (terminfo-get-max-colors))
  (format #t "Can change colors: ~a\n" (terminfo-can-change-colors))
  
  ;; Run input parsing demos
  (input-parsing-demo)
  (start-input-handler)
  (mouse-input-demo)
  
  ;; Test CJK input
  (test-cjk-input)
  (test-mixed-input)
  (test-extended-cjk)
  (test-cjk-coverage)
  (show-cjk-statistics)
  
  ;; IME simulation examples
  (simulate-ime-input "konnichiwa" "こんにちは")
  (simulate-ime-input "nihon" "日本")
  
  ;; ACS demonstration
  (demo-acs-characters)
  
  ;; Control character demonstration
  (demo-control-characters)
  (test-control-input)
  
  ;; Alt/Meta key demonstration
  (demo-alt-keys)
  (test-alt-input)
  
  ;; Complex modifier key demonstration
  (demo-complex-modifiers)
  (test-complex-modifier-parsing)
  
  ;; Draw sample boxes
  (display "\n=== Box Drawing Demo ===\n")
  (display "Unicode box:\n")
  (draw-simple-box 2 0 10 5)  ; Note: relative positioning for demo
  (display "\n\nACS box:\n")
  (draw-box 2 0 10 5)
  
  ;; Show available keys
  (display "\n=== Available Function Keys ===\n")
  (let ((function-keys '(key_f1 key_f2 key_f3 key_f4 key_f5 
                        key_f6 key_f7 key_f8 key_f9 key_f10)))
    (for-each
     (lambda (key)
       (let ((seq (get-string-capability (symbol->string key))))
         (when seq
           (format #t "~a: ~s\n" key (decode-escape-sequence seq)))))
     function-keys))
  
  ;; Show arrow keys
  (display "\n=== Arrow Key Sequences ===\n")
  (let ((arrow-keys '(key_up key_down key_left key_right)))
    (for-each
     (lambda (key)
       (let ((seq (get-string-capability (symbol->string key))))
         (when seq
           (format #t "~a: ~s\n" key (decode-escape-sequence seq)))))
     arrow-keys)))

;;; Utility for interactive testing
(define (test-key-sequence key-name)
  "Test parsing of a specific key sequence."
  (let ((seq (get-string-capability key-name)))
    (if seq
        (let ((decoded (decode-escape-sequence seq)))
          (format #t "Testing ~a sequence: ~s\n" key-name decoded)
          (let ((results (process-input-string decoded)))
            (format #t "Parse results: ~a\n" results)
            results))
        (format #t "Key ~a not found in terminfo\n" key-name))))
