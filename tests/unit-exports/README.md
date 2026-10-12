Run `./Run-NXUnitExports.ps1` with LLVM on PATH. `-Compiler` accepts a candidate compiler; `-SourceRoot` supplies its matching RTL. Outputs and logs go to a fresh temporary directory.

Checks implementation-only unit exports in EXEs and DLLs, normally and with smart linking, including units compiled separately before the program. Each image is rebuilt using a cached PPU with the unit source temporarily hidden; unit object/PPU hashes must remain unchanged. The Windows loader resolves and calls functions by alias and ordinal, and resolves writable exported data. Program/library exports must coexist with the unit exports.

The old compiler fails the fresh private-export case. Interface-visible unit exports also disappeared on cached builds. Windows and Linux unit export metadata uses optional PPU entry `ibunitexports` (88); existing PPUs without it remain readable. Units with exports must be rebuilt once to acquire the metadata. Earlier compilers cannot read PPUs containing this new entry.

For Windows-hosted Linux compilers and matching RTLs, use the [Forge cross matrix](../../NexusFPC.Forge.md). The historical `Build-NXLinuxExportRTL.ps1` invokes removed make targets; its replacement belongs in the later nxtest work.

The Python Linux runner was removed on 2026-10-12. Its exact exports, expected
values, cache checks and diagnostics are recorded in the
[nxtest backlog](../python-runner-retirement.md#linux-unit-exports).
The Pascal program, library and unit fixtures remain.

Required Linux coverage includes fresh/cached programs and shared libraries, procedure aliases and original mangled names, initialized exported data, and smart linking. A Pascal probe should resolve shared-library exports; static programs call the unit exports through external C ABI declarations. Cached unit source is hidden and object/PPU hashes must stay unchanged. An unrelated unused routine must still disappear during smart linking. Duplicate export names and Linux's unsupported ordinals must retain their diagnostics.

Building an x86 compiler requires a host compiler with native hardware80 Extended.
The Windows bootstrap script starts with stock FPC 3.2.2 Win32 and produces native
Win64 tools. There is no software80 compiler fallback; see the
[native floating-point policy](../../nexusfpc-native-real-design.md).
