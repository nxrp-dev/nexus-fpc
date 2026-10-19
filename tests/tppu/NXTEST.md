# Native CompilerRecompileTests

From the Nexus root, build this suite with Nexus nxbuild and NexusFPC:

```sh
nxbuild /action=build /project=../nexus-fpc/tests/tppu/CompilerRecompileTests.nxproject
```

The runner registers this owner's tests directly with nxtest. Configure the
matching compiler and RTL in Nexus `projects/nxbuild/nxbuild.environment.nxscript`.
No FPCUnit bridge or external test discovery is involved.

Build `packages/rtl-objpas/tests/RTLObjPasTests.nxproject` first. Its output
provides precompiled Variants, so dependencies are not counted as fixture
recompilations. On Linux, run the local `RunTests.py` helper:

```sh
python3 ../nexus-fpc/tests/tppu/RunTests.py --program output/nexus-fpc-tests/x86_64-linux/compiler-ppu/CompilerRecompileTests --compiler /path/to/sdk/bin/ppcx64 --rtl /path/to/sdk/units/x86_64-linux/rtl --runtime-units output/nexus-fpc-tests/x86_64-linux/rtl-objpas
```

The helper copies fixtures into the runner output directory and configures
the tested compiler explicitly. Its missing-system case deliberately receives
no RTL path. Tests never write into the source fixtures.

Suite ownership, output paths, consolidation decisions and explicit skips are
listed in [the central nxtest guide](../NXTEST.md).
