;;; Gano Character Buffer Operations Module
;;; Core buffer manipulation functions: movement, text operations, and SGR
;;; This module contains all the ECMA-48 operations and text modification functions

(define-module (gano cbuf-operations)
  #:use-module (gano cbuf-core)     ; Core record definitions
  #:use-module (gano cbuf-utils)    ; Pure utility functions
  #:use-module (gano text-metrics)  ; Text metrics module
  #:use-module (gano rendering)     ; SGR support
  #:use-module (gano list-utils)    ; Immutable list operations
  #:use-module (gano char)          ; Character utilities
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-11)       ; let-values
  #:use-module (srfi srfi-13)       ; String utilities
  #:use-module (srfi srfi-35)       ; Condition types
  #:export (
    ;; Position management and conversion
    cbuf-set-x! cbuf-set-y! cbuf-set-positions! cbuf-synchronize-x-goal!
    cbuf-bracket-x-data cbuf-bracket-line
    
    ;; Position conversion functions
    cbuf-x-data->x-index cbuf-x-data->x-cell cbuf-x-cell->x-data
    cbuf-x-cell->x-index cbuf-x-index->x-data cbuf-x-index->x-cell
    cbuf-update-x-cell! cbuf-update-metrics-cur!
    
    ;; Text operations
    cbuf-insert-codepoint cbuf-insert-newline cbuf-delete-newline
    cbuf-render-line cbuf-render-line-string-only
    
    ;; ECMA-48 Control Functions - Cursor movement
    cbuf-cursor-up cbuf-cursor-down cbuf-cursor-forward cbuf-cursor-backward
    cbuf-cursor-next-line cbuf-cursor-preceding-line
    cbuf-cursor-character-absolute cbuf-cursor-line-absolute cbuf-cursor-position
    
    ;; Tab operations
    cbuf-cursor-forward-tabulation cbuf-cursor-backward-tabulation
    cbuf-character-tabulation
    
    ;; Character operations
    cbuf-character-position-forward cbuf-character-position-backward
    cbuf-character-position-absolute
    
    ;; Format effectors
    cbuf-backspace cbuf-carriage-return cbuf-line-feed cbuf-form-feed
    cbuf-reverse-line-feed cbuf-next-line
    
    ;; Bell and status
    cbuf-bell cbuf-clear-bell cbuf-device-status-report cbuf-device-attributes
    
    ;; Character insertion and deletion
    cbuf-insert-character cbuf-insert-line cbuf-delete-character
    cbuf-delete-preceding-character cbuf-delete-line cbuf-delete-newline
    
    ;; Erase operations
    cbuf-erase-character cbuf-erase-in-line cbuf-erase-in-buffer
    
    ;; Word operations
    cbuf-delete-word-forward cbuf-delete-word-backward
    
    ;; SGR state management
    cbuf-select-graphic-rendition cbuf-reset-graphic-rendition
    cbuf-set-default-grcm! cbuf-save-sgr-state cbuf-restore-sgr-state
    cbuf-clear-sgr-stack
    
    ;; Enhanced text insertion
    cbuf-insert-codepoint-with-sgr cbuf-insert-string-with-current-sgr
    
    ;; SGR positioning and range operations
    cbuf-set-sgr-at-cursor cbuf-set-sgr-range cbuf-get-sgr-at-cursor
    
    ;; SGR-aware rendering
    cbuf-render-line-with-sgr cbuf-get-line-sgr-spans
    
    ;; Convenience SGR functions
    cbuf-set-bold! cbuf-set-italic! cbuf-set-foreground-color!
    cbuf-set-background-color! cbuf-apply-sgr-to-selection
    
    ;; Mark operations
    cbuf-set-mark! cbuf-clear-mark! cbuf-goto-mark
    
    ;; Status queries
    cbuf-beginning-of-line? cbuf-end-of-line? cbuf-beginning-of-buffer?
    cbuf-end-of-buffer? cbuf-on-first-page? cbuf-on-last-page?
    
    ;; Configuration
    cbuf-set-line-home! cbuf-set-tab-size! cbuf-set-vert-tab-size!
    cbuf-set-form-size! cbuf-set-line-ending!
    
    ;; Efficient string operations
    cbuf-insert-string-with-sgr cbuf-insert-string-permissive cbuf-insert-lines
    cbuf-insert-string-internal cbuf-insert-lines-internal
    
    ;; Internal helper functions
    cbuf-update-line! cbuf-set-text-cur! cbuf-validate-line-movement
    cbuf-validate-column-movement cbuf-validate-absolute-position
    cbuf-raise-boundary-error cbuf-validate-combining-mark-insertion))

;;; =================================================================
;;; HELPER FUNCTIONS
;;; =================================================================

(define (cbuf-validate-line-movement cbuf current-line delta operation)
  "Validate line movement using utility functions"
  (validate-line-movement-pure current-line delta (- (cbuf-line-count cbuf) 1) operation))

