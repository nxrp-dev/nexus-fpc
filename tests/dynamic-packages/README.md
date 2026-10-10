# Compiler package regressions

## Linux glibc

Run `python3 tests/dynamic-packages/run_linux_package_sdk_tests.py` on x86-64
Linux for clean source-only normal/smart SDK builds, fresh/cached runtime tests,
ordinary compiler/export checks and source-free relocation. For an existing SDK,
use `run_linux_package_tests.py --sdk <directory>`; `--cached` and `--smart` select
those configurations. See the [Linux implementation and SDK guide](../../nexusfpc-dynamic-packages-linux.md).

## Metadata

This suite covers dynamic-package backlog items 1–4 without enabling packages in
any production target. It builds an isolated Win64 compiler and a test driver
linked against the same compiler units. The driver enables the package capability
only inside its own process for graph validation and compile-only consumption.

From the repository root:

```powershell
python tests\dynamic-packages\run_package_metadata_tests.py
```

Requirements: Python 3, an FPC 3.2.2 Win64 bootstrap (default
`C:\lazarus\fpc\3.2.2\bin\x86_64-win64\ppcx64.exe`), and matching NexusFPC RTL
units already built in `rtl\units\x86_64-win64`. Use `--bootstrap` to select a
different bootstrap location. Outputs go to a new temporary directory, printed
on success. `--output-root` accepts an empty directory; `--compiler-build` reuses
an isolated build directory and incrementally rebuilds its compiler before testing.
Neither option should point at the repository's production compiler directory.

The suite records each command, exit code, and log path in `steps.json`. It checks:

- Case-insensitive identity, display spelling, duplicate diagnostics, and promotion
  from an indirect requirement to a direct one.
- Valid diamond dependencies, self/indirect cycles, and cycles involving a package
  being built that does not yet have a PCP.
- Conflicting owners in both dependency orders and the existing parser diagnostic
  for containing a unit already supplied by a required package.
- Real writer/reader round-trip, unchanged original PPU, repeated loading,
  independent bounded unit streams, and independently encoded version-4 metadata.
- Empty/multiple-unit containers, opposite-endian metadata, metadata crossing the
  entry buffer boundary, and malformed headers, counts, names, entries, checksums,
  offset tables, overlapping ranges, and embedded PPU headers.
- Compilation using a PCP while the packaged unit's source, standalone PPU, and
  object file are unavailable. This includes resumable loading of its dependencies.
- Continued rejection of package declarations by the production compiler.

On 2026-10-09 all 70 steps passed. The existing `tests/unit-exports` suite supplies
separate ordinary EXE/DLL build, export, runtime, cached-unit, and smart-link coverage.

The source-free consumer uses `-Cn`: this proves compile-time PCP consumption,
not package linking, shared RTL identity, or runtime loading/unloading. There is
no historical PCP corpus here; current coverage uses independently encoded v4
fixtures and real compiler-generated PPUs. Item 16 deliberately replaces the
experimental v3 format; old package containers must be rebuilt.

## Experimental Win64 linking and symbols

```powershell
python tests\dynamic-packages\run_package_link_tests.py
```

This runner first builds the isolated compiler/driver and runs the metadata suite,
then builds real `.ppk` providers and consumers through the normal package parser
and linker. It additionally requires 64-bit Python and LLVM tools on `PATH`.
It accepts the same `--source-root`, `--bootstrap`, `--compiler-build`, and
`--output-root` options as the metadata runner.

Each of four cases uses fresh directories: ordinary and smart linking, each with
freshly compiled or cached source-hidden units. The provider's source, PPU, and
object are hidden before consumer compilation; the distribution contains only
PCP and DLL files. Cached unit hashes must remain unchanged.

The suite checks PE exports/imports and loads the two DLLs into a separate native
Python process for each case. It verifies:

- Shared writable-global address and values across both images.
- Class VMT, class/enum/record RTTI, and resource-string record identity.
- Public aliases, imported procedure calls, and procedure-pointer calls through
  either the provider or a consumer import thunk.
- Parent-class references in generated VMTs, inheritance, virtual dispatch, and
  inherited method calls.
