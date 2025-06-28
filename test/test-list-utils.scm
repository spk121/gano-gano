;;; -*- mode: scheme; coding: utf-8; -*-

;;; Test suite for Gano List Utilities Module
;;; Using SRFI-64 testing framework

(use-modules (srfi srfi-64)     ; Testing framework
             (gano list-utils)) ; Module under test

;;; Test suite setup
(test-begin "list-utils")

;;; =================================================================
;;; CORE LIST MANIPULATION TESTS
;;; =================================================================

;;; Tests for list-update
(test-group "list-update"
  (test-equal "update middle element"
    '(1 2 99 4 5)
    (list-update '(1 2 3 4 5) 2 99))

  (test-equal "update first element"
    '(99 2 3 4 5)
    (list-update '(1 2 3 4 5) 0 99))

  (test-equal "update last element"
    '(1 2 3 4 99)
    (list-update '(1 2 3 4 5) 4 99))

  (test-error "negative index throws error"
    (list-update '(1 2 3 4 5) -1 99))

  (test-error "index too large throws error"
    (list-update '(1 2 3 4 5) 5 99))

  (test-error "empty list any index throws error"
    (list-update '() 0 99))

  (test-equal "single element list valid update"
    '(99)
    (list-update '(42) 0 99))

  (test-error "single element list invalid index"
    (list-update '(42) 1 99)))

;;; Tests for list-insert
(test-group "list-insert"
  (test-equal "insert at beginning"
    '(99 1 2 3)
    (list-insert '(1 2 3) 0 99))

  (test-equal "insert in middle"
    '(1 2 99 3 4)
    (list-insert '(1 2 3 4) 2 99))

  (test-equal "insert at end"
    '(1 2 3 99)
    (list-insert '(1 2 3) 3 99))

  (test-error "insert beyond end throws error"
    (list-insert '(1 2 3) 4 99))

  (test-error "negative index throws error"
    (list-insert '(1 2 3) -1 99))

  (test-equal "insert into empty list at 0"
    '(99)
    (list-insert '() 0 99))

  (test-error "insert into empty list beyond 0"
    (list-insert '() 1 99)))

;;; Tests for list-delete-range
(test-group "list-delete-range"
  (test-equal "delete middle range"
    '(1 4 5)
    (list-delete-range '(1 2 3 4 5) 1 3))

  (test-equal "delete from beginning"
    '(3 4 5)
    (list-delete-range '(1 2 3 4 5) 0 2))

  (test-equal "delete to end"
    '(1 2)
    (list-delete-range '(1 2 3 4 5) 2 5))

  (test-equal "delete single element"
    '(1 3 4 5)
    (list-delete-range '(1 2 3 4 5) 1 2))

  (test-equal "delete entire list"
    '()
    (list-delete-range '(1 2 3 4 5) 0 5))

  (test-equal "delete empty range"
    '(1 2 3 4 5)
    (list-delete-range '(1 2 3 4 5) 2 2))

  (test-error "start > end throws error"
    (list-delete-range '(1 2 3 4 5) 3 2))

  (test-error "start beyond list throws error"
    (list-delete-range '(1 2 3) 4 5))

  (test-error "end beyond list throws error"
    (list-delete-range '(1 2 3) 1 5))

  (test-error "negative start throws error"
    (list-delete-range '(1 2 3 4 5) -1 2))

  (test-error "negative end throws error"
    (list-delete-range '(1 2 3 4 5) 1 -1))

  (test-equal "empty list with valid range"
    '()
    (list-delete-range '() 0 0)))

;;; Tests for list-replace-range
(test-group "list-replace-range"
  (test-equal "replace middle range"
    '(1 a b c 5)
    (list-replace-range '(1 2 3 4 5) 1 4 '(a b c)))

  (test-equal "replace with empty list (deletion)"
    '(1 5)
    (list-replace-range '(1 2 3 4 5) 1 4 '()))

  (test-equal "replace with longer list"
    '(1 a b c d e 5)
    (list-replace-range '(1 2 3 4 5) 1 4 '(a b c d e)))

  (test-equal "replace from beginning"
    '(x y z 4 5)
    (list-replace-range '(1 2 3 4 5) 0 3 '(x y z)))

  (test-equal "replace to end"
    '(1 2 x y z)
    (list-replace-range '(1 2 3 4 5) 2 5 '(x y z)))

  (test-equal "replace entire list"
    '(a b c)
    (list-replace-range '(1 2 3 4 5) 0 5 '(a b c)))

  (test-equal "replace empty range (insertion)"
    '(1 2 x y z 3 4 5)
    (list-replace-range '(1 2 3 4 5) 2 2 '(x y z)))

  (test-error "start beyond list throws error"
    (list-replace-range '(1 2 3) 4 5 '(x y z)))

  (test-error "end beyond list throws error"
    (list-replace-range '(1 2 3) 1 5 '(x y z)))

  (test-error "negative start throws error"
    (list-replace-range '(1 2 3) -1 2 '(x y z)))

  (test-error "start > end throws error"
    (list-replace-range '(1 2 3) 2 1 '(x y z))))

;;; =================================================================
;;; ADDITIONAL UTILITIES TESTS
;;; =================================================================

;;; Tests for list-move
(test-group "list-move"
  (test-equal "move element forward from position 0 to 1"
    '(2 1 3 4 5)
    (list-move '(1 2 3 4 5) 0 1))

  (test-equal "move element forward from position 0 to 2"
    '(2 3 1 4 5)
    (list-move '(1 2 3 4 5) 0 2))

  (test-equal "move element forward from position 1 to 2"
    '(1 3 2 4 5)
    (list-move '(1 2 3 4 5) 1 2))

  (test-equal "move element forward from position 1 to 3"
    '(1 3 4 2 5)
    (list-move '(1 2 3 4 5) 1 3))

  (test-equal "move element backward from position 3 to 1"
    '(1 4 2 3 5)
    (list-move '(1 2 3 4 5) 3 1))

  (test-equal "move element backward from position 2 to 0"
    '(3 1 2 4 5)
    (list-move '(1 2 3 4 5) 2 0))

  (test-equal "move element backward"
    '(1 4 2 3 5)
    (list-move '(1 2 3 4 5) 3 1))

  (test-equal "move to same position"
    '(1 2 3 4 5)
    (list-move '(1 2 3 4 5) 2 2))

  (test-equal "move first to end"
    '(2 3 4 5 1)
    (list-move '(1 2 3 4 5) 0 5))

  (test-equal "move last to first"
    '(5 1 2 3 4)
    (list-move '(1 2 3 4 5) 4 0))

  (test-error "invalid from-index throws error"
    (list-move '(1 2 3 4 5) -1 2))

  (test-error "invalid to-index throws error"
    (list-move '(1 2 3 4 5) 2 6))

  (test-error "from-index out of bounds throws error"
    (list-move '(1 2 3 4 5) 5 2)))

;;; Tests for list-swap
(test-group "list-swap"
  (test-equal "swap middle elements"
    '(1 4 3 2 5)
    (list-swap '(1 2 3 4 5) 1 3))

  (test-equal "swap first and last"
    '(5 2 3 4 1)
    (list-swap '(1 2 3 4 5) 0 4))

  (test-equal "swap same index"
    '(1 2 3 4 5)
    (list-swap '(1 2 3 4 5) 2 2))

  (test-equal "swap adjacent elements"
    '(2 1 3 4 5)
    (list-swap '(1 2 3 4 5) 0 1))

  (test-error "invalid index1 throws error"
    (list-swap '(1 2 3 4 5) -1 3))

  (test-error "invalid index2 throws error"
    (list-swap '(1 2 3 4 5) 1 5))

  (test-error "both indices invalid throws error"
    (list-swap '(1 2 3 4 5) -1 5)))

;;; Tests for list-split-at
(test-group "list-split-at"
  (test-equal "split in middle"
    (values '(1 2) '(3 4 5))
    (list-split-at '(1 2 3 4 5) 2))

  (test-equal "split at beginning"
    (values '() '(1 2 3 4 5))
    (list-split-at '(1 2 3 4 5) 0))

  (test-equal "split at end"
    (values '(1 2 3 4 5) '())
    (list-split-at '(1 2 3 4 5) 5))

  (test-error "split beyond end throws error"
    (list-split-at '(1 2 3) 4))

  (test-error "negative index throws error"
    (list-split-at '(1 2 3) -1))

  (test-equal "split empty list at 0"
    (values '() '())
    (list-split-at '() 0))

  (test-error "split empty list beyond 0 throws error"
    (list-split-at '() 1)))

;;; Tests for list-insert-multiple
(test-group "list-insert-multiple"
  (test-equal "insert multiple in middle"
    '(1 2 a b c 3 4)
    (list-insert-multiple '(1 2 3 4) 2 '(a b c)))

  (test-equal "insert multiple at beginning"
    '(x y z 1 2 3)
    (list-insert-multiple '(1 2 3) 0 '(x y z)))

  (test-equal "insert multiple at end"
    '(1 2 3 x y z)
    (list-insert-multiple '(1 2 3) 3 '(x y z)))

  (test-equal "insert empty list"
    '(1 2 3)
    (list-insert-multiple '(1 2 3) 1 '()))

  (test-error "insert beyond end throws error"
    (list-insert-multiple '(1 2 3) 4 '(a b c)))

  (test-error "negative index throws error"
    (list-insert-multiple '(1 2 3) -1 '(a b c))))

;;; Tests for list-update-multiple
(test-group "list-update-multiple"
  (test-equal "multiple updates"
    '(99 2 88 4 77)
    (list-update-multiple '(1 2 3 4 5) '((0 . 99) (2 . 88) (4 . 77))))

  (test-equal "overlapping updates (later wins)"
    '(1 2 77 4 5)
    (list-update-multiple '(1 2 3 4 5) '((2 . 99) (2 . 77))))

  (test-equal "empty updates"
    '(1 2 3 4 5)
    (list-update-multiple '(1 2 3 4 5) '()))

  (test-equal "single update"
    '(1 99 3 4 5)
    (list-update-multiple '(1 2 3 4 5) '((1 . 99))))

  (test-error "invalid index in updates throws error"
    (list-update-multiple '(1 2 3 4 5) '((0 . 99) (5 . 88)))))

;;; =================================================================
;;; SAFE ACCESSORS TESTS (These should NOT throw errors)
;;; =================================================================

;;; Tests for list-ref-safe
(test-group "list-ref-safe"
  (test-equal "valid index"
    3
    (list-ref-safe '(1 2 3 4 5) 2 'default))

  (test-equal "negative index returns default"
    'default
    (list-ref-safe '(1 2 3 4 5) -1 'default))

  (test-equal "index too large returns default"
    'default
    (list-ref-safe '(1 2 3 4 5) 10 'default))

  (test-equal "empty list returns default"
    'default
    (list-ref-safe '() 0 'default))

  (test-equal "boundary case - last valid index"
    5
    (list-ref-safe '(1 2 3 4 5) 4 'default)))

;;; Tests for list-set-safe
(test-group "list-set-safe"
  (test-equal "update existing index"
    '(1 2 99 4 5)
    (list-set-safe '(1 2 3 4 5) 2 99 'fill))

  (test-equal "extend list with defaults"
    '(1 2 3 fill fill 99)
    (list-set-safe '(1 2 3) 5 99 'fill))

  (test-equal "negative index ignored"
    '(1 2 3)
    (list-set-safe '(1 2 3) -1 99 'fill))

  (test-equal "extend empty list"
    '(fill fill 99)
    (list-set-safe '() 2 99 'fill))

  (test-equal "set at exact length"
    '(1 2 3 99)
    (list-set-safe '(1 2 3) 3 99 'fill)))

;;; =================================================================
;;; OVERLAP DETECTION TESTS
;;; =================================================================

(test-group "overlap-detection"
  (test-equal "non-overlapping ranges should succeed"
    '(a b 3 4 x y)
    (list-replace-multiple '(1 2 3 4 5 6)
                           '((0 2 (a b)) (4 6 (x y)))))

  (test-equal "adjacent ranges (end=start) should succeed"
    '(a b x y 5 6)
    (list-replace-multiple '(1 2 3 4 5 6)
                           '((0 2 (a b)) (2 4 (x y)))))

  (test-error "overlapping by one position throws error"
    (list-replace-multiple '(1 2 3 4 5 6)
			   '((0 3 (a b)) (2 5 (x y)))))

  (test-error "range1 starts inside range2"
    (list-replace-multiple '(1 2 3 4 5 6 7 8)
			   '((1 4 (a)) (3 6 (b)))))

  (test-error "range1 ends inside range2"
    (list-replace-multiple '(1 2 3 4 5 6 7 8)
			   '((1 5 (a)) (3 7 (b)))))

  (test-error "range1 completely contains range2"
    (list-replace-multiple '(1 2 3 4 5 6 7 8)
			   '((0 6 (a)) (2 4 (b)))))

  (test-error "range2 completely contains range1"
    (list-replace-multiple '(1 2 3 4 5 6 7 8)
			   '((2 4 (a)) (0 6 (b)))))

  (test-error "identical ranges"
    (list-replace-multiple '(1 2 3 4 5)
			   '((1 4 (a)) (1 4 (b)))))

  (test-error "three ranges with middle overlapping both"
    (list-replace-multiple '(1 2 3 4 5 6 7 8 9 10)
			   '((0 3 (a)) (2 6 (b)) (5 8 (c)))))

  (test-equal "three non-overlapping ranges should succeed"
    '(a 3 4 b 7 8 c)
    (list-replace-multiple '(1 2 3 4 5 6 7 8 9 10)
                           '((0 2 (a)) (4 6 (b)) (8 10 (c))))))

;;; Tests for list-replace-multiple
(test-group "list-replace-multiple"
  (test-equal "multiple non-overlapping replacements"
    '(a b 3 4 x y)
    (list-replace-multiple '(1 2 3 4 5 6)
                           '((0 2 (a b)) (4 6 (x y)))))

  (test-equal "single replacement"
    '(1 x y z 5)
    (list-replace-multiple '(1 2 3 4 5)
                           '((1 4 (x y z)))))

  (test-equal "empty replacements"
    '(1 2 3 4 5)
    (list-replace-multiple '(1 2 3 4 5) '()))

  (test-equal "replacement with deletion"
    '(1 5)
    (list-replace-multiple '(1 2 3 4 5)
                           '((1 4 ()))))

  (test-equal "adjacent non-overlapping ranges"
    '(a b x y z)
    (list-replace-multiple '(1 2 3 4 5)
                           '((0 2 (a b)) (2 5 (x y z)))))

  (test-equal "zero-length ranges (insertions)"
    '(1 a b 2 x y 3 4 5)
    (list-replace-multiple '(1 2 3 4 5)
                           '((1 1 (a b)) (2 2 (x y)))))

  (test-error "overlapping ranges throw error"
    (list-replace-multiple '(1 2 3 4 5 6)
			   '((0 3 (a b)) (2 5 (x y z)))))

  (test-error "completely contained range throws error"
    (list-replace-multiple '(1 2 3 4 5 6)
			   '((0 5 (a b c)) (2 3 (x)))))

  (test-error "containing range throws error"
    (list-replace-multiple '(1 2 3 4 5 6)
			   '((2 3 (x)) (0 5 (a b c)))))

  (test-error "identical ranges throw error"
    (list-replace-multiple '(1 2 3 4 5)
			   '((1 3 (a b)) (1 3 (x y)))))

  (test-error "partial overlap at end throws error"
    (list-replace-multiple '(1 2 3 4 5 6)
			   '((0 3 (a b)) (2 4 (x y)))))

  (test-error "partial overlap at start throws error"
    (list-replace-multiple '(1 2 3 4 5 6)
			   '((1 4 (a b)) (0 2 (x y)))))

  (test-error "invalid indices in replacement throw error"
    (list-replace-multiple '(1 2 3 4 5)
			   '((0 2 (a b)) (3 8 (x y z))))))

;;; Tests for list-apply-updates
(test-group "list-apply-updates"
  (test-equal "mixed non-overlapping operations"
    '(99 a b 4 x)
    (list-apply-updates '(1 2 3 4 5)
			'((update 0 99)
                          (replace 1 3 (a b))
                          (update 4 x))))

  (test-equal "non-overlapping insert and delete operations"
    '(1 x y 5)
    (list-apply-updates '(1 2 3 4 5)
			'((delete 1 4)
                          (insert 4 x)
                          (insert 4 y))))

  (test-equal "single operation"
    '(1 2 99 4 5)
    (list-apply-updates '(1 2 3 4 5)
			'((update 2 99))))

  (test-equal "empty operations"
    '(1 2 3 4 5)
    (list-apply-updates '(1 2 3 4 5) '()))

  (test-equal "non-overlapping sequence"
    '(start 1 2 middle 5)
    (list-apply-updates '(1 2 3 4 5)
			'((insert 0 start)
                          (replace 2 4 (middle)))))

  (test-equal "adjacent operations (end=start)"
    '(1 x 4 5)
    (list-apply-updates '(1 2 3 4 5)
			'((replace 1 3 (x))
                          (update 3 4))))

  (test-error "overlapping update and replace throws error"
    (list-apply-updates '(1 2 3 4 5)
			'((update 2 99)
			  (replace 1 4 (a b c)))))

  (test-error "overlapping delete and insert throws error"
    (list-apply-updates '(1 2 3 4 5)
			'((delete 1 4)
			  (insert 2 x))))

  (test-error "overlapping replace operations throw error"
    (list-apply-updates '(1 2 3 4 5)
			'((replace 0 3 (a b))
			  (replace 2 5 (x y z)))))

  (test-error "complex overlapping sequence throws error"
    (list-apply-updates '(1 2 3 4 5)
			'((insert 0 start)
			  (replace 1 4 (middle))
			  (insert 3 end))))

  (test-error "invalid operation indices throw error"
    (list-apply-updates '(1 2 3 4 5)
			'((update 0 99) (update 10 88))))

  (test-error "unknown operation throws error"
    (list-apply-updates '(1 2 3 4 5)
			'((unknown 0 99)))))

;;; =================================================================
;;; ERROR MESSAGE TESTS
;;; =================================================================

(define (make-error-msg key args)
  (let* ([format-str (if (> (length args) 0) (cadr args) "")]
	 [format-args (if (> (length args) 1) (caddr args) '())]
	 [msg (apply format (append (list #f format-str) format-args))])
    msg))
  
(test-group "error-messages"
  (test-assert "list-update error contains function name"
    (catch #t
	   (lambda ()
             (list-update '(1 2 3) -1 99)
             #f) ; Should not reach here
	   (lambda (key . args)
             (let ([msg (make-error-msg key args)])
               (string-contains msg "list-update")))))

  (test-assert "list-insert error contains function name"
    (catch #t
	   (lambda ()
             (list-insert '(1 2 3) 5 99)
             #f) ; Should not reach here
	   (lambda (key . args)
             (let ([msg (make-error-msg key args)])
               (string-contains msg "list-insert")))))
  
  (test-assert "list-delete-range error contains function name"
    (catch #t
	   (lambda ()
             (list-delete-range '(1 2 3) -1 2)
             #f) ; Should not reach here
	   (lambda (key . args)
             (let ([msg (make-error-msg key args)])
               (string-contains msg "list-delete-range")))))

  (test-assert "overlapping ranges error mentions overlap"
    (catch #t
	   (lambda ()
             (list-replace-multiple '(1 2 3 4 5) '((0 3 (a)) (2 4 (b))))
             #f) ; Should not reach here
	   (lambda (key . args)
             (let ([msg (make-error-msg key args)])
               (string-contains-ci msg "overlap"))))))

;;; =================================================================
;;; EDGE CASES WITH BOUNDS
;;; =================================================================

(test-group "edge-cases-strict"
  (test-equal "operations on single element list"
    '(99)
    (list-update '(42) 0 99))

  (test-error "single element list invalid index"
    (list-update '(42) 1 99))

  (test-equal "operations preserve list structure"
    '((1 2) (3 4) (5 6))
    (list-update '((1 2) (a b) (5 6)) 1 '(3 4)))

  (test-equal "operations with nested lists"
    '(1 (a (b c)) 3)
    (list-insert '(1 3) 1 '(a (b c))))

  (test-error "empty list operations with invalid indices"
    (list-update '() 0 99)))

;;; Test suite cleanup
(test-end "list-utils")

;; Local Variables:
;; eval: (put 'test-group 'scheme-indent-function 1)
;; eval: (put 'test-assert 'scheme-indent-function 1)
;; eval: (put 'test-equal 'scheme-indent-function 1)
;; eval: (put 'test-error 'scheme-indent-function 1)
;; End:
