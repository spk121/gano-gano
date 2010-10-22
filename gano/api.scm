;;; These are the functions that are run as a result of keypresses

(define-module (gano api)
  #:export (
            DoInput
            ))

(define (DoInputModel c)
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

    ;; Add this insert to the Undo information
    (UpdateUndo 'add)

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

(define (DoInput c)
  "Insert the character C at the cursor and advance the cursor"
  (DoInputModel)
  (cond
   [vfEditRefresh
    (RefreshEditor)
    (set! vfEditRefresh #f)]

   [else
    (UpdateLine (GetBufferICur) (GetBufferXCur))]))
