(define-module (gano CBuffer)
  #:use-module (oop goops)
  #:use-module (oop goops describe)
  #:use-module (gano CText)
  #:use-module (gano CSyntax)
  #:use-module (gano CColor)
  #:use-module (srfi srfi-1)
  #:export (
            %DescribeBuffer
            Buf
            Buf?
            Buf!
	    <CBuffer>
            vrgBuffers
            AppendBufferMagicLine
            GetBufferCCur
            GetBufferCMax
            GetBufferFileName
            GetBufferICur
            GetBufferIEditTop
            GetBufferIMarkBegin
            GetBufferILim
            GetBufferLineCur
            GetBufferLine
            GetBufferLineTextCur
            GetBufferLines
            GetBufferTotalSize
            GetBufferXCur
            GetBufferXGoal
            GetBufferXMarkBegin
            GetBufferYCur
            IncreaseBufferTotalSize!
            IncreaseBufferICur!
            IncreaseBufferIEditTop!
            IncreaseBufferIMarkBegin!
            IncreaseBufferXMarkBegin!
            IncreaseBufferXCur!
            IsBufferMarkSet?
            IsBufferModified?
            SetBufferFileName!
            SetBufferICur!
            SetBufferIEditTop!
            SetBufferIMarkBegin!
            SetBufferLineTextCur!
            SetBufferLines!
            SetBufferModified!
            SetBufferTotalSize!
            SetBufferXCur!
            SetBufferYCur!
            SetBufferXGoal!
	    ))

(define-class <CBuffer> ()
  (m_fileName #:init-value "")
  (m_rgLines #:init-thunk (lambda () (list (make <CText>))))
  (m_iEditTop #:init-value 0)
  (m_iCur #:init-value 0)
  (m_totalSize #:init-value 0)
  (m_xCur #:init-value 0)
  (m_yCur #:init-value 0)
  (m_xGoal #:init-value 0)
  (m_fModified #:init-value #f)
  (m_fMarkSet #:init-value #f)
  (m_iMarkBegin #:init-value 0)
  (m_xMarkBegin #:init-value 0)
  (m_fileFormat #:init-value 'nix)
  (m_statCur #:init-value #f)
  (m_undo #:init-value '())
  (m_iUndoCur #:init-value 0)
  (m_lastAction #:init-value 'other)
  (m_syntaxes #:init-thunk (lambda () (list (make <CSyntax>))))
  (m_colorStrings #:init-thunk (lambda () (list (make <CColor>)))))

;; The list of open files aka buffers
(define vrgBuffers '())
;; The current buffer
(define viBuffer 0)

(define vfBuf #f)

(define (Buf!)
  (set! vfBuf #t))

(define (Buf)
  (cond
   [(null? vrgBuffers)
    (format (current-error-port) "vrgBuffers is null~%")
    #f]
   [(eqv? #f vrgBuffers)
    (format (current-error-port) "vrgBuffers is false~%")
    #f]
   [else
    ;;(format (current-error-port) "vrgBuffers[~s] is ~s~%" viBuffer vrgBuffers)
    (list-ref vrgBuffers viBuffer)]))

(define (Buf?)
  vfBuf)

(define (%DescribeBuffer)
  (if (Buf?)
      (describe (Buf))
      (display "There are no buffers.\n")))

(define (AppendBufferMagicLine)
  (SetBufferLines! (append (GetBufferLines)
                           (list (MakeLine "")))))

(define (GetBufferCCur)
  (+ (GetBufferXCur)
     (if (> (GetBufferICur) 0)
         (fold 0 (lambda (line count)
                   (+ count (string-length (GetLineText line))))
               (take (GetBufferLines) (1- (GetBufferICur))))
         0)))

(define (GetBufferCMax)
  (fold 0 (lambda (line count)
            (+ count (string-length (GetLineText line))))
        (GetBufferLines)))

(define (GetBufferFileName)
  (slot-ref (Buf) 'm_fileName))

(define (GetBufferICur)
  (slot-ref (Buf) 'm_iCur))

(define (GetBufferIEditTop)
  (slot-ref (Buf) 'm_iEditTop))

(define (GetBufferIMarkBegin)
  (slot-ref (Buf) 'm_iMarkBegin))

(define (GetBufferILim)
  (length (slot-ref (Buf) 'm_rgLines)))

(define (GetBufferLineCur)
  (list-ref (slot-ref (Buf) 'm_rgLines) (slot-ref (Buf) 'm_iCur)))

(define (GetBufferLineTextCur)
  (GetLineText (list-ref (slot-ref (Buf) 'm_rgLines) (slot-ref (Buf) 'm_iCur))))

(define (GetBufferLine index)
  (list-ref (slot-ref (Buf) 'm_rgLines) index))


(define (GetBufferLines)
  (slot-ref (Buf) 'm_rgLines))

(define (GetBufferTotalSize)
  (slot-ref (Buf) 'm_totalSize))

(define (GetBufferXCur)
  (slot-ref (Buf) 'm_xCur))

(define (GetBufferXGoal)
  (slot-ref (Buf) 'm_xGoal))

(define (GetBufferXMarkBegin)
  (slot-ref (Buf) 'm_xMarkBegin))

(define (GetBufferYCur)
  (slot-ref (Buf) 'm_yCur))

(define (IncreaseBufferTotalSize! n)
  (SetBufferTotalSize! (+ n (GetBufferTotalSize))))

(define (IncreaseBufferICur! n)
  (SetBufferICur! (+ n (GetBufferICur))))

(define (IncreaseBufferIEditTop! n)
  (SetBufferIEditTop! (+ n (GetBufferIEditTop))))

(define (IncreaseBufferIMarkBegin! n)
  (SetBufferIMarkBegin! (+ n (GetBufferIMarkBegin))))


(define (IncreaseBufferXMarkBegin! n)
  (SetBufferXMarkBegin! (+ n (GetBufferXMarkBegin))))

(define (IncreaseBufferXCur! n)
  (SetBufferXCur! (+ n (GetBufferXCur))))

(define (IsBufferMarkSet?)
  (slot-ref (Buf) 'm_fMarkSet))

(define (IsBufferModified?)
  (slot-ref (Buf) 'm_fModified))

(define-method (SetBufferModified! flag)
  (slot-set! (Buf) 'm_fModified flag))

(define-method (SetBufferFileName! (fileName <string>))
  (slot-set! (Buf) 'm_fileName fileName))

(define-method (SetBufferICur! (index <number>))
  (slot-set! (Buf) 'm_iCur index))

(define-method (SetBufferIEditTop! (index <number>))
  (slot-set! (Buf) 'm_iEditTop index))

(define-method (SetBufferIMarkBegin! (index <number>))
  (slot-set! (Buf) 'm_iMarkBegin index))

(define-method (SetBufferLines! rgLines)
  (slot-set! (Buf) 'm_rgLines rgLines))

(define-method (SetBufferTotalSize! (size <number>))
  (slot-set! (Buf) 'm_totalSize size))

(define-method (SetBufferXCur! (index <number>))
  (slot-set! (Buf) 'm_xCur index))

(define-method (SetBufferXGoal! (index <number>))
  (slot-set! (Buf) 'm_xGoal index))

(define-method (SetBufferXMarkBegin! (index <number>))
  (slot-set! (Buf) 'm_xMarkBegin index))

(define-method (SetBufferYCur! (index <number>))
  (slot-set! (Buf) 'm_yCur index))

(define-method (SetBufferLineTextCur! (text <string>))
  (SetLineText! (list-ref (slot-ref (Buf) 'm_rgLines) (slot-ref (Buf) 'm_iCur)) text))
