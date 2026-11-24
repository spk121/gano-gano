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
;;;; Modernized Frame Module - ECMA-48 Viewport for Character Cell Buffers
;;;
;;; A frame defines a rectangular viewport into a character cell buffer.
;;; Coordinates are in character cells: Latin characters are 1 cell wide,
;;; CJK characters are 2 cells wide, all characters are 1 cell high.
;;;
;;; The frame provides view operations that move the viewport without
;;; changing the active cursor position or buffer content.

(define-module (gano frame)
  #:use-module (gano cbuf-core)     ; Character buffer records
  #:use-module (gano cbuf-basic)    ; Character buffer rendering, positioning
  #:use-module (gano rendering)     ; For make-default-sgr
  #:use-module (gano text-metrics)  ; text-metrics-render-line
  #:use-module (srfi srfi-1)        ; List utilities (for iota)
  #:use-module (srfi srfi-9)        ; Record types
  #:use-module (srfi srfi-11)       ; let-values
  #:use-module (srfi srfi-35)       ; Condition types
  #:export (
    ;; Record type and constructor
    <frame>
    make-frame
    frame?
    
    ;; Field accessors
    frame-width frame-height
    frame-x-start frame-y-start
    frame-left-padding frame-right-padding
    
    ;; Field setters
    set-frame-width! set-frame-height!
    set-frame-x-start! set-frame-y-start!
    set-frame-left-padding! set-frame-right-padding!
    
    ;; ECMA-48 frame operations
    frame-next-page frame-next-page-strict           ; NP
    frame-preceding-page frame-preceding-page-strict ; PP
    frame-scroll-down frame-scroll-down-strict       ; SD
    frame-scroll-up frame-scroll-up-strict           ; SU
    frame-scroll-left frame-scroll-left-strict       ; SL
    frame-scroll-right frame-scroll-right-strict     ; SR
    
    ;; Page positioning
    frame-page-position-absolute frame-page-position-absolute-strict  ; PPA
    frame-page-position-forward frame-page-position-forward-strict    ; PPR
    frame-page-position-backward frame-page-position-backward-strict  ; PPB
    
    ;; ECMA-48 aliases
    frame-ppa frame-ppr frame-ppb
    frame-np frame-pp frame-sd frame-su frame-sl frame-sr
    
    ;; Frame management
    frame-update-frame
    frame-render-frame
    frame-render-frame-with-sgr
    
    ;; Utility functions
    frame-cursor-visible?
    frame-get-cursor-position
    frame-get-visible-line-range
    frame-get-visible-column-range
    frame-compute-page-start
    
    ;; Query predicates
    frame-at-beginning? frame-at-end?
    frame-can-scroll-up? frame-can-scroll-down?
    frame-can-scroll-left? frame-can-scroll-right?
    
    ;; Error conditions
    &frame-beginning-of-buffer frame-beginning-of-buffer?
    &frame-end-of-buffer frame-end-of-buffer?
    &frame-range-error frame-range-error?
    frame-range-error:operation frame-range-error:requested
    frame-range-error:actual frame-range-error:reason))

;;;; Error Conditions (Following CBuf Pattern)

(define-condition-type &frame-range-error &error
  frame-range-error?
  (operation frame-range-error:operation)
  (requested frame-range-error:requested)
  (actual frame-range-error:actual)
  (reason frame-range-error:reason))

(define-condition-type &frame-beginning-of-buffer &frame-range-error
  frame-beginning-of-buffer?)

(define-condition-type &frame-end-of-buffer &frame-range-error
  frame-end-of-buffer?)

;;;; Frame Record Type

(define-record-type <frame>
  (%make-frame width height x-start y-start left-padding right-padding)
  frame?
  (width frame-width set-frame-width!)
  (height frame-height set-frame-height!)
  (x-start frame-x-start set-frame-x-start!)
  (y-start frame-y-start set-frame-y-start!)
  (left-padding frame-left-padding set-frame-left-padding!)
  (right-padding frame-right-padding set-frame-right-padding!))

