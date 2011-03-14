;;; shortcut.scm - Associations between keypresses, contexts and function IDs

;; The output-port for debug information
(define (%sc-debug-port)
  (let ([p (%make-void-port "rw")])
    (case-lambda
      [()
       p]
      [(x)
       (set! p x)])))

(define *shortcuts* '())

;; function_type
(define CONTROL 0)
(define META 1)
(define FKEY 2)
(define RAW 3)

(define SC_KEY_STRING 1)
(define SC_KEY_TYPE 2)
(define SC_META 3)
(define SC_KEY 4)
(define SC_CONTEXT 5)
(define SC_FUNC_ID 6)
(define SC_TOGGLE 7)
(define SC_TOGGLE_ID 8)
(define SC_EXECUTE 9)
(define SC_LENGTH (+ 1 SC_EXECUTE))

(define (sc-get-key-string sc)       (vector-ref sc SC_KEY_STRING))
(define (sc-get-key-type sc)         (vector-ref sc SC_KEY_TYPE))
(define (sc-get-meta sc)             (vector-ref sc SC_META))
(define (sc-get-key sc)              (vector-ref sc SC_KEY))
(define (sc-get-context sc)          (vector-ref sc SC_CONTEXT))
(define (sc-get-function-id sc)      (vector-ref sc SC_FUNC_ID))
(define (sc-get-toggle sc)           (vector-ref sc SC_TOGGLE))
(define (sc-get-toggle-id sc)        (vector-ref sc SC_TOGGLE_ID))
(define (sc-get-execute sc)          (vector-ref sc SC_EXECUTE))

(define (sc-set-key-string! sc x)       (vector-set! sc SC_KEY_STRING x))
(define (sc-set-key-type! sc x)         (vector-set! sc SC_KEY_TYPE x))
(define (sc-set-meta! sc x)             (vector-set! sc SC_META x))
(define (sc-set-key! sc x)              (vector-set! sc SC_KEY x))
(define (sc-set-context! sc x)          (vector-set! sc SC_CONTEXT x))
(define (sc-set-function-id! sc x)      (vector-set! sc SC_FUNC_ID x))
(define (sc-set-toggle! sc x)           (vector-set! sc SC_TOGGLE x))
(define (sc-set-toggle-id! sc x)        (vector-set! sc SC_TOGGLE_ID x))
(define (sc-set-execute! sc x)          (vector-set! sc SC_EXECUTE x))

(define (sc-make-shortcut)
  "Make a shorcut, which is an association between a keypress and a function ID."
  (let ((sc (make-vector SC_LENGTH #f)))
    (vector-set! sc 0 'sc)
    ;; The ASCII version of the shortcut key
    (sc-set-key-string! sc "")
    (sc-set-key-type! sc 'raw)
    ;; The unpacked shortcut key
    (sc-set-meta! sc #f)
    (sc-set-key! sc #f)
    ;; The menus to which it is bound
    (sc-set-context! sc 0)
    (sc-set-function-id! sc 0)
    ;; If this is a toggle, and if so, the flag we're toggling
    (sc-set-toggle! sc #f)
    (sc-set-toggle-id! sc 0)
    ;; Whether we're actually executing another function
    (sc-set-execute! sc #f)
    sc))

(define (sc-create-shortcut context keyStr funcId toggleId fExecute)
  (let ([sc (sc-make-shortcut)])
    (vector-set! sc SC_CONTEXT context)
    (vector-set! sc SC_KEY_STRING keyStr)
    (vector-set! sc SC_FUNC_ID funcId)
    (vector-set! sc SC_TOGGLE (= toggleId 0))
    (vector-set! sc SC_TOGGLE_ID toggleId)
    (vector-set! sc SC_EXECUTE fExecute)
    (set! sc (sc-assign-key-info! sc))
    sc))

;; Set type of function based on the string
(define (sc-get-key-type-from-key-string str)
  "Scan a key string to decide if this is a control char, a meta char
a function key, or something else."
  (let* ([firstChar (string-ref str 0)]
         [len (string-length str)]
         [TEST (lambda (min-len first-char)
                 (and (> len min-len)
                      (char-ci=? first-char firstChar)))])
    (cond
     [(TEST 2 #\m) META]
     [(TEST 1 #\^) CONTROL]
     [(TEST 1 #\f) FKEY]
     [else RAW])))

(define (sc-assign-key-info! sc)
  "Pre-process the key string into its components."
  (let* ([keyStr (sc-get-key-string sc)]
         [type (sc-get-key-type-from-key-string keyStr)]
         [SET (lambda (m k)
                (sc-set-meta! sc m)
                (sc-set-key! sc k))]
         [KEYPAD (lambda (k)
                   (and (eq? type RAW) (string-ci=? k keyStr)))])
    (log-debug (format #f "sc-assign-key-info!: keystr ~s type ~s"
                       keyStr
                       (case type
                         ((0) "CONTROL")
                         ((1) "META")
                         ((2) "FKEY")
                         ((3) "RAW")
                         (else "UNSPECIFIED"))))
    (case type
     [(0)
      (SET #f (integer->char (- (char->integer (string-ref keyStr 1)) 64)))]
     [(1)
      (SET #t (char-downcase (string-ref keyStr 2)))]
     [(2)
      (SET #f (key-f (string->number (string-drop keyStr 1))))]
     [else
      (SET #f (string-ref keyStr 0))])

    ;; Process keys that have long names
    (cond
     [(and (eq? type CONTROL)
           (string-ci=? "space" (string-drop keyStr 1)))
      (SET #f 0)]
     [(and (eq? type META)
           (string-ci=? "space" (string-drop keyStr 2)))
      (SET #t #\space)]
     [(KEYPAD "kup")     (SET #f KEY_UP)]
     [(KEYPAD "kdown")   (SET #f KEY_DOWN)]
     [(KEYPAD "kleft")   (SET #f KEY_LEFT)]
     [(KEYPAD "kright")  (SET #f KEY_RIGHT)]
     [(KEYPAD "kinsert") (SET #f KEY_IC)]
     [(KEYPAD "kdel")    (SET #f KEY_DC)]
     [(KEYPAD "kbsp")    (SET #f KEY_BACKSPACE)]
     [(KEYPAD "kenter")  (SET #f KEY_ENTER)]
     [(KEYPAD "kpup")    (SET #f KEY_PPAGE)]
     [(KEYPAD "kpdown")  (SET #f KEY_NPAGE)]
     [(KEYPAD "khome")   (SET #f KEY_HOME)]
     [(KEYPAD "kend")    (SET #f KEY_END)]
     [(and (eq? type RAW)
           (> (string-length keyStr) 1))
      (error "bad keyStr ~s~%" keyStr)])
    (log-debug (format #f "sc-assign-key-info!: ~s" sc))
    sc))

(define (sc-does-shortcut-match-context-and-func-id? sc context funcId)
  (and (logtest (sc-get-context sc)  context)
       (eq? (sc-get-function-id sc) funcId)))

(define (sc-add-shortcut context keyStr funcId toggleId fExecute)
  "Add a shortcut to the global shortcut list."
  (let* ([sc (sc-create-shortcut context keyStr funcId toggleId fExecute)]
         [matchingSc (find (lambda (sc)
                             (sc-does-shortcut-match-context-and-func-id? sc context funcId))
                           *shortcuts*)])
    (log-debug
     (format #f "sc-add-shortcut: context ~s keyStr ~s funcId ~s toggleId ~s fExecute ~s~"
             context keyStr funcId toggleId fExecute))
    (log-debug
     (format #f "sc-add-shortcut: meta ~s key ~s"
             (sc-get-meta sc) (sc-get-key sc)))
    (log-debug
     (format #f "sc-add-shortcut: sc ~s" sc))

    (when matchingSc
      (log-debug
       (format #f "sc-add-shortcut: ~s is duplicate shortcut ~s on context ~s and function ~s~%"
               (sc-get-key-string matchingSc) keyStr context funcId)))

    (set! *shortcuts* (append *shortcuts* (list sc)))))

(define (sc-init-shortcuts)
  "Initializes the list that contains the association between keypresses,
contexts, and function IDs"
  (sc-add-shortcut MMAIN "^_" 'CUP 0 #t)
  (sc-add-shortcut MMAIN "F13" 'CUP 0 #t)
  (sc-add-shortcut MMAIN "M-G" 'CUP 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE) "^Y" 'PPB 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE) "F7" 'PPB 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE) "kpup" 'PPB 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE) "^V" 'PPR 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE) "F8" 'PPR 0 #t)
  (sc-add-shortcut (logior MMAIN MBROWSER MHELP MWHEREISFILE) "kpdown" 'PPR 0 #t)
  (sc-add-shortcut MMAIN "^K" 'CUT 0 #t)
  (sc-add-shortcut MMAIN "F9" 'CUT 0 #t)
  (sc-add-shortcut MALL "kenter" 'INL 0 #t)
  (sc-add-shortcut MALL "^J" 'INL 0 #t)
  (sc-add-shortcut MALL "^D" 'DCH 0 #t)
  (sc-add-shortcut MALL "kdel" 'DCH 0 #t))

(define (sc-does-shortcut-use-meta-key? sc)
  (sc-get-meta sc))

(define (DoesShortcutMatchMenuAndFuncId? sc context funcId)
  (sc-does-shortcut-match-context-and-func-id? sc context funcId))
(define (GetShortcutKeyStr sc)
  (sc-get-key-string sc))
