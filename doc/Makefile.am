## Process this file with automake to produce Makefile.in
## $Id: Makefile.am,v 1.6 2009/01/10 23:05:37 spike_gran Exp $

# Cygwin's texi2dvi can try to call etex, resulting in this error:
#   "texinfo.tex appears to be broken, quitting"
# The problem lies in Cygwin's etex.fmt file
# Forcing TEX to tex works around this problem
# This should not harm other platforms
#TEX=tex
#TEXI2DVI = TEX=${TEX} texi2dvi


info_TEXINFOS = gucu.texi
gucu_TEXINFOS = panel_example1.scm \
	menu_example1.scm \
	menu_example2.scm \
	ex_attrib.scm \
	ex_centered_screen.scm \
	ex_hello_world.scm \
	ex_blink.scm \
	ex_getnstr.scm \
	ex_init_func_usage.scm
