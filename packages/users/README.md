# Unix user and group lookup

This package supplies the `users` unit used by fpGUI's Linux file-list backend
to display file-owner and group names. The `pwd`, `grp`, and `shadow` units
provide the underlying account database bindings. `crypth` supplies the separate
`crypt` binding.

Runtime units live in `src/`; `namespaced/` and `namespaces.lst` retain the
corresponding dotted-unit mappings. Original examples live in `examples/`.
Pascal sources and namespace include references use NexusFPC's `.pas` convention.
Add `src/` to the consuming build's unit search path and use matching NexusFPC
RTL units. Compiled units belong in the build or toolchain output directory.

Authors, restoration evidence, and license terms are recorded in the
[canonical attribution record](https://github.com/nxrp-dev/nexus/blob/main/ATTRIBUTIONS.md#free-pascal-and-nexusfpc).
The shared distribution notice remains in `../COPYING.FPC`; original source
notices remain with the units.
