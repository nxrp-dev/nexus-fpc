# Linux dynamic packages

Implementation date: 2026-10-09. Starting commit: `2acbb37a`.

## Supported scope

The experimental SDK adds **x86-64 Linux with glibc** to the existing shared-RTL
package model. Startup-linked packages and synchronous `LoadPackage`/`UnloadPackage`
use the same Pascal lifecycle manager as Win64. This is source-level runtime
package functionality for matching NexusFPC builds, not Delphi binary BPL support.

The normal `ppcx64` compiler supports both static applications and runtime
packages. The matching SDK supplies the shared RTL and per-image startup units;
applications select runtime packages through their declared dependencies. See
[standard compiler integration](nexusfpc-standard-package-support.md).
The 2026-10-10 [unified threadvar update](nexusfpc-threadvar-design.md)
adds late-loaded storage using the same model as startup storage. TLS-bearing
load/unload requires `IsMultiThread=False`. No workers or asynchronous lifecycle
are introduced. The application must release objects, interfaces, callbacks
and other references into a package before unloading it.

## Implementation

| Area | Linux implementation |
| --- | --- |
| Shared unit ownership | One `libnxrtl.so` owns System, ObjPas, SysUtils, Classes, TypInfo, FPCPackage and their closure, including native dynamic-library/resource adapters. Consumers import its units through `nxrtl.pcp`. |
| Image metadata | Nexus `NXP004` metadata, `NXU208` units (long revision 35), and the 168-byte descriptor v4 are used; all artifacts require rebuilding. See [artifact identities](nexusfpc-artifact-identity.md). ELF dependency relocations populate local pointer slots, preserving the descriptor's pointer-to-pointer ABI. Each image has a private six-word mutable context. |
| Linking and identity | All provider units use PIC. Relocatable constant tables go into `.data.rel.ro`; the package linker requires defined imports, prohibits text relocations, enables RELRO/eager binding, and binds owned definitions locally with `-Bsymbolic`. Hosts use PIE and prohibit COPY relocations. |
| Explicit startup | `rtl/linux/sysinitpkg.pp` reuses the existing glibc `si_c.inc` entry path. Activation runs from generated host startup after the native loader. Shared System initialization preserves the already active exception stack needed for rollback. |
| Native loading | `dlopen(RTLD_NOW | RTLD_LOCAL)`, explicit `DT_NEEDED` dependencies, and `dlclose`. Each managed late image has an independent native reference. No `dlmopen` namespace or global plugin-symbol publication is used. |
| Image ownership | `dladdr` maps code/data addresses to image bases. Opaque, pointer-sized native handles are stored separately from those bases. `dlinfo` prevents a plain SO from inheriting a dependency's package descriptor through `dlsym`. |
| Lifecycle and cleanup | Existing synchronous dependency accounting, activation, reverse finalization, rollback and failure retention are reused. Classes, aliases, enum aliases, component handlers, conversion callbacks, resources and explicit application cleanup hooks follow Linux image ownership. |
| Native resources | Each package exports its own resource location. The shared internal-resource implementation looks up resources with the image's native handle. |
| Dependency preservation | Declared requirements remain in PCP metadata and native linkage even when no symbols use them. Imported units retain native `$LINKLIB` requirements without copying provider unit objects into consumers. |
| SDK and publication | Native Forge operations validate PCP/ELF identity pairs without loading code. The make-based SDK builder is retired; native Linux SDK construction through Forge is deferred. SDK and bundle hashes are enforced; complete immutable generations are selected atomically through `current.json`. |

The core changes are in `compiler/pkgutil.pas`, `compiler/pmodules.pas`, the Linux
linker and ELF/assembler writers, `rtl/linux/sysinitpkg.pp`, the System package
hooks, and `rtl/inc/fpcpackageloader.inc`. Existing Windows adapters still use the
Windows loader. Common lifecycle logic has not been duplicated.

## Build status and existing SDK use

Core make infrastructure, `build_linux_package_sdk.py`, and its WSL wrapper have
been retired. Native Linux-hosted compiler and SDK construction must be ported
to Forge before fresh Linux SDKs can be built again. That work remains deferred
by owner choice; this retirement does not remove Linux package compiler/RTL code,
the `nxrtl.ppk` declaration, startup units or examples. Existing SDK consumption
and publication now use native Forge; the Python helpers have been retired.

The [Forge cross matrix](NexusFPC.Forge.md) still builds Windows-hosted Linux
compilers and base RTLs. It does not yet produce a native Linux runtime-package
SDK. The commands below apply to an existing matching SDK; keep its compiler,
shared RTL, startup units and metadata together when relocating it.

Create packages using the same declaration as on Windows:

```pascal
package mypackage;
requires nxrtl;
contains MyUnit;
end.
```

Use native Linux Forge with its language definitions and these composed groups
(adjust the installation and SDK paths):

