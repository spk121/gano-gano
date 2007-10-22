pkglib_LTLIBRARIES = libguile-gucu.la
libguile_gucu_la_SOURCES = constant.c function.c type.c special.c raw.c \
	constant.h function.h type.h special.h
libguile_gucu_la_CPPFLAGS = $(GUILE_CFLAGS) -D_XOPEN_SOURCE_EXTENDED
libguile_gucu_la_LDFLAGS = $(GUILE_LDFLAGS) -lcursesw

guile_sitedir = $(GUILE_SITE)
pkgguile_sitedir = $(guile_sitedir)/$(PACKAGE)
pkgguile_site_DATA = raw.scm 
EXTRA_DIST = raw.scm.in
BUILT_SOURCES = raw.scm
CLEANFILES = raw.scm

raw.scm: raw.scm.in
	sed 's|XXlibdirXX|$(pkglibdir)|' < raw.scm.in | \
	sed 's|XXpackageXX|$(PACKAGE)|' > raw.scm

