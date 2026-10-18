#!/usr/bin/env bash
# Copyright (c) 2026 Kevin Collins.
# SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
set -euo pipefail
if [[ $# != 2 ]]; then
    echo "Usage: $0 <msg2inc-executable> <output-directory>" >&2
    exit 2
fi
tool=$(realpath "$1")
repository=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$2"
output=$(realpath "$2")
checks=0
failures=0
fail() {
    echo "FAIL: $*" >&2
    failures=$((failures + 1))
}

# Exercise the real catalogs, including both Polish encodings and Turkish.
for catalog in "$repository"/compiler/msg/*.msg; do
    name=$(basename "$catalog" .msg)
    directory="$output/$name"
    mkdir -p "$directory"
    if ! "$tool" -S "$catalog" "$directory/messages" msg >"$directory/run.log" 2>&1; then
        fail "$name catalog generation"
    elif [[ ! -s $directory/messagesidx.inc || ! -s $directory/messagestxt.inc ]]; then
        fail "$name generated files"
    fi
    checks=$((checks + 1))
done

# IDs are shared with the English catalog; do not merely pick unused numbers.
for name in errorpl errorpli; do
    for identifier in scan_w_appid_not_support scan_w_appname_not_support scan_e_string_exceeds_255_chars; do
        canonical=$(sed -n "s/^$identifier=\([0-9]*\)_.*/\1/p" "$repository/compiler/msg/errore.msg")
        actual=$(sed -n "s/^$identifier=\([0-9]*\)_.*/\1/p" "$repository/compiler/msg/$name.msg")
        if [[ -z $canonical || $actual != "$canonical" ]]; then
            fail "$name $identifier ID differs from English"
        fi
        checks=$((checks + 1))
    done
done

cat >"$output/input.msg" <<'EOF'
# BeginOfTeX
test=01000_E_Message
# EndOfTeX
EOF
cat >"$output/fragment.expected" <<'EOF'
\index[msgnr]{1000}
\index[msgtxt]{Message}
\item [Error 1000: Message] \hfill \\
EOF
{
    printf '%s\n' '\documentclass{article}' '\usepackage{html}' '\usepackage{fpc}' '\begin{document}'
    cat "$output/fragment.expected"
    printf '%s\n' '\end{document}'
} >"$output/standalone.expected"
for option in T t TS Ts; do
    expected=fragment
    if [[ $option == TS || $option == Ts ]]; then
        expected=standalone
    fi
    if ! "$tool" "-$option" "$output/input.msg" "$output/$option.tex" >"$output/$option.log" 2>&1; then
        fail "-$option execution"
    elif ! cmp -s "$output/$expected.expected" "$output/$option.tex"; then
        fail "-$option TeX content"
    fi
    checks=$((checks + 1))
done

# Also exercise the full documentation input, with and without the wrapper.
for option in T TS; do
    if ! "$tool" "-$option" "$repository/compiler/msg/errore.msg" "$output/english-$option.tex" >"$output/english-$option.log" 2>&1; then
        fail "English -$option execution"
    fi
    checks=$((checks + 1))
done
if [[ -s $output/english-TS.tex && -s $output/english-T.tex ]]; then
    sed '1,4d;$d' "$output/english-TS.tex" >"$output/english-body.tex"
    if ! cmp -s "$output/english-T.tex" "$output/english-body.tex"; then
        fail 'English -T and -TS document bodies differ'
    fi
else
    fail 'English TeX outputs missing'
fi
checks=$((checks + 1))

# Correcting catalog data must not disable duplicate-ID validation.
printf '%s\n' 'first=01000_E_First' 'second=01000_E_Second' >"$output/duplicate.msg"
if "$tool" -S "$output/duplicate.msg" "$output/duplicate" msg >"$output/duplicate.log" 2>&1; then
    fail 'duplicate ID accepted'
elif ! grep -Fq 'duplicate number found' "$output/duplicate.log"; then
    fail 'duplicate ID diagnostic missing'
fi
checks=$((checks + 1))

if [[ $failures != 0 ]]; then
    echo "FAIL: $failures failures in $checks msg2inc checks" >&2
    exit 1
fi
echo "PASS: $checks msg2inc checks"
