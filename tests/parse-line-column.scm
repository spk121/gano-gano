#!/bin/sh
# -*- scheme -*-
exec guile $GUILE_FLAGS -s "$0"
!#

(use-modules (gano utils))

(define x #f)
(define y #f)
(exit (and (parse-line-column "1,2" x y)
	   (= x 1)
	   (= y 2)
	   (not (parse-line-column "abc" x y))
	   (= x 1)
	   (= y 2)))

