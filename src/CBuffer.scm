(define-module (gano CBuffer)
  #:use-module (gano config)
  #:use-module (oop goops)
  #:use-module (oop goops describe)
  #:use-module (gano chars)
  #:use-module (gano utils)
  #:use-module (srfi srfi-1)
  ;; #:use-module (rnrs control)
  #:use-module ((ncurses extra) #:select (wcwidth))
  #:export (
            <CBuffer>

            backspace
            carriage-return
            character-position-absolute
            character-position-backward
            character-position-forward
            character-and-line-position
            cursor-backward-tabulation
            cursor-character-absolute
            cursor-down
            cursor-forward-tabulation
            cursor-left
            cursor-next-line
            cursor-position
            cursor-preceding-line
	    cursor-right
            cursor-up
            insert-line
            line-position-absolute
            line-position-backward
            line-position-forward
	    render-frame
            scroll-down
            scroll-up
            write-character
            write-tabulation

            get-line-cur
            get-pd-cur
            get-pp-cur
            get-pp-from-pd-cur
            get-pp-goal
            get-text-cur
            increase-pd-cur!
            render-line
            set-line-cur!
            set-line-frame!
            set-line-frame-size!
            set-pd-cur!
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

(if %have-rnrs-control
    (use-modules (rnrs control))
    (use-modules (gano control)))

(define-class <CBuffer> ()
  ;; The file
  (m_fileName #:init-value "")
  (m_fileFormat #:init-value 'nix)
  (m_fModified #:init-value #f)

  ;; The text
  ;; A list of strings
  (m_rgText #:init-value '("") #:getter get-text #:setter set-text!)
  ;; A list of the presentation positions of the characters of the current line
  (m_rgPpList #:init-value '() #:getter get-pp-list #:setter set-pp-list!)
  ;; The current line number
  (m_LCur #:init-value 0 #:getter get-line-cur #:setter %set-line-cur!)
  ;; The current data position
  (m_PdCur #:init-value 0 #:getter get-pd-cur #:setter set-pd-cur!)
  ;; The current presentation position
  (m_PpCur #:init-value 0 #:getter get-pp-cur #:setter set-pp-cur!)
  ;; The desired presentation position
  (m_PpGoal #:init-value 0 #:getter get-pp-goal #:setter set-pp-goal!)
  ;; The number of spaces per between tab stops
  (m_tabSize #:init-value 8 #:getter get-tab-size #:setter set-tab-size!)

  ;; The mark
  (m_fMarkSet #:init-value #f #:getter is-mark-enabled? #:setter set-mark-flag!)
  (m_LMark #:init-value 0)
  (m_PdMark #:init-value 0)

  ;; The Frame
  (m_LFrame #:init-value 0 #:getter get-line-frame #:setter set-line-frame!)
  (m_PpFrame #:init-value 0 #:getter get-pp-frame #:setter set-pp-frame!)
  (m_LFrameSize #:init-value 25 #:getter get-line-frame-size #:setter set-line-frame-size!)
  (m_PpFrameSize #:init-value 80 #:getter get-pp-frame-size #:setter set-pp-frame-size!)

  ;;(m_totalSize #:init-value 0)

  ;;(m_statCur #:init-value #f)
  ;;(m_undo #:init-value '()))
  )

;; PRIMITIVES

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
  "Return the number of line in the buffer"
  (length (get-text buf)))

(define-method (get-pp-from-pd-cur (buf <CBuffer>))
  "Find the presentation position of the active data position for the
current line."
  (count-cells-in-substring (get-text-cur buf) (get-pd-cur buf) 0 (get-tab-size buf)))

(define-method (get-pp-max (buf <CBuffer>))
  (last (get-pp-list buf)))

(define-method (get-text-cur (buf <CBuffer>))
  "Return the text of the active line"
  (list-ref (get-text buf) (get-line-cur buf)))

(define-method (get-text-cur-length (buf <CBuffer>))
  "Return the number of codepoints in the active line"
  (string-length (get-text-cur buf)))

(define-method (increase-pd-cur! (buf <CBuffer>) n)
  (set-pd-cur! buf (+ (get-pd-cur buf) n)))

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
			
    (format #t "~s ~s ~s~%" left-padding str-pp-size right-padding)
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

(define-method (set-line-cur! (buf <CBuffer>) n)
  (%set-line-cur! buf n)
  (update-pp-list! buf))

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
    (set-pd-cur! buf n)
    (update-pp-cur! buf)
    (synchronize-pp! buf)]
   [(eq? device 'presentation)
    (let ([ind (list-index (lambda (x) (> x n)) (get-pp-list buf))])
      (set-pp-goal! buf n)
      (if ind
	  (set-pd-cur! buf (max 0 (1- ind)))
	  ;; else
	  (set-pd-cur! buf (last (get-pp-list buf))))
      (update-pp-cur! buf))]
   [else
    (error "FIXME !!#!")]))

(define-method (set-text-cur! (buf <CBuffer>) str)
  (list-set! (get-text buf) (get-line-cur buf) str))

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
      (format #t "~a!!!~%" pp2)
      pp2)]))

(define-method (update-pp-cur! (buf <CBuffer>))
  "Sets the active presentation position to the match the beginning
of the character at the active data position"
  (set-pp-cur! buf (list-ref (get-pp-list buf) (get-pd-cur buf))))

(define-method (update-pp-list! (buf <CBuffer>))
  (set-pp-list! buf 
		(compute-pp-list-from-string (get-text-cur buf) 
					     (get-tab-size buf))))

;; METHODS

(define-method (backspace (buf <CBuffer>))
  "Move the active data position to the previous data position"
  (when (> (get-pd-cur buf) 0)
    (increase-pd-cur! buf -1))
  (update-pp-cur! buf)
  (synchronize-pp! buf))

(define-method (carriage-return (buf <CBuffer>))
  "Move the active presentation position to the line home position of
the same line"
  (set-positions! buf 0 'data))

(define-method (character-position-absolute (buf <CBuffer>) n)
  "Move the active data position to the n-th codepoint in the active
line"
  (let* ([pd (bracket-pd buf n)])
    (set-positions! buf pd 'data)))

(define-method (character-position-backward (buf <CBuffer>) n)
  "Move the active data position backward n codepoints"
  (let* ([pd (bracket-pd buf (- (get-pos-cur buf) n))])
    (set-positions! buf pd 'data)))

(define-method (character-position-forward (buf <CBuffer>) n)
  "Move the active data position forward n codepoints"
  (let* ([pd (bracket-pd (+ (get-pos-cur buf) n))])
    (set-positions! buf pd 'data)))

(define-method (character-and-line-position (buf <CBuffer>) n m)
  "Moves the active data position to the n-th line position m-th
character position"
  (set-line-cur! (bracket-line buf n))
  (update-pp-list! buf)
  (character-position-absolute (buf m)))

(define-method (cursor-backward-tabulation (buf <CBuffer>) n)
    "Move the active presentation position to the character position
corresponding to the n-th preceding character tabulation stop in the
presentation component"
    (let* ([ppCur (get-pp-cur buf)]
           [tabsize (get-tab-size buf)]
           ;; Back up n tabsizes
           [pp1 (max 0 (compute-tab-column ppCur tabsize (- n)))])
      (set-positions! buf pp1 'presentation)))

(define-method (cursor-character-absolute (buf <CBuffer>) n)
    "Move the active presentation position to character position n in
the active line in the presentation component"
    (set-positions! buf n 'presentation))

(define-method (cursor-down (buf <CBuffer>) n)
  "Move the active presentation position downwards in the presentation
component by N line positions"
  (let* ( ;; Move forward n lines, or to the end of the buffer
         [L1 (bracket-line buf (+ (get-line-cur buf) n))])
    (set-line-cur! buf L1)
    (update-pp-list! buf)
    (set-positions! buf (get-pp-cur buf) 'presentation)))

(define-method (cursor-forward-tabulation (buf <CBuffer>) n)
    "Move the active presentation position to the character position
corresponding to the n-th following character tabulation stop in the
presentation component"
    (let* ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))]
           ;; Move forward n tabsizes
           [tabsize (get-tab-size buf)]
           [pp (compute-tab-column (get-pp-cur buf) tabsize n)])
      (set-positions! buf pp 'presentation)))

(define-method (cursor-left (buf <CBuffer>) n)
  "Move the active presentation position leftwards in the presentation
component by n character positions"
  (set-positions! buf (max 0 (- (get-pp-goal buf) n)) 'presentation))

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

(define (cursor-right buf n)
  "Move the active presentation position rightwards in the
presentation component by n character positions"
  (set-positions! buf (min (get-pp-max buf)
			   (+ (get-pp-goal buf) n))
		  'presentation))

(define (cursor-position buf n m)
  "Move the active presentation position to the n-th line and m-th
character position in the presentation component"
  (set-line-cur! buf (bracket-line buf n))
  (update-pp-list! buf)
  (set-positions! buf m 'position))

(define (cursor-up buf n)
  "Move the active presentation positions upwards in the presentation
component by N line positions"
  (let* (
         ;; Move backward n lines, or to the top of the buffer
         [L1 (bracket-line buf (- (get-line-cur buf) n))])
    (set-line-cur! buf L1)
    (update-pp-list! buf)
    (set-positions! buf (get-pp-cur buf) 'presentation)))


(define-method (delete-character buf)
  "This removes the character at the active data position.  The
characters to the right of the active data position are moved left to
fill in the gap.  If the active data position it at the end of the
line, nothing happens."
  (let ([txt (get-text-cur buf)]
	[pd (get-pd-cur buf)]
	[len (get-text-cur-length)])
    (cond
     [(= len 0)
      *unspecified*]
     [(= pd len)
      *unspecified*]
     [(= pd 0)
      (set-text-cur! buf (string-drop txt 1))]
     [else
      (set-text-cur! buf (string-append (string-take txt (1- pd))
					(string-drop txt pd)))])
    (update-pd-list! buf)
    (set-positions! buf pd 'data)))

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
      (update-pd-list! buf)
      (set-positions! buf pd 'data)]
     [(= P 1)
      (set-text-cur! buf (string-drop (1+ pd)))
      (update-pd-list! buf)
      (set-positions! buf 0 'data)]
     [(= P 2)
      (set-text-cur! buf "")
      (update-pd-list! buf)
      (set-positions! buf 0 'data)]
     [else
      (error "FIXME")])))

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
					      (string-drop txt (1+pd))))))])
    (update-pd-list! buf)
    (set-positions! buf 0 'presentation)))

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

  ;;(add-undo (list 'EL device P (get-line-cur buf) (get-pd-cur buf) (get-line-text buf)))

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
      (when (and (is-mark-enabled? buf)
                 (= (get-line-cur buf) (get-line-mark buf))
                 (>= pd-mark pd-cur))
        (set-mark-flag! buf #f))]
     [(and (eqv? device 'data) (= P 0))
      (set-text! buf (string-append (string-take text-cur pd-cur)
                                    (make-string (- (string-length text-cur) pd-cur) #\space)))
      ;; Clear the mark if its position has been erased
      (when (and (is-mark-enabled? buf)
                 (= (get-line-cur buf) (get-line-mark buf))
                 (>= pd-mark pd-cur))
        (set-mark-flag! buf #f))]

     ;; Erase from the beginning of the line to here
     [(and (eqv? device 'presentation) (= P 1))
      (when (and (is-mark-enabled? buf)
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
      (when (and (is-mark-enabled? buf)
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
      (when (and (is-mark-enabled? buf)
                 (= (get-line-cur buf) (get-line-mark buf)))
        (set-mark-flag! buf #f))
      ;; Erase the line
      (set-text! buf (make-string (last ppList)))
      (set-pd-cur! pp-cur)]
     [(and (eqv? device 'data) (= P 2))
      ;; If the mark is on this line, erase it
      (when (and (is-mark-enabled? buf)
                 (= (get-line-cur buf) (get-line-mark buf)))
        (set-mark-flag! buf #f))
      ;; Erase the line
      (set-text! buf (make-string (string-length text-cur) #\space))
      (set-pp-cur! pd-cur)
      (set-pp-goal! pd-cur)])))


(define-method (insert-character-space (buf <CBuffer>) n)
  "Shift the contents of the line to the right, starting at the
current data position, creating an empty gap of N codepoints"
  ;;(add-undo (list 'ICH n (get-line-cur buf) (get-pd-cur buf)))

  (let ([str (get-line-cur buf)]
        [pd (get-pd-cur buf)])
    (set-line-cur! buf (string-take str pd) (make-string n #\space) (string-drop str pd))

    ;; Move the mark right, if necessary
    (when (and (is-mark-set? buf)
               (= (get-line-mark) (get-line-cur))
               (>= (get-pd-mark) (get-pd-cur)))
      (set-pd-mark! (+ (get-pd-mark) n)))))

(define-method (insert-line-space (buf <CBuffer>) n)
  "Move the current line and the n-1 following lines down N lines.
The resulting cap is erased.  The cursor is placed at the home
position of the first new empty line."
  ;;(add-undo buf (list 'IL n (get-line-cur) (get-pd-cur)))

  (let ([txt (get-text buf)]
        [L (get-line-cur buf)])
    (set-text! buf (append (take txt L)
                           (make-list n "")
                           (drop txt L)))
    (set-pd-cur! 0)
    (set-pp-cur! 0)
    (set-pp-goal! 0)

    ;; Move the mark down, if necessary
    (when (and (is-mark-set? buf)
               (>= (get-line-mark) L))
      (set-line-mark! (+ (get-line-mark) n)))))

(define-method (insert-nel (buf <CBuffer>) c)
  "Removes the text between the active position and the end of the
line from the current line, and places it in a new line inserted after
the current line.  The active position is moved to the beginning of
the new line."
  (let ([txt (get-text buf)]
        [txtcur (get-text-cur buf)]
        [pd (get-pd-cur buf)]
        [L (get-line-cur buf)])
    (set-text! buf (append (take txt (max 0 (1- L)))
                           (string-take txtcur pd)
                           (string-drop txtcur pd)
                           (drop txt L)))
    ;; Move the mark down, if necessary
    (when (is-mark-set? buf)
      (cond
       [(and (= (get-line-mark buf) L) (>= (get-pd-mark buf) pd))
        (set-line-mark! buf (1+ L))
        (set-pd-mark! buf (- (get-pd-mark) pd))]
       [(>= (get-line-mark buf) L)
        (set-line-mark! buf (1+ l))]))

    (set-pd-cur! 0)
    (set-pp-cur! 0)
    (set-pp-goal! 0)
    (set-line-cur! (1+ L))))


(define-method (line-position-absolute (buf <CBuffer>) n)
  "Move the active data position to the n-th line"
  (set-line-cur! (min n (get-line-max)))
  (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))])
    (set-pp-cur! (list-ref ppList (get-pd-cur)))
    (set-pp-goal! (get-pp-cur))))

(define-method (line-position-backward (buf <CBuffer>) n)
  "Move the active data position up n line positions"
  (set-line-cur! (max 0 (- (get-line-cur) n)))
  (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))])
    (set-pp-cur! (list-ref ppList (get-pd-cur)))
    (set-pp-goal! (get-pp-cur))))

(define-method (line-position-forward (buf <CBuffer>) n)
  "Move the active data position down by n line positions"
  (set-line-cur! (min (+ (get-line-cur) n) (get-line-max)))
  (let ([ppList (compute-pp-list-from-string (get-text-cur buf) (get-tab-size buf))])
    (set-pp-cur! (list-ref ppList (get-pd-cur)))
    (set-pp-goal! (get-pp-cur))))

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
  (set-line-frame! (max 0 (- (get-line-frame) n))))

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
  (set-line-frame! (min (1- (get-line-count)) (- (get-line-frame) n))))

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
      ;; Clear the mark if we're overwriting the mark
      (when (and (is-mark-enabled? buf)
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

      (format #t "write-char pd-cur ~s pd-start ~s pd-end ~s pp-cur ~s pp-start ~s pp-end ~s space ~s;~s~%" (get-pd-cur buf) pd-start pd-end (get-pp-cur buf) pp-start pp-end space-before-char space-after-char)
      ;; Replace the tab characters with spaces
      (set-text-cur! buf (string-append (string-take txt pd-start)
                                        (make-string space-before-char #\space)
                                        (string c)
                                        (make-string space-after-char #\space)
                                        (string-drop txt pd-end)))
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
    (when (and (is-mark-enabled? buf)
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
      (when (and (is-mark-enabled? buf)
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; UTILITIES

(define (compute-pp-list-from-string str tabsize)
  (let loop ([pp 0] [lst '()] [str str])
    (cond
     [(not (string-null? str))
      (loop (+ pp (count-cells-in-char (string-ref str 0) pp tabsize))
            (append lst (list pp))
            (string-drop str 1))]
     [else
      ;; return list
      (append lst (list pp))])))

(define (count-cells-in-char chr x tabSize)
  "Number of cells a character CHR at column X would take up"
  (cond
   [(eqv? chr #\nul)
    0]
   [(eqv? chr #\tab)
    (- tabSize (modulo x tabSize))]
   [(is-control-char? chr)
    ;; Add 1 for the caret '^'
    (1+ (wcwidth (get-display-char-from-control-char chr)))]
   [else
    (wcwidth chr)]))

(define (count-cells-in-string str xstart tabsize)
  "Number of screen cells occupied by the characters in a string"
  (let ([iLim (string-length str)]
        [x xstart])
    (do ([i 0 (1+ i)]) ([>= i iLim])
      (set! x (+ x (count-cells-in-char (string-ref str i) x tabsize))))
    ;; (format (current-error-port) "CountCellsInString: str ~s count ~s~%" str x)
    (- x xstart)))

(define (count-cells-in-substring str n xstart tabsize)
  "Return the number of screen cells occupied by the first N
characters of a string, assuming that the first string character is a
the presentation position XSTART with a given TABSIZE"
  (count-cells-in-string (substring str 0 n) xstart tabsize))

(define (get-display-char-from-control-char c)
  "The character to use when displaying controls in \"^X\" form"
  (integer->char (+ (char->integer c) 64)))

(define (is-control-char? c)
  "#t if this is an ISO control character"
  (char-set-contains? char-set:iso-control c))


(define (AppendBufferMagicLine)
  (SetBufferLines! (append (GetBufferLines)
                             (list ""))))

  (define (GetBufferCCur)
    (+ (GetBufferPdCur)
       (if (> (GetBufferLCur) 0)
           (fold 0 (lambda (line count)
                     (+ count (string-length line)))
                 (take (GetBufferLines) (1- (GetBufferLCur))))
           0)))

  (define (GetBufferCMax)
    (fold 0 (lambda (line count)
              (+ count (string-length line)))
          (GetBufferLines)))

  (define (GetBufferFileName)
    (slot-ref (Buf) 'm_fileName))

  (define (GetBufferLCur)
    (slot-ref (Buf) 'm_LCur))

  (define (GetBufferLFrame)
    (slot-ref (Buf) 'm_LFrame))

  (define (GetBufferLMark)
    (slot-ref (Buf) 'm_LMark))

  (define (GetBufferLLim)
    (length (slot-ref (Buf) 'm_rgText)))

  (define (GetBufferLineCur)
    (list-ref (slot-ref (Buf) 'm_rgText) (slot-ref (Buf) 'm_LCur)))

  (define (GetBufferLine index)
    (list-ref (slot-ref (Buf) 'm_rgText) index))

  (define (GetBufferLines)
    (slot-ref (Buf) 'm_rgText))

  (define (GetBufferTotalSize)
    (slot-ref (Buf) 'm_totalSize))

  (define (GetBufferPdCur)
    (slot-ref (Buf) 'm_PdCur))

  (define (GetBufferPpGoal)
    (slot-ref (Buf) 'm_PpGoal))

  (define (GetBufferPdMark)
    (slot-ref (Buf) 'm_PdMark))

  (define (GetBufferYCur)
    (slot-ref (Buf) 'm_yCur))

  (define (IncreaseBufferTotalSize! n)
    (SetBufferTotalSize! (+ n (GetBufferTotalSize))))

  (define (IncreaseBufferLCur! n)
    (SetBufferLCur! (+ n (GetBufferLCur))))

  (define (IncreaseBufferLFrame! n)
    (SetBufferLFrame! (+ n (GetBufferLFrame))))

  (define (IncreaseBufferLMark! n)
    (SetBufferLMark! (+ n (GetBufferLMark))))


  (define (IncreaseBufferPdMark! n)
    (SetBufferPdMarkBegin! (+ n (GetBufferPdMark))))

  (define (IncreaseBufferPdCur! n)
    (SetBufferPdCur! (+ n (GetBufferPdCur))))

  (define (IsBufferMarkSet?)
    (slot-ref (Buf) 'm_fMarkSet))

  (define (IsBufferModified?)
    (slot-ref (Buf) 'm_fModified))

  (define-method (SetBufferModified! flag)
    (slot-set! (Buf) 'm_fModified flag))

  (define-method (SetBufferFileName! (fileName <string>))
    (slot-set! (Buf) 'm_fileName fileName))

  (define-method (SetBufferLCur! (index <number>))
    (slot-set! (Buf) 'm_LCur index))

  (define-method (SetBufferLFrame! (index <number>))
    (slot-set! (Buf) 'm_LFrame index))

  (define-method (SetBufferLMark! (index <number>))
    (slot-set! (Buf) 'm_LMark index))

  (define-method (SetBufferLines! rgText)
    (slot-set! (Buf) 'm_rgText rgText))

  (define-method (SetBufferTotalSize! (size <number>))
    (slot-set! (Buf) 'm_totalSize size))

  (define-method (SetBufferPdCur! (index <number>))
    (slot-set! (Buf) 'm_PdCur index))

  (define-method (SetBufferPpGoal! (index <number>))
    (slot-set! (Buf) 'm_PpGoal index))

  (define-method (SetBufferXMarkBegin! (index <number>))
    (slot-set! (Buf) 'm_PdMark index))

  (define-method (SetBufferYCur! (index <number>))
    (slot-set! (Buf) 'm_yCur index))

  (define-method (SetBufferLineCur! (text <string>))
    (list-set! (slot-ref (Buf) 'm_rgText) (slot-ref (Buf) 'm_LCur) text))

  ;; -------------------

  (define (BufferCursorDown)
    "Move the active presentation position downwards in the presentation
component by N line positions"
    (let* ([LCur (GetBufferLCur)]
           [L1 (min (GetBufferLLim) (+ LCur n))])
      (SetBufferLCur! L1)
      (let ([ppList (ComputePpListFromString (GetBufferLineCur))]
            ;; Find the data position of this column.  If there is not
            ;; data at this column, move to the last character's position.
            [pd (or (1- (find (lambda (x) (> x pp)) ppList))
                    (last ppList))]
            ;; Adjust leftward if we're in the middle of a character
            [pp (list-ref ppList index)])
        (SetBufferPdCur! pd)
        (SetBufferPpCur! pp)
        ;; The goal column is unchanged
        )))

  (define (BufferCursorRight n)
    "Move the active presentation position rightwards in the presentation
component by n character positions"
    (let* ([ppList (ComputePpListFromString (GetBufferLineCur))]
           ;; Move right N screen cells
           [pp (min (last ppList) (+ (GetBufferPpCur) n))]
           ;; Adjust leftward if we're in the middle of a character
           [pd (or (1- (find (lambda (x) (> x pp) ppList)))
                   (last ppList))]
           [pp2 (list-ref ppList pd)])
      (SetBufferPdCur! pd)
      (SetBufferPpCur! pp2)
      (SetBufferPpGoal! n)))

  (define (BufferCursorPosition n m)
    "Move the active presentation position to the n-th line and m-th
character position in the presentation component"
    (let* ([L1 (min n (GetBufferLLim))])
      (SetBufferLineCur! L1)
      (let* ([ppList (ComputePpListFromString (GetBufferLineCur))]
             ;; Find the character at this location, or the last character
             ;; if this location is to the right of all characters
             [pd (or (1- (find (lambda (x) (> x m) ppList)))
                     (last ppList))]
             [pp (list-ref ppList pd)])
        (SetBufferPdCur! pd)
        (SetBufferPpCur! pp)
        (SetBufferPpGoal! pos))))

  (define (BufferCursorUp n)
    "Move the active presentation position upwards in the presentation
component by N line positions"
    (let* ([LCur (GetBufferLCur)]
           [L1 (max 0 (- LCur n))])
      (SetBufferLCur! L1)
      (let ([ppList (ComputePpListFromString (GetBufferLineCur))]
            ;; Find the data position of this column.  If there is not
            ;; data at this column, move to the last character's position.
            [pd (or (1- (find (lambda (x) (> x pp)) ppList))
                    (last ppList))]
            ;; Adjust leftward if we're in the middle of a character
            [pp (list-ref ppList index)])
        (SetBufferPdCur! pd)
        (SetBufferPpCur! pp)
        ;; The goal column is unchanged
        )))

  ;; BufferCursorLineTabulation - unimplemented

  (define (BufferDeleteCharacter n)
    "If the Device Component Select Mode is 'presentation: delete the
contents of the current presentation position and of the n-1 preceding
character cells.  The gap is closed by shifting the contents of the
adjacent character positions to the left.  If the Device Component
Select Mode is 'data, it is the n-1 preceding character that are
deleted instead."
    (cond
     [(eqv? (GetDeviceComponentSelectMode) 'presentation)
      ;; Delete the current cells and n-1 cells to the left
      (let* ([str (GetBufferLineCur)]
             [ppList (ComputePpListFromString str)]
             [pp (max 0 (- (GetBufferPpCur) n))]
             ;; Find the data position of this column.
             [pd (or (1- (find (lambda (x) (> x pp))) ppList)
                     (last ppList))]
             ;; Adjust if we're in the middle of a character
             [pp2 (list-ref ppList pd)])
        (SetBufferLineCur! (string-take str pd)
                           (string-drop str (GetBufferPdCur)))
        (SetBufferPdCur! pd)
        (SetBufferPpCur! pp2)
        (SetBufferPpGoal! pp))]
     [else
      ;; Delete the current character and n-1 characters to the left
      (let* ([str (GetBufferLineCur)]
             [ppList (ComputePpListFromString str)]
             [pd (max 0 (- (GetBufferPdCur) n))]
             ;; Find the presentation position of this column.
             [pp (list-ref ppList pd)])
        (SetBufferLineCur! (string-take str pd)
                           (string-drop str (GetBufferPdCur)))
        (SetBufferPdCur! pd)
        (SetBufferPpCur! pp)
        (SetBufferPpGoal! pp))]))

  (define (BufferDeleteLine n)
    "Delete the active line and the n-1 following lines.  The resulting
gap is closed by shifting the contents following the deleted lines
toward the active line.  The position is move to the line home position."
    #t)

  (define (BufferEraseCharacter n)
    #t)

  (define (BufferEraseInLine n)
    #f)

  (define (BufferFormFeed n)
    #t)

  (define (BufferCharacterPositionAbsolute n)
    #t)

  (define (BufferCharacterPositionBackward n)
    #t)

  (define (BufferCharacterPositionForward n)
    #t)

  (define (BufferCharacterTabulation)
    #t)

  (define (BufferCharacterAndLinePosition n m)
    #t)

  (define (BufferInsertCharacter n)
    #t)

  (define (BufferInsertLine n)
    #t)

  (define (BufferJustify n)
    #t)

  (define (BufferLineFeed)
    #t)

  (define (BufferNextLine)
    #t)

  (define (BufferNextPage)
    #t)

  (define (BufferPrecedingPage n)
    #t)

  (define (BufferPagePositionAbsolute n)
    #t)

  (define (BufferPagePositionBackward n)
    #t)

  (define (BufferPagePositionForward n)
    #t)

  (define (BufferQuad n)
    #t)

  (define (BufferReverseLineFeed)
    #t)

  (define (BufferResetToInitialState)
    #t)

  (define (BufferScrollDown n)
    #t)

  (define (BufferScrollLeft n)
    #t)

  (define (BufferScrollRight n)
    #t)

  (define (BufferScrollUp n)
    #t)

  (define (BufferLinePositionAbsolute n)
    #t)

  (define (BufferLinePositionBackward n)
    #t)

  (define (BufferLinePositionForward n)
    #t)
