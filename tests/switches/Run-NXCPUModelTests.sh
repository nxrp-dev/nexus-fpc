#!/usr/bin/env bash
# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
set -euo pipefail
if [[ $# != 4 ]]; then
    echo "Usage: $0 <compiler> <matching-rtl-units> <matching-x86_64-compiler-units> <output-directory>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl_units=$(realpath "$2")
compiler_units=$(realpath "$3")
mkdir -p "$4"
output=$(realpath "$4")
test_dir=$(cd "$(dirname "$0")" && pwd)
options=(-n -O2 -Aas-clang -XLL "-Fu$rtl_units")
mkdir -p "$output/models"
"$compiler" "${options[@]}" "-Fu$compiler_units" \
    "-FU$output/models" "-FE$output/models" \
    "$test_dir/../compiler-regressions/cpu_models.pas" >"$output/models/build.log" 2>&1
"$output/models/cpu_models" | tee "$output/models/run.log"

cat >"$output/CPUMacros.pas" <<'PASCAL'
program CPUMacros;
{$if not defined(CPUX86_64)} {$fatal Missing architecture macro} {$endif}
{$if defined(CPUATHLON64) <> defined(ExpectAthlon)} {$fatal Wrong Athlon64 macro} {$endif}
{$if defined(CPUCOREI) <> defined(ExpectCore)} {$fatal Wrong Core i macro} {$endif}
{$if defined(CPUX86_HAS_POPCNT) <> defined(ExpectPopCnt)} {$fatal Wrong POPCNT macro} {$endif}
{$if defined(CPUX86_HAS_CMPXCHG16B) <> defined(ExpectV2)} {$fatal Wrong CMPXCHG16B macro} {$endif}
{$if defined(CPUX86_HAS_LAHF_SAHF) <> defined(ExpectV2)} {$fatal Wrong LAHF/SAHF macro} {$endif}
begin end.
PASCAL
cat >"$output/CPUInstructions.pas" <<'PASCAL'
unit CPUInstructions;
{$mode objfpc}
interface
function CountBits(AValue: QWord): LongInt;
implementation
function CountBits(AValue: QWord): LongInt;
begin
  Result := PopCnt(AValue);
end;
end.
PASCAL
for model in DEFAULT ATHLON64 X86-64 X86-64-V1 COREI X86-64-V2; do
    directory="$output/$model"
    mkdir -p "$directory"
    flags=("${options[@]}" "-FU$directory" "-FE$directory")
    if [[ $model != DEFAULT ]]; then flags+=("-Cp$model"); fi
    expected=()
    case "$model" in
        DEFAULT|ATHLON64) expected+=(-dExpectAthlon) ;;
        COREI) expected+=(-dExpectCore -dExpectPopCnt) ;;
        X86-64-V2) expected+=(-dExpectV2 -dExpectPopCnt) ;;
    esac
    "$compiler" "${flags[@]}" "${expected[@]}" "$output/CPUMacros.pas" >"$directory/macros.log" 2>&1
    "$directory/CPUMacros"
    "$compiler" "${flags[@]}" -a -Cn "$output/CPUInstructions.pas" >"$directory/instructions.log" 2>&1
    if grep -Eiq '\bpopcnt[qwl]?\b' "$directory/CPUInstructions.s"; then
        [[ $model == COREI || $model == X86-64-V2 ]]
    else
        [[ $model != COREI && $model != X86-64-V2 ]]
    fi
done
echo 'PASS: six CPU macro, runtime and POPCNT assembly cases'
