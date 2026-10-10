# Dynamic packages: approved runtime contract for items 6-10

Date: 2026-10-09
Status: explicit startup activation approved, implemented, and validated on 2026-10-09.

Items 12-14 and 16 extend this historical milestone with the approved
[load/unload contract](nexusfpc-dynamic-packages-load-unload-design.md).
Current artifacts use PCP v4 and descriptor v2 (21 native words, 168 bytes on
Win64), appending SDK, package build and required-build identities. The stable
`FPC_PACKAGE_INFO` export contains a pointer to the descriptor. The context
remains six native words. Shared Classes and TypInfo now belong to nxrtl.
Startup owners remain pinned; successfully unloaded late owners are removed.
The low-level caller-mapped API retains its original exception semantics;
LoadPackage wraps diagnostics before releasing package-defined exception images.
The limitations below describe items 6-10 at their completion, not the later
loader implementation. Item 15 remains excluded.

The [Linux x86-64/glibc implementation](nexusfpc-dynamic-packages-linux.md) reuses
this explicit activation and synchronous lifetime contract. Its ELF/glibc adapters
and tests are documented separately; the original Win64 milestone below remains
historical context.

## Completion boundary

The experimental EXE now links and runs against a package-owned System using
explicit startup activation. Items 6-10 establish a tested shared RTL foundation. They do not
complete general late loading, unloading, registration cleanup, or package TLS
support for multiple threads (items 12-15).

The acceptance test for item 10 requires a real Pascal EXE. Its minimal startup
integration overlaps item 11 and belongs in this milestone so that success is
demonstrated by an application, not only calls from Python into uninitialized DLLs.
Final validation includes a fresh full native/cross bootstrap of the completed
runtime changes.

## Ownership and startup

1. A foundational package owns System, ObjPas, SysUtils, and their required unit
   closure. Every participating package and EXE imports those units from that
   same provider. Per-image startup and native resources remain image-owned.
2. Each image supplies an immutable, versioned descriptor and a separate mutable
   module context. Process-wide RTL services belong to shared System. Registering
   another image must not replace the host's entry information or resource handle.
3. The Windows DLL entry point records only its native module handle and returns.
   It does not run Pascal unit initialization, load dependencies, or allocate an
   activation registry. Compiler-generated host startup performs explicit RTL
   bootstrap and package activation after Windows has mapped the dependencies.
4. Activation is sequential. Dependencies initialize before dependents; each
   owner's units initialize once. The host's own units initialize after its
   package dependencies. Shutdown reverses that order, with shared RTL last.
5. The runtime tracks progress per module. Failed initialization finalizes only
   completed units and newly activated dependencies from that attempt, in reverse
   order. Dependencies active before the attempt stay active. The original
   initialization exception remains the reported failure.

