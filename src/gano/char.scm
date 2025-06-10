;;; chars.scm - utility functions that operate on single characters
;;;

(define-module (gano char)
  #:use-module (gano wcwidth)
  #:export (char-latin1? char-C0-control? char-control? char-blank?
			 char-combining-mark? char-graphic?
			 char-base? char-count-cells
			 char-get-display-representation-of-control-char))
(define (char-latin1? c)
  "Return #t if C is one of the first 256 codepoints"
  (< (char->integer c) 256))

(define (char-C0-control? c)
  "Return #f if C is one of the C0 control characters, which
have codepoints 0 through 31"
  (< (char->integer c) 32))

(define (char-control? c)
  "Return #t if this is an ISO control character."
  (char-set-contains? char-set:iso-control c))

(define (char-blank? c)
  "Return #t if this a horizontal whitespace character, like space or
tab."
  (char-set-contains? char-set:blank c))

(define (char-combining-mark? c)
  "Return #t if this is a combining mark, like an accent"
  (member (char-general-category c) '(Mn Mc Me)))

(define (char-graphic? c)
  "Return #t if this is a graphic character."
  (char-set-contains? char-set:graphic c))

(define (char-base? c)
  "Return #t if this is a character than can be the base for a
combining mark, like an accent."
  (member (char-general-category c)
	  '(Lu Ll Lt Lm Lo  ; Letters
               Nd Nl No              ; Numbers
               Pc Pd Ps Pe Pi Pf Po  ; Punctuation
               Sm Sc Sk So)))       ; Symbols

(define* (char-count-cells chr x tabSize #:key (cjk? #f))
  "Number of cells a character CHR at column X would take up"
  (cond
   [(eqv? chr #\nul)
    0]
   [(eqv? chr #\tab)
    (- tabSize (modulo x tabSize))]
   [(char-C0-control? chr)
    ;; Add 1 for the caret '^'
    (+ 1 (wcwidth (char-get-display-representation-of-control-char chr)))]
   [else
    (wcwidth chr cjk?)]))

(define (char-get-display-representation-of-control-char c)
  "The character to use when displaying controls in \"^X\" form"
  (integer->char (+ (char->integer c) 64)))
