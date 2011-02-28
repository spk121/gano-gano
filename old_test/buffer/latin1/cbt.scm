;; coding: iso-8859-1

;; CURSOR BACKWARD TABULATION

(setlocale LC_ALL "")

(use-modules (gano CBuffer)
	     (oop goops))

(load "testlib.scm")

(init-buf! buf data-string-ascii)

;; Cursor backward tabulation moves the cursor to the nth previous tab
;; column
(set-positions! buf 25 'data)
(cursor-backward-tabulation buf 1)
(test "cursor-backward-tabulation 1" 
      (and (= 24 (get-pd-cur buf))
	   (= 24 (get-pp-cur buf))
	   (= 24 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

(set-positions! buf 25 'data)
(cursor-backward-tabulation buf 2)
(test "cursor-backward-tabulation 2" 
      (and (= 16 (get-pd-cur buf))
	   (= 16 (get-pp-cur buf))
	   (= 16 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

(set-positions! buf 24 'data)
(cursor-backward-tabulation buf 1)
(test "cursor-backward-tabulation from a tab column" 
      (and (= 16 (get-pd-cur buf))
	   (= 16 (get-pp-cur buf))
	   (= 16 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a cursor backward tabulation to before the home position
;; set the position at home
(set-positions! buf 25 'data)
(cursor-backward-tabulation buf 4)
(test "cursor-backward-tabulation past home" 
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a cursor backward tabulation from home
(set-positions! buf 0 'data)
(cursor-backward-tabulation buf 1)
(test "cursor backward tabulation from home"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a cursor backward tabulation from end
(set-positions! buf 26 'data)
(cursor-backward-tabulation buf 1)
(test "cursor backward tabulation from end"
      (and (= 24 (get-pd-cur buf))
	   (= 24 (get-pp-cur buf))
	   (= 24 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Tabs test: cursor backward tabulation over tabs
(init-buf! buf data-string-tabs)
(set-positions! buf 3 'data)
(cursor-backward-tabulation buf 1)
(test "cursor backward tabulation over tabs"
      (and (= 1 (get-pd-cur buf))
	   (= 8 (get-pp-cur buf))
	   (= 8 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-tabs)))

;; Tabs test: cursor backward tabulation starting in the middle of a tab
(init-buf! buf data-string-tabs)
(set-positions! buf 12 'presentation)
(cursor-backward-tabulation buf 1)
(test "cursor backward tabulation from within tabs"
      (and (= 1 (get-pd-cur buf))
	   (= 8 (get-pp-cur buf))
	   (= 8 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-tabs)))

