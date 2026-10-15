{
    Copyright (c) 2019 by Jonas Maebe

    ARM and AArch64 common parameter helpers

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
unit armpara;

{$i fpcdefs.inc}

interface

uses
  symtype,
  paramgr;

type
  TArmGenParaManager = class(TParaManager)
   protected
    { Returns whether a def is a "homogeneous float array" at the machine level.
      This means that in the memory layout, the def only consists of maximally
      4 floating point values that appear consecutively in memory }
    function is_hfa(p: TDef; out BaseDef: TDef) : boolean;
   private
    function is_hfa_internal(p: TDef; var BaseDef: TDef; var EleCount: LongInt): boolean;
  end;


implementation

  uses
    symconst,symdef,SymSym,symutil,defutil;


  function TArmGenParaManager.is_hfa(p: TDef; out BaseDef: TDef): boolean;
    var
      EleCount: LongInt;
    begin
      result:=false;
      BaseDef:=nil;
      EleCount:=0;
      result:=is_hfa_internal(p,BaseDef,EleCount);
      result:=
        result and
        (EleCount>0) and
        (EleCount<=4) and
        (p.size=BaseDef.size*EleCount)
      end;


  function TArmGenParaManager.is_hfa_internal(p: TDef; var BaseDef: TDef; var EleCount: LongInt): boolean;
    var
      i: LongInt;
      sym: TSym;
      tmpelecount: LongInt;
    begin
      result:=false;
      case p.typ of
        arraydef:
          begin
            if is_special_array(p) then
              exit;
            { an array of empty records has no influence }
            if TArrayDef(p).ElementDef.size=0 then
              begin
                result:=true;
                exit
              end;
            tmpelecount:=0;
            if not is_hfa_internal(TArrayDef(p).ElementDef,BaseDef,tmpelecount) then
              exit;
            { tmpelecount now contains the number of hfa elements in a
              single array element (e.g. 2 if it's an array of a record
              containing two singles) -> multiply by number of elements
              in the array }
            inc(EleCount,TArrayDef(p).EleCount*tmpelecount);
            if EleCount>4 then
              exit;
            result:=true;
          end;
        floatdef:
          begin
            if not Assigned(BaseDef) then
              BaseDef:=p
            else if BaseDef<>p then
              exit;
            inc(EleCount);
            result:=true;
          end;
        recorddef:
          begin
            for i:=0 to TAbstractRecordDef(p).SymTable.SymList.count-1 do
              begin
                sym:=TSym(TAbstractRecordDef(p).SymTable.SymList[i]);
                if not is_normal_fieldvarsym(sym) then
                  continue;
                if not is_hfa_internal(TFieldVarSym(sym).vardef,BaseDef,EleCount) then
                  exit
              end;
            result:=true;
          end;
        else
          exit
      end;
    end;

end.
