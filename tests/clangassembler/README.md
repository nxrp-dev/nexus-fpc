# Clang assembler validation

These samples exercise managed strings, dynamic arrays, thread variables,
procedure addresses, exception handling, debug information, and shared-library
exports. The executable prints `Nexus assembler sample: OK; pointer bytes=8`
and returns zero when its runtime checks pass. The exported
`NexusAssemblerTest` function returns 42.

`NXClangBackendTests.lpr` registers native assembler, linker and archive suites.
It checks normal/external assembler defaults, LLVM flags, target triples,
executable/shared-library linker defaults, the explicit `ld` override and
retained archive drivers without SDCC commands. Cases are named by target.
All 13 retained assembler target combinations remain represented. Build with
matching compiler units for x86-64 (no test define), i386 (`-dTEST_I386`), or
AArch64 (`-dTEST_AARCH64`). The executables run on the host and inspect target
registrations without requiring target SDKs.

## Build compilers and RTLs

Use the [Forge bootstrap and cross matrix](../../NexusFPC.Forge.md). The former
bootstrap/Linux/Android PowerShell build scripts and Android make overlay are
retired. Forge's Android recipe compiles the startup assembly with NDK Clang.
The sample commands below are historical and use the old build output layout;
their test-infrastructure migration belongs in the later nxtest work.

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

For the native backend suite, use a matching Forge compiler-unit closure and
the sibling Nexus nxtest sources, with private output directories:

```sh
mkdir -p /tmp/nexus-clang-tests
"$compiler" -n -O2 -Aas-clang -XLL "-Fu$rtl" "-Fu$backend_units" \
  "-Fu$nxtest_sources" -FU/tmp/nexus-clang-tests -FE/tmp/nexus-clang-tests \
  tests/clangassembler/NXClangBackendTests.lpr
/tmp/nexus-clang-tests/NXClangBackendTests
```

`compiler`, `rtl`, `backend_units` and `nxtest_sources` must name the selected
compiler, its matching RTL/backend units and Nexus
`packages/nexus-packages/nxtest/src`. Add `-dTEST_I386` or `-dTEST_AARCH64` only
with that backend's matching unit closure, using a separate output directory.
The old registration/linker programs are removed. The archive test formerly
in `compiler-regressions/removed_sdcc_registration.pas` is consolidated here.
Linux native samples should also link and run without `-A` or `-XLL`.

`nxinlineassembler.pas` executes both Intel and AT&T Pascal inline assembly.
Run `bash tests/switches/Run-NXRemovedAssemblerTests.sh <compiler> <rtl-units> <output>`
on Linux x86-64 to check it through the default Clang writer, explicit Clang, and the internal
ELF writer, and verify that retired assembler options are rejected. NASM/MASM
output and GNU AS/YASM drivers are removed; the inline-assembly readers remain.
