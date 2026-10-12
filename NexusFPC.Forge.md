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
to match byte for byte, then builds and checks the Win64 release tools.
The public outputs are `build/forge-bootstrap/cycle3/ppcx64.exe`, `cycle3/rtl64`,
and `build/forge-bootstrap/tools/bin`.

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

No make or fpmake process is used. Other packages are deferred while the owner
selects them individually; migrating them does not block this compiler release.

For a complete Windows-hosted release, run the projects sequentially from this
directory. The target list below is the retained matrix shown above:

```powershell
$forge = '..\..\nexus\output\NexusForge-next\x86_64-win64\nxforge.exe'
& $forge /input=NexusFPC.Forge.nxscript /targets=Build:Bootstrap
if ($LASTEXITCODE -ne 0) { throw 'Bootstrap failed' }
foreach ($target in @('i386-linux','x86_64-linux','aarch64-linux',
    'i386-win32','x86_64-win64','aarch64-win64',
    'x86_64-android','aarch64-android','x86_64-darwin','aarch64-darwin',
    'x86_64-iphonesim','aarch64-iphonesim','aarch64-ios')) {
    $cpu,$os = $target -split '-'
    & $forge /input=NexusFPC.Forge.nxscript "/targets=Build:Cross,TargetCPU:$cpu,TargetOS:$os"
    if ($LASTEXITCODE -ne 0) { throw "Cross build failed: $target" }
}
& $forge /input=NexusFPC.Forge.nxscript /targets=Build:Release
if ($LASTEXITCODE -ne 0) { throw 'Release failed' }
```

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

`CompareFiles VerifyBootstrap` belongs to the Bootstrap Project and must succeed
before the build succeeds. The Package/Project contract adds no
special bootstrap executor, implicit FPC call, cache, or success shortcut.
No make/fpmake process is used for these generation steps.

## Release tools

`NexusFPC.Forge.Tools.nxscript` runs as an ordered Group at the end of Bootstrap.
To rebuild just the tools after a completed bootstrap:

```powershell
& ..\..\nexus\output\NexusForge-next\x86_64-win64\nxforge.exe /input=NexusFPC.Forge.nxscript /targets=Build:Tools
```

The Tools Project exports its binary directory, driver and resource compiler.
It builds these 18 Win64 tools using the verified native compiler:

| Purpose | Executables |
| --- | --- |
| Compiler launcher and PPU tools | `fpc`, `ppufiles`, `ppumove` |
| Compiler input generators | `mkx86ins`, `mkx86reg`, `mkx86inl`, `mka64ins`, `mka64reg`, `msg2inc` |
| Data, dependencies and translations | `data2inc`, `bin2obj`, `ppdep`, `rstconv` |
| Resources and executable metadata | `fpcres`, `fpcreslipo`, `postw32` |
| Lexer/parser generators | `plex`, `pyacc` |

The output directory includes `ppcx64.exe` beside `fpc.exe`, and `yylex.cod` and
`yyparse.cod` beside their generators. The launcher can therefore find its native
compiler without an installed FPC on PATH. The Release Project adds the matching
target RTLs and compiler-relative configuration for application unit searches.

Each tools build clears its own output tree, stages tool and required package
source, and uses separate unit directories for each executable. It consumes no
installed package PPUs. Tools use the captured bootstrap date/time.
A tools-only build reads the current
utility/package sources and the previously staged compiler sources.

Makefile generators (`fpcmake`/`fpgmake`), the retrying file-deletion utility
`rmwait`, and the configuration generator `fpcmkcfg` are retired. Forge copies
the fixed release configuration directly. The `fpmkunit` and `fcl-process`
sources are no longer staged for release tools; package selection remains
separate. The JVM resource utility (`fpcjres`) is also excluded.

The final `Test-ReleaseTools.ps1` child checks driver dispatch, binary includes,
PPU reading, dependency and translation output,
resource conversion/sharing, generated lexer/parser compilation and execution,
and regeneration of the compiler tables/messages. `ppumove` and `postw32`
receive help/startup checks, not exhaustive behavioral tests.

