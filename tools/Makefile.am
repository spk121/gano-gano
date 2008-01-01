noinst_PROGRAMS = testbed

# -lguile gets included into LIBS by configure
#testbed_LDADD = -lguile

AM_CPPFLAGS = -Wall
AM_LDFLAGS = -static

# not defining a testbed_SOURCES is the same as 
#testbed_SOURCES = testbed.c

EXTRA_DIST = run-testbed.sh.in
BUILT_SOURCES = run-testbed.sh
CLEANFILES = run-testbed.sh

run-testbed.sh: run-testbed.sh.in
	cat run-testbed.sh.in | \
	sed 's|XXXpackageXXX|@PACKAGE@|' | \
	sed 's|XXXmajorXXX|@LIBGUILE_GUCU_CURSES_MAJOR@|' > run-testbed.sh
	chmod +x run-testbed.sh
