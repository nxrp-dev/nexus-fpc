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
for assembler in as as-darwin gas masm nasm nasmcoff nasmdarwin nasmelf nasmobj nasmwdosx nasmwin32 nasmwin64 tasm wasm yasm win64-as; do
    log="$output/rejected-$assembler.log"
    if "$compiler" -n "-A$assembler" "-Fu$rtl_units" "-FU$output" \
        "-FE$output" "$test_dir/removed_legacy_options_baseline.pas" >"$log" 2>&1; then
        echo "Retired assembler unexpectedly accepted: $assembler" >&2
        exit 1
    fi
    grep -F 'Illegal parameter:' "$log" >/dev/null
done
for assembler in default as-clang elf; do
    mode_output="$output/$assembler"
    mkdir -p "$mode_output"
    "$compiler" -n "-A$assembler" "-Fu$rtl_units" "-FU$mode_output" \
        "-o$output/inline-$assembler" "$test_dir/../clangassembler/nxinlineassembler.pas" \
        >"$output/inline-$assembler.log" 2>&1
    "$output/inline-$assembler"
done
echo 'PASS: retired assembler options rejected; Clang and internal ELF writers retain both inline syntaxes'
