;; These are math operations for text locations.  These are generic:
;; the positions could be cells locations in a line, or they could be
;; lines within a document.
(define-module (gano math)
  #:export(x-insert-before
	   x-insert-after
	   x-replace
	   x-move
	   x-copy
	   x-delete
	   ))

(define (x-insert X XInsert LenInsert before-or-after)
  (cond
   ;; Pos is before text to insert
   ;; |--*--:--| => |--*--:|new|--|
   ((or (and (eqv? before-or-after 'before) (< X XInsert))
	(and (eqv? before-or-after 'after) (<= X XInsert)))
    X)

   ;; Pos is after text to insert
   ;; |--:--*--| => |--:|new|--*--|
   (else
    (+ X LenInsert))))

(define (x-insert-before X XInsert LenInsert)
  "Adjust position X as if LenInsert cells were inserted just before
position XInsert."
  (x-insert X XInsert LenInsert 'before))

(define (x-insert-after X XInsert LenInsert)
  "Adjust position X as if LenInsert cells were inserted just after
position XInsert."
  (x-insert X XInsert LenInsert 'after))

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

(define (x-move X XMoveStart XMoveEnd XMoveAfter)
  "Adjust the position as if the region XMoveStart (inclusive) to
XMoveEnd (exclusive) was moved just after the position XMoveAfter."
  (let ((MoveLen (- XMoveEnd XMoveStart)))
    (cond
     ((and (<= XMoveStart XMoveAfter) (< XMoveAfter XMoveEnd))
      ;; Can't move block inside itself.
      (error "invalid move in line"))

     ;; Pos is before text to move and point
     ;; |--*--|move|--:--| => |--*----:|move|--|
     ;; |--*--:--|move|--| => |--*--:|move|----|
     ;; or Pos is after text to move and point
     ;; |--|move|--:--*--| => |----:|move|--*--|
     ;; |--:--|move|--*--| => |--:|move|----*--|
     ((or (and (< X XMoveStart) (<= X XMoveAfter))
	  (and (>= X XMoveEnd) (> X XMoveAfter)))
      X)

     ;; Pos is inside the text to move
     ;; |--|mo*ve|--:--| => |----:|mo*ve|--|
     ;; |--:--|mo*ve|--| => |--:|mo*ve|----|
     ((and (<= XMoveStart X) (< X XMoveEnd))
      (cond
       ((< XMoveAfter XMoveStart)
	(+ XMoveAfter
	   (1+ (- X XMoveStart))))
       (else
	(+ XMoveAfter
	   (1+ (- X XMoveStart))
	   (- MoveLen)))))

     ;; Text to move is before point. Pos is between text and point.
     ;; |--|move|--*--:--| => |----*--:|move|--|
     ((and (<= XMoveEnd X) (<= X XMoveAfter))
      (- X MoveLen))

     ;; Text to move is after point. Pos is between point and text
     ;; |--:--*--|move|--| => |--:|move|--*----|
     ((and (< XMoveAfter X) (< X XMoveStart))
      (+ X MoveLen))

     (else
      (error "impossible error")))))

(define (x-copy X XCopyStart XCopyEnd XCopyAfter followCopy)
  "Adjust the position X as if the region from XCopyStart (inclusive)
to XCopyEnd (exclusive) was copied after the position XCopyAfter.  If
followCopy is #t, if position X is within the copy region, it moves to
the new copy.  If followCopy is #f, if position within the copy
region, it stays in the original region to be copied."
  (let ((CopyLen (- XCopyEnd XCopyStart)))
    (cond
     ((and (<= XCopyStart XCopyAfter) (< XCopyAfter XCopyEnd))
      ;; Can't copy block inside itself.
      (error "invalid x-copy"))

     ;; Pos is before text to copy and point
     ;; |--*--|copy|--:--| => |--*--|copy|--:|copy|--|
     ;; |--*--:--|copy|--| => |--*--:|copy|--|copy|--|
     ((and (< X XCopyStart) (<= X XCopyAfter))
      X)

     ;; Pos is after text to copy and point
     ;; |--|copy|--:--*--| => |--|copy|--:|copy|--*--|
     ;; |--:--|copy|--*--| => |--:|copy|--|copy|--*--|
     ((and (<= XCopyEnd X) (< XCopyAfter X))
      (+ X CopyLen))

     ;; Pos is inside the text to copy. Pos doesn't follow copy.
     ;; |--|co*py|--:--| => |--|co*py|--:|copy|--|
     ;; |--:--|co*py|--| => |--:|copy|--|co*py|--|
     ((and (<= XCopyStart X) (< X XCopyEnd) (not followCopy))
      (if (< XCopyAfter XCopyStart)
	  (+ X CopyLen)
	  X))

     ;; Pos is inside the text to copy. Pos follows copy.
     ;; |--|co*py|--:--| => |--|copy|--:|co*py|--|
     ;; |--:--|co*py|--| => |--:|co*py|--|copy|--|
     ((and (<= XCopyStart X) (< X XCopyEnd) followCopy)
      (if (< XCopyAfter XCopyStart)
	  (+ XCopyAfter (1+ (- X XCopyStart)))
	  (+ X CopyLen)))

     ;; Text to copy is before point. Pos is between text and point.
     ;; |--|copy|--*--:--| => |--|copy|--*--:|copy|--|
     ((and (<= XCopyEnd X) (<= X XCopyAfter))
      X)

     ;; Text to copy is after point. Pos is between point and text
     ;; |--:--*--|copy|--| => |--:|copy|--*--|copy|--|
     ((and (< XCopyAfter X) (< X XCopyStart))
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
