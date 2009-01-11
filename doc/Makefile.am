## Process this file with automake to produce Makefile.in
## $Id: Makefile.am,v 1.7 2009/01/11 03:20:05 spike_gran Exp $

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
	ex_blink.scm \
	ex_centered_screen.scm \
	ex_color.scm \
	ex_getnstr.scm \
	ex_hello_world.scm \
	ex_hline.scm \
	ex_init_func_usage.scm \
	ex_menu.scm \
	ex_menu2.scm \
	ex_panel.scm \
	ex_window.scm

