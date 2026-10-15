{
    This file is part of the Free Pascal compiler.
    Copyright (c) 2020 by the Free Pascal development team

    This unit contains platform-specific code for checking TTY output

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
unit comptty;

{$i fpcdefs.inc}

interface

function IsATTY(var T : Text) : Boolean;

const
(* This allows compile-time removal of the colouring functionality under not supported platforms *)
{$if defined(linux) or defined(MSWINDOWS) or defined(DARWIN)}
  TTYCheckSupported = True;
{$else}
  TTYCheckSupported = False;
{$endif}


implementation

{$if defined(linux) or defined(darwin)}
  uses
   TermIO;
{$endif}
{$ifdef mswindows}
  uses
   Windows;
{$endif mswindows}

var
  CachedIsATTY : Boolean = False;
  IsATTYValue : Boolean = False;

{$if defined(linux) or defined(darwin)}
function LinuxIsATTY(var T : Text) : Boolean; inline;
begin
  LinuxIsATTY:=TermIO.IsATTY(T)=1;
end;
{$endif defined(linux) or defined(darwin)}

{$ifdef MSWINDOWS}
const
  EnableVirtualTerminalProcessing = $0004;

function WindowsIsATTY(var T : Text) : Boolean; inline;
var 
  DWMode: DWORD;
begin
  DWMode:=0;
  WindowsIsATTY := False;
  if GetConsoleMode(TextRec(T).Handle, DWMode) then
   begin
    DWMode := DWMode or EnableVirtualTerminalProcessing;
    if SetConsoleMode(TextRec(T).Handle, DWMode) then
                                     WindowsIsATTY := True;
   end;
end;
{$endif MSWINDOWS}

function IsATTY(var T : Text) : Boolean;
begin
  if not(CachedIsATTY) then
    begin
(* If none of the supported values is defined, false is returned by default. *)
{$if defined(linux) or defined(darwin)}
      IsATTYValue:=LinuxIsATTY(T);
{$endif}
{$ifdef MSWINDOWS}
      IsATTYValue:=WindowsIsATTY(T);
{$endif MSWINDOWS}
      CachedIsATTY:=True;
    end;
  Result:=IsATTYValue;
end;

end.
