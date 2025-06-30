;;; UAX #9 Unicode Bidirectional Algorithm - Core Implementation
;;; Based on Unicode Standard Annex #9 Revision 44
;;; Essential bidi algorithm without advanced bracket processing

(define-module (gano uax9-core)
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-9)        ; Record types
  #:use-module (ice-9 regex)        ; Regular expressions
  #:use-module (gano char)          ; Import bidi class functionality
  #:use-module (gano string-utils)  ; String manipulation utilities
  #:export (
            ;; Main UAX #9 core functions
            resolve-paragraph-bidi
            paragraph-base-direction
            resolve-explicit-levels
            resolve-weak-types
            resolve-neutral-types
            
            ;; State management
            get-bidi-state-at-position
            split-line-with-bidi-controls
            
            ;; Basic bracket support for Rule N0
            get-bracket-type
            find-bracket-pairs
            
            ;; Utility functions
            find-matching-pdi
            first-strong-in-isolate
            find-preceding-strong
            find-following-strong
            visual-to-logical-order
            logical-to-visual-order
            
            ;; Records
            <bidi-state>
            make-bidi-state
            bidi-state?
            bidi-state-embedding-level
            bidi-state-override-status
            bidi-state-isolate-status
            
            <bracket-pair>
            make-bracket-pair
            bracket-pair?
            bracket-pair-open-pos
            bracket-pair-close-pos
            bracket-pair-open-char
            bracket-pair-close-char
            bracket-pair-level))

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
;;; Basic Bracket Support for Rule N0
;;; =================================================================

(define-record-type <bracket-pair>
  (make-bracket-pair open-pos close-pos open-char close-char level)
  bracket-pair?
  (open-pos bracket-pair-open-pos)
  (close-pos bracket-pair-close-pos) 
  (open-char bracket-pair-open-char)
  (close-char bracket-pair-close-char)
  (level bracket-pair-level))

(define (get-bracket-type char)
  "Get bracket type: 'open, 'close, or #f if not a bracket"
  (cond
   [(char-opening-bracket? char) 'open]
   [(char-closing-bracket? char) 'close]
   [else #f]))

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

;;; =================================================================
;;; Helper Functions for Isolate Processing
;;; =================================================================

(define (find-matching-pdi text start-pos)
  "Find the matching PDI for an isolate initiator at start-pos"
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
	       [else
		pos]))]
	   [else #f]))]
       [else #f]))))

(define (first-strong-in-isolate text isolate-start)
  "Find first strong character in isolate run for FSI resolution"
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
               (cond
                [(> overflow-isolate-count 0)
                 (set! result (cons (cons current-level 'BC-BN) result))]
                [(> overflow-embedding-count 0)
                 (set! overflow-embedding-count (- overflow-embedding-count 1))
                 (set! result (cons (cons current-level 'BC-BN) result))]
                [(and (> (length stack) 1)
		      (pair? (cadr stack))
                      (not (member (cdadr stack) '(BC-LRI BC-RLI BC-FSI))))
                 (set! stack (cdr stack))
                 (set! result (cons (cons current-level 'BC-BN) result))]
                [else
                 (set! result (cons (cons current-level 'BC-BN) result))])]
              
              ;; LRI, RLI, FSI (X5a-X5c)
              [(BC-LRI BC-RLI BC-FSI)
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
                 (set! result (cons (cons level override) result)))])
            
            (loop (+ i 1)))))))

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
;;; Basic Bracket Pair Detection for Rule N0
;;; =================================================================

(define (find-bracket-pairs text types levels)
  "Find all bracket pairs in text following UAX #9 rule N0.
   Returns list of <bracket-pair> records."
  (let ([text-len (string-length text)]
        [stack '()]     ; Stack of open brackets: (pos char level)
        [pairs '()])    ; Found pairs
    
    (let loop ([i 0])
      (if (>= i text-len)
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

;;; =================================================================
;;; Neutral Type Resolution (UAX #9 Rules N1, N2) - Simplified
;;; =================================================================

(define (resolve-neutral-types text weak-types explicit-levels)
  "Resolve neutral character types with basic bracket pair handling.
   Implements UAX #9 rules N1 and N2."
  (let* ([text-len (string-length text)]
         [levels (map car explicit-levels)]
         [result-types (list->vector weak-types)])
    
    ;; Rules N1 and N2: Process neutrals
    (let loop ([i 0]
               [result '()])
      (if (>= i text-len)
          (reverse result)
          (let* ([current-type (list-ref weak-types i)]
                 [current-level (list-ref levels i)])
            
            (cond
             ;; Already resolved or not neutral
             [(not (member current-type '(BC-WS BC-ON BC-S BC-B BC-ES BC-ET BC-CS)))
              (loop (+ i 1) (cons current-type result))]
             
             ;; Rule N1: Neutral between same strong types takes that type
             [else
              (let* ([preceding-strong (find-preceding-strong weak-types levels i)]
                     [following-strong (find-following-strong weak-types levels i)]
                     [resolved-type
                      (cond
                       ;; N1: Same strong type on both sides
                       [(and preceding-strong following-strong
                             (same-strong-type? preceding-strong following-strong))
                        (car preceding-strong)]
                       
                       ;; N2: Use embedding direction
                       [else
                        (if (even? current-level) BC-L BC-R)])])
                (loop (+ i 1) (cons resolved-type result)))]))))))

(define (find-preceding-strong types levels pos)
  "Find the preceding strong type with its level"
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
  "Find the following strong type with its level" 
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
  "Split text at position, adding necessary bidi controls to maintain state.
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
                                      [(and (> level 0) (eq? override 'BC-L)) '(#\x202D)]      ; LRO
                                      [(and (> level 0) (eq? override 'BC-R)) '(#\x202E)]      ; RLO
                                      [(and (> level 0) (odd? level) (eq? override 'neutral)) '(#\x202B)]  ; RLE
                                      [(and (> level 0) (even? level) (eq? override 'neutral)) '(#\x202A)] ; LRE
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
;;; Visual/Logical Order Conversion (Simplified Stubs)
;;; =================================================================

(define (visual-to-logical-order text levels)
  "Convert visual character order to logical order (simplified)"
  ;; This is a complex algorithm - providing stub for now
  (iota (string-length text)))

(define (logical-to-visual-order text levels)  
  "Convert logical character order to visual order (simplified)"
  ;; This is a complex algorithm - providing stub for now
  (iota (string-length text)))
