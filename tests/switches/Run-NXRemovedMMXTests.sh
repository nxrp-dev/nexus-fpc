#!/usr/bin/env bash
# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
set -euo pipefail
if [[ $# != 3 ]]; then
    echo "Usage: $0 <compiler> <matching-rtl-units> <output-directory>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl_units=$(realpath "$2")
mkdir -p "$3"
output=$(realpath "$3")
test_dir=$(cd "$(dirname "$0")" && pwd)
checks=0
for mode in FPC ObjFPC Delphi MacPas; do
    for directive in MMX SATURATION; do
        for toggle in ON OFF + -; do
            directory="$output/$mode-$directive-$toggle"
            mkdir -p "$directory"
            printf 'program RetiredMMXDirective;\n{$%s %s}\nbegin end.\n' \
                "$directive" "$toggle" >"$directory/directive.pas"
            options=(-n -Aas-clang -XLL -Cn -vw "-M$mode" "-Fu$rtl_units" \
                "-FU$directory" "-FE$directory")
            "$compiler" "${options[@]}" "$directory/directive.pas" \
                >"$directory/warning.log" 2>&1
            grep -F "Illegal compiler directive" "$directory/warning.log" | \
                grep -F "$directive" >/dev/null
            if "$compiler" "${options[@]}" -Sew "$directory/directive.pas" \
                >"$directory/error.log" 2>&1; then
                echo "Retired directive unexpectedly accepted with -Sew: $directive $toggle" >&2
                exit 1
            fi
            grep -F "Illegal compiler directive" "$directory/error.log" | \
                grep -F "$directive" >/dev/null
            checks=$((checks + 2))
        done
    done
done
"$compiler" -n -Aas-clang -XLL -Cn -Sew "-Fu$rtl_units" "-FU$output" \
    "-FE$output" "$test_dir/../compiler-regressions/removed_mmx_native.pas" \
    >"$output/retained-native.log" 2>&1
if "$compiler" -n -Aas-clang -XLL -Cn -vw "-Fu$rtl_units" "-FU$output" \
    "-FE$output" "$test_dir/../compiler-regressions/removed_mmx_array_arithmetic.pas" \
    >"$output/array-arithmetic.log" 2>&1; then
    echo 'Retired built-in MMX array arithmetic unexpectedly accepted' >&2
    exit 1
fi
grep -F 'Operator is not overloaded' "$output/array-arithmetic.log" >/dev/null
echo "PASS: $checks directive diagnostics; retired array arithmetic rejected; ordinary arrays and assembly retained"
