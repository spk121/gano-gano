;;; Gano Character Buffer Module - Complete Basic Operations
;;; Complete ECMA-48 terminal control implementation
;;;
;;; This file contains the minimum viable set of text editing operations

(define-module (gano cbuf-basic)
  #:use-module (gano cbuf-core)          ; Core record definitions
  #:use-module (gano cbuf-utils)         ; Pure utility functions
  #:use-module (gano text-metrics)       ; Immutable text metrics module
  #:use-module (gano rendering)          ; SGR support
  #:use-module (gano list-utils)         ; Immutable list operations
  #:use-module (gano char)               ; Character utilities
  #:use-module (gano string-split)       ; String splitting and joining
  #:use-module (gano string-utils)       ; String manipulation utilities
  #:use-module (srfi srfi-9)             ; Record types
  #:use-module (srfi srfi-1)             ; List utilities
  #:use-module (srfi srfi-11)            ; let-values
  #:use-module (srfi srfi-13)            ; String utilities
  #:use-module (srfi srfi-34)            ; Exception handling
  #:use-module (srfi srfi-35)            ; Condition types
  #:use-module (ice-9 format)            ; Format function
  #:use-module (ice-9 textual-ports)     ; get-string-all
  #:export (
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

    ;; Undo operations
    cbuf-undo
    cbuf-can-undo?

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

(define (cbuf-raise-boundary-error-with-info cbuf operation target actual boundary-type)
  "Raise boundary error using proper cbuf-utils error info constructor"
  (let* ([error-info (make-boundary-error-info operation target actual boundary-type)]
         [condition-constructor
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
                       (reason error-info))))))

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

;;; =================================================================
;;; UNDO SYSTEM
;;; =================================================================

(define (cbuf-save-undo-state! cbuf operation . args)
  "Save current state for undo using delta-based approach"
  (let ([undo-record `((position ,(cbuf-line-cur cbuf)
                                 ,(cbuf-x-data cbuf)
                                 ,(cbuf-x-cell cbuf)
                                 ,(cbuf-x-goal cbuf))
                       (mark ,(cbuf-mark-set? cbuf)
                             ,(cbuf-mark-line cbuf)
                             ,(cbuf-mark-x-data cbuf))
                       (sgr-state ,(sgr-copy (cbuf-current-sgr cbuf))
                                  ,(cbuf-default-grcm cbuf)
                                  ,(map sgr-copy (cbuf-sgr-stack cbuf)))
                       (operation ,operation ,@args))])
    (set-cbuf-undo-list! cbuf (cons undo-record (cbuf-undo-list cbuf)))))

(define (cbuf-save-line-modification-undo! cbuf line-num old-metrics operation . args)
  "Save undo state for line modification - stores the old metrics of the modified line"
  (let ([undo-record `((position ,(cbuf-line-cur cbuf)
                                 ,(cbuf-x-data cbuf)
                                 ,(cbuf-x-cell cbuf)
                                 ,(cbuf-x-goal cbuf))
                       (mark ,(cbuf-mark-set? cbuf)
                             ,(cbuf-mark-line cbuf)
                             ,(cbuf-mark-x-data cbuf))
                       (sgr-state ,(sgr-copy (cbuf-current-sgr cbuf))
                                  ,(cbuf-default-grcm cbuf)
                                  ,(map sgr-copy (cbuf-sgr-stack cbuf)))
                       (operation ,operation ,@args)
                       (modified-line ,line-num ,old-metrics))])
    (set-cbuf-undo-list! cbuf (cons undo-record (cbuf-undo-list cbuf)))))

