# Native compiler real constants

See [the approved numeric policy](../../nexusfpc-native-real-design.md).
`bestreal` is the host's native Extended: hardware binary80 on x86, Double on
ARM. Win64 applications now have a distinct ten-byte Extended. Currency and
Comp keep their integer representation on Win64/ARM. Microsoft `CExtended`
remains Double, including C varargs conversions.

NXU long revision 41 retains the revision-39 ten-byte real payloads for x86
targets and eight-byte payloads for ARM targets. Rebuild the compiler, RTL, packages and consumers.
Currency literal range state and exact scaled values survive PPU reuse.

## Regression checks

Use a matched compiler and freshly built RTL:

```powershell
& tests/compiler-real/Run-CompilerRealTests.ps1 `
  -Compiler path/to/ppcx64.exe -RTL path/to/rtl/units/x86_64-win64 `
  -Target win64 -OutputRoot output/compiler-real-win64
```

The runner supports Win32 and Win64, normally and with `-O2`. It checks native
arithmetic, literal limits, Single/Double rounding boundaries, signed zero,
Currency endpoints and rejected overflow, fresh/cached PPUs, Extended mixed
parameters/records/callbacks, RTTI, and exception recovery. Win64 also builds a tiny
Clang/LLD C DLL to verify Microsoft callbacks and varargs across register/stack
argument slots. The standalone SoftFloat units and their dedicated integer-rounding
regression have been retired; native rounding remains covered by `tcompilerreal`.
Math ABI coverage includes Extended SinCos output widths and guards, ArcTan2,
Tan, Cotan and Log2, including Win64's different parameter locations.

`Run-PackageRealTests.ps1 -SdkRoot <fresh-sdk> -OutputRoot <output-directory>`
uses a separately compiled package DLL to check the Extended ABI across images,
then runs the Math ABI test and existing `tw1737`, `ttrig` and `twrstr8` cases
against the shared RTL.
Build the SDK with `scripts/Build-NexusFPCPackageSDK.ps1 -BuildExamples -RunExamples`
to include console/GUI ownership and lifecycle checks.

The native core expects positive zero from `Frac(-1.0)`, matching native RTL
behavior. The preceding software evaluator preserved the negative sign. Existing
i386 `Int(-0.75)` also returns positive zero; x86-64 returns negative zero.
The original fixtures under `tbs` and `test` are unchanged.

## Optional high-precision comparison

`treference.pas` compares native mathematics with the unchanged 2,617-vector
reference corpus. Passing `-ReferenceVectors tests/compiler-real/reference-vectors.txt`
to the runner deliberately requests exact agreement and fails when results
differ. It is a characterization tool, not a required native-contract check.
The native implementation does not promise the former software evaluator's
full-range argument reduction or correctly rounded results for this corpus.

The initial Win64 characterization finds 665 differences: Sin 255, Cos 274,
Ln 99, Exp 37, ArcTan 0. Of these, 154 differ by one significand bit at the same
exponent; 189 Sin/Cos cases return their input because they exceed the x87
instruction's reduction range. The remaining cases also retain their original
expected values. See the design record for final validation and limitations.

`reference.cpp` generates the vectors using Boost.Multiprecision 1.86.0
(BSL-1.0), an optional test-generation dependency. Provenance is recorded in the
[Nexus attributions](../../../../nexus/ATTRIBUTIONS.md#boostmultiprecision-reference-arithmetic).

Compile as C++17 with the repositories' include directories. The source enables
`BOOST_MP_STANDALONE`. Ordinary cases use 256-bit arithmetic; 32 large
trigonometric cases use 17,024 bits. Expected values round explicitly to
binary80, ties to even. The removed software reduction table and its generator
are no longer needed.

## Building

Use the [Forge bootstrap and cross matrix](../../NexusFPC.Forge.md) in an isolated
checkout. The stock FPC 3.2.2 **i386-win32** seed's hardware80 arithmetic builds
the first x64 compiler, then the Win64 RTL/native compiler and self-hosting cycle.
Forge owns that transition; the make bootstrap and seed scripts are retired.
No software floating-point units are staged for it. Test orchestration remains
separate from the build and is deferred to nxtest.
