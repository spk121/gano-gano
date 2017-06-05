;;; -*- mode: scheme; coding: us-ascii; indent-tabs-mode: nil; -*-
;;; (gano math) - mathmatical operations on integer spans
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

(define-module (gano math)
  #:use-module (mlg logging)
  #:export(x-insert-before
	   x-insert
	   x-replace
	   x-move
	   x-copy
	   x-delete
	   ))

;; These are math operations for text locations.  These are generic:
;; the positions could be cells locations in a line, or they could be
;; lines within a document.

(define (%x-insert X XInsert LenInsert where)
  (cond
   ;; Pos is before text to insert
   ;; |--*--:--| => |--*--:|new|--|
   ((or (and (eqv? where 'before) (< X XInsert))
        (and (eqv? where 'at) (< X XInsert)))
    X)

   ;; Pos is after text to insert
   ;; |--:--*--| => |--:|new|--*--|
   (else
    (+ X LenInsert))))

(define (x-insert-before X XInsert LenInsert)
  "Adjust position X as if LenInsert cells were inserted just before
position XInsert."
  (x-insert X XInsert LenInsert 'before))

(define (x-insert X XInsert LenInsert)
  "Adjust position X as if LenInsert cells were inserted at
position XInsert."
  (cond
   ;; Pos is before text to insert
   ;; |--*--:--| => |--*--:|new|--|
   ((< X XInsert)
    X)

   ;; Pos is after text to insert
   ;; |--:--*--| => |--:|new|--*--|
   (else
    (+ X LenInsert))))


(define (x-replace X XReplaceStart XReplaceEnd ReplaceLen)
  "Adjust position X as if the region XReplaceStart (inclusive) to
XReplaceEnd (exclusive) was eliminated and replaced with a region of
length ReplaceLen."
  (cond

   ;; Pos is before text to replace
   ;; |--*--|repl|--| => |--*--|new|--|
   ((< X XReplaceStart)
    X)

   ;; Pos is in text to replace
   ;; |--|re*pl|--| => |--|new|--|
   ((and (>= X XReplaceStart) (< X XReplaceEnd))
    #f)

   (else
    ;; Pos is after text to replace
    ;; |--|repl|--*--| => |--|new|--*--|
    (+ (- X (- XReplaceEnd XReplaceStart)) ReplaceLen))))

(define (x-move X XMoveStart XMoveEnd XMoveTo)
  "Adjust the position as if the region XMoveStart (inclusive) to
XMoveEnd (exclusive) was moved to the location XMoveTo."
  (let ((MoveLen (- XMoveEnd XMoveStart)))
    (log-debug-locals)
    (cond
     ((= XMoveTo XMoveStart)
      ;; If we're not moving, then the position doesn't change.
      X)

     ((and (< XMoveStart XMoveTo) (< XMoveTo XMoveEnd))
      ;; Can't move block inside itself.
      (error "invalid move in line"))

     ;; Pos is before text to move and point
     ;; |--*--|move|--:--| => |--*----:|move|--|
     ;; |--*--:--|move|--| => |--*--:|move|----|
     ;; or Pos is after text to move and point
     ;; |--|move|--:--*--| => |----:|move|--*--|
     ;; |--:--|move|--*--| => |--:|move|----*--|
     ((or (and (< X XMoveStart) (< X XMoveTo))
          (and (>= X XMoveEnd) (> X XMoveTo)))
      X)

     ;; Pos is inside the text to move
     ;; |--|mo*ve|--:--| => |----:|mo*ve|--|
     ;; |--:--|mo*ve|--| => |--:|mo*ve|----|
     ((and (<= XMoveStart X) (< X XMoveEnd))
      (cond
       ((< XMoveTo XMoveStart)
        (+ XMoveTo
           (- X XMoveStart)))
       (else
        (+ XMoveTo
           (- X XMoveStart)
           (- MoveLen)))))

     ;; Text to move is before point. Pos is between text and point.
     ;; |--|move|--*--:--| => |----*--:|move|--|
     ((and (<= XMoveEnd X) (< X XMoveTo))
      (- X MoveLen))

     ;; Text to move is after point. Pos is between point and text
     ;; |--:--*--|move|--| => |--:|move|--*----|
     ((and (<= XMoveTo X) (< X XMoveStart))
      (+ X MoveLen))

     (else
      (error "impossible error")))))

(define (x-copy X XCopyStart XCopyEnd XCopyTo followCopy)
  "Adjust the position X as if the region from XCopyStart (inclusive)
to XCopyEnd (exclusive) was copied and inserted at the position
XCopyAfter.  If followCopy is #t, if position X is within the copy
region, it moves to the new copy.  If followCopy is #f, if position
within the copy region, it stays in the original region to be copied."
  (let ((CopyLen (- XCopyEnd XCopyStart)))
    (cond
     ((and (< XCopyStart XCopyTo) (< XCopyTo XCopyEnd))
      ;; Can't copy block inside itself.
      (error "invalid x-copy"))

     ;; Pos is before text to copy and point
     ;; |--*--|copy|--:--| => |--*--|copy|--:|copy|--|
     ;; |--*--:--|copy|--| => |--*--:|copy|--|copy|--|
     ((and (< X XCopyStart) (< X XCopyTo))
      X)

     ;; Pos is after text to copy and point
     ;; |--|copy|--:--*--| => |--|copy|--:|copy|--*--|
     ;; |--:--|copy|--*--| => |--:|copy|--|copy|--*--|
     ((and (<= XCopyEnd X) (<= XCopyTo X))
      (+ X CopyLen))

     ;; Pos is inside the text to copy. Pos doesn't follow copy.
     ;; |--|co*py|--:--| => |--|co*py|--:|copy|--|
     ;; |--:--|co*py|--| => |--:|copy|--|co*py|--|
     ((and (<= XCopyStart X) (< X XCopyEnd) (not followCopy))
      (if (< XCopyTo XCopyStart)
          (+ X CopyLen)
          X))

     ;; Pos is inside the text to copy. Pos follows copy.
     ;; |--|co*py|--:--| => |--|copy|--:|co*py|--|
     ;; |--:--|co*py|--| => |--:|co*py|--|copy|--|
     ((and (<= XCopyStart X) (< X XCopyEnd) followCopy)
      (if (< XCopyTo XCopyStart)
          (+ XCopyTo (- X XCopyStart))
          (+ X CopyLen)))

     ;; Text to copy is before point. Pos is between text and point.
     ;; |--|copy|--*--:--| => |--|copy|--*--:|copy|--|
     ((and (<= XCopyEnd X) (< X XCopyTo))
      X)

     ;; Text to copy is after point. Pos is between point and text
     ;; |--:--*--|copy|--| => |--:|copy|--*--|copy|--|
     ((and (<= XCopyTo X) (< X XCopyStart))
      (+ X CopyLen))

     (else
      (error "impossible error")))))

(define (x-delete X XDeleteStart XDeleteEnd)
  "Adjust the position X as if the region from
XDeleteStart (inclusive) to XDeleteEnd (exclusive) was removed."
  (let ((DeleteLen (- XDeleteEnd XDeleteStart)))
    (cond
     ;; Pos is before text to delete
     ;; |--*--|del|--| => |--*----|
     ((< X XDeleteStart)
      X)

     ;; Pos is inside the text to delete
     ;; |--|de*l|--| => |----|
     ((and (<= XDeleteStart X) (< X XDeleteEnd))
      #f)

     ;; Pos is after text to delete
     ;; |--|del|--*--| => |----*--|
     ((<= XDeleteEnd X)
      (- X DeleteLen))

     (else
      (error "impossible error")))))
