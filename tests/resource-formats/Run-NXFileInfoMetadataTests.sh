#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <compiler> <matching-rtl-units> <output-directory>" >&2
    exit 2
fi

compiler=$(realpath "$1")
rtl_units=$(realpath "$2")
source_root=$(cd "$(dirname "$0")/../.." && pwd)
nxtest_source="$source_root/../nexus/packages/nexus-packages/nxtest/src"
if [[ ! -f "$nxtest_source/obNXTestRegistry.pas" ]]; then
    nxtest_source="$source_root/../../nexus/packages/nexus-packages/nxtest/src"
fi

# fcl-res is owned by nexus-packages, outside the compiler source tree.
resource_source=${NEXUS_FCL_RES_SOURCE:-"$source_root/../nexus/packages/nexus-packages/fcl-res/src"}
if [[ -z ${NEXUS_FCL_RES_SOURCE:-} && ! -f "$resource_source/resource.pas" ]]; then
    resource_source="$source_root/../../nexus/packages/nexus-packages/fcl-res/src"
fi
if [[ ! -f "$resource_source/resource.pas" ]]; then
    echo "Relocated fcl-res source not found: $resource_source" >&2
    exit 2
fi
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

run_step compile "$compiler" "-Fu$nxtest_source" -n -O2 \
    "-Fu$rtl_units" "-Fu$resource_source" \
    "-FU$artifact_root/units" "-FE$artifact_root" \
    "-o$artifact_root/nxFileInfoMetadataTests" \
    "$source_root/tests/resource-formats/nxFileInfoMetadataTests.pas"

for fixture in 1 2; do
    if [[ $fixture == 1 ]]; then
        version=1,2,3,4
    else
        version=5,6,7,8
    fi
    cat >"$artifact_root/version$fixture.rc" <<EOF
1 VERSIONINFO
FILEVERSION $version
PRODUCTVERSION $version
FILEFLAGSMASK 0x3f
FILEFLAGS 0
FILEOS 0x40004
FILETYPE 1
FILESUBTYPE 0
BEGIN
END
EOF
    run_step "rc-$fixture" llvm-rc /no-preprocess /FO \
        "$artifact_root/version$fixture.res" "$artifact_root/version$fixture.rc"
done

run_step standard-res "$artifact_root/nxFileInfoMetadataTests" \
    "$artifact_root/version1.res" "$artifact_root/version2.res"

cat >"$artifact_root/entry.c" <<'EOF'
void entry(void) {}
EOF

for target in i386 x86_64 aarch64; do
    case $target in
        i386) triple=i686-pc-windows-msvc; machine=X86 ;;
        x86_64) triple=x86_64-pc-windows-msvc; machine=X64 ;;
        aarch64) triple=aarch64-pc-windows-msvc; machine=ARM64 ;;
    esac
    run_step "entry-$target" clang "--target=$triple" -c -O2 \
        "$artifact_root/entry.c" -o "$artifact_root/$target-entry.obj"
    for fixture in 1 2; do
        run_step "link-$target-$fixture" lld-link "/machine:$machine" \
            /entry:entry /subsystem:console /nodefaultlib /timestamp:0 \
            "$artifact_root/$target-entry.obj" "$artifact_root/version$fixture.res" \
            "/out:$artifact_root/$target-version$fixture.exe"
        run_step "inspect-$target-$fixture" llvm-readobj --file-headers --coff-resources \
            "$artifact_root/$target-version$fixture.exe"
    done
    run_step "pe-$target" "$artifact_root/nxFileInfoMetadataTests" \
        "$artifact_root/$target-version1.exe" "$artifact_root/$target-version2.exe"
done
