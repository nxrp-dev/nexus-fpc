# Native CompilerUtilsTests

From the Nexus root, build this suite with Nexus nxbuild and NexusFPC:

```sh
nxbuild /action=build /project=../nexus-fpc/tests/utils/unittests/CompilerUtilsTests.nxproject
```

The runner registers this owner's tests directly with nxtest. Configure the
matching compiler and RTL in Nexus `projects/nxbuild/nxbuild.environment.nxscript`.
No FPCUnit bridge or external test discovery is involved.

Run `CompilerUtilsTests` from its output directory.
