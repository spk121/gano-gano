#!/usr/local/bin/guile \
-s
!#
;;; keypress.scm -- examine the raw keycodes returned when keys are pressed

(use-modules (gucu curses)
	     (ice-9 format)
	     (srfi srfi-1))

(initscr)
(define keyflag #t)
(keypad (stdscr) keyflag)
(cbreak)
(noecho)
(nonl)
(scrollok (stdscr) #t)
(mousemask *all-mouse-events*)

(define c #f)
(mvaddstr 0 0 "Press any key to see its name\n")
(addstr "Press TAB to toggle the interpretation of function keys\n")
(addstr "Press Ctrl-C to quit\n")
(while #t
       (begin
	 (set! c (getch))
	 (addstr (format #f "~S ~S~%" c (keyname c)))
	 (if (eqv? c 3)
	     (break))
	 (if (eqv? c 9)
	     (begin
	       (set! keyflag (not keyflag))
	       (keypad (stdscr) keyflag)))
	 (if (eqv? c *key-mouse*)
	     (let* ((m (getmouse))
		    (mflag (fifth m)))
	       (addstr (format #f "x=~a y=~a flag=~x~%" 
			       (second m)
			       (third m)
			       mflag))
	       (cond
		((logtest *button-shift* mflag)
		 (addstr "shift "))
		((logtest *button-ctrl* mflag)
		 (addstr "ctrl "))
		((logtest *button-alt* mflag)
		 (addstr "alt "))
		((logtest *button1-pressed* mflag)
		 (addstr "button 1 pressed\n"))
		((logtest *button1-released* mflag)
		 (addstr "button 1 released\n"))
		((logtest *button1-clicked* mflag)
		 (addstr "button 1 clicked\n"))
		((logtest *button1-double-clicked* mflag)
		 (addstr "button 1 double clicked\n"))
		((logtest *button2-pressed* mflag)
		 (addstr "button 2 pressed\n"))
		((logtest *button2-released* mflag)
		 (addstr "button 2 released\n"))
		((logtest *button2-clicked* mflag)
		 (addstr "button 2 clicked\n"))
		((logtest *button2-double-clicked* mflag)
		 (addstr "button 2 double clicked\n"))
		((logtest *button3-pressed* mflag)
		 (addstr "button 3 pressed\n"))
		((logtest *button3-released* mflag)
		 (addstr "button 3 released\n"))
		((logtest *button3-clicked* mflag)
		 (addstr "button 3 clicked\n"))
		((logtest *button3-double-clicked* mflag)
		 (addstr "button 3 double clicked\n")))))
	     
	 (refresh)))

(endwin)