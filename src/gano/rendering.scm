;;; Gano Rendering Module
;;; ECMA-48 SGR (Select Graphic Rendition) character attributes

;;;; SGR Attribute Groups
;;;
;;; ECMA-48 SGR attributes are organized into mutually exclusive groups:
;;;
;;; INTENSITY: bold, faint, normal
;;; FONT_STYLE: italicized, fraktur, normal  
;;; UNDERLINE: single, double, none
;;; BLINK: slow, rapid, none
;;; POLARITY: positive, negative
;;; VISIBILITY: concealed, revealed
;;; STRIKETHROUGH: crossed-out, normal
;;; FONT_FAMILY: primary (0), alternative (1-9)
;;; FRAME: framed, encircled, none
;;; OVERLINE: overlined, normal
;;; FOREGROUND_COLOR: 8 standard colors + default
;;; BACKGROUND_COLOR: 8 standard colors + default

(define-module (gano rendering)
  #:use-module (srfi srfi-9)        ; Record types
  #:use-module (srfi srfi-1)        ; List utilities
  ;; #:use-module (srfi srfi-69)       ; Hash tables
  #:export (
    ;; SGR record type
    <sgr>
    make-sgr
    sgr?
    
    ;; Field accessors
    sgr-intensity
    sgr-font-style
    sgr-underline
    sgr-blink
    sgr-polarity
    sgr-visibility
    sgr-strikethrough
    sgr-font-family
    sgr-frame
    sgr-overline
    sgr-foreground-color
    sgr-background-color
    sgr-set-font-family!
    set-sgr-foreground-color!
    set-sgr-background-color!
    set-sgr-font-family!
    
    ;; Constructors and utilities
    make-default-sgr
    sgr-copy
    sgr-invert-polarity
    sgr-reset!
    sgr-equal?
    
    ;; SGR attribute application
    sgr-apply-attribute!
    sgr-apply-attributes!
    sgr-from-parameters
    
    ;; SGR rendering
    sgr->ansi-sequence
    sgr-differences
    sgr-minimal-sequence
    sgr-render-text
    
    ;; Extended color types
    <color-256> make-color-256 color-256? color-256-index
    <color-rgb> make-color-rgb color-rgb? color-rgb-red color-rgb-green color-rgb-blue

    ;; Color utilities
    color-type
    color->ansi-params
    ansi-params->color
    rgb->color-256
    color-256->rgb
    sgr-set-foreground-color!
    sgr-set-background-color!
    
    ;; ANSI SGR parameter constants
    sgr-parameters
    parameter->attribute
    attribute->parameter))

;;; =================================================================
;;; EXTENDED COLOR SUPPORT
;;; =================================================================

;;; Extended color record types for 256-color and RGB support

;; 256-color palette entry (0-255)
(define-record-type <color-256>
  (%make-color-256 index)
  color-256?
  (index color-256-index))  ; 0-255

;; RGB color (24-bit true color)
(define-record-type <color-rgb>
  (%make-color-rgb red green blue)
  color-rgb?
  (red color-rgb-red)      ; 0-255
  (green color-rgb-green)  ; 0-255  
  (blue color-rgb-blue))   ; 0-255

(define (byte? n) (and (exact-integer? n) (<= 0 n 255)))

(define (make-color-256 index)
  "A colour from the 256-colour palette (INDEX 0-255)"
  (unless (byte? index) (error "make-color-256: index must be 0-255" index))
  (%make-color-256 index))

(define (make-color-rgb red green blue)
  "A 24-bit colour (each component 0-255)"
  (unless (and (byte? red) (byte? green) (byte? blue))
    (error "make-color-rgb: components must be 0-255" red green blue))
  (%make-color-rgb red green blue))

