(define-module (gano parser tty)
  #:use-module (srfi srfi-1)
  #:use-module (rnrs io ports)
  #:use-module (rnrs bytevectors)
  #:use-module (gano CBuffer)
  #:use-module (oop goops)
  #:export(<CTTYParser>

	   ;; Constructors
	   make-tty-parser
	   tty-parser->binary-output-port))

(define-class <CTTYParser> (<CBuffer>)
  ;; The store
  (m_crlf #:init-value #t #:getter get-crlf #:setter set-crlf!)
  (m_bel #:init-value #f #:getter get-bell #:setter set-bell!)
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CONSTRUCTORS


(define (make-tty-parser)
  (let* ((tty (make <CTTYParser>)))
    (set-line-limit tty 80)
    (set-invalid-movement-mode! tty (list 'auto_right_margin))
    (set-mode tty 'IRM 'replace)
    tty))

(define-method (bell (tty <CTTYParser>))
  (set-bell! tty #t))

(define-method (push-char (tty <CTTYParser>) c)
  ;;(format #t "Display ~s~%" c)
  (cond
   ((not (char-set-contains? char-set:ascii c))
    #f)
   ((or (char-set-contains? char-set:graphic c) (char=? c #\space))
    (write-character tty c))
   ((char=? c #\return)
    (carriage-return tty))
   ((char=? c #\newline)
    (line-feed tty)
    (when (get-crlf tty)
	  (carriage-return tty)))
   ((char=? c #\alarm)
    (bell tty))))

(define-method (push-u8 (tty <CTTYParser>) u8)
  (push-char tty (integer->char u8)))

(define (tty-parser->binary-output-port tty)
  (let* ((eof? #f)
	 (write! (lambda (bv start count)
		   ;; (format #t "write! ~s ~s ~s~%" bv start count)
		   (if (= 0 count)
		       (begin
			 (set! eof? #t)
			 0)
		       (begin
			 (do ((i 0 (1+ i)))
			     ((>= i count))
			   (push-u8 tty (bytevector-u8-ref bv (+ i start))))
			 count))))
	 (get-position (lambda ()
			 (get-active-data-location tty)))
	 (port  (make-custom-binary-output-port "<CTTYParser> port"
						write!
						get-position
						#f    ; set-position
						#f 	; close
						)))
    port))

