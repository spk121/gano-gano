(define (f1 x)
  x)

;;; comment
(define (f2 x)
  (+ x (f1 x)))

;;; comment
;;; comment
(define (f3 x)
  (+ x (f2 x)))

;;; comment
;;; comment
;;; comment
(define (f4 x)
  (+ x (f1 x) (f2 x) (f3 x)))