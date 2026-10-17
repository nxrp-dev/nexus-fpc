# PasZLib verification

Use NexusFPC and Nexus nxbuild with `PasZLibTests.nxproject`.
Build output is Nexus `output/PasZLibTests/<native-target>`.

- `NXPasZLibTests` runs five direct nxtest regressions covering stored zlib
  headers and 192 KiB stream roundtrips at stored, fast, default and maximum
  compression levels.
- `tczstreamseek` checks decompression seek/position semantics.
- `testsingle` extracts one member from `test.zip`.
- `tczipper` runs its retained ZIP and Zip64 suite, including 65,537 entries.
  Allow several minutes for that intentionally large case. Its optional 4 GiB
  case remains disabled in the original source.

Run the retained programs in a disposable working directory containing the
checked-in `test.zip`; direct temporary files there as well. They deliberately
write test archives/files. Assertions and runtime checks are enabled by the
native recipe. No FPCUnit framework or bridge is used.

See [reconciliation and verified results](../CONSOLIDATION.md).
