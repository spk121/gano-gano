# Makefile

SUFFIXES = .scm .go

GUILE_WARNINGS = -Wunsupported-warning -Wunbound-variable -Warity-mismatch \
	-Wformat

MAKEINFO = makeinfo

########################
# SOURCES

vpath %.scm gano

main_sources = nano.scm
lib_sources = chars.scm files.scm flags.scm global.scm input.scm	\
	nano-c.scm nano-h.scm rcfile.scm records.scm		\
	search.scm text.scm utils.scm winio.scm
sources = $(lib_sources) $(main_sources)

objects := $(notdir $(patsubst %.scm,%.go,$(sources)))

########################
# TEST ENVIRONMENT

TESTS_ENVIRONMENT = GUILE_AUTO_COMPILE=0 guile -L . -s

# These should return
pass_test_sources = homedir.scm get_shortcut.scm
xfail_test_sources = sunder.test
test_sources := $(pass_test_sources) $(xfail_test_sources)

testdir = tests
tests = $(addprefix $(testdir)/,$(test_sources))
xfail_tests = $(addprefix $(testdir)/,$(xfail_test_sources))

########################
# STANDARD TARGETS

all: $(objects)

install:

uninstall:

clean:
	-rm $(objects) *~

distclean:

mostlyclean:

maintainer-clean:

TAGS: $(sources)
	etags $^

info:

dist:

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

%.go : %.scm
	GUILE_AUTO_COMPILE=0 \
	guile-tools compile $(GUILE_WARNINGS) -L . --output="$@" "$<"


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
