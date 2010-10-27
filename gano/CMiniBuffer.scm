(define-module (gano CMiniBuffer)
  #:use-module (oop goops)
  #:use-module (oop goops describe)
  #:use-module (gano CText)
  #:use-module (gano CSyntax)
  #:use-module (gano CColor)
  #:use-module (srfi srfi-1)
  #:export (
            %DescribeMiniBuffer
	    <CMiniBuffer>
            vMiniBuffer

            GetMiniBufferPrompt
            GetMiniBufferLine
            GetMiniBufferXCur
            GetMiniBufferXGoal
            IncreaseMiniBufferXCur!
            IsMiniBufferModified?
            SetMiniBufferPrompt!
            SetMiniBufferLine!
            SetMiniBufferXCur!
            SetMiniBufferXGoal!
            SetMiniBufferFModified!
	    ))

(define-class <CMiniBuffer> ()
  (m_prompt #:init-thunk "")
  (m_line #:init-thunk "")
  (m_xCur #:init-value 0)
  (m_xGoal #:init-value 0)
  (m_fModified #:init-value #f))

;; The buffer
(define vMiniBuffer #f)

;; An intialization flag
(define vfMiniBuf #f)

(define (MiniBuf!)
  "Set the state of the minibuffer to 'initialized'"
  (set! vfMiniBuf #t))

(define (MiniBuf)
  (cond
   [(null? vMiniBuffer)
    (format (current-error-port) "vMiniBuffer is null~%")
    #f]
   [(eqv? #f vMiniBuffer)
    (format (current-error-port) "vMiniBuffer is false~%")
    #f]
   [else
    vMiniBuffer]))

(define (MiniBuf?)
  vfMiniBuf)

(define (%DescribeMiniBuffer)
  (if (MiniBuf?)
      (describe (MiniBuf))
      (display "There is no minibuffer.\n")))

(define (GetMiniBufferPrompt)
  "Returns the prompt string of the current minibuffer"

(define (GetMiniBufferLine)
  "Returns the text entered into the current minibuffer"
  (slot-ref vMiniBuffer 'm_line))

(define (GetMiniBufferXCur)
  "Returns the logical x coordinate of the cursor in the minibuffer text"
  (slot-ref vMiniBuffer 'm_xCur))

(define (GetMiniBufferXGoal)
  "Returns the last-computed cell location of the cursort in the
minibuffer text"
  (slot-ref vMiniBuffer 'm_xGoal))

(define (IncreaseMiniBufferXCur! n)
  "Incrase the location location of the cursor in the minibuffer by 'n'"
  (slot-set vMiniBuffer 'm_xCur (+ (slot-ref vMiniBuffer 'm_xCur) n)))

(define (IsMiniBufferModified?)
  "Returns #t if the text in the minibuffer has been modified from its
initial value"
  (slot-ref vMiniBuffer 'm_fModified))

(define (SetMiniBufferPrompt! str)
  "Set the prompt (read-only) text in the minibuffer"
  (slot-set! vMiniBuffer 'm_prompt str))

(define (SetMiniBufferLine! str)
  "Set the editable text in the minibuffer"
  (slot-set! vMiniBuffer 'm_line str))

(define (SetMiniBufferXCur! x)
  "Set the current logical location of the cursor in the editable text
of the minibuffer"
  (slot-set! vMiniBuffer 'm_xCur x))

(define (SetMiniBufferXGoal! x)
  "Set the current cell location of the cursor in the editable text
of the minibuffer"
  (slot-set! vMiniBuffer 'm_xGoal x))

(define (SetMiniBufferFModified! f)
  "Set the modified flag of the minibuffer"
  (slot-set! vMiniBuffer 'm_fModified f))
