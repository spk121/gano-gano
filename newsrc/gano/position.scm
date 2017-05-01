;; A position is a coordinate in a text: a line number and a position
;; in a given line.  This module are math operations for positions.

;; Each procedure returns an updated position or an empty list. The
;; empty list is returned when the position was invalidated by the
;; operation.
(define-module (gano position)
  #:use-module (gano math)
  #:use-module (srfi srfi-1)
  #:export (
	    pos-insert-in-line-before
	    pos-insert-in-line-after
	    pos-replace-in-line
	    pos-move-in-line
	    pos-copy-in-line
	    pos-delete-in-line
	    
	    pos-insert-lines-before
	    pos-insert-lines-after
	    pos-replace-lines
	    pos-move-lines
	    pos-copy-lines
	    pos-delete-lines
	    
	    pos-merged-lines
	    pos-split-lines))

(define (<> a b)
  (not (= a b)))

(define (pos-insert-in-line-before LPos PPos LInsert PInsert LenInsert) 
  (cond
   ((<> LPos LInsert)
    (list LPos PPos))
   (else
    (list LPos (x-insert-before PPos PInsert LenInsert)))))

(define (pos-insert-in-line-after LPos PPos LInsert PInsert LenInsert)
  (cond
   ((<> LPos LInsert)
    (list LPos PPos))
   (else
    (list LPos (x-insert-after PPos PInsert LenInsert)))))

(define (pos-replace-in-line LPos PPos LReplace PReplaceStart PReplaceEnd ReplaceLen)
  (cond
   ((<> LPos LReplace)
    (list LPos PPos))
   (else
    (let ((P (x-replace PPos PReplaceStart PReplaceEnd ReplaceLen)))
      (if P
	  (list LPos P)
	  '())))))

(define (pos-move-in-line LPos PPos LMove PMoveStart PMoveEnd PMoveAfter)
  "Adjust the position as if the text from PMoveStart (inclusive)
to PMoveEnd (exclusive) was moved after the position PMoveAfter."
  (cond
   ((<> LPos LMove)
    (list LPos PPos))
   (else
    (list LPos (x-move PPos PMoveStart PMoveEnd PMoveAfter)))))
     
(define (pos-copy-in-line LPos PPos LCopy PCopyStart PCopyEnd PCopyAfter followCopy)
  "Adjust the position as if the text from PCopyStart (inclusive) to
PCopyEnd (exclusive) was copied after the position PCopyAfter.  If
followCopy is #t, a position in the copy region moves to the new copy.
If followCopy is #f, a position in the copy region stays in the region
to be copied."
  (cond
   ((<> LPos LCopy)
    (list LPos PPos))
   (else
    (list LPos (x-copy PPos PCopyStart PCopyEnd PCopyAfter followCopy)))))

(define (pos-delete-in-line LPos PPos LDelete PDeleteStart PDeleteEnd)
  "Adjust the position as if the text from PDeleteStart (inclusive) to
PDeleteEnd (exclusive) was removed."
  (cond
   ((<> LPos LDelete)
    (list LPos PPos))
   (else
    (let ((P (x-delete PPos PDeleteStart PDeleteEnd)))
      (if P (list LPos P) '())))))

(define (pos-insert-lines-before LPos PPos LInsert LCount)
  "Adjust position as if LCount lines were inserted before LInsert."
  (list (x-insert-before LPos LInsert LCount) PPos))

(define (pos-insert-lines-after LPos PPos LInsert LCount)
  "Adjust position as if LCount lines were inserted before LInsert."
  (list (x-insert-after LPos LInsert LCount) PPos))

(define (pos-replace-lines LPos PPos LReplaceStart LReplaceEnd ReplaceLen)
  "Adjust position as if lines LReplaceStart (inclusive) to
LReplaceEnd (exclusive) were replaced with a new block of ReplaceLen
lines."
  (let ((LNew (x-replace LPos LReplaceStart LReplaceEnd ReplaceLen)))
    (if LNew (list LNew PPos) '())))

(define (pos-move-lines LPos PPos LMoveStart LMoveEnd LMoveAfter)
  "Adjust position as if the lines LMoveStart (inclusive) to
LMoveEnd (exclusive) were moved to after line LMoveAfter."
  (list (x-move LPos LMoveStart LMoveEnd LMoveAfter)
	PPos))

(define (pos-copy-lines LPos PPos LCopyStart LCopyEnd LCopyAfter followCopy)
  "Adjust position as if the lines LCopyStart (inclusive) to
LCopyEnd (exclusive) were copied to after the line LCopyAfter.  If
followCopy is true and the position is inside the copy region, this
procedure adjusts the position as if it moved to the new copy.  If it
is false, and the position is inside the copy region, the procedure
adjust the position as if it remained in the original."
  (list (x-copy LPos LCopyStart LCopyEnd LCopyAfter followCopy)
	PPos))

(define (pos-delete-lines LPos PPos LDeleteStart LDeleteEnd)
  "Adjust position as if the lines from LDeleteStart (inclusive)
to LDeleteEnd (exclusive) were deleted."
  (let ((LNew (x-delete LPos LDeleteStart LDeleteEnd)))
    (if LNew (list LNew PPos) '())))

(define (pos-merge-lines LPos PPos LMergeStart LMergeEnd PMergeLengthList)
  "Adjust the position as if the lines LMergeStart (inclusive) through
LMergeEnd (exclusive) were merged into a single line.  The lengths
of the lines LMergeStart to LMergeEnd are stored in PMergeLengthList."
  (cond
   ((<= LPos LMergeStart)
    (list LPos PPos))

   ((>= LPos LMergeEnd)
    (list (- LPos (1- (- LMergeEnd LMergeStart)))
	  PPos))

   (else
    (list LMergeStart
	  (+ PPos
	     (apply + (take PMergeLengthList (- (min LPos LMergeEnd) LMergeStart))))))))

(define (pos-split-lines LPos PPos LSplit PSplitAfter)
  "Adjust the position as of line LSplit had been split after the
position PSplitAfter."
  (cond
   ((or (< LPos LSplit)
	(and (= LPos LSplit) (<= PPos PSplitAfter)))
    (list LPos PPos))
   
   ((> LPos LSplit)
    (list (1+ LPos) PPos))
   
   ((and (= LPos LSplit) (> PPos PSplitAfter))
    (list (1+ LPos) (- PPos (+ PSplitAfter 1))))
  
   (else
    (error "impossible error"))))
