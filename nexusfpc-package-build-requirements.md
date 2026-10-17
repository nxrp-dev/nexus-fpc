# Package build requirements recovered from retired recipes

Reviewed 2026-10-14 against the source tree at
`781faeb495d6aeb9d98facf441b826958af2d378`, before removal of the remaining
Make/fpmake infrastructure. This is a reference for selecting packages and
writing Nexus build descriptions. It does not declare that every listed package
has been built or that its old platform restrictions are Nexus policy.

The complete old unit lists, dependency conditions and example registrations
remain available in Git. For example:

```text
git show 781faeb495d6aeb9d98facf441b826958af2d378:packages/fcl-res/fpmake.pas
git show 781faeb495d6aeb9d98facf441b826958af2d378:tests/Makefile.fpc
```

## Package dependency checklist

These are the explicitly declared package dependencies in each package's former
`fpmake.pas`. The RTL is implicit. A dash means no additional package dependency
was declared, not that the package needs no system libraries. Dependencies may
cover optional units or tests; they are not necessarily required by every unit.
`fcl-json` moved to Nexus `packages/nexus-packages/serialization/fcl-json` on
2026-10-15; its `FCLJSON.nxpackage` builds the runtime units. The optional
FPCUnit helper and fcl-fpcunit were retired on 2026-10-16 after retained useful
tests were converted directly to nxtest (no bridge). `fcl-process` moved to Nexus
`packages/nexus-packages/fcl-process` on the same date, preserving its
source, examples, tests and static review report. Rows marked relocated record
other moves to Nexus; the other listed directories are in this repository.
`tplylib` and the TP Lex/Yacc tools were retired on 2026-10-16 after their last
production consumer, the RC parser, was removed. They are not bootstrap inputs.
The Apple-only packages `univint`, `cocoaint` and `iosxlocale` moved on
2026-10-16 to the dedicated `nexus-packages-apple` repository, cloned at Nexus
`packages/nexus-packages-apple`. Their snapshots, hashes and migration results
are saved there. Code review was explicitly waived for that relocation.
`src` is the usual source root; exceptions and platform-specific paths are below.

| Package | Declared dependencies | Details worth preserving |
| --- | --- | --- |
| `cocoaint` (relocated) | `univint` | Moved 2026-10-16 to Nexus `packages/nexus-packages-apple/cocoaint`. Darwin, x86_64/aarch64; `MACOSALL`, `COCOAALL`, `LEGACY_SETNEEDSDISPLAY` defines retained. |
| `fcl-async` (retired) | — | Removed 2026-10-17 after confirming no production Nexus consumers. The unused FCL Net async units and dependent Lab demonstrations were removed with it. Original source remains in NexusFPC Git history. |
| `fcl-base` | `rtl-objpas`; `univint` on Apple targets | OS include paths and event-log resource described below. |
| `fcl-db` (relocated) | `fcl-base`, `fcl-xml`, `rtl-objpas`, `rtl-extra`, `fcl-json`; transitive `pthreads` and encoding/compression/hash helpers | Moved on 2026-10-16 to Nexus `packages/nexus-packages/db/fcl-db`; `FCLDB.nxpackage` builds 66 runtime units. The saved review preserves the original source/hashes, regression proofs, corrections and retained-suite results. |
| `fcl-fpcunit` (retired) | Historical: `paszlib`, `fcl-base`, `fcl-xml`; `univint` on Apple targets | Removed 2026-10-16. Useful retained tests now use Nexus nxtest directly; original framework and runners are archived in Nexus `docs/migrations/fpcunit`. |
| `fcl-hash` | `rtl-objpas`, `rtl-extra`, `fcl-base`, `hash` | Recipes give explicit `src/` filenames. |
| `fcl-image` (relocated) | `pasjpeg`, `paszlib`, `fcl-base`; transitive `hash`/CRC | Moved on 2026-10-16 to Nexus `packages/nexus-packages/graphics/fcl-image`; `FCLImage.nxpackage` builds all 56 runtime units. The saved package review includes original hashes, regression proofs, fixes and retained-suite results. |
| `fcl-json` (relocated) | `fcl-base`, `rtl-objpas` | The former optional `jsonfpcunit` helper was retired; runtime JSON has no FPCUnit dependency. |
| `fcl-net` (relocated) | `fcl-base`, `rtl-extra`, `rtl-objpas` | Moved intact on 2026-10-17 to Nexus `packages/nexus-packages/network/fcl-net`; `FCLNet.nxpackage` builds the seven remaining runtime units on Linux. Synapse uses its Unix resolver and the shared OpenSSL wrappers use its TLS types. The saved review records consumers, proven fixes and the consolidation recommendation. |
| `fcl-process` | `fcl-base` | `src`, platform includes; recipe option `-S2h`. |
| `fcl-registry` (relocated) | `fcl-base`, `fcl-xml` | Moved on 2026-10-17 to Nexus `packages/nexus-packages/fcl-registry`; `FCLRegistry.nxpackage` builds the native package and `tests/FCLRegistryTests.nxproject` owns direct nxtest coverage. Windows COM, Abbrevia and Synapse serial support remain consumers. Review and proven fixes are saved with the destination. |
| `fcl-res` | RTL metadata reader closure; `fcl-base` for the optional `restool` example | Retained FileInfo, RES/PE/ELF/Mach-O readers and version models. Compiler resources use RTL-only catalog/adapters and LLVM. |
| `fcl-xml` (relocated) | `fcl-base`; `iconvenc` on Linux/Apple/AIX in the old recipe | Moved on 2026-10-16 to Nexus `packages/nexus-packages/serialization/fcl-xml`; `FCLXML.nxpackage` builds the runtime units and target encoding adapter. Retained source/test evidence and corrections are documented in the package review. |
| `hash` | `rtl-objpas`, `rtl-extra` | CPU-specific assembler includes; old `unixcrypt` target restricted to Linux. |
| `iconvenc` | — | Recipe marks libc required. |
| `iosxlocale` (relocated) | `univint` | Moved 2026-10-16 to Nexus `packages/nexus-packages-apple/iosxlocale`; locale and wide-string bindings. |
| `jni` | — | `src/jni.pas`; recipe used `-Ur` and individual-unit compilation. Native JNI is independent of the retired JVM compiler backend. |
| `libffi` | `rtl-objpas` | `ffi.pas`, `ffi.manager.pas`; recipe marks libc required. The recipe builds Pascal bindings, not libffi C sources. |
| `pasjpeg` | — | `jctrans.pas` plus the `buildpasjpeg.pas` aggregate; `jconfig.inc`. |
| `paszlib` | `hash` | `paszlib.pas`, `zip.pas`, `unzip.pas`, `zipper.pas`, plus implicitly compiled units. Old dependency version was `3.3.1`. |
| `pthreads` | — | Pascal platform bindings; preserve their source-level library declarations. |
| `rtl-extra` | — | OS-specific source selection, particularly Android `clocale`. |
| `rtl-generics` | `rtl-objpas` | Sources in `src`, includes in `src/inc`. |
| `rtl-objpas` | — | Sources in `src/inc` and platform directories; CPU-specific includes. |
| `univint` (relocated) | — | Moved 2026-10-16 to Nexus `packages/nexus-packages-apple/univint`. Apple x86_64/aarch64; `MacOS.pas`, `MacOSAll.pas`, implicit units; the nxbuild recipe preserves MacPas mode. |
| `winunits-base` | `fcl-registry`, `fcl-base`, `rtl-extra` | `buildwinutilsbase.pas` aggregate, implicit units and `w32default.res`; recipe marks libc required. |
| `x11` | — | Bindings and their external libraries must be assessed from the selected units. |

