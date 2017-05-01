(define-module (gano io)
  #:export (get-tty-line))

(define (get-tty-line)
  "Read a line of text from stdin. Return line length."
  (let ((oi 0)
	(i 0)
	(c #f))

    (while #t
      (let ((c (get-char (current-input-port))))
	(cond
	 ((eof-object? c)
	  (if (= i oi)
	      (continue)
	      i))
	 (else
	  (set! oi 0)
	  (set! ibuf (string-append ibuf (string c)))
	  (when (char=? c #\null)
	    (set! binary #t))
	  (if (not (char=? c #\nl))
	      (continue)
	      i)))))))
