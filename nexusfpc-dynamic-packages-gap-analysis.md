# NexusFPC dynamic packages: gap analysis and implementation backlog

Date: 2026-10-09

## Assessment and scope

FPC's historical dynamic-package work provides a substantial compiler foundation, but this NexusFPC checkout does not yet implement a functioning Delphi-style runtime-package system. The largest remaining work is shared RTL ownership and package lifecycle management. Enabling the existing compiler capability flag alone would expose these gaps.

This document consolidates the two source-based gap analyses and the subsequent compatibility clarification. Items 1-4 have now been implemented and tested as described below. Runtime packages remain unimplemented.

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

Implemented on 2026-10-09 against commit `10eb65ae` plus the working tree. Changes are uncommitted; unrelated existing deletions under `nexus/` were preserved.

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

## Concrete implementation gaps

### Package entry and generated tables

[`generate_pkg_stub`](compiler/symcreat.pas), approximately line 2198, returns success on Windows; it does not perform package initialization.

The `proc_package` path lacks the initialization/TLS/resource table-emission sequence used by ordinary programs and libraries. Compare it with `pmodules.pas`, approximately line 2393, where those tables are emitted.

### Module-specific RTL state

[`SetupEntryInformation`](rtl/inc/system.inc), approximately line 83, overwrites the single `EntryInformation` record and resource pointers. Reusing that startup path unchanged for multiple images sharing `System` would overwrite an earlier module's state.

The runtime needs an explicit distinction between shared process services and module-owned startup/lifecycle information. Windows startup and TLS code also use this information and must participate in the correction.

### Initialization ownership and failure handling

The compiler's [`get_init_final_list`](compiler/ngenutil.pas), approximately line 988, walks used units without a package-ownership boundary. The RTL's initialization machinery executes one table and tracks its completed prefix.

Packages require owned-unit tables, dependency ordering, initialization-once behavior, reverse finalization, and rollback after partial failure. Previously loaded dependencies must survive a failed new load.

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
| 5 | Establish an experimental Win64 package build and regression harness. Exercise the existing parser, PCP writer, and linker without claiming general support. | Target flags, compiler build configuration, new package tests. | Minimal package/consumer builds are reproducible; ordinary EXE/DLL regression coverage remains passing. |
| 6 | Complete and validate the Win64 package symbol contract: procedures, writable data, VMTs, RTTI, compiler helpers, and references embedded in generated tables. | `pkgutil`, `aasmdef`, `ncgld`, `ncgmem`, `ncgcnv`, `cgexcept`, Windows import/export code; item 5. | Fresh/cached consumers resolve each symbol category with smart linking on/off; shared data/type pointers agree across images. |
| 7 | Define and emit a versioned runtime package descriptor containing identity, dependencies, owned units, compatibility identity, and lifecycle/table references. | New compiler emitter and matching RTL record; items 2-4. | An inspector enumerates units and requirements without executing Pascal unit initialization. |
| 8 | Introduce per-module RTL context for handles, table pointers, initialization progress, and TLS/resource metadata, separate from shared process services. | `systemh.inc`, `system.inc`, platform startup code; item 7. | Registering a second synthetic module context does not overwrite the first. |
| 9 | Implement package-owned initialization/finalization and partial-initialization rollback. Emit the owner's lifecycle table, initialize dependencies first, and finalize in reverse order. | `pmodules`, `ngenutil`, RTL lifecycle code; items 7-8. | Diamond dependencies initialize each unit once; an initialization exception finalizes only completed units and preserves previously loaded packages. |
| 10 | Build the foundational shared RTL package and correct bootstrap behavior. Establish one `System` owner and shared identity for selected RTL units; retain per-image startup code where needed. | RTL package definitions, build scripts, compiler special handling of `System`; items 6-9. | Host/package class and exception identity agree; shared RTL state agrees; managed values can be created in one image and released in another. |
| 11 | Complete startup-linked package consumption using the same ownership and lifecycle model. | Program startup, package imports, RTL package manager; item 10. | An EXE starts with dependent packages, sees initialized globals, and finalizes them once in dependency order. |
| 12 | Implement explicit `LoadPackage` and runtime registration: dependency retention, descriptor validation, duplicate-unit checks, repeat-load behavior, and rollback. | New low-level RTL package manager, public `SysUtils` facade, platform loader adapter; items 7-11. | Late loading works; repeat loading reuses initialized state; ownership conflicts fail before user initialization. |
| 13 | Implement `UnloadPackage` and reference accounting. Distinguish startup-held and explicit references; finalize before unmapping and retain dependencies while needed. | RTL package manager; item 12. | Unloading one diamond branch preserves the shared dependency; releasing its last eligible reference finalizes it once. |
| 14 | Complete module registration cleanup, including class unregistration and package-owned resource/RTTI registrations and cached references. | `classes/cregist.inc`, resource/RTTI registries, module lookup; items 8 and 13. | Load/register/unload/reload leaves no stale class or metadata pointer into an unmapped image. |
| 15 | Complete package TLS behavior for existing threads, newly created threads, and teardown; explicitly define whether direct cross-package `threadvar` access is supported. | `threadvr.inc`, platform TLS/thread code, generated TLS tables; items 8 and 12-13. | A package loaded into a multithreaded host provides isolated TLS to old/new threads and cleans it up correctly. |
| 16 | Enforce runtime ABI compatibility and artifact publication consistency. Match PCP/runtime build identities and reject incompatible RTL/compiler/target/text-model combinations. | PCP metadata, runtime descriptor, build tooling; items 4, 7, and 12. | Mismatched runtime images fail before unit initialization; failed linking cannot publish a new usable-looking PCP paired with an old image. |

Items 1-4 improve existing dormant package infrastructure without requiring the full runtime. Item 5 and the symbol work in item 6 expose the compiler/linker integration requirements. The descriptor and module-context contract in items 7-8 should anchor the runtime implementation.

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

Runtime-gap conclusions above remain source-inspection findings. Items 1-4 now have the implementation and targeted validation recorded above; no package runtime behavior has been demonstrated.

The repository source links are relative so the document can be browsed within the checkout. Approximate line numbers describe the inspected snapshot and may move. Revalidate the target flags, working-tree changes, and source paths when beginning an implementation item.
