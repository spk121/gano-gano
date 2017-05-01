;;;; A command dispatch loop -*- coding: utf-8 -*-

;;; This buffer contains procedures that parse input and call
;;; character-cell buffer and window commands.

;;; The low-level text buffer is set up as a device-independent
;;; model-view-controller.

;;; Model: cbuf.scm - the text buffer and its cursor
;;; View: frame.scm - a square window that defines a region of the text buffer
;;; Controller: dispatch.scm - a command loop

;;; But both this 'view' and this 'controller' don't interface with
;;; NCurses or GTK.  That is left to higher level functions.

;;; Since this controller is part of the *device independent* MVC,
;;; it takes function IDs instead of keypresses.

;;; dsp-init: returns a newly-initialized text buffer MVC object
;;; dsp-dispatch: takes a function ID and modifies the text-buffer MVC object
;;; dsp-get-text


;;; This is the 'control' part of the character buffer's
;;; Model-View-Controller.  It receives keyboard commands and then
;;; calls model (cbuf) or view (frame) commands.
;;;
;;; This program is meant to operate as two different models:
;;; and editor and a terminal
;;;
;;; In Editor mode, I assume that we are getting keypresses that have
;;; passed through NCURSES, so they will either be complete
;;; codepoints or ncurses key constants like KEY_ENTER.  Also, editor
;;; mode won't typically let the cursor move past the end of the line
;;; or the buffer.  If the controller tries to move too wide or too far,
;;; an error will be thrown.
;;;
;;; In terminal mode, I assume that we are getting raw keypresses,
;;; where function keys can emit multi-character sequences like #\esc
;;; #\[ #\A. Also, cursor movements that move past the end of the line
;;; or the buffer will cause whitespace to be added to the underlying
;;; document.

;;; Here's a (probably outdated) list of the alphabetic control sequences
;;;
;;; C0 commands use the control key
;;; KEYPRESS  | TERMINAL-MODE COMMAND         | EDITOR-MODE COMMAND
;;; ^A - SOH: ISO-1745 unimplemented          | [C1 command introducer]
;;; ^B - STX: ISO-1745 unimplemented          | [CSI Pn=1 command introducer]
;;; ^C - ETX: ISO-1745 unimplemented          |
;;; ^D - EOT: ISO-1745 unimplemented          |
;;; ^E - ENQ: ISO-1745 unimplemented          |
;;; ^F - ACK: ISO-1745 unimplemented          |
;;; ^G - BEL:                                 |
;;; ^H - BS:  cbuf-backspace                  | cbuf-cursor-left + cbuf-delete-character
;;; ^I - HT:  cbuf-character-tabulation       | cbuf-insert-codepoint #\tab
;;; ^J - NL:  cbuf-linefeed                   | cbuf-insert-newline
;;; ^K - VT:  cbuf-line-tabulation            | cbuf-insert-vtab
;;; ^L - FF:  cbuf-form-feed                  | cbuf-insert-page
;;; ^M - CR:  cbuf-carriage-return            | cbuf-insert-newline
;;; ^N - SO:  ECMA-35 unimplemented           |
;;; ^O - SI:  ECMA-35 unimplemented           |
;;; ^P - DLE: ISO-1745 unimplemented          |
;;; ^Q - DC1: ignored                         |
;;; ^R - DC2: ignored                         |
;;; ^S - DC3: ignored                         |
;;; ^T - DC4: ignored                         |
;;; ^U - NAK: ISO-1745 unimplemented          |
;;; ^V - SYN: ISO-1745 unimplemented          |
;;; ^W - ETB: ISO-1745 unimplemented          |
;;; ^X - CAN:                                 | cbuf-undo
;;; ^Y - EM:  ignored                         |
;;; ^Z - SUB: cbuf-insert-codepoint #\xFFFD   |

;;; SET 2 and C1 commands
;;;
;;; B - BPH: cbuf-insert-codepoint U+200B (zero-width space)
;;; C - NBH: cbuf-insert-codepoint U+2060 (word joiner)
;;; E - NEL: cbuf-next-line                   | cbuf-insert-newline
;;; F - SSA: cbuf-start-of-selected-area (set mark)
;;; G - ESA: cbuf-end-of-selected-area (copy)
;;; H - HTS:
;;; I - HTJ:
;;; J - VTS:
;;; K - PLD: dsp-superscript-mode
;;; L - PLU: dsp-subscript-mode
;;; M - RI:  cbuf-reverse-line-feed
;;; N - SS2
;;; O - SS3
;;; P - DCS: Start of Device Control String
;;; Q - PU1
;;; R - PU2
;;; S - STS
;;; T - CCH: cbuf-undo (last graphical character)
;;; U - MW
;;; V - SPA
;;; W - EPA
;;; X - SOS: Start of String
;;; Z - SCI: Single Character Introducer
;;; [ - CSI: Start of Control Sequence
;;; \ - ST: String terminator
;;; ] - OSC: Start of Operating System Command
;;; ^ - PM: Start of Private Message
;;; _ - APC: Start of Application Program Command

