## Process this file with automake to produce Makefile.in
## $Id: Makefile.am,v 1.6 2008/01/04 08:07:00 spike_gran Exp $

lib_LTLIBRARIES = \
	libguile-gucu-curses-v-@LIBGUILE_GUCU_CURSES_MAJOR@.la 

if WIDE
  lib_LTLIBRARIES += \
	libguile-gucu-curses-wide-v-@LIBGUILE_GUCU_CURSES_WIDE_MAJOR@.la 
endif

libguile_gucu_curses_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_CPPFLAGS = -Wall

if CYGWIN_CURSES_BUG_FIX
libguile_gucu_curses_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_CPPFLAGS += \
	-DCYGWIN_CURSES_BUG_FIX
endif

libguile_gucu_curses_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_LDFLAGS = \
	-no-undefined \
	-export-dynamic \
	-version-info @LIBGUILE_GUCU_CURSES_INTERFACE@

libguile_gucu_curses_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_SOURCES = \
	curs_const.c curs_const.h \
	curs_func.c curs_func.h \
	type.c type.h \
	curs_spec.c curs_spec.h \
	curs_main.c

# -lguile added to LIBS by autoconf in the AC_CHECK_LIB test
libguile_gucu_curses_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_LIBADD = @LIBNCURSES@

if WIDE
libguile_gucu_curses_wide_v_@LIBGUILE_GUCU_CURSES_WIDE_MAJOR@_la_CPPFLAGS = \
	-D_XOPEN_SOURCE_EXTENDED -Wall -Werror

libguile_gucu_curses_wide_v_@LIBGUILE_GUCU_CURSES_WIDE_MAJOR@_la_LDFLAGS = \
	-no-undefined \
	-export-dynamic \
	-version-info @LIBGUILE_GUCU_CURSES_WIDE_INTERFACE@

libguile_gucu_curses_wide_v_@LIBGUILE_GUCU_CURSES_WIDE_MAJOR@_la_SOURCES = \
	cursw_const.c cursw_const.h \
	cursw_func.c cursw_func.h \
	type.c type.h \
	typew.c typew.h \
	cursw_spec.c cursw_spec.h \
	cursw_main.c

# -lguile added to LIBS by autoconf in the AC_CHECK_LIB test
libguile_gucu_curses_wide_v_@LIBGUILE_GUCU_CURSES_WIDE_MAJOR@_la_LIBADD = \
	@LIBNCURSES@
endif

guile_sitedir = ${datadir}/guile/site
pkgguile_sitedir = $(guile_sitedir)/$(PACKAGE)
pkgguile_site_DATA = curses-raw.scm
ETAGS_ARGS = curses-raw.scm

# Note that the "wide" .scm.in file needs to appear here.  It is part of
# the distribution regardless of whether it is used.
EXTRA_DIST = curses-raw.scm.in curses-wide-raw.scm.in

BUILT_SOURCES = curses-raw.scm
CLEANFILES = curses-raw.scm

curses-raw.scm: curses-raw.scm.in
	cat $< | \
	sed 's|XXlibnameXX|libguile-gucu-curses-v-@LIBGUILE_GUCU_CURSES_MAJOR@|' | \
	sed 's|XXpackageXX|$(PACKAGE)|' > $@

if WIDE
pkgguile_site_DATA += curses-wide-raw.scm 
ETAGS_ARGS += curses-wide-raw.scm
BUILT_SOURCES += curses-wide-raw.scm
CLEANFILES += curses-wide-raw.scm

curses-wide-raw.scm: curses-wide-raw.scm.in
	cat $< | \
	sed 's|XXlibnameXX|libguile-gucu-curses-wide-v-@LIBGUILE_GUCU_CURSES_WIDE_MAJOR@|' | \
	sed 's|XXpackageXX|$(PACKAGE)|' > $@
endif