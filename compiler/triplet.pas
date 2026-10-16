{
    Copyright (c) 2007-2008, 2013, 2019-2020 by Jonas Maebe

    This unit handles constructing target triples

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
unit triplet;

{$i fpcdefs.inc}

interface

uses
  GlobType;

function TargetTriplet(TripletStyle: TTripletStyle): AnsiString;

implementation

uses
  Globals,Systems,
  CPUInfo,TripletCPU;

  function TargetTriplet(TripletStyle: TTripletStyle): AnsiString;
    begin
      { architecture }
      Result:=TripletCPUStr(TripletStyle);
      { vendor and/or OS }
      if TargetInfo.System in systems_darwin then
        begin
          Result:=Result+'-apple';
          if TargetInfo.System in systems_macosx then
            Result:=Result+'-macosx'+MacOSXVersionMin.Str
          else if TargetInfo.System = system_aarch64_iphonesim then
            Result:=Result+'-ios'+IPhoneOSVersionMin.Str+'-simulator'
          else
            Result:=Result+'-ios'+IPhoneOSVersionMin.Str;
        end
      else if TargetInfo.System in (systems_linux+systems_android) then
        Result:=Result+'-unknown-linux'
      else if TargetInfo.System in systems_all_windows then
        begin
          Result:=Result+'-pc';
          Result:=Result+'-windows-msvc19'
        end
      else
        Result:=Result+'-unknown';

      { environment/ABI }
      if TargetInfo.System in systems_android then
        Result:=Result+'-android'
      else
      if TargetInfo.System in systems_linux then
        Result:=Result+'-gnu';
    end;



end.

