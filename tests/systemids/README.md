# Fixed CPU and system identifiers

`nxsystemids.pas` includes the production enum declarations and checks the
fixed numbers of all 4 surviving CPU members and 18 surviving system members.
It also checks packed type/set sizes, set membership, and numeric table indexes
using the compiler's `PACKENUM 1` / `PACKSET 1` settings.

Run from the repository root in PowerShell:

```powershell
$testOutput = Join-Path $env:TEMP ('NexusFPC-SystemIds-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testOutput | Out-Null
./compiler/ppcx64.exe -n -Furtl/units/x86_64-win64 `
    "-FU$testOutput" "-FE$testOutput" tests/systemids/nxsystemids.pas
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
