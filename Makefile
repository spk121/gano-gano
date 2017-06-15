# 

SCM_SCRIPTS = \
 gano-ed

SCM_SRC = \
 gano/address.scm \
 gano/CBuffer.scm \
 gano/ed-repl.scm \
 gano/math.scm \
 gano/position.scm \
 gano/poslist.scm \
 gano/stringlist.scm

SCM_OBJ := $(patsubst %.scm,%.go,$(SCM_SRC))
SCM_SCRIPT_OBJ := $(patsubst %,%.go,$(SCM_SCRIPTS))

C_SRC =
C_OBJ := $(patsubst %.c,%.o,$(C_SRC))

.SUFFIXES: .c .o .scm .go

GUILE_VERSION = 2.2

CFLAGS = -g -O1 \
  -Wall `pkg-config --cflags guile-$(GUILE_VERSION)` -fpic
LIBS = `pkg-config --libs guile-$(GUILE_VERSION)`
SCM_CFLAGS = -Wunsupported-warning -Wunused-variable -Wunused-toplevel\
 -Warity-mismatch -Wduplicate-case-datum \
 -Wbad-case-datum -Wformat
SCM_LDFLAGS = -L ..

all: gano.go.tar.gz

gano.go.tar.gz: gano.go.tar
	gzip -f gano.go.tar

gano.go.tar: $(SCM_OBJ) $(SCM_SCRIPT_OBJ)
	tar -c -f $@ -H ustar $(SCM_OBJ)

.scm.go:
	unset GUILE_LOAD_COMPILED_PATH ; \
	GUILE_WARN_DEPRECATED=detailed \
	LC_ALL=C \
	guild compile $(SCM_LDFLAGS) $(SCM_CFLAGS) -o "$@" "$<"

gano-ed.go: gano-ed
	unset GUILE_LOAD_COMPILED_PATH ; \
	GUILE_WARN_DEPRECATED=detailed \
	LC_ALL=C \
	guild compile $(SCM_LDFLAGS) $(SCM_CFLAGS) -o "$@" "$<"

clean:
	-rm -f $(SCM_SCRIPT_OBJ)
	-rm -f $(SCM_OBJ)
	# -rm -f $(C_OBJ)
	-rm -f *~
	-rm gano.go.tar

install:
	mkdir -p `pkg-config guile-$(GUILE_VERSION) --variable=extensiondir`
	mkdir -p `pkg-config guile-$(GUILE_VERSION) --variable=sitedir`/mlg
	cp libguile-mlg.so `pkg-config guile-$(GUILE_VERSION) --variable=extensiondir`
	cp $(SCM_SRC) `pkg-config guile-$(GUILE_VERSION) --variable=sitedir`/mlg
