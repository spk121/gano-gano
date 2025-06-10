;;; Gano List Utilities Module
;;; Functional list manipulation utilities for immutable operations
;;; Version with strict bounds checking

(define-module (gano list-utils)
  #:use-module (srfi srfi-1)     ; List utilities
  #:export (
    ;; Core list manipulation
    list-update
    list-insert
    list-delete-range
    list-replace-range
    
    ;; Additional utilities that might be useful
    list-move
    list-swap
    list-split-at
    list-insert-multiple
    list-update-multiple
    
    ;; Safe accessors
    list-ref-safe
    list-set-safe
    
    ;; Efficient implementations
    list-replace-multiple
    list-apply-updates))

;;; =================================================================
;;; HELPER FUNCTIONS
;;; =================================================================

(define (check-index lst index function-name)
  "Validate that index is within bounds for the list"
  (let ([len (length lst)])
    (cond
      [(< index 0) 
       (error function-name "Index cannot be negative" index)]
      [(>= index len)
       (error function-name "Index out of bounds" index len)])))

(define (check-insert-index lst index function-name)
  "Validate that index is valid for insertion (can be at end)"
  (let ([len (length lst)])
    (cond
      [(< index 0) 
       (error function-name "Index cannot be negative" index)]
      [(> index len)
       (error function-name "Insert index out of bounds" index len)])))

(define (check-range-indices lst start-index end-index function-name)
  "Validate that range indices are valid"
  (let ([len (length lst)])
    (cond
      [(< start-index 0)
       (error function-name "Start index cannot be negative" start-index)]
      [(< end-index 0)
       (error function-name "End index cannot be negative" end-index)]
      [(> start-index len)
       (error function-name "Start index out of bounds" start-index len)]
      [(> end-index len)
       (error function-name "End index out of bounds" end-index len)]
      [(> start-index end-index)
       (error function-name "Start index must be <= end index" start-index end-index)])))

(define (ranges-overlap? range1 range2)
  "Check if two ranges [start1, end1) and [start2, end2) overlap"
  (let ([start1 (car range1)]
        [end1 (cadr range1)]
        [start2 (car range2)]
        [end2 (cadr range2)])
    ;; Ranges overlap if: start1 < end2 AND start2 < end1
    ;; This handles all overlap cases including partial and complete overlaps
    (and (< start1 end2) (< start2 end1))))