;;;; Constructor

(define* (make-frame width height #:key (x-start 0) (y-start 0)
                     (left-padding #\$) (right-padding #\$))
  "Create a frame with specified dimensions and optional positioning.
   
   Arguments:
   - width, height: Frame dimensions in character cells
   - x-start, y-start: Top-left corner position (default: 0, 0)
   - left-padding: Character shown when content extends left of frame
   - right-padding: Character shown when content extends right of frame"
  (when (<= width 0)
    (error "Frame width must be positive" width))
  (when (<= height 0)
    (error "Frame height must be positive" height))
  (%make-frame width height x-start y-start left-padding right-padding))

;;;; Helper Functions

(define (frame-raise-boundary-error frame operation target actual boundary-type)
  "Centralized boundary error raising following cbuf pattern"
  (let ([condition-constructor
         (case boundary-type
           [(beginning-of-buffer) &frame-beginning-of-buffer]
           [(end-of-buffer) &frame-end-of-buffer]
           [else &frame-range-error])])
    (raise (condition (condition-constructor
                       (operation operation)
                       (requested target)
                       (actual actual)
                       (reason boundary-type))))))

(define (frame-compute-page-start pos lines-per-page n)
  "Compute the start line of the page N pages away from current position.
   If N is positive, move forward; if negative, move backward.
   Returns the start line of the target page."
  (cond
   [(< n 0)
    ;; Back up n pages, then find page start
    (let* ([current-page (quotient pos lines-per-page)]
           [target-page (+ current-page n)]
           [page-start (* target-page lines-per-page)])
      (max 0 page-start))]
   
   [(= n 0) 
    ;; Current page start
    (* lines-per-page (quotient pos lines-per-page))]
   
   [else
    ;; Advance n pages
    (let* ([current-page (quotient pos lines-per-page)]
           [target-page (+ current-page n)]
           [page-start (* target-page lines-per-page)])
      page-start)]))

;;;; Page Operations

(define* (frame-next-page buf frame n #:key (strict? #f))
  "NP - Move frame to the Nth following page. If strict?, raise error when hitting end."
  (let* ([page-size (cbuf-form-size buf)]
         [current-y (frame-y-start frame)]
         [target-y (frame-compute-page-start current-y page-size n)]
         [max-line (- (cbuf-line-count buf) 1)]
         [last-page-y (frame-compute-page-start max-line page-size 0)]
         [clamped-y (min target-y last-page-y)]
         [clamped? (not (= target-y clamped-y))])
    
    ;; Always perform the movement
    (set-frame-x-start! frame 0)
    (set-frame-y-start! frame clamped-y)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (frame-raise-boundary-error frame 'next-page target-y clamped-y 'end-of-buffer))))

(define (frame-next-page-strict buf frame n)
  "Move frame to next page, raising error if hitting end."
  (frame-next-page buf frame n #:strict? #t))

(define* (frame-preceding-page buf frame n #:key (strict? #f))
  "PP - Move frame to the Nth preceding page. If strict?, raise error when hitting beginning."
  (let* ([page-size (cbuf-form-size buf)]
         [current-y (frame-y-start frame)]
         [target-y (frame-compute-page-start current-y page-size (- n))]
         [clamped-y (max 0 target-y)]
         [clamped? (not (= target-y clamped-y))])
    
    ;; Always perform the movement
    (set-frame-x-start! frame 0)
    (set-frame-y-start! frame clamped-y)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (frame-raise-boundary-error frame 'preceding-page target-y clamped-y 'beginning-of-buffer))))

(define (frame-preceding-page-strict buf frame n)
  "Move frame to preceding page, raising error if hitting beginning."
  (frame-preceding-page buf frame n #:strict? #t))

;;;; Scroll Operations

(define* (frame-scroll-down frame n #:key (strict? #f))
  "SD - Move frame up N line positions (data appears to move down).
   If strict?, raise error when hitting beginning."
  (let* ([current-y (frame-y-start frame)]
         [target-y (- current-y n)]
         [clamped-y (max 0 target-y)]
         [clamped? (not (= target-y clamped-y))])
    
    ;; Always perform the movement
    (set-frame-y-start! frame clamped-y)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (frame-raise-boundary-error frame 'scroll-down target-y clamped-y 'beginning-of-buffer))))

(define (frame-scroll-down-strict frame n)
  "Scroll down, raising error if hitting beginning."
  (frame-scroll-down frame n #:strict? #t))

(define* (frame-scroll-up buf frame n #:key (strict? #f))
  "SU - Move frame down N line positions (data appears to move up).
   If strict?, raise error when hitting end."
  (let* ([current-y (frame-y-start frame)]
         [target-y (+ current-y n)]
         [max-y (max 0 (- (cbuf-line-count buf) (frame-height frame)))]
         [clamped-y (min target-y max-y)]
         [clamped? (not (= target-y clamped-y))])
    
    ;; Always perform the movement
    (set-frame-y-start! frame clamped-y)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (frame-raise-boundary-error frame 'scroll-up target-y clamped-y 'end-of-buffer))))

(define (frame-scroll-up-strict buf frame n)
  "Scroll up, raising error if hitting end."
  (frame-scroll-up buf frame n #:strict? #t))

(define* (frame-scroll-left frame n #:key (strict? #f))
  "SL - Move frame right N cell positions (data appears to move left).
   Note: No upper bound checking - frames can scroll arbitrarily far left."
  (let ([current-x (frame-x-start frame)]
        [target-x (+ (frame-x-start frame) n)])
    (set-frame-x-start! frame target-x)))

(define (frame-scroll-left-strict frame n)
  "Scroll left - same as non-strict since no bounds checking."
  (frame-scroll-left frame n))

(define* (frame-scroll-right frame n #:key (strict? #f))
  "SR - Move frame left N cell positions (data appears to move right).
   If strict?, raise error when hitting left edge."
  (let* ([current-x (frame-x-start frame)]
         [target-x (- current-x n)]
         [clamped-x (max 0 target-x)]
         [clamped? (not (= target-x clamped-x))])
    
    ;; Always perform the movement
    (set-frame-x-start! frame clamped-x)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (frame-raise-boundary-error frame 'scroll-right target-x clamped-x 'beginning-of-buffer))))

(define (frame-scroll-right-strict frame n)
  "Scroll right, raising error if hitting left edge."
  (frame-scroll-right frame n #:strict? #t))

;;;; Absolute Positioning

(define* (frame-page-position-absolute buf frame page #:key (strict? #f))
  "PPA - Move frame to absolute page number. If strict?, raise error when clamping."
  (let* ([page-size (cbuf-form-size buf)]
         [target-y (* page page-size)]
         [max-line (- (cbuf-line-count buf) 1)]
         [clamped-y (max 0 (min target-y max-line))]
         [clamped? (not (= target-y clamped-y))])
    
    ;; Always perform the positioning
    (set-frame-x-start! frame 0)
    (set-frame-y-start! frame clamped-y)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (if (< target-y 0)
          (frame-raise-boundary-error frame 'page-position-absolute target-y clamped-y 'beginning-of-buffer)
          (frame-raise-boundary-error frame 'page-position-absolute target-y clamped-y 'end-of-buffer)))))

(define (frame-page-position-absolute-strict buf frame page)
  "Move to absolute page, raising error on clamping."
  (frame-page-position-absolute buf frame page #:strict? #t))

(define* (frame-page-position-forward buf frame n #:key (strict? #f))
  "PPR - Move frame forward N pages relative to current position."
  (frame-next-page buf frame n #:strict? strict?))

(define (frame-page-position-forward-strict buf frame n)
  "Move forward N pages, raising error on boundary."
  (frame-page-position-forward buf frame n #:strict? #t))

(define* (frame-page-position-backward buf frame n #:key (strict? #f))
  "PPB - Move frame backward N pages relative to current position."
  (frame-preceding-page buf frame n #:strict? strict?))

(define (frame-page-position-backward-strict buf frame n)
  "Move backward N pages, raising error on boundary."
  (frame-page-position-backward buf frame n #:strict? #t))

;;;; ECMA-48 Command Aliases

(define frame-np frame-next-page)
(define frame-pp frame-preceding-page)
(define frame-sd frame-scroll-down)
(define frame-su frame-scroll-up)
(define frame-sl frame-scroll-left)
(define frame-sr frame-scroll-right)
(define frame-ppa frame-page-position-absolute)
(define frame-ppr frame-page-position-forward)
(define frame-ppb frame-page-position-backward)

;;;; Frame Management

(define (frame-update-frame buf frame)
  "Adjust frame so cursor is visible. If cursor is outside frame,
   position cursor 1/3 from appropriate edge for smooth scrolling."
  (let ([x-frame (frame-x-start frame)]
        [y-frame (frame-y-start frame)]
        [height (frame-height frame)]
        [width (frame-width frame)]
        [x-cell (cbuf-x-cell buf)]
        [y (cbuf-line-cur buf)])
    
    ;; Vertical adjustments
    (when (>= y (+ y-frame height))
      (let ([y-frame-target (- y (floor (* 2/3 height)))])
        (set-frame-y-start! frame (max 0 y-frame-target))))
    
    (when (< y y-frame)
      (let ([y-frame-target (- y (floor (* 1/3 height)))])
        (set-frame-y-start! frame (max 0 y-frame-target))))
    
    ;; Horizontal adjustments
    (when (>= x-cell (+ x-frame width))
      (let ([x-frame-target (- x-cell (floor (* 2/3 width)))])
        (set-frame-x-start! frame (max 0 x-frame-target))))
    
    (when (< x-cell x-frame)
      (let ([x-frame-target (- x-cell (floor (* 1/3 width)))])
        (set-frame-x-start! frame (max 0 x-frame-target))))))

;;;; Rendering

;; The rendering functions read each visible line's text metrics
;; directly rather than moving the buffer's cursor onto each line (which
;; would also reset the cursor column to the goal column).

(define (frame-visible-line-metrics buf frame)
  "Return a list of FRAME-HEIGHT entries, one per screen row: the text
   metrics of the buffer line shown there, or #f below the end of the
   buffer."
  (let* ([height (frame-height frame)]
         [all (cbuf-text-metrics buf)]
         [y-frame (frame-y-start frame)]
         [visible (if (< y-frame (length all)) (drop all y-frame) '())])
    (let loop ([i 0] [rest visible] [acc '()])
      (if (= i height)
          (reverse acc)
          (if (null? rest)
              (loop (+ i 1) rest (cons #f acc))
              (loop (+ i 1) (cdr rest) (cons (car rest) acc)))))))

(define* (frame-render-frame buf frame #:key (pad? #t))
  "Render the frame view of the buffer as a list of strings.
   Returns list of strings, one per visible line."
  (let ([x-frame (frame-x-start frame)]
        [width (frame-width frame)])
    (map (lambda (metrics)
           (if metrics
               (let-values ([(str sgr-list)
                             (text-metrics-render-line metrics x-frame width #:pad? pad?)])
                 str)
               (if pad? (make-string width #\space) "")))
         (frame-visible-line-metrics buf frame))))

(define* (frame-render-frame-with-sgr buf frame #:key (pad? #t))
  "Render frame with SGR formatting information.
   Returns list of (string . sgr-list) pairs."
  (let ([x-frame (frame-x-start frame)]
        [width (frame-width frame)])
    (map (lambda (metrics)
           (if metrics
               (let-values ([(str sgr-list)
                             (text-metrics-render-line metrics x-frame width #:pad? pad?)])
                 (cons str sgr-list))
               (cons (make-string width #\space)
                     (make-list width (make-default-sgr)))))
         (frame-visible-line-metrics buf frame))))

;;;; Query Functions

(define (frame-cursor-visible? buf frame)
  "Return #t if the cursor is currently visible in the frame."
  (let ([x-frame (frame-x-start frame)]
        [y-frame (frame-y-start frame)]
        [height (frame-height frame)]
        [width (frame-width frame)]
        [x-cell (cbuf-x-cell buf)]
        [y (cbuf-line-cur buf)])
    
    (and (>= y y-frame)
         (< y (+ y-frame height))
         (>= x-cell x-frame)
         (< x-cell (+ x-frame width)))))

(define (frame-get-cursor-position buf frame)
  "Get cursor position relative to frame. Returns (x . y) or #f if not visible."
  (if (frame-cursor-visible? buf frame)
      (let ([x-cell (cbuf-x-cell buf)]
            [y (cbuf-line-cur buf)]
            [x-frame (frame-x-start frame)]
            [y-frame (frame-y-start frame)])
        (cons (- x-cell x-frame) (- y y-frame)))
      #f))

(define (frame-get-visible-line-range buf frame)
  "Return (start-line . end-line) of lines visible in frame."
  (let ([y-frame (frame-y-start frame)]
        [height (frame-height frame)]
        [line-count (cbuf-line-count buf)])
    (cons y-frame (min (+ y-frame height) line-count))))

(define (frame-get-visible-column-range frame)
  "Return (start-column . end-column) of columns visible in frame."
  (let ([x-frame (frame-x-start frame)]
        [width (frame-width frame)])
    (cons x-frame (+ x-frame width))))

;;;; Predicates Following CBuf Pattern

(define (frame-at-beginning? frame)
  "Return #t if frame is at the top-left origin."
  (and (= (frame-x-start frame) 0)
       (= (frame-y-start frame) 0)))

(define (frame-at-end? buf frame)
  "Return #t if frame is positioned at the end of the buffer."
  (let ([y-frame (frame-y-start frame)]
        [height (frame-height frame)]
        [line-count (cbuf-line-count buf)])
    (>= (+ y-frame height) line-count)))

(define (frame-can-scroll-up? buf frame n)
  "Return #t if frame can scroll up N lines without hitting end."
  (let ([current-y (frame-y-start frame)]
        [height (frame-height frame)]
        [line-count (cbuf-line-count buf)])
    (<= (+ current-y n height) line-count)))

(define (frame-can-scroll-down? frame n)
  "Return #t if frame can scroll down N lines without hitting beginning."
  (>= (- (frame-y-start frame) n) 0))

(define (frame-can-scroll-left? frame n)
  "Return #t if frame can scroll left N columns (always true - no right bound)."
  #t)

(define (frame-can-scroll-right? frame n)
  "Return #t if frame can scroll right N columns without hitting left edge."
  (>= (- (frame-x-start frame) n) 0))

;;;; Range Query Functions

(define (frame-scroll-up-range buf frame)
  "Return maximum lines frame can scroll up."
  (let ([current-y (frame-y-start frame)]
        [height (frame-height frame)]
        [line-count (cbuf-line-count buf)])
    (max 0 (- line-count height current-y))))

(define (frame-scroll-down-range frame)
  "Return maximum lines frame can scroll down."
  (frame-y-start frame))

(define (frame-scroll-right-range frame)
  "Return maximum columns frame can scroll right."
  (frame-x-start frame))

(define (frame-page-count buf)
  "Return total number of pages in buffer."
  (let ([line-count (cbuf-line-count buf)]
        [page-size (cbuf-form-size buf)])
    (ceiling (/ line-count page-size))))

(define (frame-current-page buf frame)
  "Return current page number (0-based)."
  (let ([y-frame (frame-y-start frame)]
        [page-size (cbuf-form-size buf)])
    (quotient y-frame page-size)))
