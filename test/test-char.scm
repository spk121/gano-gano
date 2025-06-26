;;; Test suite for Gano Char Utilities Module
;;; Using SRFI-64 testing framework

(use-modules (srfi srfi-64)     ; Testing framework
	     (srfi srfi-1)      ; every
             (gano char))       ; Module under test

;;; Test suite setup
(test-begin "gano-char")

;;; =================================================================
;;; BASIC CHARACTER CLASSIFICATION TESTS
;;; =================================================================

;;; Tests for char-latin1?
(test-group "char-latin1?"
  (test-assert "NUL is latin1"
    (char-latin1? #\nul))
  
  (test-assert "space is latin1"
    (char-latin1? #\space))
  
  (test-assert "ASCII 'A' is latin1"
    (char-latin1? #\A))
  
  (test-assert "ASCII 'z' is latin1"
    (char-latin1? #\z))
  
  (test-assert "ASCII '9' is latin1"
    (char-latin1? #\9))
  
  (test-assert "DEL (127) is latin1"
    (char-latin1? (integer->char 127)))
  
  (test-assert "Extended ASCII (255) is latin1"
    (char-latin1? (integer->char 255)))
  
  (test-assert "Unicode beyond latin1 is not latin1"
    (not (char-latin1? (integer->char 256))))
  
  (test-assert "Unicode emoji is not latin1"
    (not (char-latin1? (integer->char 128512)))))  ; U+1F600 grinning face

;;; Tests for char-C0-control?
(test-group "char-C0-control?"
  (test-assert "NUL is C0 control"
    (char-C0-control? #\nul))
  
  (test-assert "SOH (1) is C0 control"
    (char-C0-control? (integer->char 1)))
  
  (test-assert "tab is C0 control"
    (char-C0-control? #\tab))
  
  (test-assert "newline is C0 control"
    (char-C0-control? #\newline))
  
  (test-assert "carriage return is C0 control"
    (char-C0-control? #\return))
  
  (test-assert "US (31) is C0 control"
    (char-C0-control? (integer->char 31)))
  
  (test-assert "space (32) is not C0 control"
    (not (char-C0-control? #\space)))
  
  (test-assert "ASCII 'A' is not C0 control"
    (not (char-C0-control? #\A)))
  
  (test-assert "DEL (127) is not C0 control"
    (not (char-C0-control? (integer->char 127)))))

;;; Tests for char-control?
(test-group "char-control?"
  (test-assert "NUL is control"
    (char-control? #\nul))
  
  (test-assert "tab is control"
    (char-control? #\tab))
  
  (test-assert "newline is control"
    (char-control? #\newline))
  
  (test-assert "carriage return is control"
    (char-control? #\return))
  
  (test-assert "DEL (127) is control"
    (char-control? (integer->char 127)))
  
  (test-assert "space is not control"
    (not (char-control? #\space)))
  
  (test-assert "ASCII 'A' is not control"
    (not (char-control? #\A)))
  
  (test-assert "digit '5' is not control"
    (not (char-control? #\5))))

;;; Tests for char-blank?
(test-group "char-blank?"
  (test-assert "space is blank"
    (char-blank? #\space))
  
  (test-assert "tab is blank"
    (char-blank? #\tab))
  
  (test-assert "newline is not blank"
    (not (char-blank? #\newline)))
  
  (test-assert "carriage return is not blank"
    (not (char-blank? #\return)))
  
  (test-assert "ASCII 'A' is not blank"
    (not (char-blank? #\A)))
  
  (test-assert "digit '0' is not blank"
    (not (char-blank? #\0))))

;;; Tests for char-combining-mark?
(test-group "char-combining-mark?"
  (test-assert "ASCII 'A' is not combining mark"
    (not (char-combining-mark? #\A)))
  
  (test-assert "space is not combining mark"
    (not (char-combining-mark? #\space)))
  
  (test-assert "digit '5' is not combining mark"
    (not (char-combining-mark? #\5)))
  
  ;; Test combining diacritical marks (if supported)
  (test-assert "combining acute accent is combining mark"
    (char-combining-mark? (integer->char #x0301)))  ; U+0301 combining acute accent
  
  (test-assert "combining grave accent is combining mark"
    (char-combining-mark? (integer->char #x0300)))  ; U+0300 combining grave accent
  
  (test-assert "combining diaeresis is combining mark"
    (char-combining-mark? (integer->char #x0308))))  ; U+0308 combining diaeresis

;;; Tests for char-graphic?
(test-group "char-graphic?"
  (test-assert "ASCII 'A' is graphic"
    (char-graphic? #\A))
  
  (test-assert "ASCII 'z' is graphic"
    (char-graphic? #\z))
  
  (test-assert "digit '9' is graphic"
    (char-graphic? #\9))
  
  (test-assert "space is not graphic"
    (not (char-graphic? #\space)))
  
  (test-assert "punctuation '!' is graphic"
    (char-graphic? #\!))
  
  (test-assert "NUL is not graphic"
    (not (char-graphic? #\nul)))
  
  (test-assert "tab is not graphic"
    (not (char-graphic? #\tab)))
  
  (test-assert "newline is not graphic"
    (not (char-graphic? #\newline)))
  
  (test-assert "carriage return is not graphic"
    (not (char-graphic? #\return))))

;;; Tests for char-base?
(test-group "char-base?"
  (test-assert "ASCII 'A' is base character"
    (char-base? #\A))
  
  (test-assert "ASCII 'z' is base character"
    (char-base? #\z))
  
  (test-assert "digit '5' is base character"
    (char-base? #\5))
  
  (test-assert "space is not a base character"
    (not (char-base? #\space)))
  
  (test-assert "punctuation '!' is base character"
    (char-base? #\!))
  
  (test-assert "combining acute accent is not base character"
    (not (char-base? (integer->char #x0301))))
  
  (test-assert "NUL is not base character"
    (not (char-base? #\nul)))
  
  (test-assert "tab is not base character"
    (not (char-base? #\tab)))
  
  (test-assert "newline is not base character"
    (not (char-base? #\newline))))

;;; =================================================================
;;; CHAR-COUNT-CELLS TESTS
;;; =================================================================

;;; Tests for char-count-cells
(test-group "char-count-cells"
  ;; Test NUL character
  (test-equal "NUL takes 0 cells"
    0
    (char-count-cells #\nul 0 8))
  
  ;; Test tab character at different positions
  (test-equal "tab at column 0 with tabsize 8"
    8
    (char-count-cells #\tab 0 8))
  
  (test-equal "tab at column 1 with tabsize 8"
    7
    (char-count-cells #\tab 1 8))
  
  (test-equal "tab at column 4 with tabsize 8"
    4
    (char-count-cells #\tab 4 8))
  
  (test-equal "tab at column 7 with tabsize 8"
    1
    (char-count-cells #\tab 7 8))
  
  (test-equal "tab at column 8 with tabsize 8"
    8
    (char-count-cells #\tab 8 8))
  
  (test-equal "tab at column 0 with tabsize 4"
    4
    (char-count-cells #\tab 0 4))
  
  (test-equal "tab at column 2 with tabsize 4"
    2
    (char-count-cells #\tab 2 4))
  
  ;; Test C0 control characters (excluding NUL and tab)
  (test-equal "SOH (^A) takes 2 cells"
    2
    (char-count-cells (integer->char 1) 0 8))
  
  (test-equal "newline (^J) takes 2 cells"
    2
    (char-count-cells #\newline 0 8))
  
  (test-equal "carriage return (^M) takes 2 cells"
    2
    (char-count-cells #\return 0 8))
  
  (test-equal "ESC (^[) takes 2 cells"
    2
    (char-count-cells (integer->char 27) 0 8))
  
  ;; Test regular ASCII characters
  (test-equal "space takes 1 cell"
    1
    (char-count-cells #\space 0 8))
  
  (test-equal "ASCII 'A' takes 1 cell"
    1
    (char-count-cells #\A 0 8))
  
  (test-equal "digit '5' takes 1 cell"
    1
    (char-count-cells #\5 0 8))
  
  ;; Test CJK parameter (if wcwidth supports it)
  (test-equal "regular char with CJK disabled"
    1
    (char-count-cells #\A 0 8 #:cjk? #f))
  
  (test-equal "regular char with CJK enabled"
    1
    (char-count-cells #\A 0 8 #:cjk? #t))
  
  ;; Test edge cases
  (test-equal "character at different column positions gives same result"
    1
    (char-count-cells #\A 5 8))
  
  (test-equal "character with different tab sizes gives same result"
    1
    (char-count-cells #\A 0 4)))

;;; =================================================================
;;; CHAR-GET-DISPLAY-REPRESENTATION-OF-CONTROL-CHAR TESTS
;;; =================================================================

;;; Tests for char-get-display-representation-of-control-char
(test-group "char-get-display-representation-of-control-char"
  (test-equal "NUL becomes @"
    #\@
    (char-get-display-representation-of-control-char #\nul))
  
  (test-equal "SOH becomes A"
    #\A
    (char-get-display-representation-of-control-char (integer->char 1)))
  
  (test-equal "tab becomes I"
    #\I
    (char-get-display-representation-of-control-char #\tab))
  
  (test-equal "newline becomes J"
    #\J
    (char-get-display-representation-of-control-char #\newline))
  
  (test-equal "carriage return becomes M"
    #\M
    (char-get-display-representation-of-control-char #\return))
  
  (test-equal "ESC becomes ["
    #\[
    (char-get-display-representation-of-control-char (integer->char 27)))
  
  (test-equal "US (31) becomes _"
    #\_
    (char-get-display-representation-of-control-char (integer->char 31)))
  
  ;; Test the mathematical relationship
  (test-assert "control char + 64 gives display char"
    (let ([ctrl-char (integer->char 5)])  ; ENQ
      (equal? (char-get-display-representation-of-control-char ctrl-char)
              (integer->char (+ (char->integer ctrl-char) 64)))))
  
  ;; Test all C0 control characters
  (test-assert "all C0 controls map to printable characters"
    (every (lambda (i)
             (let* ([ctrl-char (integer->char i)]
                    [display-char (char-get-display-representation-of-control-char ctrl-char)])
               (and (char? display-char)
                    (>= (char->integer display-char) 64)
                    (<= (char->integer display-char) 95))))
           (iota 32))))  ; 0 through 31

;;; =================================================================
;;; INTEGRATION TESTS
;;; =================================================================

(test-group "integration-tests"
  ;; Test that char-count-cells uses char-get-display-representation-of-control-char correctly
  (test-equal "control character cell count includes caret"
    2
    (let* ([ctrl-char (integer->char 5)]  ; ENQ
           [display-char (char-get-display-representation-of-control-char ctrl-char)])
      (char-count-cells ctrl-char 0 8)))
  
  ;; Test character classification consistency
  (test-assert "all C0 controls are also controls"
    (every (lambda (i)
             (let ([c (integer->char i)])
               (if (char-C0-control? c)
                   (char-control? c)
                   #t)))
           (iota 128)))
  
  ;; Test that base characters are graphic but not combining
  (test-assert "base chars are graphic and not combining"
    (let ([test-chars (list #\A #\z #\5 #\space #\!)])
      (every (lambda (c)
               (if (char-base? c)
                   (and (char-graphic? c)
                        (not (char-combining-mark? c)))
                   #t))
             test-chars)))
  
  ;; Test combining marks are not base characters
  (test-assert "combining marks are not base characters"
    (let ([combining-chars (list (integer->char #x0301)  ; combining acute
                                (integer->char #x0300)  ; combining grave
                                (integer->char #x0308))])  ; combining diaeresis
      (every (lambda (c)
               (if (char-combining-mark? c)
                   (not (char-base? c))
                   #t))
             combining-chars))))

;;; =================================================================
;;; EDGE CASES AND BOUNDARY TESTS
;;; =================================================================

(test-group "edge-cases"
  ;; Test boundary values for latin1
  (test-assert "char 255 is last latin1 character"
    (char-latin1? (integer->char 255)))
  
  (test-assert "char 256 is first non-latin1 character"
    (not (char-latin1? (integer->char 256))))
  
  ;; Test boundary values for C0 control
  (test-assert "char 31 is last C0 control character"
    (char-C0-control? (integer->char 31)))
  
  (test-assert "char 32 is first non-C0 control character"
    (not (char-C0-control? (integer->char 32))))
  
  ;; Test tab behavior at tab boundaries
  (test-equal "tab at exact tab boundary"
    8
    (char-count-cells #\tab 16 8))
  
  (test-equal "tab just before tab boundary"
    1
    (char-count-cells #\tab 15 8))
  
  ;; Test with different tab sizes
  (test-equal "tab with tabsize 1"
    1
    (char-count-cells #\tab 5 1))
  
  (test-equal "tab with large tabsize"
    16
    (char-count-cells #\tab 0 16)))

;;; Test suite cleanup
(test-end "gano-char")
