;;; -*- mode: scheme; coding: utf-8; -*-

;;; test-string-split.scm
;;; Test suite for the string-split module using SRFI-64

(use-modules (srfi srfi-64)        ; Testing framework
             (gano string-split))   ; Module under test

;;; =================================================================
;;; TEST SUITE SETUP
;;; =================================================================

(test-begin "string-split")

;;; =================================================================
;;; HELPER FUNCTION TESTS
;;; =================================================================

(test-group "helper-functions"

  (test-group "string-find-string"
    (test-equal "find simple substring"
      2 (string-find-string "abcdef" "cd"))

    (test-equal "find at beginning"
      0 (string-find-string "hello" "he"))

    (test-equal "find at end"
      3 (string-find-string "hello" "lo"))

    (test-equal "not found"
      #f (string-find-string "hello" "xyz"))

    (test-equal "empty search string"
      0 (string-find-string "hello" ""))

    (test-equal "search longer than string"
      #f (string-find-string "hi" "hello"))

    (test-equal "find multi-char delimiter"
      5 (string-find-string "line1\r\nline2" "\r\n")))

  (test-group "string-char-positions"
    (test-equal "multiple occurrences"
      '(0 2 4) (string-char-positions "ababab" #\a))

    (test-equal "no occurrences"
      '() (string-char-positions "hello" #\x))

    (test-equal "single occurrence"
      '(0) (string-char-positions "abc" #\a))

    (test-equal "empty string"
      '() (string-char-positions "" #\a)))

  (test-group "string-join-with"
    (test-equal "join with comma"
      "a,b,c" (string-join-with '("a" "b" "c") ","))

    (test-equal "single element"
      "hello" (string-join-with '("hello") ","))

    (test-equal "empty list"
      "" (string-join-with '() ","))

    (test-equal "join with multi-char separator"
      "a::b::c" (string-join-with '("a" "b" "c") "::"))))

;;; =================================================================
;;; CORE SPLITTING FUNCTION TESTS
;;; =================================================================

(test-group "string-split-at-char"

  (test-equal "split on comma"
    '("apple" "banana" "cherry")
    (string-split-at-char "apple,banana,cherry" #\,))

  (test-equal "split with empty parts"
    '("a" "" "b")
    (string-split-at-char "a,,b" #\,))

  (test-equal "no delimiter"
    '("hello")
    (string-split-at-char "hello" #\,))

  (test-equal "empty string"
    '("")
    (string-split-at-char "" #\,))

  (test-equal "delimiter at start"
    '("" "hello")
    (string-split-at-char ",hello" #\,))

  (test-equal "delimiter at end"
    '("hello" "")
    (string-split-at-char "hello," #\,)))

(test-group "string-split-on-string"

  (test-equal "split on CRLF"
    '("line1" "line2" "line3")
    (string-split-on-string "line1\r\nline2\r\nline3" "\r\n"))

  (test-equal "split on multi-char delimiter"
    '("one" "two" "three")
    (string-split-on-string "one::two::three" "::"))

  (test-equal "single char optimization"
    '("a" "b" "c")
    (string-split-on-string "a,b,c" ","))

  (test-equal "empty delimiter"
    '("h" "e" "l" "l" "o")
    (string-split-on-string "hello" ""))

  (test-equal "delimiter not found"
    '("hello world")
    (string-split-on-string "hello world" "xyz"))

  (test-equal "empty string"
    '("")
    (string-split-on-string "" "::"))

  (test-equal "delimiter at boundaries"
    '("" "middle" "")
    (string-split-on-string "::middle::" "::")))

(test-group "string-split-on-any"

  (test-equal "multiple delimiters"
    '("a" "b" "c" "d")
    (string-split-on-any "a,b;c:d" '("," ";" ":")))

  (test-equal "prioritize longer delimiters"
    '("line1" "line2")
    (string-split-on-any "line1\r\nline2" '("\r\n" "\n")))

  (test-equal "mixed line endings"
    '("a" "b" "c" "d")
    (string-split-on-any "a\r\nb\nc\rd" '("\r\n" "\n" "\r")))

  (test-equal "no delimiters found"
    '("hello world")
    (string-split-on-any "hello world" '("," ";")))

  (test-equal "empty delimiter list"
    '("hello")
    (string-split-on-any "hello" '()))

  (test-equal "empty string"
    '("")
    (string-split-on-any "" '("," ";"))))

;;; =================================================================
;;; LINE ENDING UTILITIES TESTS
;;; =================================================================

(test-group "string-split-lines"

  (test-equal "Unix line endings"
    '("line1" "line2" "line3")
    (string-split-lines "line1\nline2\nline3"))

  (test-equal "Windows line endings"
    '("line1" "line2" "line3")
    (string-split-lines "line1\r\nline2\r\nline3"))

  (test-equal "Mac classic line endings"
    '("line1" "line2" "line3")
    (string-split-lines "line1\rline2\rline3"))

  (test-equal "Unicode line separators"
    '("line1" "line2" "line3")
    (string-split-lines "line1\u2028line2\u2029line3"))

  (test-equal "mixed line endings"
    '("line1" "line2" "line3" "line4")
    (string-split-lines "line1\r\nline2\nline3\rline4"))

  (test-equal "single line"
    '("hello world")
    (string-split-lines "hello world"))

  (test-equal "empty string"
    '("")
    (string-split-lines "")))

(test-group "string-detect-line-ending"

  (test-equal "Unix dominant"
    "\n"
    (string-detect-line-ending "line1\nline2\nline3\r\n"))

  (test-equal "Windows dominant"
    "\r\n"
    (string-detect-line-ending "line1\r\nline2\r\nline3\n"))

  (test-equal "Mac classic dominant"
    "\r"
    (string-detect-line-ending "line1\rline2\rline3\n"))

  (test-equal "Unicode line separator"
    "\u2028"
    (string-detect-line-ending "line1\u2028line2\u2028line3"))

  (test-equal "Unicode paragraph separator"
    "\u2029"
    (string-detect-line-ending "line1\u2029line2\u2029line3"))

  (test-equal "tie - LF wins (priority 1)"
    "\n"
    (string-detect-line-ending "line1\nline2\rline3"))

  (test-equal "tie - CRLF wins over CR (priority 2 vs 3)"
    "\r\n"
    (string-detect-line-ending "line1\r\nline2\rline3"))

  (test-equal "no line endings"
    "\n"
    (string-detect-line-ending "hello world"))

  (test-equal "empty string"
    "\n"
    (string-detect-line-ending ""))

  (test-equal "only CRLF"
    "\r\n"
    (string-detect-line-ending "line1\r\nline2\r\n"))

  (test-equal "complex priority test"
    "\n"
    (string-detect-line-ending "a\nb\r\nc\rd\u2028e\u2029f\ng"))  ; LF=2, others=1, LF wins

  (test-equal "CRLF vs others priority test"
    "\r\n"
    (string-detect-line-ending "a\r\nb\rc\u2028d\u2029e\r\nf")))  ; CRLF=2, others=1, CRLF wins

(test-group "string-normalize-line-endings"

  (test-equal "normalize to Unix"
    "line1\nline2\nline3"
    (string-normalize-line-endings "line1\r\nline2\rline3" "\n"))

  (test-equal "normalize to Windows"
    "line1\r\nline2\r\nline3"
    (string-normalize-line-endings "line1\nline2\rline3" "\r\n"))

  (test-equal "normalize to Mac classic"
    "line1\rline2\rline3"
    (string-normalize-line-endings "line1\nline2\r\nline3" "\r"))

  (test-equal "no line endings"
    "hello world"
    (string-normalize-line-endings "hello world" "\n"))

  (test-equal "already normalized"
    "line1\nline2\n"
    (string-normalize-line-endings "line1\nline2\n" "\n")))

;;; =================================================================
;;; EDGE CASES AND ERROR CONDITIONS
;;; =================================================================

(test-group "edge-cases"

  (test-equal "very long delimiter"
    '("start" "end")
    (string-split-on-string "start123456789end" "123456789"))

  (test-equal "delimiter longer than string"
    '("hi")
    (string-split-on-string "hi" "hello"))

  (test-equal "overlapping potential matches"
    '("" "a")
    (string-split-on-string "aaa" "aa"))

  (test-equal "string is just delimiter"
    '("" "") (string-split-on-string "::" "::"))

  (test-equal "repeated delimiters"
    '("" "" "")
    (string-split-on-string "::::" "::"))

  (test-equal "string is just delimiter"
    '("" "")
    (string-split-on-string "::" "::"))

  (test-equal "Unicode characters"
    '("α" "β" "γ")
    (string-split-on-string "α∘β∘γ" "∘")))

;;; =================================================================
;;; PERFORMANCE AND STRESS TESTS
;;; =================================================================

(test-group "stress-tests"

  (test-equal "many small parts"
    (make-list 1000 "x")
    (string-split-on-string (string-join-with (make-list 1000 "x") ",") ","))

  (test-equal "detect in text with many line endings"
    "\n"
    (string-detect-line-ending (string-join-with (make-list 100 "line") "\n")))

  (test-equal "large single part"
    (list (make-string 1000 #\a))
    (string-split-on-string (make-string 1000 #\a) ",")))

;;; =================================================================
;;; RUN TESTS
;;; =================================================================

;;; =================================================================
;;; STRICT TESTS
;;; =================================================================

(define (seconds thunk)
  (let ([t0 (get-internal-real-time)])
    (thunk)
    (/ (- (get-internal-real-time) t0) internal-time-units-per-second 1.0)))

(test-group "strict: string-split-at-char"
  (test-equal "only the delimiter" '("" "") (string-split-at-char "," #\,))
  (test-equal "only delimiters" '("" "" "") (string-split-at-char ",," #\,))
  (test-equal "non-ASCII delimiter" '("a" "b") (string-split-at-char "a\u00b7b" #\x00b7))
  (test-equal "N delimiters give N+1 pieces" 51
              (length (string-split-at-char (make-string 50 #\,) #\,)))
  (test-equal "join undoes split" "a,,b,c,"
              (string-join-with (string-split-at-char "a,,b,c," #\,) ",")))

(test-group "strict: string-split-on-string"
  (test-equal "empty string, empty delimiter" '("") (string-split-on-string "" ""))
  (test-equal "matches are non-overlapping, left to right" '("" "" "a")
              (string-split-on-string "aaaaa" "aa"))
  (test-equal "partial match at the end" '("ab" ":")
              (string-split-on-string "ab:::" "::"))
  (test-equal "join undoes split" "x::y::::z"
              (string-join-with (string-split-on-string "x::y::::z" "::") "::")))

(test-group "strict: string-split-on-any"
  (test-equal "earliest match wins over list order" '("a" "b" "c")
              (string-split-on-any "a;b,c" '("," ";")))
  (test-equal "at the same position, list order decides" '("a" "\nb")
              (string-split-on-any "a\r\nb" '("\r" "\r\n")))
  (test-equal "longer delimiter first takes it whole" '("a" "b")
              (string-split-on-any "a\r\nb" '("\r\n" "\r")))
  (test-equal "empty delimiters are ignored" '("a" "b")
              (string-split-on-any "a,b" '("" ",")))
  (test-equal "only empty delimiters: no split (and no hang)" '("abc")
              (string-split-on-any "abc" '("")))
  (test-equal "delimiter at the end" '("a" "")
              (string-split-on-any "a;" '(";")))
  (test-equal "adjacent delimiters" '("a" "" "b")
              (string-split-on-any "a;,b" '("," ";"))))

(test-group "strict: string-split-lines"
  (test-equal "trailing newline gives a final empty line" '("a" "")
              (string-split-lines "a\n"))
  (test-equal "just a newline" '("" "") (string-split-lines "\n"))
  (test-equal "CR then CRLF" '("" "" "") (string-split-lines "\r\r\n"))
  (test-equal "LF then CR are two endings" '("" "" "") (string-split-lines "\n\r"))
  (test-equal "CRLF then LF" '("" "" "") (string-split-lines "\r\n\n"))
  (test-equal "paragraph separator at end" '("a" "") (string-split-lines "a\u2029"))
  (test-equal "form feed is not a line ending" '("a\fb") (string-split-lines "a\fb"))
  (test-equal "NEL is not a line ending" '("a\x85b") (string-split-lines "a\x85b"))
  (test-equal "vertical tab is not a line ending" '("a\vb") (string-split-lines "a\vb")))

(test-group "strict: string-split-lines-with-final-newline-info"
  (test-equal "empty" '(("") . #f) (string-split-lines-with-final-newline-info ""))
  (test-equal "no ending" '(("a") . #f) (string-split-lines-with-final-newline-info "a"))
  (test-equal "LF" '(("a") . #t) (string-split-lines-with-final-newline-info "a\n"))
  (test-equal "CRLF" '(("a") . #t) (string-split-lines-with-final-newline-info "a\r\n"))
  (test-equal "CR" '(("a") . #t) (string-split-lines-with-final-newline-info "a\r"))
  (test-equal "LS" '(("a") . #t) (string-split-lines-with-final-newline-info "a\u2028"))
  (test-equal "PS" '(("a") . #t) (string-split-lines-with-final-newline-info "a\u2029"))
  (test-equal "just a newline is one empty line" '(("") . #t)
              (string-split-lines-with-final-newline-info "\n"))
  (test-equal "blank last line is kept" '(("a" "") . #t)
              (string-split-lines-with-final-newline-info "a\n\n"))
  (test-equal "several lines" '(("a" "b") . #f)
              (string-split-lines-with-final-newline-info "a\nb")))

(test-group "strict: string-normalize-line-endings"
  (test-equal "trailing ending is kept" "a\nb\n"
              (string-normalize-line-endings "a\r\nb\r\n" "\n"))
  (test-equal "to LS" "a\u2028b" (string-normalize-line-endings "a\nb" "\u2028"))
  (test-equal "empty" "" (string-normalize-line-endings "" "\r\n"))
  (test-equal "same as joining split lines" "x\ny\n\nz"
              (string-join-with (string-split-lines "x\ry\r\n\u2029z") "\n")))

(test-group "strict: shared helpers"
  (test-eq "string-find-string is string-utils'" (@ (gano string-utils) string-find-string)
           string-find-string)
  (test-eq "string-char-positions is string-utils'" (@ (gano string-utils) string-char-positions)
           string-char-positions)
  (test-eq "string-detect-line-ending is string-utils'" (@ (gano string-utils) string-detect-line-ending)
           string-detect-line-ending)
  (test-equal "join-with empty list" "" (string-join-with '() ","))
  (test-equal "join-with one item" "a" (string-join-with '("a") ",")))

(test-group "strict: linear time"
  (let ([text (string-join-with (make-list 50000 "some line of text") "\n")])
    (test-assert "split 50000 lines in under 2s"
                 (< (seconds (lambda () (string-split-lines text))) 2.0))
    (test-equal "into 50000 lines" 50000 (length (string-split-lines text)))
    (test-assert "split-on-any over 50000 lines in under 4s"
                 (< (seconds (lambda () (string-split-on-any text '("\r\n" "\n")))) 4.0))
    (test-assert "split-on-string over 50000 lines in under 2s"
                 (< (seconds (lambda () (string-split-on-string text "\n"))) 2.0))
    (test-assert "join 50000 lines in under 1s"
                 (< (seconds (lambda () (string-join-with (make-list 50000 "x") "\n"))) 1.0)))
  (test-assert "split-at-char on 100000 delimiters in under 2s"
               (< (seconds (lambda () (string-split-at-char (make-string 100000 #\,) #\,))) 2.0)))

(test-end "string-split")

;; Local Variables:
;; eval: (put 'test-group 'scheme-indent-function 1)
;; eval: (put 'test-assert 'scheme-indent-function 1)
;; eval: (put 'test-equal 'scheme-indent-function 1)
;; End:
