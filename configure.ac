# Process this file with autoconf to produce a configure script

# Package info
AC_INIT([gucu], [0.0], [spk121@yahoo.com])
AC_CONFIG_AUX_DIR([build_aux])
AM_INIT_AUTOMAKE([gnu std-options -Wall])
AC_CONFIG_SRCDIR([config.h.in])
AC_CONFIG_HEADERS([config.h])

# Set some version constants
LIBGUILE_GUCU_MAJOR=0
LIBGUILE_GUCU_INTERFACE="0:0:0"
AC_SUBST(LIBGUILE_GUCU_MAJOR)
AC_SUBST(LIBGUILE_GUCU_INTERFACE)

# Check for Programs
AC_PROG_CC
AC_PROG_INSTALL
AC_LIBTOOL_DLOPEN
AC_DISABLE_FAST_INSTALL
AC_PROG_LIBTOOL
AC_PROG_MKDIR_P
GUILE_PROGS
NCURSESW_PROGS

# Check for libraries
#AC_CHECK_LIB([curses],	[initscr], ,[AC_MSG_ERROR([The ncurses library libncurses could not be found])])
#AC_CHECK_LIB([guile], [scm_boot_guile], ,[AC_MSG_ERROR([The guile library libguile could not be found])])

# Check for header files
#AC_CHECK_HEADERS([curses.h], , [AC_MSG_ERROR([The curses library header curses.h could not be found])])
#AC_CHECK_HEADERS([libguile.h], , [AC_MSG_ERROR([The guile library header libguile.h could not be found])])
GUILE_FLAGS
GUILE_SITE_DIR
NCURSESW_FLAGS

# Check for types, structures, compiler characteristics
AC_CHECK_SIZEOF([int])
AC_CHECK_SIZEOF([long])
AC_CHECK_SIZEOF([chtype], ,[#include <curses.h>])
AC_CHECK_SIZEOF([attr_t], ,[#include <curses.h>])
AC_PROG_CC_C99

# Check for library functions

# Check for system services

#  Output
AC_CONFIG_FILES([Makefile src/raw/Makefile doc/Makefile test/Makefile wrap/Makefile m4/Makefile build_aux/Makefile])
AC_OUTPUT