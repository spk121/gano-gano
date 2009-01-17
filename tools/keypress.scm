#!/usr/local/bin/guile \
-s
!#
;;; keypress.scm -- examine the raw keycodes returned when keys are pressed

(use-modules (gucu curses)
	     (ice-9 format)
	     (srfi srfi-1))

(define stdscr (initscr))
(define keyflag #t)
(keypad! stdscr keyflag)
(cbreak)
(noecho)
(nonl)
(scrollok (stdscr) #t)
(mousemask ALL_MOUSE_EVENTS)

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
	 (if (eqv? c KEY_MOUSE)
	     (let* ((m (getmouse))
		    (mflag (fifth m)))
	       (addstr (format #f "x=~a y=~a flag=~x~%" 
			       (second m)
			       (third m)
			       mflag))
	       (cond
		((logtest BUTTON_SHIFT mflag)
		 (addstr "shift "))
		((logtest BUTTON_CTRL mflag)
		 (addstr "ctrl "))
		((logtest BUTTON_ALT mflag)
		 (addstr "alt "))
		((logtest BUTTON1_PRESSED mflag)
		 (addstr "button 1 pressed\n"))
		((logtest BUTTON1_RELEASED mflag)
		 (addstr "button 1 released\n"))
		((logtest BUTTON1_CLICKED mflag)
		 (addstr "button 1 clicked\n"))
		((logtest BUTTON1_DOUBLE_CLICKED mflag)
		 (addstr "button 1 double clicked\n"))
		((logtest BUTTON2_PRESSED mflag)
		 (addstr "button 2 pressed\n"))
		((logtest BUTTON2_RELEASED mflag)
		 (addstr "button 2 released\n"))
		((logtest BUTTON2_CLICKED mflag)
		 (addstr "button 2 clicked\n"))
		((logtest BUTTON2_DOUBLE_CLICKED mflag)
		 (addstr "button 2 double clicked\n"))
		((logtest BUTTON3_PRESSED mflag)
		 (addstr "button 3 pressed\n"))
		((logtest BUTTON3_RELEASED mflag)
		 (addstr "button 3 released\n"))
		((logtest BUTTON3_CLICKED mflag)
		 (addstr "button 3 clicked\n"))
		((logtest BUTTON3_DOUBLE_CLICKED mflag)
		 (addstr "button 3 double clicked\n")))))
	     
	 (refresh)))

(endwin)