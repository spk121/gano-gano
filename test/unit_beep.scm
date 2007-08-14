#!/usr/local/bin/guile \
--debug -s
!#

;;; unit_beep -- test the function beep

;;; $Id: unit_beep.scm,v 1.3 2007/08/14 04:36:32 spike_gran Exp $

(use-modules (ncurses core))

;;;;
(format #t "TEST: calling beep before initscr\n");
(format #t "Beep: ~s\n" (curs:beep))
(sleep 1)

;;;;
(format #t "TEST: calling beep in initscr\n");
(initscr)
(define b (curs:beep))
(endwin)
(format #t "Beep: ~s\n" b)
(sleep 1)

;;;;
(format #t "TEST: calling beep after endwin\n");
(format #t "Beep: ~s\n" (curs:beep))
