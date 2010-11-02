
;; A poor man's subsitute for r6rs control
(define-module (gano control)
  #:export ( 
	    when
	    unless
	    ))

(define (when a b)
  (if a b))

(define (unless a b)
  (if (not a) b))
