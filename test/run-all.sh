#!/bin/sh
# Run every test/test-*.scm suite and print a one-line summary for each.
#
# Usage: test/run-all.sh [test-name ...]
#   e.g. test/run-all.sh            # all suites
#        test/run-all.sh cbuf-basic # just test/test-cbuf-basic.scm
#
# SRFI-64 writes a .log file per suite; those go into a scratch
# directory so they don't litter the source tree.  Set KEEP_LOGS=1 to
# keep that directory and print its location.
#
# Exit status is 0 only if every suite ran to completion with no
# unexpected failures.

top=$(cd "$(dirname "$0")/.." && pwd)
GUILE=${GUILE:-guile}
logdir=$(mktemp -d "${TMPDIR:-/tmp}/gano-tests.XXXXXX")

if [ $# -gt 0 ]; then
    tests=""
    for t in "$@"; do tests="$tests $top/test/test-$t.scm"; done
else
    tests=$(ls "$top"/test/test-*.scm | grep -v '/test-texts\.scm$')
fi

status=0
total_pass=0
total_fail=0

for t in $tests; do
    name=$(basename "$t" .scm)
    out="$logdir/$name.out"
    (cd "$logdir" && "$GUILE" -L "$top/src" "$t") >"$out" 2>&1
    rc=$?
    # A file may contain several top-level test-begin/test-end pairs,
    # each printing its own summary, so add them up.
    count() { awk -v pat="^# of $1 " '$0 ~ pat { n += $NF } END { print n + 0 }' "$out"; }
    pass=$(count "expected passes")
    fail=$(count "unexpected failures")
    xfail=$(count "expected failures")
    xpass=$(count "unexpected successes")
    total_pass=$((total_pass + pass))
    total_fail=$((total_fail + fail))

    if [ $rc -ne 0 ] || ! grep -q '^# of ' "$out"; then
        result="CRASH"
        status=1
    elif [ "$fail" -gt 0 ] || [ "$xpass" -gt 0 ]; then
        result="FAIL"
        status=1
    else
        result="ok"
    fi
    printf '%-24s %-5s pass=%-4s fail=%-4s xfail=%-3s' \
           "$name" "$result" "$pass" "$fail" "$xfail"
    if [ "$result" = CRASH ]; then
        printf '  %s' "$(grep -v '^;;;' "$out" | grep -m1 -E 'ERROR|error|Unbound' | cut -c1-70)"
    fi
    printf '\n'
done

printf '\nTotal: %s passed, %s failed\n' "$total_pass" "$total_fail"
if [ -n "$KEEP_LOGS" ]; then
    printf 'Logs kept in %s\n' "$logdir"
else
    rm -rf "$logdir"
fi
exit $status
