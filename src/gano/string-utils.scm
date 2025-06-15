;;; Gano String Utilities Module
;;; Immutable string manipulation utilities

(define-module (gano string-utils)
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (ice-9 regex)
  #:use-module (gano char)
  #:export (
    ;; Basic string manipulation
    string-insert-char
    string-insert-string
    string-delete-range
    string-replace-range
    string-replace-char
    
    ;; Character-based operations
    string-update-char
    string-set-char
    string-swap-chars
    
    ;; Multi-operation utilities
    string-apply-operations
    string-insert-multiple
    string-replace-multiple
    
    ;; Safe accessors
    string-ref-safe
    string-char-at
    
    ;; Functional builders
    string-from-chars
    string-repeat-char
    string-pad-to-length
    
    ;; Analysis utilities
    string-char-positions
    string-find-char
    string-find-string
    string-count-char
    string-detect-line-ending

    ;; Grapheme-aware search utilities
    string-contains-graphemes
    string-contains-graphemes-ci
    
    ;; Unicode-aware utilities
    ;; string-for-each-index
    string-map-with-index))

;;; =================================================================
;;; BASIC STRING MANIPULATION
;;; =================================================================

(define (string-insert-char str index char)
  "Return new string with CHAR inserted at INDEX.
   If index is out of bounds, handle gracefully."
  (let ([len (string-length str)])
    (cond
      [(< index 0) (string-append (string char) str)]
      [(>= index len) (string-append str (string char))]
      [else (string-append (substring str 0 index)
                           (string char)
                           (substring str index))])))

(define (string-insert-string str index insert-str)
  "Return new string with INSERT-STR inserted at INDEX."
  (let ([len (string-length str)])
    (cond
      [(< index 0) (string-append insert-str str)]
      [(>= index len) (string-append str insert-str)]
      [else (string-append (substring str 0 index)
                           insert-str
                           (substring str index))])))

(define (string-delete-range str start-index end-index)
  "Return new string with characters from start-index to end-index removed.
   Range is [start-index, end-index) - end-index is exclusive."
  (let ([len (string-length str)]
        [actual-start (max 0 start-index)]
        [actual-end (max 0 end-index)])
    (cond
      [(>= actual-start len) str]  ; Start beyond string
      [(>= actual-start actual-end) str]  ; Invalid range
      [else
       (let ([safe-end (min actual-end len)])
         (string-append (substring str 0 actual-start)
                        (substring str safe-end)))])))

(define (string-replace-range str start-index end-index replacement)
  "Return new string with range [start-index, end-index) replaced by REPLACEMENT."
  (let ([len (string-length str)]
        [actual-start (max 0 start-index)]
        [actual-end (max 0 end-index)])
    (cond
      [(>= actual-start len) (string-append str replacement)]  ; Append if start beyond string
      [(>= actual-start actual-end) (string-insert-string str actual-start replacement)]  ; Insert if invalid range
      [else
       (let ([safe-end (min actual-end len)])
         (string-append (substring str 0 actual-start)
                        replacement
                        (substring str safe-end)))])))

(define (string-replace-char str index new-char)
  "Return new string with character at INDEX replaced by NEW-CHAR."
  (if (and (>= index 0) (< index (string-length str)))
      (string-replace-range str index (+ index 1) (string new-char))
      str))

;;; =================================================================
;;; CHARACTER-BASED OPERATIONS
;;; =================================================================

(define (string-update-char str index char)
  "Return new string with character at INDEX updated to CHAR.
   Alias for string-replace-char for consistency with list-update."
  (string-replace-char str index char))

