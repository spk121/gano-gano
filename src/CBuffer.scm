(define-module (gano CBuffer)
  #:use-module (gano config)
  #:use-module (oop goops)
  #:use-module (oop goops describe)
  #:use-module (gano chars)
  #:use-module (gano utils)
  #:use-module (srfi srfi-1)
  #:use-module ((ncurses extra) #:select (wcwidth))
  #:export (
            <CBuffer>

            backspace
            carriage-return
            character-position-absolute
            character-position-backward
            character-position-forward
            character-and-line-position
            cursor-backward-tabulation
            cursor-character-absolute
            cursor-down
            cursor-forward-tabulation
            cursor-left
            cursor-next-line
            cursor-position
            cursor-preceding-line
            cursor-up
            insert-line
            line-position-absolute
            line-position-backward
            line-position-forward
            scroll-down
            scroll-up

            get-pd-cur
            get-pp-cur
            get-pp-from-pd-cur
            get-pp-goal
            get-text-cur
            increase-pd-cur!
            set-line-cur!
            set-line-frame!
            set-pd-cur!
            set-pp-cur!
            set-pp-goal!
            set-text!
            ))

(if %have-rnrs-control
    (use-modules (rnrs control))
    (use-modules (gano control)))

(define-class <CBuffer> ()
    (m_fileName #:init-value "")
    (m_rgText #:init-value '("") #:getter get-text #:setter set-text!)
    (m_LFrame #:init-value 0 #:getter get-line-frame #:setter set-line-frame!)
    (m_LCur #:init-value 0 #:getter get-line-cur #:setter set-line-cur!)
    (m_totalSize #:init-value 0)
    (m_tabSize #:init-value 8 #:getter get-tab-size #:setter set-tab-size!)
    (m_PdCur #:init-value 0 #:getter get-pd-cur #:setter set-pd-cur!)
    (m_PpCur #:init-value 0 #:getter get-pp-cur #:setter set-pp-cur!)
    (m_PpGoal #:init-value 0 #:getter get-pp-goal #:setter set-pp-goal!)
    (m_fModified #:init-value #f)
    (m_fMarkSet #:init-value #f)
    (m_LMark #:init-value 0)
    (m_PdMark #:init-value 0)
    (m_fileFormat #:init-value 'nix)
    (m_statCur #:init-value #f)
    (m_undo #:init-value '())
    (m_iUndoCur #:init-value 0)
    (m_lastAction #:init-value 'other))

;; PRIMITIVES

(define-method (get-line-count (buf <CBuffer>))
  "Return the number of lines in the buffer"
  (length (get-text)))

(define-method (get-text-cur (buf <CBuffer>))
  (list-ref (get-text buf) (get-line-cur buf)))

(define-method (increase-pd-cur! (buf <CBuffer>) n)
  (set-pd-cur! buf (+ (get-pd-cur buf) n)))

;; METHODS

(define-method (backspace (buf <CBuffer>))
  "Move the active data position to the previous data position"
  (when (> (get-pd-cur buf) 0)
    (increase-pd-cur! buf -1))
  (set-pp-cur! buf (get-pp-from-pd-cur buf))
  (set-pp-goal! buf (get-pp-cur buf)))

(define-method (carriage-return (buf <CBuffer>))
  "Move the active presentation position to the line home position of
the same line in the presentation component"
  (set-pd-cur! buf 0)
  (set-pp-cur! buf 0)
  (set-pp-goal! buf 0))

(define-method (character-position-absolute (buf <CBuffer>) n)
  "Move the active data position to the n-th codepoint in the active
line"
  (let* ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))]
         [pd (max 0 (min n (last ppList)))]
         [pp (list-ref ppList pd)])
    (set-pd-cur! buf pd)
    (set-pp-cur! buf pp)
    (set-pp-goal! buf pp)))

(define-method (character-position-backward (buf <CBuffer>) n)
  "Move the active data position backward n codepoints"
  (let* ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))]
         [pd (max 0
                  (min (- (get-pos-cur buf) n)
                       (last ppList)))]
         [pp (list-ref ppList pd)])
    (set-pd-cur! buf pd)
    (set-pp-cur! buf pp)
    (set-pp-goal! buf pp)))

(define-method (character-position-forward (buf <CBuffer>) n)
  "Move the active data position forward n codepoints"
  (let* ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))]
         [pd (max 0
                  (min (+ (get-pos-cur buf) n)
                       (last ppList)))]
         [pp (list-ref ppList pd)])
    (set-pd-cur! buf pd)
    (set-pp-cur! buf pp)
    (set-pp-goal! buf pp)))

(define-method (character-and-line-position (buf <CBuffer>) n m)
  "Moves the active data position to the n-th line position m-th character position"
  (set-line-cur! (max 0 (min (get-line-max buf) n)))
  (character-position-absolute (buf m)))

(define-method (cursor-backward-tabulation (buf <CBuffer>) n)
    "Move the active presentation position to the character position
corresponding to the n-th preceding character tabulation stop in the
presentation component"
    (let* ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))]
           [ppCur (get-pp-cur buf)]
           [tabsize (get-tab-size buf)]
           ;; Back up n tabsizes
           [pp1 (- ppCur (* n tabsize))]
           ;; Move forward to a tab stop, or to line home position if
           ;; we've moved too far left
           [pp2 (if (zero? (remainder pp1 tabsize))
                    (max 0 pp1)
                    ;; else
                    (max 0 (* tabsize (1+ (quotient pp1 tabsize)))))]
           ;; Move forward if we're in the middle of a double-width
           ;; character
           [pd (max 0 (1- (list-index (lambda (x) (> x pp2)) ppList)))]
           [pp3 (list-ref ppList pd)])
      (format (current-error-port) "backtab: start-pp ~a num_tabs ~a back_pp ~a forward_pp ~a~%"
              ppCur n pp1 pp2)
      (set-pd-cur! buf pd)
      (set-pp-cur! buf pp3)
      (set-pp-goal! buf pp2)))

(define-method (cursor-character-absolute (buf <CBuffer>) n)
    "Move the active presentation position to character position n in
the active line in the presentation component"
    (let* ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))]
           ;; Find the data position of the character at presentation
           ;; position N
           [pd-next (list-index (lambda (x) (> x n)) ppList)]
           [pd (if pd-next
                   (max 0 (1- pd-next))
                   ;; else
                   (last ppList))]
           ;; Adjust the presentation position if we're in the middle of
           ;; a double-width character
           [pp (list-ref ppList pd)])
      (set-pd-cur! buf pd)
      (set-pp-cur! buf pp)
      (set-pp-goal! buf (max 0 n))))

