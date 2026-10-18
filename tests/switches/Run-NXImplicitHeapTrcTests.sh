#!/usr/bin/env bash
# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
set -euo pipefail
if [[ $# != 3 ]]; then
    echo "Usage: $0 <compiler> <matching-rtl-units> <output-directory>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl=$(realpath "$2")
root=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$3"
out=$(realpath "$3")
rm -f "$out/heaptrc.nxu" "$out/heaptrc.o"
for build in source cached; do
    "$compiler" -n -O2 -Aas-clang -XLL -gh -gl -vi \
        "-Fu$rtl" "-Fu$root/rtl/inc" "-Fi$root/rtl/inc" \
        "-Fu$out" "-FU$out" "-FE$out" \
        "$root/tests/compiler-regressions/implicit_heaptrc_source.pas" \
        >"$out/$build-build.log" 2>&1
    if [[ $build == source ]]; then
        grep -E '^Compiling (.*[/\\])?heaptrc\.pas$' "$out/$build-build.log" >/dev/null
        sha256sum "$out/heaptrc.nxu" "$out/heaptrc.o" >"$out/heaptrc.sha256"
    else
        if grep -E '^Compiling (.*[/\\])?heaptrc\.pas$' "$out/$build-build.log"; then
            echo 'HeapTrc was recompiled instead of loaded from its cached unit.' >&2
            exit 1
        fi
        sha256sum --check "$out/heaptrc.sha256" >"$out/cached-artifacts.log"
    fi
    "$out/implicit_heaptrc_source" >"$out/$build-run.log" 2>&1
    grep -F 'PASS implicit HeapTrc source compilation' "$out/$build-run.log" >/dev/null
    grep -F '0 unfreed memory blocks' "$out/$build-run.log" >/dev/null
done
echo 'PASS: -gh compiles the original HeapTrc source and reuses its cached unit'
