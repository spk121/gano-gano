;;; Text Metrics Module for GNU Guile - Fully Immutable with Bidi Support
;;; Efficient Unicode text rendering and positioning utilities
;;; All operations are purely functional - no mutation of strings or data structures
;;;
;;; Given a string, converts between
;;; * x-index - the string-index, the index of a codepoint of the string
;;; * x-data - the index of a non-combining character in the string
;;; * x-cell - the terminal screen cell. Each non-combining character takes 1 or 2 cells.
;;;
;;; The text-metrics includes:
;;; - a list of <sgr> records, one for each codepoint in the string that has the console rendering information
;;; - a list of <bidi-state> records, one for each codepoint tracking bidirectional text state
;;;
;;; The SGR and Bidi State lists must be kept in perfect synchronization with the string 
;;; through all operations like insertion, deletion, modification, and undo.
;;;
;;; Synchronization Rules:
;;; - Each codepoint has exactly one SGR record and one Bidi State record
;;; - String length must always equal SGR list length and Bidi State list length
;;; - Combining marks inherit SGR and Bidi State from their base character
;;; - New characters get default SGR and computed Bidi State unless specified
;;; - Tab expansion preserves original SGR and Bidi State for all expanded cells

(define-module (gano text-metrics)
  #:use-module (srfi srfi-9)        ; record types
  #:use-module (srfi srfi-1)        ; list utilities
  #:use-module (srfi srfi-11)       ; let-values
  #:use-module (gano binary-search) ; binary-search
  #:use-module (gano list-utils)    ; immutable list operations
  #:use-module (gano string-utils)  ; immutable string operations
  #:use-module (gano wcwidth)       ; wcwidth function
  #:use-module (gano char)          ; char-combining-mark? function
  #:use-module (gano rendering)     ; SGR support
  #:use-module (gano uax9-core)     ; Bidirectional text support
  #:export (
	    ;; Enhanced text metrics record type
	    <text-metrics>
	    make-text-metrics
	    text-metrics?
	    compute-text-metrics
	    compute-text-metrics-with-sgr
	    compute-text-metrics-with-sgr-and-bidi
	    
	    ;; Accessors
	    text-metrics-string
	    text-metrics-sgr-list
	    text-metrics-bidi-state-list
	    text-metrics-base-indices
	    text-metrics-cell-positions
	    text-metrics-tabsize
	    text-metrics-cjk?
	    
	    ;; Core functionality
	    text-metrics-string-base
	    text-metrics-string-base-length
	    text-metrics-string-base-indices
	    text-metrics-x-index->x-data
	    text-metrics-x-index->x-cell
	    text-metrics-x-data->x-index
	    text-metrics-x-data->x-cell
	    text-metrics-x-cell->x-index
	    text-metrics-x-cell->x-data
	    text-metrics-cell-length
	    
	    ;; SGR-specific operations (immutable)
	    text-metrics-get-sgr-at-index
	    text-metrics-get-sgr-at-data
	    text-metrics-get-sgr-at-cell
	    text-metrics-set-sgr-at-index
	    text-metrics-set-sgr-at-data
	    text-metrics-set-sgr-range
	    text-metrics-copy-sgr-range
	    
	    ;; Bidi State operations (immutable)
	    text-metrics-get-bidi-state-at-index
	    text-metrics-get-bidi-state-at-data
	    text-metrics-get-bidi-state-at-cell
	    text-metrics-set-bidi-state-at-index
	    text-metrics-set-bidi-state-at-data
	    text-metrics-set-bidi-state-range
	    text-metrics-copy-bidi-state-range
	    text-metrics-recompute-bidi-states
	    
	    ;; SGR and Bidi-aware text modification (immutable)
	    text-metrics-insert-char-with-sgr-and-bidi
	    text-metrics-insert-string-with-sgr-and-bidi
	    text-metrics-delete-range
	    text-metrics-replace-range
	    
	    ;; SGR and Bidi inheritance and propagation (immutable)
	    text-metrics-propagate-sgr
	    text-metrics-propagate-bidi-state
	    text-metrics-inherit-sgr-for-combining
	    text-metrics-inherit-bidi-state-for-combining
	    text-metrics-default-sgr-for-range
	    text-metrics-default-bidi-state-for-range
	    
	    ;; Bidirectional text utilities
	    text-metrics-split-at-bidi-boundary
	    text-metrics-get-paragraph-direction
	    text-metrics-get-resolved-levels
	    text-metrics-is-rtl-at-position
	    
	    ;; Rendering with SGR and Bidi awareness
	    text-metrics-render-line             ; The string plus the full list of <sgr>
	    text-metrics-render-line-string-only ; just the strings
	    text-metrics-render-line-with-sgr    ; The string split into spans
	    text-metrics-get-rendered-spans))

;;; =================================================================
;;; Enhanced Text Metrics Record Type with Bidi Support
;;; =================================================================

;; Enhanced record type definition with SGR and Bidi State support
(define-record-type <text-metrics>
  (make-text-metrics string sgr-list bidi-state-list base-indices cell-positions tabsize cjk?)
  text-metrics?
  (string text-metrics-string)                     ; original string
  (sgr-list text-metrics-sgr-list)                 ; list of <sgr> records, one per codepoint
  (bidi-state-list text-metrics-bidi-state-list)   ; list of <bidi-state> records, one per codepoint
  (base-indices text-metrics-base-indices)         ; indices of non-combining chars
  (cell-positions text-metrics-cell-positions)     ; visual cell positions
  (tabsize text-metrics-tabsize)                   ; tab size used
  (cjk? text-metrics-cjk?))                        ; CJK terminal flag

;;; =================================================================
;;; Enhanced Constructors with Bidi Support
;;; =================================================================

