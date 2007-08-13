#!/usr/local/bin/guile \
--debug -s
!#

;;; unit_baudrate -- test the baudrate function

;; $Id: unit_baudrate.scm,v 1.1 2007/08/13 13:58:54 spike_gran Exp $
(use-modules (ncurses core))

(initscr)
(define b (baudrate))
(endwin)

(format #t "Baudrate: ~s\n" b)


