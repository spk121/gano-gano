
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;-------1---------2---------3---------4---------5---------6---------7---------8---------9---------10--------11--------12--------13-

;;;; A Character-Cell Buffer

;;; These are functions that act on a character cell buffer:
;;; which is a list of strings, a virtual cursor which is a location
;;; in that list of strings, and a set of functions that add text,
;;; delete text, and move the cursor.
;;;
;;; It assumes that each character has a width of 1 or 2 character
;;; cells: Latin characters have width 1, Hanzi and Kanji have width 2.
;;; Horizontal tabulation characters have a varying width that stretches
;;; to the next tabulation stop.
;;;
;;; Many functions work in either 'data' or 'presentation' coordinates.
;;; In data coordinates, the x coordinate is the coordinate of the Xth
;;; character.  In presentation coordinates, the x coordinate is the
;;; location of the Xth character cell.

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
(define CBUF_LENGTH (+ 1 CBUF_BELL))

(define (take lis k)
  (let recur ((lis lis) (k k))
    (if (zero? k) '()
        (cons (car lis)
              (recur (cdr lis) (- k 1))))))

(define (drop lis k)
  (let iter ((lis lis) (k k))
    (if (zero? k) lis (iter (cdr lis) (- k 1)))))

(define (list-set lst x val)
  (append (take lst x)
          (list val)
          (drop lst (+ x 1))))

(define (cbuf-make-buffer)
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
    cbuf))

;; The text
;; A list of strings
(define (cbuf-get-text cbuf)          (vector-ref cbuf CBUF_TEXT))
;; A list of the presentation positions of the characters of the current line
(define (cbuf-get-pp-list cbuf)       (vector-ref cbuf CBUF_PPLIST))
;; The current line number
(define (cbuf-get-line-cur cbuf)      (vector-ref cbuf CBUF_LCUR))
;; The current data position
(define (cbuf-get-pd-cur cbuf)        (vector-ref cbuf CBUF_PDCUR))
;; The current presentation position
(define (cbuf-get-pp-cur cbuf)        (vector-ref cbuf CBUF_PPCUR))
;; The desired presentation position
(define (cbuf-get-pp-goal cbuf)       (vector-ref cbuf CBUF_PPGOAL))
;; The number of spaces per between tab stops
(define (cbuf-get-tab-size cbuf)      (vector-ref cbuf CBUF_TABSIZE))
;; The number of lines per vertical tab stops
(define (cbuf-get-vert-tab-size cbuf) (vector-ref cbuf CBUF_VERTTABSIZE))

;; Home and Limit
(define (cbuf-get-home-pos cbuf)      (vector-ref cbuf CBUF_PHOME))
(define (cbuf-get-limit-pos cbuf)     (vector-ref cbuf CBUF_PLIMIT))
(define (cbuf-get-limit-type cbuf)    (vector-ref cbuf CBUF_LIMITTYPE))

;; The mark
(define (cbuf-is-mark-set? cbuf)      (vector-ref cbuf CBUF_MARKFLAG))
(define (cbuf-get-line-mark cbuf)     (vector-ref cbuf CBUF_LMARK))
(define (cbuf-get-pd-mark cbuf)       (vector-ref cbuf CBUF_PDMARK))

;; The undo ring
(define (cbuf-get-undo-list cbuf)     (vector-ref cbuf CBUF_UNDOLIST))
(define (cbuf-get-bell cbuf)          (vector-ref cbuf CBUF_BELL))

(define (cbuf-set-text! cbuf val)          (vector-set! cbuf CBUF_TEXT val))
(define (cbuf-set-pp-list! cbuf val)       (vector-set! cbuf CBUF_PPLIST val))
(define (%cbuf-set-line-cur! cbuf val)     (vector-set! cbuf CBUF_LCUR val))
(define (cbuf-set-pd-cur! cbuf val)        (vector-set! cbuf CBUF_PDCUR val))
(define (cbuf-set-pp-cur! cbuf val)        (vector-set! cbuf CBUF_PPCUR val))
(define (cbuf-set-pp-goal! cbuf val)       (vector-set! cbuf CBUF_PPGOAL val))
(define (cbuf-set-tab-size! cbuf val)      (vector-set! cbuf CBUF_TABSIZE val))
(define (cbuf-set-vert-tab-size! cbuf val) (vector-set! cbuf CBUF_VERTTABSIZE val))
(define (cbuf-set-home-pos! cbuf val)      (vector-set! cbuf CBUF_PHOME val))
(define (cbuf-set-limit-pos! cbuf val)     (vector-set! cbuf CBUF_PLIMIT val))
(define (cbuf-set-limit-type! cbuf val)    (vector-set! cbuf CBUF_LIMITTYPE val))
(define (cbuf-set-mark-flag! cbuf val)     (vector-set! cbuf CBUF_MARKFLAG val))
(define (cbuf-set-line-mark! cbuf val)     (vector-set! cbuf CBUF_LMARK val))
(define (cbuf-set-pd-mark! cbuf val)       (vector-set! cbuf CBUF_PDMARK val))
(define (cbuf-set-undo-list! cbuf val)     (vector-set! cbuf CBUF_UNDOLIST val))
(define (cbuf-set-bell! cbuf val)          (vector-set! cbuf CBUF_BELL val))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PRIMITIVES

(define (cbuf-append-undo-list! buf cmd)
  (cbuf-set-undo-list! buf (append (cbuf-get-undo-list buf)
                                   (list cmd))))

(define (cbuf-bracket-line buf L)
  "Return L if it is a valid line number for the current buffer, or
the nearest valid line number of L is out of range."
  (max 0
       (min L
            (1- (cbuf-get-line-count buf)))))

(define (cbuf-bracket-pd buf pd)
  "Return pd if it is valid data position for the active line, or the
nearest valid data position for the active line if pd is out of
range."
  (max 0
       (min pd
            (cbuf-get-text-cur-length buf))))

(define (cbuf-get-line-count buf)
  "Return the number of lines in the buffer"
  (length (cbuf-get-text buf)))

(define (cbuf-get-pp-from-pd-cur buf)
  "Find the presentation position of the active data position for the
current line."
  (cbuf-count-cells-in-substring (cbuf-get-text-cur buf) (cbuf-get-pd-cur buf) 0 (cbuf-get-tab-size buf)))

(define (cbuf-get-pp-max buf)
  (last (cbuf-get-pp-list buf)))

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
                       [(and (= i-start (1- i-end))
                             truncated-p)
                        ;; the only character is truncated
                        0]
                       [else
                        ;; the normal case
                        (if truncated-p
                            (- (list-ref pp-list (1- i-end))
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
         (do ([i i-start (1+ i)]) ([>= i (1- (or i-end (length pp-list)))])
           (if (char=? #\tab (string-ref str i))
               (set! inner-str (string-append inner-str (make-string (- (list-ref pp-list (1+ i)) (list-ref pp-list i)) #\space)))
               (set! inner-str (string-append inner-str (string (string-ref str i))))))
         inner-str)])
     ;; End of line space padding
     (make-string right-padding #\space))))

(define (cbuf-set-line-cur! buf n)
  (%cbuf-set-line-cur! buf n)
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
          (cbuf-set-pd-cur! buf (max 0 (1- ind)))
          ;; else
          (cbuf-set-pd-cur! buf (last (cbuf-get-pp-list buf))))
      (cbuf-update-pp-cur! buf))]
   [else
    (error "FIXME !!#!")]))

(define (cbuf-set-text-cur! buf str)
  (list-set! (cbuf-get-text buf) (cbuf-get-line-cur buf) str))

(define (cbuf-synchronize-pp! buf)
  "Set the presentation position goal to the active presentation
position"
  (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf)))

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
                  (* tabsize (1+ (quotient pp1 tabsize)))]
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

