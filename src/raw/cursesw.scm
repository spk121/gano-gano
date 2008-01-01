;; -*- Mode: scheme; -*-
(define-module (gucu curses)
  #:use-module (ice-9 optargs)
  #:use-module (gucu curses-raw)
  #:use-module (gucu curses-wide-raw)
  #:re-export ( 
	       ;; from add_wch
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
	       
	       )
  #:export (
	    ;; from add_wch
	    add-complex-char
	    echo-complex-char

	    ;; from add_wchstr
	    add-complex-string

	    ;; from addwstr
	    add-wide-string

	    ;; from bkgrnd
	    set-background-complex-char
	    apply-background-complex-char
	    get-background-complex-char

	    ;; from border_set
	    complex-border
	    complex-box
	    complex-hline
	    complex-vline

	    ;; from get_wch
	    get-wide-char
	    unget-wide-char

	    ;; from in_wch
	    extract-complex-char

	    ;; from in_wchstr
	    extract-complex-string

	    ;; from ins_wch
	    insert-complex-char

	    ;; from ins_wstr
	    insert-wide-string

	    ;; from inwstr
	    extract-wide-string
	    ))

;;-------------------------
;; from add_wch

(define* (add-complex-char ch #:key win y x)
  (if (eqv? *ok*
	    (cond
	     ((and (not win) (not y) (not x))
	      (add-wch ch))
	     ((and win (not y) (not x))
	      (wadd-wch win wch))
	     ((and (not win) y x)
	      (mvadd-wch y x ch))
	     ((and win y x)
	      (mvwadd-wch win y x ch))
	     (else
	      (error "Invalid combination of optional arguments"))))
      #t
      #f)))


(define* (echo-complex-char ch #:key win)
  (if (eqv? *ok*
	    (cond
	     ((not win)
	      (echo-wchar ch))
	     (win
	      (wecho-wchar win ch))))
      #t
      #f))

;;-------------------------
;; from add_wchnstr

(define* (add-complex-string wchstr #:key win y x n)
  (if (eqv? *ok*
	    (cond
	     ((and (not win) (not y) (not x) (not n))
	      (add-wchstr wchstr))
	     ((and (not win) (not y) (not x) n)
	      (add-wchnstr wchstr n))
	     ((and win (not y) (not x) (not n))
	      (add-wchstr win wchstr))
	     ((and win (not y) (not x) n)
	      (add-wchnstr win wchstr n))
	     ((and (not win) y x (not n))
	      (mvadd-wchstr y x wchstr))
	     ((and (not win) y x n)
	      (mvadd-wchnstr y x wchstr n))
	     ((and win y x (not n))
	      (mvwadd-wchstr win y x wchstr))
	     ((and win y x n)
	      (mvwadd-wchnstr win y x wchstr n))
	     (else
	      (error "Invalid combination of optional arguments"))))
      #t
      #f))

;;-------------------------
;; from addwstr

(define* (add-wide-string wstr #:key win y x n)
  (if (eqv? *ok*
	    (cond
	     ((and (not win) (not y) (not x) (not n))
	      (addwstr wstr))
	     ((and (not win) (not y) (not x) n)
	      (addnwstr wstr n))
	     ((and win (not y) (not x) (not n))
	      (waddwstr win wstr))
	     ((and win (not y) (not x) n)
	      (waddnwstr win wstr n))
	     ((and (not win) y x (not n))
	      (mvaddwstr y x wstr))
	     ((and (not win) y x n)
	      (mvaddnwstr y x wstr n))
	     ((and win y x (not n))
	      (mvwaddwstr win y x wstr))
	     ((and win y x n)
	      (mvwaddnwstr win y x wstr n))
	     (else
	      (error "Invalid combination of optional arguments"))))
      #t
      #f))

;;-------------------------
;; from bkgrnd

(define* (set-background-complex-char wch #:key win)
  (cond
   (win (wbkgrndset win ch))
   (else (bkgrndset ch)))
  *unspecified*)

(define* (apply-background-complex-char wch #:key win)
  (cond
   (win (wbkgrnd win ch))
   (else (bkgrnd ch)))
  *unspecified*)

(define* (get-background-complex-char #:optional win)
  (cond
   (win (wgetbkgrnd win))
   (else (getbkgrnd))))

;;-------------------------
;; from border_set

(define* (complex-border ls rs ts bs tl tr bl br #:key win)
  (cond
   (win (wborder-set win ls rs ts bs tl tr bl br))
   (else (border-set ls rs ts bs tl tr bl br)))
  *unspecified*)

(define* (complex-box verch horch #:key win)
  (cond
   (win (box-set win verch horch))
   (else (box-set (stdscr) verch horch)))
  *unspecified*)

(define (complex-hline ch #:key win y x n)
  (cond
   ((and (not win) (not y) (not x) (not n))
    (hline-set ch (cols)))
   ((and (not win) (not y) (not x) n)
    (hline-set ch n))
   ((and win (not y) (not x) (not n))
    (whline-set win ch (cols)))
   ((and win (not y) (not x) n)
    (whline-set win ch n))
   ((and (not win) y x (not n))
    (mvhline-set y x ch (cols)))
   ((and (not win) y x n)
    (mvhline-set y x ch n))
   ((and win y x (not n))
    (mvwhline-set win y x ch (cols)))
   ((and win y x n)
    (mvwhline-set win y x ch n))
   (else
    (error "Invalid combination of optional arguments")))
  *unspecified*)

(define (complex-vline ch #:key win y x n)
  (cond
   ((and (not win) (not y) (not x) (not n))
    (vline-set ch (cols)))
   ((and (not win) (not y) (not x) n)
    (vline-set ch n))
   ((and win (not y) (not x) (not n))
    (wvline-set win ch (cols)))
   ((and win (not y) (not x) n)
    (wvline-set win ch n))
   ((and (not win) y x (not n))
    (mvvline-set y x ch (cols)))
   ((and (not win) y x n)
    (mvvline-set y x ch n))
   ((and win y x (not n))
    (mvwvline-set win y x ch (cols)))
   ((and win y x n)
    (mvwvline-set win y x ch n))
   (else
    (error "Invalid combination of optional arguments")))
  *unspecified*)

;;-------------------------
;; from get_wch

(define* (get-wide-char #:key win y x)
  (let* ((status-and-char (cond
			   ((and (not win) (not y) (not x))
			    (get-wch))
			   ((and win (not y) (not x))
			    (wget-wch win))
			   ((and (not win) y x)
			    (mvget-wch y x))
			   ((and win y x)
			    (mvwget-wch win y x))
			   (else
			    (error "Invalid combination of optional arguments"))))
	 (status (car status-and-char))
	 (char (cadr status-and-char)))
    (cond
     ((eqv? status *err*)
      (list 'none 0))
     ((eqv? status *ok*)
      (list 'char char))
     ((eqv? status *key-code-yes*)
      (list 'key char)))))

(define (unget-wide-char ch)
  (if (eqv? *ok*
	    (unget-wch ch))
      #t 
      #f))

;;-------------------------
;; from get_wstr

(define* (get-wide-string #:key win y x n)
  (cond
   ((and (not win) (not y) (not x) (not n))
    (get_wstr wstr))
   ((and (not win) (not y) (not x) n)
    (getn_wstr wstr n))
   ((and win (not y) (not x) (not n))
    (wget_wstr win wstr))
   ((and win (not y) (not x) n)
    (wgetn_wstr win wstr n))
   ((and (not win) y x (not n))
    (mvget_wstr y x wstr))
   ((and (not win) y x n)
    (mvgetn_wstr y x wstr n))
   ((and win y x (not n))
    (mvwget_wstr win y x wstr))
   ((and win y x n)
    (mvwgetn_wstr win y x wstr n))
   (else
    (error "Invalid combination of optional arguments"))))

;;-------------------------
;; from in_wch

(define* (extract-complex-char #:key win y x)
  (cond
   ((and (not win) (not y) (not x))
    (in-wch))
   ((and win (not y) (not x))
    (win-wch win))
   ((and (not win) y x)
    (mvin-wch y x))
   ((and win y x)
    (mvwin-wch))
   (else
    (error "Invalid combination of optional arguments"))))

;;-------------------------
;; from in_wchstr

(define* (extract-complex-string #:key win y x n)
  (cond
   ((and (not win) (not y) (not x) (not n))
    (in-wchstr))
   ((and (not win) (not y) (not x) n)
    (in-wchnstr n))
   ((and win (not y) (not x) (not n))
    (win-wchstr win))
   ((and win (not y) (not x) n)
    (win-wchnstr win n))
   ((and (not win) y x (not n))
    (mvin-wchstr y x))
   ((and (not win) y x n)
    (mvin-wchnstr y x n))
   ((and win y x (not n))
    (mvwin-wchstr win y x))
   ((and win y x n)
    (mvwin-wchnstr win y x n))
   (else
    (error "Invalid combination of optional arguments"))))
  
;;-------------------------
;; from ins_wch

(define* (insert-complex-char ch #:key win y x )
  (if (eqv? *ok*
	    (cond
	     ((and (not win) (not y) (not x))
	      (ins-wch ch))
	     ((and win (not y) (not x))
	      (wins-wch win ch))
	     ((and (not win) y x)
	      (mvins-wch y x ch))
	     ((and win y x)
	      (mvwins-wch win y x ch))
	     (else
	      (error "Invalid combination of optional arguments"))))
      #t
      #f))
  
;;-------------------------
;; from ins_wstr

(define* (insert-wide-string str #:key win y x n)
  (if (eqv? *ok*
	    (cond
	     ((and (not win) (not y) (not x) (not n))
	      (ins-wstr str))
	     ((and (not win) (not y) (not x) n)
	      (ins-nwstr str n))
	     ((and win (not y) (not x) (not n))
	      (wins-wstr win str))
	     ((and win (not y) (not x) n)
	      (wins-nwstr win str n))
	     ((and (not win) y x (not n))
	      (mvins-wstr y x str))
	     ((and (not win) y x n)
	      (mvins-nwstr y x str n))
	     ((and win y x (not n))
	      (mvwins-wstr win y x str))
	     ((and win y x n)
	      (mvwin-nwstr win y x str n))
	     (else
	      (error "Invalid combination of optional arguments"))))
      #t
      #f))
  
;;-------------------------
;; from inwstr

(define* (extract-wide-string #:key win y x n)
  (cond
   ((and (not win) (not y) (not x) (not n))
    (inwstr))
   ((and (not win) (not y) (not x) n)
    (innwstr n))
   ((and win (not y) (not x) (not n))
    (winwstr win))
   ((and win (not y) (not x) n)
    (winnwstr win n))
   ((and (not win) y x (not n))
    (mvinwstr y x))
   ((and (not win) y x n)
    (mvinnwstr y x n))
   ((and win y x (not n))
    (mvwinwstr win y x))
   ((and win y x n)
    (mvwinnwstr win y x n))
   (else
    (error "Invalid combination of optional arguments"))))
  


	 
	    
