;;; Minimum Viable Operations to add to cbuf-basic.scm
;;; These should be added to the #:export list and implementation

    ;; ====== ADD TO EXPORTS ======
    ;; Character operations  
    cbuf-insert-char!
    cbuf-delete-char!
    cbuf-backspace!
    
    ;; Line operations
    cbuf-insert-newline!
    cbuf-delete-line!
    cbuf-join-lines!
    
    ;; Navigation operations
    cbuf-forward-char!
    cbuf-backward-char!
    cbuf-next-line!
    cbuf-previous-line!
    cbuf-beginning-of-line!
    cbuf-end-of-line!
    cbuf-beginning-of-buffer!
    cbuf-end-of-buffer!
    
    ;; String operations
    cbuf-insert-string!
    cbuf-delete-region!
    
    ;; Mark/selection operations
    cbuf-set-mark!
    cbuf-exchange-point-and-mark!
    cbuf-get-region-text
    
    ;; Buffer operations
    cbuf-clear!
    cbuf-load-from-string!
    cbuf-save-to-string

;;; =================================================================
;;; CHARACTER OPERATIONS
;;; =================================================================

(define (cbuf-insert-char! cbuf char-new)
  "Insert a character at the current position"
  (let* ([x-data (cbuf-x-data cbuf)]
         [text (cbuf-text-cur cbuf)]
         [sgr-list (cbuf-sgr-list-cur cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)])
    
    ;; Validate combining mark insertion if applicable
    (when (char-combining-mark? char-new)
      (let ([validation (cbuf-validate-combining-mark-insertion cbuf char-new x-data)])
        (unless (car validation)
          (error "Invalid combining mark insertion" (cadr validation)))))
    
    ;; Save undo state before modification
    (let ([old-metrics (cbuf-metrics-cur cbuf)])
      (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 'insert-char char-new))
    
    ;; Insert character and SGR
    (let* ([new-text (string-insert-char text x-index char-new)]
           [current-sgr (cbuf-current-sgr cbuf)]
           [new-sgr-list (list-insert sgr-list x-index current-sgr)])
      
      ;; Update the line
      (cbuf-set-text-cur! cbuf new-text new-sgr-list)
      
      ;; Move cursor forward
      (cbuf-set-x! cbuf (+ x-data 1) 'data)
      
      ;; Mark as modified
      (set-cbuf-modified?! cbuf #t))))

(define (cbuf-delete-char! cbuf)
  "Delete character at current position (Delete key behavior)"
  (unless (cbuf-end-of-line? cbuf)
    (let* ([x-data (cbuf-x-data cbuf)]
           [text (cbuf-text-cur cbuf)]
           [sgr-list (cbuf-sgr-list-cur cbuf)]
           [x-index (cbuf-x-data->x-index cbuf x-data)])
      
      ;; Save undo state
      (let ([old-metrics (cbuf-metrics-cur cbuf)])
        (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 'delete-char))
      
      ;; Delete character and corresponding SGR
      (let* ([new-text (string-delete-range text x-index (+ x-index 1))]
             [new-sgr-list (list-delete-range sgr-list x-index (+ x-index 1))])
        
        ;; Update the line
        (cbuf-set-text-cur! cbuf new-text new-sgr-list)
        
        ;; Cursor stays at same position
        (cbuf-set-x! cbuf x-data 'data)
        
        ;; Mark as modified
        (set-cbuf-modified?! cbuf #t)))))

(define (cbuf-backspace! cbuf)
  "Delete character before current position (Backspace key behavior)"
  (unless (cbuf-beginning-of-line? cbuf)
    (let* ([x-data (cbuf-x-data cbuf)]
           [text (cbuf-text-cur cbuf)]
           [sgr-list (cbuf-sgr-list-cur cbuf)]
           [prev-x-index (cbuf-x-data->x-index cbuf (- x-data 1))])
      
      ;; Save undo state
      (let ([old-metrics (cbuf-metrics-cur cbuf)])
        (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 'backspace))
      
      ;; Delete previous character and corresponding SGR
      (let* ([new-text (string-delete-range text prev-x-index (+ prev-x-index 1))]
             [new-sgr-list (list-delete-range sgr-list prev-x-index (+ prev-x-index 1))])
        
        ;; Update the line
        (cbuf-set-text-cur! cbuf new-text new-sgr-list)
        
        ;; Move cursor back
        (cbuf-set-x! cbuf (- x-data 1) 'data)
        
        ;; Mark as modified
        (set-cbuf-modified?! cbuf #t)))))

;;; =================================================================
;;; LINE OPERATIONS
;;; =================================================================

(define (cbuf-insert-newline! cbuf)
  "Insert a newline at current position, splitting the line"
  (let* ([x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)]
         [current-line (cbuf-line-cur cbuf)]
         [text (cbuf-text-cur cbuf)]
         [sgr-list (cbuf-sgr-list-cur cbuf)])
    
    ;; Save undo state for line insertion
    (cbuf-save-line-insertion-undo! cbuf (+ current-line 1) 1 'insert-newline)
    
    ;; Split current line at cursor position
    (let* ([left-text (substring text 0 x-index)]
           [right-text (substring text x-index)]
           [left-sgr (take sgr-list x-index)]
           [right-sgr (drop sgr-list x-index)]
           [left-metrics (compute-text-metrics-with-sgr left-text left-sgr 
                                                        (cbuf-tab-size cbuf) 
                                                        #:cjk? (cbuf-cjk? cbuf))]
           [right-metrics (compute-text-metrics-with-sgr right-text right-sgr 
                                                         (cbuf-tab-size cbuf) 
                                                         #:cjk? (cbuf-cjk? cbuf))])
      
      ;; Update current line with left part
      (let* ([metrics-list (cbuf-text-metrics cbuf)]
             [new-metrics-list (list-update metrics-list current-line left-metrics)])
        (set-cbuf-text-metrics! cbuf new-metrics-list))
      
      ;; Insert new line with right part
      (let* ([metrics-list (cbuf-text-metrics cbuf)]
             [new-metrics-list (list-insert metrics-list (+ current-line 1) right-metrics)])
        (set-cbuf-text-metrics! cbuf new-metrics-list))
      
      ;; Move cursor to beginning of new line
      (cbuf-set-y! cbuf (+ current-line 1))
      (cbuf-set-x! cbuf 0 'data)
      
      ;; Mark as modified
      (set-cbuf-modified?! cbuf #t))))

(define (cbuf-delete-line! cbuf)
  "Delete the current line"
  (when (> (cbuf-line-count cbuf) 1)  ; Don't delete if it's the only line
    (let ([current-line (cbuf-line-cur cbuf)]
          [deleted-metrics (cbuf-metrics-cur cbuf)])
      
      ;; Save undo state
      (cbuf-save-line-deletion-undo! cbuf current-line (list deleted-metrics) 'delete-line)
      
      ;; Remove the line
      (let* ([metrics-list (cbuf-text-metrics cbuf)]
             [new-metrics-list (list-delete-range metrics-list current-line (+ current-line 1))])
        (set-cbuf-text-metrics! cbuf new-metrics-list))
      
      ;; Adjust cursor position if needed
      (when (>= current-line (cbuf-line-count cbuf))
        (cbuf-set-y! cbuf (- (cbuf-line-count cbuf) 1)))
      
      ;; Move to beginning of line
      (cbuf-set-x! cbuf 0 'data)
      
      ;; Mark as modified
      (set-cbuf-modified?! cbuf #t))))

(define (cbuf-join-lines! cbuf)
  "Join current line with next line"
  (let ([current-line (cbuf-line-cur cbuf)])
    (when (< current-line (- (cbuf-line-count cbuf) 1))  ; Not on last line
      (let* ([current-text (cbuf-text-cur cbuf)]
             [current-sgr (cbuf-sgr-list-cur cbuf)]
             [next-text (cbuf-get-line-text cbuf (+ current-line 1))]
             [next-sgr (text-metrics-sgr-list (list-ref (cbuf-text-metrics cbuf) (+ current-line 1)))]
             [joined-text (string-append current-text next-text)]
             [joined-sgr (append current-sgr next-sgr)])
        
        ;; Save undo state for both line modification and deletion
        (cbuf-save-line-deletion-undo! cbuf (+ current-line 1) 
                                       (list (list-ref (cbuf-text-metrics cbuf) (+ current-line 1)))
                                       'join-lines)
        
        ;; Update current line with joined content
        (cbuf-set-text-cur! cbuf joined-text joined-sgr)
        
        ;; Remove the next line
        (let* ([metrics-list (cbuf-text-metrics cbuf)]
               [new-metrics-list (list-delete-range metrics-list (+ current-line 1) (+ current-line 2))])
          (set-cbuf-text-metrics! cbuf new-metrics-list))
        
        ;; Mark as modified
        (set-cbuf-modified?! cbuf #t)))))

;;; =================================================================
;;; NAVIGATION OPERATIONS
;;; =================================================================

(define (cbuf-forward-char! cbuf)
  "Move cursor forward one character"
  (let ([x-data (cbuf-x-data cbuf)])
    (when (< x-data (cbuf-text-cur-base-length cbuf))
      (cbuf-set-x! cbuf (+ x-data 1) 'data))))

(define (cbuf-backward-char! cbuf)
  "Move cursor backward one character"
  (let ([x-data (cbuf-x-data cbuf)])
    (when (> x-data 0)
      (cbuf-set-x! cbuf (- x-data 1) 'data))))

(define (cbuf-next-line! cbuf)
  "Move cursor to next line, maintaining x-goal"
  (let ([current-line (cbuf-line-cur cbuf)])
    (when (< current-line (- (cbuf-line-count cbuf) 1))
      (cbuf-set-y! cbuf (+ current-line 1)))))

(define (cbuf-previous-line! cbuf)
  "Move cursor to previous line, maintaining x-goal"
  (let ([current-line (cbuf-line-cur cbuf)])
    (when (> current-line 0)
      (cbuf-set-y! cbuf (- current-line 1)))))

(define (cbuf-beginning-of-line! cbuf)
  "Move cursor to beginning of current line"
  (cbuf-set-x! cbuf 0 'data))

(define (cbuf-end-of-line! cbuf)
  "Move cursor to end of current line"
  (cbuf-set-x! cbuf (cbuf-text-cur-base-length cbuf) 'data))

(define (cbuf-beginning-of-buffer! cbuf)
  "Move cursor to beginning of buffer"
  (cbuf-set-y! cbuf 0)
  (cbuf-set-x! cbuf 0 'data))

(define (cbuf-end-of-buffer! cbuf)
  "Move cursor to end of buffer"
  (cbuf-set-y! cbuf (- (cbuf-line-count cbuf) 1))
  (cbuf-set-x! cbuf (cbuf-text-cur-base-length cbuf) 'data))

;;; =================================================================
;;; STRING OPERATIONS
;;; =================================================================

(define (cbuf-insert-string! cbuf str)
  "Insert a string at the current position"
  (let* ([lines (string-split-lines str)]
         [current-line (cbuf-line-cur cbuf)]
         [x-data (cbuf-x-data cbuf)])
    
    (cond
      ;; Single line insertion
      [(= (length lines) 1)
       (let* ([text (cbuf-text-cur cbuf)]
              [sgr-list (cbuf-sgr-list-cur cbuf)]
              [x-index (cbuf-x-data->x-index cbuf x-data)]
              [insert-text (car lines)]
              [current-sgr (cbuf-current-sgr cbuf)]
              [insert-sgr-list (make-list (string-length insert-text) current-sgr)])
         
         ;; Save undo state
         (let ([old-metrics (cbuf-metrics-cur cbuf)])
           (cbuf-save-line-modification-undo! cbuf current-line old-metrics 'insert-string str))
         
         ;; Insert the string
         (let* ([new-text (string-insert-string text x-index insert-text)]
                [new-sgr-list (append (take sgr-list x-index)
                                      insert-sgr-list
                                      (drop sgr-list x-index))])
           
           ;; Update the line
           (cbuf-set-text-cur! cbuf new-text new-sgr-list)
           
           ;; Move cursor to end of inserted text
           (cbuf-set-x! cbuf (+ x-data (count-base-characters insert-text)) 'data)
           
           ;; Mark as modified
           (set-cbuf-modified?! cbuf #t)))]
      
      ;; Multi-line insertion
      [else
       ;; For simplicity, insert each line separately
       ;; A more efficient implementation would batch the operations
       (let ([first-line (car lines)]
             [middle-lines (if (> (length lines) 2) 
                              (drop (drop-right lines 1) 1) 
                              '())]
             [last-line (if (> (length lines) 1) (last lines) "")])
         
         ;; Insert first line
         (cbuf-insert-string! cbuf first-line)
         
         ;; Insert newline and each middle line
         (for-each (lambda (line)
                     (cbuf-insert-newline! cbuf)
                     (cbuf-insert-string! cbuf line))
                   middle-lines)
         
         ;; Insert final newline and last line (if multi-line)
         (when (> (length lines) 1)
           (cbuf-insert-newline! cbuf)
           (cbuf-insert-string! cbuf last-line)))])))

(define (cbuf-delete-region! cbuf start-line start-x-data end-line end-x-data)
  "Delete text from start position to end position"
  ;; Normalize positions (ensure start <= end)
  (when (or (> start-line end-line)
            (and (= start-line end-line) (> start-x-data end-x-data)))
    (let ([temp-line start-line]
          [temp-x start-x-data])
      (set! start-line end-line)
      (set! start-x-data end-x-data)
      (set! end-line temp-line)
      (set! end-x-data temp-x)))
  
  (cond
    ;; Single line deletion
    [(= start-line end-line)
     (let* ([line-text (cbuf-get-line-text cbuf start-line)]
            [line-sgr (text-metrics-sgr-list (list-ref (cbuf-text-metrics cbuf) start-line))]
            [start-index (text-metrics-x-data->x-index 
                          (list-ref (cbuf-text-metrics cbuf) start-line) start-x-data)]
            [end-index (text-metrics-x-data->x-index 
                        (list-ref (cbuf-text-metrics cbuf) start-line) end-x-data)])
       
       ;; Save undo state
       (let ([old-metrics (list-ref (cbuf-text-metrics cbuf) start-line)])
         (cbuf-save-line-modification-undo! cbuf start-line old-metrics 'delete-region))
       
       ;; Delete the range
       (let* ([new-text (string-delete-range line-text start-index end-index)]
              [new-sgr-list (list-delete-range line-sgr start-index end-index)])
         
         ;; Update the line
         (cbuf-update-line! cbuf start-line new-text new-sgr-list)
         
         ;; Position cursor at start of deletion
         (cbuf-set-y! cbuf start-line)
         (cbuf-set-x! cbuf start-x-data 'data)))]
    
    ;; Multi-line deletion - implement as a series of operations
    [else
     ;; For simplicity, implement as repeated single-line operations
     ;; A more efficient implementation would batch these
     (error "Multi-line region deletion not yet implemented")]))

;;; =================================================================
;;; MARK/SELECTION OPERATIONS
;;; =================================================================

(define (cbuf-set-mark! cbuf)
  "Set mark at current cursor position"
  (set-cbuf-mark-set?! cbuf #t)
  (set-cbuf-mark-line! cbuf (cbuf-line-cur cbuf))
  (set-cbuf-mark-x-data! cbuf (cbuf-x-data cbuf)))

(define (cbuf-exchange-point-and-mark! cbuf)
  "Exchange cursor position with mark position"
  (when (cbuf-mark-set? cbuf)
    (let ([mark-line (cbuf-mark-line cbuf)]
          [mark-x-data (cbuf-mark-x-data cbuf)]
          [current-line (cbuf-line-cur cbuf)]
          [current-x-data (cbuf-x-data cbuf)])
      
      ;; Move cursor to mark
      (cbuf-set-y! cbuf mark-line)
      (cbuf-set-x! cbuf mark-x-data 'data)
      
      ;; Set mark to old cursor position
      (set-cbuf-mark-line! cbuf current-line)
      (set-cbuf-mark-x-data! cbuf current-x-data))))

(define (cbuf-get-region-text cbuf)
  "Get text between mark and cursor as a string"
  (if (cbuf-mark-set? cbuf)
      (let ([mark-line (cbuf-mark-line cbuf)]
            [mark-x-data (cbuf-mark-x-data cbuf)]
            [current-line (cbuf-line-cur cbuf)]
            [current-x-data (cbuf-x-data cbuf)])
        
        ;; Normalize positions
        (let ([start-line (min mark-line current-line)]
              [start-x-data (if (= mark-line current-line) 
                               (min mark-x-data current-x-data) 
                               (if (< mark-line current-line) mark-x-data current-x-data))]
              [end-line (max mark-line current-line)]
              [end-x-data (if (= mark-line current-line) 
                             (max mark-x-data current-x-data) 
                             (if (> mark-line current-line) mark-x-data current-x-data))])
          
          (cond
            ;; Single line selection
            [(= start-line end-line)
             (let* ([line-text (cbuf-get-line-text cbuf start-line)]
                    [metrics (list-ref (cbuf-text-metrics cbuf) start-line)]
                    [start-index (text-metrics-x-data->x-index metrics start-x-data)]
                    [end-index (text-metrics-x-data->x-index metrics end-x-data)])
               (substring line-text start-index end-index))]
            
            ;; Multi-line selection
            [else
             ;; For simplicity, return empty string for now
             ;; Full implementation would join multiple lines
             ""])))
      ""))

;;; =================================================================
;;; BUFFER OPERATIONS
;;; =================================================================

(define (cbuf-clear! cbuf)
  "Clear all content from buffer"
  ;; Save undo state
  (cbuf-save-undo-state! cbuf 'clear)
  
  ;; Reset to single empty line
  (let ([empty-metrics (compute-text-metrics "" (cbuf-tab-size cbuf) #:cjk? (cbuf-cjk? cbuf))])
    (set-cbuf-text-metrics! cbuf (list empty-metrics)))
  
  ;; Reset cursor position
  (cbuf-set-y! cbuf 0)
  (cbuf-set-x! cbuf 0 'data)
  
  ;; Clear mark
  (set-cbuf-mark-set?! cbuf #f)
  
  ;; Mark as modified
  (set-cbuf-modified?! cbuf #t))

(define (cbuf-load-from-string! cbuf str)
  "Load content from string, replacing all current content"
  ;; Save undo state
  (cbuf-save-undo-state! cbuf 'load-from-string)
  
  ;; Clear and load new content
  (cbuf-clear! cbuf)
  (unless (string-null? str)
    (cbuf-insert-string! cbuf str))
  
  ;; Reset cursor to beginning
  (cbuf-beginning-of-buffer! cbuf))

(define (cbuf-save-to-string cbuf)
  "Save all buffer content to a string"
  (let ([lines (cbuf-text cbuf)]
        [line-ending (cbuf-line-ending cbuf)])
    (string-join lines line-ending 'suffix)))
