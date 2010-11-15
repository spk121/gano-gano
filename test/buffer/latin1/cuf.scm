;; coding: iso-8859-1

;; CURSOR RIGHT

(setlocale LC_ALL "")

(use-modules (gano CBuffer)
	     (oop goops))

(load "testlib.scm")

(init-buf! buf data-string-ascii)

;; Cursor-right moves the presentation positions rightwards by n characters
(set-positions! buf 3 'data)
(cursor-right buf 1)
(test "cursor-right 1" 
      (and (= 4 (get-pd-cur buf))
	   (= 4 (get-pp-cur buf))
	   (= 4 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

(set-positions! buf 3 'data)
(cursor-right buf 2)
(test "cursor-right 2" 
      (and (= 5 (get-pd-cur buf))
	   (= 5 (get-pp-cur buf))
	   (= 5 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a cursor right past end column
(set-positions! buf 2 'data)
(cursor-right buf 30)
(test "cursor-right past end" 
      (and (= 26 (get-pd-cur buf))
	   (= 26 (get-pp-cur buf))
	   (= 26 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a cursor right from home
(set-positions! buf 0 'data)
(cursor-right buf 1)
(test "cursor right from home"
      (and (= 1 (get-pd-cur buf))
	   (= 1 (get-pp-cur buf))
	   (= 1 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a cursor right from end
(set-positions! buf 26 'data)
(cursor-right buf 1)
(test "cursor right from end"
      (and (= 26 (get-pd-cur buf))
	   (= 26 (get-pp-cur buf))
	   (= 26 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Tabs test: cursor right over tabs
(init-buf! buf data-string-tabs)
(set-positions! buf 2 'data)
(cursor-right buf 1)
(test "cursor right over tabs"
      (and (= 2 (get-pd-cur buf))
	   (= 9 (get-pp-cur buf))
	   (= 10 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-tabs)))

;; Tabs test: cursor right starting in the middle of a tab
(init-buf! buf data-string-tabs)
(set-positions! buf 2 'presentation)
(cursor-right buf 1)
(test "cursor right from within tabs"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 3 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-tabs)))

