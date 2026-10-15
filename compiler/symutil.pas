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
       symconst,SymBase,symtype,SymSym;

    function is_funcret_sym(p:TSymEntry):boolean;

    function equal_constsym(sym1,sym2:TConstSym; nanequal: boolean):boolean;

    function get_first_proc_str(Options: TProcOptions): ShortString;

    function is_normal_fieldvarsym(sym: TSym): boolean; inline;


implementation

    uses
       Systems,
       GlobType,CPUInfo,ConstExp,Verbose,
       WideStr,
       symdef;


    function is_funcret_sym(p:TSymEntry):boolean;
      begin
        is_funcret_sym:=(p.typ in [absolutevarsym,localvarsym,paravarsym]) and
                        (vo_is_funcret in TAbstractVarSym(p).VarOptions);
      end;


    function equal_constsym(sym1,sym2:TConstSym; nanequal: boolean):boolean;
      var
        p1,p2,pend : pchar;
      begin
        equal_constsym:=false;
        if sym1.ConstTyp<>sym2.ConstTyp then
         exit;
        case sym1.ConstTyp of
           constord :
             equal_constsym:=(sym1.value.ValueOrd=sym2.value.ValueOrd);
           constpointer :
             equal_constsym:=(sym1.value.ValueOrdPtr=sym2.value.ValueOrdPtr);
           conststring,constresourcestring :
             begin
               if sym1.value.len=sym2.value.len then
                begin
                  p1:=pchar(sym1.value.ValuePtr);
                  p2:=pchar(sym2.value.ValuePtr);
                  pend:=p1+sym1.value.len;
                  while (p1<pend) do
                   begin
                     if p1^<>p2^ then
                      break;
                     inc(p1);
                     inc(p2);
                   end;
                  if (p1=pend) then
                   equal_constsym:=true;
                end;
             end;
           constwstring :
             begin
               if (CompareWideStrings(sym1.value.ValueWS,sym2.value.ValueWS)=0) then
                 equal_constsym:=true;
             end;
           constreal :
             if nanequal then
               equal_constsym:=CompareByte(PBestReal(sym1.value.ValuePtr)^,PBestReal(sym2.value.ValuePtr)^,sizeof(PBestReal^))=0
             else
               equal_constsym:=PBestReal(sym1.value.ValuePtr)^=PBestReal(sym2.value.ValuePtr)^;
           constset :
             equal_constsym:=(PNormalSet(sym1.value.ValuePtr)^=PNormalSet(sym2.value.ValuePtr)^);
           constnil :
             equal_constsym:=true;
           else
             ;
        end;
      end;


    { get_first_proc_str - returns the token string of the first option that
      appears in the list }
    function get_first_proc_str(Options: TProcOptions): ShortString;
      var
        X: TProcOption;
      begin
        if Options = [] then
          InternalError(2018051700);

        get_first_proc_str := '';

        for X in Options do
          begin
            get_first_proc_str := ProcOptionKeywords[X];
            Exit;
          end;
      end;


    function is_normal_fieldvarsym(sym: TSym): boolean; inline;
      begin
        result:=
           (sym.typ=FieldVarSym) and
           not(sp_static in sym.SymOptions);
      end;


end.

