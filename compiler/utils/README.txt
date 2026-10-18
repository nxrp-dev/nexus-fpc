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

msgdif   : analyzes the differences between two msg files
           msgdif errore.msg errord.msg
           will print out new error msg, removed old ones
           and will create a new file new.msg that will
           contain the new error messages (supposing TeX comment is after
           the message line itself)
           removed messages are prepended by "%%% "
           (they can be useful in case on error enum renaming !)

