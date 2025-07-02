;;; Gano Character Buffer Module - Extra/Advanced Operations  
;;; Complete ECMA-48 terminal control implementation
;;;
;;; This file contains advanced text editing operations beyond standard

(define-module (gano cbuf-extra)
  #:use-module (gano cbuf-core)          ; Core record definitions
  #:use-module (gano cbuf-basic)         ; Basic operations
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
    ;; Precise word navigation
    cbuf-beginning-of-word!
    cbuf-end-of-word!
    
    ;; Precise column positioning
    cbuf-move-to-column!
    
    ;; Paragraph navigation
    cbuf-forward-paragraph!
    cbuf-backward-paragraph!
    
    ;; Sentence navigation
    cbuf-forward-sentence!
    cbuf-backward-sentence!
    
    ;; Line formatting
    cbuf-center-line!
    
    ;; Smart selection
    cbuf-select-paragraph!
    cbuf-select-word!
    cbuf-select-sentence!
    
    ;; Case conversion
    cbuf-upcase-region!
    cbuf-downcase-region!
    cbuf-titlecase-region!
    
    ;; Tab conversion
    cbuf-tabify-buffer!
    cbuf-untabify-buffer!
    cbuf-tabify-lines-in-selected-region!
    cbuf-untabify-lines-in-selected-region!
    
    ;; Swapping operations
    cbuf-swap-current-and-previous-line!
    cbuf-swap-current-and-following-line!
    cbuf-swap-current-and-previous-grapheme!
    cbuf-swap-current-and-following-grapheme!
    
    ;; Sorting operations
    cbuf-sort-lines-in-region!
    
    ;; Indentation alignment
    cbuf-align-indents-in-region!
    ;; Undo registration
    cbuf-register-extra-undo-operations!
    ))

;;; =================================================================
;;; UNDO OPERATION HANDLERS FOR EXTRA OPERATIONS
;;; =================================================================
;; Line formatting handlers
(define (capture-line-formatting-state cbuf operation-type)
  "Capture state for line formatting operations"
  `((line-num ,(cbuf-line-cur cbuf))
    (old-metrics ,(cbuf-metrics-cur cbuf))
    (operation-type ,operation-type)))
(define (restore-line-formatting-state cbuf state operation-type)
  "Restore state after line formatting"
  (let ([line-num (cadr (assq 'line-num state))]
        [old-metrics (cadr (assq 'old-metrics state))])
    (cbuf-restore-line-metrics! cbuf line-num old-metrics)))
;; Buffer-wide transformation handlers
(define (capture-buffer-transformation-state cbuf operation-type)
  "Capture state for operations that transform the entire buffer"
  `((all-metrics ,(cbuf-text-metrics cbuf))
    (operation-type ,operation-type)))
