# Native test migration validation

Migration baseline: `4f78c6c072c538cb2514a0a8226d53bca982cdf0`.

Validated on 2026-10-18 on native x86-64 Linux. All 15 projects in
[nxtest-suites.json](nxtest-suites.json) resolve with the actual Nexus nxbuild
`/action=plan`. Their resolved compiler commands build successfully with only
`-FE`/`-FU` redirected to private `/tmp` output directories. The compiler reports
3.3.1; the installed Clang/LLVM tools are version 18.1.3.

The matching compiler/RTL came from the existing
`7b17fb63a7-work-9d9fc18cb8` native SDK:

- Compiler SHA-256: `ab9527a23a1669ce023edbd10fe635154a88e4c016dade5db0769cb71df948ce`
- System NXU SHA-256: `a235eeffd3566c87049403511aaaf03725f01a44d5d6f6be5e410a0f400bb46e`

## Core execution

| Program | Passed | Failed / errors | Skipped |
|---|---:|---:|---:|
| FCLBaseTests | 425 | 0 / 0 | 1 |
| RTLObjPasTests | 520 | 0 / 0 | 1 |
| RTLGenericsTests | 214 | 0 / 0 | 0 |
| RTLCollectionsTests | 269 | 0 / 0 | 0 |
| CompilerUtilsTests | 30 | 0 / 0 | 0 |
| CompilerRecompileTests | 30 | 0 / 0 | 0 |
| NXPasZLibTests | 20 | 0 / 0 | 1 |
| ReadOnlyGzipTests | 1 | 0 / 0 | 0 |
| NXProfilerTests | 8 | 0 / 0 | 0 |
| NXPackageStorageTests | 3 | 0 / 0 | 0 |
| NXPackageLifecycleTests | 1 | 0 / 0 | 1 |
| CollationDataTests | 5 | 0 / 0 | 0 |
| NXSharedLibraryTests | 10 | 0 / 0 | 0 |
| RTLRegressionTests | 213 | 0 / 0 | 17 |
| **Total** | **1,749** | **0 / 0** | **21** |

At migration completion, seven skips isolated the unresolved failures in
[NXTEST-FAILURES.md](NXTEST-FAILURES.md). Twelve are platform/interactive fixture
requirements, and TEXT-001 requires an unavailable matching Unicode-default SDK.
One is the formerly disabled, now explicit opt-in 4 GiB ZIP
workload. The 65,537-entry Zip64 case and concurrent profiler producer case run
normally and pass.

The adversarial sorting cases retain both strings and Single values, random
and quicksort-killer order, all three original input sizes, exact sorted-value
checks, and the original comparison-growth bound. The general suite also passes
when built with the CRC32 integration recipe's `-O2`, range, overflow and I/O
checks.

The recompilation suite uses its existing staging helper and precompiled
matching Variants. The linker suite builds and executes its tiny C/Pascal
fixtures. The collation tests stage the original ZIP; all three full UCA input
programs also pass through the RTL regression suite.

## Resource and compiler-unit contracts

These checks supplement the core count above; repeated target/image invocations
are not added to that total.

- Native resource groups pass: Catalog **12**, Inputs **7**, Tables **3**,
  Tools **6**, Artifacts **4**, Metadata **1**. The tool group retains all 13
  target macro configurations and malformed include/RC/encoding diagnostics.
- The resource integration recipes pass COFF conversion/inspection for x86,
  x86-64 and AArch64, ten ELF/Mach-O table target variants, two version-resource
  revisions, and the independently generated PE file-version fixtures.
- Image readers run as native cases per supplied image. Unsorted relocations and
  all five malformed-relocation mutations remain exercised for ELF images.
- The compiler resource emitter passes for the matching x86-64 backend closure:
  Linux, Android, Darwin and iPhoneSimulator emission, object/image generation,
  and native reader recovery of all 12 resource identities/languages/payloads.
- CRC32 instruction verification passes the independent CRC32C reference vector,
  **1,280** runtime source-width comparisons, and byte/word/dword/qword encoding
  inspection. The companion generic-suite run includes native string hashing.
- Native target identifiers pass; CPU models pass **143** assertions plus the
  existing six macro/POPCNT configurations; MOVZX passes **12** memory/register
  checks; NXU/NXP byte-order validation and retained platform conversions pass.
- The native package metadata driver compiles against the matching compiler-unit
  closure and passes names/deduplication, disabled loading and an explicitly
  expected missing-package rejection. Expected rejections produce passing native
  cases instead of intentionally failing test results.
- The combined Clang backend suites pass **9** native cases against the matching
  x86-64 compiler-unit closure: five assembler registrations, three linker
  defaults/overrides, and retained archive registration. Other backend closures
  remain supported by the source but are not claimed as validated here.
- All five native numeric drivers pass with both `-O-` and `-O2` on Linux x64.
  Repeated optimization invocations are not added to the core count. RTTI builds
  include its Generics/libffi dependency closure. At both optimization levels,
  cached constants pass fresh plus two source-hidden native runs; saved NXU and
  object SHA-256 values remain unchanged. The Windows adapters retain
  the separate native package/shared-RTL and source-hidden constant variants.
