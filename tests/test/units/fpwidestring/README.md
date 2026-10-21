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
cp ../nexus-fpc/tests/test/units/fpwidestring/CollationTests.zip ../../worktree/nexus/nexus-fpc-tests/x86_64-linux/collation-data/
../../worktree/nexus/nexus-fpc-tests/x86_64-linux/collation-data/CollationDataTests
```

All **5 tests pass** with range, overflow and I/O checks: both original byte lengths
and CRC32 values, repeated loads, missing member/archive, corrupt input, cleared
partial data and caller ownership after failure. Running in isolated working and
temporary directories leaves **zero files** behind. Source-archive packaging also
preserves the nested fixture ZIP byte for byte and excludes its own checkpoints.

The restored RTL Unicode package now supplies `unicodeducet` from the main
package repository. Its explicit source paths and matching-mode collation build
recipe are in
[`CollationConformance.nxproject`](../../../../../nexus/packages/nexus-packages/rtl-unicode/tests/CollationConformance.nxproject).
All three original programs pass in both ANSI-default and Unicode-default builds:
206,308 non-ignorable lines and 227,819 shifted lines per program, with zero
errors. The fixture ZIP and memory loader remain here in one maintained location.

The conformance and wide-string compiler inputs are also owned by the
[native RTL regression catalog](../../../NXTEST.md).
