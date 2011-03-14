;;; function.scm - Association between Function IDs, help strings, and function contexts

(define FUNC_ID 1)
(define FUNC_CONTEXT 2)
(define FUNC_DESCRIPTION 3)
(define FUNC_HELP 4)
(define FUNC_BLANK_AFTER 5)
(define FUNC_READ_ONLY 6)
(define FUNC_TOGGLE 7)
(define FUNC_TOGGLE_ID 8)
(define FUNC_LENGTH (+ 1 FUNC_TOGGLE_ID))

(define (func-get-id func)            (vector-ref func FUNC_ID))
(define (func-get-context func)       (vector-ref func FUNC_CONTEXT))
(define (func-get-description func)   (vector-ref func FUNC_DESCRIPTION))
(define (func-get-help func)          (vector-ref func FUNC_HELP))
(define (func-get-blank-after func)   (vector-ref func FUNC_BLANK_AFTER))
(define (func-get-read-only func)     (vector-ref func FUNC_READ_ONLY))
(define (func-get-toggle func)        (vector-ref func FUNC_TOGGLE))
(define (func-get-toggle-id func)     (vector-ref func FUNC_TOGGLE_ID))
(define (func-get-height func)        (vector-ref func FUNC_HEIGHT))

(define (func-set-id! func x)            (vector-set! func FUNC_ID x))
(define (func-set-context! func x)       (vector-set! func FUNC_CONTEXT x))
(define (func-set-description! func x)   (vector-set! func FUNC_DESCRIPTION x))
(define (func-set-help! func x)          (vector-set! func FUNC_HELP x))
(define (func-set-blank-after! func x)   (vector-set! func FUNC_BLANK_AFTER x))
(define (func-set-read-only! func x)     (vector-set! func FUNC_READ_ONLY x))
(define (func-set-toggle! func x)        (vector-set! func FUNC_TOGGLE x))
(define (func-set-toggle-id! func x)     (vector-set! func FUNC_TOGGLE_ID x))
(define (func-set-height! func x)        (vector-set! func FUNC_HEIGHT x))

(define (func-make-function)
  "Create a function."
  (let ((func (make-vector FUNC_LENGTH #f)))
    (vector-set! func 0 'func)
    (func-set-id! func 'NOOP)
    (func-set-context! func 0)
    (func-set-description! func "Noop")
    (func-set-help! func "A function that does nothing")
    (func-set-blank-after! func #f)
    (func-set-read-only! func #t)
    (func-set-toggle! func #f)
    (func-set-toggle-id! func 0)
    func))

;; The list of all defined functions
(define *functions* '())

(define (func-create-function funcID context desc help fReadOnly fBlankAfter)
  "Creates and initializes a new function structure"
  (let ([fn (func-make-function)])
    (func-set-id! fn funcID)
    (func-set-context! fn context)
    (func-set-description! fn desc)
    (func-set-help! fn help)
    (func-set-read-only! fn fReadOnly)
    (func-set-blank-after! fn fBlankAfter)
    fn))

(define (func-add-function func context description help fBlankAfter fViewOk)
  "Adds information about a function to the global function list."
  (let ([fn (func-create-function func context description help fBlankAfter fViewOk)])
    (set! *functions* (append! *functions* (list fn)))
    (log-debug (format #f "Added func \"~a\"" description))))

(define (GetFunctionMenus fn) (func-get-context fn))
(define (GetFunctionDesc fn) (func-get-description fn))
(define (GetFunctionId fn) (func-get-id fn))