Runtime checks required small source corrections: `ppdep` now sizes string
results before writing them; the lexer/parser helpers allocate strings normally;
lexer nodes use typed allocation including alignment padding; and the instruction/
register generators check for empty lines before indexing. No compiler backend
or Forge engine changes were required. `ppdep` remains a line-oriented scanner:
its fixture places the program and uses clauses on separate lines.

## Release assembly

After Bootstrap and all 13 Cross builds have completed, assemble the distribution:

```powershell
& ..\..\nexus\output\NexusForge-next\x86_64-win64\nxforge.exe /input=NexusFPC.Forge.nxscript /targets=Build:Release
```

The Release Project exposes Directory, Bin, Config, Identity and PackageSDK outputs.
It first builds the runtime-package SDK described below. Its ordered children
in `NexusFPC.Forge.Release.nxscript` validate the remaining build inputs,
copy the artifacts and release configuration, and
verify the relocated distribution. It consumes completed Bootstrap/Cross builds
and does not silently omit missing targets. SDK construction and input checks
run before clearing the previous distribution.

The output is `build/forge-bootstrap/distribution/`:

- `bin/x86_64-win64/`: the 18 release tools, lexer/parser skeletons, `ppcx64`,
  `ppcross386`, `ppcrossa64`, and `fpc.cfg`.
- `units/<cpu>-<os>/rtl/`: compiled RTL units, objects and associated resources
  for the 13 targets. The internal `buildrtl` build helper is excluded.
- `build-identity.json`: the identity captured by the bootstrap.
- `package-sdk/x86_64-win64/`: compiler, shared `nxrtl` PCP/DLL, per-image startup
  units, the Forge package build recipe/template and the SDK manifest. Build intermediates
  are excluded. This is the Win64 runtime-package SDK, separate from the static
  target RTL directories.

The cross builds produce identical compiler binaries for each CPU across their
operating systems. Preflight verifies that equality before shipping one compiler
per CPU. The driver selects that compiler with `-P`; `-T` selects its target OS
and matching RTL. For example, from the distribution's binary directory:

```powershell
& .\fpc.exe app.pas
& .\fpc.exe -Pi386 -Twin32 app.pas
& .\fpc.exe -Paarch64 -Tlinux app.pas
```

`scripts/NexusFPC.Release.cfg` is copied unchanged. It uses the compiler's
existing `$FPCBINDIR` and `$FPCTARGET` macros. These are FPC configuration macros,
not NexusScript reference syntax. No checkout, seed installation, or machine-specific
path is embedded. The compiler retains its normal configuration overrides.

LLVM tools must be on PATH; the release selects the existing Clang assembler
and LLD linker paths. LLVM, Android NDKs, Apple SDKs and platform sysroots are
external prerequisites and are not bundled by this assembly. Application links
that require SDKs/sysroots still need those toolchains and their options.

`Test-ReleaseDistribution.ps1` checks copied artifacts, then copies the release
to a new path containing spaces. With installed compiler paths and configuration
environment variables removed from its test process, it compiles against all 13
target RTLs and checks that every loaded PPU belongs to the relocated target.
It also links six Windows/Linux smoke programs, runs the Win64 and Win32 programs,
exercises the shipped resource tool, and verifies that a missing RTL produces a
failure. Android and Apple checks compile units only; they do not validate SDK
linking or execution. Evidence stays in `build/forge-bootstrap/release-checks/`.

Other package builds and their runtime-package distribution artifacts remain
outside this assembly until the owner selects them.

The relocation check exposed a Windows LLD response-file quoting defect when a
library directory contained spaces and ended in a backslash. The two `/libpath:`
emitters now normalize separators to forward slashes before quoting, preserving
the directory while preventing its final backslash from escaping the closing quote.

## Runtime-package SDK

After Bootstrap, build just the Win64 SDK with:

```powershell
& ..\..\nexus\output\NexusForge-next\x86_64-win64\nxforge.exe /input=NexusFPC.Forge.nxscript /targets=Build:PackageSDK
```

The PackageSDK Project exposes Directory, Manifest, Packages and Units outputs.
Its group in `NexusFPC.Forge.PackageSDK.nxscript` copies the verified native
compiler and matching RTL into an isolated SDK work directory, compiles `nxrtl`
with an FPC child, then compiles `SysInitPkg` against that package with a second
FPC child. Only the per-image resource adapter and startup units enter the public
SDK unit directory; the provider metadata comes from `nxrtl.pcp`.

