;;; Strict tests for (gano terminal): ANSI output and xterm key decoding.

(define-module (test terminal)
  #:use-module (srfi srfi-64)
  #:use-module (gano terminal)
  #:use-module (gano keys))

(define (out thunk) (with-output-to-string thunk))
(define (esc . parts) (apply string-append "\x1b" parts))

(define (keys-from input)
  "Decode INPUT completely; return the keys as key->string strings."
  (with-input-from-string input
    (lambda ()
      (let loop ([acc '()])
        (let ([key (terminal-read-key)])
          (if (eq? (key-symbol key) 'eof)
              (reverse acc)
              (loop (cons (key->string key) acc))))))))

(define (key-from input)
  (let ([keys (keys-from input)])
    (if (= (length keys) 1) (car keys) keys)))

(test-begin "terminal")

;;; ---------------------------------------------------------------
(test-group "screen output"
  (test-equal "clear screen (and home)" (esc "[2J" (esc "[H")) (out terminal-clear-screen))
  (test-equal "clear to end of line" (esc "[K") (out terminal-clear-to-eol))
  (test-equal "clear to end of screen" (esc "[J") (out terminal-clear-to-eos))
  (test-equal "home" (esc "[H") (out terminal-cursor-home))
  (test-equal "position" (esc "[3;17H") (out (lambda () (terminal-cursor-position 3 17))))
  (test-error "position row 0" #t (terminal-cursor-position 0 1))
  (test-error "position column 0" #t (terminal-cursor-position 1 0))
  (test-error "position not an integer" #t (terminal-cursor-position 1.5 1))
  (test-equal "up" (esc "[2A") (out (lambda () (terminal-cursor-up 2))))
  (test-equal "down" (esc "[3B") (out (lambda () (terminal-cursor-down 3))))
  (test-equal "right" (esc "[4C") (out (lambda () (terminal-cursor-right 4))))
  (test-equal "left" (esc "[5D") (out (lambda () (terminal-cursor-left 5))))
  (test-equal "moving 0 sends nothing" "" (out (lambda () (terminal-cursor-up 0))))
  (test-equal "show cursor" (esc "[?25h") (out terminal-show-cursor))
  (test-equal "hide cursor" (esc "[?25l") (out terminal-hide-cursor))
  (test-equal "alternate screen on" (esc "[?1049h") (out terminal-alternate-screen-enter))
  (test-equal "alternate screen off" (esc "[?1049l") (out terminal-alternate-screen-exit)))

(test-group "compact screen controls"
  (define (control op)
    (call-with-output-string (lambda (port) (terminal-write-screen-control op port))))
  (test-equal "control characters" "\r\n\b"
              (string-append (control '(cr)) (control '(lf)) (control '(bs))))
  (test-equal "default and explicit counts" (esc "[C") (control '(cuf 1)))
  (test-equal "multi-digit count" (esc "[12@") (control '(ich 12)))
  (test-equal "home" (esc "[H") (control '(cup 1 1)))
  (test-equal "row only" (esc "[4H") (control '(cup 4 1)))
  (test-equal "column only" (esc "[1;7H") (control '(cup 1 7)))
  (test-equal "scroll region" (esc "[2;9r") (control '(stbm 2 9)))
  (test-equal "reset scroll region" (esc "[r") (control '(stbm)))
  (test-error "unknown operation" #t (control '(unknown))))

(test-group "attributes"
  (test-equal "reset" (esc "[0m") (out terminal-reset-attributes))
  (test-equal "bold" (esc "[1m") (out terminal-bold))
  (test-equal "dim" (esc "[2m") (out terminal-dim))
  (test-equal "italic" (esc "[3m") (out terminal-italic))
  (test-equal "underline" (esc "[4m") (out terminal-underline))
  (test-equal "foreground 0-7" (esc "[31m") (out (lambda () (terminal-set-foreground 1))))
  (test-equal "foreground bright 8-15" (esc "[97m") (out (lambda () (terminal-set-foreground 15))))
  (test-equal "foreground 256-colour" (esc "[38;5;200m") (out (lambda () (terminal-set-foreground 200))))
  (test-equal "background 0-7" (esc "[44m") (out (lambda () (terminal-set-background 4))))
  (test-equal "background bright 8-15" (esc "[100m") (out (lambda () (terminal-set-background 8))))
  (test-equal "background 256-colour" (esc "[48;5;16m") (out (lambda () (terminal-set-background 16))))
  (test-error "colour 256" #t (terminal-set-foreground 256))
  (test-error "negative colour" #t (terminal-set-background -1)))

;;; ---------------------------------------------------------------
(test-group "plain and control keys"
  (test-equal "letters and UTF-8" '("a" "Z" "é" "日") (keys-from "aZé日"))
  (test-equal "space" "space" (key-from " "))
  (test-equal "^A" "^A" (key-from "\x01"))
  (test-equal "^Z" "^Z" (key-from "\x1a"))
  (test-equal "Ctrl+Space is ^@" "^@" (key-from "\x00"))
  (test-equal "^\\ ^] ^^ ^_" '("^\\" "^]" "^^" "^_") (keys-from "\x1c\x1d\x1e\x1f"))
  (test-equal "Tab" "tab" (key-from "\t"))
  (test-equal "Enter (CR)" "enter" (key-from "\r"))
  (test-equal "Enter (LF)" "enter" (key-from "\n"))
  (test-equal "Backspace (DEL)" "backspace" (key-from "\x7f"))
  (test-equal "Backspace (^H)" "backspace" (key-from "\x08"))
  (test-equal "control keys are ctrl + lower case" #\c
              (with-input-from-string "\x03" (lambda () (key-char (terminal-read-key))))))

(test-group "escape and Alt"
  (test-equal "lone Escape" "escape" (key-from (esc)))
  (test-equal "Alt+x" "A-x" (key-from (esc "x")))
  (test-equal "Alt+X" "A-X" (key-from (esc "X")))
  (test-equal "Alt+UTF-8" "A-é" (key-from (esc "é")))
  (test-equal "Alt+Ctrl+a" "C-A-a" (key-from (esc "\x01")))
  (test-equal "Alt+Backspace" "A-backspace" (key-from (esc "\x7f")))
  (test-equal "Alt+Escape" "A-escape" (key-from (esc (esc))))
  (test-equal "Alt+[ (nothing after it)" "A-[" (key-from (esc "[")))
  (test-equal "Alt+O (nothing after it)" "A-O" (key-from (esc "O"))))

(test-group "cursor keys"
  (test-equal "arrows (normal mode)" '("up" "down" "right" "left")
              (keys-from (string-append (esc "[A") (esc "[B") (esc "[C") (esc "[D"))))
  (test-equal "arrows (application mode)" '("up" "down" "right" "left")
              (keys-from (string-append (esc "OA") (esc "OB") (esc "OC") (esc "OD"))))
  (test-equal "Home/End" '("home" "end" "home" "end")
              (keys-from (string-append (esc "[H") (esc "[F") (esc "OH") (esc "OF"))))
  (test-equal "Home/End (VT220)" '("home" "end") (keys-from (string-append (esc "[1~") (esc "[4~"))))
  (test-equal "Home/End (rxvt)" '("home" "end") (keys-from (string-append (esc "[7~") (esc "[8~"))))
  (test-equal "Insert, Delete, PgUp, PgDn" '("insert" "delete" "pageup" "pagedown")
              (keys-from (string-append (esc "[2~") (esc "[3~") (esc "[5~") (esc "[6~")))))

(test-group "function keys"
  (test-equal "F1-F4 (SS3)" '("F1" "F2" "F3" "F4")
              (keys-from (string-append (esc "OP") (esc "OQ") (esc "OR") (esc "OS"))))
  (test-equal "F1-F5 (old xterm, rxvt)" '("F1" "F2" "F3" "F4" "F5")
              (keys-from (apply string-append (map (lambda (n) (esc "[" (number->string n) "~"))
                                                   '(11 12 13 14 15)))))
  (test-equal "F5-F12" '("F5" "F6" "F7" "F8" "F9" "F10" "F11" "F12")
              (keys-from (apply string-append (map (lambda (n) (esc "[" (number->string n) "~"))
                                                   '(15 17 18 19 20 21 23 24)))))
  (test-equal "F1-F5 (Linux console)" '("F1" "F2" "F3" "F4" "F5")
              (keys-from (string-append (esc "[[A") (esc "[[B") (esc "[[C") (esc "[[D") (esc "[[E")))))

(test-group "modifiers"
  (test-equal "Shift+Up" "S-up" (key-from (esc "[1;2A")))
  (test-equal "Alt+Up" "A-up" (key-from (esc "[1;3A")))
  (test-equal "Alt+Shift+Up" "A-S-up" (key-from (esc "[1;4A")))
  (test-equal "Ctrl+Right" "C-right" (key-from (esc "[1;5C")))
  (test-equal "Ctrl+Shift+Left" "C-S-left" (key-from (esc "[1;6D")))
  (test-equal "Ctrl+Alt+Down" "C-A-down" (key-from (esc "[1;7B")))
  (test-equal "Meta counts as Alt" "A-up" (key-from (esc "[1;9A")))
  (test-equal "Ctrl+Home" "C-home" (key-from (esc "[1;5H")))
  (test-equal "Ctrl+Delete" "C-delete" (key-from (esc "[3;5~")))
  (test-equal "Shift+PgDn" "S-pagedown" (key-from (esc "[6;2~")))
  (test-equal "Ctrl+F1 (xterm)" "C-F1" (key-from (esc "[1;5P")))
  (test-equal "Shift+F5" "S-F5" (key-from (esc "[15;2~")))
  (test-equal "Shift+Tab" "S-tab" (key-from (esc "[Z"))))

(test-group "robustness"
  (test-equal "keys straight after a sequence are kept" '("up" "x" "delete" "y")
              (keys-from (string-append (esc "[A") "x" (esc "[3~") "y")))
  (test-equal "unknown sequence is read through its final byte" '("unknown" "q")
              (keys-from (string-append (esc "[99~") "q")))
  (test-equal "unknown CSI letter" '("unknown" "q") (keys-from (string-append (esc "[1;5X") "q")))
  (test-equal "unknown SS3" '("unknown" "q") (keys-from (string-append (esc "Oz") "q")))
  (test-equal "unfinished sequence at end of input" "unknown" (key-from (esc "[12")))
  (test-equal "keypad Enter" "enter" (key-from (esc "OM")))
  (test-equal "end of input" 'eof
              (with-input-from-string "" (lambda () (key-symbol (terminal-read-key))))))

(test-group "terminal queries"
  (test-equal "cursor position report" '(12 . 5)
              (with-input-from-string (esc "[12;5R")
                (lambda () (with-output-to-string (lambda () #t))
                        (let ([pos #f])
                          (with-output-to-string (lambda () (set! pos (terminal-get-cursor-position))))
                          pos))))
  (test-equal "cursor position request is sent" (esc "[6n")
              (with-input-from-string (esc "[1;1R")
                (lambda () (with-output-to-string terminal-get-cursor-position))))
  (let ([size (terminal-get-size)])
    (test-assert "size is two positive integers"
                 (and (pair? size) (exact-integer? (car size)) (exact-integer? (cdr size))
                      (> (car size) 0) (> (cdr size) 0)))))

(test-end "terminal")
