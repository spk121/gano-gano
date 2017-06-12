(define-module (myxml)
  #:use-module (srfi srfi-1)
  #:use-module (sxml simple)
  #:use-module (sxml xpath)
  #:use-module (ice-9 pretty-print))

(define X (xml->sxml (open-input-file "ecma48.xml")
		     #:trim-whitespace? #t))

(define ACTION_LIST
  ((sxpath `(// action_list action))
   X))

(define (transform-action entry)
  (list
   (string->number (second (first ((sxpath `(// id)) entry))))
   (string->symbol (second (first ((sxpath `(// name)) entry))))
   (second (first ((sxpath `(// text)) entry)))))

(define action-list
  (map transform-action ACTION_LIST))

(define ACTION_TABLE_LIST
  ((sxpath `(// action_table_list action_table))
   X))

(define (transform-action-table entry)
  (list
   (string->number (second (first ((sxpath `(// id)) entry))))
   (map string->number (string-split (last entry) #\space))))

(define action-table-list
  (map transform-action-table ACTION_TABLE_LIST))

(define STATE_LIST
  ((sxpath `(// state_list state)) X))

(define (transform-state entry)
  (list
   (string->number (second (first ((sxpath `(// id)) entry))))
   (map (lambda (transition)
	  (let ((T (map (lambda (val)
			  (false-if-exception (string->number val)))
			(string-split (car (cdr transition)) #\space))))
	    (list 
	     (integer->char (first T))
	     (integer->char (second T))
	     (third T)
	     (fourth T))))
	((sxpath `(// t)) entry))))

(define state-list
  (map transform-state STATE_LIST))

(define start-state
  (string->number (second (first ((sxpath `(// start_state)) X)))))

(define state-machine-data
  (list
   action-list
   action-table-list
   state-list
   start-state))

(display "(define *ecma48-machine* '")
(pretty-print state-machine-data)
(display ")")
(newline)




