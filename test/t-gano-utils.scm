(use-modules (srfi srfi-64)
             (gano utils))

(test-begin "t-gano-utils")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; count-cells-in-string

(define string-data-ascii               "abcdefghijklmnopqrstuvwxyz")
(define string-data-hanzi               "天地玄黃，宇宙洪荒。日月盈昃，辰宿列張。")

(test-equal "count-cells-in-string ascii"
  26
  (count-cells-in-string string-data-ascii))

(test-equal "count-cells-in-string hanzi"
  40
  (count-cells-in-string string-data-hanzi))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; count-cells-in-substring

(test-equal "count-cells-in-substring ascii 5"
  5
  (count-cells-in-substring string-data-ascii 5))

(test-equal "count-cells-in-substring hanzi 5"
  10
  (count-cells-in-substring string-data-hanzi 5))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; get-index-from-string-cell
(test-equal "get-index-from-string-cell ascii 0"
  0
  (get-index-from-string-cell string-data-ascii 0))

(test-equal "get-index-from-string-cell ascii 1"
  1
  (get-index-from-string-cell string-data-ascii 1))

(test-equal "get-index-from-string-cell ascii 10"
  10
  (get-index-from-string-cell string-data-ascii 10))

(test-equal "get-index-from-string-cell hanzi 0"
  0
  (get-index-from-string-cell string-data-hanzi 0))

(test-equal "get-index-from-string-cell hanzi 1"
  0
  (get-index-from-string-cell string-data-hanzi 1))

(test-equal "get-index-from-string-cell hanzi 10"
  5
  (get-index-from-string-cell string-data-hanzi 10))

(test-end "t-gano-utils")
