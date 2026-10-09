Run `./Run-NXUnitExports.ps1` with LLVM on PATH. `-Compiler` accepts a candidate compiler; `-SourceRoot` supplies its matching RTL. Outputs and logs go to a fresh temporary directory.

Checks implementation-only unit exports in EXEs and DLLs, normally and with smart linking, including units compiled separately before the program. Each image is rebuilt using a cached PPU with the unit source temporarily hidden; unit object/PPU hashes must remain unchanged. The Windows loader resolves and calls functions by alias and ordinal, and resolves writable exported data. Program/library exports must coexist with the unit exports.

The old compiler fails the fresh private-export case. Interface-visible unit exports also disappeared on cached builds. Windows and Linux unit export metadata uses optional PPU entry `ibunitexports` (88); existing PPUs without it remain readable. Units with exports must be rebuilt once to acquire the metadata. Earlier compilers cannot read PPUs containing this new entry.

For a Windows-hosted Linux regression RTL, run `./Build-NXLinuxExportRTL.ps1` with LLVM on PATH. This invokes the repository Makefile targets for the Pascal RTL units and the `abitag` loader. It accepts `-Compiler`, `-SourceRoot` and a fresh `-OutputRoot`.

Linux: run `python3 Run-NXLinuxUnitExports.py --compiler <compiler> --rtl <matching-Linux-RTL>`. The RTL must include `system`, `objpas`, `si_prc`, `si_dll`, `fpintres` and the `abitag` loader object. The runner needs GNU ld/nm and Python 3. It also accepts a Windows cross compiler under WSL, with `--assembler-dir 'C:/Program Files/LLVM/bin'` and all source, RTL and output paths beneath `/mnt/<drive>`.

Linux coverage includes fresh/cached programs and shared libraries, procedure aliases and original mangled names, initialized exported data, and smart linking. Shared-library exports are resolved and called using Python ctypes; static programs call the unit exports through external C ABI declarations. Cached unit source is hidden and object/PPU hashes must stay unchanged. An unrelated unused routine must still disappear during smart linking. Duplicate export names and Linux's unsupported ordinals must retain their diagnostics.

On compiler hosts without native 80-bit extended support, `fpcdefs.inc` selects the existing `FPC_SOFT_FPUX80` implementation for the x86-64 compiler. This allows the ordinary bootstrap compiler to emit Linux extended constants without special build flags.
