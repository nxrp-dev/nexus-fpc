#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <compiler> <matching-rtl-units> <output-directory>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl_units=$(realpath "$2")
source_root=$(cd "$(dirname "$0")/../.." && pwd)
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

run_step compile "$compiler" -n -O2 -Cr -Co -Ci \
    "-Fu$rtl_units" "-Fu$source_root/compiler" \
    "-FU$artifact_root/units" "-FE$artifact_root" \
    "-o$artifact_root/nxResourceTablesTests" \
    "$source_root/tests/resource-formats/nxResourceTablesTests.pas"
for version_index in 1 2; do
    if [[ $version_index -eq 1 ]]; then file_version=1,2,3,4
    else file_version=5,6,7,8
    fi
    cat >"$artifact_root/version$version_index.rc" <<EOF
1 VERSIONINFO
FILEVERSION $file_version
PRODUCTVERSION $file_version
FILEFLAGSMASK 0x3f
FILEFLAGS 0
FILEOS 0x40004
FILETYPE 1
FILESUBTYPE 0
BEGIN
END
EOF
    run_step "version-rc-$version_index" llvm-rc /no-preprocess /C 65001 \
        /FO "$artifact_root/version$version_index.res" "$artifact_root/version$version_index.rc"
done
run_step tables "$artifact_root/nxResourceTablesTests" "$artifact_root" "$artifact_root/version1.res"
cat "$artifact_root/logs/tables.log"

triples=(
    i386-unknown-linux-gnu x86_64-unknown-linux-gnu aarch64-unknown-linux-gnu
    x86_64-unknown-linux-android24 aarch64-unknown-linux-android24
    x86_64-apple-macosx11.0 arm64-apple-macosx11.0
    x86_64-apple-ios14.0-simulator arm64-apple-ios14.0-simulator arm64-apple-ios14.0
)
for index in "${!triples[@]}"; do
    if [[ $index -eq 0 ]]; then layout=elf32
    elif [[ $index -lt 5 ]]; then layout=elf64
    else layout=macho64
    fi
    run_step "object-$index" clang "--target=${triples[$index]}" \
        -c -x assembler "$artifact_root/$layout/tables.s" -o "$artifact_root/target-$index.o"
    run_step "inspect-$index" llvm-readobj --sections --symbols --relocations \
        "$artifact_root/target-$index.o"
done

run_step compile-reader "$compiler" -n -O2 -Cr -Co -Ci \
    "-Fu$rtl_units" "-Fu$source_root/compiler" "-Fu$resource_source" \
    "-FU$artifact_root/units" "-FE$artifact_root" \
    "-o$artifact_root/nxResourceTableReaderTests" \
    "$source_root/tests/resource-formats/nxResourceTableReaderTests.pas"
objects=()
images=()
for index in "${!triples[@]}"; do
    if [[ $index -lt 5 ]]; then
        objects+=("$artifact_root/target-$index.o")
        image="$artifact_root/target-$index.so"
        run_step "link-$index" ld.lld -shared --gc-sections -z relro -z now \
            -o "$image" "$artifact_root/target-$index.o"
    else
        # The Mach-O reader expects resolved pointers; it does not apply LLVM
        # external-symbol relocations in raw .o files. Validate linked images.
        image="$artifact_root/target-$index.dylib"
        case $index in
            5) arch=x86_64; platform=macos; version=11.0 ;;
            6) arch=arm64; platform=macos; version=11.0 ;;
            7) arch=x86_64; platform=ios-simulator; version=14.0 ;;
            8) arch=arm64; platform=ios-simulator; version=14.0 ;;
            9) arch=arm64; platform=ios; version=14.0 ;;
        esac
        run_step "link-$index" ld.lld -flavor darwin -dylib -arch "$arch" \
            -platform_version "$platform" "$version" "$version" -dead_strip \
            -o "$image" "$artifact_root/target-$index.o"
    fi
    images+=("$image")
done
run_step readers "$artifact_root/nxResourceTableReaderTests" "$artifact_root/tables.res" \
    "${objects[@]}" "${images[@]}"
cat "$artifact_root/logs/readers.log"

run_step compile-fileinfo "$compiler" -n -O2 -Cr -Co -Ci \
    "-Fu$rtl_units" "-Fu$resource_source" \
    "-FU$artifact_root/units" "-FE$artifact_root" \
    "-o$artifact_root/nxFileInfoMetadataTests" \
    "$source_root/tests/resource-formats/nxFileInfoMetadataTests.pas"
mkdir -p "$artifact_root/version2" "$artifact_root/version1-images" "$artifact_root/version2-images"
run_step tables-version2 "$artifact_root/nxResourceTablesTests" \
    "$artifact_root/version2" "$artifact_root/version2.res"
for index in "${!triples[@]}"; do
    if [[ $index -eq 0 ]]; then layout=elf32
    elif [[ $index -lt 5 ]]; then layout=elf64
    else layout=macho64
    fi
    object="$artifact_root/version2/target-$index.o"
    image="$artifact_root/version2-images/target-$index"
    run_step "version2-object-$index" clang "--target=${triples[$index]}" \
        -c -x assembler "$artifact_root/version2/$layout/tables.s" -o "$object"
    if [[ $index -lt 5 ]]; then
        run_step "version2-link-$index" ld.lld -shared --gc-sections -z relro -z now \
            -o "$image" "$object"
    else
        case $index in
            5) arch=x86_64; platform=macos; version=11.0 ;;
            6) arch=arm64; platform=macos; version=11.0 ;;
            7) arch=x86_64; platform=ios-simulator; version=14.0 ;;
            8) arch=arm64; platform=ios-simulator; version=14.0 ;;
            9) arch=arm64; platform=ios; version=14.0 ;;
        esac
        run_step "version2-link-$index" ld.lld -flavor darwin -dylib -arch "$arch" \
            -platform_version "$platform" "$version" "$version" -dead_strip \
            -o "$image" "$object"
    fi
    # FileInfo's Unix executable reader is registered for extensionless names;
    # the stream-level reader checks above are independent of filename suffix.
    cp "${images[$index]}" "$artifact_root/version1-images/target-$index"
    run_step "fileinfo-$index" "$artifact_root/nxFileInfoMetadataTests" \
        "$artifact_root/version1-images/target-$index" "$image"
done
