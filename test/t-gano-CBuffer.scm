(use-modules (srfi srfi-64)
	     (gano CBuffer)
	     (gano poslist))

(test-begin "t-gano-CBuffer")

;; OP MOVE IN LINE
(define op-move-in-line! (@@ (gano CBuffer) op-move-in-line!))
(define buf (make-empty-cbuffer))
(insert-lines! buf 0 '("one" "two" "three"))

;; change "two" to "wto"
(op-move-in-line! buf 1 0 1 2)

(test-equal "op-move-in-line! can move forward"
  '("one" "wto" "three")
  (get-text buf))

(undo buf)

(test-equal "can undo move-in-line! forward"
  '("one" "two" "three")
  (get-text buf))

;; change "three" to "eethr"
(set-text! buf '("one" "two" "three"))
(op-move-in-line! buf 2 3 5 0)

(test-equal "op-move-in-line! can move backward"
  '("one" "two" "eethr")
  (get-text buf))

(undo buf)

(test-equal "can undo move-in-line! backward"
  '("one" "two" "three")
  (get-text buf))

;; change "one" to "one"
(set-text! buf '("one" "two" "three"))
(op-move-in-line! buf 0 0 3 0)

(test-equal "op-move-in-line! can 'move' a character nowhere"
  '("one" "two" "three")
  (get-text buf))

(undo buf)

(test-equal "can undo move-in-line! nowhere"
  '("one" "two" "three")
  (get-text buf))

(set-text! buf '("one" "two" "three"))
(bookmark-bol! buf 1 "alpha")
(op-move-in-line! buf 1 0 1 3)

(test-equal "move-in-line moves bookmarks forward"
  '(("alpha" 1 2))
  (get-bookmarks buf))

(undo buf)

#|
;; OP REPLACE IN LINE
(define op-replace-in-line! (@@ (gano CBuffer) op-replace-in-line!))

(define buf (make-empty-cbuffer))

(test-equal "make-empty-cbuffer returns a cbuffer"
  #t
  (cbuffer? buf))

(insert-lines! buf 0 '("one" "two" "three"))

(test-equal "insert-lines! into empty buffer inserts text"
  '("one" "two" "three")
  (get-text buf))

;; change "two" to "tWo"
(op-replace-in-line! buf 1 1 2 "W")

(test-equal "op-replace-in-line! can replace 1 character"
  '("one" "tWo" "three")
  (get-text buf))

;; change "three" to "FOUR"
(op-replace-in-line! buf 2 0 5 "FOUR")

(test-equal "op-replace-in-line! can replace one line with a shorter line"
  '("one" "tWo" "FOUR")
  (get-text buf))

;; change "one" to "five"
(op-replace-in-line! buf 0 0 3 "five")

(test-equal "op-replace-in-line! can replace one line with a longer line"
  '("five" "tWo" "FOUR")
  (get-text buf))

(undo buf)
(undo buf)
(undo buf)

(test-equal "undo reverts replace-in-line text"
  '("one" "two" "three")
  (get-text buf))

(bookmark-bol! buf 1 "alpha")
(op-replace-in-line! buf 1 0 3 "six")

(test-equal "replace-in-line removes overwritten bookmarks"
  '()
  (get-bookmarks buf))

(undo buf)

(test-equal "undo restores bookmarks overwritten by replace-in-line"
  '(("alpha" 1 0))
  (get-bookmarks buf))
|#
(test-end "t-gano-CBuffer")
