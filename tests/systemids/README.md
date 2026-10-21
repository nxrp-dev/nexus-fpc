# Fixed CPU and system identifiers

`nxsystemids.pas` includes the production enum declarations and checks the
fixed numbers of all 4 surviving CPU members and 15 surviving system members.
It registers directly with nxtest under `Compiler.TargetIdentities`.
It also checks packed type/set sizes, set membership, and numeric table indexes
using the compiler's `PACKENUM 1` / `PACKSET 1` settings.

Run from the repository root in PowerShell:

```powershell
$nxTestSources = Join-Path $PWD '../nexus/packages/nexus-packages/nxtest/src'
if (-not (Test-Path $nxTestSources)) {
    $nxTestSources = Join-Path $PWD '../../nexus/packages/nexus-packages/nxtest/src'
}
$testOutput = Join-Path $env:TEMP ('NexusFPC-SystemIds-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testOutput | Out-Null
./compiler/ppcx64.exe -n -Furtl/units/x86_64-win64 `
    "-Fu$nxTestSources" "-FU$testOutput" "-FE$testOutput" tests/systemids/nxsystemids.pas
if ($LASTEXITCODE -ne 0) { throw 'Identifier test compilation failed' }
& "$testOutput/nxsystemids.exe"
if ($LASTEXITCODE -ne 0) { throw 'Identifier test failed' }
```

Before the deprecated members were removed, the explicit-numbering change was
tested with the FPC 3.2.2 bootstrap compiler and its matching RTL.
Before/after output was byte-identical:
SHA-256 `18D2B27BCFAF0ADF3CCE47C20F8A8BCAEE9722D047541CADA29095664B314388`.
This compares identifier-test output, not entire compiler binaries or PPU files.

The deprecated members have since been removed from both enum declarations.
The numeric tables still cover their old ID ranges so that surviving IDs keep
their established positions. This later change is awaiting build and test
validation at the user's direction.

## Validation of the earlier explicit-numbering stage on 2026-09-29

- Full native bootstrap passed (37 warning lines).
- x86-64 and AArch64 cross-compiler builds passed.
- The rebuilt native compiler passed the same identifier test, with output
  matching the pre-change FPC 3.2.2 baseline byte for byte.
- Rebuilt `ppudump` read the current-format System PPU and correctly identified
  x86-64 / Win64. An attempted read of the seed compiler's PPU was rejected
  because it is format 207 rather than the current 208; no PPU version or
  format compatibility policy was changed.
- No old-case references to these two type names remain in Pascal source.
- `git diff --check` passed; generated Makefiles were not edited.

Logs:

- `%TEMP%/NexusFPCBootstrap/20260929-183736-bbbeacf0/`
- `%TEMP%/NexusFPCLinuxCrossBuild/20260929-184139-36c3616c/`
- `%TEMP%/NexusFPC-SystemIds-20260929-183536/`

## i386 Android retirement — 2026-10-19

Removed the unregistered i386 Android enum member and its remaining compiler
conditions. ID 78 is unused; every surviving target retains its explicit ID.
The identifier NXTest passes with identical output before and after removal,
including when compiled by the rebuilt native compiler (1 passed, no failures,
errors, or skips). Isolated NexusForge builds of the i386, x86-64, and AArch64
compilers passed. Target-selection checks confirm i386 Linux/Win32 remain
available, i386 Android is rejected, and both 64-bit Android targets remain
available. This did not rerun the full bootstrap or Android RTL builds.

## i386 Apple retirement — 2026-10-19

Removed the unregistered i386 Darwin and iPhone Simulator enum members, their
remaining target branches, and exclusively used alignment/call-stub/indirect-load
helpers. IDs 44 and 69 are unused; all 15 surviving system IDs retain their
explicit values and the identifier type/set layouts are unchanged. The i386
triplet helper also no longer checks the already retired Android target family.

Isolated NexusForge builds of the i386, x86-64, and AArch64 compilers passed.
All 13 retained target selections passed; i386 Darwin, iPhone Simulator, and
Android are rejected. The identifier NXTest passes with the rebuilt native
compiler (1 passed, no failures/errors/skips), with output identical to baseline.

Code-generation probes cover record/float layouts, C calling conventions,
external calls/data addresses, jump tables, constructors and interface wrappers
for i386 Linux/Win32, x86-64 Linux/macOS/iPhone Simulator, and AArch64 macOS/iOS/
iPhone Simulator. 7 generated objects were byte-identical; 1 COFF object matched after normalizing only its header timestamp.
The checks reuse existing RTL units and do not claim native Apple execution,
a fresh Apple RTL build, or a full bootstrap. Production build recipes were
not changed by this retirement.
