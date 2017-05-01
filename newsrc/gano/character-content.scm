(define-module (gano character-content)
  #:use-modules (srfi srfi-1)
  #:export ())

;; The CBuffer requires a content model.  Here are 4 content models
;; with associated accessors and modifiers
;; 1. 8-bit locale-encoded characters stored in a bytevector.
;; 2. Native Guile characters encoded in a string
;; 3. Unicode codepoints with associated layout presentation attributes, such
;;    as color, bold, etc.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Layout Presentation Attributes

;; We're followin T.416 here, which is rather like the model from
;; ECMA-48

;; alignment: *start-aligned, end-aligned, centred, justified
;; font-size: positive integer
;; font-identifier: positive integer up to 10
;; character-orientation: *d0, d90, d180, d270
;; character-path: *d0, d90, d180, d270
;; character-spacing: any positive integer
;; first-line-offset: any integer, default is zero
;; formatting-indicator: yes, no
;; graphic-rendition: 0, 1-7, 9, 10-19, 21-27, 29, 30-38, 40-48, 50
;;

1-bit rendition
1-bit bold, normal

11-bit rendition
1-bit bold, normal
1-bit italic, normal
1-bit underline, normal
1-bit blink, steady
1-bit positive, negative
3-bit FG color index
3-bit BG color index

43-bit rendition
;; 4-bits: font variant number
;; 4-bits: font size index
;; 2-bits: bold, normal, faint
;; 1-bit: italicized, not italicized
;; 2-bits: underlined, double underlined,
;; 2 bits: steady, slow blink, rapid blink
;; 2-bit: strikethrough, double strikethrough, unstruck
;; 2-bit: subscript, superscript, regular
;; 2-bit: small caps, all caps, lower case
;; 1-bit: positive image, negative image
;; 1-bit: variable, not variale spacing
;; 2-bits: orientation 0, 90, 180, 270
;; 8-bits: foreground color index
;; 8-bits: background color index
;; ------
;; 41-bits: all rendition


#!
Value Meaning
0 Default rendition (implementation-defined); cancels the effect of any
preceding occurrence of SGR and cancels the effect of the presentation
attribute “graphic rendition”; invokes the primary font, character
foreground and character background colour
1 Bold or increased intensity
2 Faint or decreased intensity
3 Italicized
4 Underlined
5 Slowly blinking
6 Rapidly blinking
7 Negative image
9 Crossed-out (characters still legible but marked as to be deleted)
10 Primary (default) font
11 First alternative font
12 Second alternative font
13 Third alternative font
14 Fourth alternative font
15 Fifth alternative font
16 Sixth alternative font
17 Seventh alternative font
18 Eighth alternative font
19 Ninth alternative font
21 Doubly underlined
22 Normal intensity (neither bold nor faint)
23 Not italicized
24 Not underlined (neither singly nor doubly)
25 Steady (not blinking)
26 Variable spacing
27 Positive image
29 Not crossed-out
30 Black foreground
31 Red foreground
32 Green foreground
33 Yellow foreground
34 Blue foreground
35 Magenta foreground
36 Cyan foreground
37 White foreground
38 Select character foreground colour
40 Black background
41 Red background
42 Green background
43 Yellow background
44 Blue background
45 Magenta background
46 Cyan background
47 White background
48 Select character background colour
50 Not variable spacing
!#
