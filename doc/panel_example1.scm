#!/usr/local/bin/guile
-s
!#

(use-modules (srfi srfi-1)
             (gucu curses)
             (gucu panel))

(define stdscr (initscr))
(cbreak)
(noecho)

(let* ((lines 10)
       (cols 40)
       (y 2)
       (x 4)

       ;; Create windows for the panels
       (wins (list-tabulate 
              3 
              (lambda (n) (newwin lines cols (+ y n) (+ x (* 5 n))))))

       ;; Attach a panel to each window
       (panels (map-in-order new-panel wins)))

  ;; Create borders around the windows so that you can see the effect
  ;; of panels
  (map (lambda (w) (box w 0 0))
       wins)

  ;; Show it on the screen
  (update-panels)
  (doupdate)
  (getch stdscr)
  (endwin))

            