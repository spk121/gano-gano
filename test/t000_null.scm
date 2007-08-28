(begin-test-case)
(add-string "Test 0: do nothing...\n" #:window right-window)
(add-string "Test info goes here\n" #:window right-window)
(refresh #:window right-window)

(add-string "Window results go here\n" #:window left-window)
(refresh #:window left-window)

(move #:x 0 #:y 0)
(add-string "*stdscr* results go here")
(refresh)
 
(end-test-case)