(define (check-no-overlapping-ranges replacements function-name)
  "Validate that no replacement ranges overlap with each other"
  (let loop ([remaining replacements])
    (cond
      [(null? remaining) #t]  ; No overlaps found
      [(null? (cdr remaining)) #t]  ; Only one range left, no overlaps possible
      [else
       (let ([current (car remaining)]
             [rest (cdr remaining)])
         ;; Check if current range overlaps with any of the remaining ranges
         (let ([current-range (list (car current) (cadr current))])
           (for-each (lambda (other)
                       (let ([other-range (list (car other) (cadr other))])
                         (when (ranges-overlap? current-range other-range)
                           (error function-name "Overlapping replacement ranges detected"
                                  current-range other-range))))
                     rest)
           ;; Continue checking the rest
           (loop rest)))])))

;;; =================================================================
;;; CORE LIST MANIPULATION
;;; =================================================================

(define (list-update lst index value)
  "Return new list with element at INDEX replaced by VALUE.
   Throws error if index is out of bounds."
  (check-index lst index 'list-update)
  (let loop ([remaining lst] [i 0] [result '()])
    (cond
      [(null? remaining) (reverse result)]
      [(= i index) (loop (cdr remaining) (+ i 1) (cons value result))]
      [else (loop (cdr remaining) (+ i 1) (cons (car remaining) result))])))

(define (list-insert lst index value)
  "Return new list with VALUE inserted at INDEX.
   INDEX can be from 0 to (length lst) inclusive.
   Throws error if index is out of bounds."
  (check-insert-index lst index 'list-insert)
  (let ([len (length lst)])
    (cond
      [(= index len) (append lst (list value))]  ; Insert at end
      [else
       (let loop ([remaining lst] [i 0] [result '()])
         (cond
           [(= i index) (append (reverse result) (cons value remaining))]
           [(null? remaining) (reverse (cons value result))]
           [else (loop (cdr remaining) (+ i 1) (cons (car remaining) result))]))])))

(define (list-delete-range lst start-index end-index)
  "Return new list with elements from start-index (inclusive) to end-index (exclusive) removed.
   Throws error if indices are out of bounds or invalid."
  (check-range-indices lst start-index end-index 'list-delete-range)
  (append (take lst start-index)
          (drop lst end-index)))

(define (list-replace-range lst start-index end-index new-items)
  "Return new list with range [start-index, end-index) replaced by new-items.
   Throws error if indices are out of bounds or invalid."
  (check-range-indices lst start-index end-index 'list-replace-range)
  (append (take lst start-index)
          new-items
          (drop lst end-index)))

;;; =================================================================
;;; ADDITIONAL UTILITIES
;;; =================================================================

(define (list-move lst from-index to-index)
  "Return new list with element moved from from-index to to-index.
   from-index must refer to an existing element (0 to length-1).
   to-index can be 0 to length (inclusive) where length means 'after the last element'.
   When to-index equals an existing position, the element is inserted BEFORE that position.
   Throws error if indices are out of bounds."
  (check-index lst from-index 'list-move)
  (check-insert-index lst to-index 'list-move)
  (if (= from-index to-index)
      lst
      (let ([element (list-ref lst from-index)])
        (cond
          ;; Moving to a position before the current position
          [(< to-index from-index)
           (append (take lst to-index)
                   (list element)
                   (take (drop lst to-index) (- from-index to-index))
                   (drop lst (+ from-index 1)))]
          ;; Moving to the end
          [(= to-index (length lst))
           (append (take lst from-index) (drop lst (1+ from-index)) (list element))]
          ;; Moving to a position after the current position
          [else ; (> to-index from-index)
           (let ([lst-after-removal (append (take lst from-index)
					    (drop lst (1+ from-index)))])
             (append (take lst-after-removal to-index)
                     (list element)
                     (drop lst-after-removal to-index)))]))))

(define (list-swap lst index1 index2)
  "Return new list with elements at index1 and index2 swapped.
   Throws error if indices are out of bounds."
  (check-index lst index1 'list-swap)
  (check-index lst index2 'list-swap)
  (if (= index1 index2)
      lst
      (let ([val1 (list-ref lst index1)]
            [val2 (list-ref lst index2)])
        (list-update (list-update lst index1 val2) index2 val1))))

(define (list-split-at lst index)
  "Return two values: (before-list after-list) split at index.
   INDEX can be from 0 to (length lst) inclusive.
   Throws error if index is out of bounds."
  (check-insert-index lst index 'list-split-at)
  (values (take lst index)
          (drop lst index)))

(define (list-insert-multiple lst index items)
  "Return new list with multiple items inserted at index.
   Throws error if index is out of bounds."
  (cond
    [(null? items) lst]
    [else
     (check-insert-index lst index 'list-insert-multiple)
     (append (take lst index)
             items
             (drop lst index))]))

(define (list-update-multiple lst updates)
  "Return new list with multiple updates applied.
   UPDATES is a list of (index . value) pairs.
   Applied in order, so later updates can reference earlier ones.
   Throws error if any index is out of bounds."
  (fold (lambda (update acc)
          (list-update acc (car update) (cdr update)))
        lst
        updates))

;;; =================================================================
;;; SAFE ACCESSORS
;;; =================================================================

(define (list-ref-safe lst index default-value)
  "Safe list-ref that returns default-value if index is out of bounds"
  (let ([len (length lst)])
    (cond
      [(< index 0) default-value]
      [(>= index len) default-value]
      [else (list-ref lst index)])))

(define (list-set-safe lst index value default-value)
  "Safe list update that extends list with default-value if needed"
  (let ([len (length lst)])
    (cond
      [(< index 0) lst]
      [(>= index len)
       ;; Extend list with default values
       (let ([extensions (make-list (- index len) default-value)])
         (append lst extensions (list value)))]
      [else (list-update lst index value)])))

;;; =================================================================
;;; EFFICIENT IMPLEMENTATIONS FOR COMMON PATTERNS
;;; =================================================================

(define (list-replace-multiple lst replacements)
  "Return new list with multiple ranges replaced.
   REPLACEMENTS is a list of (start-index end-index new-items) tuples.
   Applied from right to left to avoid index shifting issues.
   Throws error if any indices are out of bounds or if ranges overlap."
  ;; First validate all replacement ranges and check for overlaps
  (for-each (lambda (replacement)
              (let ([start (car replacement)]
                    [end (cadr replacement)])
                (check-range-indices lst start end 'list-replace-multiple)))
            replacements)
  
  ;; Check for overlapping ranges
  (check-no-overlapping-ranges replacements 'list-replace-multiple)
  
  ;; Apply replacements from right to left to avoid index shifting
  (fold (lambda (replacement acc)
          (let ([start (car replacement)]
                [end (cadr replacement)]
                [items (caddr replacement)])
            (list-replace-range acc start end items)))
        lst
        ;; Sort replacements by start index in descending order using stable sort
        (stable-sort replacements (lambda (a b) (> (car a) (car b))))))

(define (operation-to-range op)
  "Convert an operation to a range [start, end) for overlap checking"
  (case (car op)
    [(update) (list (cadr op) (+ (cadr op) 1))]  ; update affects one position
    [(insert) (list (cadr op) (cadr op))]        ; insert affects zero positions (point operation)
    [(delete) (list (cadr op) (caddr op))]       ; delete affects [start, end)
    [(replace) (list (cadr op) (caddr op))]      ; replace affects [start, end)
    [else (error "Unknown operation" op)]))

(define (check-no-overlapping-operations operations function-name)
  "Validate that no operations overlap with each other"
  (let ([ranges (map operation-to-range operations)])
    (let loop ([remaining-ranges ranges]
               [remaining-ops operations])
      (cond
        [(null? remaining-ranges) #t]  ; No overlaps found
        [(null? (cdr remaining-ranges)) #t]  ; Only one range left
        [else
         (let ([current-range (car remaining-ranges)]
               [current-op (car remaining-ops)]
               [rest-ranges (cdr remaining-ranges)]
               [rest-ops (cdr remaining-ops)])
           ;; Check if current range overlaps with any of the remaining ranges
           (for-each (lambda (other-range other-op)
                       (when (ranges-overlap? current-range other-range)
                         (error function-name "Overlapping operations detected"
                                current-op other-op)))
                     rest-ranges rest-ops)
           ;; Continue checking the rest
           (loop rest-ranges rest-ops))]))))

(define (list-apply-updates lst operations)
  "Apply a sequence of operations to a list.
   OPERATIONS is a list where each element is one of:
   - (update index value)
   - (insert index value)  
   - (delete start end)
   - (replace start end items)
   
   Operations must not overlap with each other.
   Operations are applied from right to left to avoid index shifting.
   Throws error if any indices are out of bounds or if operations overlap."
  ;; First validate all operation indices
  (for-each (lambda (op)
              (case (car op)
                [(update) (check-index lst (cadr op) 'list-apply-updates)]
                [(insert) (check-insert-index lst (cadr op) 'list-apply-updates)]
                [(delete) (check-range-indices lst (cadr op) (caddr op) 'list-apply-updates)]
                [(replace) (check-range-indices lst (cadr op) (caddr op) 'list-apply-updates)]
                [else (error "Unknown operation" op)]))
            operations)
  
  ;; Check for overlapping operations
  (check-no-overlapping-operations operations 'list-apply-updates)
  
  ;; Apply operations from right to left to avoid index shifting
  (fold (lambda (op acc)
          (case (car op)
            [(update) (list-update acc (cadr op) (caddr op))]
            [(insert) (list-insert acc (cadr op) (caddr op))]
            [(delete) (list-delete-range acc (cadr op) (caddr op))]
            [(replace) (list-replace-range acc (cadr op) (caddr op) (cadddr op))]
            [else (error "Unknown operation" op)]))
        lst
        ;; Sort operations by position (right to left) using stable sort
        ;; to preserve original order for operations at the same position
        (stable-sort operations (lambda (a b) 
                                 (let ([pos-a (cadr a)]
                                       [pos-b (cadr b)])
                                   (> pos-a pos-b))))))
                              