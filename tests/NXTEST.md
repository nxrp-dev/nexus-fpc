# NexusFPC native tests

[nxtest-suites.json](nxtest-suites.json) indexes the 15 native projects and 19
specialized native programs with their build adapters and required inputs.
[NXTEST-AUDIT.md](NXTEST-AUDIT.md) records the coverage/retirement audit,
including the remaining compiler inputs, integration workloads and examples.
[Unresolved failures](NXTEST-FAILURES.md) lists every migration skip with the
observed diagnostic and follow-up. There is one implementation of each migrated
behavior; punit, its runner, the old dotest/redirection/reporting programs, and
the obsolete FPCUnit console configuration have been removed.

## Build and run

From the sibling Nexus checkout, configure its existing
`projects/nxbuild/nxbuild.environment.nxscript` with a matching NexusFPC compiler
and RTL. Build a listed project with:

```sh
nxbuild /action=build /project=packages/nexus-packages/fcl-base/tests/FCLBaseTests.nxproject
```

Projects put outputs under the configured `Tools.OutputRoot`, followed by
`nexus-fpc-tests/<native-target>/<owner>`. The relocated FCL Base suite instead
uses `fcl-base-tests/<native-target>`. Run the program in its output directory. Tests register
directly with `TNXTestRegistry`; no FPCUnit/punit bridge, RTTI discovery adapter,
or replacement assertion framework is used. Categories are registered alongside
cases for nxtest clients. The console prints stable suite/case IDs and reports
passes, failures, errors, and skips independently.

| Project / program | Suite boundaries and categories | Output owner |
|---|---|---|
| [FCLBaseTests](../../nexus/packages/nexus-packages/fcl-base/tests/FCLBaseTests.nxproject) | Collection types, ordered-container lifecycles, base encodings, chained/buffered/LZW streams, configuration, CSV/templates/masks, atomics, expression scanner/nodes/operations/aggregates; builtins split into math, strings, dates, conversions, conditionals and aggregates | `fcl-base` |
| [RTLObjPasTests](../packages/rtl-objpas/tests/RTLObjPasTests.nxproject) | RTTI types/values/invocation/interfaces/cache, vectors/matrices/quaternions, monitor synchronization, dates, ANSI/Unicode comparisons, Unicode search/transformation/format buffers/helpers, and Variant negation | `rtl-objpas` |
| [RTLGenericsTests](../packages/rtl-generics/tests/RTLGenericsTests.nxproject) | Arrays, lists, dictionaries, hash maps, sets, queues/stacks, trees, error contracts, string hashing and adversarial sorting | `rtl-generics` |
| [RTLCollectionsTests](test/units/fpcunit/RTLCollectionsTests.nxproject) | Lists, buckets, linked lists, collections, components/persistence, parser and component/resource streaming | `rtl-collections` |
| [RTLRegressionTests](rtl/RTLRegressionTests.nxproject) | System strings/files/memory/arithmetic, SysUtils, date/math/type helpers, Unicode classification/conversion/collation/wide strings and platform RTL APIs | `rtl-regressions` |
| [CompilerUtilsTests](utils/unittests/CompilerUtilsTests.nxproject) | Fixture-directive parsing, including options, targets, expected exits and negative compilation; artifact identity packing, field independence and boundary values | `compiler-utils` |
| [CompilerRecompileTests](tppu/CompilerRecompileTests.nxproject) | Saved units, dependency invalidation, inline bodies, cycles and recompilation boundaries | `compiler-ppu` |
| [PasZLibTests / NXPasZLibTests](../packages/paszlib/tests/PasZLibTests.nxproject) | Compression streams and seeking, gzip, shared CRC32, archive files/entries/names and Zip64 | `paszlib` |
| [ReadOnlyGzipTests](../packages/paszlib/tests/ReadOnlyGzipTests.nxproject) | `NO_DEFLATE` reader/rejected-writer contract; separate compilation is required by the define | `paszlib-readonly` |
| [NXProfilerTests](../packages/nexusprofiler/tests/NXProfilerTests.nxproject) | Trace serialization/truncation/malformed input/file APIs; event-memory publication, reuse, pool limits and concurrent producers | `profiler` |
| [NXPackageStorageTests](dynamic-packages/NXPackageStorageTests.nxproject) | Package envelope roundtrip, malformed storage and obsolete-version rejection | `package-storage` |
| [NXPackageLifecycleTests](dynamic-packages/NXPackageLifecycleTests.nxproject) | Descriptor validation, diamond initialization, failed-load rollback and finalization; isolated process owns the global package registry | `package-lifecycle` |
| [ResourceTests](resource-formats/ResourceTests.nxproject) | Catalogs, form/type-library inputs, emitted table layouts, tool execution/encoding diagnostics and transactional artifacts | `resources` |
| [CollationDataTests](test/units/fpwidestring/CollationDataTests.nxproject) | Original Unicode ZIP members, lengths/checksums, repeated loads, malformed/missing inputs and stream ownership | `collation-data` |
| [NXSharedLibraryTests](linker/NXSharedLibraryTests.nxproject) | SONAME/exact filename/path/archive lookup and cached-unit linking | `linker` |

