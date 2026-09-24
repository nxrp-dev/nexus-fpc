# NexusFPC Procedure Trace Profiling Work Plan

**Status:** Approved; threaded event-memory implementation validated  
**Revision:** 9
**Date:** 2026-09-23  
**Initial target:** Windows x86-64  
**Canonical document:** This file

## 1. Objective

Add compiler-directed physical procedure tracing to NexusFPC.

The compiler instruments a profiling build. A small runtime records timestamped
execution events in a versioned binary trace. A separate consumer can read that
trace and derive call counts, timing, abnormal exits, per-thread call trees, and
aggregate statistics. The initial reader is deliberately minimal; higher-level
analysis is deferred to its own design.

The durable product is the trace format. Analysis policy belongs to the
consumer and can evolve without recompiling or rerunning the traced program.

## 2. Developer Contract

Profiling is enabled for one top-level compiler invocation with:

```text
ppcx64 -profile program.pas
```

Removing `-profile` and rebuilding produces an ordinary nonprofiled program.

The developer does not add a unit, annotate procedures, change source files, or
configure individual project units. The compiler automatically links the
profiling runtime into the executable.

The initial implementation writes a deterministic file in the process current
directory:

```text
nexus-profile-<process-id>-<startup-counter>.nxp
```

Alternate paths, compression, sampling, filtering, blocking capture, and live
visualization are outside the initial implementation.

## 3. Scope

The initial implementation includes:

- Windows x86-64;
- Clang COFF assembly and LLD linking;
- programs;
- physical procedure entry, normal exit, and Win64 unwind events;
- FPC-created and foreign-created threads;
- a statically linked trace runtime;
- reusable fixed-capacity event-memory blocks;
- one background trace writer;
- module and procedure metadata;
- versioned binary trace output;
- a minimal sequential trace reader;
- profiling-specific PPU compatibility;
- smartlink-compatible native COFF metadata.

It does not include ARM64, other operating systems, annotations, online
aggregation, higher-level trace analysis, live UI
integration, compression, lossless blocking capture, or changes to the FPC
LLVM code-generation backend.

## 4. Architecture

```text
NexusFPC -profile
    -> instrument physical procedures
    -> emit associative procedure metadata
    -> link the profiling runtime into the executable

Instrumented process
    -> timestamp event
    -> acquire one record through TNXProfileWriter
    -> TNXProfileWriter delegates to TNXEventMemory
    -> fill and finalize the record through TNXProfileWriter
    -> rotate a full block to the completed queue

Background worker
    -> consume completed blocks
    -> stage events by originating thread
    -> write .nxp trace

TNXProfileReader
    -> validate and enumerate length-bounded trace records
```

The target process records evidence. It does not interpret that evidence.

## 5. Compiler Activation and PPU State

### 5.1 Command-line activation

Add `-profile` as a Nexus profiling option. Recognize it before loading any unit
or PPU. Use the existing dedicated state:

```text
cs_nexus_profile
```

The option applies to the current top-level compiler invocation, its dependency
compilations, and its automatic PPU rebuilds. Configuration-file processing
must accept the same option.

### 5.2 PPU compatibility

Retain:

```text
mf_nexus_profile
```

| Current build | Project PPU | Result |
|---|---|---|
| Profiled | Profiled | Reuse |
| Profiled | Ordinary | Rebuild from source |
| Ordinary | Profiled | Rebuild from source |
| Ordinary | Ordinary | Reuse |
| Profiled | Immutable release/system PPU | Reuse uninstrumented |

`ppudump` must identify the flag. There is no support-unit exemption because
activation no longer uses a unit.

## 6. Procedure Instrumentation

Instrument physical emitted procedures only:

```text
nxp_enter(descriptor)
...
nxp_leave(descriptor)
```

Normal Pascal `Exit` statements use the existing compiler exit convergence.
Inlining does not create a separate event when no physical call remains.

Exclude assembler, naked/nostackframe, interrupt, exception-filter, and profiler
support procedures. Immutable RTL, FCL, and package PPUs accepted under the
release/system policy remain uninstrumented.

Program bodies must place hooks around the physical body while the runtime is
active. Project unit initialization and finalization remain eligible.

The compiler owns the fixed hook ABI. Hook procdefs are no longer resolved from
a user-visible support unit.

