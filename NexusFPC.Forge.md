# NexusFPC with Forge

The entry point is `NexusFPC.Forge.nxscript` in this directory. Forge target
filters select the build phase, CPU, and OS. Bootstrap and Cross are Forge
Project contracts with compiler and RTL Outputs; their ordered children own
generation, compilation, and final verification. Imported configurations supply
the compiler, paths, and named compiler and assembler settings. All targets
share Forge's FPC and Clang Mustache templates, which render those settings.

From the nexus-fpc root, build the native Win64 compiler and RTL:

```powershell
& ..\..\nexus\output\NexusForge-next\x86_64-win64\nxforge.exe /input=NexusFPC.Forge.nxscript /targets=Build:Bootstrap
```

The bootstrap uses the stock Win32 seed at
`C:\fpc\3.2.2\bin\i386-win32\ppc386.exe`, generates compiler messages and tables, and
builds three native compiler/RTL generations. It requires cycles two and three
to match byte for byte.

Then select a cross target, for example:

```powershell
& ..\..\nexus\output\NexusForge-next\x86_64-win64\nxforge.exe /input=NexusFPC.Forge.nxscript /targets=Build:Cross,TargetCPU:aarch64,TargetOS:linux
```

Supply all three selections for a cross build. Target names and values are
case-sensitive. Each invocation builds one target using the completed native
bootstrap. The retained combinations are:

| TargetOS | TargetCPU |
| --- | --- |
| linux | i386, x86_64, aarch64 |
| win32 | i386 |
| win64 | x86_64, aarch64 |
| android | x86_64, aarch64 |
| darwin | x86_64, aarch64 |
| iphonesim | x86_64, aarch64 |
| ios | aarch64 |

LLVM tools must be on PATH. The Android configuration uses the installed NDK
at `C:\android\ndk\25.2.9519653`; its Clang executable and FPC
`CompilerUtilitiesPath` are set in `NexusFPC.Forge.Config.nxscript`.

Each cross build creates a Windows-hosted compiler and the target RTL,
including startup objects where required. Linux and Windows builds also link
a small SysUtils/Classes smoke program. Apple and Android validation currently
covers the compiler and RTL; it does not link or run applications for those
platforms.

Generated files stay under the ignored `build/forge-bootstrap/` directory.
A cross build cleans only its own `cross/<cpu>-<os>` output directory.
It preserves the native bootstrap and other cross targets.

No make or fpmake process is used. Package and utility builds remain to be
translated into the recipe.

## Generated compiler inputs

`NexusFPC.Forge.Tables.nxscript` is composed as an ordinary Group inside the
Bootstrap Project. It builds `mkx86ins`, `mkx86reg`, `mkx86inl`, `mka64ins`, and
`mka64reg` with the stock Win32 seed, then runs them for the retained i386,
x86_64, and aarch64 backends. Explicit CopyFile children install the x86
intrinsic declarations into the staged i386 and x86_64 RTL trees.

Bootstrap stages compiler and RTL source under `build/forge-bootstrap/seed`.
Compiler staging excludes the checked-in generated instruction/register/intrinsic
includes and message includes; RTL staging excludes generated x86 intrinsics.
The generated files therefore must be produced before any compiler generation
can use them. Native and cross builds both consume this staged source. The
checkout's source and generated includes are never overwritten. The checked-in
includes remain available to other build workflows.

The final `CompareFiles VerifyBootstrap` belongs to the Bootstrap Project and
must succeed before the build succeeds. The Package/Project contract adds no
special bootstrap executor, implicit FPC call, cache, or success shortcut.
No make/fpmake process is used for these generation steps. Package and remaining
utility recipes are still separate migration work.