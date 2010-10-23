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
  #:export (
            %DoDumpDebugInfo
            DoEnter
            DoInsertChar
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

(define (DoEnter)
  "Insert a newline at the cursor"

  ;; When autoindent is enabled, DoEnter also indents the line
  (let ([indent (if (ISSET AUTOINDENT)
                    (min (GetBufferXCur) (GetIndentILim (GetBufferLineTextCur)))
                    0)])
    ;; Update Model
    (InsertEnterModel)
    (do ([i 0 (1+ i)]) ([= i indent])
      (InsertCharModel #\space))

    ;; Update View
    (RefreshEditor)
    (set! vfEditRefresh #f)))

(define (DoInsertChar c)
  "Insert the character C at the cursor and advance the cursor"
  ;; Update Model
  (unless (IsAsciiControlChar? c)
    (InsertCharModel c))
  ;; Update View
  (cond
   [vfEditRefresh
    (RefreshEditor)
    (set! vfEditRefresh #f)]

   [else
    (UpdateLine (GetBufferICur) (GetBufferXCur))]))


;;;-------------------------------------------------------------
;;; MODEL UPDATE FUNCTIONS TO BE MOVED LATER

(define (InsertCharModel c)
  "Insert the character C into the buffer and advance the cursor."
  (let ([cCell (CountCellsInString (GetBufferLineTextCur))])

    ;; When a character is added to the last line, we need a new
    ;; last line.
    ;; (when (equal? (GetBufferICur) (1- (GetBufferILim)))
    ;;   (AppendBufferMagicLine))

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

(define (InsertEnterModel)
  (UpdateUndo 'enter)
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



