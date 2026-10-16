#!/usr/bin/env bash
set -euo pipefail
if [[ $# != 3 ]]; then
    echo "Usage: $0 <integrated-nexus-compiler> <matching-rtl> <external-output>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl=$(realpath "$2")
root=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$3"
out=$(realpath "$3")
case "$out/" in "$root/"*) echo 'Use an external output directory.' >&2; exit 2 ;; esac
mkdir -p "$out/logs" "$out/units" "$out/source/one" "$out/source/two"
cd "$out"
flags=(-n -vi -O2 -Aas-clang -XLL "-Fu$rtl" "-FU$out/units" "-FE$out")
step() {
    local name=$1
    shift
    printf '%q ' "$@" >"$out/logs/$name.command"
    printf '\n' >>"$out/logs/$name.command"
    if ! "$@" >"$out/logs/$name.log" 2>&1; then
        cat "$out/logs/$name.log" >&2
        return 1
    fi
}
reject() {
    local name=$1 pattern=$2
    shift 2
    if "$@" >"$out/logs/$name.log" 2>&1; then
        echo "Unexpected success: $name" >&2
        return 1
    fi
    rg -F "$pattern" "$out/logs/$name.log" >/dev/null
}
expect() {
    local wanted=$1
    shift
    local actual
    actual=$("$@")
    if [[ $actual != "$wanted" ]]; then
        echo "Expected '$wanted', got '$actual'" >&2
        return 1
    fi
}

# Two independent inputs share a basename. Only the owning unit and input index
# determine the distributed artifact name.
printf first >source/one/data.bin
printf other >source/two/data.bin
printf '1 RCDATA "data.bin"\n' >source/one/input.rc
printf '2 RCDATA "data.bin"\n' >source/two/input.rc
cat >source/resunit.pas <<'EOF'
unit ResUnit;
{$mode objfpc}
interface
function UnitValue: Integer;
implementation
{$R one/input.rc}
{$R two/input.rc}
function UnitValue: Integer;
begin Result := 7; end;
end.
EOF
cat >main.pas <<'EOF'
program Main;
{$mode objfpc}{$H+}
uses Classes, SysUtils, ResUnit;
function ReadData(AId: Integer): string;
var lStream: TResourceStream;
begin
  lStream := TResourceStream.CreateFromID(HInstance, AId, PChar(10));
  try
    SetLength(Result, lStream.Size);
    if Result <> '' then lStream.ReadBuffer(Result[1], Length(Result));
  finally lStream.Free; end;
end;
begin WriteLn(UnitValue, ':', ReadData(1), ':', ReadData(2)); end.
EOF
step unit "$compiler" "${flags[@]}" -Ur source/resunit.pas
step first "$compiler" "${flags[@]}" "-Fu$out/units" "-Fu$out/source" main.pas
expect 7:first:other ./main
sha256sum units/resunit.nxu units/resunit.o >unit.sha256
touch -t 202001020304 units/resunit.nxr0.res
old_time=$(stat -c %Y units/resunit.nxr0.res)
step unchanged "$compiler" "${flags[@]}" "-Fu$out/units" "-Fu$out/source" main.pas
test "$old_time" = "$(stat -c %Y units/resunit.nxr0.res)"
printf second >source/one/data.bin
step payload-only "$compiler" "${flags[@]}" "-Fu$out/units" "-Fu$out/source" main.pas
expect 7:second:other ./main
sha256sum --check unit.sha256 >logs/pascal-artifacts-unchanged.log
sha256sum units/resunit.nxr*.res main >published.sha256
rm source/two/data.bin
reject missing-payload 'LLVM resource compilation failed' "$compiler" "${flags[@]}" "-Fu$out/units" "-Fu$out/source" main.pas
sha256sum --check published.sha256 >logs/failed-refresh-preserves-output.log
printf other >source/two/data.bin

# A bad fresh unit must not replace a previously usable unit/resource pair.
cp source/resunit.pas source/resunit.saved
sed 's/begin Result := 7; end;/begin := ; end;/' source/resunit.saved >source/resunit.pas
reject bad-pascal 'Illegal expression' "$compiler" "${flags[@]}" -B source/resunit.pas
sha256sum --check unit.sha256 >logs/failed-unit-preserves-pascal.log
sha256sum --check published.sha256 >logs/failed-unit-preserves-resources.log
mv source/resunit.saved source/resunit.pas

# Source-hidden SDKs consume canonical artifacts beside their NXU, without LLVM
# RC or Clang resource tools. Explicit invalid tool paths prove no invocation.
mv source hidden-source
mv units 'relocated units'
mkdir units
step relocated "$compiler" "${flags[@]}" "-Fu$out/relocated units" \
    --resource-clang=/missing/resource-clang -FC/missing/llvm-rc main.pas
expect 7:second:other ./main
rm 'relocated units/resunit.nxr1.res'
reject missing-artifact 'resunit.nxr1.res' "$compiler" "${flags[@]}" "-Fu$out/relocated units" main.pas

# Direct forms still load through Classes. RES signatures override extensions.
cp "$root/tests/test/units/system/"tres6.{pas,lfm} .
step form "$compiler" "${flags[@]}" tres6.pas
expect Foobar ./tres6
cp "$root/tests/test/units/system/tres4.res" direct.dcr
sed 's/tres4.res/direct.dcr/' "$root/tests/test/units/system/tres4.pas" >tres4.pas
step dcr "$compiler" "${flags[@]}" tres4.pas
step dcr-runtime ./tres4

# Retain the existing language fallback/enumeration assertions and run their RC
# sources through the production preprocessor, catalog and image emitter.
cp "$root/tests/test/units/system/"tres*.txt .
cp "$root/tests/test/units/system/"tres{1,b,5}.rc .
for name in tres tres2 tres3 tres5; do
    sed -e 's/tres1.res/tres1.rc/' -e 's/tresb.res/tresb.rc/' \
        "$root/tests/test/units/system/$name.pas" >"$name.pas"
    step "legacy-$name" "$compiler" "${flags[@]}" "$name.pas"
    step "legacy-runtime-$name" "./$name"
done

# No-link recipes remain usable; resources are already part of the main object.
step no-link "$compiler" "${flags[@]}" -Cn tres6.pas
test -f ppas.sh
step deferred-link bash ./ppas.sh
expect Foobar ./tres6
test ! -f units/tres6.or

cat >empty.pas <<'EOF'
program Empty; begin WriteLn('empty'); end.
EOF
step resource-free "$compiler" "${flags[@]}" empty.pas
expect empty ./empty
for option in -FF -FRold-converter -We; do
    reject "retired-${option:1}" 'retired' "$compiler" "${flags[@]}" "$option" empty.pas
done
echo 'PASS integrated resources: refresh, recovery, relocation, forms, DCR, no-link and retired options'
