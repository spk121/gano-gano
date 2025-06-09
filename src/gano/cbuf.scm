;;; Gano Character Buffer Module - Immutable Version
;;; Complete ECMA-48 terminal control implementation using immutable text metrics

;;;; A Character-Cell Buffer
;;;
;;; These are functions that act on a character cell buffer:
;;; which is a list of strings, a virtual cursor which is a location
;;; in that list of strings, and a set of functions that add text,
;;; delete text, and move the cursor.
;;;
;;; It assumes that each character has a width of 1 or 2 character
;;; cells: Latin characters have width 1, Hanzi and Kanji have width 2.
;;; Horizontal tabulation characters have a varying width that stretches
;;; to the next tabulation stop. Combining marks have a width of 0
;;; but must follow a valid base character with a width of 1 or 2.
;;;
;;; There are effectively three different ways to refer to the cursor's
;;; x position:
;;;
;;; x-index: the Xth codepoint in a string
;;; x-data: the Xth character in a string, where multi-codepoint characters
;;;      consisting of a base character and combining marks are counted
;;;      as a single character
;;; x-cell: the Xth character cell in the display rendition of the current
;;;      string
;;;
;;; There is also a second x-cell position:
;;; x-goal: the desired character cell. It is the position that the cursor
;;;      would be at if the current line was at least that long.

(define-module (gano cbuf)
  #:use-module (gano text-metrics)  ; Immutable text metrics module
  #:use-module (gano rendering)     ; SGR support
  #:use-module (gano list-utils)    ; Immutable list operations
  #:use-module (gano char)          ; Character utilities
  #:use-module (srfi srfi-9)        ; Record types
  #:use-module (srfi srfi-1)        ; List utilities
  #:use-module (srfi srfi-11)       ; let-values
  #:use-module (srfi srfi-13)       ; String utilities
  #:use-module (srfi srfi-35)       ; Condition types
  #:use-module (ice-9 format)       ; Format function
  #:use-module (ice-9 textual-ports) ; get-string-all
  #:export (
    ;; Record type and constructor
    <cbuf>
    make-cbuf
    cbuf?
    
    ;; Field accessors
    cbuf-text-metrics
    cbuf-line-cur
    cbuf-x-data
    cbuf-x-cell
    cbuf-x-goal
    cbuf-tab-size
    cbuf-vert-tab-size
    cbuf-form-size
    cbuf-home-pos
    cbuf-limit-pos
    cbuf-limit-type
    cbuf-cjk?
    cbuf-modified?
    cbuf-mark-set?
    cbuf-mark-line
    cbuf-mark-x-data
    cbuf-bell?
    cbuf-cut-buffer
    cbuf-undo-list
    cbuf-current-sgr
    cbuf-default-grcm
    cbuf-sgr-stack
    cbuf-line-ending
    
    ;; Derived accessors
    cbuf-line-count
    cbuf-text
    cbuf-text-cur
    cbuf-metrics-cur
    cbuf-text-cur-length
    cbuf-text-cur-cell-length
    cbuf-text-cur-base-length
    
    ;; Position management and conversion
    cbuf-set-x!
    cbuf-set-y!
    cbuf-set-positions!
    cbuf-synchronize-x-goal!
    cbuf-bracket-x-data
    cbuf-bracket-line
    
    ;; Text operations
    cbuf-insert-codepoint
    cbuf-insert-newline
    cbuf-delete-newline
    cbuf-render-line
    cbuf-render-line-string-only
    
    ;; ECMA-48 Control Functions
    ;; Cursor movement
    cbuf-cursor-up              ; CUU
    cbuf-cursor-down            ; CUD  
    cbuf-cursor-forward         ; CUF (right)
    cbuf-cursor-backward        ; CUB (left)
    cbuf-cursor-next-line       ; CNL
    cbuf-cursor-preceding-line  ; CPL
    cbuf-cursor-character-absolute ; CHA
    cbuf-cursor-line-absolute   ; VPA
    cbuf-cursor-position        ; CUP/HVP
    
    ;; Tab operations
    cbuf-cursor-forward-tabulation    ; CHT
    cbuf-cursor-backward-tabulation   ; CBT
    cbuf-cursor-line-tabulation       ; CVT
    cbuf-character-tabulation         ; HT
    cbuf-line-tabulation             ; VT
    
    ;; Character operations
    cbuf-character-position-forward   ; HPR
    cbuf-character-position-backward  ; HPB
    cbuf-character-position-absolute  ; HPA
    
    ;; Line operations
    cbuf-line-position-forward  ; VPR
    cbuf-line-position-backward ; VPB
    cbuf-line-position-absolute ; VPA
    
    ;; Format effectors
    cbuf-backspace              ; BS
    cbuf-carriage-return        ; CR
    cbuf-line-feed              ; LF
    cbuf-form-feed              ; FF
    cbuf-reverse-line-feed      ; RI
    cbuf-next-line              ; NEL
    
    ;; Page operations
    cbuf-page-position-absolute   ; PPA
    cbuf-page-position-forward    ; PPR
    cbuf-page-position-backward   ; PPB
    
    ;; Bell and status
    cbuf-bell                   ; BEL
    cbuf-clear-bell             ; Clear bell state
    cbuf-device-status-report   ; DSR
    cbuf-device-attributes      ; DA
    
    ;; Character insertion
    cbuf-insert-character       ; ICH

    ;; Line insertion
    cbuf-insert-line            ; IL

    ;; Character deletion
    cbuf-delete-character       ; DCH
    cbuf-delete-preceding-character

    ;; Line deletion  
    cbuf-delete-line            ; DL
    cbuf-delete-newline

    ;; Erase operations
    cbuf-erase-character        ; ECH
    cbuf-erase-in-line          ; EL
    cbuf-erase-in-buffer

    ;; Word operations
    cbuf-delete-word-forward
    cbuf-delete-word-backward

    ;; SGR state management
    cbuf-select-graphic-rendition
    cbuf-reset-graphic-rendition
    cbuf-set-default-grcm!
    
    ;; SGR stack operations
    cbuf-save-sgr-state
    cbuf-restore-sgr-state
    cbuf-clear-sgr-stack
    
    ;; Enhanced text insertion
    cbuf-insert-codepoint-with-sgr
    cbuf-insert-string-with-current-sgr
    
    ;; SGR positioning and range operations (immutable)
    cbuf-set-sgr-at-cursor
    cbuf-set-sgr-range
    cbuf-get-sgr-at-cursor
    
    ;; SGR-aware rendering
    cbuf-render-line-with-sgr
    cbuf-get-line-sgr-spans
    
    ;; Convenience functions
    cbuf-set-bold!
    cbuf-set-italic!
    cbuf-set-foreground-color!
    cbuf-set-background-color!
    cbuf-apply-sgr-to-selection

    ;; Undo operations
    cbuf-undo
    cbuf-can-undo?
    
    ;; Mark operations
    cbuf-set-mark!
    cbuf-clear-mark!
    cbuf-goto-mark
    
    ;; Status queries
    cbuf-beginning-of-line?
    cbuf-end-of-line?
    cbuf-beginning-of-buffer?
    cbuf-end-of-buffer?
    cbuf-on-first-page?
    cbuf-on-last-page?
    
    ;; Configuration
    cbuf-set-line-home!
    cbuf-set-tab-size!
    cbuf-set-vert-tab-size!
    cbuf-set-form-size!
    cbuf-set-line-ending!
    
    ;; JSON span format
    cbuf->json
    json->cbuf
    cbuf-save-json
    cbuf-load-json
    
    ;; Text format  
    cbuf->text
    text->cbuf
    cbuf-save-text
    cbuf-load-text

    ;; Combining marks
    validate-combining-mark-limits
    MAX-COMBINING-MARKS

    ;; Utilities
    sgr->json
    json->sgr
    color->json
    json->color
    detect-line-ending

    ;; Efficient string operations
    cbuf-insert-string-with-sgr
    cbuf-insert-string-with-current-sgr
    cbuf-insert-string-permissive
    cbuf-insert-lines
  
    ;; Efficient validation
    validate-string-combining-marks
    validate-combining-marks-at-insertion
  
    ;; Internal functions for advanced use
    cbuf-insert-string-internal
    cbuf-insert-lines-internal
    text->cbuf-internal
    count-base-characters    

    ;;; Error conditions for combining sequences
    &cbuf-too-many-combining-marks
    cbuf-too-many-combining-marks-error?
    cbuf-too-many-combining-marks-error:base-char
    cbuf-too-many-combining-marks-error:combining-char
    cbuf-too-many-combining-marks-error:current-count
    cbuf-too-many-combining-marks-error:max-count

    ;;; Error condition for too many combining marks
    &cbuf-too-many-combining-marks
    cbuf-too-many-combining-marks-error?
    cbuf-too-many-combining-marks-error:base-char
    cbuf-too-many-combining-marks-error:combining-char
    cbuf-too-many-combining-marks-error:current-count
    cbuf-too-many-combining-marks-error:max-count

    ;;; Error conditions for ranges and motion
    &cbuf-range-error
    cbuf-range-error?
    cbuf-range-error:operation
    cbuf-range-error:requested
    cbuf-range-error:actual
    cbuf-range-error:reason

    &cbuf-beginning-of-buffer
    cbuf-beginning-of-buffer-error?
    &cbuf-end-of-buffer
    cbuf-end-of-buffer-error?
    &cbuf-beginning-of-line
    cbuf-beginning-of-line-error?
    &cbuf-end-of-line
    cbuf-end-of-line-error?
    &cbuf-line-limit-exceeded
    cbuf-line-limit-exceeded-error?
    cbuf-line-limit-exceeded-error:limit
))


;; Maximum combining marks per base character (matches ncurses cchar_t)
(define MAX-COMBINING-MARKS 4)

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

;;; Error conditions for ranges and motion
(define-condition-type &cbuf-range-error &error
  cbuf-range-error?
  (operation cbuf-range-error:operation)
  (requested cbuf-range-error:requested)
  (actual cbuf-range-error:actual)
  (reason cbuf-range-error:reason))

(define-condition-type &cbuf-beginning-of-buffer &cbuf-range-error
  cbuf-beginning-of-buffer-error?)

(define-condition-type &cbuf-end-of-buffer &cbuf-range-error
  cbuf-end-of-buffer-error?)

(define-condition-type &cbuf-beginning-of-line &cbuf-range-error
  cbuf-beginning-of-line-error?)

(define-condition-type &cbuf-end-of-line &cbuf-range-error
  cbuf-end-of-line-error?)

(define-condition-type &cbuf-line-limit-exceeded &cbuf-range-error
  cbuf-line-limit-exceeded-error?
  (limit cbuf-line-limit-exceeded-error:limit))

;;; CBuf record type
(define-record-type <cbuf>
  (%make-cbuf text-metrics line-cur x-data x-cell x-goal 
             tab-size vert-tab-size form-size home-pos limit-pos limit-type
             cjk? modified? mark-set? mark-line mark-x-data bell? cut-buffer undo-list
             current-sgr default-grcm sgr-stack line-ending)
  cbuf?
  ;; Text content
  (text-metrics cbuf-text-metrics set-cbuf-text-metrics!) ; list of <text-metrics>
  
  ;; Current position
  (line-cur cbuf-line-cur set-cbuf-line-cur!)        ; current line (y)
  (x-data cbuf-x-data set-cbuf-x-data!)              ; data position
  (x-cell cbuf-x-cell set-cbuf-x-cell!)              ; cell position
  (x-goal cbuf-x-goal set-cbuf-x-goal!)              ; goal cell position
  
  ;; Tab and formatting configuration
  (tab-size cbuf-tab-size set-cbuf-tab-size!)        ; spaces per tab
  (vert-tab-size cbuf-vert-tab-size set-cbuf-vert-tab-size!) ; lines per vert tab
  (form-size cbuf-form-size set-cbuf-form-size!)     ; lines per page
  (home-pos cbuf-home-pos set-cbuf-home-pos!)        ; line home position
  (limit-pos cbuf-limit-pos set-cbuf-limit-pos!)     ; line limit position
  (limit-type cbuf-limit-type set-cbuf-limit-type!)  ; 'data or 'presentation
  
  ;; Configuration
  (cjk? cbuf-cjk? set-cbuf-cjk?!)                    ; CJK terminal mode
  
  ;; State flags
  (modified? cbuf-modified? set-cbuf-modified?!)      ; buffer modified flag
  (bell? cbuf-bell? set-cbuf-bell?!)                  ; bell/alarm state
  
  ;; Mark (selection start point)
  (mark-set? cbuf-mark-set? set-cbuf-mark-set?!)      ; is mark active?
  (mark-line cbuf-mark-line set-cbuf-mark-line!)      ; mark line position
  (mark-x-data cbuf-mark-x-data set-cbuf-mark-x-data!) ; mark data position
  
  ;; Cut/copy buffer
  (cut-buffer cbuf-cut-buffer set-cbuf-cut-buffer!)  ; list of strings
  
  ;; Undo system
  (undo-list cbuf-undo-list set-cbuf-undo-list!)    ; list of undo records
  
  ;; SGR state
  (current-sgr cbuf-current-sgr set-cbuf-current-sgr!) ; current SGR for new text
  (default-grcm cbuf-default-grcm set-cbuf-default-grcm!) ; default GRCM mode
  (sgr-stack cbuf-sgr-stack set-cbuf-sgr-stack!)     ; SGR state stack
  
  ;; Line ending configuration
  (line-ending cbuf-line-ending set-cbuf-line-ending!)) ; line terminator string

