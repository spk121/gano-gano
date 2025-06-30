(define-module (test-binary-search)
  #:use-module (gano binary-search)
  #:use-module (srfi srfi-64))    ; testing framework

;; Test suite for binary search implementation
(test-begin "binary-search")

;; Helper function to test both parts of the returned cons pair
(define (test-search-result actual expected-index expected-value test-name)
  (test-equal (string-append test-name " - index") expected-index (car actual))
  (test-equal (string-append test-name " - value") expected-value (cdr actual)))

;;; FLOOR MODE TESTS (≤ target)

;; Test empty list - floor mode
(test-search-result 
  (binary-search-floor '() 5)
  -1 #f
  "empty list floor")

;; Test single element - exact match
(test-search-result
  (binary-search-floor '(5) 5)
  0 5
  "single element exact match floor")

;; Test single element - target larger
(test-search-result
  (binary-search-floor '(3) 5)
  0 3
  "single element target larger floor")

;; Test single element - target smaller
(test-search-result
  (binary-search-floor '(7) 5)
  -1 #f
  "single element target smaller floor")

;; Test multiple elements - exact matches
(test-search-result
  (binary-search-floor '(1 3 5 7 9) 5)
  2 5
  "multiple elements exact match floor")

(test-search-result
  (binary-search-floor '(1 3 5 7 9) 1)
  0 1
  "multiple elements first element floor")

(test-search-result
  (binary-search-floor '(1 3 5 7 9) 9)
  4 9
  "multiple elements last element floor")

;; Test multiple elements - no exact match, find floor
(test-search-result
  (binary-search-floor '(1 3 5 7 9) 4)
  1 3
  "multiple elements floor between elements")

(test-search-result
  (binary-search-floor '(1 3 5 7 9) 6)
  2 5
  "multiple elements floor between elements 2")

(test-search-result
  (binary-search-floor '(1 3 5 7 9) 8)
  3 7
  "multiple elements floor between elements 3")

;; Test target smaller than all elements
(test-search-result
  (binary-search-floor '(3 5 7 9) 1)
  -1 #f
  "target smaller than all elements floor")

;; Test target larger than all elements
(test-search-result
  (binary-search-floor '(1 3 5 7) 10)
  3 7
  "target larger than all elements floor")

;;; CEILING MODE TESTS (≥ target)

;; Test empty list - ceiling mode
(test-search-result
  (binary-search-ceiling '() 5)
  0 #f
  "empty list ceiling")

;; Test single element - exact match
(test-search-result
  (binary-search-ceiling '(5) 5)
  0 5
  "single element exact match ceiling")

;; Test single element - target smaller
(test-search-result
  (binary-search-ceiling '(7) 5)
  0 7
  "single element target smaller ceiling")

;; Test single element - target larger
(test-search-result
  (binary-search-ceiling '(3) 5)
  1 #f
  "single element target larger ceiling")

;; Test multiple elements - exact matches
(test-search-result
  (binary-search-ceiling '(1 3 5 7 9) 5)
  2 5
  "multiple elements exact match ceiling")

(test-search-result
  (binary-search-ceiling '(1 3 5 7 9) 1)
  0 1
  "multiple elements first element ceiling")

(test-search-result
  (binary-search-ceiling '(1 3 5 7 9) 9)
  4 9
  "multiple elements last element ceiling")

;; Test multiple elements - no exact match, find ceiling
(test-search-result
  (binary-search-ceiling '(1 3 5 7 9) 4)
  2 5
  "multiple elements ceiling between elements")

(test-search-result
  (binary-search-ceiling '(1 3 5 7 9) 6)
  3 7
  "multiple elements ceiling between elements 2")

(test-search-result
  (binary-search-ceiling '(1 3 5 7 9) 2)
  1 3
  "multiple elements ceiling between elements 3")

;; Test target smaller than all elements
(test-search-result
  (binary-search-ceiling '(3 5 7 9) 1)
  0 3
  "target smaller than all elements ceiling")

;; Test target larger than all elements
(test-search-result
  (binary-search-ceiling '(1 3 5 7) 10)
  4 #f
  "target larger than all elements ceiling")

;;; EDGE CASES AND STRESS TESTS

;; Test with duplicates - implementation dependent which index is returned
(let ((result-floor (binary-search-floor '(1 3 3 3 5 7) 3)))
  (test-assert "duplicates floor mode - valid index"
    (and (>= (car result-floor) 1) (<= (car result-floor) 3)))
  (test-equal "duplicates floor mode - correct value" 3 (cdr result-floor)))

(let ((result-ceiling (binary-search-ceiling '(1 3 3 3 5 7) 3)))
  (test-assert "duplicates ceiling mode - valid index"
    (and (>= (car result-ceiling) 1) (<= (car result-ceiling) 3)))
  (test-equal "duplicates ceiling mode - correct value" 3 (cdr result-ceiling)))

;; Test with negative numbers
(test-search-result
  (binary-search-floor '(-5 -3 -1 1 3) -2)
  1 -3
  "negative numbers floor")

(test-search-result
  (binary-search-ceiling '(-5 -3 -1 1 3) -2)
  2 -1
  "negative numbers ceiling")

;; Test with zero
(test-search-result
  (binary-search-floor '(-2 0 2 4) 0)
  1 0
  "zero exact match floor")

(test-search-result
  (binary-search-ceiling '(-2 0 2 4) 0)
  1 0
  "zero exact match ceiling")

;; Test larger list
(define large-list '(1 5 10 15 20 25 30 35 40 45 50))

(test-search-result
  (binary-search-floor large-list 22)
  4 20
  "large list floor")

(test-search-result
  (binary-search-ceiling large-list 22)
  5 25
  "large list ceiling")

;; Test the main binary-search function with explicit modes
(test-search-result
  (binary-search '(1 3 5 7 9) 4 'floor)
  1 3
  "explicit floor mode")

(test-search-result
  (binary-search '(1 3 5 7 9) 4 'ceiling)
  2 5
  "explicit ceiling mode")

;; Test invalid mode throws out-of-range error
(test-assert "invalid mode throws error"
  (catch 'out-of-range
    (lambda ()
      (binary-search '(1 3 5 7 9) 4 'invalid-mode)
      #f)  ; If we reach here, no error was thrown
    (lambda (key . args)
      #t)))  ; Error was thrown as expected

(test-assert "leq mode throws error"
  (catch 'out-of-range
    (lambda ()
      (binary-search '(1 3 5 7 9) 4 'leq)
      #f)
    (lambda (key . args)
      #t)))

(test-assert "geq mode throws error"
  (catch 'out-of-range
    (lambda ()
      (binary-search '(1 3 5 7 9) 4 'geq)
      #f)
    (lambda (key . args)
      #t)))

;;; PROPERTY-BASED TESTS

;; Test that floor result is always ≤ target (when not -1)
(define (test-floor-property lst target)
  (let ((result (binary-search-floor lst target)))
    (when (>= (car result) 0)
      (test-assert
        (format #f "floor property: ~a ≤ ~a" (cdr result) target)
        (<= (cdr result) target)))))

;; Test that ceiling result is always ≥ target (when not beyond list)
(define (test-ceiling-property lst target)
  (let ((result (binary-search-ceiling lst target)))
    (when (< (car result) (length lst))
      (test-assert
        (format #f "ceiling property: ~a ≥ ~a" (cdr result) target)
        (>= (cdr result) target)))))

;; Apply property tests
(test-floor-property '(1 3 5 7 9) 4)
(test-floor-property '(1 3 5 7 9) 6)
(test-ceiling-property '(1 3 5 7 9) 4)
(test-ceiling-property '(1 3 5 7 9) 6)

(test-end "binary-search")

;; Local Variables:
;; eval: (put 'test-group 'scheme-indent-function 1)
;; eval: (put 'test-assert 'scheme-indent-function 1)
;; eval: (put 'test-equal 'scheme-indent-function 1)
;; eval: (put 'test-error 'scheme-indent-function 1)
;; eval: (put 'let-values 'scheme-indent-function 1)
;; End:
