{
    Copyright (c) 1998-2003 by Peter Vreman, Florian Klaempfl and Carl Eric Codere

    Basic stuff for assembler readers

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
unit rabase;

{$i fpcdefs.inc}

  interface

    uses
      CClasses,
      Systems;

    type
       TBaseAsmReader = class
         constructor Create;virtual;
         { the real return type is TAsmList, but this would introduce too much unit circles }
         function Assemble: TLinkedList;virtual;abstract;
       end;
       TBaseAsmReaderClass = class of TBaseAsmReader;

       PAsmModeInfo = ^TAsmModeInfo;
       TAsmModeInfo = record
          id    : TAsmMode;
          idtxt : string[12];
          CAsmReader : TBaseAsmReaderClass;
       end;

    var
      asmmodeinfos  : array[0..Ord(High(TAsmMode))] of PAsmModeInfo;

    function SetAsmReadMode(const s:string;var t:TAsmMode):boolean;
    procedure RegisterAsmMode(const r:TAsmModeInfo);

  implementation

    uses
      CUtils;


    procedure RegisterAsmmode(const r:TAsmModeInfo);
      var
        t : TAsmMode;
      begin
        t:=r.id;
        if Assigned(asmmodeinfos[Ord(t)]) then
          WriteLn('Warning: Asmmode is already registered!')
        else
          new(asmmodeinfos[Ord(t)]);
        asmmodeinfos[Ord(t)]^:=r;
      end;


    function SetAsmReadMode(const s:string;var t:TAsmMode):boolean;
      var
        hs : string;
        ht : TAsmMode;
      begin
        result:=false;
        hs:=upper(s);
        { Support Default as an alias for Standard }
        if hs='DEFAULT' then
          hs:='STANDARD';
        for ht:=low(TAsmMode) to high(TAsmMode) do
         if Assigned(asmmodeinfos[Ord(ht)]) and
            (asmmodeinfos[Ord(ht)]^.idtxt=hs) then
          begin
            t:=asmmodeinfos[Ord(ht)]^.id;
            result:=true;
          end;
      end;


    constructor TBaseAsmReader.Create;
      begin
        inherited Create;
      end;

var
  AsmMode : TAsmMode;

finalization
  for AsmMode:=low(TAsmMode) to high(TAsmMode) do
   if Assigned(asmmodeinfos[Ord(AsmMode)]) then
    begin
      dispose(asmmodeinfos[Ord(AsmMode)]);
      asmmodeinfos[Ord(AsmMode)]:=nil;
    end;
end.
