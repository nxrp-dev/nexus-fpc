# Experimental Win64 package SDK

The [Linux SDK guide](../../nexusfpc-dynamic-packages-linux.md) covers the x86-64
glibc implementation, WSL wrapper, native Python tools and Linux regression suite.
The console and late-loading examples are shared between the two platforms.

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
Both write `result.log` inside their selected application generation. They verify
class/RTTI identity, cross-image object destruction, strings/arrays/interfaces,
typed exceptions, resource strings, wide strings, and a diamond dependency graph.
The required log is initialization `BLRH`, success, then finalization `h,r,l,b`.

## SDK layout and distribution

| Path | Purpose |
| --- | --- |
| `bin\ppcpkg.exe` | Explicitly opted-in package compiler. The normal compiler remains package-disabled. |
| `bin\Invoke-NexusFPCPackageCompile.ps1` | Reusable package/application build helper. |
| `bin\NexusFPCPackageArtifacts.ps1` | Metadata/image checks and atomic bundle publication used by the helper. |
| `packages\nxrtl.pcp`, `nxrtl.dll` | Shared System/ObjPas/SysUtils/Classes/TypInfo/FPCPackage owner and dependency closure. |
| `units\` | Matching per-image `SysInitPkg` and native resource adapter. |
| `sdk.json` | Format 2 SDK identity and enforced compiler/foundation/startup artifact hashes. |
| `logs\`, `work\` | Build commands, diagnostics and intermediate files; not required by consumers. |
| `examples\packages\current.json` | Selects a complete immutable generation of provider PCP/DLL pairs. |

Copy `bin`, `packages`, `units`, and `sdk.json` together to relocate the SDK. Keep
dependent packages from the same SDK build together. Only DLLs alongside the EXE
are required to run an application; the compiler, PCPs and startup units are build
inputs. Build helpers verify SDK and bundle hashes and paired PCP/DLL identities.
The runtime checks descriptor ABI, compiler/target/RTL identity, SDK identity and
each required package's exact build ID before user initialization. Rebuild all
experimental packages for PCP v4 and descriptor v2; ordinary PPU format is unchanged.

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
`work-<id>` directory with `compile.log` and `build.json`. After compilation,
linking and identity checks succeed, it writes `generation-<id>` with a hash
manifest and atomically selects it through `current.json`. Failed builds leave
the preceding selection intact. Build helpers accept either the distribution
directory or its selected generation; both paths verify an available manifest.

Resolve an application generation before running or copying it:

```powershell
. "$sdk\bin\NexusFPCPackageArtifacts.ps1"
$app = Get-NexusPackageBundle C:\project\app
& "$app\app.exe"
```

Rebuilding a provider changes its build ID. If existing consumers in the bundle
still require the old ID, publication rejects the update. Build the replacement
provider and its consumers in dependency order into a new distribution directory.
Previous generations and diagnostic work directories are retained; removal is
an explicit caller operation. Build/publication is intended for sequential use.

The foundation is a minimal RTL closure, not all FPC library packages. Extra units
must be built with this SDK and assigned to a package or the host as appropriate.
Do not add ordinary-build RTL unit directories to a package application's path.

## Late loading and unloading

Build a real plugin example against an existing SDK:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Build-NexusFPCLatePackageExamples.ps1 -SdkRoot C:\temp\nxpkg-sdk -OutputRoot C:\temp\nxpkg-late -RunExamples
```

This additionally requires `llvm-rc.exe`. The console and GUI hosts import a
shared contract package and obtain an object factory from a late-loaded plugin.
The host does not startup-import either implementation branch or their common
dependency. Both examples exercise repeated loads, a diamond, managed results,
typed exceptions, native and translated string resources, registration removal,
native unmapping and reload. Distribute the selected generation's EXE/DLL files.

```pascal
Handle := SysUtils.LoadPackage('pluginleft.dll');
try
  { GetProcAddress, call the exported factory, use and release its objects. }
finally
  SysUtils.UnloadPackage(Handle);
end;
```

Use an explicit DLL filename. Bare names resolve beside the EXE; explicit paths
are expanded and dependency search uses the package directory, application
directory and System32. No implicit current-directory/PATH search is added.
Successful loads require matching unload calls. Startup owners remain pinned.
The application must release every object, interface, callback and code/RTTI
pointer into an image before its final unload, and must not call FreeLibrary
on a managed package handle.

`RegisterPackageCleanup(Handle, Callback)` supports application-owned cleanup;
the callback runs before unit finalization. `UnregisterPackageCleanup` removes
it when no longer needed. Classes/aliases, component registrations and lookup
handlers, integer conversion callbacks, enum aliases and resource-string tables
are cleaned by image ownership. Component initialization overrides restore the
preceding handler. Plain global callback assignments can be cleared, but previous
assignments cannot be reconstructed; applications should restore them explicitly.
Attribute instances returned by TypInfo are caller-owned, as are application caches.

Load failures become shared `EPackageError` diagnostics; the original exception is
destroyed while its image is mapped. Clean rollback releases new images and keeps
previously active dependencies. Cleanup/finalization failure retains affected
images/dependencies until exit and rejects reuse. Nested load/unload calls during
initialization, finalization or cleanup are rejected.

## Scope

This implements startup and late-loaded package consumption on experimental Win64. It uses
the approved [explicit startup contract](../../nexusfpc-dynamic-packages-runtime-design.md):
DLL entry records the handle; generated EXE startup activates packages after
native loading. Native LoadLibrary alone does not activate Pascal packages.
New late-loaded `threadvar` storage is rejected. No threading/TLS redesign is
included; item 15 remains deferred. Non-Win64 package runtimes, IDE packages,
Delphi binary compatibility and arbitrary compiler/text-model combinations are
outside this experimental SDK contract. The recorded
[tradeoffs](../../nexusfpc-dynamic-packages-load-unload-design.md) explain the limits.

To verify fresh source builds and source-free relocation in both normal and smart
link modes:

```powershell
python tests\dynamic-packages\run_package_sdk_tests.py
python tests\dynamic-packages\run_package_loader_tests.py
python tests\dynamic-packages\run_package_loader_tests.py --smart
```
