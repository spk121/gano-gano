## Process this file with automake to produce Makefile.in
## $Id: Makefile.am,v 1.15 2008/12/11 06:49:44 spike_gran Exp $

# COMPILE_FLAGS = -Wall -W -Wunused-parameter -Wstrict-prototypes \
# 	-Wmissing-prototypes -Wpointer-arith \
# 	-Wreturn-type -Wcast-qual -Wswitch -Wshadow -Wcast-align \
# 	-Wwrite-strings -Wchar-subscripts -Winline -Wnested-externs -Wredundant-decls

COMPILE_FLAGS = -Wall 

lib_LTLIBRARIES = \
	libguile-gucu-curses-v-@LIBGUILE_GUCU_CURSES_MAJOR@.la

### CURSES ###

libguile_gucu_curses_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_CPPFLAGS = $(COMPILE_FLAGS)

libguile_gucu_curses_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_LDFLAGS = \
	-no-undefined \
	-export-dynamic \
	-version-info @LIBGUILE_GUCU_CURSES_INTERFACE@

libguile_gucu_curses_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_SOURCES = \
	curs_const.c curs_const.h \
	curs_func.c curs_func.h \
	curs_port.c curs_port.h \
	type.c type.h \
	curs_spec.c curs_spec.h \
	curs_main.c \
	menu_const.c menu_const.h \
	menu_func.c menu_func.h \
	menu_type.c menu_type.h \
	menu_spec.c menu_spec.h \
	menu_main.c \
	panel_func.c panel_func.h \
	panel_type.c panel_type.h \
	panel_spec.c panel_spec.h \
	panel_main.c \
	form_const.c form_const.h \
	form_func.c form_func.h \
	form_type.c form_type.h \
	form_spec.c form_spec.h \
	form_main.c \
	eti_const.c eti_const.h \
	eti_main.c \
	slk_func.c slk_func.h



# -lguile added to LIBS by autoconf in the AC_CHECK_LIB test
libguile_gucu_curses_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_LIBADD = \
	@LIBMENU@ @LIBPANEL@ @LIBFORM@ @LIBNCURSES@ 

### WIDE CURSES ###

if WIDE
libguile_gucu_curses_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_CPPFLAGS += -D_XOPEN_SOURCE_EXTENDED

libguile_gucu_curses_v_@LIBGUILE_GUCU_CURSES_MAJOR@_la_SOURCES += \
	cursw_const.c cursw_const.h \
	cursw_func.c cursw_func.h \
	typew.c typew.h \
	cursw_spec.c cursw_spec.h \
	cursw_main.c
endif

######

guile_sitedir = ${datadir}/guile/site
pkgguile_sitedir = $(guile_sitedir)/$(PACKAGE)
pkgguile_site_DATA = curses.scm curses-alt.scm menu.scm panel.scm form.scm eti.scm
ETAGS_ARGS = curses.scm curses-alt.scm menu.scm panel.scm form.scm eti.scm


# Note that the "wide" .scm.in file needs to appear in EXTRA_DIST.  It
# is part of the distribution regardless of whether it is used.
EXTRA_DIST = \
	curses.scm.in curses-wide.scm.in \
	menu.scm.in panel.scm.in form.scm.in eti.scm.in \
	slk.scm.in \
	curses-alt.scm curses-wide-alt.scm

BUILT_SOURCES = curses.scm menu.scm panel.scm form.scm eti.scm slk.scm
CLEANFILES = curses.scm menu.scm panel.scm form.scm eti.scm slk.scm

curses.scm: curses.scm.in
	cat $< | \
	sed 's|XXlibnameXX|libguile-gucu-curses-v-@LIBGUILE_GUCU_CURSES_MAJOR@|' | \
	sed 's|XXpackageXX|$(PACKAGE)|' > $@

menu.scm: menu.scm.in
	cat $< | \
	sed 's|XXlibnameXX|libguile-gucu-curses-v-@LIBGUILE_GUCU_CURSES_MAJOR@|' | \
	sed 's|XXpackageXX|$(PACKAGE)|' > $@

panel.scm: panel.scm.in
	cat $< | \
	sed 's|XXlibnameXX|libguile-gucu-curses-v-@LIBGUILE_GUCU_CURSES_MAJOR@|' | \
	sed 's|XXpackageXX|$(PACKAGE)|' > $@

form.scm: form.scm.in
	cat $< | \
	sed 's|XXlibnameXX|libguile-gucu-curses-v-@LIBGUILE_GUCU_CURSES_MAJOR@|' | \
	sed 's|XXpackageXX|$(PACKAGE)|' > $@

eti.scm: eti.scm.in
	cat $< | \
	sed 's|XXlibnameXX|libguile-gucu-curses-v-@LIBGUILE_GUCU_CURSES_MAJOR@|' | \
	sed 's|XXpackageXX|$(PACKAGE)|' > $@

slk.scm: slk.scm.in
	cat $< | \
	sed 's|XXlibnameXX|libguile-gucu-curses-v-@LIBGUILE_GUCU_CURSES_MAJOR@|' | \
	sed 's|XXpackageXX|$(PACKAGE)|' > $@


if WIDE
pkgguile_site_DATA += curses-wide.scm curses-wide-alt.scm
ETAGS_ARGS += curses-wide.scm curses-wide-alt.scm
BUILT_SOURCES += curses-wide.scm
CLEANFILES += curses-wide.scm

curses-wide.scm: curses-wide.scm.in
	cat $< | \
	sed 's|XXlibnameXX|libguile-gucu-curses-v-@LIBGUILE_GUCU_CURSES_MAJOR@|' | \
	sed 's|XXpackageXX|$(PACKAGE)|' > $@
endif