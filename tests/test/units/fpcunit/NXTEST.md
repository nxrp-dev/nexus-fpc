# Native RTLCollectionsTests

From the Nexus root, build this suite with Nexus nxbuild and NexusFPC:

```sh
nxbuild /action=build /project=../nexus-fpc/tests/test/units/fpcunit/RTLCollectionsTests.nxproject
```

The runner registers this owner's tests directly with nxtest. Configure the
matching compiler and RTL in Nexus `projects/nxbuild/nxbuild.environment.nxscript`.
No FPCUnit bridge or external test discovery is involved.

Run `RTLCollectionsTests` from its output directory.

Suite ownership, output paths, consolidation decisions and explicit skips are
listed in [the central nxtest guide](../../../NXTEST.md).
