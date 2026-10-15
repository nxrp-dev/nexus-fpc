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

build_and_run() {
    local name=$1
    local fixture=$2
    shift 2
    mkdir -p "$output/$name"
    "$compiler" -n -Aas-clang -XLL "-Fu$rtl_units" "-FU$output/$name" \
        "-o$output/$name/check" "$@" "$test_dir/$fixture" \
        >"$output/$name/build.log" 2>&1
    "$output/$name/check"
}

expect_disabled() {
    local name=$1
    local fixture=$2
    shift 2
    mkdir -p "$output/$name"
    if "$compiler" -n -Aas-clang -XLL "-Fu$rtl_units" "-FU$output/$name" \
        "-o$output/$name/check" "$@" "$test_dir/$fixture" \
        >"$output/$name/build.log" 2>&1; then
        echo "C-style assignment unexpectedly accepted: $name" >&2
        exit 1
    fi
    rg -F 'C styled assignment operators are turned off' "$output/$name/build.log" >/dev/null
}

build_and_run default coperators_default.pas
for mode in fpc objfpc delphi macpas iso extendedpascal; do
    build_and_run "mode-$mode" coperators_default.pas "-M$mode"
done
expect_disabled command-off coperators_default.pas -Sc-
expect_disabled directive-off coperators_directives.pas -dDisableCOperators
expect_disabled directive-off-overrides-command coperators_directives.pas -Sc -dDisableCOperators
build_and_run directive-on-overrides-command coperators_directives.pas -Sc- -dEnableCOperators
expect_disabled last-directive-wins coperators_directives.pas -dEnableCOperators -dDisableCOperators
echo 'PASS: C-style assignments default on in all retained modes; explicit command and source overrides work'
