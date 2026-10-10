# Standard compiler package support

Date: 2026-10-10. Baseline: `73a409e1`.

The normal compiler supports both static applications and runtime packages on
Windows x64 and Linux x86-64/glibc. Package support is a standard target capability;
the developer chooses whether to link package dependencies. Other targets retain
their existing static/native-library support until their package runtime is ported.

## Implementation

- Enable `tf_supports_packages` in the Win64 x86-64 and Linux x86-64 target definitions.
- Remove the separate `ppcpkg` entry point and test wrapper. SDKs and tests build
  `compiler/pp.pas` and distribute the standard `ppcx64` executable.
- Preserve one package-capable code-generation model. Win64 references into other
  units can use indirect data/type symbols even in static builds. Linux PIC constant
  sections follow the existing package-capable relocation rules.
- Carry the Linux bootstrap Unicode fallback into the normal compiler entry point.
- Advance Nexus unit compatibility revision 34 to 35 so stale ordinary units are
  rejected or rebuilt. `NXU208`, `NXP004` and runtime descriptor v4 remain the formats.
- Replace tests that expected the normal compiler to reject packages with package
  acceptance checks. Exercise static hosts using the same SDK compiler, asserting
  that they run without a shared-RTL import. Keep unsupported-target loader coverage.

The SDK still supplies a matching shared foundation, startup units, metadata and
publication tools. A normal static application does not acquire a dependency on
`nxrtl` simply because its compiler supports packages. A package application selects
its providers explicitly; existing exact SDK/build identity checks remain enforced.

No new threads, alternate compiler implementation, legacy artifact reader, or
performance-based opt-out is introduced. Performance measurements inform later
optimization; they do not determine whether support stays enabled.

## Developer impact

Rebuild the compiler, RTL, application units and runtime package SDKs together.
SDK scripts retain their existing interfaces; the compiler inside `bin` is now
`ppcx64.exe` on Windows and `ppcx64` on Linux. Scripts that directly invoked the
removed `ppcpkg` name must use the standard name.

Static applications retain standalone deployment. Runtime package applications
retain shared-library deployment, explicit startup activation and managed loading.
The existing restrictions on late TLS lifecycle and caller-owned references during
unload are unchanged. This change does not add package runtimes to other targets,
IDE package integration, or automatic source-catalog dependency resolution.

## Timing method

`tests/dynamic-packages/run_package_support_benchmarks.py` compares two fully
bootstrapped compiler/RTL trees without rebuilding either tree in place. It compiles
identical input sources with `-n -O2 -B`, uses private output directories, warms
the tools and caches, alternates baseline/candidate order, and records seven samples
for the small build/runtime workloads and three for the full compiler rebuild.
Runtime outputs must have identical checksums. It measures:

- A small two-unit static application build.
- A full compiler source rebuild using each compiler and its matching RTL.
- A deliberately concentrated cross-unit global-data loop (200 million iterations).
- Allocation, strings, arrays, class identity and destruction (2 million objects).

Wall times include process launch and shutdown. The concentrated loop is diagnostic,
not a forecast for an application. These runs do not measure cold startup, peak
memory, or every application's workload. Do not run other validation jobs during
the timed samples.

```powershell
python tests\dynamic-packages\run_package_support_benchmarks.py `
  --baseline-root C:\gitdev\nps-base --candidate-root C:\gitdev\nps `
  --output C:\gitdev\nps-out\timings
```

## Validation and results

Validation used isolated source checkouts `C:\gitdev\nps-base` (committed baseline)
and `C:\gitdev\nps` (candidate). Candidate compiler source was compared with the
working tree after Git line-ending normalization. Windows evidence is under
`C:\gitdev\nps-out`; Linux workflow evidence is under WSL `/var/tmp/nps-linux-final`.

| Validation | Result | Evidence |
| --- | --- | --- |
| Clean native bootstrap, retained packages/utilities and six removed-option suites | Passed | `bootstrap/20261010-063128-afe75872/steps.json` |
| Full cross-compiler/RTL matrix | All 13 targets passed, plus Linux FmtBCD and isolated `-CfNONE` HeapTrc | Same bootstrap record |
| RTL compatibility audit | System and HeapTrc use NXU revision 35 on all 13 targets (26 artifacts) | `rtl-revisions.json` |
| Win64 native/LLD contracts | 51 checks passed | `contracts-win/steps.json` |
| Ordinary Windows EXE/DLL exports, normal/smart and fresh/cached | 32 checks passed | `exports-win/steps.json` |
| Artifact identity, utilities and revision-34 rejection | 29 checks passed | `identity/steps.json` |
| Package metadata and standard-compiler package acceptance | 72 checks passed | `metadata-2/steps.json` |
| Windows shared RTL and lifecycle, normal/smart and fresh/cached | 98 steps passed | `runtime-win/steps.json` |
| Windows late loader and atomic publication | 49 checks passed | `loader-win/steps.json` |
| Windows SDK, static host imports and source-free relocation | 25 checks passed | `sdk-workflow/steps.json` |
| Linux SDK, rebuilt normal compiler, static host imports, GNU assembler and relocation | 28 workflow checks passed | `/var/tmp/nps-linux-final/steps.json` |
| Linux runtime and publication | 83 fresh + 98 cached checks in each of normal and smart modes | `/var/tmp/nps-linux-final/{normal,smart}/{fresh,cached}/steps.json` |
| Unified threadvar storage | 29 steps passed on each platform | `threadvar-win/steps.json`; `/var/tmp/nps-threadvar/steps.json` |

The runtime suite has one fewer step because it no longer builds a second compiler
entry point. Both native bootstraps retained the same 14 existing warning lines
(13 circular package dependencies and the missing `winmanutf8lfn` registration).
The matrix validates compiler/RTL builds on other targets; runtime package execution
was validated on Windows x64 and Linux x86-64/glibc.

Initial test-only corrections updated the Linux expected unit revision and replaced
an invalid empty-package acceptance fixture with a real contained unit. Final runs
above passed. WSL client startup occasionally stalled and reported a systemd user
session warning; retrying the clients completed the work without service restarts.

## Measured timings

All validation jobs had finished before this Windows x64 comparison. Both compilers
were produced by the same clean native bootstrap procedure, with their own matching
RTLs. Each compiler built identical candidate compiler sources for the full-rebuild
measurement. Medians are wall-clock seconds; raw samples, ranges, commands, compiler
hashes, System-unit hashes and runtime checksums are in
`C:\gitdev\nps-out\timings\timings.json`.

| Workload | Baseline | Standard package support | Change | Samples per compiler |
| --- | ---: | ---: | ---: | ---: |
| Two-unit static build | 0.1790 s | 0.1910 s | +6.7% | 7 |
| Full compiler source rebuild | 11.3723 s | 11.8518 s | +4.2% | 3 |
| Cross-unit global-data loop | 0.3823 s | 0.3900 s | +2.0% | 7 |
| Managed allocation/type-identity workload | 0.5981 s | 0.6103 s | +2.0% | 7 |

These are local warmed measurements, not a guarantee for other applications or
hardware. Runtime sample ranges overlap, so the small runtime differences should
not be treated as precise universal overhead. The build timings show the observed
cost of the new default on these inputs. No timing result gates package support.
The rebuilt native compiler grew from 4,230,144 to 4,300,288 bytes (+1.7%).

All source changes remain uncommitted. `git diff --check` and changed Python syntax
checks passed. There is no remaining validation failure for this integration.
