AC_INIT([gucu], [0.0], [spk121@yahoo.com])
AC_CONFIG_AUX_DIR([build_aux])
dnl  Package info

dnl  Check for Programs
AC_PROG_CC
AC_PROG_INSTALL

dnl  Check for libraries
AC_CHECK_LIB([ncurses],	[initscr], ,[AC_MSG_ERROR([The ncurses library libncurses could not be found])])
AC_CHECK_LIB([guile], [scm_boot_guile], ,[AC_MSG_ERROR([The guile library libguile could not be found])])
GUILE_FLAGS

dnl  Check for header files
AC_CHECK_HEADERS([curses.h], , [AC_MSG_ERROR([The curses library header curses.h could not be found])])
AC_CHECK_HEADERS([libguile.h], , [AC_MSG_ERROR([The guile library header libguile.h could not be found])])

dnl  Check for types
AC_CHECK_SIZEOF([int])
AC_CHECK_SIZEOF([long])
AC_CHECK_SIZEOF([chtype], ,[#include <curses.h>])
AC_CHECK_SIZEOF([attr_t], ,[#include <curses.h>])

dnl  Check for structures

dnl  Check for compiler characteristics
AC_PROG_CC_C99

dnl  Check for library functions
AC_LIBTOOL_DLOPEN
AC_DISABLE_FAST_INSTALL
dnl AC_DISABLE_STATIC
AC_LIBTOOL_WIN32_DLL
AC_PROG_LIBTOOL

dnl  Check for system services

dnl  Output

AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([GNUmakefile])
AC_OUTPUT