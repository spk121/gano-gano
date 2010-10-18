(define-module (gano prompt)
  #:export (
	    do_prompt_abort
	    ))

;; The old cursor position in answer, if any
(define old_statusbar_x -1)
;; The old place we want in answer, if any
(define old_pww -1)
;; Should we reset the cursor position at the statusbar prompt?
(define reset_statusbar_x #f)

;; This function forces a reset of the statusbar cursor position.
;; It should be called when we get out of all statusbar prompts.
(define (do_prompt_abort)
  ;; Unitialize the old cursor position in answer.
  (set! old_statusbar_x -1)
  (set! old_pww -1)
  (set! reset_statusbar_x #t))