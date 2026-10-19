# Scanner debug and pointer-check flags conflict

`NXScannerBuildTests.lpr` is an NXTest build regression for native Linux x86-64.
Both `Compiler.Scanner.BuildFlags` cases require a successful compiler build.
The second enables `CHECK_INPUTPOINTER_LIMITS` in addition to `EXTDEBUG`.
Success remains the expected result; the defect is not skipped or treated as
an expected failure.

`TScannerFile.DumpPointer`, compiled under `EXTDEBUG`, reads `inputpointer` in
three places. Under `CHECK_INPUTPOINTER_LIMITS`, that field is not declared;
Scanner instead declares `hidden_inputpointer`. The combination consequently
fails to compile with three undeclared-identifier errors. A direct build from
the unchanged batch 079 source reproduces these errors. Its historical
introducing change has not been established. This naming pass retains the
field references and does not repair the defect.

Before naming batch 080, the checked-in NXTest compiled and ran against the
batch 079 bootstrap. `ExtDebug` passed; `ExtDebugWithPointerChecks` failed with
exactly the three missing-field diagnostics. The suite reported
`1 passed; 1 failed; 0 errors; 0 skipped` and exited with status 1.

The NXTest program builds both configurations itself through
`SysUtils.ExecuteProcess`, using separate unit output directories. It requires
the generated compiler source from an existing bootstrap, including its tables
and includes, and that bootstrap's matching compiler and RTL. No source copies
are edited and no bootstrap stage is changed.

Build the test program with the selected compiler, matching RTL, and sibling
`nexus/packages/nexus-packages/nxtest/src` in its unit search path. Place all
outputs in a unique directory under the development worktree. Then run:

```sh
NX_SCANNER_TEST_COMPILER="$compiler" \
NX_SCANNER_TEST_RTL="$rtl" \
NX_SCANNER_TEST_SOURCE="$generated_source/compiler" \
NX_SCANNER_TEST_FIXTURES="$repo/tests/compiler-regressions" \
NX_SCANNER_TEST_OUTPUT="$out/compiler-cases" \
  "$out/NXScannerBuildTests"
```

Use a fresh output directory for each run. `ExtDebug` is the control case;
`ExtDebugWithPointerChecks` reproduces the incompatible flags. Compiler output
is inherited by the NXTest process so the compilation diagnostics remain visible.

## UTF-8 multi-quote literal crashes the compiler

The same NXTest program registers `Compiler.Scanner.StringLiterals`.
`ScannerAsciiMultiQuote.pas` compiles and runs successfully. The otherwise
equivalent `ScannerUTF8MultiQuote.pas` contains `café`, explicitly selects UTF-8,
and causes the batch 080 compiler to raise `EAccessViolation`, exiting with
status 217. Both tests require compilation and execution to succeed and the
literal to equal its exact expected text.

`PostProcessUTF8Multiline` initializes an empty temporary wide string, then
reads from that temporary. Its append operation targets the input wide string
instead of the temporary. The caller also passes the ANSI length counter,
which was reset when the text switched to wide-string storage. In this fixture
the loop does not populate the temporary and the final read dereferences its
nil data pointer. The naming pass preserves these operations; no repair is
included. The historical introducing change has not been established.

Set `NX_SCANNER_TEST_FIXTURES` as shown above. These checked-in fixtures are
compiled directly; expected success is not changed to an expected failure.
