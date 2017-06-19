(use-modules (srfi srfi-64)
	     (gano stringlist))

(test-begin "t-gano-stringlist")

;; Inserting text into an empty strlist
(test-equal '("foo") (strlist-insert-in-line '() 0 0 "foo"))
;; Inserting text before the beginning of the first line
(test-equal '("barfoo") (strlist-insert-in-line '("foo") 0 0 "bar"))
;; Inserting text into the middle of the first line
(test-equal '("fbaroo") (strlist-insert-in-line '("foo") 0 1 "bar"))
;; Inserting text at the end of the first line
(test-equal '("foobar") (strlist-insert-in-line '("foo") 0 3 "bar"))
;; Inserting text before the beginning of the second line
(test-equal '("foo" "bazbar") (strlist-insert-in-line '("foo" "bar") 1 0 "baz"))
;; Inserting text into the middle of the second line
(test-equal '("foo" "bbazar") (strlist-insert-in-line '("foo" "bar") 1 1 "baz"))
;; Inserting text at the end of the second line
(test-equal '("foo" "barbaz") (strlist-insert-in-line '("foo" "bar") 1 3 "baz"))
;; Inserting text at the end of the list
(test-equal '("foo" "bar" "baz") (strlist-insert-in-line '("foo" "bar") 2 0 "baz"))

(test-end "t-gano-stringlist")
