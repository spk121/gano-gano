;;; UAX #9 Unicode Bidirectional Algorithm Implementation for GNU Guile
;;; Based on Unicode Standard Annex #9 Revision 44
;;; Operates on strings and provides bidi state tracking for line splitting

(define-module (gano uax9-bidi)
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-9)        ; Record types
  #:use-module (srfi srfi-11)       ; let-values
  #:use-module (ice-9 regex)        ; Regular expressions
  #:use-module (gano bidi-class)    ; Import bidi class functionality
  #:use-module (gano bracket-pairs) ; Import bracket pairs
  #:export (
    ;; Main UAX #9 functions
    resolve-paragraph-bidi
    get-bidi-state-at-position
    split-line-with-bidi-controls
    
    ;; Local bidi character classification utilities
    is-bidi-control?
    is-strong-directional?
    
    ;; Embedding/isolate state tracking
    <bidi-state>
    make-bidi-state
    bidi-state-embedding-level
    bidi-state-override-status
    bidi-state-isolate-status
    
    ;; Utility functions
    paragraph-base-direction
    visual-to-logical-order
    logical-to-visual-order)
  
  #:re-export (
    ;; Re-export from (gano bidi-class)
    get-bidi-class
    BC-L BC-R BC-AL BC-EN BC-ES BC-ET BC-AN BC-CS BC-NSM BC-BN
    BC-B BC-S BC-WS BC-ON BC-LRE BC-LRO BC-RLE BC-RLO BC-PDF
    BC-LRI BC-RLI BC-FSI BC-PDI
    
    ;; Re-export from (gano bracket-pairs)  
    bracket-pairs))

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
;;; Character Classification Utilities
;;; =================================================================

