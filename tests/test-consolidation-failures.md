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
