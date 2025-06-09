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

(test-end "string-split")

;;; =================================================================
;;; TEST RUNNER
;;; =================================================================

;; Print summary and exit with appropriate code
#; (let ([results (test-runner-get)])
  (let ([total (test-runner-test-count results)]
        [passed (test-runner-pass-count results)]
        [failed (test-runner-fail-count results)]
        [skipped (test-runner-skip-count results)])
    
    (format #t "~%Test Results:~%")
    (format #t "  Total:   ~d~%" total)
    (format #t "  Passed:  ~d~%" passed)
    (format #t "  Failed:  ~d~%" failed)
    (format #t "  Skipped: ~d~%" skipped)
    
    (if (> failed 0)
        (begin
          (format #t "~%Some tests failed!~%")
          (exit 1))
        (begin
          (format #t "~%All tests passed!~%")
          (exit 0)))))