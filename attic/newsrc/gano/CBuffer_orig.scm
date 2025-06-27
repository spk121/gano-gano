;;; CBuffer

#|

A CBuffer is a data model for lines of plain text.  It can be
conceived as a list of strings, where the first element of the list is
a string that contains the first line of text, and so on.

The strings stored in a CBuffer must only consist of printable characters.
No format effectors or presentation control functions are stored.
The lone exception is the horizontal tab character.

The strings stored in CBuffers do not explicitly store line
terminations, like newline or carriage return.  A line termination is
implicitly assumed to exist for each line in the buffer.


A CBuffer consists of 
- the text.
- an active line and position. This active location is a special address
  that is used in the command set.  It is the location of a virtual cursor.
- a mark line and position,  This mark location is a special address that
  is used in the command set.
- a list of bookmarks that assign names to locations in the text file.
- an operations list.  This is a list of all the operations that have
  modified the buffer. This allows for the implementation of undo and redo
  commands.

The Mark

The mark is often set to assign a range of text.  It may represent one
extrema of a range of text upon which a command may operate, which the
active position representing the other extrema.

Usually any action that modifies the text of the buffer will clear the
mark.

Bookmarks.

A bookmark is a name for a position in a text file.  Unlike the mark,
which is cleared on any operation that modifies text, bookmarks are
persistent.  A bookmark will only be cleared when explicitely requested
or when the character location to which they are attached is deleted.
Since bookmarks are attached to locations in the text, they will
move as text is inserted and deleted.


|#



(define-module (gano CBuffer)
  ;; #:use-module (gano config)
  #:use-module (oop goops)
  #:use-module (oop goops describe)
  ;; #:use-module (gano chars)
  ;; #:use-module (gano utils)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 pretty-print)
  #:use-module (rnrs control)
  #:use-module ((ncurses extra) #:select (wcwidth))
  #:export (
            <CBuffer>
	    ;; Constructors
	    make-empty-cbuffer

	    ;; TTY Operators
	    write-character
	    write-substitute-glyph
	    backspace			; BS
	    line-feed			; LF
	    carriage-return		; CR
	    set-line-home		; SLH
	    set-line-limit		; SLL
	    set-invalid-movement-mode!

	    ;; Operations inspired by POSIX ED
	    ed-insert-lines-after
	    ed-insert-lines-before
	    ed-replace-lines
	    ed-delete-all
	    ed-regex-search-forward-line
	    ed-join-lines
	    ed-move-lines
	    ed-copy-lines
	    
	    ;; ECMA-48 primitives
	    bell			; BEL
	    bell?
	    clear-bell
	    
            backspace			; BS
            cursor-backward-tabulation	; CBT
            cursor-character-absolute	; CHA
            cursor-forward-tabulation	; CHT
	    cursor-next-line		; CNL
            cursor-preceding-line	; CPL
            carriage-return		; CR
	    cursor-tabulation-control 	; CTC
            cursor-left			; CUB
            cursor-down			; CUD
	    cursor-right		; CUF
            cursor-position 		; CUP
            cursor-up			; CUU
	    cursor-line-tabulation	; CVT
	    device-attributes		; DA
	    delete-character		; DCH
	    delete-line 		; DL
	    erase-character		; ECH
	    erase-in-line		; EL
	    center-frame-line
	    center-frame-position
            character-position-absolute
            character-position-backward
            character-position-forward
            character-and-line-position
	    device-status-report	; DSR
	    insert-character-space
            insert-line
	    insert-nel
	    is-position-in-frame?
            line-position-absolute
            line-position-backward
            line-position-forward
	    move-frame-line
	    render-frame
            scroll-down
            scroll-up
            write-character
            write-tabulation

	    get-line-count
            get-line-cur
	    get-line-frame
	    get-line-frame-size
            get-pd-cur
            get-pp-cur
            get-pp-from-pd-cur
            get-pp-goal
	    get-text-cur
            get-text-cur-length
	    get-line-text
            increase-pd-cur!
	    is-modified?
            render-line
	    set-file-name!
            set-line-cur!
            set-line-frame!
            set-line-frame-size!
            set-pd-cur!
	    set-pd-goal!
            set-positions!
            set-pp-cur!
            set-pp-frame!
            set-pp-frame-size!
            set-pp-goal!
            set-tab-size!
            set-text!
            set-text-cur!
            update-pp-list!

            ))


