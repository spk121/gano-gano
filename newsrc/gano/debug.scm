(define-module (gano debug)
  #:use-module (system repl repl)
  #:use-module (system repl debug)
  #:export (break-here))

(define-syntax-rule (break-here)
  (start-repl
   #:debug (make-debug (stack->vector (make-stack #t)) 0 "trap!" #t)))
