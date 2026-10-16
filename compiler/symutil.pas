{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit provides some help routines for symbol handling

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
unit symutil;

{$i fpcdefs.inc}

interface

    uses
       TPCompilerReal,
       SymConst,SymBase,SymType,SymSym;

    function Is_FuncRet_Sym(P:TSymEntry):Boolean;

    function Equal_ConstSym(Sym1,Sym2:TConstSym; NaNEqual: Boolean):Boolean;

    function Get_First_Proc_Str(Options: TProcOptions): ShortString;

    function Is_Normal_FieldVarSym(Sym: TSym): Boolean; inline;


implementation

    uses
       Systems,
       GlobType,CPUInfo,ConstExp,Verbose,
       WideStr,
       SymDef;


    function Is_FuncRet_Sym(P:TSymEntry):Boolean;
      begin
        Is_FuncRet_Sym:=(P.Typ in [AbsoluteVarSym,LocalVarSym,ParaVarSym]) and
                        (vo_is_funcret in TAbstractVarSym(P).VarOptions);
      end;


    function Equal_ConstSym(Sym1,Sym2:TConstSym; NaNEqual: Boolean):Boolean;
      var
        P1,P2,PEnd : PChar;
      begin
        Equal_ConstSym:=False;
        if Sym1.ConstTyp<>Sym2.ConstTyp then
         Exit;
        case Sym1.ConstTyp of
           ConstOrd :
             Equal_ConstSym:=(Sym1.Value.ValueOrd=Sym2.Value.ValueOrd);
           ConstPointer :
             Equal_ConstSym:=(Sym1.Value.ValueOrdPtr=Sym2.Value.ValueOrdPtr);
           ConstString,ConstResourceString :
             begin
               if Sym1.Value.Len=Sym2.Value.Len then
                begin
                  P1:=PChar(Sym1.Value.ValuePtr);
                  P2:=PChar(Sym2.Value.ValuePtr);
                  PEnd:=P1+Sym1.Value.Len;
                  while (P1<PEnd) do
                   begin
                     if P1^<>P2^ then
                      Break;
                     Inc(P1);
                     Inc(P2);
                   end;
                  if (P1=PEnd) then
                   Equal_ConstSym:=True;
                end;
             end;
           ConstWString :
             begin
               if (CompareWideStrings(Sym1.Value.ValueWS,Sym2.Value.ValueWS)=0) then
                 Equal_ConstSym:=True;
             end;
           ConstReal :
             if NaNEqual then
               Equal_ConstSym:=CompareByte(PBestReal(Sym1.Value.ValuePtr)^,PBestReal(Sym2.Value.ValuePtr)^,SizeOf(PBestReal^))=0
             else
               Equal_ConstSym:=PBestReal(Sym1.Value.ValuePtr)^=PBestReal(Sym2.Value.ValuePtr)^;
           ConstSet :
             Equal_ConstSym:=(PNormalSet(Sym1.Value.ValuePtr)^=PNormalSet(Sym2.Value.ValuePtr)^);
           ConstNil :
             Equal_ConstSym:=True;
           else
             ;
        end;
      end;


    { get_first_proc_str - returns the token string of the first option that
      appears in the list }
    function Get_First_Proc_Str(Options: TProcOptions): ShortString;
      var
        X: TProcOption;
      begin
        if Options = [] then
          InternalError(2018051700);

        Get_First_Proc_Str := '';

        for X in Options do
          begin
            Get_First_Proc_Str := ProcOptionKeywords[X];
            Exit;
          end;
      end;


    function Is_Normal_FieldVarSym(Sym: TSym): Boolean; inline;
      begin
        Result:=
           (Sym.Typ=FieldVarSym) and
           not(sp_static in Sym.SymOptions);
      end;


end.