## 7. Win64 Exception Unwind

Retain the validated physical-frame rule:

- a same-procedure handled exception does not close the physical frame;
- an abandoned physical frame emits one `UNWIND` event after the FPC language
  handler processes Pascal scopes and finalizers;
- collided and target unwind follow the proven Win64 semantics;
- normal leave and unwind are mutually exclusive for one invocation.

The handler records an event only. It does not aggregate or repair a runtime
call stack.

Provide the handler and registration glue through automatically linked profiling
support. No Pascal unit is added to the developer's uses clause.

## 8. Compiler-Emitted Metadata

### 8.1 Fixed procedure descriptors

Every instrumented physical procedure receives one fixed-size native descriptor
associated with its function COMDAT leader. It contains at least:

- magic and ABI version;
- flags;
- process-local runtime procedure ID slot;
- stable 64-bit identity;
- code start and end;
- source line and column;
- procedure name as `AnsiString`;
- unit name as `AnsiString`;
- source file as `AnsiString`.

No variable payload follows the descriptor. Every descriptor has one constant
stride. This removes variable-record walking and linker-padding dependence.

The runtime assigns the compact procedure ID at module registration. Hot-path
events use that ID.

### 8.2 String ownership

Compiler metadata exposes ordinary FPC `AnsiString` values. During registration,
the runtime creates runtime-owned `AnsiString` copies.

The file writer never dumps an `AnsiString` variable or its implementation
header.

### 8.3 COFF lifetime

```text
.text.<function>       COMDAT leader
    .pdata.<function>  associative
    .xdata.<function>  associative
    .nxprof.<function> associative
```

`/OPT:REF` must remove an unused function, its unwind records, and its descriptor
together. Metadata must not root unused code.

## 9. Statically Linked Runtime

### 9.1 Responsibilities

The compiler-linked runtime owns:

- process-global module and procedure IDs;
- runtime-owned metadata strings;
- QPC frequency and timestamp capture;
- FLS thread state;
- `TNXEventMemory` block allocation, rotation, completion, and reuse;
- one completed-block worker;
- per-thread output staging owned by the worker;
- trace creation and serialization;
- trace drain and shutdown.

It does not own aggregates, call trees, duration statistics, exception
interpretation, JSON generation, pause/reset generations, or analysis snapshots.

### 9.2 Hot path

An ordinary hook performs:

1. recursion-guard check;
2. FLS state lookup;
3. `TNXProfileWriter.AcquireRecord`;
4. fixed event fill using `QueryPerformanceCounter`;
5. `TNXProfileWriter.FinalizeRecord`.

Hooks perform no file I/O, writer locking, online aggregation, or call-tree
maintenance.

### 9.3 Buffering and overflow

`TNXEventMemory` owns one current writable block, completed and available
queues, and all block allocation and reuse. `AcquireRecord` atomically reserves
one record. `FinalizeRecord` marks that record finished after the hook has
populated it.

A block is sealed when its `Issued` count reaches capacity. It becomes complete
when sealed, `Finished = Issued`, and no acquisition is between selecting that
block and reserving its record. The sealed-to-completed state transition is one
atomic compare-exchange, so a stale publisher cannot enqueue a reset block.
The worker consumes complete blocks and returns them to the available queue.
Rotation reuses an available block or allocates another when none is available.
Queue locks occur only at block transitions.

The runtime does not repair event pairing. Orphaned `ENTER`, `LEAVE`, and
`UNWIND` events remain valid evidence for the consumer to interpret.

### 9.4 Thread lifecycle

- Allocate thread state lazily through FLS.
- Retain thread state until process shutdown so queued records keep a valid
  thread context.
- Record observed thread start and end.
- Keep every complete record readable even when a thread terminates abruptly.

### 9.5 Startup

A profiled executable starts the statically linked runtime from
compiler-generated executable startup before project unit initialization.
The writer exists at that point as the sole producer-facing facade over event
memory. Its file stream is attached during normal runtime unit initialization,
after stream support is available.

### 9.6 Shutdown

Normal profiled executable shutdown stops new recording, seals the partial
active block, wakes and joins the worker, flushes its per-thread output staging,
writes `TRACE_END`, and closes the file.