```text
dialect "/nexus/projects/forge/language/Forge.nxscript";
module LinuxPackageBuild "/nexus/projects/forge/examples/LinuxPackageBuild.nxscript";
module LinuxPackageApplication "/nexus/projects/forge/examples/LinuxPackageApplication.nxscript";
Project Build {
    Id: "MyProject.LinuxPackages";
    Group Provider (LinuxPackageBuild) {
        PackageBuildPrepare Prepare (LinuxPackageBuild.Prepare) {
            SDKDirectory: "/project/sdk";
            WorkDirectory: "/project/build/provider";
        }
        FPC Compile (LinuxPackageBuild.Compile) {
            EntryPoint: "/project/mypackage.ppk";
        }
        PackageBundlePublish Publish (LinuxPackageBuild.Publish) {
            Name: "mypackage"; Kind: Package; OutputDirectory: "/project/providers";
        }
    }
    Group App (LinuxPackageApplication) {
        PackageBuildPrepare Prepare (LinuxPackageApplication.Prepare) {
            SDKDirectory: "/project/sdk";
            WorkDirectory: "/project/build/app";
            PackageDirectories: ["/project/providers"];
        }
        FPC Compile (LinuxPackageApplication.Compile) {
            EntryPoint: "/project/app.pas";
            RequiredPackages: [mypackage];
        }
        PackageBundlePublish Publish (LinuxPackageApplication.Publish) {
            Name: "app"; OutputDirectory: "/project/application";
        }
    }
}
```

Run `nxforge /input=/project/Build.nxscript`. Supply absolute SDK/work paths;
each group deletes its dedicated work directory before building. Extra `UnitPaths`
and `RequiredPackages` belong to the FPC child. Application composition includes
`nxrtl`; its array properties append additional requirements. Set `SmartLinkUnits`
and `SmartLink` to True on a child to enable smart linking.

The existing Linux Format 2 SDK manifest identifies `x86_64-linux-gnu`, uses
lowercase keys and must cover `bin/ppcx64`, the shared foundation and startup
artifacts. Keep these matched. New bundles use the same Format/Files/Generation
manifest structure as Win64; raw matching PCP/SO directories are also accepted.
Rebuild distributions from older helper-generated manifests before consuming them.
Use lowercase, matching package declaration/file basenames. To replace a provider
with existing consumers, rebuild the dependent distribution in a new directory.

The groups preserve PIC, PIE, `$ORIGIN`, rpath-link, no-COPY/no-text-relocation
linking, RELRO and eager binding. Native publication checks the executable's
identity and dependencies as well as package PCP/ELF pairs, preserves Unix file
permissions, and atomically selects only complete generations. Neither Python
nor PowerShell is invoked by these builds.

`current.json` identifies the runnable generation. Deployment needs only the
executable and its `.so` files together; PCPs are build inputs. `$ORIGIN` RUNPATH
allows running from another working directory without `LD_LIBRARY_PATH`.

Use `LoadPackage('libmypackage.so')` for genuine late loading. A bare filename is
relative to the executable, as on Windows. Native `dlopen` alone maps the package
but does not activate Pascal units. The examples' `PackageNative` helper supplies
platform filenames and probes; applications need only the SysUtils package API.

## Historical verification and retained tests

### Native Forge consumer verification, 2026-10-12

- Built the current Forge sources for native Linux using a preserved matching
  NexusFPC compiler and static RTL; no compiler/SDK bootstrap was performed.
- Used a private copy of an existing NXP004/ABI-4 SDK. Its older `ppcpkg` filename
  was restaged as `bin/ppcx64`; the two Python helpers and their manifest entries
  were omitted. Compiler, foundation and startup bytes were unchanged.
- The native Forge recipe built and published a provider and application which
  ran successfully. Full startup and late-load console examples then passed with
  ordinary and smart linking, including exact lifecycle traces, resources,
  registries, unload/reload, and execution from `/`.
- Executables had no R_X86_64_COPY relocations. Compile failure and a stale
  provider replacement both left current.json and every selected artifact unchanged.
- All 51 Forge tests passed with zero unfreed heap blocks. The new ELF group
  covers descriptor/dependency reads, truncation, section counts, table links,
  relocation symbol indexes, ABI mismatch, external pointers and string bounds.
  A Windows package/application build still ran successfully after this change.

Evidence: `C:/gitdev/nexus/output/ForgeIdentity/linux-native-consumer/` and
`C:/gitdev/nexus/output/ForgeVerification/package-linux-tests.log`. These outputs
are disposable; the implementation, recipes, instructions and this record are
kept in source. Native Linux SDK construction remains deferred.

### Earlier compiler/runtime verification

The Python runners were removed on 2026-10-12 by owner direction. Their cases are
recorded in [the nxtest backlog](tests/python-runner-retirement.md); Pascal fixtures
remain. The results below are historical, not a claim that nxtest already runs
these cases. Assertions include shared
class/RTTI identity, strings/arrays/interfaces, cross-image destruction and typed
exceptions, initialization/finalization order, real late mapping, actual unmapping
and reload, resource lookup/translation, registry cleanup, failure retention,
malformed ELF rejection, and preservation of published artifacts after failures.

Final validation passed on Ubuntu 26.04.1 under WSL2, x86-64, glibc 2.43, with
FPC 3.2.2 bootstrapping the experimental 3.3.1 compiler:

