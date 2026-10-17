# Nexus PasZLib

This is the authoritative PasZLib source for Nexus, including compiler bootstrap,
release tools and applications. The duplicate External Packages copy was retired
on 2026-10-17 by owner direction. Keep one source tree here for now.

Use `src` in unit/include search paths together with the matching NexusFPC RTL
and `packages/hash/src`. Existing build recipes select this directory through
`Tools.NexusFPC.SourcePath`. Do not mix units from another PasZLib copy.

`tests/PasZLibTests.nxproject` builds five direct nxtest window/header regressions
and the retained stream-seek, ZIP/Zip64 and single-entry extraction checks through
Nexus nxbuild. The nxtest executable is `NXPasZLibTests`. Build output is in Nexus
`output/PasZLibTests/<native-target>`. Run with `tests/test.zip` in a disposable
working directory and place temporary files there. The full ZIP suite includes
a deliberately large 65,537-entry case.

Examples are centralized in Nexus Lab `examples/data/compression/paszlib`, with
one native `PasZLibExamples.nxproject` recipe. See [the reconciliation record](CONSOLIDATION.md)
for comparison decisions, native checks and limits.

Original legal text remains in `readme.txt`, the runtime source headers,
`../COPYING.FPC` and `../../rtl/COPYING.txt`. Upstream authors, import history,
current ownership and retired-copy history are maintained in the
[central attribution record](../../../nexus/ATTRIBUTIONS.md#paszlib).
