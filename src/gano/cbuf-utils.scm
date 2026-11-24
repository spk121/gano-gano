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
    ;; (positions are string indices; matches never split a grapheme
    ;; cluster, i.e. never start on or end before a combining mark)
    grapheme-boundary?
    is-whole-word-match?
    find-pattern-in-text
    find-pattern-in-text-detailed
    find-all-pattern-matches
    find-all-regex-matches
    count-pattern-matches
    replace-pattern-in-text
    replace-all-patterns-in-text
    replace-regex-in-text
    <pattern-match>
    pattern-match?
    pattern-match-start
    pattern-match-end
    pattern-match-text
    pattern-match-full-text
    pattern-match-regex-match
    pattern-match-summary
    pattern-match-positions
    highlight-pattern-matches
    
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
         ;; Check a few chars before, backing up so the window doesn't
         ;; start in the middle of a grapheme cluster
         [start-check (let loop ([i (max 0 (- insertion-point 10))])
                        (if (and (> i 0) (char-combining-mark? (string-ref new-str i)))
                            (loop (- i 1))
                            i))]
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
  "Count the base (non-combining) characters in STR: the number of data
   positions it occupies, as in (gano text-metrics)."
  (string-count str (lambda (c) (not (char-combining-mark? c)))))

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
  (unless (and (exact-integer? tabsize) (> tabsize 0))
    (error "compute-tab-column: tab size must be a positive integer" tabsize))
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
                           (skip-while-forward txt start-index delimiter-pred)
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
    (let ([before-delimiters (skip-while-backward txt start-index delimiter-pred)])
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

;;; A match is described by a <pattern-match>: START and END are string
;;; indices (END exclusive), TEXT the matched text, FULL-TEXT the string
;;; searched, REGEX-MATCH the regexp match object (#f for literals).
(define-record-type <pattern-match>
  (make-pattern-match start end matched-text full-match regex-match)
  pattern-match?
  (start pattern-match-start)
  (end pattern-match-end)
  (matched-text pattern-match-text)
  (full-match pattern-match-full-text)
  (regex-match pattern-match-regex-match))

(define (grapheme-boundary? text pos)
  "Is POS (0 .. length) between two grapheme clusters?  True at either
   end of TEXT and before any character that is not a combining mark.
   (Same as string-grapheme-boundary? in (gano string-utils).)"
  (string-grapheme-boundary? text pos))

(define (is-whole-word-match? text match-start match-end)
  "Is [MATCH-START, MATCH-END) bounded by word delimiters or the ends of TEXT?"
  (and (or (= match-start 0)
           (char-word-delimiter? (string-ref text (- match-start 1))))
       (or (>= match-end (string-length text))
           (char-word-delimiter? (string-ref text match-end)))))

(define (acceptable-match? text start end whole-word?)
  (and (grapheme-boundary? text start)
       (grapheme-boundary? text end)
       (or (not whole-word?) (is-whole-word-match? text start end))))

(define (literal-search text pattern start case-insensitive? whole-word?)
  "First acceptable match of the literal PATTERN at or after START, as
   (start . end), or #f.  An empty pattern never matches."
  (let ([contains (if case-insensitive? string-contains-ci string-contains)]
        [plen (string-length pattern)]
        [len (string-length text)])
    (and (> plen 0)
         (let loop ([pos start])
           (and (<= pos len)
                (let ([m (contains text pattern pos)])
                  (cond
                   [(not m) #f]
                   [(acceptable-match? text m (+ m plen) whole-word?) (cons m (+ m plen))]
                   [else (loop (+ m 1))])))))))

(define (compile-regex pattern case-insensitive?)
  (if case-insensitive?
      (make-regexp pattern regexp/extended regexp/icase)
      (make-regexp pattern regexp/extended)))

(define (regex-search text rx start whole-word?)
  "First acceptable match of the compiled regexp RX at or after START, or
   #f.  ^ only matches at the start of TEXT."
  (let ([len (string-length text)])
    (let loop ([pos start])
      (and (<= pos len)
           (let ([m (regexp-exec rx text pos (if (> pos 0) regexp/notbol 0))])
             (cond
              [(not m) #f]
              [(acceptable-match? text (match:start m) (match:end m) whole-word?) m]
              [else (loop (+ (match:start m) 1))]))))))

(define (normalize-start text start-pos)
  "START-POS as a search start: #f means 0; past the end means no search."
  (let ([start (or start-pos 0)])
    (and (<= 0 start (string-length text)) start)))

(define* (find-pattern-in-text-detailed text pattern start-pos
                                        #:key
                                        (case-insensitive? #f)
                                        (whole-word? #f)
                                        (regex? #f))
  "Find the first match of PATTERN in TEXT at or after START-POS (#f = 0).
   PATTERN is a literal string, or a POSIX extended regular expression if
   #:regex? is true.  Matches never split a grapheme cluster; with
   #:whole-word? they must also be bounded by word delimiters.
   Returns a <pattern-match>, or #f.  An empty literal never matches."
  (let ([start (normalize-start text start-pos)])
    (and start
         (if regex?
             (let ([m (regex-search text (compile-regex pattern case-insensitive?) start whole-word?)])
               (and m (make-pattern-match (match:start m) (match:end m)
                                          (match:substring m) text m)))
             (let ([m (literal-search text pattern start case-insensitive? whole-word?)])
               (and m (make-pattern-match (car m) (cdr m)
                                          (substring text (car m) (cdr m)) text #f)))))))

(define* (find-pattern-in-text text pattern start-pos
                               #:key
                               (case-insensitive? #f)
                               (whole-word? #f)
                               (regex? #f))
  "Like find-pattern-in-text-detailed, but return just the start index
   of the match, or #f."
  (let ([m (find-pattern-in-text-detailed text pattern start-pos
                                          #:case-insensitive? case-insensitive?
                                          #:whole-word? whole-word?
                                          #:regex? regex?)])
    (and m (pattern-match-start m))))

(define* (find-all-pattern-matches text pattern
                                   #:key
                                   (case-insensitive? #f)
                                   (whole-word? #f)
                                   (regex? #f))
  "All non-overlapping matches of PATTERN in TEXT, left to right, as a
   list of <pattern-match>.  After an empty regex match the search resumes
   one character later."
  (let loop ([pos 0] [acc '()])
    (let ([m (find-pattern-in-text-detailed text pattern pos
                                            #:case-insensitive? case-insensitive?
                                            #:whole-word? whole-word?
                                            #:regex? regex?)])
      (if m
          (loop (max (pattern-match-end m) (+ (pattern-match-start m) 1))
                (cons m acc))
          (reverse acc)))))

(define* (find-all-regex-matches text pattern case-insensitive? #:optional (whole-word? #f))
  "All non-overlapping matches of the regular expression PATTERN in TEXT."
  (find-all-pattern-matches text pattern
                            #:case-insensitive? case-insensitive?
                            #:whole-word? whole-word?
                            #:regex? #t))

(define* (count-pattern-matches text pattern
                                #:key (case-insensitive? #f) (whole-word? #f) (regex? #f))
  "Number of non-overlapping matches of PATTERN in TEXT."
  (length (find-all-pattern-matches text pattern
                                    #:case-insensitive? case-insensitive?
                                    #:whole-word? whole-word?
                                    #:regex? regex?)))

(define* (replace-pattern-in-text text pattern replacement
                                  #:key
                                  (case-insensitive? #f)
                                  (whole-word? #f)
                                  (regex? #f)
                                  (start-pos 0))
  "Replace the first match at or after START-POS with REPLACEMENT (used
   literally, also for regexes).
   Returns (new-text . pattern-match), or (#f . #f) if there is no match."
  (let ([m (find-pattern-in-text-detailed text pattern start-pos
                                          #:case-insensitive? case-insensitive?
                                          #:whole-word? whole-word?
                                          #:regex? regex?)])
    (if m
        (cons (string-replace-range text (pattern-match-start m) (pattern-match-end m) replacement)
              m)
        (cons #f #f))))

(define* (replace-all-patterns-in-text text pattern replacement
                                       #:key
                                       (case-insensitive? #f)
                                       (whole-word? #f)
                                       (regex? #f))
  "Replace every non-overlapping match with REPLACEMENT (used literally).
   Returns (new-text . match-count)."
  (let ([matches (find-all-pattern-matches text pattern
                                           #:case-insensitive? case-insensitive?
                                           #:whole-word? whole-word?
                                           #:regex? regex?)])
    (if (null? matches)
        (cons text 0)
        (cons (string-replace-multiple
               text
               (map (lambda (m) (list (pattern-match-start m) (pattern-match-end m) replacement))
                    matches))
              (length matches)))))

(define* (replace-regex-in-text text pattern replacement
                                #:key
                                (case-insensitive? #f)
                                (replace-all? #f))
  "Replace the first (or with #:replace-all?, every) match of the regular
   expression PATTERN with REPLACEMENT.  Returns (new-text . match-count)."
  (if replace-all?
      (replace-all-patterns-in-text text pattern replacement
                                    #:case-insensitive? case-insensitive? #:regex? #t)
      (let ([result (replace-pattern-in-text text pattern replacement
                                             #:case-insensitive? case-insensitive? #:regex? #t)])
        (if (car result)
            (cons (car result) 1)
            (cons text 0)))))

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

(define (pattern-match-positions matches)
  "Extract just the start positions from a list of pattern matches."
  (map pattern-match-start matches))

(define (highlight-pattern-matches text matches open-tag close-tag)
  "Wrap each of MATCHES (non-overlapping, from TEXT) in OPEN-TAG and
   CLOSE-TAG.  Example: (highlight-pattern-matches \"hello world\" matches
   \"<mark>\" \"</mark>\")"
  (string-replace-multiple
   text
   (map (lambda (m)
          (list (pattern-match-start m) (pattern-match-end m)
                (string-append open-tag (pattern-match-text m) close-tag)))
        matches)))

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