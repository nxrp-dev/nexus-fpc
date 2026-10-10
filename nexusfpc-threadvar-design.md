# Unified threadvar storage

Approved direction: option 6, one storage and access model. Option 10's legacy
storage path is not retained. Compiler, RTL, units and packages must be rebuilt
together; compatibility with previous binary layouts is not a requirement.

Each native image owns one descriptor and a layout assembled from its owned
units. A variable descriptor contains its image owner and byte offset. The
compiler always calls the same resolver. Each execution context has an indexed
directory of separately allocated image blocks. Growing that directory never
moves variable storage. Package imports reference the provider's descriptors.

The main context uses the same representation before and after installation of
an existing platform thread manager. Bootstrap allocation uses OS memory APIs;
it must not call the Pascal heap or require exception threadvars. Existing thread
managers supply context selection and existing thread entry/exit callbacks.
No worker, asynchronous package operation or new locking scheme is introduced.

Package initialization registers storage before calling unit initialization.
Finalization retains it through unit finalization and cleanup. Successful unload
releases storage before unmapping its descriptors. Failed cleanup retains the
image and its storage. Reload gets a fresh runtime identity and zeroed storage.
Application pointers into an unloaded package remain the caller's responsibility.

Concurrent package lifecycle and cleanup on other live threads remain outside
this pass. TLS-bearing lifecycle operations must fail before mutation when they
cannot meet the supported synchronous ownership contract. This restriction must
not require a separate main-thread storage format.

Validation must cover ordinary programs, shared-RTL startup and late packages,
provider/consumer identity, alignment, address stability, rollback, reload,
existing thread-manager adapters, and native/bootstrap cross-target builds.
Performance claims require measured steady-state and application comparisons.

## Implemented ABI and build rules

- Threadvar symbols hold two native words: owner pointer and byte offset.
- Each image has a private five-word owner: tables, identity, size, alignment,
  and a debugger pointer to its existing main-context block.
- Unit table entries hold descriptor pointer, size and alignment. Imported
  threadvars retain the provider's descriptor and therefore its storage identity.
- `fpc_threadvar_addr` resolves every supported target through the common model.
  Existing Windows TLS and Unix pthread keys select the current context.
- The long PPU version is 34 and the package descriptor version is 3. Old units,
  SDKs, packages and applications must be rebuilt. The PCP format remains v4.
- The canonical bootstrap first compiles a seed compiler against the installed
  FPC 3.2.2 RTL, then uses it for the normal compiler/RTL cycle. This is a build
  dependency ordering change; no old runtime storage ABI is retained.

## Deliberate limits and costs

Late activation and unloading of images containing threadvars require
`IsMultiThread=False`. The package loader rejects unsupported operations before
changing lifecycle state or references. This flag normally stays true after a
worker exits, so merely joining workers does not re-enable these operations.
Applications must not reset it to evade the restriction. Startup packages remain
usable through existing thread managers; coordinating package lifecycle across
live threads is deferred.

Each context keeps an indexed directory and allocates an aligned block on first
access to an image. Startup and late images have identical storage. Resolving an
address costs a runtime call and indirection; application impact needs workload
measurement. Windows x86-64 retains direct TEB access to its existing TLS key.

Successful unload frees the current context's image block. Owner identities are
not reused, including when a native loader reference keeps the image mapped, so
directory capacity reflects the number of historical activations. This trades
some long-running reload memory overhead for simple, unambiguous identities.

Managed values still require appropriate application/package cleanup; unloading
does not discover outstanding objects, callbacks or pointers. Failed lifecycle
cleanup retains the image and storage. Bootstrap allocation failure terminates
with code 226 because exception creation could re-enter threadvar resolution.

DWARF describes values in the main context, preserving the earlier debugger
scope. STABS omits threadvar locations instead of treating descriptors as values.
Thread-aware debugger support remains separate work.

## Validation and measured cost (2026-10-10)

Evidence is under `output/threadvar-unified/`; Linux artifacts are under
`/var/tmp/nx-threadvar-*` in the Ubuntu WSL distribution.

