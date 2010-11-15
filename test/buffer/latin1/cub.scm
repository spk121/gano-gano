;; coding: iso-8859-1

;; CURSOR LEFT

(setlocale LC_ALL "")

(use-modules (gano CBuffer)
	     (oop goops))

(load "testlib.scm")

(init-buf! buf data-string-ascii)

;; Cursor-left moves the presentation positions leftwards by n characters
(set-positions! buf 3 'data)
(cursor-left buf 1)
(test "cursor-left 1" 
      (and (= 2 (get-pd-cur buf))
	   (= 2 (get-pp-cur buf))
	   (= 2 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

(set-positions! buf 3 'data)
(cursor-left buf 2)
(test "cursor-left 2" 
      (and (= 1 (get-pd-cur buf))
	   (= 1 (get-pp-cur buf))
	   (= 1 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a cursor left past home column
(set-positions! buf 2 'data)
(cursor-left buf 3)
(test "cursor-left past home" 
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a cursor left from home
(set-positions! buf 0 'data)
(cursor-left buf 1)
(test "cursor left from home"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a cursor left from end
(set-positions! buf 26 'data)
(cursor-left buf 1)
(test "cursor left from end"
      (and (= 25 (get-pd-cur buf))
	   (= 25 (get-pp-cur buf))
	   (= 25 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Tabs test: cursor left over tabs
(init-buf! buf data-string-tabs)
(set-positions! buf 1 'data)
(cursor-left buf 1)
(test "cursor left over tabs"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 7 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-tabs)))

;; Tabs test: cursor left starting in the middle of a tab
(init-buf! buf data-string-tabs)
(set-positions! buf 2 'presentation)
(cursor-left buf 1)
(test "cursor left from within tabs"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 1 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-tabs)))

