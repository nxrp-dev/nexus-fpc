{
    Copyright (c) 2018 by Florian Klaempfl

    Basic infrastructure for measuring timings of different compilation steps

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
unit cprofile;

{ to use this profile infrastructure, the epiktimer sources must be available, the official repository is currently:

  https://github.com/graemeg/epiktimer.git

  clone it into the same base directory fpc is checked out/cloned, i.e.
  <base dir>/fpc/compiler
  <base dir>/epiktimer

  As the official branch requires the use of the classes units, I recommend to
  use my modified version of epiktimer which allows to disable the use of the classes unit,
  this is done automatically by the compiler sources through a define. You can get my epiktimer source from

  https://github.com/FPK/epiktimer.git

  clone them into the same base directory fpc is checked out/cloned, i.e.
  <base dir>/fpc/compiler
  <base dir>/epiktimer

                                                                           (FK)
}
{ $define COMPILER_TIMINGS}

{$i fpcdefs.inc}

interface

  uses
    Globals;

  type
    TCTimer = (
      ct_none,
      ct_aopt);

  procedure ResumeTimer(T : TCTimer);
  procedure StopTimer;

implementation

{$ifndef COMPILER_TIMINGS}
  procedure ResumeTimer(T : TCTimer);
    begin
    end;


  procedure StopTimer;
    begin
    end;
{$else COMPILER_TIMINGS}
  uses
    CEpikTimer;

  var
    CurrentTimer : TCTimer;
    Timers : array[TCTimer] of TEpikTimer;


  procedure ResumeTimer(T : TCTimer);
    begin
      Timers[CurrentTimer].Stop;
      Timers[T].Start;
      CurrentTimer:=T;
    end;


  procedure StopTimer;
    begin
      Timers[CurrentTimer].Stop;
      CurrentTimer:=ct_none;
      Timers[CurrentTimer].Start;
    end;

var
  T : TCTimer;

initialization
  for T:=Low(Timers) to High(Timers) do
    Timers[T]:=TEpikTimer.Create;
  CurrentTimer:=ct_none;
finalization
  WriteLn(StdErr,'Compiler profiler results:');
  Timers[CurrentTimer].Stop;
  for T:=Low(Timers) to High(Timers) do
    WriteLn(StdErr,'  ',T,' ',Timers[T].Elapsed:0:9,' s');
  for T:=Low(Timers) to High(Timers) do
    FreeAndNil(Timers[T]);
{$endif COMPILER_TIMINGS}
end.

