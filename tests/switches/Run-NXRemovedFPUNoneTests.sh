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
nxtest_source="$test_dir/../../../nexus/packages/nexus-packages/nxtest/src"
if [[ ! -f "$nxtest_source/obNXTestRegistry.pas" ]]; then
    nxtest_source="$test_dir/../../../../nexus/packages/nexus-packages/nxtest/src"
fi
printf 'program Empty; begin end.\n' >"$output/empty.pas"
checks=0
for mode in FPC ObjFPC Delphi MacPas; do
    options=(-n -XLL -Cn "-M$mode" "-Fu$rtl_units" "-FU$output" "-FE$output")
    for value in NONE none '' DefinitelyInvalid; do
        label=${value:-empty}
        log="$output/$mode-option-$label.log"
        if "$compiler" "${options[@]}" "-Cf$value" "$output/empty.pas" >"$log" 2>&1; then
            echo "Unsupported FPU option unexpectedly accepted: -Cf$value" >&2
            exit 1
        fi
        grep -F 'Illegal parameter:' "$log" >/dev/null
        printf 'program InvalidFPU;\n{$FPUTYPE %s}\nbegin end.\n' "$value" >"$output/directive.pas"
        log="$output/$mode-directive-$label.log"
        if "$compiler" "${options[@]}" "$output/directive.pas" >"$log" 2>&1; then
            echo "Unsupported FPUTYPE unexpectedly accepted: $value" >&2
            exit 1
        fi
        grep -F 'Illegal FPU type' "$log" >/dev/null
        checks=$((checks + 2))
    done
done
"$compiler" -n -Aas-clang -XLL "-Fu$rtl_units" "-Fu$nxtest_source" "-FU$output" "-FE$output" \
    "$test_dir/../compiler-regressions/removed_fpunone_native.pas" \
    >"$output/retained-native.log" 2>&1
"$output/removed_fpunone_native" | tee "$output/retained-native-run.log"
echo "PASS: $checks unsupported FPU diagnostics; floating-point operations retained"
