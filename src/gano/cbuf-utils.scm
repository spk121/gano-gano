;;; Gano Character Buffer Utilities Module
;;; Pure utility functions extracted from cbuf module

(define-module (gano cbuf-utils)
  #:use-module (gano char)          ; Character utilities
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-34)       ; Raise for conditions
  #:use-module (srfi srfi-35)       ; Condition types
  #:export (
    ;; Constants
    MAX-COMBINING-MARKS

    ;; Validation functions
    validate-string-combining-marks
    validate-combining-marks-at-insertion
    validate-combining-mark-limits
    count-combining-marks-in-cluster
    count-base-characters

    ;; Tab computation
    compute-tab-column

    ;; Word boundary detection
    find-word-end-forward
    find-word-begin-backward
    skip-word-chars-forward
    skip-word-chars-backward
    skip-whitespace-forward
    skip-whitespace-backward
    skip-delimiters-forward
    skip-delimiters-backward
    char-word-delimiter?

    ;; Line ending detection
    detect-line-ending

    ;; Position validation helpers
    validate-line-movement-pure
    validate-column-movement-pure
    validate-absolute-position-pure

    ;; Error condition constructors (pure data)
    make-boundary-error-info
    make-combining-mark-error-info
    
    ;;; Error conditions for combining sequences
    &cbuf-invalid-combining-sequence
    cbuf-invalid-combining-sequence-error?
    cbuf-invalid-combining-sequence-error:base-char
    cbuf-invalid-combining-sequence-error:combining-char
    cbuf-invalid-combining-sequence-error:current-count
    cbuf-invalid-combining-sequence-error:max-count
    
    &cbuf-too-many-combining-marks
    cbuf-too-many-combining-marks-error?
    cbuf-too-many-combining-marks-error:base-char
    cbuf-too-many-combining-marks-error:combining-char
    cbuf-too-many-combining-marks-error:current-count
    cbuf-too-many-combining-marks-error:max-count    
  ))

;;; Error conditions for combining marks
(define-condition-type &cbuf-invalid-combining-sequence &serious
  cbuf-invalid-combining-sequence-error?
  (base-char cbuf-invalid-combining-sequence-error:base-char)
  (combining-char cbuf-invalid-combining-sequence-error:combining-char)
  (current-count cbuf-invalid-combining-sequence-error:current-count)
  (max-count cbuf-invalid-combining-sequence-error:max-count))

(define-condition-type &cbuf-too-many-combining-marks &serious
  cbuf-too-many-combining-marks-error?
  (base-char cbuf-too-many-combining-marks-error:base-char)
  (combining-char cbuf-too-many-combining-marks-error:combining-char)
  (current-count cbuf-too-many-combining-marks-error:current-count)
  (max-count cbuf-too-many-combining-marks-error:max-count))

;; Maximum combining marks per base character (matches ncurses cchar_t)
(define MAX-COMBINING-MARKS 4)

;;; =================================================================
;;; VALIDATION FUNCTIONS
;;; =================================================================

