;; coding: iso-8859-1

;; CURSOR NEXT LINE

(setlocale LC_ALL "")

(use-modules (gano CBuffer)
	     (oop goops))

(load "testlib.scm")

(init-buf! buf text-ascii)

;; Cursor next line moves the cursor to the beginning of the n-th
;; following line
(set-line-cur! buf 1)
(set-positions! buf 1 'data)
(cursor-next-line buf 1)
(test "cursor-next-line 1" 
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (= 2 (get-line-cur buf))
	   (string=? (get-text-cur buf) "as I pondered")))

(set-line-cur! buf 1)
(set-positions! buf 1 'data)
(cursor-next-line buf 2)
(test "cursor-next-line 2" 
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (= 3 (get-line-cur buf))
	   (string=? (get-text-cur buf) "weak and weary")))

;; Limits test: a cursor-next-line to after the end-of-buffer
;; set the data position to the end-of-buffer.  Normally, this
;; should be the magic line
(set-line-cur! buf 1)
(set-positions! buf 1 'data)
(cursor-next-line buf 4)
(test "cursor-next-line past end-of-buffer" 
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (= 4 (get-line-cur buf))
	   (string=? (get-text-cur buf) "")))

;; Limits test: a cursor-next-line from start-of-buffer
(set-line-cur! buf 0)
(set-positions! buf 0 'data)
(cursor-next-line buf 1)
(test "cursor-next-line from start of buffer"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (= 1 (get-line-cur buf))
	   (string=? (get-text-cur buf) "a midnight dreary")))

;; Limits test: a cursor-next-line from end-of-buffer
(set-line-cur! buf 4)
(set-positions! buf 0 'data)
(cursor-next-line buf 1)
(test "cursor forward tabulation from end"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (= 4 (get-line-cur buf))
	   (string=? (get-text-cur buf) "")))

