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

function IsATTY(var t : text) : Boolean;

const
(* This allows compile-time removal of the colouring functionality under not supported platforms *)
{$if defined(linux) or defined(MSWINDOWS) or defined(DARWIN)}
  TTYCheckSupported = true;
{$else}
  TTYCheckSupported = false;
{$endif}


implementation

{$if defined(linux) or defined(darwin)}
  uses
   termio;
{$endif}
{$ifdef mswindows}
  uses
   windows;
{$endif mswindows}

var
  CachedIsATTY : Boolean = false;
  IsATTYValue : Boolean = false;

{$if defined(linux) or defined(darwin)}
function LinuxIsATTY(var t : text) : Boolean; inline;
begin
  LinuxIsATTY:=termio.IsATTY(t)=1;
end;
{$endif defined(linux) or defined(darwin)}

{$ifdef MSWINDOWS}
const
  ENABLE_VIRTUAL_TERMINAL_PROCESSING = $0004;

function WindowsIsATTY(var t : text) : Boolean; inline;
var 
  dwMode: dword;
begin
  dwMode:=0;
  WindowsIsATTY := false;
  if GetConsoleMode(TextRec(t).handle, dwMode) then
   begin
    dwMode := dwMode or ENABLE_VIRTUAL_TERMINAL_PROCESSING;
    if SetConsoleMode(TextRec(t).handle, dwMode) then
                                     WindowsIsATTY := true;
   end;
end;
{$endif MSWINDOWS}

function IsATTY(var t : text) : Boolean;
begin
  if not(CachedIsATTY) then
    begin
(* If none of the supported values is defined, false is returned by default. *)
{$if defined(linux) or defined(darwin)}
      IsATTYValue:=LinuxIsATTY(t);
{$endif}
{$ifdef MSWINDOWS}
      IsATTYValue:=WindowsIsATTY(t);
{$endif MSWINDOWS}
      CachedIsATTY:=true;
    end;
  Result:=IsATTYValue;
end;

end.
