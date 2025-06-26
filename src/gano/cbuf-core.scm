;;; Gano Character Buffer Core Module
;;; Core record definitions and basic accessors
;;; This module contains only the fundamental data structures
;;; Updated for bidirectional text support

(define-module (gano cbuf-core)
  #:use-module (gano text-metrics)  ; Text metrics module with bidi support
  #:use-module (gano rendering)     ; SGR support
  #:use-module (gano cbuf-utils)    ; Utility functions
  #:use-module (gano string-split)  ; Enhanced string splitting
  #:use-module (gano uax9-bidi)     ; Bidirectional text support
  #:use-module (srfi srfi-9)        ; Record types
  #:use-module (srfi srfi-35)       ; Condition types
  #:export (
    ;; Record type and constructor
    <cbuf>
    %make-cbuf
    make-cbuf
    cbuf?
    
    ;; Field accessors
    cbuf-text-metrics set-cbuf-text-metrics!
    cbuf-line-cur set-cbuf-line-cur!
    cbuf-x-data set-cbuf-x-data!
    cbuf-x-cell set-cbuf-x-cell!
    cbuf-x-goal set-cbuf-x-goal!
    cbuf-tab-size set-cbuf-tab-size!
    cbuf-vert-tab-size set-cbuf-vert-tab-size!
    cbuf-form-size set-cbuf-form-size!
    cbuf-home-pos set-cbuf-home-pos!
    cbuf-limit-pos set-cbuf-limit-pos!
    cbuf-limit-type set-cbuf-limit-type!
    cbuf-cjk? set-cbuf-cjk?!
    cbuf-modified? set-cbuf-modified?!
    cbuf-mark-set? set-cbuf-mark-set?!
    cbuf-mark-line set-cbuf-mark-line!
    cbuf-mark-x-data set-cbuf-mark-x-data!
    cbuf-bell? set-cbuf-bell?!
    cbuf-cut-buffer set-cbuf-cut-buffer!
    cbuf-undo-list set-cbuf-undo-list!
    cbuf-current-sgr set-cbuf-current-sgr!
    cbuf-default-grcm set-cbuf-default-grcm!
    cbuf-sgr-stack set-cbuf-sgr-stack!
    cbuf-line-ending set-cbuf-line-ending!
    cbuf-final-newline? set-cbuf-final-newline?!
    cbuf-final-newline-policy set-cbuf-final-newline-policy!
    
    ;; Derived accessors
    cbuf-line-count
    cbuf-text
    cbuf-text-cur
    cbuf-metrics-cur
    cbuf-sgr-list-cur
    cbuf-bidi-state-list-cur
    cbuf-get-line-text
    cbuf-text-cur-length
    cbuf-text-cur-cell-length
    cbuf-text-cur-base-length
    
    ;; Bidi-specific accessors
    cbuf-get-paragraph-direction
    cbuf-get-resolved-levels
    cbuf-is-rtl-at-position
    cbuf-get-bidi-state-at-position
    
    ;; Validation functions
    cbuf-validate-line
    cbuf-validate-position
    cbuf-line-valid?
    cbuf-position-valid?
    
    ;; Error conditions for ranges and motion
    &cbuf-range-error
    cbuf-range-error?
    cbuf-range-error:operation
    cbuf-range-error:requested
    cbuf-range-error:actual
    cbuf-range-error:reason

    &cbuf-beginning-of-buffer
    cbuf-beginning-of-buffer-error?
    &cbuf-end-of-buffer
    cbuf-end-of-buffer-error?
    &cbuf-beginning-of-line
    cbuf-beginning-of-line-error?
    &cbuf-end-of-line
    cbuf-end-of-line-error?
    &cbuf-line-limit-exceeded
    cbuf-line-limit-exceeded-error?
    cbuf-line-limit-exceeded-error:limit))

;;; =================================================================
;;; ERROR CONDITIONS
;;; =================================================================

(define-condition-type &cbuf-range-error &serious
  cbuf-range-error?
  (operation cbuf-range-error:operation)
  (requested cbuf-range-error:requested)
  (actual cbuf-range-error:actual)
  (reason cbuf-range-error:reason))

(define-condition-type &cbuf-beginning-of-buffer &cbuf-range-error
  cbuf-beginning-of-buffer-error?)

(define-condition-type &cbuf-end-of-buffer &cbuf-range-error
  cbuf-end-of-buffer-error?)

(define-condition-type &cbuf-beginning-of-line &cbuf-range-error
  cbuf-beginning-of-line-error?)

(define-condition-type &cbuf-end-of-line &cbuf-range-error
  cbuf-end-of-line-error?)

(define-condition-type &cbuf-line-limit-exceeded &cbuf-range-error
  cbuf-line-limit-exceeded-error?
  (limit cbuf-line-limit-exceeded-error:limit))

;;; =================================================================
;;; CBUF RECORD TYPE
;;; =================================================================