### Runtime fixture preparation

`RTLRegressionTests` accepts four arguments:

```sh
RTLRegressionTests /path/to/nexus-fpc /path/to/ppcx64 /path/to/matching/rtl /tmp/nexus-rtl-results
```

Its [manifest](rtl/fixtures.tsv) records suite ownership, source inputs, the rare
compile-only override, helper executables, implied platform restrictions, and documented skips. Compiler options, target/CPU
constraints, expected errors/nonzero exits, and interactive/no-run contracts are
read from the fixtures by the existing `tsutils.GetConfig` parser, also covered
by `CompilerUtilsTests`. Each case copies its local inputs into a unique run
and case directory, writes compiler outputs there, bounds subprocess execution,
rejects internal compiler errors, and retains arguments/compile/runtime logs.
`texec2` builds its `texec1` helper privately; the DOS fixture also declares its `hello` helper; standalone `texec1` also retains
its intentionally nonzero exit contract.

Files under `rtl/fixtures` are subprocess inputs, not a second unit-test runner.
Their process boundaries preserve termination codes, initialization, program
identity, compiler modes, and file effects. The former `test/units` runtime
fixture directories moved here without rewriting their assertions. Shared
legacy-object input paths and resource integration consumers were updated.
The Unicode conformance inputs remain in their existing shared location because
the separately owned RTL Unicode package also consumes them.

The collation-data program needs `CollationTests.zip` copied beside its binary.
The compiler-recompilation suite needs staged fixtures and precompiled Variants;
see [its existing preparation instructions](tppu/NXTEST.md). The linker suite
accepts the toolchain/output arguments documented in [its guide](linker/README.md).
The Unicode-default comparison case explicitly skips with an ANSI-default RTL;
see TEXT-001 in the failure register. Explicit Unicode API cases run normally.

### Resource and compiler-unit contracts

`ResourceTests` selects `catalog`, `inputs`, `tables`, `tools`, or `artifacts`
followed by that group's fixture arguments. The retained
`resource-formats/Run-NXResource*Tests.sh` scripts build required resources and
then run native nxtest cases before their independent object/link checks.
They do not implement a second assertion framework. Image-reader cases are
registered per image, including malformed relocation checks; metadata, native
resource API and compiler-emitter probes also register native cases.

The compiler-unit programs `systemids/nxsystemids.pas`,
`compiler-regressions/cpu_models.pas`, `x86_movzx_memory_operand.pas`,
`little_endian_metadata.pas`, and `dynamic-packages/NXPackageMetadataTests.lpr`
now register native nxtest cases. Their matching backend/compiler-unit build
contracts remain in their existing integration scripts. They must not link an
arbitrary compiler-unit cache. Package metadata negative cases use the explicit
`--expect-rejection` option and pass only when the expected compiler rejection
occurs. Compiler unit/backend boundaries and embedded-resource build variants
justify these separate executables.

`clangassembler/NXClangBackendTests.lpr` consolidates assembler registration,
LLVM target triples, default/explicit linker selection and archive registration.
Its native suites register cases per inspected target. The same runner builds
against each backend's matching compiler units; see its
[build guide](clangassembler/README.md). Native numeric programs under
`compiler-real` retain their fresh/cached-unit and package-ABI build boundaries.
The floating streaming and byte-order option recipes also run native cases.

