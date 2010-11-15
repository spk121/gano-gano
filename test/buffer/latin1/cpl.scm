;; coding: iso-8859-1

;; CURSOR PRECEDING LINE

(setlocale LC_ALL "")

(use-modules (gano CBuffer)
	     (oop goops))

(load "testlib.scm")

(init-buf! buf text-ascii)

;; Cursor preceding line moves the cursor to the beginning of the n-th
;; previous line
(set-line-cur! buf 1)
(set-positions! buf 1 'data)
(cursor-preceding-line buf 1)
(test "cursor-preceding-line 1" 
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (= 0 (get-line-cur buf))
	   (string=? (get-text-cur buf) "\tOnce upon")))

(set-line-cur! buf 3)
(set-positions! buf 1 'data)
(cursor-preceding-line buf 2)
(test "cursor-preceding-line 2" 
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (= 1 (get-line-cur buf))
	   (string=? (get-text-cur buf) "a midnight dreary")))

;; Limits test: a cursor-preceding-line to before the beginning-of-buffer should set the data position to the beginning of buffer.
(set-line-cur! buf 1)
(set-positions! buf 1 'data)
(cursor-preceding-line buf 4)
(test "cursor-preceding-line past end-of-buffer" 
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (= 0 (get-line-cur buf))
	   (string=? (get-text-cur buf) "\tOnce upon")))

;; Limits test: a cursor-preceding-line from end-of-buffer
(set-line-cur! buf 4)
(set-positions! buf 0 'data)
(cursor-preceding-line buf 1)
(test "cursor-preceding-line from start of buffer"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (= 3 (get-line-cur buf))
	   (string=? (get-text-cur buf) "weak and weary")))

;; Limits test: a cursor-preceding-line from beginning-of-buffer
(set-line-cur! buf 0)
(set-positions! buf 0 'data)
(cursor-preceding-line buf 1)
(test "cursor forward tabulation from end"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (= 0 (get-line-cur buf))
	   (string=? (get-text-cur buf) "\tOnce upon")))

