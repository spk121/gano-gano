(use-modules (srfi srfi-64)
             (ncurses curses)
             (gano input))

(test-begin "t-gano-input")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; getch
(test-equal "getch #\\x"
  #\x
  (let ((win (initscr)))
    (cbreak!)
    (noecho!)
    (nonl!)
    (intrflush! #f)
    (keypad! win #t)
    (scrollok! win #t)
    (ungetch #\x)
    (let ((input (getch win)))
      (endwin)
      input)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get-kbinput

(define (setup)
  (let ((win (initscr)))
    (cbreak!)
    (noecho!)
    (nonl!)
    (intrflush! #f)
    (keypad! win #t)
    (scrollok! win #t)
    win))

(define-syntax chartest
  (syntax-rules ()
    ((chartest title result char)
     (test-equal title
       result
       (let ((win (setup)))
         (ungetch char)
         (let ((input (get-kbinput win)))
           (endwin)
           input))))
    
    ((chartest title result char1 char2)
     (test-equal title
       result
       (let ((win (setup)))
         (ungetch char2)
         (ungetch char1)
         (let ((input (get-kbinput win)))
           (endwin)
           input))))))


(chartest "get-kbinput #\\null" '(raw #\null) #\null)
(chartest "get-kbinput #\\space" '(raw #\space) #\space)
(chartest "get-kbinput #\\X" '(raw #\X) #\X)
(chartest "get-kbinput #\\esc #\\X" '(meta #\X) #\esc #\X)
(chartest "get-kbinput #\\esc #\\newline" '(meta #\newline) #\esc #\newline)

(test-end "t-gano-input")
