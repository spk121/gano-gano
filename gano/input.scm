(define-module (gano input)
  #:use-module (gano config)
  #:use-module (ncurses curses)
  #:use-module (rnrs control)
  #:use-module (srfi srfi-1)
  #:export (
            get_kbinput
            ))


;; The maximum number of bytes buffered at one time.
(define MAX_TRIES 128)

;;If allow is TRUE, block any SIGWINCH signals that we get, so that we
;; can deal with them later.  If allow is FALSE, unblock any SIGWINCH
;; signals that we have, so that we can deal with them now.
(define (allow_pending_sigwinch allow)
  #f)

;; Call the low-level getch() , trying up to MAX_TRIES times to get
;; a valid character.  Return ERR on failure.
(define (try_getch win max_tries)
  (let ((c (getch win)))
    (cond
     (c
      ;; sucessfully got key
      c)

     ((> max_tries 0)
      ;; try again
      (try_getch win (1- max_tries)))

     (else
      #f))))

;; Get a key.  If nodelay_mode is true, try only once.  If it is
;; false, try multiple times to get a valid character
(define (get_key_or_hangup win nodelay_mode)
  (if nodelay_mode
      (try_getch win 0)
      ;; else
      (let ((c (try_getch win MAX_TRIES)))
        (or c
            ;; If we've failed to get a character MAX_TRIES times in
            ;; a row, assume that the input source we were using is
            ;; gone and we'll need to die gracefully.
            'hangup))))

;; Read in the first character, possibly with blocking input
(define (get_initial_key win block?)
  (if block?
      (nodelay! win #f)
      (nodelay! win #t))

  (allow_pending_sigwinch #t)

  ;; Just before reading in the first character, display any pending
  ;; screen updates.
  (doupdate)

  (let ((c (get_key_or_hangup win (not block?))))
    (when (eq? c 'hangup)
          (handle_hupterm 0))
    (allow_pending_sigwinch #f)
    (nodelay! win #t)
    (if (eq? c 'hangup)
        #f
        c)))

;; Read in subsequent characters with non-blocking input
(define (get_subsequent_key win)
  (nodelay! win #t)
  (allow_pending_sigwinch #t)
  (let ((c (get_key_or_hangup win #t)))
    (allow_pending_sigwinch #f)
    c))

(define (get_key_buffer win block?)
  (let ((initial (get_initial_key win block?)))
    (if (not initial)
        ;; No keys available, or port is dead
        #f

        ;; Found 1 key.  Look for more
        (let loop ((c (get_subsequent_key win))
                   (lst (list initial)))
          (if (not c)
              ;; no more keys waiting.  Return now.
              lst
              ;; else check for another key
              (loop (get_subsequent_key win) (append lst (list c))))))))

;; Buffer for unprocessed keypresses
(define key_buffer '())

(define (unget_key k)
  (set! key_buffer (append (list k) key_buffer)))

;; Update the keystroke buffer with any waiting characters, if any.
;; Then return the first INPUT_LEN characters of the buffer.  If less
;; than INPUT_LEN characters are available, just return what we have.
(define (get_input win input_len)
  (allow_pending_sigwinch #t)
  (allow_pending_sigwinch #f)

  (when win
        ;; Add any waiting keys to the key buffer.  If the key buffer
        ;; is empty, wait around for a key.
        (let ((new_keys (get_key_buffer win (null? key_buffer))))
          (when new_keys
                (set! key_buffer (append! key_buffer new_keys)))))

  (if (>= (length key_buffer) input_len)
      (let ((returned_keys (take key_buffer input_len)))
        (set! key_buffer (drop key_buffer input_len))
        returned_keys)
      ;; else
      (let ((returned_keys (list-copy key_buffer)))
        (set! key_buffer '())
        returned_keys)))

;; Translate ASCII characters, extended keypad values, and escape
;; sequences into their corresponding key values.
(define (parse_kbinput win)
  (let loop ((kbinput_list (get_input win 1))
             (escapes 0)
             (byte_digits 0))
    (let ((kbinput (if kbinput_list (car kbinput_list) #f)))
      (cond
       [(not kbinput)
        #f]

       ;; The escape key prefixes an extended sequence.
       [(eq? kbinput #\esc)
        (loop (get_input win 1) (1+ (modulo escapes 3)) byte_digits)]

       [(= escapes 0)
        ;; A normal non-escaped input
        (list 'raw kbinput)]

       [(= escapes 1)
        (cond
         [(and (char? kbinput) (null? key_buffer))
          ;; One escape followed by a non-escape, and there aren't any
          ;; other keystrokes waiting.  Treat this as a meta key.
          (list 'meta (char-downcase kbinput))]

         [(null? key_buffer)
          ;; One escape followed by a control key.  Meta the control key
          (list 'meta kbinput)]

         [else
          ;; One escape followed by multiple keystrokes.  The multiple
	  ;; keystrokes are some unhandled function key
          ;;(unget_key kbinput)
          ;;(list 'raw (parse_escape_seq_kbinput win))
	  #f])]

       [(= escapes 2)
        (cond
         [(and (null? key_buffer)
               (char? kbinput)
               (char>=? kbinput #\0)
               (char<=? kbinput #\9))
          ;; Two escapes followed by a decimal number indicates that we
          ;; are going to search for a decimal number, and then convert
          ;; it to a char
          (unget_key kbinput)
          (let ((codepoint (get_codepoint_kbinput win)))
            (if (and codepoint (false-if-exception (integer->char codepoint)))
                (list 'raw (integer->char codepoint))
                ;; else
                ;; number was not a valid codepoint.
                #f))]

         [(null? key_buffer)
          ;; Two escapes followed by a char could be mapped to
	  ;; Control-X.  But, for now, it is unused.
	  #f]

         [else
          ;; Two escapes followed by multiple keystrokes, means that
          ;; we're meta'ing an unhandled function key.
          ;;(unget_key kbinput)
          ;;(list 'meta (parse_escape_seq_kbinput win))])]
	  #f])]

       [(= escapes 3)
        (cond
         [(null? key_buffer)
          ;; Three escapes followed by a non escape with no other
          ;; character waiting just returns that character.
          (list 'raw kbinput)]

         [else
          ;; Three escapes followed by multiple keystrokes indicates
          ;; two escapes plus an unhandled function key.  Try to
          ;; parse the function key.  If yes, return the control'ed version
          ;; of that key.  If no, return #f.
          ;; (let ((seq (append (list kbinput) key_buffer)))
          ;;   (unget_key kbinput)
          ;;   (let ((k (parse_escape_seq_kbinput win)))
          ;;     (if k
          ;;         (list 'meta (get_control_kbinput k))
          ;;         (list 'raw #f))))])]))))
	  #f])]))))

;; Translate escape sequences that ncurses didn't handle.  If the
;; terminfo for the terminal you are using were complete, you would
;; never fall into this function.  Any time you're in this function,
;; you've used the wrong terminfo or (much less likely) it is a bug
;; upstream.
(define escape_seq
  '(("\x1b01;2A" . KEY_SR)                ; shift-up on terminal
    ("\x1b01;2B" . KEY_SF)                ; shift-down on terminal
    ("\x1b01;2C" . KEY_SRIGHT)            ; shift-right on terminal
    ("\x1b01;2D" . KEY_SLEFT)             ; shift-left on terminal
    ("\x1b01;2P" . (key-f 13))            ; f13 on gnome+pcfkeys
    ("\x1b01;2Q" . (key-f 14))            ; f14 on
    ("\x1b01;2R" . (key-f 15))
    ("\x1b01;2S" . (key-f 16))
    ("\x1b01;5A" . kUP5)                  ; ctrl-up on Terminal
    ("\x1b01;5B" . kDN5)                  ; ctrl-down on Terminal
    ("\x1b01;5C" . kRIT5)                  ; ctrl-right on Terminal
    ("\x1b01;5D" . kLFT5)                  ; ctrl-left on Terminal
    ("\x1b02P" . (key-f 13))))               ; F13 on xterm-xf86-v40, xterm+pcf0

(define (parse_escape_seq_kbinput win)
  (let ((key (assoc-ref escape_seq (apply string key_buffer))))
    (set! key_buffer '())
    key))

;; Translate a control character sequence: turn an ASCII non-control
;; character into its corresponding control character
(define (get_control_kbinput win)
  (let ((k (car key_buffer)))
    (set! key_buffer (drop key_buffer 1))
    (if (integer? k)
        ;; This is a keycode
        (list 'control k)
        ;; else
        (cond
         ((or (char=? k #\space) (char=? k #\2))
          #\nul)
         ((char=? k #\\)
          #\us)
         ((and (char>=? k #\3) (char<=? k #\7))
          (integer->char (- (char->integer k) 24)))
         ((or (char=? k #\8) (char=? k #\?))
          #\del)
         ((and (char>=? k #\@) (char<=? k #\_))
          (integer->char (- (char->integer k) 64)))
         ((and (char>=? k #\`) (char<=? k #\~))
          (integer->char (- (char->integer k) 96)))
         (else
          k)))))


;; Read in a single character.  If it's ignored, swallow it and go on.
;; Otherwise, try to translate it from ASCII, meta key sequences,
;; escape sequences, and/or extended keypad values.  Set meta_key to
;; TRUE when we get a meta key sequence, and set func_key to TRUE when
;; we get an extended keypad value.  Supported extended keypad values
;; consist of [arrow key], Ctrl-[arrow key], Shift-[arrow key], Enter,
;; Backspace, the editing keypad (Insert, Delete, Home, End, PageUp,
;; and PageDown), the function keypad (F1-F16), and the numeric keypad
;; with NumLock off.  Assume nodelay(win) is FALSE.
(define (get_kbinput win)
  ;; Read in a character and interpret it.  Continue doing this until
  ;; we get a recognized value or sequence. */
  (let ((kbinput (parse_kbinput win)))
    (if (not kbinput)
        (begin
          (usleep 100)
          (get_kbinput win))
        (begin
          ;; (when (eq? win edit)
          ;;    (check_statusblank))
          kbinput))))

(define (test)
  (let ((win (initscr)))
    (cbreak!)
    (noecho!)
    (nonl!)
    (intrflush! #f)
    (keypad! win #t)
    (scrollok! win #t)
    (addstr win (format #f "Go~%"))
    (let loop ((lst (parse_kbinput win)))
      (addstr win "--> ")
      (when loop
            (addstr win (format #f "~s~%" lst))
            (loop (parse_kbinput win))))))
