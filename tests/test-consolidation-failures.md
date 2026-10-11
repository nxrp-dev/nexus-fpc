# Unexpected failures encountered during test consolidation

The sections below preserve the consolidation findings and subsequent fixes.
The approved numeric implementation supersedes the earlier deferred numeric
recommendations. Grouping-only output differences remain separate.

## 2026-10-11: native floating-point policy supersedes software80

The owner subsequently chose hardware80 Extended on x86 (including Win64),
Double Extended on ARM, and host-native compiler arithmetic. Currency/Comp keep
their existing representations. NXU long revision 38 replaces revision 37;
rebuild all compiler/RTL/package artifacts together.

See [the native floating-point decisions and results](../nexusfpc-native-real-design.md)
for the current implementation. The software80 results below are preserved as
historical evidence and do not describe the current evaluator. Its exact
high-precision transcendental contract is deliberately retired; the unchanged
reference corpus remains available to measure the native math differences.

The native implementation passes all 680 consolidated group checks and the
unchanged original numeric regressions. The final clean bootstrap passes all
13 retained RTL targets, 34 Win32 and 42 Win64 focused numeric steps, and all
51 Win64/LLD contract steps. Package Extended ABI and shared-RTL math checks
also pass. The design record distinguishes these results from the 665 measured
native transcendental differences; it records the accepted accuracy tradeoff
and the platforms not executed locally.

## Historical: approved Currency and software80 implementation

The existing compiler pipeline now uses software binary80 real constants on all
hosts, completing the earlier soft80 integration across literal parsing,
folding, comparisons, PPU import/export and assembly emission. The parser,
expression tree, type system, target directives and runtime numeric ABI remain
in place. Ln, Exp, ArcTan, Sin and Cos use existing software binary128 arithmetic
for guard precision before rounding to binary80. There is one numeric path.

Currency literal conversion retains exact scaled values, including adjacent
endpoints and the positive magnitude parsed before negating the negative limit.
Range state survives copied and serialized nodes. Lowered Currency operands
continue to emit their existing integer payload; a multiplication factor with
its scale removed is not rescaled during emission.

A one-line mask-width correction in the existing `softfpu.pp`
`roundAndPackInt64` prevents rounding increments from erasing upper integer bits.
The bootstrap and package SDK scripts now build the current software arithmetic
units against the stock bootstrap RTL. The generic integer multiplication
implementation is shared through an include for older bootstrap System units.

NXU long revision **37** replaces 36. Real payloads are fixed ten-byte values;
saved real nodes also carry Currency range state. Rebuild the compiler, RTL,
packages and cached units together. See [the regression README](compiler-real/README.md)
for the implementation contract, test commands and independent reference source.

Validation:

- All seven unchanged original Win32 regressions pass normally and with `-O2`
  using both Win64-hosted and native-i386 compilers: **28 original checks**.
  The two hosts emit identical assembly for all seven fixtures and the separate
  diagnostic probe in both variants. `tw11308` requires no directive change.
- **All 680 consolidated group checks pass**, covering 170 groups on Win32 and
  Win64, normally and with `-O2`.
- **2,617 independent high-precision vectors match exactly** for the five
  transcendental functions. The corpus includes 32 very large trigonometric
  inputs evaluated independently at 17024 bits. It passes on Win64 and Win32,
  normally and with `-O2`, including native-i386 host builds.
- Fresh/cached PPU tests, Currency endpoint and rejection tests, signed zero,
  literal limits, Single/Double rounding boundaries, and integer-rounding cases
  pass. Win64-hosted and native-i386 compilers read each other's Win32 PPUs.
- Focused AArch64 Linux RTL compilation and Win32 DWARF compile/run checks pass.
- A fresh package SDK, console/GUI lifecycle examples and shared-RTL consumers
  of `tw1737`, `ttrig` and `twrstr8` pass.
- The final clean native bootstrap and all 13 retained target RTL builds pass,
  with the same 14 native warning lines. Linux FmtBCD and `-CfNONE` heaptrc
  checks also pass. These are build checks, not execution on every target.
