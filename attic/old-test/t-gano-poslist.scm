(use-modules (srfi srfi-64)
             (gano poslist))

(test-begin "t-gano-poslist")
(define T1 '())

(tag-set! T1 "a-1-1" 1 1)
(test-equal "can set a tag"
  #t (tag-name-at? T1 "a-1-1" 1 1))

(tag-set! T1 "a-2-2" 2 2)
(test-equal "can set another tag"
  #t (tag-name-at? T1 "a-2-2" 2 2))

;; Add tests to ensure that routines return copies of entries where
;; that is desired, and 'pointer's to entries when that is desired.

(test-end "t-gano-poslist")
