# Native floating-point policy

Status: native arithmetic and the first cleanup were committed in `4236440c`.
The additional seed-compatibility cleanup below remains uncommitted for review.

## Decisions

- `Extended` uses x87 hardware binary80 on supported x86 targets, including
  Windows x86-64. Single and Double retain their existing formats.
- ARM `Extended` is Double. Compiler constant evaluation uses the compiler
  host's native `Extended`; there is no general software binary80 evaluator.
- Official x86 compilers are built on x86 hosts. Apple Silicon hosts build
  native/ARM tools, not the official x86 cross compilers. Phones are application
  targets, not compiler build hosts. Distributed desktop tools include the useful
  cross compilers so users need not build them on every target platform.
- Currency and Comp retain their existing representation and arithmetic.
  In particular, Win64 and ARM keep integer-backed Currency/Comp. Enabling
  Win64 Extended must not enable the old coupled x87 Currency/Comp option.
- Win64 `CExtended` remains Double for the Microsoft C ABI. Pascal Extended is
  a distinct, 10-byte type; interfaces exposing it require matching Nexus tools.
  C varargs lower Extended to Double with a warning; an explicit Double cast
  states that conversion at the call site. This boundary cannot carry binary80.
- Old binary/PPU compatibility is not a requirement. Rebuild the compiler, RTL,
  packages and consumers together. Keep the Nexus PPU identity distinct from
  upstream and advance its revision for the new contract.
- No product threads are introduced. Changes remain uncommitted for owner review.

## Consequences and retained fixes

Native constant folding follows native RTL mathematics and the platform's
floating-point behavior. Removing the software binary80/binary128 transcendental
engine gives up its additional full-range argument reduction and its independently
verified high-precision results for all 2,617 reference vectors. Those results
describe the preceding implementation, not a guarantee of this one. Ordinary
compiler regression tests remain unchanged; unusual transcendental inputs must
be characterized explicitly rather than given rewritten expected answers.
The former software core test has one ordinary behavior adjustment:
native `Frac(-1.0)` returns positive zero, whereas the software evaluator returned
negative zero. Literal negative zero and the other signed-zero core cases remain
tested. This is part of selecting native RTL behavior.
Existing i386 `Int(-0.75)` returns positive zero, whereas x86-64 returns negative
zero; the new core test records both existing native behaviors.

ARM-hosted compilation does not promise the extra precision of an x86 host.
This is an accepted consequence of a small supported host/target matrix. Shared
unit files must have an explicit target representation, not silently depend on
the compiler host's memory layout.
Readers on Double-only hosts reject x86 real payloads; inspecting those real
constants also requires a hardware80 host.

PPU real payloads are ten bytes for x86 targets and eight bytes for ARM targets.
NXU long revision 39 identifies the current contract. Revision 38 introduced the
Win64 ABI change; revision 39 removes the redundant real-width header byte and
native scalar Float128 entries.

The initial Windows bootstrap uses stock FPC 3.2.2 **i386-win32**, whose host
Extended already supports binary80. It builds an x86-hosted x64 seed, then the
new Win64 RTL and native Win64 compiler, before the ordinary self-hosting cycle.
Stock FPC 3.2.2 Win64 cannot parse the Extended-range constants in the new RTL.
Both the ordinary build and package SDK use one shared seed-building helper.
This changes the bootstrap prerequisite; the distributed compilers remain
native Win64 tools. No software arithmetic bootstrap is retained.

