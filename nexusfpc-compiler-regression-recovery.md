# Compiler regression recovery - 2026-10-10

## Recovered work

The interrupted test-consolidation session was
`01a11de0-ffee-7341-9a1c-0308630a4b16`, started on 2026-10-08. Its broader
consolidation combined 406 original files into 59 feature tests. The resulting
test changes are in commits `147f544c` and `78c903c2`.

Commit `2acbb37a` contains three compiler corrections discovered during that work:

- `compiler/ptype.pas`: preserve the unresolved element type in a real definition
  for generic `set of T`, instead of attempting to register System's error type.
- `compiler/ncnv.pas`: retain the destination string type when converting a CORBA
  interface identifier to a string constant.
- `compiler/psub.pas`: skip tree transformation after first-pass errors, avoiding
  optimization of unresolved helper calls.

The interrupted session recorded 19 passing focused checks and an independent
crash-guard check. Its last isolated bootstrap did not record completion. The
expanded checks had remained under ignored `output/compiler-fix-322d4d7c/`.

## Permanent regression coverage

The original `tw40453.pp` and `tw6036a.pp` now assert runtime behavior. Shared
include files let the Delphi/ObjFPC and default/short-string variants exercise
the same assertions. Additional fixtures cover invalid specializations and
generic set fields loaded from a saved unit.

The standard test suite discovers these fixtures normally. The sequential
`tests/compiler-regressions/run_compiler_regressions.py` runner uses those same
fixtures, adds optimized runs, hides the compiled generic unit's source, and
checks that subsequent consumers leave its compiled artifacts unchanged.

```powershell
python tests/compiler-regressions/run_compiler_regressions.py
```

The later `String[4]` truncation assertion, which had not been included in the
interrupted session's saved results, was verified against the baseline compiler
before changing compiler source.

## Remaining edge case corrected

The separate generic set-literal failure reproduced on the committed baseline:

```pascal
{$mode delphi}
procedure Test<T>(Value: T);
var
  Items: set of Byte;
begin
  Items := [Value];
end;
begin
  Test<Byte>(255);
end.
```

The diagnostic was `Ordinal expression expected`. The destination is already
known, but the element's type remains unresolved while the template is parsed.
`arrayconstructor_to_set` in `compiler/ncnv.pas` attempted to lower that element
before specialization supplied its type.

The correction defers lowering when an element or range endpoint depends on a
type parameter in a generic routine. A temporary empty set preserves the set
category for surrounding operators during template checking. FPC replays the
generic body's tokens during specialization; that pass performs the existing
element validation and generates the actual expression, including side effects.
The placeholder is not the specialized program's value.

This does not broaden the permitted set element types. Object and managed-string
specializations still fail with ordinary diagnostics. Regression cases cover
both generic syntax modes, enum/Byte/Char elements, fixed destinations, ranges
with either endpoint unresolved, union/difference, evaluation counts, nested
routines, optimized code, and generic methods specialized from saved PPUs.

No threaded runtime design or Kylix support is introduced.

## Validation

Results for this recovery are under `output/compiler-recovery-ef8e17be/`:

- `checks/results.json`: all 19 recovered checks passed against the original
  current compiler, including the added bounded-short-string assertion.
- `original-literal-control/results.json`: the unchanged compiler rejects the
  original set literal; the candidate compiles and runs it successfully.
- `candidate-checks-2/results.json`: all 32 permanent compile/run checks passed.
- `standard-suite/output/x86_64-win64/log.tbslog`: all 66 selected standard tests
  passed, covering the 59 consolidated feature tests and seven strengthened/new
  successful fixtures. The saved-unit fixture also recompiled successfully.
- `standard-suite/output/x86_64-win64/log.tbflog`: all five new negative fixtures
  passed under the standard test driver with the bootstrapped compiler.
- `bootstrapped-checks/results.json`: all 32 focused compile/run checks passed
  again with the compiler produced by the clean bootstrap.
- `final-checks/results.json`: all 32 checks passed with the final fixtures,
  including nested generic routines, and the bootstrapped compiler.
- The native clean bootstrap, retained packages/utilities, and removed-option
  regression suites passed. Its 14 warnings exactly match the previous successful
  full bootstrap's warning file.

`scripts/Invoke-NexusFPCBootstrap.ps1 -FullMatrix` completed successfully. All
steps returned exit code zero, including the 13 retained RTL targets, the
x86-64 Linux FmtBCD check, and the isolated `-CfNONE` heaptrc check. The cross-target
matrix validates builds; it does not establish runtime test results on every
target OS. Runtime regression checks above ran on Windows x86-64.

Bootstrap logs and `steps.json` are in
`output/compiler-recovery-ef8e17be/bootstrap/20261010-021749-3ac0b1d0/`.
