m4_include(`config.m4')

(define-module (gano files)
  #:use-module (gano flags)
  #:use-module (gano global)
  #:use-module (gano winio)
  #:use-module (gano nano-h)
  #:use-module (gano nano-c)
  #:use-module (rnrs control)
  #:use-module (ncurses curses)
  #:export (
            open_buffer
            open_file
            display_buffer
            ))

;; Add an entry to the openfile openfilestruct.  This should only be
;; called from open_buffer().
(define (make_new_buffer)
  ;; If there are no entries in openfile, make the first one and move
  ;; to it
  (if (not (openfile?))
      (set-openfile! (make_new_opennode))
      ;; else
      ;;  Make a new entry for openfile, splice it in after the current entry,
      ;;  and move to it
      (append-openfile! (make_new_opennode)))

  ;; Initialize the new buffer
  (initialize_buffer))
  

;; Initialize the current entry in the openfile openfilestruct
(define (initialize_buffer)
  (openfile-filename-set! "")
  (initialize_buffer_text)
  (openfile-current_x-set! 0)
  (openfile-placewewant-set! 0)
  (openfile-current_y-set! 0)
  (openfile-modified-set! #f)
  m4_ifdef({NANO_TINY},{},{
  (openfilestruct-mark_set-set! (openfile) #f)
  (openfilestruct-mark_begin-set! (openfile) #f)
  (openfilestruct-mark_begin_x-set! (openfile) 0)
  (openfilestruct-fmt-set! (openfile) NIX_FILE)
  (openfilestruct-current_stat-set! (openfile) #f)
  (openfilestruct-undotop-set! (openfile) #f)
  (openfilestruct-current_undo-set! (openfile) #f)
  })
  m4_ifdef({ENABLE_COLOR},{
  (openfilestruct-colorstrings-set! (openfile) #f)
  })
  )


;; If it is not "", filename is a file to open.  We make a new buffer
;; if necessary, and then open and read the file, if applicable
(define (open_buffer filename undoable)
  (let ((new_buffer (or (not (openfile?))
                        m4_ifdef({ENABLE_MULTIBUFFER},{
                        (ISSET MULTIBUFFER)
                        })
                        ))
        (f #f)
        (rc 0))       ; -2 means new file. -1 open failure. 0 success.
    m4_ifdef({DISABLE_OPERATINGDIR},{},{
    (when (check_operating_dir filename #f)
          (statusbar (_ "Can't insert file from outside of ~a") operating_dir)
          (error "FIXME-MLG: add return logic here"))
    })
    
    ;: If the filename isn't blank, open the file.  Otherwise treat it
    ;; as a new file.
    (set! rc (if (not (string-null? filename))
                 (open_file filename new_buffer f)
                 -2))

    ;; If we're loading into a new buffer, add a new entry to openfile */
    (when new_buffer
          (make_new_buffer))

    ;; If we have a file, and we're loading into a new buffer, update
    ;; the filename
    (when (and (= rc -1)
               new_buffer)
          (openfile-filename-set! (string-copy filename)))
    
    ;; If we have a non-new file, read it in.  The, if the buffer has no
    ;; stat, update the stat, if applicable.
    (when (> rc 0)
          (read_file f rc filename undoable new_buffer)
          m4_ifdef({NANO_TINY},{},{
          (unless (openfile-current_stat)
                  (openfile-current_stat-set! (stat filename)))
          }))

    ;; If we have a file, and we're loading into a new buffer, move
    ;; back to the beginning of the first line of the buffer.
    (when (and (not (= rc -1))
               new_buffer)
          (openfile-current-index-set! 0)
          (openfile-current_x-set! 0)
          (openfile-placewewant-set! 0))

    m4_ifdef({ENABLE_COLOR},{
    ;; If we're loading into a new buffer, update the colors to 
    ;; account for it, if applicable
    (when new_buffer
          (color_update))
    })
    ))


;; Open the file (and decide if it exists).  If newfie is TRUE,
;; display "New File" if the file is missing.  Otherwise, say
;; "[filename] not found".

;; Return -2 if we say "New File", -1 if the file isn't opened, and
;; the fd opened otherwise.  The file might still have an error while
;; reading with a 0 return value.  *f is set to the opened file.
(define (open_file filename newfie f)
  (let ((full_filename (get_full_path filename)))

    ;; Okay, if we can't check the full path due to a component's
    ;; permissions, just try to relative one.
    (when (or (not full_filename)
              (and
               (not (file-exists? full_filename))
               (file_exists? filename)))
          (set! full_filename filename))

    (let ((fileinfo (false-if-exception (stat full_filename))))
      (cond
       ((eq? fileinfo #f)
        ;; The file couldn't be opened by stat, which means that this
        ;; file either doesn't exist or is strange in some obscure
        ;; way.  We'll try to open it, which will likely fail.
        (let ((port (false-if-exception (open-input-file filename))))
          (cond
           (port
            ;; Strange, I could open it for some reason.  I have no
            ;; idea what I'm supposed to do now.
            ;; FIXME
            (statusbar (_ "Reading File"))
            0)
           (newfie
            (statusbar (_ "New File"))
            -2)
           (else
            (statusbar (_ "\"~a\" not found") filename)
            (beep)
            -1))))

       ((member (stat:type fileinfo) '(directory block-special char-special))
        ;; Don't open directories, character files, or block files
        (if (eq? 'directory (stat:type fileinfo))
            (statusbar (format #f (_ "\"~a\" is a directory") filename))
            (statusbar (format #f (_ "\"~a\" is a device file") filename)))
        (beep)
        -1)
       
       (else
        ;; This looks like it *should* be openable.  Let's try.
        (let ((port (false-if-exception (open-file full_filename "r"))))
          (if (not port)
              (begin
                (statusbar (_ "Error reading ~a") filename)
                ;; FIXME: can I have a more detailed error message?
                (beep)
                -1)
              ;; else
              (begin
                (statusbar (_ "Reading File"))
                port))))))))

;; Get the full path from a relative path
(define (get_full_path origpath)
  
  ;; Get the current directory.  Under strange permission conditions,
  ;; we might have to move toward the root directory before we can get
  ;; the working directory
  (let* ((d_here (let loop ((d (false-if-exception (getcwd))))
                   (if d
                       d
                       (if (false-if-exception (chdir ".."))
                           (loop (false-if-exception (getcwd)))
                           #f))))
         ;; Tack on a terminating slash
         (d_here_slash (cond
                        ((not d_here)
                         #f)
                        ((string=? d_here "/")
                         "")
                        (else
                         (string-append d_here "/"))))
         ;;
         (d_there (real_dir_from_tilde origpath))
         (path_only (let ((s (false-if-exception (stat d_there))))
                      (and s (eq? 'directory (stat:type s)))))
         ;; if this is a path, add a terminating slash
         (d_there_slash (if (and path_only
                                 (string=? "/" (string-take-right d_there 1)))
                            (string-append d_there "/")
                            d_there)))

    (cond
     
     ;; If d_there is just a filename, append the full cwd path to it
     ((and (not path_only)
           (string=? d_there (basename d_there)))
      (chdir d_here)
      (string-append d_here_slash d_there))

     ;; Otherwise, try to cd into d_there's path
     ((false-if-exception (chdir (dirname d_there_slash)))
      (let* ((fullpath (false-if-exception (getcwd)))
             (fullpath_slash (if (and fullpath 
                                      (string=? "/" (string-take-right fullpath 1)))
                                 (string-append fullpath "/")
                                 fullpath)))
        (chdir d_here)
        fullpath))

     ;; Otherwise d_there's path is jacked up, give up
     (else
      (chdir d_here)
      #f))))
                    
;; Return a malloc()ed string containing the actual directory, used to
;; convert ~user/ and ~/ notation.
(define (real_dir_from_tilde buf)
  (cond
   ((string-null? buf)
    buf)

   ;; In our own tilde directory
   ((and (>= (string-length buf) 2)
         (string=? "~/" (string-take buf 2)))
    (get_homedir)
    (string-append homedir (string-drop buf 2)))

   ;; In another user's tilde directory
   ((and (>= (string-length buf) 1)
         (string=? "~" (string-take buf 1)))
    (let* ((index (string-index buf #\/))
           (username (if index
                         (substring buf 1 index)
                         (substring buf 1)))
           (userpw (false-if-exception (getpwnam username))))
      (if userpw
          ;; return a path with an expanded user's directory
          (string-append (passwd:dir userpw)
                         (string-drop buf index))
          ;; else
          ;; This user doesn't exit.  Upstream Nano strips
          ;; of the user and returns the rest, which seems 
          ;; wrong.  FIXME?
          (string-drop buf index))))

   ;; Otherwise, this is not a tilde path
   (else
    buf)))

;; update the screen to account for the current buffer
(define (display_buffer)
  (titlebar #f)
  m4_ifdef({ENABLE_COLOR},{
  (color_init)
  })
  ;; Update the edit window
  (edit_refresh))