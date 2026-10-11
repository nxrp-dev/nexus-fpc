{
    This file is part of the Free Pascal run time library.
    Copyright (c) 2001 by Free Pascal development team

    cdecl; definitions needed for unix unit.

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 ***********************************************************************}

type filedesarray=array[0..1] of cint;

{$if defined(darwin) and (defined(cpuaarch64) or defined(iphonesim) or (defined(MAC_OS_X_VERSION_MIN_REQUIRED) and (MAC_OS_X_VERSION_MIN_REQUIRED >= 1060)))}
  {$define darwin_new_iostructs}
  {$if defined(cpui386) or defined(cpux86_64)}
    {$defined darin_new_iostructs_suffix}
  {$endif}
{$endif}

Function fpFlock (fd,mode : longint) : cint; cdecl; external clib name 'flock';

Function fpfStatFS(Fd:Longint; Info:pstatfs):cint; cdecl; external clib name 'fstatfs'{$ifdef darin_new_iostructs_suffix}+'$INODE64'{$endif};

Function fpfsync (fd : cint) : cint; cdecl; external clib name 'fsync';

Function fpStatFS  (Path:PAnsiChar; Info:pstatfs):cint; cdecl; external clib name 'statfs'{$ifdef darin_new_iostructs_suffix}+'$INODE64'{$endif};

function pipe (var fildes: filedesarray):cint;  cdecl; external clib name 'pipe';
function fpgettimeofday(tp: ptimeval;tzp:ptimezone):cint;   cdecl; external clib name 'gettimeofday';
