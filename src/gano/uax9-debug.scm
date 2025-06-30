;;; UAX #9 Unicode Bidirectional Algorithm - Debug and Analysis Utilities
;;; Debugging tools for bidirectional text processing

(define-module (gano uax9-debug)
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (ice-9 format)       ; more powerful format
  #:use-module (gano char)          ; Import bidi class functionality
  #:use-module (gano uax9-core)     ; Core bidi algorithm
  #:use-module (gano uax9-brackets) ; Bracket processing
  #:export (
            ;; Text analysis functions
            analyze-bidi-text
            print-bidi-analysis
            
            ;; Character-level debugging
            print-character-breakdown
            analyze-character-classes
            
            ;; Bracket debugging
            print-bracket-analysis
            analyze-bracket-pairs
            
            ;; Level analysis
            print-level-analysis
            analyze-embedding-levels
            
            ;; Document debugging
            print-document-analysis
            analyze-document-structure))

;;; =================================================================
;;; Comprehensive Text Analysis
;;; =================================================================

(define (analyze-bidi-text text)
  "Comprehensive analysis of bidirectional text for debugging.
   Returns detailed information about character types, levels, and bracket pairs."
  (let* ([char-list (string->list text)]
         [char-classes (map char-get-bidi-class char-list)]
         [base-direction (paragraph-base-direction text)]
         [resolved-levels (resolve-paragraph-bidi text)]
         [bracket-pairs (find-all-bracket-pairs text)]
         [validation (validate-bracket-structure text)])
    
    `((text . ,text)
      (length . ,(string-length text))
      (base-direction . ,base-direction)
      (character-classes . ,char-classes)
      (resolved-levels . ,resolved-levels)
      (bracket-pairs . ,(map (lambda (pair)
                               `((open-pos . ,(if (multi-line-bracket-pair? pair)
                                                   (open-bracket-line-position 
                                                    (multi-line-bracket-pair-open-bracket pair))
                                                   (bracket-pair-open-pos pair)))
                                 (close-pos . ,(if (multi-line-bracket-pair? pair)
                                                    (multi-line-bracket-pair-close-position pair)
                                                    (bracket-pair-close-pos pair)))
                                 (open-char . ,(if (multi-line-bracket-pair? pair)
                                                   (open-bracket-char 
                                                    (multi-line-bracket-pair-open-bracket pair))
                                                   (bracket-pair-open-char pair)))
                                 (close-char . ,(if (multi-line-bracket-pair? pair)
                                                    (multi-line-bracket-pair-close-char pair)
                                                    (bracket-pair-close-char pair)))
                                 (level . ,(if (multi-line-bracket-pair? pair)
                                                   (multi-line-bracket-pair-close-level pair)
                                                   (bracket-pair-level pair)))))
                             bracket-pairs))
      (bracket-validation . ,validation))))

