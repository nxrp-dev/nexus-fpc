NexusFPC tests
==============

Native unit-test projects, suite boundaries, categories and execution instructions:
  NXTEST.md

Observed unresolved failures and explicit skips:
  NXTEST-FAILURES.md

Measured validation and platform limits:
  NXTEST-VALIDATION.md

The punit and dotest runners, redirection/digest tools, database schemas and
FPCUnit console defaults are retired. Current results come from nxtest.

Runtime RTL compiler inputs are under rtl/fixtures; their native suite catalog
is rtl/fixtures.tsv. Compiler modes, options, expected compilation failures,
expected exit codes, platform restrictions and interactive/no-run contracts
remain in the source's initial { %DIRECTIVE=value } comments. The shared
utils/tsutils.pas parser reads those comments and is covered by native tests.

The large tbs, tbf, test and webtbf directories are language/code-generation
fixture corpora. ABI/package/export scripts and benchmarks remain separate
integration/performance work. python-runner-retirement.md records their existing
orchestration backlog; those historical results are not new unit-suite passes.
