(define-module (gano CShortcut)
  #:use-module (oop goops)
  #:use-module (oop goops describe)
  #:use-module (ncurses curses)
  #:export (
            <CShortcut>
            CreateShortcut
            GetShortcutFuncId
            GetShortcutKeyStr
            GetShortcutKey
            GetShortcutMenus
            IsShortcutMeta?
            DoesShortcutMatchMenuAndFuncId?
            DoesShortcutUseMetaKey?
            ))


(define-class <CShortcut> ()
  ;; The ASCII version of the shortcut key
  (m_keyStr #:getter GetShortcutKeyStr #:initial "")
  ;; The key type
  m_keyType
  ;; The unpacked shortcut key
  (m_fMeta #:getter IsShortcutMeta? #:initial #f)
  (m_key #:getter GetShortcutKey #:initial #\nul)
  ;; The menus to which it is bound
  (m_menus #:getter GetShortcutMenus #:initial 0)
  ;; The ID of the function
  (m_funcId #:getter GetShortcutFuncId #:initial 0)
  ;; If this is a toggle, and if so, the flag we're toggling
  (m_fToggle #:initial #f)
  (m_toggleId #:initial 0)
  ;; Whether we're actually executing another function
  m_fExecute)

;; function_type
(define CONTROL 0)
(define META 1)
(define FKEY 2)
(define RAW 3)


(define(CreateShortcut menu keyStr funcId toggleId fExecute)
  (let ([sc (make <CShortcut>)])
    (slot-set! sc 'm_menus menu)
    (slot-set! sc 'm_keyStr keyStr)
    (slot-set! sc 'm_funcId funcId)
    (slot-set! sc 'm_fToggle (= toggleId 0))
    (slot-set! sc 'm_toggleId toggleId)
    (slot-set! sc 'm_fExecute fExecute)
    (AssignKeyInfo sc)
    sc))

(define-method (DoesShortcutMatchMenuAndFuncId? (sc <CShortcut>) menu funcId)
  ;; (format (current-error-port) "DoesShortcutMatchMenuAndFuncId: sc ~s menu ~s funcId ~s~%"
  ;;         sc menu funcId)
  ;; (describe sc)
  (let ([ret (and (logtest (slot-ref sc 'm_menus)  menu)
                   (eq? (slot-ref sc 'm_funcId) funcId))])
    ;;(format (current-error-port) "DoesShortcutMatchMenuAndFuncId: ret ~s~%" ret)
    ret
    ))

(define-method (DoesShortcutUseMetaKey? (sc <CShortcut>))
  (slot-ref sc 'm_fMeta))

(define-method (GetShortcutFuncId (sc <CShortcut>))
  (slot-ref sc 'm_funcId))

(define-method (GetShortcutKeyStr (fn <CShortcut>))
  (slot-ref fn 'm_keyStr))

(define-method (AssignKeyInfo (sc <CShortcut>))
  (let* ([keyStr (slot-ref sc 'm_keyStr)]
         [type (GetKeyTypeFromKeyStr keyStr)])
    (cond
     [(eq? type CONTROL)
      (slot-set! sc 'm_key (integer->char (- (char->integer (string-ref keyStr 1)) 64)))
      (slot-set! sc 'm_fMeta #f)]
     [(eq? type META)
      (slot-set! sc 'm_key (char-downcase (string-ref keyStr 2)))
      (slot-set! sc 'm_fMeta #t)]
     [(eq? type FKEY)
      (slot-set! sc 'm_key (key-f (string->number (string-drop keyStr 1))))
      (slot-set! sc 'm_fMeta #f)]
     [else
      (slot-set! sc 'm_key (string-ref keyStr 0))
      (slot-set! sc 'm_fMeta #f)])

    ;; Process keys that have long names
    (cond
     [(and (eq? type CONTROL)
           (string-ci=? "space" (string-drop keyStr 1)))
      (slot-set! sc 'm_key 0)
      (slot-set! sc 'm_fMeta #f)]
     [(and (eq? type META)
           (string-ci=? "space" (string-drop keyStr 2)))
      (slot-set! sc 'm_key #\space)
      (slot-set! sc 'm_fMeta #t)]

     [(and (eq? type RAW)
           (string-ci=? "kup" keyStr))
      (slot-set! sc 'm_key KEY_UP)
      (slot-set! sc 'm_fMeta #f)]

     [(and (eq? type RAW)
           (string-ci=? "kdown" keyStr))
      (slot-set! sc 'm_key KEY_DOWN)
      (slot-set! sc 'm_fMeta #f)]

     [(and (eq? type RAW)
           (string-ci=? "kleft" keyStr))
      (slot-set! sc 'm_key KEY_LEFT)
      (slot-set! sc 'm_fMeta #f)]

     [(and (eq? type RAW)
           (string-ci=? "kright" keyStr))
      (slot-set! sc 'm_key KEY_RIGHT)
      (slot-set! sc 'm_fMeta #f)]

     [(and (eq? type RAW)
           (string-ci=? "kinser" keyStr))
      (slot-set! sc 'm_key KEY_IC)
      (slot-set! sc 'm_fMeta #f)]

     [(and (eq? type RAW)
           (string-ci=? "kdel" keyStr))
      (slot-set! sc 'm_key KEY_DC)
      (slot-set! sc 'm_fMeta #f)]

     [(and (eq? type RAW)
           (string-ci=? "kbsp" keyStr))
      (slot-set! sc 'm_fMeta KEY_BACKSPACE)
      (slot-set! sc 'm_fMeta #f)]

     [(and (eq? type RAW)
           (string-ci=? "kenter" keyStr))
      (slot-set! sc 'm_key KEY_ENTER)
      (slot-set! sc 'm_fMeta #f)]

     [(and (eq? type RAW)
           (string-ci=? "kpup" keyStr))
      (slot-set! sc 'm_key KEY_PPAGE)
      (slot-set! sc 'm_fMeta #f)]

     [(and (eq? type RAW)
           (string-ci=? "kpdown" keyStr))
      (slot-set! sc 'm_key KEY_NPAGE)
      (slot-set! sc 'm_fMeta #f)]

     [(and (eq? type RAW)
           (string-ci=? "khome" keyStr))
      (slot-set! sc 'm_key KEY_HOME)
      (slot-set! sc 'm_fMeta #f)]

     [(and (eq? type RAW)
           (string-ci=? "kend" keyStr))
      (slot-set! sc 'm_key KEY_END)
      (slot-set! sc 'm_fMeta #f)])))


;; Set type of function based on the string
(define (GetKeyTypeFromKeyStr str)
  (let ([firstChar (string-ref str 0)])
    (cond
     [(char-ci=? #\m firstChar)
      META]
     [(char=? #\^ firstChar)
      CONTROL]
     [(char-ci=? #\f firstChar)
      FKEY]
     [else
      RAW])))
