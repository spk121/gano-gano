(begin-test-case)
(add-string "Test 5: add-string...\n" #:window right-window)

(set-color-pair! 4 *color-cyan* *color-white*)
(define str1 "pow!")
(define str2 "blam!")
;; non-moving version

(add-string "Add 'pow!' to stdscr\n" #:window right-window)
(move #:x 0 #:y 0)
(add-string str1)
(refresh)
(refresh #:window right-window)

(add-string "Add 2 chars of 'pow!' to stdscr\n" #:window right-window)
(add-string str1 #:n 2)
(refresh)
(refresh #:window right-window)

(add-string "Add 'blam!' to window\n" #:window right-window)
(move #:x 0 #:y 0 #:window left-window)
(add-string str2 #:window left-window)
(refresh #:window left-window)
(refresh #:window right-window)

(add-string "Add 2 chars of 'blam!' to window\n" #:window right-window)
(add-string str2 #:n 2 #:window left-window)
(refresh #:window left-window)
(refresh #:window right-window)

;; move-first version

(add-string "Add 'pow!' to stdscr at 8,0 \n" #:window right-window)
(add-string str1 #:x 8 #:y 0)
(refresh)
(refresh #:window right-window)

(add-string "Add 2 chars of 'pow!' to stdscr at 8,1\n" #:window right-window)
(add-string str1 #:n 2 #:x 8 #:y 1)
(refresh)
(refresh #:window right-window)

(add-string "Add 'blam!' to window at 8,0\n" #:window right-window)
(add-string str2 #:window left-window #:x 8 #:y 0)
(refresh #:window left-window)
(refresh #:window right-window)

(add-string "Add 2 chars of 'blam!' to window at 8,4\n" #:window right-window)
(add-string str2 #:n 2 #:window left-window #:x 8 #:y 4)
(refresh #:window left-window)
(refresh #:window right-window)



(end-test-case)

