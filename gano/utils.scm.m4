m4_include(`config.m4')

(define-module (gano utils)
  #:use-module (gano chars)
  #:export (
            actual_x
            strlenpt
            strnlenpt
            get_page_start
            ))

;; Return the index in s of the character displayed at the given
;; column, i.e. the largest value such that strnlenpt(s, actual_x(s,
;; column)) <= column.
(define (actual_x s column)
  (let ((i 0)                       ; The position in s
        (len 0))                    ; The screen display width to s[i]
    (while (< i (string-length s))
           (set! len (+ len (char-width (string-ref s i) column)))
           (if (> len column)
               break)
           (set! i (+ i 1)))
    i))

;; Returns the number of cells that the first MAXLEN characters
;; takes up
(define (strnlenpt s maxlen)
  ;; (format #t "s ~a maxlen ~a~%" s maxlen)
  (let loop ((i 0) (width 0))
    ;; (format #t "i ~a width ~a~%" i width)
    (if (< i (min maxlen (string-length s)))
        (begin
          ;; (format #t "i ~a < min(~a,~a) width = ~a~%" i maxlen (string-length s) width)
          (loop (+ i 1) (+ width (char-width (string-ref s i) 0))))
        (begin
          ;; (format #t "i ~a >= min(~a,~a)  width = ~a~%" i maxlen (string-length s) width)
          width))))

;; Returns the number of character cells that the string takes up,
;; with tabs and multicolumn character factored in.
(define (strlenpt s)
  (let loop ((i 0) (width 0))
    (if (< i (string-length s))
        (loop (+ i 1) (+ width (char-width (string-ref s i) 0 )))
        width)))

;; nano scrolls horizontally within a line in chunks.  Return the
;; column number of the first character displayed in the edit window
;; when the cursor is at the given column.  Note that (0 <= column -
;; get_page_start(column) < COLS).
(define (get_page_start column)
  (cond
   ((or (= column 0) (< column (1- (cols))))
    0)
   ((> (cols) 8)
    (+ column -7 (- (remainder (- column 7) (- (cols) 8)))))
   (else
    (- column (- (cols) 2)))))
