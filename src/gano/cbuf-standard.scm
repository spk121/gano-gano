;;; Gano Character Buffer Module - Standard Operations with Undo Support
;;; Complete ECMA-48 terminal control implementation
;;;
;;; This file contains standard text editing operations beyond the basic MVP
;;; All buffer-modifying operations now support undo through the plugin system

(define-module (gano cbuf-standard)
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
  #:use-module (ice-9 textual-ports)     ; get-string-all
  #:use-module (ice-9 regex)             ; Regular expressions
  #:export (
    ;; Navigation
    cbuf-goto-line!
    cbuf-goto-home!
    cbuf-goto-limit!
    cbuf-page-up!
    cbuf-page-down!
    cbuf-forward-word!
    cbuf-backward-word!

    ;; Selection
    cbuf-select-all!
    cbuf-select-word!
    cbuf-select-line!
    cbuf-extend-selection-forward-word!
    cbuf-extend-selection-backward-word!

    ;; Cut/Copy/Paste
    cbuf-paste-previous!
    cbuf-cut-line!
    cbuf-copy-line!
    cbuf-cut-word!
    cbuf-copy-word!

    ;; Deletion
    cbuf-delete-word-forward!
    cbuf-delete-word-backward!
    cbuf-delete-to-end-of-line!
    cbuf-delete-to-beginning-of-line!
    
    ;; Search
    cbuf-search-forward!
    cbuf-search-backward!
    cbuf-search-replace!
    cbuf-search-replace-all!

    ;; Code-specific
    cbuf-comment-line!
    cbuf-comment-region!
    cbuf-uncomment-region!
    cbuf-duplicate-line!
    cbuf-move-line-up!
    cbuf-move-line-down!

    ;; Indentation
    cbuf-indent-line!
    cbuf-indent-region!
    cbuf-outdent-line!
    cbuf-outdent-region!
    cbuf-newline-and-indent!

    ;; Text transformation
    cbuf-upcase-region!
    cbuf-downcase-region!
    cbuf-capitalize-region!
    cbuf-delete-trailing-whitespace!
    cbuf-trim-whitespace!

    ;; Undo/Redo
    cbuf-redo!
    
    ;; Line utilities
    cbuf-get-current-line-indentation
    cbuf-get-indentation-level
    cbuf-set-comment-string!
    cbuf-get-comment-string

    ;; Undo registration
    cbuf-register-standard-undo-operations!
    ))

;;; =================================================================
;;; INTERNAL STATE FOR STANDARD OPERATIONS
;;; =================================================================

