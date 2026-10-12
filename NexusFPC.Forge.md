# NexusFPC with Forge

The entry point is `NexusFPC.Forge.nxscript` in this directory. Forge target
filters select the build phase, CPU, and OS. Imported configurations supply
the compiler, paths, and named compiler and assembler settings. All targets
share Forge's FPC and Clang Mustache templates, which render those settings.

From the nexus-fpc root, build the native Win64 compiler and RTL:

```powershell
& ..\..\nexus\output\NexusForge-next\x86_64-win64\nxforge.exe /input=NexusFPC.Forge.nxscript /targets=Build:Bootstrap
```

The bootstrap uses the stock Win32 seed at
`C:\fpc\3.2.2\bin\i386-win32\ppc386.exe`, generates compiler messages, and
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
