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
| `tbs/tb_variants_fpc_consolidated_01.pp` | 9 | 1 |
| `tbs/tb_floating_point_delphi_consolidated_01.pp` | 5 | 1 |
| `tbs/tb_floating_point_delphi_consolidated_02.pp` | 3 | 1 |
| `tbs/tb_floating_point_fpc_consolidated_03.pp` | 5 | 1 |
| `tbs/tb_floating_point_fpc_consolidated_02.pp` | 8 | 1 |
| `tbs/tb_floating_point_objfpc_consolidated_01.pp` | 12 | 1 |
| `tbs/tb_floating_point_objfpc_consolidated_02.pp` | 4 | 1 |
| `tbs/tb_integers_fpc_consolidated_01.pp` | 5 | 1 |
| `tbs/tb_integers_fpc_consolidated_02.pp` | 5 | 1 |
| `tbs/tb_integers_fpc_consolidated_03.pp` | 5 | 1 |
| `tbs/tb_integers_fpc_consolidated_04.pp` | 4 | 1 |
| `tbs/tb_records_objfpc_consolidated_01.pp` | 4 | 1 |
| `tbs/tb_routines_delphi_consolidated_01.pp` | 4 | 1 |
| `tbs/tb_routines_fpc_consolidated_01.pp` | 4 | 1 |
| `tbs/tb_strings_delphi_consolidated_03.pp` | 7 | 1 |
| `tbs/tb_strings_objfpc_consolidated_03.pp` | 6 | 1 |
| `tbs/tb_variants_fpc_consolidated_02.pp` | 4 | 1 |
| `tbs/tb_arrays_delphi_consolidated_01.pp` | 3 | 1 |
| `tbs/tb_arrays_fpc_consolidated_01.pp` | 12 | 1 |
| `tbs/tb_arrays_fpc_consolidated_02.pp` | 3 | 1 |
| `tbs/tb_arrays_fpc_consolidated_03.pp` | 3 | 1 |
| `tbs/tb_booleans_fpc_consolidated_01.pp` | 10 | 1 |
| `tbs/tb_control_flow_delphi_consolidated_01.pp` | 5 | 1 |
| `tbs/tb_control_flow_fpc_consolidated_01.pp` | 5 | 1 |
| `tbs/tb_control_flow_fpc_consolidated_03.pp` | 4 | 1 |
| `tbs/tb_control_flow_objfpc_consolidated_01.pp` | 7 | 1 |
| `tbs/tb_currency_fpc_consolidated_01.pp` | 3 | 1 |
| `tbs/tb_files_fpc_consolidated_01.pp` | 8 | 1 |
| `tbs/tb_floating_point_objfpc_consolidated_03.pp` | 6 | 1 |
| `tbs/tb_integer_checks_objfpc_consolidated_01.pp` | 3 | 1 |
| `tbs/tb_integers_delphi_consolidated_01.pp` | 15 | 1 |
| `tbs/tb_integers_delphi_consolidated_02.pp` | 3 | 1 |
| `tbs/tb_integers_delphi_consolidated_03.pp` | 4 | 1 |
| `tbs/tb_integers_fpc_consolidated_06.pp` | 7 | 1 |
| `tbs/tb_integers_objfpc_consolidated_03.pp` | 3 | 1 |
| `tbs/tb_records_fpc_consolidated_02.pp` | 3 | 1 |
| `tbs/tb_strings_delphi_consolidated_01.pp` | 5 | 1 |
| `tbs/tb_strings_delphi_consolidated_02.pp` | 11 | 1 |
| `tbs/tb_strings_fpc_consolidated_01.pp` | 42 | 1 |
| `tbs/tb_strings_objfpc_consolidated_01.pp` | 9 | 1 |
| `tbs/tb_strings_objfpc_consolidated_02.pp` | 11 | 1 |
| `tbs/tb_strings_objfpc_consolidated_04.pp` | 11 | 1 |
| `tbs/tb_variants_objfpc_consolidated_01.pp` | 6 | 1 |
| `test/tb_arrays_fpc_consolidated_01.pp` | 5 | 1 |
| `test/tb_arrays_macpas_consolidated_01.pp` | 5 | 1 |
| `test/tb_arrays_objfpc_consolidated_01.pp` | 5 | 1 |
| `test/tb_booleans_macpas_consolidated_01.pp` | 5 | 1 |
| `test/tb_classes_delphi_consolidated_01.pp` | 3 | 1 |
| `test/tb_control_flow_objfpc_consolidated_01.pp` | 5 | 1 |
| `test/tb_floating_point_fpc_consolidated_01.pp` | 5 | 1 |
| `test/tb_integers_fpc_consolidated_01.pp` | 21 | 1 |
| `test/tb_integers_fpc_consolidated_02.pp` | 4 | 1 |
| `test/tb_integers_macpas_consolidated_01.pp` | 7 | 1 |
| `test/tb_records_delphi_consolidated_01.pp` | 8 | 1 |
| `test/tb_records_iso_consolidated_01.pp` | 3 | 1 |
| `test/tb_routines_delphi_consolidated_01.pp` | 4 | 1 |
| `test/tb_strings_delphi_consolidated_01.pp` | 7 | 1 |
| `test/cg/tb_arrays_fpc_consolidated_01.pp` | 4 | 1 |
| `test/cg/tb_floating_point_fpc_consolidated_01.pp` | 5 | 1 |
| `test/cg/tb_integers_fpc_consolidated_01.pp` | 11 | 1 |
| `test/cg/tb_objects_fpc_consolidated_01.pp` | 3 | 1 |
| `test/cg/tb_strings_fpc_consolidated_01.pp` | 5 | 1 |
| `test/cg/tb_strings_objfpc_consolidated_01.pp` | 4 | 1 |
| `tbs/tb_arrays_objfpc_consolidated_01.pp` | 3 | 1 |
| `tbs/tb_classes_objfpc_consolidated_01.pp` | 19 | 1 |
| `tbs/tb_control_flow_fpc_consolidated_02.pp` | 22 | 1 |
| `tbs/tb_integers_objfpc_consolidated_01.pp` | 18 | 1 |
| `tbs/tb_interfaces_delphi_consolidated_01.pp` | 3 | 1 |
| `tbs/tb_interfaces_objfpc_consolidated_01.pp` | 6 | 1 |
| `tbs/tb_objects_fpc_consolidated_01.pp` | 3 | 1 |
| `tbs/tb_objects_objfpc_consolidated_01.pp` | 4 | 1 |
| `tbs/tb_records_fpc_consolidated_01.pp` | 15 | 1 |
| `test/tb_generics_delphi_consolidated_01.pp` | 5 | 1 |
| `test/tb_sets_fpc_consolidated_01.pp` | 8 | 1 |
| `test/cg/tb_records_fpc_consolidated_01.pp` | 7 | 1 |
| `test/cg/tb_routines_fpc_consolidated_01.pp` | 4 | 1 |
| `test/cg/tb_sets_fpc_consolidated_01.pp` | 5 | 1 |
| `test/units/system/tb_integers_fpc_consolidated_01.pp` | 3 | 1 |
| `tbs/tb_classes_delphi_consolidated_04.pp` | 6 | 1 |
| `tbs/tb_classes_delphi_consolidated_05.pp` | 4 | 1 |
| `tbs/tb_control_flow_fpc_consolidated_04.pp` | 4 | 1 |
| `tbs/tb_enumerations_delphi_consolidated_02.pp` | 3 | 1 |
| `tbs/tb_files_objfpc_consolidated_01.pp` | 3 | 1 |
| `tbs/tb_integers_macpas_consolidated_01.pp` | 6 | 1 |
| `tbs/tb_integers_objfpc_consolidated_04.pp` | 3 | 1 |
| `tbs/tb_strings_objfpc_consolidated_05.pp` | 4 | 1 |
| `test/tb_characters_fpc_consolidated_01.pp` | 3 | 1 |
| `test/tb_classes_delphi_consolidated_05.pp` | 5 | 1 |
| `test/tb_classes_objfpc_consolidated_06.pp` | 6 | 1 |
| `test/tb_classes_objfpc_consolidated_08.pp` | 3 | 1 |
| `test/tb_files_iso_consolidated_01.pp` | 3 | 1 |
| `test/tb_generics_objfpc_consolidated_03.pp` | 5 | 1 |
| `test/tb_integers_delphi_consolidated_01.pp` | 6 | 1 |
