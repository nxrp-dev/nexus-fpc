#!/usr/bin/env bash
# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
set -euo pipefail
if [[ $# != 4 ]]; then
    echo "Usage: $0 <compiler> <matching-rtl-units> <matching-compiler-units> <output-directory>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl=$(realpath "$2")
compiler_units=$(realpath "$3")
mkdir -p "$4"
out=$(realpath "$4")
test_dir=$(cd "$(dirname "$0")" && pwd)
flags=(-n -O2 -Aas-clang -XLL "-Fu$rtl" "-FU$out" "-FE$out")
printf 'program Empty; begin end.\n' >"$out/empty.pas"
for option in -Cb -Cb+ -Cb- -CDefinitelyInvalid; do
    if "$compiler" "${flags[@]}" -Cn "$option" "$out/empty.pas" >"$out/${option:1}.log" 2>&1; then
        echo "Unsupported option unexpectedly accepted: $option" >&2
        exit 1
    fi
    grep -F 'Illegal parameter:' "$out/${option:1}.log" >/dev/null
done
"$compiler" -n -h >"$out/help.log" 2>&1
if grep -E '^[[:space:]]*-Cb([[:space:]]|$)' "$out/help.log"; then
    echo 'Compiler help still advertises a big-endian platform option.' >&2
    exit 1
fi
"$compiler" "${flags[@]}" "$test_dir/../compiler-regressions/little_endian_platform.pas" >"$out/data-build.log" 2>&1
"$out/little_endian_platform" | tee "$out/data-run.log"
"$compiler" "${flags[@]}" "-Fu$compiler_units" \
    "$test_dir/../compiler-regressions/little_endian_metadata.pas" >"$out/metadata-build.log" 2>&1
"$out/little_endian_metadata" "$out" | tee "$out/metadata-run.log"
echo 'PASS: retired byte-order options, platform macros, retained data conversions and metadata rejection'
