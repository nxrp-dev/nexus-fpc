This directory contains the sources of the Free Pascal Compiler

If you want to compile/modify the compiler, please read first the
programmers manual.

NexusFPC compiler builds use the Forge projects in ../NexusFPC.Forge.nxscript.
See ../NexusFPC.Forge.md for bootstrap prerequisites, the retained target matrix,
generated compiler inputs, release tools and distribution assembly. The compiler
makefiles and their build/installation targets are retired.

The compiler-switch notes below are historical upstream reference. They are not
the supported Nexus target matrix or a replacement for the current Forge recipe.

Possible compiler switches (* marks a currently required switch):
  -----------------------------------------------------------------
  GDB*                support of the GNU Debugger
  I386                generate a compiler for the Intel i386+
  x86_64              generate a compiler for the AMD x86-64 architecture
  M68K                generate a compiler for the M68000
  SPARC               generate a compiler for SPARC
  POWERPC             generate a compiler for the PowerPC
  VIS                 generate a compile for the VIS
  DEBUG               version with debug code is generated
  EXTDEBUG            some extra debug code is executed
  EXTERN_MSG          Don't compile the msgfiles in the compiler, always
                      use external messagefiles, default for TP
  NOAG386INT          no Intel Assembler output
  NOAG386NSM          no NASM output
  NOAG386BIN          leaves out the binary writer, default for TP
  NORA386DIR          No direct i386 assembler reader
  TEST_GENERIC        Test Generic version of code generator
                      (uses generic RTL calls)
  -----------------------------------------------------------------
  cpuflags            The target processor has status flags (on by default)
  cpufpemu            The target compiler will also support emitting software
                       floating point operations
  cpu64bitaddr        The targets use a 64-bit address space (pointers and
                       the default integer type are 64 bit)
  cpu64bitalu         The target cpu has 64-bit registers available (unless
                       cpu64bitaddr is also defined, pointers and default
                       integer type remain 32 bit, but the cpu can perform
                       64 bit calculations directly without needing helpers)
  -----------------------------------------------------------------

  Required switches for a i386 compiler be compiled by Free Pascal Compiler:
  GDB;I386

to build a compiler to SPARC target using a Win32/i386 you just use :
      make CPU_TARGET=SPARC
