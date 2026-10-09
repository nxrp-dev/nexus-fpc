# NexusFPC dynamic packages: gap analysis and implementation backlog

Date: 2026-10-09

## Assessment and scope

FPC's historical dynamic-package work provides a substantial compiler foundation. This checkout now has an experimental Win64 shared RTL with explicit EXE startup activation, per-image contexts, and package lifecycle rollback. It is not a complete Delphi-style runtime-package system: general LoadPackage/UnloadPackage, reference accounting, registry cleanup, late-loaded TLS, and full binary compatibility remain open.

This document consolidates the source-based gap analyses, compatibility clarification, and implementation results. Items 1-10 and the profiler cache correction are committed. Item 11 now provides a tested, isolated Win64 package SDK and console/GUI build workflow. Its source-only and relocated builds, the runtime suite, and ordinary regressions pass. The preceding compiler/RTL milestone also passed profiler checks and the full bootstrap/cross matrix; item 11 changes build tooling and the experimental entry point without changing that runtime implementation.

The source inspection was made against NexusFPC at commit `471e676d`, including its working tree. At inspection time there were existing uncommitted changes in `compiler/entfile.pas`, `compiler/export.pas`, `compiler/expunix.pas`, `compiler/fpcdefs.inc`, `compiler/fppu.pas`, `compiler/pmodules.pas`, `compiler/systems/t_linux.pas`, and `compiler/systems/t_win.pas`, plus an untracked `tests/unit-exports/` suite. Those changes were not treated as validated dynamic-package support. Recheck the working tree and source locations before implementation.

The intended goal is Delphi-like runtime-package functionality for FPC-built applications: shared Pascal units, types, globals, and runtime services across module boundaries. Loading Delphi-produced BPL binaries would require a separate binary-compatibility effort.

