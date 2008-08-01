#!/usr/local/bin/guile
-s
!#

(use-modules (srfi srfi-1)
	     (gucu curses)
	     (gucu menu))

(initscr)
(start-color)
(cbreak)
(noecho)
(keypad (stdscr) #t)
(init-pair 1 COLOR_RED COLOR_BLACK)

(let* (;; Labels for the menu items
       (names '("Choice 1" "Choice 2" "Choice 3" "Choice 4" "Exit"))
       (descriptions '("Description 1" "Description 2" "Description 3"
		       "Description 4" ""))
       
       ;; Create menu items for each label 
       (my-items (map (lambda (name desc) (new-item name desc)) 
		      names
		      descriptions))
       ;; Create the menu
       (my-menu (new-menu my-items))

       ;; Make a windows to hold the menu
       (my-menu-win (newwin 10 40 4 4)))

  (keypad my-menu-win #t)

  ;; Set the main window and subwindow
  (set-menu-win my-menu my-menu-win)
  (set-menu-sub my-menu (derwin my-menu-win 6 38 3 1))

  ;; Set the menu mark string
  (set-menu-mark my-menu " * ")

  ;; Print a border around the main window, and a title
  (box my-menu-win 0 0)

  (wattron my-menu-win (color-pair 1))
  (mvwaddstr my-menu-win 1 10 "My Menu")
  (wattroff my-menu-win (color-pair 1))

  (mvwaddch my-menu-win 2 0 (acs-ltee))
  (mvwhline my-menu-win 2 1 (acs-hline) 38)
  (mvwaddch my-menu-win 2 39 (acs-rtee))
  (mvaddstr (- (lines) 2) 0 "F1 to exit")
  (refresh)

  ;; Post the menu
  (post-menu my-menu)
  (wrefresh my-menu-win)
  
  ;; Draw the menu
  (mvaddstr (- (lines) 2) 0 "F1 to Exit")

  ;; Process the up and down arrow keys.  Break the loop if F1 is
  ;; pressed.  Ignore other keys.
  (let loop ((c (wgetch my-menu-win)))
    (cond

     ;; Move down the menu when down arrow is pressed and then loop.
     ((eqv? c KEY_DOWN)
      (begin
	(menu-driver my-menu REQ_DOWN_ITEM)
	(loop (wgetch my-menu-win))))

     ;; Move up the menu when the up arrow is pressed and then loop.
     ((eqv? c KEY_UP)
      (begin
	(menu-driver my-menu REQ_UP_ITEM)
	(loop (wgetch my-menu-win))))

     ;; When enter is pressed, return the selection and quit.
     ((or (eqv? c KEY_ENTER)
	  (eqv? c (char->integer #\cr))
	  (eqv? c (char->integer #\nl)))
      (begin
	(unpost-menu my-menu)
	(mvaddstr (- (lines) 4) 0 
		  (format #f "You selected item #~a: ~a"
			  (item-index (current-item my-menu))
			  (item-name (current-item my-menu))))
	(refresh)
	(sleep 2)))

     ;; If F1 is pressed, quit.  Otherwise, loop.
     ((not (eqv? c (key-f 1)))
      (loop (getch)))))

  (endwin))