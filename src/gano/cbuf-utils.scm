;;; Gano Character Buffer Utilities Module
;;; Pure utility functions extracted from cbuf module

(define-module (gano cbuf-utils)
  #:use-module (ice-9 regex)        ; Regular expressions
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-9)        ; Records
  #:use-module (srfi srfi-34)       ; Raise for conditions
  #:use-module (srfi srfi-35)       ; Condition types
  #:use-module (gano char)          ; Character utilities
  #:use-module (gano string-utils)  ; String manipulation utilities
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

    ;; Find/Replace
    find-pattern-in-text
    find-pattern-in-text-detailed
    find-all-regex-matches
    replace-regex-in-text
    
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
           
           [(char-base? ch)
            ;; This is a base character - reset state
            (set! current-base-char ch)
            (set! current-base-index i)
            (set! combining-count 0)
            (loop (+ i 1))]
           
           [else
            ;; Neither combining mark nor base character - treat as base
            (set! current-base-char ch)
            (set! current-base-index i)
            (set! combining-count 0)
            (loop (+ i 1))]))]))))

(define (validate-combining-marks-at-insertion str insertion-point insert-str)
  "Validate combining marks when inserting INSERT-STR at INSERTION-POINT in STR.
   Only validates the boundary conditions around the insertion point.
   Returns: (valid? violation-info)"
  ;; Use string-utils for cleaner string manipulation
  (let* ([new-str (string-insert-string str insertion-point insert-str)]
         
         ;; Only need to validate around the insertion boundaries
         [start-check (max 0 (- insertion-point 10))]  ; Check a few chars before
         [end-check (min (string-length new-str) 
                        (+ insertion-point (string-length insert-str) 10))] ; Check a few chars after
         [check-region (substring new-str start-check end-check)])
    
    ;; Validate just the region around the insertion
    (validate-string-combining-marks check-region)))

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
        
        [(char-base? ch)
         ;; This is a base character, reset the count
         (set! current-base-char ch)
         (set! combining-count 0)]
        
        [else
         ;; Neither combining nor base - treat as base character
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
  "Count base characters in string efficiently"
  (let loop ([i 0] [count 0])
    (if (>= i (string-length str))
        count
        (if (char-base? (string-ref str i))
            (loop (+ i 1) (+ count 1))
            (loop (+ i 1) count)))))

