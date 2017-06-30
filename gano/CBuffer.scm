=;;; -*- mode: scheme; coding: us-ascii; indent-tabs-mode: nil; -*-
;;; (gano CBuffer) - an storage model for lines of text
;;; Copyright (C) 2017 Michael L. Gran <spk121@yahoo.com>
;;;
;;; This program is free software: you can redistribute it and/or
;;; modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundataion, either version 3 of
;;; this License, or (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see
;;; <http://www.gnu.org/licenses/>

#|

A CBuffer is a data model for lines of plain text.  It can be
conceived as a list of strings, where the first element of the list is
a string that contains the first line of text, and so on.

The strings stored in a CBuffer must only consist of printable
characters.  No format effectors or presentation control functions are
stored.  The lone exception is the horizontal tab character.

The strings stored in CBuffers do not explicitly store line
terminations, like newline or carriage return.

(Someday, a separate list will store the line terminators for each
line. A line termination will exists for each line in the buffer.  A
line may be terminated by any of the allowed Unicode terminators, CR,
LF, NL, CRLF, LS, PS, FF, or VT.)

The text may be "decorated" with various bookmarks, tags, and spans.

A "bookmark" is a string that uniquely identifies one location in the
text.  No two bookmarks have the same name, and a bookmark points to a
single (line, column) location in the text.  A location in the text
shall not have more than one bookmark. One possible use for
bookmarks are as are intradocument navigation.

A "tag" is a string that labels a location (line, column) in the text.
There may be more than one tag by the same name, and a location in the
text may have more than one tag.  An example use for tags is
sectioning, such as "Chapter" or "Section".

A "span" is label that identifies a range of characters.  There may be
more than one span with the same name, and a location may be covered
by multiple spans.  Spans could be used for formatting.  Note that the
first location in a span points to the (line, column) of the first
character in the region, but the second (line,column) location in the
span points to the first character **not** in the region.  It is valid
for the 2nd location in a span to be the on the column after the end
of the line.  An example use for spans is markup, such as "bold"
or "italic".

To facilitate navigation operations in the text buffer, there are two
important locations: the "active data position" and the "mark".  This
"active data position"n is a special address that is used in the command set.
It is the location of a virtual cursor.  The "mark" is another special
location used to indicate the extreme of a selection of text or a
range of text used in operations.

To enable undo, redo, and delta operations, an "operations list" is stored.
And operations list is an ordered list that describes all the mutations
that have occured to the CBuffer, like inserted text, deleted text, etc.

|#

(define-module (gano CBuffer)
  #:use-module (oop goops)
  #:use-module (oop goops describe)
  #:use-module (ice-9 receive)
  #:use-module (ice-9 rdelim)
  #:use-module (srfi srfi-1)
  #:use-module (rnrs control)
  #:use-module ((ncurses extra) #:select (wcwidth))
  ;; #:use-module (gano debug)
  #:use-module (gano stringlist)
  #:use-module (gano poslist)
  #:use-module (gano position)
  #:use-module (mlg typechecking)
  #:use-module (mlg math)
  #:use-module (mlg logging)
  #:use-module (mlg strings)
  #:export (
            <CBuffer>
            ;; Constructors
            make-empty-cbuffer
            cbuffer?

            ;; Needed for testing for now
            %dump-cbuffer
            get-text-cur
            get-text
            get-undo
            add-tag
            get-tags
            get-bookmarks

            ;; The Almighty Undo
            undo

            ;; Dumb TTY Operations
            ;; bell                        ; BEL
            line-feed!                   ; LF
            carriage-return!             ; CR
            insert-character-in-line!

            ;; Line-editing Operations
            bookmark-bol!
            copy-lines!
            delete-lines!
            get-bookmark-line
            regex-tag-lines
            regex-tag-nonmatching-lines
            clear-tags
            for-each-tagged-line
            insert-lines!
            insert-lines-from-port
            join-lines
            move-lines
            regex-search-backward-line
            regex-search-forward-line
            replace-all-from-port
            replace-lines
            substitute-in-lines
            write-lines-to-port

            ;; Per-character Editing Operations
            bookmark-pos!
            pad-lines!
            pad-line-with-spaces!
            pad-to-position!
            insert-string-in-line
            replace-string-in-line
            delete-string-in-line
            backspace                   ; BS
            cancel                      ; CAN
            carriage-return             ; CR
            delete-character            ; DCH
            delete-line                 ; DL
            dimension-text-area         ; DTA
            erase-character             ; ECH
            erase-in-page               ; ED
            erase-in-field              ; EF
            erase-in-line               ; EL
            character-position-absolute ; HPA
            character-position-backward ; HPB
            character-position-forward  ; HPR
            character-and-line-position ; HVP
            insert-character-space      ; ICH
            insert-line                 ; IL
            line-feed                   ; LF
            next-line                   ; NEL
            page-format-selection       ; PFS
            page-position-absolute      ; PPA
            page-position-backward      ; PPB
            page-position-forward       ; PPR
            quad                        ; QUAD
            repeat                      ; REP
            reverse-line-feed           ; RI
            select-graphics-rendition   ; SGR
            set-line-home               ; SLH
            set-line-limit              ; SLL
            set-page-home               ; SPH
            set-page-limit              ; SPL
            line-position-absolute      ; VPA
            line-position-backward      ; VPB
            line-position-forward       ; VPR

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
  (m_rgText #:init-value '() #:accessor get-text #:setter set-text!)
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

(define (append-undo! buf op)
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
  (format #t "================~%")
  (format #t "Modes: IRM ~a, HEM ~a, IMM ~a, SIMD ~a~%"
          (get-insertion-replacement-mode buf)
          (get-character-editing-mode buf)
          (get-invalid-movement-mode buf)
          (get-implicit-movement-direction buf))
  (format #t "===BEGIN TEXT===~%")
  (let loop ((i 1) (lst (get-text buf)))
    (if (not (null? lst))
        (begin
          (format #t "~a  |~a| " i (car lst))
          (let ((bmarks (bookmark-get-all-in-line (get-bookmarks buf) (1- i))))
            (when (not (null? bmarks))
                (write bmarks)))
          (let ((tags (tag-get-all-in-line (get-tags buf) (1- i))))
            (when (not (null? tags))
                (write tags)))
          (newline)
          (loop (1+ i) (cdr lst)))))
  (format #t "====END TEXT====~%")
  (format #t "Position: Line ~a, Pos ~a ~%" (get-line-cur buf) (get-pd-cur buf))
  (format #t "Tabsize: Horiz ~a, Vert ~a~%" (get-tab-size buf) (get-vert-tab-size buf))
  (format #t "Home: ~a,  Limit ~a~%" (get-home-pos buf) (get-limit-pos buf))
  (format #t "Mark: Valid ~a, Line ~a, Pos ~a~%" (is-mark-set? buf)
          (get-line-mark buf) (get-pd-mark buf))
  (format #t "================~%")

  )

(define (bracket-line Buf L)
  "Return L if it is a valid line number for the current buffer, or
the nearest valid line number of L is out of range."
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (integer-nonnegative? L))
  (max 0
       (min L
            (1- (get-line-count Buf)))))

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

(define (get-line-count buf)
  "Return the number of lines in the buffer"
  (warn-if-false (cbuffer? buf))
  (length (get-text buf)))

(define (get-text-cur buf)
  "Return the text of the active line"
  (if (null? (get-text buf))
      0
      ;; else
      (list-ref (get-text buf) (get-line-cur buf))))

(define (get-text-line buf n)
  "Return the text of line N"
  (warn-if-false (cbuffer? buf))
  (warn-if-false (<= n (get-line-count buf)))
  (cond
   ((null? (get-text buf))
    "")
   ((= n (get-line-count buf))
    "")
   (else
    (list-ref (get-text buf) n))))

(define-method (get-text-cur-length (buf <CBuffer>))
  "Return the number of codepoints in the active line"
  (if (null? (get-text buf))
      0
      (string-length (get-text-cur buf))))

(define (set-line-and-pd-cur! buf LPd)
  (warn-if-false (cbuffer? buf))
  (warn-if-false (list-of-integers-length-2? LPd))

  (when (list-of-integers-length-2? LPd)
    (set-line-cur! buf (list-ref LPd 0))
    (set-pd-cur! buf (list-ref LPd 1))))

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

(define (set-line-cur! buf L)
  "Sets the active data line to L. The line number is bracketed to a
valid value.

Without changing the goal column, the active presentation position is
set to the beginning of the grapheme at the goal column, or to the end
of the line if the goal column is past the end of the line.  The
active data position is set to the data position of the grapheme
located at the active presentation position.

It returns the active data line, which may be different from the L
parameter."
  (warn-if-false (cbuffer? buf))
  (warn-if-false (integer-nonnegative? L))

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

(define (op-bookmark-set! Buf LBookmark PBookmark Name)
  "Set a bookmark with the given name at the given location."
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (integer-nonnegative? LBookmark))
  (warn-if-false (integer-nonnegative? PBookmark))
  (warn-if-false (<= LBookmark (get-line-count Buf)))
  (warn-if-false (<= PBookmark (string-length (get-text-line Buf LBookmark))))
  (warn-if-false (string? Name))

  (unless (bookmark-name-at? (get-bookmarks Buf) Name LBookmark PBookmark)
    (let ((old-bookmark-pos (bookmark-get (get-bookmarks Buf) Name)))
      (bookmark-set! (get-bookmarks Buf) Name LBookmark PBookmark)
      (if old-bookmark-pos
          (append-undo! Buf (list 'bookmark-move LBookmark PBookmark Name
                                  (first old-bookmark-pos)
                                  (second old-bookmark-pos)))
          (append-undo! Buf (list 'bookmark-set LBookmark PBookmark Name))))))

(define (undo-bookmark-move Buf LBookmark PBookmark Name LOldBookmark POldBookmark)
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (integer-nonnegative? LBookmark))
  (warn-if-false (integer-nonnegative? PBookmark))
  (warn-if-false (<= LBookmark (get-line-count Buf)))
  (warn-if-false (<= PBookmark (string-length (get-text-line Buf LBookmark))))
  (warn-if-false (integer-nonnegative? LOldBookmark))
  (warn-if-false (integer-nonnegative? POldBookmark))
  (warn-if-false (<= LOldBookmark (get-line-count Buf)))
  (warn-if-false (<= POldBookmark (string-length (get-text-line Buf LOldBookmark))))
  (warn-if-false (string? Name))

  (bookmark-set! (get-bookmarks Buf) Name LOldBookmark POldBookmark))

(define (undo-bookmark-set Buf LBookmark PBookmark Name)
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (integer-nonnegative? LBookmark))
  (warn-if-false (integer-nonnegative? PBookmark))
  (warn-if-false (<= LBookmark (get-line-count Buf)))
  (warn-if-false (<= PBookmark (string-length (get-text-line Buf LBookmark))))
  (warn-if-false (string? Name))

  (bookmark-remove! (get-bookmarks Buf) Name))

(define (op-tags-set! Buf ListOfTags)
  (warn-if-false (cbuffer? Buf))
  (let ((tags-used '()))
    (do ((i 0 (1+ i))) ((>= i (length ListOfTags)))
      (let ((tag-cur (list-ref ListOfTags i)))
        (unless (tag-name-at? (get-tags Buf)
                              (first tag-cur)
                              (second tag-cur)
                              (third tag-cur))
          (tag-set! (get-tags Buf) (first tag-cur) (second tag-cur)
                    (third tag-cur))
          (set! tags-used (append tags-used (list tag-cur))))))
    (unless (null? tags-used)
      (append-undo! Buf (list 'tags-set tags-used)))))

(define (undo-tags-set! Buf ListOfTags)
  (do ((i 0 (1+ i))) ((>= i (length ListOfTags)))
    (let ((tag-cur (list-ref ListOfTags i)))
      (tag-remove-at-by-name! (get-tags Buf)
                              (first tag-cur)
                              (second tag-cur)
                              (third tag-cur)))))

(define (op-tags-remove! Buf ListOfTags)
  "Remove all tags that match tags in the given list."
  (warn-if-false (cbuffer? Buf))
  (let ((tags-used '()))
    (do ((i 0 (1+ i))) ((>= i (length ListOfTags)))
      (let ((tag-cur (list-ref ListOfTags i)))
        (when (tag-name-at? (get-tags Buf)
                            (first tag-cur)
                            (second tag-cur)
                            (third tag-cur))
          (tag-remove-at-by-name! (get-tags Buf) (first tag-cur) (second tag-cur)
                                  (third tag-cur))
          (set! tags-used (append tags-used (list tag-cur))))))
    (unless (null? tags-used)
      (append-undo! Buf (list 'tags-remove tags-used)))))

(define (undo-tags-remove! Buf ListOfTags)
  (do ((i 0 (1+ i))) ((>= i (length ListOfTags)))
    (let ((tag-cur (list-ref ListOfTags i)))
      (tag-set! (get-tags Buf)
                (first tag-cur)
                (second tag-cur)
                (third tag-cur)))))

(define (op-insert-in-line! Buf LInsert PInsert Txt)
  (warn-if-false (integer-nonnegative? LInsert))
  (warn-if-false (integer-nonnegative? PInsert))
  (warn-if-false (<= LInsert (get-line-count Buf)))
  (warn-if-false (<= PInsert (string-length (get-text-line Buf LInsert))))
  (warn-if-false (string? Txt))
  (warn-if-false (cbuffer? Buf))

  (unless (string-null? Txt)
    (let ((strlen (string-length Txt)))
      (append-undo! Buf (list 'insert-in-line LInsert PInsert Txt
                              (get-line-cur Buf)
                              (get-pd-cur Buf)))
      ;; Insert the text into the line
      (log-debug-pk (get-text Buf))
      (set-text! Buf
                 (strlist-insert-in-line (get-text Buf) LInsert PInsert Txt))
      (log-debug-pk (get-text Buf))
      ;; Move the active data position
      (set-line-and-pd-cur! Buf
                            (pos-insert-in-line (get-line-cur Buf)
                                                (get-pd-cur Buf)
                                                LInsert PInsert strlen))
      ;; Clear the mark
      (set-mark-flag! Buf #f)

      ;; Adjust the bookmarks and tags
      (adjust-poslist-insert-in-line! (get-tags Buf) LInsert PInsert strlen)
      (adjust-poslist-insert-in-line! (get-bookmarks Buf)
                                      LInsert PInsert strlen))))

(define (undo-insert-in-line! Buf LInsert PInsert Str LCur PdCur)
  "Undo insert in line. Note that this doesn't alter the undo stack."
  (let ((PEnd (+ PInsert (string-length Str))))
    (set-text! Buf
               (strlist-delete-in-line (get-text Buf) LInsert PInsert PEnd))
    ;; Clear the mark
    (set-mark-flag! Buf #f)
    ;; Move the active data position
    (set-line-cur! Buf LCur)
    (set-pd-cur! Buf PdCur)
    ;; Adjust bookmarks and tags
    (adjust-poslist-delete-in-line! (get-tags Buf) LInsert PInsert PEnd)
    (adjust-poslist-delete-in-line! (get-bookmarks Buf) LInsert PInsert PEnd)))

(define (op-replace-in-line! Buf LReplace PReplaceStart PReplaceEnd Txt)
  (let ((LenReplace (string-length Txt))
        (replacedtxt (substring (list-ref (get-text Buf) LReplace) PReplaceStart PReplaceEnd))
        (lost-bmarks (bookmark-get-all-in-line-segment (get-bookmarks Buf)
                                                       LReplace PReplaceStart PReplaceEnd))
        (lost-tags (tag-get-all-in-line-segment (get-tags Buf)
                                                LReplace PReplaceStart PReplaceEnd)))

    ;; Add undo info.
    (append-undo! Buf (list 'replace-in-line LReplace PReplaceStart PReplaceEnd Txt replacedtxt lost-bmarks lost-tags
                            (get-line-cur Buf) (get-pd-cur Buf)))

    ;; Overwrite the text in the line, and adjust bookmarks and tags
    (adjust-poslist-replace-in-line! (get-tags Buf) LReplace PReplaceStart PReplaceEnd LenReplace)
    (adjust-poslist-replace-in-line! (get-bookmarks Buf) LReplace PReplaceStart PReplaceEnd LenReplace)

    ;; Change the string list
    (set-text! Buf (strlist-replace-in-line (get-text Buf)
                                            LReplace PReplaceStart PReplaceEnd Txt))
    
    
    ;; Move the activive data position
    (let ((newpos (pos-replace-in-line (get-line-cur Buf) (get-pd-cur Buf)
                                       LReplace PReplaceStart PReplaceEnd LenReplace)))
      (if (null? newpos)
          (set-line-and-pd-cur! Buf (list LReplace PReplaceStaret))
          (set-line-and-pd-cur! Buf newpos)))
    
    ;; Clear the mark
    (set-mark-flag! Buf #f)))

(define (undo-replace-in-line! Buf LReplace PReplaceStart PReplaceEnd
                               newtxt oldtxt LostBmarks LostTags LCur PdCur)
  "Undo replace in line."
  (let ((buftxt (get-text Buf))
        (premovedlen (- PReplaceEnd PReplaceStart)))
    (set-text! Buf
               (strlist-replace-in-line buftxt
                                       LReplace
                                       PReplaceStart
                                       (+ PReplaceStart (string-length newtxt))
                                       oldtxt))
    ;; Clear the mark
    (set-mark-flag! Buf #f)
    ;; Move the active data position
    (set-line-cur! Buf LCur)
    (set-pd-cur! Buf PdCur)
    ;; Adjust bookmarks and tags
    (adjust-poslist-replace-in-line! (get-tags Buf) LReplace PReplaceStart PReplaceEnd premovedlen)
    (adjust-poslist-replace-in-line! (get-bookmarks Buf) LReplace PReplaceStart PReplaceEnd premovedlen)
    (for-each (lambda (bmark)
                (bookmark-set! (get-bookmarks Buf)
                               (bookmark:name bmark)
                               (bookmark:line bmark)
                               (bookmark:pd bmark)))
              LostBmarks)
    (for-each (lambda (tag)
                (tag-set! (get-tags Buf)
                               (first tag)
                               (second tag)
                               (third tag)))
              LostTags)))

(define (op-move-in-line! Buf LMove PMoveStart PMoveEnd PMoveTo)
  (let ((LenMove (- PMoveEnd PMoveStart)))
    ;; Overwrite the text in the line, and adjust bookmarks and tags
    (set-text! Buf
               (strlist-move-in-line (get-text Buf) LMove PMoveStart PMoveEnd PMoveTo))
    (adjust-poslist-move-in-line (get-tags Buf) LMove PMoveStart PMoveEnd PMoveTo)
    (adjust-poslist-move-in-line (get-bookmarks Buf) LMove PMoveStart PMoveEnd PMoveTo)

    (append-undo! Buf (list 'move-in-line LMove PMoveStart PMoveEnd PMoveTo
                            (get-line-cur Buf) (get-pd-cur Buf)))

    ;; Move the activive data position
    (set-line-and-pd-cur! Buf (pos-move-in-line (get-line-cur Buf) (get-pd-cur Buf)
                                                LMove PMoveStart PMoveEnd PMoveTo))
    ;; Clear the mark
    (set-mark-flag! Buf #f)))

(define (undo-move-in-line! Buf LMove PMoveStart PMoveEnd PMoveTo LCur PdCur)
  "Undo a move-in-line operation."
  (let ((copylen (- PMoveEnd PMoveStart)))
    (set-text! Buf
               (strlist-move-in-line (get-text Buf) LMove PMoveTo (+ PMoveTo copylen) PMoveStart))
    ;; Clear the mark
    (set-mark-flag! Buf #f)
    ;; Move the active data position
    (set-line-cur! Buf LCur)
    (set-pd-cur! Buf PdCur)
    ;; Adjust bookmarks and tags
    (adjust-poslist-move-in-line (get-tags Buf) LMove PMoveTo (+ PMoveTo copylen) PMoveStart)
    (adjust-poslist-move-in-line (get-bookmarks Buf) LMove PMoveTo (+ PMoveTo copylen) PMoveStart)))

(define (op-copy-in-line! Buf LCopy PCopyStart PCopyEnd PCopyTo)
  "Copy and insert the segment of the current line LCopy between PCopy
Start (inclusive) and PCopyEnd (exclusive) at the location PCopyTo."
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (integer-nonnegative? LCopy))
  (warn-if-false (integer-nonnegative? PCopyStart))
  (warn-if-false (integer-nonnegative? PCopyEnd))
  (warn-if-false (integer-nonnegative? PCopyTo))
  (warn-if-false (< PCopyStart PCopyEnd))

  (let ((LenCopy (- PCopyEnd PCopyStart)))

    ;; Overwrite the text in the line, and adjust bookmarks and tags
    (set-text! Buf
               (strlist-copy-in-line (get-text Buf) LCopy PCopyStart PCopyEnd PCopyTo))
      
    ;; Note that tags are duplicated under a copy operaton, but,
    ;; bookmarks are not duplicated and stay with the original.
    (poslist-copy-in-line (get-tags Buf) LCopy PCopyStart PCopyEnd PCopyAfter)
    (adjust-poslist-copy-in-line (get-bookmarks Buf) LCopy PCopyStart PCopyEnd PCopyAfter #f)

    ;; Clear the mark
    (set-mark-flag! Buf #f)

    (append-undo! Buf (list 'copy-in-line LCopy PCopyStart PCopyEnd PCopyTo
                            (get-line-cur Buf)
                            (get-pd-cur Buf)))

    ;; Move the active data position
    (set-line-and-pd-cur! Buf (pos-copy-in-line (get-line-cur Buf) (get-pd-cur Buf)
                                                LCopy PCopyStart PCopyEnd LenCopy #f))))

(define (undo-copy-in-line! Buf LCopy PCopyStart PCopyEnd PCopyTo LCur PdCur)
  "Undo a copy-lines operation."
  (set-text! Buf
             (strlist-delete-in-line (get-text Buf) LCopy PCopyStart PCopyEnd))
  ;; Clear the mark
  (set-mark-flag! Buf #f)
  ;; Move the active data position
  (set-line-cur! Buf LCur)
  (set-pd-cur! Buf PdCur)
  ;; Adjust bookmarks and tags
  (adjust-poslist-delete-in-line! (get-tags Buf) LCopy PCopyStart PCopyEnd)
  (adjust-poslist-delete-in-line! (get-bookmarks Buf) LCopy PCopyStart PCopyEnd))

(define (op-delete-in-line! Buf LDelete PDeleteStart PDeleteEnd)
  "Remove a segment of line LDelete between PDeleteStart (inclusive)
and PDeleteEnd (exclusive)."
  (warn-if-false (integer-nonnegative? LDelete))
  (warn-if-false (integer-nonnegative? PDeleteStart))
  (warn-if-false (integer-nonnegative? PDeleteEnd))
  (warn-if-false (< PDeleteStart PDeleteEnd))
  (warn-if-false (cbuffer? Buf))

  (let ((lost-bmarks (bookmark-get-all-in-line-segment (get-bookmarks Buf)
                                                       LDelete PDeleteStart PDeleteEnd))
        (lost-tags (tag-get-all-in-line-segment (get-tags Buf)
                                                LDelete PDeleteStart PDeleteEnd))
        (deletetxt (substring (list-ref (get-text Buf) LDelete) PDeleteStart PDeleteEnd)))
    ;; Add this operation to the list of mutator operations.
    (append-undo! Buf (list 'delete-in-line LDelete PDeleteStart PDeleteEnd
                            deletetxt lost-bmarks lost-tags (get-line-cur Buf) (get-pd-cur Buf)))

    ;; Change the string list.
    (set-text! Buf
               (strlist-delete-in-line (get-text Buf) LDelete PDeleteStart PDeleteEnd))

    ;; Clear the mark
    (set-mark-flag! Buf #f)

    ;; Move the active data position.  If the position was deleted, move
    ;; it to the end of the delete region.
    (let ((newpos (pos-delete-in-line (get-line-cur Buf)
                                      (get-pd-cur Buf)
                                      LDelete PDeleteStart PDeleteEnd)))
      (if (null? newpos)
          (set-line-and-pd-cur! Buf (list (LDelete PDeleteStart)))
          (set-line-and-pd-cur! Buf newpos)))

    ;; Adjust bookmarks and tags.
    (adjust-poslist-delete-in-line (get-bookmarks Buf)
                                   LDelete PDeleteStart PDeleteEnd)
    (adjust-poslist-delete-in-line (get-tags Buf)
                                   LDelete PDeleteStart PDeleteEnd)))

(define (undo-delete-in-line! Buf LDelete PDeleteStart PDeleteEnd
                           deletetxt LostBmarks LostTags LCur PdCur)
  "Undo delete lines."
  (let ((buftxt (get-text Buf))
        (premovedlen (- PDeleteEnd PDeleteStart)))
    (set-text! Buf
               (strlist-insert-in-line buftxt
                                       LDelete
                                       PDeleteStart
                                       deletetxt))
    ;; Clear the mark
    (set-mark-flag! Buf #f)
    ;; Move the active data position
    (set-line-cur! Buf LCur)
    (set-pd-cur! Buf PdCur)
    ;; Adjust bookmarks and tags
    (adjust-poslist-insert-in-line! (get-tags Buf) LDelete PDeleteStart premovedlen)
    (adjust-poslist-insert-in-line! (get-bookmarks Buf) LDelete PDeleteStart premovedlen)
    (for-each (lambda (bmark)
                (bookmark-set! (get-bookmarks Buf)
                               (bookmark:name bmark)
                               (bookmark:line bmark)
                               (bookmark:pd bmark)))
              LostBmarks)
    (for-each (lambda (tag)
                (tag-set! (get-tags Buf)
                               (first tag)
                               (second tag)
                               (third tag)))
              LostTags)))

(define (op-insert-lines! Buf LInsert StrList)
  "Append the StrList at the addressed line LInsert.  If LInsert is
the line after the last line in the buffer, StrList is appended to the
end of the text.  The previous contents of LInsert and following lines
will be pushed down. "
  (warn-if-false (integer-nonnegative? LInsert))
  (warn-if-false (<= LInsert (get-line-count Buf)))
  (warn-if-false (list-of-strings-length-0+? StrList))

  (unless (null? StrList)
    (let ((strlistlen (length StrList)))
      ;; Add the op to the list of mutator operations
      (append-undo! Buf (list 'insert-lines LInsert StrList
                              (get-line-cur Buf)
                              (get-pd-cur Buf)))
      ;; Insert the line into the string list
      (set-text! Buf
                (strlist-insert-lines (get-text Buf) LInsert StrList))
      ;; Clear the mark.
      (set-mark-flag! Buf #f)

      (set-line-and-pd-cur! Buf (pos-insert-lines (get-line-cur Buf)
                                                  (get-pd-cur Buf)
                                                  LInsert strlistlen))

      ;; Adjust bookmarks and tags
      (adjust-poslist-insert-lines! (get-tags Buf) LInsert strlistlen)
      (adjust-poslist-insert-lines! (get-bookmarks Buf) LInsert strlistlen)
      )))

(define (undo-insert-lines! Buf LInsert StrList LCur PdCur)
  "Undo insert lines. Note that this doesn't alter the undo stack."
  (let ((buftxt (get-text Buf))
        (lcount (length StrList)))
    (set-text! Buf (append (take buftxt LInsert)
                           (drop buftxt (+ LInsert lcount))))
    ;; Clear the mark
    (set-mark-flag! Buf #f)
    ;; Move the active data position
    (set-line-cur! Buf LCur)
    (set-pd-cur! Buf PdCur)
    ;; Adjust bookmarks and tags
    (adjust-poslist-delete-lines (get-tags Buf) LInsert lcount)
    (adjust-poslist-delete-lines (get-bookmarks Buf) LInsert lcount)))

(define (op-merge-lines! Buf LStart LEnd)
  "Combine the lines LStart (inclusive) to LEnd (exclusive) into a single
line."
  (warn-if-false (< LStart LEnd))
  (warn-if-false (>= LStart 0))
  (warn-if-false (<= LEnd (get-line-count Buf)))
  (warn-if-false (cbuffer? Buf))

  (when (> (- LEnd LStart) 1)

    ;; Overwrite the text in the line, and adjust bookmarks and tags
    (let* ((merge-length-list
            (map string-length (sublist (get-text Buf) LStart LEnd)))
           (cum-length-list
            (cumulative-sum merge-length-list))
           (moved-bmarks (bookmark-get-all-in-lines (get-bookmarks Buf) LStart LEnd))
           (moved-tags (tag-get-all-in-lines (get-tags Buf) LStart LEnd)))
      (log-debug-pk moved-bmarks)
      (append-undo! Buf (list 'merge-lines LStart LEnd cum-length-list
                              moved-bmarks
                              moved-tags
                              (get-line-cur Buf)
                              (get-pd-cur Buf)))

      (set-text! Buf
                 (strlist-merge-lines (get-text Buf) LStart LEnd))

      ;; Clear the mark
      (set-mark-flag! Buf #f)

      ;; Move the activive data position
      (set-line-and-pd-cur! Buf (pos-merge-lines (get-line-cur Buf) (get-pd-cur Buf)
                                                 LStart LEnd merge-length-list))

      (adjust-poslist-merge-lines (get-tags Buf) LStart LEnd merge-length-list)
      (adjust-poslist-merge-lines (get-bookmarks Buf) LStart LEnd
                                  merge-length-list))))

(define (undo-merge-lines! Buf LStart LEnd PSplitList
                           MovedBmarks
                           MovedTags
                           LCur PdCur)
  "Undo merge lines. Note that this doesn't alter the undo stack."
  (warn-if-false (cbuffer? Buf))
  (log-debug-pk MovedBmarks)

  (set-text! Buf
             (strlist-split-lines (get-text Buf) LStart PSplitList))

  ;; Clear the mark
  (set-mark-flag! Buf #f)
  ;; Move the active data position
  (set-line-cur! Buf LCur)
  (set-pd-cur! Buf PdCur)
  ;; Adjust bookmarks and tags
  (bookmark-remove-all-in-line! (get-bookmarks Buf) LStart)
  (for-each
   (lambda (bmark)
     (log-debug-locals)
     (log-debug-pk (get-bookmarks Buf))
     (bookmark-set! (get-bookmarks Buf)
                    (first bmark) (second bmark) (third bmark)))
   MovedBmarks)
  (tag-remove-all-in-line! (get-tags Buf) LStart)
  (for-each
   (lambda (tag)
     (tag-set! (get-tags Buf)
               (first tag) (second tag) (third tag)))
   MovedTags))

(define (op-replace-lines! Buf LStart LEnd StrList)
  "Replace the lines from LStart (inclusive) and LEnd (exclusive)
with strlist"
  (warn-if-false (integer-nonnegative? LStart))
  (warn-if-false (integer-nonnegative? LEnd))
  (warn-if-false (< LStart LEnd))
  (warn-if-false (<= LEnd (get-line-count Buf)))
  (warn-if-false (list-of-strings-length-0+? StrList))  
  (let ((strlistlen (length StrList))
        (orig-len (get-line-count Buf)))
    ;; And undo info.
    (append-undo! Buf (list 'replace-lines
                            LStart LEnd
                            (sublist (get-text Buf) LStart LEnd)
                            StrList
                            (get-line-cur Buf)
                            (get-pd-cur Buf)))
    ;; Change the string list.
    (let ((buftxt (get-text Buf)))
      (set-text! Buf (append (take buftxt LStart)
                             StrList
                             (drop buftxt LEnd))))
    ;; Clear the mark.
    (set-mark-flag! Buf #f)
    ;; Move the active data position.
    (let ((newpos (pos-replace-lines (get-line-cur Buf)
                                     (get-pd-cur Buf)
                                     LStart
                                     LEnd
                                     strlistlen)))
        ;; If newpos is '(), the location of the active data position
        ;; was overwritten in this operation.  So, put it after the paste,
        ;; I guess.
        (if (null? newpos)
            (set-line-and-pd-cur! Buf (list LEnd 0))
            (set-line-and-pd-cur! Buf newpos)))))

(define-method (undo-replace-lines (Buf <CBuffer>) LStart LEnd RemovedStrList
                                   NewStrList
                                   LCur PdCur)
  "Undo replace lines. Note that this doesn't alter the undo stack."
  (let ((buftxt (get-text Buf))
        (lcountnew (length NewStrList))
        (lcountremoved (length RemovedStrList)))
    ;; Remove the new text and reinsert the old text.
    (set-text! Buf (append (take buftxt LStart)
                           RemovedStrList
                           (drop buftxt (+ LStart lcountnew))))
    ;; Clear the mark.
    (set-mark-flag! Buf #f)
    ;; Restore the active data position.
    (set-line-cur! Buf LCur)
    (set-pd-cur! Buf PdCur)
    ;; Adjust bookmarks and tags.
    (adjust-poslist-replace-lines (get-tags Buf)
                                  LStart (+ LStart lcountnew)
                                  lcountremoved)
    (adjust-poslist-replace-lines (get-bookmarks Buf)
                                  LStart (+ LStart lcountnew)
                                  lcountremoved)))

(define (op-delete-lines! Buf LStart LEnd)
  "Remove the lines of text from LStart (inclusive) to LEnd (exclusive)."
  (warn-if-false (integer-nonnegative? LStart))
  (warn-if-false (integer-nonnegative? LEnd))
  (warn-if-false (< LStart LEnd))
  (warn-if-false (<= LEnd (get-line-count Buf)))
  (warn-if-false (cbuffer? Buf))

  (let ((lost-bmarks (bookmark-get-all-in-lines (get-bookmarks Buf) LStart LEnd))
        (lost-tags (tag-get-all-in-lines (get-tags Buf) LStart LEnd)))
    ;; Add this operation to the list of mutator operations.
    (append-undo! Buf (list 'delete-lines
                            LStart LEnd
                            (sublist (get-text Buf) LStart LEnd)
                            lost-bmarks
                            lost-tags
                            (get-line-cur Buf)
                            (get-pd-cur Buf)))
    ;; Change the string list
    (let ((buftxt (get-text Buf)))
      (set-text! Buf (strlist-delete-lines buftxt LStart LEnd))

      ;; Clear the mark
      (set-mark-flag! Buf #f)
      ;; Move the active data position
      (let ((newpos (pos-delete-lines (get-line-cur Buf)
                                      (get-pd-cur Buf)
                                      LStart LEnd)))
        ;; If the position was deleted, move the cursor to the end
        ;; of the deleted region.
        (if (null? newpos)
            (set-line-and-pd-cur! Buf (list LStart 0))
            (set-line-and-pd-cur! Buf newpos)))

      ;; Adjust bookmarks and tags.
      (adjust-poslist-delete-lines (get-tags Buf) LStart LEnd)
      (adjust-poslist-delete-lines (get-bookmarks Buf) LStart LEnd))))

(define (undo-delete-lines Buf LStart LEnd RemovedStrList LostBmarks LostTags
                           LCur PdCur)
  "Undo delete lines."
  (let ((buftxt (get-text Buf))
        (lremovedcount (length RemovedStrList)))
    (set-text! Buf
               (strlist-insert-lines buftxt
                                     LStart
                                     RemovedStrList))
    ;; Clear the mark
    (set-mark-flag! Buf #f)
    ;; Move the active data position
    (set-line-cur! Buf LCur)
    (set-pd-cur! Buf PdCur)
    ;; Adjust bookmarks and tags
    (adjust-poslist-insert-lines! (get-tags Buf) LStart lremovedcount)
    (adjust-poslist-insert-lines! (get-bookmarks Buf) LStart lremovedcount)
    (for-each (lambda (bmark)
                (bookmark-set! (get-bookmarks Buf)
                               (bookmark:name bmark)
                               (bookmark:line bmark)
                               (bookmark:pd bmark)))
              LostBmarks)
    (for-each (lambda (tag)
                (tag-set! (get-tags Buf)
                               (first tag)
                               (second tag)
                               (third tag)))
              LostTags)))

(define (op-move-lines! Buf LMoveStart LMoveEnd LMoveTo)
  "Move the lines from LStart (inclusive) and LEnd (exclusive) to the
line LMoveTo."
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (< LMoveStart LMoveEnd))
  (warn-if-false (or (< LMoveTo LMoveStart) (<= LMoveEnd LMoveTo)))
  (warn-if-false (<= LMoveEnd (get-line-count Buf)))

  (when (>= (- LMoveEnd LMoveStart) 1)
    
    ;; Overwrite the text in the line, and adjust bookmarks and tags
    (set-text! Buf
               (strlist-move-lines (get-text Buf) LMoveStart LMoveEnd LMoveTo))
    (adjust-poslist-move-lines (get-tags Buf) LMoveStart LMoveEnd LMoveTo)
    (adjust-poslist-move-lines (get-bookmarks Buf) LMoveStart LMoveEnd LMoveTo)

    (append-undo! Buf (list 'op-move-lines LMoveStart LMoveEnd LMoveTo
                            (get-line-cur Buf) (get-pd-cur Buf)))

    ;; Move the activive data position
    (set-line-and-pd-cur! Buf (pos-move-lines (get-line-cur Buf)
                                              (get-pd-cur Buf)
                                              LMoveStart LMoveEnd LMoveTo))

    ;; Clear the mark
    (set-mark-flag! Buf #f)))

(define (undo-move-lines! Buf LMoveStart LMoveEnd LMoveTo LCur PdCur)
  "Undo a copy-lines operation."
  (let ((copylen (- LMoveEnd LMoveStart)))
    (set-text! Buf
               (strlist-move-lines (get-text Buf) LMoveTo (+ LMoveTo copylen) LMoveStart))
    ;; Clear the mark
    (set-mark-flag! Buf #f)
    ;; Move the active data position
    (set-line-cur! Buf LCur)
    (set-pd-cur! Buf PdCur)
    ;; Adjust bookmarks and tags
    (adjust-poslist-move-lines (get-tags Buf) LMoveTo (+ LMoveTo copylen) LMoveStart)
    (adjust-poslist-move-lines (get-bookmarks Buf) LMoveTo (+ LMoveTo copylen) LMoveStart)))

(define (op-copy-lines! Buf LCopyStart LCopyEnd LCopyTo)
  "Copy and insert the lines from LCopyStart (inclusive) and
LCopyEnd (exclusive) to the line LCopyTo."
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (integer-nonnegative? LCopyStart))
  (warn-if-false (integer-nonnegative? LCopyEnd))
  (warn-if-false (integer-nonnegative? LCopyTo))
  (warn-if-false (< LCopyStart LCopyEnd))

  ;; Overwrite the text in the line, and adjust bookmarks and tags
  (set-text! Buf
             (strlist-copy-lines (get-text Buf) LCopyStart LCopyEnd LCopyTo))
  (adjust-poslist-copy-lines (get-tags Buf) LCopyStart LCopyEnd LCopyTo #f)
  (adjust-poslist-copy-lines (get-bookmarks Buf) LCopyStart LCopyEnd LCopyTo #f)

  ;; Clear the mark
  (set-mark-flag! Buf #f)

  (append-undo! Buf (list 'copy-lines LCopyStart LCopyEnd LCopyTo
                          (get-line-cur Buf)
                          (get-pd-cur Buf)))

  ;; Move the activive data position
  (set-line-and-pd-cur! Buf (pos-copy-lines (get-line-cur Buf) (get-pd-cur Buf)
                                            LCopyStart LCopyEnd LCopyTo #t))

  )

(define (undo-copy-lines Buf LCopyStart LCopyEnd LCopyTo LCur PdCur)
  "Undo a copy-lines operation."
  (let ((copylen (- LCopyEnd LCopyStart)))
    (set-text! Buf
               (strlist-delete-lines (get-text Buf) LCopyTo (+ LCopyTo copylen)))
    ;; Clear the mark
    (set-mark-flag! Buf #f)
    ;; Move the active data position
    (set-line-cur! Buf LCur)
    (set-pd-cur! Buf PdCur)
    ;; Adjust bookmarks and tags
    (adjust-poslist-delete-lines (get-tags Buf) LCopyStart
                                 (+ LCopyTo (1- copylen)))
    (adjust-poslist-delete-lines (get-bookmarks Buf) LCopyStart
                                 (+ LCopyTo (1- copylen)))))

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
  (strlist-split-lines (get-text buf) LSplit (list PSplit))
  (adjust-poslist-split-lines (get-tags buf) LSplit PSplit)
  (adjust-poslist-split-lines (get-bookmarks buf) LSplit PSplit)

  (append-undo! buf (list 'op-split-lines LSplit PSplit))

  ;; Move the activive data position
  (set-line-and-pd-cur! buf (pos-split-lines (get-line-cur buf) (get-pd-cur buf)
                                             LSplit PSplit))

  ;; Clear the mark
  (set-mark-flag! buf #f))

;(define-method (undo (Buf <CBuffer>))
(define (undo Buf)
  ;; Pop the last operation off the list of mutator operations
  ;; Dispatch the operation to its handler.
  (warn-if-false (cbuffer? Buf))

  (if (null? (get-undo Buf))
      #f
      ;; else
      (let ((last-op (last (get-undo Buf))))
        (set-undo! Buf (drop-right (get-undo Buf) 1))
        (cond
         ((eqv? (car last-op) 'replace-in-line)
          (undo-replace-in-line! Buf
                              (second last-op) ;LReplace
                              (third last-op) ;PReplaceStart
                              (fourth last-op) ;PReplaceEnd
                              (fifth last-op) ;NewTxt
                              (sixth last-op) ;replacedtxt
                              (seventh last-op) ;replaced tags
                              (eighth last-op) ;replace bmarks
                              (ninth last-op) ;LCur
                              (tenth last-op)) ;PdCur
          #t)
         ((eqv? (car last-op) 'move-in-line)
          (undo-move-in-line! Buf
                              (second last-op) ;LMove
                              (third last-op) ;PMoveStart
                              (fourth last-op) ;PMoveEnd
                              (fifth last-op) ;PMoveTo
                              (sixth last-op) ;LCur
                              (seventh last-op)) ;PdCur
          #t)
         ((eqv? (car last-op) 'copy-in-line)
          (undo-copy-in-line! Buf
                              (second last-op) ;LCopy
                              (third last-op) ;PCopyStart
                              (fourth last-op) ;PCopyEnd
                              (fifth last-op) ;PCopyTo
                              (sixth last-op) ;LCur
                              (seventh last-op)) ;PdCur
          #t)
         ((eqv? (car last-op) 'delete-in-line)
          (undo-delete-in-line! Buf
                                (second last-op) ;LDelete
                                (third last-op) ;PDeleteStart
                                (fourth last-op) ;PDeleteEnd
                                (fifth last-op) ;deletetxt
                                (sixth last-op) ;lost-bmarks
                                (seventh last-op) ; lost-tags
                                (eighth last-op) ;LCur
                                (ninth last-op)) ;PdCur
          #t)
         ((eqv? (car last-op) 'replace-in-line)
          (undo-delete-in-line! Buf
                                (second last-op) ;LReplace
                                (third last-op) ;PReplaceStart
                                (fourth last-op) ;PReplaceEnd
                                (fifth last-op) ;deletetxt
                                (sixth last-op) ;lost-bmarks
                                (seventh last-op) ; lost-tags
                                (eighth last-op) ;LCur
                                (ninth last-op)) ;PdCur
          #t)
         ((eqv? (car last-op) 'insert-in-line)
          (undo-insert-in-line! Buf
                                (second last-op) ;LInsert
                                (third last-op)  ;PInsert
                                (fourth last-op) ;Str
                                (fifth last-op)  ;LCur
                                (sixth last-op))  ;PdCur
          #t)
         ((eqv? (car last-op) 'insert-lines)
          (undo-insert-lines! Buf
                             (second last-op)
                             (third last-op)
                             (fourth last-op)
                             (fifth last-op))

          #t)
         ((eqv? (car last-op) 'replace-lines)
          (undo-replace-lines Buf
                              (second last-op) ;LStart
                              (third last-op)  ;LEnd
                              (fourth last-op) ;RemoveStrList
                              (fifth last-op)  ;NewStrList
                              (sixth last-op)  ;LCur
                              (seventh last-op)) ;PdCur
          #t)
         ((eqv? (car last-op) 'delete-lines)
          (undo-delete-lines Buf
                             (second last-op) ;LStart
                             (third last-op)  ;LEnd
                             (fourth last-op) ;RemovedStrList
                             (fifth last-op)  ;LostBmarks
                             (sixth last-op) ;LostTags
                             (seventh last-op) ;LCur
                             (eighth last-op)) ;PdCur
          #t)
         ((eqv? (car last-op) 'merge-lines)
          (undo-merge-lines! Buf
                             (second last-op) ;LStart
                             (third last-op)  ;LEnd
                             (fourth last-op) ;PSplitList
                             (fifth last-op)  ;LostBmarks
                             (sixth last-op)  ;LostTags
                             (seventh last-op) ;LCur
                             (eighth last-op)) ;PdCur
          #t)
         ((eqv? (car last-op) 'copy-lines)
          (undo-copy-lines Buf
                           (second last-op) ;LCopyStart
                           (third last-op)  ;LCopyEnd
                           (fourth last-op) ;LCopyTo
                           (fifth last-op)  ;LCur
                           (sixth last-op)) ;PdCur
          #t)
         ((eqv? (car last-op) 'move-lines)
          (undo-move-lines! Buf
                           (second last-op) ;LMoveStart
                           (third last-op)  ;LMoveEnd
                           (fourth last-op) ;LMoveTo
                           (fifth last-op)  ;LCur
                           (sixth last-op)) ;PdCur
          #t)
         ((eqv? (car last-op) 'bookmark-set)
          (undo-bookmark-set Buf
                             (second last-op) ;LBookmark
                             (third last-op) ;PBookmark
                             (fourth last-op)) ;Name
          #t)
         ((eqv? (car last-op) 'bookmark-move)
          (undo-bookmark-move Buf
                             (second last-op) ;LBookmark
                             (third last-op) ;PBookmark
                             (fourth last-op) ;Name
                             (fifth last-op) ;LOldBookmark
                             (sixth last-op)) ;POldBookmark
          #t)
         ((eqv? (car last-op) 'tags-set)
          (undo-tags-set! Buf
                          (second last-op)) ;ListOfTags
          #t)
         ((eqv? (car last-op) 'tags-remove)
          (undo-tags-remove! Buf
                          (second last-op)) ;ListOfTags
          #t)
         (else
          (warn-if-reached)
          #f)))))

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

(define (carriage-return! buf)
  "If the implicit movement direction is 'forward, move the active
data position to the line home position of the current line.  If the
implicit movement direction is 'backward, move the active data
position to the line-limit position of the current line."

  ;; If there is no text, I guess a carriage return should create a
  ;; line, right?
  (when (null? (get-text buf))
    (set-text! buf '("")))
  
  (let ((pos (if (eqv? 'forward (get-implicit-movement-direction buf))
                       (get-home-pos buf)
                       (get-limit-pos buf)))
        (len (get-text-cur-length buf)))
    (if (< len pos)
        (op-insert-in-line! buf (get-line-cur buf) pos (make-string (- pos len) #\space)))
  (set-pd-cur! buf pos)))

(define (insert-character-in-line! Buf LInsert PInsert C)
  "Insert C into the addressed line LInsert at position PInsert.
If LInsert is the line after the last line in the buffer, C is
appended as a new line to the end of the text.  If PInsert is after
the end of the line, Str is appended to the end of the line.  The
active data position will be set to the end of the inserted text."
  (warn-if-false (integer-nonnegative? LInsert))
  (warn-if-false (integer-nonnegative? PInsert))
  (warn-if-false (<= LInsert (get-line-count Buf)))
  (warn-if-false (<= PInsert (string-length (get-text-line Buf LInsert))))
  (warn-if-false (char? C))
  (warn-if-false (cbuffer? Buf))

  (op-insert-in-line! Buf LInsert PInsert (string C))
  ;; Move the active data position
  (set-line-cur! Buf LInsert)
  (if (eqv? (get-implicit-movement-direction Buf) 'forward)
      (set-pd-cur! Buf (1+ PInsert))
      (set-pd-cur! Buf PInsert)))

;; LF - LINE FEED

;; Move the active data position to the corresponding character
;; position of the following line.

(define (line-feed! Buf)
  "Move the active data position to the corresponding character
position of the following line."
  (warn-if-false (cbuffer? Buf))
  (let ((LCur (get-line-cur Buf))
        (LCount (get-line-count Buf))
        (PdCur (get-pd-cur Buf)))
    ;; If the following line doesn't exist, we'll append a line with
    ;; PdCur spaces to the end of the buffer.

    ;; Or if the following line is too short, we'll append the
    ;; appropriate number of spaces to the following line

    ;; Then move down.

    (when (= LCur (1- LCount))
      (op-insert-lines! Buf (get-line-count Buf)
                        (list (make-string PdCur #\space))))

    (let* ((txt (get-text-line Buf (1+ LCur)))
           (txtLen (string-length txt)))
      (when (< txtLen PdCur)
        (op-insert-in-line! Buf (1+ LCur) txtLen (make-string (- PdCur txtLen) #\space))))

    (increase-line-cur! Buf 1)))

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
        (len (get-text-cur-length buf)))

    ;; Normally,
    ;; if blocked, do nothing

    ;; If 'insertion, insert a character at location.
    (when (eqv? IRM 'insert)
      (op-insert-in-line! buf LCur PdCur (string c))
      ;; If HEM is following, move the cursor in the implicit movement
      ;; direction.  If HEM is 'preceding, do no move the cursor.
      (when (eqv? HEM 'following)
        (increase-pd-cur! buf (if (eqv? SIMD 'forward) 1 -1))))

    ;; If 'deletion, overwrite text at location.
    (when (eqv? IRM 'replace)
      (if (= PdCur len)
          (op-insert-in-line! buf LCur PdCur (string c))
          (op-replace-in-line! buf LCur PdCur (1+ PdCur) (string c)))
      ;; Move cursor in the implicit movement direction.  (HEM has no
      ;; effect.)
      (increase-pd-cur! buf (if (eqv? SIMD 'forward) 1 -1)))

    ;; If the cursor is at a line extremum, maybe block or wrap.
    (when (= (get-limit-pos buf) (get-pd-cur buf))
      (when (member 'auto_right_margin IMM)
        (carriage-return buf)
        (line-feed! buf)))))

(define-method (add-tag (buf <CBuffer>) id)
  (tag-set! (get-tags buf) id (get-line-cur buf) (get-pd-cur buf)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;  OPERATIONS INSPIRED BY ED

(define (bookmark-bol! Buf L Name)
  "Set a bookmark at the beginning of line L using Name."

  ;; Unusually, the Ed Mark command doesn't change the current line.
  (warn-if-false (integer-nonnegative? L))
  (warn-if-false (string? Name))
  (warn-if-false (>= L 0))
  (warn-if-false (< L (get-line-count Buf)))
  (warn-if-false (cbuffer? Buf))

  (op-bookmark-set! Buf
                    L
                    (if (eqv? (get-implicit-movement-direction Buf) 'forward)
                        0
                        (get-text-cur-length Buf))
                    Name))

(define (copy-lines! Buf LCopyStart LCopyEnd LCopyTo)
  "Make a copy of the lines between LCopyStart (inclusive) and
LCopyEnd (exclusive) and position that copy at the line LCopyTo.

The active data line will be set to the new location of the last line
copied."
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (integer-nonnegative? LCopyStart))
  (warn-if-false (integer-nonnegative? LCopyEnd))
  (warn-if-false (integer-nonnegative? LCopyTo))
  (warn-if-false (< LCopyStart LCopyEnd))

  (if (> LCopyEnd LCopyStart)
      (begin
        (op-copy-lines! Buf LCopyStart LCopyEnd LCopyTo)
        ;; Move the activive data position
        (set-line-and-pd-cur! Buf (pos-copy-lines (get-line-cur Buf)
                                                  (get-pd-cur Buf)
                                                  LCopyStart LCopyEnd LCopyTo #t))

        (set-pd-cur-to-simd-eol! Buf))))

(define (delete-lines! Buf LStart LEnd)
  "Remove the lines of text from LStart (inclusive) to LEnd (exclusive).

The active data line is set to the beginning of the line after the
last deleted line.  If the deleted region included the end of the
buffer, the active data position is set to the end of the last line."
  (warn-if-false (integer-nonnegative? LStart))
  (warn-if-false (integer-nonnegative? LEnd))
  (warn-if-false (< LStart LEnd))
  (warn-if-false (<= LEnd (get-line-count Buf)))
  (warn-if-false (cbuffer? Buf))

  (let ((orig-len (get-line-count Buf)))
    (op-delete-lines! Buf LStart LEnd)

    ;; Move the active data position
    (cond
     ((= LEnd orig-len)
      ;; When the end of the buffer is being modified, set the
      ;; active data position to the new end of the buffer.
      (set-line-cur! Buf (1- (get-line-count Buf)))
      (set-pd-cur-to-simd-eol! Buf))

     (else
      ;; Otherwise, set the active data position to the beginning
      ;; of the line after the deletion region.
      (set-line-cur! Buf LStart)
      (set-pd-cur-to-simd-bol! Buf)))))

(define (insert-lines! Buf LInsert StrList)
  "Append the StrList at the addressed line LInsert.  If LInsert is
the line after the last line in the buffer, StrList is appended to the
end of the text.  The previous contents of LInsert and following lines
will be pushed down.  The active data position will be set to the end
of the last inserted line, or, if StrList were an empty list, to the
end of the addressed line."
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (integer-nonnegative? LInsert))
  (warn-if-false (<= LInsert (get-line-count Buf)))
  (warn-if-false (list-of-strings-length-0+? StrList))

  (if (null? StrList)
      (begin
        (set-line-cur! Buf LInsert)
        (set-pd-cur-to-simd-eol! Buf))
      ;; else
      (begin
        (op-insert-lines! Buf LInsert StrList)
        (let ((strlistlen (length StrList)))
          (set-line-cur! Buf (+ LInsert (1- strlistlen)))
          (set-pd-cur-to-simd-eol! Buf)))))

(define (write-lines-to-port Buf LStart LEnd Port)
  "Writes the buffer lines LStart (inclusive) through LEnd (exclusive)
to the given port.  It returns the number of bytes written."
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (integer-nonnegative? LStart))
  (warn-if-false (integer-nonnegative? LEnd))
  (warn-if-false (output-port? Port))

  (let ((bytes-written 0))
    (for-each
     (lambda (line)
       (write-line line Port)
       (set! bytes-written (+ bytes-written (string-length line) 1)))
     (sublist (get-text Buf) LStart LEnd))
    bytes-written))


(define-method (insert-lines-from-port! (Buf <CBuffer>) LInsert InputPort)
  "Reads in from the port, line by line, appending those lines to the
buffer.  Read until #<eof> is found, and then inserts the text at
lines LInsert.

The active data position will be set to the end of the last line
inserted into the buffer.

Return the number of characters or bytes received."
  (warn-if-false (input-port? InputPort))
  (warn-if-false (integer-nonnegative? LInsert))
  (warn-if-false (<= LInsert (get-line-count Buf)))

  (let loop ((txt (read-line InputPort))
             (newstrlist '())
             (chars-read 0))
    (if (not (eof-object? txt))
        (loop (read-line InputPort)
              (append newstrlist (list txt))
              (+ chars-read (string-length txt)))
        ;; else
        (begin
          ;; Note that insert-lines handles the undo information and
          ;; moving the active data position.
          (insert-lines! Buf LInsert newstrlist)
          chars-read))))

(define-method (join-lines (Buf <CBuffer>) LStart LEnd)
  "Combine the lines LStart (inclusive) to LEnd (exclusive) into a single
line. The active data position will be moved to the last character position of
that joined line if SIMD is 'forward, or to the first character position if
SIMD is 'backward."
  (warn-if-false (< LStart LEnd))
  (warn-if-false (>= LStart 0))
  (warn-if-false (<= LEnd (get-line-count Buf)))

  (when (> (- LEnd LStart) 1)
    (op-merge-lines! Buf LStart LEnd)
      ;; Move the activive data position
      (set-line-cur! Buf LStart)
      (set-pd-cur-to-simd-eol! Buf)))

(define (move-lines Buf LMoveStart LMoveEnd LMoveTo)
  "Reposition the lines between LMoveStart (inclusive) and
LMoveEnd (exclusive) to the location LMoveTo.

The active data line will be set to the end of the last line
moved."
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (< LMoveStart LMoveEnd))
  (warn-if-false (or (< LMoveTo LMoveStart) (<= LMoveEnd LMoveTo)))
  (warn-if-false (<= LMoveEnd (get-line-count Buf)))

  (if (>= (- LMoveEnd LMoveStart) 1)
      (begin
        (op-move-lines! Buf LMoveStart LMoveEnd LMoveTo)

        ;; Move the activive data position
        (set-line-cur! Buf (+ LMoveTo (1- (- LMoveEnd LMoveStart))))
        (set-pd-cur-to-simd-eol! Buf))
      ;; else
      (begin
        (set-line-cur! Buf LMoveTo)
        (set-pd-cur-to-simd-eol! Buf))))

(define-method (replace-all-from-port (Buf <CBuffer>) InputPort)
  "Delete the entire contents of the buffer, and then reads in from the
port, line by line, appending those lines to the buffer.  Read until
#<eof> is found.

The active data position will be set to the end of the last line in
the buffer.

Return the number of characters or bytes received."
  (warn-if-false (input-port? InputPort))

  ;; Note that deleting all the lines removes the mark, the tags, and
  ;; the bookmarks, too.  Also it handles the undo information for
  ;; the deletion.
  (let ((oldlen (get-line-count Buf)))
    (let loop ((txt (read-line InputPort))
               (newstrlist '())
               (chars-read 0))
      (if (not (eof-object? txt))
          (loop (read-line InputPort)
                (append newstrlist (list txt))
                (+ chars-read (string-length txt)))
          ;; else
          (begin
            ;; Note that insert-lines handles the undo information and
            ;; moving the active data position.
            (if (zero? oldlen)
                (insert-lines! Buf 0 newstrlist)
                (replace-lines Buf 0 oldlen newstrlist))
            chars-read)))))

(define (replace-lines Buf LStart LEnd StrList)
  "Removes the lines of text from LStart (inclusive) to LEnd (exclusive),
and inserts StrList as a replacement to the deleted lines.

If StrList is non-null, the active data positiion is set to the end of
the last inserted line. If StrList is null, the active position is set
to the beginning of the line after the last deleted line.
If StrList is null and the deleted range was at the end of the buffer,
the active data line set to the end of the line before the deletion
region."
  (warn-if-false (integer-nonnegative? LStart))
  (warn-if-false (integer-nonnegative? LEnd))
  (warn-if-false (< LStart LEnd))
  (warn-if-false (<= LEnd (get-line-count Buf)))
  (warn-if-false (list-of-strings-length-0+? StrList))

  (let ((orig-len (get-line-count Buf)))
    (op-replace-lines! Buf LStart LEnd StrList)
    (cond
     ((= LEnd orig-len)
      ;; When the end of the buffer is being modified, set the active
      ;; data position to the new end of the buffer.
      (set-line-cur! Buf (1- (get-line-count Buf)))
      (set-pd-cur-to-simd-eol! Buf))

     ((null? StrList)
      ;; If this is really a delete because StrList is null, set the
      ;; active data position to the beginning of the line after the
      ;; deleted region.
      (set-line-cur! Buf LStart)
      (set-pd-cur-to-simd-bol! Buf))

     (else
      ;; On a normal change operation, set the active data position to
      ;; the end of the last changed line.
      (set-line-cur! Buf (+ LStart (1- (- LEnd LStart))))
      (set-pd-cur-to-simd-eol! Buf)))))


(define (substitute-in-lines Buf LStart LEnd Regex Replacement Flags)
  "This command shall search all the lines in the BUF from
LStart (inclusive) to LEnd (exclusive) for matches to the regular
expression REGEX.  When a match is found, it is replaced with the
string REPLACEMENT.

The REPLACEMENT string may contain some escape sequences.

An ampersand '&' will be replaced by the string matching regex.

A backslash followed by a digit from 1 to 9 ('\\1' to '\\9') will be
replaced with the Nth matching subexpression, or by an empty string if
there was no Nth matching subexpression.

A backslash + backslash will insert a single backslash.

A backslash + 'n' will split the line at that location.

FLAGS is a string that may contain the letter 'g' or a digit '1'
through '9'.  If 'g' is present, the substitution is applied to
allnon-overlapping matches in each line.  If a digit is present, the
substitution applies only to the Nth match in the line."
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (integer-nonnegative? LStart))
  (warn-if-false (integer-nonnegative? LEnd))
  (log-debug-locals)

  (do ((i LStart (1+ i)))
      ((>= i LEnd))
    (let* ((old-txt (list-ref (get-text Buf) i))
           (new-txt (string-sed-substitute
                     old-txt
                     Regex
                     Replacement
                     Flags)))
      (unless (string=? old-txt new-txt)
        ;; Weirdly, regex substitute is Ed's only way to split a
        ;; line, so we handle '\n' here by splitting the lines.
        (let ((split-new-txt (string-split new-txt #\newline)))
          (replace-lines Buf i (1+ i) split-new-txt))))))

(define-method (get-bookmark-line (Buf <CBuffer>) Name)
  "Return the line number in which a bookmark has been placed, or
#f is no such bookmark exists."
  (let ((bm (bookmark-get (get-bookmarks Buf) Name)))
    (and bm
         (list-ref bm 1))))

(define-method (regex-tag-lines (Buf <CBuffer>) LStart LEnd RegexString Tag)
  "This procedure places a TAG at the beginning of all lines
between LStart (inclusive) and LEnd (exclusive) that match a regular
expression string.

Even if there are multiple matches in a line, a single Tag is used."
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (integer-nonnegative? LStart))
  (warn-if-false (integer-nonnegative? LEnd))
  (warn-if-false (string? RegexString))
  (warn-if-false (string? Tag))

  (when (> (get-line-count Buf) 0)
    (let ((rx (make-regexp RegexString)))
      (let loop ((i LStart)
                 (tags-list '()))
        (cond
         ((and (< i LEnd) (regexp-exec rx (get-text-line Buf i)))
          (loop (1+ i)
                (append tags-list
                        (list (list Tag
                                    i
                                    (if (eqv? (get-implicit-movement-direction Buf) 'forward)
                                        0
                                        (string-length (get-text-line Buf i))))))))
         ((< i LEnd)
          (loop (1+ i)
                tags-list))
         (else
          (op-tags-set! Buf tags-list)))))))

(define-method (regex-tag-nonmatching-lines (Buf <CBuffer>) LStart LEnd RegexString Tag)
  "This procedure places a TAG at the beginning of all lines
between LStart (inclusive) and LEnd (exclusive) that do not match a regular
expression string.

Even if there are multiple matches in a line, a single Tag is used."
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (integer-nonnegative? LStart))
  (warn-if-false (integer-nonnegative? LEnd))
  (warn-if-false (string? RegexString))
  (warn-if-false (string? Tag))
  
  (when (> (get-line-count Buf) 0)
    (let ((rx (make-regexp RegexString)))
      (let loop ((i LStart)
                 (tags-list '()))
        (cond
         ((and (< i LEnd) (not (regexp-exec rx (get-text-line Buf i))))
          (loop (1+ i)
                (append tags-list
                        (list (list Tag
                                    i
                                    (if (eqv? (get-implicit-movement-direction Buf) 'forward)
                                        0
                                        (string-length (get-text-line Buf i))))))))
         ((< i LEnd)
          (loop (1+ i)
                tags-list))
         (else
          (op-tags-set! Buf tags-list)))))))

(define (clear-tags Buf Name)
  "This procedure removes any tags with the name Name."
  (op-tags-remove! Buf
                   (tag-get-all-by-name (get-tags Buf) Name)))
                   
(define-method (for-each-tagged-line (buf <CBuffer>) proc name)
  "For each line that contains the Tag (proceeding from beginning
to end) the active data position is set to the location of that tag,
and then PROC is called.  Proc must be a procedure that takes BUF as a
parameter.  If the application of PROC modifies the text in the given
line, the _RX tag is removed.  If no text is modified, the active data
position will be returned to its original location."
  (let ((tags (tag-get-all-by-name (get-tags buf) name))
        (LOrig (get-line-cur buf))
        (PdOrig (get-pd-cur buf))
        (modified? #f))
    (for-each
     (lambda (tag)
       (let ((LCur (second tag))
             (PdCur (third tag)))
         (let ((OldStr (list-ref (get-text buf) LCur)))
           (set-line-cur! buf LCur)
           (set-pd-cur! buf PdCur)
           (proc buf)
           (unless (string=? OldStr (list-ref (get-text buf) LCur))
             (set! modified? #t)
             (op-tags-remove! buf
                              (list (list name LCur PdCur)))))))
     tags)

    ;; If nothing has changed, return the active data position
    ;; to its original position.
    (unless modified?
      (set-line-cur! buf LOrig)
      (set-pd-cur! buf PdOrig))))

(define-method (regex-search-backward-line (Buf <CBuffer>) LStart RegexString)
  "This searches the the text for the first line that matches the
regular expression.  The search begins on the line before lineno. The
search will wrap around to the end of the buffer, if necessary, and
search upto and including lineno.

If a match is found, the procedure returns the line number of the
matching line, and the active data position will be set to the end of
the matching line.  If a match is not found, the procedure returns #f
and the active data position is unchanged."
  (warn-if-false (integer-nonnegative? LStart))
  (warn-if-false (string? RegexString))

  (if (= (get-line-count Buf) 0)
      #f
      ;; else
      (let* ((rx (make-regexp RegexString))
             (next-line (lambda (n)
                          (if (< (1- n) 0)
                              (1- (get-line-count Buf))
                              (1- n))))
             (start-line (next-line LStart)))
        (let loop ((i start-line))
          (if (regexp-exec rx (list-ref (get-text Buf) i))
              (begin
                (set-line-cur! Buf i)
                (set-pd-cur-to-simd-eol! Buf)
                i)
              ;; else
              (if (= (next-line i) start-line)
                  #f
                  ;; else
                  (loop (next-line i))))))))

(define-method (regex-search-forward-line (Buf <CBuffer>) LStart RegexString)
  "This searches the text for the first line that matches the regular
expression.  The search begins on the line after lineno. The search
will wrap around the end of the buffer, if necessary, and search upto
and including lineno.

If a match is found, the procedure returns the line number of the
matching line, and the active data position will be set to the end of
the matching line.  If a match is not found, the procedure returns #f
and the active data position is unchanged."
  (warn-if-false (string? RegexString))
  (warn-if-false (integer-nonnegative? LStart))

  (if (= 0 (get-line-count Buf))
      #f
      ;; else
      (let* ((rx (make-regexp RegexString))
             (next-line (lambda (n)
                          (if (>= (1+ n) (length (get-text Buf)))
                              0
                              (1+ n))))
             (start-line (next-line LStart)))
        (let loop ((i start-line))
          (if (regexp-exec rx (list-ref (get-text Buf) i))
              (begin
                (set-line-cur! Buf i)
                (set-pd-cur-to-simd-eol! Buf)
                i)
              ;; else
              (if (= (next-line i) start-line)
                  #f
                  ;; else
                  (loop (next-line i))))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; OPERATIONS INSPIRED BY ECMA48

(define (bookmark-pos! Buf L Pd Name)
  "Set a bookmark at active data line L and active data position Pd using Name."

  ;; Unusually, the Ed Mark command doesn't change the current line.
  (warn-if-false (integer-nonnegative? L))
  (warn-if-false (string? Name))
  (warn-if-false (>= L 0))
  (warn-if-false (< L (get-line-count Buf)))
  (warn-if-false (cbuffer? Buf))

  (op-bookmark-set! Buf
                    L
                    Pd
                    Name))

(define (pad-lines! Buf LCount)
  "If necessary, add empty lines to Buf to ensure that
it has LCount lines."
  (when (< (get-line-count Buf) LCount)
    (op-insert-lines! Buf
                      (get-line-count Buf)
                      (make-list (- LCount (get-line-count Buf)) ""))))
  
(define (pad-line-with-spaces! Buf L PCount)
  "If necessary, append spaces to the end of line L to ensure that it
has a length of PCount cells."
  (let ((len (string-length (get-text-line Buf L))))
    (when (< len PCount)
      (op-insert-in-line! Buf L len (make-string (- PCount len) #\space)))))

(define (pad-to-position! Buf L P)
  "If necessary, append lines and spaces to the buffer to ensure that
the position L,P is in the buffer.  E.G. that there are at least
L+1 lines and that line L has a length of at least P+1."
  (let ((lines-required (max 0 (- (1+ L) (get-line-count Buf)))))
    (let ((spaces-required
           (if (> lines-required 0)
               (1+ P)
               ;; else
               (max 0 (- (1+ P) (string-length (get-text-line Buf L)))))))
      (cond
       ((and (= 0 lines-requred) (= 0 spaces-required))
        ;; Do nothing
        #f)
       ((and (= 0 lines-required) (< 0 spaces-required))
        (op-insert-in-line! Buf L (string-length (get-text-line Buf L))
                            (make-string spaces-required #\space)))
       ((and (< 0 lines-required) (< 0 spaces-required))
        (op-insert-lines! Buf
                          (get-line-count Buf)
                          (append
                           (make-list (- L (get-line-count Buf)) "")
                           (list
                            (make-string spaces-required #\space)))))))))

        
#|

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; OPERATIONS INSPIRED BY SED

(define-method (sed-display (buf <CBuffer>) LStart LEnd)
  "Display the lines from LStart (inclusive) to LEnd (exclusive)
to the current output port."
  'fixme)

(define-method (sed-display-to-port (buf <CBuffer>) LStart LEnd Port)
  "Display the lines from LStart (inclusive) to LEnd (exclusive)
to the given Port."
  'fixme)

(define-method (sed-write (buf <CBuffer>) LStart LEnd)
  "Write the lines from LStart (inclusive) to LEnd (exclusive)
using escape sequences for non-printable characters."
  'fixme)

(define-method (sed-delete (buf <CBuffer>) LStart LEnd)
  "Delete the lines from LStart (inclusive) to LEnd (exclusive)"
  'fixme)

(define-method (sed-display-and-print (buf <CBuffer>) LStart LEnd)
  "Display the lines from LStart (inclusive) to LEnd (exclusive)
to the current output port, and then delete them from the buffer."
  'fixme)

(define-method (sed-replace (buf <CBuffer>) LStart LEnd StrList)
  "Replace the lines LStart (inclusive) to LEnd (exclusive)
with the list of strings StrList."
  'fixme)

(define-method (sed-read-replace (buf <CBuffer>) LStart LEnd)
  "For each line from LStart (inclusive) to LEnd (exclusive),
read a line from the current input port, replacing the line in the
buffer."
  'fixme)

(define-method (sed-display-and-read-replace (buf <CBuffer>) LStart LEnd)
  "For each line from LStart (inclusive) to LEnd (exclusive),
display the line to the current output port, and then read a line from
the current input port, which will replace that line in the buffer."
  'fixme)

(define-method (sed-substitute (buf <CBuffer>) LStart LEnd RegexString
                        ReplacementString Flags)
  "For each line from LStart (inclusive) to LEnd (exclusive),
search for the regular expression RegexString.  If found, replace it
with ReplacementString, minding Flags."
  'fixme)

(define-method (sed-transliterate (buf <CBuffer>) LStart LEnd StringBefore StringAfter)
  "For each line from LStart (inclusive) to LEnd (exclusive),
replace any character in the line that found in StringBefore with the
corrensponding character in StringAfter.  StringBefore and StringAfter
must be the same length."
  'fixme)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; OPERATIONS INSPIRED BY EX

(define-method (ex-shift-left (buf <CBuffer>) LStart LEnd Count)
  "For each of the lines from LStart (inclusive) to LEnd  (exclusive) remove Count leading blank characters from the lines.
If there are fewer than Count leading blank characters in a
given line, remove all the leading blank characters."
  'fixme)

(define-method (ex-shift-right (buf <CBuffer>) LStart LEnd Count)
  "For each of the lines from LStart (inclusive) to LEnd (exclusive)
append Count leading blank characters to the lines."
  'fixme)

(define-method (ex-delete-non-printing-characters (buf <CBuffer>) LStart LEnd Count)
  "For each of the lines from LStart (inclusive) to LEnd (exclusive)
remove any non-printing characters other than format effectors tab, newline, and form feed."
  'fixme)

(define-method (ex-scroll-up (buf <CBuffer>) Count)
  "Move the active data position up Count lines."
  'fixme)

(define-method (ex-scroll-down (buf <CBuffer>) Count)
  "Move the active data position down Count lines."
  'fixme)

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
|#
