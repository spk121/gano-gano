;;; string-split.scm
;;; Enhanced string splitting functions for multi-character delimiters

;;; All functions run in time linear in the length of the input.

(define-module (gano string-split)
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-13)       ; string-contains, string-join
  #:use-module ((gano string-utils)
                #:select (string-detect-line-ending
                          string-find-string
                          string-char-positions))
  #:re-export (string-detect-line-ending
               string-find-string
               string-char-positions)
  #:export (
    ;; Core splitting functions
    string-split-on-string
    string-split-on-any
    string-split-at-char
    
    ;; Line ending utilities
    string-split-lines
    string-split-lines-with-final-newline-info
    string-normalize-line-endings
    
    ;; Helper functions
    string-join-with))

;;; =================================================================
;;; HELPER FUNCTIONS
;;; =================================================================

(define (string-join-with string-list separator)
  "Join list of strings with SEPARATOR between them."
  (string-join string-list separator))

;;; =================================================================
;;; CORE SPLITTING FUNCTIONS
;;; =================================================================

(define (string-split-at-char str char)
  "Split string at all occurrences of CHAR, returning list of substrings.
   N occurrences give N+1 pieces (some possibly empty)."
  (let loop ([end (string-length str)] [i (- (string-length str) 1)] [acc '()])
    (cond
     [(< i 0) (cons (substring str 0 end) acc)]
     [(char=? (string-ref str i) char)
      (loop i (- i 1) (cons (substring str (+ i 1) end) acc))]
     [else (loop end (- i 1) acc)])))

(define (string-split-on-string str delimiter)
  "Split string on all non-overlapping occurrences of DELIMITER, scanning
   left to right.  An empty DELIMITER splits STR into single characters.
   The empty string gives (\"\")."
  (cond
    [(string-null? str) '("")]
    [(string-null? delimiter) (map string (string->list str))]
    [else
     (let ([delimiter-len (string-length delimiter)])
       (let loop ([start 0] [acc '()])
         (let ([pos (string-contains str delimiter start)])
           (if pos
               (loop (+ pos delimiter-len) (cons (substring str start pos) acc))
               (reverse (cons (substring str start) acc))))))]))

(define (string-split-on-any str delimiters)
  "Split string on any of the delimiter strings in DELIMITERS.  At each
   position the first delimiter in the list that matches there is used,
   so put longer delimiters first (e.g. \"\\r\\n\" before \"\\n\").
   Empty delimiters are ignored.  The empty string gives (\"\")."
  (let ([delimiters (remove string-null? delimiters)]
        [len (string-length str)])
    (define (match-at i)
      ;; The delimiter matching at I, or #f
      (find (lambda (d) (string-prefix? d str 0 (string-length d) i len)) delimiters))
    (if (null? delimiters)
        (list str)
        (let loop ([i 0] [start 0] [acc '()])
          (if (>= i len)
              (reverse (cons (substring str start) acc))
              (let ([d (match-at i)])
                (if d
                    (let ([next (+ i (string-length d))])
                      (loop next next (cons (substring str start i) acc)))
                    (loop (+ i 1) start acc))))))))

;;; =================================================================
;;; LINE ENDING UTILITIES
;;; =================================================================

(define (string-split-lines str)
  "Split string into lines at line endings: \\r\\n, \\n, \\r, and the Unicode
   line and paragraph separators U+2028 and U+2029.  A trailing line
   ending gives a final empty line; the empty string gives (\"\")."
  (let ([len (string-length str)])
    (let loop ([i 0] [start 0] [acc '()])
      (if (>= i len)
          (reverse (cons (substring str start) acc))
          (let ([ch (string-ref str i)])
            (cond
             [(and (char=? ch #\return) (< (+ i 1) len)
                   (char=? (string-ref str (+ i 1)) #\newline))
              (loop (+ i 2) (+ i 2) (cons (substring str start i) acc))]
             [(memv ch '(#\newline #\return #\x2028 #\x2029))
              (loop (+ i 1) (+ i 1) (cons (substring str start i) acc))]
             [else (loop (+ i 1) start acc)]))))))

(define (string-split-lines-with-final-newline-info str)
  "Split string into lines as string-split-lines does, but without the
   empty line that follows a trailing line ending.
   Returns (lines . ends-with-line-ending?).  The empty string gives
   ((\"\") . #f)."
  (cond
   [(string-null? str)
    (cons '("") #f)]
   [else
    (let* ([lines (string-split-lines str)]
           [last-char (string-ref str (- (string-length str) 1))]
           [ends-with-newline? (and (memv last-char '(#\newline #\return #\x2028 #\x2029)) #t)])
      (if ends-with-newline?
          (cons (drop-right lines 1) #t)
          (cons lines #f)))]))

(define (string-normalize-line-endings str target-ending)
  "Convert all line endings in string to TARGET-ENDING (any string, e.g.
   \"\\n\", \"\\r\\n\", \"\\r\", or U+2028/U+2029)."
  (string-join (string-split-lines str) target-ending))

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
