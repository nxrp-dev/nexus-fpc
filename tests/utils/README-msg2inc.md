# Message catalog and TeX regressions

Build `compiler/utils/msg2inc.pas` with the compiler being checked, putting its
executable and object files in a unique directory under the development
worktree. Then run:

```sh
bash tests/utils/Run-NXMsg2IncTests.sh /absolute/path/to/msg2inc /absolute/worktree/path/checks
```

The 36 checks generate all 22 message catalogs, verify that both Polish
catalogs use the English assignments for APPID, APPNAME and the string-length
error, and compare exact TeX output for `-T`, `-t`, `-TS` and `-Ts`. Full English
documentation must have the same body with and without the standalone wrapper.
An intentionally duplicated message ID must still be rejected.

The repaired defects were duplicate/misassigned IDs in both Polish encodings,
an `&` instead of `%` comment marker in Turkish, and an empty-string suffix
access when parsing bare `-T`. Catalog edits preserve the original encodings
and message payloads. The command-line fix checks for a suffix before reading
it; it does not change TeX formatting or standalone output.

Run the suite with both stock FPC 3.2.2 and NexusFPC builds of the tool to retain
seed-compiler coverage. All generated files belong outside the source tree.