;;; Alternative implementations using string-utils:
#;(define (count-base-characters-functional str)
  "Count base characters using functional string-utils approach"
  (string-count-char 
   (string-map-with-index 
    (lambda (char index)
      (if (char-base? char) #\x #\space))
    str)
   #\x))

#;(define (count-base-characters-filter str)
  "Count base characters by filtering string to list and counting"
  (length (filter char-base? (string->list str))))

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
  "Find the index after the current word ends.
If the initial position is on a delimiter (like whitespace),
skip to the next word first."
  (let ([len (string-length txt)])
    (when (or (< start-index 0) (> start-index len))
      (scm-error 'out-of-range "find-word-end-forward" "bad string index ~A" (list start-index) (list start-index)))
    (cond
     [(>= start-index len) len]
     [else
      ;; If we're starting on a delimiter (like whitespace), skip to next word first
      (let ([word-start (if (and (< start-index len)
                                (delimiter-pred (string-ref txt start-index)))
                           ;; Skip delimiters to find start of next word
                           (skip-delimiters-forward txt start-index)
                           ;; Already on a word character
                           start-index)])
        ;; Now find the end of this word
        (skip-word-chars-forward txt word-start delimiter-pred))])))

(define (find-word-begin-backward txt start-index delimiter-pred)
  "Find the index where the current word begins.
If the initial position is on a delimiter (like whitespace),
skip to the previous word first."
  (when (or (< start-index 0) (> start-index (string-length txt)))
    (scm-error 'out-of-range "find-word-begin-backward" "bad string index ~A" (list start-index) (list start-index)))
  (cond
   [(<= start-index 0) 0]
   [else
    ;; Skip preceding delimiters first (if we're on delimiters)
    (let ([before-delimiters (skip-delimiters-backward txt (- start-index 1))])
      ;; Skip back through word characters
      (skip-word-chars-backward txt before-delimiters delimiter-pred))]))

(define (skip-while-forward txt start-index predicate)
  "Generic forward skipper - skip while predicate is true"
  (when (or (< start-index 0) (> start-index (string-length txt)))
    (scm-error 'out-of-range "skip-while-forward" "bad string index ~A" (list start-index) (list start-index)))
  (let ([len (string-length txt)])
    (cond
     [(>= start-index len) len]
     [else
      (let ([stop-pos (string-index txt (lambda (c) (not (predicate c))) start-index)])
        (if stop-pos stop-pos len))])))

(define (skip-while-backward txt start-index predicate)
  "Generic backward skipper - skip while predicate is true"
  (when (or (< start-index 0) (> start-index (string-length txt)))
    (scm-error 'out-of-range "skip-while-backward" "bad string index ~A" (list start-index) (list start-index)))
  (cond
   [(<= start-index 0) 0]
   [else
    (let ([stop-pos (string-rindex txt (lambda (c) (not (predicate c))) 0 start-index)])
      (if stop-pos (1+ stop-pos) 0))]))

(define (skip-word-chars-forward txt start-index delimiter-pred)
  (when (or (< start-index 0) (> start-index (string-length txt)))
    (scm-error 'out-of-range "skip-word-chars-forward" "bad string index ~A" (list start-index) (list start-index)))
  (skip-while-forward txt start-index
		      (lambda (c)
			(not (delimiter-pred c)))))

(define (skip-word-chars-backward txt start-index delimiter-pred)
  (when (or (< start-index 0) (> start-index (string-length txt)))
    (scm-error 'out-of-range "skip-word-chars-backward" "bad string index ~A" (list start-index) (list start-index)))
  (skip-while-backward txt start-index
		       (lambda (c)
			 (not (delimiter-pred c)))))

(define (skip-whitespace-forward txt start-index)
  (when (or (< start-index 0) (> start-index (string-length txt)))
    (scm-error 'out-of-range "skip-whitespace-forward" "bad string index ~A" (list start-index) (list start-index)))
  (skip-while-forward txt start-index char-whitespace?))

(define (skip-whitespace-backward txt start-index)
  (when (or (< start-index 0) (> start-index (string-length txt)))
    (scm-error 'out-of-range "skip-whitespace-backward" "bad string index ~A" (list start-index) (list start-index)))
  (skip-while-backward txt start-index char-whitespace?))

(define (skip-delimiters-forward txt start-index)
  (when (or (< start-index 0) (> start-index (string-length txt)))
    (scm-error 'out-of-range "skip-delimiters-forward" "bad string index ~A" (list start-index) (list start-index)))
  (skip-while-forward txt start-index char-word-delimiter?))

(define (skip-delimiters-backward txt start-index)
  (when (or (< start-index 0) (> start-index (string-length txt)))
    (scm-error 'out-of-range "skip-delimiters-backward" "bad string index ~A" (list start-index) (list start-index)))
  (skip-while-backward txt start-index char-word-delimiter?))

(define (char-word-delimiter? ch)
  "True if character delimits a 'word' (punctuation + whitespace)"
  (or (char-whitespace? ch)
      (char-set-contains? char-set:punctuation ch)
      (char-set-contains? char-set:symbol ch)))

;;; =================================================================
;;; FIND / REPLACE HELPERS
;;; =================================================================

(define* (find-pattern-in-text text pattern start-pos 
                              #:key 
                              (case-insensitive? #f)
                              (whole-word? #f)
                              (regex? #f))
  "Find pattern in text starting from start-pos with options.
   Returns match position or #f if not found.
   Uses grapheme-aware search to respect Unicode character boundaries.
   
   Parameters:
   - text: string to search in
   - pattern: string pattern to find (literal or regex)
   - start-pos: position to start searching from (optional)
   - case-insensitive?: if #t, ignore case (keyword)
   - whole-word?: if #t, match only whole words (keyword)  
   - regex?: if #t, treat pattern as regular expression (keyword)
   
   Returns: match position (integer) or #f if not found"
  
  (cond
   [regex?
    ;; Use regex search with grapheme awareness
    (find-regex-pattern text pattern start-pos case-insensitive? whole-word?)]
   [else
    ;; Use literal string search with grapheme awareness
    (find-literal-pattern text pattern start-pos case-insensitive? whole-word?)]))

;;; Literal string pattern search (existing functionality)
(define (find-literal-pattern text pattern start-pos case-insensitive? whole-word?)
  "Find literal string pattern with grapheme awareness."
  ;; Choose the appropriate search function based on case sensitivity
  (let ([search-func (if case-insensitive? 
                         string-contains-graphemes-ci 
                         string-contains-graphemes)])
    
    (let loop ([pos (or start-pos 0)])
      (let ([match (search-func text pattern pos)])
        (cond
         [(not match) #f]  ; No match found
         [(not whole-word?) match]  ; Found match and whole-word not required
         [(is-whole-word-match? text match (+ match (string-length pattern)))
          match]  ; Found whole-word match
         [else
          ;; Not a whole-word match, continue searching after this match
          (loop (+ match 1))])))))

;;; Regular expression pattern search
(define (find-regex-pattern text pattern start-pos case-insensitive? whole-word?)
  "Find regex pattern with grapheme awareness."
  (let ([regex-pattern (if case-insensitive?
                          (string-append "(?i)" pattern)  ; Case-insensitive flag
                          pattern)]
        [search-start (or start-pos 0)])
    
    (let loop ([pos search-start])
      (let ([match (string-match-graphemes regex-pattern text pos)])
        (cond
         [(not match) #f]  ; No match found
         [(not whole-word?) (match:start match)]  ; Found match and whole-word not required
         [(is-whole-word-regex-match? match)
          (match:start match)]  ; Found whole-word match
         [else
          ;; Not a whole-word match, continue searching after this match
          (let ([next-pos (+ (match:start match) 1)])
            (if (< next-pos (string-length text))
                (loop next-pos)
                #f))])))))

;;; Enhanced match result structure for regex support
(define-record-type <pattern-match>
  (make-pattern-match start end matched-text full-match regex-match)
  pattern-match?
  (start pattern-match-start)
  (end pattern-match-end) 
  (matched-text pattern-match-text)
  (full-match pattern-match-full-text)
  (regex-match pattern-match-regex-match))  ; Original regex match object

(define* (find-pattern-in-text-detailed text pattern start-pos
                                       #:key 
                                       (case-insensitive? #f)
                                       (whole-word? #f)
                                       (regex? #f))
  "Enhanced version that returns detailed match information.
   Returns a pattern-match record or #f if no match found."
  
  (cond
   [regex?
    (let ([match (find-regex-pattern text pattern start-pos case-insensitive? whole-word?)])
      (if match
          (let ([regex-match (string-match-graphemes 
                             (if case-insensitive? 
                                 (string-append "(?i)" pattern) 
                                 pattern) 
                             text match)])
            (and regex-match
                 (make-pattern-match 
                  (match:start regex-match)
                  (match:end regex-match)
                  (match:substring regex-match)
                  text
                  regex-match)))
          #f))]
   [else
    (let ([match-pos (find-literal-pattern text pattern start-pos case-insensitive? whole-word?)])
      (if match-pos
          (make-pattern-match
           match-pos
           (+ match-pos (string-length pattern))
           pattern
           text
           #f)  ; No regex match for literal patterns
          #f))]))

;;; Helper functions for whole-word matching with regex
(define (is-whole-word-regex-match? match)
  "Check if a regex match constitutes a whole word."
  (let ([text (match:string match)]
        [start (match:start match)]
        [end (match:end match)])
    (is-whole-word-match? text start end)))

(define (is-whole-word-match? text match-start match-end)
  "Check if the match at [match-start, match-end) constitutes a whole word.
   A whole word means the match is bounded by word delimiters or string boundaries."
  (and 
   ;; Check start boundary: either at string start or preceded by delimiter
   (or (= match-start 0)
       (char-word-delimiter? (string-ref text (- match-start 1))))
   ;; Check end boundary: either at string end or followed by delimiter  
   (or (>= match-end (string-length text))
       (char-word-delimiter? (string-ref text match-end)))))

;;; Advanced regex utilities
(define (find-all-regex-matches text pattern case-insensitive?)
  "Find all regex matches in text. Returns list of pattern-match records."
  (let ([regex-pattern (if case-insensitive?
                          (string-append "(?i)" pattern)
                          pattern)])
    (let loop ([pos 0] [matches '()])
      (let ([match (string-match-graphemes regex-pattern text pos)])
        (if match
            (let* ([match-start (match:start match)]
                   [match-end (match:end match)]
                   [match-record (make-pattern-match 
                                 match-start match-end
                                 (match:substring match)
                                 text match)])
              ;; Continue searching after this match
              (loop (max (+ match-start 1) match-end) 
                    (cons match-record matches)))
            ;; No more matches, return in forward order
            (reverse matches))))))

;;; Regex replacement with grapheme awareness
(define* (replace-regex-in-text text pattern replacement 
                               #:key 
                               (case-insensitive? #f)
                               (replace-all? #f))
  "Replace regex pattern with replacement text, respecting grapheme boundaries.
   Returns (new-text . match-count)."
  (let ([matches (find-all-regex-matches text pattern case-insensitive?)])
    (cond
     [(null? matches) (cons text 0)]  ; No matches
     [replace-all?
      ;; Replace all matches using string-utils for efficiency
      (let* ([replacements (map (lambda (match)
                                 (list (pattern-match-start match)
                                       (pattern-match-end match)
                                       replacement))
                               matches)]
             [new-text (string-replace-multiple text replacements)])
        (cons new-text (length matches)))]
     [else
      ;; Replace only first match
      (let* ([first-match (car matches)]
             [start (pattern-match-start first-match)]
             [end (pattern-match-end first-match)]
             [new-text (string-replace-range text start end replacement)])
        (cons new-text 1))])))
        
;;; =================================================================
;;; FIND ALL OPERATIONS (Unified API)
;;; =================================================================

(define* (find-all-pattern-matches text pattern 
                                  #:key 
                                  (case-insensitive? #f)
                                  (whole-word? #f)
                                  (regex? #f))
  "Find all matches of pattern in text. Returns list of pattern-match records.
   Works for both literal strings and regular expressions."
  (if regex?
      (find-all-regex-matches text pattern case-insensitive? whole-word?)
      (find-all-literal-matches text pattern case-insensitive? whole-word?)))

(define (find-all-literal-matches text pattern case-insensitive? whole-word?)
  "Find all literal string matches in text. Returns list of pattern-match records."
  (let ([search-func (if case-insensitive? 
                         string-contains-graphemes-ci 
                         string-contains-graphemes)])
    (let loop ([pos 0] [matches '()])
      (let ([match-pos (search-func text pattern pos)])
        (cond
         [(not match-pos) (reverse matches)]  ; No more matches
         [else
          (let* ([match-start match-pos]
                 [match-end (+ match-pos (string-length pattern))]
                 [is-whole-word (or (not whole-word?)
                                   (is-whole-word-match? text match-start match-end))])
            (if is-whole-word
                ;; Valid match - add to results and continue
                (let ([match-record (make-pattern-match 
                                    match-start match-end
                                    pattern text #f)])
                  (loop (+ match-start 1) (cons match-record matches)))
                ;; Not a whole-word match - continue searching
                (loop (+ match-start 1) matches)))])))))

(define (find-all-regex-matches text pattern case-insensitive? whole-word?)
  "Find all regex matches in text. Returns list of pattern-match records."
  (let ([regex-pattern (if case-insensitive?
                          (string-append "(?i)" pattern)
                          pattern)])
    (let loop ([pos 0] [matches '()])
      (let ([match (string-match-graphemes regex-pattern text pos)])
        (cond
         [(not match) (reverse matches)]  ; No more matches
         [else
          (let* ([match-start (match:start match)]
                 [match-end (match:end match)]
                 [is-whole-word (or (not whole-word?)
                                   (is-whole-word-regex-match? match))])
            (if is-whole-word
                ;; Valid match - add to results and continue  
                (let ([match-record (make-pattern-match 
                                    match-start match-end
                                    (match:substring match)
                                    text match)])
                  (loop (max (+ match-start 1) match-end) 
                        (cons match-record matches)))
                ;; Not a whole-word match - continue searching
                (loop (+ match-start 1) matches)))])))))

;;; =================================================================
;;; REPLACE ALL OPERATIONS (Unified API)
;;; =================================================================

(define* (replace-all-patterns-in-text text pattern replacement
                                      #:key 
                                      (case-insensitive? #f)
                                      (whole-word? #f)
                                      (regex? #f))
  "Replace all occurrences of pattern with replacement text.
   Returns (new-text . match-count).
   Works for both literal strings and regular expressions."
  (if regex?
      (replace-all-regex-in-text text pattern replacement case-insensitive? whole-word?)
      (replace-all-literal-in-text text pattern replacement case-insensitive? whole-word?)))

(define (replace-all-literal-in-text text pattern replacement case-insensitive? whole-word?)
  "Replace all literal string occurrences with replacement text.
   Returns (new-text . match-count)."
  (let ([matches (find-all-literal-matches text pattern case-insensitive? whole-word?)])
    (if (null? matches)
        (cons text 0)  ; No matches
        ;; Use string-utils for efficient bulk replacement
        (let* ([replacements (map (lambda (match)
                                   (list (pattern-match-start match)
                                         (pattern-match-end match)
                                         replacement))
                                 matches)]
               [new-text (string-replace-multiple text replacements)])
          (cons new-text (length matches))))))

(define (replace-all-regex-in-text text pattern replacement case-insensitive? whole-word?)
  "Replace all regex occurrences with replacement text.
   Returns (new-text . match-count)."
  (let ([matches (find-all-regex-matches text pattern case-insensitive? whole-word?)])
    (if (null? matches)
        (cons text 0)  ; No matches
        ;; Use string-utils for efficient bulk replacement
        (let* ([replacements (map (lambda (match)
                                   (list (pattern-match-start match)
                                         (pattern-match-end match)
                                         replacement))
                                 matches)]
               [new-text (string-replace-multiple text replacements)])
          (cons new-text (length matches))))))

;;; =================================================================
;;; SINGLE REPLACE OPERATIONS (Unified API)
;;; =================================================================

(define* (replace-pattern-in-text text pattern replacement
                                 #:key 
                                 (case-insensitive? #f)
                                 (whole-word? #f)
                                 (regex? #f)
                                 (start-pos 0))
  "Replace first occurrence of pattern with replacement text.
   Returns (new-text . match-record) where match-record is the replaced match,
   or (#f . #f) if no match found."
  
  ;; Find the first match
  (let ([match-pos (find-pattern-in-text text pattern start-pos
                                         #:case-insensitive? case-insensitive?
                                         #:whole-word? whole-word?
                                         #:regex? regex?)])
    (if match-pos
        ;; Get detailed match information
        (let ([match-record (find-pattern-in-text-detailed text pattern start-pos
                                                          #:case-insensitive? case-insensitive?
                                                          #:whole-word? whole-word?
                                                          #:regex? regex?)])
          (if match-record
              (let* ([start (pattern-match-start match-record)]
                     [end (pattern-match-end match-record)]
                     [new-text (string-replace-range text start end replacement)])
                (cons new-text match-record))
              (cons #f #f)))
        (cons #f #f))))

;;; =================================================================
;;; UTILITY FUNCTIONS FOR PATTERN MATCHING
;;; =================================================================

(define (pattern-match-summary matches)
  "Create a summary of pattern matches for debugging/logging."
  (map (lambda (match)
         `((start . ,(pattern-match-start match))
           (end . ,(pattern-match-end match))
           (text . ,(pattern-match-text match))
           (length . ,(- (pattern-match-end match) (pattern-match-start match)))))
       matches))

(define (count-pattern-matches text pattern case-insensitive? whole-word? regex?)
  "Count the number of pattern matches without creating match objects."
  (length (find-all-pattern-matches text pattern 
                                   #:case-insensitive? case-insensitive?
                                   #:whole-word? whole-word?
                                   #:regex? regex?)))

(define (pattern-match-positions matches)
  "Extract just the start positions from a list of pattern matches."
  (map pattern-match-start matches))

(define (highlight-pattern-matches text matches open-tag close-tag)
  "Insert highlight tags around pattern matches in text.
   Returns new string with matches wrapped in open-tag/close-tag.
   Example: (highlight-pattern-matches \"hello world\" matches \"<mark>\" \"</mark>\")"
  (if (null? matches)
      text
      ;; Use string-utils for efficient bulk insertion
      (let* ([insertions (append
                          ;; Opening tags (insert at start positions)
                          (map (lambda (match)
                                (cons (pattern-match-start match) open-tag))
                               matches)
                          ;; Closing tags (insert at end positions, adjusted for opening tags)
                          (map (lambda (match)
                                (cons (+ (pattern-match-end match) 
                                        (string-length open-tag)) close-tag))
                               matches))]
             [sorted-insertions (sort insertions (lambda (a b) (< (car a) (car b))))])
        (string-insert-multiple text sorted-insertions))))

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