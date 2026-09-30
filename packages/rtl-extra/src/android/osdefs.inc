{
    Copyright (c) 2000-2002 by Marco van de Voort

    Target dependent defines used when compiling the baseunix unit

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
    MA 02110-1301, USA.

 ****************************************************************************}

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
  {$DEFINE has_ugetrlimit}
{$endif cpui386}

{$ifdef CPUx86_64}
{$define WAIT4}
{$endif CPUx86_64}


{$ifdef cpui386}
{$define OLDMMAP}
{$endif cpui386}
