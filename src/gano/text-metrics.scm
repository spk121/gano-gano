;;; Text Metrics Module for GNU Guile - Fully Immutable
;;; Efficient Unicode text rendering and positioning utilities
;;; All operations are purely functional - no mutation of strings or data structures
;;;
;;; Given a string, converts between
;;; * x-index - the string-index, the index of a codepoint of the string
;;; * x-data - the index of a non-combining character in the string
;;; * x-cell - the terminal screen cell. Each non-combining character takes 1 or 2 cells.
;;;
;;; The text-metrics includes a list of <sgr> records, one for each
;;; codepoint in the string, holding its console rendering attributes.
;;; The SGR list must be kept in perfect synchronization with the string
;;; through all operations like insertion, deletion, modification, and undo:
;;; - Each codepoint has exactly one SGR record
;;; - String length must always equal SGR list length
;;; - Combining marks inherit SGR from their base character
;;; - New characters get default SGR unless specified
;;; - Tab expansion preserves original SGR for all expanded cells
;;;
;;; Text is laid out left to right.  Bidirectional text is not
;;; reordered: terminals apply their own bidi handling to the logical
;;; order we send them.

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
  #:export (
	    ;; Enhanced text metrics record type
	    <text-metrics>
	    make-text-metrics
	    text-metrics?
	    compute-text-metrics
	    compute-text-metrics-with-sgr
	    
	    ;; Accessors
	    text-metrics-string
	    text-metrics-sgr-list
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
	    
	    ;; SGR-aware text modification (immutable)
	    text-metrics-insert-char-with-sgr
	    text-metrics-insert-string-with-sgr
	    text-metrics-delete-range
	    text-metrics-replace-range
	    
	    ;; SGR inheritance and propagation (immutable)
	    text-metrics-propagate-sgr
	    text-metrics-inherit-sgr-for-combining
	    text-metrics-default-sgr-for-range
	    
	    ;; Rendering with SGR
	    text-metrics-render-line             ; The string plus the full list of <sgr>
	    text-metrics-render-line-string-only ; just the strings
	    text-metrics-render-line-with-sgr    ; The string split into spans
	    text-metrics-get-rendered-spans))

;;; =================================================================
;;; Text Metrics Record Type
;;; =================================================================

(define-record-type <text-metrics>
  (make-text-metrics string sgr-list base-indices cell-positions tabsize cjk?)
  text-metrics?
  (string text-metrics-string)                     ; original string
  (sgr-list text-metrics-sgr-list)                 ; list of <sgr> records, one per codepoint
  (base-indices text-metrics-base-indices)         ; indices of non-combining chars
  (cell-positions text-metrics-cell-positions)     ; visual cell positions
  (tabsize text-metrics-tabsize)                   ; tab size used
  (cjk? text-metrics-cjk?))                        ; CJK terminal flag

;;; =================================================================
;;; Constructors
;;; =================================================================