(define-record-type <cbuf>
  (%make-cbuf text-metrics line-cur x-data x-cell x-goal 
             tab-size vert-tab-size form-size home-pos limit-pos limit-type
             cjk? modified? mark-set? mark-line mark-x-data bell? cut-buffer undo-list
             current-sgr default-grcm sgr-stack line-ending final-newline?
	     final-newline-policy)
  cbuf?
  ;; Text content (now with bidi support)
  (text-metrics cbuf-text-metrics set-cbuf-text-metrics!) ; list of <text-metrics> with bidi
  
  ;; Current position
  (line-cur cbuf-line-cur set-cbuf-line-cur!)        ; current line (y)
  (x-data cbuf-x-data set-cbuf-x-data!)              ; data position
  (x-cell cbuf-x-cell set-cbuf-x-cell!)              ; cell position (now bidi-aware)
  (x-goal cbuf-x-goal set-cbuf-x-goal!)              ; goal cell position
  
  ;; Tab and formatting configuration
  (tab-size cbuf-tab-size set-cbuf-tab-size!)        ; spaces per tab
  (vert-tab-size cbuf-vert-tab-size set-cbuf-vert-tab-size!) ; lines per vert tab
  (form-size cbuf-form-size set-cbuf-form-size!)     ; lines per page
  (home-pos cbuf-home-pos set-cbuf-home-pos!)        ; line home position
  (limit-pos cbuf-limit-pos set-cbuf-limit-pos!)     ; line limit position
  (limit-type cbuf-limit-type set-cbuf-limit-type!)  ; 'data or 'presentation
  
  ;; Configuration
  (cjk? cbuf-cjk? set-cbuf-cjk?!)                    ; CJK terminal mode
  
  ;; State flags
  (modified? cbuf-modified? set-cbuf-modified?!)      ; buffer modified flag
  (bell? cbuf-bell? set-cbuf-bell?!)                  ; bell/alarm state
  
  ;; Mark (selection start point)
  (mark-set? cbuf-mark-set? set-cbuf-mark-set?!)      ; is mark active?
  (mark-line cbuf-mark-line set-cbuf-mark-line!)      ; mark line position
  (mark-x-data cbuf-mark-x-data set-cbuf-mark-x-data!) ; mark data position
  
  ;; Cut/copy buffer
  (cut-buffer cbuf-cut-buffer set-cbuf-cut-buffer!)  ; list of strings
  
  ;; Undo system
  (undo-list cbuf-undo-list set-cbuf-undo-list!)    ; list of undo records
  
  ;; SGR state
  (current-sgr cbuf-current-sgr set-cbuf-current-sgr!) ; current SGR for new text
  (default-grcm cbuf-default-grcm set-cbuf-default-grcm!) ; default GRCM mode
  (sgr-stack cbuf-sgr-stack set-cbuf-sgr-stack!)     ; SGR state stack
  
  ;; Line ending configuration
  (line-ending cbuf-line-ending set-cbuf-line-ending!) ; line terminator string
  (final-newline? cbuf-final-newline? set-cbuf-final-newline?!) ; does buffer end with newline?
  (final-newline-policy cbuf-final-newline-policy set-cbuf-final-newline-policy!) ; behavior policy
  )

;;; =================================================================
;;; VALIDATION FUNCTIONS
;;; =================================================================

(define (cbuf-line-valid? cbuf line-num)
  "Check if line-num is a valid line index for cbuf"
  (and (>= line-num 0) (< line-num (cbuf-line-count cbuf))))

(define (cbuf-position-valid? cbuf line-num x-data)
  "Check if the position is valid within the buffer"
  (and (cbuf-line-valid? cbuf line-num)
       (>= x-data 0)
       (<= x-data (string-length (cbuf-get-line-text cbuf line-num)))))

(define (cbuf-validate-line cbuf line-num operation)
  "Validate line number, raise appropriate condition if invalid"
  (let ([line-count (cbuf-line-count cbuf)])
    (cond
      [(< line-num 0)
       (raise (condition (&cbuf-beginning-of-buffer
                          (operation operation)
                          (requested line-num)
                          (actual 0)
                          (reason "Line number below buffer start"))))]
      [(>= line-num line-count)
       (raise (condition (&cbuf-end-of-buffer
                          (operation operation)
                          (requested line-num)
                          (actual (- line-count 1))
                          (reason "Line number beyond buffer end"))))])))

(define (cbuf-validate-position cbuf line-num x-data operation)
  "Validate position, raise appropriate condition if invalid"
  (cbuf-validate-line cbuf line-num operation)
  (let ([line-length (string-length (cbuf-get-line-text cbuf line-num))])
    (cond
      [(< x-data 0)
       (raise (condition (&cbuf-beginning-of-line
                          (operation operation)
                          (requested x-data)
                          (actual 0)
                          (reason "Position before line start"))))]
      [(> x-data line-length)
       (raise (condition (&cbuf-end-of-line
                          (operation operation)
                          (requested x-data)
                          (actual line-length)
                          (reason "Position beyond line end"))))])))

;;; =================================================================
;;; CONSTRUCTOR
;;; =================================================================

