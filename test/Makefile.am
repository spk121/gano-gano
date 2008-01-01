## Process this file with automake to produce Makefile.in
## $Id: Makefile.am,v 1.4 2008/01/01 16:03:09 spike_gran Exp $


testlist_curses = \
$(srcdir)/r000_initscr.test \
$(srcdir)/r001_color.test \
$(srcdir)/r002_characters.test \
$(srcdir)/r003_addch.test \
$(srcdir)/r004_addchstr.test \
$(srcdir)/r005_addstr.test \
$(srcdir)/r006_attr.test \
$(srcdir)/r007_beep.test \
$(srcdir)/r008_bkgd.test \
$(srcdir)/r009_border.test \
$(srcdir)/r010_clear.test \
$(srcdir)/r011_delch.test \
$(srcdir)/r012_deleteln.test \
$(srcdir)/r013_getch.test \
$(srcdir)/r014_getstr.test \
$(srcdir)/r015_getyx.test \
$(srcdir)/r016_inch.test \
$(srcdir)/r017_inchstr.test \
$(srcdir)/r018_inopts.test \
$(srcdir)/r019_insch.test \
$(srcdir)/r020_insstr.test \
$(srcdir)/r021_instr.test \
$(srcdir)/r022_kernel.test \
$(srcdir)/r023_move.test \
$(srcdir)/r024_outputs.test \
$(srcdir)/r025_overlay.test \
$(srcdir)/r026_pad.test \
$(srcdir)/r027_refresh.test \
$(srcdir)/r028_scr_dump.test \
$(srcdir)/r029_scroll.test \
$(srcdir)/r030_termattrs.test \
$(srcdir)/r031_touch.test \
$(srcdir)/r032_util.test \
$(srcdir)/r999-endwin.test 
if WIDE
  testlist_curses_wide = \
$(srcdir)/r000_initscr.test \
$(srcdir)/r033_add_wch.test \
$(srcdir)/r034_add_wchstr.test \
$(srcdir)/r035_addwstr.test \
$(srcdir)/r036_bkgrnd.test \
$(srcdir)/r037_border_set.test \
$(srcdir)/r038_get_wch.test \
$(srcdir)/r039_get_wstr.test \
$(srcdir)/r999-endwin.test
endif

TESTS_ENVIRONMENT = \
	libtool -dlopen ../src/raw/libguile-gucu-curses-v-${LIBGUILE_GUCU_CURSES_MAJOR}.la \
	--mode=execute guile -s

TESTS = curs000-initscr.scm \
	cursw000-add-wch.scm

# TESTS_ENVIRONMENT = LIBGUILE_GUCU_CURSES_MAJOR=@LIBGUILE_GUCU_CURSES_MAJOR@
# TESTS_ENVIRONMENT += PACKAGE=@PACKAGE@
# TESTS_ENVIRONMENT += TESTLIST_CURSES=$(testlist_curses)
# if WIDE
#   TESTS_ENVIRONMENT += TESTLIST_CURSES_WIDE=$(testlist_curses_wide)
# endif

# TESTS = dotest-curses 
# if WIDE
#   TESTS += dotest-curses-wide
# endif

#check_SCRIPTS = guile-test

CLEANFILES = guile.log

EXTRA_DIST = \
	dotest-curses \
	dotest-curses-wide \
	guile-test \
	lib.scm \
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
	r033_add_wch.test \
	r034_add_wchstr.test \
	r035_addwstr.test \
	r036_bkgrnd.test \
	r037_border_set.test \
	r038_get_wch.test \
	r039_get_wstr.test \
	r999-endwin.test 

