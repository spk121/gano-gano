(define-module (gano CText)
  #:use-module (oop goops)
  #:export (
	    <CText>
            MakeLine
            GetLineText
            SetLineText!
	    ))

(define-class <CText> ()
  (m_text #:getter GetLineText #:setter SetLineText! #:init-value "")
  (m_rgMultiData #:init-value '()))

(define (MakeLine txt)
  (let ([line (make <CText>)])
    (SetLineText! line txt)
    line))