(define* (make-cbuf #:key (tab-size 8) (vert-tab-size 6) (form-size 66)
                    (cjk? #f) (initial-text "") (default-grcm 'replacing)
                    (line-ending "\n") (limit-pos #f) (final-newline? #t)
		    (final-newline-policy 'always-add))
  "Create a new character buffer with specified configuration.
   Now includes bidirectional text support."
  ;; Input validation
  (when (<= tab-size 0)
    (error "tab-size must be positive" tab-size))
  (when (<= vert-tab-size 0)
    (error "vert-tab-size must be positive" vert-tab-size))
  (when (<= form-size 0)
    (error "form-size must be positive" form-size))
  (unless (member default-grcm '(replacing overwriting))
    (error "default-grcm must be 'replacing or 'overwriting" default-grcm))
  
  ;; Use line splitting that respects different line endings
  (let* ([lines (if (string-null? initial-text) 
                    (list "")
                    (string-split-lines initial-text))]
         ;; Create text-metrics with bidi support
         [metrics (map (lambda (line) 
                         (compute-text-metrics line tab-size #:cjk? cjk?))
                       lines)]
         [actual-limit-pos (or limit-pos 79)])  ; Default limit if not specified
    
    (%make-cbuf metrics 0 0 0 0 
               tab-size vert-tab-size form-size 0 actual-limit-pos 'data
               cjk? #f #f 0 0 #f '() '()
               (make-default-sgr)     ; current-sgr
               default-grcm           ; default-grcm  
               '()                    ; sgr-stack
               line-ending            ; line-ending
	       final-newline?         ; final-newline?
	       final-newline-policy))) ; final-newline-policy

;;; =================================================================
;;; DERIVED ACCESSORS
;;; =================================================================

(define (cbuf-line-count cbuf)
  "Return the number of lines in the buffer"
  (length (cbuf-text-metrics cbuf)))

(define (cbuf-text cbuf)
  "Return all text lines as a list of strings"
  (map text-metrics-string (cbuf-text-metrics cbuf)))

(define (cbuf-text-cur cbuf)
  "Return the text of the current line (safe)"
  (let ([line-num (cbuf-line-cur cbuf)]
        [metrics (cbuf-text-metrics cbuf)])
    (if (and (>= line-num 0) (< line-num (length metrics)))
        (text-metrics-string (list-ref metrics line-num))
        "")))  ; Return empty string for invalid line

(define (cbuf-metrics-cur cbuf)
  "Return the text-metrics of the current line (safe)"
  (let ([line-num (cbuf-line-cur cbuf)]
        [metrics (cbuf-text-metrics cbuf)])
    (if (and (>= line-num 0) (< line-num (length metrics)))
        (list-ref metrics line-num)
        ;; Return a default empty text-metrics for invalid line
        (compute-text-metrics "" (cbuf-tab-size cbuf) #:cjk? (cbuf-cjk? cbuf)))))

(define (cbuf-sgr-list-cur cbuf)
  "Return the SGR list of the current line (safe)"
  (text-metrics-sgr-list (cbuf-metrics-cur cbuf)))

(define (cbuf-bidi-state-list-cur cbuf)
  "Return the bidi state list of the current line (safe)"
  (text-metrics-bidi-state-list (cbuf-metrics-cur cbuf)))

(define (cbuf-get-line-text cbuf n)
  "Return the text of line N (safe)"
  (let ([metrics (cbuf-text-metrics cbuf)])
    (if (and (>= n 0) (< n (length metrics)))
        (text-metrics-string (list-ref metrics n))
        "")))  ; Return empty string for invalid line

(define (cbuf-text-cur-length cbuf)
  "Return the number of codepoints in the current line (safe)"
  (string-length (cbuf-text-cur cbuf)))

(define (cbuf-text-cur-cell-length cbuf)
  "Return the number of cells in the current line (safe, now bidi-aware)"
  (text-metrics-cell-length (cbuf-metrics-cur cbuf)))

(define (cbuf-text-cur-base-length cbuf)
  "Return the number of base characters in the current line (safe)"
  (text-metrics-string-base-length (cbuf-metrics-cur cbuf)))

;;; =================================================================
;;; BIDIRECTIONAL TEXT ACCESSORS
;;; =================================================================

(define (cbuf-get-paragraph-direction cbuf)
  "Get the paragraph direction for the current line"
  (text-metrics-get-paragraph-direction (cbuf-metrics-cur cbuf)))

(define (cbuf-get-resolved-levels cbuf)
  "Get resolved bidi levels for the current line"
  (text-metrics-get-resolved-levels (cbuf-metrics-cur cbuf)))

(define (cbuf-is-rtl-at-position cbuf x-data)
  "Check if the character at x-data position is in RTL context"
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [x-index (text-metrics-x-data->x-index metrics x-data)])
    (if x-index
        (text-metrics-is-rtl-at-position metrics x-index)
        #f)))

(define (cbuf-get-bidi-state-at-position cbuf x-data)
  "Get bidi state at x-data position"
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [x-index (text-metrics-x-data->x-index metrics x-data)])
    (if x-index
        (text-metrics-get-bidi-state-at-index metrics x-index)
        (make-bidi-state 0 'neutral 'none))))