Validation used the unpacked
[official FPC 3.2.2 Win32 distribution](https://downloads.freepascal.org/fpc/dist/3.2.2/i386-win32/fpc-3.2.2.i386-win32.exe)
under `output/native-real/bootstrap-input/fpc32/app/bin/i386-win32`, passed as
`-BootstrapBin`. The installer was not run. Its SHA-256 is
`7EC78B1790ECAC7685F440B17F9E03865BC09846B7C068A9270C4D37704B5AC8`.
The script's normal default is `C:\lazarus\fpc\3.2.2\bin\i386-win32`; provide
that toolchain or an explicit path on a new machine.

Compiler Currency literals and System share the current integer decimal parser.
This also avoids a verified stock 3.2.2 Currency `Val` defect: some out-of-range
endpoint strings return success. The shared parser is compiled into the seed
from current source, independent of its installed bootstrap RTL.

Keep the independently useful Currency literal/range corrections and native
regression tests. The initial implementation also retained the optional RTL
software integer-rounding correction; its library and dedicated test are now
retired as recorded below. Historical measurements remain available.

Win64 C varargs coverage also exposed an existing internal error with floating
arguments beyond the register argument slots. The ABI describes these as 64-bit
integer slots; the compiler incorrectly requested an integer-sized SSE temporary.
The generic argument loader now selects the corresponding floating register
size. This reproduced with the preceding software evaluator as well. RTTI's
Comp-property conversion now explicitly rounds on integer-Comp targets, avoiding
an invalid Extended-to-Int64 typecast after Extended became a distinct type.

The newly enabled Win64 Extended Math routines also needed an ABI correction.
SinCos stored eight-byte values and used the Double overload's output registers.
ArcTan2, Tan, Cotan and Log2 assumed SysV stack offsets. They now use named
parameters with normal compiler-generated frames, and SinCos stores ten-byte
values through its named output parameters. This uses one implementation for
Win64 and SysV instead of maintaining separate argument-location branches.

The GNU Make 3.82 bundled with the stock Win32 compiler also exposed implicit
dependency lookups accepted by Make 3.80. Shared RTL make rules now use the
existing Unix include directory for errno and the common Unix DOS source.
Darwin explicitly identifies its BSD System source and Unix SysUtils/Classes
sources. Generated makefiles are refreshed from those rules; full dependency
checks cover Android, Darwin/iOS/simulator, Win32 and Windows ARM64.

## Verification

Validation used fresh Win64/Win32 compilers and RTL, the retained cross-target
matrix, original numeric regressions, normal and optimized grouped tests,
fresh/cached unit constants, Extended calling conventions and records, and
package/shared-RTL use. The final clean bootstrap starts from the documented
stock compiler, followed by checks against the resulting compiler and RTL.

The compiler/RTL source and make rules shrink by 578 lines net relative to the
preceding software evaluator, excluding PowerShell helpers, tests and documentation. The
dedicated real wrapper shrinks from 261 lines to 25; the 329-line transcendental
unit and 74-line reduction table are removed. At that stage, standalone RTL
software floating units remained as explicit libraries. Those APIs have since
been retired in the final cleanup recorded below.

Completed regression checks:

- All 680 consolidated group checks pass: 170 groups on Win32 and Win64, both
  normal and optimized. Win64 uses a complete rebuilt RTL with the Math fixes;
  validation inputs are isolated from bootstrap outputs that Make may replace.
- All seven unchanged original numeric fixtures pass with native Win32 and
  Win64-hosted Win32 compilers, normal and optimized: 28 original checks. The
  separate diagnostic probe passes in all four configurations too. All 16
  generated assembly files match byte for byte between hosts.
- The final bootstrapped compilers pass 42 Win64 and 34 Win32 focused
  compile/run/expected-diagnostic steps, covering core
  arithmetic, Currency ranges, the retained software integer-rounding fix,
  C callbacks/varargs, Extended calling conventions, Math ABI, RTTI and cached
  constants. All seven original Win32 fixtures and the diagnostic probe also
  pass again with the final bootstrapped cross compiler, normal and optimized.
- Win32 cached real PPUs are consumed and executed across the two compiler
  hosts in both directions, normal and optimized, without changing the PPUs.
- A Double-only host builds the AArch64 compiler and Linux RTL. Double-host and
  hardware80-host compilers consume each other's ARM PPUs; their test consumers
  generate identical machine code. These are compilation checks, not ARM execution.
- A fresh Win64 package SDK passes console and GUI lifecycle/ownership checks.
  A separate package DLL passes Extended parameters, results, callbacks, records
  and `var` parameters. Its shared RTL passes the new Math ABI check and the
  unchanged `tw1737`, `ttrig` and `twrstr8` cases.
- The clean, regenerated full bootstrap passes native self-hosting, packages,
  utilities, and all 13 retained RTL targets: i386 Windows/Linux; x86-64
  Windows/Linux/Android/macOS/iOS simulator; and AArch64
  Windows/Linux/Android/macOS/iOS/iOS simulator. Linux FmtBCD and isolated
  `-CfNONE` heaptrc checks pass too. The bootstrap records 14 warning lines:
  13 package dependency cycles and the existing missing `winmanutf8lfn` source.
- All 51 steps in the Win64/LLD contract suite pass with the final bootstrap,
  including foreign calls, DLL lifecycle, resources, unwinding and expected
  rejection diagnostics.
- All 70 changed compiler/RTL/package/build-script files match the isolated
  source used by the final bootstrap (line-ending differences ignored).

Final bootstrap evidence is under
`output/native-real/bootstrap-final/20261011-103806-3b6cd75f`.
The step/count index is `output/native-real/verification-summary.json`;
focused results are in `checks-final-win32`, `checks-final-win64` and
`win64-contracts-final` beneath `output/native-real`. Package validation uses
`package-sdk-final` and `package-real-matched`. These output directories are
ignored build evidence, not source to check in.

The unchanged 2,617-vector reference corpus records 665 native-math differences:
Sin 255, Cos 274, Ln 99, Exp 37, ArcTan 0. Of those, 154 differ by one significand
bit at the same exponent, and 189 Sin/Cos cases return their input beyond the
x87 instruction's reduction range. This is a real accuracy loss relative to the
retired software evaluator, not a passed exact-reference test.

Actual execution on ARM hosts and non-Windows targets is not verified here.
The initial native80 pass did not migrate the historical Windows package
harnesses. The cleanup pass below completes their PowerShell migration.

## Timings

The local comparison uses three matched compiler/RTL sets: the pre-correction
Double-based Win64 baseline, the preceding software80 implementation, and the
final native80 bootstrap. Trials alternate among the three compilers.
The constant-heavy workload has 50,000 real constant expressions (seven trials);
the broader workload rebuilds the same compiler source with `-B -O2` (three
trials). Results report median compiler-process CPU time; assembler/linker
child-process CPU time is excluded. Wall times and exact commands are also
recorded, but filesystem/tool startup effects make them noisier.

The compiler workload is a separate copy of the old baseline source. Four
floating-to-Comp casts are replaced by explicit Round calls in that common
fixture so all three compilers can build it. The old implicit casts are invalid
under the newly distinct Extended/integer-Comp combination. Those same four
edits apply to every measured build; the production source and original
regression fixtures are untouched by the benchmark preparation. The initial
unadjusted compiler timing attempt is excluded from the final comparison.

| Workload | Old Double baseline | Software80 | Native80 |
| --- | ---: | ---: | ---: |
| 50,000 real constant expressions | 421.875 ms | 671.875 ms | 453.125 ms |
| Common compiler-source rebuild | 12.984 s | 13.125 s | 12.641 s |

Native80 uses 32.6% less compiler CPU time than software80 on the constant-heavy
workload, and 7.4% more than the old Double baseline. The common compiler rebuild
uses about 3.7% less than software80 and 2.6% less than the old baseline. The
broader-workload differences are small; these local samples do not establish a
general performance guarantee.

Exact commands, per-trial CPU/wall measurements, and compile logs are under
`output/native-real/timing-common`; the runner is
`output/native-real/Measure-Common.ps1`. The common source fixture is in
`output/native-real/timing-source`. All 30 measured builds succeeded.

## Review checkpoint

The source changes are uncommitted. The root Nexus `ATTRIBUTIONS.md` also gains
the Boost reference-generator and temporary innoextract tool provenance; neither
dependency is shipped in the compiler. A verified source/patch archive and hash
manifest are saved in `output/native-real/checkpoints/native-real-source.zip`.
The previous software evaluator's source checkpoint remains available separately
under `output/numeric-repair/checkpoints` for comparison.

## Surrounding cleanup, items 1-5

The implementation uses stock FPC 3.2.2 i386-win32 as its seed. This changed the
prerequisite from the previously installed stock Win64 compiler; retaining the
same FPC version did not retain the same seed. The owner subsequently accepted
installing stock Win32 FPC. Pinning a new Nexus seed remains deferred. Both
ordinary bootstrap and SDK builds continue to
use the shared stock32-to-native64 helper; the tests no longer carry independent
stock-Win64 compiler build paths.

1. The x86 Pi, ArcTan, Ln, Sin and Cos first-pass hooks now directly select the
   x87 result location. Their fallback depended on an x86 best-real type that
   this policy no longer supports.
2. Compiler `entryreal`, `ppureal` and CPU-specific `ts32real`/`ts64real`/
   `ts80real`/`ts128real`/`ts64comp` aliases are gone. Consumers use Single,
   Double, Int64 or the shared `bestreal` definition directly.
3. Removed the unused real-byte swap function, the constant-pool swapped flag,
   the always-zero assembler swap mask and the redundant PPU real-width header
   byte/fields. Actual constant serialization still uses the target's 10-byte
   x86 or 8-byte ARM format. **NXU compatibility revision 39 requires rebuilding
   units and packages.**
4. Removed native scalar Float128 compiler/RTL scaffolding: the unused float
   kind, constant kind/storage/emission, FMA/min/max slots, classification/RTTI/
   mangling tables, helper predicate, Linux embedding branch and unsupported
   native-math declarations. Exhaustive switches now omit their dead fallback
   branches. The unused reverse float-size table is also gone.
5. Windows metadata, linking, runtime, SDK relocation, loader/publication,
   threadvar and timing runners use PowerShell. The main runner builds one SDK
   per link mode and shares it among suites. A separate native Pascal probe
   replaces Python DLL introspection. Coverage and individual commands are in
   [the test guide](tests/dynamic-packages/README.md).

Retained deliberately:

- `OS_F128` is still a live backend transfer size for SIMD/vector data, including
  four-Single aggregates. It is not a surviving native Pascal Float128 type.
- The explicit software-float units remained available in this earlier pass.
  The later retirement below removes those APIs and their conversion branches.
- `softfloat_rounding_mode` is used by integer-backed Currency rounding;
  software exception state remains in the ARM math path. Currency/Comp behavior,
  CExtended's foreign ABI distinction and x87/SSE controls remain as approved.
- Linux test orchestration remains separate from this Windows migration. Linux
  cross-compilation does not substitute for executing the Linux runtime suites.

The x87 accuracy/range limitations and reference differences recorded above are
unchanged by this cleanup.

### Cleanup validation

The final native bootstrap and all 13 retained cross-RTL targets pass from the
unchanged stock 3.2.2 Win32 seed. Makefiles were regenerated before validation.
The 14 native warning lines match the previous pass: 13 package dependency-cycle
warnings and the existing missing `winmanutf8lfn` source warning.

| Check | Passed |
| --- | ---: |
| Focused numeric, ABI, RTTI, PPU and expected-diagnostic steps | 42 Win64 + 34 Win32 |
| Original Win32 fixtures/probe, normal and optimized | 16 compile/run pairs |
| Win64/LLD contracts | 51 steps |
| Ordinary EXE/DLL exports | 32 steps |
| Package metadata | 71 steps |
| Package linking, fresh/cached and normal/smart | 28 steps |
| Shared RTL runtime, fresh/cached and normal/smart | 97 steps |
| Loader/publication | 49 normal + 49 smart steps |
| Sequential package threadvars | 29 normal + 29 smart steps |
| Source-only SDK construction and source-free console/GUI relocation | Normal and smart |
| Extended package ABI and shared-RTL Math regressions | Normal and smart |

The core cleanup changes 41 compiler/RTL files and removes 240 net lines compared
with the preceding native80 source snapshot. Current compiler/RTL/build-script
source matches the isolated bootstrap source. The 404 copied Windows compiler,
RTL and resource-tool artifacts used for execution checks match the completed
matrix build by SHA-256.

Evidence is under `output/native-real-cleanup`. The final bootstrap is
`bootstrap/20261011-113823-5ff2223e`; focused/ABI/export logs are in
`checks-win64`, `checks-win32`, `win64-contracts` and `unit-exports`.
Package evidence is split between the normal source-only workflow in
`packages-final`, its final loader/threadvar/math runs in `normal-final`, and
the smart source-only workflow and suites in `packages-smart`.
Initial compiler warning failures and harness-port failures remain in their
separate logs; they were corrected before the passing checks reported here.
No Python interpreter or product worker threads were used.

All **680 grouped configurations** pass: 170 fixtures, normal and optimized,
on each of Win64 and Win32. They use the immutable Windows validation snapshot.
The result files are `groups-x86_64-win64/results.json` and
`groups-i386-win32/results.json`.

The PowerShell timing runner also passes: three alternating samples per
configuration, 24 measurements, matching runtime checksums and equal 136,192-byte
fixture executables. This compares the previous native80 build to this cleanup,
not the older software80 implementation. Medians are process wall times:

| Workload | Previous native80 | Cleanup | Change |
| --- | ---: | ---: | ---: |
| Small fixture build | 308.1 ms | 289.2 ms | -6.1% |
| Compiler source rebuild | 19.354 s | 20.374 s | +5.3% |
| Global-data loop | 587.1 ms | 557.9 ms | -5.0% |
| Managed-value workload | 903.2 ms | 854.7 ms | -5.4% |

Three local samples are insufficient to establish a performance change.
Compiler-build ranges overlap substantially: 17.382-61.198 seconds before and
15.950-22.716 seconds after. Other validation jobs had finished before timing;
ordinary machine and filesystem variability remains. Raw samples, commands,
compiler/RTL hashes and summary statistics are in `timings/timings.json`.

The work is uncommitted. The current source/patch checkpoint is
`output/native-real-cleanup/checkpoints/native-real-cleanup-source.zip`; its
manifest includes the removed tracked harnesses and the prior pass's retired
software-evaluator files. The earlier checkpoints remain intact.

## Stock Win32 seed compatibility cleanup

The owner accepted stock FPC 3.2.2 Win32 as the initial bootstrap compiler and
approved removing obsolete compiler-version branches. This does not pin a new
Nexus seed or restore the retired software80 compiler evaluator.

The supported bootstrap boundary is explicit: stock `ppc386.exe` compiles the
current compiler against its installed Win32 RTL. The resulting compiler builds
our current Win64 RTL, then the native Win64 compiler and its self-hosting cycle.
The current RTL therefore does not need to compile directly with stock 3.2.x.
`systemh.inc` now reports this prerequisite explicitly if given an older compiler.

Removed the pre-2.7 compiler search-record alias and pre-3.x file-mask fallback.
Removed old RTL branches for string layouts, RTTI, dynamic-array copying, unsigned
`Val` helpers, enum input, atomic helper names, platform record alignment,
function references, and older compiler syntax/features. The cleanup also removes
now-unconditional local feature guards for RTTI attributes/invocation helpers,
Classes function references, managed moves, and VMT initialization.

Preserved the compiler's `VER3_2` `RTLString` declaration, the shared exact Currency
parser, the host-precision restrictions, and the stock32-to-native64 seed helper.
ARM keeps Double-based compiler arithmetic. Currency/Comp representations and
native x87/SSE controls are unchanged. NXU revision remains 39: the code selected
by current compilers and its artifact layout are unchanged.

### Pre-removal audit of the roughly 9,000-line SoftFloat library

This audit preceded the approved removal recorded below.

The large remaining file is `rtl/inc/softfpu.pas`, at 9,363 lines. It implements
software binary32, binary64, binary80, and binary128 arithmetic; it is not solely
the retired compiler software80 evaluator. Together with `sfpux80.pas`,
`sfpu128.pas`, `ufloatx80.pas`, and `ufloat128.pas`, the five units total 9,613 lines.
Their namespaced wrappers, build registration, and software-only conversion
branches add further removable material if these explicit APIs are retired.

A source search found no imports in `compiler`, `packages`, `utils`, or the Nexus
`packages` and `projects` trees. Remaining direct users are the RTL's build-unit
registration and tests (`tests/test/units/softfpu/sfttst.pas` and the focused
`tsoftinteger.pas` regression). The compiler and bootstrap no longer need them.

Retiring these units would remove the explicit software-arithmetic APIs,
including portable binary80/binary128 operations. That is a separate capability
removal, so this version-branch cleanup leaves them present. Ordinary native
Single/Double/Extended arithmetic would remain. The `softfloat_*` state in
`mathh.inc` must also remain: integer-backed Currency rounding and ARM exception
handling use that state independently of the arithmetic units. The shared
`flt_conv.inc`, `flt_core.inc`, and `flt_pack.inc` cannot be deleted wholesale;
System uses their native floating-point text conversion paths.

Audit evidence: `output/seed-compat-cleanup/softfloat-consumers.json`,
`softfloat-consumers-full.json` (also searching files excluded by VCS ignore
rules), and the source references above. The compiler's `SOFTFPU` feature-name
string is not a unit import. No external application dependency audit is implied.

### Validation of the seed compatibility cleanup

The cleanup removes 425 net lines across 48 compiler/RTL source files. No tests
were weakened or removed. Validation used `output/seed-compat-cleanup/source`,
starting from the extracted official stock Win32 3.2.2 distribution documented
above. All 48 modified sources exactly match the isolated build inputs.

- Clean native self-hosting, retained packages/utilities, and all 13 target RTL
  builds passed. Linux FmtBCD and isolated `-CfNONE` heaptrc checks passed. The
  native build retains the same 14 previously recorded warnings.
- All 680 grouped configurations passed: 170 fixtures, Win64/Win32, normal/O2.
- All 42 Win64 and 34 Win32 focused numeric/ABI/RTTI/PPU steps passed, as did the
  16 compile/run pairs for the original Win32 fixtures and diagnostic probe.
- All 51 Win64 contract steps and 32 executable/DLL export steps passed.
- The normal/smart SDK workflow passed all 34 steps, including source-only
  builds, static consumers, and source-free relocated console/GUI applications.
- Package metadata (71), linking (28), runtime (97), loader (49 per link mode),
  sequential threadvars (29 per link mode), and hard80/shared-RTL Math checks
  passed with fresh SDKs built from the stock Win32 seed.

The execution suites used separate copies of the Windows compiler/RTL artifacts.
All 404 artifacts were checked against the final matrix output. Five import
archives differ only in archive-member timestamps; their full contents match
after normalizing that timestamp field alone. All other artifacts match exactly.
Cross-target results are compilation checks; runtime execution was on Windows.

Evidence is under `output/seed-compat-cleanup`: the full build is
`bootstrap/20261011-135349-01d50347`, grouped and focused results are in
`groups-*` and `checks-*`, and package results are in `packages`. The summary is
`verification-summary.json`. The verified source/patch checkpoint is
`checkpoints/seed-compat-cleanup-source.zip`. Changes remain uncommitted.

## Retirement of the optional SoftFloat library

The owner approved removing the optional software arithmetic APIs after confirming
that stock FPC 3.2.2 Win32 provides hardware80 for the compiler bootstrap. The five
units (`softfpu`, `sfpux80`, `sfpu128`, `ufloatx80`, `ufloat128`), their namespaced
wrappers, RTL build registrations, and their two dedicated tests are removed.
The shared Grisu conversion includes now retain only native Single, Double and
Extended paths; the software conversion adapter and binary128 branches are gone.

System still owns native decimal conversion. Integer-backed Currency rounding
and ARM floating-point exception/rounding state remain, including the live
`softfloat_rounding_mode` variable. The compiler's `f_softfpu` feature marker also
remains: it describes System capabilities used by Variant debug metadata and is
not an import of the retired library. Native arithmetic, Currency/Comp storage,
the exact Currency parser, the bootstrap transition and NXU revision 39 are
unchanged. Standalone portable software arithmetic, including explicit binary128,
is no longer supplied.

This removal accounts for 11,497 net source/build/test lines, including the
9,613 lines in the five units and 717 net lines in the shared conversion includes.
The preceding 425-line seed compatibility cleanup is separate from this count.

### Validation after removal

Validation used `output/softfloat-retirement/source`, copied from existing
tracked sources with all twelve retired source/test files absent. The build
started from the extracted stock FPC 3.2.2 Win32 distribution, regenerated 39
Makefiles, and completed the stock32-to-native64 transition and self-hosting.
The six changed generated Makefiles were copied back into the working tree.

- Full native compiler, RTL, packages/utilities, all 13 target RTL builds,
  Linux FmtBCD and isolated `-CfNONE` heaptrc passed. The same 14 warnings
  match the preceding validated build exactly. Neither compiler stage nor any
  fresh target RTL output contains a retired SoftFloat unit.
- All 680 grouped configurations passed: 170 fixtures, Win64/Win32, normal/O2.
- All 38 Win64 and 30 Win32 focused numeric/ABI/RTTI/PPU steps passed, plus
  16 original Win32 compile/run pairs, 51 Win64 contract steps and 32 EXE/DLL
  export steps. Only the dedicated software-library tests were retired.
- Direct before/after comparison of the conversion includes passed for native
  Single, Double and Extended, normal/O2: 2,021 inputs and 22 formats per input,
  or 266,772 format/parse comparisons. Formatted text, parsed bits and error
  positions are identical. This includes boundary literals and generated bit
  patterns. Both sides used the same previously validated native compiler/RTL,
  isolating the source cleanup from other compiler changes.
- Both package SDK modes passed all 34 workflow steps, including fresh builds
  from stock Win32, static consumers, source-free relocation, console/GUI
  lifecycle checks and shared-RTL Extended/Math checks. Metadata (71), linking
  (28), runtime (97), loader (49 per mode) and sequential threadvars (29 per
  mode) also passed.

All 384 copied Windows compiler/RTL artifacts used for execution were checked
against the final build. Five import archives differ only in their member
timestamps; their contents match. All other artifacts match exactly. Runtime
execution was on Windows; the other platforms were cross-compilation checks.

Evidence is under `output/softfloat-retirement`: the build is
`bootstrap/20261011-161658-e936a136`, execution results are in `checks-*`,
`groups-*`, `packages`, `win64-contracts`, and `unit-exports`, and the direct
comparison is in `conversion-results.json`. `verification-summary.json` records
the totals. The source/patch checkpoint is
`checkpoints/softfloat-retirement-source.zip`. No new seed is pinned or installed;
the existing stock Win32 seed remains sufficient. Changes are uncommitted.

## Follow-up removal of obsolete helpers and precision branches

The owner approved the remaining cleanup after the optional library retirement.
This pass removes another 2,066 net source lines across seven files.
The unregistered `compiler/utils/ppuutils` layer (`ppuout`, `ppujson`, `ppuxml`)
is removed. No compiler, package, utility, script, test, or Nexus project source
consumer was found. This removes 1,993 lines, including the unused exporter's
inconsistent Float128 name table. The built PPU tools remain in place.

The generic trigonometric argument reducer now implements only its existing
mode 2. Its sole caller always selected that mode. The precision parameter,
initialization table, other compression branches, and their obsolete precision
documentation are removed. The arithmetic order, constants, and two output
components are preserved. Its three input slots remain necessary for splitting
a Double into 24-bit chunks.

The narrow `nf_internal` exemption for constant-to-structured-type casts in
`ncnv.pas` is removed with its retired SoftFloat producer. Internal conversion
call sites were traced through call lowering, Variant handling, array iteration,
inlining, and constant propagation. Live record/array casts of variables,
temporaries, and calls remain valid; dedicated string and set conversions retain
their own checks. The general internal-conversion flag and its other uses remain.
The stale FPU-control-word comment and the float-enum comment's obsolete include
filename are also corrected.

The remaining `softfloat_*` rounding/exception state has active Currency and
ARM64 consumers. The `f_softfpu` System feature flag, SoftFloat calling-convention
metadata, and external-format Float128 constants are separate from the retired
arithmetic library and are retained. This pass changes no native floating-point
representation, Currency/Comp storage, NXU revision, or seed requirement.

### Validation of the follow-up cleanup

The fresh isolated build under `output/softfloat-followup/source` starts from
stock FPC 3.2.2 Win32. The complete native bootstrap, self-hosting/WPO,
packages/utilities, all 13 target RTL builds, Linux FmtBCD, and `-CfNONE` heaptrc
passed. Its 14 native warnings exactly match the preceding validated build.

- All 680 grouped configurations passed: 170 fixtures, Win64/Win32, normal/O2.
- The 38 Win64 and 30 Win32 focused numeric/ABI/RTTI/PPU steps passed, along
  with all 16 original Win32 compile/run pairs, 51 Win64 contracts, and 32
  EXE/DLL export steps.
- Direct before/after execution of the extracted generic reducer produced
  identical octants and remainder bits for 240,986 inputs in each of normal
  and O2 builds: 481,972 comparisons. Cases include both signs, zero,
  subnormals, maximum finite values, infinities, NaNs, values around the
  reduction threshold and multiples of pi/2, and generated bit patterns.
- The normal/smart package SDK workflow passed all 34 steps. Metadata (71),
  linking (28), runtime (97), loader (49 per mode), sequential threadvars
  (29 per mode), and shared-RTL Extended/Math checks passed.

The 384 Windows compiler/RTL artifacts used for execution were compared with
the final matrix output. Five import archives differ only in member timestamps.
Three PPUs (`exeinfo`, `signals`, `strings`) differ only in the diagnostic source
column of the implicit `SYSTEM` unit symbol (1 versus 10): one byte per file.
The entry layout was checked against `tstoredsym.ppuwrite` and
`tcompilerppufile.putposinfo`; all other bytes, including checksums, match.
Their object files match exactly. Every other artifact is byte-identical.
Runtime execution was on Windows; other targets were cross-compilation checks.

Evidence is under `output/softfloat-followup`: the build is
`bootstrap/20261011-165049-db937c18`, the reducer comparison is in
`reducer-results.json`, and complete totals are in `verification-summary.json`.
The source/patch checkpoint is `checkpoints/softfloat-followup-source.zip`.
All 91 changed/deleted paths in the combined cleanup match the build inputs
(documentation excepted). Concurrent Forge files and its `.gitignore` edit
are excluded from this checkpoint and remain untouched. No new seed was pinned
or installed. Changes remain uncommitted.