;; [%KPOC]
(define (cbuf-keypress-overwrite-character buf c undoable)
  "Writes the graphical character C into the active position,
overwriting the current character.  The active position is
advanced.

If a mark is overwritten, it is removed."
  (let ([txt (cbuf-get-text-cur buf)]
        [pd (cbuf-get-pd-cur buf)]
        [pp (cbuf-get-pp-cur buf)]
        [pp-goal (cbuf-get-pp-goal buf)]
        [LCur (cbuf-get-line-cur buf)]
        [old-c (string-ref txt pd)])
    ;; Clear the mark if we're overwriting the mark
    (if (and (cbuf-is-mark-set? buf)
             (= (cbuf-get-pd-mark buf) pd)
             (= (cbuf-get-line-mark buf) LCur))
        (set-mark-flag! buf #f))
    (cbuf-set-text-cur! buf (string-append (string-take txt pd)
                                           (string c)
                                           (string-drop txt (min (string-length txt) (1+ pd)))))
    ;; Move the cursor forward
    (cbuf-set-pd-cur! buf (1+ (cbuf-get-pd-cur buf)))
    (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
    (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))

    (if undoable
        (if (< pd (string-length txt))
            (begin
              (cbuf-append-undo-list! buf `(%WC ,pd ,old-c))
              (cbuf-append-undo-list! buf `(%POS ,pd ,pp ,pp-goal)))
            ;; else
            (begin
              (cbuf-append-undo-list! buf `(%DC ,pd))
              (cbuf-append-undo-list! buf `(%POS ,pd ,pp ,pp-goal)))))))

;; [%KPIC]
(define (cbuf-keypress-insert-character buf c undoable)
  "Inserts the graphical character C into the active position.
The active position is advanced.

If a mark is in the current line and after the active position,
it is moved right."
  (let ([txt (cbuf-get-text-cur buf)]
        [pd (cbuf-get-pd-cur buf)]
        [pp (cbuf-get-pp-cur buf)]
        [pp-goal (cbuf-get-pp-goal buf)]
        [LCur (cbuf-get-line-cur buf)]
        [old-c (string-ref txt pd)])
    ;; Move the mark, if necessary
    (if (and (cbuf-is-mark-set? buf)
             (>= (cbuf-get-pd-mark buf) pd)
             (= (cbuf-get-line-mark buf) LCur))
        (cbuf-set-pd-mark! buf (+ 1 (cbuf-get-pd-mark buf))))
    (cbuf-set-text-cur! buf (string-append (string-take txt pd)
                                           (string c)
                                           (string-drop txt (min (string-length txt) pd))))
    ;; Move the cursor forward
    (cbuf-update-pp-list! buf)
    (cbuf-set-pd-cur! buf (1+ pd))
    (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
    (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))

    (if undoable
        (begin
          (cbuf-append-undo-list! buf `(%DC ,pd))
          (cbuf-append-undo-list! buf `(%POS ,pd ,pp ,pp-goal))))))

;; [%KPT]
(define (cbuf-keypress-horizontal-tabulation buf undoable)
  "Inserts #\tab into the active position, shifting other characters
to the right.

If a mark is to the right of the active position, it is moved to the
right.

Afterward, the active data and presentation positions are moved to the
following tab stop."
  (let ([pd (cbuf-get-pd-cur buf)]
        [txt (cbuf-get-text-cur buf)])
    (cond

     ;; If we're overwriting a tab with a tab
     [(and (< pd(string-length txt))
         (eqv? #\tab (string-ref txt pd)))
    ;; Clear the mark if we're overwriting the mark
      (when (and (cbuf-is-mark-set? buf)
                 (= (cbuf-get-pd-mark buf) pd)
                 (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
        (set-mark-flag! buf #f))
      ;; Don't replace anything, but move the cursor forward
      (cbuf-set-pd-cur! buf (1+ pd))
      (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
      (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))]

     ;; If we're overwriting a non-tab character in DATA mode
     [(and (eqv? device 'data) (< pd (string-length txt)))
      (let* ([old-cp (string-ref txt pd)])
        (cbuf-set-text-cur! buf (string-append (string-take txt pd)
                                          (string #\tab)
                                          (string-drop txt (min (string-length txt) (1+ pd)))))
        ;; Clear the mark if we're overwriting the mark
        (if (and (cbuf-is-mark-set? buf)
                 (= (cbuf-get-pd-mark buf) pd)
                 (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
            (set-mark-flag! buf #f))
        ;; Move the cursor forward
        (cbuf-update-pp-list! buf)
        (cbuf-set-pd-cur! buf (1+ pd))
        (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
        (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))
        (if undoable
            (cbuf-append-undo-list! buf `((%CHAR ,old-cp ,pd)))))]

     ;; If we're appending a tab to the end of the line in DATA mode
     [(and (eqv? device 'data) (= pd (string-length (cbuf-get-text-cur buf))))
      (let* ([txt (cbuf-get-text-cur buf)]
             [pd (cbuf-get-pd-cur buf)])
        (cbuf-set-text-cur! buf (string-append txt "\t"))
        ;; Clear the mark if we're overwriting the mark
        (if (and (cbuf-is-mark-set? buf)
                 (= (cbuf-get-pd-mark buf) pd)
                 (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
            (set-mark-flag! buf #f))
        ;; Move the cursor forward
        (cbuf-update-pp-list! buf)
        (cbuf-set-pd-cur! buf (1+ pd))
        (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
        (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))
        (if undoable
            (cbuf-append-undo-list! buf `((%DCH ,pd)))))]

     [(eqv? device 'presentation)
      (let* ([ppList (cbuf-compute-pp-list-from-string (cbuf-get-text-cur buf)
                                                       (cbuf-get-tab-size buf))]
             [tabsize (cbuf-get-tab-size buf)]
             ;; Presentation position of start of tab
             [pp-start (cbuf-get-pp-cur buf)]
             ;; Presentation position of next tab stop
             [pp-end (* tabsize (quotient (+ pp-start tabsize) tabsize))]
             ;; if we've moved past the end of the line...
             [pp3 (min pp-end (last ppList))]

             ;; Data position of start of tab, being careful to include
             ;; the beginning of wide characters
             [pd1 (list-index (lambda (x) (> x pp-start)) ppList)]
             [pd-start (if pd1
                           (max 0 (1- pd1))
                           ;; else
                           (last ppList))]

             ;; Data position of end of tab
             [pd2 (list-index (lambda (x) (> x pp3)) ppList)]
             [pd-end (if pd2
                         (max 0 (1- pd2))
                         ;; else
                         (last ppList))]

             ;; Presentation of start of tab, including padding for wide
             ;; characters
             [pp-adj-start (list-ref ppList pd-start)]
             [pp-adj-end (max pp-end (list-ref ppList pd-end))]
             [space-num (- pp-adj-end pp-adj-start)]
             [txt (cbuf-get-text-cur buf)])

        ;; Replace the tab characters with spaces
        (cbuf-set-text-cur! buf (string-append (string-take txt pd-start)
                                          (make-string space-num #\space)
                                          (string-drop txt pd-end)))
        (cbuf-set-pd-cur! buf (+ pd-start space-num))
        (cbuf-set-pp-cur! buf pp-adj-end)
        (cbuf-set-pp-goal! buf pp-adj-end))
      ;; FIXME: move the mark
      ])))



(define (char-printing? x)
  (char-set<= (->char-set #\x) char-set:printing))

;; CP
(define (cbuf-write-codepoint buf cp device undoable)
  "Processes the codepoint CP.

If CP is #\\alarm, the bell state for the buffer is set.

If CP is #\\delete, the character at the current location is deleted.

If CP is a #\\backspace or #\\return, the cursor is moved accordingly.

If CP is #\\tab, #\\vtab, #\\newline, or any graphical character, it
writes CP into the active position, overwriting any current character.
If DEVICE is 'data, the codepoint at the current data position is
replaced with C.  If DEVICE is 'presentation, the codepoint is written
at the current presentation position, and those graphemes that would
be wholly or partly overwritten by this grapheme will be erased before
this grapheme is added.

If a mark is overwritten, it is removed.

Afterward, the active data and presentation positions are moved to
the location following the character.

Returns #t if the character was processed, and #f otherwise.

The C1 controls NEL, and CCH should be processed.  HTS, HTJ, and VTS
should be processed when the functionality is ready.  CSI should
introduce a command sequence."
  (cond
   ((= ch #\alarm)
    (cbuf-bell buf #t))
   ((= ch #\backspace)
    (cbuf-cursor-left buf 1 #t))
   ((= ch #\tab)
    (cbuf-write-horizontal-tabulation buf device #t))
   ((= ch #\newline)
    (cbuf-write-newline buf device #t))
   ((= ch #\vtab)
    (cbuf-write-vertical-tabulation buf device #t))
   ((= ch #\return)
    (carriage-return buf #t))
   ((= ch #\delete)
    (delete-character buf 1 device #t))
   ((char-printing? ch)
    (cbuf-write-printing buf ch device #t))
   (else
    ;; This codepoint was ignored
    #f)))

;; [%WHT]
(define (cbuf-write-horizontal-tabulation buf device undoable)
  "Writes #\tab into the active position, overwriting any current character.
If DEVICE is 'data, the codepoint at the current data position is
replaced with #\tab.  If DEVICE is 'presentation, the tab is written
at the current presentation position, and those between the
current presentation position and the next horizontal tab stop will
be overwritten.

If a mark is overwritten, it is removed. If the mark occurs later in
the current line, is is moved accordingly.

Afterward, the active data and presentation positions are moved to
the following tab stop."
  (let ([pd (cbuf-get-pd-cur buf)]
        [txt (cbuf-get-text-cur buf)])
    (cond

     ;; If we're overwriting a tab with a tab
     [(and (< pd(string-length txt))
         (eqv? #\tab (string-ref txt pd)))
    ;; Clear the mark if we're overwriting the mark
      (when (and (cbuf-is-mark-set? buf)
                 (= (cbuf-get-pd-mark buf) pd)
                 (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
        (set-mark-flag! buf #f))
      ;; Don't replace anything, but move the cursor forward
      (cbuf-set-pd-cur! buf (1+ pd))
      (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
      (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))]

     ;; If we're overwriting a non-tab character in DATA mode
     [(and (eqv? device 'data) (< pd (string-length txt)))
      (let* ([old-cp (string-ref txt pd)])
        (cbuf-set-text-cur! buf (string-append (string-take txt pd)
                                          (string #\tab)
                                          (string-drop txt (min (string-length txt) (1+ pd)))))
        ;; Clear the mark if we're overwriting the mark
        (if (and (cbuf-is-mark-set? buf)
                 (= (cbuf-get-pd-mark buf) pd)
                 (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
            (set-mark-flag! buf #f))
        ;; Move the cursor forward
        (cbuf-update-pp-list! buf)
        (cbuf-set-pd-cur! buf (1+ pd))
        (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
        (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))
        (if undoable
            (cbuf-append-undo-list! buf `((%CHAR ,old-cp ,pd)))))]

     ;; If we're appending a tab to the end of the line in DATA mode
     [(and (eqv? device 'data) (= pd (string-length (cbuf-get-text-cur buf))))
      (let* ([txt (cbuf-get-text-cur buf)]
             [pd (cbuf-get-pd-cur buf)])
        (cbuf-set-text-cur! buf (string-append txt "\t"))
        ;; Clear the mark if we're overwriting the mark
        (if (and (cbuf-is-mark-set? buf)
                 (= (cbuf-get-pd-mark buf) pd)
                 (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
            (set-mark-flag! buf #f))
        ;; Move the cursor forward
        (cbuf-update-pp-list! buf)
        (cbuf-set-pd-cur! buf (1+ pd))
        (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
        (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))
        (if undoable
            (cbuf-append-undo-list! buf `((%DCH ,pd)))))]

     [(eqv? device 'presentation)
      (let* ([ppList (cbuf-compute-pp-list-from-string (cbuf-get-text-cur buf)
                                                       (cbuf-get-tab-size buf))]
             [tabsize (cbuf-get-tab-size buf)]
             ;; Presentation position of start of tab
             [pp-start (cbuf-get-pp-cur buf)]
             ;; Presentation position of next tab stop
             [pp-end (* tabsize (quotient (+ pp-start tabsize) tabsize))]
             ;; if we've moved past the end of the line...
             [pp3 (min pp-end (last ppList))]

             ;; Data position of start of tab, being careful to include
             ;; the beginning of wide characters
             [pd1 (list-index (lambda (x) (> x pp-start)) ppList)]
             [pd-start (if pd1
                           (max 0 (1- pd1))
                           ;; else
                           (last ppList))]

             ;; Data position of end of tab
             [pd2 (list-index (lambda (x) (> x pp3)) ppList)]
             [pd-end (if pd2
                         (max 0 (1- pd2))
                         ;; else
                         (last ppList))]

             ;; Presentation of start of tab, including padding for wide
             ;; characters
             [pp-adj-start (list-ref ppList pd-start)]
             [pp-adj-end (max pp-end (list-ref ppList pd-end))]
             [space-num (- pp-adj-end pp-adj-start)]
             [txt (cbuf-get-text-cur buf)])

        ;; Replace the tab characters with spaces
        (cbuf-set-text-cur! buf (string-append (string-take txt pd-start)
                                          (make-string space-num #\space)
                                          (string-drop txt pd-end)))
        (cbuf-set-pd-cur! buf (+ pd-start space-num))
        (cbuf-set-pp-cur! buf pp-adj-end)
        (cbuf-set-pp-goal! buf pp-adj-end))
      ;; FIXME: move the mark
      ])))


;; [%WNL]
(define (cbuf-write-newline buf device undoable)
  "Inserts a line break into the active position, overwriting any
current character.  If DEVICE is 'data, the codepoint at the current
data position is deleted and the remaining codepoints in the line are
moved to a new line.  The cursor is placed at the beginning of the new
line.

If DEVICE is 'presentation and if the current codepoint at the
presentation position is a multi-cell character or a tab, it is
converted to spaces first.

If a mark is overwritten, it is removed.  If it is after the cursor,
it is moved.
"
  (let ([pd (cbuf-get-pd-cur buf)]
        [pp (cbuf-get-pp-cur buf)]
        [txt (cbuf-get-text-cur buf)])
    (cond

     ;; If we're overwriting a character in DATA mode
     [(and (eqv? device 'data) (< pd (string-length txt)))
      (let* ([old-cp (string-ref txt pd)])
        (cbuf-set-text-cur! buf (string-take txt pd))
        )]
     )))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ECMA-48-like CONTROL METHODS


;; BEL
(define (cbuf-bell buf undoable)
  "Sets the alarm state"
  (if (not (cbuf-get-bell buf))
      (begin
        (cbuf-set-bell! buf #t)
        (if undoable
            (cbuf-append-undo-list! buf '(%CBL))))))
;; BS
(define (cbuf-backspace buf undoable)
  "Move the active data position to the previous data position"
  (let ([pp (cbuf-get-pp-cur buf)]
        [pd (cbuf-get-pd-cur buf)]
        [pp-goal (cbuf-get-pp-goal buf)])
    (if (> pd 0)
        (begin
          (cbuf-increase-pd-cur! buf -1)
          (cbuf-update-pp-cur! buf)
          (cbuf-synchronize-pp! buf)
          (if undoable
              (cbuf-append-undo-list! buf `(%POS ,pd ,pp ,pp-goal)))))))

;; CAN
(define (cbuf-cancel buf)
  "Cancel the previous command"
  (%undo buf))

;; [%CBL]
(define (%clear-bell buf undoable)
  "Clears the alarm state"
  (if (cbuf-get-bell buf)
      (begin
        (cbuf-set-bell! buf #f)
        (if undoable
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
    (if (not (= pp1 ppCur))
        (begin
          (cbuf-set-positions! buf pp1 'presentation)
          (if undoable
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
    (if (not (and (= n pp) (= n pp-goal)))
        (begin
          (cbuf-set-positions! buf n 'presentation)
          (if undoable
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
    (if (not (= pp1 ppCur))
        (begin
          (cbuf-set-positions! buf pp1 'presentation)
          (if undoable
              (cbuf-append-undo-list! buf `(%POS ,pdCur ,ppCur ,ppGoal)))))))

;; CNL
(define (cbuf-cursor-next-line buf n undoable)
  "Move the active presentation position to the 1st character position
of the n-th following line in the presentation component"
  (let* ([LCur (cbuf-get-line-cur buf)]
         ;; Move forward n lines, or to the end of the buffer
         [L1 (cbuf-bracket-line buf (+ LCur n))])
    (if (> L1 (cbuf-get-line-cur buf))
        (let ([ppCur (cbuf-get-pp-cur buf)]
              [pdCur (cbuf-get-pd-cur buf)]
              [ppGoal (cbuf-get-pp-goal buf)])
          (cbuf-set-line-cur! buf L1)
          (cbuf-update-pp-list! buf)
          (cbuf-set-positions! buf 0 'data)
          (if undoable
              (cbuf-append-undo-list! buf `(%LPOS ,LCur ,pdCur ,ppCur ,ppGoal)))))))

;; CPL
(define (cbuf-cursor-preceding-line buf n undoable)
  "Move the active presentation position to the 1st character position
of the n-th preceding line in the presentation component"
  (let* ([LCur (cbuf-get-line-cur buf)]
         ;; Move backward n lines, or to the beginning of the buffer
         [L1 (cbuf-bracket-line buf (- LCur n))])
    (if (< L1 (cbuf-get-line-cur buf))
        (let ([ppCur (cbuf-get-pp-cur buf)]
              [pdCur (cbuf-get-pd-cur buf)]
              [ppGoal (cbuf-get-pp-goal buf)])
          (cbuf-set-line-cur! buf L1)
          (cbuf-update-pp-list! buf)
          (cbuf-set-positions! buf 0 'data)
          (if undoable
            (cbuf-append-undo-list! buf `(%LPOS ,LCur ,pdCur ,ppCur ,ppGoal)))))))

;; CR
(define (cbuf-carriage-return buf undoable)
  "Move the active presentation position to the line home position of
the same line.  The line home position can be set using `set-line-home'
and by setting the Device Control Select Mode (DCSM) using `set-mode'"
  (let ([home-type (cbuf-get-DCSM buf)]
        [home-pos (cbuf-get-home-pos buf)]
        [pd (cbuf-get-pd-cur buf)]
        [pp (cbuf-get-pp-cur buf)]
        [ppGoal (cbuf-get-pp-goal buf)])
    (if (not (or (and (eq? home-type 'data) (= pd home-pos))
                 (and (eq? home-type 'presentation (= pp home-pos)))))
        (begin
          (cbuf-set-positions! buf home-pos home-type)
          (if undoable
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
    (if (not (= pp 0))
        (begin
          (cbuf-set-positions! buf (max 0 (- pp n)) 'presentation)
          (if undoable
              (cbuf-append-undo-list! buf `(%POS ,pd ,pp ,ppGoal)))))))

;; CUD
(define (cbuf-cursor-down buf n undoable)
  "Move the active presentation position downwards in the presentation
component by N line positions"
  (let ([pd (cbuf-get-pd-cur buf)]
        [pp (cbuf-get-pp-cur buf)]
        [ppGoal (cbuf-get-pp-goal buf)]
        [LCur (cbuf-get-line-cur buf)])
    (if (< LCur (1- (cbuf-get-line-count buf)))
        (begin
          (cbuf-set-line-cur! buf (cbuf-bracket-line buf (+ LCur n)))
          (cbuf-update-pp-list! buf)
          (cbuf-set-positions! buf ppGoal 'presentation)
          (if undoable
            (cbuf-append-undo-list! buf `(%LPOS ,LCur ,pd ,pp ,ppGoal)))))))

;; CUF
(define (cbuf-cursor-right buf n undoable)
  "Move the active presentation position rightwards in the
presentation component by n character positions"
  (let ([pd (cbuf-get-pd-cur buf)]
        [pp (cbuf-get-pp-cur buf)]
        [ppGoal (cbuf-get-pp-goal buf)])
    (if (not (= pp (cbuf-get-pp-max buf)))
        (begin
          (cbuf-set-positions! buf (min (cbuf-get-pp-max buf) (+ pp n)) 'presentation)
          (if undoable
              (cbuf-append-undo-list! buf `(%POS ,pd ,pp ,ppGoal)))))))

;; CUP
(define (cbuf-cursor-position buf n m undoable)
  "Move the active presentation position to the n-th line and m-th
character position in the presentation component"
  (let ([pd (cbuf-get-pd-cur buf)]
        [pp (cbuf-get-pp-cur buf)]
        [ppGoal (cbuf-get-pp-goal buf)]
        [LCur (cbuf-get-line-cur buf)])
    (if (not (and (= LCur n) (= pp m) (= ppGoal m)))
        (begin
          (cbuf-set-line-cur! buf (cbuf-bracket-line buf n))
          (cbuf-update-pp-list! buf)
          (cbuf-set-positions! buf m 'presentation)
          (if undoable
              (cbuf-append-undo-list! buf `(%LPOS ,LCur ,pd ,pp ,ppGoal)))))))

;; CUU
(define (cbuf-cursor-up buf n undoable)
  "Move the active presentation positions upwards in the presentation
component by N line positions"
  (let ([pd (cbuf-get-pd-cur buf)]
        [pp (cbuf-get-pp-cur buf)]
        [ppGoal (cbuf-get-pp-goal buf)]
        [LCur (cbuf-get-line-cur buf)])
    (if (> LCur 0)
        (begin
          (cbuf-set-line-cur! buf (cbuf-bracket-line buf (- LCur n)))
          (cbuf-update-pp-list! buf)
          (cbuf-set-positions! buf ppGoal 'presentation)
          (when undoable
            (cbuf-append-undo-list! buf `(%LPOS ,LCur ,pd ,pp ,ppGoal)))))))

;; CVT
(define (cbuf-cursor-line-tabulation buf n undoable)
  "Causes the active presentation position to be moved to the
corresponding character position of the line corresponding to the n-th
following line tabulation stop in the presentation component."
  (let* ([pd (cbuf-get-pd-cur buf)]
         [pp (cbuf-get-pp-cur buf)]
         [ppGoal (cbuf-get-pp-goal buf)]
         [LCur (cbuf-get-line-cur buf)]
         [tabsize (cbuf-get-vert-tab-size buf)]
         [L (cbuf-compute-tab-column LCur tabsize n)])
    (if (< LCur (1- (cbuf-get-line-count buf)))
        (begin
          (cbuf-set-line-cur! buf (cbuf-bracket-line buf L))
          (cbuf-update-pp-list! buf)
          (cbuf-set-positions! buf ppGoal 'presentation)
          (when undoable
            (cbuf-append-undo-list! buf `(%LPOS ,LCur ,pd ,pp ,ppGoal)))))))

;; DA
(define (device-attributes buf)
  "Returns a string identifying this class"
  "CBuffer 0.0")

;; DCH
(define (delete-character buf n device undoable)
  "This removes the cells or characters at the active data position
and the n-1 following positions.  The characters to the right of the
deleted characters are moved left to fill in the gap.  If the active
data position is at the end of the line, the active data position is
cleared and replaced by a space.

If device is 'presentation, N indicates the number of character cells to
clear.  If device is 'data, N indicates the number of characters
to clear."
  (let* ([txt (cbuf-get-text-cur buf)]
         [pd (cbuf-get-pd-cur buf)]
         [len (cbuf-get-text-cur-length)]
         [width (wcwidth (string-ref txt pd))])
    (cond
     [(= len 0)
      *unspecified*]
     [(= pd len)
      (cond
       ((eq? device 'presentation)
        (cbuf-set-text-cur! buf (string-append (string-take txt (1- len))
                                               (make-string width #\space)))
        (cbuf-set-positions! buf len 'data))
       (else
        (cbuf-set-text-cur! buf (string-append (string-take txt (1- len))
                                               (make-string 1 #\space)))
        (cbuf-set-positions! buf len 'data)))]
     [(= pd 0)
      (cond
       ((eq? device 'presentation)
        (cbuf-set-text-cur! buf (string-append (make-string (1- width) #\space)
                                               (string-drop txt 1))))
       (else
        (cbuf-set-text-cur! buf (string-drop txt 1))))]
     [else
      (cond
       ((eq? device 'presentation)
        (cbuf-set-text-cur! buf (string-append (string-take txt (1- pd))
                                               (make-string (1- width) #\space)
                                               (string-drop txt pd))))
       (else
        (cbuf-set-text-cur! buf (string-append (string-take txt (1- pd))
                                               (string-drop txt pd)))))])

    ;; (update-pd-list! buf)
    (cbuf-set-positions! buf pd 'data)))

;; DL
(define (delete-line buf n)
  "Causes the active line and the n-1 following lines to be removed
from the buffer.  The resulting gap is closed by moving the adjacent
lines up.  The cursor is placed at the home position of the active line.  If
all the lines to the end of the buffer had been deleted, a new empty line is
added to the end of the buffer."
  (error "fixme"))


;; DSR
(define (device-status-report buf device)
  "If the device is 'presentation, report the active presentation position as
line, position.  If device is 'data, report the active data position."
  (cond
   ((eq? device 'data)
    (cons (cbuf-get-line-cur buf) (cbuf-get-pd-cur buf)))
   (else
    (cons (cbuf-get-line-cur buf) (cbuf-get-pp-cur buf)))))

;; ECH
(define (erase-character buf device)
  "This replaces the character at the active data postion with the
space character.  If DEVICE is 'presentation, multi-cell graphemes
will be replaced with multiple space characters.  If DEVICE is 'data,
the current codepoint will be replaced with a single space character."
  (let ([txt (cbuf-get-text-cur buf)]
        [pd (cbuf-get-pd-cur buf)]
        [len (cbuf-get-text-cur-length buf)])
    (cond
     [(string-null? txt)
      *unspecified*]
     [(= pd len)
      *unspecified*]
     [(eq? device 'data)
      (cbuf-set-text-cur! buf (string-set! txt pd #\space))]
     [(eq? device 'presentation)
      (let ([ch (string-ref txt pd)])
        (if (char=? ch #\tab)
            (cbuf-set-text-cur! buf (string-append (string-take txt pd)
                                              (make-string (- (cbuf-compute-tab-column pd (cbuf-get-tab-size buf) 1)
                                                              pd)
                                                           #\space)
                                              (string-drop txt (1+ pd))))
            ;; else
            (cbuf-set-text-cur! buf (string-append (string-take txt pd)
                                              (make-string (wcwidth (string-ref txt pd)) #\space)
                                              (string-drop txt (1+ pd))))))])
    ;; (update-pd-list! buf)
    (cbuf-set-positions! buf 0 'presentation)))

;; EL
(define (erase-in-line buf device P)
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

  ;;(add-undo (list 'EL device P (cbuf-get-line-cur buf) (cbuf-get-pd-cur buf) (cbuf-get-line-text buf)))

  (let ([ppList (cbuf-compute-pp-list-from-string (cbuf-get-text-cur buf) (cbuf-get-tab-size buf))]
        [pp-cur (cbuf-get-pp-cur buf)]
        [pd-cur (cbuf-get-pd-cur buf)]
        [pd-mark (cbuf-get-pd-mark buf)]
        [text-cur (cbuf-get-text-cur buf)])
    (cond
     ;; Erase to the end of the line
     [(and (eqv? device 'presentation) (= P 0))
      (set-text! buf (string-append (string-take text-cur pd-cur)
                                    (make-string (- (last ppList) pp-cur) #\space)))
      ;; Clear the mark if its position has been erased
      (if (and (cbuf-is-mark-set? buf)
               (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf))
               (>= pd-mark pd-cur))
          (set-mark-flag! buf #f))]
     [(and (eqv? device 'data) (= P 0))
      (set-text! buf (string-append (string-take text-cur pd-cur)
                                    (make-string (- (string-length text-cur) pd-cur) #\space)))
      ;; Clear the mark if its position has been erased
      (if (and (cbuf-is-mark-set? buf)
               (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf))
               (>= pd-mark pd-cur))
          (set-mark-flag! buf #f))]

     ;; Erase from the beginning of the line to here
     [(and (eqv? device 'presentation) (= P 1))
      (if (and (cbuf-is-mark-set? buf)
              (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
          (begin
            ;; If the mark's position will be erased, clear the mark
            (if (<= pd-mark pd-cur)
                (set-mark-flag! buf #f))
            ;; If the mark's position is later in this line, adjust is
            ;; data position to keep it on the same codepoint
            (if (> pd-mark pd-cur)
                (cbuf-set-pd-mark! (+ pd-mark (- pp-cur pd-cur))))))
      ;; Erase the beginning of the string
      (set-text! buf (string-append (make-string pp-cur #\space)
                                    (string-drop text-cur pd-cur)))
      (cbuf-set-pd-cur! buf pp-cur)]
     [(and (eqv? device 'data) (= P 1))
      (if (and (cbuf-is-mark-set? buf)
               (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
          ;; If the mark's position will be erased, clear the mark
          (if (<= pd-mark pd-cur)
              (set-mark-flag! buf #f)))
      ;; Erase the beginning of the string
      (set-text! buf (string-append (make-string pd-cur #\space)
                                    (string-drop text-cur pd-cur)))
      (cbuf-set-pp-cur! buf pd-cur)
      (cbuf-set-pp-goal! buf pd-cur)]
     ;; Erase the whole line
     [(and (eqv? device 'presentation) (= P 2))
      ;; If the mark is on this line, erase it
      (if (and (cbuf-is-mark-set? buf)
               (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
          (set-mark-flag! buf #f))
      ;; Erase the line
      (set-text! buf (make-string (last ppList)))
      (cbuf-set-pd-cur! buf pp-cur)]
     [(and (eqv? device 'data) (= P 2))
      ;; If the mark is on this line, erase it
      (if (and (cbuf-is-mark-set? buf)
               (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
          (set-mark-flag! buf #f))
      ;; Erase the line
      (set-text! buf (make-string (string-length text-cur) #\space))
      (cbuf-set-pp-cur! buf pd-cur)
      (cbuf-set-pp-goal! buf pd-cur)])))

;; FF
(define (form-feed buf)
  "FF causes the frame to be moved one frame-size down toward the end
of the buffer.  The active presentation position to be moved to the
corresponding character position of the line at the page home position
of that next page in the presentation component."
  (if ;; If there is at least a  partial page below this one
   (< (+ (cbuf-get-line-frame buf) (cbuf-get-line-frame-size buf))
      (cbuf-get-line-count buf))
   (begin
     (cbuf-set-line-frame! buf (+ (cbuf-get-line-frame buf) (cbuf-get-line-frame-size buf)))
     (cbuf-set-line-cur! buf (min (cbuf-get-line-count buf)
                                  (+ (cbuf-get-line-frame buf) (cbuf-get-page-home-line buf)))))))

;; HPA
(define (character-position-absolute buf n)
  "Move the active data position to the n-th codepoint in the active
line"
  (let* ([pd (cbuf-bracket-pd buf n)])
    (cbuf-set-positions! buf pd 'data)))

;; HPB
(define (character-position-backward buf n)
  "Move the active data position backward n codepoints"
  (let* ([pd (cbuf-bracket-pd buf (- (cbuf-get-pd-cur buf) n))])
    (cbuf-set-positions! buf pd 'data)))

;; HPR
(define (character-position-forward buf n undoable)
  "Move the active data position forward n codepoints"
  (let* ([pdCur (cbuf-get-pd-cur buf)]
         [pd (cbuf-bracket-pd buf (+ pdCur n))])
    (if (not (= pdCur pd))
        (begin
          (cbuf-set-positions! buf pd 'data)
          (if undoable
              (cbuf-append-undo-list! buf `(HPB ,n)))))))

;; HT
;; shorthand for cursor-forward-tabulation 1

;; HTJ
;; wait until we have fully generic tab stops

;; HVP
(define (character-and-line-position buf n m)
  "Moves the active data position to the n-th line position m-th
character position"
  (cbuf-set-line-cur! buf (cbuf-bracket-line buf n))
  (cbuf-update-pp-list! buf)
  (character-position-absolute buf m))

;; ICH
(define (insert-character-space buf n)
  "Shift the contents of the line to the right, starting at the
current data position, creating an empty gap of N codepoints"
  ;;(add-undo (list 'ICH n (cbuf-get-line-cur buf) (cbuf-get-pd-cur buf)))

  (let ([str (cbuf-get-text-cur buf)]
        [pd (cbuf-get-pd-cur buf)])
    (cbuf-set-text-cur! buf (string-append (string-take str pd) (make-string n #\space) (string-drop str pd)))

    ;; Move the mark right, if necessary
    (if (and (cbuf-is-mark-set? buf)
             (= (cbuf-get-line-mark buf) (cbuf-get-line-cur buf))
             (>= (cbuf-get-pd-mark buf) (cbuf-get-pd-cur buf)))
        (cbuf-set-pd-mark! buf (+ (cbuf-get-pd-mark buf) n)))))

;; IL
(define (insert-line-space buf n)
  "Move the current line and the n-1 following lines down N lines.
The resulting cap is erased.  The cursor is placed at the home
position of the first new empty line."
  ;;(add-undo buf (list 'IL n (cbuf-get-line-cur) (cbuf-get-pd-cur)))

  (let ([txt (cbuf-get-text buf)]
        [L (cbuf-get-line-cur buf)])
    (set-text! buf (append (take txt L)
                           (make-list n "")
                           (drop txt L)))
    (cbuf-set-pd-cur! buf 0)
    (cbuf-set-pp-cur! buf 0)
    (cbuf-set-pp-goal! buf 0)

    ;; Move the mark down, if necessary
    (if (and (cbuf-is-mark-set? buf)
             (>= (cbuf-get-line-mark) L))
        (cbuf-set-line-mark! buf (+ (cbuf-get-line-mark) n)))))

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
  (set-home-pos! buf n))

;; SM
(define (set-mode buf mode val)
  "Used to set the control modes of this buffer.

If MODE is 'dcsm, the Device Component Select Mode will be
modified. VAL can be one of 'data or 'presentation.

Setting the DCSM modifies the behavior of several procedures.
If it is set to 'data, those procedures, when given a position,
will assume that position is a Nth character in the line.
If it is set to 'presentation, those procedures will assume that
any position is the Nth character cell in the line.  These
are different if any double-width characters are present, such
as Kanji and Hanzi."
  (cond
   ((and (eq? mode 'dcsm) (eq? val 'data))
    (set-DCSM! buf 'data))
   ((and (eq? mode 'dcsm) (eq? val 'presentation))
    (set-DCSM! buf 'presentation))
   (else
    (error "unknown mode or val" (list mode val)))))


;; Many tab commands
;; TSR, TATE, etc

;; VPA
(define (line-position-absolute buf n)
  "Move the active data position to the n-th line"
  (cbuf-set-line-cur! buf (min n (cbuf-get-line-count buf)))
  (let ([ppList (cbuf-compute-pp-list-from-string (cbuf-get-text-cur buf) (cbuf-get-tab-size buf))])
    (cbuf-set-pp-cur! buf (list-ref ppList (cbuf-get-pd-cur buf)))
    (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))))

;; VPB
(define (line-position-backward buf n)
  "Move the active data position up n line positions"
  (cbuf-set-line-cur! buf (max 0 (- (cbuf-get-line-cur) n)))
  (let ([ppList (cbuf-compute-pp-list-from-string (cbuf-get-text-cur buf) (cbuf-get-tab-size buf))])
    (cbuf-set-pp-cur! buf (list-ref ppList (cbuf-get-pd-cur)))
    (cbuf-set-pp-goal! buf (cbuf-get-pp-cur))))

;; VPR
(define (line-position-forward buf n)
  "Move the active data position down by n line positions"
  (cbuf-set-line-cur! buf (min (+ (cbuf-get-line-cur) n) (cbuf-get-line-count buf)))
  (let ([ppList (cbuf-compute-pp-list-from-string (cbuf-get-text-cur buf) (cbuf-get-tab-size buf))])
    (cbuf-set-pp-cur! buf (list-ref ppList (cbuf-get-pd-cur)))
    (cbuf-set-pp-goal! buf (cbuf-get-pp-cur))))

;; VT
;; do one line tabulation

;; VTS
;; line tabulation set


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Writing and other non-ECMA-48 methods

;; [%LPOS]
(define (%set-line-and-positions buf L pd pp pp-goal undoable)
  "Directly sets the y and the three x positions in the buffer:
the data position, the presentation position, and the goal column"
  (let ([old-pd (cbuf-get-pd-cur buf)]
        [old-pp (cbuf-get-pp-cur buf)]
        [old-pp-goal (cbuf-get-pp-goal buf)]
        [old-L (cbuf-get-line-cur buf)])
    (if (not (and (= L old-L)
                  (= pd old-pd)
                  (= pp old-pp)
                  (= pp-goal old-pp-goal)))
        (begin
          (cbuf-set-line-cur! buf L)
          (cbuf-update-pp-list! buf)
          (cbuf-set-pd-cur! buf pd)
          (cbuf-set-pp-cur! buf pp)
          (cbuf-set-pp-goal! buf pp-goal)
          (if undoable
              (cbuf-append-undo-list! buf `(%LPOS ,old-L ,old-pd ,old-pp ,old-pp-goal)))))))


;; [%POS]
(define (%set-positions buf pd pp pp-goal undoable)
  "Directly sets the three x positions in the buffer: the data position,
the presentation position, and the goal column"
  (let ([old-pd (cbuf-get-pd-cur buf)]
        [old-pp (cbuf-get-pp-cur buf)]
        [old-pp-goal (cbuf-get-pp-goal buf)])
    (if (not (and (= pd old-pd)
                  (= pp old-pp)
                  (= pp-goal old-pp-goal)))
        (begin
          (cbuf-set-pd-cur! buf pd)
          (cbuf-set-pp-cur! buf pp)
          (cbuf-set-pp-goal! buf pp-goal)
          (if undoable
              (cbuf-append-undo-list! buf `(%POS ,old-pd ,old-pp ,old-pp-goal)))))))

;; [%UND]
(define (%undo buf)
  "Indicates that buffer is to be returned to a state as if both the
previous command and this command had not been called."
  (let ([undo-list (cbuf-get-undo-list buf)])
    (if (> (length undo-list) 0)
        (begin
          (apply dispatch-undo (append (list buf) (last undo-list)))
          (set-undo-list! buf (drop-right undo-list 1))))))


#!
;; [%WC]
(define (cbuf-write-character buf c device undoable)
  "Writes the graphical character C into the active position,
overwriting the current character.  If DEVICE is 'data, the codepoint
at the current data position is replaced with C.  If DEVICE is
'presentation, the codepoint is written at the current presentation
position, and those graphemes that would be wholly or partly
overwritten by this grapheme will be erased before this grapheme is
added.

If a mark is overwritten, it is removed."
  (cond
   [(eq? device 'data)
    (let ([txt (cbuf-get-text-cur buf)]
          [pd (cbuf-get-pd-cur buf)]
          [LCur (cbuf-get-line-cur buf)]
          [old-c (string-ref txt pd)])
      ;; If this position is *in* the string
      (if (< pd (string-length txt))
          (begin
            (string-set! txt pd c)
            (if (and (cbuf-is-mark-set? buf)
                     (= (cbuf-get-pd-mark buf) pd)
                     (= (cbuf-get-line-mark buf) LCur))
                (set-mark-flag! buf #f))
            (cbuf-set-text-cur! buf (string-append (string-take txt pd)
                                              (string c)
                                              (string-drop txt (min (string-length txt) (1+ pd)))))
            ;; Clear the mark if we're overwriting the mark
            (if (and (cbuf-is-mark-set? buf)
                     (= (cbuf-get-pd-mark buf) (cbuf-get-pd-cur buf))
                     (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
                (set-mark-flag! buf #f))
            ;; Move the cursor forward
            (cbuf-set-pd-cur! buf (1+ (cbuf-get-pd-cur buf)))
            (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
            (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf)))))]

   [(eqv? device 'presentation)
    (let* ([ppList (cbuf-compute-pp-list-from-string (cbuf-get-text-cur buf)
                                                (cbuf-get-tab-size buf))]
           ;; Presentation position of start
           [pp-start (cbuf-get-pp-cur buf)]
           ;; Presentation position of next
           [pp-end (+ pp-start (wcwidth c))]

           ;; Data position of start of char, being careful to include
           ;; the beginning of wide characters
           [pd1 (list-index (lambda (x) (> x pp-start)) ppList)]
           [pd-start (if pd1
                         (max 0 (1- pd1))
                         ;; else
                         (last ppList))]

           ;; Data position of end of char
           [pd2 (list-index (lambda (x) (> x pp-end)) ppList)]
           [pd3 (if pd2
                    (max 0 (1- pd2))
                    ;; else
                    (last ppList))]
           [pd-end (min (last ppList) (if (= pd3 pd-start)
                                          (1+ pd-start)
                                          pd3))]

           ;; Presentation of start of characters overwritten by char,
           ;; including padding for wide characters
           [space-before-char (- (cbuf-get-pp-cur buf) (list-ref ppList pd-start))]
           [space-after-char (max 0 (- (list-ref ppList pd-end) pp-end))]
           [txt (cbuf-get-text-cur buf)])

      (format (current-error-port) "write-char pd-cur ~s pd-start ~s pd-end ~s pp-cur ~s pp-start ~s pp-end ~s space ~s;~s~%" (cbuf-get-pd-cur buf) pd-start pd-end (cbuf-get-pp-cur buf) pp-start pp-end space-before-char space-after-char)
      ;; Replace the tab characters with spaces
      (cbuf-set-text-cur! buf (string-append (string-take txt pd-start)
                                        (make-string space-before-char #\space)
                                        (string c)
                                        (make-string space-after-char #\space)
                                        (string-drop txt pd-end)))
      (cbuf-set-pd-cur! buf (+ pd-start 1))
      (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
      (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf)))]))

;; [%WHT]
(define (cbuf-write-horizontal-tabulation buf device)
  "Writes a tab at the current position, overwriting the current character.
If DEVICE is 'data, the current codepoint is replace with a tab.  If
DEVICE is 'presentation, those graphemes that would be wholly or
partly overwritten by this tab will be erased before the tab is
added."
  (cond

   ;; If we're overwriting a tab with a tab
   [(and (< (cbuf-get-pd-cur buf) (string-length (cbuf-get-text-cur buf)))
         (eqv? #\tab (string-ref (cbuf-get-text-cur buf) (cbuf-get-pd-cur buf))))
    ;; Clear the mark if we're overwriting the mark
    (if (and (cbuf-is-mark-set? buf)
             (= (cbuf-get-pd-mark buf) (cbuf-get-pd-cur buf))
             (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
        (set-mark-flag! buf #f))
    ;; Don't replace anything, but move the cursor forward
    (cbuf-set-pd-cur! buf (1+ (cbuf-get-pd-cur buf)))
    (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
    (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf))]

   [(eqv? device 'data)
    (let ([txt (cbuf-get-text-cur buf)]
          [pd (cbuf-get-pd-cur buf)])
      (cbuf-set-text-cur! buf (string-append (string-take txt pd)
                                        (string #\tab)
                                        (string-drop txt (min (string-length txt) (1+ pd)))))
      ;; Clear the mark if we're overwriting the mark
      (if (and (cbuf-is-mark-set? buf)
               (= (cbuf-get-pd-mark buf) (cbuf-get-pd-cur buf))
               (= (cbuf-get-line-cur buf) (cbuf-get-line-mark buf)))
          (set-mark-flag! buf #f))
      ;; Move the cursor forward
      (cbuf-set-pd-cur! buf (1+ (cbuf-get-pd-cur buf)))
      (cbuf-set-pp-cur! buf (cbuf-get-pp-from-pd-cur buf))
      (cbuf-set-pp-goal! buf (cbuf-get-pp-cur buf)))]

   [(eqv? device 'presentation)
    (let* ([ppList (cbuf-compute-pp-list-from-string (cbuf-get-text-cur buf)
                                                (cbuf-get-tab-size buf))]
           [tabsize (cbuf-get-tab-size buf)]
           ;; Presentation position of start of tab
           [pp-start (cbuf-get-pp-cur buf)]
           ;; Presentation position of next tab stop
           [pp-end (* tabsize (quotient (+ pp-start tabsize) tabsize))]
           ;; if we've moved past the end of the line...
           [pp3 (min pp-end (last ppList))]

           ;; Data position of start of tab, being careful to include
           ;; the beginning of wide characters
           [pd1 (list-index (lambda (x) (> x pp-start)) ppList)]
           [pd-start (if pd1
                         (max 0 (1- pd1))
                         ;; else
                         (last ppList))]

           ;; Data position of end of tab
           [pd2 (list-index (lambda (x) (> x pp3)) ppList)]
           [pd-end (if pd2
                       (max 0 (1- pd2))
                       ;; else
                       (last ppList))]

           ;; Presentation of start of tab, including padding for wide
           ;; characters
           [pp-adj-start (list-ref ppList pd-start)]
           [pp-adj-end (max pp-end (list-ref ppList pd-end))]
           [space-num (- pp-adj-end pp-adj-start)]
           [txt (cbuf-get-text-cur buf)])

      ;; Replace the tab characters with spaces
      (cbuf-set-text-cur! buf (string-append (string-take txt pd-start)
                                        (make-string space-num #\space)
                                        (string-drop txt pd-end)))
      (cbuf-set-pd-cur! buf (+ pd-start space-num))
      (cbuf-set-pp-cur! buf pp-adj-end)
      (cbuf-set-pp-goal! buf pp-adj-end))]))
!#
;; [%WVT]
;; write vertical tabulation

;; [%WNL]
;; write newline

(define (insert-nel buf)
  "Removes the text between the active position and the end of the
line from the current line, and places it in a new line inserted after
the current line.  The active position is moved to the beginning of
the new line."
  (let ([txt (cbuf-get-text buf)]
        [txtcur (cbuf-get-text-cur buf)]
        [pd (cbuf-get-pd-cur buf)]
        [L (cbuf-get-line-cur buf)])
    (format (current-error-port) "insert-nel: before txtcur ~a pd ~a L ~a~%" txtcur pd L)
    ;; (pretty-print (render-frame buf))
    (set-text! buf (append (take txt L)
                           (list (string-take txtcur pd))
                           (list (string-drop txtcur pd))
                           (drop txt (min (1+ L)))))
    ;; Move the mark down, if necessary
    (if (cbuf-is-mark-set? buf)
        (cond
         [(and (= (cbuf-get-line-mark buf) L) (>= (cbuf-get-pd-mark buf) pd))
          (cbuf-set-line-mark! buf (1+ L))
          (cbuf-set-pd-mark! buf (- (cbuf-get-pd-mark buf) pd))]
         [(>= (cbuf-get-line-mark buf) L)
          (cbuf-set-line-mark! buf (1+ L))]))

    (cbuf-set-pd-cur! buf 0)
    (cbuf-set-pp-cur! buf 0)
    (cbuf-set-pp-goal! buf 0)
    (cbuf-set-line-cur! buf (1+ L))
    (format (current-error-port) "insert-nel: after txtcur ~a pd ~a L ~a~%" (cbuf-get-text-cur buf) (cbuf-get-pd-cur buf) (cbuf-get-line-cur buf))
    ;;(pretty-print (render-frame buf))
    ))

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
    (cbuf-character-position-backward buf 1 #t)
    (cbuf-delete-character buf 1 'data #t))
   ((= ch #\tab)
    (cbuf-write-horizontal-tabulation buf #t))
   ((= ch #\newline)
    (cbuf-write-newline buf #t))
   ((= ch #\vtab)
    (cbuf-write-vertical-tabulation buf #t))
   ((= ch #\return)
    (cbuf-carriage-return buf #t))
   ((= ch #\delete)
    (delete-character buf 1 'data #t))
   ((and (char>= ch #\space) (char<=? ch #\~))
    (cbuf-write-character buf ch #t))))

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
    (else
     (error "unimplemented undo dispatch" cmd))))

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
      (cbuf-set-text-cur! buf (string-take txt pd))
      ;; (update-pd-list! buf)
      (cbuf-set-positions! buf pd 'data)]
     [(= P 1)
      (cbuf-set-text-cur! buf (string-drop txt (1+ pd)))
      ;; (update-pd-list! buf)
      (cbuf-set-positions! buf 0 'data)]
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
     [(not (string-null? str))
      (loop (+ pp (cbuf-count-cells-in-char (string-ref str 0) pp tabsize))
            (append lst (list pp))
            (string-drop str 1))]
     [else
      ;; return list
      (append lst (list pp))])))

(define (cbuf-count-cells-in-char chr x tabSize)
  "Number of cells a character CHR at column X would take up"
  (cond
   [(eqv? chr #\nul)
    0]
   [(eqv? chr #\tab)
    (- tabSize (modulo x tabSize))]
   [(is-control-char? chr)
    ;; Add 1 for the caret '^'
    (1+ (wcwidth (cbuf-get-display-char-from-control-char chr)))]
   [else
    (wcwidth chr)]))

(define (cbuf-count-cells-in-string str xstart tabsize)
  "Number of screen cells occupied by the characters in a string"
  (let ([iLim (string-length str)]
        [x xstart])
    (do ([i 0 (1+ i)]) ([>= i iLim])
      (set! x (+ x (cbuf-count-cells-in-char (string-ref str i) x tabsize))))
    ;; (format (current-error-port) "CountCellsInString: str ~s count ~s~%" str x)
    (- x xstart)))

(define (cbuf-count-cells-in-substring str n xstart tabsize)
  "Return the number of screen cells occupied by the first N
characters of a string, assuming that the first string character is a
the presentation position XSTART with a given TABSIZE"
  (cbuf-count-cells-in-string (substring str 0 n) xstart tabsize))

(define (cbuf-get-display-char-from-control-char c)
  "The character to use when displaying controls in \"^X\" form"
  (integer->char (+ (char->integer c) 64)))

(define (is-control-char? c)
  "#t if this is an ISO control character"
  (char-set-contains? char-set:iso-control c))


