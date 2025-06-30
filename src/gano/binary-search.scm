(define-module (gano binary-search)
  #:use-module (srfi srfi-1)        ; list utilities
  #:export (
	    ;; Binary search utilities
	    binary-search
	    binary-search-floor
	    binary-search-ceiling))

(define (binary-search lst value mode)
  "Binary search for VALUE in sorted list LST with specified MODE.
   Returns (index . closest-value) where behavior depends on MODE:

   MODE 'floor:
   - index: position of exact match, or closest entry ≤ value, or -1
   - closest-value: the actual value at that position, or #f if index is -1
   - If first entry > value, returns (-1 . #f)

   MODE 'ceiling:
   - index: position of exact match, or closest entry ≥ value, or (length lst)
   - closest-value: the actual value at that position, or #f if index is (length lst)

   MODE must be either 'floor or 'ceiling, otherwise an out-of-range error is thrown."

  ;; Validate mode parameter
  (unless (or (eq? mode 'floor) (eq? mode 'ceiling))
    (scm-error 'out-of-range "binary-search"
               "Invalid mode, must be 'floor or 'ceiling: ~S" (list mode) (list mode)))

  (let ([len (length lst)])
    (cond
     ;; Empty list
     [(null? lst)
      (cons (if (eq? mode 'ceiling) 0 -1) #f)]

     ;; Single element
     [(= len 1)
      (let ([single-val (car lst)])
        (cond
         [(= single-val value) (cons 0 single-val)]
         [(eq? mode 'floor)
          (if (<= single-val value) (cons 0 single-val) (cons -1 #f))]
         [else ; ceiling mode
          (if (>= single-val value) (cons 0 single-val) (cons 1 #f))]))]

     ;; Handle edge cases based on mode
     [(eq? mode 'floor)
      (cond
       [(> (car lst) value) (cons -1 #f)]
       [(<= (last lst) value) (cons (- len 1) (last lst))]
       [else (binary-search-core lst value mode len)])]

     [else ; ceiling mode
      (cond
       [(< (last lst) value) (cons len #f)]
       [(>= (car lst) value) (cons 0 (car lst))]
       [else (binary-search-core lst value mode len)])])))

(define (binary-search-core lst value mode len)
  "Core binary search implementation."
  (let loop ([low 0]
             [high (- len 1)]
             [best-idx (if (eq? mode 'floor) -1 len)]
             [best-val #f])

    (if (> low high)
        ;; Search complete - return best match found
        (cons best-idx best-val)

        ;; Continue searching
        (let* ([mid (quotient (+ low high) 2)]
               [mid-val (list-ref lst mid)])

          (cond
           ;; Exact match found
           [(= mid-val value)
            (cons mid mid-val)]

           ;; Mid value is less than target
           [(< mid-val value)
            (if (eq? mode 'floor)
                ;; Floor: this is a candidate, search right
                (loop (+ mid 1) high mid mid-val)
                ;; Ceiling: search right for something ≥ target
                (loop (+ mid 1) high best-idx best-val))]

           ;; Mid value is greater than target
           [else
            (if (eq? mode 'floor)
                ;; Floor: search left for something ≤ target
                (loop low (- mid 1) best-idx best-val)
                ;; Ceiling: this is a candidate, search left
                (loop low (- mid 1) mid mid-val))])))))

;; Convenience functions with descriptive names
(define (binary-search-floor lst value)
  "Find largest value ≤ target, or -1 if none exists."
  (binary-search lst value 'floor))

(define (binary-search-ceiling lst value)
  "Find smallest value ≥ target, or (length lst) if none exists."
  (binary-search lst value 'ceiling))
