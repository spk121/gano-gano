;;; Gano Character Buffer Module - Complete Basic Operations with Streamlined Undo
;;; Complete ECMA-48 terminal control implementation with plugin-based undo system
;;;
;;; This file contains the minimum viable set of text editing operations
;;; All operations support undo through a plugin-based registry system

(define-module (gano cbuf-basic)
  #:use-module (ice-9 format)            ; Format function
  #:use-module (ice-9 textual-ports)     ; get-string-all
  #:use-module (srfi srfi-1)             ; List utilities
  #:use-module (srfi srfi-9)             ; Record types
  #:use-module (srfi srfi-11)            ; let-values
  #:use-module (srfi srfi-13)            ; String utilities
  #:use-module (srfi srfi-34)            ; Exception handling
  #:use-module (srfi srfi-35)            ; Condition types
  #:use-module (gano cbuf-core)          ; Core record definitions
  #:use-module (gano cbuf-utils)         ; Pure utility functions
  #:use-module (gano text-metrics)       ; Immutable text metrics module
  #:use-module (gano rendering)          ; SGR support
  #:use-module (gano list-utils)         ; Immutable list operations
  #:use-module (gano char)               ; Character utilities
  #:use-module (gano string-split)       ; String splitting and joining
  #:use-module (gano string-utils)       ; String manipulation utilities
  #:use-module (gano uax9-core)
  #:export (
    ;; Low-level helpers shared with cbuf-standard / cbuf-extra /
    ;; cbuf-serialization (not intended for editor code)
    cbuf-restore-line-metrics!
    cbuf-find-grapheme-cluster-bounds
    cbuf-bracket-line
    cbuf-bracket-x-data

    ;; Undo system API
    cbuf-register-undo-operation!
    cbuf-unregister-undo-operation!
    cbuf-get-undo-operation-handler
    cbuf-list-registered-operations
    cbuf-save-undo!
    cbuf-undo
    cbuf-can-undo?
    cbuf-clear-undo-history!
    cbuf-get-undo-count
    cbuf-set-max-undo-operations!
    
    ;; Helper functions
    cbuf-x-data->x-index
    cbuf-x-index->x-data	    
    
    ;; Character operations
    cbuf-insert-char!
    cbuf-delete-char!
    cbuf-backspace!

    ;; Line operations
    cbuf-insert-newline!
    cbuf-delete-line!
    cbuf-join-lines!

    ;; Navigation operations
    cbuf-set-x!
    cbuf-set-y!
    cbuf-forward-char!
    cbuf-backward-char!
    cbuf-next-line!
    cbuf-previous-line!
    cbuf-beginning-of-line!
    cbuf-end-of-line!
    cbuf-beginning-of-buffer!
    cbuf-end-of-buffer!

    ;; String operations
    cbuf-insert-string!
    cbuf-delete-region!

    ;; Mark/selection operations
    cbuf-set-mark!
    cbuf-clear-mark!
    cbuf-exchange-point-and-mark!
    cbuf-cut-region!
    cbuf-copy-region!
    cbuf-paste!
    cbuf-get-region-text

    ;; Final newlines
    cbuf-apply-final-newline-policy
    cbuf-should-have-final-newline?
    cbuf-normalize-final-newline!
    cbuf-set-final-newline-policy!

    ;; Buffer operations
    cbuf-clear!
    cbuf-load-from-string!
    cbuf-save-to-string

    ;; Word operations
    cbuf-handle-tab!

    ;; Validation helpers
    cbuf-validate-string-insertion
    cbuf-validate-combining-mark-insertion

    ;; Rendering helpers
    cbuf-render-line
    cbuf-render-line-string-only

    ;; Status queries
    cbuf-beginning-of-line?
    cbuf-end-of-line?
    cbuf-beginning-of-buffer?
    cbuf-end-of-buffer?
    cbuf-on-first-page?
    cbuf-on-last-page?
    ))

;;; =================================================================
;;; UNDO OPERATION REGISTRY
;;; =================================================================

;; Global registry for undo operation handlers
(define *undo-operation-registry* (make-hash-table))

;; Default maximum undo operations
(define *max-undo-operations* 1000)

;;; =================================================================
;;; UNDO OPERATION HANDLER API
;;; =================================================================

(define (cbuf-register-undo-operation! operation-type capturer restorer)
  "Register an undo operation handler.
   OPERATION-TYPE: symbol identifying the operation (e.g., 'delete-to-eol)
   CAPTURER: function that captures state before operation: (lambda (cbuf . args) -> state)
   RESTORER: function that restores state: (lambda (cbuf state . args) -> void)"
  (hash-set! *undo-operation-registry* operation-type (cons capturer restorer)))

(define (cbuf-unregister-undo-operation! operation-type)
  "Unregister an undo operation handler"
  (hash-remove! *undo-operation-registry* operation-type))

(define (cbuf-get-undo-operation-handler operation-type)
  "Get the handler (capturer . restorer) for an operation type"
  (hash-ref *undo-operation-registry* operation-type #f))

(define (cbuf-list-registered-operations)
  "List all registered undo operation types"
  (hash-map->list (lambda (k v) k) *undo-operation-registry*))

;;; =================================================================
;;; UNDO STATE CAPTURE AND RESTORATION
;;; =================================================================

(define (cbuf-capture-base-state cbuf)
  "Capture the base state that all operations need to restore"
  `((position ,(cbuf-line-cur cbuf)
              ,(cbuf-x-data cbuf)
              ,(cbuf-x-cell cbuf)
              ,(cbuf-x-goal cbuf))
    (mark ,(cbuf-mark-set? cbuf)
          ,(cbuf-mark-line cbuf)
          ,(cbuf-mark-x-data cbuf))
    (sgr-state ,(sgr-copy (cbuf-current-sgr cbuf))
               ,(cbuf-default-grcm cbuf)
               ,(map sgr-copy (cbuf-sgr-stack cbuf)))
    (buffer-state ,(cbuf-modified? cbuf)
                  ,(cbuf-final-newline? cbuf)
                  ,(cbuf-final-newline-policy cbuf))))

(define (cbuf-restore-base-state! cbuf base-state)
  "Restore the base state for all operations"
  (let ([position (assq 'position base-state)]
        [mark (assq 'mark base-state)]
        [sgr-state (assq 'sgr-state base-state)]
        [buffer-state (assq 'buffer-state base-state)])
    
    ;; Restore cursor position
    (when position
      (let ([line (cadr position)]
            [x-data (caddr position)]
            [x-cell (cadddr position)]
            [x-goal (cadddr (cdr position))])
        (set-cbuf-line-cur! cbuf (cbuf-bracket-line cbuf line))
        (set-cbuf-x-data! cbuf (cbuf-bracket-x-data cbuf x-data))
        (set-cbuf-x-cell! cbuf x-cell)
        (set-cbuf-x-goal! cbuf x-goal)))
    
    ;; Restore mark state
    (when mark
      (let ([mark-set? (cadr mark)]
            [mark-line (caddr mark)]
            [mark-x-data (cadddr mark)])
        (set-cbuf-mark-set?! cbuf mark-set?)
        (set-cbuf-mark-line! cbuf (cbuf-bracket-line cbuf mark-line))
        (set-cbuf-mark-x-data! cbuf mark-x-data)))
    
    ;; Restore SGR state
    (when sgr-state
      (let ([saved-current-sgr (cadr sgr-state)]
            [saved-grcm (caddr sgr-state)]
            [saved-stack (cadddr sgr-state)])
        (set-cbuf-current-sgr! cbuf (sgr-copy saved-current-sgr))
        (set-cbuf-default-grcm! cbuf saved-grcm)
        (set-cbuf-sgr-stack! cbuf (map sgr-copy saved-stack))))
    
    ;; Restore buffer state
    (when buffer-state
      (let ([modified? (cadr buffer-state)]
            [final-newline? (caddr buffer-state)]
            [final-newline-policy (cadddr buffer-state)])
        (set-cbuf-modified?! cbuf modified?)
        (set-cbuf-final-newline?! cbuf final-newline?)
        (set-cbuf-final-newline-policy! cbuf final-newline-policy)))))

;;; =================================================================
;;; UNDO RECORDING AND EXECUTION
;;; =================================================================

(define (cbuf-save-undo! cbuf operation-type . args)
  "Save undo using the plugin system.
   Automatically calls the registered capturer for the operation type."
  (let ([handler (cbuf-get-undo-operation-handler operation-type)])
    (if handler
        (let* ([capturer (car handler)]
               [base-state (cbuf-capture-base-state cbuf)]
               [operation-state (apply capturer cbuf args)]
               [undo-record `((base-state ,base-state)
                             (operation-type ,operation-type)
                             (operation-state ,operation-state)
                             (operation-args ,args))])
          
          ;; Add to undo list with size management
          (let ([new-undo-list (cons undo-record (cbuf-undo-list cbuf))])
            (set-cbuf-undo-list! cbuf 
              (if (> (length new-undo-list) *max-undo-operations*)
                  (take new-undo-list *max-undo-operations*)
                  new-undo-list))))
        
        (error "Unregistered undo operation type" operation-type))))

