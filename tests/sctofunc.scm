(use-modules (gano global)
	     (gano nano-h))

;; Only valid for Capital letters
(define (control c)
  (- (char->integer c) 64))

(define s (make-sc))
(sc-keystr-set! s "^U")
(sc-type-set! s CONTROL)
(sc-seq-set! s (control #\U))
(sc-menu-set! s MMAIN)
(sc-scfunc-set! s DO_UNCUT_TEXT)
(sc-toggle-set! s 0)
(sc-execute-set! s #t)

(shortcut_init #f)

(define f ((@@ (gano global) sctofunc) s))

#!
(format #t "subnfunc-scfunc ~a~%" (subnfunc-scfunc f))
(format #t "subnfunc-menus ~a~%" (subnfunc-menus f))
(format #t "subnfunc-desc ~a~%" (subnfunc-desc f))
(format #t "subnfunc-help ~a~%" (subnfunc-help f))
(format #t "subnfunc-blank_after ~a~%" (subnfunc-blank_after f))
(format #t "subnfunc-viewok ~a~%" (subnfunc-viewok f))
(format #t "subnfunc-toggle ~a~%" (subnfunc-toggle f))
!#

(define (test)
  (and (eq? (subnfunc-scfunc f) DO_UNCUT_TEXT)
       (string=? (subnfunc-desc f) "UnCut Text")))

(exit (test))