;; Comment string for code commenting (can be customized)
(define *comment-string* ";;")
(define *search-history* '())
(define *replace-history* '())

;;; =================================================================
;;; UNDO OPERATION HANDLERS FOR STANDARD OPERATIONS
;;; =================================================================

;; Word deletion handlers
(define (capture-word-deletion-state cbuf direction position)
  "Capture state for word deletion (forward or backward)"
  `((line-num ,(cbuf-line-cur cbuf))
    (old-metrics ,(cbuf-metrics-cur cbuf))
    (direction ,direction)))

(define (restore-word-deletion-state cbuf state direction position)
  "Restore state after word deletion"
  (let ([line-num (cadr (assq 'line-num state))]
        [old-metrics (cadr (assq 'old-metrics state))])
    (cbuf-restore-line-metrics! cbuf line-num old-metrics)))

;; Line/region modification handlers
(define* (capture-line-modification-state cbuf #:optional operation-data)
  "Capture state for operations that modify entire lines"
  `((line-num ,(cbuf-line-cur cbuf))
    (old-metrics ,(cbuf-metrics-cur cbuf))
    (operation-data ,operation-data)))

(define* (restore-line-modification-state cbuf state #:optional operation-data)
  "Restore state after line modification"
  (let ([line-num (cadr (assq 'line-num state))]
        [old-metrics (cadr (assq 'old-metrics state))])
    (cbuf-restore-line-metrics! cbuf line-num old-metrics)))

;; Multi-line operation handlers
(define* (capture-multiline-operation-state cbuf start-line end-line #:optional operation-type)
  "Capture state for operations affecting multiple lines"
  (let ([affected-lines (let loop ([line start-line] [result '()])
                          (if (> line end-line)
                              (reverse result)
                              (loop (+ line 1)
                                    (cons (cons line (list-ref (cbuf-text-metrics cbuf) line))
                                          result))))])
    `((affected-lines ,affected-lines)
      (start-line ,start-line)
      (end-line ,end-line)
      (operation-type ,operation-type))))

(define* (restore-multiline-operation-state cbuf state start-line end-line #:optional operation-type)
  "Restore state after multi-line operation"
  (let ([affected-lines (cadr (assq 'affected-lines state))])
    (for-each (lambda (line-data)
                (let ([line-num (car line-data)]
                      [old-metrics (cdr line-data)])
                  (when (< line-num (cbuf-line-count cbuf))
                    (cbuf-restore-line-metrics! cbuf line-num old-metrics))))
              affected-lines)))

;; Line movement handlers  
(define (capture-line-movement-state cbuf direction)
  "Capture state for line movement operations"
  (let ([current-line (cbuf-line-cur cbuf)])
    (case direction
      [(up)
       (when (> current-line 0)
         `((current-line ,current-line)
           (current-metrics ,(cbuf-metrics-cur cbuf))
           (prev-line ,(- current-line 1))
           (prev-metrics ,(list-ref (cbuf-text-metrics cbuf) (- current-line 1)))
           (direction ,direction)))]
      [(down)
       (when (< current-line (- (cbuf-line-count cbuf) 1))
         `((current-line ,current-line)
           (current-metrics ,(cbuf-metrics-cur cbuf))
           (next-line ,(+ current-line 1))
           (next-metrics ,(list-ref (cbuf-text-metrics cbuf) (+ current-line 1)))
           (direction ,direction)))])))

(define (restore-line-movement-state cbuf state direction)
  "Restore state after line movement"
  (let ([current-line (cadr (assq 'current-line state))]
        [current-metrics (cadr (assq 'current-metrics state))]
        [direction (cadr (assq 'direction state))])
    
    (case direction
      [(up)
       (let ([prev-line (cadr (assq 'prev-line state))]
             [prev-metrics (cadr (assq 'prev-metrics state))])
         ;; Restore both lines to their original positions
         (cbuf-restore-line-metrics! cbuf prev-line prev-metrics)
         (cbuf-restore-line-metrics! cbuf current-line current-metrics))]
      [(down)
       (let ([next-line (cadr (assq 'next-line state))]
             [next-metrics (cadr (assq 'next-metrics state))])
         ;; Restore both lines to their original positions
         (cbuf-restore-line-metrics! cbuf current-line current-metrics)
         (cbuf-restore-line-metrics! cbuf next-line next-metrics))])))

;; Global buffer modification handlers
(define (capture-global-modification-state cbuf . args)
  "Capture state for operations that modify the entire buffer.
   ARGS are the operation's own arguments (e.g. the search and replace
   patterns for replace-all); they are not needed to restore the buffer."
  `((all-metrics ,(cbuf-text-metrics cbuf))))

(define (restore-global-modification-state cbuf state . args)
  "Restore state after global buffer modification"
  (let ([all-metrics (cadr (assq 'all-metrics state))])
    (set-cbuf-text-metrics! cbuf all-metrics)))

;;; =================================================================
;;; HELPER FUNCTIONS
;;; =================================================================

(define (cbuf-set-positions! cbuf n device)
  "Set position based on device type ('data or 'presentation)"
  (cond
   [(eq? device 'data)
    (cbuf-set-x! cbuf n 'data)]
   [(eq? device 'presentation)
    (cbuf-set-x! cbuf n 'cell)]
   [else
    (error "Invalid device type" device)]))

(define (cbuf-find-word-bounds cbuf)
  "Find the bounds of the word at current position.
   Returns (start-line start-x-data end-line end-x-data)"
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [text (cbuf-text-cur cbuf)]
         [text-len (string-length text)])
    
    (if (string-null? text)
        (list current-line 0 current-line 0)
        (let* ([current-index (cbuf-x-data->x-index cbuf current-x)]
               [start-index (skip-word-chars-backward text current-index char-word-delimiter?)]
               [end-index (skip-word-chars-forward text current-index char-word-delimiter?)]
               [start-x-data (cbuf-x-index->x-data cbuf start-index)]
               [end-x-data (cbuf-x-index->x-data cbuf end-index)])
          (list current-line start-x-data current-line end-x-data)))))

(define (cbuf-get-indentation-string cbuf level)
  "Get indentation string for given level"
  (let ([tab-size (cbuf-tab-size cbuf)])
    (make-string (* level tab-size) #\space)))

;;; =================================================================
;;; NAVIGATION (No undo needed - these don't modify buffer content)
;;; =================================================================

(define (cbuf-goto-line! cbuf line)
  "Move cursor to home position of specified line"
  (cbuf-set-y! cbuf line)
  (cbuf-set-positions! cbuf (cbuf-home-pos cbuf) (cbuf-limit-type cbuf)))

(define (cbuf-goto-home! cbuf)
  "Move cursor to home position of current line"
  (cbuf-set-positions! cbuf (cbuf-home-pos cbuf) (cbuf-limit-type cbuf)))
  
(define (cbuf-goto-limit! cbuf)
  "Move cursor to limit position of current line"
  (cbuf-set-positions! cbuf (cbuf-limit-pos cbuf) (cbuf-limit-type cbuf)))

(define (cbuf-page-up! cbuf)
  "Move cursor up one page size"
  (let* ([current-line (cbuf-line-cur cbuf)]
         [page-size (cbuf-form-size cbuf)]
         [new-line (max 0 (- current-line page-size))])
    (cbuf-set-y! cbuf new-line)))

(define (cbuf-page-down! cbuf)
  "Move cursor down one page size"
  (let* ([current-line (cbuf-line-cur cbuf)]
         [page-size (cbuf-form-size cbuf)]
         [max-line (- (cbuf-line-count cbuf) 1)]
         [new-line (min max-line (+ current-line page-size))])
    (cbuf-set-y! cbuf new-line)))

(define (cbuf-forward-word! cbuf)
  "Move cursor forward to the beginning of the next word"
  (let* ([text (cbuf-text-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [current-index (cbuf-x-data->x-index cbuf current-x)]
         [end-index (find-word-end-forward text current-index char-word-delimiter?)])
    
    (if (< end-index (string-length text))
        ;; Move to end of current word, then skip delimiters to next word
        (let ([next-word-index (skip-delimiters-forward text end-index)])
          (cbuf-set-x! cbuf (cbuf-x-index->x-data cbuf next-word-index) 'data))
        ;; At end of line, move to next line
        (when (< (cbuf-line-cur cbuf) (- (cbuf-line-count cbuf) 1))
          (cbuf-next-line! cbuf)
          (cbuf-beginning-of-line! cbuf)))))

(define (cbuf-backward-word! cbuf)
  "Move cursor backward to the beginning of the previous word"
  (let* ([text (cbuf-text-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [current-index (cbuf-x-data->x-index cbuf current-x)])
    
    (if (> current-index 0)
        (let ([start-index (find-word-begin-backward text (- current-index 1) char-word-delimiter?)])
          (cbuf-set-x! cbuf (cbuf-x-index->x-data cbuf start-index) 'data))
        ;; At beginning of line, move to previous line
        (when (> (cbuf-line-cur cbuf) 0)
          (cbuf-previous-line! cbuf)
          (cbuf-end-of-line! cbuf)))))

;;; =================================================================
;;; SELECTION (No undo needed - these don't modify buffer content)
;;; =================================================================

(define (cbuf-select-all! cbuf)
  "Select all text in the buffer"
  (cbuf-beginning-of-buffer! cbuf)
  (cbuf-set-mark! cbuf)
  (cbuf-end-of-buffer! cbuf))

(define (cbuf-select-word! cbuf)
  "Select the word at current cursor position"
  (let ([bounds (cbuf-find-word-bounds cbuf)])
    (let ([start-line (car bounds)]
          [start-x (cadr bounds)]
          [end-line (caddr bounds)]
          [end-x (cadddr bounds)])
      
      ;; Move to start of word and set mark
      (cbuf-set-y! cbuf start-line)
      (cbuf-set-x! cbuf start-x 'data)
      (cbuf-set-mark! cbuf)
      
      ;; Move to end of word
      (cbuf-set-y! cbuf end-line)
      (cbuf-set-x! cbuf end-x 'data))))

(define (cbuf-select-line! cbuf)
  "Select the entire current line"
  (cbuf-beginning-of-line! cbuf)
  (cbuf-set-mark! cbuf)
  (cbuf-end-of-line! cbuf))

(define (cbuf-extend-selection-forward-word! cbuf)
  "Extend selection forward by one word"
  (unless (cbuf-mark-set? cbuf)
    (cbuf-set-mark! cbuf))
  (cbuf-forward-word! cbuf))

(define (cbuf-extend-selection-backward-word! cbuf)
  "Extend selection backward by one word"
  (unless (cbuf-mark-set? cbuf)
    (cbuf-set-mark! cbuf))
  (cbuf-backward-word! cbuf))

;;; =================================================================
;;; CUT/COPY/PASTE (paste operations need undo, cut/copy delegate to basic operations)
;;; =================================================================

(define (cbuf-paste-previous! cbuf)
  "Paste from previous entry in cut buffer (if available) with undo support"
  (let ([cut-buffer (cbuf-cut-buffer cbuf)])
    (when (and cut-buffer (> (length cut-buffer) 1))
      ;; Rotate the cut buffer
      (let ([rotated-buffer (append (cdr cut-buffer) (list (car cut-buffer)))])
        (set-cbuf-cut-buffer! cbuf rotated-buffer)
        (cbuf-paste! cbuf)))))  ; cbuf-paste! already has undo support

(define (cbuf-select-line-including-newline! cbuf)
  "Select the entire current line including its newline character.
   This removes the line completely when cut, rather than leaving an empty line."
  (let ([current-line (cbuf-line-cur cbuf)])
    (cbuf-beginning-of-line! cbuf)
    (cbuf-set-mark! cbuf)
    
    ;; Move to beginning of next line (or end of buffer if last line)
    (if (< current-line (- (cbuf-line-count cbuf) 1))
        ;; Not the last line - move to start of next line
        (begin
          (cbuf-next-line! cbuf)
          (cbuf-beginning-of-line! cbuf))
        ;; Last line - select to end of buffer
        (cbuf-end-of-buffer! cbuf))))

(define (cbuf-cut-line! cbuf)
  "Cut the entire current line, removing it completely"
  (cbuf-select-line-including-newline! cbuf)
  (cbuf-cut-region! cbuf))  ; cbuf-cut-region! already has undo support

(define (cbuf-copy-line! cbuf)
  "Copy the entire current line (no undo needed)"
  (cbuf-select-line-including-newline! cbuf)
  (cbuf-copy-region! cbuf))

(define (cbuf-cut-word! cbuf)
  "Cut the word at current position"
  (cbuf-select-word! cbuf)
  (cbuf-cut-region! cbuf))  ; cbuf-cut-region! already has undo support

(define (cbuf-copy-word! cbuf)
  "Copy the word at current position (no undo needed)"
  (cbuf-select-word! cbuf)
  (cbuf-copy-region! cbuf))

;;; =================================================================
;;; DELETION (All need undo support)
;;; =================================================================

(define (cbuf-delete-word-forward! cbuf)
  "Delete from cursor to end of current word with undo support"
  (let* ([text (cbuf-text-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [current-index (cbuf-x-data->x-index cbuf current-x)]
         [end-index (find-word-end-forward text current-index char-word-delimiter?)])
    
    (when (> end-index current-index)
      ;; Save undo state
      (cbuf-save-undo! cbuf 'delete-word 'forward current-x)
      
      (let ([end-x-data (cbuf-x-index->x-data cbuf end-index)])
        (cbuf-delete-region! cbuf (cbuf-line-cur cbuf) current-x 
                             (cbuf-line-cur cbuf) end-x-data)))))

(define (cbuf-delete-word-backward! cbuf)
  "Delete from cursor to beginning of current word with undo support"
  (let* ([text (cbuf-text-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [current-index (cbuf-x-data->x-index cbuf current-x)]
         [start-index (if (> current-index 0)
                         (find-word-begin-backward text (- current-index 1) char-word-delimiter?)
                         0)])
    
    (when (< start-index current-index)
      ;; Save undo state
      (cbuf-save-undo! cbuf 'delete-word 'backward current-x)
      
      (let ([start-x-data (cbuf-x-index->x-data cbuf start-index)])
        (cbuf-delete-region! cbuf (cbuf-line-cur cbuf) start-x-data 
                             (cbuf-line-cur cbuf) current-x)))))

(define (cbuf-delete-to-end-of-line! cbuf)
  "Delete from cursor to end of line with undo support"
  (let ([current-x (cbuf-x-data cbuf)]
        [line-length (cbuf-text-cur-base-length cbuf)])
    (when (< current-x line-length)
      ;; Save undo state  
      (cbuf-save-undo! cbuf 'delete-to-eol current-x)
      
      (cbuf-delete-region! cbuf (cbuf-line-cur cbuf) current-x 
                           (cbuf-line-cur cbuf) line-length))))

(define (cbuf-delete-to-beginning-of-line! cbuf)
  "Delete from cursor to beginning of line with undo support"
  (let ([current-x (cbuf-x-data cbuf)])
    (when (> current-x 0)
      ;; Save undo state
      (cbuf-save-undo! cbuf 'delete-to-bol current-x)
      
      (cbuf-delete-region! cbuf (cbuf-line-cur cbuf) 0 
                           (cbuf-line-cur cbuf) current-x))))

;;; =================================================================
;;; SEARCH AND REPLACE (Replace operations need undo)
;;; =================================================================

(define (char-word-character? ch)
  "Return #t if character is a letter or number (word character)"
  (or (char-alphabetic? ch) (char-numeric? ch)))

(define (is-whole-word-match? text match-start match-end)
  "Check if match is a whole word (not preceded/followed by alphanumeric)"
  (let ([before-ok (or (= match-start 0)
                      (not (char-word-character? (string-ref text (- match-start 1)))))]
        [after-ok (or (= match-end (string-length text))
                     (not (char-word-character? (string-ref text match-end))))])
    (and before-ok after-ok)))

(define (find-pattern-in-text text pattern start-pos case-insensitive? whole-word?)
  "Find pattern in text starting from start-pos with options.
   Returns match position or #f if not found."
  (let ([search-text (if case-insensitive? (string-downcase text) text)]
        [search-pattern (if case-insensitive? (string-downcase pattern) pattern)])
    
    (let loop ([pos (or start-pos 0)])
      (let ([match (string-contains search-text search-pattern pos)])
        (cond
         [(not match) #f]
         [(not whole-word?) match]  ; Found match and whole-word not required
         [(is-whole-word-match? text match (+ match (string-length pattern)))
          match]  ; Found whole-word match
         [else
          ;; Not a whole-word match, continue searching
          (loop (+ match 1))])))))

(define (find-pattern-in-text-backward text pattern end-pos case-insensitive? whole-word?)
  "Find pattern in text backward from end-pos with options.
   Returns match position or #f if not found."
  (let* ([search-text (if case-insensitive? (string-downcase text) text)]
         [search-pattern (if case-insensitive? (string-downcase pattern) pattern)]
         [search-in (substring search-text 0 (min end-pos (string-length text)))])
    
    (let loop ([match (string-contains-right search-in search-pattern)])
      (cond
       [(not match) #f]
       [(not whole-word?) match]  ; Found match and whole-word not required
       [(is-whole-word-match? text match (+ match (string-length pattern)))
        match]  ; Found whole-word match
       [else
        ;; Not a whole-word match, search for previous occurrence
        (if (> match 0)
            (loop (string-contains-right (substring search-in 0 match) search-pattern))
            #f)]))))

;; SRFI-13 has no right-to-left substring search, so provide one.
(define (string-contains-right s pattern)
  "Return the index of the last occurrence of PATTERN in S, or #f."
  (let ([plen (string-length pattern)])
    (let loop ([i (- (string-length s) plen)])
      (cond
       [(< i 0) #f]
       [(string=? (substring s i (+ i plen)) pattern) i]
       [else (loop (- i 1))]))))

(define (preserve-case original replacement)
  "Preserve case pattern from original string when replacing with replacement.
   Only works if both strings have same length."
  (if (not (= (string-length original) (string-length replacement)))
      replacement  ; Can't preserve case if lengths differ
      (let ([result (string-copy replacement)])
        (string-for-each-index
         (lambda (i)
           (let ([orig-char (string-ref original i)]
                 [repl-char (string-ref result i)])
             (cond
              [(char-upper-case? orig-char)
               (string-set! result i (char-upcase repl-char))]
              [(char-lower-case? orig-char)
               (string-set! result i (char-downcase repl-char))])))
         result)
        result)))

(define* (cbuf-search-forward! cbuf pattern #:key (case-insensitive? #f) (whole-word? #f))
  "Search for pattern forward from current position with options.
   #:case-insensitive? - ignore case when matching
   #:whole-word? - only match complete words"
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [line-count (cbuf-line-count cbuf)])
    
    ;; Add to search history
    (set! *search-history* (cons pattern *search-history*))
    
    ;; Search from current position
    (let search-loop ([line current-line] [start-x current-x])
      (cond
       [(>= line line-count) #f] ; End of buffer
       
       [else
        (let* ([text (cbuf-get-line-text cbuf line)]
               [search-from (if (= line current-line) 
                               (cbuf-x-data->x-index cbuf start-x)
                               0)]
               [match (find-pattern-in-text text pattern search-from 
                                            case-insensitive? whole-word?)])
          
          (if match
              (begin
                ;; Found match - move cursor there
                (cbuf-set-y! cbuf line)
                (cbuf-set-x! cbuf (cbuf-x-index->x-data cbuf match) 'data)
                ;; Select the matched text
                (cbuf-set-mark! cbuf)
                (cbuf-set-x! cbuf (cbuf-x-index->x-data cbuf (+ match (string-length pattern))) 'data)
                #t)
              ;; No match on this line, try next
              (search-loop (+ line 1) 0)))]))))

(define* (cbuf-search-backward! cbuf pattern #:key (case-insensitive? #f) (whole-word? #f))
  "Search for pattern backward from current position with options.
   #:case-insensitive? - ignore case when matching  
   #:whole-word? - only match complete words"
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)])
    
    ;; Add to search history
    (set! *search-history* (cons pattern *search-history*))
    
    ;; Search from current position
    (let search-loop ([line current-line] [end-x (max 0 (- current-x 1))])
      (cond
       [(< line 0) #f] ; Beginning of buffer
       
       [else
        (let* ([text (cbuf-get-line-text cbuf line)]
               [search-end (if (= line current-line)
                              (cbuf-x-data->x-index cbuf end-x)
                              (string-length text))]
               [match (find-pattern-in-text-backward text pattern search-end
                                                    case-insensitive? whole-word?)])
          
          (if match
              (begin
                ;; Found match - move cursor there
                (cbuf-set-y! cbuf line)
                (cbuf-set-x! cbuf (cbuf-x-index->x-data cbuf match) 'data)
                ;; Select the matched text
                (cbuf-set-mark! cbuf)
                (cbuf-set-x! cbuf (cbuf-x-index->x-data cbuf (+ match (string-length pattern))) 'data)
                #t)
              ;; No match on this line, try previous
              (search-loop (- line 1) #f)))]))))

(define* (cbuf-search-replace! cbuf search-pattern replace-pattern 
                              #:key (case-insensitive? #f) (whole-word? #f) (preserve-case? #f))
  "Replace current selection if it matches search pattern with options.
   Has undo support through underlying cbuf-insert-string!
   #:case-insensitive? - ignore case when matching
   #:whole-word? - only match complete words
   #:preserve-case? - preserve original case pattern in replacement"
  (when (cbuf-mark-set? cbuf)
    (let* ([selected-text (cbuf-get-region-text cbuf)]
           [matches? (if case-insensitive?
                        (string-ci=? selected-text search-pattern)
                        (string=? selected-text search-pattern))]
           [whole-word-ok? (if whole-word?
                              ;; For replace, we assume current selection is already validated
                              ;; since it came from a search operation
                              #t
                              #t)])
      
      (when (and matches? whole-word-ok?)
        (let ([final-replacement (if preserve-case?
                                    (preserve-case selected-text replace-pattern)
                                    replace-pattern)])
          ;; cbuf-insert-string! has its own undo support
          (cbuf-insert-string! cbuf final-replacement)
          (set! *replace-history* (cons (cons search-pattern replace-pattern) *replace-history*))
          #t)))))

(define* (cbuf-search-replace-all! cbuf search-pattern replace-pattern
                                  #:key (case-insensitive? #f) (whole-word? #f) (preserve-case? #f))
  "Replace all occurrences of search pattern with replace pattern with options.
   Has undo support through underlying operations
   #:case-insensitive? - ignore case when matching
   #:whole-word? - only match complete words  
   #:preserve-case? - preserve original case pattern in replacements"
  ;; Save single undo state for the entire replace-all operation
  (cbuf-save-undo! cbuf 'replace-all search-pattern replace-pattern)
  
  (let ([count 0])
    (cbuf-beginning-of-buffer! cbuf)
    (while (cbuf-search-forward! cbuf search-pattern 
                                #:case-insensitive? case-insensitive?
                                #:whole-word? whole-word?)
      (when (cbuf-search-replace! cbuf search-pattern replace-pattern
                                 #:case-insensitive? case-insensitive?
                                 #:whole-word? whole-word?
                                 #:preserve-case? preserve-case?)
        (set! count (+ count 1))))
    (set! *replace-history* (cons (cons search-pattern replace-pattern) *replace-history*))
    count))

;;; =================================================================
;;; CODE-SPECIFIC OPERATIONS (Most need undo support)
;;; =================================================================

(define (cbuf-set-comment-string! comment-str)
  "Set the comment string for code commenting"
  (set! *comment-string* comment-str))

(define (cbuf-get-comment-string)
  "Get the current comment string"
  *comment-string*)

(define (cbuf-comment-line! cbuf)
  "Comment out the current line with undo support"
  ;; Save undo state
  (cbuf-save-undo! cbuf 'comment-line)
  
  (cbuf-beginning-of-line! cbuf)
  (cbuf-insert-string! cbuf (string-append *comment-string* " ")))

(define (cbuf-comment-region! cbuf)
  "Comment out the selected region line by line with undo support"
  (when (cbuf-mark-set? cbuf)
    (let* ([start-line (min (cbuf-mark-line cbuf) (cbuf-line-cur cbuf))]
           [end-line (max (cbuf-mark-line cbuf) (cbuf-line-cur cbuf))])
      
      ;; Save undo state for the entire region
      (cbuf-save-undo! cbuf 'comment-region start-line end-line)
      
      (let loop ([line start-line])
        (when (<= line end-line)
          (cbuf-set-y! cbuf line)
          (cbuf-beginning-of-line! cbuf)
          (cbuf-insert-string! cbuf (string-append *comment-string* " "))
          (loop (+ line 1)))))))

(define (cbuf-uncomment-region! cbuf)
  "Uncomment the selected region line by line with undo support"
  (when (cbuf-mark-set? cbuf)
    (let* ([start-line (min (cbuf-mark-line cbuf) (cbuf-line-cur cbuf))]
           [end-line (max (cbuf-mark-line cbuf) (cbuf-line-cur cbuf))]
           [comment-len (string-length *comment-string*)])
      
      ;; Save undo state for the entire region
      (cbuf-save-undo! cbuf 'uncomment-region start-line end-line)
      
      (let loop ([line start-line])
        (when (<= line end-line)
          (cbuf-set-y! cbuf line)
          (let ([text (cbuf-text-cur cbuf)])
            (when (string-prefix? *comment-string* text)
              (cbuf-beginning-of-line! cbuf)
              (cbuf-delete-region! cbuf line 0 line
                                   (if (and (> (string-length text) comment-len)
                                           (char=? (string-ref text comment-len) #\space))
                                       (+ comment-len 1)
                                       comment-len))))
          (loop (+ line 1)))))))

(define (cbuf-duplicate-line! cbuf)
  "Duplicate the current line with undo support"
  ;; Save undo state
  (cbuf-save-undo! cbuf 'duplicate-line)
  
  (let ([text (cbuf-text-cur cbuf)])
    (cbuf-end-of-line! cbuf)
    (cbuf-insert-newline! cbuf)
    (cbuf-insert-string! cbuf text)))

(define (cbuf-move-line-up! cbuf)
  "Move current line up one position with undo support"
  (when (> (cbuf-line-cur cbuf) 0)
    (let* ([current-line (cbuf-line-cur cbuf)]
           [current-x (cbuf-x-data cbuf)])
      
      ;; Save undo state
      (cbuf-save-undo! cbuf 'move-line 'up)
      
      (let ([current-text (cbuf-text-cur cbuf)]
            [prev-text (cbuf-get-line-text cbuf (- current-line 1))])
        
        ;; Delete current line
        (cbuf-delete-line! cbuf)
        
        ;; Move to previous line and delete it
        (cbuf-set-y! cbuf (- current-line 1))
        (cbuf-delete-line! cbuf)
        
        ;; Insert current line, then previous line
        (cbuf-insert-string! cbuf current-text)
        (cbuf-insert-newline! cbuf)
        (cbuf-insert-string! cbuf prev-text)
        
        ;; Restore position
        (cbuf-set-y! cbuf (- current-line 1))
        (cbuf-set-x! cbuf current-x 'data)))))

(define (cbuf-move-line-down! cbuf)
  "Move current line down one position with undo support"
  (when (< (cbuf-line-cur cbuf) (- (cbuf-line-count cbuf) 1))
    (let* ([current-line (cbuf-line-cur cbuf)]
           [current-x (cbuf-x-data cbuf)])
      
      ;; Save undo state
      (cbuf-save-undo! cbuf 'move-line 'down)
      
      (let ([current-text (cbuf-text-cur cbuf)]
            [next-text (cbuf-get-line-text cbuf (+ current-line 1))])
        
        ;; Delete next line
        (cbuf-set-y! cbuf (+ current-line 1))
        (cbuf-delete-line! cbuf)
        
        ;; Move to current line and delete it
        (cbuf-set-y! cbuf current-line)
        (cbuf-delete-line! cbuf)
        
        ;; Insert next line, then current line
        (cbuf-insert-string! cbuf next-text)
        (cbuf-insert-newline! cbuf)
        (cbuf-insert-string! cbuf current-text)
        
        ;; Restore position
        (cbuf-set-y! cbuf (+ current-line 1))
        (cbuf-set-x! cbuf current-x 'data)))))

;;; =================================================================
;;; INDENTATION (All need undo support)
;;; =================================================================

(define (cbuf-get-current-line-indentation cbuf)
  "Get the indentation level of the current line"
  (let ([text (cbuf-text-cur cbuf)])
    (let loop ([i 0] [indent 0])
      (cond
       [(>= i (string-length text)) indent]
       [(char=? (string-ref text i) #\space)
        (loop (+ i 1) (+ indent 1))]
       [(char=? (string-ref text i) #\tab)
        (loop (+ i 1) (+ indent (cbuf-tab-size cbuf)))]
       [else indent]))))

(define (cbuf-get-indentation-level cbuf)
  "Get the indentation level in tab units"
  (quotient (cbuf-get-current-line-indentation cbuf) (cbuf-tab-size cbuf)))

(define (cbuf-indent-line! cbuf)
  "Indent current line by one level with undo support"
  ;; Save undo state
  (cbuf-save-undo! cbuf 'indent-line)
  
  (let* ([tab-size (cbuf-tab-size cbuf)]
         [indent-str (make-string tab-size #\space)])
    (cbuf-beginning-of-line! cbuf)
    (cbuf-insert-string! cbuf indent-str)))

(define (cbuf-indent-region! cbuf)
  "Indent all lines in selected region with undo support"
  (when (cbuf-mark-set? cbuf)
    (let* ([start-line (min (cbuf-mark-line cbuf) (cbuf-line-cur cbuf))]
           [end-line (max (cbuf-mark-line cbuf) (cbuf-line-cur cbuf))])
      
      ;; Save undo state for the entire region
      (cbuf-save-undo! cbuf 'indent-region start-line end-line)
      
      (let loop ([line start-line])
        (when (<= line end-line)
          (cbuf-set-y! cbuf line)
          (cbuf-indent-line! cbuf)
          (loop (+ line 1)))))))

(define (cbuf-outdent-line! cbuf)
  "Outdent current line by one level with undo support"
  (let* ([tab-size (cbuf-tab-size cbuf)]
         [text (cbuf-text-cur cbuf)]
         [current-indent (cbuf-get-current-line-indentation cbuf)])
    
    (when (> current-indent 0)
      ;; Save undo state
      (cbuf-save-undo! cbuf 'outdent-line)
      
      (let ([remove-count (min tab-size current-indent)])
        (cbuf-beginning-of-line! cbuf)
        (cbuf-delete-region! cbuf (cbuf-line-cur cbuf) 0 
                             (cbuf-line-cur cbuf) remove-count)))))

(define (cbuf-outdent-region! cbuf)
  "Outdent all lines in selected region with undo support"
  (when (cbuf-mark-set? cbuf)
    (let* ([start-line (min (cbuf-mark-line cbuf) (cbuf-line-cur cbuf))]
           [end-line (max (cbuf-mark-line cbuf) (cbuf-line-cur cbuf))])
      
      ;; Save undo state for the entire region
      (cbuf-save-undo! cbuf 'outdent-region start-line end-line)
      
      (let loop ([line start-line])
        (when (<= line end-line)
          (cbuf-set-y! cbuf line)
          (cbuf-outdent-line! cbuf)
          (loop (+ line 1)))))))

(define (cbuf-newline-and-indent! cbuf)
  "Insert newline and indent to match previous line with undo support"
  ;; Save undo state
  (cbuf-save-undo! cbuf 'newline-and-indent)
  
  (let ([indent-level (cbuf-get-indentation-level cbuf)])
    (cbuf-insert-newline! cbuf)
    (cbuf-insert-string! cbuf (cbuf-get-indentation-string cbuf indent-level))))

;;; =================================================================
;;; TEXT TRANSFORMATION (All need undo support)
;;; =================================================================

(define (cbuf-upcase-region! cbuf)
  "Convert selected region to uppercase with undo support"
  (when (cbuf-mark-set? cbuf)
    ;; Save undo state
    (cbuf-save-undo! cbuf 'upcase-region)
    
    (let ([text (cbuf-get-region-text cbuf)])
      (cbuf-cut-region! cbuf)
      (cbuf-insert-string! cbuf (string-upcase text)))))

(define (cbuf-downcase-region! cbuf)
  "Convert selected region to lowercase with undo support"
  (when (cbuf-mark-set? cbuf)
    ;; Save undo state
    (cbuf-save-undo! cbuf 'downcase-region)
    
    (let ([text (cbuf-get-region-text cbuf)])
      (cbuf-cut-region! cbuf)
      (cbuf-insert-string! cbuf (string-downcase text)))))

(define (cbuf-capitalize-region! cbuf)
  "Capitalize selected region with undo support"
  (when (cbuf-mark-set? cbuf)
    ;; Save undo state
    (cbuf-save-undo! cbuf 'capitalize-region)
    
    (let ([text (cbuf-get-region-text cbuf)])
      (cbuf-cut-region! cbuf)
      (cbuf-insert-string! cbuf (string-capitalize text)))))

(define (cbuf-delete-trailing-whitespace! cbuf)
  "Delete trailing whitespace from all lines with undo support"
  ;; Save undo state for the entire buffer
  (cbuf-save-undo! cbuf 'delete-trailing-whitespace)
  
  (let ([original-line (cbuf-line-cur cbuf)]
        [original-x (cbuf-x-data cbuf)])
    
    (let loop ([line 0])
      (when (< line (cbuf-line-count cbuf))
        (cbuf-set-y! cbuf line)
        (let* ([text (cbuf-text-cur cbuf)]
               [trimmed (string-trim-right text)])
          (unless (string=? text trimmed)
            (let ([trim-start (string-length trimmed)])
              (cbuf-delete-region! cbuf line trim-start line (string-length text)))))
        (loop (+ line 1))))
    
    ;; Restore original position
    (cbuf-set-y! cbuf original-line)
    (cbuf-set-x! cbuf original-x 'data)))

(define (cbuf-trim-whitespace! cbuf)
  "Trim leading and trailing whitespace from selected region with undo support"
  (when (cbuf-mark-set? cbuf)
    ;; Save undo state
    (cbuf-save-undo! cbuf 'trim-whitespace)
    
    (let ([text (cbuf-get-region-text cbuf)])
      (cbuf-cut-region! cbuf)
      (cbuf-insert-string! cbuf (string-trim text)))))

;;; =================================================================
;;; UNDO/REDO
;;; =================================================================

(define (cbuf-redo! cbuf)
  "Redo the last undone operation (placeholder - requires redo stack)"
  ;; This would require implementing a separate redo stack
  ;; For now, just a placeholder
  (error "Redo not yet implemented - requires separate redo stack"))

;;; =================================================================
;;; UNDO REGISTRATION
;;; =================================================================

(define (cbuf-register-standard-undo-operations!)
  "Register all standard undo operations with the plugin system"
  
  ;; Word deletion operations
  (cbuf-register-undo-operation! 'delete-word
                                  capture-word-deletion-state
                                  restore-word-deletion-state)
  
  ;; Line deletion operations
  (cbuf-register-undo-operation! 'delete-to-eol
                                  capture-line-modification-state
                                  restore-line-modification-state)
  
  (cbuf-register-undo-operation! 'delete-to-bol
                                  capture-line-modification-state
                                  restore-line-modification-state)
  
  ;; Code operations
  (cbuf-register-undo-operation! 'comment-line
                                  capture-line-modification-state
                                  restore-line-modification-state)
  
  (cbuf-register-undo-operation! 'comment-region
                                  capture-multiline-operation-state
                                  restore-multiline-operation-state)
  
  (cbuf-register-undo-operation! 'uncomment-region
                                  capture-multiline-operation-state
                                  restore-multiline-operation-state)
  
  (cbuf-register-undo-operation! 'duplicate-line
                                  capture-line-modification-state
                                  restore-line-modification-state)
  
  ;; Line movement operations
  (cbuf-register-undo-operation! 'move-line
                                  capture-line-movement-state
                                  restore-line-movement-state)
  
  ;; Indentation operations
  (cbuf-register-undo-operation! 'indent-line
                                  capture-line-modification-state
                                  restore-line-modification-state)
  
  (cbuf-register-undo-operation! 'indent-region
                                  capture-multiline-operation-state
                                  restore-multiline-operation-state)
  
  (cbuf-register-undo-operation! 'outdent-line
                                  capture-line-modification-state
                                  restore-line-modification-state)
  
  (cbuf-register-undo-operation! 'outdent-region
                                  capture-multiline-operation-state
                                  restore-multiline-operation-state)
  
  (cbuf-register-undo-operation! 'newline-and-indent
                                  capture-line-modification-state
                                  restore-line-modification-state)
  
  ;; Text transformation operations
  (cbuf-register-undo-operation! 'upcase-region
                                  capture-global-modification-state
                                  restore-global-modification-state)
  
  (cbuf-register-undo-operation! 'downcase-region
                                  capture-global-modification-state
                                  restore-global-modification-state)
  
  (cbuf-register-undo-operation! 'capitalize-region
                                  capture-global-modification-state
                                  restore-global-modification-state)
  
  (cbuf-register-undo-operation! 'delete-trailing-whitespace
                                  capture-global-modification-state
                                  restore-global-modification-state)
  
  (cbuf-register-undo-operation! 'trim-whitespace
                                  capture-global-modification-state
                                  restore-global-modification-state)
  
  ;; Replace operations
  (cbuf-register-undo-operation! 'replace-all
                                  capture-global-modification-state
                                  restore-global-modification-state))

;;; =================================================================
;;; MODULE INITIALIZATION
;;; =================================================================

;; Register standard operations when module loads
(cbuf-register-standard-undo-operations!)
