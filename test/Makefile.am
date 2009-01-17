## Process this file with automake to produce Makefile.in
## $Id: Makefile.am,v 1.11 2009/01/17 23:06:24 spike_gran Exp $

all-local:
	-ln -s ../src/raw @PACKAGE@


TESTS_ENVIRONMENT = ../libtool -dlopen ../src/raw/libguile-gucu.la --mode=execute \
	guile -L $(top_srcdir) -L . -s 

NARROWTESTS = r000_test.test \
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
	r041_ports.test \
	r042_mouse.test \
	p001_panel.test \
	f001_new_form.test \
	f002_data.test \
	f003_field_attributes.test \
	f004_form_field.test \
	f005_form_page.test \
	f006_form_field_just.test \
	f007_form_field_opts.test \
	f008_form_field_buffer.test \
	m001_new_menu.test \
	m002_mitem_current.test \
	m003_mitem_name.test \
	m004_mitem_opts.test \
	m005_mitem_value.test \
	m006_mitem_visible.test \
	m007_menu_attributes.test \
	m008_menu_cursor.test \
	m009_menu_format.test \
	m010_menu_mark.test \
	m011_menu_options.test


WIDETESTS = \
	r033_add_wch.test \
	r034_add_wchstr.test \
	r035_addwstr.test \
	r036_bkgrnd.test \
	r037_border_set.test \
	r038_get_wch.test \
	r039_get_wstr.test \
	r040_term_attrs.test

TESTS = $(NARROWTESTS)
if WIDE
TESTS += $(WIDETESTS)
endif


CLEANFILES = curses.log *.out

EXTRA_DIST = $(NARROWTESTS) \
	$(WIDETESTS) \
	dotest-curses \
	lib.scm \
	lib2.scm \
	gc000_window.test

