# Makefile.am for gano/test.
#
# Copyright 2009, 2010, 2011, 2014, 2016 Free Software Foundation, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 3, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this program.  If not, see
# <http://www.gnu.org/licenses/>.

TESTLIB = automake-test-lib.scm

AM_TESTS_ENVIRONMENT = \
	ORIGTERM=${TERM}; export ORIGTERM; \
	TERM=xterm; export TERM; \
	GUILE_AUTO_COMPILE=0; export GUILE_AUTO_COMPILE;
TEST_EXTENSIONS = .scm
SCM_LOG_COMPILER = guile
AM_SCM_LOG_FLAGS = -L $(abs_top_srcdir) -s

NOTERMTESTS = \
 cbuffer_bell.scm \
 cbuffer_bell_clear.scm \
 cbuffer_backspace_empty_line.scm \
 cbuffer_backspace_bol.scm \
 cbuffer_backspace.scm \
 cbuffer_cursor_backward_tabulation_empty_line.scm \
 cbuffer_cursor_backward_tabulation_bol.scm \
 cbuffer_cursor_backward_tabulation_column_1.scm \
 cbuffer_cursor_backward_tabulation_column_8.scm \
 cbuffer_cursor_backward_tabulation_column_9.scm

NARROWTESTS =
WIDETESTS =

TESTS = $(NOTERMTESTS) $(NARROWTESTS) $(WIDETESTS)

EXTRA_DIST = $(TESTLIB) $(NOTERMTESTS) $(NARROWTESTS) $(WIDETESTS)

