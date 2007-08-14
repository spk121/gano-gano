#!/usr/local/bin/guile \
--debug -s
!#

;;; unit_baudrate -- test the baudrate function

;; $Id: unit_baudrate.scm,v 1.2 2007/08/14 04:17:14 spike_gran Exp $
(use-modules (ncurses core))

;;;;
; (format #t "TEST: calling baudrate before initscr\n");
; (format #t "Baudrate: ~s\n" (baudrate))
;; FIXME: segmentation fault!

;;;;
(format #t "TEST: calling baudrate in initscr\n");
(initscr)
(define b (baudrate))
(endwin)
(format #t "Baudrate: ~s\n" b)

;;;;
(format #t "TEST: calling baudrate after endwin\n");
(format #t "Baudrate: ~s\n" (baudrate))


