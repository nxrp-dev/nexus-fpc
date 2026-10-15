# Cases retained for nxtest

On 2026-10-12 the owner directed removal of the eight Python runners, with their
cases recorded for later nxtest integration. This is a coverage backlog, not a
claim that nxtest currently executes these cases. Existing Pascal fixtures,
PowerShell suites and historical results remain. No replacement ad hoc runners
were added. The deleted implementations are recoverable from git revision
`3931c16b43c5865767a5746cd00bf76af3a01927` at the paths listed below.

All future harnesses should use private outputs, matching compiler/RTL artifacts,
sequential execution, explicit expected diagnostics and exit codes, and reject
internal compiler errors. Source-hidden and cache checks must compare the saved
PPU/object hashes before and after the consumer builds. Some fixture names below
are historical; reconcile them with consolidated test groups when integrating.

## Compiler generic sets and CORBA strings

Former runner: `compiler-regressions/run_compiler_regressions.py`.

- Build and run generic sets in Delphi and ObjFPC modes: `tw40453.pas`,
  `tb_generic_set_operations_objfpc.pas`, `tb_generic_set_literals_delphi.pas`,
  `tb_generic_set_literals_objfpc.pas`; repeat Delphi literals at `-O2`.
- Preserve literal membership, mixed elements, ranges, union/difference, nested
  routines, expression evaluation counts, enum/Byte specializations and unused
  declarations, including fixed `set of Byte` destinations.
- `tw6036a.pas`, ordinary and `-O2`, and `tb_corba_string_ids_short.pas` cover CORBA
  identifiers converted to supported strings, bounded truncation and `{$H-}`.
- Reject `tb_generic_set_invalid_object.pas` and `_invalid_range.pas` with illegal
  set element diagnostics; reject `_literal_object.pas` and `_literal_string.pas`
  with ordinal-expression diagnostics; reject `tb_corba_id_invalid_integer.pas`
  and `webtbf/tw6036b.pas` as incompatible types. `tbf/tb0215a` through `e` must
  produce ordinary errors without internal exceptions.
- Compile `ugeneric_set_storage.pas` separately, hide its source, and build/run
  `tb_generic_set_storage.pas` twice without modifying the saved PPU/object.

## Profiler mixed caches

Former runner: `nexusprofiler/run_profile_cache_tests.py`.
Fixtures: `packages/nexusprofiler/tests/profiler_smoke.pas`, its companion unit,
and `nxprofile_trace_probe.pas`; runtime sources under `packages/nexusprofiler/src`.

- Build the trace reader unprofiled in a separate cache. For ordinary and smart
  linking, build a profiled `NXProfilerRuntime` at `-O2`, compile an ordinary
  probe into the application cache, then build the profiled smoke at `-O-`
  with debug information without `-B`. The invalidated implicit runtime must rebuild.
- Each smoke emits one trace: calls=8, normal_returns=7, unwinds=1, unmatched=0,
  lost=0, trace_end=1, truncated=0. Repeated builds preserve valid runtime and
  application PPU/object hashes and still produce this trace.
- Profiled-to-ordinary builds remove `nxp_enter`, `.nxprof`, `nxp_` and
  `__NXP_specific_handler` from the relevant objects/EXE, run successfully and
  create no trace. Switching back retains deliberately unprofiled units until
  `-profile -B` restores instrumentation and the complete trace.
- Source-only implicit runtime: a program with no uses clause calls `nxp_flush`;
  the compiler finds/builds the runtime and execution creates one trace.
- Missing runtime: report `Can't find unit NXProfilerRuntime`.
- Stale runtime: change an interface constant in NXProfile, rebuild its probe,
  hide NXProfilerRuntime source, then require unit/checksum/source-not-found
  diagnostics instead of internal error `2026032615`.

## Artifact identity

Former runner: `artifact-identity/run_artifact_identity_tests.py`.
Retained fixture: `artifact-identity/identity_encoding.pas`.

- Build independent upstream and Nexus versions of a unit whose Marker returns
  37; verify PPU versus NXU208 signatures and a source-hidden Nexus round trip.
- Reject upstream-family units, including equal numeric revisions, before
  interpreting deliberately corrupt target fields. Upstream must also reject
  Nexus-family units even when their numeric revision is changed to match.
- Reject wrong header and long revisions, including pre-standard-package long
  revision 34 versus 35; preserve independent identity fields above 255 and at
  the maximum 32-bit revision.
- If source is available beside a foreign-family PPU, rebuild it as NXU and run.
- `ppufiles` and `ppumove` must accept valid Nexus units and reject wrong family,
  header and long revisions without changing rejected inputs or queuing linker
  work. Valid ppumove preserves NXU and queues its expected link commands.
- Accept NXP004 metadata and reject same-number PCP004 metadata in all active
  readers. The native Forge reader now owns build-path validation; do not recreate
  the retired Python validator as a separate implementation.
- Preserve runtime v4 descriptor identity checks, foreign embedded-unit rejection
  and low/high compiler identity mismatch checks in the retained Pascal fixtures.
- Replace the retired runner's Lazarus seed path with the current supported
  toolchain when implementing these cases.

## Linux unit exports

Former runner: `unit-exports/Run-NXLinuxUnitExports.py`.
Fixtures: `utNXLinuxExports.pas`, `nxLinuxExports.lpr`, `nxLinuxExportsLibrary.lpr`.

- Ordinary and smart linking; library cold/cached, program standalone/cold/cached.
  Hide unit source for cached builds and preserve PPU/object/archive hashes.
