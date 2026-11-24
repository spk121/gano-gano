;;; Gano Character Buffer Module - Standard Operations with Undo Support
;;; Complete ECMA-48 terminal control implementation
;;;
;;; This file contains standard text editing operations beyond the basic MVP.
;;;
;;; Undo: a command that is a single basic operation (delete-region,
;;; insert-string, ...) lets that operation record its own undo step.  A
;;; command made of several operations runs them with #:undo? #f and
;;; records one 'line-range step: the lines it is about to change, which
;;; undo puts back and redo replaces with the lines it produced.  Every
;;; modifying command takes #:undo? too, for use by larger commands.

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
  #:re-export (cbuf-redo!)              ; implemented in cbuf-basic
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

    ;; Line utilities
    cbuf-get-current-line-indentation
    cbuf-get-indentation-level
    cbuf-set-comment-string!
    cbuf-get-comment-string

    ;; Undo registration
    cbuf-register-standard-undo-operations!
    cbuf-save-line-range-undo!            ; for compound operations elsewhere
    ))

;;; =================================================================
;;; INTERNAL STATE FOR STANDARD OPERATIONS
;;; =================================================================

;; Comment string for code commenting (can be customized)
(define *comment-string* ";;")
(define *search-history* '())
(define *replace-history* '())

;;; =================================================================
;;; LINE-RANGE UNDO
;;; =================================================================
;;; A compound command calls (save-line-range-undo! cbuf start end) before
;;; changing lines START .. END (the edit may change the number of lines).

(define (line-slice cbuf start count)
  (take (drop (cbuf-text-metrics cbuf) start) count))

(define (capture-line-range cbuf start end)
  `((start ,start)
    (lines ,(line-slice cbuf start (+ 1 (- end start))))
    (count-before ,(cbuf-line-count cbuf))))

(define (post-edit-line-count cbuf state)
  "How many lines the edit turned the captured lines into"
  (+ (length (cadr (assq 'lines state)))
     (- (cbuf-line-count cbuf) (cadr (assq 'count-before state)))))

(define (restore-line-range cbuf state . args)
  (let ([start (cadr (assq 'start state))]
        [lines (cadr (assq 'lines state))]
        [metrics (cbuf-text-metrics cbuf)])
    (set-cbuf-text-metrics! cbuf (append (take metrics start)
                                         lines
                                         (drop metrics (+ start (post-edit-line-count cbuf state)))))))

(define (redo-line-range cbuf state . args)
  (let ([start (cadr (assq 'start state))])
    (list (list start
                (length (cadr (assq 'lines state)))
                (line-slice cbuf start (post-edit-line-count cbuf state))))))

(define* (cbuf-save-line-range-undo! cbuf start end #:optional (undo? #t))
  "Record one undo step for an edit about to change lines START .. END
   (it may change how many lines there are).  Does nothing if UNDO? is #f."
  (when undo?
    (cbuf-save-undo! cbuf 'line-range start end)))

(define save-line-range-undo! cbuf-save-line-range-undo!)

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

(define (line-data-position cbuf line index)
  "Data position of string INDEX on LINE"
  (text-metrics-x-index->x-data (list-ref (cbuf-text-metrics cbuf) line) index))

(define (cbuf-find-word-bounds cbuf)
  "Find the bounds of the word at current position.
   Returns (start-line start-x-data end-line end-x-data)"
  (let* ([current-line (cbuf-line-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [text (cbuf-text-cur cbuf)])
    (if (string-null? text)
        (list current-line 0 current-line 0)
        (let* ([current-index (cbuf-x-data->x-index cbuf current-x)]
               [start-index (skip-word-chars-backward text current-index char-word-delimiter?)]
               [end-index (skip-word-chars-forward text current-index char-word-delimiter?)])
          (list current-line (cbuf-x-index->x-data cbuf start-index)
                current-line (cbuf-x-index->x-data cbuf end-index))))))

(define (region-bounds cbuf)
  "The selection as (start-line start-x end-line end-x), start first"
  (let ([ml (cbuf-mark-line cbuf)] [mx (cbuf-mark-x-data cbuf)]
        [cl (cbuf-line-cur cbuf)] [cx (cbuf-x-data cbuf)])
    (if (or (< ml cl) (and (= ml cl) (<= mx cx)))
        (list ml mx cl cx)
        (list cl cx ml mx))))

(define (replace-region! cbuf transform undo?)
  "Replace the selected text with (TRANSFORM text) as one undo step,
   leaving the cut buffer alone.  The cursor ends after the new text."
  (when (cbuf-mark-set? cbuf)
    (let* ([bounds (region-bounds cbuf)]
           [text (cbuf-get-region-text cbuf)])
      (save-line-range-undo! cbuf (first bounds) (third bounds) undo?)
      (apply cbuf-delete-region! cbuf (append bounds '(#:undo? #f)))
      (cbuf-clear-mark! cbuf)
      (cbuf-insert-string! cbuf (transform text) #:undo? #f))))

(define (leading-whitespace text)
  (let ([end (or (string-index text (lambda (c) (not (memv c '(#\space #\tab))))) 
                 (string-length text))])
    (substring text 0 end)))

;;; =================================================================
;;; NAVIGATION (No undo needed - these don't modify buffer content)
;;; =================================================================

(define (cbuf-goto-line! cbuf line)
  "Move cursor to the home position of LINE (0-based, clamped)"
  (cbuf-set-y! cbuf line)
  (cbuf-set-positions! cbuf (cbuf-home-pos cbuf) (cbuf-limit-type cbuf)))

(define (cbuf-goto-home! cbuf)
  "Move cursor to home position of current line"
  (cbuf-set-positions! cbuf (cbuf-home-pos cbuf) (cbuf-limit-type cbuf)))
  
(define (cbuf-goto-limit! cbuf)
  "Move cursor to limit position of current line"
  (cbuf-set-positions! cbuf (cbuf-limit-pos cbuf) (cbuf-limit-type cbuf)))

(define (cbuf-page-up! cbuf)
  "Move cursor up one page (form size) of lines"
  (cbuf-set-y! cbuf (max 0 (- (cbuf-line-cur cbuf) (cbuf-form-size cbuf)))))

(define (cbuf-page-down! cbuf)
  "Move cursor down one page (form size) of lines"
  (cbuf-set-y! cbuf (min (- (cbuf-line-count cbuf) 1)
                         (+ (cbuf-line-cur cbuf) (cbuf-form-size cbuf)))))

(define (cbuf-forward-word! cbuf)
  "Move cursor forward to the beginning of the next word; from the last
   word of a line, to the start of the next line."
  (let* ([text (cbuf-text-cur cbuf)]
         [current-index (cbuf-x-data->x-index cbuf (cbuf-x-data cbuf))]
         [end-index (find-word-end-forward text current-index char-word-delimiter?)]
         [next-word-index (skip-delimiters-forward text end-index)])
    (if (< next-word-index (string-length text))
        (cbuf-set-x! cbuf (cbuf-x-index->x-data cbuf next-word-index) 'data)
        (if (< (cbuf-line-cur cbuf) (- (cbuf-line-count cbuf) 1))
            (begin (cbuf-next-line! cbuf)
                   (cbuf-beginning-of-line! cbuf))
            (cbuf-end-of-line! cbuf)))))

(define (cbuf-backward-word! cbuf)
  "Move cursor back to the beginning of the current or previous word;
   from the start of a line, to the end of the previous line."
  (let* ([text (cbuf-text-cur cbuf)]
         [current-index (cbuf-x-data->x-index cbuf (cbuf-x-data cbuf))])
    (if (> current-index 0)
        (cbuf-set-x! cbuf (cbuf-x-index->x-data
                           cbuf (find-word-begin-backward text current-index char-word-delimiter?))
                     'data)
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
    (cbuf-set-y! cbuf (first bounds))
    (cbuf-set-x! cbuf (second bounds) 'data)
    (cbuf-set-mark! cbuf)
    (cbuf-set-y! cbuf (third bounds))
    (cbuf-set-x! cbuf (fourth bounds) 'data)))

(define (cbuf-select-line! cbuf)
  "Select the text of the current line (not its line ending)"
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
;;; CUT/COPY/PASTE
;;; =================================================================

(define* (cbuf-paste-previous! cbuf #:key (undo? #t))
  "Rotate the cut buffer to the previous entry and paste it"
  (let ([cut-buffer (cbuf-cut-buffer cbuf)])
    (when (and cut-buffer (> (length cut-buffer) 1))
      (set-cbuf-cut-buffer! cbuf (append (cdr cut-buffer) (list (car cut-buffer))))
      (cbuf-paste! cbuf #:undo? undo?))))

(define (cbuf-select-line-including-newline! cbuf)
  "Select the current line and its line ending (on the last line, which
   has none in the buffer, just its text)."
  (let ([current-line (cbuf-line-cur cbuf)])
    (cbuf-beginning-of-line! cbuf)
    (cbuf-set-mark! cbuf)
    (if (< current-line (- (cbuf-line-count cbuf) 1))
        (begin (cbuf-next-line! cbuf)
               (cbuf-beginning-of-line! cbuf))
        (cbuf-end-of-buffer! cbuf))))

(define* (cbuf-cut-line! cbuf #:key (undo? #t))
  "Cut the current line, including its line ending.  Undo puts the
   cursor back where it was."
  (let ([line (cbuf-line-cur cbuf)])
    (save-line-range-undo! cbuf line (min (+ line 1) (- (cbuf-line-count cbuf) 1)) undo?)
    (cbuf-select-line-including-newline! cbuf)
    (cbuf-cut-region! cbuf #:undo? #f)))

(define (cbuf-copy-line! cbuf)
  "Copy the current line, including its line ending"
  (cbuf-select-line-including-newline! cbuf)
  (cbuf-copy-region! cbuf))

(define* (cbuf-cut-word! cbuf #:key (undo? #t))
  "Cut the word at current position.  Undo puts the cursor back."
  (let ([line (cbuf-line-cur cbuf)])
    (save-line-range-undo! cbuf line line undo?)
    (cbuf-select-word! cbuf)
    (cbuf-cut-region! cbuf #:undo? #f)))

(define (cbuf-copy-word! cbuf)
  "Copy the word at current position"
  (cbuf-select-word! cbuf)
  (cbuf-copy-region! cbuf))

;;; =================================================================
;;; DELETION
;;; =================================================================

(define* (cbuf-delete-word-forward! cbuf #:key (undo? #t))
  "Delete from cursor to end of current (or next) word"
  (let* ([text (cbuf-text-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [current-index (cbuf-x-data->x-index cbuf current-x)]
         [end-index (find-word-end-forward text current-index char-word-delimiter?)])
    (when (> end-index current-index)
      (cbuf-delete-region! cbuf (cbuf-line-cur cbuf) current-x
                           (cbuf-line-cur cbuf) (cbuf-x-index->x-data cbuf end-index)
                           #:undo? undo?))))

(define* (cbuf-delete-word-backward! cbuf #:key (undo? #t))
  "Delete from the start of the current (or previous) word to the cursor"
  (let* ([text (cbuf-text-cur cbuf)]
         [current-x (cbuf-x-data cbuf)]
         [current-index (cbuf-x-data->x-index cbuf current-x)]
         [start-index (find-word-begin-backward text current-index char-word-delimiter?)])
    (when (< start-index current-index)
      (cbuf-delete-region! cbuf (cbuf-line-cur cbuf) (cbuf-x-index->x-data cbuf start-index)
                           (cbuf-line-cur cbuf) current-x
                           #:undo? undo?))))

(define* (cbuf-delete-to-end-of-line! cbuf #:key (undo? #t))
  "Delete from cursor to end of line"
  (let ([current-x (cbuf-x-data cbuf)]
        [line-length (cbuf-text-cur-base-length cbuf)])
    (when (< current-x line-length)
      (cbuf-delete-region! cbuf (cbuf-line-cur cbuf) current-x 
                           (cbuf-line-cur cbuf) line-length
                           #:undo? undo?))))

(define* (cbuf-delete-to-beginning-of-line! cbuf #:key (undo? #t))
  "Delete from beginning of line to cursor"
  (let ([current-x (cbuf-x-data cbuf)])
    (when (> current-x 0)
      (cbuf-delete-region! cbuf (cbuf-line-cur cbuf) 0 
                           (cbuf-line-cur cbuf) current-x
                           #:undo? undo?))))

;;; =================================================================
;;; SEARCH AND REPLACE
;;; =================================================================
;;; Searches look within single lines and do not wrap around.  A match is
;;; selected: forward searches leave the cursor after it (mark at its
;;; start), backward searches leave the cursor at its start (mark after
;;; it), so repeating the search moves on to the next match.

(define (select-match! cbuf line start-index end-index cursor-at-end?)
  (cbuf-set-y! cbuf line)
  (cbuf-set-x! cbuf (cbuf-x-index->x-data cbuf (if cursor-at-end? start-index end-index)) 'data)
  (cbuf-set-mark! cbuf)
  (cbuf-set-x! cbuf (cbuf-x-index->x-data cbuf (if cursor-at-end? end-index start-index)) 'data))

(define* (cbuf-search-forward! cbuf pattern #:key (case-insensitive? #f) (whole-word? #f))
  "Find PATTERN at or after the cursor and select it.  Returns #t if
   found, #f (cursor unchanged) if not.  Matches never split a grapheme
   cluster."
  (set! *search-history* (cons pattern *search-history*))
  (let ([line0 (cbuf-line-cur cbuf)]
        [index0 (cbuf-x-data->x-index cbuf (cbuf-x-data cbuf))])
    (let loop ([line line0])
      (and (< line (cbuf-line-count cbuf))
           (let* ([text (cbuf-get-line-text cbuf line)]
                  [m (find-pattern-in-text-detailed text pattern (if (= line line0) index0 0)
                                                    #:case-insensitive? case-insensitive?
                                                    #:whole-word? whole-word?)])
             (if m
                 (begin (select-match! cbuf line (pattern-match-start m) (pattern-match-end m) #t)
                        #t)
                 (loop (+ line 1))))))))

(define* (cbuf-search-backward! cbuf pattern #:key (case-insensitive? #f) (whole-word? #f))
  "Find the last match of PATTERN starting before the cursor and select
   it, with the cursor at its start.  Returns #t if found, #f if not."
  (set! *search-history* (cons pattern *search-history*))
  (let ([line0 (cbuf-line-cur cbuf)]
        [index0 (cbuf-x-data->x-index cbuf (cbuf-x-data cbuf))])
    (let loop ([line line0])
      (and (>= line 0)
           (let* ([text (cbuf-get-line-text cbuf line)]
                  [limit (if (= line line0) index0 (+ 1 (string-length text)))]
                  [candidates (filter (lambda (m) (< (pattern-match-start m) limit))
                                      (find-all-pattern-matches
                                       text pattern
                                       #:case-insensitive? case-insensitive?
                                       #:whole-word? whole-word?))])
             (if (null? candidates)
                 (loop (- line 1))
                 (let ([m (last candidates)])
                   (select-match! cbuf line (pattern-match-start m) (pattern-match-end m) #f)
                   #t)))))))

(define (preserve-case original replacement)
  "Give REPLACEMENT the case pattern of ORIGINAL: letter by letter when
   they are the same length, otherwise all-caps or capitalised if
   ORIGINAL is; else REPLACEMENT unchanged."
  (let ([letters (filter char-alphabetic? (string->list original))])
    (cond
     [(= (string-length original) (string-length replacement))
      (list->string
       (map (lambda (o r)
              (cond [(char-upper-case? o) (char-upcase r)]
                    [(char-lower-case? o) (char-downcase r)]
                    [else r]))
            (string->list original) (string->list replacement)))]
     [(and (pair? letters) (every char-upper-case? letters) (> (length letters) 1))
      (string-upcase replacement)]
     [(and (pair? letters) (char-upper-case? (car letters))
           (every char-lower-case? (cdr letters)))
      (string-append (string-upcase (substring replacement 0 (min 1 (string-length replacement))))
                     (substring replacement (min 1 (string-length replacement))))]
     [else replacement])))

(define* (cbuf-search-replace! cbuf search-pattern replace-pattern 
                               #:key (case-insensitive? #f) (whole-word? #f)
                               (preserve-case? #f) (undo? #t))
  "If the selection is SEARCH-PATTERN (as left by a search), replace it
   with REPLACE-PATTERN and return #t; otherwise return #f.  The cursor
   ends after the replacement."
  (and (cbuf-mark-set? cbuf)
       (let ([selected-text (cbuf-get-region-text cbuf)])
         (and (if case-insensitive?
                  (string-ci=? selected-text search-pattern)
                  (string=? selected-text search-pattern))
              (begin
                (replace-region! cbuf
                                 (lambda (old) (if preserve-case?
                                                   (preserve-case old replace-pattern)
                                                   replace-pattern))
                                 undo?)
                (set! *replace-history* (cons (cons search-pattern replace-pattern)
                                              *replace-history*))
                #t)))))

(define* (cbuf-search-replace-all! cbuf search-pattern replace-pattern
                                   #:key (case-insensitive? #f) (whole-word? #f)
                                   (preserve-case? #f) (undo? #t))
  "Replace every match of SEARCH-PATTERN in the buffer as one undo step.
   Returns the number of replacements; the cursor ends after the last."
  (let* ([lines-with-matches
          (filter (lambda (line)
                    (find-pattern-in-text (cbuf-get-line-text cbuf line) search-pattern 0
                                          #:case-insensitive? case-insensitive?
                                          #:whole-word? whole-word?))
                  (iota (cbuf-line-count cbuf)))])
    (if (null? lines-with-matches)
        0
        (begin
          (save-line-range-undo! cbuf (first lines-with-matches) (last lines-with-matches) undo?)
          (cbuf-set-y! cbuf (first lines-with-matches))
          (cbuf-beginning-of-line! cbuf)
          (let loop ([count 0])
            (if (cbuf-search-forward! cbuf search-pattern
                                      #:case-insensitive? case-insensitive?
                                      #:whole-word? whole-word?)
                (begin
                  (cbuf-search-replace! cbuf search-pattern replace-pattern
                                        #:case-insensitive? case-insensitive?
                                        #:preserve-case? preserve-case?
                                        #:undo? #f)
                  (loop (+ count 1)))
                (begin
                  (cbuf-clear-mark! cbuf)
                  (set! *replace-history* (cons (cons search-pattern replace-pattern)
                                                *replace-history*))
                  count)))))))

;;; =================================================================
;;; CODE-SPECIFIC OPERATIONS
;;; =================================================================

(define (cbuf-set-comment-string! comment-str)
  "Set the comment string for code commenting"
  (unless (and (string? comment-str) (not (string-null? comment-str)))
    (error "comment string must be a non-empty string" comment-str))
  (set! *comment-string* comment-str))

(define (cbuf-get-comment-string)
  "Get the current comment string"
  *comment-string*)

(define (comment-prefix) (string-append *comment-string* " "))

(define* (cbuf-comment-line! cbuf #:key (undo? #t))
  "Insert the comment string and a space at the start of the line"
  (cbuf-beginning-of-line! cbuf)
  (cbuf-insert-string! cbuf (comment-prefix) #:undo? undo?))

(define (region-lines cbuf)
  (cons (min (cbuf-mark-line cbuf) (cbuf-line-cur cbuf))
        (max (cbuf-mark-line cbuf) (cbuf-line-cur cbuf))))

(define (for-each-region-line! cbuf undo? proc)
  "Run PROC on each line of the selection, as one undo step"
  (when (cbuf-mark-set? cbuf)
    (let ([start-line (car (region-lines cbuf))]
          [end-line (cdr (region-lines cbuf))])
      (save-line-range-undo! cbuf start-line end-line undo?)
      (let loop ([line start-line])
        (when (<= line end-line)
          (cbuf-set-y! cbuf line)
          (proc line)
          (loop (+ line 1)))))))

(define* (cbuf-comment-region! cbuf #:key (undo? #t))
  "Comment out each line of the selection"
  (for-each-region-line! cbuf undo?
    (lambda (line) (cbuf-comment-line! cbuf #:undo? #f))))

(define* (cbuf-uncomment-region! cbuf #:key (undo? #t))
  "Remove a leading comment string (and one following space) from each
   line of the selection"
  (let ([comment-len (string-length *comment-string*)])
    (for-each-region-line! cbuf undo?
      (lambda (line)
        (let ([text (cbuf-text-cur cbuf)])
          (when (string-prefix? *comment-string* text)
            (cbuf-delete-region! cbuf line 0 line
                                 (if (and (> (string-length text) comment-len)
                                          (char=? (string-ref text comment-len) #\space))
                                     (+ comment-len 1)
                                     comment-len)
                                 #:undo? #f)))))))

(define* (cbuf-duplicate-line! cbuf #:key (undo? #t))
  "Insert a copy of the current line below it; the cursor ends at the
   end of the copy"
  (let ([line (cbuf-line-cur cbuf)]
        [text (cbuf-text-cur cbuf)])
    (save-line-range-undo! cbuf line line undo?)
    (cbuf-end-of-line! cbuf)
    (cbuf-insert-newline! cbuf #:undo? #f)
    (cbuf-insert-string! cbuf text #:undo? #f)))

(define (swap-lines! cbuf a)
  "Swap lines A and A+1"
  (let* ([metrics (cbuf-text-metrics cbuf)]
         [la (list-ref metrics a)]
         [lb (list-ref metrics (+ a 1))])
    (set-cbuf-text-metrics! cbuf (append (take metrics a) (list lb la) (drop metrics (+ a 2))))
    (set-cbuf-modified?! cbuf #t)))

(define* (cbuf-move-line-up! cbuf #:key (undo? #t))
  "Swap the current line with the one above; the cursor moves with it"
  (let ([line (cbuf-line-cur cbuf)]
        [x (cbuf-x-data cbuf)])
    (when (> line 0)
      (save-line-range-undo! cbuf (- line 1) line undo?)
      (swap-lines! cbuf (- line 1))
      (cbuf-set-y! cbuf (- line 1))
      (cbuf-set-x! cbuf x 'data))))

(define* (cbuf-move-line-down! cbuf #:key (undo? #t))
  "Swap the current line with the one below; the cursor moves with it"
  (let ([line (cbuf-line-cur cbuf)]
        [x (cbuf-x-data cbuf)])
    (when (< line (- (cbuf-line-count cbuf) 1))
      (save-line-range-undo! cbuf line (+ line 1) undo?)
      (swap-lines! cbuf line)
      (cbuf-set-y! cbuf (+ line 1))
      (cbuf-set-x! cbuf x 'data))))

;;; =================================================================
;;; INDENTATION
;;; =================================================================

(define (cbuf-get-current-line-indentation cbuf)
  "Width in columns of the current line's leading spaces and tabs (tabs
   run to the next tab stop)"
  (let ([tab-size (cbuf-tab-size cbuf)])
    (string-fold (lambda (c col)
                   (if (char=? c #\tab)
                       (* tab-size (+ 1 (quotient col tab-size)))
                       (+ col 1)))
                 0
                 (leading-whitespace (cbuf-text-cur cbuf)))))

(define (cbuf-get-indentation-level cbuf)
  "Indentation in whole tab stops"
  (quotient (cbuf-get-current-line-indentation cbuf) (cbuf-tab-size cbuf)))

(define* (cbuf-indent-line! cbuf #:key (undo? #t))
  "Insert one tab size of spaces at the start of the line"
  (cbuf-beginning-of-line! cbuf)
  (cbuf-insert-string! cbuf (make-string (cbuf-tab-size cbuf) #\space) #:undo? undo?))

(define* (cbuf-indent-region! cbuf #:key (undo? #t))
  "Indent each line of the selection"
  (for-each-region-line! cbuf undo?
    (lambda (line) (cbuf-indent-line! cbuf #:undo? #f))))

(define* (cbuf-outdent-line! cbuf #:key (undo? #t))
  "Remove one level of indentation: a leading tab, or up to one tab size
   of leading spaces"
  (let* ([text (cbuf-text-cur cbuf)]
         [remove-count (cond
                        [(string-null? text) 0]
                        [(char=? (string-ref text 0) #\tab) 1]
                        [else (min (cbuf-tab-size cbuf)
                                   (or (string-index text (lambda (c) (not (char=? c #\space))))
                                       (string-length text)))])])
    (when (> remove-count 0)
      (cbuf-delete-region! cbuf (cbuf-line-cur cbuf) 0 (cbuf-line-cur cbuf) remove-count
                           #:undo? undo?))))

(define* (cbuf-outdent-region! cbuf #:key (undo? #t))
  "Outdent each line of the selection"
  (for-each-region-line! cbuf undo?
    (lambda (line) (cbuf-outdent-line! cbuf #:undo? #f))))

(define* (cbuf-newline-and-indent! cbuf #:key (undo? #t))
  "Split the line and start the new line with the same leading
   whitespace as the current one (only the part before the cursor)"
  (let* ([line (cbuf-line-cur cbuf)]
         [before-cursor (substring (cbuf-text-cur cbuf) 0
                                   (cbuf-x-data->x-index cbuf (cbuf-x-data cbuf)))]
         [indent (leading-whitespace before-cursor)])
    (save-line-range-undo! cbuf line line undo?)
    (cbuf-insert-newline! cbuf #:undo? #f)
    (cbuf-insert-string! cbuf indent #:undo? #f)))

;;; =================================================================
;;; TEXT TRANSFORMATION
;;; =================================================================

(define* (cbuf-upcase-region! cbuf #:key (undo? #t))
  "Convert the selection to upper case"
  (replace-region! cbuf string-upcase undo?))

(define* (cbuf-downcase-region! cbuf #:key (undo? #t))
  "Convert the selection to lower case"
  (replace-region! cbuf string-downcase undo?))

(define* (cbuf-capitalize-region! cbuf #:key (undo? #t))
  "Capitalize each word of the selection"
  (replace-region! cbuf string-titlecase undo?))

(define* (cbuf-trim-whitespace! cbuf #:key (undo? #t))
  "Remove leading and trailing whitespace from the selection"
  (replace-region! cbuf string-trim-both undo?))

(define* (cbuf-delete-trailing-whitespace! cbuf #:key (undo? #t))
  "Delete trailing whitespace from every line, as one undo step.  The
   cursor stays where it was (moved back if its line got shorter)."
  (let* ([changed (filter (lambda (line)
                            (let ([text (cbuf-get-line-text cbuf line)])
                              (not (string=? text (string-trim-right text)))))
                          (iota (cbuf-line-count cbuf)))]
         [original-line (cbuf-line-cur cbuf)]
         [original-x (cbuf-x-data cbuf)])
    (unless (null? changed)
      (save-line-range-undo! cbuf (first changed) (last changed) undo?)
      (for-each (lambda (line)
                  (let* ([text (cbuf-get-line-text cbuf line)]
                         [keep (string-length (string-trim-right text))])
                    (cbuf-delete-region! cbuf line (line-data-position cbuf line keep)
                                         line (line-data-position cbuf line (string-length text))
                                         #:undo? #f)))
                changed)
      (cbuf-set-y! cbuf original-line)
      (cbuf-set-x! cbuf original-x 'data))))

;;; =================================================================
;;; UNDO REGISTRATION
;;; =================================================================

(define (cbuf-register-standard-undo-operations!)
  "Register the undo handler used by the compound standard operations"
  (cbuf-register-undo-operation! 'line-range
                                 capture-line-range
                                 restore-line-range
                                 redo-line-range))

;;; =================================================================
;;; MODULE INITIALIZATION
;;; =================================================================

;; Register standard operations when module loads
(cbuf-register-standard-undo-operations!)
