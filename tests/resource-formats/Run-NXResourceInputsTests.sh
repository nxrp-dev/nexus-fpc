#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <compiler> <matching-rtl-units> <output-directory>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl_units=$(realpath "$2")
source_root=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$3"
artifact_root=$(realpath "$3")
mkdir -p "$artifact_root/units" "$artifact_root/logs"

nxtest_source="$source_root/../nexus/packages/nexus-packages/nxtest/src"
if [[ ! -f "$nxtest_source/obNXTestRegistry.pas" ]]; then
    nxtest_source="$source_root/../../nexus/packages/nexus-packages/nxtest/src"
fi


run_step() {
    local name=$1
    shift
    if "$@" >"$artifact_root/logs/$name.log" 2>&1; then
        echo "PASS: $name"
    else
        cat "$artifact_root/logs/$name.log" >&2
        return 1
    fi
}

run_step compile "$compiler" "-Fu$nxtest_source" -n -O2 -Cr -Co -Ci \
    "-Fu$rtl_units" "-Fu$source_root/compiler" "-Fu$nxtest_source" \
    "-FU$artifact_root/units" "-FE$artifact_root" \
    "-o$artifact_root/nxResourceInputsTests" \
    "$source_root/tests/resource-formats/ResourceTests.lpr"
run_step inputs "$artifact_root/nxResourceInputsTests" inputs "$source_root" "$artifact_root"
cat "$artifact_root/logs/inputs.log"
for fixture in simple bom inherited childpos tres6 com_serv; do
    run_step "llvm-$fixture" llvm-cvtres /MACHINE:X64 /TIMESTAMP:0 \
        "/OUT:$artifact_root/$fixture.obj" "$artifact_root/$fixture.res"
done
