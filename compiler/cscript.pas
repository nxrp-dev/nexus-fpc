{
    Copyright (c) 1998-2002 by Peter Vreman

    This unit handles the writing of script files

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
unit cscript;

{$i fpcdefs.inc}

interface
{$H+}
uses
  SysUtils,
  GlobType,
  CClasses;

type
  TScript=class
    FN   : TCmdStr;
    Data : TCmdStrList;
    Executable : Boolean;
    constructor Create(const S:TCmdStr);
    constructor CreateExec(const S:TCmdStr);
    destructor Destroy;override;
    procedure AddStart(const S:TCmdStr);
    procedure Add(const S:TCmdStr);
    Function  Empty:Boolean;
    procedure WriteToDisk;virtual;
  end;

  TAsmScript = class (TScript)
    Constructor Create(Const ScriptName : TCmdStr); virtual;
    Procedure AddAsmCommand (Const Command, Options,FileName : TCmdStr);virtual;abstract;
    Procedure AddLinkCommand (Const Command, Options, FileName : TCmdStr);virtual;abstract;
    Procedure AddDeleteCommand (Const FileName : TCmdStr);virtual;abstract;
    Procedure AddDeleteDirCommand (Const FileName : TCmdStr);virtual;abstract;
  end;

  TAsmScriptDos = class (TAsmScript)
    Constructor Create (Const ScriptName : TCmdStr); override;
    Procedure AddAsmCommand (Const Command, Options,FileName : TCmdStr);override;
    Procedure AddLinkCommand (Const Command, Options, FileName : TCmdStr);override;
    Procedure AddDeleteCommand (Const FileName : TCmdStr);override;
    Procedure AddDeleteDirCommand (Const FileName : TCmdStr);override;
    Procedure WriteToDisk;override;
  end;

  TAsmScriptUnix = class (TAsmScript)
    Constructor Create (Const ScriptName : TCmdStr);override;
    Procedure AddAsmCommand (Const Command, Options,FileName : TCmdStr);override;
    Procedure AddLinkCommand (Const Command, Options, FileName : TCmdStr);override;
    Procedure AddDeleteCommand (Const FileName : TCmdStr);override;
    Procedure AddDeleteDirCommand (Const FileName : TCmdStr);override;
    Procedure WriteToDisk;override;
  end;

  TLinkRes = Class (TScript)
    Section: string[30];
    FRealResponseFile: Boolean;
    FForceUseForwardSlash: Boolean;
    constructor Create(const ScriptName : TCmdStr; RealResponseFile: Boolean);
    procedure Add(const S:TCmdStr);
    procedure AddFileName(const S:TCmdStr);
    procedure EndSection(const S:TCmdStr);
    procedure StartSection(const S:TCmdStr);
  end;

var
  AsmRes : TAsmScript;

Function ScriptFixFileName(const S:TCmdStr):TCmdStr;
Procedure GenerateAsmRes(const ST : TCmdStr);
Function GenerateScript(const ST : TCmdStr): TAsmScript;


implementation

uses
{$ifdef hasUnix}
  BaseUnix,
{$endif}
  CUtils,CFileUtl,
  Globals,Systems,Verbose;


{****************************************************************************
                                   Helpers
****************************************************************************}

    Function ScriptFixFileName(const S:TCmdStr):TCmdStr;
     begin
       if cs_link_on_target in CurrentSettings.GlobalSwitches then
         ScriptFixFileName:=TargetFixFileName(S)
       else
         ScriptFixFileName:=FixFileName(S);
     end;

{****************************************************************************
                                  TScript
****************************************************************************}

constructor TScript.Create(const S: TCmdStr);
begin
  FN:=FixFileName(S);
  Executable:=False;
  Data:=TCmdStrList.Create;
end;


constructor TScript.CreateExec(const S:TCmdStr);
begin
  FN:=FixFileName(S);
  if cs_link_on_target in CurrentSettings.GlobalSwitches then
    FN:=ChangeFileExt(FN,TargetInfo.ScriptExt)
  else
    FN:=ChangeFileExt(FN,SourceInfo.ScriptExt);
  Executable:=True;
  Data:=TCmdStrList.Create;
end;


destructor TScript.Destroy;
begin
  Data.Free;
  Data := nil;
end;


procedure TScript.AddStart(const S:TCmdStr);
begin
  Data.Insert(S);
end;


procedure TScript.Add(const S:TCmdStr);
begin
   Data.Concat(S);
end;


Function TScript.Empty:Boolean;
begin
  Empty:=Data.Empty;
end;

procedure TScript.WriteToDisk;
var
  T : file;
  I : LongInt;
  S : TCmdStr;
  LE: string[2];

begin
  Assign(T,FN);
  if cs_link_on_target in CurrentSettings.GlobalSwitches then
    LE:= TargetInfo.NewLine
  else
    LE:= SourceInfo.NewLine;

  {$push}{$I-}
  Rewrite(T,1);
  if IOResult<>0 then
    Exit;
  while not Data.Empty do
    begin
      S:=Data.GetFirst;
      BlockWrite(T,S[1],Length(S),I);
      BlockWrite(T,LE[1],Length(LE),I);
    end;
  Close(T);
  {$pop}
  I:=IOResult;
{$ifdef hasUnix}
  if Executable then
   FpChmod(FN,493);
{$endif}
end;

{****************************************************************************
                                  Asm Response
****************************************************************************}

Constructor TAsmScript.Create (Const ScriptName : TCmdStr);
begin
  Inherited CreateExec(ScriptName);
end;


{****************************************************************************
                                  DOS Asm Response
****************************************************************************}

Constructor TAsmScriptDos.Create (Const ScriptName : TCmdStr);
begin
  Inherited Create(ScriptName);
end;


Procedure TAsmScriptDos.AddAsmCommand (Const Command, Options,FileName : TCmdStr);
begin
  if FileName<>'' then
   begin
     Add('SET THEFILE='+ScriptFixFileName(FileName));
     Add('echo Assembling %THEFILE%');
   end;
  Add(MaybeQuoted(Command)+' '+Options);
  Add('if errorlevel 1 goto asmend');
end;


Procedure TAsmScriptDos.AddLinkCommand (Const Command, Options, FileName : TCmdStr);
begin
  if FileName<>'' then
   begin
     Add('SET THEFILE='+ScriptFixFileName(FileName));
     Add('echo Linking %THEFILE%');
   end;
  Add(MaybeQuoted(Command)+' '+Options);
  Add('if errorlevel 1 goto linkend');
end;


Procedure TAsmScriptDos.AddDeleteCommand (Const FileName : TCmdStr);
begin
 Add('Del ' + MaybeQuoted (ScriptFixFileName (FileName)));
end;


Procedure TAsmScriptDos.AddDeleteDirCommand (Const FileName : TCmdStr);
begin
 Add('Rmdir ' + MaybeQuoted (ScriptFixFileName (FileName)));
end;


Procedure TAsmScriptDos.WriteToDisk;
Begin
  AddStart('@echo off');
  Add('goto end');
  Add(':asmend');
  Add('echo An error occurred while assembling %THEFILE%');
  Add('goto end');
  Add(':linkend');
  Add('echo An error occurred while linking %THEFILE%');
  Add(':end');
  inherited WriteToDisk;
end;

{****************************************************************************
                              Unix Asm Response
****************************************************************************}

Constructor TAsmScriptUnix.Create (Const ScriptName : TCmdStr);
begin
  Inherited Create(ScriptName);
end;


Procedure TAsmScriptUnix.AddAsmCommand (Const Command, Options,FileName : TCmdStr);
begin
  if FileName<>'' then
   Add('echo Assembling '+MaybeQuoted(ScriptFixFileName(FileName)));
  Add(MaybeQuoted(Command)+' '+Options);
  Add('if [ $? != 0 ]; then DoExitAsm '+MaybeQuoted(ScriptFixFileName(FileName))+'; fi');
end;


Procedure TAsmScriptUnix.AddLinkCommand (Const Command, Options, FileName : TCmdStr);
begin
  if FileName<>'' then
   Add('echo Linking '+ScriptFixFileName(FileName));
  Add('OFS=$IFS');
  Add('IFS="');
  Add('"');
  Add(MaybeQuoted(Command)+' '+Options);
  Add('if [ $? != 0 ]; then DoExitLink '+ScriptFixFileName(FileName)+'; fi');
  Add('IFS=$OFS');
end;


Procedure TAsmScriptUnix.AddDeleteCommand (Const FileName : TCmdStr);
begin
 Add('rm ' + MaybeQuoted (ScriptFixFileName(FileName)));
end;


Procedure TAsmScriptUnix.AddDeleteDirCommand (Const FileName : TCmdStr);
begin
 Add('rmdir ' + MaybeQuoted (ScriptFixFileName(FileName)));
end;


Procedure TAsmScriptUnix.WriteToDisk;
Begin
  AddStart('{ echo "An error occurred while linking $1"; exit 1; }');
  AddStart('DoExitLink ()');
  AddStart('{ echo "An error occurred while assembling $1"; exit 1; }');
  AddStart('DoExitAsm ()');
   AddStart('#!/bin/sh');
  inherited WriteToDisk;
end;


Procedure GenerateAsmRes(const ST : TCmdStr);
begin
  AsmRes:=GenerateScript(ST);
end;

function GenerateScript(const ST: TCmdStr): TAsmScript;
  var
    ScriptTyp : TScriptType;
  begin
    if cs_link_on_target in CurrentSettings.GlobalSwitches then
      ScriptTyp := TargetInfo.Script
    else
      ScriptTyp := SourceInfo.Script;
    case ScriptTyp of
      script_unix :
        Result:=TAsmScriptUnix.Create(ST);
      script_dos :
        Result:=TAsmScriptDos.Create(ST);
      else
        InternalError(2013112805);
    end;
  end;


{****************************************************************************
                                  Link Response
****************************************************************************}

constructor TLinkRes.Create(const ScriptName: TCmdStr; RealResponseFile: Boolean);
begin
  inherited Create(ScriptName);
  FRealResponseFile:=RealResponseFile;
  FForceUseForwardSlash:=False;
end;

procedure TLinkRes.Add(const S:TCmdStr);
begin
  if S<>'' then
   inherited Add(S);
end;

procedure TLinkRes.AddFileName(const S:TCmdStr);
var
  LS: TCmdStr;
  I: LongInt;
begin
  if Section<>'' then
   begin
    inherited Add(Section);
    Section:='';
   end;
  if S<>'' then
   begin
     LS:=S;
     if FForceUseForwardSlash then
       { Fix separator }
       for I:=1 to Length(LS) do
         if (LS[I]=SourceInfo.DirSep) then
           LS[I]:='/';
     { GNU ld only supports double quotes in the response file. }
     if FRealResponseFile and
        (LS[1]='''') and
        (((cs_link_on_target in CurrentSettings.GlobalSwitches) and
          (TargetInfo.Script=script_unix)) or
         (not(cs_link_on_target in CurrentSettings.GlobalSwitches) and
          (SourceInfo.Script=script_unix))) then
       inherited Add(UnixRequoteWithDoubleQuotes(S))
     else if not(LS[1] in ['a'..'z','A'..'Z','/','\','.','"']) then
      begin
        if FForceUseForwardSlash then
          inherited Add('./'+LS)
        else if (cs_link_on_target in CurrentSettings.GlobalSwitches) then
          inherited Add('.'+TargetInfo.DirSep+LS)
        else
          inherited Add('.'+SourceInfo.DirSep+LS);
      end
     else
      inherited Add(LS);
   end;
end;

procedure TLinkRes.EndSection(const S:TCmdStr);
begin
  { only terminate if we started the section }
  if Section='' then
    inherited Add(S);
  Section:='';
end;

procedure TLinkRes.StartSection(const S:TCmdStr);
begin
  Section:=S;
end;

end.
