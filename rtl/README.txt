This is the Run-Time Library (RTL) tree for Free Pascal.

The Forge Bootstrap and Cross projects build the RTL with matching compilers.
See ../NexusFPC.Forge.md for the current commands, target matrix and output paths.
The RTL makefiles, fpmake recipes and regeneration scripts are retired.
Native Linux-hosted build recipes remain deferred; Windows-hosted Linux cross
builds are included in the Forge matrix.

The tree contains subdirectories for all the supported operating systems,
as well as all processor architectures. The processor directories contain
low-level routines which are required for the system unit (if they are not
available in high-level language form), as well as optimized versions of
the pascal generic routines (the generic routine source code is localized in
the inc subdirectory).

Enjoy.
