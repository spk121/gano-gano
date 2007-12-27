# ncurses.m4 - Configure ncursesw for linking against gucu. -*-Autoconf-*-

#serial 1 


# Macros for the NCURSESW library

# NCURSESW_PROGS -- set paths to NCURSESW config and tool programs
#
# Usage: NCURSESW_PROGS
#
# This macro looks for program ncursesw5-config, and set NCURSESW_CONFIG.
# Error if not found

# The variables are marked for substitution, as by AC_SUBST.
#
AC_DEFUN([NCURSESW_PROGS],
 [AC_PATH_PROG(NCURSESW_CONFIG,ncursesw5-config)
  if test "$NCURSESW_CONFIG" = "" ; then
      AC_MSG_ERROR([ncursesw5-config from ncurses required but not found.])
  fi
  AC_SUBST(NCURSESW_CONFIG)
 ])

# NCURSESW_FLAGS -- set flags for compiling and linking with NCURSESW
#
# Usage: NCURSESW_FLAGS
#
# This macro runs the ncursesw-config script, installed with NCURSESW, to find
# out where NCURSESW's header files and libraries are installed.  It sets
# two variables, NCURSESW_CFLAGS and NCURSESW_LDFLAGS.
#
# NCURSESW_CFLAGS: flags to pass to a C or C++ compiler to build code that
# uses NCURSESW header files.  This will include a -I flag.
#
# NCURSESW_LDFLAGS: flags to pass to the linker to link a program against
# NCURSESW.  This includes -lncurseswi18n for the NCURSESW library itself, any other
# libraries that NCURSESW itself requires (like -lpthread), and so on.  It
# may also include a -L flag to tell the compiler where to find the
# libraries.
#
# The variables are marked for substitution, as by @code{AC_SUBST}.
#
AC_DEFUN([NCURSESW_FLAGS],
 [AC_REQUIRE([NCURSESW_PROGS])dnl
  AC_MSG_CHECKING([ncursesw compile flags])
  NCURSESW_CFLAGS="`$NCURSESW_CONFIG --cflags`"
  AC_MSG_RESULT([$NCURSESW_CFLAGS])
  AC_MSG_CHECKING([ncursesw link flags])
  NCURSESW_LDFLAGS="`$NCURSESW_CONFIG --libs`"
  AC_MSG_RESULT([$NCURSESW_LDFLAGS])
  AC_SUBST(NCURSESW_CFLAGS)
  AC_SUBST(NCURSESW_LDFLAGS)
 ])


