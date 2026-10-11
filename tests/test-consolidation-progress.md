# Test consolidation progress

This pass started at `db37cbcd`. Each batch below passed the standard
test driver individually and grouped, normally and with `-O2`, using
a freshly bootstrapped Win64 compiler and matching RTL/packages. Runtime
output is compared byte for byte. Expected compile failures and fixtures
that require an independent program/unit remain separate.

Original case IDs, source comments, assertions, modes and required options
are retained. Global names receive case prefixes. Terminal computed exit
codes become equivalent nonzero-status checks so later cases can run.
The initial native bootstrap passed; its 14 warnings match the baseline.
Unexpected failures are recorded in [the failure notes](test-consolidation-failures.md).

| Feature group | Original fixtures | Grouped fixtures |
|---|---:|---:|
| `tbs/tb_booleans_objfpc_consolidated_01.pp` | 5 | 1 |
| `tbs/tb_floating_point_fpc_consolidated_01.pp` | 31 | 1 |
