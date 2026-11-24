;;; s-edit.scm -- a state loop for main editing functionality

;; Set type of function based on the string
(define (key-type-from-key-string str)
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

(define META #t)
(define NOMETA #f)

;; function_type
(define CONTROL 0)
(define META 1)
(define FKEY 2)
(define RAW 3)

(define (key-string->event keystr)
  "Pre-process the key string into its components."
  (let* ([type (key-type-from-key-string keystr)]
         [meta NOMETA]
         [key #f]
         [SET (lambda (m k)
                (set! meta m)
                (set! key k))]
         [KEYPAD (lambda (k)
                   (and (eq? type RAW) (string-ci=? k keystr)))])
    (cond
     [(eqv? type CONTROL)
      (SET NOMETA (integer->char (- (char->integer (string-ref keystr 1)) 64)))]
     [(eqv? type META)
      (SET META (char-downcase (string-ref keystr 2)))]
     [(eqv? type FKEY)
      (SET NOMETA (key-f (string->number (string-drop keystr 1))))]
     [else
      (SET NOMETA (string-ref keystr 0))])

    ;; Process keys that have long names
    (cond
     [(and (eq? type CONTROL)
           (string-ci=? "space" (string-drop keystr 1)))
      (SET NOMETA 0)]
     [(and (eq? type META)
           (string-ci=? "space" (string-drop keystr 2)))
      (SET META #\space)]
     [(KEYPAD "kup")     (SET NOMETA KEY_UP)]
     [(KEYPAD "kdown")   (SET NOMETA KEY_DOWN)]
     [(KEYPAD "kleft")   (SET NOMETA KEY_LEFT)]
     [(KEYPAD "kright")  (SET NOMETA KEY_RIGHT)]
     [(KEYPAD "kinsert") (SET NOMETA KEY_IC)]
     [(KEYPAD "kdel")    (SET NOMETA KEY_DC)]
     [(KEYPAD "kbsp")    (SET NOMETA KEY_BACKSPACE)]
     [(KEYPAD "kenter")  (SET NOMETA KEY_ENTER)]
     [(KEYPAD "kpup")    (SET NOMETA KEY_PPAGE)]
     [(KEYPAD "kpdown")  (SET NOMETA KEY_NPAGE)]
     [(KEYPAD "khome")   (SET NOMETA KEY_HOME)]
     [(KEYPAD "kend")    (SET NOMETA KEY_END)]
     [(and (eq? type RAW)
           (> (string-length keystr) 1))
      (error "bad keystr ~s~%" keystr)])
    (list key meta)))

(define K key-string->event)

;; A list

(define (edit-state)
  "This procedure creates a text buffer and the edit commands
that operate on it."
  (let* ([buf #f]
         [frame #f]
         [dsp #f]
         [BFS (lambda () (list buf frame dsp))]
         [keymap #f]
         [filename (if (and (defined? 'filename)
                            filename)
                       filename "")]

         [forward-char
          (lambda ()
            "Move the active data position forward."
            ;; At the end of the buffer, do nothing
            ;; At the end of the line, move to the beginning of next line
            ;; Otherwise, move right
            (unless (cbuf-end-of-buffer? buf)
              (cond
               [(cbuf-end-of-line? buf)
                (dsp-id-dispatch! 'CNL (BFS))]
               [else
                (dsp-id-dispatch! 'HPR (BFS))])
              #t))]

         [backward-char
          (lambda ()
            "Move the active data position backward."
            ;; At the beginning of the buffer, do nothing
            ;; At the beginning of a line, move to the end of the previous line
            ;; Otherwise, move left
            (unless (cbuf-beginning-of-buffer? buf)
              (cond
               [(cbuf-beginning-of-line? buf)
                (dsp-id-dispatch! 'CPL (BFS))
                (dsp-id-dispatch! 'HPAn (BFS) (cbuf-get-text-cur-base-length buf))]
               [else
                (dsp-id-dispatch! 'HPB (BFS))]))
            #t)]

         [previous-line
          (lambda ()
            ;; In the first line of the buffer, do nothing
            ;; Otherwise, move up to the goal column or end of the line,
            ;; whichever is less.  Don't change the goal column when moving up.
            (unless (= 0 (cbuf-get-y buf))
              (dsp-id-dispatch! 'CUU (BFS)))
            #t)]

         [next-line
          (lambda ()
            "Move to the next line in the buffer"
            ;; In the last line of the buffer, do nothing.  Otherwise,
            ;; move down to the goal column or end of line, whichever
            ;; is less.  Don't change the goal column when moving up.
            (unless (= (cbuf-get-y buf) (cbuf-get-line-count buf))
              (dsp-id-dispatch! 'CUD (BFS)))
            #t)]

         [beginning-of-line
          (lambda ()
            "Move to the first position in the line"
            (dsp-id-dispatch! 'HPA (BFS))
            #t)]

         [end-of-line
          (lambda ()
            "move to the last position in the line"
            (dsp-id-dispatch! 'HPAn (BFS) (cbuf-get-text-cur-base-length buf))
            #t)]

         [page-down
          (lambda ()
            "Move to this position on the next page."
            (unless (cbuf-on-last-page? buf)
              (dsp-id-dispatch! 'PPR (BFS)))
            #t)]

         [page-up
          (lambda ()
            "Move to this position on the previous page"
            (unless (cbuf-on-first-page? buf)
              (dsp-id-dispatch! 'PPB (BFS)))
            #t)]

         [delete-char
          (lambda ()
            "Delete the character under the cursor"
            ;; If at the end of buffer, do nothing.  If at the end of
            ;; line, join line below to this line.  Otherwise, remove
            ;; the character at the active data position.
            (unless (cbuf-end-of-buffer? buf)
              (cond
               [(cbuf-end-of-line? buf)
                (dsp-id-dispatch! 'DNL (BFS))
                (s-edit-refresh buf frame)]
               [else
                (dsp-id-dispatch! 'DCH (BFS))]))
            #t)]

         [insert-tab
          (lambda ()
            (dsp-id-dispatch! 'ICP (BFS) #\tab)
            #t)]

         [cursor-position
          (lambda()
            "Display info about the cursor position"
            (let* ([line-cur (cbuf-get-y buf)]
                   [line-max (cbuf-get-line-count buf)]
                   [line-ratio (if (zero? line-max)
                                   0
                                   (quotient (* 100 line-cur) line-max))]
                   [col-cur (1+ (cbuf-get-x-cell buf))]
                   [col-max (1+ (cbuf-get-text-cur-cell-length buf))]
                   [col-ratio (if (zero? col-max)
                                  0
                                  (quotient (* 100 col-cur) col-max))])
              (winio-statusbar (format #f "line ~a/~a (~a%), col ~a/~a (~a%)"
                                       line-cur line-max line-ratio
                                       col-cur col-max col-ratio)))
            #t)]
         [*cmd-keymap*
          (list
           (cons (K "^F") forward-char)
           (cons (K "^B") backward-char)
           (cons (K "^P") previous-line)
           (cons (K "^N") next-line)
           (cons (K "^A") beginning-of-line)
           (cons (K "^E") end-of-line)
           (cons (K "^V") page-down)
           (cons (K "^Y") page-up)
           (cons (K "^D") delete-char)
           (cons (K "^I") insert-tab)
           (cons (K "f8") cursor-position)
           ;;(cons (K "^^") mark)
           ;;(cons (K "^K") cut)
           ;;(cons (K "^U") paste)
           ;;(cons (K "^J") justify)
           ;;(cons (K "^Z") undo))
           )]

         [*state-keymap*
          (list
           ;;(cons (K "^G") help-state)
           ;;(cons (K "^W") search-state)
           ;;(cons (K "^T") spell-state)
           ;;(cons (K "^R") read-file-state)
           ;;(cons (K "^X") exit-state))
           (cons (K "f12") (lambda () #t))
           )])
    (let ([setup
           (lambda ()
             (clear vWinMain)
             (refresh vWinMain)
             (clear vWinEdit)
             (addstr vWinEdit "making buffer: ")
             (addstr vWinEdit filename)
             (refresh vWinEdit)
             (sleep 1)
             (set! buf (make-empty-cbuffer))
             (set! frame (frame-make-frame (cols) editwinrows))
             (set! dsp (dsp-make-state))
             ;; Load the file
             (s-edit-open-buffer filename buf))]

          [update
           (lambda ()
             (let* ([kbinput (input-get-kbinput vWinEdit)]
                    [meta (eq? (first kbinput) 'meta)]
                    [input (second kbinput)])
               (cond
                ;; First, check if it is an text-editing command
                [(assoc (list input meta) *cmd-keymap*)
                 ((cdr (assoc (list input meta) *cmd-keymap*)))]

                ;; Next, see if it is a state-changing command
                [(assoc (list input meta) *state-keymap*)
                 ((assoc (list input meta) *state-keymap*))]

                ;; Otherwise, try it as a regular character
                [(and (not meta)
                      (char? input)
                      (or (char=? input #\space)
                          (char=? input #\tab)
                          (char-set-contains? char-set:graphic input)))
                 (dsp-id-dispatch! 'ICP (BFS) input)
                 #t]

                ;; Newline
                [(and (not meta)
                      (or (eqv? input #\newline)
                          (eqv? input KEY_ENTER)))
                 (dsp-id-dispatch! 'INL (BFS))
                 #t]

                ;; If this was a non-printing key that has no function
                ;; then error.
                [(or meta (not (char? input)))
                 (winio-statusbar "Unknown Command")
                 (beep)
                 #t]

                [else
                 ;; non-printing regular character?
                 #t])))]

          [draw
           (lambda ()
             (winio-titlebar "" filename 'modified 'edit)
             (attr-off! vWinTop A_REVERSE)
             (refresh vWinTop)
             (s-edit-bottombars)
             (s-edit-refresh buf frame))])
      (state-methods setup update draw))))

(define (s-edit-bottombars)
  "Display the shortcut list in the last two rows of the bottom
portion of the window"
  (winio-blank-bottombars)
  (let* ([MAX_ENTRIES 12]
         [i 0]
         [x-limit (cadr (getmaxyx vWinMain))]
         [colwidth (quotient x-limit (+ (quotient MAX_ENTRIES 2)
                                        (remainder MAX_ENTRIES 2)))])
    (for-each (lambda (entry)
                (addstr vWinEdit (format #f "~s" entry))
                (refresh vWinEdit)
                (move vWinBottom (+ 1 (remainder i 2))
                      (* colwidth (quotient i 2)))
                (onekey (car entry)
                        (cdr entry)
                        (+ colwidth (remainder (cols) colwidth)))
                (set! i (+ i 1)))
              '(("^G" . "Get Help")
                ("^X" . "Exit")))
    (refresh vWinBottom)))


;; If it is not "", FILENAME is a file to open.  If filename can be opened
;; we put in into BUFFER.  If it can't be opened, we display an error
(define (s-edit-open-buffer filename buf)
  (unless (string-null? filename)
    (let ([inport (s-edit-open-port filename)])
      (when inport
        ;; If we have a non-new file, read it in.  The, if the buffer has no
        ;; stat, update the stat, if applicable.
        (s-edit-load-from-port inport buf)))))

;; Returns a port set to the input file, if possible.  #f otherwise.
;; Writes to the statusbar.
(define (s-edit-open-port filename)
  (let ((full-filename (get_full_path filename)))

    ;; If we can't check the full path due to a component's
    ;; permissions, just try the relative one.
    (when (or (not full-filename)
              (and
               (not (file-exists? full-filename))
               (file-exists? filename)))
      (set! full-filename filename))

    (let ((fileinfo (false-if-exception (stat full-filename))))
      (cond
       ((eq? fileinfo #f)
        ;; The file couldn't be opened by stat, which means that this
        ;; file either doesn't exist or is strange in some obscure
        ;; way.  We'll try to open it, which will likely fail.
        (let ([port (false-if-exception (open-input-file filename))])
          (cond
           [port
            ;; Strange, I could open it for some reason.  I have no
            ;; idea what I'm supposed to do now.
            ;; FIXME
            (winio-statusbar "Reading File")
            port]
           [else
            (winio-statusbar (format #f "\"~a\" not found" filename))
            (beep)
            #f])))

       ((member (stat:type fileinfo) '(directory block-special char-special))
        ;; Don't open directories, character files, or block files
        (if (eq? 'directory (stat:type fileinfo))
            (winio-statusbar (format #f "\"~a\" is a directory" filename))
            (winio-statusbar (format #f "\"~a\" is a device file" filename)))
        (beep)
        #f)

       (else
        ;; This looks like it *should* be openable.  Let's try.
        (let ((port (false-if-exception (open-file full-filename "r"))))
          (if (not port)
              (begin
                (winio-statusbar (format #f "Error reading ~a" filename))
                ;; FIXME: can I have a more detailed error message?
                (beep)
                #f)
              ;; else
              (begin
                (winio-statusbar "Reading File")
                port))))))))

(define (s-edit-load-from-port prt buf)
  "Copy the file into the buffer, one line at a time"
  (let loop ([line (read-line prt)])
    (unless (eof-object? line)
      (cbuf-set-text! buf
                      (append (cbuf-get-text buf)
                              (list line)))
      (loop (read-line prt)))))


;; Refresh the screen without changing the position of lines.  Use
;; this if we'ved moved and changed text.
(define (s-edit-refresh buf frame)
  (when (and buf frame)
    (let ([strings (frame-render-frame buf frame)])

      (map
       (lambda (y)
         (let ([txt (list-ref strings y)])
           (log-debug (format #f "winio-edit-refresh: ~a: ~s" y txt))
           (addstr vWinEdit txt #:x 0 #:y y)))
       (iota editwinrows))
      (s-edit-reset-cursor buf frame)))
  (refresh vWinEdit))

(define (s-edit-reset-cursor buf frame)
  "Put the curses's cursor at the current location in the frame"
  (cond
   ;; If we haven't opened any files yet, put the cursor in the top
   ;; left corner of the edit window and get out.
   [(not buf)
    (move vWinEdit 0 0)]

   [else
    (let* ([x-cell (cbuf-get-x-cell buf)])
      (log-debug (format #f "winio-reset-cursor: active position (~a,~a), top of frame (~a, ~a)"
                         x-cell (cbuf-get-y buf)
                         (frame-get-x-start frame)
                         (frame-get-y-start frame)))
      ;; If the cursor is in the frame, display it
      (let ([y-cur (- (cbuf-get-y buf) (frame-get-y-start frame))]
            [x-cur (- x-cell (frame-get-x-start frame))])
        (cond
         [(and (>= y-cur 0)
               (< y-cur (frame-get-height frame))
               (>= x-cur 0)
               (< x-cur (frame-get-width frame)))
          (move vWinEdit y-cur x-cur)
          (curs-set 1)
          (log-debug (format #f "winio-reset-cursor: cursor position (~a, ~a)"
                             x-cur y-cur))]
         [else
          ;; Otherwise, hide it
          (curs-set 0)])))]))



