{
    Copyright (c) 2011 by Jonas Maebe

    This unit provides helpers for creating new syms/defs based on string
    representations.

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
{$i fpcdefs.inc}

unit symcreat;

interface

  uses
    FinPut,Tokens,Scanner,GlobType,CClasses,
    AAsmData,
    SymConst,SymBase,SymType,SymDef,SymSym,
    Node;


  type
    TScannerState = record
      NewScanner: TScannerFile;
      OldScanner: TScannerFile;
      OldFilePos: TFilePosInfo;
      OldModeSwitches: TModeSwitches;
      Valid: Boolean;
    end;

  { save/restore the scanner state before/after injecting }
  procedure Replace_Scanner(const TempName: string; out SState: TScannerState);
  procedure Restore_Scanner(const SState: TScannerState);

  { parses a (class or regular) method/constructor/destructor declaration from
    str, as if it were declared in astruct's declaration body

    WARNING: save the scanner state before calling this routine, and restore
      when done. }
  function Str_Parse_Method_Dec(Str: AnsiString; POType: TProcTypeOption; IsClassDef: Boolean; AStruct: TAbstractRecordDef; out PD: TProcDef): Boolean;

  { parses a (class or regular)  method/constructor/destructor implementation
    from str, as if it appeared in the current unit's implementation section

      WARNINGS:
        * save the scanner state before calling this routine, and restore when done.
        * the code *must* be written in objfpc style
  }
  function Str_Parse_Method_Impl(const Str: AnsiString; UseFWPD: TProcDef; IsClassDef: Boolean):Boolean;

  { parses a typed constant assignment to ssym

      WARNINGS:
        * save the scanner state before calling this routine, and restore when done.
        * the code *must* be written in objfpc style
  }
  procedure Str_Parse_TypedConst(List: TAsmList; Str: AnsiString; SSym: TStaticVarSym);

  { goes through all defs in st to add implementations for synthetic methods
    added earlier }
  procedure Add_Synthetic_Method_Implementations(ST: TSymTable);

  { create an alias for a procdef with Pascal name "newrealname",
    mangledname "newmangledname", in symtable newparentst, part of the
    record/class/.. "newstruct" (nil if none), and with synthetickind "sk" and
    synthetic kind para "skpara" to create the implementation (tsk_none and nil
    in case not necessary). Returns the new procdef; finish_copied_procdef() is
    not required/must not be called for the result. }
  function Create_ProcDef_Alias(PD: TProcDef; const NewRealName: string; const NewMangledName: TSymStr; NewParentST: TSymTable; NewStruct: TAbstractRecordDef; SK: TSyntheticKind; SKPara: Pointer): TProcDef;

  { finalize a procdef that has been copied with
    tprocdef.getcopyas(procdef,pc_bareproc) }
  procedure Finish_Copied_ProcDef(var PD: TProcDef; const RealName: string; NewParentST: TSymTable; NewStruct: TAbstractRecordDef);

  { checks whether sym (a local or para of pd) already has a counterpart in
    pd's parentfpstruct, and if not adds a new field to the struct with type
    "vardef" (can be different from sym's type in case it's a call-by-reference
    parameter, which is indicated by addrparam). If it already has a field in
    the parentfpstruct, this field is returned. }
  function Maybe_Add_Sym_To_ParentFPStruct(PD: TProcDef; Sym: TSym; VarDef: TDef; AddrParam: Boolean): TSym;
  { given a localvarsym or paravarsym of pd, returns the field of the
    parentfpstruct corresponding to this sym }
  function Find_Sym_In_ParentFPStruct(PD: TProcDef; Sym: TSym): TSym;
  { replaces all local and paravarsyms that have been mirrored in the
    parentfpstruct with aliasvarsyms that redirect to these fields (used to
    make sure that references to these syms in the owning procdef itself also
    use the ones in the parentfpstructs) }
  procedure Redirect_ParentFPStruct_Local_Syms(PD: TProcDef);
  { finalises the parentfpstruct (alignment padding, ...) }
  procedure Finish_ParentFPStruct(PD: TProcDef);

  { turns a fieldvarsym into a class/static field definition, and returns the
    created staticvarsym that is responsible for allocating the global storage }
  function Make_Field_Static(RecST: TSymTable; FieldVS: TFieldVarSym): TStaticVarSym;

  { create a new procdef with the signature of orgpd and (mangled) name
    newname, and change the implementation of orgpd so that it calls through
    to this new procedure }
  procedure Call_Through_New_Name(OrgPD: TProcDef; const NewName: TSymStr);

  function Generate_Pkg_Stub(PD:TProcDef):TNode;
  procedure Generate_Attr_Constrs(Attrs:TFPObjectList);

  { Generate the hidden thunk class for interfaces,
    so we can use them in TVirtualInterface on platforms that do not allow
    generating executable code in memory at runtime.}
  procedure Add_Synthetic_Interface_Classes_For_ST(ST : TSymTable; GenIntf, GenImpl : Boolean);


implementation

  uses
    CUtils,Globals,Verbose,Systems,CompHook,FModule,ConstExp,
    SymTable,DefUtil,SymUtil,ProcInfo,
    PBase,PDecl, PDecObj,PDecSub,PSub,PTConst,PParaUtl,
    AAsmCPU,SymCPU,
    NBas,NLd,NMem,NCon,
    DefCmp,
    Paramgr;

  procedure Replace_Scanner(const TempName: string; out SState: TScannerState);
    var
      OldBlockType: TBlockType;
    begin
      { would require saving of cstringpattern, patternw }
      if (CurrentScanner.Token=_CSTRING) or
         (CurrentScanner.Token=_CWCHAR) or
         (CurrentScanner.Token=_CWSTRING) then
        InternalError(2011032201);
      SState.OldScanner:=CurrentScanner;
      SState.OldFilePos:=CurrentFilePos;
      SState.OldModeSwitches:=CurrentSettings.ModeSwitches;
      SState.Valid:=True;
      { creating a new scanner resets the block type, while we want to continue
        in the current one }
      OldBlockType:=Block_Type;
      SState.NewScanner:=TScannerFile.Create('_Macro_.'+TempName,True);
      Set_Current_Scanner(SState.NewScanner);
      Block_Type:=OldBlockType;
      { required for e.g. FpcDeepCopy record method (uses "out" parameter; field
        names are escaped via &, so should not cause conflicts }
      CurrentSettings.ModeSwitches:=ObjFPCModeSwitches+
        (SState.OldModeSwitches*[m_default_ansistring,m_default_unicodestring]);
    end;


  procedure Restore_Scanner(const SState: TScannerState);
    begin
      if SState.Valid then
        begin
          SState.NewScanner.Free; // no nil needed
          Set_Current_Scanner(SState.OldScanner);
          CurrentFilePos:=SState.OldFilePos;
          CurrentSettings.ModeSwitches:=SState.OldModeSwitches;
        end;
    end;


  function Str_Parse_Method_Dec(Str: AnsiString; POType: TProcTypeOption; IsClassDef: Boolean; AStruct: TAbstractRecordDef; out PD: TProcDef): Boolean;
    var
      OldParseOnly: Boolean;
    begin
      Message1(parser_d_internal_parser_string,Str);
      OldParseOnly:=parse_only;
      parse_only:=True;
      Result:=False;
      { in case multiple strings are injected, make sure to always close the
        previous macro inputfile to prevent memory leaks }
      if Assigned(CurrentScanner.InputFile) and
         not(CurrentScanner.InputFile.Closed) then
        CurrentScanner.CloseInputFile;
      { inject the string in the scanner }
      Str:=Str+'end;';
      CurrentScanner.SubstituteMacro('meth_head_macro',@Str[1],Length(Str),CurrentScanner.line_no,CurrentScanner.InputFile.RefIndex,True);
      CurrentScanner.ReadToken(False);
      { and parse it... }
      case POType of
        potype_class_constructor:
          PD:=class_constructor_head(AStruct);
        potype_class_destructor:
          PD:=class_destructor_head(AStruct);
        potype_constructor:
          PD:=constructor_head;
        potype_destructor:
          PD:=destructor_head;
        else if Assigned(AStruct) and
           (AStruct.Typ=RecordDef) then
          PD:=parse_record_method_dec(AStruct,IsClassDef,False)
        else
          PD:=method_dec(AStruct,IsClassDef,False);
      end;
      if Assigned(PD) then
        Result:=True;
      parse_only:=OldParseOnly;
      { remove the temporary macro input file again }
      CurrentScanner.CloseInputFile;
      CurrentScanner.NextFile;
      CurrentScanner.TempOpenInputFile;
    end;


  function StrParseMethodImplWithFileInfo(Str: AnsiString; UseFWPD: TProcDef; FileNo, LineNo: LongInt; IsClassDef: Boolean; out ResultProcDef: TProcDef):Boolean;
     var
       OldParseOnly: Boolean;
       TmpStr: AnsiString;
       Flags : TReadProcFlags;
     begin
      if ((Status.Verbosity and VDebug)<>0) then
        begin
           if Assigned(UseFWPD) then
             Message1(parser_d_internal_parser_string,UseFWPD.CustomProcName([pno_proctypeoption,pno_paranames,pno_ownername,pno_noclassmarker,pno_noleadingdollar])+Str)
           else
             begin
               if IsClassDef then
                 TmpStr:='class '
               else
                 TmpStr:='';
               Message1(parser_d_internal_parser_string,TmpStr+Str);
             end;
        end;
      OldParseOnly:=parse_only;
      parse_only:=False;
      Result:=False;
      { "const" starts a new kind of block and hence makes the scanner return }
      Str:=Str+'const;';
      { inject the string in the scanner }
      CurrentScanner.SubstituteMacro('meth_impl_macro',@Str[1],Length(Str),LineNo,FileNo,True);
      CurrentScanner.ReadToken(False);
      { and parse it... }
      Flags:=[];
      if IsClassDef then
        Include(Flags,rpf_classmethod);
      ResultProcDef:=read_proc(Flags,UseFWPD);
      parse_only:=OldParseOnly;
      { remove the temporary macro input file again }
      CurrentScanner.CloseInputFile;
      CurrentScanner.NextFile;
      CurrentScanner.TempOpenInputFile;
      Result:=True;
     end;


  function Str_Parse_Method_Impl(const Str: AnsiString; UseFWPD: TProcDef; IsClassDef: Boolean):Boolean;
    var
      TmpProc: TProcDef;
    begin
      Result:=StrParseMethodImplWithFileInfo(Str, UseFWPD, CurrentScanner.InputFile.RefIndex, CurrentScanner.line_no, IsClassDef, TmpProc);
    end;


  function Str_Parse_Method_Impl(const Str: AnsiString; UseFWPD: TProcDef; IsClassDef: Boolean; out ResultProcDef: TProcDef):Boolean;
    begin
      Result:=StrParseMethodImplWithFileInfo(Str, UseFWPD, CurrentScanner.InputFile.RefIndex, CurrentScanner.line_no, IsClassDef, ResultProcDef);
    end;


  procedure Str_Parse_TypedConst(List: TAsmList; Str: AnsiString; SSym: TStaticVarSym);
    var
      OldBlockType: TBlockType;
      OldParseOnly: Boolean;
    begin
      Message1(parser_d_internal_parser_string,Str);
      { a string that will be interpreted as the start of a new section ->
        typed constant parsing will stop }
      Str:=Str+'type ';
      OldParseOnly:=parse_only;
      OldBlockType:=Block_Type;
      parse_only:=True;
      Block_Type:=bt_const;
      CurrentScanner.SubstituteMacro('typed_const_macro',@Str[1],Length(Str),CurrentScanner.line_no,CurrentScanner.InputFile.RefIndex,True);
      CurrentScanner.ReadToken(False);
      read_typed_const(List,SSym,SSym.Owner.SymTableType in [RecordSymTable,ObjectSymTable]);
      parse_only:=OldParseOnly;
      Block_Type:=OldBlockType;
      { remove the temporary macro input file again }
      CurrentScanner.CloseInputFile;
      CurrentScanner.NextFile;
      CurrentScanner.TempOpenInputFile;
    end;

    function StrParseObjectTypeDef(TypeName : ShortString;Str: AnsiString): TObjectDef;
     var
       B,OldParseOnly: Boolean;
       I : Integer;
       TmpStr: AnsiString;
       Flags : TReadProcFlags;
       O : TObject;

     begin
      Result:=nil;
      Message1(parser_d_internal_parser_string,Str);
      OldParseOnly:=parse_only;
      parse_only:=True;
      { "const" starts a new kind of block and hence makes the scanner return }
      Str:=Str+'const;';
      Block_Type:=bt_type;
      { inject the string in the scanner }
      CurrentScanner.SubstituteMacro('hidden_interface_class_macro',@Str[1],Length(Str),CurrentScanner.line_no,CurrentScanner.InputFile.RefIndex,True);
      CurrentScanner.ReadToken(False);
      type_dec(B);
      // In the interface part, the object def is not necessarily the last one, the methods also generate defs.
      I:=CurrentModule.DefList.Count-1;
      While (Result=nil) and (I>=0) do
        begin
        O:=CurrentModule.DefList[I];
        if (O is TObjectDef) then
           if (TObjectDef(O).GetTypeName=TypeName) then
             Result:=TObjectDef(O);
        Dec(I);
        end;
      if Result=nil then
        InternalError(2024050401);
      parse_only:=OldParseOnly;
      { remove the temporary macro input file again }
      CurrentScanner.CloseInputFile;
      CurrentScanner.NextFile;
      CurrentScanner.TempOpenInputFile;
     end;


  function DefUnitNamePrefixIfTopLevel(Def: TDef): TSymStr;
    begin
      Result:='';
      { if the routine is a global routine in a unit, explicitly use this unit
        name to avoid accidentally calling other same-named routines that may be
        in scope }
      if not Assigned(Def.Owner.DefOwner) and
         Assigned(Def.Owner.RealName) and
         (Def.Owner.ModuleID<>0) then
        Result:=internal_macro_escape_unit_namespace_name+Def.Owner.RealName^+'.';
    end;


  procedure ImplementRecordDeepCopy(PD: TProcDef);
    var
      Struct: TAbstractRecordDef;
      Str: AnsiString;
      I: LongInt;
      Sym: TSym;
      FSym: TFieldVarSym;
    begin
      if not(PD.Struct.Typ in [RecordDef,ObjectDef]) then
        InternalError(2011032810);
      Struct:=PD.Struct;
      { anonymous record types must get an artificial name, so we can generate
        a typecast at the scanner level }
      if (Struct.Typ=RecordDef) and
         not Assigned(Struct.TypeSym) then
        InternalError(2011032811);
      { copy all fields }
      Str:='type _fpc_ptrt = ^'+Struct.TypeSym.RealName+'; var Res: _fpc_ptrt; begin Res:=_fpc_ptrt(Result);';
      for I:=0 to Struct.SymTable.SymList.Count-1 do
        begin
          Sym:=TSym(Struct.SymTable.SymList[I]);
          if (Sym.Typ=FieldVarSym) then
            begin
              FSym:=TFieldVarSym(Sym);
              Str:=Str+'Res^.&'+FSym.RealName+':=&'+FSym.RealName+';';
            end;
        end;
      Str:=Str+'end;';
      Str_Parse_Method_Impl(Str,PD,False);
    end;


  procedure ImplementRecordInitialize(PD: TProcDef);
    var
      Struct: TAbstractRecordDef;
      Str: AnsiString;
      I: LongInt;
      Sym: TSym;
      FSym: TFieldVarSym;
    begin
      if not(PD.Struct.Typ in [RecordDef,ObjectDef]) then
        InternalError(2011071710);
      Struct:=PD.Struct;
      { anonymous record types must get an artificial name, so we can generate
        a typecast at the scanner level }
      if (Struct.Typ=RecordDef) and
         not Assigned(Struct.TypeSym) then
        InternalError(2011032804);
      { walk over all fields that need initialization }
      Str:='begin ';
      for I:=0 to Struct.SymTable.SymList.Count-1 do
        begin
          Sym:=TSym(Struct.SymTable.SymList[I]);
          if (Sym.Typ=FieldVarSym) then
            begin
              FSym:=TFieldVarSym(Sym);
              if FSym.VarDef.NeedsInitTable then
                Str:=Str+(internal_macro_escape_unit_namespace_name+'System.Initialize(&')+FSym.RealName+');';
            end;
        end;
      Str:=Str+'end;';
      Str_Parse_Method_Impl(Str,PD,False);
    end;

  procedure ImplementEmpty(PD: TProcDef);
    var
      Str: AnsiString;
      IsClassMethod: Boolean;
    begin
      IsClassMethod:=
        (po_classmethod in PD.ProcOptions) and
        not(PD.ProcTypeOption in [potype_constructor,potype_destructor]);
      Str:='begin end;';
      Str_Parse_Method_Impl(Str,PD,IsClassMethod);
    end;


  procedure AddVisibleParameters(var Str: AnsiString; PD: TProcDef);
    var
      CurrPara: TParaVarSym;
      I: LongInt;
      FirstPara: Boolean;
    begin
      FirstPara:=True;
      for I:=0 to PD.Paras.Count-1 do
        begin
          CurrPara:=TParaVarSym(PD.Paras[I]);
          if not(vo_is_hidden_para in CurrPara.VarOptions) then
            begin
              if not FirstPara then
                Str:=Str+',';
              FirstPara:=False;
              Str:=Str+'&'+CurrPara.RealName;
            end;
        end;
    end;



  procedure ImplementCallThrough(PD: TProcDef);
    var
      Str: AnsiString;
      CallPD: TProcDef;
      IsClassMethod: Boolean;
    begin
      IsClassMethod:=
        (po_classmethod in PD.ProcOptions) and
        not(PD.ProcTypeOption in [potype_constructor,potype_destructor]);
      CallPD:=TProcDef(PD.SKPara);
      Str:='begin ';
      if PD.ReturnDef<>VoidType then
        Str:=Str+'Result:=';
      { if the routine is a global routine in a unit/program, explicitly
        mnetion this program/unit name to avoid accidentally calling other
        same-named routines that may be in scope }
      Str:=Str+DefUnitNamePrefixIfTopLevel(CallPD)+CallPD.ProcSym.RealName+'(';
      AddVisibleParameters(Str,PD);
      Str:=Str+') end;';
      Str_Parse_Method_Impl(Str,PD,IsClassMethod);
    end;






  procedure ImplementFieldGetter(PD: TProcDef);
    var
      I: LongInt;
      PVS: TParaVarSym;
      Str: AnsiString;
      CallThroughProp: TPropertySym;
      PropAccessList: TPropAccessList;
      LastParaNr: LongInt;
      FirstPara: Boolean;
    begin
      CallThroughProp:=TPropertySym(PD.SKPara);
      Str:='begin Result:='+CallThroughProp.RealName;
      if ppo_hasparameters in CallThroughProp.PropOptions then
        begin
          if not CallThroughProp.GetPropAccessList(palt_read,PropAccessList) then
            InternalError(2012100701);
          Str:=Str+'[';
          FirstPara:=True;
          LastParaNr:=TProcDef(PropAccessList.ProcDef).Paras.Count-1;
          if ppo_indexed in CallThroughProp.PropOptions then
            Dec(LastParaNr);
          for I:=0 to LastParaNr do
            begin
              { skip self/vmt/parentfp, passed implicitly }
              PVS:=TParaVarSym(TProcDef(PropAccessList.ProcDef).Paras[I]);
              if ([vo_is_self,vo_is_vmt,vo_is_parentfp]*PVS.VarOptions)<>[] then
                Continue;
              if not FirstPara then
                Str:=Str+',';
              FirstPara:=False;
              Str:=Str+PVS.RealName;
            end;
          Str:=Str+']';
        end;
      Str:=Str+'; end;';
      Str_Parse_Method_Impl(Str,PD,po_classmethod in PD.ProcOptions)
    end;


  procedure ImplementFieldSetter(PD: TProcDef);
    var
      I, LastParaIndex: LongInt;
      PVS: TParaVarSym;
      ParaName,  Str: AnsiString;
      CallThroughProp: TPropertySym;
      PropAccessList: TPropAccessList;
      FirstPara: Boolean;
    begin
      CallThroughProp:=TPropertySym(PD.SKPara);
      Str:='begin '+CallThroughProp.RealName;
      if not CallThroughProp.GetPropAccessList(palt_write,PropAccessList) then
        InternalError(2012100702);
      if ppo_hasparameters in CallThroughProp.PropOptions then
        begin
          Str:=Str+'[';
          FirstPara:=True;
          { last parameter is the value to be set, skip (only add index
            parameters here) }
          LastParaIndex:=TProcDef(PropAccessList.ProcDef).Paras.Count-2;
          if ppo_indexed in CallThroughProp.PropOptions then
            Dec(LastParaIndex);
          for I:=0 to LastParaIndex do
            begin
              { skip self/vmt/parentfp/index, passed implicitly }
              PVS:=TParaVarSym(TProcDef(PropAccessList.ProcDef).Paras[I]);
              if ([vo_is_self,vo_is_vmt,vo_is_parentfp]*PVS.VarOptions)<>[] then
                Continue;
              if not FirstPara then
                Str:=Str+',';
              FirstPara:=False;
              Str:=Str+PVS.RealName;
            end;
          Str:=Str+']';
        end;
      { the value-to-be-set }
      if Assigned(PropAccessList.ProcDef) then
        begin
          PVS:=TParaVarSym(TProcDef(PropAccessList.ProcDef).Paras[TProcDef(PropAccessList.ProcDef).Paras.Count-1]);
          ParaName:=PVS.RealName;
        end
      else
        ParaName:='__fpc_newval__';
      Str:=Str+':='+ParaName+'; end;';
      Str_Parse_Method_Impl(Str,PD,po_classmethod in PD.ProcOptions)
    end;


  procedure ImplementBlockInvokeProcVar(PD: TProcDef);
    var
      Str: AnsiString;
    begin
      Str:='';
      Str:='begin ';
      if PD.ReturnDef<>VoidType then
        Str:=Str+'Result:=';
      Str:=Str+'__FPC_BLOCK_INVOKE_PV_TYPE(PFPC_Block_literal_complex_procvar(FPC_Block_Self)^.pv)(';
      AddVisibleParameters(Str,PD);
      Str:=Str+') end;';
      Str_Parse_Method_Impl(Str,PD,False);
    end;


  procedure ImplementInterfaceWrapper(PD: TProcDef);
    var
      WrapperInfo: PSKParaInterfaceWrapper;
      CallThroughPD, TmpProc: TProcDef;
      Str: AnsiString;
      FileInfo: TFilePosInfo;
    begin
      WrapperInfo:=PSKParaInterfaceWrapper(PD.SKPara);
      if not Assigned(WrapperInfo) then
        InternalError(2015090801);
      CallThroughPD:=TProcDef(WrapperInfo^.PD);
      Str:='begin ';
      { self right now points to the VMT of interface inside the instance ->
        adjust so it points to the start of the instance }
      Str:=Str+'Pointer(Self):=Pointer(Self) - '+ToStr(WrapperInfo^.Offset)+';';
      { now call through to the actual method }
      if PD.ReturnDef<>VoidType then
        Str:=Str+'Result:=';
      Str:=Str+'&'+CallThroughPD.ProcSym.RealName+'(';
      AddVisibleParameters(Str,PD);
      Str:=Str+') end;';
      { add dummy file info so we can step in/through it }
      if PD.Owner.IsCurrentUnit then
        FileInfo:=PD.FileInfo
      else
        begin
          FileInfo.ModuleIndex:=CurrentModule.ModuleID;
          FileInfo.FileIndex:=1;
          FileInfo.Line:=1;
          FileInfo.Column:=1;
        end;
      StrParseMethodImplWithFileInfo(Str,PD,FileInfo.FileIndex,FileInfo.Line,False,TmpProc);
      Dispose(WrapperInfo);
      PD.SKPara:=nil;
    end;


  procedure ImplementCallNoParameters(PD: TProcDef);
    var
      CallPD: TProcDef;
      Str: AnsiString;
      WarningsOn,
      IsClassMethod: Boolean;
    begin
      { avoid warnings about unset function results in these abstract wrappers }
      WarningsOn:=(Status.Verbosity and VWarning)<>0;
      SetVerbosity('W-');
      Str:='begin ';
      CallPD:=TProcDef(PD.SKPara);
      Str:=Str+DefUnitNamePrefixIfTopLevel(CallPD)+CallPD.ProcSym.RealName+'; end;';
      IsClassMethod:=
        (po_classmethod in PD.ProcOptions) and
        not(PD.ProcTypeOption in [potype_constructor,potype_destructor]);
      Str_Parse_Method_Impl(Str,PD,IsClassMethod);
      if WarningsOn then
        SetVerbosity('W+');
    end;

  function GetMethodParamType(VarDef  : TDef; AsPointer : Boolean; out IsAnonymousArrayDef : Boolean) : AnsiString; forward;

  function StrParseMethod(Str: AnsiString; AllowGenericID : Boolean): TProcDef; forward;

  function StrParseMethod(Str: AnsiString): TProcDef;
  begin
     Result:=StrParseMethod(Str,False);
  end;

  procedure ImplementInvokeHelper(CN : string;PD: TProcDef; Idx : Integer);

    var
      SArg,Str : AnsiString;
      PT, PN,D : ShortString;
      Sym : TSym;
      AArg,ArgCount,I : Integer;
      IsArray,HaveResult : Boolean;
      Para : TParaVarSym;
      HasOpenArray, WasHigh: Boolean;

    begin
      Str:='procedure __invoke_helper__';
      PN:=PD.ProcSym.RealName;
      Str:=Str+CN+'__'+PN+'_'+ToStr(Idx);
      for I:=1 to Length(Str) do
        if Str[I]='.' then
          Str[I]:='_';
      Str:=Str+'(Instance : Pointer; Args : PPointer);'#10;
      ArgCount:=0;
      for I:=0 to PD.Paras.Count-1 do
        begin
          Para:=TParaVarSym(PD.Paras[I]);
          if vo_is_hidden_para in Para.VarOptions then
            Continue;
          Inc(ArgCount);
          if ArgCount=1 then
            Str:=Str+'Type'#10;
          PT:=GetMethodParamType(Para.VarDef,True,IsArray);
          if IsArray then
            begin
            Str:=Str+'  TPA'+ToStr(ArgCount)+' = '+PT+';'#10;
            PT:='^TPA'+ToStr(ArgCount);
            end;
          Str:=Str+'  TP'+ToStr(ArgCount)+' = '+PT+';'#10;
        end;
      HaveResult:=PD.ReturnDef<>VoidType;
      if HaveResult then
        begin
        if ArgCount=0 then
          Str:=Str+'Type'#10;
        PT:=GetMethodParamType(PD.ReturnDef ,True,IsArray);
        if IsArray then
          begin
          Str:=Str+'  TRA'+ToStr(ArgCount)+' = '+PT+';'#10;
          PT:='^TRA';
          end;
        Str:=Str+'  TR = '+PT+';'#10;
        end;
      Str:=Str+'begin'#10'  ';
      if HaveResult then
        Str:=Str+'TR(Args[0])^:=';
      Str:=Str+CN+'(Instance).'+PN+'(';
      ArgCount:=0;
      for I:=0 to PD.Paras.Count-1 do
        begin
          Para:=TParaVarSym(PD.Paras[I]);
          if vo_is_hidden_para in Para.VarOptions then
            Continue;
          Inc(ArgCount);
          SArg:=ToStr(ArgCount);
          if ArgCount>1 then
            Str:=Str+',';
          Str:=Str+'TP'+SArg+'(Args['+SArg+'])^';
        end;
      Str:=Str+');'#10;
      Str:=Str+'end;'#10;
      PD.InvokeHelper:=StrParseMethod(Str,True);
  end;

  procedure AddSyntheticMethodImplementationsForST(ST: TSymTable);
    var
      I   : LongInt;
      Def : TDef;
      PD  : TProcDef;
      CN  : ShortString;
    begin
      for I:=0 to ST.DefList.Count-1 do
        begin
          Def:=TDef(ST.DefList[I]);
          if (Def.Typ<>ProcDef) then
            Continue;
          { skip methods when processing unit symtable }
          if Def.Owner<>ST then
            Continue;
          PD:=TProcDef(Def);
          case PD.SyntheticKind of
            tsk_none:
              ;
            tsk_record_deepcopy:
              ImplementRecordDeepCopy(PD);
            tsk_record_initialize:
              ImplementRecordInitialize(PD);
            tsk_empty,
            { special handling for this one is done in tnodeutils.wrap_proc_body }
            tsk_tcinit:
              ImplementEmpty(PD);
            tsk_callthrough:
              ImplementCallThrough(PD);
            tsk_callthrough_nonabstract:
              begin
                if (PD.Owner.DefOwner.Typ<>ObjectDef) or
                   (TObjectDef(PD.Owner.DefOwner).AbstractCnt=0) then
                  ImplementCallThrough(PD)
                else
                  ImplementEmpty(PD);
              end;
            tsk_wasm_suspending_first,
            tsk_wasm_suspending_last,
            tsk_wasm_promising:
              InternalError(2023061107);
            tsk_field_getter:
              ImplementFieldGetter(PD);
            tsk_field_setter:
              ImplementFieldSetter(PD);
            tsk_block_invoke_procvar:
              ImplementBlockInvokeProcVar(PD);
            tsk_interface_wrapper:
              ImplementInterfaceWrapper(PD);
            tsk_call_no_parameters:
              ImplementCallNoParameters(PD);
            tsk_invoke_helper:
              begin
                if (PD.Owner.DefOwner) is TObjectDef  then
                  CN:=TObjectDef(Def.Owner.DefOwner).GetTypeName
                else
                  InternalError(2023061107);
                ImplementInvokeHelper(CN,PD,I);
              end;
          end;
        end;
    end;

  function GetMethodParamType(VarDef  : TDef; AsPointer : Boolean; out IsAnonymousArrayDef : Boolean) : AnsiString;

  var
    P : Integer;
    ArrDef : TArrayDef absolute VarDef;

  begin
    {
      None of the existing routines fulltypename,OwnerHierarchyName,FullOwnerHierarchyName,typename
      results in a workable definition for open array parameters.
    }
    IsAnonymousArrayDef:=False;
    if AsPointer and (VarDef.Typ=FormalDef) then
      Exit('Pointer');
    if (VarDef is TProcVarDef) then
      begin
      Result:=VarDef.FullOwnerHierarchyName(False,False);
      if Assigned(VarDef.TypeSym) then
        Result:=Result+(VarDef.TypeSym.Name);
      end
    else if not (VarDef is TArrayDef) then
      Result:=VarDef.FullTypeName
    else
      begin
      if (ado_isarrayofconst in ArrDef.ArrayOptions) then
        begin
          if AsPointer then
            Result:='Array of TVarRec'
          else
            Result:='Array Of Const';
          AsPointer:=False;
          IsAnonymousArrayDef:=True;
        end
      else if (ado_OpenArray in ArrDef.ArrayOptions) then
        begin
        Result:='Array of '+ArrDef.ElementDef.FullTypeName;
        AsPointer:=False;
        IsAnonymousArrayDef:=True;
        end
      else
        begin
        Result:=VarDef.FullTypeName;
        end;
      end;
    // ansistring(0) -> ansistring
    P:=Pos('(',Result);
    if P=0 then
      P:=Pos('[',Result);
    if P>0 then
      Result:=Copy(Result,1,P-1);
    if AsPointer then
      Result:='^'+Result;
  end;

  function GetMethodParamType(VarDef  : TDef; AsPointer : Boolean) : AnsiString;

  var
    AD : Boolean;

  begin
    Result:=GetMethodParamType(VarDef,AsPointer,AD);
  end;

  function CreateIntfMethodArgs(P : TProcDef; out ArgCount: Integer) : AnsiString;

  const
    VarSpezPrefixes : array[TVarSpez] of ShortString =
      ('','const','var','out','constref','final');
  var
    I : Integer;
    S : string;
    Para : TParaVarSym;


  begin
    Result:='';
    ArgCount:=0;
    for I:=0 to P.Paras.Count-1 do
      begin
      Para:=TParaVarSym(P.Paras[I]);
      if vo_is_hidden_para in Para.VarOptions then
        Continue;
      if Result<>'' then
        Result:=Result+';';
      Inc(ArgCount);
      Result:=Result+VarSpezPrefixes[Para.VarSpez]+' p'+ToStr(ArgCount);
      if Assigned(Para.VarDef) and not (Para.VarDef is TFormalDef) then
        Result:=Result+' : '+GetMethodParamType(Para.VarDef,False);
      end;
    if Result<>'' then
      Result:='('+Result+')';
  end;

  function GenerateThunkClassName(ACount: Integer; ObjDef : TObjectDef) : ShortString;

  var
    CN : ShortString;
    I : Integer;

  begin
    CN:=ObjDef.GetTypeName;
    for I:=0 to Length(CN) do
      begin
      if CN[I]='.' then
        CN[I]:='_'
      else if (CN[I]='<') or (CN[I]='>') then
        CN[I]:='_';
      end;
    Result:='_t_hidden'+ToStr(ACount)+CN;
  end;

  function GetThunkClassInterfaceVMTOffset(ObjDef : TObjectDef) : Integer;

  var
    I,J,Offs : Integer;
    Sym : TSym;
    Proc : TProcSym absolute Sym;
    PD : TProcDef;

  begin
    Offs:=MaxInt;
    for I:=0 to ObjDef.SymTable.SymList.Count-1 do
      begin
      Sym:=TSym(ObjDef.SymTable.SymList[I]);
      if Not Assigned(Sym) then
        Continue;
      if (Sym.Typ<>ProcSym) then
        Continue;
      for J:=0 to Proc.ProcdefList.Count-1 do
        begin
        PD:=TProcDef(Proc.ProcdefList[J]);
        if PD.ExtNumber<Offs then
          Offs:=PD.ExtNumber;
        end;
      end;
      if Offs=MaxInt then
        Offs:=0;
      Result:=Offs;
    end;


  // return parent Interface def, but skip iunknown.

  function GetParentInterfaceDef(ODef : TObjectDef) : TObjectDef;

  begin
    if (ODef.GetParentDef is TObjectDef) then
      begin
      Result:=ODef.GetParentDef as TObjectDef;
      if Result=Interface_IUnknown then
        Result:=Nil;
      end
    else
      Result:=nil;
  end;

  procedure ImplementInterfaceThunkClassDecl(CN : ShortString; ObjDef : TObjectDef);

  var
    ParentName,Str : AnsiString;
    Sym : TSym;
    Proc : TProcSym absolute Sym;
    PD : TProcDef;
    ODef,Def : TObjectDef;
    Offs,ArgCount,I,J : Integer;
    IntfDef : TObjectDef;
  begin
    Str:='type '#10;
    ODef:=GetParentInterfaceDef(ObjDef);
    if (ODef=Nil) or (ODef.HiddenClassDef=Nil) then
      ParentName:='TInterfaceThunk'
    else
      ParentName:=ODef.HiddenClassDef.GetTypeName;
    Str:=Str+CN+' = class('+ParentName+','+ObjDef.GetTypeName+')'#10;
    Str:=Str+' protected '#10;
    IntfDef:=ObjDef;
    Repeat
      if not IntfDef.Is_Generic then
        for I:=0 to IntfDef.SymTable.SymList.Count-1 do
          begin
          Sym:=TSym(IntfDef.SymTable.SymList[I]);
          if Not Assigned(Sym) then
            Continue;
          if (Sym.Typ<>ProcSym) then
            Continue;
          for J:=0 to Proc.ProcdefList.Count-1 do
            begin
            PD:=TProcDef(Proc.ProcdefList[J]);
            if PD.ReturnDef<>VoidType then
              Str:=Str+'function '
            else
              Str:=Str+'procedure ';
            Str:=Str+Proc.RealName;
            Str:=Str+CreateIntfMethodArgs(PD,ArgCount);
            if PD.ReturnDef<>VoidType then
              Str:=Str+' : '+GetMethodParamType(PD.ReturnDef,False);
            Str:=Str+';'#10;
            end;
          end;
      // Check parent class
      IntfDef:=GetParentInterfaceDef(IntfDef);
      // If we already have a hidden class def for it, no need to continue
      if (IntfDef<>nil) and (IntfDef.HiddenClassDef<>nil) then
        IntfDef:=Nil;
    until IntfDef=nil;
    Offs:=GetThunkClassInterfaceVMTOffset(ObjDef);
    if Offs>0 then
      begin
      Str:=Str+'public '#10;
      Str:=Str+'  function InterfaceVMTOffset : Word; override;'#10;
      end;
    Str:=Str+' end;'#10;
    Def:=StrParseObjectTypeDef(CN,Str);
    if Assigned(Def) then
      begin
      Def.CreatedInCurrentModule:=True;
      if not Def.TypeSym.IsRegistered then
        Def.TypeSym.RegisterSym;
      Def.BuildDeref;
      Include(Def.ObjectOptions,oo_can_have_published);
      end;
    ObjDef.HiddenClassDef:=Def;
  end;

  function StrParseMethod(Str: AnsiString; AllowGenericID : Boolean): TProcDef;
   var
     OldParseOnly: Boolean;
     TmpStr: AnsiString;
     Flags : TReadProcFlags;
     OldAllow : Boolean;

   begin
    Message1(parser_d_internal_parser_string,Str);
    OldParseOnly:=parse_only;
    parse_only:=False;
    { "const" starts a new kind of block and hence makes the scanner return }
    Str:=Str+'const;';
    Block_Type:=bt_none;
    { inject the string in the scanner }
    OldAllow:=CurrentScanner.AllowGenericID;
    CurrentScanner.AllowGenericID:=AllowGenericID;
    CurrentScanner.SubstituteMacro('hidden_interface_method',@Str[1],Length(Str),CurrentScanner.line_no,CurrentScanner.InputFile.RefIndex,True);
    CurrentScanner.ReadToken(False);
    Result:=read_proc([],Nil);
    parse_only:=OldParseOnly;
    { remove the temporary macro input file again }
    CurrentScanner.CloseInputFile;
    CurrentScanner.NextFile;
    CurrentScanner.TempOpenInputFile;
    CurrentScanner.AllowGenericID:=OldAllow;
   end;


  procedure ImplementInterfaceThunkClassImplMethod(CN : ShortString; ObjDef : TObjectDef; Proc : TProcSym; PD : TProcDef);

  var
    Rest,Str : AnsiString;
    PN,D : ShortString;
    Sym : TSym;
    AArg,ArgCount,I : Integer;
    HaveResult : Boolean;
    Para : TParaVarSym;
    HasOpenArray, WasHigh: Boolean;

  begin
    Rest:='';
    Str:='';
    if PD.ReturnDef<>VoidType then
      Str:=Str+'function '
    else
      Str:=Str+'procedure ';
    PN:=Proc.RealName;
    Str:=Str+CN+'.'+PN;
    Str:=Str+CreateIntfMethodArgs(PD,ArgCount);
    HaveResult:=PD.ReturnDef<>VoidType;
    if HaveResult then
      begin
      Rest:=GetMethodParamType(PD.ReturnDef,False);
      Str:=Str+' : '+Rest;
      end;
    Str:=Str+';'#10;
    Str:=Str+'var '#10;
    Str:=Str+'  Data : array[0..'+ToStr(ArgCount)+'] of System.TInterfaceThunk.TArgData;'#10;
    if HaveResult then
      Str:=Str+'  Res : '+Rest+';'#10;
    Str:=Str+'begin'#10;
    // initialize result.
    if HaveResult then
      begin
      Str:=Str+'  Data[0].Addr:=@Res;'#10;
      Str:=Str+'  Data[0].Info:=TypeInfo(Res);'#10;
      end
    else
      begin
      Str:=Str+'  Data[0].Addr:=nil;'#10;
      Str:=Str+'  Data[0].Idx:=-1;'#10;
      end;
    Str:=Str+'  Data[0].Idx:=-1;'#10;
    Str:=Str+'  Data[0].AHigh:=-1;'#10;
    // Fill rest of data
    AArg:=0;
    WasHigh:=False;
    D:='0';
    for I:=0 to PD.Paras.Count-1 do
      begin
      Para:=TParaVarSym(PD.Paras[I]);
      // previous was open array. Record high
      if (I>1) then
        begin
        WasHigh:=(vo_is_high_para in Para.VarOptions);
        if WasHigh then
          // D is still value of previous (real) parameter
          Str:=Str+'  Data['+D+'].AHigh:=High(p'+D+');'#10
        else
          Str:=Str+'  Data['+D+'].AHigh:=-1;'#10;
        end;
      if vo_is_hidden_para in Para.VarOptions then
        Continue;
      Inc(AArg);
      D:=ToStr(AArg);
      Str:=Str+'  Data['+D+'].Addr:=@p'+D+';'#10;
      Str:=Str+'  Data['+D+'].Idx:='+ToStr(I)+';'#10;
      if Assigned(Para.VarDef) and not (Para.VarDef is TFormalDef) then
        Str:=Str+'  Data['+D+'].Info:=TypeInfo(p'+D+');'#10
      else
        Str:=Str+'  Data['+D+'].Info:=Nil;'#10
      end;
    // if last was not high, set to sentinel.
    if not WasHigh then
      Str:=Str+'  Data['+D+'].AHigh:=-1;'#10;
    Str:=Str+'  Thunk('+ToStr(PD.ExtNumber)+','+ToStr(ArgCount)+',@Data);'#10;
    if HaveResult then
      Str:=Str+'  Result:=Res;'#10;
    Str:=Str+'end;'#10;
    PD:=StrParseMethod(Str,True);
  end;

  procedure ImplementThunkClassInterfaceVMTOffset(CN : ShortString; ObjDef : TObjectDef; Offs : Integer);

  var
    Str : AnsiString;
  begin
    Str:='function '+CN+'.InterfaceVMTOffset : Word;'#10;
    Str:=Str+'begin'#10;
    Str:=Str+'  Result:='+ToStr(Offs)+';'#10;
    Str:=Str+'end;'#10;
    StrParseMethod(Str);
  end;


  procedure ImplementInterfaceThunkClassImpl(CN: ShortString; ObjDef : TObjectDef);

  var
    Str : AnsiString;
    Sym : TSym;
    Proc : TProcSym absolute Sym;
    PD : TProcDef;
    Offs,I,J : Integer;
    IntfDef : TObjectDef;

  begin
    Offs:=GetThunkClassInterfaceVMTOffset(ObjDef);
    if Offs>0 then
      ImplementThunkClassInterfaceVMTOffset(CN,ObjDef,Offs);
    IntfDef:=ObjDef;
    repeat
      for I:=0 to IntfDef.SymTable.SymList.Count-1 do
        begin
        Sym:=TSym(IntfDef.SymTable.SymList[I]);
        if Not Assigned(Sym) then
          Continue;
        if (Sym.Typ<>ProcSym) then
          Continue;
        for J:=0 to Proc.ProcdefList.Count-1 do
          begin
          PD:=TProcDef(Proc.ProcdefList[J]);
          ImplementInterfaceThunkClassImplMethod(CN,IntfDef,Proc,PD);
          end;
        end;
      // Check parent class.
      IntfDef:=GetParentInterfaceDef(IntfDef);
      // If we already have a hidden class def for it, no need to continue
      if (IntfDef<>Nil) and (IntfDef.HiddenClassDef<>nil) then
        IntfDef:=Nil;
    until (IntfDef=Nil);
  end;

  procedure Add_Synthetic_Interface_Classes_For_ST(ST : TSymTable; GenIntf, GenImpl : Boolean);

  var
    I   : LongInt;
    Def : TDef;
    ObjDef : TObjectDef absolute Def;
    RecDef : TRecordDef absolute Def;
    SState: TScannerState;
    CN : ShortString;
    IsDelphiMode : Boolean;
    OldSettings: TModeSwitches;

  begin
    { skip if any errors have occurred, since then this can only cause more
      errors }
    if ErrorCount<>0 then
      Exit;
    IsDelphiMode:=(m_delphi in CurrentSettings.ModeSwitches);
    Replace_Scanner('hiddenclass_impl',SState);
    SState.NewScanner.AllowGenericID:=True;
    if IsDelphiMode then
      begin
      OldSettings:=CurrentSettings.ModeSwitches;
      CurrentSettings.ModeSwitches:=CurrentSettings.ModeSwitches+[m_delphi]-[m_objfpc];
      end;
    for I:=0 to ST.DefList.Count-1 do
      begin
      Def:=TDef(ST.DefList[I]);
      if (Def.Typ<>ObjectDef) then
        Continue;
      if not (ObjDef.ObjectType in ObjectTypesWithThunk) then
        Continue;
      if not (oo_can_have_published in ObjDef.ObjectOptions) then
        Continue;
      // need to add here extended rtti check when it is available
      CN:=GenerateThunkClassName(I,ObjDef);
      if GenIntf then
        ImplementInterfaceThunkClassDecl(CN,ObjDef);
      if GenImpl then
        ImplementInterfaceThunkClassImpl(CN,ObjDef);
      end;
    Restore_Scanner(SState);
    // Recurse for interfaces defined in a type section of a class/record.
    for I:=0 to ST.DefList.Count-1 do
      begin
      Def:=TDef(ST.DefList[I]);
      if (Def.Typ=ObjectDef) and (ObjDef.ObjectType=odt_class) then
        Add_Synthetic_Interface_Classes_For_ST(ObjDef.SymTable,GenIntf,GenImpl)
      else if (Def.Typ=RecordDef) and (m_advanced_records in CurrentSettings.ModeSwitches) then
        Add_Synthetic_Interface_Classes_For_ST(RecDef.SymTable,GenIntf,GenImpl);
      end;
  end;

  procedure Add_Synthetic_Method_Implementations(ST: TSymTable);
    var
      I: LongInt;
      Def: TDef;
      SState: TScannerState;
    begin
      { skip if any errors have occurred, since then this can only cause more
        errors }
      if ErrorCount<>0 then
        Exit;
      Replace_Scanner('synthetic_impl',SState);
      AddSyntheticMethodImplementationsForST(ST);
      for I:=0 to ST.DefList.Count-1 do
        begin
          Def:=TDef(ST.DefList[I]);
          if (Def.Typ=ProcDef) and
             Assigned(TProcDef(Def).LocalST) and
             { not true for the "main" procedure, whose localsymtable is the staticsymtable }
             (TProcDef(Def).LocalST.SymTableType=LocalSymTable) then
            Add_Synthetic_Method_Implementations(TProcDef(Def).LocalST)
          else if ((Def.Typ=ObjectDef) and
                   not(oo_is_external in TObjectDef(Def).ObjectOptions) and
                   { we must not create duplicate synthetic methods for a unique
                     type declaration as that simply shares the VMT of the aliased
                     types }
                   not(TObjectDef(Def).Is_Unique_ObjPasDef)) or
                  (Def.Typ=RecordDef) then
           begin
            { also complete nested types }
            Add_Synthetic_Method_Implementations(TAbstractRecordDef(Def).SymTable);
           end;
        end;
      Restore_Scanner(SState);
    end;


  function Create_ProcDef_Alias(PD: TProcDef; const NewRealName: string; const NewMangledName: TSymStr; NewParentST: TSymTable; NewStruct: TAbstractRecordDef;
      SK: TSyntheticKind; SKPara: Pointer): TProcDef;
    begin
      { bare copy so we don't copy the aliasnames (specify prefix for
        parameter names so we don't get issues in the body in case
        we e.g. reference system.initialize and one of the parameters
        is called "system") }
      Result:=TProcDef(PD.GetCopyAs(ProcDef,pc_bareproc,'__FPCW_',True));
      { set the mangled name to the wrapper name }
      Result.SetMangledName(NewMangledName);
      { finish creating the copy }
      Finish_Copied_ProcDef(Result,NewRealName,NewParentST,NewStruct);
      { insert hidden high parameters }
      Result.ParaST.SymList.ForEachCall(@insert_hidden_para,Result);
      { now insert self/vmt }
      insert_self_and_vmt_para(Result);
      { and the function result }
      insert_funcret_para(Result);
      { recalculate the parameters now that we've added the missing ones }
      Result.CalcParas;
      { set the info required to generate the implementation }
      Result.SyntheticKind:=SK;
      Result.SKPara:=SKPara;
    end;


  procedure Finish_Copied_ProcDef(var PD: TProcDef; const RealName: string; NewParentST: TSymTable; NewStruct: TAbstractRecordDef);
    var
      Sym: TSym;
      PArasym: TParaVarSym;
      PS: TProcSym;
      STName: string;
      I: LongInt;
    begin
      { add generic flag if required }
      if Assigned(NewStruct) and
         (df_generic in NewStruct.DefOptions) then
        Include(PD.DefOptions,df_generic);
      { associate the procdef with a procsym in the owner }
      if not(PD.ProcTypeOption in [potype_class_constructor,potype_class_destructor]) then
        STName:=Upper(RealName)
      else
        STName:=Lower(RealName);
      Sym:=TSym(NewParentST.Find(STName));
      if Assigned(Sym) then
        begin
          if Sym.Typ<>ProcSym then
            InternalError(2011040601);
          PS:=TProcSym(Sym);
        end
      else
        begin
          PS:=CProcSym.Create(RealName);
          NewParentST.InsertSym(PS);
        end;
      PD.ProcSym:=PS;
      PD.Struct:=NewStruct;
      { in case of methods, replace the special parameter types with new ones }
      if Assigned(NewStruct) then
        begin
          SymTableStack.Push(PD.ParaST);
          { may not be assigned in case we converted a procvar into a procdef }
          if Assigned(PD.Paras) then
            begin
              for I:=0 to PD.Paras.Count-1 do
                begin
                  PArasym:=TParaVarSym(PD.Paras[I]);
                  if vo_is_self in PArasym.VarOptions then
                    begin
                      if PArasym.VarDef.Typ=ClassRefDef then
                        PArasym.VarDef:=CClassRefDef.Create(NewStruct)
                      else
                        PArasym.VarDef:=NewStruct;
                    end
                end;
            end;
          { also fix returndef in case of a constructor }
          if PD.ProcTypeOption=potype_constructor then
            PD.ReturnDef:=NewStruct;
          SymTableStack.Pop(PD.ParaST);
        end;
      PD.CalcParas;
      proc_add_definition(PD);
    end;


  function Maybe_Add_Sym_To_ParentFPStruct(PD: TProcDef; Sym: TSym; VarDef: TDef; AddrParam: Boolean): TSym;
    var
      FieldVarDef,
      NestedVarsDef: TDef;
      NestedVarsST: TSymTable;
      InitCode: TNode;
      OldFilePos: TFilePosInfo;
      SymName,
      SymRealName: TSymStr;
      HighSym: TAbstractVarSym;
    begin
      NestedVarsDef:=TLocalVarSym(PD.ParentFPStruct).VarDef;
      { redirect all aliases for the function result also to the function
        result }
      if vo_is_funcret in TAbstractVarSym(Sym).VarOptions then
        begin
          SymName:='Result';
          SymRealName:='$Result'
        end
      else
        begin
          SymName:=Sym.Name;
          SymRealName:=Sym.EscapedRealName;
        end;
      Result:=Search_Struct_Member(TRecordDef(NestedVarsDef),SymName);
      if not Assigned(Result) then
        begin
          { mark that this symbol is mirrored in the parentfpstruct }
          TAbstractNormalVarSym(Sym).InParentFPStruct:=True;
          { add field to the struct holding all locals accessed
            by nested routines }
          NestedVarsST:=TRecordDef(NestedVarsDef).SymTable;
          { indicate whether or not this is a var/out/constref/... parameter }
          if AddrParam then
            FieldVarDef:=CPointerDef.GetReusable(VarDef)
          else
            FieldVarDef:=VarDef;
          Result:=CFieldVarSym.Create(SymRealName,vs_value,FieldVarDef,[]);
          NestedVarsST.InsertSym(Result);
          TRecordSymTable(NestedVarsST).AddField(TFieldVarSym(Result),vis_public);

          { add initialization with original value if it's a parameter }
          if (Sym.Typ=ParaVarSym) then
            begin
              OldFilePos:=CurrentFilePos;
              FillChar(CurrentFilePos,SizeOf(CurrentFilePos),0);
              InitCode:=CLoadNode.Create(Sym,Sym.Owner);
              { indicate that this load should not be transformed into a load
                from the parentfpstruct, but instead should load the original
                value }
              Include(InitCode.Flags,nf_internal);
              { in case it's a var/out/constref parameter, store the address of the
                parameter in the struct }
              if AddrParam then
                begin
                  InitCode:=CAddrNode.Create_Internal(InitCode);
                  Include(TAddrNode(InitCode).AddrNodeFlags,anf_typedaddr);
                end;
              InitCode:=CAssignmentNode.Create(
                CSubscriptNode.Create(Result,CLoadNode.Create(PD.ParentFPStruct,PD.ParentFPStruct.Owner)),
                InitCode);
              TBlockNode(PD.ParentFPInitBlock).Left:=CStatementNode.Create
                (InitCode,TBlockNode(PD.ParentFPInitBlock).Left);
              CurrentFilePos:=OldFilePos;

              { also add the associated high para, if any. It may not be accessed
                during code generation, and we need to catch 'em all (TM) during
                the typecheck/firstpass }
              HighSym:=Get_High_Value_Sym(TParaVarSym(Sym));
              if Assigned(HighSym) then
                Maybe_Add_Sym_To_ParentFPStruct(PD, HighSym, HighSym.VarDef, False);
            end;
        end;
    end;


  procedure Redirect_ParentFPStruct_Local_Syms(PD: TProcDef);
    var
      NestedVarsDef: TRecordDef;
      SL: TPropAccessList;
      FSym,
      LSym,
      AliasSym: TSym;
      I: LongInt;
    begin
      NestedVarsDef:=TRecordDef(TLocalVarSym(PD.ParentFPStruct).VarDef);
      for I:=0 to NestedVarsDef.SymTable.SymList.Count-1 do
        begin
          FSym:=TSym(NestedVarsDef.SymTable.SymList[I]);
          if FSym.Typ<>FieldVarSym then
            Continue;
          LSym:=TSym(PD.LocalST.Find(FSym.Name));
          if not Assigned(LSym) then
            LSym:=TSym(PD.ParaST.Find(FSym.Name));
          if not Assigned(LSym) then
            InternalError(2011060408);
          { add an absolute variable that redirects to the field }
          SL:=TPropAccessList.Create;
          SL.AddSym(sl_load,PD.ParentFPStruct);
          SL.AddSym(sl_subscript,TFieldVarSym(FSym));
          AliasSym:=CAbsoluteVarSym.Create_Ref(LSym.EscapedRealName,TFieldVarSym(FSym).VarDef,SL);
          { hide the original variable (can't delete, because there
            may be other loadnodes that reference it)
            -- only for locals; hiding parameters changes the
            function signature }
          if LSym.Typ<>ParaVarSym then
            HideSym(LSym);
          { insert the absolute variable in the localst of the
            routine; ignore duplicates, because this will also check the
            parasymtable and we want to override parameters with our local
            versions }
          PD.LocalST.InsertSym(AliasSym,False);
        end;
    end;


  function Find_Sym_In_ParentFPStruct(PD: TProcDef; Sym: TSym): TSym;
    var
      NestedVarsDef: TDef;
    begin
      NestedVarsDef:=TLocalVarSym(PD.ParentFPStruct).VarDef;
      Result:=Search_Struct_Member(TRecordDef(NestedVarsDef),Sym.Name);
    end;


  procedure Finish_ParentFPStruct(PD: TProcDef);
    begin
      TRecordSymTable(TRecordDef(TLocalVarSym(PD.ParentFPStruct).VarDef).SymTable).AddAlignmentPadding;
    end;


  function Make_Field_Static(RecST: TSymTable; FieldVS: TFieldVarSym): TStaticVarSym;
    var
      StaticName: string;
      HStaticVS: TStaticVarSym;
      Tmp: TAbsoluteVarSym;
      SL: TPropAccessList;
    begin
      Include(FieldVS.SymOptions,sp_static);
      { generate the symbol which reserves the space }
      StaticName:=Lower(Generate_Nested_Name(RecST,'_'))+'_'+FieldVS.Name;
      HStaticVS:=CStaticVarSym.Create_From_FieldVar(StaticName,FieldVS);
      Include(HStaticVS.SymOptions,sp_internal);
      if df_generic in TDef(RecST.DefOwner).DefOptions then
        TAbstractRecordSymTable(RecST).InsertSym(HStaticVS)
      else
        TDef(TAbstractRecordSymTable(RecST).DefOwner).GetTopLevelSymTable(False).InsertSym(HStaticVS);
      { generate the symbol for the access }
      SL:=TPropAccessList.Create;
      SL.AddSym(sl_load,HStaticVS);
      { do *not* change the visibility of this absolutevarsym from vis_public
        to anything else, because its visibility is used by visibility checks
        after turning a class property referring to a class variable into a
        load node (handle_staticfield_access -> searchsym_in_class ->
        is_visible_for_object), which means that the load will fail if this
        symbol is e.g. "strict private" while the property is public }
      Tmp:=CAbsoluteVarSym.Create_Ref('$'+StaticName,FieldVS.VarDef,SL);
      RecST.InsertSym(Tmp);
      Result:=HStaticVS;
    end;


  procedure Call_Through_New_Name(OrgPD: TProcDef; const NewName: TSymStr);
    var
      NewPD: TProcDef;
    begin
      { we have a forward declaration like
         procedure test; (in the unit interface or "forward")
        and then an implementation like
         procedure test; external name 'something';

        To solve this, we create a new external procdef for the
        implementation, and then generate a procedure body for the original
        one that calls through to the external procdef. This is necessary
        because there may already be references to the mangled name for the
        non-external "test".
      }

      { prefixing the parameters here is useless, because the new procdef will
        just be an external declaration without a body }
      NewPD:=TProcDef(OrgPD.GetCopyAs(ProcDef,pc_bareproc,'',True));
      insert_funcret_para(NewPD);
      NewPD.ProcOptions:=NewPD.ProcOptions+OrgPD.ProcOptions*[po_external,po_has_importname,po_has_importdll];
      StringDispose(OrgPD.ImportName);
      StringDispose(OrgPD.ImportDLL);
      OrgPD.ImportNr:=0;
      NewPD.SetMangledName(NewName);
      Finish_Copied_ProcDef(NewPD,'__FPC_IMPL_EXTERNAL_REDIRECT_'+NewName,CurrentModule.LocalSymTable,nil);
      NewPD.ForwardDef:=False;
      { ideally we would prefix the parameters of the original routine here, but since it
        can be an interface definition, we cannot do that without risking to change the
        interface crc }
      OrgPD.SKPara:=NewPD;
      OrgPD.SyntheticKind:=tsk_callthrough;
      OrgPD.ProcOptions:=OrgPD.ProcOptions-[po_external,po_has_importname,po_has_importdll];
      OrgPD.ForwardDef:=True;
    end;


  function Generate_Pkg_Stub(PD:TProcDef):TNode;
    var
      Stat: TStatementNode;
      HandleVar: TStaticVarSym;
      Instance: TSym;
    begin
      if TargetInfo.System in systems_all_windows then
        begin
          insert_funcret_local(PD);
          Result:=InternalStatements(Stat);
          if TargetInfo.System=system_x86_64_win64 then
            begin
              HandleVar:=CStaticVarSym.Create_C('FPC_PACKAGE_HANDLE','FPC_PACKAGE_HANDLE',
                vs_value,SizeUIntType);
              Include(HandleVar.VarOptions,vo_is_external);
              CurrentModule.LocalSymTable.InsertSym(HandleVar);
              Instance:=TSym(PD.ParaST.Find('HINSTANCE'));
              AddStatement(Stat,CAssignmentNode.Create(
                CLoadNode.Create(HandleVar,HandleVar.Owner),
                CLoadNode.Create(Instance,PD.ParaST)));
            end;
          AddStatement(Stat,CAssignmentNode.Create(
                      CLoadNode.Create(PD.FuncRetSym,PD.LocalST),
                      COrdConstNode.Create(1,Bool32Type,False)
                    ));
        end
      else
        Result:=CNothingNode.Create;
    end;

  procedure Generate_Attr_Constrs(Attrs:TFPObjectList);
    var
      PS : TProcSym;
      PD : TProcDef;
      PI : TCGProcInfo;
      I : SizeInt;
      Attr : TRTTIAttribute;
    begin
      if Attrs.Count=0 then
        Exit;
      { if this isn't set then this unit shouldn't have any attributes }
      if not Assigned(Class_TCustomAttribute) then
        InternalError(2019071003);
      for I:=0 to Attrs.Count-1 do
        begin
          Attr:=TRTTIAttribute(Attrs[I]);
          {Generate a procsym for main}
          PS:=CProcSym.Create('$rttiattrconstr$'+ToStr(I));
          { always register the symbol }
          PS.RegisterSym;
          { the RTTI always references this symbol }
          Inc(PS.RefS);
          CurrentModule.LocalSymTable.InsertSym(PS);
          PD:=CProcDef.Create(NormalFunctionLevel,True);
          { always register the def }
          PD.RegisterDef;
          PD.ProcSym:=PS;
          PS.ProcdefList.Add(PD);
          { set procdef options }
          PD.ProcTypeOption:=potype_function;
          PD.ProcCallOption:=pocall_default;
          Include(PD.ProcOptions,po_hascallingconvention);
          PD.ReturnDef:=Class_TCustomAttribute;
          insert_funcret_para(PD);
          PD.CalcParas;
          PD.ForwardDef:=False;
          PD.AliasNames.Insert(PD.MangledName);
          handle_calling_convention(PD,hcc_default_actions_impl);
          { set procinfo and current_procinfo.procdef }
          PI:=TCGProcInfo(CProcInfo.Create(nil));
          PI.ProcDef:=PD;
          { we always do a call, namely to the constructor }
          Include(PI.Flags,pi_do_call);
          insert_funcret_local(PD);
          PI.Code:=CAssignmentNode.Create(
                      CLoadNode.Create(PD.FuncRetSym,PD.LocalST),
                      Attr.ConstructorCall.GetCopy
                    );
          PI.generate_code;
          Attr.ConstructorPD:=PD;
        end;
    end;

end.

