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

for option in -Xi -Xi+ -Xe-; do
    log="$output/rejected-${option#-}.log"
    if "$compiler" -n -Aas-clang -XLL "$option" "-Fu$rtl_units" \
        "-FU$output" "-FE$output" "$source_file" >"$log" 2>&1; then
        echo "Internal-linker option unexpectedly accepted: $option" >&2
        exit 1
    fi
    grep -F "Option \"$option\" is not, or not yet, supported" "$log" >/dev/null
done

for option in -Xe -Xi- -XLL; do
    binary="$output/external-${option#-}"
    "$compiler" -n -Aas-clang -XLL "$option" "-Fu$rtl_units" \
        "-FU$output" "-o$binary" "$source_file" >"$binary.log" 2>&1
    "$binary"
done

"$compiler" -n -h >"$output/help.log" 2>&1
if grep -F 'Use internal linker' "$output/help.log"; then
    echo 'Compiler help still advertises the internal linker' >&2
    exit 1
fi

echo 'PASS: internal-linker options rejected; external linking and help checked'