- The final bootstrapped compilers pass the Win32 and Win64 numeric suites,
  including fresh/cached PPUs and reference vectors. The Win64/LLD contract
  suite passes with the final bootstrapped compiler. All seven original Win32
  fixtures and the diagnostic probe also pass again with the final bootstrap,
  normally and with `-O2` (`results-bootstrap.json`).

Validation evidence is under `output/numeric-repair`. The authoritative full
build is `bootstrap-complete.log`, with detailed logs in
`bootstrap-complete/20261011-075901-84256a1e`. Final numeric-suite logs are
`tests-bootstrap-win32.log` and `tests-bootstrap-win64.log`; contract results
are in `win64-contracts.log`. Earlier failed or superseded build attempts are
retained as diagnostic evidence, not successful validation.

Compilation timing used baseline and repaired production compilers with their
matching RTLs. Median compiler-process CPU times were:

| Workload | Trials per compiler | Baseline | Repaired | Difference |
| --- | ---: | ---: | ---: | ---: |
| 50,000 floating-constant expressions | 7 | 453 ms | 734 ms | +62.1% |
| Rebuild the same unchanged compiler sources with `-B -O2` | 3 | 15.203 s | 14.922 s | -1.9% |

The second result shows no measured slowdown in that workload; the small
difference is not evidence of a speed improvement. Other builds were running,
so wall times were too variable for comparison. The stress test deliberately
concentrates software arithmetic and is not a prediction for typical projects.
Raw measurements and commands are in `timing-final/results.json`,
`timing-final/compiler-results.json` and their adjacent PowerShell scripts.
The cost is compilation work, not a switch to software arithmetic in generated
applications. PPU revision 37 requires rebuilding existing compiled units.

Implementation issues found by the expanded tests were corrected before this
validation: insufficient digits in AArch64 immediate text, a rescaled optimized
Currency multiplication factor, the negated Currency endpoint, and the software
integer-rounding mask. No original test assertions were weakened.

## 2026-10-11: correction pass

Corrections implemented:

- `tw25685` and `tspace` now explicitly use ShortString for their inline-buffer
  operations. The four DelphiUnicode fixtures supply `-MUNICODESTRINGS` and are
  tested against a matching Unicode RTL.
- `tw41282`: reserve the hidden upper bound of a captured parameter in its
  parent's frame before register allocation. Regression coverage includes a
  bounded ShortString, open-array bounds, and two levels of nesting.
- `tw1592`, `tw0788`, `tw1737`, `twrstr8`, and `ttrig`: System's x86 SIMD Abs
  intrinsic must reference its own numeric masks directly. Its local indirect
  alias is a pointer cell, not mask data. Consumers retain import indirection.
  Both the RTL and the compiler must be rebuilt: the compiler's old RTL also
  corrupted compile-time trigonometric evaluation. `tabsrealmask` checks Single
  and Double signs, negative zero, and folded/runtime trigonometry.
- `tw41865c`: lower integer-backed Currency div/mod to operations on the stored
  Int64 values, restoring the quotient scale and preserving the remainder scale.
  `tcurrencydivmodscaled` covers constants, fractions, signs, mixed operands and
  evaluation counts. Win32 uses floating-backed Currency and does not accept
  these operators; the original fixture is not a Win32 runtime regression.
- `tmultilinestring26`: set the quote style when a backtick fragment follows a
  character code or ordinary quoted fragment. The fixture now asserts all six
  exact strings, including whitespace. The nearby negative `tmultilinestring11`
  also needed explicit ShortString and warning-as-error options to test its
  intended overlength diagnostic under Nexus string defaults.

### Validation and check-in scope

- All 170 consolidated groups pass on Win64 and Win32, normally and with `-O2`:
  **680 group checks**, with no failures.
- Fresh native bootstrap and all 13 retained cross-target RTL builds passed,
  with the same 14 native warning lines. Linux FmtBCD and `-CfNONE` heaptrc
  checks also passed. These are build checks, not execution on every target.
- All 14 corrected Win64 fixtures pass normally and with `-O2` (28 checks).
  All four Unicode fixtures pass on Win32 and Win64 with matching Unicode RTLs
  in both variants (16 checks).
- All 52 multiline scanner checks pass through the standard test driver,
  including the intended compile failures. The enhanced nested-parameter test
  and the new Abs/scaling regressions pass their applicable checks; the
  integer-backed Currency test body is conditional on that representation.
