;;; CBuffer

#|

A CBuffer is a data model for lines of plain text.  It can be
conceived as a list of strings, where the first element of the list is
a string that contains the first line of text, and so on.

The strings stored in a CBuffer must only consist of printable
characters.  No format effectors or presentation control functions are
stored.  The lone exception is the horizontal tab character.

The strings stored in CBuffers do not explicitly store line
terminations, like newline or carriage return.  A separate list
stores the line terminators for each line. A line termination is
exists for each line in the buffer.  A line may be terminated
by any of the allowed Unicode terminators, CR, LF, NL, CRLF, LS,
PS, FF, or VT.

A CBuffer consists of
- the text, broken into lines.
- a list of line endings, one per line.
- an active line and position. This active location is a special address
that is used in the command set.  It is the location of a virtual cursor.
- a mark line and position,  This mark location is a special address that
is used in the command set.
- a list of bookmarks that assign names to locations in the text file.
  Bookmarks are unique and a location may have only one bookmark.
- a list of tags that assign properties to locations in the text file.
  There may be multiple tags with the same name, and a position may
  have any number of tags.
- an operations list.  This is a list of all the operations that have
modified the buffer. This allows for the implementation of undo and redo
commands.

The Mark

The mark is often set to assign a range of text.  It may represent one
extrema of a range of text upon which a command may operate, which the
active position representing the other extrema.

Usually any action that modifies the text of the buffer will clear the
mark.

Bookmarks.

A bookmark is a name for a position in a text file.  Unlike the mark,
which is cleared on any operation that modifies text, bookmarks are
persistent.  A bookmark will only be cleared when explicitely
requested or when the character location to which they are attached is
deleted.  Since bookmarks are attached to locations in the text, they
will move as text is inserted and deleted.

|#


(define-module (gano CBuffer)
  #:use-module (oop goops)
  #:use-module (oop goops describe)
  #:use-module (ice-9 receive)
  #:use-module (ice-9 rdelim)
  #:use-module (srfi srfi-1)
  #:use-module (rnrs control)
  #:use-module ((ncurses extra) #:select (wcwidth))
  #:use-module (gano debug)
  #:use-module (gano stringlist)
  #:use-module (gano poslist)
  #:use-module (gano position)
  #:use-module (mlg typechecking)
  #:use-module (mlg logging)
  #:export (
            <CBuffer>
            ;; Constructors
            make-empty-cbuffer
            cbuffer?

            ;; TTY Operations
            backspace                   ; BS
            line-feed                   ; LF
            carriage-return             ; CR
            set-line-home               ; SLH
            set-line-limit              ; SLL
            set-mode                    ; SM
            write-character             ; WC
            set-invalid-movement-mode!
            get-active-data-location

            ;; Needed for testing for now
            %dump-cbuffer
            get-text-cur
            get-text
            get-undo
            add-tag
            get-tags

            ;; Operations inspired by POSIX ED
            ed-append
            ed-change
            ed-copy
            ed-delete
            ed-edit
            ed-get-mark
            ed-insert
            ed-join
            ed-line-number
            ed-mark
            ed-move
            ed-null
            ed-read
            ed-regex-search-backward-line
            ed-regex-search-forward-line
            ed-write

            insert-lines-before
            replace-lines
            delete-all
            regex-search-forward-line
            join-lines
            move-lines
            copy-lines
            bookmark-line
            undo

            ;; ECMA-48 primitives

            backspace                   ; BS
            cursor-backward-tabulation  ; CBT
            cursor-character-absolute   ; CHA
            cursor-forward-tabulation   ; CHT
            cursor-next-line            ; CNL
            cursor-preceding-line       ; CPL
            carriage-return             ; CR
            cursor-tabulation-control   ; CTC
            cursor-left                 ; CUB
            cursor-down                 ; CUD
            cursor-right                ; CUF
            cursor-position             ; CUP
            cursor-up                   ; CUU
            cursor-line-tabulation      ; CVT
            device-attributes           ; DA
            delete-character            ; DCH
            delete-line                 ; DL
            erase-character             ; ECH
            erase-in-line               ; EL
            center-frame-line
            center-frame-position
            character-position-absolute
            character-position-backward
            character-position-forward
            character-and-line-position
            device-status-report        ; DSR
            insert-character-space
            insert-line
            insert-nel
            is-position-in-frame?
            line-position-absolute
            line-position-backward
            line-position-forward
            move-frame-line
            render-frame
            scroll-down
            scroll-up
            write-tabulation

            get-line-count
            get-line-cur
            get-line-frame
            get-line-frame-size
            get-pd-cur
            get-text-cur
            get-text-cur-length
            get-text-line
            increase-pd-cur!
            render-line
            set-line-cur!
            set-line-frame!
            set-line-frame-size!
            set-pd-cur!
            set-pd-goal!
            set-positions!
            set-tab-size!
            set-text!
            set-text-cur!
            ))

(define (sublist lst start end)
  "Extract a sublist from lst between start (inclusive) and
end (exclusive)."
  (drop (take lst end) start))

