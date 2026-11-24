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


;;; Enhanced weak type resolution with all W rules
(define (resolve-weak-types text explicit-levels base-level)
  "Complete weak character type resolution following all W rules."
  (let* ([text-len (string-length text)]
         [original-types (map (lambda (char) (char-get-bidi-class char)) (string->list text))]
         [levels (map car explicit-levels)])
    
    ;; Apply W rules in sequence
    (let* ([w1-types (apply-w1-rule original-types)]
           [w2-types (apply-w2-rule w1-types)]
           [w3-types (apply-w3-rule w2-types)]
           [w4-types (apply-w4-rule w3-types)]
           [w5-types (apply-w5-rule w4-types)]
           [w6-types (apply-w6-rule w5-types)]
           [w7-types (apply-w7-rule w6-types levels)])
      w7-types)))

;;; W1: NSM takes type of preceding character
(define (apply-w1-rule types)
  "W1: NSM takes the type of the preceding character."
  (if (null? types)
      '()
      (let loop ([remaining types]
                 [result (list (car types))])
        (if (null? (cdr remaining))
            (reverse result)
            (let ([current-type (cadr remaining)])
              (if (eq? current-type 'BC-NSM)
                  (loop (cdr remaining) (cons (car result) result))
                  (loop (cdr remaining) (cons current-type result))))))))

;;; W2: EN after AL becomes AN  
(define (apply-w2-rule types)
  "W2: European Number after Arabic Letter becomes Arabic Number."
  (let loop ([remaining types]
             [result '()]
             [last-strong 'BC-L])  ; Default to L
    (if (null? remaining)
        (reverse result)
        (let ([current-type (car remaining)])
          (case current-type
            [(BC-AL BC-R BC-L)
             (loop (cdr remaining) (cons current-type result) current-type)]
            [(BC-EN)
             (if (eq? last-strong 'BC-AL)
                 (loop (cdr remaining) (cons 'BC-AN result) last-strong)
                 (loop (cdr remaining) (cons current-type result) last-strong))]
            [else
             (loop (cdr remaining) (cons current-type result) last-strong)])))))

;;; W3: AL -> R
(define (apply-w3-rule types)
  "W3: Arabic Letter becomes R."
  (map (lambda (type)
         (if (eq? type 'BC-AL) 'BC-R type))
       types))

;;; W4: Single separator between same number types
(define (apply-w4-rule types)
  "W4: Single ES or CS between same number types takes that type."
  (if (< (length types) 3)
      types
      (let loop ([i 1]  ; Start from second element
                 [result (list (car types))])
        (if (>= i (- (length types) 1))
            (append (reverse result) (list (last types)))
            (let ([prev-type (list-ref types (- i 1))]
                  [curr-type (list-ref types i)]
                  [next-type (list-ref types (+ i 1))])
              (cond
               ;; ES between EN becomes EN
               [(and (eq? curr-type 'BC-ES)
                     (eq? prev-type 'BC-EN)
                     (eq? next-type 'BC-EN))
                (loop (+ i 1) (cons 'BC-EN result))]
               ;; CS between same number types
               [(and (eq? curr-type 'BC-CS)
                     (member prev-type '(BC-EN BC-AN))
                     (eq? prev-type next-type))
                (loop (+ i 1) (cons prev-type result))]
               [else
                (loop (+ i 1) (cons curr-type result))]))))))

;;; W5: Sequence of ET adjacent to EN becomes EN
(define (apply-w5-rule types)
  "W5: Sequence of ET adjacent to EN becomes EN."
  ;; This is a complex rule - simplified implementation
  (let loop ([remaining types]
             [result '()])
    (if (null? remaining)
        (reverse result)
        (let ([current-type (car remaining)])
          (if (eq? current-type 'BC-ET)
              ;; Look for adjacent EN to convert ET
              (let ([has-adjacent-en (or (and (not (null? result))
                                              (eq? (car result) 'BC-EN))
                                         (and (not (null? (cdr remaining)))
                                              (eq? (cadr remaining) 'BC-EN)))])
                (if has-adjacent-en
                    (loop (cdr remaining) (cons 'BC-EN result))
                    (loop (cdr remaining) (cons current-type result))))
              (loop (cdr remaining) (cons current-type result)))))))

;;; W6: All ET, ES, CS become ON
(define (apply-w6-rule types)
  "W6: ET, ES, CS become ON."
  (map (lambda (type)
         (if (member type '(BC-ET BC-ES BC-CS))
             'BC-ON
             type))
       types))

;;; W7: EN after L becomes L
(define (apply-w7-rule types levels)
  "W7: European Number after L becomes L."
  (let loop ([remaining types]
             [remaining-levels levels]
             [result '()]
             [last-strong 'BC-L])
    (if (null? remaining)
        (reverse result)
        (let ([current-type (car remaining)]
              [current-level (car remaining-levels)])
          (case current-type
            [(BC-L BC-R)
             (loop (cdr remaining) (cdr remaining-levels) 
                   (cons current-type result) current-type)]
            [(BC-EN)
             (if (eq? last-strong 'BC-L)
                 (loop (cdr remaining) (cdr remaining-levels)
                       (cons 'BC-L result) last-strong)
                 (loop (cdr remaining) (cdr remaining-levels)
                       (cons current-type result) last-strong))]
            [else
             (loop (cdr remaining) (cdr remaining-levels)
                   (cons current-type result) last-strong)])))))

;;; Enhanced neutral type resolution with proper bracket handling
(define (resolve-neutral-types text weak-types explicit-levels)
  "Enhanced neutral type resolution with bracket pair processing."
  (let* ([text-len (string-length text)]
         [levels (map car explicit-levels)]
         [bracket-pairs (find-bracket-pairs text weak-types levels)])
    
    ;; Apply N0 rule for bracket pairs first
    (let ([n0-types (apply-n0-rule weak-types bracket-pairs)])
      ;; Then apply N1 and N2 rules
      (apply-n1-n2-rules n0-types levels))))

;;; N0: Bracket pairs
(define (apply-n0-rule types bracket-pairs)
  "N0: Bracket pairs take the direction of their content."
  ;; Simplified implementation - just return original types for now
  ;; Full implementation would analyze bracket pair contents
  types)

;;; N1 and N2: Neutral character resolution
(define (apply-n1-n2-rules types levels)
  "Apply N1 and N2 rules for neutral character resolution."
  (let loop ([i 0]
             [result '()])
    (if (>= i (length types))
        (reverse result)
        (let* ([current-type (list-ref types i)]
               [current-level (list-ref levels i)])
          
          (cond
           ;; Already resolved - not neutral
           [(not (member current-type '(BC-WS BC-ON BC-S BC-B)))
            (loop (+ i 1) (cons current-type result))]
           
           ;; Neutral type - apply resolution rules
           [else
            (let* ([preceding-strong (find-preceding-strong-simple types i)]
                   [following-strong (find-following-strong-simple types i)]
                   [resolved-type
                    (cond
                     ;; N1: Same strong type on both sides  
                     [(and preceding-strong following-strong
                           (same-strong-type-simple? preceding-strong following-strong))
                      preceding-strong]
                     
                     ;; N2: Use embedding direction
                     [else
                      (if (even? current-level) 'BC-L 'BC-R)])])
              (loop (+ i 1) (cons resolved-type result)))])))))

;; Simplified helper functions for N1/N2
(define (find-preceding-strong-simple types pos)
  "Find the preceding strong type (simplified)."
  (let loop ([i (- pos 1)])
    (cond
     [(< i 0) #f]
     [else
      (let ([type (list-ref types i)])
        (cond
         [(member type '(BC-L BC-R BC-EN BC-AN)) type]
         [else (loop (- i 1))]))])))

(define (find-following-strong-simple types pos)
  "Find the following strong type (simplified)."
  (let loop ([i (+ pos 1)])
    (cond
     [(>= i (length types)) #f]
     [else
      (let ([type (list-ref types i)])
        (cond
         [(member type '(BC-L BC-R BC-EN BC-AN)) type]
         [else (loop (+ i 1))]))])))

(define (same-strong-type-simple? type1 type2)
  "Check if two strong types are the same for N1 purposes."
  (or (and (member type1 '(BC-L BC-EN)) (member type2 '(BC-L BC-EN)))
      (and (member type1 '(BC-R BC-AN)) (member type2 '(BC-R BC-AN)))))

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

#;(define (resolve-neutral-types text weak-types explicit-levels)
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
  "Main UAX #9 implementation with proper implicit level resolution."
  (if (string-null? text)
      '()
      (let* ([base-direction (paragraph-base-direction text)]
             [base-level (if (eq? base-direction 'rtl) 1 0)]
             [explicit-levels (resolve-explicit-levels text base-level)]
             [weak-types (resolve-weak-types text explicit-levels base-level)]
             [neutral-types (resolve-neutral-types text weak-types explicit-levels)])
        
        ;; Apply implicit level resolution (Rules I1-I2)
        (resolve-implicit-levels explicit-levels neutral-types))))

;;; Implicit Level Resolution (UAX #9 Rules I1-I2)
(define (resolve-implicit-levels explicit-levels final-types)
  "Apply implicit level resolution rules I1 and I2."
  (map (lambda (level-info final-type)
         (let ([level (car level-info)]
               [override (cdr level-info)])
           
           ;; Apply override first if present
           (cond
            [(eq? override 'BC-L) 
             ;; Override to L: use even level
             (if (even? level) level (+ level 1))]
            [(eq? override 'BC-R)
             ;; Override to R: use odd level  
             (if (odd? level) level (+ level 1))]
            [else
             ;; No override - apply implicit rules based on character type
             (cond
              ;; Rule I1: For odd embedding levels
              [(odd? level)
               (cond
                ;; I1a: R, AL, AN, EN -> level
                [(member final-type '(BC-R BC-AL BC-AN BC-EN)) level]
                ;; I1b: L -> level + 1  
                [(eq? final-type 'BC-L) (+ level 1)]
                ;; Others -> level
                [else level])]
              
              ;; Rule I2: For even embedding levels  
              [else
               (cond
                ;; I2a: L, EN -> level
                [(member final-type '(BC-L BC-EN)) level]
                ;; I2b: R, AL, AN -> level + 1
                [(member final-type '(BC-R BC-AL BC-AN)) (+ level 1)]
                ;; Others -> level
                [else level])])])))
       explicit-levels final-types))

#;(define (resolve-paragraph-bidi text)
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
