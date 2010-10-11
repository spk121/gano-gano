m4_include(`config.m4')
(define-module (gano chars)
  #:use-module (gano nano-h)
  #:use-module (ncurses extra)
  #:export (
           m4_ifdef({ENABLE_UTF8},{
           utf8_init
           mb_cur_max
           char-width
           })
           ))

(define (mb_cur_max)
  (error "mb_cur_max has no meaning in Gano.  use '1' instead"))

(define (parse_mbchar a b c)
  (error "parse_mbchar has no meaning. Use char-width instead"))

m4_ifdef({ENABLE_UTF8},{

;; Whether we've enabled UTF-8 support.  In Gano (and not in Nano)
;; if this is true, we assume Guile 2.0.x and UCS-4 chars.  If this
;; is false, we assume Guile 1.8.x and 8-bit locale chars.  Otherwise,
;; we don't do any of the mbchar processing.
(define use_utf8 #f)

;; If we get an invalid multibyte sequence, we treat it as
;; Unicode FFFD (Replacement Character), unless we're searching
;; for a match to it
(define bad_wchar #xFFFD)

;; Enable UTF-8 support
(define (utf8_init)
  (set! use_utf8 #t))

;; Is UTF-8 support enabled?
(define (using_utf8)
  use_utf8)
})

;; Return #t if a character is blank
m4_ifdef({HAVE_ISBLANK},{},{
(define (nisblank c)
  (char-set-contains? char-set:blank c))
})

m4_ifdef({HAVE_ISWBLANK},{},{
m4_ifdef({ENABLE_UTF8},{
(define (niswblank c)
  (char-set-contains? char-set:blank c))
})
})

;; Return #t if c is in byte range.
(define (is_byte c)
  (< (char->number c) 256))

;; Return #t for the C0 ASCII control characters
(define (is_ascii_cntrl_char c)
  (let ((n (char->integer c)))
    (and (<= 0 n) (< n 32))))

;; Return #t for all control 8-bit characters
(define (is_cntrl_char c)
  (char-set-contains? char-set:iso-control c))

m4_ifdef({ENABLE_UTF8},{
(define (is_cntrl_wchar wc)
  (char-set-contains? char-set:iso-control c))
})

;; c is a control character.  It displays as ^@, ^?, or ^[ch] where
;; ch is c + 64.
(define (control_rep c)
  ;; Treat newlines embedded in a line as encoded nulls
  (cond
   ((eq? c #\newline)
    #\@)
   ((eq? c #\delete)
    (#\?))
   (else
    (integer->char (+ (char->integer c) 64)))))

m4_ifdef({ENABLE_UTF8},{
(define (control_wrep c)
  (control_rep c))
})

;; Return #t if BUF contains characters or #f if it is empty.
;; Sets CHR to the first character in BUF.  Increments COL
;; by the number of cells that the character would take up
;; on the terminal.

;; Given a character CHR and the current column COL, this procedure
;; returns the number of cells that this character will take up.
;; This is usually 1, but, can be more for wide characters, kanji, 
;; tabs, etc.
(define (char-width chr col)
  (cond
   ((eq? chr #\nul)
    0)
   ((eq? chr #\tab)
    (+ tabsize (- (modulo col tabsize))))
   ((is_cntrl_char chr)
    (+ 1 (control_mbrep chr)))
   (else
    (wcwidth chr))))
