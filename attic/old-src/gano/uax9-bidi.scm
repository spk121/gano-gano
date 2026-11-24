;;; UAX #9 Unicode Bidirectional Algorithm Implementation for GNU Guile
;;; Based on Unicode Standard Annex #9 Revision 44
;;; Operates on strings and provides bidi state tracking for line splitting

(define-module (gano uax9-bidi)
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-9)        ; Record types
  #:use-module (srfi srfi-11)       ; let-values
  #:use-module (ice-9 regex)        ; Regular expressions
  #:use-module (ice-9 format)       ; more powerful format
  #:use-module (gano char)	    ; Import bidi class functionality
  #:export (
	    ;; Main UAX #9 functions
	    resolve-paragraph-bidi
	    get-bidi-state-at-position
	    split-line-with-bidi-controls
	    resolve-explicit-levels
	    resolve-weak-types
	    get-bracket-type
	    find-bracket-pairs
	    find-all-bracket-pairs
	    validate-bracket-structure
	    bracket-pair-open-pos
	    bracket-pair-close-pos
	    bracket-pair-open-char
	    bracket-pair-close-char

	    ;; <bracket-context>, <open-bracket>, <multi-line-bracket-pair>
	    <bracket-context>
	    make-bracket-context
	    bracket-context?
	    bracket-context-open-brackets
	    bracket-context-line-pairs
	    bracket-context-unclosed-brackets
	    <open-bracket>
	    make-open-bracket
	    open-bracket?
	    open-bracket-char
	    open-bracket-level
	    open-bracket-line-number
	    open-bracket-line-position
	    open-bracket-global-position
	    <multi-line-bracket-pair>
	    make-multi-line-bracket-pair
	    multi-line-bracket-pair?
	    multi-line-bracket-pair-open-bracket
	    multi-line-bracket-pair-close-position
	    multi-line-bracket-pair-close-char
	    multi-line-bracket-pair-close-level
	    multi-line-bracket-pair-spans-lines?
	    
	    ;; Embedding/isolate state tracking
	    <bidi-state>
	    make-bidi-state
	    bidi-state?
	    bidi-state-embedding-level
	    bidi-state-override-status
	    bidi-state-isolate-status
	    
	    ;; Utility functions
	    paragraph-base-direction
	    find-matching-pdi
	    visual-to-logical-order
	    logical-to-visual-order

	    ;; Debug funcs
	    ;; REMOVE ME WHEN STABLE
	    split-line-with-bracket-context
	    categorize-pairs-by-split
	    categorize-unclosed-by-split
	    print-bracket-context
	    find-matching-bracket-position
	    get-bracket-nesting-level
	    find-enclosing-brackets
	    find-bracket-errors-in-document
	    get-bracket-context-for-line
	    print-bidi-analysis
	    ))

;;; =================================================================
;;; Bidi State Record
;;; =================================================================

(define-record-type <bidi-state>
  (make-bidi-state embedding-level override-status isolate-status)
  bidi-state?
  (embedding-level bidi-state-embedding-level)   ; 0-125
  (override-status bidi-state-override-status)   ; neutral, L, R
  (isolate-status bidi-state-isolate-status))    ; none, LRI, RLI, FSI

