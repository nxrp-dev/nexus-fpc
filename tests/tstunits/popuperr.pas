{
    This file is part of the Free Pascal test suite.
    Copyright (c) 1999-2004 by the Free Pascal development team.

    Used to avoid getting pop up windows for critical errors under Windows
    and OS/2 operating systems (extension of win32err unit by Pierre Muller).

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit popuperr;

interface

implementation

{ mswindows is defined for win32 and win64 targets }
{$ifdef mswindows}
uses
  windows;
{$endif mswindows}


begin
{$ifdef mswindows}
  SetErrorMode(
    SEM_FAILCRITICALERRORS or
    SEM_NOGPFAULTERRORBOX or
    SEM_NOOPENFILEERRORBOX);
{$endif mswindows}
end.
