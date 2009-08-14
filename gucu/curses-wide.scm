
;; -*- Mode: scheme; -*-
(define-module (gucu curses-wide)
  #:use-module (ice-9 optargs)
  #:use-module (gucu curses)
  #:export ( 
	    WEOF
	    add-wch
	    add-wchstr
	    addwstr
	    bkgrnd
	    bkgrndset
	    border-set
	    box-set
	    echo-wchar
	    erasewchar
	    getbkgrnd
	    get-wch
	    getn-wstr
	    hline-set
	    in-wch
	    in-wchstr
	    innwstr
	    ins-wch
	    ins-wstr
	    key-name
	    killwchar
	    mvadd-wch
	    mvwadd-wch
	    term-attrs
	    unget-wch
	    vline-set
	    wacs-block
	    wacs-board
	    wacs-btee
	    wacs-bullet
	    wacs-ckboard
	    wacs-darrow
	    wacs-degree
	    wacs-diamond
	    wacs-hline
	    wacs-lantern
	    wacs-larrow
	    wacs-llcorner
	    wacs-lrcorner
	    wacs-ltee
	    wacs-plminus
	    wacs-plus
	    wacs-rarrow
	    wacs-rtee
	    wacs-s1
	    wacs-s9
	    wacs-ttee
	    wacs-uarrow
	    wacs-ulcorner
	    wacs-urcorner
	    wacs-vline
))

(define* (add-wch win ch #:key x y)
  (and (if (and x y)
	   (move win y x)
	   #t)
       (%wadd-wch win ch)))

(define* (add-wchstr win wchstr #:key x y (n -1))
  (and (if (and x y)
	   (move win y x)
	   #t)
       (%wadd-wchnstr win wchstr n)))

(define* (addwstr win wstr #:key x y (n -1))
  (and (if (and x y)
	   (move win y x)
	   #t)
       (%waddnwstr win wstr n)))

(define (bkgrnd win wch)
  (%wbkgrnd win wch))

(define (bkgrndset win wch)
  (%wbkgrndset win wch))

(define (border-set win a b c d e f g h)
  (%wborder-set win a b c d e f g h))

(define (box-set win v h key)
  (%wborder-set win v v h h 0 0 0 0))

(define* (echo-wchar win ch #:key y x)
  (and (if (and y x)
	   (move win y x)
	   #t)
       (%wecho-wchar win ch)))

(define* (getbkgrnd #:key win)
  (%wgetbkgrnd win))

(define* (get-wch win #:key y x)
  (and (if (and y x)
	   (move win y x)
	   #t)
       (%wget-wch win)))

(define* (getn-wstr win n #:key y x)
  (and (if (and y x)
	   (move win y x)
	   #t)
       (%wgetn-wstr win n)))

(define* (hline-set win ch n #:key y x)
  (and (if (and y x)
	   (move win y x)
	   #t)
       (%whline-set win ch n)))

(define* (in-wch win #:key y x)
  (and (if (and y x)
	   (move win y x)
	   #t)
       (%win-wch win)))

(define* (in-wchstr win #:key y x (n -1))
  (and (if (and y x)
	   (move win y x)
	   #t)
       (%win-wchnstr win n)))

(define* (ins-wch win #:key y x)
  (and (if (and y x)
	   (move win y x)
	   #t)
       (%wins-wch win)))

(define* (ins-wstr win str #:key y x (n -1))
  (and (if (and y x)
	   (move win y x)
	   #t)
       (%wins-nwstr win str n)))

(define* (innwstr win n #:key y x)
  (and (if (and y x)
	   (move win y x)
	   #t)
       (%winnwstr win n)))

(define* (vline-set win ch n #:key y x)
  (and (if (and y x)
	   (move win y x)
	   #t)
       (%wvline-set win ch n)))


(load-extension "libguile-gucu" "gucu_cursw_init")