All RTL/package source comes from the bootstrap staging tree, including the
`.ppk` declaration now staged by Bootstrap. Rebuild older bootstraps that lack it.
The SDK build does not regenerate the compiler, rebuild the base RTL with make,
or modify the bootstrap RTL cache. Release assembly invokes this same group and
ships its public files; no alternative SDK build path is maintained.

Native Forge `PackageSDKOptions` writes the identity response files before the
FPC children run; `PackageSDKManifest` writes the final Format 2 manifest afterward.
The SDK identity hashes the compiler, actual compiled RTL inputs, staged RTL
sources and captured build options. Each foundation build receives a fresh package
build ID. The manifest operation checks the resulting PCP/DLL identity pair without
loading the DLL, then hashes the compiler, foundation and startup artifacts. Both
operations use the existing ordered group execution. SDK generation and consumer
compilation no longer invoke PowerShell internally. The SDK ships
`forge/PackageBuild.nxscript` and `forge/FPC.mustache`; it does not ship PowerShell
compile/artifact helpers. Consumers compose the group with their SDK, source,
provider, work and output paths using the installed Forge language definitions.

`PackageBuildPrepare` verifies the SDK and selected PCP/DLL dependencies and
writes the compiler response file plus the input hash record. The ordinary FPC
child compiles in the work directory. `PackageBundlePublish` checks unchanged
inputs, matching identities and dependency build IDs before copying a complete
generation and atomically updating `current.json`. Rejected builds preserve the
previous selection. The group explicitly clears its dedicated work directory.

This is a temporary native migration of SDK policy, pending the owner's later
architecture review. The source `Invoke-NexusFPCPackageCompile.ps1` remains a
thin Forge-document/log adapter for existing example/test callers. The separate
PowerShell artifact helper still serves older test utilities and example run
selection; native package builds do not call it. No general dependency resolver,
version selection or new execution lifecycle was introduced.

`Build-NexusFPCPackageSDK.ps1` now delegates to the Forge target. It can export
the public SDK files to `-OutputRoot` and retains its optional example builds/runs;
it no longer accepts a seed directory. Its `-SmartLink` option applies to example
consumers. The foundation has one standard release build, usable by both ordinary
and smart-linked consumers. See the [SDK guide](examples/dynamic-packages/README.md)
for the layout and developer commands.

The native SDK metadata migration was verified on 2026-10-12 using nxbuild and
NexusFPC. The isolated `Build:PackageSDK` completed in 4.49 seconds. Its SDK
identity and all nine artifact hashes matched the retired PowerShell writer
on the same inputs. After removing that writer from the isolated checkout,
the SDK built again and the relocated console and GUI examples passed with
ordinary and smart-linked consumers: shared identity, managed ownership,
initialization and finalization. The 50-test Forge suite passed with no
unfreed heap blocks; coverage includes deterministic fingerprints, new build
IDs, ordered output consumption, malformed PCP/PE input, identity mismatches,
compiler-query failures and preservation of an existing manifest on failure.
Evidence is under `C:/gitdev/nexus/output/ForgeIdentity/package-sdk*.log` and
`C:/gitdev/nexus/output/ForgeVerification/package-sdk*.log`. Compiler source and
cross-target recipes were unchanged; the full compiler matrix was not rerun.

The native consumer migration was also verified on 2026-10-12:

- The exported SDK contained the Forge recipe/template and no PowerShell helpers.
  Builds used relocated SDK paths containing spaces.
- All eight application runs passed: console and GUI hosts, startup and late
  loading, ordinary and smart-linked. Checks covered shared identity, managed
  ownership, initialization/finalization, resources, registries, unload and reload.
- The documented Forge-only two-group package/application example compiled and
  ran, printing `forge-native-package-ok`.
- Rebuilding a provider while its existing dependents required the old build ID
  was rejected. An intentional application compilation failure was also rejected.
  Both retained the previous `current.json` byte for byte.
- The expanded 50-test Forge suite passed with zero unfreed heap blocks.
  Regression coverage includes the named FPC package switches, preparation and
  publication order, unchanged input hashes, paired identities, exact dependency
  builds, manifest tampering, selection paths and preservation of published output.