- All 32 existing focused compiler checks pass, including saved/cached PPUs.
- A fresh package SDK and both console/GUI lifecycle examples pass. Shared-RTL
  consumers of `tw1737`, `ttrig`, `twrstr8`, and `tabsrealmask` also pass.

The changed compiler sources exactly match the isolated bootstrap sources.
Validation evidence is under `output/failure-corrections`; the successful full
build is `bootstrap-final.log`. The earlier overlapping build/test run is
invalid validation evidence and was replaced by sequential build then test.
Remaining orchestration was switched to PowerShell at the owner's instruction;
future work must use PowerShell, not Python. Changes are left uncommitted for
the owner to check in.

### Deferred numeric/configuration review

The earlier recommendation to replace the real-constant evaluator is withdrawn.
The owner identified an existing compiler directive relevant to these cases.
Review that directive and each fixture's intended precision/target contract
before classifying these observations as compiler defects. No evaluator, PPU
format, or production compiler-host policy change is part of this patch.

The original assertions remain unchanged in `tw6493`, `tw25122`, `tw11308`,
`tb_currency_default_run_01`, `tcurrency1`, and `tfloatrecs`. The recorded
cross-compiler failures and native-i386 comparison are evidence for that review,
not proof that an architectural change is needed. `tw0788` also retains a Win32
exact-equality failure after its Win64 crash was corrected. Leave these cases
for the requested discussion; do not introduce a redesign to make them pass.

`tw41865c` passes on Win64 after the local scaling correction. Its Win32 compile
rejection needs to be considered against its intended target coverage; this
patch does not add Currency div/mod support to floating-backed Currency.

### 2026-10-11: completed numeric evaluation

Evaluated the committed correction baseline `3a473100`. No production compiler,
RTL, build configuration, or checked-in test fixture was changed in this
evaluation. PowerShell orchestration, copied fixtures, diagnostic programs and
logs are under `output/numeric-evaluation`.

The problem is real, but it is a compiler-host precision limitation rather than
a general failure of Win32 runtime arithmetic. It also affects Windows-hosted
x86-64 Linux compilation; treating it as exclusively a 32-bit issue would be
incorrect. This finding does not authorize a replacement constant evaluator.

#### What soft80 actually supplies

`FPC_SOFT_FPUX80` is already enabled in the cross-compiler build. The underlying
software floating-point library has 80-bit arithmetic routines, but the compiler
does not use them as its general constant evaluator. Its `bestreal` remains the
host's `Extended`, which is Double on the current Win64 host.

- `compiler/pexpr.pas:2041` parses real literals into `bestreal`.
- `compiler/assemble.pas:1240` widens the already-rounded Double to an 80-bit
  representation when emitting an Extended constant.
- `compiler/entfile.pas:1351` narrows an imported 80-bit PPU value to Double.

Consequently, enabling soft80 does not restore digits or exponent range lost
before emission. Changing a test's FPU or excess-precision setting does not
change the precision of the compiler executable itself.

#### Controlled comparisons

Ran seven original fixtures with two compiler hosts and seven configurations:
default, O2, EXCESSPRECISION ON, EXCESSPRECISION OFF, MINFPCONSTPREC 64,
EXCESSPRECISION ON plus MINFPCONSTPREC 64, and SSE2. Both compiler hosts used the
same Win32 RTL. All 98 compilations succeeded.

- Native-i386 compiler: all seven tests pass in every configuration (49 runs).
- Win64-hosted i386 cross-compiler: the six originally deferred tests plus
  `tw0788` fail under default/O2. Only `tw11308` is corrected by MINFPCONSTPREC 64.
- The MINFPCONSTPREC correction also passes cross-compiler O2 and native Win64
  normal/O2 checks. The fixture assertions were unchanged in these copies.
- All relevant compiler sources match the successful bootstrap source; the
  differences in `assemble.pas` and `entfile.pas` are only line endings.

