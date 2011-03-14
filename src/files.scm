;;; files.scm
;;;
;;; Copyright (C) 2010 Michael L. Gran
;;; Copyright (C) 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009 Free Software Foundation, Inc.

;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU General Public License as
;;; published by the Free Software Foundation; either version 3, or
;;; (at your option) any later version.

;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;;; General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, write to the Free Software
;;; Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
;;; 02110-1301, USA.

;;; This file incorporates code from GNU Nano


;; The Old-school R5RS 'class' for a open file.  It contains the
;; subclasses for the buffer, the frame, the controller as well as
;; some additional properties

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CLASS and PRIMITIVES

(define-condition-type &openfile-error &condition
  openfile-error?)

(define OPENFILE_BUFFER 1)
(define OPENFILE_FRAME 2)
(define OPENFILE_STATE 3)
(define OPENFILE_FILENAME 4)
(define OPENFILE_LENGTH (+ 1 OPENFILE_FILENAME))

(define (openfile-get-buffer f)    (vector-ref f OPENFILE_BUFFER))
(define (openfile-get-frame f)     (vector-ref f OPENFILE_FRAME))
(define (openfile-get-state f)     (vector-ref f OPENFILE_STATE))
(define (openfile-get-filename f)  (vector-ref f OPENFILE_FILENAME))

(define (openfile-set-buffer! f x)    (vector-set! f OPENFILE_BUFFER x))
(define (openfile-set-frame! f x)     (vector-set! f OPENFILE_FRAME x))
(define (openfile-set-state! f x)     (vector-set! f OPENFILE_STATE x))
(define (openfile-set-filename! f x)  (vector-set! f OPENFILE_FILENAME x))

(define (openfile-make-openfile)
  "Create a structure that represents a file being edited."
  (let ((x (make-vector OPENFILE_LENGTH #f)))
    (vector-set! x 0 'openfile)
    (openfile-set-buffer! x (cbuf-make-buffer))
    (openfile-set-frame! x (frame-make-frame))
    (openfile-set-state! x (dsp-make-state))
    x))


;; The list of open files.  The current file is always the first element.
(define *openfile-list* '())
(define (openfile-buffer)
  "The file buffer of the currently open file"
  (if (null? *openfile-list*)
      #f
      (openfile-get-buffer (first *openfile-list*))))

(define (openfile-frame)
  "The frame of the currently open file"
  (if (null? *openfile-list*)
      #f
      (openfile-get-frame (first *openfile-list*))))

(define (openfile-state)
  "The dispatch parser state of the currently open file"
  (if (null? *openfile-list*)
      #f
      (openfile-get-state (first *openfile-list*))))

(define (openfile-BFS)
  "Buffer, frame, and state of top open file"
  (let* ([of (first *openfile-list*)]
         [B (openfile-get-buffer of)]
         [F (openfile-get-frame of)]
         [S (openfile-get-state of)])
    (list B F S)))


;; If it is not "", filename is a file to open.  We make a new buffer
;; if necessary, and then open and read the file, if applicable
(define (OpenBuffer fileName fUndoable)
  (let ([fBufferNew (or (null? *openfile-list*) (ISSET MULTIBUFFER))]
        [f #f]
        [returnCode 0])       ; -2 means new file. -1 open failure. 0 success.

    (cond
     [(CheckOperatingDir? fileName #f)
      (winio-statusbar (format #f "Can't insert file from outside of ~a" vDirOperating))]

     [else
      ;; If the filename isn't blank, open the file.  Otherwise treat
      ;; it as a new file.
      (set! returnCode (cond [(not (string-null? fileName))
                              (OpenFile fileName fBufferNew f)]
                             [else
                              -2]))

      ;; If we're loading into a new buffer, add a new entry to
      ;; openfile.
      (when fBufferNew
        (set! *openfile-list* (append! (list (openfile-make-openfile))
                                   *openfile-list*)))

      ;; If we have a file, and we're loading into a new buffer, update
      ;; the filename
      (when (and fBufferNew (not (= returnCode -1)))
        (openfile-set-filename! (first *openfile-list*) fileName))

      ;; If we have a non-new file, read it in.  The, if the buffer has no
      ;; stat, update the stat, if applicable.
      (when (> returnCode 0)
        (ReadFile f returnCode fileName fUndoable fBufferNew))

      ;; If we're loading into a new buffer, update the colorto account
      ;; for it, if applicable
      ;; (UpdateColor)
      ])))

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
               (file-exists? filename)))
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
            (winio-statusbar (_ "Reading File"))
            0)
           (newfie
            (winio-statusbar (_ "New File"))
            -2)
           (else
            (winio-statusbar (format #f "\"~a\" not found" filename))
            (beep)
            -1))))

       ((member (stat:type fileinfo) '(directory block-special char-special))
        ;; Don't open directories, character files, or block files
        (if (eq? 'directory (stat:type fileinfo))
            (winio-statusbar (format #f "\"~a\" is a directory" filename))
            (winio-statusbar (format #f "\"~a\" is a device file" filename)))
        (beep)
        -1)

       (else
        ;; This looks like it *should* be openable.  Let's try.
        (let ((port (false-if-exception (open-file full_filename "r"))))
          (if (not port)
              (begin
                (winio-statusbar (format #f "Error reading ~a" filename))
                ;; FIXME: can I have a more detailed error message?
                (beep)
                -1)
              ;; else
              (begin
                (winio-statusbar (_ "Reading File"))
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
                                 (string<> "/" (string-take-right d_there 1)))
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
                                      (string<> "/" (string-take-right fullpath 1)))
                                 (string-append fullpath "/")
                                 fullpath)))
        (chdir d_here)
        (if path_only
            fullpath_slash
            (string-append fullpath_slash (basename d_there)))))

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
    (InitDirHome)
    (string-append vDirHome (string-drop buf 2)))

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
(define (DisplayBuffer)
  (winio-titlebar "")
  ;; Update the edit window
  (winio-edit-refresh))

(define (InitBackupDir)
  (if (not vDirBackup)
      #f
      (error "implement me!!!!!")))

(define (InitOperatingDir)
  "Initialize the full_operating_dir based on operating_dir"
  (if (not vDirOperating)
      #f
      (error "implement me!!!!!!")))

(define (CheckOperatingDir? path allow_tabcomp)
  #f)