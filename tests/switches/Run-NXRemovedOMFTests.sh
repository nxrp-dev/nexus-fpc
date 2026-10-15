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
source_file="$(cd "$(dirname "$0")" && pwd)/removed_legacy_options_baseline.pas"

for option in -Aomf -gm -godwarfomflinnum -godwarfomflinnum-; do
    log="$output/rejected-${option#-}.log"
    if "$compiler" -n -Aas-clang -XLL "$option" "-Fu$rtl_units" \
        "-FU$output" "-FE$output" "$source_file" >"$log" 2>&1; then
        echo "Retired OMF option unexpectedly accepted: $option" >&2
        exit 1
    fi
    grep -F 'Illegal parameter:' "$log" >/dev/null
done

for option in -gw3 -godwarfcpp; do
    binary="$output/retained-${option#-}"
    "$compiler" -n -Aas-clang -XLL -g -gw3 "$option" "-Fu$rtl_units" \
        "-FU$output" "-o$binary" "$source_file" >"$binary.log" 2>&1
    "$binary"
done

"$compiler" -n -h >"$output/help.log" 2>&1
if grep -Ei 'CodeView|DWARFOMFLINNUM' "$output/help.log"; then
    echo 'Compiler help still advertises retired OMF debug support' >&2
    exit 1
fi

echo 'PASS: OMF options rejected; retained DWARF options link and run'
