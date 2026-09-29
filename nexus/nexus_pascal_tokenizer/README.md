# Nexus Pascal Tokenizer Prototype

This is a clean-room frontend prototype based on the lexical behavior observed in the supplied NexusFPC/FPC snapshot and on the architecture discussed for NexusFPC.

## Core rules implemented

- Tokenization produces a durable physical token buffer only when complete.
- The complete physical source is tokenized, including every conditional branch.
- Compiler directives are emitted as structured physical tokens with source locations and original directive text.
- Tokenization performs no conditional evaluation, branch elimination, define mutation, include expansion or semantic lookup.
- `TNXConditionalProcessor` consumes completed physical tokens and produces the effective token stream.
- Semantic `$IF` expressions can block conditional processing without blocking or invalidating physical tokenization.
- Operators and keywords do not retain redundant source strings.
- Identifiers are interned in a string pool.
- Literal and directive values are stored in separate pools.
- `<` and `>` are always lexical operator facts; parser context does not alter their token identity.
- Known FPC words retain a keyword-candidate ID even when emitted as identifiers.
- A keyword policy decides whether a known word is active as a keyword.

## Units

- `nxPasTokenTypes.pas` - token records, token kinds, directive kinds, pools and blocker information.
- `nxPasKeywords.pas` - known FPC words plus keyword lookup and policy.
- `nxPasSources.pas` - physical source abstraction.
- `nxPasDirectives.pas` - directive classification, conditional state and semantic-resolver boundary.
- `nxPasConditionals.pas` - conditional selection from physical tokens to effective tokens.
- `nxPasTokenizer.pas` - physical tokenizer.
- `tokenizer_demo.pas` - minimal physical-token example.

## Frontend boundary

```text
physical source
  -> tokenizer
  -> physical tokens
  -> conditional/precompile processor
  -> effective tokens
  -> parser
  -> binding, resolution and semantic analysis
```

Every conditional branch must be lexically tokenizable. Inactive branches do not need to parse, resolve, type-check or support the current target.

## Implemented lexical forms

The prototype currently recognizes:

- identifiers, including `&escaped` identifiers;
- FPC keyword candidates;
- decimal integers;
- `$` hexadecimal integers;
- `%` binary integers;
- `&` octal integers;
- decimal real literals with exponent;
- Pascal quoted strings with doubled apostrophes;
- `#nn`, `#$nn` and `#&nn` character-code literals;
- standard Pascal punctuation and operators;
- `:=`, `..`, `...`, `<>`, `>=`, `<=`, `><`, `**`;
- several compound assignment operators;
- `{...}`, `(*...*)`, and `//...` comments;
- `{$...}` and `(*$...*)` directive tokens; and
- nested ordinary comments in the prototype.

## Directive behavior

The tokenizer classifies these directives as first-class tokens:

- `$DEFINE`
- `$UNDEF`
- `$IFDEF`
- `$IFNDEF`
- `$IF`
- `$IFOPT`
- `$ELSE`
- `$ELSEIF`
- `$ENDIF` / `$IFEND`
- `$I` / `$INCLUDE`
- `$ERROR` / `$FATAL`

The tokenizer does not execute any directive. The conditional processor handles define state and branch selection. `$IF` handles simple `DEFINED(...)`, `NOT`, `AND`, `OR`, and boolean or defined-symbol tests locally. More complex expressions, including `DECLARED`, `SIZEOF`, or `HIGH`, are delegated through `TNXSemanticDirectiveResolver`.

Selected `$ERROR` and `$FATAL` directives fail during conditional processing; unselected ones remain inert. Active non-conditional directives are retained in the effective stream for a later precompile/compiler phase. Include loading is deliberately no longer a tokenizer responsibility.

## Important prototype limits

This is an architectural prototype, not yet a drop-in replacement for `scanner.pas`.

Before compiler integration, compatibility work still includes:

- exact NexusFPC language-mode keyword policy;
- all retained compiler directives and mode switches;
- assembler lexical context, including AArch64 `!` syntax;
- wide and Unicode string or character forms;
- source encoding and codepage behavior;
- exact numeric overflow and validation rules;
- FPC-specific string modes and multiline strings if retained;
- exact comment-nesting switches;
- any retained macro extension;
- diagnostics parity; and
- a differential token-dump test against the existing scanner.

`nxlexical_compat_scan.pas` provides a whole-file physical-tokenization scan. Its results must be classified because `.inc` files can contain assembler or makefile content rather than ordinary Pascal tokens.

## Block/resume model

A semantic directive does not delay or discard tokenizer work:

```text
source
  -> complete physical token stream
  -> conditional processor reaches semantic directive
  -> retain physical tokens and private conditional progress
  -> return cpsBlocked

dependency progresses

Continue
  -> retry conditional evaluation
  -> continue at the same physical-token position
  -> publish the effective token buffer
```

Physical tokens are already complete and publishable while conditional processing is blocked. No partial effective token buffer is published.

## Memory model

`TNXToken` is intentionally fixed-size and contains IDs and positions rather than copied token text. Identifier, literal and directive payloads live in separate pools. This keeps the primary token walk contiguous and cache-friendly.
