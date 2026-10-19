# Scanner replay snapshot clears its input

`NXScannerReplayTests.lpr` is an NXTest regression. The case
`Compiler.Scanner.Replay.WideInputSurvivesSnapshot` creates a replay snapshot
from the two-character wide string `AB`. The caller's length and contents must
remain unchanged. Success requires exit status zero; the defect is not marked
as an expected failure or skipped.

`TReplayStack.Create` initializes its saved wide string empty, then calls
`CopyWideString(saved, input)`. `WideStr.CopyWideString` takes source first and
destination second. This clears the caller's string instead of saving it.
The naming pass preserves that call order. The same input-clearing behavior
was reproduced with the compiler-unit closures from naming batches 074 and
075. That establishes that batch 075 did not introduce this behavior; the
historical introducing change has not been established. No behavior fix is
included in this naming work.

The initial single-case NXTest program compiled successfully against both closures
and reported `0 passed; 1 failed; 0 errors; 0 skipped`, exiting with status 1. The
failure is the assertion that the caller's length remains 2 (it becomes 0).

Build the checked-in test with one bootstrap's matching compiler, native RTL,
compiler units and the sibling Nexus NXTest sources. Put outputs in a unique
directory under the development worktree:

```sh
"$compiler" -n -O2 -Aas-clang -XLL "-Fu$rtl" "-Fu$compiler_units" \
  "-Fu$nxtest_sources" "-FU$out" "-FE$out" \
  tests/compiler-regressions/NXScannerReplayTests.lpr
"$out/NXScannerReplayTests"
```

`compiler_units` names `cycle3/compiler-units` from the same bootstrap;
`nxtest_sources` names `nexus/packages/nexus-packages/nxtest/src`.

## Message count truncation during replay

`Compiler.Scanner.Replay.MessageCounts.Messages255` and `Messages256` record
255 or 256 changes to the same message state through the real Scanner writer,
then replay the resulting buffer. Both must restore the newest state once,
consume the entire buffer, and preserve the following semicolon token.
The repeated changes exercise the intended deduplication behavior.

The 255-record case passes. The 256-record case fails: no state is restored.
The recorded count and replay count variable are `asizeint`, but the replay
loop counter is `Byte`. Its loop bound truncates 256 to zero, leaving the
message records unread and interpreting their bytes as subsequent tokens.
The reproducer uses a semicolon-valued message key so those unread bytes
remain harmless while the test reports the lost state.

Both cases were compiled from this checked-in NXTest source against the
batch 075 and 076 compiler-unit closures. Both runs report
`1 passed; 2 failed; 0 errors; 0 skipped`: the earlier wide-string case and
the 256-record case fail. Expected success remains unchanged. This establishes
the defect before batch 077; its historical introducing change is unknown.
The naming pass retains the counter's `Byte` type and includes no repair.
