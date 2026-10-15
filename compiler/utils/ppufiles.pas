{
    Copyright (c) 1999-2002 by Peter Vreman

    List files needed by PPU

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

 ****************************************************************************}
Program ppufiles;

uses
  dos,
  ppu,entfile,NXArtifactID;

const
  Version   = 'Version 1.00';
  Title     = 'NXU-Files';
  Copyright = 'Copyright (c) 1999-2002 by the Free Pascal Development Team';

  PPUExt = NexusUnitFileType;

type
  POutFile = ^TOutFile;
  TOutFile = record
    name : string;
    next : POutFile;
  end;

var
  skipdup,
  showstatic,
  showshared,
  showobjects : boolean;

  OutFiles    : POutFile;


{*****************************************************************************
                                 Helpers
*****************************************************************************}

Procedure Error(const s:string;stop:boolean);
{
  Write an error message to stderr
}
begin
  WriteLn(stderr,s);
  if stop then
   halt(1);
end;


Function ChangeFileExt(Const HStr,ext:String):String;
{
  Return a filename which will have extension ext added if no
  extension is found
}
var
  j : LongInt;
begin
  j:=length(Hstr);
  while (j>0) and (Hstr[j]<>'.') do
   dec(j);
  if j=0 then
   ChangeFileExt:=Hstr+'.'+Ext
  else
   ChangeFileExt:=HStr;
end;


Function SplitPath(Const HStr:String):String;
var
  i : LongInt;
begin
  i:=Length(Hstr);
  while (i>0) and not(Hstr[i] in ['\','/']) do
   dec(i);
  SplitPath:=Copy(Hstr,1,i);
end;


Procedure AddFile(const s:string);
var
  p : POutFile;
begin
  p:=nil;
  if skipdup then
   begin
     p:=outfiles;
     while Assigned(p) do
      begin
        if s=p^.name then
         break;
        p:=p^.next;
      end;
   end;
  if not Assigned(p) then
   begin
     new(p);
     p^.name:=s;
     p^.next:=outfiles;
     outfiles:=p;
   end;
end;


Function DoPPU(const PPUFn:String):Boolean;
{
  Convert one file (in Filename) to library format.
  Return true if successful, false otherwise.
}
Var
  inppu  : TPPUFile;
  b      : byte;
  ppulongversion: cardinal;

  procedure showfiles;
  begin
    while not inppu.endofentry do
     begin
       AddFile(inppu.getstring);
       inppu.getlongint;
     end;
  end;

begin
  DoPPU:=false;
  inppu:=TPPUFile.create(PPUFn);
  if not inppu.openfile then
   begin
     inppu.free;
     Error('Error: Could not open : '+PPUFn,false);
     Exit;
   end;
{ Check the ppufile }
  if not inppu.CheckPPUId then
   begin
     inppu.free;
     Error('Error: Expected NexusFPC NXU unit signature in '+PPUFn+'; rebuild with NexusFPC',false);
     Exit;
   end;
  if inppu.getversion<>CurrentPPUVersion then
   begin
     inppu.free;
     Error('Error: Wrong PPU Version : '+PPUFn,false);
     Exit;
   end;
{ read until the object files are found }
  repeat
    b:=inppu.readentry;
    case b of
      ibextraheader:
        begin
          ppulongversion:=cardinal(inppu.getlongint);
          if ppulongversion<>CurrentPPULongVersion then
            begin
              inppu.free;
              Error('Error: Wrong NexusFPC PPU Long Version in '+PPUFn,false);
              exit;
            end;
        end;
      ibendinterface,
      ibend :
        break;
      iblinkunitstaticlibs :
        if showstatic then
         showfiles;
      iblinkunitsharedlibs :
        if showshared then
         showfiles;
      iblinkunitofiles :
        if showobjects then
         showfiles;
    end;
  until false;
  inppu.free;
  DoPPU:=True;
end;



var
  i,parafile : LongInt;
  dir        : SearchRec;
  s,InFile   : String;
  p          : POutFile;
begin
{ defaults }
  skipdup:=true;
{ options }
  i:=1;
  while (i<=paramcount) do
   begin
     s:=ParamStr(i);
     if s[1]<>'-' then
      break;
     case upcase(s[2]) of
      'L' : showshared:=true;
      'S' : showstatic:=true;
      'O' : showobjects:=true;
      'A' : skipdup:=false;
      '?','H' :
        begin
          WriteLn('usage: ppufiles [options] <files>');
          WriteLn('options:');
          WriteLn('  -A  Show all files (don''t remove duplicates)');
          WriteLn('  -L  Show only shared libraries');
          WriteLn('  -S  Show only static libraries');
          WriteLn('  -O  Show only object files');
          WriteLn('  -H  This helpscreen');
        end;
     end;
     inc(i);
   end;
  { default shows everything }
  if i=1 then
   begin
     showshared:=true;
     showstatic:=true;
     showobjects:=true;
   end;
{ files }
  parafile:=i;
  for i:=parafile to ParamCount do
   begin
     InFile:=ChangeFileExt(ParamStr(i),PPUExt);
     FindFirst(InFile,$20,Dir);
     while (DosError=0) do
      begin
        if not DoPPU(SplitPath(InFile)+Dir.Name) then
          ExitCode:=1;
        FindNext(Dir);
      end;
     FindClose(Dir);
   end;
{ Display the files }
  while Assigned(outfiles) do
   begin
     p:=outfiles;
     write(outfiles^.name);
     outfiles:=outfiles^.next;
     dispose(p);
     if Assigned(outfiles) then
      write(' ');
   end;
end.
