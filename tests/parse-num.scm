#!/bin/sh
# -*- scheme -*-
exec guile $GUILE_FLAGS -s "$0"
!#

(use-modules (gano utils))

(define x #f)
(exit (and (parse-num "10" x)
	   (= x 10)
	   (not (parse-num "abc" x))
	   (= x 10)))

