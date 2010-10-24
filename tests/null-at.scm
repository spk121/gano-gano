#!/bin/sh
# -*- scheme -*-
exec guile $GUILE_FLAGS -s "$0"
!#

(use-modules (gano utils))

(define str "abcdefghi")
(null-at str 3)
(exit (string=? str "abc"))

