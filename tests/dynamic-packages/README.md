# Compiler package metadata regressions

This suite covers dynamic-package backlog items 1–4 without enabling packages in
any production target. It builds an isolated Win64 compiler and a test driver
linked against the same compiler units. The driver enables the package capability
only inside its own process for graph validation and compile-only consumption.

From the repository root:

```powershell
python tests\dynamic-packages\run_package_metadata_tests.py
```

Requirements: Python 3, an FPC 3.2.2 Win64 bootstrap (default
`C:\lazarus\fpc\3.2.2\bin\x86_64-win64\ppcx64.exe`), and matching NexusFPC RTL
units already built in `rtl\units\x86_64-win64`. Use `--bootstrap` to select a
different bootstrap location. Outputs go to a new temporary directory, printed
on success. `--output-root` accepts an empty directory; `--compiler-build` reuses
an isolated build directory and incrementally rebuilds its compiler before testing.
Neither option should point at the repository's production compiler directory.

The suite records each command, exit code, and log path in `steps.json`. It checks:

- Case-insensitive identity, display spelling, duplicate diagnostics, and promotion
  from an indirect requirement to a direct one.
- Valid diamond dependencies, self/indirect cycles, and cycles involving a package
  being built that does not yet have a PCP.
- Conflicting owners in both dependency orders and the existing parser diagnostic
  for containing a unit already supplied by a required package.
- Real writer/reader round-trip, unchanged original PPU, repeated loading,
  independent bounded unit streams, and independently encoded version-3 metadata.
- Empty/multiple-unit containers, opposite-endian metadata, metadata crossing the
  entry buffer boundary, and malformed headers, counts, names, entries, checksums,
  offset tables, overlapping ranges, and embedded PPU headers.
- Compilation using a PCP while the packaged unit's source, standalone PPU, and
  object file are unavailable. This includes resumable loading of its dependencies.
- Continued rejection of package declarations by the production compiler.

On 2026-10-09 all 70 steps passed. The existing `tests/unit-exports` suite supplies
separate ordinary EXE/DLL build, export, runtime, cached-unit, and smart-link coverage.

The source-free consumer uses `-Cn`: this proves compile-time PCP consumption,
not package linking, shared RTL identity, or runtime loading/unloading. There is
no historical PCP corpus here; compatibility evidence consists of the unchanged
v3 layout plus independently encoded fixtures and real compiler-generated PPUs.
