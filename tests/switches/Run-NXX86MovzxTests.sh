#!/usr/bin/env bash
# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
set -euo pipefail
if [[ $# != 4 ]]; then
    echo "Usage: $0 <linux-x64-host-compiler> <host-rtl-units> <backend-compiler-units> <output-directory>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl_units=$(realpath "$2")
compiler_units=$(realpath "$3")
mkdir -p "$4"
output=$(realpath "$4")
test_dir=$(cd "$(dirname "$0")" && pwd)
nxtest_source="$test_dir/../../../nexus/packages/nexus-packages/nxtest/src"
if [[ ! -f "$nxtest_source/obNXTestRegistry.pas" ]]; then
    nxtest_source="$test_dir/../../../../nexus/packages/nexus-packages/nxtest/src"
fi

"$compiler" "-Fu$nxtest_source" -n -O2 -Aas-clang -XLL "-Fu$rtl_units" "-Fu$compiler_units" \
    "-FU$output" "-o$output/x86_movzx_memory_operand" \
    "$test_dir/../compiler-regressions/x86_movzx_memory_operand.pas" \
    >"$output/build.log" 2>&1
"$output/x86_movzx_memory_operand" | tee "$output/run.log"
