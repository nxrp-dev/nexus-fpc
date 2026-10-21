# Unresolved nxtest failures

Verified on native x86-64 Linux during the 2026-10-18 migration. These are
explicit skips, not accepted failures or relaxed assertions. The original
assertions/reproducers remain in their native cases or compiler-input fixtures.
Remove the corresponding skip only after reproducing the correction.

| ID | Native case | Observed failure | Suspected cause / follow-up |
|---|---|---|---|
| RTL-001 | `RTL.Dos.tdos` | `tdos.pas(133,27): Call by var for arg no. 4 has to match exactly: Got "AnsiString" expected "ShortString"`. | Legacy DOS `FSplit` string contract conflicts with Nexus string defaults. Choose explicit fixture types before enabling it. |
| RTL-002 | `RTL.Strutils.tstruth2bu` | Line 5: `MODE DELPHIUNICODE requires -MUNICODESTRINGS`. | The fixture does not select the required text mode. Its intended option contract remains unresolved. |
| RTL-003 | `RTL.Sysutils.twstrcmp` | Line 25: `Illegal compiler directive "MODESWITCH UNICODESTRINGS"`. | The fixture still uses a retired directive. Determine its intended ANSI/Unicode configurations. |
| RTL-004 | `RTL.Unix.ttimezone1` | Lines 12 and 30: `Identifier not found "Result"`. | The source uses `Result` without selecting a supporting language mode. Preserve the default-mode failure pending an explicit fixture configuration decision. |
| RTL-005 | `RTL.Unicode.WideStrings.tcpstr9fpwidestring` | Line 3: `MODE DELPHIUNICODE requires -MUNICODESTRINGS`. | Same configuration issue as RTL-002, through the wide-string provider. Keep the two API paths represented. |

The fixture skips are in `rtl/fixtures.tsv`; TEXT-001 calls
`TNXTestContext.Skip` directly. Unknown future failures remain failures; no
catch-all conversion from errors to skips exists.

## Reproduction

Use one matching NexusFPC compiler and RTL, with generated files outside the
source checkout. Build the projects listed in [NXTEST.md](NXTEST.md).

For an RTL fixture, clear **only that row's skip field** in `rtl/fixtures.tsv`
and run `RTLRegressionTests` again. It retains compiler arguments, complete
compiler output, and runtime output under a new run directory. The fixture
source's options and expected exit status are read by the existing, tested
`tsutils.GetConfig` parser.

## Resolved PKG-001: symbolic addresses in SIMD move merging

The generic x86-64 peephole optimizer's `OptPass1MOV` rule
`MovMovMovMov2MovdqMovdq` in `compiler/x86/aoptx86.pas` (around line 4475)
merges two adjacent 8-byte memory copies into one 16-byte SIMD copy. Its faulty
source operand check accepted `top_ref`, which represents both memory operands
and symbolic address constants. It omitted the `RefAddr <> addr_full` check
needed to distinguish the two.

The lifecycle trigger is `Dep[3,0]:=@Ref[1]; Dep[3,1]:=@Ref[2]`. A standalone
reduction requires no package or test-framework units:

```pascal
program AddressPair;
{$mode objfpc}
type PValue = ^PtrUInt; PPValue = ^PValue;
var Refs: array[0..2] of PValue;
    Slots: array[0..1] of PPValue;
begin
  Slots[0] := @Refs[1];
  Slots[1] := @Refs[2];
  if (Slots[0] <> @Refs[1]) or (Slots[1] <> @Refs[2]) then Halt(1);
end.
```

Correct scalar code stores the two addresses, loaded as `movq $Refs+8,reg` and
`movq $Refs+16,reg`. The faulty rule sees equal source symbols and offsets eight
bytes apart, then changes the load to `movdqu` while retaining `addr_full`.
The AT&T writer in `compiler/x86/agx86att.pas` correctly renders that address
constant with `$`; MOVDQU/VMOVDQU have no immediate-source form. Both Clang and
GNU as reject it. Removing `$` would read the contents at Refs instead of
forming the required addresses and would change program behavior.

Verified on a matching Linux x64 SDK:

- `-O-` passes; `-O1` and `-O2` reproduce the failure. `-O2 -CfAVX` reproduces
  the AVX form at compile time. Other OS/backend configurations were not run.