;;; =================================================================
;;; Paragraph Base Direction (UAX #9 Rule P2-P3)
;;; =================================================================

(define (paragraph-base-direction text)
  "Determine the base direction of a paragraph.
   Returns 'ltr for left-to-right or 'rtl for right-to-left.
   Follows UAX #9 rules P2-P3."
  (let loop ([i 0])
    (cond
     [(>= i (string-length text)) 'ltr]  ; Default to LTR if no strong characters
     [else
      (let* ([char (string-ref text i)]
             [class (char-get-bidi-class char)])
        (cond
         ;; Skip isolate runs (simplified)
         [(member class '(BC-LRI BC-RLI BC-FSI))
          (let ([isolate-end (find-matching-pdi text i)])
            (loop (if isolate-end (+ isolate-end 1) (+ i 1))))]
         
         ;; First strong character determines direction  
         [(eq? class BC-L) 'ltr]
         [(or (eq? class BC-R) (eq? class BC-AL)) 'rtl]
         
         ;; Continue searching
         [else (loop (+ i 1))]))])))

(define (find-matching-pdi text start-pos)
  "Find the matching PDI for an isolate initiator at start-pos"
  (let ([text-length (string-length text)])
    (let loop ([pos (+ start-pos 1)]
               [depth 1])
      (cond
       [(>= pos text-length) #f]  ; No matching PDI found
       [else
        (let ([char (string-char-at text pos)])
          (if char
              (let ([class (char-get-bidi-class char)])
                (cond
                 [(member class '(BC-LRI BC-RLI BC-FSI)) (loop (+ pos 1) (+ depth 1))]
                 [(eq? class BC-PDI)
                  (if (= depth 1)
                      pos  ; Found matching PDI
                      (loop (+ pos 1) (- depth 1)))]
                 [else (loop (+ pos 1) depth)]))
              #f))]))))

(define (find-matching-pdi text start-pos)
  "The PDI codepoint denotes the end of a run that started with
LRI, RLI, or FSI controls. This function returns the position
of a non-nested PDI. The search starts at start-pos, which
should be the location of an LRI, RLI, or FSI control."
  (let ([text-length (string-length text)])
    (let loop ([pos (+ start-pos 1)]
               [depth 1])
      (cond
       [(< pos text-length)
        (let ([char (string-char-at text pos)])
          (cond
           [(char? char)
            (let ([class (char-get-bidi-class char)])
              (cond
               [(member class '(BC-LRI BC-RLI BC-FSI))
		(loop (+ pos 1) (+ depth 1))]
               [(and (eq? class BC-PDI) (> depth 1))
		(loop (+ pos 1) (- depth 1))]
               [(not (eq? class BC-PDI))
		(loop (+ pos 1) depth)]
	       [else 			; Success, found a BC-PDI
		pos]))]
	   [else #f]))]
       [else #f]))))

(define (first-strong-in-isolate text isolate-start)
  "This function searches the text string from isolate-start to
the next non-nested PDI character. If returns the first strong direction
found. For example, if it finds a Latin letter, it will return 'ltr for
left-to-right..
If it finds a Hebrew character, it will return 'rtl for right-to-left.

If no strong character is found, 'ltr is assumed."
  (let ([isolate-end (find-matching-pdi text isolate-start)])
    (cond
     [(not isolate-end) 'ltr]  ; Default if no matching PDI
     [else
      (let loop ([pos (+ isolate-start 1)])
        (cond
         [(< pos isolate-end)
          (let ([char (string-char-at text pos)])
            (cond
             [(char? char)
              (let ([class (char-get-bidi-class char)])
                (cond
                 [(eq? class BC-L) 'ltr]
                 [(or (eq? class BC-R) (eq? class BC-AL)) 'rtl]
                 [(member class '(BC-LRI BC-RLI BC-FSI))
                  ;; Skip nested isolate
                  (let ([nested-end (find-matching-pdi text pos)])
                    (loop (cond
                           [nested-end (+ nested-end 1)]
                           [else (+ pos 1)])))]
                 [else (loop (+ pos 1))]))]
             [else 'ltr]))]  ; char-at returned #f, default to ltr
         [else 'ltr]))])))  ; No strong character found

;;; =================================================================
;;; Explicit Level Resolution (UAX #9 Rules X1-X8)
;;; =================================================================

(define (resolve-explicit-levels text base-level)
  "Resolve explicit embedding levels.
   Returns list of (level . override-status) for each character."
  (let ([text-len (string-length text)]
        [stack (list (cons base-level 'neutral))]  ; (level . override-status)
        [overflow-isolate-count 0]
        [overflow-embedding-count 0]
        [valid-isolate-count 0]
        [result '()])
    
    (let loop ([i 0])
      (if (>= i text-len)
          (reverse result)
	  ;; else
          (let* ([char (string-ref text i)]
                 [class (char-get-bidi-class char)]
                 [current-level (car (car stack))]
                 [current-override (cdr (car stack))])
            
            (case class
              ;; RLE, LRE, RLO, LRO (X2-X5)
              [(BC-RLE BC-LRE BC-RLO BC-LRO)
	       (pk 'charlie)
               (let* ([new-level (if (member class '(BC-RLE BC-RLO))
                                     (+ (* 2 (quotient (+ current-level 1) 2)) 1)  ; Next odd
                                     (+ (* 2 (quotient (+ current-level 2) 2)) 0))] ; Next even
                      [new-override (if (member class '(BC-RLO BC-LRO))
					(if (eq? class 'BC-RLO) 'BC-R 'BC-L)
					'neutral)])
                 (cond
                  [(and (< new-level 126)
                        (< overflow-isolate-count 1)
                        (< overflow-embedding-count 1))
                   (set! stack (cons (cons new-level new-override) stack))
                   (set! result (cons (cons current-level 'BC-BN) result))]
                  [else
                   (set! overflow-embedding-count (+ overflow-embedding-count 1))
                   (set! result (cons (cons current-level 'BC-BN) result))]))]
              
              ;; PDF (X7)
              [(BC-PDF)
	       (pk 'delta overflow-isolate-count overflow-embedding-count current-level stack)
	       (pk 'deltax stack (length stack))
	       (pk 'delta2 (length stack))
	       ;; (pk 'delta3 'cadr (cadr stack) 'cdadr (cdadr stack) 'cdr (cdr stack) 'result result)
               (cond
                [(> overflow-isolate-count 0)
                 (set! result (cons (cons current-level 'BC-BN) result))]
                [(> overflow-embedding-count 0)
                 (set! overflow-embedding-count (- overflow-embedding-count 1))
                 (set! result (cons (cons current-level 'BC-BN) result))]

		;; Check stack has enough element AND the right type
                [(and (> (length stack) 1)
		      (pair? (cadr stack)) ; Ensure 2nd element exists and is a pair
                      (not (member (cdadr stack) '(BC-LRI BC-RLI BC-FSI))))
                 (set! stack (cdr stack))
                 (set! result (cons (cons current-level 'BC-BN) result))]
                [else
		 ;; Could get here with, for example, an isolated PDF, which
		 ;; we treat as boundary neutral and continue.
                 (set! result (cons (cons current-level 'BC-BN) result))])]
              
              ;; LRI, RLI, FSI (X5a-X5c)
              [(BC-LRI BC-RLI BC-FSI)
	       (pk 'echo)
               (let* ([new-level (if (or (eq? class 'BC-RLI)
                                         (and (eq? class 'BC-FSI)
                                              (eq? (first-strong-in-isolate text i) 'rtl)))
                                     (+ (* 2 (quotient (+ current-level 1) 2)) 1)  ; Next odd
                                     (+ (* 2 (quotient (+ current-level 2) 2)) 0))] ; Next even
                      [isolate-info (cons new-level class)])
                 (set! result (cons (cons current-level 'BC-BN) result))
                 (cond
                  [(and (< new-level 126)
                        (< overflow-isolate-count 1)
                        (< overflow-embedding-count 1))
                   (set! valid-isolate-count (+ valid-isolate-count 1))
                   (set! stack (cons isolate-info stack))]
                  [else
                   (set! overflow-isolate-count (+ overflow-isolate-count 1))]))]
              
              ;; PDI (X6a)
              [(BC-PDI)
	       (pk 'foxtrot overflow-isolate-count valid-isolate-count 'stack stack)
               (cond
                [(> overflow-isolate-count 0)
                 (set! overflow-isolate-count (1- overflow-isolate-count))
                 (set! result (cons (cons current-level 'BC-BN) result))]
                [(> valid-isolate-count 0)
                 (set! overflow-embedding-count 0)
                 ;; Pop back to matching isolate initiator
                 (let loop-pop ([stack-temp stack])
                   (cond
                    [(null? stack-temp) (set! stack '())]
                    [(member (cdar stack-temp) '(BC-LRI BC-RLI BC-FSI))
                     (set! stack (cdr stack-temp))
                     (set! valid-isolate-count (1- valid-isolate-count))]
                    [else (loop-pop (cdr stack-temp))]))
                 (set! result (cons (cons current-level 'BC-BN) result))]
                [else
                 (set! result (cons (cons current-level 'BC-BN) result))])]
              
              ;; All other characters (X6)
              [else
               (let ([level (car (car stack))]
                     [override (cdr (car stack))])
		 ;; (pk 'golf 'level level 'override override 'stack stack)
                 (set! result (cons (cons level override) result)))])
            
            (loop (+ i 1)))))))

(define (first-strong-in-isolate text isolate-start)
  "Find first strong character in isolate run for FSI resolution"
  (let ([isolate-end (find-matching-pdi text isolate-start)])
    (if (not isolate-end)
        'ltr  ; Default if no matching PDI
        (let loop ([i (+ isolate-start 1)])
          (cond
           [(>= i isolate-end) 'ltr]  ; No strong character found
           [else
            (let ([class (char-get-bidi-class (string-ref text i))])
              (cond
               [(eq? class BC-L) 'ltr]
               [(or (eq? class BC-R) (eq? class BC-AL)) 'rtl]
               [(member class '(BC-LRI BC-RLI BC-FSI))
                ;; Skip nested isolate
                (let ([nested-end (find-matching-pdi text i)])
                  (loop (if nested-end (+ nested-end 1) (+ i 1))))]
               [else (loop (+ i 1))]))])))))

;;; =================================================================
;;; Weak Type Resolution (UAX #9 Rules W1-W7) - Simplified
;;; =================================================================

(define (resolve-weak-types text explicit-levels base-level)
  "Resolve weak character types. Simplified implementation."
  (let ([text-len (string-length text)]
        [types (map (lambda (char) (char-get-bidi-class char)) (string->list text))])
    
    ;; W1: NSM takes type of preceding character
    (let loop-w1 ([i 1]
                  [result (list (car types))])
      (if (>= i text-len)
          (let ([w1-types (reverse result)])
            ;; W2: EN after AL becomes AN
            (let loop-w2 ([i 0]
                          [result-w2 '()]
                          [last-strong BC-L])
              (if (>= i text-len)
                  (reverse result-w2)
                  (let ([current-type (list-ref w1-types i)])
                    (case current-type
                      [(BC-AL BC-R BC-L) 
                       (loop-w2 (+ i 1) (cons current-type result-w2) current-type)]
                      [(BC-EN)
                       (if (eq? last-strong BC-AL)
                           (loop-w2 (+ i 1) (cons BC-AN result-w2) last-strong)
                           (loop-w2 (+ i 1) (cons current-type result-w2) last-strong))]
                      [else
                       (loop-w2 (+ i 1) (cons current-type result-w2) last-strong)])))))
          
          (let ([current-type (list-ref types i)])
            (if (eq? current-type BC-NSM)
                (loop-w1 (+ i 1) (cons (car result) result))
                (loop-w1 (+ i 1) (cons current-type result))))))))

;;; =================================================================
;;; Bracket Pair Detection and Processing (UAX #9 Rule N0)
;;; =================================================================

(define (get-bracket-type char)
  "Get bracket type: 'open, 'close, or #f if not a bracket"
  (cond
   [(char-opening-bracket? char) 'open]
   [(char-closing-bracket? char) 'close]
   [else #f]))

(define-record-type <bracket-pair>
  (make-bracket-pair open-pos close-pos open-char close-char level)
  bracket-pair?
  (open-pos bracket-pair-open-pos)
  (close-pos bracket-pair-close-pos) 
  (open-char bracket-pair-open-char)
  (close-char bracket-pair-close-char)
  (level bracket-pair-level))

(define (find-bracket-pairs text types levels)
  "Find all bracket pairs in text following UAX #9 rule N0.
   Returns list of <bracket-pair> records."
  (let ([text-len (string-length text)]
        [stack '()]     ; Stack of open brackets: (pos char level)
        [pairs '()]     ; Found pairs
        [errors '()])   ; Track nesting errors
    
    (let loop ([i 0])
      (if (>= i text-len)
          (if (null? errors)
              (reverse pairs)
              ;; Return error information instead
              '())  ; or could return (cons 'errors errors)
          (let* ([char (string-ref text i)]
                 [type (list-ref types i)]
                 [level (list-ref levels i)]
                 [bracket-type (get-bracket-type char)])
            
            (cond
             ;; Opening bracket
             [(eq? bracket-type 'open)
              (set! stack (cons (list i char level) stack))
              (loop (+ i 1))]
             
             ;; Closing bracket
             [(eq? bracket-type 'close)
              (let ([matching-open (find-matching-open-bracket-strict stack char)])
                (if matching-open
                    (let* ([open-info (car matching-open)]
                           [remaining-stack (cdr matching-open)]
                           [open-pos (car open-info)]
                           [open-char (cadr open-info)]
                           [open-level (caddr open-info)])
                      (set! stack remaining-stack)
                      (set! pairs (cons (make-bracket-pair open-pos i open-char char level) pairs))
                      (loop (+ i 1)))
                    ;; No proper match - record error and continue
                    (begin
                      (set! errors (cons (list 'improper-nesting i char) errors))
                      (loop (+ i 1)))))]
             
             ;; Not a bracket
             [else (loop (+ i 1))]))))))

(define (find-matching-open-bracket stack close-char)
  "Find matching open bracket in stack, removing any unmatched brackets.
   Returns (matching-element . remaining-stack) or #f if no match."
  (let ([target-open (char-get-bracket-partner close-char)])
    (if (not target-open)
        #f
        (let loop ([remaining stack]
                   [removed '()])
          (cond
           [(null? remaining) #f]  ; No match found
           [(char=? (cadar remaining) target-open)
            ;; Found match
            (cons (car remaining) (append removed (cdr remaining)))]
           [else
            ;; Continue searching, but remove this unmatched bracket
            (loop (cdr remaining) (cons (car remaining) removed))])))))

(define (find-matching-open-bracket-strict stack close-char)
  "Find matching open bracket in stack, but only if it's the topmost matching bracket.
   Returns (matching-element . remaining-stack) or #f if no proper match."
  (let ([target-open (char-get-bracket-partner close-char)])
    (if (not target-open)
        #f
        ;; Only match if the target is at the top of stack (proper nesting)
        (cond
         [(null? stack) #f]  ; No brackets to match
         [(char=? (cadar stack) target-open)
          ;; Perfect match - top of stack is the right bracket
          (cons (car stack) (cdr stack))]
         [else
          ;; Top of stack is different bracket - improper nesting
          #f]))))

;;; =================================================================
;;; Enhanced Neutral Type Resolution (UAX #9 Rules N0, N1, N2)
;;; =================================================================

(define (resolve-neutral-types text weak-types explicit-levels)
  "Resolve neutral character types with proper bracket pair handling.
   Implements UAX #9 rules N0, N1, and N2."
  (let* ([text-len (string-length text)]
         [levels (map car explicit-levels)]
         [result-types (list->vector weak-types)]  ; Use vector for efficient updates
         [bracket-pairs (find-bracket-pairs text weak-types levels)])
    
    ;; Rule N0: Process bracket pairs
    (for-each (lambda (pair)
                (process-bracket-pair text result-types levels pair))
              bracket-pairs)
    
    ;; Convert back to list for further processing
    (let ([types-after-n0 (vector->list result-types)])
      
      ;; Rules N1 and N2: Process remaining neutrals
      (let loop ([i 0]
                 [result '()])
        (if (>= i text-len)
            (reverse result)
            (let* ([current-type (list-ref types-after-n0 i)]
                   [current-level (list-ref levels i)])
              
              (cond
               ;; Already resolved by N0 or not neutral
               [(not (member current-type '(BC-WS BC-ON BC-S BC-B BC-ES BC-ET BC-CS)))
                (loop (+ i 1) (cons current-type result))]
               
               ;; Rule N1: Neutral between same strong types takes that type
               [else
                (let* ([preceding-strong (find-preceding-strong types-after-n0 levels i)]
                       [following-strong (find-following-strong types-after-n0 levels i)]
                       [resolved-type
                        (cond
                         ;; N1: Same strong type on both sides
                         [(and preceding-strong following-strong
                               (same-strong-type? preceding-strong following-strong))
                          (car preceding-strong)]
                         
                         ;; N2: Use embedding direction
                         [else
                          (if (even? current-level) BC-L BC-R)])])
                  (loop (+ i 1) (cons resolved-type result)))])))))))

(define (process-bracket-pair text types-vector levels pair)
  "Process a single bracket pair according to rule N0"
  (let* ([open-pos (bracket-pair-open-pos pair)]
         [close-pos (bracket-pair-close-pos pair)]
         [pair-level (bracket-pair-level pair)]
         
         ;; Find strong type within the bracket pair
         [internal-strong (find-strong-type-in-range text types-vector levels 
                                                     (+ open-pos 1) close-pos)]
         
         ;; Find embedding direction
         [embedding-direction (if (even? pair-level) BC-L BC-R)])
    
    (when internal-strong
      (let ([strong-direction (car internal-strong)])
        (cond
         ;; Strong type opposes embedding direction
         [(or (and (eq? embedding-direction BC-L) (member strong-direction '(BC-R BC-AL BC-AN)))
              (and (eq? embedding-direction BC-R) (member strong-direction '(BC-L BC-EN))))
          
          ;; Set bracket types to opposite of embedding direction
          (let ([bracket-type (if (eq? embedding-direction BC-L) BC-R BC-L)])
            (vector-set! types-vector open-pos bracket-type)
            (vector-set! types-vector close-pos bracket-type))]
         
         ;; Strong type matches embedding direction - no change needed
         [else #f])))))

(define (find-strong-type-in-range text types-vector levels start end)
  "Find first strong type within a range, respecting isolates and embeddings"
  (let loop ([pos start])
    (cond
     [(< pos end)
      (let ([char (string-char-at text pos)])
        (cond
         [(char? char)
          (let* ([type (vector-ref types-vector pos)]
                 [class (char-get-bidi-class char)])
            (cond
             ;; Skip isolate runs
             [(member class '(BC-LRI BC-RLI BC-FSI))
              (let ([isolate-end (find-matching-pdi text pos)])
                (loop (cond
                       [isolate-end (+ isolate-end 1)]
                       [else (+ pos 1)])))]
             ;; Found strong type
             [(member type '(BC-L BC-R BC-AL BC-EN BC-AN))
              (cons type pos)]
             ;; Continue searching
             [else (loop (+ pos 1))]))]
         [else #f]))]  ; char-at returned #f
     [else #f])))     ; Reached end without finding strong type


(define (find-preceding-strong types levels pos)
  "Given a list of bidi types and a list of bidi levels, this
function start searching backwards in those two lists at the position preceding
POS, and finds the first codepoint with a strong
left-to-right or right-to-left direction.  It returns a
(type . level) pair."
  (let loop ([i (- pos 1)])
    (cond
     [(>= i 0)
      (let ([type (list-ref types i)]
            [level (list-ref levels i)])
        (cond
         [(member type '(BC-L BC-R BC-AL BC-EN BC-AN))
          (cons type level)]
         [else (loop (- i 1))]))]
     [else #f])))

(define (find-following-strong types levels pos)
  "Given a list of bidi types and a list of bidi levels, this
function start searching those two lists at the position following
POS, and finds the first codepoint with a strong
left-to-right or right-to-left direction.  It returns a
(type . level) pair."
  (let ([list-len (length types)])
    (let loop ([i (+ pos 1)])
      (cond
       [(< i list-len)
        (let ([type (list-ref types i)]
              [level (list-ref levels i)])
          (cond
           [(member type '(BC-L BC-R BC-AL BC-EN BC-AN))
            (cons type level)]
           [else (loop (+ i 1))]))]
       [else #f]))))

(define (same-strong-type? strong1 strong2)
  "Check if two strong types are the same for N1 rule purposes"
  (let ([type1 (car strong1)]
        [type2 (car strong2)])
    (or (and (member type1 '(BC-L BC-EN)) (member type2 '(BC-L BC-EN)))
        (and (member type1 '(BC-R BC-AL BC-AN)) (member type2 '(BC-R BC-AL BC-AN))))))

;;; =================================================================
;;; Main Algorithm Implementation
;;; =================================================================

(define (resolve-paragraph-bidi text)
  "Main UAX #9 implementation. Returns list of resolved levels for each character."
  (if (string-null? text)
      '()
      (let* ([base-direction (paragraph-base-direction text)]
             [base-level (if (eq? base-direction 'rtl) 1 0)]
             [explicit-levels (resolve-explicit-levels text base-level)]
             [weak-types (resolve-weak-types text explicit-levels base-level)]
             [final-types (resolve-neutral-types text weak-types explicit-levels)])
        
        ;; Return final embedding levels
        (map (lambda (level-info final-type)
               (let ([level (car level-info)]
                     [override (cdr level-info)])
                 (cond
                  ;; Apply overrides
                  [(eq? override 'BC-L) (if (even? level) level (+ level 1))]
                  [(eq? override 'BC-R) (if (odd? level) level (+ level 1))]
                  ;; For strong types, use character's natural level
                  [(member final-type '(BC-L BC-EN))
                   (if (even? level) level (+ level 1))]
                  [(member final-type '(BC-R BC-AL BC-AN))
                   (if (odd? level) level (+ level 1))]
                  ;; Use embedding level for others
                  [else level])))
             explicit-levels final-types))))

;;; =================================================================
;;; Bidi State Tracking for Line Splitting
;;; =================================================================

(define (get-bidi-state-at-position text position)
  "Get the bidirectional state at a specific position in text.
   Returns <bidi-state> record with embedding level, override status, and isolate status."
  (if (or (< position 0) (> position (string-length text)))
      (make-bidi-state 0 'neutral 'none)
      (let ([stack (list (cons 0 'neutral))]  ; (level . override-status)
            [isolate-stack '()]                ; List of isolate types
            [overflow-isolate-count 0]
            [overflow-embedding-count 0])
        
        (let loop ([i 0])
          (if (>= i position)
              ;; Return current state
              (let* ([current-frame (if (null? stack) (cons 0 'neutral) (car stack))]
                     [level (car current-frame)]
                     [override (cdr current-frame)]
                     [isolate-status (if (null? isolate-stack) 'none (car isolate-stack))])
                (make-bidi-state level override isolate-status))
              
              ;; Process character at position i
              (let* ([char (string-ref text i)]
                     [class (char-get-bidi-class char)]
                     [current-level (if (null? stack) 0 (car (car stack)))])
                
                (case class
                  ;; Embedding/Override initiators
                  [(BC-RLE BC-LRE BC-RLO BC-LRO)
                   (let* ([new-level (if (member class '(BC-RLE BC-RLO))
                                         (+ (* 2 (quotient (+ current-level 1) 2)) 1)
                                         (+ (* 2 (quotient (+ current-level 2) 2)) 0))]
                          [new-override (if (member class '(BC-RLO BC-LRO))
                                            (if (eq? class 'BC-RLO) 'BC-R 'BC-L)
                                            'neutral)])
                     (cond
                      [(and (< new-level 126)
                            (< overflow-isolate-count 1)
                            (< overflow-embedding-count 1))
                       (set! stack (cons (cons new-level new-override) stack))]
                      [else
                       (set! overflow-embedding-count (+ overflow-embedding-count 1))]))]
                  
                  ;; PDF
                  [(BC-PDF)
                   (cond
                    [(> overflow-isolate-count 0) #f]  ; Do nothing
                    [(> overflow-embedding-count 0)
                     (set! overflow-embedding-count (- overflow-embedding-count 1))]
                    [(and (> (length stack) 1)
                          (not (member (cdr (cadr stack)) '(BC-LRI BC-RLI BC-FSI))))
                     (set! stack (cdr stack))])]
                  
                  ;; Isolate initiators
                  [(BC-LRI BC-RLI BC-FSI)
                   (let* ([new-level (if (or (eq? class 'BC-RLI)
                                             (and (eq? class 'BC-FSI)
                                                  (eq? (first-strong-in-isolate text i) 'rtl)))
                                         (+ (* 2 (quotient (+ current-level 1) 2)) 1)
                                         (+ (* 2 (quotient (+ current-level 2) 2)) 0))])
                     (cond
                      [(and (< new-level 126)
                            (< overflow-isolate-count 1)
                            (< overflow-embedding-count 1))
                       (set! stack (cons (cons new-level class) stack))
                       (set! isolate-stack (cons class isolate-stack))]
                      [else
                       (set! overflow-isolate-count (+ overflow-isolate-count 1))]))]
                  
                  ;; PDI
                  [(BC-PDI)
                   (cond
                    [(> overflow-isolate-count 0)
                     (set! overflow-isolate-count (- overflow-isolate-count 1))]
                    [(not (null? isolate-stack))
                     (set! overflow-embedding-count 0)
                     (set! isolate-stack (cdr isolate-stack))
                     ;; Pop back to matching isolate initiator
                     (let loop-pop ([stack-temp stack])
                       (cond
                        [(null? stack-temp) (set! stack '())]
                        [(member (cdr (car stack-temp)) '(BC-LRI BC-RLI BC-FSI))
                         (set! stack (cdr stack-temp))]
                        [else (loop-pop (cdr stack-temp))]))])])
                
                (loop (+ i 1))))))))

(define (split-line-with-bidi-controls text split-position)
  "Split text at position into two strings, adding necessary bidi controls
at the end of the first string and at the beginning of the second string
to maintain state.
   Returns (values first-line second-line)"
  (let ([text-length (string-length text)])
    (cond
     [(<= split-position 0) (values "" text)]
     [(>= split-position text-length) (values text "")]
     [else
      (let* ([state-at-split (get-bidi-state-at-position text split-position)]
             [first-part (substring text 0 split-position)]
             [second-part (substring text split-position)]
             [level (bidi-state-embedding-level state-at-split)]
             [override (bidi-state-override-status state-at-split)]
             [isolate (bidi-state-isolate-status state-at-split)])
        
        ;; Build termination controls for first line
        (let* ([isolate-terminators (cond
                                     [(eq? isolate 'none) '()]
                                     [else '(#\x2069)])]  ; PDI
               [embedding-terminators (cond
                                       [(or (> level 0) (not (eq? override 'neutral)))
                                        '(#\x202C)]  ; PDF
                                       [else '()])]
               [first-terminators (append isolate-terminators embedding-terminators)]
               
               ;; Build restoration controls for second line  
               [embedding-initiators (cond
                                      [(and (> level 0) (eq? override 'BC-L))
				       '(#\x202D)]      ; LRO
                                      [(and (> level 0) (eq? override 'BC-R))
				       '(#\x202E)]      ; RLO
                                      [(and (> level 0) (odd? level) (eq? override 'neutral))
				       '(#\x202B)]  ; RLE
                                      [(and (> level 0) (even? level) (eq? override 'neutral))
				       '(#\x202A)] ; LRE
                                      [else '()])]
               [isolate-initiators (case isolate
                                     [(BC-LRI) '(#\x2066)]   ; LRI
                                     [(BC-RLI) '(#\x2067)]   ; RLI  
                                     [(BC-FSI) '(#\x2068)]   ; FSI
                                     [else '()])]
               [second-initiators (append embedding-initiators isolate-initiators)]
               
               ;; Use string-utils for cleaner string building
               [first-line (cond
                            [(null? first-terminators) first-part]
                            [else (string-append first-part (string-from-chars first-terminators))])]
               [second-line (cond
                             [(null? second-initiators) second-part]
                             [else (string-append (string-from-chars second-initiators) second-part)])])
          
          (values first-line second-line)))])))

;;; =================================================================
;;; Multi-line Bracket State Management
;;; =================================================================

(define-record-type <bracket-context>
  (make-bracket-context open-brackets line-pairs unclosed-brackets)
  bracket-context?
  (open-brackets bracket-context-open-brackets)      ; List of open brackets from previous lines
  (line-pairs bracket-context-line-pairs)            ; Pairs completed within this line
  (unclosed-brackets bracket-context-unclosed-brackets)) ; Brackets opened in this line but not closed

(define-record-type <open-bracket>
  (make-open-bracket char level line-number line-position global-position)
  open-bracket?
  (char open-bracket-char)                    ; The bracket character
  (level open-bracket-level)                  ; Bidi embedding level
  (line-number open-bracket-line-number)      ; Which line it's from (for tracking)
  (line-position open-bracket-line-position)  ; Position within that line
  (global-position open-bracket-global-position)) ; Global position if known

(define-record-type <multi-line-bracket-pair>
  (make-multi-line-bracket-pair open-bracket close-position close-char close-level spans-lines?)
  multi-line-bracket-pair?
  (open-bracket multi-line-bracket-pair-open-bracket)    ; <open-bracket> record
  (close-position multi-line-bracket-pair-close-position) ; Position in current line
  (close-char multi-line-bracket-pair-close-char)        ; Closing character
  (close-level multi-line-bracket-pair-close-level)      ; Closing bidi level
  (spans-lines? multi-line-bracket-pair-spans-lines?))   ; True if crosses line boundaries

;;; =================================================================
;;; Line-aware Bracket Pair Processing
;;; =================================================================

(define* (find-bracket-pairs-with-context text types levels 
                                          #:key 
                                          (inherited-brackets '())
                                          (line-number 0)
                                          (global-offset 0))
  "Find bracket pairs in a single line, accounting for brackets from previous lines.
   
   Arguments:
   - text: The text of the current line
   - types: Bidi types for each character in the line
   - levels: Bidi levels for each character in the line
   - inherited-brackets: List of <open-bracket> records from previous lines
   - line-number: Current line number (for tracking)
   - global-offset: Global character offset of this line's start
   
   Returns: <bracket-context> containing:
   - open-brackets: Inherited brackets that remain unclosed
   - line-pairs: All bracket pairs (both within-line and cross-line)
   - unclosed-brackets: New brackets opened in this line but not closed"
  
    ;; Helper function to separate inherited from newly opened brackets
  (define (partition-brackets current-stack original-inherited)
    (let loop ([remaining current-stack]
               [inherited '()]
               [new-opens '()])
      (cond
       [(null? remaining) 
        (values (reverse inherited) (reverse new-opens))]
       [else
        (let ([bracket (car remaining)])
          (if (member bracket original-inherited)
              (loop (cdr remaining) (cons bracket inherited) new-opens)
              (loop (cdr remaining) inherited (cons bracket new-opens))))])))
  
  ;; Helper function to find and remove matching open bracket
  (define (find-and-remove-matching-open stack close-char)
    (let ([target-open (char-get-bracket-partner close-char)])
      (if (not target-open)
          #f
          (let loop ([remaining stack]
                     [before '()])
            (cond
             [(null? remaining) #f]  ; No match found
             [(char=? (open-bracket-char (car remaining)) target-open)
              ;; Found match - return matched bracket and remaining stack
              (cons (car remaining) (append (reverse before) (cdr remaining)))]
             [else
              ;; Continue searching
              (loop (cdr remaining) (cons (car remaining) before))])))))
  
  (let ([text-len (string-length text)]
        [stack inherited-brackets]  ; Start with inherited open brackets
        [line-pairs '()]            ; Pairs found in this line
        [unclosed-brackets '()])    ; New unclosed brackets from this line
    
    (let loop ([i 0])
      (if (>= i text-len)
          ;; End of line - separate inherited from new unclosed brackets
          (let-values ([(still-inherited newly-opened) 
                        (partition-brackets stack inherited-brackets)])
            (make-bracket-context still-inherited line-pairs newly-opened))
          
          ;; Process character at position i
          (let* ([char (string-ref text i)]
                 [type (list-ref types i)]
                 [level (list-ref levels i)]
                 [bracket-type (get-bracket-type char)]
                 [global-pos (+ global-offset i)])
            
            (cond
             ;; Opening bracket
             [(eq? bracket-type 'open)
              (let ([new-open (make-open-bracket char level line-number i global-pos)])
                (set! stack (cons new-open stack))
                (loop (+ i 1)))]
             
             ;; Closing bracket
             [(eq? bracket-type 'close)
              (let ([matching-result (find-and-remove-matching-open stack char)])
                (if matching-result
                    (let* ([matched-open (car matching-result)]
                           [remaining-stack (cdr matching-result)]
                           [spans-lines (not (= (open-bracket-line-number matched-open) line-number))]
                           [pair (make-multi-line-bracket-pair 
                                  matched-open i char level spans-lines)])
                      (set! stack remaining-stack)
                      (set! line-pairs (cons pair line-pairs))
                      (loop (+ i 1)))
                    ;; No matching open bracket - just continue
                    (loop (+ i 1))))]
             
             ;; Not a bracket
             [else (loop (+ i 1))]))))))

;;; =================================================================
;;; Multi-line Bracket Processing Utilities
;;; =================================================================

(define* (process-multiple-lines lines #:key (starting-brackets '()) (starting-line-number 0))
  "Process multiple lines of text, maintaining bracket state across lines.
   
   Arguments:
   - lines: List of strings, one per line
   - starting-brackets: Initial open brackets from previous processing
   - starting-line-number: Starting line number for tracking
   
   Returns: List of <bracket-context> records, one per line"
  
  (let loop ([remaining-lines lines]
             [line-num starting-line-number]
             [global-offset 0]
             [current-brackets starting-brackets]
             [results '()])
    
    (if (null? remaining-lines)
	'()

	#|
	;; else
        (let* ([line-text (car remaining-lines)]
               [line-length (string-length line-text)]
               
               ;; Compute bidi information for this line
               [line-levels (resolve-paragraph-bidi line-text)]
               [line-types (map (lambda (char) (char-get-bidi-class char)) 
				(string->list line-text))]
               [weak-types (resolve-weak-types line-text 
                                               (map (lambda (level) (cons level 'neutral)) line-levels)
                                               0)]
               
               ;; Process brackets with context
               [context (find-bracket-pairs-with-context 
                         line-text weak-types line-levels
                         #:inherited-brackets current-brackets
                         #:line-number line-num
                         #:global-offset global-offset)]
               
               ;; Extract unclosed brackets for next line
               [next-brackets (append (bracket-context-open-brackets context)
                                      (bracket-context-unclosed-brackets context))])
          
          (loop (cdr remaining-lines)
                (1+ line-num)
                (+ global-offset line-length 1)  ; +1 for line ending
                next-brackets
        (cons context results))))))|#
	)))

;;; =================================================================
;;; Line Splitting with Bracket Awareness
;;; =================================================================

(define (split-line-with-bracket-context text split-position bracket-context)
  "Split a line while preserving bracket state information.
   
   Arguments:
   - text: The line text to split
   - split-position: Where to split the line
   - bracket-context: Current bracket context for this line
   
   Returns: (values first-line-context second-line-context first-text second-text)"
  
  (if (or (<= split-position 0) (>= split-position (string-length text)))
      ;; No actual split needed
      (if (<= split-position 0)
          (values (make-bracket-context '() '() '())
                  bracket-context
                  ""
                  text)
          (values bracket-context
                  (make-bracket-context '() '() '())
                  text
                  ""))
      
      ;; Perform the split
      (let* ([first-text (substring text 0 split-position)]
             [second-text (substring text split-position)]
             [line-pairs (bracket-context-line-pairs bracket-context)]
             [inherited-brackets (bracket-context-open-brackets bracket-context)]
             [unclosed-brackets (bracket-context-unclosed-brackets bracket-context)])
        
        ;; Categorize bracket pairs and open brackets based on split position
        (let-values ([(first-pairs second-pairs cross-pairs)
                      (categorize-pairs-by-split line-pairs split-position)]
                     [(first-unclosed second-unclosed)
                      (categorize-unclosed-by-split unclosed-brackets split-position)]
                     [(first-inherited second-inherited)
                      (values inherited-brackets inherited-brackets)]) ; Inherited brackets affect both parts
          
          ;; Create contexts for both parts
          (let ([first-context 
                 (make-bracket-context first-inherited first-pairs first-unclosed)]
                [second-context
                 (make-bracket-context 
                  (append second-inherited first-unclosed)  ; Second part inherits unclosed from first
                  (append second-pairs cross-pairs)         ; Plus its own pairs and cross-boundary pairs
                  second-unclosed)])
            
            (values first-context second-context first-text second-text))))))

;; Helper functions for split categorization
(define (categorize-pairs-by-split pairs split-position)
  "Categorize bracket pairs based on split position.
   Returns (values first-pairs second-pairs cross-pairs)"
  (let loop ([remaining-pairs pairs]
             [first '()]
             [second '()]
             [cross '()])
    (if (null? remaining-pairs)
        (values (reverse first) (reverse second) (reverse cross))
        
        (let* ([pair (car remaining-pairs)]
               [open-pos (if (multi-line-bracket-pair-spans-lines? pair)
                             -1  ; From previous line
                             (open-bracket-line-position 
                              (multi-line-bracket-pair-open-bracket pair)))]
               [close-pos (multi-line-bracket-pair-close-position pair)])
          
          (cond
           ;; Both positions before split
           [(and (>= open-pos 0) (< open-pos split-position) (< close-pos split-position))
            (loop (cdr remaining-pairs) (cons pair first) second cross)]
           
           ;; Both positions after split  
           [(and (>= open-pos split-position) (>= close-pos split-position))
            (loop (cdr remaining-pairs) first (cons pair second) cross)]
           
           ;; Pair crosses split boundary
           [else
            (loop (cdr remaining-pairs) first second (cons pair cross))])))))

(define (categorize-unclosed-by-split unclosed-brackets split-position)
  "Categorize unclosed brackets based on split position.
   Returns (values first-unclosed second-unclosed)"
  (let loop ([remaining unclosed-brackets]
             [first '()]
             [second '()])
    (if (null? remaining)
        (values (reverse first) (reverse second))
        
        (let* ([bracket (car remaining)]
               [pos (open-bracket-line-position bracket)])
          (if (< pos split-position)
              (loop (cdr remaining) (cons bracket first) second)
              (loop (cdr remaining) first (cons bracket second)))))))

;;; =================================================================
;;; Bracket Context Analysis and Debugging
;;; =================================================================

(define* (analyze-bracket-context context #:key (line-number 0))
  "Analyze a bracket context for debugging and display"
  `((line-number . ,line-number)
    (inherited-brackets . ,(map open-bracket-char 
				(bracket-context-open-brackets context)))
    (line-pairs . ,(length (bracket-context-line-pairs context)))
    (unclosed-brackets . ,(map open-bracket-char 
                               (bracket-context-unclosed-brackets context)))
    (total-open-brackets . ,(+ (length (bracket-context-open-brackets context))
                               (length (bracket-context-unclosed-brackets context))))))

(define* (print-bracket-context context #:key (line-number 0))
  "Print human-readable bracket context information"
  (let ([analysis (analyze-bracket-context context #:line-number line-number)])
    (format #t "Line ~a Bracket Context:~%" line-number)
    (format #t "  Inherited: ~a~%" (assoc-ref analysis 'inherited-brackets))
    (format #t "  Line pairs: ~a~%" (assoc-ref analysis 'line-pairs))
    (format #t "  Unclosed: ~a~%" (assoc-ref analysis 'unclosed-brackets))
    (format #t "  Total open: ~a~%" (assoc-ref analysis 'total-open-brackets))))

(define (get-bracket-nesting-at-position context position)
  "Get bracket nesting level at a specific position within a line"
  (let* ([inherited-count (length (bracket-context-open-brackets context))]
         [unclosed-before-pos 
          (length (filter (lambda (bracket)
                            (< (open-bracket-line-position bracket) position))
                          (bracket-context-unclosed-brackets context)))]
         [pairs-enclosing-pos
          (length (filter (lambda (pair)
                            (let ([open-pos (if (multi-line-bracket-pair-spans-lines? pair)
                                                -1  ; From previous line, always before position
                                                (open-bracket-line-position 
                                                 (multi-line-bracket-pair-open-bracket pair)))]
                                  [close-pos (multi-line-bracket-pair-close-position pair)])
                              (and (<= open-pos position)     ; Opens at or before position
                                   (> close-pos position))))  ; Closes after position
                          (bracket-context-line-pairs context)))])
    (+ inherited-count unclosed-before-pos pairs-enclosing-pos)))

;;; =================================================================
;;; Enhanced Code Editor Bracket Utilities
;;; =================================================================

(define* (find-all-bracket-pairs text #:key (inherited-brackets '()))
  "Find all bracket pairs in text, useful for syntax highlighting and navigation.
   Can optionally account for brackets inherited from previous lines.
   Returns list of bracket-pair records sorted by position."
  (let* ([resolved-levels (resolve-paragraph-bidi text)]
         [char-types (map (lambda (char) (char-get-bidi-class char)) (string->list text))]
         [weak-types (resolve-weak-types text 
                                         (map (lambda (level) (cons level 'neutral)) resolved-levels) 
                                         0)]
         [context (find-bracket-pairs-with-context 
                   text weak-types resolved-levels
                   #:inherited-brackets inherited-brackets)])
    (bracket-context-line-pairs context)))

(define* (validate-bracket-structure text #:key (inherited-brackets '()))
  "Validate bracket structure for code editor, accounting for inherited brackets.
   Returns (valid? . error-info) where error-info contains details about problems."
  (let* ([types (map (lambda (char)
		       (char-get-bidi-class char))
		     (string->list text))]
	 [levels (resolve-paragraph-bidi text)]
	 [context (find-bracket-pairs-with-context 
                   text
		   types
		   levels
                   #:inherited-brackets inherited-brackets)]
         [unclosed (bracket-context-unclosed-brackets context)])
    ;; (pk 'context context)
    ;; (pk 'unclosed unclosed)
    ;; For single-line validation, unclosed brackets are not necessarily errors
    ;; (they might be closed on subsequent lines)
    (cons #t unclosed)))  ; Return unclosed brackets as information

(define* (find-matching-bracket-position text position #:key (inherited-brackets '()))
  "Find the position of the matching bracket for bracket at given position.
   Accounts for inherited brackets from previous lines.
   Returns position or #f if no match found."
  (if (or (< position 0) (>= position (string-length text)))
      #f
      (let* ([char (string-ref text position)]
             [bracket-type (get-bracket-type char)])
        (if (not bracket-type)
            #f
            (let* ([context (find-bracket-pairs-with-context 
                             text 
                             (map (lambda (char) (char-get-bidi-class char)) (string->list text))
                             (resolve-paragraph-bidi text)
                             #:inherited-brackets inherited-brackets)]
                   [pairs (bracket-context-line-pairs context)])
              
              (cond
               ;; Looking for closing bracket
               [(eq? bracket-type 'open)
                (let loop ([remaining-pairs pairs])
                  (cond
                   [(null? remaining-pairs) #f]
                   [else
                    (let ([pair (car remaining-pairs)])
                      (if (and (not (multi-line-bracket-pair-spans-lines? pair))
                               (= position (open-bracket-line-position 
                                            (multi-line-bracket-pair-open-bracket pair))))
                          (multi-line-bracket-pair-close-position pair)
                          (loop (cdr remaining-pairs))))]))]
               
               ;; Looking for opening bracket
               [(eq? bracket-type 'close)
                (let loop ([remaining-pairs pairs])
                  (cond
                   [(null? remaining-pairs) #f]
                   [else
                    (let ([pair (car remaining-pairs)])
                      (if (= position (multi-line-bracket-pair-close-position pair))
                          (if (multi-line-bracket-pair-spans-lines? pair)
                              'previous-line  ; Indicates match is on previous line
                              (open-bracket-line-position 
                               (multi-line-bracket-pair-open-bracket pair)))
                          (loop (cdr remaining-pairs))))]))]
               
               [else #f]))))))

(define* (get-bracket-nesting-level text position #:key (inherited-brackets '()))
  "Get the nesting level of brackets at a given position (0-based).
   Accounts for inherited brackets from previous lines."
  (cond
   ;; Position before text start - only inherited brackets
   [(< position 0)
    (length inherited-brackets)]
   
   ;; Position after text end - inherited + unclosed brackets from text
   [(> position (string-length text))
    (let* ([types (map (lambda (char)
			 (char-get-bidi-class char))
		       (string->list text))]
	   [levels (resolve-paragraph-bidi text)]
	   [context (find-bracket-pairs-with-context 
                     text
		     types
		     levels
                     #:inherited-brackets inherited-brackets)])
      (+ (length (bracket-context-open-brackets context))
         (length (bracket-context-unclosed-brackets context))))]
   
   ;; Position within text - use normal calculation
   [else
    (let* ([types (map (lambda (char)
			 (char-get-bidi-class char))
		       (string->list text))]
	   [levels (resolve-paragraph-bidi text)]
	   [context (find-bracket-pairs-with-context 
                     (pk 'txt text)
                     (pk 'types types)
		     (pk 'levels levels)
                     #:inherited-brackets inherited-brackets)])
      (get-bracket-nesting-at-position context position))]))

(define* (find-enclosing-brackets text position #:key (inherited-brackets '()))
  "Find the innermost bracket pair that encloses the given position.
   Accounts for inherited brackets. Returns bracket-pair record or #f if not enclosed."
  (let* ([context (find-bracket-pairs-with-context 
                   text 
                   (map (lambda (char) (char-get-bidi-class char)) (string->list text))
                   (resolve-paragraph-bidi text)
                   #:inherited-brackets inherited-brackets)]
         [pairs (bracket-context-line-pairs context)])
    
    (let loop ([remaining-pairs pairs]
               [best-pair #f]
               [best-span #f])
      (cond
       [(null? remaining-pairs) best-pair]
       [else
        (let* ([pair (car remaining-pairs)]
               [open-pos (if (multi-line-bracket-pair-spans-lines? pair)
                             -1  ; From previous line, so it encloses everything
                             (open-bracket-line-position 
                              (multi-line-bracket-pair-open-bracket pair)))]
               [close-pos (multi-line-bracket-pair-close-position pair)])
          
          (cond
           ;; Multi-line pair that closes after our position
           [(and (multi-line-bracket-pair-spans-lines? pair) (> close-pos position))
            ;; This always encloses our position, check if it's the best
            (let ([span (- close-pos open-pos)])
              (if (or (not best-span) (< span best-span))
                  (loop (cdr remaining-pairs) pair span)
                  (loop (cdr remaining-pairs) best-pair best-span)))]
           
           ;; Same-line pair that encloses our position
           [(and (not (multi-line-bracket-pair-spans-lines? pair))
                 (< open-pos position) (> close-pos position))
            (let ([span (- close-pos open-pos)])
              (if (or (not best-span) (< span best-span))
                  (loop (cdr remaining-pairs) pair span)
                  (loop (cdr remaining-pairs) best-pair best-span)))]
           
           [else (loop (cdr remaining-pairs) best-pair best-span)]))]))))

;;; =================================================================
;;; Multi-line Document Bracket Analysis
;;; =================================================================

(define (analyze-document-brackets lines)
  "Analyze bracket structure across an entire document.
   Returns comprehensive bracket information for the whole document."
  (let* ([contexts (process-multiple-lines lines)]
         [all-pairs (apply append (map bracket-context-line-pairs contexts))]
         [final-unclosed (let ([last-context (if (null? contexts) 
                                                 (make-bracket-context '() '() '())
                                                 (last contexts))])
                           (append (bracket-context-open-brackets last-context)
                                   (bracket-context-unclosed-brackets last-context)))])
    
    `((total-lines . ,(length lines))
      (total-pairs . ,(length all-pairs))
      (multi-line-pairs . ,(length (filter multi-line-bracket-pair-spans-lines? all-pairs)))
      (single-line-pairs . ,(length (filter (lambda (p) 
                                              (not (multi-line-bracket-pair-spans-lines? p))) 
                                            all-pairs)))
      (final-unclosed-brackets . ,(map open-bracket-char final-unclosed))
      (contexts-per-line . ,contexts))))

(define (find-bracket-errors-in-document lines)
  "Find bracket matching errors across an entire document.
   Returns list of error descriptions."
  (let* ([analysis (analyze-document-brackets lines)]
         [final-unclosed (assoc-ref analysis 'final-unclosed-brackets)]
         [errors '()])
    
    ;; Check for unclosed brackets at end of document
    (when (not (null? final-unclosed))
      (set! errors (cons `(unclosed-brackets-at-end . ,final-unclosed) errors)))
    
    ;; Could add more sophisticated error detection here
    ;; (mismatched bracket types, etc.)
    
    errors))

(define (get-bracket-context-for-line lines line-number)
  "Get the bracket context for a specific line in a document"
  (if (or (< line-number 0) (>= line-number (length lines)))
      #f
      (let ([contexts (process-multiple-lines (take lines (+ line-number 1)))])
        (if (> (length contexts) line-number)
            (list-ref contexts line-number)
            #f))))

(define (analyze-bidi-text text)
  "Comprehensive analysis of bidirectional text for debugging.
   Returns detailed information about character types, levels, and bracket pairs."
  (let* ([char-list (string->list text)]
         [char-classes (map char-get-bidi-class char-list)]
         [base-direction (paragraph-base-direction text)]
         [resolved-levels (resolve-paragraph-bidi text)]
         [bracket-pairs (find-all-bracket-pairs text)]
         [validation (validate-bracket-structure text)])
    
    `((text . ,text)
      (length . ,(string-length text))
      (base-direction . ,base-direction)
      (character-classes . ,char-classes)
      (resolved-levels . ,resolved-levels)
      (bracket-pairs . ,(map (lambda (pair)
                               `((open-pos . ,(bracket-pair-open-pos pair))
                                 (close-pos . ,(bracket-pair-close-pos pair))
                                 (open-char . ,(bracket-pair-open-char pair))
                                 (close-char . ,(bracket-pair-close-char pair))
                                 (level . ,(bracket-pair-level pair))))
                             bracket-pairs))
      (bracket-validation . ,validation))))

(define (print-bidi-analysis text)
  "Print a human-readable analysis of bidirectional text"
  (let ([analysis (analyze-bidi-text text)])
    (format #t "=== Bidirectional Text Analysis ===~%")
    (format #t "Text: ~s~%" (assoc-ref analysis 'text))
    (format #t "Length: ~a characters~%" (assoc-ref analysis 'length))
    (format #t "Base Direction: ~a~%" (assoc-ref analysis 'base-direction))
    (format #t "~%Character breakdown:~%")
    
    (let ([chars (string->list (assoc-ref analysis 'text))]
          [classes (assoc-ref analysis 'character-classes)]
          [levels (assoc-ref analysis 'resolved-levels)])
      (for-each (lambda (i)
                  (let ([char (list-ref chars i)]
                        [class (list-ref classes i)]
                        [level (list-ref levels i)])
                    (format #t "  ~2d: ~c  ~4a  level=~a~%" i char class level)))
                (iota (length chars))))
    
    (format #t "~%Bracket pairs:~%")
    (let ([pairs (assoc-ref analysis 'bracket-pairs)])
      (if (null? pairs)
          (format #t "  (none)~%")
          (for-each (lambda (pair)
                      (format #t "  ~a(~a) at ~a ↔ ~a(~a) at ~a, level=~a~%"
                              (assoc-ref pair 'open-char)
                              (char->integer (assoc-ref pair 'open-char))
                              (assoc-ref pair 'open-pos)
                              (assoc-ref pair 'close-char)
                              (char->integer (assoc-ref pair 'close-char))
                              (assoc-ref pair 'close-pos)
                              (assoc-ref pair 'level)))
                    pairs)))
    
    (let ([validation (assoc-ref analysis 'bracket-validation)])
      (format #t "~%Bracket validation: ~a~%"
              (if (car validation) "VALID" "INVALID"))
      (when (not (car validation))
        (format #t "Unmatched brackets:~%")
        (for-each (lambda (bracket)
                    (format #t "  ~a at position ~a~%" (cadr bracket) (car bracket)))
                  (cdr validation))))))

;;; =================================================================
;;; Visual/Logical Order Conversion (Simplified)
;;; =================================================================

(define (visual-to-logical-order text levels)
  "Convert visual character order to logical order (simplified)"
  ;; This is a complex algorithm - providing stub for now
  (iota (string-length text)))

(define (logical-to-visual-order text levels)  
  "Convert logical character order to visual order (simplified)"
  ;; This is a complex algorithm - providing stub for now
  (iota (string-length text)))
