# Native RTLObjPasTests

From the Nexus root, build this suite with Nexus nxbuild and NexusFPC:

```sh
nxbuild /action=build /project=../nexus-fpc/packages/rtl-objpas/tests/RTLObjPasTests.nxproject
```

The runner registers this owner's tests directly with nxtest. Configure the
matching compiler and RTL in Nexus `projects/nxbuild/nxbuild.environment.nxscript`.
No FPCUnit bridge or external test discovery is involved.

Run `RTLObjPasTests` from its output directory.

Use a compiler/RTL pair built from current NexusFPC source. The old SDK
installed during migration predates the CRC32 operand-width correction.
