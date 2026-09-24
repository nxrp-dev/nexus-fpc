# NexusFPC procedure tracing

NexusFPC can instrument physical Win64 x86-64 procedures and write a binary execution trace.

## Build the support units

```powershell
.\packages\nexusprofiler\Build-NexusProfiler.ps1 `
  -OutputDirectory $env:TEMP\nexusprofiler
```

The script builds the compiler-owned tracing support units with the repository compiler and the Win64 RTL. Install those units on the compiler unit path. `clang.exe` and `lld-link.exe` must be available on `PATH`.

## Build a profiled program

Add `-profile` to the normal NexusFPC command line:

```text
ppcx64 -profile -Aas-clang -XLL program.pas
```

No profiling unit, source annotation, or external profiler DLL is required. The compiler links the tracing runtime into the executable.

Removing `-profile` and rebuilding produces an ordinary binary without profiling imports or `.nxprof` metadata.

## Start and stop capture

Profiling starts active by default. Set the environment variable below before
launching an instrumented process to start it paused:

```text
NEXUS_PROFILE_START=paused
```

The runtime creates a hidden top-level window with class
`NexusFPCProfilerControl` and title `NexusFPCProfiler-<process-id>`. A controller
uses `RegisterWindowMessage` for these names and sends the resulting messages to
that window:

```text
NexusFPCProfiler.Start
NexusFPCProfiler.Stop
```

`Stop` immediately disables new capture, discards events and completed calls
that have not yet reached disk, resets the worker's call stacks, writes
`TRACE_END`, and closes the current trace. `Start` opens a fresh trace, writes
its metadata, and then enables capture. Each active interval therefore produces
one independent `.nxp` file. While capture is paused, generated hook calls
return before timestamp, thread-state, and event-memory work.

## Trace output

A profiled executable writes this file in its current directory:

```text
nexus-profile-<process-id>-<startup-counter>.nxp
```

The runtime records module, procedure, and thread metadata. Hooks capture entry,
normal leave, and unwind events in memory. The worker pairs those events and
writes one completed-call record containing caller, inclusive time, self time,
and return kind. Metadata strings are copied into runtime-owned `AnsiString`
values at module registration and serialized as null-terminated bytes inside
bounded binary records.

Profiling hooks acquire and finalize fixed records only through
`TNXProfileWriter`, which delegates record storage to `TNXEventMemory`. Full
blocks move to a completed queue only after every issued record is finalized
and no record acquisition against that block remains in flight. Publication is
a single atomic sealed-to-completed state transition. One background worker
collapses events, writes completed calls, and returns capture memory for reuse.
After a backlog drains, no more than 64 available capture blocks remain in the
warm pool. Hook execution performs no file I/O.

The writer facade exists during compiler-generated startup so early events can enter memory without initializing file classes. Normal unit initialization attaches the trace stream and starts the worker.

`NXProfile.pas` contains the binary writer and a small sequential reader. The reader validates record bounds, skips unknown record kinds, and preserves complete records before a truncated final record. Trace interpretation and reporting are intentionally outside that unit.

## Validation

```powershell
.\tests\nexusprofiler\Run-NXProfileFormatTests.ps1
.\tests\nexusprofiler\Run-NexusProfilerTests.ps1
```

The format tests include independent block lifecycle, reuse, and concurrent producer coverage for `TNXEventMemory`.