;;; SET 3: CSI commands with a single numeric parameter
;;;
;;; Z - cbuf-backward-tabulation
;;; G - cbuf-cursor-character-absolute (move to 1st column)
;;; I - cbuf-forward-tabulation
;;; E - cbuf-next-line
;;; F - cbuf-preceding-line
;;; D - cbuf-cursor-left
;;; B - cbuf-cursor-down
;;; C - cbuf-cursor-right
;;; A - cbuf-cursor-up
;;; Y - cbuf-cursor-line-tabulation
;;; P - cbuf-delete-character
;;; M - cbuf-delete-line
;;; O - cbuf-erase-in-area (clear from cursor to end of area)
;;; X - cbuf-erase-character
;;; J - cbuf-erase-in-page (clear from active pos to end of page)
;;; N - cbuf-erase-in-field (clear from active pos to next tab stop)
;;; K - cbuf erase-in-line (clear from active pos to end of line)
;;; ` - cbuf-character-position-absolute (move to 1st character in line)
;;; j - cbuf-character-position-backward
;;; a - cbuf-character-position-forward
;;; @ - cbuf-insert-character (insert a space)
;;; L - cbuf-insert-line
;;; U - frame-next-page
;;; V - frame-preceding-page
;;; b - dsp-repeat
;;; T - cbuf-scroll-down
;;; S - cbuf-scroll-up
;;; d - cbuf-line-position-absolute (move to 1st line)
;;; k - cbuf-line-position-backward
;;; e - cbuf-line-position-forward

;;; SET 4
;;;
;;; space P - cbuf-page-position-absolute (move to 1st page)
;;; space R - cbuf-page-position-backward
;;; space Q - cbuf-page-position-forward
;;; space @ - cbuf-scroll-left
;;; space A - cbuf-scroll-right

(define-condition-type &dsp-unknown-key-sequence &condition
  dsp-unknown-key-sequence?
  (sequence dsp-unknown-key-sequence:sequence))

(define \PAD (integer->char 128))
(define \HOP (integer->char 129))
(define \BPH (integer->char 130))
(define \NBH (integer->char 131))
(define \IND (integer->char 132))
(define \NEL (integer->char 133))
(define \SSA (integer->char 134))
(define \ESA (integer->char 135))
(define \HTS (integer->char 136))
(define \HTJ (integer->char 137))
(define \VTS (integer->char 138))
(define \PLD (integer->char 139))
(define \PLU (integer->char 140))
(define \RI  (integer->char 141))
(define \SS2 (integer->char 142))
(define \SS3 (integer->char 143))
(define \DCS (integer->char 144))
(define \PU1 (integer->char 145))
(define \PU2 (integer->char 146))
(define \STS (integer->char 147))
(define \CCH (integer->char 148))
(define \MW  (integer->char 149))
(define \SPA (integer->char 150))
(define \EPA (integer->char 151))
(define \SOS (integer->char 152))
(define \SGCI (integer->char 153))
(define \SCI (integer->char 154))
(define \CSI (integer->char 155))
(define \ST  (integer->char 156))
(define \OSC (integer->char 157))
(define \PM  (integer->char 158))
(define \APC (integer->char 159))

(define DSP_C0_SET 1)
;; Changes the behavior of format effectors. #t means it behaves more
;; like a terminal than an editor.
(define DSP_TERMINAL_MODE 1)
;; If #t and if we're working as an editor, linefeed characters
;; start new lines in the buffer.
(define DSP_LINEFEED_IS_CARRIAGE_RETURN 2)
;; If we're in a multi-codepoint sequence, it contains the list of codepoints
;; in the sequence.  Otherwise it is a null list.
(define DSP_SEQUENCE 3)
(define DSP_PREV_SEQUENCE 4)
(define DSP_SUBSCRIPT 5)
(define DSP_SUPERSCRIPT 6)
(define DSP_SET_2_INTRODUCER 7)
(define DSP_SET_3_INTRODUCER 8)
(define DSP_SET_4_INTRODUCER 9)
(define DSP_LENGTH (+ DSP_SET_4_INTRODUCER 1))

(define (dsp-make-state)
  "Create an empty dispatch loop state."
  (let ((state (make-vector DSP_LENGTH #f)))
    (vector-set! state 0 'dsp)
    (vector-set! state DSP_C0_SET 'c0)
    (vector-set! state DSP_LINEFEED_IS_CARRIAGE_RETURN #f)
    (vector-set! state DSP_TERMINAL_MODE #f)
    (vector-set! state DSP_SUBSCRIPT #f)
    (vector-set! state DSP_SUPERSCRIPT #f)
    (vector-set! state DSP_PREV_SEQUENCE '())
    (vector-set! state DSP_SEQUENCE '())
    (vector-set! state DSP_SET_2_INTRODUCER #\soh)
    (vector-set! state DSP_SET_3_INTRODUCER #\stx)
    (vector-set! state DSP_SET_4_INTRODUCER #\eot)
    state))

(define (dsp-is-control-string-char? ch)
  (or (and (char>=? ch #\backspace) (char<=? ch #\return))
      (and (char>=? #\space)  (char<=? ch #\~))))

;; lower case super ᵃ ᵇ ᶜ ᵈ ᵉ ᶠ ᵍ ʰ ⁱ ʲ ᵏ ˡ ᵐ ⁿ ᵒ ᵖ ʳ ˢ ᵗ ᵘ ᵛ ʷ ˣ ʸ ᶻ
;; upper-case super ᴬ ᴮ ᴰ ᴱ ᴳ ᴴ ᴵ ᴶ ᴷ ᴸ ᴹ ᴺ ᴼ ᴾ ᴿ ᵀ ᵁ ⱽ ᵂ
;; lower-case sub ₐ ₑ ᵢ ₒ ᵣ ᵤ ᵥ ₓ
;; greek super ᵅ ᵝ ᵞ ᵟ ᵋ ᶿ ᶥ ᶲ ᵠ ᵡ
;; greek sub ᵦ ᵧ ᵨ ᵩ ᵪ
(define *dsp-superscript*
  '((#\0 . #\⁰)
    (#\i . #\ⁱ)
    (#\2 . #\²)
    (#\3 . #\³)
    (#\4 . #\⁴)
    (#\5 . #\⁵)
    (#\6 . #\⁶)
    (#\7 . #\⁷)
    (#\8 . #\⁸)
    (#\9 . #\⁹)
    (#\+ . #\⁺)
    (#\- . #\⁻)
    (#\= . #\⁼)
    (#\( . #\⁽)
    (#\) . #\⁾)
    (#\n . #\ⁿ)))

(define *dsp-superscript*
  '((#\0 . #\₀)
    (#\1 . #\₁)
    (#\2 . #\₂)
    (#\3 . #\₃)
    (#\4 . #\₄)
    (#\5 . #\₅)
    (#\6 . #\₆)
    (#\7 . #\₇)
    (#\8 . #\₈)
    (#\9 . #\₉)
    (#\+ . #\₊)
    (#\- . #\₋)
    (#\= . #\₌)
    (#\( . #\₍)
    (#\) . #\₎)
    (#\a . #\ₐ)
    (#\e . #\ₑ)
    (#\o . #\ₒ)
    (#\x . #\ₓ)
    (#\ə . #\ₔ)
    (#\h . #\ₕ)
    (#\k . #\ₖ)
    (#\l . #\ₗ)
    (#\m . #\ₘ)
    (#\n . #\ₙ)
    (#\p . #\ₚ)
    (#\s . #\ₛ)
    (#\t . #\ₜ)))

(define (dsp-update-state . x)
  #f)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; PRIMITIVES

(define (dsp-repeat buf frame state n)
  "Repeat the last command N times"
  (let* ([cmd (vector-ref state DSP_PREV_SEQUENCE)]
         [ch (if (null? cmd) #f (last cmd))]
         [seq (if (< (length cmd) 2) '() (drop-right cmd 1))])
    (if (not (null? cmd))
        (let loop ([i 0] [state2 (vector-copy state)])
          (if (< i n)
              (begin
                (vector-set! state2 DSP_SEQUENCE seq)
                (loop (+ i 1) (dsp-dispatch ch buf frame state2)))
              state2))
        ;; else
        state)))

;; PLD - Partial Line Forward
(define (dsp-partial-line-forward state)
  "Try to image the following characters as subscripts."
  (if (vector-ref state DSP_SUPERSCRIPT)
      (vector-set! state DSP_SUPERSCRIPT #f)
      (vector-set! state DSP_SUBSCRIPT #t)))

;; PLU - Partial Line Backward
(define (dsp-partial-line-backward state)
  "Try to image the following characters as superscripts."
  (if (vector-ref state DSP_SUBSCRIPT)
      (vector-set! state DSP_SUBSCRIPT #f)
      (vector-set! state DSP_SUPERSCRIPT #t)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; METHODS

(define* (dsp-id-dispatch! id BFS #:optional x x2)
  "Given a function ID and a buffer/frame/state (which are the three
components that make up a character cell buffer's
model/view/controller) apply the corresponding function to the
BFS."
  (let* ([buf (first BFS)]
         [frame (second BFS)]
         [state (third BFS)]
         ;; Default frame operation
         [F (lambda () (frame-update-frame buf frame))]
         ;; Default state operation
         [S (lambda () (dsp-update-state state))]
         ;; Default frame/state operation
         [D (lambda () (F) (S))])
  (case id
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Model methods
    [(ICP) (cbuf-insert-codepoint buf x #t) (D)]
    [(INL) (cbuf-insert-newline buf #t) (D)]
    [(CUT) (cbuf-del buf #t #t) (D)]
    [(DEL) (cbuf-del buf #f #t) (D)]
    [(CPY) (cbuf-copy buf #t) (S)]
    [(PST) (cbuf-paste buf #t) (D)]
    [(BEL) (cbuf-bell buf #t) (S)]
    [(BS)  (cbuf-backspace buf) (D)]
    [(CAN)
     (cbuf-cancel buf)
     (F)
     (dsp-cancel state)]
    [(CBL) (cbuf-clear-bell buf) (S)]
    [(CBT) (cbuf-cursor-backward-tabulation buf 1) (D)]
    [(CCH)
     (cbuf-cancel-character buf)
     (F)
     (dsp-cancel-character)]
    [(CHA) (cbuf-cursor-charcter-absolute buf 0) (D)]
    [(CHT) (cbuf-cursor-forward-tabulation buf 1) (D)]
    [(CNL) (cbuf-cursor-next-line buf 1) (D)]
    [(CPL) (cbuf-cursor-preceding-line buf 1) (D)]
    [(CR)  (cbuf-carriage-return buf) (D)]
    [(CUB) (cbuf-cursor-left buf 1) (D)]
    [(CUD) (cbuf-cursor-down buf 1) (D)]
    [(CUF) (cbuf-cursor-right buf 1) (D)]
    [(CUP) (cbuf-cursor-position buf 0 0) (D)]
    [(CUU) (cbuf-cursor-up buf 1) (D)]
    [(CVT) (cbuf-cursor-line-tabulation buf 1) (D)]
    [(DCH) (cbuf-delete-character buf 1 'presentation #t #t) (D)]
    [(DNL) (cbuf-delete-newline buf #t) (D)]
    [(DL)  (cbuf-delete-line buf 1 #t #t) (D)]
    [(ECH) (cbuf-erase-character buf 'presentation 1 #t #t) (D)]
    [(EL0) (cbuf-erase-in-line buf 'presentation 0 #t #t) (D)]
    [(EL1) (cbuf-erase-in-line buf 'presentation 1 #t #t) (D)]
    [(EL2) (cbuf-erase-in-line buf 'presentation 2 #t #t) (D)]
    [(FF)  (cbuf-form-feed buf) (D)]
    [(HPA) (cbuf-character-position-absolute buf 0) (D)]
    [(HPAn) (cbuf-character-position-absolute buf x) (D)]
    [(HPB) (cbuf-character-position-backward buf 1) (D)]
    [(HPR) (cbuf-character-position-forward buf 1) (D)]
    [(ICH) (cbuf-insert-character buf 1 #t) (D)]
    [(IL)  (cbuf-insert-line buf 1 #t) (D)]
    [(LF)  (cbuf-line-feed buf) (D)]
    [(NEL) (cbuf-next-line buf) (D)]
    [(PPB) (cbuf-page-position-backward buf 1) (D)]
    [(PPR) (cbuf-page-position-forward buf 1) (D)]
    [(RI)  (cbuf-reverse-line-feed buf) (D)]
    [(SLH) (cbuf-set-line-home buf (cbuf-get-x-cell buf)) (D)]
    [(VPB) (cbuf-line-position-backward buf 1) (D)]
    [(VPR) (cbuf-line-position-forward buf 1) (D)]
    [(VT)  (cbuf-line-tabulation buf) (D)]
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Frame methods
    [(NP)  (frame-next-page buf frame 1) (S)]
    [(PP)  (frame-preceding-page buf frame 1) (S)]
    [(SD)  (frame-scroll-down frame 1) (S)]
    [(SL)  (frame-scroll-left frame 1) (S)]
    [(SR)  (frame-scroll-right frame 1) (S)]
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; Controller methods
    [(PLD) (dsp-partial-line-forward state)]
    [(PLU) (dsp-partial-line-backward state)]
    [(REP) (dsp-repeat state)])))

(define (%dsp-debug-dispatch ch buf frame state)
  "A dispatch loop that takes the codepoint CH, a character cell
buffer BUF, and a character-cell buffer frame FRAME, and a state
machine STATE.  Depending on the value of CH, it may call a function
that modifies BUF or FRAME.  It will return a new state machine that
can be used in the next call to this procedure.

This is only used in the debug demo.  The real dispatcher is
elsewhere."
  (cond

   ;; If we are in a multi-codepoint sequence, call the correct
   ;; sub-parsers
   [(not (null? (vector-ref state DSP_SEQUENCE)))
    (let ([start (car (vector-ref state DSP_SEQUENCE))])
      (cond


       ;; Set 2: ^A + character between @ and _
       ;; Set 2 is mostly C1 controls
       [(and (char=? start (vector-ref state DSP_SET_2_INTRODUCER))
             (char>=? ch #\soh)
             (char<=? ch #\~))
        (dsp-dispatch-format-effectors ch buf frame state)]

       ;; Set 3: ^B + character between @ and ! and ~
       ;; Set 3 is mostly ECMA-48 controls
       [(and (char=? start (vector-ref state DSP_SET_3_INTRODUCER))
             (char>=? ch #\soh)
             (char<=? ch #\~))
        (dsp-dispatch-editor-functions ch buf frame state)]

       ;; Set 4: ^D + character betweeen @ and _
       ;; Set 4 is mostly less common ECMA-48 controls
       [(and (char=? start (vector-ref state DSP_SET_4_INTRODUCER))
             (char>=? ch #\!)
             (char<=? ch #\~))
        (dsp-dispatch-set-4 ch buf frame state)]

       [else
        (raise (condition (&dsp-unknown-key-sequence
                           (sequence (append (vector-ref state DSP_SEQUENCE)
                                             (list ch))))))
        state]))]

   ;; Integers greater than 255 are NCurses key constants like
   ;; KEY_DOWN
   [(and (integer? ch) (> ch 255))
    (dsp-dispatch-keycodes ch buf frame state)]

   ;; Three control characters are reserved for multi-keypress
   ;; control sequences.
   [(or (char=? ch (vector-ref state DSP_SET_2_INTRODUCER))
        (char=? ch (vector-ref state DSP_SET_3_INTRODUCER))
        (char=? ch (vector-ref state DSP_SET_4_INTRODUCER)))
    (vector-set! state DSP_SEQUENCE (list ch))
    state]

   ;; The remaining control characters are parsed as single-character
   ;; commands
   [(or (char<=? ch #\x1F)
        (and (char>=? ch #\x7F) (char<=? ch #\x9F)))
    (dsp-dispatch-controls ch buf frame state)]

   ;; Everything else is inserted as is
   [else
    (cond
     [(vector-ref state DSP_SUPERSCRIPT)
      (cbuf-insert-codepoint buf (or (assoc ch *dsp-superscript*) ch) #t)]
     [(vector-ref state DSP_SUBSCRIPT)
      (cbuf-insert-codepoint buf (or (assoc ch *dsp-subscript*) ch) #t)]
     [else
      (cbuf-insert-codepoint buf ch #t)])
    (vector-set! state DSP_PREV_SEQUENCE (list ch))
    state]))

(define (dsp-dispatch-controls ch buf frame state)
  "Dispatches commands for the C0 and C1 control characters."
  (cond

   ;; NUL and DELcan be inserted into a stream to kill time.  It can be
   ;; removed with no ill effects.
   [(or (char=? ch #\nul) (char=? ch #\delete))
    state]

   ;; ISO 1745 is unimplemented.
   ;; SOH is the start of an ISO 1745 heading.
   ;; STX is the start of an ISO-1745 text section.
   ;; ETX is the end of an ISO-1745 text section.
   ;; ENQ is the ISO-1745 enquiry character.
   ;; ACK is the ISO-1745 acknowledge character.
   ;; EOT is the ISO-1745 end-of-transmission character.
   ;; DLE is the ISO-1745 data link escape
   ;; NAK is ISO-1745's Negative Acknowledge.
   ;; SYN is ISO-1745's Synchronous Idle.
   ;; ETB is ISO-1745's End-of-Transmission Block.
   [(member ch (list #\soh #\stx #\etx #\eot #\enq #\ack #\eot #\dle
                     #\nak #\syn #\etb))
    (raise (condition (&dsp-unknown-key-sequence
                       (sequence (append (vector-ref state DSP_SEQUENCE)
                                         (list ch))))))]

   ;; BEL indicates that the caller needs attention.  It could be used
   ;; to implement some sort of priority response mechanism.  It is
   ;; IGNORED.
   [(char=? ch #\alarm)
    state]

   ;; BS is the backspace character.
   [(char=? ch #\backspace)
    (cbuf-backspace buf)
    state]

   ;; HT is the horizontal tab.  In most editors, this inserts a
   ;; horizontal tab.  If we are emulating a terminal, this instead
   ;; moves to the next tab stop.
   [(char=? ch #\tab)
    (let ([terminal? (vector-ref state DSP_TERMINAL_MODE)])
      (cond
       [terminal?
        ;; FIXME: someday implement ECMA-48's TAC, TALE, TATE, and TCC.
        (cbuf-cursor-forward-tabulation buf 1)
        state]
       [else
        (cbuf-insert-codepoint buf #\tab #t)
        state]))]


   ;; LF is linefeed.  If a terminal is being emulated, the active
   ;; position is moved down one line.  For an editor, it is either
   ;; ignored or possibly inserts a new line.
   [(char=? ch #\newline)
    (let ([terminal? (vector-ref state DSP_TERMINAL_MODE)])
      (cond
       [terminal?
        (cbuf-line-feed buf)
        state]
       [(vector-ref state DSP_LINEFEED_IS_CARRIAGE_RETURN)
        (cbuf-insert-newline buf #t)
        state]
       [else
        state]))]

   ;; VT is vertical tab.  For an editor, it inserts enough newlines
   ;; to put the cursor at the next vertical tab stop.  If a terminal
   ;; is being emulated, the active position is moved down to the next
   ;; vertical tab stop.
   [(char=? ch #\vtab)
    (let ([terminal? (vector-ref state DSP_TERMINAL_MODE)])
      (cond
       [terminal?
        (cbuf-cursor-line-tabulation buf 1)
        state]
       [else
        ;;(cbuf-insert-vtab buf #t)
        state]))]

   ;; FF is form feed.  For an editor, it inserts enough newlines
   ;; to put the cursor at the beginning of the next page.  If a terminal
   ;; is being emulated, it moves the active position to the page home
   ;; position of the next page.
   [(char=? ch #\page)
    (let ([terminal? (vector-ref state DSP_TERMINAL_MODE)])
      (cond
       [terminal?
        (cbuf-form-feed buf)
        state]
       [else
        ;;(cbuf-insert-page #t)
        state]))]

   ;; CR is carriage return.  For an editor, it starts a new line.
   ;; For a terminal it moves the active position to the beginning of
   ;; the line.
   [(char=? ch #\return)
    (let ([terminal? (vector-ref state DSP_TERMINAL_MODE)])
      (cond
       [terminal?
        (cbuf-carriage-return buf)]
       [else
        ;;(cbuf-insert-newline buf #t)
        state]))]

   ;; These are Locking Shift 1 and Locking Shift 0 which are part of
   ;; ECMA-35.  It is UNIMPLEMENTED
   [(or (char=? ch #\so) (char=? ch #\si))
    state]

   ;; The device control characters DC1 through DC4 are to allow the
   ;; caller to toggle ancillary devices.  This editor has no devices,
   ;; so it ignore them.
   [(or (char=? ch #\dc1) (char=? ch #\dc2) (char=? ch #\dc3) (char=? ch #\dc4))
    state]

   ;; CAN is used to indicate that the previous element in the data
   ;; stream is in error.  To implement it properly, I would have
   ;; needed to create an undo for every possible command, so instead
   ;; I've left it IGNORED.
   [(char=? ch #\can)
    state]

   ;; EM indicates the physical end of a medium.  It could operate where
   ;; the caller uses it to indicate that this is the end of a page of paper.
   ;; It is IGNORED.
   [(char=? ch #\em)
    state]

   ;; SUB is a representation of a character that is invalid.  This program
   ;; translates them to U+FFFD REPLACEMENT CHARCTER
   [(char=? ch #\sub)
    (cbuf-insert-codepoint buf #\xFFFD #t)]

   ;; ESC is usually the beginning of a multi-codepoint sequence.
   ;; Should probably use it as an introducer
   [(char=? ch #\esc)
    ;;(vector-set! state DSP_SEQUENCE (list #\esc))
    state]

   ;; US, FS, GS, and RS are information separator characters.  (GS
   ;; could be Page Terminator and FS could be Document Terminator.)
   ;; Since we assume that all the input information is part of the
   ;; same unit, these are IGNORED.
   [(or (char=? ch #\fs) (char=? ch #\gs) (char=? ch #\rs) (char=? ch #\us))
    state]

   ;; PAD and HOP are obsolete.
   [(or (char=? ch \PAD) (char=? ch \HOP))
    (raise (condition (&dsp-unknown-key-sequence (sequence ch))))]

   ;; BPH is Break Permitted Here.  Here it is implemented by mapping
   ;; it to Unicode's U+200B ZERO WIDTH SPACE
   [(char=? ch \BPH)
    (cbuf-insert-codepoint buf (integer->char #x200B) #t)]

   ;; NBH is No Break Here.  Here it is implemented by mapping
   ;; it to Unicode's U+2060 Word Joiner
   [(char=? ch \NBH)
    (cbuf-insert-codepoint buf (integer->char #x2060) #t)]

   ;; IND is obsolete.
   [(char=? ch \IND)
    (raise (condition (&dsp-unknown-key-sequence (sequence ch))))]

   ;; NEL is next line.  For a terminal it is a CR/LF pair.  For
   ;; an editor, it inserts a newline
   [(char=? ch \NEL)
    (let ([terminal? (vector-ref state DSP_TERMINAL_MODE)])
      (cond
       [terminal?
        (cbuf-cursor-next-line buf 1)]
       [else
        (cbuf-insert-newline buf #t)]))]

   ;; SSA is the Start of a Selected Area.  We use it to set the
   ;; mark to the current location.
   ;;[(char=? ch \SSA)
    ;;(cbuf-start-of-selected-area buf)
    ;;state]

   ;; ESA is the End of a Selected Area.  We use it to move the
   ;; marked text to the copy buffer and clear the mark.
   ;;[(char=? ch \ESA)
    ;;(cbuf-end-of-selected-area buf)
    ;;state]

   ;; HTS - Horizontal Tab Set.  Unimplemented. IGNORED
   [(char=? ch \HTS)
    state]

   ;; HTJ - A right-justified horizontal tab.  Unimplemented. IGNORED
   [(char=? ch \HTJ)
    state]

   ;; VTS - Vertical Tab Set.  Unimplemented. IGNORED
   [(char=? ch \HTS)
    state]

   ;; PLD - Partial Line Down.  In this editor, this starts a superscript
   ;; mode where if a superscript version of a character exists, it will
   ;; be used instead of the regular codepoint. PLU cancels.
   [(char=? ch \PLD)
    (if (vector-ref state DSP_SUBSCRIPT)
        (vector-set! state DSP_SUBSCRIPT #f)
        (vector-set! state DSP_SUPERSCRIPT #t))
    state]

   ;; PLU - Partial Line Down.  In this editor, this starts a subscript
   ;; mode where if a subscript version of a character exists, it will
   ;; be used instead of the regular codepoint. PLD cancels.
   [(char=? ch \PLU)
    (if (vector-ref state DSP_SUPERSCRIPT)
        (vector-set! state DSP_SUPERSCRIPT #f)
        (vector-set! state DSP_SUBSCRIPT #t))
    state]

   ;; RI - Reverse Line Feed.
   [(char=? ch \RI)
    (cbuf-reverse-line-feed buf)
    state]

   ;; SS2 and SS3 are ECMA-35 commands. SS3 can also be emitted by the keypad
   ;; when num-lock is not on.  They are UNIMPLEMENTED.
   [(or (char=? ch \SS2) (char=? ch \SS3))
    (raise (condition (&dsp-unknown-key-sequence (sequence ch))))
    state]

   ;; DCS begins a Device Control String.  All following ASCII
   ;; characters will be put in the string until \ST is received.
   ;; They are parsed, but, we don't do anything with them yet.
   [(char=? ch \DCS)
    (vector-set! state DSP_SEQUENCE (list \DCS))
    state]

   ;; PU1 and PU2 are Private Use functions.  No command has been
   ;; defined for them, so they are ignored.
   [(or (char=? ch \PU1) (char=? ch \PU2))
    state]

   ;; STS is Set Transmit State.  It basically would tell the buffer
   ;; that it has permission to go from receive mode to transmit mode.
   ;; It is IGNORED.
   [(char=? ch \STS)
    state]

   ;; CCH is Cancel Character.  It is supposed to be used to undo the
   ;; last graphical character.  We basically map it to the undo operation
   [(char=? ch \CCH)
    (cbuf-cancel-character buf)
    state]

   ;; MW is Message Waiting.  If we're running in terminal mode, it would
   ;; tell the terminal that it should indicate that the sender has a message
   ;; for it.  It is IGNORED.
   [(char=? ch \MW)
    state]

   ;; SPA and EPA indicate the start and end of a guarded area.  We
   ;; might use this to delimit read-only strings.  For now, it is
   ;; IGNORED
   [(or (char=? ch \SPA) (char=? ch \EPA))
    state]

   ;; SOS is the opening delimiter of a control string.  All characters
   ;; up to the STRING TERMINATOR (ST) are put in the control string.
   [(char=? ch \SOS)
    (vector-set! state DSP_SEQUENCE (list \SOS))
    state]

   ;; SCI is the Single Character Introducer.  The next charcter,
   ;; which is either an ASCII format effector or non-control
   ;; character, indicates a command or special graphic character.
   [(char=? ch \SCI)
    (vector-set! state DSP_SEQUENCE (list \SCI))
    state]

   ;; CSI is the control sequence introducer.  It is the first
   ;; character in a multi-character command
   [(char=? ch \CSI)
    (vector-set! state DSP_SEQUENCE (list \CSI))
    state]

   ;; ST is the String Terminator.  Receiving a ST when not in
   ;; a string is an error.
   [(char=? ch \ST)
    (raise (condition (&dsp-unknown-key-sequence
                       (sequence (list \ST)))))
    state]

   ;; OSC, PM, and APC introduce control strings. OSC is 'operating
   ;; system command.  PM is Privacy Message.  APC is Application
   ;; Program Command.  These control strings are terminated with an
   ;; \ST
   [(or (char=? ch \OSC) (char=? ch \PM) (char=? ch \APC))
    (vector-set! state DSP_SEQUENCE (list ch))
    state]

   [else
    ;; Ignored
    state]))

(define (dsp-dispatch-keycodes ch buf frame state)
  state)

(define (dsp-dispatch-set-2 ch buf frame state)
  "Dispatches the first set of multi-keypress commands"
  (cond

   ;; BPH is Break Permitted Here.  Here it is implemented by mapping
   ;; it to Unicode's U+200B ZERO WIDTH SPACE
   [(char=? ch #\B)
    (cbuf-insert-codepoint buf (integer->char #x200B) #t)]

   ;; NBH is No Break Here.  Here it is implemented by mapping
   ;; it to Unicode's U+2060 Word Joiner
   [(char=? ch #\C)
    (cbuf-insert-codepoint buf (integer->char #x2060) #t)]

   ;; NEL is next line.  For a terminal it is a CR/LF pair.  For
   ;; an editor, it inserts a newline
   [(char=? ch #\E)
    (let ([terminal? (vector-ref state DSP_TERMINAL_MODE)])
      (cond
       [terminal?
        (cbuf-cursor-next-line buf 1)]
       [else
        (cbuf-insert-newline buf #t)]))]

   ;; SSA is the Start of a Selected Area.  We use it to set the
   ;; mark to the current location.
   ;;[(char=? ch #\F)
    ;;(cbuf-start-of-selected-area buf)
    ;;state]

   ;; ESA is the End of a Selected Area.  We use it to move the
   ;; marked text to the copy buffer and clear the mark.
   ;;[(char=? ch #\G)
    ;;(cbuf-end-of-selected-area buf)
    ;;state]

   ;; PLD - Partial Line Down.  In this editor, this starts a superscript
   ;; mode where if a superscript version of a character exists, it will
   ;; be used instead of the regular codepoint. PLU cancels.
   [(char=? ch #\K)
    (if (vector-ref state DSP_SUBSCRIPT)
        (vector-set! state DSP_SUBSCRIPT #f)
        (vector-set! state DSP_SUPERSCRIPT #t))
    state]

   ;; PLU - Partial Line Down.  In this editor, this starts a subscript
   ;; mode where if a subscript version of a character exists, it will
   ;; be used instead of the regular codepoint. PLD cancels.
   [(char=? ch #\L)
    (if (vector-ref state DSP_SUPERSCRIPT)
        (vector-set! state DSP_SUPERSCRIPT #f)
        (vector-set! state DSP_SUBSCRIPT #t))
    state]

   ;; RI - Reverse Line Feed.
   [(char=? ch #\M)
    (cbuf-reverse-line-feed buf)
    state]

   ;; CCH is Cancel Character.  It is supposed to be used to undo the
   ;; last graphical character.  We basically map it to the undo operation
   [(char=? ch #\T)
    (cbuf-cancel-character buf)
    state]

   [else
    ;; Ignored
    state]))


(define (dsp-dispatch-set-3 ch buf frame state)
  "Dispatches the third set of multi-keypress commands"
  (cond
   ;; CSI Z
   [(char=? ch #\Z)
    (cbuf-cursor-backward-tabulation buf 1)]
   ;; CSI G
   [(char=? ch #\G)
    (cbuf-cursor-character-absolute buf 0)]
   [(char=? ch #\I)
    (cbuf-cursor-forward-tabulation buf 1)]
   [(char=? ch #\E)
    (cbuf-cursor-next-line buf 1)]
   [(char=? ch #\F)
    (cbuf-cursor-preceding-line buf 1)]
   [(char=? ch #\D)
    (cbuf-cursor-left buf 1)]
   [(char=? ch #\B)
    (cbuf-cursor-down buf 1)]
   [(char=? ch #\C)
    (cbuf-cursor-right buf 1)]
   [(char=? ch #\A)
    (cbuf-cursor-up buf 1)]
   [(char=? ch #\Y)
    (cbuf-cursor-line-tabulation buf 1)]
   [(char=? ch #\P)
    (cbuf-delete-character buf 1 'presentation #t #t)]
   [(char=? ch #\M)
    (cbuf-delete-line buf 1 #t #t)]
   ;;[(char=? ch #\O)
    ;;(cbuf-erase-in-area buf 1)]
   [(char=? ch #\X)
    (cbuf-erase-character buf 'presentation 1 #t #t)]
   ;;[(char=? ch #\J)
    ;;(cbuf-erase-in-page buf 1)]
   ;;[(char=? ch #\N)
    ;;(cbuf-erase-in-field buf 1)]
   [(char=? ch #\K)
    (cbuf-erase-in-line buf 'presentation 0 #t #t)]
   [(char=? ch #\`)
    (cbuf-character-position-absolute buf 0)]
   [(char=? ch #\j)
    (cbuf-character-position-backward buf 1)]
   [(char=? ch #\a)
    (cbuf-character-position-forward buf 1)]
   [(char=? ch #\@)
    (cbuf-insert-character buf 1 #t)]
   [(char=? ch #\L)
    (cbuf-insert-line buf 1 #t)]
   [(char=? ch #\U)
    (frame-next-page buf frame 1)]
   [(char=? ch #\V)
    (frame-preceding-page buf frame 1)]
   [(char=? ch #\b)
    (dsp-repeat buf frame state 1)]
   [(char=? ch #\b)
    (frame-scroll-down buf 1)]
   [(char=? ch #\d)
    (cbuf-line-position-absolute buf 0)]
   [(char=? ch #\k)
    (cbuf-line-position-backward buf 0)]
   [(char=? ch #\e)
    (cbuf-line-position-forward buf 0)])
  (vector-set! state DSP_SEQUENCE '())
  state)

(define (dsp-dispatch-set-4 ch buf frame state)
  "Dispatches the fourth set of multi-keypress commands"
  (cond
   [(char=? ch #\P)
    (cbuf-page-position-absolute buf 1)]
   [(char=? ch #\Q)
    (cbuf-page-position-forward buf 1)]
   [(char=? ch #\R)
    (cbuf-page-position-backward buf 1)]
   [(char=? ch #\@)
    (frame-scroll-left buf 1)]
   [(char=? ch #\A)
    (frame-scroll-right buf 1)]

   [(char=? ch #\M)
    (cbuf-carriage-return buf)]
   ))

(define (dsp-keycode-dispatch ch buf frame state)
  "Dispatches commands based on ncurses keycodes"
  state)

(define (dsp-dispatch-format-effectors ch buf frame state)
  (guard
   (err
    [(or (cbuf-beginning-of-line? err)
         (cbuf-end-of-line? err)
         (cbuf-beginning-of-buffer? err)
         (cbuf-end-of-buffer? err))
     (display "BEEP!!") (newline)])
   (cond
    [(char=? ch #\b)
     (cbuf-backspace buf)]
    [(char=? ch #\r)
     (cbuf-carriage-return buf)]
    [(char=? ch #\f)
     (cbuf-form-feed buf)]
    [(char=? ch #\,)
     (cbuf-character-position-backward buf 1)]
    [(char=? ch #\.)
     (cbuf-character-position-forward buf 1)]
    [(char=? ch #\tab)
     (cbuf-character-tabulation buf)]
    [(char=? ch #\l)
     (cbuf-line-feed buf)]
    [(char=? ch #\n)
     (cbuf-next-line buf)]
    [(char=? ch #\_)
     (dsp-partial-line-forward state)]
    [(char=? ch #\^)
     (dsp-partial-line-backward state)]
    ;; FIXME: Curly brackets can't get past M4
    ;;[(char=? ch #\{)
     ;;(cbuf-page-position-backward buf 1)]
    ;;[(char=? ch #\})
     ;;(cbuf-page-position-forward buf 1)]
    [(char=? ch #\L)
     (cbuf-reverse-line-feed buf)]
    [(char=? ch #\[)
     (cbuf-line-position-backward buf 1)]
    [(char=? ch #\])
     (cbuf-line-position-forward buf 1)]
    [(char=? ch #\v)
     (cbuf-line-tabulation buf)]))

  (vector-set! state DSP_PREV_SEQUENCE (append (vector-ref state DSP_SEQUENCE) (list ch)))
  (vector-set! state DSP_SEQUENCE '())
  state)

(define (dsp-dispatch-editor-functions ch buf frame state)
  (guard
   (err
    [(or (cbuf-beginning-of-line? err)
         (cbuf-end-of-line? err)
         (cbuf-beginning-of-buffer? err)
         (cbuf-end-of-buffer? err))
     (display "BEEP!!") (newline)])
   (cond
    [(char=? ch #\c)
     (cbuf-delete-character buf 1 'presentation #t #t)]
    [(char=? ch #\l)
     (cbuf-delete-line buf 1 #t #t)]
    ;;[(char=? ch #\a)
     ;;(cbuf-erase-in-area buf 0)]
    [(char=? ch #\C)
     (cbuf-erase-character buf 'presentation 1 #t #t)]
    ;;[(char=? ch #\p)
      ;;(cbuf-erase-in-page buf 0)]

    [(char=? ch #\l)
     (cbuf-erase-in-line buf 'presentation 0 #t #t)]
    [(char=? ch #\L)
     (cbuf-erase-in-line buf 'presentation 1 #t #t)]
    [(char=? ch #\page)
     (cbuf-erase-in-line buf 'presentation 2 #t #t)]

    [(char=? ch #\space)
     (cbuf-insert-character buf 1 #t)]
    [(or (char=? ch #\return) (char=? #\newline))
     (cbuf-insert-line buf 1 #t)]))
  (vector-set! state DSP_PREV_SEQUENCE (append (vector-ref state DSP_SEQUENCE) (list ch)))
  (vector-set! state DSP_SEQUENCE '())
  state)


#!
(define (ecma48-single-character-dispatch ch buf frame state)
  "Dispatches consisting of two-codepoint commands that begin
with SCI"
  ;; If a sequence is invalid, an error is thrown.
  (when (not (dsp-is-control-string-char? ch))
    (raise (condition (&dsp-unknown-key-sequence
                       (sequence (list \CSI ch))))))

  ;; These commands are IGNORED.
  (vector-set! state DSP_SEQUENCE '())
  state)

(define (ecma48-character-string-dispatch ch buf frame state)
  "Dispatch strings starting with \SOS and ending with \ST."
  (cond
   [(char=? ch \SOS)
    ;; It is an error to have an Start-Of-String in a string
    (raise (condition (&dsp-unknown-key-sequence
                       (sequence (append (vector-ref state DSP_SEQUENCE)
                                         (list ch))))))]

   [(char=? ch \ST)
    ;; The string is complete.  For now, it is IGNORED.
    (vector-set! state DSP_SEQUENCE '())
    state]

   [else
    ;; The string isn't complete yet.
    (vector-set! state DSP_SEQUENCE (append (vector-ref state DSP_SEQUENCE)
                                            (list ch)))
    state]))

(define (ecma48-control-string-dispatch ch buf frame state)
  "Dispatch strings starting with \APC, \OSC, \PM or \DCS and ending
with \ST."
  (cond
   [(char=? ch \ST)
    ;; The string is complete.  For now, it is IGNORED.
    (vector-set! state DSP_SEQUENCE '())
    state]
   [(dsp-is-control-string-char? ch)
    ;; The string isn't complete yet.
    (vector-set! state DSP_SEQUENCE (append (vector-ref state DSP_SEQUENCE)
                                            (list ch)))
    state]
   [else
    (raise (condition (&dsp-unknown-key-sequence
                       (sequence (append (vector-ref state DSP_SEQUENCE) (list ch))))))
    state]))

(define (ecma48-command-sequence-dispatch ch buf frame state)
  (let* ([seq (vector-ref state DSP_SEQUENCE)]
         [prev (last seq)])
    (cond

     ;; Valid parameter bytes
     [(and (dsp-parameter-byte? ch)
           (or (dsp-csi-byte? prev) (dsp-parameter-byte? prev)))
      (vector-set! state DSP_SEQUENCE (append seq (list ch)))
      state]

     ;; Valid intermediate byte
     [(and (dsp-intermediate-byte? ch)
           (or (dsp-csi-byte? prev) (dsp-parameter-byte? prev) (dsp-intermediate-byte? prev)))
      (vector-set! state DSP_SEQUENCE (append seq (list ch)))
      state]

     ;; Valid final byte
     [(and (dsp-final-byte? ch)
           (or (dsp-csi-byte? prev) (dsp-parameter-byte? prev) (dsp-intermediate-byte? prev)))

      (or
       (apply-pn #\Z 1 cbuf-cursor-backward-tabulation)
       (apply-pn #\G 1 cbuf-cursor-character-absolute)
       (apply-pn #\I 1 cbuf-cursor-forward-tabulation)
       (apply-pn #\E 1 cbuf-cursor-next-line)
       (apply-pn #\F 1 cbuf-cursor-preceding-line)
       (apply-pn #\D 1 cbuf-cursor-left)
       (apply-pn #\B 1 cbuf-cursor-down)
       (apply-pn #\C 1 cbuf-cursor-right)
       (apply-pn-pn #\H 1 1 cbuf-cursor-position)
       (apply-pn #\A 1 cbuf-cursor-up)
       (apply-pn #\Y 1 cbur-cursor-line-tabulation))])))

!#