# Unexpected failures encountered during test consolidation

Keep affected fixtures separate and unchanged. Continue consolidating other
verified cases; resolve these failures in a separate correction pass.

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
