## Process this file with automake to produce Makefile.in
## $Id: Makefile.am,v 1.7 2008/08/01 16:04:53 spike_gran Exp $

########### TESTBED ############
# The program testbed is a statically linked guile interpreter to use
# in debugging.  It does not get installed.

noinst_PROGRAMS = testbed

# -lguile gets included into LIBS by configure
#testbed_LDADD = -lguile

testbed_LDADD = @LIBNCURSES@ @LIBMENU@ @LIBPANEL@ @LIBFORM@
#testbed_LDADD = -lncursesw_g -lmenuw_g -lpanelw -lformw_g

testbed_CPPFLAGS = -Wextra -Wall -I../src/raw -static -u gucu_initscr -u initscr
testbed_LDFLAGS = -Bstatic

testbed_SOURCES = \
	testbed.c \
	../src/raw/curs_const.c \
	../src/raw/curs_func.c \
	../src/raw/curs_main.c  \
	../src/raw/curs_spec.c \
	../src/raw/type.c \
	../src/raw/menu_const.c \
	../src/raw/menu_func.c \
	../src/raw/menu_main.c \
	../src/raw/menu_spec.c \
	../src/raw/menu_type.c \
	../src/raw/eti_const.c \
	../src/raw/eti_main.c \
	../src/raw/panel_func.c \
	../src/raw/panel_main.c \
	../src/raw/panel_spec.c \
	../src/raw/panel_type.c \
	../src/raw/form_const.c \
	../src/raw/form_func.c \
	../src/raw/form_main.c \
	../src/raw/form_spec.c \
	../src/raw/form_type.c
#       ../src/raw/panel_const.c

if WIDE
testbed_SOURCES += \
	../src/raw/cursw_const.c \
	../src/raw/cursw_func.c \
	../src/raw/cursw_main.c \
	../src/raw/cursw_spec.c \
	../src/raw/typew.c
testbed_CPPFLAGS += -D_XOPEN_SOURCE_EXTENDED
endif

########### GUCUSHELL ############
# The program gucushell is a stub that opens an guile REPL whose
# ncurses commands will execute in an xterm.

bin_PROGRAMS = gucushell
EXTRA_DIST = keypress.scm

gucushell_LDADD = @LIBNCURSES@ -lutil
gucushell_CPPFLAGS = -Wextra -Wall 
gucushell_LDFLAGS =

gucushell_SOURCES = \
	shell.c

