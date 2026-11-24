;;; Test suite for Gano WCWidth Module
;;; Using SRFI-64 testing framework

(use-modules (srfi srfi-64)     ; Testing framework
             (srfi srfi-1)      ; every
             (ice-9 regex)      ; string-match
             (gano wcwidth))    ; Module under test

;;; Test suite setup
(test-begin "gano-wcwidth")

;;; =================================================================
;;; BASIC WCWIDTH TESTS - CHARACTER INPUT
;;; =================================================================

;;; Tests for wcwidth with character input
(test-group "wcwidth-char-basic"
  ;; Test null character
  (test-equal "NUL character has width 0"
    0
    (wcwidth #\nul))
  
  ;; Test C0 control characters (should return -1)
  (test-equal "SOH control character has width -1"
    -1
    (wcwidth (integer->char 1)))
  
  (test-equal "tab control character has width -1"
    -1
    (wcwidth #\tab))
  
  (test-equal "newline control character has width -1"
    -1
    (wcwidth #\newline))
  
  (test-equal "carriage return control character has width -1"
    -1
    (wcwidth #\return))
  
  (test-equal "ESC control character has width -1"
    -1
    (wcwidth (integer->char 27)))
  
  ;; Test DEL and C1 control characters
  (test-equal "DEL character has width -1"
    -1
    (wcwidth (integer->char 127)))
  
  (test-equal "C1 control character has width -1"
    -1
    (wcwidth (integer->char 128)))
  
  ;; Test regular ASCII characters
  (test-equal "space character has width 1"
    1
    (wcwidth #\space))
  
  (test-equal "ASCII 'A' has width 1"
    1
    (wcwidth #\A))
  
  (test-equal "ASCII 'z' has width 1"
    1
    (wcwidth #\z))
  
  (test-equal "digit '5' has width 1"
    1
    (wcwidth #\5))
  
  (test-equal "punctuation '!' has width 1"
    1
    (wcwidth #\!))
  
  ;; Test extended ASCII
  (test-equal "extended ASCII character has width 1"
    1
    (wcwidth (integer->char 192)))  ; À
  
  (test-equal "soft hyphen has width 1"
    1
    (wcwidth (integer->char #x00AD))))

;;; Tests for combining characters (width 0)
(test-group "wcwidth-char-combining"
  ;; Test combining diacritical marks
  (test-equal "combining acute accent has width 0"
    0
    (wcwidth (integer->char #x0301)))
  
  (test-equal "combining grave accent has width 0"
    0
    (wcwidth (integer->char #x0300)))
  
  (test-equal "combining diaeresis has width 0"
    0
    (wcwidth (integer->char #x0308)))
  
  (test-equal "combining cedilla has width 0"
    0
    (wcwidth (integer->char #x0327)))
  
  ;; Test other combining marks
  (test-equal "combining ring above has width 0"
    0
    (wcwidth (integer->char #x030A)))
  
  (test-equal "combining tilde has width 0"
    0
    (wcwidth (integer->char #x0303)))
  
  ;; Test zero-width space
  (test-equal "zero width space has width 0"
    0
    (wcwidth (integer->char #x200B))))

;;; Tests for wide characters (width 2)
(test-group "wcwidth-char-wide"
  ;; Test CJK characters
  (test-equal "CJK ideograph has width 2"
    2
    (wcwidth (integer->char #x4E00)))  ; 一 (one)
  
  (test-equal "another CJK ideograph has width 2"
    2
    (wcwidth (integer->char #x4E2D)))  ; 中 (middle)
  
  ;; Test Hangul syllables
  (test-equal "Hangul syllable has width 2"
    2
    (wcwidth (integer->char #xAC00)))  ; 가
  
  (test-equal "another Hangul syllable has width 2"
    2
    (wcwidth (integer->char #xD7A3)))  ; 힣
  
  ;; Test fullwidth forms
  (test-equal "fullwidth 'A' has width 2"
    2
    (wcwidth (integer->char #xFF21)))  ; Ａ
  
  (test-equal "fullwidth '0' has width 2"
    2
    (wcwidth (integer->char #xFF10)))  ; ０
  
  ;; Test angle brackets (traditional)
  (test-equal "left angle bracket has width 2"
    2
    (wcwidth (integer->char #x2329)))
  
  (test-equal "right angle bracket has width 2"
    2
    (wcwidth (integer->char #x232A))))

;;; =================================================================
;;; CJK MODE TESTS
;;; =================================================================

;;; Tests for CJK mode differences
(test-group "wcwidth-cjk-mode"
  ;; Test ambiguous characters - should be width 1 in normal mode, 2 in CJK mode
  (test-equal "section sign in normal mode has width 1"
    1
    (wcwidth (integer->char #x00A7) #f))  ; §
  
  (test-equal "section sign in CJK mode has width 2"
    2
    (wcwidth (integer->char #x00A7) #t))  ; §
  
  (test-equal "degree symbol in normal mode has width 1"
    1
    (wcwidth (integer->char #x00B0) #f))  ; °
  
  (test-equal "degree symbol in CJK mode has width 2"
    2
    (wcwidth (integer->char #x00B0) #t))  ; °
  
  (test-equal "Greek alpha in normal mode has width 1"
    1
    (wcwidth (integer->char #x03B1) #f))  ; α
  
  (test-equal "Greek alpha in CJK mode has width 2"
    2
    (wcwidth (integer->char #x03B1) #t))  ; α
  
  ;; Test that non-ambiguous characters are unaffected
  (test-equal "ASCII 'A' same width in both modes"
    1
    (wcwidth #\A #f))
  
  (test-equal "ASCII 'A' same width in CJK mode"
    1
    (wcwidth #\A #t))
  
  (test-equal "CJK ideograph same width in both modes"
    2
    (wcwidth (integer->char #x4E00) #f))
  
  (test-equal "CJK ideograph same width in CJK mode"
    2
    (wcwidth (integer->char #x4E00) #t)))

;;; =================================================================
;;; INTEGER INPUT TESTS
;;; =================================================================

;;; Tests for wcwidth with integer input
(test-group "wcwidth-integer"
  (test-equal "integer 0 (NUL) has width 0"
    0
    (wcwidth 0))
  
  (test-equal "integer 65 ('A') has width 1"
    1
    (wcwidth 65))
  
  (test-equal "integer for CJK character has width 2"
    2
    (wcwidth #x4E00))
  
  (test-equal "integer for combining mark has width 0"
    0
    (wcwidth #x0301))
  
  (test-equal "integer for control character has width -1"
    -1
    (wcwidth 9))  ; tab
  
  ;; Test CJK mode with integers
  (test-equal "ambiguous character integer in normal mode"
    1
    (wcwidth #x00A7 #f))
  
  (test-equal "ambiguous character integer in CJK mode"
    2
    (wcwidth #x00A7 #t)))

;;; =================================================================
;;; STRING INPUT TESTS
;;; =================================================================

;;; Tests for wcwidth with string input
(test-group "wcwidth-string"
  ;; Test basic ASCII strings
  (test-equal "simple ASCII string"
    5
    (wcwidth "hello"))
  
  (test-equal "ASCII string with spaces"
    11
    (wcwidth "hello world"))
  
  (test-equal "string with digits and punctuation"
    7
    (wcwidth "123-456"))
  
  ;; Test empty string
  (test-equal "empty string has width 0"
    0
    (wcwidth ""))
  
  ;; Test strings with wide characters
  (test-equal "string with CJK characters"
    6  ; 3 characters × 2 width each
    (wcwidth "中文字"))
  
  (test-equal "mixed ASCII and CJK"
    4
    (wcwidth "a中b"))  ; "a" (1) + "中" (2) + "b" (1) = 4
  
  ;; Test strings with combining characters
  (test-equal "string with combining marks"
    1  ; base character + combining marks = width of base
    (wcwidth (string (integer->char #x0065)    ; e
                     (integer->char #x0301))))  ; combining acute
  
  (test-equal "word with combining diacritics"
    4  ; "café" - each base char is 1, combining marks are 0
    (wcwidth (string #\c #\a #\f
                     (integer->char #x0065)    ; e
                     (integer->char #x0301))))  ; combining acute = é
  
  ;; Test strings with control characters (should contribute -1 each)
  (test-equal "string with tab"
    -1  ; control characters return -1
    (wcwidth "a\tb"))
  
  ;; Test CJK mode with strings
  (test-equal "ambiguous chars in string, normal mode"
    3
    (wcwidth (string (integer->char #x00A7)    ; §
                     (integer->char #x00B0)    ; °
                     (integer->char #x03B1)) #f)) ; α
  
  (test-equal "ambiguous chars in string, CJK mode"
    6
    (wcwidth (string (integer->char #x00A7)    ; §
                     (integer->char #x00B0)    ; °
                     (integer->char #x03B1)) #t))) ; α

;;; =================================================================
;;; EDGE CASES AND BOUNDARY TESTS
;;; =================================================================

(test-group "wcwidth-edge-cases"
  ;; Test invalid input types
  (test-equal "invalid input type returns -1"
    -1
    (wcwidth 'symbol))
  
  (test-equal "list input returns -1"
    -1
    (wcwidth '(1 2 3)))
  
  ;; Test boundary Unicode values
  (test-equal "highest BMP character"
    1
    (wcwidth #xFFFF))
  
  (test-equal "first supplementary plane character"
	      ;; U+10000 LINEAR B SYLLABLE B008 A has width class 'N'
    1
    (wcwidth #x10000))
  
  ;; Test various format characters
  (test-equal "byte order mark has width 0"
    0
    (wcwidth #xFEFF))
  
  (test-equal "object replacement character has width 1"
    1
    (wcwidth #xFFFC))
  
  ;; Test private use area
  (test-equal "private use character has width 2 in CJK"
    2  ; U+E000 private-use-E000 
    (wcwidth #xE000 #t))
  
  ;; Test mathematical operators
  (test-equal "mathematical operator has width 1"
    1
    (wcwidth (integer->char #x2200)))  ; ∀ (for all)
  
  ;; Test emoji (if supported)
  (test-equal "emoji character"
    2  ; Most emoji are wide
    (wcwidth #x1F600))) ; 😀 grinning face

;;; =================================================================
;;; COMPREHENSIVE CHARACTER RANGE TESTS
;;; =================================================================

(test-group "wcwidth-ranges"
  ;; Test that all C0 controls except NUL return -1
  (test-assert "all C0 control characters return -1"
    (every (lambda (i)
             (= (wcwidth i) -1))
           (iota 31 1)))  ; 1-31
  
  ;; Test that basic ASCII returns 1
  (test-assert "basic ASCII characters return 1"
    (every (lambda (i)
             (= (wcwidth i) 1))
           (iota 95 32)))  ; 32-126 (space through ~)
  
  ;; Test C1 controls return -1
  (test-assert "C1 control characters return -1"
    (every (lambda (i)
             (= (wcwidth i) -1))
           (iota 32 128)))  ; 128-159
  
  ;; Test that combining marks return 0
  (test-assert "sample combining marks return 0"
    (every (lambda (cp)
             (= (wcwidth cp) 0))
           '(#x0300 #x0301 #x0302 #x0308 #x0327)))
  
  ;; Test that CJK ideographs return 2
  (test-assert "sample CJK ideographs return 2"
    (every (lambda (cp)
             (= (wcwidth cp) 2))
           '(#x4E00 #x4E2D #x4F60 #x597D))))

;;; =================================================================
;;; INTEGRATION AND CONSISTENCY TESTS
;;; =================================================================

(test-group "wcwidth-integration"
  ;; Test that string width equals sum of character widths (when no control chars)
  (test-assert "string width equals sum of char widths"
    (let* ([test-string "hello世界"]
           [string-width (wcwidth test-string)]
           [char-sum (apply + (map wcwidth (string->list test-string)))])
      (= string-width char-sum)))
  
  ;; Test consistency between char and integer input
  (test-assert "char and integer input give same results"
    (every (lambda (cp)
             (= (wcwidth (integer->char cp))
                (wcwidth cp)))
           '(65 97 48 33 #x4E00 #x0301 0 9 127)))
  
  ;; Test that CJK mode only affects ambiguous characters
  (test-assert "CJK mode only affects ambiguous characters"
    (let ([normal-chars '(65 97 48 #x4E00 #x0301 0 9)]  ; non-ambiguous
          [ambiguous-chars '(#x00A7 #x00B0 #x03B1)])     ; ambiguous
      (and
       ;; Normal chars should be same in both modes
       (every (lambda (cp)
                (= (wcwidth cp #f) (wcwidth cp #t)))
              normal-chars)
       ;; Ambiguous chars should differ
       (every (lambda (cp)
                (let ([normal-width (wcwidth cp #f)]
                      [cjk-width (wcwidth cp #t)])
                  (and (>= normal-width 0)  ; valid widths
                       (>= cjk-width 0)
                       (not (= normal-width cjk-width)))))
              ambiguous-chars))))
  
  ;; Test composition: string of known characters
  (test-equal "composed string width calculation"
    12
    (wcwidth (string #\A                       ; A (1)
                     (integer->char #x4E2D)    ; 中 (2)
                     (integer->char #x0301)    ; combining acute (0)
                     #\B                       ; B (1)
                     (integer->char #x6587)    ; 文 (2)
                     #\space                   ; space (1)
                     (integer->char #x4E16)    ; 世 (2)
                     (integer->char #x754C)    ; 界 (2)
                     #\!))))                   ; ! (1)
                                               ; Total: 1+2+0+1+2+1+2+2+1 = 12

;;; Test suite cleanup
;;; ---------------------------------------------------------------
;;; Strict: the Kuhn/glibc rules the generator implements
;;; ---------------------------------------------------------------

(test-group "strict rules"
  (test-equal "spacing combining mark (Mc) takes a cell" 1 (wcwidth #\x093E))
  (test-equal "nonspacing mark (Mn)" 0 (wcwidth #\x0301))
  (test-equal "enclosing mark (Me)" 0 (wcwidth #\x20DD))
  (test-equal "format character (Cf): LEFT-TO-RIGHT MARK" 0 (wcwidth #\x200E))
  (test-equal "format character: ZERO WIDTH JOINER" 0 (wcwidth #\x200D))
  (test-equal "format character: WORD JOINER" 0 (wcwidth #\x2060))
  (test-equal "soft hyphen is the exception" 1 (wcwidth #\x00AD))
  (test-equal "Hangul medial vowel" 0 (wcwidth #\x1161))
  (test-equal "Hangul final consonant (extended-B)" 0 (wcwidth #\xD7CB))
  (test-equal "Hangul leading consonant is wide" 2 (wcwidth #\x1100))
  (test-equal "private use, normal" 1 (wcwidth #\xE000))
  (test-equal "private use, CJK" 2 (wcwidth #\xE000 #t))
  (test-equal "supplementary private use, CJK" 2 (wcwidth #\xF0000 #t))
  (test-equal "last private use character, CJK" 2 (wcwidth #x10FFFD #t))
  (test-equal "surrogate codepoint" -1 (wcwidth #xD800))
  (test-equal "surrogate codepoint (end)" -1 (wcwidth #xDFFF))
  (test-equal "codepoint past Unicode" -1 (wcwidth #x110000))
  (test-equal "negative codepoint" -1 (wcwidth -1))
  (test-equal "emoji" 2 (wcwidth #\x1F600))
  (test-equal "CJK extension B" 2 (wcwidth #\x20000))
  (test-equal "unassigned CJK plane-3 codepoint is wide" 2 (wcwidth #x30000))
  (test-equal "string with a format character" 2 (wcwidth "a‎b"))
  (test-equal "string with a control character" -1 (wcwidth "a\x01b"))
  (test-equal "Unicode version is recorded" #t
              (and (string-match "^[0-9]+\\.[0-9]+\\.[0-9]+$" wcwidth-unicode-version) #t)))

(test-group "whole ranges"
  (test-assert "every surrogate is -1"
               (every (lambda (cp) (= -1 (wcwidth cp))) (iota #x800 #xD800)))
  (test-assert "the BMP private use area is ambiguous"
               (every (lambda (cp) (and (= 1 (wcwidth cp)) (= 2 (wcwidth cp #t))))
                      (iota (- #xF900 #xE000) #xE000)))
  (test-assert "all CJK unified ideographs are wide"
               (every (lambda (cp) (= 2 (wcwidth cp))) (iota (- #xA000 #x4E00) #x4E00)))
  (test-assert "all Hangul syllables are wide"
               (every (lambda (cp) (= 2 (wcwidth cp))) (iota (- #xD7A4 #xAC00) #xAC00))))

(test-end "gano-wcwidth")
