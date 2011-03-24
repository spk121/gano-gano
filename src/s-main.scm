;; s-main.scm -- a state loop for the top-level


(define-syntax state-methods
  (syntax-rules ()
    ((_ a b c)
     (list (cons 'setup a)
           (cons 'update b)
           (cons 'draw c)))))
(define *splash-screen*
  (list "Welcome to GANO, a nearly useless editor written in GUILE."
        "Press 'n' to open a new, empty buffer."
        "Press 'f' to open an existing file."
        "Press 'q' to quit."))

(define (main-state)
  "This procedure creates the initial menu and then passes control
to the editor or file browser."
  (let ([splash-screen-complete #f])
    (let ([setup
           (lambda ()
             ;; The main screen is has only one window
             #t)]
          [draw
           (lambda ()
             (unless splash-screen-complete
               (border vWinMain 0 0 0 0 0 0 0 0)
               (addstr vWinMain (list-ref *splash-screen* 0) #:y 2 #:x 2)
               (addstr vWinMain (list-ref *splash-screen* 1) #:y 4 #:x 4)
               (addstr vWinMain (list-ref *splash-screen* 2) #:y 6 #:x 4)
               (addstr vWinMain (list-ref *splash-screen* 3) #:y 8 #:x 4)
               (refresh vWinMain)))]
          [update
           (lambda ()
             (let ([c (getch vWinMain)])
               (cond
                [(char-ci=? c #\n)
                 (gano start (edit-state))]
                [(char-ci=? c #\f)
                 (gano start file-browser-state)]
                [(char-ci=? c #\q)
                 #f]
                [else
                 ;; ignore, but keep looping
                 #t])))])
      (state-methods setup update draw))))
