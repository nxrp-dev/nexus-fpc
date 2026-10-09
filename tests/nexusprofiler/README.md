# Nexus profiler regressions

## Compiler-injected runtime and cached PPUs

From the repository root:

```powershell
python tests\nexusprofiler\run_profile_cache_tests.py
```

Requires a built native Win64 NexusFPC compiler and matching RTL, Python 3, and
LLVM tools on PATH. `--compiler` and `--rtl` select a candidate build.
`--output-root` accepts a new or empty directory. By default, the runner creates
a fresh temporary directory and records commands, expected exit codes, and logs
in `steps.json`.

The 41 steps cover:

- A profiled runtime PPU followed by an ordinary trace-probe build and a profiled
  application using the same unit cache. The application rebuilds the invalidated
  implicit runtime without `-B`, then runs with a complete trace.
- Normal and smart linking, repeated cached builds, unchanged valid runtime and
  application unit hashes, and eight calls with one exception unwind.
- Profiling-to-ordinary transitions without retained instrumentation or trace
  output, ordinary-to-profiling reuse with deliberately partial coverage, and an
  explicit `-B` restoring instrumentation.
- An application with no uses clause, loading the runtime from source only. Its
  implicit runtime symbols remain visible after sequential dependency processing.
- A missing runtime and an invalidated runtime PPU whose source was removed.
  Both produce unit diagnostics; neither produces an internal compiler error.

The original mixed-cache case fails on the committed `d4002ae8` compiler with
internal error `2026032615`. The correction registers NXProfilerRuntime as an
implicit uses dependency and routes it through `loadunits` and the existing
sequential continuation. It does not change profiling coverage policy, PPU
format, or the profiler runtime's implementation.

On 2026-10-09, all **41/41 steps passed** with both the isolated candidate and the
freshly bootstrapped optimized compiler. The optimized run is recorded in
`C:\Users\kcollins\AppData\Local\Temp\nx-profile-cache-hhj3qvyh\steps.json`.
The baseline failure is recorded in
`C:\Users\kcollins\AppData\Local\Temp\nx-profile-cache-4z8efntp\normal-mixed-build.log`.
The same correction passed the full clean native/cross bootstrap, all 13 RTL
targets, package runtime/link/metadata checks, and ordinary EXE/DLL export checks.
See [the saved validation results](../../nexusfpc-dynamic-packages-gap-analysis.md#implementation-results-items-6-10).

## Existing profiler suites

`Run-NexusProfilerTests.ps1` covers the broader profiler behavior, including
format, activation, calls, exceptions, existing thread support, control, and
optimized builds. `Run-NXProfileFormatTests.ps1` covers the format and event-memory
fixtures separately. Supply `-SourceRoot`, `-Compiler`, `-RtlUnits`, and a fresh
`-OutputRoot` when invoking these scripts directly.
