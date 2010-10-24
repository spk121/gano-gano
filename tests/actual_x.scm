(use-modules (gano utils)
	     (gano global))

(set! tabsizelen 8)


(define (test)
  (let ((t1 (actual_x "" 0))
	(t2 (actual_x "abcdef" 0))
	(t3 (actual_x "abcdef" 6))
	(t4 (actual_x "abcdef" 3))
	(t5 (actual_x "ab\tcdef" 7))	; 7 is in 1st tab
	(t6 (actual_x "\t:\t:\t:" 11))) ; 11 is in 2nd tab
    (format #t "~a ~a ~a ~a ~a ~a~%" t1 t2 t3 t4 t5 t6)
    (and (= 0 t1)
	 (= 0 t2)
	 (= 6 t3)
	 (= 3 t4)
	 (= 2 t5)
	 (= 2 t6))))

(exit (test))