(define (cbuf-validate-column-movement cbuf current-column delta operation)
  "Validate column movement using utility functions"
  (validate-column-movement-pure current-column delta (cbuf-text-cur-cell-length cbuf) operation))

(define (cbuf-validate-absolute-position cbuf line column operation)
  "Validate absolute positioning using utility functions"
  (let* ([max-line (- (cbuf-line-count cbuf) 1)]
         [max-column (if (< line (cbuf-line-count cbuf))
                        (text-metrics-cell-length 
                         (list-ref (cbuf-text-metrics cbuf) 
                                   (max 0 (min line max-line))))
                        0)])
    (validate-absolute-position-pure line column max-line max-column operation)))

(define (cbuf-raise-boundary-error cbuf operation target actual boundary-type)
  "Centralized boundary error raising"
  (let ([condition-constructor
         (case boundary-type
           [(beginning-of-buffer) &cbuf-beginning-of-buffer]
           [(end-of-buffer) &cbuf-end-of-buffer]
           [(beginning-of-line) &cbuf-beginning-of-line]
           [(end-of-line) &cbuf-end-of-line]
           [else &cbuf-range-error])])
    (raise (condition (condition-constructor
                       (operation operation)
                       (requested target)
                       (actual actual)
                       (reason boundary-type))))))