Abrupt termination may leave a truncated trace. Every complete record before
the truncated tail remains readable.

## 10. Binary Trace Format

### 10.1 General rules

- little-endian;
- `NXPF` magic;
- explicit format and ABI versions;
- explicit QPC frequency;
- kind, flags, and total byte length on every top-level record;
- unknown record kinds skipped using their byte length;
- incomplete final record ignored;
- no native Pascal managed type or compiler record dumped directly.

### 10.2 Strings

Metadata strings are null-terminated UTF-8 bytes within a length-bounded record.
Readers search for terminators only inside that record. The disk format has no
255-byte string limit.

### 10.3 Records

```text
FILE_HEADER
MODULE_DEFINE
MODULE_UNLOAD
PROCEDURE_DEFINE
THREAD_DEFINE
EVENT_BLOCK
TRACE_GAP
TRACE_END
```

`MODULE_DEFINE` contains module ID, build identity, image path, load address,
and flags. `PROCEDURE_DEFINE` maps a compact ID to module ID, stable ID, code
range, source position, name, unit, and source file.

### 10.4 Event blocks

Each block contains thread ID, per-thread sequence, event count, lost-event
count, first and last timestamps, and fixed events.

The common event is 16 bytes:

```text
kind          uint8
flags         uint8
reserved      uint16
procedure_id  uint32
timestamp     uint64
```

Initial kinds are `ENTER`, `LEAVE`, and `UNWIND`. Per-thread sequence and
timestamps define thread order. QPC timestamps permit later global merging.

## 11. Reader and Deferred Analysis

The initial `TNXProfileReader` must:

- validate headers and record bounds;
- accept a truncated final record;
- load module and procedure metadata;
- skip unknown length-bounded records.

Stack reconstruction, aggregation, reports, and JSON output are deferred until
the owner supplies the consumer design.

## 12. Cleanup of the Superseded Implementation

Remove:

- first-unit parsing from `compiler/pmodules.pas`;
- the `NexusProfiler` activation contract and support unit;
- hook-procdef lookup through that unit;
- its special PPU handling;
- online runtime stacks and aggregates;
- pause/start/reset generations;
- target-process JSON reporting;
- analysis snapshot and merge machinery;
- variable-length `.nxprof` descriptors;
- marker-contract tests and documentation.

Retain and adapt:

- `cs_nexus_profile` and `mf_nexus_profile`;
- PPU rebuild behavior and `ppudump` visibility;
- physical procedure eligibility and entry/leave insertion;
- native COFF COMDAT association;
- Win64 physical-frame unwind semantics;
- the general TLS callback correction in `rtl/win/systlsdir.inc`;
- applicable procedure, exception, thread, and smartlink tests.

Do not retain compatibility code solely for the superseded architecture.

## 13. Implementation Sequence

This is one continuous pass. These are dependency steps, not approval gates.

1. Replace first-unit activation with `-profile` processing.
2. Simplify PPU policy and remove the support-unit exemption.
3. Define the compiler-owned hook ABI and automatic support object.
4. Replace variable descriptors with fixed descriptors containing managed
   metadata fields and a runtime ID slot.
5. Preserve descriptor association with function COMDAT leaders.
6. Adapt entry, leave, program body, and unwind calls.
7. Replace aggregation with registration, metadata copying, FLS state, and
   `TNXEventMemory` event capture.
8. Implement the completed-block worker, executable startup, drain, and
   shutdown.
9. Implement the versioned binary writer.
10. Implement the minimal sequential reader.
11. Remove superseded unit, aggregation, snapshot, and runtime JSON code.
12. Adapt and complete the validation corpus.
13. Perform a clean make-based compiler and RTL bootstrap.
14. Run the complete corpus against the clean compiler.
15. Remove generated build/test artifacts.

At the first major semantic blocker not answered by this plan, pause and report
the exact scenario and evidence before expanding the design.

## 14. Validation

### 14.1 Compiler and PPU

- `-profile` takes effect before unit loading.
- Builds without it remain ordinary.
- Project PPUs rebuild across incompatible profile state.
- Immutable release/system PPUs remain usable uninstrumented.
- `ppudump` identifies profiling PPUs.

### 14.2 Object and linking