- Managed-record initialization metadata, initialization/finalization helper
  imports, and the Win64 exception-handler symbol.
- Inlined code that calls an exported implementation-only helper.
- Clean diagnostics for a package without System, missing contained units, and
  duplicate unit ownership.

`NX_BaseCounter` and the other `NX_Base*`/`NX_Consumer*` names are test export
aliases, unrelated to `packages/nexusprofiler` or the removed `nexus/` experiment.
All test orchestration and the package parser continuation use sequential
execution; this work introduces no threads or parallel compilation mechanism.

The final run on 2026-10-09 passed 28 runner steps: the complete 70-step metadata
suite plus 27 linking, symbol, and diagnostic checks. Logs are in
`C:\Users\kcollins\AppData\Local\Temp\nxpkg-link-7oh1gfgu`.

### Runtime boundary

The consumer is a second package DLL. The provider includes `System` and `ObjPas`
through the existing implicit-unit ownership rule. Native loading plus probes
using static object storage and nil managed values establish symbol sharing;
they do not establish automatic Pascal package lifecycle or a supported shared
RTL startup. Resource coverage verifies the record address, not resource loading.
Exception-handler coverage verifies linking, not cross-image exception unwinding.

The earlier standalone EXE startup failure is covered by the shared RTL suite
below. The symbol-only runner no longer expects or counts that historical failure.

The standard Win64 and Linux x86-64 compilers now support packages. Metadata uses
NXP v4 and NXU header 208 with compatibility revision 35; rebuild existing units.

## Shared RTL and explicit startup activation (items 6-10)

```powershell
python tests\dynamic-packages\run_package_runtime_tests.py
```

This builds an isolated standard compiler and
matching package-enabled RTL from source. It needs the default FPC 3.2.2 bootstrap,
64-bit Python, and LLVM tools on PATH. It uses the checked-in target capabilities.
Outputs, command records (`steps.json`), PE import/export reports, descriptor JSON,
and application output go to a new temporary directory. `--output-root` can reuse
a development output directory; omit it for a fresh validation build.

Four configurations cover fresh and cached units with normal and smart linking.
Only PCP/DLL files are distributed; original provider sources, PPUs, and objects
are hidden. Cached artifacts must retain their hashes. Checks include:

- Descriptor version/layout, compiler/target/System identity, unit ownership,
  dependencies, native image handles, and zero initialization during native loading.
- Every inter-package and EXE package import resolves to the provider's exports,
  including anonymous managed-field RTTI.
- Independent module contexts; diamond initialization exactly once; reverse
  finalization; invalid descriptor, duplicate owner, and dependency-cycle rejection.
- A real EXE and packages sharing class/RTTI identity, objects allocated and freed
  across images, strings, dynamic arrays, interfaces, and typed exception unwinding.
- Resource strings, wide-string constants, and metadata for contained units not
  directly referenced by the EXE, using existing main-thread storage.
- Failed activation rolls back completed units while preserving active dependencies;
  synthetic cleanup failures preserve the original exception. Interrupted normal
  finalization can resume without repeating callbacks.

The approved contract is in [the runtime design](../../nexusfpc-dynamic-packages-runtime-design.md).
The foundation owns System/ObjPas/SysUtils; generated EXE startup explicitly
activates packages. Native LoadLibrary only maps them. This low-level suite uses
caller-held mappings; the managed LoadPackage/UnloadPackage suite below exercises
native release and registry cleanup. The unified threadvar suite below covers
late-loaded TLS within the single-threaded package lifecycle contract.
No worker threads or new synchronization were introduced.

