;;; Gano Character Buffer Operations Module
;;; Advanced operations beyond the minimum viable set
;;; Includes sophisticated SGR-aware insertion and text manipulation

(define-module (gano cbuf-operations)
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
  #:export (
    ;; Enhanced SGR-aware insertion
    cbuf-insert-string-default-sgr!
    cbuf-insert-string-inherit-sgr!
    cbuf-insert-string-with-sgr!
    
    ;; SGR validation for insertion
    validate-string-graphemes
    validate-sgr-grapheme-consistency
    validate-insertion-sgr-list
    
    ;; Grapheme analysis utilities
    string-grapheme-boundaries
    string-split-graphemes
    string-grapheme-count
    
    ;; Advanced position operations
    cbuf-goto-grapheme!
    cbuf-forward-grapheme!
    cbuf-backward-grapheme!
    
    ;; SGR manipulation at position
    cbuf-get-sgr-at-position
    cbuf-set-sgr-at-position!
    cbuf-set-sgr-range!
    
    ;; Enhanced text replacement
    cbuf-replace-text-with-sgr!
    cbuf-replace-range-with-sgr!
    
    ;; Error conditions for advanced operations
    &cbuf-invalid-grapheme-sequence
    cbuf-invalid-grapheme-sequence-error?
    cbuf-invalid-grapheme-sequence-error:string
    cbuf-invalid-grapheme-sequence-error:position
    cbuf-invalid-grapheme-sequence-error:reason
    
    &cbuf-sgr-grapheme-mismatch
    cbuf-sgr-grapheme-mismatch-error?
    cbuf-sgr-grapheme-mismatch-error:grapheme-start
    cbuf-sgr-grapheme-mismatch-error:grapheme-end
    cbuf-sgr-grapheme-mismatch-error:expected-sgr
    cbuf-sgr-grapheme-mismatch-error:actual-sgr))

;;; =================================================================
;;; ERROR CONDITIONS FOR ADVANCED OPERATIONS
;;; =================================================================

(define-condition-type &cbuf-invalid-grapheme-sequence &serious
  cbuf-invalid-grapheme-sequence-error?
  (string cbuf-invalid-grapheme-sequence-error:string)
  (position cbuf-invalid-grapheme-sequence-error:position)
  (reason cbuf-invalid-grapheme-sequence-error:reason))

(define-condition-type &cbuf-sgr-grapheme-mismatch &serious
  cbuf-sgr-grapheme-mismatch-error?
  (grapheme-start cbuf-sgr-grapheme-mismatch-error:grapheme-start)
  (grapheme-end cbuf-sgr-grapheme-mismatch-error:grapheme-end)
  (expected-sgr cbuf-sgr-grapheme-mismatch-error:expected-sgr)
  (actual-sgr cbuf-sgr-grapheme-mismatch-error:actual-sgr))

;;; =================================================================
;;; GRAPHEME ANALYSIS UTILITIES
;;; =================================================================

