# Clang assembler validation - 2026-09-29

## Scope and changes

The subsequent owner-requested removal of `Linux6432` is included in this
validation. Its target descriptor, registration, active target-set membership,
exclusive assembler entries, test-harness classification, triple override, and
assembly probe have been removed. Only obsolete PPU system slot 41 is reserved;
all 126 system enumeration positions checked against HEAD are unchanged.
The compiler rejects `-Tlinux6432` and no longer advertises the target.

This change uses the existing native FPC code generators and Clang's assembler.
It does not enable LLVM IR code generation.

- Added Android x86-64 to the x86-64 Clang registration.
- Selected Clang by default for Android x86-64 and Android AArch64.
- Removed automatic Android GNU tool prefixes so the NDK's unprefixed Clang
  is found. Explicit `-XP` settings remain available.
- Adjusted the Android supplementary linker script for LLD: `.data1` does
  not exist in its default layout; the augmented `.data` now precedes `.bss`.
- Added an Android cross-build helper and a startup-assembly make overlay.
  Neither `Makefile.fpc` nor `Makefile` was edited.

## Results

| Target/check | Compiler and RTL | Samples | Execution |
|---|---|---|---|
| Win64 x86-64 | Full native bootstrap passed | Executable and DLL linked | Executable passed |
| Linux x86-64 | Cross compiler and full RTL passed | Executable linked | Passed under Ubuntu/WSL |
| Linux AArch64 | Cross compiler and full RTL passed | Executable linked | Not run: no ARM64 runtime/emulator |
| Android x86-64 | Cross compiler and full RTL passed | Executable and shared library linked | Not run: no connected Android device |
| Android AArch64 | Cross compiler and full RTL passed | Executable and shared library linked | Not run: no connected Android device |

The native bootstrap completed with 37 warning lines. This is build and targeted
sample validation, not an execution of the entire historical FPC test suite.
Darwin/iOS builds were not tested in this Windows environment.

The Pascal samples cover managed strings, dynamic arrays, a thread variable,
a procedure address, exception handling, and a shared-library export.
Both executed programs printed `Nexus assembler sample: OK; pointer bytes=8`
and returned zero. Shared-library entry points were inspected, not invoked.

Android builds used the new default assembler without `-A` overrides.
Verbose logs confirm NDK `clang.exe` assembled the generated Pascal assembly;
the NDK's `ld.exe` identifies itself as LLD, not GNU ld.
Both architectures' ELF binaries contain the expected machine type,
`.debug_info` and `.init_array`, with no `TEXTREL`; both libraries export
`NexusAssemblerTest`. Object relocations were also inspected. These checks do
not establish on-device runtime correctness or validate every Android API level.

## Failures and limitations

1. **Optional Linux shared-library link was not completed.** Initial attempts
   found Windows GNU ld, then, with LLD selected, lacked the Linux loader
   `/lib64/ld-linux-x86-64.so.2` in a suitable cross sysroot. Linux executables
   and Android shared libraries passed; Linux shared-library support is not
   claimed validated by this run.
2. **Android integration hurdles fixed in this change:** automatic tool
   prefixes looked for nonexistent prefixed Clang executables; direct GNU
   startup-assembly flags needed Clang's `-Wa,-defsym,...` spelling; and LLD
   rejected the old `INSERT AFTER .data1` linker-script directive.
3. **Registration test needed fresh compiler units after bootstrap.** Generated
   message includes were newer than retained x86-64 cross PPUs. A forced
   compiler-unit rebuild resolved the failure without changing test assertions
   or compiler behavior. The test then passed.

## Tools and evidence

- Bootstrap seed: FPC 3.2.2, Windows x86-64.
- Installed LLVM Clang: 23.1.2.
- Android NDK: 25.2.9519653; Clang and LLD 14.0.7; API 21 library sysroot.
  API 21 is the test configuration, not a new minimum-API policy.
- Final native bootstrap log directory:
  `%TEMP%/NexusFPCBootstrap/20260929-182035-123f2cc0`.
- Final Linux compiler/RTL logs:
  `%TEMP%/NexusFPCLinuxCrossBuild/20260929-182538-e7371b7a`.
- Final Android compiler logs:
  `%TEMP%/NexusFPCAndroidCrossBuild/20260929-182708-9417ec7b`.
- Final Android RTL logs:
  `%TEMP%/NexusFPCAndroidCrossBuild/20260929-182741-55ea8a0c`.
- Sample binaries, build logs, ELF inspections, and forced
  cross-unit rebuild log: `output/clangassembler-validation/` (ignored).
- Reproduction instructions and sample sources: this directory's `README.md`.
- The modified `tests/utils/dotest.pp` test harness also rebuilt successfully.
- Removed-target generated artifacts were moved out of the repository to
  `%TEMP%/NexusFPC-removed-target-350b125efd1e4cafadcc3f4e9550feb3/` for recovery.

`git diff --check` passed. Stable PPU enumeration identifiers were not changed.
