(begin-test-case)
(add-string "Test 4: add characters...\n" #:window right-window)
(refresh #:window right-window)

(move #:x 0 #:y 0)
(move #:x 0 #:y 0 #:window left-window)


(add-string "Put 'a' in stdscr\n" #:window right-window)
(add-character #\a);

(add-string "Put 'b' in window\n" #:window right-window)
(add-character #\b #:window left-window)

(add-string "Put 'c' in stcscr at 1, 1\n" #:window right-window)
(add-character #\c #:x 1 #:y 1)

(add-string "Put 'd' in window at 1, 1\n" #:window right-window)
(add-character #\d #:window left-window #:x 1 #:y 1)
(refresh #:window left-window)
(refresh #:window right-window)
(refresh)


(add-string "Echo 'e' in stdscr\n" #:window right-window)
(refresh #:window right-window)
(echo-character #\e)

(add-string "Echo 'f' in window\n" #:window right-window)
(refresh #:window right-window)
(echo-character #\e #:window left-window)

(add-string "Separate x's with a TAB \n" #:window right-window)
(add-string (format #f "~%tabsize: ~s~%" (tabsize)) #:window left-window)
(add-character #\x #:window left-window) 
(add-character #\tab #:window left-window)
(add-character #\x #:window left-window)
(refresh #:window left-window)
(refresh #:window right-window)

(set-tabsize! 6)

(add-string "Set tabsize to 6\n" #:window right-window)
(add-string (format #f "~%tabsize: ~s~%" (tabsize)) #:window left-window)
(add-character #\x #:window left-window) 
(add-character #\tab #:window left-window)
(add-character #\x #:window left-window)
(refresh #:window left-window)
(refresh #:window right-window)

(end-test-case)

