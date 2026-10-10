# Dynamic packages: load/unload implementation and tradeoffs

2026-10-10 update: the [unified threadvar design](nexusfpc-threadvar-design.md)
supersedes the earlier late-TLS rejection and unchanged-PPU statements below.
Startup and late images use one model. Rebuild all artifacts for descriptor v3
and PPU long version 34. Coordinating package lifecycle across live threads is
still deferred; TLS-bearing load/unload requires `IsMultiThread=False`.


Status: implemented and validated on 2026-10-09. User
approved the recommendations for items 12-14 and 16, with remaining mechanical
decisions delegated. Item 15 is excluded.

## Accepted contract

- Experimental Win64, one shared startup RTL, synchronous lifecycle operations.
- `SysUtils.LoadPackage`/`UnloadPackage`, native handles and shared `EPackageError`.
- Shared contracts and exported factories for genuinely late-loaded implementations.
- Shared Classes/TypInfo in nxrtl; startup owners stay pinned until process exit.
- Explicit load references and dependency retention; the caller releases live
  objects/interfaces/callbacks before unload and does not call FreeLibrary directly.
- Reject newly introduced TLS storage and nested lifecycle-changing operations.
- Check SDK, package and dependency build identities before user initialization.
- Convert load failures to an RTL-owned diagnostic before releasing original images.
- Retain failed images/dependencies when finalization or rollback cleanup fails.
- Remove image-owned RTL registrations/resources/caches before native release.
- Publish completed artifact generations; failed builds retain the previous generation.

## Tradeoffs to discuss after validation

| Decision | Consequence relative to alternatives |
| --- | --- |
| Reject new late-loaded TLS | Packages declaring new threadvars cannot be late-loaded; startup-linked use remains available. No threading/TLS redesign is included. |
| Reject nested lifecycle calls | Initialization/finalization cannot dynamically load/unload other packages; declare dependencies or operate from host code. |
| One active image per package identity | No simultaneous versions or live replacement. Clean unload/reload is supported. |
| Caller-owned live-reference discipline | Reference counts cannot detect arbitrary Pascal objects, interfaces or callbacks retained by application code. |
| Shared Classes/TypInfo in nxrtl | Larger foundation; avoids another registry-owner lifetime and identity boundary. |
| Shared loader exception type | Load failures retain diagnostic class/message information but do not preserve the package-specific exception object/type or original raise stack. Ordinary calls retain typed exceptions. |
| Retain images after cleanup failure | Memory/native mappings can remain until exit; avoids unmapping potentially referenced code. Failed images cannot be reused. |
| Strict SDK/build identities | Independently rebuilt SDKs and package generations require matching rebuilt consumers. Experimental package metadata/descriptor versions change; ordinary PPU format remains unchanged. |
| Explicit loader search directories | No implicit current-directory/PATH fallback. Modern Windows loader search support is required. |
| Immutable publication generations | More disk use; callers follow the selected completed generation instead of assuming mutable loose files. |
| Registration owner follows retained addresses | RTL cleanup covers references into the image, not arbitrary application state. Global procedure-variable assignments can be cleared but previous values require application restoration. |
| Early startup diagnostics use native output | Incompatible startup images exit with code 217 before RTL text I/O or user initialization. Diagnostics go to stderr and debugger output; a GUI application needs captured output or a debugger to read them. |
| Matching ObjFPC SDK contract | This pass does not promise Delphi-produced BPL loading or arbitrary text-model/compiler-option combinations. More permissive ABI compatibility would require a separate explicit policy. |
| Sequential bundle publication | Concurrent publishers to the same output directory are not coordinated. Use a single build owner or separate output directories. |

## Implementation details

- `rtl/inc/fpcpackageloader.inc` implements native holds, explicit/dependency refs,
  startup pinning, activation, rollback, finalization and release. Original load
  exceptions are destroyed before native release. Failed cleanup retains mappings
  and dependencies and prevents reuse. Resource-table allocation is prepared
  before removing owners; bookkeeping is allocated before acquiring native holds.
- Classes owns component/lookup/integer-conversion registries and restores earlier
  component initialization handlers when an overriding package unloads. TypInfo
  removes enum aliases by image; its attribute creation API has no shared attribute
  cache, so returned attribute objects remain the caller's responsibility.