| Fixture | Isolated finding | Scope of a possible correction |
|---|---|---|
| `tw11308` | MINFPCONSTPREC 64 gives the expected `1.58` and `0.58`. The emitted numeric bytes are unchanged; the formatting call receives the Double type indicator instead of Extended. | Explicit fixture precision setting; no compiler change. |
| `tw6493` | The Extended literal is emitted as zero. Runtime `Val` of the same decimal produces the correct nonzero smallest denormal. | General 80-bit literal limitation. Runtime parse/format coverage can use an exact bit-pattern reference, while literal coverage stays a recorded compiler limitation. |
| `tw25122` | Both large Extended literals have incorrect low mantissa bits. Runtime parsing produces exactly the byte arrays already asserted by the fixture. | Genuine 80-bit literal-precision coverage; do not weaken its expected bytes. |
| `tfloatrecs` | The calculated Pi fraction is correct; its decimal comparison constant loses low bits. Runtime parsing of that same reference decimal matches the actual fraction exactly. | Separate the RTL record-helper check from the compiler-literal limitation. |
| `tcurrency1` | `922337203685477` assigned to Currency becomes `922337203685476.9664`. The multiplication produces the correct value, but is compared against this incorrectly compiled expected value. | Currency constant conversion and emission, rather than multiplication code generation. |
| `tb_currency_default_run_01` | The minimum literal ends in `.5808` instead of `.5807`. A separate probe also finds that the positive maximum literal becomes the negative minimum. | Currency constant handling; the positive-to-negative result is material, not just formatting noise. |
| `tw0788` | The compiler folds `ArcTan(1)` at host precision. Evaluating both sides at runtime gives exact equality in the probe. | Separate runtime trigonometry coverage from host-dependent constant folding. |

The maximum Currency probe is:

```pascal
const
  cMaxCurrency: Currency = 922337203685477.5807;
```

The Win64-hosted Win32 compiler emits raw `$8000000000000000`, which represents
`-922337203685477.5808`. The native-i386 compiler and native Win64 target emit
the correct value. A Windows-hosted x86-64 Linux compile emits the same wrong
Currency bytes and the same imprecise Extended literals. Linux evidence is
successful compile/object/assembly inspection, not Linux execution.

#### Independent upstream verification of FPC_SOFT_FPUX80

Rechecked the owner's specific soft80 hypothesis against unmodified upstream
FPCSource revision `a6c342346ec1ec32fa5b41e555b3efcd020c086f` (2026-10-11).
Downloaded compiler/RTL source and all generated outputs are isolated under
`output/numeric-evaluation/upstream-audit`.

- Built a fresh Win64-hosted i386 compiler with `-dFPC_SOFT_FPUX80`, using stock
  FPC 3.2.2 and its host RTL. Built the matching upstream Win32 RTL. All seven
  unchanged fixtures compiled, then reproduced their failures normally and
  with `-O2`: 14 runs. The diagnostic probe reproduced the same wrong Extended
  and Currency values previously observed in Nexus.
- Independently built an upstream Win64 compiler, rebuilt the upstream Win64
  host RTL with `-dFPC_SOFT_FPUX80`, then rebuilt the i386 compiler with that
  host RTL and the same define, using a separate fresh compiler-unit directory.
  All seven failures reproduced again normally and with `-O2`: another 14 runs.
- A probe importing that second compiler's actual `cpuinfo` unit reports
  `SizeOf(bestreal)=8` and `SizeOf(Extended)=8`, while the rebuilt host RTL
  exposes `SizeOf(TExtended80Rec)=10`. Direct software 80-bit arithmetic correctly
  preserves `(1 + 2^-60) - 1`. The software arithmetic implementation works;
  enabling it does not make the compiler use it for `bestreal` arithmetic.
