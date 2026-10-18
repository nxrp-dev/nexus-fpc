This directory contains the NexusFPC compiler sources.

Builds use the Forge projects in ../NexusFPC.Forge.nxscript. Read
../NexusFPC.Forge.md for prerequisites, generation steps, the supported target
matrix, release tools and SDK assembly.

The retained compiler backends are i386, x86_64 and aarch64. Supported targets
are selected by both CPU and OS in ../NexusFPC.Forge.Targets.nxscript:

  Linux:         i386, x86_64, aarch64
  Windows:       i386 (win32), x86_64 and aarch64 (win64)
  Android:       x86_64, aarch64
  macOS:         x86_64, aarch64 (darwin)
  iOS simulator: x86_64, aarch64 (iphonesim)
  iOS device:    aarch64 (ios)

Forge entry points:
  Build:Bootstrap   Build the native compiler and RTL from the FPC 3.2.2 seed;
                    verify compiler generations two and three byte for byte.
  Build:Cross       Build a selected target compiler and RTL.
  Build:Tools       Build the retained release utilities.
  Build:PackageSDK  Assemble the runtime-package SDK.
  Build:Release     Assemble the completed target matrix and release.

Use the documented Clang/LLVM assembler and LLD linker path. Compiler inputs
are generated from the .dat and message sources by the utilities in utils/;
see ../NexusFPC.Forge.Tables.nxscript and utils/README.txt.

Keep generated files outside the source checkout, in a unique directory under
the development worktree. Full rebuild validation uses an isolated checkout.
The Linux bootstrap helper in ../nexus-private/scripts/linux/ (relative to the
repository root) executes the documented stages and accepts --toolchain-root
for this purpose. Use --no-promote for validation builds.
