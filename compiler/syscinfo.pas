{
    Copyright (c) 2016 by Karoly Balogh

    Contains information on syscalls

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
unit syscinfo;

{$i fpcdefs.inc}

interface

uses
  Systems, Tokens, SymConst;

type
  TSysCallInfo = record
    Token: TToken;
    ProcOption: TProcOption;
    ValidOn: set of TSystem;
  end;
  PSysCallInfo = ^TSysCallInfo;

const
  SysCall_Conventions: array[1..1] of TSysCallInfo = (
      ( Token: NOTOKEN;    ProcOption: po_syscall;           ValidOn: [] ));

function Get_SysCall_By_Token(const Token: TToken): PSysCallInfo;
function Get_SysCall_By_Name(const Name: string): PSysCallInfo;
function Get_Default_SysCall: TProcOption;
procedure Set_Default_SysCall(SC: TProcOption);

implementation

uses
  Verbose;

const
  SysCallConventionsPO = [ po_syscall, po_syscall_legacy, po_syscall_basenone,
                             po_syscall_baselast, po_syscall_basefirst, po_syscall_basereg ];

var
  DefaultSysCallConvention: TProcOption = po_none;

function Get_SysCall_By_Token(const Token: TToken): PSysCallInfo;
var
  I: LongInt;
begin
  Result:=nil;
  for I:=Low(SysCall_Conventions) to High(SysCall_Conventions) do
    if SysCall_Conventions[I].Token = Token then
      begin
        Result:=@SysCall_Conventions[I];
        Break;
      end;
end;

function Get_SysCall_By_Name(const Name: string): PSysCallInfo;
var
  I: LongInt;
begin
  Result:=nil;
  for I:=Low(SysCall_Conventions) to High(SysCall_Conventions) do
    if ArrayTokenInfo[SysCall_Conventions[I].Token].Str = Name then
      begin
        Result:=@SysCall_Conventions[I];
        Break;
      end;
end;

function Get_Default_SysCall: TProcOption;
begin
  if not (DefaultSysCallConvention in SysCallConventionsPO) then
    InternalError(2016090302);

  Result:=DefaultSysCallConvention;
end;

procedure Set_Default_SysCall(SC: TProcOption);
begin
  if not (SC in SysCallConventionsPO) then
    InternalError(2016090301);

  DefaultSysCallConvention:=SC;
end;

end.
