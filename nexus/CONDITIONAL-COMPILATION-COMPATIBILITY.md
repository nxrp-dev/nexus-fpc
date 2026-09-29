# Conditional Compilation Compatibility Review

## Scope

This review supports NXLR-0001, which requires every physical conditional
branch to be lexically tokenizable.

The review scanned 1,955 `.pas`, `.pp`, and `.inc` files under:

- `compiler`;
- `rtl`; and
- every `packages/fcl-*` directory.

`nxlexical_compat_scan.pas` tokenizes each physical file without evaluating
conditional directives. It also checks the structured directive tokens for a
conditional stack that crosses physical EOF.

This is a focused compatibility screen, not yet a claim of complete parity
with the production FPC scanner. Findings caused by known prototype lexical
gaps are classified separately below.

## Conditional dependencies found and corrected

### Inactive Delphi-style `#ERROR` text

`packages/fcl-db/src/dbase/dbf_common.inc` contained three inactive branches
whose bodies used this non-Pascal text:

```text
#ERROR tDbf needs Delphi or C++ Builder 3 minimum.
```

The branches are normally skipped by FPC. Under NXLR-0001, the text must be
lexically valid even when the corresponding legacy Delphi-version symbol is
not defined.

Each occurrence now uses an explicit compiler directive:

```pascal
{$ERROR 'tDbf needs Delphi or C++ Builder 3 minimum.'}
```

The failure remains conditional, but the physical source is tokenizable.

### Conditional left open at physical EOF

`rtl/inc/lstrings.pp` opened `{$IFDEF lstrings_unit}` around its standalone-unit
footer and reached physical EOF without a matching directive. An explicit
`{$ENDIF lstrings_unit}` now closes that physical conditional region.

## Expected constructs that remain valid

Conditional punctuation, operators, identifiers, member fragments,
declaration fragments and incomplete grammatical constructs are not lexical
compatibility failures. They remain ordinary tokens in the physical stream.
Only the selected effective stream must parse.

No other conditional branch dependency on an unterminated string, an
unterminated comment, arbitrary prose, or a lexical construct spanning a
conditional boundary was identified in files successfully covered by the
prototype scanner.

## Findings requiring separate decisions

Six files remain outside a clean prototype scan:

- three AArch64 assembler includes use `!` as valid assembler punctuation;
- two `makefile.inc` files contain makefile syntax rather than Pascal source;
- `packages/fcl-base/examples/promisesimple.pp` contains an independently
  unterminated opening comment.

The assembler findings expose a real integration question. Globally accepting
`!` as ordinary Pascal punctuation would make text such as `STOP!` lexically
tokenizable, undermining the intended Pascal rule. The production design needs
an explicit contract for embedded assembler lexical context.

The makefile fragments need source-kind metadata or exclusion from Pascal
tokenization. Their `.inc` extension alone is not sufficient evidence that they
contain Pascal source.

The FCL example defect is not conditional-compilation behavior and was not
changed in this pass.

## Reproduction

Build `nexus/nxlexical_compat_scan.pas` with the tokenizer directory on the unit
path, then pass `compiler`, `rtl`, and the `packages/fcl-*` directories as
arguments. The scanner prints one review line per rejected file and a final
count summary.
