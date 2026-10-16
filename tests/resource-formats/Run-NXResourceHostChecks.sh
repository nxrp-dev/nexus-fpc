#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <compiler> <matching-rtl-units> <external-artifact-directory>" >&2
    exit 2
fi
compiler=$(realpath "$1")
rtl_units=$(realpath "$2")
source_root=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$3"
artifact_root=$(realpath "$3")
case "$artifact_root/" in
    "$source_root/"*) echo 'Use an artifact directory outside the source/bundle tree.' >&2; exit 2 ;;
esac
metadata_fixtures="$source_root/tests/resource-formats/fixtures/metadata"
test -f "$metadata_fixtures/versions.tsv"
mkdir -p "$artifact_root/logs"
uname -a >"$artifact_root/host.txt"
"$compiler" -iV >>"$artifact_root/host.txt"
clang --version >>"$artifact_root/host.txt"
for suite in Catalog Inputs Tools Artifacts Metadata FileInfoMetadata Tables; do
    runner="Run-NXResource${suite}Tests.sh"
    if [[ $suite == FileInfoMetadata ]]; then runner=Run-NXFileInfoMetadataTests.sh; fi
    log="$artifact_root/logs/$suite.log"
    if ! bash "$source_root/tests/resource-formats/$runner" \
        "$compiler" "$rtl_units" "$artifact_root/$suite" >"$log" 2>&1; then
        cat "$log" >&2
        echo "FAIL $suite; preserve $artifact_root for analysis." >&2
        exit 1
    fi
    echo "PASS $suite"
done
while IFS=$'\t' read -r name first second; do
    log="$artifact_root/logs/fileinfo-$name.log"
    if ! "$artifact_root/FileInfoMetadata/nxFileInfoMetadataTests" \
        "$metadata_fixtures/$first" "$metadata_fixtures/$second" >"$log" 2>&1; then
        cat "$log" >&2
        exit 1
    fi
    echo "PASS metadata $name"
done <"$metadata_fixtures/versions.tsv"
if [[ -f "$rtl_units/system.nxu" ]]; then
    bash "$source_root/tests/resource-formats/Run-NXResourceIntegrationTests.sh" \
        "$compiler" "$rtl_units" "$artifact_root/Integration" >"$artifact_root/logs/Integration.log" 2>&1
    echo 'PASS Integration'
    if [[ $("$compiler" -iTP) == x86_64 || $("$compiler" -iTP) == i386 ]]; then
        bash "$source_root/tests/resource-formats/Run-NXCRC32WidthTests.sh" \
            "$compiler" "$rtl_units" "$artifact_root/CRC32" >"$artifact_root/logs/CRC32.log" 2>&1
        echo 'PASS CRC32 and string hashing'
    fi
fi
echo "Host checks passed. Return host.txt and logs from $artifact_root."
