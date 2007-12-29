## Process this file with automake to produce Makefile.in
## $Id: Makefile.am,v 1.4 2007/12/29 20:04:40 spike_gran Exp $

lib_LTLIBRARIES = libguile-gucu-v-@LIBGUILE_GUCU_MAJOR@.la

# -lguile and -lncursesw were added to LIBS by autoconf
# in the AC_CHECK_LIB test

AM_CPPFLAGS = \
	-D_XOPEN_SOURCE_EXTENDED

AM_LDFLAGS = \
	-no-undefined \
	-export-dynamic \
	-version-info @LIBGUILE_GUCU_INTERFACE@

libguile_gucu_v_@LIBGUILE_GUCU_MAJOR@_la_SOURCES = \
	constant.c constant.h \
	function.c function.h \
	type.c type.h \
	special.c special.h \
	raw.c

guile_sitedir = ${datadir}/guile/site
pkgguile_sitedir = $(guile_sitedir)/$(PACKAGE)
pkgguile_site_DATA = raw.scm 

ETAGS_ARGS = raw.scm
EXTRA_DIST = raw.scm.in
BUILT_SOURCES = raw.scm
CLEANFILES = raw.scm

raw.scm: raw.scm.in
	cat $< | \
	sed 's|XXlibnameXX|libguile-gucu-v-@LIBGUILE_GUCU_MAJOR@|' | \
	sed 's|XXpackageXX|$(PACKAGE)|' > $@