;;; Constructor
(define* (make-cbuf #:key (tab-size 8) (vert-tab-size 6) (form-size 66)
                    (cjk? #f) (initial-text "") (default-grcm 'replacing)
                    (line-ending "\n"))
  "Create a new character buffer with specified configuration."
  (let* ([lines (if (string-null? initial-text) 
                    (list "")
                    (string-split initial-text #\newline))]
         [metrics (map (lambda (line) 
                         (compute-text-metrics line tab-size #:cjk? cjk?))
                       lines)])
    (%make-cbuf metrics 0 0 0 0 
               tab-size vert-tab-size form-size 0 79 'data
               cjk? #f #f 0 0 #f #f '()
               (make-default-sgr)     ; current-sgr
               default-grcm           ; default-grcm  
               '()                    ; sgr-stack
               line-ending)))         ; line-ending

;;; Derived accessors
(define (cbuf-line-count cbuf)
  "Return the number of lines in the buffer"
  (length (cbuf-text-metrics cbuf)))

(define (cbuf-text cbuf)
  "Return all text lines as a list of strings"
  (map text-metrics-string (cbuf-text-metrics cbuf)))

(define (cbuf-text-cur cbuf)
  "Return the text of the current line"
  (text-metrics-string (list-ref (cbuf-text-metrics cbuf) (cbuf-line-cur cbuf))))

(define (cbuf-metrics-cur cbuf)
  "Return the text-metrics of the current line"
  (list-ref (cbuf-text-metrics cbuf) (cbuf-line-cur cbuf)))

(define (cbuf-sgr-list-cur cbuf)
  "Return the SGR list of the current line"
  (text-metrics-sgr-list (cbuf-metrics-cur cbuf)))

(define (cbuf-get-line-text cbuf n)
  "Return the text of line N"
  (text-metrics-string (list-ref (cbuf-text-metrics cbuf) n)))

(define (cbuf-text-cur-length cbuf)
  "Return the number of codepoints in the current line"
  (string-length (cbuf-text-cur cbuf)))

(define (cbuf-text-cur-cell-length cbuf)
  "Return the number of cells in the current line"
  (text-metrics-cell-length (cbuf-metrics-cur cbuf)))

(define (cbuf-text-cur-base-length cbuf)
  "Return the number of base characters in the current line"
  (text-metrics-string-base-length (cbuf-metrics-cur cbuf)))

;;; =================================================================
;;; UNDO SYSTEM
;;; =================================================================

(define (cbuf-save-undo-state! cbuf operation . args)
  "Save current state for undo using delta-based approach.
   Records only the changes needed to reverse the operation."
  (let ([undo-record `((position ,(cbuf-line-cur cbuf) 
                                 ,(cbuf-x-data cbuf) 
                                 ,(cbuf-x-cell cbuf) 
                                 ,(cbuf-x-goal cbuf))
                       (mark ,(cbuf-mark-set? cbuf)
                             ,(cbuf-mark-line cbuf)
                             ,(cbuf-mark-x-data cbuf))
                       (sgr-state ,(sgr-copy (cbuf-current-sgr cbuf))
                                  ,(cbuf-default-grcm cbuf)
                                  ,(map sgr-copy (cbuf-sgr-stack cbuf)))
                       (operation ,operation ,@args))])
    (set-cbuf-undo-list! cbuf (cons undo-record (cbuf-undo-list cbuf)))))

(define (cbuf-save-line-modification-undo! cbuf line-num old-metrics operation . args)
  "Save undo state for line modification - stores the old metrics of the modified line"
  (let ([undo-record `((position ,(cbuf-line-cur cbuf) 
                                 ,(cbuf-x-data cbuf) 
                                 ,(cbuf-x-cell cbuf) 
                                 ,(cbuf-x-goal cbuf))
                       (mark ,(cbuf-mark-set? cbuf)
                             ,(cbuf-mark-line cbuf)
                             ,(cbuf-mark-x-data cbuf))
                       (sgr-state ,(sgr-copy (cbuf-current-sgr cbuf))
                                  ,(cbuf-default-grcm cbuf)
                                  ,(map sgr-copy (cbuf-sgr-stack cbuf)))
                       (operation ,operation ,@args)
                       (modified-line ,line-num ,old-metrics))])
    (set-cbuf-undo-list! cbuf (cons undo-record (cbuf-undo-list cbuf)))))

(define (cbuf-save-line-insertion-undo! cbuf start-line num-lines operation . args)
  "Save undo state for line insertion - records lines that were added"
  (let ([undo-record `((position ,(cbuf-line-cur cbuf) 
                                 ,(cbuf-x-data cbuf) 
                                 ,(cbuf-x-cell cbuf) 
                                 ,(cbuf-x-goal cbuf))
                       (mark ,(cbuf-mark-set? cbuf)
                             ,(cbuf-mark-line cbuf)
                             ,(cbuf-mark-x-data cbuf))
                       (sgr-state ,(sgr-copy (cbuf-current-sgr cbuf))
                                  ,(cbuf-default-grcm cbuf)
                                  ,(map sgr-copy (cbuf-sgr-stack cbuf)))
                       (operation ,operation ,@args)
                       (inserted-lines ,start-line ,num-lines))])
    (set-cbuf-undo-list! cbuf (cons undo-record (cbuf-undo-list cbuf)))))

(define (cbuf-save-line-deletion-undo! cbuf start-line deleted-metrics operation . args)
  "Save undo state for line deletion - stores the deleted lines"
  (let ([undo-record `((position ,(cbuf-line-cur cbuf) 
                                 ,(cbuf-x-data cbuf) 
                                 ,(cbuf-x-cell cbuf) 
                                 ,(cbuf-x-goal cbuf))
                       (mark ,(cbuf-mark-set? cbuf)
                             ,(cbuf-mark-line cbuf)
                             ,(cbuf-mark-x-data cbuf))
                       (sgr-state ,(sgr-copy (cbuf-current-sgr cbuf))
                                  ,(cbuf-default-grcm cbuf)
                                  ,(map sgr-copy (cbuf-sgr-stack cbuf)))
                       (operation ,operation ,@args)
                       (deleted-lines ,start-line ,deleted-metrics))])
    (set-cbuf-undo-list! cbuf (cons undo-record (cbuf-undo-list cbuf)))))

(define (cbuf-save-sgr-undo! cbuf operation . args)
  "Save SGR state for undo - stores current SGR and GRCM"
  (let ([undo-record `((position ,(cbuf-line-cur cbuf) 
                                 ,(cbuf-x-data cbuf) 
                                 ,(cbuf-x-cell cbuf) 
                                 ,(cbuf-x-goal cbuf))
                       (mark ,(cbuf-mark-set? cbuf)
                             ,(cbuf-mark-line cbuf)
                             ,(cbuf-mark-x-data cbuf))
                       (sgr-state ,(sgr-copy (cbuf-current-sgr cbuf))
                                  ,(cbuf-default-grcm cbuf)
                                  ,(map sgr-copy (cbuf-sgr-stack cbuf)))
                       (operation ,operation ,@args))])
    (set-cbuf-undo-list! cbuf (cons undo-record (cbuf-undo-list cbuf)))))

(define (cbuf-can-undo? cbuf)
  "Return #t if there are operations that can be undone"
  (not (null? (cbuf-undo-list cbuf))))

(define (cbuf-undo cbuf)
  "Undo the last operation using delta-based restoration"
  (when (cbuf-can-undo? cbuf)
    (let* ([undo-record (car (cbuf-undo-list cbuf))]
           [position (assq 'position undo-record)]
           [mark (assq 'mark undo-record)]
           [sgr-state (assq 'sgr-state undo-record)]
           [modified-line (assq 'modified-line undo-record)]
           [inserted-lines (assq 'inserted-lines undo-record)]
           [deleted-lines (assq 'deleted-lines undo-record)])
      
      ;; Undo text changes based on operation type
      (cond
       ;; Restore modified line (e.g., undo character insertion)
       [modified-line
        (let ([line-num (cadr modified-line)]
              [old-metrics (caddr modified-line)])
          (let ([new-metrics-list (list-update (cbuf-text-metrics cbuf) line-num old-metrics)])
            (set-cbuf-text-metrics! cbuf new-metrics-list)))]
       
       ;; Remove inserted lines (e.g., undo newline insertion)
       [inserted-lines
        (let ([start-line (cadr inserted-lines)]
              [num-lines (caddr inserted-lines)])
          (let* ([metrics-list (cbuf-text-metrics cbuf)]
                 [new-metrics-list (append (take metrics-list start-line)
                                           (drop metrics-list (+ start-line num-lines)))])
            (set-cbuf-text-metrics! cbuf new-metrics-list)))]
       
       ;; Restore deleted lines (e.g., undo line deletion)
       [deleted-lines
        (let ([start-line (cadr deleted-lines)]
              [deleted-metrics (caddr deleted-lines)])
          (let* ([metrics-list (cbuf-text-metrics cbuf)]
                 [new-metrics-list (append (take metrics-list start-line)
                                           deleted-metrics
                                           (drop metrics-list start-line))])
            (set-cbuf-text-metrics! cbuf new-metrics-list)))])
      
      ;; Restore SGR state
      (when sgr-state
        (let ([saved-current-sgr (cadr sgr-state)]
              [saved-grcm (caddr sgr-state)]
              [saved-stack (cadddr sgr-state)])
          (set-cbuf-current-sgr! cbuf (sgr-copy saved-current-sgr))
          (set-cbuf-default-grcm! cbuf saved-grcm)
          (set-cbuf-sgr-stack! cbuf (map sgr-copy saved-stack))))
      
      ;; Restore cursor position (bracket to ensure validity after text changes)
      (when position
        (let ([line (cadr position)]
              [x-data (caddr position)]
              [x-cell (cadddr position)]
              [x-goal (cadddr (cdr position))])
          (set-cbuf-line-cur! cbuf (cbuf-bracket-line cbuf line))
          (set-cbuf-x-data! cbuf (cbuf-bracket-x-data cbuf x-data))
          (set-cbuf-x-cell! cbuf x-cell)
          (set-cbuf-x-goal! cbuf x-goal)))
      
      ;; Restore mark state
      (when mark
        (let ([mark-set? (cadr mark)]
              [mark-line (caddr mark)]
              [mark-x-data (cadddr mark)])
          (set-cbuf-mark-set?! cbuf mark-set?)
          (set-cbuf-mark-line! cbuf (cbuf-bracket-line cbuf mark-line))
          (set-cbuf-mark-x-data! cbuf mark-x-data)))
      
      ;; Remove this undo record and mark as modified
      (set-cbuf-undo-list! cbuf (cdr (cbuf-undo-list cbuf)))
      (set-cbuf-modified?! cbuf #t))))

;;; =================================================================
;;; HELPER FUNCTIONS
;;; =================================================================

;;;; Validation Helper Functions

(define (cbuf-validate-line-movement cbuf current-line delta operation)
  "Validate line movement, return (target-line . clamped-line . clamped?)"
  (let* ([target-line (+ current-line delta)]
         [max-line (- (cbuf-line-count cbuf) 1)]
         [clamped-line (max 0 (min target-line max-line))]
         [clamped? (not (= target-line clamped-line))])
    (list target-line clamped-line clamped? operation)))

(define (cbuf-validate-column-movement cbuf current-column delta operation)
  "Validate column movement, return (target-column . clamped-column . clamped?)"
  (let* ([target-column (+ current-column delta)]
         [max-column (cbuf-text-cur-cell-length cbuf)]
         [clamped-column (max 0 (min target-column max-column))]
         [clamped? (not (= target-column clamped-column))])
    (list target-column clamped-column clamped? operation)))

(define (cbuf-validate-absolute-position cbuf line column operation)
  "Validate absolute positioning, return detailed validation info"
  (let* ([max-line (- (cbuf-line-count cbuf) 1)]
         [clamped-line (max 0 (min line max-line))]
         [line-clamped? (not (= line clamped-line))]
         [max-column (if (< clamped-line (cbuf-line-count cbuf))
                        (text-metrics-cell-length 
                         (list-ref (cbuf-text-metrics cbuf) clamped-line))
                        0)]
         [clamped-column (max 0 (min column max-column))]
         [column-clamped? (not (= column clamped-column))])
    (list clamped-line clamped-column line-clamped? column-clamped? operation)))

(define (cbuf-raise-boundary-error cbuf operation target actual boundary-type)
  "Centralized boundary error raising"
  (let ([condition-constructor
         (case boundary-type
           [(beginning-of-buffer) &cbuf-beginning-of-buffer]
           [(end-of-buffer) &cbuf-end-of-buffer]
           [(beginning-of-line) &cbuf-beginning-of-line]
           [(end-of-line) &cbuf-end-of-line]
           [else &cbuf-range-error])])
    (raise (condition (condition-constructor
                       (operation operation)
                       (requested target)
                       (actual actual)
                       (reason boundary-type))))))

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

;;;;;
(define (cbuf-update-line! cbuf line-num new-text new-sgr-list)
  "Update the text and SGR list for a specific line"
  ;; Simple validation
  (unless (= (string-length new-text) (length new-sgr-list))
    (error "Text length and SGR list length must match"))
  
  ;; Save undo state
  (let ([old-metrics (list-ref (cbuf-text-metrics cbuf) line-num)])
    (cbuf-save-line-modification-undo! cbuf line-num old-metrics 'update-line line-num new-text))
  
  ;; Compute new metrics with cbuf's settings
  (let* ([new-metrics (compute-text-metrics-with-sgr new-text 
                                                     new-sgr-list
                                                     (cbuf-tab-size cbuf) 
                                                     #:cjk? (cbuf-cjk? cbuf))]
         [new-metrics-list (list-update (cbuf-text-metrics cbuf) line-num new-metrics)])
    (set-cbuf-text-metrics! cbuf new-metrics-list)
    (set-cbuf-modified?! cbuf #t)))

(define (cbuf-set-text-cur! cbuf text sgr-list)
  "Set the text of the current line and update its metrics"
  (cbuf-update-line! cbuf (cbuf-line-cur cbuf) text sgr-list))

(define (cbuf-update-metrics-cur! cbuf new-metrics)
  "Update the metrics for the current line"
  (let* ([line-num (cbuf-line-cur cbuf)]
         [metrics-list (cbuf-text-metrics cbuf)]
         [new-metrics-list (list-update metrics-list line-num new-metrics)])
    (set-cbuf-text-metrics! cbuf new-metrics-list)
    (set-cbuf-modified?! cbuf #t)))

;;; Position conversion functions using text metrics
(define (cbuf-x-data->x-index cbuf x-data)
  "Convert data position to string index"
  (if (and (< (cbuf-line-cur cbuf) (cbuf-line-count cbuf))
           (>= (cbuf-line-cur cbuf) 0))
      (text-metrics-x-data->x-index (cbuf-metrics-cur cbuf) x-data)
      0))  ; Safe default

(define (cbuf-x-data->x-cell cbuf x-data)
  "Convert data position to cell position"
  (if (and (< (cbuf-line-cur cbuf) (cbuf-line-count cbuf))
           (>= (cbuf-line-cur cbuf) 0))
      (text-metrics-x-data->x-cell (cbuf-metrics-cur cbuf) x-data)
      0))  ; Safe default

(define (cbuf-x-cell->x-data cbuf x-cell)
  "Convert cell position to data position"
  (if (and (< (cbuf-line-cur cbuf) (cbuf-line-count cbuf))
           (>= (cbuf-line-cur cbuf) 0))
      (text-metrics-x-cell->x-data (cbuf-metrics-cur cbuf) x-cell)
      0))  ; Safe default

(define (cbuf-x-cell->x-index cbuf x-cell)
  "Convert cell position to string index"
  (if (and (< (cbuf-line-cur cbuf) (cbuf-line-count cbuf))
           (>= (cbuf-line-cur cbuf) 0))
      (text-metrics-x-cell->x-index (cbuf-metrics-cur cbuf) x-cell)
      0))  ; Safe default

(define (cbuf-x-index->x-data cbuf x-index)
  "Convert string index to data position"
  (if (and (< (cbuf-line-cur cbuf) (cbuf-line-count cbuf))
           (>= (cbuf-line-cur cbuf) 0))
      (text-metrics-x-index->x-data (cbuf-metrics-cur cbuf) x-index)
      0))  ; Safe default

(define (cbuf-x-index->x-cell cbuf x-index)
  "Convert string index to cell position"
  (if (and (< (cbuf-line-cur cbuf) (cbuf-line-count cbuf))
           (>= (cbuf-line-cur cbuf) 0))
      (text-metrics-x-index->x-cell (cbuf-metrics-cur cbuf) x-index)
      0))  ; Safe default

;;; Position management
(define (cbuf-bracket-x-data cbuf x-data)
  "Return x-data if valid, or nearest valid x-data position"
  (max 0 (min x-data (cbuf-text-cur-base-length cbuf))))

(define (cbuf-bracket-line cbuf line)
  "Return line if valid, or nearest valid line number"
  (max 0 (min line (- (cbuf-line-count cbuf) 1))))

(define (cbuf-update-x-cell! cbuf)
  "Update x-cell to match current x-data position"
  (let ([x-cell (cbuf-x-data->x-cell cbuf (cbuf-x-data cbuf))])
    (set-cbuf-x-cell! cbuf x-cell)))

(define (cbuf-synchronize-x-goal! cbuf)
  "Set x-goal to match current x-cell position"
  (set-cbuf-x-goal! cbuf (cbuf-x-cell cbuf)))

(define (cbuf-set-x! cbuf x type)
  "Set the x position based on TYPE ('index, 'data, or 'cell)"
  (cond
   [(eq? type 'index)
    (let ([x-data (cbuf-x-index->x-data cbuf x)])
      (when x-data
        (set-cbuf-x-data! cbuf x-data)
        (cbuf-update-x-cell! cbuf)
        (cbuf-synchronize-x-goal! cbuf)))]
   
   [(eq? type 'data)
    (set-cbuf-x-data! cbuf (cbuf-bracket-x-data cbuf x))
    (cbuf-update-x-cell! cbuf)
    (cbuf-synchronize-x-goal! cbuf)]
   
   [(eq? type 'cell)
    (let ([x-data (cbuf-x-cell->x-data cbuf x)])
      (if x-data
          (begin
            (set-cbuf-x-data! cbuf x-data)
            (cbuf-update-x-cell! cbuf)
            (set-cbuf-x-goal! cbuf x))
          (begin
            (set-cbuf-x-data! cbuf (cbuf-text-cur-base-length cbuf))
            (cbuf-update-x-cell! cbuf)
            (set-cbuf-x-goal! cbuf x))))]
   
   [else
    (error "Invalid cbuf-set-x! type" type)]))

(define (cbuf-set-y! cbuf line)
  "Set the current line and update positions"
  (set-cbuf-line-cur! cbuf (cbuf-bracket-line cbuf line))
  ;; Try to maintain x-goal position on new line
  (cbuf-set-x! cbuf (cbuf-x-goal cbuf) 'cell))

(define (cbuf-set-positions! cbuf n device)
  "Set position based on device type ('data or 'presentation)"
  (cond
   [(eq? device 'data)
    (cbuf-set-x! cbuf n 'data)]
   [(eq? device 'presentation)
    (cbuf-set-x! cbuf n 'cell)]
   [else
    (error "Invalid device type" device)]))

;;; Tab computation helper
(define (cbuf-compute-tab-column pos tabsize n)
  "If N is positive, compute the presentation position of the nth next
forward tabulation. If N is negative, compute the position of the
backward tabulation. This function does not do bracketing."
  (cond
   [(< n 0)
    ;; Back up n tabsizes, then find previous tab stop
    (let* ([pp1 (+ pos (* n tabsize))]
           [pp2 (cond
                 [(zero? (remainder pp1 tabsize)) pp1]
                 [(> pp1 0) (* tabsize (quotient pp1 tabsize))]
                 [(< pp1 0) (* tabsize (quotient pp1 tabsize))])])
      pp2)]
   [(= n 0) pos]
   [(> n 0)
    ;; Advance to next tab stop, then forward n-1 more
    (let* ([next-tab (* tabsize (+ (quotient pos tabsize) 1))]
           [final-tab (+ next-tab (* (- n 1) tabsize))])
      final-tab)]))

;;; Also update the cbuf function that calls this:
(define* (cbuf-render-line cbuf x-cell-start x-width #:key (pad? #t))
  "Render a portion of the current line, with both the
   substring and a list of the <sgr> renderings for the substring.
   Returns two values: (values rendered-string sgr-list)"
  (text-metrics-render-line (cbuf-metrics-cur cbuf) 
                            x-cell-start x-width #:pad? pad?))

(define* (cbuf-render-line-string-only cbuf x-cell-start x-width #:key (pad? #t))
  "Return only the rendered string"
  (let-values ([(rendered-string sgr-list) 
                (cbuf-render-line cbuf x-cell-start x-width #:pad? pad?)])
    rendered-string))


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
           (error "Combining mark without base character" ch))
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

(define (validate-combining-mark-insertion cbuf char-new)
  "Validate that inserting CHAR-NEW at current position won't exceed limits.
   Only checks if CHAR-NEW is a combining mark."
  (when (char-combining-mark? char-new)
    (let* ([x-data (cbuf-x-data cbuf)]
           [txt (cbuf-text-cur cbuf)])
      
      ;; Check we're not at beginning of line
      (when (= x-data 0)
        (error "Cannot insert combining mark at beginning of line"))
      
      ;; Find the base character for this cluster
      (let* ([base-data-pos (- x-data 1)]
             [base-index (cbuf-x-data->x-index cbuf base-data-pos)]
             [base-char (string-ref txt base-index)]
             [current-count (count-combining-marks-in-cluster txt base-index)])
        
        ;; Verify base character is valid
        (when (char-combining-mark? base-char)
          (error "Cannot attach combining mark to another combining mark"))
        
        ;; Check combining mark limit
        (when (>= current-count MAX-COMBINING-MARKS)
          (raise (condition (&cbuf-too-many-combining-marks
                             (base-char base-char)
                             (combining-char char-new)
                             (current-count current-count)
                             (max-count MAX-COMBINING-MARKS)))))))))    

;;; =================================================================
;;; SGR STATE MANAGEMENT (Updated for Immutable)
;;; =================================================================

(define* (cbuf-select-graphic-rendition cbuf sgr-attributes #:key (mode #f))
  "SGR - Select Graphic Rendition. Apply SGR attributes to current SGR state."
  ;; Save undo state for SGR changes
  (cbuf-save-sgr-undo! cbuf 'select-graphic-rendition sgr-attributes mode)
  
  (let* ([current-sgr (cbuf-current-sgr cbuf)]
         [actual-mode (or mode (cbuf-default-grcm cbuf))]
         [attr-list (if (list? sgr-attributes) sgr-attributes (list sgr-attributes))])
    
    (cond
     ;; Replacing mode: start with default SGR, then apply attributes
     [(eq? actual-mode 'replacing)
      (let ([new-sgr (make-default-sgr)])
        (sgr-apply-attributes! new-sgr attr-list)
        (set-cbuf-current-sgr! cbuf new-sgr))]
     
     ;; Cumulative mode: apply attributes to current SGR
     [(eq? actual-mode 'cumulative)
      (let ([new-sgr (sgr-copy current-sgr)])
        (sgr-apply-attributes! new-sgr attr-list)
        (set-cbuf-current-sgr! cbuf new-sgr))]
     
     [else
      (error "Invalid GRCM mode" actual-mode)])
    
    (set-cbuf-modified?! cbuf #t)))

(define (cbuf-reset-graphic-rendition cbuf)
  "Reset SGR to default state (equivalent to SGR 0)"
  (cbuf-select-graphic-rendition cbuf '(reset) #:mode 'replacing))

(define (cbuf-set-default-grcm! cbuf mode)
  "Set the default Graphic Rendition Combination Mode"
  (unless (memq mode '(replacing cumulative))
    (error "Invalid GRCM mode, must be 'replacing or 'cumulative" mode))
  (set-cbuf-default-grcm! cbuf mode))

;;; =================================================================
;;; SGR STACK OPERATIONS  
;;; =================================================================

(define (cbuf-save-sgr-state cbuf)
  "Save current SGR state to stack"
  (let ([current-sgr (cbuf-current-sgr cbuf)]
        [stack (cbuf-sgr-stack cbuf)])
    (set-cbuf-sgr-stack! cbuf (cons (sgr-copy current-sgr) stack))))

(define (cbuf-restore-sgr-state cbuf)
  "Restore SGR state from stack"
  (let ([stack (cbuf-sgr-stack cbuf)])
    (unless (null? stack)
      ;; Save undo state before restoring
      (cbuf-save-sgr-undo! cbuf 'restore-sgr-state)
      
      (set-cbuf-current-sgr! cbuf (sgr-copy (car stack)))
      (set-cbuf-sgr-stack! cbuf (cdr stack))
      (set-cbuf-modified?! cbuf #t))))

(define (cbuf-clear-sgr-stack cbuf)
  "Clear the SGR state stack"
  (set-cbuf-sgr-stack! cbuf '()))

;;; =================================================================
;;; TEXT MODIFICATION OPERATIONS (Updated for Immutable)
;;; =================================================================


(define (cbuf-insert-codepoint cbuf char-new)
  "Enhanced version: Insert codepoint using current SGR state"
  (cbuf-insert-codepoint-with-sgr cbuf char-new (cbuf-current-sgr cbuf)))

(define* (cbuf-insert-string-with-sgr cbuf str sgr-list #:key (strict? #t))
  "Insert string with SGR list.
   Validates entire operation first, then performs single atomic update."
  
  (when (not (= (string-length str) (length sgr-list)))
    (error "String length and SGR list length must match" 
           (string-length str) (length sgr-list)))
  
  ;; Save undo state before any modifications
  (let ([old-metrics (cbuf-metrics-cur cbuf)])
    (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 
                                      'insert str))
  
  (cond
   [(not strict?)
    ;; Permissive mode - perform insertion without validation
    (cbuf-insert-string-internal cbuf str sgr-list)]
   
   [else
    ;; Strict mode - validate first, then perform operation
    (let* ([current-str (cbuf-text-cur cbuf)]
           [insertion-point (cbuf-x-data->x-index cbuf (cbuf-x-data cbuf))]
           [validation (validate-combining-marks-at-insertion current-str insertion-point str)])
      
      (if (car validation)
          ;; Validation passed - perform insertion
          (cbuf-insert-string-internal cbuf str sgr-list)
          
          ;; Validation failed - raise error with first violation
          (let ([violations (cadr validation)])
            (when (not (null? violations))
              (let ([first-violation (car violations)])
                (case (car first-violation)
                  [(no-base-character)
                   (raise (condition (&cbuf-invalid-combining-sequence
                                      (operation 'insert-string)
                                      (base-char #f)
                                      (combining-char (cadr first-violation))
                                      (current-count 0)
                                      (max-count MAX-COMBINING-MARKS)
                                      (reason "String contains combining mark without base character"))))]
                  
                  [(too-many-combining)
                   (raise (condition (&cbuf-too-many-combining-marks
                                      (operation 'insert-string)
                                      (base-char (cadr first-violation))
                                      (combining-char (caddr first-violation))
                                      (current-count (list-ref first-violation 6))
                                      (max-count MAX-COMBINING-MARKS)
                                      (reason "String contains too many combining marks"))))]))))))]))
  
(define (cbuf-insert-string-internal cbuf str sgr-list)
    "Internal string insertion"
  
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)]
         
         ;; Use text-metrics insertion function
         [new-metrics (text-metrics-insert-string-with-sgr metrics x-index str sgr-list)])
    
    ;; Single atomic update to the metrics
    (cbuf-update-metrics-cur! cbuf new-metrics)
    
    ;; Update cursor and mark positions
    (let ([inserted-chars (string-length str)]
          [inserted-data-positions (count-base-characters str)])
      
      ;; Move mark if necessary
      (when (and (cbuf-mark-set? cbuf)
                 (= (cbuf-mark-line cbuf) (cbuf-line-cur cbuf))
                 (>= (cbuf-mark-x-data cbuf) x-data))
        (set-cbuf-mark-x-data! cbuf (+ (cbuf-mark-x-data cbuf) inserted-data-positions)))
      
      ;; Move cursor to end of inserted text
      (cbuf-set-x! cbuf (+ x-data inserted-data-positions) 'data))))

(define (count-base-characters str)
  "Count non-combining characters in string efficiently"
  (let loop ([i 0] [count 0])
    (if (>= i (string-length str))
        count
        (if (char-combining-mark? (string-ref str i))
            (loop (+ i 1) count)
            (loop (+ i 1) (+ count 1))))))

(define* (cbuf-insert-string-with-current-sgr cbuf str #:key (strict? #t))
  "Insert string using current SGR for all characters."
  (let ([current-sgr (cbuf-current-sgr cbuf)]
        [str-length (string-length str)])
    (if (= str-length 0)
        #f  ; Nothing to insert
        (let ([sgr-list (make-list str-length current-sgr)])
          (cbuf-insert-string-with-sgr cbuf str sgr-list #:strict? strict?)))))

(define (cbuf-insert-string-permissive cbuf str)
  "Insert string without combining mark validation."
  (cbuf-insert-string-with-current-sgr cbuf str #:strict? #f))

(define (cbuf-insert-codepoint-internal cbuf char-new sgr)
    "Internal string insertion"
  
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)]
         
         ;; Use text-metrics insertion function
         [new-metrics (text-metrics-insert-string-with-sgr metrics x-index (string char-new) (list sgr))])
    
    ;; Single atomic update to the metrics
    (cbuf-update-metrics-cur! cbuf new-metrics)
    
    ;; Update cursor and mark positions
    (let ([inserted-chars 1]
          [inserted-data-positions (if (or (char=? char-new #\space)
					   (char-base? char-new))
				       1
				       0)])
      
      ;; Move mark if necessary
      (when (and (cbuf-mark-set? cbuf)
                 (= (cbuf-mark-line cbuf) (cbuf-line-cur cbuf))
                 (>= (cbuf-mark-x-data cbuf) x-data))
        (set-cbuf-mark-x-data! cbuf (+ (cbuf-mark-x-data cbuf) inserted-data-positions)))
      
      ;; Move cursor to end of inserted text
      (cbuf-set-x! cbuf (+ x-data inserted-data-positions) 'data))))

(define* (cbuf-insert-codepoint-with-sgr cbuf char-new sgr #:key (strict? #t))
  "Insert single codepoint - optimized for the single character case."
  
  ;; Save undo state first
  (let ([old-metrics (cbuf-metrics-cur cbuf)])
    (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 
                                      'insert-codepoint-with-sgr char-new sgr))
  
  (cond
   [(not strict?)
    ;; Permissive mode - use efficient single character insertion
    (cbuf-insert-codepoint-internal cbuf char-new sgr)]
   
   [else
    ;; Strict mode - validate then use efficient insertion
    (if (char-combining-mark? char-new)
        ;; Combining mark - need validation
        (let* ([position (cbuf-x-data cbuf)]
               [validation (cbuf-validate-combining-mark-insertion cbuf char-new position)])
          (if (car validation)
              (cbuf-insert-codepoint-internal cbuf char-new sgr)
              (let ([reason (cadddr validation)]
                    [base-char (cadr validation)]
                    [current-count (caddr validation)])
                (case reason
                  [(no-base-character)
                   (raise (condition (&cbuf-invalid-combining-sequence
                                      (operation 'insert-codepoint)
                                      (base-char #f)
                                      (combining-char char-new)
                                      (current-count 0)
                                      (max-count MAX-COMBINING-MARKS)
                                      (reason "Combining mark without base character"))))]
                  
                  [(base-is-combining)
                   (raise (condition (&cbuf-invalid-combining-sequence
                                      (operation 'insert-codepoint)
                                      (base-char base-char)
                                      (combining-char char-new)
                                      (current-count current-count)
                                      (max-count MAX-COMBINING-MARKS)
                                      (reason "Cannot attach combining mark to another combining mark"))))]
                  
                  [(too-many-combining)
                   (raise (condition (&cbuf-too-many-combining-marks
                                      (operation 'insert-codepoint)
                                      (base-char base-char)
                                      (combining-char char-new)
                                      (current-count current-count)
                                      (max-count MAX-COMBINING-MARKS)
                                      (reason "Too many combining marks for base character"))))]))))
        
        ;; Not a combining mark - direct insertion
        (cbuf-insert-codepoint-internal cbuf char-new sgr))]))

(define (cbuf-insert-newline cbuf)
  "Splits the current line into two lines (INL)."
  ;; Save undo state - this inserts 1 line at position y+1
  (cbuf-save-line-insertion-undo! cbuf (+ (cbuf-line-cur cbuf) 1) 1 'insert-newline)
  
  (let* ([txt (cbuf-text-cur cbuf)]
         [x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)]
         [y (cbuf-line-cur cbuf)]
         [metrics-list (cbuf-text-metrics cbuf)]
         [txt1 (substring txt 0 x-index)]
         [txt2 (substring txt x-index)])
    
    ;; Validate both resulting strings
    (validate-combining-mark-limits txt1)
    (validate-combining-mark-limits txt2)
    
    (let* ([metrics1 (compute-text-metrics txt1 (cbuf-tab-size cbuf) #:cjk? (cbuf-cjk? cbuf))]
           [metrics2 (compute-text-metrics txt2 (cbuf-tab-size cbuf) #:cjk? (cbuf-cjk? cbuf))])
      
      ;; Split the lines and metrics using immutable list operations
      (set-cbuf-text-metrics! cbuf (append (take metrics-list y)
                                           (list metrics1 metrics2)
                                           (drop metrics-list (+ y 1))))
      
      ;; Adjust mark if necessary
      (when (cbuf-mark-set? cbuf)
        (cond
         [(> (cbuf-mark-line cbuf) y)
          (set-cbuf-mark-line! cbuf (+ (cbuf-mark-line cbuf) 1))]
         [(and (= (cbuf-mark-line cbuf) y) (>= (cbuf-mark-x-data cbuf) x-data))
          (set-cbuf-mark-line! cbuf (+ y 1))
          (set-cbuf-mark-x-data! cbuf (- (cbuf-mark-x-data cbuf) x-data))]))
      
      ;; Move to beginning of new line
      (set-cbuf-line-cur! cbuf (+ y 1))
      (cbuf-set-x! cbuf 0 'data)
      (set-cbuf-modified?! cbuf #t))))

;;; =================================================================
;;; SGR POSITIONING AND RANGE OPERATIONS (Updated for Immutable)
;;; =================================================================

(define (cbuf-set-sgr-at-cursor cbuf sgr)
  "Set SGR at current cursor position, return updated cbuf"
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)])
    (when x-index
      ;; Save undo state
      (let ([old-metrics (cbuf-metrics-cur cbuf)])
        (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 'set-sgr-at-cursor sgr))
      
      ;; Update with new metrics (functional update)
      (let ([new-metrics (text-metrics-set-sgr-at-index metrics x-index sgr)])
        (cbuf-update-metrics-cur! cbuf new-metrics)))))

(define (cbuf-set-sgr-range cbuf start-data end-data sgr)
  "Set SGR for a range of data positions on current line"
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [start-index (cbuf-x-data->x-index cbuf start-data)]
         [end-index (cbuf-x-data->x-index cbuf end-data)])
    (when (and start-index end-index)
      ;; Save undo state
      (let ([old-metrics (cbuf-metrics-cur cbuf)])
        (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 'set-sgr-range start-data end-data sgr))
      
      ;; Update with new metrics (functional update)
      (let ([new-metrics (text-metrics-set-sgr-range metrics start-index end-index sgr)])
        (cbuf-update-metrics-cur! cbuf new-metrics)))))

(define (cbuf-get-sgr-at-cursor cbuf)
  "Get SGR at current cursor position"
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [x-data (cbuf-x-data cbuf)])
    (text-metrics-get-sgr-at-data metrics x-data)))

;;; =================================================================
;;; SGR-AWARE RENDERING (Updated for Immutable)
;;; =================================================================

(define* (cbuf-render-line-with-sgr cbuf x-cell-start x-width #:key (pad? #t))
  "Render current line with SGR spans"
  (text-metrics-render-line-with-sgr (cbuf-metrics-cur cbuf) 
                                     x-cell-start x-width #:pad? pad?))

(define (cbuf-get-line-sgr-spans cbuf)
  "Get current line as optimized SGR spans"
  (text-metrics-get-rendered-spans (cbuf-metrics-cur cbuf)))

;;; =================================================================
;;; CONVENIENCE FUNCTIONS FOR COMMON SGR OPERATIONS (Updated)
;;; =================================================================

(define (cbuf-set-bold! cbuf)
  "Set current SGR to bold"
  (cbuf-select-graphic-rendition cbuf 'intensity-bold))

(define (cbuf-set-italic! cbuf)
  "Set current SGR to italic"
  (cbuf-select-graphic-rendition cbuf 'font-style-italic))

(define (cbuf-set-foreground-color! cbuf color)
  "Set current SGR foreground color"
  (let ([new-sgr (sgr-copy (cbuf-current-sgr cbuf))])
    (sgr-set-foreground-color! new-sgr color)
    (set-cbuf-current-sgr! cbuf new-sgr)))

(define (cbuf-set-background-color! cbuf color)
  "Set current SGR background color"
  (let ([new-sgr (sgr-copy (cbuf-current-sgr cbuf))])
    (sgr-set-background-color! new-sgr color)
    (set-cbuf-current-sgr! cbuf new-sgr)))

(define (cbuf-apply-sgr-to-selection cbuf sgr)
  "Apply SGR to selected text (between mark and cursor)"
  (when (cbuf-mark-set? cbuf)
    (let* ([mark-line (cbuf-mark-line cbuf)]
           [mark-x-data (cbuf-mark-x-data cbuf)]
           [cursor-line (cbuf-line-cur cbuf)]
           [cursor-x-data (cbuf-x-data cbuf)])
      
      ;; For now, only handle selections on the same line
      (when (= mark-line cursor-line)
        (let ([start-data (min mark-x-data cursor-x-data)]
              [end-data (max mark-x-data cursor-x-data)])
          (cbuf-set-sgr-range cbuf start-data end-data sgr))))))

;;; =================================================================
;;; RANGE PREDICATES
;;; =================================================================

(define (cbuf-can-cursor-up? cbuf n)
  "Return #t if cursor can move up N lines without hitting boundary."
  (>= (- (cbuf-line-cur cbuf) n) 0))

(define (cbuf-can-cursor-down? cbuf n)
  "Return #t if cursor can move down N lines without hitting boundary."
  (< (+ (cbuf-line-cur cbuf) n) (cbuf-line-count cbuf)))

(define (cbuf-can-cursor-forward? cbuf n)
  "Return #t if cursor can move forward N cells without hitting boundary."
  (<= (+ (cbuf-x-cell cbuf) n) (cbuf-text-cur-cell-length cbuf)))

(define (cbuf-can-cursor-backward? cbuf n)
  "Return #t if cursor can move backward N cells without hitting boundary."
  (>= (- (cbuf-x-cell cbuf) n) 0))

(define (cbuf-position-valid? cbuf line column)
  "Return #t if the given line/column position is valid."
  (and (>= line 0)
       (< line (cbuf-line-count cbuf))
       (>= column 0)
       (<= column (text-metrics-cell-length 
                   (list-ref (cbuf-text-metrics cbuf) line)))))

(define (cbuf-at-beginning-of-buffer? cbuf)
  "Return #t if cursor is at beginning of buffer."
  (and (= (cbuf-line-cur cbuf) 0)
       (= (cbuf-x-data cbuf) 0)))

(define (cbuf-at-end-of-buffer? cbuf)
  "Return #t if cursor is at end of buffer."
  (and (= (cbuf-line-cur cbuf) (- (cbuf-line-count cbuf) 1))
       (= (cbuf-x-data cbuf) (cbuf-text-cur-base-length cbuf))))

(define (cbuf-at-beginning-of-line? cbuf)
  "Return #t if cursor is at beginning of line."
  (= (cbuf-x-data cbuf) 0))

(define (cbuf-at-end-of-line? cbuf)
  "Return #t if cursor is at end of line."
  (= (cbuf-x-data cbuf) (cbuf-text-cur-base-length cbuf)))

;;;; Query Functions (return values or #f)

(define (cbuf-cursor-up-range cbuf)
  "Return maximum lines cursor can move up."
  (cbuf-line-cur cbuf))

(define (cbuf-cursor-down-range cbuf)
  "Return maximum lines cursor can move down."
  (- (cbuf-line-count cbuf) (cbuf-line-cur cbuf) 1))

(define (cbuf-cursor-forward-range cbuf)
  "Return maximum cells cursor can move forward."
  (- (cbuf-text-cur-cell-length cbuf) (cbuf-x-cell cbuf)))

(define (cbuf-cursor-backward-range cbuf)
  "Return maximum cells cursor can move backward."
  (cbuf-x-cell cbuf))

(define (cbuf-valid-line-range cbuf)
  "Return (min . max) valid line numbers."
  (cons 0 (- (cbuf-line-count cbuf) 1)))

(define (cbuf-valid-column-range cbuf line)
  "Return (min . max) valid column numbers for given line."
  (if (and (>= line 0) (< line (cbuf-line-count cbuf)))
      (cons 0 (text-metrics-cell-length 
               (list-ref (cbuf-text-metrics cbuf) line)))
      (cons 0 0)))

;;; =================================================================
;;; ECMA-48 CONTROL FUNCTIONS
;;; =================================================================

;;; Cursor movement functions
(define* (cbuf-cursor-up cbuf n #:key (strict? #f))
  "CUU - Move cursor up N lines. If strict?, raise exception when clamping occurs."
  (let* ([current-line (cbuf-line-cur cbuf)]
         [validation (cbuf-validate-line-movement cbuf current-line (- n) 'cursor-up)]
         [target-line (car validation)]
         [clamped-line (cadr validation)]
         [clamped? (caddr validation)]
         [x-goal (cbuf-x-goal cbuf)])
    
    ;; Always perform the movement
    (cbuf-set-y! cbuf clamped-line)
    (cbuf-set-x! cbuf x-goal 'cell)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'cursor-up target-line clamped-line
                                (if (< target-line 0) 'beginning-of-buffer 'end-of-buffer)))))

(define (cbuf-cursor-up-strict cbuf n)
  "Move cursor up N lines, raising exception on any boundary hit."
  (cbuf-cursor-up cbuf n #:strict? #t))

(define* (cbuf-cursor-down cbuf n #:key (strict? #f))
  "CUD - Move cursor down N lines. If strict?, raise exception when clamping occurs."
  (let* ([current-line (cbuf-line-cur cbuf)]
         [validation (cbuf-validate-line-movement cbuf current-line n 'cursor-down)]
         [target-line (car validation)]
         [clamped-line (cadr validation)]
         [clamped? (caddr validation)]
         [x-goal (cbuf-x-goal cbuf)])
    
    ;; Always perform the movement
    (cbuf-set-y! cbuf clamped-line)
    (cbuf-set-x! cbuf x-goal 'cell)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'cursor-down target-line clamped-line
                                (if (>= target-line (cbuf-line-count cbuf)) 'end-of-buffer 'beginning-of-buffer)))))

(define (cbuf-cursor-down-strict cbuf n)
  "Move cursor down N lines, raising exception on any boundary hit."
  (cbuf-cursor-down cbuf n #:strict? #t))

;;; Cursor Movement - Horizontal
(define* (cbuf-cursor-forward cbuf n #:key (strict? #f))
  "CUF - Move cursor forward N cells. If strict?, raise exception when clamping occurs."
  (let* ([current-cell (cbuf-x-cell cbuf)]
         [validation (cbuf-validate-column-movement cbuf current-cell n 'cursor-forward)]
         [target-cell (car validation)]
         [clamped-cell (cadr validation)]
         [clamped? (caddr validation)])
    
    ;; Always perform the movement
    (cbuf-set-x! cbuf clamped-cell 'cell)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'cursor-forward target-cell clamped-cell 'end-of-line))))

(define (cbuf-cursor-forward-strict cbuf n)
  "Move cursor forward N cells, raising exception on any boundary hit."
  (cbuf-cursor-forward cbuf n #:strict? #t))

(define* (cbuf-cursor-backward cbuf n #:key (strict? #f))
  "CUB - Move cursor backward N cells. If strict?, raise exception when clamping occurs."
  (let* ([current-cell (cbuf-x-cell cbuf)]
         [validation (cbuf-validate-column-movement cbuf current-cell (- n) 'cursor-backward)]
         [target-cell (car validation)]
         [clamped-cell (cadr validation)]
         [clamped? (caddr validation)])
    
    ;; Always perform the movement
    (cbuf-set-x! cbuf clamped-cell 'cell)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'cursor-backward target-cell clamped-cell 'beginning-of-line))))

(define (cbuf-cursor-backward-strict cbuf n)
  "Move cursor backward N cells, raising exception on any boundary hit."
  (cbuf-cursor-backward cbuf n #:strict? #t))

(define* (cbuf-cursor-next-line cbuf n #:key (strict? #f))
  "CNL - Move to 1st character position of nth following line."
  (cbuf-cursor-down cbuf n #:strict? strict?)
  (cbuf-set-positions! cbuf 0 'data))

(define (cbuf-cursor-next-line-strict cbuf n)
  "Move to first position of nth following line, raising exception on boundary."
  (cbuf-cursor-next-line cbuf n #:strict? #t))

(define* (cbuf-cursor-preceding-line cbuf n #:key (strict? #f))
  "CPL - Move to 1st character position of nth preceding line."
  (cbuf-cursor-up cbuf n #:strict? strict?)
  (cbuf-set-positions! cbuf 0 'data))

(define (cbuf-cursor-preceding-line-strict cbuf n)
  "Move to first position of nth preceding line, raising exception on boundary."
  (cbuf-cursor-preceding-line cbuf n #:strict? #t))

(define* (cbuf-cursor-character-absolute cbuf n #:key (strict? #f))
  "CHA - Move to character position N in active line. If strict?, raise error when clamping."
  (let* ([max-cell (cbuf-text-cur-cell-length cbuf)]
         [clamped-n (max 0 (min n max-cell))]
         [clamped? (not (= n clamped-n))])
    
    ;; Always perform the positioning
    (cbuf-set-x! cbuf clamped-n 'cell)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'cursor-character-absolute n clamped-n
                                (if (< n 0) 'beginning-of-line 'end-of-line)))))

(define (cbuf-cursor-character-absolute-strict cbuf n)
  "Move to character position N, raising exception on clamping."
  (cbuf-cursor-character-absolute cbuf n #:strict? #t))

(define* (cbuf-cursor-line-absolute cbuf n #:key (strict? #f))
  "VPA - Move to line N, preserving column. If strict?, raise error when clamping."
  (let* ([max-line (- (cbuf-line-count cbuf) 1)]
         [clamped-n (max 0 (min n max-line))]
         [clamped? (not (= n clamped-n))])
    
    ;; Always perform the positioning
    (cbuf-set-y! cbuf clamped-n)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'cursor-line-absolute n clamped-n
                                (if (< n 0) 'beginning-of-buffer 'end-of-buffer)))))

(define (cbuf-cursor-line-absolute-strict cbuf n)
  "Move to line N, raising exception on clamping."
  (cbuf-cursor-line-absolute cbuf n #:strict? #t))

(define* (cbuf-cursor-position cbuf line column #:key (strict? #f))
  "CUP/HVP - Move to absolute position. If strict?, raise error when clamping occurs."
  (let* ([validation (cbuf-validate-absolute-position cbuf line column 'cursor-position)]
         [clamped-line (car validation)]
         [clamped-column (cadr validation)]
         [line-clamped? (caddr validation)]
         [column-clamped? (cadddr validation)])
    
    ;; Always perform the positioning
    (cbuf-set-y! cbuf clamped-line)
    (cbuf-set-x! cbuf clamped-column 'cell)
    
    ;; Conditionally raise after successful operation
    (when strict?
      (cond
       [line-clamped? 
        (cbuf-raise-boundary-error cbuf 'cursor-position line clamped-line
                                  (if (< line 0) 'beginning-of-buffer 'end-of-buffer))]
       [column-clamped?
        (cbuf-raise-boundary-error cbuf 'cursor-position column clamped-column
                                  (if (< column 0) 'beginning-of-line 'end-of-line))]))))

(define (cbuf-cursor-position-strict cbuf line column)
  "Move to absolute position, raising exception on any clamping."
  (cbuf-cursor-position cbuf line column #:strict? #t))

;;; Tab operations
(define* (cbuf-cursor-forward-tabulation cbuf n #:key (strict? #f))
  "CHT - Move to nth following character tabulation stop."
  (let* ([x-cell (cbuf-x-cell cbuf)]
         [tabsize (cbuf-tab-size cbuf)]
         [target-x (cbuf-compute-tab-column x-cell tabsize n)]
         [max-cell (cbuf-text-cur-cell-length cbuf)]
         [clamped-x (max 0 (min target-x max-cell))]
         [clamped? (not (= target-x clamped-x))])
    
    ;; Always perform the movement
    (cbuf-set-x! cbuf clamped-x 'cell)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'cursor-forward-tabulation target-x clamped-x
                                (if (< target-x 0) 'beginning-of-line 'end-of-line)))))

(define (cbuf-cursor-forward-tabulation-strict cbuf n)
  "Move to nth following tab stop, raising exception on boundary."
  (cbuf-cursor-forward-tabulation cbuf n #:strict? #t))

(define* (cbuf-cursor-backward-tabulation cbuf n #:key (strict? #f))
  "CBT - Move to nth preceding character tabulation stop."
  (cbuf-cursor-forward-tabulation cbuf (- n) #:strict? strict?))

(define (cbuf-cursor-backward-tabulation-strict cbuf n)
  "Move to nth preceding tab stop, raising exception on boundary."
  (cbuf-cursor-backward-tabulation cbuf n #:strict? #t))

(define (cbuf-character-tabulation cbuf)
  "HT - Character tabulation (horizontal tab)"
  (cbuf-cursor-forward-tabulation cbuf 1))

;;; Character operations
(define* (cbuf-character-position-forward cbuf n #:key (strict? #f))
  "HPR - Move forward N character positions (data positions)."
  (let* ([current-data (cbuf-x-data cbuf)]
         [max-data (cbuf-text-cur-base-length cbuf)]
         [target-data (+ current-data n)]
         [clamped-data (max 0 (min target-data max-data))]
         [clamped? (not (= target-data clamped-data))])
    
    ;; Always perform the movement
    (cbuf-set-x! cbuf clamped-data 'data)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'character-position-forward target-data clamped-data 'end-of-line))))

(define (cbuf-character-position-forward-strict cbuf n)
  "Move forward N character positions, raising exception on boundary."
  (cbuf-character-position-forward cbuf n #:strict? #t))

(define* (cbuf-character-position-backward cbuf n #:key (strict? #f))
  "HPB - Move backward N character positions (data positions)."
  (let* ([current-data (cbuf-x-data cbuf)]
         [target-data (- current-data n)]
         [clamped-data (max 0 target-data)]
         [clamped? (not (= target-data clamped-data))])
    
    ;; Always perform the movement
    (cbuf-set-x! cbuf clamped-data 'data)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'character-position-backward target-data clamped-data 'beginning-of-line))))

(define (cbuf-character-position-backward-strict cbuf n)
  "Move backward N character positions, raising exception on boundary."
  (cbuf-character-position-backward cbuf n #:strict? #t))

(define* (cbuf-character-position-absolute cbuf n #:key (strict? #f))
  "HPA - Move to character position N in the active line."
  (let* ([max-data (cbuf-text-cur-base-length cbuf)]
         [clamped-n (max 0 (min n max-data))]
         [clamped? (not (= n clamped-n))])
    
    ;; Always perform the positioning
    (cbuf-set-x! cbuf clamped-n 'data)
    
    ;; Conditionally raise after successful operation
    (when (and strict? clamped?)
      (cbuf-raise-boundary-error cbuf 'character-position-absolute n clamped-n
                                (if (< n 0) 'beginning-of-line 'end-of-line)))))

(define (cbuf-character-position-absolute-strict cbuf n)
  "Move to character position N, raising exception on clamping."
  (cbuf-character-position-absolute cbuf n #:strict? #t))

;;; Format effectors
(define (cbuf-backspace cbuf)
  "BS - Move the active data position to the previous data position"
  (cbuf-character-position-backward cbuf 1))

(define (cbuf-carriage-return cbuf)
  "CR - Move to the line home position of the same line"
  (cbuf-set-positions! cbuf (cbuf-home-pos cbuf) (cbuf-limit-type cbuf)))

(define (cbuf-line-feed cbuf)
  "LF - Line feed (shorthand for cursor down 1)"
  (cbuf-cursor-down cbuf 1))

(define (cbuf-reverse-line-feed cbuf)
  "RI - Reverse line feed (shorthand for cursor up 1)"
  (cbuf-cursor-up cbuf 1))

(define (cbuf-next-line cbuf)
  "NEL - Next line. Move to the home position in the next line"
  (cbuf-carriage-return cbuf)
  (cbuf-line-feed cbuf))

(define (cbuf-form-feed cbuf)
  "FF - Form feed. Move to corresponding character position of next page"
  (let* ([y (cbuf-line-cur cbuf)]
         [ps (cbuf-form-size cbuf)]
         [y-on-page (remainder y ps)]
         [y-start-of-next-page (* ps (+ (quotient y ps) 1))])
    (cbuf-cursor-position cbuf (+ y-start-of-next-page y-on-page) 0)))

;;; Bell operations
(define (cbuf-bell cbuf)
  "BEL - Sets the alarm state"
  (set-cbuf-bell?! cbuf #t))

(define (cbuf-clear-bell cbuf)
  "CBL - Clears the alarm state"
  (set-cbuf-bell?! cbuf #f))

;;; Status and configuration
(define (cbuf-device-status-report cbuf device)
  "DSR - Device Status Report"
  (cond
   [(eq? device 'data)
    (cons (cbuf-line-cur cbuf) (cbuf-x-data cbuf))]
   [(eq? device 'presentation)
    (cons (cbuf-line-cur cbuf) (cbuf-x-cell cbuf))]
   [else
    (error "Unknown device" device)]))

(define (cbuf-device-attributes cbuf)
  "DA - Device Attributes. Returns a string identifying this class"
  "Gano CBuf 1.0")

;;; Status queries
(define (cbuf-beginning-of-line? cbuf)
  "Return #t if cursor is at beginning of line"
  (= (cbuf-x-data cbuf) 0))

(define (cbuf-end-of-line? cbuf)
  "Return #t if cursor is at end of line"
  (= (cbuf-x-data cbuf) (cbuf-text-cur-base-length cbuf)))

(define (cbuf-beginning-of-buffer? cbuf)
  "Return #t if cursor is at beginning of buffer"
  (and (= (cbuf-line-cur cbuf) 0)
       (= (cbuf-x-data cbuf) 0)))

(define (cbuf-end-of-buffer? cbuf)
  "Return #t if cursor is at end of buffer"
  (and (= (cbuf-line-cur cbuf) (- (cbuf-line-count cbuf) 1))
       (= (cbuf-x-data cbuf) (cbuf-text-cur-base-length cbuf))))

(define (cbuf-on-first-page? cbuf)
  "Return #t if cursor is on first page"
  (< (cbuf-line-cur cbuf) (cbuf-form-size cbuf)))

(define (cbuf-on-last-page? cbuf)
  "Return #t if cursor is on last page"
  (let* ([y (cbuf-line-cur cbuf)]
         [ps (cbuf-form-size cbuf)]
         [y-on-page (remainder y ps)]
         [y-start-of-next-page (* ps (+ (quotient y ps) 1))])
    (>= (+ y-start-of-next-page y-on-page) (cbuf-line-count cbuf))))

;;; Configuration functions
(define (cbuf-set-line-home! cbuf n)
  "SLH - Set Line Home"
  (set-cbuf-home-pos! cbuf n))

(define (cbuf-set-tab-size! cbuf n)
  "Set tab size and recompute all metrics"
  (set-cbuf-tab-size! cbuf n)
  ;; Recompute all text metrics with new tab size
  (let* ([text-list (cbuf-text cbuf)]
         [cjk? (cbuf-cjk? cbuf)]
         [new-metrics (map (lambda (line)
                             (compute-text-metrics line n #:cjk? cjk?))
                           text-list)])
    (set-cbuf-text-metrics! cbuf new-metrics)
    ;; Update current position
    (cbuf-update-x-cell! cbuf)))

(define (cbuf-set-vert-tab-size! cbuf n)
  "Set vertical tab size"
  (set-cbuf-vert-tab-size! cbuf n))

(define (cbuf-set-form-size! cbuf n)
  "Set form (page) size"
  (set-cbuf-form-size! cbuf n))

(define (cbuf-set-line-ending! cbuf ending)
  "Set line ending style for cbuf"
  (unless (member ending '("\n" "\r\n" "\r" "\u2028"))
    (error "Invalid line ending" ending))
  (set-cbuf-line-ending! cbuf ending))

;;; Mark operations
(define (cbuf-set-mark! cbuf)
  "Set mark at current position"
  (set-cbuf-mark-set?! cbuf #t)
  (set-cbuf-mark-line! cbuf (cbuf-line-cur cbuf))
  (set-cbuf-mark-x-data! cbuf (cbuf-x-data cbuf)))

(define (cbuf-clear-mark! cbuf)
  "Clear the mark"
  (set-cbuf-mark-set?! cbuf #f))

(define (cbuf-goto-mark cbuf)
  "Move cursor to mark position"
  (when (cbuf-mark-set? cbuf)
    (cbuf-set-y! cbuf (cbuf-mark-line cbuf))
    (cbuf-set-x! cbuf (cbuf-mark-x-data cbuf) 'data)))

;;; =================================================================
;;; INSERTION AND DELETION OPERATIONS (Updated for Immutable)
;;; =================================================================

;; Insertion operations
(define (cbuf-insert-character cbuf n)
  "ICH - Insert n space characters at the current position"
  ;; Save undo state before modification
  (let ([old-metrics (cbuf-metrics-cur cbuf)])
    (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 'insert-character n))
  
  (let* ([txt-metrics (cbuf-metrics-cur cbuf)]
         [txt (text-metrics-string txt-metrics)]
         [sgr-list (text-metrics-sgr-list txt-metrics)]
         [x-data (cbuf-x-data cbuf)]
         [x-index (cbuf-x-data->x-index cbuf x-data)]
         [default-sgr (make-default-sgr)])
    
    ;; Handle line limit if set
    (let* ([limit-pos (cbuf-limit-pos cbuf)]
           [limit-type (cbuf-limit-type cbuf)]
           [line-limit (cond
                        [(eq? limit-type 'data) limit-pos]
                        [(eq? limit-type 'presentation)
                         ;; Convert cell limit to approximate data limit
                         (cbuf-x-cell->x-data cbuf limit-pos)]
                        [else #f])]
           [truncated-n (if line-limit
                            (min n (max 0 (- line-limit x-data)))
                            n)]
           [truncated-spaces (make-string truncated-n #\space)]
           [truncated-sgr-list (make-list truncated-n default-sgr)]
           [new-text-full (string-append (substring txt 0 x-index)
                                         truncated-spaces
                                         (substring txt x-index))]
           [new-sgr-list-full (append (take sgr-list x-index)
                                       truncated-sgr-list
                                       (drop sgr-list x-index))])
      
      ;; Handle line limit truncation if needed
      (let* ([final-text (if line-limit
                             (let* ([temp-metrics (compute-text-metrics-with-sgr 
                                                   new-text-full 
                                                   new-sgr-list-full
                                                   (cbuf-tab-size cbuf)
                                                   #:cjk? (cbuf-cjk? cbuf))]
                                    [actual-limit (if (eq? limit-type 'data)
                                                      (min (text-metrics-string-base-length temp-metrics) limit-pos)
                                                      (text-metrics-string-base-length temp-metrics))]
                                    [limit-index (text-metrics-x-data->x-index temp-metrics actual-limit)])
                               (substring new-text-full 0 limit-index))
                             new-text-full)]
             [final-sgr-list (take new-sgr-list-full (string-length final-text))]
             [new-metrics (compute-text-metrics-with-sgr final-text
                                                         final-sgr-list
                                                         (cbuf-tab-size cbuf)
                                                         #:cjk? (cbuf-cjk? cbuf))])
        
        ;; Update the metrics
        (cbuf-update-metrics-cur! cbuf new-metrics)
        
        ;; Adjust mark if necessary
        (when (and (cbuf-mark-set? cbuf)
                   (= (cbuf-mark-line cbuf) (cbuf-line-cur cbuf))
                   (>= (cbuf-mark-x-data cbuf) x-data))
          (set-cbuf-mark-x-data! cbuf (+ (cbuf-mark-x-data cbuf) 
                                         (string-length truncated-spaces))))))))


(define (cbuf-insert-line cbuf n)
  "IL - Insert n blank lines before the current line"
  ;; Save undo state - this inserts n lines at current position
  (cbuf-save-line-insertion-undo! cbuf (cbuf-line-cur cbuf) n 'insert-line)
  
  (let* ([y (cbuf-line-cur cbuf)]
         [metrics-list (cbuf-text-metrics cbuf)]
         [empty-metrics (map (lambda (_) 
                               (compute-text-metrics "" 
                                                     (cbuf-tab-size cbuf) 
                                                     #:cjk? (cbuf-cjk? cbuf)))
                             (iota n))])
    
    ;; Insert the new lines using immutable operations
    (set-cbuf-text-metrics! cbuf (append (take metrics-list y)
                                         empty-metrics
                                         (drop metrics-list y)))
    
    ;; Adjust mark if necessary
    (when (and (cbuf-mark-set? cbuf)
               (>= (cbuf-mark-line cbuf) y))
      (set-cbuf-mark-line! cbuf (+ (cbuf-mark-line cbuf) n)))
    
    ;; Move cursor to home position of first new line
    (cbuf-set-positions! cbuf (cbuf-home-pos cbuf) (cbuf-limit-type cbuf))
    (set-cbuf-modified?! cbuf #t)))

(define* (cbuf-insert-lines cbuf lines #:key (strict? #t))
  "Insert multiple lines."
  (when (not (null? lines))
    ;; Save undo state for multi-line insertion
    (cbuf-save-line-insertion-undo! cbuf (+ (cbuf-line-cur cbuf) 1) (length lines) 'insert-lines)
    
    (cond
     [(not strict?)
      ;; Permissive mode - build metrics and insert
      (cbuf-insert-lines-internal cbuf lines)]
     
     [else
      ;; Strict mode - validate all lines first
      (let ([all-valid? #t]
            [first-violation #f])
        
        ;; Check each line for combining mark violations
        (let loop ([remaining-lines lines])
          (when (and all-valid? (not (null? remaining-lines)))
            (let ([validation (validate-string-combining-marks (car remaining-lines))])
              (if (car validation)
                  (loop (cdr remaining-lines))
                  (begin
                    (set! all-valid? #f)
                    (set! first-violation (caadr validation)))))))
        
        (if all-valid?
            ;; All lines valid - perform insertion
            (cbuf-insert-lines-internal cbuf lines)
            
            ;; Found violation - raise error
            (case (car first-violation)
              [(no-base-character)
               (raise (condition (&cbuf-invalid-combining-sequence
                                  (operation 'insert-lines)
                                  (base-char #f)
                                  (combining-char (cadr first-violation))
                                  (current-count 0)
                                  (max-count MAX-COMBINING-MARKS)
                                  (reason "Lines contain combining mark without base character"))))]
              
              [(too-many-combining)
               (raise (condition (&cbuf-too-many-combining-marks
                                  (operation 'insert-lines)
                                  (base-char (cadr first-violation))
                                  (combining-char (caddr first-violation))
                                  (current-count (list-ref first-violation 6))
                                  (max-count MAX-COMBINING-MARKS)
                                  (reason "Lines contain too many combining marks"))))])))])))

(define (cbuf-insert-lines-internal cbuf lines)
  "Internal multi-line insertion - efficient operation."
  (let* ([y (cbuf-line-cur cbuf)]
         [metrics-list (cbuf-text-metrics cbuf)]
         
         ;; Build all new line metrics in one pass
         [new-line-metrics (map (lambda (line)
                                 (compute-text-metrics line 
                                                       (cbuf-tab-size cbuf) 
                                                       #:cjk? (cbuf-cjk? cbuf)))
                               lines)]
         
         ;; Insert all lines
         [new-metrics-list (append (take metrics-list (+ y 1))
                                   new-line-metrics
                                   (drop metrics-list (+ y 1)))])
    
    (set-cbuf-text-metrics! cbuf new-metrics-list)
    
    ;; Adjust mark if necessary
    (when (and (cbuf-mark-set? cbuf)
               (> (cbuf-mark-line cbuf) y))
      (set-cbuf-mark-line! cbuf (+ (cbuf-mark-line cbuf) (length lines))))
    
    ;; Move cursor to beginning of last inserted line
    (cbuf-set-y! cbuf (+ y (length lines)))
    (cbuf-set-positions! cbuf (cbuf-home-pos cbuf) (cbuf-limit-type cbuf))
    (set-cbuf-modified?! cbuf #t)))

(define (cbuf-delete-character cbuf n)
  "DCH - Delete n grapheme clusters (character positions) from the current position"
  ;; Save undo state before modification
  (let ([old-metrics (cbuf-metrics-cur cbuf)])
    (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 'delete-character n))
  
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [x-data (cbuf-x-data cbuf)]
         [max-data (cbuf-text-cur-base-length cbuf)]
         [clusters-to-delete (min n (- max-data x-data))])
    
    (when (> clusters-to-delete 0)
      ;; Find the string index range for these grapheme clusters
      (let* ([start-data x-data]
             [end-data (+ start-data clusters-to-delete)]
             [start-index (cbuf-x-data->x-index cbuf start-data)]
             [end-index (if (< end-data max-data)
                           (cbuf-x-data->x-index cbuf end-data)
                           (string-length (cbuf-text-cur cbuf)))])
        
        ;; Delete the range using immutable text-metrics deletion
        (let ([new-metrics (text-metrics-delete-range metrics start-index end-index)])
          (cbuf-update-metrics-cur! cbuf new-metrics)
          
          ;; Adjust mark if necessary
          (when (and (cbuf-mark-set? cbuf)
                     (= (cbuf-mark-line cbuf) (cbuf-line-cur cbuf)))
            (cond
             [(< (cbuf-mark-x-data cbuf) start-data)
              ;; Mark before deletion - no change needed
              #f]
             [(<= (cbuf-mark-x-data cbuf) end-data)
              ;; Mark within deleted range - move to deletion start
              (set-cbuf-mark-x-data! cbuf start-data)]
             [else
              ;; Mark after deletion - shift left
              (set-cbuf-mark-x-data! cbuf (- (cbuf-mark-x-data cbuf) clusters-to-delete))]))
          
          ;; Bracket cursor position to ensure it's still valid
          (cbuf-set-x! cbuf (cbuf-bracket-x-data cbuf x-data) 'data))))))

(define (cbuf-delete-preceding-character cbuf n)
  "Delete n grapheme clusters before the cursor (like backspace)"
  (let ([x-data (cbuf-x-data cbuf)])
    (when (> x-data 0)
      (let ([move-count (min n x-data)])
        ;; Move cursor back by the number of clusters we can delete
        (cbuf-set-x! cbuf (- x-data move-count) 'data)
        ;; Delete clusters at new position
        (cbuf-delete-character cbuf move-count)))))

;; Helper function for internal use when you need to delete by string indices
(define (cbuf-delete-range-by-index cbuf start-index end-index)
  "Delete characters by string index range (for internal use)"
  (let ([old-metrics (cbuf-metrics-cur cbuf)])
    (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 
                                      'delete-range-by-index start-index end-index))
  
  (let* ([metrics (cbuf-metrics-cur cbuf)]
         [new-metrics (text-metrics-delete-range metrics start-index end-index)])
    (cbuf-update-metrics-cur! cbuf new-metrics)
    
    ;; Update cursor position - convert from index back to data coordinate
    (let* ([current-x-index (cbuf-x-data->x-index cbuf (cbuf-x-data cbuf))]
           [new-x-index (if (<= current-x-index start-index)
                           current-x-index  ; Cursor before deletion
                           (max start-index (- current-x-index (- end-index start-index))))]
           [new-x-data (cbuf-x-index->x-data cbuf new-x-index)])
      (when new-x-data
        (cbuf-set-x! cbuf new-x-data 'data)))))

;; Line deletion operations
(define (cbuf-delete-line cbuf n)
  "DL - Delete n lines starting from the current line"
  ;; Save undo state with lines that will be deleted
  (let* ([start-line (cbuf-line-cur cbuf)]
         [end-line (min (cbuf-line-count cbuf) (+ start-line n))]
         [deleted-count (- end-line start-line)]
         [deleted-metrics (take (drop (cbuf-text-metrics cbuf) start-line) deleted-count)])
    (cbuf-save-line-deletion-undo! cbuf start-line deleted-metrics 'delete-line n))
  
  (let* ([y (cbuf-line-cur cbuf)]
         [metrics-list (cbuf-text-metrics cbuf)]
         [delete-count (min n (- (length metrics-list) y))])
    
    (when (> delete-count 0)
      ;; Remove the lines using immutable operations
      (let ([new-metrics-list (append (take metrics-list y)
                                      (drop metrics-list (+ y delete-count)))])
        (set-cbuf-text-metrics! cbuf new-metrics-list)
        
        ;; Adjust mark if necessary
        (when (cbuf-mark-set? cbuf)
          (cond
           [(< (cbuf-mark-line cbuf) y)
            ;; Mark before deletion - no change needed
            #f]
           [(<= (cbuf-mark-line cbuf) (+ y delete-count -1))
            ;; Mark within deleted range - clear mark
            (cbuf-clear-mark! cbuf)]
           [else
            ;; Mark after deletion - shift up
            (set-cbuf-mark-line! cbuf (- (cbuf-mark-line cbuf) delete-count))]))
        
        ;; Ensure we have at least one line
        (when (null? (cbuf-text-metrics cbuf))
          (set-cbuf-text-metrics! cbuf (list (compute-text-metrics "" 
                                                                   (cbuf-tab-size cbuf) 
                                                                   #:cjk? (cbuf-cjk? cbuf)))))
        
        ;; Move cursor to home position and bracket line position
        (cbuf-set-y! cbuf (cbuf-bracket-line cbuf y))
        (cbuf-set-positions! cbuf (cbuf-home-pos cbuf) (cbuf-limit-type cbuf))
        (set-cbuf-modified?! cbuf #t)))))

(define (cbuf-delete-newline cbuf)
  "Delete the newline at the end of the current line, joining it with the next line"
  (let ([y (cbuf-line-cur cbuf)]
        [max-y (- (cbuf-line-count cbuf) 1)])
    
    (when (< y max-y)
      ;; Save undo state - this deletes 1 line at position y+1
      (let ([deleted-metrics (list (list-ref (cbuf-text-metrics cbuf) (+ y 1)))])
        (cbuf-save-line-deletion-undo! cbuf (+ y 1) deleted-metrics 'delete-newline))
      
      (let* ([current-metrics (list-ref (cbuf-text-metrics cbuf) y)]
             [next-metrics (list-ref (cbuf-text-metrics cbuf) (+ y 1))]
             [current-text (text-metrics-string current-metrics)]
             [next-text (text-metrics-string next-metrics)]
             [current-sgr-list (text-metrics-sgr-list current-metrics)]
             [next-sgr-list (text-metrics-sgr-list next-metrics)]
             [joined-text (string-append current-text next-text)]
             [joined-sgr-list (append current-sgr-list next-sgr-list)]
             [join-point (string-length current-text)]
             [metrics-list (cbuf-text-metrics cbuf)])
        
        ;; Update current line with joined text and SGR
        (cbuf-update-line! cbuf y joined-text joined-sgr-list)
        
        ;; Remove the next line using immutable operations
        (set-cbuf-text-metrics! cbuf (append (take metrics-list (+ y 1))
                                             (drop metrics-list (+ y 2))))
        
        ;; Adjust mark if necessary
        (when (cbuf-mark-set? cbuf)
          (cond
           [(> (cbuf-mark-line cbuf) (+ y 1))
            ;; Mark after deleted line - shift up
            (set-cbuf-mark-line! cbuf (- (cbuf-mark-line cbuf) 1))]
           [(= (cbuf-mark-line cbuf) (+ y 1))
            ;; Mark on deleted line - move to joined line
            (set-cbuf-mark-line! cbuf y)
            (set-cbuf-mark-x-data! cbuf (+ (cbuf-x-index->x-data cbuf join-point)
                                           (cbuf-mark-x-data cbuf)))]))
        
        ;; Move cursor to join point
        (cbuf-set-x! cbuf (cbuf-x-index->x-data cbuf join-point) 'data)))))


;; Erase operations
(define (cbuf-erase-character cbuf n)
  "ECH - Erase n character positions starting from the cursor"
  ;; Save undo state before modification
  (let ([old-metrics (cbuf-metrics-cur cbuf)])
    (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 'erase-character n))
  
  (let* ([x-cell (cbuf-x-cell cbuf)]
         [max-cell (cbuf-text-cur-cell-length cbuf)]
         [erase-count (min n (- max-cell x-cell))])
    
    (when (> erase-count 0)
      ;; Find the range of characters to replace
      (let* ([start-x-data (cbuf-x-cell->x-data cbuf x-cell)]
             [end-x-cell (+ x-cell erase-count)]
             [end-x-data (cbuf-x-cell->x-data cbuf end-x-cell)]
             [start-index (cbuf-x-data->x-index cbuf start-x-data)]
             [end-index (if end-x-data 
                           (cbuf-x-data->x-index cbuf end-x-data)
                           (string-length (cbuf-text-cur cbuf)))]
             [spaces (make-string erase-count #\space)]
	     [default-sgrs (make-list erase-count (make-default-sgr))]
             [txt (cbuf-text-cur cbuf)]
             [new-text (string-append (substring txt 0 start-index)
                                      spaces
                                      (substring txt end-index))]
	     [sgr-list (cbuf-sgr-list-cur cbuf)]
	     [new-sgr-list (append (take sgr-list start-index)
			      default-sgrs
			      (drop sgr-list end-index))])
			      
        (cbuf-set-text-cur! cbuf new-text new-sgr-list)))))

(define (cbuf-erase-in-line cbuf mode)
  "EL - Erase in line according to mode"
  ;; Save undo state before modification
  (let ([old-metrics (cbuf-metrics-cur cbuf)])
    (cbuf-save-line-modification-undo! cbuf (cbuf-line-cur cbuf) old-metrics 'erase-in-line mode))
  
  (let* ([txt (cbuf-text-cur cbuf)]
         [sgr-list (text-metrics-sgr-list (cbuf-metrics-cur cbuf))]
         [x-cell (cbuf-x-cell cbuf)]
         [default-sgr (make-default-sgr)])
    
    (cond
     [(or (eq? mode 0) (eq? mode 'cursor-to-end))
      ;; Erase from cursor to end of line
      (let* ([start-x-data (cbuf-x-cell->x-data cbuf x-cell)]
             [start-index (cbuf-x-data->x-index cbuf start-x-data)]
             [new-text (substring txt 0 start-index)]
             [new-sgr-list (take sgr-list start-index)])
        (cbuf-set-text-cur! cbuf new-text new-sgr-list))]
     
     [(or (eq? mode 1) (eq? mode 'start-to-cursor))
      ;; Erase from start of line to cursor (inclusive)
      (let* ([end-x-cell (+ x-cell 1)]
             [end-x-data (cbuf-x-cell->x-data cbuf end-x-cell)]
             [end-index (if end-x-data
                           (cbuf-x-data->x-index cbuf end-x-data)
                           (string-length txt))]
             [spaces (make-string x-cell #\space)]
             [space-sgrs (make-list x-cell default-sgr)]
             [new-text (string-append spaces (substring txt end-index))]
             [new-sgr-list (append space-sgrs (drop sgr-list end-index))])
        (cbuf-set-text-cur! cbuf new-text new-sgr-list))]
     
     [(or (eq? mode 2) (eq? mode 'entire-line))
      ;; Erase entire line
      (cbuf-set-text-cur! cbuf "" '())
      ;; Keep cursor at beginning of line
      (cbuf-set-x! cbuf 0 'data)]
     
     [else
      (error "Invalid erase-in-line mode" mode)])))


(define (cbuf-erase-in-buffer cbuf mode)
  "ED - Erase in buffer according to mode"
  (let ([y (cbuf-line-cur cbuf)]
        [line-count (cbuf-line-count cbuf)])
    
    (cond
     [(or (eq? mode 0) (eq? mode 'cursor-to-end))
      ;; Erase current line from cursor to end, then all lines below
      (cbuf-erase-in-line cbuf 'cursor-to-end)
      (when (< (+ y 1) line-count)
        (cbuf-delete-line cbuf (- line-count y 1)))]
     
     [(or (eq? mode 1) (eq? mode 'start-to-cursor))
      ;; Erase all lines above, then current line from start to cursor
      (when (> y 0)
        (let ([old-y y])
          (cbuf-set-y! cbuf 0)
          (cbuf-delete-line cbuf y)
          (cbuf-set-y! cbuf 0)))
      (cbuf-erase-in-line cbuf 'start-to-cursor)]
     
     [(or (eq? mode 2) (eq? mode 'entire-buffer))
      ;; Clear entire buffer
      (let ([empty-metrics (compute-text-metrics "" 
                                                  (cbuf-tab-size cbuf) 
                                                  #:cjk? (cbuf-cjk? cbuf))])
        (set-cbuf-text-metrics! cbuf (list empty-metrics))
        (cbuf-set-y! cbuf 0)
        (cbuf-set-x! cbuf 0 'data)
        (cbuf-clear-mark! cbuf)
        (set-cbuf-modified?! cbuf #t))]
     
     [else
      (error "Invalid erase-in-buffer mode" mode)])))

(define* (cbuf-delete-word-forward cbuf #:optional (word-type 'word))
  "Delete from cursor to end of current word.
   word-type: 'word (default) - punctuation + whitespace delimiters
             'big-word - whitespace-only delimiters"
  (let* ([txt (cbuf-text-cur cbuf)]
         [x-data (cbuf-x-data cbuf)]
         [start-index (cbuf-x-data->x-index cbuf x-data)]
         [len (string-length txt)]
         [delimiter-pred (case word-type
                          [(word) char-word-delimiter?]
                          [(big-word) char-whitespace?]
                          [else char-word-delimiter?])])
    
    ;; Find end of current word
    (let ([end-index (find-word-end-forward txt start-index delimiter-pred)])
      (cond
       [(>= end-index len)
        ;; Delete to end of line
        (cbuf-erase-in-line cbuf 'cursor-to-end)]
       [else
        ;; Delete specific range
        (let* ([end-x-data (cbuf-x-index->x-data cbuf end-index)]
               [delete-count (- end-x-data x-data)])
          (cbuf-delete-character cbuf delete-count))]))))

(define* (cbuf-delete-word-backward cbuf #:optional (word-type 'word))
  "Delete from cursor to beginning of current word.
   word-type: 'word (default) - punctuation + whitespace delimiters
             'big-word - whitespace-only delimiters"
  (let* ([txt (cbuf-text-cur cbuf)]
         [x-data (cbuf-x-data cbuf)]
         [delimiter-pred (case word-type
                          [(word) char-word-delimiter?]
                          [(big-word) char-whitespace?]
                          [else char-word-delimiter?])])
    
    (when (> x-data 0)
      (let* ([start-index (cbuf-x-data->x-index cbuf x-data)]
             [begin-index (find-word-begin-backward txt start-index delimiter-pred)])
        (cond
         [(<= begin-index 0)
          ;; Delete from beginning of line
          (let ([delete-count x-data])
            (cbuf-delete-preceding-character cbuf delete-count))]
         [else
          ;; Delete specific range
          (let* ([begin-x-data (cbuf-x-index->x-data cbuf begin-index)]
                 [delete-count (- x-data begin-x-data)])
            (cbuf-delete-preceding-character cbuf delete-count))])))))

;; Helper functions for word boundary detection
(define (find-word-end-forward txt start-index delimiter-pred)
  "Find the index after the current word ends"
  (let ([len (string-length txt)])
    (cond
     [(>= start-index len) len]
     [else
      ;; Skip current word characters
      (let ([after-word (skip-word-chars-forward txt start-index delimiter-pred)])
        ;; Skip any following whitespace
        (skip-whitespace-forward txt after-word))])))

(define (find-word-begin-backward txt start-index delimiter-pred)
  "Find the index where the current word begins"
  (cond
   [(<= start-index 0) 0]
   [else
    ;; Skip preceding whitespace
    (let ([before-whitespace (skip-whitespace-backward txt (- start-index 1))])
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
     [(< i 0) 0]
     [(delimiter-pred (string-ref txt i)) (+ i 1)]
     [else (loop (- i 1))])))

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

;; Word delimiter predicates
(define (char-word-delimiter? ch)
  "True if character delimits a 'word' (punctuation + whitespace)"
  (or (char-whitespace? ch)
      (char-set-contains? char-set:punctuation ch)
      (char-set-contains? char-set:symbol ch)))

;; Convenience functions for common word types
(define (cbuf-delete-big-word-forward cbuf)
  "Delete forward big-word (whitespace-delimited)"
  (cbuf-delete-word-forward cbuf 'big-word))

(define (cbuf-delete-big-word-backward cbuf)
  "Delete backward big-word (whitespace-delimited)"
  (cbuf-delete-word-backward cbuf 'big-word))


;;; =================================================================
;;; SERIALIZATION FUNCTIONS
;;; =================================================================

;;; SGR TO/FROM JSON CONVERSION
;;; SGR TO/FROM JSON CONVERSION
(define (sgr->json sgr)
  "Convert SGR record to JSON-compatible alist"
  (let ([json-obj '()])
    
    ;; Add non-default attributes
    (unless (eq? (sgr-intensity sgr) 'intensity-normal)
      (set! json-obj (cons `(intensity . ,(symbol->string (sgr-intensity sgr))) json-obj)))
    
    (unless (eq? (sgr-font-style sgr) 'font-style-normal)
      (set! json-obj (cons `(font_style . ,(symbol->string (sgr-font-style sgr))) json-obj)))
    
    (unless (eq? (sgr-underline sgr) 'underline-none)
      (set! json-obj (cons `(underline . ,(symbol->string (sgr-underline sgr))) json-obj)))
    
    (unless (eq? (sgr-blink sgr) 'blink-none)
      (set! json-obj (cons `(blink . ,(symbol->string (sgr-blink sgr))) json-obj)))
    
    (unless (eq? (sgr-polarity sgr) 'polarity-positive)
      (set! json-obj (cons `(polarity . ,(symbol->string (sgr-polarity sgr))) json-obj)))
    
    (unless (eq? (sgr-visibility sgr) 'visibility-revealed)
      (set! json-obj (cons `(visibility . ,(symbol->string (sgr-visibility sgr))) json-obj)))
    
    (unless (eq? (sgr-strikethrough sgr) 'strikethrough-normal)
      (set! json-obj (cons `(strikethrough . ,(symbol->string (sgr-strikethrough sgr))) json-obj)))
    
    (unless (= (sgr-font-family sgr) 0)
      (set! json-obj (cons `(font_family . ,(sgr-font-family sgr)) json-obj)))
    
    (unless (eq? (sgr-frame sgr) 'frame-none)
      (set! json-obj (cons `(frame . ,(symbol->string (sgr-frame sgr))) json-obj)))
    
    (unless (eq? (sgr-overline sgr) 'overline-normal)
      (set! json-obj (cons `(overline . ,(symbol->string (sgr-overline sgr))) json-obj)))
    
    ;; Handle foreground color
    (unless (eq? (sgr-foreground-color sgr) 'color-default)
      (set! json-obj (cons `(foreground_color . ,(color->json (sgr-foreground-color sgr))) json-obj)))
    
    ;; Handle background color
    (unless (eq? (sgr-background-color sgr) 'color-default)
      (set! json-obj (cons `(background_color . ,(color->json (sgr-background-color sgr))) json-obj)))
    
    json-obj))

(define (color->json color)
  "Convert color value to JSON representation"
  (cond
   ;; Standard colors
   [(symbol? color)
    `((type . "standard") (value . ,(symbol->string color)))]
   
   ;; 256-color palette
   [(color-256? color)
    `((type . "256color") (index . ,(color-256-index color)))]
   
   ;; RGB color
   [(color-rgb? color)
    `((type . "rgb") 
      (r . ,(color-rgb-red color))
      (g . ,(color-rgb-green color))
      (b . ,(color-rgb-blue color)))]
   
   [else
    `((type . "standard") (value . "color-default"))]))

(define (json->sgr json-obj)
  "Convert JSON object to SGR record"
  (let ([sgr (make-default-sgr)])
    
    ;; Apply each attribute if present
    (let ([intensity (assq 'intensity json-obj)])
      (when intensity
        (sgr-apply-attribute! sgr (string->symbol (cdr intensity)))))
    
    (let ([font-style (assq 'font_style json-obj)])
      (when font-style
        (sgr-apply-attribute! sgr (string->symbol (cdr font-style)))))
    
    (let ([underline (assq 'underline json-obj)])
      (when underline
        (sgr-apply-attribute! sgr (string->symbol (cdr underline)))))
    
    (let ([blink (assq 'blink json-obj)])
      (when blink
        (sgr-apply-attribute! sgr (string->symbol (cdr blink)))))
    
    (let ([polarity (assq 'polarity json-obj)])
      (when polarity
        (sgr-apply-attribute! sgr (string->symbol (cdr polarity)))))
    
    (let ([visibility (assq 'visibility json-obj)])
      (when visibility
        (sgr-apply-attribute! sgr (string->symbol (cdr visibility)))))
    
    (let ([strikethrough (assq 'strikethrough json-obj)])
      (when strikethrough
        (sgr-apply-attribute! sgr (string->symbol (cdr strikethrough)))))
    
    (let ([font-family (assq 'font_family json-obj)])
      (when font-family
        (set-sgr-font-family! sgr (cdr font-family))))
    
    (let ([frame (assq 'frame json-obj)])
      (when frame
        (sgr-apply-attribute! sgr (string->symbol (cdr frame)))))
    
    (let ([overline (assq 'overline json-obj)])
      (when overline
        (sgr-apply-attribute! sgr (string->symbol (cdr overline)))))
    
    ;; Handle colors
    (let ([fg-color (assq 'foreground_color json-obj)])
      (when fg-color
        (set-sgr-foreground-color! sgr (json->color (cdr fg-color)))))
    
    (let ([bg-color (assq 'background_color json-obj)])
      (when bg-color
        (set-sgr-background-color! sgr (json->color (cdr bg-color)))))
    
    sgr))

(define (json->color color-obj)
  "Convert JSON color object to color value"
  (let ([type (cdr (assq 'type color-obj))])
    (cond
     [(string=? type "standard")
      (string->symbol (cdr (assq 'value color-obj)))]
     
     [(string=? type "256color")
      (make-color-256 (cdr (assq 'index color-obj)))]
     
     [(string=? type "rgb")
      (make-color-rgb (cdr (assq 'r color-obj))
                      (cdr (assq 'g color-obj))
                      (cdr (assq 'b color-obj)))]
     
     [else 'color-default])))

;;; JSON SPAN FORMAT SERIALIZATION
(define (cbuf->json cbuf)
  "Convert cbuf to JSON span format"
  (let* ([lines (cbuf-text cbuf)]
         [metrics-list (cbuf-text-metrics cbuf)]
         [json-lines (map (lambda (line metrics)
                           (line-metrics->json-line line metrics))
                         lines metrics-list)])
    
    `((version . "1.0")
      (format . "spans")
      (lines . ,json-lines)
      (metadata . ((tab_size . ,(cbuf-tab-size cbuf))
                   (vert_tab_size . ,(cbuf-vert-tab-size cbuf))
                   (form_size . ,(cbuf-form-size cbuf))
                   (home_pos . ,(cbuf-home-pos cbuf))
                   (limit_pos . ,(cbuf-limit-pos cbuf))
                   (limit_type . ,(symbol->string (cbuf-limit-type cbuf)))
                   (cjk_mode . ,(cbuf-cjk? cbuf))
                   (line_ending . ,(cbuf-line-ending cbuf))
                   (default_grcm . ,(symbol->string (cbuf-default-grcm cbuf)))
                   (cursor . ((line . ,(cbuf-line-cur cbuf))
                             (data . ,(cbuf-x-data cbuf))
                             (cell . ,(cbuf-x-cell cbuf))
                             (goal . ,(cbuf-x-goal cbuf))))
                   (mark . ,(if (cbuf-mark-set? cbuf)
                               `((set . #t)
                                 (line . ,(cbuf-mark-line cbuf))
                                 (data . ,(cbuf-mark-x-data cbuf)))
                               `((set . #f))))
                   (current_sgr . ,(sgr->json (cbuf-current-sgr cbuf)))
                   (sgr_stack . ,(map sgr->json (cbuf-sgr-stack cbuf)))
                   (modified . ,(cbuf-modified? cbuf))
                   (bell . ,(cbuf-bell? cbuf)))))))

(define (line-metrics->json-line text metrics)
  "Convert a line's text and metrics to JSON line representation"
  (let ([spans (text-metrics-get-rendered-spans metrics)])
    `((text . ,text)
      (spans . ,(map (lambda (span)
                      (let ([span-text (car span)]
                            [span-sgr (cdr span)])
                        `((text . ,span-text)
                          (sgr . ,(sgr->json span-sgr)))))
                    spans)))))

(define (json->cbuf json-obj)
  "Convert JSON span format to cbuf"
  (let* ([version (cdr (assq 'version json-obj))]
         [format (cdr (assq 'format json-obj))]
         [lines (cdr (assq 'lines json-obj))]
         [metadata (cdr (assq 'metadata json-obj))])
    
    ;; Validate format
    (unless (and (string=? version "1.0") (string=? format "spans"))
      (error "Unsupported JSON format" version format))
    
    ;; Extract metadata
    (let* ([tab-size (cdr (assq 'tab_size metadata))]
           [vert-tab-size (cdr (assq 'vert_tab_size metadata))]
           [form-size (cdr (assq 'form_size metadata))]
           [home-pos (cdr (assq 'home_pos metadata))]
           [limit-pos (cdr (assq 'limit_pos metadata))]
           [limit-type (string->symbol (cdr (assq 'limit_type metadata)))]
           [cjk-mode (cdr (assq 'cjk_mode metadata))]
           [line-ending (cdr (assq 'line_ending metadata))]
           [default-grcm (string->symbol (cdr (assq 'default_grcm metadata)))]
           [cursor (cdr (assq 'cursor metadata))]
           [mark (cdr (assq 'mark metadata))]
           [current-sgr-json (cdr (assq 'current_sgr metadata))]
           [sgr-stack-json (cdr (assq 'sgr_stack metadata))]
           [modified (cdr (assq 'modified metadata))]
           [bell (cdr (assq 'bell metadata))])
      
      ;; Reconstruct text-metrics for each line
      (let* ([reconstructed-metrics 
              (map (lambda (line-obj)
                    (json-line->metrics (cdr (assq 'text line-obj))
                                       (cdr (assq 'spans line-obj))
                                       tab-size cjk-mode))
                   lines)]
             [cbuf (%make-cbuf reconstructed-metrics 0 0 0 0
                               tab-size vert-tab-size form-size 
                               home-pos limit-pos limit-type
                               cjk-mode modified #f 0 0 bell #f '()
                               (json->sgr current-sgr-json)
                               default-grcm
                               (map json->sgr sgr-stack-json)
                               line-ending)])
        
        ;; Set cursor position
        (let ([cursor-line (cdr (assq 'line cursor))]
              [cursor-data (cdr (assq 'data cursor))]
              [cursor-cell (cdr (assq 'cell cursor))]
              [cursor-goal (cdr (assq 'goal cursor))])
          (set-cbuf-line-cur! cbuf (cbuf-bracket-line cbuf cursor-line))
          (set-cbuf-x-data! cbuf (cbuf-bracket-x-data cbuf cursor-data))
          (set-cbuf-x-cell! cbuf cursor-cell)
          (set-cbuf-x-goal! cbuf cursor-goal))
        
        ;; Set mark if present
        (when (cdr (assq 'set mark))
          (set-cbuf-mark-set?! cbuf #t)
          (set-cbuf-mark-line! cbuf (cbuf-bracket-line cbuf (cdr (assq 'line mark))))
          (set-cbuf-mark-x-data! cbuf (cdr (assq 'data mark))))
        
        cbuf))))

(define (json-line->metrics text spans tab-size cjk-mode)
  "Reconstruct text-metrics from JSON line representation"
  (if (null? spans)
      ;; Empty line
      (compute-text-metrics text tab-size #:cjk? cjk-mode)
      
      ;; Reconstruct SGR list from spans
      (let ([sgr-list '()]
            [text-pos 0])
        
        ;; Process each span
        (for-each (lambda (span-obj)
                   (let ([span-text (cdr (assq 'text span-obj))]
                         [span-sgr-json (cdr (assq 'sgr span-obj))])
                     (let ([span-sgr (json->sgr span-sgr-json)]
                           [span-length (string-length span-text)])
                       ;; Add SGR for each character in span
                       (set! sgr-list (append sgr-list 
                                             (make-list span-length span-sgr)))
                       (set! text-pos (+ text-pos span-length)))))
                 spans)
        
        ;; Create text-metrics with reconstructed SGR list
        (compute-text-metrics-with-sgr text sgr-list tab-size #:cjk? cjk-mode))))

;;; TEXT FORMAT SERIALIZATION (working implementations)
(define (cbuf->text cbuf)
  "Convert cbuf to plain text using configured line endings"
  (let ([lines (cbuf-text cbuf)]
        [line-ending (cbuf-line-ending cbuf)])
    (string-join lines line-ending)))


(define* (text->cbuf text #:key (tab-size 8) (vert-tab-size 6) (form-size 66)
                     (cjk? #f) (default-grcm 'replacing) (line-ending "\n")
                     (strict? #t))
  "Convert plain text to cbuf with efficient validation and construction."
  
  (cond
   [(not strict?)
    ;; Permissive mode - build directly without validation
    (text->cbuf-internal text tab-size vert-tab-size form-size cjk? default-grcm line-ending)]
   
   [else
    ;; Strict mode - validate entire text efficiently, then build
    (let ([validation (validate-string-combining-marks text)])
      (if (car validation)
          ;; Text is valid - build normally
          (text->cbuf-internal text tab-size vert-tab-size form-size cjk? default-grcm line-ending)
          
          ;; Text has violations - raise error with first violation
          (let ([violations (cadr validation)])
            (when (not (null? violations))
              (let ([first-violation (car violations)])
                (case (car first-violation)
                  [(no-base-character)
                   (raise (condition (&cbuf-invalid-combining-sequence
                                      (operation 'text->cbuf)
                                      (base-char #f)
                                      (combining-char (cadr first-violation))
                                      (current-count 0)
                                      (max-count MAX-COMBINING-MARKS)
                                      (reason "Input text contains combining mark without base character"))))]
                  
                  [(too-many-combining)
                   (raise (condition (&cbuf-too-many-combining-marks
                                      (operation 'text->cbuf)
                                      (base-char (cadr first-violation))
                                      (combining-char (caddr first-violation))
                                      (current-count (list-ref first-violation 6))
                                      (max-count MAX-COMBINING-MARKS)
                                      (reason "Input text contains too many combining marks"))))]))))))]))

(define (text->cbuf-internal text tab-size vert-tab-size form-size cjk? default-grcm line-ending)
  "Internal text->cbuf implementation without validation."
  (let* ([detected-ending (if (string=? line-ending "\n")
                             (detect-line-ending text)
                             line-ending)]
         [lines (cond
		 ;; FIXME: handle CRLF
                 [(string-contains text "\r\n") (string-split text #\newline)]
                 [(string-contains text "\r") (string-split text #\return)]
                 [(string-contains text "\n") (string-split text #\newline)]
                 [(string-contains text "\u2028") (string-split text '\u2028')]
                 [else (list text)])]
         
         ;; Build all metrics in one pass
         [metrics (map (lambda (line) 
                        (compute-text-metrics line tab-size #:cjk? cjk?))
                      lines)])
    
    (%make-cbuf metrics 0 0 0 0 
               tab-size vert-tab-size form-size 0 79 'data
               cjk? #f #f 0 0 #f #f '()
               (make-default-sgr)
               default-grcm
               '()
               detected-ending)))

(define (detect-line-ending text)
  "Detect line ending type in text"
  (cond
   [(string-contains text "\r\n") "\r\n"]     ; Windows
   [(string-contains text "\r") "\r"]         ; Classic Mac
   [(string-contains text "\u2028") "\u2028"] ; Unicode Line Separator
   [else "\n"]))                              ; Unix/Linux (default)

;;; CONVENIENCE FUNCTIONS (placeholders)
(define (cbuf-save-json cbuf filename)
  "Save cbuf to JSON file (placeholder)"
  (call-with-output-file filename
    (lambda (port)
      (write (cbuf->json cbuf) port))))

(define (cbuf-load-json filename)
  "Load cbuf from JSON file (placeholder)"
  (call-with-input-file filename
    (lambda (port)
      (json->cbuf (read port)))))

(define (cbuf-save-text cbuf filename)
  "Save cbuf to plain text file"
  (call-with-output-file filename
    (lambda (port)
      (display (cbuf->text cbuf) port))))

(define (cbuf-load-text filename . args)
  "Load cbuf from plain text file"
  (call-with-input-file filename
    (lambda (port)
      (let ([text (get-string-all port)])
        (apply text->cbuf text args)))))
        
