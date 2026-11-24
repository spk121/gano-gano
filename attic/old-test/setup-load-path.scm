;; Puts the current directory in the load path

(let* ((bindir (dirname (car (command-line))))
       (absdir (cond ((string=? bindir ".")
                      (getcwd))
                     ((string-match "^/" bindir)
                      bindir)
                     (else
                      (in-vicinity (getcwd) bindir)))))
  (set! %load-path (cons (in-vicinity absdir "..")
                         %load-path)))

;; Debug output for which files are being loaded
(set! %load-hook (lambda (filename)
                   (format #t "Loading ~a \n" filename)))
