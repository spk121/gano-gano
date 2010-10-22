;; coding: utf-8

(setlocale LC_ALL "")

;;
(define (∘ f g) (lambda (x) (f (g x))))

;; Numeric operations
(define × *)				; U+00d7
(define ÷ /)				; U+002b
(define − -)				; U+2212
(define ∞ +inf.0)
;;(define ⌊ floor)
;;(define ⌈ ceil)
(define (∑ lo hi func) (let loop ([i lo] [total 0])
			 (if (≤ i hi)
			     (loop (1+ i) (+ total (func i)))
			     total)))

(define (∏ lo hi func) (let loop ([i lo] [total 1])
			 (if (≤ i hi)
			     (loop (1+ i) (* total (func i)))
			     total)))

;; Numeric relations
(define ≤ <=)				; U+2264
(define ≥ >=)				; U+2265

;; Boolean logic
;; and
(define (∧ a b) (if (and a b) #t #f))	; U+2227
;; or
(define (∨ a b) (if (or a b) #t #f))	; U+2228
;; not
(define (¬ a) (if a #f #t))		; U+00ac
;; xor
(define (⊻ a b) (or (and a (not b)) (and (not a) b))) ; U+22bb
;; nand
(define (⊼ a b) (not (and a b)))		; U+22bc

;; Lists
(define ∅ (list))
(define (∅? a) (null? a))
(define (∈ x y) (if (member x y) #t #f))

(define (→ func x) (map func x))
