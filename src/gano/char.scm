;;; -*- mode: scheme; coding: utf-8; -*-

;;; chars.scm - utility functions that operate on single characters
;;;

(define-module (gano char)
  #:use-module (gano wcwidth)
  #:use-module (gano bracket-pairs)
  #:use-module (gano bidi-class)
  #:export (char-latin1?
	    char-C0-control?
	    char-control?
	    char-blank?
	    char-combining-mark?
	    char-graphic?
	    char-base?
	    char-opening-bracket?
	    char-closing-bracket?
	    char-bracket?
	    char-get-bracket-partner
	    char-get-bidi-class
	    char-is-bidi-control?
	    char-is-strong-directional?)
  #:re-export (BC-AL
               BC-AN
               BC-B
               BC-BN
               BC-CS
               BC-EN
               BC-ES
               BC-ET
               BC-FSI
               BC-L
               BC-LRE
               BC-LRI
               BC-LRO
               BC-NSM
               BC-ON
               BC-PDF
               BC-PDI
               BC-R
               BC-RLE
               BC-RLI
               BC-RLO
               BC-S
               BC-WS))

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
	  '(Lu Ll Lt Lm Lo		; Letters
               Nd Nl No			; Numbers
               Pc Pd Ps Pe Pi Pf Po	; Punctuation
               Sm Sc Sk So)))		; Symbols

;; Remix of (gano bracket-pairs)

(define char-opening-bracket?
  opening-bracket?)

(define char-closing-bracket?
  closing-bracket?)

(define (char-bracket? c)
  (or (opening-bracket? c)
      (closing-bracket? c)))

(define char-get-bracket-partner
  bracket-partner)

;;; =================================================================
;;; Remix of (gano bidi-class)
;;; =================================================================

(define (char-get-bidi-class c)
  (get-bidi-class c))

(define (char-is-bidi-control? char)
  "Check if character is a bidirectional control character"
  (let ([class (get-bidi-class char)])
    (member class '(BC-LRE BC-RLE BC-PDF BC-LRO BC-RLO BC-LRI BC-RLI BC-FSI BC-PDI))))

(define (char-is-strong-directional? char)
  "Check if character has strong directional properties"
  (let ([class (get-bidi-class char)])
    (member class '(BC-L BC-R BC-AL))))

