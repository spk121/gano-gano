;;; -*- mode: scheme; coding: us-ascii; indent-tabs-mode: nil; -*-
;;; (gano CBuffer) - an storage model for lines of text
;;; Copyright (C) 2017,2019 Michael L. Gran <spk121@yahoo.com>
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

This module is the public-facing API for <CBuffer> types
as described in CBuffer-base.scm.

By design, the methods in (gano CBuffer) should only call the
primitive methods provided by (gano CBuffer-base).  None of the
mutating methods from (gano CBuffer-base) should be re-exported here.

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
  #:use-module (mlg typechecking)
  #:use-module (mlg math)
  #:use-module (mlg logging)
  #:use-module (mlg lists)
  #:use-module (mlg strings)
  #:use-module (gano stringlist)
  #:use-module (gano poslist)
  #:use-module (gano position)
  #:use-module (gano CBuffer-base)
  #:re-export (<CBuffer>
               %dump-cbuffer
               bookmark:line
               bookmark:name
               bookmark:pd
               cbuffer?
               get-bookmarks
               get-home-pos
               get-implicit-movement-direction
               get-line-count
               get-line-cur
               get-pd-cur
               get-tags
               get-text
               make-empty-cbuffer
               tag:line
               tag:name
               tag:pd
               undo
               )
  #:export (
            active-position-report      ; CPR
            append-line!
            carriage-return!             ; CR
            character-position-absolute! ; HPA
            insert-character-in-line!
            line-feed!                   ; LF
            line-position-absolute!      ; VPA
            set-line-home!               ; SLH
            set-line-limit!              ; SLL
            set-mode!                    ; SM
            write-character!

            ;; Dumb TTY Operations
            ;; bell                        ; BEL

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
            next-line                   ; NEL
            page-format-selection       ; PFS
            page-position-absolute      ; PPA
            page-position-backward      ; PPB
            page-position-forward       ; PPR
            quad                        ; QUAD
            repeat                      ; REP
            reverse-line-feed           ; RI
            select-graphics-rendition   ; SGR
            set-page-home               ; SPH
            set-page-limit              ; SPL
            line-position-absolute      ; VPA
            line-position-backward      ; VPB
            line-position-forward       ; VPR

            ;; ;; get-line-count
            ;; ;; get-line-cur
            ;; get-line-frame
            ;; get-line-frame-size
            ;; ;; get-pd-cur
            ;; get-text-cur
            ;; get-text-cur-length
            ;; get-text-line
            ;; increase-pd-cur!
            ;; render-line
            ;; set-line-cur!
            ;; set-line-frame!
            ;; set-line-frame-size!
            ;; set-pd-cur!
            ;; set-pd-goal!
            ;; set-positions!
            ;; set-tab-size!
            ;; set-text!
            ;; set-text-cur!
            )
  #:re-export (get-text-line get-text-cur))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; METHODS

(define-method (active-position-report (Buf <CBuffer>))
  "Returns a pair where the car is the n-th line position and the cdr
is the m-th character position of the active data position."
  (cons (get-line-cur Buf)
        (get-pd-cur Buf)))

(define-method (append-line! (Buf <CBuffer>) (Str <string>))
  "Append the Str as a new line at the end of Buf. The active data
position will be set to the end of the inserted line."
  (let ((LineCount (get-line-count Buf)))
    (op-insert-lines! Buf LineCount (list Str))
    (set-line-cur! Buf LineCount)
    (set-pd-cur-to-simd-eol! Buf)))

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

