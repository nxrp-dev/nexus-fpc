# Nexus module foundation

This directory is an isolated prototype for a future NexusFPC module model. It
does not replace or modify the compiler's existing `TModule` path.

## Purpose

The prototype separates four kinds of state that are currently easy to mix:

1. Stable module definition: identity, name, source and module kind.
2. Shared scheduling state: the current committed milestone and dependencies.
3. Private working state: mutable, partially complete work retained across a
   blocked transition.
4. Published state: a cloned snapshot replaced only after a transition
   completes successfully.

This means a tokenizer, parser, resolver or code generator can stop on a
dependency without exposing its partial result and without restarting its
completed work when it resumes.

## Files

- `nxworkgraph.pas`: generic linear work-state and dependency scheduler, plus
  the original compiler-oriented reference model.
- `nxmodule.pas`: the new `TNXModule` foundation built on the work graph.
- `nxmodule_tests.pas`: executable behavioral tests.
- `nxlexical_compat_scan.pas`: physical-token compatibility scanner.
- `nexus_pascal_tokenizer/`: clean-room resumable Pascal tokenizer prototype.
- `CONDITIONAL-COMPILATION-COMPATIBILITY.md`: NXLR-0001 corpus findings.
- `HURDLES.md`: resolved hurdles, deferred questions and integration risks.
- `Run-NXModuleTests.ps1`: repeatable FPC 3.2.2 test build.
- `Run-NXLexicalCompatibilityScan.ps1`: repeatable compiler/RTL/FCL scan.

All classes introduced by this prototype use the `TNX` prefix.

## Module lifecycle

`TNXModule` currently follows the source-compilation states already modeled by
`TNXCompileState`:

```text
NotStarted
  -> Tokenizing
  -> Tokenized
  -> Compile
  -> CompilingWait
  -> CompilingWaitIntf
  -> CompilingWaitImpl
  -> CompilingWaitFinish
  -> CompiledWaitCRC
  -> Compiled
  -> Processed
```

The tokenizer transition performs real, configuration-independent physical
tokenization. The following transition performs real conditional selection and
publishes a separate effective token stream. Later compiler phases are
deliberately skeletal: each has a durable
`TNXModulePhaseWorkspace`, but does not yet parse, resolve, generate code or
write a PPU.

The physical token stream includes structured conditional-directive tokens and
tokens from every branch. It can be published while symbol-dependent
conditional processing is blocked. Only the effective stream reflects compiler
defines or semantic conditional results.

## Publication contract

Before running a transition, `TNXWorkItem` clones the last published snapshot.
The transition mutates only `TNXModuleWorkspace` and its phase workspace. On
success, `TNXModule.Commit` updates and publishes the clone while advancing the
state. On block or exception, the clone is discarded and the previous snapshot
remains visible.

The working phase retains:

- whether work has begun;
- whether it has completed;
- a general progress cursor;
- an owned `TNXModulePhaseData` object for phase-specific resumable data.

The tests demonstrate this behavior for both tokenization and an arbitrary
implementation phase.

## Running tests

From the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\nexus\Run-NXModuleTests.ps1
```

The script builds outside the repository by default and enables heap tracing.

