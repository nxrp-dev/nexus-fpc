# NexusFPC Language Rule Changes

## Purpose

This document is the authoritative record of deliberate changes that NexusFPC makes to the Pascal language rules inherited from upstream Free Pascal.

It exists so that a language decision cannot become an undocumented compiler behavior. Each change must state what upstream Free Pascal does, what NexusFPC does differently, why the difference is intentional, and how users and tools are affected.

Ordinary bug fixes that restore established Free Pascal behavior do not belong here. Neither do optimizer changes, internal compiler refactors, target removals, library changes, or diagnostics that do not alter whether a program is accepted or what that program means.

## Principles

- Language changes must be deliberate, narrow, and testable.
- Compatibility with upstream Free Pascal remains the default.
- A proposal is not a language rule until it has been accepted.
- An accepted rule is not implemented merely because it appears in this document.
- Every implemented rule must have tests that demonstrate both the intended behavior and its boundary cases.
- Compatibility consequences must be recorded explicitly, including whether upstream-valid source is rejected or given different meaning.
- Where a rule depends on a compiler mode, modeswitch, target, or language version, that scope must be stated precisely.
- Reversals and superseding decisions remain in the history; they are not erased.

## Status Definitions

| Status | Meaning |
|---|---|
| Proposed | Under consideration. It does not define NexusFPC behavior. |
| Accepted | The language rule has been approved, but implementation is not asserted. |
| Implemented | Compiler behavior and tests implement the accepted rule. |
| Released | The implemented rule has shipped in a named NexusFPC release. |
| Rejected | The proposal was considered and deliberately declined. |
| Superseded | A later recorded decision replaces this rule. |

## Change Index

