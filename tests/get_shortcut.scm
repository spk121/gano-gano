(use-modules ((gano winio) #:select (get_shortcut))
	     ((gano global) #:select (shortcut_init))
	     (gano nano-h)
	      )

;; Only valid for Capital letters
(define (control c)
  (- (char->integer c) 64))
(define (meta c)
  (char->integer (char-downcase c)))

(shortcut_init #t)

(define sc_a (get_shortcut MMAIN #\a #f #f))
(define sc_control_a (get_shortcut MMAIN (control #\A) #f #t))
(define sc_meta_a (get_shortcut MMAIN (meta #\A) #t #f))

(define (func x)
  (if x
      (sc-scfunc x)
      x))

;; (format #t "~s ~s ~s~%" (func sc_a) (func sc_control_a) (func sc_meta_a))

(define (test)
  (and (eq? (func sc_a) #f)
       (eq? (func sc_control_a) DO_HOME)
       (eq? (func sc_meta_a) DO_MARK)))

(exit (test))
