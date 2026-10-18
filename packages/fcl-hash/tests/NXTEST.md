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

The suite now uses the single HashLib4Pascal source tree in main Nexus Packages.
It keeps RSA/ECDSA/PEM/OTP behavior and tests the provider directly for SHA-2;
there are no legacy digest implementations or compatibility units. The source
paths under `packages/hash/src` contain only UUID/NTLM/system-crypt services.
All 37 cases pass with range checks, including the independent UUID, NTLM/LM,
RSA callback/MGF1, empty-key OTP and PEM thumbprint regressions. Run from this
source directory to use the existing PEM fixture files without copying them.
