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
| [NXLR-0002](#nxlr-0002-compiler-wide-default-text-types) | Compiler-wide default text types | Accepted |
| [NXLR-0003](#nxlr-0003-removal-of-the-g-switch) | Removal of the `$G` switch | Implemented |
| [NXLR-0004](#nxlr-0004-removal-of-floating-point-emulation-directives) | Removal of floating-point emulation directives | Implemented |
| [NXLR-0005](#nxlr-0005-removal-of-kylix-and-turbo-pascal-compatibility-options) | Removal of Kylix and Turbo Pascal compatibility options | Implemented |
| [NXLR-0006](#nxlr-0006-removal-of-nearfar-procedure-directives) | Removal of near/far procedure directives | Implemented |
| [NXLR-0007](#nxlr-0007-removal-of-n-and-a5-legacy-options) | Removal of `$N` and `-a5` legacy options | Implemented |

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

## NXLR-0002: Compiler-Wide Default Text Types

- Status: Accepted
- Decision date: 2026-10-01
- Implemented in: Compiler mode, PPU and System.Char checks, and mode-driven RTL text declarations; full Unicode package parity and automatic RTL selection remain in progress
- Released in: Not released
- Applies to: All NexusFPC compiler modes and targets
- Supersedes: Upstream `$H` selection of the unqualified `String` type

### Rule

One compiler-invocation choice controls the default text types throughout the
source being compiled. The default is ANSI: unqualified `String`, `Char`, and
`PChar` mean `AnsiString`, `AnsiChar`, and `PAnsiChar`. `-MUNICODESTRINGS`
selects `UnicodeString`, `WideChar`, and `PWideChar` instead.
`-MANSISTRINGS` explicitly selects the ANSI default.

Source-level mode directives cannot change this choice for an individual unit
or include file. `$H+` and `$H-` are accepted but have no effect. The `-Sh`
command-line switch is likewise accepted but has no effect. The effective
long-string state is always on, so `$IFOPT H+` is true and `$IFOPT H-` is false.
Conflicting source-level requests to select a different default text family
are errors rather than silent overrides.

`ShortString` and `String[n]` remain explicit fixed-length string types.
`AnsiString`, `UnicodeString`, `AnsiChar`, `WideChar`, `PAnsiChar`, and
`PWideChar` also retain their explicit meanings regardless of the default.
The choice does not specify an `AnsiString` code page or change the encoding
required by an operating-system or JNI interface.

### Upstream Free Pascal Behavior

In upstream Free Pascal, `$H-` makes unqualified `String` a `ShortString`,
while `$H+` makes it a long string. Language modes and source directives can
change that setting within a compilation. The comparison baseline for this
rule is Free Pascal 3.2.2, the NexusFPC bootstrap compiler.

### Rationale

An unqualified type name should have one predictable meaning for a compiler
invocation. A source-local switch that changes its representation makes unit
interfaces and build artifacts harder to reason about. Explicit short-string
types preserve the fixed-length capability without an ambient type switch.
The ANSI/Unicode default is an invocation-level policy, not a property of an
individual unit.

### Examples

With the default ANSI choice, `var S: String;` declares an `AnsiString`.
With the compiler-wide Unicode choice, the same source declares a
`UnicodeString`. In either choice, `var S: String[40];` declares a fixed-length
short string and `var S: ShortString;` remains explicit.

`{$H-}` no longer changes any of those declarations. Code that needs a short
string must name `ShortString` or use `String[n]`.

### Compatibility Impact

Source relying on `$H-` to make bare `String` short will now compile that name
as the compiler-wide long-string default. This can change layout, calling
conventions, overload selection, and behavior; such declarations require an
explicit short-string type. Source containing `$H` itself remains accepted so
legacy directives do not force a mass source migration.

Precompiled declarations retain the concrete types recorded in their PPUs. The
compiler-wide choice does not reinterpret their public signatures. Every PPU,
including a released RTL or package PPU, records its default text choice and
must match the current compiler invocation. A PPU built under the other choice
is rejected rather than treated as an interchangeable cached artifact.

### Diagnostics

`$H` and `-Sh` are silent compatibility no-ops. A source directive that
attempts to select an ANSI/Unicode default contrary to the compiler-wide
choice must produce a hard error.

### Implementation

The implementation must keep the invocation choice separate from mutable
per-module mode settings and leave explicit ANSI and Unicode APIs available.
The FPC 3.2.2 seed compiler may still apply its historical `$H` semantics
while building the first NexusFPC compiler; that bootstrap behavior is not a
NexusFPC language rule.

`FPC_UNICODESTRINGS` is owned by the compiler invocation. Source directives
and config-file defines, as well as `-d`/`-u`, cannot redefine it. The old
`UNICODERTL` and `FPC_UNICODE_RTL` defines do not select the default RTL text
types; the compiler's choice does. `-MUNICODESTRINGS` does not set the separate
Windows API `UNICODE`/`FPC_OS_UNICODE` aliases; those are not default Pascal
text types.
The compiler also checks the actual width of `System.Char`, so a misleading
PPU mode flag cannot make an incompatible System unit appear valid.

A build uses one mode-matched set of RTL and package PPUs. Switching modes
requires rebuilding those artifacts; maintaining simultaneous ANSI and Unicode
installations is not a product requirement. The compiler rejects a mismatched
PPU even when it is marked as released. The ANSI RTL is the current canonical
build. A Win64 Unicode RTL can be built with `-MUNICODESTRINGS` alone, but full
Unicode package parity and automatic selection of the matching unit directory
are not yet established. Until then, a Unicode build must explicitly supply
its matching unit search path.

### Tests

Tests must cover both choices using one compiler and separate matched RTLs,
explicit short strings, inert `$H` and `-Sh`, `$IFOPT H`, conflicting source
directives, qualified and unqualified default text names, and rejection of
both crossed client/RTL PPU combinations. They must also cover the public RTL
text aliases, legacy Unicode defines not changing the mode, and attempted
redefinition of `FPC_UNICODESTRINGS` through source, options, and config files.

### Decision History

- 2026-10-01: Accepted compiler-wide ANSI default with an explicit Unicode or
  ANSI compiler choice and no per-unit text-model override.
- 2026-10-01: Chose silent `$H` compatibility no-ops instead of rejecting
  existing `$H` directives.
- 2026-10-01: Bootstrapped the compiler, verified project-PPU mode switching,
  and built native Android and i386 Linux RTLs under the shared-RTL contract.
- 2026-10-01: Superseded shared-RTL PPU reuse with strict mode matching for
  all PPUs. An isolated Win64 Unicode RTL build succeeded, but Unicode RTL
  parity and automatic selection remain incomplete.
- 2026-10-02: Made the compiler-owned mode authoritative for RTL text
  declarations and converted the remaining live `SizeOf(Char)` preprocessor
  selectors in RTL and packages. An ANSI bootstrap and isolated Win64 Unicode
  RTL build passed; full Unicode package parity remains future work.

## NXLR-0003: Removal of the `$G` Switch

- Status: Implemented
- Decision date: 2026-10-03
- Implemented in: Compiler switch handling and removal of the imported-data local switch
- Released in: Not released
- Applies to: All NexusFPC compiler modes and targets
- Supersedes: Upstream `$G+` and `$G-` compatibility directives

### Rule

An active `{$G+}` or `{$G-}` is an illegal compiler directive. A processed
conditional query of their state, `{$IFOPT G+}` or `{$IFOPT G-}`, is also
illegal. There is no `$G`
state or target-specific exception. MacPas mode's corresponding
`{$IFC OPTION(G)}` query is illegal as well.

### Upstream Free Pascal Behavior

The [Free Pascal 3.2.2 user documentation](https://docs.freepascal.org/docs-html/user/userap6.html)
describes `$G` as an ignored switch for generating 80286 code. Before this
change, NexusFPC's switch table instead mapped it to a local imported-data
flag. All its code-generation consumers
were gated on target package support, which no retained NexusFPC target
enables. The flag was nevertheless observable through `$IFOPT`.

### Rationale

An obsolete switch with no code-generation effect on the supported target
matrix should not remain as an unexplained, mutable frontend state.

### Examples

`{$G+}`, `{$G-}`, `{$IFOPT G+}`, and `{$IFOPT G-}` each produce a compiler
error where their enclosing directive syntax is supported. In MacPas mode,
`{$IFC OPTION(G)}` produces an error.

### Compatibility Impact

Source that processes these directives is rejected. Remove `$G+` and `$G-`;
they do not select a useful feature on supported targets. Remove `$IFOPT G`
and MacPas `OPTION(G)` queries or replace them with a condition describing the actual intended
target or feature. No compatibility mode or silent-ignore behavior is provided.

### Diagnostics

Direct `$G` forms and conditional queries in their respective supported
directive syntaxes report an illegal compiler directive error.

### Implementation

`compiler/switches.pas` rejects direct and `$IFOPT` forms. The
`cs_imported_data` local switch and its checks were removed from the compiler.
The next live local switch keeps its previous ordinal so PPU-serialized node
switches retain their bit positions.
The remaining imported-symbol code is separate package-support machinery;
it does not implement `$G` and is still gated off for retained targets.

### Tests

`tests/switches` contains negative fixtures for both direct states and both
`$IFOPT` states. The bootstrap runner checks direct forms in FPC, ObjFPC, and
MacPas modes, `$IFOPT` forms in FPC and ObjFPC modes, and MacPas's
`OPTION(G)` form. MacPas does not accept `$IFOPT` independently of this rule.
Each checked form must produce an illegal-directive error. The normal bootstrap also confirms retained source
compiles without `$G`.

### Decision History

- 2026-10-03: Accepted and implemented removal of `$G` and its imported-data
  switch state for all supported targets.

## NXLR-0004: Removal of Floating-Point Emulation Directives

- Status: Implemented
- Decision date: 2026-10-03
- Implemented in: Compiler directive handling and removal of the `cs_fp_emulation` code paths
- Released in: Not released
- Applies to: All NexusFPC compiler modes and targets
- Supersedes: Upstream `$E+`, `$E-`, and `FLOATINGPOINTEMULATION`

### Rule

`{$E+}` and `{$E-}` are handled as unknown directives, like
`{$NONSENSEHDKJHKS}`. `{$IFOPT E+}` and `{$IFOPT E-}` query an unknown switch
and therefore select no branch, as with an unknown `IFOPT` name.
`{$FLOATINGPOINTEMULATION ...}` is likewise an unknown directive. There is
no floating-point emulation switch state. The separate `-Cf` FPU selection,
including soft-FPU configurations, is not changed by this rule.

### Upstream Free Pascal Behavior

Free Pascal recognizes `$E` as a floating-point coprocessor emulation switch.
The retained NexusFPC targets did not enable the `cpufpemu` compiler feature;
the switch produced an unsupported-target warning and could not activate its
code paths.

### Rationale

The switch refers to a legacy emulation mechanism that is not available on the
retained target matrix. Keeping its syntax and dormant branches would imply a
supported capability that does not exist.

### Compatibility Impact

Source containing an active `$E` directive or processed `$IFOPT E` query no
longer has a floating-point emulation state to control or inspect. Such source
should remove the directive or use a condition for the actual FPU configuration.
Code using `-Cf` to select an FPU type is unaffected.

### Implementation and Tests

The compiler handles direct `$E` forms through its unknown-directive warning
and `$IFOPT E` through its unknown-switch behavior. It no longer registers
`FLOATINGPOINTEMULATION`. The `cs_fp_emulation` state and its
code-generation alternatives were removed. The following module-switch ordinal
is fixed so existing PPU-serialized switch positions do not shift.

`tests/switches` checks that direct `$E` forms and an arbitrary unknown
directive compile under the scanner's normal unknown-directive behavior. It
also checks that `$IFOPT E` and an arbitrary unknown switch do not select their
branches, and that the former long-form directive compiles as unknown. The
bootstrap runner executes these tests after building the compiler.

### Decision History

- 2026-10-03: Accepted and implemented removal of the legacy emulation switch.

## NXLR-0005: Removal of Kylix and Turbo Pascal compatibility options

- Status: Implemented
- Decision date: 2026-10-03
- Implemented in: Current worktree
- Released in: Not released
- Applies to: All NexusFPC targets and compiler modes
- Supersedes: None

### Rule

NexusFPC does not support `-Sk`, `-Mtp`, `-So`, or `-Ss`, or the
`{$MODE TP}` source directive. The command-line options are rejected as unknown
options. `{$MODE TP}` follows the ordinary unknown-mode path: it emits an
illegal-switch warning and leaves the current mode unchanged. No Kylix compatibility unit is automatically
loaded, and object constructors and destructors have no special `Init`/`Done`
name restriction.

### Rationale

The Kylix unit and Turbo Pascal 7 compatibility mode are outside the supported
NexusFPC language and target contract. Removing their dedicated compiler state
also removes otherwise unreachable parsing and code-generation branches.

### Compatibility Impact

Source and build commands requesting these compatibility modes must select a
retained language mode and update any syntax that depended on the old mode.
Code that used `-Ss` solely to enforce method names must enforce that convention
outside the compiler.

### Implementation and Tests

The options, TP mode state and TP-only branches were removed from the compiler.
The `fpcylix` unit and its RTL build registration were removed. The bootstrap
runner tests rejection of all four options and the unknown-mode warning for
`{$MODE TP}`, plus compilation of arbitrarily named constructors and
destructors. TP-mode-specific legacy test fixtures were removed because changing
their mode would invalidate the behavior they originally tested.

### Decision History

- 2026-10-03: Removed at the project owner's direction.

## NXLR-0006: Removal of near/far procedure directives

- Status: Implemented
- Decision date: 2026-10-03
- Implemented in: Current worktree
- Released in: Not released
- Applies to: All NexusFPC compiler modes and retained targets
- Supersedes: Upstream `$F`, `FARCALLS`, and ignored Pascal procedure `far`/`near` directives

### Rule

`{$F+}`, `{$F-}`, and `{$FARCALLS ...}` follow the ordinary unknown-directive
path. Pascal `far` and `near` procedure and procedure-variable directives are
not accepted. The formerly ignored `far` pointer modifier on x86-64 and
non-x86 targets is not accepted.

This rule does not remove the distinct i386 pointer modifiers: `far` selects
an FS-segment pointer there, and `near` can explicitly select a segment
register on x86. It also does not remove `far`/`near` operand qualifiers from
x86 inline assembly, where they describe control-transfer instruction forms.
Windows API identifiers such as `FARPROC` are unaffected.

### Upstream Free Pascal Behavior

Free Pascal recognizes `$F` and `FARCALLS` for legacy compatibility but
ignores their call-distance effect on 32- and 64-bit targets. It accepts
Pascal `far` and `near` procedure directives while warning that they are
ignored. Some pointer and inline-assembly uses have separate target-specific
meanings and are not covered by that no-op behavior.

### Rationale

The retained targets have no segmented-memory procedure call model. Accepting
ignored call-distance directives implies a capability they do not provide.
Target-specific pointer and instruction syntax with real semantics remains
available.

### Examples

`procedure P; far;` and `procedure P; near;` are rejected. `{$F+}` and
`{$F-}` receive the same unknown-directive warning as an arbitrary unregistered
directive. On i386, `type PFS = ^Byte; far;` remains meaningful and accepted.

### Compatibility Impact

Existing source using the ignored procedure directives must remove them.
Source using the ignored x86-64 or non-x86 `far` pointer modifier must remove
that modifier. i386 segment-qualified pointer declarations, x86 assembly
operand qualifiers, and Windows API names are unchanged.

### Implementation and Tests

The scanner no longer registers `$F` or `FARCALLS`; the procedure-directive
table no longer accepts `far` or `near`; their no-op handlers and unreachable
procedure-option branches were removed. The x86-64/non-x86 no-op `far`
pointer paths were removed. Obsolete modifiers were removed from retained
source. The bootstrap runner checks unknown-directive behavior and rejection
of the removed Pascal syntax on Win64.

### Decision History

- 2026-10-03: Removed no-op near/far call syntax at the project owner's direction; retained behavior-bearing pointer and assembly uses.

## NXLR-0007: Removal of `$N` and `-a5` legacy options

- Status: Implemented
- Decision date: 2026-10-03
- Implemented in: Current worktree
- Released in: Not released
- Applies to: All NexusFPC compiler modes and retained targets
- Supersedes: Upstream `$N` numeric-coprocessor compatibility switch and `-a5` old-binutils workaround

### Rule

`{$N+}` and `{$N-}` follow the ordinary unknown-directive path. The `-a5`
command-line option and its boolean-off form are rejected as unknown options.
The compiler automatically requests Big Obj COFF output when a Windows target
has enough sections to require it; that decision is no longer user-overridable
to support pre-2.25 GNU binutils.

### Upstream Free Pascal Behavior

Free Pascal recognizes `$N` as a Turbo Pascal numeric-processing compatibility
switch. In this source tree it had no working numeric backend effect and
reported an unsupported-switch warning. On Windows, `-a5` could suppress
Big Obj COFF output for old GNU binutils.

### Rationale

The retained targets do not use the Turbo Pascal coprocessor model, and the
project does not support the obsolete GNU binutils compatibility mode.
Big Obj COFF itself remains necessary for large Windows object files.

### Compatibility Impact

Source containing `$N` receives an unknown-directive warning and should
remove it. Commands containing `-a5` must remove that option. If a Windows
object requires Big Obj COFF, the assembler must support it.

### Implementation and Tests

The switch tables no longer recognize `$N`; the six inactive `$N+` lines in
pasjpeg were removed. The `-a5` parser, option-help entry, and its conditional
Big Obj suppression path were removed. The bootstrap runner checks both `$N`
forms and both `-a5` forms.

### Decision History

- 2026-10-03: Removed both legacy options at the project owner's direction.

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

