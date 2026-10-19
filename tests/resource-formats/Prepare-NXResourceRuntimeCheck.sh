#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 5 ]]; then
    echo "Usage: $0 <nexus-compiler> <matching-target-rtl> <target-os> <table-fixture.res> <external-output> [compiler/SDK options...]" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl_units=$(realpath "$2")
target_os=$3
fixture=$(realpath "$4")
mkdir -p "$5"
artifact_root=$(realpath "$5")
shift 5
source_root=$(cd "$(dirname "$0")/../.." && pwd)
nxtest_source="$source_root/../nexus/packages/nexus-packages/nxtest/src"
if [[ ! -f "$nxtest_source/obNXTestRegistry.pas" ]]; then
    nxtest_source="$source_root/../../nexus/packages/nexus-packages/nxtest/src"
fi
case "$artifact_root/" in
    "$source_root/"*) echo 'Use an output directory outside the source tree.' >&2; exit 2 ;;
esac
mkdir -p "$artifact_root/units" "$artifact_root/logs"
cp "$fixture" "$artifact_root/runtimetables.res"
cp "$source_root/tests/resource-formats/nxResourceRuntimeTests.pas" "$artifact_root/"
executable=nxResourceRuntimeTests
case $target_os in win32|win64) executable+=.exe ;; esac
command=("$compiler" -n -al -O2 -Cr -Co -Ci -Aas-clang -XLL "-T$target_os"
    "-Fu$rtl_units" "-Fu$source_root/compiler" "-Fu$nxtest_source" "-FU$artifact_root/units"
    "-FE$artifact_root" "-o$artifact_root/$executable" "$@"
    "$artifact_root/nxResourceRuntimeTests.pas")
printf '%q ' "${command[@]}" >"$artifact_root/logs/compiler-command.txt"
printf '\n' >>"$artifact_root/logs/compiler-command.txt"
if ! (cd "$artifact_root" && "${command[@]}") >"$artifact_root/logs/compile.log" 2>&1; then
    cat "$artifact_root/logs/compile.log" >&2
    exit 1
fi
test -f "$artifact_root/$executable"
echo "Prepared $artifact_root/$executable through the integrated compiler resource path."
