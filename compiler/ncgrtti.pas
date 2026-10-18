{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Routines for the code generation of RTTI data structures

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
unit ncgrtti;

{$i fpcdefs.inc}

interface

    uses
      CClasses,ConstExp,GlobType,
      aasmbase,aasmcnst,
      SymBase,symconst,symtype,symdef,SymSym,
      parabase;

    type

      { TRTTIWriter }

      TRTTIWriter=class
      private
        { required internal alignment of the rtti data }
        FRequiredAlignment: ShortInt;
        { required packing of all structures except for ttypeinfo and tpropinfo,
          which always use packrecords 1 }
        FDefaultPacking: ShortInt;
        { write comments ? }
        FAddComments : Boolean;
        procedure FieldsWriteRTTI(ASymTable:TSymTable;ARTTIType:TRTTIType);
        procedure ParamsWriteRTTI(ADef:TAbstractProcDef;ARTTIType:TRTTIType;AAllowHidden:Boolean);
        procedure FieldsWriteRTTIData(ATypedConstBuilder: TTAITypedConstBuilder; ADef: TAbstractRecordDef; ARTTIType: TRTTIType);
        procedure MethodsWriteRTTI(ASymTable:TSymTable;ARTTIType:TRTTIType;AVisibilities:TVisibilities;AAllowHidden:Boolean);
        procedure WriteRTTIExtraSyms(ADef:TDef;ARTTIType:TRTTIType;AMainRTTI:TAsmSymbol);
        procedure PublishedWriteRTTI(ADef : TObjectDef;ARTTIType:TRTTIType);
        procedure PropertiesWriteRTTIData(ATypedConstBuilder:TTAITypedConstBuilder;APropNameList:TFPHashObjectList;ASymTable:TSymTable;AExtendedRTTI:Boolean;AVisibilities:TVisibilities);
        procedure Write_Extended_Method_Table(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TAbstractRecordDef;APackRecords:LongInt);
        procedure Write_Extended_Field_Table(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TAbstractRecordDef;APackRecords:LongInt);
        procedure CollectPropNameList(APropNameList:TFPHashObjectList;ADef:TAbstractRecordDef;AVisibilities:TVisibilities);
        { only use a direct reference if the referenced type can *only* reside
          in the same unit as the current one }
        function Ref_RTTI(ADef:TDef;ARTTIType:TRTTIType;AIndirect:Boolean;ASuffix:TSymStr):TAsmSymbol;
        procedure WriteRTTIName(ATypedConstBuilder: TTAITypedConstBuilder; ADef: TDef);
        procedure WriteCommonRTTIData(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TDef;ARTTIType:TRTTIType);
        procedure WriteRTTIData(ATypedConstBuilder: TTAITypedConstBuilder; ADef:TDef; ARTTIType: TRTTIType);
        procedure WriteAttributeData(ATypedConstBuilder: TTAITypedConstBuilder;AAttributeList:TRTTIAttributeList);
        procedure WriteChildRTTIData(ADef:TDef;ARTTIType:TRTTIType);
        procedure WriteRTTIReference(ATypedConstBuilder: TTAITypedConstBuilder; ADef: TDef; ARTTIType: TRTTIType);
        procedure WriteMethods(ATypedConstBuilder:TTAITypedConstBuilder;ASymTable:TSymTable;AExtendedRTTI:Boolean;AVisibilities:TVisibilities);
        procedure WriteHeader(ATypedConstBuilder: TTAITypedConstBuilder; ADef: TDef; ATypeKind: Byte);
        function WriteMethodKind(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TAbstractProcDef):Byte;
        procedure WriteCallConv(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TAbstractProcDef);
        procedure WriteParaLocs(ATypedConstBuilder:TTAITypedConstBuilder;APara:PCGPara);
        procedure WriteParamFlag(ATypedConstBuilder:TTAITypedConstBuilder;AParaSym:TParaVarSym);
        procedure WriteParam(ATypedConstBuilder:TTAITypedConstBuilder;APara:TParaVarSym);
        procedure WriteMOPOffsetTable(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TAbstractRecordDef;AManagementOperator:TManagementOperator);
        procedure MaybeAddComment(ATypedConstBuilder:TTAITypedConstBuilder;const AComment : String); inline;
      public
        constructor Create;
        procedure Write_RTTI(ADef:TDef;ARTTIType:TRTTIType);
        procedure Write_Extended_Method_Table(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TAbstractRecordDef); inline;
        procedure Write_Extended_Field_Table(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TAbstractRecordDef); inline;
        function  Get_RTTI_Label(ADef:TDef;ARTTIType:TRTTIType;AIndirect:Boolean):TAsmSymbol; inline;
        function  Get_RTTI_Label_Ord2Str(ADef:TDef;ARTTIType:TRTTIType;AIndirect:Boolean):TAsmSymbol; inline;
        function  Get_RTTI_Label_Str2Ord(ADef:TDef;ARTTIType:TRTTIType;AIndirect:Boolean):TAsmSymbol; inline;
      end;

    { generate RTTI and init tables }
    procedure Write_Persistent_Type_Info(ASymTable:TSymTable;AIsGlobal:Boolean);

    var
      RTTIWriter : TRTTIWriter;


implementation

    uses
       CUtils,
       Globals,Verbose,Systems,
       node,ncal,ncon,
       FModule, ProcInfo,
       SymTable,symutil,
       aasmtai,AAsmData,
       defutil,
       paramgr
       ;


    const
       cRTTIDefStates : array[TRTTIType] of TDefState =
         (ds_rtti_table_written,ds_init_table_written,
         { Objective-C related, does not pass here }
         symconst.ds_none,symconst.ds_none,
         symconst.ds_none,symconst.ds_none,
         symconst.ds_none,symconst.ds_none,
         symconst.ds_none,symconst.ds_none,
         symconst.ds_none,symconst.ds_none);
       cRTTITypeNames : array[TRTTIType] of String =
         ('full','init',
          'objcmeta','objcmetaro',
          'objcclass','objcclassro',
          'objcprotocollist','objcprotocolmethodstypelist',
          'objcinstancemethods','objectclassmethods',
          'objcprotinstancemethodsopt','objcprotoclassmethodsopt'
          );

    type
       TPropNameListItem = class(TFPHashObject)
         PropIndex : LongInt;
         PropOwner : TSymTable;
       end;


    function VisibilityToRTTIFlags(AVisibility: TVisibility): Byte;
      begin
        case AVisibility of
          vis_private:
            Result:=Byte(rv_private);
          vis_strictprivate:
            begin
              Result:=Byte(rv_private);
              // add bit to indicate "strict"
              Result:=Result or (1 shl 2);
            end;
          vis_protected:
            Result:=Byte(rv_protected);
          vis_strictprotected:
            begin
              Result:=Byte(rv_protected);
              // add bit to indicate "strict"
              Result:=Result or (1 shl 2);
            end;
          vis_public:
            Result:=Byte(rv_public);
          vis_published:
            Result:=Byte(rv_published);
          otherwise
            InternalError(2021061301);
        end;
      end;


    procedure Write_Persistent_Type_Info(ASymTable: TSymTable; AIsGlobal: Boolean);
      var
        lIndex : LongInt;
        lDef : TDef;
      begin
        for lIndex:=0 to ASymTable.DefList.Count-1 do
          begin
            lDef:=TDef(ASymTable.DefList[lIndex]);
            { skip generics }
            if [df_generic,df_genconstraint]*lDef.DefOptions<>[] then
              continue;
            case lDef.typ of
              recorddef:
                Write_Persistent_Type_Info(TRecordDef(lDef).SymTable,AIsGlobal);
              objectdef :
                begin
                  { Skip forward defs }
                  if (oo_is_forward in TObjectDef(lDef).ObjectOptions) then
                    continue;
                  { skip unique type aliases, they use the RTTI from the parent class }
                  if TObjectDef(lDef).Is_Unique_ObjPasDef then
                    continue;
                  Write_Persistent_Type_Info(TObjectDef(lDef).SymTable,AIsGlobal);
                end;
              procdef :
                begin
                  if Assigned(TProcDef(lDef).LocalST) and
                     (TProcDef(lDef).LocalST.SymTableType=LocalSymTable) then
                    Write_Persistent_Type_Info(TProcDef(lDef).LocalST,false);
                  if Assigned(TProcDef(lDef).ParaST) then
                    Write_Persistent_Type_Info(TProcDef(lDef).ParaST,false);
                end;
              errordef:
                { we shouldn't have come this far if we have an errordef somewhere }
                InternalError(2017010701);
              undefineddef:
                { don't write any RTTI for these }
                continue;
              else
                ;
            end;
            { always generate persistent tables for types in the interface so
              they can be reused in other units and give always the same pointer
              location. }
            { Init }
            if (
                Assigned(lDef.TypeSym) and
                AIsGlobal and
                not Is_ObjC_Class_Or_Protocol(lDef)
               ) or
               Is_Managed_Type(lDef) or
               (ds_init_table_used in lDef.DefStates) then
              RTTIWriter.Write_RTTI(lDef,initrtti);
            { RTTI }
            if not(df_internal in lDef.DefOptions) and
               (
                (
                 Assigned(lDef.TypeSym) and
                 AIsGlobal and
                 not Is_ObjC_Class_Or_Protocol(lDef)
                ) or
                (ds_rtti_table_used in lDef.DefStates)
               ) then
              RTTIWriter.Write_RTTI(lDef,fullrtti);
          end;
      end;


{***************************************************************************
                              TRTTIWriter
***************************************************************************}

    function TRTTIWriter.Get_RTTI_Label(ADef:TDef;ARTTIType:TRTTIType;AIndirect:Boolean):TAsmSymbol;
      begin
        Result:=Ref_RTTI(ADef,ARTTIType,AIndirect,'');
      end;

    function TRTTIWriter.Get_RTTI_Label_Ord2Str(ADef:TDef;ARTTIType:TRTTIType;AIndirect:Boolean):TAsmSymbol;
      begin
        Result:=Ref_RTTI(ADef,ARTTIType,AIndirect,'_o2s');
      end;

    function TRTTIWriter.Get_RTTI_Label_Str2Ord(ADef:TDef;ARTTIType:TRTTIType;AIndirect:Boolean):TAsmSymbol;
      begin
        Result:=Ref_RTTI(ADef,ARTTIType,AIndirect,'_s2o');
      end;

    procedure TRTTIWriter.WriteMethods(ATypedConstBuilder:TTAITypedConstBuilder;ASymTable:TSymTable;AExtendedRTTI:Boolean;AVisibilities:TVisibilities);
      var
        lRTTICount,
        lTotalCount,
        lIndex,lIndexJ,lIndexK : LongInt;
        lSym : TProcSym;
        lDef : TProcDef;
        lParaSym : TParaVarSym;
      begin
        MaybeAddComment(ATypedConstBuilder,'RTTI: begin methods');
        ATypedConstBuilder.begin_anonymous_record('',FDefaultPacking,min(FRequiredAlignment,SizeOf(PInt)),
          targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

        lTotalCount:=0;
        lRTTICount:=0;
        for lIndex:=0 to ASymTable.SymList.count-1 do
          if TSym(ASymTable.SymList[lIndex]).typ=ProcSym then
            begin
              lSym:=TProcSym(ASymTable.SymList[lIndex]);
              inc(lTotalCount,lSym.procdeflist.count);
              for lIndexJ:=0 to lSym.procdeflist.count-1 do
                begin
                lDef:=TProcDef(lSym.procdeflist[lIndexJ]);
                if (lDef.visibility in AVisibilities) and not (lDef.Is_Generic) then
                  inc(lRTTICount);
                end;
            end;

        { write the count section for non-extended methods }
        if not AExtendedRTTI then
          begin
            MaybeAddComment(ATypedConstBuilder,#9'count');
            ATypedConstBuilder.emit_ord_const(lTotalCount,U16IntType);
            MaybeAddComment(ATypedConstBuilder,#9'RTTI count');
            if lRTTICount=0 then
              ATypedConstBuilder.emit_ord_const($FFFF,U16IntType)
            else
              ATypedConstBuilder.emit_ord_const(lRTTICount,U16IntType);
          end;

        if lRTTICount>0 then
          for lIndex:=0 to ASymTable.SymList.count-1 do
            if TSym(ASymTable.SymList[lIndex]).typ=ProcSym then
              begin
                lSym:=TProcSym(ASymTable.SymList[lIndex]);
                for lIndexJ:=0 to lSym.procdeflist.count-1 do
                  begin
                    lDef:=TProcDef(lSym.procdeflist[lIndexJ]);

                    if (lDef.Is_Generic) or not (lDef.visibility in AVisibilities) then
                      continue;

                    lDef.Init_ParaLoc_Info(callerside);

                    MaybeAddComment(ATypedConstBuilder,'RTTI: begin method '+lDef.FullProcName(false));
                    ATypedConstBuilder.begin_anonymous_record('',FDefaultPacking,min(FRequiredAlignment,SizeOf(PInt)),
                      targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

                    MaybeAddComment(ATypedConstBuilder,#9'return type');
                    WriteRTTIReference(ATypedConstBuilder,lDef.ReturnDef,fullrtti);
                    MaybeAddComment(ATypedConstBuilder,#9'calling convention');
                    WriteCallConv(ATypedConstBuilder,lDef);
                    MaybeAddComment(ATypedConstBuilder,#9'method kind');
                    WriteMethodKind(ATypedConstBuilder,lDef);
                    MaybeAddComment(ATypedConstBuilder,#9'param count');
                    ATypedConstBuilder.emit_ord_const(lDef.paras.count,U16IntType);
                    MaybeAddComment(ATypedConstBuilder,#9'caller args size');
                    ATypedConstBuilder.emit_ord_const(lDef.CallerArgAreaSize,SizeSIntType);
                    MaybeAddComment(ATypedConstBuilder,#9'invoke helper');
                    if lDef.InvokeHelper=nil then
                      ATypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidCodePointerType)
                    else
                      ATypedConstBuilder.emit_procdef_const(lDef.InvokeHelper);
                    MaybeAddComment(ATypedConstBuilder,#9'name');
                    ATypedConstBuilder.emit_pooled_shortstring_const_ref(lSym.realname);

                    if AExtendedRTTI then
                      begin
                        { write visibility section for extended RTTI }
                        MaybeAddComment(ATypedConstBuilder,#9'visibility');
                        ATypedConstBuilder.emit_ord_const(VisibilityToRTTIFlags(lDef.visibility),U8IntType);
                        { for objects and classes write a VMT index }
                        if ASymTable.DefOwner.typ=objectdef then
                          begin
                            MaybeAddComment(ATypedConstBuilder,#9'VMT index');
                            ATypedConstBuilder.emit_ord_const(lDef.ExtNumber,U16IntType);
                          end;
                        MaybeAddComment(ATypedConstBuilder,#9'Code Address');
                        ATypedConstBuilder.emit_procdef_const(lDef);
                        MaybeAddComment(ATypedConstBuilder,#9'Attribute table');
                        WriteAttributeData(ATypedConstBuilder,lDef.RTTIAttributeList);
                      end;

                    for lIndexK:=0 to lDef.paras.count-1 do
                        WriteParam(ATypedConstBuilder,TParaVarSym(lDef.paras[lIndexK]));

                    if not Is_Void(lDef.ReturnDef) then
                      begin
                      MaybeAddComment(ATypedConstBuilder,#9'return loc');
                      WriteParaLocs(ATypedConstBuilder,@lDef.FuncRetLoc[callerside]);
                      end;

                    ATypedConstBuilder.end_anonymous_record;
                    MaybeAddComment(ATypedConstBuilder,'RTTI: end method '+lDef.FullProcName(false));
                  end;
              end;

        ATypedConstBuilder.end_anonymous_record;
        MaybeAddComment(ATypedConstBuilder,'RTTI: end methods');
      end;


    procedure TRTTIWriter.WriteHeader(ATypedConstBuilder: TTAITypedConstBuilder; ADef: TDef; ATypeKind: Byte);
      var
        lName: ShortString;
      begin
        if Assigned(ADef.TypeSym) then
          lName:=TTypeSym(ADef.TypeSym).realname
        else
          lName:='';
        { TTypeInfo, always packed and doesn't need alignment }
        ATypedConstBuilder.begin_anonymous_record(
          InternalTypePrefixName[itp_rtti_header]+ToStr(length(lName)),1,1,
          targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
        if ADef.typ=arraydef then
          InternalError(201012211);
        ATypedConstBuilder.emit_tai(TAIConst.Create_8bit(ATypeKind),U8IntType);
        ATypedConstBuilder.emit_shortstring_const(lName);

        ATypedConstBuilder.end_anonymous_record;
      end;


    function TRTTIWriter.WriteMethodKind(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TAbstractProcDef):Byte;
      begin
        case ADef.ProcTypeOption of
          potype_constructor: Result:=MkConstructor;
          potype_destructor: Result:=MkDestructor;
          potype_class_constructor: Result:=MkClassConstructor;
          potype_class_destructor: Result:=MkClassDestructor;
          potype_operator: Result:=MkOperatorOverload;
          potype_procedure:
            if po_classmethod in ADef.ProcOptions then
              Result:=MkClassProcedure
            else
              Result:=MkProcedure;
          potype_function:
            if po_classmethod in ADef.ProcOptions then
              Result:=MkClassFunction
            else
              Result:=MkFunction;
        else
          begin
            if ADef.ReturnDef = VoidType then
              Result:=MkProcedure
            else
              Result:=MkFunction;
          end;
        end;
        ATypedConstBuilder.emit_ord_const(Result,U8IntType);
      end;


    procedure TRTTIWriter.WriteCallConv(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TAbstractProcDef);
      const
        cProcCallOptionToCallConv: array[TProcCallOption] of Byte = (
         { pocall_none       } 0,
         { pocall_cdecl      } 1,
         { pocall_cppdecl    } 5,
         { pocall_far16      } 6,
         { pocall_oldfpccall } 7,
         { pocall_internproc } 8,
         { pocall_pascal     } 2,
         { pocall_register   } 0,
         { pocall_safecall   } 4,
         { pocall_stdcall    } 3,
         { pocall_softfloat  } 10,
         { pocall_mwpascal   } 11,
         { pocall_interrupt  } 12,
         { pocall_hardfloat  } 13,
         { pocall_sysv_abi_default } 14,
         { pocall_sysv_abi_cdecl }   15,
         { pocall_ms_abi_default }   16,
         { pocall_ms_abi_cdecl }     17,
         { pocall_vectorcall }       18
        );
      begin
        ATypedConstBuilder.emit_ord_const(cProcCallOptionToCallConv[ADef.ProcCallOption],U8IntType);
      end;


    procedure TRTTIWriter.WriteParaLocs(ATypedConstBuilder:TTAITypedConstBuilder;APara:PCGPara);
      var
        lLocs : TRTTIParaLocs;
        lIndex : LongInt;
        lPool : THashSet;
        lEntry : PHashSetItem;
        lLocLabel : TAsmLabel;
        lLocTypedConstBuilder : TTAITypedConstBuilder;
        lDataDef : TDef;
      begin
        lLocs:=ParaManager.CGParaLocs_To_RTTIParaLocs(APara^.Location);
        if length(lLocs)>high(Byte) then
          InternalError(2017010601);

        if length(lLocs)=0 then
          begin
            { *shrugs* }
            ATypedConstBuilder.emit_tai(TAIConst.Create_nil_codeptr,VoidPointerType);
            exit;
          end;

        { do we have such a paraloc already in the pool? }
        lPool:=CurrentAsmData.ConstPools[sp_paraloc];

        lEntry:=lPool.FindOrAdd(@lLocs[0],length(lLocs)*sizeof(TRTTIParaLoc));

        if not Assigned(lEntry^.Data) then
          begin
            CurrentAsmData.getglobaldatalabel(lLocLabel);

            lLocTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_is_lab,tcalo_make_dead_strippable]);

            lLocTypedConstBuilder.begin_anonymous_record('',FDefaultPacking,min(FRequiredAlignment,SizeOf(PInt)),
              targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
            lLocTypedConstBuilder.emit_ord_const(length(lLocs),U8IntType);
            for lIndex:=low(lLocs) to high(lLocs) do
              begin
                lLocTypedConstBuilder.begin_anonymous_record('',FDefaultPacking,min(FRequiredAlignment,SizeOf(PInt)),
                  targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
                lLocTypedConstBuilder.emit_ord_const(lLocs[lIndex].LocType,U8IntType);
                lLocTypedConstBuilder.emit_ord_const(lLocs[lIndex].RegSub,U8IntType);
                lLocTypedConstBuilder.emit_ord_const(lLocs[lIndex].RegIndex,U16IntType);
                { the corresponding type for aint is alusinttype }
                lLocTypedConstBuilder.emit_ord_const(lLocs[lIndex].Offset,ALUSIntType);
                lLocTypedConstBuilder.end_anonymous_record;
              end;
            lDataDef:=lLocTypedConstBuilder.end_anonymous_record;

            CurrentAsmData.asmlists[al_typedconsts].ConcatList(
              lLocTypedConstBuilder.get_final_asmlist(lLocLabel,lDataDef,sec_rodata_norel,lLocLabel.name,Const_Align(sizeof(PInt)))
            );

            lLocTypedConstBuilder.free;
            lLocTypedConstBuilder := nil;

            lEntry^.data:=lLocLabel;
          end
        else
          lLocLabel:=TAsmLabel(lEntry^.Data);

        ATypedConstBuilder.emit_tai(TAIConst.Create_sym(lLocLabel),VoidPointerType);
      end;


    procedure TRTTIWriter.WriteParamFlag(ATypedConstBuilder:TTAITypedConstBuilder;AParaSym:TParaVarSym);
      var
        lParaSpec : Word;
      begin
        case AParaSym.VarSpez of
          vs_value   : lParaSpec := 0;
          vs_const   : lParaSpec := PfConst;
          vs_var     : lParaSpec := PfVar;
          vs_out     : lParaSpec := PfOut;
          vs_constref: lParaSpec := PfConstRef;
          else
            InternalError(2013112904);
        end;
        { Kylix also seems to always add both pfArray and pfReference
          in this case
        }
        if Is_Open_Array(AParaSym.vardef) or Is_Array_Of_Const(AParaSym.vardef) then
          lParaSpec:=lParaSpec or PfArray or PfReference;
        { and these for classes and interfaces (maybe because they
          are themselves addresses?)
        }
        if Is_Class_Or_Interface(AParaSym.vardef) then
          lParaSpec:=lParaSpec or PfAddress;
        { flags for the hidden parameters }
        if vo_is_hidden_para in AParaSym.VarOptions then
          lParaSpec:=lParaSpec or PfHidden;
        if vo_is_high_para in AParaSym.VarOptions then
          lParaSpec:=lParaSpec or PfHigh;
        if vo_is_self in AParaSym.VarOptions then
          lParaSpec:=lParaSpec or PfSelf;
        if vo_is_vmt in AParaSym.VarOptions then
          lParaSpec:=lParaSpec or PfVMT;
        if vo_is_funcret in AParaSym.VarOptions then
          lParaSpec:=lParaSpec or PfResult;
        { set bits run from the highest to the lowest bit on
          big endian systems
        }
        if (TargetInfo.endian = endian_big) then
          lParaSpec:=Reverse_Word(lParaSpec);
        { write flags for current parameter }
        ATypedConstBuilder.emit_ord_const(lParaSpec,U16IntType);
      end;

    procedure TRTTIWriter.WriteParam(ATypedConstBuilder: TTAITypedConstBuilder;
      APara: TParaVarSym);
      begin
        MaybeAddComment(ATypedConstBuilder,'RTTI: begin param '+APara.prettyname);
        ATypedConstBuilder.begin_anonymous_record('',FDefaultPacking,min(FRequiredAlignment,SizeOf(PInt)),
          targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

        MaybeAddComment(ATypedConstBuilder,#9'type');
        if Is_Open_Array(APara.vardef) or Is_Array_Of_Const(APara.vardef) then
          WriteRTTIReference(ATypedConstBuilder,TArrayDef(APara.vardef).ElementDef,fullrtti)
        else if APara.vardef=CFormalType then
          WriteRTTIReference(ATypedConstBuilder,nil,fullrtti)
        else
          WriteRTTIReference(ATypedConstBuilder,APara.vardef,fullrtti);
        MaybeAddComment(ATypedConstBuilder,#9'flags');
        WriteParamFlag(ATypedConstBuilder,APara);

        MaybeAddComment(ATypedConstBuilder,#9'name');
        ATypedConstBuilder.emit_pooled_shortstring_const_ref(APara.realname);

        MaybeAddComment(ATypedConstBuilder,#9'locs');
        WriteParaLocs(ATypedConstBuilder,@APara.ParaLoc[callerside]);

        ATypedConstBuilder.end_anonymous_record;
        MaybeAddComment(ATypedConstBuilder,'RTTI: end param '+APara.prettyname);
      end;


    function CompareMOPOffsetEntry(AItem1,AItem2:Pointer):LongInt;
      var
        lEntry1: PManagementOperatorOffsetEntry absolute AItem1;
        lEntry2: PManagementOperatorOffsetEntry absolute AItem2;
      begin
        if lEntry1^.Offset<lEntry2^.Offset then
          Result:=-1
        else if lEntry1^.Offset>lEntry2^.Offset then
          Result:=1
        else
          Result:=0;
      end;


    procedure TRTTIWriter.WriteMOPOffsetTable(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TAbstractRecordDef;AManagementOperator:TManagementOperator);
      var
        lList : TFPList;
        lDataTypedConstBuilder : TTAITypedConstBuilder;
        lTableLabel : TAsmLabel;
        lEntry : PManagementOperatorOffsetEntry;
        lDataDef,lEntryDef : TDef;
        lIndex : LongInt;
        lProcDef : TObjectDef;
      begin
        lList:=TFPList.Create;
        TAbstractRecordSymTable(ADef.SymTable).Get_ManagementOperator_Offset_List(AManagementOperator,lList);
        if (ADef.typ=objectdef) then
          begin
            lProcDef:=TObjectDef(ADef).ChildOf;
            while Assigned(lProcDef) do
              begin
                TAbstractRecordSymTable(lProcDef.SymTable).Get_ManagementOperator_Offset_List(AManagementOperator,lList);
                lProcDef:=lProcDef.ChildOf;
              end;
            lList.sort(@CompareMOPOffsetEntry);
          end;
        if lList.count=0 then
          ATypedConstBuilder.emit_tai(TAIConst.create_nil_dataptr,VoidPointerType)
        else
          begin
            ATypedConstBuilder.start_internal_data_builder(CurrentAsmData.AsmLists[al_rtti],sec_rodata,'',lDataTypedConstBuilder,lTableLabel);

            lDataTypedConstBuilder.begin_anonymous_record('',FDefaultPacking,min(FRequiredAlignment,SizeOf(PInt)),
              targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
            lDataTypedConstBuilder.emit_ord_const(lList.count,U32IntType);

            lEntryDef:=Get_RecordDef(itp_init_mop_offset_entry,[VoidCodePointerType,SizeUIntType],FDefaultPacking);

            for lIndex:=0 to lList.count-1 do
              begin
                lEntry:=PManagementOperatorOffsetEntry(lList[lIndex]);

                lDataTypedConstBuilder.maybe_begin_aggregate(lEntryDef);

                lDataTypedConstBuilder.queue_init(VoidCodePointerType);
                lDataTypedConstBuilder.queue_emit_proc(lEntry^.pd);

                lDataTypedConstBuilder.queue_init(SizeUIntType);
                lDataTypedConstBuilder.queue_emit_ordconst(lEntry^.Offset,SizeUIntType);

                lDataTypedConstBuilder.maybe_end_aggregate(lEntryDef);

                dispose(lEntry);
              end;

            lDataDef:=lDataTypedConstBuilder.end_anonymous_record;

            ATypedConstBuilder.finish_internal_data_builder(lDataTypedConstBuilder,lTableLabel,lDataDef,sizeof(PInt));

            ATypedConstBuilder.emit_tai(TAIConst.Create_sym(lTableLabel),VoidPointerType);
          end;
        lList.free;
        lList := nil;
      end;


    procedure TRTTIWriter.WriteRTTIName(ATypedConstBuilder: TTAITypedConstBuilder; ADef: TDef);
      begin
         if Is_Open_Array(ADef) then
           { open arrays never have a typesym with a name, since you cannot
             define an "open array type". Kylix prints the type of the
             elements in the array in this case (so together with the pfArray
             flag, you can reconstruct the full typename, I assume (JM))
           }
           ADef:=TArrayDef(ADef).ElementDef;
         { name }
         if Assigned(ADef.TypeSym) then
           ATypedConstBuilder.emit_shortstring_const(TTypeSym(ADef.TypeSym).prettyname)
         else
           ATypedConstBuilder.emit_shortstring_const('');
      end;


    procedure TRTTIWriter.WriteCommonRTTIData(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TDef;ARTTIType:TRTTIType);
      begin
        if ARTTIType<>fullrtti then
          WriteAttributeData(ATypedConstBuilder,nil)
        else
          WriteAttributeData(ATypedConstBuilder,TStoredDef(ADef).RTTIAttributeList);
      end;


    { writes a 32-bit count followed by array of field infos for given symtable }
    procedure TRTTIWriter.FieldsWriteRTTIData(ATypedConstBuilder: TTAITypedConstBuilder; ADef: TAbstractRecordDef; ARTTIType: TRTTIType);
      var
        lIndex   : LongInt;
        lSym : TSym;
        lFieldCount: LongInt;
        lSymTable: TSymTable;
        lFields: TFPList;
        lParentRTTI: Boolean;
      begin
        lFieldCount:=0;
        lParentRTTI:=false;
        lSymTable:=ADef.SymTable;
        lFields:=TFPList.Create;
        lFields.capacity:=lSymTable.SymList.count+1;
        { For objects, treat parent (if any) as a field with offset 0. This
          provides correct handling of entire instance with RTL rtti routines. }
        if (ADef.typ=objectdef) and (TObjectDef(ADef).ObjectType=odt_object) and
            Assigned(TObjectDef(ADef).ChildOf) and
            ((ARTTIType=fullrtti) or (TObjectDef(ADef).ChildOf.NeedsInitTable)) then
           begin
             lParentRTTI:=true;
             inc(lFieldCount);
           end;

        for lIndex:=0 to lSymTable.SymList.Count-1 do
          begin
            lSym:=TSym(lSymTable.SymList[lIndex]);
            if Is_Normal_FieldVarSym(lSym) and
               (
                (ARTTIType=fullrtti) or
                TFieldVarSym(lSym).vardef.NeedsInitTable
               ) and
               not Is_ObjC_Class_Or_Protocol(TFieldVarSym(lSym).vardef) then
              begin
                lFields.add(TFieldVarSym(lSym));
                inc(lFieldCount);
              end;
          end;
        { insert field count before data }
        MaybeAddComment(ATypedConstBuilder,'Field count');
        ATypedConstBuilder.emit_ord_const(lFieldCount,U32IntType);
        { parent object? }
        if lParentRTTI then
          begin
            WriteRTTIReference(ATypedConstBuilder,TObjectDef(ADef).ChildOf,ARTTIType);
            ATypedConstBuilder.emit_ord_const(0,PtrUIntType);
          end;
        { fields }
        for lIndex:=0 to lFields.count-1 do
          begin
            lSym:=TSym(lFields[lIndex]);
            MaybeAddComment(ATypedConstBuilder,'RTTI begin field '+ToStr(lIndex)+': '+lSym.prettyname);
            WriteRTTIReference(ATypedConstBuilder,TFieldVarSym(lSym).vardef,ARTTIType);
            ATypedConstBuilder.emit_ord_const(TFieldVarSym(lSym).FieldOffset,SizeUIntType);
            MaybeAddComment(ATypedConstBuilder,'RTTI end field '+ToStr(lIndex)+': '+lSym.prettyname);
          end;
        lFields.free;
        lFields := nil;
      end;


    procedure TRTTIWriter.FieldsWriteRTTI(ASymTable:TSymTable;ARTTIType:TRTTIType);
      var
        lIndex   : LongInt;
        lSym : TSym;
      begin
        for lIndex:=0 to ASymTable.SymList.Count-1 do
          begin
            lSym:=TSym(ASymTable.SymList[lIndex]);
            if Is_Normal_FieldVarSym(lSym) and
               (
                (ARTTIType=fullrtti) or
                TFieldVarSym(lSym).vardef.NeedsInitTable
               ) then
              Write_RTTI(TFieldVarSym(lSym).vardef,ARTTIType);
          end;
      end;


    procedure TRTTIWriter.ParamsWriteRTTI(ADef:TAbstractProcDef;ARTTIType:TRTTIType;AAllowHidden:Boolean);
      var
        lIndex   : LongInt;
        lSym : TParaVarSym;
      begin
        for lIndex:=0 to ADef.paras.count-1 do
          begin
            lSym:=TParaVarSym(ADef.paras[lIndex]);
            if not (vo_is_hidden_para in lSym.VarOptions) or AAllowHidden then
              begin
                if Is_Open_Array(lSym.vardef) or Is_Array_Of_Const(lSym.vardef) then
                  Write_RTTI(TArrayDef(lSym.vardef).ElementDef,ARTTIType)
                else
                  Write_RTTI(lSym.vardef,ARTTIType);
              end;
          end;
      end;


    procedure TRTTIWriter.MethodsWriteRTTI(ASymTable:TSymTable;ARTTIType:TRTTIType;AVisibilities:TVisibilities;AAllowHidden:Boolean);
      var
        lIndex,lIndexJ : LongInt;
        lSym : TProcSym;
        lDef : TAbstractProcDef;
      begin
        for lIndex:=0 to ASymTable.SymList.count-1 do
          if TSym(ASymTable.SymList[lIndex]).typ=ProcSym then
            begin
              lSym:=TProcSym(ASymTable.SymList[lIndex]);
              for lIndexJ:=0 to lSym.procdeflist.count-1 do
                begin
                  lDef:=TAbstractProcDef(lSym.procdeflist[lIndexJ]);
                  Write_RTTI(lDef.ReturnDef,ARTTIType);
                  ParamsWriteRTTI(lDef,ARTTIType,AAllowHidden);
                end;
            end;
      end;


    procedure TRTTIWriter.Write_Extended_Method_Table(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TAbstractRecordDef;APackRecords:LongInt);
      var
        lMethodCount,
        lIndex, lIndexJ: LongInt;
        lSym: TProcSym;
        lProcDef : TProcDef;

      begin
        { count methods }
        lMethodCount:=0;
        for lIndex:=0 to ADef.SymTable.SymList.count-1 do
          if TSym(ADef.SymTable.SymList[lIndex]).typ=ProcSym then
            begin
              lSym:=TProcSym(ADef.SymTable.SymList[lIndex]);
              for lIndexJ:=0 to lSym.procdeflist.count-1 do
                begin
                lProcDef:=TProcDef(lSym.procdeflist[lIndexJ]);
                if (not lProcDef.Is_Generic) and ADef.Is_Visible_For_RTTI(ro_methods,lProcDef.visibility) then
                  inc(lMethodCount);
                end;
            end;

        ATypedConstBuilder.begin_anonymous_record('',APackRecords,min(FRequiredAlignment,SizeOf(PInt)),
          targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
        { emit method count }
        MaybeAddComment(ATypedConstBuilder,'RTTI Method table: method count');
        ATypedConstBuilder.emit_ord_const(lMethodCount,U16IntType);
        { emit method entries (array) }
        if lMethodCount>0 then
          WriteMethods(ATypedConstBuilder,ADef.SymTable,true,ADef.RTTI_Visibilities_For_Option(ro_methods));
        ATypedConstBuilder.end_anonymous_record;
      end;


    procedure TRTTIWriter.Write_Extended_Method_Table(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TAbstractRecordDef);
      begin
        Write_Extended_Method_Table(ATypedConstBuilder,ADef,FDefaultPacking);
      end;


    procedure TRTTIWriter.Write_Extended_Field_Table(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TAbstractRecordDef;APackRecords:LongInt);
      var
        lIndex,lCount: Integer;
        lSym: TSym;
        lFieldSym : TFieldVarSym;
        lList: TFPList;
      begin
        lList:=TFPList.Create;
        { build list of visible fields }
        for lIndex:=0 to ADef.SymTable.SymList.Count-1 do
          begin
            lSym:=TSym(ADef.SymTable.SymList[lIndex]);
            if (lSym.typ=FieldVarSym) and
               not(sp_static in lSym.SymOptions) and
               ADef.Is_Visible_For_RTTI(ro_fields, lSym.visibility) then
              lList.add(lSym);
          end;
        {
          TExtendedFieldTable = record
            FieldCount: Word;
            Fields: array[0..0] of TExtendedFieldInfo;
          end;
        }
        ATypedConstBuilder.begin_anonymous_record(InternalTypePrefixName[itp_extended_rtti_table]+ToStr(lList.count),APackRecords,min(FRequiredAlignment,SizeOf(PInt)),targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
        MaybeAddComment(ATypedConstBuilder,'RTTI: Extended Field count');
        ATypedConstBuilder.emit_ord_const(lList.count,U16IntType);
        for lIndex := 0 to lList.count-1 do
          begin
            lFieldSym:=TFieldVarSym(lList[lIndex]);
            {
              TExtendedFieldInfo = record
                FieldOffset: SizeUInt;
                FieldType: Pointer;
                FieldVisibility: Byte;
                Name: PShortString;
                Attributes :
              end;
            }
            ATypedConstBuilder.begin_anonymous_record(InternalTypePrefixName[itp_extended_rtti_field]+ToStr(lFieldSym.FieldOffset),APackRecords,min(FRequiredAlignment,SizeOf(PInt)),targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
            { FieldOffset }
            ATypedConstBuilder.emit_tai(TAIConst.Create_sizeint(lFieldSym.FieldOffset),SizeUIntType);
            { FieldType: PPTypeInfo }
            if Is_ObjC_Class_Or_Protocol(lFieldSym.vardef) then
              ATypedConstBuilder.emit_tai(TAIConst.Create_sym(RTTIWriter.Get_RTTI_Label(VoidPointerType,fullrtti,true)),VoidPointerType)
            else
              ATypedConstBuilder.emit_tai(TAIConst.Create_sym(RTTIWriter.Get_RTTI_Label(lFieldSym.vardef,fullrtti,true)),VoidPointerType);
            { FieldVisibility }
            ATypedConstBuilder.emit_ord_const(VisibilityToRTTIFlags(lFieldSym.visibility),U8IntType);
            { Name }
            ATypedConstBuilder.emit_pooled_shortstring_const_ref(lFieldSym.realname);
            { Attribute table }
            if Assigned(lFieldSym.RTTIAttributeList) and Assigned(lFieldSym.RTTIAttributeList.RTTIAttributes) then
              lCount:=lFieldSym.RTTIAttributeList.RTTIAttributes.count
            else
              lCount:=0;
            WriteAttributeData(ATypedConstBuilder,lFieldSym.RTTIAttributeList);
            ATypedConstBuilder.end_anonymous_record;
          end;
        ATypedConstBuilder.end_anonymous_record;
        lList.free;
        lList := nil;
      end;


    procedure TRTTIWriter.Write_Extended_Field_Table(ATypedConstBuilder:TTAITypedConstBuilder;ADef:TAbstractRecordDef);
      begin
        Write_Extended_Field_Table(ATypedConstBuilder,ADef,FDefaultPacking);
      end;


    procedure TRTTIWriter.PublishedWriteRTTI(ADef : TObjectDef;ARTTIType:TRTTIType);
      var
        lIndex   : LongInt;
        lSymTable : TSymTable;
        lSym : TSym;
      begin
        lSymTable:=ADef.SymTable;
        for lIndex:=0 to lSymTable.SymList.Count-1 do
          begin
            lSym:=TSym(lSymTable.SymList[lIndex]);
            if (lSym.visibility=vis_published) or ADef.Is_Visible_For_RTTI(ro_properties, lSym.visibility)  then
              begin
                case TSym(lSym).typ of
                  propertysym:
                    Write_RTTI(TPropertySym(lSym).PropDef,ARTTIType);
                  FieldVarSym:
                    Write_RTTI(TFieldVarSym(lSym).vardef,ARTTIType);
                  else
                    ;
                end;
              end;
          end;
      end;


    procedure TRTTIWriter.CollectPropNameList(APropNameList:TFPHashObjectList;ADef:TAbstractRecordDef;AVisibilities:TVisibilities);
      var
        lIndex   : LongInt;
        lSym : TSym;
        lPropName  : TPropNameListItem;
      begin
        { search into parent for objects }
        if ADef.typ=objectdef then
          begin
            if Assigned(TObjectDef(ADef).ChildOf) then
              CollectPropNameList(APropNameList,TObjectDef(ADef).ChildOf,AVisibilities);
          end;
        for lIndex:=0 to ADef.SymTable.SymList.Count-1 do
          begin
            lSym:=TSym(ADef.SymTable.SymList[lIndex]);
            if (TSym(lSym).typ=propertysym) and
               (lSym.visibility in AVisibilities) then
              begin
                lPropName:=TPropNameListItem(APropNameList.Find(TSym(lSym).name));
                if not Assigned(lPropName) then
                  begin
                     lPropName:=TPropNameListItem.Create(APropNameList,TSym(lSym).name);
                     lPropName.PropIndex:=APropNameList.count-1;
                     lPropName.PropOwner:=TSym(lSym).owner;
                  end;
             end;
          end;
      end;


    procedure TRTTIWriter.PropertiesWriteRTTIData(ATypedConstBuilder: TTAITypedConstBuilder; APropNameList:TFPHashObjectList; ASymTable:TSymTable; AExtendedRTTI:Boolean; AVisibilities:TVisibilities);
      var
        lIndex : LongInt;
        lSym : TSym;
        lProcTypesInfo : Byte;
        lPropNameItem  : TPropNameListItem;
        lPropDefName : String;
        lTableTypedConstBuilder : TTAITypedConstBuilder;
        lTableLabel : TAsmLabel;
        lTableDef : TDef;
        lVisibilityByte : Byte;

        procedure WriteAccessProc(ATypedConstBuilder: TTAITypedConstBuilder; APropAccessType:TPropAccessListTypes; AShiftValue : Byte; AUnsetValue: Byte);
        var
           lTypeValue : Byte;
           lPropAccessItem : PPropAccessListItem;
           lExtNumber: LongInt;
           lAddress,lSpace : LongInt;
           lDef : TDef;
           lPropertySym : TPropertySym;
           lPropAccessList : TPropAccessList;
        begin
           lPropertySym:=TPropertySym(lSym);
           repeat
             lPropAccessList:=lPropertySym.PropAccessList[APropAccessType];
             if not lPropAccessList.empty then
               break;
             lPropertySym:=lPropertySym.OverriddenPropSym;
           until not Assigned(lPropertySym);
           if not(Assigned(lPropAccessList) and Assigned(lPropAccessList.FirstSym))  then
             begin
               ATypedConstBuilder.emit_tai(TAIConst.Create_int_codeptr(AUnsetValue),CodePtrUIntType);
               lTypeValue:=3;
             end
           { also for accessing class fields }
           else if lPropAccessList.FirstSym^.sym.typ=FieldVarSym then
             begin
                lAddress:=0;
                lPropAccessItem:=lPropAccessList.FirstSym;
                lDef:=nil;
                while Assigned(lPropAccessItem) do
                  begin
                     case lPropAccessItem^.SLType of
                       sl_load :
                         begin
                           lDef:=TFieldVarSym(lPropAccessItem^.sym).vardef;
                           inc(lAddress,TFieldVarSym(lPropAccessItem^.sym).FieldOffset);
                         end;
                       sl_subscript :
                         begin
                           if not(Assigned(lDef) and
                                  ((lDef.typ=recorddef) or
                                   Is_Object(lDef))) then
                             InternalError(200402171);
                           inc(lAddress,TFieldVarSym(lPropAccessItem^.sym).FieldOffset);
                           lDef:=TFieldVarSym(lPropAccessItem^.sym).vardef;
                         end;
                       sl_vec :
                         begin
                           if not(Assigned(lDef) and (lDef.typ=arraydef)) then
                             InternalError(200402172);
                           lDef:=TArrayDef(lDef).ElementDef;
                           {Hp.value is a Tconstexprint, which can be rather large,
                            sanity check for longint overflow.}
                           lSpace:=(high(lAddress)-lAddress) div lDef.Size;
                           if Int64(lSpace)<lPropAccessItem^.Value then
                             InternalError(200706101);
                           inc(lAddress,Int64(lDef.Size*lPropAccessItem^.Value));
                         end;
                       else
                         InternalError(2019050523);
                     end;
                     lPropAccessItem:=lPropAccessItem^.next;
                  end;
                ATypedConstBuilder.emit_tai(TAIConst.Create_int_codeptr(lAddress),CodePtrUIntType);
                lTypeValue:=0;
             end
           else
             begin
                { When there was an error then procdef is not assigned }
                if not Assigned(lPropAccessList.procdef) then
                  exit;
                if not(po_virtualmethod in TProcDef(lPropAccessList.procdef).ProcOptions) or
                   Is_ObjectPascal_Helper(TProcDef(lPropAccessList.procdef).struct) then
                  begin
                    ATypedConstBuilder.queue_init(CodePtrUIntType);
                    ATypedConstBuilder.queue_emit_proc(TProcDef(lPropAccessList.procdef));
                    lTypeValue:=1;
                  end
                else
                  begin
                    { virtual method, write vmt offset }
                    lExtNumber:=TProcDef(lPropAccessList.procdef).ExtNumber;
                    ATypedConstBuilder.emit_tai(TAIConst.Create_int_codeptr(
                      TObjectDef(TProcDef(lPropAccessList.procdef).struct).VMTMethodOffset(lExtNumber)),
                      CodePtrUIntType);
                    { register for wpo }
                    TObjectDef(TProcDef(lPropAccessList.procdef).struct).Register_VMT_Call(lExtNumber);
                    {$ifdef vtentry}
                    { not sure if we can insert those vtentry symbols safely here }
                    {$error register methods used for published properties}
                    {$endif vtentry}
                    lTypeValue:=2;
                  end;
             end;
           lProcTypesInfo:=lProcTypesInfo or (lTypeValue shl AShiftValue);
        end;

        function PropertiesCount(ASymTable:TSymTable):LongInt;
          var
            lIndex   : LongInt;
            lSym : TSym;
          begin
            Result:=0;
            for lIndex:=0 to ASymTable.SymList.Count-1 do
              begin
                lSym:=TSym(ASymTable.SymList[lIndex]);
                if (TSym(lSym).typ=propertysym) and
                   (lSym.visibility in AVisibilities) and
                   (AExtendedRTTI or (
                     (TPropertySym(lSym).ParaST=Nil) and
                     not (sp_static in lSym.SymOptions)
                   )) then
                  inc(Result);
              end;
          end;

        procedure WritePropParams(ATypedConstBuilder:TTAITypedConstBuilder;AParamST:TSymTable);
          var
            lParamTypedConstBuilder : TTAITypedConstBuilder;
            lParamLabel : TAsmLabel;
            lParamDef : TDef;
            lIndex : LongInt;
          begin
              ATypedConstBuilder.start_internal_data_builder(CurrentAsmData.AsmLists[al_rtti],sec_rodata,'',lParamTypedConstBuilder,lParamLabel);

              lParamTypedConstBuilder.begin_anonymous_record('',FDefaultPacking,min(FRequiredAlignment,SizeOf(PInt)),
                targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

              { paramcount }
              lParamTypedConstBuilder.emit_ord_const(AParamST.SymList.count,U32IntType);
              for lIndex:=0 to AParamST.SymList.count-1 do
                begin
                  if TSym(AParamST.SymList[lIndex]).typ<>paravarsym then
                    InternalError(2024103101);
                  WriteParam(lParamTypedConstBuilder,TParaVarSym(AParamST.SymList[lIndex]));
                end;


              lParamDef:=lParamTypedConstBuilder.end_anonymous_record;
              ATypedConstBuilder.finish_internal_data_builder(lParamTypedConstBuilder,lParamLabel,lParamDef,sizeof(PInt));

              ATypedConstBuilder.emit_tai(TAIConst.Create_sym(lParamLabel),VoidPointerType);
          end;

        function WritePropInfoData(ATypedConstBuilder: TTAITypedConstBuilder; ASym: TPropertySym): TDef;
          begin
            { we can only easily reuse defs if the property is not stored,
              because otherwise the rtti layout depends on how the "stored"
              is defined (field, indexed expression, virtual method, ...) }
            if not(ppo_stored in ASym.PropOptions) then
              lPropDefName:=InternalTypePrefixName[itp_rtti_prop]+ToStr(length(ASym.realname))
            else
              lPropDefName:='';
            { TPropInfo is a packed record (even on targets that require
              alignment), but it starts aligned }
            if FAddComments then
              if Assigned(ASymTable.name) then
                ATypedConstBuilder.emit_comment('RTTI: begin propinfo record '+ASym.realname+' (class/rec: '+ASymTable.name^+')')
              else
                ATypedConstBuilder.emit_comment('RTTI: begin propinfo record '+ASym.realname+'(anon)');
            ATypedConstBuilder.begin_anonymous_record(
              lPropDefName,
              1,min(FRequiredAlignment,SizeOf(PInt)),
              targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
            if ppo_indexed in ASym.PropOptions then
              lProcTypesInfo:=$40
            else
              lProcTypesInfo:=0;
            if FAddComments then
              ATypedConstBuilder.emit_comment(#9'type info '+ASym.Name+' (Type: '+ASym.PropDef.GetTypeName+')');
            WriteRTTIReference(ATypedConstBuilder,ASym.PropDef,fullrtti);
            if FAddComments then
              ATypedConstBuilder.emit_comment(#9'read access');
            WriteAccessProc(ATypedConstBuilder,palt_read,0,0);
            if FAddComments then
              ATypedConstBuilder.emit_comment(#9'write access');
            WriteAccessProc(ATypedConstBuilder,palt_write,2,0);
            { is it stored ? }
            if FAddComments then
              ATypedConstBuilder.emit_comment(#9'stored ?');
            if not(ppo_stored in ASym.PropOptions) then
              begin
                { no, so put a constant zero }
                ATypedConstBuilder.emit_tai(TAIConst.Create_nil_codeptr,CodePtrUIntType);
                lProcTypesInfo:=lProcTypesInfo or (3 shl 4);
              end
            else
              WriteAccessProc(ATypedConstBuilder,palt_stored,4,1); { maybe; if no procedure put a constant 1 (=true) }
            if FAddComments then
              ATypedConstBuilder.emit_comment(#9'Index');
            ATypedConstBuilder.emit_ord_const(ASym.Index,U32IntType);
            if FAddComments then
              ATypedConstBuilder.emit_comment(#9'default');
            ATypedConstBuilder.emit_ord_const(ASym.default,U32IntType);
            lPropNameItem:=TPropNameListItem(APropNameList.Find(ASym.name));
            if not Assigned(lPropNameItem) then
              InternalError(200512201);
            if FAddComments then
              ATypedConstBuilder.emit_comment(#9'property index');
            ATypedConstBuilder.emit_ord_const(lPropNameItem.PropIndex,U16IntType);
            if FAddComments then
              ATypedConstBuilder.emit_comment(#9'proc types');
            ATypedConstBuilder.emit_ord_const(lProcTypesInfo,U8IntType);
            if FAddComments then
              ATypedConstBuilder.emit_comment(#9'is static prop');
            ATypedConstBuilder.emit_ord_const(ord(sp_static in ASym.SymOptions),PasBool1Type);
            { index parameters }
            if FAddComments then
              ATypedConstBuilder.emit_comment(#9'indexed params');
            if AExtendedRTTI and Assigned(TPropertySym(ASym).ParaST) then
              WritePropParams(ATypedConstBuilder,ASym.ParaST)
            else
              ATypedConstBuilder.emit_tai(TAIConst.create_nil_dataptr,VoidPointerType);
            { write reference to attribute table }
            if FAddComments then
              ATypedConstBuilder.emit_comment(#9'attributes');
            WriteAttributeData(ATypedConstBuilder,ASym.RTTIAttributeList);
            { write property name }
            if FAddComments then
              ATypedConstBuilder.emit_comment(#9'name');
            ATypedConstBuilder.emit_shortstring_const(ASym.realname);
            Result:=ATypedConstBuilder.end_anonymous_record;
            if FAddComments then
              ATypedConstBuilder.emit_comment('RTTI: End propinfo record '+ASym.realname);
          end;

      begin
        ATypedConstBuilder.begin_anonymous_record('',FDefaultPacking,min(FRequiredAlignment,SizeOf(PInt)),
          targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
        if AExtendedRTTI then
          MaybeAddComment(ATypedConstBuilder,'RTTI: Extended property data: Property count')
        else
          MaybeAddComment(ATypedConstBuilder,'RTTI: Legacy property data: Property count');
        ATypedConstBuilder.emit_ord_const(PropertiesCount(ASymTable),U16IntType);
        for lIndex:=0 to ASymTable.SymList.Count-1 do
          begin
            lSym:=TSym(ASymTable.SymList[lIndex]);
            if (lSym.typ=propertysym) and
               (lSym.visibility in AVisibilities) and
               (AExtendedRTTI or (TPropertySym(lSym).ParaST=Nil)) then
              begin
                if AExtendedRTTI then
                  begin
                    {
                      TPropInfoEx = record
                        Flags: Byte;
                        Info: PPropInfo;
                        // AttrData: TAttrData
                      end;
                    }
                    MaybeAddComment(ATypedConstBuilder,'RTTI: begin property '+lSym.prettyname);
                    ATypedConstBuilder.begin_anonymous_record('',FDefaultPacking,min(FRequiredAlignment,SizeOf(PInt)),
                      targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
                    { write visiblity flags for extended RTTI }
                    MaybeAddComment(ATypedConstBuilder,#9'visibility flags');
                    lVisibilityByte:=Byte(VisibilityToRTTIFlags(lSym.visibility));
                    ATypedConstBuilder.emit_ord_const(lVisibilityByte,U8IntType);
                    { create separate constant builder }
                    CurrentAsmData.getglobaldatalabel(lTableLabel);
                    lTableTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_is_lab,tcalo_make_dead_strippable]);
                    { write TPropInfo record }
                    lTableDef:=WritePropInfoData(lTableTypedConstBuilder,TPropertySym(lSym));
                    CurrentAsmData.asmlists[al_rtti].ConcatList(
                      lTableTypedConstBuilder.get_final_asmlist(lTableLabel,lTableDef,sec_rodata,lTableLabel.name,Const_Align(sizeof(PInt)))
                    );
                    lTableTypedConstBuilder.free;
                    lTableTypedConstBuilder := nil;
                    { write the pointer to the prop info }
                    MaybeAddComment(ATypedConstBuilder,#9'property info reference');
                    ATypedConstBuilder.emit_tai(TAIConst.Create_sym(lTableLabel),VoidPointerType);
                    { end record }
                    ATypedConstBuilder.end_anonymous_record;
                    MaybeAddComment(ATypedConstBuilder,'RTTI: end property '+lSym.prettyname);
                  end
                else if not (sp_static in lSym.SymOptions) then
                  WritePropInfoData(ATypedConstBuilder,TPropertySym(lSym));
              end;
          end;
        ATypedConstBuilder.end_anonymous_record;
      end;


    procedure TRTTIWriter.WriteRTTIData(ATypedConstBuilder: TTAITypedConstBuilder; ADef: TDef; ARTTIType: TRTTIType);

        procedure UnknownRTTI(ADef:TStoredDef);
        begin
          ATypedConstBuilder.emit_ord_const(TkUnknown,U8IntType);
          WriteRTTIName(ATypedConstBuilder,ADef);
          WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);
        end;

        procedure VariantDefRTTI(ADef:TVariantDef);
        begin
          WriteHeader(ATypedConstBuilder,ADef,TkVariant);
          WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);
        end;

        procedure StringDefRTTI(ADef:TStringDef);
        const
          cStringTypeKinds: array[TStringType] of Byte = (
            TkSString,TkLString,TkAString,TkWString,TkUString
          );
        begin
          WriteHeader(ATypedConstBuilder,ADef,cStringTypeKinds[ADef.StringType]);
          ATypedConstBuilder.begin_anonymous_record(
            InternalTypePrefixName[itp_rtti_outer]+ToStr(cStringTypeKinds[ADef.StringType]),
            FDefaultPacking,FRequiredAlignment,
            targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
          WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);
          case ADef.StringType of
            st_ansistring:
              begin
                ATypedConstBuilder.begin_anonymous_record(
                  InternalTypePrefixName[itp_rtti_case]+ToStr(cStringTypeKinds[ADef.StringType]),
                  FDefaultPacking,FRequiredAlignment,
                  targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
                ATypedConstBuilder.emit_ord_const(ADef.encoding,U16IntType);
                ATypedConstBuilder.end_anonymous_record;
              end;

            st_shortstring:
              begin
                ATypedConstBuilder.begin_anonymous_record(
                  InternalTypePrefixName[itp_rtti_case]+ToStr(cStringTypeKinds[ADef.StringType]),
                  FDefaultPacking,FRequiredAlignment,
                  targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
                ATypedConstBuilder.emit_ord_const(ADef.len,U8IntType);
                ATypedConstBuilder.end_anonymous_record;
              end;

            st_widestring,
            st_unicodestring,
            st_longstring:
              { nothing }
              ;

          end;
          ATypedConstBuilder.end_anonymous_record;
        end;

        procedure EnumDefRTTI(ADef: TEnumDef);
        var
           lIndex  : Integer;
           lEnumSym : TEnumSym;
        begin
          WriteHeader(ATypedConstBuilder,ADef,TkEnumeration);
          { align; the named fields are so that we can let the compiler
            calculate the string offsets later on }
          ATypedConstBuilder.next_field_name:='size_start_rec';
          { add a typename so that it can be reused when writing the the s2o
            and o2s arrays for llvm (otherwise we have to write out the entire
            type definition every time we access an element from this record) }
          ATypedConstBuilder.begin_anonymous_record(InternalTypePrefixName[itp_rtti_enum_size_start_rec]+ADef.UniqueIDStr,FDefaultPacking,FRequiredAlignment,
            targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
          WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);
          ATypedConstBuilder.next_field_name:='typ_union_rec';
          ATypedConstBuilder.begin_anonymous_record(InternalTypePrefixName[itp_rtti_enum_size_start_rec2]+ADef.UniqueIDStr,FDefaultPacking,FRequiredAlignment,
            targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
          case LongInt(ADef.Size) of
            1 :
              ATypedConstBuilder.emit_ord_const(OtUByte,U8IntType);
            2 :
              ATypedConstBuilder.emit_ord_const(OtUWord,U8IntType);
            4 :
              ATypedConstBuilder.emit_ord_const(OtULong,U8IntType);
          end;
          { we need to align by Tconstptruint here to satisfy the alignment
            rules set by records: in the typinfo unit we overlay a TTypeData
            record on this data, which at the innermost variant record needs an
            alignment of TConstPtrUint due to e.g. the "CompType" member for
            tkSet (also the "BaseType" member for tkEnumeration).

            We need to adhere to this, otherwise things will break. }
          ATypedConstBuilder.next_field_name:='min_max_rec';
          ATypedConstBuilder.begin_anonymous_record(InternalTypePrefixName[itp_rtti_enum_min_max_rec]+ADef.UniqueIDStr,FDefaultPacking,FRequiredAlignment,
            targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
          ATypedConstBuilder.emit_ord_const(ADef.min,S32IntType);
          ATypedConstBuilder.emit_ord_const(ADef.max,S32IntType);
          ATypedConstBuilder.next_field_name:='basetype_array_rec';
          { all strings must appear right after each other -> from now on
            packrecords 1 (but the start must still be aligned) }
          ATypedConstBuilder.begin_anonymous_record(InternalTypePrefixName[itp_rtti_enum_basetype_array_rec]+ADef.UniqueIDStr,1,FRequiredAlignment,
            targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
          { write base type }
          WriteRTTIReference(ATypedConstBuilder,ADef.BaseDef,ARTTIType);
          for lIndex:=0 to ADef.SymTable.SymList.Count-1 do
            begin
              lEnumSym:=TEnumSym(ADef.SymTable.SymList[lIndex]);
              if lEnumSym.Value<ADef.MinVal then
                continue
              else
              if lEnumSym.Value>ADef.MaxVal then
                break;
              ATypedConstBuilder.next_field_name:=lEnumSym.name;
              ATypedConstBuilder.emit_shortstring_const(lEnumSym.realname);
            end;
          { write unit name }
          ATypedConstBuilder.emit_shortstring_const(CurrentModule.RealModuleName^);
          { write zero which is required by RTL }
          ATypedConstBuilder.emit_ord_const(0,U8IntType);
          { terminate all records }
          ATypedConstBuilder.end_anonymous_record;
          ATypedConstBuilder.end_anonymous_record;
          ATypedConstBuilder.end_anonymous_record;
          ATypedConstBuilder.end_anonymous_record;
        end;

        procedure OrdDefRTTI(ADef:TOrdDef);

          procedure DoInt32Or64(ATypeKind: Byte;AMin,AMax:Int64);
            const
              cOrdTypeTranslations : array[TOrdType] of Byte =
                (OtUByte{otNone},
                 OtUByte,OtUWord,OtULong,OtUQWord,OtUByte{otNone},
                 OtSByte,OtSWord,OtSLong,OtSQWord,OtUByte{otNone},
                 OtUByte,OtUByte,OtUWord,OtULong,OtUQWord,
                 OtSByte,OtSWord,OtSLong,OtSQWord,
                 OtUByte,OtUWord,OtUByte,255);
            var
              lElementSize: String[1];
              lDefTranslation: Byte;
          begin
            WriteHeader(ATypedConstBuilder,ADef,ATypeKind);
            lDefTranslation:=cOrdTypeTranslations[ADef.OrdType];
            case lDefTranslation of
              OtUQWord,
              OtSQWord:
                lElementSize:='8';
              255:
                begin
                  if ADef.PackedBitSize<=32 then
                    begin
                      lElementSize:='4';
                      if ADef.low<0 then
                        lDefTranslation:=OtSLong
                      else
                        lDefTranslation:=OtULong;
                    end
                  else
                    begin
                      lElementSize:='8';
                      if ADef.low<0 then
                        lDefTranslation:=OtSQWord
                      else
                        lDefTranslation:=OtUQWord;
                    end;
                end
              else
                lElementSize:='4'
            end;
            ATypedConstBuilder.begin_anonymous_record(
              InternalTypePrefixName[itp_rtti_ord_outer]+lElementSize,
              FDefaultPacking,FRequiredAlignment,
              targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
            WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);
            ATypedConstBuilder.begin_anonymous_record(
              InternalTypePrefixName[itp_rtti_ord_middle]+lElementSize,
              FDefaultPacking,FRequiredAlignment,
              targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
            ATypedConstBuilder.emit_ord_const(Byte(cOrdTypeTranslations[ADef.OrdType]),U8IntType);
            ATypedConstBuilder.begin_anonymous_record(
              InternalTypePrefixName[itp_rtti_ord_inner]+lElementSize,
              FDefaultPacking,FRequiredAlignment,
              targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
            {Convert to longint to smuggle values in high(longint)+1..high(cardinal) into asmlist.}
            case lDefTranslation of
              OtUQWord:
                begin
                  ATypedConstBuilder.emit_ord_const(AMin,U64IntType);
                  ATypedConstBuilder.emit_ord_const(AMax,U64IntType);
                end;
              OtSQWord:
                begin
                  ATypedConstBuilder.emit_ord_const(AMin,S64IntType);
                  ATypedConstBuilder.emit_ord_const(AMax,S64IntType);
                end;
              else
                begin
                  ATypedConstBuilder.emit_ord_const(LongInt(AMin),S32IntType);
                  ATypedConstBuilder.emit_ord_const(LongInt(AMax),S32IntType);
                end;
            end;
            ATypedConstBuilder.end_anonymous_record;
            ATypedConstBuilder.end_anonymous_record;
            ATypedConstBuilder.end_anonymous_record;
          end;

        procedure DoInteger(ATypeKind:Byte);inline;
          begin
            DoInt32Or64(ATypeKind,Int64(ADef.low.svalue),Int64(ADef.high.svalue));
          end;

        begin
          case ADef.OrdType of
            s64bit :
                DoInteger(TkInt64);
            u64bit :
                DoInteger(TkQWord);
            pasbool1,
            pasbool8,
            pasbool16,
            pasbool32,
            pasbool64:
                DoInteger(TkBool);
            { use different low/high values to be Delphi compatible }
            bool8bit,
            bool16bit,
            bool32bit:
                DoInt32Or64(TkBool,LongInt(low(LongInt)),LongInt(high(LongInt)));
            bool64bit:
                DoInt32Or64(TkBool,low(Int64),high(Int64));
            uchar:
                DoInteger(TkChar);
            uwidechar:
                DoInteger(TkWChar);
            scurrency:
              begin
                WriteHeader(ATypedConstBuilder,ADef,TkFloat);
                ATypedConstBuilder.begin_anonymous_record(
                  InternalTypePrefixName[itp_1byte],
                  FDefaultPacking,FRequiredAlignment,
                  targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
                WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);
                ATypedConstBuilder.emit_ord_const(FtCurr,U8IntType);
                ATypedConstBuilder.end_anonymous_record;
              end;
            else
              DoInteger(TkInteger);
          end;
        end;


        procedure FloatDefRTTI(ADef:TFloatDef);
        const
          cFloatTypeTranslations : array[TFloatType] of Byte =
             (FtSingle,FtDouble,FtExtended,FtExtended,FtComp,FtCurr);
        begin
           WriteHeader(ATypedConstBuilder,ADef,TkFloat);
           ATypedConstBuilder.begin_anonymous_record(
             InternalTypePrefixName[itp_1byte],
             FDefaultPacking,FRequiredAlignment,
             targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
           WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);
           ATypedConstBuilder.begin_anonymous_record(
             InternalTypePrefixName[itp_rtti_float],
             FDefaultPacking,FRequiredAlignment,
             targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
           ATypedConstBuilder.emit_ord_const(cFloatTypeTranslations[ADef.FloatType],U8IntType);
           ATypedConstBuilder.end_anonymous_record;
           ATypedConstBuilder.end_anonymous_record;
        end;


        procedure SetDefRTTI(ADef:TSetDef);
        begin
           WriteHeader(ATypedConstBuilder,ADef,TkSet);
           ATypedConstBuilder.begin_anonymous_record(
             InternalTypePrefixName[itp_rtti_set_outer],
             FDefaultPacking,FRequiredAlignment,
             targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
           WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);
           ATypedConstBuilder.begin_anonymous_record(
             InternalTypePrefixName[itp_rtti_set_middle],
             FDefaultPacking,FRequiredAlignment,
             targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
           case ADef.Size of
             1:
               ATypedConstBuilder.emit_ord_const(OtUByte,U8IntType);
             2:
               ATypedConstBuilder.emit_ord_const(OtUWord,U8IntType);
             4:
               ATypedConstBuilder.emit_ord_const(OtULong,U8IntType);
             else
               ATypedConstBuilder.emit_ord_const(OtUByte,U8IntType);
           end;
           ATypedConstBuilder.begin_anonymous_record(
             InternalTypePrefixName[itp_rtti_set_inner],
             FDefaultPacking,FRequiredAlignment,
             targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
           ATypedConstBuilder.emit_ord_const(ADef.Size,SizeSIntType);
           WriteRTTIReference(ATypedConstBuilder,ADef.ElementDef,ARTTIType);
           ATypedConstBuilder.end_anonymous_record;
           ATypedConstBuilder.end_anonymous_record;
           ATypedConstBuilder.end_anonymous_record;
        end;


        procedure ArrayDefRTTI(ADef:TArrayDef);
          var
            lIndex,lDimensionCount: Byte;
            lTotalCount: ASizeUInt;
            lFinalDef: TDef;
            lCurrentDef:TArrayDef;
        begin
           if ado_IsDynamicArray in ADef.ArrayOptions then
             ATypedConstBuilder.emit_ord_const(TkDynArray,U8IntType)
           else
             ATypedConstBuilder.emit_ord_const(TkArray,U8IntType);
           WriteRTTIName(ATypedConstBuilder,ADef);

           if not(ado_IsDynamicArray in ADef.ArrayOptions) then
             begin
               { remember tha last instruction. we will need to insert some
                 calculated values after it }
               lFinalDef:=ADef;
               lTotalCount:=1;
               lDimensionCount:=0;
               repeat
                 lCurrentDef:=TArrayDef(lFinalDef);
                 lFinalDef:=lCurrentDef.ElementDef;
                 { Dims[i] PTypeInfo }
                 inc(lDimensionCount);
                 lTotalCount:=lTotalCount*lCurrentDef.EleCount;
               until (lFinalDef.typ<>arraydef) or
                     (ado_IsDynamicArray in TArrayDef(lFinalDef).ArrayOptions);
               ATypedConstBuilder.begin_anonymous_record(
                 InternalTypePrefixName[itp_rtti_normal_array]+ToStr(lDimensionCount),
                 FDefaultPacking,FRequiredAlignment,
                 targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

               WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);

               ATypedConstBuilder.begin_anonymous_record(InternalTypePrefixName[itp_rtti_normal_array_inner]+ToStr(lDimensionCount),
                 FDefaultPacking,FRequiredAlignment,
                 targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

               { total size = elecount * elesize of the first arraydef }
               ATypedConstBuilder.emit_tai(TAIConst.Create_sizeint(ADef.EleCount*ADef.EleSize),SizeUIntType);
               { total element count }
               ATypedConstBuilder.emit_tai(TAIConst.Create_sizeint(asizeint(lTotalCount)),SizeUIntType);
               { last dimension element type }
               if Is_ObjC_Class_Or_Protocol(lCurrentDef.ElementDef) then
                 ATypedConstBuilder.emit_tai(TAIConst.Create_sym(Get_RTTI_Label(VoidPointerType,ARTTIType,true)),VoidPointerType)
               else
                 ATypedConstBuilder.emit_tai(TAIConst.Create_sym(Get_RTTI_Label(lCurrentDef.ElementDef,ARTTIType,true)),VoidPointerType);
               { dimension count }
               ATypedConstBuilder.emit_ord_const(lDimensionCount,U8IntType);
               lFinalDef:=ADef;
               { ranges of the dimensions }
               for lIndex:=1 to lDimensionCount do
                 begin
                   lCurrentDef:=TArrayDef(lFinalDef);
                   lFinalDef:=lCurrentDef.ElementDef;
                   { Dims[i] PPTypeInfo }
                   WriteRTTIReference(ATypedConstBuilder,lCurrentDef.RangeDef,ARTTIType);
                 end;
             end
           else
             { write a delphi almost compatible dyn. array entry:
               there are two types, eltype and eltype2, the latter is nil if the element type needs
               no finalization, the former is always valid, delphi has this swapped, but for
               compatibility with older fpc versions we do it different, to be delphi compatible,
               the names are swapped in typinfo.pas
             }
             begin
               ATypedConstBuilder.begin_anonymous_record(
                 InternalTypePrefixName[itp_rtti_dyn_array],
                 FDefaultPacking,FRequiredAlignment,
                 targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

               WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);

               { record in TypInfo is aligned differently from init rtti }
               ATypedConstBuilder.begin_anonymous_record(
                 InternalTypePrefixName[itp_rtti_dyn_array_inner],
                 FDefaultPacking,FRequiredAlignment,
                 targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

               { size of elements }
               ATypedConstBuilder.emit_tai(TAIConst.Create_sizeint(ADef.EleSize),SizeUIntType);
               { element type }
               WriteRTTIReference(ATypedConstBuilder,ADef.ElementDef,ARTTIType);
               { variant type }
               ATypedConstBuilder.emit_ord_const(TStoredDef(ADef.ElementDef).GetVarDef,S32IntType);
               { element type }
               if ADef.ElementDef.NeedsInitTable then
                 WriteRTTIReference(ATypedConstBuilder,ADef.ElementDef,ARTTIType)
               else
                 ATypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
               { write unit name }
               ATypedConstBuilder.emit_shortstring_const(CurrentModule.RealModuleName^);
             end;

          ATypedConstBuilder.end_anonymous_record;
          ATypedConstBuilder.end_anonymous_record;
        end;

        procedure ClassRefDefRTTI(ADef:TClassRefDef);
        begin
          WriteHeader(ATypedConstBuilder,ADef,TkClassRef);
          ATypedConstBuilder.begin_anonymous_record(
            InternalTypePrefixName[itp_rtti_ref],
            FDefaultPacking,FRequiredAlignment,
            targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
          WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);
          ATypedConstBuilder.begin_anonymous_record(
            InternalTypePrefixName[itp_rtti_classref],
            FDefaultPacking,FRequiredAlignment,
            targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
          WriteRTTIReference(ATypedConstBuilder,ADef.PointedDef,ARTTIType);
          ATypedConstBuilder.end_anonymous_record;
          ATypedConstBuilder.end_anonymous_record;
        end;

        procedure PointerDefRTTI(ADef:TPointerDef);
        begin
          WriteHeader(ATypedConstBuilder,ADef,TkPointer);
          ATypedConstBuilder.begin_anonymous_record(
            InternalTypePrefixName[itp_rtti_ref],
            FDefaultPacking,FRequiredAlignment,
            targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
          WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);
          ATypedConstBuilder.begin_anonymous_record(
            InternalTypePrefixName[itp_rtti_pointer],
            FDefaultPacking,FRequiredAlignment,
            targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
          WriteRTTIReference(ATypedConstBuilder,ADef.PointedDef,ARTTIType);
          ATypedConstBuilder.end_anonymous_record;
          ATypedConstBuilder.end_anonymous_record;
        end;

        procedure RecordDefRTTI(ADef:TRecordDef);

          procedure WriteRecordOperators(ARTTILabel:TAsmLabel);
          var
            lRTTIDef: TDef;
            lTypedConstBuilder: TTAITypedConstBuilder;
            lManagementOperator: TManagementOperator;
            lProcDef: TProcDef;
          begin
            lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_make_dead_strippable]);

            lTypedConstBuilder.begin_anonymous_record(
              '',
              FDefaultPacking,min(FRequiredAlignment,SizeOf(PInt)),
              targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin
            );

            { use "succ" to omit first enum item "mop_none" }
            for lManagementOperator := succ(low(TManagementOperator)) to high(TManagementOperator) do
            begin
              if not (lManagementOperator in TRecordSymTable(ADef.SymTable).ManagementOperators) then
                lTypedConstBuilder.emit_tai(TAIConst.Create_nil_codeptr,VoidCodePointerType)
              else
                begin
                  lProcDef := Search_Management_Operator(lManagementOperator, ADef);
                  if lProcDef = nil then
                    InternalError(201603021)
                  else
                    lTypedConstBuilder.emit_tai(TAIConst.Createname(lProcDef.MangledName,AT_FUNCTION,0),
                      CProcVarDef.GetReusableProcAddr(lProcDef,pc_address_only));
                end;
            end;

            lRTTIDef := lTypedConstBuilder.end_anonymous_record;

            CurrentAsmData.AsmLists[al_rtti].ConcatList(
              lTypedConstBuilder.get_final_asmlist(ARTTILabel,lRTTIDef,sec_rodata,ARTTILabel.name,
              sizeof(PInt)));
            lTypedConstBuilder.free;
            lTypedConstBuilder := nil;
          end;


          procedure WriteExtendedPropertyTable;
          var
            lPropNameList: TFPHashObjectList;
            lVisibilities: TVisibilities;
          begin
            lPropNameList:=TFPHashObjectList.Create;
            lVisibilities:=ADef.RTTI_Visibilities_For_Option(ro_properties);
            CollectPropNameList(lPropNameList,ADef,lVisibilities);
            PropertiesWriteRTTIData(ATypedConstBuilder,lPropNameList,ADef.SymTable,true,lVisibilities);
            lPropNameList.free;
            lPropNameList := nil;
          end;

        var
          lOperatorLabel : TAsmLabel;

        begin
           WriteHeader(ATypedConstBuilder,ADef,TkRecord);
           { need extra reqalign record, because otherwise the u32 int will
             only be aligned to 4 even on 64 bit target (while the rtti code
             in typinfo expects alignments to sizeof(pointer)) }
           ATypedConstBuilder.begin_anonymous_record('',
             FDefaultPacking,FRequiredAlignment,
             targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

           WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);

           ATypedConstBuilder.begin_anonymous_record('',
             FDefaultPacking,FRequiredAlignment,
             targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
           { store special terminator for init table for more optimal rtl operations
             strictly related to RecordRTTI procedure in rtti.inc (directly
             related to RTTIRecordRttiInfoToInitInfo function) }
           if ARTTIType=initrtti then
             ATypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType)
           else
             { we use a direct reference as the init RTTI is always in the same
               unit as the full RTTI }
             ATypedConstBuilder.emit_tai(TAIConst.Create_sym(Get_RTTI_Label(ADef,initrtti,false)),VoidPointerType);

           ATypedConstBuilder.emit_ord_const(ADef.Size,U32IntType);

           lOperatorLabel:=nil;
           { store rtti management operators only for init table }
           if ARTTIType=initrtti then
             begin
               { for now records don't have the initializer table }
               ATypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
               if (TRecordSymTable(ADef.SymTable).ManagementOperators=[]) then
                 ATypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType)
               else
                 begin
                   CurrentAsmData.getlocaldatalabel(lOperatorLabel);
                   ATypedConstBuilder.emit_tai(TAIConst.Createname(
                     lOperatorLabel.name,
                     AT_DATA_FORCEINDIRECT,0),VoidPointerType);
                 end;
             end;

           FieldsWriteRTTIData(ATypedConstBuilder,ADef,ARTTIType);
           { write extended rtti }
           if ARTTIType=fullrtti then
             begin
               Write_Extended_Field_Table(ATypedConstBuilder,ADef,FDefaultPacking);
               Write_Extended_Method_Table(ATypedConstBuilder,ADef,FDefaultPacking);
               WriteExtendedPropertyTable;
             end;
           ATypedConstBuilder.end_anonymous_record;
           ATypedConstBuilder.end_anonymous_record;

           { write pointers to operators if needed }
           if (ARTTIType=initrtti) and (TRecordSymTable(ADef.SymTable).ManagementOperators<>[]) then
             WriteRecordOperators(lOperatorLabel);
        end;


        procedure ProcVarDefRTTI(ADef:TProcVarDef);

           procedure WritePara(AParaSym:TParaVarSym);
             begin
               { write flags for current parameter }
               WriteParamFlag(ATypedConstBuilder,AParaSym);
               { write name of current parameter }
               ATypedConstBuilder.emit_shortstring_const(AParaSym.realname);
               { write name of type of current parameter }
               WriteRTTIName(ATypedConstBuilder,AParaSym.vardef);
             end;

           procedure WriteProcedureParam(AParaSym:TParaVarSym);
             begin
               { every parameter is expected to start aligned }
               ATypedConstBuilder.begin_anonymous_record(
                 InternalTypePrefixName[itp_rtti_proc_param]+ToStr(length(AParaSym.realname)),
                 FDefaultPacking,min(FRequiredAlignment,SizeOf(PInt)),
                 targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
               { write flags for current parameter }
               WriteParamFlag(ATypedConstBuilder,AParaSym);
               { write param type }
               if Is_Open_Array(AParaSym.vardef) or Is_Array_Of_Const(AParaSym.vardef) then
                 WriteRTTIReference(ATypedConstBuilder,TArrayDef(AParaSym.vardef).ElementDef,fullrtti)
               else if AParaSym.vardef=CFormalType then
                 WriteRTTIReference(ATypedConstBuilder,nil,fullrtti)
               else
                 WriteRTTIReference(ATypedConstBuilder,AParaSym.vardef,fullrtti);
               { write name of current parameter }
               ATypedConstBuilder.emit_shortstring_const(AParaSym.realname);
               ATypedConstBuilder.end_anonymous_record;
             end;

        var
          lMethodKind : Byte;
          lIndex : Integer;
        begin
          if po_methodpointer in ADef.ProcOptions then
            begin
               { write method id and name }
               WriteHeader(ATypedConstBuilder,ADef,TkMethod);
               ATypedConstBuilder.begin_anonymous_record('',FDefaultPacking,FRequiredAlignment,
                 targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

               WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);

               ATypedConstBuilder.begin_anonymous_record('',
                 FDefaultPacking,FRequiredAlignment,
                 targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
               { write kind of method }
               lMethodKind:=WriteMethodKind(ATypedConstBuilder,ADef);

               { write parameter info. The parameters must be written in reverse order
                 if this method uses right to left parameter pushing! }
               ATypedConstBuilder.emit_ord_const(ADef.paras.count,U8IntType);

               for lIndex:=0 to ADef.paras.count-1 do
                 WritePara(TParaVarSym(ADef.paras[lIndex]));

               if (lMethodKind=MkFunction) or (lMethodKind=MkClassFunction) then
               begin
                 { write name of result type }
                 WriteRTTIName(ATypedConstBuilder,ADef.ReturnDef);
                 { enclosing record takes care of alignment }
                 { write result typeinfo }
                 WriteRTTIReference(ATypedConstBuilder,ADef.ReturnDef,fullrtti);
               end;

               { write calling convention }
               WriteCallConv(ATypedConstBuilder,ADef);

               { enclosing record takes care of alignment }
               { write params typeinfo }
               for lIndex:=0 to ADef.paras.count-1 do
                 begin
                   if Is_Open_Array(TParaVarSym(ADef.paras[lIndex]).vardef) or Is_Array_Of_Const(TParaVarSym(ADef.paras[lIndex]).vardef) then
                     WriteRTTIReference(ATypedConstBuilder,TArrayDef(TParaVarSym(ADef.paras[lIndex]).vardef).ElementDef,fullrtti)
                   else if TParaVarSym(ADef.paras[lIndex]).vardef=CFormalType then
                     WriteRTTIReference(ATypedConstBuilder,nil,fullrtti)
                   else
                     WriteRTTIReference(ATypedConstBuilder,TParaVarSym(ADef.paras[lIndex]).vardef,fullrtti);
                 end;
               ATypedConstBuilder.end_anonymous_record;
               ATypedConstBuilder.end_anonymous_record;
            end
          else
            begin
              WriteHeader(ATypedConstBuilder,ADef,TkProcVar);
              ATypedConstBuilder.begin_anonymous_record('',FDefaultPacking,FRequiredAlignment,
                targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

              WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);

              ATypedConstBuilder.begin_anonymous_record('',
                FDefaultPacking,FRequiredAlignment,
                targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
              { flags }
              ATypedConstBuilder.emit_ord_const(0,U8IntType);
              { write calling convention }
              WriteCallConv(ATypedConstBuilder,ADef);
              { enclosing record takes care of alignment }
              { write result typeinfo }
              WriteRTTIReference(ATypedConstBuilder,ADef.ReturnDef,fullrtti);
              { write parameter count }
              ATypedConstBuilder.emit_ord_const(ADef.paras.count,U8IntType);
              for lIndex:=0 to ADef.paras.count-1 do
                WriteProcedureParam(TParaVarSym(ADef.paras[lIndex]));
              ATypedConstBuilder.end_anonymous_record;
              ATypedConstBuilder.end_anonymous_record;
            end;
        end;


        procedure ObjectDefRTTI(ADef: TObjectDef);

          procedure ObjectDefRTTIFields(ADef:TObjectDef);
          begin
            MaybeAddComment(ATypedConstBuilder,'RTTI begin fields '+ADef.ObjName^);
            ATypedConstBuilder.begin_anonymous_record('',FDefaultPacking,FRequiredAlignment,
              targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

            { - for compatiblity with record RTTI we need to write a terminator-
                Nil pointer for initrtti as well for objects
              - for RTTI consistency for objects we need point from fullrtti
                to initrtti
              - classes are assumed to have the same INIT RTTI as records
                (see TObject.CleanupInstance)
              - neither helper nor class type have fullrtti for fields
            }
            if (ARTTIType=initrtti) then
              ATypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType)
            else
              if (ADef.ObjectType=odt_object) then
                ATypedConstBuilder.emit_tai(TAIConst.Create_sym(Get_RTTI_Label(ADef,initrtti,false)),VoidPointerType)
              else
                InternalError(2017011801);

            ATypedConstBuilder.emit_ord_const(ADef.Size, U32IntType);
            { pointer to management operators available only for initrtti }
            if (ARTTIType=initrtti) then
              begin
                { initializer table only available for classes currently }
                if ADef.ObjectType=odt_class then
                  WriteMOPOffsetTable(ATypedConstBuilder,ADef,mop_initialize)
                else
                  ATypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
                ATypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
              end;
            { enclosing record takes care of alignment }
            FieldsWriteRTTIData(ATypedConstBuilder,ADef,ARTTIType);

            ATypedConstBuilder.end_anonymous_record;
            MaybeAddComment(ATypedConstBuilder,'RTTI end fields '+ADef.ObjName^);
          end;

          procedure ObjectDefRTTIInterfaceInit(ADef:TObjectDef);
          begin
            ATypedConstBuilder.emit_ord_const(ADef.Size, U32IntType);
          end;

          procedure ObjectDefExtendedRTTIClass(ADef:TObjectDef);
          var
            lPropNameList : TFPHashObjectList;
            lVisibilities : TVisibilities;
          begin
            lPropNameList:=TFPHashObjectList.Create;
            lVisibilities:=ADef.RTTI_Visibilities_For_Option(ro_properties);
            CollectPropNameList(lPropNameList,ADef,lVisibilities);
            PropertiesWriteRTTIData(ATypedConstBuilder,lPropNameList,ADef.SymTable,true,lVisibilities);
            lPropNameList.free;
            lPropNameList := nil;
          end;

          procedure ObjectDefRTTIClassFull(ADef:TObjectDef);
          var
            lPropNameList : TFPHashObjectList;
          begin
            { Collect unique property names with nameindex }
            lPropNameList:=TFPHashObjectList.Create;
            CollectPropNameList(lPropNameList,ADef,[vis_published]);

            ATypedConstBuilder.begin_anonymous_record('',FDefaultPacking,FRequiredAlignment,
              targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

            if not Is_ObjectPascal_Helper(ADef) then
              begin
              MaybeAddComment(ATypedConstBuilder,#9'Parent type info');
              if (oo_has_vmt in ADef.ObjectOptions) then
                ATypedConstBuilder.emit_tai(
                  TAIConst.Createname(ADef.VMT_MangledName,AT_DATA_FORCEINDIRECT,0),
                  CPointerDef.getreusable(ADef.VMT_Def))
              else
                ATypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
              end;
            { write parent typeinfo }
            MaybeAddComment(ATypedConstBuilder,#9'Parent type info');
            WriteRTTIReference(ATypedConstBuilder,ADef.ChildOf,fullrtti);

            { write typeinfo of extended type }
            if Is_ObjectPascal_Helper(ADef) then
              if Assigned(ADef.ExtendedDef) then
                begin
                MaybeAddComment(ATypedConstBuilder,#9'helper for type info');
                WriteRTTIReference(ATypedConstBuilder,ADef.ExtendedDef,fullrtti)
                end
              else
                InternalError(2011033001);

            { total number of unique properties }

            MaybeAddComment(ATypedConstBuilder,#9'Number of properties');
            ATypedConstBuilder.emit_ord_const(lPropNameList.count,U16IntType);

            { write unit name }

            MaybeAddComment(ATypedConstBuilder, #9'Unit name');
            ATypedConstBuilder.emit_shortstring_const(CurrentModule.RealModuleName^);

            { write published properties for this object }
            PropertiesWriteRTTIData(ATypedConstBuilder,lPropNameList,ADef.SymTable,false,[vis_published]);

            { write extended properties }
            ObjectDefExtendedRTTIClass(ADef);

            ATypedConstBuilder.end_anonymous_record;

            lPropNameList.free;
            lPropNameList := nil;
          end;

          procedure ObjectDefRTTIInterfaceFull(ADef:TObjectDef);
          var
            lPropNameList : TFPHashObjectList;
            { if changed to a set, make sure it's still a byte large, and
              swap appropriately when cross-compiling
            }
            lInterfaceFlags: Byte;
          begin
            { Collect unique property names with nameindex }
            lPropNameList:=TFPHashObjectList.Create;
            CollectPropNameList(lPropNameList,ADef,[vis_published]);

            ATypedConstBuilder.begin_anonymous_record('',FDefaultPacking,FRequiredAlignment,
              targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

            { write parent typeinfo }
            WriteRTTIReference(ATypedConstBuilder,ADef.ChildOf,fullrtti);

            { interface: write flags, iid and iidstr }
            lInterfaceFlags:=0;
            if Assigned(ADef.IIDGUID) then
              lInterfaceFlags:=lInterfaceFlags or (1 shl ord(ifHasGuid));
            if (ADef.ObjectType=odt_interfacecorba) and (ADef.IIDStr^<>'') then
              lInterfaceFlags:=lInterfaceFlags or (1 shl ord(ifHasStrGUID));
            if (ADef.ObjectType=odt_dispinterface) then
              lInterfaceFlags:=lInterfaceFlags or (1 shl ord(ifDispInterface));
            if (TargetInfo.endian=endian_big) then
              lInterfaceFlags:=Reverse_Byte(lInterfaceFlags);
              {
              ifDispatch, }
            ATypedConstBuilder.emit_ord_const(lInterfaceFlags,U8IntType);

            { write GUID }
            ATypedConstBuilder.emit_guid_const(ADef.IIDGUID^);

            { write hidden class reference - if it is nil, WriteRTTIReference writes nil }
            WriteRTTIReference(ATypedConstBuilder,ADef.HiddenClassDef,fullrtti);

            { write unit name }
            ATypedConstBuilder.emit_shortstring_const(CurrentModule.RealModuleName^);

            ATypedConstBuilder.begin_anonymous_record('',FDefaultPacking,FRequiredAlignment,
              targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

            { write iidstr }
            if ADef.ObjectType=odt_interfacecorba then
              begin
                { prepareguid always allocates an empty string }
                if not Assigned(ADef.IIDStr) then
                  InternalError(2016021901);
                ATypedConstBuilder.emit_shortstring_const(ADef.IIDStr^)
              end;

            { write published properties for this object }
            PropertiesWriteRTTIData(ATypedConstBuilder,lPropNameList,ADef.SymTable,false,[vis_published]);

            { write published methods for this interface }
            WriteMethods(ATypedConstBuilder,ADef.SymTable,false,[vis_published]);

            ATypedConstBuilder.end_anonymous_record;
            ATypedConstBuilder.end_anonymous_record;

            lPropNameList.free;
            lPropNameList := nil;
          end;

        begin
           case ADef.ObjectType of
             odt_class:
               ATypedConstBuilder.emit_ord_const(TkClass,U8IntType);
             odt_object:
               ATypedConstBuilder.emit_ord_const(TkObject,U8IntType);
             odt_dispinterface,
             odt_interfacecom:
               ATypedConstBuilder.emit_ord_const(TkInterface,U8IntType);
             odt_interfacecorba:
               ATypedConstBuilder.emit_ord_const(TkInterfaceCORBA,U8IntType);
             odt_helper:
               ATypedConstBuilder.emit_ord_const(TkHelper,U8IntType);
             else
               InternalError(200611034);
           end;

           { generate the name }
           ATypedConstBuilder.emit_shortstring_const(ADef.ObjRealName^);

           ATypedConstBuilder.begin_anonymous_record('',FDefaultPacking,FRequiredAlignment,
             targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

           WriteCommonRTTIData(ATypedConstBuilder,ADef,ARTTIType);

           case ARTTIType of
             initrtti :
               begin
                 if ADef.ObjectType in [odt_class,odt_object,odt_helper] then
                   ObjectDefRTTIFields(ADef)
                 else
                   ObjectDefRTTIInterfaceInit(ADef);
               end;
             fullrtti :
               begin
                 ATypedConstBuilder.begin_anonymous_record('',
                   FDefaultPacking,FRequiredAlignment,
                   targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
                 case ADef.ObjectType of
                   odt_helper,
                   odt_class:
                     ObjectDefRTTIClassFull(ADef);
                   odt_object:
                     ObjectDefRTTIFields(ADef);
                 else
                   ObjectDefRTTIInterfaceFull(ADef);
                 end;
                 ATypedConstBuilder.end_anonymous_record;
               end;
             else
               ;
           end;
           ATypedConstBuilder.end_anonymous_record;
        end;

      begin
        case ADef.typ of
          variantdef :
            VariantDefRTTI(TVariantDef(ADef));
          stringdef :
            StringDefRTTI(TStringDef(ADef));
          enumdef :
            EnumDefRTTI(TEnumDef(ADef));
          orddef :
            OrdDefRTTI(TOrdDef(ADef));
          floatdef :
            FloatDefRTTI(TFloatDef(ADef));
          setdef :
            SetDefRTTI(TSetDef(ADef));
          procvardef :
            ProcVarDefRTTI(TProcVarDef(ADef));
          arraydef :
            begin
              if ado_IsBitPacked in TArrayDef(ADef).ArrayOptions then
                UnknownRTTI(TStoredDef(ADef))
              else
                ArrayDefRTTI(TArrayDef(ADef));
            end;
          recorddef :
            begin
              if TRecordDef(ADef).Is_Packed then
                UnknownRTTI(TStoredDef(ADef))
              else
                RecordDefRTTI(TRecordDef(ADef));
            end;
          objectdef :
            ObjectDefRTTI(TObjectDef(ADef));
          classrefdef :
            ClassRefDefRTTI(TClassRefDef(ADef));
          pointerdef :
            PointerDefRTTI(TPointerDef(ADef));
          else
            UnknownRTTI(TStoredDef(ADef));
        end;
      end;

  procedure TRTTIWriter.WriteAttributeData(ATypedConstBuilder:TTAITypedConstBuilder;AAttributeList:TRTTIAttributeList);

    procedure WriteArgs(ATableTypedConstBuilder:TTAITypedConstBuilder;AAttribute:TRTTIAttribute);
      var
        lArgTypedConstBuilder : TTAITypedConstBuilder;
        lArgLabel : TAsmLabel;
        lArgDef : TDef;
        lIndex : SizeInt;
      begin
        if length(AAttribute.paras)=0 then
          begin
            ATableTypedConstBuilder.emit_tai(TAIConst.Create_16bit(0),U16IntType);
            ATableTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
          end
        else
          begin
            CurrentAsmData.getglobaldatalabel(lArgLabel);

            lArgTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_is_lab,tcalo_make_dead_strippable]);

            lArgTypedConstBuilder.begin_anonymous_record('',FDefaultPacking,min(FRequiredAlignment,SizeOf(PInt)),
              targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

            for lIndex:=0 to High(AAttribute.paras) do
              begin
                case AAttribute.paras[lIndex].NodeType of
                  niln,
                  ordconstn,
                  realconstn,
                  stringconstn,
                  pointerconstn,
                  guidconstn:
                    TConstNode(AAttribute.paras[lIndex]).Emit_Data(lArgTypedConstBuilder);
                  setconstn:
                    TSetConstNode(AAttribute.paras[lIndex]).Emit_Data(lArgTypedConstBuilder);
                  else
                    InternalError(2019070803);
                end;
              end;

            lArgDef:=lArgTypedConstBuilder.end_anonymous_record;

            CurrentAsmData.asmlists[al_rtti].ConcatList(
              lArgTypedConstBuilder.get_final_asmlist(lArgLabel,lArgDef,sec_rodata,lArgLabel.name,Const_Align(sizeof(PInt)))
            );

            lArgTypedConstBuilder.free;
            lArgTypedConstBuilder := nil;

            { write argument size and the reference to the argument entry }
            ATableTypedConstBuilder.emit_ord_const(lArgDef.Size,U16IntType);
            ATableTypedConstBuilder.emit_tai(TAIConst.Create_sym(lArgLabel),VoidPointerType);
          end;
      end;

    var
      lCount,lIndex: Word;
      lAttribute : TRTTIAttribute;
      lTableTypedConstBuilder : TTAITypedConstBuilder;
      lTableLabel : TAsmLabel;
      lTableDef : TDef;
    begin
      if Assigned(AAttributeList) then
        lCount:=AAttributeList.GetAttributeCount
      else
        lCount:=0;

      if lCount=0 then
        begin
          { write a Nil reference }
          ATypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
          exit;
        end;

      { first write the attribute list as a separate table }
      CurrentAsmData.getglobaldatalabel(lTableLabel);

      lTableTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_is_lab,tcalo_make_dead_strippable]);

      lTableTypedConstBuilder.begin_anonymous_record(
        InternalTypePrefixName[itp_rtti_attr_list]+ToStr(lCount),
        FDefaultPacking,min(FRequiredAlignment,SizeOf(PInt)),
        targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
      lTableTypedConstBuilder.emit_ord_const(lCount,U16IntType);
      for lIndex:=0 to lCount-1 do
        begin
          lTableTypedConstBuilder.begin_anonymous_record(InternalTypePrefixName[itp_rtti_attr_entry],FDefaultPacking,min(FRequiredAlignment,SizeOf(PInt)),
            targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
          lAttribute:=TRTTIAttribute(AAttributeList.RTTIAttributes[lIndex]);

          WriteRTTIReference(lTableTypedConstBuilder,TTypeSym(lAttribute.TypeSym).TypeDef,fullrtti);

          lTableTypedConstBuilder.emit_procdef_const(TProcDef(TCallNode(lAttribute.ConstructorCall).ProcDefinition));

          if not Assigned(lAttribute.ConstructorPD) then
            InternalError(2019071004);
          lTableTypedConstBuilder.emit_procdef_const(TProcDef(lAttribute.ConstructorPD));

          WriteArgs(lTableTypedConstBuilder,lAttribute);

          lTableTypedConstBuilder.end_anonymous_record;
        end;
      lTableDef:=lTableTypedConstBuilder.end_anonymous_record;

      CurrentAsmData.asmlists[al_rtti].ConcatList(
        lTableTypedConstBuilder.get_final_asmlist(lTableLabel,lTableDef,sec_rodata,lTableLabel.name,Const_Align(sizeof(PInt)))
      );

      lTableTypedConstBuilder.free;
      lTableTypedConstBuilder := nil;

      { write the reference to the attribute table }
      ATypedConstBuilder.emit_tai(TAIConst.Create_sym(lTableLabel),VoidPointerType);
    end;


    function EnumSymCompareName(AItem1, AItem2: Pointer): Integer;
      var
        lEnum1: TEnumSym absolute AItem1;
        lEnum2: TEnumSym absolute AItem2;
      begin
        if lEnum1=lEnum2 then
          Result:=0
        else if lEnum1.name>lEnum2.name then
          Result:=1
        else
          { there can't be equal names, identifiers are unique }
          Result:=-1;
      end;


    function EnumSymCompareValue(AItem1, AItem2: Pointer): Integer;
      var
        lEnum1: TEnumSym absolute AItem1;
        lEnum2: TEnumSym absolute AItem2;
      begin
        if lEnum1.Value>lEnum2.Value then
          Result:=1
        else if lEnum1.Value<lEnum2.Value then
          Result:=-1
        else
          Result:=0;
      end;


    procedure TRTTIWriter.WriteRTTIExtraSyms(ADef:TDef;ARTTIType:TRTTIType;AMainRTTI:TAsmSymbol);

        type Penumsym = ^TEnumSym;

        { Writes a helper table for accelerated conversion of ordinal enum values to strings.
          If you change something in this method, make sure to adapt the corresponding code
          in sstrings.inc. }
        procedure EnumDefRTTIOrd2StringIndex(ARTTIDef: TRecordDef; const ASyms: TFPList);

        var lRTTILabel:TAsmSymbol;
            lExpectedValue,lIndex,lOrdinalValue,lPreviousValue:LongInt;
            lMode:(lookup,search); {Modify with care, ordinal value of enum is written.}
            lHoleCount:Single;             {Must be real type because of integer overflow risk.}
            lTypedConstBuilder: TTAITypedConstBuilder;
            lSymCount: Integer;
            lTableDef: TDef;
        begin

          {Decide wether a lookup array is size efficient.}
          lMode:=lookup;
          lSymCount:=ASyms.count;
          if lSymCount>0 then
            begin
              lIndex:=1;
              lHoleCount:=0;
              lExpectedValue:=TEnumSym(ASyms[0]).Value; {Next expected enum value is min.}
              { set prev_value for the first iteration to a value that is
                different from the first one without risking overflow (it's used
                to detect whether two enum values are the same) }
              if lExpectedValue=0 then
                lPreviousValue:=1
              else
                lPreviousValue:=0;
              while lIndex<lSymCount do
                begin
                  { if two enum values are the same, we have to create a table }
                  if (lPreviousValue=lExpectedValue) then
                    begin
                      lMode:=search;
                      break;
                    end;
                  {Calculate size of hole between values. Avoid integer overflows.}
                  lHoleCount:=lHoleCount+(Single(TEnumSym(ASyms[lIndex]).Value)-Single(lExpectedValue))-1;
                  lPreviousValue:=lExpectedValue;
                  lExpectedValue:=TEnumSym(ASyms[lIndex]).Value;
                  inc(lIndex);
                end;
              if lHoleCount>lSymCount then
                lMode:=search; {Don't waste more than 50% space.}
            end;
          { write rtti data; make sure that the alignment matches the corresponding data structure
            in the code that uses it (if alignment is required). }
          lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_make_dead_strippable,tcalo_data_force_indirect]);
          { use TConstPtrUInt packrecords to ensure good alignment }
          lTypedConstBuilder.begin_anonymous_record('',FDefaultPacking,FRequiredAlignment,
            targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
          { now emit the data: first the mode }
          lTypedConstBuilder.emit_tai(TAIConst.create_32bit(LongInt(lMode)),U32IntType);
          { align }
          lTypedConstBuilder.begin_anonymous_record('',FDefaultPacking,min(FRequiredAlignment,sizeof(PInt)),
            targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
          if lMode=lookup then
            begin
              lOrdinalValue:=TEnumSym(ASyms[0]).Value;  {Start with min value.}
              for lIndex:=0 to lSymCount-1 do
                begin
                  while lOrdinalValue<TEnumSym(ASyms[lIndex]).Value do
                    begin
                      lTypedConstBuilder.emit_tai(TAIConst.create_nil_dataptr,PtrUIntType);
                      inc(lOrdinalValue);
                    end;
                  inc(lOrdinalValue);
                  lTypedConstBuilder.queue_init(VoidPointerType);
                  lTypedConstBuilder.queue_subscriptn_multiple_by_name(ARTTIDef,
                    ['size_start_rec',
                      'typ_union_rec',
                      'min_max_rec',
                      'basetype_array_rec',
                      TSym(ASyms[lIndex]).Name]
                  );
                  lTypedConstBuilder.queue_emit_asmsym(AMainRTTI,ARTTIDef);
                end;
            end
          else
            begin
              lTypedConstBuilder.emit_ord_const(lSymCount,U32IntType);
              lTypedConstBuilder.begin_anonymous_record('',FDefaultPacking,min(FRequiredAlignment,sizeof(PInt)),
                targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
              for lIndex:=0 to lSymCount-1 do
                begin
                  lTypedConstBuilder.emit_ord_const(TEnumSym(ASyms[lIndex]).Value,S32IntType);
                  lTypedConstBuilder.queue_init(VoidPointerType);
                  lTypedConstBuilder.queue_subscriptn_multiple_by_name(ARTTIDef,
                    ['size_start_rec',
                      'typ_union_rec',
                      'min_max_rec',
                      'basetype_array_rec',
                      TSym(ASyms[lIndex]).Name]
                  );
                  lTypedConstBuilder.queue_emit_asmsym(AMainRTTI,ARTTIDef);
                end;
              lTypedConstBuilder.end_anonymous_record;
            end;
            lTypedConstBuilder.end_anonymous_record;

            lTableDef:=lTypedConstBuilder.end_anonymous_record;
            lRTTILabel:=CurrentAsmData.DefineAsmSymbol(TStoredDef(ADef).RTTIMangledName(ARTTIType)+'_o2s',AB_GLOBAL,AT_DATA_NOINDIRECT,lTableDef);
            CurrentAsmData.asmlists[al_rtti].ConcatList(lTypedConstBuilder.get_final_asmlist(
              lRTTILabel,lTableDef,sec_rodata,
              lRTTILabel.name,sizeof(PInt)));
            lTypedConstBuilder.free;
            lTypedConstBuilder := nil;

            CurrentModule.Add_Public_AsmSym(lRTTILabel);
        end;


        { Writes a helper table for accelerated conversion of string to ordinal enum values.
          If you change something in this method, make sure to adapt the corresponding code
          in sstrings.inc. }
        procedure EnumDefRTTIString2OrdIndex(ARTTIDef: TRecordDef; const ASyms: TFPList);

        var
          lTypedConstBuilder: TTAITypedConstBuilder;
          lRTTILabel: TAsmSymbol;
          lIndex:LongInt;
          lTableDef: TDef;
        begin
          { write rtti data }
          lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_make_dead_strippable,tcalo_data_force_indirect]);
          { begin of Tstring_to_ord }
          lTypedConstBuilder.begin_anonymous_record('',FDefaultPacking,min(FRequiredAlignment,sizeof(PInt)),
            targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
          lTypedConstBuilder.emit_ord_const(ASyms.count,S32IntType);
          { begin of "data" array in Tstring_to_ord }
          lTypedConstBuilder.begin_anonymous_record('',FDefaultPacking,min(FRequiredAlignment,sizeof(PInt)),
            targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
          for lIndex:=0 to ASyms.count-1 do
            begin
              lTypedConstBuilder.emit_ord_const(TEnumSym(ASyms[lIndex]).Value,S32IntType);
              { alignment of pointer value handled by enclosing record already }
              lTypedConstBuilder.queue_init(VoidPointerType);
              lTypedConstBuilder.queue_subscriptn_multiple_by_name(ARTTIDef,
                ['size_start_rec',
                  'typ_union_rec',
                  'min_max_rec',
                  'basetype_array_rec',
                  TSym(ASyms[lIndex]).Name]
              );
              lTypedConstBuilder.queue_emit_asmsym(AMainRTTI,ARTTIDef);
            end;
          lTypedConstBuilder.end_anonymous_record;
          lTableDef:=lTypedConstBuilder.end_anonymous_record;
          lRTTILabel:=CurrentAsmData.DefineAsmSymbol(TStoredDef(ADef).RTTIMangledName(ARTTIType)+'_s2o',AB_GLOBAL,AT_DATA_NOINDIRECT,lTableDef);
          CurrentAsmData.asmlists[al_rtti].ConcatList(lTypedConstBuilder.get_final_asmlist(
            lRTTILabel,lTableDef,sec_rodata,
            lRTTILabel.name,sizeof(PInt)));
          lTypedConstBuilder.free;
          lTypedConstBuilder := nil;

          CurrentModule.Add_Public_AsmSym(lRTTILabel);
        end;

        procedure EnumDefRTTIExtraSyms(ADef:TEnumDef);
        var
          lEnumSym:TEnumSym;
          lSyms:TFPList;
          lIndex:LongInt;
          lRTTITypeSym: TTypeSym;
          lRTTIDef: TRecordDef;
          lString:TIDString;
        begin
          { collect enumsyms belonging to this enum type (could be a subsection
            in case of a subrange type) }
          lSyms:=TFPList.Create;
          for lIndex := 0 to ADef.SymTable.SymList.Count - 1 do
            begin
              lEnumSym:=TEnumSym(ADef.SymTable.SymList[lIndex]);
              if lEnumSym.Value<ADef.MinVal then
                continue
              else
              if lEnumSym.Value>ADef.MaxVal then
                break;
              lSyms.add(lEnumSym);
            end;
          { sort the syms by enum name }
          lSyms.sort(@EnumSymCompareName);
          lString:=InternalTypePrefixName[itp_rttidef]+ADef.RTTIMangledName(fullrtti);
          lRTTITypeSym:=Try_Search_Current_Module_Type(lString);
          if not Assigned(lRTTITypeSym) or
             (TTypeSym(lRTTITypeSym).TypeDef.typ<>recorddef) then
            InternalError(2015071402);
          lRTTIDef:=TRecordDef(TTypeSym(lRTTITypeSym).TypeDef);
          EnumDefRTTIString2OrdIndex(lRTTIDef,lSyms);
          { sort the syms by enum value }
          lSyms.sort(@EnumSymCompareValue);
          EnumDefRTTIOrd2StringIndex(lRTTIDef,lSyms);
          lSyms.free;
          lSyms := nil;
        end;


    begin
      case ADef.typ of
        enumdef:
          if ARTTIType=fullrtti then
            begin
              EnumDefRTTIExtraSyms(TEnumDef(ADef));
            end;
        else
          ;
      end;
    end;

    procedure TRTTIWriter.WriteChildRTTIData(ADef:TDef;ARTTIType:TRTTIType);
      begin
        case ADef.typ of
          enumdef :
            if Assigned(TEnumDef(ADef).BaseDef) then
              Write_RTTI(TEnumDef(ADef).BaseDef,ARTTIType);
          setdef :
            Write_RTTI(TSetDef(ADef).ElementDef,ARTTIType);
          arraydef :
            begin
              Write_RTTI(TArrayDef(ADef).RangeDef,ARTTIType);
              Write_RTTI(TArrayDef(ADef).ElementDef,ARTTIType);
            end;
          recorddef :
            begin
              { guarantee initrtti for any record for RTTI purposes
                also for fpc_initialize, fpc_finalize }
              if (ARTTIType=fullrtti) then
                begin
                  include(ADef.DefStates,ds_init_table_used);
                  Write_RTTI(ADef, initrtti);
                end;
              FieldsWriteRTTI(TRecordDef(ADef).SymTable,ARTTIType);
            end;
          objectdef :
            begin
              if Assigned(TObjectDef(ADef).ChildOf) then
                Write_RTTI(TObjectDef(ADef).ChildOf,ARTTIType);
              if (ARTTIType=initrtti) or (TObjectDef(ADef).ObjectType=odt_object) then
                FieldsWriteRTTI(TObjectDef(ADef).SymTable,ARTTIType)
              else
                PublishedWriteRTTI(TObjectDef(ADef),ARTTIType);

              if (ARTTIType=fullrtti) then
                begin
                  { guarantee initrtti for any object for RTTI purposes
                    also for fpc_initialize, fpc_finalize }
                  if (TObjectDef(ADef).ObjectType=odt_object) then
                    begin
                      include(ADef.DefStates,ds_init_table_used);
                      Write_RTTI(ADef,initrtti);
                    end;
                  if (Is_Interface(ADef) or Is_DispInterface(ADef))
                      and (oo_can_have_published in TObjectDef(ADef).ObjectOptions) then
                    MethodsWriteRTTI(TObjectDef(ADef).SymTable,ARTTIType,[vis_published],true);
                end;
            end;
          classrefdef,
          pointerdef:
            if not Is_ObjC_Class_Or_Protocol(TAbstractPointerDef(ADef).PointedDef) then
              Write_RTTI(TAbstractPointerDef(ADef).PointedDef,ARTTIType);
          procvardef:
            ParamsWriteRTTI(TAbstractProcDef(ADef),ARTTIType,false);
          else
            ;
        end;
      end;

    procedure TRTTIWriter.WriteRTTIReference(ATypedConstBuilder: TTAITypedConstBuilder; ADef: TDef; ARTTIType: TRTTIType);
      begin
        { we don't care about the real type here, because
           a) we don't index into these elements
           b) we may not have the rtti type available at the point that we
              are emitting this data, because of forward definitions etc
           c) if the rtti is emitted in another unit, we won't have the type
              available at all
          For the cases where the type is emitted in the current unit and hence
          the underlying system will detect and complain about symbol def
          mismatches, type conversions will have to be inserted afterwards (like
          in llvm/llvmtype)
        }
        if not Assigned(ADef) or Is_Void(ADef) or ((ARTTIType<>initrtti) and Is_ObjC_Class_Or_Protocol(ADef)) then
          ATypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType)
        else
          ATypedConstBuilder.emit_tai(TAIConst.Create_sym(Get_RTTI_Label(ADef,ARTTIType,true)),VoidPointerType);
      end;


    function TRTTIWriter.Ref_RTTI(ADef:TDef;ARTTIType:TRTTIType;AIndirect:Boolean;ASuffix:TSymStr):TAsmSymbol;
      var
        lString : TSymStr;
      begin
        lString:=ADef.RTTIMangledName(ARTTIType)+ASuffix;
        Result:=CurrentAsmData.RefAsmSymbol(lString,AT_DATA,AIndirect);
        if ADef.owner.ModuleID<>CurrentModule.ModuleID then
          CurrentModule.Add_Extern_AsmSym(lString,AB_EXTERNAL,AT_DATA);
      end;

    procedure TRTTIWriter.Write_RTTI(ADef:TDef;ARTTIType:TRTTIType);

      var
        lTypedConstBuilder: TTAITypedConstBuilder;
        lOptions : TTCAsmListOptions;
        lRTTILabel: TAsmSymbol;
        lRTTIDef: TDef;
        lString: TIDString;
      begin
        { Objective-C has its own RTTI system }
        if Is_ObjC_Class_Or_Protocol(ADef) then
          exit;

        { only write rtti of definitions from the current module }
        if not FindUnitSymTable(ADef.owner).IsCurrentUnit then
          exit;
        { check if separate initrtti is actually needed }
        if (ARTTIType=initrtti) and (not ADef.NeedsSeparateInitRTTI) then
          ARTTIType:=fullrtti;
        { prevent recursion }
        if cRTTIDefStates[ARTTIType] in ADef.DefStates then
          exit;
        include(ADef.DefStates,cRTTIDefStates[ARTTIType]);

        { write first all dependencies }
        WriteChildRTTIData(ADef,ARTTIType);
        { write rtti data }
        lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_make_dead_strippable,tcalo_data_force_indirect]);
        lString:=InternalTypePrefixName[itp_rttidef]+TStoredDef(ADef).RTTIMangledName(ARTTIType);

        MaybeAddComment(lTypedConstBuilder,'RTTI: begin Type '+ADef.GetTypeName+' ('+cRTTITypeNames[ARTTIType]+')');
        lTypedConstBuilder.begin_anonymous_record(
          lString,
          FDefaultPacking,FRequiredAlignment,
          targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin
        );
        WriteRTTIData(lTypedConstBuilder,ADef,ARTTIType);
        lRTTIDef:=lTypedConstBuilder.end_anonymous_record;
        MaybeAddComment(lTypedConstBuilder,'RTTI: end Type '+ADef.GetTypeName+' ('+cRTTITypeNames[ARTTIType]+')');
        lRTTILabel:=CurrentAsmData.DefineAsmSymbol(TStoredDef(ADef).RTTIMangledName(ARTTIType),AB_GLOBAL,AT_DATA_NOINDIRECT,lRTTIDef);
        CurrentAsmData.AsmLists[al_rtti].ConcatList(
          lTypedConstBuilder.get_final_asmlist(lRTTILabel,lRTTIDef,sec_rodata,lRTTILabel.name,min(TargetInfo.Alignment.MaxCRecordAlign,SizeOf(QWord))));
        lTypedConstBuilder.free;
        lTypedConstBuilder := nil;

        CurrentModule.Add_Public_AsmSym(lRTTILabel);

        { write additional data }
        WriteRTTIExtraSyms(ADef,ARTTIType,lRTTILabel);
      end;

    procedure TRTTIWriter.MaybeAddComment(ATypedConstBuilder:TTAITypedConstBuilder;const AComment : String);

      begin
        if FAddComments then
          ATypedConstBuilder.emit_comment(AComment);
      end;

    constructor TRTTIWriter.Create;
      begin
        FAddComments:=cs_asm_rtti_source in CurrentSettings.GlobalSwitches;
        if tf_requires_proper_alignment in TargetInfo.Flags then
          begin
            FRequiredAlignment:=min(sizeof(QWord),TargetInfo.Alignment.MaxCRecordAlign);
            FDefaultPacking:=CAlignment;
          end
        else
          begin
            FRequiredAlignment:=1;
            FDefaultPacking:=1;
          end;
      end;


end.