Final 2026-10-09 runtime validation passed **99/99 steps** from a fresh directory:
`C:\Users\kcollins\AppData\Local\Temp\nxpkg-runtime-tbns3jyv`. The corresponding
ordinary/full-cross build results are recorded in the
[gap analysis](../../nexusfpc-dynamic-packages-gap-analysis.md#implementation-results-items-6-10).

## Package SDK workflow (item 11)

The [SDK guide](../../examples/dynamic-packages/README.md) documents the reusable
PowerShell build and compile helpers and checked-in console/GUI examples.
Both workflows now build `compiler/pp.pas`, the standard compiler entry point.
Package support is enabled by the normal Win64/Linux x86-64 target definitions.
SDK regressions also build and run static hosts and verify that they have no
shared-RTL imports. Older validation records below describe their original runs.

```powershell
python tests\dynamic-packages\run_package_sdk_tests.py
```

This runner copies tracked and new, non-ignored compiler/RTL/script/example files
into a source-only snapshot, without compiler message includes or prebuilt RTL
units. It builds and runs the examples in normal and smart-link modes, checks
that the source snapshot is unchanged, and copies only the SDK distribution and
provider PCP/DLL pairs. It then hides the original source and SDK directories and
rebuilds/runs both hosts from the relocated distribution. Checks include PE
subsystem selection, shared identity, cross-image managed ownership, dependency
initialization once, reverse finalization, and unchanged SDK artifacts.

Requirements: Python 3.9+, Git, Windows PowerShell, the FPC 3.2.2 Win64 bootstrap,
and LLVM Clang/LLD on PATH. `--bootstrap-bin` selects another bootstrap location;
`--output-root` must be empty. `--build-timeout` controls the allowance for each
fresh SDK build (default 1800 seconds); other steps retain their shorter timeout.
All commands and results are recorded under the
printed output directory.

Validation on 2026-10-09 passed **19/19 workflow checks**:
`C:\Users\kcollins\AppData\Local\Temp\nxpkg-sdk-1ej_6isf`. The shared-entry-point
runtime suite also passed **99/99**, and ordinary EXE/DLL coverage passed **32/32**;
see the [item 11 results](../../nexusfpc-dynamic-packages-gap-analysis.md#implementation-results-item-11).

## Late loading, unloading and publication (items 12-14 and 16)

```powershell
python tests\dynamic-packages\run_package_loader_tests.py
python tests\dynamic-packages\run_package_loader_tests.py --smart
```

Each run builds a fresh SDK unless `--sdk-root` selects an existing matching
normal/smart SDK. `--output-root` must be new or empty. LLVM RC and readobj are
required in addition to the SDK prerequisites. Commands and output are recorded
in `steps.json` and per-check logs.

Console/GUI hosts prove implementation DLLs are absent from startup imports and
run from relocated directories containing only runtime EXEs/DLLs. Coverage includes
repeated loads, diamond retention, class/RTTI identity, factories and managed
strings, typed exceptions, native/string resources, image-owned registry and
callback cleanup, restoration of overridden component initialization handlers,
native unmapping, reload and startup pinning.

Separate processes inject initialization/finalization/cleanup failures, exercise
new and already active dependencies, initialize/finalize/reload new TLS, reject nested lifecycle calls,
missing/non-package images, duplicate images, SDK/ABI/dependency mismatches, and
verify exception destruction before rollback releases the DLL. Failed compiler
and linker invocations preserve the previous generation, as do rejected stale
consumers. Artifact checks reject mismatched PCP/DLL pairs and manifest tampering.

The [load/unload design](../../nexusfpc-dynamic-packages-load-unload-design.md)
records the current contract, tradeoffs and final validation results.

## Unified threadvar storage

Rebuild a matching SDK, then run the same sequential suite on Windows or Linux:

```text
python tests/dynamic-packages/run_threadvar_package_tests.py --sdk SDK_DIRECTORY --output NEW_DIRECTORY
```

The suite checks a startup owner and 24 late owners, shared imported variables,
32-byte explicit alignment, managed strings, directory growth without moving
variables, repeated unload/reload, an independent native loader reference, and
initialization rollback. It creates no worker threads. Existing ordinary thread
manager and Win64 DLL contract tests validate the reused platform adapters.
The ordinary `tests/test/tthreadvarpointer.pp` regression also checks direct and
interior pointers into threadvar blocks through HeapTrc on both platforms.

The [design and validation report](../../nexusfpc-threadvar-design.md) records the
new ABI, measured costs and the remaining multithreaded lifecycle restriction.