- Compiler resource collection now excludes imported package owners. Without that
  correction, a consumer tried to read its provider's native `.res` file. A real
  package-native resource and lookup regression cover this case.
- PCP v4 records SDK/package/required-build IDs; runtime descriptor v2 appends the
  corresponding fields and occupies 168 bytes on Win64. The stable data export
  `FPC_PACKAGE_INFO` holds the descriptor pointer. Context layout and ordinary PPU
  layout remain unchanged. All experimental package artifacts need rebuilding.
- SDK Format 2 hashes compiler/foundation/startup artifacts and derives a strict
  identity from the built compiler, RTL sources and foundation link mode. The
  publication helper reads PE descriptors without loading code, compares them with
  PCP identities, checks dependency build IDs, and verifies bundle manifests.
- Publication writes complete `generation-<id>` directories and atomically changes
  `current.json`. Failed compiler/linker or validation steps retain the prior
  generation. Rebuild a changed provider and its consumers in a new output directory;
  retained generations and work directories are not automatically pruned.

No worker threads, asynchronous lifecycle or new synchronization were introduced.
Ordinary build target flags remain package-disabled. Unrelated concurrent edits
in `compiler/ncnv.pas`, `compiler/psub.pas`, `compiler/ptype.pas` and three deleted
`tests/tbs` files are preserved and are not attributed to this work.

The [Linux x86-64/glibc port](nexusfpc-dynamic-packages-linux.md) now uses this same
manager through native ELF/glibc adapters. That report records its separate
validation, SDK tools, and platform limitations.

## Validation on 2026-10-09

| Check | Result | Evidence directory |
| --- | --- | --- |
| Metadata serialization/ownership | 70 passed | `%TEMP%\nxpkg-link-phcz4ndi\metadata` |
| Package linking, fresh/cached and normal/smart | 28 suite steps passed, including the metadata invocation | `%TEMP%\nxpkg-link-phcz4ndi` |
| Shared RTL and low-level lifecycle | 99 passed | `%TEMP%\nxpkg-runtime-z32j0lcc` |
| Final normal late loader/publication | 49 passed | `%TEMP%\nxpkg-loader-r44xrs7p` |
| Final smart late loader/publication and SDK build | 50 passed | `%TEMP%\nxpkg-loader-vvmxhvlp` |
| Source-only SDK and relocation, normal/smart console/GUI | 19 passed | `%TEMP%\nxpkg-sdk-n8a3e5lg` |
| Full native bootstrap / cross matrix | Passed; all 13 RTL targets, Linux FmtBCD and heaptrc `-CfNONE` | `output\NexusFPCBootstrap\20261009-123924-f9084886` |
| Ordinary EXE/DLL, fresh/cached normal/smart | 32 passed on the fresh optimized compiler | `%TEMP%\nx-unit-exports-f8588f2c` |
| Profiler cache, including mixed-profile recompilation | 41 passed on the fresh optimized compiler | `%TEMP%\nx-profile-cache-byu95r9k` |
| Production compiler still rejects packages | Passed | Bootstrap directory, `production-package-check\compile.log` |

Each test directory contains commands and per-step logs. The normal SDK is at
`C:\temp\nxpkg-loader-final-normal`; the smart SDK is under its loader evidence
directory. Both SDKs also passed the startup-linked console/GUI examples.

The source-only SDK suite also passed 19 checks earlier in development
(`%TEMP%\nxpkg-sdk-yewhwerp`). An intervening rerun hit a 600-second compiler-build
timeout during concurrent filesystem work, without a compiler diagnostic.
The runner now allows 1800 seconds by default for SDK builds and exposes
`--build-timeout`; the successful final revalidation used 2400 seconds. This changes the build
time allowance, not expected compiler/application results.

The full bootstrap rebuilt the native compiler, RTL, packages and utilities and
passed its option/directive regressions. Its 14 nonfatal warnings exactly match
the preceding bootstrap: 13 dependency-cycle warnings and the existing missing
`winmanutf8lfn` source warning. Cross-target success proves compilation, not
execution of package runtimes on those platforms.

No planned validation remains failing. Work is uncommitted. Automatic approval
review rejected deletion of two generated Python cache files with "blocked by
policy"; they remain untracked under `tests/dynamic-packages/__pycache__`.
