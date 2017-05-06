;;; ----------------------------------------------------------------
;;;   unit test for CBuffer
;;; ----------------------------------------------------------------
(use-modules (gano CBuffer)
             (unit-test)
             (oop goops))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; make-empty-cbuffer
(define-class <test-make-empty-cbuffer> (<test-case>))

(define-method (test-make-empty-cbuffer (tc <test-make-empty-cbuffer>))
  (assert-true
   (is-a? (make-empty-cbuffer) <CBuffer>)))

(define-method (test-empty-cbuffer-line (tc <test-make-empty-cbuffer>))
  (assert-equal 0
   (get-line-cur (make-empty-cbuffer))))

(define-method (test-empty-cbuffer-pd (tc <test-make-empty-cbuffer>))
  (assert-equal 0
   (get-pd-cur (make-empty-cbuffer))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; cbuffer?
(define-class <test-cbuffer?> (<test-case>))

(define-method (test-cbuffer?-true (tc <test-cbuffer?>))
  (assert-true
   (cbuffer? (make-empty-cbuffer))))

(define-method (test-cbuffer?-false (tc <test-cbuffer?>))
  (assert-equal #f
   (cbuffer? '())))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; carriage-return

(define-class <test-carriage-return> (<test-case>))

(define-method (test-carriage-return-one-pd (tc <test-carriage-return>))
  (let ((C (make-empty-cbuffer)))
    (write-character C #\x)
    (carriage-return C)
    (assert-equal 0 (get-pd-cur C))))

(define-method (test-carriage-return-one-line (tc <test-carriage-return>))
  (let ((C (make-empty-cbuffer)))
    (write-character C #\x)
    (carriage-return C)
    (assert-equal 0 (get-line-cur C))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; write-character

(define-class <test-write-one-character> (<test-case>)
  (one-char-cbuf #:accessor cbuf))

(define-method (set-up-test (tc <test-write-one-character>))
  (set! (cbuf tc) (make-empty-cbuffer))
  (write-character (cbuf tc) #\x))

(define-method (test-write-one (tc <test-write-one-character>))
    (assert-equal "x" (get-text-cur (cbuf tc))))

(define-method (test-write-one-line-cur (tc <test-write-one-character>))
    (assert-equal 0 (get-line-cur (cbuf tc))))

(define-method (test-write-one-pd-cur (tc <test-write-one-character>))
    (assert-equal 1 (get-pd-cur (cbuf tc))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; add tag

(define-class <test-tags> (<test-case>)
  (_cbuf #:accessor cbuf))

(define-method (set-up-test (tc <test-tags>))
  (set! (cbuf tc) (make-empty-cbuffer))
  (write-character (cbuf tc) #\x)
  (add-tag (cbuf tc) 'here))

(define-method (test-get-tag (tc <test-tags>))
  (assert-equal (list (list 'here 0 1)) (get-tags (cbuf tc))))

(exit-with-summary (run-all-defined-test-cases))