(define (cbuf-undo cbuf)
  "Perform undo using the plugin system"
  (when (cbuf-can-undo? cbuf)
    (let* ([undo-record (car (cbuf-undo-list cbuf))]
           [base-state (cadr (assq 'base-state undo-record))]
           [operation-type (cadr (assq 'operation-type undo-record))]
           [operation-state (cadr (assq 'operation-state undo-record))]
           [operation-args (cadr (assq 'operation-args undo-record))])
      
      ;; Get the restorer function
      (let ([handler (cbuf-get-undo-operation-handler operation-type)])
        (if handler
            (let ([restorer (cdr handler)])
              ;; Call the specific operation restorer
              (apply restorer cbuf operation-state operation-args)
              
              ;; Restore base state
              (cbuf-restore-base-state! cbuf base-state)
              
              ;; Remove this undo record
              (set-cbuf-undo-list! cbuf (cdr (cbuf-undo-list cbuf))))
            
            (error "Cannot undo unregistered operation type" operation-type))))))

(define (cbuf-can-undo? cbuf)
  "Return #t if there are operations that can be undone"
  (not (null? (cbuf-undo-list cbuf))))

(define (cbuf-clear-undo-history! cbuf)
  "Clear all undo history"
  (set-cbuf-undo-list! cbuf '()))

(define (cbuf-get-undo-count cbuf)
  "Get the number of operations that can be undone"
  (length (cbuf-undo-list cbuf)))

(define (cbuf-set-max-undo-operations! max-ops)
  "Set the maximum number of undo operations to keep"
  (set! *max-undo-operations* max-ops))

;;; =================================================================
;;; BUILT-IN OPERATION HANDLERS
;;; =================================================================

;; Character insertion handler
(define (capture-char-insertion-state cbuf char position)
  "Capture state for character insertion"
  `((line-num ,(cbuf-line-cur cbuf))
    (old-metrics ,(cbuf-metrics-cur cbuf))))

(define (restore-char-insertion-state cbuf state char position)
  "Restore state after character insertion"
  (let ([line-num (cadr (assq 'line-num state))]
        [old-metrics (cadr (assq 'old-metrics state))])
    (cbuf-restore-line-metrics! cbuf line-num old-metrics)))

;; Character deletion handler
(define (capture-char-deletion-state cbuf position)
  "Capture state for character deletion"
  `((line-num ,(cbuf-line-cur cbuf))
    (old-metrics ,(cbuf-metrics-cur cbuf))))

(define (restore-char-deletion-state cbuf state position)
  "Restore state after character deletion"
  (let ([line-num (cadr (assq 'line-num state))]
        [old-metrics (cadr (assq 'old-metrics state))])
    (cbuf-restore-line-metrics! cbuf line-num old-metrics)))

;; Newline insertion handler
(define (capture-newline-insertion-state cbuf position)
  "Capture state for newline insertion"
  `((line-num ,(cbuf-line-cur cbuf))
    (old-metrics ,(cbuf-metrics-cur cbuf))
    (line-count-before ,(cbuf-line-count cbuf))))

(define (restore-newline-insertion-state cbuf state position)
  "Restore state after newline insertion"
  (let ([line-num (cadr (assq 'line-num state))]
        [old-metrics (cadr (assq 'old-metrics state))])
    
    ;; Remove the inserted line and restore original line
    (let* ([current-metrics-list (cbuf-text-metrics cbuf)]
           [after-removal (list-delete-range current-metrics-list (+ line-num 1) (+ line-num 2))]
           [final-metrics-list (list-update after-removal line-num old-metrics)])
      (set-cbuf-text-metrics! cbuf final-metrics-list))))

;; String insertion handler
(define (capture-string-insertion-state cbuf string position)
  "Capture state for string insertion"
  (if (string-contains string "\n")
      ;; Multi-line string insertion
      `((type multiline)
        (line-num ,(cbuf-line-cur cbuf))
        (old-metrics ,(cbuf-metrics-cur cbuf))
        (line-count-before ,(cbuf-line-count cbuf)))
      ;; Single-line string insertion
      `((type single-line)
        (line-num ,(cbuf-line-cur cbuf))
        (old-metrics ,(cbuf-metrics-cur cbuf)))))

(define (restore-string-insertion-state cbuf state string position)
  "Restore state after string insertion"
  (let ([type (cadr (assq 'type state))]
        [line-num (cadr (assq 'line-num state))]
        [old-metrics (cadr (assq 'old-metrics state))])
    
    (case type
      [(single-line)
       ;; Simple single-line restoration
       (cbuf-restore-line-metrics! cbuf line-num old-metrics)]
      
      [(multiline)
       ;; Complex multi-line restoration
       (let ([line-count-before (cadr (assq 'line-count-before state))]
             [current-line-count (cbuf-line-count cbuf)])
         ;; Remove all inserted lines except the first
         (when (> current-line-count line-count-before)
           (let* ([metrics-list (cbuf-text-metrics cbuf)]
                  [lines-to-remove (- current-line-count line-count-before)]
                  [after-removal (list-delete-range metrics-list 
                                                   (+ line-num 1) 
                                                   (+ line-num 1 lines-to-remove))])
             (set-cbuf-text-metrics! cbuf after-removal)))
         ;; Restore the original line
         (cbuf-restore-line-metrics! cbuf line-num old-metrics))])))

;; Region deletion handler
(define (capture-region-deletion-state cbuf start-line start-x-data end-line end-x-data)
  "Capture state for region deletion"
  (if (= start-line end-line)
      ;; Single line deletion
      `((type single-line)
        (line-num ,start-line)
        (old-metrics ,(list-ref (cbuf-text-metrics cbuf) start-line)))
      ;; Multi-line deletion
      `((type multiline)
        (start-line ,start-line)
        (end-line ,end-line)
        (start-line-metrics ,(list-ref (cbuf-text-metrics cbuf) start-line))
        (end-line-metrics ,(list-ref (cbuf-text-metrics cbuf) end-line))
        (deleted-lines ,(take (drop (cbuf-text-metrics cbuf) (+ start-line 1)) 
                             (- end-line start-line))))))

(define (restore-region-deletion-state cbuf state start-line start-x-data end-line end-x-data)
  "Restore state after region deletion"
  (let ([type (cadr (assq 'type state))])
    (case type
      [(single-line)
       (let ([line-num (cadr (assq 'line-num state))]
             [old-metrics (cadr (assq 'old-metrics state))])
         (cbuf-restore-line-metrics! cbuf line-num old-metrics))]
      
      [(multiline)
       (let ([start-line-orig (cadr (assq 'start-line state))]
             [end-line-orig (cadr (assq 'end-line state))]
             [start-line-metrics (cadr (assq 'start-line-metrics state))]
             [end-line-metrics (cadr (assq 'end-line-metrics state))]
             [deleted-lines (cadr (assq 'deleted-lines state))])
         
         ;; Restore start line
         (cbuf-restore-line-metrics! cbuf start-line-orig start-line-metrics)
         
         ;; Insert deleted middle lines
         (when (not (null? deleted-lines))
           (let* ([metrics-list (cbuf-text-metrics cbuf)]
                  [before (take metrics-list (+ start-line-orig 1))]
                  [after (drop metrics-list (+ start-line-orig 1))]
                  [new-metrics-list (append before deleted-lines after)])
             (set-cbuf-text-metrics! cbuf new-metrics-list)))
         
         ;; Insert end line
         (let* ([metrics-list (cbuf-text-metrics cbuf)]
                [new-metrics-list (list-insert metrics-list end-line-orig end-line-metrics)])
           (set-cbuf-text-metrics! cbuf new-metrics-list)))])))

;; Line deletion handler
(define (capture-line-deletion-state cbuf)
  "Capture state for line deletion"
  `((line-num ,(cbuf-line-cur cbuf))
    (deleted-metrics ,(cbuf-metrics-cur cbuf))
    (line-count-before ,(cbuf-line-count cbuf))))

(define (restore-line-deletion-state cbuf state)
  "Restore state after line deletion"
  (let ([line-num (cadr (assq 'line-num state))]
        [deleted-metrics (cadr (assq 'deleted-metrics state))])
    ;; Insert the deleted line back
    (let* ([metrics-list (cbuf-text-metrics cbuf)]
           [new-metrics-list (list-insert metrics-list line-num deleted-metrics)])
      (set-cbuf-text-metrics! cbuf new-metrics-list))))

;; Line joining handler
(define (capture-line-joining-state cbuf)
  "Capture state for line joining"
  (let ([current-line (cbuf-line-cur cbuf)])
    `((current-line ,current-line)
      (current-metrics ,(cbuf-metrics-cur cbuf))
      (next-line ,(+ current-line 1))
      (next-metrics ,(list-ref (cbuf-text-metrics cbuf) (+ current-line 1))))))

(define (restore-line-joining-state cbuf state)
  "Restore state after line joining"
  (let ([current-line (cadr (assq 'current-line state))]
        [current-metrics (cadr (assq 'current-metrics state))]
        [next-line (cadr (assq 'next-line state))]
        [next-metrics (cadr (assq 'next-metrics state))])
    
    ;; Restore both lines
    (cbuf-restore-line-metrics! cbuf current-line current-metrics)
    (let* ([metrics-list (cbuf-text-metrics cbuf)]
           [new-metrics-list (list-insert metrics-list next-line next-metrics)])
      (set-cbuf-text-metrics! cbuf new-metrics-list))))

;; Buffer clear handler
(define (capture-buffer-clear-state cbuf)
  "Capture state for buffer clear"
  `((all-metrics ,(cbuf-text-metrics cbuf))
    (cursor-line ,(cbuf-line-cur cbuf))
    (cursor-x-data ,(cbuf-x-data cbuf))))

(define (restore-buffer-clear-state cbuf state)
  "Restore state after buffer clear"
  (let ([all-metrics (cadr (assq 'all-metrics state))])
    (set-cbuf-text-metrics! cbuf all-metrics)))

;;; =================================================================
;;; REGISTRATION OF BUILT-IN OPERATIONS
;;; =================================================================

(define (cbuf-register-built-in-undo-operations!)
  "Register all built-in undo operations"
  (cbuf-register-undo-operation! 'insert-char
                                  capture-char-insertion-state
                                  restore-char-insertion-state)
  
  (cbuf-register-undo-operation! 'delete-char
                                  capture-char-deletion-state
                                  restore-char-deletion-state)
  
  (cbuf-register-undo-operation! 'backspace
                                  capture-char-deletion-state
                                  restore-char-deletion-state)
  
  (cbuf-register-undo-operation! 'insert-newline
                                  capture-newline-insertion-state
                                  restore-newline-insertion-state)
  
  (cbuf-register-undo-operation! 'insert-string
                                  capture-string-insertion-state
                                  restore-string-insertion-state)
  
  (cbuf-register-undo-operation! 'delete-region
                                  capture-region-deletion-state
                                  restore-region-deletion-state)
  
  (cbuf-register-undo-operation! 'delete-line
                                  capture-line-deletion-state
                                  restore-line-deletion-state)
  
  (cbuf-register-undo-operation! 'join-lines
                                  capture-line-joining-state
                                  restore-line-joining-state)
  
  (cbuf-register-undo-operation! 'clear-buffer
                                  capture-buffer-clear-state
                                  restore-buffer-clear-state))

;;; =================================================================
;;; HELPER FUNCTIONS (using utilities from cbuf-utils)
;;; =================================================================

(define (cbuf-validate-line-movement cbuf current-line delta operation)
  "Validate line movement, return (target-line clamped-line clamped? operation)"
  (validate-line-movement-pure current-line delta (- (cbuf-line-count cbuf) 1) operation))

(define (cbuf-validate-column-movement cbuf current-column delta operation)
  "Validate column movement, return (target-column clamped-column clamped? operation)"
  (validate-column-movement-pure current-column delta (cbuf-text-cur-cell-length cbuf) operation))

(define (cbuf-validate-absolute-position cbuf line column operation)
  "Validate absolute positioning, return detailed validation info"
  (let* ([max-line (- (cbuf-line-count cbuf) 1)]
         [max-column (if (< line (cbuf-line-count cbuf))
                        (text-metrics-cell-length
                         (list-ref (cbuf-text-metrics cbuf)
                                   (max 0 (min line max-line))))
                        0)])
    (validate-absolute-position-pure line column max-line max-column operation)))

(define (cbuf-validate-combining-mark-insertion cbuf char-new position)
  "Validate combining mark insertion using cbuf-utils validation"
  (when (char-combining-mark? char-new)
    (let* ([txt (cbuf-text-cur cbuf)]
           [validation-result (validate-combining-marks-at-insertion
                              txt position (string char-new))])
      (unless (car validation-result)
        (let ([violations (cadr validation-result)])
          (when (not (null? violations))
            (let ([violation (car violations)])
              (error "Invalid combining mark insertion" violation))))))))

(define (cbuf-validate-string-insertion cbuf str position)
  "Validate string insertion for combining mark limits"
  (let* ([current-text (cbuf-text-cur cbuf)]
         [validation-result (validate-string-combining-marks str)])

    ;; First check if the string itself is valid
    (unless (car validation-result)
      (error "Invalid combining marks in inserted string" (cadr validation-result)))

    ;; Then check insertion at position
    (let ([insertion-result (validate-combining-marks-at-insertion
                            current-text position str)])
      (unless (car insertion-result)
        (error "Invalid combining mark insertion at position"
               position (cadr insertion-result))))))

(define (cbuf-find-grapheme-cluster-bounds cbuf x-data)
  "Find the string index bounds [start, end) for the grapheme cluster at x-data position.
   Returns (start-index end-index) where the range includes the base character
   and any following combining marks."
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [text (cbuf-text-cur cbuf)]
         [base-indices (text-metrics-string-base-indices metrics)])

    (cond
      ;; Position beyond base characters
      [(>= x-data (length base-indices))
       (list (string-length text) (string-length text))]  ; Empty range at end

      ;; Valid position
      [else
       (let* ([start-index (list-ref base-indices x-data)]
              [end-index (if (< (+ x-data 1) (length base-indices))
                            (list-ref base-indices (+ x-data 1))
                            (string-length text))])
         (list start-index end-index))])))

(define (cbuf-restore-line-metrics! cbuf line-num old-metrics)
  "Restore a single line's metrics (helper for undo)"
  (let ([new-metrics-list (list-update (cbuf-text-metrics cbuf) line-num old-metrics)])
    (set-cbuf-text-metrics! cbuf new-metrics-list)))

;;; =================================================================
;;; POSITION MANAGEMENT FUNCTIONS
;;; =================================================================

(define (cbuf-update-metrics-cur! cbuf new-metrics)
  "Update the metrics for the current line. No undo save."
  (let* ([line-num (cbuf-line-cur cbuf)]
         [metrics-list (cbuf-text-metrics cbuf)]
         [new-metrics-list (list-update metrics-list line-num new-metrics)])
    (set-cbuf-text-metrics! cbuf new-metrics-list)
    (set-cbuf-modified?! cbuf #t)))

;;; Position conversion functions using text metrics
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

;;; Position management
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

;;; =================================================================
;;; CHARACTER OPERATIONS
;;; =================================================================

(define bidi-state (make-bidi-state 0 'neutral 'none))

(define (cbuf-insert-char! cbuf char-new)
  "Insert a character at the current position with undo support"
  (let* ([x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)])

    ;; Validate combining mark insertion
    (cbuf-validate-combining-mark-insertion cbuf char-new x-data)

    ;; Save undo state
    (cbuf-save-undo! cbuf 'insert-char char-new x-data)

    ;; Perform the operation
    (let ([new-metrics (text-metrics-insert-char-with-sgr-and-bidi
                        (cbuf-metrics-cur cbuf)
                        x-index
                        char-new
                        (cbuf-current-sgr cbuf)
                        bidi-state)])
      
      (cbuf-update-metrics-cur! cbuf new-metrics)
      (cbuf-set-x! cbuf (+ x-data 1) 'data)
      (set-cbuf-modified?! cbuf #t))))

(define (cbuf-delete-char! cbuf)
  "Delete the complete grapheme cluster at current position with undo support"
  (unless (cbuf-end-of-line? cbuf)
    (let* ([x-data (cbuf-x-data cbuf)]
           [cluster-bounds (cbuf-find-grapheme-cluster-bounds cbuf x-data)]
           [start-index (car cluster-bounds)]
           [end-index (cadr cluster-bounds)])

      (when (< start-index end-index)
        ;; Save undo state
        (cbuf-save-undo! cbuf 'delete-char x-data)

        ;; Use bidi-aware deletion from text-metrics
        (let ([new-metrics (text-metrics-delete-range (cbuf-metrics-cur cbuf) 
                                                     start-index end-index)])
          (cbuf-update-metrics-cur! cbuf new-metrics)
          (cbuf-set-x! cbuf x-data 'data)
          (set-cbuf-modified?! cbuf #t))))))

(define (cbuf-backspace! cbuf)
  "Delete the complete grapheme cluster before current position with undo support"
  (unless (cbuf-beginning-of-line? cbuf)
    (let* ([x-data (cbuf-x-data cbuf)]
           [prev-x-data (- x-data 1)]
           [cluster-bounds (cbuf-find-grapheme-cluster-bounds cbuf prev-x-data)]
           [start-index (car cluster-bounds)]
           [end-index (cadr cluster-bounds)])

      (when (< start-index end-index)
        ;; Save undo state
        (cbuf-save-undo! cbuf 'backspace prev-x-data)

        ;; Delete the entire grapheme cluster
        (let ([new-metrics (text-metrics-delete-range (cbuf-metrics-cur cbuf)
                                                      start-index end-index)])
          (cbuf-update-metrics-cur! cbuf new-metrics)
          (cbuf-set-x! cbuf prev-x-data 'data)
          (set-cbuf-modified?! cbuf #t))))))

;;; =================================================================
;;; LINE OPERATIONS
;;; =================================================================

(define (cbuf-insert-newline! cbuf)
  "Insert a newline at current position with undo support"
  (let* ([x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)]
         [current-line (cbuf-line-cur cbuf)]
         [text (cbuf-text-cur cbuf)]
         [sgr-list (cbuf-sgr-list-cur cbuf)]
         [at-end-of-buffer? (and (= current-line (- (cbuf-line-count cbuf) 1))
                                (= x-data (cbuf-text-cur-base-length cbuf)))])
    
    ;; Save undo state
    (cbuf-save-undo! cbuf 'insert-newline x-data)
    
    ;; Split current line at cursor position
    (let* ([left-text (substring text 0 x-index)]
           [right-text (substring text x-index)]
           [left-sgr (take sgr-list x-index)]
           [right-sgr (drop sgr-list x-index)]
           [left-metrics (compute-text-metrics-with-sgr left-text left-sgr 
                                                        (cbuf-tab-size cbuf) 
                                                        #:cjk? (cbuf-cjk? cbuf))]
           [right-metrics (compute-text-metrics-with-sgr right-text right-sgr 
                                                         (cbuf-tab-size cbuf) 
                                                         #:cjk? (cbuf-cjk? cbuf))])
      
      ;; Update current line with left part
      (cbuf-update-metrics-cur! cbuf left-metrics)
      
      ;; Insert new line with right part
      (let* ([metrics-list (cbuf-text-metrics cbuf)]
             [new-metrics-list (list-insert metrics-list (+ current-line 1) right-metrics)])
        (set-cbuf-text-metrics! cbuf new-metrics-list))
      
      ;; Update final newline status
      (when at-end-of-buffer?
        (set-cbuf-final-newline?! cbuf #t))
      
      ;; Move cursor to beginning of new line
      (cbuf-set-y! cbuf (+ current-line 1))
      (cbuf-set-x! cbuf 0 'data)
      
      ;; Mark as modified
      (set-cbuf-modified?! cbuf #t))))

(define (cbuf-delete-line! cbuf)
  "Delete the current line with undo support"
  (when (> (cbuf-line-count cbuf) 1)  ; Don't delete if it's the only line
    (let ([current-line (cbuf-line-cur cbuf)]
          [is-last-line? (= (cbuf-line-cur cbuf) (- (cbuf-line-count cbuf) 1))]
          [is-empty-last-line? (and (= (cbuf-line-cur cbuf) (- (cbuf-line-count cbuf) 1))
                                   (string-null? (cbuf-text-cur cbuf)))])

      ;; Save undo state
      (cbuf-save-undo! cbuf 'delete-line)

      ;; Update final newline status
      (when (and is-last-line? is-empty-last-line? (cbuf-final-newline? cbuf))
        ;; Deleting empty last line removes final newline
        (set-cbuf-final-newline?! cbuf #f))

      ;; Remove the line
      (let* ([metrics-list (cbuf-text-metrics cbuf)]
             [new-metrics-list (list-delete-range metrics-list current-line (+ current-line 1))])
        (set-cbuf-text-metrics! cbuf new-metrics-list))

      ;; Adjust cursor position if needed
      (when (>= current-line (cbuf-line-count cbuf))
        (cbuf-set-y! cbuf (- (cbuf-line-count cbuf) 1)))

      ;; Move to beginning of line
      (cbuf-set-x! cbuf 0 'data)

      ;; Mark as modified
      (set-cbuf-modified?! cbuf #t))))

(define (cbuf-join-lines! cbuf)
  "Join current line with next line with undo support"
  (let ([current-line (cbuf-line-cur cbuf)])
    (when (< current-line (- (cbuf-line-count cbuf) 1))  ; Not on last line
      ;; Save undo state
      (cbuf-save-undo! cbuf 'join-lines)
      
      (let* ([current-text (cbuf-text-cur cbuf)]
             [current-sgr (cbuf-sgr-list-cur cbuf)]
             [next-text (cbuf-get-line-text cbuf (+ current-line 1))]
             [next-sgr (text-metrics-sgr-list (list-ref (cbuf-text-metrics cbuf) (+ current-line 1)))]
             [joined-text (string-append current-text next-text)]
             [joined-sgr (append current-sgr next-sgr)]
             [joined-metrics (compute-text-metrics-with-sgr joined-text joined-sgr
                                                           (cbuf-tab-size cbuf)
                                                           #:cjk? (cbuf-cjk? cbuf))])

        ;; Update current line with joined content
        (cbuf-update-metrics-cur! cbuf joined-metrics)

        ;; Remove the next line
        (let* ([metrics-list (cbuf-text-metrics cbuf)]
               [new-metrics-list (list-delete-range metrics-list (+ current-line 1) (+ current-line 2))])
          (set-cbuf-text-metrics! cbuf new-metrics-list))

        ;; Mark as modified
        (set-cbuf-modified?! cbuf #t)))))

;;; =================================================================
;;; NAVIGATION OPERATIONS
;;; =================================================================

(define (cbuf-forward-char! cbuf)
  "Move cursor forward one character"
  (let ([x-data (cbuf-x-data cbuf)])
    (when (< x-data (cbuf-text-cur-base-length cbuf))
      (cbuf-set-x! cbuf (+ x-data 1) 'data))))

(define (cbuf-backward-char! cbuf)
  "Move cursor backward one character"
  (let ([x-data (cbuf-x-data cbuf)])
    (when (> x-data 0)
      (cbuf-set-x! cbuf (- x-data 1) 'data))))

(define (cbuf-next-line! cbuf)
  "Move cursor to next line, maintaining x-goal"
  (let ([current-line (cbuf-line-cur cbuf)])
    (when (< current-line (- (cbuf-line-count cbuf) 1))
      (cbuf-set-y! cbuf (+ current-line 1)))))

(define (cbuf-previous-line! cbuf)
  "Move cursor to previous line, maintaining x-goal"
  (let ([current-line (cbuf-line-cur cbuf)])
    (when (> current-line 0)
      (cbuf-set-y! cbuf (- current-line 1)))))

(define (cbuf-beginning-of-line! cbuf)
  "Move cursor to beginning of current line"
  (cbuf-set-x! cbuf 0 'data))

(define (cbuf-end-of-line! cbuf)
  "Move cursor to end of current line"
  (cbuf-set-x! cbuf (cbuf-text-cur-base-length cbuf) 'data))

(define (cbuf-beginning-of-buffer! cbuf)
  "Move cursor to beginning of buffer"
  (cbuf-set-y! cbuf 0)
  (cbuf-set-x! cbuf 0 'data))

(define (cbuf-end-of-buffer! cbuf)
  "Move cursor to end of buffer"
  (cbuf-set-y! cbuf (- (cbuf-line-count cbuf) 1))
  (cbuf-set-x! cbuf (cbuf-text-cur-base-length cbuf) 'data))

;;; =================================================================
;;; STRING OPERATIONS
;;; =================================================================

(define (cbuf-insert-string! cbuf str)
  "Insert a string at the current position with undo support"
  ;; Validate the string first
  (cbuf-validate-string-insertion cbuf str (cbuf-x-data cbuf))

  ;; Save undo state
  (cbuf-save-undo! cbuf 'insert-string str (cbuf-x-data cbuf))

  (let* ([lines (string-split-lines str)]
         [current-line (cbuf-line-cur cbuf)]
         [x-data (cbuf-x-data cbuf)])

    (cond
     ;; Single line insertion
     [(= (length lines) 1)
      (let* ([text (cbuf-text-cur cbuf)]
             [sgr-list (cbuf-sgr-list-cur cbuf)]
             [x-index (cbuf-x-data->x-index cbuf x-data)]
             [insert-text (car lines)]
             [current-sgr (cbuf-current-sgr cbuf)]
             [insert-sgr-list (make-list (string-length insert-text) current-sgr)])

        ;; Insert the string
        (let* ([new-text (string-insert-string text x-index insert-text)]
               [new-sgr-list (append (take sgr-list x-index)
                                     insert-sgr-list
                                     (drop sgr-list x-index))]
               [new-metrics (compute-text-metrics-with-sgr new-text new-sgr-list
                                                          (cbuf-tab-size cbuf)
                                                          #:cjk? (cbuf-cjk? cbuf))])

          ;; Update the line
          (cbuf-update-metrics-cur! cbuf new-metrics)

          ;; Move cursor to end of inserted text using cbuf-utils
          (cbuf-set-x! cbuf (+ x-data (count-base-characters insert-text)) 'data)

          ;; Mark as modified
          (set-cbuf-modified?! cbuf #t)))]

     ;; Multi-line insertion
     [else
      (cbuf-insert-multiline-string-internal! cbuf lines)])))

(define (cbuf-insert-multiline-string-internal! cbuf lines)
  "Internal helper for multi-line string insertion (no additional undo save)"
  (let ([first-line (car lines)]
        [middle-lines (if (> (length lines) 2)
                          (drop (drop-right lines 1) 1)
                          '())]
        [last-line (if (> (length lines) 1) (last lines) "")])

    ;; Insert first line
    (cbuf-insert-single-line-internal! cbuf first-line)

    ;; Insert newline and each middle line
    (for-each (lambda (line)
                (cbuf-insert-newline-internal! cbuf)
                (cbuf-insert-single-line-internal! cbuf line))
              middle-lines)

    ;; Insert final newline and last line (if multi-line)
    (when (> (length lines) 1)
      (cbuf-insert-newline-internal! cbuf)
      (cbuf-insert-single-line-internal! cbuf last-line))))

(define (cbuf-insert-single-line-internal! cbuf str)
  "Internal helper for single line insertion (no undo save)"
  (let* ([text (cbuf-text-cur cbuf)]
         [sgr-list (cbuf-sgr-list-cur cbuf)]
         [x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)]
         [current-sgr (cbuf-current-sgr cbuf)]
         [insert-sgr-list (make-list (string-length str) current-sgr)])

    (let* ([new-text (string-insert-string text x-index str)]
           [new-sgr-list (append (take sgr-list x-index)
                                 insert-sgr-list
                                 (drop sgr-list x-index))]
           [new-metrics (compute-text-metrics-with-sgr new-text new-sgr-list
                                                      (cbuf-tab-size cbuf)
                                                      #:cjk? (cbuf-cjk? cbuf))])
      (cbuf-update-metrics-cur! cbuf new-metrics)
      (cbuf-set-x! cbuf (+ x-data (count-base-characters str)) 'data)
      (set-cbuf-modified?! cbuf #t))))

(define (cbuf-insert-newline-internal! cbuf)
  "Internal helper for newline insertion (no undo save)"
  (let* ([x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)]
         [current-line (cbuf-line-cur cbuf)]
         [text (cbuf-text-cur cbuf)]
         [sgr-list (cbuf-sgr-list-cur cbuf)])
    
    ;; Split current line at cursor position
    (let* ([left-text (substring text 0 x-index)]
           [right-text (substring text x-index)]
           [left-sgr (take sgr-list x-index)]
           [right-sgr (drop sgr-list x-index)]
           [left-metrics (compute-text-metrics-with-sgr left-text left-sgr 
                                                        (cbuf-tab-size cbuf) 
                                                        #:cjk? (cbuf-cjk? cbuf))]
           [right-metrics (compute-text-metrics-with-sgr right-text right-sgr 
                                                         (cbuf-tab-size cbuf) 
                                                         #:cjk? (cbuf-cjk? cbuf))])
      
      ;; Update current line with left part
      (cbuf-update-metrics-cur! cbuf left-metrics)
      
      ;; Insert new line with right part
      (let* ([metrics-list (cbuf-text-metrics cbuf)]
             [new-metrics-list (list-insert metrics-list (+ current-line 1) right-metrics)])
        (set-cbuf-text-metrics! cbuf new-metrics-list))
      
      ;; Move cursor to beginning of new line
      (cbuf-set-y! cbuf (+ current-line 1))
      (cbuf-set-x! cbuf 0 'data)
      
      ;; Mark as modified
      (set-cbuf-modified?! cbuf #t))))

(define (cbuf-delete-region! cbuf start-line start-x-data end-line end-x-data)
  "Delete text from start position to end position with undo support"
  ;; Normalize positions (ensure start <= end)
  (when (or (> start-line end-line)
            (and (= start-line end-line) (> start-x-data end-x-data)))
    (let ([temp-line start-line]
          [temp-x start-x-data])
      (set! start-line end-line)
      (set! start-x-data end-x-data)
      (set! end-line temp-line)
      (set! end-x-data temp-x)))
  
  ;; Validate line numbers
  (when (or (< start-line 0) (>= start-line (cbuf-line-count cbuf))
            (< end-line 0) (>= end-line (cbuf-line-count cbuf)))
    (error "cbuf-delete-region!: line numbers out of range" start-line end-line))
  
  ;; Save undo state
  (cbuf-save-undo! cbuf 'delete-region start-line start-x-data end-line end-x-data)
  
  ;; Perform the deletion
  (cond
    ;; Single line deletion
    [(= start-line end-line)
     (let* ([line-metrics (list-ref (cbuf-text-metrics cbuf) start-line)]
            [line-text (text-metrics-string line-metrics)]
            [line-sgr (text-metrics-sgr-list line-metrics)]
            [base-indices (text-metrics-string-base-indices line-metrics)])
       
       ;; Convert data positions to string indices using base-indices
       (let* ([start-index (if (< start-x-data (length base-indices))
                              (list-ref base-indices start-x-data)
                              (string-length line-text))]
              [end-index (if (< end-x-data (length base-indices))
                            (list-ref base-indices end-x-data)
                            (string-length line-text))])
         
         ;; Only proceed if we have a valid range
         (when (< start-index end-index)
           ;; Delete the range
           (let* ([new-text (string-delete-range line-text start-index end-index)]
                  [new-sgr-list (list-delete-range line-sgr start-index end-index)]
                  [new-metrics (compute-text-metrics-with-sgr new-text new-sgr-list
                                                             (cbuf-tab-size cbuf)
                                                             #:cjk? (cbuf-cjk? cbuf))])
             
             ;; Update the line
             (cbuf-update-metrics-cur! cbuf new-metrics)
             
             ;; Position cursor at start of deletion
             (cbuf-set-y! cbuf start-line)
             (cbuf-set-x! cbuf start-x-data 'data)))))]
    
    ;; Multi-line deletion
    [else
     (cbuf-delete-multiline-region-internal! cbuf start-line start-x-data end-line end-x-data)]))

(define (cbuf-delete-multiline-region-internal! cbuf start-line start-x-data end-line end-x-data)
  "Internal helper for multi-line region deletion (no additional undo save)"
  (let* ([start-line-metrics (list-ref (cbuf-text-metrics cbuf) start-line)]
         [end-line-metrics (list-ref (cbuf-text-metrics cbuf) end-line)]
         [start-line-text (text-metrics-string start-line-metrics)]
         [end-line-text (text-metrics-string end-line-metrics)]
         [start-line-sgr (text-metrics-sgr-list start-line-metrics)]
         [end-line-sgr (text-metrics-sgr-list end-line-metrics)]
         [start-base-indices (text-metrics-string-base-indices start-line-metrics)]
         [end-base-indices (text-metrics-string-base-indices end-line-metrics)])
    
    ;; Convert data positions to string indices
    (let* ([start-index (if (< start-x-data (length start-base-indices))
                           (list-ref start-base-indices start-x-data)
                           (string-length start-line-text))]
           [end-index (if (< end-x-data (length end-base-indices))
                         (list-ref end-base-indices end-x-data)
                         (string-length end-line-text))]
           
           ;; Extract the parts to keep
           [start-part-text (substring start-line-text 0 start-index)]
           [end-part-text (substring end-line-text end-index)]
           [start-part-sgr (take start-line-sgr start-index)]
           [end-part-sgr (drop end-line-sgr end-index)]
           
           ;; Create the joined line
           [joined-text (string-append start-part-text end-part-text)]
           [joined-sgr (append start-part-sgr end-part-sgr)]
           [joined-metrics (compute-text-metrics-with-sgr joined-text joined-sgr
                                                         (cbuf-tab-size cbuf)
                                                         #:cjk? (cbuf-cjk? cbuf))])
      
      ;; Update the start line with joined content
      (cbuf-set-y! cbuf start-line)
      (cbuf-update-metrics-cur! cbuf joined-metrics)
      
      ;; Remove the intermediate and end lines
      (when (> end-line start-line)
        (let* ([metrics-list (cbuf-text-metrics cbuf)]
               [new-metrics-list (append (take metrics-list (+ start-line 1))
                                        (drop metrics-list (+ end-line 1)))])
          (set-cbuf-text-metrics! cbuf new-metrics-list)))
      
      ;; Position cursor at start of deletion
      (cbuf-set-y! cbuf start-line)
      (cbuf-set-x! cbuf start-x-data 'data))))

;;; =================================================================
;;; MARK/SELECTION OPERATIONS
;;; =================================================================

(define (cbuf-set-mark! cbuf)
  "Set mark at current cursor position"
  (set-cbuf-mark-set?! cbuf #t)
  (set-cbuf-mark-line! cbuf (cbuf-line-cur cbuf))
  (set-cbuf-mark-x-data! cbuf (cbuf-x-data cbuf)))

(define (cbuf-clear-mark! cbuf)
  "Clear the mark, deactivating any selection."
  (set-cbuf-mark-set?! cbuf #f)
  (set-cbuf-mark-line! cbuf 0)
  (set-cbuf-mark-x-data! cbuf 0))

(define (cbuf-exchange-point-and-mark! cbuf)
  "Exchange cursor position with mark position"
  (when (cbuf-mark-set? cbuf)
    (let ([mark-line (cbuf-mark-line cbuf)]
          [mark-x-data (cbuf-mark-x-data cbuf)]
          [current-line (cbuf-line-cur cbuf)]
          [current-x-data (cbuf-x-data cbuf)])

      ;; Move cursor to mark
      (cbuf-set-y! cbuf mark-line)
      (cbuf-set-x! cbuf mark-x-data 'data)

      ;; Set mark to old cursor position
      (set-cbuf-mark-line! cbuf current-line)
      (set-cbuf-mark-x-data! cbuf current-x-data))))

(define (cbuf-cut-region! cbuf)
  "Cut the selected region to the kill buffer with undo support"
  (when (and (cbuf-mark-set? cbuf)
             (or (not (= (cbuf-mark-line cbuf) (cbuf-line-cur cbuf)))
                 (not (= (cbuf-mark-x-data cbuf) (cbuf-x-data cbuf)))))

    ;; Get the region text before deleting it
    (let ([region-text (cbuf-get-region-text cbuf)])
      ;; Store in cut buffer
      (set-cbuf-cut-buffer! cbuf (list region-text))

      ;; Delete the region
      (let ([mark-line (cbuf-mark-line cbuf)]
            [mark-x-data (cbuf-mark-x-data cbuf)]
            [cursor-line (cbuf-line-cur cbuf)]
            [cursor-x-data (cbuf-x-data cbuf)])

        ;; Normalize positions (start <= end)
        (let ([start-line (min mark-line cursor-line)]
              [start-x-data (if (= mark-line cursor-line)
                               (min mark-x-data cursor-x-data)
                               (if (< mark-line cursor-line) mark-x-data cursor-x-data))]
              [end-line (max mark-line cursor-line)]
              [end-x-data (if (= mark-line cursor-line)
                             (max mark-x-data cursor-x-data)
                             (if (> mark-line cursor-line) mark-x-data cursor-x-data))])

          ;; Position cursor at start of region
          (cbuf-set-y! cbuf start-line)
          (cbuf-set-x! cbuf start-x-data 'data)

          ;; Delete the region (this will save its own undo)
          (cbuf-delete-region! cbuf start-line start-x-data end-line end-x-data)))

      ;; Clear the mark
      (cbuf-clear-mark! cbuf))))

(define (cbuf-copy-region! cbuf)
  "Copy the selected region to the kill buffer (no undo needed)"
  (when (and (cbuf-mark-set? cbuf)
             (or (not (= (cbuf-mark-line cbuf) (cbuf-line-cur cbuf)))
                 (not (= (cbuf-mark-x-data cbuf) (cbuf-x-data cbuf)))))

    ;; Get the region text and store in cut buffer
    (let ([region-text (cbuf-get-region-text cbuf)])
      (set-cbuf-cut-buffer! cbuf (list region-text)))

    ;; Keep the mark active (don't clear it like cut does)
    ))

(define (cbuf-paste! cbuf)
  "Insert text from the kill buffer at the current cursor position with undo support"
  (let ([cut-buffer (cbuf-cut-buffer cbuf)])
    (when (and cut-buffer (not (null? cut-buffer)))
      (let ([text-to-paste (car cut-buffer)])
        (when (not (string-null? text-to-paste))
          ;; Clear mark if set (pasting typically deactivates selection)
          (when (cbuf-mark-set? cbuf)
            (cbuf-clear-mark! cbuf))

          ;; Insert the text (this will save its own undo)
          (cbuf-insert-string! cbuf text-to-paste))))))

(define (cbuf-get-region-text cbuf)
  "Get text between mark and cursor as a string"
  (if (cbuf-mark-set? cbuf)
      (let ([mark-line (cbuf-mark-line cbuf)]
            [mark-x-data (cbuf-mark-x-data cbuf)]
            [current-line (cbuf-line-cur cbuf)]
            [current-x-data (cbuf-x-data cbuf)])

        ;; Normalize positions (start <= end)
        (let ([start-line (min mark-line current-line)]
              [start-x-data (if (= mark-line current-line)
                               (min mark-x-data current-x-data)
                               (if (< mark-line current-line) mark-x-data current-x-data))]
              [end-line (max mark-line current-line)]
              [end-x-data (if (= mark-line current-line)
                             (max mark-x-data current-x-data)
                             (if (> mark-line current-line) mark-x-data current-x-data))])

          (cond
            ;; Single line selection
            [(= start-line end-line)
             (let* ([line-text (cbuf-get-line-text cbuf start-line)]
                    [metrics (list-ref (cbuf-text-metrics cbuf) start-line)]
                    [start-index (text-metrics-x-data->x-index metrics start-x-data)]
                    [end-index (text-metrics-x-data->x-index metrics end-x-data)])
               (substring line-text start-index end-index))]

            ;; Multi-line selection
            [else
             (let ([result-parts '()])

               ;; First line (from start position to end of line)
               (let* ([first-line-text (cbuf-get-line-text cbuf start-line)]
                      [first-metrics (list-ref (cbuf-text-metrics cbuf) start-line)]
                      [start-index (text-metrics-x-data->x-index first-metrics start-x-data)]
                      [first-part (substring first-line-text start-index)])
                 (set! result-parts (cons first-part result-parts)))

               ;; Middle lines (complete lines)
               (let loop ([line (+ start-line 1)])
                 (when (< line end-line)
                   (let ([line-text (cbuf-get-line-text cbuf line)])
                     (set! result-parts (cons line-text result-parts)))
                   (loop (+ line 1))))

               ;; Last line (from beginning to end position)
               (when (> end-line start-line)
                 (let* ([last-line-text (cbuf-get-line-text cbuf end-line)]
                        [last-metrics (list-ref (cbuf-text-metrics cbuf) end-line)]
                        [end-index (text-metrics-x-data->x-index last-metrics end-x-data)]
                        [last-part (substring last-line-text 0 end-index)])
                   (set! result-parts (cons last-part result-parts))))

               ;; Join with line ending
               (string-join (reverse result-parts) (cbuf-line-ending cbuf)))])))
      ""))

;;; =================================================================
;;; NEWLINE POLICY APPLICATION FUNCTIONS
;;; =================================================================

(define (cbuf-apply-final-newline-policy cbuf)
  "Apply the current final newline policy to determine what the save state should be"
  (case (cbuf-final-newline-policy cbuf)
    [(always-add) #t]
    [(never-add) #f]
    [(preserve) (cbuf-final-newline? cbuf)]
    [else (error "Invalid final newline policy" (cbuf-final-newline-policy cbuf))]))

(define (cbuf-should-have-final-newline? cbuf)
  "Determine if buffer should have final newline based on policy"
  (cbuf-apply-final-newline-policy cbuf))

(define (cbuf-normalize-final-newline! cbuf)
  "Adjust buffer final newline state to match policy"
  (let ([should-have? (cbuf-apply-final-newline-policy cbuf)]
        [currently-has? (cbuf-final-newline? cbuf)])

    (cond
      ;; Need to add final newline
      [(and should-have? (not currently-has?))
       (cbuf-end-of-buffer! cbuf)
       (cbuf-insert-newline! cbuf)]

      ;; Need to remove final newline (delete empty last line)
      [(and (not should-have?) currently-has?)
       (let ([last-line-index (- (cbuf-line-count cbuf) 1)])
         (when (and (> (cbuf-line-count cbuf) 1)
                   (string-null? (cbuf-get-line-text cbuf last-line-index)))
           (cbuf-set-y! cbuf last-line-index)
           (cbuf-delete-line! cbuf)
           (set-cbuf-final-newline?! cbuf #f)))])))

(define (cbuf-set-final-newline-policy! cbuf policy)
  "Set final newline policy and optionally apply it immediately"
  (unless (member policy '(always-add never-add preserve))
    (error "Invalid final newline policy" policy))

  (set-cbuf-final-newline-policy! cbuf policy)

  ;; Don't auto-apply on 'preserve policy changes
  (unless (eq? policy 'preserve)
    (cbuf-normalize-final-newline! cbuf)))

;;; =================================================================
;;; BUFFER OPERATIONS
;;; =================================================================

(define (cbuf-clear! cbuf)
  "Clear all content from buffer with undo support"
  ;; Save undo state
  (cbuf-save-undo! cbuf 'clear-buffer)

  ;; Reset to single empty line
  (let ([empty-metrics (compute-text-metrics "" (cbuf-tab-size cbuf) #:cjk? (cbuf-cjk? cbuf))])
    (set-cbuf-text-metrics! cbuf (list empty-metrics)))

  ;; Reset cursor position
  (cbuf-set-y! cbuf 0)
  (cbuf-set-x! cbuf 0 'data)

  ;; Clear mark
  (set-cbuf-mark-set?! cbuf #f)

  ;; Mark as modified
  (set-cbuf-modified?! cbuf #t))

(define (cbuf-load-from-string! cbuf str)
  "Load content from string, detecting final newline and applying policy"
  ;; Save undo state
  (cbuf-save-undo! cbuf 'clear-buffer)  ; Loading is like clearing + inserting

  ;; Detect line ending and final newline status
  (let* ([detected-ending (string-detect-line-ending str)]
         [split-result (string-split-lines-with-final-newline-info str)]
         [lines (car split-result)]
         [has-final-newline? (cdr split-result)])

    ;; Set line ending and detected final newline status
    (set-cbuf-line-ending! cbuf detected-ending)
    (set-cbuf-final-newline?! cbuf has-final-newline?)

    ;; Create metrics for each line
    (let ([metrics (map (lambda (line)
                          (compute-text-metrics line (cbuf-tab-size cbuf) #:cjk? (cbuf-cjk? cbuf)))
                        lines)])
      (set-cbuf-text-metrics! cbuf metrics))

    ;; Apply policy if not 'preserve
    (unless (eq? (cbuf-final-newline-policy cbuf) 'preserve)
      (cbuf-normalize-final-newline! cbuf))

    ;; Reset cursor to beginning
    (cbuf-beginning-of-buffer! cbuf)
    (set-cbuf-modified?! cbuf #f)))  ; Loading resets modified flag

(define (cbuf-save-to-string cbuf)
  "Save all buffer content to a string, applying final newline policy"
  (let* ([lines (cbuf-text cbuf)]
         [line-ending (cbuf-line-ending cbuf)]
         [should-end-with-newline? (cbuf-apply-final-newline-policy cbuf)])

    (cond
      ;; Single empty line - handle based on policy
      [(and (= (length lines) 1)
            (string-null? (car lines)))
       (if should-end-with-newline? line-ending "")]

      ;; Normal case: join lines and optionally add final newline
      [else
       (let ([joined (string-join lines line-ending)])
         (if should-end-with-newline?
             (string-append joined line-ending)
             joined))])))

;;; =================================================================
;;; WORD OPERATIONS
;;; =================================================================

(define (cbuf-handle-tab! cbuf)
  "Handle tab key press using cbuf-utils tab computation"
  (let* ([current-cell (cbuf-x-cell cbuf)]
         [tab-size (cbuf-tab-size cbuf)]
         [next-tab-cell (compute-tab-column current-cell tab-size 1)])

    ;; For now, just insert spaces to next tab stop
    (let ([spaces-needed (- next-tab-cell current-cell)])
      (cbuf-insert-string! cbuf (make-string spaces-needed #\space)))))

;;; =================================================================
;;; RENDERING HELPERS
;;; =================================================================

(define* (cbuf-render-line cbuf x-cell-start x-width #:key (pad? #t))
  "Render a portion of the current line"
  (text-metrics-render-line (cbuf-metrics-cur cbuf)
                            x-cell-start x-width #:pad? pad?))

(define* (cbuf-render-line-string-only cbuf x-cell-start x-width #:key (pad? #t))
  "Return only the rendered string"
  (let-values ([(rendered-string sgr-list bidi-state-list)
                (cbuf-render-line cbuf x-cell-start x-width #:pad? pad?)])
    rendered-string))

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
;;; MODULE INITIALIZATION
;;; =================================================================

;; Register built-in operations when module loads
(cbuf-register-built-in-undo-operations!)

