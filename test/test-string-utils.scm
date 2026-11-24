;;; -*- mode: scheme; coding: utf-8; -*-

;;; Test Suite for Gano String Utilities Module
;;; Uses SRFI-64 testing framework

(use-modules (srfi srfi-64)
             (ice-9 regex)
             (gano string-utils))

(test-begin "string-utils")

;;; =================================================================
;;; BASIC STRING MANIPULATION TESTS
;;; =================================================================

(test-group "string-insert-char"
  (test-equal "insert at beginning"
    "xhello" (string-insert-char "hello" 0 #\x))
  
  (test-equal "insert in middle"
    "helxlo" (string-insert-char "hello" 3 #\x))
  
  (test-equal "insert at end"
    "hellox" (string-insert-char "hello" 5 #\x))
  
  (test-equal "insert beyond end"
    "hellox" (string-insert-char "hello" 10 #\x))
  
  (test-equal "insert at negative index"
    "xhello" (string-insert-char "hello" -1 #\x))
  
  (test-equal "insert in empty string"
    "x" (string-insert-char "" 0 #\x)))

(test-group "string-insert-string"
  (test-equal "insert string at beginning"
    "xyzhello" (string-insert-string "hello" 0 "xyz"))
  
  (test-equal "insert string in middle"
    "helxyzlo" (string-insert-string "hello" 3 "xyz"))
  
  (test-equal "insert string at end"
    "helloxyz" (string-insert-string "hello" 5 "xyz"))
  
  (test-equal "insert string beyond end"
    "helloxyz" (string-insert-string "hello" 10 "xyz"))
  
  (test-equal "insert string at negative index"
    "xyzhello" (string-insert-string "hello" -1 "xyz"))
  
  (test-equal "insert empty string"
    "hello" (string-insert-string "hello" 2 ""))
  
  (test-equal "insert into empty string"
    "xyz" (string-insert-string "" 0 "xyz")))

(test-group "string-delete-range"
  (test-equal "delete from beginning"
    "lo" (string-delete-range "hello" 0 3))
  
  (test-equal "delete from middle"
    "heo" (string-delete-range "hello" 2 4))
  
  (test-equal "delete to end"
    "hel" (string-delete-range "hello" 3 5))
  
  (test-equal "delete beyond end"
    "hel" (string-delete-range "hello" 3 10))
  
  (test-equal "delete with negative start"
    "llo" (string-delete-range "hello" -1 2))
  
  (test-equal "delete with start beyond length"
    "hello" (string-delete-range "hello" 10 15))
  
  (test-equal "delete with start >= end"
    "hello" (string-delete-range "hello" 3 2))
  
  (test-equal "delete entire string"
    "" (string-delete-range "hello" 0 5))
  
  (test-equal "delete from empty string"
    "" (string-delete-range "" 0 1)))

(test-group "string-replace-range"
  (test-equal "replace from beginning"
    "xyzlo" (string-replace-range "hello" 0 3 "xyz"))
  
  (test-equal "replace in middle"
    "hexyz" (string-replace-range "hello" 2 5 "xyz"))
  
  (test-equal "replace with longer string"
    "hxyzabco" (string-replace-range "hello" 1 4 "xyzabc"))
  
  (test-equal "replace with shorter string"
    "hxo" (string-replace-range "hello" 1 4 "x"))
  
  (test-equal "replace with empty string"
    "ho" (string-replace-range "hello" 1 4 ""))
  
  (test-equal "replace beyond end (append)"
    "helloxyz" (string-replace-range "hello" 10 15 "xyz"))
  
  (test-equal "replace with invalid range (insert)"
    "helxyzlo" (string-replace-range "hello" 3 2 "xyz"))
  
  (test-equal "replace entire string"
    "xyz" (string-replace-range "hello" 0 5 "xyz")))

(test-group "string-replace-char"
  (test-equal "replace first char"
    "xello" (string-replace-char "hello" 0 #\x))
  
  (test-equal "replace middle char"
    "helxo" (string-replace-char "hello" 3 #\x))
  
  (test-equal "replace last char"
    "hellx" (string-replace-char "hello" 4 #\x))
  
  (test-equal "replace out of bounds"
    "hello" (string-replace-char "hello" 10 #\x))
  
  (test-equal "replace negative index"
    "hello" (string-replace-char "hello" -1 #\x)))

;;; =================================================================
;;; CHARACTER-BASED OPERATIONS TESTS
;;; =================================================================

(test-group "string-update-char"
  (test-equal "update char (alias test)"
    "xello" (string-update-char "hello" 0 #\x)))

(test-group "string-set-char"
  (test-equal "set existing char"
    "xello" (string-set-char "hello" 0 #\x))
  
  (test-equal "set char beyond string (extend)"
    "hello   x" (string-set-char "hello" 8 #\x))
  
  (test-equal "set char at negative index"
    "hello" (string-set-char "hello" -1 #\x))
  
  (test-equal "set char in empty string"
    " x" (string-set-char "" 1 #\x)))

(test-group "string-swap-chars"
  (test-equal "swap first and last"
    "oellh" (string-swap-chars "hello" 0 4))
  
  (test-equal "swap adjacent chars"
    "ehllo" (string-swap-chars "hello" 0 1))
  
  (test-equal "swap same index"
    "hello" (string-swap-chars "hello" 2 2))
  
  (test-equal "swap out of bounds"
    "hello" (string-swap-chars "hello" 0 10))
  
  (test-equal "swap negative index"
    "hello" (string-swap-chars "hello" -1 2)))

;;; =================================================================
;;; MULTI-OPERATION UTILITIES TESTS
;;; =================================================================

(test-group "string-apply-operations"
  (test-equal "single insert operation"
    "hxello" (string-apply-operations "hello" '((insert 1 #\x))))
  
  (test-equal "single delete operation"
    "hlo" (string-apply-operations "hello" '((delete 1 3))))
  
  (test-equal "single replace operation"
    "hxyzo" (string-apply-operations "hello" '((replace 1 4 "xyz"))))
  
  (test-equal "single update operation"
    "hxllo" (string-apply-operations "hello" '((update 1 #\x))))
  
  (test-equal "multiple operations (right to left)"
    "hyexlo" (string-apply-operations "hello" 
				      '((insert 1 #\y) (update 2 #\x))))
  
  (test-equal "complex operations sequence"
    "hxabc" (string-apply-operations "hello" 
				     '((delete 2 5) (insert 2 "abc") (update 1 #\x)))))

(test-group "string-insert-multiple"
  (test-equal "insert nothing"
    "hello" (string-insert-multiple "hello" '()))

  (test-equal "insert at index 0"
    "|hello" (string-insert-multiple "hello" '((0 . #\|))))

  (test-equal "insert at index 1"
    "h|ello" (string-insert-multiple "hello" '((1 . #\|))))

  (test-equal "insert at index 2"
    "he|llo" (string-insert-multiple "hello" '((2 . #\|))))

  (test-equal "insert at index 5"
    "hello|" (string-insert-multiple "hello" '((5 . #\|))))

  (test-equal "insert at index 0 then 0"
    "|:hello" (string-insert-multiple "hello" '((0 . #\|) (0 . #\:))))

  (test-equal "insert at index 1 then 0"
    ":h|ello" (string-insert-multiple "hello" '((1 . #\|) (0 . #\:))))

  (test-equal "insert at index 2 then 2"
    "he|:llo" (string-insert-multiple "hello" '((2 . #\|) (2 . #\:))))

  (test-equal "insert at index 5 then 3"
    "hel:lo|" (string-insert-multiple "hello" '((5 . #\|) (3 . #\:))))

  (test-equal "insert multiple chars"
    "hxelyloz" (string-insert-multiple "hello" '((1 . #\x) (3 . #\y) (5 . #\z))))
  
  (test-equal "insert multiple strings"
    "habcellxyzo" (string-insert-multiple "hello" '((1 . "abc") (4 . "xyz"))))
  
  (test-equal "insert mixed chars and strings"
    "hxeabcllo" (string-insert-multiple "hello" '((1 . #\x) (2 . "abc")))))

(test-group "string-insert-multiple-errors"
  (test-error "negative index"
	      (string-insert-multiple "hello" '((-1 . #\x))))
  
  (test-error "multiple negative indices"
	      (string-insert-multiple "hello" '((-1 . #\x) (-2 . #\y)))))

(test-group "string-replace-multiple"
  (test-equal "replace multiple ranges"
    "hxyzo " (string-replace-multiple "hello world" 
				      '((1 4 "xyz") (6 11 ""))))

  (test-equal "replace adjacent ranges"
    "habco" (string-replace-multiple "hello" 
				     '((1 2 "a") (2 4 "bc")))))

(test-group "string-replace-multiple-errors"
  (test-error "overlapping ranges" 
	      (string-replace-multiple "hello" '((1 3 "xy") (2 4 "zw"))))
  
  (test-error "end index out of bounds" 
	      (string-replace-multiple "hello" '((3 10 "xyz"))))
  
  (test-error "negative start index"
	      (string-replace-multiple "hello" '((-1 2 "xyz"))))
  
  (test-error "start greater than end"
	      (string-replace-multiple "hello" '((3 1 "xyz"))))
  
  (test-error "multiple overlapping ranges"
	      (string-replace-multiple "hello" '((1 3 "a") (2 4 "b") (5 6 "c")))))

;;; =================================================================
;;; SAFE ACCESSORS TESTS
;;; =================================================================

(test-group "string-ref-safe"
  (test-equal "valid index"
    #\e (string-ref-safe "hello" 1 #\?))
  
  (test-equal "negative index"
    #\? (string-ref-safe "hello" -1 #\?))
  
  (test-equal "beyond bounds"
    #\? (string-ref-safe "hello" 10 #\?))
  
  (test-equal "empty string"
    #\? (string-ref-safe "" 0 #\?)))

(test-group "string-char-at"
  (test-equal "valid index"
    #\e (string-char-at "hello" 1))
  
  (test-equal "negative index"
    #f (string-char-at "hello" -1))
  
  (test-equal "beyond bounds"
    #f (string-char-at "hello" 10))
  
  (test-equal "empty string"
    #f (string-char-at "" 0)))

;;; =================================================================
;;; FUNCTIONAL BUILDERS TESTS
;;; =================================================================

(test-group "string-from-chars"
  (test-equal "build from char list"
    "hello" (string-from-chars '(#\h #\e #\l #\l #\o)))
  
  (test-equal "build from empty list"
    "" (string-from-chars '()))
  
  (test-equal "build from single char"
    "x" (string-from-chars '(#\x))))

(test-group "string-repeat-char"
  (test-equal "repeat char multiple times"
    "xxxxx" (string-repeat-char #\x 5))
  
  (test-equal "repeat char zero times"
    "" (string-repeat-char #\x 0))
  
  (test-equal "repeat char once"
    "x" (string-repeat-char #\x 1)))

(test-group "string-pad-to-length"
  (test-equal "pad short string"
    "hello   " (string-pad-to-length "hello" 8 #\space))
  
  (test-equal "pad to same length"
    "hello" (string-pad-to-length "hello" 5 #\space))
  
  (test-equal "pad longer string (no change)"
    "hello world" (string-pad-to-length "hello world" 5 #\space))
  
  (test-equal "pad empty string"
    "   " (string-pad-to-length "" 3 #\space))
  
  (test-equal "pad with custom char"
    "helloxxx" (string-pad-to-length "hello" 8 #\x)))

;;; =================================================================
;;; ANALYSIS UTILITIES TESTS
;;; =================================================================

(test-group "string-char-positions"
  (test-equal "find multiple occurrences"
    '(1 2 3) (string-char-positions "hlll" #\l))
  
  (test-equal "find single occurrence"
    '(1) (string-char-positions "hello" #\e))
  
  (test-equal "find no occurrences"
    '() (string-char-positions "hello" #\x))
  
  (test-equal "find in empty string"
    '() (string-char-positions "" #\x))
  
  (test-equal "find all same chars"
    '(0 1 2) (string-char-positions "xxx" #\x)))

(test-group "string-find-char"
  (test-equal "find existing char"
    1 (string-find-char "hello" #\e))
  
  (test-equal "find first occurrence"
    2 (string-find-char "hello" #\l))
  
  (test-equal "find non-existing char"
    #f (string-find-char "hello" #\x))
  
  (test-equal "find in empty string"
    #f (string-find-char "" #\x)))

(test-group "string-find-string"
  (test-equal "find existing substring"
    1 (string-find-string "hello world" "ello"))
  
  (test-equal "find at beginning"
    0 (string-find-string "hello world" "hello"))
  
  (test-equal "find at end"
    6 (string-find-string "hello world" "world"))
  
  (test-equal "find non-existing substring"
    #f (string-find-string "hello world" "xyz"))
  
  (test-equal "find longer substring"
    #f (string-find-string "hello" "hello world"))
  
  (test-equal "find empty substring"
    0 (string-find-string "hello" ""))
  
  (test-equal "find in empty string"
    #f (string-find-string "" "hello"))
  
  (test-equal "find empty in empty"
    0 (string-find-string "" "")))

(test-group "string-count-char"
  (test-equal "count multiple occurrences"
    2 (string-count-char "hello" #\l))
  
  (test-equal "count single occurrence"
    1 (string-count-char "hello" #\h))
  
  (test-equal "count no occurrences"
    0 (string-count-char "hello" #\x))
  
  (test-equal "count in empty string"
    0 (string-count-char "" #\x))
  
  (test-equal "count all same chars"
    5 (string-count-char "aaaaa" #\a)))

(test-group "line-ending-detection"
  (test-group "string-detect-line-ending"
    (test-assert "string-detect-line-ending is callable"
      (procedure? string-detect-line-ending))
    
    ;; Basic functionality tests
    (test-equal "Unix line ending" "\n" (string-detect-line-ending "line1\nline2\n"))
    (test-equal "Windows line ending" "\r\n" (string-detect-line-ending "line1\r\nline2\r\n"))
    (test-equal "Mac line ending" "\r" (string-detect-line-ending "line1\rline2\r"))
    (test-equal "No line ending defaults to LF" "\n" (string-detect-line-ending "single line"))
    
    ;; Edge cases
    (test-equal "Mixed line endings prefers most common" "\n" (string-detect-line-ending "line1\nline2\r\nline3\n"))
    (test-equal "Empty string defaults to LF" "\n" (string-detect-line-ending ""))
    (test-equal "Single newline" "\n" (string-detect-line-ending "\n"))
    (test-equal "Single CRLF" "\r\n" (string-detect-line-ending "\r\n"))
    
    ;; Unicode line separators
    (test-equal "Line separator" "\u2028" (string-detect-line-ending "line1\u2028line2\u2028"))
    (test-equal "Paragraph separator" "\u2029" (string-detect-line-ending "line1\u2029line2\u2029"))
    
    ;; Tie-breaking priority (LF wins ties)
    (test-equal "LF vs CRLF tie goes to LF" "\n" (string-detect-line-ending "a\nb\r\nc"))
    (test-equal "Complex tie scenario" "\n" (string-detect-line-ending "a\nb\r\nc\rd\u2028e\u2029f"))))


;;; =================================================================
;;; UNICODE-AWARE UTILITIES TESTS
;;; =================================================================

(test-group "string-map-with-index"
  (test-equal "map with index (uppercase if even index)"
    "HeLlO" (string-map-with-index 
	     (lambda (char index)
	       (if (even? index)
		   (char-upcase char)
		   char))
	     "hello"))
  
  (test-equal "map with index (add index to char code)"
    "hfnos" (string-map-with-index 
	     (lambda (char index)
	       (integer->char (+ (char->integer char) index)))
	     "hello"))
  
  (test-equal "map empty string"
    "" (string-map-with-index 
	(lambda (char index) char)
	""))
  
  (test-equal "map single char"
    "H" (string-map-with-index 
	 (lambda (char index) (char-upcase char))
	 "h")))

;;; =================================================================
;;; EDGE CASES AND STRESS TESTS
;;; =================================================================

(test-group "edge-cases"
  (test-equal "operations on empty strings"
    "x" (string-insert-char "" 0 #\x))
  
  (test-equal "operations with unicode characters"
    "h€llo" (string-insert-char "hllo" 1 #\€))
  
  (test-equal "very large indices"
    "hellox" (string-insert-char "hello" 999999 #\x))
  
  (test-equal "chain multiple operations"
    "Hxello" 
    (string-update-char 
     (string-insert-char 
      (string-delete-range "hello world" 5 11) 1 #\x) 0 #\H)))

(test-group "consistency-checks"
  (test-equal "insert then delete should be identity (when possible)"
    "hello" 
    (string-delete-range 
     (string-insert-char "hello" 2 #\x) 2 3))
  
  (test-equal "multiple char positions should match single finds"
    (string-find-char "hello world" #\l)
    (car (string-char-positions "hello world" #\l))))

;;; =================================================================
;;; GRAPHEME-AWARE SEARCH (strict)
;;; =================================================================
;;; A grapheme boundary is any position that is not just before a
;;; combining mark.  Matches must start and end on boundaries of the
;;; whole string.

(test-group "string-grapheme-boundary?"
  (test-assert "start of string" (string-grapheme-boundary? "éx" 0))
  (test-assert "before a combining mark is not" (not (string-grapheme-boundary? "éx" 1)))
  (test-assert "after the cluster" (string-grapheme-boundary? "éx" 2))
  (test-assert "end of string" (string-grapheme-boundary? "éx" 3))
  (test-assert "before a space" (string-grapheme-boundary? "a b" 1))
  (test-assert "before a tab" (string-grapheme-boundary? "a\tb" 1))
  (test-assert "before a control char" (string-grapheme-boundary? "a\x01" 1))
  (test-assert "before a wide char" (string-grapheme-boundary? "a日" 1)))

(test-group "string-contains-graphemes"
  (test-equal "followed by a space" 0 (string-contains-graphemes "say hi" "say"))
  (test-equal "preceded by a space" 4 (string-contains-graphemes "say hi" "hi"))
  (test-equal "the space itself" 3 (string-contains-graphemes "say hi" " "))
  (test-equal "followed by a tab" 0 (string-contains-graphemes "x\ty" "x"))
  (test-equal "won't end before a combining mark" #f (string-contains-graphemes "éx" "e"))
  (test-equal "won't start on a combining mark" #f (string-contains-graphemes "éx" "́x"))
  (test-equal "whole cluster" 0 (string-contains-graphemes "éx" "é"))
  (test-equal "skips a bad match for a good one" 3 (string-contains-graphemes "é e" "e"))
  (test-equal "not found" #f (string-contains-graphemes "abc" "z"))
  (test-equal "case-sensitive" #f (string-contains-graphemes "ABC" "b"))
  (test-equal "empty pattern matches at the start" 0 (string-contains-graphemes "abc" ""))
  (test-equal "start1: index into the whole string" 3 (string-contains-graphemes "ab ab" "ab" 1))
  (test-equal "end1 limits the search" #f (string-contains-graphemes "abcab" "ab" 1 4))
  (test-equal "a match may end at end1" 3 (string-contains-graphemes "abcab" "ab" 1 5))
  (test-equal "a match ending at end1 still can't split a cluster" #f
              (string-contains-graphemes "xé" "e" 0 2))
  (test-equal "a match starting at start1 still can't split a cluster" #f
              (string-contains-graphemes "éx" "́x" 1))
  (test-equal "start2/end2 select part of the pattern" 2
              (string-contains-graphemes "abcd" "xcdx" 0 4 1 3)))

(test-group "string-contains-graphemes-ci"
  (test-equal "ignores case" 1 (string-contains-graphemes-ci "ABC" "b"))
  (test-equal "followed by a space" 0 (string-contains-graphemes-ci "SAY hi" "say"))
  (test-equal "won't split a cluster" #f (string-contains-graphemes-ci "Éx" "e"))
  (test-equal "start1" 3 (string-contains-graphemes-ci "Ab aB" "ab" 1)))

(test-group "string-match-graphemes"
  (let ([m (string-match-graphemes "[0-9]+" "ab 123 c")])
    (test-assert "match" (regexp-match? m))
    (test-equal "start" 3 (match:start m))
    (test-equal "end" 6 (match:end m)))
  (test-equal "followed by a space" 0 (match:start (string-match-graphemes "say" "say hi")))
  (test-equal "won't split a cluster" #f (string-match-graphemes "e" "é"))
  (test-equal "skips to an acceptable match" 3 (match:start (string-match-graphemes "e" "é e")))
  (test-equal "from a start position" 4 (match:start (string-match-graphemes "b+" "ab abb" 3)))
  (test-equal "^ only at the start of the string" #f (string-match-graphemes "^a" "aa" 1))
  (test-equal "^ at the start" 0 (match:start (string-match-graphemes "^a" "aa")))
  (test-equal "accepts a compiled regexp" 1
              (match:start (string-match-graphemes (make-regexp "b" regexp/icase) "aB")))
  (test-equal "no match" #f (string-match-graphemes "z" "abc"))
  (test-error "bad regex" #t (string-match-graphemes "(" "abc")))

(test-end "string-utils")

;;; Run the tests when this file is executed
(when (batch-mode?)
  (test-runner-current (test-runner-simple)))

;; Local Variables:
;; eval: (put 'test-group 'scheme-indent-function 1)
;; eval: (put 'test-assert 'scheme-indent-function 1)
;; eval: (put 'test-equal 'scheme-indent-function 1)
;; End:
