;; coding: iso-8859-1

;; CURSOR DOWN

(setlocale LC_ALL "")

(use-modules (gano CBuffer)
	     (oop goops))

(load "testlib.scm")

(init-buf! buf text-ascii)

;; Cursor down moves the presentation position down n lines
(set-line-cur! buf 1)
(set-positions! buf 1 'data)
(cursor-down buf 1)
(test "cursor-down 1" 
      (and (= 1 (get-pd-cur buf))
	   (= 1 (get-pp-cur buf))
	   (= 1 (get-pp-goal buf))
	   (= 2 (get-line-cur buf))
	   (string=? (get-text-cur buf) "as I pondered")))

(set-line-cur! buf 1)
(set-positions! buf 1 'data)
(cursor-down buf 2)
(test "cursor-down 2" 
      (and (= 1 (get-pd-cur buf))
	   (= 1 (get-pp-cur buf))
	   (= 1 (get-pp-goal buf))
	   (= 3 (get-line-cur buf))
	   (string=? (get-text-cur buf) "weak and weary")))

;; Limits test: a cursor-down to after the end-of-buffer
(set-line-cur! buf 1)
(set-positions! buf 1 'data)
(cursor-down buf 4)
(test "cursor-down past end-of-buffer" 
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 1 (get-pp-goal buf))
	   (= 4 (get-line-cur buf))
	   (string=? (get-text-cur buf) "")))

;; Limits test: a cursor-down from start-of-buffer
(set-line-cur! buf 0)
(set-positions! buf 0 'data)
(cursor-down buf 1)
(test "cursor-down from start of buffer"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (= 1 (get-line-cur buf))
	   (string=? (get-text-cur buf) "a midnight dreary")))

;; Limits test: a cursor-down from end-of-buffer
(set-line-cur! buf 4)
(set-positions! buf 0 'data)
(cursor-down buf 1)
(test "cursor down from end"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (= 4 (get-line-cur buf))
	   (string=? (get-text-cur buf) "")))

