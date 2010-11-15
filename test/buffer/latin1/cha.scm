;; coding: iso-8859-1
(setlocale LC_ALL "")

(use-modules (gano CBuffer)
	     (oop goops))

(load "testlib.scm")

(init-buf! buf data-string-ascii)

;; Latin test: cursor-character-absolute moves the cursor
;; to the given presentation positions
(set-positions! buf 0 'data)
(cursor-character-absolute buf 10)
(test "cursor-character-absolute" 
      (and (= 10 (get-pd-cur buf))
	   (= 10 (get-pp-cur buf))
	   (= 10 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a cursor-character-absolute should work for the home
;; position
(set-positions! buf 10 'data)
(cursor-character-absolute buf 0)
(test "cursor-character-absolute to home"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Limits test: a cursor-character-absolute should work for the end
;; position
(set-positions! buf 10 'data)
(cursor-character-absolute buf 26)
(test "cursor-character-absolute to end"
      (and (= 26 (get-pd-cur buf))
	   (= 26 (get-pp-cur buf))
	   (= 26 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-ascii)))

;; Tabs test: cursor-character-absolute to the beginning of a tab
(init-buf! buf data-string-tabs)
(set-positions! buf 0 'data)
(cursor-character-absolute buf 9)
(test "cursor-character-absolute to beginning of tab"
      (and (= 2 (get-pd-cur buf))
	   (= 9 (get-pp-cur buf))
	   (= 9 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-tabs)))

(set-positions! buf 0 'data)
(cursor-character-absolute buf 10)
(test "cursor-character-absolute to middle of tab"
      (and (= 2 (get-pd-cur buf))
	   (= 9 (get-pp-cur buf))
	   (= 10 (get-pp-goal buf))
	   (string=? (get-text-cur buf) data-string-tabs)))

