#!/usr/local/bin/guile \
--debug -s
!#

;;; unit_beep -- test the function beep

;;; $Id: unit_beep.scm,v 1.1 2007/08/13 13:58:54 spike_gran Exp $

(use-modules (ncurses core))

(initscr)
(define b (curs:beep))
(endwin)
(if b
    (format #t "Beep.\n")
    (format #t "No beep.\n"))

(sleep 3)

(initscr)
(define f (curs:flash))
(endwin)
(if f
    (format #t "Flash.\n")
    (format #t "No flash.\n"))


