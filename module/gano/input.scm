(define-module (gano input)
  ;; #:use-module (gano config)
  #:use-module (ncurses curses)
  #:use-module (rnrs control)
  #:use-module (srfi srfi-1)
  #:export (
            get-kbinput
            kbinput-test
            ))


;; The maximum number of bytes buffered at one time.
(define MAX-TRIES 128)

;;If allow is TRUE, block any SIGWINCH signals that we get, so that we
;; can deal with them later.  If allow is FALSE, unblock any SIGWINCH
;; signals that we have, so that we can deal with them now.
(define (allow-pending-sigwinch allow)
  #f)

;; Call the low-level getch() , trying up to MAX-TRIES times to get
;; a valid character.  Return ERR on failure.
(define (try-getch win max-tries)
  (let ((c (getch win)))
    (cond
     (c
      ;; sucessfully got key
      c)

     ((> max-tries 0)
      ;; try again
      (try-getch win (1- max-tries)))

     (else
      #f))))

;; Get a key.  If nodelay-mode is true, try only once.  If it is
;; false, try multiple times to get a valid character
(define (get-key-or-hangup win nodelay-mode)
  (if nodelay-mode
      (try-getch win 0)
      ;; else
      (let ((c (try-getch win MAX-TRIES)))
        (or c
            ;; If we've failed to get a character MAX-TRIES times in
            ;; a row, assume that the input source we were using is
            ;; gone and we'll need to die gracefully.
            'hangup))))

;; Read in the first character, possibly with blocking input
(define (get-initial-key win block?)
  (if block?
      (nodelay! win #f)
      (nodelay! win #t))

  (allow-pending-sigwinch #t)

  ;; Just before reading in the first character, display any pending
  ;; screen updates.
  (doupdate)

  (let ((c (get-key-or-hangup win (not block?))))
    (when (eq? c 'hangup)
          (handle-hupterm 0))
    (allow-pending-sigwinch #f)
    (nodelay! win #t)
    (if (eq? c 'hangup)
        #f
        c)))

;; Read in subsequent characters with non-blocking input
(define (get-subsequent-key win)
  (nodelay! win #t)
  (allow-pending-sigwinch #t)
  (let ((c (get-key-or-hangup win #t)))
    (allow-pending-sigwinch #f)
    c))

(define (get-key-buffer win block?)
  (let ((initial (get-initial-key win block?)))
    (if (not initial)
        ;; No keys available, or port is dead
        #f

        ;; Found 1 key.  Look for more
        (let loop ((c (get-subsequent-key win))
                   (lst (list initial)))
          (if (not c)
              ;; no more keys waiting.  Return now.
              lst
              ;; else check for another key
              (loop (get-subsequent-key win) (append lst (list c))))))))

;; Buffer for unprocessed keypresses
(define key-buffer '())

(define (unget-key k)
  (set! key-buffer (append (list k) key-buffer)))

;; Update the keystroke buffer with any waiting characters, if any.
;; Then return the first INPUT-LEN characters of the buffer.  If less
;; than INPUT-LEN characters are available, just return what we have.
(define (get-input win input-len)
  (allow-pending-sigwinch #t)
  (allow-pending-sigwinch #f)

  (when win
        ;; Add any waiting keys to the key buffer.  If the key buffer
        ;; is empty, wait around for a key.
        (let ((new-keys (get-key-buffer win (null? key-buffer))))
          (when new-keys
                (set! key-buffer (append! key-buffer new-keys)))))

  (if (>= (length key-buffer) input-len)
      (let ((returned-keys (take key-buffer input-len)))
        (set! key-buffer (drop key-buffer input-len))
        returned-keys)
      ;; else
      (let ((returned-keys (list-copy key-buffer)))
        (set! key-buffer '())
        returned-keys)))

;; Translate ASCII characters, extended keypad values, and escape
;; sequences into their corresponding key values.
(define (parse-kbinput win)
  (let loop ((kbinput-list (get-input win 1))
             (escapes 0)
             (byte-digits 0))
    (let ((kbinput (if kbinput-list (car kbinput-list) #f)))
      (cond
       [(not kbinput)
        #f]

       ;; The escape key prefixes an extended sequence.
       [(eq? kbinput #\esc)
        (loop (get-input win 1) (1+ (modulo escapes 3)) byte-digits)]

       [(= escapes 0)
        ;; A normal non-escaped input
        (list 'raw kbinput)]

       [(= escapes 1)
        (cond
         [(and (char? kbinput) (null? key-buffer))
          ;; One escape followed by a non-escape, and there aren't any
          ;; other keystrokes waiting.  Treat this as a meta key.
          (list 'meta (char-downcase kbinput))]

         [(null? key-buffer)
          ;; One escape followed by a control key.  Meta the control key
          (list 'meta kbinput)]

         [else
          ;; One escape followed by multiple keystrokes.  The multiple
	  ;; keystrokes are some unhandled function key
          ;;(unget-key kbinput)
          ;;(list 'raw (parse-escape-seq-kbinput win))
	  #f])]

       [(= escapes 2)
        (cond
         [(and (null? key-buffer)
               (char? kbinput)
               (char>=? kbinput #\0)
               (char<=? kbinput #\9))
          ;; Two escapes followed by a decimal number indicates that we
          ;; are going to search for a decimal number, and then convert
          ;; it to a char
          (unget-key kbinput)
          (let ((codepoint (get-codepoint-kbinput win)))
            (if (and codepoint (false-if-exception (integer->char codepoint)))
                (list 'raw (integer->char codepoint))
                ;; else
                ;; number was not a valid codepoint.
                #f))]

         [(null? key-buffer)
          ;; Two escapes followed by a char could be mapped to
	  ;; Control-X.  But, for now, it is unused.
	  #f]

         [else
          ;; Two escapes followed by multiple keystrokes, means that
          ;; we're meta'ing an unhandled function key.
          ;;(unget-key kbinput)
          ;;(list 'meta (parse-escape-seq-kbinput win))])]
	  #f])]

       [(= escapes 3)
        (cond
         [(null? key-buffer)
          ;; Three escapes followed by a non escape with no other
          ;; character waiting just returns that character.
          (list 'raw kbinput)]

         [else
          ;; Three escapes followed by multiple keystrokes indicates
          ;; two escapes plus an unhandled function key.  Try to
          ;; parse the function key.  If yes, return the control'ed version
          ;; of that key.  If no, return #f.
          ;; (let ((seq (append (list kbinput) key-buffer)))
          ;;   (unget-key kbinput)
          ;;   (let ((k (parse-escape-seq-kbinput win)))
          ;;     (if k
          ;;         (list 'meta (get-control-kbinput k))
          ;;         (list 'raw #f))))])]))))
	  #f])]))))

;; Translate escape sequences that ncurses didn't handle.  If the
;; terminfo for the terminal you are using were complete, you would
;; never fall into this function.  Any time you're in this function,
;; you've used the wrong terminfo or (much less likely) it is a bug
;; upstream.
(define escape-seq
  '(("\x1b01;2A" . KEY-SR)                ; shift-up on terminal
    ("\x1b01;2B" . KEY-SF)                ; shift-down on terminal
    ("\x1b01;2C" . KEY-SRIGHT)            ; shift-right on terminal
    ("\x1b01;2D" . KEY-SLEFT)             ; shift-left on terminal
    ("\x1b01;2P" . (key-f 13))            ; f13 on gnome+pcfkeys
    ("\x1b01;2Q" . (key-f 14))            ; f14 on
    ("\x1b01;2R" . (key-f 15))
    ("\x1b01;2S" . (key-f 16))
    ("\x1b01;5A" . kUP5)                  ; ctrl-up on Terminal
    ("\x1b01;5B" . kDN5)                  ; ctrl-down on Terminal
    ("\x1b01;5C" . kRIT5)                  ; ctrl-right on Terminal
    ("\x1b01;5D" . kLFT5)                  ; ctrl-left on Terminal
    ("\x1b02P" . (key-f 13))))               ; F13 on xterm-xf86-v40, xterm+pcf0

(define (parse-escape-seq-kbinput win)
  (let ((key (assoc-ref escape-seq (apply string key-buffer))))
    (set! key-buffer '())
    key))

;; Translate a control character sequence: turn an ASCII non-control
;; character into its corresponding control character
(define (get-control-kbinput win)
  (let ((k (car key-buffer)))
    (set! key-buffer (drop key-buffer 1))
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
         ((and (char>=? k #\@) (char<=? k #\-))
          (integer->char (- (char->integer k) 64)))
         ((and (char>=? k #\`) (char<=? k #\~))
          (integer->char (- (char->integer k) 96)))
         (else
          k)))))


;; Read in a single character.  If it's ignored, swallow it and go on.
;; Otherwise, try to translate it from ASCII, meta key sequences,
;; escape sequences, and/or extended keypad values.  Set meta-key to
;; TRUE when we get a meta key sequence, and set func-key to TRUE when
;; we get an extended keypad value.  Supported extended keypad values
;; consist of [arrow key], Ctrl-[arrow key], Shift-[arrow key], Enter,
;; Backspace, the editing keypad (Insert, Delete, Home, End, PageUp,
;; and PageDown), the function keypad (F1-F16), and the numeric keypad
;; with NumLock off.  Assume nodelay(win) is FALSE.
(define (get-kbinput win)
  ;; Read in a character and interpret it.  Continue doing this until
  ;; we get a recognized value or sequence. */
  (let ((kbinput (parse-kbinput win)))
    (if (not kbinput)
        (begin
          (usleep 100)
          (get-kbinput win))
        (begin
          #; (when (eq? win edit) (check-statusblank))
          kbinput))))

(define (kbinput-test)
  (let ((win (initscr)))
    (cbreak!)
    (noecho!)
    (nonl!)
    (intrflush! #f)
    (keypad! win #t)
    (scrollok! win #t)
    (addstr win (format #f "Go~%"))
    (let loop ((lst (parse-kbinput win)))
      (addstr win "--> ")
      (when loop
            (addstr win (format #f "~s~%" lst))
            (loop (parse-kbinput win))))))
