(use-modules (gano winio)
	     (gano global))

(set! tabsizelen 8)

;; coding: utf-8

(setlocale LC_ALL "")

(set! tabsizelen 8)

(define (test)
  (let* (
	 (s1 (display_string "abcdef" 0 80 #t))
	 (s2 (display_string "abcdef" 0 5 #t))
	 (s3 (display_string "abcdef" 1 80 #t))
	 (s4 (display_string "abcdef" 1 5 #t))
	 (s5 (display_string "hi\tmom" 0 80 #t))
	 (s6 (display_string "hi\tmom" 0 5 #t))
	 (s7 (display_string "hi\tmom" 1 80 #t))
	 (s8 (display_string "hi\tmom" 1 5 #t))
	 (t1 (string=? s1 "abcdef"))
	 (t2 (string=? s2 "abcd")) 		; length 5 - 1 for '$'
	 (t3 (string=? s3 "bcdef"))
	 ;; t4 should be 5 because we don't reserve space for dollar signs
	 ;; at the beginning of lines, apparently.
	 (t4 (string=? s4 "bcdef"))
	 (t5 (string=? s5 "hi      mom"))
	 (t6 (string=? s6 "hi  "))
	 (t7 (string=? s7 "i      mom"))
	 (t8 (string=? s8 "i   "))
	)
    ;; (format #t "1: ~s ~s~%" s1 t1)
    ;; (format #t "1: ~s ~s~%" s2 t2)
    ;; (format #t "1: ~s ~s~%" s3 t3)
    ;; (format #t "1: ~s ~s~%" s4 t4)
    ;; (format #t "1: ~s ~s~%" s5 t5)
    ;; (format #t "1: ~s ~s~%" s6 t6)
    ;; (format #t "1: ~s ~s~%" s7 t7)
    ;; (format #t "1: ~s ~s~%" s8 t8)
    (and t1 t2 t3 t4 t5 t6 t7 t8)))

(exit (test))