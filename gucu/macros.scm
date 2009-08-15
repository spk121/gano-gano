;; -*- Mode: scheme; -*-
(define-module (gucu macros)
  #:export (
            check-char
            check-char-or-rendered-char
            check-complex-char-or-wide-char
            check-complex-string-or-wide-string
            check-integer
            check-integer-and-range-check
            check-position-and-move
            check-string
            check-string-or-rendered-string
            check-window
            check-x
            check-y
            render-char-if-necessary
            render-string-if-necessary
            render-wide-char-if-necessary
            render-wide-string-if-necessary
            string-length-or-length
            WIN-CCH-KEY-YX
            WIN-CST-KEY-YX-N
            WIN-RCH-KEY-YX
            WIN-RST-KEY-YX-N
            WIN-ST-KEY-YX-N 
            ))

;; Range checks

(defmacro check-char (ch)
  `(if (not (char? ,ch))
       (scm-error 'wrong-type-arg fname 
                  "Not a character: ~S" (list ,ch) (list ,ch))))

(defmacro check-char-or-rendered-char (ch)
  `(if (not (or (integer? ,ch)          ; rendered narrow char
                (char? ,ch)))           ; plain char
       (scm-error 'wrong-type-arg fname 
                  "Not a character or a rendered character: ~S" (list ,ch) (list ,ch))))

(defmacro check-complex-char-or-wide-char (ch)
  `(if (not (or (and (list? ,ch)        ; rendered complex char
                     (<= 3 (length ,ch)) 
                     (<= (length ,ch) 7))
                (and (integer? ,ch)     ; wide char
                     (<= 0 ,ch)
                     (<= ,ch #x10ffff))))
       (scm-error 'wrong-type-arg fname 
                  "Not a complex character or wide character: ~S" (list ,ch) (list ,ch))))

(defmacro check-complex-string-or-wide-string (str)
  `(if (not (or (and (list? ,str)       ; rendered complex string
                     (or (null? ,str)
                         (and (list? (list-ref ,str 0))
                              (<= 3 (length (list-ref ,str 0))))))
                (and (list? ,str)        ; wide string
                     (or (null? ,str)
                         (integer? (list-ref ,str 0))))))
       (scm-error 'wrong-type-arg fname 
                  "Not a complex string or wide string: ~S" (list ,str) (list ,str))))

(defmacro check-integer (n)
  `(if (not (integer? ,n))
       (scm-error 'wrong-type-arg fname 
                  "Not an integer: ~S" (list ,n) (list ,n))))

(defmacro check-integer-and-range-check (n lo hi)
  `(cond
    ((not (integer? ,n))
     (scm-error 'wrong-type-arg fname 
                "Not an integer: ~S" (list ,n) (list ,n)))
    ((or (< ,n ,lo) (> ,n ,hi))
     (scm_error 'out-of-range fname
                "N value out of range ~S to ~S: ~S" (list ,lo ,hi ,n) (list ,n)))))

(defmacro check-position-and-move (win y x)
  `(if (and ,y ,x)
       (begin
         (check-integer ,x)
         (check-integer ,y)
         (check-x ,win ,x)
         (check-y ,win ,y)
         (%wmove ,win (inexact->exact ,y) (inexact->exact ,x)))
       #t))

(defmacro check-string (str)
  `(if (not (string? ,str))
       (scm-error 'wrong-type-arg fname 
                  "Not a string: ~S" (list ,str) (list ,str))))


;; This doesn't check every member of the list.  
(defmacro check-string-or-rendered-string (str)
  `(if (not (or (string? ,str) 
                (and (list? ,str) (or (null? ,str) 
                                      (integer? (list-ref ,str 0))))))
       (scm-error 'wrong-type-arg fname 
                  "Not a string or a rendered string: ~S" (list ,str) (list ,str))))

(defmacro check-wide-string (str)
  `(if (not (and (list? ,str)           ; wide string
                 (or (null? ,str)
                     (integer? (list-ref ,str 0)))))
       (scm-error 'wrong-type-arg fname 
                  "Not a complex string or wide string: ~S" (list ,str) (list ,str))))

