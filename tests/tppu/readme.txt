Test suite for running the compiler, building ppus, running again, checking what ppus were build.

How to use:
- Build the compiler through Forge; see ../../NXPC.Forge.md.
- Compile this testsuite's testppu.lpr with a matching NexusFPC compiler and RTL.
- Run this testsuite:
  Set environment variable PP to the compiler and run all tests:
    PP=../../compiler/x86_64/pp ./testppu

Or run a single test:

PP=../../compiler/x86_64/pp ./testppu --suite=TestImplInline1

