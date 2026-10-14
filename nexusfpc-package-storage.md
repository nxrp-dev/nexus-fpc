# Runtime package storage

Approved direction: one native `.nxpl` package library by default, with an
optional `.nxp` sidecar for comparing distribution size and compiler cost.
This changes storage, not the runtime package ABI or initialization model.

## Developer option

The compiler defaults to embedded metadata. `-FJ` / `-FJ+` enables embedding;
`-FJ-` disables it. The equivalent named values are `-FJEnabled` and
`-FJDisabled`. Forge exposes `EmbedPackageMetadata: Enabled` or `Disabled`;
nxbuild exposes the same setting under `BuildControl` (with its usual `Unset`
state). Omission uses the compiler default. Packages may mix these settings.

* Embedded: distribute `name.nxpl` for both development and runtime.
* Split: distribute `name.nxpl` and `name.nxp` for development; runtime needs
  only `name.nxpl`.

The `.nxpl` name applies on both supported package targets: Windows x86-64 and
Linux x86-64. Ordinary libraries retain their normal platform filenames.
Linux package dependencies use exact library filenames and matching SONAMEs.

## Storage and ownership

`compiler/nxpackagefile.pas` owns the common container reader, encoder and
decoder. Compiler and Forge use this implementation. The existing NXP004
metadata and its embedded NXU records remain the uncompressed payload.
Compression uses the existing Pascal zlib implementation; it introduces no
external compression DLL or runtime dependency. Compiler builds stage the
Pascal compression and hash sources alongside their other build inputs.

The native image contains a `.nxmeta` section before linking, stripping,
publication hashing or signing. Its little-endian envelope contains:

| Offset | Size | Meaning |
| --- | --- | --- |
| 0 | 8 | `NXPM0001` storage signature/version |
| 8 | 4 | Payload placement: 1 embedded, 0 sidecar |
| 12 | 4 | Uncompressed metadata byte count |
| 16 | 4 | Compressed metadata byte count |
| 20 | 20 | SHA-1 fingerprint of the uncompressed metadata |
| 40 | variable | zlib stream, present for embedded storage |

A sidecar contains the same envelope with placement 1 and the same zlib stream.
The native image always retains the sizes and fingerprint, so replacing the
sidecar with one from a different build fails before unit metadata is read.
The fingerprint is a content-consistency check, not package authentication.
SDK and package publication retain their existing SHA-256 artifact checks.

The reader locates the section through PE/ELF section tables without loading
the image. It validates ranges, the envelope version, compression termination,
exact decoded size and fingerprint. Existing compiler target, SDK, build,
dependency, unit-range and checksum checks still apply to the decoded payload.
An embedded payload takes precedence over any stale sidecar. Corrupt embedded
metadata is an error, not a reason to fall back to another file.

## Evaluation and limits

Runtime code never reads or decompresses this metadata. Native loading,
descriptors, explicit startup activation, package lifetime and threading
remain unchanged. Normal build intermediates such as objects and import
libraries still exist; the single-file promise concerns the published package.

Embedding increases the library's file size and the metadata must be read and
decompressed during compilation. The current compiler retains decoded package
metadata in memory, as it needs random access to its embedded units. Switching
placement does not remove this decoding cost. PE section alignment also adds
padding. Signing is performed after the compiler finishes the native image.
Tools explicitly removing `.nxmeta` make the image unusable for compilation.

## Verification: 2026-10-14

Verified in isolated outputs, without replacing the normal installed tools:

* Full Forge bootstrap from stock FPC 3.2.2 Win32 passed. Compiler generations
  two and three have identical SHA-256
  `D72BA192255D011849C8A915CDD1ECA9D3A70AE446867340E0F1D4E511914489`.
  Release-tool validation passed: 18 tools, 29 execution steps and 64 matching
  generated table includes.
