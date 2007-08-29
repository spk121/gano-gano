#!/usr/local/bin/guile \
--debug -s
!#

(read-enable 'positions) 
(debug-enable 'backtrace)

(use-modules (gucu core)
	     (ice-9 pretty-print))

(define test-directory (opendir ".."))

(define test-list '())

(define (begin-test-case)
  (begin
    (clear-all #:window left-window)
    (clear-all #:window right-window)
    (clear-all)
    (vertical-line (acs-vline) #:x (- right-x-start 1))
    (horizontal-line (acs-hline) #:y (- left-y-start 1) #:n (+ 1 left-x-size))
    (refresh)))

(define (end-test-case)
  (begin 
    (add-string "...complete\n" #:window right-window)
    (add-string "Press any key to continue\n" #:window right-window)
    (refresh #:window right-window)
    (get-character)))


(do ((file-name (readdir test-directory)
		(readdir test-directory)))
    ((eof-object? file-name))
  (if (and (string=? (string-take file-name 1) "t")
	   (string=? (string-take-right file-name 4) ".scm"))
      (set! test-list (append test-list (list file-name)))))

(closedir test-directory)

(sort! test-list string<?)

(display "Test drivers found:")
(newline)
(pretty-print test-list)
(sleep 1)

(display "initialize-screen\n")
(usleep 10000)
(initialize-screen)
(refresh)
(usleep 10000)

(add-string (format #f "stdscr ~s\n" *stdscr*))
(refresh)
(usleep 10000)

(add-string "enable-cbreak\n") 
(refresh)
(enable-cbreak)
(usleep 10000)

(add-string "disable-echo\n")
(refresh)
(disable-echo)
(usleep 10000)

(add-string "disable-newline-translation\n")
(refresh)
(disable-newline-translation)
(usleep 10000)

(add-string "enable-flush-on-interrupt\n") 
(refresh) 
(enable-flush-on-interrupt)
(usleep 10000)

(add-string (format #f "~s lines ~s columns~%" (lines) (columns)))
(refresh)
(usleep 10000)

;; Divide the screen into three sections
;; The right window is for status
;; The left window is for testing
;; A bit of the stdscr is not covered at top-left

(define left-x-start 0)
(define left-x-size (- (/ (columns) 2) 2))
(define left-y-start 3)
(define left-y-size (- (lines) left-y-start))
(define left-window (new-window left-y-size left-x-size
				left-y-start left-x-start))
(add-string (format #f "left-window ~s ~%" left-window))
(refresh)
(usleep 10000)

(define right-x-start (+ 1 (/ (columns) 2)))
(define right-x-size (- (/ (columns) 2) 2))
(define right-y-start 0)
(define right-y-size (lines))
(define right-window (new-window right-y-size right-x-size
				 right-y-start right-x-start))
(add-string (format #f "right-window ~s ~%" right-window))
(refresh)
(usleep 10000)



(add-string (format #f "set-scroll-region ~s ~s ~s\n" 
		    0 
		    (- (lines) 1) 
		    right-window))
(refresh)
(set-scroll-region 0 (- (lines) 1) #:window right-window)
(usleep 10000)

(clear-all)
(refresh)

(add-string "enable-scroll\n" #:window right-window)
(refresh #:window right-window)
(enable-scroll #:window right-window)


(add-string "enable-keypad\n" #:window right-window)
(refresh #:window right-window)
(enable-keypad)



(let loop ((test-list test-list))
  (if (not (null? test-list))
      (begin
	(load (car test-list))
	(loop (cdr test-list)))))


(end-window)