Consumer logs are under `C:/gitdev/nexus/output/ForgeIdentity/package-consumers/`.
The final suite log is `C:/gitdev/nexus/output/ForgeVerification/package-consumer-tests-final.log`.
The recipes, behavior and results are recorded here so those disposable validation
directories can be removed without losing the implementation or its instructions.

## Release policy

The compiler uses the standard `-O2 -Ur -Xs` release settings. Bootstrap clears
its seed outputs as well as each native generation, so seed PPUs and options
files cannot carry over from an earlier build. Cross recipes use the final
ordinary native compiler and RTL. Stripping removes compiler debugging symbols.

The owner explicitly declined additional whole-program optimization passes on
2026-10-11 after measurement. The WPO recipe and the Forge settings added for it
have been removed. WPO is not a remaining make-parity requirement for our compiler
release. This decision concerns how we build the compiler; it does not remove
existing compiler optimization features available to application developers.

The evaluated WPO build was 2.67% smaller, but the timing difference was within
observed variation. Compiling the same compiler source with fresh unit directories,
identical options and ordinary RTL gave these medians after one warm-up per
compiler and three measured samples in alternating order:

| Compiler | Median compile seconds | Executable bytes |
| --- | ---: | ---: |
| Ordinary `-O2`, stripped | 14.208 | 4,407,296 |
| Evaluated WPO build, stripped | 14.151 | 4,289,536 |

Both compiler variants produced identical output executables across all eight
compilations. The 0.4% timing change did not establish a useful speed improvement.
The additional build passes and maintenance cost were therefore rejected. Measurement evidence remains in
`C:/gitdev/nexus/output/ForgeRelease/benchmark`.

Forge's additions are limited to the FPC definition/template settings
`StripSymbols` and `ResponseFiles`, plus their tests and documentation. Forge's
Pascal executor and the NexusScript implementation are unchanged.

## Build identity

The bootstrap runs Forge's native `BuildIdentity` operation after staging source.
`Repository` selects the source checkout and `OutputDirectory` selects the seed
directory. It captures the full Git HEAD commit and a `-dirty` suffix when tracked or
untracked, non-ignored files differ. This identifies the base revision and dirty
state; it is not a fingerprint of the uncommitted changes. A Git checkout is
required for this recipe.

The operation writes `seed/source/revision.inc`, `seed/build-identity.json`, and
`seed/build-options.cfg` directly, using Git on PATH with no PowerShell writer.
It requires staged `source/version.pas` and validates the timestamp before
writing any of the three files. Compiler builds enable the existing `REVINC` define.
The response file freezes `%DATE%` and `%TIME%` using the HEAD commit timestamp
in UTC, or `SOURCE_DATE_EPOCH` when supplied. The stock 3.2.2 seed lacks `-DD`;
it embeds the revision, while every subsequent Nexus compiler stage uses the
fixed date/time. The temporary stock-built seed is not a distribution artifact.

This is an intentionally contained implementation: Forge currently owns these
three FPC file formats in `utNXForgeBuildIdentity.pas`. It does not introduce
runtime NexusScript values or change Render's preparation behavior. The retired
PowerShell writer's checks now belong to the NexusForge test suite.

Cross builds reuse the captured identity and staged source. They do not relabel
that source using the current checkout's revision. Both native and cross recipes
finish their compiler construction with `Test-NexusFPCBuildIdentity.ps1`, which
checks `-iW` and `-iD` against the captured record and fails on a mismatch.

The native identity replacement was verified on 2026-10-12 with Forge and its
tests rebuilt through nxbuild using NexusFPC. All 48 Forge checks passed with
zero unfreed heap blocks, including a fixed `SOURCE_DATE_EPOCH` environment,
clean/dirty/untracked source, repeatability, invalid timestamps, and failure
ordering. The isolated native bootstrap passed in 139.13 seconds; generations
two and three share SHA-256
`819773E900312FEE25C5BF3BFAB9D76F1CAD9F50718B9CE6B2BB9C2A2670B89F`.
Release-tool validation passed for 18 tools, 29 execution steps, and 64 table
comparisons. A representative i386-win32 cross build passed in 25.40 seconds,
preserved the identity record byte for byte, verified its compiler identity,
and ran its smoke executable successfully. The other cross targets were not
rerun for this metadata-only change. Logs are under
`C:/gitdev/nexus/output/ForgeIdentity` and `output/ForgeVerification`.