(define (string-grapheme-boundaries str)
  "Return list of indices where graphemes start in string.
   Each index marks the beginning of a new grapheme cluster."
  (let ([boundaries '(0)]  ; Always start with 0
        [len (string-length str)])
    
    (let loop ([i 1])
      (if (>= i len)
          (reverse (cons len boundaries))  ; Add final boundary
          (let ([char (string-ref str i)])
            (unless (char-combining-mark? char)
              ;; This is a base character, so it starts a new grapheme
              (set! boundaries (cons i boundaries)))
            (loop (+ i 1)))))))

(define (string-split-graphemes str)
  "Split string into list of graphemes (base char + combining marks)"
  (let* ([boundaries (string-grapheme-boundaries str)]
         [boundary-pairs (map list boundaries (cdr boundaries))])
    
    (map (lambda (pair)
           (substring str (car pair) (cadr pair)))
         boundary-pairs)))

(define (string-grapheme-count str)
  "Return number of graphemes in string"
  (- (length (string-grapheme-boundaries str)) 1))

(define (validate-string-graphemes str)
  "Validate that string contains only complete graphemes with proper limits.
   Returns (valid? error-info)"
  (cond
    ;; Empty string is valid
    [(string-null? str) 
     (list #t #f)]
    
    ;; Check if starts with combining mark
    [(char-combining-mark? (string-ref str 0))
     (list #f (list 'starts-with-combining-mark 0 (string-ref str 0)))]
    
    [else
     ;; Check each grapheme for combining mark limits
     (let ([boundaries (string-grapheme-boundaries str)])
       (let loop ([boundary-pairs (map list boundaries (cdr boundaries))]
                  [grapheme-index 0])
         (cond
           [(null? boundary-pairs) 
            (list #t #f)]  ; All graphemes valid
           
           [else
            (let* ([pair (car boundary-pairs)]
                   [start (car pair)]
                   [end (cadr pair)]
                   [grapheme (substring str start end)]
                   [combining-count (- (string-length grapheme) 1)])  ; -1 for base char
              
              (cond
                ;; Too many combining marks
                [(> combining-count MAX-COMBINING-MARKS)
                 (list #f (list 'too-many-combining-marks start end combining-count))]
                
                ;; This grapheme is valid, check next
                [else
                 (loop (cdr boundary-pairs) (+ grapheme-index 1))]))]))]))

(define (validate-sgr-grapheme-consistency str sgr-list)
  "Validate that all SGR records within each grapheme are identical.
   Returns (valid? error-info)"
  (cond
    [(not (= (string-length str) (length sgr-list)))
     (list #f (list 'length-mismatch (string-length str) (length sgr-list)))]
    
    [(string-null? str)
     (list #t #f)]
    
    [else
     (let ([boundaries (string-grapheme-boundaries str)])
       (let loop ([boundary-pairs (map list boundaries (cdr boundaries))])
         (cond
           [(null? boundary-pairs) 
            (list #t #f)]  ; All graphemes consistent
           
           [else
            (let* ([pair (car boundary-pairs)]
                   [start (car pair)]
                   [end (cadr pair)]
                   [grapheme-sgrs (take (drop sgr-list start) (- end start))])
              
              (if (null? grapheme-sgrs)
                  (loop (cdr boundary-pairs))  ; Empty grapheme, continue
                  
                  ;; Check if all SGRs in this grapheme are equal
                  (let ([first-sgr (car grapheme-sgrs)])
                    (if (every (lambda (sgr) (sgr-equal? sgr first-sgr)) grapheme-sgrs)
                        (loop (cdr boundary-pairs))  ; This grapheme consistent
                        
                        ;; Found inconsistency
                        (let ([inconsistent-pos (+ start 
                                                   (list-index (lambda (sgr) 
                                                                (not (sgr-equal? sgr first-sgr))) 
                                                              grapheme-sgrs))])
                          (list #f (list 'sgr-mismatch start end first-sgr 
                                        (list-ref sgr-list inconsistent-pos))))))))]))]))

(define (validate-insertion-sgr-list str sgr-list)
  "Comprehensive validation for string and SGR list insertion.
   Returns (valid? error-list)"
  (let ([errors '()])
    
    ;; Check string length matches SGR list length
    (unless (= (string-length str) (length sgr-list))
      (set! errors (cons (list 'length-mismatch (string-length str) (length sgr-list)) errors)))
    
    ;; Validate grapheme structure
    (let ([grapheme-validation (validate-string-graphemes str)])
      (unless (car grapheme-validation)
        (set! errors (cons (cadr grapheme-validation) errors))))
    
    ;; Validate SGR consistency within graphemes
    (when (= (string-length str) (length sgr-list))  ; Only if lengths match
      (let ([sgr-validation (validate-sgr-grapheme-consistency str sgr-list)])
        (unless (car sgr-validation)
          (set! errors (cons (cadr sgr-validation) errors)))))
    
    ;; Return results
    (if (null? errors)
        (list #t '())
        (list #f (reverse errors)))))

;;; =================================================================
;;; ENHANCED SGR-AWARE INSERTION OPERATIONS
;;; =================================================================

(define (cbuf-insert-string-default-sgr! cbuf str)
  "Insert string using the buffer's current default SGR for all characters"
  ;; Validate string structure
  (let ([validation (validate-string-graphemes str)])
    (unless (car validation)
      (let ([error-info (cadr validation)])
        (raise (condition (&cbuf-invalid-grapheme-sequence
                           (string str)
                           (position 0)
                           (reason error-info)))))))
  
  ;; Use the basic insertion which already uses current SGR
  (cbuf-insert-string! cbuf str))

(define (cbuf-insert-string-inherit-sgr! cbuf str)
  "Insert string using the SGR that existed at the insertion point.
   If at end of line, uses current default SGR."
  ;; Validate string structure
  (let ([validation (validate-string-graphemes str)])
    (unless (car validation)
      (let ([error-info (cadr validation)])
        (raise (condition (&cbuf-invalid-grapheme-sequence
                           (string str)
                           (position 0)
                           (reason error-info)))))))
  
  (let* ([x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)]
         [text (cbuf-text-cur cbuf)]
         [sgr-list (cbuf-sgr-list-cur cbuf)]
         
         ;; Determine SGR to inherit
         [inherit-sgr (cond
                        ;; At end of line - use current default
                        [(>= x-index (string-length text))
                         (cbuf-current-sgr cbuf)]
                        
                        ;; In middle of line - inherit from position
                        [else
                         (list-ref sgr-list x-index)])]
         
         ;; Create SGR list for insertion
         [insert-sgr-list (make-list (string-length str) inherit-sgr)])
    
    ;; Validate and insert
    (cbuf-insert-string-with-sgr! cbuf str insert-sgr-list)))

(define (cbuf-insert-string-with-sgr! cbuf str sgr-list)
  "Insert string with explicit SGR list, validating grapheme consistency"
  ;; Comprehensive validation
  (let ([validation (validate-insertion-sgr-list str sgr-list)])
    (unless (car validation)
      (let ([errors (cadr validation)])
        ;; Raise appropriate error for first issue found
        (let ([first-error (car errors)])
          (case (car first-error)
            [(length-mismatch)
             (error "String length doesn't match SGR list length" 
                    (cadr first-error) (caddr first-error))]
            
            [(starts-with-combining-mark)
             (raise (condition (&cbuf-invalid-grapheme-sequence
                                (string str)
                                (position (cadr first-error))
                                (reason "String starts with combining mark"))))]
            
            [(too-many-combining-marks)
             (raise (condition (&cbuf-invalid-grapheme-sequence
                                (string str)
                                (position (cadr first-error))
                                (reason (format #f "Too many combining marks: ~a > ~a" 
                                               (cadddr first-error) MAX-COMBINING-MARKS)))))]
            
            [(sgr-mismatch)
             (raise (condition (&cbuf-sgr-grapheme-mismatch
                                (grapheme-start (cadr first-error))
                                (grapheme-end (caddr first-error))
                                (expected-sgr (cadddr first-error))
                                (actual-sgr (cadddr (cdr first-error))))))]
            
            [else
             (error "String insertion validation failed" first-error)])))))
  
  ;; Validation passed - perform insertion
  (let* ([x-data (cbuf-x-data cbuf)]
         [text (cbuf-text-cur cbuf)]
         [current-sgr-list (cbuf-sgr-list-cur cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)])
    
    ;; Save undo state
    (let ([old-metrics (cbuf-metrics-cur cbuf)])
      (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 
                                         'insert-string-with-sgr str sgr-list))
    
    ;; Insert the string and SGR list
    (let* ([new-text (string-insert-string text x-index str)]
           [new-sgr-list (append (take current-sgr-list x-index)
                                sgr-list
                                (drop current-sgr-list x-index))])
      
      ;; Update the line
      (cbuf-set-text-cur! cbuf new-text new-sgr-list)
      
      ;; Move cursor to end of inserted text
      (cbuf-set-x! cbuf (+ x-data (string-grapheme-count str)) 'data)
      
      ;; Mark as modified
      (set-cbuf-modified?! cbuf #t))))

;;; =================================================================
;;; ADVANCED POSITION OPERATIONS
;;; =================================================================

(define (cbuf-goto-grapheme! cbuf grapheme-index)
  "Move cursor to the start of the specified grapheme (0-based)"
  (let* ([text (cbuf-text-cur cbuf)]
         [boundaries (string-grapheme-boundaries text)]
         [max-grapheme (- (length boundaries) 2)])  ; -1 for 0-based, -1 for final boundary
    
    (when (and (>= grapheme-index 0) (<= grapheme-index max-grapheme))
      (let ([target-index (list-ref boundaries grapheme-index)])
        (cbuf-set-x! cbuf (cbuf-x-index->x-data cbuf target-index) 'data)))))

(define (cbuf-forward-grapheme! cbuf)
  "Move cursor forward by one complete grapheme"
  (let* ([text (cbuf-text-cur cbuf)]
         [x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)]
         [boundaries (string-grapheme-boundaries text)])
    
    ;; Find next boundary after current position
    (let ([next-boundary (find (lambda (boundary) (> boundary x-index)) boundaries)])
      (when next-boundary
        (cbuf-set-x! cbuf (cbuf-x-index->x-data cbuf next-boundary) 'data)))))

(define (cbuf-backward-grapheme! cbuf)
  "Move cursor backward by one complete grapheme"
  (let* ([text (cbuf-text-cur cbuf)]
         [x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)]
         [boundaries (string-grapheme-boundaries text)])
    
    ;; Find previous boundary before current position
    (let ([prev-boundary (find (lambda (boundary) (< boundary x-index)) 
                              (reverse boundaries))])
      (when prev-boundary
        (cbuf-set-x! cbuf (cbuf-x-index->x-data cbuf prev-boundary) 'data)))))

;;; =================================================================
;;; SGR MANIPULATION AT POSITION
;;; =================================================================

(define (cbuf-get-sgr-at-position cbuf)
  "Get SGR at current cursor position"
  (text-metrics-get-sgr-at-data (cbuf-metrics-cur cbuf) (cbuf-x-data cbuf)))

(define (cbuf-set-sgr-at-position! cbuf sgr)
  "Set SGR at current cursor position, extending to whole grapheme"
  (let* ([text (cbuf-text-cur cbuf)]
         [x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)]
         [boundaries (string-grapheme-boundaries text)])
    
    ;; Find grapheme boundaries containing current position
    (let loop ([boundary-pairs (map list boundaries (cdr boundaries))])
      (when (not (null? boundary-pairs))
        (let* ([pair (car boundary-pairs)]
               [start (car pair)]
               [end (cadr pair)])
          
          (if (and (>= x-index start) (< x-index end))
              ;; Found the grapheme - set SGR for entire grapheme
              (let* ([current-metrics (cbuf-metrics-cur cbuf)]
                     [old-metrics current-metrics]
                     [new-metrics (text-metrics-set-sgr-range current-metrics start end sgr)])
                
                ;; Save undo and update
                (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 'set-sgr-at-position sgr)
                (cbuf-update-metrics-cur! cbuf new-metrics))
              
              ;; Continue searching
              (loop (cdr boundary-pairs))))))))

(define (cbuf-set-sgr-range! cbuf start-data end-data sgr)
  "Set SGR for a range of data positions, respecting grapheme boundaries"
  (let* ([text (cbuf-text-cur cbuf)]
         [start-index (cbuf-x-data->x-index cbuf start-data)]
         [end-index (cbuf-x-data->x-index cbuf end-data)]
         [boundaries (string-grapheme-boundaries text)])
    
    ;; Expand range to complete graphemes
    (let* ([expanded-start (find (lambda (b) (<= b start-index)) (reverse boundaries))]
           [expanded-end (find (lambda (b) (>= b end-index)) boundaries)]
           [safe-start (or expanded-start start-index)]
           [safe-end (or expanded-end end-index)])
      
      ;; Apply SGR to expanded range
      (let* ([current-metrics (cbuf-metrics-cur cbuf)]
             [old-metrics current-metrics]
             [new-metrics (text-metrics-set-sgr-range current-metrics safe-start safe-end sgr)])
        
        ;; Save undo and update
        (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 'set-sgr-range start-data end-data sgr)
        (cbuf-update-metrics-cur! cbuf new-metrics)))))

;;; =================================================================
;;; ENHANCED TEXT REPLACEMENT
;;; =================================================================

(define (cbuf-replace-text-with-sgr! cbuf old-text new-text new-sgr-list)
  "Replace first occurrence of old-text with new-text and SGR list"
  (let* ([current-text (cbuf-text-cur cbuf)]
         [match-pos (string-find-string current-text old-text)])
    
    (when match-pos
      ;; Validate replacement text and SGR
      (let ([validation (validate-insertion-sgr-list new-text new-sgr-list)])
        (unless (car validation)
          (error "Invalid replacement text or SGR" (cadr validation))))
      
      ;; Perform replacement
      (let* ([match-end (+ match-pos (string-length old-text))]
             [match-data-start (cbuf-x-index->x-data cbuf match-pos)]
             [match-data-end (cbuf-x-index->x-data cbuf match-end)])
        
        ;; Delete old text and insert new
        (cbuf-set-x! cbuf match-data-start 'data)
        (cbuf-delete-region! cbuf (cbuf-line-cur cbuf) match-data-start 
                            (cbuf-line-cur cbuf) match-data-end)
        (cbuf-insert-string-with-sgr! cbuf new-text new-sgr-list)))))

(define (cbuf-replace-range-with-sgr! cbuf start-line start-data end-line end-data new-text new-sgr-list)
  "Replace a range with new text and SGR list"
  ;; Validate replacement text and SGR
  (let ([validation (validate-insertion-sgr-list new-text new-sgr-list)])
    (unless (car validation)
      (error "Invalid replacement text or SGR" (cadr validation))))
  
  ;; Position at start of range
  (cbuf-set-y! cbuf start-line)
  (cbuf-set-x! cbuf start-data 'data)
  
  ;; Delete range and insert replacement
  (cbuf-delete-region! cbuf start-line start-data end-line end-data)
  (cbuf-insert-string-with-sgr! cbuf new-text new-sgr-list))

;;; =================================================================
;;; UTILITY FUNCTIONS FOR SGR OPERATIONS
;;; =================================================================

(define (cbuf-copy-sgr-from-position cbuf source-data)
  "Copy SGR from a specific data position"
  (let ([source-index (cbuf-x-data->x-index cbuf source-data)])
    (if (and (>= source-index 0) (< source-index (cbuf-text-cur-length cbuf)))
        (list-ref (cbuf-sgr-list-cur cbuf) source-index)
        (cbuf-current-sgr cbuf))))

(define (cbuf-create-sgr-list-from-template cbuf template-sgr length)
  "Create SGR list of specified length using template SGR"
  (make-list length (sgr-copy template-sgr)))

(define (cbuf-create-default-sgr-list cbuf length)
  "Create SGR list of specified length using buffer's current SGR"
  (make-list length (cbuf-current-sgr cbuf)))

;;; =================================================================
;;; DEBUGGING AND INSPECTION UTILITIES
;;; =================================================================

(define (cbuf-analyze-graphemes cbuf)
  "Return detailed analysis of graphemes in current line"
  (let* ([text (cbuf-text-cur cbuf)]
         [boundaries (string-grapheme-boundaries text)]
         [graphemes (string-split-graphemes text)])
    
    `((text . ,text)
      (grapheme-count . ,(length graphemes))
      (codepoint-count . ,(string-length text))
      (boundaries . ,boundaries)
      (graphemes . ,(map (lambda (g i)
                          `((index . ,i)
                            (text . ,g)
                            (length . ,(string-length g))
                            (combining-marks . ,(- (string-length g) 1))))
                        graphemes (iota (length graphemes)))))))

(define (cbuf-analyze-sgr-consistency cbuf)
  "Analyze SGR consistency within graphemes on current line"
  (let* ([text (cbuf-text-cur cbuf)]
         [sgr-list (cbuf-sgr-list-cur cbuf)]
         [boundaries (string-grapheme-boundaries text)])
    
    (let loop ([boundary-pairs (map list boundaries (cdr boundaries))]
               [grapheme-index 0]
               [results '()])
      
      (if (null? boundary-pairs)
          (reverse results)
          
          (let* ([pair (car boundary-pairs)]
                 [start (car pair)]
                 [end (cadr pair)]
                 [grapheme (substring text start end)]
                 [grapheme-sgrs (take (drop sgr-list start) (- end start))]
                 [consistent? (if (null? grapheme-sgrs)
                                 #t
                                 (every (lambda (sgr) (sgr-equal? sgr (car grapheme-sgrs))) 
                                       grapheme-sgrs))])
            
            (loop (cdr boundary-pairs)
                  (+ grapheme-index 1)
                  (cons `((grapheme-index . ,grapheme-index)
                          (text . ,grapheme)
                          (start . ,start)
                          (end . ,end)
                          (sgr-consistent . ,consistent?)
                          (sgr-count . ,(length grapheme-sgrs)))
                        results)))))))

;;; =================================================================
;;; EXAMPLES AND TESTING UTILITIES
;;; =================================================================

(define (test-cbuf-operations)
  "Test the advanced cbuf operations"
  (let ([cbuf (make-cbuf)])
    
    (format #t "=== Testing Advanced CBuf Operations ===~%~%")
    
    ;; Test basic insertion with default SGR
    (format #t "1. Testing default SGR insertion:~%")
    (cbuf-insert-string-default-sgr! cbuf "Hello")
    (format #t "   Text: ~s~%" (cbuf-text-cur cbuf))
    
    ;; Test insertion with inherited SGR
    (format #t "~%2. Testing inherited SGR insertion:~%")
    (cbuf-insert-string-inherit-sgr! cbuf " World")
    (format #t "   Text: ~s~%" (cbuf-text-cur cbuf))
    
    ;; Test grapheme analysis
    (format #t "~%3. Testing grapheme analysis:~%")
    (cbuf-clear! cbuf)
    (cbuf-insert-string-default-sgr! cbuf "café")  ; e with combining acute
    (let ([analysis (cbuf-analyze-graphemes cbuf)])
      (format #t "   Analysis: ~a~%" analysis))
    
    ;; Test SGR operations
    (format #t "~%4. Testing SGR operations:~%")
    (let ([bold-sgr (make-default-sgr)])
      (sgr-apply-attribute! bold-sgr 'intensity-bold)
      (cbuf-set-sgr-at-position! cbuf bold-sgr)
      (format #t "   Applied bold SGR at position~%"))
    
    (format #t "~%=== Testing Complete ===~%")))
    