#!/bin/sh
# -*- scheme -*-
exec guile $GUILE_FLAGS -s "$0"
!#

(use-modules (gano utils))

(define str1 "abcd\x00efgh")
(unsunder str1 (string-length str1))
(exit (string=? str1 "abcd\nefgh"))

