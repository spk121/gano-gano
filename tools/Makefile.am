noinst_PROGRAMS = testbed

# -lguile gets included into LIBS by configure
#testbed_LDADD = -lguile

testbed_LDADD =	@LIBNCURSES@
AM_CPPFLAGS = -Wall -I../src/raw -static -u gucu_initscr
AM_LDFLAGS = -Bstatic

# not defining a testbed_SOURCES is the same as 
#testbed_SOURCES = testbed.c
testbed_SOURCES = \
	testbed.c \
	../src/raw/curs_const.c \
	../src/raw/curs_func.c \
	../src/raw/curs_main.c  \
	../src/raw/curs_spec.c \
	../src/raw/type.c 

EXTRA_DIST = run-testbed.sh.in
BUILT_SOURCES = run-testbed.sh
CLEANFILES = run-testbed.sh

run-testbed.sh: run-testbed.sh.in
	cat run-testbed.sh.in | \
	sed 's|XXXpackageXXX|@PACKAGE@|' | \
	sed 's|XXXmajorXXX|@LIBGUILE_GUCU_CURSES_MAJOR@|' > run-testbed.sh
	chmod +x run-testbed.sh
