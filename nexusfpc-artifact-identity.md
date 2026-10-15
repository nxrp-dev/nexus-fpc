# NexusFPC compiled artifact identity

NexusFPC owns a separate compiled artifact family. An upstream numeric version
increase cannot cause an upstream unit or package to be mistaken for a Nexus
artifact, even when all numeric version fields happen to match.

## Formats

| Artifact | Extension | Signature | Current revision |
| --- | --- | --- | --- |
| Compiled unit | `.nxu` | `NXU` | Header 208; long compatibility revision 44 |
| Compiler package metadata | `.nxp` | `NXP` | 4 |
| Runtime package descriptor | Native DLL or SO | Existing `NXPK` magic (`$4e58504b`) | 4; 168 bytes on supported package targets |

The first six bytes of current unit and package metadata files are `NXU208` and
`NXP004`. The runtime descriptor retains its numeric magic constant and native
endianness; the four-character name does not specify on-disk byte order.
Compiled unit and package extensions now follow their Nexus identities:
`.nxu` and `.nxp`. Source syntax and target identifiers stay the same.
The extension change does not alter the binary layout or numeric revisions.

`.nxp` is reserved for compiled package metadata. Profiling traces use
`.nxtrace`; the runtime producer and importer use that extension together.
Existing profiling traces can be renamed because their binary format is unchanged.
Nexus project/package build descriptions remain `.nxproject`/`.nxpackage`.

The [standard package support integration](nexusfpc-standard-package-support.md)
advanced the unit compatibility revision to 35 because the normal Win64 compiler
now emits package-capable indirect data references. Rebuild ordinary units as
well as package SDKs. The validation record below describes the earlier family
identity milestone at revision 34.

The retired-target cleanup advances the compatibility revision to 36. Removing
obsolete target switches changes the settings recorded in generic token streams;
obsolete module flags are removed too. Rebuild ordinary units and package SDKs.
The `NXU208` family/header and `NXP004` package container remain unchanged.

The Currency correction used revision 37 for saved range state. The subsequent
[native floating-point policy](nexusfpc-native-real-design.md) advances it to 38:
Win64 Extended is binary80, and real payloads use ten bytes for x86 targets or
eight bytes for ARM targets. The runtime compiler identity includes this revision.

OMF removal advances the compatibility revision from 39 to 40. The retired OMF
assembler directive is removed from the serialized directive enum, and its
debug-switch member is removed from saved compiler settings. Rebuild cached
units and package SDKs. The `NXU208` header and `NXP004` container are unchanged.

STABS removal advances the compatibility revision from 40 to 41. Serialized
assembly item/section/list kinds and saved compiler settings no longer contain
STABS members. Rebuild cached units and package SDKs; `NXU208` and `NXP004`
remain unchanged. Debug information uses DWARF.

Java/JVM and SDCC cleanup advances the long compatibility revision from 41 to
42. Java object kinds, synthetic method kinds, procedure/object options,
JVM namespace records, field external names, and retired target switches are
removed from compiler metadata. Rebuild cached units and package SDKs; the
`NXU208` header and `NXP004` container remain unchanged.

XCOFF resource removal advances the long compatibility revision from 42 to 43.
The retired resource format is removed from compiler target enums, and AIX
machine kinds are removed from the resource library. Rebuild cached units and
package SDKs; `NXU208` and `NXP004` remain unchanged.

Obsolete assembler removal advances the long compatibility revision from 43 to 44.
Saved assembler identifiers no longer contain GNU AS, NASM, MASM, or YASM
drivers. Clang writers, inline-assembly readers, and internal ELF/PE-COFF object
writers remain. Rebuild cached units and package SDKs; `NXU208` and `NXP004`
remain unchanged.

The family constants live in `compiler/nxartifactid.pas`. Unit readers, package
readers, embedded package units, package rewriting, `ppufiles`, and `ppumove`
require this family. Current bundle validators require `NXP004`.
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
pointer size. Current inputs `(208, $c181, 38)` produce `$00d0c18100000026`.
The descriptor version advances from 3 to 4 because the field's meaning changed,
although its size and offsets did not. Runtime registration compares the complete
identity before activation. The runtime family is already identified by `NXPK`.

## Rebuilding and consequences