(defmacro check-window (win)
  `(if (not (window? ,win))
       (scm-error 'wrong-type-arg fname 
                  "Not a window: ~S" (list ,win) (list ,win))))

(defmacro check-x (win x)
  `(let ((maxyx (getmaxyx ,win)))
     (if (or (< ,x 0) (>= ,x (cadr maxyx)))
         (scm-error 'out-of-range fname 
                    "X value out of range: ~S" (list ,x) (list ,x)))))

(defmacro check-y (win y)
  `(let ((maxyx (getmaxyx ,win)))
     (if (or (< ,y 0) (>= ,y (car maxyx)))
         (scm-error 'out-of-range fname 
                    "Y value out of range: ~S" (list ,y) (list ,y)))))

;; decorators

(defmacro render-char-if-necessary (ch)
  `(if (char? ,ch)
       (char->integer ,ch)
       (inexact->exact ,ch)))

(defmacro render-string-if-necessary (str)
  `(if (string? ,str)
       (map char->integer (string->list ,str))
       ,str))

(defmacro render-wide-char-if-necessary (ch)
  `(if (integer? ,ch)
       (list A_NORMAL 0 ,ch)
       ,ch))

(defmacro render-wide-string-if-necessary (str)
  `(if (and (not (null? ,str))
            (integer? (list-ref ,str 0)))
       (map (lambda (c) 
              (list A_NORMAL 0 c))
            ,str)
       ,str))

(defmacro string-length-or-length (str)
  `(if (string? ,str)
       (string-length ,str)
       (length ,str)))
  
;; declaration outlines

;; CCH -> rendered, complex character
;; CST -> rendered, complex string
;; RCH -> rendered, narrow character
;; RST -> rendered, narrow string
;; ST -> unrendered, narrow string, e.g. a regular string
;; WIN -> window

(defmacro WIN-CCH-KEY-YX (func primitive-func)
  `(define* (,func win ch #:key y x)
     (let ((fname (symbol->string ',func)))
       (check-window win)
       (check-complex-char-or-wide-char ch)
       (and (check-position-and-move win y x)
            (,primitive-func win (render-wide-char-if-necessary ch))))))

(defmacro WIN-CST-KEY-YX-N (func primitive-func)
  `(define* (,func win str #:key y x (n -1))
     (let ((fname (symbol->string ',func)))
       (check-window win)
       (check-complex-string-or-wide-string str)
       (check-integer-and-range-check n -1 (length str))
       (and (check-position-and-move win y x)
            (,primitive-func win 
                             (render-wide-string-if-necessary str) 
                             (inexact->exact n))))))

(defmacro WIN-RCH-KEY-YX (func primitive-func)
  `(define* (,func win ch #:key y x)
     (let ((fname (symbol->string ',func)))
       (check-window win)
       (check-char-or-rendered-char ch)
       (and (check-position-and-move win y x)
            (,primitive-func win (render-char-if-necessary ch))))))

(defmacro WIN-RST-KEY-YX-N (func primitive-func)
  `(define* (,func win str #:key y x (n -1))
     (let ((fname (symbol->string ',func)))
       (check-window win)
       (check-string-or-rendered-string str)
       (check-integer-and-range-check n -1 (string-length-or-length str))
       (and (check-position-and-move win y x)
            (,primitive-func win 
                             (render-string-if-necessary str) 
                             (inexact->exact n))))))

(defmacro WIN-ST-KEY-YX-N (func primitive-func)
  `(define* (,func win str #:key y x (n -1))
     (let ((fname (symbol->string ',func)))
       (check-window win)
       (check-string str)
       (check-integer-and-range-check n -1 (string-length str))
       (and (check-position-and-move win y x)
            (,primitive-func win 
                             str
                             (inexact->exact n))))))

(defmacro WIN-WST-KEY-YX-N (func primitive-func)
  `(define* (,func win str #:key y x (n -1))
     (let ((fname (symbol->string ',func)))
       (check-window win)
       (check-wide-string str)
       (check-integer-and-range-check n -1 (length str))
       (and (check-position-and-move win y x)
            (,primitive-func win 
                             str
                             (inexact->exact n))))))