`NXProfilerTests control <trace> <required> <forbidden> <forbidden>` registers
only `Profiler.Control.Interval`. The instrumentation integration adapter uses
that case for each generated interval. The old control assertion probe is gone;
the trace-count reporting utility remains an integration input.

The compiler language/code-generation corpora (`tbs`, `tbf`, `test`, `webtbf`),
ABI/package/export/link scripts, profiling instrumentation programs and
benchmarks, plus Windows COM/OLE demonstration applications, are compiler
inputs or integration/performance/example workloads, rather
than additional unit-test frameworks. Their separate orchestration backlogs
remain documented in [python-runner-retirement.md](python-runner-retirement.md).

## Consolidation decisions

- The 27 punit units now register native cases in the FCL owner. Expression
  parser cases omitted by the old runner are included. Fixture setup/teardown
  runs for each case, including cleanup after assertions or exceptions.
- Five ordered-container modules had 22 overlapping create/count/push/pop/peek
  cases. Four lifecycle cases now cover pointer stack/queue ordering, empty
  behavior, counts, `AtLeast`, return identity, nondestructive peek and both
  object-typed facade APIs. The artificial ordered-list subclass duplicated the
  same inherited implementation and is gone. Object ownership tests for the
  separate list/hash implementations remain distinct.
- Builtin evaluation, node semantics, scanner tokens, aggregate propagation and
  parser conversion remain separate boundaries. The parser creation-only check
  is consolidated into numeric literal evaluation; unused placeholder assertion
  helpers were removed. Scanner rejection tests now
  call the real scanner; the old helper merely raised the expected exception.
  Floating assertions retain the original explicit/default tolerances.
- `tczipper`, `tczstreamseek`, and `testsingle` were replaced by native archive
  cases. ZIP entries/content/empty/65,537-entry boundaries, file APIs, filename
  rules, save-to-file, selected-member extraction and seek errors remain.
  `CompressSmallStreams` compared an entry's size with that same entry object;
  it added no size assertion. Its default/stored small-stream creation paths
  are consolidated into `StreamEntries`, which also verifies decoded bytes and
  stored size against the independent original length. The optional archive viewer and unused ZIP fixture are gone.
  New archive fixtures own and free their streams and temporary files.
- The standalone vector/matrix/quaternion print driver `tv.dpr` duplicated the
  numbered native vector tests and supplied no additional assertions. It was
  removed; rotation/projection/handedness/layout assertions remain native.
  The separate DateOf regression was migrated into `RTL.DateUtils`.
- The standalone sorting workload now supplies native string/Single adversarial
  cases in the generic suite. All original sizes, random/adversarial orders,
  correctness assertions and comparison-growth bounds remain; there is no
  separate benchmark-style pass/fail runner.
- Equal-string storage/hash consistency moved from the resource-format runner
  into `Generics.Hashing`; stream seek moved into `PasZLib.Streams`. CRC32 operand
  encoding stays with the compiler-instruction contract because it tests emitted
  byte/word/dword/qword instruction forms and CPU capability independently.
- Profiler format/event-memory programs and package lifecycle/metadata drivers
  have one native implementation each. The duplicate profiler-format script,
  punit framework/runner/generator, obsolete dotest/redirection/digest programs,
  database schemas, and FPCUnit console defaults were removed. The tested shared
  directive parser remains and is reused by the native RTL fixture suite.
- Five explicit Unicode/ANSI API programs, the legacy-name Unicode search
  program and the Unicode-default comparison probe now belong to RTLObjPas.
  Shared data literals are grouped by API behavior; explicit entry points,
  legacy-name overloads, helper methods and default-type aliases remain distinct
  contracts. The Unicode-default alias case requires a matching text model.
  Variant negation retains result subtypes, all integer boundaries, floating and
  Currency values, ordinary/by-reference paths and unchanged referenced storage.
- Artifact identity's nine checks become two CompilerUtils cases. The two
  Clang programs and SDCC archive-registration program become one native backend
  runner, with assembler, linker and archive suite boundaries. The numeric
  regression drivers retain exact low-bit/rounding/ABI assertions and use native
  contexts; saved FPU exception masks are restored even after failed assertions.

See [NXTEST-VALIDATION.md](NXTEST-VALIDATION.md) for measured results and platform
limits; skips are listed separately from passes.
