{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generation of a .def file for needed for Os2/Win32

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
unit gendef;

{$i fpcdefs.inc}

interface
uses
  GlobType,CClasses;

type
  TDefFile=class
    fname : string;
    constructor create(const fn:string);
    destructor  Destroy;override;
    procedure addexport(const s:TSymStr);
    procedure addimport(const s:TSymStr);
    procedure writefile;
    function empty : boolean;
  private
    is_empty : boolean;
    WrittenOnDisk : boolean;
    exportlist,
    importlist   : TCmdStrList;
  end;

var
  deffile : TDefFile;


implementation

uses
  SysUtils,
  Systems,CUtils,Globals;

{******************************************************************************
                               TDefFile
******************************************************************************}

constructor TDefFile.create(const fn:string);
begin
  fname:=fn;
  WrittenOnDisk:=false;
  is_empty:=true;
  importlist:=TCmdStrList.Create;
  exportlist:=TCmdStrList.Create;
end;


destructor TDefFile.Destroy;
begin
  if WrittenOnDisk and
     ([cs_link_nolink,cs_link_deffile]*CurrentSettings.GlobalSwitches=[]) then
    DeleteFile(FName);
  importlist.Free;
  importlist := nil;
  exportlist.Free;
  exportlist := nil;
end;



procedure TDefFile.addexport(const s:TSymStr);
begin
  exportlist.insert(s);
  is_empty:=false;
end;


procedure TDefFile.addimport(const s:TSymStr);
begin
  importlist.insert(s);
  is_empty:=false;
end;


function TDefFile.empty : boolean;
begin
  empty:=is_empty or DescriptionSetExplicity;
end;


procedure TDefFile.writefile;
var
  t : text;
begin
  If WrittenOnDisk then
    Exit;
{ open file }
  assign(t,fname);
  {$push}{$I-}
   rewrite(t);
  {$pop}
  if IOResult<>0 then
   exit;
  case TargetInfo.system of
    system_i386_win32,
    system_x86_64_win64,
    system_aarch64_win64 :
      begin
        if Description<>'' then
          WriteLn(t,'DESCRIPTION '+''''+Description+'''');
        if DLLVersion<>'' then
          WriteLn(t,'VERSION '+DLLVersion);
      end;
    else
      ;
  end;

{write imports}
  if not importlist.empty then
   begin
     WriteLn(t,'');
     WriteLn(t,'IMPORTS');
     while not importlist.empty do
      WriteLn(t,#9+importlist.GetFirst);
   end;

{write exports}
  if not exportlist.empty then
   begin
     WriteLn(t,'');
     WriteLn(t,'EXPORTS');
     while not exportlist.empty do
      WriteLn(t,#9+exportlist.GetFirst);
   end;

  close(t);
  WrittenOnDisk:=true;
end;

end.
