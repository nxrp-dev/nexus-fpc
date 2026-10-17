#!/usr/bin/env bash
# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
set -euo pipefail
if [[ $# != 3 ]]; then
    echo "Usage: $0 <native-compiler> <rtl-units> <output-directory>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl_units=$(realpath "$2")
mkdir -p "$3"
output=$(realpath "$3")
checks=0
for mode in FPC ObjFPC Delphi MacPas ISO ExtendedPascal; do
    for convention in empty LEGACY BASEREG; do
        directory="$output/$mode-$convention"
        mkdir -p "$directory"
        if [[ $convention == empty ]]; then
            directive='{$SYSCALL}'
            diagnostic='Specified syscall convention is not useable on this target'
        else
            directive="{\$SYSCALL $convention}"
            diagnostic='Invalid syscall convention specified'
        fi
        printf '%s\n' 'program SyscallDirective;' "$directive" 'begin end.' \
            >"$directory/directive.pas"
        options=(-n -Aas-clang -XLL -Cn -vw "-M$mode" "-Fu$rtl_units" \
            "-FU$directory" "-FE$directory")
        "$compiler" "${options[@]}" "$directory/directive.pas" \
            >"$directory/warning.log" 2>&1
        grep -F "$diagnostic" "$directory/warning.log" >/dev/null
        if "$compiler" "${options[@]}" -Sew "$directory/directive.pas" \
            >"$directory/error.log" 2>&1; then
            echo "Warning-as-error unexpectedly accepted: $mode $convention" >&2
            exit 1
        fi
        grep -F "$diagnostic" "$directory/error.log" >/dev/null
        if grep -F 'Internal error' "$directory/error.log" >/dev/null; then
            cat "$directory/error.log" >&2
            exit 1
        fi
        checks=$((checks + 2))
    done
done
echo "PASS: $checks syscall directive diagnostic checks"