(define-method (cursor-down (buf <CBuffer>) n)
  "Move the active presentation position downwards in the presentation
component by N line positions"
  (let* ([LCur (get-line-cur buf)]
         ;; Move forward n lines, or to the end of the buffer
         [L1 (min (+ LCur n) (1- (get-line-count buf)))])
    (set-line-cur! buf L1)
    (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))]
          ;; Find the data position of the character at the current
          ;; presentation position.
          [pd-next (list-index (lambda (x) (> x n)) ppList)]
          [pd (if pd-next
                  (max 0 (1- pd-next))
                  ;; else
                  (last ppList))]
          ;; Adjust the presentation position if we're in the middle of
          ;; a double-width character
          [pp (list-ref ppList pd)])
      (set-pd-cur! buf pd)
      (set-pp-cur! buf pp)
      ;; The goal column remains unchanged
      )))

(define-method (cursor-forward-tabulation (buf <CBuffer>) n)
    "Move the active presentation position to the character position
corresponding to the n-th following character tabulation stop in the
presentation component"
    (let* ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))]
           ;; Move forward n tabsizes
           [tabsize (get-tab-size buf)]
           [pp1 (+ (get-pp-cur buf) (* n tabsize))]
           ;; Move backward to a tab stop
           [pp2 (* tabsize (quotient pp1 tabsize))]
           ;; if we've moved past the end of the line...
           [pp3 (min pp2 (last ppList))]
           ;; Then move backward if we're in the middle of a double-width
           ;; character
           [pd-next (list-index (lambda (x) (> x pp3)) ppList)]
           [pd (if pd-next
                   (max 0 (1- pd-next))
                   ;; else
                   (last ppList))]
           [pp4 (list-ref ppList pd)])
      (set-pd-cur! buf pd)
      (set-pp-cur! buf pp4)
      (set-pp-goal! buf pp2)))

