# Nexus PasZLib

The authoritative runtime source is directly in NexusFPC `rtl/objpas`:

- `paszlib.pas`: in-memory zlib compression, decompression and Adler32.
- `paszlibio.pas`: compressed streams, gzip files and ZIP/Zip64 archives.
- `crc32.pas`: the shared IEEE CRC32 table and update routines used by the
  compiler and compression code.

Use `PasZLib` for the buffer/stream-state API, `PasZLibIO` for stream classes
and archive/file APIs, and `CRC32` for direct checksums. Current source consumers
select `rtl/objpas` through `Tools.NexusFPC.SourcePath`; no separate compression
package or compatibility units are required. The old split units and their
namespace wrappers have been removed. Dotted origins now belong to the RTL's
namespace map. No legacy hash or HashLib4Pascal dependency is introduced.

The bootstrap retains its existing stages and options. Its source locations and
file-selection masks select the relocated units. The stock FPC 3.2.2 seed remains
supported. Runtime units compile from the selected matching RTL and source, as
they did before consolidation; this change adds no SDK/bootstrap stages.

`tests/PasZLibTests.nxproject` builds direct nxtest compression/CRC32 regressions
and retained stream-seek, ZIP/Zip64 and single-entry checks through nxbuild. Run
with `tests/test.zip` in a disposable directory under the development worktree.
The full ZIP suite includes 65,537 entries.
`tests/ReadOnlyGzipTests.nxproject` checks the retained `NO_DEFLATE` gzip-file
configuration, including rejected write opens and stream writes. Generated files belong in worktree,
never the source checkout. Examples remain in Nexus Lab
`examples/data/compression/paszlib`.

Original legal text remains in `readme.txt`, the RTL source headers,
`../COPYING.FPC` and `../../rtl/COPYING.txt`. See the
[central attribution record](../../../nexus/ATTRIBUTIONS.md#paszlib).
