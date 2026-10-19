#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 7 ]]; then
    echo "Usage: $0 <compiler> <matching-rtl> <target-cpu> <matching-compiler-units> <compiler-includes> <table-fixture.res> <artifact-directory>" >&2
    exit 2
fi
compiler=$1
rtl_units=$2
target_cpu=$3
compiler_units=$4
compiler_includes=$5
fixture=$6
artifact_root=$7
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
mkdir -p "$artifact_root/units" "$artifact_root/source" "$artifact_root/logs"
artifact_root=$(cd "$artifact_root" && pwd)

run_step() {
    local name=$1
    shift
    if ! "$@" >"$artifact_root/logs/$name.log" 2>&1; then
        cat "$artifact_root/logs/$name.log" >&2
        return 1
    fi
}

# Dependencies must come from the same compiler/RTL/target closure. Copy only
# the new units so source lookup cannot rebuild arbitrary compiler dependencies
# using a mixture of target CPU definitions or cached unit generations.
for unit in resourcecatalog resourcetables resourceemit; do
    cp "$source_root/compiler/$unit.pas" "$artifact_root/source/"
done
compiler_flags=()
if [[ -f "$compiler_units/globtype.nxu" ]]; then
    compiler_flags=(-Aas-clang -XLL)
fi
run_step compile "$compiler" "-Fu$nxtest_source" -n -O2 -Cr -Co -Ci "${compiler_flags[@]}" \
    "-d$target_cpu" -dREVINC -dRELEASE \
    "-Fu$rtl_units" "-Fu$compiler_units" "-Fu$artifact_root/source" \
    "-Fi$compiler_includes" "-FU$artifact_root/units" \
    "-o$artifact_root/nxCompilerResourceEmitTests" \
    "$source_root/tests/resource-formats/nxCompilerResourceEmitTests.pas"

case $target_cpu in
    i386)
        targets=(linux)
        triples=(i386-unknown-linux-gnu)
        ;;
    x86_64)
        targets=(linux android darwin iphonesim)
        triples=(x86_64-unknown-linux-gnu x86_64-unknown-linux-android24 \
            x86_64-apple-macosx11.0 x86_64-apple-ios14.0-simulator)
        ;;
    aarch64)
        targets=(linux android darwin iphonesim ios)
        triples=(aarch64-unknown-linux-gnu aarch64-unknown-linux-android24 \
            arm64-apple-macosx11.0 arm64-apple-ios14.0-simulator arm64-apple-ios14.0)
        ;;
    *) echo "Unsupported target CPU: $target_cpu" >&2; exit 2 ;;
esac
objects=()
images=()
for index in "${!targets[@]}"; do
    target=${targets[$index]}
    object="$artifact_root/$target.o"
    image="$artifact_root/$target.image"
    run_step "emit-$target" "$artifact_root/nxCompilerResourceEmitTests" \
        "$target" "$fixture" "$artifact_root/$target.s"
    run_step "assemble-$target" clang "--target=${triples[$index]}" \
        -c -x assembler "$artifact_root/$target.s" -o "$object"
    run_step "inspect-$target" llvm-readobj --sections --symbols --relocations "$object"
    case $target in
        linux|android)
            run_step "link-$target" ld.lld -shared --gc-sections -z relro -z now \
                -o "$image" "$object"
            objects+=("$object")
            ;;
        *)
            case $target in
                darwin) platform=macos; version=11.0 ;;
                iphonesim) platform=ios-simulator; version=14.0 ;;
                ios) platform=ios; version=14.0 ;;
            esac
            arch=$target_cpu
            if [[ $arch == aarch64 ]]; then arch=arm64; fi
            run_step "link-$target" ld.lld -flavor darwin -dylib -arch "$arch" \
                -platform_version "$platform" "$version" "$version" -dead_strip \
                -o "$image" "$object"
            ;;
    esac
    images+=("$image")
    cat "$artifact_root/logs/emit-$target.log"
done
run_step compile-reader "$compiler" "-Fu$nxtest_source" -n -O2 -Cr -Co -Ci "${compiler_flags[@]}" \
    "-Fu$rtl_units" "-Fu$artifact_root/source" "-Fu$resource_source" \
    "-FU$artifact_root/units" "-o$artifact_root/nxResourceTableReaderTests" \
    "$source_root/tests/resource-formats/nxResourceTableReaderTests.pas"
run_step readers "$artifact_root/nxResourceTableReaderTests" "$fixture" \
    "${objects[@]}" "${images[@]}"
cat "$artifact_root/logs/readers.log"