- `-O2 -OoNOPEEPHOLE` passes both the reducer and the full original lifecycle
  program, whose trace remains `BLRHCF!fchrlb`. `-O2 -Cg` also passes the reducer
  because address formation uses a different instruction pattern.
- An isolated diagnostic compiler logs the exact rule accepting `RefAddr=1`
  (`addr_full`), source offsets 8/16 and the Refs symbol before emitting the
  invalid load. The optimizer source is byte-identical to the SDK source.
- An isolated compiler with only `(SourceRef.RefAddr <> addr_full)` added to
  the merge condition passes the reducer at `-O1`/`-O2` and the full original
  lifecycle program at `-O2`. Descending address assignments also pass. Genuine
  ascending/descending memory-copy controls still emit MOVDQU and pass, so the
  experiment preserves that optimization for real memory operands.

The repository compiler now excludes `addr_full` sources from this merge rule.
`NXPackageLifecycleTests` builds with `-O2`; the old optimized-case skip and
`-O-` workaround are removed. Its full lifecycle case runs alongside four
focused native `Compiler.X86.MovePairs` cases in
`compiler-regressions/tsNXMovePairs.pas`: address formation and genuine memory
copies, each with ascending and descending stores.

With the unfixed compiler, the focused regression fails compilation at both
address cases. With the bootstrap-installed compiler and matching RTL, the full
project passes
**5 cases, 0 failures, 0 errors and 0 skips** at each of `-O1`, `-O2`, and
`-O2 -CfAVX` on native Linux x64. The memory-copy cases retain MOVDQU/VMOVDQU;
neither address case emits an immediate-source SIMD load. The original
lifecycle trace remains `BLRHCF!fchrlb`.

Validation on 2026-10-18 used the existing
`../nexus-private/scripts/linux/bootstrap-nexusfpc.py` script against this working
tree, with `--allow-dirty` and a toolchain root under
`/media/kcollins/dev/worktree/pkg-001-move-pairs`. Compiler cycles 2 and 3 matched,
as did all 89 RTL objects. The bootstrapped optimizer source was verified
byte-identical to the corrected working-tree source.

The SDK, bootstrap logs and test outputs are all under that worktree directory.
`validation/results.json` records the installed compiler's identity and hash and
all three test variants; their subdirectories retain exact compiler commands,
build/run logs and assembly. The shared nxbuild environment still
selects its older SDK; it was not changed by this validation. Other target
platforms were not run. The earlier `/tmp/pkg-001-analysis` and
`/tmp/pkg-001-fix` experiments are diagnostic evidence.

## Other explicit skips

Platform exclusions and the six interactive terminal fixtures are environment
requirements, not unresolved defects. They are reported individually from the
original fixture directives. `PasZLib.Archives.LargeZip64` replaces the previously
commented-out 4 GiB test with an explicit skip unless `NXTEST_LARGE_ZIP=1` is set.
The enabled 65,537-entry Zip64 case always runs. CRC32 hardware execution skips
on a CPU without SSE4.2; the reference-vector and instruction-encoding checks
remain available.

The historical compiler-consolidation findings in
[test-consolidation-failures.md](test-consolidation-failures.md) concern the
separate compiler-language fixture corpus. They are not silently imported as
unit-suite failures or represented as newly verified fixes.

## Unicode-default environment requirement (TEXT-001)

`RTL.Text.UnicodeDefaults.ComparisonAndStringList` preserves the former
`textmodel/unicode_rtl_compare_probe.pas` checks. The unchanged original reported
eight failures with the ANSI-default SDK: distinct characters became equal,
code-unit ordering was lost, and `TStringList` found the wrong item. Default
`String` APIs narrowed the Unicode inputs through the ANSI text model. Attempting
`-MUNICODESTRINGS` with that SDK instead gives `PPU default text model does not
match this compiler invocation` when loading System.

The case explicitly skips when compiled without `FPC_UNICODESTRINGS`. It is
registered alongside the unaffected RTLObjPas cases, so the skip does not turn
an otherwise successful run into an all-skipped console run. To validate it,
build RTLObjPasTests with `-MUNICODESTRINGS` and a matching Unicode-default RTL
and dependency closure. That configuration is not available in the validated
SDK. This is an isolated environment/configuration requirement; the explicit
Unicode API and helper cases run with the ordinary ANSI SDK and pass.