(define (print-bidi-analysis text)
  "Print a human-readable analysis of bidirectional text"
  (let ([analysis (analyze-bidi-text text)])
    (format #t "=== Bidirectional Text Analysis ===~%")
    (format #t "Text: ~s~%" (assoc-ref analysis 'text))
    (format #t "Length: ~a characters~%" (assoc-ref analysis 'length))
    (format #t "Base Direction: ~a~%" (assoc-ref analysis 'base-direction))
    (format #t "~%Character breakdown:~%")
    
    (let ([chars (string->list (assoc-ref analysis 'text))]
          [classes (assoc-ref analysis 'character-classes)]
          [levels (assoc-ref analysis 'resolved-levels)])
      (for-each (lambda (i)
                  (let ([char (list-ref chars i)]
                        [class (list-ref classes i)]
                        [level (list-ref levels i)])
                    (format #t "  ~2d: ~c  ~4a  level=~a~%" i char class level)))
                (iota (length chars))))
    
    (format #t "~%Bracket pairs:~%")
    (let ([pairs (assoc-ref analysis 'bracket-pairs)])
      (if (null? pairs)
          (format #t "  (none)~%")
          (for-each (lambda (pair)
                      (format #t "  ~a(~a) at ~a ↔ ~a(~a) at ~a, level=~a~%"
                              (assoc-ref pair 'open-char)
                              (char->integer (assoc-ref pair 'open-char))
                              (assoc-ref pair 'open-pos)
                              (assoc-ref pair 'close-char)
                              (char->integer (assoc-ref pair 'close-char))
                              (assoc-ref pair 'close-pos)
                              (assoc-ref pair 'level)))
                    pairs)))
    
    (let ([validation (assoc-ref analysis 'bracket-validation)])
      (format #t "~%Bracket validation: ~a~%"
              (if (car validation) "VALID" "INVALID"))
      (when (not (null? (cdr validation)))
        (format #t "Unclosed brackets: ~a~%" (length (cdr validation)))))))

;;; =================================================================
;;; Character-level Debugging
;;; =================================================================

(define (analyze-character-classes text)
  "Analyze the distribution of bidirectional character classes in text"
  (let* ([chars (string->list text)]
         [classes (map char-get-bidi-class chars)]
         [class-counts (fold (lambda (class acc)
                               (let ([current (assoc-ref acc class)])
                                 (assoc-set! acc class (if current (+ current 1) 1))))
                             '()
                             classes)])
    
    `((total-characters . ,(length chars))
      (unique-classes . ,(length class-counts))
      (class-distribution . ,class-counts)
      (strong-characters . ,(length (filter (lambda (c) 
                                              (member c '(BC-L BC-R BC-AL))) 
                                            classes)))
      (weak-characters . ,(length (filter (lambda (c) 
                                            (member c '(BC-EN BC-ES BC-ET BC-AN BC-CS BC-NSM))) 
                                          classes)))
      (neutral-characters . ,(length (filter (lambda (c) 
                                               (member c '(BC-B BC-S BC-WS BC-ON))) 
                                             classes)))
      (control-characters . ,(length (filter (lambda (c) 
                                               (member c '(BC-LRE BC-LRO BC-RLE BC-RLO BC-PDF BC-LRI BC-RLI BC-FSI BC-PDI))) 
                                              classes))))))

(define (print-character-breakdown text)
  "Print detailed character-by-character breakdown"
  (let* ([chars (string->list text)]
         [classes (map char-get-bidi-class chars)]
         [levels (resolve-paragraph-bidi text)])
    
    (format #t "=== Character Breakdown ===~%")
    (format #t "Pos | Char | Unicode | Class | Level | Description~%")
    (format #t "----+------+---------+-------+-------+------------~%")
    
    (for-each (lambda (i)
                (let* ([char (list-ref chars i)]
                       [class (list-ref classes i)]
                       [level (list-ref levels i)]
                       [unicode (char->integer char)]
                       [desc (get-bidi-class-description class)])
                  (format #t "~3d | ~4a | U+~4,'0X  | ~5a | ~5a | ~a~%"
                          i 
                          (if (char-graphic? char) char #\?)
                          unicode
                          class
                          level
                          desc)))
              (iota (length chars)))))

(define (get-bidi-class-description class)
  "Get human-readable description of bidi class"
  (case class
    [(BC-L) "Left-to-Right"]
    [(BC-R) "Right-to-Left"]
    [(BC-AL) "Arabic Letter"]
    [(BC-EN) "European Number"]
    [(BC-ES) "European Separator"]
    [(BC-ET) "European Terminator"]
    [(BC-AN) "Arabic Number"]
    [(BC-CS) "Common Separator"]
    [(BC-NSM) "Nonspacing Mark"]
    [(BC-BN) "Boundary Neutral"]
    [(BC-B) "Paragraph Separator"]
    [(BC-S) "Segment Separator"]
    [(BC-WS) "Whitespace"]
    [(BC-ON) "Other Neutral"]
    [(BC-LRE) "Left-to-Right Embedding"]
    [(BC-LRO) "Left-to-Right Override"]
    [(BC-RLE) "Right-to-Left Embedding"]
    [(BC-RLO) "Right-to-Left Override"]
    [(BC-PDF) "Pop Directional Format"]
    [(BC-LRI) "Left-to-Right Isolate"]
    [(BC-RLI) "Right-to-Left Isolate"]
    [(BC-FSI) "First Strong Isolate"]
    [(BC-PDI) "Pop Directional Isolate"]
    [else "Unknown"]))

;;; =================================================================
;;; Bracket-specific Debugging
;;; =================================================================

(define (analyze-bracket-pairs text)
  "Analyze bracket pair structure in detail"
  (let* ([pairs (find-all-bracket-pairs text)]
         [nesting-levels (map (lambda (pos) 
                                (get-bracket-nesting-level text pos))
                              (iota (string-length text)))]
         [max-nesting (if (null? nesting-levels) 0 (apply max nesting-levels))])
    
    `((total-pairs . ,(length pairs))
      (max-nesting-level . ,max-nesting)
      (bracket-positions . ,(map (lambda (char pos)
                                   (if (get-bracket-type char)
                                       (cons pos char)
                                       #f))
                                 (string->list text)
                                 (iota (string-length text))))
      (nesting-at-positions . ,nesting-levels)
      (pair-details . ,(map (lambda (pair)
                              (if (multi-line-bracket-pair? pair)
                                  `((type . multi-line)
                                    (open-pos . ,(open-bracket-line-position 
                                                  (multi-line-bracket-pair-open-bracket pair)))
                                    (close-pos . ,(multi-line-bracket-pair-close-position pair))
                                    (open-char . ,(open-bracket-char 
                                                   (multi-line-bracket-pair-open-bracket pair)))
                                    (close-char . ,(multi-line-bracket-pair-close-char pair))
                                    (spans-lines . ,(multi-line-bracket-pair-spans-lines? pair)))
                                  `((type . single-line)
                                    (open-pos . ,(bracket-pair-open-pos pair))
                                    (close-pos . ,(bracket-pair-close-pos pair))
                                    (open-char . ,(bracket-pair-open-char pair))
                                    (close-char . ,(bracket-pair-close-char pair))
                                    (level . ,(bracket-pair-level pair)))))
                            pairs)))))

(define (print-bracket-analysis text)
  "Print detailed bracket analysis"
  (let ([analysis (analyze-bracket-pairs text)])
    (format #t "=== Bracket Analysis ===~%")
    (format #t "Total bracket pairs: ~a~%" (assoc-ref analysis 'total-pairs))
    (format #t "Maximum nesting level: ~a~%" (assoc-ref analysis 'max-nesting-level))
    
    (format #t "~%Bracket positions:~%")
    (let ([positions (filter identity (assoc-ref analysis 'bracket-positions))])
      (if (null? positions)
          (format #t "  (no brackets)~%")
          (for-each (lambda (pos-char)
                      (format #t "  Position ~a: ~a (~a)~%"
                              (car pos-char)
                              (cdr pos-char)
                              (if (char-opening-bracket? (cdr pos-char)) "open" "close")))
                    positions)))
    
    (format #t "~%Nesting levels by position:~%")
    (let ([nesting (assoc-ref analysis 'nesting-at-positions)])
      (for-each (lambda (pos level)
                  (when (> level 0)
                    (format #t "  Position ~a: level ~a~%" pos level)))
                (iota (length nesting))
                nesting))
    
    (format #t "~%Pair details:~%")
    (let ([pairs (assoc-ref analysis 'pair-details)])
      (if (null? pairs)
          (format #t "  (no pairs)~%")
          (for-each (lambda (pair i)
                      (format #t "  Pair ~a: ~a at ~a ↔ ~a at ~a~%"
                              i
                              (assoc-ref pair 'open-char)
                              (assoc-ref pair 'open-pos)
                              (assoc-ref pair 'close-char)
                              (assoc-ref pair 'close-pos)))
                    pairs
                    (iota (length pairs)))))))

;;; =================================================================
;;; Embedding Level Analysis
;;; =================================================================

(define (analyze-embedding-levels text)
  "Analyze embedding level structure"
  (let* ([levels (resolve-paragraph-bidi text)]
         [max-level (if (null? levels) 0 (apply max levels))]
         [min-level (if (null? levels) 0 (apply min levels))]
         [level-changes (count-level-changes levels)]
         [level-distribution (count-level-distribution levels)])
    
    `((text-length . ,(string-length text))
      (min-level . ,min-level)
      (max-level . ,max-level)
      (level-range . ,(- max-level min-level))
      (level-changes . ,level-changes)
      (level-distribution . ,level-distribution)
      (levels . ,levels))))

(define (count-level-changes levels)
  "Count the number of embedding level changes"
  (if (< (length levels) 2)
      0
      (length (filter identity
                      (map (lambda (a b) (not (= a b)))
                           levels
                           (cdr levels))))))

(define (count-level-distribution levels)
  "Count frequency of each embedding level"
  (fold (lambda (level acc)
          (let ([current (assoc-ref acc level)])
            (assoc-set! acc level (if current (+ current 1) 1))))
        '()
        levels))

(define (print-level-analysis text)
  "Print detailed embedding level analysis"
  (let ([analysis (analyze-embedding-levels text)])
    (format #t "=== Embedding Level Analysis ===~%")
    (format #t "Text length: ~a characters~%" (assoc-ref analysis 'text-length))
    (format #t "Level range: ~a to ~a (span: ~a)~%"
            (assoc-ref analysis 'min-level)
            (assoc-ref analysis 'max-level)
            (assoc-ref analysis 'level-range))
    (format #t "Level changes: ~a~%" (assoc-ref analysis 'level-changes))
    
    (format #t "~%Level distribution:~%")
    (let ([distribution (assoc-ref analysis 'level-distribution)])
      (for-each (lambda (level-count)
                  (format #t "  Level ~a: ~a characters (~,1f%)~%"
                          (car level-count)
                          (cdr level-count)
                          (* 100.0 (/ (cdr level-count) (assoc-ref analysis 'text-length)))))
                (sort distribution (lambda (a b) (< (car a) (car b))))))
    
    (format #t "~%Level sequence:~%")
    (let ([levels (assoc-ref analysis 'levels)])
      (format #t "  ~a~%" levels))))

;;; =================================================================
;;; Document-level Analysis
;;; =================================================================

(define (analyze-document-structure lines)
  "Analyze bidirectional structure across multiple lines"
  (let* ([line-analyses (map analyze-bidi-text lines)]
         [bracket-analysis (analyze-document-brackets lines)]
         [total-chars (apply + (map (lambda (analysis) 
                                      (assoc-ref analysis 'length)) 
                                    line-analyses))]
         [base-directions (map (lambda (analysis) 
                                 (assoc-ref analysis 'base-direction)) 
                               line-analyses)])
    
    `((total-lines . ,(length lines))
      (total-characters . ,total-chars)
      (average-line-length . ,(if (> (length lines) 0) 
                                  (/ total-chars (length lines)) 
                                  0))
      (base-directions . ,base-directions)
      (mixed-direction-lines . ,(length (filter (lambda (dir) 
                                                   (not (eq? dir 'ltr))) 
                                                 base-directions)))
      (bracket-analysis . ,bracket-analysis)
      (line-analyses . ,line-analyses))))

(define (print-document-analysis lines)
  "Print comprehensive document analysis"
  (let ([analysis (analyze-document-structure lines)])
    (format #t "=== Document Analysis ===~%")
    (format #t "Total lines: ~a~%" (assoc-ref analysis 'total-lines))
    (format #t "Total characters: ~a~%" (assoc-ref analysis 'total-characters))
    (format #t "Average line length: ~,1f characters~%" (assoc-ref analysis 'average-line-length))
    (format #t "Mixed direction lines: ~a~%" (assoc-ref analysis 'mixed-direction-lines))
    
    (format #t "~%Base direction by line:~%")
    (let ([directions (assoc-ref analysis 'base-directions)])
      (for-each (lambda (line dir)
                  (format #t "  Line ~a: ~a~%" line dir))
                (iota (length directions))
                directions))
    
    (let ([bracket-analysis (assoc-ref analysis 'bracket-analysis)])
      (format #t "~%Document bracket summary:~%")
      (format #t "  Total pairs: ~a~%" (assoc-ref bracket-analysis 'total-pairs))
      (format #t "  Multi-line pairs: ~a~%" (assoc-ref bracket-analysis 'multi-line-pairs))
      (format #t "  Single-line pairs: ~a~%" (assoc-ref bracket-analysis 'single-line-pairs))
      (format #t "  Final unclosed: ~a~%" 
              (length (assoc-ref bracket-analysis 'final-unclosed-brackets))))))

;;; =================================================================
;;; Utility Functions
;;; =================================================================

(define (format-unicode-char char)
  "Format a character with its Unicode code point"
  (format #f "~a (U+~4,'0X)" char (char->integer char)))

(define (format-bidi-class class)
  "Format a bidi class with description"
  (format #f "~a (~a)" class (get-bidi-class-description class)))
