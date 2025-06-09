;;; Gano List Utilities Module
;;; Functional list manipulation utilities for immutable operations

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
;;; CORE LIST MANIPULATION
;;; =================================================================

(define (list-update lst index value)
  "Return new list with element at INDEX replaced by VALUE.
   If index is out of bounds, returns original list unchanged."
  (cond
    [(< index 0) lst]
    [(>= index (length lst)) lst]
    [else
     (let loop ([remaining lst] [i 0] [result '()])
       (cond
         [(null? remaining) (reverse result)]
         [(= i index) (loop (cdr remaining) (+ i 1) (cons value result))]
         [else (loop (cdr remaining) (+ i 1) (cons (car remaining) result))]))]))

(define (list-insert lst index value)
  "Return new list with VALUE inserted at INDEX.
   If index >= length, appends to end. If index < 0, prepends to start."
  (cond
    [(< index 0) (cons value lst)]
    [(>= index (length lst)) (append lst (list value))]
    [else
     (let loop ([remaining lst] [i 0] [result '()])
       (cond
         [(= i index) (append (reverse result) (cons value remaining))]
         [(null? remaining) (reverse (cons value result))]
         [else (loop (cdr remaining) (+ i 1) (cons (car remaining) result))]))]))

(define (list-delete-range lst start-index end-index)
  "Return new list with elements from start-index (inclusive) to end-index (exclusive) removed.
   Handles bounds checking gracefully."
  (let ([len (length lst)]
        [actual-start (max 0 start-index)]
        [actual-end (max 0 end-index)])
    (cond
      [(>= actual-start len) lst]  ; Start beyond list
      [(>= actual-start actual-end) lst]  ; Invalid range
      [else
       (let ([safe-end (min actual-end len)])
         (append (take lst actual-start)
                 (drop lst safe-end)))])))

(define (list-replace-range lst start-index end-index new-items)
  "Return new list with range [start-index, end-index) replaced by new-items.
   Handles bounds checking gracefully."
  (let ([len (length lst)]
        [actual-start (max 0 start-index)]
        [actual-end (max 0 end-index)])
    (cond
      [(>= actual-start len) (append lst new-items)]  ; Append if start beyond list
      [(>= actual-start actual-end) (list-insert-multiple lst actual-start new-items)]  ; Insert if invalid range
      [else
       (let ([safe-end (min actual-end len)])
         (append (take lst actual-start)
                 new-items
                 (drop lst safe-end)))])))

;;; =================================================================
;;; ADDITIONAL UTILITIES
;;; =================================================================

(define (list-move lst from-index to-index)
  "Return new list with element moved from from-index to to-index"
  (let ([len (length lst)])
    (cond
      [(or (< from-index 0) (>= from-index len)
           (< to-index 0) (>= to-index len)
           (= from-index to-index)) lst]
      [else
       (let ([element (list-ref lst from-index)]
             [without-element (list-delete-range lst from-index (+ from-index 1))])
         (list-insert without-element to-index element))])))

(define (list-swap lst index1 index2)
  "Return new list with elements at index1 and index2 swapped"
  (let ([len (length lst)])
    (cond
      [(or (< index1 0) (>= index1 len)
           (< index2 0) (>= index2 len)
           (= index1 index2)) lst]
      [else
       (let ([val1 (list-ref lst index1)]
             [val2 (list-ref lst index2)])
         (list-update (list-update lst index1 val2) index2 val1))])))

(define (list-split-at lst index)
  "Return two values: (before-list after-list) split at index"
  (let ([safe-index (max 0 (min index (length lst)))])
    (values (take lst safe-index)
            (drop lst safe-index))))

(define (list-insert-multiple lst index items)
  "Return new list with multiple items inserted at index"
  (cond
    [(null? items) lst]
    [(< index 0) (append items lst)]
    [(>= index (length lst)) (append lst items)]
    [else
     (append (take lst index)
             items
             (drop lst index))]))

(define (list-update-multiple lst updates)
  "Return new list with multiple updates applied.
   UPDATES is a list of (index . value) pairs.
   Applied in order, so later updates can reference earlier ones."
  (fold (lambda (update acc)
          (list-update acc (car update) (cdr update)))
        lst
        updates))

;;; =================================================================
;;; SAFE ACCESSORS
;;; =================================================================

(define (list-ref-safe lst index default-value)
  "Safe list-ref that returns default-value if index is out of bounds"
  (cond
    [(< index 0) default-value]
    [(>= index (length lst)) default-value]
    [else (list-ref lst index)]))

(define (list-set-safe lst index value default-value)
  "Safe list update that extends list with default-value if needed"
  (cond
    [(< index 0) lst]
    [(>= index (length lst))
     ;; Extend list with default values
     (let ([extensions (make-list (- index (length lst)) default-value)])
       (append lst extensions (list value)))]
    [else (list-update lst index value)]))

;;; =================================================================
;;; EFFICIENT IMPLEMENTATIONS FOR COMMON PATTERNS
;;; =================================================================

(define (list-replace-multiple lst replacements)
  "Return new list with multiple ranges replaced.
   REPLACEMENTS is a list of (start-index end-index new-items) tuples.
   Applied from right to left to avoid index shifting issues."
  (fold (lambda (replacement acc)
          (let ([start (car replacement)]
                [end (cadr replacement)]
                [items (caddr replacement)])
            (list-replace-range acc start end items)))
        lst
        ;; Sort replacements by start index in descending order
        (sort replacements (lambda (a b) (> (car a) (car b))))))

(define (list-apply-updates lst operations)
  "Apply a sequence of operations to a list.
   OPERATIONS is a list where each element is one of:
   - (update index value)
   - (insert index value)  
   - (delete start end)
   - (replace start end items)
   
   Operations are applied from right to left to avoid index shifting."
  (fold (lambda (op acc)
          (case (car op)
            [(update) (list-update acc (cadr op) (caddr op))]
            [(insert) (list-insert acc (cadr op) (caddr op))]
            [(delete) (list-delete-range acc (cadr op) (caddr op))]
            [(replace) (list-replace-range acc (cadr op) (caddr op) (cadddr op))]
            [else (error "Unknown operation" op)]))
        lst
        ;; Sort operations by position (right to left for most operations)
        (sort operations (lambda (a b) 
                          (let ([pos-a (cadr a)]
                                [pos-b (cadr b)])
                            (> pos-a pos-b))))))
