# Compiler package regressions

Windows package validation uses PowerShell and the standard package-enabled
compiler. Build from the stock **FPC 3.2.2 i386-win32** bootstrap; a new Nexus
seed is not required. LLVM Clang/LLD, RC and readobj must be on `PATH`.

From the repository root:

```powershell
./tests/dynamic-packages/Run-PackageSDKTests.ps1 `
  -BootstrapBin C:/lazarus/fpc/3.2.2/bin/i386-win32 `
  -OutputRoot output/package-validation -FullSuite
```

Use a new or empty output directory. The runner copies tracked and new,
non-ignored compiler/RTL/build/example sources into an isolated source snapshot.
It builds one matching SDK for each normal/smart-link configuration through
`Build-NexusFPCPackageSDK.ps1` and the shared `NexusFPCBootstrapSeed.ps1`.
`-FullSuite` adds all Windows package suites and the Extended/shared-RTL math
regressions. Omit it to run just SDK construction and relocation checks.
Each suite writes `steps.json` and individual command logs. Expected failures
must match both their exit status and diagnostic text. Tests execute sequentially;
the native DLL probes run in separate Pascal processes.

Individual suites accept an existing matching SDK:

```powershell
./tests/dynamic-packages/Run-PackageMetadataTests.ps1 -SdkRoot SDK -OutputRoot output/pkg-metadata
./tests/dynamic-packages/Run-PackageLinkTests.ps1 -SdkRoot SDK -OutputRoot output/pkg-link
./tests/dynamic-packages/Run-PackageRuntimeTests.ps1 -SdkRoot SDK -OutputRoot output/pkg-runtime
./tests/dynamic-packages/Run-PackageLoaderTests.ps1 -SdkRoot SDK -OutputRoot output/pkg-loader
./tests/dynamic-packages/Run-ThreadvarPackageTests.ps1 -SdkRoot SDK -OutputRoot output/pkg-threadvar
```

Metadata/link/runtime use the complete SDK build, including its matching static
RTL and staged compiler sources under `work/`. Loader/threadvar use the SDK
compile helper and accept `-SmartLink` with a matching smart SDK.

## Coverage

| Suite | Checks |
| --- | --- |
| Metadata | Case-insensitive identities, display spelling, direct-requirement promotion, duplicate diagnostics, diamonds, self/indirect/building-package cycles, conflicting owners in both orders, real writer round-trip, unchanged source PPU, repeated loading and bounded unit streams. Independently encoded NXP v4 containers include empty/multiple units, opposite-endian metadata, 1,600 requirements crossing the buffer boundary, malformed headers/counts/names/entries/checksums/tables, overlapping ranges and malformed/foreign embedded units. Source-free PCP consumption and normal compiler package declarations are tested. |
| Link | Normal/smart linking with fresh/cached units. Only PCP/DLL files remain available to consumers; cached PPU/object hashes must stay unchanged. PE imports must resolve to exports. Native probes check writable globals, class/enum/record RTTI, VMTs, resources, public aliases, procedure pointers, parent/inherited dispatch, managed-record metadata and inline implementation-helper calls. Negative cases cover missing System/units and duplicate owners. |
| Runtime | Four fresh/cached, normal/smart configurations. Independent descriptor inspection checks ABI, compiler/target/RTL identity, owners, dependencies, native handles and inactive contexts after native loading. Synthetic lifecycle checks and real hosts cover diamond initialization once, reverse finalization, rollback, resumable cleanup, shared objects/strings/arrays/interfaces, typed exceptions, resources, wide constants and unreferenced contained units. All cross-image imports must resolve. |
| SDK | Source-only normal/smart builds; unchanged input sources; ordinary static hosts without nxrtl imports. Relocation copies only SDK distribution files and provider PCP/DLL pairs, hides the original source and SDK, then builds/runs console and GUI hosts. Exact lifecycle output, PE target/subsystem, runtime DLL set and unchanged SDK hashes are checked. |
| Loader | Console/GUI startup import inspection and runtime-only relocation; repeated loads, diamond retention, identity, factories, managed values, exceptions, resources, registry/callback cleanup, component-handler restoration, native unmapping, reload and startup pins. Separate processes exercise initialization/finalization/cleanup failures, active/new dependencies, TLS, nested calls, missing/non-package/duplicate images and SDK/ABI/dependency mismatches. Failed compilation/linking and stale consumers must preserve publication; mismatched PCP/DLL pairs and tampered manifests must be rejected. |
| Threadvar | One startup owner and 24 late owners, imported variables, 32-byte alignment, managed strings, directory growth without moving variables, unload/reload, independent native references and initialization rollback. No worker threads are created. |
| Compiler real | Extended package parameters/results/callbacks/records/var parameters, Math ABI and unchanged shared-RTL numeric regressions. |

`NX_BaseCounter` and the other `NX_Base*`/`NX_Consumer*` symbols are test exports,
unrelated to the profiler. Native loading in the symbol/descriptor probes only
maps DLLs; generated EXE startup or `LoadPackage` performs Pascal activation.
The source-free metadata consumer uses `-Cn`; linking and lifecycle are verified
by the other suites.

The PowerShell migration preserves the cases from the retired Windows metadata,
link, runtime, SDK and loader Python runners. It shares SDK construction instead
of separately bootstrapping obsolete stock-Win64 compiler builds in every suite.
Native descriptor checks derive the compatibility revision from current source;
there is no stale hard-coded revision 35 expectation. Current artifacts use
NXP v4 and NXU header 208, compatibility revision **39**.

## Timings

For a sequential comparison of two fully bootstrapped Win64 trees:

```powershell
./tests/dynamic-packages/Run-PackageSupportBenchmarks.ps1 `
  -BaselineRoot BASELINE -CandidateRoot CANDIDATE `
  -OutputRoot output/package-timings
```

The runner warms caches, alternates baseline/candidate order, checks runtime
checksums, and saves every wall-time sample plus median/minimum/maximum,
compiler/RTL hashes and executable sizes in `timings.json`. Run it without other
builds or benchmarks competing for the machine. It compares fixture builds,
compiler rebuilds, writable globals and managed-value workloads.

## Linux glibc

The existing Linux harnesses are unchanged by the Windows migration:
`run_linux_package_sdk_tests.py` covers source-only normal/smart SDK construction,
fresh/cached runtime cases, ordinary compiler/export checks and relocation.
`run_linux_package_tests.py` accepts an existing SDK. Linux threadvar and timing
harnesses remain separately named with the `run_linux_` prefix.
No Linux execution is implied by a Windows bootstrap or cross-RTL build.

See the [Linux guide](../../nexusfpc-dynamic-packages-linux.md),
[SDK guide](../../examples/dynamic-packages/README.md),
[runtime design](../../nexusfpc-dynamic-packages-runtime-design.md),
[load/unload design](../../nexusfpc-dynamic-packages-load-unload-design.md),
[threadvar design](../../nexusfpc-threadvar-design.md) and
[native floating-point policy and validation](../../nexusfpc-native-real-design.md).
The ordinary EXE/DLL and Win64 ABI suites remain separate integration checks.