(define (cbuf-validate-combining-mark-insertion cbuf char-new position)
  "Validate combining mark insertion using utilities"
  (when (char-combining-mark? char-new)
    (let* ([txt (cbuf-text-cur cbuf)])
      
      ;; Check we're not at beginning of line
      (when (= position 0)
        (list #f (make-combining-mark-error-info 'insert-codepoint #f char-new 0 MAX-COMBINING-MARKS 'no-base-character)))
      
      ;; Find the base character for this cluster
      (let* ([base-data-pos (- position 1)]
             [base-index (cbuf-x-data->x-index cbuf base-data-pos)]
             [base-char (string-ref txt base-index)]
             [current-count (count-combining-marks-in-cluster txt base-index)])
        
        ;; Verify base character is valid
        (when (char-combining-mark? base-char)
          (list #f (make-combining-mark-error-info 'insert-codepoint base-char char-new current-count MAX-COMBINING-MARKS 'base-is-combining)))
        
        ;; Check combining mark limit
        (when (>= current-count MAX-COMBINING-MARKS)
          (list #f (make-combining-mark-error-info 'insert-codepoint base-char char-new current-count MAX-COMBINING-MARKS 'too-many-combining)))
        
        ;; If we get here, validation passed
        (list #t #f)))))

(define (cbuf-update-line! cbuf line-num new-text new-sgr-list)
  "Update the text and SGR list for a specific line"
  (unless (= (string-length new-text) (length new-sgr-list))
    (error "Text length and SGR list length must match"))
  
  ;; Compute new metrics with cbuf's settings
  (let* ([new-metrics (compute-text-metrics-with-sgr new-text 
                                                     new-sgr-list
                                                     (cbuf-tab-size cbuf) 
                                                     #:cjk? (cbuf-cjk? cbuf))]
         [new-metrics-list (list-update (cbuf-text-metrics cbuf) line-num new-metrics)])
    (set-cbuf-text-metrics! cbuf new-metrics-list)
    (set-cbuf-modified?! cbuf #t)))

(define (cbuf-set-text-cur! cbuf text sgr-list)
  "Set the text of the current line and update its metrics"
  (cbuf-update-line! cbuf (cbuf-line-cur cbuf) text sgr-list))

(define (cbuf-update-metrics-cur! cbuf new-metrics)
  "Update the metrics for the current line"
  (let* ([line-num (cbuf-line-cur cbuf)]
         [metrics-list (cbuf-text-metrics cbuf)]
         [new-metrics-list (list-update metrics-list line-num new-metrics)])
    (set-cbuf-text-metrics! cbuf new-metrics-list)
    (set-cbuf-modified?! cbuf #t)))

;;; =================================================================
;;; POSITION CONVERSION FUNCTIONS
;;; =================================================================

(define (cbuf-x-data->x-index cbuf x-data)
  "Convert data position to string index"
  (if (and (< (cbuf-line-cur cbuf) (cbuf-line-count cbuf))
           (>= (cbuf-line-cur cbuf) 0))
      (text-metrics-x-data->x-index (cbuf-metrics-cur cbuf) x-data)
      0))

(define (cbuf-x-data->x-cell cbuf x-data)
  "Convert data position to cell position"
  (if (and (< (cbuf-line-cur cbuf) (cbuf-line-count cbuf))
           (>= (cbuf-line-cur cbuf) 0))
      (text-metrics-x-data->x-cell (cbuf-metrics-cur cbuf) x-data)
      0))

(define (cbuf-x-cell->x-data cbuf x-cell)
  "Convert cell position to data position"
  (if (and (< (cbuf-line-cur cbuf) (cbuf-line-count cbuf))
           (>= (cbuf-line-cur cbuf) 0))
      (text-metrics-x-cell->x-data (cbuf-metrics-cur cbuf) x-cell)
      0))

(define (cbuf-x-cell->x-index cbuf x-cell)
  "Convert cell position to string index"
  (if (and (< (cbuf-line-cur cbuf) (cbuf-line-count cbuf))
           (>= (cbuf-line-cur cbuf) 0))
      (text-metrics-x-cell->x-index (cbuf-metrics-cur cbuf) x-cell)
      0))

(define (cbuf-x-index->x-data cbuf x-index)
  "Convert string index to data position"
  (if (and (< (cbuf-line-cur cbuf) (cbuf-line-count cbuf))
           (>= (cbuf-line-cur cbuf) 0))
      (text-metrics-x-index->x-data (cbuf-metrics-cur cbuf) x-index)
      0))

(define (cbuf-x-index->x-cell cbuf x-index)
  "Convert string index to cell position"
  (if (and (< (cbuf-line-cur cbuf) (cbuf-line-count cbuf))
           (>= (cbuf-line-cur cbuf) 0))
      (text-metrics-x-index->x-cell (cbuf-metrics-cur cbuf) x-index)
      0))

;;; =================================================================
;;; POSITION MANAGEMENT
;;; =================================================================

(define (cbuf-bracket-x-data cbuf x-data)
  "Return x-data if valid, or nearest valid x-data position"
  (max 0 (min x-data (cbuf-text-cur-base-length cbuf))))

(define (cbuf-bracket-line cbuf line)
  "Return line if valid, or nearest valid line number"
  (max 0 (min line (- (cbuf-line-count cbuf) 1))))

(define (cbuf-update-x-cell! cbuf)
  "Update x-cell to match current x-data position"
  (let ([x-cell (cbuf-x-data->x-cell cbuf (cbuf-x-data cbuf))])
    (set-cbuf-x-cell! cbuf x-cell)))

(define (cbuf-synchronize-x-goal! cbuf)
  "Set x-goal to match current x-cell position"
  (set-cbuf-x-goal! cbuf (cbuf-x-cell cbuf)))

(define (cbuf-set-x! cbuf x type)
  "Set the x position based on TYPE ('index, 'data, or 'cell)"
  (cond
   [(eq? type 'index)
    (let ([x-data (cbuf-x-index->x-data cbuf x)])
      (when x-data
        (set-cbuf-x-data! cbuf x-data)
        (cbuf-update-x-cell! cbuf)
        (cbuf-synchronize-x-goal! cbuf)))]
   
   [(eq? type 'data)
    (set-cbuf-x-data! cbuf (cbuf-bracket-x-data cbuf x))
    (cbuf-update-x-cell! cbuf)
    (cbuf-synchronize-x-goal! cbuf)]
   
   [(eq? type 'cell)
    (let ([x-data (cbuf-x-cell->x-data cbuf x)])
      (if x-data
          (begin
            (set-cbuf-x-data! cbuf x-data)
            (cbuf-update-x-cell! cbuf)
            (set-cbuf-x-goal! cbuf x))
          (begin
            (set-cbuf-x-data! cbuf (cbuf-text-cur-base-length cbuf))
            (cbuf-update-x-cell! cbuf)
            (set-cbuf-x-goal! cbuf x))))]
   
   [else
    (error "Invalid cbuf-set-x! type" type)]))

(define (cbuf-set-y! cbuf line)
  "Set the current line and update positions"
  (set-cbuf-line-cur! cbuf (cbuf-bracket-line cbuf line))
  ;; Try to maintain x-goal position on new line
  (cbuf-set-x! cbuf (cbuf-x-goal cbuf) 'cell))

(define (cbuf-set-positions! cbuf n device)
  "Set position based on device type ('data or 'presentation)"
  (cond
   [(eq? device 'data)
    (cbuf-set-x! cbuf n 'data)]
   [(eq? device 'presentation)
    (cbuf-set-x! cbuf n 'cell)]
   [else
    (error "Invalid device type" device)]))

;;; =================================================================
;;; RENDERING FUNCTIONS
;;; =================================================================

(define* (cbuf-render-line cbuf x-cell-start x-width #:key (pad? #t))
  "Render a portion of the current line"
  (text-metrics-render-line (cbuf-metrics-cur cbuf) 
                            x-cell-start x-width #:pad? pad?))

(define* (cbuf-render-line-string-only cbuf x-cell-start x-width #:key (pad? #t))
  "Return only the rendered string"
  (let-values ([(rendered-string sgr-list) 
                (cbuf-render-line cbuf x-cell-start x-width #:pad? pad?)])
    rendered-string))

;;; =================================================================
;;; CURSOR MOVEMENT FUNCTIONS
;;; =================================================================

(define* (cbuf-cursor-up cbuf n #:key (strict? #f))
  "CUU - Move cursor up N lines"
  (let* ([current-line (cbuf-line-cur cbuf)]
         [validation (cbuf-validate-line-movement cbuf current-line (- n) 'cursor-up)]
         [target-line (car validation)]
         [clamped-line (cadr validation)]
         [clamped? (caddr validation)]
         [x-goal (cbuf-x-goal cbuf)])
    
    ;; Always perform the movement
    (cbuf-set-y! cbuf clamped-line)
    (cbuf-set-x! cbuf x-goal 'cell)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'cursor-up target-line clamped-line
                                (if (< target-line 0) 'beginning-of-buffer 'end-of-buffer)))))

(define* (cbuf-cursor-down cbuf n #:key (strict? #f))
  "CUD - Move cursor down N lines"
  (let* ([current-line (cbuf-line-cur cbuf)]
         [validation (cbuf-validate-line-movement cbuf current-line n 'cursor-down)]
         [target-line (car validation)]
         [clamped-line (cadr validation)]
         [clamped? (caddr validation)]
         [x-goal (cbuf-x-goal cbuf)])
    
    ;; Always perform the movement
    (cbuf-set-y! cbuf clamped-line)
    (cbuf-set-x! cbuf x-goal 'cell)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'cursor-down target-line clamped-line
                                (if (>= target-line (cbuf-line-count cbuf)) 'end-of-buffer 'beginning-of-buffer)))))

(define* (cbuf-cursor-forward cbuf n #:key (strict? #f))
  "CUF - Move cursor forward N cells"
  (let* ([current-cell (cbuf-x-cell cbuf)]
         [validation (cbuf-validate-column-movement cbuf current-cell n 'cursor-forward)]
         [target-cell (car validation)]
         [clamped-cell (cadr validation)]
         [clamped? (caddr validation)])
    
    ;; Always perform the movement
    (cbuf-set-x! cbuf clamped-cell 'cell)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'cursor-forward target-cell clamped-cell 'end-of-line))))

(define* (cbuf-cursor-backward cbuf n #:key (strict? #f))
  "CUB - Move cursor backward N cells"
  (let* ([current-cell (cbuf-x-cell cbuf)]
         [validation (cbuf-validate-column-movement cbuf current-cell (- n) 'cursor-backward)]
         [target-cell (car validation)]
         [clamped-cell (cadr validation)]
         [clamped? (caddr validation)])
    
    ;; Always perform the movement
    (cbuf-set-x! cbuf clamped-cell 'cell)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'cursor-backward target-cell clamped-cell 'beginning-of-line))))

(define* (cbuf-cursor-next-line cbuf n #:key (strict? #f))
  "CNL - Move to 1st character position of nth following line"
  (cbuf-cursor-down cbuf n #:strict? strict?)
  (cbuf-set-positions! cbuf 0 'data))

(define* (cbuf-cursor-preceding-line cbuf n #:key (strict? #f))
  "CPL - Move to 1st character position of nth preceding line"
  (cbuf-cursor-up cbuf n #:strict? strict?)
  (cbuf-set-positions! cbuf 0 'data))

(define* (cbuf-cursor-character-absolute cbuf n #:key (strict? #f))
  "CHA - Move to character position N in active line"
  (let* ([max-cell (cbuf-text-cur-cell-length cbuf)]
         [clamped-n (max 0 (min n max-cell))]
         [clamped? (not (= n clamped-n))])
    
    ;; Always perform the positioning
    (cbuf-set-x! cbuf clamped-n 'cell)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'cursor-character-absolute n clamped-n
                                (if (< n 0) 'beginning-of-line 'end-of-line)))))

(define* (cbuf-cursor-line-absolute cbuf n #:key (strict? #f))
  "VPA - Move to line N, preserving column"
  (let* ([max-line (- (cbuf-line-count cbuf) 1)]
         [clamped-n (max 0 (min n max-line))]
         [clamped? (not (= n clamped-n))])
    
    ;; Always perform the positioning
    (cbuf-set-y! cbuf clamped-n)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'cursor-line-absolute n clamped-n
                                (if (< n 0) 'beginning-of-buffer 'end-of-buffer)))))

(define* (cbuf-cursor-position cbuf line column #:key (strict? #f))
  "CUP/HVP - Move to absolute position"
  (let* ([validation (cbuf-validate-absolute-position cbuf line column 'cursor-position)]
         [clamped-line (car validation)]
         [clamped-column (cadr validation)]
         [line-clamped? (caddr validation)]
         [column-clamped? (cadddr validation)])
    
    ;; Always perform the positioning
    (cbuf-set-y! cbuf clamped-line)
    (cbuf-set-x! cbuf clamped-column 'cell)
    
    ;; Conditionally raise after successful operation
    (when strict?
      (cond
       [line-clamped? 
        (cbuf-raise-boundary-error cbuf 'cursor-position line clamped-line
                                  (if (< line 0) 'beginning-of-buffer 'end-of-buffer))]
       [column-clamped?
        (cbuf-raise-boundary-error cbuf 'cursor-position column clamped-column
                                  (if (< column 0) 'beginning-of-line 'end-of-line))]))))

;;; =================================================================
;;; TAB OPERATIONS
;;; =================================================================

(define* (cbuf-cursor-forward-tabulation cbuf n #:key (strict? #f))
  "CHT - Move to nth following character tabulation stop"
  (let* ([x-cell (cbuf-x-cell cbuf)]
         [tabsize (cbuf-tab-size cbuf)]
         [target-x (compute-tab-column x-cell tabsize n)]
         [max-cell (cbuf-text-cur-cell-length cbuf)]
         [clamped-x (max 0 (min target-x max-cell))]
         [clamped? (not (= target-x clamped-x))])
    
    ;; Always perform the movement
    (cbuf-set-x! cbuf clamped-x 'cell)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'cursor-forward-tabulation target-x clamped-x
                                (if (< target-x 0) 'beginning-of-line 'end-of-line)))))

(define* (cbuf-cursor-backward-tabulation cbuf n #:key (strict? #f))
  "CBT - Move to nth preceding character tabulation stop"
  (cbuf-cursor-forward-tabulation cbuf (- n) #:strict? strict?))

(define (cbuf-character-tabulation cbuf)
  "HT - Character tabulation (horizontal tab)"
  (cbuf-cursor-forward-tabulation cbuf 1))

;;; =================================================================
;;; CHARACTER POSITION OPERATIONS
;;; =================================================================

(define* (cbuf-character-position-forward cbuf n #:key (strict? #f))
  "HPR - Move forward N character positions (data positions)"
  (let* ([current-data (cbuf-x-data cbuf)]
         [max-data (cbuf-text-cur-base-length cbuf)]
         [target-data (+ current-data n)]
         [clamped-data (max 0 (min target-data max-data))]
         [clamped? (not (= target-data clamped-data))])
    
    ;; Always perform the movement
    (cbuf-set-x! cbuf clamped-data 'data)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'character-position-forward target-data clamped-data 'end-of-line))))

(define* (cbuf-character-position-backward cbuf n #:key (strict? #f))
  "HPB - Move backward N character positions (data positions)"
  (let* ([current-data (cbuf-x-data cbuf)]
         [target-data (- current-data n)]
         [clamped-data (max 0 target-data)]
         [clamped? (not (= target-data clamped-data))])
    
    ;; Always perform the movement
    (cbuf-set-x! cbuf clamped-data 'data)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'character-position-backward target-data clamped-data 'beginning-of-line))))

(define* (cbuf-character-position-absolute cbuf n #:key (strict? #f))
  "HPA - Move to character position N in the active line"
  (let* ([max-data (cbuf-text-cur-base-length cbuf)]
         [clamped-n (max 0 (min n max-data))]
         [clamped? (not (= n clamped-n))])
    
    ;; Always perform the positioning
    (cbuf-set-x! cbuf clamped-n 'data)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'character-position-absolute n clamped-n
                                (if (< n 0) 'beginning-of-line 'end-of-line)))))

;;; =================================================================
;;; FORMAT EFFECTORS
;;; =================================================================

(define (cbuf-backspace cbuf)
  "BS - Move the active data position to the previous data position"
  (cbuf-character-position-backward cbuf 1))

(define (cbuf-carriage-return cbuf)
  "CR - Move to the line home position of the same line"
  (cbuf-set-positions! cbuf (cbuf-home-pos cbuf) (cbuf-limit-type cbuf)))

(define (cbuf-line-feed cbuf)
  "LF - Line feed (shorthand for cursor down 1)"
  (cbuf-cursor-down cbuf 1))

(define (cbuf-reverse-line-feed cbuf)
  "RI - Reverse line feed (shorthand for cursor up 1)"
  (cbuf-cursor-up cbuf 1))

(define (cbuf-next-line cbuf)
  "NEL - Next line. Move to the home position in the next line"
  (cbuf-carriage-return cbuf)
  (cbuf-line-feed cbuf))

(define (cbuf-form-feed cbuf)
  "FF - Form feed. Move to corresponding character position of next page"
  (let* ([y (cbuf-line-cur cbuf)]
         [ps (cbuf-form-size cbuf)]
         [y-on-page (remainder y ps)]
         [y-start-of-next-page (* ps (+ (quotient y ps) 1))])
    (cbuf-cursor-position cbuf (+ y-start-of-next-page y-on-page) 0)))

;;; =================================================================
;;; BELL AND STATUS OPERATIONS
;;; =================================================================

(define (cbuf-bell cbuf)
  "BEL - Sets the alarm state"
  (set-cbuf-bell?! cbuf #t))

(define (cbuf-clear-bell cbuf)
  "CBL - Clears the alarm state"
  (set-cbuf-bell?! cbuf #f))

(define (cbuf-device-status-report cbuf device)
  "DSR - Device Status Report"
  (cond
   [(eq? device 'data)
    (cons (cbuf-line-cur cbuf) (cbuf-x-data cbuf))]
   [(eq? device 'presentation)
    (cons (cbuf-line-cur cbuf) (cbuf-x-cell cbuf))]
   [else
    (error "Unknown device" device)]))

(define (cbuf-device-attributes cbuf)
  "DA - Device Attributes. Returns a string identifying this class"
  "Gano CBuf 1.0")

;;; =================================================================
;;; TEXT INSERTION AND DELETION OPERATIONS
;;; =================================================================

(define (cbuf-insert-codepoint cbuf char-new)
  "Insert codepoint using current SGR state"
  (cbuf-insert-codepoint-with-sgr cbuf char-new (cbuf-current-sgr cbuf)))

(define* (cbuf-insert-codepoint-with-sgr cbuf char-new sgr #:key (strict? #t))
  "Insert single codepoint with specific SGR"
  (cond
   [(not strict?)
    ;; Permissive mode - use efficient single character insertion
    (cbuf-insert-codepoint-internal cbuf char-new sgr)]
   
   [else
    ;; Strict mode - validate then use efficient insertion
    (if (char-combining-mark? char-new)
        ;; Combining mark - need validation
        (let ([validation (cbuf-validate-combining-mark-insertion cbuf char-new (cbuf-x-data cbuf))])
          (if (car validation)
              (cbuf-insert-codepoint-internal cbuf char-new sgr)
              (let ([error-info (cadr validation)])
                (error "Combining mark validation failed" error-info))))
        
        ;; Not a combining mark - direct insertion
        (cbuf-insert-codepoint-internal cbuf char-new sgr))]))

(define (cbuf-insert-codepoint-internal cbuf char-new sgr)
  "Internal codepoint insertion"
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)]
         [new-metrics (text-metrics-insert-string-with-sgr metrics x-index (string char-new) (list sgr))])
    
    ;; Single atomic update to the metrics
    (cbuf-update-metrics-cur! cbuf new-metrics)
    
    ;; Update cursor position
    (let ([inserted-data-positions (if (char-combining-mark? char-new) 0 1)])
      ;; Move cursor to end of inserted text
      (cbuf-set-x! cbuf (+ x-data inserted-data-positions) 'data))))

(define* (cbuf-insert-string-with-current-sgr cbuf str #:key (strict? #t))
  "Insert string using current SGR for all characters"
  (let ([current-sgr (cbuf-current-sgr cbuf)]
        [str-length (string-length str)])
    (if (= str-length 0)
        #f  ; Nothing to insert
        (let ([sgr-list (make-list str-length current-sgr)])
          (cbuf-insert-string-with-sgr cbuf str sgr-list #:strict? strict?)))))

(define* (cbuf-insert-string-with-sgr cbuf str sgr-list #:key (strict? #t))
  "Insert string with SGR list"
  (when (not (= (string-length str) (length sgr-list)))
    (error "String length and SGR list length must match" 
           (string-length str) (length sgr-list)))
  
  (cond
   [(not strict?)
    ;; Permissive mode - perform insertion without validation
    (cbuf-insert-string-internal cbuf str sgr-list)]
   
   [else
    ;; Strict mode - validate first, then perform operation
    (let* ([current-str (cbuf-text-cur cbuf)]
           [insertion-point (cbuf-x-data->x-index cbuf (cbuf-x-data cbuf))]
           [validation (validate-combining-marks-at-insertion current-str insertion-point str)])
      
      (if (car validation)
          ;; Validation passed - perform insertion
          (cbuf-insert-string-internal cbuf str sgr-list)
          
          ;; Validation failed - raise error
          (error "String contains invalid combining mark sequences")))]))

(define (cbuf-insert-string-internal cbuf str sgr-list)
  "Internal string insertion"
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)]
         [new-metrics (text-metrics-insert-string-with-sgr metrics x-index str sgr-list)])
    
    ;; Single atomic update to the metrics
    (cbuf-update-metrics-cur! cbuf new-metrics)
    
    ;; Update cursor position
    (let ([inserted-data-positions (count-base-characters str)])
      ;; Move cursor to end of inserted text
      (cbuf-set-x! cbuf (+ x-data inserted-data-positions) 'data))))

(define (cbuf-insert-string-permissive cbuf str)
  "Insert string without combining mark validation"
  (cbuf-insert-string-with-current-sgr cbuf str #:strict? #f))

;; Placeholder for remaining text operations - would include:
;; - cbuf-insert-newline, cbuf-delete-newline
;; - cbuf-insert-character, cbuf-insert-line  
;; - cbuf-delete-character, cbuf-delete-preceding-character, cbuf-delete-line
;; - cbuf-erase-character, cbuf-erase-in-line, cbuf-erase-in-buffer
;; - cbuf-delete-word-forward, cbuf-delete-word-backward
;; - cbuf-insert-lines, cbuf-insert-lines-internal

;;; =================================================================
;;; SGR STATE MANAGEMENT
;;; =================================================================

(define* (cbuf-select-graphic-rendition cbuf sgr-attributes #:key (mode #f))
  "SGR - Select Graphic Rendition. Apply SGR attributes to current SGR state"
  (let* ([current-sgr (cbuf-current-sgr cbuf)]
         [actual-mode (or mode (cbuf-default-grcm cbuf))]
         [attr-list (if (list? sgr-attributes) sgr-attributes (list sgr-attributes))])
    
    (cond
     ;; Replacing mode: start with default SGR, then apply attributes
     [(eq? actual-mode 'replacing)
      (let ([new-sgr (make-default-sgr)])
        (sgr-apply-attributes! new-sgr attr-list)
        (set-cbuf-current-sgr! cbuf new-sgr))]
     
     ;; Cumulative mode: apply attributes to current SGR
     [(eq? actual-mode 'cumulative)
      (let ([new-sgr (sgr-copy current-sgr)])
        (sgr-apply-attributes! new-sgr attr-list)
        (set-cbuf-current-sgr! cbuf new-sgr))]
     
     [else
      (error "Invalid GRCM mode" actual-mode)])
    
    (set-cbuf-modified?! cbuf #t)))

(define (cbuf-reset-graphic-rendition cbuf)
  "Reset SGR to default state (equivalent to SGR 0)"
  (cbuf-select-graphic-rendition cbuf '(reset) #:mode 'replacing))

(define (cbuf-set-default-grcm! cbuf mode)
  "Set the default Graphic Rendition Combination Mode"
  (unless (memq mode '(replacing cumulative))
    (error "Invalid GRCM mode, must be 'replacing or 'cumulative" mode))
  (set-cbuf-default-grcm! cbuf mode))

(define (cbuf-save-sgr-state cbuf)
  "Save current SGR state to stack"
  (let ([current-sgr (cbuf-current-sgr cbuf)]
        [stack (cbuf-sgr-stack cbuf)])
    (set-cbuf-sgr-stack! cbuf (cons (sgr-copy current-sgr) stack))))

(define (cbuf-restore-sgr-state cbuf)
  "Restore SGR state from stack"
  (let ([stack (cbuf-sgr-stack cbuf)])
    (unless (null? stack)
      (set-cbuf-current-sgr! cbuf (sgr-copy (car stack)))
      (set-cbuf-sgr-stack! cbuf (cdr stack))
      (set-cbuf-modified?! cbuf #t))))

(define (cbuf-clear-sgr-stack cbuf)
  "Clear the SGR state stack"
  (set-cbuf-sgr-stack! cbuf '()))

;;; =================================================================
;;; SGR POSITIONING AND RANGE OPERATIONS
;;; =================================================================

(define (cbuf-set-sgr-at-cursor cbuf sgr)
  "Set SGR at current cursor position"
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)])
    (when x-index
      (let ([new-metrics (text-metrics-set-sgr-at-index metrics x-index sgr)])
        (cbuf-update-metrics-cur! cbuf new-metrics)))))

(define (cbuf-set-sgr-range cbuf start-data end-data sgr)
  "Set SGR for a range of data positions on current line"
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [start-index (cbuf-x-data->x-index cbuf start-data)]
         [end-index (cbuf-x-data->x-index cbuf end-data)])
    (when (and start-index end-index)
      (let ([new-metrics (text-metrics-set-sgr-range metrics start-index end-index sgr)])
        (cbuf-update-metrics-cur! cbuf new-metrics)))))

(define (cbuf-get-sgr-at-cursor cbuf)
  "Get SGR at current cursor position"
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [x-data (cbuf-x-data cbuf)])
    (text-metrics-get-sgr-at-data metrics x-data)))

;;; =================================================================
;;; SGR-AWARE RENDERING
;;; =================================================================

(define* (cbuf-render-line-with-sgr cbuf x-cell-start x-width #:key (pad? #t))
  "Render current line with SGR spans"
  (text-metrics-render-line-with-sgr (cbuf-metrics-cur cbuf) 
                                     x-cell-start x-width #:pad? pad?))

(define (cbuf-get-line-sgr-spans cbuf)
  "Get current line as optimized SGR spans"
  (text-metrics-get-rendered-spans (cbuf-metrics-cur cbuf)))

;;; =================================================================
;;; CONVENIENCE SGR FUNCTIONS
;;; =================================================================

(define (cbuf-set-bold! cbuf)
  "Set current SGR to bold"
  (cbuf-select-graphic-rendition cbuf 'intensity-bold))

(define (cbuf-set-italic! cbuf)
  "Set current SGR to italic"
  (cbuf-select-graphic-rendition cbuf 'font-style-italic))

(define (cbuf-set-foreground-color! cbuf color)
  "Set current SGR foreground color"
  (let ([new-sgr (sgr-copy (cbuf-current-sgr cbuf))])
    (sgr-set-foreground-color! new-sgr color)
    (set-cbuf-current-sgr! cbuf new-sgr)))

(define (cbuf-set-background-color! cbuf color)
  "Set current SGR background color"
  (let ([new-sgr (sgr-copy (cbuf-current-sgr cbuf))])
    (sgr-set-background-color! new-sgr color)
    (set-cbuf-current-sgr! cbuf new-sgr)))

(define (cbuf-apply-sgr-to-selection cbuf sgr)
  "Apply SGR to selected text (between mark and cursor)"
  (when (cbuf-mark-set? cbuf)
    (let* ([mark-line (cbuf-mark-line cbuf)]
           [mark-x-data (cbuf-mark-x-data cbuf)]
           [cursor-line (cbuf-line-cur cbuf)]
           [cursor-x-data (cbuf-x-data cbuf)])
      
      ;; For now, only handle selections on the same line
      (when (= mark-line cursor-line)
        (let ([start-data (min mark-x-data cursor-x-data)]
              [end-data (max mark-x-data cursor-x-data)])
          (cbuf-set-sgr-range cbuf start-data end-data sgr))))))

;;; =================================================================
;;; MARK OPERATIONS
;;; =================================================================

(define (cbuf-set-mark! cbuf)
  "Set mark at current position"
  (set-cbuf-mark-set?! cbuf #t)
  (set-cbuf-mark-line! cbuf (cbuf-line-cur cbuf))
  (set-cbuf-mark-x-data! cbuf (cbuf-x-data cbuf)))

(define (cbuf-clear-mark! cbuf)
  "Clear the mark"
  (set-cbuf-mark-set?! cbuf #f))

(define (cbuf-goto-mark cbuf)
  "Move cursor to mark position"
  (when (cbuf-mark-set? cbuf)
    (cbuf-set-y! cbuf (cbuf-mark-line cbuf))
    (cbuf-set-x! cbuf (cbuf-mark-x-data cbuf) 'data)))

;;; =================================================================
;;; STATUS QUERIES
;;; =================================================================

(define (cbuf-beginning-of-line? cbuf)
  "Return #t if cursor is at beginning of line"
  (= (cbuf-x-data cbuf) 0))

(define (cbuf-end-of-line? cbuf)
  "Return #t if cursor is at end of line"
  (= (cbuf-x-data cbuf) (cbuf-text-cur-base-length cbuf)))

(define (cbuf-beginning-of-buffer? cbuf)
  "Return #t if cursor is at beginning of buffer"
  (and (= (cbuf-line-cur cbuf) 0)
       (= (cbuf-x-data cbuf) 0)))

(define (cbuf-end-of-buffer? cbuf)
  "Return #t if cursor is at end of buffer"
  (and (= (cbuf-line-cur cbuf) (- (cbuf-line-count cbuf) 1))
       (= (cbuf-x-data cbuf) (cbuf-text-cur-base-length cbuf))))

(define (cbuf-on-first-page? cbuf)
  "Return #t if cursor is on first page"
  (< (cbuf-line-cur cbuf) (cbuf-form-size cbuf)))

(define (cbuf-on-last-page? cbuf)
  "Return #t if cursor is on last page"
  (let* ([y (cbuf-line-cur cbuf)]
         [ps (cbuf-form-size cbuf)]
         [y-on-page (remainder y ps)]
         [y-start-of-next-page (* ps (+ (quotient y ps) 1))])
    (>= (+ y-start-of-next-page y-on-page) (cbuf-line-count cbuf))))

;;; =================================================================
;;; CONFIGURATION FUNCTIONS
;;; =================================================================

(define (cbuf-set-line-home! cbuf n)
  "SLH - Set Line Home"
  (set-cbuf-home-pos! cbuf n))

(define (cbuf-set-tab-size! cbuf n)
  "Set tab size and recompute all metrics"
  (set-cbuf-tab-size! cbuf n)
  ;; Recompute all text metrics with new tab size
  (let* ([text-list (cbuf-text cbuf)]
         [cjk? (cbuf-cjk? cbuf)]
         [new-metrics (map (lambda (line)
                             (compute-text-metrics line n #:cjk? cjk?))
                           text-list)])
    (set-cbuf-text-metrics! cbuf new-metrics)
    ;; Update current position
    (cbuf-update-x-cell! cbuf)))

(define (cbuf-set-vert-tab-size! cbuf n)
  "Set vertical tab size"
  (set-cbuf-vert-tab-size! cbuf n))

(define (cbuf-set-form-size! cbuf n)
  "Set form (page) size"
  (set-cbuf-form-size! cbuf n))

(define (cbuf-set-line-ending! cbuf ending)
  "Set line ending style for cbuf"
  (unless (member ending '("\n" "\r\n" "\r" "\u2028"))
    (error "Invalid line ending" ending))
  (set-cbuf-line-ending! cbuf ending))

;;; NOTE: Additional text operations would be implemented here following 
;;; the same patterns established above. This includes:
;;; - Complete text insertion/deletion operations
;;; - Word manipulation functions  
;;; - Line manipulation functions
;;; - Erase operations
;;; All following the same modular, utility-based approach.
