# Process this file with autoconf to produce a configure script

##################
# Package info
AC_PREREQ(2.61)
AC_INIT([gucu],[0.1],[spk121@yahoo.com])
AC_CONFIG_AUX_DIR([build_aux])
AM_INIT_AUTOMAKE([gnu std-options -Wall])
AC_CONFIG_SRCDIR([config.h.in])
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_MACRO_DIR([m4])

##################
# Set some version constants
LIBGUILE_GUCU_CURSES_MAJOR=0
LIBGUILE_GUCU_CURSES_INTERFACE="0:1:0"
AC_SUBST(LIBGUILE_GUCU_CURSES_MAJOR)
AC_SUBST(LIBGUILE_GUCU_CURSES_INTERFACE)

##################
# Check for Programs
AC_PROG_CC
AM_PROG_CC_C_O
AC_CANONICAL_HOST
AC_PROG_INSTALL
LT_INIT([dlopen disable-fast-install win32-dll])
AC_PROG_MKDIR_P
#GUILE_PROGS
#NCURSESW_PROGS


##################
# Initial guess of platform specific options
case $host in
*-*-cygwin)
	[with_ncursesw=no]
	[enable_acs_map_fix=yes] ;;
*-*-linux*)
	[with_ncursesw=yes]
	[enable_acs_map_fix=no] ;;
*)
	[with_ncursesw=yes]
	[enable_acs_map_fix=no] ;;
esac


##################
# Check for libraries

AC_ARG_ENABLE([ndebug],
              [AS_HELP_STRING([--enable-ndebug],
                              [use the debug version of the curses libraries (requires --disable-shared)])],
              # if option is selected
              [libncurses="ncurses_g"
	       libform="form_g"
	       libpanel="panel_g"
	       libmenu="menu_g"
	       libncursesw="ncursesw_g"
	       libformw="formw_g"
	       libpanelw="panelw_g"
	       libmenuw="menuw_g"],
              # if option is not selected
              [libncurses="ncurses"
	       libform="form"
	       libpanel="panel"
	       libmenu="menu"
	       libncursesw="ncursesw"
	       libformw="formw"
	       libpanelw="panelw"
	       libmenuw="menuw"])
	     
AC_ARG_WITH([ncursesw],
            [AS_HELP_STRING([--with-ncursesw],
                            [enable support for wide curses])])
LIBNCURSES=
AS_IF(
      # if
      [test "$with_ncursesw" = yes],
      # then
      [AC_CHECK_LIB([$libncursesw],	
                    [initscr],
		    # if ncursesw is ok
		    [AC_SUBST([LIBNCURSES], ["-l$libncursesw"])
		     AC_DEFINE([HAVE_LIBNCURSESW], 
                               [1],
                               [Define if you have libncursesw])
                    ],
		    # if ncursesw is not ok
                    [AC_MSG_WARN([Wide NCurses not found.  Trying standard curses.])
		     with_ncursesw=no])])

AS_IF(
      # if 
      [test "$with_ncursesw" = no],
      # then
      [AC_CHECK_LIB([$libncurses],	
                    [initscr],
		    # if ncurses is ok
		    [AC_SUBST([LIBNCURSES], ["-l$libncurses"])],
		    # if ncurses is not ok
                    [AC_MSG_ERROR([ncurses not found])])])

# When WIDE is defined, sub-makefiles should try to build the wide curses library
AM_CONDITIONAL([WIDE], [test "$with_ncursesw" = yes])

# The menu, panel, and form libraries should either use the wide or the narrow
# forms to match the version of the ncurses library being used.
LIBMENU=
AS_IF(
      # if
      [test "$with_ncursesw" = yes],
      # then
      [AC_CHECK_LIB([$libmenuw],	
                    [new_menu],
		    # if ncursesw is ok
		    [AC_SUBST([LIBMENU], ["-l$libmenuw"])],
		    # if ncursesw is not ok
                    [AC_MSG_ERROR([The wide ncurses menu library was not found.])])],
      # else
      [AC_CHECK_LIB([$libmenu],	
                    [new_menu],
		    # if ncursesw is ok
		    [AC_SUBST([LIBMENU], ["-l$libmenu"])],
		    # if ncursesw is not ok
                    [AC_MSG_ERROR([The ncurses menu library was not found.])])])

