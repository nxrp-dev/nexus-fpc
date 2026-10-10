# Compiler regressions recovered from test consolidation

Run the focused checks with the repository compiler and Win64 RTL:

```powershell
python tests/compiler-regressions/run_compiler_regressions.py
```

Use `--compiler`, `--rtl`, and an empty `--output-root` to select another native
compiler, its matching RTL, and a persistent results directory. Commands and
results are recorded in `results.json`; each compile/run has its own log.
Execution is sequential.

The runner uses the same Pascal fixtures as the normal test suite rather than
generating another copy of the tests. It covers:

- Generic `set of T` declarations and runtime operations in Delphi and ObjFPC
  modes, including enum/Byte specializations and unused generic declarations.
- Generic set literals, membership, mixed elements, ranges, union/difference,
  nested routines, and expression evaluation counts, including fixed
  `set of Byte` destinations.
- Generic set fields specialized from a saved PPU, with the unit source hidden;
  a second consumer checks that the cached unit remains unchanged.
- Invalid set element types and ranges, requiring ordinary compiler diagnostics.
  Non-ordinal literal elements are still rejected when specializing.
- CORBA interface identifiers assigned to all supported string types, including
  bounded short-string truncation, `-O2`, and `{$H-}`.
- Invalid interface conversions, requiring diagnostics without internal errors.

The normal test suite discovers the `t*.pp` fixtures in `tbs`, `tbf`, and
`webtbf`. The saved-unit consumer also uses its standard `RECOMPILE` directive.
The focused runner adds the source-hidden PPU check and optimization variant.

See [the recovery report](../../nexusfpc-compiler-regression-recovery.md) for the
original failure, compiler correction, and recorded validation.
