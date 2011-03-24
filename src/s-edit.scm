;;; s-edit.scm -- a state loop for main editing functionality

(define (edit-state)
  "This procedure creates a text buffer and the edit commands
that operate on it."
  (let ([initialized #f]
        [buf #f]
        [frame #f]
        [dsp #f]
        [filename (if (defined? 'filename) filename "")])
    ;; PARENT VARIABLES
    ;; filename
    (let ([setup
           (lambda ()
             (set! buf (cbuf-make-buffer))
             (set! frame (frame-make-frame (cols) editwinrows))
             (set! dsp (dsp-make-state))
             ;; Load the file
             (s-edit-open-buffer filename buf))]

           [








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



(define (ax)
  (let* ([a 0]
         [do-hey (lambda () (set! a 1))]
         [do-ho (lambda () (set! a 2))]
         [do-hum (lambda () a)])
    (list (cons 'do-hey do-hey)
          (cons 'do-ho do-ho)
          (cons 'do-hum do-hum))))

(define-syntax edit-state
  (syntax-rules (setup update)
    ((edit-state setup x)
     (begin
       ((assoc-ref x 'do-hey))
       (write "hey")
       (newline)))
    ((edit-state update x)
     (begin
       ((assoc-ref x 'do-ho))
       (write "ho")
       (newline)))))
#t
)))

(define s-edit
  "The state variables and loop functions for the main editing window"
  (let ([buffer #f]
        [frame #f]
        [dsp #f])

    (define (setup)
      ;; Create the text buffer MVC
      (set! buffer (cbuf-make-buffer))
      (set! frame (frame-make-frame (
      ;; Menu information
      ;; Titlebar
      ;; Statusbar
      ;; Functions
      )

    (define (update)
      ;; Read a key
      ;; Call the associated method
      ;; No redraw, move cursor only, or total redraw enum
      )

    (define (draw)
      ;; Paint the titlebar
      ;; Paint the statusbar
      ;; Paint the edit window
      )
    ))