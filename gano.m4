m4_dnl gano.m4 -- the top-level script assembly for the Gano editor
m4_dnl
m4_dnl This m4 file includes all of the source code files into
m4_dnl a single flat file.  It also selectively includes some files
m4_dnl based on the platform.
m4_dnl
m4_changecom(`;')m4_dnl
m4_changequote(`{', `}')m4_dnl
;;; Gano - a simple console text editor     -*- mode: scheme; -*-
(setlocale LC_ALL "")
(use-modules (srfi srfi-1)
	     (srfi srfi-34)
	     (srfi srfi-35)
             (rnrs control)
             (ice-9 getopt-long)
             (ncurses curses)
	     (ncurses extra))
m4_define({_m4_inline},
{m4_dnl
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; START OF $1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
m4_include($1)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; END OF $1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
})

m4_define({_m4_insert_file},
{m4_ifdef({__INLINE__}, 
  {_m4_inline({$1})}, 
  {(include "$1")})})

_m4_insert_file({src/log.scm})
(log-debug "START OF PROGRAM")

_m4_insert_file({src/nano-h.scm})

_m4_insert_file({src/cbuf.scm})
_m4_insert_file({src/char.scm})
_m4_insert_file({src/dispatch.scm})
_m4_insert_file({src/files.scm})
_m4_insert_file({src/flags.scm})
_m4_insert_file({src/frame.scm})
_m4_insert_file({src/function.scm})
_m4_insert_file({src/global.scm})
_m4_insert_file({src/input.scm})
_m4_insert_file({src/shortcut.scm})
_m4_insert_file({src/string.scm})
_m4_insert_file({src/utils.scm})
_m4_insert_file({src/wcwidth.scm})
_m4_insert_file({src/winio.scm})

_m4_insert_file({src/gano.scm})

m4_ifdef({__EXTRA__},{_m4_insert_file(__EXTRA__)})
m4_ifdef({__TEST__},
{_m4_insert_file({test/srfi-64.scm})
_m4_insert_file(__TEST__)},
{;;; Let's get this party started.
(main (command-line))
(log-debug "END OF PROGRAM")
})