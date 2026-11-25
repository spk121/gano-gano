;;; Gano Screen Module
;;; Screen contents, and the cheapest way to turn one screen into another
;;;
;;; Redrawing the whole screen takes about 2000 bytes for an 80x24
;;; terminal: two seconds at 9600 baud.  This module instead works out a
;;; short list of terminal operations that turns the screen the terminal
;;; is showing into the screen it should show:
;;;
;;;   (screen-update BEFORE AFTER)  =>  list of operations
;;;   (ops->string OPS)             =>  the bytes to send
;;;
;;; and, for a program with one terminal, on top of those:
;;;
;;;   (show-screen SCREEN)   sends what turns the screen last shown
;;;                          into SCREEN
;;;   (redraw-screen)        has the next show-screen redraw everything,
;;;                          for when the terminal no longer shows what
;;;                          was sent (line noise, a resize)
;;;
;;; A screen is a grid of character cells, each with its attributes,
;;; plus the cursor.  Build one with make-screen, screen-put-string! and
;;; screen-set-cursor!; build a new one for every frame (screen-update
;;; keeps no reference to its arguments, but the caller passes this
;;; frame's AFTER as the next frame's BEFORE).
;;;
;;; The cost that is minimized is the number of bytes sent.
;;;
;;; How screen-update works
;;; -----------------------
;;;
;;; It keeps a model of the terminal (cells, cursor, attributes), starts
;;; it as BEFORE, and applies to it every operation it decides to send.
;;; So at each step it knows exactly what the terminal shows, and the
;;; work left is always "model versus AFTER".
;;;
;;; 1. Vertical scrolls.  Rows are hashed.  For each distance d, the
;;;    rows of AFTER that equal the model's row d further down (or up)
;;;    are found; each run of them, and the stretch from the first to
;;;    the last, is a candidate block move.  A candidate is costed as
;;;    scroll bytes + repainting the rows it exposes + fixing the rows
;;;    in the stretch that only nearly match, against repainting the
;;;    region in place.  The best one that saves bytes is applied to the
;;;    model, and the search repeats until nothing saves any more.  (So
;;;    a line inserted in the middle of the screen scrolls just the rows
;;;    below it, and two independent moves are both found.)
;;;
;;; 2. Rows.  Each row that still differs is updated on its own, by
;;;    whichever is cheapest of
;;;      - rewriting the cells that differ, or
;;;      - first deleting or inserting cells (DCH, ICH) so that the rest
;;;        of the row slides into place, then rewriting what differs.
;;;        Typing into or deleting from the middle of a line, and
;;;        scrolling sideways, come out as this.
;;;    When rewriting: a short stretch of unchanged cells between two
;;;    changed ones is rewritten when that is cheaper than moving over
;;;    it; a blank end of row is erased with EL, a blank stretch with
;;;    ECH; a repeated character is sent once and repeated with REP.
;;;
;;; 3. Cursor movement and attributes.  Every move takes the shortest
;;;    of CUP, a relative move (CUU CUD CUF CUB, CHA, VPA) and the
;;;    one-byte controls CR, LF and BS.  Attribute changes take the
;;;    shorter of changing just what differs and resetting first.
;;;
;;; Each step is a minimum over the choices listed, but the steps are
;;; made one after another, so the result is a very good answer rather
;;; than a proven optimum.  (The exact problem contains the travelling
;;; salesman's.)
;;;
;;; Assumptions about the terminal (true of xterm and its relatives)
;;; ----------------------------------------------------------------
;;;
;;;  - Between updates nothing else writes to it, the attributes are
;;;    the default ones and the scroll region is the whole screen.
;;;    screen-update leaves it that way.
;;;  - LF moves straight down (output post-processing is off, as in raw
;;;    mode).  Pass #:lf? #f if it is not.
;;;  - It has REP.  Pass #:rep? #f for one that does not.
;;;  - Character widths are (gano wcwidth)'s.
;;;
;;; Where terminals differ, the model assumes nothing:
;;;  - After writing in the last column the cursor's column is taken as
;;;    unknown; the next move is absolute, or starts with CR.
;;;  - Erasing, inserting, deleting and scrolling are only done with
;;;    default attributes, so it does not matter whether new blank
;;;    cells take the current background colour.
;;;  - Of the blank cells ICH makes, only as many as the cells it moved
;;;    along are trusted; the rest are unknown.  (tmux does not blank
;;;    them.)
;;;  - A cell that loses half of a double-width character is unknown
;;;    until rewritten, and double-width characters are never shifted
;;;    with ICH or DCH.
;;;
;;; Operations
;;; ----------
;;;
;;; Rows and columns in operations are 1-based, as they are sent.
;;;
;;;   (text STRING)        graphic characters
;;;   (rep N)              REP  CSI N b   repeat the last character N times
;;;   (sgr PARAM ...)      SGR  CSI ... m (no parameters: reset)
;;;   (cup ROW COL)        CUP  CSI R;C H
;;;   (cuu N) (cud N)      CUU, CUD       up, down
;;;   (cuf N) (cub N)      CUF, CUB       right, left
;;;   (cha COL) (vpa ROW)  CHA  CSI C G,  VPA  CSI R d
;;;   (cr) (lf) (bs)       the control characters
;;;   (el)                 EL   CSI K     erase to the end of the row
;;;   (ech N)              ECH  CSI N X   erase N cells
;;;   (ich N) (dch N)      ICH  CSI N @,  DCH  CSI N P   insert, delete cells
;;;   (il N) (dl N)        IL   CSI N L,  DL   CSI N M   insert, delete rows
;;;   (su N) (sd N)        SU   CSI N S,  SD   CSI N T   scroll up, down
;;;   (stbm TOP BOTTOM)    DECSTBM CSI T;B r  set the scroll region
;;;   (stbm)               DECSTBM CSI r      scroll region = whole screen
;;;   (ed 2)               ED   CSI 2 J   erase the screen
;;;   (cursor-show) (cursor-hide)         DECTCEM  CSI ? 25 h / l

(define-module (gano screen)
  #:use-module (gano rendering)     ; SGR attributes
  #:use-module (gano wcwidth)       ; Character widths
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-9)        ; Record types
  #:use-module (ice-9 match)
  #:export (make-screen
            screen?
            screen-width
            screen-height
            screen-cursor-row
            screen-cursor-col
            screen-cursor-visible?
            screen-set-cursor!
            screen-put-string!
            screen-row-string
            screen-cell-sgr
            screen-equal?

            screen-update
            screen-update-string
            screen-apply-ops
            ops->string
            ops-byte-count

            show-screen
            redraw-screen))

;;; =================================================================
;;; ATTRIBUTES AS SMALL INTEGERS
;;; =================================================================

