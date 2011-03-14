;;;; A Character Cell Buffer Frame

;;;; These are functions that define the view of a character cell
;;;; buffer.  The view is a rectangular region defined by the coordinate
;;;; of its top left corner, its width, and its height.  The 'units'
;;;; are character cells: Latin characters are 1 cell wide by 1 cell high;
;;;; Kanji and Hanzi are 2 cells wide by 1 cell high.

;;;; Creating the list of strings that comprise a view from a character-cell
;;;; buffer and a window is here called 'rendering'.

;;;; There are two different renderings.  The regular rendering will
;;;; return a list of strings, where each string is the portion of a
;;;; line of a cbuf that is visible in the window.  The curses rendering is
;;;; a list of lists of complex characters, where a complex character
;;;; is a base character plus possibly some combining marks.

;;;; The commands in this file move the view without changing the active
;;;; data position or the text of the buffer.

;; NP - next page
;; FF - form feed
;; PP - preceding page
;; PPA - page position absolute
;; PPB - page position backward
;; PPR - page position forward
;; SD - scroll down
;; SL - scroll left
;; SPH - set page home
;; SPL - set page limit
;; SR - scroll right
;; SU - scroll up

;; The Old-school R5RS 'class' for the character-cell buffer's frame.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CLASS and PRIMITIVES

(define-condition-type &frame-beginning-of-buffer &condition
  frame-beginning-of-buffer?)
(define-condition-type &frame-end-of-buffer &condition
  frame-end-of-buffer?)

(define FRAME_WIDTH 1)
(define FRAME_HEIGHT 2)
(define FRAME_X_START 3)
(define FRAME_Y_START 4)
(define FRAME_LEFT_PADDING 5)
(define FRAME_RIGHT_PADDING 6)
(define FRAME_LENGTH (+ 1 FRAME_RIGHT_PADDING))

(define (frame-make-frame)
  "Create a frame."
  (let ((frame (make-vector FRAME_LENGTH #f)))
    (vector-set! frame 0 'frame)
    (vector-set! frame FRAME_WIDTH 80)
    (vector-set! frame FRAME_HEIGHT 24)
    (vector-set! frame FRAME_X_START 0)
    (vector-set! frame FRAME_Y_START 0)
    (vector-set! frame FRAME_LEFT_PADDING #\$)
    (vector-set! frame FRAME_RIGHT_PADDING #\$)
    frame))

(define (frame-get-width frame)         (vector-ref frame FRAME_WIDTH))
(define (frame-get-height frame)        (vector-ref frame FRAME_HEIGHT))
(define (frame-get-x-start frame)       (vector-ref frame FRAME_X_START))
(define (frame-get-y-start frame)       (vector-ref frame FRAME_Y_START))
;; Left padding is either #f, or is a character that will be prepended
;; to any line that has characters to the left of the frame.
(define (frame-get-left-padding frame)  (vector-ref frame FRAME_LEFT_PADDING))
;; Right padding is either #f, or is a character that will be appended
;; to any line that has characters to the right of the frame.
(define (frame-get-right-padding frame) (vector-ref frame FRAME_RIGHT_PADDING))

(define (frame-set-width! frame x)       (vector-set! frame FRAME_WIDTH x))
(define (frame-set-height! frame x)      (vector-set! frame FRAME_HEIGHT x))
(define (frame-set-x-start! frame x)     (vector-set! frame FRAME_X_START x))
(define (frame-set-y-start! frame x)     (vector-set! frame FRAME_Y_START x))

(define (frame-compute-page-start pos lines-per-page n)
  "If N is positive, compute the start line of the Nth next page
tabulation.  If N is negative, compute the star lines of the Nth
preceding page.  This function does not do bracketing."
  (cond
   [(< n 0)
    ;; Back up n pages
    (let* ([pp1 (+ pos (* n lines-per-page))]
           ;; Move forward to a page start
           [pp2 (cond
                 [(zero? (remainder pp1 lines-per-page))
                  pp1]
                 [(> pp1 0)
                  (* lines-per-page (+ (quotient pp1 lines-per-page) 1))]
                 [(< pp1 0)
                  (* lines-per-page (quotient pp1 lines-per-page))])])
      pp2)]
   [(>= n 0)
    ;; Advance n pages
    (let* ([pp1 (+ pos (* n lines-per-page))]
           ;; Move backward to the start of a page
           [pp2 (* lines-per-page (quotient pp1 lines-per-page))])
      pp2)]))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; METHODS

;; NP - Next Page
(define (frame-next-page buf frame n)
  "Moves the frame to the Nth following page.  The active data
position is not modified, and the cursor will likely be moved out of
the frame.  Attempting to move the frame past the last page will cause
a frame-end-of-buffer error."
  (let* ([page-size (cbuf-get-page-size buf)]
         [y (frame-get-y-start frame)]
         [new-y (frame-compute-page-start y page-size n)]
         [last-page-y (frame-compute-page-start (cbuf-get-line-count buf) page-size 0)])
    (cond
     [(> new-y last-page-y)
      (frame-set-x-start! frame 0)
      (frame-set-y-start! frame last-page-y)
      (raise (condition (&frame-end-of-buffer)))]
     [else
      (frame-set-x-start! frame 0)
      (frame-set-y-start! frame new-y)])))

;; PP
(define (frame-preceding-page buf frame n)
  "Moves the frame to the Nth preceding page.  The active data position
is not modified, and the cursor will likely be moved out of the frame.
Attempting to move the frame before the beginning of the buffer will
cause a frame-beginning-of-buffer error."
  (let* ([page-size (cbuf-get-page-size buf)]
         [y (frame-get-y-start frame)]
         [new-y (frame-compute-page-start y page-size (- n))])
    (cond
     [(< new-y 0)
      (frame-set-x-start! frame 0)
      (frame-set-y-start! frame 0)
      (raise (condition (&frame-beginning-of-buffer)))]
     [else
      (frame-set-x-start! frame 0)
      (frame-set-y-start! frame new-y)])))

;; SD
(define (frame-scroll-down frame n)
  "Moves the frame up N line positions so that the data appears to
move down.  Attempting to move the frame before the beginning of the buffer
will cause an frame-beginning-of-buffer error."
  (cond
   [(>= (frame-get-y-start frame) n)
    (frame-set-y-start! frame (- (frame-get-y-start frame) n))]
   [else
    (frame-set-y-start! frame 0)
    (raise (condition (&frame-beginning-of-buffer)))]))

;; SL
(define (frame-scroll-left frame n)
  "Moves the frame right N cell positions so that the data appears to
move left."
  (frame-set-x-start! frame (+ (frame-get-x-start frame) n)))

;; SR
(define (frame-scroll-right frame n)
  "Moves the frame left N cell positions so that the data appears to
move right."
  (frame-set-x-start! frame (- (frame-get-x-start frame) n)))

(define (frame-update-frame buf frame)
  "Adjust the frame so that the cursor is present"
  #f)

(define (frame-render-frame buf frame)
  (let ([txt (cbuf-get-text buf)]
        [tabsize (cbuf-get-tab-size buf)]
        [x-frame (frame-get-x-start frame)]
        [y-frame (frame-get-y-start frame)]
        [height (frame-get-height frame)]
        [width (frame-get-width frame)])
    (map (lambda (i)
           (let ([y (+ i y-frame)])
             (if (< y (length txt))
                 (string-render-line (list-ref txt y) tabsize x-frame width)
                 ;; else
                 (make-string width #\space))))

         (iota height))))
