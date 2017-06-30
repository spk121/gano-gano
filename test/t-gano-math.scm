(use-modules (srfi srfi-64)
	     (gano math))

(test-begin "t-gano-math")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; FORWARDS MOVE
;; A position before a forward move shouldn't change.
(test-equal 0 (x-move 0 1 3 10))
;; The position at MoveStart should move to MoveTo, then
;; back count lines because of the cut.
(test-equal 8 (x-move 1 1 3 10))
;; A position in a forward move should move to after MoveTo, then
;; back count lines because of the cut
(test-equal 9 (x-move 2 1 3 10))
;; A position at MoveEnd should move backward to MoveStart
(test-equal 1 (x-move 3 1 3 10))
;; A position between MoveEnd and MoveTo should move backward
;; count lines.
(test-equal 2 (x-move 4 1 3 10))
;; A position just before MoveTo should move backward count
;; lines.
(test-equal 7 (x-move 9 1 3 10))
;; A position at MoveTo doesn't change, because it
;; moved backward for the cut but forward for the paste.
(test-equal 10 (x-move 10 1 3 10))
;; A position after MoveTo doesn't change for the same reason.
(test-equal 11 (x-move 11 1 3 10))

;; BACKWARDS MOVE
;; A position before a backward move shouldn't change.
(test-equal 0 (x-move 0 8 10 1))
;; The position at MoveTo should move forward count lines
(test-equal 3 (x-move 1 8 10 1))
;; A position between MoveTo and MoveStart should move forward
;; count lines.
(test-equal 6 (x-move 4 8 10 1))
;; The position at MoveStart should move to MoveTo.
(test-equal 1 (x-move 8 8 10 1))
;; A position between MoveStart and MoveEnd should move to after
;; MoveTo.
(test-equal 2 (x-move 9 8 10 1))
;; A position at MoveEnd should stay the same.
(test-equal 10 (x-move 10 8 10 1))
;; A position after MoveEnd should stay the same
(test-equal 11 (x-move 11 8 10 1))

(test-end "t-gano-math")