The old `NeedLibC` flags are recorded as recipe facts, not a replacement for
examining `external`/`linklib` declarations for a selected target. Likewise,
recipe options already expressed by source directives need not be duplicated:
for example, `univint/src/MacOS.pas` itself specifies `{$mode macpas}`, and
`jni/src/jni.pas` specifies its mode and C record packing.

## Source selection and compiler settings

The `users` package was restored on 2026-10-15 for fpGUI's Linux file-owner
and group-name lookup. Its five runtime units are `users`, `pwd`, `grp`,
`shadow`, and `crypth`, under `packages/users/src`. They depend on RTL units;
`crypth` additionally links the host's `crypt` library. Namespace mappings and
examples are retained using `.pas` filenames. The retired Make/fpmake drivers
are not part of this restoration.

- **FCL platform includes:** `fcl-base` used `src`, `src/<os>`, `src/unix` or
  `src/win`, plus `src/dummy` as a fallback. `fcl-net` used `src` with
  `src/unix` or `src/win` includes. `fcl-process` used `src`, then `src/unix`
  on Unix-family targets, or both `src/winall` and `src/win` for Win32/Win64.
  Its `processbody.inc` and `pipes.pas` include platform implementations by
  basename, so the include paths matter. Only select paths applicable to the
  actual Nexus target; old broad OS sets do not establish support.
- **Database roots:** relocated subdirectories under Nexus
  `packages/nexus-packages/db/fcl-db/src` are `base`,
  `sqldb`, `sdf`, `json`, `datadict`, `memds`, `codegen`, `export`, `dbase`,
  and `sql`. Explicit include roots were `base`, `sqldb`, `sdf`, `memds`,
  and `dbase`. The old recipe limited data-dictionary/codegen/export targets
  to Linux, Windows, Darwin, Android and historical AIX.
- **RTL extensions:** `rtl-extra` used `src/inc`, `src/<os>`, `src/unix`,
  `src/bsd` where appropriate and `src/win` for Windows. Apple mobile targets
  additionally used `src/darwin`. Android selected its own `clocale.pas`
  before the Unix implementation. Preserve that source choice rather than
  compiling both same-named units indiscriminately.
- **Object Pascal RTL extensions:** `rtl-objpas` used `src/inc`, `src/<os>`,
  `src/win` on Windows and `src/<cpu>` for includes. Examples are `invoke.inc`
  and the Windows/non-Windows variant implementations.
