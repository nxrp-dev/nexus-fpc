# NXPC source repository

## Synopsis
NXPC is the Nexus Pascal compiler and runtime, forked from [Free Pascal](https://www.freepascal.org/).


It contains
* The compiler sources in the directory *compiler*.
* The run-time library in the directory *rtl*.
* The packages distributed with the compiler in the directory *packages*.
* Several utilities in the directory *utils*.
* The compiler testsuite in the directory *tests*.

NXPC uses its own [compiled artifact identities](nexusfpc-artifact-identity.md):
`NXU` in `.nxu` files and `NXP` in `.nxp` files. Numeric format revisions are
independent of upstream FPC. Rebuild the compiler, RTL, units and packages together
when moving from an earlier build; upstream compiled units cannot be reused.

The installed command is `nxpc`, with backends `nxpc-x86_64`, `nxpc-i386`
and `nxpc-aarch64`. Its configuration is `nxpc.cfg`. Compiler configuration,
executable and message overrides use `NXPC_CONFIG_PATH`, `NXPC_EXEC_PATH` and
`NXPC_ERROR_FILE`; `NXPCDIR` selects the compiler installation root. These names
are separate from stock FPC. Platform unit overrides likewise use the `NXPC_`
prefix, for example `NXPC_LINUXUNITS` and `NXPC_WIN64UNITS`. Language modes and FPC compatibility symbols remain
available to source code. nxbuild and Forge distinguish `NXPC` product builds
from genuine `FPC` builds. Initial bootstrap generators and the seed compiler
still build with stock FPC 3.2.2; subsequent stages use NXPC.

## Building NXPC

Forge owns compiler bootstrap orchestration. On Linux, nxbuild projects own
compilation of the generators, seed, three compiler/RTL generations and retained
Users units. Forge verifies convergence and compiler identity, installs the
matching compiler/RTL, and builds/runs native and shared-library NXTests.
Windows-hosted bootstrap, cross builds, release tools and the Win64 runtime-package
SDK remain Forge projects.

All generated files belong in a selected worktree `BuildRoot`, outside source.
Use the commands and prerequisites in [NXPC with Forge](NXPC.Forge.md).
The Linux Python helper in nexus-private is a launcher for that entry point and
contains no independent build logic. Makefiles, make generators, fpmake and
make-based bootstrap/cross scripts have been retired.

[Recovered package build requirements](nexusfpc-package-build-requirements.md)
record useful details from the removed package and test recipes. Native
[nxtest suites](tests/NXTEST.md) own unit coverage and document unresolved cases.

## Experimental Win64 dynamic packages

Complete the [Forge bootstrap](NXPC.Forge.md), then build the package SDK
and validate its console/GUI examples:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\dynamic-packages\Build-NXPCPackageSDK.ps1 -Forge C:/tools/nxforge.exe -BootstrapDirectory C:/dev/worktree/fpc-bootstrap -RunExamples
```

See the [package SDK guide](../nexus-lab/examples/packages/runtime-loading/README.md) for prerequisites,
distribution, and application build commands. Runtime-package support is standard
in the compiler on Win64 x86-64 and Linux x86-64/glibc; developers choose static
linking or runtime packages. This SDK recipe targets Win64 x86-64.

Build and run real late-loading console/GUI examples against that SDK:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\dynamic-packages\Build-NXPCLatePackageExamples.ps1 -SdkRoot build\forge-bootstrap\package-sdk -OutputRoot output\nxpkg-late -RunExamples
```

Use the SDK path printed by the first command. Late loading is synchronous.
[Unified threadvar storage](nexusfpc-threadvar-design.md) supports late package
storage under the single-threaded lifecycle contract; see the guide for unload
lifetimes and build identities.

## License
The compiler is licensed under GPL v2, the run-time files are licensed under modified LGPL. 
Both can be found in the LICENSE file, and the file rtl/COPYING.txt

## Documentation
Extensive documentation can be found on the [documentation website](https://docs.freepascal.org/). 
