;; coding: utf-8
(define-module (gano syntax)
  #:export (
	    ))

;; Numeric operations and relations
(define × *)				; U+00d7
(define ÷ /)				; U+002b
(define − -)				; U+2212
(define ≤ <=)				; U+2264
(define ≥ >=)				; U+2265

;; Boolean logic
(define ∧ and)				; U+2227
(define ∨ or)				; U+2228
(define ¬ not)


(write (∧ #t #t))
(write (∧ #t #f))