(define (cbuf-save-line-insertion-undo! cbuf start-line num-lines operation . args)
  "Save undo state for line insertion"
  (let ([undo-record `((position ,(cbuf-line-cur cbuf)
                                 ,(cbuf-x-data cbuf)
                                 ,(cbuf-x-cell cbuf)
                                 ,(cbuf-x-goal cbuf))
                       (mark ,(cbuf-mark-set? cbuf)
                             ,(cbuf-mark-line cbuf)
                             ,(cbuf-mark-x-data cbuf))
                       (sgr-state ,(sgr-copy (cbuf-current-sgr cbuf))
                                  ,(cbuf-default-grcm cbuf)
                                  ,(map sgr-copy (cbuf-sgr-stack cbuf)))
                       (operation ,operation ,@args)
                       (inserted-lines ,start-line ,num-lines))])
    (set-cbuf-undo-list! cbuf (cons undo-record (cbuf-undo-list cbuf)))))

(define (cbuf-save-line-deletion-undo! cbuf start-line deleted-metrics operation . args)
  "Save undo state for line deletion"
  (let ([undo-record `((position ,(cbuf-line-cur cbuf)
                                 ,(cbuf-x-data cbuf)
                                 ,(cbuf-x-cell cbuf)
                                 ,(cbuf-x-goal cbuf))
                       (mark ,(cbuf-mark-set? cbuf)
                             ,(cbuf-mark-line cbuf)
                             ,(cbuf-mark-x-data cbuf))
                       (sgr-state ,(sgr-copy (cbuf-current-sgr cbuf))
                                  ,(cbuf-default-grcm cbuf)
                                  ,(map sgr-copy (cbuf-sgr-stack cbuf)))
                       (operation ,operation ,@args)
                       (deleted-lines ,start-line ,deleted-metrics))])
    (set-cbuf-undo-list! cbuf (cons undo-record (cbuf-undo-list cbuf)))))

(define (cbuf-save-newline-insertion-undo! cbuf original-line original-text original-sgr-list split-x-index operation . args)
  "Save undo state for newline insertion - captures the complete operation atomically"
  (let ([undo-record `((position ,(cbuf-line-cur cbuf) 
                                 ,(cbuf-x-data cbuf) 
                                 ,(cbuf-x-cell cbuf) 
                                 ,(cbuf-x-goal cbuf))
                       (mark ,(cbuf-mark-set? cbuf)
                             ,(cbuf-mark-line cbuf)
                             ,(cbuf-mark-x-data cbuf))
                       (sgr-state ,(sgr-copy (cbuf-current-sgr cbuf))
                                  ,(cbuf-default-grcm cbuf)
                                  ,(map sgr-copy (cbuf-sgr-stack cbuf)))
                       (operation ,operation ,@args)
                       (newline-insertion ,(cbuf-line-cur cbuf)    ; line where newline was inserted
                                         ,original-text           ; original complete line text
                                         ,original-sgr-list      ; original complete SGR list
                                         ,split-x-index))])      ; where the split occurred
    (set-cbuf-undo-list! cbuf (cons undo-record (cbuf-undo-list cbuf)))))

(define (cbuf-save-multiline-deletion-undo! cbuf start-line end-line start-line-metrics end-line-metrics deleted-lines operation . args)
  "Save undo state for multi-line deletion - captures all affected lines"
  (let ([undo-record `((position ,(cbuf-line-cur cbuf) 
                                 ,(cbuf-x-data cbuf) 
                                 ,(cbuf-x-cell cbuf) 
                                 ,(cbuf-x-goal cbuf))
                       (mark ,(cbuf-mark-set? cbuf)
                             ,(cbuf-mark-line cbuf)
                             ,(cbuf-mark-x-data cbuf))
                       (sgr-state ,(sgr-copy (cbuf-current-sgr cbuf))
                                  ,(cbuf-default-grcm cbuf)
                                  ,(map sgr-copy (cbuf-sgr-stack cbuf)))
                       (operation ,operation ,@args)
                       (multiline-deletion ,start-line ,end-line 
                                          ,start-line-metrics 
                                          ,end-line-metrics 
                                          ,deleted-lines))])
    (set-cbuf-undo-list! cbuf (cons undo-record (cbuf-undo-list cbuf)))))

(define (cbuf-can-undo? cbuf)
  "Return #t if there are operations that can be undone"
  (not (null? (cbuf-undo-list cbuf))))

