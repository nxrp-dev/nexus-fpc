# Linux dynamic packages

Implementation date: 2026-10-09. Starting commit: `2acbb37a`.

## Supported scope

The experimental SDK adds **x86-64 Linux with glibc** to the existing shared-RTL
package model. Startup-linked packages and synchronous `LoadPackage`/`UnloadPackage`
use the same Pascal lifecycle manager as Win64. This is source-level runtime
package functionality for matching NexusFPC builds, not Delphi binary BPL support.

The normal compiler remains package-disabled. `ppcpkg` and its matching SDK are
explicit opt-ins. The 2026-10-10 [unified threadvar update](nexusfpc-threadvar-design.md)
adds late-loaded storage using the same model as startup storage. TLS-bearing
load/unload requires `IsMultiThread=False`. No workers or asynchronous lifecycle
are introduced. The application must release objects, interfaces, callbacks
and other references into a package before unloading it.

## Implementation

| Area | Linux implementation |
| --- | --- |
| Shared unit ownership | One `libnxrtl.so` owns System, ObjPas, SysUtils, Classes, TypInfo, FPCPackage and their closure, including native dynamic-library/resource adapters. Consumers import its units through `nxrtl.pcp`. |
| Image metadata | Nexus `NXP004` metadata, `NXU208` units (long revision 34), and the 168-byte descriptor v4 are used; all artifacts require rebuilding. See [artifact identities](nexusfpc-artifact-identity.md). ELF dependency relocations populate local pointer slots, preserving the descriptor's pointer-to-pointer ABI. Each image has a private six-word mutable context. |
| Linking and identity | All provider units use PIC. Relocatable constant tables go into `.data.rel.ro`; the package linker requires defined imports, prohibits text relocations, enables RELRO/eager binding, and binds owned definitions locally with `-Bsymbolic`. Hosts use PIE and prohibit COPY relocations. |
| Explicit startup | `rtl/linux/sysinitpkg.pp` reuses the existing glibc `si_c.inc` entry path. Activation runs from generated host startup after the native loader. Shared System initialization preserves the already active exception stack needed for rollback. |
| Native loading | `dlopen(RTLD_NOW | RTLD_LOCAL)`, explicit `DT_NEEDED` dependencies, and `dlclose`. Each managed late image has an independent native reference. No `dlmopen` namespace or global plugin-symbol publication is used. |
| Image ownership | `dladdr` maps code/data addresses to image bases. Opaque, pointer-sized native handles are stored separately from those bases. `dlinfo` prevents a plain SO from inheriting a dependency's package descriptor through `dlsym`. |
| Lifecycle and cleanup | Existing synchronous dependency accounting, activation, reverse finalization, rollback and failure retention are reused. Classes, aliases, enum aliases, component handlers, conversion callbacks, resources and explicit application cleanup hooks follow Linux image ownership. |
| Native resources | Each package exports its own resource location. The shared internal-resource implementation looks up resources with the image's native handle. |
| Dependency preservation | Declared requirements remain in PCP metadata and native linkage even when no symbols use them. Imported units retain native `$LINKLIB` requirements without copying provider unit objects into consumers. |
| SDK and publication | Native Python tools build an isolated compiler/RTL/SDK and validate PCP/ELF identity pairs without loading code. SDK and bundle hashes are enforced; complete immutable generations are selected atomically through `current.json`. |

The core changes are in `compiler/pkgutil.pas`, `compiler/pmodules.pas`, the Linux
linker and ELF/assembler writers, `rtl/linux/sysinitpkg.pp`, the System package
hooks, and `rtl/inc/fpcpackageloader.inc`. Existing Windows adapters still use the
Windows loader. Common lifecycle logic has not been duplicated.

## Build and use

On Debian/Ubuntu, install the native prerequisites:

```sh
sudo apt install fp-compiler fp-units-rtl fp-utils make gcc libc6-dev binutils python3 git
python3 scripts/build_linux_package_sdk.py --output-root /var/tmp/nexus-linux-sdk
```

The validated bootstrap is FPC 3.2.2. Source and SDK **build** paths must not
contain whitespace because of the existing RTL makefiles. The completed SDK and
application distributions support relocation to paths with spaces. WSL builds
isolate the native tool PATH from Windows tools.

From Windows PowerShell:

```powershell
.\scripts\Build-NexusFPCLinuxPackageSDK.ps1 -OutputRoot /var/tmp/nexus-linux-sdk -Distribution Ubuntu -RunTests
```

Use a new/empty SDK output directory. `--smart` or `-SmartLink` builds a smart-link
foundation. `--resume` is restricted to unfinished native SDK builds; a completed
SDK is immutable. Logs and intermediate files live under its `logs` and `work`
directories. Only `bin`, `packages`, `units`, and `sdk.json` are distributed.
Use disk-backed storage such as `/var/tmp` for repeated/full validation runs;
some Linux installations mount `/tmp` as a small RAM filesystem.

Create packages using the same declaration as on Windows:

```pascal
package mypackage;
requires nxrtl;
contains MyUnit;
end.
```

Compile with the matching SDK helper:

```sh
python3 /var/tmp/nexus-linux-sdk/bin/compile_linux_package.py \
  --source /project/mypackage.ppk --kind package --output /project/providers
python3 /var/tmp/nexus-linux-sdk/bin/compile_linux_package.py \
  --source /project/app.pas --kind program --require mypackage \
  --package-path /project/providers --output /project/application
```

`--unit-path`, `--package-path` and `--require` can be repeated. Use lowercase,
matching package declaration/file basenames. Keep all package dependencies from
the same SDK together. To replace a provider, rebuild it and its consumers in a
new bundle; replacing an already published provider in place is rejected.

`current.json` identifies the runnable generation. Deployment needs only the
executable and its `.so` files together; PCPs are build inputs. `$ORIGIN` RUNPATH
allows running from another working directory without `LD_LIBRARY_PATH`.

Use `LoadPackage('libmypackage.so')` for genuine late loading. A bare filename is
relative to the executable, as on Windows. Native `dlopen` alone maps the package
but does not activate Pascal units. The examples' `PackageNative` helper supplies
platform filenames and probes; applications need only the SysUtils package API.

## Verification

Run the complete native source-only workflow from the repository:

```sh
python3 tests/dynamic-packages/run_linux_package_sdk_tests.py --output /var/tmp/nexus-linux-validation
```

It builds fresh normal and smart SDKs, runs the lifecycle/late-loading/failure and
publication tests with fresh and source-hidden cached units, and checks SDK/source
immutability. It also rebuilds the ordinary compiler entry point, checks that it
rejects packages, runs ordinary EXE/SO export regressions, and rebuilds/runs hosts
from relocated distributions while original source, SDK and package build trees
are unavailable. Commands and per-step logs are recorded under the output path.

For an existing SDK:

```sh
python3 tests/dynamic-packages/run_linux_package_tests.py --sdk /var/tmp/nexus-linux-sdk
```

Add `--smart` and/or `--cached` for those configurations. Assertions include shared
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
