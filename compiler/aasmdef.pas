{
    Copyright (c) 2016 by Jonas Maebe, member of the Free Pascal
    development team

    Contains asmsymbol functionality that depends on symdef (to avoid creating
    circular dependencies between symdef and aasmdata via aasmtai)

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
unit aasmdef;

{$i fpcdefs.inc}

interface

uses
  GlobType,
  aasmbase,AAsmData,
  symtype;

type
  TAsmDataDef = class(TAsmData)
    function  DefineAsmSymbolByClass(symclass: TAsmSymbolClass; const s : TSymStr;_bind:TAsmsymbind;_typ:TAsmsymtype; def: TDef) : TAsmSymbol; override;
  end;

implementation

uses
  Globals,CUtils,Systems,
  aasmtai,aasmcnst,
  symdef,
  FModule;


function TAsmDataDef.DefineAsmSymbolByClass(symclass: TAsmSymbolClass; const s: TSymStr; _bind: TAsmsymbind; _typ: TAsmsymtype; def: TDef): TAsmSymbol;
  var
    symind: TAsmSymbol;
    ptrdef: TDef;
    tcb: TTAITypedConstBuilder;
    wasdefined: boolean;
  begin
    result:=DefineAsmSymbolByClassBase(symclass,s,_bind,_typ,def,wasdefined);
    { define the indirect asmsymbol if necessary }
    if not wasdefined and
       (_bind in [AB_GLOBAL,AB_COMMON,AB_PRIVATE_EXTERN]) and
       (_typ<>AT_DATA_NOINDIRECT) and
       (((_typ=AT_DATA) and
         (tf_supports_packages in TargetInfo.flags) and
         (TargetInfo.system in systems_indirect_var_imports)
        ) or
        (_typ=AT_DATA_FORCEINDIRECT)
       ) then
      begin
        ptrdef:=CPointerDef.getreusable(def);
        symind:=CurrentAsmData.DefineAsmSymbol(s,AB_INDIRECT,AT_DATA,ptrdef);
        tcb:=CTAITypedConstBuilder.create([tcalo_make_dead_strippable,tcalo_new_section]);
        tcb.emit_tai(TAIConst.Create_sym_offset(result,0),ptrdef);
        CurrentAsmData.AsmLists[al_indirectglobals].ConcatList(tcb.get_final_asmlist(
          symind,ptrdef,
          sec_rodata,
          lower(symind.name),
          ptrdef.alignment));
        tcb.free;
        tcb := nil;
        if (_typ=AT_DATA_FORCEINDIRECT) and not (TargetInfo.system in systems_indirect_var_imports) then
          CurrentModule.Add_Public_AsmSym(symind.name,AB_INDIRECT,AT_DATA);
      end;
  end;


begin
  { Do not overwrite if already set, by powerpc specific code for example }
  if not Assigned(casmdata) then
    casmdata:=TAsmDataDef;
end.

