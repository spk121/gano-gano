m4_include(`config.m4')
(define-module (gano chars)
  #:export (
           m4_ifdef({ENABLE_UTF8},{
           utf8_init
           })
           ))

m4_ifdef({ENABLE_UTF8},{

;; Whether we've enabled UTF-8 support
(define use_utf8 #f)
;; If we get an invalid multibyte sequence, we treat it as
;; Unicode FFFD (Replacement Character), unless we're searching
;; for a match to it
(define bad_wchar #xFFFD)
(define bad_mbchar "\xef\xbf\xbd")
(define bad_mbchar_len 3)

;; Enable UTF-8 support
(define (utf8_init)
  (set! use_utf8 #t))

;; Is UTF-8 support enabled?
(define (using_utf8)
  use_utf8)
})
