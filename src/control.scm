
;; A poor man's subsitute for r6rs control
(define-module (gano control)
  #:use-syntax (ice-9 syncase)
  #:export ( 
	    when
	    unless
	    ))

(define-syntax when
    (syntax-rules ()
      ((when test result1 result2 ...)
       (if test
           (begin result1 result2 ...)))))
  
  (define-syntax unless
    (syntax-rules ()
      ((unless test result1 result2 ...)
       (if (not test)
           (begin result1 result2 ...)))))
  
