#!/usr/bin/env bash
# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
set -euo pipefail
if [[ $# != 3 ]]; then
    echo "Usage: $0 <compiler> <matching-rtl-units> <output-directory>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl=$(realpath "$2")
mkdir -p "$3"
out=$(realpath "$3")
flags=(-n -Aas-clang -XLL -Cn "-Fu$rtl")
printf 'program Empty; begin end.\n' >"$out/empty.pas"
for mode in extendedpascal EXTENDEDPASCAL extendedpascal- NexusUnknownMode; do
    directory="$out/command-$mode"
    mkdir -p "$directory"
    if "$compiler" "${flags[@]}" "-M$mode" "-FU$directory" "-FE$directory" \
        "$out/empty.pas" >"$directory/run.log" 2>&1; then
        echo "Unknown mode unexpectedly accepted: $mode" >&2
        exit 1
    fi
    grep -F 'Illegal parameter:' "$directory/run.log" >/dev/null
done
for mode in extendedpascal NexusUnknownMode; do
    directory="$out/source-$mode"
    mkdir -p "$directory"
    printf 'program UnknownMode;\n{$mode %s}\n{$ifdef FPC_EXTENDEDPASCAL}{$fatal Unexpected mode macro}{$endif}\nbegin end.\n' \
        "$mode" >"$directory/check.pas"
    "$compiler" "${flags[@]}" -vw "-FU$directory" "-FE$directory" \
        "$directory/check.pas" >"$directory/warning.log" 2>&1
    grep -F 'Illegal compiler switch' "$directory/warning.log" >/dev/null
    if "$compiler" "${flags[@]}" -vw -Sew "-FU$directory" "-FE$directory" \
        "$directory/check.pas" >"$directory/error.log" 2>&1; then
        echo "Unknown mode warning unexpectedly accepted with -Sew: $mode" >&2
        exit 1
    fi
    grep -F 'Illegal compiler switch' "$directory/error.log" >/dev/null
done
"$compiler" -n -h >"$out/help.log" 2>&1
if grep -i 'extendedpascal\|ISO 10206' "$out/help.log"; then
    echo 'Compiler help still advertises Extended Pascal' >&2
    exit 1
fi
echo 'PASS: Extended Pascal uses ordinary unknown-mode diagnostics and is absent from help'