LIBFORM=
AS_IF(
      # if
      [test "$with_ncursesw" = yes],
      # then
      [AC_CHECK_LIB([$libformw],	
                    [new_form],
		    # if ncursesw is ok
		    [AC_SUBST([LIBFORM], ["-l$libformw"])],
		    # if ncursesw is not ok
                    [AC_MSG_ERROR([The wide ncurses form library was not found.])])],
      # else
      [AC_CHECK_LIB([$libform],	
                    [new_form],
		    # if ncursesw is ok
		    [AC_SUBST([LIBFORM], ["-l$libform"])],
		    # if ncursesw is not ok
                    [AC_MSG_ERROR([The ncurses form library was not found.])])])

LIBPANEL=
AS_IF(
      # if
      [test "$with_ncursesw" = yes],
      # then
      [AC_CHECK_LIB([$libpanelw],	
                    [new_panel],
		    # if ncursesw is ok
		    [AC_SUBST([LIBPANEL], ["-l$libpanelw"])],
		    # if ncursesw is not ok
                    [AC_MSG_ERROR([The wide ncurses panel library was not found.])])],
      # else
      [AC_CHECK_LIB([$libpanel],	
                    [new_panel],
		    # if ncursesw is ok
		    [AC_SUBST([LIBPANEL], ["-l$libpanel"])],
		    # if ncursesw is not ok
                    [AC_MSG_ERROR([The ncurses panel library was not found.])])])


#
# In Cygwin NCurses v5.5.20061104, there is a bug in the acs_map
# table declaration in <curses.h>.  This enables a workaround
#
AC_ARG_ENABLE([acs-map-fix],
              [AS_HELP_STRING([--enable-acs-map-fix],
                              [Work around acs_map bug in Cygwin NCurses v 5.5.20061104])])
AS_IF(
      # if 
      [test "$enable_acs_map_fix" = yes],
      # then
      [AC_DEFINE([ENABLE_ACS_MAP_FIX], 
                 [1],
                 [Define if you have to explicitly declare the curses acs_map])])

# Guile gets added to LIBS here
AC_CHECK_LIB([guile], 
             [scm_boot_guile], ,
             [AC_MSG_ERROR([The guile library was not found])])

AC_CHECK_FUNC([cfmakeraw],
              AC_DEFINE([HAVE_CFMAKERAW], 
                        [1],
                        [Define to 1 if you have cfmakeraw]))

##################
# Check for header files
AC_CHECK_HEADERS([wchar.h])
AC_CHECK_HEADERS([curses.h], , 
                 [AC_MSG_ERROR([<curses.h> was not found])])
AC_CHECK_HEADERS([menu.h], , 
                 [AC_MSG_ERROR([<menu.h> was not found])])
AC_CHECK_HEADERS([form.h], , 
                 [AC_MSG_ERROR([<form.h> was not found])])
AC_CHECK_HEADERS([panel.h], , 
                 [AC_MSG_ERROR([<panel.h> was not found])])
AC_CHECK_HEADERS([libguile.h], , 
                 [AC_MSG_ERROR([<libguile.h> was not found])])

##################
# Check for types, structures, compiler characteristics
AC_CHECK_SIZEOF([int])
AC_CHECK_SIZEOF([long])
AC_CHECK_SIZEOF([chtype], ,[#include <curses.h>])
AC_CHECK_SIZEOF([attr_t], ,[#include <curses.h>])
AC_CHECK_SIZEOF([wchar_t], ,[#include <stddef.h>])
AC_CHECK_SIZEOF([wint_t], ,[#include <wchar.h>])
AC_PROG_CC_C99

##################
# Check for library functions

# Later something should be done with this
# AC_FUNC_MALLOC

##################
# Check for system services

##################
#  Output
AC_CONFIG_FILES([Makefile 
                src/raw/Makefile 
                doc/Makefile 
                test/Makefile 
                wrap/Makefile 
                m4/Makefile 
                build_aux/Makefile 
                tools/Makefile])
AC_OUTPUT