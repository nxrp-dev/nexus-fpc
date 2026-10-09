# Win64/LLD integration contracts

This suite validates the native NexusFPC -> Clang assembler -> LLD Windows path.
It uses the compiler, RTL units and resource converter built in the same checkout;
`-n` excludes installed FPC configuration. Pascal fixtures use `-O2`, matching
the bootstrap release optimization level. The pointer fixtures enable HeapTrc and exercise the Windows RTL PE data predicate
that replaces the unsupported GNU section-boundary assumption.

Run directly against an existing matched build:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\win64-contracts\Run-NXWin64Contracts.ps1
```

The canonical Nexus `repo-automation/Invoke-NexusFPCBootstrap.ps1` runs this suite
after its clean/all build. A failed assertion fails the bootstrap. LLVM's Clang,
LLD, llvm-rc, llvm-dlltool and llvm-readobj must be on PATH. No Windows SDK, C CRT,
Python, test framework or downloaded dependency is required.

The runner creates fixtures and evidence in a fresh TEMP directory by default.
Bootstrap passes its own log directory. `steps.json` records executable paths,
arguments and exit codes; version logs identify compiler/LLVM versions;
`pe-contracts.json` records the checked layout. Detailed llvm-readobj logs retain
headers, imports, exports, relocations, TLS and unwind information.

## Assertions

- A default-command-line fixed EXE, explicit `-CX -XX` fixed EXE and relocatable EXE
  verify initialized storage, static address references, large zero-filled data,
  ordered unit initialization and name/ordinal/data imports from Pascal DLLs.
- A Pascal exception unwinds through a non-leaf Clang C frame, executes its
  Pascal finally block and reaches its Pascal handler.
- Two independently built Pascal DLLs share a preferred base. A CRT-free Clang C
  caller reserves that address before loading either DLL and asserts their actual
  loaded addresses differ. Initialized pointer references, module-specific
  resources and runtime behavior are then checked under actual relocation.
- The C caller checks ordinal/name/data exports, mixed integer/floating register
  arguments plus a fifth stack argument, 16-byte aggregate returns, and callbacks
  from Pascal into C. Each DLL also exercises Pascal exception/finally behavior.
- Foreign Windows threads exist both before and after DLL loading. The earlier
  worker blocks at an event while the main thread loads the modules; this is the
  required independently progressing activity for the thread fixture. Separate
  main/worker values check zero initialization, persistence and isolation of RTL
  threadvars across threads and modules. Workers finish before DLL unloading.
- DLL unload checks reverse unit finalization through a caller-owned result
  pointer. Reload checks that module initialization and threadvars reset.
- PE checks cover AMD64/PE32+, executable entry points, section alignment and
  non-overlap, file/image bounds, writable zero-fill storage, required directories,
  sorted non-overlapping executable unwind ranges, mapped unwind data, TLS
  template/index/callback bounds, callback termination and DIR64 relocation
  targets. Fixed EXEs must have no base relocation directory.
- Link maps in every variant must omit an emitted unreferenced procedure while initialization,
  exports, callbacks and exception paths remain operational.

The target already emits COMDAT sections and enables LLD section collection by
default; the default-command-line case does not disable that behavior.

## Static pointer regressions

`-gh` fixtures explicitly call HeapTrc.CheckPointer for initialized data, a large
zero-filled array and actual read-only Clang `.rdata`. Every accessible data
section's first and last virtual byte is checked; alignment padding is rejected.
Stack, RTL threadvars and tracked heap pointers retain their existing acceptance.
Windows does not support `-gc`; these fixtures invoke the actual CheckPointer routine directly.

Ten negative cases cover nil, address 1, executable code, image headers, section
padding, private memory with forged PE signatures, no-access private memory,
guarded/no-access image data and released memory. Each negative case runs in an
isolated EXE child and again in a C host calling a forced-relocated Pascal DLL.
The runner requires exit code 204, a marker flushed immediately before the actual
CheckPointer call, and its runtime-error diagnostic. The DLL children additionally
verify relocation and a passing positive control before the rejection test.
HeapTrc's normal fatal-error configuration remains enabled. The DLL also accepts
static data in its C caller's image. Diagnostics are retained in the logs.
The predicate preserves Windows GetLastError across success and rejection.

## Limits

This is focused regression coverage, not certification of every Windows ABI
feature. It does not validate raw PE TLS variables
(the current FPC target uses RTL-managed threadvars), prove allocation reclamation,
exercise failing/partial unit initialization, GUI startup, every calling convention,
C++ exception interoperability or managed Pascal types across independent RTLs.
EXE relocation metadata is checked; only DLL relocation is forced at runtime.
The parser checks unwind row bounds, not every encoded unwind opcode.

PE interpretation follows [Microsoft's PE format](https://learn.microsoft.com/en-us/windows/win32/debug/pe-format).
The foreign calls follow the [Windows x64 calling convention](https://learn.microsoft.com/en-us/cpp/build/x64-calling-convention).

Copyright (c) 2026 Kevin Collins. Fixture and script source is licensed under
MPL-2.0-no-copyleft-exception. This Source Code Form is subject to the terms of
the Mozilla Public License, v. 2.0, available at https://mozilla.org/MPL/2.0/.
This Source Code Form is Incompatible With Secondary Licenses as defined by MPL 2.0.
