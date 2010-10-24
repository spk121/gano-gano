#!/bin/sh
# -*- scheme -*-
exec guile $GUILE_FLAGS -s "$0"
!#

(use-modules (gano utils))

(exit (and (= 1 (digits 0))
	   (= 1 (digits 1))
	   (= 1 (digits 9))
	   (= 2 (digits 10))
	   (= 2 (digits 99))
	   (= 3 (digits 100))))