(define* (compute-text-metrics str tabsize #:key (cjk? #f))
  "Create a text-metrics record by analyzing STR with given TABSIZE.
   All characters get default SGR attributes and computed Bidi states.
   Keyword arguments: #:cjk? (default #f) - use CJK width rules for ambiguous characters."
  (let ([default-sgr (make-default-sgr)])
    (compute-text-metrics-with-sgr str (make-list (string-length str) default-sgr) tabsize #:cjk? cjk?)))

(define* (compute-text-metrics-with-sgr str sgr-list tabsize #:key (cjk? #f))
  "Create a text-metrics record with explicit SGR attributes for each character.
   Bidi states are computed automatically.
   STR and SGR-LIST must have the same length."
  (when (not (= (string-length str) (length sgr-list)))
    (error "String length and SGR list length must match" 
           (string-length str) (length sgr-list)))
  
  ;; Compute bidi states for the string
  (let ([bidi-state-list (compute-bidi-state-list str)])
    (compute-text-metrics-with-sgr-and-bidi str sgr-list bidi-state-list tabsize #:cjk? cjk?)))

(define* (compute-text-metrics-with-sgr-and-bidi str sgr-list bidi-state-list tabsize #:key (cjk? #f))
  "Create a text-metrics record with explicit SGR attributes and Bidi states for each character.
   STR, SGR-LIST, and BIDI-STATE-LIST must all have the same length."
  (let ([str-len (string-length str)])
    (when (not (= str-len (length sgr-list)))
      (error "String length and SGR list length must match" str-len (length sgr-list)))
    (when (not (= str-len (length bidi-state-list)))
      (error "String length and Bidi state list length must match" str-len (length bidi-state-list))))
  
  (let ([base-indices '()]
        [cell-positions (compute-bidi-aware-cell-positions-two-pass str tabsize cjk?)])
    
    ;; Find base character indices (non-combining marks)
    (string-for-each-index
     (lambda (i)
       (let ([ch (string-ref str i)])
         (when (not (char-combining-mark? ch))
           (set! base-indices (append base-indices (list i))))))
     str)
    
    (make-text-metrics str sgr-list bidi-state-list base-indices cell-positions tabsize cjk?)))

(define (find-bidi-runs levels)
  "Find contiguous runs of characters with the same embedding level.
   Returns list of (start-index end-index level) tuples."
  (if (null? levels)
      '()
      (let loop ([i 0]
                 [current-level (car levels)]
                 [run-start 0]
                 [runs '()])
        (cond
         ;; End of list - add final run
         [(>= i (length levels))
          (reverse (cons (list run-start i current-level) runs))]
         
         ;; Level changed - end current run and start new one
         [(not (= (list-ref levels i) current-level))
          (let ([new-level (list-ref levels i)])
            (loop (+ i 1) new-level i 
                  (cons (list run-start i current-level) runs)))]
         
         ;; Same level - continue current run
         [else (loop (+ i 1) current-level run-start runs)]))))


;; Bidi reordering algorithm (simplified L2 rule implementation)
(define (reorder-runs-by-level runs max-level)
  "Reorder runs according to UAX#9 L2 rule (simplified).
   Returns list of original run indices in visual order."
  
  (let ([run-indices (iota (length runs))])
    ;; Apply L2 rule: reverse runs at each level from max down to 1
    (let loop ([level max-level]
               [indices run-indices])
      (if (<= level 0)
          indices
          (let ([reordered (reverse-runs-at-level runs indices level)])
            (loop (- level 1) reordered))))))

(define (reverse-runs-at-level runs indices level)
  "Reverse contiguous runs at specified level."
  (let loop ([remaining indices]
             [result '()]
             [current-sequence '()])
    
    (cond
     ;; End of list - process final sequence
     [(null? remaining)
      (if (null? current-sequence)
          (reverse result)
          (append (reverse result) (reverse current-sequence)))]
     
     ;; Check if current run is at target level
     [else
      (let* ([run-index (car remaining)]
             [run (list-ref runs run-index)]
             [run-level (caddr run)])
        
        (cond
         ;; Run is at target level - add to current sequence
         [(>= run-level level)
          (loop (cdr remaining) result (cons run-index current-sequence))]
         
         ;; Run is below target level - emit sequence and continue
         [else
          (let ([new-result (if (null? current-sequence)
                               result
                               (append (reverse result) (reverse current-sequence)))])
            (loop (cdr remaining) (append new-result (list run-index)) '()))]))])))


(define (find-next-grapheme-boundary str start-idx)
  "Find the end index of the grapheme cluster starting at start-idx.
   A grapheme is a base character followed by up to 4 combining marks."
  (if (>= start-idx (string-length str))
      start-idx
      (let ([base-char (string-ref str start-idx)])
        (if (char-combining-mark? base-char)
            ;; If we start on a combining mark, just return next position
            (+ start-idx 1)
            ;; Base character - look for following combining marks
            (let loop ([i (+ start-idx 1)]
                       [combining-count 0])
              (cond
               ;; End of string
               [(>= i (string-length str)) i]
               ;; Hit maximum combining marks (4)
               [(>= combining-count 4) i]
               ;; Next character is not combining mark
               [(not (char-combining-mark? (string-ref str i))) i]
               ;; Next character is combining mark - continue
               [else (loop (+ i 1) (+ combining-count 1))]))))))


(define (compute-bidi-state-list str)
  "Compute bidi state for each character position in string.
   Returns list of <bidi-state> records using resolved levels."
  (if (string-null? str)
      '()
      (let* ([str-len (string-length str)]
             [resolved-levels (resolve-paragraph-bidi str)])
        ;; Create bidi-state records using the resolved levels
        (map (lambda (i level)
               ;; Use the resolved level, with neutral override and no isolate
               ;; (This is simplified - you might want more sophisticated state tracking)
               (make-bidi-state level 'neutral 'none))
             (iota str-len)
             resolved-levels))))

;;; =================================================================
;;; SGR Access and Manipulation (Immutable)
;;; =================================================================

(define (text-metrics-get-sgr-at-index metrics index)
  "Get SGR at string index"
  (let ([sgr-list (text-metrics-sgr-list metrics)])
    (if (and (>= index 0) (< index (length sgr-list)))
        (list-ref sgr-list index)
        (make-default-sgr))))

(define (text-metrics-get-sgr-at-data metrics data-pos)
  "Get SGR at data position (base character)"
  (let ([index (text-metrics-x-data->x-index metrics data-pos)])
    (if index
        (text-metrics-get-sgr-at-index metrics index)
        (make-default-sgr))))

(define (text-metrics-get-sgr-at-cell metrics cell-pos)
  "Get SGR at cell position"
  (let ([index (text-metrics-x-cell->x-index metrics cell-pos)])
    (if index
        (text-metrics-get-sgr-at-index metrics index)
        (make-default-sgr))))

(define (text-metrics-set-sgr-at-index metrics index sgr)
  "Return new text-metrics with SGR updated at string index"
  (let* ([old-sgr-list (text-metrics-sgr-list metrics)]
         [str-len (string-length (text-metrics-string metrics))])
    (if (and (>= index 0) (< index str-len))
        (let ([new-sgr-list (list-update old-sgr-list index sgr)])
          (make-text-metrics (text-metrics-string metrics)
                             new-sgr-list
                             (text-metrics-bidi-state-list metrics)
                             (text-metrics-base-indices metrics)
                             (text-metrics-cell-positions metrics)
                             (text-metrics-tabsize metrics)
                             (text-metrics-cjk? metrics)))
        metrics))) ; Return unchanged if index invalid

(define (text-metrics-set-sgr-at-data metrics data-pos sgr)
  "Return new text-metrics with SGR updated at data position"
  (let ([index (text-metrics-x-data->x-index metrics data-pos)])
    (if index
        (text-metrics-set-sgr-at-index metrics index sgr)
        metrics)))

(define (text-metrics-set-sgr-range metrics start-index end-index sgr)
  "Return new text-metrics with SGR set for a range of string indices"
  (let* ([sgr-list (text-metrics-sgr-list metrics)]
         [str-len (string-length (text-metrics-string metrics))]
         [actual-start (max 0 start-index)]
         [actual-end (min str-len end-index)])
    (if (< actual-start actual-end)
        (let ([new-sgr-list 
	       (list-replace-range sgr-list actual-start actual-end
                                   (make-list (- actual-end actual-start) sgr))])
          (make-text-metrics (text-metrics-string metrics)
                             new-sgr-list
                             (text-metrics-bidi-state-list metrics)
                             (text-metrics-base-indices metrics)
                             (text-metrics-cell-positions metrics)
                             (text-metrics-tabsize metrics)
                             (text-metrics-cjk? metrics)))
        metrics)))

(define (text-metrics-copy-sgr-range metrics start-index end-index)
  "Copy SGR attributes for a range of string indices"
  (let ([sgr-list (text-metrics-sgr-list metrics)]
        [str-len (string-length (text-metrics-string metrics))])
    (let ([actual-start (max 0 start-index)]
          [actual-end (min str-len end-index)])
      (map (lambda (i) (sgr-copy (list-ref sgr-list i)))
           (iota (- actual-end actual-start) actual-start)))))

;;; =================================================================
;;; Bidi State Access and Manipulation (Immutable)
;;; =================================================================

(define (text-metrics-get-bidi-state-at-index metrics index)
  "Get Bidi State at string index"
  (let ([bidi-state-list (text-metrics-bidi-state-list metrics)])
    (if (and (>= index 0) (< index (length bidi-state-list)))
        (list-ref bidi-state-list index)
        (make-bidi-state 0 'neutral 'none))))

(define (text-metrics-get-bidi-state-at-data metrics data-pos)
  "Get Bidi State at data position (base character)"
  (let ([index (text-metrics-x-data->x-index metrics data-pos)])
    (if index
        (text-metrics-get-bidi-state-at-index metrics index)
        (make-bidi-state 0 'neutral 'none))))

(define (text-metrics-get-bidi-state-at-cell metrics cell-pos)
  "Get Bidi State at cell position"
  (let ([index (text-metrics-x-cell->x-index metrics cell-pos)])
    (if index
        (text-metrics-get-bidi-state-at-index metrics index)
        (make-bidi-state 0 'neutral 'none))))

(define (text-metrics-set-bidi-state-at-index metrics index bidi-state)
  "Return new text-metrics with Bidi State updated at string index"
  (let* ([old-bidi-state-list (text-metrics-bidi-state-list metrics)]
         [str-len (string-length (text-metrics-string metrics))])
    (if (and (>= index 0) (< index str-len))
        (let ([new-bidi-state-list (list-update old-bidi-state-list index bidi-state)])
          (make-text-metrics (text-metrics-string metrics)
                             (text-metrics-sgr-list metrics)
                             new-bidi-state-list
                             (text-metrics-base-indices metrics)
                             (text-metrics-cell-positions metrics)
                             (text-metrics-tabsize metrics)
                             (text-metrics-cjk? metrics)))
        metrics))) ; Return unchanged if index invalid

(define (text-metrics-set-bidi-state-at-data metrics data-pos bidi-state)
  "Return new text-metrics with Bidi State updated at data position"
  (let ([index (text-metrics-x-data->x-index metrics data-pos)])
    (if index
        (text-metrics-set-bidi-state-at-index metrics index bidi-state)
        metrics)))

(define (text-metrics-set-bidi-state-range metrics start-index end-index bidi-state)
  "Return new text-metrics with Bidi State set for a range of string indices"
  (let* ([bidi-state-list (text-metrics-bidi-state-list metrics)]
         [str-len (string-length (text-metrics-string metrics))]
         [actual-start (max 0 start-index)]
         [actual-end (min str-len end-index)])
    (if (< actual-start actual-end)
        (let ([new-bidi-state-list 
	       (list-replace-range bidi-state-list actual-start actual-end
                                   (make-list (- actual-end actual-start) bidi-state))])
          (make-text-metrics (text-metrics-string metrics)
                             (text-metrics-sgr-list metrics)
                             new-bidi-state-list
                             (text-metrics-base-indices metrics)
                             (text-metrics-cell-positions metrics)
                             (text-metrics-tabsize metrics)
                             (text-metrics-cjk? metrics)))
        metrics)))

(define (text-metrics-copy-bidi-state-range metrics start-index end-index)
  "Copy Bidi State attributes for a range of string indices"
  (let ([bidi-state-list (text-metrics-bidi-state-list metrics)]
        [str-len (string-length (text-metrics-string metrics))])
    (let ([actual-start (max 0 start-index)]
          [actual-end (min str-len end-index)])
      (map (lambda (i) 
             (let ([state (list-ref bidi-state-list i)])
	       (make-bidi-state (bidi-state-embedding-level state)
				(bidi-state-override-status state)
				(bidi-state-isolate-status state))))
           (iota (- actual-end actual-start) actual-start)))))

(define (text-metrics-recompute-bidi-states metrics)
  "Return new text-metrics with recomputed Bidi states for the current string"
  (let* ([str (text-metrics-string metrics)]
         [new-bidi-state-list (compute-bidi-state-list str)])
    (make-text-metrics str
		       (text-metrics-sgr-list metrics)
		       new-bidi-state-list
		       (text-metrics-base-indices metrics)
		       (text-metrics-cell-positions metrics)
		       (text-metrics-tabsize metrics)
		       (text-metrics-cjk? metrics))))

;;; =================================================================
;;; SGR and Bidi-Aware Text Modification (Fully Immutable)
;;; =================================================================

(define (text-metrics-insert-char-with-sgr-and-bidi metrics index char-new sgr bidi-state)
  "Insert character with SGR and Bidi State at specified index, return new text-metrics"
  (let* ([str (text-metrics-string metrics)]
         [sgr-list (text-metrics-sgr-list metrics)]
         [bidi-state-list (text-metrics-bidi-state-list metrics)]
         [new-str (string-insert-char str index char-new)]
         [new-sgr-list (list-insert sgr-list index sgr)]
         [new-bidi-state-list (list-insert bidi-state-list index bidi-state)])
    (compute-text-metrics-with-sgr-and-bidi new-str new-sgr-list new-bidi-state-list
                                            (text-metrics-tabsize metrics)
                                            #:cjk? (text-metrics-cjk? metrics))))

(define (text-metrics-insert-string-with-sgr-and-bidi metrics index insert-str insert-sgr-list insert-bidi-state-list)
  "Insert string with SGR and Bidi State lists at specified index, return new text-metrics"
  (let ([insert-len (string-length insert-str)])
    (when (not (= insert-len (length insert-sgr-list)))
      (error "Insert string length and SGR list length must match"))
    (when (not (= insert-len (length insert-bidi-state-list)))
      (error "Insert string length and Bidi state list length must match")))
  
  (let* ([str (text-metrics-string metrics)]
         [sgr-list (text-metrics-sgr-list metrics)]
         [bidi-state-list (text-metrics-bidi-state-list metrics)]
         [new-str (string-insert-string str index insert-str)]
         [new-sgr-list (list-insert-multiple sgr-list index insert-sgr-list)]
         [new-bidi-state-list (list-insert-multiple bidi-state-list index insert-bidi-state-list)])
    (compute-text-metrics-with-sgr-and-bidi new-str new-sgr-list new-bidi-state-list
                                            (text-metrics-tabsize metrics)
                                            #:cjk? (text-metrics-cjk? metrics))))

(define (text-metrics-delete-range metrics start-index end-index)
  "Delete characters, SGR, and Bidi States from start-index to end-index, return new text-metrics"
  (let* ([str (text-metrics-string metrics)]
         [sgr-list (text-metrics-sgr-list metrics)]
         [bidi-state-list (text-metrics-bidi-state-list metrics)]
         [str-len (string-length str)]
         [actual-start (max 0 start-index)]
         [actual-end (min str-len end-index)]
         [new-str (string-delete-range str actual-start actual-end)]
         [new-sgr-list (list-delete-range sgr-list actual-start actual-end)]
         [new-bidi-state-list (list-delete-range bidi-state-list actual-start actual-end)])
    (compute-text-metrics-with-sgr-and-bidi new-str new-sgr-list new-bidi-state-list
                                            (text-metrics-tabsize metrics)
                                            #:cjk? (text-metrics-cjk? metrics))))

(define (text-metrics-replace-range metrics start-index end-index replace-str replace-sgr-list replace-bidi-state-list)
  "Replace characters, SGR, and Bidi States in range with new string, SGR, and Bidi States, return new text-metrics"
  (let ([replace-len (string-length replace-str)])
    (when (not (= replace-len (length replace-sgr-list)))
      (error "Replace string length and SGR list length must match"))
    (when (not (= replace-len (length replace-bidi-state-list)))
      (error "Replace string length and Bidi state list length must match")))
  
  (let* ([str (text-metrics-string metrics)]
         [sgr-list (text-metrics-sgr-list metrics)]
         [bidi-state-list (text-metrics-bidi-state-list metrics)]
         [str-len (string-length str)]
         [actual-start (max 0 start-index)]
         [actual-end (min str-len end-index)]
         [new-str (string-replace-range str actual-start actual-end replace-str)]
         [new-sgr-list (list-replace-range sgr-list actual-start actual-end replace-sgr-list)]
         [new-bidi-state-list (list-replace-range bidi-state-list actual-start actual-end replace-bidi-state-list)])
    (compute-text-metrics-with-sgr-and-bidi new-str new-sgr-list new-bidi-state-list
                                            (text-metrics-tabsize metrics)
                                            #:cjk? (text-metrics-cjk? metrics))))

;;; =================================================================
;;; SGR and Bidi Inheritance and Propagation (Immutable)
;;; =================================================================

(define (text-metrics-propagate-sgr metrics from-index to-index)
  "Return new text-metrics with SGR copied from one index to another"
  (let ([source-sgr (text-metrics-get-sgr-at-index metrics from-index)])
    (text-metrics-set-sgr-at-index metrics to-index (sgr-copy source-sgr))))

(define (text-metrics-propagate-bidi-state metrics from-index to-index)
  "Return new text-metrics with Bidi State copied from one index to another"
  (let ([source-state (text-metrics-get-bidi-state-at-index metrics from-index)])
    (text-metrics-set-bidi-state-at-index metrics to-index 
                                          (make-bidi-state (bidi-state-embedding-level source-state)
                                                           (bidi-state-override-status source-state)
                                                           (bidi-state-isolate-status source-state)))))

(define (text-metrics-inherit-sgr-for-combining metrics base-index combining-index)
  "Return new text-metrics with combining mark inheriting SGR from base character"
  (text-metrics-propagate-sgr metrics base-index combining-index))

(define (text-metrics-inherit-bidi-state-for-combining metrics base-index combining-index)
  "Return new text-metrics with combining mark inheriting Bidi State from base character"
  (text-metrics-propagate-bidi-state metrics base-index combining-index))

(define (text-metrics-default-sgr-for-range metrics start-index end-index)
  "Return new text-metrics with default SGR for a range of characters"
  (text-metrics-set-sgr-range metrics start-index end-index (make-default-sgr)))

(define (text-metrics-default-bidi-state-for-range metrics start-index end-index)
  "Return new text-metrics with default Bidi State for a range of characters"
  (text-metrics-set-bidi-state-range metrics start-index end-index (make-bidi-state 0 'neutral 'none)))

;;; =================================================================
;;; Bidirectional Text Utilities
;;; =================================================================

(define (text-metrics-split-at-bidi-boundary metrics position)
  "Split text-metrics at a bidirectional boundary near the given position.
   Returns (values first-metrics second-metrics) with proper bidi controls added."
  (let* ([str (text-metrics-string metrics)]
         [sgr-list (text-metrics-sgr-list metrics)]
         [bidi-state-list (text-metrics-bidi-state-list metrics)])
    
    (let-values ([(first-line second-line) (split-line-with-bidi-controls str position)])
      (let* ([first-len (string-length first-line)]
             [second-len (string-length second-line)]
             [first-sgr (if (> first-len 0) 
                            (append (take sgr-list position)
                                    (make-list (- first-len position) (make-default-sgr)))
                            '())]
             [second-sgr (if (> second-len 0)
                             (append (make-list (- second-len (- (string-length str) position)) (make-default-sgr))
                                     (drop sgr-list position))
                             '())]
             [first-bidi (compute-bidi-state-list first-line)]
             [second-bidi (compute-bidi-state-list second-line)])
        
        (values (compute-text-metrics-with-sgr-and-bidi first-line first-sgr first-bidi
							(text-metrics-tabsize metrics)
							#:cjk? (text-metrics-cjk? metrics))
                (compute-text-metrics-with-sgr-and-bidi second-line second-sgr second-bidi
							(text-metrics-tabsize metrics)
							#:cjk? (text-metrics-cjk? metrics)))))))

(define (text-metrics-get-paragraph-direction metrics)
  "Get the base paragraph direction for the text"
  (paragraph-base-direction (text-metrics-string metrics)))

(define (text-metrics-get-resolved-levels metrics)
  "Get the resolved bidi embedding levels for each character"
  (resolve-paragraph-bidi (text-metrics-string metrics)))

(define (text-metrics-is-rtl-at-position metrics index)
  "Check if the character at index is in right-to-left context"
  (let ([bidi-state (text-metrics-get-bidi-state-at-index metrics index)])
    (odd? (bidi-state-embedding-level bidi-state))))

;;; =================================================================
;;; Core Methods (updated for bidi support)
;;; =================================================================

(define (text-metrics-string-base metrics)
  "Returns a string with any combining marks removed."
  (let ([str (text-metrics-string metrics)]
        [base-indices (text-metrics-base-indices metrics)])
    (string-from-chars (map (lambda (i) (string-ref str i)) base-indices))))

(define (text-metrics-string-base-length metrics)
  "Returns the number of base characters, ignoring combining marks."
  (length (text-metrics-base-indices metrics)))

(define (text-metrics-string-base-indices metrics)
  "Returns a list of indices of all non-combining-mark codepoints."
  (text-metrics-base-indices metrics))

(define (text-metrics-x-index->x-data metrics n)
  "Returns the count of base characters in the first N codepoints.
   If N > string length, returns #f.
   If N = 0, returns 0."
  (let ([str (text-metrics-string metrics)]
        [base-indices (text-metrics-base-indices metrics)])
    (cond
     [(> n (string-length str)) #f]
     [(= n 0) 0]
     [else
      ;; Count how many base indices are < n
      (length (filter (lambda (idx) (< idx n)) base-indices))])))

(define (text-metrics-x-index->x-cell metrics n)
  "Returns the character cell location of the Nth codepoint.
   If N > string length, returns #f.
   If N = 0, returns 0."
  (let ([str (text-metrics-string metrics)]
        [cell-positions (text-metrics-cell-positions metrics)])
    (cond
     [(> n (string-length str)) #f]
     [(= n 0) 0]
     [else
      (list-ref cell-positions n)])))

(define (text-metrics-x-data->x-index metrics n)
  "Returns the string index of the Nth base character.
   If N = number of base chars, returns string length.
   If N > number of base chars, returns #f."
  (let ([base-indices (text-metrics-base-indices metrics)]
        [str-len (string-length (text-metrics-string metrics))])
    (cond
     [(= n 0) 0]
     [(> n (length base-indices)) #f]
     [(= n (length base-indices)) str-len]
     [else
      (list-ref base-indices n)])))

(define (text-metrics-x-data->x-cell metrics n)
  "Returns the character cell location of the Nth base character.
   If N = number of base chars, returns end-of-string cell position.
   If N > number of base chars, returns #f."
  (let ([base-count (text-metrics-string-base-length metrics)])
    (cond
     [(> n base-count) #f]
     [(= n base-count) 
      ;; Return end-of-string position
      (last (text-metrics-cell-positions metrics))]
     [else
      (let ([str-index (text-metrics-x-data->x-index metrics n)])
        (text-metrics-x-index->x-cell metrics str-index))])))

(define (text-metrics-x-cell->x-index metrics n)
  "Returns the string index of the first codepoint at cell N.
   Uses binary search for efficiency."
  (let ([cell-positions (text-metrics-cell-positions metrics)]
        [str-len (string-length (text-metrics-string metrics))])
    (let ([result (binary-search-ceiling cell-positions n)])
      (let ([index (car result)])
        (cond
         [(= index str-len) str-len]  ; Past end of string
         [(>= index (length cell-positions)) #f]  ; Beyond valid range
         [else index])))))

(define (text-metrics-x-cell->x-data metrics n)
  "Returns the number of base characters in the first N cells.
   Uses binary search for efficiency."
  (let ([str-index (text-metrics-x-cell->x-index metrics n)])
    (cond
     [(not str-index) #f]
     [else (text-metrics-x-index->x-data metrics str-index)])))

(define (text-metrics-cell-length metrics)
  "Returns the number of cells that the string occupies."
  (last (text-metrics-cell-positions metrics)))

;;; =================================================================
;;; SGR and Bidi-Aware Rendering (Using Immutable String Operations)
;;; =================================================================

(define* (text-metrics-render-line metrics x-cell-start x-width #:key (pad? #t))
  "Return the substring beginning at x-cell-start with x-width cells.
   Returns three values: (values rendered-string sgr-list bidi-state-list)
   - rendered-string: The text content with tabs expanded to spaces
   - sgr-list: List of SGR records corresponding to each character in rendered-string
   - bidi-state-list: List of Bidi State records corresponding to each character
   Keyword arguments: #:pad? (default #t)"
  (let* ([str (text-metrics-string metrics)]
         [sgr-list (text-metrics-sgr-list metrics)]
         [bidi-state-list (text-metrics-bidi-state-list metrics)]
         [cell-positions (text-metrics-cell-positions metrics)]
         [tabsize (text-metrics-tabsize metrics)]
         [x-cell-end (+ x-cell-start x-width)]
         
         ;; Find start and end indices using binary search
         [i-start-result (binary-search-ceiling cell-positions x-cell-start)]
         [i-end-result (binary-search-ceiling cell-positions x-cell-end)]
         [i-start (car i-start-result)]
         [i-end (car i-end-result)]
         
         ;; Calculate padding and content
         [left-padding (if (< i-start (length cell-positions))
                           (max 0 (- (list-ref cell-positions i-start) x-cell-start))
                           0)]
         [content-start (min i-start (string-length str))]
         [content-end (min i-end (string-length str))]
         [content-str (if (< content-start content-end)
                          (substring str content-start content-end)
                          "")]
         
         ;; Extract corresponding SGR and Bidi State records for content
         [content-sgr (if (< content-start content-end)
                          (take (drop sgr-list content-start) (- content-end content-start))
                          '())]
         [content-bidi-state (if (< content-start content-end)
                                 (take (drop bidi-state-list content-start) (- content-end content-start))
                                 '())]
         
         ;; Expand tabs in content with proper visual columns
         [expanded-result (expand-tabs-with-sgr-and-bidi content-str content-sgr content-bidi-state tabsize)]
         [expanded-content (car expanded-result)]
         [expanded-sgr (cadr expanded-result)]
         [expanded-bidi-state (caddr expanded-result)]
         
         ;; Calculate content width and right padding
         [content-width (if (< content-end (length cell-positions))
                            (- (list-ref cell-positions content-end)
			       (list-ref cell-positions content-start))
                            (- (text-metrics-cell-length metrics)
			       (if (< content-start (length cell-positions))
                                   (list-ref cell-positions content-start)
                                   0)))]
         [right-padding (if pad?
                            (max 0 (- x-width left-padding content-width))
                            0)]
         
         ;; Create SGR and Bidi State records for padding (use defaults)
         [default-sgr (make-default-sgr)]
         [default-bidi-state (make-bidi-state 0 'neutral 'none)]
         [left-padding-sgr (make-list left-padding default-sgr)]
         [left-padding-bidi (make-list left-padding default-bidi-state)]
         [right-padding-sgr (make-list right-padding default-sgr)]
         [right-padding-bidi (make-list right-padding default-bidi-state)]
         
         ;; Combine all parts using immutable string operations
         [final-string (string-join-with (list (string-repeat-char #\space left-padding)
					       expanded-content
					       (string-repeat-char #\space right-padding)) "")]
         [final-sgr-list (append left-padding-sgr
                                 expanded-sgr
                                 right-padding-sgr)]
         [final-bidi-state-list (append left-padding-bidi
					expanded-bidi-state
					right-padding-bidi)])
    
    (values final-string final-sgr-list final-bidi-state-list)))

(define (expand-tabs-with-sgr-and-bidi content-str content-sgr content-bidi-state tabsize)
  "Expand tabs to spaces while preserving SGR and Bidi State associations.
   Returns (list expanded-string expanded-sgr-list expanded-bidi-state-list)"
  (if (string-null? content-str)
      (list "" '() '())
      (let loop ([i 0]
                 [current-visual-column 0]  ; Track visual position
                 [result-chars '()]
                 [result-sgr '()]
                 [result-bidi-state '()])
        (if (>= i (string-length content-str))
            ;; Convert result to string and return using immutable operations
            (list (string-from-chars (reverse result-chars))
                  (reverse result-sgr)
                  (reverse result-bidi-state))
            
            ;; Process current character
            (let ([ch (string-ref content-str i)]
                  [ch-sgr (list-ref content-sgr i)]
                  [ch-bidi-state (list-ref content-bidi-state i)])
	      (if (char=? ch #\tab)
                  ;; Tab character - expand to proper number of spaces
                  (let* ([next-tab-stop (* tabsize (+ (quotient current-visual-column tabsize) 1))]
                         [spaces-needed (- next-tab-stop current-visual-column)]
                         [spaces (make-list spaces-needed #\space)]
                         [space-sgrs (make-list spaces-needed ch-sgr)]
                         [space-bidi-states (make-list spaces-needed ch-bidi-state)])
                    (loop (+ i 1)
                          next-tab-stop  ; Visual column advances to tab stop
                          (append (reverse spaces) result-chars)
                          (append (reverse space-sgrs) result-sgr)
                          (append (reverse space-bidi-states) result-bidi-state)))
                  
                  ;; Regular character - keep as-is and advance visual column
                  (let ([char-width (wcwidth ch #f)])
                    (loop (+ i 1)
                          (+ current-visual-column char-width)
                          (cons ch result-chars)
                          (cons ch-sgr result-sgr)
                          (cons ch-bidi-state result-bidi-state)))))))))

(define* (text-metrics-render-line-string-only metrics x-cell-start x-width #:key (pad? #t))
  "Return only the rendered string."
  (let-values ([(rendered-string sgr-list bidi-state-list) 
                (text-metrics-render-line metrics x-cell-start x-width #:pad? pad?)])
    rendered-string))

(define* (text-metrics-render-line-with-sgr metrics x-cell-start x-width #:key (pad? #t))
  "Render line with SGR attributes, returning list of (string . sgr) spans.
   Note: This function focuses on SGR spans and doesn't expose bidi information directly."
  (let-values ([(rendered-string sgr-list bidi-state-list)
                (text-metrics-render-line metrics x-cell-start x-width #:pad? pad?)])
    ;; Group consecutive characters with same SGR into spans
    (if (string-null? rendered-string)
        '()
        (let loop ([i 0]
                   [spans '()]
                   [current-sgr (car sgr-list)]
                   [current-chars '()])
          
          (cond
           [(>= i (string-length rendered-string))
            ;; End of string - build final span
            (if (not (null? current-chars))
                (reverse (cons (cons (string-from-chars (reverse current-chars)) current-sgr) spans))
                (reverse spans))]
           
           [else
            (let ([char (string-ref rendered-string i)]
                  [char-sgr (list-ref sgr-list i)])
	      (cond
	       ;; SGR changed - emit current span and start new one
	       [(not (sgr-equal? current-sgr char-sgr))
                (loop (+ i 1)
		      (if (not (null? current-chars))
                          (cons (cons (string-from-chars (reverse current-chars)) current-sgr) spans)
                          spans)
		      char-sgr
		      (list char))]
	       
	       ;; Same SGR - accumulate character
	       [else
                (loop (+ i 1) spans current-sgr
		      (cons char current-chars))]))])))))

(define (text-metrics-get-rendered-spans metrics)
  "Get all text as list of (string . sgr) spans, optimized by combining adjacent identical SGR"
  (let ([str (text-metrics-string metrics)]
        [sgr-list (text-metrics-sgr-list metrics)])
    
    (if (= (string-length str) 0)
        '()
        (let loop ([i 0]
                   [spans '()]
                   [current-sgr (car sgr-list)]
                   [current-chars '()])  ; Collect chars as list first
          
          (cond
           [(>= i (string-length str))
            ;; End of string - build final span using string-utils
            (if (not (null? current-chars))
                (reverse (cons (cons (string-from-chars (reverse current-chars)) current-sgr) spans))
                (reverse spans))]
           
           [else
            (let ([char (string-ref str i)]
                  [char-sgr (list-ref sgr-list i)])
	      (cond
	       ;; SGR changed - emit current span and start new one
	       [(not (sgr-equal? current-sgr char-sgr))
                (loop (+ i 1)
		      (if (not (null? current-chars))
                          (cons (cons (string-from-chars (reverse current-chars)) current-sgr) spans)
                          spans)
		      char-sgr
		      (list char))]
	       
	       ;; Same SGR - accumulate character
	       [else
                (loop (+ i 1) spans current-sgr
		      (cons char current-chars))]))])))))

;;; =================================================================
;;; Helper Utilities
;;; =================================================================

(define (string-join-with str-list separator)
  "Join list of strings with separator"
  (cond
   [(null? str-list) ""]
   [(null? (cdr str-list)) (car str-list)]
   [else (string-append (car str-list) separator (string-join-with (cdr str-list) separator))]))



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;; Fixed bidirectional control character positioning

;;; Enhanced character type detection for positioning
(define (is-bidi-initiator? char)
  "Check if character is a bidi run initiator"
  (let ([class (char-get-bidi-class char)])
    (member class '(BC-LRE BC-RLE BC-LRO BC-RLO BC-LRI BC-RLI BC-FSI))))

(define (is-bidi-terminator? char)
  "Check if character is a bidi run terminator"
  (let ([class (char-get-bidi-class char)])
    (member class '(BC-PDF BC-PDI))))

(define (is-bidi-control? char)
  "Check if character is any bidi control character"
  (or (is-bidi-initiator? char) (is-bidi-terminator? char)))


;;; Test the RLO case specifically
(define (test-rlo-case)
  "Test the specific RLO case that's failing."
  (let* ([rlo #\x202E]        ; Right-to-Left Override
         [pdf #\x202C]        ; Pop Directional Formatting  
         [test-str (string rlo #\a #\b #\c pdf)])
    
    (pk 'rlo-test-string test-str)
    (pk 'rlo-test-chars (map char->integer (string->list test-str)))
    
    ;; Expected: RLO=0, c=2, b=1, a=0, PDF=3
    ;; The RLO creates an RTL run containing "abc", which gets reversed to "cba"
    ;; So: RLO at 0, c at 1, b at 2, a at 3, but wait...
    ;; Actually: RLO=0 (initiator), "abc" in RTL positions 2,1,0, PDF=3 (terminator)
    
    (pk 'expected-positions '(0 2 1 0 3))
    (debug-positioning test-str)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define* (compute-bidi-aware-cell-positions-two-pass str tabsize cjk?)
  "Two-pass approach: first pass positions controls sequentially, second pass reorders content."
  (if (string-null? str)
      '(0)
      (let* ([str-len (string-length str)]
             [resolved-levels (resolve-paragraph-bidi str)]
             [positions (make-vector (+ str-len 1) 0)])
        
        ;; Pass 1: Position everything sequentially, handling combining marks properly
        (let loop ([i 0]
                   [visual-cursor 0]
                   [last-base-position 0])  ; Track position of last base character
          (when (< i str-len)
            (let ([ch (string-ref str i)])
              (cond
               ;; Bidi controls get positioned where they appear
               [(is-bidi-control? ch)
                (vector-set! positions i visual-cursor)
                (loop (+ i 1) visual-cursor last-base-position)]  ; Controls don't advance cursor
               
               ;; Combining marks - position at last base character position
               [(char-combining-mark? ch)
                (vector-set! positions i last-base-position)
                (loop (+ i 1) visual-cursor last-base-position)]  ; Combining marks don't advance cursor
               
               ;; Tab character
               [(char=? ch #\tab)
                (vector-set! positions i visual-cursor)
                (let ([next-tab (* tabsize (+ (quotient visual-cursor tabsize) 1))])
                  (loop (+ i 1) next-tab visual-cursor))]  ; Tab is new base position
               
               ;; Regular characters (base characters)
               [else
                (let ([char-width (max 0 (wcwidth ch cjk?))])
                  (vector-set! positions i visual-cursor)
                  (loop (+ i 1) (+ visual-cursor char-width) visual-cursor))]))))
        
        ;; Pass 2: Apply bidi reordering to content within runs based on resolved levels
        (let ([runs (find-bidi-runs resolved-levels)])
          (for-each (lambda (run)
                      (let ([start (car run)]
                            [end (cadr run)]
                            [level (caddr run)])
                        (when (odd? level)  ; Only reverse RTL runs (odd levels)
                          (apply-rtl-reordering-to-run str start end positions))))
                    runs))
        
        ;; Set final position - find the rightmost visual position
        (let ([rightmost-pos (find-rightmost-visual-position str positions str-len)])
          (vector-set! positions str-len rightmost-pos))
        
        (vector->list positions))))

(define (apply-rtl-reordering-to-run str start end positions)
  "Apply RTL reordering to content characters within a run, preserving grapheme clusters."
  ;; Collect grapheme clusters and their positions
  (let ([grapheme-clusters '()])
    
    ;; Find grapheme clusters within the run
    (let loop ([i start])
      (when (< i end)
        (let ([ch (string-ref str i)])
          (cond
           ;; Skip bidi controls
           [(is-bidi-control? ch)
            (loop (+ i 1))]
           
           ;; Process grapheme cluster
           [(not (char-combining-mark? ch))  ; Base character
            (let* ([cluster-end (find-next-grapheme-boundary str i)]
                   [cluster-end-in-run (min cluster-end end)]
                   [cluster-positions (iota (- cluster-end-in-run i) i)]
                   [cluster-visual-pos (vector-ref positions i)])
              
              ;; Add this cluster to our list
              (set! grapheme-clusters 
                    (cons (cons cluster-positions cluster-visual-pos) grapheme-clusters))
              
              (loop cluster-end-in-run))]
           
           ;; Combining mark not preceded by base in this run - treat as single char
           [else
            (let ([cluster-visual-pos (vector-ref positions i)])
              (set! grapheme-clusters 
                    (cons (cons (list i) cluster-visual-pos) grapheme-clusters))
              (loop (+ i 1)))]))))
    
    ;; Reverse the order of grapheme clusters (not individual characters)
    (when (not (null? grapheme-clusters))
      (let* ([cluster-infos (reverse grapheme-clusters)]  ; Reverse cluster order
             [visual-positions (map cdr cluster-infos)]
             [reversed-positions (reverse visual-positions)])
        
        
        ;; Apply reversed positions to each cluster
        (for-each (lambda (cluster-positions new-visual)
                    ;; All characters in the grapheme cluster get the same position
                    (for-each (lambda (pos)
                                (vector-set! positions pos new-visual))
                              cluster-positions))
                  (map car cluster-infos) reversed-positions)))))

(define (find-rightmost-visual-position str positions str-len)
  "Find the rightmost visual position after RTL reordering, ignoring combining marks."
  (if (= str-len 0)
      0
      ;; Find the maximum visual position among non-combining characters
      (let ([max-visual-pos 0]
            [char-at-max-pos #f])
        
        ;; Find non-combining character with maximum visual position
        (let loop ([i 0])
          (when (< i str-len)
            (let ([ch (string-ref str i)]
                  [visual-pos (vector-ref positions i)])
              ;; Only consider non-combining, non-control characters for EOL calculation
              (when (and (not (char-combining-mark? ch))
                         (not (is-bidi-control? ch))
                         (>= visual-pos max-visual-pos))
                (set! max-visual-pos visual-pos)
                (set! char-at-max-pos i)))
            (loop (+ i 1))))
        
        ;; Calculate width of the rightmost non-combining character
        (if char-at-max-pos
            (let ([rightmost-char (string-ref str char-at-max-pos)])
              (let ([char-width (cond
                                 [(char=? rightmost-char #\tab) 8]  ; Use default tabsize
                                 [else (max 0 (wcwidth rightmost-char #f))])])
                (+ max-visual-pos char-width)))
            0))))

;;; Test functions for combining mark positioning
(define (test-ltr-combining-mark)
  "Test LTR base with combining mark."
  (let* ([combining-acute #\x0301]  ; Combining acute accent
         [test-str (string #\a combining-acute)])
    
    (pk 'ltr-combining-test test-str)
    (pk 'ltr-combining-chars (map char->integer (string->list test-str)))
    
    ;; Expected: a=0, combining-acute=0, EOL=1
    (pk 'expected-ltr-combining '(0 0 1))
    
    (let ([result (compute-bidi-aware-cell-positions-two-pass test-str 8 #f)])
      (pk 'ltr-combining-result result)
      result)))

(define (test-rtl-combining-mark)
  "Test RTL base with combining mark."
  (let* ([hebrew-alef #\x05d0]      ; Hebrew Alef
         [combining-acute #\x0301]   ; Combining acute accent
         [test-str (string hebrew-alef combining-acute)])
    
    (pk 'rtl-combining-test test-str)
    (pk 'rtl-combining-chars (map char->integer (string->list test-str)))
    
    ;; Expected: alef=0, combining-acute=0, EOL=1
    (pk 'expected-rtl-combining '(0 0 1))
    
    (let ([result (compute-bidi-aware-cell-positions-two-pass test-str 8 #f)])
      (pk 'rtl-combining-result result)
      result)))

;;; Updated test for RTL text EOL positioning
(define (test-rtl-eol-position)
  "Test that EOL position is correct after RTL text."
  (let* ([alef #\x05d0]       ; Hebrew Alef
         [bet #\x05d1]        ; Hebrew Bet  
         [gimel #\x05d2]      ; Hebrew Gimel
         [test-str (string alef bet gimel)])
    
    (pk 'rtl-eol-test-string test-str)
    (pk 'rtl-eol-test-chars (map char->integer (string->list test-str)))
    
    ;; Expected: gimel=0, bet=1, alef=2, EOL=3
    (pk 'expected-rtl-eol '(2 1 0 3))
    
    (let ([result (compute-bidi-aware-cell-positions-two-pass test-str 8 #t)])
      (pk 'rtl-eol-result result)
      result)))
(define (test-rtl-combining-chars)
  "Test RTL text with combining characters to ensure proper positioning."
  (let* ([rlo #\x202E]        ; Right-to-Left Override
         [pdf #\x202C]        ; Pop Directional Formatting
         [alef #\x05d0]       ; Hebrew Alef (base)
         [qamats #\x05b8]     ; Hebrew Qamats (combining mark)
         [dagesh #\x05bc]     ; Hebrew Dagesh (combining mark)
         [bet #\x05d1]        ; Hebrew Bet (base)
         [patah #\x05b7]      ; Hebrew Patah (combining mark)
         ;; Test: RLO + alef+qamats+dagesh + bet+patah + PDF
         [test-str (string rlo alef qamats dagesh bet patah pdf)])
    
    (pk 'combining-test-string test-str)
    (pk 'combining-test-chars (map char->integer (string->list test-str)))
    
    ;; Expected behavior:
    ;; - RLO at position 0
    ;; - RTL content: (alef+qamats+dagesh) and (bet+patah) should be reversed as clusters
    ;; - So: RLO=0, bet+patah=0, alef+qamats+dagesh=2, PDF=4
    ;; - All combining marks should be at same position as their base
    
    (pk 'expected-combining '(0 2 2 2 0 0 4))
    
    (let ([result (compute-bidi-aware-cell-positions-two-pass test-str 8 #t)])
      (pk 'combining-result result)
      result)))

;;; Test function for the specific case
(define (test-complex-bidi-case)
  "Test the ab+LRO+alef+bet+cd+PDF+ef case."
  (let* ([lro #\x202E]        ; Right-to-Left Override
         [pdf #\x202C]        ; Pop Directional Formatting
         [alef #\x05d0]       ; Hebrew Alef
         [bet #\x05d1]        ; Hebrew Bet
         [test-str (string #\a #\b lro alef bet #\c #\d pdf #\e #\f)])
    
    (pk 'complex-test-string test-str)
    (pk 'complex-test-chars (map char->integer (string->list test-str)))
    
    ;; Expected: a=0, b=1, LRO=2, alef=3, bet=2, c=4, d=5, PDF=6, e=6, f=7
    ;; Wait, let me recalculate...
    ;; Sequential: a=0, b=1, LRO=2, alef=2, bet=3, c=4, d=5, PDF=6, e=6, f=7
    ;; RTL reorder within LRO...PDF: bet should come before alef visually
    ;; So: a=0, b=1, LRO=2, bet=2, alef=3, c=4, d=5, PDF=6, e=6, f=7
    (pk 'expected '(0 1 2 3 2 4 5 6 6 7 8))
    
    (let ([result (compute-bidi-aware-cell-positions-two-pass test-str 8 #t)])
      (pk 'complex-result result)
      result)))
