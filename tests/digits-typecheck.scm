#!/bin/sh
# -*- scheme -*-
exec guile $GUILE_FLAGS -s "$0"
!#

(use-modules (gano utils))

(exit (and (not (false-if-exception (digits)))
	   (not (false-if-exception (digits "hi mom")))
	   (not (false-if-exception (digits -1)))))