- Clang is the assembler and `lld-link` is the linker.
- Descriptors have one constant size and stride.
- Descriptor `AnsiString` values register correctly.
- Runtime-owned metadata copies remain valid for the trace lifetime.
- Descriptors remain associative COMDATs.
- `/OPT:REF` removes unused code, descriptors, `.pdata`, and `.xdata`.
- Ordinary builds contain no profiling sections or profiling runtime code.

### 14.3 Event correctness

Cover normal return, Pascal `Exit`, recursion, nested and anonymous routines,
constructors/destructors, unit initialization/finalization, program
bodies, inline behavior, excluded assembler procedures, same-frame catches,
one- and multi-frame propagation, rethrow, `try/finally`, nested exceptions,
access violations, safecall, ordinary unhandled
exceptions, FPC-created threads, and foreign-created threads.

### 14.4 Runtime and trace

- no online aggregation;
- sealed blocks publish only after every issued record is finalized;
- a block cannot publish while record acquisition against it is in flight;
- sealed-to-completed publication occurs exactly once across block reuse;
- completed blocks are consumed exactly once and returned for reuse;
- concurrent producers preserve every finalized event;
- the worker serializes per-thread output blocks correctly;
- orphaned records remain readable;
- per-thread block sequence is monotonic;
- metadata resolves regardless of record arrival order;
- normal executable shutdown drains and closes the trace;
- a truncated final record remains readable;

### 14.5 Reader

- skip unknown records;
- reject lengths exceeding file bounds;
- preserve complete records before a truncated tail.

### 14.6 Regression

- clean Windows x86-64 compiler and RTL build;
- debug build and GDB inspection;
- release/smartlinked build;
- TLS/threadvars;
- exception/unwind;
- normal nonprofiled build;
- no new bootstrap warning class.

### 14.7 Performance

Measure nonprofiled and profiled leaves, nested calls, recursion, high-frequency
calls, multithread recording, QPC, FLS lookup, record acquisition/finalization,
worker throughput, descriptor and executable size, unwind size, and final drain
time.

Do not optimize without a measured problem.

## 15. Completion Criteria

- `-profile` deterministically controls compilation.
- Incompatible project PPUs cannot be silently reused.
- Entry, leave, and unwind events match physical calls.
- Event capture uses reusable fixed-capacity blocks and one background writer.
- The runtime writes a versioned self-describing trace.
- Metadata remains usable for the complete trace.
- The reader handles complete and partial evidence.
- Smartlinking removes unused code and metadata.
- Ordinary builds contain no profiling residue.
- A clean make bootstrap and the complete corpus pass.

## 16. Settled Decisions

| Decision | Result |
|---|---|
| Activation | `-profile` before unit loading |
| Developer source changes | None |
| Runtime | Raw capture without online aggregation |
| Analysis | Deferred consumer design |
| Buffering | Reusable fixed-capacity `TNXEventMemory` blocks |
| Writer | One background worker consuming completed blocks |
| Producer access | Hooks acquire and finalize only through `TNXProfileWriter` |
| Block lifecycle | Available -> active -> sealed -> completed -> processing -> available |
| Orphaned events | Partial evidence interpreted by consumer |
| Metadata strings | Runtime-owned `AnsiString` values |
| Disk strings | Null-terminated UTF-8 in bounded records |
| Descriptors | Fixed-size associative COMDAT |
| Events | Fixed 16-byte records |
| Timing | Producer-side QPC |
| Ordering | Per-thread sequence and timestamps |
| Unwind | One event per abandoned physical frame |
| Runtime integration | Compiler-linked into the executable |
| Initial platform | Windows x86-64 |

## 17. Revision History

| Revision | Date | Summary |
|---|---|---|
| 1-5 | 2026-09-23 | Superseded first-unit and online-aggregation design |
| 6 | 2026-09-23 | Compiler-option activation, buffered binary tracing, runtime-owned `AnsiString` metadata, null-terminated disk strings, and offline analysis |
| 7 | 2026-09-23 | Static runtime, simple synchronous writer, and minimal reader; threading and higher-level analysis deferred |
| 8 | 2026-09-23 | `TNXEventMemory` issued/finished blocks, reusable queues, and one background trace writer |
| 9 | 2026-09-23 | Atomic acquisition lifetime, single state-transition publication, and writer-only producer access |
