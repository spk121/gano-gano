;;; -*- mode: scheme; coding: us-ascii; indent-tabs-mode: nil; -*-
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
bookmarks are as intradocument navigation.

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
"active data position" is a special address that is used in the command set.
It is the location of a virtual cursor.  The "mark" is another special
location used to indicate the extreme of a selection of text or a
range of text used in operations.

To enable undo, redo, and delta operations, an "operations list" is
stored.  And operations list is an ordered list that describes all the
mutations that have occured to the CBuffer, like inserted text,
deleted text, etc.  Note that only mutation operations are stored.

|#

(define-module (gano CBuffer-base)
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
  #:use-module (mlg lists)
  #:use-module (mlg strings)
  #:export (
            <CBuffer>
            ;; Constructors
            make-empty-cbuffer
            cbuffer?

            ;; Needed for testing for now
            bookmark:name
            bookmark:line
            bookmark:pd
            tag:name
            tag:line
            tag:pd
            %dump-cbuffer
            add-tag
            get-bookmarks
            get-character-editing-mode
            get-home-pos
            get-implicit-movement-direction
            get-insertion-replacement-mode
            get-invalid-movement-mode
            get-limit-pos
            get-line-count
            get-line-cur
            get-pd-cur
            get-tab-size
            get-tags
            get-text
            get-text-cur
            get-text-cur-length
            get-text-line
            get-undo
            increase-line-cur!
            increase-pd-cur!
            set-character-editing-mode!
            set-home-pos!
            set-insertion-replacement-mode!
            set-limit-pos!
            set-line-and-pd-cur!
            set-line-cur!
            set-pd-cur!
            set-pd-cur-to-simd-bol!
            set-pd-cur-to-simd-eol!
            set-text!

            ;; The operations
            op-bookmark-set!
            op-bookmark-remove!
            op-tags-set!
            op-tags-remove!
            op-insert-in-line!
            op-replace-in-line!
            op-move-in-line!
            op-copy-in-line!
            op-delete-in-line!
            op-insert-lines!
            op-merge-lines!
            op-replace-lines!
            op-delete-lines!
            op-move-lines!
            op-copy-lines!
            op-split-lines!

            ;; The Almighty Undo
            undo

            ))

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

  ;; After a graphic character is received, the active data position
  ;; will be moved.  If the active data position should be moved
  ;; toward the end of the string, SIMD is 'forward.  If the active
  ;; data position should move toward the beginning of the string,
  ;; SIMD is backward.
  (m_SIMD #:init-value 'forward
          #:getter get-implicit-movement-direction
          #:setter set-implicit-movement-direction!)

  ;; The text
  ;; A list of strings.
  (m_rgText #:init-value '("") #:accessor get-text #:setter set-text!)

  ;; The current line number. Zero indexed.
  (m_LCur #:init-value 0 #:getter get-line-cur #:setter %set-line-cur!)

  ;; The current data position.  The data position is index to the
  ;; codepoint in the current line's string.  The data position is
  ;; distinct from the display position, because of variable character
  ;; widths.
  (m_PdCur #:init-value 0 #:getter get-pd-cur #:setter %set-pd-cur!)

  ;; The number of spaces per between tab stops
  (m_tabSize #:init-value 8 #:getter get-tab-size #:setter set-tab-size!)

  ;; The number of lines per vertical tab stops
  (m_vertTabSize #:init-value 6 #:getter get-vert-tab-size
                 #:setter set-vert-tab-size!)

  ;; Page and line sizes
  ;; The maximum length of a line in presentation cells.
  (m_PMax #:init-value 1024 #:getter get-xcell-max
          #:setter set-xcell-max!)
  ;; The maximum number of lines on a page, in lines.
  (m_pageLMax #:init-value 1024 #:getter get-y-page-max
              #:setter set-y-page-max!)

  ;; Homes and Limits.
  ;; A line has a home column and a limit column.  Editing on a line will
  ;; begin at the 'home' column and end at the 'limit' column.  These
  ;; coordinates are in cells.
  ;; A page also has a home and a limit: the first and last editable
  ;; lines on a page.
  (m_PHome #:init-value 0 #:getter get-home-pos #:setter set-home-pos!)
  (m_PLimit #:init-value 1024 #:getter get-limit-pos
            #:setter set-limit-pos!)
  (m_pageHome #:init-value 0 #:getter get-y-page-home
              #:setter set-y-page-home!)
  (m_pageLimit #:init-value 0 #:getter get-y-page-limit
               #:setter set-y-page-limit!)

  ;; The mark
  (m_fMarkSet #:init-value #f #:getter is-mark-set? #:setter set-mark-flag!)
  (m_LMark #:init-value 0 #:getter get-line-mark #:setter set-line-mark!)
  (m_PdMark #:init-value 0 #:getter get-pd-mark #:setter set-pd-mark!)

  ;; The bookmarks
  (m_rgBookmark #:init-value '() #:accessor get-bookmarks
                #:setter set-bookmarks!)
  ;; The tags
  (m_rgTags #:init-value '() #:accessor get-tags #:setter set-tags!)

  ;; The undo list
  (m_rgUndo #:init-value '() #:accessor get-undo #:setter set-undo!)
  )

;; The bookmarks are of the form
;; (cons 'symbol line pd)
;; Tags, too
(define (bookmark:name B) (first B))
(define (bookmark:line B) (second B))
(define (bookmark:pd B) (third B))
(define (bookmark:name! B val) (list-set! B 0 val))
(define (bookmark:line! B val) (list-set! B 1 val))
(define (bookmark:pd! B val) (list-set! B 2 val))
(define (tag:name B) (first B))
(define (tag:line B) (second B))
(define (tag:pd B) (third B))
(define (tag:name! B val) (list-set! B 0 val))
(define (tag:line! B val) (list-set! B 1 val))
(define (tag:pd! B val) (list-set! B 2 val))

(define (append-undo! buf op)
  (set-undo! buf (append (get-undo buf)
                         (list op))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CONSTRUCTORS

(define (make-empty-cbuffer)
  "Creates a <CBuffer> with a default empty text buffer."
  (make <CBuffer>))

(define (cbuffer? buf)
  "Returns #t if BUF is of type <CBuffer>"
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

(define (get-line-count buf)
  "Return the number of lines in the buffer"
  (warn-if-false (cbuffer? buf))
  (length (get-text buf)))

;; FIXME: last line problem.
(define (bracket-line Buf L)
  "Return L if it is a valid line number for the current buffer, or
the nearest valid line number of L is out of range."
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (integer-nonnegative? L))
  (max 0
       (min L
            (get-line-count Buf))))

(define-method (get-text-cur-length (buf <CBuffer>))
  "Return the number of codepoints in the active line"
  (if (null? (get-text buf))
      0
      (string-length (get-text-cur buf))))

(define-method (bracket-pd (buf <CBuffer>) pd)
  "Return pd if it is valid data position for the active line, or the
nearest valid data position for the active line if pd is out of
range."
  (max 0
       (min pd
            (get-text-cur-length buf))))

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
      ""
      ;; else
      (if (= (get-line-cur buf) (get-line-count buf))
          ""
          ;; else
          (list-ref (get-text buf) (get-line-cur buf)))))


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

(define (undo-bookmark-set! Buf LBookmark PBookmark Name)
  (warn-if-false (cbuffer? Buf))
  (warn-if-false (integer-nonnegative? LBookmark))
  (warn-if-false (integer-nonnegative? PBookmark))
  (warn-if-false (<= LBookmark (get-line-count Buf)))
  (warn-if-false (<= PBookmark (string-length (get-text-line Buf LBookmark))))
  (warn-if-false (string? Name))

  (bookmark-remove! (get-bookmarks Buf) Name))

(define (undo-bookmark-move! Buf LBookmark PBookmark Name LOldBookmark POldBookmark)
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

(define (op-tags-set! Buf ListOfTags)
  (warn-if-false (cbuffer? Buf))
  (let ((tags-used '()))
    (do ((i 0 (1+ i))) ((>= i (length ListOfTags)))
      (let ((tag-cur (list-ref ListOfTags i)))
        (unless (tag-name-at? (get-tags Buf)
                              (tag:name tag-cur)
                              (tag:line tag-cur)
                              (tag:pd tag-cur))
          (tag-set! (get-tags Buf)
                    (tag:name tag-cur) (tag:line tag-cur) (tag:pd tag-cur))
          (set! tags-used (append tags-used (list tag-cur))))))
    (unless (null? tags-used)
      (append-undo! Buf (list 'tags-set tags-used)))))

(define (undo-tags-set! Buf ListOfTags)
  (do ((i 0 (1+ i))) ((>= i (length ListOfTags)))
    (let ((tag-cur (list-ref ListOfTags i)))
      (tag-remove-at-by-name! (get-tags Buf)
                              (tag:name tag-cur)
                              (tag:line tag-cur)
                              (tag:pd tag-cur)))))

(define (op-tags-remove! Buf ListOfTags)
  "Remove all tags that match tags in the given list."
  (warn-if-false (cbuffer? Buf))
  (let ((tags-used '()))
    (do ((i 0 (1+ i))) ((>= i (length ListOfTags)))
      (let ((tag-cur (list-ref ListOfTags i)))
        (when (tag-name-at? (get-tags Buf)
                            (tag:name tag-cur)
                            (tag:line tag-cur)
                            (tag:pd tag-cur))
          (tag-remove-at-by-name! (get-tags Buf)
                                  (tag:name tag-cur) (tag:line tag-cur)
                                  (tag:pd tag-cur))
          (set! tags-used (append tags-used (list tag-cur))))))
    (unless (null? tags-used)
      (append-undo! Buf (list 'tags-remove tags-used)))))

(define (undo-tags-remove! Buf ListOfTags)
  (do ((i 0 (1+ i))) ((>= i (length ListOfTags)))
    (let ((tag-cur (list-ref ListOfTags i)))
      (tag-set! (get-tags Buf)
                (tag:name tag-cur)
                (tag:line tag-cur)
                (tag:pd tag-cur)))))

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
          (set-line-and-pd-cur! Buf (list LReplace PReplaceStart))
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
                          (tag:name tag)
                          (tag:line tag)
                          (tag:pd tag)))
              LostTags)))

(define (op-move-in-line! Buf LMove PMoveStart PMoveEnd PMoveTo)
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
  (set-mark-flag! Buf #f))

(define (undo-move-in-line! Buf LMove PMoveStart PMoveEnd PMoveTo LCur PdCur)
  "Undo a move-in-line operation."
  (let ((copylen (- PMoveEnd PMoveStart)))
    (set-text! Buf
               (strlist-unmove-in-line (get-text Buf) LMove PMoveStart PMoveEnd PMoveTo))
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
    (poslist-copy-in-line (get-tags Buf) LCopy PCopyStart PCopyEnd PCopyTo)
    (adjust-poslist-copy-in-line (get-bookmarks Buf) LCopy PCopyStart PCopyEnd PCopyTo #f)

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
    (adjust-poslist-delete-in-line! (get-bookmarks Buf)
                                    LDelete PDeleteStart PDeleteEnd)
    (adjust-poslist-delete-in-line! (get-tags Buf)
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
                          (tag:name tag)
                          (tag:line tag)
                          (tag:pd tag)))
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
                    (bookmark:name bmark)
                    (bookmark:line bmark)
                    (bookmark:pd bmark)))
   MovedBmarks)
  (tag-remove-all-in-line! (get-tags Buf) LStart)
  (for-each
   (lambda (tag)
     (tag-set! (get-tags Buf)
               (tag:name tag) (tag:line tag) (tag:pd tag)))
   MovedTags))

(define (op-replace-lines! Buf LStart LEnd StrList)
  "Replace the lines from LStart (inclusive) and LEnd (exclusive)
with strlist"
  (warn-if-false (integer-nonnegative? LStart))
  (warn-if-false (integer-nonnegative? LEnd))
  (warn-if-false (< LStart LEnd))
  (warn-if-false (<= LEnd (get-line-count Buf)))
  (warn-if-false (list-of-strings-length-0+? StrList))
  (let ((strlistlen (length StrList)))
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
                          (tag:name tag)
                          (tag:line tag)
                          (tag:pd tag)))
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
          (undo-bookmark-set! Buf
                              (second last-op) ;LBookmark
                              (third last-op) ;PBookmark
                              (fourth last-op)) ;Name
          #t)
         ((eqv? (car last-op) 'bookmark-move)
          (undo-bookmark-move! Buf
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
