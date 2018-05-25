(define-module (gano CBuffer-base)
  #:use-module (oop goops)
  #:use-module (oop goops describe)
  #:use-module (ice-9 receive)
  #:use-module (ice-9 rdelim)
  #:use-module (srfi srfi-1)
  #:use-module (rnrs control)
  #:use-module ((ncurses extra) #:select (wcwidth))
  ;; #:use-module (gano debug)
  #:use-module (gano stringlist)
  #:use-module (gano poslist)
  #:use-module (gano position)
  #:use-module (mlg typechecking)
  #:use-module (mlg math)
  #:use-module (mlg logging)
  #:use-module (mlg lists)
  #:use-module (mlg strings)
  #:export ())

;; In this module we as the concept of a rendering frame to a CBuffer.
;; A frame is a rectangular region that displays a subset of the
;; characters in a CBuffer.  A default frame might be 25 lines by 80
;; columns.

;; A rendering frame has a starting row and column, a width, and a
;; height.

