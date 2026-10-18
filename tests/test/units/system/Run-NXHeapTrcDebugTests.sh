#!/usr/bin/env bash
# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
set -euo pipefail
if [[ $# != 4 ]]; then
    echo "Usage: $0 <native-compiler> <rtl-units> <heaptrc-source> <output-directory>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl_units=$(realpath "$2")
heaptrc_source=$(realpath "$3")
fixture=$(cd "$(dirname "$0")" && pwd)/theaptrcreport.pas
mkdir -p "$4"
output=$(realpath "$4")
for variant in normal debug; do
    directory="$output/$variant"
    mkdir -p "$directory/units" "$directory/consumer"
    defines=()
    if [[ $variant == debug ]]; then defines=(-ddebug_heaptrc); fi
    "$compiler" -n -O2 -Aas-clang -XLL "${defines[@]}" "-Fu$rtl_units" \
        "-Fi$(dirname "$heaptrc_source")" "-FU$directory/units" \
        "$heaptrc_source" >"$directory/unit.log" 2>&1
    "$compiler" -n -O2 -Aas-clang -XLL "${defines[@]}" \
        "-Fu$directory/units" "-Fu$rtl_units" "-FU$directory/consumer" \
        "-FE$directory/consumer" "$fixture" \
        >"$directory/compile.log" 2>&1
    (cd "$directory/consumer"; ./theaptrcreport) >"$directory/runtime.log" 2>&1
    echo "PASS HeapTrc $variant report and dump checks"
done
