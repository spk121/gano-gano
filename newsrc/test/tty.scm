;;; ----------------------------------------------------------------
;;;   unit test for CBuffer
;;; ----------------------------------------------------------------
(use-modules (gano CBuffer)
	     (gano parser tty)
	     ;; (rnrs bytevectors)
	     (unit-test)
	     (oop goops))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; write-character

(define-class <tty-write> (<test-case>)
  (one-tty #:accessor tty)
  (one-tty-port #:accessor tty-port))

(define-method (set-up-test (tc <tty-write>))
  (set! (tty tc) (make-tty-parser))
  (set! (tty-port tc) (tty-parser->binary-output-port (tty tc)))
  (setvbuf (tty-port tc) 'none))

(define-method (test-write-one (tc <tty-write>))
  (display #\x (tty-port tc))
  (write (get-text (tty-port tc))) (newline)
  (assert-equal "x" (get-text-cur (tty tc))))

(exit-with-summary (run-all-defined-test-cases))
