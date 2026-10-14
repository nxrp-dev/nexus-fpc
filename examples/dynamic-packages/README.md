# Experimental Win64 package SDK

Package support is standard in the normal `ppcx64` compiler on Windows x64 and
Linux x86-64. Static linking remains available; declaring package dependencies
selects runtime package consumption. The SDK supplies the matching shared RTL,
startup units and publication tools. See the
[standard compiler integration](../../nexusfpc-standard-package-support.md).

The [Linux SDK guide](../../nexusfpc-dynamic-packages-linux.md) covers the x86-64
glibc implementation and existing SDK consumers. Its old make builder and WSL
wrapper are retired; native Linux SDK construction through Forge remains deferred.
The console and late-loading examples are shared between the two platforms.

Build the compiler with Forge, then build the shared RTL package and per-image
startup units and run both example applications:

```powershell
& ..\..\nexus\output\NexusForge-next\x86_64-win64\nxforge.exe /input=NexusFPC.Forge.nxscript /targets=Build:Bootstrap
./scripts/Build-NexusFPCPackageSDK.ps1 -RunExamples
```

Run this from the checkout root. Requirements are Windows x64, NexusForge,
and LLVM `clang.exe` and `lld-link.exe` on PATH. The initial Forge bootstrap uses
FPC 3.2.2 Win32 at `C:\fpc\3.2.2\bin\i386-win32`. SDK construction reuses that
completed bootstrap's native Win64 compiler, compiled RTL and staged sources.
It invokes no make and needs no seed installation once Bootstrap is complete.
See the [Forge build guide](../../NexusFPC.Forge.md#runtime-package-sdk).

The script delegates to Forge's `Build:PackageSDK` target and prints its SDK
directory at `build/forge-bootstrap/package-sdk`. Set `-Forge` to select the
Forge executable, or `-OutputRoot output\nxpkg-sdk` to export the SDK to a new or
empty directory. `-BuildExamples` builds without running; `-RunExamples` builds
and checks both applications. `-SmartLink` applies to the example packages and
hosts; the shared foundation uses the standard release settings in every SDK.
All steps run sequentially. Forge's `Build:Release` also builds and ships the
SDK under `distribution/package-sdk/x86_64-win64`.

The Win32 bootstrap supplies hardware80 arithmetic for the first x64 seed;
the resulting SDK compiler is native Win64. See the
[native floating-point policy](../../nexusfpc-native-real-design.md) for the
Extended ABI and rebuild requirements.

The console example prints a success line. The GUI example uses the Windows GUI
subsystem and writes its result to a file; it deliberately creates no window.
Both write `result.log` inside their selected application generation. They verify
class/RTTI identity, cross-image object destruction, strings/arrays/interfaces,
typed exceptions, resource strings, wide strings, and a diamond dependency graph.
The required log is initialization `BLRH`, success, then finalization `h,r,l,b`.

## SDK layout and distribution

| Path | Purpose |
| --- | --- |
| `bin\ppcx64.exe` | Standard compiler, supporting both static and runtime package builds. |
| `forge\PackageBuild.nxscript` | Reusable ordered package/application build group. |
| `forge\FPC.mustache` | Compiler command template used by the group. |
| `packages\nxrtl.nxpl` | Shared System/ObjPas/SysUtils/Classes/TypInfo/FPCPackage owner and dependency closure. |
| `units\` | Matching per-image `SysInitPkg` and native resource adapter. |
| `sdk.json` | Format 2 SDK identity and enforced compiler/foundation/startup artifact hashes. |
| `work\` | Forge build intermediates; excluded from exported/distributed SDKs. |
| `examples\packages\current.json` | Selects a complete immutable generation of provider package libraries. |

Copy `bin`, `packages`, `units`, `forge`, and `sdk.json` together to relocate the SDK. Keep
dependent packages from the same SDK build together. Only `.nxpl` libraries alongside
the EXE are required at runtime. Metadata is compressed inside each library by default;
`EmbedPackageMetadata: Disabled` uses a development-only `.nxp` sidecar instead.
See [package storage](../../nexusfpc-package-storage.md). Native Forge operations
verify SDK/bundle hashes and metadata/native descriptor identities.
Forge with its matching language definitions, LLVM Clang/LLD, and the release
tools (including `fpcres.exe` for resources) must be available to build consumers.
The wrapper saves Forge's build log at `build/forge-bootstrap/package-sdk-forge.log`.
The runtime checks descriptor ABI, compiler/target/RTL identity, SDK identity and
each required package's exact build ID before user initialization. Rebuild all
the compiler, RTL, units and packages together for `NXP004` package metadata,
descriptor v4 and `NXU208` units with long revision 39. These
[artifact identities](../../nexusfpc-artifact-identity.md) belong to NexusFPC;
upstream and previous Nexus binary artifacts must be rebuilt.

## Build your own package or application

Use a `.ppk` whose basename matches the package name. List `nxrtl` and other
required packages in its `requires` clause; place contained unit sources beside
the declaration or supply FPC `UnitPaths`. For example:

```pascal
package mypackage;
requires nxrtl;
contains MyUnit;
end.
```

Compose the SDK group in `C:/project/Build.nxscript` (adjust the installed paths):

```text
dialect "C:/gitdev/nexus/projects/forge/language/Forge.nxscript";
module PackageBuild "C:/project/sdk/forge/PackageBuild.nxscript";
Project Build {
    Id: "MyProject.PackageBuild";
    Group Provider (PackageBuild) {
        PackageBuildPrepare Prepare (PackageBuild.Prepare) {
            SDKDirectory: "C:/project/sdk";
            WorkDirectory: "C:/project/build/package";
        }
        FPC Compile (PackageBuild.Compile) {
            EntryPoint: "C:/project/mypackage.ppk";
        }
        PackageBundlePublish Publish (PackageBuild.Publish) {
            Name: "mypackage"; Kind: Package;
            OutputDirectory: "C:/project/distribution";
        }
    }
    Group Application (PackageBuild) {
        PackageBuildPrepare Prepare (PackageBuild.Prepare) {
            SDKDirectory: "C:/project/sdk";
            WorkDirectory: "C:/project/build/app";
            PackageDirectories: ["C:/project/distribution"];
        }
        FPC Compile (PackageBuild.Compile) {
            EntryPoint: "C:/project/app.pas";
            RequiredPackages: [nxrtl, mypackage];
            ConsoleApplication: True;
        }
        PackageBundlePublish Publish (PackageBuild.Publish) {
            Name: "app"; Kind: Console;
            OutputDirectory: "C:/project/app";
        }
    }
}
```

Run `nxforge /input=C:/project/Build.nxscript`. Use `GUIApplication: True` and
`Kind: GUI` for a GUI host. Set `SmartLinkUnits: True` and `SmartLink: True` on
the FPC child for smart linking. Application requirements explicitly include
`nxrtl`; package declarations specify their own requirements.

The group's cleanup deletes its `WorkDirectory` recursively on each invocation;
use a dedicated build directory, separate from sources and published outputs.
Explicit child composition retains the group's inherited settings. Supply
absolute SDK/work paths in this reusable group, as shown above. Preparation
writes `package.cfg` and `package-build.json` into the work directory, then FPC
runs there. The supplied package directories must contain all required `.nxpl` files
and any matching sidecars. Publication copies those libraries next to the EXE, rejecting different images
with the same name. It does not acquire or select package versions.
After compilation, linking and identity checks succeed, it writes `generation-<id>` with a hash
manifest and atomically selects it through `current.json`. Failed builds leave
the preceding selection intact. Forge accepts either the distribution
directory or its selected generation; both paths verify an available manifest.

Use the generation reported by Forge when running or copying an application.
Existing source-tree example/test callers retain a thin PowerShell adapter:

```powershell
./scripts/Invoke-NexusFPCPackageCompile.ps1 -SdkRoot C:\project\sdk -Kind Package `
    -Source C:\project\mypackage.ppk -OutputDirectory C:\project\distribution
```

That adapter writes a composed `build-<name>.nxscript` and captures Forge output
in `build-<name>.log`; compilation, validation and publication run in Forge.
It is not shipped in the SDK. Its application mode supplies `nxrtl` automatically.

Rebuilding a provider changes its build ID. If existing consumers in the bundle
still require the old ID, publication rejects the update. Build the replacement
provider and its consumers in dependency order into a new distribution directory.
Previous generations and diagnostic work directories are retained; removal is
an explicit caller operation. The reusable group clears its configured work
directory; the adapter assigns a fresh one per call. Build/publication is intended
for sequential use. A failed copy can leave an unselected generation.

This native migration is temporary: SDK layout, artifact validation and bundle
publication policy currently live in Forge and remain subject to architectural review.

The foundation is a minimal RTL closure, not all FPC library packages. Extra units
must be built with this SDK and assigned to a package or the host as appropriate.
Do not add ordinary-build RTL unit directories to a package application's path.

## Late loading and unloading

Build a real plugin example against an existing SDK:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Build-NexusFPCLatePackageExamples.ps1 -SdkRoot C:\project\sdk -OutputRoot C:\project\late-examples -RunExamples
```

This additionally requires `llvm-rc.exe`. The console and GUI hosts import a
shared contract package and obtain an object factory from a late-loaded plugin.
The host does not startup-import either implementation branch or their common
dependency. Both examples exercise repeated loads, a diamond, managed results,
typed exceptions, native and translated string resources, registration removal,
native unmapping and reload. Distribute the selected generation's EXE and `.nxpl` files.

```pascal
Handle := SysUtils.LoadPackage('pluginleft.nxpl');
try
  { GetProcAddress, call the exported factory, use and release its objects. }
finally
  SysUtils.UnloadPackage(Handle);
end;
```

Use an explicit `.nxpl` filename. Bare names resolve beside the EXE; explicit paths
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
Startup and late-loaded `threadvar` declarations use one image-owned storage
model. TLS-bearing load/unload requires `IsMultiThread=False`; coordinating
package storage across live threads remains deferred. See the
[threadvar design](../../nexusfpc-threadvar-design.md). Targets beyond Win64 and Linux x86-64/glibc, IDE packages,
Delphi binary compatibility and arbitrary compiler/text-model combinations are
outside this experimental SDK contract. The recorded
[tradeoffs](../../nexusfpc-dynamic-packages-load-unload-design.md) explain the limits.

The old `Run-PackageSDKTests.ps1` source-only bootstrap harness predates the Forge
SDK workflow. It is not maintained as a Forge build dependency. Regression-test
consolidation and integration belong to the later nxtest work.
