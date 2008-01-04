## Process this file with automake to produce Makefile.in
## $Id: Makefile.am,v 1.8 2008/01/04 15:47:47 spike_gran Exp $

noinst_SCRIPTS = curs_wrap.sh cursw_wrap.sh

EXTRA_DIST = \
	const_def.awk const_head.awk const_init.awk const_scm.awk \
	func_def.awk func_head.awk func_init.awk func_scm.awk \
	special_scm.awk \
	curs_func.txt curs_const.txt curs_spec.txt \
	cursw_func.txt cursw_const.txt cursw_spec.txt

CLEANFILES = \
	curs_const.c curs_const.h curs_func.c curs_func.h \
	cursw_const.c cursw_const.h cursw_func.c cursw_func.h \
	curses-raw.scm.in curses-wide-raw.scm.in
