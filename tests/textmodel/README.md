# Text-model tests

Runtime ANSI/Unicode comparisons, explicit and legacy-name Unicode searches,
transformations, format buffers, copy/replace operations, helpers and default
Unicode StringList comparisons now register in RTLObjPasTests through
`packages/rtl-objpas/tests/tsNXUnicodeText.pas`. Their seven original standalone
programs are removed. TEXT-001 explicitly skips the Unicode-default comparison
case when the suite is compiled against an ANSI-default RTL; its original
assertions remain and require `-MUNICODESTRINGS` with a matching Unicode RTL.

The remaining Pascal/config inputs test compiler configuration and type binding:

- `ansi_default` / `unicode_default`: String/Char/PChar defaults and fixed/short
  string sizes, including the legacy H/LONGSTRINGS directives.
- `rtl_mode_contract`: RTLString, search/symlink record aliases and the declared
  GetCurrentDir return type for the selected RTL text model.
- `windows_api_aliases`: Windows API character-pointer aliases.
- `source_mode_*`, `source_textmode_*`, `config_textmode_*` and
  `mac_undefined_textmode`: mode restrictions and reserved-definition diagnostics.
- `cacheunit` / `cache_client`: saved-unit text-model compatibility.

Those inputs must be compiled with the intended matching ANSI or Unicode RTL and
expected diagnostic configuration. They are compiler fixtures, not another unit
assertion runner.