(define-class <CBuffer> ()
  ;; The file
  (m_fileName #:init-value "" #:setter set-file-name!)
  (m_fileFormat #:init-value 'nix)
  (m_fModified #:init-value #f #:getter is-modified?)

  ;; The text
  ;; A list of strings
  (m_rgText #:init-value '("") #:getter get-text #:setter set-text!)
  ;; A list of the presentation positions of the characters of the current line
  (m_rgPpList #:init-value '() #:getter get-pp-list #:setter set-pp-list!)
  ;; The current line number
  (m_LCur #:init-value 0 #:getter get-line-cur #:setter %set-line-cur!)
  ;; The current data position
  (m_PdCur #:init-value 0 #:getter get-pd-cur #:setter %set-pd-cur!)
  ;; The current presentation position
  (m_PpCur #:init-value 0 #:getter get-pp-cur #:setter set-pp-cur!)
  ;; The desired presentation position
  (m_PpGoal #:init-value 0 #:getter get-pp-goal #:setter set-pp-goal!)
  ;; The number of spaces per between tab stops
  (m_tabSize #:init-value 8 #:getter get-tab-size #:setter set-tab-size!)
  ;; The number of lines per vertical tab stops
  (m_vertTabSize #:init-value 6 #:getter get-vert-tab-size #:setter set-vert-tab-size!)

  ;; Home and Limit
  (m_PHome #:init-value 0 #:getter get-home-pos #:setter set-home-pos!)
  (m_HomeType #:init-value 'data #:getter get-home-type #:setter set-home-type!)
  (m_PLimit #:init-value 1024 #:getter get-limit-pos #:setter set-limit-pos!)
  (m_LimitType #:init-value 'data #:getter get-limit-type #:setter set-limit-type!) 
  (m_pageHome #:init-value 0 #:getter get-page-home-line #:setter set-page-home-line!)

  ;; The mark
  (m_fMarkSet #:init-value #f #:getter is-mark-set? #:setter set-mark-flag!)
  (m_LMark #:init-value 0 #:getter get-line-mark #:setter set-line-mark!)
  (m_PdMark #:init-value 0 #:getter get-pd-mark #:setter set-pd-mark!)

  ;; The Frame
  (m_LFrame #:init-value 0 #:getter get-line-frame #:setter set-line-frame!)
  (m_PpFrame #:init-value 0 #:getter get-pp-frame #:setter set-pp-frame!)
  (m_LFrameSize #:init-value 25 #:getter get-line-frame-size #:setter set-line-frame-size!)
  (m_PpFrameSize #:init-value 80 #:getter get-pp-frame-size #:setter set-pp-frame-size!)

  ;; Other 
  (m_Bel #:init-value #f #:getter get-bell #:setter set-bell!)

  ;;(m_totalSize #:init-value 0)

  ;;(m_statCur #:init-value #f)
  ;;(m_undo #:init-value '()))
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CONSTRUCTORS

(define (make-empty-cbuffer)
  (let ((CB (make <CBuffer>)))
    (update-pp-list! CB)
    CB))

;;;;;;;;;;;;;;;;;;;;;;;;;
;; PRIMITIVES

;; RULES FOR PRIMITIVES

;; 0. Primitives may only call getters/setters or primitives.

;; 1. If the active data line is changed, the pp-list must immediately
;; be updated. The goal column stays the same.  The active
;; presentation is set to the beginning of the character at the goal
;; column, or, if the goal column is after the last presentation
;; position in the line, the active presentation position is set to
;; the end of the line.  Then the active data position is set to match
;; the presentation position.

;; 2. If the active data position is changed, the active presentation
;; position is changed to match, and the goal column is set to the active
;; presentation position.

;; Any primitive that could result in the above rules being violated
;; or that could throw an error must begin with '%' to mark it as
;; dangerous.

;; Pp - a presentation position in a line
;; PpCur - The active presentation position
;; PpStart - The presentation position of the 1st character.
;; Pd - a data position in line
;; PdCur - The active data position
;; PdLim - The last data position in a line or string
;; Str - a string
;; Char - a character

(define (compute-pp-list-from-string str PpStart tabsize)
  "Computes a list of the locations of the presentation positions of
the beginning of each character in a string.  For the purposes of
horizontal tabs, it assumes that the string begins on column PpStart."
  (let loop ([Pp PpStart] [lst '()] [str str])
    (cond
     [(not (string-null? str))
      (loop (+ Pp (count-cells-in-char (string-ref str 0) Pp tabsize))
            (append lst (list Pp))
            (string-drop str 1))]
     [else
      ;; return list
      (append lst (list pp))])))

(define (count-cells-in-char Char Pp tabSize)
  "Number of cells a character Char occupies. Usually 0, 1, or 2.
The current presentation position Pp and the tab size are used to
figure out how many spaces a horizontal tab character occupies."
  (cond
   [(eqv? Char #\nul)
    0]
   [(eqv? Char #\tab)
    (- tabSize (modulo Pp tabSize))]
   [(is-control-char? Char)
    ;; Add 1 for the caret '^'
    (1+ (wcwidth (get-display-char-from-control-char Char)))]
   [else
    (wcwidth Char)]))

(define (count-cells-in-string str PpStart tabsize)
  "Number of screen cells occupied by the characters in a string,
given that the 1st character of the string has the presentation
position PpStart, and given a tabsize."
  (let ([PdLim (string-length str)]
        [Pp PpStart])
    (do ([i 0 (1+ i)]) ([>= i PdLim])
      (set! Pp (+ Pp (count-cells-in-char (string-ref str i) Pp tabsize))))
    (- Pp PpStart)))

(define (count-cells-in-substring str n PpStart tabsize)
  "Return the number of screen cells occupied by the first N
characters of a string, assuming that the first string character is a
the presentation position PpStart with a given TABSIZE"
  (count-cells-in-string (substring str 0 n) PpStart tabsize))

(define (get-display-char-from-control-char c)
  "The character to use when displaying controls in \"^X\" form"
  (integer->char (+ (char->integer c) 64)))

(define (is-control-char? c)
  "#t if this is an ISO control character"
  (char-set-contains? char-set:iso-control c))

(define-method (bracket-line (buf <CBuffer>) L)
  "Return L if it is a valid line number for the current buffer, or
the nearest valid line number of L is out of range."
  (max 0
       (min L
	    (1- (get-line-count buf)))))

(define-method (bracket-pd (buf <CBuffer>) pd)
  "Return pd if it is valid data position for the active line, or the
nearest valid data position for the active line if pd is out of
range."
  (max 0 
       (min pd 
	    (get-text-cur-length buf))))

(define-method (get-line-count (buf <CBuffer>))
  "Return the number of lines in the buffer"
  (length (get-text buf)))

;; FIXME: don't use this because Pp and Pd should be synchronized
(define-method (get-pp-from-pd-cur (buf <CBuffer>))
  "Find the presentation position of the active data position for the
current line."
  (count-cells-in-substring (get-text-cur buf) (get-pd-cur buf) 0 (get-tab-size buf)))

(define-method (get-pp-max (buf <CBuffer>))
  (last (get-pp-list buf)))

(define-method (get-text-cur (buf <CBuffer>))
  "Return the text of the active line"
  (list-ref (get-text buf) (get-line-cur buf)))

(define-method (get-line-text (buf <CBuffer>) n)
  "Return the text of line N"
  (if (= n (bracket-line buf n))
      (list-ref (get-text buf) n)
      ""))

(define-method (get-text-cur-length (buf <CBuffer>))
  "Return the number of codepoints in the active line"
  (string-length (get-text-cur buf)))

(define-method (%update-pp-cur! (buf <CBuffer>))
  "Sets the active presentation position to the match the beginning
of the character at the active data position"
  (%set-pp-cur! buf (list-ref (get-pp-list buf) (get-pd-cur buf))))

(define-method (set-positions! (buf <CBuffer>) n device)
  "When device is 'data, set the active data position to N and the
active presentation position and presentation position goal to the
beginning of grapheme at data position N.  When device is
'presentation, set the presentation position goal to N, the active
presentation position to the beginning of the grapheme at presentation
position N, and the active data position to the data position of that
grapheme."
  (cond
   [(eq? device 'data)
    (set-pd-cur! buf n)]
   [(eq? device 'presentation)
    (set-pp-cur! buf n)]))

(define-method (set-pd-cur! (buf <CBuffer>) Pd)
  "Moves the active data position to Pd.  The data position is
bracketed so that it is valid position.  The presentation position and
goal column are synchronized.

It returns the active data position, which may be different from the
parameter Pd if that value is less than zero or greater than the
length of the active line."
  (%set-pd-cur! buf (bracket-pd buf Pd))
  (%update-pp-cur! buf)
  (%set-pp-goal! buf (get-pp-cur buf))
  (get-pd-cur buf))

(define-method (set-pd-to-eol! (buf <CBuffer>))
  "Sets the active data position to the end of the current line.
Updates the presentation position list. Sets the active
presentation position and the goal column to the end of the
active data line."
    (set-pd-cur! buf (string-length (get-text-cur buf))))


(define-method (increase-pd-cur! (buf <CBuffer>) n)
  "Moves the active data position N characters to the right, if N is
positive, or N characters to the left, if N is negative.  The data
position is bracketed so that it is valid.  The presentation position
and goal column are syncronized.

It returns the actual number of positions moved, which may be
different from the expected value if N would have moved the data
position before the beginning or past the end of the line."
  (let* ((LStart (get-line-cur buf))
	 (LEnd (set-pd-cur! buf (+ n (get-pd-cur buf)))))
    (- LEnd LStart)))

(define-method (set-pp-cur! (buf <CBuffer>) Pp)
  "Sets set the presentation position goal column to Pp, the active
presentation position to the beginning of the grapheme at presentation
position Pp, and the active data position to the data position of that
grapheme.

It returns the active presentation position, which may be different
from the Pp parameter."
  (%set-pp-goal! buf Pp)
  (let ([ind (list-index (lambda (x) (> x Pp)) (get-pp-list buf))])
    (if ind
	(%set-pd-cur! buf (max 0 (1- ind)))
	;; else
	(%set-pd-cur! buf (last (get-pp-list buf)))))
  (%update-pp-cur! buf)
  (get-pp-cur buf))

(define-method (set-line-cur! (buf <CBuffer>) L)
  "Sets the active data line to L. The line number is bracketed to a
valid value.

Without changing the goal column, the active presentation position is
set to the beginning of the grapheme at the goal column, or to the end
of the line if the goal column is past the end of the line.  The
active data position is set to the data position of the grapheme
located at the active presentation position.

It returns the active data line, which may be different from the L
parameter."
  (%set-line-cur! buf (bracket-line buf L))
  (update-pp-list! buf)
  (let ((goal (get-pp-goal buf)))
    (set-pp-cur! buf goal)
    (%set-pp-goal! buf goal))
  (get-line-cur buf))
    
(define-method (increase-line-cur! (buf <CBuffer>) n)
  "Sets the active data line down N lines, if N is positive,
or up N lines, if N is negative.  The line number is bracketed
to a valid value.

Without changing the goal column, the active presentation position is
set to the beginning of the grapheme at the goal column, or to the end
of the line if the goal column is past the end of the line.  The
active data position is set to the data position of the grapheme
located at the active presentation position.

It returns the actual number of lines moved, which may be different
from the N parameter."
  (let* ((LStart (get-line cur buf))
	 (LEnd (set-line-cur! buf (+ (get-line-cur buf) n))))
    (- LEnd LStart)))

(define-method (set-text-cur! (buf <CBuffer>) str)
  "Sets the text of the current line to STR.

Without changing the goal column, the active presentation position is
set to the beginning of the grapheme at the goal column, or to the
end of the line if the goal column is past the end of the line.  The 
active data position is set to the data position of the grapheme located at
the active presentation position.

All bookmarks in the current line are removed, except those at the beginning
of the line.

The mark is unset.

The return value is unspecified."
  (list-set! (get-text buf) (get-line-cur buf) str)
  (let ((PpGoal (get-pp-goal buf)))
    (set-pp-cur! buf goal)
    (%set-pp-goal! buf goal))
  (set-mark-flag! buf #f)
    
    *unspecified*))

(define-method (set-text! (buf <CBuffer>) strlist)
  "Sets the text of the current buffer to strlist.

If the active line would now be beyond the end of the buffer, it is
set to the last line in the buffer, and the active data position is
set to the end of that line.  The goal column is adjusted.

Otherwise, without changing the goal column, the active presentation
position is set to the beginning of the grapheme at the goal column,
or to the end of the line if the goal column is past the end of the
line.  The active data position is set to the data position of the
grapheme located at the active presentation position.

All bookmarks are removed.

The mark is unset.

The return value is unspecified."
  (%set-text! buf strlist)
  (let ((LLim (get-line-count buf))
	(LCur (get-line-cur buf)))
    (if (>= LCur LLim)
	(begin
	  (set-line-cur! buf (bracket-lines (1- LLim)))
	  (set-pd-to-eol! buf))
	;; else
	(let ((PpGoal (get-pp-goal buf)))
	  (set-pp-cur! buf goal)
	  (%set-pp-goal! buf goal))))
  (%set-mark-flag! buf #f)
  *unspecified*)


(define (render-line str tabsize pp-start pp-length)
  "Return the substring of str constrained by the presentation columns.
Tabs are converted to spaces, and characters that would be clipped by
the edges are replaced with spaces."
  (let* ([pp-end (+ pp-start pp-length)]
	 [pp-list (compute-pp-list-from-string str tabsize)]
	 ;; The index of the first character past the start of the window
	 [i-start (list-index (lambda (x) (>= x pp-start)) pp-list)]
	 ;; The index of the first character past endthe window
	 [i-end (list-index (lambda (x) (> x pp-end)) pp-list)]
	 ;; The number of left-side spaces needed
	 [left-padding (min pp-length
			    (if i-start
				(- (list-ref pp-list i-start) pp-start)
				pp-length))]
	 ;; #t if the last character straddles the frame
	 [truncated-p (and i-end (> (list-ref pp-list i-end) pp-end))]
	 ;; The number of cells that the windowed string occupies
	 [str-pp-size (cond
		       [(and (not i-start) (not i-end))
			;; window starts after string
			0]
		       [(and i-start (not i-end))
			;; string starts in window and ends before window
			(- (last pp-list) (list-ref pp-list i-start))]
		       [(= i-start i-end)
			;; string starts after window
			0]
		       [(and (= i-start (1- i-end))
			     truncated-p)
			;; the only character is truncated
			0]
		       [else
			;; the normal case
			(if truncated-p
			    (- (list-ref pp-list (1- i-end))
			       (list-ref pp-list i-start))
			    ;; else
			    (- (list-ref pp-list i-end)
			       (list-ref pp-list i-start)))])]
	 [right-padding (- pp-length (+ left-padding str-pp-size))])
			
    (format (current-error-port) "~s ~s ~s~%" left-padding str-pp-size right-padding)
    (string-append
     ;; Space padding for initial truncated characters
     (make-string left-padding #\space)
     ;; Main list
     (cond
      [(not i-start)
       ""]
      [i-start
       (let ([inner-str ""])
	 (do ([i i-start (1+ i)]) ([>= i (1- (or i-end (length pp-list)))])
	   (if (char=? #\tab (string-ref str i))
	       (set! inner-str (string-append inner-str (make-string (- (list-ref pp-list (1+ i)) (list-ref pp-list i)) #\space)))
	       (set! inner-str (string-append inner-str (string (string-ref str i))))))
	 inner-str)])
     ;; End of line space padding
     (make-string right-padding #\space))))



(define-method (synchronize-pp! (buf <CBuffer>))
  "Set the presentation position goal to the active presentation
position"
  (set-pp-goal! buf (get-pp-cur buf)))

(define (compute-tab-column pos tabsize n)
  "If N is positive, compute the presentation position of the nth next
forward tabulation.  If N is negative, compute the position of the
backward tabulation.  This function does not do bracketing."
  (cond
   [(< n 0)
    ;; Back up n tabsizes
    (let* ([pp1 (+ pos (* n tabsize))]
	   ;; Move forward to a tab stop
	   [pp2 (cond 
		 [(zero? (remainder pp1 tabsize))
		  pp1]
		 [(> pp1 0)
		  (* tabsize (1+ (quotient pp1 tabsize)))]
		 [(< pp1 0)
		  (* tabsize (quotient pp1 tabsize))])])
      pp2)]
   [(= n 0)
    pos]
   [(> n 0)
    ;; Advance n tabsizes
    (let* ([pp1 (+ pos (* n tabsize))]
           ;; Move backward to a tab stop
           [pp2 (* tabsize (quotient pp1 tabsize))])
      (format (current-error-port) "~a!!!~%" pp2)
      pp2)]))


(define-method (update-pp-list! (buf <CBuffer>))
  (set-pp-list! buf 
		(compute-pp-list-from-string (get-text-cur buf) 
					     (get-tab-size buf))))




(define-method (move-mark-down-if-after! (buf <CBuffer>) lineno n)
  ;; Move the mark down, if necessary
  (when (and (is-mark-set? buf)
	     (>= (get-line-mark buf) lineno))
    (set-line-mark! buf (+ (get-line-mark buf) n))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; QUERIES

(define-method (bell? (buf <CBuffer>))
  "Has there been a call for attention?" 
  (get-bell buf))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; OPERATIONS inspired by POSIX ED

;; INSERT-LINES-AFTER

;; Given a list of strings, this inserts the strings into BUF after
;; the line LINENO, or, if LINENO is not specified, after the line in
;; which the active data position is located.  The active data
;; position is moved to the end of the last inserted line.  If strlist
;; is an empty list, no lines are inserted and the active data
;; position is moved the end of line LINENO."

(define-method (op-insert-lines-after (buf <CBuffer>) strlist lineno)
  ('insert-lines-after
   strlist				; strings to insert
   lineno				; line number to insert after
   (get-line-cur buf)			; current line
   (get-pd-cur buf)			; current position
   (get-pp-goal buf)))			; current goal column

(define-method (apply-op-insert-lines-after (buf <CBuffer>) op)
  (let* ((strlist (second op))
	 (strlistlen (length strlist))
	 (lineno (third op)))
    ;; Append the text after line LINENO.
    (set-text! buf (append (take txt lineno)
			   strlist
			   (drop txt linenoo)))
    (increase-line-cur-using-goal! buf strlistlen)
    (set-pd-and-goal-to-eol! buf)
    (move-mark-down-if-after! buf lineno strlistlen)))

(define-method (undo-op-insert-lines-after (buf <CBuffer>) op)
  (let ((txt (get-text buf))
	(nLines (length (second op)))
	(LCur (third op))
	(LPrev (fourth op))
	(PdPrev (fifth op)))
    ;; Remove the added lines.
    (set-text! buf (append (take text LCur)
			   (drop text (+ LCur nLines))))
    ;; Move the cursor to the previous location.
    (set-line-cur! buf LPrev)
    (update-pp-list! buf)
    (set-pd-cur! buf PdPrev)
    (set-pp-goal! buf PpGoalPrev)

    ;; Clear the mark if it was in the delete region. Otherwise, Move
    ;; the mark up, if necessary.
    (let ((LMark (get-line-mark buf)))
    (when (is-mark-set? buf)
      (cond
       ((and (>= LMark LCur)
	     (<= LMark (+ LCur + nLines))
	(set-mark-set! buf #f))
       ((> LMark (+ LCur nLines))
	(set-line-mark! buf (- LMark nLines)))))))

(define* (insert-lines-after (buf <CBuffer>) strlist #:optional (lineno #f))
  "Given a list of strings, this inserts the strings into BUF after
the line LINENO, or, if LINENO is not specified, after the line in
which the active data position is located.  The active data position
is moved to the end of the last inserted line.  If strlist is an empty
list, no lines are inserted and the active data position is moved the
end of line LINENO."
  (push-op! buf (op-insert-lines-after buf
				       strlist
				       (or lineno (get-line-mark buf)))))

;;  INSERT-LINES-BEFORE

(define-method (op-insert-lines-before (buf <CBuffer>) strlist lineno)
  ('insert-lines-before
   strlist				; strings to insert
   lineno				; line number to insert after
   (get-line-cur buf)			; current line
   (get-pd-cur buf)			; current position
   (get-pp-goal buf)))			; current goal column

(define-method (apply-op-insert-lines-before (buf <CBuffer>) op)
  (let ((strlist (second op))
	(LCur (third op)))
    ;; Append the text before line LCur.
    (set-text! buf (append (take txt (max 0 (1- LCur)))
			   strlist
			   (drop txt (max 0 (1- LCur)))))
    ;; Move the cursor to the end of the inserted lines,
    ;; or if strlist was empty, to the end of the current line.
    (set-line-cur! buf (if (null-list? strlist)
			   LCur
			   (1- LCur)))
    (let ((txtcur (get-text-cur buf)))
      ;; Move the active data position to the end of the line, and
      ;; then adjust the presentation position and goal column.
      (set-pd-cur! buf (string-length txtcur))
      (update-pp-list! buf)
      (update-pp-cur! buf)
      (set-pp-goal! buf 0)

      ;; Move the mark down, if necessary
      (let ((LCur (get-line-cur)))
	(when (and (is-mark-set? buf)
		   (>= (get-line-mark buf) LCur))
	(set-line-mark! buf (+ (get-line-mark buf) (length strlist)))))))

(define (ed-insert-lines-before (buf <CBuffer>) strlist #:optional (lineno #f))
  "Given a list of strings, this inserts them as lines before the line
LINENO, or, if LINENO is not specified, before the active data line.
The active data position is moved to the end of the last inserted
line.  If strlist is an empty list, no lines are inserted, and the
active data position is moved to the end of line LINENO, or, if LINENO
is not specified, to the end of the active data line."  #f)

(define (ed-replace-lines (buf<CBuffer>) strlist
			  #:optional (start #f)
			  (end #f))
  "Given a list of strings and START and END line numbers, this
deletes the lines START through END inclusive and inserts the list of
strings into the buffer beginning at the line number of the first of
the deleted lines.

The active data position will be set to the end of the last inserted
line.  If END is not specified, it will be assumed to be the same as
START.  If START is not specified, the active data line will be used.
If the list of strings is empty, the active data position will be set
to the end of the line preceding the deleted lines.

If the buffer is empty, the active data position will be set to the
first position."

  #f)

(define (ed-delete-all (buf <CBuffer>))
  "This deletes all the contents of the current buffer and places the
active data position in the first position."
  #f)

(define (ed-regex-search-forward-line (buf <CBuffer>) regex)
  "This searches the text following the active data position for the
first line that matches the regular expression.  For the line where
the active data position is located, only the substring after the
active data position is searched. For the remaining lines, the whole
of the text in each line is searched. If a match is found, the
procedure returns #t, and the active data position will be set to the
end of the matching line.  If a match is not found, the procedure
returns #f and the active data position is unchanged."  #f)

(define (ed-join-lines (buf <CBuffer>) #:optional (start #f) (end #f))
  "This concatenates the lines numbered START to END into a single
line located at START.  If START and END are not both specified, the buffer
is unchanged.  The active data position is moved to the end of line
START, or, of START is not specified, to the end of the active data line."
  
  #f)

(define (ed-move-lines (buf <CBuffer>) pos #:optional (start #f) (end #f))
  "This moves the lines addressed START to END inclusively to after
line addresed as POS.  If END is not specified, only the line
addressed as START is moved.  If START and END are not specified, the
active data line is moved. It is an error if START <= POS <= END.  The
active data position is moved to the end of last line moved."
  #f)

(define (ed-copy-lines (buf <CBuffer>) pos #:optional (start #f) (end #f))
  "This copies the lines addressed START to END inclusively to after
line addresed as POS.  If END is not specified, only the line
addressed as START is copied.  If START and END are not specified, the
active data line is copied. It is an error if START <= POS <= END.  The
active data position is moved to the end of last line copied."
  #f)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; OPERATIONS

;; BELL - Set call for attention
(define-method (bell (buf <CBuffer>))
  "Call for attention" 
  (set-bell! buf #t))

(define-method (op-bell (buf <CBuffer>))
  (list 'bell (get-bell buf)))

(define-method (apply-op-bell (buf <CBuffer>) op)
  (set-bell! buf #t))

(define-method (undo-op-bell (buf <CBuffer>) op)
  (set-bell! buf (second op)))

;; CLEAR_BELL - unset call for attention

(define-method (clear-bell (buf <CBuffer>))
  "Reset any call for attention." 
  (set-bell! buf #f))

(define-method (op-clear-bell (buf <CBuffer>))
  (list 'clear-bell (get-bell buf)))

(define-method (apply-op-clear-bell (buf <CBuffer>) op)
  (set-bell! buf #f))

(define-method (undo-op-clear-bell (buf <CBuffer>) op)
  (set-bell! buf (second op)))


;; BS - backspace
(define-method (op-backspace (buf <CBuffer>))
  `(bs ,(get-pd-cur buf) ,(get-pp-goal buf)))

(define-method (apply-op-backspace (buf <CBuffer>) op)
  (when (> (get-pd-cur buf) 0)
    (increase-pd-cur! buf -1))
  (update-pp-cur! buf)
  (synchronize-pp! buf))

(define-method (undo-op-backspace (buf <CBuffer>) op)
  (set-pd-cur! buf (second op))
  (update-pp-cur! buf)
  (set-pp-goal! buf (third op)))

;; FIXME - should honor SIMD.
(define-method (backspace (buf <CBuffer>))
  "Move the active data position to the previous data position."
  (push-op! buf (op-backspace buf))
  (run-op buf))

;; CAN - Treat the last operation as erroneous. Undo it and keep no
;; record of it on the stack.
(define-method (op-cancel (buf <CBuffer>))
  `(can))

(define-method (apply-op-cancel (buf <CBuffer>) op)
  (let ((prev-op (pop-last-op! buf)))
    (if prev-op
	(push-op! buf prev-op 'undo))))

(define-method (cancel (buf <CBuffer>))
  "Undo the previous operation, if any.

The cancel operation is special in that it is never stored in the
queue and can't be undone."
  (push-op! buf (op-cancel))
  (run-op buf))

;; CBT
(define-method (cursor-backward-tabulation (buf <CBuffer>) n)
    "Move the active presentation position to the character position
corresponding to the n-th preceding character tabulation stop in the
presentation component"
    (let* ([ppCur (get-pp-cur buf)]
           [tabsize (get-tab-size buf)]
           ;; Back up n tabsizes
           [pp1 (max 0 (compute-tab-column ppCur tabsize (- n)))])
      (set-positions! buf pp1 'presentation)))

;; CCH - UNIMPLEMENTED
(define-method (cancel (buf <CBuffer>))
  "Undo the previous graphic character"
  #f)

;; CHA
(define-method (cursor-character-absolute (buf <CBuffer>) n)
    "Move the active presentation position to character position n in
the active line in the presentation component"
    (set-positions! buf n 'presentation))

;; CHT
(define-method (cursor-forward-tabulation (buf <CBuffer>) n)
    "Move the active presentation position to the character position
corresponding to the n-th following character tabulation stop in the
presentation component"
    (let* ([ppList (compute-pp-list-from-string (get-text-cur buf)
						(get-tab-size buf))]
           ;; Move forward n tabsizes
           [tabsize (get-tab-size buf)]
           [pp (compute-tab-column (get-pp-cur buf) tabsize n)])
      (set-positions! buf pp 'presentation)))

;; CNL
(define (cursor-next-line buf n)
  "Move the active presentation position to the 1st character position
of the n-th following line in the presentation component"
  (let* ([LCur (get-line-cur buf)]
         ;; Move forward n lines, or to the end of the buffer
         [L1 (bracket-line buf (+ LCur n))])
    (when (> L1 (get-line-cur buf))
	  (set-line-cur! buf L1)
	  (update-pp-list! buf)
	  (set-positions! buf 0 'data))))
;; CPL
(define (cursor-preceding-line buf n)
  "Move the active presentation position to the 1st character position
of the n-th preceding line in the presentation component"
  (let* ([LCur (get-line-cur buf)]
         ;; Move backward n lines, or to the beginning of the buffer
         [L1 (bracket-line buf (- LCur n))])
    (when (< L1 (get-line-cur buf))
	  (set-line-cur! buf L1)
	  (update-pp-list! buf)
	  (set-positions! buf 0 'data))))

;; CR
(define-method (carriage-return (buf <CBuffer>))
  "Move the active presentation position to the line home position of
the same line"
  (cond
   ((eq? (get-home-type buf) 'data)
    (set-positions! buf (get-home-pos buf) 'data))
   (else
    (set-positions! buf (get-home-pos buf) 'presentation))))

;; CTC
(define-method (cursor-tabulation-control (buf <CBuffer>) n)
  "Set the number of spaces per tab to N"
  (set-tab-size! buf n))

;; CUB
(define-method (cursor-left (buf <CBuffer>) n)
  "Move the active presentation position leftwards in the presentation
component by n character positions"
  (set-positions! buf (max 0 (- (get-pp-goal buf) n)) 'presentation))

;; CUD
(define-method (cursor-down (buf <CBuffer>) n)
  "Move the active presentation position downwards in the presentation
component by N line positions"
  (let* ( ;; Move forward n lines, or to the end of the buffer
         [L1 (bracket-line buf (+ (get-line-cur buf) n))])
    (set-line-cur! buf L1)
    (update-pp-list! buf)
    (set-positions! buf (get-pp-cur buf) 'presentation)))

;; CUF
(define-method (cursor-right (buf <CBuffer>) n)
  "Move the active presentation position rightwards in the
presentation component by n character positions"
  (set-positions! buf (min (get-pp-max buf)
			   (+ (get-pp-goal buf) n))
		  'presentation))

;; CUP
(define-method (cursor-position (buf <CBuffer>) n m)
  "Move the active presentation position to the n-th line and m-th
character position in the presentation component"
  (set-line-cur! buf (bracket-line buf n))
  (update-pp-list! buf)
  (set-positions! buf m 'presentation))

;; CUU
(define-method (cursor-up (buf <CBuffer>) n)
  "Move the active presentation positions upwards in the presentation
component by N line positions"
  (let* (
         ;; Move backward n lines, or to the top of the buffer
         [L1 (bracket-line buf (- (get-line-cur buf) n))])
    (set-line-cur! buf L1)
    (update-pp-list! buf)
    (set-positions! buf (get-pp-cur buf) 'presentation)))

;; CVT
(define-method (cursor-line-tabulation (buf <CBuffer>) n)
  "Causes the active presentation position to be moved to the
corresponding character position of the line corresponding to the n-th
following line tabulation stop in the presentation component."  
    (let* (
           ;; Move down n vert-tabsizes
           [tabsize (get-vert-tab-size buf)]
           [L (compute-tab-column (get-line-cur buf) tabsize n)])
      (set-line-cur! buf (bracket-line buf L))
      (set-positions! buf (get-pp-cur buf) 'presentation)))

;; DA
(define-method (device-attributes (buf <CBuffer>))
  "Returns a string identifying this class"
  "CBuffer 0.0")

;; DSR
(define-method (device-status-report (buf <CBuffer>) device)
  "If the device is 'presentation, report the active presentation position as
line, position.  If device is 'data, report the active data position."
  (cond
   ((eq? device 'data)
    (cons (get-line-cur buf) (get-pd-cur buf)))
   (else
    (cons (get-line-cur buf) (get-pp-cur buf)))))

;; DCH
(define-method (delete-character buf device)
  "This removes the character at the active data position.  The
characters to the right of the active data position are moved left to
fill in the gap.  If the active data position it at the end of the
line, nothing happens.  If device is 'presentation, the characters are
shifted one cell, even if the character was double-width.  If device
is 'data, the characters are shifted one character."
  (let ([txt (get-text-cur buf)]
	[pd (get-pd-cur buf)]
	[len (get-text-cur-length)]
	[width (wcwidth (string-ref txt pd))])
    (cond
     [(= len 0)
      *unspecified*]
     [(= pd len)
      *unspecified*]
     [(= pd 0)
      (cond
       ((eq? device 'presentation)
	(set-text-cur! buf (string-append (make-string (1- w) #\space)
					  (string-drop txt 1))))
       (else
	(set-text-cur! buf (string-drop txt 1))))]
     [else
      (cond
       ((eq? device 'presentation)
	(set-text-cur! buf (string-append (string-take txt (1- pd))
					  (make-string (1- w) #\space)
					  (string-drop txt pd))))
       (else
	(set-text-cur! buf (string-append (string-take txt (1- pd))
					  (string-drop txt pd)))))])

    ;; (update-pd-list! buf)
    (set-positions! buf pd 'data)))

;; DL
(define-method (delete-line (buf <CBuffer>) n)
  "Causes the active line and the n-1 following lines to be removed
from the buffer.  The resulting gap is closed by moving the adjacent
lines up.  The cursor is placed at the home position of the active line.  If
all the lines to the end of the buffer had been deleted, a new empty line is
added to the end of the buffer."
  (error "fixme"))
  
(define-method (center-frame-line (buf <CBuffer>))
  "Vertically center the frame around the active presentation position"
  (let ([L (- (get-line-cur buf) (floor (/ (get-line-frame-size buf) 2)))])
    (set-line-frame! buf (max 0 L))))

(define-method (center-frame-position (buf <CBuffer>))
  "Adjust the left hand side of the frame so that the active presentation
position is visible"
  (let ([pp (get-pp-cur buf)]
	[col (get-pp-frame-size buf)])
    (set-pp-frame! buf (cond
			((or (= 0 pp) (< pp (1- col)))
			 0)
			((> col 8)
			 (+ pp -7 (modulo (- pp 7) (- col 8))))
			(else
			 (+ pp (- col) 2))))))

(define-method (character-position-absolute (buf <CBuffer>) n)
  "Move the active data position to the n-th codepoint in the active
line"
  (let* ([pd (bracket-pd buf n)])
    (set-positions! buf pd 'data)))

(define-method (character-position-backward (buf <CBuffer>) n)
  "Move the active data position backward n codepoints"
  (let* ([pd (bracket-pd buf (- (get-pd-cur buf) n))])
    (set-positions! buf pd 'data)))

(define-method (character-position-forward (buf <CBuffer>) n)
  "Move the active data position forward n codepoints"
  (let* ([pd (bracket-pd buf (+ (get-pd-cur buf) n))])
    (set-positions! buf pd 'data)))

(define-method (character-and-line-position (buf <CBuffer>) n m)
  "Moves the active data position to the n-th line position m-th
character position"
  (set-line-cur! buf (bracket-line buf n))
  (update-pp-list! buf)
  (character-position-absolute buf m))






(define-method (delete-in-line buf P)
  "This removes some or all of the characters in the current line.
If P is zero, the active position through the end of the line are
deleted.  If P is one, the beginning of the line through the active
position are deleted; the remaining characters in the line are shifted
left to fill in the gap; and, the cursor is placed at the beginning of
the line.  If P is two, all the characters in the line are removed,
and the cursor is placed at the beginning of the now-empty line."
  (let ([txt (get-text-cur buf)]
	[pd (get-pd-cur buf)])
    (cond
     [(= P 0)
      (set-text-cur! buf (string-take txt pd))
      ;; (update-pd-list! buf)
      (set-positions! buf pd 'data)]
     [(= P 1)
      (set-text-cur! buf (string-drop txt (1+ pd)))
      ;; (update-pd-list! buf)
      (set-positions! buf 0 'data)]
     [(= P 2)
      (set-text-cur! buf "")
      ;; (update-pd-list! buf)
      (set-positions! buf 0 'data)]
     [else
      (error "FIXME")])))

;; ECH
(define-method (erase-character buf device)
  "This replaces the character at the active data postion with the
space character.  If DEVICE is 'presentation, multi-cell graphemes
will be replaced with multiple space characters.  If DEVICE is 'data,
the current codepoint will be replaced with a single space character."
  (let ([txt (get-text-cur buf)]
	[pd (get-pd-cur buf)]
	[len (get-text-cur-length buf)])
    (cond
     [(string-null? txt)
      *unspecified*]
     [(= pd len)
      *unspecified*]
     [(eq? device 'data)
      (set-text-cur! buf (string-set! txt pd #\space))]
     [(eq? device 'presentation)
      (let ([ch (string-ref txt pd)])
	(if (char=? ch #\tab)
	    (set-text-cur! buf (string-append (string-take txt pd)
					      (make-string (- (compute-tab-column pd (get-tab-size buf) 1)
							      pd)
							   #\space)
					      (string-drop txt (1+ pd))))
	    ;; else
	    (set-text-cur! buf (string-append (string-take txt pd)
					      (make-string (wcwidth (string-ref txt pd)) #\space)
					      (string-drop txt (1+ pd))))))])
    ;; (update-pd-list! buf)
    (set-positions! buf 0 'presentation)))

;; EL
(define-method (erase-in-line buf device P)
  "This sets some or all of the characters in the current line to
spaces. If P is zero, the active position through end of the line are
erased.  If P is one, the beginning of the line through the active
position are erased.  If P is two, the entire line is erased.

If the DEVICE is 'presentation, graphemes that occupy more than one
cell will be replaced with as many spaces necessary to keep the number
of presentation cells constant, and the cursor remains in the same
position in the presentation component, but, the active data position
may change.  If the DEVICE is 'data, each codepoint that is erased
will be replaced with a single space character.  The active data
position remains the same but the presentation position may change.
This may change the visual presentation of the line"

  ;;(add-undo (list 'EL device P (get-text-cur buf) (get-pd-cur buf) (get-line-text buf)))

  (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))]
        [pp-cur (get-pp-cur buf)]
        [pd-cur (get-pd-cur buf)]
        [pd-mark (get-pd-mark buf)]
        [text-cur (get-text-cur buf)])
    (cond
     ;; Erase to the end of the line
     [(and (eqv? device 'presentation) (= P 0))
      (set-text! buf (string-append (string-take text-cur pd-cur)
                                    (make-string (- (last ppList) pp-cur) #\space)))
      ;; Clear the mark if its position has been erased
      (when (and (is-mark-set? buf)
                 (= (get-line-cur buf) (get-line-mark buf))
                 (>= pd-mark pd-cur))
        (set-mark-flag! buf #f))]
     [(and (eqv? device 'data) (= P 0))
      (set-text! buf (string-append (string-take text-cur pd-cur)
                                    (make-string (- (string-length text-cur) pd-cur) #\space)))
      ;; Clear the mark if its position has been erased
      (when (and (is-mark-set? buf)
                 (= (get-line-cur buf) (get-line-mark buf))
                 (>= pd-mark pd-cur))
        (set-mark-flag! buf #f))]

     ;; Erase from the beginning of the line to here
     [(and (eqv? device 'presentation) (= P 1))
      (when (and (is-mark-set? buf)
                 (= (get-line-cur buf) (get-line-mark buf)))
        ;; If the mark's position will be erased, clear the mark
        (when (<= pd-mark pd-cur)
          (set-mark-flag! buf #f))
        ;; If the mark's position is later in this line, adjust is
        ;; data position to keep it on the same codepoint
        (when (> pd-mark pd-cur)
          (set-pd-mark! (+ pd-mark (- pp-cur pd-cur)))))
      ;; Erase the beginning of the string
      (set-text! buf (string-append (make-string pp-cur #\space)
                                    (string-drop text-cur pd-cur)))
      (set-pd-cur! buf pp-cur)]
     [(and (eqv? device 'data) (= P 1))
      (when (and (is-mark-set? buf)
                 (= (get-line-cur buf) (get-line-mark buf)))
        ;; If the mark's position will be erased, clear the mark
        (when (<= pd-mark pd-cur)
          (set-mark-flag! buf #f)))
      ;; Erase the beginning of the string
      (set-text! buf (string-append (make-string pd-cur #\space)
                                    (string-drop text-cur pd-cur)))
      (set-pp-cur! buf pd-cur)
      (set-pp-goal! buf pd-cur)]
     ;; Erase the whole line
     [(and (eqv? device 'presentation) (= P 2))
      ;; If the mark is on this line, erase it
      (when (and (is-mark-set? buf)
                 (= (get-line-cur buf) (get-line-mark buf)))
        (set-mark-flag! buf #f))
      ;; Erase the line
      (set-text! buf (make-string (last ppList)))
      (set-pd-cur! buf pp-cur)]
     [(and (eqv? device 'data) (= P 2))
      ;; If the mark is on this line, erase it
      (when (and (is-mark-set? buf)
                 (= (get-line-cur buf) (get-line-mark buf)))
        (set-mark-flag! buf #f))
      ;; Erase the line
      (set-text! buf (make-string (string-length text-cur) #\space))
      (set-pp-cur! buf pd-cur)
      (set-pp-goal! buf pd-cur)])))

;; FF
(define-method (form-feed (buf <CBuffer>))
  "FF causes the frame to be moved one frame-size down toward the end
of the buffer.  The active presentation position to be moved to the
corresponding character position of the line at the page home position
of that next page in the presentation component."
  (when
      ;; If there is at least a  partial page below this one
      (< (+ (get-line-frame buf) (get-line-frame-size buf))
	 (get-line-count buf))
    (set-line-frame! buf (+ (get-line-frame buf) (get-line-frame-size buf)))
    (set-line-cur! buf (min (get-line-count buf)
			    (+ (get-line-frame buf) (get-page-home-line buf))))))

(define-method (insert-character-space (buf <CBuffer>) n)
  "Shift the contents of the line to the right, starting at the
current data position, creating an empty gap of N codepoints.  The
active position is unchanged."
  ;;(add-undo (list 'ICH n (get-text-cur buf) (get-pd-cur buf)))

  (let ([str (get-text-cur buf)]
        [pd (get-pd-cur buf)])
    ;; Add some space at the current position.
    (set-text-cur! buf
		   (string-append (string-take str pd)
				  (make-string n #\space)
				  (string-drop str pd)))
    
    ;; Update the list of presentation positions.
    (update-pp-list! buf)
    
    ;; Move the mark right, if necessary
    (when (and (is-mark-set? buf)
               (= (get-line-mark buf) (get-line-cur buf))
               (>= (get-pd-mark buf) (get-pd-cur buf)))
      (set-pd-mark! buf (+ (get-pd-mark buf) n)))))

(define-method (insert-line-space (buf <CBuffer>) n)
  "Move the current line and the n-1 following lines down N lines.
The resulting cap is erased.  The cursor is placed at the home
position of the first new empty line."
  ;;(add-undo buf (list 'IL n (get-text-cur) (get-pd-cur)))

  (let ([txt (get-text buf)]
        [L (get-line-cur buf)])
    (set-text! buf (append (take txt L)
                           (make-list n "")
                           (drop txt L)))
    (set-pd-cur! buf 0)
    (set-pp-cur! buf 0)
    (set-pp-goal! buf 0)

    ;; Move the mark down, if necessary
    (when (and (is-mark-set? buf)
               (>= (get-line-mark) L))
      (set-line-mark! buf (+ (get-line-mark) n)))))

(define-method (insert-nel (buf <CBuffer>))
  "Removes the text between the active position and the end of the
line from the current line, and places it in a new line inserted after
the current line.  The active position is moved to the beginning of
the new line."
  (let ([txt (get-text buf)]
        [txtcur (get-text-cur buf)]
        [pd (get-pd-cur buf)]
        [L (get-line-cur buf)])
    (format (current-error-port) "insert-nel: before txtcur ~a pd ~a L ~a~%" txtcur pd L)
    (set-text! buf (append (take txt L)
                           (list (string-take txtcur pd))
                           (list (string-drop txtcur pd))
                           (drop txt (min (1+ L)))))
    ;; Move the mark down, if necessary
    (when (is-mark-set? buf)
      (cond
       [(and (= (get-line-mark buf) L) (>= (get-pd-mark buf) pd))
        (set-line-mark! buf (1+ L))
        (set-pd-mark! buf (- (get-pd-mark buf) pd))]
       [(>= (get-line-mark buf) L)
        (set-line-mark! buf (1+ L))]))

    (set-pd-cur! buf 0)
    (set-pp-cur! buf 0)
    (set-pp-goal! buf 0)
    (set-line-cur! buf (1+ L))
    (format (current-error-port) "insert-nel: after txtcur ~a pd ~a L ~a~%" (get-text-cur buf) (get-pd-cur buf) (get-line-cur buf))
    ))

(define-method (is-position-in-frame? (buf <CBuffer>))
  "Return #t if the active line and presentation position are visible in the
current frame."
  (let* ([pp (get-pp-cur buf)]
	 [line (get-line-cur buf)]
	 [top (get-line-frame buf)]
	 [bottom (+ top (get-line-frame-size buf))]
	 [left (get-pp-frame buf)]
	 [right (+ left (get-pp-frame-size buf))]
	 )
    (and (>= line top) (<= line bottom)
	 (>= pp left) (<= pp right))))

(define-method (line-position-absolute (buf <CBuffer>) n)
  "Move the active data position to the n-th line"
  (set-line-cur! buf (min n (get-line-count buf)))
  (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))])
    (set-pp-cur! buf (list-ref ppList (get-pd-cur buf)))
    (set-pp-goal! buf (get-pp-cur buf))))

(define-method (line-position-backward (buf <CBuffer>) n)
  "Move the active data position up n line positions"
  (set-line-cur! buf (max 0 (- (get-line-cur) n)))
  (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))])
    (set-pp-cur! buf (list-ref ppList (get-pd-cur)))
    (set-pp-goal! buf (get-pp-cur))))

(define-method (line-position-forward (buf <CBuffer>) n)
  "Move the active data position down by n line positions"
  (set-line-cur! buf (min (+ (get-line-cur) n) (get-line-count buf)))
  (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))])
    (set-pp-cur! buf (list-ref ppList (get-pd-cur)))
    (set-pp-goal! buf (get-pp-cur))))

(define-method (move-frame-line (buf <CBuffer>))
  "Set the top line of the frame to the be active presentation line"
  (let ([L (get-line-cur buf)])
    (set-line-frame! buf L)))

(define-method (render-frame (buf <CBuffer>))
  "Return a list of strings of the characters that are visible
in the current frame.  Tabs will be converted to spaces.
Lines will be space-padded to contain as many cells as the 
frame"
  (let* ([L-size (get-line-frame-size buf)]
	 [L-start (get-line-frame buf)]
	 [L-end (min (get-line-count buf) (+ L-start L-size))]
	 [tabsize (get-tab-size buf)]
	 [data-txt (get-text buf)]
	 [pp-start (get-pp-frame buf)]
	 [pp-size (get-pp-frame-size buf)]
	 [frame-txt (make-list L-size (make-string (get-pp-frame-size buf) #\space))])
    (do ([L (max 0 L-start) (1+ L)]) ([>= L L-end])
      (list-set! frame-txt (- L L-start)
		 (render-line (list-ref data-txt L) tabsize pp-start pp-size)))
    frame-txt))

(define-method (scroll-down (buf <CBuffer>) n)
  "Moves the presentation component N line positions such that the
data appear to move down; the active presentation position is not
affected by this control function."
  (set-line-frame! buf (max 0 (- (get-line-frame buf) n))))

(define-method (scroll-left (buf <CBuffer>) n)
  "Causes the presentation component to be moved n character cells
such that the text appears to move to the left"
  #f)

(define-method (scroll-right (buf <CBuffer>) n)
  "Causes the presentation component to be moved n character cells
such that the text appears to move to the right"
  #f)

(define-method (scroll-up (buf <CBuffer>) n)
  "Moves the presentation component N line positions such that the
data appear to move up; the active presentation position is not
affected by this control function."
  (set-line-frame! buf (min (1- (get-line-count buf)) (- (get-line-frame buf) n))))

(define-method (write-character (buf <CBuffer>) c device)
  "Writes the graphical character C into the active position,
overwriting the current character.  If DEVICE is 'data, the current
codepoint is replaced with C.  If DEVICE is 'presentation, those
graphemes that would be wholly or partly overwritten by this grapheme
will be erased before this grapheme is added."
  (cond
   [(eq? device 'data)
    (let ([txt (get-text-cur buf)]
          [pd (get-pd-cur buf)])
      (set-text-cur! buf (string-append (string-take txt pd)
                                        (string c)
                                        (string-drop txt (min (string-length txt) (1+ pd)))))
      
      ;; Update the list of presentation positions.
      (update-pp-list! buf)
      
      ;; Clear the mark if we're overwriting the mark
      (when (and (is-mark-set? buf)
                 (= (get-pd-mark buf) (get-pd-cur buf))
                 (= (get-line-cur buf) (get-line-mark buf)))
        (set-mark-flag! buf #f))
      ;; Move the cursor forward
      (set-pd-cur! buf (1+ (get-pd-cur buf)))
      (set-pp-cur! buf (get-pp-from-pd-cur buf))
      (set-pp-goal! buf (get-pp-cur buf)))]

   [(eqv? device 'presentation)
    (let* ([ppList (compute-pp-list-from-string (get-text-cur buf)
                                                (get-tab-size buf))]
           ;; Presentation position of start
           [pp-start (get-pp-cur buf)]
           ;; Presentation position of next
           [pp-end (+ pp-start (wcwidth c))]

           ;; Data position of start of char, being careful to include
           ;; the beginning of wide characters
           [pd1 (list-index (lambda (x) (> x pp-start)) ppList)]
           [pd-start (if pd1
                         (max 0 (1- pd1))
                         ;; else
                         (last ppList))]

           ;; Data position of end of char
           [pd2 (list-index (lambda (x) (> x pp-end)) ppList)]
           [pd3 (if pd2
                    (max 0 (1- pd2))
                    ;; else
                    (last ppList))]
           [pd-end (min (last ppList) (if (= pd3 pd-start)
                                          (1+ pd-start)
                                          pd3))]

           ;; Presentation of start of characters overwritten by char,
           ;; including padding for wide characters
           [space-before-char (- (get-pp-cur buf) (list-ref ppList pd-start))]
           [space-after-char (max 0 (- (list-ref ppList pd-end) pp-end))]
           [txt (get-text-cur buf)])

      (format (current-error-port) "write-char pd-cur ~s pd-start ~s pd-end ~s pp-cur ~s pp-start ~s pp-end ~s space ~s;~s~%" (get-pd-cur buf) pd-start pd-end (get-pp-cur buf) pp-start pp-end space-before-char space-after-char)
      ;; Replace the tab characters with spaces
      (set-text-cur! buf (string-append (string-take txt pd-start)
                                        (make-string space-before-char #\space)
                                        (string c)
                                        (make-string space-after-char #\space)
                                        (string-drop txt pd-end)))
      ;; Update the list of presentation positions.
      (update-pp-list! buf)

      ;; Move the active position
      (set-pd-cur! buf (+ pd-start 1))
      (set-pp-cur! buf (get-pp-from-pd-cur buf))
      (set-pp-goal! buf (get-pp-cur buf)))]))

(define-method (write-tabulation (buf <CBuffer>) device)
  "Writes a tab at the current position, overwriting the current character.
If DEVICE is 'data, the current codepoint is replace with a tab.  If
DEVICE is 'presentation, those graphemes that would be wholly or
partly overwritten by this tab will be erased before the tab is
added."
  (cond

   ;; If we're overwriting a tab with a tab
   [(and (< (get-pd-cur buf) (string-length (get-text-cur buf)))
         (eqv? #\tab (string-ref (get-text-cur buf) (get-pd-cur buf))))
    ;; Clear the mark if we're overwriting the mark
    (when (and (is-mark-set? buf)
               (= (get-pd-mark buf) (get-pd-cur buf))
               (= (get-line-cur buf) (get-line-mark buf)))
      (set-mark-flag! buf #f))
    ;; Don't replace anything, but move the cursor forward
    (set-pd-cur! buf (1+ (get-pd-cur buf)))
    (set-pp-cur! buf (get-pp-from-pd-cur buf))
    (set-pp-goal! buf (get-pp-cur buf))]

   [(eqv? device 'data)
    (let ([txt (get-text-cur buf)]
          [pd (get-pd-cur buf)])
      (set-text-cur! buf (string-append (string-take txt pd)
                                        (string #\tab)
                                        (string-drop txt (min (string-length txt) (1+ pd)))))
      ;; Clear the mark if we're overwriting the mark
      (when (and (is-mark-set? buf)
                 (= (get-pd-mark buf) (get-pd-cur buf))
                 (= (get-line-cur buf) (get-line-mark buf)))
        (set-mark-flag! buf #f))
      ;; Move the cursor forward
      (set-pd-cur! buf (1+ (get-pd-cur buf)))
      (set-pp-cur! buf (get-pp-from-pd-cur buf))
      (set-pp-goal! buf (get-pp-cur buf)))]

   [(eqv? device 'presentation)
    (let* ([ppList (compute-pp-list-from-string (get-text-cur buf)
                                                (get-tab-size buf))]
           [tabsize (get-tab-size buf)]
           ;; Presentation position of start of tab
           [pp-start (get-pp-cur buf)]
           ;; Presentation position of next tab stop
           [pp-end (* tabsize (quotient (+ pp-start tabsize) tabsize))]
           ;; if we've moved past the end of the line...
           [pp3 (min pp-end (last ppList))]

           ;; Data position of start of tab, being careful to include
           ;; the beginning of wide characters
           [pd1 (list-index (lambda (x) (> x pp-start)) ppList)]
           [pd-start (if pd1
                         (max 0 (1- pd1))
                         ;; else
                         (last ppList))]

           ;; Data position of end of tab
           [pd2 (list-index (lambda (x) (> x pp3)) ppList)]
           [pd-end (if pd2
                       (max 0 (1- pd2))
                       ;; else
                       (last ppList))]

           ;; Presentation of start of tab, including padding for wide
           ;; characters
           [pp-adj-start (list-ref ppList pd-start)]
           [pp-adj-end (max pp-end (list-ref ppList pd-end))]
           [space-num (- pp-adj-end pp-adj-start)]
           [txt (get-text-cur buf)])

      ;; Replace the tab characters with spaces
      (set-text-cur! buf (string-append (string-take txt pd-start)
                                        (make-string space-num #\space)
                                        (string-drop txt pd-end)))
      (set-pd-cur! buf (+ pd-start space-num))
      (set-pp-cur! buf pp-adj-end)
      (set-pp-goal! buf pp-adj-end))]))



