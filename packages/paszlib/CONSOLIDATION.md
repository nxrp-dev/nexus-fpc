# PasZLib source consolidation

Owner authorization, 2026-10-17: reconcile the two source trees, retain the
NexusFPC package as the official source for now, and remove the duplicate under
Nexus External Packages.

## Review before removal

Compared all 20 runtime source/include files by logical filename. Seventeen are
byte-identical. The three differences are:

| File | External-only code | Decision |
| --- | --- | --- |
| zconf.inc | DPMI/MSDOS define management. | Keep NexusFPC: those targets are retired. |
| zdeflate.pas | CPUWASM/NOGOTO alternative control flow. | Keep NexusFPC: WebAssembly is outside the Nexus target matrix. Both copies already contain the hash-chain loop advancement. |
| zipper.pas / zipper.pp | OS/2 origin-platform metadata. | Keep NexusFPC: OS/2 is retired. |

The supported target matrix is recorded in NexusFPC.Forge.md. No supported-target
runtime fix needs importing. Runtime filenames stay in NexusFPC's normalized
.pas form. No compatibility branch is restored.

The three retained test programs are equivalent: two are byte-identical and the
third differs only in its comment naming zipper.pas versus zipper.pp. The ZIP
fixture is byte-identical. Nine of ten Lab programs are byte-identical; the last
only rewrites an optional memcheck path to another missing legacy location.
Keep the canonical examples/data/compression/paszlib folder and remove the
paszlib-external duplicate, including its retired Make/Lazarus drivers.

The external COPYING.FPC notice is byte-identical to NexusFPC packages/COPYING.FPC.
The core zlib notices and FPC author/license headers remain in the official
sources; central provenance remains in Nexus ATTRIBUTIONS.md. Baseline hashes
and Git revisions are under ignored Nexus output/paszlib-consolidation.

## Example integration corrections

Compiling the canonical Lab examples proved two old source/API mismatches:
`example.pas` and `minigzip.pas` used Integer for gzerror's SmallInt var parameter;
`miniunz.pas` and `minizip.pas` imported the absent zlib unit even though PasZLib
provides the required API. The examples now use the exact parameter type and
import PasZLib directly. These are example corrections, not runtime-library fixes.
A native Lab build recipe compiles the canonical programs against NexusFPC.

## Proven runtime finding

The checked canonical example2 run fails in zdeflate.fill_window when stored
compression slides its 64 KiB window: match_start is unsigned and remains zero
because stored compression does not find matches, so subtracting w_size raises
ERangeError. Four direct nxtest cases exercise a 192 KiB high-entropy stream at
stored, fast, default and maximum levels. Prove the failure before modifying
runtime code; then retain valid surviving match positions and clear expired
positions consistently with the hash-table slide.

Stored compression also failed before reaching the window code: computing
(level - 1) shr 1 at level zero produces an out-of-range unsigned header hint.
The separate StoredHeader nxtest proves this with a one-byte input. Level zero
now uses the fastest-level hint directly, without shifting a negative value.
The FLEVEL/FCHECK assertions follow
[RFC 1950 section 2.2](https://www.rfc-editor.org/rfc/rfc1950.html#section-2.2).

## Final verification

Native x86_64 Linux with the installed NexusFPC 3.3.1 and Nexus nxbuild. Test
recipes enable range, overflow, I/O and assertion checks; retained-suite builds
use optimization for the deliberately large Zip64 case.

| Check | Result |
| --- | --- |
| Initial source comparison | All 20 runtime/include files matched by logical filename; 17 byte-identical, three target-only differences reconciled above. |
| Retained tests against both original copies | All three programs pass against each tree, including the 65,537-entry Zip64 case. |
| Untouched official source, four large-stream nxtest cases | All four raise ERangeError. The ZIP example separately identifies match_start subtraction in fill_window. |
| After the window fix, isolated stored-header proof | Fast/default/maximum pass; StoredHeader and StoredWindow still raise ERangeError in the level-zero header calculation. |
| Final official source | **5 nxtest cases pass; 0 failures/errors/skips.** |
| Final retained suite | tczstreamseek, testsingle and tczipper all pass, including all enabled large-entry tests. |
| Canonical Lab examples | All 10 programs build with the official source. Memory/gzip examples, stored/default ZIP entry generation, ZIP CLI roundtrip and minigzip roundtrip pass. Python zipfile/gzip independently decode the resulting archives. |
| Affected runtime consumers | FCLImage.nxpackage and FCLDB.nxpackage build with NexusFPC. |
| Catalogs | Machine pool, owned packages and external packages catalogs validate after removal of the duplicate PasZLib entries. |
| Source-path audit | No active source/build/catalog reference points at the deleted external runtime or duplicate Lab folder. |

The earlier 90-second limit was too short for the existing Zip64 test. The
optimized checked run uses a seven-minute ceiling and completes successfully;
the test itself was not removed or weakened. The example prints binary legacy
sync-test output, so the verification harness captures it without assuming UTF-8.
No runtime failure was dismissed as an upstream failure.

Baseline NexusFPC commit: `bfd5d2156b01f1213b3fa16e3b3fde38588c9d5d`.
Baseline External Packages commit: `65229aa52bcd13bce13a1bcea556283c44f24f4e`.
Exact baseline source hashes, source diffs, build logs and before/after results
are under ignored Nexus `output/paszlib-consolidation`. No evidence/source
archive is added to Git.

## Limits

Windows and other target architectures were not executed. No compiler bootstrap
or complete release matrix was rebuilt. The original optional 4 GiB Zip64 test
remains disabled in its source and was not run; the enabled 65,537-entry Zip64
case was run to completion on both baseline trees and the final official tree.


## Private CRC32 and hash-consumer audit, 2026-10-17

The approved hash-consumer audit consolidated the reflected IEEE CRC table/core
from ZStream and Zipper into `src/utNXPasZLibCRC32.pas`. PasZLib, gzio, zip, unzip,
zstream and zipper now use that private implementation. The existing
PasZLib.crc32/get_crc_table signatures remain; retained file comparisons use byte
equality instead of MD5. Runtime, dotted wrappers and tests have no HashLib4Pascal
or legacy hash source dependency. There is still one canonical PasZLib tree.

New independent fixtures proved an existing minizip range-check failure: running
and stored CRC values were signed LongInt. Split reads/writes can set bit 31 even
when the final CRC is below it; a one-byte-NUL stored ZIP has final CRC D202EF8D.
Both fail against the untouched pre-audit source. The CRC fields are now Cardinal;
the existing four-byte header reader's bit pattern is copied into the unsigned
field without a numeric signed conversion. No general-purpose hash is introduced.

Direct nxtest MiniZipInteroperability and MiniZipHighBitCRC cover the proof,
stored/deflated writes, independent ZIP input and corrupted-CRC rejection. The
11-case CRC/window/header/interoperability suite passes under native NexusFPC
3.3.1 and stock FPC 3.2.2, with range/overflow/I/O/assertion checks. Retained
stream-seek, single-entry and 65,537-entry ZIP tests pass. The dotted core probe
passes compression/decompression and the public CRC facade; the full dotted RTL
closure was not built on this host.

The initial audit plan incorrectly referred to password ZIP processing. The
current package rejects encryption and has no password implementation to
preserve; encryption support was not added. The complete audit, unchanged
compiler-build checks and remaining SDK limits are recorded in Nexus
[the implementation review](../../../nexus/work/reviews/hashlib4pascal-package-and-hash-consumer-audit.md).
