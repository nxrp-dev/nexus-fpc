# Unit-test ownership and retirement audit

Audited against migration baseline `4f78c6c072c538cb2514a0a8226d53bca982cdf0`
and the current source tree. The audit followed behavior and build consumers,
including standalone programs outside directories named `unittests`.

| Original coverage | Current owner / disposition |
|---|---|
| FCL punit units, including unregistered expression parser tests | FCLBaseTests; direct native callbacks and per-case setup/cleanup. Five overlapping ordered-container modules consolidate into four lifecycle cases. The punit framework, runner and unused LZW generator are removed. |
| Existing RTL/generic/collection/compiler utility and recompilation native units | Retained native owners, with categories and consistent output paths; no compatibility runner. |
| PasZLib `tczipper`, `tczstreamseek`, `testsingle` | Native archive/stream cases in NXPasZLibTests; originals and unused ZIP/viewer input removed. Distinct NO_DEFLATE compilation remains separate. |
| RTL `tdateof`, generic sorting workload, resource string hashing | RTL.DateUtils, native generic adversarial sorting and Generics.Hashing. The print-only `tv.dpr` is redundant with native numbered vector/matrix/quaternion assertions and is removed. |
| Profiler event-memory, trace-format and controlled-interval assertion programs | NXProfilerTests normal suites and optional Control suite. All three old assertion programs and the duplicate format script are removed. |
| Package storage, lifecycle and metadata unit contracts | Native storage/lifecycle owners and metadata driver. Lifecycle's global registry requires process isolation. Compiler-unit metadata and expected-rejection build variants remain in the existing adapter. |
| Resource catalog, input conversion, tables, tools and artifact transaction algorithms | One ResourceTests program, five semantic groups; five original assertion programs removed. Metadata, linked-resource runtime, image reader, compiler emitter, file info and instruction-width variants use native drivers because their inputs/build boundaries differ. |
| 26 runtime directories formerly under `test/units` | 216 Pascal inputs plus support/data move to `rtl/fixtures`. The native manifest owns every standalone test input; helper units, `hello.pas` and the retained `tgenstr` data generator are not separate cases. The 233 relocated files are byte-identical. |
| Shared `test/units/fpwidestring` inputs | 22 standalone/conformance cases in the RTL manifest, plus the existing native collation-data owner. Inputs stay at the shared path used by the separate Unicode package. |
| `textmodel` ANSI comparisons, explicit/legacy Unicode searches, transformations, buffer formatting, string helpers and Unicode-default comparisons | RTLObjPas native text suites; seven original programs removed. Explicit APIs, overloads, helpers and default aliases test different contracts. TEXT-001 isolates the unavailable Unicode-default SDK configuration. |
| `variants_byref_negation.pas` | RTLObjPas `RTL.Variants.Negation`, preserving all original signed/unsigned, source-preservation and result-subtype checks. Original removed. |
| `artifact-identity/identity_encoding.pas` | Two CompilerUtils artifact-identity cases, preserving all nine original assertions. Original removed. |
| `nxclangregistration`, `nxllddefaults`, `removed_sdcc_registration` | One NXClangBackendTests runner with assembler, linker and archive suites; original programs removed. Backend-specific compiler-unit closures and all target tables remain supported. |
| Numeric core, Extended ABI, math ABI, numeric property RTTI and cached real constants | Five existing special-build programs now register native cases; no counters/Halt assertion runners. Their Windows and shared-package consumers pass nxtest search paths. Different compiler/cache/package inputs justify these existing build boundaries. |
| Native floating streaming, platform byte-order conversions, CPU models, MOVZX pass, artifact headers and stored target identities | Native cases in their existing integration build recipes. FPUNone's formerly compile-only positive program now runs its two streaming cases. |
| Old discovery/reporting support | dotest, digest/redirection/failure utilities, SQL schemas, obsolete sample settings and FPCUnit console defaults removed. The production fixture-directive parser remains, is covered by CompilerUtils and is reused by RTLRegressionTests. |

## Retained inputs and workloads

These sources have an independent purpose and are not duplicate unit-test
implementations:

- `tbs`, `tbf`, `test` and `webtbf` are compiler language/code-generation inputs:
  positive and negative syntax, mode-dependent typing, constant folding, emitted
  RTTI, calling conventions, intrinsics and optimizer behavior. Compiler fixtures
  can use RTL units without becoming another RTL unit runner. For example,
  `tw38642` is a compile-only generic enum specialization and `tw7071` tests
  overload selection for untyped versus stream parameters. Their compiler
  orchestration backlog remains in `python-runner-retirement.md`.
- Remaining `compiler-regressions` programs test generated code or compiler
  configuration: callback address optimization, optional short-string optimizer,
  VMT/message dispatch, retired JVM/MMX option controls and implicit HeapTrc
  compilation. The direct archive/Variant/numeric/byte-order unit checks found
  among them were migrated as listed above.
- Remaining `textmodel` sources test compile-time default aliases, forbidden
  source/config defines, mode conflicts, Windows API alias typing and saved-unit
  text-model compatibility. The runtime library API programs were moved into
  native suites; [its guide](textmodel/README.md) lists the boundary.
- Profiler `profiler_*` sources are instrumented compiler inputs and their helper
  units. Their exact call counts, unwind/termination behavior and trace generation
  require separately profiled builds. `nxprofile_trace_probe` reports counts to
  that integration adapter; it is not a second assertion runner. Benchmark inputs
  remain performance workloads.
- Multi-image ABI/export/package/Win64 contract programs require linked providers,
  native loaders, DLLs or C objects and inspect imports/relocations as well as
  runtime behavior. They remain integration fixtures and adapters. The optional
  high-precision `treference` and C++ vector generator remain characterization
  tools, not required numeric-contract passes.
- `winunits-base/tests` contains CHM viewers, Excel/OpenOffice automation,
  in-process COM client/server demos and version/codepage display examples. They
  launch external applications or display output; no independent library unit
  assertion suite was found there. `tests/bench`, `utils/bench`, `utils/fptime`,
  and package benchmarks are timing workloads; `utils/concat` is a file utility.
- `tests/tstunits` are expected runtime-error/message fixtures imported by
  compiler inputs; the kept directive parser and its reduced type record are
  shared infrastructure, not an alternative runner.

## Completion checks

The catalog includes every current native test entry program under packages and
tests, either as a normal project or a specialized program with a build adapter.
Retained adapters were checked for references to removed assertion programs and
moved fixture paths. In particular, both resource host adapters now use the
consolidated ResourceTests program, both runtime preparation adapters include
nxtest, and profiler interval checks use NXProfilerTests.

Validation, exact measured counts, skipped defects and unavailable platform/text
models are recorded separately in [NXTEST-VALIDATION.md](NXTEST-VALIDATION.md)
and [NXTEST-FAILURES.md](NXTEST-FAILURES.md). No compiler-language corpus,
Windows integration execution or missing SDK variant is reported as a new pass.
