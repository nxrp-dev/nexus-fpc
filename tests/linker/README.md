# Linux shared-library linking regressions

These ten direct nxtest cases compile tiny C providers and Pascal consumers,
execute the consumers and inspect their ELF DT_NEEDED entries with LLVM.
Versioned-library cases deliberately provide no unversioned `.so` alias.
They cover external declarations, linklib directives, source-hidden NXU imports,
explicit `:filename` lookup, literal filenames without a lib prefix, a path with
spaces, bare-name behavior and static archive fallback, a missing ABI and an NXPL filename control.
The NXPL control tests exact filename handling, not package metadata or ownership.

Build `NXSharedLibraryTests.nxproject` with Nexus nxbuild and the configured
NexusFPC toolchain. The test driver accepts five arguments:

```
NXSharedLibraryTests /path/to/ppcx64 /path/to/matching/rtl /path/to/output /path/to/clang /path/to/llvm-readobj
```

Use an empty output directory for each compiler comparison. C providers need no
headers or libc development files. The static fallback control uses llvm-ar from PATH. The Pascal probes explicitly link libc, as
the X11 bindings do. The driver itself uses nxtest and the relocated process
package; no FPCUnit framework or bridge is involved. This suite targets native
Linux and does not claim Android or other-host execution coverage.

The compiler distinguishes bare library names from explicit ELF filenames.
Versioned `.so.*`, `.nxpl` and explicit `:filename` references retain
exact lookup; missing ABI names must fail without falling back to another ABI.
