# FPC Source code repository

## Synopsis
This repository contains the sources of the [Free Pascal](https://www.freepascal.org/) compiler distribution.


It contains
* The compiler sources in the directory *compiler*.
* The run-time library in the directory *rtl*.
* The packages distributed with the compiler in the directory *packages*.
* Several utilities in the directory *utils*.
* The compiler testsuite in the directory *tests*.

NexusFPC uses its own [compiled artifact identities](nexusfpc-artifact-identity.md):
`NXU` in `.ppu` files and `NXP` in `.pcp` files. Numeric format revisions are
independent of upstream FPC. Rebuild the compiler, RTL, units and packages together
when moving from an earlier build; upstream compiled units cannot be reused.

## Experimental Win64 dynamic packages

Complete the [Forge bootstrap](NexusFPC.Forge.md), then build the package SDK
and validate its console/GUI examples:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Build-NexusFPCPackageSDK.ps1 -RunExamples
```

See the [package SDK guide](examples/dynamic-packages/README.md) for prerequisites,
distribution, and application build commands. Runtime-package support is standard
in the compiler on Win64 x86-64 and Linux x86-64/glibc; developers choose static
linking or runtime packages. This SDK recipe targets Win64 x86-64.

Build and run real late-loading console/GUI examples against that SDK:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\Build-NexusFPCLatePackageExamples.ps1 -SdkRoot build\forge-bootstrap\package-sdk -OutputRoot output\nxpkg-late -RunExamples
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