| Check | Result |
| --- | --- |
| Windows package loader | 49 checks passed (`win-loader-final`) |
| Windows package runtime | 99 checks passed, including normal/smart and fresh/source-hidden cached units (`win-runtime-final`) |
| Linux package runtime | 98 checks passed with smart linking and source-hidden cached units (`nx-threadvar-linux-final`) |
| New threadvar package regression | Passed on Windows and Linux: startup owner, 24 late owners, directory growth, stable addresses, imported identity, 32-byte alignment, managed strings, rollback and reload |
| Native reference held across managed unload/reload | Passed on both platforms; reactivation sees fresh storage while the native image remains mapped |
| Multithreaded lifecycle rejection | Windows state-guard tests passed without creating workers; rejected operations preserve usable package state |
| Ordinary `tthread1` and `theapthread` | Built and ran successfully on Windows and Linux |
| Win64/LLD contracts | 51 steps passed, including existing foreign-thread DLL use, load/unload, normal/smart linking and valid/invalid pointer checks (`win-contracts-final`) |
| DWARF | GDB read scalar value 1234 and record field 5678 correctly (`debug-final/gdb.log`) |
| Linux `CheckPointer` regression | Reproduced error 204 with the Windows-only check; passed after moving threadvar recognition into the common path (`linux-pointer-before.log`, `linux-pointer-after.log`) |
| Final ordinary pointer regression | Passed on Win32, Win64 and x86-64 Linux (`win32-pointer-final`, `win-pointer-final`, `linux-pointer-final.log`) |
| Full bootstrap and retained RTL matrix | Passed all 13 targets, Linux FmtBCD and isolated `-CfNONE` HeapTrc (`bootstrap-logs/20261010-031524-ad424e3d`) |

The full native bootstrap passed, including its switch-removal checks. It used
the detached source snapshot in `bootstrap-tree`, leaving the working checkout's
installed compiler artifacts untouched. The final common `heaptrc` correction
was rebuilt explicitly before the Win64 contracts and Linux pointer regression.
The matrix refreshed System and HeapTrc for i386 Linux/Win32; x86-64 Linux,
Win64, Darwin, iPhone simulator and Android; and AArch64 Linux, Win64, Darwin,
iPhone simulator, iOS and Android. The native bootstrap recorded 14 warning
lines about package dependency cycles and the absent `winmanutf8lfn` source;
see its `warnings.txt`. These were not fatal failures.

Runtime execution was verified on Windows and x86-64 glibc Linux. Cross-target
compilation is not runtime validation on Apple, Android or ARM64 devices, nor
does it enable package runtimes on those targets. The package stress suite is
sequential; ordinary thread and foreign-thread tests exercise the existing
adapters, not concurrent package lifecycle.

Use this repository's `scripts/Invoke-NexusFPCBootstrap.ps1` for the required
seed-first rebuild. The separate legacy helper at
`C:\gitdev\nexus\repo-automation\Invoke-NexusFPCBootstrap.ps1` still uses the older
direct bootstrap flow and was not changed in this repository task; callers of
that helper need to switch to the updated entry point. Rebuild SDKs and product
binaries together. Validation did not replace the working checkout's previously
installed compiler binaries.

The final Win64 microbenchmark uses the ordinary baseline compiler/RTL and the
new ordinary bootstrapped compiler/RTL, both with `-O2`. It alternates five samples
of 100 million operations, uses QueryPerformanceCounter, and verifies the final
counter value. Commands and artifact hashes are in `benchmark-final/results.json`.

| Workload | Baseline median | Unified median |
| --- | ---: | ---: |
| Increment directly in a loop | 150.027 ms | 149.659 ms |
| Call a small procedure that increments a threadvar | 340.652 ms | 905.715 ms |

The latter measures approximately 3.4 versus 9.1 ns per iteration, or 5.7 ns of
additional cost in this very small workload (about 2.7 times its previous time).
This is a real local microbenchmark regression, not evidence of a 2.7-times
application slowdown. The direct loop reuses a resolved address. No representative
application benchmark has been run, and no previous-storage fallback was added
to hide the cost. Further optimization should preserve the unified model.
