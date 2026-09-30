{
    This file is part of the Free Pascal run time library.
    Copyright (c) 2002 Marco van de Voort
    member of the Free Pascal development team.

    Target dependent defines used when compiling the baseunix unit

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

{$ifndef cpux86_64}
  {$define usestime}              // Use stime() syscall instead of settimeofday
{$endif}
{$define oldreaddir}            // Keep using readdir system call instead
                                // of userland getdents stuff.
{$define usedomain}             // Allow uname with "domain" entry.
                                // (which is a GNU extension)
{$ifdef FPC_USE_LIBC}
  {$define usegetcwd}
  {$if not defined(cpux86) and not defined(cpux86_64)}
  {$linklib m}
  {$endif}
{$endif}

{$ifdef cpui386}
  {$define HAS_UGETRLIMIT}
{$endif cpui386}

{$ifdef CPUx86_64}
{$define WAIT4}
{$endif CPUx86_64}


{$ifdef cpui386}
{$define OLDMMAP}
{$endif cpui386}



{$ifdef cpuaarch64}
  {$define generic_linux_syscalls}
  {$undef usestime}
  {$define userenameat}
{$endif cpuaarch64}






{$ifdef android}
  {$define generic_linux_syscalls}
  {$define userenameat}
  {$undef usestime}
  {$undef OLDMMAP}
  {$ifndef cpu64}
    {$define MMAP2}
  {$endif}
{$endif android}
