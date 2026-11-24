(use-modules (srfi srfi-64)
             (gano chars))

(test-begin "t-gano-chars")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; is-ascii-control-char?

(test-assert "is-ascii-control-char? #\\null"
  (is-ascii-control-char? #\null))

(test-assert "is-ascii-control-char? #\\us"
  (is-ascii-control-char? #\us))

(test-equal "is-ascii-control-char? #\\space"
  #f
  (is-ascii-control-char? #\space))

(test-equal "is-ascii-control-char? #\\x80"
  #f
  (is-ascii-control-char? #\x80))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; is-control-char?

(test-assert "is-control-char? #\\null"
  (is-control-char? #\null))

(test-assert "is-control-char? #\\us"
  (is-control-char? #\us))

(test-equal "is-control-char? #\\space"
  #f
  (is-control-char? #\space))

(test-equal "is-control-char? #\\x80"
  #t
  (is-control-char? #\x80))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; is-blank-char?

(test-equal "is-blank-char? #\\tab"
  #t
  (is-blank-char? #\tab))

(test-equal "is-blank-char? #\\space"
  #t
  (is-blank-char? #\space))

(test-equal "is-blank-char? #\\null"
  #f
  (is-blank-char? #\null))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get-display-char-from-control-char

(test-equal "get-display-char-from-control-char #\\newline"
  #\J
  (get-display-char-from-control-char #\newline))

(test-equal "get-display-char-from-control-char #\\newline"
  #\I
  (get-display-char-from-control-char #\tab))

(test-equal "get-display-char-from-control-char #\\return"
  #\M
  (get-display-char-from-control-char #\return))

(test-equal "get-display-char-from-control-char C1 BPH"
  #\â
  (get-display-char-from-control-char #\xA2))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; count-cells-in-char

(test-equal "count-cells-in-char A"
  1
  (count-cells-in-char #\A))

;; Returns 2 because it assumes the string is "^M"
(test-equal "count-cells-in-char #\\return"
  2
  (count-cells-in-char #\return))

(test-equal "count-cells-in-char ⻤"
  2
  (count-cells-in-char #\⻤))

(test-equal "count-cells-in-char #\\tab"
  8
  (count-cells-in-char #\tab))

(test-equal "count-cells-in-char #\\tab from column 1"
  7
  (count-cells-in-char #\tab 1))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; compute-pp-list-from-string

(test-equal "compute-pp-list-from-string 'hello'"
  '(0 1 2 3 4 5)
  (compute-pp-list-from-string "hello"))

(test-equal "compute-pp-list-from-string TAB + 'hello'"
  '(0 8 9 10 11 12 13)
  (compute-pp-list-from-string "\thello"))

(test-equal "compute-pp-list-from-string 'foo' + TAB + 'bar'"
  '(0 1 2 3 8 9 10 11)
  (compute-pp-list-from-string "foo\tbar"))

(test-equal "compute-pp-list-from-string 'Duヅ'"
  '(0 1 2 4)
  (compute-pp-list-from-string "Duヅ"))

(test-end "t-gano-chars")

