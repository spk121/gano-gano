## Process this file with automake to produce Makefile.in
## $Id: Makefile.am,v 1.7 2008/06/03 11:36:33 spike_gran Exp $

all-local:
	-ln -s ../src/raw @PACKAGE@


TESTS_ENVIRONMENT = LIBGUILE_GUCU_CURSES_MAJOR=@LIBGUILE_GUCU_CURSES_MAJOR@
TESTS_ENVIRONMENT += ../libtool -dlopen ../src/raw/libguile-gucu-curses-v-0.la --mode=execute \
	guile -L $(top_srcdir) -s 

TESTS = r000_test.test \
	r000_initscr.test \
	r001_color.test \
	r002_characters.test \
	r003_addch.test \
	r004_addchstr.test \
	r005_addstr.test \
	r006_attr.test \
	r007_beep.test \
	r008_bkgd.test \
	r009_border.test \
	r010_clear.test \
	r011_delch.test \
	r012_deleteln.test \
	r013_getch.test \
	r014_getstr.test \
	r015_getyx.test \
	r016_inch.test \
	r017_inchstr.test \
	r018_inopts.test \
	r019_insch.test \
	r020_insstr.test \
	r021_instr.test \
	r022_kernel.test \
	r023_move.test \
	r024_outputs.test \
	r025_overlay.test \
	r026_pad.test \
	r027_refresh.test \
	r028_scr_dump.test \
	r029_scroll.test \
	r030_termattrs.test \
	r031_touch.test \
	r032_util.test \
	f001_new_form.test

if WIDE
TESTS += \
	r033_add_wch.test \
	r034_add_wchstr.test \
	r035_addwstr.test \
	r036_bkgrnd.test \
	r037_border_set.test \
	r038_get_wch.test \
	r039_get_wstr.test 
endif


CLEANFILES = curses.log *.out

EXTRA_DIST = $(TESTS) \
	dotest-curses \
	lib.scm \
	lib2.scm 