- The FPU option recipe passes **32** negative compiler diagnostics and **2**
  native numeric streaming cases. The byte-order recipe passes **2** native
  platform/conversion cases plus the existing native header case.
- The actual runtime-resource preparation adapter builds successfully; its
  native enumeration/lookup/language/payload/stream case passes for all **12**
  generated resource identities on Linux.
- Native profiler interval validation passes a generated required-procedure
  trace and rejects the deliberately missing-procedure control. Production
  profiled interval generation on Windows remains an unexecuted integration
  configuration, not a newly claimed pass.

## Resolved fixture issues

The final checks also verified the migration's fixture corrections: scanner
rejections call the actual scanner; resource tool cases initialize target and
input state independently; buffered/INI/archive/profile fixtures use private
GUID paths; atomic pointer-exchange tests retain stable cleanup owners. A
checked sorting run exposed a signed temporary used to save the unsigned
`RandSeed`; matching its Cardinal type resolves the range error without changing
sorting assertions. Array allocation now uses typed `SetLength` calls. These
resolved fixture issues are not additional unresolved skips.

## Preservation and limits

All **233** relocated fixture/support/data files were compared with their
pre-migration Git contents and are byte-identical. The fixture manifest has
**230 unique IDs in 32 logical suites**. The original assertions, binary input
payloads, and source directives remain available. The two RTL production-tree
edits update comments' moved test paths; compiler/RTL implementations are
unchanged.

All shell scripts touched by the migration pass `bash -n`; `git diff --check`
passes. Generated binaries, compiler units, fixture copies and logs stay outside
the checkout. Private fixture directories and stable ownership now allow native
assertions to unwind safely, including during pointer-exchange checks.

Windows runtime execution and the PowerShell package/profiler integration
adapters were not run on this Linux host. Neither the full Windows package
metadata corruption matrix nor other backend compiler-unit closures are claimed
as newly validated. Cross-format inspection is not execution on those targets.
The separate compiler-language/integration backlog is unchanged in scope.

Final command plans, compiler/runtime logs, source-move hashes and toolchain
fingerprints are retained locally under `/tmp/nxtest-migration-final`;
resource/backend integration evidence is under `/tmp/nxtest-migration`.

## FCL-001 follow-up: expression Boolean text

The migration counts above describe the original validation run. A subsequent
native x86-64 Linux run reproduces the enabled `booltostr` case's failure, then
passes all **426 FCLBaseTests cases with 0 failures, 0 errors and 0 skips** after
correcting the expression wrapper. The regression now checks both `True` and
`False`; its skip was removed. The general `SysUtils.BoolToStr` API and its
callers are unchanged. The other suites were not rerun for this one-wrapper
correction. See [NXTEST-FAILURES.md](NXTEST-FAILURES.md) for the remaining six
unresolved cases at that stage and the local before/after evidence location.

## PKG-001 follow-up: optimized symbolic address assignments

The corrected `OptPass1MOV` SIMD-copy rule excludes symbolic immediates
(`RefAddr = addr_full`). The lifecycle project now builds at `-O2` and replaces
its optimized-case skip with four native `Compiler.X86.MovePairs` regressions.
The existing full lifecycle assertions remain enabled in their own suite.

The original SDK compiler fails to assemble both new address cases. On
2026-10-18, the existing bootstrap script was run from the repository root:

```sh
python3 ../nexus-private/scripts/linux/bootstrap-nexusfpc.py \
  /media/kcollins/dev/source/nexus-fpc --allow-dirty \
  --toolchain-root /media/kcollins/dev/worktree/pkg-001-move-pairs/toolchain
```

It completed successfully with compiler cycles 2 and 3 identical and all 89 RTL
objects matching. All artifacts are under
`/media/kcollins/dev/worktree/pkg-001-move-pairs`:

- Installed SDK: `toolchain/nexus-fpc/x86_64-linux/d9f54ab727-work-da393de8fb`.
- Bootstrap logs: `toolchain/build/nexus-fpc-d9f54ab727-work-da393de8fb/logs`.
- Test commands, assembly, build/run logs and results: `validation`.

The script's optimizer source was checked against the corrected working-tree
file, and the installed compiler hash against its `build-identity.json`.
`validation/results.json` retains that compiler identity and SHA-256.

That installed compiler and matching RTL pass **5 cases with 0 failures, 0 errors
and 0 skips** for each of `-O1`, `-O2`, and `-O2 -CfAVX` on native Linux x64.
The test builds use the lifecycle project's compiler options with the installed
compiler/RTL paths and separate output directories. The two memory-copy controls
still emit MOVDQU/VMOVDQU; all variants preserve the exact lifecycle trace
`BLRHCF!fchrlb`. The shared nxbuild environment still points to its earlier SDK.
No cross-target validation was run.

The migration snapshot table above remains historical; other suites were not
rerun for this correction. Five RTL fixture failures and the Unicode-default
environment requirement remain in the failure register. The earlier
`/tmp/pkg-001-fix` experiments are diagnostic evidence. No build output is kept
in the source checkout.