(define (cursor-left buf n)
  "Move the active presentation position leftwards in the presentation
component by n character positions"
    (let* ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))]
           [ppCur (get-pp-cur buf)]
           ;; Back up n cells
           [pp1 (- ppCur n)]
           ;; Move backward if we're in the middle of a double-width
           ;; character
           [pd (max 0 (1- (list-index (lambda (x) (> x pp1)) ppList)))]
           [pp2 (list-ref ppList pd)])
      (set-pd-cur! buf pd)
      (set-pp-cur! buf pp2)
      (set-pp-goal! buf pp1)))

(define (cursor-next-line buf n)
  "Move the active presentation position to the 1st character position
of the n-th following line in the presentation component"
  (let* ([LCur (get-line-cur buf)]
         ;; Move forward n lines, or to the end of the buffer
         [L1 (min (+ LCur n) (1- (get-line-count buf)))])
    (set-line-cur! buf L1)
    (set-pd-cur! buf 0)
    (set-pp-cur! buf 0)
    (set-pp-goal! buf 0)))


(define (cursor-preceding-line buf n)
  "Move the active presentation position to the 1st character position
of the n-th preceding line in the presentation component"
  (let* ([LCur (get-line-cur buf)]
         ;; Move backward n lines, or to the beginning of the buffer
         [L1 (max 0 (- LCur n))])
    (set-line-cur! buf L1)
    (set-pd-cur! buf 0)
    (set-pp-cur! buf 0)
    (set-pp-goal! buf 0)))

(define (cursor-right buf n)
  "Move the active presentation position rightwards in the
presentation component by n character positions"
  (let* ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))]
         [ppCur (get-pp-cur buf)]
         ;; Move forward n cells
         [pp1 (+ ppCur n)]
         ;; Move backward if we're in the middle of a double-width
         ;; character
         [pd (max 0 (1- (list-index (lambda (x) (> x pp1)) ppList)))]
         [pp2 (list-ref ppList pd)])
    (set-pd-cur! buf pd)
    (set-pp-cur! buf pp2)
    (set-pp-goal! buf pp1)))

(define (cursor-position buf n m)
  "Move the active presentation position to the n-th line and m-th
character position in the presentation component"
  (set-line-cur! buf (min (get-line buf) (1- (get-line-count buf))))
  (cursor-character-absolute buf m))

(define (cursor-up buf n)
  "Move the active presentation positions upwards in the presentation
component by N line positions"
  (let* ([LCur (get-line-cur buf)]
         ;; Move backward n lines, or to the top of the buffer
         [L1 (max (+ LCur n) 0)])
    (set-line-cur! buf L1)
    (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))]
          ;; Find the data position of the character at the current
          ;; presentation position.
          [pd-next (list-index (lambda (x) (> x n)) ppList)]
          [pd (if pd-next
                  (max 0 (1- pd-next))
                  ;; else
                  (last ppList))]
          ;; Adjust the presentation position if we're in the middle of
          ;; a double-width character
          [pp (list-ref ppList pd)])
      (set-pd-cur! buf pd)
      (set-pp-cur! buf pp)
      ;; The goal column remains unchanged
      )))

