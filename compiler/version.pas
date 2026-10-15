{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Version/target constants

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
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************
}
unit version;

{$i fpcdefs.inc}

interface

    const
       { version string }
       VersionNr = '3';
       ReleaseNr = '3';
       PatchNr   = '1';
       MinorPatch = '';

       { word version for ppu file }
       WordVersion = ((Ord(VersionNr)-Ord('0')) shl 14)+
                     ((Ord(ReleaseNr)-Ord('0')) shl 7)+
                     (Ord(PatchNr)-Ord('0'));

       { date string }
       DateString = {$I %DATE%};

       { source cpu string }
{$ifdef cpui386}
        SourceCPUString = 'i386';
{$endif cpui386}
{$ifdef cpux86_64}
        SourceCPUString = 'x86_64';
{$endif cpux86_64}
{$ifdef cpuaarch64}
        SourceCPUString = 'aarch64';
{$endif cpuaarch64}

function Version_String:string;
function Full_Version_String:string;


implementation

function Version_String:string;
begin
  Version_String := VersionNr+'.'+ReleaseNr+'.'+PatchNr;
end;


function Full_Version_String:string;
begin
  Full_Version_String := VersionNr+'.'+ReleaseNr+'.'+PatchNr+MinorPatch
{$ifdef REVINC}
  +'-'+{$i revision.inc}
{$endif REVINC}
  ;
end;

end.
