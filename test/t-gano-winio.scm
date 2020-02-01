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
    (initscr)
    (init-winio! winio 24 80 #f #f)
    (endwin)
    (list
     (get-top-win-lines winio)
     (get-edit-win-lines winio)
     (get-bottom-win-lines winio)
     (get-cols winio))))

(test-equal "init-winio! when more-space? is #f and help? is #t"
  '(1 20 3 80)
  (let ((winio (make-winio)))
    (initscr)
    (init-winio! winio 24 80 #f #t)
    (endwin)
    (list
     (get-top-win-lines winio)
     (get-edit-win-lines winio)
     (get-bottom-win-lines winio)
     (get-cols winio))))

(test-equal "init-winio! when more-space? is #t and help? is #f"
  '(2 21 1 80)
  (let ((winio (make-winio)))
    (initscr)
    (init-winio! winio 24 80 #t #f)
    (endwin)
    (list
     (get-top-win-lines winio)
     (get-edit-win-lines winio)
     (get-bottom-win-lines winio)
     (get-cols winio))))

(test-equal "init-winio! when more-space? is #t and help? is #t"
  '(2 19 3 80)
  (let ((winio (make-winio)))
    (initscr)
    (init-winio! winio 24 80 #t #t)
    (endwin)
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
    (initscr)
    (init-winio! winio 24 40 #t #t)
    (display-titlebar winio "" #t #f #f)
    (let ((str (string-trim-both (read-titlebar winio))))
      (endwin)
      str)))

(test-equal "display-titlebar no path, file, modified, not readonly"
  "Gano 0.0  New Buffer Modified"
  (let ((winio (make-winio)))
    (initscr)
    (init-winio! winio 24 40 #t #t)
    (display-titlebar winio "" #t #t #f)
    (let ((str (string-trim-both (read-titlebar winio))))
      (endwin)
      str)))

(test-equal "display-titlebar path, file, not modified, not readonly"
  "Gano 0.0  File:  temp.txt"
  (let ((winio (make-winio)))
    (initscr)
    (init-winio! winio 24 40 #t #t)
    (display-titlebar winio "temp.txt" #t #f #f)
    (let ((str (string-trim-both (read-titlebar winio))))
      (endwin)
      str)))

(test-equal "display-titlebar path, file, not modified, not readonly"
  "Gano 0.0  File:  temp.txt"
  (let* ((winio (make-winio))
         (mainwin (initscr)))
    (init-winio! winio 24 40 #t #t)
    (display-titlebar winio "temp.txt" #t #f #f)
    (refresh (get-top-win winio))
    (sleep 3)
    (let ((str (string-trim-both (read-titlebar winio))))
      (endwin)
      str)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; display-statusbar

(test-equal "display-statusbar short ascii"
  "[ This is a sample error message ]"
  (let ((winio (make-winio))
        (mainwin (initscr)))
    (init-winio! winio 24 40 #t #t)
    (refresh mainwin)
    (display-statusbar winio "This is a sample error message")
    (refresh (get-bottom-win winio))
    (sleep 3)
    (let ((str (string-trim-both (read-statusbar winio))))
      (endwin)
      str)))

(test-end "t-gano-winio")
