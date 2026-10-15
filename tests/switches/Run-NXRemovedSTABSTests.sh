#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 3 ]]; then
    echo "Usage: $0 <native-compiler> <rtl-units> <output-directory>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl_units=$(realpath "$2")
mkdir -p "$3"
output=$(realpath "$3")
test_dir=$(cd "$(dirname "$0")" && pwd)

for option in -gs -gs- -gp -gp- -gp+ -gostabsabsincludes -gostabsabsincludes-; do
    log="$output/rejected-${option#-}.log"
    if "$compiler" -n -Aas-clang -XLL "$option" "-Fu$rtl_units" \
        "-FU$output" "-FE$output" "$test_dir/removed_legacy_options_baseline.pas" >"$log" 2>&1; then
        echo "Retired STABS option unexpectedly accepted: $option" >&2
        exit 1
    fi
    grep -F 'Illegal parameter:' "$log" >/dev/null
done

for option in -g -gw3 -gw4 -gw5; do
    binary="$output/retained-${option#-}"
    "$compiler" -n -Aas-clang -XLL -O- -gl "$option" "-Fu$rtl_units" \
        "-FU$output" "-o$binary" "$test_dir/removed_stabs_dwarf.pas" >"$binary.log" 2>&1
    "$binary"
    readelf -S "$binary" >"$binary.sections"
    grep -F '.debug_info' "$binary.sections" >/dev/null
    if grep -E '\.stab(str)?([[:space:]]|$)' "$binary.sections"; then
        echo 'Executable contains retired STABS sections' >&2
        exit 1
    fi
done

"$compiler" -n -h >"$output/help.log" 2>&1
if grep -Ei -- '^[[:space:]]+-g(s|p)([[:space:]]|$)|gostabsabsincludes|Generate.*Stabs|STABX' "$output/help.log"; then
    echo 'Compiler help still advertises STABS' >&2
    exit 1
fi

echo 'PASS: STABS options rejected; DWARF 3/4/5 link, run, and resolve source locations'
