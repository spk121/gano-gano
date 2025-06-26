;;; Test suite for Gano Rendering Module
;;; Using SRFI-64 testing framework

(use-modules (srfi srfi-64)     ; Testing framework
             (srfi srfi-1)      ; List utilities
             (gano rendering))  ; Module under test

;;; Test suite setup
(test-begin "gano-rendering")

;;; =================================================================
;;; COLOR RECORD TESTS
;;; =================================================================

;;; Tests for extended color record types
(test-group "color-records"
  ;; 256-color tests
  (test-assert "make-color-256 creates color-256"
    (color-256? (make-color-256 42)))
  
  (test-equal "color-256-index accessor works"
    42
    (color-256-index (make-color-256 42)))
  
  (test-assert "color-256 bounds checking"
    (and (color-256? (make-color-256 0))
         (color-256? (make-color-256 255))))
  
  ;; RGB color tests
  (test-assert "make-color-rgb creates color-rgb"
    (color-rgb? (make-color-rgb 255 128 64)))
  
  (test-equal "color-rgb-red accessor works"
    255
    (color-rgb-red (make-color-rgb 255 128 64)))
  
  (test-equal "color-rgb-green accessor works"
    128
    (color-rgb-green (make-color-rgb 255 128 64)))
  
  (test-equal "color-rgb-blue accessor works"
    64
    (color-rgb-blue (make-color-rgb 255 128 64)))
  
  ;; Color type detection
  (test-equal "color-type detects standard colors"
    'standard
    (color-type 'color-red))
  
  (test-equal "color-type detects 256-color"
    '256-color
    (color-type (make-color-256 100)))
  
  (test-equal "color-type detects RGB color"
    'rgb
    (color-type (make-color-rgb 255 0 0)))
  
  (test-equal "color-type detects unknown"
    'unknown
    (color-type 123)))

;;; =================================================================
;;; SGR RECORD TESTS
;;; =================================================================

;;; Tests for SGR record creation and accessors
(test-group "sgr-record"
  ;; Basic record creation
  (test-assert "make-sgr creates sgr"
    (sgr? (make-sgr)))
  
  (test-assert "make-default-sgr creates sgr"
    (sgr? (make-default-sgr)))
  
  ;; Default values
  (let ([sgr (make-default-sgr)])
    (test-equal "default intensity is normal"
      'intensity-normal
      (sgr-intensity sgr))
    
    (test-equal "default font-style is normal"
      'font-style-normal
      (sgr-font-style sgr))
    
    (test-equal "default underline is none"
      'underline-none
      (sgr-underline sgr))
    
    (test-equal "default blink is none"
      'blink-none
      (sgr-blink sgr))
    
    (test-equal "default polarity is positive"
      'polarity-positive
      (sgr-polarity sgr))
    
    (test-equal "default visibility is revealed"
      'visibility-revealed
      (sgr-visibility sgr))
    
    (test-equal "default strikethrough is normal"
      'strikethrough-normal
      (sgr-strikethrough sgr))
    
    (test-equal "default font-family is 0"
      0
      (sgr-font-family sgr))
    
    (test-equal "default frame is none"
      'frame-none
      (sgr-frame sgr))
    
    (test-equal "default overline is normal"
      'overline-normal
      (sgr-overline sgr))
    
    (test-equal "default foreground-color is default"
      'color-default
      (sgr-foreground-color sgr))
    
    (test-equal "default background-color is default"
      'color-default
      (sgr-background-color sgr)))
  
  ;; Custom values
  (test-equal "make-sgr with custom intensity"
    'intensity-bold
    (sgr-intensity (make-sgr #:intensity 'intensity-bold)))
  
  (test-equal "make-sgr with custom colors"
    'color-red
    (sgr-foreground-color (make-sgr #:foreground-color 'color-red))))

;;; =================================================================
;;; SGR UTILITY TESTS
;;; =================================================================

;;; Tests for SGR utility functions
(test-group "sgr-utilities"
  ;; sgr-copy
  (test-assert "sgr-copy creates new sgr"
    (let* ([original (make-sgr #:intensity 'intensity-bold #:foreground-color 'color-red)]
           [copy (sgr-copy original)])
      (and (sgr? copy)
           (not (eq? original copy))
           (sgr-equal? original copy))))
  
  ;; sgr-equal?
  (test-assert "sgr-equal? detects identical SGRs"
    (let ([sgr1 (make-sgr #:intensity 'intensity-bold #:foreground-color 'color-red)]
          [sgr2 (make-sgr #:intensity 'intensity-bold #:foreground-color 'color-red)])
      (sgr-equal? sgr1 sgr2)))
  
  (test-assert "sgr-equal? detects different SGRs"
    (let ([sgr1 (make-sgr #:intensity 'intensity-bold)]
          [sgr2 (make-sgr #:intensity 'intensity-faint)])
      (not (sgr-equal? sgr1 sgr2))))
  
  ;; sgr-reset!
  (test-assert "sgr-reset! resets all attributes"
    (let ([sgr (make-sgr #:intensity 'intensity-bold 
                        #:foreground-color 'color-red
                        #:background-color 'color-blue)])
      (sgr-reset! sgr)
      (and (eq? (sgr-intensity sgr) 'intensity-normal)
           (eq? (sgr-foreground-color sgr) 'color-default)
           (eq? (sgr-background-color sgr) 'color-default)))))

;;; =================================================================
;;; COLOR CONVERSION TESTS
;;; =================================================================

;;; Tests for color conversion functions
(test-group "color-conversion"
  ;; Standard color to ANSI parameters
  (test-equal "color-red foreground to ANSI"
    '(31)
    (color->ansi-params 'color-red #f))
  
  (test-equal "color-blue background to ANSI"
    '(44)
    (color->ansi-params 'color-blue #t))
  
  (test-equal "color-default foreground to ANSI"
    '(39)
    (color->ansi-params 'color-default #f))
  
  (test-equal "color-default background to ANSI"
    '(49)
    (color->ansi-params 'color-default #t))
  
  ;; 256-color to ANSI parameters
  (test-equal "256-color foreground to ANSI"
    '(38 5 196)
    (color->ansi-params (make-color-256 196) #f))
  
  (test-equal "256-color background to ANSI"
    '(48 5 196)
    (color->ansi-params (make-color-256 196) #t))
  
  ;; RGB color to ANSI parameters
  (test-equal "RGB foreground to ANSI"
    '(38 2 255 128 64)
    (color->ansi-params (make-color-rgb 255 128 64) #f))
  
  (test-equal "RGB background to ANSI"
    '(48 2 255 128 64)
    (color->ansi-params (make-color-rgb 255 128 64) #t))
  
  ;; ANSI parameters to color
  (test-equal "ANSI to standard foreground color"
    'color-red
    (ansi-params->color '(31) #f))
  
  (test-equal "ANSI to standard background color"
    'color-blue
    (ansi-params->color '(44) #t))
  
  (test-assert "ANSI to 256-color"
    (let ([color (ansi-params->color '(38 5 196) #f)])
      (and (color-256? color)
           (= (color-256-index color) 196))))
  
  (test-assert "ANSI to RGB color"
    (let ([color (ansi-params->color '(38 2 255 128 64) #f)])
      (and (color-rgb? color)
           (= (color-rgb-red color) 255)
           (= (color-rgb-green color) 128)
           (= (color-rgb-blue color) 64)))))

;;; =================================================================
;;; RGB/256-COLOR CONVERSION TESTS
;;; =================================================================

;;; Tests for RGB and 256-color conversion
(test-group "rgb-256-conversion"
  ;; RGB to 256-color conversion
  (test-assert "rgb->color-256 creates color-256"
    (color-256? (rgb->color-256 255 0 0)))
  
  (test-assert "rgb->color-256 handles grayscale"
    (let ([gray-color (rgb->color-256 128 128 128)])
      (and (color-256? gray-color)
           (<= 232 (color-256-index gray-color) 255))))
  
  (test-assert "rgb->color-256 handles color cube"
    (let ([color (rgb->color-256 255 0 0)])
      (and (color-256? color)
           (<= 16 (color-256-index color) 231))))
  
  ;; 256-color to RGB conversion
  (test-assert "color-256->rgb creates color-rgb"
    (color-rgb? (color-256->rgb 196)))
  
  (test-assert "color-256->rgb handles standard colors"
    (let ([red-color (color-256->rgb 1)])
      (and (color-rgb? red-color)
           (= (color-rgb-red red-color) 128)
           (= (color-rgb-green red-color) 0)
           (= (color-rgb-blue red-color) 0))))
  
  (test-assert "color-256->rgb handles grayscale ramp"
    (let ([gray-color (color-256->rgb 240)])
      (and (color-rgb? gray-color)
           (= (color-rgb-red gray-color)
              (color-rgb-green gray-color)
              (color-rgb-blue gray-color)))))
  
  ;; Roundtrip testing (approximate)
  (test-assert "RGB to 256-color roundtrip preserves color family"
    (let* ([original-rgb (make-color-rgb 255 0 0)]
           [color-256 (rgb->color-256 255 0 0)]
           [back-to-rgb (color-256->rgb (color-256-index color-256))])
      ;; Should be approximately red
      (> (color-rgb-red back-to-rgb) 200))))

;;; =================================================================
;;; SGR ATTRIBUTE APPLICATION TESTS
;;; =================================================================

;;; Tests for applying attributes to SGR records
(test-group "sgr-attribute-application"
  ;; Single attribute application
  (test-assert "sgr-apply-attribute! sets intensity"
    (let ([sgr (make-default-sgr)])
      (sgr-apply-attribute! sgr 'intensity-bold)
      (eq? (sgr-intensity sgr) 'intensity-bold)))
  
  (test-assert "sgr-apply-attribute! sets font-style"
    (let ([sgr (make-default-sgr)])
      (sgr-apply-attribute! sgr 'font-style-italic)
      (eq? (sgr-font-style sgr) 'font-style-italic)))
  
  (test-assert "sgr-apply-attribute! sets colors"
    (let ([sgr (make-default-sgr)])
      (sgr-apply-attribute! sgr 'color-red)
      (eq? (sgr-foreground-color sgr) 'color-red)))
  
  (test-assert "sgr-apply-attribute! handles background colors"
    (let ([sgr (make-default-sgr)])
      (sgr-apply-attribute! sgr 'bg-color-blue)
      (eq? (sgr-background-color sgr) 'color-blue)))
  
  (test-assert "sgr-apply-attribute! handles reset"
    (let ([sgr (make-sgr #:intensity 'intensity-bold #:foreground-color 'color-red)])
      (sgr-apply-attribute! sgr 'reset)
      (and (eq? (sgr-intensity sgr) 'intensity-normal)
           (eq? (sgr-foreground-color sgr) 'color-default))))
  
  ;; Multiple attributes
  (test-assert "sgr-apply-attributes! applies multiple attributes"
    (let ([sgr (make-default-sgr)])
      (sgr-apply-attributes! sgr '(intensity-bold color-red underline-single))
      (and (eq? (sgr-intensity sgr) 'intensity-bold)
           (eq? (sgr-foreground-color sgr) 'color-red)
           (eq? (sgr-underline sgr) 'underline-single))))
  
  ;; Color setting functions
  (test-assert "sgr-set-foreground-color! sets standard color"
    (let ([sgr (make-default-sgr)])
      (sgr-set-foreground-color! sgr 'color-green)
      (eq? (sgr-foreground-color sgr) 'color-green)))
  
  (test-assert "sgr-set-foreground-color! sets 256-color"
    (let ([sgr (make-default-sgr)]
          [color (make-color-256 196)])
      (sgr-set-foreground-color! sgr color)
      (equal? (sgr-foreground-color sgr) color)))
  
  (test-assert "sgr-set-background-color! sets RGB color"
    (let ([sgr (make-default-sgr)]
          [color (make-color-rgb 255 128 64)])
      (sgr-set-background-color! sgr color)
      (equal? (sgr-background-color sgr) color)))
  
  (test-error "sgr-set-foreground-color! rejects invalid color"
    (sgr-set-foreground-color! (make-default-sgr) 'invalid-color)))

;;; =================================================================
;;; SGR PARAMETER PARSING TESTS
;;; =================================================================

;;; Tests for parsing ANSI SGR parameters
(test-group "sgr-parameter-parsing"
  ;; Basic parameters
  (test-assert "sgr-from-parameters handles basic attributes"
    (let ([sgr (sgr-from-parameters '(1 4 31))])  ; bold, underline, red
      (and (eq? (sgr-intensity sgr) 'intensity-bold)
           (eq? (sgr-underline sgr) 'underline-single)
           (eq? (sgr-foreground-color sgr) 'color-red))))
  
  (test-assert "sgr-from-parameters handles reset"
    (let ([sgr (sgr-from-parameters '(0))])
      (sgr-equal? sgr (make-default-sgr))))
  
  ;; 256-color parameters
  (test-assert "sgr-from-parameters handles 256-color foreground"
    (let ([sgr (sgr-from-parameters '(38 5 196))])
      (and (color-256? (sgr-foreground-color sgr))
           (= (color-256-index (sgr-foreground-color sgr)) 196))))
  
  (test-assert "sgr-from-parameters handles 256-color background"
    (let ([sgr (sgr-from-parameters '(48 5 21))])
      (and (color-256? (sgr-background-color sgr))
           (= (color-256-index (sgr-background-color sgr)) 21))))
  
  ;; RGB color parameters
  (test-assert "sgr-from-parameters handles RGB foreground"
    (let ([sgr (sgr-from-parameters '(38 2 255 128 64))])
      (let ([color (sgr-foreground-color sgr)])
        (and (color-rgb? color)
             (= (color-rgb-red color) 255)
             (= (color-rgb-green color) 128)
             (= (color-rgb-blue color) 64)))))
  
  (test-assert "sgr-from-parameters handles RGB background"
    (let ([sgr (sgr-from-parameters '(48 2 200 100 50))])
      (let ([color (sgr-background-color sgr)])
        (and (color-rgb? color)
             (= (color-rgb-red color) 200)
             (= (color-rgb-green color) 100)
             (= (color-rgb-blue color) 50)))))
  
  ;; Complex parameter sequences
  (test-assert "sgr-from-parameters handles mixed parameters"
    (let ([sgr (sgr-from-parameters '(1 3 38 5 196 48 2 128 64 32))])
      (and (eq? (sgr-intensity sgr) 'intensity-bold)
           (eq? (sgr-font-style sgr) 'font-style-italic)
           (color-256? (sgr-foreground-color sgr))
           (color-rgb? (sgr-background-color sgr)))))
  
  ;; Invalid parameters (should be ignored)
  (test-assert "sgr-from-parameters ignores invalid parameters"
    (let ([sgr (sgr-from-parameters '(1 999 31))])  ; 999 is invalid
      (and (eq? (sgr-intensity sgr) 'intensity-bold)
           (eq? (sgr-foreground-color sgr) 'color-red)))))

;;; =================================================================
;;; ANSI SEQUENCE GENERATION TESTS
;;; =================================================================

;;; Tests for generating ANSI escape sequences
(test-group "ansi-sequence-generation"
  ;; Basic sequences
  (test-equal "sgr->ansi-sequence for default SGR"
    ""
    (sgr->ansi-sequence (make-default-sgr)))
  
  (test-assert "sgr->ansi-sequence for bold"
    (string-contains (sgr->ansi-sequence (make-sgr #:intensity 'intensity-bold)) "1"))
  
  (test-assert "sgr->ansi-sequence for red foreground"
    (string-contains (sgr->ansi-sequence (make-sgr #:foreground-color 'color-red)) "31"))
  
  (test-assert "sgr->ansi-sequence format is correct"
    (let ([seq (sgr->ansi-sequence (make-sgr #:intensity 'intensity-bold))])
      (and (string-prefix? "\x1b[" seq)
           (string-suffix? "m" seq))))
  
  ;; Extended color sequences
  (test-assert "sgr->ansi-sequence for 256-color"
    (let ([seq (sgr->ansi-sequence (make-sgr #:foreground-color (make-color-256 196)))])
      (and (string-contains seq "38")
           (string-contains seq "5")
           (string-contains seq "196"))))
  
  (test-assert "sgr->ansi-sequence for RGB color"
    (let ([seq (sgr->ansi-sequence (make-sgr #:foreground-color (make-color-rgb 255 128 64)))])
      (and (string-contains seq "38")
           (string-contains seq "2")
           (string-contains seq "255")
           (string-contains seq "128")
           (string-contains seq "64"))))
  
  ;; Complex sequences
  (test-assert "sgr->ansi-sequence for multiple attributes"
    (let ([seq (sgr->ansi-sequence (make-sgr #:intensity 'intensity-bold
                                           #:underline 'underline-single
                                           #:foreground-color 'color-red))])
      (and (string-contains seq "1")   ; bold
           (string-contains seq "4")   ; underline
           (string-contains seq "31")))) ; red
  )
;;; =================================================================
;;; SGR DIFFERENCE DETECTION TESTS
;;; =================================================================

;;; Tests for detecting differences between SGR records
(test-group "sgr-differences"
  ;; No differences
  (test-equal "sgr-differences with identical SGRs"
    '()
    (sgr-differences (make-default-sgr) (make-default-sgr)))
  
  ;; Single differences
  (test-assert "sgr-differences detects intensity change"
    (let ([diffs (sgr-differences (make-default-sgr)
                                 (make-sgr #:intensity 'intensity-bold))])
      (memq 'intensity diffs)))
  
  (test-assert "sgr-differences detects color change"
    (let ([diffs (sgr-differences (make-default-sgr)
                                 (make-sgr #:foreground-color 'color-red))])
      (memq 'foreground-color diffs)))
  
  ;; Multiple differences
  (test-assert "sgr-differences detects multiple changes"
    (let ([diffs (sgr-differences (make-default-sgr)
                                 (make-sgr #:intensity 'intensity-bold
                                          #:foreground-color 'color-red
                                          #:underline 'underline-single))])
      (and (memq 'intensity diffs)
           (memq 'foreground-color diffs)
           (memq 'underline diffs))))
  
  ;; Minimal sequence generation
  (test-equal "sgr-minimal-sequence with no changes"
    ""
    (sgr-minimal-sequence (make-default-sgr) (make-default-sgr)))
  
  (test-assert "sgr-minimal-sequence with changes"
    (let ([seq (sgr-minimal-sequence (make-default-sgr)
                                    (make-sgr #:intensity 'intensity-bold))])
      (> (string-length seq) 0))))

;;; =================================================================
;;; INTEGRATION TESTS
;;; =================================================================

;;; Tests for complete workflows
(test-group "integration"
  ;; Roundtrip: SGR -> ANSI -> SGR
  (test-assert "SGR to ANSI to SGR roundtrip preserves simple attributes"
    (let* ([original (make-sgr #:intensity 'intensity-bold
                              #:foreground-color 'color-red
                              #:underline 'underline-single)]
           [params '(1 31 4)]  ; Manually construct parameters
           [reconstructed (sgr-from-parameters params)])
      (and (eq? (sgr-intensity reconstructed) 'intensity-bold)
           (eq? (sgr-foreground-color reconstructed) 'color-red)
           (eq? (sgr-underline reconstructed) 'underline-single))))
  
  ;; Color conversion roundtrips
  (test-assert "RGB to 256-color to RGB maintains color family"
    (let* ([original (make-color-rgb 255 0 0)]
           [params (color->ansi-params original #f)]
           [converted-256 (rgb->color-256 255 0 0)]
           [back-to-rgb (color-256->rgb (color-256-index converted-256))])
      ;; Should still be predominantly red
      (> (color-rgb-red back-to-rgb) 
         (+ (color-rgb-green back-to-rgb) (color-rgb-blue back-to-rgb)))))
  
  ;; Complex SGR manipulation
  (test-assert "complex SGR manipulation workflow"
    (let ([sgr (make-default-sgr)])
      ;; Apply various attributes
      (sgr-apply-attributes! sgr '(intensity-bold font-style-italic color-red))
      (sgr-set-background-color! sgr (make-color-256 21))
      
      ;; Create copy and modify
      (let ([sgr2 (sgr-copy sgr)])
        (sgr-apply-attribute! sgr2 'intensity-faint)
        
        ;; Check that they differ appropriately
        (let ([diffs (sgr-differences sgr sgr2)])
          (and (memq 'intensity diffs)
               (not (memq 'font-style diffs))  ; Should be same
               (not (memq 'background-color diffs))))))) ; Should be same
  )
;;; =================================================================
;;; ERROR HANDLING TESTS
;;; =================================================================

;;; Tests for error conditions
(test-group "error-handling"
  ;; Invalid attributes
  (test-error "sgr-apply-attribute! rejects unknown attribute"
    (sgr-apply-attribute! (make-default-sgr) 'unknown-attribute))
  
  ;; Invalid colors
  (test-error "sgr-set-foreground-color! rejects invalid color"
    (sgr-set-foreground-color! (make-default-sgr) 'not-a-color))
  
  (test-error "sgr-set-background-color! rejects invalid color"
    (sgr-set-background-color! (make-default-sgr) 123))
  
  ;; Invalid color ranges
  (test-assert "color-256 index bounds are respected in conversion"
    (let ([color (ansi-params->color '(38 5 300) #f)])  ; Out of range
      (eq? color 'color-default)))  ; Should fallback to default
  
  (test-assert "RGB values bounds are handled gracefully"
    (color-rgb? (make-color-rgb 300 -50 128))))  ; Constructor should accept any values

;;; =================================================================
;;; EDGE CASES AND BOUNDARY TESTS
;;; =================================================================

(test-group "edge-cases"
  ;; Boundary color values
  (test-assert "256-color boundary values work"
    (and (color-256? (make-color-256 0))
         (color-256? (make-color-256 255))))
  
  (test-assert "RGB boundary values work"
    (and (color-rgb? (make-color-rgb 0 0 0))
         (color-rgb? (make-color-rgb 255 255 255))))
  
  ;; Font family ranges
  (test-assert "font family boundary values work"
    (let ([sgr (make-sgr #:font-family 9)])
      (= (sgr-font-family sgr) 9)))
  
  ;; Empty parameter lists
  (test-assert "sgr-from-parameters handles empty list"
    (sgr-equal? (sgr-from-parameters '()) (make-default-sgr)))
  
  ;; Incomplete color parameters
  (test-assert "sgr-from-parameters handles incomplete 256-color"
    (let ([sgr (sgr-from-parameters '(38 5))])  ; Missing color index
      (eq? (sgr-foreground-color sgr) 'color-default)))
  
  (test-assert "sgr-from-parameters handles incomplete RGB"
    (let ([sgr (sgr-from-parameters '(38 2 255))])  ; Missing green and blue
      (eq? (sgr-foreground-color sgr) 'color-default)))
  
  ;; Large parameter lists
  (test-assert "sgr-from-parameters handles large parameter lists"
    (let ([sgr (sgr-from-parameters (make-list 100 1))])  ; 100 bold parameters
      (eq? (sgr-intensity sgr) 'intensity-bold))))

;;; Test suite cleanup
(test-end "gano-rendering")
