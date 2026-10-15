{
    Copyright (c) 2022 by Jonas Maebe

    Target OS version comparisons

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
unit versioncmp;

{$i fpcdefs.inc}

interface

  type
    TVersion = object
     private
      FStr: string;
      FNum: Cardinal;
     public
      { initialise with string and numerical representation of the version }
      constructor Init(const Str: string; Major: Byte; Minor: Word; Patch: Byte);
      constructor Invalidate;
      function RelationTo(const Other: TVersion): ShortInt;
      function RelationTo(Major: Byte; Minor: Word; Patch: Byte): ShortInt;
      function IsValid: Boolean;
      property Str: string read FStr;
     private
      function ToNum(Major: Byte; Minor: Word; Patch: Byte): Cardinal; inline;
    end;

implementation

  function TVersion.ToNum(Major: Byte; Minor: Word; Patch: Byte): Cardinal;
    begin
      Result:=(Major shl 24) or (Minor shl 8) or Patch;
    end;


  constructor TVersion.Init(const Str: string; Major: Byte; Minor: Word; Patch: Byte);
    begin
      FStr:=Str;
      FNum:=ToNum(Major,Minor,Patch);
    end;


  constructor TVersion.Invalidate;
    begin
      FStr:='';
      FNum:=0;
    end;


  function TVersion.RelationTo(const Other: TVersion): ShortInt;
    begin
      if FNum>Other.FNum then
        Result:=1
      else if FNum<Other.FNum then
        Result:=-1
      else
        Result:=0;
    end;


  function TVersion.RelationTo(Major: Byte; Minor: Word; Patch: Byte): ShortInt;
    var
      OtherNum: Cardinal;
    begin
      OtherNum:=ToNum(Major,Minor,Patch);
      if FNum>OtherNum then
        Result:=1
      else if FNum<OtherNum then
        Result:=-1
      else
        Result:=0;
    end;


  function TVersion.IsValid: Boolean;
    begin
      Result:=FStr<>'';
    end;



end.

