;;#lang racket
;; Copyright (c) 2005, 2006 Per Bothner
;;
;; Permission is hereby granted, free of charge, to any person
;; obtaining a copy of this software and associated documentation
;; files (the "Software"), to deal in the Software without
;; restriction, including without limitation the rights to use, copy,
;; modify, merge, publish, distribute, sublicense, and/or sell copies
;; of the Software, and to permit persons to whom the Software is
;; furnished to do so, subject to the following conditions:
;;
;; The above copyright notice and this permission notice shall be
;; included in all copies or substantial portions of the Software.
;;
;; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
;; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
;; MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
;; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
;; BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
;; ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
;; CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;; SOFTWARE.

(define %test-runner-cookie (list "test-runner"))

(define (%test-runner-alloc)
  (let ((runner (make-vector 23)))
    (vector-set! runner 0 %test-runner-cookie)
    runner))

(define (test-runner? obj)
  (and (vector? obj)
       (> (vector-length obj) 1)
       (eq? (vector-ref obj 0) %test-runner-cookie)))

 ;; Cumulate count of all tests that have passed and were expected to.
(define (test-runner-pass-count runner)      (vector-ref runner 1))
(define (test-runner-fail-count runner)      (vector-ref runner 2))
(define (test-runner-xpass-count runner)     (vector-ref runner 3))
(define (test-runner-xfail-count runner)     (vector-ref runner 4))
(define (test-runner-skip-count runner)      (vector-ref runner 5))
(define (%test-runner-skip-list runner)      (vector-ref runner 6))
(define (%test-runner-fail-list runner)      (vector-ref runner 7))
 ;; Normally #t, except when in a test-apply.
(define (%test-runner-run-list runner)       (vector-ref runner 8))
(define (%test-runner-skip-save runner)      (vector-ref runner 9))
(define (%test-runner-fail-save runner)      (vector-ref runner 10))
(define (test-runner-group-stack runner)     (vector-ref runner 11))
(define (test-runner-on-test-begin runner)   (vector-ref runner 12))
(define (test-runner-on-test-end runner)     (vector-ref runner 13))
 ;; Call-back when entering a group. Takes (runner suite-name count).
(define (test-runner-on-group-begin runner)  (vector-ref runner 14))
 ;; Call-back when leaving a group.
(define (test-runner-on-group-end runner)    (vector-ref runner 15))
 ;; Call-back when leaving the outermost group.
(define (test-runner-on-final runner)        (vector-ref runner 16))
;; Call-back when expected number of tests was wrong.
(define (test-runner-on-bad-count runner)    (vector-ref runner 17))
;; Call-back when name in test=end doesn't match test-begin.
(define (test-runner-on-bad-end-name runner) (vector-ref runner 18))
;; Cumulate count of all tests that have been done.
(define (%test-runner-total-count runner)    (vector-ref runner 19))
;; Stack (list) of (count-at-start . expected-count):
(define (%test-runner-count-list runner)     (vector-ref runner 20))
(define (test-result-alist runner)           (vector-ref runner 21))
 ;; Field can be used by test-runner for any purpose.
 ;; test-runner-simple uses it for a log file.
(define (test-runner-aux-value runner)       (vector-ref runner 22))


(define (test-runner-pass-count! runner x)      (vector-set! runner 1 x))
(define (test-runner-fail-count! runner x)      (vector-set! runner 2 x))
(define (test-runner-xpass-count! runner x)     (vector-set! runner 3 x))
(define (test-runner-xfail-count! runner x)     (vector-set! runner 4 x))
(define (test-runner-skip-count! runner x)      (vector-set! runner 5 x))
(define (%test-runner-skip-list! runner x)      (vector-set! runner 6 x))
(define (%test-runner-fail-list! runner x)      (vector-set! runner 7 x))
(define (%test-runner-run-list! runner x)       (vector-set! runner 8 x))
(define (%test-runner-skip-save! runner x)      (vector-set! runner 9 x))
(define (%test-runner-fail-save! runner x)      (vector-set! runner 10 x))
(define (test-runner-group-stack! runner x)     (vector-set! runner 11 x))
(define (test-runner-on-test-begin! runner x)   (vector-set! runner 12 x))
(define (test-runner-on-test-end! runner x)     (vector-set! runner 13 x))
(define (test-runner-on-group-begin! runner x)  (vector-set! runner 14 x))
(define (test-runner-on-group-end! runner x)    (vector-set! runner 15 x))
(define (test-runner-on-final! runner x)        (vector-set! runner 16 x))
(define (test-runner-on-bad-count! runner x)    (vector-set! runner 17 x))
(define (test-runner-on-bad-end-name! runner x) (vector-set! runner 18 x))
(define (%test-runner-total-count! runner x)    (vector-set! runner 19 x))
(define (%test-runner-count-list! runner x)     (vector-set! runner 20 x))
(define (test-result-alist! runner x)           (vector-set! runner 21 x))
(define (test-runner-aux-value! runner x)       (vector-set! runner 22 x))

