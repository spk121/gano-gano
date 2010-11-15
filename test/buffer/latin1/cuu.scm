;; coding: iso-8859-1

;; CURSOR UP

(setlocale LC_ALL "")

(use-modules (gano CBuffer)
	     (oop goops))

(load "testlib.scm")

(init-buf! buf text-ascii)

;; Cursor up moves the presentation position up n lines
(set-line-cur! buf 3)
(set-positions! buf 1 'data)
(cursor-up buf 1)
(test "cursor-up 1" 
      (and (= 1 (get-pd-cur buf))
	   (= 1 (get-pp-cur buf))
	   (= 1 (get-pp-goal buf))
	   (= 2 (get-line-cur buf))
	   (string=? (get-text-cur buf) "as I pondered")))

(set-line-cur! buf 3)
(set-positions! buf 1 'data)
(cursor-up buf 2)
(test "cursor-up 2" 
      (and (= 1 (get-pd-cur buf))
	   (= 1 (get-pp-cur buf))
	   (= 1 (get-pp-goal buf))
	   (= 1 (get-line-cur buf))
	   (string=? (get-text-cur buf) "a midnight dreary")))

;; Limits test: a cursor-up to before the beginning-of-buffer
(set-line-cur! buf 1)
(set-positions! buf 1 'data)
(cursor-up buf 4)
(test "cursor-up before beginning-of-buffer" 
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 1 (get-pp-goal buf))
	   (= 0 (get-line-cur buf))
	   (string=? (get-text-cur buf) "\tOnce upon")))

;; Limits test: a cursor-up from end-of-buffer
(set-line-cur! buf 4)
(set-positions! buf 0 'data)
(cursor-up buf 1)
(test "cursor-up from start of buffer"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (= 3 (get-line-cur buf))
	   (string=? (get-text-cur buf) "weak and weary")))

;; Limits test: a cursor-up from beginning-of-buffer
(set-line-cur! buf 0)
(set-positions! buf 0 'data)
(cursor-up buf 1)
(test "cursor up from end"
      (and (= 0 (get-pd-cur buf))
	   (= 0 (get-pp-cur buf))
	   (= 0 (get-pp-goal buf))
	   (= 0 (get-line-cur buf))
	   (string=? (get-text-cur buf) "\tOnce upon")))

