## Process this file with automake to produce Makefile.in
## $Id: Makefile.am,v 1.3 2008/01/05 05:03:27 spike_gran Exp $

# Cygwin's texi2dvi can try to call etex, resulting in this error:
#   "texinfo.tex appears to be broken, quitting"
# The problem lies in Cygwin's etex.fmt file
# Forcing TEX to tex works around this problem
# This should not harm other platforms
TEX=tex
TEXI2DVI = TEX=${TEX} texi2dvi


info_TEXINFOS = gucu.texi