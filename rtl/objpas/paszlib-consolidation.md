# PasZLib and shared CRC32 consolidation

Owner authorization: 2026-10-18. Keep two authoritative PasZLib units directly
in this directory and share CRC32 with the compiler in a third unit. Maintain
stock FPC 3.2.2. Bootstrap source-location/mask updates only were approved;
additional stages, switches or other bootstrap corrections require discussion.

## Source review before changes

The previous `packages/paszlib/src` contained 21 source/include files totaling
17,439 lines (534,396 bytes). `PasZLib` was a facade over split algorithm units;
gzip, compressed streams and ZIP implementations were distributed among six
additional units. The compiler's metadata codec used ZBase/ZCompres/ZInflate.
FPCHash maintained a separately generated IEEE CRC32 table; compression already
shared a static table in utNXPasZLibCRC32. Both use polynomial $EDB88320 and
complement the accumulator before and after block updates.

Original source, notices, tests, per-file SHA256 hashes, starting revision and
consumer snapshots are retained in the isolated development worktree recorded
in the validation report. The original notices remain in the authoritative
units. Upstream authors and license history are in Nexus ATTRIBUTIONS.md.

## Resulting ownership

`paszlib.pas` owns in-memory compression and decompression. Former cross-unit
Huffman/inflate helper declarations are private implementation declarations.
`paszlibio.pas` owns gzip, streams, low-level ZIP APIs and TZipper/TUnZipper.
`crc32.pas` owns one static CRC32 table and its update operations. FPCHash keeps
its FNV64 and name mangling functions. Compiler callers import CRC32 directly.

Algorithm bodies are retained, with scope-conflict names disambiguated during
consolidation: TreePos, TreeMinLookahead, GZipBufferSize, ZipOffset and the
ZipSeek* enum values. The formerly conflicting gzip and ZIP offset types retain
their original widths. The zlib CRC facade keeps its special nil-buffer rule;
the common update API preserves the compiler's empty/negative-count behavior.
No compatibility units, extra runtime dependencies or threads are added.

The retained NO_DEFLATE switch exposed a merge issue: TGZFileStream.Write
referenced the excluded gzip writer. Its call now uses the same conditional.
The read-only regression then exposed original early-failure cleanup of an
unopened file record. By separate owner approval, gzopen now initializes its
compression-state pointer and records whether file opening succeeded; destroy
closes only a file it owns. A candidate passed in isolation before application.
Rejected-open and read-only gzip nxtest regressions retain this coverage.

The new units are authoritative source, not generated from the retired units.
The one-time transformation and original sources are retained only as review
evidence outside the source tree. Regeneration of RTL dotted wrappers uses
`rtl/namespaces.lst`, which now owns all three origins.

## Validation

Evidence: `/media/kcollins/dev/worktree/paszlib-rtl-v6l4sbcx`. The untouched package, per-file hashes, consumer originals,
commands, successful and failed diagnostic logs, isolated cleanup candidate,
and final source hashes are retained there. No output was written into source.

- Stock FPC 3.2.2 seed, normal three-generation bootstrap: generations 2/3
  identical and all 89 RTL objects identical. The compiler closure is unchanged
  by the subsequent I/O-only cleanup correction.
- All 13 supported target RTL builds passed. All three new objects were checked
  for ELF/COFF/Mach-O machine identity; the final I/O source was rebuilt for all
  13 targets after the approved correction.
- Direct compression/CRC suite: 13 passed on native x86-64, native i386 and
  stock 3.2.2. Read-only gzip regression: 1 passed with NexusFPC and stock 3.2.2.
  The retained ZLIB_DEBUG branch also compiles.
- CRC: 132 vectors match the unchanged compiler and Python zlib. All 24 valid
  metadata envelopes are byte-identical. The shared table is one 1,024-byte
  definition in CRC32; compiler hashing and PasZLib do not define duplicates.
- Untouched and consolidated retained stream/ZIP suites pass, including 65,537
  entries (402.51 s baseline, 407.41 s consolidated). The final cleanup only
  changes gzip file ownership and is covered by the direct gzip regressions.
- Package storage 3, images 18, Setup 24, Forge 54, RTL 508, compiler recompile
  30 and compressed collation fixtures 5 tests passed. All ten examples compile.
- An audit matches all 18 original implementation sections after the documented
  scope/CRC rewrites and the two gzip corrections.

Bootstrap edits are strictly existing source locations/file masks. No stages,
compiler options, version branches or extra bootstrap processing were added.
Source directories follow the matching compiled RTL in consumer lookup order.
For native i386 tests, worktree-only library aliases point at installed 32-bit
runtime libraries; no host installation or bootstrap change was made.

Windows/Android/Apple verification consists of cross-compilation and artifact
review, under the owner's earlier waiver of native-platform execution.

Unrelated owner edits in FCL Base, Lab AVL examples and fpGUI were preserved.
No commit or toolchain promotion was performed.
