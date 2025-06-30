;;; -*- mode: scheme; coding: utf-8; -*-

;;;; Copyright (C) 1996-2025 Michael L. Gran
;;;; License GPL 3+

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
;;; BRACKET FUNCTION TESTS
;;; =================================================================

;;; Tests for char-opening-bracket?
(test-group "char-opening-bracket?"
  (test-assert "left parenthesis is opening bracket"
    (char-opening-bracket? #\())
  
  (test-assert "left square bracket is opening bracket"
    (char-opening-bracket? #\[))
  
  (test-assert "left curly bracket is opening bracket"
    (char-opening-bracket? #\{))
  
  (test-assert "right parenthesis is not opening bracket"
    (not (char-opening-bracket? #\))))
  
  (test-assert "right square bracket is not opening bracket"
    (not (char-opening-bracket? #\])))
  
  (test-assert "right curly bracket is not opening bracket"
    (not (char-opening-bracket? #\})))
  
  (test-assert "less-than sign is not opening bracket"
    (not (char-opening-bracket? #\<)))
  
  (test-assert "greater-than sign is not opening bracket"
    (not (char-opening-bracket? #\>)))
  
  (test-assert "regular letter is not opening bracket"
    (not (char-opening-bracket? #\A)))
  
  (test-assert "digit is not opening bracket"
    (not (char-opening-bracket? #\5)))
  
  (test-assert "space is not opening bracket"
    (not (char-opening-bracket? #\space))))

;;; Tests for char-closing-bracket?
(test-group "char-closing-bracket?"
  (test-assert "right parenthesis is closing bracket"
    (char-closing-bracket? #\)))
  
  (test-assert "right square bracket is closing bracket"
    (char-closing-bracket? #\]))
  
  (test-assert "right curly bracket is closing bracket"
    (char-closing-bracket? #\}))
  
  (test-assert "left parenthesis is not closing bracket"
    (not (char-closing-bracket? #\()))
  
  (test-assert "left square bracket is not closing bracket"
    (not (char-closing-bracket? #\[)))
  
  (test-assert "left curly bracket is not closing bracket"
    (not (char-closing-bracket? #\{)))
  
  (test-assert "less-than sign is not closing bracket"
    (not (char-closing-bracket? #\<)))
  
  (test-assert "greater-than sign is not closing bracket"
    (not (char-closing-bracket? #\>)))
  
  (test-assert "regular letter is not closing bracket"
    (not (char-closing-bracket? #\Z)))
  
  (test-assert "digit is not closing bracket"
    (not (char-closing-bracket? #\7)))
  
  (test-assert "space is not closing bracket"
    (not (char-closing-bracket? #\space))))

;;; Tests for char-bracket?
(test-group "char-bracket?"
  (test-assert "left parenthesis is bracket"
    (char-bracket? #\())
  
  (test-assert "right parenthesis is bracket"
    (char-bracket? #\)))
  
  (test-assert "left square bracket is bracket"
    (char-bracket? #\[))
  
  (test-assert "right square bracket is bracket"
    (char-bracket? #\]))
  
  (test-assert "left curly bracket is bracket"
    (char-bracket? #\{))
  
  (test-assert "right curly bracket is bracket"
    (char-bracket? #\}))
  
  (test-assert "less-than sign is not bracket"
    (not (char-bracket? #\<)))
  
  (test-assert "greater-than sign is not bracket"
    (not (char-bracket? #\>)))
  
  (test-assert "regular letter is not bracket"
    (not (char-bracket? #\M)))
  
  (test-assert "digit is not bracket"
    (not (char-bracket? #\3)))
  
  (test-assert "space is not bracket"
    (not (char-bracket? #\space)))
  
  (test-assert "punctuation mark is not bracket"
    (not (char-bracket? #\!))))

;;; Tests for char-get-bracket-partner
(test-group "char-get-bracket-partner"
  ;; Test opening -> closing mappings
  (test-equal "left paren maps to right paren"
    #\) (char-get-bracket-partner #\())
  
  (test-equal "left square maps to right square"
    #\] (char-get-bracket-partner #\[))
  
  (test-equal "left curly maps to right curly"
    #\} (char-get-bracket-partner #\{))
  
  ;; Test closing -> opening mappings
  (test-equal "right paren maps to left paren"
    #\( (char-get-bracket-partner #\)))
  
  (test-equal "right square maps to left square"
    #\[ (char-get-bracket-partner #\]))
  
  (test-equal "right curly maps to left curly"
    #\{ (char-get-bracket-partner #\}))
  
  ;; Test non-brackets return #f
  (test-equal "less-than sign returns #f"
    #f (char-get-bracket-partner #\<))
  
  (test-equal "greater-than sign returns #f"
    #f (char-get-bracket-partner #\>))
  
  ;; Test non-brackets return #f
  (test-equal "regular letter returns #f"
    #f (char-get-bracket-partner #\X))
  
  (test-equal "digit returns #f"
    #f (char-get-bracket-partner #\8))
  
  (test-equal "space returns #f"
    #f (char-get-bracket-partner #\space))
  
  (test-equal "punctuation returns #f"
    #f (char-get-bracket-partner #\!))
  
  (test-equal "newline returns #f"
    #f (char-get-bracket-partner #\newline)))

;;; Tests for bracket function consistency
(test-group "bracket-consistency"
  ;; Test that all opening brackets have partners
  (test-assert "opening brackets have closing partners"
    (every (lambda (c)
             (if (char-opening-bracket? c)
                 (and (char-get-bracket-partner c)
                      (char-closing-bracket? (char-get-bracket-partner c)))
                 #t))
           (map integer->char (iota 128))))
  
  ;; Test that all closing brackets have partners
  (test-assert "closing brackets have opening partners"
    (every (lambda (c)
             (if (char-closing-bracket? c)
                 (and (char-get-bracket-partner c)
                      (char-opening-bracket? (char-get-bracket-partner c)))
                 #t))
           (map integer->char (iota 128))))
  
  ;; Test symmetry: if A maps to B, then B maps to A
  (test-assert "bracket partner mapping is symmetric"
    (every (lambda (c)
             (let ([partner (char-get-bracket-partner c)])
               (if partner
                   (equal? c (char-get-bracket-partner partner))
                   #t)))
           (map integer->char (iota 128))))
  
  ;; Test that bracket? is equivalent to opening OR closing
  (test-assert "char-bracket? equals opening OR closing"
    (every (lambda (c)
             (equal? (char-bracket? c)
                     (or (char-opening-bracket? c)
                         (char-closing-bracket? c))))
           (map integer->char (iota 128))))
  
  ;; Test that opening and closing are mutually exclusive
  (test-assert "opening and closing brackets are mutually exclusive"
    (every (lambda (c)
             (not (and (char-opening-bracket? c)
                       (char-closing-bracket? c))))
           (map integer->char (iota 128)))))

;;; =================================================================
;;; BIDI CLASS FUNCTION TESTS
;;; =================================================================

;;; Tests for char-get-bidi-class
(test-group "char-get-bidi-class"
  ;; Test ASCII letters (Left-to-Right)
  (test-equal "ASCII uppercase letter has L bidi class"
    BC-L (char-get-bidi-class #\A))
  
  (test-equal "ASCII lowercase letter has L bidi class"
    BC-L (char-get-bidi-class #\z))
  
  ;; Test ASCII digits (European Number)
  (test-equal "ASCII digit has EN bidi class"
    BC-EN (char-get-bidi-class #\0))
  
  (test-equal "ASCII digit 9 has EN bidi class"
    BC-EN (char-get-bidi-class #\9))
  
  ;; Test whitespace characters
  (test-equal "space has WS bidi class"
    BC-WS (char-get-bidi-class #\space))
  
  (test-equal "tab has S bidi class"
    BC-S (char-get-bidi-class #\tab))
  
  (test-equal "newline has B bidi class"
    BC-B (char-get-bidi-class #\newline))
  
  (test-equal "carriage return has B bidi class"
    BC-B (char-get-bidi-class #\return))
  
  ;; Test punctuation and symbols (Other Neutral)
  (test-equal "exclamation mark has ON bidi class"
    BC-ON (char-get-bidi-class #\!))
  
  (test-equal "period has CS bidi class"
    BC-CS (char-get-bidi-class #\.))
  
  (test-equal "comma has CS bidi class"
    BC-CS (char-get-bidi-class #\,))
  
  (test-equal "colon has CS bidi class"
    BC-CS (char-get-bidi-class #\:))
  
  (test-equal "semicolon has ON bidi class"
    BC-ON (char-get-bidi-class #\;))
  
  (test-equal "question mark has ON bidi class"
    BC-ON (char-get-bidi-class #\?))
  
  ;; Test mathematical operators
  (test-equal "plus sign has ES bidi class"
    BC-ES (char-get-bidi-class #\+))
  
  (test-equal "minus sign has ES bidi class"
    BC-ES (char-get-bidi-class #\-))
  
  (test-equal "less-than has ON bidi class"
    BC-ON (char-get-bidi-class #\<))
  
  (test-equal "greater-than has ON bidi class"
    BC-ON (char-get-bidi-class #\>))
  
  (test-equal "equals sign has ON bidi class"
    BC-ON (char-get-bidi-class #\=))
  
  ;; Test currency symbols (European Terminator)
  (test-equal "dollar sign has ET bidi class"
    BC-ET (char-get-bidi-class #\$))
  
  ;; Test brackets (Other Neutral)
  (test-equal "left parenthesis has ON bidi class"
    BC-ON (char-get-bidi-class #\())
  
  (test-equal "right parenthesis has ON bidi class"
    BC-ON (char-get-bidi-class #\)))
  
  (test-equal "left square bracket has ON bidi class"
    BC-ON (char-get-bidi-class #\[))
  
  (test-equal "right square bracket has ON bidi class"
    BC-ON (char-get-bidi-class #\]))
  
  (test-equal "left curly bracket has ON bidi class"
    BC-ON (char-get-bidi-class #\{))
  
  (test-equal "right curly bracket has ON bidi class"
    BC-ON (char-get-bidi-class #\}))
  
  ;; Test control characters (Boundary Neutral)
  (test-equal "NUL has BN bidi class"
    BC-BN (char-get-bidi-class #\nul))
  
  (test-equal "DEL has BN bidi class"
    BC-BN (char-get-bidi-class (integer->char 127)))
  
  ;; Test some Unicode characters (if supported)
  ;; Arabic letter (Right-to-Left)
  (test-equal "Arabic letter Alef has AL bidi class"
    BC-AL (char-get-bidi-class (integer->char #x0627)))  ; U+0627 Arabic Letter Alef
  
  ;; Hebrew letter (Right-to-Left)
  (test-equal "Hebrew letter Alef has R bidi class"
    BC-R (char-get-bidi-class (integer->char #x05D0)))   ; U+05D0 Hebrew Letter Alef
  
  ;; Arabic-Indic digit (Arabic Number)
  (test-equal "Arabic-Indic digit has AN bidi class"
    BC-AN (char-get-bidi-class (integer->char #x0660))) ; U+0660 Arabic-Indic Digit Zero
  
  ;; Combining mark (Nonspacing Mark)
  (test-equal "combining acute accent has NSM bidi class"
    BC-NSM (char-get-bidi-class (integer->char #x0301))) ; U+0301 Combining Acute Accent
  
  ;; Paragraph separator
  (test-equal "paragraph separator has B bidi class"
    BC-B (char-get-bidi-class (integer->char #x2029)))   ; U+2029 Paragraph Separator
  
  ;; Zero width space (Boundary Neutral)
  (test-equal "zero width space has BN bidi class"
    BC-BN (char-get-bidi-class (integer->char #x200B)))) ; U+200B Zero Width Space

;;; Tests for bidi class symbol consistency
(test-group "bidi-class-symbols"
  ;; Test that the exported symbols are defined and distinct
  (test-assert "BC-L is defined" (symbol? BC-L))
  (test-assert "BC-R is defined" (symbol? BC-R))
  (test-assert "BC-AL is defined" (symbol? BC-AL))
  (test-assert "BC-EN is defined" (symbol? BC-EN))
  (test-assert "BC-AN is defined" (symbol? BC-AN))
  (test-assert "BC-ES is defined" (symbol? BC-ES))
  (test-assert "BC-ET is defined" (symbol? BC-ET))
  (test-assert "BC-CS is defined" (symbol? BC-CS))
  (test-assert "BC-NSM is defined" (symbol? BC-NSM))
  (test-assert "BC-BN is defined" (symbol? BC-BN))
  (test-assert "BC-B is defined" (symbol? BC-B))
  (test-assert "BC-S is defined" (symbol? BC-S))
  (test-assert "BC-WS is defined" (symbol? BC-WS))
  (test-assert "BC-ON is defined" (symbol? BC-ON))
  (test-assert "BC-LRE is defined" (symbol? BC-LRE))
  (test-assert "BC-RLE is defined" (symbol? BC-RLE))
  (test-assert "BC-LRO is defined" (symbol? BC-LRO))
  (test-assert "BC-RLO is defined" (symbol? BC-RLO))
  (test-assert "BC-PDF is defined" (symbol? BC-PDF))
  (test-assert "BC-LRI is defined" (symbol? BC-LRI))
  (test-assert "BC-RLI is defined" (symbol? BC-RLI))
  (test-assert "BC-FSI is defined" (symbol? BC-FSI))
  (test-assert "BC-PDI is defined" (symbol? BC-PDI))
  
  ;; Test that symbols are distinct
  (test-assert "BC-L and BC-R are different"
    (not (eq? BC-L BC-R)))
  
  (test-assert "BC-EN and BC-AN are different"
    (not (eq? BC-EN BC-AN)))
  
  (test-assert "BC-ES and BC-ET are different"
    (not (eq? BC-ES BC-ET)))
  
  ;; Test that function returns actual symbol constants
  (test-assert "char-get-bidi-class returns exported symbol"
    (eq? (char-get-bidi-class #\A) BC-L))
  
  (test-assert "char-get-bidi-class returns same symbol for same class"
    (eq? (char-get-bidi-class #\A) (char-get-bidi-class #\Z))))

;;; Tests for char-is-bidi-control?
(test-group "char-is-bidi-control?"
  ;; Test that regular characters are not bidi controls
  (test-assert "ASCII letter is not bidi control"
    (not (char-is-bidi-control? #\A)))
  
  (test-assert "ASCII digit is not bidi control"
    (not (char-is-bidi-control? #\5)))
  
  (test-assert "space is not bidi control"
    (not (char-is-bidi-control? #\space)))
  
  (test-assert "punctuation is not bidi control"
    (not (char-is-bidi-control? #\!)))
  
  (test-assert "bracket is not bidi control"
    (not (char-is-bidi-control? #\()))
  
  (test-assert "Arabic letter is not bidi control"
    (not (char-is-bidi-control? (integer->char #x0627))))  ; Arabic Letter Alef
  
  (test-assert "Hebrew letter is not bidi control"
    (not (char-is-bidi-control? (integer->char #x05D0))))  ; Hebrew Letter Alef
  
  ;; Test actual bidi control characters (if they exist in the implementation)
  ;; Note: These may not be available in all Unicode implementations
  ;; Left-to-Right Embedding (LRE)
  (test-assert "LRE character is bidi control"
    (char-is-bidi-control? (integer->char #x202A)))  ; U+202A LRE
  
  ;; Right-to-Left Embedding (RLE)  
  (test-assert "RLE character is bidi control"
    (char-is-bidi-control? (integer->char #x202B)))  ; U+202B RLE
  
  ;; Pop Directional Formatting (PDF)
  (test-assert "PDF character is bidi control"
    (char-is-bidi-control? (integer->char #x202C)))  ; U+202C PDF
  
  ;; Left-to-Right Override (LRO)
  (test-assert "LRO character is bidi control"
    (char-is-bidi-control? (integer->char #x202D)))  ; U+202D LRO
  
  ;; Right-to-Left Override (RLO)
  (test-assert "RLO character is bidi control"
    (char-is-bidi-control? (integer->char #x202E)))  ; U+202E RLO
  
  ;; Left-to-Right Isolate (LRI)
  (test-assert "LRI character is bidi control"
    (char-is-bidi-control? (integer->char #x2066)))  ; U+2066 LRI
  
  ;; Right-to-Left Isolate (RLI)
  (test-assert "RLI character is bidi control"
    (char-is-bidi-control? (integer->char #x2067)))  ; U+2067 RLI
  
  ;; First Strong Isolate (FSI)
  (test-assert "FSI character is bidi control"
    (char-is-bidi-control? (integer->char #x2068)))  ; U+2068 FSI
  
  ;; Pop Directional Isolate (PDI)
  (test-assert "PDI character is bidi control"
    (char-is-bidi-control? (integer->char #x2069))))  ; U+2069 PDI

;;; Tests for char-is-strong-directional?
(test-group "char-is-strong-directional?"
  ;; Test Left-to-Right characters (L)
  (test-assert "ASCII uppercase letter is strong directional"
    (char-is-strong-directional? #\A))
  
  (test-assert "ASCII lowercase letter is strong directional"
    (char-is-strong-directional? #\z))
  
  ;; Test Right-to-Left characters (R)
  (test-assert "Hebrew letter is strong directional"
    (char-is-strong-directional? (integer->char #x05D0)))  ; Hebrew Letter Alef
  
  ;; Test Arabic Letters (AL)
  (test-assert "Arabic letter is strong directional"
    (char-is-strong-directional? (integer->char #x0627)))  ; Arabic Letter Alef
  
  ;; Test that weak and neutral characters are not strong directional
  (test-assert "ASCII digit is not strong directional"
    (not (char-is-strong-directional? #\5)))
  
  (test-assert "Arabic-Indic digit is not strong directional"
    (not (char-is-strong-directional? (integer->char #x0660))))  ; Arabic-Indic Digit Zero
  
  (test-assert "space is not strong directional"
    (not (char-is-strong-directional? #\space)))
  
  (test-assert "punctuation is not strong directional"
    (not (char-is-strong-directional? #\!)))
  
  (test-assert "bracket is not strong directional"
    (not (char-is-strong-directional? #\()))
  
  (test-assert "math operator is not strong directional"
    (not (char-is-strong-directional? #\+)))
  
  (test-assert "combining mark is not strong directional"
    (not (char-is-strong-directional? (integer->char #x0301))))  ; Combining Acute Accent
  
  (test-assert "control character is not strong directional"
    (not (char-is-strong-directional? #\tab)))
  
  ;; Test bidi control characters are not strong directional
  (test-assert "LRE is not strong directional"
    (not (char-is-strong-directional? (integer->char #x202A))))  ; U+202A LRE
  
  (test-assert "RLE is not strong directional"
    (not (char-is-strong-directional? (integer->char #x202B)))))  ; U+202B RLE

;;; Tests for bidi function consistency  
(test-group "bidi-function-consistency"
  ;; Test that bidi controls are never strong directional
  (test-assert "bidi controls are never strong directional"
    (every (lambda (cp)
             (let ([c (integer->char cp)])
               (if (char-is-bidi-control? c)
                   (not (char-is-strong-directional? c))
                   #t)))
           ;; Test range that includes bidi control characters
           (append (iota 128)  ; ASCII range
                   (list #x202A #x202B #x202C #x202D #x202E  ; Legacy bidi controls
                         #x2066 #x2067 #x2068 #x2069))))     ; Isolate controls
  
  ;; Test that strong directional chars have expected bidi classes
  (test-assert "strong directional chars have L, R, or AL class"
    (every (lambda (cp)
             (let ([c (integer->char cp)])
               (if (char-is-strong-directional? c)
                   (member (char-get-bidi-class c) (list BC-L BC-R BC-AL))
                   #t)))
           ;; Test both ASCII and some Unicode ranges
           (append (iota 128)  ; ASCII
                   (iota 128 #x0590)   ; Hebrew block start  
                   (iota 128 #x0600)))))  ; Arabic block start

;;; =================================================================
;;; INTEGRATION TESTS
;;; =================================================================

(test-group "integration-tests"
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
    (not (char-C0-control? (integer->char 32)))))
  
;;; Test suite cleanup
(test-end "gano-char")

;; Local Variables:
;; eval: (put 'test-group 'scheme-indent-function 1)
;; eval: (put 'test-assert 'scheme-indent-function 1)
;; End:
