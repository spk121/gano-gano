#!/bin/bash
export GUILE_LOAD_PATH=.:$GUILE_LOAD_PATH

exec guile --debug -c "(use-modules (gano)) (Main (command-line))" 2> out2.txt

;; (use-modules (gano))

;; (Main (command-line))
