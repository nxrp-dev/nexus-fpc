# Native FCLHashTests

From the Nexus root, build this suite with Nexus nxbuild and NexusFPC:

```sh
nxbuild /action=build /project=../nexus-fpc/packages/fcl-hash/tests/FCLHashTests.nxproject
```

The runner registers this owner's tests directly with nxtest. Configure the
matching compiler and RTL in Nexus `projects/nxbuild/nxbuild.environment.nxscript`.
No FPCUnit bridge or external test discovery is involved.

Before running from the output directory, copy `private-key.pem` and
`public-key.pem` from this test folder beside the executable. They are the
existing deterministic PEM inputs, not generated user credentials.
