(use-modules (ice-9 optargs)
	     (ncurses core))

;; Prepare a terminal by gathering information from the terminfo
;; database, but, do not set up the main window.  NAME is the terminal
;; identifier (e.g. "vt220") used to gather information from the
;; terminfo database.  If it is 'default TERM is gathered from the shell
;; environment variables.  The CURRENT_OUTPUT_PORT is where this
;; terminal will output.  If you are not setting to a special tty, set
;; it using (current-output-port).
(define* (terminal-setup #:optional (name (getenv "TERM")) (output-port (current-output-port)))
  (begin 
    (if (not name)
	(set! name "unknown"))
    (case (setupterm name (port->fdes output-port))
      ((1) (error 'curses 
		  "terminal-setup" 
		  "Terminal ~s is a hardcopy terminal" 
		  name))
      ((0) (error 'curses 
		  "terminal-setup" 
		  "Terminal ~s was not found in the terminfo database"
		  name))
      ((-1) (error 'curses
		   "terminal-setup"
		   "The terminfo database was not found"))
      (else #t))))

(define (terminal-attributes)
  (term-attrs))

(define (attributes->list a)
  (let ((alist '()))
    (cond
     ((logand a *a-altcharset*)
      (set! alist (append alist '(altcharset))))
     ((logand a *a-blink*)
      (set! alist (append alist '(blink))))
     ((logand a *a-bold*)
      (set! alist (append alist '(bold))))
     ((logand a *a-dim*)
      (set! alist (append alist '(dim))))
     ((logand a *a-reverse*)
      (set! alist (append alist '(dim))))
     ((logand a *a-standout*)
      (set! alist (append alist '(standout))))
     ((logand a *a-protect*)
      (set! alist (append alist '(protect))))
     ((logand a *a-invisible*)
      (set! alist (append alist '(invisible))))
     ((logand a *a-underline*)
      (set! alist (append alist '(underline))))
     ((logand a *a-color*)
      (set! alist (append alist '(dim))))
     ((logand a *wa-horizontal*)
      (set! alist (append alist '(horizontal))))
;;      ((logand a *wa-left*)
;;       (set! alist (append alist '(left))))
;;      ((logand a *wa-low*)
;;       (set! alist (append alist '(low))))
;;      ((logand a *wa-right*)
;;       (set! alist (append alist '(right))))
;;      ((logand a *wa-top*)
;;       (set! alist (append alist '(top))))
;;      ((logand a *wa-vertical)
;;       (set! alist (append alist '(vertical))))
     ((color-pair a)
      (set! alist (append alist `((color-pair ,(color-pair a))))))
    alist))

