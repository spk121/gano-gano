;;; These are the functions that are run as a result of keypresses

(define-module (gano api)
  #:use-module (gano CBuffer)
  #:use-module (gano CText)
  #:use-module (gano chars)
  #:use-module (gano utils)
  #:use-module (gano flags)
  #:use-module (gano global)
  #:use-module (gano winio)
  #:use-module (srfi srfi-1)
  #:use-module (rnrs control)
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
      (for-each (lambda (x) (write (GetLineText x)) (newline))
                (GetBufferLines)))))

(define (DoCharDeleteLeft)
  "Remove the character under the cursor"
  ;; Update Model
  (unless (and (= 0 (GetBufferICur)) (= 0 (GetBufferXCur)))
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
                    (min (GetBufferXCur) (GetIndentILim (GetBufferLineTextCur)))
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
  (when (>= (GetBufferICur) (+ editwinrows (GetBufferIEditTop)))
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
  (when (<= (GetBufferICur) (GetBufferIEditTop))
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
  (SetBufferXGoal! (GetBufferXGoalFromXCur))
  (let ([str (GetBufferLineTextCur)]
        [xCur (GetBufferXCur)])
    (cond

     ;; If we're at the end of the buffer, do nothing
     [(and (= (GetBufferICur) (1- (GetBufferILim)))
           (= xCur (string-length str)))
      *unspecified*]

     ;; If we're inside of a line, delete right
     [(< xCur (string-length str))
      (SetBufferLineTextCur! (string-append
                              (substring str 0 xCur)
                              (substring str (1+ xCur))))
      (IncreaseBufferTotalSize! -1)
      (when (and (IsBufferMarkSet?)
                 (= (GetBufferICur) (GetBufferIMarkBegin))
                 (< (GetBufferXCur) (GetBufferXMarkBegin)))
        (IncreaseBufferXMarkBegin! -1))]

     ;; Deleting the last character in the line appends the previous
     ;; line to this line
     [else
      (SetBufferLineTextCur! (string-append str
                                            (GetLineText (GetBufferLine (1+ (GetBufferICur))))))
      (SetBufferLines!
       (append (take (GetBufferLines) (1+ (GetBufferICur)))
               (drop (GetBufferLines) (+ 2 (GetBufferICur)))))

      (when (IsBufferMarkSet?)
        (when (= (1+ (GetBufferICur)) (GetBufferIMarkBegin))
          (IncreaseBufferXMarkBegin! (GetBufferXCur)))
        (IncreaseBufferIMarkBegin! -1))

      (IncreaseBufferTotalSize! -1)])))

(define (GoToCharNextModel)
  "Set the buffer's position to the next character in the buffer"

  (let ([xGoalSav (GetBufferXGoal)])    ; Later, use to make hint
    (cond
     [(< (GetBufferXCur) (string-length (GetBufferLineTextCur)))
      (IncreaseBufferXCur! 1)]
     [(< (GetBufferICur) (1- (GetBufferILim)))
      (IncreaseBufferICur! 1)
      (SetBufferXCur! 0)])

    (SetBufferXGoal! (GetBufferXGoalFromXCur))))

(define (GoToCharPrevModel)
  "Set the buffer's position to the next character in the buffer"

  (let ([xGoalSav (GetBufferXGoal)])    ; Later, use to make hint
    (cond
     [(> (GetBufferXCur) 0)
      (IncreaseBufferXCur! -1)]

     ;; If we're at the beginning of a line, go to the end
     ;; of the previous line.
     [(> (GetBufferICur) 0)
      (IncreaseBufferICur! -1)
      (SetBufferXCur! (string-length (GetBufferLineTextCur)))])

    (SetBufferXGoal! (GetBufferXGoalFromXCur))))

(define (GoToLineBeginningModel)
  (SetBufferXCur! 0)
  (SetBufferXGoal! 0))

(define (GoToLineEndModel)
  (SetBufferXCur! (string-length (GetBufferLineTextCur)))
  (SetBufferXGoal! (GetBufferXGoalFromXCur)))

(define (GoToLineFirstModel)
  "Set the buffer's position to the beginning of the buffer"
  (SetBufferICur! 0)
  (SetBufferIEditTop! 0)
  (SetBufferXCur! 0)
  (SetBufferXGoal! 0)
  (set! vfEditRefresh #t))

(define (GoToLineLastModel)
  "Set the buffer's position to the end of the buffer"
  (SetBufferICur! (1- (GetBufferILim)))
  (SetBufferXCur! (max 0 (1- (string-length (GetBufferLineTextCur)))))
  (SetBufferXGoal! (GetBufferXGoalFromXCur))
  (SetBufferYCur! (1- editwinrows))
  (set! vfEditRefresh #t))

(define (GoToLineNextModel)
  "Set the buffer's position to the next line"
  (cond
  ;; Do nothing if we're already on the last line
   [(= (1- (GetBufferILim)) (GetBufferICur))
    *unspecified*]
   [(not (= (GetBufferYCur) (- (GetBufferICur) (GetBufferIEditTop))))
    (error "assertion failed: yCur is not correct")]
   [else
    ;; Move up down line, trying to keep the same screen column
    (IncreaseBufferICur! 1)
    (SetBufferXCur! (GetIndexFromStringCell (GetBufferLineTextCur) (GetBufferXGoal)))]))

(define (GoToLinePrevModel)
  "Set the buffer's position to the previous line"
  (cond
  ;; Do nothing if we're already in the first line
   [(= 0 (GetBufferICur))
    *unspecified*]
   [(not (= (GetBufferYCur) (- (GetBufferICur) (GetBufferIEditTop))))
    (error "assertion failed: yCur is not correct")]
   [else
    ;; Move up one line, trying to keep the same screen column
    (IncreaseBufferICur! -1)
    (SetBufferXCur! (GetIndexFromStringCell (GetBufferLineTextCur) (GetBufferXGoal)))]))

(define (GoToPageNextModel)
  "Move the cursor down one page in the buffer"
  (cond
   ;; If we're on the last page of text, just move to the end of
   ;; the file.
   [(>= (GetBufferICur) (- (GetBufferILim) editwinrows 2))
    (SetBufferICur! (1- (GetBufferILim)))
    (SetBufferXCur! (max 0 (1- (string-length (GetBufferLineTextCur)))))
    (SetBufferXGoal! (GetBufferXGoalFromXCur))
    (SetBufferYCur! (1- editwinrows))]

   [else
    ;; Scroll down one page, leaving the cursor in the first screen line
    (IncreaseBufferICur! (- editwinrows 2))
    (SetBufferXCur! (GetIndexFromStringCell (GetBufferLineTextCur) (GetBufferXGoal)))
    (SetBufferIEditTop! (GetBufferICur))]))

(define (GoToPagePrevModel)
  "Move the cursor up one page in the buffer"
  (cond
   ;; If we're on the first page of text, just move to the beginning
   ;; of the file.
   [(<= (GetBufferICur) (- editwinrows 2))
    (SetBufferICur! 0)
    (SetBufferIEditTop! 0)
    (SetBufferXCur! 0)
    (SetBufferXGoal! 0)]

   [else
    (IncreaseBufferICur! (- 2 editwinrows))
    (SetBufferXCur! (GetIndexFromStringCell (GetBufferLineTextCur) (GetBufferXGoal)))
    (SetBufferIEditTop! (GetBufferICur))]))

(define (InsertCharModel c)
  "Insert the character C into the buffer and advance the cursor."
  (let ([cCell (CountCellsInString (GetBufferLineTextCur))])

    ;; When a character is added to the last line, we need a new
    ;; last line.
    (when (equal? (GetBufferICur) (1- (GetBufferILim)))
      (AppendBufferMagicLine))

    ;; Add the character to the line
    (SetBufferLineTextCur!
     (string-append (substring (GetBufferLineTextCur) 0 (GetBufferXCur))
                    (string c)
                    (substring (GetBufferLineTextCur) (GetBufferXCur))))

    ;; Move the mark to the right if we are inserting a character to the
    ;; left of the mark
    (when (and (IsBufferMarkSet?)
               (eqv? (GetBufferIMarkBegin) (GetBufferICur))
               (< (GetBufferXCur) (GetBufferXMarkBegin)))
      (IncreaseBufferXMarkBegin! 1))

    (IncreaseBufferXCur! 1)
    (IncreaseBufferTotalSize! 1)
    (SetBufferModified! #t)

    ;; If we're hard wrapping, check wrapping now.  If we actually wrap
    ;; we'll need to refresh the whole screen.
    (unless (ISSET NO_WRAP)
      (set! vfEditRefresh (DoWrap (GetBufferICur))))

    ;; If we're soft wrapping, and the line needs wrapping, we
    ;; need to refresh the whole screen.
    (when (and (ISSET SOFTWRAP)
               (not vfEditRefresh)
               (not (= (quotient (CountCellsInString (GetBufferLineTextCur)) (getmaxx))
                       (quotient cCell (getmaxx)))))
      (set! vfEditRefresh #t))

    (SetBufferXGoal! (GetBufferXGoalFromXCur))))

(define (InsertEnterModel)
  (let ([newLine (MakeLine "")])
    ;; Store the text after the cursor in a new line
    (SetLineText! newLine (substring (GetBufferLineTextCur) (GetBufferXCur)))
    ;; Truncate the current line
    (SetBufferLineTextCur! (substring (GetBufferLineTextCur) 0 (GetBufferXCur)))
    (SetBufferLines!
     (append (take (GetBufferLines) (1+ (GetBufferICur)))
	     (list newLine)
	     (drop (GetBufferLines) (1+ (GetBufferICur)))))

    ;; If the mark was on this line and after the cursor, move it
    (when (and (IsBufferMarkSet?)
	       (eq? (GetBufferICur) (GetBufferIMarkBegin))
	       (< (GetBufferXCur) (GetBufferXMarkBegin)))
      (IncreaseBufferIMarkBegin! 1)
      (IncreaseBufferXMarkBegin! (- (GetBufferXCur))))

    (SetBufferXCur! 0)
    (IncreaseBufferICur! 1)
    (IncreaseBufferTotalSize! 1)
    (SetBufferModified! #t)
    (SetBufferXGoal! (GetBufferXGoalFromXCur))

    ;; Request a full repaint of the screen
    (set! vfEditRefresh #f)))

(define* (ScrollDownModel #:optional (n 1))
  (IncreaseBufferIEditTop! (min n (- (GetBufferILim) (GetBufferIEditTop) 1))))

(define* (ScrollUpModel #:optional (n 1))
  "Decrement the edit window's top line line number"
    (IncreaseBufferIEditTop! (- (min n (GetBufferIEditTop)))))

