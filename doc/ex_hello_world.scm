#!/usr/bin/guile
!#
(use-modules (gucu curses))

(define screen (initscr))
(addstr screen "Hello World!!!")       
(refresh screen)      
(getch screen)
(endwin)
