#!/usr/bin/env bash
set -euo pipefail
if [[ $# != 3 ]]; then
    echo "Usage: $0 <nexus-compiler> <matching-x86-rtl> <external-output>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl=$(realpath "$2")
root=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$3"
out=$(realpath "$3")
case "$out/" in "$root/"*) echo 'Use an external output directory.' >&2; exit 2 ;; esac
mkdir -p "$out/units"
flags=(-n -O2 -Cr -Co -Ci -al -Aas-clang -XLL "-Fu$rtl" "-FU$out/units" "-FE$out")
"$compiler" "${flags[@]}" "$root/tests/resource-formats/nxCRC32WidthTests.pas" >"$out/compile.log" 2>&1
if "$out/nxCRC32WidthTests" >"$out/runtime.log" 2>&1; then
    :
else
    code=$?
    if [[ $code != 77 ]]; then
        cat "$out/runtime.log" >&2
        exit "$code"
    fi
fi
llvm-objdump -d "$out/units/nxCRC32WidthTests.o" >"$out/encoding.log"
for width in b w l; do rg "crc32$width[[:space:]]" "$out/encoding.log" >/dev/null; done
if rg -F 'crc32q' "$out/encoding.log" >/dev/null; then
    rg 'crc32b.*%rax' "$out/encoding.log" >/dev/null
fi
"$compiler" "${flags[@]}" \
    "-Fu$root/packages/rtl-generics/src" "-Fi$root/packages/rtl-generics/src" \
    "-Fu$root/packages/rtl-objpas/src/inc" "-Fi$root/packages/rtl-objpas/src/inc" \
    "$root/tests/resource-formats/nxStringHashTests.pas" >"$out/hash-compile.log" 2>&1
"$out/nxStringHashTests" >"$out/hash-runtime.log" 2>&1
cat "$out/runtime.log" "$out/hash-runtime.log"