The main tradeoff is item 3. Explicit activation gives Pascal startup control over
ordering, typed failure reporting, and rollback. Native LoadLibrary by itself
would map a package without activating it; the later LoadPackage API must perform
activation before returning to callers. Initializing inside DLL_PROCESS_ATTACH
would make native loading immediately activate packages, but would run arbitrary
Pascal initialization under the Windows loader lock. Microsoft documents these
restrictions and recommends minimal DLL entry-point work:
[DllMain](https://learn.microsoft.com/en-us/windows/win32/dlls/dllmain).

No worker threads, asynchronous lifecycle, parallel compilation, or new locking
scheme were added. Existing RTL storage associated with the main thread still
has to work: the heap and exception machinery use it even in a single-threaded
application. Any need to redesign the threading/TLS mechanism is a separate joint
design decision, not permission to implement backlog item 15.

## Descriptor and context contract

The compiler and RTL share a precisely checked native layout. The descriptor
contains a magic value, byte size, format version, target/compiler/RTL compatibility
identity, canonical package identity, direct dependencies, owned unit identities,
and references to the owner's lifecycle, resource, and existing TLS metadata.
Version 1 occupies 18 native words (144 bytes on Win64). Metadata uses native-word
scalar fields, native pointers, counted tables, and
unmanaged names; reading it must not require a working Pascal heap or unit init.
The descriptor is retained under smart linking and available through a stable
export. PCP v3 remains the compile-time container; this is a separate runtime ABI.
Compiler identity combines the compiler version and PPU long version; RTL identity
is the System PPU checksum. Registration rejects disagreement with registered
owners. These fields are preliminary compatibility checks, not complete artifact
fingerprints. Full mixed-build compatibility enforcement remains item 16; tests
use one matching compiler and RTL build.

The mutable context occupies six native words: descriptor pointer, lifecycle state,
completed initialization count, native handle, previous-active link, and registry
link. Image-specific table pointers remain in the descriptor.
Its lifetime is the image lifetime. Registration and activation are distinct:
registering or inspecting a descriptor must not execute Pascal unit initialization.
This milestone needs activation bookkeeping and rollback, not general operating
system library-reference management or automatic detection of live objects.

## Source changes and checks

| Item | Concrete work | Required evidence |
|---|---|---|
| 6 | Extend symbol checks to real managed values, class allocation, resources, and typed exceptions using the shared RTL. | Allocate in either image and release in the other; preserve values; catch the declared exception type across the boundary; test fresh/cached and smart-linked artifacts. |
| 7 | Emit and export the descriptor from the package compiler; define its matching RTL layout and add an inspector. | Read identities, dependencies, owned units, version and table pointers without running initialization; verify layout and smart-link retention. |
| 8 | Add explicit module contexts and registration without replacing shared process entry state. | Two contexts retain distinct handles, tables and progress; ordinary EXE/DLL behavior remains covered. |
| 9 | Emit owner-only lifecycle tables and implement sequential dependency activation, finalization and rollback. | A real diamond initializes once, finalizes in reverse order, and survives an injected initialization failure without disturbing an already active dependency. |
| 10 | Build the foundational shared RTL, provide matching per-image startup objects, and integrate the minimal EXE startup path. | The EXE links and runs with one System owner; shared class/exception/global identity agrees; managed ownership crosses images safely. |

Relevant source boundaries:

- `compiler/pmodules.pas`: package emission and executable startup selection.
- `compiler/ngenutil.pas`: owner-only lifecycle, resource, and main-thread storage tables.
- `compiler/symcreat.pas`: package entry records the native handle and returns.
- `rtl/inc/system.inc`: optional Win64 lifecycle hooks; ordinary startup keeps its existing path.
- `rtl/inc/fpcpackage.pp`: registration, activation, rollback, and finalization.
- `rtl/win64/sysinitpkg.pp`: package-aware EXE startup and the EXE resource-handle adapter.
- `rtl/win64/system.pp`: explicit heap/bootstrap preparation before activation.
- `tests/dynamic-packages`: isolated compiler/RTL/package build and end-to-end tests.

Production package capability remains disabled after this experimental milestone.
No unrelated cleanup or changes to the removed `nexus/` experiment are included.
Any failed acceptance test is reported with the exact failure before choosing to
change the test contract or the implementation.

## Implemented scope and remaining boundaries

The isolated runtime runner builds its own package-enabled compiler and matching
RTL. It constructs `nxrtl.ppk` containing FPCPackage and its implicit System,
ObjPas, SysUtils dependency closure. It compiles SysInitPkg against that provider
before linking the EXE. This is the reproducible experimental build recipe;
ordinary installation/build rules do not publish package-enabled RTL artifacts.

Item 11 adds a reusable [PowerShell SDK workflow](examples/dynamic-packages/README.md).
It builds the dedicated `ppcpkg` entry point, matching RTL, checked-in `nxrtl.ppk`,
and per-image startup adapters into a separate directory. Both console and GUI
hosts use the existing approved startup sequence. Consumers need the distributed
compiler, startup units and PCP/DLL pairs; the original source/build tree is not
part of that build contract. Production target flags and ordinary bootstrap
outputs remain separate.

Startup gathers every owner's existing main-thread storage and resource-string
tables before the existing RTL storage setup. It does not change that mechanism
or create threads. An otherwise unused contained unit is covered by the runtime
test. General late-loaded TLS, existing/new thread support, and teardown remain
item 15 and require joint design.

Rollback finalizes completed unit prefixes, continues through cleanup exceptions,
and preserves the original initialization exception. A normal shutdown exception
propagates with progress retained; a subsequent finalization call resumes without
repeating completed callbacks. Registered images and their descriptors must stay
mapped for the process lifetime. This milestone does not remove registrations or
manage native loader reference counts after a failed activation.

Resource tests cover resource strings, initialized wide-string constants, and the
EXE's native resource-handle adapter. General package-owned native resource lookup,
class/RTTI registry removal, safe unload, late-load dependency acquisition, generic
specialization ownership, and full binary compatibility remain follow-on work.
PCP v3 and PPU v208/long 33 layouts are unchanged; the new System declarations
require matching rebuilt RTL units, as used by the test runner.

## Definition of a known-good milestone

The milestone is complete only when the ordinary build checks and the real EXE
package tests pass together: descriptor inspection, independent contexts,
initialization/finalization order, rollback, shared identity, managed values,
typed exception unwinding, profiler smoke, and the full retained cross-build
matrix. Passing these tests establishes this scoped experimental Win64 contract;
it does not imply that LoadPackage/UnloadPackage or all BPL behavior is implemented.

The completed milestone passed 99 runtime steps, 70 metadata steps, 27 link checks,
32 ordinary export checks, profiler smoke, and 27 top-level full-bootstrap steps
covering all 13 retained RTL targets. See the [gap-analysis results](nexusfpc-dynamic-packages-gap-analysis.md#implementation-results-items-6-10)
for exact log locations and remaining scope.
