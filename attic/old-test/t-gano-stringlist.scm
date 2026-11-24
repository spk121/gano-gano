(use-modules (srfi srfi-64)
	     (gano stringlist))

(test-begin "t-gano-stringlist")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; STRLIST MOVE IN LINE
;; Moving a text backward
(test-equal "move text backward in line"
  '("barfoo") (strlist-move-in-line '("foobar") 0 3 6 0))
;; Moving a text forward
(test-equal "move text forward in line"
  '("barfoo") (strlist-move-in-line '("foobar") 0 0 3 6))
;; Moving a text nowhere
(test-equal "move text nowhere in line"
  '("foobar") (strlist-move-in-line '("foobar") 0 2 4 2))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; STRLIST INSERT IN LINE
;; Inserting text into an empty strlist
(test-equal "insert text into empty strlist"
  '("foo") (strlist-insert-in-line '() 0 0 "foo"))
;; Inserting text before the beginning of the first line
(test-equal "insert text before beginning of line"
  '("barfoo") (strlist-insert-in-line '("foo") 0 0 "bar"))
;; Inserting text into the middle of the first line
(test-equal "insert text in middle of line"
  '("fbaroo") (strlist-insert-in-line '("foo") 0 1 "bar"))
;; Inserting text at the end of the first line
(test-equal "insert text and end of line"
  '("foobar") (strlist-insert-in-line '("foo") 0 3 "bar"))
;; Inserting text before the beginning of the second line
(test-equal "insert text before beginning of second line"
  '("foo" "bazbar") (strlist-insert-in-line '("foo" "bar") 1 0 "baz"))
;; Inserting text into the middle of the second line
(test-equal "insert text in middle of second line"
  '("foo" "bbazar") (strlist-insert-in-line '("foo" "bar") 1 1 "baz"))
;; Inserting text at the end of the second line
(test-equal "insert text at end of second line"
  '("foo" "barbaz") (strlist-insert-in-line '("foo" "bar") 1 3 "baz"))
;; Inserting text at the end of the list
(test-equal "insert text at end of stringlist"
  '("foo" "bar" "baz") (strlist-insert-in-line '("foo" "bar") 2 0 "baz"))

(test-end "t-gano-stringlist")
