;;; Gano Character Buffer Serialization Module - Updated Version
;;; Import/export functionality for character buffers
;;; Supports JSON span format and plain text format
;;; Updated to align with cbuf-core and cbuf-basic changes

(define-module (gano cbuf-serialization)
  #:use-module (gano cbuf-core)     ; Core record definitions
  #:use-module (gano cbuf-basic)    ; Basic operations (for load/save)
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
    
    ;; Text format (now delegates to cbuf-basic)
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
    line-metrics->json-line
    json-line->metrics
    
    ;; Version information
    cbuf-serialization-version))

;;; =================================================================
;;; VERSION AND COMPATIBILITY
;;; =================================================================

(define cbuf-serialization-version "2.0")  ; Updated for new cbuf structure

;;; =================================================================
;;; SGR TO/FROM JSON CONVERSION (Updated)
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
;;; JSON SPAN FORMAT SERIALIZATION (Updated)
;;; =================================================================

(define (cbuf->json cbuf)
  "Convert cbuf to JSON span format with all current fields"
  (let* ([lines (cbuf-text cbuf)]
         [metrics-list (cbuf-text-metrics cbuf)]
         [json-lines (map (lambda (line metrics)
                           (line-metrics->json-line line metrics))
                         lines metrics-list)])
    
    `((version . ,cbuf-serialization-version)
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
                   
                   ;; NEW: Final newline handling
                   (final_newline . ,(cbuf-final-newline? cbuf))
                   (final_newline_policy . ,(symbol->string (cbuf-final-newline-policy cbuf)))
                   
                   ;; Cursor state
                   (cursor . ((line . ,(cbuf-line-cur cbuf))
                             (data . ,(cbuf-x-data cbuf))
                             (cell . ,(cbuf-x-cell cbuf))
                             (goal . ,(cbuf-x-goal cbuf))))
                   
                   ;; Mark state
                   (mark . ,(if (cbuf-mark-set? cbuf)
                               `((set . #t)
                                 (line . ,(cbuf-mark-line cbuf))
                                 (data . ,(cbuf-mark-x-data cbuf)))
                               `((set . #f))))
                   
                   ;; SGR state
                   (current_sgr . ,(sgr->json (cbuf-current-sgr cbuf)))
                   (sgr_stack . ,(map sgr->json (cbuf-sgr-stack cbuf)))
                   
                   ;; Buffer state
                   (modified . ,(cbuf-modified? cbuf))
                   (bell . ,(cbuf-bell? cbuf))
                   
                   ;; Optional: Cut buffer (if you want to serialize it)
                   (cut_buffer . ,(cbuf-cut-buffer cbuf))
                   
                   ;; Note: undo-list is intentionally NOT serialized for security/size reasons
                   )))))

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
  "Convert JSON span format to cbuf (updated for new cbuf structure)"
  (let* ([version (cdr (assq 'version json-obj))]
         [format (cdr (assq 'format json-obj))]
         [lines (cdr (assq 'lines json-obj))]
         [metadata (cdr (assq 'metadata json-obj))])
    
    ;; Validate format (support both old and new versions)
    (unless (and (member version '("1.0" "2.0")) (string=? format "spans"))
      (error "Unsupported JSON format" version format))
    
    ;; Extract metadata with defaults for missing fields
    (let* ([tab-size (or (assq-ref metadata 'tab_size) 8)]
           [vert-tab-size (or (assq-ref metadata 'vert_tab_size) 6)]
           [form-size (or (assq-ref metadata 'form_size) 66)]
           [home-pos (or (assq-ref metadata 'home_pos) 0)]
           [limit-pos (or (assq-ref metadata 'limit_pos) 79)]
           [limit-type (string->symbol (or (assq-ref metadata 'limit_type) "data"))]
           [cjk-mode (or (assq-ref metadata 'cjk_mode) #f)]
           [line-ending (or (assq-ref metadata 'line_ending) "\n")]
           [default-grcm (string->symbol (or (assq-ref metadata 'default_grcm) "replacing"))]
           
           ;; NEW: Final newline fields (with defaults for old format)
           [final-newline? (or (assq-ref metadata 'final_newline) #t)]
           [final-newline-policy (string->symbol (or (assq-ref metadata 'final_newline_policy) "preserve"))]
           
           [cursor (or (assq-ref metadata 'cursor) '((line . 0) (data . 0) (cell . 0) (goal . 0)))]
           [mark (or (assq-ref metadata 'mark) '((set . #f)))]
           [current-sgr-json (or (assq-ref metadata 'current_sgr) '())]
           [sgr-stack-json (or (assq-ref metadata 'sgr_stack) '())]
           [modified (or (assq-ref metadata 'modified) #f)]
           [bell (or (assq-ref metadata 'bell) #f)]
           [cut-buffer (or (assq-ref metadata 'cut_buffer) '())])
      
      ;; Reconstruct text-metrics for each line
      (let* ([reconstructed-metrics 
              (map (lambda (line-obj)
                    (json-line->metrics (assq-ref line-obj 'text)
                                       (assq-ref line-obj 'spans)
                                       tab-size cjk-mode))
                   lines)]
             
             ;; Create cbuf using updated constructor signature
             [cbuf (%make-cbuf reconstructed-metrics 0 0 0 0
                               tab-size vert-tab-size form-size 
                               home-pos limit-pos limit-type
                               cjk-mode modified #f 0 0 bell cut-buffer '()
                               (if (null? current-sgr-json) 
                                   (make-default-sgr) 
                                   (json->sgr current-sgr-json))
                               default-grcm
                               (map json->sgr sgr-stack-json)
                               line-ending
                               final-newline?
                               final-newline-policy)])
        
        ;; Set cursor position using safe methods
        (let ([cursor-line (or (assq-ref cursor 'line) 0)]
              [cursor-data (or (assq-ref cursor 'data) 0)]
              [cursor-cell (or (assq-ref cursor 'cell) 0)]
              [cursor-goal (or (assq-ref cursor 'goal) 0)])
          (set-cbuf-line-cur! cbuf (cbuf-bracket-line cbuf cursor-line))
          (set-cbuf-x-data! cbuf (cbuf-bracket-x-data cbuf cursor-data))
          (set-cbuf-x-cell! cbuf cursor-cell)
          (set-cbuf-x-goal! cbuf cursor-goal))
        
        ;; Set mark if present
        (when (assq-ref mark 'set)
          (set-cbuf-mark-set?! cbuf #t)
          (set-cbuf-mark-line! cbuf (cbuf-bracket-line cbuf (or (assq-ref mark 'line) 0)))
          (set-cbuf-mark-x-data! cbuf (or (assq-ref mark 'data) 0)))
        
        cbuf))))

(define (json-line->metrics text spans tab-size cjk-mode)
  "Reconstruct text-metrics from JSON line representation"
  (if (or (null? spans) (not spans))
      ;; Empty line or line with no spans - use default SGR
      (compute-text-metrics text tab-size #:cjk? cjk-mode)
      
      ;; Reconstruct SGR list from spans
      (let ([sgr-list '()]
            [text-pos 0])
        
        ;; Process each span
        (for-each (lambda (span-obj)
                   (let ([span-text (assq-ref span-obj 'text)]
                         [span-sgr-json (assq-ref span-obj 'sgr)])
                     (let ([span-sgr (if span-sgr-json 
                                         (json->sgr span-sgr-json) 
                                         (make-default-sgr))]
                           [span-length (string-length span-text)])
                       ;; Add SGR for each character in span
                       (set! sgr-list (append sgr-list 
                                             (make-list span-length span-sgr)))
                       (set! text-pos (+ text-pos span-length)))))
                 spans)
        
        ;; Ensure SGR list matches text length
        (let ([text-length (string-length text)])
          (cond
            [(< (length sgr-list) text-length)
             ;; Pad with default SGR
             (set! sgr-list (append sgr-list 
                                   (make-list (- text-length (length sgr-list)) 
                                             (make-default-sgr))))]
            [(> (length sgr-list) text-length)
             ;; Truncate 
             (set! sgr-list (take sgr-list text-length))]))
        
        ;; Create text-metrics with reconstructed SGR list
        (compute-text-metrics-with-sgr text sgr-list tab-size #:cjk? cjk-mode))))

;;; =================================================================
;;; TEXT FORMAT SERIALIZATION (Now delegates to cbuf-basic)
;;; =================================================================

(define (cbuf->text cbuf)
  "Convert cbuf to plain text using cbuf-basic functionality"
  (cbuf-save-to-string cbuf))

(define* (text->cbuf text #:key (tab-size 8) (vert-tab-size 6) (form-size 66)
                     (cjk? #f) (default-grcm 'replacing) (line-ending "\n")
                     (final-newline-policy 'preserve))
  "Convert plain text to cbuf using cbuf-basic functionality"
  (let ([cbuf (make-cbuf #:tab-size tab-size 
                         #:vert-tab-size vert-tab-size
                         #:form-size form-size
                         #:cjk? cjk?
                         #:default-grcm default-grcm
                         #:line-ending line-ending
                         #:final-newline-policy final-newline-policy)])
    (cbuf-load-from-string! cbuf text)
    cbuf))

;;; =================================================================
;;; FILE I/O CONVENIENCE FUNCTIONS (Updated)
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
  "Save cbuf to plain text file using cbuf-basic functionality"
  (call-with-output-file filename
    (lambda (port)
      (display (cbuf-save-to-string cbuf) port))))

(define* (cbuf-load-text filename #:key (tab-size 8) (vert-tab-size 6) 
                         (form-size 66) (cjk? #f) (default-grcm 'replacing) 
                         (line-ending "\n") (final-newline-policy 'preserve))
  "Load cbuf from plain text file using cbuf-basic functionality"
  (let ([cbuf (make-cbuf #:tab-size tab-size 
                         #:vert-tab-size vert-tab-size
                         #:form-size form-size
                         #:cjk? cjk?
                         #:default-grcm default-grcm
                         #:line-ending line-ending
                         #:final-newline-policy final-newline-policy)])
    (call-with-input-file filename
      (lambda (port)
        (let ([text (get-string-all port)])
          (cbuf-load-from-string! cbuf text))))
    cbuf))

;;; =================================================================
;;; UTILITY FUNCTIONS
;;; =================================================================

(define (assq-ref alist key)
  "Safe association list reference"
  (let ([pair (assq key alist)])
    (if pair (cdr pair) #f)))

;;; =================================================================
;;; MIGRATION UTILITIES
;;; =================================================================

(define (cbuf-migrate-json-format json-obj)
  "Migrate old JSON format to new format"
  (let ([version (assq-ref json-obj 'version)])
    (cond
      [(string=? version "1.0")
       ;; Add missing fields with defaults
       (let ([metadata (assq-ref json-obj 'metadata)])
         (set! metadata (cons '(final_newline . #t) metadata))
         (set! metadata (cons '(final_newline_policy . "preserve") metadata))
         (set! metadata (cons '(cut_buffer . ()) metadata))
         `((version . "2.0")
           (format . ,(assq-ref json-obj 'format))
           (lines . ,(assq-ref json-obj 'lines))
           (metadata . ,metadata)))]
      
      [else json-obj])))  ; Already current version

(define (cbuf-validate-json-format json-obj)
  "Validate JSON format compatibility"
  (let ([version (assq-ref json-obj 'version)]
        [format (assq-ref json-obj 'format)])
    (and version
         format
         (member version '("1.0" "2.0"))
         (string=? format "spans"))))

;;; =================================================================
;;; DEBUG AND INSPECTION UTILITIES
;;; =================================================================

(define (cbuf-json-summary json-obj)
  "Return summary information about JSON cbuf format"
  (let ([metadata (assq-ref json-obj 'metadata)]
        [lines (assq-ref json-obj 'lines)])
    `((version . ,(assq-ref json-obj 'version))
      (format . ,(assq-ref json-obj 'format))
      (line_count . ,(length lines))
      (tab_size . ,(assq-ref metadata 'tab_size))
      (cjk_mode . ,(assq-ref metadata 'cjk_mode))
      (line_ending . ,(assq-ref metadata 'line_ending))
      (final_newline . ,(assq-ref metadata 'final_newline))
      (final_newline_policy . ,(assq-ref metadata 'final_newline_policy))
      (cursor_position . ((line . ,(assq-ref (assq-ref metadata 'cursor) 'line))
                          (data . ,(assq-ref (assq-ref metadata 'cursor) 'data))))
      (mark_set . ,(assq-ref (assq-ref metadata 'mark) 'set))
      (modified . ,(assq-ref metadata 'modified)))))
