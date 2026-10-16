# Native HashTests

From the Nexus root, build this suite with Nexus nxbuild and NexusFPC:

```sh
nxbuild /action=build /project=../nexus-fpc/packages/hash/tests/HashTests.nxproject
```

The runner registers this owner's tests directly with nxtest. Configure the
matching compiler and RTL in Nexus `projects/nxbuild/nxbuild.environment.nxscript`.
No FPCUnit bridge or external test discovery is involved.

Run `HashTests` from its output directory.
