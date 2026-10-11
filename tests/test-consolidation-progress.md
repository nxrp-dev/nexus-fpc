# Test consolidation progress

This pass started at `db37cbcd`. It consolidated **1,309 baseline fixture files
into 170 logical groups** and removed three byte-identical duplicates: **1,142
fewer test programs overall**. The baseline inputs include groups from earlier
passes; the figures count files, not individual assertions. The 186 incremental
consolidation commits include intermediate groups that were subsequently merged,
and one Currency merge withdrawn after Win32 validation.

Groups follow language or RTL features: booleans, integers, floating point,
strings, arrays, sets, enumerations, classes, records, generics, interfaces,
routines, and related topics. Compatible cases can share a group across source
directories. Different modes, options and independent harness contracts remain
separate. No batch was accepted merely as a two-file-to-one-file reduction.

Original case IDs, comments and assertions remain in the grouped sources.
Global symbols receive case prefixes where needed. Terminal computed exit codes
become nonzero-status checks so subsequent cases execute. Locale-mutating cases
restore their initial formatting settings between cases. Compiler, RTL and
package production sources were not changed.

## Validation

- Every final group passes the standard test driver on Win64 and Win32, normally
  and with `-O2`: **680 final group checks**. Required per-fixture compiler
  options are retained; compile-only tests retain their `%NORUN` contract.
- Original inputs and final groups were checked independently on Win64; runtime
  output matches byte for byte. Win32 validation checks the grouped assertions
  and driver result. Existing failing originals were restored separately.
- The fresh isolated native bootstrap passed, with 14 baseline warnings.
- The maintained repository `scripts/Invoke-NexusFPCBootstrap.ps1` also passed
  the complete 13-target compiler/RTL matrix, including i386 Windows/Linux,
  x86-64 Windows/Linux/Darwin/iPhoneSimulator/Android, and AArch64
  Windows/Linux/Darwin/iOS/iPhoneSimulator/Android. Linux FmtBCD and the isolated
  `-CfNONE` heaptrc check passed. These are build checks; Linux, Apple and Android
  test executables were not run on this Windows host.
- All **32 focused compiler regression compile/run checks** passed, including
  saved and cached PPU consumers.
- Required option spellings remain exact, including option letter case. The
  final source hashes match the files validated on Win32. Named regression
  runner fixtures and included sources remain available.

## What remains separate

Unexpected standalone failures and unsuccessful regrouping attempts are recorded
in [the failure notes](test-consolidation-failures.md). Passing cases were removed
from failed candidate batches wherever a worthwhile compatible group remained.
The final sweep left no unchecked host-runnable candidate group of three or more
under the preserved contracts.

This does not mean every remaining standalone file is broken. Expected-error
fixtures, process/unit boundaries, named runner inputs, shared-type helpers,
external resources, global initialization/finalization, identity-sensitive
assertions and output, platform-only runtime tests, and one/two-file compatible
remainders retain meaningful isolation. The host cannot validate Darwin-only
Objective-C or AArch64-only runtime groups, so those were left unchanged.

Three exact duplicates were removed, with case IDs recorded in their survivors:
`tcasecov3b.pp`, `tisdigit3.pp`, and `tobjc9b.pp`. The first two survivors were
checked normally and with `-O2`; the Objective-C pair was verified byte-identical
without claiming execution on Darwin.

Local evidence is retained in `output/test-consolidation/evidence.zip`: original
and grouped commands/output, bootstrap logs, focused checks, inventories, and
commit/source mappings. The large temporary source/build copies were removed.
The fixture index in `tests/test/README.txt` points to the final grouped paths.
All changes are committed locally; nothing was pushed.

## Final groups

The input column counts files present at the start of this pass. Intermediate
batch history is preserved in Git and the evidence manifest.

