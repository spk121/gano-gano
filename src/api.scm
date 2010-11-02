;;; These are the functions that are run as a result of keypresses

(define-module (gano api)
  #:use-module (gano config)
  #:use-module (gano CBuffer)
  #:use-module (gano CText)
  #:use-module (gano chars)
  #:use-module (gano utils)
  #:use-module (gano flags)
  #:use-module (gano global)
  #:use-module (gano winio)
  #:use-module (srfi srfi-1)
  #:use-module (ncurses curses)
  #:use-module (ice-9 optargs)
  #:export (
            %DoDumpDebugInfo
            DoCharDeleteLeft
            DoCharDelete
            DoCharInsert
            DoCharNext
            DoCharPrev
            DoEnter
            DoLineBeginning
            DoLineEnd
            DoLineFirst
            DoLineLast
            DoLineNext
            DoLinePrev
            DoPageNext
            DoPagePrev
            DoTotalRefresh
            DoScrollDown
            DoScrollUp
            ))

(if %have-rnrs-control
    (use-modules (rnrs control))
    (use-modules (gano control)))

;; STUBS
(define (UpdateUndo a . b) #t)
(define (DoWrap a) #t)

;; API
(define (%DoDumpDebugInfo fileName)
  "Write the current state of the editor to a file"
  (with-output-to-file fileName
    (lambda ()
      (display "Gano Debug File") (newline)
      (%DescribeBuffer)
      (for-each (lambda (x) (write x) (newline))
                (GetBufferLines)))))

(define (DoCharDeleteLeft)
  "Remove the character under the cursor"
  ;; Update Model
  (unless (and (= 0 (GetBufferLCur)) (= 0 (GetBufferPdCur)))
    (GoToCharPrevModel)
    (UpdateUndo 'del)
    (DeleteCharModel)
    ;; FIXME: only need to update a couple of lines
    (RefreshEditor)
    (set! vfEditRefresh #f)))

(define (DoCharDelete)
  "Remove the character under the cursor"
  ;; Update Model
  (UpdateUndo 'del)
  (DeleteCharModel)
  ;; FIXME: only need to update a couple of lines
  (RefreshEditor)
  (set! vfEditRefresh #f))

(define* (DoCharInsert c #:optional (fControlCharsOk #f))
  "Insert the character C at the cursor and advance the cursor"
  ;; Update Model
  (when (or (not (IsAsciiControlChar? c)) fControlCharsOk)
    (InsertCharModel c)
    ;; Add this insert to the Undo information
    (UpdateUndo 'add))
  ;; Update View
  ;; FIXME: only need to update one line
  (RefreshEditor)
  (set! vfEditRefresh #f))

(define (DoCharNext)
  "Move the cursor to the next character"
  ;; Update Model
  (GoToCharNextModel)
  ;; Update View
  ;; FIXME: only need to update a couple of lines
  (RefreshEditor)
  (set! vfEditRefresh #f))

(define (DoCharPrev)
  "Move the cursor to the previous character"
  ;; Update Model
  (GoToCharPrevModel)
  ;; Update View
  ;; FIXME: only need to update a couple of lines
  (RefreshEditor)
  (set! vfEditRefresh #f))

(define* (DoEnter #:optional (fUndoing #f))
  "Insert a newline at the cursor"

  ;; When autoindent is enabled, DoEnter also indents the line
  (let ([indent (if (ISSET AUTOINDENT)
                    (min (GetBufferPdCur) (GetIndentILim (GetBufferLineCur)))
                    0)])
    ;; Update Model
    (unless fUndoing
      (UpdateUndo 'enter))
    (InsertEnterModel)
    (do ([i 0 (1+ i)]) ([= i indent])
      (InsertCharModel #\space))

    ;; Update View
    (RefreshEditor)
    (set! vfEditRefresh #f)))

(define (DoLineBeginning)
  (GoToLineBeginningModel)
  (RefreshEditor))

(define (DoLineEnd)
  (GoToLineEndModel)
  (RefreshEditor))

(define (DoLineFirst)
  "Move to the first line of the file"

  ;; Update Model
  (GoToLineFirstModel)
  ;; Update View
  (RefreshEditor)
  (set! vfEditRefresh #f))

(define (DoLineLast)
  "Move to the last line of the file"

  ;; Update Model
  (GoToLineLastModel)
  ;; Update View
  (RefreshEditor)
  (set! vfEditRefresh #f))

(define* (DoLineNext #:optional fSmoothScroll)
  "Move down one line"
  ;; Update Model
  (GoToLineNextModel)
  ;; If we're at or after the bottom line of the edit window, scroll
  ;; down.
  (when (>= (GetBufferLCur) (+ editwinrows (GetBufferLFrame)))
    (if fSmoothScroll
        (ScrollDownModel)
        ;; else
        (ScrollDownModel (1+ (quotient editwinrows 2)))))

  ;; Update View
  ;; FIXME: replace this with a scrl and targeted updates
  (RefreshEditor)
  (set! vfEditRefresh #f))

(define* (DoLinePrev #:optional fSmoothScroll)
  "Move up one line"
  ;; Update Model
  (GoToLinePrevModel)
  ;; If we're at or before the top of the edit window, scroll up.
  (when (<= (GetBufferLCur) (GetBufferLFrame))
    (if fSmoothScroll
        (ScrollUpModel)
        ;; else
        (ScrollUpModel (1+ (quotient editwinrows 2)))))

  ;; Update View
  ;; FIXME: replace this with a scrl and targeted updates
  (RefreshEditor)
  (set! vfEditRefresh #f))

(define (DoPagePrev)
  "Move up one page"
  ;; Update Model
  (GoToPagePrevModel)
  ;; Update View
  (RefreshEditor)
  (set! vfEditRefresh #f))

(define (DoPageNext)
  "Move down one page"
  ;; Update Model
  (GoToPageNextModel)
  ;; Update View
  (RefreshEditor)
  (set! vfEditRefresh #f))

(define* (DoScrollDown #:optional (n 1))
  "Scroll the editor window down one line"
  ;; Update Model
  (ScrollDownModel n)
  ;; Update View
  ;; FIXME: replace this with a line scrl and fill in the  line
  (RefreshEditor)
  (set! vfEditRefresh #f))

(define* (DoScrollUp #:optional (n 1))
  "Scroll the editor window up one line"
  ;; Update Model
  (ScrollUpModel n)
  ;; Update View
  ;; FIXME: replace this with a line scrl and fill in the  line
  (RefreshEditor)
  (set! vfEditRefresh #f))

(define (DoTotalRefresh)
  "Unconditionally redraw the entire screen."

  (DisplayTitlebar "")
  (RefreshEditor)
  (DisplayShortcutList vMenuCur)
  (refresh vWinTop)
  (refresh vWinEdit)
  (refresh vWinBottom)
  ;;(refresh vWinMain)
  )

;;;-------------------------------------------------------------
;;; MODEL UPDATE FUNCTIONS TO BE MOVED LATER

(define (DeleteCharModel)
  "Remove the character at the current position"
  (SetBufferPpGoal! (GetPpFromBufferPdCur))
  (let ([str (GetBufferLineCur)]
        [xCur (GetBufferPdCur)])
    (cond

     ;; If we're at the end of the buffer, do nothing
     [(and (= (GetBufferLCur) (1- (GetBufferLLim)))
           (= xCur (string-length str)))
      *unspecified*]

     ;; If we're inside of a line, delete right
     [(< xCur (string-length str))
      (SetBufferLineCur! (string-append
                          (substring str 0 xCur)
                          (substring str (1+ xCur))))
      (IncreaseBufferTotalSize! -1)
      (when (and (IsBufferMarkSet?)
                 (= (GetBufferLCur) (GetBufferLMark))
                 (< (GetBufferPdCur) (GetBufferPdMark)))
        (IncreaseBufferPdMark! -1))]

     ;; Deleting the last character in the line appends the previous
     ;; line to this line
     [else
      (SetBufferLineCur! (string-append str (GetBufferLine (1+ (GetBufferLCur)))))
      (SetBufferLines!
       (append (take (GetBufferLines) (1+ (GetBufferLCur)))
               (drop (GetBufferLines) (+ 2 (GetBufferLCur)))))

      (when (IsBufferMarkSet?)
        (when (= (1+ (GetBufferLCur)) (GetBufferLMark))
          (IncreaseBufferPdMark! (GetBufferPdCur)))
        (IncreaseBufferLMark! -1))

      (IncreaseBufferTotalSize! -1)])))

(define (GoToCharNextModel)
  "Set the buffer's position to the next character in the buffer"

  (let ([xGoalSav (GetBufferPpGoal)])    ; Later, use to make hint
    (cond
     [(< (GetBufferPdCur) (string-length (GetBufferLineCur)))
      (IncreaseBufferPdCur! 1)]
     [(< (GetBufferLCur) (1- (GetBufferLLim)))
      (IncreaseBufferLCur! 1)
      (SetBufferPdCur! 0)])

    (SetBufferPpGoal! (GetPpFromBufferPdCur))))

(define (GoToCharPrevModel)
  "Set the buffer's position to the next character in the buffer"

  (let ([xGoalSav (GetBufferPpGoal)])    ; Later, use to make hint
    (cond
     [(> (GetBufferPdCur) 0)
      (IncreaseBufferPdCur! -1)]

     ;; If we're at the beginning of a line, go to the end
     ;; of the previous line.
     [(> (GetBufferLCur) 0)
      (IncreaseBufferLCur! -1)
      (SetBufferPdCur! (string-length (GetBufferLineCur)))])

    (SetBufferPpGoal! (GetPpFromBufferPdCur))))

(define (GoToLineBeginningModel)
  (SetBufferPdCur! 0)
  (SetBufferPpGoal! 0))

(define (GoToLineEndModel)
  (SetBufferPdCur! (string-length (GetBufferLineCur)))
  (SetBufferPpGoal! (GetPpFromBufferPdCur)))

(define (GoToLineFirstModel)
  "Set the buffer's position to the beginning of the buffer"
  (SetBufferLCur! 0)
  (SetBufferLFrame! 0)
  (SetBufferPdCur! 0)
  (SetBufferPpGoal! 0)
  (set! vfEditRefresh #t))

(define (GoToLineLastModel)
  "Set the buffer's position to the end of the buffer"
  (SetBufferLCur! (1- (GetBufferLLim)))
  (SetBufferPdCur! (max 0 (1- (string-length (GetBufferLineCur)))))
  (SetBufferPpGoal! (GetPpFromBufferPdCur))
  (SetBufferYCur! (1- editwinrows))
  (set! vfEditRefresh #t))

(define (GoToLineNextModel)
  "Set the buffer's position to the next line"
  (cond
  ;; Do nothing if we're already on the last line
   [(= (1- (GetBufferLLim)) (GetBufferLCur))
    *unspecified*]
   [(not (= (GetBufferYCur) (- (GetBufferLCur) (GetBufferLFrame))))
    (error "assertion failed: yCur is not correct")]
   [else
    ;; Move up down line, trying to keep the same screen column
    (IncreaseBufferLCur! 1)
    (SetBufferPdCur! (GetIndexFromStringCell (GetBufferLineCur) (GetBufferPpGoal)))]))

(define (GoToLinePrevModel)
  "Set the buffer's position to the previous line"
  (cond
  ;; Do nothing if we're already in the first line
   [(= 0 (GetBufferLCur))
    *unspecified*]
   [(not (= (GetBufferYCur) (- (GetBufferLCur) (GetBufferLFrame))))
    (error "assertion failed: yCur is not correct")]
   [else
    ;; Move up one line, trying to keep the same screen column
    (IncreaseBufferLCur! -1)
    (SetBufferPdCur! (GetIndexFromStringCell (GetBufferLineCur) (GetBufferPpGoal)))]))

(define (GoToPageNextModel)
  "Move the cursor down one page in the buffer"
  (cond
   ;; If we're on the last page of text, just move to the end of
   ;; the file.
   [(>= (GetBufferLCur) (- (GetBufferLLim) editwinrows 2))
    (SetBufferLCur! (1- (GetBufferLLim)))
    (SetBufferPdCur! (max 0 (1- (string-length (GetBufferLineCur)))))
    (SetBufferPpGoal! (GetPpFromBufferPdCur))
    (SetBufferYCur! (1- editwinrows))]

   [else
    ;; Scroll down one page, leaving the cursor in the first screen line
    (IncreaseBufferLCur! (- editwinrows 2))
    (SetBufferPdCur! (GetIndexFromStringCell (GetBufferLineCur) (GetBufferPpGoal)))
    (SetBufferLFrame! (GetBufferLCur))]))

(define (GoToPagePrevModel)
  "Move the cursor up one page in the buffer"
  (cond
   ;; If we're on the first page of text, just move to the beginning
   ;; of the file.
   [(<= (GetBufferLCur) (- editwinrows 2))
    (SetBufferLCur! 0)
    (SetBufferLFrame! 0)
    (SetBufferPdCur! 0)
    (SetBufferPpGoal! 0)]

   [else
    (IncreaseBufferLCur! (- 2 editwinrows))
    (SetBufferPdCur! (GetIndexFromStringCell (GetBufferLineCur) (GetBufferPpGoal)))
    (SetBufferLFrame! (GetBufferLCur))]))

(define (InsertCharModel c)
  "Insert the character C into the buffer and advance the cursor."
  (let ([cCell (CountCellsInString (GetBufferLineCur))])

    ;; When a character is added to the last line, we need a new
    ;; last line.
    (when (equal? (GetBufferLCur) (1- (GetBufferLLim)))
      (AppendBufferMagicLine))

    ;; Add the character to the line
    (SetBufferLineCur!
     (string-append (substring (GetBufferLineCur) 0 (GetBufferPdCur))
                    (string c)
                    (substring (GetBufferLineCur) (GetBufferPdCur))))

    ;; Move the mark to the right if we are inserting a character to the
    ;; left of the mark
    (when (and (IsBufferMarkSet?)
               (eqv? (GetBufferLMark) (GetBufferLCur))
               (< (GetBufferPdCur) (GetBufferPdMark)))
      (IncreaseBufferPdMark! 1))

    (IncreaseBufferPdCur! 1)
    (IncreaseBufferTotalSize! 1)
    (SetBufferModified! #t)

    ;; If we're hard wrapping, check wrapping now.  If we actually wrap
    ;; we'll need to refresh the whole screen.
    (unless (ISSET NO_WRAP)
      (set! vfEditRefresh (DoWrap (GetBufferLCur))))

    ;; If we're soft wrapping, and the line needs wrapping, we
    ;; need to refresh the whole screen.
    (when (and (ISSET SOFTWRAP)
               (not vfEditRefresh)
               (not (= (quotient (CountCellsInString (GetBufferLineCur)) (getmaxx))
                       (quotient cCell (getmaxx)))))
      (set! vfEditRefresh #t))

    (SetBufferPpGoal! (GetPpFromBufferPdCur))))

(define (InsertEnterModel)
  (let ([newLine (MakeLine "")])
    ;; Store the text after the cursor in a new line
    (set! newLine (substring (GetBufferLineCur) (GetBufferPdCur)))
    ;; Truncate the current line
    (SetBufferLineCur! (substring (GetBufferLineCur) 0 (GetBufferPdCur)))
    (SetBufferLines!
     (append (take (GetBufferLines) (1+ (GetBufferLCur)))
	     (list newLine)
	     (drop (GetBufferLines) (1+ (GetBufferLCur)))))

    ;; If the mark was on this line and after the cursor, move it
    (when (and (IsBufferMarkSet?)
	       (eq? (GetBufferLCur) (GetBufferLMark))
	       (< (GetBufferPdCur) (GetBufferPdMark)))
      (IncreaseBufferLMark! 1)
      (IncreaseBufferPdMark! (- (GetBufferPdCur))))

    (SetBufferPdCur! 0)
    (IncreaseBufferLCur! 1)
    (IncreaseBufferTotalSize! 1)
    (SetBufferModified! #t)
    (SetBufferPpGoal! (GetPpFromBufferPdCur))

    ;; Request a full repaint of the screen
    (set! vfEditRefresh #f)))

(define* (ScrollDownModel #:optional (n 1))
  (IncreaseBufferLFrame! (min n (- (GetBufferLLim) (GetBufferLFrame) 1))))

(define* (ScrollUpModel #:optional (n 1))
  "Decrement the edit window's top line line number"
    (IncreaseBufferLFrame! (- (min n (GetBufferLFrame)))))