Rebuild the compiler, RTL, packages, applications and distributed package SDKs as
a matching set. Upstream `PPU`/`PCP` artifacts and older Nexus builds with those
signatures are rejected. This intentionally breaks binary artifact compatibility.
Third-party PPU parsers must learn `NXU` and the `.nxu` extension before they
can inspect these files; use the rebuilt Nexus utilities. Rebuild units and
package SDKs to populate the new filenames. The compiler searches `.nxu`/`.nxp`
only; it does not fall back to the old extensions.

The Windows repository bootstrap starts with stock FPC 3.2.2 i386-win32 and its
matching RTL. It builds an x64 seed, then the new Win64 RTL and native compiler
before the normal cycle, retaining native hardware80 arithmetic at every step.
The bootstrap compiler therefore never has to read `NXU` files. Use an isolated
source checkout for the [Forge bootstrap and full matrix](NexusFPC.Forge.md):

```powershell
& ..\..\nexus\output\NexusForge-next\x86_64-win64\nxforge.exe /input=NexusFPC.Forge.nxscript /targets=Build:Bootstrap
```

The Win64 SDK reuses the completed Forge bootstrap's compiler, staged sources
and matching RTL. Native Linux SDK construction through Forge is deferred; its
old make builder has been retired. Do not mix an existing SDK's compiler or RTL
with new files.

## Verification

### Extension migration (2026-10-14)

The compiler's thirteen retained target definitions use the shared unit extension
constant in `nxartifactid.pas`. Package lookup and writing use its package
extension constant. Release tools, Forge SDK preparation/publication, release
copy masks, archive exclusions and existing test consumers use the new names.
The stock bootstrap compiler still uses its own upstream `.ppu` files; Nexus
compilers search `.nxu`/`.nxp` without an old-extension fallback.

The `.nxp` audit found one active competing use: profiler trace files. The
runtime producer, trace tests and Nexus profiler importer now use `.nxtrace`.
A historical NexusCode review also mentioned `.nxp` project discovery, but no
current project handler or project file using that extension was found.
Keeping `.nxp` for traces and choosing another compiled-package extension would
avoid renaming old traces; the chosen names follow the requested package identity
and give traces an explicit name. Existing trace contents are unchanged.

Validated in the isolated workspace `output/artifact-names-check/`:

| Check | Result |
| --- | --- |
| Stock Win32 seed to native Win64 bootstrap | Compiler generations two and three match byte for byte |
| Release utilities and generated tables | 18 tools; 29 execution steps; 64 matching generated includes |
| Retained cross compiler/RTL matrix | All 13 targets pass, including Win32 and Linux i386 |
| Assembled release | Relocated unit searches pass on all targets; six programs link; Win32 and Win64 programs execute |
| Unit extension behavior | Emits `.nxu`; source-hidden cached consumer runs; cache remains unchanged; `.ppu` filename rejected |
| Compiler package metadata | 71 checks pass, including source-free metadata consumption |
| Shared package runtime | 97 checks pass, including fresh/cached and ordinary/smart linking |
| Package SDK examples | Console and GUI pass identity, ownership, initialization and finalization checks |
| Forge nxtest suite | 51 pass, zero failures/skips and zero unfreed heap blocks |
| Profiler runtime and importer | Both pass with `.nxtrace` files |

The renamed unit filename is part of the SDK fingerprint. The test's expected
SHA-256 vector was recalculated independently with .NET, after first verifying
that the old input reproduces the old vector.

An independent `-O2` procedure-variable failure was found during validation.
The pre-rename Win64 compiler rebuilt from `8f0cd324` reproduces it. Forge's
declared project options pass; no compiler correction was mixed into this change.
The minimized source and evidence are recorded in the
[compiler regression notes](tests/compiler-regressions/README.md#additional-optimization-failure-2026-10-14).

The retired focused regression runner compiled real upstream and Nexus units. It checked
same-number family rejection in both directions, foreign-family rejection before
target-field interpretation, header and long revisions, source fallback,
utility exit behavior, both metadata validators, and identity boundaries above
255 through the maximum 32-bit revision.

The Python runner was removed on 2026-10-12. Its cases and retained fixtures are
listed in the [nxtest backlog](tests/python-runner-retirement.md#artifact-identity).
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