(define (string-set-char str index char)
  "Return new string with character at INDEX set to CHAR.
   Extends string with spaces if index is beyond current length."
  (let ([len (string-length str)])
    (cond
      [(< index 0) str]
      [(>= index len)
       ;; Extend string with spaces
       (let ([padding (make-string (- index len) #\space)])
         (string-append str padding (string char)))]
      [else (string-replace-char str index char)])))

(define (string-swap-chars str index1 index2)
  "Return new string with characters at index1 and index2 swapped."
  (let ([len (string-length str)])
    (cond
      [(or (< index1 0) (>= index1 len)
           (< index2 0) (>= index2 len)
           (= index1 index2)) str]
      [else
       (let ([char1 (string-ref str index1)]
             [char2 (string-ref str index2)])
         (string-update-char (string-update-char str index1 char2) index2 char1))])))

;;; =================================================================
;;; MULTI-OPERATION UTILITIES
;;; =================================================================

(define (string-apply-operations str operations)
  "Apply a sequence of operations to a string.
   OPERATIONS is a list where each element is one of:
   - (insert index char-or-string)
   - (delete start end)
   - (replace start end replacement)
   - (update index char)
   
   Operations are applied from right to left to avoid index shifting."
  (fold (lambda (op acc)
          (case (car op)
            [(insert) 
             (let ([index (cadr op)]
                   [value (caddr op)])
               (if (char? value)
                   (string-insert-char acc index value)
                   (string-insert-string acc index value)))]
            [(delete) (string-delete-range acc (cadr op) (caddr op))]
            [(replace) (string-replace-range acc (cadr op) (caddr op) (cadddr op))]
            [(update) (string-update-char acc (cadr op) (caddr op))]
            [else (error "Unknown string operation" op)]))
        str
        ;; Sort operations by position (right to left)
        (sort operations (lambda (a b) 
                          (let ([pos-a (cadr a)]
                                [pos-b (cadr b)])
                            (> pos-a pos-b))))))

(define (string-insert-multiple str insertions)
  "Insert multiple characters/strings at various positions.
   INSERTIONS is a list of (index . value) pairs.
   All indices refer to positions in the original string.
   Multiple insertions at the same index are applied left-to-right.
   Throws an error if indices are negative."
  (if (null? insertions)
      str
      (let ([str-len (string-length str)])
        
        ;; Validate indices (negative indices are errors, beyond-end is ok for inserts)
        (for-each
         (lambda (insertion)
           (let ([index (car insertion)])
             (when (< index 0)
               (error "string-insert-multiple: negative index" index))))
         insertions)
        
        ;; Proceed with insertions
        (let* ([sorted (stable-sort insertions (lambda (a b) (< (car a) (car b))))]
               [segments '()]
               [pos 0])
          
          (for-each
           (lambda (insertion)
             (let ([insert-pos (car insertion)]
                   [insert-val (cdr insertion)])
               ;; Add original string segment if we've moved to a new position
               (when (> insert-pos pos)
                 (set! segments (append segments (list (substring str pos (min insert-pos str-len)))))
                 (set! pos insert-pos))
               ;; Add the insertion
               (set! segments (append segments (list (if (char? insert-val) 
                                                         (string insert-val) 
                                                         insert-val))))))
           sorted)
          
          ;; Add remaining original string
          (when (< pos str-len)
            (set! segments (append segments (list (substring str pos str-len)))))
          
          (string-concatenate segments)))))

(define (string-replace-multiple str replacements)
  "Replace multiple ranges in a string.
   REPLACEMENTS is a list of (start-index end-index replacement) tuples.
   All indices refer to positions in the original string.
   Throws an error if ranges overlap or are out of bounds."
  (if (null? replacements)
      str
      (let ([str-len (string-length str)])
        
        ;; Validate all ranges first
        (for-each
         (lambda (replacement)
           (let ([start (car replacement)]
                 [end (cadr replacement)])
             ;; Check bounds
             (when (< start 0)
               (error "string-replace-multiple: start index out of bounds" start))
             (when (> end str-len)
               (error "string-replace-multiple: end index out of bounds" end str-len))
             (when (> start end)
               (error "string-replace-multiple: invalid range, start > end" start end))))
         replacements)
        
        ;; Check for overlapping ranges
        (let ([sorted-ranges (sort (map (lambda (r) (list (car r) (cadr r) (caddr r))) replacements)
                                   (lambda (a b) (< (car a) (car b))))])
          (let check-overlap ([ranges sorted-ranges])
            (when (>= (length ranges) 2)
              (let ([first (car ranges)]
                    [second (cadr ranges)])
                (when (> (cadr first) (car second))  ; first-end > second-start
                  (error "string-replace-multiple: overlapping ranges" 
                         (list (car first) (cadr first)) 
                         (list (car second) (cadr second))))
                (check-overlap (cdr ranges)))))
          
          ;; All validations passed, perform replacements
          (let ([segments '()]
                [pos 0])
            
            (for-each
             (lambda (replacement)
               (let ([start (car replacement)]
                     [end (cadr replacement)]
                     [repl (caddr replacement)])
                 ;; Add original string segment before this replacement
                 (when (> start pos)
                   (set! segments (append segments (list (substring str pos start)))))
                 ;; Add the replacement
                 (set! segments (append segments (list repl)))
                 ;; Update position
                 (set! pos end)))
             sorted-ranges)
            
            ;; Add remaining original string
            (when (< pos str-len)
              (set! segments (append segments (list (substring str pos str-len)))))
            
            (string-concatenate segments))))))

;;; =================================================================
;;; SAFE ACCESSORS
;;; =================================================================

(define (string-ref-safe str index default-char)
  "Safe string-ref that returns default-char if index is out of bounds."
  (if (and (>= index 0) (< index (string-length str)))
      (string-ref str index)
      default-char))

(define (string-char-at str index)
  "Get character at index, returns #f if out of bounds."
  (if (and (>= index 0) (< index (string-length str)))
      (string-ref str index)
      #f))

;;; =================================================================
;;; FUNCTIONAL BUILDERS
;;; =================================================================

(define (string-from-chars char-list)
  "Create string from list of characters."
  (apply string char-list))

(define (string-repeat-char char count)
  "Create string by repeating CHAR COUNT times."
  (make-string count char))

(define (string-pad-to-length str target-length pad-char)
  "Return string padded to target-length with pad-char.
   If string is already longer, returns original string."
  (let ([current-length (string-length str)])
    (if (>= current-length target-length)
        str
        (string-append str (make-string (- target-length current-length) pad-char)))))

;;; =================================================================
;;; ANALYSIS UTILITIES
;;; =================================================================

(define (string-char-positions str char)
  "Return list of all positions where CHAR appears in STR."
  (let loop ([i 0] [positions '()])
    (if (>= i (string-length str))
        (reverse positions)
        (if (char=? (string-ref str i) char)
            (loop (+ i 1) (cons i positions))
            (loop (+ i 1) positions)))))

(define (string-find-char str char)
  "Return first position of CHAR in STR, or #f if not found."
  (let loop ([i 0])
    (cond
      [(>= i (string-length str)) #f]
      [(char=? (string-ref str i) char) i]
      [else (loop (+ i 1))])))

(define (string-find-string str search-str)
  "Return first position where SEARCH-STR appears in STR, or #f if not found."
  (let ([str-len (string-length str)]
        [search-len (string-length search-str)])
    (cond
      [(> search-len str-len) #f]
      [(= search-len 0) 0]
      [else
       (let loop ([i 0])
         (cond
           [(> (+ i search-len) str-len) #f]
           [(string=? (substring str i (+ i search-len)) search-str) i]
           [else (loop (+ i 1))]))])))

(define (string-count-char str char)
  "Count occurrences of CHAR in STR."
  (let loop ([i 0] [count 0])
    (if (>= i (string-length str))
        count
        (if (char=? (string-ref str i) char)
            (loop (+ i 1) (+ count 1))
            (loop (+ i 1) count)))))

(define (string-detect-line-ending str)
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
;;; GRAPHEME-AWARE SEARCH UTILITIES
;;; =================================================================

(define* (string-contains-graphemes s1 s2 #:optional start1 end1 start2 end2)
  "Grapheme-aware version of string-contains.
   Does string S1 contain string S2? Return the index in S1 where S2 
   occurs as a substring, or false. Ensures matches respect grapheme boundaries.
   The optional start/end indices restrict the operation to the indicated substrings."
  (let* ([s1-start (or start1 0)]
         [s1-end (or end1 (string-length s1))]
         [s2-start (or start2 0)]
         [s2-end (or end2 (string-length s2))]
         [s1-sub (substring s1 s1-start s1-end)]
         [s2-sub (substring s2 s2-start s2-end)])
    
    ;; Find all potential matches using the standard function
    (let loop ([search-start 0])
      (let ([match-pos (string-contains s1-sub s2-sub search-start)])
        (cond
         [(not match-pos) #f]  ; No more matches found
         ;; Check if this match respects grapheme boundaries
         [(is-valid-grapheme-match? s1-sub match-pos (+ match-pos (string-length s2-sub)))
          ;; Valid match - return position adjusted for the original string
          (+ s1-start match-pos)]
         [else
          ;; Invalid match, continue searching from next position
          (loop (+ match-pos 1))])))))

(define* (string-contains-graphemes-ci s1 s2 #:optional start1 end1 start2 end2)
  "Case-insensitive grapheme-aware version of string-contains.
   Does string S1 contain string S2? Return the index in S1 where S2 
   occurs as a substring, or false. Ensures matches respect grapheme boundaries.
   Character comparison is done case-insensitively.
   The optional start/end indices restrict the operation to the indicated substrings."
  (let* ([s1-start (or start1 0)]
         [s1-end (or end1 (string-length s1))]
         [s2-start (or start2 0)]
         [s2-end (or end2 (string-length s2))]
         [s1-sub (substring s1 s1-start s1-end)]
         [s2-sub (substring s2 s2-start s2-end)])
    
    ;; Find all potential matches using the case-insensitive standard function
    (let loop ([search-start 0])
      (let ([match-pos (string-contains-ci s1-sub s2-sub search-start)])
        (cond
         [(not match-pos) #f]  ; No more matches found
         ;; Check if this match respects grapheme boundaries
         [(is-valid-grapheme-match? s1-sub match-pos (+ match-pos (string-length s2-sub)))
          ;; Valid match - return position adjusted for the original string
          (+ s1-start match-pos)]
         [else
          ;; Invalid match, continue searching from next position
          (loop (+ match-pos 1))])))))

;;; Helper functions for grapheme boundary detection

(define (is-valid-grapheme-match? text match-start match-end)
  "Check if a match respects grapheme boundaries.
   A valid match must:
   1. Start at the beginning of a grapheme (not in the middle of combining marks)
   2. End at the end of a grapheme (include all combining marks of the last base char)"
  (and (is-grapheme-boundary-start? text match-start)
       (is-grapheme-boundary-end? text match-end)))

(define (is-grapheme-boundary-start? text pos)
  "Check if position is at the start of a grapheme.
   True if:
   - pos is 0 (start of string), OR
   - pos is at a base character"
  (cond
   [(= pos 0) #t]  ; Beginning of string is always a boundary
   [(>= pos (string-length text)) #t]  ; End of string is always a boundary
   [else
    ;; Check if character at pos is a base character
    (let ([char-at-pos (string-ref text pos)])
      (char-base? char-at-pos))]))

(define (is-grapheme-boundary-end? text pos)
  "Check if position is at the end of a grapheme.
   True if:
   - pos is at end of string, OR
   - pos is just after a complete grapheme (base char + all its combining marks)"
  (cond
   [(>= pos (string-length text)) #t]  ; End of string is always a boundary
   [(= pos 0) #t]  ; Beginning of string is always a boundary
   [else
    ;; Check if we're at the end of a complete grapheme
    ;; This means the character at pos should be a base character (starting next grapheme)
    (let ([char-at-pos (string-ref text pos)])
      (char-base? char-at-pos))]))

(define* (string-match-graphemes pattern str #:optional start)
  "Grapheme-aware version of string-match.
   Compile the string PATTERN into a regular expression and match it with STR.
   Ensures matches respect grapheme boundaries - will not match partial graphemes.
   Returns a match structure or #f if no valid grapheme-respecting match found."
  (let ([search-start (or start 0)])
    
    ;; Try to find regex matches starting from search-start
    (let loop ([pos search-start])
      (let ([match (string-match pattern str pos)])
        (cond
         [(not match) #f]  ; No match found
         [else
          ;; Check if this match respects grapheme boundaries
          (let ([match-start (match:start match)]
                [match-end (match:end match)])
            (cond
             [(is-valid-grapheme-match? str match-start match-end)
              ;; Valid grapheme match - return it
              match]
             [(< (+ match-start 1) (string-length str))
              ;; Invalid match, try searching from next position
              (loop (+ match-start 1))]
             [else 
              ;; Can't advance further, no valid match
              #f]))])))))

;;; Helper function to validate regex matches for grapheme boundaries
(define (validate-regex-match-graphemes match)
  "Validate that a regex match respects grapheme boundaries.
   Returns the match if valid, #f otherwise."
  (if (not match)
      #f
      (let ([match-start (match:start match)]
            [match-end (match:end match)]
            [str (match:string match)])
        (if (is-valid-grapheme-match? str match-start match-end)
            match
            #f))))

;;; =================================================================
;;; UNICODE-AWARE UTILITIES
;;; =================================================================

;; (define (string-for-each-index proc str)
;;   "Call PROC with each character index in STR.
;;    PROC is called as (proc index)."
;;   (let loop ([i 0])
;;     (when (< i (string-length str))
;;       (proc i)
;;       (loop (+ i 1)))))

(define (string-map-with-index proc str)
  "Map PROC over string with index information.
   PROC is called as (proc char index) and should return a character.
   Returns new string with results."
  (let loop ([i 0] [result '()])
    (if (>= i (string-length str))
        (string-from-chars (reverse result))
        (let ([char (string-ref str i)])
          (loop (+ i 1) 
                (cons (proc char i) result))))))