## Verification

Retiring `rmwait` and `fpcmkcfg` passed against the existing verified bootstrap
and cross matrix in the isolated checkout. A fresh Tools build produced all 18
remaining tools; all 29 execution checks and 64 generated-table comparisons
passed. Release assembly passed all 23 existing distribution checks, including
all 13 relocated target compilations, six links and Win32/Win64 execution.
The directly copied configuration has the same content as the previous generated
configuration. Retired executables are absent from the rebuilt tools, release
and relocated release. The compiler and RTL were unchanged and were not rebuilt
for this utility-only removal. Earlier verification counts below include the
utilities that were subsequently retired.

The Make retirement pass passed in an isolated checkout with all retired source
files physically absent:

- Fresh native bootstrap: 376.14 seconds. Compiler generations two and three
  were byte-identical; all 20 tools built and all 32 existing tool checks passed.
  All 64 generated table includes matched.
- Fresh builds of all 13 cross compiler/RTL targets: 771.53 seconds total, with
  no failures or reused cross outputs.
- Release assembly, including Win64 SDK construction: 52.93 seconds. All 23
  existing distribution checks passed, including the relocated 13-target unit
  builds, six linked programs and successful Win32/Win64 execution.
- All 12 public SDK files matched their build outputs and relocated copies.
  Build intermediates were excluded. A consumer built using the relocated SDK's
  shipped helper ran successfully and printed `forge-package-sdk-ok`.

Evidence is under `C:/gitdev/nexus/output/ForgeRelease/make-retirement/`:
`bootstrap-result.json`, `cross-results.json`, `release-result.json`,
`sdk-result.json` and the corresponding build logs. Compiler and RTL runtime
source, Forge recipes and test implementations were unchanged by this retirement.
Apple/Android application linking and non-Windows execution were not tested.

The runtime-package SDK migration passed in the isolated checkout:

- Fresh native bootstrap and all 32 existing release-tool checks: 243.68 seconds;
  compiler generations two and three were byte-identical. The native compiler
  also matched the previous full-matrix compiler, so the 13 cross builds were
  reused and their compiler equality was checked again by release preflight.
- Standalone `Build:PackageSDK`: 17.10 seconds. All 183 copied RTL artifacts still
  matched the bootstrap cache after SDK construction.
- The PowerShell wrapper passed with both an exported SDK in a path containing
  spaces and its default output directory. Existing console and GUI examples
  passed in ordinary and smart-link modes, including identity, managed ownership
  and exact initialization/finalization order.
- `Build:Release`, including SDK construction and all 23 existing distribution
  checks: 186.98 seconds. All 12 shipped SDK files matched their build outputs and
  the relocated copies. SDK work directories and examples were excluded.
- A consumer compiled through the shipped helper in the relocated distribution
  ran successfully and printed `forge-package-sdk-ok`.

Evidence is under `C:/gitdev/nexus/output/ForgeRelease`: `package-sdk-bootstrap*`,
`package-sdk-build*`, `package-sdk-examples*`, `package-sdk-smart-*`,
`package-sdk-release*`, `package-sdk-rtl-copy.json`, and
`package-sdk-shipped-check/result.json`. These are local validation results;
no new ad hoc regression suite or Forge test integration was added in this pass.

The release assembly pass, including the Windows LLD path correction, passed
in the isolated checkout:

- Clean bootstrap and its 32 release-tool checks: 145.45 seconds; cycles two
  and three were byte-identical.
- All 13 cross compiler/RTL builds: 415.44 seconds total, no failures.
- All 51 Win64/LLD contract checks passed.
- Release assembly and verification: 53.51 seconds. All 23 execution checks
  passed, including compilation for all 13 relocated targets, six linked
  programs, two executed programs and the expected missing-RTL rejection.
- The distribution contains 20 tools, three compiler binaries and 2,499 RTL
  unit/object/resource files. Copied artifacts matched their build inputs.
- Preflight rejected stale cross compilers before modifying the previous release.

