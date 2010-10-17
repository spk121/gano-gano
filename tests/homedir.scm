;; -*- scheme -*-

(use-modules (gano utils))
(get_homedir)
(exit (if (@@ (gano global) homedir) #t #f))

