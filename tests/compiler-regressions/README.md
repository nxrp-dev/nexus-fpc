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
The former `removed_sdcc_registration.pas` coverage is consolidated into the
native archive suite in [NXClangBackendTests](../clangassembler/README.md).

## Syscall directive diagnostics

The obsolete compiler syscall-convention table had only a placeholder valid on
no targets. Its removal preserves the existing warnings: an empty `{$SYSCALL}`
reports an unusable convention, and named conventions report an invalid one.
Linux RTL system calls and the procedure calling-convention parser are unchanged.

Run `bash tests/switches/Run-NXSyscallDirectiveTests.sh <compiler> <rtl-units>
<output-directory>` with an output directory under the development worktree.
The 36 checks cover both warnings and warnings promoted to errors in all six
retained modes: FPC, ObjFPC, Delphi, MacPas and ISO.

## X86-64 CPU model alignment

`cpu_models.pas` checks all CPU enum identities, names and saved numeric slots,
both CPU selectors, the default model, and the distinct Core i/V2 capabilities.
The first five enum members previously disagreed with the parallel tables.
Reordering the enum preserves explicit `-Cp`/`-Op` option slots and their feature
sets, including the numeric settings saved with generic tokens. The default
`cpu_athlon64` now correctly defines `CPUATHLON64`.

On Linux, run with one matching bootstrap's compiler, RTL and x86-64 compiler
units, and an output directory under the development worktree:

```sh
bash tests/switches/Run-NXCPUModelTests.sh \
  <compiler> <rtl-units> <cycle3/compiler-units> <output-directory>
```

The runner also checks macros and generated POPCNT instructions for the default,
Athlon64, X86-64, X86-64-V1, Core i and X86-64-V2 selections.

## Optional shortstring optimizer build

Building the compiler with `-daddstringopt` needs a temporary node in
`TAddNode.Pass_1`. Upstream commit `e35403c3b8364f7efdc40ce0af00eefec0226e24`
removed its declaration while retaining four uses. The repair restores the
conditional local as `lStringOptNode`; it does not enable the optional optimizer
in normal builds.

`addstringopt_shortstring.pas` checks shortstring plus character, shortstring
plus constant, two characters, and truncation at 255 bytes. Build and run it at
`-O2` with both the normal compiler and a compiler built with `-daddstringopt`,
using matching RTL units and an output directory under the development worktree:

```sh
<compiler> -n -O2 -Aas-clang -XLL -Fu<rtl-units> \
  -FU<output-directory> -o<output-directory>/addstringopt_shortstring \
  tests/compiler-regressions/addstringopt_shortstring.pas
<output-directory>/addstringopt_shortstring
```

The define belongs to the compiler build, not the fixture compilation. The
compiler build itself is the regression for the missing local declaration.

## Optional DMT retirement

`retired_dmt_native.pas` checks ordinary object virtual dispatch, class virtual
and dynamic methods, an overridden integer message handler, and inherited
integer/string message handlers. These remain supported after removing the
optional `WITHDMT` implementation and its alternative object VMT layout.

Compile and run it with a native compiler and matching RTL. Put the executable
and unit output in a unique directory under the development worktree. For
cross-target verification, compile with `-Cn` and compare the emitted VMT and
message-table object data against the compiler before the removal.

## X86 move-pair optimization

`tsNXMovePairs.pas` registers four native `Compiler.X86.MovePairs` cases in
`NXPackageLifecycleTests`: ascending/descending address assignments and real
memory copies. That project now builds at `-O2`. It catches PKG-001, where
`OptPass1MOV` accepted symbolic immediate addresses as memory for SIMD copying.
Use a bootstrapped compiler containing the `addr_full` guard. Linux x64 validation
with the existing bootstrap script's installed compiler and RTL passes all five
project cases at `-O1`, `-O2` and `-O2 -CfAVX`; genuine memory
copies still use MOVDQU/VMOVDQU. See the [resolved failure record](../NXTEST-FAILURES.md).

## X86 MOVZX memory operands

`x86_movzx_memory_operand.pas` exercises the real `OptPass1Movx` pass against
matching compiler units. On a Linux x64 host, it reserves valid memory-reference
descriptors at two controlled addresses. One address, when incorrectly read
through `TOper.reg`, collides with the EAX-family encoding. Both memory loads
must survive; same-register mask optimizations must still run, and moves
between distinct registers must survive. It checks both byte/word extensions
with the i386 and x86-64 backends. The x86-64 generator uses these same dword
MOVZX forms for unsigned extension to qword, implicitly clearing the upper bits.

