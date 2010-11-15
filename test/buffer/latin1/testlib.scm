;; coding: iso-8859-1
(define buf (make <CBuffer>))

(define (init-buf! buf str-list)
  (set-text! buf (if (not (list? str-list))
		     (list str-list)
		     str-list))
  (set-line-frame! buf 0)
  (set-line-cur! buf 0)
  (set-tab-size! buf 8)
  (update-pp-list! buf)
  (set-positions! buf 0 'data))

(define testname "")

(define (pass)
  (format #t "PASS: ~a~%" testname))
(define (fail)
  (format #t "FAIL: ~a~%" testname)
  (flush-all-ports)
  (sleep 1)
  (exit 1))
(define (test str val)
  (set! testname (format #f "~a" str))
  (if val
      (pass)
      (fail)))

(define (print-pos buf)
  (format #t "Pd ~a Pp ~a Pp-Goal ~a~%" (get-pd-cur buf) (get-pp-cur buf) (get-pp-goal buf)))

(define data-string-ascii 	           "abcdefghijklmnopqrstuvwxyz")
(define presentation-string-ascii          "abcdefghijklmnopqrstuvwxyz")
(define presentation-position-ascii        (iota 27))
(define data-string-tabs                   "\ta\tb\tc\td")
(define presentation-string-tabs           "        a       b       c       d")
(define presentation-position-tabs         '(0 8 9 16 17 24 25 32 33))

(define text-ascii
'("\tOnce upon"
"a midnight dreary"
"as I pondered"
"weak and weary"
""))

(define long-text-ascii
'("Preserve me, O God: for in thee do I put my trust."
""
"O my soul, thou has said unto the LORD, Thou art my Lord: my goodness"
"extendeth not to thee;"
""
"But to the saints that are in the earth, and to the excellent, in whom"
"is all my delight."
""
"Their sorrows shall be multiplied that hasten after another god: their"
"drink offerings of blood will I not offer, nor take up their names"
"into my lips."
""
"The LORD is the portion of mine inheritance and of my cup: thou"
"maintainest my lot."
""
"The lines are fallen unto me in pleasant places; yea, I have a goodly"
"heritage."
""
"I will bless the LORD, who hath given me counsel: my reins also"
"instruct me in the night seasons."
""
"I have set the LORD always before me: because he is at my right hand,"
"I shall not be moved."
""
"Therefore my heart is glad, and my glory rejoiceth: my flesh also"
"shall rest in hope."
""
"For thou wilt not leave my soul in hell; neither wilt thou suffer"
"thine Holy One to see corruption."
""
"Thou wilt shew me the path of life: in thy presence is fulness of joy;"
"at thy right hand there are pleasures for evermore."))
