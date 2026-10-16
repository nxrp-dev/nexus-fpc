#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <compiler> <matching-rtl-units> <external-artifact-directory>" >&2
    exit 2
fi
compiler=$1
rtl_units=$2
artifact_root=$3
source_root=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$artifact_root/units" "$artifact_root/logs"
if ! "$compiler" -n -O2 -Cr -Co -Ci "-Fu$rtl_units" "-Fu$source_root/compiler" \
    "-FU$artifact_root/units" "-o$artifact_root/nxResourceMetadataTests" \
    "$source_root/tests/resource-formats/nxResourceMetadataTests.pas" \
    >"$artifact_root/logs/compile.log" 2>&1; then
    cat "$artifact_root/logs/compile.log" >&2
    exit 1
fi
"$artifact_root/nxResourceMetadataTests" "$artifact_root/metadata.bin" \
    | tee "$artifact_root/logs/tests.log"
