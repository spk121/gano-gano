;;; string-split.scm
;;; Enhanced string splitting functions for multi-character delimiters

(define-module (gano string-split)
  #:use-module (srfi srfi-1)        ; List utilities
  #:export (
    ;; Core splitting functions
    string-split-on-string
    string-split-on-any
    string-split-at-char
    
    ;; Line ending utilities
    string-split-lines
    string-split-lines-with-final-newline-info
    string-detect-line-ending
    string-normalize-line-endings
    
    ;; Helper functions
    string-find-string
    string-char-positions
    string-join-with))

;;; =================================================================
;;; HELPER FUNCTIONS
;;; =================================================================

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

(define (string-char-positions str char)
  "Return list of all positions where CHAR appears in STR."
  (let loop ([i 0] [positions '()])
    (if (>= i (string-length str))
        (reverse positions)
        (if (char=? (string-ref str i) char)
            (loop (+ i 1) (cons i positions))
            (loop (+ i 1) positions)))))

(define (string-join-with string-list separator)
  "Join list of strings with SEPARATOR between them."
  (cond
    [(null? string-list) ""]
    [(null? (cdr string-list)) (car string-list)]
    [else
     (let loop ([remaining (cdr string-list)]
                [result (car string-list)])
       (if (null? remaining)
           result
           (loop (cdr remaining)
                 (string-append result separator (car remaining)))))]))

;;; =================================================================
;;; CORE SPLITTING FUNCTIONS
;;; =================================================================

(define (string-split-at-char str char)
  "Split string at all occurrences of CHAR, returning list of substrings."
  (let ([positions (cons -1 (append (string-char-positions str char) 
                                    (list (string-length str))))])
    (let loop ([pos-list positions] [result '()])
      (if (< (length pos-list) 2)
          (reverse result)
          (let ([start (+ (car pos-list) 1)]
                [end (cadr pos-list)])
            (loop (cdr pos-list) 
                  (cons (substring str start end) result)))))))

(define (string-split-on-string str delimiter)
  "Split string on all occurrences of DELIMITER string.
   Returns list of substrings. Empty delimiter returns list of single characters."
  (cond
    [(string-null? str) '("")]
    [(string-null? delimiter) (map string (string->list str))]
    [(= (string-length delimiter) 1)
     ;; Optimize single character case
     (string-split-at-char str (string-ref delimiter 0))]
    [else
     ;; Multi-character delimiter
     (let ([delimiter-len (string-length delimiter)])
       (let loop ([start 0] [result '()])
         (let ([pos (string-find-string (substring str start) delimiter)])
           (cond
             ;; No more occurrences - add final part
             [(not pos)
              (reverse (cons (substring str start) result))]
             
             ;; Found delimiter - add part before it and continue after it
             [else
              (let* ([actual-pos (+ start pos)]
                     [part (substring str start actual-pos)]
                     [new-start (+ actual-pos delimiter-len)])
                (loop new-start (cons part result)))]))))]))

(define (string-split-on-any str delimiters)
  "Split string on any of the delimiter strings in DELIMITERS list.
   Processes delimiters in order, so longer delimiters should come first
   to avoid incorrect splitting (e.g., put '\\r\\n' before '\\n')."
  (cond
    [(string-null? str) '("")]
    [(null? delimiters) (list str)]
    [else
     ;; Find the first occurrence of any delimiter
     (let* ([delimiter-positions 
             (filter-map (lambda (delim)
                          (let ([pos (string-find-string str delim)])
                            (and pos (cons pos delim))))
                        delimiters)]
            [earliest (and (not (null? delimiter-positions))
                          (fold (lambda (item acc)
                                 (if (< (car item) (car acc)) item acc))
                               (car delimiter-positions)
                               (cdr delimiter-positions)))])
       
       (cond
         ;; No delimiters found
         [(not earliest) (list str)]
         
         ;; Found delimiter - split and recurse
         [else
          (let* ([pos (car earliest)]
                 [delimiter (cdr earliest)]
                 [delimiter-len (string-length delimiter)]
                 [before (substring str 0 pos)]
                 [after (substring str (+ pos delimiter-len))])
            (cons before (string-split-on-any after delimiters)))]))]))

;;; =================================================================
;;; LINE ENDING UTILITIES
;;; =================================================================

(define (string-split-lines str)
  "Split string into lines, handling multiple line ending types.
   Recognizes \\r\\n, \\n, \\r, and Unicode line separators."
  (string-split-on-any str '("\r\n" "\n" "\r" "\u2028" "\u2029")))

(define (string-split-lines-with-final-newline-info str)
  "Split string into lines, handling multiple line ending types.
   Recognizes \\r\\n, \\n, \\r, and Unicode line separators."
  (cond
   [(string-null? str)
    (cons '("") #f)]
   [else
    (let* ([lines (string-split-lines str)]
           ;; Check if original string ended with any line ending
           [str-len (string-length str)]
           [last-char (string-ref str (- str-len 1))]
           [ends-with-newline? (or (char=? last-char #\newline)
                                   (char=? last-char #\return)
                                   (char=? last-char #\x2028)  ; Line separator
                                   (char=? last-char #\x2029)  ; Paragraph separator
                                   ;; Check for CRLF
                                   (and (>= str-len 2)
                                        (char=? (string-ref str (- str-len 2)) #\return)
                                        (char=? last-char #\newline)))])
       
      ;; If string ended with line ending, remove the extra empty line that split creates
      (if (and ends-with-newline? 
               (not (null? lines))
               (string-null? (last lines)))
          (cons (drop-right lines 1) #t)
          (cons lines #f)))]))

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

(define (string-normalize-line-endings str target-ending)
  "Convert all line endings in string to target-ending.
   TARGET-ENDING should be one of: \\n, \\r\\n, \\r, LS, or PS"
  (let ([lines (string-split-lines str)])
    (string-join-with lines target-ending)))

;;; =================================================================
;;; TESTING AND EXAMPLES
;;; =================================================================

(define (test-string-split)
  "Test the string splitting functions"
  (let* ([test-text "line1\r\nline2\nline3\rline4"]
         [test-csv "apple,banana,cherry"]
         [test-multi "one::two::three"])
    
    (format #t "Original text: ~s~%" test-text)
    (format #t "Split lines: ~a~%" (string-split-lines test-text))
    (format #t "Detected ending: ~s~%" (string-detect-line-ending test-text))
    (format #t "~%")
    
    (format #t "CSV text: ~s~%" test-csv)
    (format #t "Split on comma: ~a~%" (string-split-on-string test-csv ","))
    (format #t "~%")
    
    (format #t "Multi-delim text: ~s~%" test-multi)
    (format #t "Split on '::': ~a~%" (string-split-on-string test-multi "::"))
    (format #t "~%")
    
    (format #t "Split on multiple delims: ~a~%" 
           (string-split-on-any "a::b;;c::d" '("::" ";;")))))
