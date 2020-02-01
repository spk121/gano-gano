;;; Gano - a simple console text editor     -*- mode: scheme; -*-
(setlocale LC_ALL "")
(use-modules (srfi srfi-1)
             (srfi srfi-34)
             (srfi srfi-35)
             (rnrs control)
             (ice-9 format)
             (ice-9 getopt-long)
             (ice-9 rdelim)
             (ncurses curses)
             (ncurses extra)

             )




(include "src/log.scm")
(log-debug "START OF PROGRAM")

(include "src/nano-h.scm")

(include "src/cbuf.scm")
(include "src/char.scm")
(include "src/dispatch.scm")
(include "src/files.scm")
(include "src/flags.scm")
(include "src/frame.scm")
(include "src/function.scm")
(include "src/global.scm")
(include "src/help.scm")
(include "src/input.scm")
(include "src/prompt.scm")
(include "src/shortcut.scm")
(include "src/string.scm")
(include "src/utils.scm")
(include "src/wcwidth.scm")
(include "src/winio.scm")

(include "src/gano.scm")
(include "src/s-main.scm")
(include "src/s-edit.scm")

;;; Let's get this party started.
(main (command-line))
(log-debug "END OF PROGRAM")
