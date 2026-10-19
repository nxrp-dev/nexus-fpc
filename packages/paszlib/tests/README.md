# PasZLib native tests

Build `PasZLibTests.nxproject` with Nexus nxbuild and a matching NexusFPC/RTL.
Run `NXPasZLibTests` from its output directory under the configured
`Tools.OutputRoot/nexus-fpc-tests/<target>/paszlib`.

Native suites own compression streams/seeking, gzip, shared CRC32 and archives.
The former `tczipper`, `tczstreamseek` and `testsingle` programs are consolidated
into `tsNXArchiveTests`: file/content roundtrips, stream/empty entries, the
65,537-entry Zip64 boundary, long/platform filenames, save-to-file, selected
member extraction and invalid seeks. Fixtures create their own inputs and clean
up streams and temporary files; no checked-in ZIP needs staging.

The 4 GiB case is reported as skipped unless `NXTEST_LARGE_ZIP=1` is set.
`ReadOnlyGzipTests.nxproject` retains a separate `NO_DEFLATE` compilation and native
reader/rejected-writer case.

See [the suite catalog](../../../tests/NXTEST.md),
[consolidation decisions](../../../tests/NXTEST.md#consolidation-decisions) and
[recorded package verification](../CONSOLIDATION.md).