* Forge built the actual Win64 package SDK with `nxrtl.nxpl` and no sidecar.
* Forge and nxbuild CLI builds passed. Their nxtest suites passed 52 and 20
  tests respectively, with no failures, errors, skips or unfreed heap blocks.
  Coverage includes PE/ELF storage, malformed/truncated/compressed payloads,
  fingerprints, embedded precedence, missing/mismatched sidecars, publication
  and both option front ends.
* The existing Windows package runtime suite passed all 97 steps, covering
  normal/smart linking and fresh/cached consumers. Separate real package checks
  passed mixed embedded/split dependencies in both directions and rejected a
  mismatched sidecar. Runtime copies contained only native package images.
* `llvm-strip --strip-all` preserved the actual Win64 `.nxmeta` section. It is
  read-only; a source-free consumer compiled, linked and ran against that image.
* The provided console and GUI late-loading examples built and ran through
  Forge, including unload, resources, registries and reload.
* Cross compiler/RTL/smoke builds passed for i386-win32, x86_64-linux and
  aarch64-linux. The Win32 smoke executable also ran successfully. This is a
  selected cross-build check, not a rerun of the entire target matrix.

Linux native package linking/execution is not verified in this pass. The Windows
cross-link attempt produced the ELF package object but selected the installed
PE-only GNU linker, which rejected `elf_x86_64`; a matching Linux glibc link
sysroot was not established here. The ELF container tests pass. A native Linux
check must still cover `.nxpl` SONAME/dependency names, stripping and package
startup/unload. No Linux runtime success is inferred from the cross builds.

Older metadata/link/SDK/loader PowerShell regressions still assume raw NXP/DLL
pairs. Their cases remain for the planned nxtest migration; they were not run or
counted as passes here. New storage regressions are in the existing nxtest suites.

### Size and timing comparison

The same Win64 foundation and metadata were built in both storage modes:

| Measurement | Embedded | Split |
| --- | ---: | ---: |
| Native `.nxpl` bytes | 4,154,368 | 2,134,528 |
| `.nxp` sidecar bytes | 0 | 2,020,021 |
| Total development distribution bytes | 4,154,368 | 4,154,549 |
| Median foundation build time | 5.204 s | 4.365 s |
| Median source-free consumer compile time | 2.486 s | 1.726 s |

Raw compiler metadata was 8,178,400 bytes; its compressed stream was 2,019,981
bytes (about 75.3% smaller). The sidecar adds a 40-byte envelope. The 181-byte
total-size difference between modes is native section alignment.

Timing used one warmup per mode, then three alternating-order samples. Consumer
compilation used `-Cn` to measure metadata consumption without native linking.
These samples are noisy: embedded foundation builds ranged 4.730–28.120 seconds,
split builds 4.282–4.993 seconds; consumer compiles ranged 0.936–4.686 and
0.973–2.570 seconds respectively. They do not establish a reliable placement
performance advantage. Both modes use exactly the same compression/decoding.
Split storage saves approximately 2 MB when shipping only runtime artifacts;
embedding keeps those bytes in the runtime image and gives a single development
artifact.

### Validation outputs

All source changes and this report belong in the repositories. Disposable logs,
measurements and isolated binaries are under `output/package-storage-check/`.
The exact verified SDK is under
`output/package-storage-check/bootstrap/tools/nexus-fpc/build/forge-bootstrap/package-sdk/`.
Isolated Nexus tools are under `C:/gitdev/nexus/output/NexusForgePackageStorage/`
and `C:/gitdev/nexus/output/nxbuild-package-storage/`; normal installed outputs
were not replaced. Rebuild the usual tools and SDK before evaluating the option
through their normal locations.

The Nexus source checkpoint is
`output/package-storage-check/checkpoint/nexus-package-storage-source.zip`.
The repository archiver completed source staging but stalled while traversing
existing recursive junctions in `Nexus/output` to collect test artifacts. Only
that archive process was stopped; its staged sources were compressed and its
temporary staging directory removed. The two affected `.nxproject` descriptions
were included explicitly because the existing filter omits that extension.
This checkpoint contains Nexus sources, not the sibling NexusFPC repository or
generated test artifacts. The archive script was not changed.
