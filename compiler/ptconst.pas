{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Reads typed constants

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
unit ptconst;

{$i fpcdefs.inc}

interface

   uses symtype,SymSym,AAsmData;

    procedure ReadTypedConst(AList:TAsmList;ASym:TStaticVarSym;AInStructure:Boolean);


implementation

    uses
       GlobType,Systems,Globals,Verbose,CUtils,tokens,
       aasmbase,aasmtai,
       FModule,
       Scanner,pbase,pdecvar,
       node,ngtcon,
       symconst,SymBase,symdef
       ;

    procedure ReadTypedConst(AList:TAsmList;ASym:TStaticVarSym;AInStructure:Boolean);
      var
        lSavedFilePos : TFilePosInfo;
        lBuilder    : TTypedConstBuilder;
        lResultList,
        lDataList     : TAsmList;
      begin
        { mark the staticvarsym as typedconst }
        include(ASym.VarOptions,vo_is_typed_const);
        { The variable has a value assigned }
        ASym.VarState:=vs_initialised;
        { the variable can't be placed in a register }
        ASym.VarRegable:=vr_none;

        { generate data for typed const }
        lSavedFilePos:=CurrentFilePos;
        CurrentFilePos:=ASym.fileinfo;

        maybe_new_object_file(AList);
        lBuilder:=TAsmListTypedConstBuilderClass(CTypedConstBuilder).Create(ASym);
        TAsmListTypedConstBuilder(lBuilder).parse_into_asmlist;

        { Parse hints }
        TryConsumeHintDirective(ASym.SymOptions,ASym.DeprecatedMsg);

        Consume(_SEMICOLON);

        { parse public/external/export/... }
        if not AInStructure and
           (
            (
             (CurrentScanner.FToken = _ID) and
             ((CurrentScanner.FIDToken in [_EXPORT,_EXTERNAL,_PUBLIC,_CVAR]) or (CurrentScanner.FIDToken = _WEAKEXTERNAL)) and
             (m_cvar_support in CurrentSettings.ModeSwitches)
            ) or
            (
             (m_mac in CurrentSettings.ModeSwitches) and
             (
              (cs_external_var in CurrentSettings.LocalSwitches) or
              (cs_externally_visible in CurrentSettings.LocalSwitches)
             )
            )
           ) then
          ReadPublicAndExternal(ASym);


        if not ParseGeneric then
          begin
            if vo_is_public in ASym.VarOptions then
              CurrentModule.Add_Public_AsmSym(ASym.MangledName,AB_GLOBAL,AT_DATA);

            { only now get the final asmlist, because inserting the symbol
              information depends on potential section information set above }
            TAsmListTypedConstBuilder(lBuilder).get_final_asmlists(lResultList,lDataList);
            { add the parsed value }
            AList.ConcatList(lResultList);
            { and pointed data, if any }
            CurrentAsmData.asmlists[al_const].ConcatList(lDataList);
            { the (empty) lists themselves are freed by tcbuilder }
          end;

        lBuilder.free;
        lBuilder := nil;
        CurrentFilePos:=lSavedFilePos;
      end;

end.
