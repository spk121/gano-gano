# Makefile -*- mode: makefile -*-
SHELL = /bin/sh

.SUFFIXES:
.SUFFIXES: .scm .go

# This following should be 1.8 or 2.0
GUILE_VERSION = 2.0

GUILE = guile

INSTALL_PROGRAM = $(INSTALL)
INSTALL_DATA = ${INSTALL} -m 644

##########################
# INSTALLATION DIRECTORIES

prefix = /usr/local
exec_prefix = $(prefix)
bindir = $(exec_prefix)/bin
sbindir = $(exec_prefix)/sbin
libexecdir = $(exec_prefix)/libexec
datarootdir = $(prefix)/share
datadir = $(datarootdir)
sysconfdir = $(prefix)/etc
sharedstatedir = $(prefix)/com
localstatedir = $(prefix)/var
includedir = $(prefix)/include
docdir = $(datarootdir)/doc/gano
infodir = $(datarootdir)/info
htmldir = $(docdir)
dvidir = $(docdir)
pdfdir = $(docdir)
psdir = $(docdir)
libdir = $(exec_prefix)/lib
lispdir = $(datarootdir)/emacs/site-lisp
guiledir = $(datarootdir)/guile
guilesitedir = $(datarootdir)/guile/site
srcdir = .

##########################
# SHARED SOURCES

lib_sources = chars.scm files.scm flags.scm global.scm input.scm	\
	nano-c.scm nano-h.scm rcfile.scm text.scm utils.scm	\
	winio.scm CBuffer.scm CText.scm CFunction.scm CShortcut.scm	\
	api.scm help.scm
script_sources = nano.scm


ifeq (GUILE_VERSION, 1.8)
include guile-1.8.mk
else # (GUILE_VERSION, 2.0)
include guile-2.0.mk
endif
