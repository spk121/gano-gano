# Makefile
.SUFFIXES: .scm .go

GUILECOMPILE = guild compile
GUILECOMPILEFLAGS = -Wunsupported-warning -Wunbound-variable -Warity-mismatch \
	-Wformat

guilesitedir = $(datarootdir)/guile/$(GUILE_VERSION)/site
srcdir = .

##########################
# SOURCES

vpath %.scm src
vpath %.scm src/gano

sources = $(lib_sources) $(script_sources)

lib_objects := $(notdir $(patsubst %.scm,%.go,$(lib_sources)))

########################
# TEST ENVIRONMENT

TESTS_ENVIRONMENT = GUILE_AUTO_COMPILE=0 guile -L . -s

# These should return
pass_test_sources =
xfail_test_sources =
test_sources := $(pass_test_sources) $(xfail_test_sources)

testdir = tests
tests = $(addprefix $(testdir)/,$(test_sources))
xfail_tests = $(addprefix $(testdir)/,$(xfail_test_sources))

########################
# STANDARD TARGETS

# ALL: compile the entire program.  Do not rebuild and documentation
# files.
all: $(lib_objects)

# INSTALL: compile the program and copy the executables, libraries.
# Create all the directories in which files are to be installed, if
# they don't exist.

# PRE_INSTALL:
install:
	$(PRE_INSTALL)
	$(NORMAL_INSTALL)
	$(POST_INSTALL)		# Run install-info


# UNINSTALL: delete all the installed files
uninstall:
	$(PRE_UNINSTALL)	# Delete entries from info directory
	$(NORMAL_UNINSTALL)
	$(POST_UNINSTALL)

# CLEAN: delete all files created by building the program.  Don't delete
# files that record the configuration.  Preserve files that could be
# made by building but aren't because the distribution comes with them.
# Delete dvi files if they are not part of the distribution.
clean:
	-rm -f $(objects) *~

# DISTCLEAN: delete all the files created by this makefile that are created
# by configuring or building the program.  Leave only the files that
# were in the distribution.
distclean:

# MOSTLYCLEAN: like CLEAN, but, don't delete files you really don't
# want to recompile.
mostlyclean:

# MAINTAINER-CLEAN: delete almost everything that can be reconstructed
# with this makefile, except configure.
maintainer-clean:

# TAGS: update a tags table for this program
TAGS: $(sources)
	etags $^

# INFO: generate info files
info:

# Create a distribution tar file for this program. (Depends on all non-source
# files that are in the distribution)
dist:

# CHECK: perform self-tests
check: $(tests)
	@failed=0; all=0; xfail=0; xpass=0; skip=0; \
	list=' $+ '; \
	echo "$$list"; \
	$(tty_colors); \
	if test -n "$$list"; then \
	  for tst in $$list; do \
	    if test -f ./$$tst; then dir=./; \
	    elif test -f $$tst; then dir=; \
	    else dir="$(srcdir)/"; fi; \
	    if $(TESTS_ENVIRONMENT) $${dir}$$tst; then \
	      all=`expr $$all + 1`; \
	      case " $(xfail_tests) " in \
	      *[\ \	]$$tst[\ \	]*) \
		xpass=`expr $$xpass + 1`; \
		failed=`expr $$failed + 1`; \
		col=$$red; res=XPASS; \
	      ;; \
	      *) \
		col=$$grn; res=PASS; \
	      ;; \
	      esac; \
	    elif test $$? -ne 77; then \
	      all=`expr $$all + 1`; \
	      case " $(xfail_tests) " in \
	      *[\ \	]$$tst[\ \	]*) \
		xfail=`expr $$xfail + 1`; \
		col=$$lgn; res=XFAIL; \
	      ;; \
	      *) \
		failed=`expr $$failed + 1`; \
		col=$$red; res=FAIL; \
	      ;; \
	      esac; \
	    else \
	      skip=`expr $$skip + 1`; \
	      col=$$blu; res=SKIP; \
	    fi; \
	    echo "$${col}$$res$${std}: $$tst"; \
	  done; \
	  if test "$$all" -eq 1; then \
	    tests="test"; \
	    All=""; \
	  else \
	    tests="tests"; \
	    All="All "; \
	  fi; \
	  if test "$$failed" -eq 0; then \
	    if test "$$xfail" -eq 0; then \
	      banner="$$All$$all $$tests passed"; \
	    else \
	      if test "$$xfail" -eq 1; then failures=failure; else failures=failures; fi; \
	      banner="$$All$$all $$tests behaved as expected ($$xfail expected $$failures)"; \
	    fi; \
	  else \
	    if test "$$xpass" -eq 0; then \
	      banner="$$failed of $$all $$tests failed"; \
	    else \
	      if test "$$xpass" -eq 1; then passes=pass; else passes=passes; fi; \
	      banner="$$failed of $$all $$tests did not behave as expected ($$xpass unexpected $$passes)"; \
	    fi; \
	  fi; \
	  dashes="$$banner"; \
	  skipped=""; \
	  if test "$$skip" -ne 0; then \
	    if test "$$skip" -eq 1; then \
	      skipped="($$skip test was not run)"; \
	    else \
	      skipped="($$skip tests were not run)"; \
	    fi; \
	    test `echo "$$skipped" | wc -c` -le `echo "$$banner" | wc -c` || \
	      dashes="$$skipped"; \
	  fi; \
	  report=""; \
	  if test "$$failed" -ne 0 && test -n "$(PACKAGE_BUGREPORT)"; then \
	    report="Please report to $(PACKAGE_BUGREPORT)"; \
	    test `echo "$$report" | wc -c` -le `echo "$$banner" | wc -c` || \
	      dashes="$$report"; \
	  fi; \
	  dashes=`echo "$$dashes" | sed s/./=/g`; \
	  if test "$$failed" -eq 0; then \
	    echo "$$grn$$dashes"; \
	  else \
	    echo "$$red$$dashes"; \
	  fi; \
	  echo "$$banner"; \
	  test -z "$$skipped" || echo "$$skipped"; \
	  test -z "$$report" || echo "$$report"; \
	  echo "$$dashes$$std"; \
	  test "$$failed" -eq 0; \
	else :; fi

.PHONY : all install uninstall clean distclean mostlyclean maintainer-clean \
	info dist check
########################

nano : nano.scm
	ln -s $^ $@
	chmod 755 $@

nano.go : nano
	GUILE_AUTO_COMPILE=0 \
	$(GUILECOMPILE) $(GUILECOMPILEFLAGS) -L . --output="$@" "$<"

%.go : %.scm
	GUILE_AUTO_COMPILE=0 \
	$(GUILECOMPILE) $(GUILECOMPILEFLAGS) -L . -L src --output="$@" "$<"


# If stdout is a non-dumb tty, use colors.  If test -t is not supported,
# then this fails; a conservative approach.  Of course do not redirect
# stdout here, just stderr.
tty_colors = \
red=; grn=; lgn=; blu=; std=; \
test "$$TERM" != dumb \
&& { test -t 1 2>/dev/null; } \
&& { \
  red='[0;31m'; \
  grn='[0;32m'; \
  lgn='[1;32m'; \
  blu='[1;34m'; \
  std='[m'; \
}
