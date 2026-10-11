# Retired compiler defines and branch cleanup

Date: 2026-10-10. Baseline: `d59938cb`.

## Supported targets

32-bit i386 Windows and Linux remain supported, along with x86-64 and the ARM64
targets in [the mission statement](nexusfpc-mission-statement.md). Apple bindings
remain 64-bit-only. `BSD` remains a live Darwin define; native Android and JNI
remain supported. This cleanup does not remove any currently registered target.

## Removed code

- Unreachable JVM, Xtensa, WebAssembly, PowerPC, MIPS, M68K, SPARC and RISC-V
  conditionals in the compiler, RTL, packages and utilities, including obsolete
  `CPUJVM` / `CPUXTENSA` define-generation branches.
- Conditions for retired operating systems, including AIX, Solaris/SunOS,
  BeOS/Haiku, WinCE, OS/2, DOS targets, Amiga variants and individual BSD targets.
  Shared BSD, Unix, Windows and Linux implementations remain.
- Kylix-specific DBF branches and obsolete LLVM-backend checks; the old
  `ppcx64llvm.lpi` project is deleted. Native Clang/LLVM assembler and linker
  integration remains. The compiler's explicit rejection of `LLVM` remains.
- Derived branches whose enabling definitions existed only in removed target
  paths, including WinCE registry stubs, unsupported mutex/semaphore fallbacks,
  old libffi ABI alternatives, RTTI helpers for removed CPUs, old-binutils
  fallbacks and JVM no-goto alternatives.
- Unused JVM resource compiler class, WebAssembly resource registration and
  assembler symbol kinds, plus obsolete WebAssembly module flags.

The retired target options are `SMALLTOC`, `COMPACTINTARRAYINIT`, `ENUMFIELDINIT`,
`THUMBINTERWORKING`, `INITLOCALS`, `FARPROCSPUSHODDBP`, `NOEXCEPTIONS`,
`BFEXCEPTIONS`, `WASMEXCEPTIONS`, `LEGACYEXCEPTIONS`, `WASMTHREADS` and
`SATURATINGFLOATTOINT`. Their `-CT` forms now fail through the ordinary illegal
parameter diagnostic. Source `TARGETSWITCH` forms warn as illegal switches and
do not define feature macros. Associated help entries are removed from the
message catalogs. Working `CLD` and procedure-name casing behavior remain.

The pruning selects existing branches. It introduces no replacement APIs,
threads, target emulation, or alternative implementation paths. Original source
headers and surviving declarations remain with their files. DOS header records
needed by Windows PE parsing are retained.

General feature/build controls are not classified as dead merely because one
platform-specific definition disappeared: `NO_THREADING`, `NO_UNIT_PROCESS`,
and compiler-generated software floating-point capability flags remain.
Historical numeric target identifiers and file-format tables are not blanket
deleted. This is a cleanup of the identified branches and their orphaned code,
not a claim that every historical name in the repository is a supported target.

## Compiled artifacts

`CurrentPPULongVersion` advances from 35 to 36 because the target-switch set
serialized into generic token streams changes. Obsolete module flags are also
removed. Ordinary cached units and package SDKs must be rebuilt. The Nexus
`NXU208` identity and `NXP004` package-container version are unchanged; see
[artifact identity](nexusfpc-artifact-identity.md).

## Validation

Validation uses isolated source snapshots under ignored
`output/define-cleanup/`; the working checkout's compiler and built units are
not replaced. Both snapshots start from the same committed baseline, with the
changed snapshot receiving only the working source changes.

The older `C:/gitdev/nexus/repo-automation/Invoke-NexusFPCBootstrap.ps1` fails on
the untouched baseline at `TRELOCATETHREADVARHANDLER`: the installed FPC 3.2.2
cannot build the current threadvar RTL directly. The repository's
`scripts/Invoke-NexusFPCBootstrap.ps1` creates the required seed compiler first.
Its `-FullMatrix` workflow passed on the baseline, including all 13 retained RTL
targets. No helper or threading design was changed to resolve this invocation
mismatch.

The final changed-source snapshot passed the same complete bootstrap workflow.
All 197 affected files matched that validated snapshot before this results
section was completed.

| Check | Result |
|---|---|
| Clean native compiler, RTL, packages and utilities bootstrap | Baseline and final passed; the 14 warning lines are byte-identical |
| Retained RTL target matrix | All 13 targets passed on baseline and final, including i386 Windows and Linux |
| Targeted package compilation | 78/78 checks passed on both baseline and final across 10 targets |
| Win64/Clang/LLD contracts | 51/51 steps passed on both baseline and final |
| Compiler regressions, including generic sets, saved/cached generic PPUs and CORBA conversions | 32/32 final checks passed |
| Mixed-profile cache regression suite | 41/41 final checks passed |
| Win32 compiled-program execution | Three programs compiled and ran successfully: 6/6 steps |
| Removed options and source directives | All 12 command-line options rejected and all 12 source directives diagnosed; retained switches passed |
| Old PPU rejection | Revision 35 rejected with `Invalid Long Version 35 expecting 36`, without an internal error |
| Patch and conditional-structure checks | Clean diff check; no remaining targeted conditionals or unbalanced directives |

The RTL comparison reproduced all 1,279 baseline PPUs with no missing units.
Interface checksums match for 1,188; the remaining 91 are the same seven units
on every target: `fgl`, `math`, `objpas`, `system`, `sysutils`, `types` and
`typinfo`. These are recorded differences, not a claim of identical PPU output;
the serialized settings change deliberately requires rebuilding cached units.

The RTL matrix covers i386 Windows/Linux; x86-64 Windows/Linux/macOS/iOS
simulator/Android; and ARM64 Windows/Linux/macOS/iOS simulator/Android/iOS.
Targeted package checks cover those CPU/OS combinations except iOS and its
simulator. Linux, Apple and Android results are cross-compilation checks;
runtime execution was performed on Windows only.

Validation logs, result manifests and the temporary audit helpers are retained
in the local ignored `output/define-cleanup/evidence.zip`. Temporary source
files and built artifacts are removed after preserving that evidence. Empty
scratch directories remain: automatic approval review rejected the combined
file/directory cleanup command with `blocked by policy`; the narrower file-only
cleanup was accepted.
The changes remain uncommitted, and installed/working compiler binaries are
unchanged.
