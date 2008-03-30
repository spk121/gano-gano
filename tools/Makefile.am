noinst_PROGRAMS = testbed
bin_PROGRAMS = gucushell

# -lguile gets included into LIBS by configure
#testbed_LDADD = -lguile

testbed_LDADD =	@LIBNCURSES@
testbed_CPPFLAGS = -Wextra -Wall -I../src/raw -static -u gucu_initscr
testbed_LDFLAGS = -Bstatic

testbed_SOURCES = \
	testbed.c \
	../src/raw/curs_const.c \
	../src/raw/curs_func.c \
	../src/raw/curs_main.c  \
	../src/raw/curs_spec.c \
	../src/raw/type.c 

gucushell_LDADD = @LIBNCURSES@ -lutil
gucushell_CPPFLAGS = -Wextra -Wall 
gucushell_LDFLAGS =

gucushell_SOURCES = \
	shell.c

