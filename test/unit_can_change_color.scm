#!/usr/local/bin/guile \
--debug -s
!#

;;; unit_can_change_color

;; $Id: unit_can_change_color.scm,v 1.1 2007/08/14 04:36:32 spike_gran Exp $
(use-modules (ncurses core))

;;;;
;; (format #t "TEST: calling can-change-color before initscr\n");
;; (format #t "Can change color? ~s\n" (can-change-color))
;; FIXME: segmentation fault!

;;;;
(format #t "TEST: calling can-change-color after initscr but before start-color\n");
(initscr)
(define c (can-change-color))
(endwin)
(format #t "Can change color? ~s\n" c)

;;;;
(format #t "TEST: calling can-change-color normally\n");
(initscr)
(start-color)
(set! c (can-change-color))
(endwin)
(format #t "Can change color? ~s\n" c)

;;;;
(format #t "TEST: calling can-change-color after endwin\n");
(format #t "Can change color? ~s\n" (can-change-color))


