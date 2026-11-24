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
  (unless (and (exact-integer? tabsize) (> tabsize 0))
    (error "Tab size must be a positive integer" tabsize))
  (when (not (= (string-length str) (length sgr-list)))
    (error "String length and SGR list length must match" 
           (string-length str) (length sgr-list)))
  (let ([base-indices
         ;; Indices of base (non-combining) characters, in order
         (let loop ([i (- (string-length str) 1)] [acc '()])
           (cond
            [(< i 0) acc]
            [(char-combining-mark? (string-ref str i)) (loop (- i 1) acc)]
            [else (loop (- i 1) (cons i acc))]))]
        [cell-positions (compute-cell-positions str tabsize cjk?)])
    (make-text-metrics str sgr-list base-indices cell-positions tabsize cjk?)))

;;; =================================================================
;;; Cell Positions
;;; =================================================================

(define (char-control? ch)
  "C0 controls (other than tab), DEL and C1 controls.  They have no
   glyph of their own, so they are drawn as a one-cell substitute."
  (let ([n (char->integer ch)])
    (and (not (= n 9))
         (or (< n 32) (= n 127) (<= #x80 n #x9f)))))

(define (char-cells ch column tabsize cjk?)
  "Number of cells CH occupies when it starts at COLUMN."
  (cond
   [(char=? ch #\tab) (- (* tabsize (+ (quotient column tabsize) 1)) column)]
   [(char-control? ch) 1]
   [else (max 0 (wcwidth ch cjk?))]))

(define (compute-cell-positions str tabsize cjk?)
  "Return a list of STR-LENGTH + 1 cell positions: the cell where each
   codepoint is drawn, followed by the cell just past the end.
   A combining mark belongs to its base character's grapheme cluster, so
   it gets the base's position; a spacing mark (Mc) still widens the
   cluster by its own width (nonspacing marks have width 0)."
  (let ([str-len (string-length str)])
    (let loop ([i 0] [column 0] [base-column 0] [acc '()])
      (if (= i str-len)
          (reverse (cons column acc))
          (let ([ch (string-ref str i)])
            (if (char-combining-mark? ch)
                (loop (+ i 1) (+ column (char-cells ch column tabsize cjk?)) base-column
                      (cons base-column acc))
                (loop (+ i 1) (+ column (char-cells ch column tabsize cjk?)) column
                      (cons column acc))))))))

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
  "Copy SGR attributes for a range of string indices (clamped to the
   string; an empty or reversed range gives '())"
  (let* ([sgr-list (text-metrics-sgr-list metrics)]
         [str-len (string-length (text-metrics-string metrics))]
         [actual-start (max 0 start-index)]
         [actual-end (min str-len end-index)])
    (if (< actual-start actual-end)
        (map sgr-copy (take (drop sgr-list actual-start) (- actual-end actual-start)))
        '())))

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
   If N is negative or greater than the string length, returns #f."
  (let ([str (text-metrics-string metrics)]
        [base-indices (text-metrics-base-indices metrics)])
    (cond
     [(or (< n 0) (> n (string-length str))) #f]
     [else (count (lambda (idx) (< idx n)) base-indices)])))

(define (text-metrics-x-index->x-cell metrics n)
  "Returns the cell where the Nth codepoint is drawn; N = string length
   gives the cell just past the end.  Out of range N returns #f."
  (let ([str (text-metrics-string metrics)])
    (cond
     [(or (< n 0) (> n (string-length str))) #f]
     [else (list-ref (text-metrics-cell-positions metrics) n)])))

(define (text-metrics-x-data->x-index metrics n)
  "Returns the string index of the Nth base character.
   Data position 0 is always index 0, the start of the line.
   If N = number of base chars, returns string length.
   If N is negative or greater than that, returns #f."
  (let ([base-indices (text-metrics-base-indices metrics)]
        [str-len (string-length (text-metrics-string metrics))])
    (cond
     [(< n 0) #f]
     [(= n 0) 0]                ; start of line, even before a stray combining mark
     [(> n (length base-indices)) #f]
     [(= n (length base-indices)) str-len]
     [else (list-ref base-indices n)])))

(define (text-metrics-x-data->x-cell metrics n)
  "Returns the cell where the Nth base character is drawn.
   If N = number of base chars, returns the cell just past the end.
   If N is negative or greater than that, returns #f."
  (let ([index (text-metrics-x-data->x-index metrics n)])
    (and index (text-metrics-x-index->x-cell metrics index))))

(define (text-metrics-x-cell->x-index metrics n)
  "Returns the string index of the base character drawn over cell N: a
   cell inside a wide character or a tab maps to that character.  Where
   several base characters start at the same cell (zero-width ones), the
   first is returned.  N = cell length gives the string length; N outside
   0 .. cell length gives #f."
  (let ([str-len (string-length (text-metrics-string metrics))]
        [cell-length (text-metrics-cell-length metrics)]
        [positions (list->vector (text-metrics-cell-positions metrics))])
    (cond
     [(or (< n 0) (> n cell-length)) #f]
     [(= n cell-length) str-len]
     [else
      ;; Last base character starting at or before N, then back up over
      ;; earlier base characters starting at the same cell.
      (let loop ([bases (text-metrics-base-indices metrics)] [best #f])
        (if (or (null? bases) (> (vector-ref positions (car bases)) n))
            (let ([p (vector-ref positions best)])
              (find (lambda (i) (= (vector-ref positions i) p))
                    (text-metrics-base-indices metrics)))
            (loop (cdr bases) (car bases))))])))

(define (text-metrics-x-cell->x-data metrics n)
  "Returns the data position of the base character drawn over cell N
   (see text-metrics-x-cell->x-index), or #f if N is out of range."
  (let ([index (text-metrics-x-cell->x-index metrics n)])
    (and index (text-metrics-x-index->x-data metrics index))))

(define (text-metrics-cell-length metrics)
  "Returns the number of cells that the string occupies."
  (last (text-metrics-cell-positions metrics)))

;;; =================================================================
;;; SGR-Aware Rendering (Using Immutable String Operations)
;;; =================================================================

(define* (text-metrics-render-line metrics x-cell-start x-width #:key (pad? #t))
  "Render the cells X-CELL-START .. X-CELL-START + X-WIDTH - 1 of the line.
   Returns two values: (values rendered-string sgr-list)
   - rendered-string: what to print.  It is built from whole grapheme
     clusters (a base character and its combining marks).  Tabs become
     spaces and control characters become ?.  A cluster cut by either
     edge of the window (a wide character, a tab, a base with spacing
     marks) contributes spaces for the cells that are visible.
   - sgr-list: one SGR per codepoint of rendered-string; the spaces from a
     tab or cut-off cluster carry its base character's SGR, padding gets
     the default SGR.
   With #:pad? #t (the default) the result fills exactly X-WIDTH cells;
   otherwise it stops at the end of the line."
  (let* ([str (text-metrics-string metrics)]
         [str-len (string-length str)]
         [sgrs (list->vector (text-metrics-sgr-list metrics))]
         [positions (list->vector (text-metrics-cell-positions metrics))]
         [tabsize (text-metrics-tabsize metrics)]
         [cjk? (text-metrics-cjk? metrics)]
         [window-start x-cell-start]
         [window-end (+ x-cell-start (max 0 x-width))])
    (define (cluster-end i)
      ;; index after the combining marks following I
      (let loop ([j (+ i 1)])
        (if (and (< j str-len) (char-combining-mark? (string-ref str j)))
            (loop (+ j 1))
            j)))
    (let loop ([i 0]
               [chars '()]               ; reversed output
               [out-sgrs '()])
      (if (= i str-len)
          ;; Pad from the end of the line to the end of the window
          (let* ([end-cell (vector-ref positions str-len)]
                 [pad (if pad?
                          (max 0 (- window-end (max window-start end-cell)))
                          0)])
            (values (string-append (list->string (reverse chars))
                                   (make-string pad #\space))
                    (append (reverse out-sgrs)
                            (make-list pad (make-default-sgr)))))
          (let* ([j (cluster-end i)]
                 [ch (string-ref str i)]
                 [sgr (vector-ref sgrs i)]
                 [start (vector-ref positions i)]
                 [end (if (< j str-len) (vector-ref positions j) (vector-ref positions str-len))]
                 [width (- end start)])
            (cond
             ;; Wholly inside the window (zero-width clusters included
             ;; when they sit inside it)
             [(and (>= start window-start)
                   (if (zero? width) (< start window-end) (<= end window-end)))
              (let* ([base-width (char-cells ch start tabsize cjk?)]
                     [base-chars (cond [(char=? ch #\tab) (make-list base-width #\space)]
                                       [(char-control? ch) (list #\?)]
                                       [else (list ch)])]
                     [mark-indices (iota (- j i 1) (+ i 1))])
                (loop j
                      (append (reverse (map (lambda (k) (string-ref str k)) mark-indices))
                              (reverse base-chars)
                              chars)
                      (append (reverse (map (lambda (k) (vector-ref sgrs k)) mark-indices))
                              (make-list (length base-chars) sgr)
                              out-sgrs)))]
             ;; Partly inside: blank out the visible cells
             [(and (< start window-end) (> end window-start))
              (let ([visible (- (min end window-end) (max start window-start))])
                (loop j
                      (append (make-list visible #\space) chars)
                      (append (make-list visible sgr) out-sgrs)))]
             ;; Outside the window
             [else (loop j chars out-sgrs)]))))))

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

