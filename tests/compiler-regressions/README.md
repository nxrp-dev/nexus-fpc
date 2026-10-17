# Compiler regressions recovered from test consolidation

The Python runner was removed on 2026-10-12. Its additional orchestration checks
are recorded in the [nxtest backlog](../python-runner-retirement.md#compiler-generic-sets-and-corba-strings).
The Pascal fixtures remain and cover:

- Generic `set of T` declarations and runtime operations in Delphi and ObjFPC
  modes, including enum/Byte specializations and unused generic declarations.
- Generic set literals, membership, mixed elements, ranges, union/difference,
  nested routines, and expression evaluation counts, including fixed
  `set of Byte` destinations.
- Generic set fields specialized from a saved PPU, with the unit source hidden;
  a second consumer checks that the cached unit remains unchanged.
- Invalid set element types and ranges, requiring ordinary compiler diagnostics.
  Non-ordinal literal elements are still rejected when specializing.
- CORBA interface identifiers assigned to all supported string types, including
  bounded short-string truncation, `-O2`, and `{$H-}`.
- Invalid interface conversions, requiring diagnostics without internal errors.

The normal test suite discovers the `t*.pas` fixtures in `tbs`, `tbf`, and
`webtbf`. The saved-unit consumer also uses its standard `RECOMPILE` directive.
The future nxtest integration must retain the source-hidden PPU check and optimization variant.

See [the recovery report](../../nexusfpc-compiler-regression-recovery.md) for the
original failure, compiler correction, and recorded validation.

## Assigned callback optimization correction (2026-10-14)

At `-O2`, the compiler combines two comparisons such as
`not Assigned(A) and not Assigned(B)` into integer operations. The generated
casts must retain `nf_load_procvar` from the original comparisons. Otherwise,
Delphi-mode conversion rules can call the callbacks instead of inspecting
their addresses. The correction in `compiler/nadd.pas` preserves this flag on
both generated value casts.

Before the correction, callbacks requiring arguments caused wrong-parameter-count
errors. Parameterless callbacks could compile and then be invoked incorrectly:
the reproducer made two calls and returned True where zero calls and False were
required. `try/finally` is not necessary to trigger the defect.

- `assigned_procvar_try_finally.pas` retains the original compilation failure,
  also seen in `SynCommons.pas` when building Forge with additional `-O2` options.
- `assigned_procvar_callbacks.pas` checks all four nil/non-nil combinations for
  plain callbacks, callbacks requiring an argument, and method callbacks. It must
  print `PASS: 12 callback checks; zero callback calls` and exit successfully.
  Keep the optimized runtime checks when integrating these fixtures into nxtest.

Focused Windows verification passed with a freshly recompiled optimizer matching
the working source: the original fixture at `-O2`, and the 12-case runtime fixture
at both `-O1` and `-O2`. The same three checks passed with stock FPC 3.2.2 Win32.
This correction has not undergone a full bootstrap or native Linux verification.

### Verification still needed on Linux / upstream

The uncorrected Nexus compiler reproduced the compilation failure for Win64,
Win32, Linux x64 and Linux ARM64 targets. These Linux results were cross-compilation
checks on Windows, not execution on Linux. Stock FPC 3.2.2 i386-win32 passed the
compile and runtime reproducers. The corresponding upstream development source
contains the same rewrite, but an unmodified upstream development compiler has
**not** been tested. Attribution of the defect to upstream remains unverified.
The attempted upstream checkout was stopped and removed at the user's request.

The user will verify on an actual Linux machine. From the repository root, using
the selected compiler and its matching RTL configuration:

```sh
mkdir -p output/assigned-o2-check
fpc -O2 -FUoutput/assigned-o2-check -FEoutput/assigned-o2-check tests/compiler-regressions/assigned_procvar_try_finally.pas
fpc -O2 -FUoutput/assigned-o2-check -FEoutput/assigned-o2-check tests/compiler-regressions/assigned_procvar_callbacks.pas
./output/assigned-o2-check/assigned_procvar_callbacks
```

Run with stock FPC 3.2.2 and with the corrected Nexus compiler, recording the
compiler version, target and results. Repeat the runtime fixture with `-O1` as
a control. If testing a newer upstream compiler, record its exact revision too;
do not infer its behavior from the 3.2.2 result or matching source alone.

`removed_java_native.pas` exercises retained constructor inheritance, overloads,
CORBA interfaces, and virtual/final methods after retiring JVM compiler support.
`removed_sdcc_registration.pas` links against matching compiler units to check
that the retained archive drivers register and no SDCC archive command remains.

## Syscall directive diagnostics

The obsolete compiler syscall-convention table had only a placeholder valid on
no targets. Its removal preserves the existing warnings: an empty `{$SYSCALL}`
reports an unusable convention, and named conventions report an invalid one.
Linux RTL system calls and the procedure calling-convention parser are unchanged.

Run `bash tests/switches/Run-NXSyscallDirectiveTests.sh <compiler> <rtl-units>
<output-directory>` with an output directory under the development worktree.
The 36 checks cover both warnings and warnings promoted to errors in all six
retained modes: FPC, ObjFPC, Delphi, MacPas, ISO and ExtendedPascal.
