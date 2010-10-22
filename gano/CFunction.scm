(define-module (gano CFunction)
  #:use-module (oop goops)
  #:export (
            <CFunction>
            CreateFunction
            GetFunctionId
            GetFunctionMenus
            GetFunctionDesc
            IsFunctionReadOnly?
            ))


(define-class <CFunction> ()
   ;; What function is this
   m_ID
   ;; In what menus does this function applu
   m_menus
   ;; The function's description, e.g. "Page Up".
   m_desc
   ;; The help file entry text for this function.
   m_help
   ;; Whether there should be a blank line after the help entry
   ;; text for this function.
   m_fBlankAfter
   ;; Is this function OK for View mode?
   (m_fReadOnly #:getter IsFunctionReadOnly? #:initial #f)
   ;; If this is a toggle, if nonzero what toggle to set
   m_fToggle
   m_toggleID
   )

(define-method (CreateFunction funcID menus desc help fReadOnly fBlankAfter)
  (let ([fn (make <CFunction>)])
    (slot-set! fn 'm_ID funcID)
    (slot-set! fn 'm_menus menus)
    (slot-set! fn 'm_desc desc)
    (slot-set! fn 'm_help help)
    (slot-set! fn 'm_fReadOnly fReadOnly)
    (slot-set! fn 'm_fBlankAfter fBlankAfter)
    fn))

(define-method (GetFunctionId (fn <CFunction>))
  (slot-ref fn 'm_ID))

(define-method (GetFunctionMenus (fn <CFunction>))
  (slot-ref fn 'm_menus))

(define-method (GetFunctionDesc (fn <CFunction>))
  (slot-ref fn 'm_desc))

(define-method (IsFunctionReadOnly? (fn <CFunction>))
  (slot-ref fn 'm_fReadOnly))