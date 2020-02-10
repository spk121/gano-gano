(use-modules (srfi srfi-64)
             (ncurses curses)
             (gano winio))

(test-begin "t-gano-winio")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; make-winio

(test-assert "make-winio makes a <winio>"
  (winio? (make-winio)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; init-winio!

(test-equal "init-winio! when more-space? is #f and help? is #f"
  '(1 22 1 80)
  (let ((winio (make-winio)))
    (initialize-ncurses winio)
    (init-winio! winio 24 80 #f #f)
    (move-cursor-to-last-line-and-endwin winio)
    (list
     (get-top-win-lines winio)
     (get-edit-win-lines winio)
     (get-bottom-win-lines winio)
     (get-cols winio))))

(test-equal "init-winio! when more-space? is #f and help? is #t"
  '(1 20 3 80)
  (let ((winio (make-winio)))
    (initialize-ncurses winio)
    (init-winio! winio 24 80 #f #t)
    (move-cursor-to-last-line-and-endwin winio)
    (list
     (get-top-win-lines winio)
     (get-edit-win-lines winio)
     (get-bottom-win-lines winio)
     (get-cols winio))))

(test-equal "init-winio! when more-space? is #t and help? is #f"
  '(2 21 1 80)
  (let ((winio (make-winio)))
    (initialize-ncurses winio)
    (init-winio! winio 24 80 #t #f)
    (move-cursor-to-last-line-and-endwin winio)
    (list
     (get-top-win-lines winio)
     (get-edit-win-lines winio)
     (get-bottom-win-lines winio)
     (get-cols winio))))

(test-equal "init-winio! when more-space? is #t and help? is #t"
  '(2 19 3 80)
  (let ((winio (make-winio)))
    (initialize-ncurses winio)
    (init-winio! winio 24 80 #t #t)
    (move-cursor-to-last-line-and-endwin winio)
    (list
     (get-top-win-lines winio)
     (get-edit-win-lines winio)
     (get-bottom-win-lines winio)
     (get-cols winio))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; display-string
(define string-data-ascii               "abcdefghijklmnopqrstuvwxyz")
(test-equal "display-string ascii, no tabs, all characters"
  "hello"
  (display-string "hello" 0 100 #t))

(test-equal "display-string ascii, no tabs, starting from 1st column"
  "ello"
  (display-string "hello" 1 100 #t))

(test-equal "display-string ascii, no tabs, starting from 2nd column"
  "llo"
  (display-string "hello" 2 100 #t))

(test-equal "display-string ascii, no tabs, truncated, no dollars"
  "hel"
  (display-string "hello" 0 3 #f))

(test-equal "display-string ascii, no tabs, truncated, dollars"
  "he"
  (display-string "hello" 0 3 #t))

(define test-text-kanji
  "老婆は、一目下人を見ると、まるで弩（いしゆみ）にでも弾かれたように　飛び上がった。")

(test-equal "display-string kanji, no tabs, all characters"
  test-text-kanji
  (display-string test-text-kanji 0 100 #t))

(test-equal "display-string kanji, no tabs, starting from 1st column"
  (string-append
   " "
   (substring test-text-kanji 1))
  (display-string test-text-kanji 1 100 #t))

(test-equal "display-string kanji, no tabs, starting from 2nd column"
  (substring test-text-kanji 1)
  (display-string test-text-kanji 2 100 #t))

(test-equal "display-string kanji, no tabs, truncated, no dollars"
  "老"
  (display-string test-text-kanji 0 3 #f))

(test-equal "display-string ascii, no tabs, truncated, dollars"
  "老"
  (display-string test-text-kanji 0 3 #t))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; display-titlebar
(test-equal "display-titlebar no path, file, not modified, not readonly"
  "Gano 0.0  New Buffer"
  (let ((winio (make-winio)))
    (initialize-ncurses winio)
    (init-winio! winio 24 40 #t #t)
    (display-titlebar winio "" #t #f #f)
    (let ((str (string-trim-both (read-titlebar winio))))
      (move-cursor-to-last-line-and-endwin winio)
      str)))

(test-equal "display-titlebar no path, file, modified, not readonly"
  "Gano 0.0  New Buffer Modified"
  (let ((winio (make-winio)))
    (initialize-ncurses winio)
    (init-winio! winio 24 40 #t #t)
    (display-titlebar winio "" #t #t #f)
    (let ((str (string-trim-both (read-titlebar winio))))
      (move-cursor-to-last-line-and-endwin winio)
      str)))

(test-equal "display-titlebar path, file, not modified, not readonly"
  "Gano 0.0  File:  temp.txt"
  (let ((winio (make-winio)))
    (initialize-ncurses winio)
    (init-winio! winio 24 40 #t #t)
    (display-titlebar winio "temp.txt" #t #f #f)
    (let ((str (string-trim-both (read-titlebar winio))))
      (move-cursor-to-last-line-and-endwin winio)
      str)))

(test-equal "display-titlebar path, file, not modified, not readonly"
  "Gano 0.0  File:  temp.txt"
  (let* ((winio (make-winio)))
    (initialize-ncurses winio)
    (init-winio! winio 24 40 #t #t)
    (display-titlebar winio "temp.txt" #t #f #f)
    (refresh (get-top-win winio))
    (sleep 1)
    (let ((str (string-trim-both (read-titlebar winio))))
      (move-cursor-to-last-line-and-endwin winio)
      str)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; display-statusbar

(test-equal "display-statusbar short ascii"
  "[ This is a sample error message ]"
  (let* ((winio (make-winio)))
    (initialize-ncurses winio)
    (init-winio! winio 24 40 #t #t)
    (refresh (get-main-win winio))
    (display-statusbar winio "This is a sample error message")
    (refresh (get-bottom-win winio))
    ;; (sleep 1)
    (let ((str (string-trim-both (read-statusbar winio))))
      (move-cursor-to-last-line-and-endwin winio)
      str)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; display-shortcut-list
(test-equal "display-shortcut-list one shortcut"
  "^G Help"
  (let* ((winio (make-winio)))
      (initialize-ncurses winio)
    (init-winio! winio 24 40 #t #t)
    (refresh (get-main-win winio))
    (display-shortcut-list winio '("^G") '("Help"))
    (refresh (get-bottom-win winio))
    ;; (sleep 3)
    (let ((str (string-trim-both (read-shortcut-list winio))))
      (move-cursor-to-last-line-and-endwin winio)
      str)))

(define shortcuts
  '("^A" "^B" "^C" "^D" "^E" "^F" "^G" "^H" "^I" "^J" "^K" "^L" "^M" "^N"))
(define descriptions
  '("Alpha" "Bravo" "Charlie" "Delta" "Echo" "Foxtrot" "Golf" "Hotel" "India"
    "Juliet" "Kilo" "Lima" "Mike" "November"))

(test-equal "display-shortcut-list many shortcuts"
  "^A Alp^C Cha^E Ech^G Gol^I Ind^K Kilo   \n^B Bra^D Del^F Fox^H Hot^J Jul^L Lima"
  (let ((winio (make-winio)))
    (initialize-ncurses winio)
    (init-winio! winio 24 40 #t #t)
    (refresh (get-main-win winio))
    (display-shortcut-list winio shortcuts descriptions)
    (refresh (get-bottom-win winio))
    ;; (sleep 3)
    (let ((str (string-trim-both (read-shortcut-list winio))))
      (move-cursor-to-last-line-and-endwin winio)
      str)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; display-editor
(test-equal "display-editor two lines"
  "hello                                   \nworld                                   \n"
  (let* ((winio (make-winio)))
    (initialize-ncurses winio)
    (init-winio! winio 24 40 #t #t)
    (refresh (get-main-win winio))
    (display-editor winio '("hello" "world") 0)
    (refresh (get-edit-win winio))
    ;; (sleep 3)
    (let ((str (read-editor winio)))
      (move-cursor-to-last-line-and-endwin winio)
      (substring str 0 82))))

(test-end "t-gano-winio")