- Verify `NX_LinuxMarker`, `NX_LinuxAutomatic`, `NX_LinuxData`, `NX_LinuxMain`,
  `PlainMarker` and `UTNXLINUXEXPORTS_$$_PLAINMARKER$$LONGINT` in the linked image.
  Smart linking removes the unused non-exported DiscardMarker.
- Run programs and load each library in a fresh Pascal probe. Require Marker(5)=47,
  Automatic=77, Main=99, both PlainMarker exports=55, writable data initially 1234
  and still 4321 after assignment. Preserve the C ABI declarations.
- Reject duplicate `NX_LinuxMarker` exports in cold and cached builds; reject
  `exports Marker index 7` on Linux with an unsupported-ordinal diagnostic.
- A Windows cross compiler can produce objects for Linux linking, with explicit
  Windows/WSL path conversion. That is a validation option, not a requirement to
  retain the old temporary linker-script driver.

## Linux package runtime and publication

Former runner: `dynamic-packages/run_linux_package_tests.py`.
Fixtures: `examples/dynamic-packages`, `package_loader_failures.pas` and
`package_native_probe.pas`.

- Ordinary/smart and fresh/source-hidden cached units. Cached builds must leave
  all saved PPU/object/archive hashes unchanged.
- Startup providers demotypes/demoleft/demoright: shared class/RTTI identity,
  managed ownership and exact trace `init=BLRH`, `PASS console`, `final=h`,
  `final=r`, `final=l`, `final=b`. No R_X86_64_COPY relocations.
- Late providers democontracts/pluginbase/pluginleft/pluginright: resources,
  registries, actual unload/reload and trace `PASS late console`, `CBLRlrbBLlb`.
  The executable directly needs democontracts, not pluginbase/pluginleft.
- Native mapping alone must leave all six lifecycle-state words zero in v4
  descriptors. Require the exact compiler identity, without Pascal activation.
- Run runtime-only relocated outputs from a different working directory without
  LD_LIBRARY_PATH or LD_PRELOAD. `$ORIGIN` must find the complete dependency set.
- ABI, SDK and dependency-build corruption at startup must fail before user
  initialization, with exit 217 and EPackageError diagnostics.
- Preserve all `package_loader_failures.pas` modes: init, new-dependency,
  live-dependency, cleanup, finalization, callback, tls, nested-load, nested-unload,
  non-exception, missing, not-package, duplicate, sdk, abi, dependency.
- Generated fixtures formerly supplied the modes: partial initialization registers
  FailedAlias then raises a package-local exception whose destructor appends D;
  newly loaded/live dependency rollback; cleanup that raises while rolling back;
  finalization and registered callback exceptions; threadvar zero initialization
  and value retained through finalization; LoadPackage from initialization;
  self-UnloadPackage from finalization; and a raised TObject with a destructor.
  Recreate these as Pascal fixtures when wiring the retained host into nxtest.
- A plain shared library whose dependency exports FPC_PACKAGE_INFO must still be
  rejected as not a package; copying a package under another filename must not
  create a second logical owner.
- Compile failure, link failure and stale provider replacement preserve current.json
  and all selected artifacts. Reject changed bundle hashes, PCP/ELF identity or
  dependency mismatches, malformed section counts, invalid symbol-string-table
  links and relocation symbol indexes. Reject a tampered SDK before compilation.
- Build with a relocated source-free SDK and verify its artifact hashes remain
  unchanged. Linked shared objects must contain no TEXTREL entries.

## Linux unified threadvars

Former runner: `dynamic-packages/run_linux_threadvar_package_tests.py`.
Fixtures: `threadvar_contracts.pas`, `threadvar_provider.pas.in`,
`threadvar_package_host.pas`.

- Build tvcontracts, expand the provider template for indexes 0..25, and build
  tv0..tv24. Index 25 is tvfail and adds a unit with a zero-initialized LongInt
  threadvar, assigns 18, then raises `threadvar-init-failure` in initialization.
- Build the host requiring tvcontracts and tv24, supply all provider images,
  and require `PASS unified package threadvars`. Retain all assertions already
  present in the host and template. No new worker threads are required.

## Linux SDK integration

Former runner: `dynamic-packages/run_linux_package_sdk_tests.py`.

- The old make SDK builder is retired. Resume source-only native Linux SDK
  construction through Forge when that separately deferred work is authorized.
- Preserve source hashes across builds; source input contains no generated
  message includes or RTL units. Exercise ordinary/smart consumers, fresh/cached
  units, lifecycle fixtures, and ordinary compiler/unit exports.
- Compile a GNU-assembler package owning a class with a managed string and verify
  class identity and its value from a consumer.
- A rebuilt standard compiler supports both package declarations and a static
  SysUtils/Classes program; the static program must not depend on libnxrtl.so.
- Relocate only distributed SDK artifacts, supply provider PCP/SO pairs and host
  source, hide original source/SDK/build trees, then compile and run from `/`.
  SDK and source hashes must remain unchanged.

## Linux package-support timings

Former runner: `dynamic-packages/run_linux_package_support_benchmarks.py`.
Fixtures: `dynamic-packages/benchmarks/package_bench.pas`, `PackageBenchData.pas`.

- Compare two fully built compiler/RTL pairs; record their hashes, platform,
  command lines, executable sizes and all raw samples.
- Warm compilation/runtime caches, alternate candidate/baseline order and execute
  sequentially. Default seven samples, including three compiler-build samples;
  require at least three of each and compiler samples no greater than total.
- Measure forced `-O2 -B` fixture builds, identical compiler-source rebuilds,
  200,000,000 global operations and 2,000,000 managed operations. Require identical
  runtime checksums throughout and a working version query from rebuilt compilers.
- Report median/minimum/maximum and candidate median percentage change for each
  workload. This is a future benchmark task, not a build dependency.
