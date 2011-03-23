# Makefile -*- mode: makefile -*-

# Makefile for the Gano editor
# Copyright 2011 Michael L Gran
# License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
# This is free software: you are free to change and redistribute it.
# There is NO WARRANTY, to the extent permitted by law.

SHELL = /bin/sh

########################################################################
# CONFIGURATION

.SUFFIXES:
.SUFFIXES: .scm .go

srcdir=src

M4_FLAGS = --fatal-warnings --debug --prefix-builtins
# __INLINE__: if defined, source files will be inline copied into the
#         main script
# __EXTRA__: if set to a filename, that file will be inline copied into
#         the main script
# __TEST__: if set to a filename, the script will be inserted.  Otherwise
#         the main function will be called

#M4_DEFS = -D __INLINE__="yes"

SCHEME_INTERPRETER = guile -s

INSTALL_PROGRAM = $(INSTALL)
INSTALL_DATA = ${INSTALL} -m 644

include $(wildcard config.mk)
VPATH = $(srcdir)

########################################################################
# TARGETS

SRC = gano.scm char.scm cbuf.scm string.scm wcwidth.scm \
	dispatch.scm frame.scm nano-h.scm global.scm function.scm \
	flags.scm shortcut.scm files.scm winio.scm utils.scm

.PHONY: all
all: gano config.mk

config.mk:
	@echo "ERROR: You need to run 'configure' before running 'make'."
	@echo
	@echo "Running 'configure' generates 'config.mk', which is a makefile"
	@echo "fragment that contains path information."
	@echo
	@exit 1

gano: gano.m4 $(SRC)
	m4 $(M4_FLAGS) $(M4_DEFS) gano.m4 > $@

check: CBUF_TEST

gano-dispatch-demo: gano.m4 $(SRC) test/dispatch.demo
	m4 $(M4_FLAGS) $(M4_DEFS) \
	  -D __EXTRA__=test/dispatch.demo \
	  gano.m4 > gano-dispatch-demo

.PHONY: STRING_TEST
STRING_TEST: gano.m4 $(SRC) test/string.test
	m4 $(M4_FLAGS) $(M4_DEFS) \
	  -D __EXTRA__=test/common.test -D __TEST__=test/string.test \
	  gano.m4 > gano.test
	guile -s gano.test

.PHONY: CBUF_TEST
CBUF_TEST: 
	m4 $(M4_FLAGS) $(M4_DEFS) \
	  -D __EXTRA__=test/common.test -D __TEST__=test/cbuf.test \
	  gano.m4 > gano.test
	guile -s gano.test