(define* (compute-text-metrics str tabsize #:key (cjk? #f))
  "Create a text-metrics record by analyzing STR with given TABSIZE.
   All characters get default SGR attributes.
   Keyword arguments: #:cjk? (default #f) - use CJK width rules for ambiguous characters."
  (let ([default-sgr (make-default-sgr)])
    (compute-text-metrics-with-sgr str (make-list (string-length str) default-sgr) tabsize #:cjk? cjk?)))

(define* (compute-text-metrics-with-sgr str sgr-list tabsize #:key (cjk? #f))
  "Create a text-metrics record with explicit SGR attributes for each character.
   STR and SGR-LIST must have the same length."
  (when (not (= (string-length str) (length sgr-list)))
    (error "String length and SGR list length must match" 
           (string-length str) (length sgr-list)))
  (let ([base-indices '()]
        [cell-positions (compute-cell-positions str tabsize cjk?)])
    
    ;; Find base character indices (non-combining marks)
    (string-for-each-index
     (lambda (i)
       (let ([ch (string-ref str i)])
         (when (not (char-combining-mark? ch))
           (set! base-indices (append base-indices (list i))))))
     str)
    
    (make-text-metrics str sgr-list base-indices cell-positions tabsize cjk?)))

;;; =================================================================
;;; Cell Positions
;;; =================================================================

(define (compute-cell-positions str tabsize cjk?)
  "Return a list of STR-LENGTH + 1 cell positions: the cell where each
   codepoint is drawn, followed by the cell just past the end.
   Combining marks share the cell of their base character; a tab runs to
   the next multiple of TABSIZE."
  (let ([str-len (string-length str)])
    (let loop ([i 0]
               [visual-cursor 0]
               [last-base-position 0]
               [acc '()])
      (if (= i str-len)
          (reverse (cons visual-cursor acc))
          (let ([ch (string-ref str i)])
            (cond
             ;; Combining marks - position at last base character position
             [(char-combining-mark? ch)
              (loop (+ i 1) visual-cursor last-base-position
                    (cons last-base-position acc))]
             ;; Tab character
             [(char=? ch #\tab)
              (let ([next-tab (* tabsize (+ (quotient visual-cursor tabsize) 1))])
                (loop (+ i 1) next-tab visual-cursor (cons visual-cursor acc)))]
             ;; Regular characters (base characters)
             [else
              (let ([char-width (max 0 (wcwidth ch cjk?))])
                (loop (+ i 1) (+ visual-cursor char-width) visual-cursor
                      (cons visual-cursor acc)))]))))))

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
;;; SGR-Aware Text Modification (Fully Immutable)
;;; =================================================================

(define (text-metrics-insert-char-with-sgr metrics index char-new sgr)
  "Insert character with SGR at specified index, return new text-metrics"
  (let* ([str (text-metrics-string metrics)]
         [sgr-list (text-metrics-sgr-list metrics)]
         [new-str (string-insert-char str index char-new)]
         [new-sgr-list (list-insert sgr-list index sgr)])
    (compute-text-metrics-with-sgr new-str new-sgr-list
                                   (text-metrics-tabsize metrics)
                                   #:cjk? (text-metrics-cjk? metrics))))

(define (text-metrics-insert-string-with-sgr metrics index insert-str insert-sgr-list)
  "Insert string with SGR list at specified index, return new text-metrics"
  (when (not (= (string-length insert-str) (length insert-sgr-list)))
    (error "Insert string length and SGR list length must match"))
  (let* ([str (text-metrics-string metrics)]
         [sgr-list (text-metrics-sgr-list metrics)]
         [new-str (string-insert-string str index insert-str)]
         [new-sgr-list (list-insert-multiple sgr-list index insert-sgr-list)])
    (compute-text-metrics-with-sgr new-str new-sgr-list
                                   (text-metrics-tabsize metrics)
                                   #:cjk? (text-metrics-cjk? metrics))))

(define (text-metrics-delete-range metrics start-index end-index)
  "Delete characters and SGR from start-index to end-index, return new text-metrics"
  (let* ([str (text-metrics-string metrics)]
         [sgr-list (text-metrics-sgr-list metrics)]
         [str-len (string-length str)]
         [actual-start (max 0 start-index)]
         [actual-end (min str-len end-index)]
         [new-str (string-delete-range str actual-start actual-end)]
         [new-sgr-list (list-delete-range sgr-list actual-start actual-end)])
    (compute-text-metrics-with-sgr new-str new-sgr-list
                                   (text-metrics-tabsize metrics)
                                   #:cjk? (text-metrics-cjk? metrics))))

(define (text-metrics-replace-range metrics start-index end-index replace-str replace-sgr-list)
  "Replace characters and SGR in range with new string and SGR, return new text-metrics"
  (when (not (= (string-length replace-str) (length replace-sgr-list)))
    (error "Replace string length and SGR list length must match"))
  (let* ([str (text-metrics-string metrics)]
         [sgr-list (text-metrics-sgr-list metrics)]
         [str-len (string-length str)]
         [actual-start (max 0 start-index)]
         [actual-end (min str-len end-index)]
         [new-str (string-replace-range str actual-start actual-end replace-str)]
         [new-sgr-list (list-replace-range sgr-list actual-start actual-end replace-sgr-list)])
    (compute-text-metrics-with-sgr new-str new-sgr-list
                                   (text-metrics-tabsize metrics)
                                   #:cjk? (text-metrics-cjk? metrics))))

;;; =================================================================
;;; SGR Inheritance and Propagation (Immutable)
;;; =================================================================

(define (text-metrics-propagate-sgr metrics from-index to-index)
  "Return new text-metrics with SGR copied from one index to another"
  (let ([source-sgr (text-metrics-get-sgr-at-index metrics from-index)])
    (text-metrics-set-sgr-at-index metrics to-index (sgr-copy source-sgr))))

(define (text-metrics-inherit-sgr-for-combining metrics base-index combining-index)
  "Return new text-metrics with combining mark inheriting SGR from base character"
  (text-metrics-propagate-sgr metrics base-index combining-index))

(define (text-metrics-default-sgr-for-range metrics start-index end-index)
  "Return new text-metrics with default SGR for a range of characters"
  (text-metrics-set-sgr-range metrics start-index end-index (make-default-sgr)))

;;; =================================================================
;;; Core Methods
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
;;; SGR-Aware Rendering (Using Immutable String Operations)
;;; =================================================================

(define* (text-metrics-render-line metrics x-cell-start x-width #:key (pad? #t))
  "Return the substring beginning at x-cell-start with x-width cells.
   Returns two values: (values rendered-string sgr-list)
   - rendered-string: The text content with tabs expanded to spaces
   - sgr-list: List of SGR records corresponding to each character in rendered-string
   Keyword arguments: #:pad? (default #t)"
  (let* ([str (text-metrics-string metrics)]
         [sgr-list (text-metrics-sgr-list metrics)]
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
         
         ;; Extract corresponding SGR records for content
         [content-sgr (if (< content-start content-end)
                          (take (drop sgr-list content-start) (- content-end content-start))
                          '())]
         
         ;; Expand tabs in content with proper visual columns
         [expanded-result (expand-tabs-with-sgr content-str content-sgr tabsize)]
         [expanded-content (car expanded-result)]
         [expanded-sgr (cadr expanded-result)]
         
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
         
         ;; Create SGR records for padding (use defaults)
         [default-sgr (make-default-sgr)]
         [left-padding-sgr (make-list left-padding default-sgr)]
         [right-padding-sgr (make-list right-padding default-sgr)]
         
         ;; Combine all parts using immutable string operations
         [final-string (string-join-with (list (string-repeat-char #\space left-padding)
					       expanded-content
					       (string-repeat-char #\space right-padding)) "")]
         [final-sgr-list (append left-padding-sgr
                                 expanded-sgr
                                 right-padding-sgr)])
    
    (values final-string final-sgr-list)))

(define (expand-tabs-with-sgr content-str content-sgr tabsize)
  "Expand tabs to spaces while preserving SGR associations.
   Returns (list expanded-string expanded-sgr-list)"
  (if (string-null? content-str)
      (list "" '())
      (let loop ([i 0]
                 [current-visual-column 0]  ; Track visual position
                 [result-chars '()]
                 [result-sgr '()])
        (if (>= i (string-length content-str))
            ;; Convert result to string and return using immutable operations
            (list (string-from-chars (reverse result-chars))
                  (reverse result-sgr))
            
            ;; Process current character
            (let ([ch (string-ref content-str i)]
                  [ch-sgr (list-ref content-sgr i)])
	      (if (char=? ch #\tab)
                  ;; Tab character - expand to proper number of spaces
                  (let* ([next-tab-stop (* tabsize (+ (quotient current-visual-column tabsize) 1))]
                         [spaces-needed (- next-tab-stop current-visual-column)]
                         [spaces (make-list spaces-needed #\space)]
                         [space-sgrs (make-list spaces-needed ch-sgr)])
                    (loop (+ i 1)
                          next-tab-stop  ; Visual column advances to tab stop
                          (append (reverse spaces) result-chars)
                          (append (reverse space-sgrs) result-sgr)))
                  
                  ;; Regular character - keep as-is and advance visual column
                  (let ([char-width (wcwidth ch #f)])
                    (loop (+ i 1)
                          (+ current-visual-column char-width)
                          (cons ch result-chars)
                          (cons ch-sgr result-sgr)))))))))

(define* (text-metrics-render-line-string-only metrics x-cell-start x-width #:key (pad? #t))
  "Return only the rendered string."
  (let-values ([(rendered-string sgr-list)
                (text-metrics-render-line metrics x-cell-start x-width #:pad? pad?)])
    rendered-string))

(define* (text-metrics-render-line-with-sgr metrics x-cell-start x-width #:key (pad? #t))
  "Render line with SGR attributes, returning list of (string . sgr) spans."
  (let-values ([(rendered-string sgr-list)
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

