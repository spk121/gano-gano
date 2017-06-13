(define-module (gano ecma48-repl)
  #:use-module (gano CBuffer)
  #:use-module (oop goops)
  #:use-module (srfi srfi-1)
  #:use-module (rnrs io ports)
  #:use-module (ice-9 rdelim)
  )

(include-from-path "gano/ecma48-machine.scm")
(define *self* #f)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; An <Ecma48Repl> is a read-eval-print loop for terminal-like
;; control functions for coded character sets.

(define-class <Ecma48Repl> (<CBuffer>)

  (m_AlarmCallback #:init-value #f
		   #:getter get-alarm-callback
		   #:setter set-alarm-callback!))

(define (make-ecma48-repl)
  (let ((rpl (make <Ecma48Repl>)))
    rpl))

(define (ecma48-repl? buf)
  (is-a? buf <Ecma48Repl>))

(define (console-bell)
  (let ((cb (get-alarm-callback *self*)))
    (if cb
	(cb))))

(define (state-machine-do state-id val)
  ;; Get the transition matrix for this state id
  (format #t "Applying value ~s to State #~a.~%" val state-id)
  (let ((transition-list (assoc-ref (third *ecma48-machine*) state-id)))
    (if (not transition-list)
	(error "no transition list for this state")
	;; else
	(let ((range (char-range-ref transition-list val)))
	  (if (not range)
	      (error "there is no transiton out of this state for this val")
	      ;; else
	      (let ((action-list-id (fourth range))
		    (new-state-id (third range)))
		(if (fourth range)
		    (format #t "Range ~s to ~s has actions and transitions to State #~a~%" (first range) (second range) (third range))
		    (format #t "Range ~s to ~s transitions to State #~a~%" (first range) (second range) (third range)))
		    
		(when (integer? action-list-id)
		  (action-list-do action-list-id val))
		new-state-id))))))

(define (char-range-ref range-list x)
  "Given a range list of the form
 (list (lo hi ...) (lo hi ...))
Return the first element of range list where x is
between the first two elements of a given entry."
  (find
   (lambda (entry)
     (and
      (char<=? (first entry) x)
      (char<=? x (second entry))))
   (car range-list)))

(define (action-list-do action-list-id val)
  (let ((action-list-list (assoc-ref (second *ecma48-machine*) action-list-id)))
    (if (not action-list-list)
	(error "there is no action list for this action list id")
	;; else
	(let ((action-list (car action-list-list)))
	  (for-each
	   (lambda (action-id)
	     (action-do action-id val))
	   action-list)))))

(define (action-do action-id val)
  (let ((action-entry (assoc-ref (first *ecma48-machine*) action-id)))
    (if (not action-entry)
	(error "there is no action for this action id")
	;; else
	(action-dispatch (first action-entry) val))))

(define (action-dispatch key val)
  (format #t "Doing action ~s with value ~s~%" key val)
  (case key
    ((do_ack)
     ;; NOOP
     #t)
    ((do_apc)
     ;; APC - Application Program Command
     #t)
    ((do_bel)
     ;; BEL - Bell
     (console-bell))
    ((do_bph)
     ;; BPH - Break Permitted Here
     #t)
    ((do_bs)
     ;; BS - Backspace
     #t)
    ((do_can)
     ;; CAN - Cancel
     #t)
    ((do_cbt)
     ;; CBT - Cursor Backward Tabulation
     #t)
    ((do_cch)
     ;; CCH - Cancel Character
     #t)
    ((do_cht)
     ;; CHT - Cursor Forward Tabulation
     #t)
    ((do_cmd)
     ;; CMD - Coding Method Delimiter
     #t)
    ((do_cnl)
     ;; CNL - Cursor Next Line
     #t)
    ((do_cpl)
     ;; CPS - Cursor Preceding Line
     #t)
    ((do_cpr)
     ;; CPR - Active Position Report
     #t)
    ((do_cr)
     ;; CR - Carriage Return
     #t)
    ((do_ctc)
     ;; CTC - Cursor Tabulation Control
     #t)
    ((do_cub)
     ;; CUB - Cursor Left
     #t)
    ((do_cud)
     ;; CUD - Cursor Down
     #t)
    ((do_cuf)
     ;; CUF - Cursor Right
     #t)
    ((do_cup)
     ;; CUP - Cursor Position
     #t)
    ((do_cuu)
     ;; CUU - Cursor Up
     #t)
    ((do_cvt)
     ;; CVT - Cursor Line Tabulation
     #t)
    ((do_print)
     ;; Write a G0 character
     (write-character *self* val))
    (else
     (format #t "no dispatchable action for the curent key '~a'~%" key))))

(set! *self* (make-ecma48-repl))
(define *state-id* (fourth *ecma48-machine*))
(while #t
  (let ((c (get-u8 (current-input-port))))
    (format #t "received ~s = ~s ~%" (integer->char c) c)
    (let ((ret (state-machine-do *state-id* (integer->char c))))
      (set! *state-id* ret)
      ret)))
