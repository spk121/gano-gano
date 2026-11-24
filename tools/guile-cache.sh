# Source this (from bin/gano or test/run-all.sh) with $top set to the
# top of the source tree.  It points Guile's auto-compile cache at
# $top/.cache/guile and empties that cache whenever any module source
# changes.
#
# Why: Guile recompiles a module only when its own .scm file is newer
# than its .go file.  A module compiled against an older version of a
# module it imports can keep stale inlined code (record accessors in
# particular), which shows up as baffling errors after an edit.  Keying
# the whole cache on a fingerprint of every source file avoids that, at
# the cost of a full recompile (about 20s) after any change.

gano_cache_dir="$top/.cache/guile"
gano_fingerprint=$(cat "$top"/src/gano/*.scm | cksum | cut -d' ' -f1)
if [ "$(cat "$gano_cache_dir/FINGERPRINT" 2>/dev/null)" != "$gano_fingerprint" ]; then
    rm -rf "$gano_cache_dir"
    mkdir -p "$gano_cache_dir"
    echo "$gano_fingerprint" > "$gano_cache_dir/FINGERPRINT"
fi
XDG_CACHE_HOME="$gano_cache_dir"
export XDG_CACHE_HOME
