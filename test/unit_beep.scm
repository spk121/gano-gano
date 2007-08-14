#!/usr/local/bin/guile \
--debug -s
!#

;;; unit_beep -- test the function beep

;;; $Id: unit_beep.scm,v 1.2 2007/08/14 04:02:19 spike_gran Exp $

(read-enable 'positions)
(set! %load-path (append %load-path '(".")))

(use-modules (ncurses core)
	     (testeez))

(use-syntax (ice-9 syncase))

(define (%ncurses:test)
  (testeez
   "Unit Beep"
   
   (test/equal "Beep"
	       (and
		(initscr)
		(curs:beep)
		(endwin))
	       #t)
   
   (test/equal "Flash"
	       (and
		(initscr)
		(curs:flash)
		(endwin))
	       #t)))

(%ncurses:test)
