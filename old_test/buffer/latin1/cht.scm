;; coding: iso-8859-1

;; CURSOR FORWARD TABULATION

(setlocale LC_ALL "")

(use-modules (gano CBuffer)
	     (oop goops))

(load "testlib.scm")

(init-buf! buf data-string-ascii)

;; Cursor forward tabulation moves the cursor the to nth following tab
;; column
(set-positions! buf 1 'data)
(cursor-forward-tabulation buf 1)
(test "cursor-forward-tabulation 1" 
      (and (= 8 (get-pd-cur buf))
	   (= 8 (get-pp-cur buf))
	   (= 8 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

(set-positions! buf 1 'data)
(cursor-forward-tabulation buf 2)
(test "cursor-forward-tabulation 2" 
      (and (= 16 (get-pd-cur buf))
	   (= 16 (get-pp-cur buf))
	   (= 16 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

(set-positions! buf 8 'data)
(cursor-forward-tabulation buf 1)
(test "cursor-forward-tabulation from a tab column" 
      (and (= 16 (get-pd-cur buf))
	   (= 16 (get-pp-cur buf))
	   (= 16 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a cursor forward tabulation to after the end position
;; set the data position to the last data position.
(set-positions! buf 1 'data)
(cursor-forward-tabulation buf 4)
(test "cursor-forward-tabulation past home" 
      (and (= 26 (get-pd-cur buf))
	   (= 26 (get-pp-cur buf))
	   (= 32 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a cursor forward tabulation from home
(set-positions! buf 0 'data)
(cursor-forward-tabulation buf 1)
(test "cursor forward tabulation from home"
      (and (= 8 (get-pd-cur buf))
	   (= 8 (get-pp-cur buf))
	   (= 8 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a cursor forward tabulation from end
(set-positions! buf 26 'data)
(cursor-forward-tabulation buf 1)
(test "cursor forward tabulation from end"
      (and (= 26 (get-pd-cur buf))
	   (= 26 (get-pp-cur buf))
	   (= 32 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Tabs test: cursor forward tabulation over tabs
(init-buf! buf data-string-tabs)
(set-positions! buf 0 'data)
(cursor-forward-tabulation buf 1)
(test "cursor forward tabulation over tabs"
      (and (= 1 (get-pd-cur buf))
	   (= 8 (get-pp-cur buf))
	   (= 8 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-tabs)))

;; Tabs test: cursor forward tabulation starting in the middle of a tab
(init-buf! buf data-string-tabs)
(set-positions! buf 2 'presentation)
(cursor-forward-tabulation buf 1)
(test "cursor forward tabulation from within tabs"
      (and (= 1 (get-pd-cur buf))
	   (= 8 (get-pp-cur buf))
	   (= 8 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-tabs)))

