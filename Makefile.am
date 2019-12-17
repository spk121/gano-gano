## Process this file with automake to produce Makefile.in.
##
##   Copyright (C) 2019 Michael Gran <spk121@yahoo.com>
##
##   This file is part of gano.
##
##   gano is free software: you can redistribute it and/or modify
##   it under the terms of the GNU General Public License as published
##   by the Free Software Foundation, either version 3 of the License,
##   or (at your option) any later version.
##
##   gano is distributed in the hope that it will be useful, but
##   WITHOUT ANY WARRANTY; without even the implied warranty of
##   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
##   General Public License for more details.
##
##   You should have received a copy of the GNU General Public License
##   along with Foobar.  If not, see <https://www.gnu.org/licenses/>.

.DEFAULT:

% : RCS/%,v
% : RCS/%
% : %,v
% : SCCS/s.%
% : s.%

ACLOCAL_AMFLAGS = -I m4 ${ACLOCAL_FLAGS}
AM_DISTCHECK_CONFIGURE_FLAGS = --with-gnu-filesystem-hierarchy

################################################################
# STUFF

EXTRA_DIST = \
 AUTHORS \
 NEWS \
 LICENSE \
 INSTALL \
 build-aux/test-driver \
 build-aux/test-driver.scm \
 tools/uninstalled-env.in

CLEANFILES =

################################################################
# MODULE

pkgguilesitedir = $(guilesitedir)/gano
pkgguileobjectdir = $(guileobjectdir)/gano

dist_pkgguilesite_DATA = \
  module/gano/CBuffer-base.scm \
  module/gano/CBuffer.scm \
  module/gano/CFunction.scm \
  module/gano/CShortcut.scm \
  module/gano/CText.scm \
  module/gano/address.scm \
  module/gano/chars.scm \
  module/gano/config.scm \
  module/gano/ed-repl.scm \
  module/gano/flags.scm \
  module/gano/global.scm \
  module/gano/math.scm \
  module/gano/nano-h.scm \
  module/gano/position.scm \
  module/gano/poslist.scm \
  module/gano/stringlist.scm \
  module/gano/text.scm \
  module/gano/utils.scm

pkgguileobject_DATA = \
  $(dist_pkgguilesite_DATA:%.scm=%.go)

GUILEC_FLAGS = \
 -O2 \
 -Warity-mismatch \
 -Wformat \
 -Wmacro-use-before-definition \
 -Wunbound-variable \
 --load-path=$(abs_srcdir)/module \
 --load-path=$(abs_builddir)/module

.scm.go:
	GUILE_AUTO_COMPILE=0 \
	$(GUILE_TOOLS) compile $(GUILEC_FLAGS) \
	-o "$@" "$<"

CLEANFILES += \
  $(dist_guilesite_DATA:%.scm=%.go) \
  $(dist_pkgguilesite_DATA:%.scm=%.go)

################################################################
# SRC

dist_bin_SCRIPTS = src/gano-ed

src/gano-ed: src/gano-ed.in
	sed s^GUILE^$(GUILE)^ $< > $@
	chmod 755 $@

EXTRA_DIST += src/gano-ed.in
CLEANFILES += src/gano-ed

################################################################
# TEST

TESTS = \
  test/t-gano-math.scm
TEST_EXTENSIONS = .scm

XFAIL_TESTS =

SCM_LOG_DRIVER = \
  $(top_builddir)/tools/uninstalled-env \
  $(GUILE) --no-auto-compile $(top_srcdir)/build-aux/test-driver.scm

test: check

.PHONY: test

################################################################