(define-class <CBuffer> ()

  ;; Modes

  ;; either 'insert or 'replace
  (m_IRM #:init-value 'insert
         #:getter get-insertion-replacement-mode
         #:setter set-insertion-replacement-mode!)

  ;; either 'following or 'preceding
  (m_HEM #:init-value 'following
         #:getter get-character-editing-mode
         #:setter set-character-editing-mode!)

  ;; A list of symbols that may contains one or more of the following:
  ;; 'auto_right_margin: will carriage return and line feed when at last column
  (m_IMM #:init-value '()
         #:getter get-invalid-movement-mode
         #:setter set-invalid-movement-mode!)

  ;; After a graphic character is received, the active data
  ;; position will be moved.  If the active data position should
  ;; be moved toward the end of the string, SIMD is 'forward.
  ;; If the active data position should move toward the beginning
  ;; of the string, SIMD is backward.
  (m_SIMD #:init-value 'forward
          #:getter get-implicit-movement-direction
          #:setter set-implicit-movement-direction!)

  ;; The text
  ;; A list of strings
  (m_rgText #:init-value '("") #:accessor get-text #:setter set-text!)
  ;; The current line number
  (m_LCur #:init-value 0 #:getter get-line-cur #:setter %set-line-cur!)
  ;; The current data position
  (m_PdCur #:init-value 0 #:getter get-pd-cur #:setter %set-pd-cur!)
  ;; The number of spaces per between tab stops
  (m_tabSize #:init-value 8 #:getter get-tab-size #:setter set-tab-size!)
  ;; The number of lines per vertical tab stops
  (m_vertTabSize #:init-value 6 #:getter get-vert-tab-size #:setter set-vert-tab-size!)

  ;; Home and Limit
  (m_PHome #:init-value 0 #:getter get-home-pos #:setter set-home-pos!)
  (m_HomeType #:init-value 'data #:getter get-home-type #:setter set-home-type!)
  (m_PLimit #:init-value 1024 #:getter get-limit-pos #:setter set-limit-pos!)
  (m_LimitType #:init-value 'data #:getter get-limit-type #:setter set-limit-type!)
  (m_pageHome #:init-value 0 #:getter get-page-home-line #:setter set-page-home-line!)

  ;; The mark
  (m_fMarkSet #:init-value #f #:getter is-mark-set? #:setter set-mark-flag!)
  (m_LMark #:init-value 0 #:getter get-line-mark #:setter set-line-mark!)
  (m_PdMark #:init-value 0 #:getter get-pd-mark #:setter set-pd-mark!)

  ;; The bookmarks
  (m_rgBookmark #:init-value '() #:accessor get-bookmarks #:setter set-bookmarks!)
  ;; The tags
  (m_rgTags #:init-value '() #:accessor get-tags #:setter set-tags!)

  ;; The undo list
  (m_rgUndo #:init-value '() #:accessor get-undo #:setter set-undo!)
  )

;; The bookmarks are of the form
;; (cons 'symbol (list line pd))
(define (bookmark:name B) (first B))
(define (bookmark:line B) (second B))
(define (bookmark:pd B) (third B))
(define (bookmark:name! B val) (list-set! B 0 val))
(define (bookmark:line! B val) (list-set! B 1 val))
(define (bookmark:pd! B val) (list-set! B 2 val))

(define-method (append-undo! (buf <CBuffer>) op)
  (set-undo! buf (append (get-undo buf)
                         (list op))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CONSTRUCTORS

(define (make-empty-cbuffer)
  (let ((CB (make <CBuffer>)))
    CB))

(define (cbuffer? buf)
  (is-a? buf <CBuffer>))

;;;;;;;;;;;;;;;;;;;;;;;;;
;; PRIMITIVES

;; RULES FOR PRIMITIVES

;; 0. Primitives may only call getters/setters or primitives.

;; Any primitive that could result in the above rules being violated
;; or that could throw an error must begin with '%' to mark it as
;; dangerous.

;; Pd - a data position in line
;; PdCur - The active data position
;; PdLim - The last data position in a line or string
;; Str - a string
;; Char - a character

(define-method (%dump-cbuffer (buf <CBuffer>))
  (format #t "Modes: IRM ~a, HEM ~a, IMM ~a, SIMD ~a~%"
          (get-insertion-replacement-mode buf)
          (get-character-editing-mode buf)
          (get-invalid-movement-mode buf)
          (get-implicit-movement-direction buf))
  (format #t "===BEGIN TEXT===~%")
  (let loop ((i 1) (lst (get-text buf)))
    (if (not (null? lst))
        (begin
          (format #t "~a  |~a|~%" i (car lst))
          (loop (1+ i) (cdr lst)))))
  (format #t "====END TEXT====~%")
  (format #t "Position: Line ~a, Pos ~a ~%" (get-line-cur buf) (get-pd-cur buf))
  (format #t "Tabsize: Horiz ~a, Vert ~a~%" (get-tab-size buf) (get-vert-tab-size buf))
  (format #t "Home: ~a,  Limit ~a~%" (get-home-pos buf) (get-limit-pos buf))
  (format #t "Mark: Valid ~a, Line ~a, Pos ~a~%" (is-mark-set? buf)
          (get-line-mark buf) (get-pd-mark buf)))

(define-method (bracket-line (buf <CBuffer>) L)
  "Return L if it is a valid line number for the current buffer, or
the nearest valid line number of L is out of range."
  (max 0
       (min L
            (1- (get-line-count buf)))))

(define-method (bracket-pd (buf <CBuffer>) pd)
  "Return pd if it is valid data position for the active line, or the
nearest valid data position for the active line if pd is out of
range."
  (max 0
       (min pd
            (get-text-cur-length buf))))

(define-method (bracket-line-pd (buf <CBuffer>) L pd)
  "Return pd if it is valid data position for the active line, or the
nearest valid data position for the active line if pd is out of
range."
  (max 0
       (min pd
            (string-length (get-text-line buf (bracket-line buf L))))))

(define-method (get-line-count (buf <CBuffer>))
  "Return the number of lines in the buffer"
  (length (get-text buf)))

(define-method (get-text-cur (buf <CBuffer>))
  "Return the text of the active line"
  (list-ref (get-text buf) (get-line-cur buf)))

(define-method (get-text-line (buf <CBuffer>) n)
  "Return the text of line N"
  (if (= n (bracket-line buf n))
      (list-ref (get-text buf) n)
      ""))

(define-method (get-text-cur-length (buf <CBuffer>))
  "Return the number of codepoints in the active line"
  (string-length (get-text-cur buf)))


(define-method (set-line-and-pd-cur! (buf <CBuffer>) LPd)
  (warn-if-false (cbuffer? buf))
  (warn-if-false (list-of-two-integers? LPd))

  (set-line-cur! buf (list-ref LPd 0))
  (set-pd-cur! buf (list-ref LPd 1)))

(define-method (set-pd-cur! (buf <CBuffer>) Pd)
  "Moves the active data position to Pd.  The data position is
bracketed so that it is valid position.  The presentation position and
goal column are synchronized.

It returns the active data position, which may be different from the
parameter Pd if that value is less than zero or greater than the
length of the active line."
  (%set-pd-cur! buf (bracket-pd buf Pd))
  (get-pd-cur buf))

(define-method (set-pd-cur-to-simd-eol! (buf <CBuffer>))
  "Sets the active data position to the last character position in the
current line if the implicit movement direction (SIMD) is 'forward, or
to the first character position in the current line if SIMD is
'backward."
  (set-pd-cur! buf
               (if (eqv? (get-implicit-movement-direction buf)
                         'forward)
                   (get-text-cur-length buf)
                   0)))

(define-method (set-pd-cur-to-simd-bol! (buf <CBuffer>))
  "Sets the active data position to the first character position in the
current line if the implicit movement direction (SIMD) is 'forward, or
to the last character position in the current line if SIMD is
'backward."
  (set-pd-cur! buf
               (if (eqv? (get-implicit-movement-direction buf) 'forward)
                   0
                   (get-text-cur-length buf))))

(define-method (increase-pd-cur! (buf <CBuffer>) n)
  "Moves the active data position N characters to the right, if N is
positive, or N characters to the left, if N is negative.  The data
position is bracketed so that it is valid.  The presentation position
and goal column are syncronized.

It returns the actual number of positions moved, which may be
different from the expected value if N would have moved the data
position before the beginning or past the end of the line."
  (let* ((LStart (get-line-cur buf))
         (LEnd (set-pd-cur! buf (+ n (get-pd-cur buf)))))
    (- LEnd LStart)))

(define-method (set-line-cur! (buf <CBuffer>) L)
  "Sets the active data line to L. The line number is bracketed to a
valid value.

Without changing the goal column, the active presentation position is
set to the beginning of the grapheme at the goal column, or to the end
of the line if the goal column is past the end of the line.  The
active data position is set to the data position of the grapheme
located at the active presentation position.

It returns the active data line, which may be different from the L
parameter."
  (%set-line-cur! buf (bracket-line buf L))
  (get-line-cur buf))

(define-method (increase-line-cur! (buf <CBuffer>) n)
  "Sets the active data line down N lines, if N is positive,
or up N lines, if N is negative.  The line number is bracketed
to a valid value.

Without changing the goal column, the active presentation position is
set to the beginning of the grapheme at the goal column, or to the end
of the line if the goal column is past the end of the line.  The
active data position is set to the data position of the grapheme
located at the active presentation position.

It returns the actual number of lines moved, which may be different
from the N parameter."
  (let* ((LStart (get-line-cur buf))
         (LEnd (set-line-cur! buf (+ (get-line-cur buf) n))))
    (- LEnd LStart)))

(define-method (set-text-cur! (buf <CBuffer>) str)
  "Sets the text of the current line to STR.

Without changing the goal column, the active presentation position is
set to the beginning of the grapheme at the goal column, or to the
end of the line if the goal column is past the end of the line.  The
active data position is set to the data position of the grapheme located at
the active presentation position.

All bookmarks in the current line are removed, except those at the beginning
of the line.

The mark is unset.

The return value is unspecified."
  (list-set! (get-text buf) (get-line-cur buf) str)
  (set-mark-flag! buf #f)

  *unspecified*)

(define-method (set-text-line! (buf <CBuffer>) L str)
  (list-set! (get-text buf) (bracket-line buf L) str)
  (set-mark-flag! buf #f)
  *unspecified*)


(define-method (set-text!! (buf <CBuffer>) strlist)
  "Sets the text of the current buffer to strlist.

If the active line would now be beyond the end of the buffer, it is
set to the last line in the buffer, and the active data position is
set to the end of that line.  The goal column is adjusted.

Otherwise, without changing the goal column, the active presentation
position is set to the beginning of the grapheme at the goal column,
or to the end of the line if the goal column is past the end of the
line.  The active data position is set to the data position of the
grapheme located at the active presentation position.

All bookmarks are removed.

The mark is unset.

The return value is unspecified."
  (set-text! buf strlist)
  (let ((LLim (get-line-count buf))
        (LCur (get-line-cur buf)))
    (if (>= LCur LLim)
        (begin
          (set-line-cur! buf (bracket-line buf (1- LLim)))
          (set-pd-cur-to-simd-eol! buf)))
    (set-mark-flag! buf #f)
    *unspecified*))

(define-method (move-mark-down-if-after! (buf <CBuffer>) lineno n)
  ;; Move the mark down, if necessary
  (when (and (is-mark-set? buf)
             (>= (get-line-mark buf) lineno))
        (set-line-mark! buf (+ (get-line-mark buf) n))))

(define-method (new-bookmark-at! (buf <CBuffer>) L Pd sym)
  (set-bookmarks! buf
                  (append (get-bookmarks buf)
                          (list sym
                                (bracket-line buf L)
                                (bracket-line-pd buf L Pd)))))

(define-method (extract-bookmarks-in-line-at (buf <CBuffer>) LStart PdStart PdEnd)
  "Removes any bookmarks that may be on line
LStart,PdStart (inclusive) PdEnd (exclusive).  Returns those
bookmarks as a list.  If no bookmarks are in that region, the empty
list is returned."
  (receive (extracted unextracted)
      (partition
       (lambda (bmark)
         (and (= (bookmark:line bmark) LStart)
              (>= (bookmark:pd bmark) PdStart)
              (< (bookmark:pd bmark) PdEnd)))
       (get-bookmarks buf))
    (set-bookmarks! buf unextracted)
    extracted))

(define-method (extract-bookmarks-in-lines (buf <CBuffer>) LStart LEnd)
  "Removes any bookmarks that may be on line
LStart (inclusive) LEnd (exclusive).  Returns those
bookmarks as a list.  If no bookmarks are in that region, the empty
list is returned."
  (receive (extracted unextracted)
      (partition
       (lambda (bmark)
         (and (>= (bookmark:line bmark) LStart)
              (< (bookmark:line bmark) LEnd)))
       (get-bookmarks buf))
    (set-bookmarks! buf unextracted)
    extracted))


(define-method (adjust-bookmarks-in-line-after (buf <CBuffer>) LCur PdPrev PdCur)
  (for-each
   (lambda (bmark)
     (when (and (= (bookmark:line bmark) LCur)
                (>= (bookmark:pd bmark) PdPrev))
       (bookmark:pd! bmark (+ (bookmark:pd bmark) (- PdCur PdPrev)))))
   (get-bookmarks buf)))

(define-method (adjust-bookmarks-in-lines (buf <CBuffer>) LPrev LCur)
  (for-each
   (lambda (bmark)
     (when (>= (bookmark:line bmark) LPrev)
       (bookmark:line! bmark (+ (bookmark:line bmark) (- LCur LPrev)))))
   (get-bookmarks buf)))

(define-method (adjust-bookmarks-in-joined-lines (buf <CBuffer>) LStart LEnd)
  "When combining lines LStart (inclusive) through LEnd (exclusive),
adjust the bookmarks."
  (for-each
   (lambda (bmark)
     (cond
      ((and (<= (1+ LStart) (bookmark:line bmark)) (< (bookmark:line bmark) LEnd))
       (bookmark:line! bmark LStart)
       (bookmark:pd! bmark (+ (bookmark:pd bmark)
                              (apply +
                                     (map string-length
                                          (sublist (get-text buf) LStart (bookmark:line bmark)))))))

      ((>= (bookmark:line bmark) LEnd)
       (bookmark:line! bmark (- (bookmark:line bmark) (- LEnd LStart))))))
   (get-bookmarks buf)))


(define-method (get-active-data-location (buf <CBuffer>))
  "Counts the number of characters between the beginning of the CBuffer
and the active data position."
  (let ((txt (get-text buf))
        (LCur (get-line-cur buf))
        (PdCur (get-pd-cur buf)))
    (let loop ((i 0)
               (n 0)
               (txtCur (car txt))
               (txtRest (cdr txt)))
      (cond
       ((< i LCur)
        (loop (1+ i)
              (+ 1 n (string-length txtCur)) ; note the added 1 for the line feed
              (car txtRest)
              (cdr txtRest)))
       (else
        (+ n PdCur))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MODIFYING OPERATIONS

;; These are primitives that need to add undo information

(define-method (op-insert-in-line-before (buf <CBuffer>) LInsert PInsert txt)
  (let ((LenInsert (string-length txt)))

  (append-undo! buf (list 'op-insert-in-line-before LInsert PInsert txt))

  ;; Insert the text into the line
  (strlist-insert-in-line (get-text buf) LInsert PInsert txt)

  ;; Move the active data position
  (set-line-and-pd-cur! buf (pos-insert-in-line-before (get-line-cur buf) (get-pd-cur buf)
                                                       LInsert PInsert LenInsert))
  ;; Clear the mark
  (set-mark-flag! buf #f)

  ;; Adjust the bookmarks and tags
  (adjust-poslist-insert-in-line-before (get-tags buf) LInsert PInsert LenInsert)
  (adjust-poslist-insert-in-line-before (get-bookmarks buf) LInsert PInsert LenInsert)))

(define-method (op-insert-in-line-after (buf <CBuffer>) LInsert PInsert txt)
  (let ((LenInsert (string-length txt)))

  (append-undo! buf (list 'op-insert-in-line-after LInsert PInsert txt))

  ;; Insert the text into the line
  (strlist-insert-in-line (get-text buf) LInsert PInsert txt)

  ;; Move the active data position
  (set-line-and-pd-cur! buf (pos-insert-in-line-after (get-line-cur buf) (get-pd-cur buf)
                                                      LInsert PInsert LenInsert))
  ;; Clear the mark
  (set-mark-flag! buf #f)

  ;; Adjust the bookmarks and tags
  (adjust-poslist-insert-in-line-after (get-tags buf) LInsert PInsert LenInsert)
  (adjust-poslist-insert-in-line-after (get-bookmarks buf) LInsert PInsert LenInsert)))

(define-method (op-replace-in-line (buf <CBuffer>) LReplace PReplaceStart PReplaceEnd txt)
  (let ((LenReplace (string-length txt)))

    ;; Overwrite the text in the line, and adjust bookmarks and tags
    (let ((replacetxt (strlist-replace-in-line (get-text buf) LReplace PReplaceStart PReplaceEnd txt))
          (replacetags (adjust-poslist-replace-in-line (get-tags buf) LReplace PReplaceStart PReplaceEnd LenReplace))
          (replacebmarks (adjust-poslist-replace-in-line (get-bookmarks buf) LReplace PReplaceStart PReplaceEnd LenReplace)))

      (append-undo! buf (list 'op-replace-in-line LReplace PReplaceStart PReplaceEnd txt replacetxt replacetags replacebmarks))

      ;; Move the activive data position
      (set-line-and-pd-cur! buf (pos-replace-in-line (get-line-cur buf) (get-pd-cur buf)
                                                     LReplace PReplaceStart PReplaceEnd LenReplace))

      ;; Clear the mark
      (set-mark-flag! buf #f))))

(define-method (op-move-in-line (buf <CBuffer>) LMove PMoveStart PMoveEnd PMoveAfter)
  (let ((LenMove (- PMoveEnd PMoveStart)))

    ;; Overwrite the text in the line, and adjust bookmarks and tags
    (strlist-move-in-line (get-text buf) LMove PMoveStart PMoveEnd PMoveAfter)
    (adjust-poslist-move-in-line (get-tags buf) LMove PMoveStart PMoveEnd PMoveAfter)
    (adjust-poslist-move-in-line (get-bookmarks buf) LMove PMoveStart PMoveEnd PMoveAfter)

    (append-undo! buf (list 'op-move-in-line LMove PMoveStart PMoveEnd PMoveAfter))

    ;; Move the activive data position
    (set-line-and-pd-cur! buf (pos-move-in-line (get-line-cur buf) (get-pd-cur buf)
                                                LMove PMoveStart PMoveEnd LenMove))

    ;; Clear the mark
    (set-mark-flag! buf #f)))

(define-method (op-copy-in-line (buf <CBuffer>) LCopy PCopyStart PCopyEnd PCopyAfter followCopy)
  (let ((LenCopy (- PCopyEnd PCopyStart)))

    ;; Overwrite the text in the line, and adjust bookmarks and tags
    (strlist-copy-in-line (get-text buf) LCopy PCopyStart PCopyEnd PCopyAfter)

    ;; Note that tags are duplicated under a copy operaton, but,
    ;; bookmarks are not duplicated and stay with the original.
    (poslist-copy-in-line (get-tags buf) LCopy PCopyStart PCopyEnd PCopyAfter)
    (adjust-poslist-copy-in-line (get-bookmarks buf) LCopy PCopyStart PCopyEnd PCopyAfter #f)

    (append-undo! buf (list 'op-copy-in-line LCopy PCopyStart PCopyEnd PCopyAfter))

    ;; Move the active data position
    (set-line-and-pd-cur! buf (pos-copy-in-line (get-line-cur buf) (get-pd-cur buf)
                                                LCopy PCopyStart PCopyEnd LenCopy #f))

    ;; Clear the mark
    (set-mark-flag! buf #f)))

(define-method (op-delete-in-line (buf <CBuffer>) LDelete PDeleteStart PDeleteEnd)
  ;; Overwrite the text in the line, and adjust bookmarks and tags
  (let ((deletetxt (strlist-delete-in-line (get-text buf) LDelete PDeleteStart PDeleteEnd))
        (deletetags (adjust-poslist-delete-in-line (get-tags buf) LDelete PDeleteStart PDeleteEnd))
        (deletebmarks (adjust-poslist-delete-in-line (get-bookmarks buf) LDelete PDeleteStart PDeleteEnd)))

    (append-undo! buf (list 'op-delete-in-line LDelete PDeleteStart PDeleteEnd deletetxt deletetags deletebmarks))

    ;; Move the activive data position
    (set-line-and-pd-cur! buf (pos-delete-in-line (get-line-cur buf) (get-pd-cur buf)
                                                  LDelete PDeleteStart PDeleteEnd))

    ;; Clear the mark
    (set-mark-flag! buf #f)))

(define-method (op-insert-lines-before (buf <CBuffer>) LInsert txt)
  (let ((LCount (length txt)))
    ;; Add the op to the list of mutator operations
    (append-undo! buf (list 'op-insert-lines-before LInsert txt))

    ;; Insert the line into the string list
    (let ((bufTxt (get-text buf)))
      (set-text! buf (append (take bufTxt LInsert)
                             txt
                             (drop bufTxt LInsert))))

    ;; Clear the mark.
    (set-mark-flag! buf #f)

    (set-line-and-pd-cur! buf (pos-insert-lines-before (get-line-cur buf) (get-pd-cur buf)
                                                       LInsert LCount))

    ;; Adjust bookmarks and tags
    (adjust-poslist-insert-lines-before (get-tags buf) LInsert LCount)
    (adjust-poslist-insert-lines-before (get-bookmarks buf) LInsert LCount)))

(define-method (op-insert-lines-after (buf <CBuffer>) LInsert txt)
  (warn-if-false (list-of-strings? txt))
  (let ((LCount (length txt)))
    ;; Add the op to the list of mutator operations
    (append-undo! buf (list 'op-insert-lines-after LInsert txt))

    ;; Insert the line into the string list
    (let ((bufTxt (get-text buf)))
      (set-text! buf (append (take bufTxt LInsert)
                             txt
                             (drop bufTxt LInsert))))
    ;; Clear the mark.
    (set-mark-flag! buf #f)

    (set-line-and-pd-cur! buf (pos-insert-lines-after (get-line-cur buf) (get-pd-cur buf)
                                                      LInsert LCount))

    ;; Adjust bookmarks and tags
    (adjust-poslist-insert-lines-after (get-tags buf) LInsert LCount)
    (adjust-poslist-insert-lines-after (get-bookmarks buf) LInsert LCount)
    ))

(define-method (op-replace-lines (buf <CBuffer>) LReplaceStart LReplaceEnd strlist)
  "Replace the lines from LStart (inclusive) and LEnd (exclusive)
with strlist"
  (let ((LenReplace (length strlist)))

    ;; Overwrite the text in the line, and adjust bookmarks and tags
    (let ((replacetxt (strlist-replace-lines (get-text buf)
                                             LReplaceStart
                                             LReplaceEnd strlist))
          (replacetags (adjust-poslist-replace-lines (get-tags buf)
                                                     LReplaceStart
                                                     LReplaceEnd
                                                     LenReplace))
          (replacebmarks (adjust-poslist-replace-lines (get-bookmarks buf)
                                                       LReplaceStart
                                                       LReplaceEnd
                                                       LenReplace)))

      (append-undo! buf (list 'op-replace-lines
                              LReplaceStart LReplaceEnd
                              strlist
                              replacetxt replacetags replacebmarks))

      ;; Move the active data position
      (let ((newpos (pos-replace-lines (get-line-cur buf)
                                       (get-pd-cur buf)
                                       LReplaceStart
                                       LReplaceEnd
                                       LenReplace)))
        ;; If newpos is '(), the location of the active data position
        ;; was overwritten in this operation.  So, put it after the paste,
        ;; I guess.
        (if (null? newpos)
            (set-line-and-pd-cur! buf (list LReplaceEnd 0))
            (set-line-and-pd-cur! buf newpos)))

      ;; Clear the mark
      (set-mark-flag! buf #f))))

(define-method (op-delete-lines (buf <CBuffer>) LDeleteStart LDeleteEnd)
  "Delete the lines from LStart (inclusive) and LEnd (exclusive)."

  ;; Overwrite the text in the line, and adjust bookmarks and tags
  (let ((deletetxt (strlist-delete-lines (get-text buf)
                                         LDeleteStart LDeleteEnd))
        (deletetags (adjust-poslist-delete-lines (get-tags buf)
                                                 LDeleteStart LDeleteEnd))
        (deletebmarks (adjust-poslist-delete-lines (get-bookmarks buf)
                                                   LDeleteStart LDeleteEnd)))

    (append-undo! buf (list 'op-delete-lines
                            LDeleteStart LDeleteEnd
                            deletetxt deletetags deletebmarks))

    ;; Move the activive data position
    (let ((newpos (pos-delete-lines (get-line-cur buf)
                                                (get-pd-cur buf)
                                                LDeleteStart LDeleteEnd)))
      ;; If the position was deleted, move the cursor to the end
      ;; of the deleted region.
      (if (null? newpos)
          (set-line-and-pd-cur! buf (list LDeleteStart 0))
          (set-line-and-pd-cur! buf newpos)))

    ;; Clear the mark
    (set-mark-flag! buf #f)))

(define-method (op-move-lines (buf <CBuffer>) LMoveStart LMoveEnd LMoveAfter)
  "Move the lines from LStart (inclusive) and LEnd (exclusive) to the 
line LMoveAfter."

  ;; Overwrite the text in the line, and adjust bookmarks and tags
  (strlist-move-lines (get-text buf) LMoveStart LMoveEnd LMoveAfter)
  (adjust-poslist-move-lines (get-tags buf) LMoveStart LMoveEnd LMoveAfter)
  (adjust-poslist-move-lines (get-bookmarks buf) LMoveStart LMoveEnd LMoveAfter)

  (append-undo! buf (list 'op-move-lines LMoveStart LMoveEnd LMoveAfter))

  ;; Move the activive data position
  (set-line-and-pd-cur! buf (pos-move-lines (get-line-cur buf) (get-pd-cur buf)
                                            LMoveStart LMoveEnd LMoveAfter))

  ;; Clear the mark
  (set-mark-flag! buf #f))

(define-method (op-copy-lines (buf <CBuffer>) LCopyStart LCopyEnd LCopyAfter)
  "Copy the lines from LStart (inclusive) and LEnd (exclusive)."

  ;; Overwrite the text in the line, and adjust bookmarks and tags
  (strlist-copy-lines (get-text buf) LCopyStart LCopyEnd LCopyAfter)
  (poslist-copy-lines (get-tags buf) LCopyStart LCopyEnd LCopyAfter)
  (adjust-poslist-copy-lines (get-bookmarks buf) LCopyStart LCopyEnd LCopyAfter #f)

  (append-undo! buf (list 'op-copy-lines LCopyStart LCopyEnd LCopyAfter))

  ;; Move the activive data position
  (set-line-and-pd-cur! buf (pos-copy-lines (get-line-cur buf) (get-pd-cur buf)
                                            LCopyStart LCopyEnd LCopyAfter #t))

  ;; Clear the mark
  (set-mark-flag! buf #f))

(define-method (op-merge-lines (buf <CBuffer>) LMergeStart LMergeEnd)
  "Merge the lines from LStart (inclusive) and LEnd (exclusive)."

  ;; Overwrite the text in the line, and adjust bookmarks and tags
  (let ((PMergeLengthList (map string-length (sublist (get-text buf) LMergeStart LMergeEnd))))
    (strlist-merge-lines (get-text buf) LMergeStart LMergeEnd)
    (adjust-poslist-merge-lines (get-tags buf) LMergeStart LMergeEnd PMergeLengthList)
    (adjust-poslist-merge-lines (get-bookmarks buf) LMergeStart LMergeEnd PMergeLengthList)

    (append-undo! buf (list 'op-merge-lines LMergeStart LMergeEnd PMergeLengthList))

    ;; Move the activive data position
    (set-line-and-pd-cur! buf (pos-merge-lines (get-line-cur buf) (get-pd-cur buf)
                                               LMergeStart LMergeEnd PMergeLengthList))

    ;; Clear the mark
    (set-mark-flag! buf #f)))

(define-method (op-split-lines (buf <CBuffer>) LSplit PSplit)
  "Split the line LSplit into two lines at the position PSplit."

  ;; Overwrite the text in the line, and adjust bookmarks and tags
  (strlist-split-line (get-text buf) LSplit PSplit)
  (adjust-poslist-split-lines (get-tags buf) LSplit PSplit)
  (adjust-poslist-split-lines (get-bookmarks buf) LSplit PSplit)

  (append-undo! buf (list 'op-split-lines LSplit PSplit))

  ;; Move the activive data position
  (set-line-and-pd-cur! buf (pos-split-lines (get-line-cur buf) (get-pd-cur buf)
                                             LSplit PSplit))

  ;; Clear the mark
  (set-mark-flag! buf #f))

(define-method (undo (buf <CBuffer>))
  ;; Pop the last operation off the list of mutator operations
  ;; Dispatch the operation to its handler.
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; METHODS

;; BS - BACKSPACE

(define-method (backspace (buf <CBuffer>))
  "Move the active data position one character position in the
direction opposite that of the implicit movement."
  (increase-pd-cur! buf
                    (if (eqv? 'forward (get-implicit-movement-direction buf))
                        -1
                        1)))

;; CR - CARRIAGE RETURN

;; If the implicit movement direction is 'forward, move the active
;; data position to the line home position of the current line.
;; If the implicit movement direction is 'backward, move the
;; active data position to the line limit position of the current line.
;; CR

(define-method (carriage-return (buf <CBuffer>))
  "If the implicit movement direction is 'forward, move the active
data position to the line home position of the current line.  If the
implicit movement direction is 'backward, move the active data
position to the line-limit position of the current line."
  (let ((pos (if (eqv? 'forward (get-implicit-movement-direction buf))
                       (get-home-pos buf)
                       (get-limit-pos buf)))
        (len (get-text-cur-length buf)))
    (if (< len pos)
        (op-insert-in-line-after buf (get-line-cur buf) pos (make-string (- pos len) #\space)))
  (set-pd-cur! buf pos)))

;; LF - LINE FEED

;; Move the active data position to the corresponding character
;; position of the following line.

(define-method (line-feed (buf <CBuffer>))
  "Move the active data position to the corresponding character
position of the following line."
  (let ((LCur (get-line-cur buf))
        (LCount (get-line-count buf))
        (PdCur (get-pd-cur buf)))
    ;; If the following line doesn't exist, we'll append a line with
    ;; PdCur spaces to the end of the buffer.

    ;; Or if the following line is too short, we'll append the
    ;; appropriate number of spaces to the following line

    ;; Then move down.

    (when (= LCur (1- LCount))
      (op-insert-lines-after buf (get-line-count buf) (list (make-string PdCur #\space))))

    (let* ((txt (get-text-line buf (1+ LCur)))
           (txtLen (string-length txt)))
      (when (< txtLen PdCur)
        (op-insert-in-line-after buf (1+ LCur) txtLen (make-string (- PdCur txtLen) #\space))))

    (increase-line-cur! buf 1)))

;; SLH - SET LINE HOME
(define-method (set-line-home (buf <CBuffer>) n)
  (set-home-pos! buf n))

;; SLL - SET LINE LIMIT
(define-method (set-line-limit (buf <CBuffer>) n)
  (set-limit-pos! buf n))

;; SM - SET MODE
(define-method (set-mode (buf <CBuffer>) mode val)
  (cond
   ((eqv? mode 'HEM)
    (if (member val (list 'following 'preceding))
        (begin
          (set-character-editing-mode! buf val)
          val)
        ;; else
        (error "unknown mode value ~a" val)))
   ((eqv? mode 'IRM)
    (if (member val (list 'insert 'replace))
        (begin
          (set-insertion-replacement-mode! buf val)
          val)
        ;; else
        (error "unknown mode value ~a" val)))
   (else
    (error "unknown mode ~a" mode))))

;; WC - WRITE-CHARACTER
(define-method (write-character (buf <CBuffer>) c)
  (let ((LCur (get-line-cur buf))
        (PdCur (get-pd-cur buf))
        (IRM (get-insertion-replacement-mode buf))
        (HEM (get-character-editing-mode buf))
        (IMM (get-invalid-movement-mode buf))
        (SIMD (get-implicit-movement-direction buf))
        (txtCur (get-text-cur buf))
        (len (get-text-cur-length buf)))

    ;; Normally,
    ;; if blocked, do nothing

    ;; If 'insertion, insert a character at location.
    (when (eqv? IRM 'insert)
      (op-insert-in-line-after buf LCur PdCur (string c))
      ;; If HEM is following, move the cursor in the implicit movement
      ;; direction.  If HEM is 'preceding, do no move the cursor.
      (when (eqv? HEM 'following)
        (increase-pd-cur! buf (if (eqv? SIMD 'forward) 1 -1))))

    ;; If 'deletion, overwrite text at location.
    (when (eqv? IRM 'replace)
      (if (= PdCur len)
          (op-insert-in-line-after buf LCur PdCur (string c))
          (op-replace-in-line buf LCur PdCur (1+ PdCur) (string c)))
      ;; Move cursor in the implicit movement direction.  (HEM has no
      ;; effect.)
      (increase-pd-cur! buf (if (eqv? SIMD 'forward) 1 -1)))

    ;; If the cursor is at a line extremum, maybe block or wrap.
    (when (= (get-limit-pos buf) (get-pd-cur buf))
      (when (member 'auto_right_margin IMM)
        (carriage-return buf)
        (line-feed buf)))))

(define-method (add-tag (buf <CBuffer>) id)
  (tag-set! (get-tags buf) id (get-line-cur buf) (get-pd-cur buf)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  OPERATIONS INSPIRED BY ED

(define-method (ed-append (buf <CBuffer>) lineno strlist)
  "Append the lines of text STRLIST at the addressed line LINENO.
The previous contents of LINENO and following lines will be pushed down.
The active data position will be set to the last inserted line, or, if
STRLIST was an empty list, to the addressed line.

If the implicit movement direction (SIMD) is 'forward, the active data
position will be placed as the last character position of the line.
If it is 'backward, it will be placed as the first character position
of the line."
  (let ((L (bracket-line buf lineno)))
    (log-debug-locals)
    (unless (null? strlist)
      (op-insert-lines-after buf L strlist))
    (if (null? strlist)
        (set-line-cur! buf L)
        (set-line-cur! buf (+ L (1- (length strlist)))))
    (set-pd-cur-to-simd-eol! buf)))

(define-method (ed-change (buf <CBuffer>) lstart lend strlist)
  "Remove the lines of text from LStart (inclusive) to LEnd (exclusive),
and insert strlist as a replacement to the deleted lines.

If strlist is non-null, the active data line is set to the last
inserted line. If the implicit movement direction (SIMD) is 'forward,
the active data position will be placed at the last character position
of the line.  If SIMD is 'backward, the data position is the first
character position.

If strlist is null, the active data line is set after the last deleted
line.  The active data position will be at the first character
position when SIMD is 'forward, or at the last character position if
SIMD is 'backward.

If strlist is null and the deleted range was at the end of the buffer,
the active data line set to the end of the line before the deletion
region. It will be at the last charcter position if SIMD is 'forward,
or the first character position if SIMD is 'negative."
  (let* ((LStart (bracket-line buf lstart))
         (LEnd (bracket-line buf lend))
         (ReplaceLen (length strlist)))

    (if (null? strlist)
        (op-delete-lines buf LStart LEnd)
        (op-replace-lines buf LStart LEnd strlist))
    (cond
     ((and (null? strlist) (<= (get-line-count buf) LStart))
      (set-line-cur! buf (1- (get-line-count buf)))
      (set-pd-cur-to-simd-eol! buf))

     ((and (null? strlist) (> (get-line-count buf) LStart))
      (set-line-cur! buf LStart)
      (set-pd-cur-to-simd-bol! buf))

     (else
      (set-line-cur! buf (+ LStart (1- ReplaceLen)))
      (set-pd-cur-to-simd-eol! buf)))))

(define-method (ed-copy (buf <CBuffer>) lcopybegin lcopyend lcopyafter)
  "Make a copy of the lines between LCopyBegin (inclusive) and
LCopyEnd (exclusive) and position that copy after the line
LCopyAfter.

The active data line will be set to the new location of the last line
copied.  If the implicit movement direction (SIMD) is 'forward, the
data position will be at the last character position in that line.  If
it is 'backward, it will be at the first character position in that
line."
  (let ((LCopyBegin (bracket-line buf lcopybegin))
        (LCopyEnd (bracket-line buf lcopyend))
        (LCopyAfter (bracket-line buf lcopyafter)))
    (if (> LCopyEnd LCopyBegin)
        (begin
          (op-copy-lines buf LCopyBegin LCopyEnd LCopyAfter)))
    (set-line-cur! buf (+ LCopyAfter (- LCopyEnd LCopyBegin)))
    (set-pd-cur-to-simd-eol! buf)))

(define-method (ed-delete (buf <CBuffer>) lstart lend)
  "Remove the lines of text from LStart (inclusive) to LEnd (exclusive).

The active data line is set after the last deleted line.  The active
data position will be at the first character position when SIMD is
'forward, or at the last character position if SIMD is 'backward.

If the deleted range was at the end of the buffer, the active data
line set to the end of the line before the deletion region. It will be
at the last charcter position if SIMD is 'forward, or the first
character position if SIMD is 'negative."
  (let* ((LStart (bracket-line buf lstart))
         (LEnd (bracket-line buf lend)))

    (op-delete-lines buf LStart LEnd)
    (cond
     ((<= (get-line-count buf) LStart)
      (set-line-cur! buf (1- (get-line-count buf)))
      (set-pd-cur-to-simd-eol! buf))

     (else
      (set-line-cur! buf LStart)
      (set-pd-cur-to-simd-bol! buf)))))

(define-method (ed-delete-all (buf <CBuffer>))
  "This deletes all the contents of the current buffer and places the
active data position in the first position."
  #f)

(define-method (ed-edit (buf <CBuffer>) input-port)
  "Delete the entire contents of the buffer, and then read in from the
port, line by line, appending those lines to the buffer.  Read until
#<eof> is found.

The active data position will be set to the last line in the buffer.
If the implicit movement direction (SIMD) is 'forward, it is placed at
the last character position in the line.  If SIMD is 'backward, it is
placed at the first character position."
  (ed-delete buf 0 (get-line-count buf))
  (let ((bytes-read 0))
    (while #t
      (let ((txt (read-line input-port)))
        (if (eof-object? txt)
            (break)
            (begin
              (set! bytes-read (+ bytes-read (string-length txt) 1))
              (ed-append buf (1+ (get-line-cur buf)) (list txt))))))
    bytes-read))

(define-method (ed-get-mark (buf <CBuffer>) name)
  "Return the line number in which a bookmark has been placed, or
#f is no such bookmark exists."
  (let ((bm (bookmark-get (get-bookmarks buf) name)))
    (and bm
         (list-ref bm 1))))

;; N.B. ed-insert is supposed to behave similarly to ed-append
(define-method (ed-insert (buf <CBuffer>) lineno strlist)
  "insert the lines of text STRLIST before the addressed line LINENO.

If strlist is not null, the active data position will be set to the
last inserted line. If the implicit movement direction (SIMD) is
'forward, the active data position will be placed as the last
character position of the line.  If it is 'backward, it will be placed
as the first character position of the line.

If strlist is null, the active data line will be set to LINENO.  If
SIMD is 'forward, the active data position will be at the first
character position of the line.  If SIMD is 'backward, the active data
position will be at the last character position in the line."
  (let ((L (bracket-line buf lineno))
        (SIMD (get-implicit-movement-direction buf)))
    (unless (null? strlist)
      (op-insert-lines-before buf L strlist))
    (if (null? strlist)
        (begin
          (set-line-cur! buf L)
          (set-pd-cur-to-simd-bol! buf))
        ;; else
        (begin
          (set-line-cur! buf (bracket-line buf (1- L)))
          (set-pd-cur-to-simd-eol! buf)))))

(define-method (ed-join (buf <CBuffer>) lstart lend)
  "Combine the lines LStart (inclusive) to LEnd (exclusive) into a single
line. The active data position will be moved to the last character position of
that joined line if SIMD is 'forward, or to the first character position if
SIMD is 'backward."
  (let ((LStart (bracket-line buf lstart))
        (LEnd (bracket-line buf lend)))
    (op-merge-lines buf LStart LEnd)
    (set-line-cur! buf LStart)
    (set-pd-cur-to-simd-eol! buf)))

(define-method (ed-line-number (buf <CBuffer>))
  "Return the address of the active data line."
  (get-line-cur buf))

(define-method (ed-mark (buf <CBuffer>) lineno name)
  "Set a bookmark at the first data position of the given lineno if
implicit movement direction (SIMD) is 'forward, or at the last data
position of the line, if SIMD is 'backward."
  (let ((L (bracket-line buf lineno)))
    (bookmark-set! (get-bookmarks buf) name
                   L
                   (if (eqv? (get-implicit-movement-direction buf) 'forward)
                       0
                       (get-text-cur-length buf)))))

(define-method (ed-move (buf <CBuffer>) lmovebegin lmoveend lmoveafter)
  "Reposition the lines between LMoveBegin (inclusive) and
LMoveEnd (exclusive) to after the line LMoveAfter.

The active data line will be set to the new location of the last line
moved.  If the implicit movement direction (SIMD) is 'forward, the
data position will be at the last character position in that line.  If
it is 'backward, it will be at the first character position in that
line."
  (let ((LMoveBegin (bracket-line buf lmovebegin))
        (LMoveEnd (bracket-line buf lmoveend))
        (LMoveAfter (bracket-line buf lmoveafter)))
    (op-move-lines buf LMoveBegin LMoveEnd LMoveAfter)
    (set-line-cur! buf (+ LMoveAfter (- LMoveEnd LMoveBegin)))
    (set-pd-cur-to-simd-eol! buf)))

(define-method (ed-null (buf <CBuffer>))
  (get-line-cur buf))

(define-method (ed-read (buf <CBuffer>) lineno input-port)
  "Read in from the port, line by line, appending those lines to the
buffer after LINENO.  Read until #<eof> is found.

The active data position will be set to the last line read in..
If the implicit movement direction (SIMD) is 'forward, it is placed at
the last character position in the line.  If SIMD is 'backward, it is
placed at the first character position."
  (let ((L (bracket-line buf lineno))
        (bytes-read 0))
    (set-line-cur! buf L)
    (while #t
      (let ((txt (read-line input-port)))
        (if (eof-object? txt)
            (break)
            (begin
              (set! bytes-read (+ bytes-read (string-length txt) 1))
              (ed-append buf (get-line-cur buf) (list txt))
              (set-line-cur! buf (1+ L))))))
    (set-pd-cur-to-simd-eol! buf)
    bytes-read))

(define-method (ed-regex-search-backward-line (buf <CBuffer>) lineno regex)
  "This searches the the text for the first line that matches the
regular expression.  The search begins on the line before lineno. The
search will wrap around to the end of the buffer, if necessary, and
search upto and including lineno.

If a match is found, the procedure returns the line number of the
matching line, and the active data position will be set to the end of
the matching line.  If a match is not found, the procedure returns #f
and the active data position is unchanged."
  (if (= (get-line-count buf) 0)
      #f
      ;; else
      (let* ((rx (make-regexp regex-string))
             (next-line (lambda (n)
                          (if (< (1- n) 0)
                              (1- (get-line-count buf))
                              (1- n))))
             (start-line (next-line (bracket-line buf lineno))))
        (let loop ((i start-line))
          (if (regexp-exec rx (list-ref (get-text buf) i))
              (begin
                (set-line-cur! buf i)
                (set-pd-cur-to-simd-eol! buf)
                i)
              ;; else
              (if (= (next-line i) start-line)
                  #f
                  ;; else
                  (loop (next-line i))))))))

(define-method (ed-regex-search-forward-line (buf <CBuffer>) regex)
  "This searches the text for the first line that matches the regular
expression.  The search begins on the line after lineno. The search
will wrap around the end of the buffer, if necessary, and search upto
and including lineno.

If a match is found, the procedure returns the line number of the
matching line, and the active data position will be set to the end of
the matching line.  If a match is not found, the procedure returns #f
and the active data position is unchanged."
  (if (= 0 (get-line-count buf))
      #f
      ;; else
      (let* ((rx (make-regexp regex-string))
             (next-line (lambda (n)
                          (if (>= (1+ n) (length (get-text buf)))
                              0
                              (1+ n))))
             (start-line (next-line (bracket-line buf lineno))))
        (let loop ((i start-line))
          (if (regexp-exec rx (list-ref (get-text buf) i))
              (begin
                (set-line-cur! buf i)
                (set-pd-cur-to-simd-eol! buf)
                i)
              ;; else
              (if (= (next-line i) start-line)
                  #f
                  ;; else
                  (loop (next-line i))))))))

(define-method (ed-write (buf <CBuffer>) lstart lend port)
  "Write the buffer lines LStart (inclusive) through LEnd (exclusive)
to the given port.  It returns the number of bytes written."
  (let ((LStart (bracket-line buf lstart))
        (LEnd (bracket-line buf lend))
        (bytes-written 0))
    (for-each
     (lambda (line)
       (write-line line port)
       (+= bytes-written (1+ (string-length line))))
     (sublist (get-text buf) LStart LEnd))
    bytes-written))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; OPERATIONS

;; BS - backspace

;; CAN - Treat the last operation as erroneous. Undo it and keep no
;; record of it on the stack.
(define-method (op-cancel (buf <CBuffer>))
  `(can))

(define-method (apply-op-cancel (buf <CBuffer>) op)
  (let ((prev-op (pop-last-op! buf)))
    (if prev-op
        (push-op! buf prev-op 'undo))))

(define-method (cancel (buf <CBuffer>))
  "Undo the previous operation, if any.

The cancel operation is special in that it is never stored in the
queue and can't be undone."
  (push-op! buf (op-cancel))
  (run-op buf))

;; CBT
(define-method (cursor-backward-tabulation (buf <CBuffer>) n)
  "Move the active presentation position to the character position
corresponding to the n-th preceding character tabulation stop in the
presentation component"
  (let* ([ppCur (get-pp-cur buf)]
         [tabsize (get-tab-size buf)]
         ;; Back up n tabsizes
         [pp1 (max 0 (compute-tab-column ppCur tabsize (- n)))])
    (set-positions! buf pp1 'presentation)))

;; CCH - UNIMPLEMENTED
(define-method (cancel (buf <CBuffer>))
  "Undo the previous graphic character"
  #f)

;; CHA
(define-method (cursor-character-absolute (buf <CBuffer>) n)
  "Move the active presentation position to character position n in
the active line in the presentation component"
  (set-positions! buf n 'presentation))

;; CHT
(define-method (cursor-forward-tabulation (buf <CBuffer>) n)
  "Move the active presentation position to the character position
corresponding to the n-th following character tabulation stop in the
presentation component"
  (let* ([ppList (compute-pp-list-from-string (get-text-cur buf)
                                              (get-tab-size buf))]
         ;; Move forward n tabsizes
         [tabsize (get-tab-size buf)]
         [pp (compute-tab-column (get-pp-cur buf) tabsize n)])
    (set-positions! buf pp 'presentation)))

;; CNL
(define (cursor-next-line buf n)
  "Move the active presentation position to the 1st character position
of the n-th following line in the presentation component"
  (let* ([LCur (get-line-cur buf)]
         ;; Move forward n lines, or to the end of the buffer
         [L1 (bracket-line buf (+ LCur n))])
    (when (> L1 (get-line-cur buf))
          (set-line-cur! buf L1)
          (update-pp-list! buf)
          (set-positions! buf 0 'data))))
;; CPL
(define (cursor-preceding-line buf n)
  "Move the active presentation position to the 1st character position
of the n-th preceding line in the presentation component"
  (let* ([LCur (get-line-cur buf)]
         ;; Move backward n lines, or to the beginning of the buffer
         [L1 (bracket-line buf (- LCur n))])
    (when (< L1 (get-line-cur buf))
          (set-line-cur! buf L1)
          (update-pp-list! buf)
          (set-positions! buf 0 'data))))

#|
;; CR
(define-method (carriage-return (buf <CBuffer>))
  "Move the active presentation position to the line home position of
the same line"
  (cond
   ((eq? (get-home-type buf) 'data)
    (set-positions! buf (get-home-pos buf) 'data))
   (else
    (set-positions! buf (get-home-pos buf) 'presentation))))
|#
;; CTC
(define-method (cursor-tabulation-control (buf <CBuffer>) n)
  "Set the number of spaces per tab to N"
  (set-tab-size! buf n))

;; CUB
(define-method (cursor-left (buf <CBuffer>) n)
  "Move the active presentation position leftwards in the presentation
component by n character positions"
  (set-positions! buf (max 0 (- (get-pp-goal buf) n)) 'presentation))

;; CUD
(define-method (cursor-down (buf <CBuffer>) n)
  "Move the active presentation position downwards in the presentation
component by N line positions"
  (let* ( ;; Move forward n lines, or to the end of the buffer
         [L1 (bracket-line buf (+ (get-line-cur buf) n))])
    (set-line-cur! buf L1)
    (update-pp-list! buf)
    (set-positions! buf (get-pp-cur buf) 'presentation)))

;; CUF
(define-method (cursor-right (buf <CBuffer>) n)
  "Move the active presentation position rightwards in the
presentation component by n character positions"
  (set-positions! buf (min (get-pp-max buf)
                           (+ (get-pp-goal buf) n))
                  'presentation))

;; CUP
(define-method (cursor-position (buf <CBuffer>) n m)
  "Move the active presentation position to the n-th line and m-th
character position in the presentation component"
  (set-line-cur! buf (bracket-line buf n))
  (update-pp-list! buf)
  (set-positions! buf m 'presentation))

;; CUU
(define-method (cursor-up (buf <CBuffer>) n)
  "Move the active presentation positions upwards in the presentation
component by N line positions"
  (let* (
         ;; Move backward n lines, or to the top of the buffer
         [L1 (bracket-line buf (- (get-line-cur buf) n))])
    (set-line-cur! buf L1)
    (update-pp-list! buf)
    (set-positions! buf (get-pp-cur buf) 'presentation)))

;; CVT
(define-method (cursor-line-tabulation (buf <CBuffer>) n)
  "Causes the active presentation position to be moved to the
corresponding character position of the line corresponding to the n-th
following line tabulation stop in the presentation component."
  (let* (
         ;; Move down n vert-tabsizes
         [tabsize (get-vert-tab-size buf)]
         [L (compute-tab-column (get-line-cur buf) tabsize n)])
    (set-line-cur! buf (bracket-line buf L))
    (set-positions! buf (get-pp-cur buf) 'presentation)))

;; DA
(define-method (device-attributes (buf <CBuffer>))
  "Returns a string identifying this class"
  "CBuffer 0.0")

;; DSR
(define-method (device-status-report (buf <CBuffer>) device)
  "If the device is 'presentation, report the active presentation position as
line, position.  If device is 'data, report the active data position."
  (cond
   ((eq? device 'data)
    (cons (get-line-cur buf) (get-pd-cur buf)))
   (else
    (cons (get-line-cur buf) (get-pp-cur buf)))))

;; DCH
(define-method (delete-character buf device)
  "This removes the character at the active data position.  The
characters to the right of the active data position are moved left to
fill in the gap.  If the active data position it at the end of the
line, nothing happens.  If device is 'presentation, the characters are
shifted one cell, even if the character was double-width.  If device
is 'data, the characters are shifted one character."
  (let* ([txt (get-text-cur buf)]
         [pd (get-pd-cur buf)]
         [len (get-text-cur-length)]
         [width (wcwidth (string-ref txt pd))])
    (cond
     [(= len 0)
      *unspecified*]
     [(= pd len)
      *unspecified*]
     [(= pd 0)
      (cond
       ((eq? device 'presentation)
        (set-text-cur! buf (string-append (make-string (1- w) #\space)
                                          (string-drop txt 1))))
       (else
        (set-text-cur! buf (string-drop txt 1))))]
     [else
      (cond
       ((eq? device 'presentation)
        (set-text-cur! buf (string-append (string-take txt (1- pd))
                                          (make-string (1- w) #\space)
                                          (string-drop txt pd))))
       (else
        (set-text-cur! buf (string-append (string-take txt (1- pd))
                                          (string-drop txt pd)))))])

    ;; (update-pd-list! buf)
    (set-positions! buf pd 'data)))

;; DL
(define-method (delete-line (buf <CBuffer>) n)
  "Causes the active line and the n-1 following lines to be removed
from the buffer.  The resulting gap is closed by moving the adjacent
lines up.  The cursor is placed at the home position of the active line.  If
all the lines to the end of the buffer had been deleted, a new empty line is
added to the end of the buffer."
  (error "fixme"))

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

(define-method (character-position-absolute (buf <CBuffer>) n)
  "Move the active data position to the n-th codepoint in the active
line"
  (let* ([pd (bracket-pd buf n)])
    (set-positions! buf pd 'data)))

(define-method (character-position-backward (buf <CBuffer>) n)
  "Move the active data position backward n codepoints"
  (let* ([pd (bracket-pd buf (- (get-pd-cur buf) n))])
    (set-positions! buf pd 'data)))

(define-method (character-position-forward (buf <CBuffer>) n)
  "Move the active data position forward n codepoints"
  (let* ([pd (bracket-pd buf (+ (get-pd-cur buf) n))])
    (set-positions! buf pd 'data)))

(define-method (character-and-line-position (buf <CBuffer>) n m)
  "Moves the active data position to the n-th line position m-th
character position"
  (set-line-cur! buf (bracket-line buf n))
  (update-pp-list! buf)
  (character-position-absolute buf m))






(define-method (delete-in-line buf P)
  "This removes some or all of the characters in the current line.
If P is zero, the active position through the end of the line are
deleted.  If P is one, the beginning of the line through the active
position are deleted; the remaining characters in the line are shifted
left to fill in the gap; and, the cursor is placed at the beginning of
the line.  If P is two, all the characters in the line are removed,
and the cursor is placed at the beginning of the now-empty line."
  (let ([txt (get-text-cur buf)]
        [pd (get-pd-cur buf)])
    (cond
     [(= P 0)
      (set-text-cur! buf (string-take txt pd))
      ;; (update-pd-list! buf)
      (set-positions! buf pd 'data)]
     [(= P 1)
      (set-text-cur! buf (string-drop txt (1+ pd)))
      ;; (update-pd-list! buf)
      (set-positions! buf 0 'data)]
     [(= P 2)
      (set-text-cur! buf "")
      ;; (update-pd-list! buf)
      (set-positions! buf 0 'data)]
     [else
      (error "FIXME")])))

;; ECH
(define-method (erase-character buf device)
  "This replaces the character at the active data postion with the
space character.  If DEVICE is 'presentation, multi-cell graphemes
will be replaced with multiple space characters.  If DEVICE is 'data,
the current codepoint will be replaced with a single space character."
  (let ([txt (get-text-cur buf)]
        [pd (get-pd-cur buf)]
        [len (get-text-cur-length buf)])
    (cond
     [(string-null? txt)
      *unspecified*]
     [(= pd len)
      *unspecified*]
     [(eq? device 'data)
      (set-text-cur! buf (string-set! txt pd #\space))]
     [(eq? device 'presentation)
      (let ([ch (string-ref txt pd)])
        (if (char=? ch #\tab)
            (set-text-cur! buf (string-append (string-take txt pd)
                                              (make-string (- (compute-tab-column pd (get-tab-size buf) 1)
                                                              pd)
                                                           #\space)
                                              (string-drop txt (1+ pd))))
            ;; else
            (set-text-cur! buf (string-append (string-take txt pd)
                                              (make-string (wcwidth (string-ref txt pd)) #\space)
                                              (string-drop txt (1+ pd))))))])
    ;; (update-pd-list! buf)
    (set-positions! buf 0 'presentation)))

;; EL
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

  ;;(add-undo (list 'EL device P (get-text-cur buf) (get-pd-cur buf) (get-text-line buf)))

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
      (when (and (is-mark-set? buf)
                 (= (get-line-cur buf) (get-line-mark buf))
                 (>= pd-mark pd-cur))
            (set-mark-flag! buf #f))]
     [(and (eqv? device 'data) (= P 0))
      (set-text! buf (string-append (string-take text-cur pd-cur)
                                    (make-string (- (string-length text-cur) pd-cur) #\space)))
      ;; Clear the mark if its position has been erased
      (when (and (is-mark-set? buf)
                 (= (get-line-cur buf) (get-line-mark buf))
                 (>= pd-mark pd-cur))
            (set-mark-flag! buf #f))]

     ;; Erase from the beginning of the line to here
     [(and (eqv? device 'presentation) (= P 1))
      (when (and (is-mark-set? buf)
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
      (when (and (is-mark-set? buf)
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
      (when (and (is-mark-set? buf)
                 (= (get-line-cur buf) (get-line-mark buf)))
            (set-mark-flag! buf #f))
      ;; Erase the line
      (set-text! buf (make-string (last ppList)))
      (set-pd-cur! buf pp-cur)]
     [(and (eqv? device 'data) (= P 2))
      ;; If the mark is on this line, erase it
      (when (and (is-mark-set? buf)
                 (= (get-line-cur buf) (get-line-mark buf)))
            (set-mark-flag! buf #f))
      ;; Erase the line
      (set-text! buf (make-string (string-length text-cur) #\space))
      (set-pp-cur! buf pd-cur)
      (set-pp-goal! buf pd-cur)])))

;; FF
(define-method (form-feed (buf <CBuffer>))
  "FF causes the frame to be moved one frame-size down toward the end
of the buffer.  The active presentation position to be moved to the
corresponding character position of the line at the page home position
of that next page in the presentation component."
  (when
   ;; If there is at least a  partial page below this one
   (< (+ (get-line-frame buf) (get-line-frame-size buf))
      (get-line-count buf))
   (set-line-frame! buf (+ (get-line-frame buf) (get-line-frame-size buf)))
   (set-line-cur! buf (min (get-line-count buf)
                           (+ (get-line-frame buf) (get-page-home-line buf))))))

(define-method (insert-character-space (buf <CBuffer>) n)
  "Shift the contents of the line to the right, starting at the
current data position, creating an empty gap of N codepoints.  The
active position is unchanged."
  ;;(add-undo (list 'ICH n (get-text-cur buf) (get-pd-cur buf)))

  (let ([str (get-text-cur buf)]
        [pd (get-pd-cur buf)])
    ;; Add some space at the current position.
    (set-text-cur! buf
                   (string-append (string-take str pd)
                                  (make-string n #\space)
                                  (string-drop str pd)))

    ;; Update the list of presentation positions.
    (update-pp-list! buf)

    ;; Move the mark right, if necessary
    (when (and (is-mark-set? buf)
               (= (get-line-mark buf) (get-line-cur buf))
               (>= (get-pd-mark buf) (get-pd-cur buf)))
          (set-pd-mark! buf (+ (get-pd-mark buf) n)))))

(define-method (insert-line-space (buf <CBuffer>) n)
  "Move the current line and the n-1 following lines down N lines.
The resulting cap is erased.  The cursor is placed at the home
position of the first new empty line."
  ;;(add-undo buf (list 'IL n (get-text-cur) (get-pd-cur)))

  (let ([txt (get-text buf)]
        [L (get-line-cur buf)])
    (set-text! buf (append (take txt L)
                           (make-list n "")
                           (drop txt L)))
    (set-pd-cur! buf 0)
    (set-pp-cur! buf 0)
    (set-pp-goal! buf 0)

    ;; Move the mark down, if necessary
    (when (and (is-mark-set? buf)
               (>= (get-line-mark) L))
          (set-line-mark! buf (+ (get-line-mark) n)))))

(define-method (insert-nel (buf <CBuffer>))
  "Removes the text between the active position and the end of the
line from the current line, and places it in a new line inserted after
the current line.  The active position is moved to the beginning of
the new line."
  (let ([txt (get-text buf)]
        [txtcur (get-text-cur buf)]
        [pd (get-pd-cur buf)]
        [L (get-line-cur buf)])
    (format (current-error-port) "insert-nel: before txtcur ~a pd ~a L ~a~%" txtcur pd L)
    (set-text! buf (append (take txt L)
                           (list (string-take txtcur pd))
                           (list (string-drop txtcur pd))
                           (drop txt (min (1+ L)))))
    ;; Move the mark down, if necessary
    (when (is-mark-set? buf)
          (cond
           [(and (= (get-line-mark buf) L) (>= (get-pd-mark buf) pd))
            (set-line-mark! buf (1+ L))
            (set-pd-mark! buf (- (get-pd-mark buf) pd))]
           [(>= (get-line-mark buf) L)
            (set-line-mark! buf (1+ L))]))

    (set-pd-cur! buf 0)
    (set-pp-cur! buf 0)
    (set-pp-goal! buf 0)
    (set-line-cur! buf (1+ L))
    (format (current-error-port) "insert-nel: after txtcur ~a pd ~a L ~a~%" (get-text-cur buf) (get-pd-cur buf) (get-line-cur buf))
    ))

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

(define-method (line-position-absolute (buf <CBuffer>) n)
  "Move the active data position to the n-th line"
  (set-line-cur! buf (min n (get-line-count buf)))
  (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))])
    (set-pp-cur! buf (list-ref ppList (get-pd-cur buf)))
    (set-pp-goal! buf (get-pp-cur buf))))

(define-method (line-position-backward (buf <CBuffer>) n)
  "Move the active data position up n line positions"
  (set-line-cur! buf (max 0 (- (get-line-cur) n)))
  (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))])
    (set-pp-cur! buf (list-ref ppList (get-pd-cur)))
    (set-pp-goal! buf (get-pp-cur))))

(define-method (line-position-forward (buf <CBuffer>) n)
  "Move the active data position down by n line positions"
  (set-line-cur! buf (min (+ (get-line-cur) n) (get-line-count buf)))
  (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))])
    (set-pp-cur! buf (list-ref ppList (get-pd-cur)))
    (set-pp-goal! buf (get-pp-cur))))

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

#|
(define-method (write-character (buf <CBuffer>) c)
  "Writes the graphical character C into the active data position,
overwriting the current character.  If DEVICE is 'data, the current
codepoint is replaced with C.  If DEVICE is 'presentation, those
graphemes that would be wholly or partly overwritten by this grapheme
will be erased before this grapheme is added."
  (cond
   [(eq? device 'data)
    (let ([txt (get-text-cur buf)]
          [pd (get-pd-cur buf)])
      (set-text-cur! buf (string-append (string-take txt pd)
                                        (string c)
                                        (string-drop txt (min (string-length txt) (1+ pd)))))

      ;; Update the list of presentation positions.
      (update-pp-list! buf)

      ;; Clear the mark if we're overwriting the mark
      (when (and (is-mark-set? buf)
                 (= (get-pd-mark buf) (get-pd-cur buf))
                 (= (get-line-cur buf) (get-line-mark buf)))
            (set-mark-flag! buf #f))
      ;; Move the cursor forward
      (set-pd-cur! buf (1+ (get-pd-cur buf)))
      (set-pp-cur! buf (get-pp-from-pd-cur buf))
      (set-pp-goal! buf (get-pp-cur buf)))]

   [(eqv? device 'presentation)
    (let* ([ppList (compute-pp-list-from-string (get-text-cur buf)
                                                (get-tab-size buf))]
           ;; Presentation position of start
           [pp-start (get-pp-cur buf)]
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
           [space-before-char (- (get-pp-cur buf) (list-ref ppList pd-start))]
           [space-after-char (max 0 (- (list-ref ppList pd-end) pp-end))]
           [txt (get-text-cur buf)])

      (format (current-error-port) "write-char pd-cur ~s pd-start ~s pd-end ~s pp-cur ~s pp-start ~s pp-end ~s space ~s;~s~%" (get-pd-cur buf) pd-start pd-end (get-pp-cur buf) pp-start pp-end space-before-char space-after-char)
      ;; Replace the tab characters with spaces
      (set-text-cur! buf (string-append (string-take txt pd-start)
                                        (make-string space-before-char #\space)
                                        (string c)
                                        (make-string space-after-char #\space)
                                        (string-drop txt pd-end)))
      ;; Update the list of presentation positions.
      (update-pp-list! buf)

      ;; Move the active position
      (set-pd-cur! buf (+ pd-start 1))
      (set-pp-cur! buf (get-pp-from-pd-cur buf))
      (set-pp-goal! buf (get-pp-cur buf)))]))
|#

(define-method (write-tabulation (buf <CBuffer>) device)
  "Writes a tab at the current position, overwriting the current character.
If DEVICE is 'data, the current codepoint is replace with a tab.  If
DEVICE is 'presentation, those graphemes that would be wholly or
partly overwritten by this tab will be erased before the tab is
added."
  (cond

   ;; If we're overwriting a tab with a tab
   [(and (< (get-pd-cur buf) (string-length (get-text-cur buf)))
         (eqv? #\tab (string-ref (get-text-cur buf) (get-pd-cur buf))))
    ;; Clear the mark if we're overwriting the mark
    (when (and (is-mark-set? buf)
               (= (get-pd-mark buf) (get-pd-cur buf))
               (= (get-line-cur buf) (get-line-mark buf)))
          (set-mark-flag! buf #f))
    ;; Don't replace anything, but move the cursor forward
    (set-pd-cur! buf (1+ (get-pd-cur buf)))
    (set-pp-cur! buf (get-pp-from-pd-cur buf))
    (set-pp-goal! buf (get-pp-cur buf))]

   [(eqv? device 'data)
    (let ([txt (get-text-cur buf)]
          [pd (get-pd-cur buf)])
      (set-text-cur! buf (string-append (string-take txt pd)
                                        (string #\tab)
                                        (string-drop txt (min (string-length txt) (1+ pd)))))
      ;; Clear the mark if we're overwriting the mark
      (when (and (is-mark-set? buf)
                 (= (get-pd-mark buf) (get-pd-cur buf))
                 (= (get-line-cur buf) (get-line-mark buf)))
            (set-mark-flag! buf #f))
      ;; Move the cursor forward
      (set-pd-cur! buf (1+ (get-pd-cur buf)))
      (set-pp-cur! buf (get-pp-from-pd-cur buf))
      (set-pp-goal! buf (get-pp-cur buf)))]

   [(eqv? device 'presentation)
    (let* ([ppList (compute-pp-list-from-string (get-text-cur buf)
                                                (get-tab-size buf))]
           [tabsize (get-tab-size buf)]
           ;; Presentation position of start of tab
           [pp-start (get-pp-cur buf)]
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
           [txt (get-text-cur buf)])

      ;; Replace the tab characters with spaces
      (set-text-cur! buf (string-append (string-take txt pd-start)
                                        (make-string space-num #\space)
                                        (string-drop txt pd-end)))
      (set-pd-cur! buf (+ pd-start space-num))
      (set-pp-cur! buf pp-adj-end)
      (set-pp-goal! buf pp-adj-end))]))

;; Local Variables:
;; coding: us-ascii
;; indent-tabs-mode: nil
;; End:
