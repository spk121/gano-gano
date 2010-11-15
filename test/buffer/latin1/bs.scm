;; coding: iso-8859-1
(setlocale LC_ALL "")

(use-modules (gano CBuffer)
	     (oop goops))

(load "testlib.scm")

(init-buf! buf data-string-ascii)

;; Latin test: backspace moves the data and presentation positions
;; backwards, leaving the text unchanged.
(set-positions! buf 10 'data)
(backspace buf)
(test "backspace" 
      (and (= 9 (get-pd-cur buf))
	   (= 9 (get-pp-cur buf))
	   (= 9 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a backspace when the data position it at home does nothing.
(set-positions! buf 0 'data)
(backspace buf)
(test "backspace at home"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a backspace from the end of the line
(set-positions! buf 26 'data)
(backspace buf)
(test "backspace at end"
      (and (= 25 (get-pd-cur buf))
	   (= 25 (get-pp-cur buf))
	   (= 25 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Tabs test: backspace takes into account the width of tabs
(init-buf! buf data-string-tabs)
(set-positions! buf 3 'data)
(backspace buf)
(test "backspace tabs"
      (and (= 2 (get-pd-cur buf))
	   (= 9 (get-pp-cur buf))
	   (= 9 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-tabs)))


