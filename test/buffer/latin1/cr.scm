;; coding: iso-8859-1
(setlocale LC_ALL "")

(use-modules (gano CBuffer)
	     (oop goops))

(load "testlib.scm")

(init-buf! buf data-string-ascii)

;; Latin test: carriage-return moves the data and presentation positions
;; to the beginning of the line, leaving the text unchanged.
(set-positions! buf 10 'data)
(carriage-return buf)
(test "carriage-return" 
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a carriage-return when the data position it at home
;; does nothing.
(set-positions! buf 0 'data)
(carriage-return buf)
(test "carriage return at home"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a carriage return from the end of the line
(set-positions! buf 26 'data)
(carriage-return buf)
(test "carriage return at end"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Tabs test: carriage return is not affected by tabs
(init-buf! buf data-string-tabs)
(set-positions! buf 3 'data)
(carriage-return buf)
(test "carriage return over tabs"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-tabs)))