(define (test-runner-reset runner)
    (test-runner-pass-count! runner 0)
    (test-runner-fail-count! runner 0)
    (test-runner-xpass-count! runner 0)
    (test-runner-xfail-count! runner 0)
    (test-runner-skip-count! runner 0)
    (%test-runner-total-count! runner 0)
    (%test-runner-count-list! runner '())
    (%test-runner-run-list! runner #t)
    (%test-runner-skip-list! runner '())
    (%test-runner-fail-list! runner '())
    (%test-runner-skip-save! runner '())
    (%test-runner-fail-save! runner '())
    (test-runner-group-stack! runner '()))

(define (test-runner-group-path runner)
  (reverse (test-runner-group-stack runner)))

(define (%test-null-callback runner) #f)

(define (test-runner-null)
  (let ((runner (%test-runner-alloc)))
    (test-runner-reset runner)
    (test-runner-on-group-begin! runner (lambda (runner name count) #f))
    (test-runner-on-group-end! runner %test-null-callback)
    (test-runner-on-final! runner %test-null-callback)
    (test-runner-on-test-begin! runner %test-null-callback)
    (test-runner-on-test-end! runner %test-null-callback)
    (test-runner-on-bad-count! runner (lambda (runner count expected) #f))
    (test-runner-on-bad-end-name! runner (lambda (runner begin end) #f))
    runner))

(define test-log-to-file #t)

(define (test-runner-simple)
  (let ((runner (%test-runner-alloc)))
    (test-runner-reset runner)
    (test-runner-on-group-begin! runner test-on-group-begin-simple)
    (test-runner-on-group-end! runner test-on-group-end-simple)
    (test-runner-on-final! runner test-on-final-simple)
    (test-runner-on-test-begin! runner test-on-test-begin-simple)
    (test-runner-on-test-end! runner test-on-test-end-simple)
    (test-runner-on-bad-count! runner test-on-bad-count-simple)
    (test-runner-on-bad-end-name! runner test-on-bad-end-name-simple)
    runner))

(define %test-runner-current #f)

(define (test-runner-current . x)
  (if (not (null? x))
      (set! %test-runner-current (car x))
      %test-runner-current))
(define %test-runner-factory test-runner-simple)
(define (test-runner-factory . x)
  (if (not (null? x))
      (set! %test-runner-factory (car x))
      %test-runner-factory))

(define (test-runner-get)
  (let ((r (test-runner-current)))
    (and (not r)
         (error "test-runner not initialized - test-begin missing?"))
    r))

(define (%test-specificier-matches spec runner)
  (spec runner))

(define (test-runner-create)
  ((test-runner-factory)))

(define (%test-any-specifier-matches list runner)
  (let ((result #f))
    (let loop ((l list))
      (cond ((null? l) result)
            (else
             (and (%test-specificier-matches (car l) runner)
                  (set! result #t))
             (loop (cdr l)))))))

;; Returns #f, #t, or 'xfail.
(define (%test-should-execute runner)
  (let ((run (%test-runner-run-list runner)))
    (cond ((or
            (not (or (eqv? run #t)
                     (%test-any-specifier-matches run runner)))
            (%test-any-specifier-matches
             (%test-runner-skip-list runner)
             runner))
            (test-result-set! runner 'result-kind 'skip)
            #f)
          ((%test-any-specifier-matches
            (%test-runner-fail-list runner)
            runner)
           (test-result-set! runner 'result-kind 'xfail)
           'xfail)
          (else #t))))

(define (%test-begin suite-name count)
  (and (not (test-runner-current))
       (test-runner-current (test-runner-create)))
  (let ((runner (test-runner-current)))
    ((test-runner-on-group-begin runner) runner suite-name count)
    (%test-runner-skip-save! runner
                               (cons (%test-runner-skip-list runner)
                                     (%test-runner-skip-save runner)))
    (%test-runner-fail-save! runner
                               (cons (%test-runner-fail-list runner)
                                     (%test-runner-fail-save runner)))
    (%test-runner-count-list! runner
                             (cons (cons (%test-runner-total-count runner)
                                         count)
                                   (%test-runner-count-list runner)))
    (test-runner-group-stack! runner (cons suite-name
                                        (test-runner-group-stack runner)))))

(define (test-begin suite-name . x)
  (if (null? x)
      (%test-begin suite-name #f)
      (%test-begin suite-name count)))

(define (test-on-group-begin-simple runner suite-name count)
  (and (null? (test-runner-group-stack runner))
       (begin
         (display "%%%% Starting test ")
         (display suite-name)
         (and test-log-to-file
              (let* ((log-file-name
                      (if (string? test-log-to-file) test-log-to-file
                          (string-append suite-name ".log")))
                     (log-file
                      (open-output-file log-file-name)))
                (display "%%%% Starting test " log-file)
                (display suite-name log-file)
                (newline log-file)
                (test-runner-aux-value! runner log-file)
                (display "  (Writing full log to \"")
                (display log-file-name)
                (display "\")")))
         (newline)))
  (let ((log (test-runner-aux-value runner)))
    (and (output-port? log)
         (begin
           (display "Group begin: " log)
           (display suite-name log)
           (newline log))))
  #f)

(define (test-on-group-end-simple runner)
  (let ((log (test-runner-aux-value runner)))
    (and (output-port? log)
         (begin
           (display "Group end: " log)
           (display (car (test-runner-group-stack runner)) log)
           (newline log))))
  #f)

(define (%test-on-bad-count-write runner count expected-count port)
  (display "*** Total number of tests was " port)
  (display count port)
  (display " but should be " port)
  (display expected-count port)
  (display ". ***" port)
  (newline port)
  (display "*** Discrepancy indicates testsuite error or exceptions. ***" port)
  (newline port))

(define (test-on-bad-count-simple runner count expected-count)
  (%test-on-bad-count-write runner count expected-count (current-output-port))
  (let ((log (test-runner-aux-value runner)))
    (and (output-port? log)
         (%test-on-bad-count-write runner count expected-count log))))

(define (test-on-bad-end-name-simple runner begin-name end-name)
  (let ((msg (string-append (%test-format-line runner) "test-end " begin-name
                            " does not match test-begin " end-name)))
    (display msg)
    (newline)))


(define (%test-final-report1 value label port)
  (and (> value 0)
       (begin
         (display label port)
         (display value port)
         (newline port))))

(define (%test-final-report-simple runner port)
  (%test-final-report1 (test-runner-pass-count runner)
                      "# of expected passes      " port)
  (%test-final-report1 (test-runner-xfail-count runner)
                      "# of expected failures    " port)
  (%test-final-report1 (test-runner-xpass-count runner)
                      "# of unexpected successes " port)
  (%test-final-report1 (test-runner-fail-count runner)
                      "# of unexpected failures  " port)
  (%test-final-report1 (test-runner-skip-count runner)
                      "# of skipped tests        " port))

(define (test-on-final-simple runner)
  (%test-final-report-simple runner (current-output-port))
  (let ((log (test-runner-aux-value runner)))
    (and (output-port? log)
         (%test-final-report-simple runner log)))
  (if (= 0 (+ (test-runner-xpass-count runner)
              (test-runner-fail-count runner)))
      (exit 0)
      (exit 1)))

(define (%test-format-line runner)
   (let* ((line-info (test-result-alist runner))
          (source-file (assq 'source-file line-info))
          (source-line (assq 'source-line line-info))
          (file (if source-file (cdr source-file) "")))
     (if source-line
         (string-append file ":"
                        (number->string (cdr source-line)) ": ")
         "")))

(define (%test-end suite-name line-info)
  (let* ((r (test-runner-get))
         (groups (test-runner-group-stack r))
         (line (%test-format-line r)))
    (test-result-alist! r line-info)
    (and (null? groups)
         (let ((msg (string-append line "test-end not in a group")))
           (error msg)))
    (and suite-name (not (equal? suite-name (car groups)))
         ((test-runner-on-bad-end-name r) r suite-name (car groups)))
    (let* ((count-list (%test-runner-count-list r))
           (expected-count (cdar count-list))
           (saved-count (caar count-list))
           (group-count (- (%test-runner-total-count r) saved-count)))
      (and expected-count
           (not (= expected-count group-count))
           (test-runner-on-bad-count r) r group-count expected-count)
      ((test-runner-on-group-end r) r)
      (test-runner-group-stack! r (cdr (test-runner-group-stack r)))
      (%test-runner-skip-list! r (car (%test-runner-skip-save r)))
      (%test-runner-skip-save! r (cdr (%test-runner-skip-save r)))
      (%test-runner-fail-list! r (car (%test-runner-fail-save r)))
      (%test-runner-fail-save! r (cdr (%test-runner-fail-save r)))
      (%test-runner-count-list! r (cdr count-list))
      (and (null? (test-runner-group-stack r))
           ((test-runner-on-final r) r)))))

(define-syntax test-group
  (syntax-rules ()
    ((test-group suite-name . body)
     (let ((r (test-runner-current)))
       ;; Ideally should also set line-number, if available.
       (test-result-alist! r (list (cons 'test-name suite-name)))
       (if (%test-should-execute r)
           (dynamic-wind
               (lambda () (test-begin suite-name))
               (lambda () . body)
               (lambda () (test-end  suite-name))))))))

(define-syntax test-group-with-cleanup
  (syntax-rules ()
    ((test-group-with-cleanup suite-name form cleanup-form)
     (test-group suite-name
                    (dynamic-wind
                        (lambda () #f)
                        (lambda () form)
                        (lambda () cleanup-form))))
    ((test-group-with-cleanup suite-name cleanup-form)
     (test-group-with-cleanup suite-name #f cleanup-form))
    ((test-group-with-cleanup suite-name form1 form2 form3 . rest)
     (test-group-with-cleanup suite-name (begin form1 form2) form3 . rest))))

(define (test-on-test-begin-simple runner)
 (let ((log (test-runner-aux-value runner)))
    (and (output-port? log)
         (let* ((results (test-result-alist runner))
                (source-file (assq 'source-file results))
                (source-line (assq 'source-line results))
                (source-form (assq 'source-form results))
                (test-name (assq 'test-name results)))
           (display "Test begin:" log)
           (newline log)
           (and test-name (%test-write-result1 test-name log))
           (and source-file (%test-write-result1 source-file log))
           (and source-line (%test-write-result1 source-line log))
           (and source-file (%test-write-result1 source-form log))))))

(define-syntax test-result-ref
  (syntax-rules ()
    ((test-result-ref runner pname)
     (test-result-ref runner pname #f))
    ((test-result-ref runner pname default)
     (let ((p (assq pname (test-result-alist runner))))
       (if p (cdr p) default)))))

(define (test-on-test-end-simple runner)
  (let ((log (test-runner-aux-value runner))
        (kind (test-result-ref runner 'result-kind)))
    (and (memq kind '(fail xpass))
        (let* ((results (test-result-alist runner))
               (source-file (assq 'source-file results))
               (source-line (assq 'source-line results))
               (test-name (assq 'test-name results)))
          (and (or source-file source-line)
               (begin
                 (and source-file (display (cdr source-file)))
                 (display ":")
                 (and source-line (display (cdr source-line)))
                 (display ": ")))
          (display (if (eq? kind 'xpass) "XPASS" "FAIL"))
          (and test-name
               (begin
                 (display " ")
                 (display (cdr test-name))))
          (newline)))
    (and (output-port? log)
         (begin
           (display "Test end:" log)
           (newline log)
           (let loop ((list (test-result-alist runner)))
             (and (pair? list)
                  (let ((pair (car list)))
                    ;; Write out properties not written out by on-test-begin.
                    (and (not (memq (car pair)
                                    '(test-name source-file source-line source-form)))
                         (%test-write-result1 pair log))
                    (loop (cdr list)))))))))

(define (%test-write-result1 pair port)
  ;;(display "  " port)
  (let ((s1 (format #f "~a" (car pair))))
    (display (make-string (max 0 (- 18 (string-length s1))) #\space) port)
    (display s1 port)
    (display ": " port)
    (write (cdr pair) port)
    (newline port)))

(define (assq-set alist key val)
  (if (null? alist)
      (list (cons key val))
      ;; else
      (let loop ((in alist)
                 (out '())
                 (f #f))
        (display in) (newline)
        (display out) (newline)
        (if (null? in)
            (if f
                out
                (append out (list (cons key val))))
            (if (eq? (car (car in)) key)
                (loop (cdr in)
                      (append out
                              (list (cons key val)))
                      #t)
                ;; else
                (loop (cdr in)
                      (append out
                              (list (car in)))
                      f))))))


(define (test-result-set! runner pname value)
  (let* ((alist (test-result-alist runner))
         (p (assq pname alist)))
    (if p
        (test-result-alist! runner (assq-set alist pname value))
        (test-result-alist! runner (cons (cons pname value) alist)))))

(define (test-result-clear runner)
  (test-result-alist! runner '()))

(define (test-result-remove runner pname)
  (let* ((alist (test-result-alist runner))
         (p (assq pname alist)))
    (and p
         (test-result-alist! runner
                             (let loop ((r alist))
                               (if (eq? r p)
                                   (cdr r)
                                   (cons (car r) (loop (cdr r)))))))))

(define (test-result-kind . rest)
  (let ((runner (if (pair? rest) (car rest) (test-runner-current))))
    (test-result-ref runner 'result-kind)))

(define (test-passed? . rest)
  (let ((runner (if (pair? rest) (car rest) (test-runner-get))))
    (memq (test-result-ref runner 'result-kind) '(pass xpass))))

(define (%test-report-result)
  (let* ((r (test-runner-get))
         (result-kind (test-result-kind r)))
    (case result-kind
      ((pass)
       (test-runner-pass-count! r (+ 1 (test-runner-pass-count r))))
      ((fail)
       (test-runner-fail-count! r (+ 1 (test-runner-fail-count r))))
      ((xpass)
       (test-runner-xpass-count! r (+ 1 (test-runner-xpass-count r))))
      ((xfail)
       (test-runner-xfail-count! r (+ 1 (test-runner-xfail-count r))))
      (else
       (test-runner-skip-count! r (+ 1 (test-runner-skip-count r)))))
    (%test-runner-total-count! r (+ 1 (%test-runner-total-count r)))
    ((test-runner-on-test-end r) r)))

(define (%test-evaluate-with-catch test-expression)
  test-expression)

(define (%test-source-line2 form)
    '())

(define (%test-on-test-begin r)
  (%test-should-execute r)
  ((test-runner-on-test-begin r) r)
  (not (eq? 'skip (test-result-ref r 'result-kind))))

(define (%test-on-test-end r result)
    (test-result-set! r 'result-kind
                      (if (eq? (test-result-ref r 'result-kind) 'xfail)
                          (if result 'xpass 'xfail)
                          (if result 'pass 'fail))))

(define (test-runner-test-name runner)
  (test-result-ref runner 'test-name ""))

(define-syntax %test-comp2body
  (syntax-rules ()
                ((%test-comp2body r comp expected expr)
                 (let ()
                   (and (%test-on-test-begin r)
                        (let ((exp expected))
                          (test-result-set! r 'expected-value exp)
                          (let ((res (%test-evaluate-with-catch expr)))
                            (test-result-set! r 'actual-value res)
                            (%test-on-test-end r (comp exp res)))))
                   (%test-report-result)))))

(define (%test-approximimate= error)
  (lambda (value expected)
    (and (>= value (- expected error))
         (<= value (+ expected error)))))

(define-syntax %test-comp1body
  (syntax-rules ()
    ((%test-comp1body r expr)
     (let ()
       (and (%test-on-test-begin r)
            (let ()
              (let ((res (%test-evaluate-with-catch expr)))
                (test-result-set! r 'actual-value res)
                (%test-on-test-end r res))))
       (%test-report-result)))))

(define-syntax test-end
  (syntax-rules ()
    ((test-end)
     (%test-end #f '()))
    ((test-end suite-name)
     (%test-end suite-name '()))))
(define-syntax test-assert
  (syntax-rules ()
    ((test-assert tname test-expression)
     (let* ((r (test-runner-get))
            (name tname))
       (test-result-alist! r '((test-name . tname)))
       (%test-comp1body r test-expression)))
    ((test-assert test-expression)
     (let* ((r (test-runner-get)))
       (test-result-alist! r '())
       (%test-comp1body r test-expression)))))
(define-syntax %test-comp2
  (syntax-rules ()
    ((%test-comp2 comp tname expected expr)
     (let* ((r (test-runner-get))
            (name tname))
       (test-result-alist! r (list (cons 'test-name tname)))
       (%test-comp2body r comp expected expr)))
    ((%test-comp2 comp expected expr)
     (let* ((r (test-runner-get)))
       (test-result-alist! r '())
       (%test-comp2body r comp expected expr)))))
(define-syntax test-equal
  (syntax-rules ()
    ((test-equal . rest)
     (%test-comp2 equal? . rest))))
(define-syntax test-eqv
  (syntax-rules ()
    ((test-eqv . rest)
     (%test-comp2 eqv? . rest))))
(define-syntax test-eq
  (syntax-rules ()
    ((test-eq . rest)
     (%test-comp2 eq? . rest))))
(define-syntax test-approximate
  (syntax-rules ()
    ((test-approximate tname expected expr error)
     (%test-comp2 (%test-approximimate= error) tname expected expr))
    ((test-approximate expected expr error)
     (%test-comp2 (%test-approximimate= error) expected expr))))

(define-syntax %test-error
  (syntax-rules ()
    ((%test-error r etype expr)
     (begin
       ((test-runner-on-test-begin r) r)
       (test-result-set! r 'result-kind 'skip)
       (%test-report-result)))))

(define-syntax test-error
  (syntax-rules ()
    ((test-error name etype expr)
     (test-assert name (%test-error (test-runner-current) etype expr)))
    ((test-error etype expr)
     (test-assert (%test-error (test-runner-current) etype expr)))
    ((test-error expr)
     (test-assert (%test-error (test-runner-current) #t expr)))))

(define (test-apply first . rest)
  (if (test-runner? first)
      (test-with-runner first (apply test-apply rest))
      (let ((r (test-runner-current)))
        (if r
            (let ((run-list (%test-runner-run-list r)))
              (cond ((null? rest)
                     (%test-runner-run-list! r (reverse run-list))
                     (first)) ;; actually apply procedure thunk
                    (else
                     (%test-runner-run-list!
                      r
                      (if (eq? run-list #t) (list first) (cons first run-list)))
                     (apply test-apply rest)
                     (%test-runner-run-list! r run-list))))
            (let ((r (test-runner-create)))
              (test-with-runner r (apply test-apply first rest))
              ((test-runner-on-final r) r))))))

(define-syntax test-with-runner
  (syntax-rules ()
    ((test-with-runner runner form ...)
     (let ((saved-runner (test-runner-current)))
       (dynamic-wind
           (lambda () (test-runner-current runner))
           (lambda () form ...)
           (lambda () (test-runner-current saved-runner)))))))

;;; Predicates

(define (%test-match-nth n count)
  (let ((i 0))
    (lambda (runner)
      (set! i (+ i 1))
      (and (>= i n) (< i (+ n count))))))

(define-syntax test-match-nth
  (syntax-rules ()
    ((test-match-nth n)
     (test-match-nth n 1))
    ((test-match-nth n count)
     (%test-match-nth n count))))

(define (%test-match-all . pred-list)
  (lambda (runner)
    (let ((result #t))
      (let loop ((l pred-list))
        (if (null? l)
            result
            (begin
              (and (not ((car l) runner))
                   (set! result #f))
              (loop (cdr l))))))))

(define-syntax test-match-all
  (syntax-rules ()
    ((test-match-all pred ...)
     (%test-match-all (%test-as-specifier pred) ...))))

(define (%test-match-any . pred-list)
  (lambda (runner)
    (let ((result #f))
      (let loop ((l pred-list))
        (if (null? l)
            result
            (begin
              (and ((car l) runner)
                   (set! result #t))
              (loop (cdr l))))))))

(define-syntax test-match-any
  (syntax-rules ()
    ((test-match-any pred ...)
     (%test-match-any (%test-as-specifier pred) ...))))

;; Coerce to a predicate function:
(define (%test-as-specifier specifier)
  (cond ((procedure? specifier) specifier)
        ((integer? specifier) (test-match-nth 1 specifier))
        ((string? specifier) (test-match-name specifier))
        (else
         (error "not a valid test specifier"))))

(define-syntax test-skip
  (syntax-rules ()
    ((test-skip pred ...)
     (let ((runner (test-runner-get)))
       (%test-runner-skip-list! runner
                                  (cons (test-match-all (%test-as-specifier pred)  ...)
                                        (%test-runner-skip-list runner)))))))

(define-syntax test-expect-fail
  (syntax-rules ()
    ((test-expect-fail pred ...)
     (let ((runner (test-runner-get)))
       (%test-runner-fail-list! runner
                                  (cons (test-match-all (%test-as-specifier pred)  ...)
                                        (%test-runner-fail-list runner)))))))

(define (test-match-name name)
  (lambda (runner)
    (equal? name (test-runner-test-name runner))))

(define (test-read-eval-string string)
  (let* ((port (open-input-string string))
         (form (read port)))
    (if (eof-object? (read-char port))
        (eval form)
        "error")))