;;; Color type detection
(define (color-type color)
  "Determine the type of a color value"
  (cond
   [(symbol? color) 'standard]     ; Standard 8 colors + default
   [(color-256? color) '256-color]
   [(color-rgb? color) 'rgb]
   [else 'unknown]))

;;; =================================================================
;;; COLOR UTILITIES
;;; =================================================================

(define (color->ansi-params color is-background?)
  "Convert a color value to ANSI SGR parameters"
  (cond
   ;; Standard colors
   [(symbol? color)
    (if (eq? color 'color-default)
        (list (if is-background? 49 39))  ; Default color
        (let ([base (if is-background? 40 30)]
              [color-num (case color
                          [(color-black) 0]
                          [(color-red) 1] 
                          [(color-green) 2]
                          [(color-yellow) 3]
                          [(color-blue) 4]
                          [(color-magenta) 5]
                          [(color-cyan) 6]
                          [(color-white) 7]
                          [else (error "Unknown colour" color)])])
          (list (+ base color-num))))]
   
   ;; 256-color palette
   [(color-256? color)
    (list (if is-background? 48 38) 5 (color-256-index color))]
   
   ;; RGB color
   [(color-rgb? color)
    (list (if is-background? 48 38) 2 
          (color-rgb-red color) 
          (color-rgb-green color) 
          (color-rgb-blue color))]
   
   ;; Unknown color type
   [else (error "Unknown colour" color)]))

(define (ansi-params->color params is-background?)
  "Convert ANSI SGR parameters to a color value"
  (cond
   ;; Standard colors (30-37, 40-47, 39, 49)
   [(= (length params) 1)
    (let ([param (car params)])
      (cond
       ;; Default colors
       [(or (= param 39) (= param 49)) 'color-default]
       
       ;; Standard foreground colors (30-37)
       [(and (not is-background?) (<= 30 param 37))
        (case (- param 30)
          [(0) 'color-black] [(1) 'color-red] [(2) 'color-green] [(3) 'color-yellow]
          [(4) 'color-blue] [(5) 'color-magenta] [(6) 'color-cyan] [(7) 'color-white])]
       
       ;; Standard background colors (40-47)
       [(and is-background? (<= 40 param 47))
        (case (- param 40)
          [(0) 'color-black] [(1) 'color-red] [(2) 'color-green] [(3) 'color-yellow]
          [(4) 'color-blue] [(5) 'color-magenta] [(6) 'color-cyan] [(7) 'color-white])]
       
       [else 'color-default]))]
   
   ;; 256-color: [38|48];5;n
   [(and (= (length params) 3) 
         (or (= (car params) 38) (= (car params) 48))
         (= (cadr params) 5))
    (let ([index (caddr params)])
      (if (and (>= index 0) (< index 256))
	  (make-color-256 (caddr params))
	  'color-default))]
   
   ;; RGB color: [38|48];2;r;g;b
   [(and (= (length params) 5)
         (or (= (car params) 38) (= (car params) 48))
         (= (cadr params) 2))
    (let ([r (caddr params)] [g (cadddr params)] [b (list-ref params 4)])
      (if (and (byte? r) (byte? g) (byte? b))
          (make-color-rgb r g b)
          'color-default))]
   
   ;; Unknown format
   [else 'color-default]))

(define (rgb->color-256 red green blue)
  "Closest entry of the xterm 256-colour palette to an RGB colour: a
   grey from the 232-255 ramp for (near-)greys, otherwise the nearest
   entry of the 6x6x6 cube (levels 0, 95, 135, 175, 215, 255)."
  (define (cube-level v)                ; index 0-5 of the nearest cube level
    (cond [(< v 48) 0] [(< v 115) 1] [else (min 5 (quotient (- v 35) 40))]))
  (cond
   [(and (< (abs (- red green)) 10)
         (< (abs (- green blue)) 10)
         (< (abs (- red blue)) 10))
    ;; Grey ramp 232-255 has levels 8, 18, ..., 238
    (let ([gray (quotient (+ red green blue) 3)])
      (make-color-256 (+ 232 (max 0 (min 23 (round->exact (/ (- gray 8) 10)))))))]
   [else
    (make-color-256 (+ 16 (* 36 (cube-level red)) (* 6 (cube-level green)) (cube-level blue)))]))

(define (round->exact x) (inexact->exact (round x)))

(define (color-256->rgb index)
  "Convert 256-color palette entry to approximate RGB values"
  (cond
   ;; Standard colors (0-15) - approximate RGB values
   [(<= 0 index 15)
    (case index
      [(0) (make-color-rgb 0 0 0)]         ; Black
      [(1) (make-color-rgb 128 0 0)]       ; Dark Red
      [(2) (make-color-rgb 0 128 0)]       ; Dark Green  
      [(3) (make-color-rgb 128 128 0)]     ; Dark Yellow
      [(4) (make-color-rgb 0 0 128)]       ; Dark Blue
      [(5) (make-color-rgb 128 0 128)]     ; Dark Magenta
      [(6) (make-color-rgb 0 128 128)]     ; Dark Cyan
      [(7) (make-color-rgb 192 192 192)]   ; Light Gray
      [(8) (make-color-rgb 128 128 128)]   ; Dark Gray
      [(9) (make-color-rgb 255 0 0)]       ; Red
      [(10) (make-color-rgb 0 255 0)]      ; Green
      [(11) (make-color-rgb 255 255 0)]    ; Yellow
      [(12) (make-color-rgb 0 0 255)]      ; Blue
      [(13) (make-color-rgb 255 0 255)]    ; Magenta
      [(14) (make-color-rgb 0 255 255)]    ; Cyan
      [(15) (make-color-rgb 255 255 255)]  ; White
      [else (make-color-rgb 0 0 0)])]
   
   ;; 6x6x6 color cube (16-231)
   [(<= 16 index 231)
    (let* ([cube-index (- index 16)]
           [r6 (quotient cube-index 36)]
           [g6 (quotient (remainder cube-index 36) 6)]
           [b6 (remainder cube-index 6)]
           [scale (lambda (n) (if (= n 0) 0 (+ 55 (* n 40))))])
      (make-color-rgb (scale r6) (scale g6) (scale b6)))]
   
   ;; Grayscale ramp (232-255)
   [(<= 232 index 255)
    (let ([gray-level (+ 8 (* (- index 232) 10))])
      (make-color-rgb gray-level gray-level gray-level))]
   
   ;; Invalid index
   [else (make-color-rgb 0 0 0)]))


;;; =================================================================
;;; SGR ATTRIBUTE GROUPS AND SYMBOLS
;;; =================================================================

;;; Each group represents mutually exclusive attributes
(define intensity-values '(intensity-normal intensity-bold intensity-faint))
(define font-style-values '(font-style-normal font-style-italic font-style-fraktur))
(define underline-values '(underline-none underline-single underline-double))
(define blink-values '(blink-none blink-slow blink-rapid))
(define polarity-values '(polarity-positive polarity-negative))
(define visibility-values '(visibility-revealed visibility-concealed))
(define strikethrough-values '(strikethrough-normal strikethrough-crossed))
(define frame-values '(frame-none frame-framed frame-encircled))
(define overline-values '(overline-normal overline-overlined))
(define color-values '(color-default color-black color-red color-green color-yellow
                       color-blue color-magenta color-cyan color-white))

;;; =================================================================
;;; SGR RECORD TYPE
;;; =================================================================

(define-record-type <sgr>
  (%make-sgr intensity font-style underline blink polarity visibility 
            strikethrough font-family frame overline foreground-color background-color)
  sgr?
  ;; Mutually exclusive attribute groups
  (intensity sgr-intensity set-sgr-intensity!)           ; normal, bold, faint
  (font-style sgr-font-style set-sgr-font-style!)        ; normal, italic, fraktur
  (underline sgr-underline set-sgr-underline!)           ; none, single, double
  (blink sgr-blink set-sgr-blink!)                       ; none, slow, rapid
  (polarity sgr-polarity set-sgr-polarity!)              ; positive, negative
  (visibility sgr-visibility set-sgr-visibility!)         ; revealed, concealed
  (strikethrough sgr-strikethrough set-sgr-strikethrough!) ; normal, crossed
  (font-family sgr-font-family set-sgr-font-family!)     ; 0-9 (primary + alternatives)
  (frame sgr-frame set-sgr-frame!)                       ; none, framed, encircled
  (overline sgr-overline set-sgr-overline!)              ; normal, overlined
  (foreground-color sgr-foreground-color set-sgr-foreground-color!) ; 8 colors + default
  (background-color sgr-background-color set-sgr-background-color!)) ; 8 colors + default

;;; =================================================================
;;; CONSTRUCTORS AND UTILITIES
;;; =================================================================

(define* (make-sgr #:key 
                   (intensity 'intensity-normal)
                   (font-style 'font-style-normal)
                   (underline 'underline-none)
                   (blink 'blink-none)
                   (polarity 'polarity-positive)
                   (visibility 'visibility-revealed)
                   (strikethrough 'strikethrough-normal)
                   (font-family 0)
                   (frame 'frame-none)
                   (overline 'overline-normal)
                   (foreground-color 'color-default)
                   (background-color 'color-default))
  "Create an SGR record with specified attributes. All parameters are optional
   and default to normal/default values."
  (%make-sgr intensity font-style underline blink polarity visibility
            strikethrough font-family frame overline foreground-color background-color))

(define (make-default-sgr)
  "Create an SGR record with all default attributes"
  (make-sgr))

(define (sgr-invert-polarity sgr)
  "A copy of SGR in reverse video if it was not, or normal video if it was"
  (let ([new (sgr-copy sgr)])
    (set-sgr-polarity! new (if (eq? (sgr-polarity sgr) 'polarity-negative)
                               'polarity-positive
                               'polarity-negative))
    new))

(define (sgr-copy sgr)
  "Create a copy of an SGR record"
  (%make-sgr (sgr-intensity sgr)
            (sgr-font-style sgr)
            (sgr-underline sgr)
            (sgr-blink sgr)
            (sgr-polarity sgr)
            (sgr-visibility sgr)
            (sgr-strikethrough sgr)
            (sgr-font-family sgr)
            (sgr-frame sgr)
            (sgr-overline sgr)
            (sgr-foreground-color sgr)
            (sgr-background-color sgr)))

(define (sgr-reset! sgr)
  "Reset all SGR attributes to default values"
  (set-sgr-intensity! sgr 'intensity-normal)
  (set-sgr-font-style! sgr 'font-style-normal)
  (set-sgr-underline! sgr 'underline-none)
  (set-sgr-blink! sgr 'blink-none)
  (set-sgr-polarity! sgr 'polarity-positive)
  (set-sgr-visibility! sgr 'visibility-revealed)
  (set-sgr-strikethrough! sgr 'strikethrough-normal)
  (set-sgr-font-family! sgr 0)
  (set-sgr-frame! sgr 'frame-none)
  (set-sgr-overline! sgr 'overline-normal)
  (set-sgr-foreground-color! sgr 'color-default)
  (set-sgr-background-color! sgr 'color-default))

(define (sgr-equal? sgr1 sgr2)
  "Test if two SGR records have identical attributes"
  (and (eq? (sgr-intensity sgr1) (sgr-intensity sgr2))
       (eq? (sgr-font-style sgr1) (sgr-font-style sgr2))
       (eq? (sgr-underline sgr1) (sgr-underline sgr2))
       (eq? (sgr-blink sgr1) (sgr-blink sgr2))
       (eq? (sgr-polarity sgr1) (sgr-polarity sgr2))
       (eq? (sgr-visibility sgr1) (sgr-visibility sgr2))
       (eq? (sgr-strikethrough sgr1) (sgr-strikethrough sgr2))
       (eqv? (sgr-font-family sgr1) (sgr-font-family sgr2))
       (eq? (sgr-frame sgr1) (sgr-frame sgr2))
       (eq? (sgr-overline sgr1) (sgr-overline sgr2))
       (equal? (sgr-foreground-color sgr1) (sgr-foreground-color sgr2))
       (equal? (sgr-background-color sgr1) (sgr-background-color sgr2))))

;;; =================================================================
;;; ANSI SGR PARAMETER MAPPINGS
;;; =================================================================

;;; Mapping from ANSI SGR parameters to attribute symbols
(define sgr-parameters
  '((0  . reset)                    ; Reset all attributes
    (1  . intensity-bold)           ; Bold/bright
    (2  . intensity-faint)          ; Faint/dim
    (3  . font-style-italic)        ; Italic
    (4  . underline-single)         ; Single underline
    (5  . blink-slow)               ; Slow blink
    (6  . blink-rapid)              ; Rapid blink
    (7  . polarity-negative)        ; Negative/reverse video
    (8  . visibility-concealed)     ; Concealed/hidden
    (9  . strikethrough-crossed)    ; Crossed out/strikethrough
    (10 . font-family-primary)      ; Primary font
    (11 . font-family-alt-1)        ; Alternative font 1
    (12 . font-family-alt-2)        ; Alternative font 2
    (13 . font-family-alt-3)        ; Alternative font 3
    (14 . font-family-alt-4)        ; Alternative font 4
    (15 . font-family-alt-5)        ; Alternative font 5
    (16 . font-family-alt-6)        ; Alternative font 6
    (17 . font-family-alt-7)        ; Alternative font 7
    (18 . font-family-alt-8)        ; Alternative font 8
    (19 . font-family-alt-9)        ; Alternative font 9
    (20 . font-style-fraktur)       ; Fraktur font
    (21 . underline-double)         ; Double underline
    (22 . intensity-normal)         ; Normal intensity
    (23 . font-style-normal)        ; Not italic, not fraktur
    (24 . underline-none)           ; Not underlined
    (25 . blink-none)               ; Not blinking
    (27 . polarity-positive)        ; Positive image
    (28 . visibility-revealed)      ; Revealed characters
    (29 . strikethrough-normal)     ; Not crossed out
    (30 . color-black)              ; Black foreground
    (31 . color-red)                ; Red foreground
    (32 . color-green)              ; Green foreground
    (33 . color-yellow)             ; Yellow foreground
    (34 . color-blue)               ; Blue foreground
    (35 . color-magenta)            ; Magenta foreground
    (36 . color-cyan)               ; Cyan foreground
    (37 . color-white)              ; White foreground
    (39 . color-default)            ; Default foreground
    (40 . bg-color-black)           ; Black background
    (41 . bg-color-red)             ; Red background
    (42 . bg-color-green)           ; Green background
    (43 . bg-color-yellow)          ; Yellow background
    (44 . bg-color-blue)            ; Blue background
    (45 . bg-color-magenta)         ; Magenta background
    (46 . bg-color-cyan)            ; Cyan background
    (47 . bg-color-white)           ; White background
    (49 . bg-color-default)         ; Default background
    (51 . frame-framed)             ; Framed
    (52 . frame-encircled)          ; Encircled
    (53 . overline-overlined)       ; Overlined
    (54 . frame-none)               ; Not framed or encircled
    (55 . overline-normal)))        ; Not overlined

;;; Reverse mapping for generating ANSI sequences
(define parameter->attribute
  (let ((ht (make-hash-table)))
    (for-each (lambda (pair) 
                (hash-set! ht (car pair) (cdr pair))) 
              sgr-parameters)
    ht))

(define attribute->parameter
  (let ((ht (make-hash-table)))
    (for-each (lambda (pair) 
                (hash-set! ht (cdr pair) (car pair))) 
              sgr-parameters)
    ht))

;;; =================================================================
;;; SGR ATTRIBUTE APPLICATION
;;; =================================================================

(define (sgr-apply-attribute! sgr attribute)
  "Apply a single SGR attribute to an SGR record"
  (cond
   ;; Reset all attributes
   [(eq? attribute 'reset)
    (sgr-reset! sgr)]
   
   ;; Intensity group
   [(memq attribute intensity-values)
    (set-sgr-intensity! sgr attribute)]
   
   ;; Font style group
   [(memq attribute font-style-values)
    (set-sgr-font-style! sgr attribute)]
   
   ;; Underline group
   [(memq attribute underline-values)
    (set-sgr-underline! sgr attribute)]
   
   ;; Blink group
   [(memq attribute blink-values)
    (set-sgr-blink! sgr attribute)]
   
   ;; Polarity group
   [(memq attribute polarity-values)
    (set-sgr-polarity! sgr attribute)]
   
   ;; Visibility group
   [(memq attribute visibility-values)
    (set-sgr-visibility! sgr attribute)]
   
   ;; Strikethrough group
   [(memq attribute strikethrough-values)
    (set-sgr-strikethrough! sgr attribute)]
   
   ;; Frame group
   [(memq attribute frame-values)
    (set-sgr-frame! sgr attribute)]
   
   ;; Overline group
   [(memq attribute overline-values)
    (set-sgr-overline! sgr attribute)]
   
   ;; Font family (special handling for numbers)
   [(and (symbol? attribute) (string-prefix? "font-family-" (symbol->string attribute)))
    (let ([family-num (cond
                       [(eq? attribute 'font-family-primary) 0]
                       [(eq? attribute 'font-family-alt-1) 1]
                       [(eq? attribute 'font-family-alt-2) 2]
                       [(eq? attribute 'font-family-alt-3) 3]
                       [(eq? attribute 'font-family-alt-4) 4]
                       [(eq? attribute 'font-family-alt-5) 5]
                       [(eq? attribute 'font-family-alt-6) 6]
                       [(eq? attribute 'font-family-alt-7) 7]
                       [(eq? attribute 'font-family-alt-8) 8]
                       [(eq? attribute 'font-family-alt-9) 9]
                       [else 0])])
      (set-sgr-font-family! sgr family-num))]
   
   ;; Foreground colors (standard, 256-color, or RGB)
   [(or (memq attribute color-values)
        (color-256? attribute)
        (color-rgb? attribute))
    (set-sgr-foreground-color! sgr attribute)]
   
   ;; Background colors (with bg- prefix for standard colors)
   [(and (symbol? attribute) (string-prefix? "bg-" (symbol->string attribute)))
    (let ([color (string->symbol (substring (symbol->string attribute) 3))])
      (when (memq color color-values)
        (set-sgr-background-color! sgr color)))]
   
   ;; Unknown attribute
   [else
    (error "Unknown SGR attribute" attribute)]))

(define (sgr-apply-attributes! sgr attributes)
  "Apply a list of SGR attributes to an SGR record"
  (for-each (lambda (attr) (sgr-apply-attribute! sgr attr)) attributes))

(define (sgr-set-font-family! sgr family)
  "Set the font family: 0 (primary) to 9 (alternative fonts)"
  (unless (and (exact-integer? family) (<= 0 family 9))
    (error "Font family must be 0-9" family))
  (set-sgr-font-family! sgr family))

(define (sgr-set-foreground-color! sgr color)
  "Set foreground color (standard symbol, 256-color, or RGB)"
  (cond
   [(memq color color-values) (set-sgr-foreground-color! sgr color)]
   [(color-256? color) (set-sgr-foreground-color! sgr color)]
   [(color-rgb? color) (set-sgr-foreground-color! sgr color)]
   [else (error "Invalid color" color)]))

(define (sgr-set-background-color! sgr color)
  "Set background color (standard symbol, 256-color, or RGB)"
  (cond
   [(memq color color-values) (set-sgr-background-color! sgr color)]
   [(color-256? color) (set-sgr-background-color! sgr color)]
   [(color-rgb? color) (set-sgr-background-color! sgr color)]
   [else (error "Invalid color" color)]))

(define (sgr-from-parameters parameters)
  "Create an SGR record from a list of ANSI SGR parameters.
   Handles standard colors, 256-color (38;5;n and 48;5;n), and RGB (38;2;r;g;b and 48;2;r;g;b)"
  (let ([sgr (make-default-sgr)])
    (let loop ([params parameters])
      (unless (null? params)
        (let ([param (car params)]
              [rest (cdr params)])
          (cond
           ;; Standard SGR attributes
           [(hash-ref parameter->attribute param #f)
            => (lambda (attribute) 
                 (sgr-apply-attribute! sgr attribute)
                 (loop rest))]
           
           ;; Bright foreground 90-97 / background 100-107 (aixterm, xterm):
           ;; palette entries 8-15
           [(<= 90 param 97)
            (set-sgr-foreground-color! sgr (make-color-256 (- param 82)))
            (loop rest)]
           [(<= 100 param 107)
            (set-sgr-background-color! sgr (make-color-256 (- param 92)))
            (loop rest)]

           ;; 256-color foreground: 38;5;n
           [(and (= param 38) (>= (length rest) 2) (= (car rest) 5))
            (let ([color-index (cadr rest)])
              (when (<= 0 color-index 255)
                (set-sgr-foreground-color! sgr (make-color-256 color-index)))
              (loop (cddr rest)))]
           
           ;; RGB foreground: 38;2;r;g;b  
           [(and (= param 38) (>= (length rest) 4) (= (car rest) 2))
            (let ([r (cadr rest)]
                  [g (caddr rest)]
                  [b (cadddr rest)])
              (when (and (<= 0 r 255) (<= 0 g 255) (<= 0 b 255))
                (set-sgr-foreground-color! sgr (make-color-rgb r g b)))
              (loop (cddddr rest)))]
           
           ;; 256-color background: 48;5;n
           [(and (= param 48) (>= (length rest) 2) (= (car rest) 5))
            (let ([color-index (cadr rest)])
              (when (<= 0 color-index 255)
                (set-sgr-background-color! sgr (make-color-256 color-index)))
              (loop (cddr rest)))]
           
           ;; RGB background: 48;2;r;g;b
           [(and (= param 48) (>= (length rest) 4) (= (car rest) 2))
            (let ([r (cadr rest)]
                  [g (caddr rest)]
                  [b (cadddr rest)])
              (when (and (<= 0 r 255) (<= 0 g 255) (<= 0 b 255))
                (set-sgr-background-color! sgr (make-color-rgb r g b)))
              (loop (cddddr rest)))]
           
           ;; Unknown parameter, skip
           [else (loop rest)]))))
    sgr))

;;; =================================================================
;;; SGR RENDERING TO ANSI SEQUENCES
;;; =================================================================

(define (group-parameters attribute)
  "SGR parameters that select ATTRIBUTE (a group value symbol)"
  (list (hash-ref attribute->parameter attribute)))

(define (sgr-parameter-list sgr from)
  "SGR parameters that turn the attributes FROM into those of SGR, for
   the groups where they differ (FROM #f means: all non-default ones)."
  (define (changed? get default)
    (if from
        (not (equal? (get sgr) (get from)))
        (not (equal? (get sgr) default))))
  (append
   (if (changed? sgr-intensity 'intensity-normal)
       ;; going between bold and faint, end the old one first (22)
       (if (and from
                (not (eq? (sgr-intensity from) 'intensity-normal))
                (not (eq? (sgr-intensity sgr) 'intensity-normal)))
           (cons 22 (group-parameters (sgr-intensity sgr)))
           (group-parameters (sgr-intensity sgr)))
       '())
   (if (changed? sgr-font-style 'font-style-normal) (group-parameters (sgr-font-style sgr)) '())
   (if (changed? sgr-underline 'underline-none) (group-parameters (sgr-underline sgr)) '())
   (if (changed? sgr-blink 'blink-none) (group-parameters (sgr-blink sgr)) '())
   (if (changed? sgr-polarity 'polarity-positive) (group-parameters (sgr-polarity sgr)) '())
   (if (changed? sgr-visibility 'visibility-revealed) (group-parameters (sgr-visibility sgr)) '())
   (if (changed? sgr-strikethrough 'strikethrough-normal) (group-parameters (sgr-strikethrough sgr)) '())
   (if (changed? sgr-font-family 0) (list (+ 10 (sgr-font-family sgr))) '())
   (if (changed? sgr-frame 'frame-none) (group-parameters (sgr-frame sgr)) '())
   (if (changed? sgr-overline 'overline-normal) (group-parameters (sgr-overline sgr)) '())
   (if (changed? sgr-foreground-color 'color-default)
       (color->ansi-params (sgr-foreground-color sgr) #f) '())
   (if (changed? sgr-background-color 'color-default)
       (color->ansi-params (sgr-background-color sgr) #t) '())))

(define (csi-sgr params)
  (if (null? params)
      ""
      (string-append "\x1b[" (string-join (map number->string params) ";") "m")))

(define (sgr->ansi-sequence sgr)
  "ANSI sequence that sets SGR's non-default attributes, starting from
   the default state (\"\" if every attribute is the default)"
  (csi-sgr (sgr-parameter-list sgr #f)))

(define (sgr-differences sgr1 sgr2)
  "Return list of attributes that differ between two SGR records"
  (let ([diffs '()])
    (unless (eq? (sgr-intensity sgr1) (sgr-intensity sgr2))
      (set! diffs (cons 'intensity diffs)))
    (unless (eq? (sgr-font-style sgr1) (sgr-font-style sgr2))
      (set! diffs (cons 'font-style diffs)))
    (unless (eq? (sgr-underline sgr1) (sgr-underline sgr2))
      (set! diffs (cons 'underline diffs)))
    (unless (eq? (sgr-blink sgr1) (sgr-blink sgr2))
      (set! diffs (cons 'blink diffs)))
    (unless (eq? (sgr-polarity sgr1) (sgr-polarity sgr2))
      (set! diffs (cons 'polarity diffs)))
    (unless (eq? (sgr-visibility sgr1) (sgr-visibility sgr2))
      (set! diffs (cons 'visibility diffs)))
    (unless (eq? (sgr-strikethrough sgr1) (sgr-strikethrough sgr2))
      (set! diffs (cons 'strikethrough diffs)))
    (unless (= (sgr-font-family sgr1) (sgr-font-family sgr2))
      (set! diffs (cons 'font-family diffs)))
    (unless (eq? (sgr-frame sgr1) (sgr-frame sgr2))
      (set! diffs (cons 'frame diffs)))
    (unless (eq? (sgr-overline sgr1) (sgr-overline sgr2))
      (set! diffs (cons 'overline diffs)))
    (unless (equal? (sgr-foreground-color sgr1) (sgr-foreground-color sgr2))
      (set! diffs (cons 'foreground-color diffs)))
    (unless (equal? (sgr-background-color sgr1) (sgr-background-color sgr2))
      (set! diffs (cons 'background-color diffs)))
    diffs))

(define (sgr-minimal-sequence from-sgr to-sgr)
  "ANSI sequence that changes the terminal from FROM-SGR to TO-SGR,
   setting only the groups that differ (each group has an \"off\"
   parameter, so attributes can be turned off without a full reset).
   \"\" if nothing differs."
  (csi-sgr (sgr-parameter-list to-sgr from-sgr)))

(define (sgr-render-text text sgr-list)
  "ANSI output that draws TEXT with the attributes in SGR-LIST (one per
   character), starting from and ending in the default state.  Only the
   changes between neighbouring characters are sent."
  (unless (= (string-length text) (length sgr-list))
    (error "sgr-render-text: need one SGR per character"
           (string-length text) (length sgr-list)))
  (let ([default (make-default-sgr)]
        [out (open-output-string)])
    (let loop ([i 0] [sgrs sgr-list] [current default])
      (if (null? sgrs)
          (begin
            (display (sgr-minimal-sequence current default) out)
            (get-output-string out))
          (begin
            (unless (sgr-equal? current (car sgrs))
              (display (sgr-minimal-sequence current (car sgrs)) out))
            (write-char (string-ref text i) out)
            (loop (+ i 1) (cdr sgrs) (car sgrs)))))))
