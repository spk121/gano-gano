(use-modules (srfi srfi-64)
	     (gano math))

(test-begin "t-gano-math")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; INSERT
;; A position before the insertion shouldn't change.
(test-equal "position before insertion"
  0 (x-insert 0 3 4))
;; A position just before the insertion shouldn't change.
(test-equal "position before insertion"
  2 (x-insert 2 3 4))
;; A position at the insertion location should move forward count
;; locations.
(test-equal "position at insertion"
  7 (x-insert 3 3 4))
;; A position after the insertion location should move forward
;; count locations
(test-equal "position after insertion"
  8 (x-insert 4 3 4))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FORWARDS MOVE
;; A position before a forward move shouldn't change.
(test-equal "position before move"
  0 (x-move 0 1 3 10))
;; The position at MoveStart should move to MoveTo, then
;; back count lines because of the cut.
(test-equal "position at move start"
  8 (x-move 1 1 3 10))
;; A position in a forward move should move to after MoveTo, then
;; back count lines because of the cut
(test-equal "position in move"
  9 (x-move 2 1 3 10))
;; A position at MoveEnd should move backward to MoveStart
(test-equal "position at move end"
  1 (x-move 3 1 3 10))
;; A position between MoveEnd and MoveTo should move backward
;; count lines.
(test-equal "position after move end"
  2 (x-move 4 1 3 10))
;; A position just before MoveTo should move backward count
;; lines.
(test-equal "position before move start"
  7 (x-move 9 1 3 10))
;; A position at MoveTo doesn't change, because it
;; moved backward for the cut but forward for the paste.
(test-equal "position at move to"
  10 (x-move 10 1 3 10))
;; A position after MoveTo doesn't change for the same reason.
(test-equal "position after move to"
  11 (x-move 11 1 3 10))

;; BACKWARDS MOVE
;; A position before a backward move shouldn't change.
(test-equal "position before backward move"
  0 (x-move 0 8 10 1))
;; The position at MoveTo should move forward count lines
(test-equal "position in backwards move"
  3 (x-move 1 8 10 1))
;; A position between MoveTo and MoveStart should move forward
;; count lines.
(test-equal "backwards move"
  6 (x-move 4 8 10 1))
;; The position at MoveStart should move to MoveTo.
(test-equal "position at move start in backwards move"
  1 (x-move 8 8 10 1))
;; A position between MoveStart and MoveEnd should move to after
;; MoveTo.
(test-equal "position between start and end in backwards move"
  2 (x-move 9 8 10 1))
;; A position at MoveEnd should stay the same.
(test-equal "position at move end in backwards move"
  10 (x-move 10 8 10 1))
;; A position after MoveEnd should stay the same
(test-equal "position after move end in backwards move"
  11 (x-move 11 8 10 1))

(test-end "t-gano-math")