(define (is-bidi-control? char)
  "Check if character is a bidirectional control character"
  (let ([class (get-bidi-class char)])
    (member class '(LRE RLE PDF LRO RLO LRI RLI FSI PDI))))

(define (is-strong-directional? char)
  "Check if character has strong directional properties"
  (let ([class (get-bidi-class char)])
    (member class '(L R AL))))

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
              [class (get-bidi-class char)])
         (cond
           ;; Skip isolate runs (simplified)
           [(member class '(LRI RLI FSI))
            (let ([isolate-end (find-matching-pdi text i)])
              (loop (if isolate-end (+ isolate-end 1) (+ i 1))))]
           
           ;; First strong character determines direction  
           [(eq? class BC-L) 'ltr]
           [(or (eq? class BC-R) (eq? class BC-AL)) 'rtl]
           
           ;; Continue searching
           [else (loop (+ i 1))]))])))

(define (find-matching-pdi text start-pos)
  "Find the matching PDI for an isolate initiator at start-pos"
  (let loop ([i (+ start-pos 1)]
             [depth 1])
    (cond
      [(>= i (string-length text)) #f]  ; No matching PDI found
      [else
       (let ([class (get-bidi-class (string-ref text i))])
         (cond
           [(member class '(LRI RLI FSI)) (loop (+ i 1) (+ depth 1))]
           [(eq? class BC-PDI)
            (if (= depth 1)
                i  ; Found matching PDI
                (loop (+ i 1) (- depth 1)))]
           [else (loop (+ i 1) depth)]))])))

;;; =================================================================
;;; Explicit Level Resolution (UAX #9 Rules X1-X8)
;;; =================================================================

(define (resolve-explicit-levels text base-level)
  "Resolve explicit embedding levels.
   Returns list of (level . override-status) for each character."
  (let ([length (string-length text)]
        [stack (list (cons base-level 'neutral))]  ; (level . override-status)
        [overflow-isolate-count 0]
        [overflow-embedding-count 0]
        [valid-isolate-count 0]
        [result '()])
    
    (let loop ([i 0])
      (if (>= i length)
          (reverse result)
          (let* ([char (string-ref text i)]
                 [class (get-bidi-class char)]
                 [current-level (car (car stack))]
                 [current-override (cdr (car stack))])
            
            (case class
              ;; RLE, LRE, RLO, LRO (X2-X5)
              [(RLE LRE RLO LRO)
               (let* ([new-level (if (member class '(RLE RLO))
                                    (+ (* 2 (quotient (+ current-level 1) 2)) 1)  ; Next odd
                                    (+ (* 2 (quotient (+ current-level 2) 2)) 0))] ; Next even
                      [new-override (if (member class '(RLO LRO))
                                       (if (eq? class 'RLO) 'R 'L)
                                       'neutral)])
                 (cond
                   [(and (< new-level 126)
                         (< overflow-isolate-count 1)
                         (< overflow-embedding-count 1))
                    (set! stack (cons (cons new-level new-override) stack))
                    (set! result (cons (cons current-level 'BN) result))]
                   [else
                    (set! overflow-embedding-count (+ overflow-embedding-count 1))
                    (set! result (cons (cons current-level 'BN) result))]))]
              
              ;; PDF (X7)
              [(PDF)
               (cond
                 [(> overflow-isolate-count 0)
                  (set! result (cons (cons current-level 'BN) result))]
                 [(> overflow-embedding-count 0)
                  (set! overflow-embedding-count (- overflow-embedding-count 1))
                  (set! result (cons (cons current-level 'BN) result))]
                 [(and (> (length stack) 1)
                       (not (member (cdr (cadr stack)) '(LRI RLI FSI))))
                  (set! stack (cdr stack))
                  (set! result (cons (cons current-level 'BN) result))]
                 [else
                  (set! result (cons (cons current-level 'BN) result))])]
              
              ;; LRI, RLI, FSI (X5a-X5c)
              [(LRI RLI FSI)
               (let* ([new-level (if (or (eq? class 'RLI)
                                        (and (eq? class 'FSI)
                                             (eq? (first-strong-in-isolate text i) 'rtl)))
                                    (+ (* 2 (quotient (+ current-level 1) 2)) 1)  ; Next odd
                                    (+ (* 2 (quotient (+ current-level 2) 2)) 0))] ; Next even
                      [isolate-info (cons new-level class)])
                 (set! result (cons (cons current-level 'BN) result))
                 (cond
                   [(and (< new-level 126)
                         (< overflow-isolate-count 1)
                         (< overflow-embedding-count 1))
                    (set! valid-isolate-count (+ valid-isolate-count 1))
                    (set! stack (cons isolate-info stack))]
                   [else
                    (set! overflow-isolate-count (+ overflow-isolate-count 1))]))]
              
              ;; PDI (X6a)
              [(PDI)
               (cond
                 [(> overflow-isolate-count 0)
                  (set! overflow-isolate-count (- overflow-isolate-count 1))
                  (set! result (cons (cons current-level 'BN) result))]
                 [(> valid-isolate-count 0)
                  (set! overflow-embedding-count 0)
                  ;; Pop back to matching isolate initiator
                  (let loop-pop ([stack-temp stack])
                    (cond
                      [(null? stack-temp) (set! stack '())]
                      [(member (cdr (car stack-temp)) '(LRI RLI FSI))
                       (set! stack stack-temp)
                       (set! valid-isolate-count (- valid-isolate-count 1))]
                      [else (loop-pop (cdr stack-temp))]))
                  (set! result (cons (cons current-level 'BN) result))]
                 [else
                  (set! result (cons (cons current-level 'BN) result))])]
              
              ;; All other characters (X6)
              [else
               (let ([level (car (car stack))]
                     [override (cdr (car stack))])
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
             (let ([class (get-bidi-class (string-ref text i))])
               (cond
                 [(eq? class BC-L) 'ltr]
                 [(or (eq? class BC-R) (eq? class BC-AL)) 'rtl]
                 [(member class '(LRI RLI FSI))
                  ;; Skip nested isolate
                  (let ([nested-end (find-matching-pdi text i)])
                    (loop (if nested-end (+ nested-end 1) (+ i 1))))]
                 [else (loop (+ i 1))]))])))))

;;; =================================================================
;;; Weak Type Resolution (UAX #9 Rules W1-W7) - Simplified
;;; =================================================================

(define (resolve-weak-types text explicit-levels base-level)
  "Resolve weak character types. Simplified implementation."
  (let ([length (string-length text)]
        [types (map (lambda (char) (get-bidi-class char)) (string->list text))])
    
    ;; W1: NSM takes type of preceding character
    (let loop-w1 ([i 1]
                  [result (list (car types))])
      (if (>= i length)
          (let ([w1-types (reverse result)])
            ;; W2: EN after AL becomes AN
            (let loop-w2 ([i 0]
                          [result-w2 '()]
                          [last-strong BC-L])
              (if (>= i length)
                  (reverse result-w2)
                  (let ([current-type (list-ref w1-types i)])
                    (case current-type
                      [(AL R L) 
                       (loop-w2 (+ i 1) (cons current-type result-w2) current-type)]
                      [(EN)
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
    [(assoc char bracket-pairs) 'open]
    [(rassoc char bracket-pairs) 'close]
    [else #f]))

(define (get-matching-bracket char)
  "Get the matching bracket for a given bracket character"
  (cond
    [(assoc char bracket-pairs) => cdr]
    [(rassoc char bracket-pairs) => car]
    [else #f]))

(define (rassoc key alist)
  "Reverse association list lookup"
  (let loop ([lst alist])
    (cond
      [(null? lst) #f]
      [(equal? key (cdar lst)) (caar lst)]
      [else (loop (cdr lst))])))

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
  (let ([length (string-length text)]
        [stack '()]     ; Stack of open brackets: (pos char level)
        [pairs '()])    ; Found pairs
    
    (let loop ([i 0])
      (if (>= i length)
          (reverse pairs)
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
               (let ([matching-open (find-matching-open-bracket stack char)])
                 (if matching-open
                     (let* ([open-info (car matching-open)]
                            [remaining-stack (cdr matching-open)]
                            [open-pos (car open-info)]
                            [open-char (cadr open-info)]
                            [open-level (caddr open-info)])
                       (set! stack remaining-stack)
                       (set! pairs (cons (make-bracket-pair open-pos i open-char char level) pairs))
                       (loop (+ i 1)))
                     (loop (+ i 1))))]
              
              ;; Not a bracket
              [else (loop (+ i 1))]))))
    
    ;; Sort pairs by opening position for processing
    (sort pairs (lambda (a b) (< (bracket-pair-open-pos a) (bracket-pair-open-pos b))))))

(define (find-matching-open-bracket stack close-char)
  "Find matching open bracket in stack, removing any unmatched brackets.
   Returns (matching-element . remaining-stack) or #f if no match."
  (let ([target-open (get-matching-bracket close-char)])
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

;;; =================================================================
;;; Enhanced Neutral Type Resolution (UAX #9 Rules N0, N1, N2)
;;; =================================================================

(define (resolve-neutral-types text weak-types explicit-levels)
  "Resolve neutral character types with proper bracket pair handling.
   Implements UAX #9 rules N0, N1, and N2."
  (let* ([length (string-length text)]
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
        (if (>= i length)
            (reverse result)
            (let* ([current-type (list-ref types-after-n0 i)]
                   [current-level (list-ref levels i)])
              
              (cond
                ;; Already resolved by N0 or not neutral
                [(not (member current-type '(WS ON S B ES ET CS)))
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
          [(or (and (eq? embedding-direction BC-L) (member strong-direction '(R AL AN)))
               (and (eq? embedding-direction BC-R) (member strong-direction '(L EN))))
           
           ;; Set bracket types to opposite of embedding direction
           (let ([bracket-type (if (eq? embedding-direction BC-L) BC-R BC-L)])
             (vector-set! types-vector open-pos bracket-type)
             (vector-set! types-vector close-pos bracket-type))]
          
          ;; Strong type matches embedding direction - no change needed
          [else #f])))))

(define (find-strong-type-in-range text types-vector levels start end)
  "Find first strong type within a range, respecting isolates and embeddings"
  (let loop ([i start])
    (cond
      [(>= i end) #f]
      [else
       (let* ([char (string-ref text i)]
              [type (vector-ref types-vector i)]
              [class (get-bidi-class char)])
         (cond
           ;; Skip isolate runs
           [(member class '(LRI RLI FSI))
            (let ([isolate-end (find-matching-pdi text i)])
              (loop (if isolate-end (+ isolate-end 1) (+ i 1))))]
           
           ;; Found strong type
           [(member type '(L R AL EN AN))
            (cons type i)]
           
           ;; Continue searching
           [else (loop (+ i 1))]))])))

(define (find-preceding-strong types levels pos)
  "Find the preceding strong type with its level"
  (let loop ([i (- pos 1)])
    (cond
      [(< i 0) #f]
      [else
       (let ([type (list-ref types i)]
             [level (list-ref levels i)])
         (if (member type '(L R AL EN AN))
             (cons type level)
             (loop (- i 1))))])))

(define (find-following-strong types levels pos)
  "Find the following strong type with its level" 
  (let ([length (length types)])
    (let loop ([i (+ pos 1)])
      (cond
        [(>= i length) #f]
        [else
         (let ([type (list-ref types i)]
               [level (list-ref levels i)])
           (if (member type '(L R AL EN AN))
               (cons type level)
               (loop (+ i 1))))]))))

(define (same-strong-type? strong1 strong2)
  "Check if two strong types are the same for N1 rule purposes"
  (let ([type1 (car strong1)]
        [type2 (car strong2)])
    (or (and (member type1 '(L EN)) (member type2 '(L EN)))
        (and (member type1 '(R AL AN)) (member type2 '(R AL AN))))))

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
                   [(eq? override 'L) (if (even? level) level (+ level 1))]
                   [(eq? override 'R) (if (odd? level) level (+ level 1))]
                   ;; For strong types, use character's natural level
                   [(member final-type '(L EN))
                    (if (even? level) level (+ level 1))]
                   [(member final-type '(R AL AN))
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
                     [class (get-bidi-class char)]
                     [current-level (if (null? stack) 0 (car (car stack)))])
                
                (case class
                  ;; Embedding/Override initiators
                  [(RLE LRE RLO LRO)
                   (let* ([new-level (if (member class '(RLE RLO))
                                        (+ (* 2 (quotient (+ current-level 1) 2)) 1)
                                        (+ (* 2 (quotient (+ current-level 2) 2)) 0))]
                          [new-override (if (member class '(RLO LRO))
                                           (if (eq? class 'RLO) 'R 'L)
                                           'neutral)])
                     (cond
                       [(and (< new-level 126)
                             (< overflow-isolate-count 1)
                             (< overflow-embedding-count 1))
                        (set! stack (cons (cons new-level new-override) stack))]
                       [else
                        (set! overflow-embedding-count (+ overflow-embedding-count 1))]))]
                  
                  ;; PDF
                  [(PDF)
                   (cond
                     [(> overflow-isolate-count 0) #f]  ; Do nothing
                     [(> overflow-embedding-count 0)
                      (set! overflow-embedding-count (- overflow-embedding-count 1))]
                     [(and (> (length stack) 1)
                           (not (member (cdr (cadr stack)) '(LRI RLI FSI))))
                      (set! stack (cdr stack))])]
                  
                  ;; Isolate initiators
                  [(LRI RLI FSI)
                   (let* ([new-level (if (or (eq? class 'RLI)
                                            (and (eq? class 'FSI)
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
                  [(PDI)
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
                          [(member (cdr (car stack-temp)) '(LRI RLI FSI))
                           (set! stack (cdr stack-temp))]
                          [else (loop-pop (cdr stack-temp))]))])])
                
                (loop (+ i 1))))))))

(define (split-line-with-bidi-controls text split-position)
  "Split text at position, adding necessary bidi controls to maintain state.
   Returns (values first-line second-line)"
  (if (or (<= split-position 0) (>= split-position (string-length text)))
      (if (<= split-position 0)
          (values "" text)
          (values text ""))
      
      (let* ([state-at-split (get-bidi-state-at-position text split-position)]
             [first-part (substring text 0 split-position)]
             [second-part (substring text split-position)]
             [level (bidi-state-embedding-level state-at-split)]
             [override (bidi-state-override-status state-at-split)]
             [isolate (bidi-state-isolate-status state-at-split)])
        
        ;; Generate termination controls for first line
        (let ([first-terminators
               (append
                 ;; Close isolates if needed
                 (if (not (eq? isolate 'none)) '(#\x2069) '())  ; PDI
                 ;; Close embeddings/overrides if needed  
                 (if (or (> level 0) (not (eq? override 'neutral)))
                     '(#\x202C)  ; PDF
                     '()))])
          
          ;; Generate restoration controls for second line
          (let ([second-initiators
                 (append
                   ;; Restore embeddings/overrides
                   (cond
                     [(and (> level 0) (eq? override 'L)) '(#\x202D)]      ; LRO
                     [(and (> level 0) (eq? override 'R)) '(#\x202E)]      ; RLO
                     [(and (> level 0) (odd? level) (eq? override 'neutral)) '(#\x202B)]  ; RLE
                     [(and (> level 0) (even? level) (eq? override 'neutral)) '(#\x202A)] ; LRE
                     [else '()])
                   ;; Restore isolates
                   (case isolate
                     [(LRI) '(#\x2066)]   ; LRI
                     [(RLI) '(#\x2067)]   ; RLI  
                     [(FSI) '(#\x2068)]   ; FSI
                     [else '()]))])
            
            (values 
              (string-append first-part (list->string first-terminators))
              (string-append (list->string second-initiators) second-part)))))))

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
  
  (let ([length (string-length text)]
        [stack inherited-brackets]  ; Start with inherited open brackets
        [line-pairs '()]            ; Pairs found in this line
        [unclosed-brackets '()])    ; New unclosed brackets from this line
    
    (let loop ([i 0])
      (if (>= i length)
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
              [else (loop (+ i 1))]))))
    
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
      (let ([target-open (get-matching-bracket close-char)])
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
                 (loop (cdr remaining) (cons (car remaining) before))])))))))

;;; =================================================================
;;; Multi-line Bracket Processing Utilities
;;; =================================================================

(define (process-multiple-lines lines #:key (starting-brackets '()) (starting-line-number 0))
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
        (reverse results)
        
        (let* ([line-text (car remaining-lines)]
               [line-length (string-length line-text)]
               
               ;; Compute bidi information for this line
               [line-levels (resolve-paragraph-bidi line-text)]
               [line-types (map (lambda (char) (get-bidi-class char)) 
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
                (+ line-num 1)
                (+ global-offset line-length 1)  ; +1 for line ending
                next-brackets
                (cons context results))))))

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

(define (analyze-bracket-context context #:key (line-number 0))
  "Analyze a bracket context for debugging and display"
  `((line-number . ,line-number)
    (inherited-brackets . ,(map open-bracket-char 
                               (bracket-context-open-brackets context)))
    (line-pairs . ,(length (bracket-context-line-pairs context)))
    (unclosed-brackets . ,(map open-bracket-char 
                              (bracket-context-unclosed-brackets context)))
    (total-open-brackets . ,(+ (length (bracket-context-open-brackets context))
                              (length (bracket-context-unclosed-brackets context))))))

(define (print-bracket-context context #:key (line-number 0))
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
         [pairs-closing-after-pos
          (length (filter (lambda (pair)
                           (> (multi-line-bracket-pair-close-position pair) position))
                         (bracket-context-line-pairs context)))])
    (+ inherited-count unclosed-before-pos pairs-closing-after-pos)))

(define (validate-bracket-structure text)
  "Validate bracket structure for code editor.
   Returns (valid? . error-info) where error-info contains details about problems."
  (let* ([pairs (find-all-bracket-pairs text)]
         [all-brackets (find-all-brackets text)]
         [unmatched (find-unmatched-brackets all-brackets pairs)])
    
    (if (null? unmatched)
        (cons #t '())
        (cons #f unmatched))))

(define (find-all-brackets text)
  "Find all bracket characters with their positions and types"
  (let loop ([i 0]
             [brackets '()])
    (if (>= i (string-length text))
        (reverse brackets)
        (let* ([char (string-ref text i)]
               [bracket-type (get-bracket-type char)])
          (if bracket-type
              (loop (+ i 1) (cons (list i char bracket-type) brackets))
              (loop (+ i 1) brackets))))))

(define (find-unmatched-brackets all-brackets pairs)
  "Find brackets that don't have matches"
  (let ([matched-positions (apply append 
                                 (map (lambda (pair)
                                        (list (bracket-pair-open-pos pair)
                                              (bracket-pair-close-pos pair)))
                                      pairs))])
    (filter (lambda (bracket-info)
              (not (member (car bracket-info) matched-positions)))
            all-brackets)))

(define (find-matching-bracket-position text position)
  "Find the position of the matching bracket for bracket at given position.
   Returns position or #f if no match found."
  (if (or (< position 0) (>= position (string-length text)))
      #f
      (let* ([char (string-ref text position)]
             [bracket-type (get-bracket-type char)])
        (if (not bracket-type)
            #f
            (let ([pairs (find-all-bracket-pairs text)])
              (let loop ([remaining-pairs pairs])
                (cond
                  [(null? remaining-pairs) #f]
                  [else
                   (let ([pair (car remaining-pairs)])
                     (cond
                       [(= position (bracket-pair-open-pos pair))
                        (bracket-pair-close-pos pair)]
                       [(= position (bracket-pair-close-pos pair))
                        (bracket-pair-open-pos pair)]
                       [else (loop (cdr remaining-pairs))]))])))))))

(define (get-bracket-nesting-level text position)
  "Get the nesting level of brackets at a given position (0-based)"
  (if (or (< position 0) (> position (string-length text)))
      0
      (let ([pairs (find-all-bracket-pairs text)])
        (length (filter (lambda (pair)
                         (and (< (bracket-pair-open-pos pair) position)
                              (> (bracket-pair-close-pos pair) position)))
                       pairs)))))

(define (find-enclosing-brackets text position)
  "Find the innermost bracket pair that encloses the given position.
   Returns bracket-pair record or #f if not enclosed."
  (let ([pairs (find-all-bracket-pairs text)])
    (let loop ([remaining-pairs pairs]
               [best-pair #f]
               [best-span #f])
      (cond
        [(null? remaining-pairs) best-pair]
        [else
         (let* ([pair (car remaining-pairs)]
                [open-pos (bracket-pair-open-pos pair)]
                [close-pos (bracket-pair-close-pos pair)]
                [span (- close-pos open-pos)])
           (if (and (< open-pos position) (> close-pos position)
                    (or (not best-span) (< span best-span)))
               (loop (cdr remaining-pairs) pair span)
               (loop (cdr remaining-pairs) best-pair best-span)))]))))

;;; =================================================================
;;; Enhanced Code Editor Bracket Utilities
;;; =================================================================

(define* (find-all-bracket-pairs text #:key (inherited-brackets '()))
  "Find all bracket pairs in text, useful for syntax highlighting and navigation.
   Can optionally account for brackets inherited from previous lines.
   Returns list of bracket-pair records sorted by position."
  (let* ([resolved-levels (resolve-paragraph-bidi text)]
         [char-types (map (lambda (char) (get-bidi-class char)) (string->list text))]
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
  (let* ([context (find-bracket-pairs-with-context 
                   text 
                   (map (lambda (char) (get-bidi-class char)) (string->list text))
                   (resolve-paragraph-bidi text)
                   #:inherited-brackets inherited-brackets)]
         [unclosed (bracket-context-unclosed-brackets context)])
    
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
                            (map (lambda (char) (get-bidi-class char)) (string->list text))
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
  (if (or (< position 0) (> position (string-length text)))
      (length inherited-brackets)  ; Just inherited nesting if outside text
      (let* ([context (find-bracket-pairs-with-context 
                      text 
                      (map (lambda (char) (get-bidi-class char)) (string->list text))
                      (resolve-paragraph-bidi text)
                      #:inherited-brackets inherited-brackets)])
        (get-bracket-nesting-at-position context position))))

(define* (find-enclosing-brackets text position #:key (inherited-brackets '()))
  "Find the innermost bracket pair that encloses the given position.
   Accounts for inherited brackets. Returns bracket-pair record or #f if not enclosed."
  (let* ([context (find-bracket-pairs-with-context 
                  text 
                  (map (lambda (char) (get-bidi-class char)) (string->list text))
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
         [char-classes (map get-bidi-class char-list)]
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
