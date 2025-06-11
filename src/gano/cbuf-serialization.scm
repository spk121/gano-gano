;;; Gano Character Buffer Serialization Module
;;; Import/export functionality for character buffers
;;; Supports JSON span format and plain text format

(define-module (gano cbuf-serialization)
  #:use-module (gano cbuf-core)     ; Core record definitions
  #:use-module (gano cbuf-utils)    ; Utility functions
  #:use-module (gano text-metrics)  ; Text metrics module
  #:use-module (gano rendering)     ; SGR support
  #:use-module (gano string-split)  ; String splitting and joining
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-13)       ; String utilities
  #:use-module (ice-9 textual-ports) ; get-string-all
  #:export (
    ;; JSON span format
    cbuf->json
    json->cbuf
    cbuf-save-json
    cbuf-load-json
    
    ;; Text format  
    cbuf->text
    text->cbuf
    cbuf-save-text
    cbuf-load-text
    
    ;; SGR/Color conversion utilities
    sgr->json
    json->sgr
    color->json
    json->color
    
    ;; Internal functions for advanced use
    text->cbuf-internal
    line-metrics->json-line
    json-line->metrics))

;;; =================================================================
;;; SGR TO/FROM JSON CONVERSION
;;; =================================================================

(define (sgr->json sgr)
  "Convert SGR record to JSON-compatible alist"
  (let ([json-obj '()])
    
    ;; Add non-default attributes
    (unless (eq? (sgr-intensity sgr) 'intensity-normal)
      (set! json-obj (cons `(intensity . ,(symbol->string (sgr-intensity sgr))) json-obj)))
    
    (unless (eq? (sgr-font-style sgr) 'font-style-normal)
      (set! json-obj (cons `(font_style . ,(symbol->string (sgr-font-style sgr))) json-obj)))
    
    (unless (eq? (sgr-underline sgr) 'underline-none)
      (set! json-obj (cons `(underline . ,(symbol->string (sgr-underline sgr))) json-obj)))
    
    (unless (eq? (sgr-blink sgr) 'blink-none)
      (set! json-obj (cons `(blink . ,(symbol->string (sgr-blink sgr))) json-obj)))
    
    (unless (eq? (sgr-polarity sgr) 'polarity-positive)
      (set! json-obj (cons `(polarity . ,(symbol->string (sgr-polarity sgr))) json-obj)))
    
    (unless (eq? (sgr-visibility sgr) 'visibility-revealed)
      (set! json-obj (cons `(visibility . ,(symbol->string (sgr-visibility sgr))) json-obj)))
    
    (unless (eq? (sgr-strikethrough sgr) 'strikethrough-normal)
      (set! json-obj (cons `(strikethrough . ,(symbol->string (sgr-strikethrough sgr))) json-obj)))
    
    (unless (= (sgr-font-family sgr) 0)
      (set! json-obj (cons `(font_family . ,(sgr-font-family sgr)) json-obj)))
    
    (unless (eq? (sgr-frame sgr) 'frame-none)
      (set! json-obj (cons `(frame . ,(symbol->string (sgr-frame sgr))) json-obj)))
    
    (unless (eq? (sgr-overline sgr) 'overline-normal)
      (set! json-obj (cons `(overline . ,(symbol->string (sgr-overline sgr))) json-obj)))
    
    ;; Handle foreground color
    (unless (eq? (sgr-foreground-color sgr) 'color-default)
      (set! json-obj (cons `(foreground_color . ,(color->json (sgr-foreground-color sgr))) json-obj)))
    
    ;; Handle background color
    (unless (eq? (sgr-background-color sgr) 'color-default)
      (set! json-obj (cons `(background_color . ,(color->json (sgr-background-color sgr))) json-obj)))
    
    json-obj))

(define (color->json color)
  "Convert color value to JSON representation"
  (cond
   ;; Standard colors
   [(symbol? color)
    `((type . "standard") (value . ,(symbol->string color)))]
   
   ;; 256-color palette
   [(color-256? color)
    `((type . "256color") (index . ,(color-256-index color)))]
   
   ;; RGB color
   [(color-rgb? color)
    `((type . "rgb") 
      (r . ,(color-rgb-red color))
      (g . ,(color-rgb-green color))
      (b . ,(color-rgb-blue color)))]
   
   [else
    `((type . "standard") (value . "color-default"))]))

(define (json->sgr json-obj)
  "Convert JSON object to SGR record"
  (let ([sgr (make-default-sgr)])
    
    ;; Apply each attribute if present
    (let ([intensity (assq 'intensity json-obj)])
      (when intensity
        (sgr-apply-attribute! sgr (string->symbol (cdr intensity)))))
    
    (let ([font-style (assq 'font_style json-obj)])
      (when font-style
        (sgr-apply-attribute! sgr (string->symbol (cdr font-style)))))
    
    (let ([underline (assq 'underline json-obj)])
      (when underline
        (sgr-apply-attribute! sgr (string->symbol (cdr underline)))))
    
    (let ([blink (assq 'blink json-obj)])
      (when blink
        (sgr-apply-attribute! sgr (string->symbol (cdr blink)))))
    
    (let ([polarity (assq 'polarity json-obj)])
      (when polarity
        (sgr-apply-attribute! sgr (string->symbol (cdr polarity)))))
    
    (let ([visibility (assq 'visibility json-obj)])
      (when visibility
        (sgr-apply-attribute! sgr (string->symbol (cdr visibility)))))
    
    (let ([strikethrough (assq 'strikethrough json-obj)])
      (when strikethrough
        (sgr-apply-attribute! sgr (string->symbol (cdr strikethrough)))))
    
    (let ([font-family (assq 'font_family json-obj)])
      (when font-family
        (set-sgr-font-family! sgr (cdr font-family))))
    
    (let ([frame (assq 'frame json-obj)])
      (when frame
        (sgr-apply-attribute! sgr (string->symbol (cdr frame)))))
    
    (let ([overline (assq 'overline json-obj)])
      (when overline
        (sgr-apply-attribute! sgr (string->symbol (cdr overline)))))
    
    ;; Handle colors
    (let ([fg-color (assq 'foreground_color json-obj)])
      (when fg-color
        (set-sgr-foreground-color! sgr (json->color (cdr fg-color)))))
    
    (let ([bg-color (assq 'background_color json-obj)])
      (when bg-color
        (set-sgr-background-color! sgr (json->color (cdr bg-color)))))
    
    sgr))

(define (json->color color-obj)
  "Convert JSON color object to color value"
  (let ([type (cdr (assq 'type color-obj))])
    (cond
     [(string=? type "standard")
      (string->symbol (cdr (assq 'value color-obj)))]
     
     [(string=? type "256color")
      (make-color-256 (cdr (assq 'index color-obj)))]
     
     [(string=? type "rgb")
      (make-color-rgb (cdr (assq 'r color-obj))
                      (cdr (assq 'g color-obj))
                      (cdr (assq 'b color-obj)))]
     
     [else 'color-default])))

;;; =================================================================
;;; JSON SPAN FORMAT SERIALIZATION
;;; =================================================================

(define (cbuf->json cbuf)
  "Convert cbuf to JSON span format"
  (let* ([lines (cbuf-text cbuf)]
         [metrics-list (cbuf-text-metrics cbuf)]
         [json-lines (map (lambda (line metrics)
                           (line-metrics->json-line line metrics))
                         lines metrics-list)])
    
    `((version . "1.0")
      (format . "spans")
      (lines . ,json-lines)
      (metadata . ((tab_size . ,(cbuf-tab-size cbuf))
                   (vert_tab_size . ,(cbuf-vert-tab-size cbuf))
                   (form_size . ,(cbuf-form-size cbuf))
                   (home_pos . ,(cbuf-home-pos cbuf))
                   (limit_pos . ,(cbuf-limit-pos cbuf))
                   (limit_type . ,(symbol->string (cbuf-limit-type cbuf)))
                   (cjk_mode . ,(cbuf-cjk? cbuf))
                   (line_ending . ,(cbuf-line-ending cbuf))
                   (default_grcm . ,(symbol->string (cbuf-default-grcm cbuf)))
                   (cursor . ((line . ,(cbuf-line-cur cbuf))
                             (data . ,(cbuf-x-data cbuf))
                             (cell . ,(cbuf-x-cell cbuf))
                             (goal . ,(cbuf-x-goal cbuf))))
                   (mark . ,(if (cbuf-mark-set? cbuf)
                               `((set . #t)
                                 (line . ,(cbuf-mark-line cbuf))
                                 (data . ,(cbuf-mark-x-data cbuf)))
                               `((set . #f))))
                   (current_sgr . ,(sgr->json (cbuf-current-sgr cbuf)))
                   (sgr_stack . ,(map sgr->json (cbuf-sgr-stack cbuf)))
                   (modified . ,(cbuf-modified? cbuf))
                   (bell . ,(cbuf-bell? cbuf)))))))

(define (line-metrics->json-line text metrics)
  "Convert a line's text and metrics to JSON line representation"
  (let ([spans (text-metrics-get-rendered-spans metrics)])
    `((text . ,text)
      (spans . ,(map (lambda (span)
                      (let ([span-text (car span)]
                            [span-sgr (cdr span)])
                        `((text . ,span-text)
                          (sgr . ,(sgr->json span-sgr)))))
                    spans)))))

(define (json->cbuf json-obj)
  "Convert JSON span format to cbuf"
  (let* ([version (cdr (assq 'version json-obj))]
         [format (cdr (assq 'format json-obj))]
         [lines (cdr (assq 'lines json-obj))]
         [metadata (cdr (assq 'metadata json-obj))])
    
    ;; Validate format
    (unless (and (string=? version "1.0") (string=? format "spans"))
      (error "Unsupported JSON format" version format))
    
    ;; Extract metadata
    (let* ([tab-size (cdr (assq 'tab_size metadata))]
           [vert-tab-size (cdr (assq 'vert_tab_size metadata))]
           [form-size (cdr (assq 'form_size metadata))]
           [home-pos (cdr (assq 'home_pos metadata))]
           [limit-pos (cdr (assq 'limit_pos metadata))]
           [limit-type (string->symbol (cdr (assq 'limit_type metadata)))]
           [cjk-mode (cdr (assq 'cjk_mode metadata))]
           [line-ending (cdr (assq 'line_ending metadata))]
           [default-grcm (string->symbol (cdr (assq 'default_grcm metadata)))]
           [cursor (cdr (assq 'cursor metadata))]
           [mark (cdr (assq 'mark metadata))]
           [current-sgr-json (cdr (assq 'current_sgr metadata))]
           [sgr-stack-json (cdr (assq 'sgr_stack metadata))]
           [modified (cdr (assq 'modified metadata))]
           [bell (cdr (assq 'bell metadata))])
      
      ;; Reconstruct text-metrics for each line
      (let* ([reconstructed-metrics 
              (map (lambda (line-obj)
                    (json-line->metrics (cdr (assq 'text line-obj))
                                       (cdr (assq 'spans line-obj))
                                       tab-size cjk-mode))
                   lines)]
             [cbuf (%make-cbuf reconstructed-metrics 0 0 0 0
                               tab-size vert-tab-size form-size 
                               home-pos limit-pos limit-type
                               cjk-mode modified #f 0 0 bell #f '()
                               (json->sgr current-sgr-json)
                               default-grcm
                               (map json->sgr sgr-stack-json)
                               line-ending)])
        
        ;; Set cursor position
        (let ([cursor-line (cdr (assq 'line cursor))]
              [cursor-data (cdr (assq 'data cursor))]
              [cursor-cell (cdr (assq 'cell cursor))]
              [cursor-goal (cdr (assq 'goal cursor))])
          (set-cbuf-line-cur! cbuf (max 0 (min cursor-line (- (cbuf-line-count cbuf) 1))))
          (set-cbuf-x-data! cbuf cursor-data)  ; Will be bracketed when position functions are called
          (set-cbuf-x-cell! cbuf cursor-cell)
          (set-cbuf-x-goal! cbuf cursor-goal))
        
        ;; Set mark if present
        (when (cdr (assq 'set mark))
          (set-cbuf-mark-set?! cbuf #t)
          (set-cbuf-mark-line! cbuf (max 0 (min (cdr (assq 'line mark)) (- (cbuf-line-count cbuf) 1))))
          (set-cbuf-mark-x-data! cbuf (cdr (assq 'data mark))))
        
        cbuf))))

(define (json-line->metrics text spans tab-size cjk-mode)
  "Reconstruct text-metrics from JSON line representation"
  (if (null? spans)
      ;; Empty line or line with no spans
      (compute-text-metrics text tab-size #:cjk? cjk-mode)
      
      ;; Reconstruct SGR list from spans
      (let ([sgr-list '()]
            [text-pos 0])
        
        ;; Process each span
        (for-each (lambda (span-obj)
                   (let ([span-text (cdr (assq 'text span-obj))]
                         [span-sgr-json (cdr (assq 'sgr span-obj))])
                     (let ([span-sgr (json->sgr span-sgr-json)]
                           [span-length (string-length span-text)])
                       ;; Add SGR for each character in span
                       (set! sgr-list (append sgr-list 
                                             (make-list span-length span-sgr)))
                       (set! text-pos (+ text-pos span-length)))))
                 spans)
        
        ;; Create text-metrics with reconstructed SGR list
        (compute-text-metrics-with-sgr text sgr-list tab-size #:cjk? cjk-mode))))

;;; =================================================================
;;; TEXT FORMAT SERIALIZATION
;;; =================================================================

(define (cbuf->text cbuf)
  "Convert cbuf to plain text using configured line endings"
  (let ([lines (cbuf-text cbuf)]
        [line-ending (cbuf-line-ending cbuf)])
    (string-join lines line-ending)))

(define* (text->cbuf text #:key (tab-size 8) (vert-tab-size 6) (form-size 66)
                     (cjk? #f) (default-grcm 'replacing) (line-ending "\n")
                     (strict? #t))
  "Convert plain text to cbuf with efficient validation and construction."
  
  (cond
   [(not strict?)
    ;; Permissive mode - build directly without validation
    (text->cbuf-internal text tab-size vert-tab-size form-size cjk? default-grcm line-ending)]
   
   [else
    ;; Strict mode - validate entire text efficiently, then build
    (let ([validation (validate-string-combining-marks text)])
      (if (car validation)
          ;; Text is valid - build normally
          (text->cbuf-internal text tab-size vert-tab-size form-size cjk? default-grcm line-ending)
          
          ;; Text has violations - raise error with first violation
          (let ([violations (cadr validation)])
            (when (not (null? violations))
              (let ([first-violation (car violations)])
                (case (car first-violation)
                  [(no-base-character)
                   (error "Input text contains combining mark without base character"
                          (cadr first-violation))]
                  
                  [(too-many-combining)
                   (error "Input text contains too many combining marks"
                          (cadr first-violation) (caddr first-violation)
                          (list-ref first-violation 4))])))))]))

(define (text->cbuf-internal text tab-size vert-tab-size form-size cjk? default-grcm line-ending)
  "Internal text->cbuf implementation without validation."
  (let* ([detected-ending (if (string=? line-ending "\n")
                             (detect-line-ending text)
                             line-ending)]
         [lines (string-split-lines text)]
         ;; Build all metrics in one pass
         [metrics (map (lambda (line) 
                        (compute-text-metrics line tab-size #:cjk? cjk?))
                      lines)])
    
    (%make-cbuf metrics 0 0 0 0 
               tab-size vert-tab-size form-size 0 79 'data
               cjk? #f #f 0 0 #f #f '()
               (make-default-sgr)
               default-grcm
               '()
               detected-ending)))

;;; =================================================================
;;; FILE I/O CONVENIENCE FUNCTIONS
;;; =================================================================

(define (cbuf-save-json cbuf filename)
  "Save cbuf to JSON file"
  (call-with-output-file filename
    (lambda (port)
      (write (cbuf->json cbuf) port))))

(define (cbuf-load-json filename)
  "Load cbuf from JSON file"
  (call-with-input-file filename
    (lambda (port)
      (json->cbuf (read port)))))

(define (cbuf-save-text cbuf filename)
  "Save cbuf to plain text file"
  (call-with-output-file filename
    (lambda (port)
      (display (cbuf->text cbuf) port))))

(define* (cbuf-load-text filename #:key (tab-size 8) (vert-tab-size 6) 
                         (form-size 66) (cjk? #f) (default-grcm 'replacing) 
                         (line-ending "\n") (strict? #t))
  "Load cbuf from plain text file"
  (call-with-input-file filename
    (lambda (port)
      (let ([text (get-string-all port)])
        (text->cbuf text #:tab-size tab-size #:vert-tab-size vert-tab-size
                    #:form-size form-size #:cjk? cjk? #:default-grcm default-grcm
                    #:line-ending line-ending #:strict? strict?)))))
                    