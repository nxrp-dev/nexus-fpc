# Clang assembler validation

These samples exercise managed strings, dynamic arrays, thread variables,
procedure addresses, exception handling, debug information, and shared-library
exports. The executable prints `Nexus assembler sample: OK; pointer bytes=8`
and returns zero when its runtime checks pass. The exported
`NexusAssemblerTest` function returns 42.

`nxclangregistration.pas` checks the compiler's actual assembler registration,
default selection, and target-triple construction for Android x86-64.
It links against the built x86-64 cross compiler units and runs on Windows.

## Build compilers and RTLs

Run from the repository root in PowerShell:

```powershell
./scripts/Invoke-NexusFPCBootstrap.ps1 -SourceRoot $PWD.Path -LogRoot "$env:TEMP/NexusFPCBootstrap"
./scripts/Invoke-NexusFPCLinuxCrossBuild.ps1 -SourceRoot $PWD.Path -BuildRTL -BinutilsDir 'C:/Program Files/LLVM/bin'
./scripts/Invoke-NexusFPCAndroidCrossBuild.ps1 -SourceRoot $PWD.Path -NdkRoot 'C:/android/ndk/25.2.9519653'
```

The Android helper builds both CPU cross compilers and both Android RTLs. It
uses NDK Clang, with no assembler-selection override in the Pascal compilation:
the compiler's new Android default is therefore tested. Startup files use
`scripts/android-clang.mk`, an overlay on the existing Android Makefile, which
passes `-Wa,-defsym,CPU64=1` through Clang. Neither `Makefile.fpc` nor the
generated `Makefile` is edited.

## Build Android samples

Set the NDK path to the installed version. API 21 is the validation sysroot,
not a new NexusFPC minimum-API policy.

```powershell
$ndk = 'C:/android/ndk/25.2.9519653/toolchains/llvm/prebuilt/windows-x86_64'
foreach ($cpu in @('x86_64', 'aarch64')) {
    $suffix = if ($cpu -eq 'x86_64') { 'x64' } else { 'a64' }
    $out = Join-Path $PWD "output/clangassembler-validation/$cpu-android"
    New-Item -ItemType Directory -Path $out -Force | Out-Null
    $options = @('-n', '-Tandroid', '-B', '-Cg', '-g', '-gw3', '-O2', '-al',
        "-FD$ndk/bin", "-Furtl/units/$cpu-android", '-Futests/clangassembler',
        "-FU$out", "-FE$out", "-Fl$ndk/sysroot/usr/lib/$cpu-linux-android/21",
        "-Fl$ndk/sysroot/usr/lib/$cpu-linux-android")
    foreach ($sample in @('nxassemblersample', 'nxassemblerlibrary')) {
        & "./compiler/ppcross$suffix.exe" @options "tests/clangassembler/$sample.pas"
        if ($LASTEXITCODE -ne 0) { throw "Failed: $cpu $sample" }
    }
}
```

NDK `ld.exe` is LLD. Check generated files with `llvm-readobj --file-headers
--program-headers --sections --dynamic-table --dyn-symbols`. Expect ELF64,
`EM_X86_64` or `EM_AARCH64`, a `.debug_info` section, an `.init_array` section,
and no `TEXTREL`. The library must export `NexusAssemblerTest`. Executables
use `/system/bin/linker64`. Inspect the sample unit's `.o` with
`llvm-readobj --relocations` as well.

## Linux and Windows samples

Use the corresponding cross compiler with `-n -Tlinux -B -Cg -g -gw3 -O2 -al
-Aas-clang -XLL`, the matching `rtl/units/<cpu>-linux` directory, and separate
`-FU` and `-FE` output directories. Build `nxassemblersample.pas`. Linux shared
libraries additionally require a suitable Linux sysroot; an Android sysroot
is not a replacement for it.

For Windows, use `compiler/ppcx64.exe -n -Twin64 -B -g -gw3 -O2 -al` with
`rtl/units/x86_64-win64`, the sample source directory, and separate output
directories. Build both samples and run the executable.

For the registration test, use the native compiler with
`-n -Furtl/units/x86_64-win64 -Fucompiler/x86_64_cross/units/x86_64-win64`,
plus `-FU` and `-FE` output directories, then run `nxclangregistration.exe`.
If a bootstrap has regenerated compiler message includes since those units
were built, force their rebuild first. With the bootstrap tools on PATH:

```powershell
make -C compiler compiler "FPC=$($PWD.Path -replace '\\','/')/compiler/ppcx64.exe" `
    CPU_TARGET=x86_64 OS_TARGET=win64 PPC_TARGET=x86_64 `
    CPU_UNITDIR=x86_64_cross EXENAME=ppcrossx64.exe 'LOCALOPT=-dFPC_SOFT_FPUX80 -B'
```
