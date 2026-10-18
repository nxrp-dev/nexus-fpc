This directory contains some utilities that are used during the
development of the Free Pascal Compiler.

msg2inc  : Convert a compiler message file (errorX.msg) to .inc files to
           include it as the default language in the compiler. It can
           also convert the .msg to .tex for inclusion the documentation

mkx86ins, mkx86reg : Generate x86 instruction and register tables.
mkx86inl          : Generate x86 intrinsic declarations and tables.
mka64ins, mka64reg : Generate AArch64 instruction and register tables.

The generation commands and retained release-tool list are documented in
NexusFPC.Forge.md at the repository root. Run generators in an
isolated source copy under the development worktree, outside this checkout.