- **Hash assembly:** the old dependencies name `md5i386.inc`, `sha1i386.inc`,
  `sha1x86.inc`, `sha1x64_sysv.inc` and `sha1x64_win.inc`. Keep source-level
  CPU/ABI selection; a recursive compile-every-file operation is unsuitable.
- **Cocoa configuration:** current Cocoa sources test `MACOSALL` and
  `COCOAALL`; the old package also set `LEGACY_SETNEEDSDISPLAY`. These select
  binding configurations and must be considered when choosing entry units.

The `buildpasjpeg.pas` and `buildwinutilsbase.pas` source aggregates and
`univint/src/MacOS.pas` remain. The old recipes compiled them to pull in their
used units but marked the aggregate itself `Install=False`. Distribution must
include the actual compiled member units, including implicit units, rather than
only the explicit entry-unit outputs. The aggregates' uses clauses and retained
namespace maps provide the current source-side inventory; Git retains the full
old explicit/implicit target lists.

## Resources and namespaces

| Item | Verified source or artifact | Build/distribution significance |
| --- | --- | --- |
| Windows default manifest resource | `packages/winunits-base/src/w32default.res`; referenced by `winmanutf8lfn.pas` | Old recipe copied this resource alongside installed units. Keep it available to consumers that compile the unit. This is unrelated to the removed package-manager `manifest.xml`. |
| Windows event-log resource | `packages/fcl-base/src/win/fclel.res`, with `.mc`/`.rc` inputs | Old recipe explicitly shipped it. No active Pascal reference was found in `fcl-base/src`; do not infer that every application needs it. The `.rc` contains an obsolete absolute temporary path, so regeneration needs a separate review. |
| Resource strings | `ResourceStrings=True` target registrations | Old installation collected `.rsj`, or historical `.rst`, alongside unit artifacts. Current Forge release/SDK copy masks already include `.rsj` and `.res`. |
| Namespace mappings | Retained package `namespaces.lst` and `namespaced/` source trees | Example: `hash` maps `src/md5.pas` to `namespaced/System.Hash.Md5.pas`. Preserve these source mappings independently of fpmake. |
| Translation example | `../nexus-lab/examples/runtime/base/intl/restest.<language>.po` and `.mo` | Old Makefile used `msgfmt -o restest.<language>.mo restest.<language>.po` for `fr`, `nl`, `de`, `pb`, `ru`, `cs`. All six input/output pairs exist. |

## Test preparation retained for nxtest

The test sources and data remain. The retired Make runners are not being
reimplemented in Forge as part of this cleanup.

- `tests/test/cg/obj/` contains `ctest.c`, `tcext3.c` through `tcext7.c`,
  `cpptcl1.cpp`, `cpptcl2.cpp` and `ttasm1.asm`. The old runner compiled the
  C/C++ fixtures with the target C compiler and explicit test flags. Objects
  were separated by OS, CPU and optional ABI before copying them into the
  test output. A future nxtest migration must supply matching-target objects.
  The assembly fixture was separately listed; it is not a C compiler input.
- `tests/tstunits/` prepared `erroru.pas`, `popuperr.pas`, `tests/test/cg/ptest.pas`,
  FPCUnit support and selected package/RTL units. The source files remain.
- Old package test entry lists include `fcl-fpcunit/src/tests/`
  (`asserttest`, `frameworktest`, `suitetest`), `fcl-registry/tests/`
  (`tregtestframework`), relocated Nexus `packages/nexus-packages/db/fcl-db/tests/`
  (`testsqlfiles.lpr`, `toolsunit`,
  `dbftoolsunit`) and `fcl-xml/tests/` (`xmlts`, `domunit`, `testgen`).
  Preserve test/unit distinctions when migrating; not every listed file is
  a runnable program.
- Package `examples/` and `tests/` sources are retained. Full historical
  registrations are recoverable from the commit above; those registrations
  are not proof that an example still compiles.

## Obsolete information and removed machinery

The nested `fcl-db/src/base/fpmake.inc` referenced removed SQLite and InterBase
directories. Several old Makefile templates list packages or platforms no
longer present. None of these declarations authorizes restoring removed code
or broadening the supported target matrix.

Removed: remaining Makefiles and `Makefile.fpc`/`.fpc.fpcmake` templates,
`fpmake.pas`/`.inc` drivers and aggregates, `regenmakefiles.sh`, the `fpmkunit`
engine and its `ppu2fpmake.sh` helper, generated fpmake executables/objects,
fpmkunit unit caches, obsolete `fpcmade.*` stamps and the stale generated
`packages/packages.txt` directory listing. Searches found no consumer of that engine outside
the retired drivers in NexusFPC, and none in current Nexus build-tool sources.

No checked-in package-manager `manifest.xml` remained. Its generator was part
of `fpmkunit`; it only serialized package version, target restrictions,
dependencies and distribution metadata from the declarations. Removing it
does not affect compiler `.nxpk`/`.nxp` package support or application resources.

Package source, compiler/RTL source, namespace maps, resources, tests and
license notices remain. Package selection and nxtest migration are separate
work. The root attribution file is unchanged.