(define-method (carriage-return! (buf <CBuffer>))
  "If the implicit movement direction is 'forward, move the active
data position to the line home position of the current line.  If the
implicit movement direction is 'backward, move the active data
position to the line-limit position of the current line."

  (let ((pos (if (eqv? 'forward (get-implicit-movement-direction buf))
                       (get-home-pos buf)
                       (get-limit-pos buf)))
        (len (get-text-cur-length buf)))
    (if (< len pos)
        (op-insert-in-line! buf (get-line-cur buf) len (make-string (- pos len) #\space)))
  (set-pd-cur! buf pos)))

(define-method (character-position-absolute! (buf <CBuffer>) n)
  "Move the active data position to the n-th codepoint in the active
line, padding with spaces if necessary.  The position will be bracketed
by the home and limit columns."
  (let ((home (get-home-pos buf))
        (limit (get-limit-pos buf))
        (len (get-text-cur-length buf)))
    (let ((pos (min (max home n) limit)))
      (if (< len pos)
          (op-insert-in-line! buf (get-line-cur buf) len (make-string (- pos len) #\space)))
      (set-pd-cur! buf pos))))

(define (insert-character-in-line! Buf LInsert PInsert C)
  "Insert C into the addressed line LInsert at position PInsert.
If LInsert is the line after the last line in the buffer, C is
appended as a new line to the end of the text.  If PInsert is after
the end of the line, C is appended to the end of the line.  The
active data position will be set to after the inserted character
if the implicit movement direction is forward, or will be set
before the inserted character otherwise."
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

(define-method (line-feed! (Buf <CBuffer>))
  "Move the active data position to the corresponding character
position of the following line."
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

(define-method (line-position-absolute! (buf <CBuffer>) n)
  "Move the active data position to the n-th line"
  (set-line-cur! buf (min n (get-line-count buf))))

;; SLH - SET LINE HOME
(define-method (set-line-home! (buf <CBuffer>) n)
  "Sets the home position column of this buffer to the given column index"
  (warn-if-false (integer-nonnegative? n))
  (warn-if-false (< (get-home-pos buf) (get-limit-pos buf)))
  (set-home-pos! buf n))

;; SLL - SET LINE LIMIT
(define-method (set-line-limit! (buf <CBuffer>) n)
  "Sets the limit position column of this buffer to the given column index"
  (warn-if-false (integer-nonnegative? n))
  (warn-if-false (< (get-home-pos buf) (get-limit-pos buf)))
  (set-limit-pos! buf n))

;; SM - SET MODE
(define-method (set-mode! (buf <CBuffer>) mode val)
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
   ((eqv? mode 'SIMD)
    (if (member val (list 'forward 'backward))
        (begin
          (set-implicit-movement-direction! buf val)
          val)
        ;; else
        (error "unknown mode value ~a" val)))
   (else
    (error "unknown mode ~a" mode))))

;; WC - WRITE-CHARACTER
(define-method (write-character! (buf <CBuffer>) c)
  "Places the character C at the current data location.  Depending on
the current insertion-replacement-mode (IRM), this may be either an
insertion or a replcement.  Depending on the character-editing
mode (HEM), the current data location will be advanced to after the
character or remain unchanged.  The implicit-movement-direction (SIMD)
mode will determine if the the cursor, if advanced, is advanced
forward or backward.  The invalid movement mode (IMM) determines what
happens if the limit column is reached."
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
;; Operations inspiried by the dumb line editor

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
       (let ((LCur (tag:line tag))
             (PdCur (tag:pd tag)))
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
       ((and (= 0 lines-required) (= 0 spaces-required))
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
  (let* ([Y (get-y buf)]
         ;; Move forward n lines, or to the end of the buffer
         [L1 (bracket-line buf (+ Y n))])
    (when (> L1 (get-y buf))
          (set-y! buf L1)
          (update-pp-list! buf)
          (set-positions! buf 0 'data))))
;; CPL
(define (cursor-preceding-line buf n)
  "Move the active presentation position to the 1st character position
of the n-th preceding line in the presentation component"
  (let* ([Y (get-y buf)]
         ;; Move backward n lines, or to the beginning of the buffer
         [L1 (bracket-line buf (- Y n))])
    (when (< L1 (get-y buf))
          (set-y! buf L1)
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
