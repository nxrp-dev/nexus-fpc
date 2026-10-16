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
  SymType,
  ParaMgr;

type
  TArmGenParaManager = class(TParaManager)
   protected
    { Returns whether a def is a "homogeneous float array" at the machine level.
      This means that in the memory layout, the def only consists of maximally
      4 floating point values that appear consecutively in memory }
    function Is_HFA(P: TDef; out BaseDef: TDef) : Boolean;
   private
    function IsHFAInternal(P: TDef; var BaseDef: TDef; var EleCount: LongInt): Boolean;
  end;


implementation

  uses
    SymConst,SymDef,SymSym,SymUtil,DefUtil;


  function TArmGenParaManager.Is_HFA(P: TDef; out BaseDef: TDef): Boolean;
    var
      EleCount: LongInt;
    begin
      Result:=False;
      BaseDef:=nil;
      EleCount:=0;
      Result:=IsHFAInternal(P,BaseDef,EleCount);
      Result:=
        Result and
        (EleCount>0) and
        (EleCount<=4) and
        (P.Size=BaseDef.Size*EleCount)
      end;


  function TArmGenParaManager.IsHFAInternal(P: TDef; var BaseDef: TDef; var EleCount: LongInt): Boolean;
    var
      I: LongInt;
      Sym: TSym;
      TmpEleCount: LongInt;
    begin
      Result:=False;
      case P.Typ of
        ArrayDef:
          begin
            if Is_Special_Array(P) then
              Exit;
            { an array of empty records has no influence }
            if TArrayDef(P).ElementDef.Size=0 then
              begin
                Result:=True;
                Exit
              end;
            TmpEleCount:=0;
            if not IsHFAInternal(TArrayDef(P).ElementDef,BaseDef,TmpEleCount) then
              Exit;
            { tmpelecount now contains the number of hfa elements in a
              single array element (e.g. 2 if it's an array of a record
              containing two singles) -> multiply by number of elements
              in the array }
            Inc(EleCount,TArrayDef(P).EleCount*TmpEleCount);
            if EleCount>4 then
              Exit;
            Result:=True;
          end;
        FloatDef:
          begin
            if not Assigned(BaseDef) then
              BaseDef:=P
            else if BaseDef<>P then
              Exit;
            Inc(EleCount);
            Result:=True;
          end;
        RecordDef:
          begin
            for I:=0 to TAbstractRecordDef(P).SymTable.SymList.Count-1 do
              begin
                Sym:=TSym(TAbstractRecordDef(P).SymTable.SymList[I]);
                if not Is_Normal_FieldVarSym(Sym) then
                  Continue;
                if not IsHFAInternal(TFieldVarSym(Sym).VarDef,BaseDef,EleCount) then
                  Exit
              end;
            Result:=True;
          end;
        else
          Exit
      end;
    end;

end.
