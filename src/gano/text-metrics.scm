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
  #:use-module (gano list-utils)    ; immutable list operations
  #:use-module (gano string-utils)  ; immutable string operations
  #:use-module (gano wcwidth)       ; wcwidth function
  #:use-module (gano char)          ; char-combining-mark? function
  #:use-module (gano rendering)     ; SGR support
  #:use-module (gano uax9-bidi)     ; Bidirectional text support
  #:export (
    ;; Binary search utilities
    binary-search
    binary-search-floor
    binary-search-ceiling
    
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
;;; Binary Search Utilities (unchanged)
;;; =================================================================

(define (binary-search lst value mode)
  "Binary search for VALUE in sorted list LST with specified MODE.
   Returns (index . closest-value) where behavior depends on MODE:
   
   MODE 'floor (or 'leq):
   - index: position of exact match, or closest entry ≤ value, or -1
   - closest-value: the actual value at that position, or #f if index is -1
   - If first entry > value, returns (-1 . #f)
   
   MODE 'ceiling (or 'geq):
   - index: position of exact match, or closest entry ≥ value, or (length lst)
   - closest-value: the actual value at that position, or #f if index is (length lst)"
  
  (let ([len (length lst)])
    (cond
     ;; Empty list
     [(null? lst) 
      (cons (if (eq? mode 'ceiling) 0 -1) #f)]
     
     ;; Single element
     [(= len 1)
      (let ([single-val (car lst)])
        (cond
         [(= single-val value) (cons 0 single-val)]
         [(eq? mode 'floor)
          (if (<= single-val value) (cons 0 single-val) (cons -1 #f))]
         [else ; ceiling mode
          (if (>= single-val value) (cons 0 single-val) (cons 1 #f))]))]
     
     ;; Handle edge cases based on mode
     [(eq? mode 'floor)
      (cond
       [(> (car lst) value) (cons -1 #f)]
       [(<= (last lst) value) (cons (- len 1) (last lst))]
       [else (binary-search-core lst value mode len)])]
     
     [else ; ceiling mode  
      (cond
       [(< (last lst) value) (cons len #f)]
       [(>= (car lst) value) (cons 0 (car lst))]
       [else (binary-search-core lst value mode len)])])))

(define (binary-search-core lst value mode len)
  "Core binary search implementation."
  (let loop ([low 0]
             [high (- len 1)]
             [best-idx (if (eq? mode 'floor) -1 len)]
             [best-val #f])
    
    (if (> low high)
        ;; Search complete - return best match found
        (cons best-idx best-val)
        
        ;; Continue searching
        (let* ([mid (quotient (+ low high) 2)]
               [mid-val (list-ref lst mid)])
          
          (cond
           ;; Exact match found
           [(= mid-val value)
            (cons mid mid-val)]
           
           ;; Mid value is less than target
           [(< mid-val value)
            (if (eq? mode 'floor)
                ;; Floor: this is a candidate, search right
                (loop (+ mid 1) high mid mid-val)
                ;; Ceiling: search right for something ≥ target
                (loop (+ mid 1) high best-idx best-val))]
           
           ;; Mid value is greater than target
           [else
            (if (eq? mode 'floor)
                ;; Floor: search left for something ≤ target
                (loop low (- mid 1) best-idx best-val)
                ;; Ceiling: this is a candidate, search left
                (loop low (- mid 1) mid mid-val))])))))

;; Convenience functions with descriptive names
(define (binary-search-floor lst value)
  "Find largest value ≤ target, or -1 if none exists."
  (binary-search lst value 'floor))

(define (binary-search-ceiling lst value)
  "Find smallest value ≥ target, or (length lst) if none exists."
  (binary-search lst value 'ceiling))

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
        [cell-positions (compute-bidi-aware-cell-positions str tabsize cjk?)])
    
    ;; Find base character indices (non-combining marks)
    (string-for-each-index
     (lambda (i)
       (let ([ch (string-ref str i)])
         (when (not (char-combining-mark? ch))
           (set! base-indices (append base-indices (list i))))))
     str)
    
    (make-text-metrics str sgr-list bidi-state-list base-indices cell-positions tabsize cjk?))

;;; =================================================================
;;; Bidirectional Cell Position Computation
;;; =================================================================

(define* (compute-bidi-aware-cell-positions str tabsize cjk?)
  "Compute visual cell positions for each character considering bidirectional text layout.
   Uses a stack-based algorithm to handle nested bidi runs correctly.
   Returns list of cell positions, one for each character plus final position."
  (if (string-null? str)
      '(0)  ; Empty string has one position at 0
      (let* ([str-len (string-length str)]
             [resolved-levels (resolve-paragraph-bidi str)]
             [base-direction (paragraph-base-direction str)]
             [base-level (if (eq? base-direction 'rtl) 1 0)])
        
        ;; Find bidi runs (contiguous sequences of same embedding level)
        (let ([runs (find-bidi-runs resolved-levels)])
          ;; Compute cell positions using stack-based algorithm
          (compute-cell-positions-for-runs str runs tabsize cjk? base-level)))))

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

(define (compute-cell-positions-for-runs str runs tabsize cjk? base-level)
  "Compute cell positions for bidi runs using stack-based algorithm.
   Handles nested RTL/LTR runs correctly."
  (let ([str-len (string-length str)]
        [positions (make-vector (+ str-len 1) 0)])  ; +1 for final position
    
    ;; Process runs in logical order, but assign positions based on visual order
    (let ([run-infos (compute-run-visual-info str runs tabsize cjk?)])
      ;; Sort runs by visual position for assignment
      (let ([sorted-runs (sort run-infos (lambda (a b) (< (cadddr a) (cadddr b))))])
        ;; Assign positions based on visual order
        (assign-positions-to-runs str sorted-runs positions tabsize cjk?)))
    
    ;; Convert vector to list
    (vector->list positions)))

(define (compute-run-visual-info str runs tabsize cjk?)
  "Compute visual information for each run: (start end level visual-start width).
   Uses stack-based algorithm to handle nested runs."
  (let ([visual-cursor 0]
        [run-stack '()]
        [run-infos '()])
    
    ;; Process runs in embedding level order (deepest first for RTL)
    (let ([level-sorted-runs (sort runs (lambda (a b) 
                                         (let ([level-a (caddr a)]
                                               [level-b (caddr b)])
                                           (> level-a level-b))))])
      
      ;; Group runs by level and process each level
      (let ([level-groups (group-runs-by-level level-sorted-runs)])
        (for-each (lambda (level-group)
                    (let ([level (caar level-group)])
                      (if (odd? level)
                          ;; RTL level - process runs right to left
                          (process-rtl-level-runs str level-group run-infos tabsize cjk?)
                          ;; LTR level - process runs left to right  
                          (process-ltr-level-runs str level-group run-infos tabsize cjk?))))
                  level-groups))
      
      run-infos)))

(define (group-runs-by-level runs)
  "Group runs by their embedding level."
  (let ([groups '()])
    (for-each (lambda (run)
                (let ([level (caddr run)])
                  (let ([existing-group (assoc level groups)])
                    (if existing-group
                        (set-cdr! existing-group (cons run (cdr existing-group)))
                        (set! groups (cons (list level run) groups))))))
              runs)
    ;; Sort groups by level (highest first) and reverse run order within each group
    (map (lambda (group) 
           (cons (car group) (reverse (cdr group))))
         (sort groups (lambda (a b) (> (car a) (car b)))))))

(define (process-ltr-level-runs str runs run-infos tabsize cjk?)
  "Process LTR runs in logical order (left to right)."
  (let ([visual-cursor 0])
    (for-each (lambda (run)
                (let* ([start (car run)]
                       [end (cadr run)]
                       [level (caddr run)]
                       [run-width (compute-run-width str start end tabsize cjk?)])
                  (set! run-infos (cons (list start end level visual-cursor run-width) run-infos))
                  (set! visual-cursor (+ visual-cursor run-width))))
              runs)))

(define (process-rtl-level-runs str runs run-infos tabsize cjk?)
  "Process RTL runs in reverse logical order (right to left)."
  (let* ([total-width (apply + (map (lambda (run)
                                     (compute-run-width str (car run) (cadr run) tabsize cjk?))
                                   runs))]
         [visual-cursor total-width])
    (for-each (lambda (run)
                (let* ([start (car run)]
                       [end (cadr run)]
                       [level (caddr run)]
                       [run-width (compute-run-width str start end tabsize cjk?)])
                  (set! visual-cursor (- visual-cursor run-width))
                  (set! run-infos (cons (list start end level visual-cursor run-width) run-infos))))
              (reverse runs)))) ; Process in reverse order for RTL

(define (compute-run-width str start end tabsize cjk?)
  "Compute the total width in cells for a run of characters."
  (let loop ([i start]
             [width 0])
    (if (>= i end)
        width
        (let ([ch (string-ref str i)])
          (cond
           [(char=? ch #\tab)
            ;; Tab width depends on current position
            (let ([next-tab-stop (* tabsize (+ (quotient width tabsize) 1))])
              (loop (+ i 1) next-tab-stop))]
           [(char-combining-mark? ch)
            ;; Combining marks don't add width
            (loop (+ i 1) width)]
           [else
            ;; Regular character
            (loop (+ i 1) (+ width (wcwidth ch cjk?)))])))))

(define (assign-positions-to-runs str run-infos positions tabsize cjk?)
  "Assign cell positions to characters based on computed run visual positions."
  (for-each (lambda (run-info)
              (let ([start (car run-info)]
                    [end (cadr run-info)]
                    [level (caddr run-info)]
                    [visual-start (cadddr run-info)])
                (if (odd? level)
                    ;; RTL run - assign positions right to left within the run
                    (assign-rtl-run-positions str start end visual-start positions tabsize cjk?)
                    ;; LTR run - assign positions left to right within the run
                    (assign-ltr-run-positions str start end visual-start positions tabsize cjk?))))
            run-infos)
  
  ;; Set final position (after all characters)
  (let ([final-pos (apply max (map (lambda (run-info)
                                    (+ (cadddr run-info) (car (cddddr run-info))))
                                  run-infos))])
    (vector-set! positions (string-length str) final-pos)))

(define (assign-ltr-run-positions str start end visual-start positions tabsize cjk?)
  "Assign positions for an LTR run (left to right)."
  (let loop ([i start]
             [current-pos visual-start])
    (when (< i end)
      (let ([ch (string-ref str i)])
        (vector-set! positions i current-pos)
        (cond
         [(char=? ch #\tab)
          (let ([next-tab-stop (* tabsize (+ (quotient current-pos tabsize) 1))])
            (loop (+ i 1) next-tab-stop))]
         [(char-combining-mark? ch)
          ;; Combining marks stay at same position as base character
          (loop (+ i 1) current-pos)]
         [else
          ;; Regular character
          (loop (+ i 1) (+ current-pos (wcwidth ch cjk?)))])))))

(define (assign-rtl-run-positions str start end visual-start positions tabsize cjk?)
  "Assign positions for an RTL run (right to left)."
  ;; First compute the total width to know where to start from the right
  (let ([run-width (compute-run-width str start end tabsize cjk?)])
    (let loop ([i start]
               [current-pos (+ visual-start run-width)])
      (when (< i end)
        (let ([ch (string-ref str i)])
          (cond
           [(char=? ch #\tab)
            (let ([char-width (- (* tabsize (+ (quotient current-pos tabsize) 1))
                                current-pos)])
              (set! current-pos (- current-pos char-width))
              (vector-set! positions i current-pos)
              (loop (+ i 1) current-pos))]
           [(char-combining-mark? ch)
            ;; Combining marks stay at same position as base character
            (vector-set! positions i current-pos)
            (loop (+ i 1) current-pos)]
           [else
            ;; Regular character
            (let ([char-width (wcwidth ch cjk?)])
              (set! current-pos (- current-pos char-width))
              (vector-set! positions i current-pos)
              (loop (+ i 1) current-pos))]))))))

;;; =================================================================
;;; Simplified Bidi-Aware Algorithm (Alternative Implementation)
;;; =================================================================

(define* (compute-bidi-aware-cell-positions-simple str tabsize cjk?)
  "Simplified bidi-aware cell position computation.
   This is a more straightforward implementation that handles basic bidi cases."
  (if (string-null? str)
      '(0)
      (let* ([str-len (string-length str)]
             [resolved-levels (resolve-paragraph-bidi str)]
             [positions (make-vector (+ str-len 1) 0)])
        
        ;; Process characters in logical order but assign visual positions
        (let ([segments (find-level-segments resolved-levels)])
          (assign-segment-positions str segments positions tabsize cjk?))
        
        (vector->list positions))))

(define (find-level-segments levels)
  "Find contiguous segments of same embedding level.
   Returns list of (start end level) tuples."
  (if (null? levels)
      '()
      (let loop ([i 1]
                 [current-level (car levels)]
                 [segment-start 0]
                 [segments '()])
        (cond
         [(>= i (length levels))
          (reverse (cons (list segment-start i current-level) segments))]
         [(not (= (list-ref levels i) current-level))
          (let ([new-level (list-ref levels i)])
            (loop (+ i 1) new-level i
                  (cons (list segment-start i current-level) segments)))]
         [else (loop (+ i 1) current-level segment-start segments)]))))

(define (assign-segment-positions str segments positions tabsize cjk?)
  "Assign visual positions to segments based on their embedding levels."
  (let ([visual-cursor 0])
    ;; Process segments in order, but reverse RTL segments
    (for-each (lambda (segment)
                (let ([start (car segment)]
                      [end (cadr segment)]
                      [level (caddr segment)])
                  (if (odd? level)
                      ;; RTL segment - compute positions right to left
                      (let ([segment-width (compute-segment-width str start end tabsize cjk?)])
                        (assign-rtl-segment-positions str start end 
                                                     (+ visual-cursor segment-width)
                                                     positions tabsize cjk?)
                        (set! visual-cursor (+ visual-cursor segment-width)))
                      ;; LTR segment - compute positions left to right
                      (begin (assign-ltr-segment-positions str start end visual-cursor 
                                                          positions tabsize cjk?)
                             (set! visual-cursor (+ visual-cursor 
                                                    (compute-segment-width str start end tabsize cjk?)))))))
              segments)
    
    ;; Set final position
    (vector-set! positions (string-length str) visual-cursor)))

(define (compute-segment-width str start end tabsize cjk?)
  "Compute total width of a segment."
  (let loop ([i start] [width 0])
    (if (>= i end)
        width
        (let ([ch (string-ref str i)])
          (cond
           [(char=? ch #\tab)
            (let ([next-tab (* tabsize (+ (quotient width tabsize) 1))])
              (loop (+ i 1) next-tab))]
           [(char-combining-mark? ch)
            (loop (+ i 1) width)]
           [else
            (loop (+ i 1) (+ width (wcwidth ch cjk?)))])))))

(define (assign-ltr-segment-positions str start end visual-start positions tabsize cjk?)
  "Assign positions for LTR segment."
  (let loop ([i start] [pos visual-start])
    (when (< i end)
      (vector-set! positions i pos)
      (let ([ch (string-ref str i)])
        (cond
         [(char=? ch #\tab)
          (let ([next-tab (* tabsize (+ (quotient pos tabsize) 1))])
            (loop (+ i 1) next-tab))]
         [(char-combining-mark? ch)
          (loop (+ i 1) pos)]
         [else
          (loop (+ i 1) (+ pos (wcwidth ch cjk?)))])))))

(define (assign-rtl-segment-positions str start end visual-end positions tabsize cjk?)
  "Assign positions for RTL segment (right to left)."
  (let loop ([i (- end 1)] [pos visual-end])
    (when (>= i start)
      (let ([ch (string-ref str i)])
        (cond
         [(char=? ch #\tab)
          (let ([char-width (- (* tabsize (+ (quotient pos tabsize) 1)) pos)])
            (set! pos (- pos char-width))
            (vector-set! positions i pos)
            (loop (- i 1) pos))]
         [(char-combining-mark? ch)
          (vector-set! positions i pos)
          (loop (- i 1) pos)]
         [else
          (let ([char-width (wcwidth ch cjk?)])
            (set! pos (- pos char-width))
            (vector-set! positions i pos)
            (loop (- i 1) pos))])))))

;;; Use the simplified algorithm by default
(define compute-bidi-aware-cell-positions compute-bidi-aware-cell-positions-simple)

(define (compute-bidi-state-list str)
  "Compute bidi state for each character position in string.
   Returns list of <bidi-state> records."
  (if (string-null? str)
      '()
      (let ([str-len (string-length str)])
        (map (lambda (i)
               (get-bidi-state-at-position str i))
             (iota str-len)))))

(define (compute-bidi-levels str)
  "Compute resolved bidi levels for each character in string.
   Returns list of embedding levels."
  (if (string-null? str)
      '()
      (resolve-paragraph-bidi str)))

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

(define (string-for-each-index proc str)
  "Call PROC with each character index in STR"
  (let loop ([i 0])
    (when (< i (string-length str))
      (proc i)
      (loop (+ i 1)))))

(define (string-join-with str-list separator)
  "Join list of strings with separator"
  (cond
   [(null? str-list) ""]
   [(null? (cdr str-list)) (car str-list)]
   [else (string-append (car str-list) separator (string-join-with (cdr str-list) separator))]))
