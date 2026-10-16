#!/usr/bin/env bash
set -euo pipefail
if [[ $# != 2 ]]; then
    echo "Usage: $0 <rstconv> <output-directory>" >&2
    exit 2
fi
converter=$(realpath "$1")
mkdir -p "$2"
output=$(realpath "$2")
cd "$output"
cat >fixture.rst <<'RST'
Sample.Greeting='Hello'
Sample.Multiline='A'#10'B'
Sample.Accent='Caf'#195#169
RST
cat >fixture.rsj <<'RSJ'
{"version":1,"strings":[
{"name":"Sample.Greeting","sourcebytes":[72,101,108,108,111],"value":"Hello"},
{"name":"Sample.Multiline","sourcebytes":[65,10,66],"value":"A\nB"},
{"name":"Sample.Accent","sourcebytes":[67,97,102,195,169],"value":"Caf\u00e9"}
]}
RSJ
if "$converter" -i fixture.rsj -o retired.msg -f msg -c ABC >retired-msg.log 2>&1; then
    echo 'Retired OS/2 MSG output unexpectedly accepted' >&2
    exit 1
fi
grep -F 'Invalid output format -msg' retired-msg.log >/dev/null
test ! -e retired.msg
if "$converter" -i fixture.rsj -o retired-s.rc -f rc -s >retired-s.log 2>&1; then
    echo 'Retired table selector unexpectedly accepted' >&2
    exit 1
fi
grep -F 'Invalid option - -s' retired-s.log >/dev/null
test ! -e retired-s.rc
"$converter" --help >help.log
if grep -Ei 'OS/2|MESSAGETABLE|MSG file' help.log; then
    echo 'Help still advertises OS/2 output' >&2
    exit 1
fi
for input in rst rsj; do
    "$converter" -i "fixture.$input" -o "$input.po" >"$input-po.log" 2>&1
    grep -F 'msgid "Hello"' "$input.po" >/dev/null
    grep -F 'msgstr ""' "$input.po" >/dev/null
    "$converter" -i "fixture.$input" -o "$input.rc" -f rc -n 32 >"$input-rc.log" 2>&1
    grep -Fx 'STRINGTABLE' "$input.rc" >/dev/null
    grep -F '32 "Hello"' "$input.rc" >/dev/null
done
cmp rst.po rsj.po
cmp rst.rc rsj.rc
"$converter" -i fixture.rsj -o utf8.po -p UTF-8 -c UTF-8 >utf8.log 2>&1
grep -F 'charset=UTF-8' utf8.po >/dev/null
"$converter" -i fixture.rsj -o cp1252.po -p cp1252 >cp1252.log 2>&1
grep -F 'Caf\351' cp1252.po >/dev/null
printf "Sample.Greeting='Hello'\n" >ascii.rst
"$converter" -i ascii.rst -o ascii.rc -f rc >ascii-rc.log 2>&1
llvm-rc /FO ascii.res ascii.rc >ascii-compile.log 2>&1
"$converter" -i fixture.rsj -o cp1252.rc -f rc -p cp1252 -n 32 >cp1252-rc.log 2>&1
grep -F 'Caf\351' cp1252.rc >/dev/null
llvm-rc /C1252 /FO cp1252.res cp1252.rc >cp1252-compile.log 2>&1
echo 'PASS: OS/2 output rejected; RST/RSJ conversion, PO, STRINGTABLE and code pages retained'
