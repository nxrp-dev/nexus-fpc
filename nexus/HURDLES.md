# Nexus module foundation: hurdles and open questions

This document records issues encountered while establishing the isolated
module architecture. No answer in the open section is assumed by the current
prototype.

## Resolved during this pass

### Conditional evaluation was embedded in tokenization

The tokenizer previously owned define and conditional state, discarded inactive
source, expanded selected includes, and could block on semantic `$IF`
expressions. It now emits structured directive tokens and tokenizes every
physical branch without consulting compile defines or semantic state.

`TNXConditionalProcessor` is a separate resumable phase. A semantic condition
can block that phase after the immutable physical stream has been published.
The effective stream remains private until conditional processing completes.

### The retained source tree contained two conditional-compatibility cases

A scan of 1,955 compiler, RTL, and FCL `.pas`, `.pp`, and `.inc` files found
three Delphi-style `#ERROR` lines hidden by inactive branches in
`packages/fcl-db/src/dbase/dbf_common.inc`. They now use explicit `$ERROR`
directives. The scan also found an open `{$IFDEF lstrings_unit}` at physical EOF
in `rtl/inc/lstrings.pp`; an explicit matching `$ENDIF` was added.

Punctuation and incomplete grammar fragments were not treated as problems.
They are ordinary physical tokens and remain valid under the new rule.

### The supplied tokenizer did not compile with FPC 3.2.2

`TNXBlockInfo` has record methods, which require the `advancedrecords` mode
switch. The switch was added to `nxPasTokenTypes.pas`.

The tokenizer's public `Continue` method also shadowed loop `Continue`
statements inside its own implementation. The implementation was separated
into `ContinueTokenizing`; its loop uses an explicit local continuation label,
while the public API remains `Continue`.

### Token records were not independently publishable

Tokens reference identifier and literal pools by numeric ID. Publishing only
the token array would leave those IDs without their values. Read-only pool
count accessors were added to `TNXTokenizer`, and `TNXPublishedTokenStream`
copies the token array and both pools as one immutable result.

### Partial work was concrete only for tokenization

`TNXModuleWorkspace` now owns a `TNXModulePhaseWorkspace` for every transition.
Each phase retains a cursor and an owned `TNXModulePhaseData` subclass while a
transition is blocked. Tests prove that partial implementation-phase progress
survives privately and is absent from the published snapshot until success.

### Checked arithmetic exposed intentional hash wraparound

The deterministic FNV-1a work-ID hash depends on unsigned 64-bit wraparound.
The runtime-check build initially raised an overflow exception at the multiply.
Overflow checking is now disabled only around the hash implementation and the
rest of the test build retains checked arithmetic.

### Heap tracing differs between the two available compilers

The FPC 3.2.2 test build links and runs with `heaptrc`, reporting zero leaked
blocks. The bootstrapped compiler currently fails to link `heaptrc` because its
LLD path does not provide `__data_start__` and `__bss_end__`. The same checked
test suite builds and passes with the bootstrapped compiler when `-gh` is
omitted. This appears to be a toolchain/linker issue rather than a module-model
failure, but it should remain visible when memory diagnostics move to that
toolchain.

## Open architectural questions

### Pre-integration blocker: embedded assembler and non-Pascal includes

The compatibility scanner still reports AArch64 assembler lines using `!` and
two makefile fragments stored with `.inc` extensions. Treating `!` as an
ordinary Pascal token would also make malformed text such as `STOP!` lexically
valid, contrary to the accepted rule. The production tokenizer therefore needs
an explicit physical-source or lexical-context contract for assembler regions
and non-Pascal includes rather than silently accepting every byte everywhere.

An unrelated FCL example, `packages/fcl-base/examples/promisesimple.pp`, also
contains an unterminated opening comment. It was recorded but not changed as
part of the conditional-compilation implementation.

### 1. Exact working data for each compiler phase

The current phase workspace supplies ownership and lifetime boundaries, but the
real parser, resolver, code-generation and finalization checkpoint types are
unknown. Integration should identify the minimum resumable state for each
phase rather than moving the current `TModule` object graph wholesale.

### 2. Source identity catalog

Published tokens retain `SourceID`, offset, line and column, but the tokenizer
does not yet publish the mapping from source IDs to main/include file names.
Diagnostics and source navigation will require an immutable source catalog in
the published token stream.

NXLR-0001 also moves include loading out of the tokenizer. The conditional or
precompile layer must eventually request the included physical source, obtain
or build its independently cacheable physical token stream, and splice its
selected effective tokens without losing source identity. Active include
directives are currently retained in the prototype effective stream as the
explicit handoff point; include expansion itself is not yet implemented.

### 3. Synchronization policy

`TNXWorkItem` exposes read/write hooks around published data, but those hooks,
`TNXStateMap`, and `TNXAssignment` are not synchronized. Before multiple worker
threads are introduced, ownership and lock ordering must cover snapshot reads,
state transitions, dependency registration and queue operations together.

### 4. Snapshot cost and sharing

The prototype deep-clones published module state before every transition. That
is safe and easy to verify, but compiler symbol tables and generated data may
make full cloning too expensive. Immutable subgraphs, reference counting or
copy-on-write structures may be needed while retaining the same publication
contract.

### 5. Cyclic unit dependencies

The scheduler prioritizes work that blocks other work but does not identify or
resolve strongly connected components. The existing compiler has deliberate
cycle and SCC behavior. That behavior must be specified against these finer
state barriers before cyclic units can migrate.

### 6. Failure, cancellation and retry

The model distinguishes completed and blocked transitions. It does not yet
model fatal errors, cancellation, invalidation, source changes, retry, or a
transition that voluntarily yields without a dependency.

### 7. PPU loading and recompilation

The current lifecycle covers source compilation only. Loading a PPU,
discarding it, recompiling from source, CRC mismatch recovery and dependent-unit
reload are alternate work paths that still need a composition model.

### 8. Global compiler state

The existing compiler relies on globals such as the current module, scanner,
assembler data, symbol tables and options. A worker-safe module cannot merely
point those globals at its private workspace. The retained globals must be
classified as immutable configuration, worker context, module working state or
published state.

### 9. Module identity rules

The prototype requires an explicit stable identity and separately stores the
Pascal module name and source name. Canonicalization rules for namespaces,
packages, programs, aliases and case sensitivity have not been chosen.

### 10. Dependency milestone mapping

The dependency helpers follow the current `nxworkgraph` reference mapping to
`ctask`/`pmodules` barriers. Each mapping must be checked against the live
compiler path before integration; the prototype does not claim semantic parity
yet.

### 11. Lifetime and graph removal

`TNXStateMap` currently retains state and blocker records until the entire map
is destroyed. A long-lived or incremental compiler will need explicit work
retirement and safe removal of dependency edges.

### 12. Generic work graph versus compiler example

`nxworkgraph.pas` currently contains both the generic scheduler and its earlier
`TNXCompileUnit` example. `TNXModule` reuses the example's `TNXCompileState` but
otherwise supersedes that example. Before this becomes production code, the
generic graph, shared compiler-state declarations and obsolete example should
be separated so there is only one concrete module model.