| Check | Result | Evidence |
| --- | --- | --- |
| Clean source-only Linux SDK workflow | 25 orchestration checks passed, including all rows for Linux runtime/relocation below | `/var/tmp/nxpkg-linux-validation-final/steps.json` |
| Normal linking, fresh units | 83 checks passed | `normal/fresh/steps.json` under that directory |
| Normal linking, cached source-hidden units | 98 checks passed | `normal/cached/steps.json` |
| Smart linking, fresh units | 83 checks passed | `smart/fresh/steps.json` |
| Smart linking, cached source-hidden units | 98 checks passed | `smart/cached/steps.json` |
| Low-level lifecycle and GNU assembler package execution | Passed | Top-level `lifecycle-*` and `external-assembler-*` logs |
| Ordinary Linux EXE/SO exports, both compiler entry points | 50 checks each; includes fresh/cached and normal/smart builds | `normal/ordinary-exports/steps.json`, `normal/experimental-exports/steps.json` |
| Production package rejection; source-free SDK relocation; source and SDK immutability | Passed | Top-level workflow logs, normal and smart |
| PowerShell WSL build and tests | Passed, including 83 runtime/publication checks; existing completed SDK rejected with readable diagnostics | `output/linux-packages-dev/wsl-wrapper-final.log`, `wsl-wrapper-existing-sdk.log` |
| Windows late loader/publication | 50 checks passed | `C:/temp/nxpkg-linux-port-win2/steps.json` |
| Windows metadata, ordinary exports, profiler cache | 70, 32, and 41 checks passed | `C:/temp/nxpkg-linux-port-metadata`, `nxpkg-linux-port-exports`, `nxpkg-linux-port-profile` |
| Full clean bootstrap and cross matrix | Passed: native compiler/RTL/packages/utilities, option/directive regressions, all 13 retained RTL targets, Linux FmtBCD and `heaptrc -CfNONE` | `output/NexusFPCBootstrap/20261009-143454-4fab1545/steps.json` |

The bootstrap's 14 nonfatal warnings match the prior baseline: 13 dependency-cycle
warnings and the existing missing `winmanutf8lfn` source warning. No planned
validation remains failing. The implementation is uncommitted.

Reusable normal/smart SDKs are under `normal/sdk` and `smart/sdk` in the Linux
validation directory. The separately built PowerShell-workflow SDK is at
`/var/tmp/nxpkg-linux-powershell-sdk`. Windows can inspect these through
`\\wsl.localhost\Ubuntu\var\tmp`. A concise environment/suite summary is saved in
`output/linux-packages-dev/linux-validation-summary.json`.

An intermediate fresh build failed without compiler diagnostics when accumulated
development artifacts filled the WSL `/tmp` RAM filesystem. Those artifacts were
archived under `/var/tmp/nxpkg-linux-development-20261009`; the successful final
validation used persistent storage. Final tests retain the original runtime
expectations, including actual native unmapping and rejection cases.

## Decisions and remaining limits

| Decision | Benefit | Cost or alternative left open |
| --- | --- | --- |
| x86-64 glibc first | A concrete Linux runtime with execution evidence. | i386 and AArch64 package runtimes remain disabled; ordinary cross-build success does not validate packages on those CPUs. Each needs startup, relocation and runtime execution tests. |
| Native Linux Python SDK tools, with a WSL wrapper | Uses the real Linux loader/toolchain and supports Linux CI without requiring PowerShell on Linux. | Windows-hosted cross-package distribution is not provided; Linux and Windows artifact-validation tools must be maintained separately. |
| `RTLD_LOCAL` and explicit dependencies | Keeps imports tied to declared package owners. | Plugins cannot resolve undeclared symbols merely because another plugin was loaded globally. |
| `-Bsymbolic`, PIC, PIE and RELRO | Preserves canonical owned symbol addresses and keeps relocated metadata protected after loading. | ELF interposition of package-owned Pascal symbols is deliberately unavailable; existing non-PIC units must be rebuilt for the SDK. |
| Exact SDK and package build identities | Detects stale/mixed artifacts before Pascal initialization. | A provider rebuild requires rebuilding dependent artifacts; this is not a stable ABI across arbitrary compiler versions. |
| Preserve failed images until exit | Prevents cleanup failures from leaving executable pointers into unmapped code. | Failed images retain memory/native references for the process lifetime. |
| Existing synchronous lifetime contract | Reuses the agreed manager without threads. | Application-held objects/callbacks remain the caller's responsibility; concurrent load/unload is unsupported. |
| musl deferred | Avoids claiming unload semantics not validated by this design. | Alpine/musl is outside the supported SDK. Android/Bionic and Apple platforms remain separate work. |

Validation on the installed WSL glibc version is not a certification of every
glibc distribution or older version. Build on the oldest intended deployment
baseline and test those target systems before publishing a portable SDK. The
generated compiler and shared RTL import `GLIBC_2.34` symbols, so these particular
artifacts require glibc 2.34 or later; only 2.43 was exercised here. Linux
GUI toolkit integration, IDE design-time packages, broad generic/attribute
coverage, and backlog item 15 remain follow-on work.
