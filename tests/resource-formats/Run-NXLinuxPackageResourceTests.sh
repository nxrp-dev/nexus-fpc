#!/usr/bin/env bash
set -euo pipefail
if [[ $# != 3 ]]; then
    echo "Usage: $0 <linux-x86_64-nexus-compiler> <matching-PIC-rtl> <external-output>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl=$(realpath "$2")
root=$(cd "$(dirname "$0")/../.." && pwd)
nxtest_source="$root/../nexus/packages/nexus-packages/nxtest/src"
if [[ ! -f "$nxtest_source/obNXTestRegistry.pas" ]]; then
    nxtest_source="$root/../../nexus/packages/nexus-packages/nxtest/src"
fi

# fcl-res is owned by nexus-packages, outside the compiler source tree.
resource_source=${NEXUS_FCL_RES_SOURCE:-"$root/../nexus/packages/nexus-packages/fcl-res/src"}
if [[ -z ${NEXUS_FCL_RES_SOURCE:-} && ! -f "$resource_source/resource.pas" ]]; then
    resource_source="$root/../../nexus/packages/nexus-packages/fcl-res/src"
fi
if [[ ! -f "$resource_source/resource.pas" ]]; then
    echo "Relocated fcl-res source not found: $resource_source" >&2
    exit 2
fi
mkdir -p "$3"
out=$(realpath "$3")
case "$out/" in "$root/"*) echo 'Use an external output directory.' >&2; exit 2 ;; esac
mkdir -p "$out/"{foundation,provider,consumer,packages,reader,logs}
step() {
    local name=$1
    shift
    if ! "$@" >"$out/logs/$name.log" 2>&1; then
        cat "$out/logs/$name.log" >&2
        return 1
    fi
}
flags=(-n -vi -O2 -Cg -Aas-clang -XLL "-Fu$rtl")
cp "$root/rtl/linux/nxrtl.nxpk" "$out/foundation/"
cd "$out/foundation"
step foundation "$compiler" "${flags[@]}" "-Fu$root/rtl/inc" \
    "-FU$out/foundation" "-FE$out/foundation" nxrtl.nxpk
cp nxrtl.nxpl "$out/packages/"
cat >"$out/provider/providerunit.pas" <<'EOF'
unit ProviderUnit;
{$mode objfpc}
interface
function ProviderValue: LongInt;
implementation
{$R data.rc}
function ProviderValue: LongInt; begin Result := 901; end;
end.
EOF
printf '101 RCDATA BEGIN 901 END\n' >"$out/provider/data.rc"
printf 'package Provider; requires nxrtl; contains ProviderUnit; end.\n' >"$out/provider/provider.nxpk"
flags+=("-Fp$out/packages" "-Fl$out/packages")
cd "$out/provider"
step provider "$compiler" "${flags[@]}" "-FU$out/provider" "-FE$out/provider" provider.nxpk
cp Provider.nxpl "$out/packages/"
cp providerunit.nxr0.res "$out/expected.res"
for filename in providerunit.pas providerunit.nxu providerunit.o providerunit.nxr0.res data.rc; do
    if [[ -f $filename ]]; then mv "$filename" "$filename.hidden"; fi
done
cat >"$out/consumer/consumerunit.pas" <<'EOF'
unit ConsumerUnit;
{$mode objfpc}
interface
uses ProviderUnit;
function ConsumerValue: LongInt;
implementation
function ConsumerValue: LongInt; begin Result := ProviderValue; end;
end.
EOF
printf 'package Consumer; requires Provider; contains ConsumerUnit; end.\n' >"$out/consumer/consumer.nxpk"
cd "$out/consumer"
step consumer "$compiler" "${flags[@]}" "-FU$out/consumer" "-FE$out/consumer" consumer.nxpk
step reader-compile "$compiler" "-Fu$nxtest_source" -n -O2 -Aas-clang -XLL "-Fu$rtl" \
    "-Fu$root/compiler" "-Fu$resource_source" "-FU$out/reader" "-FE$out/reader" \
    "$root/tests/resource-formats/nxResourceTableReaderTests.pas"
step provider-resources "$out/reader/nxResourceTableReaderTests" \
    "$out/expected.res" "$out/packages/Provider.nxpl"
step consumer-inspection llvm-readobj --sections --symbols --needed-libs Consumer.nxpl
if rg 'Name: (FPC_RESSYMBOL|fpc.resources)( |$)' "$out/logs/consumer-inspection.log"; then
    echo 'Imported provider resources leaked into the consumer image.' >&2
    exit 1
fi
echo 'PASS exact NXPL links and source-hidden provider resource ownership'