(define (restore-buffer-transformation-state cbuf state operation-type)
  "Restore state after buffer transformation"
  (let ([all-metrics (cadr (assq 'all-metrics state))])
    (set-cbuf-text-metrics! cbuf all-metrics)))
;; Region transformation handlers
(define (capture-region-transformation-state cbuf start-line end-line operation-type)
  "Capture state for operations that transform a region"
  (let ([affected-lines (let loop ([line start-line] [result '()])
                          (if (> line end-line)
                              (reverse result)
                              (loop (+ line 1)
                                    (cons (cons line (list-ref (cbuf-text-metrics cbuf) line))
                                          result))))])
    `((affected-lines ,affected-lines)
      (start-line ,start-line)
      (end-line ,end-line)
      (operation-type ,operation-type))))
(define (restore-region-transformation-state cbuf state start-line end-line operation-type)
  "Restore state after region transformation"
  (let ([affected-lines (cadr (assq 'affected-lines state))])
    (for-each (lambda (line-data)
                (let ([line-num (car line-data)]
                      [old-metrics (cdr line-data)])
                  (when (< line-num (cbuf-line-count cbuf))
                    (cbuf-restore-line-metrics! cbuf line-num old-metrics))))
              affected-lines)))
;; Line swapping handlers
(define (capture-line-swapping-state cbuf line1 line2 operation-type)
  "Capture state for line swapping operations"
  `((line1 ,line1)
    (line1-metrics ,(list-ref (cbuf-text-metrics cbuf) line1))
    (line2 ,line2)
    (line2-metrics ,(list-ref (cbuf-text-metrics cbuf) line2))
    (operation-type ,operation-type)))
(define (restore-line-swapping-state cbuf state line1 line2 operation-type)
  "Restore state after line swapping"
  (let ([original-line1 (cadr (assq 'line1 state))]
        [line1-metrics (cadr (assq 'line1-metrics state))]
        [original-line2 (cadr (assq 'line2 state))]
        [line2-metrics (cadr (assq 'line2-metrics state))])
    ;; Restore both lines to their original state
    (cbuf-restore-line-metrics! cbuf original-line1 line1-metrics)
    (cbuf-restore-line-metrics! cbuf original-line2 line2-metrics)))
;; Grapheme swapping handlers
(define (capture-grapheme-swapping-state cbuf operation-type)
  "Capture state for grapheme swapping operations"
  `((line-num ,(cbuf-line-cur cbuf))
    (old-metrics ,(cbuf-metrics-cur cbuf))
    (operation-type ,operation-type)))
(define (restore-grapheme-swapping-state cbuf state operation-type)
  "Restore state after grapheme swapping"
  (let ([line-num (cadr (assq 'line-num state))]
        [old-metrics (cadr (assq 'old-metrics state))])
    (cbuf-restore-line-metrics! cbuf line-num old-metrics)))
;; Sorting handlers
(define (capture-sorting-state cbuf start-line end-line operation-type)
  "Capture state for sorting operations"
  (let ([lines-to-sort (let loop ([line start-line] [result '()])
                         (if (> line end-line)
                             (reverse result)
                             (loop (+ line 1)
                                   (cons (list-ref (cbuf-text-metrics cbuf) line) result))))])
    `((start-line ,start-line)
      (end-line ,end-line)
      (original-lines ,lines-to-sort)
      (operation-type ,operation-type))))
(define (restore-sorting-state cbuf state start-line end-line operation-type)
  "Restore state after sorting"
  (let ([original-start (cadr (assq 'start-line state))]
        [original-end (cadr (assq 'end-line state))]
        [original-lines (cadr (assq 'original-lines state))])
    ;; Replace the sorted region with the original lines
    (cbuf-replace-line-range! cbuf original-start original-end original-lines)))
;;; =================================================================
;;; HELPER FUNCTIONS
;;; =================================================================
(define (cbuf-set-text-cur! cbuf new-text new-sgr-list)
  "Replace current line text and SGR, computing new metrics"
  (let* ([new-metrics (compute-text-metrics-with-sgr new-text new-sgr-list
                                                     (cbuf-tab-size cbuf)
                                                     #:cjk? (cbuf-cjk? cbuf))])
    (cbuf-restore-line-metrics! cbuf (cbuf-line-cur cbuf) new-metrics)
    (set-cbuf-modified?! cbuf #t)))
(define (cbuf-save-line-modification-undo! cbuf line-num old-metrics operation-type)
  "Save undo state for single line modification (helper function)"
  (cbuf-save-undo! cbuf operation-type line-num old-metrics))
(define (cbuf-save-line-deletion-undo! cbuf start-line deleted-lines operation-type)
  "Save undo state for line deletion operations (helper function)"
  (cbuf-save-undo! cbuf operation-type start-line deleted-lines))
(define (string-from-chars char-list)
  "Convert list of characters to string"
  (list->string char-list))

(define (cbuf-find-word-boundary-backward cbuf)
  "Find the beginning of the current word, handling grapheme clusters properly.
   Returns the x-data position of the word start (base character)."
  (let* ([text (cbuf-text-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [current-index (cbuf-x-data->x-index cbuf current-x)]
         [text-len (string-length text)])
    
    (cond
     ;; Empty line or at beginning
     [(or (string-null? text) (= current-index 0)) 0]
     
     ;; Find word boundary
     [else
      (let* ([start-search-index (max 0 (- current-index 1))]
             [word-start-index (find-word-begin-backward text start-search-index char-word-delimiter?)]
             ;; Ensure we're at a base character, not a combining mark
             [adjusted-index (cbuf-ensure-base-character-index text word-start-index)])
        (cbuf-x-index->x-data cbuf adjusted-index))])))

(define (cbuf-find-word-boundary-forward cbuf)
  "Find the end of the current word, handling grapheme clusters properly.
   Returns the x-data position after the word end (base character)."
  (let* ([text (cbuf-text-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [current-index (cbuf-x-data->x-index cbuf current-x)]
         [text-len (string-length text)])
    
    (cond
     ;; Empty line or at end
     [(or (string-null? text) (>= current-index text-len)) 
      (cbuf-text-cur-base-length cbuf)]
     
     ;; Find word boundary
     [else
      (let* ([word-end-index (find-word-end-forward text current-index char-word-delimiter?)]
             ;; Ensure we're at a base character, not a combining mark
             [adjusted-index (cbuf-ensure-base-character-index text word-end-index)])
        (cbuf-x-index->x-data cbuf adjusted-index))])))

(define (cbuf-ensure-base-character-index text index)
  "Ensure index points to a base character, not a combining mark.
   If index points to a combining mark, find the preceding base character."
  (let ([text-len (string-length text)])
    (cond
     ;; Beyond string bounds
     [(>= index text-len) text-len]
     [(<= index 0) 0]
     
     ;; Check if current position is a combining mark
     [(char-combining-mark? (string-ref text index))
      ;; Walk backward to find the base character
      (let loop ([i (- index 1)])
        (cond
         [(< i 0) 0]  ; Shouldn't happen with valid text, but be safe
         [(not (char-combining-mark? (string-ref text i))) i]
         [else (loop (- i 1))]))]
     
     ;; Already at base character or beyond text
     [else index])))

(define (cbuf-at-word-boundary? cbuf boundary-type)
  "Check if cursor is at a word boundary.
   BOUNDARY-TYPE: 'beginning or 'end"
  (let* ([text (cbuf-text-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [current-index (cbuf-x-data->x-index cbuf current-x)]
         [text-len (string-length text)])
    
    (cond
     ;; Empty line
     [(string-null? text) #t]
     
     ;; At beginning of line
     [(= current-index 0) 
      (eq? boundary-type 'beginning)]
     
     ;; At end of line
     [(>= current-index text-len)
      (eq? boundary-type 'end)]
     
     ;; Check boundary conditions
     [else
      (let ([current-char (string-ref text current-index)]
            [prev-char (if (> current-index 0) 
                          (string-ref text (- current-index 1)) 
                          #\space)]  ; Treat beginning as whitespace
            [next-char (if (< current-index (- text-len 1))
                          (string-ref text (+ current-index 1))
                          #\space)]) ; Treat end as whitespace
        
        (case boundary-type
          [(beginning)
           ;; At word beginning if current is word char and previous is delimiter
           (and (not (char-word-delimiter? current-char))
                (char-word-delimiter? prev-char))]
          
          [(end)
           ;; At word end if current is delimiter and previous is word char
           (and (char-word-delimiter? current-char)
                (not (char-word-delimiter? prev-char)))]
          
          [else #f]))])))

;;; =================================================================
;;; INDENTATION ALIGNMENT (Needs undo support)
;;; =================================================================

(define (cbuf-align-indents-in-region! cbuf)
  "Align indentation of all lines in selected region to match the first line with undo support.
   All lines will have the same initial indentation whitespace as the first line.
   Operates on complete lines regardless of selection boundaries."
  (when (cbuf-mark-set? cbuf)
    (let* ([mark-line (cbuf-mark-line cbuf)]
           [cursor-line (cbuf-line-cur cbuf)]
           [start-line (min mark-line cursor-line)]
           [end-line (max mark-line cursor-line)]
           [original-cursor-line (cbuf-line-cur cbuf)]
           [original-cursor-x (cbuf-x-data cbuf)])
      
      ;; Only proceed if we have multiple lines to align
      (when (< start-line end-line)
        ;; Save undo state for the entire alignment operation
        (cbuf-save-undo! cbuf 'align-indents start-line end-line)
        
        ;; Get the reference indentation from the first line
        (let* ([reference-line-text (cbuf-get-line-text cbuf start-line)]
               [reference-indentation (cbuf-extract-line-indentation reference-line-text)])
          
          ;; Process each line in the region (skip first line since it's the reference)
          (let loop ([line (+ start-line 1)])
            (when (<= line end-line)
              (cbuf-set-y! cbuf line)
              (cbuf-align-line-indentation! cbuf reference-indentation)
              (loop (+ line 1))))
          
          ;; Restore cursor position
          (cbuf-set-y! cbuf original-cursor-line)
          (cbuf-set-x! cbuf (min original-cursor-x (cbuf-text-cur-base-length cbuf)) 'data)
          
          ;; Clear selection and mark as modified
          (cbuf-clear-mark! cbuf)
          (set-cbuf-modified?! cbuf #t))))))

(define (cbuf-extract-line-indentation text)
  "Extract the leading whitespace from a line.
   Returns the indentation string (spaces, tabs, or mixed)."
  (if (string-null? text)
      ""
      (let loop ([i 0])
        (cond
         [(>= i (string-length text)) text]  ; Entire line is whitespace
         [(char-whitespace? (string-ref text i))
          (loop (+ i 1))]
         [else
          (substring text 0 i)]))))  ; Return whitespace prefix

(define (cbuf-align-line-indentation! cbuf target-indentation)
  "Replace the indentation of the current line with target-indentation.
   Preserves the non-whitespace content of the line."
  (let* ([current-text (cbuf-text-cur cbuf)]
         [current-sgr-list (cbuf-sgr-list-cur cbuf)])
    
    (if (string-null? current-text)
        ;; Empty line - just set it to the target indentation
        (when (not (string-null? target-indentation))
          (cbuf-insert-string! cbuf target-indentation))
        
        ;; Non-empty line - replace indentation
        (let* ([current-indentation (cbuf-extract-line-indentation current-text)]
               [content-start-index (string-length current-indentation)]
               [line-content (substring current-text content-start-index)]
               [content-sgr-list (drop current-sgr-list content-start-index)])
          
          ;; Only proceed if there's a change needed
          (unless (string=? current-indentation target-indentation)
            ;; Save undo state
            (let ([old-metrics (cbuf-metrics-cur cbuf)])
              (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 'align-indentation))
            
            ;; Build new line with target indentation
            (let* ([default-sgr (make-default-sgr)]
                   [target-indentation-sgr (make-list (string-length target-indentation) default-sgr)]
                   [new-text (string-append target-indentation line-content)]
                   [new-sgr-list (append target-indentation-sgr content-sgr-list)])
              
              ;; Replace the entire line
              (cbuf-set-text-cur! cbuf new-text new-sgr-list)))))))

;;; Advanced indentation alignment functions

(define* (cbuf-align-indents-in-region-to-column! cbuf target-column #:key (use-tabs? #f))
  "Align all lines in region to a specific column position.
   TARGET-COLUMN: The column position to align to (0-based)
   #:use-tabs? - Use tabs for indentation when possible (default #f)"
  (when (cbuf-mark-set? cbuf)
    (let* ([mark-line (cbuf-mark-line cbuf)]
           [cursor-line (cbuf-line-cur cbuf)]
           [start-line (min mark-line cursor-line)]
           [end-line (max mark-line cursor-line)]
           [original-cursor-line (cbuf-line-cur cbuf)]
           [original-cursor-x (cbuf-x-data cbuf)]
           [tab-size (cbuf-tab-size cbuf)])
      
      ;; Create target indentation string
      (let ([target-indentation (cbuf-create-indentation-string target-column tab-size use-tabs?)])
        
        ;; Process each line in the region
        (let loop ([line start-line])
          (when (<= line end-line)
            (cbuf-set-y! cbuf line)
            (cbuf-align-line-indentation! cbuf target-indentation)
            (loop (+ line 1))))
        
        ;; Restore cursor position
        (cbuf-set-y! cbuf original-cursor-line)
        (cbuf-set-x! cbuf (min original-cursor-x (cbuf-text-cur-base-length cbuf)) 'data)
        
        ;; Clear selection and mark as modified
        (cbuf-clear-mark! cbuf)
        (set-cbuf-modified?! cbuf #t)))))

(define (cbuf-create-indentation-string column tab-size use-tabs?)
  "Create indentation string to reach the specified column.
   Uses tabs and/or spaces based on use-tabs? setting."
  (cond
   [(<= column 0) ""]
   
   [(not use-tabs?)
    ;; Use only spaces
    (make-string column #\space)]
   
   [else
    ;; Use tabs where possible, spaces for remainder
    (let* ([num-tabs (quotient column tab-size)]
           [num-spaces (remainder column tab-size)]
           [tab-string (make-string num-tabs #\tab)]
           [space-string (make-string num-spaces #\space)])
      (string-append tab-string space-string))]))

(define (cbuf-align-indents-in-region-relative! cbuf offset)
  "Adjust indentation of all lines in region by a relative offset.
   OFFSET: Number of columns to add (positive) or remove (negative)"
  (when (cbuf-mark-set? cbuf)
    (let* ([mark-line (cbuf-mark-line cbuf)]
           [cursor-line (cbuf-line-cur cbuf)]
           [start-line (min mark-line cursor-line)]
           [end-line (max mark-line cursor-line)]
           [original-cursor-line (cbuf-line-cur cbuf)]
           [original-cursor-x (cbuf-x-data cbuf)])
      
      ;; Process each line in the region
      (let loop ([line start-line])
        (when (<= line end-line)
          (cbuf-set-y! cbuf line)
          (cbuf-adjust-line-indentation-relative! cbuf offset)
          (loop (+ line 1))))
      
      ;; Restore cursor position
      (cbuf-set-y! cbuf original-cursor-line)
      (cbuf-set-x! cbuf (min original-cursor-x (cbuf-text-cur-base-length cbuf)) 'data)
      
      ;; Clear selection and mark as modified
      (cbuf-clear-mark! cbuf)
      (set-cbuf-modified?! cbuf #t))))

(define (cbuf-adjust-line-indentation-relative! cbuf offset)
  "Adjust current line's indentation by relative offset."
  (let* ([current-text (cbuf-text-cur cbuf)]
         [current-indentation (cbuf-extract-line-indentation current-text)]
         [current-indent-column (cbuf-calculate-indentation-column current-indentation (cbuf-tab-size cbuf))]
         [new-indent-column (max 0 (+ current-indent-column offset))]
         [new-indentation (cbuf-create-indentation-string new-indent-column (cbuf-tab-size cbuf) #f)])
    
    (cbuf-align-line-indentation! cbuf new-indentation)))

(define (cbuf-calculate-indentation-column indentation-string tab-size)
  "Calculate the column position that an indentation string reaches."
  (let loop ([i 0] [column 0])
    (cond
     [(>= i (string-length indentation-string)) column]
     [(char=? (string-ref indentation-string i) #\tab)
      (loop (+ i 1) (* tab-size (+ (quotient column tab-size) 1)))]
     [(char=? (string-ref indentation-string i) #\space)
      (loop (+ i 1) (+ column 1))]
     [else
      ;; Non-whitespace character (shouldn't happen in pure indentation)
      (loop (+ i 1) (+ column 1))])))

;;; =================================================================
;;; SORTING OPERATIONS (Needs undo support)
;;; =================================================================

(define (cbuf-sort-lines-in-region! cbuf)
  "Sort lines in selected region alphabetically with undo support.
   Operates on complete lines regardless of selection boundaries.
   Ignores leading whitespace when comparing lines for sort order."
  (when (cbuf-mark-set? cbuf)
    (let* ([mark-line (cbuf-mark-line cbuf)]
           [cursor-line (cbuf-line-cur cbuf)]
           [start-line (min mark-line cursor-line)]
           [end-line (max mark-line cursor-line)]
           [original-cursor-line (cbuf-line-cur cbuf)]
           [original-cursor-x (cbuf-x-data cbuf)])
      
      ;; Only proceed if we have multiple lines to sort
      (when (< start-line end-line)
        
        ;; Save undo state for the entire sort operation
        (cbuf-save-undo! cbuf 'sort-lines start-line end-line)
        ;; Extract line metrics for the region
        (let* ([lines-to-sort (cbuf-extract-lines-for-sorting cbuf start-line end-line)]
               [sorted-lines (cbuf-sort-line-metrics-list lines-to-sort)])
          
          
          ;; Replace the region with sorted lines
          (cbuf-replace-line-range! cbuf start-line end-line sorted-lines)
          
          ;; Restore cursor position (may need adjustment if lines moved)
          (let ([new-cursor-line (cbuf-find-line-new-position original-cursor-line 
                                                              lines-to-sort sorted-lines 
                                                              start-line)])
            (cbuf-set-y! cbuf (min new-cursor-line (- (cbuf-line-count cbuf) 1)))
            (cbuf-set-x! cbuf (min original-cursor-x (cbuf-text-cur-base-length cbuf)) 'data))
          
          ;; Clear selection and mark as modified
          (cbuf-clear-mark! cbuf)
          (set-cbuf-modified?! cbuf #t))))))

(define (cbuf-extract-lines-for-sorting cbuf start-line end-line)
  "Extract text-metrics for lines in range [start-line, end-line] inclusive.
   Returns list of text-metrics objects."
  (let ([metrics-list (cbuf-text-metrics cbuf)])
    (take (drop metrics-list start-line) (+ (- end-line start-line) 1))))

(define (cbuf-sort-line-metrics-list lines-metrics)
  "Sort list of text-metrics objects by their trimmed text content.
   Leading whitespace is ignored for comparison purposes."
  (sort lines-metrics
        (lambda (metrics1 metrics2)
          (let ([text1 (text-metrics-string metrics1)]
                [text2 (text-metrics-string metrics2)])
            (cbuf-line-less-than? text1 text2)))))

(define (cbuf-line-less-than? line1 line2)
  "Compare two lines for sorting, ignoring leading whitespace.
   Returns #t if line1 should come before line2 in sorted order."
  (let ([trimmed1 (string-trim-left line1)]
        [trimmed2 (string-trim-left line2)])
    (string-ci<? trimmed1 trimmed2)))

(define (cbuf-replace-line-range! cbuf start-line end-line new-metrics-list)
  "Replace lines from start-line to end-line (inclusive) with new-metrics-list."
  (let* ([metrics-list (cbuf-text-metrics cbuf)]
         [before-range (take metrics-list start-line)]
         [after-range (drop metrics-list (+ end-line 1))]
         [new-full-metrics (append before-range new-metrics-list after-range)])
    (set-cbuf-text-metrics! cbuf new-full-metrics)))

(define (cbuf-find-line-new-position original-line original-metrics sorted-metrics start-line)
  "Find where the original cursor line ended up after sorting.
   Returns the new line number where the original line content is now located."
  (let ([original-line-metrics (list-ref original-metrics (- original-line start-line))])
    
    ;; Find this metrics object in the sorted list
    (let loop ([sorted-list sorted-metrics] [index 0])
      (cond
       [(null? sorted-list) 
        ;; Shouldn't happen, but fallback to start-line
        start-line]
       
       [(cbuf-metrics-equal? original-line-metrics (car sorted-list))
        (+ start-line index)]
       
       [else
        (loop (cdr sorted-list) (+ index 1))]))))

(define (cbuf-metrics-equal? metrics1 metrics2)
  "Check if two text-metrics objects represent the same content.
   Compares both text content and SGR formatting."
  (and (string=? (text-metrics-string metrics1) 
                 (text-metrics-string metrics2))
       (equal? (text-metrics-sgr-list metrics1)
               (text-metrics-sgr-list metrics2))))

;;; Advanced sorting with custom comparison (for future extension)

(define* (cbuf-sort-lines-in-region-with-predicate! cbuf predicate #:key (ignore-leading-whitespace? #t))
  "Sort lines in selected region using custom predicate.
   PREDICATE: function taking two strings, returning #t if first should come before second.
   #:ignore-leading-whitespace? - whether to trim whitespace before comparison (default #t)"
  (when (cbuf-mark-set? cbuf)
    (let* ([mark-line (cbuf-mark-line cbuf)]
           [cursor-line (cbuf-line-cur cbuf)]
           [start-line (min mark-line cursor-line)]
           [end-line (max mark-line cursor-line)]
           [original-cursor-line (cbuf-line-cur cbuf)]
           [original-cursor-x (cbuf-x-data cbuf)])
      
      ;; Only proceed if we have multiple lines to sort
      (when (< start-line end-line)
        
        ;; Extract line metrics for the region
        (let* ([lines-to-sort (cbuf-extract-lines-for-sorting cbuf start-line end-line)]
               [sorted-lines (cbuf-sort-line-metrics-with-predicate lines-to-sort predicate ignore-leading-whitespace?)])
          
          ;; Save undo state for the entire region
          (cbuf-save-undo! cbuf 'sort-lines-custom start-line end-line)
          
          ;; Replace the region with sorted lines
          (cbuf-replace-line-range! cbuf start-line end-line sorted-lines)
          
          ;; Restore cursor position
          (let ([new-cursor-line (cbuf-find-line-new-position original-cursor-line 
                                                              lines-to-sort sorted-lines 
                                                              start-line)])
            (cbuf-set-y! cbuf (min new-cursor-line (- (cbuf-line-count cbuf) 1)))
            (cbuf-set-x! cbuf (min original-cursor-x (cbuf-text-cur-base-length cbuf)) 'data))
          
          ;; Clear selection and mark as modified
          (cbuf-clear-mark! cbuf)
          (set-cbuf-modified?! cbuf #t))))))

(define (cbuf-sort-line-metrics-with-predicate lines-metrics predicate ignore-leading-whitespace?)
  "Sort list of text-metrics using custom predicate."
  (sort lines-metrics
        (lambda (metrics1 metrics2)
          (let* ([text1 (text-metrics-string metrics1)]
                 [text2 (text-metrics-string metrics2)]
                 [compare-text1 (if ignore-leading-whitespace? (string-trim-left text1) text1)]
                 [compare-text2 (if ignore-leading-whitespace? (string-trim-left text2) text2)])
            (predicate compare-text1 compare-text2)))))

;;; Convenience functions for common sorting patterns

(define (cbuf-sort-lines-in-region-case-sensitive! cbuf)
  "Sort lines in region with case-sensitive comparison."
  (cbuf-sort-lines-in-region-with-predicate! cbuf string<?))

(define (cbuf-sort-lines-in-region-reverse! cbuf)
  "Sort lines in region in reverse alphabetical order."
  (cbuf-sort-lines-in-region-with-predicate! cbuf string-ci>?))

(define (cbuf-sort-lines-in-region-by-length! cbuf)
  "Sort lines in region by length (shortest first)."
  (cbuf-sort-lines-in-region-with-predicate! cbuf 
    (lambda (str1 str2) (< (string-length str1) (string-length str2)))))

;;; =================================================================
;;; SWAPPING OPERATIONS (All need undo support)
;;; =================================================================

(define (cbuf-swap-current-and-previous-line! cbuf)
  "Swap current line with previous line with undo support.
   Cursor moves up with the swapped line (follows the line content)."
  (let ([current-line (cbuf-line-cur cbuf)]
        [current-x (cbuf-x-data cbuf)])
    
    (when (> current-line 0)  ; Can't swap if we're on the first line
      (let* ([prev-line (- current-line 1)])
        
        ;; Save undo state for the swap operation
        (cbuf-save-undo! cbuf 'swap-lines prev-line current-line)
        
        (let ([current-metrics (list-ref (cbuf-text-metrics cbuf) current-line)]
              [prev-metrics (list-ref (cbuf-text-metrics cbuf) prev-line)])
        ;; Perform the swap
        (let* ([metrics-list (cbuf-text-metrics cbuf)]
               [new-metrics-list (list-update 
                                  (list-update metrics-list prev-line current-metrics)
                                  current-line prev-metrics)])
          (set-cbuf-text-metrics! cbuf new-metrics-list))
        
        ;; Move cursor up with the line content
        (cbuf-set-y! cbuf prev-line)
        (cbuf-set-x! cbuf (min current-x (cbuf-text-cur-base-length cbuf)) 'data)
        
        ;; Mark as modified
          (set-cbuf-modified?! cbuf #t))))))

(define (cbuf-swap-current-and-following-line! cbuf)
  "Swap current line with following line with undo support.
   Cursor moves down with the swapped line (follows the line content)."
  (let ([current-line (cbuf-line-cur cbuf)]
        [current-x (cbuf-x-data cbuf)])
    
    (when (< current-line (- (cbuf-line-count cbuf) 1))  ; Can't swap if we're on the last line
      (let* ([next-line (+ current-line 1)])
        
        ;; Save undo state for the swap operation  
        (cbuf-save-undo! cbuf 'swap-lines current-line next-line)
        
        (let ([current-metrics (list-ref (cbuf-text-metrics cbuf) current-line)]
              [next-metrics (list-ref (cbuf-text-metrics cbuf) next-line)])
        ;; Perform the swap
        (let* ([metrics-list (cbuf-text-metrics cbuf)]
               [new-metrics-list (list-update 
                                  (list-update metrics-list current-line next-metrics)
                                  next-line current-metrics)])
          (set-cbuf-text-metrics! cbuf new-metrics-list))
        
        ;; Move cursor down with the line content
        (cbuf-set-y! cbuf next-line)
        (cbuf-set-x! cbuf (min current-x (cbuf-text-cur-base-length cbuf)) 'data)
        
        ;; Mark as modified
          (set-cbuf-modified?! cbuf #t))))))

(define (cbuf-swap-current-and-previous-grapheme! cbuf)
  "Swap current grapheme cluster with previous grapheme cluster with undo support.
   Cursor moves left with the swapped grapheme (follows the content)."
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [text (cbuf-text-cur cbuf)]
         [sgr-list (cbuf-sgr-list-cur cbuf)])
    
    (when (and (> current-x 0) (not (string-null? text)))
      ;; Save undo state
      (cbuf-save-undo! cbuf 'swap-graphemes 'previous)
      (let* ([prev-x-data (- current-x 1)]
             ;; Find grapheme cluster boundaries
             [current-bounds (cbuf-find-grapheme-cluster-bounds cbuf current-x)]
             [prev-bounds (cbuf-find-grapheme-cluster-bounds cbuf prev-x-data)]
             [current-start-index (car current-bounds)]
             [current-end-index (cadr current-bounds)]
             [prev-start-index (car prev-bounds)]  
             [prev-end-index (cadr prev-bounds)])
        
        ;; Only proceed if we have distinct, valid grapheme clusters
        (when (and (< prev-start-index prev-end-index)
                   (< current-start-index current-end-index)
                   (not (= prev-start-index current-start-index)))
          
          ;; Extract the grapheme clusters and their SGR
          (let* ([prev-grapheme (substring text prev-start-index prev-end-index)]
                 [current-grapheme (substring text current-start-index current-end-index)]
                 [prev-grapheme-sgr (take (drop sgr-list prev-start-index) 
                                          (- prev-end-index prev-start-index))]
                 [current-grapheme-sgr (take (drop sgr-list current-start-index)
                                            (- current-end-index current-start-index))]
                 
                 ;; Build new text with swapped graphemes
                 [before-prev (substring text 0 prev-start-index)]
                 [between-graphemes (substring text prev-end-index current-start-index)]
                 [after-current (substring text current-end-index)]
                 [new-text (string-append before-prev current-grapheme between-graphemes prev-grapheme after-current)]
                 
                 ;; Build new SGR list with swapped formatting
                 [before-prev-sgr (take sgr-list prev-start-index)]
                 [between-sgr (take (drop sgr-list prev-end-index) 
                                   (- current-start-index prev-end-index))]
                 [after-current-sgr (drop sgr-list current-end-index)]
                 [new-sgr-list (append before-prev-sgr current-grapheme-sgr between-sgr 
                                       prev-grapheme-sgr after-current-sgr)])
            
            ;; Apply the changes
            (cbuf-set-text-cur! cbuf new-text new-sgr-list)
            
            ;; Move cursor to follow the swapped grapheme (moves left)
            (cbuf-set-x! cbuf prev-x-data 'data)
            
            ;; Mark as modified
            (set-cbuf-modified?! cbuf #t)))))))

(define (cbuf-swap-current-and-following-grapheme! cbuf)
  "Swap current grapheme cluster with following grapheme cluster with undo support.
   Cursor moves right with the swapped grapheme (follows the content)."
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [text (cbuf-text-cur cbuf)]
         [sgr-list (cbuf-sgr-list-cur cbuf)]
         [text-base-length (cbuf-text-cur-base-length cbuf)])
    
    (when (and (< current-x text-base-length) (not (string-null? text)))
      ;; Save undo state
      (cbuf-save-undo! cbuf 'swap-graphemes 'following)
      (let* ([next-x-data (min (+ current-x 1) text-base-length)]
             ;; Find grapheme cluster boundaries
             [current-bounds (cbuf-find-grapheme-cluster-bounds cbuf current-x)]
             [next-bounds (cbuf-find-grapheme-cluster-bounds cbuf next-x-data)]
             [current-start-index (car current-bounds)]
             [current-end-index (cadr current-bounds)]
             [next-start-index (car next-bounds)]
             [next-end-index (cadr next-bounds)])
        
        ;; Only proceed if we have distinct, valid grapheme clusters
        (when (and (< current-start-index current-end-index)
                   (< next-start-index next-end-index)
                   (not (= current-start-index next-start-index))
                   (< current-end-index (string-length text)))
          
          ;; Extract the grapheme clusters and their SGR
          (let* ([current-grapheme (substring text current-start-index current-end-index)]
                 [next-grapheme (substring text next-start-index next-end-index)]
                 [current-grapheme-sgr (take (drop sgr-list current-start-index)
                                            (- current-end-index current-start-index))]
                 [next-grapheme-sgr (take (drop sgr-list next-start-index)
                                         (- next-end-index next-start-index))]
                 
                 ;; Build new text with swapped graphemes
                 [before-current (substring text 0 current-start-index)]
                 [between-graphemes (substring text current-end-index next-start-index)]  
                 [after-next (substring text next-end-index)]
                 [new-text (string-append before-current next-grapheme between-graphemes current-grapheme after-next)]
                 
                 ;; Build new SGR list with swapped formatting
                 [before-current-sgr (take sgr-list current-start-index)]
                 [between-sgr (take (drop sgr-list current-end-index)
                                   (- next-start-index current-end-index))]
                 [after-next-sgr (drop sgr-list next-end-index)]
                 [new-sgr-list (append before-current-sgr next-grapheme-sgr between-sgr 
                                       current-grapheme-sgr after-next-sgr)])
            
            ;; Apply the changes
            (cbuf-set-text-cur! cbuf new-text new-sgr-list)
            
            ;; Move cursor to follow the swapped grapheme (moves right)
            ;; Calculate new position: we're now where the next grapheme was
            (let ([new-x-data (+ current-x (count-base-characters next-grapheme))])
              (cbuf-set-x! cbuf (min new-x-data text-base-length) 'data))
            
            ;; Mark as modified
            (set-cbuf-modified?! cbuf #t)))))))

;;; =================================================================
;;; TAB CONVERSION (Needs undo support)
;;; =================================================================

(define (cbuf-tabify-buffer! cbuf)
  "Convert sequences of spaces to tabs throughout the entire buffer with undo support.
   Operates on graphical columns - tabs align to columns 0, 8, 16, etc."
  ;; Save undo state for entire buffer
  (cbuf-save-undo! cbuf 'tabify-buffer)
  (let* ([original-line (cbuf-line-cur cbuf)]
         [original-x (cbuf-x-data cbuf)]
         [line-count (cbuf-line-count cbuf)])
    
    ;; Process each line in the buffer
    (let loop ([line 0])
      (when (< line line-count)
        (cbuf-set-y! cbuf line)
        (cbuf-tabify-current-line! cbuf)
        (loop (+ line 1))))
    
    ;; Restore original cursor position (may need adjustment)
    (cbuf-set-y! cbuf (min original-line (- (cbuf-line-count cbuf) 1)))
    (cbuf-set-x! cbuf (min original-x (cbuf-text-cur-base-length cbuf)) 'data)))

(define (cbuf-untabify-buffer! cbuf)
  "Convert all tabs to spaces throughout the entire buffer with undo support.
   Expands tabs to proper graphical column positions."
  ;; Save undo state for entire buffer
  (cbuf-save-undo! cbuf 'untabify-buffer)
  (let* ([original-line (cbuf-line-cur cbuf)]
         [original-x (cbuf-x-data cbuf)]
         [line-count (cbuf-line-count cbuf)])
    
    ;; Process each line in the buffer
    (let loop ([line 0])
      (when (< line line-count)
        (cbuf-set-y! cbuf line)
        (cbuf-untabify-current-line! cbuf)
        (loop (+ line 1))))
    
    ;; Restore original cursor position (may need adjustment)
    (cbuf-set-y! cbuf (min original-line (- (cbuf-line-count cbuf) 1)))
    (cbuf-set-x! cbuf (min original-x (cbuf-text-cur-base-length cbuf)) 'data)))

(define (cbuf-tabify-lines-in-selected-region! cbuf)
  "Convert spaces to tabs in all lines touched by the selected region with undo support.
   Operates on complete lines for simplicity."
  (when (cbuf-mark-set? cbuf)
    (let* ([mark-line (cbuf-mark-line cbuf)]
           [cursor-line (cbuf-line-cur cbuf)]
           [start-line (min mark-line cursor-line)]
           [end-line (max mark-line cursor-line)])
      ;; Save undo state for affected region
      (cbuf-save-undo! cbuf 'tabify-region start-line end-line)
      (let ([original-line (cbuf-line-cur cbuf)]
           [original-x (cbuf-x-data cbuf)])
      
      ;; Process each line in the region
      (let loop ([line start-line])
        (when (<= line end-line)
          (cbuf-set-y! cbuf line)
          (cbuf-tabify-current-line! cbuf)
          (loop (+ line 1))))
      
      ;; Restore original cursor position
      (cbuf-set-y! cbuf original-line)
      (cbuf-set-x! cbuf (min original-x (cbuf-text-cur-base-length cbuf)) 'data)
      
      ;; Clear selection
        (cbuf-clear-mark! cbuf)))))

(define (cbuf-untabify-lines-in-selected-region! cbuf)
  "Convert tabs to spaces in all lines touched by the selected region with undo support.
   Operates on complete lines for simplicity."
  (when (cbuf-mark-set? cbuf)
    (let* ([mark-line (cbuf-mark-line cbuf)]
           [cursor-line (cbuf-line-cur cbuf)]
           [start-line (min mark-line cursor-line)]
           [end-line (max mark-line cursor-line)])
      ;; Save undo state for affected region
      (cbuf-save-undo! cbuf 'untabify-region start-line end-line)
      (let ([original-line (cbuf-line-cur cbuf)]
           [original-x (cbuf-x-data cbuf)])
      
      ;; Process each line in the region
      (let loop ([line start-line])
        (when (<= line end-line)
          (cbuf-set-y! cbuf line)
          (cbuf-untabify-current-line! cbuf)
          (loop (+ line 1))))
      
      ;; Restore original cursor position
      (cbuf-set-y! cbuf original-line)
      (cbuf-set-x! cbuf (min original-x (cbuf-text-cur-base-length cbuf)) 'data)
      
      ;; Clear selection
        (cbuf-clear-mark! cbuf)))))

(define (cbuf-tabify-current-line! cbuf)
  "Convert sequences of spaces to tabs on the current line.
   Uses graphical column positions for proper tab alignment."
  (let* ([text (cbuf-text-cur cbuf)]
         [sgr-list (cbuf-sgr-list-cur cbuf)]
         [tab-size (cbuf-tab-size cbuf)])
    
    (unless (string-null? text)
      (let ([result (cbuf-tabify-string-with-sgr text sgr-list tab-size)])
        (let ([new-text (car result)]
              [new-sgr-list (cdr result)])
          (unless (string=? text new-text)
            (cbuf-set-text-cur! cbuf new-text new-sgr-list)))))))

(define (cbuf-untabify-current-line! cbuf)
  "Convert all tabs to spaces on the current line.
   Expands tabs to proper graphical column positions."
  (let* ([text (cbuf-text-cur cbuf)]
         [sgr-list (cbuf-sgr-list-cur cbuf)]
         [tab-size (cbuf-tab-size cbuf)])
    
    (unless (string-null? text)
      (let ([result (cbuf-untabify-string-with-sgr text sgr-list tab-size)])
        (let ([new-text (car result)]
              [new-sgr-list (cdr result)])
          (unless (string=? text new-text)
            (cbuf-set-text-cur! cbuf new-text new-sgr-list)))))))

(define (cbuf-tabify-string-with-sgr text sgr-list tab-size)
  "Convert spaces to tabs in string while preserving SGR formatting.
   Returns (new-text . new-sgr-list)."
  (if (string-null? text)
      (cons text sgr-list)
      (let ([result-chars '()]
            [result-sgr '()]
            [current-column 0])
        
        (let loop ([i 0])
          (cond
           [(>= i (string-length text))
            ;; End of string
            (cons (string-from-chars (reverse result-chars))
                  (reverse result-sgr))]
           
           [else
            (let ([ch (string-ref text i)]
                  [ch-sgr (list-ref sgr-list i)])
              (cond
               ;; Tab character - just copy it
               [(char=? ch #\tab)
                (set! result-chars (cons ch result-chars))
                (set! result-sgr (cons ch-sgr result-sgr))
                (set! current-column (* tab-size (+ (quotient current-column tab-size) 1)))
                (loop (+ i 1))]
               
               ;; Space character - check for tabification opportunity
               [(char=? ch #\space)
                (let ([space-result (cbuf-process-space-sequence text sgr-list i current-column tab-size)])
                  (let ([new-chars (car space-result)]
                        [new-sgrs (cadr space-result)]
                        [new-column (caddr space-result)]
                        [chars-consumed (cadddr space-result)])
                    (set! result-chars (append (reverse new-chars) result-chars))
                    (set! result-sgr (append (reverse new-sgrs) result-sgr))
                    (set! current-column new-column)
                    (loop (+ i chars-consumed))))]
               
               ;; Regular character
               [else
                (set! result-chars (cons ch result-chars))
                (set! result-sgr (cons ch-sgr result-sgr))
                (set! current-column (+ current-column (wcwidth (char->integer ch) (cbuf-cjk? cbuf))))
                (loop (+ i 1))]))])))))

(define (cbuf-process-space-sequence text sgr-list start-index current-column tab-size)
  "Process a sequence of spaces, converting to tabs where beneficial.
   Returns (chars sgrs new-column chars-consumed)."
  (let ([text-len (string-length text)])
    
    ;; Count consecutive spaces
    (let count-spaces ([i start-index] [space-count 0])
      (if (and (< i text-len) (char=? (string-ref text i) #\space))
          (count-spaces (+ i 1) (+ space-count 1))
          
          ;; Now we know how many spaces we have
          (let* ([end-column (+ current-column space-count)]
                 [next-tab-column (* tab-size (+ (quotient current-column tab-size) 1))])
            
            (cond
             ;; No spaces to process
             [(= space-count 0)
              (list '() '() current-column 0)]
             
             ;; Spaces don't reach next tab stop - keep as spaces
             [(< end-column next-tab-column)
              (let ([space-chars (make-list space-count #\space)]
                    [space-sgrs (take (drop sgr-list start-index) space-count)])
                (list space-chars space-sgrs end-column space-count))]
             
             ;; Spaces cross or reach tab boundary - convert to tab + remaining spaces
             [else
              (let* ([spaces-to-tab (- next-tab-column current-column)]
                     [remaining-spaces (- space-count spaces-to-tab)]
                     [tab-sgr (list-ref sgr-list start-index)]  ; Use first space's SGR
                     [result-chars (cons #\tab (make-list remaining-spaces #\space))]
                     [result-sgrs (cons tab-sgr (if (> remaining-spaces 0)
                                                    (take (drop sgr-list (+ start-index spaces-to-tab)) remaining-spaces)
                                                    '()))])
                (list result-chars result-sgrs end-column space-count))]))))))

(define (cbuf-untabify-string-with-sgr text sgr-list tab-size)
  "Convert tabs to spaces in string while preserving SGR formatting.
   Returns (new-text . new-sgr-list)."
  (if (string-null? text)
      (cons text sgr-list)
      (let ([result-chars '()]
            [result-sgr '()]
            [current-column 0])
        
        (let loop ([i 0])
          (cond
           [(>= i (string-length text))
            ;; End of string
            (cons (string-from-chars (reverse result-chars))
                  (reverse result-sgr))]
           
           [else
            (let ([ch (string-ref text i)]
                  [ch-sgr (list-ref sgr-list i)])
              (cond
               ;; Tab character - expand to spaces
               [(char=? ch #\tab)
                (let* ([next-tab-column (* tab-size (+ (quotient current-column tab-size) 1))]
                       [spaces-needed (- next-tab-column current-column)]
                       [space-chars (make-list spaces-needed #\space)]
                       [space-sgrs (make-list spaces-needed ch-sgr)])
                  (set! result-chars (append (reverse space-chars) result-chars))
                  (set! result-sgr (append (reverse space-sgrs) result-sgr))
                  (set! current-column next-tab-column)
                  (loop (+ i 1)))]
               
               ;; Regular character
               [else
                (set! result-chars (cons ch result-chars))
                (set! result-sgr (cons ch-sgr result-sgr))
                (set! current-column (+ current-column (wcwidth (char->integer ch) #f)))
                (loop (+ i 1))]))])))))

;;; =================================================================
;;; CASE CONVERSION (Needs undo support)
;;; =================================================================

(define (cbuf-upcase-region! cbuf)
  "Convert selected region to uppercase with undo support.
   Preserves SGR formatting and handles Unicode case conversion properly."
  (when (cbuf-mark-set? cbuf)
    ;; Save undo state
    (cbuf-save-undo! cbuf 'upcase-region)
    (let* ([region-text (cbuf-get-region-text cbuf)]
           [uppercased-text (string-upcase region-text)])
      
      ;; Only proceed if there's actually a change
      (unless (string=? region-text uppercased-text)
        (cbuf-replace-region-with-case-conversion! cbuf uppercased-text)))))

(define (cbuf-downcase-region! cbuf)
  "Convert selected region to lowercase with undo support.
   Preserves SGR formatting and handles Unicode case conversion properly."
  (when (cbuf-mark-set? cbuf)
    ;; Save undo state
    (cbuf-save-undo! cbuf 'downcase-region)
    (let* ([region-text (cbuf-get-region-text cbuf)]
           [lowercased-text (string-downcase region-text)])
      
      ;; Only proceed if there's actually a change
      (unless (string=? region-text lowercased-text)
        (cbuf-replace-region-with-case-conversion! cbuf lowercased-text)))))

(define (cbuf-titlecase-region! cbuf)
  "Convert selected region to title case with undo support.
   Preserves SGR formatting and handles Unicode case conversion properly."
  (when (cbuf-mark-set? cbuf)
    ;; Save undo state
    (cbuf-save-undo! cbuf 'titlecase-region)
    (let* ([region-text (cbuf-get-region-text cbuf)]
           [titlecased-text (cbuf-string-titlecase region-text)])
      
      ;; Only proceed if there's actually a change
      (unless (string=? region-text titlecased-text)
        (cbuf-replace-region-with-case-conversion! cbuf titlecased-text)))))

(define (cbuf-string-titlecase text)
  "Convert string to title case - capitalize first letter of each word.
   More sophisticated than string-titlecase - handles contractions and punctuation correctly."
  (if (string-null? text)
      text
      (let* ([text-len (string-length text)]
             [result-chars '()]
             [at-word-start? #t])  ; Start of string is considered word start
        
        (let loop ([i 0])
          (if (>= i text-len)
              (string-from-chars (reverse result-chars))
              (let ([ch (string-ref text i)])
                (cond
                 ;; Word character
                 [(not (char-word-delimiter? ch))
                  (let ([converted-ch (if at-word-start?
                                         (char-upcase ch)
                                         (char-downcase ch))])
                    (set! result-chars (cons converted-ch result-chars))
                    (set! at-word-start? #f)
                    (loop (+ i 1)))]
                 
                 ;; Delimiter character (whitespace, punctuation)
                 [else
                  (set! result-chars (cons ch result-chars))
                  (set! at-word-start? #t)  ; Next letter will be word start
                  (loop (+ i 1))])))))))

(define (cbuf-replace-region-with-case-conversion! cbuf new-text)
  "Replace selected region with case-converted text, preserving SGR formatting.
   Handles both single-line and multi-line selections."
  (let* ([mark-line (cbuf-mark-line cbuf)]
         [mark-x-data (cbuf-mark-x-data cbuf)]
         [cursor-line (cbuf-line-cur cbuf)]
         [cursor-x-data (cbuf-x-data cbuf)]
         
         ;; Normalize positions (start <= end)
         [start-line (min mark-line cursor-line)]
         [start-x-data (if (= mark-line cursor-line)
                          (min mark-x-data cursor-x-data)
                          (if (< mark-line cursor-line) mark-x-data cursor-x-data))]
         [end-line (max mark-line cursor-line)]
         [end-x-data (if (= mark-line cursor-line)
                        (max mark-x-data cursor-x-data)
                        (if (> mark-line cursor-line) mark-x-data cursor-x-data))]
         
         ;; Extract SGR formatting from the original region
         [region-sgr-list (cbuf-extract-region-sgr-list cbuf start-line start-x-data end-line end-x-data)]
         
         ;; Handle potential length changes after case conversion
         [original-text (cbuf-get-region-text cbuf)]
         [new-sgr-list (cbuf-adjust-sgr-for-case-conversion region-sgr-list original-text new-text)])
    
    ;; Replace the region with new text and adjusted SGR
    (cbuf-delete-region! cbuf start-line start-x-data end-line end-x-data)
    (cbuf-insert-string-with-sgr! cbuf new-text new-sgr-list)
    
    ;; Clear selection and position cursor at end of inserted text
    (cbuf-clear-mark! cbuf)))

(define (cbuf-extract-region-sgr-list cbuf start-line start-x-data end-line end-x-data)
  "Extract SGR formatting from a region of text.
   Returns list of SGR records corresponding to each character in the region."
  (cond
   ;; Single line selection
   [(= start-line end-line)
    (let* ([line-metrics (list-ref (cbuf-text-metrics cbuf) start-line)]
           [line-sgr (text-metrics-sgr-list line-metrics)]
           [start-index (text-metrics-x-data->x-index line-metrics start-x-data)]
           [end-index (text-metrics-x-data->x-index line-metrics end-x-data)])
      (take (drop line-sgr start-index) (- end-index start-index)))]
   
   ;; Multi-line selection
   [else
    (let ([result-sgr '()])
      
      ;; First line (from start position to end of line)
      (let* ([first-line-metrics (list-ref (cbuf-text-metrics cbuf) start-line)]
             [first-line-sgr (text-metrics-sgr-list first-line-metrics)]
             [start-index (text-metrics-x-data->x-index first-line-metrics start-x-data)]
             [first-part-sgr (drop first-line-sgr start-index)])
        (set! result-sgr (append result-sgr first-part-sgr)))
      
      ;; Add line ending SGR (use default)
      (set! result-sgr (append result-sgr (list (make-default-sgr))))
      
      ;; Middle lines (complete lines)
      (let loop ([line (+ start-line 1)])
        (when (< line end-line)
          (let* ([line-metrics (list-ref (cbuf-text-metrics cbuf) line)]
                 [line-sgr (text-metrics-sgr-list line-metrics)])
            (set! result-sgr (append result-sgr line-sgr))
            ;; Add line ending SGR
            (set! result-sgr (append result-sgr (list (make-default-sgr))))
            (loop (+ line 1)))))
      
      ;; Last line (from beginning to end position)
      (when (> end-line start-line)
        (let* ([last-line-metrics (list-ref (cbuf-text-metrics cbuf) end-line)]
               [last-line-sgr (text-metrics-sgr-list last-line-metrics)]
               [end-index (text-metrics-x-data->x-index last-line-metrics end-x-data)]
               [last-part-sgr (take last-line-sgr end-index)])
          (set! result-sgr (append result-sgr last-part-sgr))))
      
      result-sgr)]))

(define (cbuf-adjust-sgr-for-case-conversion sgr-list original-text new-text)
  "Adjust SGR list when text length changes due to case conversion.
   Handles cases where Unicode case conversion changes string length."
  (let ([original-len (string-length original-text)]
        [new-len (string-length new-text)]
        [sgr-len (length sgr-list)])
    
    (cond
     ;; Lengths match - return original SGR list
     [(= new-len sgr-len) sgr-list]
     
     ;; New text is longer - extend SGR list
     [(> new-len sgr-len)
      (let ([default-sgr (if (null? sgr-list) 
                             (make-default-sgr)
                             (last sgr-list))])
        (append sgr-list (make-list (- new-len sgr-len) default-sgr)))]
     
     ;; New text is shorter - truncate SGR list
     [else
      (take sgr-list new-len)])))

(define (cbuf-insert-string-with-sgr! cbuf text sgr-list)
  "Insert string with associated SGR formatting at current position"
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [current-index (cbuf-x-data->x-index cbuf current-x)]
         [line-text (cbuf-text-cur cbuf)]
         [line-sgr (cbuf-sgr-list-cur cbuf)])
    
    ;; Handle single-line vs multi-line insertion
    (if (string-contains text (cbuf-line-ending cbuf))
        ;; Multi-line insertion - use existing cbuf-insert-string!
        (cbuf-insert-string! cbuf text)
        ;; Single-line insertion with SGR preservation
        (let* ([new-text (string-insert-string line-text current-index text)]
               [new-sgr-list (append (take line-sgr current-index)
                                     sgr-list
                                     (drop line-sgr current-index))])
          (cbuf-set-text-cur! cbuf new-text new-sgr-list)
          ;; Move cursor to end of inserted text
          (cbuf-set-x! cbuf (+ current-x (count-base-characters text)) 'data)))))

;;; =================================================================
;;; SMART SELECTION FUNCTIONS
;;; =================================================================

(define (cbuf-select-paragraph! cbuf)
  "Smart paragraph selection.
   - If cursor is in non-blank line: select that paragraph
   - If cursor is in blank line: select following paragraph (if exists)"
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)])
    
    (cond
     ;; Cursor is on non-blank line - select current paragraph
     [(not (cbuf-line-blank? cbuf current-line))
      (let* ([para-start (cbuf-find-paragraph-start cbuf current-line)]
             [para-end (cbuf-find-paragraph-end cbuf current-line)])
        ;; Select from beginning of paragraph to end
        (cbuf-set-y! cbuf para-start)
        (cbuf-beginning-of-line! cbuf)
        (cbuf-set-mark! cbuf)
        ;; Move to end of paragraph (beginning of next paragraph or end of buffer)
        (if (>= para-end (cbuf-line-count cbuf))
            (cbuf-end-of-buffer! cbuf)
            (begin
              (cbuf-set-y! cbuf para-end)
              (cbuf-beginning-of-line! cbuf))))]
     
     ;; Cursor is on blank line - select following paragraph
     [else
      (let ([next-para-start (cbuf-skip-blank-lines cbuf current-line 'forward)])
        (if (>= next-para-start (cbuf-line-count cbuf))
            ;; No following paragraph - do nothing
            #f
            ;; Select the following paragraph
            (let ([next-para-end (cbuf-find-paragraph-end cbuf next-para-start)])
              (cbuf-set-y! cbuf next-para-start)
              (cbuf-beginning-of-line! cbuf)
              (cbuf-set-mark! cbuf)
              ;; Move to end of paragraph
              (if (>= next-para-end (cbuf-line-count cbuf))
                  (cbuf-end-of-buffer! cbuf)
                  (begin
                    (cbuf-set-y! cbuf next-para-end)
                    (cbuf-beginning-of-line! cbuf))))))])))

(define (cbuf-select-word! cbuf)
  "Smart word selection.
   - If cursor is in word: select that word  
   - If cursor is on non-word character: select following word (if exists)"
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [text (cbuf-text-cur cbuf)]
         [current-index (cbuf-x-data->x-index cbuf current-x)])
    
    (cond
     ;; Empty line - do nothing
     [(string-null? text) #f]
     
     ;; At end of line - do nothing
     [(>= current-index (string-length text)) #f]
     
     ;; Cursor is on word character - select current word
     [(not (char-word-delimiter? (string-ref text current-index)))
      (let* ([word-start-index (find-word-begin-backward text current-index char-word-delimiter?)]
             [word-end-index (find-word-end-forward text current-index char-word-delimiter?)]
             [word-start-x-data (cbuf-x-index->x-data cbuf word-start-index)]
             [word-end-x-data (cbuf-x-index->x-data cbuf word-end-index)])
        ;; Select the word
        (cbuf-set-x! cbuf word-start-x-data 'data)
        (cbuf-set-mark! cbuf)
        (cbuf-set-x! cbuf word-end-x-data 'data))]
     
     ;; Cursor is on delimiter - select following word
     [else
      (let ([next-word-start (skip-delimiters-forward text current-index)])
        (if (>= next-word-start (string-length text))
            ;; No following word on this line - try next line
            (cbuf-select-word-next-line! cbuf)
            ;; Select following word on current line
            (let* ([next-word-end (find-word-end-forward text next-word-start char-word-delimiter?)]
                   [start-x-data (cbuf-x-index->x-data cbuf next-word-start)]
                   [end-x-data (cbuf-x-index->x-data cbuf next-word-end)])
              (cbuf-set-x! cbuf start-x-data 'data)
              (cbuf-set-mark! cbuf)
              (cbuf-set-x! cbuf end-x-data 'data))))])))

(define (cbuf-select-word-next-line! cbuf)
  "Helper: select first word on next non-blank line"
  (let ([current-line (cbuf-line-cur cbuf)])
    (let loop ([line (+ current-line 1)])
      (cond
       ;; Reached end of buffer
       [(>= line (cbuf-line-count cbuf)) #f]
       
       ;; Found non-blank line
       [(not (cbuf-line-blank? cbuf line))
        (let* ([text (cbuf-get-line-text cbuf line)]
               [first-word-start (skip-whitespace-forward text 0)])
          (if (>= first-word-start (string-length text))
              ;; Line has no words, try next line
              (loop (+ line 1))
              ;; Select first word on this line
              (let* ([first-word-end (find-word-end-forward text first-word-start char-word-delimiter?)]
                     [start-x-data (cbuf-x-index->x-data cbuf first-word-start)]
                     [end-x-data (cbuf-x-index->x-data cbuf first-word-end)])
                (cbuf-set-y! cbuf line)
                (cbuf-set-x! cbuf start-x-data 'data)
                (cbuf-set-mark! cbuf)
                (cbuf-set-x! cbuf end-x-data 'data))))]
       
       ;; Blank line, continue searching
       [else (loop (+ line 1))]))))

(define (cbuf-select-sentence! cbuf)
  "Smart sentence selection.
   - If cursor is in sentence: select that sentence
   - If cursor is on sentence boundary: select following sentence (if exists)"
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)])
    
    (cond
     ;; Already at sentence beginning - select current sentence
     [(cbuf-at-sentence-beginning? cbuf)
      (cbuf-select-current-sentence! cbuf)]
     
     ;; In middle of sentence - select current sentence  
     [else
      (let ([sentence-start (cbuf-find-current-sentence-start cbuf)])
        (if sentence-start
            (begin
              ;; Move to sentence start
              (cbuf-set-y! cbuf (car sentence-start))
              (cbuf-set-x! cbuf (cdr sentence-start) 'data)
              (cbuf-select-current-sentence! cbuf))
            ;; No sentence found - do nothing
            #f))])))

(define (cbuf-select-current-sentence! cbuf)
  "Select sentence starting from current position"
  (let* ([start-line (cbuf-line-cur cbuf)]
         [start-x (cbuf-x-data cbuf)])
    ;; Set mark at sentence start
    (cbuf-set-mark! cbuf)
    
    ;; Find next sentence start (end of current sentence)
    (let ([next-sentence (cbuf-find-next-sentence-start cbuf)])
      (if next-sentence
          (begin
            ;; Move to beginning of next sentence
            (cbuf-set-y! cbuf (car next-sentence))
            (cbuf-set-x! cbuf (cdr next-sentence) 'data))
          ;; No next sentence - select to end of buffer
          (cbuf-end-of-buffer! cbuf)))))

;;; =================================================================
;;; LINE FORMATTING (Needs undo support)
;;; =================================================================

(define (cbuf-center-line! cbuf)
  "Center the current line between home and limit positions with undo support.
   Only works if home and limit are presentation positions (not data).
   Strips leading and trailing whitespace, then centers the content."
  
  ;; First verify that we can center (presentation mode required)
  (unless (eq? (cbuf-limit-type cbuf) 'presentation)
    (error "cbuf-center-line!: requires presentation-mode positioning (home/limit must be presentation positions)"))
  ;; Save undo state
  (cbuf-save-undo! cbuf 'center-line)
  
  (let* ([home-pos (cbuf-home-pos cbuf)]
         [limit-pos (cbuf-limit-pos cbuf)]
         [center-point (quotient (+ home-pos limit-pos) 2)]
         [available-width (- limit-pos home-pos)]
         [current-text (cbuf-text-cur cbuf)]
         [current-sgr-list (cbuf-sgr-list-cur cbuf)])
    
    ;; Only proceed if we have reasonable constraints
    (when (and (> available-width 0) (not (string-null? current-text)))
      
      ;; Strip whitespace and compute content metrics
      (let* ([trimmed-text (string-trim current-text)]
             [trim-left-count (- (string-length current-text)
                                (string-length (string-trim-left current-text)))]
             [trim-right-count (- (string-length current-text)
                                 (string-length (string-trim-right current-text)))]
             [content-start-index trim-left-count]
             [content-end-index (- (string-length current-text) trim-right-count)]
             [content-sgr-list (take (drop current-sgr-list content-start-index)
                                    (- content-end-index content-start-index))])
        
        (if (string-null? trimmed-text)
            ;; Line is all whitespace - just clear it
            (begin
              (cbuf-beginning-of-line! cbuf)
              (cbuf-delete-to-end-of-line! cbuf))
            
            ;; Center the non-whitespace content
            (let* ([content-metrics (compute-text-metrics-with-sgr trimmed-text 
                                                                   content-sgr-list
                                                                   (cbuf-tab-size cbuf)
                                                                   #:cjk? (cbuf-cjk? cbuf))]
                   [content-width (text-metrics-cell-length content-metrics)]
                   [left-padding (max 0 (- center-point (quotient content-width 2) home-pos))]
                   [padding-spaces (make-string left-padding #\space)]
                   [default-sgr (make-default-sgr)]
                   [padding-sgr-list (make-list left-padding default-sgr)]
                   [new-text (string-append padding-spaces trimmed-text)]
                   [new-sgr-list (append padding-sgr-list content-sgr-list)])
              
              ;; Check if the centered line fits within limits
              (let* ([new-metrics (compute-text-metrics-with-sgr new-text 
                                                                 new-sgr-list
                                                                 (cbuf-tab-size cbuf)
                                                                 #:cjk? (cbuf-cjk? cbuf))]
                     [new-width (text-metrics-cell-length new-metrics)])
                
                (if (> (+ home-pos new-width) limit-pos)
                    ;; Content too wide to center properly - just strip whitespace
                    (cbuf-strip-line-whitespace! cbuf)
                    ;; Apply the centered version
                    (begin
                      (cbuf-beginning-of-line! cbuf)
                      (cbuf-delete-to-end-of-line! cbuf)
                      (cbuf-insert-string! cbuf new-text)
                      ;; Position cursor at beginning of content (after padding)
                      (cbuf-beginning-of-line! cbuf)
                      (cbuf-move-to-column! cbuf (+ home-pos left-padding)))))))))))

(define (cbuf-strip-line-whitespace! cbuf)
  "Strip leading and trailing whitespace from current line (no additional undo save)"
  (let* ([current-text (cbuf-text-cur cbuf)]
         [current-sgr-list (cbuf-sgr-list-cur cbuf)]
         [trimmed-text (string-trim current-text)])
    
    (unless (string=? current-text trimmed-text)
      (let* ([trim-left-count (- (string-length current-text)
                                (string-length (string-trim-left current-text)))]
             [trim-right-count (- (string-length current-text)
                                 (string-length (string-trim-right current-text)))]
             [content-start-index trim-left-count]
             [content-end-index (- (string-length current-text) trim-right-count)]
             [content-sgr-list (take (drop current-sgr-list content-start-index)
                                    (- content-end-index content-start-index))])
        
        (cbuf-beginning-of-line! cbuf)
        (cbuf-delete-to-end-of-line! cbuf)
        (cbuf-insert-string! cbuf trimmed-text)
        (cbuf-beginning-of-line! cbuf)))))

;;; =================================================================
;;; SENTENCE NAVIGATION FUNCTIONS
;;; =================================================================

(define (char-sentence-terminator? ch)
  "Check if character is a sentence terminator (.?! plus international)"
  (or (char=? ch #\.)   ; FULL STOP
      (char=? ch #\?)   ; QUESTION MARK  
      (char=? ch #\!)   ; EXCLAMATION MARK
      (char=? ch #\。)  ; IDEOGRAPHIC FULL STOP (CJK)
      (char=? ch #\؟)   ; ARABIC QUESTION MARK
      (char=? ch #\۔)   ; ARABIC FULL STOP
      (char=? ch #\।)   ; DEVANAGARI DANDA
      (char=? ch #\։)   ; ARMENIAN FULL STOP
      (char=? ch #\።)   ; ETHIOPIC FULL STOP
      (char=? ch #\፧)   ; ETHIOPIC QUESTION MARK
      (char=? ch #\᙮)   ; CANADIAN SYLLABICS FULL STOP
      (char=? ch #\‼)   ; DOUBLE EXCLAMATION MARK
      (char=? ch #\⁇)   ; DOUBLE QUESTION MARK
      (char=? ch #\⁈)   ; QUESTION EXCLAMATION MARK
      (char=? ch #\⁉))) ; EXCLAMATION QUESTION MARK

(define (cbuf-find-first-non-whitespace-pos cbuf line-num)
  "Find the position of first non-whitespace character on line.
   Returns x-data position, or #f if line is blank."
  (if (cbuf-line-blank? cbuf line-num)
      #f
      (let* ([text (cbuf-get-line-text cbuf line-num)]
             [first-non-ws-idx (string-skip text char-whitespace?)])
        (if first-non-ws-idx
            (cbuf-x-index->x-data cbuf first-non-ws-idx)
            #f))))

(define (cbuf-line-ends-with-sentence-terminator? cbuf line-num)
  "Check if line ends with sentence terminator followed by optional whitespace.
   Returns the position of the terminator, or #f if not found."
  (if (or (< line-num 0) (>= line-num (cbuf-line-count cbuf)))
      #f
      (let ([text (cbuf-get-line-text cbuf line-num)])
        (if (string-null? text)
            #f
            ;; Find last non-whitespace character
            (let* ([trimmed (string-trim-right text)]
                   [trimmed-len (string-length trimmed)])
              (if (and (> trimmed-len 0)
                       (char-sentence-terminator? (string-ref trimmed (- trimmed-len 1))))
                  ;; Return x-data position of the terminator
                  (cbuf-x-index->x-data cbuf (- trimmed-len 1))
                  #f))))))

(define (cbuf-at-paragraph-beginning? cbuf line-num)
  "Check if line-num is the beginning of a paragraph"
  (= line-num (cbuf-find-paragraph-start cbuf line-num)))

(define (cbuf-at-sentence-beginning? cbuf)
  "Check if cursor is at the beginning of a sentence based on our rules."
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [first-non-ws (cbuf-find-first-non-whitespace-pos cbuf current-line)])
    
    (cond
     ;; Rule 1: First character of paragraph is sentence beginning
     [(and (cbuf-at-paragraph-beginning? cbuf current-line)
           first-non-ws
           (= current-x first-non-ws))
      #t]
     
     ;; Rule 2: Previous line ends with terminator, cursor at first non-blank of current line
     [(and (> current-line 0)
           first-non-ws
           (= current-x first-non-ws)
           (cbuf-line-ends-with-sentence-terminator? cbuf (- current-line 1)))
      #t]
     
     ;; Rule 3: Within line - check for terminator + whitespace + non-whitespace pattern
     [(and first-non-ws (>= current-x first-non-ws))
      (cbuf-at-intraline-sentence-beginning? cbuf current-line current-x)]
     
     [else #f])))

(define (cbuf-at-intraline-sentence-beginning? cbuf line-num x-data)
  "Check if position is at sentence beginning within a line (Rule 3).
   Pattern: {.?!}{whitespace}{non-whitespace} where cursor is at non-whitespace."
  (let* ([text (cbuf-get-line-text cbuf line-num)]
         [current-index (cbuf-x-data->x-index cbuf x-data)])
    
    (if (or (string-null? text) (= current-index 0))
        #f
        ;; Look backward for terminator + whitespace pattern
        (let loop ([i (- current-index 1)])
          (cond
           [(<= i 0) #f]  ; Reached beginning without finding pattern
           
           ;; Found whitespace - continue looking backward
           [(char-whitespace? (string-ref text i))
            (loop (- i 1))]
           
           ;; Found sentence terminator after whitespace
           [(char-sentence-terminator? (string-ref text i))
            ;; Verify there's at least one whitespace between terminator and current pos
            (< i (- current-index 1))]
           
           ;; Found non-whitespace, non-terminator - not a sentence boundary
           [else #f])))))

(define (cbuf-find-next-sentence-start cbuf)
  "Find the next sentence start from current position.
   Returns (line . x-data) or #f if no next sentence found."
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [line-count (cbuf-line-count cbuf)])
    
    ;; First try to find sentence start on current line after current position
    (or (cbuf-find-sentence-start-on-line cbuf current-line (+ current-x 1))
        ;; Then try subsequent lines
        (cbuf-find-sentence-start-on-subsequent-lines cbuf (+ current-line 1)))))

(define (cbuf-find-sentence-start-on-line cbuf line-num start-x-data)
  "Find sentence start on specific line starting from start-x-data.
   Returns (line . x-data) or #f if not found on this line."
  (if (>= line-num (cbuf-line-count cbuf))
      #f
      (let* ([text (cbuf-get-line-text cbuf line-num)]
             [text-len (string-length text)]
             [start-index (cbuf-x-data->x-index cbuf start-x-data)])
        
        (if (>= start-index text-len)
            #f
            ;; Scan for terminator + whitespace + non-whitespace pattern
            (let loop ([i start-index])
              (cond
               [(>= i text-len) #f]
               
               ;; Found sentence terminator
               [(char-sentence-terminator? (string-ref text i))
                ;; Look for whitespace + non-whitespace after terminator
                (let ([sentence-start (cbuf-find-sentence-start-after-terminator text (+ i 1))])
                  (if sentence-start
                      (cons line-num (cbuf-x-index->x-data cbuf sentence-start))
                      (loop (+ i 1))))]
               
               [else (loop (+ i 1))]))))))

(define (cbuf-find-sentence-start-after-terminator text start-index)
  "Find sentence start after terminator: skip whitespace, find non-whitespace.
   Returns string index of first non-whitespace, or #f if not found."
  (let ([text-len (string-length text)])
    (let skip-whitespace ([i start-index])
      (cond
       [(>= i text-len) #f]
       [(char-whitespace? (string-ref text i))
        (skip-whitespace (+ i 1))]
       [else i]))))  ; Found non-whitespace

(define (cbuf-find-sentence-start-on-subsequent-lines cbuf start-line)
  "Find sentence start on lines after start-line.
   Returns (line . x-data) or #f if not found."
  (let ([line-count (cbuf-line-count cbuf)])
    (let loop ([line start-line])
      (cond
       [(>= line line-count) #f]
       
       ;; Check if this line starts a new paragraph (sentence beginning)
       [(cbuf-at-paragraph-beginning? cbuf line)
        (let ([first-non-ws (cbuf-find-first-non-whitespace-pos cbuf line)])
          (if first-non-ws
              (cons line first-non-ws)
              (loop (+ line 1))))]
       
       ;; Check if previous line ended with terminator
       [(and (> line 0)
             (cbuf-line-ends-with-sentence-terminator? cbuf (- line 1)))
        (let ([first-non-ws (cbuf-find-first-non-whitespace-pos cbuf line)])
          (if first-non-ws
              (cons line first-non-ws)
              (loop (+ line 1))))]
       
       ;; Check for intraline sentence starts
       [else
        (or (cbuf-find-sentence-start-on-line cbuf line 0)
            (loop (+ line 1)))]))))

(define (cbuf-find-previous-sentence-start cbuf)
  "Find the previous sentence start from current position.
   Returns (line . x-data) or #f if no previous sentence found."
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)])
    
    ;; If already at sentence beginning, find previous sentence
    (if (cbuf-at-sentence-beginning? cbuf)
        (cbuf-find-actual-previous-sentence cbuf)
        ;; Otherwise find beginning of current sentence
        (cbuf-find-current-sentence-start cbuf))))

(define (cbuf-find-actual-previous-sentence cbuf)
  "Find the actual previous sentence when already at sentence beginning."
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)])
    
    ;; Try current line before current position
    (or (cbuf-find-sentence-start-backward-on-line cbuf current-line 0 (- current-x 1))
        ;; Try previous lines
        (cbuf-find-sentence-start-on-previous-lines cbuf (- current-line 1)))))

(define (cbuf-find-current-sentence-start cbuf)
  "Find the beginning of the current sentence."
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)])
    
    ;; Check if we're at paragraph beginning
    (if (cbuf-at-paragraph-beginning? cbuf current-line)
        (let ([first-non-ws (cbuf-find-first-non-whitespace-pos cbuf current-line)])
          (if first-non-ws
              (cons current-line first-non-ws)
              #f))
        
        ;; Search backward for sentence beginning
        (or (cbuf-find-sentence-start-backward-on-line cbuf current-line 0 current-x)
            (cbuf-find-sentence-start-on-previous-lines cbuf (- current-line 1))))))

(define (cbuf-find-sentence-start-backward-on-line cbuf line-num start-x end-x)
  "Find sentence start on line between start-x and end-x, searching backward.
   Returns (line . x-data) or #f if not found."
  (let* ([text (cbuf-get-line-text cbuf line-num)]
         [start-index (cbuf-x-data->x-index cbuf start-x)]
         [end-index (cbuf-x-data->x-index cbuf end-x)])
    
    ;; Scan backward for sentence boundaries
    (let loop ([i (- end-index 1)])
      (cond
       [(< i start-index) #f]
       
       ;; Check if this position is a sentence start
       [(cbuf-at-intraline-sentence-beginning? cbuf line-num (cbuf-x-index->x-data cbuf i))
        (cons line-num (cbuf-x-index->x-data cbuf i))]
       
       [else (loop (- i 1))]))))

(define (cbuf-find-sentence-start-on-previous-lines cbuf start-line)
  "Find sentence start on lines before start-line, searching backward.
   Returns (line . x-data) or #f if not found."
  (let loop ([line start-line])
    (cond
     [(< line 0) #f]
     
     ;; Check if this line is paragraph beginning
     [(cbuf-at-paragraph-beginning? cbuf line)
      (let ([first-non-ws (cbuf-find-first-non-whitespace-pos cbuf line)])
        (if first-non-ws
            (cons line first-non-ws)
            (loop (- line 1))))]
     
     ;; Check for cross-line sentence boundary
     [(and (> line 0)
           (cbuf-line-ends-with-sentence-terminator? cbuf (- line 1)))
      (let ([first-non-ws (cbuf-find-first-non-whitespace-pos cbuf line)])
        (if first-non-ws
            (cons line first-non-ws)
            (loop (- line 1))))]
     
     ;; Check for intraline sentence starts on this line
     [else
      (let* ([text (cbuf-get-line-text cbuf line)]
             [line-len (cbuf-text-cur-base-length cbuf)])
        (or (cbuf-find-sentence-start-backward-on-line cbuf line 0 line-len)
            (loop (- line 1))))])))

(define (cbuf-forward-sentence! cbuf)
  "Move cursor to the beginning of the next sentence."
  (let ([next-sentence (cbuf-find-next-sentence-start cbuf)])
    (if next-sentence
        (begin
          (cbuf-set-y! cbuf (car next-sentence))
          (cbuf-set-x! cbuf (cdr next-sentence) 'data))
        ;; No next sentence found - go to end of buffer
        (cbuf-end-of-buffer! cbuf))))

(define (cbuf-backward-sentence! cbuf)
  "Move cursor to the beginning of the current or previous sentence."
  (let ([prev-sentence (cbuf-find-previous-sentence-start cbuf)])
    (if prev-sentence
        (begin
          (cbuf-set-y! cbuf (car prev-sentence))
          (cbuf-set-x! cbuf (cdr prev-sentence) 'data))
        ;; No previous sentence found - go to beginning of buffer
        (cbuf-beginning-of-buffer! cbuf))))

;;; =================================================================
;;; PARAGRAPH NAVIGATION
;;; =================================================================

(define (cbuf-line-blank? cbuf line-num)
  "Check if line contains only whitespace characters (blank line).
   Returns #t if line is empty or contains only spaces, tabs, etc."
  (if (and (>= line-num 0) (< line-num (cbuf-line-count cbuf)))
      (let ([text (cbuf-get-line-text cbuf line-num)])
        (or (string-null? text)
            (string-every char-whitespace? text)))
      #t))  ; Treat out-of-bounds as blank

(define (cbuf-find-paragraph-boundary cbuf direction)
  "Find paragraph boundary in given direction from current position.
   DIRECTION: 'forward or 'backward
   Returns line number of paragraph boundary (beginning of next/previous paragraph)."
  (let* ([current-line (cbuf-line-cur cbuf)]
         [line-count (cbuf-line-count cbuf)])
    
    (case direction
      [(forward)
       ;; Find end of current paragraph, then beginning of next
       (let* ([para-end (cbuf-find-paragraph-end cbuf current-line)]
              [next-para-start (cbuf-find-next-paragraph-start cbuf para-end)])
         next-para-start)]
      
      [(backward)  
       ;; Find beginning of current paragraph, then end of previous
       (let* ([para-start (cbuf-find-paragraph-start cbuf current-line)]
              [prev-para-end (cbuf-find-previous-paragraph-end cbuf para-start)])
         prev-para-end)]
      
      [else current-line])))

(define (cbuf-find-paragraph-end cbuf start-line)
  "Find the end of paragraph starting from start-line.
   Returns line number after the last non-blank line of paragraph."
  (let ([line-count (cbuf-line-count cbuf)])
    (cond
     ;; Start beyond buffer
     [(>= start-line line-count) line-count]
     
     ;; Starting on blank line - find next non-blank, then its end
     [(cbuf-line-blank? cbuf start-line)
      (let ([next-non-blank (cbuf-skip-blank-lines cbuf start-line 'forward)])
        (if (>= next-non-blank line-count)
            line-count  ; No more paragraphs
            (cbuf-find-paragraph-end cbuf next-non-blank)))]
     
     ;; Starting on non-blank line - find where non-blanks end
     [else
      (let loop ([line start-line])
        (cond
         ;; Reached end of buffer
         [(>= line line-count) line-count]
         
         ;; Found blank line - end of paragraph
         [(cbuf-line-blank? cbuf line) line]
         
         ;; Still in paragraph, continue
         [else (loop (+ line 1))]))])))

(define (cbuf-find-paragraph-start cbuf start-line)
  "Find the beginning of paragraph containing start-line.
   Returns line number of first non-blank line of paragraph."
  (cond
   ;; Start before buffer
   [(<= start-line 0) 0]
   
   ;; Starting on blank line - find previous non-blank, then its start
   [(cbuf-line-blank? cbuf start-line)
    (let ([prev-non-blank (cbuf-skip-blank-lines cbuf start-line 'backward)])
      (if (< prev-non-blank 0)
          0  ; No previous paragraphs
          (cbuf-find-paragraph-start cbuf prev-non-blank)))]
   
   ;; Starting on non-blank line - find where non-blanks begin
   [else
    (let loop ([line start-line])
      (cond
       ;; Reached beginning of buffer
       [(<= line 0) 0]
       
       ;; Previous line is blank - start of paragraph
       [(cbuf-line-blank? cbuf (- line 1)) line]
       
       ;; Previous line is non-blank, continue backward
       [else (loop (- line 1))]))]))

(define (cbuf-find-next-paragraph-start cbuf start-line)
  "Find the beginning of the next paragraph after start-line.
   Skips blank lines to find next non-blank line."
  (let ([line-count (cbuf-line-count cbuf)])
    (cond
     ;; Start beyond buffer
     [(>= start-line line-count) line-count]
     
     ;; Skip any blank lines, then find first non-blank
     [else
      (let ([next-line (cbuf-skip-blank-lines cbuf start-line 'forward)])
        (min next-line line-count))])))

(define (cbuf-find-previous-paragraph-end cbuf start-line)
  "Find the end of the previous paragraph before start-line.
   Returns line number after last non-blank line of previous paragraph."
  (cond
   ;; Start at or before beginning
   [(<= start-line 0) 0]
   
   ;; Skip backward through blank lines, then find paragraph end
   [else
    (let* ([prev-line (cbuf-skip-blank-lines cbuf (- start-line 1) 'backward)]
           [para-start (if (< prev-line 0) 0 (cbuf-find-paragraph-start cbuf prev-line))])
      para-start)]))

(define (cbuf-skip-blank-lines cbuf start-line direction)
  "Skip blank lines in given direction.
   DIRECTION: 'forward or 'backward
   Returns line number of first non-blank line, or boundary if none found."
  (let ([line-count (cbuf-line-count cbuf)])
    (case direction
      [(forward)
       (let loop ([line start-line])
         (cond
          [(>= line line-count) line-count]
          [(not (cbuf-line-blank? cbuf line)) line]
          [else (loop (+ line 1))]))]
      
      [(backward)
       (let loop ([line start-line])
         (cond
          [(< line 0) -1]
          [(not (cbuf-line-blank? cbuf line)) line]
          [else (loop (- line 1))]))]
      
      [else start-line])))

(define (cbuf-forward-paragraph! cbuf)
  "Move cursor to the beginning of the next paragraph.
   A paragraph is one or more consecutive non-blank lines.
   Paragraphs are separated by blank lines (lines with only whitespace)."
  (let* ([current-line (cbuf-line-cur cbuf)]
         [line-count (cbuf-line-count cbuf)]
         [target-line (cbuf-find-paragraph-boundary cbuf 'forward)])
    
    (cond
     ;; Already at or past end of buffer
     [(>= current-line (- line-count 1))
      (cbuf-end-of-buffer! cbuf)]
     
     ;; Move to target line
     [else
      (cbuf-set-y! cbuf (min target-line (- line-count 1)))
      (cbuf-beginning-of-line! cbuf)])))

(define (cbuf-backward-paragraph! cbuf)
  "Move cursor to the beginning of the current or previous paragraph.
   If already at paragraph beginning, moves to beginning of previous paragraph.
   A paragraph is one or more consecutive non-blank lines."
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)])
    
    (cond
     ;; Already at beginning of buffer
     [(<= current-line 0)
      (cbuf-beginning-of-buffer! cbuf)]
     
     ;; At beginning of line and at paragraph start - go to previous paragraph
     [(and (= current-x 0) 
           (= current-line (cbuf-find-paragraph-start cbuf current-line)))
      (let ([prev-para-start (cbuf-find-paragraph-boundary cbuf 'backward)])
        (cbuf-set-y! cbuf (max 0 prev-para-start))
        (cbuf-beginning-of-line! cbuf))]
     
     ;; Go to beginning of current paragraph
     [else
      (let ([para-start (cbuf-find-paragraph-start cbuf current-line)])
        (cbuf-set-y! cbuf para-start)
        (cbuf-beginning-of-line! cbuf))])))

;;; =================================================================
;;; COLUMN POSITIONING
;;; =================================================================

(define (cbuf-find-base-character-at-cell cbuf target-cell)
  "Find the base character position that corresponds to the target cell position.
   Handles wide characters (CJK) and tabs by finding the base character that 
   'owns' the target cell position."
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [cell-positions (text-metrics-cell-positions metrics)]
         [base-indices (text-metrics-base-indices metrics)]
         [text (cbuf-text-cur cbuf)])
    
    (cond
     ;; Empty line or target beyond line
     [(or (string-null? text) 
          (>= target-cell (text-metrics-cell-length metrics)))
      (cbuf-text-cur-base-length cbuf)]
     
     ;; Target at or before beginning
     [(<= target-cell 0) 0]
     
     ;; Find the base character that owns this cell position
     [else
      (let loop ([base-idx 0])
        (cond
         ;; Reached end of base characters
         [(>= base-idx (length base-indices))
          (cbuf-text-cur-base-length cbuf)]
         
         ;; Get cell position for this base character
         [else
          (let* ([string-idx (list-ref base-indices base-idx)]
                 [char-cell-start (list-ref cell-positions string-idx)]
                 [next-base-idx (+ base-idx 1)]
                 [char-cell-end (if (< next-base-idx (length base-indices))
                                   (list-ref cell-positions (list-ref base-indices next-base-idx))
                                   (text-metrics-cell-length metrics))])
            
            (cond
             ;; Target cell is before this character
             [(< target-cell char-cell-start)
              ;; This shouldn't happen with valid input, but handle gracefully
              base-idx]
             
             ;; Target cell is within this character's range
             [(< target-cell char-cell-end)
              ;; This base character owns the target cell
              base-idx]
             
             ;; Target cell is after this character, continue searching
             [else
              (loop (+ base-idx 1))]))]))])))

(define (cbuf-move-to-column! cbuf target-column)
  "Move cursor to the specified column (cell position).
   If target column is in the middle of a wide character or tab,
   positions cursor at the base character that owns that cell.
   
   TARGET-COLUMN: Zero-based cell position (graphical column)"
  (let* ([current-line (cbuf-line-cur cbuf)]
         [text (cbuf-text-cur cbuf)]
         [line-cell-length (cbuf-text-cur-cell-length cbuf)])
    
    (cond
     ;; Empty line - position at beginning
     [(string-null? text)
      (cbuf-set-x! cbuf 0 'data)]
     
     ;; Target beyond line end - position at end
     [(>= target-column line-cell-length)
      (cbuf-set-x! cbuf (cbuf-text-cur-base-length cbuf) 'data)]
     
     ;; Target at or before beginning - position at beginning  
     [(<= target-column 0)
      (cbuf-set-x! cbuf 0 'data)]
     
     ;; Find appropriate base character position
     [else
      (let ([target-x-data (cbuf-find-base-character-at-cell cbuf target-column)])
        (cbuf-set-x! cbuf target-x-data 'data))])))

;;; =================================================================
;;; WORD BOUNDARY NAVIGATION  
;;; =================================================================

(define (cbuf-beginning-of-word! cbuf)
  "Move cursor to the beginning of the current word.
   If already at word beginning, move to beginning of previous word.
   Final position is always at a base character (never combining mark)."
  (let* ([text (cbuf-text-cur cbuf)]
         [current-x (cbuf-x-data cbuf)])
    
    (cond
     ;; Empty line - stay at beginning
     [(string-null? text)
      (cbuf-set-x! cbuf 0 'data)]
     
     ;; Already at beginning of word - find previous word
     [(cbuf-at-word-boundary? cbuf 'beginning)
      (let* ([current-index (cbuf-x-data->x-index cbuf current-x)]
             ;; Skip current word and any preceding delimiters
             [before-current-word (skip-delimiters-backward text (- current-index 1))]
             ;; Find beginning of previous word
             [prev-word-start (if (>= before-current-word 0)
                                 (find-word-begin-backward text before-current-word char-word-delimiter?)
                                 0)]
             ;; Ensure we're at a base character
             [adjusted-index (cbuf-ensure-base-character-index text prev-word-start)]
             [target-x-data (cbuf-x-index->x-data cbuf adjusted-index)])
        (cbuf-set-x! cbuf target-x-data 'data))]
     
     ;; Not at word beginning - find beginning of current word
     [else
      (let ([target-x-data (cbuf-find-word-boundary-backward cbuf)])
        (cbuf-set-x! cbuf target-x-data 'data))])))

(define (cbuf-end-of-word! cbuf)
  "Move cursor to the end of the current word.
   If already at word end, move to end of next word.
   Final position is always at a base character (never combining mark)."
  (let* ([text (cbuf-text-cur cbuf)]
         [current-x (cbuf-x-data cbuf)])
    
    (cond
     ;; Empty line - stay at beginning  
     [(string-null? text)
      (cbuf-set-x! cbuf 0 'data)]
     
     ;; Already at end of word - find next word end
     [(cbuf-at-word-boundary? cbuf 'end)
      (let* ([current-index (cbuf-x-data->x-index cbuf current-x)]
             ;; Skip current delimiters to find next word
             [next-word-start (skip-delimiters-forward text current-index)]
             ;; Find end of next word
             [next-word-end (if (< next-word-start (string-length text))
                               (find-word-end-forward text next-word-start char-word-delimiter?)
                               (string-length text))]
             ;; Ensure we're at a base character (or valid end position)
             [adjusted-index (cbuf-ensure-base-character-index text next-word-end)]
             [target-x-data (cbuf-x-index->x-data cbuf adjusted-index)])
        (cbuf-set-x! cbuf target-x-data 'data))]
     
     ;; Not at word end - find end of current word
     [else
      (let ([target-x-data (cbuf-find-word-boundary-forward cbuf)])
        (cbuf-set-x! cbuf target-x-data 'data))])))
    
;;; =================================================================
;;; UNDO REGISTRATION
;;; =================================================================
(define (cbuf-register-extra-undo-operations!)
  "Register all extra undo operations with the plugin system"
  
  ;; Line formatting operations
  (cbuf-register-undo-operation! 'center-line
                                  capture-line-formatting-state
                                  restore-line-formatting-state)
  ;; Case conversion operations
  (cbuf-register-undo-operation! 'upcase-region
                                  capture-region-transformation-state
                                  restore-region-transformation-state)
  (cbuf-register-undo-operation! 'downcase-region
                                  capture-region-transformation-state
                                  restore-region-transformation-state)
  (cbuf-register-undo-operation! 'titlecase-region
                                  capture-region-transformation-state
                                  restore-region-transformation-state)
  ;; Tab conversion operations
  (cbuf-register-undo-operation! 'tabify-buffer
                                  capture-buffer-transformation-state
                                  restore-buffer-transformation-state)
  (cbuf-register-undo-operation! 'untabify-buffer
                                  capture-buffer-transformation-state
                                  restore-buffer-transformation-state)
  (cbuf-register-undo-operation! 'tabify-region
                                  capture-region-transformation-state
                                  restore-region-transformation-state)
  (cbuf-register-undo-operation! 'untabify-region
                                  capture-region-transformation-state
                                  restore-region-transformation-state)
  ;; Line swapping operations
  (cbuf-register-undo-operation! 'swap-lines
                                  capture-line-swapping-state
                                  restore-line-swapping-state)
  ;; Grapheme swapping operations
  (cbuf-register-undo-operation! 'swap-graphemes
                                  capture-grapheme-swapping-state
                                  restore-grapheme-swapping-state)
  ;; Sorting operations
  (cbuf-register-undo-operation! 'sort-lines
                                  capture-sorting-state
                                  restore-sorting-state)
  ;; Indentation alignment operations
  (cbuf-register-undo-operation! 'align-indents
                                  capture-region-transformation-state
                                  restore-region-transformation-state))
;;; =================================================================
;;; MODULE INITIALIZATION
;;; =================================================================
;; Register extra operations when module loads
(cbuf-register-extra-undo-operations!)
