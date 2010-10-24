(use-modules (gano utils)
	     (gano global))

(set! tabsizelen 8)

(define (test)
  (let ((t1 (strnlenpt "" 0))
	(t2 (strnlenpt "abcdef" 0))
	(t3 (strnlenpt "abcdef" 6))
	(t4 (strnlenpt "abcdef" 3))
	(t5 (strnlenpt "ab\tcdef" 7))	; tab to col 8 + 4 chars = 12
	(t6 (strnlenpt "\t:\t:\t:" 6))) ; 3 tabs + 1 char = 25
    ;; (format #t "~a ~a ~a ~a ~a ~a~%" t1 t2 t3 t4 t5 t6)
    (and (= 0 t1)
	 (= 0 t2)
	 (= 6 t3)
	 (= 3 t4)
	 (= 12 t5)
	 (= 25 t6))))

(exit (test))