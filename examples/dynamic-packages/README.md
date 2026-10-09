# Experimental Win64 package SDK

Build a matching compiler, shared RTL package, and per-image startup units, then
build and run both example applications:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Build-NexusFPCPackageSDK.ps1 -RunExamples
```

Run this from the checkout root. Requirements are Windows x64, FPC 3.2.2 at
`C:\lazarus\fpc\3.2.2\bin\x86_64-win64` (override with `-BootstrapBin`), and
LLVM `clang.exe` and `lld-link.exe` on PATH. No previous NexusFPC build is needed.
GNU make requires the checkout, bootstrap and SDK output paths to have no spaces.

The script prints its SDK directory under `output\NexusFPCPackages`. Set
`-OutputRoot C:\temp\nxpkg-sdk` to choose a new or empty directory. `-BuildExamples`
builds without running; `-RunExamples` builds and checks both applications.
`-SmartLink` applies smart linking to the foundation, example packages and hosts.
All steps run sequentially.

The console example prints a success line. The GUI example uses the Windows GUI
subsystem and writes its result to a file; it deliberately creates no window.
Both write `examples\demo_<kind>\result.log` when run by the script. They verify
class/RTTI identity, cross-image object destruction, strings/arrays/interfaces,
typed exceptions, resource strings, wide strings, and a diamond dependency graph.
The required log is initialization `BLRH`, success, then finalization `h,r,l,b`.

## SDK layout and distribution

| Path | Purpose |
| --- | --- |
| `bin\ppcpkg.exe` | Explicitly opted-in package compiler. The normal compiler remains package-disabled. |
| `bin\Invoke-NexusFPCPackageCompile.ps1` | Reusable package/application build helper. |
| `packages\nxrtl.pcp`, `nxrtl.dll` | One shared System/ObjPas/SysUtils/FPCPackage owner and its dependency closure. |
| `units\` | Matching per-image `SysInitPkg` and native resource adapter. |
| `sdk.json` | Build description and compiler/foundation DLL hashes for provenance. |
| `logs\`, `work\` | Build commands, diagnostics and intermediate files; not required by consumers. |
| `examples\packages\*.pcp`, `*.dll` | Example provider distribution; standalone unit PPUs/objects are unnecessary. |

Copy `bin`, `packages`, `units`, and `sdk.json` together to relocate the SDK. Keep
dependent packages from the same SDK build together. Only DLLs alongside the EXE
are required to run an application; the compiler, PCPs and startup units are build
inputs. Hashes are informational, not a complete binary compatibility policy.

## Build your own package or application

Use a `.ppk` whose basename matches the package name. List `nxrtl` and other
required packages in its `requires` clause; place contained unit sources beside
the declaration or supply `-UnitPath`. For example:

```pascal
package mypackage;
requires nxrtl;
contains MyUnit;
end.
```

From PowerShell, compile and publish its PCP/DLL pair:

```powershell
$sdk = 'C:\temp\nxpkg-sdk'
$compile = "$sdk\bin\Invoke-NexusFPCPackageCompile.ps1"
& $compile -SdkRoot $sdk -Kind Package -Source C:\project\mypackage.ppk -OutputDirectory C:\project\distribution
& $compile -SdkRoot $sdk -Kind Console -Source C:\project\app.pas -RequiredPackages mypackage -PackagePath C:\project\distribution -OutputDirectory C:\project\app
```

Use `-Kind GUI` for a GUI-subsystem host. `-RequiredPackages` and `-PackagePath`
accept arrays; applications automatically include `nxrtl`. The supplied package
directories must contain all required PCP/DLL pairs. The helper copies DLLs from
those directories next to the EXE, rejecting different DLLs with the same name.
It does not acquire or select package versions. Each invocation writes a fresh
`work-<id>` directory with `compile.log` and `build.json`; failed compilation does
not copy new outputs into the distribution.

The foundation is a minimal RTL closure, not all FPC library packages. Extra units
must be built with this SDK and assigned to a package or the host as appropriate.
Do not add ordinary-build RTL unit directories to a package application's path.

## Scope

This implements startup-linked package consumption on experimental Win64. It uses
the approved [explicit startup contract](../../nexusfpc-dynamic-packages-runtime-design.md):
DLL entry records the handle; generated EXE startup activates packages after
native loading. Packages remain mapped until process exit. General
`LoadPackage`/`UnloadPackage`, reference accounting, registry cleanup, late-loaded
TLS and full mixed-build compatibility are subsequent backlog items.

To verify fresh source builds and source-free relocation in both normal and smart
link modes:

```powershell
python tests\dynamic-packages\run_package_sdk_tests.py
```