Evidence is under `C:/gitdev/nexus/output/ForgeRelease`: `distribution-bootstrap*`,
`distribution-cross-*`, `distribution-win64-contracts/`, `distribution-build*`,
and `distribution-preflight-results.json`. The isolated build's `release-checks/`
contains individual relocation logs and `results.json`. Apple/Android application
linking and non-Windows execution remain untested.

The preceding tools/release-policy pass without WPO also passed in an isolated checkout:

- Clean native bootstrap including release tools: 123.85 seconds; cycles two and
  three and the compiler copied beside the driver were byte-identical.
- Release tools: all 20 built, all 32 execution steps passed, all 64 generated
  table includes and both message includes matched the bootstrap outputs.
- The new driver also compiled and ran a Win32 program and selected the AArch64
  cross compiler through an explicit compiler search path.
- Forge: the existing 47-test run passed with no failures or unfreed memory
  blocks. This tools pass did not change Forge source, definitions or templates.
- Win64/LLD contracts: all 51 steps passed using the new compiler, RTL and the
  newly Forge-built `fpcres`.
- All 13 Windows-hosted cross compiler/RTL targets passed in the preceding matrix
  run. This pass produced the identical native compiler. Each cross compiler
  was byte-identical to its earlier output produced by the evaluated WPO compiler.
- Win32 and Win64 smoke programs ran successfully. Linux smoke programs linked;
  non-Windows execution and Apple/Android application linking were not tested.
- Identity tests covered clean, modified and untracked source, fixed UTC epochs,
  repeatability, invalid epochs and the default commit date. The identity verifier
  also rejected deliberately incorrect revision and date records.

Evidence is under `C:/gitdev/nexus/output/ForgeRelease`: `tools-bootstrap.log`,
`tools-bootstrap-result.json`, `tools-win64-contracts/`, `driver-cross/`, and the
isolated build's `tools/checks/` cover the release tools pass. The `standard-*`
logs record the preceding compiler/cross matrix; `benchmark/` preserves the measurements
behind the release policy. Timings are observations, not performance guarantees.

## Make retirement

The Windows-hosted compiler bootstrap, standard release settings, generated inputs,
release tools, retained cross-target compiler/base RTL matrix, configuration
generation, Win64 runtime-package SDK construction and compiler distribution
assembly use Forge.

The last committed tree before this retirement is `455d14b8`; the old recipes
and scripts remain available in Git history for reference.

The following obsolete infrastructure has been removed:

- Root, compiler, RTL and utility makefiles, fpmake aggregates and regeneration
  scripts, including the Android make overlay.
- The `fpcmake` and `fpgmake` generators and their templates, `rmwait`, and
  `fpcmkcfg` with its templates and old `samplecfg` wrapper. The `fpmkunit`
  package remains under the separate package-selection work; it is no longer
  a release-tool dependency.
- Both copies of `Invoke-NexusFPCBootstrap.ps1`, `NexusFPCBootstrapSeed.ps1`, and
  the old Linux/Android cross-build wrappers. Use the Forge commands above.
- The upstream make-based GitLab CI configuration. A future CI configuration
  must invoke Forge on an appropriately provisioned host.
- The native Linux SDK make builder and its WSL wrapper. Native Linux-hosted
  compiler/SDK construction through Forge remains deferred. Linux runtime,
  package declarations and startup sources remain. Existing Linux SDK consumption
  and publication now use native Forge; the Python helpers are removed.
  The Windows-hosted Linux cross builds are unchanged.

The `packages/` and `tests/` recipes are retained under the owner's separate
package-selection and nxtest work. They are not build entry points for the
compiler release. Legacy test runners which rebuild through the removed make
infrastructure will need replacement during that work; this pass does not add
ad hoc test compatibility paths. Historical documents and logs may describe the
old commands as evidence of earlier results.

Dynamic-library and runtime-package support is standard compiler functionality
on supported targets. Developers choose static linking or runtime packages;
there are no separate compiler editions for those choices. Distribution recipes
must produce the units and runtime-package artifacts those choices require.
Historical make shared/smart targets are not an independent migration requirement.

Ad hoc regression-suite integration is explicitly excluded from this migration.
Testing will move to nxtest through later work; maintaining additional Forge
integration for the current ad hoc suites is not a prerequisite for retiring make.