(define-method (delete-character buf device)
  #t)

(define-method (delete-in-line buf device)
  #t)

(define-method (erase-character buf device)
  "This replaces the character at the active data postion with the space
character.  If DEVICE is 'presentation, multi-cell graphemes will be
replaced with multiple space characters.  If DEVICE is 'data, the current
codepoint will be replaced with a single space character."
  #t)

(define-method (erase-in-line buf device P)
  "This sets some or all of the characters in the current line to
spaces. If P is zero, the active position through end of the line are
erased.  If P is one, the beginning of the line through the active
position are erased.  If P is two, the entire line is erased.

If the DEVICE is 'presentation, graphemes that occupy more than one
cell will be replaced with as many spaces necessary to keep the number
of presentation cells constant, and the cursor remains in the same
position in the presentation component, but, the active data position
may change.  If the DEVICE is 'data, each codepoint that is erased
will be replaced with a single space character.  The active data
position remains the same but the presentation position may change.
This may change the visual presentation of the line"

  (add-undo (list 'EL device P (get-line-cur buf) (get-pd-cur buf) (get-line-text buf)))

  (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))]
        [pp-cur (get-pp-cur buf)]
        [pd-cur (get-pd-cur buf)]
        [pd-mark (get-pd-mark buf)]
        [text-cur (get-text-cur buf)])
    (cond
     ;; Erase to the end of the line
     [(and (eqv? device 'presentation) (= P 0))
      (set-text! buf (string-append (string-take text-cur pd-cur)
                                    (make-string (- (last ppList) pp-cur) #\space)))
      ;; Clear the mark if its position has been erased
      (when (and (is-mark-enabled? buf)
                 (= (get-line-cur buf) (get-line-mark buf))
                 (>= pd-mark pd-cur))
        (set-mark-flag! buf #f))]
     [(and (eqv? device 'data) (= P 0))
      (set-text! buf (string-append (string-take text-cur pd-cur)
                                    (make-string (- (string-length text-cur) pd-cur) #\space)))
      ;; Clear the mark if its position has been erased
      (when (and (is-mark-enabled? buf)
                 (= (get-line-cur buf) (get-line-mark buf))
                 (>= pd-mark pd-cur))
        (set-mark-flag! buf #f))]

     ;; Erase from the beginning of the line to here
     [(and (eqv? device 'presentation) (= P 1))
      (when (and (is-mark-enabled? buf)
                 (= (get-line-cur buf) (get-line-mark buf)))
        ;; If the mark's position will be erased, clear the mark
        (when (<= pd-mark pd-cur)
          (set-mark-flag! buf #f))
        ;; If the mark's position is later in this line, adjust is
        ;; data position to keep it on the same codepoint
        (when (> pd-mark pd-cur)
          (set-pd-mark! (+ pd-mark (- pp-cur pd-cur)))))
      ;; Erase the beginning of the string
      (set-text! buf (string-append (make-string pp-cur #\space)
                                    (string-drop text-cur pd-cur)))
      (set-pd-cur! buf pp-cur)]
     [(and (eqv? device 'data) (= P 1))
      (when (and (is-mark-enabled? buf)
                 (= (get-line-cur buf) (get-line-mark buf)))
        ;; If the mark's position will be erased, clear the mark
        (when (<= pd-mark pd-cur)
          (set-mark-flag! buf #f)))
      ;; Erase the beginning of the string
      (set-text! buf (string-append (make-string pd-cur #\space)
                                    (string-drop text-cur pd-cur)))
      (set-pp-cur! buf pd-cur)
      (set-pp-goal! buf pd-cur)]
     ;; Erase the whole line
     [(and (eqv? device 'presentation) (= P 2))
      ;; If the mark is on this line, erase it
      (when (and (is-mark-enabled? buf)
                 (= (get-line-cur buf) (get-line-mark buf)))
        (set-mark-flag! buf #f))
      ;; Erase the line
      (set-text! buf (make-string (last ppList)))
      (set-pd-cur! pp-cur)]
     [(and (eqv? device 'data) (= P 2))
      ;; If the mark is on this line, erase it
      (when (and (is-mark-enabled? buf)
                 (= (get-line-cur buf) (get-line-mark buf)))
        (set-mark-flag! buf #f))
      ;; Erase the line
      (set-text! buf (make-string (string-length text-cur) #\space))
      (set-pp-cur! pd-cur)
      (set-pp-goal! pd-cur)])))


(define-method (insert-character (buf <CBuffer>) n)
  "Shift the contents of the line to the right, starting at the
current data position, creating an empty gap of N codepoints"
  (add-undo (list 'ICH n (get-line-cur buf) (get-pd-cur buf)))

  (let ([str (get-line-cur buf)]
        [pd (get-pd-cur buf)])
    (set-line-cur! buf (string-take str pd) (make-string n #\space) (string-drop str pd))

    ;; Move the mark right, if necessary
    (when (and (is-mark-set? buf)
               (= (get-line-mark) (get-line-cur))
               (>= (get-pd-mark) (get-pd-cur)))
      (set-pd-mark! (+ (get-pd-mark) n)))))

(define-method (insert-line (buf <CBuffer> n))
  "Move the current line and the n-1 following lines down N lines.
The resulting cap is erased.  The cursor is placed at the home
position of the first new empty line."
  (add-undo buf (list 'IL n (get-line-cur) (get-pd-cur)))

  (let ([txt (get-text buf)]
        [L (get-line-cur buf)])
    (set-text! buf (append (take txt L)
                           (make-list n "")
                           (drop txt L)))
    (set-pd-cur! 0)
    (set-pp-cur! 0)
    (set-pp-goal! 0)

    ;; Move the mark down, if necessary
    (when (and (is-mark-set? buf)
               (>= (get-line-mark) L))
      (set-line-mark! (+ (get-line-mark) n)))))

(define-method (line-position-absolute (buf <CBuffer>) n)
  "Move the active data position to the n-th line"
  (set-line-cur! (min n (get-line-max)))
  (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))])
    (set-pp-cur! (list-ref ppList (get-pd-cur)))
    (set-pp-goal! (get-pp-cur))))

(define-method (line-position-backward (buf <CBuffer>) n)
  "Move the active data position up n line positions"
  (set-line-cur! (max 0 (- (get-line-cur) n)))
  (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))])
    (set-pp-cur! (list-ref ppList (get-pd-cur)))
    (set-pp-goal! (get-pp-cur))))

(define-method (line-position-forward (buf <CBuffer>) n)
  "Move the active data position down by n line positions"
  (set-line-cur! (min (+ (get-line-cur) n) (get-line-max)))
  (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))])
    (set-pp-cur! (list-ref ppList (get-pd-cur)))
    (set-pp-goal! (get-pp-cur))))

(define-method (scroll-down (buf <CBuffer>) n)
  "Moves the presentation component N line positions such that the
data appear to move down; the active presentation position is not
affected by this control function."
  (set-line-frame! (max 0 (- (get-line-frame) n))))

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
  (set-line-frame! (min (1- (get-line-count)) (- (get-line-frame) n))))

(define-method (write-character (buf <CBuffer>) c device)
  "Writes the graphical character C into the active position,
overwriting the current character.  If DEVICE is 'data, the current
codepoint is replaced with C.  If DEVICE is 'presentation, those
graphemes that would be wholly or partly overwritten by this grapheme
will be erased before this grapheme is added."
  
  #t)

(define-method (write-tab (buf <CBuffer>) c device)
  "Writes a tab at the current position, overwritting the current character.
If DEVICE is 'data, the current codepoint is replace with a tab.
If DEVICE is 'presentation, those graphemes that would be wholly or partly
overwritten by this tab will be erased before the tab is added."
  #t)

(define-method (write-next-line (buf <CBuffer>) c)
  "Removes the text between the active position and the end of the
line from the current line, and places it in a new line inserted after
the current line"
  #t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; UTILITIES

(define (compute-pp-list-from-string str tabsize)
  (let loop ([pp 0] [lst '()] [str str])
    (cond
     [(not (string-null? str))
      (loop (+ pp (count-cells-in-char (string-ref str 0) pp tabsize))
            (append lst (list pp))
            (string-drop str 1))]
     [else
      ;; return list
      (append lst (list pp))])))

(define (count-cells-in-char chr x tabSize)
  "Number of cells a character CHR at column X would take up"
  (cond
   [(eqv? chr #\nul)
    0]
   [(eqv? chr #\tab)
    (- tabSize (modulo x tabSize))]
   [(is-control-char? chr)
    ;; Add 1 for the caret '^'
    (1+ (wcwidth (get-display-char-from-control-char chr)))]
   [else
    (wcwidth chr)]))

(define (count-cells-in-string str xstart tabsize)
  "Number of screen cells occupied by the characters in a string"
  (let ([iLim (string-length str)]
        [x xstart])
    (do ([i 0 (1+ i)]) ([>= i iLim])
      (set! x (+ x (count-cells-in-char (string-ref str i) x tabsize))))
    (format (current-error-port) "CountCellsInString: str ~s count ~s~%" str x)
    (- x xstart)))

(define (count-cells-in-substring str n xstart tabsize)
  "Return the number of screen cells occupied by the first N
characters of a string, assuming that the first string character is a
the presentation position XSTART with a given TABSIZE"
  (count-cells-in-string (substring str 0 n) xstart tabsize))

(define (get-display-char-from-control-char c)
  "The character to use when displaying controls in \"^X\" form"
  (integer->char (+ (char->integer c) 64)))

(define-method (get-pp-from-pd-cur (buf <CBuffer>))
  "Find the presentation position of the active data position for the
current line."
  (count-cells-in-substring (get-text-cur buf) (get-pd-cur buf) 0 (get-tab-size buf)))

(define (is-control-char? c)
  "#t if this is an ISO control character"
  (char-set-contains? char-set:iso-control c))


(define (AppendBufferMagicLine)
  (SetBufferLines! (append (GetBufferLines)
                             (list ""))))

  (define (GetBufferCCur)
    (+ (GetBufferPdCur)
       (if (> (GetBufferLCur) 0)
           (fold 0 (lambda (line count)
                     (+ count (string-length line)))
                 (take (GetBufferLines) (1- (GetBufferLCur))))
           0)))

  (define (GetBufferCMax)
    (fold 0 (lambda (line count)
              (+ count (string-length line)))
          (GetBufferLines)))

  (define (GetBufferFileName)
    (slot-ref (Buf) 'm_fileName))

  (define (GetBufferLCur)
    (slot-ref (Buf) 'm_LCur))

  (define (GetBufferLFrame)
    (slot-ref (Buf) 'm_LFrame))

  (define (GetBufferLMark)
    (slot-ref (Buf) 'm_LMark))

  (define (GetBufferLLim)
    (length (slot-ref (Buf) 'm_rgText)))

  (define (GetBufferLineCur)
    (list-ref (slot-ref (Buf) 'm_rgText) (slot-ref (Buf) 'm_LCur)))

  (define (GetBufferLine index)
    (list-ref (slot-ref (Buf) 'm_rgText) index))

  (define (GetBufferLines)
    (slot-ref (Buf) 'm_rgText))

  (define (GetBufferTotalSize)
    (slot-ref (Buf) 'm_totalSize))

  (define (GetBufferPdCur)
    (slot-ref (Buf) 'm_PdCur))

  (define (GetBufferPpGoal)
    (slot-ref (Buf) 'm_PpGoal))

  (define (GetBufferPdMark)
    (slot-ref (Buf) 'm_PdMark))

  (define (GetBufferYCur)
    (slot-ref (Buf) 'm_yCur))

  (define (IncreaseBufferTotalSize! n)
    (SetBufferTotalSize! (+ n (GetBufferTotalSize))))

  (define (IncreaseBufferLCur! n)
    (SetBufferLCur! (+ n (GetBufferLCur))))

  (define (IncreaseBufferLFrame! n)
    (SetBufferLFrame! (+ n (GetBufferLFrame))))

  (define (IncreaseBufferLMark! n)
    (SetBufferLMark! (+ n (GetBufferLMark))))


  (define (IncreaseBufferPdMark! n)
    (SetBufferPdMarkBegin! (+ n (GetBufferPdMark))))

  (define (IncreaseBufferPdCur! n)
    (SetBufferPdCur! (+ n (GetBufferPdCur))))

  (define (IsBufferMarkSet?)
    (slot-ref (Buf) 'm_fMarkSet))

  (define (IsBufferModified?)
    (slot-ref (Buf) 'm_fModified))

  (define-method (SetBufferModified! flag)
    (slot-set! (Buf) 'm_fModified flag))

  (define-method (SetBufferFileName! (fileName <string>))
    (slot-set! (Buf) 'm_fileName fileName))

  (define-method (SetBufferLCur! (index <number>))
    (slot-set! (Buf) 'm_LCur index))

  (define-method (SetBufferLFrame! (index <number>))
    (slot-set! (Buf) 'm_LFrame index))

  (define-method (SetBufferLMark! (index <number>))
    (slot-set! (Buf) 'm_LMark index))

  (define-method (SetBufferLines! rgText)
    (slot-set! (Buf) 'm_rgText rgText))

  (define-method (SetBufferTotalSize! (size <number>))
    (slot-set! (Buf) 'm_totalSize size))

  (define-method (SetBufferPdCur! (index <number>))
    (slot-set! (Buf) 'm_PdCur index))

  (define-method (SetBufferPpGoal! (index <number>))
    (slot-set! (Buf) 'm_PpGoal index))

  (define-method (SetBufferXMarkBegin! (index <number>))
    (slot-set! (Buf) 'm_PdMark index))

  (define-method (SetBufferYCur! (index <number>))
    (slot-set! (Buf) 'm_yCur index))

  (define-method (SetBufferLineCur! (text <string>))
    (list-set! (slot-ref (Buf) 'm_rgText) (slot-ref (Buf) 'm_LCur) text))

  ;; -------------------

  (define (BufferCursorDown)
    "Move the active presentation position downwards in the presentation
component by N line positions"
    (let* ([LCur (GetBufferLCur)]
           [L1 (min (GetBufferLLim) (+ LCur n))])
      (SetBufferLCur! L1)
      (let ([ppList (ComputePpListFromString (GetBufferLineCur))]
            ;; Find the data position of this column.  If there is not
            ;; data at this column, move to the last character's position.
            [pd (or (1- (find (lambda (x) (> x pp)) ppList))
                    (last ppList))]
            ;; Adjust leftward if we're in the middle of a character
            [pp (list-ref ppList index)])
        (SetBufferPdCur! pd)
        (SetBufferPpCur! pp)
        ;; The goal column is unchanged
        )))

  (define (BufferCursorRight n)
    "Move the active presentation position rightwards in the presentation
component by n character positions"
    (let* ([ppList (ComputePpListFromString (GetBufferLineCur))]
           ;; Move right N screen cells
           [pp (min (last ppList) (+ (GetBufferPpCur) n))]
           ;; Adjust leftward if we're in the middle of a character
           [pd (or (1- (find (lambda (x) (> x pp) ppList)))
                   (last ppList))]
           [pp2 (list-ref ppList pd)])
      (SetBufferPdCur! pd)
      (SetBufferPpCur! pp2)
      (SetBufferPpGoal! n)))

  (define (BufferCursorPosition n m)
    "Move the active presentation position to the n-th line and m-th
character position in the presentation component"
    (let* ([L1 (min n (GetBufferLLim))])
      (SetBufferLineCur! L1)
      (let* ([ppList (ComputePpListFromString (GetBufferLineCur))]
             ;; Find the character at this location, or the last character
             ;; if this location is to the right of all characters
             [pd (or (1- (find (lambda (x) (> x m) ppList)))
                     (last ppList))]
             [pp (list-ref ppList pd)])
        (SetBufferPdCur! pd)
        (SetBufferPpCur! pp)
        (SetBufferPpGoal! pos))))

  (define (BufferCursorUp n)
    "Move the active presentation position upwards in the presentation
component by N line positions"
    (let* ([LCur (GetBufferLCur)]
           [L1 (max 0 (- LCur n))])
      (SetBufferLCur! L1)
      (let ([ppList (ComputePpListFromString (GetBufferLineCur))]
            ;; Find the data position of this column.  If there is not
            ;; data at this column, move to the last character's position.
            [pd (or (1- (find (lambda (x) (> x pp)) ppList))
                    (last ppList))]
            ;; Adjust leftward if we're in the middle of a character
            [pp (list-ref ppList index)])
        (SetBufferPdCur! pd)
        (SetBufferPpCur! pp)
        ;; The goal column is unchanged
        )))

  ;; BufferCursorLineTabulation - unimplemented

  (define (BufferDeleteCharacter n)
    "If the Device Component Select Mode is 'presentation: delete the
contents of the current presentation position and of the n-1 preceding
character cells.  The gap is closed by shifting the contents of the
adjacent character positions to the left.  If the Device Component
Select Mode is 'data, it is the n-1 preceding character that are
deleted instead."
    (cond
     [(eqv? (GetDeviceComponentSelectMode) 'presentation)
      ;; Delete the current cells and n-1 cells to the left
      (let* ([str (GetBufferLineCur)]
             [ppList (ComputePpListFromString str)]
             [pp (max 0 (- (GetBufferPpCur) n))]
             ;; Find the data position of this column.
             [pd (or (1- (find (lambda (x) (> x pp))) ppList)
                     (last ppList))]
             ;; Adjust if we're in the middle of a character
             [pp2 (list-ref ppList pd)])
        (SetBufferLineCur! (string-take str pd)
                           (string-drop str (GetBufferPdCur)))
        (SetBufferPdCur! pd)
        (SetBufferPpCur! pp2)
        (SetBufferPpGoal! pp))]
     [else
      ;; Delete the current character and n-1 characters to the left
      (let* ([str (GetBufferLineCur)]
             [ppList (ComputePpListFromString str)]
             [pd (max 0 (- (GetBufferPdCur) n))]
             ;; Find the presentation position of this column.
             [pp (list-ref ppList pd)])
        (SetBufferLineCur! (string-take str pd)
                           (string-drop str (GetBufferPdCur)))
        (SetBufferPdCur! pd)
        (SetBufferPpCur! pp)
        (SetBufferPpGoal! pp))]))

  (define (BufferDeleteLine n)
    "Delete the active line and the n-1 following lines.  The resulting
gap is closed by shifting the contents following the deleted lines
toward the active line.  The position is move to the line home position."
    #t)

  (define (BufferEraseCharacter n)
    #t)

  (define (BufferEraseInLine n)
    #f)

  (define (BufferFormFeed n)
    #t)

  (define (BufferCharacterPositionAbsolute n)
    #t)

  (define (BufferCharacterPositionBackward n)
    #t)

  (define (BufferCharacterPositionForward n)
    #t)

  (define (BufferCharacterTabulation)
    #t)

  (define (BufferCharacterAndLinePosition n m)
    #t)

  (define (BufferInsertCharacter n)
    #t)

  (define (BufferInsertLine n)
    #t)

  (define (BufferJustify n)
    #t)

  (define (BufferLineFeed)
    #t)

  (define (BufferNextLine)
    #t)

  (define (BufferNextPage)
    #t)

  (define (BufferPrecedingPage n)
    #t)

  (define (BufferPagePositionAbsolute n)
    #t)

  (define (BufferPagePositionBackward n)
    #t)

  (define (BufferPagePositionForward n)
    #t)

  (define (BufferQuad n)
    #t)

  (define (BufferReverseLineFeed)
    #t)

  (define (BufferResetToInitialState)
    #t)

  (define (BufferScrollDown n)
    #t)

  (define (BufferScrollLeft n)
    #t)

  (define (BufferScrollRight n)
    #t)

  (define (BufferScrollUp n)
    #t)

  (define (BufferLinePositionAbsolute n)
    #t)

  (define (BufferLinePositionBackward n)
    #t)

  (define (BufferLinePositionForward n)
    #t)