(define (validate-string-combining-marks str)
  "Validate entire string for combining mark limits.
   Returns: (valid? violations-list) where violations-list contains all issues found."
  (let ([violations '()]
        [current-base-char #f]
        [current-base-index #f]
        [combining-count 0])
    
    (let loop ([i 0])
      (cond
       [(>= i (string-length str)) 
        ;; End of string - return results
        (list (null? violations) (reverse violations))]
       
       [else
        (let ([ch (string-ref str i)])
          (cond
           [(char-combining-mark? ch)
            ;; This is a combining mark
            (cond
             [(not current-base-char)
              ;; No base character for this combining mark
              (set! violations (cons (list 'no-base-character ch i 0) violations))
              (loop (+ i 1))]
             
             [else
              ;; Have a base character - check count
              (set! combining-count (+ combining-count 1))
              (when (> combining-count MAX-COMBINING-MARKS)
                (set! violations (cons (list 'too-many-combining 
                                            current-base-char ch 
                                            current-base-index i 
                                            combining-count) violations)))
              (loop (+ i 1))])]
           
           [else
            ;; This is a base character - reset state
            (set! current-base-char ch)
            (set! current-base-index i)
            (set! combining-count 0)
            (loop (+ i 1))]))]))))

(define (validate-combining-marks-at-insertion str insertion-point insert-str)
  "Validate combining marks when inserting INSERT-STR at INSERTION-POINT in STR.
   Only validates the boundary conditions around the insertion point.
   Returns: (valid? violation-info)"
  (let* ([before-str (substring str 0 insertion-point)]
         [after-str (substring str insertion-point)]
         [new-str (string-append before-str insert-str after-str)]
         
         ;; Only need to validate around the insertion boundaries
         [start-check (max 0 (- insertion-point 10))]  ; Check a few chars before
         [end-check (min (string-length new-str) 
                        (+ insertion-point (string-length insert-str) 10))] ; Check a few chars after
         [check-region (substring new-str start-check end-check)])
    
    ;; Validate just the region around the insertion
    (validate-string-combining-marks check-region)))


#;(define (validate-combining-mark-limits str)
  "Validate that no grapheme cluster in STR exceeds the combining mark limit.
   Raises &cbuf-too-many-combining-marks if limit exceeded."
  (let ([current-base-char #f]
        [combining-count 0])
    
    (string-for-each
     (lambda (ch)
       (cond
        [(char-combining-mark? ch)
         ;; This is a combining mark
         (unless current-base-char
           ;; Use proper condition raising - create condition first, then raise
           (let ([condition (make-condition &cbuf-invalid-combining-sequence
                                           'base-char #f
                                           'combining-char ch
                                           'current-count 0
                                           'max-count MAX-COMBINING-MARKS)])
             (raise condition)))
         (set! combining-count (+ combining-count 1))
         (when (> combining-count MAX-COMBINING-MARKS)
           ;; Use proper condition raising
           (let ([condition (make-condition &cbuf-too-many-combining-marks
                                           'base-char current-base-char
                                           'combining-char ch
                                           'current-count combining-count
                                           'max-count MAX-COMBINING-MARKS)])
             (raise condition)))]
        
        [else
         ;; This is a base character, reset the count
         (set! current-base-char ch)
         (set! combining-count 0)]))
     str)))

(define (validate-combining-mark-limits str)
  "Validate that no grapheme cluster in STR exceeds the combining mark limit.
   Raises &cbuf-too-many-combining-marks if limit exceeded."
  (let ([current-base-char #f]
        [combining-count 0])
    
    (string-for-each
     (lambda (ch)
       (cond
        [(char-combining-mark? ch)
         ;; This is a combining mark
         (unless current-base-char
	   (raise (condition (&cbuf-invalid-combining-sequence
			      (base-char #f)
			      (combining-char ch)
			      (current-count combining-count)
			      (max-count MAX-COMBINING-MARKS)))))
         (set! combining-count (+ combining-count 1))
         (when (> combining-count MAX-COMBINING-MARKS)
           (raise (condition (&cbuf-too-many-combining-marks
                              (base-char current-base-char)
                              (combining-char ch)
                              (current-count combining-count)
                              (max-count MAX-COMBINING-MARKS)))))]
        
        [else
         ;; This is a base character, reset the count
         (set! current-base-char ch)
         (set! combining-count 0)]))
     str)))


(define (count-combining-marks-in-cluster str start-index)
  "Count combining marks starting from start-index until next base character or end of string"
  (let ([len (string-length str)])
    (let loop ([i (+ start-index 1)] [count 0])
      (cond
       [(>= i len) count]
       [(char-combining-mark? (string-ref str i))
        (loop (+ i 1) (+ count 1))]
       [else count]))))


;;; =================================================================
;;; STRING ANALYSIS
;;; =================================================================
(define (count-base-characters str)
  "Count non-combining characters in string efficiently"
  (let loop ([i 0] [count 0])
    (if (>= i (string-length str))
        count
        (if (char-combining-mark? (string-ref str i))
            (loop (+ i 1) count)
            (loop (+ i 1) (+ count 1))))))
;;; =================================================================
;;; LINE ENDING DETECTION
;;; =================================================================

(define (detect-line-ending str)
  "Detect the primary line ending used in string.
   Counts all 5 line ending types and returns the most common one.
   Priority order for ties: LF, CRLF, CR, LS, PS.
   Returns \\n as default if no line endings found."
  (let* ([len (string-length str)])
    ;; Helper function to safely check character at position
    (define (char-at-pos? i char)
      (and (< i len) (char=? (string-ref str i) char)))
    ;; Count all line ending types using recursion
    (let loop ([i 0] [crlf-count 0] [lf-count 0] [cr-count 0] [ls-count 0] [ps-count 0])
      (cond
        ;; Check for CRLF first (2 characters)
        [(and (char-at-pos? i #\return) 
              (char-at-pos? (+ i 1) #\newline))
         (loop (+ i 2) (+ crlf-count 1) lf-count cr-count ls-count ps-count)]
        ;; Single character line endings
        [(char-at-pos? i #\newline)
         (loop (+ i 1) crlf-count (+ lf-count 1) cr-count ls-count ps-count)]
        [(char-at-pos? i #\return)
         (loop (+ i 1) crlf-count lf-count (+ cr-count 1) ls-count ps-count)]
        [(char-at-pos? i #\x2028)  ; Line Separator
         (loop (+ i 1) crlf-count lf-count cr-count (+ ls-count 1) ps-count)]
        [(char-at-pos? i #\x2029)  ; Paragraph Separator
         (loop (+ i 1) crlf-count lf-count cr-count ls-count (+ ps-count 1))]
        ;; Regular character - continue
        [(< i len)
         (loop (+ i 1) crlf-count lf-count cr-count ls-count ps-count)]
        ;; End of string - find most common with priority
        [else
         (let* ([counts (list (cons lf-count "\n")      ; Priority 1
                             (cons crlf-count "\r\n")   ; Priority 2  
                             (cons cr-count "\r")       ; Priority 3
                             (cons ls-count "\u2028")   ; Priority 4
                             (cons ps-count "\u2029"))] ; Priority 5
                [max-count (apply max (map car counts))])
           (cond
             ;; No line endings found
             [(= max-count 0) "\n"]
             ;; Find first (highest priority) entry with max count
             [else
              (let find-max ([remaining counts])
                (cond
                  [(null? remaining) "\n"]  ; Fallback
                  [(= (caar remaining) max-count) (cdar remaining)]
                  [else (find-max (cdr remaining))]))]))]))))

;;; =================================================================
;;; TAB COMPUTATION
;;; =================================================================

(define (compute-tab-column pos tabsize n)
  "If N is positive, compute the presentation position of the nth next
forward tabulation. If N is negative, compute the position of the
backward tabulation. This function does not do bracketing."
  (cond
   [(< n 0)
    ;; Move backward n tab stops
    (let* ([current-tab-pos (if (zero? (remainder pos tabsize))
                               ;; Already at a tab stop
                               (quotient pos tabsize)
                               ;; Between tab stops, consider current tab as the next one
                               (+ (quotient pos tabsize) 1))]
           [target-tab-pos (+ current-tab-pos n)]
           [result (* (max 0 target-tab-pos) tabsize)])
      result)]
   [(= n 0) pos]
   [(> n 0)
    ;; Advance to next tab stop, then forward n-1 more
    (let* ([next-tab (* tabsize (+ (quotient pos tabsize) 1))]
           [final-tab (+ next-tab (* (- n 1) tabsize))])
      final-tab)]))

;;; =================================================================
;;; WORD BOUNDARY DETECTION
;;; =================================================================

(define (find-word-end-forward txt start-index delimiter-pred)
  "Find the index after the current word ends"
  (let ([len (string-length txt)])
    (cond
     [(>= start-index len) len]
     [else
      ;; If we're starting on a delimiter (like whitespace), skip to next word first
      (let ([word-start (if (and (< start-index len)
                                (delimiter-pred (string-ref txt start-index)))
                           ;; Skip delimiters to find start of next word
                           (skip-whitespace-forward txt start-index)
                           ;; Already on a word character
                           start-index)])
        ;; Now find the end of this word
        (skip-word-chars-forward txt word-start delimiter-pred))])))

(define (find-word-begin-backward txt start-index delimiter-pred)
  "Find the index where the current word begins"
  (cond
   [(<= start-index 0) 0]
   [else
    ;; Skip preceding whitespace first (if we're on whitespace)
    (let ([before-whitespace (skip-whitespace-backward txt (- start-index 0))])
      ;; Skip back through word characters
      (skip-word-chars-backward txt before-whitespace delimiter-pred))]))

(define (skip-word-chars-forward txt start-index delimiter-pred)
  "Skip forward through word characters, return index after word"
  (let ([len (string-length txt)])
    (let loop ([i start-index])
      (cond
       [(>= i len) len]
       [(delimiter-pred (string-ref txt i)) i]
       [else (loop (+ i 1))]))))

(define (skip-word-chars-backward txt start-index delimiter-pred)
  "Skip backward through word characters, return index at word start"
  (let loop ([i start-index])
    (cond
     [(< i 0)
      0]
     [(and (< i (string-length txt)) (delimiter-pred (string-ref txt i)))
      (+ i 1)]
     [else
      (loop (- i 1))])))

(define (skip-whitespace-forward txt start-index)
  "Skip forward through whitespace, return index after whitespace"
  (let ([len (string-length txt)])
    (let loop ([i start-index])
      (cond
       [(>= i len) len]
       [(not (char-whitespace? (string-ref txt i))) i]
       [else (loop (+ i 1))]))))

(define (skip-whitespace-backward txt start-index)
  "Skip backward through whitespace, return index before whitespace"
  (let loop ([i start-index])
    (cond
     [(<= i 0) 0]
     [(not (char-whitespace? (string-ref txt i))) i]
     [else (loop (- i 1))])))

(define (skip-delimiters-forward txt start-index)
  "Skip forward through delimiters (whitespace + punctuation), return index after delimiters"
  (let ([len (string-length txt)])
    (let loop ([i start-index])
      (cond
       [(>= i len) len]
       [(not (char-word-delimiter? (string-ref txt i))) i]
       [else (loop (+ i 1))]))))

(define (skip-delimiters-backward txt start-index)
  "Skip backward through delimiters (whitespace + punctuation), return index before delimiters"
  (let loop ([i start-index])
    (cond
     [(<= i 0) 0]
     [(not (char-word-delimiter? (string-ref txt i))) i]
     [else (loop (- i 1))])))

(define (char-word-delimiter? ch)
  "True if character delimits a 'word' (punctuation + whitespace)"
  (or (char-whitespace? ch)
      (char-set-contains? char-set:punctuation ch)
      (char-set-contains? char-set:symbol ch)))

;;; =================================================================
;;; POSITION VALIDATION HELPERS (Pure functions)
;;; =================================================================

(define (validate-line-movement-pure current-line delta max-line operation)
  "Pure version of line movement validation.
   Returns (target-line clamped-line clamped? operation)"
  (let* ([target-line (+ current-line delta)]
         [clamped-line (max 0 (min target-line max-line))]
         [clamped? (not (= target-line clamped-line))])
    (list target-line clamped-line clamped? operation)))
    

(define (validate-column-movement-pure current-column delta max-column operation)
  "Pure version of column movement validation.
   Returns (target-column clamped-column clamped? operation)"
  (let* ([target-column (+ current-column delta)]
         [clamped-column (max 0 (min target-column max-column))]
         [clamped? (not (= target-column clamped-column))])
    (list target-column clamped-column clamped? operation)))

(define (validate-absolute-position-pure line column max-line max-column operation)
  "Pure version of absolute positioning validation.
   Returns (clamped-line clamped-column line-clamped? column-clamped? operation)"
  (let* ([clamped-line (max 0 (min line max-line))]
         [line-clamped? (not (= line clamped-line))]
         ;; Calculate max-column for the clamped line
         [actual-max-column (if (<= clamped-line max-line) max-column 0)]
         [clamped-column (max 0 (min column actual-max-column))]
         [column-clamped? (not (= column clamped-column))])
    (list clamped-line clamped-column line-clamped? column-clamped? operation)))

;;; =================================================================
;;; ERROR CONDITION HELPERS (Pure data constructors)
;;; =================================================================

(define (make-boundary-error-info operation target actual boundary-type)
  "Create boundary error information structure"
  `((operation . ,operation)
    (target . ,target)
    (actual . ,actual)
    (boundary-type . ,boundary-type)))

(define (make-combining-mark-error-info operation base-char combining-char current-count max-count reason)
  "Create combining mark error information structure"
  `((operation . ,operation)
    (base-char . ,base-char)
    (combining-char . ,combining-char)
    (current-count . ,current-count)
    (max-count . ,max-count)
    (reason . ,reason)))
    
