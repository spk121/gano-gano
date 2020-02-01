(use-modules (srfi srfi-64)
	     (gano CBuffer)
	     (gano poslist))

(test-begin "t-gano-CBuffer")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; active-position-report

;; Returns the line and either the data or presentation position,
;; depending on the current Device Component Select Mode (DSCM)

(test-equal "active-position-report of null buffer"
  '(0 . 0)
  (let ((buf (make-empty-cbuffer)))
    (active-position-report buf)))

(test-equal "active-position-report of 2nd character"
  '(0 . 1)
  (let ((buf (make-empty-cbuffer)))
    (write-character! buf #\x)
    (active-position-report buf)))

(test-equal "active-position-report of 2nd line"
  '(1 . 0)
  (let ((buf (make-empty-cbuffer)))
    (line-feed! buf)
    (active-position-report buf)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; append-line!

(test-equal "append-line! to empty buffer adds a line of text"
  '("" "hello")
  (let ((buf (make-empty-cbuffer)))
    (append-line! buf "hello")
    (get-text buf)))

(test-equal "append-line! to empty buffer moves the display position to the end of buffer"
  '(1 . 5)
  (let ((buf (make-empty-cbuffer)))
    (append-line! buf "hello")
    (active-position-report buf)))

(test-equal "append-line! to non-empty buffer adds a line of text"
  '("" "hello" "world")
  (let ((buf (make-empty-cbuffer)))
    (append-line! buf "hello")
    (append-line! buf "world")
    (get-text buf)))

(test-equal "append-line! to non-empty buffer moves the display position to the end of buffer"
  '(2 . 5)
  (let ((buf (make-empty-cbuffer)))
    (append-line! buf "hello")
    (append-line! buf "world")
    (active-position-report buf)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; bookmark-bol!

(test-assert "bookmark-bol! on empty buffer"
  (let ((buf (make-empty-cbuffer)))
    (bookmark-bol! buf 0 "alpha")
    (bookmark-name-at? (get-bookmarks buf) "alpha" 0 0)))

(test-assert "bookmark-bol! on non-empty line"
  (let ((buf (make-empty-cbuffer)))
    (write-character! buf #\x)
    (bookmark-bol! buf 0 "alpha")
    (bookmark-name-at? (get-bookmarks buf) "alpha" 0 0)))

(test-assert "bookmark-bol! on second line"
  (let ((buf (make-empty-cbuffer)))
    (append-line! buf "foo")
    (bookmark-name-at? (get-bookmarks buf) "alpha" 1 0)
    (bookmark-bol! buf 1 "alpha")))    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; carriage-return!

(test-equal "CR when SIMD=forward and HOME=0 moves to column 0"
  '(1 . 0)
  (let ((buf (make-empty-cbuffer)))
    (append-line! buf "hello")          ; moves position to end of new line
    (carriage-return! buf)
    (active-position-report buf)))

(test-equal "CR when SIMD=forward and HOME=1 moves to column 1"
  '(1 . 1)
  (let ((buf (make-empty-cbuffer)))
    (set-line-home! buf 1)
    (append-line! buf "hello")          ; moves position to end of new line
    (carriage-return! buf)
    (active-position-report buf)))

(test-equal "CR when SIMD=backward and LIMIT=80 moves to column 80"
  '(1 . 80)
  (let ((buf (make-empty-cbuffer)))
    (set-mode! buf 'SIMD 'backward)
    (set-line-limit! buf 80)
    (append-line! buf "hello")          ; moves position to end of new line
    (carriage-return! buf)              ; moves position to limit, appending spaces
    (active-position-report buf)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; character-position-absolute!

(test-equal "character-position-absolute! to 1st position"
  '(0 . 0)
  (let ((buf (make-empty-cbuffer)))
    (write-character! buf #\x)
    (character-position-absolute! buf 0)
    (active-position-report buf)))

(test-equal "character-position-absolute! to right of EOL"
  '(0 . 10)
  (let ((buf (make-empty-cbuffer)))
    (character-position-absolute! buf 10)
    (active-position-report buf)))

(test-equal "character-position-absolute! will pad with spaces"
  '("          ")
  (let ((buf (make-empty-cbuffer)))
    (character-position-absolute! buf 10)
    (get-text buf)))

(test-equal "character-position-absolute! is bracketed by the line limit"
  '(0 . 20)
  (let ((buf (make-empty-cbuffer)))
    (set-line-limit! buf 20)
    (character-position-absolute! buf 30)
    (active-position-report buf)))

(test-equal "character-position-absolute! is bracketed by the line home"
  '(0 . 20)
  (let ((buf (make-empty-cbuffer)))
    (set-line-home! buf 20)
    (character-position-absolute! buf 0)
    (active-position-report buf)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; insert-character-in-line!

(test-equal "insert-character-in-line! in empty buffer"
  '(("x") (0 . 1))
  (let ((buf (make-empty-cbuffer)))
    (insert-character-in-line! buf 0 0 #\x)
    (list (get-text buf)
          (active-position-report buf))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; line-feed!

(test-assert "line-feed! in empty buffer"
  (let ((buf (make-empty-cbuffer)))
    (line-feed! buf)
    (and
     (equal? '(1 . 0) (active-position-report buf))
     (equal? '("" "")
	     (get-text buf)))))

(test-assert "line-feed! from existing line to existing line"
  (let ((buf (make-empty-cbuffer)))
    (append-line! buf "hello")
    (append-line! buf "world")
    (line-position-absolute! buf 1)
    (character-position-absolute! buf 3)
    (line-feed! buf)
    (and
     (equal? '(2 . 3) (active-position-report buf))
     (equal? '("" "hello" "world")
	     (get-text buf)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; write-character!

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; OP BOOKMARK SET
(define op-bookmark-set! (@@ (gano CBuffer) op-bookmark-set!))
(define buf (make-empty-cbuffer))
(insert-lines! buf 0 '("one" "two" "three"))
(op-bookmark-set! buf 1 2 "bmark")
(%dump-cbuffer buf)

(test-assert "bookmark can be set"
  (bookmark-name-at? (get-bookmarks buf) "bmark" 1 2))

(op-bookmark-set! buf 1 0 "bmark")
(test-assert "bookmark can be moved"
  (bookmark-name-at? (get-bookmarks buf) "bmark" 1 0))

(undo buf)

(test-assert "bookmark can be unmoved"
  (bookmark-name-at? (get-bookmarks buf) "bmark" 1 2))

(undo buf)

(test-equal "bookmark can be unset"
  #f
  (bookmark-get (get-bookmarks buf) "bmark"))

;; Test that setting an out-of-range bookmark fails

;; Test that setting a bookmark with an invalid name fails

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; OP TAGS SET
(define op-tags-set! (@@ (gano CBuffer) op-tags-set!))
(define buf (make-empty-cbuffer))
(insert-lines! buf 0 '("one" "two" "three"))

(op-tags-set! buf '(("tag" 1 2)))

(test-assert "tag can be set"
  (tag-name-at? (get-tags buf) "tag" 1 2))

(op-tags-set! buf '(("tag" 1 0)))
(test-assert "different tags can have the same name"
  (and (tag-name-at? (get-tags buf) "tag" 1 0)
       (tag-name-at? (get-tags buf) "tag" 1 2)))

(undo buf)

(test-assert "remove a tag doesn't remove all tags with the same name"
  (tag-name-at? (get-tags buf) "tag" 1 2))

(undo buf)

(test-equal "tags can be removed"
  '()
  (tag-get-all-by-name (get-tags buf) "tag"))

;; Test that multiple tags with different names can be at the
;; same location

(op-tags-set! buf '(("alpha" 1 2)))
(op-tags-set! buf '(("bravo" 1 2)))
(test-assert "can set multiple tags at the same location"
  (and (tag-name-at? (get-tags buf) "alpha" 1 2)
       (tag-name-at? (get-tags buf) "bravo" 1 2)))

;; Test that removing one tag at a given location doesn't remove all
;; tags at the location
(undo buf)

(test-assert "undo op-tag-set! doesn't remove all tags at a location"
  (and (tag-name-at? (get-tags buf) "alpha" 1 2)
       (not (tag-name-at? (get-tags buf) "bravo" 1 2))))


;; Test that trying to set multiple tags with the same name at the
;; same location only leave a single tag of that name at the location.

;; Test that setting multiple tags with the same name at the same location
;; only sets one undo operation.

;; Test that setting an out of range tag fails

;; Test that setting an invalid tag name fails

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; OP INSERT IN LINE

(define op-insert-in-line! (@@ (gano CBuffer) op-insert-in-line!))
(define buf (make-empty-cbuffer))
(insert-lines! buf 0 '("one" "two" "three"))

;; change "two" to "twoTWO"
(op-insert-in-line! buf 1 3 "TWO")

(test-equal "op-insert-in-line! can insert at EOL"
  '("one" "twoTWO" "three" "")
  (get-text buf))

(undo buf)

#|
(test-equal "can undo op-insert-in-line! at EOL"
  '("one" "two" "three" "")
  (get-text buf))

;; change "three" to "THREEthree"
(set-text! buf '("one" "two" "three"))
(op-insert-in-line! buf 2 0 "THREE")

(test-equal "op-insert-in-line! can insert at BOL"
  '("one" "two" "THREEthree")
  (get-text buf))

(undo buf)

(test-equal "can undo op-insert-in-line! at BOL"
  '("one" "two" "three")
  (get-text buf))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; OP REPLACE IN LINE

(define op-replace-in-line! (@@ (gano CBuffer) op-replace-in-line!))
(define buf (make-empty-cbuffer))
(insert-lines! buf 0 '("one" "two" "three"))
(op-bookmark-set! buf 1 2 "B1")
(op-bookmark-set! buf 2 2 "B2")

;; change "two" to "twoTWO"
(op-replace-in-line! buf 1 3 3 "TWO")

(test-equal "op-replace-in-line! can replace at EOL"
  '("one" "twoTWO" "three" "")
  (get-text buf))

(undo buf)

(test-equal "can undo op-replace-in-line! at EOL"
  '("one" "two" "three" "")
  (get-text buf))

;; change "three" to "THREE"
(set-text! buf '("one" "two" "three"))
(op-replace-in-line! buf 2 0 5 "THREE")

(test-equal "op-replace-in-line! can replace at BOL"
  '("one" "two" "THREE")
  (get-text buf))

(undo buf)

(test-equal "can undo op-replace-in-line! at BOL"
  '("one" "two" "three")
  (get-text buf))

(op-replace-in-line! buf 1 1 2 "W")

(test-equal "op-replace-in-line! can replace 1 character"
  '("one" "tWo" "three")
  (get-text buf))

(undo buf)

(test-equal "can undo op-replace-in-line! replace 1 character"
  '("one" "two" "three")
  (get-text buf))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; OP MOVE IN LINE
(define op-move-in-line! (@@ (gano CBuffer) op-move-in-line!))
(define buf (make-empty-cbuffer))
(insert-lines! buf 0 '("one" "two" "three"))

;; change "two" to "wto"
(op-move-in-line! buf 1 0 1 2)

(test-equal "op-move-in-line! can move forward"
  '("one" "wto" "three" "")
  (get-text buf))

(undo buf)

(test-equal "can undo move-in-line! forward"
  '("one" "two" "three" "")
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
|#

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
