(begin-test-case)
(add-string "Test 3: color...\n" #:window right-window)

(add-string "Starting color\n" #:window right-window)
(start-color)
(use-default-colors)
(refresh #:window right-window)
(sleep 1)

(add-string "Checking for color capability\n" #:window right-window)
(refresh #:window right-window)

(if (has-colors?)
    (add-string "has colors: TRUE\n" #:window left-window)
    (add-string "has colors: FALSE\n" #:window left-window))
(refresh #:window left-window)

(if (can-change-color?)
    (add-string "can change color: TRUE\n" #:window left-window)
    (add-string "can change color: FALSE\n" #:window left-window))
(refresh #:window left-window)

(add-string (format #f "num colors: ~s~%" (colors)) #:window left-window)
(add-string 
 (format #f "num color pairs: ~s~%" (color-pairs)) #:window left-window)
(refresh #:window left-window)

(add-character (logior (color-pair 0) (char->integer #\X)) #:window left-window)
(set-color-pair! 1 *color-black* *color-red*)
(set-color-pair! 2 *color-green* *color-yellow*)
(set-color-pair! 3 *color-blue* *color-magenta*)
(set-color-pair! 4 *color-cyan* *color-white*)

(add-string " default on default\n" #:window left-window)
(add-character (logior (color-pair 1) (char->integer #\X)) #:window left-window)
(add-string " black on red\n" #:window left-window)
(add-character (logior (color-pair 2) (char->integer #\X)) #:window left-window)
(add-string " green on yellow\n" #:window left-window)
(add-character (logior (color-pair 3) (char->integer #\X)) #:window left-window)
(add-string " blue on magenta\n" #:window left-window)
(add-character (logior (color-pair 4) (char->integer #\X)) #:window left-window)
(add-string " cyan on white\n" #:window left-window)

(refresh #:window left-window)

(add-string (format #f "color-pair 0 ~s~%" (color-pair-content 0))  
	    #:window left-window)
(add-string (format #f "color-pair 1 ~s~%" (color-pair-content 1))  
	    #:window left-window)
(add-string (format #f "color-pair 2 ~s~%" (color-pair-content 2))  
	    #:window left-window)
(add-string (format #f "color-pair 3 ~s~%" (color-pair-content 3))  
	    #:window left-window)
(add-string (format #f "color-pair 4 ~s~%" (color-pair-content 4))  
	    #:window left-window)
(refresh #:window left-window)

(add-string (format #f "RGB of red is ~s~%" (color-content *color-red*))
	    #:window left-window)
(add-string (format #f "RGB of green is ~s~%" (color-content *color-green*))
	    #:window left-window)
(add-string (format #f "RGB of white is ~s~%" (color-content *color-white*))
	    #:window left-window)
(refresh #:window left-window)

(end-test-case)