(define (cbuf-undo cbuf)
  "Undo the last operation using delta-based restoration.
   Now includes support for dedicated newline insertion undo."
  (when (cbuf-can-undo? cbuf)
    (let* ([undo-record (car (cbuf-undo-list cbuf))]
           [position (assq 'position undo-record)]
           [mark (assq 'mark undo-record)]
           [sgr-state (assq 'sgr-state undo-record)]
           [modified-line (assq 'modified-line undo-record)]
           [inserted-lines (assq 'inserted-lines undo-record)]
           [deleted-lines (assq 'deleted-lines undo-record)]
           [newline-insertion (assq 'newline-insertion undo-record)]
           [multiline-deletion (assq 'newline-insertion undo-record)]
	   )
      
      ;; Undo text changes based on operation type
      (cond
       [newline-insertion
        ;; Handle newline insertion undo - restore original single line
        (let ([line-num (cadr newline-insertion)]
              [original-text (caddr newline-insertion)]
              [original-sgr-list (cadddr newline-insertion)]
              [split-index (cadddr (cdr newline-insertion))])
          
          ;; Recreate the original line metrics
          (let ([original-metrics (compute-text-metrics-with-sgr original-text original-sgr-list
                                                                 (cbuf-tab-size cbuf)
                                                                 #:cjk? (cbuf-cjk? cbuf))])
            ;; Replace the split lines with the original single line
            (let* ([metrics-list (cbuf-text-metrics cbuf)]
                   ;; Remove the inserted line first, then replace the modified line
                   [after-line-removal (list-delete-range metrics-list (+ line-num 1) (+ line-num 2))]
                   [restored-metrics-list (list-update after-line-removal line-num original-metrics)])
              (set-cbuf-text-metrics! cbuf restored-metrics-list))))]
       
       [multiline-deletion
	;; Handle multi-line deletion undo - restore all original lines
	(let ([start-line (cadr multiline-deletion)]
	      [end-line (caddr multiline-deletion)]
	      [original-start-metrics (cadddr multiline-deletion)]
	      [original-end-metrics (cadddr (cdr multiline-deletion))]
	      [deleted-middle-lines (cadddr (cddr multiline-deletion))])
	  
	  ;; Restore the original lines
	  (let* ([metrics-list (cbuf-text-metrics cbuf)]
		 ;; Replace the joined line with original start line
		 [after-start-restore (list-update metrics-list start-line original-start-metrics)]
		 ;; Insert the deleted middle lines
		 [after-middle-restore (append (take after-start-restore (+ start-line 1))
					       deleted-middle-lines
					       (drop after-start-restore (+ start-line 1)))]
		 ;; Insert the original end line
		 [final-restored (list-insert after-middle-restore end-line original-end-metrics)])
	    (set-cbuf-text-metrics! cbuf final-restored)))]
       
       [modified-line
        (let ([line-num (cadr modified-line)]
              [old-metrics (caddr modified-line)])
          (let ([new-metrics-list (list-update (cbuf-text-metrics cbuf) line-num old-metrics)])
            (set-cbuf-text-metrics! cbuf new-metrics-list)))]
       
       [inserted-lines
        (let ([start-line (cadr inserted-lines)]
              [num-lines (caddr inserted-lines)])
          (let* ([metrics-list (cbuf-text-metrics cbuf)]
                 [new-metrics-list (append (take metrics-list start-line)
                                           (drop metrics-list (+ start-line num-lines)))])
            (set-cbuf-text-metrics! cbuf new-metrics-list)))]
       
       [deleted-lines
        (let ([start-line (cadr deleted-lines)]
              [deleted-metrics (caddr deleted-lines)])
          (let* ([metrics-list (cbuf-text-metrics cbuf)]
                 [new-metrics-list (append (take metrics-list start-line)
                                           deleted-metrics
                                           (drop metrics-list start-line))])
            (set-cbuf-text-metrics! cbuf new-metrics-list)))])
      
      ;; Restore SGR state
      (when sgr-state
        (let ([saved-current-sgr (cadr sgr-state)]
              [saved-grcm (caddr sgr-state)]
              [saved-stack (cadddr sgr-state)])
          (set-cbuf-current-sgr! cbuf (sgr-copy saved-current-sgr))
          (set-cbuf-default-grcm! cbuf saved-grcm)
          (set-cbuf-sgr-stack! cbuf (map sgr-copy saved-stack))))
      
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
      
      ;; Remove this undo record and mark as modified
      (set-cbuf-undo-list! cbuf (cdr (cbuf-undo-list cbuf)))
      (set-cbuf-modified?! cbuf #t))))


;;; =================================================================
;;; HELPER FUNCTIONS FOR POSITION MANAGEMENT
;;; =================================================================

(define (cbuf-update-line! cbuf line-num new-text new-sgr-list)
  "Update the text and SGR list for a specific line"
  (unless (= (string-length new-text) (length new-sgr-list))
    (error "Text length and SGR list length must match"))

  ;; Save undo state
  (let ([old-metrics (list-ref (cbuf-text-metrics cbuf) line-num)])
    (cbuf-save-line-modification-undo! cbuf line-num old-metrics 'update-line line-num new-text))

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
  ;; DON'T save undo here - cbuf-update-line! will do it

(define (cbuf-insert-char! cbuf char-new)
  "Insert a character at the current position with proper validation"
  (let* ([x-data (cbuf-x-data cbuf)]
         [text (cbuf-text-cur cbuf)]
         [sgr-list (cbuf-sgr-list-cur cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)])

    ;; Use cbuf-utils validation for combining marks
    (cbuf-validate-combining-mark-insertion cbuf char-new x-data)

    ;; DON'T save undo here - cbuf-update-line! will do it

    ;; Insert character and SGR
    (let* ([new-text (string-insert-char text x-index char-new)]
           [current-sgr (cbuf-current-sgr cbuf)]
           [new-sgr-list (list-insert sgr-list x-index current-sgr)])

      ;; Update the line
      (cbuf-set-text-cur! cbuf new-text new-sgr-list)

      ;; Move cursor forward
      (cbuf-set-x! cbuf (+ x-data 1) 'data)

      ;; Mark as modified
      (set-cbuf-modified?! cbuf #t))))

(define (cbuf-delete-char! cbuf)
  "Delete the complete grapheme cluster at current position (Delete key behavior)"
  (unless (cbuf-end-of-line? cbuf)
    (let* ([x-data (cbuf-x-data cbuf)]
           [text (cbuf-text-cur cbuf)]
           [sgr-list (cbuf-sgr-list-cur cbuf)]
           [cluster-bounds (cbuf-find-grapheme-cluster-bounds cbuf x-data)]
           [start-index (car cluster-bounds)]
           [end-index (cadr cluster-bounds)])

      ;; Only proceed if we have a valid cluster to delete
      (when (< start-index end-index)
        ;; DON'T save undo here - cbuf-update-line! will do it

        ;; Delete the entire grapheme cluster
        (let* ([new-text (string-delete-range text start-index end-index)]
               [new-sgr-list (list-delete-range sgr-list start-index end-index)])

          ;; Update the line
          (cbuf-set-text-cur! cbuf new-text new-sgr-list)

          ;; Cursor stays at same data position (now points to next character)
          (cbuf-set-x! cbuf x-data 'data)

          ;; Mark as modified
          (set-cbuf-modified?! cbuf #t))))))

(define (cbuf-backspace! cbuf)
  "Delete the complete grapheme cluster before current position (Backspace key behavior)"
  (unless (cbuf-beginning-of-line? cbuf)
    (let* ([x-data (cbuf-x-data cbuf)]
           [prev-x-data (- x-data 1)]
           [text (cbuf-text-cur cbuf)]
           [sgr-list (cbuf-sgr-list-cur cbuf)]
           [cluster-bounds (cbuf-find-grapheme-cluster-bounds cbuf prev-x-data)]
           [start-index (car cluster-bounds)]
           [end-index (cadr cluster-bounds)])

      ;; Only proceed if we have a valid cluster to delete
      (when (< start-index end-index)
        ;; DON'T save undo here - cbuf-update-line! will do it

        ;; Delete the entire grapheme cluster
        (let* ([new-text (string-delete-range text start-index end-index)]
               [new-sgr-list (list-delete-range sgr-list start-index end-index)])

          ;; Update the line
          (cbuf-set-text-cur! cbuf new-text new-sgr-list)

          ;; Move cursor to where the deleted cluster was
          (cbuf-set-x! cbuf prev-x-data 'data)

          ;; Mark as modified
          (set-cbuf-modified?! cbuf #t))))))

;;; =================================================================
;;; LINE OPERATIONS
;;; =================================================================

(define (cbuf-insert-newline! cbuf)
  "Insert a newline at current position, updating final newline status.
   Uses dedicated undo system for atomic operation."
  (let* ([x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)]
         [current-line (cbuf-line-cur cbuf)]
         [text (cbuf-text-cur cbuf)]
         [sgr-list (cbuf-sgr-list-cur cbuf)]
         [at-end-of-buffer? (and (= current-line (- (cbuf-line-count cbuf) 1))
                                (= x-data (cbuf-text-cur-base-length cbuf)))])
    
    ;; Save undo state BEFORE any modifications - capture the original complete line
    (cbuf-save-newline-insertion-undo! cbuf current-line text sgr-list x-index 'insert-newline)
    
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
      
      ;; Perform the modifications without additional undo saves
      ;; Update current line with left part (direct metrics list manipulation)
      (let* ([metrics-list (cbuf-text-metrics cbuf)]
             [new-metrics-list (list-update metrics-list current-line left-metrics)])
        (set-cbuf-text-metrics! cbuf new-metrics-list))
      
      ;; Insert new line with right part (direct metrics list manipulation)
      (let* ([metrics-list (cbuf-text-metrics cbuf)]
             [new-metrics-list (list-insert metrics-list (+ current-line 1) right-metrics)])
        (set-cbuf-text-metrics! cbuf new-metrics-list))
      
      ;; Update final newline status
      (cond
        ;; If we were at end of buffer, we now have content after final newline
        [at-end-of-buffer?
         (set-cbuf-final-newline?! cbuf #t)]
        
        ;; If we're inserting in middle, final newline status depends on whether
        ;; we're creating a new final line or not
        [(= (cbuf-line-cur cbuf) (- (cbuf-line-count cbuf) 2))  ; Near end
         ;; Check if the new line we just created is now the last line
         (when (string-null? right-text)
           (set-cbuf-final-newline?! cbuf #t))])
      
      ;; Move cursor to beginning of new line
      (cbuf-set-y! cbuf (+ current-line 1))
      (cbuf-set-x! cbuf 0 'data)
      
      ;; Mark as modified
      (set-cbuf-modified?! cbuf #t))))

(define (cbuf-delete-line! cbuf)
  "Delete the current line, updating final newline status appropriately"
  (when (> (cbuf-line-count cbuf) 1)  ; Don't delete if it's the only line
    (let ([current-line (cbuf-line-cur cbuf)]
          [deleted-metrics (cbuf-metrics-cur cbuf)]
          [is-last-line? (= (cbuf-line-cur cbuf) (- (cbuf-line-count cbuf) 1))]
          [is-empty-last-line? (and (= (cbuf-line-cur cbuf) (- (cbuf-line-count cbuf) 1))
                                   (string-null? (cbuf-text-cur cbuf)))])

      ;; Save undo state
      (cbuf-save-line-deletion-undo! cbuf current-line (list deleted-metrics) 'delete-line)

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
  "Join current line with next line"
  (let ([current-line (cbuf-line-cur cbuf)])
    (when (< current-line (- (cbuf-line-count cbuf) 1))  ; Not on last line
      (let* ([current-text (cbuf-text-cur cbuf)]
             [current-sgr (cbuf-sgr-list-cur cbuf)]
             [next-text (cbuf-get-line-text cbuf (+ current-line 1))]
             [next-sgr (text-metrics-sgr-list (list-ref (cbuf-text-metrics cbuf) (+ current-line 1)))]
             [joined-text (string-append current-text next-text)]
             [joined-sgr (append current-sgr next-sgr)])

        ;; Save undo state for both line modification and deletion
        (cbuf-save-line-deletion-undo! cbuf (+ current-line 1)
                                       (list (list-ref (cbuf-text-metrics cbuf) (+ current-line 1)))
                                       'join-lines)

        ;; Update current line with joined content
        (cbuf-set-text-cur! cbuf joined-text joined-sgr)

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
  "Insert a string at the current position with proper validation"
  ;; Validate the string first
  (cbuf-validate-string-insertion cbuf str (cbuf-x-data cbuf))

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

        ;; Save undo state
        (let ([old-metrics (cbuf-metrics-cur cbuf)])
          ;; DON'T save undo here - cbuf-update-line! will do it

          ;; Insert the string
          (let* ([new-text (string-insert-string text x-index insert-text)]
                 [new-sgr-list (append (take sgr-list x-index)
                                       insert-sgr-list
                                       (drop sgr-list x-index))])

            ;; Update the line
            (cbuf-set-text-cur! cbuf new-text new-sgr-list)

            ;; Move cursor to end of inserted text using cbuf-utils
            (cbuf-set-x! cbuf (+ x-data (count-base-characters insert-text)) 'data)

            ;; Mark as modified
            (set-cbuf-modified?! cbuf #t))))]

     ;; Multi-line insertion
     [else
      (let ([first-line (car lines)]
            [middle-lines (if (> (length lines) 2)
                              (drop (drop-right lines 1) 1)
                              '())]
            [last-line (if (> (length lines) 1) (last lines) "")])

        ;; Insert first line
        (cbuf-insert-string! cbuf first-line)

        ;; Insert newline and each middle line
        (for-each (lambda (line)
                    (cbuf-insert-newline! cbuf)
                    (cbuf-insert-string! cbuf line))
                  middle-lines)

        ;; Insert final newline and last line (if multi-line)
        (when (> (length lines) 1)
          (cbuf-insert-newline! cbuf)
          (cbuf-insert-string! cbuf last-line)))])))

(define (cbuf-delete-region! cbuf start-line start-x-data end-line end-x-data)
  "Delete text from start position to end position (handles both single and multi-line)."
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
           ;; Save undo state
           (let ([old-metrics line-metrics])
             (cbuf-save-line-modification-undo! cbuf start-line old-metrics 'delete-region))
           
           ;; Delete the range
           (let* ([new-text (string-delete-range line-text start-index end-index)]
                  [new-sgr-list (list-delete-range line-sgr start-index end-index)])
             
             ;; Update the line
             (cbuf-update-line! cbuf start-line new-text new-sgr-list)
             
             ;; Position cursor at start of deletion
             (cbuf-set-y! cbuf start-line)
             (cbuf-set-x! cbuf start-x-data 'data)))))]
    
    ;; Multi-line deletion
    [else
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
              
              ;; Calculate how many lines will be deleted
              [lines-to-delete (- end-line start-line)]
              [deleted-lines (take (drop (cbuf-text-metrics cbuf) (+ start-line 1)) 
                                  (- end-line start-line))])
         
         ;; Save undo state for multi-line deletion
         (cbuf-save-multiline-deletion-undo! cbuf start-line end-line 
                                            start-line-metrics end-line-metrics 
                                            deleted-lines 'delete-region)
         
         ;; Update the start line with joined content
         (cbuf-update-line! cbuf start-line joined-text joined-sgr)
         
         ;; Remove the intermediate and end lines
         (when (> lines-to-delete 0)
           (let* ([metrics-list (cbuf-text-metrics cbuf)]
                  [new-metrics-list (append (take metrics-list (+ start-line 1))
                                           (drop metrics-list (+ end-line 1)))])
             (set-cbuf-text-metrics! cbuf new-metrics-list)))
         
         ;; Position cursor at start of deletion
         (cbuf-set-y! cbuf start-line)
         (cbuf-set-x! cbuf start-x-data 'data)))]))

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
  "Cut the selected region to the kill buffer.
   Deletes the region and stores it for pasting.
   If no region is selected, does nothing."
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

          ;; Delete the region
          (cbuf-delete-region! cbuf start-line start-x-data end-line end-x-data)))

      ;; Clear the mark
      (cbuf-clear-mark! cbuf))))

(define (cbuf-copy-region! cbuf)
  "Copy the selected region to the kill buffer.
   Does not delete the region.
   If no region is selected, does nothing."
  (when (and (cbuf-mark-set? cbuf)
             (or (not (= (cbuf-mark-line cbuf) (cbuf-line-cur cbuf)))
                 (not (= (cbuf-mark-x-data cbuf) (cbuf-x-data cbuf)))))

    ;; Get the region text and store in cut buffer
    (let ([region-text (cbuf-get-region-text cbuf)])
      (set-cbuf-cut-buffer! cbuf (list region-text)))

    ;; Keep the mark active (don't clear it like cut does)
    ))

(define (cbuf-paste! cbuf)
  "Insert text from the kill buffer at the current cursor position.
   If kill buffer is empty, does nothing."
  (let ([cut-buffer (cbuf-cut-buffer cbuf)])
    (when (and cut-buffer (not (null? cut-buffer)))
      (let ([text-to-paste (car cut-buffer)])
        (when (not (string-null? text-to-paste))
          ;; Clear mark if set (pasting typically deactivates selection)
          (when (cbuf-mark-set? cbuf)
            (cbuf-clear-mark! cbuf))

          ;; Insert the text
          (cbuf-insert-string! cbuf text-to-paste))))))

(define (cbuf-get-region-text cbuf)
  "Get text between mark and cursor as a string.
   Handles both single-line and multi-line selections properly."
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

(define (cbuf-get-final-newline-info cbuf)
  "Return comprehensive information about final newline status"
  (let* ([lines (cbuf-text cbuf)]
         [last-line (if (null? lines) "" (last lines))]
         [line-count (cbuf-line-count cbuf)])
    `((current-state . ,(cbuf-final-newline? cbuf))
      (policy . ,(cbuf-final-newline-policy cbuf))
      (should-have-per-policy . ,(cbuf-apply-final-newline-policy cbuf))
      (line-ending . ,(cbuf-line-ending cbuf))
      (line-count . ,line-count)
      (last-line-empty? . ,(string-null? last-line))
      (needs-normalization? . ,(not (eq? (cbuf-final-newline? cbuf)
                                         (cbuf-apply-final-newline-policy cbuf)))))))

(define (cbuf-toggle-final-newline! cbuf)
  "Toggle final newline state (sets policy to 'preserve)"
  (set-cbuf-final-newline-policy! cbuf 'preserve)
  (if (cbuf-final-newline? cbuf)
      (begin
        ;; Remove final newline by deleting empty last line if exists
        (let ([last-line-index (- (cbuf-line-count cbuf) 1)])
          (when (and (> (cbuf-line-count cbuf) 1)
                    (string-null? (cbuf-get-line-text cbuf last-line-index)))
            (cbuf-set-y! cbuf last-line-index)
            (cbuf-delete-line! cbuf)))
        (set-cbuf-final-newline?! cbuf #f))
      (begin
        ;; Add final newline
        (cbuf-end-of-buffer! cbuf)
        (cbuf-insert-newline! cbuf))))

;;; =================================================================
;;; BUFFER OPERATIONS
;;; =================================================================

(define (cbuf-clear! cbuf)
  "Clear all content from buffer"
  ;; Save undo state
  (cbuf-save-undo-state! cbuf 'clear)

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
  (cbuf-save-undo-state! cbuf 'load-from-string)

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
  "Handle tab key press using cbuf-utils tab computation (future implementation)"
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
  (let-values ([(rendered-string sgr-list)
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