| ID | Title | Status |
|---|---|---|
| [NXLR-0001](#nxlr-0001-complete-tokenization-of-conditionally-compiled-source) | Complete tokenization of conditionally compiled source | Accepted |

## NXLR-0001: Complete Tokenization of Conditionally Compiled Source

- Status: Accepted
- Decision date: 2026-09-29
- Implemented in: Isolated `nexus` frontend prototype; production compiler integration remains outstanding
- Released in: Not released
- Applies to: All NexusFPC compiler modes and targets
- Supersedes: None

### Rule

The tokenizer must tokenize the complete physical source file, including every branch of conditional compilation. It must not evaluate conditional expressions, select active branches, or discard tokens belonging to inactive branches.

Conditional directives, including `{$IFDEF}`, `{$IFNDEF}`, `{$IF}`, `{$ELSE}`, `{$ELSEIF}`, and `{$ENDIF}`, are tokens in the physical token stream.

Conditional evaluation is a separate phase. It consumes the completed physical token stream and produces the effective token stream that is presented to the parser.

Consequently, every conditional branch must be lexically tokenizable whether or not that branch is active for the current compilation.

An inactive branch is not required to be:

- syntactically valid after conditional processing;
- semantically valid;
- resolvable;
- type-correct;
- valid for the current target; or
- compilable if selected.

Lexical validity is the only requirement imposed on source solely because it occurs in an inactive conditional branch.

The frontend phase boundary is:

```text
Physical source
    -> tokenizer
    -> physical token stream
    -> conditional/precompile processor
    -> effective token stream
    -> parser
    -> binding, resolution, and semantic analysis
```

### Upstream Free Pascal Behavior

Historical Free Pascal behavior permits conditional state to affect source consumption during tokenization. Source in an inactive branch can therefore be discarded without being completely tokenized.

NexusFPC intentionally does not preserve that behavior. The precise upstream comparison version and conformance examples must be captured with the implementation tests.

### Rationale

Separating physical tokenization from conditional evaluation simplifies the frontend architecture and allows complete physical token streams to be produced independently of conditional state. This separation also improves the ability to schedule frontend work concurrently: tokenization does not need to wait for the state used to select conditional branches.

The physical token stream remains a complete lexical representation of the physical source. Conditional selection is explicit and belongs to the later conditional/precompile phase.

### Examples

Conditional source may insert or remove a grammatical fragment without making
that fragment an independently parseable construct:

```pascal
Foo(
  A
{$IFDEF WITH_B}
  , B
{$ENDIF}
);
```

The physical stream contains the conditional directive tokens and the comma and
identifier tokens. Conditional processing either retains or removes `, B`, and
the parser receives the resulting effective stream.

Likewise, the following source is lexically valid even though selecting the
conditional branch produces invalid syntax because there is no comma before
`B`:

```pascal
Foo(
  A
{$IFDEF BROKEN_CONFIGURATION}
  B
{$ENDIF}
);
```

The tokenizer accepts it. If `BROKEN_CONFIGURATION` is defined, the parser
rejects the selected effective stream.

An inactive branch containing an unterminated string literal is not lexically tokenizable and violates this rule:

```pascal
{$IFDEF X}
  S := 'unterminated
{$ENDIF}
```

Malformed source text cannot be used as an implicit configuration failure. Use
an explicit selected directive such as
`{$ERROR 'This configuration is unsupported'}` instead.

### Compatibility Impact

This is intentionally stricter than historical Free Pascal behavior. Source that was previously accepted because lexically invalid text occurred only in an inactive conditional branch will be rejected by NexusFPC.

The initial compatibility scan found three such cases in
`packages/fcl-db/src/dbase/dbf_common.inc`: inactive Delphi-style `#ERROR`
lines. They were replaced with explicit `$ERROR` directives. It also found an
RTL include ending with an open conditional, which was given an explicit
matching `$ENDIF`.

The rule does not require inactive code to parse, resolve, type-check, or support the current compilation target. It changes only the lexical requirement and the phase at which conditional branches are selected.

No opt-out or compatibility mode is defined by this decision.

### Diagnostics

Lexical errors must be reported even when they occur in a branch that the conditional/precompile phase would later remove. Exact diagnostic wording and source-position requirements remain to be specified during implementation.

### Implementation

The isolated `nexus` frontend prototype implements the phase boundary in
`nxPasTokenizer.pas`, `nxPasDirectives.pas`, and `nxPasConditionals.pas`.
`TNXModule` publishes separate physical and effective token streams, and a
symbol-dependent condition blocks only the conditional-processing phase.

This record remains `Accepted`, rather than `Implemented`, until the production
NexusFPC scanner path uses the new pipeline.

### Tests

Implementation tests must demonstrate at least:

- conditional directives are retained as physical tokens;
- tokens from active and inactive branches are retained in physical source order;
- tokenization is independent of which symbols are defined;
- conditional processing produces the expected effective token stream;
- lexically valid but syntactically invalid inactive branches are accepted;
- lexically invalid inactive branches produce lexical errors;
- selecting a syntactically invalid branch produces a parser error rather than a tokenizer error; and
- nested conditionals and `ELSEIF` preserve the same phase separation.

The isolated prototype tests cover these requirements except for an actual
parser diagnostic, because the prototype parser phase remains skeletal. They do
prove that a selected syntactically invalid token sequence passes tokenization
and conditional processing unchanged for the future parser to reject.

### Decision History

- 2026-09-29: Accepted as the first deliberate NexusFPC language-rule change to simplify frontend architecture and improve concurrency.
- 2026-09-29: Implemented and tested in the isolated frontend prototype; production scanner integration remains pending.

## Change Record Format

Copy this section for each proposed change. Assign identifiers sequentially in the form `NXLR-0001`.

```markdown
## NXLR-0001: Short descriptive title

- Status: Proposed
- Decision date: Not decided
- Implemented in: Not implemented
- Released in: Not released
- Applies to: Exact compiler modes, modeswitches, targets, or language versions
- Supersedes: None

### Rule

State the NexusFPC language rule precisely and independently of its implementation.

### Upstream Free Pascal Behavior

Describe the corresponding upstream rule and identify the upstream version used for comparison.

### Rationale

Explain why NexusFPC is intentionally adopting a different rule.

### Examples

Show source that establishes the rule, including important accepted and rejected cases.

### Compatibility Impact

State whether the change rejects previously valid source, accepts previously invalid source, or changes the meaning of valid source. Describe migration or opt-in/opt-out behavior, if any.

### Diagnostics

Record required error, warning, or note behavior, including when it must be emitted.

### Implementation

List the compiler locations and commits that implement the rule. Do not treat this section as the definition of the rule.

### Tests

List conformance and regression tests, including boundary and compatibility cases.

### Decision History

- YYYY-MM-DD: Proposed. Brief reason and decision owner.
```