- The original upstream [soft80 emission commit](https://github.com/fpc/FPCSource/commit/735f9363d8568745acff44ce25e0d637b5e31b8a)
  explicitly converts an existing Double/Single value into 80-bit output.
  Current upstream still uses native `Extended` for `bestreal`. The associated
  `ufloatx80` unit supplies arithmetic operators, but the compiler does not use
  that unit as its constant-evaluation type.

Evidence: `results.json`, `soft-host-results.json`, the individual compile/run
logs, and `hostsoft80probe-run.log` in the audit directory. These results rule
out a missing soft80 define in either the compiler or its host RTL as the fix
for these reproductions. They establish an inherited upstream limitation, not
the necessity of a general evaluator redesign. Production source, build policy,
and original test assertions remain unchanged.

#### Bounded next steps and tradeoffs for discussion

1. Give `tw11308` an explicit Double constant-precision contract. This is a
   verified local fixture correction; it has not been applied to the original.
2. Prioritize a bounded Currency-constant correction. The compiler already
   parses a separate exact Currency value (`pexpr.pas:2063`) and serializes that
   field in PPUs (`ncon.pas:483`). Floating-backed Currency conversion, constant
   pooling and emission still pass through `bestreal` (`ncnv.pas:3895`,
   `ncgcon.pas:98`, `ngtcon.pas:736`). Preserving scaled Int64 values through
   those paths is a candidate for a focused fix without replacing general
   real-constant evaluation or changing the runtime Currency ABI. This is a
   source-based proposal, not an implemented or regression-validated patch.
3. Keep exact 80-bit literal/folding failures explicitly recorded. Correcting
   runtime-focused test references can preserve their intended coverage, but
   must not be described as fixing the compiler's 80-bit constant limitation.
4. If full 80-bit compilation is needed immediately, the existing native-i386
   compiler is a demonstrated working option for these Win32 tests. Using it
   as a supported build tool adds compiler-host/build maintenance and a smaller
   process address space. No automatic fallback or new build route was added.

A literal-parser-only fix would not cover constant arithmetic and PPU import,
so it should not be promised as complete Extended support. A general evaluator
replacement, Win64 Extended/ABI change, or product threading change is outside
this evaluation. The recommendation is to handle the fixture configuration and
bounded Currency work separately, then decide how much 80-bit cross-compilation
support is actually required.

## 2026-10-10: stock-compiler bootstrap

At source revision `588c77a5`, a clean native Win64 bootstrap with FPC 3.2.2
failed while compiling `rtl/win64/system.pp`:

```text
sysos.inc(459,6) Fatal: Cannot find system type "TRELOCATETHREADVARHANDLER".
Check if you use the correct run time library.
```

Reproduction: run Nexus `repo-automation/Invoke-NexusFPCBootstrap.ps1` with
`-SourceRoot` pointing to a clean checkout and `-RegenerateMakefiles`.
The failure occurs during the initial RTL build, before the updated compiler
is available. No compiler or RTL source correction was made during consolidation.

The existing package SDK builder builds the current compiler against the stock
bootstrap RTL before building its matching Nexus RTL. That separate build path
was used for fixture validation; it does not establish that the complete
stock-compiler bootstrap passes.

## 2026-10-10: layout-sensitive managed-string diagnostics

Keep `tbs/tb0239.pp`, `tbs/tb0240.pp` and `tbs/tb0252.pp` separate. Their original
fixtures compile and run successfully in the standard driver, normally and with
`-O2`, using the freshly built compiler and matching RTL.

The attempted groups also compiled and ran successfully, but their output did
not match the originals. `ErrorU.DoMem` reported different baseline heap usage
(`480` bytes versus `656` or `672` bytes) with zero bytes lost. `tb0240` also
prints string-header diagnostics that vary with allocation/layout between runs.
The grouping/output comparison therefore failed; no compiler defect has been
established by these checks. The attempted groups were discarded, and all three
original fixtures remain unchanged.

## 2026-10-10: standalone Currency runtime failures

The fresh Win64 compiler and matching RTL reproduce these failures through the
standard test driver, both normally and with `-O2`:

- `tbs/tw1737.pp` compiles but crashes with runtime error `216` while executing
  `writeln(round(c * 100))`, where `c: Currency` is assigned `234982814`.
- `tbs/tw41865c.pp` compiles but exits with code `1`. Its first assertion expects
  the raw scaled representation of `Currency(10) div Currency(3)` to be `30000`.
  The remaining assertions cannot be assessed because the first assertion halts.

These are failures of the original standalone fixtures, before any grouping.
Both fixtures were left unchanged and were excluded from consolidation. No
compiler or RTL correction was attempted in this pass. Other Currency fixtures
that pass independently remain eligible for separate consolidated batches.

## 2026-10-10: address-dependent output in larger group merges

The following existing groups pass independently, normally and with `-O2`, but
their proposed larger merges changed address diagnostics in standard output:

- `tb_records_default_run_01.pp`: case `tb0258` prints local addresses.
- `tb_records_objfpc_run_02.pp`: case `tw39665` prints object-field addresses
  and addresses recovered by subtracting field offsets.
- `tb_classes_objfpc_run_03.pp`: case `tw26536` prints `PtrUInt(Self)` twice.
- `tb_classes_delphi_run_03.pp`: case `tw8150d` prints `Pointer(Self)`.

All attempted larger fixtures compiled and ran successfully. The failure was
the exact output comparison; no assertion or compiler failure was established.
These four source groups remain separate and unchanged. Other groups in the
same feature families were successfully consolidated without them.

## 2026-10-10: resumed full consolidation scan

Validated with the fresh compiler built from `db37cbcd`, matching Win64 RTL/packages,
Clang/LLD, and the standard test driver. Each fixture below remains separate.
Commands and complete diagnostics are retained under `output/test-consolidation`.

| Fixture | Variant | Observed failure |
|---|---|---|
| `tbs/tw1592.pp` | normal | Runtime error 216 |
| `tbs/tw1592.pp` | O2 | Runtime error 216 |
| `tbs/tw0788.pp` | normal | EOverflow: Floating point overflow |
| `tbs/tw0788.pp` | O2 | EAccessViolation: Access violation |
| `tbs/tw41865c.pp` | normal | Exitcode: 1 (expected 0) |
| `tbs/tw41865c.pp` | O2 | Exitcode: 1 (expected 0) |
| `tbs/tw41282.pp` | O2 | tw41282.pp(9,3) Fatal: Internal error 200409241; Fatal: Compilation aborted |
| `test/twrstr8.pp` | normal | Exitcode: 1 (expected 0) |
| `test/twrstr8.pp` | O2 | Exitcode: 1 (expected 0) |
| `test/units/system/ttrig.pp` | normal | Runtime error 216 |
| `test/units/system/ttrig.pp` | O2 | Runtime error 216 |

## Win32 checks during the resumed pass

`tbs/tw6493.pp` exits with code 1 in its unchanged standalone form on Win32,
normally and with `-O2`. It passes on Win64. It has been restored as an
independent fixture and removed from the floating-point group. The
remaining group passes normally and with `-O2` on both architectures.

`tbs/tw25122.pp` also exits with code 1 on Win32 in both variants: its first
assertion comparing the ten-byte representation of an Extended literal fails.
It has been restored unchanged and removed from the record group; the remaining
group passes on both architectures.

## Multiline string scanning

`test/tmultilinestring26.pp` fails standalone compilation normally and with
`-O2`: `Fatal: Unterminated multi-line string starting at line 0, column 0.`
The fixture remains unchanged and separate.

## Additional Win32 failures from cross-directory consolidation

Unchanged originals fail through the standard driver normally and with `-O2`,
but pass on Win64. These fixtures were restored as separate tests:

- `tbs/tw11308.pp`: formatting prints `1.57` where the assertion expects `1.58`.
- `tbs/tb_currency_default_run_01.pp`: retained pre-existing Currency group fails at runtime.
- `test/tcurrency1.pp`: Currency runtime assertion fails.
- `test/units/system/tfloatrecs.pp`: reports `Error near 12`.

The attempted Currency merge was withdrawn because only one passing input
remained. The other reduced groups pass normally and with `-O2` on both
Win32 and Win64. No compiler or RTL correction was made.

## Additional unchanged Win64 failures

`tbs/tw25685.pp` and `test/opt/tspace.pp` both compile, then fail with runtime
error `216`, normally and with `-O2`. Their required `-o2` fixture option remains
unchanged. Both originals remain separate.

`tbs/tw25332a.pp`, `test/tcpstr26a.pp`, `test/tcpstr26c.pp` and
`test/tcpstr26d.pp` fail compilation in both variants with
`MODE DELPHIUNICODE requires -MUNICODESTRINGS`. The fixtures do not supply that
required option. They remain unchanged pending a decision about their intended
compiler-option contract. This is a test configuration failure, not evidence of
a compiler crash.

## Remaining regrouping failures and identity-sensitive fixtures

The originals below pass independently on Win64 normally and with `-O2`.
A proposed grouped form could not preserve their compilation or exact runtime
output. They remain unchanged; these results do **not** establish standalone
compiler defects. In particular, prefixing symbols changes RTTI names, while
addresses, timestamps, executable names and diagnostic line numbers naturally
change between programs. No assertions or reference strings were weakened to
force a match. Temporary failed proposals were discarded.

| Original fixture | Observed regrouping difference |
|---|---|
| `tbs/tb0546.pp` | Compiles and runs; output differs after regrouping |
| `tbs/tb0660.pp` | Compiles and runs; output differs after regrouping |
| `tbs/tb0662.pp` | Compiles and runs; output differs after regrouping |
| `tbs/tb_generics_objfpc_run_01.pp` | Error: Fields cannot appear after a method or property definition, start a new visibility section first |
| `tbs/tb_nested_method_types_delphi.pp` | Error: Method identifier expected |
| `tbs/tb_sets_objfpc_run_02.pp` | Exitcode: 1 (expected 0) |
| `tbs/tw0719.pp` | Compiles and runs; output differs after regrouping |
| `tbs/tw10247.pp` | Compiles and runs; output differs after regrouping |
| `tbs/tw11825.pp` | Runtime assertion fails after symbol renaming |
| `tbs/tw12788.pp` | Compiles and runs; output differs after regrouping |
| `tbs/tw14155.pp` | Compiles and runs; output differs after regrouping |
| `tbs/tw15377.pp` | Exitcode: 1 (expected 0) |
| `tbs/tw15467.pp` | Exitcode: 1 (expected 0) |
| `tbs/tw17402.pp` | Compiles and runs; output differs after regrouping |
| `tbs/tw22570.pp` | Exitcode: 1 (expected 0) |
| `tbs/tw2913.pp` | Compiles and runs; output differs after regrouping |
| `tbs/tw38058.pp` | Compiles and runs; output differs after regrouping |
| `tbs/tw3870.pp` | Compiles and runs; output differs after regrouping |
| `test/cg/tcalpvr4.pp` | Fatal: Syntax error, "=" expected but ";" found |
| `test/tanonfunc15.pp` | Exitcode: 1 (expected 0) |
| `test/tanonfunc16.pp` | Exitcode: 2 (expected 0) |
| `test/tcustomattr10.pp` | Error: Identifier not found "TMyAttr" |
| `test/tcustomattr19.pp` | Error: Identifier not found "TTest" |
| `test/tenum3.pp` | Error: Identifier idents no member "first" |
| `test/tforin28.pp` | Compiles and runs; output differs after regrouping |
| `test/tgeneric15.pp` | Compiles and runs; output differs after regrouping |
| `test/tgeneric16.pp` | Compiles and runs; output differs after regrouping |
| `test/tgeneric97.pp` | Exitcode: 1 (expected 0) |
| `test/tmultilinestring25.pp` | Compiles and runs; output differs after regrouping |
| `test/tpropdef.pp` | Exception: Wrong output at character index: 1
 |
| `test/trtti20.pp` | Exitcode: 1 (expected 0) |
| `test/trtti25.pp` | Exitcode: 5 (expected 0) |
| `test/tstatementexpr20.pp` | Compiles and runs; output differs after regrouping |
| `test/units/system/targs.pp` | Compiles and runs; output differs after regrouping |
| `test/units/system/tdir.pp` | Compiles and runs; output differs after regrouping |
| `test/units/system/trnd1.pp` | Compiles and runs; output differs after regrouping |
| `test/units/sysutils/tgetlocaltime.pp` | Compiles and runs; output differs after regrouping |

Additional whole-program interactions, although the transformed individual
cases pass: `tmoperator2.pp`, `tmoperator3.pp` and `tmoperator5.pp` emit global
record initialization/finalization output outside their case bodies; their
combined output order changes. `tmacprocvar.pp` prints a procedure address.
The attempted combinations containing `tw11859.pp` and `tw15061.pp` fail
representation/layout assertions; those containing `tw3144.pp`, `tw33205.pp`
and `tw9704.pp` change runtime output. Keep those cases independent; the logs
distinguish output-comparison failures from compiler/runtime failures.

The full commands, original and grouped output, and compiler diagnostics are
in the local `output/test-consolidation/evidence.zip` (`baseline.json`,
`final-exclusions.json`, `round*-merges.json`, `merges.json`, and `checks/`).