Historically, Sven Barth was still discussing finishing dynamic packages in [October 2018](https://lists.freepascal.org/pipermail/fpc-pascal/2018-October/054934.html). The retained sources provide more specific evidence of the remaining work than historical statements alone. This assessment describes this checkout, not an exhaustive audit of every upstream or experimental branch.

## Compatibility clarification for items 1-4

The numbered backlog below follows the latest analysis: items 1-4 are package-name normalization, dependency-cycle validation, unique unit ownership, and PCP hardening.

These are improvements to existing compiler package infrastructure. With their scope kept narrow, they should leave ordinary application, static-unit, and conventional DLL/shared-library builds unchanged. They primarily improve the currently disabled dynamic-package path, so they should not be presented as general performance or functionality improvements for current ordinary builds.

That boundary now has targeted Win64 regression coverage, not a universal compatibility guarantee. There are deliberate behavior changes for invalid or inconsistent package input:

| Item | Expected effect on ordinary builds | Intended package behavior change | Compatibility constraint |
|---|---|---|---|
| 1. Normalize package names | No code-generation, ABI, or file-format change. Package-option parsing is also a caller to review. | Case variants identify the same package and follow the intended duplicate-reference policy. | Preserve display names and existing policy for ignoring versus diagnosing duplicates; canonicalize lookup keys consistently. |
| 2. Validate dependency cycles | No effect when the package-loading path is unused. | Self-dependencies and circular requirements produce explicit errors. | Accept valid acyclic graphs, including diamonds; avoid imposing restrictions on ordinary unit dependency handling. |
| 3. Enforce unique unit ownership | No effect on ordinary unit selection outside package consumption. | Packages that provide conflicting ownership fail instead of depending on lookup order. | Limit enforcement to package ownership and its dependency closure; preserve valid package graphs. |
| 4. Harden PCP handling | No effect on normal PPU-only builds if changes remain PCP-specific. | Malformed, truncated, or internally inconsistent PCP files are rejected cleanly. | Preserve the current PCP layout/version and valid existing files. Changes to shared PPU/entry-file infrastructure require broader regression coverage. |

At the clarification check, `CurrentPCPVersion` was `3`; no target definition enabled `tf_supports_packages`. `proc_package` rejects unsupported targets, and `load_packages` exits when that capability is absent.

Implementation of items 1-4 should not enable package target support, change the PPU or PCP schema, alter symbol mangling or calling conventions, modify ordinary unit-search semantics, or change the RTL ABI. A need to do any of those would be a separate scope decision. Item 16 covers runtime compatibility identity and any metadata extensions needed for a complete runtime system.

Validation now covers valid v3 fixtures, intended invalid-input diagnostics, source-free compile-time consumption, and ordinary EXE/DLL builds. See the implementation results below for the evidence and its limits.

## Implementation results: items 1-4

Implemented on 2026-10-09 against commit `10eb65ae` plus the working tree, then committed by the user in `d4002ae8`. Unrelated existing deletions under `nexus/` were preserved.

| Item | Implemented behavior | Validation |
|---|---|---|
| 1. Package identity | `add_package` uses a canonical uppercase key, preserves the first display/filesystem spelling, retains duplicate policy, and promotes an indirect reference when it is later explicitly required. | Mixed-case references resolve to one entry; ignored duplicates stay silent; explicit duplicates produce one error. |
| 2. Dependency cycles | Package loading walks the required-package closure with an active stack and reports a dependency chain. The package being built participates even before its PCP exists. | Diamonds pass; direct, indirect, and building-root cycles fail with the expected chains. |
| 3. Unit ownership | After loading the entire closure, a canonical unit-owner index rejects conflicting packages before unit lookup chooses a provider. | Both dependency orders reject duplicate owners; the existing `contains` check rejects a unit supplied by a requirement. |
| 4. PCP hardening | Validate complete headers, endian flags, metadata bounds/order/lengths, counts, identity, duplicate names, checksum, PPU ranges, and embedded PPU headers. Preserve metadata-only v3 size semantics. Correct writer table patching, honor PPU rewrite failure, and return independent bounded unit streams. | Real serialization round-trip, independent v3 fixtures, malformed-input cases, idempotent loading, and source-free consumer compilation pass. |

Production changes are in [pkgutil.pas](compiler/pkgutil.pas), [pcp.pas](compiler/pcp.pas), [fpcp.pas](compiler/fpcp.pas), and the package-specific loading path in [fppu.pas](compiler/fppu.pas). The latter now uses the existing resumable PPU loader and retains the owned package stream until loading completes. The test exposed an obsolete synchronous-loading assumption that otherwise raised internal error `2026020415`.

PCP-specific stream copies avoid the existing shared range-stream boundary/cursor problems without changing `cstreams` or shared entry-file serialization. Each active package PPU load uses a memory copy of that embedded PPU, freed when discarded; this is a memory cost to revisit if large-package profiling warrants it. The writer likewise buffers one rewritten PPU at a time.

Validation results:

- **70/70 package-suite steps passed**, including isolated compiler/driver builds, the tests above, and confirmation that the production target still rejects packages. Final logs: `C:\Users\kcollins\AppData\Local\Temp\nxpkg-tests-rd0ewpcv\steps.json`.
- **32/32 existing unit-export steps passed** using the final candidate compiler: ordinary EXE/DLL builds, export inspection, runtime calls, source-hidden cached units, and smart linking. Final logs: `C:\Users\kcollins\AppData\Local\Temp\nx-unit-exports-fc1ad23a\steps.json`.
- **Full clean bootstrap and cross matrix passed** on 2026-10-09 using `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-NexusFPCBootstrap.ps1 -FullMatrix -NdkRoot C:\android\ndk\25.2.9519653`. This rebuilt the native compiler, RTL, packages, and utilities; ran all six included native option/directive regression suites; built the retained cross compilers and all 13 RTL targets; verified fresh `System`/`heaptrc` outputs; and passed Linux FmtBCD and `heaptrc -CfNONE` checks. The native compiler reports 3.3.1. The native build recorded 14 nonfatal warnings: 13 dependency-cycle warnings and one missing `winmanutf8lfn` source warning. [Run logs](output/NexusFPCBootstrap/20261009-083156-353d2c79/steps.json). Cross-target results prove compilation, not execution on those platforms.
- PCP version remains **3**; PPU version remains **208**, long version **33**. No target capability, symbol mangling, calling convention, or RTL ABI was changed.

The reproducible suite and invocation are in [tests/dynamic-packages/README.md](tests/dynamic-packages/README.md). Log directories are local temporary artifacts, not committed fixtures.

The source-free test compiles with `-Cn`, using a PCP after hiding the unit's source, original PPU, and object file. It does **not** prove package linking or runtime behavior; that portion of item 4's original end-to-end acceptance depends on items 5 onward. No historical PCP corpus was available: compatibility was checked with independently encoded v3 metadata and real generated PPUs, including opposite-endian metadata. Runtime shared identity, loading, unloading, and package-specific behavior on non-Win64 platforms remain outside this validation; ordinary cross-target compiler/RTL builds are covered by the full matrix above.

## Initial implementation results: items 5-6

Implemented after `d4002ae8` on 2026-10-09, with experimental activation confined
to the test driver. Production changes are in [pmodules.pas](compiler/pmodules.pas)
and [ctask.pas](compiler/ctask.pas):

- Parse and register `contains` units, let the existing sequential compiler loop
  finish those units, then resume package emission. This supports fresh source
  builds and cached units without a synchronous-loader internal error.
- Keep package entry-point definitions in the package's own symbol table.
- Load command-line package metadata before compiling an initial standalone unit.
- Reject unsupported targets and packages lacking System with clean diagnostics.

The continuation is ordinary sequential compiler state handling. No threads,
parallel execution, or prototype code from the removed `nexus/` folder were added.

The [link suite](tests/dynamic-packages/run_package_link_tests.py) builds a provider
and a dependent package DLL, distributes only their PCP/DLL artifacts, inspects
PE imports/exports, and runs native probes. Four configurations pass: fresh and
cached units with smart linking off and on. The provider's original source, PPU,
and object files are hidden before building the consumer.

Verified across the two images: writable-global identity and updates; VMT and
class/enum/record RTTI identity; resource-string record identity; public aliases;
procedure and procedure-pointer calls; parent VMT references, inheritance, virtual
dispatch, and inherited calls; managed-record initialization metadata and helper
imports; Win64 exception-handler symbol resolution; and inline references to an
implementation-only helper. Imported procedure pointers may be import thunks;
the suite verifies that both pointers call the same provider and update its data.

Validation:

- **70/70 metadata steps** plus **27/27 linking, symbol, and diagnostic checks**
  passed. The runner reports 28 top-level steps because the metadata suite is one
  step. [Test instructions](tests/dynamic-packages/README.md). Local logs:
  `C:\Users\kcollins\AppData\Local\Temp\nxpkg-link-3ixe3sii`.
- **32/32 ordinary EXE/DLL export regressions** passed with the candidate compiler.
  Local logs: `C:\Users\kcollins\AppData\Local\Temp\nx-unit-exports-d57e76f5`.
- The existing **profiler smoke program** compiled and ran successfully: eight
  completed calls, one exception unwind, no unmatched/lost events, and a complete
  trace. Local logs: `C:\Users\kcollins\AppData\Local\Temp\nxpkg-profiler-38912e07`.
- **Clean native bootstrap passed**, including the compiler cycle, RTL, packages,
  utilities, compiler-version check (3.3.1), and all six option/directive regression
  suites: nine top-level steps, all successful. The run recorded the same 14
  nonfatal warnings as the earlier bootstrap: 13 dependency-cycle warnings and
  one missing `winmanutf8lfn` source warning.
  [Run logs](output/NexusFPCBootstrap/20261009-090805-20bae512/steps.json).
  This run was native Win64 only; the earlier cross matrix validates items 1-4,
  not these subsequent changes.

At this earlier checkpoint, the standalone Pascal EXE acceptance case was blocked by shared RTL startup:
ordinary `SysInit`/resource objects directly reference `System` data now owned by
the provider, including `U_$SYSTEM_$$_STARTUPCONSOLEMODE` and `_FPC_SysInstance`.
The historical run recorded this in `known-limitations.json` and
`application-startup.log`, excluded from passing-build counts. Items 7-10 now
resolve this failure with the approved explicit startup path; the old expected
failure was removed from the link runner and replaced by the real EXE runtime suite.

The successful runtime probes use static storage and nil managed values. They
establish symbol sharing between packages, not automatic initialization,
allocation across modules, exception unwinding across modules, or unload safety.
The provider includes System/ObjPas through existing implicit ownership; it is
not the foundational shared RTL package used by the newer runtime suite. PCP/PPU
versions, production target flags, and RTL ABI were unchanged at that checkpoint.

## Implementation results: items 6-10

The [approved runtime contract](nexusfpc-dynamic-packages-runtime-design.md) uses
one shared System/ObjPas/SysUtils owner, immutable descriptors, mutable per-image
contexts, and explicit sequential activation from generated EXE startup. Windows
package entry only records the native handle. No threads, asynchronous startup,
new locks, or parallel compilation were introduced.

| Item | Implemented behavior | Evidence |
|---|---|---|
| 6 | Export generated anonymous managed-type RTTI as well as named public symbols; exercise real managed values and exception unwinding. | Provider and host allocate/free objects across images, exchange strings/dynamic arrays/interfaces, agree on VMT/RTTI, and catch the declared exception type. PE import/export checks pass. |
| 7 | Emit exported version-1 descriptors with compiler/target/System identity, owned units, dependencies, and owner table references. | Native inspection checks the 144-byte layout, image handle, dependency closure and zero activation, including smart-linked DLLs. |
| 8 | Give each image a six-word mutable context separate from shared System entry state. | Distinct handles/descriptors/progress survive registration; owned resource and main-thread metadata remain attached to their image. |
| 9 | Filter imported owners out of generated tables; initialize dependencies once; reverse finalization; rollback completed prefixes after failure. | Real diamond order, otherwise-unused contained unit, typed initialization failure, preserved active dependencies, synthetic cleanup exceptions, and resumed finalization pass. |
| 10 | Build a matching shared RTL foundation and use SysInitPkg for a real host EXE. | Fresh/cached and normal/smart configurations all link and run with one System owner. Provider source/PPU/object files are hidden before consumption. |

The runtime harness builds its compiler and RTL in an isolated temporary directory.
The contained-unit continuation also clears dependency edges before releasing
modules, and loads System's intrinsic types before reading cached contained units.
These corrections address fresh multi-unit and cached foundation failures exposed
by the expanded acceptance cases.

Final validation on 2026-10-09:

- **99/99 runtime steps passed**, including all four fresh/cached and normal/smart
  configurations, native import/export inspection, and host-side finalization of
  provider-created managed values. Logs: `C:\Users\kcollins\AppData\Local\Temp\nxpkg-runtime-tbns3jyv`.
- **70/70 metadata steps and 27/27 link/symbol/diagnostic checks passed** (28
  top-level link-runner steps). Logs: `C:\Users\kcollins\AppData\Local\Temp\nxpkg-link-7oh1gfgu`.
- **32/32 ordinary EXE/DLL export checks passed** with the freshly bootstrapped
  compiler. Logs: `C:\Users\kcollins\AppData\Local\Temp\nx-unit-exports-8c2c2304`.
- **Profiler smoke passed** using the existing fixture and its isolated runtime
  unit paths: eight calls, seven normal returns, one unwind, zero unmatched/lost
  events, one trace-end record, and no truncation. Five build/run/probe steps passed.
  Logs: `C:\Users\kcollins\AppData\Local\Temp\nxpkg-profiler-final-0j_4xax6`.
- **Full clean bootstrap passed**, including the optimized native compiler cycle,
  RTL, packages, utilities, six option/directive regression suites, cross compilers,
  all **13 retained RTL targets**, Linux FmtBCD, and isolated `heaptrc -CfNONE`:
  **27/27 top-level steps**. Native compiler: 3.3.1. The same 14 nonfatal native
  warnings remain: 13 dependency-cycle warnings and one missing `winmanutf8lfn`
  source warning. [Bootstrap records](output/NexusFPCBootstrap/20261009-100746-283f9bb9/steps.json).
  Cross-target results establish compilation, not runtime execution on those platforms.

These checks establish a known-good milestone for the approved experimental
Win64 startup contract alongside ordinary builds. They do not establish complete
BPL compatibility or safe unload. The reproducible commands are in
[the test README](tests/dynamic-packages/README.md).

The separate profiler cache issue found during validation is now corrected.
Mixing the unprofiled trace probe's units with profiler runtime sources exposed
internal error `2026032615`: the compiler loaded NXProfilerRuntime through a
synchronous path that prohibited recompilation. A compiler built from committed
`d4002ae8` reproduces it. Comparison records:
`C:\Users\kcollins\AppData\Local\Temp\nxpkg-profiler-cache-qese6719`.

The correction in `pmodules.pas` registers the profiler runtime as an implicit
uses dependency, loads it even when the program has no uses clause, and lets the
existing sequential continuation load or rebuild it before program declarations.
No runtime implementation or threading mechanism changed. The new
[profiler cache regression suite](tests/nexusprofiler/README.md) passes 41 checks
with the candidate compiler, including source-only startup, normal/smart linking,
cache reuse, profile-mode transitions, and missing-source diagnostics. Candidate
records: `C:\Users\kcollins\AppData\Local\Temp\nx-profile-cache-p9tg7n2o`.

The freshly bootstrapped optimized compiler also passes **41/41 cache checks**:
`C:\Users\kcollins\AppData\Local\Temp\nx-profile-cache-hhj3qvyh`. The correction
retains **99/99 package runtime checks** (`nxpkg-runtime-a_cu8h_y`), **70/70 metadata
and 27/27 link checks** (`nxpkg-link-5hbbxomy`), and **32/32 ordinary EXE/DLL export
checks** (`nx-unit-exports-55e3af53`), all under the same local temporary-directory
root. The clean native bootstrap and six option/directive suites pass with the
same 14 nonfatal warnings. The refreshed cross matrix also passes all **13 RTL
targets**, Linux FmtBCD, and isolated `heaptrc -CfNONE`: **27/27 bootstrap steps**.
[Correction bootstrap records](output/NexusFPCBootstrap/20261009-104405-2ae70066/steps.json).
The mixed-profile cache defect is resolved for the tested source-available and
missing-source cases; it is no longer an outstanding limitation of this milestone.

Production target package flags remain disabled. PCP v3 and PPU v208/long 33
serialization formats are unchanged. New System startup hooks require matching
rebuilt RTL units; the runtime runner supplies them. The descriptor's preliminary
System checksum is not a complete mixed-build compatibility policy (item 16).
Native package resources, late-loaded TLS, loader reference accounting and unload
remain outside this milestone. Every registered image must remain mapped.

## Implementation results: item 11

The [SDK build script](scripts/Build-NexusFPCPackageSDK.ps1) builds a dedicated
experimental `ppcpkg` compiler from FPC 3.2.2, a matching RTL, the checked-in
`nxrtl.ppk` foundation, and per-image startup/resource adapters into an isolated
SDK. It generates compiler message includes itself and requires no prior ordinary
bootstrap. The normal compiler and installation outputs remain separate.

The distributed [compile helper](scripts/Invoke-NexusFPCPackageCompile.ps1)
builds packages or console/GUI applications. Packages declare their requirements;
hosts select package names and directories explicitly. PCP/DLL pairs provide
package units without standalone provider PPUs, objects or source files. Commands
and diagnostics are retained in logs. The [example guide](examples/dynamic-packages/README.md)
documents the one-command build/test workflow and distribution layout.

Validation on 2026-10-09:

- **19/19 SDK workflow checks**, covering fresh source-only builds, console and
  GUI startup, normal and smart linking, unchanged input sources, and relocated
  SDK/PCP/DLL consumption with the original source/build paths unavailable.
  Both host types preserve shared identity, cross-image managed ownership, and
  the exact diamond initialization/reverse-finalization order. Distributed SDK
  artifacts retain their hashes after host builds.
  Logs: `C:\Users\kcollins\AppData\Local\Temp\nxpkg-sdk-1ej_6isf`.
- **99/99 existing runtime checks** using the same experimental compiler entry
  point: `C:\Users\kcollins\AppData\Local\Temp\nxpkg-runtime-8lbtxg5y`.
- **32/32 ordinary EXE/DLL checks**:
  `C:\Users\kcollins\AppData\Local\Temp\nx-unit-exports-c9ecfb9a`.
- A freshly built ordinary compiler still rejects dynamic package declarations;
  recorded in `production-package-rejection.log` under the runtime results.

The GUI example tests the GUI PE subsystem and startup using a result file; it
does not exercise a GUI toolkit. This SDK contains the minimal shared RTL closure,
not all FPC library packages. General loading/unloading, registry cleanup, TLS
extensions and full mixed-build compatibility remain items 12-16. No runtime
threading changes or production target capability changes were introduced.

## Existing implementation

| Area | Current implementation | Assessment and source |
|---|---|---|
| Package language | `package`, `requires`, and `contains` parsing; collection of explicit and implicit contained units. | Substantial foundation in [pmodules.pas](compiler/pmodules.pas), `proc_package` (approximately line 1797). |
| Compiler package model | Package identity, contained units, required packages, and library filenames. | Existing model in [fpkg.pas](compiler/fpkg.pas), `tpackage`. |
| Compiled package metadata | PCP reading/writing, embedded PPU data, dependency names, unit tables, CPU/target/format checks. | Useful compile-time container in [fpcp.pas](compiler/fpcp.pas) and [pcp.pas](compiler/pcp.pas). |
| Package unit consumption | Units load from PCP files, receive package ownership, and are excluded from ordinary object-file inclusion. | [fppu.pas](compiler/fppu.pas), `loadfrompackage`, and the executable/package linking paths in `pmodules.pas`. |
| Symbol exports | Procedures, methods, globals, VMTs, RTTI, initialization/finalization procedures, and some TLS/resource symbols. | Existing symbol inventory in [pkgutil.pas](compiler/pkgutil.pas), `export_unit` and its helpers. |
| Symbol imports | Package import generation and indirect access paths for data, RTTI, and other compiler-generated references. | Existing machinery in `pkgutil.pas`, [ncgld.pas](compiler/ncgld.pas), and related code generators; systematic validation remains necessary. |
| Package linking | Package-owned objects are collected into a shared library; required package libraries/imports are attached. | Existing build path in `pmodules.pas`, approximately lines 2142-2207. |
| Target availability | No target definition enables `tf_supports_packages`; the package parser reports unsupported dynamic packages. | Disabled in this checkout. |
| Runtime management | No RTL `LoadPackage`/`UnloadPackage` implementation was found. | Missing operational package loader/lifecycle system. |

The existing [unit-export test description](tests/unit-exports/README.md) covers fresh/cached compilation, procedure aliases, exported data, and smart linking. It is relevant infrastructure, but symbol-export tests do not demonstrate shared Pascal type identity or package lifecycle. Its implementation and results need their own validation.

## Required ownership model

A unit shared across the application and packages must have one owner. If `CommonTypes` belongs to a package, every consumer must reference that owner's actual VMTs, RTTI, routines, and globals. Participating images must also use compatible shared RTL services.

For example:

```text
Application ---------> Common package ---------> Shared RTL package
     |                       ^                         ^
     +-------------------------------------------------+
                             |                         |
Dynamically loaded package --+-------------------------+
```

Each image also needs its own module descriptor for initialization tables, resources, TLS information, and native module handle. Sharing the RTL must preserve those module-specific distinctions.

[`TObject.InheritsFrom`](rtl/inc/objpas.inc), approximately line 868, compares VMT addresses. Independently compiling identical class declarations into different images does not establish common type identity. This affects typed exceptions as well as class checks, RTTI, globals, and registries. Sven Barth describes the typed-exception problem in [this 2021 FPC explanation](https://lists.freepascal.org/fpc-pascal/2021-August/059900.html).

## Original implementation gaps and current disposition

### Package entry and generated tables

[`generate_pkg_stub`](compiler/symcreat.pas) originally returned success without lifecycle work. It now records the native handle; generated EXE startup owns activation.

The Win64 package path now emits owner-only initialization, existing main-thread storage, resource-string, and managed-constant tables plus the runtime descriptor.

### Module-specific RTL state

[`SetupEntryInformation`](rtl/inc/system.inc), approximately line 83, overwrites the single `EntryInformation` record and resource pointers. Reusing that startup path unchanged for multiple images sharing `System` would overwrite an earlier module's state.

The new descriptor/context split preserves module-owned tables and handles. Startup aggregates existing main-thread and resource-string metadata before the existing RTL setup. General package resource lookup and late TLS support remain open.

### Initialization ownership and failure handling

The compiler's [`get_init_final_list`](compiler/ngenutil.pas) now excludes imported package owners. The package runtime tracks a completed prefix per context; ordinary builds retain the existing single-table path.

Owned-unit tables, dependency ordering, initialization once, reverse finalization, and partial-failure rollback are implemented and tested. General loader registration/reference cleanup remains separate.

### Runtime registration and cleanup

Windows has a skeletal `TLibModule` declaration in [sysosh.inc](rtl/win/sysosh.inc). This is not a complete runtime package registry. [`UnRegisterModuleClasses`](rtl/objpas/classes/cregist.inc), approximately line 97, has an empty implementation.

Loading needs package identity and compatibility checks, unit-ownership validation, dependency retention, and lifecycle execution. Unloading needs reference accounting, finalization before unmapping, and removal of registrations and caches that refer into the image.

Delphi's documented `LoadPackage` behavior includes duplicate-unit checking and unit initialization. Its unload contract requires callers to release objects and registrations belonging to the package. See [Loading Packages with the LoadPackage Function](https://docwiki.embarcadero.com/RADStudio/Sydney/en/Loading_Packages_with_the_LoadPackage_Function).

### Capability flag and code generation

`tf_supports_packages` affects ordinary code generation, including indirect data references; it is not merely permission to parse `package`. See [aasmdef.pas](compiler/aasmdef.pas), approximately line 58, and `tcgloadnode.use_indirect_symbol` in [ncgld.pas](compiler/ncgld.pas), approximately line 389.

Enabling the flag therefore requires matching compiler/RTL builds and regression coverage for conventional executables and libraries as well as package tests.

## Targeted implementation backlog

Each item is intended to be independently reviewable and testable. Dependencies identify prerequisites for completion, not approval checkpoints.

| ID | Targeted implementation | Main locations and dependencies | Acceptance criterion |
|---|---|---|---|
| 1 | **Implemented.** Normalize package names consistently using canonical lookup keys. | `pkgutil.add_package`; no runtime prerequisite. | `Foo`, `FOO`, and `foo` resolve consistently and follow the intended duplicate-reference policy. |
| 2 | **Implemented.** Validate package dependency cycles with a diagnostic dependency chain. | `pkgutil.load_packages`, `fpcp`; no runtime prerequisite. | Reject `A -> A` and `A -> B -> A`; accept a diamond and load its shared dependency once. |
| 3 | **Implemented.** Enforce unique unit ownership across the full required-package closure before package-unit lookup selects a provider. | `pkgutil`, `fppu.loadfrompackage`; items 1-2. | Conflicting package ownership fails regardless of search order; containing a unit already supplied by a requirement gets a precise diagnostic. |
| 4 | **Implemented for metadata and compile-time consumption.** Harden and regression-test PCP serialization and consumption without changing the format. | `pcp`, `fpcp`, package use of `RewritePPU`, package-specific `fppu` loading. | Compile-only source-free consumption and malformed-container checks pass. Full linked consumption still depends on items 5 onward. |
| 5 | **Implemented.** Experimental Win64 builds exercise the parser, PCP writer, and linker. | Test-only target activation, `pmodules`, sequential continuation in `ctask`, new package tests. | Fresh/cached package builds, source-free dependent linking, and ordinary EXE/DLL regressions pass. Items 7-10 add the real package-backed EXE. |
| 6 | **Implemented for experimental Win64.** Named/anonymous symbols, managed values, allocation and typed exceptions. | Import/export paths and both package suites. | Four fresh/cached and smart-link configurations pass with shared data/type identity and real managed ownership crossing images. |
| 7 | **Implemented for experimental Win64.** Versioned runtime descriptor with identity, dependencies, owned units and table references. | `pkgutil.emit_package_descriptor`, `FPCPackage`; items 2-4. | Native inspector reads descriptors without Pascal initialization; layout and preliminary compatibility checks pass. |
| 8 | **Implemented for the approved startup contract.** Separate mutable image context and immutable table references. | `FPCPackage`, System hooks, SysInitPkg; item 7. | Multiple contexts retain distinct handles, tables and progress without replacing host entry state. |
| 9 | **Implemented.** Owner-only tables, sequential dependency activation, reverse finalization and partial-initialization rollback. | `pmodules`, `ngenutil`, `FPCPackage`; items 7-8. | Diamond, failure rollback, preservation of active dependencies, cleanup failures and resumed shutdown pass. |
| 10 | **Implemented as an isolated experimental build.** Foundational shared System/ObjPas/SysUtils closure and per-image startup. | Runtime test build recipe, SysInitPkg, System preparation; items 6-9. | Real host/package identity, managed values, resources and typed exceptions pass. |
| 11 | **Implemented for experimental Win64.** Reusable isolated SDK and startup-linked console/GUI consumption. | `ppcpkg`, PowerShell SDK/build helpers, checked-in examples; item 10. | Fresh source-only build plus relocated PCP/DLL consumption passes in normal/smart modes with shared identity and ordered lifecycle. Ordinary builds remain separate. |
| 12 | Implement explicit `LoadPackage` and runtime registration: dependency retention, descriptor validation, duplicate-unit checks, repeat-load behavior, and rollback. | New low-level RTL package manager, public `SysUtils` facade, platform loader adapter; items 7-11. | Late loading works; repeat loading reuses initialized state; ownership conflicts fail before user initialization. |
| 13 | Implement `UnloadPackage` and reference accounting. Distinguish startup-held and explicit references; finalize before unmapping and retain dependencies while needed. | RTL package manager; item 12. | Unloading one diamond branch preserves the shared dependency; releasing its last eligible reference finalizes it once. |
| 14 | Complete module registration cleanup, including class unregistration and package-owned resource/RTTI registrations and cached references. | `classes/cregist.inc`, resource/RTTI registries, module lookup; items 8 and 13. | Load/register/unload/reload leaves no stale class or metadata pointer into an unmapped image. |
| 15 | Complete package TLS behavior for existing threads, newly created threads, and teardown; explicitly define whether direct cross-package `threadvar` access is supported. | `threadvr.inc`, platform TLS/thread code, generated TLS tables; items 8 and 12-13. | A package loaded into a multithreaded host provides isolated TLS to old/new threads and cleans it up correctly. |
| 16 | Enforce runtime ABI compatibility and artifact publication consistency. Match PCP/runtime build identities and reject incompatible RTL/compiler/target/text-model combinations. | PCP metadata, runtime descriptor, build tooling; items 4, 7, and 12. | Mismatched runtime images fail before unit initialization; failed linking cannot publish a new usable-looking PCP paired with an old image. |

Items 1-4 improve existing dormant package infrastructure without requiring the full runtime. Item 5 and the symbol work in item 6 expose the compiler/linker integration requirements. The descriptor and module-context contract in items 7-8 should anchor the runtime implementation.

The [runtime contract](nexusfpc-dynamic-packages-runtime-design.md) was approved
with explicit startup activation and implemented without threading changes.

## Unload contract

Package/dependency reference accounting cannot discover every live Pascal object, interface, callback, procedure pointer, or external cache that refers into an image. The application must release such references before unload.

The implementation should provide dependable dependency accounting and explicit lifetime rules. It should not promise automatic discovery of every remaining application reference. Failure rollback must also define how package registrations are removed when initialization only partly completes.

## Platform and follow-on work

Start with Win64 and one compiler/RTL build identity. Linux should receive a separate implementation and validation effort covering ELF symbol visibility, relocations, native loading, TLS, and startup behavior.

Once the basic runtime works, add focused cross-package coverage for:

- Generic specializations and their ownership/identity.
- Inline routines that reference implementation-only symbols.
- Custom attributes and RTTI-held references into packages.
- Managed values, including strings, dynamic arrays, interfaces, and managed records.
- Cross-module exception propagation and unwinding.
- Smart linking and retention of metadata/lifecycle symbols.

Delphi package directive compatibility and IDE design-time packages are follow-on work. Directive parsing alone does not establish its full semantics: this tree records `WEAKPACKAGEUNIT`, but its complete ownership behavior still needs examination. Design-time package support additionally requires IDE registration and unload integration.

## First meaningful end-to-end demonstration

Use an executable and a late-loaded package that share a third package containing a class, a typed exception, and a global counter, all using the shared RTL.

Success requires:

1. The participating images agree on class and RTTI addresses.
2. The executable catches the package's exception by its declared type.
3. Both images observe and modify the same global counter.
4. Each owned unit initializes once.
5. Dependencies remain loaded while needed.
6. Each unit finalizes once after its owner's last eligible release.
7. Partial load failure rolls back its own completed work without disturbing existing packages.

This demonstrates the central BPL-like behavior. A successful native DLL load or exported function call alone does not establish it.

## Evidence and implementation limits

Items 1-11 have the scoped implementation and validation recorded above. The
experimental Win64 SDK supports console/GUI shared RTL startup and sequential
package lifecycle. General BPL-style load/unload behavior and non-Win64 package runtime
support remain unimplemented; cross-target builds validate ordinary compilation,
not package execution on those platforms.

The repository source links are relative so the document can be browsed within the checkout. Approximate line numbers describe the inspected snapshot and may move. Revalidate the target flags, working-tree changes, and source paths when beginning an implementation item.