## Resolved FCL-001: expression Boolean text

The expression builtin `booltostr` now returns `True` or `False` explicitly.
The restored nxtest case covers both values. Against the unchanged wrapper,
FCLBaseTests reproduced **425 passed, 1 failed, 0 errors, 0 skipped**. After the
wrapper correction, the same project passes **426 cases with no failures,
errors or skips** on native x86-64 Linux.

A working-source audit of eight Nexus repositories found no production
consumers of `fpexprpars` / `Fcl.Expressions`; references are confined to the
parser implementation, its tests, a reference guide and migration records.
Direct `SysUtils.BoolToStr` callers use a separate API and remain unchanged.
The SysUtils implementation and declarations retain their original SHA-256
values. Build logs, before/after results and the consumer audit are under
`/media/kcollins/dev/worktree/expression-booltostr`.

## Runtime backtrace symbolization

Resolved in `rtl/inc/exeinfo.pas`. Upstream commit
[`2ba3a9521c767b3ab326636bb93a1929fb13d07d`](https://github.com/fpc/FPCSource/commit/2ba3a9521c767b3ab326636bb93a1929fb13d07d)
(Pierre Muller; authored September 19, 2023, committed June 2, 2025) replaced
the executable-base calculation with a backward ELF-header search to support
PIE. LLVM can map file offset zero at two different addresses in an ordinary
ELF executable. The search accepted the second header, producing a $1000 error
in the load adjustment and preventing runtime DWARF address lookup. PIC was
enabled in the failing x86-64 build; fixed-address linking and PIC generation
are separate choices.

The repair uses the loader's `AT_PHDR` address and the executable's program
headers. When the optional `PT_PHDR` descriptor is absent, it reads `e_phoff`
from the running executable and finds its containing `PT_LOAD` segment. The
file's program headers must match the loader's table. This preserves PIE
support and removes the memory search and its exit-handler recovery hook.

`ImplicitRuntimeTests` now has 22 passing cases, with no failures, errors or
skips. `LineInfoBacktraceFromSource`, `LineInfoCached` and `LineInfoInstalled`
all identify `RaiseWithBacktrace` and its source location. New `LineInfoPIE`
and `LineInfoWithoutPHDR` cases cover PIE and the optional-header fallback.
Against the unchanged RTL, the final suite reports 18 passes and four failures;
the PIE control passes before and after the repair.

A fresh Forge bootstrap from stock FPC 3.2.2 passed in 106.12 seconds. Compiler
generations two and three and all 89 RTL objects match byte for byte; both
native/shared-library bootstrap NXTests pass. Additional x86-64 controls pass
with LLVM and GNU linkers for ordinary and PIE executables, using identical
object inputs for each link. i386 ordinary executables pass with both linkers.
The 30 existing compiler recompilation NXTests also pass. Forge cross builds
pass for i386/ARM64 Linux and x86-64/ARM64 Android; object inspection confirms
each includes the repaired reader. Together with the native build, these cover
all five affected ELF targets. Android and ARM64 runtime execution was not run.
An attempted i386 PIE control was invalid for the existing non-PIC i386 RTL:
LLD rejected its absolute relocations. Its build policy was not changed.

A proposed PIE fixture with its `PT_PHDR` descriptor removed failed inside
`ld-linux` (`dl_main`, before Pascal entry). It was not retained as an RTL test;
the retained optional-header fixture is a valid fixed-address executable.

The separate source-loading internal error 2026032615 is resolved by routing all
implicit dependencies through the existing sequential loader. The removed
`FinishModule` path allowed compiled units only; source compilation instead
needed to return to `ProcessQueue`. Released FPC 3.2.2 handled this synchronously.
The original failure was also reproduced with unmodified upstream compiler
`33fe3a02f3ac738afbb4e682fc390ba601fb0d77`.

Run `ImplicitRuntimeTests` with the compiler source root, matching compiler,
matching RTL unit directory and an external output directory, in that order.
Verification artifacts are under
`/media/kcollins/dev/worktree/nxpc-elf-load-base-2_km88l9`.
