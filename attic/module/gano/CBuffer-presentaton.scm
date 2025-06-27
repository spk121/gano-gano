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

;; In this module we add two concepts: the presentation vs data
;; position and the page. Presentation position is figuring out
;; where each character in the CBuffer is located when rendered
;; on a terminal or printer page.

;; There are basically two modes to a page: 'wrapped' and 'unwrapped'.
;; In an unwrapped page, if a line is wider than the page, it is truncated.
;; In a wrapped page, if a line is wider than the page, it is wrapped.

;; There are a couple of wrapping modes: character break and word
;; break.  Word breaking using the Unicode word-breaking algorithm to
;; determine a break location.  Character breaking wraps after a grapheme.

;; A page has a width and height.  It has a home and end position.
;; It has operations to move the cursor.

;; When moving the presentation position, the width of each character
;; has to be taken into account.  Each character could be zero, one,
;; or two cells, or could jump to a tab stop. Latin characters occupy
;; one cell. Kanji occupy two.  When moving by cells in the frame,
;; this can be tricky.

;; Also, one could also deal with right-to-left and top-to-bottom
;; languages, for extra credit.



