#!/usr/bin/env bash
set -euo pipefail
if [[ $# != 2 ]]; then
    echo "Usage: $0 <fpcres> <output-directory>" >&2
    exit 2
fi
converter=$(realpath "$1")
mkdir -p "$2"
output=$(realpath "$2")
printf 'Nexus resource payload\n' >"$output/data.bin"
printf '1 RCDATA "data.bin"\n' >"$output/fixture.rc"
cd "$output"
"$converter" -of res -o fixture.res fixture.rc >res.log 2>&1
if "$converter" -of xcoff -a powerpc -o retired.o fixture.res >rejected.log 2>&1; then
    echo 'Retired XCOFF output unexpectedly accepted' >&2
    exit 1
fi
grep -F 'Unknown file format' rejected.log >/dev/null
for format in elf coff mach-o; do
    for arch in i386 x86_64 aarch64; do
        "$converter" -of "$format" -a "$arch" -o "$format-$arch.o" fixture.res \
            >"$format-$arch.log" 2>&1
        llvm-readobj --file-headers "$format-$arch.o" >"$format-$arch.headers"
        test -s "$format-$arch.o"
    done
done
for arch in littleendian bigendian; do
    "$converter" -of external -a "$arch" -o "$arch.fpcres" fixture.res >"$arch.log" 2>&1
    test -s "$arch.fpcres"
done
echo 'PASS: XCOFF rejected; retained resource formats produce readable objects'