```sh
bash tests/switches/Run-NXX86MovzxTests.sh \
  <host-compiler> <host-rtl-units> <matching-backend-compiler-units> \
  <output-directory-under-worktree>
```

The harness uses Linux `MAP_FIXED_NOREPLACE`; inability to reserve either
address is an error, not a skipped test. It restores each instruction's owned
reference before destruction, including when testing an unfixed optimizer.
No production compiler instrumentation is required.

The native `RTL.Variants.Negation.ByReferenceAndOrdinary` case in
`packages/rtl-objpas/tests/tsNXVariantNegation.pas` retains the reproducer that exposed the
missing memory reload in `Variants.sysvarneg`. Compile the Variants unit itself
with the tested compiler and optimization setting, then compile and run this
RTLObjPasTests with that unit and its matching RTL. It checks signed/unsigned integer,
floating-point and Currency negation, result subtypes, unchanged referenced
values, and ordinary Variant negation. LongWord inputs on both sides of
`$80000000`, including `$FFFFFFFF`, check that negation widens the operand to
Int64 before changing its sign in both ordinary and by-reference paths.
Outputs belong under the worktree.

`little_endian_platform.pas` verifies native layout, bitpacked access, small
record parameters and retained network/UTF-16BE/GUID conversions.
`little_endian_metadata.pas` verifies NXU/NXP little-endian header acceptance
and rejection of retired, mixed and missing byte-order flags. Run both with
`tests/switches/Run-NXRemovedBigEndianTests.sh` and matching compiler/RTL units.

## Implicit dependencies

Build `ImplicitRuntimeTests.nxproject` with nxbuild, then run:

```text
ImplicitRuntimeTests <source-root> <compiler> <matching-rtl-units> <external-output>
```

The Linux x86-64 NXTests compile original source fixtures and RTL sources through
the normal dependency loader. They cover explicit and `-Fa` dependencies, cached
units, stale dependency checksums, symbol visibility, initialization/finalization
order, valid implementation cycles and rejected interface cycles. Source-built
System, ObjPas, ISO7185, HeapTrc, line information, startup and late-discovered Variants
exercise the compiler's different continuation points. Package cases distinguish
implicit imports from explicit `contains` ownership claims.

Five cases additionally require procedure, file and line names in runtime
backtraces: source-built, cached and installed line information, a PIE executable,
and a fixed-address executable without the optional `PT_PHDR` descriptor. The
latter changes that ELF descriptor to `PT_NULL` in the generated test artifact;
Pascal source, machine code, load segments and DWARF are unchanged. The tests
check the actual ELF executable type. The PIE control uses the native x86-64
Linux interpreter at `/lib64/ld-linux-x86-64.so.2`.

All 22 cases pass with the repaired ELF load-address calculation. The original
failure and its upstream introduction are recorded in
[the failure history](../NXTEST-FAILURES.md#runtime-backtrace-symbolization).

The narrower `Run-NXImplicitHeapTrcTests.sh` runner builds the original HeapTrc
source directly, verifies unchanged cached artifacts on a second build, and
requires a clean runtime heap report with `-gh -gl` enabled.

## Windows debug artifacts and linker paths

Build `DwarfArtifactTests.nxproject` with nxbuild, then run:

```text
DwarfArtifactTests <source-root> <nxpc-driver-or-bootstrap-root> <llvm-dwarfdump> <external-output>
```

The second argument accepts either an installed NXPC driver with its matching
configuration, or an isolated Forge bootstrap root after the three Windows
`Build:Cross` invocations. The latter selects each `cross/<cpu>-<os>/nxpc-<cpu>`
and its matching `rtl` directly. Outputs must be outside source, under worktree.
Clang, llvm-ar and llvm-readobj must be on PATH.

The NXTests cover i386 Win32, x86-64 Win64 and ARM64 Win64. They verify complete
linked DWARF range tables, compare live-function counts and linker maps, and
check that discarded functions lose their range entries. They also require
discarded functions' debug records to have zero start and end addresses, while
retained functions keep nonzero address ranges, and run LLVM's DWARF verifier.

The path cases build executables and DLLs with braces, spaces and apostrophes
in output paths. They check map placement, quoted archive filenames, actual
linker library-path lookup in a separate directory, and named DLL exports
through definition files. The original braced response-file regression remains
an independent case. No Windows execution is required for these artifact checks.
