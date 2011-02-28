

;;;; A Character-Cell Buffer

;;; These are functions that act on a character cell buffer:
;;; which is a list of strings, a virtual cursor which is a location
;;; in that list of strings, and a set of functions that add text,
;;; delete text, and move the cursor.
;;;
;;; It assumes that each character has a width of 1 or 2 character
;;; cells: Latin characters have width 1, Hanzi and Kanji have width 2.
;;; Horizontal tabulation characters have a varying width that stretches
;;; to the next tabulation stop.  Combining marks have a width of 0
;;; but must following a valid base character with a width of 1 or 2.
;;;
;;; There are effectively three different ways to refer to the cursor's
;;; x position:
;;;
;;; x-index: the Xth codepoint in a string
;;; x-data: the Xth character in a string, where multi-codepoint characters
;;;      consisting of a base character and combining marks are counted
;;;      as a single character
;;; x-cell: the Xth character cell in the display rendition of the current
;;;      string
;;;
;;; There is also a second x-cell position.
;;; x-goal: the desired character cell.  It is the position that the cursor
;;;      would be at if the current line was at least that long.
;;;
;;; "pd" - data position
;;; "pp" - presentation position

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Customary behaviors for keypresses
;;
;; Narrow char on wide char (OVR):
;;     replace char, move point after char
;;
;; Wide char on narrow char (OVR):
;;     replace char, move point after char
;;
;; Backspace over char (INS):
;;     move point 1 left, delete char after point
;;
;; Backspace over char (OVR):
;;     EMACS: move point 1 left, convert char after point to wcwidth spaces
;;     Others: move point 1 left, delete char after point
;;
;; Backspace over tab:
;;     move point to beginning of tab, delete tab
;;
;; Backspace over BOL:
;;     move point to end of prev line, join lines
;;
;; Delete char:
;;     delete char after point
;;
;; Delete tab:
;;     delete tab after point
;;
;; Delete EOL:
;;     join lines
;;
;; Tab:
;;     insert tab after point, move point after tab
;;
;; Enter:
;;     break lines at point, move point to beginning of new lilne
;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;
;; Customary behaviors for format effectors in files
;;
;; Bell, backspace, vtab, form feed:
;;      print as escape
;;
;; Return:
;;      emacs: print at ^M
;;      others: ignore
;;
;; Newline:
;;      use a line break

;; #ifdef RACKET
(define alarm-char (integer->char 7))
(define delete-char (integer->char 127))

(define (list-set lst x val)
  (append (take lst x)
          (list val)
          (drop lst (+ x 1))))

;; Error codes for CBUF

(define-condition-type &cbuf-beginning-of-buffer &condition
  cbuf-beginning-of-buffer?)

(define-condition-type &cbuf-end-of-buffer &condition
  cbuf-end-of-buffer?)

(define-condition-type &cbuf-beginning-of-line &condition
  cbuf-beginning-of-line?)

(define-condition-type &cbuf-end-of-line &condition
  cbuf-end-of-line?)

(define-condition-type &cbuf-combining-mark-error &serious
  cbuf-combining-mark-error?
  (previous cbuf-combining-mark-error:previous)
  (current cbuf-combining-mark-error:current)
  (next cbuf-combining-mark-error:next))

;; The Old-school R5RS 'class' for the CBuf character-cell buffer.

(define CBUF_TEXT 1)
(define CBUF_PPLIST 2)
(define CBUF_LCUR 3)
(define CBUF_PDCUR 4)
(define CBUF_PPCUR 5)
(define CBUF_PPGOAL 6)
(define CBUF_TABSIZE 7)
(define CBUF_VERTTABSIZE 8)
(define CBUF_FORMSIZE 9)
(define CBUF_PHOME 10)
(define CBUF_PLIMIT 11)
(define CBUF_LIMITTYPE 12)
(define CBUF_MARKFLAG 13)
(define CBUF_LMARK 14)
(define CBUF_PDMARK 15)
(define CBUF_UNDOLIST 16)
(define CBUF_BELL 17)
(define CBUF_AMBIGUOUS_WIDTH 18)
(define CBUF_CUTBUFFER 19)
(define CBUF_LENGTH (+ 1 CBUF_CUTBUFFER))


