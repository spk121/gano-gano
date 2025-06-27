#|

A CTerminalBuffer is a subclass of a CScreenBuffer with some
miscellaneous methods that might be useful when being used as the
backing store for an actual terminal widget.

|#

	    bell			; BEL
	    bell?
	    clear-bell
  (m_Bel #:init-value #f #:getter get-bell #:setter set-bell!)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; QUERIES


(define-method (bell? (buf <CBuffer>))
  "Has there been a call for attention?" 
  (get-bell buf))


;; BELL - Set call for attention
(define-method (bell (buf <CBuffer>))
  "Call for attention" 
  (set-bell! buf #t))

(define-method (op-bell (buf <CBuffer>))
  (list 'bell (get-bell buf)))

(define-method (apply-op-bell (buf <CBuffer>) op)
  (set-bell! buf #t))

(define-method (undo-op-bell (buf <CBuffer>) op)
  (set-bell! buf (second op)))

;; CLEAR_BELL - unset call for attention

(define-method (clear-bell (buf <CBuffer>))
  "Reset any call for attention." 
  (set-bell! buf #f))

(define-method (op-clear-bell (buf <CBuffer>))
  (list 'clear-bell (get-bell buf)))

(define-method (apply-op-clear-bell (buf <CBuffer>) op)
  (set-bell! buf #f))

(define-method (undo-op-clear-bell (buf <CBuffer>) op)
  (set-bell! buf (second op)))


