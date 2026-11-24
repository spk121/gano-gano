  (define-method (center-frame-line (buf <CBuffer>))
    "Vertically center the frame around the active presentation position"
    (let ([L (- (get-line-cur buf) (floor (/ (get-line-frame-size buf) 2)))])
      (set-line-frame! buf (max 0 L))))

  (define-method (center-frame-position (buf <CBuffer>))
    "Adjust the left hand side of the frame so that the active presentation
position is visible"
    (let ([pp (get-pp-cur buf)]
          [col (get-pp-frame-size buf)])
      (set-pp-frame! buf (cond
                          ((or (= 0 pp) (< pp (1- col)))
                           0)
                          ((> col 8)
                           (+ pp -7 (modulo (- pp 7) (- col 8))))
                          (else
                           (+ pp (- col) 2))))))



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


(define-method (is-position-in-frame? (buf <CBuffer>))
  "Return #t if the active line and presentation position are visible in the
current frame."
  (let* ([pp (get-pp-cur buf)]
         [line (get-line-cur buf)]
         [top (get-line-frame buf)]
         [bottom (+ top (get-line-frame-size buf))]
         [left (get-pp-frame buf)]
         [right (+ left (get-pp-frame-size buf))]
         )
    (and (>= line top) (<= line bottom)
         (>= pp left) (<= pp right))))


(define-method (move-frame-line (buf <CBuffer>))
  "Set the top line of the frame to the be active presentation line"
  (let ([L (get-line-cur buf)])
    (set-line-frame! buf L)))

(define-method (render-frame (buf <CBuffer>))
  "Return a list of strings of the characters that are visible
in the current frame.  Tabs will be converted to spaces.
Lines will be space-padded to contain as many cells as the
frame"
  (let* ([L-size (get-line-frame-size buf)]
         [L-start (get-line-frame buf)]
         [L-end (min (get-line-count buf) (+ L-start L-size))]
         [tabsize (get-tab-size buf)]
         [data-txt (get-text buf)]
         [pp-start (get-pp-frame buf)]
         [pp-size (get-pp-frame-size buf)]
         [frame-txt (make-list L-size (make-string (get-pp-frame-size buf) #\space))])
    (do ([L (max 0 L-start) (1+ L)]) ([>= L L-end])
      (list-set! frame-txt (- L L-start)
                 (render-line (list-ref data-txt L) tabsize pp-start pp-size)))
    frame-txt))

(define-method (scroll-down (buf <CBuffer>) n)
  "Moves the presentation component N line positions such that the
data appear to move down; the active presentation position is not
affected by this control function."
  (set-line-frame! buf (max 0 (- (get-line-frame buf) n))))

(define-method (scroll-left (buf <CBuffer>) n)
  "Causes the presentation component to be moved n character cells
such that the text appears to move to the left"
  #f)

(define-method (scroll-right (buf <CBuffer>) n)
  "Causes the presentation component to be moved n character cells
such that the text appears to move to the right"
    #f)

  (define-method (scroll-up (buf <CBuffer>) n)
    "Moves the presentation component N line positions such that the
data appear to move up; the active presentation position is not
affected by this control function."
    (set-line-frame! buf (min (1- (get-line-count buf)) (- (get-line-frame buf) n))))