(define (cbuf-make-buffer)
  "Create an empty character cell buffer."
  (let ((cbuf (make-vector CBUF_LENGTH #f)))
    (vector-set! cbuf 0 'cbuf)
    (vector-set! cbuf CBUF_TEXT '(""))
    (vector-set! cbuf CBUF_PPLIST '())
    (vector-set! cbuf CBUF_LCUR 0)
    (vector-set! cbuf CBUF_PDCUR 0)
    (vector-set! cbuf CBUF_PPCUR 0)
    (vector-set! cbuf CBUF_PPGOAL 0)
    (vector-set! cbuf CBUF_TABSIZE 8)   ; 8 spaces per tab
    (vector-set! cbuf CBUF_VERTTABSIZE 6) ; 6 lines per vert tab
    (vector-set! cbuf CBUF_FORMSIZE 66) ; 66 lines per page
    (vector-set! cbuf CBUF_PHOME 0)
    (vector-set! cbuf CBUF_PLIMIT 79)
    (vector-set! cbuf CBUF_LIMITTYPE 'data)
    (vector-set! cbuf CBUF_MARKFLAG #f)
    (vector-set! cbuf CBUF_LMARK 0)
    (vector-set! cbuf CBUF_PDMARK 0)
    (vector-set! cbuf CBUF_UNDOLIST '())
    (vector-set! cbuf CBUF_BELL #f)
    (vector-set! cbuf CBUF_AMBIGUOUS_WIDTH 1)
    (vector-set! cbuf CBUF_CUTBUFFER #f)
    cbuf))

;; The text
;; A list of strings
(define (cbuf-get-text cbuf)          (vector-ref cbuf CBUF_TEXT))
;; A list of the presentation positions of the characters of the current line
(define (cbuf-get-pp-list cbuf)       (vector-ref cbuf CBUF_PPLIST))
;; The current line number
(define (cbuf-get-line-cur cbuf)      (vector-ref cbuf CBUF_LCUR))
(define (cbuf-get-y cbuf)             (vector-ref cbuf CBUF_LCUR))
;; The current data position
(define (cbuf-get-pd-cur cbuf)        (vector-ref cbuf CBUF_PDCUR))
(define (cbuf-get-x-data cbuf)        (vector-ref cbuf CBUF_PDCUR))
;; The current presentation position
(define (cbuf-get-pp-cur cbuf)        (vector-ref cbuf CBUF_PPCUR))
;; The desired presentation position
(define (cbuf-get-pp-goal cbuf)       (vector-ref cbuf CBUF_PPGOAL))
(define (cbuf-get-x-goal cbuf)        (vector-ref cbuf CBUF_PPGOAL))
;; The number of spaces per between tab stops
(define (cbuf-get-tab-size cbuf)      (vector-ref cbuf CBUF_TABSIZE))
;; The number of lines per vertical tab stops
(define (cbuf-get-vert-tab-size cbuf) (vector-ref cbuf CBUF_VERTTABSIZE))
;;
(define (cbuf-get-form-size cbuf)     (vector-ref cbuf CBUF_FORMSIZE))

;; Home and Limit
(define (cbuf-get-home-pos cbuf)      (vector-ref cbuf CBUF_PHOME))
(define (cbuf-get-limit-pos cbuf)     (vector-ref cbuf CBUF_PLIMIT))
(define (cbuf-get-limit-type cbuf)    (vector-ref cbuf CBUF_LIMITTYPE))

;; The mark
(define (cbuf-is-mark-set? cbuf)      (vector-ref cbuf CBUF_MARKFLAG))
(define (cbuf-get-line-mark cbuf)     (vector-ref cbuf CBUF_LMARK))
(define (cbuf-get-y-mark cbuf)        (vector-ref cbuf CBUF_LMARK))
(define (cbuf-get-pd-mark cbuf)       (vector-ref cbuf CBUF_PDMARK))
(define (cbuf-get-x-mark cbuf)        (vector-ref cbuf CBUF_PDMARK))

;; The undo ring
(define (cbuf-get-undo-list cbuf)     (vector-ref cbuf CBUF_UNDOLIST))
(define (cbuf-get-bell cbuf)          (vector-ref cbuf CBUF_BELL))
(define (cbuf-get-cut-buffer cbuf)    (vector-ref cbuf CBUF_CUTBUFFER))

;; The width of characters whose width is ambiguous.  Typically
;; ambiguous characters are width 1 when most text is not East Asian
;; and is 2 when most text is East Asian
(define (cbuf-get-ambiguous-width cbuf) (vector-ref cbuf CBUF_AMBIGUOUS_WIDTH))

(define (cbuf-set-text! cbuf val)          (vector-set! cbuf CBUF_TEXT val))
(define (cbuf-set-pp-list! cbuf val)       (vector-set! cbuf CBUF_PPLIST val))
(define (%cbuf-set-line-cur! cbuf val)     (vector-set! cbuf CBUF_LCUR val))
(define (%cbuf-set-y! cbuf val)            (vector-set! cbuf CBUF_LCUR val))
(define (cbuf-set-pd-cur! cbuf val)        (vector-set! cbuf CBUF_PDCUR val))
(define (cbuf-set-x-data! cbuf val)        (vector-set! cbuf CBUF_PDCUR val))
(define (cbuf-set-pp-cur! cbuf val)        (vector-set! cbuf CBUF_PPCUR val))
(define (cbuf-set-pp-goal! cbuf val)       (vector-set! cbuf CBUF_PPGOAL val))
(define (cbuf-set-x-goal! cbuf val)        (vector-set! cbuf CBUF_PPGOAL val))
(define (cbuf-set-tab-size! cbuf val)      (vector-set! cbuf CBUF_TABSIZE val))
(define (cbuf-set-vert-tab-size! cbuf val) (vector-set! cbuf CBUF_VERTTABSIZE val))
(define (cbuf-set-home-pos! cbuf val)      (vector-set! cbuf CBUF_PHOME val))
(define (cbuf-set-limit-pos! cbuf val)     (vector-set! cbuf CBUF_PLIMIT val))
(define (cbuf-set-limit-type! cbuf val)    (vector-set! cbuf CBUF_LIMITTYPE val))
(define (cbuf-set-mark-flag! cbuf val)     (vector-set! cbuf CBUF_MARKFLAG val))
(define (cbuf-set-line-mark! cbuf val)     (vector-set! cbuf CBUF_LMARK val))
(define (cbuf-set-y-mark! cbuf val)        (vector-set! cbuf CBUF_LMARK val))
(define (cbuf-set-pd-mark! cbuf val)       (vector-set! cbuf CBUF_PDMARK val))
(define (cbuf-set-x-mark! cbuf val)        (vector-set! cbuf CBUF_PDMARK val))
(define (cbuf-set-cut-buffer! cbuf val)    (vector-set! cbuf CBUF_CUTBUFFER val))
(define (cbuf-set-undo-list! cbuf val)     (vector-set! cbuf CBUF_UNDOLIST val))
(define (cbuf-set-bell! cbuf val)          (vector-set! cbuf CBUF_BELL val))
(define (cbuf-set-ambiguous-width! cbuf val) (vector-set! cbuf CBUF_AMBIGUOUS_WIDTH val))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PRIMITIVES

(define (cbuf-get-x-index buf)
  (let ([base-indices (string-base-indices (cbuf-get-text-cur buf))]
        [x-data (cbuf-get-x-data buf)])
    (list-ref base-indices x-data)))

(define (cbuf-get-x-cell buf)
  ;; (format #t "cbuf-get-x-cell x-data ~a text-cur ~s tabsize ~a -> x-cell ~a~%"
  ;;         (cbuf-get-x-data buf)
  ;;         (cbuf-get-text-cur buf)
  ;;         (cbuf-get-tab-size buf)
  ;;         (string-x-data->x-cell (cbuf-get-x-data buf)
  ;;                                (cbuf-get-text-cur buf)
  ;;                                (cbuf-get-tab-size buf)))
  (string-x-data->x-cell (cbuf-get-x-data buf)
                         (cbuf-get-text-cur buf)
                         (cbuf-get-tab-size buf)))

(define (cbuf-append-undo-list! buf cmd)
  (cbuf-set-undo-list! buf (append (cbuf-get-undo-list buf)
                                   (list cmd))))

(define (cbuf-bracket-line buf L)
  "Return L if it is a valid line number for the current buffer, or
the nearest valid line number of L is out of range."
  (max 0
       (min L
            (- (cbuf-get-line-count buf) 1))))

(define (cbuf-bracket-pd buf pd)
  "Return pd if it is valid data position for the active line, or the
nearest valid data position for the active line if pd is out of
range."
  (max 0
       (min pd
            (string-base-length (cbuf-get-text-cur buf)))))

(define (cbuf-bracket-x-data buf x-data)
  "Return x-data if it is a valid data position for the active line, or
the nearest valid data position if x-data is out of range"
  (max 0
       (min x-data
            (string-base-length (cbuf-get-text-cur buf)))))

(define (cbuf-get-line-count buf)
  "Return the number of lines in the buffer"
  (length (cbuf-get-text buf)))

(define (cbuf-get-pp-from-pd-cur buf)
  "Find the presentation position of the active data position for the
current line."
  (cbuf-count-cells-in-substring (cbuf-get-text-cur buf) (cbuf-get-pd-cur buf) 0 (cbuf-get-tab-size buf)))

(define (cbuf-get-pp-max buf)
  (or (last (cbuf-get-pp-list buf))
      0))

(define (cbuf-get-text-cur buf)
  "Return the text of the active line"
  (list-ref (cbuf-get-text buf) (cbuf-get-line-cur buf)))

(define (cbuf-get-line-text buf n)
  "Return the text of line N"
  (list-ref (cbuf-get-text buf) n))

(define (cbuf-get-text-cur-length buf)
  "Return the number of codepoints in the active line"
  (string-length (cbuf-get-text-cur buf)))

(define (cbuf-increase-pd-cur! buf n)
  (cbuf-set-pd-cur! buf (+ (cbuf-get-pd-cur buf) n)))

(define (render-line str tabsize pp-start pp-length)
  "Return the substring of str constrained by the presentation columns.
Tabs are converted to spaces, and characters that would be clipped by
the edges are replaced with spaces."
  (let* ([pp-end (+ pp-start pp-length)]
         [pp-list (cbuf-compute-pp-list-from-string str tabsize)]
         ;; The index of the first character past the start of the window
         [i-start (list-index (lambda (x) (>= x pp-start)) pp-list)]
         ;; The index of the first character past endthe window
         [i-end (list-index (lambda (x) (> x pp-end)) pp-list)]
         ;; The number of left-side spaces needed
         [left-padding (min pp-length
                            (if i-start
                                (- (list-ref pp-list i-start) pp-start)
                                pp-length))]
         ;; #t if the last character straddles the frame
         [truncated-p (and i-end (> (list-ref pp-list i-end) pp-end))]
         ;; The number of cells that the windowed string occupies
         [str-pp-size (cond
                       [(and (not i-start) (not i-end))
                        ;; window starts after string
                        0]
                       [(and i-start (not i-end))
                        ;; string starts in window and ends before window
                        (- (last pp-list) (list-ref pp-list i-start))]
                       [(= i-start i-end)
                        ;; string starts after window
                        0]
                       [(and (= i-start (- i-end 1))
                             truncated-p)
                        ;; the only character is truncated
                        0]
                       [else
                        ;; the normal case
                        (if truncated-p
                            (- (list-ref pp-list (- i-end 1))
                               (list-ref pp-list i-start))
                            ;; else
                            (- (list-ref pp-list i-end)
                               (list-ref pp-list i-start)))])]
         [right-padding (- pp-length (+ left-padding str-pp-size))])

    (format (current-error-port) "~s ~s ~s~%" left-padding str-pp-size right-padding)
    (string-append
     ;; Space padding for initial truncated characters
     (make-string left-padding #\space)
     ;; Main list
     (cond
      [(not i-start)
       ""]
      [i-start
       (let ([inner-str ""])
         (do ([i i-start (+ i 1)]) ([>= i (- (or i-end (length pp-list)) 1)])
           (if (char=? #\tab (string-ref str i))
               (set! inner-str (string-append inner-str (make-string (- (list-ref pp-list (+ i 1)) (list-ref pp-list i)) #\space)))
               (set! inner-str (string-append inner-str (string (string-ref str i))))))
         inner-str)])
     ;; End of line space padding
     (make-string right-padding #\space))))

(define (cbuf-set-line-cur! buf n)
  (%cbuf-set-line-cur! buf n)
  (cbuf-update-pp-list! buf))
(define (cbuf-set-y! buf n)
  (%cbuf-set-y! buf n)
  (cbuf-update-pp-list! buf))

(define (cbuf-set-positions! buf n device)
  "When device is 'data, set the active data position to N and the
active presentation position and presentation position goal to the
beginning of grapheme at data position N.  When device is
'presentation, set the presentation position goal to N, the active
presentation position to the beginning of the grapheme at presentation
position N, and the active data position to the data position of that
grapheme."
  (cond
   [(eq? device 'data)
    (cbuf-set-pd-cur! buf n)
    (cbuf-update-pp-cur! buf)
    (cbuf-synchronize-pp! buf)]
   [(eq? device 'presentation)
    (let ([ind (list-index (lambda (x) (> x n)) (cbuf-get-pp-list buf))])
      (cbuf-set-pp-goal! buf n)
      (if ind
          (cbuf-set-pd-cur! buf (max 0 (- ind 1)))
          ;; else
          (cbuf-set-pd-cur! buf (last (cbuf-get-pp-list buf))))
      (cbuf-update-pp-cur! buf))]
   [else
    (error "FIXME !!#!")]))

(define (cbuf-set-x! buf x type)
  "This procedure sets the x-data and x-goal values for this buffer.
The TYPE parameter indicates the type of X, whether X is an 'index,
a 'data or a 'cell position.

If TYPE is 'index in a string in which there are multi-codepoint
characters consisting of base characters and continuation marks, the
distinction of whether you are pointing to a base character or a
continuation mark is not preserved, since x-data always indicates a
base character.

Likewise, if TYPE is 'cell and that location is not the first cell of
a multi-cell character, x-goal will be set to the given location, but,
x-data will point to the data position of the base character at that
cell position."
  (cond
   [(eq? type 'index)
    (cbuf-set-x-data! buf
                      (string-count-base-codepoints-in-substring
                       (cbuf-get-text-cur buf) 0 x))
    (cbuf-synchronize-x-goal! buf)]

   [(eq? type 'data)
    (cbuf-set-x-data! buf x)
    (cbuf-synchronize-x-goal! buf)]

   [(eq? type 'cell)
    (let* ([txt (cbuf-get-text-cur buf)]
           [base-cell-list (string-compute-x-cell-list-from-string
                            (string-base txt)
                            (cbuf-get-tab-size buf))]
           [one-past-index (list-index (lambda (i) (> i x))
                                       base-cell-list)])
      (cond
       ;; We found a corresponding base character data location.
       [one-past-index
        (cbuf-set-x-data! buf (- one-past-index 1))
        (cbuf-set-x-goal! buf x)]
       ;; Otherwise, this x-index points to either the last
       ;; character of the string or past the end of the string.
       [(= x (last base-cell-list))
        (cbuf-set-x-data! buf (last base-cell-list))
        (cbuf-set-x-goal! buf x)]
       [else
        (raise (condition (&error)))]))]
   [else
    (error "bad cbuf-set-x! type" type)]))

(define (cbuf-set-text-cur! buf str)
  (cbuf-set-text! buf (list-set (cbuf-get-text buf) (cbuf-get-line-cur buf) str)))

(define (cbuf-synchronize-pp! buf)
  "Set the presentation position goal to the active presentation
position"
  (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf)))

(define (cbuf-synchronize-x-goal! buf)
  ;;(format #t "In cbuf-synchronize-x-goal! ~s~%" buf)
  (let* ([txt (cbuf-get-text-cur buf)]
         [x-data (cbuf-get-x-data buf)]
         [tabsize (cbuf-get-tab-size buf)]
         [x-goal (string-x-data->x-cell x-data txt tabsize)])
    (cbuf-set-x-goal! buf x-goal)))

(define (cbuf-compute-tab-column pos tabsize n)
  "If N is positive, compute the presentation position of the nth next
forward tabulation.  If N is negative, compute the position of the
backward tabulation.  This function does not do bracketing."
  (cond
   [(< n 0)
    ;; Back up n tabsizes
    (let* ([pp1 (+ pos (* n tabsize))]
           ;; Move forward to a tab stop
           [pp2 (cond
                 [(zero? (remainder pp1 tabsize))
                  pp1]
                 [(> pp1 0)
                  (* tabsize (+ (quotient pp1 tabsize) 1))]
                 [(< pp1 0)
                  (* tabsize (quotient pp1 tabsize))])])
      pp2)]
   [(= n 0)
    pos]
   [(> n 0)
    ;; Advance n tabsizes
    (let* ([pp1 (+ pos (* n tabsize))]
           ;; Move backward to a tab stop
           [pp2 (* tabsize (quotient pp1 tabsize))])
      pp2)]))

(define (cbuf-update-pp-cur! buf)
  "Sets the active presentation position to the match the beginning
of the character at the active data position"
  (cbuf-set-pp-cur! buf (list-ref (cbuf-get-pp-list buf) (cbuf-get-pd-cur buf))))

(define (cbuf-update-pp-list! buf)
  (cbuf-set-pp-list! buf
                     (cbuf-compute-pp-list-from-string (cbuf-get-text-cur buf)
                                                       (cbuf-get-tab-size buf))))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; KEYPRESS METHODS
;;
;; These methods are the typical responses in an editor widget when
;; a codepoint is received as a response to a keypress.

;; [ICP]
(define (cbuf-insert-codepoint buf char-new undoable)
  "Inserts the given codepoint into the active data position.

If the character being inserted is a combining mark, it is inserted
before the active data position so that it combines with the character
before the active data position.  The position is not advanced.  If
the character before the active data position is not a suitable base
character, an error is thrown.

Otherwise, it is inserted before the character at the active data
position, pushing the remaining characters in the line to the
right. Then the active position is incremented.  If a mark occurs
after the current data position in the current line, it is shifted to
the right."
  (let* ([txt (cbuf-get-text-cur buf)]
         [len (string-base-length txt)]
         [x-data (cbuf-get-x-data buf)]
         [x-index (string-x-data->x-index x-data txt)]
         [x-cell (cbuf-get-x-cell buf)]
         [x-goal (cbuf-get-x-goal buf)]
         [y (cbuf-get-y buf)]
         [char-prev (if (> x-data 0) (string-ref txt (- x-data 1)) #f)])
    (cond
     [(char-combining-mark? char-new)
      ;; Check for inappropriate base character / combining-mark pairs
      (when (and char-prev
                 (not (char-base? char-prev)))
        (raise (condition (&cbuf-combining-mark-error
                           (previous char-prev)
                           (current char-new)
                           (next (if (< x-data len) (string-ref txt x-data)))))))
      ;; Insert the character
      (cbuf-set-text-cur!
       buf (string-append (substring txt 0 x-index)
                          (string char-new)
                          (substring txt x-index)))]
     [else
      ;; Insert the character
      (cbuf-set-text-cur!
       buf (string-append (substring txt 0 x-index)
                          (string char-new)
                          (substring txt x-index)))
      ;; Move the mark
      (when (and (cbuf-is-mark-set? buf)
                 (>= (cbuf-get-x-mark buf) x-data)
                 (= (cbuf-get-y-mark buf) y))
        (cbuf-set-x-mark! buf (+ 1 x-data)))

      ;; Move the cursor forward.
      (cbuf-set-x! buf (+ 1 x-data) 'data)])

    (when undoable
      (cbuf-append-undo-list! buf `(%DC ,x-data))
      (cbuf-append-undo-list! buf `(%POS ,x-data ,x-cell ,x-goal)))))

;; ;; [%IHT]
;; (define (cbuf-insert-horizontal-tabulation buf device undoable)
;;   "Inserts #\tab into the active position, shifting other characters
;; to the right.

;; If a mark is to the right of the active position, it is moved to the
;; right.

;; Afterward, the active data and presentation positions are moved to the
;; following tab stop."
;;   (let ([pd (cbuf-get-pd-cur buf)]
;;         [txt (cbuf-get-text-cur buf)])
;;     (cond

;;      ;; If we're overwriting a tab with a tab
;;      [(and (< pd(string-length txt))
;;          (eqv? #\tab (string-ref txt pd)))
;;     ;; Clear the mark if we're overwriting the mark
;;       (when (and (cbuf-is-mark-set? buf)
;;                  (= (cbuf-get-pd-mark buf) pd)
;;                  (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
;;         (cbuf-set-mark-flag! buf #f))
;;       ;; Don't replace anything, but move the cursor forward
;;       (cbuf-set-pd-cur! buf (+ 1 pd))
;;       (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
;;       (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))]

;;      ;; If we're overwriting a non-tab character in DATA mode
;;      [(and (eqv? device 'data) (< pd (string-length txt)))
;;       (let* ([old-cp (string-ref txt pd)])
;;         (cbuf-set-text-cur! buf (string-append (substring txt 0 pd)
;;                                                (string #\tab)
;;                                                (substring txt
;;                                                           (min (string-length txt) (+ 1 pd))
;;                                                           (string-length txt))))
;;         ;; Clear the mark if we're overwriting the mark
;;         (or (and (cbuf-is-mark-set? buf)
;;                  (= (cbuf-get-pd-mark buf) pd)
;;                  (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
;;             (cbuf-set-mark-flag! buf #f))
;;         ;; Move the cursor forward
;;         (cbuf-update-pp-list! buf)
;;         (cbuf-set-pd-cur! buf (+ 1 pd))
;;         (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
;;         (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))
;;         (or undoable
;;             (cbuf-append-undo-list! buf `((%CHAR ,old-cp ,pd)))))]

;;      ;; If we're appending a tab to the end of the line in DATA mode
;;      [(and (eqv? device 'data) (= pd (string-length (cbuf-get-text-cur buf))))
;;       (let* ([txt (cbuf-get-text-cur buf)]
;;              [pd (cbuf-get-pd-cur buf)])
;;         (cbuf-set-text-cur! buf (string-append txt "\t"))
;;         ;; Clear the mark if we're overwriting the mark
;;         (or (and (cbuf-is-mark-set? buf)
;;                  (= (cbuf-get-pd-mark buf) pd)
;;                  (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
;;             (cbuf-set-mark-flag! buf #f))
;;         ;; Move the cursor forward
;;         (cbuf-update-pp-list! buf)
;;         (cbuf-set-pd-cur! buf (+ 1 pd))
;;         (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
;;         (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))
;;         (or undoable
;;             (cbuf-append-undo-list! buf `((%DCH ,pd)))))]

;;      [(eqv? device 'presentation)
;;       (let* ([ppList (cbuf-compute-pp-list-from-string (cbuf-get-text-cur buf)
;;                                                        (cbuf-get-tab-size buf))]
;;              [tabsize (cbuf-get-tab-size buf)]
;;              ;; Presentation position of start of tab
;;              [pp-start (cbuf-get-pp-cur buf)]
;;              ;; Presentation position of next tab stop
;;              [pp-end (* tabsize (quotient (+ pp-start tabsize) tabsize))]
;;              ;; if we've moved past the end of the line...
;;              [pp3 (min pp-end (last ppList))]

;;              ;; Data position of start of tab, being careful to include
;;              ;; the beginning of wide characters
;;              [pd1 (list-index (lambda (x) (> x pp-start)) ppList)]
;;              [pd-start (if pd1
;;                            (max 0 (+ -1 pd1))
;;                            ;; else
;;                            (last ppList))]

;;              ;; Data position of end of tab
;;              [pd2 (list-index (lambda (x) (> x pp3)) ppList)]
;;              [pd-end (if pd2
;;                          (max 0 (+ -1 pd2))
;;                          ;; else
;;                          (last ppList))]

;;              ;; Presentation of start of tab, including padding for wide
;;              ;; characters
;;              [pp-adj-start (list-ref ppList pd-start)]
;;              [pp-adj-end (max pp-end (list-ref ppList pd-end))]
;;              [space-num (- pp-adj-end pp-adj-start)]
;;              [txt (cbuf-get-text-cur buf)])

;;         ;; Replace the tab characters with spaces
;;         (cbuf-set-text-cur! buf (string-append (substring txt 0 pd-start)
;;                                           (make-string space-num #\space)
;;                                           (substring txt pd-end (string-length txt))))
;;         (cbuf-set-pd-cur! buf (+ pd-start space-num))
;;         (cbuf-set-pp-cur! buf pp-adj-end)
;;         (cbuf-set-pp-goal! buf pp-adj-end))
;;       ;; FIXME: move the mark
;;       ])))



                                        ;(define (char-printing? x)
                                        ;  (char-set<= (->char-set #\x) char-set:printing))

;;; CP
                                        ;(define (cbuf-write-codepoint buf ch device undoable)
                                        ;  "Processes the codepoint CP.
                                        ;
                                        ;If CP is #\\alarm, the bell state for the buffer is set.
                                        ;
                                        ;If CP is #\\delete, the character at the current location is deleted.
                                        ;
                                        ;If CP is a #\\backspace or #\\return, the cursor is moved accordingly.
                                        ;
                                        ;If CP is #\\tab, #\\vtab, #\\newline, or any graphical character, it
                                        ;writes CP into the active position, overwriting any current character.
                                        ;If DEVICE is 'data, the codepoint at the current data position is
                                        ;replaced with C.  If DEVICE is 'presentation, the codepoint is written
                                        ;at the current presentation position, and those graphemes that would
                                        ;be wholly or partly overwritten by this grapheme will be erased before
                                        ;this grapheme is added.
                                        ;
                                        ;If a mark is overwritten, it is removed.
                                        ;
                                        ;Afterward, the active data and presentation positions are moved to
                                        ;the location following the character.
                                        ;
                                        ;Returns #t if the character was processed, and #f otherwise.
                                        ;
                                        ;The C1 controls NEL, and CCH should be processed.  HTS, HTJ, and VTS
                                        ;should be processed when the functionality is ready.  CSI should
                                        ;introduce a command sequence."
                                        ;  (cond
                                        ;   ((= ch alarm-char)
                                        ;    (cbuf-bell buf #t))
                                        ;   ((= ch #\backspace)
                                        ;    (cbuf-cursor-left buf 1 #t))
                                        ;   ((= ch #\tab)
                                        ;    (cbuf-write-horizontal-tabulation buf device #t))
                                        ;   ((= ch #\newline)
                                        ;    (cbuf-write-newline buf device #t))
                                        ;   ;;((= ch #\vtab)
                                        ;   ;; (cbuf-write-vertical-tabulation buf device #t))
                                        ;   ((= ch #\return)
                                        ;    (cbuf-carriage-return buf #t))
                                        ;   ((= ch delete-char)
                                        ;    (delete-character buf 1 device #t))
                                        ;   (else
                                        ;    (cbuf-write-printing buf ch device #t))))

;; ;; [%WHT]
;; (define (cbuf-write-horizontal-tabulation buf device undoable)
;;   "Writes #\tab into the active position, overwriting any current character.
;; If DEVICE is 'data, the codepoint at the current data position is
;; replaced with #\tab.  If DEVICE is 'presentation, the tab is written
;; at the current presentation position, and those between the
;; current presentation position and the next horizontal tab stop will
;; be overwritten.

;; If a mark is overwritten, it is removed. If the mark occurs later in
;; the current line, is is moved accordingly.

;; Afterward, the active data and presentation positions are moved to
;; the following tab stop."
;;   (let ([pd (cbuf-get-pd-cur buf)]
;;         [txt (cbuf-get-text-cur buf)])
;;     (cond

;;      ;; If we're overwriting a tab with a tab
;;      [(and (< pd(string-length txt))
;;          (eqv? #\tab (string-ref txt pd)))
;;     ;; Clear the mark if we're overwriting the mark
;;       (when (and (cbuf-is-mark-set? buf)
;;                  (= (cbuf-get-pd-mark buf) pd)
;;                  (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
;;         (cbuf-set-mark-flag! buf #f))
;;       ;; Don't replace anything, but move the cursor forward
;;       (cbuf-set-pd-cur! buf (+ 1 pd))
;;       (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
;;       (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))]

;;      ;; If we're overwriting a non-tab character in DATA mode
;;      [(and (eqv? device 'data) (< pd (string-length txt)))
;;       (let* ([old-cp (string-ref txt pd)])
;;         (cbuf-set-text-cur! buf (string-append (substring txt 0 pd)
;;                                                (string #\tab)
;;                                                (substring txt (min (string-length txt) (+ 1 pd)) (string-length txt))))
;;         ;; Clear the mark if we're overwriting the mark
;;         (and (cbuf-is-mark-set? buf)
;;              (= (cbuf-get-pd-mark buf) pd)
;;              (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf))
;;              (cbuf-set-mark-flag! buf #f))
;;         ;; Move the cursor forward
;;         (cbuf-update-pp-list! buf)
;;         (cbuf-set-pd-cur! buf (+ 1 pd))
;;         (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
;;         (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))
;;         (and undoable
;;              (cbuf-append-undo-list! buf `((%CHAR ,old-cp ,pd)))))]

;;      ;; If we're appending a tab to the end of the line in DATA mode
;;      [(and (eqv? device 'data) (= pd (string-length (cbuf-get-text-cur buf))))
;;       (let* ([txt (cbuf-get-text-cur buf)]
;;              [pd (cbuf-get-pd-cur buf)])
;;         (cbuf-set-text-cur! buf (string-append txt "\t"))
;;         ;; Clear the mark if we're overwriting the mark
;;         (and (cbuf-is-mark-set? buf)
;;              (= (cbuf-get-pd-mark buf) pd)
;;              (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf))
;;              (cbuf-set-mark-flag! buf #f))
;;         ;; Move the cursor forward
;;         (cbuf-update-pp-list! buf)
;;         (cbuf-set-pd-cur! buf (+ 1 pd))
;;         (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
;;         (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))
;;         (and undoable
;;              (cbuf-append-undo-list! buf `((%DCH ,pd)))))]

;;      [(eqv? device 'presentation)
;;       (let* ([ppList (cbuf-compute-pp-list-from-string (cbuf-get-text-cur buf)
;;                                                        (cbuf-get-tab-size buf))]
;;              [tabsize (cbuf-get-tab-size buf)]
;;              ;; Presentation position of start of tab
;;              [pp-start (cbuf-get-pp-cur buf)]
;;              ;; Presentation position of next tab stop
;;              [pp-end (* tabsize (quotient (+ pp-start tabsize) tabsize))]
;;              ;; if we've moved past the end of the line...
;;              [pp3 (min pp-end (last ppList))]

;;              ;; Data position of start of tab, being careful to include
;;              ;; the beginning of wide characters
;;              [pd1 (list-index (lambda (x) (> x pp-start)) ppList)]
;;              [pd-start (if pd1
;;                            (max 0 (+ -1 pd1))
;;                            ;; else
;;                            (last ppList))]

;;              ;; Data position of end of tab
;;              [pd2 (list-index (lambda (x) (> x pp3)) ppList)]
;;              [pd-end (if pd2
;;                          (max 0 (+ -1 pd2))
;;                          ;; else
;;                          (last ppList))]

;;              ;; Presentation of start of tab, including padding for wide
;;              ;; characters
;;              [pp-adj-start (list-ref ppList pd-start)]
;;              [pp-adj-end (max pp-end (list-ref ppList pd-end))]
;;              [space-num (- pp-adj-end pp-adj-start)]
;;              [txt (cbuf-get-text-cur buf)])

;;         ;; Replace the tab characters with spaces
;;         (cbuf-set-text-cur! buf (string-append (substring txt 0 pd-start)
;;                                                (make-string space-num #\space)
;;                                                (substring txt pd-end (string-length txt))))
;;         (cbuf-set-pd-cur! buf (+ pd-start space-num))
;;         (cbuf-set-pp-cur! buf pp-adj-end)
;;         (cbuf-set-pp-goal! buf pp-adj-end))
;;       ;; FIXME: move the mark
;;       ])))


;; [INL]
(define (cbuf-insert-newline buf undoable)
  "Splits the current line into two lines.  The first line will
consist of the characters from the beginning of the line to just
before the active data position.  The second line will contain the
remaining characters in the original line.  The cursor is placed at
the beginning of the new line.

The mark will be moved if necessary."
  (let* ([txt (cbuf-get-text-cur buf)]
         [x-data (cbuf-get-x-data buf)]
         [x-index (string-x-data->x-index x-data txt)]
         [x-cell (cbuf-get-x-cell buf)]
         [y (cbuf-get-y buf)]
         [txt-list (cbuf-get-text buf)]
         [len (string-length txt)]
         [txt1 (substring txt 0 x-index)]
         [txt2 (substring txt x-index len)])

    ;; Split the lines
    (if (string-null? txt)
        (cbuf-set-text! buf (append (take txt-list y)
                                    (list "")
                                    (drop txt-list y)))
        (cbuf-set-text! buf (append (take txt-list y)
                                    (list txt1 txt2)
                                    (drop txt-list (+ y 1)))))
    (cbuf-set-y! buf (+ y 1))
    (cbuf-set-x! buf 0 'data)

    ;; Move the mark, if necessary
    (let ([y-mark (cbuf-get-y-mark buf)]
          [x-mark (cbuf-get-x-mark buf)])
      (when (cbuf-is-mark-set? buf)
        (cond
         [(> y-mark y)
          (cbuf-set-y-mark! buf (+ y-mark 1))]
         [(and (= y-mark y) (>= x-mark x-data))
          (cbuf-set-x-mark! buf (- x-mark x-data))
          (cbuf-set-y-mark! buf (+ y-mark 1))])))
    (when undoable
      (cbuf-append-undo-list! buf `(%JOIN ,y)))))

;; [DEL]
(define (cbuf-del buf copy undoable)
  "If the mark is set, it deletes all the text from the mark to the
active position.  If the mark is before the data position, the delete
region includes the character at the mark and excludes the character
at the active data position.  If the mark is after the data position,
the region includes the active data position and excludes the
character at the mark.  Afterwards, the mark is cleared.

If the mark and the active data position are equal, nothing is
cut and the mark is not cleared.

If COPY is #t, any deleted text will be placed in the copy/paste
buffer.

An error will be thrown if the cut will split a multi-codepoint
character consisting of a base character and combining marks."
  #f)

;; [CPY]
(define (cbuf-copy buf device undoable)
  "If the mark is set, it makes a copy of all the text from the mark
to the active position and places it in the copy/paste buffer.  If the
mark is before the data position, the copy includes the character at
the mark and excludes the character at the active data position.  If
the mark is after the data position, the copy includes the active data
position and excludes the character at the mark.  Afterwards, the mark
is cleared.

If the mark and the active data position are equal, nothing is
copied and the mark is not cleared.

An error will be thrown if the copy will split a multi-codepoint
character consisting of a base character and combining marks."
  #f)

;; [PST]
(define (cbuf-paste buf device undoable)
  "This inserts the contents of the copy/paste buffer at the active
data position.

An error will be thrown if the paste will split a multi-codepoint
character consisting of a base character and combining marks."
  #f)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ECMA-48-like CONTROL METHODS


;; BEL
(define (cbuf-bell buf)
  "Sets the alarm state"
  (or (cbuf-get-bell buf)
      (begin
        (cbuf-set-bell! buf #t)
        (and undoable
             (cbuf-append-undo-list! buf '(%CBL))))))
;; BS
(define (cbuf-backspace buf undoable)
  "Move the active data position to the previous data position.  If
the previous character is a multi-codepoint character with a base
character and combining marks, the position is moved to the base
codepoint of the previous character."
  (let ([pp (cbuf-get-pp-cur buf)]
        [pd (cbuf-get-pd-cur buf)]
        [pp-goal (cbuf-get-pp-goal buf)])
    (and (> pd 0)
         (begin
           (cbuf-increase-pd-cur! buf -1)
           (cbuf-update-pp-cur! buf)
           (cbuf-synchronize-pp! buf)
           (and undoable
                (cbuf-append-undo-list! buf `(%POS ,pd ,pp ,pp-goal)))))))

;; CAN
(define (cbuf-cancel buf)
  "Cancel the previous command"
  (%undo buf))

;; [%CBL]
(define (%clear-bell buf undoable)
  "Clears the alarm state"
  (and (cbuf-get-bell buf)
       (begin
         (cbuf-set-bell! buf #f)
         (and undoable
              (cbuf-append-undo-list! buf '(BEL))))))

;; CBT
(define (cbuf-cursor-backward-tabulation buf n undoable)
  "Move the active presentation position to the character position
corresponding to the n-th preceding character tabulation stop in the
presentation component"
  (let* ([ppCur (cbuf-get-pp-cur buf)]
         [pdCur (cbuf-get-pd-cur buf)]
         [ppGoal (cbuf-get-pp-goal buf)]
         [tabsize (cbuf-get-tab-size buf)]
         ;; Back up n tabsizes
         [pp1 (max 0 (cbuf-compute-tab-column ppCur tabsize (- n)))])
    (or (= pp1 ppCur)
        (begin
          (cbuf-set-positions! buf pp1 'presentation)
          (and undoable
               (cbuf-append-undo-list! buf `(%POS ,pdCur ,ppCur ,ppGoal)))))))

;; CCH - UNIMPLEMENTED
(define (cancel buf)
  "Undo the previous graphic character"
  #f)

;; CHA
(define (cbuf-cursor-character-absolute buf n undoable)
  "Move the active presentation position to character position n in
the active line in the presentation component"
  (let ([pp (cbuf-get-pp-cur buf)]
        [pd (cbuf-get-pd-cur buf)]
        [pp-goal (cbuf-get-pp-goal buf)])
    (or (and (= n pp) (= n pp-goal))
        (begin
          (cbuf-set-positions! buf n 'presentation)
          (and undoable
               (cbuf-append-undo-list! buf `(%POS ,pd ,pp ,pp-goal)))))))

;; CHT
(define (cbuf-cursor-forward-tabulation buf n undoable)
  "Move the active presentation position to the character position
corresponding to the n-th following character tabulation stop in the
presentation component"
  (let* ([ppCur (cbuf-get-pp-cur buf)]
         [pdCur (cbuf-get-pd-cur buf)]
         [ppGoal (cbuf-get-pp-goal buf)]
         [tabsize (cbuf-get-tab-size buf)]
         ;; Move forward n tabsizes
         [pp1 (cbuf-compute-tab-column ppCur tabsize n)])
    (or (= pp1 ppCur)
        (begin
          (cbuf-set-positions! buf pp1 'presentation)
          (and undoable
               (cbuf-append-undo-list! buf `(%POS ,pdCur ,ppCur ,ppGoal)))))))

;; CNL
(define (cbuf-cursor-next-line buf n undoable)
  "Move the active presentation position to the 1st character position
of the n-th following line in the presentation component"
  (let* ([LCur (cbuf-get-line-cur buf)]
         ;; Move forward n lines, or to the end of the buffer
         [L1 (cbuf-bracket-line buf (+ LCur n))])
    (and (> L1 (cbuf-get-line-cur buf))
         (let ([ppCur (cbuf-get-pp-cur buf)]
               [pdCur (cbuf-get-pd-cur buf)]
               [ppGoal (cbuf-get-pp-goal buf)])
           (cbuf-set-line-cur! buf L1)
           (cbuf-update-pp-list! buf)
           (cbuf-set-positions! buf 0 'data)
           (and undoable
                (cbuf-append-undo-list! buf `(%LPOS ,LCur ,pdCur ,ppCur ,ppGoal)))))))

;; CPL
(define (cbuf-cursor-preceding-line buf n undoable)
  "Move the active presentation position to the 1st character position
of the n-th preceding line in the presentation component"
  (let* ([LCur (cbuf-get-line-cur buf)]
         ;; Move backward n lines, or to the beginning of the buffer
         [L1 (cbuf-bracket-line buf (- LCur n))])
    (and (< L1 (cbuf-get-line-cur buf))
         (let ([ppCur (cbuf-get-pp-cur buf)]
               [pdCur (cbuf-get-pd-cur buf)]
               [ppGoal (cbuf-get-pp-goal buf)])
           (cbuf-set-line-cur! buf L1)
           (cbuf-update-pp-list! buf)
           (cbuf-set-positions! buf 0 'data)
           (and undoable
                (cbuf-append-undo-list! buf `(%LPOS ,LCur ,pdCur ,ppCur ,ppGoal)))))))

;; CR
(define (cbuf-carriage-return buf undoable)
  "Move the active presentation position to the line home position of
the same line.  The line home position can be set using `set-line-home'
and by setting the Device Control Select Mode (DCSM) using `set-mode'"
  (let ([home-type (cbuf-get-limit-type buf)]
        [home-pos (cbuf-get-home-pos buf)]
        [pd (cbuf-get-pd-cur buf)]
        [pp (cbuf-get-pp-cur buf)]
        [ppGoal (cbuf-get-pp-goal buf)])
    (and (not (or (and (eq? home-type 'data) (= pd home-pos))
                  (and (eq? home-type 'presentation) (= pp home-pos))))
         (begin
           (cbuf-set-positions! buf home-pos home-type)
           (and undoable
                (cbuf-append-undo-list! buf `(%POS ,pd ,pp ,ppGoal)))))))

;; CTC
(define (cbuf-cursor-tabulation-control buf n)
  "Set the number of spaces per tab to N"
  (cbuf-set-tab-size! buf n))

;; CUB
(define (cbuf-cursor-left buf n undoable)
  "Move the active presentation position leftwards in the presentation
component by n character positions"
  (let ([pd (cbuf-get-pd-cur buf)]
        [pp (cbuf-get-pp-cur buf)]
        [ppGoal (cbuf-get-pp-goal buf)])
    (and (not (= pp 0))
         (begin
           (cbuf-set-positions! buf (max 0 (- pp n)) 'presentation)
           (and undoable
                (cbuf-append-undo-list! buf `(%POS ,pd ,pp ,ppGoal)))))))

;; CUD
(define (cbuf-cursor-down buf n undoable)
  "Move the active presentation position downwards in the presentation
component by N line positions"
  (let ([pd (cbuf-get-pd-cur buf)]
        [pp (cbuf-get-pp-cur buf)]
        [ppGoal (cbuf-get-pp-goal buf)]
        [LCur (cbuf-get-line-cur buf)])
    (and (< LCur (+ -1 (cbuf-get-line-count buf)))
         (begin
           (cbuf-set-line-cur! buf (cbuf-bracket-line buf (+ LCur n)))
           (cbuf-update-pp-list! buf)
           (cbuf-set-positions! buf ppGoal 'presentation)
           (and undoable
                (cbuf-append-undo-list! buf `(%LPOS ,LCur ,pd ,pp ,ppGoal)))))))

;; CUF
(define (cbuf-cursor-right buf n undoable)
  "Move the active presentation position rightwards in the
presentation component by N character cells.  If N character position
will place the active position in a non-initial cell of a multi-cell
character, the active position will be set to the beginning of the
character and the goal position will be set to that Nth cell."
  (let ([pd (cbuf-get-pd-cur buf)]
        [pp (cbuf-get-pp-cur buf)]
        [ppGoal (cbuf-get-pp-goal buf)])
    (and (not (= pp (cbuf-get-pp-max buf)))
         (begin
           (cbuf-set-positions! buf (min (cbuf-get-pp-max buf) (+ pp n)) 'presentation)
           (and undoable
                (cbuf-append-undo-list! buf `(%POS ,pd ,pp ,ppGoal)))))))

;; CUP
(define (cbuf-cursor-position buf n m)
  "Move the active presentation position to the n-th line and m-th
character position in the presentation component.

If M is beyond the end of the line, the active position will be
set to the end of the line; the goal column will be set to M, and
an end-of-line error will be thrown.

If N is beyond the end of the buffer, the active position will
be set to the Mth column of the last line, and an end-of-buffer
error will be thrown.

If N is beyond the end of the buffer, and M is beyond the end of the
last line, the active position will be set to the end of the last
line; the goal column will be set to the Mth cell, and an end-of-buffer
error will be thrown."
  (let ([y (cbuf-get-y buf)]
        [x-cell (cbuf-get-x-cell buf)]
        [x-goal (cbuf-get-x-goal buf)]
        [y-length (cbuf-get-line-count buf)]
        [tabsize (cbuf-get-tab-size buf)])
    (cond
     [(and (< n y-length)
           (<= m (string-cell-length (list-ref (cbuf-get-text buf) n) tabsize)))
      (cbuf-set-y! buf n)
      (cbuf-set-x! buf m 'cell)]
     [(and (< n y-length)
           (> m (string-cell-length (list-ref (cbuf-get-text buf) n) tabsize)))
      ;; Too wide
      (cbuf-set-y! buf n)
      (cbuf-set-x! buf (string-base-length (list-ref (cbuf-get-text buf) n)) 'data)
      (cbuf-set-x-goal! buf m)
      (raise (condition (&cbuf-end-of-line)))]
     [(and (>= n y-length)
           (<= m (string-cell-length (last (cbuf-get-text buf)) tabsize)))
      ;; Too far
      (cbuf-set-y! buf (+ -1 y-length))
      (cbuf-set-x! buf m 'cell)
      (raise (condition (&cbuf-end-of-buffer)))]
     [else
      ;; Too wide and too far
      (cbuf-set-y! buf (+ -1 y-length))
      (cbuf-set-x! buf (string-base-length (last (cbuf-get-text buf))) 'data)
      (cbuf-set-x-goal! buf m)
      (raise (condition (&cbuf-end-of-buffer)))])))

;; CUU
(define (cbuf-cursor-up buf n undoable)
  "Move the active presentation positions upwards in the presentation
component by N line positions"
  (let ([pd (cbuf-get-pd-cur buf)]
        [pp (cbuf-get-pp-cur buf)]
        [ppGoal (cbuf-get-pp-goal buf)]
        [LCur (cbuf-get-line-cur buf)])
    (and (> LCur 0)
         (begin
           (cbuf-set-line-cur! buf (cbuf-bracket-line buf (- LCur n)))
           (cbuf-update-pp-list! buf)
           (cbuf-set-positions! buf ppGoal 'presentation)
           (and undoable
                (cbuf-append-undo-list! buf `(%LPOS ,LCur ,pd ,pp ,ppGoal)))))))

;; CVT
(define (cbuf-cursor-line-tabulation buf n undoable)
  "Causes the active position to be moved to the corresponding goal
position of the line corresponding to the n-th following line
tabulation stop in the presentation component.  If that line is too
short to allow the active position to be set to the goal position, the
goal column will remain unchanged and the active position will be set
to the end of the line, and an end-of-line error will be thrown.

If the n-th following line tab stop is beyond the end of the buffer,
the active position will be set to the corresponding cell position in
the last available line and an end-of-buffer error will be thrown.
"
  (let* ([x-data (cbuf-get-x-data buf)]
         [x-cell (cbuf-get-x-cell buf)]
         [x-goal (cbuf-get-x-goal buf)]
         [y (cbuf-get-y buf)]
         [tabsize (cbuf-get-vert-tab-size buf)]
         [y2 (cbuf-compute-tab-column y tabsize n)])
    (cond
     [(and (< y2 (+ -1 (cbuf-get-line-count buf)))
           (<= x-goal (wcwidth (list-ref (cbuf-get-text buf) y2))))
      ;; The normal case
      (cbuf-set-y! buf y2)
      (cbuf-set-x! buf x-goal 'cell)]
     [(and (< y2 (+ -1 (cbuf-get-line-count buf)))
           (> x-goal (wcwidth (list-ref (cbuf-get-text buf) y2))))
      ;; Too wide
      (cbuf-set-y! buf y2)
      (cbuf-set-x! buf (wcwidth (list-ref (cbuf-get-text buf) y2)) 'position)
      (cbuf-set-x-goal! buf x-goal)
      (raise (condition (&cbuf-end-of-line)))]
     [(and (>= y2 (cbuf-get-line-count buf))
           (<= x-goal (wcwidth (last (cbuf-get-text buf)))))
      ;; Too far
      (cbuf-set-y! buf (+ -1 (cbuf-get-line-count buf)))
      (cbuf-set-x! buf x-goal 'cell)
      (raise (condition (&cbuf-end-of-buffer)))]
     [else
      ;; Too wide and too far
      (cbuf-set-y! buf (+ -1 (cbuf-get-line-count buf)))
      (cbuf-set-x! buf (string-base-length (last (cbuf-get-text buf))) 'data)
      (cbuf-set-x-goal! buf x-goal)
      (raise (condition (&cbuf-end-of-buffer)))])))

;; DA
(define (cbuf-device-attributes buf)
  "Returns a string identifying this class"
  "CBuffer 0.0")

;; DCH
(define (cbuf-delete-character buf n device cut undoable)
  "This removes the cells or characters at the active data position
and the n-1 following positions.  The characters to the right of the
deleted characters are moved left to fill in the gap.  If the active
data position is at the end of the line or if the delete operation would
exceed the line of the line, and end-of-line error is thrown.

If the mark was in the deleted characters, it is removed.  If was after
the deleted characters in the same line, it is adjusted.

If device is 'presentation, N indicates the number of character cells
to clear.  The the range of character cells to be deleted covers only
part of a multi-cell character, the entire multi-cell character is
deleted.

If device is 'data, N indicates the number of characters to clear.
Characters formed from a combination of a base character and
continuation marks will be counted as a single character.

If CUT is true, the deleted text is placed in the cut buffer.

If UNDOABLE is true, undo information for this operation is stored."
#f)
;; (let* ([txt (cbuf-get-text-cur buf)]
;;        [y (cbuf-get-y buf)]
;;        [x-data (cbuf-get-x-data buf)]
;;        [x-data-len (string-base-length txt)])
;;   (cond
;;    [(= len 0)
;;     #f]
;;    [(= x-data len)
;;     (when (and (cbuf-is-mark-set? buf)
;;                (= y (cbuf-get-mark buf))
;;                (= x-data (cbuf-get-x-data buf)))
;;       (cbuf-set-mark-flag! buf #f))
;;     (raise (condition (&cbuf-end-of-line)))]
;;    [else
;;     (let ([x-index (string-find-index-of-nth-base-codepoint txt x-data)]
;;           [x-index-next (string-find-index-of-nth-base-codepoint txt (min x-data-len (+ x-data n)))]
;;           [txt-cut (substring txt x-index x-index-next)])

;;       (cond
;;        [(eq? device 'presentation)
;;         (cbuf-set-text-cur! buf (string-append (make-string (+ -1 width) #\space)
;;                                                (substring txt 1 (string-length txt))))
;;         (else
;;          (cbuf-set-text-cur! buf (substring txt 1 (string-length txt)))))]
;;       [else
;;        (cond
;;         ((eq? device 'presentation)
;;          (cbuf-set-text-cur! buf (string-append (substring txt 0 (+ -1 pd))
;;                                                 (make-string (+ -1 width) #\space)
;;                                                 (substring txt pd (string-length txt)))))
;;         (else
;;          (cbuf-set-text-cur! buf (string-append (substring txt 0 (+ -1 pd))
;;                                                 (substring txt pd (string-length txt))))))])

;;     ;; (update-pd-list! buf)
;;     (cbuf-set-positions! buf pd 'data)))

;; DL
(define (cbuf-delete-line buf n cut undoable)
  "Causes the active line and the n-1 following lines to be removed
from the buffer.  The resulting gap is closed by moving the adjacent
lines up.  The cursor is placed at the home position of the active
line.  If all the lines to the end of the buffer had been deleted, a
new empty line is added so that the active data position remains on
the same line.  If the request delete operation would try to delete
lines beyond the end of the buffer, all the text to the end of the
buffer is deleted and an end-of-buffer error is thrown.

If the mark is set in the deleted area it is cleared.  If it is beyond
the deleted area, it is moved up.

If CUT is true, the deleted text is placed in the cut buffer.

If UNDOABLE is true, undo information is saved for this operation."
  (let* ([txt-list (cbuf-get-text buf)]
         [txt-len (length txt-list)]
         [y (cbuf-get-y buf)]
         [y-cut-length (min n (- (length txt-list) y))]
         [x-data (cbuf-get-x-data buf)]
         [x-cell (cbuf-get-x-cell buf)]
         [err #f])
    (when (> (+ y n) (length txt-list))
      (set! err 'eob))
    (cond
     ;; If
     [(>= (+ y n) (length txt-list))
      (when cut
        (cbuf-set-cut-buffer! buf (drop txt-list y)))
      (cbuf-set-text! buf (append (take txt-list y) (list "")))]
     [(> n 0)
      (when cut
        (cbuf-set-cut-buffer! buf (take (drop txt-list y) n)))
      (cbuf-set-text! buf (append (take txt-list y)
                                  (drop txt-list (+ y n))))])
    (cbuf-set-x! buf 0 'data)
    ;; Clear the mark if it is in the deleted region
    (when (and (cbuf-is-mark-set? buf)
               (>= (cbuf-get-y-mark buf) y)
               (< (cbuf-get-y-mark buf) (+ y n)))
      (cbuf-set-mark-flag! buf #f))
    ;; Move the mark if it is after the deleted region
    (when (and (cbuf-is-mark-set? buf)
               (>= (cbuf-get-y-mark buf) (+ y n)))
      (cbuf-set-y-mark! buf (- (cbuf-get-y-mark buf) n)))

    ;; Throw an error, if necessary
    (when err
      (raise (condition (&cbuf-end-of-buffer))))))

;; DSR
(define (cbuf-device-status-report buf device)
  "If the device is 'presentation, report the active presentation position as
line, position.  If device is 'data, report the active data position."
  (cond
   ((eq? device 'data)
    (cons (cbuf-get-y buf) (cbuf-get-x-data buf)))
   ((eq? device 'presentation)
    (cons (cbuf-get-y buf) (cbuf-get-x-cell buf)))
   (else
    (error "unknown device" device))))

;; ECH
(define (cbuf-erase-character buf device n cut undoable)
  "This replaces the character at the active data postion and the n-1
following with the space character.  If DEVICE is 'presentation,
multi-cell graphemes will be replaced with multiple space characters.
If DEVICE is 'data, the current codepoint will be replaced with a
single space character.

If the active data position is part of a base character with combining
marks, the base character and the combining marks will all be erased.

If the active data position is in a horizontal tabulation character,
the tab will be replaced with spaces.

If the active position is at the end of a line (which is not actually
a character) nothing happens.

If the mark is at the active position, it will be cleared.

If CUT is #t, the erased character will be placed in the copy/paste
buffer.

If UNDOABLE is true, undo information for this operation will be
saved."
  (let* ([txt (cbuf-get-text-cur buf)]
         [y (cbuf-get-y buf)]
         [x-data (cbuf-get-x-data buf)]
         [x-data-len (string-base-length txt)])
    (cond
     [(= x-data x-data-len)
      *unspecified*]
     [(eq? device 'data)
      (let* ([x-index (string-find-index-of-nth-base-codepoint txt x-data)]
             [x-index-next (string-find-index-of-nth-base-codepoint txt (+ x-data 1))]
             [txt-cut (substring txt x-index x-index-next)])
        (cbuf-set-text-cur! buf (string-append (substring txt 0 x-index)
                                               (substring txt x-index-next)))
        (cbuf-set-x! buf x-data 'data)
        ;; Clear the mark if its position has been erased
        (when (and (cbuf-is-mark-set? buf)
                   (= (cbuf-get-y-mark buf) y)
                   (>= (cbuf-get-x-mark buf) x-data)
                   (< (cbuf-get-x-mark buf) (+ x-data n)))
          (cbuf-set-mark-flag! buf #f))
        ;; If the mark is to the right of the active position, update
        ;; the mark's x position when an erased character takes up
        ;; multiple spaces
        (when (and (cbuf-is-mark-set? buf)
                   (= (cbuf-get-y-mark buf) y)
                   (>= (cbuf-get-x-mark buf) (+ x-data n)))
          (cbuf-set-x-mark! buf (+ (cbuf-get-x-mark buf) (- n 1))))
        ;; Store the erase text to the cut buffer, if necessary
        (when cut
          (cbuf-set-cut-buffer! buf (list txt-cut)))
        ;; Add undo information
        (when undoable
          (cbuf-append-undo-list! buf `(%XDCH ,y ,x-data txt-cut))))]
      [(eq? device 'presentation)
      (let* ([x-cell (cbuf-get-x-cell buf)]
             [x-index (string-find-index-of-nth-base-codepoint txt x-data)]
             [x-cell-next (min (wcwidth txt) (+ x-cell n))]
             [x-index-next (string-find-index-of-nth-cell txt x-cell-next (cbuf-get-tab-size buf))]
             [x-data-next (string-x-cell->x-data x-cell-next txt (cbuf-get-tab-size buf))])
        (cbuf-set-text-cur! buf (string-append (substring txt 0 x-index)
                                               (substring txt x-index-next)))
        (cbuf-set-x! buf x-cell 'cell)
        ;; Clear the mark if its position has been erased
        (when (and (cbuf-is-mark-set? buf)
                   (= (cbuf-get-y-mark buf) y)
                   (>= (cbuf-get-x-mark buf) x-data)
                   (< (cbuf-get-x-mark buf) x-data-next))
          (cbuf-set-mark-flag! buf #f))
        ;; If the mark is to the right of the active position, update
        ;; the mark's x position when an erased character takes up
        ;; multiple spaces
        (when (and (cbuf-is-mark-set? buf)
                   (= (cbuf-get-y-mark buf) y)
                   (>= (cbuf-get-x-mark buf) (+ x-data n)))
          (cbuf-set-x-mark! buf (+ (cbuf-get-x-mark buf) (- n 1))))
        ;; Store the erase text to the cut buffer, if necessary
        (when cut
          ;;FIXME: define txt-cut
          ;; (cbuf-set-cut-buffer! buf (list txt-cut))
          #t)
        ;; Add undo information
        (when undoable
          (cbuf-append-undo-list! buf `(%XDCH ,y ,x-data txt-cut))))]

)))

;; EL

;; [%EL0]
(define (%cbuf-erase-in-line-to-eol buf device cut undoable)
  "Replace pos to eol with space."
  (let* ([txt (cbuf-get-text-cur buf)]
         [y (cbuf-get-y buf)]
         [x-data (cbuf-get-x-data buf)]
         [x-index (string-find-index-of-nth-base-codepoint txt x-data)]
         [txt-cut (substring txt x-index)]
         [n-spaces (cond ((eq? device 'presentation)
                          (wcwidth txt-cut))
                         (else
                          (string-base-length txt-cut)))])
    (cbuf-set-text-cur! buf (string-append (substring txt 0 x-index)
                                           (make-string n-spaces #\space)))
    (cbuf-set-x! buf x-data 'data)
    ;; Clear the mark if its position has been erased
    (when (and (cbuf-is-mark-set? buf)
               (= (cbuf-get-y-mark buf) (cbuf-get-y buf))
               (>= (cbuf-get-x-mark buf) x-data))
      (cbuf-set-mark-flag! buf #f))
    ;; Store the erase text to the cut buffer, if necessary
    (when cut
      (cbuf-set-cut-buffer! buf (list txt-cut)))
    ;; Add undo information
    (when undoable
      (cbuf-append-undo-list! buf `(%XEL0 ,y ,x-data txt-cut n-space)))))

;; [%EL1]
(define (%cbuf-erase-in-line-from-bol buf device cut undoable)
  "Replace bol to pos with space."
  (let* ([txt (cbuf-get-text-cur buf)]
         [y (cbuf-get-y buf)]
         [x-data (cbuf-get-x-data buf)]
         [x-index (string-find-index-of-nth-base-codepoint txt x-data)]
         [x-cell (cbuf-get-x-cell buf)]
         [txt-cut (substring txt 0 x-index)]
         [n-spaces (cond ((eq? device 'presentation)
                          (wcwidth txt-cut))
                         (else
                          (string-base-length txt-cut)))])
    (cbuf-set-text-cur! buf (string-append (make-string n-spaces #\space)
                                           (substring txt x-index)))
    (if (eq? device 'presentation)
        (cbuf-set-x! buf x-cell 'cell)
        (cbuf-set-x! buf x-data 'data))
    (when (and (cbuf-is-mark-set? buf) (= (cbuf-get-y-mark buf) (cbuf-get-y buf)))
      (if (< (cbuf-get-x-mark buf) x-data)
          ;; Clear the mark if its position has been erased
          (cbuf-set-mark-flag! buf #f)
          ;; else
          ;; Adjust the mark in the presentation case, because there may be
          ;; more preceding spaces than there were preceding codepoints
          (cbuf-set-x-mark! buf (+ n-spaces (- (cbuf-get-x-mark buf) x-data)))))
    ;; Store the erase text to the cut buffer, if necessary
    (when cut
      (cbuf-set-cut-buffer! buf (list txt-cut)))
    ;; Add undo information
    (when undoable
      (cbuf-append-undo-list! buf `(%XEL1 ,y ,x-data txt-cut n-space)))))

;; [%EL2]
(define (%cbuf-erase-in-line buf device cut undoable)
  "Replace bol to eol with space."
  (let* ([txt (cbuf-get-text-cur buf)]
         [y (cbuf-get-y buf)]
         [x-data (cbuf-get-x-data buf)]
         [x-cell (cbuf-get-x-cell buf)]
         [n-spaces (cond ((eq? device 'presentation)
                          (wcwidth txt))
                         (else
                          (string-base-length txt)))])
    (cbuf-set-text-cur! buf (make-string n-spaces #\space))
    (if (eq? device 'presentation)
        (cbuf-set-x! buf x-cell 'cell)
        (cbuf-set-x! buf x-data 'data))
    ;; Clear the mark if its position has been erased
    (when (and (cbuf-is-mark-set? buf) (= (cbuf-get-y-mark buf)))
      (cbuf-set-mark-flag! buf #f))
    ;; Store the erased text to the cut buffer, if necessary
    (when cut
      (cbuf-set-cut-buffer! buf (list txt)))
    ;; Add undo information
    (when undoable
      (cbuf-append-undo-list! buf `(%XEL2 ,y ,x-data txt n-space)))))

(define (erase-in-line buf device P cut undoable)
  "This sets some or all of the characters in the current line to
spaces. If P is zero, the active position through end of the line are
erased.  If P is one, the beginning of the line through the active
position are erased.  If P is two, the entire line is erased.

If the DEVICE is 'presentation, graphemes that occupy more than one
cell will be replaced with as many spaces as necessary to keep the
number of presentation cells constant, and the cursor remains in the
same position in the presentation component, but, the active data
position may change.  If the DEVICE is 'data, each codepoint that is
erased will be replaced with a single space character.  The active
data position remains the same but the presentation position may
change.  This may change the visual presentation of the line.

If CUT is true, the deleted characters will be placed in the
copy/paste buffer.

IF UNDOABLE is true, undo information for this operation will be
saved."
    (cond
     ;; Erase to the end of the line
     [(= P 0)
      (%cbuf-erase-in-line-to-eol buf device cut undoable)]
     [(= P 1)
      (%cbuf-erase-in-line-from-bol buf device cut undoable)]
     [(= P 2)
      (%cbuf-erase-in-line buf device cut undoable)]))

;; FF
(define (cbuf-form-feed buf undoable)
  "FF causes the active presentation position to be moved to the
corresponding character position of the line at the page home position
of that next page in the presentation component.

It does not insert a form feed character into the text."
  #f)

;; HPA
(define (cbuf-character-position-absolute buf n)
  "Move the active data position to the n-th character in the active
line.

Any multi-codepoint character consisting of a base character and
combining marks will be counted as a single character.  The data
position will always end on the base character of a multi-codepoint
character.

If the move would put the active position beyond the limits of the
line, a &cbuf-end-of-line error is thrown."
  (let* ([x-data (cbuf-get-x-data buf)]
         [x-length (string-base-length (cbuf-get-text-cur buf))])
    (cond
     [(and (>= n 0) (<= n x-length))
      (cbuf-set-x! buf n 'data)]
     [(> n x-length)
      (cbuf-set-x! buf x-length 'data)
      (raise (condition (&cbuf-end-of-line)))]
     [else
      (cbuf-set-x! buf 0 'data)
      (raise (condition (&cbuf-beginning-of-line)))])))


;; HPB
(define (cbuf-character-position-backward buf n)
  "Move the active data position backward n codepoints.

Any multi-codepoint character consisting of a base character and
combining marks will be counted as a single character.  The data
position will always end on the base character of a multi-codepoint
character.

If the move would put the active position before the beginning of the
line, the active data position is set to the beginning of the line,
and a &cbuf-beginning-of-line error is thrown."
  (let* ([x-data (cbuf-get-x-data buf)])
    (cond
     [(>= (- x-data n) 0)
      (cbuf-set-x! buf (- x-data n) 'data)]
     [else
      (cbuf-set-x! buf 0 'data)
      (raise (condition (&cbuf-beginning-of-line)))])))

;; HPR
(define (cbuf-character-position-forward buf n)
  "Move the active data position forward n characters.

Any multi-codepoint character consisting of a base character and
combining marks will be counted as a single character.  The data
position will always end on the base character of a multi-codepoint
character.

If the move would put the active position past the end of the
line, the active data position is set to the end of the line,
and a &cbuf-end-of-line error is thrown."
  (let* ([x-data (cbuf-get-x-data buf)]
         [x-length (string-base-length (cbuf-get-text-cur buf))])
    (cond
     [(<= (+ x-data n) x-length)
      (cbuf-set-x! buf (+ x-data n) 'data)]
     [else
      (cbuf-set-x! buf x-length 'data)
      (raise (condition (&cbuf-end-of-line)))])))

;; HT
;; shorthand for cursor-forward-tabulation 1

;; HTJ
;; wait until we have fully generic tab stops

;; HVP
(define (cbuf-character-and-line-position buf n m)
  "Moves the active data position to the n-th line position m-th
character position.  If the position is out of range, the position is
set to an undefined but allowed position and an error is thrown."
  (let ([y-len (length (cbuf-get-text buf))]
        [err #f])
    (if (< n y-len)
        (cbuf-set-y! buf n)
        (begin
          (set! err 'eob)
          (cbuf-set-y! buf (- y-len 1))))
    (let* ([txt (cbuf-get-text-cur buf)]
           [len (string-base-length txt)])
      (if (<= m len)
          (cbuf-set-x! buf m 'data)
          (begin
            (set! err (or err 'eol))
            (cbuf-set-x! buf len 'data))))
    (when (eq? err 'eob)
      (raise (condition (&cbuf-end-of-buffer))))
    (when (eq? err 'eol)
      (raise (condition (&cbuf-end-of-line))))))

;; ICH
(define (cbuf-insert-character buf n undoable)
  "Shift the contents of the line to the right, starting at the
current data position, creating an empty gap of N codepoints.

The mark is moved if necessary.

When UNDOABLE is true, undo information is placed in the undo buffer."
  (let* ([str (cbuf-get-text-cur buf)]
         [x-data (cbuf-get-x-data buf)]
         [x-index (string-find-index-of-nth-base-codepoint str x-data)])
    (cbuf-set-text-cur! buf (string-append (substring str 0 x-index)
                                           (make-string n #\space)
                                           (substring str x-index (string-length str))))

    ;; Move the mark right, if necessary
    (when (and (cbuf-is-mark-set? buf)
               (= (cbuf-get-y-mark buf) (cbuf-get-y buf))
               (>= (cbuf-get-x-mark buf) (cbuf-get-x-data buf)))
      (cbuf-set-x-mark! buf (+ (cbuf-get-x-mark buf) n)))

    (when undoable
      (cbuf-append-undo-list! buf `(%XICH ,x-data ,n)))))


;; IL
(define (cbuf-insert-line buf n undoable)
  "This procedure inserts N blank lines before the current line,
causing the rest of the buffer to be moved down.  The cursor is placed
at the home position of the first new empty line.

The mark is moved, if necessary.

If UNDOABLE is true, undo information is placed in the undo buffer."
  (let ([txt (cbuf-get-text buf)]
        [y (cbuf-get-y buf)]
        [x-data (cbuf-get-x-data buf)]
        [x-goal (cbuf-get-x-goal buf)])
    (cbuf-set-text! buf (append (take txt y)
                                (make-list n "")
                                (drop txt y)))
    (cbuf-set-x! buf 0 'data)

    ;; Move the mark down, if necessary
    (when (and (cbuf-is-mark-set? buf)
               (>= (cbuf-get-y-mark buf) y))
      (cbuf-set-y-mark! buf (+ (cbuf-get-y-mark buf) n)))

    (when undoable
      (cbuf-append-undo-list! buf  `(%XIL ,y ,n ,x-data)))))

;; LF  - line feed
;; shorthand for cursor down 1

;; NEL - next line

;; REP - repeat

;; RI - reverse line feed

;; RM - reset mode

;; SGR - select graphic rendition
;; maybe someday

;; SLH
(define (cbuf-set-line-home buf n)
  "Sets the position that the cursor will move to after the commands
carriage return, delete-line, insert-line, and next-line. If the
Device Component Select Mode (DCSM) is set to 'presentation', this
home position will be a presentation position (the nth character
cell).  If the DCSM is set to 'data', this home position will be a
data position (the nth character).  The DCSM can be set using
`set-mode'."
  (cbuf-set-home-pos! buf n))

;; Many tab commands
;; TSR, TATE, etc

;; VPA
(define (cbuf-line-position-absolute buf n)
  "This procedure moves the active position to the Nth line, while
attempting to preserve the x-data position. If the new line has fewer
than than x-data characters, the x-data position is set to the end of
the line.

If this motion causes the active position to move past then end of the
buffer, it throws an end-of-buffer exception."
  (let* ([x-data (cbuf-get-x-data buf)]
         [y (cbuf-get-y buf)]
         [text-list (cbuf-get-text buf)]
         [y-max (+ -1 (length text-list))])

    ;; Check if we're moving past the end of the buffer
    (when (or (> n y-max)
              (and (= n y-max)
                   (> x-data (string-base-length (last text-list)))))
      (cbuf-set-y! buf y-max)
      (cbuf-set-x! buf (string-base-length (last text-list)) 'data)
      (raise (condition (&cbuf-end-of-buffer))))

    (cbuf-set-y! buf n)
    (cbuf-set-x! buf (cbuf-bracket-x-data buf x-data) 'data)))

;; VPB
(define (cbuf-line-position-backward buf n)
  "This procedure moves the active position backward by N lines, while
attempting to preserve the x-data position. If the new line has fewer
than than x-data characters, the x-data position is set to the end of
the line.

If moving N lines puts the active position before the beginning of the
buffer, it moves to the first character in the buffer and throws an
exception."
  (let* ([x-data (cbuf-get-x-data buf)]
         [y (cbuf-get-y buf)]
         [text-list (cbuf-get-text buf)])

    ;; Check if we're moving past before the beginning of the buffer
    (when (< (- y n) 0)
      (cbuf-set-y! buf 0)
      (cbuf-set-x! buf 0 'data)
      (raise (condition (&cbuf-beginning-of-buffer))))

    (cbuf-set-y! buf (- y n))
    (cbuf-set-x! buf (cbuf-bracket-x-data buf x-data) 'data)))

;; VPR
(define (cbuf-line-position-forward buf n)
  "This procedure moves the active position forward by N lines, while
attempting to preserve the x-data position. If the new line has fewer
than than x-data characters, the x-data position is set to the end of
the line.

If moving N lines puts the active position past the end of the buffer,
it moves to the last character in the buffer and throws an exception."
  (let* ([x-data (cbuf-get-x-data buf)]
         [y (cbuf-get-y buf)]
         [text-list (cbuf-get-text buf)]
         [y-max (+ -1 (length text-list))])

    ;; Check if we're moving past the end of the buffer
    (when (or (> (+ y n) y-max)
              (and (= (+ y n) y-max)
                   (> x-data (string-base-length (last text-list)))))
      (cbuf-set-y! buf y-max)
      (cbuf-set-x! buf (cbuf-bracket-x-data buf x-data) 'data)
      (raise (condition (&cbuf-end-of-buffer))))

    (cbuf-set-y! buf (+ y n))
    (cbuf-set-x! buf (cbuf-bracket-x-data buf x-data) 'data)))

;; VT
;; do one line tabulation

;; VTS
;; line tabulation set


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Methods specific to Undo

(define (dispatch-undo buf cmd . args)
  (case cmd
    ((BEL)
     (cbuf-bell buf #f))
    ((%CBL)
     (%clear-bell buf #f))
    ((%POS)
     (%set-positions buf (first args) (second args) (third args) #f))
    ((%LPOS)
     (%set-line-and-positions buf (first args) (second args) (third args)
              (fourth args) #f))
    [(%XY) (%set-xy buf (first args) (second args) (third args))]
    [(%XIL) (%undo-insert-line buf (first args) (second args) (third args))]
    [(%XICH) (%undo-insert-character buf (first args) (second args))]
    (else
     (error "unimplemented undo dispatch" cmd))))

;; [%YX]
(define (%set-xy buf x-data x-goal y)
  "Directly sets the x and y positions of the active position."
  (cbuf-set-y! buf y)
  (cbuf-set-x! buf x-data 'data)
  (cbuf-set-x-goal! buf x-goal))

;; [%XICH]
(define (%undo-insert-character buf x-data n)
  "Removes N characters from the current line beginning at the data
position X.  Since this is an undo method that expects the inserted
characters are all spaces, it does no checking for combining marks in
the deleted characters.  Thus, so using this function outside of
dispatch-undo is not recommended."
  (let* ([txt (cbuf-get-text-cur buf)]
         [x-index (string-find-index-of-nth-base-codepoint txt x-data)])
    (cbuf-set-text-cur! buf (string-append
                             (substring txt 0 x-index)
                             (substring txt (+ x-index n))))
    (cbuf-set-x! buf x-data 'data)

    ;; Move the mark left, if necessary
    (when (and (cbuf-is-mark-set? buf) (= (cbuf-get-y-mark buf) (cbuf-get-y buf)))
      (cond
       [(>= (cbuf-get-x-mark buf) (+ x-data n))
        (cbuf-set-x-mark! buf (- (cbuf-get-x-mark buf) n))]

       ;; The mark is in the spaces that are begin deleted.
       [(>= (cbuf-get-x-mark buf) x-data)
        (cbuf-set-mark-flag! buf #f)]))))

;; [%XIL]
(define (%undo-insert-line buf y n x-data)
  "Removes n lines from the buffer, starting at line y."
  (let* ([txt-list (cbuf-get-text buf)]
         [txt-len (length txt-list)])
    (cbuf-set-text! buf (append (take txt-list y)
                                (drop txt-list (+ y n))))
    (cbuf-set-y! buf y)
    (cbuf-set-x! buf x-data 'data)
    (when (and (cbuf-is-mark-set? buf) (>= (cbuf-get-y-mark buf) y))
      (cond
       [(>= (cbuf-get-y-mark buf) (+ y n))
        (cbuf-set-y-mark! buf (- (cbuf-get-y-mark buf) n))]

       ;; If the mark is in the lines that are being deleted
       [(>= (cbuf-get-y-mark buf) y)
        (cbuf-set-mark-flag! buf #f)]))))

;; [%LPOS]
(define (%set-line-and-positions buf L pd pp pp-goal undoable)
  "Directly sets the y and the three x positions in the buffer:
the data position, the presentation position, and the goal column"
  (let ([old-pd (cbuf-get-pd-cur buf)]
        [old-pp (cbuf-get-pp-cur buf)]
        [old-pp-goal (cbuf-get-pp-goal buf)]
        [old-L (cbuf-get-line-cur buf)])
    (and (not (and (= L old-L)
                   (= pd old-pd)
                   (= pp old-pp)
                   (= pp-goal old-pp-goal)))
         (begin
           (cbuf-set-line-cur! buf L)
           (cbuf-update-pp-list! buf)
           (cbuf-set-pd-cur! buf pd)
           (cbuf-set-pp-cur! buf pp)
           (cbuf-set-pp-goal! buf pp-goal)
           (and undoable
                (cbuf-append-undo-list! buf `(%LPOS ,old-L ,old-pd ,old-pp ,old-pp-goal)))))))


;; [%POS]
(define (%set-positions buf pd pp pp-goal undoable)
  "Directly sets the three x positions in the buffer: the data position,
the presentation position, and the goal column"
  (let ([old-pd (cbuf-get-pd-cur buf)]
        [old-pp (cbuf-get-pp-cur buf)]
        [old-pp-goal (cbuf-get-pp-goal buf)])
    (and (not (and (= pd old-pd)
                   (= pp old-pp)
                   (= pp-goal old-pp-goal)))
         (begin
           (cbuf-set-pd-cur! buf pd)
           (cbuf-set-pp-cur! buf pp)
           (cbuf-set-pp-goal! buf pp-goal)
           (and undoable
                (cbuf-append-undo-list! buf `(%POS ,old-pd ,old-pp ,old-pp-goal)))))))

;; [%UND]
(define (cbuf-undo buf)
  "Indicates that buffer is to be returned to a state as if both the
previous buffer-modifying command and this command had not been
called."
  (let ([undo-list (cbuf-get-undo-list buf)])
    (when (> (length undo-list) 0)
      (apply dispatch-undo (append (list buf) (last undo-list)))
      (cbuf-set-undo-list! buf (take undo-list (+ -1 (length undo-list)))))))

(define %undo cbuf-undo)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Dispatchers

(define (ascii-input-dispatch buf ch)
  "This dispatcher receives ASCII characters and applies them to the
buffer.  Some of the C0 controls and format effectors are mapped to
control functions."
  (cond
   ((= ch #\alarm)
    (cbuf-bell buf #t))
   ((= ch #\backspace)
    (cbuf-character-position-backward buf 1)
    (cbuf-delete-character buf 1 'data #t))
   ;;((= ch #\tab)
    ;;(cbuf-write-horizontal-tabulation buf #t))
   ;;((= ch #\newline)
    ;;(cbuf-write-newline buf #t))
   ;;((= ch #\vtab)
   ;; (cbuf-write-vertical-tabulation buf #t))
   ((= ch #\return)
    (cbuf-carriage-return buf #t))
   ((= ch #\delete)
    (cbuf-delete-character buf 1 'data #t))
   ;;((and (char>=? ch #\space) (char<=? ch #\~))
   ;; (cbuf-write-character buf ch #t))
   ))

(define (delete-in-line buf P)
  "This removes some or all of the characters in the current line.
If P is zero, the active position through the end of the line are
deleted.  If P is one, the beginning of the line through the active
position are deleted; the remaining characters in the line are shifted
left to fill in the gap; and, the cursor is placed at the beginning of
the line.  If P is two, all the characters in the line are removed,
and the cursor is placed at the beginning of the now-empty line."
  (let ([txt (cbuf-get-text-cur buf)]
        [pd (cbuf-get-pd-cur buf)])
    (cond
     [(= P 0)
      (cbuf-set-text-cur! buf (substring txt 0 pd))
      ;; (update-pd-list! buf)
      (cbuf-set-positions! buf pd 'data)]
     [(= P 1)
      (cbuf-set-text-cur! buf (substring txt (+ 1 pd) (string-length txt)))]
      ;; (update-pd-list! buf)      (cbuf-set-positions! buf 0 'data)]
     [(= P 2)
      (cbuf-set-text-cur! buf "")
      ;; (update-pd-list! buf)
      (cbuf-set-positions! buf 0 'data)]
     [else
      (error "FIXME")])))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; UTILITIES

(define (cbuf-compute-pp-list-from-string str tabsize)
  (let loop ([pp 0] [lst '()] [str str])
    (cond
     [(not (= 0 (string-length str)))
      (loop (+ pp (char-count-cells (string-ref str 0) pp tabsize))
            (append lst (list pp))
            (substring str 1 (string-length str)))]
     [else
      ;; return list
      (append lst (list pp))])))

(define (cbuf-count-cells-in-string str xstart tabsize)
  "Number of screen cells occupied by the characters in a string"
  (let ([iLim (string-length str)]
        [x xstart])
    (do ([i 0 (+ 1 i)]) ([>= i iLim])
      (set! x (+ x (char-count-cells (string-ref str i) x tabsize))))
    ;; (format (current-error-port) "CountCellsInString: str ~s count ~s~%" str x)
    (- x xstart)))

(define (cbuf-count-cells-in-substring str n xstart tabsize)
  "Return the number of screen cells occupied by the first N
characters of a string, assuming that the first string character is a
the presentation position XSTART with a given TABSIZE"
  (cbuf-count-cells-in-string (substring str 0 n) xstart tabsize))
