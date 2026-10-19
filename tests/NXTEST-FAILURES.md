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
| PKG-001 | `Packages.Lifecycle.OptimizedReferenceArrayCopy` | At `-O2`, Clang rejects `movdqu $...REF+8,%xmm0` as an invalid operand. | The unchanged original program and the native unit both reproduce the immediate-address SIMD load. The lifecycle suite builds with `-O-` and its full descriptor/diamond/rollback/finalization assertions pass. The optimized variant is separately skipped on Linux x86-64. |

The fixture skips are in `rtl/fixtures.tsv`; PKG-001 calls
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

For PKG-001, remove the project's `-O-` override and build at `-O2`; both the native unit and
the original program at the pre-migration revision reproduce the assembler
error. The normal lifecycle test remains enabled at `-O-`.

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
