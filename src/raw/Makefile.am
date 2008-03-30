## Process this file with automake to produce Makefile.in
## $Id: Makefile.am,v 1.10 2008/03/30 16:56:01 spike_gran Exp $

lib_LTLIBRARIES = \
	libguile-gucu-curses-v-@LIBGUILE_GUCU_CURSES_MAJOR@.la \
	libguile-gucu-menu-v-@LIBGUILE_GUCU_CURSES_MAJOR@.la \
	libguile-gucu-panel-v-@LIBGUILE_GUCU_CURSES_MAJOR@.la

if WIDE
lib_LTLIBRARIES += \
	libguile-gucu-curses-wide-v-@LIBGUILE_GUCU_CURSES_WIDE_MAJOR@.la 
endif

### CURSES ###

libguile_gucu_curses_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_CPPFLAGS = -Wall

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

### MENU ###

libguile_gucu_menu_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_CPPFLAGS = -Wall

libguile_gucu_menu_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_LDFLAGS = \
	-no-undefined \
	-export-dynamic \
	-version-info @LIBGUILE_GUCU_CURSES_INTERFACE@

libguile_gucu_menu_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_SOURCES = \
	menu_const.c menu_const.h \
	menu_func.c menu_func.h \
	type.c type.h \
	menu_type.c menu_type.h \
	menu_spec.c menu_spec.h \
	menu_main.c

# -lguile added to LIBS by autoconf in the AC_CHECK_LIB test
libguile_gucu_menu_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_LIBADD = @LIBNCURSES@

### PANEL ###

libguile_gucu_panel_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_CPPFLAGS = -Wall

libguile_gucu_panel_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_LDFLAGS = \
	-no-undefined \
	-export-dynamic \
	-version-info @LIBGUILE_GUCU_CURSES_INTERFACE@

libguile_gucu_panel_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_SOURCES = \
	panel_func.c panel_func.h \
	type.c type.h \
	panel_type.c panel_type.h \
	panel_spec.c panel_spec.h \
	panel_main.c

# -lguile added to LIBS by autoconf in the AC_CHECK_LIB test
libguile_gucu_panel_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_LIBADD = @LIBNCURSES@

### WIDE CURSES ###

if WIDE
libguile_gucu_curses_wide_v_@LIBGUILE_GUCU_CURSES_WIDE_MAJOR@_la_CPPFLAGS = \
	-D_XOPEN_SOURCE_EXTENDED -Wall 

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

######

guile_sitedir = ${datadir}/guile/site
pkgguile_sitedir = $(guile_sitedir)/$(PACKAGE)
pkgguile_site_DATA = curses.scm curses-alt.scm menu.scm panel.scm
ETAGS_ARGS = curses.scm curses-alt.scm menu.scm panel.scm


# Note that the "wide" .scm.in file needs to appear here.  It is part of
# the distribution regardless of whether it is used.
EXTRA_DIST = \
	curses.scm.in curses-wide.scm.in \
	curses-alt.scm curses-wide-alt.scm

BUILT_SOURCES = curses.scm menu.scm panel.scm
CLEANFILES = curses.scm menu.scm panel.scm

curses.scm: curses.scm.in
	cat $< | \
	sed 's|XXlibnameXX|libguile-gucu-curses-v-@LIBGUILE_GUCU_CURSES_MAJOR@|' | \
	sed 's|XXpackageXX|$(PACKAGE)|' > $@

menu.scm: menu.scm.in
	cat $< | \
	sed 's|XXlibnameXX|libguile-gucu-menu-v-@LIBGUILE_GUCU_CURSES_MAJOR@|' | \
	sed 's|XXpackageXX|$(PACKAGE)|' > $@

panel.scm: panel.scm.in
	cat $< | \
	sed 's|XXlibnameXX|libguile-gucu-panel-v-@LIBGUILE_GUCU_CURSES_MAJOR@|' | \
	sed 's|XXpackageXX|$(PACKAGE)|' > $@


if WIDE
pkgguile_site_DATA += curses-wide.scm curses-wide-alt.scm
ETAGS_ARGS += curses-wide.scm curses-wide-alt.scm
BUILT_SOURCES += curses-wide.scm
CLEANFILES += curses-wide.scm

curses-wide.scm: curses-wide.scm.in
	cat $< | \
	sed 's|XXlibnameXX|libguile-gucu-curses-wide-v-@LIBGUILE_GUCU_CURSES_WIDE_MAJOR@|' | \
	sed 's|XXpackageXX|$(PACKAGE)|' > $@
endif