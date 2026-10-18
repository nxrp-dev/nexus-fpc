{
    Copyright (c) 1998-2007 by Florian Klaempfl

    Type checking and register allocation for inline nodes

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
unit ninl;

{$i fpcdefs.inc}

interface

    uses
       TPCompilerReal,
       node,htypechk,symtype,compinnr;

    type
       TInlineNodeFlag = (
         inf_inlineconst
       );

       TInlineNodeFlags = set of TInlineNodeFlag;

       TInlineNode = class(TUnaryNode)
          InlineNodeFlags : TInlineNodeFlags;
          InlineNumber : TInlineNumber;
          constructor Create(AInlineNumber : TInlineNumber;AIsConst:Boolean;ALeft : TNode);virtual;
          constructor CreateIntern(AInlineNumber : TInlineNumber;AIsConst:Boolean;ALeft : TNode);virtual;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          function DoGetCopy : TNode;override;
          procedure PrintNodeInfo(var AText : Text);override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function Pass_TypeCheck_CPU:TNode;virtual;
          function Simplify(AForInline : Boolean): TNode;override;
          function DoCompare(ANode: TNode): Boolean; override;
          procedure Mark_Write;override;

          { returns a node tree where the inc/dec are replaced by add/sub }
          function GetAddSub_For_IncDec : TNode;

          { pack and unpack are changed into for-loops by the compiler }
          function First_Pack_Unpack: TNode; virtual;

          property Parameters : TNode read Left write Left;

          function May_Have_SideEffect_NoRecurse: Boolean;

          function May_Ignore_Result:Boolean;
         protected
          { All the following routines currently
            call compilerprocs, unless they are
            overridden in which case, the code
            generator handles them.
          }
          function First_Pi: TNode ; virtual;
          function First_ArcTan_Real: TNode; virtual;
          function First_Abs_Real: TNode; virtual;
          function First_Sqr_Real: TNode; virtual;
          function First_Sqrt_Real: TNode; virtual;
          function First_Ln_Real: TNode; virtual;
          function First_Cos_Real: TNode; virtual;
          function First_Sin_Real: TNode; virtual;
          function First_Exp_Real: TNode; virtual;
          function First_Frac_Real: TNode; virtual;
          function First_Round_Real: TNode; virtual;
          function First_Trunc_Real: TNode; virtual;
          function First_Int_Real: TNode; virtual;
          function First_Abs_Long: TNode; virtual;
          function First_IncDec: TNode; virtual;
          function First_IncludeExclude: TNode; virtual;
          function First_Get_Frame: TNode; virtual;
          function First_SetLength: TNode; virtual;
          function First_Copy: TNode; virtual;

          { Internal allocation node; the parser does not emit it. }
          function First_New: TNode; virtual;
          function First_Length: TNode; virtual;
          function First_High: TNode; virtual;
          function First_Box: TNode; virtual; abstract;
          function First_Unbox: TNode; virtual; abstract;
          function First_Assigned: TNode; virtual;
          function First_Assert: TNode; virtual;
          function First_PopCnt: TNode; virtual;
          function First_BitScan: TNode; virtual;
          { override these for Seg() support }
          function TypeCheck_Seg: TNode; virtual;
          function First_Seg: TNode; virtual;
          function First_SAR: TNode; virtual;
          function First_FMA : TNode; virtual;
          function First_MinMax: TNode; virtual;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
          function First_ShiftRot_Assign_64BitInt: TNode; virtual;
{$endif not cpu64bitalu and not cpuhighleveltarget}
          function First_AndOrXorShiftRot_Assign: TNode; virtual;
          function First_NegNot_Assign: TNode; virtual;
          function First_Atomic:TNode;virtual;
          function First_CPU : TNode; virtual;

          procedure CheckParameters(ACount : Integer);
        private
          function HandleStr: TNode;
          function HandleResetRewriteTyped: TNode;
          function HandleTextReadWrite(AFilePara,AParams:TTertiaryNode;var ANewStatement:TNode):Boolean;
          function HandleTypedReadWrite(AFilePara,AParams:TTertiaryNode;var ANewStatement:TNode):Boolean;
          function HandleReadWrite: TNode;
          function HandleVal: TNode;
          function HandleDefault: TNode;
          function HandleSetLength: TNode;
          function HandleCopy: TNode;
          function HandleBox: TNode;
          function HandleUnbox: TNode;
          function HandleInsert:TNode;
          function HandleDelete:TNode;
          function HandleConcat:TNode;
       end;
       TInlineNodeClass = class of TInlineNode;

    var
       CInlineNode : TInlineNodeClass = TInlineNode;

   function GenInlineNode(AInlineNumber : TInlineNumber;AIsConst:Boolean;ALeft : TNode) : TInlineNode;

implementation

    uses
      Verbose,Globals,Systems,ConstExp,
      GlobType,CUtils,CClasses,FModule,
      symconst,symdef,SymSym,symcpu,SymTable,paramgr,defcmp,defutil,SymBase,
      CPUInfo,cpubase,
      Pass_1,PPU,
      ncal,ncon,ncnv,nadd,nld,nbas,nflw,nmem,nmat,nutils,ngenutil,
      nobjc,objcdef,
      cgbase,ProcInfo;

   function GenInlineNode(AInlineNumber : TInlineNumber;AIsConst:Boolean;ALeft : TNode) : TInlineNode;

     begin
        GenInlineNode:=CInlineNode.Create(AInlineNumber,AIsConst,ALeft);
     end;

{*****************************************************************************
                           TINLINENODE
*****************************************************************************}

    constructor TInlineNode.Create(AInlineNumber : TInlineNumber;AIsConst:Boolean;ALeft : TNode);
      begin
         inherited Create(inlinen,ALeft);
         if AIsConst then
           InlineNodeFlags:=[inf_inlineconst]
         else
           InlineNodeFlags:=[];
         InlineNumber:=AInlineNumber;
      end;


    constructor TInlineNode.CreateIntern(AInlineNumber : TInlineNumber; AIsConst : Boolean;
     ALeft : TNode);
      begin
         Create(AInlineNumber,AIsConst,ALeft);
         InlineNodeFlags:=[];
         include(Flags,nf_internal);
      end;


    constructor TInlineNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        APPUFile.GetSet(TPPUSet1(InlineNodeFlags));
        InlineNumber:=TInlineNumber(APPUFile.GetLongInt);
      end;


    procedure TInlineNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutSet(TPPUSet1(InlineNodeFlags));
        APPUFile.PutLongInt(LongInt(InlineNumber));
      end;


    function TInlineNode.DoGetCopy : TNode;
      var
         lNode : TInlineNode;
      begin
         lNode:=TInlineNode(inherited DoGetCopy);
         lNode.InlineNodeFlags:=InlineNodeFlags;
         lNode.InlineNumber:=InlineNumber;
         Result:=lNode;
      end;


    procedure TInlineNode.PrintNodeInfo(var AText : Text);
      begin
        inherited;
        write(AText,', inlinenumber = ',InlineNumber);
      end;


    function GetStrIntFunc(ADef: TDef): String;
    var
      lOrdType: TOrdType;
    begin
      lOrdType := TOrdDef(ADef).OrdType;
      if not (lOrdType in [scurrency,s64bit,u64bit,s32bit,u32bit,s16bit,u16bit,s8bit,u8bit]) then
        InternalError(2013032603);

      if Is_OversizedOrd(ADef) then
        begin
          case lOrdType of
            scurrency,
            s64bit: exit('int64');
            u64bit: exit('qword');
            s32bit: exit('longint');
            u32bit: exit('longword');
            s16bit: exit('smallint');
            u16bit: exit('word');
            else
              InternalError(2013032604);
          end;
        end
      else
        begin
          if Is_NativeUInt(ADef) then
            exit('uint')
          else
            exit('sint');
        end;
      InternalError(2013032605);
    end;


    function TInlineNode.HandleStr : TNode;
      var
        lLengthPara,
        lFracPara,
        lNewParas,
        lTempPara,
        lDest,
        lSource  : TCallParaNode;
        lProcName: String;
        lIsReal,lIsEnum : Boolean;
        lRealType : AInt;
        lIntrinsicCode: TInlineNumber;

      begin
        Result := CErrorNode.Create;

        { get destination string }
        lDest := TCallParaNode(Left);

        { get source para (number) }
        lSource := lDest;
        while Assigned(lSource.Right) do
          lSource := TCallParaNode(lSource.Right);

        { destination parameter must be a normal (not a colon) parameter, this
          check is needed because str(v:len) also has 2 parameters }
        if (lSource=lDest) or
           (cpf_is_colon_para in TCallParaNode(lDest).CallParaFlags) then
          begin
            CGMessage1(parser_e_wrong_parameter_size,'Str');
            exit;
          end;

        { in case we are in a generic definition, we cannot
          do all checks, the parameters might be type parameters,

          bailout as well in case of an error before }
        if (df_generic in CurrentProcInfo.procdef.DefOptions) or
         (lDest.ResultDef.typ=errordef) or
         (lSource.ResultDef.typ=errordef) then
          begin
            Result.Free;
            Result:=nil;
            ResultDef:=VoidType;
            exit;
          end;

        lIsReal:=(lSource.ResultDef.typ = floatdef) or Is_Currency(lSource.ResultDef);
        lIsEnum:=lSource.Left.ResultDef.typ=enumdef;

        if ((lDest.Left.ResultDef.typ<>stringdef) and
            not(Is_CharArray(lDest.Left.ResultDef))) or
           not(lIsReal or lIsEnum or
               (lSource.Left.ResultDef.typ=orddef)) then
          begin
            CGMessagePos1(lSource.FileInfo,
              type_e_integer_expr_expected,lSource.ResultDef.TypeName);
            exit;
          end;

        { get len/frac parameters }
        lLengthPara := nil;
        lFracPara := nil;
        if (cpf_is_colon_para in TCallParaNode(lDest.Right).CallParaFlags) then
          begin
            lLengthPara := TCallParaNode(lDest.Right);

            { we can let the callnode do the type checking of these parameters too, }
            { but then the error messages aren't as nice                            }
            if not Is_Integer(lLengthPara.ResultDef) then
              begin
                CGMessagePos1(lLengthPara.FileInfo,
                  type_e_integer_expr_expected,lLengthPara.ResultDef.TypeName);
                exit;
              end;
            if (cpf_is_colon_para in TCallParaNode(lLengthPara.Right).CallParaFlags) then
              begin
                { parameters are in reverse order! }
                lFracPara := lLengthPara;
                lLengthPara := TCallParaNode(lLengthPara.Right);
                if not lIsReal then
                  begin
                    CGMessagePos(lLengthPara.FileInfo,parser_e_illegal_colon_qualifier);
                    exit
                  end;
                if not Is_Integer(lLengthPara.ResultDef) then
                  begin
                    CGMessagePos1(lLengthPara.FileInfo,
                      type_e_integer_expr_expected,lLengthPara.ResultDef.TypeName);
                    exit;
                  end;
              end;
          end;

        { generate the parameter list for the compilerproc }
        lNewParas := lDest;

        { if we have a float parameter, insert the realtype, len and fracpara parameters }
        if lIsReal then
          begin
            { insert realtype parameter }
            if not Is_Currency(lSource.ResultDef) then
              begin
                lRealType:=ord(TFloatDef(lSource.Left.ResultDef).FloatType);
                lNewParas.Right := CCallParaNode.Create(COrdConstNode.Create(
                  lRealType,S32IntType,true),lNewParas.Right);
                lTempPara:=TCallParaNode(lNewParas.Right);
              end
            else
              lTempPara:=lNewParas;
            { if necessary, insert a fraction parameter }
            if not Assigned(lFracPara) then
              begin
                lTempPara.Right := CCallParaNode.Create(
                  COrdConstNode.Create(Int64(-1),S32IntType,false),
                   lTempPara.Right);
                lFracPara := TCallParaNode(lTempPara.Right);
              end;
            { if necessary, insert a length para }
            if not Assigned(lLengthPara) then
              lFracPara.Right := CCallParaNode.Create(
                COrdConstNode.Create(Int64(-32767),S32IntType,false),
                   lFracPara.Right);
          end
        else if lIsEnum then
          begin
            {Insert a reference to the ord2string index.}
            lNewParas.Right:=CCallParaNode.Create(
              CAddrNode.Create_Internal(
                CRTTINode.Create(TEnumDef(lSource.Left.ResultDef),fullrtti,rdt_normal)
              ),
              lNewParas.Right);
            {Insert a reference to the typinfo.}
            lNewParas.Right:=CCallParaNode.Create(
              CAddrNode.Create_Internal(
                CRTTINode.Create(TEnumDef(lSource.Left.ResultDef),fullrtti,rdt_ord2str)
              ),
              lNewParas.Right);
            {Insert a type conversion from the enumeration to longint.}
            lSource.Left:=CTypeConvNode.Create_Internal(lSource.Left,S32IntType);
            TypeCheckPass(lSource.Left);

            { if necessary, insert a length para }
            if not Assigned(lLengthPara) then
              TCallParaNode(TCallParaNode(lNewParas.Right).Right).Right:=
                CCallParaNode.Create(
                  COrdConstNode.Create(Int64(-1),S32IntType,false),
                  TCallParaNode(TCallParaNode(lNewParas.Right).Right).Right
                );
          end
        else
          { for a normal parameter, insert a only length parameter if one is missing }
          if not Assigned(lLengthPara) then
            lNewParas.Right := CCallParaNode.Create(COrdConstNode.Create(Int64(-1),S32IntType,false),
              lNewParas.Right);

        { remove the parameters from the original node so they won't get disposed, }
        { since they're reused                                                     }
        Left := nil;

        lIntrinsicCode := Default(TInlineNumber);

        { create procedure name }
        if Is_CharArray(lDest.ResultDef) then
          lProcName:='fpc_chararray_'
        else
          lProcName := 'fpc_' + TStringDef(lDest.ResultDef).StringTypName+'_';
        if lIsReal then
          if Is_Currency(lSource.ResultDef) then
            lProcName := lProcName + 'currency'
          else
            lProcName := lProcName + 'float'
        else if lIsEnum then
          lProcName:=lProcName+'enum'
        else
          case TOrdDef(lSource.ResultDef).OrdType of
            pasbool1,pasbool8,pasbool16,pasbool32,pasbool64,
            bool8bit,bool16bit,bool32bit,bool64bit:
              lProcName := lProcName + 'bool';

            scurrency,s64bit,u64bit,s32bit,u32bit,s16bit,u16bit,s8bit,u8bit:
              begin
                lIntrinsicCode := in_str_x_string;
                lProcName := lProcName + GetStrIntFunc(lSource.ResultDef);
              end;

            else
              begin
                CGMessagePos1(lSource.FileInfo,
                  type_e_integer_expr_expected,TOrdDef(lSource.ResultDef).TypeName);
                exit;
              end;
          end;

        { for ansistrings insert the encoding argument }
        if Is_AnsiString(lDest.ResultDef) then
          lNewParas:=CCallParaNode.Create(COrdConstNode.Create(
            GetParaEncoding(lDest.ResultDef),U16IntType,true),lNewParas);

        { free the errornode we generated in the beginning }
        Result.free;
        { create the call node, }
        Result := CCallNode.CreateFromIntrinsic(lIntrinsicCode,lProcName,lNewParas);
      end;


    function TInlineNode.HandleDefault: TNode;

      function GetDefaultVarSym(ADef:TDef):TNode;
        var
          lHashedID : THashedIDString;
          lFoundSym : TSym;
          lFoundSymTable : TSymTable;
          lDefaultName : TIDString;
          lVarSpez : TVarSpez;
        begin
          if not Assigned(ADef) or
              not (ADef.typ in [arraydef,recorddef,variantdef,objectdef,procvardef]) or
              ((ADef.typ=objectdef) and not Is_Object(ADef)) then
            InternalError(201202101);

          { extra '$' prefix because on darwin the result of makemangledname
            is prefixed by '_' and hence adding a '$' at the start of the
            prefix passed to makemangledname doesn't help (the whole point of
            the copy() operation below is to ensure that the id does not start
            with a '$', because that is interpreted specially by the symtable
            routines -- that's also why we prefix with '$_', so it will still
            work if make_mangledname() would somehow return a name that already
            starts with '$' }
          lDefaultName:='$_'+Make_MangledName('zero',ADef.owner,ADef.TypeSym.Name);
          { can't hardcode the position of the '$', e.g. on darwin an underscore
            is added }
          lHashedID.id:=copy(lDefaultName,2,255);
          { in case of a previous error, current_procinfo might not be set
            so avoid a crash in this case }
          if Assigned(CurrentProcInfo) then
            begin
              { the default sym is always part of the current procedure/function }
              lFoundSymTable:=CurrentModule.LocalSymTable;
              lFoundSym:=TSym(lFoundSymTable.findwithhash(lHashedID));
              if not Assigned(lFoundSym) then
                begin
                  lVarSpez:=vs_const;
                  { if we have an initialize or finalize management operator then
                    we may not declare this as const as the unit init-/finalization
                    needs to be able to modify it }
                  if (ADef.typ=recorddef) and (mop_initialize in TRecordSymTable(TRecordDef(ADef).SymTable).ManagementOperators) then
                    lVarSpez:=vs_var;
                  { no valid default variable found, so create it }
                  lFoundSym:=CStaticVarSym.Create(lDefaultName,lVarSpez,ADef,[]);
                  { mark the staticvarsym as typedconst }
                  if lVarSpez=vs_const then
                    include(TAbstractVarSym(lFoundSym).VarOptions,vo_is_typed_const);
                  include(TAbstractVarSym(lFoundSym).VarOptions,vo_is_default_var);
                  { There is no reliable way to be sure that this symbol will not be used
                    later on inside some inlined code, so mark it as global }
                  include(TAbstractVarSym(lFoundSym).VarOptions,vo_is_public);
                  { The variable has a value assigned }
                  TAbstractVarSym(lFoundSym).VarState:=vs_initialised;

                  lFoundSymTable.InsertSym(lFoundSym);
                  CNodeUtils.InsertBSSData(TStaticVarSym(lFoundSym));
                end;
              Result:=CLoadNode.Create(lFoundSym,lFoundSymTable);
            end
          else
            Result:=CErrorNode.Create;
        end;

      var
        lDef : TDef;
      begin
        if not Assigned(Left) or (Left.NodeType<>typen) then
          InternalError(2012032102);

        lDef:=TTypeNode(Left).TypeDef;
        if Assigned(CurrentProcInfo) and
           (df_generic in CurrentProcInfo.procdef.DefOptions) then
          begin
            { don't allow as a default parameter value, because it may not be valid
              when specialising }
            if Block_Type<>bt_const then
              Result:=CPointerConstNode.Create(0,lDef)
            else
              Result:=CErrorNode.Create;
            exit;
          end;

        Result:=nil;
        case lDef.typ of
          enumdef,
          orddef:
            { don't do a rangecheck as Default will also return 0
              for the following types (Delphi compatible):
              TRange1 = -10..-5;
              TRange2 = 5..10;
              TEnum = (a:=5;b:=10); }
            Result:=COrdConstNode.Create(0,lDef,false);
          classrefdef,
          pointerdef:
            Result:=CPointerConstNode.Create(0,lDef);
          procvardef:
            if TProcVarDef(lDef).Size<>sizeof(PInt) then
              Result:=GetDefaultVarSym(lDef)
            else
              Result:=CPointerConstNode.Create(0,lDef);
          stringdef:
            Result:=CStringConstNode.CreateStr('');
          floatdef:
            Result:=CRealConstNode.Create(0,lDef);
          objectdef:
            begin
              if Is_Implicit_Pointer_Object_Type(lDef) then
                Result:=CPointerConstNode.Create(0,lDef)
              else
                if Is_Object(lDef) then
                  begin
                    { Delphi does not recursively check whether
                      an object contains unsupported types }
                    if not (m_delphi in CurrentSettings.ModeSwitches) and
                        not is_valid_for_default(lDef) then
                      Message(type_e_type_not_allowed_for_default);
                    Result:=GetDefaultVarSym(lDef);
                  end
                else
                  Message(type_e_type_not_allowed_for_default);
            end;
          variantdef,
          recorddef:
            begin
              { Delphi does not recursively check whether a record
                contains unsupported types }
              if (lDef.typ=recorddef) and not (m_delphi in CurrentSettings.ModeSwitches) and
                  not is_valid_for_default(lDef) then
                Message(type_e_type_not_allowed_for_default);
              Result:=GetDefaultVarSym(lDef);
            end;
          setdef:
            begin
              Result:=CSetConstNode.Create(nil,lDef);
              New(TSetConstNode(Result).ValueSet);
              TSetConstNode(Result).ValueSet^:=[];
            end;
          arraydef:
            begin
              { can other array types be parsed by single_type? }
              if ado_isdynamicarray in TArrayDef(lDef).ArrayOptions then
                Result:=CPointerConstNode.Create(0,lDef)
              else
                begin
                  Result:=GetDefaultVarSym(lDef);
                end;
            end;
          undefineddef:
            begin
              if sp_generic_dummy in lDef.TypeSym.SymOptions then
                begin
                  { this matches the error messages that are printed
                    in case of non-Delphi modes }
                  Message(parser_e_no_generics_as_types);
                  Message(type_e_type_id_expected);
                end
              else
                Result:=CPointerConstNode.Create(0,lDef);
            end;
          else
            Message(type_e_type_not_allowed_for_default);
        end;
        if not Assigned(Result) then
          Result:=CErrorNode.Create;
      end;


    function TInlineNode.HandleResetRewriteTyped: TNode;
      begin
        { since this is a "in_xxxx_typedfile" node, we can be sure we have  }
        { a typed file as argument and we don't have to check it again (JM) }

        { add the recsize parameter }

        { iso mode extension with name? }
        if InlineNumber in [in_reset_typedfile_name,in_rewrite_typedfile_name] then
          begin
            Left := CCallParaNode.Create(COrdConstNode.Create(
              TFileDef(TCallParaNode(TCallParaNode(Left).NextPara).ParaValue.ResultDef).TypedFileDef.Size,S32IntType,true),Left);
          end
        else
          begin
            { note: for some reason, the parameter of intern procedures with only one }
            {   parameter is gets lifted out of its original tcallparanode (see round }
            {   line 1306 of ncal.pas), so recreate a tcallparanode here (JM)         }
            Left := CCallParaNode.Create(COrdConstNode.Create(
              TFileDef(Left.ResultDef).TypedFileDef.Size,S32IntType,true),
              CCallParaNode.Create(Left,nil));
          end;
        { create the correct call }
        if m_isolike_io in CurrentSettings.ModeSwitches then
          begin
            case InlineNumber of
              in_reset_typedfile:
                Result := CCallNode.CreateIntern('fpc_reset_typed_iso',Left);
              in_reset_typedfile_name:
                Result := CCallNode.CreateIntern('fpc_reset_typed_name_iso',Left);
              in_rewrite_typedfile:
                Result := CCallNode.CreateIntern('fpc_rewrite_typed_iso',Left);
              in_rewrite_typedfile_name:
                Result := CCallNode.CreateIntern('fpc_rewrite_typed_name_iso',Left);
              else
                InternalError(2016101502);
            end;
          end
        else
          begin
            if InlineNumber=in_reset_typedfile then
              Result := CCallNode.CreateIntern('fpc_reset_typed',Left)
            else
              Result := CCallNode.CreateIntern('fpc_rewrite_typed',Left);
          end;

        { make sure left doesn't get disposed, since we use it in the new call }
        Left := nil;
      end;


    procedure MaybeConvertToString(var ANode: TNode);
      begin
        { stringconstnodes are arrays of char. It's much more }
        { efficient to write a constant string, so convert    }
        { either to shortstring or ansistring depending on    }
        { length                                              }
        if (ANode.NodeType=stringconstn) then
          if Is_CharArray(ANode.ResultDef) then
            if (TStringConstNode(ANode).len<=255) then
              InsertTypeConv(ANode,CShortStringType)
            else
              InsertTypeConv(ANode,GetAnsiStringDef)
          else if Is_WideCharArray(ANode.ResultDef) then
            InsertTypeConv(ANode,CUnicodeStringType);
      end;


    procedure GetReadWriteIntFunc(ADef: TDef; out AFuncSuffix: ShortString; out AReadFuncType: TDef);
    var
      lOrdType: TOrdType;
    begin
      lOrdType := TOrdDef(ADef).OrdType;
      if Is_OversizedInt(ADef) then
        begin
          case lOrdType of
            s64bit:
              begin
                AFuncSuffix := 'int64';
                AReadFuncType:=S64IntType;
              end;
            u64bit :
              begin
                AFuncSuffix := 'qword';
                AReadFuncType:=U64IntType;
              end;
            s32bit:
              begin
                AFuncSuffix := 'longint';
                AReadFuncType:=S32IntType;
              end;
            u32bit :
              begin
                AFuncSuffix := 'longword';
                AReadFuncType:=U32IntType;
              end;
            s16bit:
              begin
                AFuncSuffix := 'smallint';
                AReadFuncType:=S16IntType;
              end;
            u16bit :
              begin
                AFuncSuffix := 'word';
                AReadFuncType:=U16IntType;
              end;
            else
              InternalError(2013032602);
          end;
        end
      else
        begin
          case lOrdType of
            s64bit,
            s32bit,
            s16bit,
            s8bit:
              begin
                AFuncSuffix := 'sint';
                AReadFuncType := SIntType;
              end;
            u64bit,
            u32bit,
            u16bit,
            u8bit:
              begin
                AFuncSuffix := 'uint';
                AReadFuncType := UIntType;
              end;
            else
              InternalError(2013032601);
          end;
        end;
    end;


    function TInlineNode.HandleTextReadWrite(AFilePara,AParams:TTertiaryNode;var ANewStatement:TNode):Boolean;

    {Read(ln)/write(ln) for text files.}

    const  ProcPrefixes:array[Boolean] of String[15]=('fpc_write_text_','fpc_read_text_');

    var lErrorPara,lIsReal,lSpecialHandling,lFoundError,lDoRead:Boolean;
        lNode1:TNode;
        lNextPara,
        lIndexPara,
        lLengthPara,
        lPara,
        lFracPara:TCallParaNode;
        lTempNode:TTempCreateNode;
        lReadFuncType:TDef;
        lName:String[63];
        lFuncSuffix:String[8];

    begin
      lPara:=TCallParaNode(AParams);
      lFoundError:=false;
      lDoRead:=InlineNumber in [in_read_x,in_readln_x,in_readstr_x];
      lName:='';
      while Assigned(lPara) do
        begin
          { is this parameter faulty? }
          lErrorPara:=false;
          { is this parameter a real? }
          lIsReal:=false;
          { type used for the read(), this is used to check
            whether a temp is needed for range checking }
          lReadFuncType:=nil;

          { can't read/write types }
          if (lPara.Left.NodeType=typen) and not(Is_TypeParam(TTypeNode(lPara.Left).TypeDef)) then
            begin
              CGMessagePos(lPara.FileInfo,type_e_cant_read_write_type);
              lErrorPara := true;
            end;

          { support writeln(procvar) }
          if lPara.Left.ResultDef.typ=procvardef then
            begin
              lNode1:=CCallNode.Create_ProcVar(nil,lPara.Left);
              TypeCheckPass(lNode1);
              lPara.Left:=lNode1;
            end;

          if InlineNumber in [in_write_x,in_writeln_x] then
            { prefer strings to chararrays }
            MaybeConvertToString(lPara.Left);
          if Is_TypeParam(lPara.Left.ResultDef) then
            lErrorPara:=true
          else
            case lPara.Left.ResultDef.typ of
              stringdef :
                begin
                  lName:=ProcPrefixes[lDoRead]+TStringDef(lPara.Left.ResultDef).StringTypName;
                  if (m_isolike_io in CurrentSettings.ModeSwitches) and (TStringDef(lPara.Left.ResultDef).StringType<>st_shortstring) then
                    begin
                      CGMessagePos(lPara.FileInfo,type_e_cant_read_write_type_in_iso_mode);
                      lErrorPara := true;
                    end;
                end;
              pointerdef :
                begin
                  if (not Is_PChar(lPara.Left.ResultDef)) or lDoRead then
                    begin
                      CGMessagePos(lPara.FileInfo,type_e_cant_read_write_type);
                      lErrorPara := true;
                    end
                  else
                    lName:=ProcPrefixes[lDoRead]+'pchar_as_pointer';
                end;
              floatdef :
                begin
                  lIsReal:=true;
                  if TFloatDef(lPara.Left.ResultDef).FloatType=s64currency then
                    lName := ProcPrefixes[lDoRead]+'currency'
                  else
                    begin
                      lName := ProcPrefixes[lDoRead]+'float';
                      lReadFuncType:=PBestRealType^;
                    end;
                  { iso pascal needs a different handler }
                  if (m_isolike_io in CurrentSettings.ModeSwitches) and lDoRead then
                    lName:=lName+'_iso';
                end;
              enumdef:
                begin
                  if m_isolike_io in CurrentSettings.ModeSwitches then
                    begin
                      lErrorPara := true;
                      CGMessagePos(lPara.FileInfo,type_e_cant_read_write_type);
                    end;

                  lName:=ProcPrefixes[lDoRead]+'enum';
                  if lDoRead then
                    { read is done with a var parameter so we need the correct
                      size for that }
                    case lPara.Left.ResultDef.Size of
                      1:
                        begin
                          lName:=lName+'_shortint';
                          lReadFuncType:=S8IntType;
                        end;
                      2:
                        begin
                          lName:=lName+'_smallint';
                          lReadFuncType:=S16IntType;
                        end;
                      4:
                        begin
                          lName:=lName+'_longint';
                          lReadFuncType:=S32IntType;
                        end;
                      else
                        InternalError(2022082601);
                    end
                  else
                    lReadFuncType:=S32IntType;
                end;
              orddef :
                begin
                  case TOrdDef(lPara.Left.ResultDef).OrdType of
                    s8bit,
                    s16bit,
                    s32bit,
                    s64bit,
                    u8bit,
                    u16bit,
                    u32bit,
                    u64bit:
                      begin
                        GetReadWriteIntFunc(lPara.Left.ResultDef,lFuncSuffix,lReadFuncType);
                        lName := ProcPrefixes[lDoRead]+lFuncSuffix;
                        if (m_isolike_io in CurrentSettings.ModeSwitches) and lDoRead then
                          lName:=lName+'_iso';
                      end;
                    uchar :
                      begin
                        lName := ProcPrefixes[lDoRead]+'char';
                        { iso pascal needs a different handler }
                        if (m_isolike_io in CurrentSettings.ModeSwitches) and lDoRead then
                          lName:=lName+'_iso';
                        lReadFuncType:=CAnsiCharType;
                      end;
                    uwidechar :
                      begin
                        lName := ProcPrefixes[lDoRead]+'widechar';
                        lReadFuncType:=CWideCharType;
                      end;
                    scurrency:
                      begin
                        lName := ProcPrefixes[lDoRead]+'currency';
                        { iso pascal needs a different handler }
                        if (m_isolike_io in CurrentSettings.ModeSwitches) and lDoRead then
                          lName:=lName+'_iso';
                        lReadFuncType:=S64CurrencyType;
                        lIsReal:=true;
                      end;
                    pasbool1,
                    pasbool8,
                    pasbool16,
                    pasbool32,
                    pasbool64,
                    bool8bit,
                    bool16bit,
                    bool32bit,
                    bool64bit:
                      if lDoRead then
                        begin
                          CGMessagePos(lPara.FileInfo,type_e_cant_read_write_type);
                          lErrorPara := true;
                        end
                      else
                        begin
                          lName := ProcPrefixes[lDoRead]+'boolean';
                          lReadFuncType:=PasBool1Type;
                        end
                    else
                      begin
                        CGMessagePos(lPara.FileInfo,type_e_cant_read_write_type);
                        lErrorPara := true;
                      end;
                  end;
                end;
              variantdef :
                begin
                  lName:=ProcPrefixes[lDoRead]+'variant';
                  include(CurrentModule.ModuleFlags,mf_uses_variants);
                end;
              arraydef :
                begin
                  if Is_CharArray(lPara.Left.ResultDef) then
                    lName := ProcPrefixes[lDoRead]+'pchar_as_array'
                  else
                    begin
                      CGMessagePos(lPara.FileInfo,type_e_cant_read_write_type);
                      lErrorPara := true;
                    end
                end;
              else
                begin
                  CGMessagePos(lPara.FileInfo,type_e_cant_read_write_type);
                  lErrorPara := true;
                end;
            end;

          { iso pascal needs a different handler }
          if (m_isolike_io in CurrentSettings.ModeSwitches) and not(lDoRead) then
            lName:=lName+'_iso';

          { check for length/fractional colon para's }
          lFracPara:=nil;
          lLengthPara:=nil;
          lIndexPara:=nil;
          if Assigned(lPara.Right) and
             (cpf_is_colon_para in TCallParaNode(lPara.Right).CallParaFlags) then
            begin
              lLengthPara := TCallParaNode(lPara.Right);
              if Assigned(lLengthPara.Right) and
                 (cpf_is_colon_para in TCallParaNode(lLengthPara.Right).CallParaFlags) then
                lFracPara:=TCallParaNode(lLengthPara.Right);
            end;
          { get the next parameter now already, because we're going }
          { to muck around with the pointers                        }
          if Assigned(lFracPara) then
            lNextPara := TCallParaNode(lFracPara.Right)
          else if Assigned(lLengthPara) then
            lNextPara := TCallParaNode(lLengthPara.Right)
          else
            lNextPara := TCallParaNode(lPara.Right);

          { check if a fracpara is allowed }
          if Assigned(lFracPara) and not lIsReal then
            begin
              CGMessagePos(lFracPara.FileInfo,parser_e_illegal_colon_qualifier);
              lErrorPara := true;
            end
          else if Assigned(lLengthPara) and lDoRead then
            begin
              { I think this is already filtered out by parsing, but I'm not sure (JM) }
              CGMessagePos(lLengthPara.FileInfo,parser_e_illegal_colon_qualifier);
              lErrorPara := true;
            end;

          { adjust found_error }
          lFoundError := lFoundError or lErrorPara;

          if not lErrorPara then
            begin
              lSpecialHandling:=false;
              { create dummy frac/len para's if necessary }
              if not lDoRead then
                begin
                  { difference in default value for floats and the rest :( }
                  if not lIsReal then
                    begin
                      if not Assigned(lLengthPara) then
                        begin
                          if m_isolike_io in CurrentSettings.ModeSwitches then
                            lLengthPara := CCallParaNode.Create(
                              COrdConstNode.Create(-1,S32IntType,false),nil)
                          else
                            lLengthPara := CCallParaNode.Create(
                              COrdConstNode.Create(0,S32IntType,false),nil);
                        end
                      else
                        { make sure we don't pass the successive }
                        { parameters too. We also already have a }
                        { reference to the next parameter in     }
                        { nextpara                               }
                        lLengthPara.Right := nil;
                    end
                  else
                    begin
                      if not Assigned(lLengthPara) then
                        lLengthPara := CCallParaNode.Create(
                          COrdConstNode.Create(Int64(-32767),S32IntType,false),nil);
                      { also create a default fracpara if necessary }
                      if not Assigned(lFracPara) then
                        lFracPara := CCallParaNode.Create(
                          COrdConstNode.Create(Int64(-1),S32IntType,false),nil);
                      { add it to the lenpara }
                      lLengthPara.Right := lFracPara;
                      if not Is_Currency(lPara.Left.ResultDef) then
                        begin
                          { and add the realtype para (this also removes the link }
                          { to any parameters coming after it)                    }
                          lFracPara.Right := CCallParaNode.Create(
                              COrdConstNode.Create(ord(TFloatDef(lPara.Left.ResultDef).FloatType),
                              S32IntType,true),nil);
                        end
                      else
                        lFracPara.Right:=nil;
                    end;
                  if lPara.Left.ResultDef.typ=enumdef then
                    begin
                      {To write(ln) an enum we need a some extra parameters.}
                      {Insert a reference to the ord2string index.}
                      lIndexPara:=CCallParaNode.Create(
                        CAddrNode.Create_Internal(
                          CRTTINode.Create(TEnumDef(lPara.Left.ResultDef),fullrtti,rdt_normal)
                        ),
                        nil);
                      {Insert a reference to the typinfo.}
                      lIndexPara:=CCallParaNode.Create(
                        CAddrNode.Create_Internal(
                         CRTTINode.Create(TEnumDef(lPara.Left.ResultDef),fullrtti,rdt_ord2str)
                        ),
                        lIndexPara);
                      {Insert a type conversion to to convert the enum to longint.}
                      lPara.Left:=CTypeConvNode.Create_Internal(lPara.Left,S32IntType);
                      TypeCheckPass(lPara.Left);
                    end;
                end
              else
                begin
                  {To read(ln) an enum we need a an extra parameter.}
                  if lPara.Left.ResultDef.typ=enumdef then
                    begin
                      {Insert a reference to the string2ord index.}
                      lIndexPara:=CCallParaNode.Create(CAddrNode.Create_Internal(
                        CRTTINode.Create(TEnumDef(lPara.Left.ResultDef),fullrtti,rdt_str2ord)
                      ),nil);
                      {Insert a type conversion to to convert the enum to longint.}
                      lPara.Left:=CTypeConvNode.Create_Internal(lPara.Left,lReadFuncType);
                      TypeCheckPass(lPara.Left);
                    end;
                  { special handling of reading small numbers, because the helpers  }
                  { expect a longint/card/bestreal var parameter. Use a temp. can't }
                  { use functions because then the call to FPC_IOCHECK destroys     }
                  { their result before we can store it                             }
                  if (lReadFuncType<>nil) and (lPara.Left.ResultDef<>lReadFuncType) then
                    lSpecialHandling:=true;
                end;
              if lSpecialHandling then
                begin
                  { since we're not going to pass the parameter as var-parameter }
                  { to the read function, manually check whether the parameter   }
                  { can be used as var-parameter (e.g., whether it isn't a       }
                  { property)                                                    }
                  valid_for_var(lPara.Left,true);

                  { create the parameter list: the temp ... }
                  lTempNode := CTempCreateNode.Create(lReadFuncType,lReadFuncType.Size,tt_persistent,false);
                  AddStatement(TStatementNode(ANewStatement),lTempNode);

                  { ... and the file }
                  lNode1 := CCallParaNode.Create(CTempRefNode.Create(lTempNode),
                    AFilePara.GetCopy);
                  TCallParaNode(TCallParaNode(lNode1).Right).Right:=lIndexPara;

                  { create the call to the helper }
                  AddStatement(TStatementNode(ANewStatement),
                    CCallNode.CreateIntern(lName,TCallParaNode(lNode1)));

                  { assign the result to the original var (this automatically }
                  { takes care of range checking)                             }
                  AddStatement(TStatementNode(ANewStatement),
                    CAssignmentNode.Create(lPara.Left,
                      CTempRefNode.Create(lTempNode)));

                  { release the temp location }
                  AddStatement(TStatementNode(ANewStatement),CTempDeleteNode.Create(lTempNode));

                  { statement of para is used }
                  lPara.Left := nil;

                  { free the enclosing tcallparanode, but not the }
                  { parameters coming after it                    }
                  lPara.Right := nil;
                  lPara.free;
                  lPara := nil;
                end
              else
                { read of non s/u-8/16bit, or a write }
                begin
                  { add the filepara to the current parameter }
                  lPara.Right := AFilePara.GetCopy;
                  {Add the lenpara and the indexpara(s) (fracpara and realtype are
                   already linked with the lenpara if necessary).}
                  if lIndexPara=nil then
                    TCallParaNode(lPara.Right).Right:=lLengthPara
                  else
                    begin
                      if lLengthPara=nil then
                        TCallParaNode(lPara.Right).Right:=lIndexPara
                      else
                        begin
                          TCallParaNode(lPara.Right).Right:=lLengthPara;
                          lLengthPara.Right:=lIndexPara;
                        end;
{                      indexpara.right:=lenpara;}
                    end;
                  { in case of writing a chararray, add whether it's zero-based }
                  if lPara.Left.ResultDef.typ=arraydef then
                    lPara := CCallParaNode.Create(COrdConstNode.Create(
                      ord(TArrayDef(lPara.Left.ResultDef).LowRange=0),PasBool1Type,false),lPara)
                  else
                  { in case of reading an ansistring pass a codepage argument }
                  if lDoRead and Is_AnsiString(lPara.Left.ResultDef) then
                    lPara:=CCallParaNode.Create(COrdConstNode.Create(
                      GetParaEncoding(lPara.Left.ResultDef),U16IntType,true),lPara);
                  { create the call statement }
                  AddStatement(TStatementNode(ANewStatement),
                    CCallNode.CreateIntern(lName,lPara));
                end
            end
          else
            { error_para = true }
            begin
              { free the parameter, since it isn't referenced anywhere anymore }
              lPara.Right := nil;
              lPara.free;
              lPara := nil;
              if Assigned(lLengthPara) then
                begin
                  lLengthPara.Right := nil;
                  lLengthPara.free;
                  lLengthPara := nil;
                end;
              if Assigned(lFracPara) then
                begin
                  lFracPara.Right := nil;
                  lFracPara.free;
                  lFracPara := nil;
                end;
            end;

          { process next parameter }
          lPara := lNextPara;
        end;

      { if no error, add the write(ln)/read(ln) end calls }
      if not lFoundError then
        begin
          case InlineNumber of
            in_read_x,
            in_readstr_x:
              lName:='fpc_read_end';
            in_write_x,
            in_writestr_x:
              lName:='fpc_write_end';
            in_readln_x:
              begin
                lName:='fpc_readln_end';
                if m_isolike_io in CurrentSettings.ModeSwitches then
                  lName:=lName+'_iso';
              end;
            in_writeln_x:
              lName:='fpc_writeln_end';
            else
              InternalError(2019050501);
          end;
          AddStatement(TStatementNode(ANewStatement),CCallNode.CreateIntern(lName,AFilePara.GetCopy));
        end;
      HandleTextReadWrite:=lFoundError;
    end;

    function TInlineNode.HandleTypedReadWrite(AFilePara,AParams:TTertiaryNode;var ANewStatement:TNode):Boolean;

    {Read/write for typed files.}

    const  ProcPrefixes:array[Boolean,Boolean] of String[19]=(('fpc_typed_write','fpc_typed_read'),
                                                              ('fpc_typed_write','fpc_typed_read_iso'));
           procnamesdisplay:array[Boolean,Boolean] of String[8] = (('Write','Read'),('WriteStr','ReadStr'));

    var lFoundError,lDoRead,lIsRWStr:Boolean;
        lPara,lNextPara:TCallParaNode;
        lNode1:TNode;
        lTempNode:TTempCreateNode;
    begin
      lFoundError:=false;
      lPara:=TCallParaNode(AParams);
      lDoRead:=InlineNumber in [in_read_x,in_readln_x,in_readstr_x];
      lIsRWStr := InlineNumber in [in_readstr_x,in_writestr_x];
      lTempNode:=nil;
      { add the typesize to the filepara }
      if AFilePara.ResultDef.typ=filedef then
        AFilePara.Right := CCallParaNode.Create(COrdConstNode.Create(
          TFileDef(AFilePara.ResultDef).TypedFileDef.Size,S32IntType,true),nil);

      { check for "no parameters" (you need at least one extra para for typed files) }
      if not Assigned(lPara) then
        begin
          CGMessage1(parser_e_wrong_parameter_size,procnamesdisplay[lIsRWStr,lDoRead]);
          lFoundError := true;
        end;

      { process all parameters }
      while Assigned(lPara) do
        begin
          { check if valid parameter }
          if lPara.Left.NodeType=typen then
            begin
              CGMessagePos(lPara.Left.FileInfo,type_e_cant_read_write_type);
              lFoundError := true;
            end;

          { support writeln(procvar) }
          if (lPara.Left.ResultDef.typ=procvardef) then
            begin
              lNode1:=CCallNode.Create_ProcVar(nil,lPara.Left);
              TypeCheckPass(lNode1);
              lPara.Left:=lNode1;
            end;

          if AFilePara.ResultDef.typ=filedef then
            InsertTypeConv(lPara.Left,TFileDef(AFilePara.ResultDef).TypedFileDef);

          if Assigned(lPara.Right) and
            (cpf_is_colon_para in TCallParaNode(lPara.Right).CallParaFlags) then
            begin
              CGMessagePos(lPara.Right.FileInfo,parser_e_illegal_colon_qualifier);

              { skip all colon para's }
              lNextPara := TCallParaNode(TCallParaNode(lPara.Right).Right);
              while Assigned(lNextPara) and (cpf_is_colon_para in lNextPara.CallParaFlags) do
                lNextPara := TCallParaNode(lNextPara.Right);
              lFoundError := true;
            end
          else
            { get next parameter }
            lNextPara := TCallParaNode(lPara.Right);

          { When we have a call, we have a problem: you can't pass the  }
          { result of a call as a formal const parameter. Solution:     }
          { assign the result to a temp and pass this temp as parameter }
          { This is not very efficient, but write(typedfile,x) is       }
          { already slow by itself anyway (no buffering) (JM)           }
          { Actually, thge same goes for every non-simple expression    }
          { (such as an addition, ...) -> put everything but load nodes }
          { into temps (JM)                                             }
          { of course, this must only be allowed for writes!!! (JM)     }
          if not(lDoRead) and (lPara.Left.NodeType <> loadn) then
            begin
              { create temp for result }
              lTempNode := CTempCreateNode.Create(lPara.Left.ResultDef,
                lPara.Left.ResultDef.Size,tt_persistent,false);
              AddStatement(TStatementNode(ANewStatement),lTempNode);
              { assign result to temp }
              AddStatement(TStatementNode(ANewStatement),
               CAssignmentNode.Create(CTempRefNode.Create(lTempNode),
                 lPara.Left));
              { replace (reused) paranode with temp }
              lPara.Left := CTempRefNode.Create(lTempNode);
            end;
          { add fileparameter }
          lPara.Right := AFilePara.GetCopy;

          { create call statement                                            }
          { since the parameters are in the correct order, we have to insert }
          { the statements always at the end of the current block            }
          AddStatement(TStatementNode(ANewStatement),
            CCallNode.CreateIntern(ProcPrefixes[m_isolike_io in CurrentSettings.ModeSwitches,lDoRead],lPara
          ));

          { if we used a temp, free it }
          if lPara.Left.NodeType = temprefn then
            AddStatement(TStatementNode(ANewStatement),CTempDeleteNode.Create(lTempNode));

          { process next parameter }
          lPara := lNextPara;
        end;

      HandleTypedReadWrite:=lFoundError;
    end;

    function TInlineNode.HandleReadWrite: TNode;

      var
        lFilePara,
        lNextPara,
        lParams   : TCallParaNode;
        lNewStatement  : TStatementNode;
        lNewBlock      : TBlockNode;
        lFileTemp      : TTempCreateNode;
        lName          : String[31];
        lTextSym       : TTypeSym;
        lIsTyped,
        lDoRead,
        lIsRWStr,
        lFoundError   : Boolean;
      begin
        lFilePara := nil;
        lIsTyped := false;
        lFileTemp := nil;
        lDoRead := InlineNumber in [in_read_x,in_readln_x,in_readstr_x];
        lIsRWStr := InlineNumber in [in_readstr_x,in_writestr_x];

        { if we fail, we can quickly exit this way. We must generate something }
        { instead of the inline node, because firstpass will bomb with an      }
        { internalerror if it encounters a read/write                          }
        Result := CErrorNode.Create;

        { reverse the parameters (needed to get the colon parameters in the }
        { correct order when processing write(ln)                           }
        ReverseParameters(TCallParaNode(Left));

        if lIsRWStr then
          begin
            lFilePara := TCallParaNode(Left);
            { needs at least two parameters: source/dest string + min. 1 value }
            if not(Assigned(lFilePara)) or
               not(Assigned(lFilePara.Right)) then
              begin
                CGMessagePos1(FileInfo,parser_e_wrong_parameter_size,'ReadStr/WriteStr');
                exit;
              end
            else if (lFilePara.ResultDef.typ <> stringdef) then
              begin
                { convert chararray to string, or give an appropriate error message }
                { (if you want to optimize to use shortstring, keep in mind that    }
                {  readstr internally always uses ansistring, and to account for    }
                {  chararrays with > 255 characters)                                }
                InsertTypeConv(lFilePara.Left,GetAnsiStringDef);
                lFilePara.ResultDef:=lFilePara.Left.ResultDef;
                if CodeGenError then
                  exit;
              end
          end
        else if Assigned(Left) then
          begin
            { check if we have a file parameter and if yes, what kind it is }
            lFilePara := TCallParaNode(Left);

            if (lFilePara.ResultDef.typ=filedef) then
              begin
                if (TFileDef(lFilePara.ResultDef).FileTyp=ft_untyped) then
                  begin
                    CGMessagePos(FileInfo,type_e_no_read_write_for_untyped_file);
                    exit;
                  end
                else
                  begin
                    if (TFileDef(lFilePara.ResultDef).FileTyp=ft_typed) then
                      begin
                        if (InlineNumber in [in_readln_x,in_writeln_x]) then
                          begin
                            CGMessagePos(FileInfo,type_e_no_readln_writeln_for_typed_file);
                            exit;
                          end;
                        lIsTyped := true;
                      end
                  end;
              end
            else
              lFilePara := nil;
          end;

        if Assigned(lFilePara) and
            Assigned(lFilePara.Right) and
            (cpf_is_colon_para in TCallParaNode(lFilePara.Right).CallParaFlags) then
          begin
            CGMessagePos(lFilePara.FileInfo,parser_e_illegal_colon_qualifier);
            { for recovery we can simply continue, because the compiler will
              simply treat the next parameters as normal parameters }
          end;

        { create a blocknode in which the successive write/read statements will be  }
        { put, since they belong together. Also create a dummy statement already to }
        { make inserting of additional statements easier                            }
        lNewBlock:=InternalStatements(lNewStatement);

        if lIsRWStr then
          begin
            { create a dummy temp text file that will be used to cache the
              readstr/writestr state. Can't use a global variable in the system
              unit because these can be nested (in case of parameters to
              writestr that are function calls to functions that also call
              readstr/writestr) }
            lTextSym:=Search_System_Type('TEXT');
            lFileTemp:=CTempCreateNode.Create(lTextSym.TypeDef,lTextSym.TypeDef.Size,tt_persistent,false);
            AddStatement(lNewStatement,lFileTemp);

            if (lDoRead) then
              lName:='fpc_setupreadstr_'
            else
              lName:='fpc_setupwritestr_';
            lName:=lName+TStringDef(lFilePara.ResultDef).StringTypName;
            { the file para is a var parameter, but it is properly initialized,
              so it should be actually an out parameter }
            if not(lDoRead) then
              set_varstate(lFilePara.Left,vs_written,[]);
            { remove the source/destination string parameter from the }
            { parameter chain                                         }
            Left:=lFilePara.Right;
            lFilePara.Right:=CCallParaNode.Create(CTempRefNode.Create(lFileTemp),nil);
            { in case of a writestr() to an ansistring, also pass the string's
              code page }
            if not lDoRead and
               Is_AnsiString(lFilePara.Left.ResultDef) then
              lFilePara:=CCallParaNode.Create(GenIntConstNode(TStringDef(lFilePara.Left.ResultDef).encoding),lFilePara);
            { pass the temp text file and the source/destination string to the
              setup routine, which will store the string's address in the
              textrec }
            AddStatement(lNewStatement,CCallNode.CreateIntern(lName,lFilePara));
            lFilePara:=CCallParaNode.Create(CTempRefNode.Create(lFileTemp),nil);
          end
        { if we don't have a filepara, create one containing the default }
        else if not Assigned(lFilePara) then
          begin
            { since the input/output variables are threadvars loading them into
              a temp once is faster. Create a temp which will hold a pointer to the file }
            lFileTemp := CTempCreateNode.Create(VoidPointerType,VoidPointerType.Size,tt_persistent,true);
            AddStatement(lNewStatement,lFileTemp);

            { make sure the resultdef of the temp (and as such of the }
            { temprefs coming after it) is set (necessary because the  }
            { temprefs will be part of the filepara, of which we need  }
            { the resultdef later on and temprefs can only be         }
            { typecheckpassed if the resultdef of the temp is known) }
            TypeCheckPass(TNode(lFileTemp));

            { assign the address of the file to the temp }
            if lDoRead then
              lName := 'input'
            else
              lName := 'output';
            AddStatement(lNewStatement,
              CAssignmentNode.Create(CTempRefNode.Create(lFileTemp),
                CCallNode.CreateIntern('fpc_get_'+lName,nil)));

            { create a new fileparameter as follows: file_type(temp^)    }
            { (so that we pass the value and not the address of the temp }
            { to the read/write routine)                                 }
            lTextSym:=Search_System_Type('TEXT');
            lFilePara := CCallParaNode.Create(CTypeConvNode.Create_Internal(
              CDerefNode.Create(CTempRefNode.Create(lFileTemp)),lTextSym.TypeDef),nil);
          end
        else
          { remove filepara from the parameter chain }
          begin
            Left := lFilePara.Right;
            lFilePara.Right := nil;
            { the file para is a var parameter, but it must be valid already }
            set_varstate(lFilePara.Left,vs_readwritten,[vsf_must_be_valid]);
            { check if we should make a temp to store the result of a complex }
            { expression (better heuristics, anyone?) (JM)                    }
            if (lFilePara.Left.NodeType <> loadn) then
              begin
                { create a temp which will hold a pointer to the file }
                lFileTemp := CTempCreateNode.Create(VoidPointerType,VoidPointerType.Size,tt_persistent,true);

                { add it to the statements }
                AddStatement(lNewStatement,lFileTemp);

                { make sure the resultdef of the temp (and as such of the }
                { temprefs coming after it) is set (necessary because the  }
                { temprefs will be part of the filepara, of which we need  }
                { the resultdef later on and temprefs can only be         }
                { typecheckpassed if the resultdef of the temp is known) }
                TypeCheckPass(TNode(lFileTemp));

                { assign the address of the file to the temp }
                AddStatement(lNewStatement,
                  CAssignmentNode.Create(CTempRefNode.Create(lFileTemp),
                    CAddrNode.Create_Internal(lFilePara.Left)));
                TypeCheckPass(lNewStatement.Left);
                { create a new fileparameter as follows: file_type(temp^)    }
                { (so that we pass the value and not the address of the temp }
                { to the read/write routine)                                 }
                lNextPara := CCallParaNode.Create(CTypeConvNode.Create_Internal(
                  CDerefNode.Create(CTempRefNode.Create(lFileTemp)),lFilePara.Left.ResultDef),nil);

                { replace the old file para with the new one }
                lFilePara.Left := nil;
                lFilePara.free;
                lFilePara := lNextPara;
              end;
          end;

        { the resultdef of the filepara must be set since it's }
        { used below                                            }
        lFilePara.Get_ParaType;

        { now, filepara is nowhere referenced anymore, so we can safely dispose it }
        { if something goes wrong or at the end of the procedure                   }

        { we're going to reuse the paranodes, so make sure they don't get freed }
        { twice                                                                 }
        lParams:=TCallParaNode(Left);
        Left := nil;

        if lIsTyped then
          lFoundError:=HandleTypedReadWrite(lFilePara,TTertiaryNode(lParams),TNode(lNewStatement))
        else
          lFoundError:=HandleTextReadWrite(lFilePara,TTertiaryNode(lParams),TNode(lNewStatement));

        { free the file parameter (it's copied inside the handle_*_read_write methods) }
        lFilePara.free;
        lFilePara := nil;

        { if we found an error, simply delete the generated blocknode }
        if lFoundError then
          begin
            { ensure that the tempinfo is freed correctly by destroying a
              delete node for it
              Note: this might happen legitimately when parsing a generic that
                    passes an undefined type to Write/Read }
            if Assigned(lFileTemp) then
              CTempDeleteNode.Create(lFileTemp).free; // no nil needed
            lNewBlock.free;
            lNewBlock := nil;
          end
        else
          begin
            { deallocate the temp for the file para if we used one }
            if Assigned(lFileTemp) then
              AddStatement(lNewStatement,CTempDeleteNode.Create(lFileTemp));
            { otherwise return the newly generated block of instructions, }
            { but first free the errornode we generated at the beginning }
            Result.free;
            Result := lNewBlock
          end;
      end;


    function GetValIntFunc(ADef: TDef): String;
    var
      lOrdType: TOrdType;
    begin
      lOrdType := TOrdDef(ADef).OrdType;
      if not (lOrdType in [s64bit,u64bit,s32bit,u32bit,s16bit,u16bit,s8bit,u8bit]) then
        InternalError(2020080101);

      if Is_OversizedInt(ADef) then
        begin
          case lOrdType of
            s64bit: exit('int64');
            u64bit: exit('qword');
            s32bit: exit('longint');
            u32bit: exit('longword');
            s16bit: exit('smallint');
            u16bit: exit('word');
            else
              InternalError(2013032606);
          end;
        end
      else
        begin
          case lOrdType of
            s64bit,s32bit,s16bit,s8bit: exit('sint');
            u64bit,u32bit,u16bit,u8bit: exit('uint');
            else
              InternalError(2013032607);
          end;
        end;
      InternalError(2013032608);
    end;


    function TInlineNode.HandleVal: TNode;
      var
        lProcName,
        lSuffix        : String[31];
        lSourcePara,
        lDestPara,
        lCodePara,
        lSizePara,
        lNewParas      : TCallParaNode;
        lOriginalCode,lTypeConvNode    : TNode;
        lNewStatement  : TStatementNode;
        lNewBlock      : TBlockNode;
        lTempCode      : TTempCreateNode;
        lValSIntType   : TDef;
      begin
        { for easy exiting if something goes wrong }
        Result := CErrorNode.Create;

        { check the amount of parameters }
        if not(Assigned(Left)) or
           not(Assigned(TCallParaNode(Left).Right)) then
         begin
           CGMessage1(parser_e_wrong_parameter_size,'Val');
           exit;
         end;

         lSuffix:='';

         { in case we are in a generic definition, we cannot
           do all checks, the parameters might be type parameters }
         if df_generic in CurrentProcInfo.procdef.DefOptions then
           begin
             Result.Free;
             Result:=nil;
             ResultDef:=VoidType;
             exit;
           end;

        { retrieve the ValSInt type }
        lValSIntType:=Search_System_Type('VALSINT').TypeDef;

        { reverse parameters for easier processing }
        ReverseParameters(TCallParaNode(Left));

        { get the parameters }
        lTempCode := nil;
        lOriginalCode := nil;
        lSizePara := nil;
        lSourcePara := TCallParaNode(Left);
        lDestPara := TCallParaNode(lSourcePara.Right);
        lCodePara := TCallParaNode(lDestPara.Right);

        { check if codepara is valid }
        if Assigned(lCodePara) and
           (
            not Is_Integer(lCodePara.ResultDef)
{$ifndef cpu64bitaddr}
            or Is_64BitInt(lCodePara.ResultDef)
{$endif not cpu64bitaddr}
            ) then
          begin
            CGMessagePos1(lCodePara.FileInfo,type_e_integer_expr_expected,lCodePara.ResultDef.TypeName);
            exit;
          end;

        { check if dest para is valid }
        if not Is_Integer(lDestPara.ResultDef) and
           not Is_Currency(lDestPara.ResultDef) and
           not(lDestPara.ResultDef.typ in [floatdef,enumdef]) then
          begin
            CGMessagePos(lDestPara.FileInfo,type_e_integer_or_real_expr_expected);
            exit;
          end;

        { we're going to reuse the existing para's, so make sure they  }
        { won't be disposed                                            }
        Left := nil;

        { create the blocknode which will hold the generated statements + }
        { an initial dummy statement                                      }

        lNewBlock:=InternalStatements(lNewStatement);

        { do we need a temp for code? Yes, if no code specified, or if  }
        { code is not a valsinttype sized parameter (we already checked }
        { whether the code para, if specified, was an orddef)           }
        if not Assigned(lCodePara) or
           (lCodePara.ResultDef.Size<>lValSIntType.Size) then
          begin
            lTempCode := CTempCreateNode.Create(lValSIntType,lValSIntType.Size,tt_persistent,false);
            AddStatement(lNewStatement,lTempCode);
            { set the resultdef of the temp (needed to be able to get }
            { the resultdef of the tempref used in the new code para) }
            TypeCheckPass(TNode(lTempCode));
            { create a temp codepara, but save the original code para to }
            { assign the result to later on                              }
            if Assigned(lCodePara) then
              begin
                lOriginalCode := lCodePara.Left;
                lCodePara.Left := CTempRefNode.Create(lTempCode);
              end
            else
              lCodePara := CCallParaNode.Create(CTempRefNode.Create(lTempCode),nil);
            { we need its resultdef later on }
            lCodePara.Get_ParaType;
          end
        else if (TOrdDef(lCodePara.ResultDef).OrdType <> TOrdDef(lValSIntType).OrdType) then
          { because code is a var parameter, it must match types exactly    }
          { however, since it will return values >= 0, both signed and      }
          { and unsigned ints of the same size are fine. Since the formal   }
          { code para type is sinttype, insert a typecoversion to sint for  }
          { unsigned para's  }
          begin
            lCodePara.Left := CTypeConvNode.Create_Internal(lCodePara.Left,lValSIntType);
            { make it explicit, otherwise you may get a nonsense range}
            { check error if the cardinal already contained a value   }
            { > $7fffffff                                             }
            lCodePara.Get_ParaType;
          end;

        { create the procedure name }
        lProcName := 'fpc_val_';

        case lDestPara.ResultDef.typ of
          orddef:
            begin
              case TOrdDef(lDestPara.ResultDef).OrdType of
                s8bit,s16bit,s32bit,s64bit,
                u8bit,u16bit,u32bit,u64bit:
                  begin
                    lSuffix := GetValIntFunc(lDestPara.ResultDef) + '_';
                    { we also need a destsize para in the case of sint or uint }
                    if (lSuffix = 'sint_') or (lSuffix = 'uint_') then
                      lSizePara := CCallParaNode.Create(COrdConstNode.Create
                        (lDestPara.ResultDef.Size,S32IntType,true),nil);
                  end;
                scurrency: lSuffix := 'currency_';
                else
                  InternalError(200304225);
              end;
            end;
          floatdef:
            lSuffix:='real_';
          enumdef:
            begin
              lSuffix:='enum_';
              lSizePara:=CCallParaNode.Create(CAddrNode.Create_Internal(
                CRTTINode.Create(TEnumDef(lDestPara.ResultDef),fullrtti,rdt_str2ord)
              ),nil);
            end;
          else
            InternalError(2019050515);
        end;

        lProcName := lProcName + lSuffix;

        { play a trick to have tcallnode handle invalid source parameters: }
        { the shortstring-longint val routine by default                   }
        if (lSourcePara.ResultDef.typ = stringdef) then
          lProcName := lProcName + TStringDef(lSourcePara.ResultDef).StringTypName
        { zero-based arrays (of char) can be implicitly converted to ansistring, but don't do
          so if not needed because the array is too short }
        else if Is_Zero_Based_Array(lSourcePara.ResultDef) and (lSourcePara.ResultDef.Size>255) then
          lProcName := lProcName + 'ansistr'
        else
          lProcName := lProcName + 'shortstr';

        { set up the correct parameters for the call: the code para... }
        lNewParas := lCodePara;
        { and the source para }
        lCodePara.Right := lSourcePara;
        { sizepara either contains nil if none is needed (which is ok, since   }
        { then the next statement serves any possible links with other paras   }
        { that sourcepara may have) or it contains the necessary size para and }
        { its right field is nil                                               }
        lSourcePara.Right := lSizePara;

        { create the call and assign the result to dest (val helpers are functions).
          Use a trick to prevent a type size mismatch warning to be generated by the
          assignment node. First convert implicitly to the resultdef. This will insert
          the range check. The Second conversion is done explicitly to hide the implicit conversion
          for the assignment node and therefor preventing the warning (PFV)

          The implicit conversion is avoided for enums because implicit conversion between
          longint (which is what fpc_val_enum_shortstr returns) and enumerations is not
          possible. (DM).

          The implicit conversion is also avoided for COMP type if it is handled by FPU (x86)
          to prevent warning about automatic type conversion. }
        if (lDestPara.ResultDef.typ=enumdef) or
           ((lDestPara.ResultDef.typ=floatdef) and (TFloatDef(lDestPara.ResultDef).FloatType=s64comp))
          then
            lTypeConvNode:=CCallNode.CreateFromIntrinsic(in_val_x,lProcName,lNewParas)
        else
          lTypeConvNode:=CTypeConvNode.Create(CCallNode.CreateFromIntrinsic(in_val_x,lProcName,lNewParas),lDestPara.Left.ResultDef);
        AddStatement(lNewStatement,CAssignmentNode.Create(
          lDestPara.Left,CTypeConvNode.Create_Internal(lTypeConvNode,lDestPara.Left.ResultDef)));

        { dispose of the enclosing paranode of the destination }
        lDestPara.Left := nil;
        lDestPara.Right := nil;
        lDestPara.free;
        lDestPara := nil;

        { check if we used a temp for code and whether we have to store }
        { it to the real code parameter                                 }
        if Assigned(lOriginalCode) then
          AddStatement(lNewStatement,CAssignmentNode.Create(
              lOriginalCode,
              CTypeConvNode.Create_Internal(
                CTempRefNode.Create(lTempCode),lOriginalCode.ResultDef)));

        { release the temp if we allocated one }
        if Assigned(lTempCode) then
          AddStatement(lNewStatement,CTempDeleteNode.Create(lTempCode));

        { free the errornode }
        Result.free;
        { and return it }
        Result := lNewBlock;
      end;

    function TInlineNode.HandleSetLength: TNode;
      var
        lDef: TDef;
        lDestPara,
        lParas: TNode;
        lNewStatement: TStatementNode;
        lPara: TCallParaNode;
        lCounter,
        lDimensions: LongInt;
        lIsArray: Boolean;
      begin
        { for easy exiting if something goes wrong }
        Result:=CErrorNode.Create;
        ResultDef:=VoidType;
        lParas:=Left;
        lDimensions:=0;
        if Assigned(lParas) then
         begin
           { check type of lengths }
           lPara:=TCallParaNode(lParas);
           while Assigned(lPara.Right) do
            begin
              set_varstate(lPara.Left,vs_read,[vsf_must_be_valid]);
              InsertTypeConv(lPara.Left,SIntType);
              inc(lDimensions);
              lPara:=TCallParaNode(lPara.Right);
            end;
         end
        else
         InternalError(2013112912);
        if lDimensions=0 then
         begin
           CGMessage1(parser_e_wrong_parameter_size,'SetLength');
           exit;
         end;
        { last param must be var }
        lDestPara:=lPara.Left;
        valid_for_var(lDestPara,true);
        set_varstate(lDestPara,vs_written,[vsf_must_be_valid,vsf_use_hints,vsf_use_hint_for_string_result]);
        { first param must be a string or dynamic array ...}
        lIsArray:=Is_Dynamic_Array(lDestPara.ResultDef);
        if not((lDestPara.ResultDef.typ=stringdef) or
               lIsArray) then
          begin
            { possibly generic involved? }
            if df_generic in CurrentProcInfo.procdef.DefOptions then
              Result:=InternalStatements(lNewStatement)
            else
              CGMessage(type_e_mismatch);
            exit;
          end;

        { only dynamic arrays accept more dimensions }
        if (lDimensions>1) then
         begin
           if (not lIsArray) then
            CGMessage(type_e_mismatch)
           else
            begin
              { check if the amount of dimensions is valid }
              lDef:=TArrayDef(lDestPara.ResultDef).ElementDef;
              lCounter:=lDimensions;
              while lCounter > 1 do
                begin
                  if not(Is_Dynamic_Array(lDef)) then
                    begin
                      CGMessage1(parser_e_wrong_parameter_size,'SetLength');
                      break;
                    end;
                  dec(lCounter);
                  lDef:=TArrayDef(lDef).ElementDef;
                end;
            end;
         end;
        Result.free;
        Result:=nil;
      end;


    function TInlineNode.HandleCopy: TNode;

      procedure DoError(ATypeMismatch:Boolean;AFunc:String;AFileInfo:TFilePosInfo);

        procedure WriteDynArrayCopy;
          begin
            MessagePos1(FileInfo,sym_e_param_list,'Copy(Dynamic Array;'+SizeSIntType.TypeName+'=`<low>`;'+SizeSIntType.TypeName+'=`<length>`);');
          end;

        begin
          if ATypeMismatch then
            CGMessagePos(AFileInfo,type_e_mismatch)
          else
            CGMessagePos1(AFileInfo,parser_e_wrong_parameter_size,'Copy');
          if AFunc='' then
            begin
              Write_System_Parameter_Lists('fpc_shortstr_copy');
              Write_System_Parameter_Lists('fpc_char_copy');
              Write_System_Parameter_Lists('fpc_unicodestr_copy');
              if tf_winlikewidestring in TargetInfo.Flags then
                Write_System_Parameter_Lists('fpc_widestr_copy');
              Write_System_Parameter_Lists('fpc_ansistr_copy');
              WriteDynArrayCopy;
            end
          else if AFunc='fpc_dynarray_copy' then
            WriteDynArrayCopy
          else
            Write_System_Parameter_Lists(AFunc);
        end;

      var
        lParas   : TNode;
        lPara     : TCallParaNode;
        lParaDef : TDef;
        lCounter : Integer;
        lMinArgs,
        lMaxArgs : LongInt;
        lFunc : String;
      begin
        if not Assigned(Left) then
          begin
            DoError(false,'',FileInfo);
            exit(CErrorNode.Create);
          end;
        Result:=nil;
        { determine copy function to use based on the first argument,
          also count the number of arguments in this loop }
        lCounter:=1;
        lParas:=Left;
        lPara:=TCallParaNode(lParas);
        while Assigned(lPara.Right) do
         begin
           inc(lCounter);
           set_varstate(lPara.Left,vs_read,[vsf_must_be_valid]);
           lPara:=TCallParaNode(lPara.Right);
         end;
        set_varstate(lPara.Left,vs_read,[vsf_must_be_valid]);
        lParaDef:=lPara.Left.ResultDef;
        { the string variants all require 2 or 3 args, only the array one allows less }
        lMinArgs:=2;
        lMaxArgs:=3;
        lFunc:='';
        if Is_AnsiString(lParaDef) then
          begin
            // set resultdef to argument def
            ResultDef:=lParaDef;
            lFunc:='fpc_ansistr_copy';
          end
        else if (Is_CharArray(lParaDef) and (lParaDef.Size>255)) or
           ((cs_refcountedstrings in CurrentSettings.LocalSwitches) and Is_PChar(lParaDef)) then
          begin
            // set resultdef to ansistring type since result will be in ansistring codepage
            ResultDef:=GetAnsiStringDef;
            lFunc:='fpc_ansistr_copy';
          end
        else if Is_WideString(lParaDef) then
          begin
           ResultDef:=CWideStringType;
           lFunc:='fpc_widestr_copy';
          end
        else if Is_UnicodeString(lParaDef) or
            Is_WideCharArray(lParaDef) or
            Is_PWideChar(lParaDef) then
          begin
            ResultDef:=CUnicodeStringType;
            lFunc:='fpc_unicodestr_copy';
          end
        else
         if Is_Char(lParaDef) then
           begin
             ResultDef:=CShortStringType;
             lFunc:='fpc_char_copy';
           end
        else
         if Is_Dynamic_Array(lParaDef) then
          begin
            lMinArgs:=1;
            ResultDef:=lParaDef;
            lFunc:='fpc_array_to_dynarray_copy';
          end
        else
         if Is_Open_Array(lParaDef) then
          begin
            lMinArgs:=1;
            ResultDef:=CArrayDef.Create(0,-1,TArrayDef(lParaDef).RangeDef);
            TArrayDef(ResultDef).ArrayOptions:=TArrayDef(ResultDef).ArrayOptions+[ado_IsDynamicArray];
            TArrayDef(ResultDef).ElementDef:=TArrayDef(lParaDef).ElementDef;
            lFunc:='fpc_array_to_dynarray_copy';
          end
        else if lCounter in [2..3] then
          begin
            ResultDef:=CShortStringType;
            lFunc:='fpc_shortstr_copy';
          end
        else if lCounter<=lMaxArgs then
          begin
            DoError(true,'',lPara.Left.FileInfo);
            exit(CErrorNode.Create);
          end;

        if (lCounter<lMinArgs) or (lCounter>lMaxArgs) then
          begin
            DoError(false,lFunc,FileInfo);
            exit(CErrorNode.Create);
          end;
      end;

{$maxfpuregisters 0}

    function TInlineNode.Simplify(AForInline : Boolean): TNode;

      function DoLowHigh(ADef:TDef) : TNode;
        var
           lValue    : TConstExprInt;
           lEnumSym : TEnumSym;
           lNode   : TNode;
           lIndex    : Integer;
        begin
           case ADef.typ of
             orddef:
               begin
                  set_varstate(Left,vs_read,[]);
                  if InlineNumber=in_low_x then
                    lValue:=TOrdDef(ADef).low
                  else
                    lValue:=TOrdDef(ADef).high;
                  lNode:=COrdConstNode.Create(lValue,ADef,true);
                  TypeCheckPass(lNode);
                  DoLowHigh:=lNode;
               end;
             enumdef:
               begin
                  set_varstate(Left,vs_read,[]);
                  if InlineNumber=in_high_x then
                    lValue:=TEnumDef(ADef).MaxVal
                  else
                    lValue:=TEnumDef(ADef).MinVal;
                  lEnumSym:=nil;
                  for lIndex := 0 to TEnumDef(ADef).SymTable.SymList.Count - 1 do
                    if TEnumSym(TEnumDef(ADef).SymTable.SymList[lIndex]).Value=lValue then
                      begin
                        lEnumSym:=TEnumSym(TEnumDef(ADef).SymTable.SymList[lIndex]);
                        break;
                      end;
                  if not Assigned(lEnumSym) then
                    InternalError(309993)
                  else
                    lNode:=GenEnumNode(lEnumSym);
                  DoLowHigh:=lNode;
               end;
           else
             InternalError(87);
           end;
        end;


      function GetConstRealValue : BestReal;
        begin
           case Left.NodeType of
              ordconstn:
                GetConstRealValue:=TOrdConstNode(Left).Value;
              realconstn:
                begin
                  if (nf_is_currency in TRealConstNode(Left).Flags) then
                    GetConstRealValue:=TRealConstNode(Left).ValueReal/BestReal(10000.0)
                  else
                    GetConstRealValue:=TRealConstNode(Left).ValueReal;
                end
              else
                InternalError(309992);
           end;
        end;


      procedure SetConstRealValue(ARealValue : BestReal);
        begin
           Result:=CRealConstNode.Create(ARealValue,PBestRealType^);
        end;


      function HandleLnConst(ARealValue : BestReal) : TNode;
        begin
          if ARealValue<=0.0 then
            if Floating_Point_Range_Check_Error then
               begin
                 Result:=CRealConstNode.Create(0,PBestRealType^);
                 CGMessage(type_e_wrong_math_argument)
               end
            else
              begin
                if ARealValue=0.0 then
                  Result:=CRealConstNode.Create(MathNegInf.Value,PBestRealType^)
                else
                  Result:=CRealConstNode.Create(MathQNaN.Value,PBestRealType^)
              end
          else
            Result:=CRealConstNode.Create(Ln(ARealValue),PBestRealType^)
        end;


      function HandleSqrtConst(ARealValue : BestReal) : TNode;
        begin
          if ARealValue<0.0 then
            if Floating_Point_Range_Check_Error then
               begin
                 Result:=CRealConstNode.Create(0,PBestRealType^);
                 CGMessage(type_e_wrong_math_argument)
               end
            else
              Result:=CRealConstNode.Create(MathQNaN.Value,PBestRealType^)
          else
            Result:=CRealConstNode.Create(Sqrt(ARealValue),PBestRealType^)
        end;


      function HandleConstSAR : TNode;
        var
          lIntValue,lIntValue2    : TConstExprInt;
          lBits,lShift: Integer;
          lMask : QWord;
          lDef : TDef;
        begin
          Result:=nil;
          if (Left.NodeType=ordconstn) or ((Left.NodeType=callparan) and (TCallParaNode(Left).Left.NodeType=ordconstn)) then
            begin
              if (Left.NodeType=callparan) and
                 Assigned(TCallParaNode(Left).Right) then
                begin
                  lIntValue:=TOrdConstNode(TCallParaNode(Left).Left).Value;
                  if AForInline then
                    case ResultDef.Size of
                      1,2,4:
                        lIntValue:=lIntValue and Byte($1f);
                      8:
                        lIntValue:=lIntValue and Byte($3f);
                      else
                        InternalError(2013122303);
                    end;
                  if (TCallParaNode(TCallParaNode(Left).Right).Left.NodeType=ordconstn) then
                    begin
                      lDef:=TCallParaNode(TCallParaNode(Left).Right).Left.ResultDef;
                      lIntValue2:=TOrdConstNode(TCallParaNode(TCallParaNode(Left).Right).Left).Value;
                    end
                  else if lIntValue=0 then
                    begin
                      Result:=TCallParaNode(TCallParaNode(Left).Right).Left;
                      TCallParaNode(TCallParaNode(Left).Right).Left:=nil;
                      exit;
                    end
                  else
                    exit;
                end
              else
                begin
                  lDef:=Left.ResultDef;
                  lIntValue:=1;
                  lIntValue2:=TOrdConstNode(Left).Value;
                end;

              lBits:=lDef.Size*8;
              lShift:=lIntValue.svalue and (lBits-1);
              case lBits of
                 8:
                   lMask:=$ff;
                 16:
                   lMask:=$ffff;
                 32:
                   lMask:=$ffffffff;
                 64:
                   lMask:=QWord($ffffffffffffffff);
                 else
                   lMask:=QWord(1 shl lBits)-1;
              end;
{$push}
{$r-,q-}
              if lShift=0 then
                Result:=COrdConstNode.Create(lIntValue2.svalue,lDef,false)
              else if lIntValue2.svalue<0 then
                Result:=COrdConstNode.Create(((lIntValue2.svalue shr lShift) or (lMask shl (lBits-lShift))) and lMask,lDef,false)
              else
                Result:=COrdConstNode.Create((lIntValue2.svalue shr lShift) and lMask,lDef,false);
{$pop}
            end
          else if (Left.NodeType=callparan) and Assigned(TCallParaNode(Left).Right) and
                  (TCallParaNode(TCallParaNode(Left).Right).Left.NodeType=ordconstn) then
            begin
              lDef:=TCallParaNode(TCallParaNode(Left).Right).Left.ResultDef;
              lIntValue2:=TOrdConstNode(TCallParaNode(TCallParaNode(Left).Right).Left).Value;
              { sar(0,x) is 0 }
              { sar32(ffffffff,x) is ffffffff, etc. }
              if ((lIntValue2=0) or
                  ((ResultDef.Size=1) and (shortint(lIntValue2.svalue)=-1)) or
                  ((ResultDef.Size=2) and (smallint(lIntValue2.svalue)=-1)) or
                  ((ResultDef.Size=4) and (LongInt(lIntValue2.svalue)=-1)) or
                  ((ResultDef.Size=8) and (Int64(lIntValue2.svalue)=-1))) and
                 ((cs_opt_level4 in CurrentSettings.OptimizerSwitches) or
                  not Might_Have_SideEffects(TCallParaNode(Left).Left)) then
                begin
                  if lIntValue2=0 then
                    Result:=COrdConstNode.Create(0,ResultDef,true)
                  else
                    Result:=COrdConstNode.Create(-1,ResultDef,true);
                end;
            end;
        end;


      function HandleConstROX : TNode;
        var
          lIntValue,lIntValue2    : TConstExprInt;
          lBits,lShift: Integer;
          lDef : TDef;
        begin
          Result:=nil;
          if (Left.NodeType=ordconstn) or ((Left.NodeType=callparan) and (TCallParaNode(Left).Left.NodeType=ordconstn)) then
            begin
              if (Left.NodeType=callparan) and
                 Assigned(TCallParaNode(Left).Right) then
                begin
                  lIntValue:=TOrdConstNode(TCallParaNode(Left).Left).Value;
                  if AForInline then
                    case ResultDef.Size of
                      { unlike shifts, for rotates, when masking out the higher bits
                        of the rotate count, we go all the way down to byte, because
                        it doesn't matter, it produces the same result, since it's a rotate }
                      1:
                        lIntValue:=lIntValue and Byte($07);
                      2:
                        lIntValue:=lIntValue and Byte($0f);
                      4:
                        lIntValue:=lIntValue and Byte($1f);
                      8:
                        lIntValue:=lIntValue and Byte($3f);
                      else
                        InternalError(2013122304);
                    end;
                  if (TCallParaNode(TCallParaNode(Left).Right).Left.NodeType=ordconstn) then
                    begin
                      lDef:=TCallParaNode(TCallParaNode(Left).Right).Left.ResultDef;
                      lIntValue2:=TOrdConstNode(TCallParaNode(TCallParaNode(Left).Right).Left).Value;
                    end
                  else if lIntValue=0 then
                    begin
                      Result:=TCallParaNode(TCallParaNode(Left).Right).Left;
                      TCallParaNode(TCallParaNode(Left).Right).Left:=nil;
                      exit;
                    end
                  else
                    exit;
                end
              else
                begin
                  lDef:=Left.ResultDef;
                  lIntValue:=1;
                  lIntValue2:=TOrdConstNode(Left).Value;
                end;

              lBits:=lDef.Size*8;
              lShift:=lIntValue.svalue and (lBits-1);
{$push}
{$r-,q-}
              if lShift=0 then
                Result:=COrdConstNode.Create(lIntValue2.svalue,lDef,false)
              else
                case InlineNumber of
                  in_ror_x,in_ror_x_y:
                    case lDef.Size of
                      1:
                        Result:=COrdConstNode.Create(RorByte(Byte(lIntValue2.svalue),lShift),lDef,false);
                      2:
                        Result:=COrdConstNode.Create(RorWord(Word(lIntValue2.svalue),lShift),lDef,false);
                      4:
                        Result:=COrdConstNode.Create(RorDWord(DWord(lIntValue2.svalue),lShift),lDef,false);
                      8:
                        Result:=COrdConstNode.Create(RorQWord(QWord(lIntValue2.svalue),lShift),lDef,false);
                      else
                        InternalError(2011061903);
                    end;
                  in_rol_x,in_rol_x_y:
                    case lDef.Size of
                      1:
                        Result:=COrdConstNode.Create(RolByte(Byte(lIntValue2.svalue),lShift),lDef,false);
                      2:
                        Result:=COrdConstNode.Create(RolWord(Word(lIntValue2.svalue),lShift),lDef,false);
                      4:
                        Result:=COrdConstNode.Create(RolDWord(DWord(lIntValue2.svalue),lShift),lDef,false);
                      8:
                        Result:=COrdConstNode.Create(RolQWord(QWord(lIntValue2.svalue),lShift),lDef,false);
                      else
                        InternalError(2011061902);
                    end;
                  else
                    InternalError(2011061901);
                  end;
{$pop}
            end
          else if (Left.NodeType=callparan) and Assigned(TCallParaNode(Left).Right) and
                  (TCallParaNode(TCallParaNode(Left).Right).Left.NodeType=ordconstn) then
            begin
              lDef:=TCallParaNode(TCallParaNode(Left).Right).Left.ResultDef;
              lIntValue2:=TOrdConstNode(TCallParaNode(TCallParaNode(Left).Right).Left).Value;
              { rol/ror are unsigned operations, so cut off upper bits }
              case ResultDef.Size of
                1:
                  lIntValue2:=lIntValue2 and Byte($ff);
                2:
                  lIntValue2:=lIntValue2 and Word($ffff);
                4:
                  lIntValue2:=lIntValue2 and dword($ffffffff);
                8:
                  lIntValue2:=lIntValue2 and QWord($ffffffffffffffff);
                else
                  InternalError(2017050101);
              end;
              { rol(0,x) and ror(0,x) are 0 }
              { rol32(ffffffff,x) and ror32(ffffffff,x) are ffffffff, etc. }
              if ((lIntValue2=0) or
                  ((ResultDef.Size=1) and (lIntValue2=$ff)) or
                  ((ResultDef.Size=2) and (lIntValue2=$ffff)) or
                  ((ResultDef.Size=4) and (lIntValue2=$ffffffff)) or
                  ((ResultDef.Size=8) and (lIntValue2.uvalue=QWord($ffffffffffffffff)))) and
                 ((cs_opt_level4 in CurrentSettings.OptimizerSwitches) or
                  not Might_Have_SideEffects(TCallParaNode(Left).Left)) then
                Result:=COrdConstNode.Create(lIntValue2,ResultDef,true);
            end;
        end;

      function IsMinMaxDeterministic(var ANode: TOrdConstNode; const ADoMax: Boolean; out AResult: Boolean): Boolean;
        begin
          Result := False;
          if not Is_Integer(ResultDef) then
            InternalError(2024031501);

          if (ANode.Value <= TOrdDef(ResultDef).low) then
            begin
              AResult := not ADoMax;
              Exit(True);
            end
          else if (ANode.Value >= TOrdDef(ResultDef).high) then
            begin
              AResult := ADoMax;
              Exit(True);
            end
        end;

      var
        lNode,lNode2    : TNode;
        lIntValue,lIntValue2    : TConstExprInt;
        lRealValue        : BestReal;
        lHelperResult : Boolean;

      begin { simplify }
         Result:=nil;
         { handle intern constant functions in separate case }
         if inf_inlineconst in InlineNodeFlags then
          begin
            { no parameters? }
            if not Assigned(Left) then
              InternalError(200501231)
            else
             begin
               lIntValue:=0;
               lIntValue2:=0; { second parameter Ex: ptr(vl,vl2) }
               case Left.NodeType of
                 ordconstn :
                   lIntValue:=TOrdConstNode(Left).Value;
                 callparan :
                   begin
                     { both exists, else it was not generated }
                     lIntValue:=TOrdConstNode(TCallParaNode(Left).Left).Value;
                     lIntValue2:=TOrdConstNode(TCallParaNode(TCallParaNode(Left).Right).Left).Value;
                   end;
                 else
                   begin
                     { Real functions are all handled with internproc below, and
                       unsupported typex are also trapped here }
                     if Is_Integer(Left.ResultDef) then
                       { Not as informative, but less confusing }
                       CGMessagePos(Left.FileInfo,parser_e_illegal_expression)
                     else
                       CGMessagePos1(Left.FileInfo,type_e_integer_expr_expected,Left.ResultDef.TypeName);
                     Result:=CErrorNode.Create;
                     exit;
                   end;
               end;
               case InlineNumber of
                 in_const_abs :
                   if lIntValue.signed then
                     lNode:=Create_Simplified_Ord_Const(abs(lIntValue.svalue),ResultDef,AForInline,false)
                   else
                     lNode:=Create_Simplified_Ord_Const(lIntValue.uvalue,ResultDef,AForInline,false);
                 in_const_sqr:
                   if lIntValue.signed then
                     lNode:=Create_Simplified_Ord_Const(sqr(lIntValue.svalue),ResultDef,AForInline,false)
                   else
                     lNode:=Create_Simplified_Ord_Const(sqr(lIntValue.uvalue),ResultDef,AForInline,false);
                 in_const_odd :
                   lNode:=COrdConstNode.Create(QWord(odd(Int64(lIntValue))),PasBool1Type,true);
                 in_const_swap_word :
                   lNode:=COrdConstNode.Create((lIntValue and $ff) shl 8+(lIntValue shr 8),Left.ResultDef,true);
                 in_const_swap_long :
                   lNode:=COrdConstNode.Create((lIntValue and $ffff) shl 16+(lIntValue shr 16),Left.ResultDef,true);
                 in_const_swap_qword :
                   lNode:=COrdConstNode.Create((lIntValue and $ffffffff) shl 32+(lIntValue shr 32),Left.ResultDef,true);
                 in_const_ptr:
                   begin
                     {Don't construct pointers from negative values.}
                     if (lIntValue.signed and (lIntValue.svalue<0)) or (lIntValue2.signed and (lIntValue2.svalue<0)) then
                       CGMessage(parser_e_range_check_error);
{$if defined(i386)}
                     lNode:=CPointerConstNode.Create((lIntValue2.uvalue shl 4)+lIntValue.uvalue,VoidNearFSPointerType);
{$else}
                     lNode:=CPointerConstNode.Create((lIntValue2.uvalue shl 4)+lIntValue.uvalue,VoidPointerType);
{$endif}
                   end;
                 in_const_eh_return_data_regno:
                   begin
                     lIntValue:=eh_return_data_regno(lIntValue.svalue);
                     if lIntValue=-1 then
                       CGMessagePos(Left.FileInfo,type_e_range_check_error_bounds);
                     lNode:=GenIntConstNode(lIntValue);
                   end;
                 else
                   InternalError(88);
               end;
             end;
            if lNode=nil then
              lNode:=CErrorNode.Create;
            Result:=lNode;
          end
        else
          begin
            case InlineNumber of
              in_lo_long,
              in_hi_long,
              in_lo_qword,
              in_hi_qword,
              in_lo_word,
              in_hi_word :
                begin
                  if Left.NodeType=ordconstn then
                    begin
                      case InlineNumber of
                        in_lo_word :
                          Result:=COrdConstNode.Create(TOrdConstNode(Left).Value and $ff,U8IntType,true);
                        in_hi_word :
                          Result:=COrdConstNode.Create(TOrdConstNode(Left).Value shr 8,U8IntType,true);
                        in_lo_long :
                          Result:=COrdConstNode.Create(TOrdConstNode(Left).Value and $ffff,U16IntType,true);
                        in_hi_long :
                          Result:=COrdConstNode.Create(TOrdConstNode(Left).Value shr 16,U16IntType,true);
                        in_lo_qword :
                          Result:=COrdConstNode.Create(TOrdConstNode(Left).Value and $ffffffff,U32IntType,true);
                        in_hi_qword :
                          Result:=COrdConstNode.Create(TOrdConstNode(Left).Value shr 32,U32IntType,true);
                        else
                          InternalError(2019050514);
                      end;
                    end;
                end;
              in_ord_x:
                begin
                  case Left.ResultDef.typ of
                    orddef :
                      begin
                        case TOrdDef(Left.ResultDef).OrdType of
                          pasbool1,
                          pasbool8,
                          uchar:
                            begin
                              { change to byte() }
                              Result:=CTypeConvNode.Create_Internal(Left,U8IntType);
                              Left:=nil;
                            end;
                          pasbool16,
                          uwidechar :
                            begin
                              { change to word() }
                              Result:=CTypeConvNode.Create_Internal(Left,U16IntType);
                              Left:=nil;
                            end;
                          pasbool32 :
                            begin
                              { change to dword() }
                              Result:=CTypeConvNode.Create_Internal(Left,U32IntType);
                              Left:=nil;
                            end;
                          pasbool64 :
                            begin
                              { change to qword() }
                              Result:=CTypeConvNode.Create_Internal(Left,U64IntType);
                              Left:=nil;
                            end;
                          bool8bit:
                            begin
                              { change to shortint() }
                              Result:=CTypeConvNode.Create_Internal(Left,S8IntType);
                              Left:=nil;
                            end;
                          bool16bit :
                            begin
                              { change to smallint() }
                              Result:=CTypeConvNode.Create_Internal(Left,S16IntType);
                              Left:=nil;
                            end;
                          bool32bit :
                            begin
                              { change to longint() }
                              Result:=CTypeConvNode.Create_Internal(Left,S32IntType);
                              Left:=nil;
                            end;
                          bool64bit :
                            begin
                              { change to int64() }
                              Result:=CTypeConvNode.Create_Internal(Left,S64IntType);
                              Left:=nil;
                            end;
                          uvoid :
                            CGMessage1(type_e_ordinal_expr_expected,Left.ResultDef.TypeName);
                          else
                            begin
                              { all other orddef need no transformation }
                              Result:=Left;
                              Left:=nil;
                            end;
                        end;
                      end;
                    enumdef :
                      begin
                        Result:=CTypeConvNode.Create_Internal(Left,S32IntType);
                        Left:=nil;
                      end;
                    undefineddef :
                      begin
                        { we just create a constant 0 here, that's marked as a
                          parameter }
                        Result:=COrdConstNode.Create(0,S32IntType,false);
                        include(Result.Flags,nf_generic_para);
                        Left:=nil;
                      end;
                    pointerdef :
                      begin
                        if m_mac in CurrentSettings.ModeSwitches then
                          begin
                            Result:=CTypeConvNode.Create_Internal(Left,PtrUIntType);
                            Left:=nil;
                          end
                      end;
                    else
                      InternalError(2019050513);
                  end;
(*
                  if (left.nodetype=ordconstn) then
                     begin
                       result:=cordconstnode.create(
                         tordconstnode(left).value,sinttype,true);
                     end
                   else if (m_mac in current_settings.modeswitches) and
                           (left.ndoetype=pointerconstn) then
                       result:=cordconstnode.create(
                         tpointerconstnode(left).value,ptruinttype,true);
*)
                end;
              in_chr_byte:
                begin
                   { convert to explicit char() }
                   Result:=CTypeConvNode.Create_Internal(Left,CAnsiCharType);
                   Left:=nil;
                end;
              in_length_x:
                begin
                  case Left.ResultDef.typ of
                    stringdef :
                      begin
                        if (Left.NodeType=stringconstn) then
                          begin
                            Result:=COrdConstNode.Create(
                              TStringConstNode(Left).len,SIntType,true);
                          end;
                      end;
                    orddef :
                      begin
                        { length of char is always one }
                        if Is_Char(Left.ResultDef) or
                           Is_WideChar(Left.ResultDef) then
                         begin
                           Result:=COrdConstNode.Create(1,SIntType,false);
                         end
                      end;
                    arraydef :
                      begin
                        if (Left.NodeType=stringconstn) then
                          begin
                            Result:=COrdConstNode.Create(
                              TStringConstNode(Left).len,SIntType,true);
                          end
                        else if not Is_Open_Array(Left.ResultDef) and
                           not Is_Array_Of_Const(Left.ResultDef) and
                           not Is_Dynamic_Array(Left.ResultDef) then
                          Result:=GenIntConstNode(TArrayDef(Left.ResultDef).HighRange-
                            TArrayDef(Left.ResultDef).LowRange+1,SizeSIntType);
                      end;
                    else
                      ;
                  end;
                end;
              in_assigned_x:
                begin
                  if Is_ConstNode(TCallParaNode(Left).Left) or
                     (TCallParaNode(Left).Left.NodeType = pointerconstn) then
                    begin
                      { let an add node figure it out }
                      Result:=CAddNode.Create(unequaln,TCallParaNode(Left).Left,CNilNode.Create);
                      TCallParaNode(Left).Left := nil;
                    end;
                end;
              in_pred_x,
              in_succ_x:
                begin
                  case Left.NodeType of
                    ordconstn:
                      begin
                        if InlineNumber=in_succ_x then
                          lIntValue:=TOrdConstNode(Left).Value+1
                        else
                          lIntValue:=TOrdConstNode(Left).Value-1;
                        if Is_Integer(Left.ResultDef) then
                          { the type of the original integer constant is irrelevant,
                            it should be automatically adapted to the new value
                            (except when inlining) }
                          Result:=Create_Simplified_Ord_Const(lIntValue,ResultDef,AForInline,cs_check_range in LocalSwitches)
                        else
                          { check the range for enums, chars, booleans }
                          Result:=COrdConstNode.Create(lIntValue,Left.ResultDef,not(nf_internal in Flags));
                        Result.Flags:=Result.Flags+(Flags*[nf_internal]);
                      end;
                    addn,
                    subn:
                      begin
                        { fold succ/pred in child add/sub nodes with a constant if possible:
                           - no overflow/range checking
                           - equal types
                        }
                        if ([cs_check_overflow,cs_check_range]*CurrentSettings.LocalSwitches)=[] then
                          begin
                            if InlineNumber=in_succ_x then
                              lIntValue:=1
                            else
                              lIntValue:=-1;
                            if (TAddNode(Left).Left.NodeType=ordconstn) and Equal_Defs(ResultDef,TAddNode(Left).Left.ResultDef) then
                              begin
                                TOrdConstNode(TAddNode(Left).Left).Value:=TOrdConstNode(TAddNode(Left).Left).Value+lIntValue;
                                Result:=Left;
                                Left:=nil;
                              end
                            else if (TAddNode(Left).Right.NodeType=ordconstn) and Equal_Defs(ResultDef,TAddNode(Left).Right.ResultDef) then
                              begin
                                if Left.NodeType=subn then
                                  TOrdConstNode(TAddNode(Left).Right).Value:=TOrdConstNode(TAddNode(Left).Right).Value-lIntValue
                                else
                                  TOrdConstNode(TAddNode(Left).Right).Value:=TOrdConstNode(TAddNode(Left).Right).Value+lIntValue;
                                Result:=Left;
                                Left:=nil;
                              end;
                          end;
                      end;
                    else
                      ;
                  end;
                end;
              in_low_x,
              in_high_x:
                begin
                  case Left.ResultDef.typ of
                    orddef,
                    enumdef:
                      begin
                        Result:=DoLowHigh(Left.ResultDef);
                      end;
                    setdef:
                      begin
                        Result:=DoLowHigh(TSetDef(Left.ResultDef).ElementDef);
                      end;
                    arraydef:
                      begin
                        if (InlineNumber=in_low_x) then
                          begin
                            Result:=COrdConstNode.Create(Int64(TArrayDef(
                             Left.ResultDef).LowRange),TArrayDef(Left.ResultDef).RangeDef,true);
                          end
                        else if not Is_Open_Array(Left.ResultDef) and
                                not Is_Array_Of_Const(Left.ResultDef) and
                                not Is_Dynamic_Array(Left.ResultDef) then
                          Result:=COrdConstNode.Create(Int64(TArrayDef(Left.ResultDef).HighRange),
                            TArrayDef(Left.ResultDef).RangeDef,true);
                      end;
                    stringdef:
                      begin
                        if InlineNumber=in_low_x then
                          begin
                            if Is_DynamicString(Left.ResultDef) and
                              not(cs_zerobasedstrings in CurrentSettings.LocalSwitches) then
                              Result:=COrdConstNode.Create(1,U8IntType,false)
                            else
                              Result:=COrdConstNode.Create(0,U8IntType,false);
                          end
                        else if not Is_DynamicString(Left.ResultDef) then
                          Result:=COrdConstNode.Create(TStringDef(Left.ResultDef).len,U8IntType,true)
                      end;
                    undefineddef:
                      begin
                        Result:=COrdConstNode.Create(0,U8IntType,false);
                      end;
                    errordef:
                      ;
                    else
                      InternalError(2019050512);
                  end;
                end;
              in_exp_real :
                begin
                  if Left.NodeType in [ordconstn,realconstn] then
                    begin
                      Result:=CRealConstNode.Create(Exp(GetConstRealValue),PBestRealType^);
                      if (TRealConstNode(Result).ValueReal=MathInf.Value) and
                         Floating_Point_Range_Check_Error then
                        begin
                          Result:=CRealConstNode.Create(0,PBestRealType^);
                          CGMessage(parser_e_range_check_error);
                        end;
                    end
                end;
              in_trunc_real :
                begin
                  if Left.NodeType in [ordconstn,realconstn] then
                    begin
                      lRealValue:=GetConstRealValue;
                      if (lRealValue>=BestReal(QWord($8000000000000000))) or (lRealValue<BestReal(Low(Int64))) then
                        begin
                          message3(type_e_range_check_error_bounds,RealToStr(lRealValue),'-9223372036854775808.0','9223372036854775807.99..');
                          Result:=COrdConstNode.Create(1,S64IntType,false)
                        end
                      else
                        Result:=COrdConstNode.Create(Trunc(lRealValue),S64IntType,true)
                    end
                end;
              in_round_real :
                begin
                  { can't evaluate while inlining, may depend on fpu setting }
                  if (not AForInline) and
                     (Left.NodeType in [ordconstn,realconstn]) then
                    begin
                      lRealValue:=GetConstRealValue;
                      if (lRealValue>=BestReal(High(Int64))+BestReal(0.5)) or (lRealValue<BestReal(Low(Int64))) then
                        begin
                          message3(type_e_range_check_error_bounds,RealToStr(lRealValue),'-9223372036854775808.49..','9223372036854775807.49..');
                          Result:=COrdConstNode.Create(1,S64IntType,false)
                        end
                      else
                        Result:=COrdConstNode.Create(Round(lRealValue),S64IntType,true)
                    end
                end;
              in_frac_real :
                begin
                  if Left.NodeType in [ordconstn,realconstn] then
                    SetConstRealValue(Frac(GetConstRealValue))
                end;
              in_int_real :
                begin
                  if Left.NodeType in [ordconstn,realconstn] then
                    SetConstRealValue(Int(GetConstRealValue));
                end;
              in_pi_real :
                 begin
                   if Block_Type=bt_const then
                     SetConstRealValue(Pi)
                 end;
              in_cos_real :
                begin
                  if Left.NodeType in [ordconstn,realconstn] then
                    SetConstRealValue(Cos(GetConstRealValue))
                end;
              in_sin_real :
                begin
                  if Left.NodeType in [ordconstn,realconstn] then
                    SetConstRealValue(Sin(GetConstRealValue))
                end;
              in_arctan_real :
                begin
                  if Left.NodeType in [ordconstn,realconstn] then
                    SetConstRealValue(ArcTan(GetConstRealValue))
                end;
              in_abs_real :
                begin
                  if Left.NodeType in [ordconstn,realconstn] then
                    SetConstRealValue(Abs(GetConstRealValue))
                end;
              in_abs_long:
                begin
                  if Left.NodeType=ordconstn then
                    begin
                      if TOrdConstNode(Left).Value<0 then
                        Result:=COrdConstNode.Create((-TOrdConstNode(Left).Value),ResultDef,false)
                      else
                        Result:=COrdConstNode.Create((TOrdConstNode(Left).Value),ResultDef,false);
                    end
                end;
              in_sqr_real :
                begin
                  if Left.NodeType in [ordconstn,realconstn] then
                    SetConstRealValue((GetConstRealValue*GetConstRealValue))
                end;
              in_sqrt_real :
                begin
                  if Left.NodeType in [ordconstn,realconstn] then
                    Result:=HandleSqrtConst(GetConstRealValue);
                end;
              in_ln_real :
                begin
                  if Left.NodeType in [ordconstn,realconstn] then
                    Result:=HandleLnConst(GetConstRealValue);
                end;
              in_assert_x_y :
                begin
                  if not(cs_do_assertion in CurrentSettings.LocalSwitches) then
                    { we need a valid node, so insert a nothingn }
                    Result:=CNothingNode.Create;
                end;
              in_sar_x,
              in_sar_x_y :
                begin
                  Result:=HandleConstSAR;
                end;
              in_rol_x,
              in_rol_x_y,
              in_ror_x,
              in_ror_x_y :
                Result:=HandleConstROX;
              in_bsf_x:
                begin
                  if Left.NodeType=ordconstn then
                    begin
                      case Left.ResultDef.Size of
                        1:
                          Result:=COrdConstNode.Create(BsfByte(Byte(TOrdConstNode(Left).Value.uvalue)),ResultDef,false);
                        2:
                          Result:=COrdConstNode.Create(BsfWord(Word(TOrdConstNode(Left).Value.uvalue)),ResultDef,false);
                        4:
                          Result:=COrdConstNode.Create(BsfDWord(DWord(TOrdConstNode(Left).Value.uvalue)),ResultDef,false);
                        8:
                          Result:=COrdConstNode.Create(BsfQWord(QWord(TOrdConstNode(Left).Value.uvalue)),ResultDef,false);
                        else
                          InternalError(2017042401);
                      end;
                    end;
                end;
              in_bsr_x :
                begin
                  if Left.NodeType=ordconstn then
                    begin
                      case Left.ResultDef.Size of
                        1:
                          Result:=COrdConstNode.Create(BsrByte(Byte(TOrdConstNode(Left).Value.uvalue)),ResultDef,false);
                        2:
                          Result:=COrdConstNode.Create(BsrWord(Word(TOrdConstNode(Left).Value.uvalue)),ResultDef,false);
                        4:
                          Result:=COrdConstNode.Create(BsrDWord(DWord(TOrdConstNode(Left).Value.uvalue)),ResultDef,false);
                        8:
                          Result:=COrdConstNode.Create(BsrQWord(QWord(TOrdConstNode(Left).Value.uvalue)),ResultDef,false);
                        else
                          InternalError(2017042402);
                      end;
                    end;
                end;
              in_popcnt_x :
                begin
                  if Left.NodeType=ordconstn then
                    begin
                      Result:=COrdConstNode.Create(PopCnt(TOrdConstNode(Left).Value),ResultDef,false);
                    end;
                end;
              in_min_single,
              in_min_double:
                begin
                  { Check to see if the result is deterministic }
                  if Left.NodeType=callparan then
                    begin
                      lNode:=TCallParaNode(TCallParaNode(Left).NextPara).ParaValue;
                      lNode2:=TCallParaNode(Left).ParaValue;

                      if (lNode.NodeType=realconstn) then
                        begin
                          if (TRealConstNode(lNode).ValueReal = MathQNaN.Value) then
                            { If one of the inputs is NaN, the second parameter
                              is taken }
                            Result:=lNode2.GetCopy()
                          else if (TRealConstNode(lNode).ValueReal = MathNegInf.Value) then
                            { Nothing is less than than -oo }
                            Result:=CRealConstNode.Create(MathNegInf.Value,ResultDef)
                          else if (TRealConstNode(lNode).ValueReal = MathInf.Value) then
                            { Everything is less than +oo }
                            Result:=lNode2.GetCopy()
                          else if (lNode2.NodeType=realconstn) then
                            begin
                              { Both actual parameters are constants, so take
                                the smaller of the two right now }
                              if (TRealConstNode(lNode).ValueReal < TRealConstNode(lNode2).ValueReal) then
                                Result:=CRealConstNode.Create(TRealConstNode(lNode).ValueReal,ResultDef)
                              else
                                Result:=CRealConstNode.Create(TRealConstNode(lNode2).ValueReal,ResultDef);
                            end;
                        end
                      else if (lNode2.NodeType=realconstn) then
                        begin
                          if (TRealConstNode(lNode2).ValueReal = MathQNaN.Value) then
                            { If one of the inputs is NaN, the second parameter
                              is taken (even if it is NaN) }
                            Result:=CRealConstNode.Create(MathQNaN.Value,ResultDef)
                          else if (TRealConstNode(lNode2).ValueReal = MathNegInf.Value) then
                            { Nothing is less than than -oo }
                            Result:=CRealConstNode.Create(MathNegInf.Value,ResultDef)
                          else if (TRealConstNode(lNode2).ValueReal = MathInf.Value) then
                            { Everything is less than +oo }
                            Result:=lNode.GetCopy();
                        end;
                    end;
                end;
              in_max_single,
              in_max_double:
                begin
                  { Check to see if the result is deterministic }
                  if Left.NodeType=callparan then
                    begin
                      lNode:=TCallParaNode(TCallParaNode(Left).NextPara).ParaValue;
                      lNode2:=TCallParaNode(Left).ParaValue;

                      if (lNode.NodeType=realconstn) then
                        begin
                          if (TRealConstNode(lNode).ValueReal = MathQNaN.Value) then
                            { If one of the inputs is NaN, the second parameter
                              is taken }
                            Result:=lNode2.GetCopy()
                          else if (TRealConstNode(lNode).ValueReal = MathNegInf.Value) then
                            { Everything is greater than than -oo }
                            Result:=lNode2.GetCopy()
                          else if (TRealConstNode(lNode).ValueReal = MathInf.Value) then
                            { Nothing is greater than +oo }
                            Result:=CRealConstNode.Create(MathInf.Value,ResultDef)
                          else if (lNode2.NodeType=realconstn) then
                            begin
                              { Both actual parameters are constants, so take
                                the larger of the two right now }
                              if (TRealConstNode(lNode).ValueReal > TRealConstNode(lNode2).ValueReal) then
                                Result:=CRealConstNode.Create(TRealConstNode(lNode).ValueReal,ResultDef)
                              else
                                Result:=CRealConstNode.Create(TRealConstNode(lNode2).ValueReal,ResultDef)
                            end;
                        end
                      else if (lNode2.NodeType=realconstn) then
                        begin
                          if (TRealConstNode(lNode2).ValueReal = MathQNaN.Value) then
                            { If one of the inputs is NaN, the second parameter
                              is taken (even if it is NaN) }
                            Result:=CRealConstNode.Create(MathQNaN.Value,ResultDef)
                          else if (TRealConstNode(lNode2).ValueReal = MathNegInf.Value) then
                            { Everything is greater than than -oo }
                            Result:=lNode.GetCopy()
                          else if (TRealConstNode(lNode2).ValueReal = MathInf.Value) then
                            { Nothing is greater than +oo }
                            Result:=CRealConstNode.Create(MathInf.Value,ResultDef);
                        end;
                    end;
                end;
              in_min_longint,
              in_min_int64:
                begin
                  if Left.NodeType=callparan then
                    begin
                      { Check to see if the result is deterministic }
                      lNode:=TCallParaNode(TCallParaNode(Left).NextPara).ParaValue;
                      lNode2:=TCallParaNode(Left).ParaValue;

                      if (lNode.NodeType=ordconstn) then
                        begin
                          if (lNode2.NodeType=ordconstn) then
                            begin
                              { Both actual parameters are constants, so take
                                the smaller of the two right now }
                              if InlineNumber=in_min_longint then
                                Result:=COrdConstNode.Create(min(LongInt(TOrdConstNode(lNode).Value.svalue),LongInt(TOrdConstNode(lNode2).Value.svalue)),ResultDef,false)
                              else
                                Result:=COrdConstNode.Create(min(TOrdConstNode(lNode).Value,TOrdConstNode(lNode2).Value),ResultDef,false);
                            end;

                          if IsMinMaxDeterministic(TOrdConstNode(lNode), False, lHelperResult) then
                            begin
                              if lHelperResult then
                                Result:=COrdConstNode.Create(TOrdConstNode(lNode).Value,ResultDef,false)
                              else
                                Result:=lNode2.GetCopy();
                            end;
                        end
                      else if (lNode2.NodeType=ordconstn) then
                        begin
                          if IsMinMaxDeterministic(TOrdConstNode(lNode2), False, lHelperResult) then
                            begin
                              if lHelperResult then
                                Result:=COrdConstNode.Create(TOrdConstNode(lNode2).Value,ResultDef,false)
                              else
                                Result:=lNode.GetCopy();
                            end;
                        end;
                    end;
                end;
              in_max_longint,
              in_max_int64:
                begin
                  if Left.NodeType=callparan then
                    begin
                      { Check to see if the result is deterministic }
                      lNode:=TCallParaNode(Left).ParaValue;
                      lNode2:=TCallParaNode(TCallParaNode(Left).NextPara).ParaValue;

                      if (lNode.NodeType=ordconstn) then
                        begin
                          if (lNode2.NodeType=ordconstn) then
                            begin
                              { Both actual parameters are constants, so take
                                the larger of the two right now }
                              if InlineNumber=in_max_longint then
                                Result:=COrdConstNode.Create(max(LongInt(TOrdConstNode(lNode).Value.svalue),LongInt(TOrdConstNode(lNode2).Value.svalue)),ResultDef,false)
                              else
                                Result:=COrdConstNode.Create(max(TOrdConstNode(lNode).Value,TOrdConstNode(lNode2).Value),ResultDef,false);
                            end;

                          if IsMinMaxDeterministic(TOrdConstNode(lNode), True, lHelperResult) then
                            begin
                              if lHelperResult then
                                Result:=COrdConstNode.Create(TOrdConstNode(lNode).Value,ResultDef,false)
                              else
                                Result:=lNode2.GetCopy();
                            end;
                        end
                      else if (lNode2.NodeType=ordconstn) then
                        begin
                          if IsMinMaxDeterministic(TOrdConstNode(lNode2), True, lHelperResult) then
                            begin
                              if lHelperResult then
                                Result:=COrdConstNode.Create(TOrdConstNode(lNode2).Value,ResultDef,false)
                              else
                                Result:=lNode.GetCopy();
                            end;
                        end;
                    end;
                end;
              in_min_dword,
              in_min_qword:
                begin
                  if Left.NodeType=callparan then
                    begin
                      { Check to see if the result is deterministic }
                      lNode:=TCallParaNode(TCallParaNode(Left).NextPara).ParaValue;
                      lNode2:=TCallParaNode(Left).ParaValue;

                      if (lNode.NodeType=ordconstn) then
                        begin
                          if (lNode2.NodeType=ordconstn) then
                            begin
                              { Both actual parameters are constants, so take
                                the smaller of the two right now }
                              if InlineNumber=in_min_dword then
                                Result:=COrdConstNode.Create(min(DWord(TOrdConstNode(lNode).Value.uvalue),DWord(TOrdConstNode(lNode2).Value.uvalue)),ResultDef,false)
                              else
                                Result:=COrdConstNode.Create(min(TOrdConstNode(lNode).Value,TOrdConstNode(lNode2).Value),ResultDef,false);
                            end;

                          if IsMinMaxDeterministic(TOrdConstNode(lNode), False, lHelperResult) then
                            begin
                              if lHelperResult then
                                Result:=COrdConstNode.Create(TOrdConstNode(lNode).Value,ResultDef,false)
                              else
                                Result:=lNode2.GetCopy();
                            end;
                        end
                      else if (lNode2.NodeType=ordconstn) then
                        begin
                          if IsMinMaxDeterministic(TOrdConstNode(lNode2), False, lHelperResult) then
                            begin
                              if lHelperResult then
                                Result:=COrdConstNode.Create(TOrdConstNode(lNode2).Value,ResultDef,false)
                              else
                                Result:=lNode.GetCopy();
                            end;
                        end;
                    end;
                end;
              in_max_dword,
              in_max_qword:
                begin
                  if Left.NodeType=callparan then
                    begin
                      { Check to see if the result is deterministic }
                      lNode:=TCallParaNode(Left).ParaValue;
                      lNode2:=TCallParaNode(TCallParaNode(Left).NextPara).ParaValue;

                      if (lNode.NodeType=ordconstn) then
                        begin
                          if (lNode2.NodeType=ordconstn) then
                            begin
                              { Both actual parameters are constants, so take
                                the larger of the two right now }
                              if InlineNumber=in_max_dword then
                                Result:=COrdConstNode.Create(max(DWord(TOrdConstNode(lNode).Value.uvalue),DWord(TOrdConstNode(lNode2).Value.uvalue)),ResultDef,false)
                              else
                                Result:=COrdConstNode.Create(max(TOrdConstNode(lNode).Value,TOrdConstNode(lNode2).Value),ResultDef,false);
                            end;

                          if IsMinMaxDeterministic(TOrdConstNode(lNode), True, lHelperResult) then
                            begin
                              if lHelperResult then
                                Result:=COrdConstNode.Create(TOrdConstNode(lNode).Value,ResultDef,false)
                              else
                                Result:=lNode2.GetCopy();
                            end;
                        end
                      else if (lNode2.NodeType=ordconstn) then
                        begin
                          if IsMinMaxDeterministic(TOrdConstNode(lNode2), True, lHelperResult) then
                            begin
                              if lHelperResult then
                                Result:=COrdConstNode.Create(TOrdConstNode(lNode2).Value,ResultDef,false)
                              else
                                Result:=lNode.GetCopy();
                            end;
                        end;
                    end;
                end;
              else
                ;
            end;
          end;
      end;



    function TInlineNode.Pass_TypeCheck:TNode;

      type
        TFloatTypeSet = set of TFloatType;

      function RemoveFloatUpcasts(var ANode: TNode; const AFloatTypes: TFloatTypeSet): TDef;
        var
          lFloatNode: TNode;
        begin
          { System unit declares internal functions like this:
              function foo(x: valreal): valreal; [internproc: number];
            Calls to such functions are initially processed by callnode,
            which typechecks the arguments, possibly inserting conversion to valreal.
            To handle smaller types without excess precision, we need to remove
            these extra typecasts. }
          if not(cs_excessprecision in CurrentSettings.LocalSwitches) and
             (ANode.NodeType=typeconvn) and
             (TTypeConvNode(ANode).Left.ResultDef.typ=floatdef) and
             (ANode.Flags*[nf_explicit,nf_internal]=[]) and
             (TFloatDef(TTypeConvNode(ANode).Left.ResultDef).FloatType in (AFloatTypes*[S32Real,S64Real,s80real,sc80real])) then
            begin
              lFloatNode:=TTypeConvNode(ANode).Left;
              TTypeConvNode(ANode).Left:=nil;
              ANode.free;
              ANode:=lFloatNode;
              Result:=ANode.ResultDef;
            end
          else if (ANode.NodeType=typeconvn) and
             (ANode.Flags*[nf_explicit,nf_internal]=[]) and
             (TTypeConvNode(ANode).Left.ResultDef.typ=floatdef) and
             (TFloatDef(TTypeConvNode(ANode).Left.ResultDef).FloatType in (AFloatTypes*[s64currency,s64comp])) then
            begin
              lFloatNode:=TTypeConvNode(ANode).Left;
              TTypeConvNode(ANode).Left:=nil;
              ANode.free;
              ANode:=lFloatNode;
              if Is_Currency(ANode.ResultDef) then
                begin
                  if (nf_is_currency in ANode.Flags) and
                     (ANode.NodeType=slashn) and
                     (TAddNode(ANode).Right.NodeType=realconstn) and
                     (TRealConstNode(TAddNode(ANode).Right).ValueReal=10000.0) and
                     not(nf_is_currency in TAddNode(ANode).Left.Flags) then
                   begin
                     lFloatNode:=TAddNode(ANode).Left;
                     TAddNode(ANode).Left:=nil;
                     ANode.free;
                     ANode:=lFloatNode;
                   end;
                end;
              Result:=ANode.ResultDef;
            end
          { in case the system helper was declared with overloads for different types,
            keep those }
          else if (ANode.ResultDef.typ=floatdef) and
             (TFloatDef(ANode.ResultDef).FloatType in (AFloatTypes*[S32Real,S64Real,s80real,sc80real])) then
            Result:=ANode.ResultDef
          else
            begin
              { for variant parameters; the rest has been converted by the
                call node already }
              if not(ANode.NodeType in [ordconstn,realconstn]) then
                InsertTypeConv(ANode,PBestRealType^);
              Result:=ANode.ResultDef
            end;
        end;


      procedure HandlePackUnpack;
        var
          lSource, lTarget, lIndexNode: TCallParaNode;
          lUnpackedArrayDef, lPackedArrayDef: TArrayDef;
          lTempIndex: TConstExprInt;
        begin
          ResultDef:=VoidType;

          lUnpackedArrayDef := nil;
          lPackedArrayDef := nil;
          lSource := TCallParaNode(Left);
          if (InlineNumber = in_unpack_x_y_z) then
            begin
              lTarget := TCallParaNode(lSource.Right);
              lIndexNode := TCallParaNode(lTarget.Right);

              { source must be a packed array }
              if not Is_Packed_Array(lSource.Left.ResultDef) then
                CGMessagePos2(lSource.Left.FileInfo,type_e_got_expected_packed_array,'1',lSource.Left.ResultDef.TypeName)
              else
                lPackedArrayDef := TArrayDef(lSource.Left.ResultDef);
              { target can be any kind of array, as long as it's not packed }
              if (lTarget.Left.ResultDef.typ <> arraydef) or
                 Is_Packed_Array(lTarget.Left.ResultDef) then
                CGMessagePos2(lTarget.Left.FileInfo,type_e_got_expected_unpacked_array,'2',lTarget.Left.ResultDef.TypeName)
              else
                lUnpackedArrayDef := TArrayDef(lTarget.Left.ResultDef);
            end
          else
            begin
              lIndexNode := TCallParaNode(lSource.Right);
              lTarget := TCallParaNode(lIndexNode.Right);

              { source can be any kind of array, as long as it's not packed }
              if (lSource.Left.ResultDef.typ <> arraydef) or
                 Is_Packed_Array(lSource.Left.ResultDef) then
                CGMessagePos2(lSource.Left.FileInfo,type_e_got_expected_unpacked_array,'1',lSource.Left.ResultDef.TypeName)
              else
                lUnpackedArrayDef := TArrayDef(lSource.Left.ResultDef);
              { target must be a packed array }
              if not Is_Packed_Array(lTarget.Left.ResultDef) then
                CGMessagePos2(lTarget.Left.FileInfo,type_e_got_expected_packed_array,'3',lTarget.Left.ResultDef.TypeName)
              else
                lPackedArrayDef := TArrayDef(lTarget.Left.ResultDef);
            end;

          if Assigned(lUnpackedArrayDef) then
            begin
              { index must be compatible with the unpacked array's indextype }
              InsertTypeConv(lIndexNode.Left,lUnpackedArrayDef.RangeDef);

              { range check at compile time if possible }
              if Assigned(lPackedArrayDef) and
                 (lIndexNode.Left.NodeType = ordconstn) and
                 not Is_Special_Array(lUnpackedArrayDef) then
                begin
                  AdaptRange(lUnpackedArrayDef,TOrdConstNode(lIndexNode.Left).Value,false,false,cs_check_range in CurrentSettings.LocalSwitches);
                  lTempIndex := TOrdConstNode(lIndexNode.Left).Value + lPackedArrayDef.HighRange-lPackedArrayDef.LowRange;
                  AdaptRange(lUnpackedArrayDef,lTempIndex,false,false,cs_check_range in CurrentSettings.LocalSwitches);
                end;
            end;

          { source array is read and must be valid }
          set_varstate(lSource.Left,vs_read,[vsf_must_be_valid]);
          { target array is written }
          valid_for_assignment(lTarget.Left,true);
          set_varstate(lTarget.Left,vs_written,[]);
          { index in the unpacked array is read and must be valid }
          set_varstate(lIndexNode.Left,vs_read,[vsf_must_be_valid]);
          { if the size of the arrays is 0 (array of empty records), }
          { do nothing                                               }
          if (lSource.ResultDef.Size = 0) then
            Result:=CNothingNode.Create;
        end;


      function HandleObjCEncode: TNode;
        var
          lEncodedType: AnsiString;
          lErrorDef: TDef;
        begin
          lEncodedType:='';
          if not ObjCTryEncodeType(Left.ResultDef,lEncodedType,lErrorDef) then
            Message1(type_e_objc_type_unsupported,lErrorDef.TypeName);
          Result:=CStringConstNode.CreatePChar(PChar(lEncodedType),length(lEncodedType),nil);
        end;

      var
         lHighTree,
         lNode        : TNode;
         lTempNodePointer: PNode;
         lConvDef   : TDef;
      begin
        Result:=nil;
        { when handling writeln "left" contains no valid address }
        if Assigned(Left) then
          begin
            if Left.NodeType=callparan then
              TCallParaNode(Left).Get_ParaType
            else
              TypeCheckPass(Left);
          end;

        if not(inf_inlineconst in InlineNodeFlags) then
          begin
            case InlineNumber of
              in_lo_long,
              in_hi_long,
              in_lo_qword,
              in_hi_qword,
              in_lo_word,
              in_hi_word :
                begin
                  { give warning for incompatibility with Delphi }
                  if (InlineNumber in [in_lo_long,in_hi_long,in_lo_qword,in_hi_qword]) and
                     (m_delphi in CurrentSettings.ModeSwitches) then
                    CGMessage(type_w_maybe_wrong_hi_lo);
                  set_varstate(Left,vs_read,[vsf_must_be_valid]);
                  if not Is_Integer(Left.ResultDef) then
                    CGMessage1(type_e_integer_expr_expected,Left.ResultDef.TypeName);
                  case InlineNumber of
                    in_lo_word,
                    in_hi_word :
                      ResultDef:=U8IntType;
                    in_lo_long,
                    in_hi_long :
                      ResultDef:=U16IntType;
                    in_lo_qword,
                    in_hi_qword :
                      ResultDef:=U32IntType;
                    else
                      ;
                  end;
                end;

              in_sizeof_x:
                begin
                  { the constant evaluation of in_sizeof_x happens in pexpr where possible,
                    though for generics it can reach here as well }
                  set_varstate(Left,vs_read,[]);
                  if (Left.ResultDef.typ<>undefineddef) and
                      Assigned(CurrentProcInfo) and
                      ParaManager.Push_High_Param(vs_value,Left.ResultDef,CurrentProcInfo.procdef.ProcCallOption) then
                   begin
                     { this should be an open array or array of const, both of
                       which can only be simple load nodes of parameters }
                     if Left.NodeType<>loadn then
                       InternalError(2014120701);
                     lHighTree:=Load_High_Value_Node(TParaVarSym(TLoadNode(Left).SymTableEntry));
                     if Assigned(lHighTree) then
                      begin
                        lNode:=CAddNode.Create(addn,lHighTree,
                                         COrdConstNode.Create(1,SizeSIntType,false));
                        if (Left.ResultDef.typ=arraydef) then
                          if not Is_Packed_Array(TArrayDef(Left.ResultDef)) then
                            begin
                              if (TArrayDef(Left.ResultDef).EleSize<>1) then
                                lNode:=CAddNode.Create(muln,lNode,COrdConstNode.Create(TArrayDef(
                                  Left.ResultDef).EleSize,SizeSIntType,true));
                            end
                          else if (TArrayDef(Left.ResultDef).ElePackedBitSize <> 8) then
                            begin
                              { no packed open array support yet }
                              if (lNode.NodeType <> ordconstn) then
                                InternalError(2006081511);
                              lNode.free;
                              lNode := COrdConstNode.Create(Left.ResultDef.Size,SizeSIntType,true);
{
                              hp:=
                                 ctypeconvnode.create_explicit(sizesinttype,
                                   cmoddivnode.create(divn,
                                     caddnode.create(addn,
                                       caddnode.create(muln,hp,cordconstnode.create(tarraydef(
                                         left.resultdef).elepackedbitsize,s64inttype,true)),
                                       cordconstnode.create(a,s64inttype,true)),
                                     cordconstnode.create(8,s64inttype,true)),
                                   sizesinttype);
}
                            end;
                        Result:=lNode;
                      end;
                   end
                  else
                   ResultDef:=SizeSIntType;
                end;

              in_typeof_x:
                begin
                  TypeCheckPass(Left);
                  set_varstate(Left,vs_read,[]);
                  if (Left.ResultDef.typ=objectdef) and
                    not(oo_has_vmt in TObjectDef(Left.ResultDef).ObjectOptions) then
                      message(type_e_typeof_requires_vmt);
                  ResultDef:=VoidPointerType;
                end;

              in_ord_x:
                begin
                   set_varstate(Left,vs_read,[vsf_must_be_valid]);
                   case Left.ResultDef.typ of
                     orddef,
                     enumdef,
                     undefineddef :
                       ;
                     pointerdef :
                       begin
                         if not(m_mac in CurrentSettings.ModeSwitches) then
                           CGMessage1(type_e_ordinal_expr_expected,Left.ResultDef.TypeName);
                       end
                     else
                       CGMessage1(type_e_ordinal_expr_expected,Left.ResultDef.TypeName);
                   end;
                end;

             in_chr_byte:
               begin
                 set_varstate(Left,vs_read,[vsf_must_be_valid]);
               end;

              in_length_x:
                begin
                  if ((Left.ResultDef.typ=arraydef) and
                      (not Is_Special_Array(Left.ResultDef) or
                       Is_Open_Array(Left.ResultDef))) or
                     (Left.ResultDef.typ=orddef) then
                    set_varstate(Left,vs_read,[])
                  else
                    set_varstate(Left,vs_read,[vsf_must_be_valid]);

                  case Left.ResultDef.typ of
                    variantdef:
                      begin
                        InsertTypeConv(Left,GetAnsiStringDef);
                      end;

                    stringdef :
                      begin
                        { we don't need string convertions here,  }
                        { except if from widestring to ansistring }
                        { and vice versa (that can change the     }
                        { length)                                 }
                        if (Left.NodeType=typeconvn) and
                           (TTypeConvNode(Left).Left.ResultDef.typ=stringdef) and
                           not(Is_Wide_Or_Unicode_String(Left.ResultDef) xor
                               Is_Wide_Or_Unicode_String(TTypeConvNode(Left).Left.ResultDef)) then
                         begin
                           lNode:=TTypeConvNode(Left).Left;
                           TTypeConvNode(Left).Left:=nil;
                           Left.free;
                           Left:=lNode;
                         end;
                      end;
                    orddef :
                      begin
                        { will be handled in simplify }
                        if not Is_Char(Left.ResultDef) and
                           not Is_WideChar(Left.ResultDef) then
                          CGMessage(type_e_mismatch);
                      end;
                    pointerdef :
                      begin
                        if Is_PChar(Left.ResultDef) then
                         begin
                            lNode := CCallParaNode.Create(Left,nil);
                            Result := CCallNode.CreateIntern('fpc_pchar_length',lNode);
                            { make sure the left node doesn't get disposed, since it's }
                            { reused in the new node (JM)                              }
                            Left:=nil;
                            exit;
                         end
                        else if Is_PWideChar(Left.ResultDef) then
                         begin
                            lNode := CCallParaNode.Create(Left,nil);
                            Result := CCallNode.CreateIntern('fpc_pwidechar_length',lNode);
                            { make sure the left node doesn't get disposed, since it's }
                            { reused in the new node (JM)                              }
                            Left:=nil;
                            exit;
                         end
                        else
                         CGMessage(type_e_mismatch);
                      end;
                    arraydef :
                      begin
                        if Is_Open_Array(Left.ResultDef) or
                           Is_Array_Of_Const(Left.ResultDef) then
                         begin
                           lHighTree:=Load_High_Value_Node(TParaVarSym(TLoadNode(Left).SymTableEntry));
                           if Assigned(lHighTree) then
                             Result:=CAddNode.Create(addn,lHighTree,
                               COrdConstNode.Create(1,SIntType,false));
                           exit;
                         end
                        { Length() for dynamic arrays is inlined }
                        else
                          begin
                            { will be handled in simplify }
                          end;
                      end;
                    undefineddef :
                      begin
                        if not (df_generic in CurrentProcInfo.procdef.DefOptions) then
                          CGMessage(type_e_mismatch);
                        { otherwise nothing }
                      end;
                    else
                      CGMessage(type_e_mismatch);
                  end;

                  { shortstring return an 8 bit value as the length
                    is the first byte of the string }
                  if Is_ShortString(Left.ResultDef) then
                    ResultDef:=U8IntType
                  else
                    ResultDef:=SizeSIntType;
                end;

              in_typeinfo_x:
                begin
                   if (Left.ResultDef.typ=enumdef) and
                      (TEnumDef(Left.ResultDef).HasJumps) and
                      (
                        (Left.NodeType<>typen) or
                        not (sp_generic_para in TTypeNode(Left).TypeSym.SymOptions)
                      ) then
                     CGMessage(type_e_no_type_info);
                   set_varstate(Left,vs_read,[vsf_must_be_valid]);
                   ResultDef:=VoidPointerType;
                end;

              in_gettypekind_x:
                begin
                  set_varstate(Left,vs_read,[vsf_must_be_valid]);
                  ResultDef:=TypeKindType;
                end;

              in_ismanagedtype_x:
                begin
                  set_varstate(Left,vs_read,[vsf_must_be_valid]);
                  ResultDef:=PasBool1Type;
                end;

              in_isconstvalue_x:
                begin
                  set_varstate(Left,vs_read,[vsf_must_be_valid]);
                  ResultDef:=PasBool1Type;
                end;

              in_assigned_x:
                begin
                  { the parser has already made sure the expression is valid }

                  { in case of a complex procvar, only check the "code" pointer }
                  if (TCallParaNode(Left).Left.ResultDef.typ=procvardef) and
                     not TProcVarDef(TCallParaNode(Left).Left.ResultDef).Is_AddressOnly then
                    begin
                      InsertTypeConv_Explicit(TCallParaNode(Left).Left,Search_System_Type('TMETHOD').TypeDef);
                      TCallParaNode(Left).Left:=CSubscriptNode.Create(TSym(TAbstractRecordDef(TCallParaNode(Left).Left.ResultDef).SymTable.find('CODE')),TCallParaNode(Left).Left);
                      TCallParaNode(Left).Get_ParaType;
                    end;

                  { Postpone conversion into addnode until firstpass, so targets
                    may override first_assigned and insert specific code. }
                  set_varstate(TCallParaNode(Left).Left,vs_read,[vsf_must_be_valid]);
                  ResultDef:=PasBool1Type;
                end;

              in_ofs_x :
                InternalError(2000101001);

              in_seg_x :
                begin
                  Result := TypeCheck_Seg;
                end;

              in_pred_x,
              in_succ_x:
                begin
                   set_varstate(Left,vs_read,[vsf_must_be_valid]);
                   ResultDef:=Left.ResultDef;
                   if Is_Ordinal(ResultDef) or Is_TypeParam(ResultDef) then
                     begin
                       if (ResultDef.typ=enumdef) and
                          (TEnumDef(ResultDef).HasJumps) and
                          not(m_delphi in CurrentSettings.ModeSwitches) and
                          not(nf_internal in Flags) then
                         CGMessage(type_e_succ_and_pred_enums_with_assign_not_possible);
                     end
                   else
                     CGMessage(type_e_ordinal_expr_expected)
                end;

              in_copy_x:
                Result:=HandleCopy;

              in_initialize_x,
              in_finalize_x:
                begin
                  { inlined from pinline }
                  InternalError(200204231);
                end;
              in_setlength_x:
                begin
                  Result:=HandleSetLength;
                end;
              in_inc_x,
              in_dec_x:
                begin
                  ResultDef:=VoidType;
                  if not(df_generic in CurrentProcInfo.procdef.DefOptions) then
                    begin
                      if Assigned(Left) then
                        begin
                           { first param must be var }
                           valid_for_var(TCallParaNode(Left).Left,true);
                           set_varstate(TCallParaNode(Left).Left,vs_readwritten,[vsf_must_be_valid]);

                           if (Left.ResultDef.typ in [enumdef,pointerdef]) or
                              Is_Ordinal(Left.ResultDef) or
                              Is_Currency(Left.ResultDef) then
                            begin
                              { value of left gets changed -> must be unique }
                              set_unique(TCallParaNode(Left).Left);
                              { two paras ? }
                              if Assigned(TCallParaNode(Left).Right) then
                               begin
                                 if Is_Integer(TCallParaNode(Left).Right.ResultDef) then
                                   begin
                                     set_varstate(TCallParaNode(TCallParaNode(Left).Right).Left,vs_read,[vsf_must_be_valid]);
                                     { when range/overflow checking is on, we
                                       convert this to a regular add, and for proper
                                       checking we need the original type }
                                     if ([cs_check_range,cs_check_overflow]*CurrentSettings.LocalSwitches=[]) then
                                       if (TCallParaNode(Left).Left.ResultDef.typ=pointerdef) then
                                         begin
                                           { don't convert values added to pointers into the pointer types themselves,
                                             because that will turn signed values into unsigned ones, which then
                                             goes wrong when they have to be multiplied with the size of the elements
                                             to which the pointer points in ncginl (mantis #17342) }
                                           if Is_Signed(TCallParaNode(TCallParaNode(Left).Right).Left.ResultDef) then
                                             InsertTypeConv(TCallParaNode(TCallParaNode(Left).Right).Left,TPointerDef(TCallParaNode(Left).Left.ResultDef).Pointer_Arithmetic_Int_Type)
                                           else
                                             InsertTypeConv(TCallParaNode(TCallParaNode(Left).Right).Left,TPointerDef(TCallParaNode(Left).Left.ResultDef).Pointer_Arithmetic_UInt_Type)
                                         end
                                       else if Is_Integer(TCallParaNode(Left).Left.ResultDef) then
                                         InsertTypeConv(TCallParaNode(TCallParaNode(Left).Right).Left,TCallParaNode(Left).Left.ResultDef)
                                       else
                                         InsertTypeConv_Internal(TCallParaNode(TCallParaNode(Left).Right).Left,TCallParaNode(Left).Left.ResultDef);
                                     if Assigned(TCallParaNode(TCallParaNode(Left).Right).Right) then
                                       { should be handled in the parser (JM) }
                                       InternalError(2006020901);
                                   end
                                 else
                                   CGMessagePos(TCallParaNode(Left).Right.FileInfo,type_e_ordinal_expr_expected);
                               end;
                            end
                           { generic type parameter? }
                           else if Is_TypeParam(Left.ResultDef) then
                             begin
                               Result:=CNothingNode.Create;
                               exit;
                             end
                           else
                             begin
                               lNode:=Self;
                               if isunaryoverloaded(lNode,[]) then
                                 begin
                                   { inc(rec) and dec(rec) assigns result value to argument }
                                   Result:=CAssignmentNode.Create(TCallParaNode(Left).Left.GetCopy,lNode);
                                   exit;
                                 end
                               else
                                 CGMessagePos(Left.FileInfo,type_e_ordinal_expr_expected);
                             end;
                        end
                      else
                        CGMessagePos(FileInfo,type_e_mismatch);
                    end;
                end;

              in_and_assign_x_y,
              in_or_assign_x_y,
              in_xor_assign_x_y,
              in_sar_assign_x_y,
              in_shl_assign_x_y,
              in_shr_assign_x_y,
              in_rol_assign_x_y,
              in_ror_assign_x_y:
                begin
                  ResultDef:=VoidType;
                  if not(df_generic in CurrentProcInfo.procdef.DefOptions) then
                    begin
                      { first parameter must exist }
                      if not Assigned(Left) or (Left.NodeType<>callparan) then
                        InternalError(2017032501);
                      { second parameter must exist }
                      if not Assigned(TCallParaNode(Left).Right) or (TCallParaNode(Left).Right.NodeType<>callparan) then
                        InternalError(2017032502);
                      { third parameter must NOT exist }
                      if Assigned(TCallParaNode(TCallParaNode(Left).Right).Right) then
                        InternalError(2017032503);

                      valid_for_var(TCallParaNode(TCallParaNode(Left).Right).Left,true);
                      set_varstate(TCallParaNode(TCallParaNode(Left).Right).Left,vs_readwritten,[vsf_must_be_valid]);

                      if Is_Integer(TCallParaNode(Left).Right.ResultDef) then
                        begin
                          { value of right gets changed -> must be unique }
                          set_unique(TCallParaNode(TCallParaNode(Left).Right).Left);
                          if Is_Integer(Left.ResultDef) then
                            begin
                              set_varstate(TCallParaNode(Left).Left,vs_read,[vsf_must_be_valid]);
                              { these nodes shouldn't be created, when range checking is on }
                              if [cs_check_range,cs_check_overflow]*LocalSwitches<>[] then
                                InternalError(2017032701);
                              if InlineNumber in [in_sar_assign_x_y,in_shl_assign_x_y,in_shr_assign_x_y,in_rol_assign_x_y,in_ror_assign_x_y] then
                                InsertTypeConv(TCallParaNode(Left).Left,SIntType)
                              else
                                InsertTypeConv(TCallParaNode(Left).Left,TCallParaNode(TCallParaNode(Left).Right).Left.ResultDef);
                            end
                          else
                            CGMessagePos(Left.FileInfo,type_e_ordinal_expr_expected);
                        end
                      { generic type parameter? }
                      else if Is_TypeParam(TCallParaNode(Left).Right.ResultDef) then
                        begin
                          Result:=CNothingNode.Create;
                          exit;
                        end
                      else
                        CGMessagePos(TCallParaNode(Left).Right.FileInfo,type_e_ordinal_expr_expected);
                    end;
                end;

              in_neg_assign_x,
              in_not_assign_x:
                begin
                  ResultDef:=VoidType;
                  if not(df_generic in CurrentProcInfo.procdef.DefOptions) then
                    begin
                      valid_for_var(Left,true);
                      set_varstate(Left,vs_readwritten,[vsf_must_be_valid]);

                      if Is_Integer(Left.ResultDef) then
                        begin
                          { value of left gets changed -> must be unique }
                          set_unique(Left);
                          { these nodes shouldn't be created, when range checking is on }
                          if [cs_check_range,cs_check_overflow]*CurrentSettings.LocalSwitches<>[] then
                            InternalError(2017040703);
                        end
                      { generic type parameter? }
                      else if Is_TypeParam(Left.ResultDef) then
                        begin
                          Result:=CNothingNode.Create;
                          exit;
                        end
                      else
                        CGMessagePos(Left.FileInfo,type_e_ordinal_expr_expected);
                    end;
                end;

              in_read_x,
              in_readln_x,
              in_readstr_x,
              in_write_x,
              in_writeln_x,
              in_writestr_x :
                begin
                  Result := HandleReadWrite;
                end;

              in_settextbuf_file_x :
                begin
                  ResultDef:=VoidType;
                  { now we know the type of buffer }
                  lNode:=CCallParaNode.Create(COrdConstNode.Create(
                     TCallParaNode(Left).Left.ResultDef.Size,S32IntType,true),Left);
                  Result:=CCallNode.CreateIntern('SETTEXTBUF',lNode);
                  Left:=nil;
                end;

              { the firstpass of the arg has been done in firstcalln ? }
              in_reset_typedfile,
              in_rewrite_typedfile,
              in_reset_typedfile_name,
              in_rewrite_typedfile_name :
                begin
                  Result := HandleResetRewriteTyped;
                end;

              in_str_x_string :
                begin
                  Result:=HandleStr;
                end;

              in_val_x :
                begin
                  Result:=HandleVal;
                end;

              in_include_x_y,
              in_exclude_x_y:
                begin
                  ResultDef:=VoidType;
                  { the parser already checks whether we have two (and exactly two) }
                  { parameters (JM)                                                 }
                  { first param must be var }
                  valid_for_var(TCallParaNode(Left).Left,true);
                  set_varstate(TCallParaNode(Left).Left,vs_readwritten,[vsf_must_be_valid]);
                  { check type }
                  if (Left.ResultDef.typ=setdef) then
                    begin
                      { insert a type conversion       }
                      { to the type of the set elements  }
                      set_varstate(TCallParaNode(TCallParaNode(Left).Right).Left,vs_read,[vsf_must_be_valid]);
                      InsertTypeConv(TCallParaNode(TCallParaNode(Left).Right).Left,
                        TSetDef(Left.ResultDef).ElementDef);
                    end
                  else if Left.ResultDef.typ<>undefineddef then
                    CGMessage(type_e_mismatch);
                end;
              in_pack_x_y_z,
              in_unpack_x_y_z :
                begin
                  HandlePackUnpack;
                end;

              in_slice_x:
                begin
                  Result:=nil;
                  ResultDef:=TCallParaNode(Left).Left.ResultDef;
                  if (ResultDef.typ <> arraydef) then
                    CGMessagePos(Left.FileInfo,type_e_mismatch)
                  else if Is_Packed_Array(ResultDef) then
                    CGMessagePos2(Left.FileInfo,type_e_got_expected_unpacked_array,'1',ResultDef.TypeName);
                  if not(Is_Integer(TCallParaNode(TCallParaNode(Left).Right).Left.ResultDef)) then
                    CGMessagePos1(TCallParaNode(Left).Right.FileInfo,
                      type_e_integer_expr_expected,
                      TCallParaNode(TCallParaNode(Left).Right).Left.ResultDef.TypeName);
                end;

              in_new_x:
                ResultDef:=Left.ResultDef;

              in_low_x,
              in_high_x:
                begin
                  case Left.ResultDef.typ of
                    undefineddef,
                    orddef,
                    enumdef,
                    setdef:
                      ;
                    arraydef:
                      begin
                        if (InlineNumber=in_low_x) then
                          set_varstate(Left,vs_read,[])
                        else
                         begin
                           if Is_Open_Array(Left.ResultDef) or
                              Is_Array_Of_Const(Left.ResultDef) then
                            begin
                              set_varstate(Left,vs_read,[]);
                              Result:=Load_High_Value_Node(TParaVarSym(TLoadNode(Left).SymTableEntry));
                            end
                           else
                             begin
                               set_varstate(Left,vs_read,[]);
                               ResultDef:=SizeSIntType;
                             end;
                         end;
                      end;
                    stringdef:
                      begin
                        if InlineNumber=in_low_x then
                         begin
                           set_varstate(Left,vs_read,[]);
                         end
                        else
                         begin
                           if Is_Open_String(Left.ResultDef) then
                            begin
                              set_varstate(Left,vs_read,[]);
                              Result:=Load_High_Value_Node(TParaVarSym(TLoadNode(Left).SymTableEntry))
                            end
                           else if Is_DynamicString(Left.ResultDef) then
                              begin
                                Result:=CInlineNode.Create(in_length_x,false,Left);
                                if cs_zerobasedstrings in CurrentSettings.LocalSwitches then
                                  Result:=CAddNode.Create(subn,Result,COrdConstNode.Create(1,SIntType,false));
                                { make sure the left node doesn't get disposed, since it's }
                                { reused in the new node (JM)                              }
                                Left:=nil;
                              end
                         end;
                     end;
                    else
                      CGMessage(type_e_mismatch);
                  end;
                end;

              in_exp_real,
              in_frac_real,
              in_int_real,
              in_cos_real,
              in_sin_real,
              in_arctan_real,
              in_ln_real :
                begin
                  { on the Z80, the double result is returned in a var param, because
                    it's too big to fit in registers. In that case we have 2 parameters
                    and left.nodetype is a callparan. }
                  if Left.NodeType = callparan then
                    lTempNodePointer := @TCallParaNode(Left).Left
                  else
                    lTempNodePointer := @Left;
                  set_varstate(lTempNodePointer^,vs_read,[vsf_must_be_valid]);
                  { converting an int64 to double on platforms without }
                  { extended can cause precision loss                  }
                  if not(lTempNodePointer^.NodeType in [ordconstn,realconstn]) then
                    InsertTypeConv(lTempNodePointer^,PBestRealType^);
                  ResultDef:=PBestRealType^;
                end;

              in_trunc_real,
              in_round_real :
                begin
                  { on i8086, the int64 result is returned in a var param, because
                    it's too big to fit in a register or a pair of registers. In
                    that case we have 2 parameters and left.nodetype is a callparan. }
                  if Left.NodeType=callparan then
                    lTempNodePointer:=@TCallParaNode(Left).Left
                  else
                    lTempNodePointer:=@Left;
                  set_varstate(lTempNodePointer^,vs_read,[vsf_must_be_valid]);
                  { on platforms where comp and currency are "type int64", this is
                    handled via inlined system helpers (-> no need for special
                    handling of s64currency/s64comp for them) }
                  if InlineNumber=in_trunc_real then
                    RemoveFloatUpcasts(lTempNodePointer^,[S32Real,S64Real,s80real,sc80real,s64currency,s64comp])
                  else
                    RemoveFloatUpcasts(lTempNodePointer^,[S32Real,S64Real,s80real,sc80real,s64comp]);
                  if (InlineNumber=in_trunc_real) and
                     Is_Currency(lTempNodePointer^.ResultDef) and
                     (nf_is_currency in lTempNodePointer^.Flags) then
                    begin
                      Result:=CModDivNode.Create(divn,CTypeConvNode.Create_Internal(lTempNodePointer^.GetCopy,S64IntType),GenIntConstNode(10000));
                      exit;
                    end
                  else if Is_FPUComp(lTempNodePointer^.ResultDef) then
                    begin
                      Result:=CTypeConvNode.Create_Internal(lTempNodePointer^.GetCopy,S64IntType);
                      exit;
                    end;
                  ResultDef:=S64IntType;
                end;

              in_pi_real :
                begin
                  ResultDef:=PBestRealType^;
                end;

              in_abs_long:
                begin
                  set_varstate(Left,vs_read,[vsf_must_be_valid]);
                  ResultDef:=Left.ResultDef;
                end;

              in_abs_real,
              in_sqr_real,
              in_sqrt_real :
                begin
                  { on the Z80, the double result is returned in a var param, because
                    it's too big to fit in registers. In that case we have 2 parameters
                    and left.nodetype is a callparan. }
                  if Left.NodeType = callparan then
                    lTempNodePointer := @TCallParaNode(Left).Left
                  else
                    lTempNodePointer := @Left;
                  set_varstate(lTempNodePointer^,vs_read,[vsf_must_be_valid]);
                  ResultDef:=RemoveFloatUpcasts(lTempNodePointer^,[S32Real,S64Real,s80real,sc80real]);
                end;

              in_aligned_x,
              in_unaligned_x:
                begin
                  ResultDef:=Left.ResultDef;
                end;
              in_volatile_x:
                begin
                  ResultDef:=Left.ResultDef;
                  { volatile only makes sense if the value is in memory }
                  make_not_regable(Left,[ra_addr_regable]);
                end;
              in_assert_x_y :
                begin
                  ResultDef:=VoidType;
                  if Assigned(Left) then
                    begin
                      set_varstate(TCallParaNode(Left).Left,vs_read,[vsf_must_be_valid]);
                      { check type }
                      if Is_Boolean(Left.ResultDef) or
                          (
                            (Left.ResultDef.typ=undefineddef) and
                            (df_generic in CurrentProcInfo.procdef.DefOptions)
                          ) then
                        begin
                           set_varstate(TCallParaNode(TCallParaNode(Left).Right).Left,vs_read,[vsf_must_be_valid]);
                           { must always be a string }
                           InsertTypeConv(TCallParaNode(TCallParaNode(Left).Right).Left,CShortStringType);
                         end
                       else
                         CGMessage1(type_e_boolean_expr_expected,Left.ResultDef.TypeName);
                    end
                  else
                    CGMessage(type_e_mismatch);

                  if (cs_do_assertion in CurrentSettings.LocalSwitches) then
                    include(CurrentProcInfo.Flags,pi_do_call);
                end;
              in_prefetch_var:
                ResultDef:=VoidType;
              in_get_frame,
              in_get_caller_frame,
              in_get_caller_addr:
                begin
                  ResultDef:=VoidPointerType;
                end;
              in_rol_x,
              in_ror_x,
              in_sar_x:
                begin
                  set_varstate(Left,vs_read,[vsf_must_be_valid]);
                  ResultDef:=Left.ResultDef;
                end;
              in_rol_x_y,
              in_ror_x_y,
              in_sar_x_y:
                begin
                  set_varstate(TCallParaNode(Left).Left,vs_read,[vsf_must_be_valid]);
                  set_varstate(TCallParaNode(TCallParaNode(Left).Right).Left,vs_read,[vsf_must_be_valid]);
                  ResultDef:=TCallParaNode(TCallParaNode(Left).Right).Left.ResultDef;
                end;
              in_bsf_x,
              in_bsr_x:
                 begin
                   set_varstate(Left,vs_read,[vsf_must_be_valid]);
                   if not Is_Integer(Left.ResultDef) then
                     CGMessage1(type_e_integer_expr_expected,Left.ResultDef.TypeName);
                   if TOrdDef(Left.ResultDef).OrdType in [u64bit, s64bit] then
                     ResultDef:=U64IntType
                   else
                     ResultDef:=U32IntType
                 end;

              in_popcnt_x:
                 begin
                   set_varstate(Left,vs_read,[vsf_must_be_valid]);
                   if not Is_Integer(Left.ResultDef) then
                     CGMessage1(type_e_integer_expr_expected,Left.ResultDef.TypeName);
                   ResultDef:=Left.ResultDef;
                 end;

              in_objc_selector_x:
                begin
                  Result:=CObjCSelectorNode.Create(Left);
                  { reused }
                  Left:=nil;
                end;
              in_objc_protocol_x:
                begin
                  Result:=CObjCProtocolNode.Create(Left);
                  { reused }
                  Left:=nil;
                end;
              in_objc_encode_x:
                begin
                  Result:=HandleObjCEncode;
                end;
              in_default_x:
                begin
                  Result:=HandleDefault;
                end;
              in_box_x:
                begin
                  Result:=HandleBox;
                end;
              in_unbox_x_y:
                begin
                  Result:=HandleUnbox;
                end;
              in_fma_single,
              in_fma_double,
              in_fma_extended:
                begin
                  set_varstate(TCallParaNode(Left).Left,vs_read,[vsf_must_be_valid]);
                  set_varstate(TCallParaNode(TCallParaNode(Left).Right).Left,vs_read,[vsf_must_be_valid]);
                  set_varstate(TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Left,vs_read,[vsf_must_be_valid]);
                  ResultDef:=TCallParaNode(Left).Left.ResultDef;
                end;
              in_max_longint,
              in_max_dword,
              in_min_longint,
              in_min_dword,
              in_max_int64,
              in_max_qword,
              in_min_int64,
              in_min_qword,
              in_max_single,
              in_max_double,
              in_min_single,
              in_min_double:
                begin
                  set_varstate(TCallParaNode(Left).Left,vs_read,[vsf_must_be_valid]);
                  set_varstate(TCallParaNode(TCallParaNode(Left).Right).Left,vs_read,[vsf_must_be_valid]);
                  ResultDef:=TCallParaNode(Left).Left.ResultDef;
                end;
              in_delete_x_y_z:
                begin
                  Result:=HandleDelete;
                end;
              in_insert_x_y_z:
                begin
                  Result:=HandleInsert;
                end;
              in_concat_x:
                begin
                  Result:=HandleConcat;
                end;
              in_atomic_dec,
              in_atomic_inc,
              in_atomic_xchg,
              in_atomic_cmp_xchg:
                begin
                  { first parameter must exist for all }
                  if not Assigned(Left) or (Left.NodeType<>callparan) then
                    InternalError(2022093001);
                  { second parameter must exist for xchg and cmp_xchg }
                  if (InlineNumber=in_atomic_xchg) or (InlineNumber=in_atomic_cmp_xchg) then
                    begin
                      if not Assigned(TCallParaNode(Left).Right) or (TCallParaNode(Left).Right.NodeType<>callparan) then
                        InternalError(2022093002);
                      if InlineNumber=in_atomic_cmp_xchg then
                        begin
                          { third parameter must exist }
                          if not Assigned(TCallParaNode(TCallParaNode(Left).Right).Right) or (TCallParaNode(TCallParaNode(Left).Right).Right.NodeType<>callparan) then
                            InternalError(2022093004);
                          { fourth parameter may exist }
                          if Assigned(TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Right) then
                            begin
                              if TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Right.NodeType<>callparan then
                                InternalError(2022093005);
                              { fifth parameter must NOT exist }
                              if Assigned(TCallParaNode(TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Right).Right) then
                                InternalError(2022093006);
                            end;
                        end
                      { third parameter must NOT exist }
                      else if Assigned(TCallParaNode(TCallParaNode(Left).Right).Right) then
                        InternalError(2022093003);
                    end
                  else if Assigned(TCallParaNode(Left).Right) then
                    begin
                      { if the second parameter exists, it must be a callparan }
                      if TCallParaNode(Left).Right.NodeType<>callparan then
                        InternalError(2022093004);
                      { a third parameter must not exist }
                      if Assigned(TCallParaNode(TCallParaNode(Left).Right).Right) then
                        InternalError(2022093005);
                    end;

                  valid_for_var(TCallParaNode(Left).Left,true);
                  set_varstate(TCallParaNode(Left).Left,vs_readwritten,[vsf_must_be_valid]);

                  if Is_Integer(TCallParaNode(Left).ResultDef) or Is_Pointer(TCallParaNode(Left).ResultDef) then
                    begin
                      if not Is_Pointer(TCallParaNode(Left).ResultDef) then
                        begin
                          ResultDef:=Get_Signed_IntType(TCallParaNode(Left).Left.ResultDef);
                          lConvDef:=ResultDef;
                        end
                      else
                        begin
                          { pointer is only allowed for Exchange and CmpExchange }
                          if (InlineNumber<>in_atomic_xchg) and (InlineNumber<>in_atomic_cmp_xchg) then
                            CGMessagePos(FileInfo,type_e_ordinal_expr_expected);
                          ResultDef:=VoidPointerType;
                          lConvDef:=PtrSIntType;
                        end;
                      { left gets changed -> must be unique }
                      set_unique(TCallParaNode(Left).Left);
                      InsertTypeConv_Internal(TCallParaNode(Left).Left,lConvDef);
                      if Assigned(TCallParaNode(Left).Right) then
                        begin
                          InsertTypeConv(TCallParaNode(TCallParaNode(Left).Right).Left,ResultDef);
                          if ResultDef<>lConvDef then
                            InsertTypeConv_Internal(TCallParaNode(TCallParaNode(Left).Right).Left,lConvDef);
                          if Assigned(TCallParaNode(TCallParaNode(Left).Right).Right) then
                            begin
                              InsertTypeConv(TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Left,ResultDef);
                              if ResultDef<>lConvDef then
                                InsertTypeConv_Internal(TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Left,lConvDef);
                              if Assigned(TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Right) then
                                begin
                                  { the boolean parameter must be assignable }
                                  valid_for_var(TCallParaNode(TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Right).Left,true);
                                  set_varstate(TCallParaNode(TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Right).Left,vs_written,[]);
                                  if not Is_Boolean(TCallParaNode(TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Right).Left.ResultDef) then
                                    InsertTypeConv(TCallParaNode(TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Right).Left,PasBool1Type);
                                end;
                            end;
                        end;
                    end
                  else if Is_TypeParam(TCallParaNode(Left).Left.ResultDef) then
                    begin
                      ResultDef:=TCallParaNode(Left).Left.ResultDef;
                    end
                  else if (InlineNumber=in_atomic_xchg) or (InlineNumber=in_atomic_cmp_xchg) then
                    CGMessagePos(TCallParaNode(Left).Left.FileInfo,type_e_ordinal_or_pointer_expr_expected)
                  else
                    CGMessagePos(TCallParaNode(Left).Left.FileInfo,type_e_ordinal_expr_expected);
                end;
              else
                Result:=Pass_TypeCheck_CPU;
            end;
          end;

        if not Assigned(Result) and not
           CodeGenError then
          Result:=Simplify(false);
      end;


    function TInlineNode.Pass_TypeCheck_CPU : TNode;
      begin
        Result:=nil;

        Message1(cg_f_unknown_internal_procedure_number,ToStr(ord(InlineNumber)));
      end;


    function TInlineNode.Pass_1 : TNode;
      var
         lNode: TNode;
         lShiftConst: LongInt;
         lObjectDef: TObjectDef;
         lSym : TSym;
         lDef: TDef;

      begin
         Result:=nil;
         { if we handle writeln; left contains no valid address }
         if Assigned(Left) then
           begin
              if Left.NodeType=callparan then
                TCallParaNode(Left).FirstCallParaN
              else
                FirstPass(Left);
           end;

         { intern const should already be handled }
         if inf_inlineconst in InlineNodeFlags then
          InternalError(200104044);
         case InlineNumber of
          in_lo_qword,
          in_hi_qword,
          in_lo_long,
          in_hi_long,
          in_lo_word,
          in_hi_word:
            begin
              lShiftConst := 0;
              case InlineNumber of
                in_hi_qword:
                  lShiftConst := 32;
                in_hi_long:
                  lShiftConst := 16;
                in_hi_word:
                  lShiftConst := 8;
                else
                  ;
              end;
              if lShiftConst <> 0 then
                Result := CTypeConvNode.Create_Internal(CShlShrNode.Create(shrn,Left,
                    COrdConstNode.Create(lShiftConst,SIntType,false)),ResultDef)
              else
                Result := CTypeConvNode.Create_Internal(Left,ResultDef);
              Left := nil;
              FirstPass(Result);
            end;

          in_sizeof_x,
          in_typeof_x:
            begin
              ExpectLoc:=LOC_REGISTER;
              case Left.ResultDef.typ of
                objectdef,classrefdef:
                  begin
                    if Left.ResultDef.typ=objectdef then
                      begin
                        Result:=CLoadVMTAddrNode.Create(Left);
                        lObjectDef:=TObjectDef(Left.ResultDef);
                      end
                    else
                      begin
                        Result:=Left;
                        lObjectDef:=TObjectDef(TClassRefDef(Left.ResultDef).PointedDef);
                      end;
                    Left:=nil;
                    if InlineNumber=in_sizeof_x then
                      begin
                        InsertTypeConv_Explicit(Result,CPointerDef.getreusable(lObjectDef.VMT_Def));
                        Result:=CDerefNode.Create(Result);
                        Result:=GenLoadField(Result,'VINSTANCESIZE');
                      end
                    else
                      InsertTypeConv_Explicit(Result,VoidPointerType);
                  end;
                undefineddef:
                  ;
                else
                  InternalError(2015122702);
              end;
            end;

          in_length_x:
            begin
               Result:=First_Length;
            end;

          in_typeinfo_x:
            begin
              if (Left.ResultDef.typ=enumdef) and
                 (TEnumDef(Left.ResultDef).HasJumps) then
                begin
                  if (Left.NodeType=typen) and (sp_generic_para in TTypeNode(Left).TypeSym.SymOptions) then
                    Result:=CNilNode.Create
                  else
                    InternalError(2021032601);
                end
              else
                Result:=CAddrNode.Create_Internal(
                  CRTTINode.Create(TStoredDef(Left.ResultDef),fullrtti,rdt_normal)
                );
            end;

          in_gettypekind_x:
            begin
              lSym:=TEnumDef(TypeKindType).Int2EnumSym(Get_TypeKind(Left.ResultDef));
              if not Assigned(lSym) then
                InternalError(2017081101);
              if lSym.typ<>enumsym then
                InternalError(2017081102);
              Result:=GenEnumNode(TEnumSym(lSym));
            end;

          in_ismanagedtype_x:
            begin
              if Left.ResultDef.NeedsInitTable then
                Result:=COrdConstNode.Create(1,ResultDef,false)
              else
                Result:=COrdConstNode.Create(0,ResultDef,false);
            end;

          in_isconstvalue_x:
            begin
              if Is_ConstNode(Left) then
                Result:=COrdConstNode.Create(1,ResultDef,false)
              else
                Result:=COrdConstNode.Create(0,ResultDef,false);
            end;

          in_assigned_x:
            begin
              Result:=First_Assigned;
            end;

          in_pred_x,
          in_succ_x:
            begin
              ExpectLoc:=LOC_REGISTER;
              { in case of range/overflow checking, use a regular addnode
                because it's too complex to handle correctly otherwise }

              if (([cs_check_overflow,cs_check_range]*CurrentSettings.LocalSwitches)<>[]) and not(nf_internal in Flags) then
                begin
                  { create constant 1, ensure the data type is large enough }
                  Range_To_Type(
                    min(1,Get_Min_Value(Left.ResultDef)),
                    max(1,Get_Max_Value(Left.ResultDef)),lDef);
                  lNode:=COrdConstNode.Create(1,lDef,false);
                  TypeCheckPass(lNode);
                  if not Is_Integer(lNode.ResultDef) then
                    InsertTypeConv_Internal(lNode,SIntType);

                  { avoid type errors from the addn/subn }
                  if not Is_Integer(Left.ResultDef) then
                    InsertTypeConv_Internal(Left,SIntType);

                  { addition/subtraction depending on succ/pred }
                  if InlineNumber=in_succ_x then
                    lNode:=CAddNode.Create(addn,Left,lNode)
                  else
                    lNode:=CAddNode.Create(subn,Left,lNode);


                  if nf_internal in Flags then
                    include(lNode.Flags,nf_internal);

                  { assign result of addition }
                  if not(Is_Integer(ResultDef)) then
                    InsertTypeConv(lNode,COrdDef.Create(
{$ifdef cpu64bitaddr}
                      s64bit,
{$else cpu64bitaddr}
                      s32bit,
{$endif cpu64bitaddr}
                      Get_Min_Value(ResultDef),
                      Get_Max_Value(ResultDef),
                      true))
                  else
                    InsertTypeConv(lNode,ResultDef);

                  if nf_internal in Flags then
                    include(lNode.Flags,nf_internal);

                  { avoid any possible errors/warnings }
                  InsertTypeConv_Internal(lNode,ResultDef);

                  { firstpass it }
                  FirstPass(lNode);

                  { left is reused }
                  Left:=nil;

                  { return new node }
                  Result:=lNode;
                end;
            end;

          in_setlength_x:
            Result:=First_SetLength;
          in_copy_x:
            Result:=First_Copy;
          in_initialize_x,
          in_finalize_x:
            begin
              ExpectLoc:=LOC_VOID;
            end;

          in_inc_x,
          in_dec_x:
            begin
              Result:=First_IncDec;
            end;

          in_and_assign_x_y,
          in_or_assign_x_y,
          in_xor_assign_x_y,
          in_sar_assign_x_y,
          in_shl_assign_x_y,
          in_shr_assign_x_y,
          in_rol_assign_x_y,
          in_ror_assign_x_y:
            begin
              Result:=First_AndOrXorShiftRot_Assign;
            end;

          in_neg_assign_x,
          in_not_assign_x:
            begin
              Result:=First_NegNot_Assign;
            end;

         in_include_x_y,
         in_exclude_x_y:
           begin
              Result:=First_IncludeExclude;
           end;

         in_pack_x_y_z,
         in_unpack_x_y_z:
           begin
             Result:=First_Pack_Unpack;
           end;

         in_exp_real:
           begin
             Result:= First_Exp_Real;
           end;

         in_round_real:
           begin
             Result:= First_Round_Real;
           end;

         in_trunc_real:
           begin
             Result:= First_Trunc_Real;
           end;

         in_int_real:
           begin
             Result:= First_Int_Real;
           end;

         in_frac_real:
           begin
             Result:= First_Frac_Real;
           end;

         in_cos_real:
           begin
             Result:= First_Cos_Real;
           end;

         in_sin_real:
           begin
             Result := First_Sin_Real;
           end;

         in_arctan_real:
           begin
             Result := First_ArcTan_Real;
           end;

         in_pi_real :
           begin
             Result := First_Pi;
           end;

         in_abs_real:
           begin
             Result := First_Abs_Real;
           end;

         in_abs_long:
           begin
             Result := First_Abs_Long;
           end;

         in_sqr_real:
           begin
             Result := First_Sqr_Real;
           end;

         in_sqrt_real:
           begin
             Result := First_Sqrt_Real;
           end;

         in_ln_real:
           begin
             Result := First_Ln_Real;
           end;


         in_assert_x_y :
            begin
              Result:=First_Assert;
            end;

          in_low_x:
            InternalError(200104047);
          in_high_x:
            begin
              Result:=First_High;
            end;

          in_slice_x:
            { slice can be used only in calls for open array parameters, so it has to be converted appropriately before
              if we get here, the array could not be passed to an open array parameter so it is an error }
            CGMessagePos(Left.FileInfo,type_e_mismatch);

          in_ord_x,
          in_chr_byte:
            begin
               { should not happened as it's converted to typeconv }
               InternalError(200104045);
            end;

          in_ofs_x :
            InternalError(2000101002);

          in_seg_x :
            begin
              Result:=First_Seg;
            end;

          in_settextbuf_file_x,
          in_reset_typedfile,
          in_rewrite_typedfile,
          in_reset_typedfile_name,
          in_rewrite_typedfile_name,
          in_str_x_string,
          in_val_x,
          in_read_x,
          in_readln_x,
          in_write_x,
          in_writeln_x :
            begin
              { should be handled by pass_typecheck }
              InternalError(2001082302);
            end;
         in_get_frame:
            begin
              Result:=First_Get_Frame;
            end;
         in_get_caller_frame:
            begin
              ExpectLoc:=LOC_REGISTER;
            end;
         in_get_caller_addr:
            begin
              ExpectLoc:=LOC_REGISTER;
            end;
         in_prefetch_var:
           begin
             ExpectLoc:=LOC_VOID;
           end;
         in_aligned_x,
         in_unaligned_x,
         in_volatile_x:
           begin
             ExpectLoc:=TCallParaNode(Left).Left.ExpectLoc;
           end;
         in_rol_x,
         in_rol_x_y,
         in_ror_x,
         in_ror_x_y:
           ExpectLoc:=LOC_REGISTER;
         in_bsf_x,
         in_bsr_x:
           Result:=First_BitScan;
         in_sar_x,
         in_sar_x_y:
           Result:=First_SAR;
         in_popcnt_x:
           Result:=First_PopCnt;
         in_new_x:
           Result:=First_New;
         in_box_x:
           Result:=First_Box;
         in_unbox_x_y:
           Result:=First_Unbox;
         in_fma_single,
         in_fma_double,
         in_fma_extended:
           Result:=First_FMA;
         in_max_longint,
         in_max_dword,
         in_min_longint,
         in_min_dword,
         in_max_int64,
         in_max_qword,
         in_min_int64,
         in_min_qword,
         in_min_single,
         in_min_double,
         in_max_single,
         in_max_double:
           Result:=First_MinMax;
         in_atomic_inc,
         in_atomic_dec,
         in_atomic_xchg,
         in_atomic_cmp_xchg:
           Result:=First_Atomic;
         else
           Result:=First_CPU;
          end;
       end;
{$maxfpuregisters default}

    function TInlineNode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare :=
          inherited DoCompare(ANode) and
          (InlineNumber = TInlineNode(ANode).InlineNumber);
      end;


    procedure TInlineNode.Mark_Write;
      begin
        case InlineNumber of
	  in_aligned_x, in_unaligned_x:
           TCallParaNode(Left).Left.Mark_Write;
        else
          inherited Mark_Write;
        end;
      end;

    function TInlineNode.First_Pi : TNode;
      begin
        Result:=CRealConstNode.Create(Pi,PBestRealType^);
      end;


     function TInlineNode.First_ArcTan_Real : TNode;
      var
        lTempNodePointer: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if Left.NodeType = callparan then
          lTempNodePointer := @TCallParaNode(Left).Left
        else
          lTempNodePointer := @Left;
        Result := CCallNode.CreateIntern('fpc_arctan_real',
                CCallParaNode.Create(lTempNodePointer^,nil));
        lTempNodePointer^ := nil;
      end;

     function TInlineNode.First_Abs_Real : TNode;
      var
         lCallNode : TCallNode;
         lTempNodePointer: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if Left.NodeType = callparan then
          lTempNodePointer := @TCallParaNode(Left).Left
        else
          lTempNodePointer := @Left;
        lCallNode:=CCallNode.CreateIntern('fpc_abs_real',
                    CCallParaNode.Create(lTempNodePointer^,nil));
        Result := CTypeConvNode.Create(lCallNode,ResultDef);
        include(lCallNode.CallNodeFlags,cnf_check_fpu_exceptions);
        lTempNodePointer^ := nil;
      end;

     function TInlineNode.First_Sqr_Real : TNode;
      begin
        { All retained CPUs implement this in their CPU-specific inline node. }
        InternalError(2011092401);
        Result:=nil;
      end;

     function TInlineNode.First_Sqrt_Real : TNode;
      var
        lCallNode: TCallNode;
        lTempNodePointer: PNode;
      begin
        if Left.NodeType = callparan then
          lTempNodePointer := @TCallParaNode(Left).Left
        else
          lTempNodePointer := @Left;
        { create the call to the helper }
        { on entry left node contains the parameter }
        lCallNode := CCallNode.CreateIntern('fpc_sqrt_real',
            CCallParaNode.Create(lTempNodePointer^,nil));
        Result := CTypeConvNode.Create(lCallNode,ResultDef);
        include(lCallNode.CallNodeFlags,cnf_check_fpu_exceptions);
        lTempNodePointer^ := nil;
      end;

     function TInlineNode.First_Ln_Real : TNode;
      var
        lTempNodePointer: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if Left.NodeType = callparan then
          lTempNodePointer := @TCallParaNode(Left).Left
        else
          lTempNodePointer := @Left;
        Result := CCallNode.CreateIntern('fpc_ln_real',
                CCallParaNode.Create(lTempNodePointer^,nil));
        include(TCallNode(Result).CallNodeFlags,cnf_check_fpu_exceptions);
        lTempNodePointer^ := nil;
      end;

     function TInlineNode.First_Cos_Real : TNode;
      var
        lTempNodePointer: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if Left.NodeType = callparan then
          lTempNodePointer := @TCallParaNode(Left).Left
        else
          lTempNodePointer := @Left;
        Result := CCallNode.CreateIntern('fpc_cos_real',
                CCallParaNode.Create(lTempNodePointer^,nil));
        include(TCallNode(Result).CallNodeFlags,cnf_check_fpu_exceptions);
        lTempNodePointer^ := nil;
      end;

     function TInlineNode.First_Sin_Real : TNode;
      var
        lTempNodePointer: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if Left.NodeType = callparan then
          lTempNodePointer := @TCallParaNode(Left).Left
        else
          lTempNodePointer := @Left;
        Result := CCallNode.CreateIntern('fpc_sin_real',
                CCallParaNode.Create(lTempNodePointer^,nil));
        include(TCallNode(Result).CallNodeFlags,cnf_check_fpu_exceptions);
        lTempNodePointer^ := nil;
      end;

     function TInlineNode.First_Exp_Real : TNode;
      var
        lTempNodePointer: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if Left.NodeType = callparan then
          lTempNodePointer := @TCallParaNode(Left).Left
        else
          lTempNodePointer := @Left;
        Result := CCallNode.CreateIntern('fpc_exp_real',CCallParaNode.Create(lTempNodePointer^,nil));
        include(TCallNode(Result).CallNodeFlags,cnf_check_fpu_exceptions);
        lTempNodePointer^ := nil;
      end;

     function TInlineNode.First_Int_Real : TNode;
      var
        lTempNodePointer: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if Left.NodeType = callparan then
          lTempNodePointer := @TCallParaNode(Left).Left
        else
          lTempNodePointer := @Left;
        Result := CCallNode.CreateIntern('fpc_int_real',CCallParaNode.Create(lTempNodePointer^,nil));
        include(TCallNode(Result).CallNodeFlags,cnf_check_fpu_exceptions);
        lTempNodePointer^ := nil;
      end;

     function TInlineNode.First_Frac_Real : TNode;
      var
        lTempNodePointer: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if Left.NodeType = callparan then
          lTempNodePointer := @TCallParaNode(Left).Left
        else
          lTempNodePointer := @Left;
        Result := CCallNode.CreateIntern('fpc_frac_real',CCallParaNode.Create(lTempNodePointer^,nil));
        include(TCallNode(Result).CallNodeFlags,cnf_check_fpu_exceptions);
        lTempNodePointer^ := nil;
      end;

     function TInlineNode.First_Round_Real : TNode;
      var
        lTempNodePointer: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if Left.NodeType = callparan then
          lTempNodePointer := @TCallParaNode(Left).Left
        else
          lTempNodePointer := @Left;
        Result := CCallNode.CreateIntern('fpc_round_real',CCallParaNode.Create(lTempNodePointer^,nil));
        include(TCallNode(Result).CallNodeFlags,cnf_check_fpu_exceptions);
        lTempNodePointer^ := nil;
      end;

     function TInlineNode.First_Trunc_Real : TNode;
      var
        lTempNodePointer: PNode;
      begin
        { create the call to the helper }
        { on entry left node contains the parameter }
        if Left.NodeType = callparan then
          lTempNodePointer := @TCallParaNode(Left).Left
        else
          lTempNodePointer := @Left;
        Result := CCallNode.CreateIntern('fpc_trunc_real',CCallParaNode.Create(lTempNodePointer^,nil));
        include(TCallNode(Result).CallNodeFlags,cnf_check_fpu_exceptions);
        lTempNodePointer^ := nil;
      end;


     function TInlineNode.First_Abs_Long : TNode;
      begin
        ExpectLoc:=LOC_REGISTER;
        Result:=nil;
      end;


     function TInlineNode.GetAddSub_For_IncDec : TNode;
       var
         lNode,lParaNode,lResultNode  : TNode;
         lTempNode: TTempCreateNode;
         lNewStatement: TStatementNode;
         lNewBlock: TBlockNode;
         lDef: TDef;
       begin
         lNewBlock := InternalStatements(lNewStatement);
         { extra parameter? }
         if Assigned(TCallParaNode(Left).Right) then
           begin
             { Yes, use for add node }
             lParaNode := TCallParaNode(TCallParaNode(Left).Right).Left;
             TCallParaNode(TCallParaNode(Left).Right).Left := nil;
             if Assigned(TCallParaNode(TCallParaNode(Left).Right).Right) then
               { A syntax error should have already been raised }
               InternalError(2025050601);
           end
         else
           begin
             { no, create constant 1, ensure the data type is large enough }
             Range_To_Type(
               min(1,Get_Min_Value(TCallParaNode(Left).Left.ResultDef)),
               max(1,Get_Max_Value(TCallParaNode(Left).Left.ResultDef)),lDef);
             lParaNode:=COrdConstNode.Create(1,lDef,false)
           end;
         TypeCheckPass(lParaNode);

         { make sure we don't call functions part of the left node twice (and generally }
         { optimize the code generation)                                                }
         { Storing address is not always an optimization: alignment of left is not known
           at this point, so we must assume the worst and use an unaligned pointer.
           This results in larger and slower code on alignment-sensitive targets.
           Therefore the complexity condition below is questionable, maybe just filtering
           out calls with "= NODE_COMPLEXITY_INF" is sufficient.
           Value of 3 corresponds to subscript nodes, i.e. record field. }
         if Node_Complexity(TCallParaNode(Left).Left) > 3 then
           begin
             lTempNode := CTempCreateNode.Create(VoidPointerType,VoidPointerType.Size,tt_persistent,true);
             AddStatement(lNewStatement,lTempNode);
             AddStatement(lNewStatement,CAssignmentNode.Create(CTempRefNode.Create(lTempNode),
               CAddrNode.Create_Internal(TCallParaNode(Left).Left.GetCopy)));
             lNode := CDerefNode.Create(CTempRefNode.Create(lTempNode));
             InsertTypeConv_Internal(lNode,TCallParaNode(Left).Left.ResultDef);
           end
         else
           begin
             lNode := TCallParaNode(Left).Left.GetCopy;
             lTempNode := nil;
           end;

         lResultNode := lNode.GetCopy;
         { Remove "modify" flag from what will be an assignment destination }
         Exclude(lResultNode.Flags, nf_modify);

         { avoid type errors from the addn/subn }
         if not Is_Integer(lResultNode.ResultDef) then
           begin
             InsertTypeConv_Internal(lNode,SIntType);
             InsertTypeConv_Internal(lParaNode,SIntType);
           end;

         { addition/subtraction depending on inc/dec }
         if InlineNumber = in_inc_x then
           lParaNode := CAddNode.Create_Internal(addn,lNode,lParaNode)
         else
           lParaNode := CAddNode.Create_Internal(subn,lNode,lParaNode);

         { assign result of addition }

         { inherit internal flag }
         if not(Is_Integer(lResultNode.ResultDef)) then
           begin
             if nf_internal in Flags then
               InsertTypeConv_Internal(lParaNode,COrdDef.Create(
{$ifdef cpu64bitaddr}
                 s64bit,
{$else cpu64bitaddr}
                 s32bit,
{$endif cpu64bitaddr}
                 Get_Min_Value(lResultNode.ResultDef),
                 Get_Max_Value(lResultNode.ResultDef),
                 true))
             else
               InsertTypeConv(lParaNode,COrdDef.Create(
{$ifdef cpu64bitaddr}
                 s64bit,
{$else cpu64bitaddr}
                 s32bit,
{$endif cpu64bitaddr}
                 Get_Min_Value(lResultNode.ResultDef),
                 Get_Max_Value(lResultNode.ResultDef),
                 true))
           end
         else
           begin
             if nf_internal in Flags then
               InsertTypeConv_Internal(lParaNode,lResultNode.ResultDef)
             else
               InsertTypeConv(lParaNode,lResultNode.ResultDef);
           end;

         { avoid any possible warnings }
         InsertTypeConv_Internal(lParaNode,lResultNode.ResultDef);

         { force pass 1, so copied trees get first pass'ed as well and flags like
           nf_call_unique get set right }
         Node_Reset_Pass1_Write(lParaNode);
         DoTypeCheckPass(lParaNode);

         AddStatement(lNewStatement,CAssignmentNode.Create(lResultNode,lParaNode));

         { firstpass it }
         FirstPass(TNode(lNewStatement.Left));

         { deallocate the temp }
         if Assigned(lTempNode) then
           AddStatement(lNewStatement,CTempDeleteNode.Create(lTempNode));
         { firstpass it }
         FirstPass(TNode(lNewBlock));
         { return new node }
         Result := lNewBlock;
       end;


     function TInlineNode.First_IncDec: TNode;
       begin
         ExpectLoc:=LOC_VOID;
         Result:=nil;

         { range/overflow checking doesn't work properly }
         { with the inc/dec code that's generated (JM)   }
         if ((LocalSwitches * [cs_check_overflow,cs_check_range] <> []) and
           { No overflow check for pointer operations, because inc(pointer,-1) will always
             trigger an overflow. For uint32 it works because then the operation is done
             in 64bit. Range checking is not applicable to pointers either }
             (TCallParaNode(Left).Left.ResultDef.typ<>pointerdef))
            then
             { convert to simple add (JM) }
             Result:=GetAddSub_For_IncDec
       end;


     function TInlineNode.First_IncludeExclude: TNode;
       begin
         Result:=nil;
         ExpectLoc:=LOC_VOID;
       end;


     function TInlineNode.First_Get_Frame: TNode;
       begin
         include(CurrentProcInfo.Flags,pi_needs_stackframe);
         include(CurrentProcInfo.Flags,pi_uses_get_frame);
         ExpectLoc:=LOC_CREGISTER;
         Result:=nil;
       end;


     function TInlineNode.First_SetLength: TNode;
      var
        lParas   : TNode;
        lNewPara,
        lPara     : TCallParaNode;
        lDimensions,
        lCounter : Integer;
        lIsArray : Boolean;
        lDestPara : TNode;
        lNewStatement : TStatementNode;
        lTempNode    : TTempCreateNode;
        lNewBlock : TNode;
      begin
        lParas:=Left;
        lPara:=TCallParaNode(lParas);
        lDimensions:=0;
        while Assigned(lPara.Right) do
          begin
            inc(lDimensions);
            lPara:=TCallParaNode(lPara.Right);
          end;

        lDestPara:=lPara.Left;
        lIsArray:=Is_Dynamic_Array(lDestPara.ResultDef);
        { first param must be a string or dynamic array ...}
        if lIsArray then
         begin
           { SetLength(Arr, 0), Arr := nil, Arr := [] }
           if (lDimensions=1) and Is_ConstIntValue(TCallParaNode(lParas).Left, 0) then
             begin
               lPara.Left:=nil; { unlink destppn }
               Result:=CCallParaNode.Create(CTypeConvNode.Create_Internal(lDestPara,VoidPointerType),nil);
               Result:=CCallNode.CreateIntern('fpc_dynarray_clear',
                 CCallParaNode.Create(CAddrNode.Create_Internal(
                   CRTTINode.Create(TStoredDef(lDestPara.ResultDef),initrtti,rdt_normal)),
                 Result));
               exit;
             end;
           { create statements with call initialize the arguments and
             call fpc_dynarr_setlength }
           lNewBlock:=InternalStatements(lNewStatement);

           { get temp for array of lengths }
           lTempNode:=CTempCreateNode.Create(CArrayDef.getreusable(SIntType,lDimensions),lDimensions*SIntType.Size,tt_persistent,false);
           AddStatement(lNewStatement,lTempNode);

           { load array of lengths }
           lPara:=TCallParaNode(lParas);
           lCounter:=lDimensions-1;
           while Assigned(lPara.Right) do
             begin
               AddStatement(lNewStatement,CAssignmentNode.Create(
                   CVecNode.Create(
                     CTempRefNode.Create(lTempNode),
                     GenIntConstNode(lCounter)
                   ),
                   lPara.Left));
               lPara.Left:=nil;
               dec(lCounter);
               lPara:=TCallParaNode(lPara.Right);
             end;
           { destppn is also reused }
           lPara.Left:=nil;

           { create call to fpc_dynarr_setlength }
           lNewPara:=CCallParaNode.Create(CAddrNode.Create_Internal(
                     CVecNode.Create(
                       CTempRefNode.Create(lTempNode),
                       GenIntConstNode(0)
                     )),
                  CCallParaNode.Create(COrdConstNode.Create
                     (lDimensions,SIntType,true),
                  CCallParaNode.Create(CAddrNode.Create_Internal
                     (CRTTINode.Create(TStoredDef(lDestPara.ResultDef),initrtti,rdt_normal)),
                  CCallParaNode.Create(CTypeConvNode.Create_Internal(lDestPara,VoidPointerType),nil))));
           AddStatement(lNewStatement,CCallNode.CreateIntern('fpc_dynarray_setlength',lNewPara));
           AddStatement(lNewStatement,CTempDeleteNode.Create(lTempNode));
         end
        else if Is_AnsiString(lDestPara.ResultDef) then
         begin
            lNewBlock:=CCallNode.CreateIntern(
              'fpc_'+TStringDef(lDestPara.ResultDef).StringTypName+'_setlength',
              CCallParaNode.Create(
                COrdConstNode.Create(GetParaEncoding(lDestPara.ResultDef),U16IntType,true),
                lParas
              )
            );
            { we reused the parameters, make sure we don't release them }
            Left:=nil;
         end
        else
         begin
           { we can reuse the supplied parameters }
           lNewBlock:=CCallNode.CreateIntern(
              'fpc_'+TStringDef(lDestPara.ResultDef).StringTypName+'_setlength',lParas);
           { we reused the parameters, make sure we don't release them }
           Left:=nil;
         end;
        Result:=lNewBlock;
      end;

    function TInlineNode.First_Copy: TNode;
      var
        lLowPara,
        lCountPara,
        lElementSizePara,
        lElementTypePara,
        lMaxCountPara,
        lArrayPara,
        lRTTIPara,
        lNewPara,
        lParas   : TNode;
        lPara     : TCallParaNode;
        lParaDef : TDef;
        lCounter : Integer;
      begin
        { determine copy function to use based on the first argument,
          also count the number of arguments in this loop }
        lCounter:=1;
        lParas:=Left;
        lPara:=TCallParaNode(lParas);
        while Assigned(lPara.Right) do
          begin
            inc(lCounter);
            lPara:=TCallParaNode(lPara.Right);
          end;
        lParaDef:=lPara.Left.ResultDef;

        { fill up third parameter }
        if lCounter=2 then
          begin
            lParas:=CCallParaNode.Create(COrdConstNode.Create(TOrdDef(SIntType).high,SIntType,false),lParas);
            lCounter:=3;
          end;

        if Is_AnsiString(ResultDef) then
          { keep the specific kind of ansistringdef as result }
          Result:=CCallNode.CreateInternRes('fpc_ansistr_copy',lParas,ResultDef)
        else if Is_WideString(ResultDef) then
          Result:=CCallNode.CreateIntern('fpc_widestr_copy',lParas)
        else if Is_UnicodeString(ResultDef) then
          Result:=CCallNode.CreateIntern('fpc_unicodestr_copy',lParas)
          { can't check for resultdef = cansichartype, because resultdef=
            cshortstringtype here }
        else if Is_Char(lParaDef) then
          Result:=CCallNode.CreateIntern('fpc_char_copy',lParas)
        else if Is_Dynamic_Array(ResultDef) then
          begin
            { create statements with call }
            lElementSizePara:=COrdConstNode.Create(TArrayDef(lParaDef).EleSize,SIntType,false);
            if Is_Managed_Type(TArrayDef(lParaDef).ElementDef) then
              lElementTypePara:=CAddrNode.Create_Internal(
                CRTTINode.Create(TStoredDef(TArrayDef(lParaDef).ElementDef),initrtti,rdt_normal))
            else
              lElementTypePara:=COrdConstNode.Create(0,VoidPointerType,false);
            lMaxCountPara:=GenInlineNode(in_length_x,false,lPara.Left.GetCopy);
            case lCounter of
              1:
                begin
                  { copy the whole array using [0..high(sizeint)] range }
                  lCountPara:=COrdConstNode.Create(TOrdDef(SIntType).high,SIntType,false);
                  lLowPara:=COrdConstNode.Create(0,SIntType,false);
                end;
              2:
                begin
                  { copy the array using [low..high(sizeint)] range }
                  lCountPara:=COrdConstNode.Create(TOrdDef(SIntType).high,SIntType,false);
                  lLowPara:=TCallParaNode(lParas).Left.GetCopy;
                end;
              3:
                begin
                  lCountPara:=TCallParaNode(lParas).Left.GetCopy;
                  lLowPara:=TCallParaNode(TCallParaNode(lParas).Right).Left.GetCopy;
                end;
              else
                InternalError(2012100703);
            end;

            if Is_Open_Array(lParaDef) then
              begin
                lArrayPara:=CAddrNode.Create_Internal(lPara.Left);
              end
            else if Is_Dynamic_Array(lParaDef) then
              begin
                lArrayPara:=CTypeConvNode.Create_Internal(lPara.Left,VoidPointerType);
              end
            else
              InternalError(2012100704);

            lRTTIPara:=CAddrNode.Create_Internal(CRTTINode.Create(TStoredDef(ResultDef),initrtti,rdt_normal));

            { create call to fpc_array_to_dynarray_copy }
            lNewPara:=CCallParaNode.Create(lElementTypePara,
                   CCallParaNode.Create(lElementSizePara,
                   CCallParaNode.Create(lMaxCountPara,
                   CCallParaNode.Create(lCountPara,
                   CCallParaNode.Create(lLowPara,
                   CCallParaNode.Create(lRTTIPara,
                   CCallParaNode.Create(lArrayPara,nil)))))));
            Result:=CCallNode.CreateInternRes('fpc_array_to_dynarray_copy',lNewPara,ResultDef);

            lPara.Left:=nil;
            lParas.free;
            lParas := nil;
          end
        else
          Result:=CCallNode.CreateIntern('fpc_shortstr_copy',lParas);
        { parameters are reused }
        Left:=nil;
     end;


     function TInlineNode.First_New: TNode;
       var
         lNewStatement : TStatementNode;
         lNewBlock     : TBlockNode;
         lTempNode         : TTempCreateNode;
         lPara         : TCallParaNode;
       begin
         { create statements with call to getmem+initialize }
         lNewBlock:=InternalStatements(lNewStatement);

         { create temp for result }
         lTempNode := CTempCreateNode.Create(Left.ResultDef,Left.ResultDef.Size,tt_persistent,true);
         AddStatement(lNewStatement,lTempNode);

         { create call to fpc_getmem }
         lPara := CCallParaNode.Create(COrdConstNode.Create
             (TPointerDef(Left.ResultDef).PointedDef.Size,S32IntType,true),nil);
         AddStatement(lNewStatement,CAssignmentNode.Create(
             CTempRefNode.Create(lTempNode),
             CCallNode.CreateIntern('fpc_getmem',lPara)));

         { create call to fpc_initialize }
         if Is_Managed_Type(TPointerDef(Left.ResultDef).PointedDef) then
          begin
            lPara := CCallParaNode.Create(CAddrNode.Create_Internal(CRTTINode.Create
                       (TStoredDef(TPointerDef(Left.ResultDef).PointedDef),initrtti,rdt_normal)),
                    CCallParaNode.Create(CTempRefNode.Create
                       (lTempNode),nil));
            AddStatement(lNewStatement,CCallNode.CreateIntern('fpc_initialize',lPara));
          end;

         { the last statement should return the value as
           location and type, this is done be referencing the
           temp and converting it first from a persistent temp to
           normal temp }
         AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lTempNode));
         AddStatement(lNewStatement,CTempRefNode.Create(lTempNode));
         Result:=lNewBlock;
       end;


     function TInlineNode.First_Length: TNode;
       begin
         Result:=nil;
         if Is_ShortString(Left.ResultDef) then
          ExpectLoc:=Left.ExpectLoc
         else
          begin
            { ansi/wide string }
            ExpectLoc:=LOC_REGISTER;
          end;
       end;


     function TInlineNode.First_High: TNode;
       begin
         Result:=nil;
         if not(Is_Dynamic_Array(Left.ResultDef)) then
           InternalError(2019122802);
         ExpectLoc:=LOC_REGISTER;
       end;


     function TInlineNode.First_Assigned: TNode;
       begin
         { Comparison must not call procvars, indicate that with nf_load_procvar flag }
         Result:=CAddNode.Create(unequaln,TCallParaNode(Left).Left,CNilNode.Create);
         include(Result.Flags,nf_load_procvar);
         TCallParaNode(Left).Left:=nil;
       end;


     function TInlineNode.First_Assert: TNode;
       var
         lParas: TCallParaNode;
       begin
         lParas:=TCallParaNode(TCallParaNode(Left).Right);
         lParas:=CCallParaNode.Create(CStringConstNode.CreateStr(CurrentModule.SourceFiles.Get_File_Name(CurrentFilePos.fileindex)),lParas);
         lParas:=CCallParaNode.Create(GenIntConstNode(FileInfo.line),lParas);
{$ifdef SUPPORT_GET_FRAME}
         lParas:=CCallParaNode.Create(GenInlineNode(in_get_frame,false,nil),lParas);
{$else}
         lParas:=CCallParaNode.Create(CCallNode.CreateInternFromUnit('SYSTEM','GET_FRAME',nil),lParas);
{$endif}
         Result:=CIfNode.Create(CNotNode.Create(TCallParaNode(Left).Left),
            CCallNode.CreateIntern('fpc_assert',lParas),nil);
         include(Result.Flags,nf_internal);
         TCallParaNode(Left).Left:=nil;
         TCallParaNode(Left).Right:=nil;
       end;


     function TInlineNode.First_PopCnt: TNode;
       var
         lSuffix : String;
       begin
         case TOrdDef(Left.ResultDef).OrdType of
           u8bit: lSuffix:='byte';
           u16bit: lSuffix:='word';
           u32bit: lSuffix:='dword';
           u64bit: lSuffix:='qword';
         else
           InternalError(2012082601);
         end;
         Result:=CCallNode.CreateIntern('fpc_popcnt_'+lSuffix,CCallParaNode.Create(Left,nil));
         Left:=nil;
       end;

     function TInlineNode.First_BitScan: TNode;
       begin
         Result:=nil;
         ExpectLoc:=LOC_REGISTER;
       end;


     function TInlineNode.TypeCheck_Seg: TNode;
       begin
         set_varstate(Left,vs_read,[]);
         Result:=COrdConstNode.Create(0,S32IntType,false);
       end;


     function TInlineNode.First_Seg: TNode;
       begin
         InternalError(200104046);
         Result:=nil;
       end;


     function TInlineNode.First_SAR: TNode;
       begin
         Result:=nil;
         ExpectLoc:=LOC_REGISTER;
{$if not defined(cpu64bitalu) and not defined(cpucg64shiftsupport)}
         if Is_64BitInt(ResultDef) then
           begin
             if (InlineNumber=in_sar_x) then
               Left:=CCallParaNode.Create(COrdConstNode.Create(1,U8IntType,false),
                 CCallParaNode.Create(Left,nil));
             Result:=CCallNode.CreateIntern('fpc_sarint64',Left);
             Left:=nil;
           end;
{$endif not defined(cpu64bitalu) and not defined(cpucg64shiftsupport)}
       end;


     function TInlineNode.HandleBox: TNode;
       begin
         Result:=nil;
         if not Assigned(Left) or
            Assigned(TCallParaNode(Left).Right) then
           CGMessage1(parser_e_wrong_parameter_size,'FpcInternalBox');
         ResultDef:=Class_TObject;
       end;


     function TInlineNode.HandleUnbox: TNode;
       begin
         Result:=nil;
         if not Assigned(Left) or
            not Assigned(TCallParaNode(Left).Right) or
            Assigned(TCallParaNode(TCallParaNode(Left).Right).Right) then
           CGMessage1(parser_e_wrong_parameter_size,'FpcInternalUnBox');
         if TCallParaNode(Left).Left.NodeType<>typen then
           InternalError(2011071701);
         TTypeNode(TCallParaNode(Left).Left).allowed:=true;
         ResultDef:=TCallParaNode(Left).Left.ResultDef;
       end;

     function TInlineNode.HandleInsert: TNode;

       procedure DoError;
         begin
           CGMessagePos1(FileInfo,parser_e_wrong_parameter_size,'Insert');
           Write_System_Parameter_Lists('fpc_shortstr_insert');
           Write_System_Parameter_Lists('fpc_shortstr_insert_char');
           Write_System_Parameter_Lists('fpc_unicodestr_insert');
           if tf_winlikewidestring in TargetInfo.Flags then
             Write_System_Parameter_Lists('fpc_widestr_insert');
           Write_System_Parameter_Lists('fpc_ansistr_insert');
           MessagePos1(FileInfo,sym_e_param_list,'Insert(Dynamic Array;var Dynamic Array;'+SIntType.TypeName+');');
           MessagePos1(FileInfo,sym_e_param_list,'Insert(Element;var Dynamic Array;'+SIntType.TypeName+');');
         end;

       var
         lProcName : String;
         lNewNode,
         lDataNode,
         lDataCountNode,
         lFirstNode,
         lSecondNode : TNode;
         lFirstDef,
         lSecondDef : TDef;
         lIsConstructor,
         lIsCompatibleArray,
         lIsCompatibleElement : Boolean;
         lDataTemp : TTempCreateNode;
         lInsertBlock : TBlockNode;
         lInsertStatement : TStatementNode;
       begin
         if not Assigned(Left) or
             not Assigned(TCallParaNode(Left).Right) or
             not Assigned(TCallParaNode(TCallParaNode(Left).Right).Right) or
             Assigned(TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Right) then
           begin
             DoError;
             exit(CErrorNode.Create);
           end;
         { determine the correct function based on the second parameter }
         lFirstNode:=TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Left;
         lFirstDef:=lFirstNode.ResultDef;
         lSecondNode:=TCallParaNode(TCallParaNode(Left).Right).Left;
         lSecondDef:=lSecondNode.ResultDef;
         if Is_ShortString(lSecondDef) then
           begin
             if Is_Char(lFirstDef) then
               lProcName:='fpc_shortstr_insert_char'
             else
               lProcName:='fpc_shortstr_insert';
           end
         else if Is_UnicodeString(lSecondDef) then
           lProcName:='fpc_unicodestr_insert'
         else if Is_WideString(lSecondDef) then
           lProcName:='fpc_widestr_insert'
         else if Is_AnsiString(lSecondDef) then
           lProcName:='fpc_ansistr_insert'
         else if Is_Dynamic_Array(lSecondDef) then
           begin
             { The first parameter needs to be
               a) a dynamic array of the same type
               b) a single element of the same type
               c) a static array of the same type (not Delphi compatible)
             }
             lIsConstructor:=Is_Array_Constructor(lFirstDef);
             lIsCompatibleArray:=(lFirstDef.typ=arraydef) and Equal_Defs(TArrayDef(lFirstDef).ElementDef,TArrayDef(lSecondDef).ElementDef);
             lIsCompatibleElement:=Compare_Defs(lFirstDef,TArrayDef(lSecondDef).ElementDef,niln)<>te_incompatible;
             if not lIsCompatibleArray
                 and not lIsCompatibleElement
                 and not lIsConstructor then
               begin
                 CGMessagePos(FileInfo,type_e_array_required);
                 exit(CErrorNode.Create);
               end;
             lInsertBlock:=InternalStatements(lInsertStatement);
             lDataTemp:=nil;
             if lIsCompatibleArray then
               begin
                 lDataTemp:=CTempCreateNode.Create_Value(lFirstDef,lFirstDef.Size,tt_normal,false,lFirstNode);
                 AddStatement(lInsertStatement,lDataTemp);
                 if Is_Dynamic_Array(lFirstDef) then
                   lDataNode:=CTypeConvNode.Create_Internal(CTempRefNode.Create(lDataTemp),VoidPointerType)
                 else
                   lDataNode:=CAddrNode.Create_Internal(CVecNode.Create(CTempRefNode.Create(lDataTemp),COrdConstNode.Create(0,SizeSIntType,false)));
                 lDataCountNode:=CInlineNode.Create(in_length_x,false,CTempRefNode.Create(lDataTemp));
               end
             else if lIsConstructor then
               begin
                 InsertTypeConv(lFirstNode,lSecondDef);
                 lDataTemp:=CTempCreateNode.Create_Value(lSecondDef,lSecondDef.Size,tt_normal,false,lFirstNode);
                 AddStatement(lInsertStatement,lDataTemp);
                 lDataNode:=CTypeConvNode.Create_Internal(CTempRefNode.Create(lDataTemp),VoidPointerType);
                 lDataCountNode:=CInlineNode.Create(in_length_x,false,CTempRefNode.Create(lDataTemp));
               end
             else
               begin
                 if Is_Const(lFirstNode) then
                   begin
                     lDataTemp:=CTempCreateNode.Create_Value(TArrayDef(lSecondDef).ElementDef,TArrayDef(lSecondDef).ElementDef.Size,tt_normal,false,lFirstNode);
                     AddStatement(lInsertStatement,lDataTemp);
                     lDataNode:=CAddrNode.Create_Internal(CTempRefNode.Create(lDataTemp));
                   end
                 else
                   begin
                     lDataNode:=lFirstNode;
                     InsertTypeConv(lDataNode,TArrayDef(lSecondDef).ElementDef);
                     lDataNode:=CAddrNode.Create_Internal(lDataNode);
                   end;
                 lDataCountNode:=COrdConstNode.Create(1,SizeSIntType,false);
               end;
             lProcName:='fpc_dynarray_insert';
             { recreate the parameters as array pointer, source, data, count, typeinfo }
             lNewNode:=CCallParaNode.Create(CAddrNode.Create_Internal(CRTTINode.Create(TStoredDef(lSecondDef),initrtti,rdt_normal)),
                     CCallParaNode.Create(lDataCountNode,
                       CCallParaNode.Create(lDataNode,
                         CCallParaNode.Create(TCallParaNode(Left).Left,
                           CCallParaNode.Create(CTypeConvNode.Create_Internal(lSecondNode,VoidPointerType),nil)))));
             AddStatement(lInsertStatement,CCallNode.CreateIntern(lProcName,lNewNode));
             if Assigned(lDataTemp) then
               AddStatement(lInsertStatement,CTempDeleteNode.Create(lDataTemp));
             TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Left:=nil; // insert idx
             TCallParaNode(TCallParaNode(Left).Right).Left:=nil; // dyn array
             TCallParaNode(Left).Left:=nil; // insert element/array
             Left.free;
             Left:=nil;
             Result:=lInsertBlock;
             exit; { ! }
           end
         else if lSecondDef.typ=undefineddef then
           { just pick one }
           lProcName:='fpc_ansistr_insert'
         else
           begin
             DoError;
             exit(CErrorNode.Create);
           end;
         Result:=CCallNode.CreateIntern(lProcName,Left);
         Left:=nil;
       end;

     function TInlineNode.HandleDelete: TNode;

       procedure DoError;
         begin
           CGMessagePos1(FileInfo,parser_e_wrong_parameter_size,'Delete');
           Write_System_Parameter_Lists('fpc_shortstr_delete');
           Write_System_Parameter_Lists('fpc_unicodestr_delete');
           if tf_winlikewidestring in TargetInfo.Flags then
             Write_System_Parameter_Lists('fpc_widestr_delete');
           Write_System_Parameter_Lists('fpc_ansistr_delete');
           MessagePos1(FileInfo,sym_e_param_list,'Delete(var Dynamic Array;'+SIntType.TypeName+';'+SIntType.TypeName+');');
         end;

       var
         lProcName : String;
         lFirstDef : TDef;
         lFirstNode,
         lNewNode : TNode;
       begin
         if not Assigned(Left) or
             not Assigned(TCallParaNode(Left).Right) or
             not Assigned(TCallParaNode(TCallParaNode(Left).Right).Right) or
             Assigned(TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Right) then
           begin
             DoError;
             exit(CErrorNode.Create);
           end;
         { determine the correct function based on the first parameter }
         lFirstNode:=TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Left;
         lFirstDef:=lFirstNode.ResultDef;
         if Is_ShortString(lFirstDef) then
           lProcName:='fpc_shortstr_delete'
         else if Is_UnicodeString(lFirstDef) then
           lProcName:='fpc_unicodestr_delete'
         else if Is_WideString(lFirstDef) then
           lProcName:='fpc_widestr_delete'
         else if Is_AnsiString(lFirstDef) then
           lProcName:='fpc_ansistr_delete'
         else if Is_Dynamic_Array(lFirstDef) then
           begin
             lProcName:='fpc_dynarray_delete';
             { recreate the parameters as array pointer, src, count, typeinfo }
             lNewNode:=CCallParaNode.Create(CAddrNode.Create_Internal
                  (CRTTINode.Create(TStoredDef(lFirstDef),initrtti,rdt_normal)),
                    CCallParaNode.Create(TCallParaNode(Left).Left,
                      CCallParaNode.Create(TCallParaNode(TCallParaNode(Left).Right).Left,
                        CCallParaNode.Create(CTypeConvNode.Create_Internal(lFirstNode,VoidPointerType),nil))));
             TCallParaNode(TCallParaNode(TCallParaNode(Left).Right).Right).Left:=nil;
             TCallParaNode(TCallParaNode(Left).Right).Left:=nil;
             TCallParaNode(Left).Left:=nil;
             Left.free;
             Left:=lNewNode;
           end
         else if lFirstDef.typ=undefineddef then
           { just pick one }
           lProcName:='fpc_ansistr_delete'
         else
           begin
             DoError;
             exit(CErrorNode.Create);
           end;
         Result:=CCallNode.CreateIntern(lProcName,Left);
         Left:=nil;
       end;


     function TInlineNode.HandleConcat:TNode;

       procedure DoError;
         begin
           CGMessagePos1(FileInfo,parser_e_wrong_parameter_size,'Concat');
           MessagePos1(FileInfo,sym_e_param_list,'Concat(String[;String;...])');
           MessagePos1(FileInfo,sym_e_param_list,'Concat(Dynamic Array[;Dynamic Array;...])');
         end;

       var
         lCallPara : TCallParaNode;
         lList : TFPObjectList;
         lNode,
         lArrayNode,
         lFirstNode : TNode;
         lIndex : LongInt;
         lArrayConstructor : TArrayConstructorNode;
         lNewStatement : TStatementNode;
         lTempNode : TTempCreateNode;
         lLastChanged : Boolean;
       begin
         if not Assigned(Left) then
           begin
             DoError;
             exit(CErrorNode.Create);
           end;
         Result:=nil;
         { the arguments are right to left, but we need to work on them from
           left to right, so insert them in a list and process that from back
           to front }
         lList:=TFPObjectList.Create(false);
         { remember the last (aka first) dynamic array parameter (important
           in case of array constructors) }
         lArrayNode:=nil;
         lCallPara:=TCallParaNode(Left);
         while Assigned(lCallPara) do
           begin
             lList.add(lCallPara.Left);
             if Is_Dynamic_Array(lCallPara.Left.ResultDef) then
               lArrayNode:=lCallPara.Left;
             lCallPara.Left:=nil;
             lCallPara:=TCallParaNode(lCallPara.Right);
           end;

         if lList.count=0 then
           InternalError(2017100901);

         lFirstNode:=TNode(lList.last);
         if not Assigned(lFirstNode) then
           InternalError(2017100902);

         { are we dealing with strings or dynamic arrays? }
         if Is_Dynamic_Array(lFirstNode.ResultDef) or Is_Array_Constructor(lFirstNode.ResultDef) then
           begin
             { try to combine all consecutive array constructors }
             lLastChanged:=false;
             lIndex:=0;
             repeat
               if lLastChanged or Is_Array_Constructor(TNode(lList[lIndex]).ResultDef) then
                 begin
                   if (lIndex<lList.count-1) and Is_Array_Constructor(TNode(lList[lIndex+1]).ResultDef) then
                     begin
                       lArrayConstructor:=TArrayConstructorNode(lList[lIndex+1]);
                       while Assigned(lArrayConstructor.Right) do
                         lArrayConstructor:=TArrayConstructorNode(lArrayConstructor.Right);
                       lArrayConstructor.Right:=TNode(lList[lIndex]);
                       lList[lIndex]:=lList[lIndex+1];
                       lList.delete(lIndex+1);
                       lLastChanged:=true;
                       TNode(lList[lIndex]).ResultDef:=nil;
                       { don't increase index! }
                       continue;
                     end;
                   if lLastChanged then
                     begin
                       { we concatenated all consecutive ones, so typecheck the new one again }
                       lNode:=TNode(lList[lIndex]);
                       TypeCheckPass(lNode);
                       lList[lIndex]:=lNode;
                     end;
                   lLastChanged:=false;
                 end;
               inc(lIndex);
             until lIndex=lList.count;

             if lList.count=1 then
               begin
                 { no need to call the concat helper }
                 Result:=lFirstNode;
               end
             else
               begin
                 { if we reach this point then the concat list didn't consist
                   solely of array constructors }
                 if not Assigned(lArrayNode) then
                   InternalError(2017101001);

                 Result:=InternalStatements(lNewStatement);

                 { generate the open array constructor for the source arrays
                   note: the order needs to be swapped again here! }
                 lArrayConstructor:=nil;
                 for lIndex:=0 to lList.count-1 do
                   begin
                     lNode:=TNode(lList[lIndex]);
                     { first convert to the target type }
                     if not Is_Array_Constructor(lNode.ResultDef) then
                       InsertTypeConv(lNode,lArrayNode.ResultDef);
                     { we need to ensure that we get a reference counted
                       assignment for the temp array }
                     lTempNode:=CTempCreateNode.Create(lArrayNode.ResultDef,lArrayNode.ResultDef.Size,tt_persistent,true);
                     AddStatement(lNewStatement,lTempNode);
                     AddStatement(lNewStatement,CAssignmentNode.Create(CTempRefNode.Create(lTempNode),lNode));
                     AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lTempNode));
                     lNode:=CTempRefNode.Create(lTempNode);
                     { then to a plain pointer for the helper }
                     InsertTypeConv_Internal(lNode,VoidPointerType);
                     lArrayConstructor:=CArrayConstructorNode.Create(lNode,lArrayConstructor);
                   end;
                 Include(lArrayConstructor.ArrayConstructorNodeFlags,acnf_allow_array_constructor);

                 { based on the code from nopt.genmultistringadd() }
                 lTempNode:=CTempCreateNode.Create(lArrayNode.ResultDef,lArrayNode.ResultDef.Size,tt_persistent,true);
                 AddStatement(lNewStatement,lTempNode);

                 lCallPara:=CCallParaNode.Create(
                         lArrayConstructor,
                         CCallParaNode.Create(
                           CAddrNode.Create_Internal(CRTTINode.Create(TStoredDef(lArrayNode.ResultDef),initrtti,rdt_normal)),
                             CCallParaNode.Create(CTypeConvNode.Create_Internal(CTempRefNode.Create(lTempNode),VoidPointerType),nil))
                       );
                 AddStatement(
                   lNewStatement,
                   CCallNode.CreateIntern(
                     'fpc_dynarray_concat_multi',
                     lCallPara
                   )
                 );
                 AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lTempNode));
                 AddStatement(lNewStatement,CTempRefNode.Create(lTempNode));
               end;
           end
         else
           begin
             { enforce strings }
             for lIndex:=lList.count-1 downto 0 do
               begin
                 if Assigned(Result) then
                   Result:=CAddNode.Create(addn,Result,TNode(lList[lIndex]))
                 else
                   begin
                     Result:=TNode(lList[lIndex]);
                     { Force string type if it isn't yet }
                     if not(
                            (Result.ResultDef.typ=stringdef) or
                            Is_CharArray(Result.ResultDef) or
                            Is_Char(Result.ResultDef)
                           ) then
                       InsertTypeConv(Result,CShortStringType);
                   end;
               end;
           end;

         lList.free;
         lList := nil;
       end;


     function TInlineNode.First_Pack_Unpack: TNode;
       var
         lLoopStatement    : TStatementNode;
         lLoopBlock             : TBlockNode;
         lLoopVar          : TTempCreateNode;
         lTempNode,
         lSource,
         lTarget,
         lIndexNode,
         lUnpackedNode,
         lPackedNode,
         lSourceVecIndex,
         lTargetVecIndex,
         lLoopBody         : TNode;
         lTempRangeDef     : TDef;
         lUnpackedLowRange,
         lUnpackedHighRange,
         lPackedLowRange,
         lPackedHighRange          : TConstExprInt;
       begin
         { transform into a for loop which assigns the data of the (un)packed }
         { array to the other one                                             }
         lSource := Left;
         if (InlineNumber = in_unpack_x_y_z) then
           begin
             lTarget := TCallParaNode(lSource).Right;
             lIndexNode := TCallParaNode(lTarget).Right;
             lPackedNode := TCallParaNode(lSource).Left;
             lUnpackedNode := TCallParaNode(lTarget).Left;
           end
         else
           begin
             lIndexNode := TCallParaNode(lSource).Right;
             lTarget := TCallParaNode(lIndexNode).Right;
             lPackedNode := TCallParaNode(lTarget).Left;
             lUnpackedNode := TCallParaNode(lSource).Left;
           end;
         lSource := TCallParaNode(lSource).Left;
         lTarget := TCallParaNode(lTarget).Left;
         lIndexNode := TCallParaNode(lIndexNode).Left;

         lLoopBlock := InternalStatements(lLoopStatement);
         lLoopVar := CTempCreateNode.Create(
           TArrayDef(lPackedNode.ResultDef).RangeDef,
           TArrayDef(lPackedNode.ResultDef).RangeDef.Size,
           tt_persistent,true);
         AddStatement(lLoopStatement,lLoopVar);

         { For range checking: we have to convert to an integer type (in case the index type }
         { is an enum), add the index and loop variable together, convert the result         }
         { implicitly to an orddef with range equal to the rangedef to get range checking   }
         { and finally convert it explicitly back to the actual rangedef to avoid type      }
         { errors                                                                            }
         lTempRangeDef:=nil;
         GetRange(lUnpackedNode.ResultDef,lUnpackedLowRange,lUnpackedHighRange);
         GetRange(lPackedNode.ResultDef,lPackedLowRange,lPackedHighRange);
         { does not really need to be registered, but then we would have to
           record it elsewhere so it still can be freed }
         lTempRangeDef:=COrdDef.Create(TOrdDef(SIntType).OrdType,lUnpackedLowRange,lUnpackedHighRange,true);
         lSourceVecIndex := CTempRefNode.Create(lLoopVar);
         lTargetVecIndex := CTypeConvNode.Create_Internal(lIndexNode.GetCopy,SIntType);
         lTargetVecIndex := CAddNode.Create(subn,lTargetVecIndex,COrdConstNode.Create(lPackedLowRange,SIntType,true));
         lTargetVecIndex := CAddNode.Create(addn,lTargetVecIndex,CTempRefNode.Create(lLoopVar));
         lTargetVecIndex := CTypeConvNode.Create(lTargetVecIndex,lTempRangeDef);
         lTargetVecIndex := CTypeConvNode.Create_Explicit(lTargetVecIndex,TArrayDef(lUnpackedNode.ResultDef).RangeDef);

         if (InlineNumber = in_pack_x_y_z) then
           begin
             { swap source and target vec indices }
             lTempNode := lSourceVecIndex;
             lSourceVecIndex := lTargetVecIndex;
             lTargetVecIndex := lTempNode;
           end;

         { create the assignment in the loop body }
         lLoopBody :=
           CAssignmentNode.Create(
             CVecNode.Create(lTarget.GetCopy,lTargetVecIndex),
             CVecNode.Create(lSource.GetCopy,lSourceVecIndex)
           );
         { create the actual for loop }
         lTempNode := CForNode.Create(
           CTempRefNode.Create(lLoopVar),
           CInlineNode.Create(in_low_x,false,lPackedNode.GetCopy),
           CInlineNode.Create(in_high_x,false,lPackedNode.GetCopy),
           lLoopBody,
           false);
         AddStatement(lLoopStatement,lTempNode);
         { free the loop counter }
         AddStatement(lLoopStatement,CTempDeleteNode.Create(lLoopVar));
         Result := lLoopBlock;
       end;

     function TInlineNode.May_Have_SideEffect_NoRecurse: Boolean;
       begin
         Result:=
          (InlineNumber in [in_write_x,in_writeln_x,in_read_x,in_readln_x,in_str_x_string,
           in_val_x,in_reset_x,in_rewrite_x,in_reset_typedfile,in_rewrite_typedfile,
           in_reset_typedfile_name,in_rewrite_typedfile_name,in_settextbuf_file_x,
           in_inc_x,in_dec_x,in_include_x_y,in_exclude_x_y,in_break,in_continue,in_setlength_x,
           in_finalize_x,in_new_x,in_dispose_x,in_exit,in_copy_x,in_initialize_x,in_leave,in_cycle,
           in_and_assign_x_y,in_or_assign_x_y,in_xor_assign_x_y,in_sar_assign_x_y,in_shl_assign_x_y,
           in_shr_assign_x_y,in_rol_assign_x_y,in_ror_assign_x_y,in_neg_assign_x,in_not_assign_x]) or
          ((InlineNumber = in_assert_x_y) and
           (cs_do_assertion in LocalSwitches));
       end;


     function TInlineNode.May_Ignore_Result:Boolean;
       begin
         case InlineNumber of
           in_atomic_inc,
           in_atomic_dec,
           in_atomic_xchg,
           in_atomic_cmp_xchg:
             Result:=true;
           else
             Result:=Is_Void(ResultDef);
         end;
       end;


     function TInlineNode.First_FMA: TNode;
       begin
         CGMessage1(cg_e_function_not_support_by_selected_instruction_set,'FMA');
         Result:=nil;
       end;


     function TInlineNode.First_MinMax: TNode;
       begin
         CGMessage1(cg_e_function_not_support_by_selected_instruction_set,'MIN/MAX');
         Result:=nil;
       end;


{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
     function TInlineNode.First_ShiftRot_Assign_64BitInt: TNode;
       var
         lProcName: String[31];
       begin
{$ifdef cpucg64shiftsupport}
         if InlineNumber in [in_sar_assign_x_y,in_shl_assign_x_y,in_shr_assign_x_y] then
           begin
             Result:=nil;
             ExpectLoc:=TCallParaNode(TCallParaNode(Left).Right).Left.ExpectLoc;
             exit;
           end;
{$endif cpucg64shiftsupport}
         Result := nil;
         if Is_Signed(TCallParaNode(Left).Right.ResultDef) then
           lProcName:='int64'
         else
           lProcName:='qword';
         case InlineNumber of
           in_sar_assign_x_y:
             lProcName := 'fpc_sar_assign_'+lProcName;
           in_shl_assign_x_y:
             lProcName := 'fpc_shl_assign_'+lProcName;
           in_shr_assign_x_y:
             lProcName := 'fpc_shr_assign_'+lProcName;
           in_rol_assign_x_y:
             lProcName := 'fpc_rol_assign_'+lProcName;
           in_ror_assign_x_y:
             lProcName := 'fpc_ror_assign_'+lProcName;
           else
             InternalError(2017041301);
         end;
         Result := CCallNode.CreateIntern(lProcName,CCallParaNode.Create(TCallParaNode(Left).Left,
           CCallParaNode.Create(TCallParaNode(TCallParaNode(Left).Right).Left,nil)));
         TCallParaNode(TCallParaNode(Left).Right).Left := nil;
         TCallParaNode(Left).Left := nil;
         FirstPass(Result);
       end;
{$endif not cpu64bitalu and nto cpuhighleveltarget}


     function TInlineNode.First_AndOrXorShiftRot_Assign: TNode;
       begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         { 64 bit ints have their own shift handling }
         if Is_64Bit(TCallParaNode(Left).Right.ResultDef) and
            (InlineNumber in [in_sar_assign_x_y,in_shl_assign_x_y,in_shr_assign_x_y,in_rol_assign_x_y,in_ror_assign_x_y]) then
           Result := First_ShiftRot_Assign_64BitInt
         else
{$endif not cpu64bitalu and not cpuhighleveltarget}
           begin
             Result:=nil;
             ExpectLoc:=TCallParaNode(TCallParaNode(Left).Right).Left.ExpectLoc;
           end;
       end;


     function TInlineNode.First_NegNot_Assign: TNode;
       begin
         Result:=nil;
         ExpectLoc:=Left.ExpectLoc;
       end;


     function TInlineNode.First_Atomic: TNode;
       var
         lName : String;
         lNode,lNode2,lCompareNode,lSuccessNode,lValueNode : TNode;
         lParaCount : SizeInt;
         lStatement : TStatementNode;
         lTempNode,lTempNode2: TTempCreateNode;
       begin
         { by default we redirect to the corresponding compilerprocs }
         lName:='fpc_atomic_';
         case InlineNumber of
           in_atomic_inc:
             if Assigned(TCallParaNode(Left).Right) then
               lName:=lName+'add'
             else
               lName:=lName+'inc';
           in_atomic_dec:
             if Assigned(TCallParaNode(Left).Right) then
               lName:=lName+'sub'
             else
               lName:=lName+'dec';
           in_atomic_xchg:
             lName:=lName+'xchg';
           in_atomic_cmp_xchg:
             lName:=lName+'cmp_xchg';
           else
             InternalError(2022093008);
         end;
         lName:=lName+'_';
         if Is_Pointer(ResultDef) then
           lName:=lName+ToStr(VoidPointerType.Size*8)
         else if Is_Integer(ResultDef) then
           case TOrdDef(ResultDef).OrdType of
             s8bit:
               lName:=lName+'8';
             s16bit:
               lName:=lName+'16';
             s32bit:
               lName:=lName+'32';
             s64bit:
               lName:=lName+'64';
             else
               InternalError(2022100101);
           end
         else
           InternalError(2022093009);

         { for the call node we need to reverse the parameters }
         lParaCount:=ReverseParameters(TCallParaNode(Left));

         lSuccessNode:=nil;
         lCompareNode:=nil;
         lValueNode:=nil;

         if (InlineNumber=in_atomic_cmp_xchg) and (lParaCount=4) then
           begin
             { don't pass along the Succeeded parameter }
             lSuccessNode:=TCallParaNode(Left).Left;
             lNode:=TCallParaNode(Left).Right;
             TCallParaNode(Left).Left:=nil;
             TCallParaNode(Left).Right:=nil;
             Left.free;
             Left:=TCallParaNode(lNode);
             { get a copy of the Comparand parameter }
             lCompareNode:=TCallParaNode(Left).Left.GetCopy;
           end
         else if ((InlineNumber=in_atomic_inc) or (InlineNumber=in_atomic_dec)) and (lParaCount=2) then
           begin
             lValueNode:=TCallParaNode(Left).Left.GetCopy;
           end;

         Result:=CTypeConvNode.Create_Internal(CCallNode.CreateIntern(lName,Left),ResultDef);

         Left:=nil;

         if Assigned(lSuccessNode) then
           begin
             { we need to execute the intrinsic and then we check whether the
               returned result, namely the original value, is equal to the
               comparand which means that the Succeeded parameter needs to be
               True (otherwise it needs to be False). }
             lNode:=InternalStatements(lStatement);
             lTempNode:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,true);
             AddStatement(lStatement,lTempNode);
             AddStatement(lStatement,CAssignmentNode.Create(CTempRefNode.Create(lTempNode),Result));
             lCompareNode:=lCompareNode.GetCopy;
             InsertTypeConv_Internal(lCompareNode,ResultDef);
             AddStatement(lStatement,
               CAssignmentNode.Create(lSuccessNode,
                 CAddNode.Create(EqualN,lCompareNode,
                   CTempRefNode.Create(lTempNode))));
             AddStatement(lStatement,CTempDeleteNode.Create_Normal_Temp(lTempNode));
             AddStatement(lStatement,CTempRefNode.Create(lTempNode));
             Result:=lNode;
           end
         else if ((InlineNumber=in_atomic_dec) or (InlineNumber=in_atomic_inc)) and (lParaCount=2) then
           begin
             { the helpers return the original value, due to ease of implementation with the
               existing Interlocked* implementations, but the intrinsics need to return the
               resulting value so we add/sub the Value to/from the result }
             lNode:=InternalStatements(lStatement);
             lTempNode:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,true);
             AddStatement(lStatement,lTempNode);
             if InlineNumber=in_atomic_inc then
               lNode2:=CAddNode.Create(addn,Result,lValueNode)
             else
               lNode2:=CAddNode.Create(subn,Result,lValueNode);
             AddStatement(lStatement,CAssignmentNode.Create(CTempRefNode.Create(lTempNode),lNode2));
             AddStatement(lStatement,CTempDeleteNode.Create_Normal_Temp(lTempNode));
             AddStatement(lStatement,CTempRefNode.Create(lTempNode));
             Result:=lNode;
           end;
       end;


     function TInlineNode.First_CPU : TNode;
       begin
         Result:=nil;
         InternalError(2017110101);
       end;


     procedure TInlineNode.CheckParameters(ACount: Integer);
       var
         lNode: TNode;
       begin
         if ACount=1 then
           begin
             // Sometimes there are more callparanodes
             if Left is TCallParaNode then
               set_varstate(TCallParaNode(Left).Left,vs_read,[vsf_must_be_valid])
             else
               set_varstate(Left,vs_read,[vsf_must_be_valid])
           end
         else
           begin
             lNode:=Left;
             while ACount>0 do
               begin
                 set_varstate(TCallParaNode(lNode).Left,vs_read,[vsf_must_be_valid]);

                 lNode:=TCallParaNode(lNode).Right;
                 dec(ACount);
               end;
           end;
       end;

end.

