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

run_step compile "$compiler" -n -O2 -Cr -Co -Ci \
    "-Fu$rtl_units" "-Fu$source_root/compiler" \
    "-FU$artifact_root/units" "-FE$artifact_root" \
    "-o$artifact_root/nxResourceCatalogTests" \
    "$source_root/tests/resource-formats/nxResourceCatalogTests.pas"

printf 'Nexus resource payload\000\377' >"$artifact_root/payload.bin"
cat >"$artifact_root/first.rc" <<'EOF'
LANGUAGE 9, 1
101 RCDATA "payload.bin"
STRINGTABLE
BEGIN
  1 "Alpha"
END
EOF
cat >"$artifact_root/second.rc" <<'EOF'
LANGUAGE 9, 1
102 RCDATA "payload.bin"
STRINGTABLE
BEGIN
  2 "Beta"
END
EOF

for fixture in first second; do
    run_step "$fixture-rc" llvm-rc /no-preprocess /I "$artifact_root" \
        /FO "$artifact_root/$fixture.res" "$artifact_root/$fixture.rc"
done

# One-pixel 32-bit DIB images, shared by standard ICO/CUR file containers.
for color in red green; do
    dib="$artifact_root/$color.dib"
    printf '\050\000\000\000\001\000\000\000\002\000\000\000\001\000\040\000' >"$dib"
    printf '\000\000\000\000\010\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000' >>"$dib"
    if [[ $color == red ]]; then
        printf '\000\000\377\377\000\000\000\000' >>"$dib"
    else
        printf '\000\377\000\377\000\000\000\000' >>"$dib"
    fi
    printf '\000\000\001\000\001\000\001\001\000\000\001\000\040\000\060\000\000\000\026\000\000\000' >"$artifact_root/$color.ico"
    printf '\000\000\002\000\001\000\001\001\000\000\000\000\000\000\060\000\000\000\026\000\000\000' >"$artifact_root/$color.cur"
    cat "$dib" >>"$artifact_root/$color.ico"
    cat "$dib" >>"$artifact_root/$color.cur"
done
for fixture in first second; do
    if [[ $fixture == first ]]; then
        color=red
        icon_id=201
        cursor_id=301
    else
        color=green
        icon_id=202
        cursor_id=302
    fi
    cat >"$artifact_root/$fixture-images.rc" <<EOF
LANGUAGE 9, 1
$icon_id ICON "$color.ico"
$cursor_id CURSOR "$color.cur"
EOF
    run_step "$fixture-images-rc" llvm-rc /no-preprocess /I "$artifact_root" \
        /FO "$artifact_root/$fixture-images.res" "$artifact_root/$fixture-images.rc"
done
run_step catalog "$artifact_root/nxResourceCatalogTests" \
    "$artifact_root/first.res" "$artifact_root/second.res" "$artifact_root/merged.res" \
    "$source_root/tests/test/units/system/tres4.res" \
    "$artifact_root/first-images.res" "$artifact_root/second-images.res"
cat "$artifact_root/logs/catalog.log"
for machine in X86 X64 ARM64; do
    run_step "coff-$machine" llvm-cvtres "/MACHINE:$machine" /TIMESTAMP:0 \
        "/OUT:$artifact_root/merged-$machine.obj" "$artifact_root/merged.res"
    run_step "inspect-$machine" llvm-readobj --file-headers --coff-resources \
        "$artifact_root/merged-$machine.obj"
    run_step "images-coff-$machine" llvm-cvtres "/MACHINE:$machine" /TIMESTAMP:0 \
        "/OUT:$artifact_root/merged-images-$machine.obj" "$artifact_root/merged.images.res"
done
