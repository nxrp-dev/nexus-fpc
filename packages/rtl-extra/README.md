# Networking and locale RTL extensions

This package retains the low-level `Sockets`, `WinSock`, `WinSock2` and
`CLocale` units and their platform includes. Android selects its own CLocale
implementation. Darwin/iOS use the shared Unix sources with the Darwin socket
headers and BSD definitions; the BSD directory is required by those targets.

The compiler and base RTL do not depend on this package. Release tools no
longer stage it. Networking consumers and FCL-DB exports still use the retained
APIs. WinSock remains available; removing it is a separate consumer migration.

The 2026-10-17 cleanup retired Matrix, UComplex, Real48Utils, Serial, Printer,
System V IPC, GPM and the unused UnixSockets unit. `SortAlgs` and its namespace
wrapper moved unchanged to `packages/rtl-objpas`. Namespace mappings list the
retained platform sources only; original source headers remain intact.

The legacy Objects implementation is now the private `LegacyObjects` fixture
under `tests/rtl/fixtures/objects`. The object-language compiler regressions remain.
The two short-string stream tests now name ShortString explicitly, as required
by Nexus's documented string policy. `toperator5` retains its six operator tests
with a self-contained complex record; library-only Matrix/UComplex tests were
retired with their implementations. The Lab JPEG comment reader uses Classes.

The original 59-file snapshot, SHA-256 inventory and validation evidence are at
`/media/kcollins/dev/worktree/rtl-extra-cleanup-20261017-cil14_no`.
The pre-cleanup source is also retained in NexusFPC Git revision
`bfd5d2156b01f1213b3fa16e3b3fde38588c9d5d`.
Original FPC authorship and component license terms remain authoritative; see
[the canonical attribution record](../../../nexus/ATTRIBUTIONS.md#free-pascal-and-nexusfpc).

Validation passed with stock FPC 3.2.2 as the seed: native compiler generations
2/3 match, as do all 90 RTL objects. The retained units compiled 29 times
across all 13 targets. Native nxbuild suites passed 806 checks; the preserved
compiler/sorting/JPEG corpus passed 25 comparisons, including the intentional
missing-file diagnostic correction. Socket-pair transfer and locale initialization
passed at runtime. Bin2obj and RstConv build without this package on their search
paths; the RstConv regression suite passes. Windows/Apple/Android execution was
not performed. Compiler and base RTL source files were not changed.
