#!/usr/local/bin/guile \
--debug -e main -s
!#

;;;tclock - analog/digital clock for curses

;; based on tclock.c as distributed the ncurses distribution

;; tclock.c bears the following copyright  

;; "This program is copyright Howard Jones, September 1994
;; (ha.jones@ic.ac.uk). It may be freely distributed as long as this
;; copyright message remains intact, and any modifications are clearly
;; marked as such. [In fact, if you modify it, I wouldn't mind the
;; modifications back, especially if they add any nice features. A
;; good one would be a precalc table for the 60 hand positions, so
;; that the floating point stuff can be ditched. As I said, it was a
;; 20 hackup minute job.] "


(display "Loading tclock.scm...")
(newline)

(use-modules (ncurses core))

(define *aspect* 2.2)

;; Plot a point
(define (plot x y col)
  (mvaddch (inexact->exact (round y)) 
	   (inexact->exact (round x)) 
	   col))

(define (sign x)
  (if (negative? x)
      -1
      1))

;; Draw a diagonal abitrary line using Bresenham's algorithm
(define (dline pair from_x from_y x2 y2 ch)
  (let* ((dx (- x2 from_x))
	 (dy (- y2 from_y))
	 (ax (abs (* 2 dx)))
	 (ay (abs (* 2 dy)))
	 (sx (sign dx))
	 (sy (sign dy)))
    (if (has-colors)
	(attrset (color-pair pair)))
    (if (> ax ay)

	(let loop ((d (- ay (/ ax 2)))
		   (x from_x)
		   (y from_y))
	  (if (not (equal? x x2))
	      (begin
		(plot x y ch)
		(if (>= d 0)
		    (loop (+ d (- ax) ay) 
			  (+ x sx)
			  (+ y sy))
		    (loop (+ d ay)
			  (+ x sx)
			  y)))
	      #t))

	(let loop ((d (- ax (/ ay 2)))
		   (x from_x)
		   (y from_y))
	  (if (not (equal? y y2))
	      (begin
		(plot x y ch)
		(if (>= d 0)
		    (loop (+ d (- ay) ax) 
			  (+ x sx)
			  (+ y sy))
		    (loop (+ d ax)
			  x
			  (+ y sy))))
	      #t)))))

(define (a2x angle radius)
  (inexact->exact (round (* *aspect* radius (sin angle)))))

(define (a2y angle radius)
  (inexact->exact (round (* radius (cos angle)))))

(define (hour-angle h)
  (* h (/ 3.14159 6.0))) 

(define (minute-angle m)
  (* m (/ 3.14159 30.0)))

(define (second-angle s)
  (* s (/ 3.14159 30.0)))
  

(define (main args)
  (let ((my-bg *color-black*))
    (begin
      (display "Starting main loop...")
      (newline)
      (setlocale LC_ALL "")
      (initscr)
      (noecho)
      (cbreak)
      (nodelay (stdscr) #t)
      (curs-set 0)
      (if (has-colors)
	  (begin
	    (start-color)
	    (if (use-default-colors)
		(set! my-bg -1))
	    (init-pair 1 *color-red* my-bg)
	    (init-pair 2 *color-magenta* my-bg)
	    (init-pair 3 *color-green* my-bg)
	    (init-pair 4 *color-white* *color-blue*)))
      (keypad (stdscr) #t)
      (let* ((cx (/ (- (cols) 1) 2))	; usually 39
	     (cy (/ (lines) 2))		; usually 12
	     (cr (if (< (/ cx *aspect*) cy)
		     (/ cx *aspect*)
		     cy))
	     (nradius (/ (* 5 cr) 6))	; radius of numbers
	     (sradius (/ (* 2 cr) 3))	; radius of second hand
	     (mradius (/ (* 3 cr) 4))	; radius of minute hand
	     (hradius (/ cr 2)))	; radius of hour hand
	(let loop ((i 1))
	  (if (<= i 12)
	      (begin
		(mvaddstr (round (- cy (a2y (hour-angle i) nradius)))
			  (round (+ cx (a2x (hour-angle i) nradius)))
			  (number->string i))
		(loop (+ i 1)))
	      #t))
	(mvaddstr 0 0 "ASCII Clock a la Howard Jones")
	(while (not (getch))
	       (begin
		 (let* ((now (localtime (current-time)))
			(hour (+ (tm:hour now) (/ (tm:min now) 60.0)))
			(hdx (a2x (hour-angle hour) hradius))
			(hdy (a2y (hour-angle hour) hradius))
			
			(min (+ (tm:min now) (/ (tm:sec now) 60.0)))
			(mdx (a2x (minute-angle min) mradius))
			(mdy (a2y (minute-angle min) mradius))
			
			(sec (tm:sec now))
			(sdx (a2x (second-angle sec) sradius))
			(sdy (a2y (second-angle sec) sradius)))
		   
		   (begin
		     (dline 3 cx cy (+ cx mdx) (- cy mdy) #\#)
		     (attrset *a-reverse*)
		     (dline 2 cx cy (+ cx hdx) (- cy hdy) #\.)
		     (attroff *a-reverse*)
		     (if (has-colors)
			 (attrset (color-pair 1)))
		     (dline 1 cx cy (+ cx sdx) (- cy sdy) #\O)
		     (if (has-colors)
			 (attrset (color-pair 0)))
		     (mvaddstr 2 0 (strftime "%c" now))
		     (refresh)
		     (napms 500)
		     
		     ;; erase the lines
		     (dline 0 cx cy (+ cx hdx) (- cy hdy) #\sp)
		     (dline 0 cx cy (+ cx mdx) (- cy mdy) #\sp)
		     (dline 0 cx cy (+ cx sdx) (- cy sdy) #\sp)))))
	(curs-set 1)
	(endwin)
	0))))
			  
      
	    
		     
	     
  
  