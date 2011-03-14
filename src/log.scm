;; Yet another quick and dirty set of logging routines

;; The output-port for debug information
(define *log-port* (open-output-file "gano.log"))
(define (%log-port)
  *log-port*)

(define *log-level* 'debug)

(define (log-log str)
  (display (strftime "%T" (localtime (current-time))) (%log-port))
  (display ": " (%log-port))
  (display str (%log-port))
  (newline (%log-port))
  (force-output (%log-port)))

(define (log-trivia str)
  (when (eq? *log-level* 'trivia)
    (log-log str)))

(define (log-debug str)
  (when (member *log-level* (list 'trivia 'debug))
    (log-log str)))

(define (log-info str)
  (when (member *log-level* (list 'trivia 'debug 'info))
    (log-log str)))

(define (log-warning str)
  (when (member *log-level* (list 'trivia 'debug 'info 'warning))
    (log-log str)))

(define (log-error str)
  (when (member *log-level* (list 'trivia 'debug 'info 'warning 'error))
    (log-log str)))

(define (log-critical str)
  (log-log str))
