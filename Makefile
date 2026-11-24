# Makefile for gano, a simple console text editor in GNU Guile
#
#   make             byte-compile the modules into build/, with warnings
#   make check       run the test suites (after compiling)
#   make dist        make gano-$(VERSION).tar.gz
#   make distcheck   make the tarball, then build and check it unpacked
#   make clean       remove build products
#
# Guile's programs are found with pkg-config; set GUILE_PC to pick another
# Guile (default guile-3.0), or set GUILE / GUILD directly.

PACKAGE    = gano
VERSION    = 0.0.1

PKG_CONFIG ?= pkg-config
GUILE_PC   ?= guile-3.0
GUILE      ?= $(shell $(PKG_CONFIG) --variable=guile $(GUILE_PC))
GUILD      ?= $(shell $(PKG_CONFIG) --variable=guild $(GUILE_PC))

ifeq ($(strip $(GUILD)),)
$(error Cannot find guild: is $(GUILE_PC).pc installed (e.g. the Guile -dev package)?)
endif

BUILDDIR   = build

# Every warning except the unused-variable / unused-toplevel ones
WARNINGS   = -Wunbound-variable -Warity-mismatch -Wformat \
             -Wmacro-use-before-definition -Wuse-before-definition \
             -Wshadowed-toplevel -Wnon-idempotent-definition \
             -Wduplicate-case-datum -Wbad-case-datum
GUILDFLAGS = -O2 $(WARNINGS) -L src

MODULES    := $(sort $(wildcard src/gano/*.scm))
OBJECTS    := $(MODULES:src/gano/%.scm=$(BUILDDIR)/gano/%.go)

TESTS      := $(sort $(wildcard test/test-*.scm))
DISTFILES  = Makefile README NEWS AUTHORS COPYING LICENSE \
             bin/gano $(MODULES) \
             test/run-all.sh $(TESTS) \
             tools/guile-cache.sh tools/generate-wcwidth.py \
             tools/generate_bidi_class.py tools/generate_bracket_pairs.py \
             $(wildcard doc/*)
DISTDIR    = $(PACKAGE)-$(VERSION)

.PHONY: all check dist distcheck clean

all: $(OBJECTS)

# Compile against the already-compiled modules in $(BUILDDIR); the
# dependency rules below make sure those are built (and rebuilt) first.
$(BUILDDIR)/gano/%.go: src/gano/%.scm
	@mkdir -p $(@D)
	GUILE_AUTO_COMPILE=0 GUILE_LOAD_COMPILED_PATH=$(BUILDDIR) \
	  $(GUILD) compile $(GUILDFLAGS) -o $@ $<

# A module is recompiled when a module it imports changes (Guile inlines
# across modules, so a stale import can leave stale code).  The
# dependencies come from the (gano ...) names each source mentions.
$(BUILDDIR)/deps.mk: $(MODULES)
	@mkdir -p $(@D)
	@for f in $(MODULES); do \
	  m=$$(basename $$f .scm); \
	  for d in $$(grep -o '(gano [a-z0-9-]*)' $$f | sed 's/(gano \(.*\))/\1/' | sort -u); do \
	    if [ "$$d" != "$$m" ] && [ -f src/gano/$$d.scm ]; then \
	      echo "$(BUILDDIR)/gano/$$m.go: $(BUILDDIR)/gano/$$d.go"; \
	    fi; \
	  done; \
	done > $@

-include $(BUILDDIR)/deps.mk

# The suites load the modules compiled above; the test files themselves
# are auto-compiled into .cache/guile (see tools/guile-cache.sh).
check: all
	GUILE=$(GUILE) GUILE_LOAD_COMPILED_PATH=$(abspath $(BUILDDIR)) test/run-all.sh

dist: $(DISTDIR).tar.gz

$(DISTDIR).tar.gz: $(DISTFILES)
	rm -rf $(DISTDIR)
	mkdir -p $(DISTDIR)
	tar cf - $(DISTFILES) | (cd $(DISTDIR) && tar xf -)
	tar czf $@ $(DISTDIR)
	rm -rf $(DISTDIR)

distcheck: dist
	rm -rf $(BUILDDIR)/distcheck
	mkdir -p $(BUILDDIR)/distcheck
	tar xzf $(DISTDIR).tar.gz -C $(BUILDDIR)/distcheck
	$(MAKE) -C $(BUILDDIR)/distcheck/$(DISTDIR) check
	rm -rf $(BUILDDIR)/distcheck
	@echo "$(DISTDIR).tar.gz is ready"

clean:
	rm -rf $(BUILDDIR) $(DISTDIR) $(DISTDIR).tar.gz
