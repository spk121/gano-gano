;;; UAX #9 Unicode Bidirectional Algorithm - Advanced Bracket Processing
;;; Multi-line bracket tracking and editor utilities

(define-module (gano uax9-brackets)
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-9)        ; Record types
  #:use-module (srfi srfi-11)       ; let-values
  #:use-module (ice-9 format)       ; more powerful format
  #:use-module (gano char)          ; Import bidi class functionality
  #:use-module (gano string-utils)  ; String manipulation utilities
  #:use-module (gano uax9-core)     ; Core bidi algorithm
  #:export (
            ;; Enhanced bracket pair processing
            find-bracket-pairs-with-context
            process-bracket-pair
            find-strong-type-in-range
            find-matching-open-bracket-strict
            
            ;; Multi-line bracket context management
            process-multiple-lines
            split-line-with-bracket-context
            categorize-pairs-by-split
            categorize-unclosed-by-split
            
            ;; Record types
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
            
            ;; Code editor utilities
            find-all-bracket-pairs
            validate-bracket-structure
            find-matching-bracket-position
            get-bracket-nesting-level
            find-enclosing-brackets
            
            ;; Document analysis
            analyze-document-brackets
            find-bracket-errors-in-document
            get-bracket-context-for-line
            
            ;; Utility functions
            get-bracket-nesting-at-position
            print-bracket-context
            analyze-bracket-context))

;;; =================================================================
;;; Multi-line Bracket Records
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
;;; Enhanced Bracket Pair Processing
;;; =================================================================

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

(define (find-matching-open-bracket-strict stack close-char)
  "Find matching open bracket in stack, but only if it's the topmost matching bracket.
   Returns (matching-element . remaining-stack) or #f if no proper match."
  (let ([target-open (char-get-bracket-partner close-char)])
    (pk 'find-matching-open-brack-strict 'target-open target-open 'stack stack)
    (cond
     [(not target-open) #f]  ; Invalid closing bracket
     [(null? stack) #f]      ; No brackets to match
     [(char=? (cadar stack) target-open)
      ;; Perfect match - top of stack is the right bracket
      (cons (car stack) (cdr stack))]
     [else #f])))            ; Top of stack is different bracket - improper nesting

;;; =================================================================
;;; Line-aware Bracket Pair Processing
;;; =================================================================

(define* (find-bracket-pairs-with-context text types levels 
                                          #:key 
                                          (inherited-brackets '())
                                          (line-number 0)
                                          (global-offset 0))
  "Find bracket pairs in a single line, accounting for brackets from previous lines."
  
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
                           [spans-lines (or (not (= (open-bracket-line-number matched-open) line-number))
                                            ;; If line-number is default 0 and we have inherited brackets,
                                            ;; assume inherited brackets come from previous lines
                                            (and (= line-number 0) 
                                                 (not (null? inherited-brackets))
                                                 (member matched-open inherited-brackets)))]
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
  "Process multiple lines of text, maintaining bracket state across lines."
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
               [line-types (map (lambda (char) (char-get-bidi-class char)) 
                                (string->list line-text))]
               
               ;; Process brackets with context
               [context (find-bracket-pairs-with-context 
                         line-text line-types line-levels
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
                (cons context results))))))

;;; =================================================================
;;; Line Splitting with Bracket Awareness
;;; =================================================================

(define (split-line-with-bracket-context text split-position bracket-context)
  "Split a line while preserving bracket state information."
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
  "Categorize bracket pairs based on split position."
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
  "Categorize unclosed brackets based on split position."
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
;;; Code Editor Bracket Utilities
;;; =================================================================

(define* (find-all-bracket-pairs text #:key (inherited-brackets '()))
  "Find all bracket pairs in text, useful for syntax highlighting and navigation."
  (let* ([resolved-levels (resolve-paragraph-bidi text)]
         [char-types (map (lambda (char) (char-get-bidi-class char)) (string->list text))]
         [context (find-bracket-pairs-with-context 
                   text char-types resolved-levels
                   #:inherited-brackets inherited-brackets)])
    (bracket-context-line-pairs context)))

(define* (validate-bracket-structure text #:key (inherited-brackets '()))
  "Validate bracket structure for code editor, accounting for inherited brackets."
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
    ;; For single-line validation, unclosed brackets are not necessarily errors
    (cons #t unclosed)))  ; Return unclosed brackets as information

(define* (find-matching-bracket-position text position #:key (inherited-brackets '()))
  "Find the position of the matching bracket for bracket at given position."
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
  "Get the nesting level of brackets at a given position (0-based)."
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
                     text
                     types
		     levels
                     #:inherited-brackets inherited-brackets)])
      (get-bracket-nesting-at-position context position))]))

(define* (find-enclosing-brackets text position #:key (inherited-brackets '()))
  "Find the innermost bracket pair that encloses the given position."
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
  "Analyze bracket structure across an entire document."
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
  "Find bracket matching errors across an entire document."
  (let* ([analysis (analyze-document-brackets lines)]
         [final-unclosed (assoc-ref analysis 'final-unclosed-brackets)]
         [errors '()])
    
    ;; Check for unclosed brackets at end of document
    (when (not (null? final-unclosed))
      (set! errors (cons `(unclosed-brackets-at-end . ,final-unclosed) errors)))
    
    errors))

(define (get-bracket-context-for-line lines line-number)
  "Get the bracket context for a specific line in a document"
  (if (or (< line-number 0) (>= line-number (length lines)))
      #f
      (let ([contexts (process-multiple-lines (take lines (+ line-number 1)))])
        (if (> (length contexts) line-number)
            (list-ref contexts line-number)
            #f))))

;;; =================================================================
;;; Bracket Context Analysis and Debugging
;;; =================================================================

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