;; Cells hold their attributes as an id: equal attributes always get
;; the same id, so cells compare with eq? and rows hash cheaply.  Id 0
;; is the default attributes.  (The table only grows, by one entry per
;; distinct combination of attributes ever shown.)

(define sgr-ids (make-hash-table))        ; ANSI sequence -> id
(define sgr-records (make-vector 64 #f))  ; id -> <sgr>
(define sgr-count 0)

(define (sgr->id sgr)
  (let ([key (sgr->ansi-sequence sgr)])
    (or (hash-ref sgr-ids key)
        (let ([id sgr-count])
          (when (= id (vector-length sgr-records))
            (let ([bigger (make-vector (* 2 id) #f)])
              (vector-move-left! sgr-records 0 id bigger 0)
              (set! sgr-records bigger)))
          (vector-set! sgr-records id (sgr-copy sgr))
          (hash-set! sgr-ids key id)
          (set! sgr-count (+ id 1))
          id))))

(define (id->sgr id) (vector-ref sgr-records id))

(sgr->id (make-default-sgr))            ; id 0

(define sgr-apply-memo (make-hash-table))

(define (sgr-id-apply id params)
  "The attributes a terminal showing ID has after SGR PARAMS"
  (if (null? params)
      0
      (let ([key (cons id params)])
        (or (hash-ref sgr-apply-memo key)
            (let ([new (sgr->id (sgr-apply-parameters! (sgr-copy (id->sgr id)) params))])
              (hash-set! sgr-apply-memo key new)
              new)))))

;;; =================================================================
;;; ROWS OF CELLS
;;; =================================================================

;; A row is two vectors, one entry per cell.
;;   texts: a character; a string (a character and its combining
;;          marks); #f for the right half of a double-width character;
;;          or 'unknown when the model cannot tell what the terminal
;;          shows there.
;;   sgrs:  attribute ids
;; The hash is computed when first asked for, and dropped on change.

(define-record-type <row>
  (%make-row texts sgrs hash)
  row?
  (texts row-texts)
  (sgrs row-sgrs)
  (hash %row-hash set-row-hash!))

(define (make-row width text)
  (%make-row (make-vector width text) (make-vector width 0) #f))

(define (row-copy row)
  (%make-row (vector-copy (row-texts row)) (vector-copy (row-sgrs row)) #f))

(define-inlinable (text=? a b)
  ;; 'unknown equals nothing, itself included
  (cond [(char? a) (eq? a b)]
        [(string? a) (and (string? b) (string=? a b))]
        [(not a) (not b)]
        [else #f]))

(define-inlinable (cell=? xt xs i yt ys j)
  (and (eq? (vector-ref xs i) (vector-ref ys j))
       (text=? (vector-ref xt i) (vector-ref yt j))))

(define-inlinable (blank-cell? texts sgrs j)
  (and (eq? (vector-ref texts j) #\space) (eq? (vector-ref sgrs j) 0)))

(define (row-hash row)
  (or (%row-hash row)
      (let* ([texts (row-texts row)]
             [sgrs (row-sgrs row)]
             [n (vector-length texts)])
        (let loop ([j 0] [h 0])
          (if (= j n)
              (begin (set-row-hash! row h) h)
              (let ([t (vector-ref texts j)])
                (loop (+ j 1)
                      (logand (+ (* h 31)
                                 (* 7919 (vector-ref sgrs j))
                                 (cond [(char? t) (char->integer t)]
                                       [(string? t) (string-hash t 65536)]
                                       [(not t) 1]
                                       [else 2]))
                              #x3ffffff))))))))

(define (rows-equal? x y)
  (or (eq? x y)
      (and (= (row-hash x) (row-hash y))
           (let ([xt (row-texts x)] [xs (row-sgrs x)]
                 [yt (row-texts y)] [ys (row-sgrs y)])
             (let loop ([j (- (vector-length xt) 1)])
               (or (< j 0)
                   (and (cell=? xt xs j yt ys j) (loop (- j 1)))))))))

(define (row-tail-start row)
  "The column from which ROW is blank to its end"
  (let ([texts (row-texts row)] [sgrs (row-sgrs row)])
    (let loop ([e (vector-length texts)])
      (if (and (> e 0) (blank-cell? texts sgrs (- e 1)))
          (loop (- e 1))
          e))))

(define (orphan! texts j value)
  "Cell J of TEXTS is about to be replaced.  If it is half of a
   double-width character, put VALUE in the other half."
  (when (and (not (vector-ref texts j)) (> j 0))
    (vector-set! texts (- j 1) value))
  (when (and (< (+ j 1) (vector-length texts)) (not (vector-ref texts (+ j 1))))
    (vector-set! texts (+ j 1) value)))

;;; Characters

(define-inlinable (ascii-graphic? ch)
  (and (char>=? ch #\space) (char<? ch #\delete)))

(define (char-cells ch cjk?)
  "Cells CH takes: 0 (it joins the character before it), 1 or 2"
  (if (ascii-graphic? ch)
      1
      (let ([w (wcwidth ch cjk?)])
        (cond [(eqv? w 0) 0] [(eqv? w 2) 2] [else 1]))))

(define (char-control? ch)
  (let ([n (char->integer ch)])
    (or (< n 32) (= n 127) (<= #x80 n #x9f))))

(define (text-cells text cjk?)
  (char-cells (if (char? text) text (string-ref text 0)) cjk?))

(define (text-append text ch)
  (string-append (if (char? text) (string text) text) (string ch)))

(define (char-utf8-length ch)
  (let ([n (char->integer ch)])
    (cond [(< n #x80) 1] [(< n #x800) 2] [(< n #x10000) 3] [else 4])))

(define (text-bytes text)
  (cond [(char? text) (char-utf8-length text)]
        [(string? text) (string-fold (lambda (ch n) (+ n (char-utf8-length ch))) 0 text)]
        [else 0]))

;;; =================================================================
;;; SCREENS
;;; =================================================================

(define-record-type <screen>
  (%make-screen width height rows cursor-row cursor-col cursor-visible? cjk?)
  screen?
  (width screen-width)
  (height screen-height)
  (rows screen-rows)
  (cursor-row screen-cursor-row set-screen-cursor-row!)
  (cursor-col screen-cursor-col set-screen-cursor-col!)
  (cursor-visible? screen-cursor-visible? set-screen-cursor-visible?!)
  (cjk? screen-cjk?))

(define* (make-screen width height #:key (cjk? #f))
  "A blank WIDTH x HEIGHT screen with the cursor shown at the top left.
   With #:cjk? #t, East Asian Ambiguous characters are double width."
  (unless (and (exact-integer? width) (exact-integer? height) (> width 0) (> height 0))
    (error "make-screen: width and height must be positive integers" width height))
  (let ([rows (make-vector height #f)])
    (do ([i 0 (+ i 1)]) ((= i height))
      (vector-set! rows i (make-row width #\space)))
    (%make-screen width height rows 0 0 #t cjk?)))

(define* (screen-set-cursor! screen row col #:optional (visible? #t))
  "Put the cursor at ROW, COL (0-based; clamped to the screen), shown
   or hidden."
  (set-screen-cursor-row! screen (max 0 (min row (- (screen-height screen) 1))))
  (set-screen-cursor-col! screen (max 0 (min col (- (screen-width screen) 1))))
  (set-screen-cursor-visible?! screen (and visible? #t)))

(define* (screen-put-string! screen row col str #:optional (sgr #f))
  "Put STR on SCREEN starting at ROW, COL (0-based) and return the
   column after it.  SGR gives the attributes: #f for the default ones,
   an <sgr> for the whole string, or a list with one <sgr> per
   character of STR.  Zero-width characters (combining marks) share the
   cell of the character before them; control characters are shown as
   ?; a double-width character that does not fit, and anything past the
   right edge, is left out."
  (let* ([width (screen-width screen)]
         [cjk? (screen-cjk? screen)]
         [r (vector-ref (screen-rows screen) row)]
         [texts (row-texts r)]
         [sgrs (row-sgrs r)]
         [len (string-length str)]
         [whole (and (sgr? sgr) sgr)]
         [last-sgr #f]                  ; the last <sgr> looked up,
         [last-id 0])                   ; and its id
    (define (id-of s)
      (cond [(not s) 0]
            [(eq? s last-sgr) last-id]
            [else (set! last-sgr s) (set! last-id (sgr->id s)) last-id]))
    (set-row-hash! r #f)
    (let loop ([i 0] [c col] [base #f] [sgr-list (and (pair? sgr) sgr)])
      (if (or (= i len) (>= c width))
          c
          (let* ([ch0 (string-ref str i)]
                 [ch (if (char-control? ch0) #\? ch0)]
                 [id (id-of (if sgr-list (car sgr-list) whole))]
                 [rest (and sgr-list (pair? (cdr sgr-list)) (cdr sgr-list))]
                 [w (char-cells ch cjk?)])
            (cond
             [(= w 0)
              (when base
                (vector-set! texts base (text-append (vector-ref texts base) ch)))
              (loop (+ i 1) c base rest)]
             [(and (= w 2) (>= (+ c 1) width))
              (orphan! texts c #\space)
              (vector-set! texts c #\space)
              (vector-set! sgrs c id)
              (loop (+ i 1) (+ c 1) #f rest)]
             [else
              (orphan! texts c #\space)
              (vector-set! texts c ch)
              (vector-set! sgrs c id)
              (when (= w 2)
                (orphan! texts (+ c 1) #\space)
                (vector-set! texts (+ c 1) #f)
                (vector-set! sgrs (+ c 1) id))
              (loop (+ i 1) (+ c w) c rest)]))))))

(define (text->string text)
  (cond [(char? text) (string text)]
        [(string? text) text]
        [(not text) ""]
        [else "�"]))

(define (screen-row-string screen row)
  "The characters of ROW (0-based) as a string.  A cell whose contents
   are not known (see screen-apply-ops) is shown as U+FFFD."
  (string-concatenate
   (map text->string (vector->list (row-texts (vector-ref (screen-rows screen) row))))))

(define (screen-cell-sgr screen row col)
  "The attributes of the cell at ROW, COL (0-based), as an <sgr>"
  (sgr-copy (id->sgr (vector-ref (row-sgrs (vector-ref (screen-rows screen) row)) col))))

(define (screen-equal? a b)
  "True if screens A and B show the same thing: the same cells, and the
   cursor in the same place and state."
  (and (= (screen-width a) (screen-width b))
       (= (screen-height a) (screen-height b))
       (= (screen-cursor-row a) (screen-cursor-row b))
       (= (screen-cursor-col a) (screen-cursor-col b))
       (eq? (screen-cursor-visible? a) (screen-cursor-visible? b))
       (let loop ([i (- (screen-height a) 1)])
         (or (< i 0)
             (and (rows-equal? (vector-ref (screen-rows a) i) (vector-ref (screen-rows b) i))
                  (loop (- i 1)))))))

;;; =================================================================
;;; OPERATIONS: SIZE AND ENCODING
;;; =================================================================

(define (digits n)
  (cond [(< n 10) 1] [(< n 100) 2] [(< n 1000) 3] [else (string-length (number->string n))]))

(define (csi-n-bytes n)
  "Bytes of CSI N <final>, where an N of 1 is left out"
  (if (= n 1) 3 (+ 3 (digits n))))

(define (op-bytes op)
  (match op
    [('text str) (text-bytes str)]
    [((or 'cr 'lf 'bs)) 1]
    [((or 'rep 'cuu 'cud 'cuf 'cub 'cha 'vpa 'ech 'ich 'dch 'il 'dl 'su 'sd) n) (csi-n-bytes n)]
    [('cup row col)
     (cond [(> col 1) (+ 4 (digits row) (digits col))]
           [(> row 1) (+ 3 (digits row))]
           [else 3])]
    [('sgr) 3]
    [('sgr . params) (+ 2 (length params) (fold (lambda (p n) (+ n (digits p))) 0 params))]
    [('el) 3]
    [('ed 2) 4]
    [('stbm) 3]
    [('stbm top bottom) (+ 4 (digits top) (digits bottom))]
    [((or 'cursor-show 'cursor-hide)) 6]
    [_ (error "screen: unknown operation" op)]))

(define (ops-byte-count ops)
  "The number of bytes OPS take when sent (as UTF-8)"
  (fold (lambda (op n) (+ n (op-bytes op))) 0 ops))

(define (write-op op port)
  (define (csi n final)
    (display "\x1b[" port)
    (unless (= n 1) (display n port))
    (display final port))
  (match op
    [('text str) (display str port)]
    [('cr) (write-char #\return port)]
    [('lf) (write-char #\newline port)]
    [('bs) (write-char #\backspace port)]
    [('rep n) (csi n "b")]
    [('cuu n) (csi n "A")]
    [('cud n) (csi n "B")]
    [('cuf n) (csi n "C")]
    [('cub n) (csi n "D")]
    [('cha n) (csi n "G")]
    [('vpa n) (csi n "d")]
    [('ech n) (csi n "X")]
    [('ich n) (csi n "@")]
    [('dch n) (csi n "P")]
    [('il n) (csi n "L")]
    [('dl n) (csi n "M")]
    [('su n) (csi n "S")]
    [('sd n) (csi n "T")]
    [('cup row col)
     (display "\x1b[" port)
     (when (or (> row 1) (> col 1)) (display row port))
     (when (> col 1) (display ";" port) (display col port))
     (display "H" port)]
    [('sgr . params)
     (display "\x1b[" port)
     (display (string-join (map number->string params) ";") port)
     (display "m" port)]
    [('el) (display "\x1b[K" port)]
    [('ed 2) (display "\x1b[2J" port)]
    [('stbm) (display "\x1b[r" port)]
    [('stbm top bottom)
     (display "\x1b[" port) (display top port)
     (display ";" port) (display bottom port)
     (display "r" port)]
    [('cursor-show) (display "\x1b[?25h" port)]
    [('cursor-hide) (display "\x1b[?25l" port)]
    [_ (error "screen: unknown operation" op)]))

(define (ops->string ops)
  "The characters to send to the terminal to carry out OPS"
  (call-with-output-string
    (lambda (port)
      (for-each (lambda (op) (write-op op port)) ops))))

;;; =================================================================
;;; THE TERMINAL MODEL
;;; =================================================================

;; What the terminal shows and the state it is in.  Rows are shared
;; with the screen the model was made from until they are written to
;; (OWNED says which rows are the model's own).
;;
;; COL-UNKNOWN? is set after a character is written in the last column:
;; terminals differ in where they then say the cursor is, though they
;; agree that the next character wraps.
;;
;; The last three fields belong to screen-update: its options, and the
;; operations sent so far (newest first) with their size in bytes.

(define-record-type <term>
  (%make-term width height rows owned row col col-unknown? sgr visible?
              top bottom last cjk? rep? lf? ops bytes)
  term?
  (width term-width)
  (height term-height)
  (rows term-rows)
  (owned term-owned)
  (row term-row set-term-row!)
  (col term-col set-term-col!)
  (col-unknown? term-col-unknown? set-term-col-unknown?!)
  (sgr term-sgr set-term-sgr!)
  (visible? term-visible? set-term-visible?!)
  (top term-top set-term-top!)             ; scroll region, 0-based,
  (bottom term-bottom set-term-bottom!)    ; inclusive
  (last term-last set-term-last!)          ; last character written, for REP
  (cjk? term-cjk?)
  (rep? term-rep?)
  (lf? term-lf?)
  (ops term-ops set-term-ops!)
  (bytes term-bytes set-term-bytes!))

(define* (screen->term screen #:key (rep? #t) (lf? #t))
  (let ([height (screen-height screen)])
    (%make-term (screen-width screen) height
                (vector-copy (screen-rows screen)) (make-vector height #f)
                (screen-cursor-row screen) (screen-cursor-col screen) #f
                0 (screen-cursor-visible? screen)
                0 (- height 1) #f (screen-cjk? screen) rep? lf? '() 0)))

(define (term->screen t)
  (let ([rows (vector-copy (term-rows t))])
    (do ([i 0 (+ i 1)]) ((= i (vector-length rows)))
      (vector-set! rows i (row-copy (vector-ref rows i))))
    (%make-screen (term-width t) (term-height t) rows
                  (term-row t) (term-col t) (term-visible? t) (term-cjk? t))))

(define (term-row-ref t r) (vector-ref (term-rows t) r))

(define (term-row! t r)
  "Row R of T, for writing to"
  (let ([row (term-row-ref t r)])
    (if (vector-ref (term-owned t) r)
        (begin (set-row-hash! row #f) row)
        (let ([copy (row-copy row)])
          (vector-set! (term-rows t) r copy)
          (vector-set! (term-owned t) r #t)
          copy))))

(define (erased-text t)
  ;; What an erased cell holds.  With non-default attributes that
  ;; depends on the terminal (background colour erase).
  (if (eq? (term-sgr t) 0) #\space 'unknown))

(define (term-scroll! t top bottom n up?)
  "Move rows TOP .. BOTTOM of T up or down N rows; blank rows come in."
  (let* ([rows (term-rows t)]
         [owned (term-owned t)]
         [n (min n (+ 1 (- bottom top)))])
    (define (move! to from)
      (vector-set! rows to (vector-ref rows from))
      (vector-set! owned to (vector-ref owned from)))
    (define (blank! i)
      (vector-set! rows i (make-row (term-width t) (erased-text t)))
      (vector-set! owned i #t))
    (if up?
        (begin
          (do ([i top (+ i 1)]) ((> (+ i n) bottom)) (move! i (+ i n)))
          (do ([i (+ 1 (- bottom n)) (+ i 1)]) ((> i bottom)) (blank! i)))
        (begin
          (do ([i bottom (- i 1)]) ((< (- i n) top)) (move! i (- i n)))
          (do ([i top (+ i 1)]) ((= i (+ top n))) (blank! i))))))

(define (term-erase! t r from to)
  "Erase cells FROM .. TO - 1 of row R"
  (when (< from to)
    (let* ([row (term-row! t r)]
           [texts (row-texts row)]
           [sgrs (row-sgrs row)]
           [text (erased-text t)])
      (orphan! texts from 'unknown)
      (orphan! texts (- to 1) 'unknown)
      (do ([j from (+ j 1)]) ((= j to))
        (vector-set! texts j text)
        (vector-set! sgrs j 0)))))

(define (term-shift! t r col n insert?)
  "Insert N blank cells at COL of row R, or delete N cells there"
  (let* ([width (term-width t)]
         [n (min n (- width col))]
         [row (term-row! t r)]
         [texts (row-texts row)]
         [sgrs (row-sgrs row)]
         [text (erased-text t)]
         [wide? (let loop ([j col])
                  (and (< j width) (or (not (vector-ref texts j)) (loop (+ j 1)))))])
    (if wide?
        ;; Terminals differ on double-width characters cut by a shift
        (begin
          (orphan! texts col 'unknown)
          (do ([j col (+ j 1)]) ((= j width)) (vector-set! texts j 'unknown)))
        (if insert?
            (begin
              (do ([j (- width 1) (- j 1)]) ((< (- j n) col))
                (vector-set! texts j (vector-ref texts (- j n)))
                (vector-set! sgrs j (vector-ref sgrs (- j n))))
              ;; The new cells are blank.  But when more cells are
              ;; inserted than there are cells to move along, tmux
              ;; (3.4) leaves old text in those past the moved ones.
              (do ([j col (+ j 1)]) ((= j (+ col n)))
                (vector-set! texts j (if (< j (- width n)) text 'unknown))
                (vector-set! sgrs j 0)))
            (begin
              (do ([j col (+ j 1)]) ((>= (+ j n) width))
                (vector-set! texts j (vector-ref texts (+ j n)))
                (vector-set! sgrs j (vector-ref sgrs (+ j n))))
              (do ([j (- width n) (+ j 1)]) ((= j width))
                (vector-set! texts j text)
                (vector-set! sgrs j 0)))))))

(define (term-line-feed! t)
  (cond [(= (term-row t) (term-bottom t))
         (term-scroll! t (term-top t) (term-bottom t) 1 #t)]
        [(< (term-row t) (- (term-height t) 1))
         (set-term-row! t (+ (term-row t) 1))]))

(define (term-put! t text)
  "Write one character (with its combining marks) at the cursor"
  (let ([width (term-width t)]
        [w (text-cells text (term-cjk? t))])
    (when (or (term-col-unknown? t) (> (+ (term-col t) w) width))
      (set-term-col! t 0)               ; wrap
      (set-term-col-unknown?! t #f)
      (term-line-feed! t))
    (let* ([row (term-row! t (term-row t))]
           [texts (row-texts row)]
           [sgrs (row-sgrs row)]
           [c (term-col t)])
      (orphan! texts c 'unknown)
      (vector-set! texts c text)
      (vector-set! sgrs c (term-sgr t))
      (when (and (= w 2) (< (+ c 1) width))
        (orphan! texts (+ c 1) 'unknown)
        (vector-set! texts (+ c 1) #f)
        (vector-set! sgrs (+ c 1) (term-sgr t)))
      (set-term-last! t text)
      (if (>= (+ c w) width)
          (begin (set-term-col! t (- width 1))
                 (set-term-col-unknown?! t #t))
          (set-term-col! t (+ c w))))))

(define (term-write! t str)
  (let ([len (string-length str)]
        [cjk? (term-cjk? t)])
    (let loop ([i 0])
      (when (< i len)
        ;; a character and the zero-width characters after it
        (let end ([j (+ i 1)])
          (if (and (< j len) (= 0 (char-cells (string-ref str j) cjk?)))
              (end (+ j 1))
              (begin
                (unless (= 0 (char-cells (string-ref str i) cjk?))
                  (term-put! t (if (= j (+ i 1)) (string-ref str i) (substring str i j))))
                (loop j))))))))

(define (term-goto! t row col)
  (set-term-row! t (max 0 (min row (- (term-height t) 1))))
  (set-term-col! t (max 0 (min col (- (term-width t) 1))))
  (set-term-col-unknown?! t #f))

(define (apply-op! t op)
  "Do to the model T what OP does to a terminal."
  (match op
    [('text str) (term-write! t str)]
    [('rep n)
     (let ([last (term-last t)])
       (when last
         (do ([i 0 (+ i 1)]) ((= i n)) (term-put! t last))))]
    [('sgr . params) (set-term-sgr! t (sgr-id-apply (term-sgr t) params))]
    [('cup row col) (term-goto! t (- row 1) (- col 1))]
    [('cuu n)
     (let ([limit (if (>= (term-row t) (term-top t)) (term-top t) 0)])
       (term-goto! t (max limit (- (term-row t) n)) (term-col t)))]
    [('cud n)
     (let ([limit (if (<= (term-row t) (term-bottom t)) (term-bottom t) (- (term-height t) 1))])
       (term-goto! t (min limit (+ (term-row t) n)) (term-col t)))]
    [('cuf n) (term-goto! t (term-row t) (+ (term-col t) n))]
    [('cub n) (term-goto! t (term-row t) (- (term-col t) n))]
    [('cha col) (term-goto! t (term-row t) (- col 1))]
    [('vpa row) (term-goto! t (- row 1) (term-col t))]
    [('cr) (term-goto! t (term-row t) 0)]
    [('bs) (term-goto! t (term-row t) (- (term-col t) 1))]
    [('lf) (term-line-feed! t)]
    [('el) (term-erase! t (term-row t) (term-col t) (term-width t))]
    [('ech n) (term-erase! t (term-row t) (term-col t) (min (term-width t) (+ (term-col t) n)))]
    [('ich n) (term-shift! t (term-row t) (term-col t) n #t)]
    [('dch n) (term-shift! t (term-row t) (term-col t) n #f)]
    [('il n)
     (when (<= (term-top t) (term-row t) (term-bottom t))
       (term-scroll! t (term-row t) (term-bottom t) n #f)
       (term-goto! t (term-row t) 0))]
    [('dl n)
     (when (<= (term-top t) (term-row t) (term-bottom t))
       (term-scroll! t (term-row t) (term-bottom t) n #t)
       (term-goto! t (term-row t) 0))]
    [('su n) (term-scroll! t (term-top t) (term-bottom t) n #t)]
    [('sd n) (term-scroll! t (term-top t) (term-bottom t) n #f)]
    [('stbm)
     (set-term-top! t 0)
     (set-term-bottom! t (- (term-height t) 1))
     (term-goto! t 0 0)]
    [('stbm top bottom)
     (when (and (< 0 top bottom) (<= bottom (term-height t)))
       (set-term-top! t (- top 1))
       (set-term-bottom! t (- bottom 1))
       (term-goto! t 0 0))]
    [('ed 2)
     (do ([r 0 (+ r 1)]) ((= r (term-height t)))
       (term-erase! t r 0 (term-width t)))]
    [('cursor-show) (set-term-visible?! t #t)]
    [('cursor-hide) (set-term-visible?! t #f)]
    [_ (error "screen: unknown operation" op)]))

(define (screen-apply-ops screen ops)
  "The screen a terminal showing SCREEN shows after OPS: a model of
   how xterm carries out the operations screen-update produces.  SCREEN
   is not changed.  Where terminals differ, the cell is left unknown,
   and equal to nothing (screen-equal?)."
  (let ([t (screen->term screen)])
    (for-each (lambda (op) (apply-op! t op)) ops)
    (term->screen t)))

;;; =================================================================
;;; SENDING OPERATIONS
;;; =================================================================

(define (emit! t op)
  (apply-op! t op)
  (set-term-ops! t (cons op (term-ops t)))
  (set-term-bytes! t (+ (term-bytes t) (op-bytes op))))

(define (emit-all! t ops)
  (for-each (lambda (op) (emit! t op)) ops))

(define (shortest a b)
  "Whichever of the operation lists A and B is fewer bytes"
  (if (<= (ops-byte-count a) (ops-byte-count b)) a b))

;;; Attributes

(define sgr-transition-memo (make-hash-table))

(define (sgr-transition from to)
  "The shortest SGR parameters that change attributes FROM into TO"
  (if (eq? to 0)
      '()                               ; CSI m: nothing is shorter
      (let ([key (cons from to)])
        (or (hash-ref sgr-transition-memo key)
            (let* ([change (sgr-parameter-list (id->sgr to) (id->sgr from))]
                   [reset (cons 0 (sgr-parameter-list (id->sgr to) #f))]
                   [params (if (<= (op-bytes (cons 'sgr change)) (op-bytes (cons 'sgr reset)))
                               change
                               reset)])
              (hash-set! sgr-transition-memo key params)
              params)))))

(define (set-sgr! t id)
  (unless (eq? id (term-sgr t))
    (emit! t (cons 'sgr (sgr-transition (term-sgr t) id)))))

;;; Cursor movement

(define (vertical-ops t from to)
  (let ([d (- to from)])
    (cond [(= d 0) '()]
          [(< d 0) (shortest `((cuu ,(- d))) `((vpa ,(+ to 1))))]
          ;; LF scrolls at the bottom of the scroll region, but a move
          ;; down never starts there
          [(and (term-lf? t) (<= d 3) (= (term-bottom t) (- (term-height t) 1)))
           (make-list d '(lf))]
          [else (shortest `((cud ,d)) `((vpa ,(+ to 1))))])))

(define (horizontal-ops from to)
  (let ([d (- to from)])
    (cond [(= d 0) '()]
          [(= to 0) '((cr))]
          [(>= d -3 ) (if (< d 0)
                          (make-list (- d) '(bs))
                          (shortest `((cuf ,d)) `((cha ,(+ to 1)))))]
          [else (shortest `((cub ,(- d))) `((cha ,(+ to 1))))])))

(define (move! t row col)
  "Move the cursor to ROW, COL (0-based) the cheapest way."
  (unless (and (= row (term-row t)) (= col (term-col t)) (not (term-col-unknown? t)))
    (emit-all! t (shortest
                  (if (term-col-unknown? t)
                      (append '((cr)) (vertical-ops t (term-row t) row) (horizontal-ops 0 col))
                      (append (vertical-ops t (term-row t) row)
                              (horizontal-ops (term-col t) col)))
                  `((cup ,(+ row 1) ,(+ col 1)))))))

;;; =================================================================
;;; UPDATING ONE ROW
;;; =================================================================

(define (cells->string cells)
  (if (every char? cells)
      (list->string cells)
      (string-concatenate (map text->string cells))))

(define (write-cells! t y from to)
  "With the cursor at column FROM of a row, write cells FROM .. TO of
   the row Y there."
  (let ([yt (row-texts y)]
        [ys (row-sgrs y)]
        [pending '()]                   ; cells not yet sent, newest first
        [pending-sgr 0])
    (define (flush!)
      (when (pair? pending)
        (set-sgr! t pending-sgr)
        (emit! t (list 'text (cells->string (reverse pending))))
        (set! pending '())))
    (define (run-length j)
      ;; cells from J on that are the same single-width character
      (let ([text (vector-ref yt j)] [sgr (vector-ref ys j)])
        (let loop ([k (+ j 1)])
          (if (and (<= k to) (eq? (vector-ref yt k) text) (eq? (vector-ref ys k) sgr))
              (loop (+ k 1))
              (- k j)))))
    (let loop ([j from])
      (if (> j to)
          (flush!)
          (let ([text (vector-ref yt j)]
                [sgr (vector-ref ys j)])
            (if (not text)
                (loop (+ j 1))          ; right half: sent with the left
                (let* ([n (if (char? text) (run-length j) 1)]
                       [plain (* n (text-bytes text))]
                       [rep (and (term-rep? t) (>= n 3)
                                 (+ (text-bytes text) (csi-n-bytes (- n 1))))]
                       ;; Erasing leaves the cursor where it was
                       [ech (and (>= n 3) (blank-cell? yt ys j)
                                 (+ (csi-n-bytes n)
                                    (if (= (+ j n -1) to) 0 (csi-n-bytes n))))])
                  (cond
                   [(and ech (< ech plain) (or (not rep) (<= ech rep)))
                    (flush!)
                    (set-sgr! t 0)
                    (emit! t `(ech ,n))
                    (unless (= (+ j n -1) to) (emit! t `(cuf ,n)))
                    (loop (+ j n))]
                   [(and rep (< rep plain))
                    (flush!)
                    (set-sgr! t sgr)
                    (emit! t `(text ,(string text)))
                    (emit! t `(rep ,(- n 1)))
                    (loop (+ j n))]
                   [else
                    (unless (eq? sgr pending-sgr) (flush!))
                    (set! pending-sgr sgr)
                    (set! pending (append (make-list n text) pending))
                    (loop (+ j n))]))))))))

(define (rewrite! t r y)
  "Make row R of T equal to the row Y by rewriting or erasing cells."
  (let* ([width (term-width t)]
         [x (term-row-ref t r)]
         [xt (row-texts x)] [xs (row-sgrs x)]
         [yt (row-texts y)] [ys (row-sgrs y)]
         [dirty (make-vector width #f)]
         [tail (row-tail-start y)]
         [el-at #f])
    (do ([j 0 (+ j 1)]) ((= j width))
      (unless (cell=? xt xs j yt ys j) (vector-set! dirty j #t)))
    ;; Both halves of a double-width character are written together
    (do ([j (- width 1) (- j 1)]) ((< j 1))
      (when (and (vector-ref dirty j) (not (vector-ref yt j)))
        (vector-set! dirty (- j 1) #t)))
    (do ([j 0 (+ j 1)]) ((>= (+ j 1) width))
      (when (and (vector-ref dirty j) (not (vector-ref yt (+ j 1))))
        (vector-set! dirty (+ j 1) #t)))
    ;; A blank end of row with enough wrong in it is erased in one go
    (let loop ([j tail] [count 0] [first #f])
      (if (< j width)
          (if (vector-ref dirty j)
              (loop (+ j 1) (+ count 1) (or first j))
              (loop (+ j 1) count first))
          (when (>= count 4)
            (set! el-at first)
            (do ([j first (+ j 1)]) ((= j width)) (vector-set! dirty j #f)))))
    ;; Unchanged cells between two changed ones are rewritten when
    ;; that takes no more bytes than moving the cursor over them
    (let loop ([j 0] [last #f])
      (when (< j width)
        (if (vector-ref dirty j)
            (begin
              (when (and last (> (- j last) 1))
                (let ([gap (- j last 1)]
                      [sgr (vector-ref ys j)])
                  (let scan ([k (+ last 1)] [bytes 0])
                    (if (= k j)
                        (when (and (eq? sgr (vector-ref ys last))
                                   (<= bytes (csi-n-bytes gap)))
                          (do ([k (+ last 1) (+ k 1)]) ((= k j)) (vector-set! dirty k #t)))
                        (when (eq? sgr (vector-ref ys k))
                          (scan (+ k 1) (+ bytes (text-bytes (vector-ref yt k)))))))))
              (loop (+ j 1) j))
            (loop (+ j 1) last))))
    ;; Write each stretch of changed cells
    (let loop ([j 0])
      (when (< j width)
        (if (vector-ref dirty j)
            (let end ([k j])
              (if (and (< (+ k 1) width) (vector-ref dirty (+ k 1)))
                  (end (+ k 1))
                  (begin
                    (move! t r j)
                    (write-cells! t y j k)
                    (loop (+ k 1)))))
            (loop (+ j 1)))))
    (when el-at
      (set-sgr! t 0)
      ;; anywhere from the start of the blank end to its first wrong cell
      (unless (and (= (term-row t) r) (not (term-col-unknown? t))
                   (<= tail (term-col t) el-at))
        (move! t r el-at))
      (emit! t '(el)))))

(define (shift-candidates t r y)
  "Ways to slide part of row R of T sideways that bring many of its
   cells to where the row Y has them: a list of (dch COL N) and
   (ich COL N), at most one of each."
  (let* ([width (term-width t)]
         [x (term-row-ref t r)]
         [xt (row-texts x)] [xs (row-sgrs x)]
         [yt (row-texts y)] [ys (row-sgrs y)]
         [p (let loop ([j 0])           ; first and last cell that differ
              (and (< j width) (if (cell=? xt xs j yt ys j) (loop (+ j 1)) j)))]
         [q (and p (let loop ([j (- width 1)])
                     (if (cell=? xt xs j yt ys j) (loop (- j 1)) j)))])
    (define (matches from to offset)
      ;; cells J of Y in FROM .. TO - 1 equal to cell J + OFFSET of X
      (let loop ([j from] [n 0])
        (if (>= j to)
            n
            (loop (+ j 1) (if (cell=? xt xs (+ j offset) yt ys j) (+ n 1) n)))))
    (define (best-shift insert? at)
      ;; Try the first few distances at which the two cells at AT line
      ;; up with two of the other row; return (MATCHES . N) for the
      ;; best, or #f
      (let loop ([n 1] [tries 0] [best #f])
        (if (or (>= (+ at n 1) width) (= tries 6))
            best
            (if (if insert?
                    (and (cell=? xt xs at yt ys (+ at n))
                         (cell=? xt xs (+ at 1) yt ys (+ at n 1)))
                    (and (cell=? xt xs (+ at n) yt ys at)
                         (cell=? xt xs (+ at n 1) yt ys (+ at 1))))
                (let ([m (if insert?
                             (matches (+ p n) width (- n))
                             (matches p (- width n) n))])
                  (loop (+ n 1) (+ tries 1) (if (or (not best) (> m (car best))) (cons m n) best)))
                (loop (+ n 1) tries best)))))
    (define (best-of a b)
      (if (and a b) (if (>= (car a) (car b)) a b) (or a b)))
    (define (shift insert?)
      ;; Lining up at the first cell that differs finds text that
      ;; slid; a little further on, text that slid and changed there
      (best-of (best-shift insert? p) (best-shift insert? (+ p 4))))
    (if (and p (>= (- q p) 6)
             ;; no double-width or unknown cells from P on
             (let loop ([j p])
               (or (= j width)
                   (and (let ([text (vector-ref xt j)]) (or (char? text) (string? text)))
                        (loop (+ j 1)))))
             (vector-ref yt p))
        (let ([in-place (matches p width 0)]
              [delete (shift #f)]
              [insert (shift #t)])
          (append (if (and delete (> (car delete) (+ in-place 4))) `((dch ,p ,(cdr delete))) '())
                  (if (and insert (> (car insert) (+ in-place 4))) `((ich ,p ,(cdr insert))) '())))
        '())))

(define (update-row! t r y)
  "Make row R of T equal to the row Y, the cheapest way found."
  (define (run! shift)
    (match shift
      [#f #t]
      [(op col n)
       (move! t r col)
       (set-sgr! t 0)
       (emit! t (list op n))])
    (rewrite! t r y)
    (term-bytes t))
  (let ([candidates (shift-candidates t r y)])
    (if (null? candidates)
        (run! #f)
        ;; Try each on the model, undo it, and redo the best
        (let* ([owned? (vector-ref (term-owned t) r)]
               [row (if owned? (row-copy (term-row-ref t r)) (term-row-ref t r))]
               [state (list (term-row t) (term-col t) (term-col-unknown? t) (term-sgr t)
                            (term-last t) (term-ops t) (term-bytes t))]
               [restore! (lambda ()
                           (vector-set! (term-rows t) r (if owned? (row-copy row) row))
                           (vector-set! (term-owned t) r owned?)
                           (match state
                             [(row col col-unknown? sgr last ops bytes)
                              (set-term-row! t row)
                              (set-term-col! t col)
                              (set-term-col-unknown?! t col-unknown?)
                              (set-term-sgr! t sgr)
                              (set-term-last! t last)
                              (set-term-ops! t ops)
                              (set-term-bytes! t bytes)]))])
          (let loop ([shifts (cons #f candidates)] [best #f] [best-bytes #f])
            (if (null? shifts)
                (run! best)
                (let ([bytes (run! (car shifts))])
                  (restore!)
                  (if (or (not best-bytes) (< bytes best-bytes))
                      (loop (cdr shifts) (car shifts) bytes)
                      (loop (cdr shifts) best best-bytes)))))))))

;;; =================================================================
;;; VERTICAL SCROLLS
;;; =================================================================

(define (row-distance x y y-tail)
  "An estimate of the bytes it takes to turn row X into row Y, whose
   blank end starts at column Y-TAIL"
  (if (rows-equal? x y)
      0
      (let ([xt (row-texts x)] [xs (row-sgrs x)]
            [yt (row-texts y)] [ys (row-sgrs y)])
        (let loop ([j (- (vector-length xt) 1)] [body 0] [tail 0])
          (cond [(< j 0) (+ 3 body (min tail 3))]   ; a move; EL at worst
                [(cell=? xt xs j yt ys j) (loop (- j 1) body tail)]
                [(< j y-tail) (loop (- j 1) (+ body 1) tail)]
                [else (loop (- j 1) body (+ tail 1))])))))

(define (scroll! t top bottom n up?)
  "Send what scrolls rows TOP .. BOTTOM (0-based) of the terminal up or
   down N rows."
  (let ([last (- (term-height t) 1)])
    (set-sgr! t 0)                      ; so the new rows are plain blanks
    (cond
     [(and (= top 0) (= bottom last))
      (emit! t (if up? `(su ,n) `(sd ,n)))]
     ;; Down to the last row: delete or insert rows at the top
     [(= bottom last)
      (move! t top 0)
      (emit! t (if up? `(dl ,n) `(il ,n)))]
     [else
      (emit! t `(stbm ,(+ top 1) ,(+ bottom 1)))
      (emit! t (if up? `(su ,n) `(sd ,n)))
      (emit! t '(stbm))])))

(define (scroll-cost t top bottom)
  (let ([last (- (term-height t) 1)])
    (cond [(and (= top 0) (= bottom last)) 4]
          [(= bottom last) 9]
          [else 14])))

(define (scroll-rows! t after)
  "Scroll parts of T wherever that brings rows to where the screen
   AFTER has them and saves bytes."
  (let* ([height (term-height t)]
         [target (screen-rows after)]
         [blank (make-row (term-width t) #\space)]
         [tails (vector-map-index (lambda (i row) (row-tail-start row)) target)]
         [blank? (vector-map-index (lambda (i e) (= e 0)) tails)]
         [distance (lambda (x i) (row-distance x (vector-ref target i) (vector-ref tails i)))]
         ;; bytes to paint each row of AFTER on a blank row, and on the
         ;; row the terminal has there now
         [paint (vector-map-index (lambda (i row) (distance blank i)) target)]
         [in-place (make-vector height 0)])
    (define (refresh! from to)
      (do ([i from (+ i 1)]) ((> i to))
        (vector-set! in-place i (distance (term-row-ref t i) i))))
    (define (sum v from to)
      (let loop ([i from] [n 0])
        (if (> i to) n (loop (+ i 1) (+ n (vector-ref v i))))))
    (define (match? i d)
      ;; AFTER's row I is what the terminal has D rows further down
      (and (not (vector-ref blank? i))
           (rows-equal? (term-row-ref t (+ i d)) (vector-ref target i))))
    (define (candidate a b d)
      ;; Moving the rows that become A .. B of AFTER by D:
      ;; (SAVING TOP BOTTOM N UP?)
      (let* ([up? (> d 0)]
             [n (abs d)]
             [top (if up? a (- a n))]
             [bottom (if up? (+ b d) b)]
             [exposed (if up? (sum paint (+ b 1) bottom) (sum paint top (- a 1)))]
             [moved (let loop ([i a] [cost 0])
                      (if (> i b)
                          cost
                          (loop (+ i 1) (+ cost (distance (term-row-ref t (+ i d)) i)))))])
        (list (- (sum in-place top bottom) (scroll-cost t top bottom) exposed moved)
              top bottom n up?)))
    (define (best-candidate)
      (let ([best #f])
        (define (consider! a b d)
          (let ([c (candidate a b d)])
            (when (and (> (car c) 0) (or (not best) (> (car c) (car best))))
              (set! best c))))
        (do ([d (- 1 height) (+ d 1)]) ((= d height))
          (unless (= d 0)
            (let ([low (max 0 (- d))]                 ; rows I with I + D on screen
                  [high (- (min height (- height d)) 1)])
              (let loop ([i low] [start #f] [first #f] [last #f] [runs 0])
                (cond
                 [(> i high)
                  (when start (consider! start high d))
                  ;; all the runs together, when there are several
                  (when (and first (> (+ runs (if start 1 0)) 1))
                    (consider! first (if start high last) d))]
                 [(match? i d) (loop (+ i 1) (or start i) (or first i) i runs)]
                 [start
                  (consider! start (- i 1) d)
                  (loop (+ i 1) #f first last (+ runs 1))]
                 [else (loop (+ i 1) #f first last runs)])))))
        best))
    (refresh! 0 (- height 1))
    (let loop ([rounds height])
      ;; Moving rows only pays when at least two are wrong
      (when (and (> rounds 0)
                 (>= (vector-count-index (lambda (i cost) (> cost 0)) in-place) 2))
        (match (best-candidate)
          [#f #t]
          [(saving top bottom n up?)
           (scroll! t top bottom n up?)
           (refresh! top bottom)
           (loop (- rounds 1))])))))

;; Map and count over (index, element)
(define (vector-map-index f v)
  (let* ([n (vector-length v)] [out (make-vector n #f)])
    (do ([i 0 (+ i 1)]) ((= i n) out)
      (vector-set! out i (f i (vector-ref v i))))))

(define (vector-count-index f v)
  (let loop ([i 0] [n 0])
    (if (= i (vector-length v)) n (loop (+ i 1) (if (f i (vector-ref v i)) (+ n 1) n)))))

;;; =================================================================
;;; UPDATING THE SCREEN
;;; =================================================================

(define* (screen-update before after #:key (rep? #t) (lf? #t) (hide-cursor-over 200))
  "Return a list of terminal operations that turns the screen BEFORE,
   which the terminal is showing, into the screen AFTER, in as few bytes
   as this module can find (see the top of the file for how, and for the
   operations).  BEFORE is #f when what the terminal shows is not
   known, as at the start or after it is resized: the screen is then
   erased first.  Neither screen is changed.

   #:rep? #f             do not use REP
   #:lf? #f              do not use LF to move down
   #:hide-cursor-over N  hide the cursor while sending more than N
                         bytes (default 200), so that it is not seen
                         jumping about; #f never does"
  (let* ([known? (and before
                      (= (screen-width before) (screen-width after))
                      (= (screen-height before) (screen-height after)))]
         [t (screen->term (if known?
                              before
                              (make-screen (screen-width after) (screen-height after)
                                           #:cjk? (screen-cjk? after)))
                          #:rep? rep? #:lf? lf?)]
         [target (screen-rows after)]
         [show? (screen-cursor-visible? after)]
         [shown? (and known? (screen-cursor-visible? before))])
    (if known?
        (when (and shown? (not show?)) (emit! t '(cursor-hide)))
        (emit-all! t '((cursor-hide) (sgr) (stbm) (ed 2))))
    (scroll-rows! t after)
    (do ([r 0 (+ r 1)]) ((= r (term-height t)))
      (unless (rows-equal? (term-row-ref t r) (vector-ref target r))
        (update-row! t r (vector-ref target r))))
    (set-sgr! t 0)
    (move! t (screen-cursor-row after) (screen-cursor-col after))
    (when (and show? (not (term-visible? t))) (emit! t '(cursor-show)))
    (let ([ops (reverse (term-ops t))])
      (if (and shown? show? hide-cursor-over (> (term-bytes t) hide-cursor-over))
          (append '((cursor-hide)) ops '((cursor-show)))
          ops))))

(define (screen-update-string before after . options)
  "The characters to send to the terminal to turn the screen BEFORE
   into the screen AFTER; see screen-update."
  (ops->string (apply screen-update before after options)))

;;; =================================================================
;;; THE TERMINAL
;;; =================================================================

;; The screen the terminal is showing, or #f when that is not known:
;; before anything is shown, and after redraw-screen.
(define shown #f)

(define* (show-screen screen #:optional (port (current-output-port)))
  "Make the terminal on PORT show SCREEN, sending only what turns the
   screen last shown into it (see screen-update), or a full redraw the
   first time and after redraw-screen.  Returns the number of
   characters sent.  SCREEN must not be changed afterwards: it is kept
   to compare the next screen with."
  (let ([out (screen-update-string shown screen)])
    (display out port)
    (force-output port)
    (set! shown screen)
    (string-length out)))

(define (redraw-screen)
  "Stop relying on what the terminal shows: the next show-screen erases
   it and draws its screen in full.  For when the terminal may not show
   what was sent to it, as after noise on a serial line, output from
   another program, or a change of size.  Nothing is sent now."
  (set! shown #f))