| Feature group | Baseline input files |
|---|---:|
| `tbs/tb_arrays_delphi_consolidated_01.pp` | 3 |
| `tbs/tb_arrays_fpc_consolidated_01.pp` | 12 |
| `tbs/tb_arrays_fpc_consolidated_02.pp` | 3 |
| `tbs/tb_arrays_fpc_consolidated_03.pp` | 3 |
| `tbs/tb_arrays_objfpc_consolidated_01.pp` | 3 |
| `tbs/tb_booleans_fpc_consolidated_02.pp` | 15 |
| `tbs/tb_booleans_objfpc_consolidated_01.pp` | 5 |
| `tbs/tb_classes_delphi_consolidated_01.pp` | 4 |
| `tbs/tb_classes_delphi_consolidated_02.pp` | 27 |
| `tbs/tb_classes_delphi_consolidated_03.pp` | 34 |
| `tbs/tb_classes_delphi_consolidated_04.pp` | 6 |
| `tbs/tb_classes_delphi_consolidated_05.pp` | 4 |
| `tbs/tb_classes_delphi_consolidated_06.pp` | 7 |
| `tbs/tb_classes_delphi_consolidated_07.pp` | 5 |
| `tbs/tb_classes_delphi_consolidated_08.pp` | 3 |
| `tbs/tb_classes_delphi_consolidated_09.pp` | 3 |
| `tbs/tb_classes_objfpc_consolidated_01.pp` | 19 |
| `tbs/tb_classes_objfpc_consolidated_02.pp` | 12 |
| `tbs/tb_classes_objfpc_consolidated_04.pp` | 11 |
| `tbs/tb_classes_objfpc_consolidated_05.pp` | 8 |
| `tbs/tb_classes_objfpc_consolidated_06.pp` | 4 |
| `tbs/tb_classes_objfpc_consolidated_07.pp` | 5 |
| `tbs/tb_classes_objfpc_consolidated_09.pp` | 3 |
| `tbs/tb_classes_objfpc_consolidated_10.pp` | 3 |
| `tbs/tb_classes_objfpc_consolidated_11.pp` | 3 |
| `tbs/tb_control_flow_delphi_consolidated_02.pp` | 7 |
| `tbs/tb_control_flow_fpc_consolidated_01.pp` | 5 |
| `tbs/tb_control_flow_fpc_consolidated_02.pp` | 22 |
| `tbs/tb_control_flow_fpc_consolidated_03.pp` | 4 |
| `tbs/tb_control_flow_fpc_consolidated_04.pp` | 4 |
| `tbs/tb_control_flow_objfpc_consolidated_01.pp` | 7 |
| `tbs/tb_currency_fpc_consolidated_01.pp` | 3 |
| `tbs/tb_enumerations_delphi_consolidated_01.pp` | 4 |
| `tbs/tb_enumerations_delphi_consolidated_02.pp` | 3 |
| `tbs/tb_enumerations_fpc_consolidated_02.pp` | 7 |
| `tbs/tb_files_fpc_consolidated_01.pp` | 8 |
| `tbs/tb_files_objfpc_consolidated_01.pp` | 3 |
| `tbs/tb_floating_point_delphi_consolidated_01.pp` | 5 |
| `tbs/tb_floating_point_delphi_consolidated_02.pp` | 3 |
| `tbs/tb_floating_point_fpc_consolidated_01.pp` | 30 |
| `tbs/tb_floating_point_fpc_consolidated_04.pp` | 12 |
| `tbs/tb_floating_point_fpc_consolidated_05.pp` | 7 |
| `tbs/tb_floating_point_objfpc_consolidated_01.pp` | 12 |
| `tbs/tb_floating_point_objfpc_consolidated_02.pp` | 4 |
| `tbs/tb_floating_point_objfpc_consolidated_03.pp` | 6 |
| `tbs/tb_generics_delphi_consolidated_01.pp` | 32 |
| `tbs/tb_generics_objfpc_consolidated_01.pp` | 11 |
| `tbs/tb_generics_objfpc_consolidated_02.pp` | 8 |
| `tbs/tb_generics_objfpc_consolidated_03.pp` | 3 |
| `tbs/tb_generics_objfpc_consolidated_04.pp` | 3 |
| `tbs/tb_generics_objfpc_consolidated_05.pp` | 4 |
| `tbs/tb_integers_delphi_consolidated_01.pp` | 15 |
| `tbs/tb_integers_delphi_consolidated_03.pp` | 4 |
| `tbs/tb_integers_delphi_consolidated_04.pp` | 5 |
| `tbs/tb_integers_fpc_consolidated_01.pp` | 5 |
| `tbs/tb_integers_fpc_consolidated_02.pp` | 5 |
| `tbs/tb_integers_fpc_consolidated_03.pp` | 5 |
| `tbs/tb_integers_fpc_consolidated_04.pp` | 4 |
| `tbs/tb_integers_fpc_consolidated_05.pp` | 41 |
| `tbs/tb_integers_fpc_consolidated_08.pp` | 9 |
| `tbs/tb_integers_macpas_consolidated_01.pp` | 6 |
| `tbs/tb_integers_objfpc_consolidated_01.pp` | 18 |
| `tbs/tb_integers_objfpc_consolidated_02.pp` | 7 |
| `tbs/tb_integers_objfpc_consolidated_03.pp` | 3 |
| `tbs/tb_integers_objfpc_consolidated_04.pp` | 3 |
| `tbs/tb_integers_objfpc_consolidated_05.pp` | 4 |
| `tbs/tb_integers_objfpc_consolidated_06.pp` | 3 |
| `tbs/tb_interfaces_delphi_consolidated_01.pp` | 3 |
| `tbs/tb_interfaces_delphi_consolidated_02.pp` | 8 |
| `tbs/tb_interfaces_delphi_consolidated_04.pp` | 5 |
| `tbs/tb_interfaces_objfpc_consolidated_01.pp` | 6 |
| `tbs/tb_interfaces_objfpc_consolidated_02.pp` | 3 |
| `tbs/tb_interfaces_objfpc_consolidated_03.pp` | 6 |
| `tbs/tb_objects_fpc_consolidated_01.pp` | 3 |
| `tbs/tb_objects_objfpc_consolidated_02.pp` | 6 |
| `tbs/tb_records_delphi_consolidated_01.pp` | 3 |
| `tbs/tb_records_delphi_consolidated_02.pp` | 3 |
| `tbs/tb_records_fpc_consolidated_01.pp` | 14 |
| `tbs/tb_records_fpc_consolidated_02.pp` | 3 |
| `tbs/tb_records_macpas_consolidated_01.pp` | 5 |
| `tbs/tb_records_objfpc_consolidated_01.pp` | 4 |
| `tbs/tb_records_objfpc_consolidated_02.pp` | 6 |
| `tbs/tb_routines_delphi_consolidated_01.pp` | 4 |
| `tbs/tb_routines_fpc_consolidated_01.pp` | 4 |
| `tbs/tb_sets_objfpc_consolidated_01.pp` | 3 |
| `tbs/tb_strings_delphi_consolidated_01.pp` | 5 |
| `tbs/tb_strings_delphi_consolidated_02.pp` | 11 |
| `tbs/tb_strings_delphi_consolidated_04.pp` | 9 |
| `tbs/tb_strings_delphi_consolidated_05.pp` | 3 |
| `tbs/tb_strings_fpc_consolidated_01.pp` | 42 |
| `tbs/tb_strings_fpc_consolidated_02.pp` | 11 |
| `tbs/tb_strings_fpc_consolidated_04.pp` | 4 |
| `tbs/tb_strings_objfpc_consolidated_01.pp` | 9 |
| `tbs/tb_strings_objfpc_consolidated_02.pp` | 11 |
| `tbs/tb_strings_objfpc_consolidated_03.pp` | 6 |
| `tbs/tb_strings_objfpc_consolidated_05.pp` | 4 |
| `tbs/tb_strings_objfpc_consolidated_06.pp` | 14 |
| `tbs/tb_variants_fpc_consolidated_01.pp` | 9 |
| `tbs/tb_variants_fpc_consolidated_02.pp` | 4 |
| `tbs/tb_variants_objfpc_consolidated_02.pp` | 8 |
| `test/cg/tb_arrays_fpc_consolidated_01.pp` | 4 |
| `test/cg/tb_classes_objfpc_consolidated_01.pp` | 11 |
| `test/cg/tb_floating_point_fpc_consolidated_01.pp` | 5 |
| `test/cg/tb_integers_fpc_consolidated_01.pp` | 11 |
| `test/cg/tb_objects_fpc_consolidated_01.pp` | 3 |
| `test/cg/tb_records_fpc_consolidated_01.pp` | 7 |
| `test/cg/tb_routines_fpc_consolidated_01.pp` | 4 |
| `test/cg/tb_sets_fpc_consolidated_01.pp` | 5 |
| `test/cg/tb_strings_fpc_consolidated_01.pp` | 5 |
| `test/cg/tb_strings_objfpc_consolidated_01.pp` | 4 |
| `test/opt/tb_control_flow_fpc_consolidated_01.pp` | 3 |
| `test/tb_arrays_fpc_consolidated_01.pp` | 5 |
| `test/tb_arrays_macpas_consolidated_01.pp` | 5 |
| `test/tb_arrays_objfpc_consolidated_01.pp` | 5 |
| `test/tb_booleans_macpas_consolidated_01.pp` | 5 |
| `test/tb_characters_fpc_consolidated_01.pp` | 3 |
| `test/tb_classes_delphi_consolidated_01.pp` | 3 |
| `test/tb_classes_delphi_consolidated_02.pp` | 19 |
| `test/tb_classes_delphi_consolidated_03.pp` | 31 |
| `test/tb_classes_delphi_consolidated_04.pp` | 20 |
| `test/tb_classes_delphi_consolidated_05.pp` | 5 |
| `test/tb_classes_objfpc_consolidated_02.pp` | 9 |
| `test/tb_classes_objfpc_consolidated_03.pp` | 3 |
| `test/tb_classes_objfpc_consolidated_04.pp` | 3 |
| `test/tb_classes_objfpc_consolidated_05.pp` | 4 |
| `test/tb_classes_objfpc_consolidated_06.pp` | 6 |
| `test/tb_classes_objfpc_consolidated_07.pp` | 3 |
| `test/tb_classes_objfpc_consolidated_08.pp` | 3 |
| `test/tb_classes_objfpc_consolidated_09.pp` | 9 |
| `test/tb_classes_objfpc_consolidated_10.pp` | 3 |
| `test/tb_control_flow_objfpc_consolidated_01.pp` | 5 |
| `test/tb_enumerations_fpc_consolidated_01.pp` | 5 |
| `test/tb_files_iso_consolidated_01.pp` | 3 |
| `test/tb_floating_point_fpc_consolidated_01.pp` | 5 |
| `test/tb_generics_delphi_consolidated_03.pp` | 5 |
| `test/tb_generics_delphi_consolidated_04.pp` | 7 |
| `test/tb_generics_objfpc_consolidated_01.pp` | 17 |
| `test/tb_generics_objfpc_consolidated_02.pp` | 26 |
| `test/tb_generics_objfpc_consolidated_03.pp` | 5 |
| `test/tb_generics_objfpc_consolidated_04.pp` | 10 |
| `test/tb_integers_delphi_consolidated_01.pp` | 6 |
| `test/tb_integers_fpc_consolidated_01.pp` | 21 |
| `test/tb_integers_fpc_consolidated_02.pp` | 4 |
| `test/tb_integers_fpc_consolidated_03.pp` | 5 |
| `test/tb_integers_macpas_consolidated_01.pp` | 7 |
| `test/tb_integers_objfpc_consolidated_01.pp` | 6 |
| `test/tb_integers_objfpc_consolidated_02.pp` | 4 |
| `test/tb_interfaces_objfpc_consolidated_01.pp` | 3 |
| `test/tb_objects_delphi_consolidated_01.pp` | 4 |
| `test/tb_records_delphi_consolidated_01.pp` | 8 |
| `test/tb_records_delphi_consolidated_02.pp` | 7 |
| `test/tb_records_delphi_consolidated_03.pp` | 5 |
| `test/tb_records_fpc_consolidated_01.pp` | 19 |
| `test/tb_records_iso_consolidated_01.pp` | 3 |
| `test/tb_records_macpas_consolidated_01.pp` | 5 |
| `test/tb_records_objfpc_consolidated_01.pp` | 3 |
| `test/tb_records_objfpc_consolidated_02.pp` | 3 |
| `test/tb_records_objfpc_consolidated_03.pp` | 3 |
| `test/tb_records_objfpc_consolidated_04.pp` | 4 |
| `test/tb_routines_delphi_consolidated_01.pp` | 4 |
| `test/tb_sets_fpc_consolidated_01.pp` | 8 |
| `test/tb_strings_delphi_consolidated_01.pp` | 7 |
| `test/tb_strings_fpc_consolidated_01.pp` | 44 |
| `test/tb_strings_fpc_consolidated_02.pp` | 4 |
| `test/tb_strings_fpc_consolidated_03.pp` | 5 |
| `test/tb_strings_fpc_consolidated_04.pp` | 8 |
| `test/tb_strings_objfpc_consolidated_01.pp` | 5 |
| `test/tb_strings_objfpc_consolidated_02.pp` | 6 |
| `test/units/system/tb_integers_fpc_consolidated_01.pp` | 3 |
| `webtbf/tb_records_fpc_consolidated_01.pp` | 3 |
