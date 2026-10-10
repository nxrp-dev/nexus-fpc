# NexusFPC compiled artifact identity

NexusFPC owns a separate compiled artifact family. An upstream numeric version
increase cannot cause an upstream unit or package to be mistaken for a Nexus
artifact, even when all numeric version fields happen to match.

## Formats

| Artifact | Extension | Signature | Current revision |
| --- | --- | --- | --- |
| Compiled unit | `.ppu` | `NXU` | Header 208; long compatibility revision 35 |
| Compiler package metadata | `.pcp` | `NXP` | 4 |
| Runtime package descriptor | Native DLL or SO | Existing `NXPK` magic (`$4e58504b`) | 4; 168 bytes on supported package targets |

The first six bytes of current unit and package metadata files are `NXU208` and
`NXP004`. The runtime descriptor retains its numeric magic constant and native
endianness; the four-character name does not specify on-disk byte order.
File extensions, source syntax, and target identifiers stay the same.

The [standard package support integration](nexusfpc-standard-package-support.md)
advances the unit compatibility revision to 35 because the normal Win64 compiler
now emits package-capable indirect data references. Rebuild ordinary units as
well as package SDKs. The validation record below describes the earlier family
identity milestone at revision 34.

The family constants live in `compiler/nxartifactid.pas`. Unit readers, package
readers, embedded package units, package rewriting, `ppufiles`, and `ppumove`
require this family. PowerShell and Python bundle validators require `NXP004`.
There is one accepted family and no legacy reader. Ordinary source fallback can
recompile a foreign cached unit into the current format when source is available.
Otherwise the diagnostic identifies the required Nexus signature and rebuild.
The standalone utilities return failure for rejected artifacts; `ppumove` does
not proceed to linking after a unit is rejected.

## Version ownership

Keep the existing numeric values as the initial Nexus revisions. Their namespace
is now independent of upstream, so choosing a very large number or periodically
skipping upstream numbers is unnecessary.

- Advance `CurrentPPUVersion` when the fixed unit header or its interpretation changes.
- Advance `CurrentPPULongVersion` when unit serialization or the compiler/RTL ABI
  changes incompatibly, including generated code contracts and threadvar layout.
- Advance `CurrentPCPVersion` when the package metadata layout changes incompatibly.
- Advance `FPCPackageVersion` and the compiler's emitted descriptor version when
  runtime descriptor layout or field semantics change incompatibly. Update the
  offline validators and ABI assertions at the same time.
- Keep SDK identities and dependency build identities: format compatibility does
  not mean that independently built package sets can be mixed.

When merging upstream, evaluate its format and ABI changes, then advance the
corresponding Nexus revision if needed. Do not copy upstream version numbers as
the identity policy. Human compiler release numbers are a separate concern.

## Runtime compiler identity

The old expression `(wordversion shl 8) or CurrentPPULongVersion` overlaps fields
once the long revision exceeds 255. Descriptor v4 uses this explicit 64-bit value:

```text
bits 63..56: reserved, zero
bits 55..48: unit header version       (8 bits)
bits 47..32: encoded compiler version (16 bits)
bits 31.. 0: unit compatibility revision (32 bits)
```

`NexusCompilerIdentity` constructs the value without narrowing it to the host
pointer size. Current inputs `(208, $c181, 34)` produce `$00d0c18100000022`.
The descriptor version advances from 3 to 4 because the field's meaning changed,
although its size and offsets did not. Runtime registration compares the complete
identity before activation. The runtime family is already identified by `NXPK`.

## Rebuilding and consequences

Rebuild the compiler, RTL, packages, applications and distributed package SDKs as
a matching set. Upstream `PPU`/`PCP` artifacts and older Nexus builds with those
signatures are rejected. This intentionally breaks binary artifact compatibility.
Third-party PPU parsers must learn `NXU` before they can inspect these files; use
the rebuilt Nexus utilities. Source-based tools do not need a new file extension.

The repository bootstrap script builds a seed compiler against the installed
FPC 3.2.2 RTL, then uses that seed to generate Nexus RTL units before cycling.
The bootstrap compiler therefore never has to read `NXU` files. Use an isolated
source checkout for the script's clean/full build:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Invoke-NexusFPCBootstrap.ps1 -FullMatrix
```

Both SDK builders stage compiler source, regenerate messages, and build their
own matching RTL. Do not mix an existing SDK's compiler or RTL with new files.

## Verification

The focused regression runner compiles real upstream and Nexus units. It checks
same-number family rejection in both directions, foreign-family rejection before
target-field interpretation, header and long revisions, source fallback,
utility exit behavior, both metadata validators, and identity boundaries above
255 through the maximum 32-bit revision.

```powershell
python tests\artifact-identity\run_artifact_identity_tests.py --sdk C:\temp\nxpkg-sdk --output C:\temp\nx-artifact-tests
```

`--sdk` must name a freshly rebuilt Windows package SDK; `--output` must be empty.
The package metadata regressions also reject an upstream-family package with the
same numeric revision and a foreign-family embedded unit. Runtime tests inspect
the emitted v4 descriptor and exact compiler identity. Lifecycle tests reject
differences in both the low revision field and the high compiler/header fields.

## Validation record (2026-10-10)

Validated from `fba54671` plus this change in the detached source checkout
`C:\gitdev\npuid`. Compiler and RTL source hashes were checked against the working
changes. Windows evidence is under `C:\gitdev\npuid-out`.

| Validation | Result | Evidence |
| --- | --- | --- |
| Artifact identity and utilities | 28 checks passed | `identity-2/steps.json` |
| Compiler package metadata | 72 checks passed | `metadata/steps.json` |
| Windows shared runtime, fresh/cached units, normal/smart linking | 99 steps passed | `runtime-win/steps.json` |
| Windows real late loader and publication | 49 checks passed | `loader-win/steps.json` |
| Linux glibc runtime, smart linking and cached units | 98 checks passed | WSL `/var/tmp/npuid-linux-tests/steps.json` |
| Windows native contracts | 51 steps passed | `win-contracts/steps.json` |
| Windows and Linux SDKs | Both rebuilt; Windows console/GUI examples passed | `sdk-win/logs/steps.json`; WSL `/var/tmp/npuid-sdk/logs/steps.json` |
| Native clean bootstrap and retained packages/utilities | Passed, including six removed-option regression suites | `bootstrap/20261010-035943-9548c68b/steps.json` |
| Full cross-compiler/RTL matrix | All 13 targets passed, plus Linux FmtBCD and isolated `-CfNONE` HeapTrc | Same bootstrap record |
| Generated RTL family audit | System and HeapTrc contain `NXU208` on all 13 targets (26 artifacts) | `rtl-artifact-identities.json` |

The native bootstrap logged 14 warnings: 13 circular package dependency warnings
and the missing `winmanutf8lfn` source registration. There were no fatal build
errors. WSL's first test-launch attempt timed out before launching the suite;
the retry completed all Linux checks. No system services were restarted.

The matrix covers i386 Linux/Win32, x86-64 Linux/Windows/macOS/iOS simulator/Android,
and AArch64 Linux/Windows/macOS/iOS simulator/Android/iOS. These are compiler and
RTL build checks; package runtime execution was tested on Windows x86-64 and
Linux x86-64 glibc. The six regression suites above total 397 passed checks/steps.
`git diff --check` passed. Build and test artifacts remain in the isolated output
directories; the source changes are uncommitted.
