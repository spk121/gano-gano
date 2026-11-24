;;; Strict tests for (gano text-metrics), left-to-right layout.
;;;
;;; Terms used by the module:
;;;   x-index  index of a codepoint in the string
;;;   x-data   index of a base (non-combining) character
;;;   x-cell   terminal cell column; most characters take 1 cell, wide
;;;            (CJK) characters 2, combining marks 0 (they share their
;;;            base's cell) and a tab runs to the next tab stop.
;;;            Control characters take 1 cell and render as "?".

(define-module (test text-metrics)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-11)
  #:use-module (srfi srfi-64)
  #:use-module (gano text-metrics)
  #:use-module (gano rendering)
  #:use-module (gano wcwidth)
  #:use-module (ice-9 format))

(define (tm str . opts) (apply compute-text-metrics str 8 opts))
(define (positions str . opts)
  (text-metrics-cell-positions (apply tm str opts)))
(define* (render str start width #:key (pad? #t) (tabsize 8) (cjk? #f))
  (text-metrics-render-line-string-only
   (compute-text-metrics str tabsize #:cjk? cjk?) start width #:pad? pad?))

(define bold (make-sgr #:intensity 'intensity-bold))
(define default (make-default-sgr))
(define (bold? sgr) (eq? (sgr-intensity sgr) 'intensity-bold))
(define (all-default? sgrs) (every (lambda (s) (sgr-equal? s default)) sgrs))

(define (display-width str)
  "Cells STR occupies when printed (combining marks are 0)."
  (fold (lambda (ch acc) (+ acc (max 0 (wcwidth ch)))) 0 (string->list str)))

(test-begin "text-metrics")

;;; ---------------------------------------------------------------
(test-group "construction"
  (let ([m (tm "hello")])
    (test-assert "record" (text-metrics? m))
    (test-equal "string kept" "hello" (text-metrics-string m))
    (test-equal "tab size kept" 8 (text-metrics-tabsize m))
    (test-equal "cjk? defaults to #f" #f (text-metrics-cjk? m))
    (test-equal "one SGR per codepoint" 5 (length (text-metrics-sgr-list m)))
    (test-assert "SGRs are default" (all-default? (text-metrics-sgr-list m))))

  (test-equal "cjk? kept" #t (text-metrics-cjk? (tm "x" #:cjk? #t)))

  (let ([m (compute-text-metrics-with-sgr "ab" (list bold default) 4)])
    (test-assert "explicit SGRs kept" (bold? (car (text-metrics-sgr-list m))))
    (test-equal "explicit tab size" 4 (text-metrics-tabsize m)))

  (test-error "SGR list too short" #t (compute-text-metrics-with-sgr "ab" (list bold) 8))
  (test-error "SGR list too long" #t (compute-text-metrics-with-sgr "a" (list bold bold) 8))
  (test-error "tab size 0" #t (compute-text-metrics "a" 0))
  (test-error "negative tab size" #t (compute-text-metrics "a" -4))

  (let ([m (tm "")])
    (test-equal "empty: positions" '(0) (text-metrics-cell-positions m))
    (test-equal "empty: no base chars" '() (text-metrics-base-indices m))
    (test-equal "empty: cell length" 0 (text-metrics-cell-length m))))

;;; ---------------------------------------------------------------
(test-group "cell positions"
  (test-equal "ascii" '(0 1 2 3) (positions "abc"))
  (test-equal "wide" '(0 1 3 4) (positions "a日b"))
  (test-equal "all wide" '(0 2 4 6) (positions "日本語"))
  (test-equal "combining mark shares base's cell" '(0 0 1 2) (positions "éx"))
  (test-equal "two combining marks" '(0 0 0 1) (positions "é̈"))
  (test-equal "trailing combining mark" '(0 0 1) (positions "é"))
  (test-equal "combining after wide" '(0 0 2) (positions "日́"))
  (test-equal "lone tab" '(0 8) (positions "\t"))
  (test-equal "tab mid-line" '(0 1 8 9) (positions "a\tb"))
  (test-equal "trailing tab" '(0 1 2 3 4 5 8) (positions "abcde\t"))
  (test-equal "tab at a tab stop" '(0 1 2 3 4 5 6 7 8 16)
              (positions "abcdefgh\t"))
  (test-equal "consecutive tabs" '(0 8 16) (positions "\t\t"))
  (test-equal "tab after wide" '(0 2 8) (positions "日\t"))
  (test-equal "tab size 4" '(0 1 4 5)
              (text-metrics-cell-positions (compute-text-metrics "a\tb" 4)))
  (test-equal "ambiguous width, cjk? #f" '(0 1) (positions "±"))
  (test-equal "ambiguous width, cjk? #t" '(0 2) (positions "±" #:cjk? #t))
  (test-equal "control char is one cell" '(0 1 2 3) (positions "a\x01b"))
  (test-equal "DEL is one cell" '(0 1) (positions "\x7f"))
  (test-equal "C1 control is one cell" '(0 1) (positions "\x85"))
  (test-equal "zero-width space takes no cell" '(0 1 1 2) (positions "a​b"))
  ;; क + ि (U+093F, a spacing mark): one cluster, two cells
  (test-equal "spacing mark widens its cluster" '(0 0 2) (positions "\u0915\u093F"))
  (test-equal "spacing mark then next char" '(0 0 2 3) (positions "\u0915\u093Fx"))
  (test-equal "nonspacing and spacing marks" '(0 0 0 2) (positions "\u0915\u0301\u093F"))
  (test-equal "always one more position than codepoints"
              11 (length (positions "a日\tb́c\x01±de"))))

;;; ---------------------------------------------------------------
(test-group "base characters"
  (let ([m (tm "éẍ")])
    (test-equal "base indices" '(0 2) (text-metrics-base-indices m))
    (test-equal "string-base-indices" '(0 2) (text-metrics-string-base-indices m))
    (test-equal "string-base" "ex" (text-metrics-string-base m))
    (test-equal "base length" 2 (text-metrics-string-base-length m)))
  (test-equal "wide and tab are base chars" 3 (text-metrics-string-base-length (tm "日\tz"))))

;;; ---------------------------------------------------------------
(test-group "x-index <-> x-data"
  (let ([m (tm "éx")])            ; indices 0 1 2, bases at 0 and 2
    (test-equal "index 0" 0 (text-metrics-x-index->x-data m 0))
    (test-equal "index of combining mark counts its base" 1 (text-metrics-x-index->x-data m 1))
    (test-equal "index 2" 1 (text-metrics-x-index->x-data m 2))
    (test-equal "index = length" 2 (text-metrics-x-index->x-data m 3))
    (test-equal "index past end" #f (text-metrics-x-index->x-data m 4))
    (test-equal "negative index" #f (text-metrics-x-index->x-data m -1))

    (test-equal "data 0" 0 (text-metrics-x-data->x-index m 0))
    (test-equal "data 1" 2 (text-metrics-x-data->x-index m 1))
    (test-equal "data = base count is string length" 3 (text-metrics-x-data->x-index m 2))
    (test-equal "data past end" #f (text-metrics-x-data->x-index m 3))
    (test-equal "negative data" #f (text-metrics-x-data->x-index m -1)))

  (let ([m (tm "́a")])             ; leading combining mark
    (test-equal "leading mark: data 0 is index 0" 0 (text-metrics-x-data->x-index m 0))
    (test-equal "leading mark: one base" 1 (text-metrics-string-base-length m)))

  (let ([m (tm "")])
    (test-equal "empty: data 0" 0 (text-metrics-x-data->x-index m 0))
    (test-equal "empty: index 0" 0 (text-metrics-x-index->x-data m 0))
    (test-equal "empty: data 1" #f (text-metrics-x-data->x-index m 1))))

;;; ---------------------------------------------------------------
(test-group "to cells"
  (let ([m (tm "a日b")])
    (test-equal "index->cell" '(0 1 3 4)
                (map (lambda (i) (text-metrics-x-index->x-cell m i)) '(0 1 2 3)))
    (test-equal "index->cell past end" #f (text-metrics-x-index->x-cell m 4))
    (test-equal "index->cell negative" #f (text-metrics-x-index->x-cell m -1))
    (test-equal "data->cell" '(0 1 3 4)
                (map (lambda (d) (text-metrics-x-data->x-cell m d)) '(0 1 2 3)))
    (test-equal "data->cell past end" #f (text-metrics-x-data->x-cell m 4))
    (test-equal "data->cell negative" #f (text-metrics-x-data->x-cell m -1))
    (test-equal "cell length" 4 (text-metrics-cell-length m)))
  (test-equal "data->cell skips combining marks" 1
              (text-metrics-x-data->x-cell (tm "éx") 1))
  (test-equal "empty data->cell 0" 0 (text-metrics-x-data->x-cell (tm "") 0)))

;;; ---------------------------------------------------------------
(test-group "from cells"
  (let ([m (tm "\u0915\u093Fx")])
    (test-equal "both cells of a spacing-mark cluster map to its base" '(0 0 2 3)
                (map (lambda (c) (text-metrics-x-cell->x-index m c)) '(0 1 2 3))))
  ;; A cell maps to the base character drawn over it.
  (let ([m (tm "a日b")])            ; a:0  日:1-2  b:3  end:4
    (test-equal "cell->index" '(0 1 1 2 3)
                (map (lambda (c) (text-metrics-x-cell->x-index m c)) '(0 1 2 3 4)))
    (test-equal "cell->data" '(0 1 1 2 3)
                (map (lambda (c) (text-metrics-x-cell->x-data m c)) '(0 1 2 3 4)))
    (test-equal "cell past end" #f (text-metrics-x-cell->x-index m 5))
    (test-equal "negative cell" #f (text-metrics-x-cell->x-index m -1)))
  (let ([m (tm "a\tb")])                ; a:0  tab:1-7  b:8  end:9
    (test-equal "cells inside a tab map to the tab" '(1 1 1 1 1 1 1)
                (map (lambda (c) (text-metrics-x-cell->x-index m c)) '(1 2 3 4 5 6 7)))
    (test-equal "after the tab" '(2 3)
                (map (lambda (c) (text-metrics-x-cell->x-index m c)) '(8 9))))
  (let ([m (tm "éx")])
    (test-equal "cell maps to the base, not its combining mark" 0
                (text-metrics-x-cell->x-index m 0))
    (test-equal "next base" 2 (text-metrics-x-cell->x-index m 1))
    (test-equal "end" 3 (text-metrics-x-cell->x-index m 2)))
  (let ([m (tm "a​b")])            ; zero-width base shares b's cell
    (test-equal "zero-width char: first codepoint at the cell" 1
                (text-metrics-x-cell->x-index m 1)))
  (test-equal "empty: cell 0" 0 (text-metrics-x-cell->x-index (tm "") 0))
  (test-equal "empty: cell 1" #f (text-metrics-x-cell->x-index (tm "") 1))
  ;; round trip for every base character
  (let* ([s "x日\tq́éz"] [m (tm s)])
    (test-assert "data -> cell -> data round trip"
                 (every (lambda (d)
                          (= d (text-metrics-x-cell->x-data m (text-metrics-x-data->x-cell m d))))
                        (iota (+ 1 (text-metrics-string-base-length m)))))))

;;; ---------------------------------------------------------------
(test-group "SGR access"
  (let ([m (compute-text-metrics-with-sgr "a日b" (list default bold default) 8)])
    (test-assert "at index" (bold? (text-metrics-get-sgr-at-index m 1)))
    (test-assert "at data" (bold? (text-metrics-get-sgr-at-data m 1)))
    (test-assert "at cell (second half of wide char)" (bold? (text-metrics-get-sgr-at-cell m 2)))
    (test-assert "at cell before" (not (bold? (text-metrics-get-sgr-at-cell m 0))))
    (test-assert "out of range index gives default"
                 (sgr-equal? default (text-metrics-get-sgr-at-index m 99)))
    (test-assert "negative index gives default"
                 (sgr-equal? default (text-metrics-get-sgr-at-index m -1)))
    (test-assert "out of range data gives default"
                 (sgr-equal? default (text-metrics-get-sgr-at-data m 99)))
    (test-assert "out of range cell gives default"
                 (sgr-equal? default (text-metrics-get-sgr-at-cell m 99)))))

(test-group "SGR updates are non-destructive"
  (let* ([m (tm "abcd")]
         [m1 (text-metrics-set-sgr-at-index m 1 bold)])
    (test-assert "new record has it" (bold? (list-ref (text-metrics-sgr-list m1) 1)))
    (test-assert "original untouched" (all-default? (text-metrics-sgr-list m)))
    (test-eq "invalid index returns the same record" m (text-metrics-set-sgr-at-index m 9 bold))
    (test-eq "negative index returns the same record" m (text-metrics-set-sgr-at-index m -1 bold)))
  (let ([m (text-metrics-set-sgr-at-data (tm "éx") 1 bold)])
    (test-equal "set at data uses the base's index" '(#f #f #t)
                (map bold? (text-metrics-sgr-list m))))
  (let ([m (text-metrics-set-sgr-range (tm "abcdef") 1 4 bold)])
    (test-equal "range" '(#f #t #t #t #f #f) (map bold? (text-metrics-sgr-list m))))
  (let ([m (text-metrics-set-sgr-range (tm "abc") -5 99 bold)])
    (test-equal "range is clamped" '(#t #t #t) (map bold? (text-metrics-sgr-list m))))
  (let ([m (tm "abc")])
    (test-eq "empty range is a no-op" m (text-metrics-set-sgr-range m 2 2 bold))
    (test-eq "reversed range is a no-op" m (text-metrics-set-sgr-range m 2 1 bold)))
  (let* ([m (compute-text-metrics-with-sgr "abc" (list bold bold default) 8)]
         [copy (text-metrics-copy-sgr-range m 0 2)])
    (test-equal "copy range" '(#t #t) (map bold? copy))
    (test-assert "copies are fresh records" (not (eq? (car copy) (car (text-metrics-sgr-list m)))))
    (test-equal "copy clamped" 3 (length (text-metrics-copy-sgr-range m -1 10)))
    (test-equal "copy reversed range is empty" '() (text-metrics-copy-sgr-range m 2 1)))
  (let* ([m (compute-text-metrics-with-sgr "ab" (list bold default) 8)])
    (test-equal "propagate" '(#t #t)
                (map bold? (text-metrics-sgr-list (text-metrics-propagate-sgr m 0 1))))
    (test-equal "inherit for combining" '(#t #t)
                (map bold? (text-metrics-sgr-list (text-metrics-inherit-sgr-for-combining m 0 1))))
    (test-assert "default for range"
                 (all-default? (text-metrics-sgr-list (text-metrics-default-sgr-for-range m 0 2))))))

;;; ---------------------------------------------------------------
(test-group "modification"
  (let* ([m (tm "ac")]
         [m1 (text-metrics-insert-char-with-sgr m 1 #\b bold)])
    (test-equal "insert char" "abc" (text-metrics-string m1))
    (test-equal "with its SGR" '(#f #t #f) (map bold? (text-metrics-sgr-list m1)))
    (test-equal "positions recomputed" '(0 1 2 3) (text-metrics-cell-positions m1))
    (test-equal "original untouched" "ac" (text-metrics-string m)))
  (test-equal "insert at start" "xab"
              (text-metrics-string (text-metrics-insert-char-with-sgr (tm "ab") 0 #\x bold)))
  (test-equal "insert at end" "abx"
              (text-metrics-string (text-metrics-insert-char-with-sgr (tm "ab") 2 #\x bold)))
  (test-error "insert past end" #t (text-metrics-insert-char-with-sgr (tm "ab") 3 #\x bold))
  (test-equal "insert keeps tab size and cjk"
              '(4 #t)
              (let ([m (text-metrics-insert-char-with-sgr (compute-text-metrics "a" 4 #:cjk? #t) 0 #\x bold)])
                (list (text-metrics-tabsize m) (text-metrics-cjk? m))))

  (let ([m (text-metrics-insert-string-with-sgr (tm "ad") 1 "bc" (list bold bold))])
    (test-equal "insert string" "abcd" (text-metrics-string m))
    (test-equal "with its SGRs" '(#f #t #t #f) (map bold? (text-metrics-sgr-list m))))
  (test-error "insert string with wrong SGR count" #t
              (text-metrics-insert-string-with-sgr (tm "ad") 1 "bc" (list bold)))

  (let ([m (text-metrics-delete-range (compute-text-metrics-with-sgr "abcd" (list default bold bold default) 8) 1 3)])
    (test-equal "delete range" "ad" (text-metrics-string m))
    (test-assert "SGRs deleted with it" (all-default? (text-metrics-sgr-list m))))
  (test-equal "delete clamps" "" (text-metrics-string (text-metrics-delete-range (tm "abc") -2 10)))
  (test-equal "delete empty range" "abc" (text-metrics-string (text-metrics-delete-range (tm "abc") 1 1)))

  (let ([m (text-metrics-replace-range (tm "abcd") 1 3 "XYZ" (list bold bold bold))])
    (test-equal "replace range" "aXYZd" (text-metrics-string m))
    (test-equal "with its SGRs" '(#f #t #t #t #f) (map bold? (text-metrics-sgr-list m))))
  (test-error "replace with wrong SGR count" #t
              (text-metrics-replace-range (tm "abcd") 1 3 "XY" (list bold))))

;;; ---------------------------------------------------------------
(test-group "rendering"
  (test-equal "whole line, padded" "abc  " (render "abc" 0 5))
  (test-equal "whole line, unpadded" "abc" (render "abc" 0 5 #:pad? #f))
  (test-equal "window into the line" "cde" (render "abcdef" 2 3))
  (test-equal "exact fit" "abc" (render "abc" 0 3))
  (test-equal "start past end, padded" "   " (render "abc" 5 3))
  (test-equal "start past end, unpadded" "" (render "abc" 5 3 #:pad? #f))
  (test-equal "zero width" "" (render "abc" 0 0))
  (test-equal "empty line" "    " (render "" 0 4))

  ;; tabs
  (test-equal "tab expands to the tab stop" "a       b " (render "a\tb" 0 10))
  (test-equal "tab cut off at the right edge" "a   " (render "a\tb" 0 4))
  (test-equal "tab cut off at the left edge" "     b" (render "a\tb" 3 6))
  (test-equal "tab stops are absolute when scrolled" "b      cd " (render "ab\tcd" 1 10))
  (test-equal "tab size 4" "a   b" (render "a\tb" 0 5 #:tabsize 4))

  ;; wide characters
  (test-equal "wide chars" "日本" (render "日本" 0 4))
  (test-equal "wide char cut off at the right edge becomes a space" "日 "
              (render "日本語" 0 3))
  (test-equal "wide char cut off at the left edge becomes a space" " 本 "
              (render "日本語" 1 4))
  (test-equal "ambiguous width with cjk? #t" "\u00b1" (render "\u00b1x" 0 2 #:cjk? #t))
  (test-equal "ambiguous width with cjk? #f" "\u00b1x" (render "\u00b1x" 0 2))

  ;; combining marks and control characters
  (test-equal "combining marks kept with their base" "éx " (render "éx" 0 3))
  (test-equal "combining mark dropped with its base" "x" (render "éx" 1 1))
  (test-equal "control characters shown as ?" "a?b" (render "a\x01b" 0 3))

  (test-equal "cluster with a spacing mark" "\u0915\u093F " (render "\u0915\u093F" 0 3))
  (test-equal "cluster with a spacing mark cut at the right edge" "a " (render "a\u0915\u093F" 0 2))
  (test-equal "cluster with a spacing mark cut at the left edge" " x" (render "\u0915\u093Fx" 1 2))
  ;; SGR list follows the rendered codepoints
  (let-values ([(str sgrs)
                (text-metrics-render-line
                 (compute-text-metrics-with-sgr "a\tb" (list default bold default) 8) 0 10)])
    (test-equal "one SGR per rendered codepoint" (string-length str) (length sgrs))
    (test-equal "tab's spaces carry the tab's SGR" '(#f #t #t #t #t #t #t #t #f #f)
                (map bold? sgrs)))
  (let-values ([(str sgrs)
                (text-metrics-render-line
                 (compute-text-metrics-with-sgr "日本" (list bold default) 8) 1 3)])
    (test-equal "half-wide space keeps that char's SGR" '(#t #f) (map bold? sgrs))
    (test-equal "and the string matches" " 本" str))

  ;; Every padded render fills exactly the requested width.
  (let ([samples '("" "abc" "a\tb\tc" "日本語" "é̈x日\t!"
                   "\t日á\x01b" "x±y")])
    (test-assert "rendered width always equals the window width"
                 (every (lambda (s)
                          (every (lambda (start)
                                   (every (lambda (w)
                                            (= w (display-width (render s start w))))
                                          (iota 12)))
                                 (iota 12)))
                        samples))))

(test-group "spans"
  (let ([m (compute-text-metrics-with-sgr "aabb" (list bold bold default default) 8)])
    (let ([spans (text-metrics-render-line-with-sgr m 0 6)])
      (test-equal "render spans: text" '("aa" "bb  ") (map car spans))
      (test-equal "render spans: attributes" '(#t #f) (map (lambda (s) (bold? (cdr s))) spans)))
    (let ([spans (text-metrics-get-rendered-spans m)])
      (test-equal "whole-line spans" '("aa" "bb") (map car spans))))
  (test-equal "no spans for an empty render" '() (text-metrics-render-line-with-sgr (tm "") 0 0))
  (test-equal "no spans for an empty line" '() (text-metrics-get-rendered-spans (tm ""))))

;;; ---------------------------------------------------------------
(test-group "long lines"
  ;; Building metrics should be linear, not quadratic, in line length.
  (let* ([s (make-string 20000 #\a)]
         [t0 (get-internal-real-time)]
         [m (tm s)]
         [secs (/ (- (get-internal-real-time) t0) internal-time-units-per-second 1.0)])
    (test-equal "20000-char line" 20000 (text-metrics-cell-length m))
    (test-assert (format #f "built in under 2s (took ~,2fs)" secs) (< secs 2.0))))

(test-end "text-metrics")
