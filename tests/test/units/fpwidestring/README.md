# Unicode collation test data

`CollationTests.zip` contains the two original Unicode 17.0 collation inputs,
unchanged, including their copyright and license notices. The loose text copies
have been removed. The archive is 1,082,862 bytes; its members total 4,727,841 bytes.
See the [central attribution record](../../../../../nexus/ATTRIBUTIONS.md#unicode-collation-conformance-data)
for provenance, license and original SHA-256 values.

`tuca1`, `tuca2` and `tucawsm` load one member at a time directly into their existing
memory stream through `utNXCollationData`. The existing `finally` blocks free that
stream. No extracted text files or temporary directories are created. Each program's
`%FILES` directive stages the ZIP and loader beside the test; PasZLib must be available
on its unit path.

The focused direct nxtest suite builds independently of the collation provider.
From Nexus on native Linux:

```sh
output/nxbuild-next/x86_64-linux/nxbuild /action=build /project=../nexus-fpc/tests/test/units/fpwidestring/CollationDataTests.nxproject
cp ../nexus-fpc/tests/test/units/fpwidestring/CollationTests.zip output/CollationDataTests/x86_64-linux/
output/CollationDataTests/x86_64-linux/CollationDataTests
```

All **5 tests pass** with range, overflow and I/O checks: both original byte lengths
and CRC32 values, repeated loads, missing member/archive, corrupt input, cleared
partial data and caller ownership after failure. Running in isolated working and
temporary directories leaves **zero files** behind. Source-archive packaging also
preserves the nested fixture ZIP byte for byte and excludes its own checkpoints.

The original three collation programs already fail to compile because `unicodeducet`
is absent. It belonged to `packages/rtl-unicode`, removed in NexusFPC commit
`334e806fea1b1ee4cd89d6ccf4ac8a74e19cb83c`. The unchanged `tuca1` was compiled
before this edit and failed at that missing unit. This storage change does not
restore the retired provider or claim a collation algorithm test run.
