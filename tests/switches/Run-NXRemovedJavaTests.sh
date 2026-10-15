#!/usr/bin/env bash
set -euo pipefail
if [[ $# != 3 ]]; then
    echo "Usage: $0 <native-compiler> <rtl-units> <output-directory>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl_units=$(realpath "$2")
mkdir -p "$3"
output=$(realpath "$3")
test_dir=$(cd "$(dirname "$0")" && pwd)
for option in -CTautogetterprefix=Get -CTautosetterprefix=Set -CTlowercaseprocstart; do
    log="$output/rejected-${option#-}.log"
    if "$compiler" -n -Aas-clang -XLL "$option" "-Fu$rtl_units" \
        "-FU$output" "-FE$output" "$test_dir/removed_legacy_options_baseline.pas" >"$log" 2>&1; then
        echo "Retired Java option unexpectedly accepted: $option" >&2
        exit 1
    fi
    grep -F 'Illegal parameter:' "$log" >/dev/null
done
"$compiler" -n -Aas-clang -XLL -CTcld "-Fu$rtl_units" "-FU$output" \
    "-o$output/retained-native" "$test_dir/../compiler-regressions/removed_java_native.pas" \
    >"$output/retained-native.log" 2>&1
"$output/retained-native"
printf 'program RetiredNamespace; {$namespace Retired.Java} begin end.\n' >"$output/retired_namespace.pas"
if "$compiler" -n -Aas-clang -XLL -Sew "-Fu$rtl_units" "-FU$output" \
    "-FE$output" "$output/retired_namespace.pas" >"$output/namespace.log" 2>&1; then
    echo 'Retired Java namespace directive unexpectedly accepted' >&2
    exit 1
fi
grep -F 'Illegal compiler directive' "$output/namespace.log" >/dev/null
echo 'PASS: Java switches and namespace directive rejected; native class behavior retained'
