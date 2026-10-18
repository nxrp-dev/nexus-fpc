{
    Copyright (c) 2000-2002 by Florian Klaempfl

    Type checking and register allocation for type converting nodes

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
unit ncnv;

{$i fpcdefs.inc}

interface

    uses
       TPCompilerReal,
       node,
       symtype,
       defutil,defcmp,
       nld
       ;

    type
       TTypeConvNodeFlag = (
          { the typeconvnode is a proc_2_procvar, generated internally by an
            address operator, such as @proc, Addr(proc), Ofs(proc) or Seg(proc),
            which is then going to be converted to a void pointer. Why does it
            matter? Because, on i8086 far code memory models you're allowed to
            take the address of a _near_ procedure as a void pointer (which the
            @ operator does in TP mode), but not as a procvar (in that case the
            procedure must be far). }
          tcnf_proc_2_procvar_2_voidpointer,
          { proc_2_procvar, generated internally by Ofs() }
          tcnf_proc_2_procvar_get_offset_only
       );
       TTypeConvNodeFlags = set of TTypeConvNodeFlag;

       TTypeConvNode = class(TUnaryNode)
          ToTypeDef   : TDef;
          ToTypeDefDeref : TDeref;
          ConvType : TConvertType;
          ConvNodeFlags : TTypeConvNodeFlags;
          WarnPointerToSigned,
          AssignmentSide: Boolean;
          constructor Create(ANode : TNode;ADef:TDef);virtual;
          constructor Create_Explicit(ANode : TNode;ADef:TDef);
          constructor Create_Internal(ANode : TNode;ADef:TDef);
          constructor Create_Proc_To_ProcVar(ANode : TNode);
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          function DoGetCopy : TNode;override;
          procedure PrintNodeInfo(var AText : Text);override;
          procedure Convert_Deferred_Stmt_Expr;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function Simplify(AForInline : Boolean):TNode; override;
          procedure Mark_Write;override;
          function DoCompare(ANode: TNode) : Boolean; override;
          function Retains_Value_Location:Boolean;
          function Assign_Allowed:Boolean;
          procedure Second_Call_Helper(AConvertType : TConvertType);
          { always called before any other type conversion checks. If it
            returns true, the type conversion is ok and no further checks/
            handling are required. }
          function Target_Specific_General_TypeConv: Boolean;virtual;
          { called in case of a valid explicit type conversion. Can be used to
            replace this explicit type conversion with a different node, or to
            reject it after all }
          function Target_Specific_Explicit_TypeConv: Boolean;virtual;

          { called when inserttypeconv is used to convert to a def that is equal
            according to compare_defs() }
          class function Target_Specific_Need_Equal_TypeConv(AFromDef, AToDef: TDef): Boolean; virtual;
       protected
          function TypeCheck_Int_To_Int : TNode; virtual;
          function TypeCheck_COrd_To_Pointer : TNode; virtual;
          function TypeCheck_CharArray_To_String : TNode; virtual;
          function TypeCheck_String_To_CharArray : TNode; virtual;
          function TypeCheck_String_To_String : TNode; virtual;
          function TypeCheck_Char_To_String : TNode; virtual;
          function TypeCheck_Char_To_CharArray : TNode; virtual;
          function TypeCheck_Int_To_Real : TNode; virtual;
          function TypeCheck_Real_To_Real : TNode; virtual;
          function TypeCheck_Real_To_Currency : TNode; virtual;
          function TypeCheck_CChar_To_PChar : TNode; virtual;
          function TypeCheck_CString_To_PChar : TNode; virtual;
          function TypeCheck_CString_To_Int : TNode; virtual;
          function TypeCheck_Char_To_Char : TNode; virtual;
          function TypeCheck_ArrayConstructor_To_Set : TNode; virtual;
          function TypeCheck_Set_To_Set : TNode; virtual;
          function TypeCheck_PChar_To_String : TNode; virtual;
          function TypeCheck_Interface_To_String : TNode; virtual;
          function TypeCheck_Interface_To_GUID : TNode; virtual;
          function TypeCheck_DynArray_To_OpenArray : TNode; virtual;
          function TypeCheck_PWChar_To_String : TNode; virtual;
          function TypeCheck_Variant_To_DynArray : TNode; virtual;
          function TypeCheck_DynArray_To_Variant : TNode; virtual;
          function TypeCheck_Variant_To_Enum : TNode; virtual;
          function TypeCheck_Enum_To_Variant : TNode; virtual;
          function TypeCheck_Proc_To_ProcVar : TNode; virtual;
          function TypeCheck_Variant_To_Interface : TNode; virtual;
          function TypeCheck_Interface_To_Variant : TNode; virtual;
          function TypeCheck_Array_2_DynArray : TNode; virtual;
          function TypeCheck_Elem_2_OpenArray : TNode; virtual;
          function TypeCheck_ArrayConstructor_To_DynArray : TNode; virtual;
          function TypeCheck_ArrayConstructor_To_Array : TNode; virtual;
          function TypeCheck_AnonProc_2_FuncRef : TNode; virtual;
          function TypeCheck_ProcVar_2_FuncRef : TNode; virtual;
       private
          function DispatchTypeCheckIntToInt : TNode;
          function DispatchTypeCheckCOrdToPointer : TNode;
          function DispatchTypeCheckCharArrayToString : TNode;
          function DispatchTypeCheckStringToCharArray : TNode;
          function DispatchTypeCheckStringToString : TNode;
          function DispatchTypeCheckCharToString : TNode;
          function DispatchTypeCheckCharToCharArray : TNode;
          function DispatchTypeCheckIntToReal : TNode;
          function DispatchTypeCheckRealToReal : TNode;
          function DispatchTypeCheckRealToCurrency : TNode;
          function DispatchTypeCheckCCharToPChar : TNode;
          function DispatchTypeCheckCStringToPChar : TNode;
          function DispatchTypeCheckCStringToInt : TNode;
          function DispatchTypeCheckCharToChar : TNode;
          function DispatchTypeCheckArrayConstructorToSet : TNode;
          function DispatchTypeCheckSetToSet : TNode;
          function DispatchTypeCheckPCharToString : TNode;
          function DispatchTypeCheckInterfaceToString : TNode;
          function DispatchTypeCheckInterfaceToGUID : TNode;
          function DispatchTypeCheckDynArrayToOpenArray : TNode;
          function DispatchTypeCheckPWCharToString : TNode;
          function DispatchTypeCheckVariantToDynArray : TNode;
          function DispatchTypeCheckDynArrayToVariant : TNode;
          function DispatchTypeCheckVariantToEnum : TNode;
          function DispatchTypeCheckEnumToVariant : TNode;
          function DispatchTypeCheckProcToProcVar : TNode;
          function DispatchTypeCheckVariantToInterface : TNode;
          function DispatchTypeCheckInterfaceToVariant : TNode;
          function DispatchTypeCheckArrayToDynArray : TNode;
          function DispatchTypeCheckElemToOpenArray : TNode;
          function DispatchTypeCheckArrayConstructorToDynArray : TNode;
          function DispatchTypeCheckArrayConstructorToArray : TNode;
          function DispatchTypeCheckAnonProcToFuncRef : TNode;
          function DispatchTypeCheckProcVarToFuncRef : TNode;
       protected
          function First_Int_To_Int : TNode;virtual;
          function First_CString_To_PChar : TNode;virtual;
          function First_CString_To_Int : TNode;virtual;
          function First_String_To_CharArray : TNode;virtual;
          function First_Char_To_String : TNode;virtual;
          function First_Char_To_CharArray : TNode; virtual;
          function First_Nothing : TNode;virtual;
          function First_Array_To_Pointer : TNode;virtual;
          function First_Int_To_Real : TNode;virtual;
          function First_Real_To_Real : TNode;virtual;
          function First_Pointer_To_Array : TNode;virtual;
          function First_CChar_To_PChar : TNode;virtual;
          function First_Bool_To_Int : TNode;virtual;
          function First_Int_To_Bool : TNode;virtual;
          function First_Bool_To_Bool : TNode;virtual;
          function First_Proc_To_ProcVar : TNode;virtual;
          function First_Nil_To_MethodProcVar : TNode;virtual;
          function First_Set_To_Set : TNode;virtual;
          function First_COrd_To_Pointer : TNode;virtual;
          function First_AnsiString_To_PChar : TNode;virtual;
          function First_ArrayConstructor_To_Set : TNode;virtual;
          function First_Class_To_Intf : TNode;virtual;
          function First_Char_To_Char : TNode;virtual;
          function First_String_To_String : TNode;virtual;
          function First_Call_Helper(AConvertType : TConvertType) : TNode;
          function TypeCheck_Call_Helper(AConvertType : TConvertType) : TNode;
       private
          { these wrapper are necessary, because the first_* stuff is called }
          { through a table. Without the wrappers override wouldn't have     }
          { any effect                                                       }
          function DispatchFirstIntToInt : TNode;
          function DispatchFirstCStringToPChar : TNode;
          function DispatchFirstCStringToInt : TNode;
          function DispatchFirstStringToCharArray : TNode;
          function DispatchFirstCharToString : TNode;
          function DispatchFirstCharToCharArray : TNode;
          function DispatchFirstNothing : TNode;
          function DispatchFirstArrayToPointer : TNode;
          function DispatchFirstIntToReal : TNode;
          function DispatchFirstRealToReal: TNode;
          function DispatchFirstPointerToArray : TNode;
          function DispatchFirstCCharToPChar : TNode;
          function DispatchFirstBoolToInt : TNode;
          function DispatchFirstIntToBool : TNode;
          function DispatchFirstBoolToBool : TNode;
          function DispatchFirstProcToProcVar : TNode;
          function DispatchFirstNilToMethodProcVar : TNode;
          function DispatchFirstCOrdToPointer : TNode;
          function DispatchFirstAnsiStringToPChar : TNode;
          function DispatchFirstArrayConstructorToSet : TNode;
          function DispatchFirstClassToIntf : TNode;
          function DispatchFirstCharToChar : TNode;
          function DispatchFirstSetToSet : TNode;
          function DispatchFirstStringToString : TNode;

          procedure _Second_Int_To_Int;virtual;
          procedure _Second_String_To_String;virtual;
          procedure _Second_CString_To_PChar;virtual;
          procedure _Second_CString_To_Int;virtual;
          procedure _Second_String_To_CharArray;virtual;
          procedure _Second_Array_To_Pointer;virtual;
          procedure _Second_Pointer_To_Array;virtual;
          procedure _Second_CharArray_To_String;virtual;
          procedure _Second_Char_To_String;virtual;
          procedure _Second_Int_To_Real;virtual;
          procedure _Second_Real_To_Real;virtual;
          procedure _Second_COrd_To_Pointer;virtual;
          procedure _Second_Proc_To_ProcVar;virtual;
          procedure _Second_Nil_To_MethodProcVar;virtual;
          procedure _Second_Bool_To_Int;virtual;
          procedure _Second_Int_To_Bool;virtual;
          procedure _Second_Bool_To_Bool;virtual;
          procedure _Second_Set_To_Set;virtual;
          procedure _Second_AnsiString_To_PChar;virtual;
          procedure _Second_Class_To_Intf;virtual;
          procedure _Second_Char_To_Char;virtual;
          procedure _Second_Elem_To_OpenArray;virtual;
          procedure _Second_Nothing; virtual;

        protected
          procedure Second_Int_To_Int;virtual;abstract;
          procedure Second_String_To_String;virtual;abstract;
          procedure Second_CString_To_PChar;virtual;abstract;
          procedure Second_CString_To_Int;virtual;abstract;
          procedure Second_String_To_CharArray;virtual;abstract;
          procedure Second_Array_To_Pointer;virtual;abstract;
          procedure Second_Pointer_To_Array;virtual;abstract;
          procedure Second_CharArray_To_String;virtual;abstract;
          procedure Second_Char_To_String;virtual;abstract;
          procedure Second_Int_To_Real;virtual;abstract;
          procedure Second_Real_To_Real;virtual;abstract;
          procedure Second_COrd_To_Pointer;virtual;abstract;
          procedure Second_Proc_To_ProcVar;virtual;abstract;
          procedure Second_Nil_To_MethodProcVar;virtual;abstract;
          procedure Second_Bool_To_Int;virtual;abstract;
          procedure Second_Int_To_Bool;virtual;abstract;
          procedure Second_Bool_To_Bool;virtual;abstract;
          procedure Second_Set_To_Set;virtual;abstract;
          procedure Second_AnsiString_To_PChar;virtual;abstract;
          procedure Second_Class_To_Intf;virtual;abstract;
          procedure Second_Char_To_Char;virtual;abstract;
          procedure Second_Elem_To_OpenArray;virtual;abstract;
          procedure Second_Nothing; virtual;abstract;
       end;
       TTypeConvNodeClass = class of TTypeConvNode;

       { common functionality of as-nodes and is-nodes }
       TAsIsNode = class(TBinaryNode)
          protected
           { if non-standard usage of as-nodes is possible, targets can override
           this method and return true in case the conditions are fulfilled }
          function Target_Specific_TypeCheck: Boolean;virtual;
         public
          function Pass_TypeCheck:TNode;override;
       end;

       TAsNode = class(TAsIsNode)
          { as nodes cannot be translated directly into call nodes bcause:

            When using -CR, explicit class typecasts are replaced with as-nodes to perform
            class type checking. The problem is that if a typecasted class instance is
            passed as a var-parameter, then you cannot replace it with a function call. So the as-node
            a) call the as helper to perform the type checking
            b) still pass the original instance as parameter to var-parameters
            (and in general: to return it as the result of the as-node)

            so the call field is required
          }
          Call: TNode;
          constructor Create(ALeft,ARight : TNode);virtual;
          constructor Create_Internal(ALeft,ARight : TNode);virtual;
          function Pass_1 : TNode;override;
          function DoGetCopy: TNode;override;
          function DoCompare(ANode: TNode): Boolean; override;
          destructor Destroy; override;
       end;
       TAsNodeClass = class of TAsNode;

       TIsNode = class(TAsIsNode)
          constructor Create(ALeft,ARight : TNode);virtual;
          constructor Create_Internal(ALeft,ARight : TNode);virtual;
          function Pass_1 : TNode;override;
          procedure Pass_Generate_Code;override;
       end;
       TIsNodeClass = class of TIsNode;

    var
       CTypeConvNode : TTypeConvNodeClass = TTypeConvNode;
       CAsNode : TAsNodeClass = TAsNode;
       CIsNode : TIsNodeClass=TIsNode;

    procedure InsertTypeConv(var ANode:TNode;ADef:TDef);
    procedure InsertTypeConv_Explicit(var ANode:TNode;ADef:TDef);
    procedure InsertTypeConv_Internal(var ANode:TNode;ADef:TDef);
    procedure ArrayConstructor_To_Set(var ANode : TNode);inline;
    function ArrayConstructor_To_Set(ANode:TNode;AFreeNode:Boolean):TNode;
    function ArrayConstructor_Can_Be_Set(ANode:TNode):Boolean;
    procedure Insert_VarArgsTypeConv(var ANode : TNode; AIsCVarArgs: Boolean);

    function Maybe_Global_Proc_To_Nested(var AFromNode: TNode; AToDef: TDef): Boolean;


implementation

   uses
      GlobType,Systems,ConstExp,compinnr,
      CUtils,Verbose,Globals,WideStr,PPU,
      symconst,symdef,SymSym,symcpu,SymTable,
      ncon,ncal,nset,nadd,nmem,nmat,nbas,nutils,ninl,nflw,
      psub,
      cgbase,ProcInfo,
      htypechk,blockutl,pparautl,procdefutil,Pass_1,CPUInfo;


{*****************************************************************************
                                   Helpers
*****************************************************************************}
    type
      TTypeConvNodeType = (tct_implicit,tct_explicit,tct_internal);

    procedure DoInsertTypeConv(var ANode: TNode;ADef: TDef; AConvType: TTypeConvNodeType);

      begin
        if not Assigned(ANode.ResultDef) then
         begin
           TypeCheckPass(ANode);
           if CodeGenError then
            exit;
         end;


        { Preserve definition kinds and bitpacked access widths when removing casts. }
        if Equal_Defs(ANode.ResultDef,ADef) and
           (ANode.ResultDef.typ=ADef.typ) and
           not Is_BitPacked_Access(ANode) and
           { result of a hardware vector node must remain a hardware
             vector of the same kind (will match to tc_equal with regular arrays
             of same dimension/eledef) }
           not((ANode.ResultDef.typ=arraydef) and
               TArrayDef(ANode.ResultDef).Is_HWVector) and
           ((ANode.blocktype=bt_const) or
            not CTypeConvNode.Target_Specific_Need_Equal_TypeConv(ANode.ResultDef,ADef)) then
          begin
            { don't replace encoded string constants to rawbytestring encoding.
              preserve the codepage }
            if not (Is_RawByteString(ADef) and (ANode.NodeType=stringconstn)) then
              ANode.ResultDef:=ADef
          end
        else
         begin
           case AConvType of
             tct_implicit:
               ANode:=CTypeConvNode.Create(ANode,ADef);
             tct_explicit:
               ANode:=CTypeConvNode.Create_Explicit(ANode,ADef);
             tct_internal:
               ANode:=CTypeConvNode.Create_Internal(ANode,ADef);
           end;
           if not (nf_internal in ANode.Flags) and Is_Currency(ADef) then
             Include(ANode.Flags, nf_is_currency);
           ANode.FileInfo:=TTypeConvNode(ANode).Left.FileInfo;
           TypeCheckPass(ANode);
         end;
      end;


    procedure InsertTypeConv(var ANode:TNode;ADef:TDef);

      begin
        DoInsertTypeConv(ANode,ADef,tct_implicit);
      end;


    procedure InsertTypeConv_Explicit(var ANode: TNode; ADef: TDef);

      begin
        DoInsertTypeConv(ANode,ADef,tct_explicit);
      end;

    procedure InsertTypeConv_Internal(var ANode:TNode;ADef:TDef);

      begin
        DoInsertTypeConv(ANode,ADef,tct_internal);
      end;


{*****************************************************************************
                    Array constructor to Set Conversion
*****************************************************************************}

    procedure ArrayConstructor_To_Set(var ANode : TNode);
      begin
        ANode:=ArrayConstructor_To_Set(ANode,true);
      end;

    function ArrayConstructor_To_Set(ANode:TNode;AFreeNode:Boolean):TNode;
      var
        lConstNode      : TSetConstNode;
        lNode2,lNode3,lNode4    : TNode;
        lDef        : TDef;
        lConstSet    : PConstSet;
        lConstSetLow,
        lConstSetHigh  : TConstExprInt;

        procedure UpdateConstSetHigh(ADef:TDef; AMaybeTruncateEnumRange: Boolean);
          begin
            if (ADef.typ=orddef) and
               ((TOrdDef(ADef).high>=lConstSetHigh) or
                (TOrdDef(ADef).low <=lConstSetLow)) then
              begin
                if TOrdDef(ADef).OrdType=uwidechar then
                  begin
                    lConstSetHigh:=255;
                    lConstSetLow:=0;
                    if lDef=nil then
                      lDef:=ADef;
                  end
                else
                  begin
                    if (TOrdDef(ADef).high>=lConstSetHigh) then
                      lConstSetHigh:=TOrdDef(ADef).high;
                    if (TOrdDef(ADef).low<=lConstSetLow) then
                      lConstSetLow:=TOrdDef(ADef).low;
                    if lDef=nil then
                      begin
                         if (lConstSetHigh>255) or
                            (TOrdDef(ADef).low<0) then
                           lDef:=U8IntType
                         else
                           lDef:=ADef;
                      end;
                    if lConstSetHigh>255 then
                      lConstSetHigh:=255;
                    if lConstSetLow<0 then
                      lConstSetLow:=0;
                  end;
              end
            else if (ADef.typ=enumdef) and
                    ((TEnumDef(ADef).max>=lConstSetHigh) or
                     (TEnumDef(ADef).min<=lConstSetLow)) then
              begin
                 if lDef=nil then
                   lDef:=ADef;
                 if (TEnumDef(ADef).max>=lConstSetHigh) then
                   lConstSetHigh:=TEnumDef(ADef).max;
                 if (TEnumDef(ADef).min<=lConstSetLow) then
                   lConstSetLow:=TEnumDef(ADef).min;
                 { for constant set elements, delphi allows the usage of elements of enumerations which
                   have value>255 if there is no element with a value > 255 used }
                 if (AMaybeTruncateEnumRange) then
                   begin
                    if lConstSetHigh>255 then
                      lConstSetHigh:=255;
                    if lConstSetLow<0 then
                      lConstSetLow:=0;
                   end;
              end;
          end;

        procedure IncludeSetValue(APosition : LongInt);
          begin
            if (APosition and not $ff)<>0 then
              begin
                Message(parser_e_illegal_set_expr);
                exit;
              end;
            if APosition>lConstSetHigh then
             lConstSetHigh:=APosition;
            if APosition<lConstSetLow then
             lConstSetLow:=APosition;
            if APosition in lConstSet^ then
              Message(parser_e_illegal_set_expr);
            include(lConstSet^,APosition);
          end;

      var
        lLength : LongInt;
        lLowRange,lHighRange : TConstExprInt;
        lArrayConstructor : TArrayConstructorNode;
        lOldFilePos: TFilePosInfo;
        lFirst: Boolean;
      begin
        { keep in sync with arrayconstructor_can_be_set }
        if ANode.NodeType<>arrayconstructorn then
          InternalError(200205105);
        { A generic body is parsed again when specializing. Do not lower a set
          constructor before its element types are known: even a fixed set
          destination can contain expressions whose type is a parameter. }
        if Assigned(CurrentProcInfo) and
           (df_generic in CurrentProcInfo.procdef.DefOptions) then
          begin
            lArrayConstructor:=TArrayConstructorNode(ANode);
            while Assigned(lArrayConstructor) and Assigned(lArrayConstructor.Left) do
              begin
                TypeCheckPass(lArrayConstructor.Left);
                if lArrayConstructor.Left.NodeType=arrayconstructorrangen then
                  begin
                    lNode2:=TArrayConstructorRangeNode(lArrayConstructor.Left).Left;
                    lNode3:=TArrayConstructorRangeNode(lArrayConstructor.Left).Right;
                  end
                else
                  begin
                    lNode2:=lArrayConstructor.Left;
                    lNode3:=nil;
                  end;
                if Is_TypeParam(lNode2.ResultDef) or
                   (Assigned(lNode3) and Is_TypeParam(lNode3.ResultDef)) then
                  begin
                    { Keep a set-typed placeholder so surrounding set operators
                      can still be checked while parsing the template. }
                    new(lConstSet);
                    lConstSet^:=[];
                    lConstNode:=CSetConstNode.Create(nil,CSetDef.Create(nil,0,0,true));
                    lConstNode.ValueSet:=lConstSet;
                    Result:=lConstNode;
                    TypeCheckPass(Result);
                    if AFreeNode then
                      ANode.free;
                    exit;
                  end;
                lArrayConstructor:=TArrayConstructorNode(lArrayConstructor.Right);
              end;
          end;
        new(lConstSet);
        lConstSet^:=[];
        lDef:=nil;
        { make sure to set constsetlo correctly for empty sets }
        if Assigned(TArrayConstructorNode(ANode).Left) then
          lConstSetLow:=high(aint)
        else
          lConstSetLow:=0;
        lConstSetHigh:=0;
        lConstNode:=CSetConstNode.Create(nil,lDef);
        lConstNode.ValueSet:=lConstSet;
        Result:=lConstNode;
        lArrayConstructor:=TArrayConstructorNode(ANode);
        if Assigned(lArrayConstructor.Left) then
         begin
           lFirst:=true;
           while Assigned(lArrayConstructor) do
            begin
              lNode4:=nil; { will contain the tree to create the set }
              { split a range into p2 and p3 }
              if lArrayConstructor.Left.NodeType=arrayconstructorrangen then
               begin
                 lNode2:=TArrayConstructorRangeNode(lArrayConstructor.Left).Left;
                 lNode3:=TArrayConstructorRangeNode(lArrayConstructor.Left).Right;
                 TArrayConstructorRangeNode(lArrayConstructor.Left).Left:=nil;
                 TArrayConstructorRangeNode(lArrayConstructor.Left).Right:=nil;
               end
              else
               begin
                 lNode2:=lArrayConstructor.Left;
                 lArrayConstructor.Left:=nil;
                 lNode3:=nil;
               end;
              TypeCheckPass(lNode2);
              Set_VarState(lNode2,vs_read,[vsf_must_be_valid]);
              if Assigned(lNode3) then
                begin
                  TypeCheckPass(lNode3);
                  Set_VarState(lNode3,vs_read,[vsf_must_be_valid]);
                end;
              if CodeGenError then
               break;
              lOldFilePos:=CurrentFilePos;
              CurrentFilePos:=lNode2.FileInfo;
              case lNode2.ResultDef.typ of
                enumdef,
                orddef:
                  begin
                    { widechars are not yet supported }
                    if Is_WideChar(lNode2.ResultDef) then
                      begin
                        if Block_Type<>bt_const then
                          InsertTypeConv(lNode2,CAnsiCharType);
                        if (lNode2.NodeType<>ordconstn) and not (m_default_unicodestring in CurrentSettings.ModeSwitches) then
                          IncompatibleTypes(CWideCharType,CAnsiCharType);
                      end;

                    GetRange(lNode2.ResultDef,lLowRange,lHighRange);
                    if Assigned(lNode3) then
                     begin
                       if Is_WideChar(lNode3.ResultDef) then
                         begin
                           if Block_Type<>bt_const then
                             InsertTypeConv(lNode3,CAnsiCharType);
                           if (lNode3.NodeType<>ordconstn) and not (m_default_unicodestring in CurrentSettings.ModeSwitches) then
                             begin
                               CurrentFilePos:=lNode3.FileInfo;
                               IncompatibleTypes(CWideCharType,CAnsiCharType);
                             end;
                         end;
                       { this isn't good, you'll get problems with
                         type t010 = 0..10;
                              ts = set of t010;
                         var  s : ts;b : t010
                         begin  s:=[1,2,b]; end.
                       if is_integer(p3^.resultdef) then
                        begin
                          inserttypeconv(p3,u8bitdef);
                        end;
                       }
                       if Assigned(lDef) and not(Equal_Defs(lDef,lNode3.ResultDef)) then
                         begin
                            CGMessagePos(lNode3.FileInfo,type_e_typeconflict_in_set);
                         end
                       else
                         begin
                           if (lNode2.NodeType=ordconstn) and (lNode3.NodeType=ordconstn) then
                            begin
                               if not(Is_Integer(lNode3.ResultDef)) then
                                 begin
                                   if not(Assigned(lDef)) and lFirst then
                                     lDef:=lNode3.ResultDef;
                                 end
                               else
                                 begin
                                   InsertTypeConv(lNode3,U8IntType);
                                   InsertTypeConv(lNode2,U8IntType);
                                 end;

                              if TOrdConstNode(lNode2).Value.svalue>TOrdConstNode(lNode3).Value.svalue then
                                CGMessagePos(lNode2.FileInfo,type_w_empty_constant_range_set);
                              for lLength:=TOrdConstNode(lNode2).Value.svalue to TOrdConstNode(lNode3).Value.svalue do
                                IncludeSetValue(lLength);
                              lNode2.free;
                              lNode2 := nil;
                              lNode3.free;
                              lNode3 := nil;
                            end
                           else
                            begin
                              UpdateConstSetHigh(lNode2.ResultDef,false);
                              InsertTypeConv(lNode2,lDef);

                              UpdateConstSetHigh(lNode3.ResultDef,false);
                              InsertTypeConv(lNode3,lDef);

                              if Assigned(lDef) then
                                InsertTypeConv(lNode3,lDef)
                              else if lFirst then
                                lDef:=lNode3.ResultDef
                              else
                                InsertTypeConv(lNode3,U8IntType);
                              lNode4:=CSetElementNode.Create(lNode2,lNode3);
                            end;
                         end;
                     end
                    else
                     begin
                       { Single value }
                       if lNode2.NodeType=ordconstn then
                        begin
                          if Assigned(lDef) then
                            InsertTypeConv(lNode2,lDef)
                          else if not(Is_Integer(lNode2.ResultDef)) and lFirst then
                            lDef:=lNode2.ResultDef
                          else
                            InsertTypeConv(lNode2,U8IntType);

                          if not(Is_Integer(lNode2.ResultDef)) then
                            UpdateConstSetHigh(lNode2.ResultDef,true);

                          IncludeSetValue(TOrdConstNode(lNode2).Value.svalue);
                          lNode2.free;
                          lNode2 := nil;
                        end
                       else
                        begin
                          UpdateConstSetHigh(lNode2.ResultDef,false);

                          if Assigned(lDef) then
                            InsertTypeConv(lNode2,lDef)
                          else if not(Is_Integer(lNode2.ResultDef)) and lFirst then
                            lDef:=lNode2.ResultDef
                          else
                            InsertTypeConv(lNode2,U8IntType);

                          lNode4:=CSetElementNode.Create(lNode2,nil);
                        end;
                     end;
                  end;
                else
                  CGMessage(type_e_ordinal_expr_expected);
              end;
              { insert the set creation tree }
              if Assigned(lNode4) then
               Result:=CAddNode.Create(addn,Result,lNode4);
              { load next and dispose current node }
              lNode2:=lArrayConstructor;
              lArrayConstructor:=TArrayConstructorNode(TArrayConstructorNode(lNode2).Right);
              TArrayConstructorNode(lNode2).Right:=nil;
              if AFreeNode then
                lNode2.free; // no nil needed
              CurrentFilePos:=lOldFilePos;
              lFirst:=false;
            end;
          if (lDef=nil) then
            lDef:=U8IntType;
         end
        else
         begin
           { empty set [], only remove node }
           if AFreeNode then
             ANode.free; // no nil needed
         end;
        { set the initial set type }
        lConstNode.ResultDef:=CSetDef.Create(lDef,lConstSetLow.svalue,lConstSetHigh.svalue,true);
        { determine the resultdef for the tree }
        TypeCheckPass(Result);
      end;


    function ArrayConstructor_Can_Be_Set(ANode:TNode):Boolean;
      var
        lNode1,lNode2 : TNode;
        lDef : TDef;
      begin
        { keep in sync with arrayconstructor_to_set }
        if not Assigned(ANode) then
          InternalError(2015050401);
        if not Assigned(TArrayConstructorNode(ANode).Left) then
          begin
            if Assigned(TArrayConstructorNode(ANode).Right) then
              InternalError(2015050103);
            Result:=true;
          end
        else
          begin
            Result:=false;

            lDef:=nil;

            while Assigned(ANode) do
              begin
                if TArrayConstructorNode(ANode).Left.NodeType=arrayconstructorrangen then
                  begin
                    lNode1:=TArrayConstructorRangeNode(TArrayConstructorNode(ANode).Left).Left;
                    lNode2:=TArrayConstructorRangeNode(TArrayConstructorNode(ANode).Left).Right;
                  end
                else
                  begin
                    lNode1:=TArrayConstructorNode(ANode).Left;
                    lNode2:=nil;
                  end;

                case lNode1.ResultDef.typ of
                  orddef,
                  enumdef:
                    begin
                      if Is_WideChar(lNode1.ResultDef) then
                        begin
                          if lNode1.NodeType<>ordconstn then
                            exit
                          else if (TOrdConstNode(lNode1).Value.uvalue>high(Byte)) and not (m_default_unicodestring in CurrentSettings.ModeSwitches) then
                            exit;
                        end;

                      if Assigned(lNode2) then
                        begin
                          if Is_WideChar(lNode2.ResultDef) then
                            begin
                              if lNode2.NodeType<>ordconstn then
                                exit
                              else if (TOrdConstNode(lNode2).Value.uvalue>high(Byte)) and not (m_default_unicodestring in CurrentSettings.ModeSwitches) then
                                exit;
                            end;

                          { anything to exclude? }
                        end
                      else
                        begin
                          { anything to exclude? }
                        end;
                    end;
                  stringdef:
                    if lNode1.NodeType<>stringconstn then
                      exit
                    else if Assigned(lDef) and not Is_Char(lDef) then
                      exit;
                  else
                    exit;
                end;

                ANode:=TArrayConstructorNode(ANode).Right;
              end;

            Result:=true;
          end;
      end;


    procedure Insert_VarArgsTypeConv(var ANode : TNode; AIsCVarArgs: Boolean);
      begin
        { procvars without arguments in variant arrays are always called by
          Delphi }
        if not(AIsCVarArgs) then
          Maybe_Call_ProcVar(ANode,true);
        if not(AIsCVarArgs) and
           (ANode.NodeType=stringconstn) and
           { don't cast to AnsiString if already casted to Wide/UnicodeString, issue #18266 }
           (TStringConstNode(ANode).ConstStringType in [cst_conststring,cst_shortstring,cst_longstring]) then
          ANode:=CTypeConvNode.Create_Internal(ANode,GetAnsiStringDef)
        else
          case ANode.ResultDef.typ of
            enumdef :
              ANode:=CTypeConvNode.Create_Internal(ANode,S32IntType);
            arraydef :
              begin
                if Is_CharArray(ANode.ResultDef) then
                  ANode:=CTypeConvNode.Create_Internal(ANode,CharPointerType)
                else
                  if Is_WideCharArray(ANode.ResultDef) then
                    ANode:=CTypeConvNode.Create_Internal(ANode,WideCharPointerType)
                else
                  CGMessagePos1(ANode.FileInfo,type_e_wrong_type_in_array_constructor,ANode.ResultDef.TypeName);
              end;
            orddef :
              begin
                if Is_Integer(ANode.ResultDef) and
                   not(Is_64BitInt(ANode.ResultDef)) then
                  if not(m_delphi in CurrentSettings.ModeSwitches) then
                    ANode:=CTypeConvNode.Create(ANode,S32IntType)
                  else
                    { delphi doesn't generate a range error when passing a
                      cardinal >= $80000000, but since these are seen as
                      longint on the callee side, this causes data loss;
                      as a result, we require an explicit longint()
                      typecast in FPC mode on the caller side if range
                      checking should be disabled, but not in Delphi mode }
                    ANode:=CTypeConvNode.Create_Internal(ANode,S32IntType)
                else if Is_Void(ANode.ResultDef) then
                  CGMessagePos1(ANode.FileInfo,type_e_wrong_type_in_array_constructor,ANode.ResultDef.TypeName)
                else if AIsCVarArgs and Is_Currency(ANode.ResultDef) then
                  ANode:=CTypeConvNode.Create(ANode,S64FloatType);
              end;
            floatdef :
              if not(AIsCVarArgs) then
                begin
                  if not(Is_Currency(ANode.ResultDef)) then
                    ANode:=CTypeConvNode.Create(ANode,PBestRealType^);
                end
              else
                begin
                  if (Is_ConstRealNode(ANode) and not(nf_explicit in ANode.Flags)) or
                     ((TargetInfo.system=system_x86_64_win64) and Is_Extended(ANode.ResultDef)) then
                    MessagePos(ANode.FileInfo,type_w_double_c_varargs);
                  if (TFloatDef(ANode.ResultDef).FloatType in [S32Real,s64currency]) or
                     ((TargetInfo.system=system_x86_64_win64) and Is_Extended(ANode.ResultDef)) or
                     (Is_ConstRealNode(ANode) and
                      not(nf_explicit in ANode.Flags)) then
                    ANode:=CTypeConvNode.Create(ANode,S64FloatType);
                end;
            procvardef :
              ANode:=CTypeConvNode.Create(ANode,VoidPointerType);
            stringdef:
              if AIsCVarArgs then
                ANode:=CTypeConvNode.Create(ANode,CharPointerType);
            variantdef:
              if AIsCVarArgs then
                CGMessagePos1(ANode.FileInfo,type_e_wrong_type_in_array_constructor,ANode.ResultDef.TypeName);
            { maybe warn in case it's not using "packrecords c"? }
            recorddef:
              if not AIsCVarArgs then
                CGMessagePos1(ANode.FileInfo,type_e_wrong_type_in_array_constructor,ANode.ResultDef.TypeName);
            pointerdef:
              ;
            classrefdef:
              if AIsCVarArgs then
                ANode:=CTypeConvNode.Create(ANode,VoidPointerType);
            objectdef :
              if Is_ObjC_Class_Or_Protocol(ANode.ResultDef) then
                ANode:=CTypeConvNode.Create(ANode,VoidPointerType)
              else if AIsCVarArgs or
                 Is_Object(ANode.ResultDef) then
                CGMessagePos1(ANode.FileInfo,type_e_wrong_type_in_array_constructor,ANode.ResultDef.TypeName)
              else
            else
              CGMessagePos1(ANode.FileInfo,type_e_wrong_type_in_array_constructor,ANode.ResultDef.TypeName);
          end;
        TypeCheckPass(ANode);
      end;


    { in FPC mode, @procname immediately has to be evaluated as a
      procvar. If procname is global, then this will be a global
      procvar. Since converting global procvars to local procvars is
      not allowed (see point d in defcmp.proc_to_procvar_equal()),
      this results in errors when passing global procedures to local
      procvar parameters or assigning them to nested procvars. The
      solution is to remove the (wrong) conversion to a global procvar,
      and instead insert a conversion to the local procvar type. }
    function Maybe_Global_Proc_To_Nested(var AFromNode: TNode; AToDef: TDef): Boolean;
      var
        lNode: TNode;
      begin
        Result:=false;
        if (m_nested_procvars in CurrentSettings.ModeSwitches) and
           not(m_tp_procvar in CurrentSettings.ModeSwitches) and
           (AToDef.typ=procvardef) and
           Is_Nested_PD(TProcVarDef(AToDef)) and
           (AFromNode.NodeType=typeconvn) and
           (TTypeConvNode(AFromNode).ConvType=tc_proc_2_procvar) and
           not Is_Nested_PD(TProcVarDef(AFromNode.ResultDef)) and
           (Proc_To_ProcVar_Equal(TProcDef(TTypeConvNode(AFromNode).Left.ResultDef),TProcVarDef(AToDef),false)>=te_convert_l1) then
          begin
            lNode:=AFromNode;
            AFromNode:=CTypeConvNode.Create_Proc_To_ProcVar(TTypeConvNode(AFromNode).Left);
            TTypeConvNode(AFromNode).ToTypeDef:=AToDef;
            TypeCheckPass(AFromNode);
            TTypeConvNode(lNode).Left:=nil;
            lNode.free;
            lNode := nil;
            Result:=true;
          end;
      end;


    { similar as above, but for assigning @classtype.method to a
      procvar of object. pexpr.do_proc_call() stores the symtable of classtype
      in the loadnode so we can retrieve it here (rather than the symtable in
      which method was found, which may be a parent class) }
    function MaybeClassMethodToMethodProcVar(var AFromNode: TNode; AToDef: TDef): Boolean;
      var
        lNode: TNode;
      begin
        Result:=false;
        if not(m_tp_procvar in CurrentSettings.ModeSwitches) and
           (AToDef.typ=procvardef) and
           Is_MethodPointer(TProcVarDef(AToDef)) and
           (AFromNode.NodeType=typeconvn) and
           (TTypeConvNode(AFromNode).ConvType=tc_proc_2_procvar) and
           Is_MethodPointer(AFromNode.ResultDef) and
           (po_classmethod in TProcVarDef(AFromNode.ResultDef).ProcOptions) and
           not(po_staticmethod in TProcVarDef(AFromNode.ResultDef).ProcOptions) and
           (Proc_To_ProcVar_Equal(TProcDef(TTypeConvNode(AFromNode).Left.ResultDef),TProcVarDef(AToDef),false)>=te_convert_l1) then
          begin
            lNode:=AFromNode;
            AFromNode:=TTypeConvNode(AFromNode).Left;
            if (AFromNode.NodeType=loadn) and
               not Assigned(TLoadNode(AFromNode).Left) then
              TLoadNode(AFromNode).Set_MP(CLoadVMTAddrNode.Create(CTypeNode.Create(TDef(TLoadNode(AFromNode).SymTable.DefOwner))));
            AFromNode:=CTypeConvNode.Create_Proc_To_ProcVar(AFromNode);
            TTypeConvNode(AFromNode).ToTypeDef:=AToDef;
            TypeCheckPass(AFromNode);
            TTypeConvNode(lNode).Left:=nil;
            lNode.free;
            lNode := nil;
            Result:=true;
          end;
      end;

{*****************************************************************************
                           TTYPECONVNODE
*****************************************************************************}


    constructor TTypeConvNode.Create(ANode : TNode;ADef:TDef);

      begin
         inherited Create(typeconvn,ANode);
         ConvType:=tc_none;
         ConvNodeFlags:=[];
         ToTypeDef:=ADef;
         if ADef=nil then
          InternalError(200103281);
         FileInfo:=ANode.FileInfo;
         {An attempt to convert the result of a floating point division
          (with the / operator) to an integer type will fail. Give a hint
          to use the div operator.}
         if (ANode.NodeType=slashn) and (ADef.typ=orddef) and not(Is_Currency(ADef)) then
           CGMessage(type_h_use_div_for_int);
         {In expressions like int64:=longint+longint, an integer overflow could be avoided
          by simply converting the operands to int64 first. Give a hint to do this.}
         if (ANode.NodeType in [addn,subn,muln]) and
            (ADef.typ=orddef) and (ANode.ResultDef<>nil) and (ANode.ResultDef.typ=orddef) and
            ((TOrdDef(ANode.ResultDef).low>=TOrdDef(ADef).low) and (TOrdDef(ANode.ResultDef).high<=TOrdDef(ADef).high)) and
            ((TOrdDef(ANode.ResultDef).low>TOrdDef(ADef).low) or (TOrdDef(ANode.ResultDef).high<TOrdDef(ADef).high)) then
           case ANode.NodeType of
             addn:
               CGMessage1(type_h_convert_add_operands_to_prevent_overflow,ADef.TypeName);
             subn:
               CGMessage1(type_h_convert_sub_operands_to_prevent_overflow,ADef.TypeName);
             muln:
               CGMessage1(type_h_convert_mul_operands_to_prevent_overflow,ADef.TypeName);
             else
               ;
           end;
      end;


    constructor TTypeConvNode.Create_Explicit(ANode : TNode;ADef:TDef);

      begin
         Self.Create(ANode,ADef);
         include(Flags,nf_explicit);
      end;


    constructor TTypeConvNode.Create_Internal(ANode : TNode;ADef:TDef);

      begin
         Self.Create(ANode,ADef);
         { handle like explicit conversions }
         include(Flags,nf_explicit);
         include(Flags,nf_internal);
      end;


    constructor TTypeConvNode.Create_Proc_To_ProcVar(ANode : TNode);

      begin
         Self.Create(ANode,VoidType);
         ConvType:=tc_proc_2_procvar;
      end;


    constructor TTypeConvNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        APPUFile.GetDeref(ToTypeDefDeref);
        ConvType:=TConvertType(APPUFile.GetByte);
        APPUFile.GetSet(TPPUSet1(ConvNodeFlags));
      end;


    procedure TTypeConvNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutDeref(ToTypeDefDeref);
        APPUFile.PutByte(Byte(ConvType));
        APPUFile.PutSet(TPPUSet1(ConvNodeFlags));
      end;


    procedure TTypeConvNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        ToTypeDefDeref.Build(ToTypeDef);
      end;


    procedure TTypeConvNode.DerefImpl;
      begin
        inherited DerefImpl;
        ToTypeDef:=TDef(ToTypeDefDeref.resolve);
      end;


    function TTypeConvNode.DoGetCopy : TNode;
      var
         lNode : TTypeConvNode;
      begin
         lNode:=TTypeConvNode(inherited DoGetCopy);
         lNode.ConvType:=ConvType;
         lNode.ConvNodeFlags:=ConvNodeFlags;
         lNode.ToTypeDef:=ToTypeDef;
         lNode.AssignmentSide:=AssignmentSide;
         DoGetCopy:=lNode;
      end;

    procedure TTypeConvNode.PrintNodeInfo(var AText : Text);
      var
        lFirst: Boolean;
        lIndex: TTypeConvNodeFlag;
      begin
        inherited PrintNodeInfo(AText);
        write(AText,', totypedef = ',ToTypeDef.GetTypeName);
        write(AText,', convtype = ',ConvType);
        write(AText,', assignment_side = ',AssignmentSide);
        write(AText,', convnodeflags = [');
        lFirst:=true;
        for lIndex:=low(TTypeConvNodeFlag) to high(TTypeConvNodeFlag) do
          if lIndex in ConvNodeFlags then
            begin
              if not lFirst then
                write(AText,',')
              else
                lFirst:=false;
              write(AText,lIndex);
            end;
        write(AText,']');
      end;


    function TTypeConvNode.TypeCheck_COrd_To_Pointer : TNode;

      begin
        Result:=nil;
        if Left.NodeType=ordconstn then
          begin
            if not(nf_explicit in Flags) then
              if (TOrdConstNode(Left).Value.svalue=0) then
                CGMessage(type_w_zero_to_nil)
              else
                { in Delphi mode, these aren't caught in compare_defs_ext }
                IncompatibleTypes(Left.ResultDef,ResultDef);
            Result:=CPointerConstNode.Create(TConstPtrUInt(TOrdConstNode(Left).Value.uvalue),ResultDef);
          end
         else
          InternalError(200104023);
      end;


    function TTypeConvNode.TypeCheck_CharArray_To_String : TNode;
      var
        lCharType : string[8];
        lNewBlock : TBlockNode;
        lNewStatement  : TStatementNode;
        lResultTemp  : TTempCreateNode;
      begin
        if Is_WideChar(TArrayDef(Left.ResultDef).ElementDef) then
          lCharType:='widechar'
        else
          lCharType:='char';
        if TStringDef(ResultDef).StringType=st_shortstring then
          begin
            lNewBlock:=InternalStatements(lNewStatement);
            lResultTemp:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,false);
            AddStatement(lNewStatement,lResultTemp);
            AddStatement(lNewStatement,CCallNode.CreateIntern('fpc_'+lCharType+'array_to_shortstr',
              CCallParaNode.Create(COrdConstNode.Create(
                ord(TArrayDef(Left.ResultDef).LowRange=0),PasBool1Type,false),
              CCallParaNode.Create(Left,CCallParaNode.Create(
              CTempRefNode.Create(lResultTemp),nil)))));
            AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lResultTemp));
            AddStatement(lNewStatement,CTempRefNode.Create(lResultTemp));
            Result:=lNewBlock;
          end
        else if (TStringDef(ResultDef).StringType=st_ansistring) then
          begin
            Result:=CCallNode.CreateInternRes(
                      'fpc_'+lCharType+'array_to_'+TStringDef(ResultDef).StringTypName,
                      CCallParaNode.Create(
                        COrdConstNode.Create(
                          ord(TArrayDef(Left.ResultDef).LowRange=0),
                          PasBool1Type,
                          false
                        ),
                        CCallParaNode.Create(
                          COrdConstNode.Create(
                            GetParaEncoding(ResultDef),
                            U16IntType,
                            true
                          ),
                          CCallParaNode.Create(Left,nil)
                        )
                      ),
                      ResultDef
                    );
          end
        else
          Result:=CCallNode.CreateInternRes(
            'fpc_'+lCharType+'array_to_'+TStringDef(ResultDef).StringTypName,
            CCallParaNode.Create(COrdConstNode.Create(
               ord(TArrayDef(Left.ResultDef).LowRange=0),PasBool1Type,false),
             CCallParaNode.Create(Left,nil)),ResultDef);
        Left:=nil;
      end;


    function TTypeConvNode.TypeCheck_String_To_CharArray : TNode;
      var
        lNewBlock : TBlockNode;
        lNewStatement  : TStatementNode;
        lResultTemp  : TTempCreateNode;
        lCharPointer  : PChar;
        lArraySize  : TCGInt;
        lCharType : string[8];

      begin
        Result := nil;
        with TArrayDef(ResultDef) do
          begin
            if HighRange<LowRange then
             InternalError(2005010502);
            lArraySize := HighRange-LowRange+1;
          end;
        if (Left.NodeType = stringconstn) and
           (TStringConstNode(Left).ConstStringType=cst_conststring) then
           begin
             if (m_iso in CurrentSettings.ModeSwitches) and (lArraySize<>TStringConstNode(Left).len) and
                Is_Char(TArrayDef(ResultDef).ElementDef) then
               Message2(type_w_array_size_does_not_match_size_of_constant_string,ToStr(TStringConstNode(Left).len),ToStr(lArraySize));
             { if the array of char is large enough we can use the string
               constant directly. This is handled in ncgcnv }
             if (lArraySize>=TStringConstNode(Left).len) and
                Is_Char(TArrayDef(ResultDef).ElementDef) then
               begin
                 { pad the constant string with #0 to the array len }
                 { (2.0.x compatible)                               }
                 if (lArraySize>TStringConstNode(Left).len) then
                   begin
                     lCharPointer:=ConcatAnsiStrings(TStringConstNode(Left).AsConstPChar,PChar(StringOfChar(#0,lArraySize-TStringConstNode(Left).len)),TStringConstNode(Left).len,lArraySize-TStringConstNode(Left).len);
                     Left.free;
                     Left:=CStringConstNode.CreatePChar(lCharPointer,lArraySize,nil);
                     FreeMem(lCharPointer);
                     TypeCheckPass(Left);
                   end;
                 exit;
               end;
             { Convert to wide/short/ansistring and call default helper }
             if Is_WideChar(TArrayDef(ResultDef).ElementDef) then
               InsertTypeConv(Left,CUnicodeStringType)
             else
               begin
                 if TStringConstNode(Left).len>255 then
                   InsertTypeConv(Left,GetAnsiStringDef)
                 else
                   InsertTypeConv(Left,CShortStringType);
               end;
           end;
        if Is_WideChar(TArrayDef(ResultDef).ElementDef) then
          lCharType:='widechar'
        else
          lCharType:='char';
        lNewBlock:=InternalStatements(lNewStatement);
        lResultTemp:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,false);
        AddStatement(lNewStatement,lResultTemp);
        AddStatement(lNewStatement,CCallNode.CreateIntern('fpc_'+TStringDef(Left.ResultDef).StringTypName+
          '_to_'+lCharType+'array',CCallParaNode.Create(Left,CCallParaNode.Create(
          CTempRefNode.Create(lResultTemp),nil))));
        AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lResultTemp));
        AddStatement(lNewStatement,CTempRefNode.Create(lResultTemp));
        Result:=lNewBlock;
        Left:=nil;
      end;


    function TTypeConvNode.TypeCheck_Char_To_String : TNode;
      var
        lProcName: string[31];
        lPara : TCallParaNode;
        lStringNode : TStringConstNode;
        lWideString : TCompilerWideString;
        lAnsiString : AnsiString;
        lWideChar : TCompilerWideChar;
        lLength : SizeUInt;
        lExprType : TDef;
      begin
         Result:=nil;
         lAnsiString:='';
         if (Left.NodeType=ordconstn) and
            ((TStringDef(ResultDef).StringType in [st_widestring,st_unicodestring,st_ansistring]) or
             (TOrdDef(Left.ResultDef).OrdType in [uchar,uwidechar])) then
           begin
              if (TStringDef(ResultDef).StringType in [st_widestring,st_unicodestring]) then
               begin
                 InitWideString(lWideString);
                 if TOrdDef(Left.ResultDef).OrdType=uwidechar then
                   ConcatWideStringChar(lWideString,TCompilerWideChar(TOrdConstNode(Left).Value.uvalue))
                 else
                   ConcatWideStringChar(lWideString,ASCIIChar2Unicode(chr(TOrdConstNode(Left).Value.uvalue)));
                 lStringNode:=CStringConstNode.CreateUniStr(lWideString);
                 lStringNode.ChangeStringType(ResultDef);
                 DoneWideString(lWideString);
               end
              else
                begin
                  if (TOrdDef(Left.ResultDef).OrdType=uwidechar) then
                    begin
                      if not((CurrentSettings.SourceCodePage=CP_UTF8) or
                             ((TStringDef(ResultDef).StringType=st_ansistring) and
                              (TStringDef(ResultDef).encoding=CP_UTF8))) then
                        begin
                          if TOrdConstNode(Left).Value.uvalue>127 then
                            begin
                              Message(type_w_unicode_data_loss);
                              // compiler has different codepage than a system running an application
                              // to prevent wrong codepage and data loss we are converting unicode char
                              // using a helper routine. This is not delphi compatible behavior.
                              // Delphi converts UniocodeChar to ansistring at the compile time
                              // old behavior:
                              // hp:=cstringconstnode.createstr(unicode2asciichar(tcompilerwidechar(tordconstnode(left).value.uvalue)));
                              lPara:=CCallParaNode.Create(Left,nil);
                              if TStringDef(ResultDef).StringType=st_ansistring then
                                lPara:=CCallParaNode.Create(COrdConstNode.Create(GetParaEncoding(ResultDef),U16IntType,true),lPara);
                              Result:=CCallNode.CreateInternRes('fpc_uchar_to_'+TStringDef(ResultDef).StringTypName,
                                lPara,ResultDef);
                              Left:=nil;
                              exit;
                            end
                          else
                            lStringNode:=CStringConstNode.CreateStr(Unicode2ASCIIChar(TCompilerWideChar(TOrdConstNode(Left).Value.uvalue)));
                        end
                      else
                        begin
                          lWideChar:=TCompilerWideChar(TOrdConstNode(Left).Value.uvalue);
                          SetLength(lAnsiString,5);
                          lLength:=UnicodeToUtf8(@(lAnsiString[1]),Length(lAnsiString),@lWideChar,1);
                          SetLength(lAnsiString,lLength-1);
                          lStringNode:=CStringConstNode.CreateStr(lAnsiString);
                          { explicitly set the type of string constant to avoid unnecessary conversion }
                          if (TStringDef(ResultDef).StringType=st_ansistring) and
                             (TStringDef(ResultDef).encoding=CP_UTF8) then
                            begin
                              lStringNode.ConstStringType:=cst_ansistring;
                              lStringNode.ResultDef:=ResultDef;
                            end;
                        end
                    end
                  else
                    lStringNode:=CStringConstNode.CreateStr(chr(TOrdConstNode(Left).Value.uvalue));
                  { output string consts in local ansistring encoding }
                  if Is_AnsiString(ResultDef) and ((TStringDef(ResultDef).encoding=0) or (TStringDef(ResultDef).encoding=Globals.CP_NONE)) then
                    TStringConstNode(lStringNode).ChangeStringType(GetAnsiStringDef)
                  else
                    TStringConstNode(lStringNode).ChangeStringType(ResultDef);
                end;
              Result:=lStringNode;
           end
         else
           { shortstrings are handled 'inline' (except for widechars) }
           if (TStringDef(ResultDef).StringType<>st_shortstring) or
              (TOrdDef(Left.ResultDef).OrdType=uwidechar) then
             begin
               { parameter }
               lPara:=CCallParaNode.Create(Left,nil);
               { encoding required? }
               if TStringDef(ResultDef).StringType=st_ansistring then
                 lPara:=CCallParaNode.Create(COrdConstNode.Create(GetParaEncoding(ResultDef),U16IntType,true),lPara);

               { create the procname }
               if TOrdDef(Left.ResultDef).OrdType<>uwidechar then
                 begin
                   lProcName:='fpc_char_to_';
                   if TStringDef(ResultDef).StringType in [st_widestring,st_unicodestring] then
                     if nf_explicit in Flags then
                       Message2(type_w_explicit_string_cast,Left.ResultDef.TypeName,ResultDef.TypeName)
                     else
                       Message2(type_w_implicit_string_cast,Left.ResultDef.TypeName,ResultDef.TypeName);
                 end
               else
                 begin
                   lProcName:='fpc_uchar_to_';
                   if not (TStringDef(ResultDef).StringType in [st_widestring,st_unicodestring]) then
                     if nf_explicit in Flags then
                       Message2(type_w_explicit_string_cast_loss,Left.ResultDef.TypeName,ResultDef.TypeName)
                     else
                       Message2(type_w_implicit_string_cast_loss,Left.ResultDef.TypeName,ResultDef.TypeName);
                 end;
               lProcName:=lProcName+TStringDef(ResultDef).StringTypName;

               { and finally the call }
               Result:=CCallNode.CreateInternRes(lProcName,lPara,ResultDef);
               Left := nil;
             end
           else
             begin
               { use at least u16inttype }

               lExprType:=UIntType;

               { create word(byte(char) shl 8 or 1) for little endian machines}

               Left := CTypeConvNode.Create_Internal(Left,lExprType);
               Left := CAddNode.Create(orn,
                   CShlShrNode.Create(shln,Left,COrdConstNode.Create(8,lExprType,false)),
                   COrdConstNode.Create(1,lExprType,false));
               Left := CTypeConvNode.Create_Internal(Left,U16IntType);
               TypeCheckPass(Left);
             end;
      end;

    function TTypeConvNode.TypeCheck_String_To_String : TNode;
      begin
        Result:=nil;
        if (Left.NodeType=stringconstn) and
           (((TStringDef(ResultDef).StringType=st_ansistring) and
             (TStringDef(ResultDef).encoding<>CP_NONE)
            )
           ) and
           (TStringDef(Left.ResultDef).StringType in [st_unicodestring,st_widestring]) then
          begin
            TStringConstNode(Left).ChangeStringType(ResultDef);
            Result:=Left;
            Left:=nil;
          end
        else if (TStringDef(ResultDef).StringType=st_ansistring) and
                (TStringDef(Left.ResultDef).StringType=st_ansistring) and
                (TStringDef(ResultDef).encoding<>TStringDef(Left.ResultDef).encoding) then
          begin
            Result:=CCallNode.CreateInternRes(
                      'fpc_ansistr_to_ansistr',
                      CCallParaNode.Create(
                        COrdConstNode.Create(
                          TStringDef(ResultDef).encoding,
                          U16IntType,
                          true
                        ),
                        CCallParaNode.Create(Left,nil)
                      ),
                      ResultDef
                    );
            Left:=nil;
          end
        else if (Left.NodeType=stringconstn) and
                (TStringDef(Left.ResultDef).StringType in [st_unicodestring,st_widestring]) and
                (TStringDef(ResultDef).StringType=st_shortstring) then
          begin
            if not HasNonASCIIChars(TStringConstNode(Left).ValueWS) then
              begin
                TStringConstNode(Left).ChangeStringType(ResultDef);
                Result:=Left;
                Left:=nil;
              end;
          end
        else if (TStringDef(Left.ResultDef).StringType in [st_unicodestring,st_widestring]) and
                not (TStringDef(ResultDef).StringType in [st_unicodestring,st_widestring]) then
          begin
            if nf_explicit in Flags then
              Message2(type_w_explicit_string_cast_loss,Left.ResultDef.TypeName,ResultDef.TypeName)
            else
              Message2(type_w_implicit_string_cast_loss,Left.ResultDef.TypeName,ResultDef.TypeName);
          end
        else if not (TStringDef(Left.ResultDef).StringType in [st_unicodestring,st_widestring]) and
                (TStringDef(ResultDef).StringType in [st_unicodestring,st_widestring]) then
          begin
            if nf_explicit in Flags then
              Message2(type_w_explicit_string_cast,Left.ResultDef.TypeName,ResultDef.TypeName)
            else
              Message2(type_w_implicit_string_cast,Left.ResultDef.TypeName,ResultDef.TypeName);
          end
      end;

    function TTypeConvNode.TypeCheck_Char_To_CharArray : TNode;
      begin
        Result:=nil;
      end;


    function TTypeConvNode.TypeCheck_Char_To_Char : TNode;
      var
        lOrdNode : TOrdConstNode;
      begin
         Result:=nil;
         if (Left.NodeType=ordconstn) and
            ((TOrdDef(ResultDef).OrdType<>uchar) or
             (TOrdDef(Left.ResultDef).OrdType<>uwidechar) or
             (CurrentSettings.SourceCodePage<>CP_UTF8))
         then
           begin
             if (TOrdDef(ResultDef).OrdType=uchar) and
                (TOrdDef(Left.ResultDef).OrdType=uwidechar) and
                (CurrentSettings.SourceCodePage<>CP_UTF8) then
              begin
                if TOrdConstNode(Left).Value.uvalue>127 then
                  Message(type_w_unicode_data_loss);
                lOrdNode:=COrdConstNode.Create(
                      ord(Unicode2ASCIIChar(TCompilerWideChar(TOrdConstNode(Left).Value.uvalue))),
                      CAnsiCharType,true);
                Result:=lOrdNode;
              end
             else if (TOrdDef(ResultDef).OrdType=uwidechar) and
                     (TOrdDef(Left.ResultDef).OrdType=uchar) then
              begin
                lOrdNode:=COrdConstNode.Create(
                      ASCIIChar2Unicode(chr(TOrdConstNode(Left).Value.uvalue)),
                      CWideCharType,true);
                Result:=lOrdNode;
              end
             else
              InternalError(200105131);
             exit;
           end;
      end;


    function TTypeConvNode.TypeCheck_Int_To_Int : TNode;
      var
        lValue : TConstExprInt;
        lNode : TNode;
        lSetCurrencyFlag: Boolean;
      begin
        lSetCurrencyFlag:=False;
        Result:=nil;
        if Left.NodeType=ordconstn then
         begin
           lValue:=TOrdConstNode(Left).Value;
           if Is_Currency(ResultDef) and
              (nf_is_currency in Flags) and
              not(nf_internal in Flags) then
             begin
               if not(nf_is_currency in Left.Flags) then
                 lValue:=lValue*10000;
               lSetCurrencyFlag:=True;
             end;
           if (ResultDef.typ=pointerdef) then
             Result:=CPointerConstNode.Create(TConstPtrUInt(lValue.uvalue),ResultDef)
           else
             begin
               if (nf_is_currency in Left.Flags) and
                 Is_Currency(Left.ResultDef) then
                 begin
                  if not(nf_internal in Flags) and
                    not(nf_is_currency in Flags) then
                    lValue:=lValue div 10000;
                 end
               else if (ResultDef.typ in [orddef,enumdef]) then
                 AdaptRange(ResultDef,lValue,([nf_internal,nf_absolute]*Flags)<>[],nf_explicit in Flags,cs_check_range in LocalSwitches);
               Result:=COrdConstNode.Create(lValue,ResultDef,false);
             end;

           if lSetCurrencyFlag then
             Include(Result.Flags, nf_is_currency);
         end
        else if Left.NodeType=pointerconstn then
         begin
           lValue:=TPointerConstNode(Left).Value;
           if (ResultDef.typ=pointerdef) then
             Result:=CPointerConstNode.Create(lValue.uvalue,ResultDef)
           else
             begin
               if (nf_is_currency in Flags) and
                 Is_Currency(ResultDef) and
                  not(nf_internal in Flags) then
                 lValue:=lValue*10000;
               Result:=COrdConstNode.Create(lValue,ResultDef,false);
             end;
         end
        else
         if not (nf_internal in Flags) then
          begin
           { multiply by 10000 for currency. We need to use getcopy to pass
             the argument because the current node is always disposed. Only
             inserting the multiply in the left node is not possible because
             it'll get in an infinite loop to convert int->currency }
           if (nf_is_currency in Flags) and not (nf_is_currency in Left.Flags) then
            begin
              lNode:=GetCopy;
              Result:=CAddNode.Create(muln,lNode,COrdConstNode.Create_Currency_Scalar(ResultDef));
              include(Result.Flags,nf_is_currency);
              exclude(lNode.Flags,nf_is_currency);
              include(lNode.Flags,nf_internal);
            end
           else if not (nf_is_currency in Flags) and (nf_is_currency in Left.Flags) then
            begin
              lNode:=GetCopy;
              Result:=CModDivNode.Create(divn,lNode,COrdConstNode.Create_Currency_Scalar(ResultDef));
              include(lNode.Flags,nf_is_currency);
              include(lNode.Flags,nf_internal);
            end;
         end;
      end;


    function TTypeConvNode.TypeCheck_Int_To_Real : TNode;
      var
        lRealValue : BestReal;
        lNode : TNode;
        lSetCurrencyFlag: Boolean;
      begin
        Result:=nil;
        if Left.NodeType=ordconstn then
         begin
           lRealValue:=TOrdConstNode(Left).Value;

           if not(nf_internal in Flags) then
             begin
               lSetCurrencyFlag:=(nf_is_currency in Flags); { Make sure the flag gets preserved }

               if (nf_is_currency in Flags) and Is_Currency(ResultDef) then
                 begin
                   if not(nf_is_currency in Left.Flags) then
                     begin
                       lRealValue:=lRealValue*BestReal(10000.0);
                       lSetCurrencyFlag:=True;
                     end
                 end
               else if Is_Currency(Left.ResultDef) and
                 (nf_is_currency in Left.Flags) and
                 not lSetCurrencyFlag then
                 lRealValue:=lRealValue/BestReal(10000.0);
             end
           else
             lSetCurrencyFlag:=False;

           Result:=CRealConstNode.Create(lRealValue,ResultDef);
           if lSetCurrencyFlag then
             include(Result.Flags,nf_is_currency)
         end
        else if not(nf_internal in Flags) then
         begin
           { multiply by 10000 for currency. We need to use getcopy to pass
             the argument because the current node is always disposed. Only
             inserting the multiply in the left node is not possible because
             it'll get in an infinite loop to convert int->currency }
           if Is_Currency(ResultDef) and
             not (nf_is_currency in Left.Flags) then
            begin
              lNode:=GetCopy;
              Exclude(lNode.Flags,nf_is_currency);
              Result:=CAddNode.Create(muln,lNode,CRealConstNode.Create_Currency_Scalar(ResultDef));
              Include(Result.Flags,nf_is_currency);
            end
           else if Is_Currency(Left.ResultDef) and
            (nf_is_currency in Left.Flags) and
            not (nf_is_currency in Flags) then
            begin
              lNode:=GetCopy;
              Include(lNode.Flags,nf_is_currency);
              Result:=CAddNode.Create(slashn,lNode,CRealConstNode.Create_Currency_Scalar(ResultDef));
            end;
         end;
      end;


    function TTypeConvNode.TypeCheck_Real_To_Currency : TNode;
      var
        lNode: TNode;
      begin
        if not Is_Currency(ResultDef) then
          InternalError(200304221);

        { Convert constants directly, else call Round() }
        if Left.NodeType=realconstn then
          begin
            Result:=COrdConstNode.Create(TRealConstNode(Left).CurrencyScaledValue,ResultDef,false);
            include(Result.Flags,nf_is_currency);
          end
        else
          begin
            if not (nf_is_currency in Left.Flags) then
              begin
                Left:=CAddNode.Create(muln,Left,CRealConstNode.Create_Currency_Scalar(Left.ResultDef));
                include(Left.Flags,nf_is_currency);
              end;

            Result:=CInlineNode.Create(in_round_real,false,Left);
            include(Result.Flags,nf_is_currency);
            { Internal type cast to currency }
            Result:=CTypeConvNode.Create_Internal(Result,S64CurrencyType);
            include(Result.Flags,nf_is_currency);
            Left:=nil;
          end;
      end;


    function TTypeConvNode.TypeCheck_Real_To_Real : TNode;
      begin
         Result:=nil;
         if not(nf_internal in Flags) then
           begin
             if not (nf_is_currency in Flags) and not(Is_Currency(ResultDef))
               and (nf_is_currency in Left.Flags) and Is_Currency(Left.ResultDef) then
               begin
                 Left:=CAddNode.Create_Internal(slashn,Left,CRealConstNode.Create_Currency_Scalar(Left.ResultDef));
                 TypeCheckPass(Left);
               end
             else
               if (nf_is_currency in Flags) and Is_Currency(ResultDef) and
                 not (nf_is_currency in Left.Flags) then { Regardless of whether or not the type is Currency }
                 begin
                   Left:=CAddNode.Create_Internal(muln,Left,CRealConstNode.Create_Currency_Scalar(Left.ResultDef));
                   include(Left.Flags,nf_is_currency);
                   TypeCheckPass(Left);
                 end;
             { comp is handled by the fpu but not a floating type point }
             if Is_FPUComp(ResultDef) and not(Is_FPUComp(Left.ResultDef)) and
               not (nf_explicit in Flags) then
               Message(type_w_convert_real_2_comp);
           end;
      end;


    function TTypeConvNode.TypeCheck_CChar_To_PChar : TNode;

      begin
         Result:=nil;
         { handle any constants via cunicodestringtype because the compiler
           cannot convert arbitrary unicodechar constants at compile time to
           a shortstring (since it doesn't know the code page to use) }
         InsertTypeConv(Left,CUnicodeStringType);
         { evaluate again, reset resultdef so the convert_typ
           will be calculated again and cstring_to_pchar will
           be used for further conversion }
         ConvType:=tc_none;
         Result:=Pass_TypeCheck;
      end;


    function TTypeConvNode.TypeCheck_CString_To_PChar : TNode;

      begin
         Result:=nil;
         if Is_PWideChar(ResultDef) then
           InsertTypeConv(Left,CUnicodeStringType)
         else
           if Is_PChar(ResultDef) and
              (Is_WideString(Left.ResultDef) or
               Is_UnicodeString(Left.ResultDef)) then
             begin
               InsertTypeConv(Left,GetAnsiStringDef);
               { the second pass of second_cstring_to_pchar expects a  }
               { strinconstn, but this may become a call to the        }
               { widestring manager in case left contains "high ascii" }
               if (Left.NodeType<>stringconstn) then
                 begin
                   Result:=Left;
                   Left:=nil;
                 end;
             end;
      end;


    function TTypeConvNode.TypeCheck_CString_To_Int : TNode;
      var
        lFourCharCode : Cardinal;
        lBytePointer  : PByte;
      begin
         Result:=nil;
         if Left.NodeType<>stringconstn then
           InternalError(200510012);
         if (m_mac in CurrentSettings.ModeSwitches) and
            Is_Integer(ResultDef) and
            (TStringConstNode(Left).ConstStringType=cst_conststring) and
            (TStringConstNode(Left).len=4) then
           begin
             lBytePointer:=PByte(TStringConstNode(Left).AsConstPChar);
             lFourCharCode:=(lBytePointer[0] shl 24) or (lBytePointer[1] shl 16) or (lBytePointer[2] shl 8) or lBytePointer[3];
             Result:=COrdConstNode.Create(lFourCharCode,U32IntType,false);
           end
         else
           CGMessage2(type_e_illegal_type_conversion,Left.ResultDef.TypeName,ResultDef.TypeName);
      end;


    function TTypeConvNode.TypeCheck_ArrayConstructor_To_Set : TNode;
      var
        lNode : TNode;
      begin
        Result:=nil;
        if Left.NodeType<>arrayconstructorn then
         InternalError(5546);
        { remove typeconv node }
        lNode:=Left;
        Left:=nil;
        { create a set constructor tree }
        ArrayConstructor_To_Set(lNode);
        if Is_EmptySet(lNode) then
          begin
            { enforce the result type for an empty set }
            lNode.ResultDef:=ResultDef;
            Result:=lNode;
          end
        else if lNode.ResultDef<>ResultDef then
          begin
            { the set might contain a subrange element (e.g. through a variable),
              thus we need to insert another type conversion }
            if nf_explicit in Flags then
              Result:=CTypeConvNode.Create_Explicit(lNode,ToTypeDef)
            else if nf_internal in Flags then
              Result:=CTypeConvNode.Create_Internal(lNode,ToTypeDef)
            else
              Result:=CTypeConvNode.Create(lNode,ToTypeDef);
          end
        else
          Result:=lNode;
      end;


    function TTypeConvNode.TypeCheck_Set_To_Set : TNode;
      begin
        Result:=nil;
        { constant sets can be converted by changing the type only }
        if (Left.NodeType=setconstn) then
         begin
           if (cs_check_range in CurrentSettings.LocalSwitches) and (TSetConstNode(Left).elements>0) and ((TSetConstNode(Left).low<TSetDef(ResultDef).SetLow) or (TSetConstNode(Left).high>TSetDef(ResultDef).SetMax)) then
             Message(parser_e_range_check_error);

           Left.ResultDef:=ResultDef;
           Result:=Left;
           Left:=nil;
           exit;
         end;
      end;


    function TTypeConvNode.TypeCheck_PChar_To_String : TNode;
      var
        lNewBlock : TBlockNode;
        lNewStatement  : TStatementNode;
        lResultTemp  : TTempCreateNode;
      begin
        if TStringDef(ResultDef).StringType=st_shortstring then
          begin
            lNewBlock:=InternalStatements(lNewStatement);
            lResultTemp:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,false);
            AddStatement(lNewStatement,lResultTemp);
            AddStatement(lNewStatement,CCallNode.CreateIntern('fpc_pchar_to_shortstr',CCallParaNode.Create(Left,CCallParaNode.Create(
              CTempRefNode.Create(lResultTemp),nil))));
            AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lResultTemp));
            AddStatement(lNewStatement,CTempRefNode.Create(lResultTemp));
            Result:=lNewBlock;
          end
        else if TStringDef(ResultDef).StringType=st_ansistring then
          Result := CCallNode.CreateInternRes(
                      'fpc_pchar_to_'+TStringDef(ResultDef).StringTypName,
                      CCallParaNode.Create(
                        COrdConstNode.Create(GetParaEncoding(ResultDef),U16IntType,true),
                        CCallParaNode.Create(Left,nil)
                      ),
                      ResultDef
                    )
        else
          Result := CCallNode.CreateInternRes(
            'fpc_pchar_to_'+TStringDef(ResultDef).StringTypName,
            CCallParaNode.Create(Left,nil),ResultDef);
        Left:=nil;
      end;


    function TTypeConvNode.TypeCheck_Interface_To_String : TNode;
      begin
        if Assigned(TObjectDef(Left.ResultDef).IIDStr) then
          begin
            if not(oo_has_valid_guid in TObjectDef(Left.ResultDef).ObjectOptions) then
              CGMessage1(type_e_interface_has_no_name,TObjectDef(Left.ResultDef).TypeName);
            Result:=CStringConstNode.CreateStr(TObjectDef(Left.ResultDef).IIDStr^);
            TStringConstNode(Result).ChangeStringType(ResultDef);
          end
        else
          InternalError(2013112913);
      end;


    function TTypeConvNode.TypeCheck_Interface_To_GUID : TNode;
      begin
        if Assigned(TObjectDef(Left.ResultDef).IIDGUID) then
          begin
            if not(oo_has_valid_guid in TObjectDef(Left.ResultDef).ObjectOptions) then
              CGMessage1(type_e_interface_has_no_guid,TObjectDef(Left.ResultDef).TypeName);
            Result:=CGUIDConstNode.Create(TObjectDef(Left.ResultDef).IIDGUID^);
          end
        else
          InternalError(2013112914);
      end;


    function TTypeConvNode.TypeCheck_DynArray_To_OpenArray : TNode;
      begin
        if (ActualTargetNode(@Left)^.NodeType in [pointerconstn,niln]) then
          CGMessage(type_e_no_addr_of_constant);
        { a dynamic array is a pointer to an array, so to convert it to }
        { an open array, we have to dereference it (JM)                 }
        Result:=CTypeConvNode.Create_Internal(Left,CPointerDef.getreusable(ResultDef));
        TypeCheckPass(Result);
        { left is reused }
        Left:=nil;
        Result:=CDerefNode.Create(Result);
        include(TDerefNode(Result).DerefNodeFlags,drnf_no_checkpointer);
      end;


    function TTypeConvNode.TypeCheck_PWChar_To_String : TNode;
      var
        lNewBlock : TBlockNode;
        lNewStatement  : TStatementNode;
        lResultTemp  : TTempCreateNode;
      begin
        if TStringDef(ResultDef).StringType=st_shortstring then
          begin
            lNewBlock:=InternalStatements(lNewStatement);
            lResultTemp:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,false);
            AddStatement(lNewStatement,lResultTemp);
            AddStatement(lNewStatement,CCallNode.CreateIntern('fpc_pwidechar_to_shortstr',CCallParaNode.Create(Left,CCallParaNode.Create(
              CTempRefNode.Create(lResultTemp),nil))));
            AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lResultTemp));
            AddStatement(lNewStatement,CTempRefNode.Create(lResultTemp));
            Result:=lNewBlock;
          end
        else if TStringDef(ResultDef).StringType=st_ansistring then
          begin
            Result:=CCallNode.CreateInternRes(
                        'fpc_pwidechar_to_'+TStringDef(ResultDef).StringTypName,
                         CCallParaNode.Create(
                           COrdConstNode.Create(
                             GetParaEncoding(ResultDef),
                             U16IntType,
                             true
                           ),
                           CCallParaNode.Create(Left,nil)
                         ),
                         ResultDef
                      );
          end
        else
          Result := CCallNode.CreateInternRes(
            'fpc_pwidechar_to_'+TStringDef(ResultDef).StringTypName,
            CCallParaNode.Create(Left,nil),ResultDef);
        Left:=nil;
      end;


    function TTypeConvNode.TypeCheck_Variant_To_DynArray : TNode;
      begin
        Result := CCallNode.CreateInternRes(
          'fpc_variant_to_dynarray',
          CCallParaNode.Create(CAddrNode.Create_Internal(CRTTINode.Create(TStoredDef(ResultDef),initrtti,rdt_normal)),
            CCallParaNode.Create(Left,nil)
          ),ResultDef);
        TypeCheckPass(Result);
        Left:=nil;
      end;


    function TTypeConvNode.TypeCheck_DynArray_To_Variant : TNode;
      begin
        Result := CCallNode.CreateInternRes(
          'fpc_dynarray_to_variant',
          CCallParaNode.Create(CAddrNode.Create_Internal(CRTTINode.Create(TStoredDef(Left.ResultDef),initrtti,rdt_normal)),
            CCallParaNode.Create(CTypeConvNode.Create_Explicit(Left,VoidPointerType),nil)
          ),ResultDef);
        TypeCheckPass(Result);
        Left:=nil;
      end;


    function TTypeConvNode.TypeCheck_Variant_To_Interface : TNode;
      begin
        if Def_Is_Related(TObjectDef(ResultDef),TObjectDef(Search_System_Type('IDISPATCH').TypeDef)) then
          Result := CCallNode.CreateInternRes(
            'fpc_variant_to_idispatch',
              CCallParaNode.Create(Left,nil)
            ,ResultDef)
        else
          Result := CCallNode.CreateInternRes(
            'fpc_variant_to_interface',
              CCallParaNode.Create(Left,nil)
            ,ResultDef);
        TypeCheckPass(Result);
        Left:=nil;
      end;


    function TTypeConvNode.TypeCheck_Interface_To_Variant : TNode;
      begin
        if Def_Is_Related(TObjectDef(Left.ResultDef),TObjectDef(Search_System_Type('IDISPATCH').TypeDef)) then
          Result := CCallNode.CreateInternRes(
            'fpc_idispatch_to_variant',
              CCallParaNode.Create(Left,nil)
            ,ResultDef)
        else
          Result := CCallNode.CreateInternRes(
            'fpc_interface_to_variant',
              CCallParaNode.Create(Left,nil)
            ,ResultDef);
        TypeCheckPass(Result);
        Left:=nil;
      end;


    function TTypeConvNode.TypeCheck_Variant_To_Enum : TNode;

      begin
        Result := CTypeConvNode.Create_Internal(Left,SIntType);
        Result := CTypeConvNode.Create_Internal(Result,ResultDef);
        TypeCheckPass(Result);
        { left is reused }
        Left := nil;
      end;


    function TTypeConvNode.TypeCheck_Enum_To_Variant : TNode;

      begin
        Result := CTypeConvNode.Create_Internal(Left,SIntType);
        Result := CTypeConvNode.Create_Internal(Result,CVariantType);
        TypeCheckPass(Result);
        { left is reused }
        Left := nil;
      end;


    function TTypeConvNode.TypeCheck_Array_2_DynArray : TNode;
      var
        lNewStatement : TStatementNode;
        lTemp         : TTempCreateNode;
        lTemp2        : TTempCreateNode;
      begin
        { create statements with call to getmem+initialize }
        Result:=InternalStatements(lNewStatement);

        { create temp for result }
        lTemp:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,true);
        AddStatement(lNewStatement,lTemp);

        { get temp for array of lengths }
        lTemp2:=CTempCreateNode.Create(SIntType,SIntType.Size,tt_persistent,false);
        AddStatement(lNewStatement,lTemp2);

        { one dimensional }
        AddStatement(lNewStatement,CAssignmentNode.Create(
            CTempRefNode.Create(lTemp2),
            COrdConstNode.Create
               (TArrayDef(Left.ResultDef).HighRange+1,S32IntType,true)));
        { create call to fpc_dynarr_setlength }
        AddStatement(lNewStatement,CCallNode.CreateIntern('fpc_dynarray_setlength',
            CCallParaNode.Create(CAddrNode.Create_Internal
                  (CTempRefNode.Create(lTemp2)),
               CCallParaNode.Create(COrdConstNode.Create
                  (1,S32IntType,true),
               CCallParaNode.Create(CAddrNode.Create_Internal
                  (CRTTINode.Create(TStoredDef(ResultDef),initrtti,rdt_normal)),
               CCallParaNode.Create(
                 CTypeConvNode.Create_Internal(
                   CTempRefNode.Create(lTemp),VoidPointerType),
                 nil))))

          ));
        AddStatement(lNewStatement,CTempDeleteNode.Create(lTemp2));

        { copy ... }
        AddStatement(lNewStatement,CAssignmentNode.Create(
          CTypeConvNode.Create_Internal(CDerefNode.Create(CTypeConvNode.Create_Internal(CTempRefNode.Create(lTemp),VoidPointerType)),Left.ResultDef),
          Left
        ));
        { left is reused }
        Left:=nil;
        { the last statement should return the value as
          location and type, this is done be referencing the
          temp and converting it first from a persistent temp to
          normal temp }
        AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lTemp));
        AddStatement(lNewStatement,CTempRefNode.Create(lTemp));
      end;


    function TTypeConvNode.TypeCheck_Elem_2_OpenArray : TNode;
      begin
        Result:=nil;
      end;


    function TTypeConvNode.TypeCheck_ArrayConstructor_To_DynArray : TNode;
      var
        lNewStatement,
        lAssignmentStatement : TStatementNode;
        lArrayNode : TTempCreateNode;
        lTemp2 : TTempCreateNode;
        lAssignmentNode : TNode;
        lParaCount : Integer;
        lElementNode : TArrayConstructorNode;
      begin
        { assignment of []? }
        if (
              (Left.NodeType=arrayconstructorn) and
              not Assigned(TArrayConstructorNode(Left).Left)
            ) or
              Is_EmptySet(Left)
            then
          begin
            Result:=CNilNode.Create;
            exit;
          end;

        if ResultDef.typ<>arraydef then
          InternalError(2017050102);

        TArrayConstructorNode(Left).Force_Type(TArrayDef(ResultDef).ElementDef);

        Result:=InternalStatements(lNewStatement);
        { create temp for result }
        lArrayNode:=CTempCreateNode.Create(ToTypeDef,ToTypeDef.Size,tt_persistent,true);
        AddStatement(lNewStatement,lArrayNode);

        lParaCount:=0;

        { create an assignment call for each element }
        lAssignmentNode:=InternalStatements(lAssignmentStatement);
        if Left.NodeType=arrayconstructorrangen then
          InternalError(2016021902);
        lElementNode:=TArrayConstructorNode(Left);
        while Assigned(lElementNode) do
          begin
            { arr[i] := param_i }
            if not Assigned(lElementNode.Left) then
              InternalError(2017050103);
            AddStatement(lAssignmentStatement,
              CAssignmentNode.Create(
                CVecNode.Create(
                  CTempRefNode.Create(lArrayNode),
                  COrdConstNode.Create(lParaCount,TArrayDef(ToTypeDef).RangeDef,false)),
                lElementNode.Left));
            lElementNode.Left:=nil;
            inc(lParaCount);
            lElementNode:=TArrayConstructorNode(lElementNode.Right);
            if Assigned(lElementNode) and (lElementNode.NodeType<>arrayconstructorn) then
              InternalError(2016021903);
          end;

        { get temp for array of lengths }
        lTemp2:=CTempCreateNode.Create_Value(SIntType,SIntType.Size,tt_persistent,false,COrdConstNode.Create(lParaCount,S32IntType,true));
        AddStatement(lNewStatement,lTemp2);

        { create call to fpc_dynarr_setlength }
        AddStatement(lNewStatement,CCallNode.CreateIntern('fpc_dynarray_setlength',
            CCallParaNode.Create(CAddrNode.Create_Internal
                  (CTempRefNode.Create(lTemp2)),
               CCallParaNode.Create(COrdConstNode.Create
                  (1,S32IntType,true),
               CCallParaNode.Create(CAddrNode.Create_Internal
                  (CRTTINode.Create(TStoredDef(ToTypeDef),initrtti,rdt_normal)),
               CCallParaNode.Create(
                 CTypeConvNode.Create_Internal(
                   CTempRefNode.Create(lArrayNode),VoidPointerType),
                 nil))))

          ));
        { add assignment statements }
        AddStatement(lNewStatement,CTempDeleteNode.Create(lTemp2));
        AddStatement(lNewStatement,lAssignmentNode);
        { the last statement should return the value as
          location and type, this is done be referencing the
          temp and converting it first from a persistent temp to
          normal temp }
        AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lArrayNode));
        AddStatement(lNewStatement,CTempRefNode.Create(lArrayNode));
      end;


    function TTypeConvNode.TypeCheck_ArrayConstructor_To_Array : TNode;
      var
        lNewStatement,
        lAssignmentStatement : TStatementNode;
        lArrayNode : TTempCreateNode;
        lTemp2 : TTempCreateNode;
        lAssignmentNode : TNode;
        lParaCount : Integer;
        lElementNode : TArrayConstructorNode;
      begin
        TArrayConstructorNode(Left).Force_Type(TArrayDef(ResultDef).ElementDef);

        Result:=InternalStatements(lNewStatement);
        { create temp for result }
        lArrayNode:=CTempCreateNode.Create(ToTypeDef,ToTypeDef.Size,tt_persistent,true);
        AddStatement(lNewStatement,lArrayNode);

        lParaCount:=0;

        { create an assignment call for each element }
        lAssignmentNode:=InternalStatements(lAssignmentStatement);
        if Left.NodeType=arrayconstructorrangen then
          InternalError(2020041402);
        lElementNode:=TArrayConstructorNode(Left);
        while Assigned(lElementNode) do
          begin
            { arr[i] := param_i }
            if not Assigned(lElementNode.Left) then
              InternalError(2020041403);
            AddStatement(lAssignmentStatement,
              CAssignmentNode.Create(
                CVecNode.Create(
                  CTempRefNode.Create(lArrayNode),
                  COrdConstNode.Create(lParaCount+TArrayDef(ToTypeDef).LowRange,TArrayDef(ToTypeDef).RangeDef,false)),
                lElementNode.Left));
            lElementNode.Left:=nil;
            inc(lParaCount);
            lElementNode:=TArrayConstructorNode(lElementNode.Right);
            if Assigned(lElementNode) and (lElementNode.NodeType<>arrayconstructorn) then
              InternalError(2020041404);
          end;

        { get temp for array of lengths }
        lTemp2:=CTempCreateNode.Create_Value(SIntType,SIntType.Size,tt_persistent,false,COrdConstNode.Create(lParaCount,S32IntType,true));
        AddStatement(lNewStatement,lTemp2);

        { add assignment statements }
        AddStatement(lNewStatement,CTempDeleteNode.Create(lTemp2));
        AddStatement(lNewStatement,lAssignmentNode);
        { the last statement should return the value as
          location and type, this is done be referencing the
          temp and converting it first from a persistent temp to
          normal temp }
        AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lArrayNode));
        AddStatement(lNewStatement,CTempRefNode.Create(lArrayNode));
      end;


    function TTypeConvNode.DispatchTypeCheckIntToInt : TNode;
      begin
        Result := TypeCheck_Int_To_Int;
      end;


    function TTypeConvNode.DispatchTypeCheckCOrdToPointer : TNode;
      begin
        Result := TypeCheck_COrd_To_Pointer;
      end;


    function TTypeConvNode.DispatchTypeCheckCharArrayToString : TNode;
      begin
        Result := TypeCheck_CharArray_To_String;
      end;


    function TTypeConvNode.DispatchTypeCheckStringToCharArray : TNode;
      begin
        Result := TypeCheck_String_To_CharArray;
      end;


    function TTypeConvNode.DispatchTypeCheckStringToString: TNode;
      begin
        Result := TypeCheck_String_To_String;
      end;


    function TTypeConvNode.DispatchTypeCheckCharToString : TNode;
      begin
        Result := TypeCheck_Char_To_String;
      end;


    function TTypeConvNode.DispatchTypeCheckCharToCharArray : TNode;
      begin
        Result := TypeCheck_Char_To_CharArray;
      end;


    function TTypeConvNode.DispatchTypeCheckIntToReal : TNode;
      begin
        Result := TypeCheck_Int_To_Real;
      end;


    function TTypeConvNode.DispatchTypeCheckRealToReal : TNode;
      begin
        Result := TypeCheck_Real_To_Real;
      end;


    function TTypeConvNode.DispatchTypeCheckRealToCurrency : TNode;
      begin
        Result := TypeCheck_Real_To_Currency;
      end;


    function TTypeConvNode.DispatchTypeCheckCCharToPChar : TNode;
      begin
        Result := TypeCheck_CChar_To_PChar;
      end;


    function TTypeConvNode.DispatchTypeCheckCStringToPChar : TNode;
      begin
        Result := TypeCheck_CString_To_PChar;
      end;


    function TTypeConvNode.DispatchTypeCheckCStringToInt : TNode;
      begin
        Result := TypeCheck_CString_To_Int;
      end;


    function TTypeConvNode.DispatchTypeCheckCharToChar : TNode;
      begin
        Result := TypeCheck_Char_To_Char;
      end;


    function TTypeConvNode.DispatchTypeCheckArrayConstructorToSet : TNode;
      begin
        Result := TypeCheck_ArrayConstructor_To_Set;
      end;


    function TTypeConvNode.DispatchTypeCheckSetToSet : TNode;
      begin
        Result := TypeCheck_Set_To_Set;
      end;


    function TTypeConvNode.DispatchTypeCheckPCharToString : TNode;
      begin
        Result := TypeCheck_PChar_To_String;
      end;


    function TTypeConvNode.DispatchTypeCheckInterfaceToString : TNode;
      begin
        Result := TypeCheck_Interface_To_String;
      end;


    function TTypeConvNode.DispatchTypeCheckInterfaceToGUID : TNode;
      begin
        Result := TypeCheck_Interface_To_GUID;
      end;


    function TTypeConvNode.DispatchTypeCheckDynArrayToOpenArray : TNode;
      begin
        Result := TypeCheck_DynArray_To_OpenArray;
      end;


    function TTypeConvNode.DispatchTypeCheckPWCharToString : TNode;
      begin
        Result := TypeCheck_PWChar_To_String;
      end;


    function TTypeConvNode.DispatchTypeCheckVariantToDynArray : TNode;
      begin
        Result := TypeCheck_Variant_To_DynArray;
      end;


    function TTypeConvNode.DispatchTypeCheckDynArrayToVariant : TNode;
      begin
        Result := TypeCheck_DynArray_To_Variant;
      end;


    function TTypeConvNode.DispatchTypeCheckVariantToEnum : TNode;
      begin
        Result := TypeCheck_Variant_To_Enum;
      end;


    function TTypeConvNode.DispatchTypeCheckEnumToVariant : TNode;
      begin
        Result := TypeCheck_Enum_To_Variant;
      end;


    function TTypeConvNode.DispatchTypeCheckProcToProcVar : TNode;
      begin
        Result := TypeCheck_Proc_To_ProcVar;
      end;


    function TTypeConvNode.DispatchTypeCheckVariantToInterface : TNode;
      begin
        Result := TypeCheck_Variant_To_Interface;
      end;


    function TTypeConvNode.DispatchTypeCheckInterfaceToVariant : TNode;
      begin
        Result := TypeCheck_Interface_To_Variant;
      end;


    function TTypeConvNode.DispatchTypeCheckArrayToDynArray : TNode;
      begin
        Result := TypeCheck_Array_2_DynArray;
      end;


    function TTypeConvNode.DispatchTypeCheckElemToOpenArray : TNode;
      begin
        Result := TypeCheck_Elem_2_OpenArray;
      end;


    function TTypeConvNode.DispatchTypeCheckArrayConstructorToDynArray : TNode;
      begin
        Result:=TypeCheck_ArrayConstructor_To_DynArray;
      end;


    function TTypeConvNode.DispatchTypeCheckArrayConstructorToArray : TNode;
      begin
        Result:=TypeCheck_ArrayConstructor_To_Array;
      end;


    function TTypeConvNode.DispatchTypeCheckProcVarToFuncRef : TNode;
      begin
        Result:=TypeCheck_ProcVar_2_FuncRef;
      end;


    function TTypeConvNode.DispatchTypeCheckAnonProcToFuncRef : TNode;
      begin
        Result:=TypeCheck_AnonProc_2_FuncRef;
      end;


    function TTypeConvNode.Target_Specific_General_TypeConv: Boolean;
      begin
        Result:=false;
      end;


    function TTypeConvNode.Target_Specific_Explicit_TypeConv: Boolean;
      begin
        Result:=false;
      end;


    class function TTypeConvNode.Target_Specific_Need_Equal_TypeConv(AFromDef, AToDef: TDef): Boolean;
      begin
        Result:=false;
      end;


    type
      TSymMapping = record
        OldSym:TSym;
        NewSym:TSym;
      end;
      PSymMapping = ^TSymMapping;


    function ReplaceSelfSym(var ANode:TNode;AArg:Pointer):TForEachNodeResult;
      var
        lMapping : PSymMapping absolute AArg;
        lLoadNode : TLoadNode;
      begin
        if ANode.NodeType=loadn then
          begin
            lLoadNode:=TLoadNode(ANode);
            if lLoadNode.SymTableEntry=lMapping^.OldSym then
              begin
                lLoadNode.SymTableEntry:=lMapping^.NewSym;
                { make sure that the node is processed again }
                lLoadNode.ResultDef:=nil;
                if Assigned(lLoadNode.Left) then
                  begin
                    { no longer loaded through the frame pointer }
                    lLoadNode.Left.free;
                    lLoadNode.Left:=nil;
                  end;
                TypeCheckPass(ANode);
              end;
          end;
        Result:=fen_true;
      end;


    function TTypeConvNode.TypeCheck_Proc_To_ProcVar : TNode;

      function IsSelfSym(ASym:TSym):Boolean;
        begin
          Result:=(ASym.typ in [localvarsym,paravarsym]) and
                    (vo_is_self in TAbstractVarSym(ASym).VarOptions);
        end;

      var
        lProcDef : TAbstractProcDef;
        lCopyType : TProcCopyTyp;
        lSource: PNode;
        lFramePointerSym,
        lSelfSym,
        lSym : TSym;
        lMapping : TSymMapping;
        lProcInfo : TProcInfo;
        lIndex : LongInt;
      begin
        Result:=nil;
        lProcDef:=TAbstractProcDef(Left.ResultDef);

        { create procvardef (default for create_proc_to_procvar is voiddef,
          but if later a regular inserttypeconvnode() is used to insert a type
          conversion to the actual procvardef, totypedef will be set to the
          real procvartype that we are converting to) }
        if Assigned(ToTypeDef) and
           (ToTypeDef.typ=procvardef) then
          begin
            { have to do this in typecheckpass so that it's triggered for
              typed constant declarations }
            if po_is_block in TProcVarDef(ToTypeDef).ProcOptions then
              begin
                { can only convert from procdef to procvardef, but in the mean
                  time other type conversions may have been inserted (pointers,
                  proc2procvar, ...) }
                lSource:=ActualTargetNode(@Left);
                while (lSource^.NodeType=typeconvn) and
                      (TTypeConvNode(lSource^).ConvType=tc_proc_2_procvar) and
                      (Is_Void(lSource^.ResultDef) or
                       (lSource^.ResultDef.typ=procvardef)) do
                  begin
                    { won't skip proc2procvar }
                    lSource:=ActualTargetNode(@TTypeConvNode(lSource^).Left);
                  end;
                if (lSource^.NodeType=loadn) and
                   (lSource^.ResultDef.typ=procdef) and
                   not Is_Nested_PD(TProcDef(lSource^.ResultDef)) and
                   not Is_ObjCClass(TDef(lSource^.ResultDef.owner.DefOwner)) then
                  begin
                    Result:=generate_block_for_procaddr(TLoadNode(lSource^));
                    exit;
                  end
                else
                  CGMessage2(type_e_illegal_type_conversion,Left.ResultDef.TypeName,ResultDef.TypeName);
              end
            else if (lProcDef.typ=procdef) and
               (po_anonymous in lProcDef.ProcOptions) then
              begin
                if Left.NodeType<>loadn then
                  InternalError(2021062402);
                { get rid of any potential framepointer loading; if it's necessary
                  (for a nested procvar for example) it will be added again }
                if Assigned(TLoadNode(Left).Left) and (TLoadNode(Left).Left.NodeType=loadparentfpn) then
                  begin
                    TLoadNode(Left).Left.free;
                    TLoadNode(Left).Left:=nil;
                    TLoadNode(Left).ResultDef:=nil;
                  end;
                if TProcVarDef(ToTypeDef).Is_MethodPointer then
                  begin
                    if Assigned(TProcDef(lProcDef).CapturedSyms) and
                        (
                          (TProcDef(lProcDef).CapturedSyms.count>1) or
                          (
                            (TProcDef(lProcDef).CapturedSyms.count=1) and
                            not IsSelfSym(TSym(PCapturedSymInfo(TProcDef(lProcDef).CapturedSyms[0])^.sym))
                          )
                        ) then
                      begin
                        Result:=CErrorNode.Create;
                        exit;
                      end;

                    { so that insert_self_and_vmt_para correctly inserts the
                      Self, cause it otherwise skips that for anonymous functions }
                    include(lProcDef.ProcOptions,po_methodpointer);
                    { we know this only captures Self, so we can move the
                      anonymous function to normal function level }
                    lProcDef.ParaST.SymTableLevel:=NormalFunctionLevel;
                    TProcDef(lProcDef).LocalST.SymTableLevel:=NormalFunctionLevel;

                    lSelfSym:=nil;
                    lFramePointerSym:=nil;
                    { find the framepointer parameter and an eventual self }
                    for lIndex:=0 to TProcDef(lProcDef).ParaST.SymList.count-1 do
                      begin
                        lSym:=TSym(TProcDef(lProcDef).ParaST.SymList[lIndex]);
                        if lSym.typ<>paravarsym then
                          continue;
                        if vo_is_parentfp in TParaVarSym(lSym).VarOptions then
                          lFramePointerSym:=lSym;
                        if vo_is_self in TParaVarSym(lSym).VarOptions then
                          lSelfSym:=lSym;
                        if Assigned(lFramePointerSym) and Assigned(lSelfSym) then
                          break;
                      end;

                    if Assigned(lFramePointerSym) then
                      TProcDef(lProcDef).ParaST.SymList.remove(lFramePointerSym);

                    { if we don't have a self parameter already we need to
                      insert a suitable one }

                    if not Assigned(lSelfSym) then
                      begin
                        { replace the self symbol by the new parameter if it was
                          captured }
                        if Assigned(TProcDef(lProcDef).CapturedSyms) and
                            (TProcDef(lProcDef).CapturedSyms.count>0) then
                          begin
                            if not Assigned(TProcDef(lProcDef).struct) then
                              { we can't use the captured symbol for the struct as that
                                might be the self of a type helper, thus we need to find
                                the parent procinfo that provides the Self }
                              TProcDef(lProcDef).struct:=CurrentProcInfo.Get_Normal_Proc.procdef.struct;
                            if not Assigned(TProcDef(lProcDef).struct) then
                              InternalError(2021062204);

                            Insert_Self_And_VMT_Para(lProcDef);

                            lMapping.OldSym:=TSym(PCapturedSymInfo(TProcDef(lProcDef).CapturedSyms[0])^.sym);
                            lMapping.NewSym:=nil;

                            { find the new self parameter }
                            for lIndex:=0 to TProcDef(lProcDef).ParaST.SymList.count-1 do
                              begin
                                lSym:=TSym(TProcDef(lProcDef).ParaST.SymList[lIndex]);
                                if (lSym.typ=paravarsym) and (vo_is_self in TParaVarSym(lSym).VarOptions) then
                                  begin
                                    lMapping.NewSym:=lSym;

                                    break;
                                  end;
                              end;

                            if not Assigned(lMapping.NewSym) then
                              InternalError(2021062202);

                            { the anonymous function can only be a direct child of the
                              current_procinfo }
                            lProcInfo:=CurrentProcInfo.Get_First_NestedProc;
                            while Assigned(lProcInfo) do
                              begin
                                if lProcInfo.procdef=lProcDef then
                                  break;
                                lProcInfo:=TProcInfo(lProcInfo.next);
                              end;

                            if not Assigned(lProcInfo) then
                              InternalError(2021062203);

                            { replace all uses of the captured Self by the new Self
                              parameter }
                            ForEachNodeStatic(pm_preprocess,TCGProcInfo(lProcInfo).code,@ReplaceSelfSym,@lMapping);
                          end
                        else
                          begin
                            { for a nested function of a method struct is already
                              set }
                            if not Assigned(TProcDef(lProcDef).struct) then
                              { simply add a TObject as Self parameter }
                              TProcDef(lProcDef).struct:=Class_TObject;

                            Insert_Self_And_VMT_Para(lProcDef);

                            { there is no self, so load a nil value }
                            TLoadNode(Left).Set_MP(CNilNode.Create);
                          end;
                      end;

                    { the anonymous function no longer adheres to the nested
                      calling convention }
                    exclude(lProcDef.ProcOptions,po_delphi_nested_cc);

                    TProcDef(lProcDef).CalcParas;

                    if not Assigned(TLoadNode(Left).Left) then
                      TLoadNode(Left).Set_MP(Load_Self_Node);
                  end
                else if TProcVarDef(ToTypeDef).Is_AddressOnly then
                  begin
                    if Assigned(TProcDef(lProcDef).CapturedSyms) and (TProcDef(lProcDef).CapturedSyms.count>0) then
                      begin
                        Result:=CErrorNode.Create;
                        exit;
                      end;

                    { remove framepointer and Self parameters }
                    for lIndex:=TProcDef(lProcDef).ParaST.SymList.count-1 downto 0 do
                      begin
                        lSym:=TSym(TProcDef(lProcDef).ParaST.SymList[lIndex]);
                        if (lSym.typ=paravarsym) and (TParaVarSym(lSym).VarOptions*[vo_is_parentfp,vo_is_self]<>[]) then
                          TProcDef(lProcDef).ParaST.SymList.delete(lIndex);
                      end;

                    { the anonymous function no longer adheres to the nested
                      calling convention }
                    exclude(lProcDef.ProcOptions,po_delphi_nested_cc);

                    { we don't need to look through the existing nodes, cause
                      the parameter was never used anyway }
                    TProcDef(lProcDef).CalcParas;
                  end
                else
                  begin
                    { this is a nested function pointer, so ensure that the
                      anonymous function is handled as such }
                    if Assigned(TProcDef(lProcDef).CapturedSyms) and
                        (TProcDef(lProcDef).CapturedSyms.count>0) and
                        (Left.NodeType=loadn) then
                      begin
                        TLoadNode(Left).Left:=CLoadParentFPNode.Create(TProcDef(TLoadNode(Left).SymTable.DefOwner),lpf_forload);
                        TypeCheckPass(TLoadNode(Left).Left);

                        lProcInfo:=CurrentProcInfo.Get_First_NestedProc;
                        while Assigned(lProcInfo) do
                          begin
                            if lProcInfo.procdef=lProcDef then
                              break;
                            lProcInfo:=TProcInfo(lProcInfo.next);
                          end;

                        lProcInfo.Set_Needs_ParentFP(TProcDef(TLoadNode(Left).SymTable.DefOwner).ParaST.SymTableLevel);
                      end;
                  end;
              end;
            ResultDef:=ToTypeDef;
          end
        else
         begin
           { only need the address of the method? this is needed
             for @tobject.create. In this case there will be a loadn without
             a methodpointer. }
           if (Left.NodeType=loadn) and
              not Assigned(TLoadNode(Left).Left) and
              (not(m_nested_procvars in CurrentSettings.ModeSwitches) or
               not Is_Nested_PD(TAbstractProcDef(TLoadNode(Left).ResultDef))) then
             lCopyType:=pc_address_only
           else
             lCopyType:=pc_normal;
           ResultDef:=CProcVarDef.GetReusableProcAddr(lProcDef,lCopyType);
         end;
      end;


    function TTypeConvNode.TypeCheck_ProcVar_2_FuncRef : TNode;
      var
        lCapturer : TSym;
        lInterfaceDef : TDef;
        lLoadNode,lBlock,lNode : TNode;
        lStatement : TStatementNode;
      begin
        Result:=nil;

        if not(m_tp_procvar in CurrentSettings.ModeSwitches) and
           Is_Invokable(ResultDef) and
           (Left.NodeType=typeconvn) and
           (TTypeConvNode(Left).ConvType=tc_proc_2_procvar) and
           Is_MethodPointer(Left.ResultDef) and
           (po_classmethod in TProcVarDef(Left.ResultDef).ProcOptions) and
           not(po_staticmethod in TProcVarDef(Left.ResultDef).ProcOptions) and
           (Proc_To_FuncRef_Equal(TProcDef(TTypeConvNode(Left).Left.ResultDef),TObjectDef(ResultDef))>=te_convert_l1) then
          begin
            lNode:=Left;
            Left:=TTypeConvNode(Left).Left;
            if (Left.NodeType=loadn) and
               not Assigned(TLoadNode(Left).Left) then
              TLoadNode(Left).Set_MP(CLoadVMTAddrNode.Create(CTypeNode.Create(TDef(TLoadNode(Left).SymTable.DefOwner))));
            Left:=CTypeConvNode.Create_Proc_To_ProcVar(Left);
            TTypeConvNode(Left).ToTypeDef:=ResultDef;
            TypeCheckPass(Left);
            TTypeConvNode(lNode).Left:=nil;
            lNode.free;
            lNode := nil;
          end;

        lInterfaceDef:=Capturer_Add_ProcVar_Or_Proc(CurrentProcInfo,Left,lCapturer,lNode);
        if Assigned(lInterfaceDef) then
          begin
            if Assigned(lCapturer) then
              lLoadNode:=CLoadNode.Create(lCapturer,lCapturer.owner)
            else
              lLoadNode:=CNilNode.Create;
            Result:=CTypeConvNode.Create_Internal(
                      CTypeConvNode.Create_Internal(
                        lLoadNode,
                        lInterfaceDef),
                      ToTypeDef);
            if Assigned(lNode) then
              begin
                lBlock:=InternalStatements(lStatement);
                AddStatement(lStatement,CAssignmentNode.Create(lNode,Left));
                Left:=nil;
                AddStatement(lStatement,Result);
                Result:=lBlock;
              end;
          end;
        if not Assigned(Result) then
          Result:=CErrorNode.Create;
      end;


    function TTypeConvNode.TypeCheck_AnonProc_2_FuncRef : TNode;
      var
        lCapturer : TSym;
        lInterfaceDef : TDef;
        lLoadNode : TNode;
      begin
        lInterfaceDef:=Capturer_Add_Anonymous_Proc(CurrentProcInfo,TProcDef(Left.ResultDef),lCapturer);
        if Assigned(lInterfaceDef) then
          begin
            if Assigned(lCapturer) then
              lLoadNode:=CLoadNode.Create(lCapturer,lCapturer.owner)
            else
              lLoadNode:=CNilNode.Create;
            Result:=CTypeConvNode.Create_Internal(
                      CTypeConvNode.Create_Internal(
                        lLoadNode,
                        lInterfaceDef),
                      ToTypeDef);
          end
        else
          Result:=CErrorNode.Create;
      end;

    procedure TTypeConvNode.Convert_Deferred_Stmt_Expr;
    { A statement expression (if-, case-, try-expression) with anonymous
      functions as values is created without the assignments to its result
      temp, because the type of the temp is only known now (see pstatmnt).
      Retype the temp, add the assignments and typecheck again. }
      var
        lStatement : TStatementNode;
        lResultTemp : TTempCreateNode;
        lValueNode,lOnNode : TNode;
        lIndex : LongInt;

        procedure AssignToTemp(var ANode : TNode);
          begin
            if Assigned(ANode) then
              ANode:=CAssignmentNode.Create(CTempRefNode.Create(lResultTemp),ANode);
          end;

      begin
        { skip the nothing node created by internalstatements }
        lStatement:=TStatementNode(TBlockNode(Left).Left);
        while lStatement.Left.NodeType=nothingn do
          lStatement:=TStatementNode(lStatement.Right);

        lResultTemp:=TTempCreateNode(lStatement.Left);
        lResultTemp.TempInfo^.TypeDef:=ResultDef;
        lResultTemp.Size:=ResultDef.Size;
        Left.ResultDef:=nil;

        { the statement computing the value }
        lStatement:=TStatementNode(lStatement.Right);
        lValueNode:=lStatement.Left;
        case lValueNode.NodeType of
          ifn:
            begin
              AssignToTemp(TIfNode(lValueNode).Right);
              AssignToTemp(TIfNode(lValueNode).t1);
              lValueNode.ResultDef:=nil;
            end;
          casen:
            begin
              for lIndex:=0 to TCaseNode(lValueNode).Blocks.count-1 do
                AssignToTemp(PCaseBlock(TCaseNode(lValueNode).Blocks[lIndex])^.Statement);
              AssignToTemp(TCaseNode(lValueNode).ElseBlock);
              lValueNode.ResultDef:=nil;
            end;
          tryexceptn:
            begin
              AssignToTemp(TTryExceptNode(lValueNode).Left);
              lOnNode:=TTryExceptNode(lValueNode).Right;
              while Assigned(lOnNode) and (lOnNode.NodeType=onn) do
                begin
                  AssignToTemp(TOnNode(lOnNode).Right);
                  lOnNode:=TOnNode(lOnNode).Left;
                end;
              AssignToTemp(TTryExceptNode(lValueNode).t1);
              lValueNode.ResultDef:=nil;
            end;
          else
            { simplified to a single value, e.g. constant condition }
            AssignToTemp(lStatement.Left);
        end;

        { the temp delete and temp ref }
        lStatement:=TStatementNode(lStatement.Right);
        while Assigned(lStatement) do
          begin
            lStatement.Left.ResultDef:=nil;
            lStatement:=TStatementNode(lStatement.Right);
          end;

        TypeCheckPass(Left);
      end;

    function TTypeConvNode.TypeCheck_Call_Helper(AConvertType : TConvertType) : TNode;
      const
         ResultDefConvert : array[TConvertType] of Pointer = (
          {none} nil,
          {equal} nil,
          {not_possible} nil,
          { string_2_string } @TTypeConvNode.DispatchTypeCheckStringToString,
          { char_2_string } @TTypeConvNode.DispatchTypeCheckCharToString,
          { char_2_chararray } @TTypeConvNode.DispatchTypeCheckCharToCharArray,
          { pchar_2_string } @TTypeConvNode.DispatchTypeCheckPCharToString,
          { cchar_2_pchar } @TTypeConvNode.DispatchTypeCheckCCharToPChar,
          { cstring_2_pchar } @TTypeConvNode.DispatchTypeCheckCStringToPChar,
          { cstring_2_int } @TTypeConvNode.DispatchTypeCheckCStringToInt,
          { ansistring_2_pchar } nil,
          { string_2_chararray } @TTypeConvNode.DispatchTypeCheckStringToCharArray,
          { chararray_2_string } @TTypeConvNode.DispatchTypeCheckCharArrayToString,
          { array_2_pointer } nil,
          { pointer_2_array } nil,
          { int_2_int } @TTypeConvNode.DispatchTypeCheckIntToInt,
          { int_2_bool } nil,
          { bool_2_bool } nil,
          { bool_2_int } nil,
          { real_2_real } @TTypeConvNode.DispatchTypeCheckRealToReal,
          { int_2_real } @TTypeConvNode.DispatchTypeCheckIntToReal,
          { real_2_currency } @TTypeConvNode.DispatchTypeCheckRealToCurrency,
          { proc_2_procvar } @TTypeConvNode.DispatchTypeCheckProcToProcVar,
          { nil_2_methodprocvar } nil,
          { arrayconstructor_2_set } @TTypeConvNode.DispatchTypeCheckArrayConstructorToSet,
          { set_to_set } @TTypeConvNode.DispatchTypeCheckSetToSet,
          { cord_2_pointer } @TTypeConvNode.DispatchTypeCheckCOrdToPointer,
          { intf_2_string } @TTypeConvNode.DispatchTypeCheckInterfaceToString,
          { intf_2_guid } @TTypeConvNode.DispatchTypeCheckInterfaceToGUID,
          { class_2_intf } nil,
          { char_2_char } @TTypeConvNode.DispatchTypeCheckCharToChar,
          { dynarray_2_openarray} @TTypeConvNode.DispatchTypeCheckDynArrayToOpenArray,
          { pwchar_2_string} @TTypeConvNode.DispatchTypeCheckPWCharToString,
          { variant_2_dynarray} @TTypeConvNode.DispatchTypeCheckVariantToDynArray,
          { dynarray_2_variant} @TTypeConvNode.DispatchTypeCheckDynArrayToVariant,
          { variant_2_enum} @TTypeConvNode.DispatchTypeCheckVariantToEnum,
          { enum_2_variant} @TTypeConvNode.DispatchTypeCheckEnumToVariant,
          { variant_2_interface} @TTypeConvNode.DispatchTypeCheckInterfaceToVariant,
          { interface_2_variant} @TTypeConvNode.DispatchTypeCheckVariantToInterface,
          { array_2_dynarray} @TTypeConvNode.DispatchTypeCheckArrayToDynArray,
          { elem_2_openarray } @TTypeConvNode.DispatchTypeCheckElemToOpenArray,
          { arrayconstructor_2_dynarray } @TTypeConvNode.DispatchTypeCheckArrayConstructorToDynArray,
          { arrayconstructor_2_array } @TTypeConvNode.DispatchTypeCheckArrayConstructorToArray,
          { anonproc_2_funcref } @TTypeConvNode.DispatchTypeCheckAnonProcToFuncRef,
          { procvar_2_funcref } @TTypeConvNode.DispatchTypeCheckProcVarToFuncRef
         );
      type
         TProcedureOfObject = function : TNode of object;
      var
         lMethod : TMethod;
      begin
         Result:=nil;
         { this is a little bit dirty but it works }
         { and should be quite portable too        }
         lMethod.Code:=ResultDefConvert[AConvertType];
         lMethod.Data:=Self;
         if Assigned(lMethod.Code) then
          Result:=TProcedureOfObject(lMethod)();
      end;


    function TTypeConvNode.Pass_TypeCheck:TNode;
      var
        lDef : TDef;
        lNode : TNode;
        lCurrentProcDef : TAbstractProcDef;
        lProcDef : TProcDef;
        lEqualType : TEqualType;
        lCompareDefsOptions : TCompareDefsOptions;
        lSelfNode : TNode;
        lNewBlock: TBlockNode;
        lNewStatement: TStatementNode;
        lTempNode: TTempCreateNode;
      begin
        Result:=nil;
        ResultDef:=ToTypeDef;

        TypeCheckPass(Left);
        if CodeGenError then
          exit;

        if Is_Deferred_Stmt_Expr(Left) and
            ((ResultDef.typ=procvardef) or Is_FuncRef(ResultDef)) then
          begin
            Convert_Deferred_Stmt_Expr;
            if CodeGenError then
              exit;
          end;

        { When absolute force tc_equal }
        if (nf_absolute in Flags) then
          begin
            ConvType:=tc_equal;
            { we need to check regability only if something is really regable }
            if ((TStoredDef(Left.ResultDef).Is_IntRegable) or
               (TStoredDef(ResultDef).Is_FPURegable)) and
               (
               (TStoredDef(ResultDef).Is_IntRegable<>TStoredDef(Left.ResultDef).Is_IntRegable) or
               (TStoredDef(ResultDef).Is_FPURegable<>TStoredDef(Left.ResultDef).Is_FPURegable) or
               { like in pdecvar.read_absolute(): if the size changes, the
                 register size would also have to change (but second_nothing
                 does not handle this) }
               (TStoredDef(ResultDef).Size<>TStoredDef(Left.ResultDef).Size)) then
              Make_Not_Regable(Left,[ra_addr_regable]);
            exit;
          end;

        { tp procvar support. Skip typecasts to procvar, record or set. Those
          convert on the procvar value. This is used to access the
          fields of a methodpointer }
        if not(nf_load_procvar in Flags) and
           not(ResultDef.typ in [procvardef,recorddef,setdef]) and
           not Is_Invokable(ResultDef) and
           { in case of interface assignments of invokables they'll be converted
             to voidpointertype using an internal conversions; we must not call
             the invokable in that case }
           not (
             (nf_internal in Flags) and
             Is_Invokable(Left.ResultDef)
           ) then
          Maybe_Call_ProcVar(Left,true);

        if Target_Specific_General_TypeConv then
          exit;

        if ConvType=tc_none then
          begin
            lCompareDefsOptions:=[cdo_allow_variant,cdo_warn_incompatible_univ];
            { overloaded operators require calls, which is not possible inside
              a constant declaration }
            if (Block_Type<>bt_const) and
               not(nf_internal in Flags) then
              include(lCompareDefsOptions,cdo_check_operator);
            if nf_explicit in Flags then
              include(lCompareDefsOptions,cdo_explicit);
            if nf_internal in Flags then
              include(lCompareDefsOptions,cdo_internal);
            lProcDef:=nil;
            lEqualType:=Compare_Defs_Ext(Left.ResultDef,ResultDef,Left.NodeType,ConvType,lProcDef,lCompareDefsOptions);
            case lEqualType of
              te_exact,
              te_equal :
                begin
                  Result := Simplify(false);
                  if Assigned(Result) then
                    exit;

                  { in case of bitpacked accesses, the original type must
                    remain so that not too many/few bits are laoded }
                  if Is_BitPacked_Access(Left) then
                    ConvType:=tc_int_2_int;
                  { Only leave when there is no conversion to do.
                    We can still need to call a conversion routine,
                    like the routine to convert a stringconstnode }
                  if (ConvType in [tc_equal,tc_not_possible]) and
                     { some conversions, like dynarray to pointer in Delphi
                       mode, must not be removed, because then we get memory
                       leaks due to missing temp finalization }
                     (not Is_Managed_Type(Left.ResultDef) or
                     { different kinds of refcounted types may need calls
                       to different kinds of refcounting helpers }
                      (ResultDef=Left.ResultDef)) then
                   begin

                       begin
                         Left.ResultDef:=ResultDef;
                         if (nf_explicit in Flags) and (Left.NodeType = addrn) then
                           include(TAddrNode(Left).AddrNodeFlags,anf_typedaddr);
                         Result:=Left;
                         Left:=nil;
                       end;
                     exit;
                   end;
                end;

              te_convert_l1,
              te_convert_l2,
              te_convert_l3,
              te_convert_l4,
              te_convert_l5,
              te_convert_l6:
                { nothing to do }
                ;

              te_convert_operator :
                begin
                  include(CurrentProcInfo.Flags,pi_do_call);
                  AddSymRef(lProcDef.ProcSym,lProcDef);
                  lNode:=CCallNode.Create(CCallParaNode.Create(Left,nil),TProcSym(lProcDef.ProcSym),nil,nil,[],nil);
                  { tell explicitly which def we must use !! (PM) }
                  TCallNode(lNode).ProcDefinition:=lProcDef;
                  Left:=nil;
                  Result:=lNode;
                  exit;
                end;

              te_incompatible :
                begin
                  { convert an array constructor to a set so that we still get
                    the error "set of Y incompatible to Z" instead of "array of
                    X incompatible to Z" }
                  if (ResultDef.typ<>arraydef) and
                     Is_Array_Constructor(Left.ResultDef) then
                    begin
                      ArrayConstructor_To_Set(Left);
                      TypeCheckPass(Left);
                    end;

                  { Procedures have a resultdef of voiddef and functions of their
                    own resultdef. They will therefore always be incompatible with
                    a procvar. Because isconvertable cannot check for procedures we
                    use an extra check for them.}
                  if (Left.NodeType=calln) and
                     (TCallNode(Left).Required_Para_Count=0) and
                     (
                       (ResultDef.typ=procvardef) or
                       Is_Invokable(ResultDef)
                     ) and
                     (
                      (m_tp_procvar in CurrentSettings.ModeSwitches) or
                      (m_mac_procvar in CurrentSettings.ModeSwitches)
                     ) then
                   begin
                     if Assigned(TCallNode(Left).Right) then
                      begin
                        { this is already a procvar, if it is really equal
                          is checked below }
                        ConvType:=tc_equal;
                        lNode:=TCallNode(Left).Right.GetCopy;
                        lCurrentProcDef:=TAbstractProcDef(lNode.ResultDef);
                      end
                     else
                      begin
                        if ResultDef.typ=procvardef then
                          begin
                            ConvType:=tc_proc_2_procvar;
                            lCurrentProcDef:=TProcSym(TCallNode(Left).SymTableProcEntry).Find_ProcDef_ByProcVarDef(TProcVarDef(ResultDef));
                          end
                        else
                          begin
                            ConvType:=tc_procvar_2_funcref;
                            lCurrentProcDef:=TProcSym(TCallNode(Left).SymTableProcEntry).Find_ProcDef_ByFuncRefDef(TObjectDef(ResultDef));
                          end;
                        lNode:=CLoadNode.Create_ProcVar(TProcSym(TCallNode(Left).SymTableProcEntry),
                            TProcDef(lCurrentProcDef),TCallNode(Left).SymTableProc);
                        if (TCallNode(Left).SymTableProcEntry.owner.SymTableType=ObjectSymtable) then
                         begin
                           lSelfNode:=TCallNode(Left).MethodPointer;
                           if Assigned(lSelfNode) then
                            begin
                              { in case the nodetype is a typen, avoid the internal error
                                in set_mp and instead let the code error out normally }
                              if lSelfNode.NodeType<>typen then
                                TLoadNode(lNode).Set_MP(lSelfNode.GetCopy)
                            end
                           else
                             TLoadNode(lNode).Set_MP(Load_Self_Node);
                         end;
                        TypeCheckPass(lNode);
                      end;
                     Left.free;
                     Left:=lNode;
                     { Now check if the procedure we are going to assign to
                       the procvar, is compatible with the procvar's type }
                     if not(nf_explicit in Flags) and
                        (
                          (
                            (ResultDef.typ=procvardef) and
                            (Proc_To_ProcVar_Equal(lCurrentProcDef,TProcVarDef(ResultDef),false)=te_incompatible)
                          ) or (
                            Is_Invokable(ResultDef) and
                            (Proc_To_FuncRef_Equal(lCurrentProcDef,TObjectDef(ResultDef))=te_incompatible)
                          )
                        ) then
                       IncompatibleTypes(Left.ResultDef,ResultDef)
                     else
                       Result:=TypeCheck_Call_Helper(ConvType);
                     exit;
                   end
                  else if Maybe_Global_Proc_To_Nested(Left,ResultDef) or
                          MaybeClassMethodToMethodProcVar(Left,ResultDef) then
                    begin
                      Result:=Left;
                      Left:=nil;
                      exit;
                    end;

                  { Handle explicit type conversions }
                  if nf_explicit in Flags then
                   begin
                     { do common tc_equal cast, except when dealing with proc -> procvar
                       (may have to get rid of method pointer) }
                     if (Left.ResultDef.typ<>procdef) or
                        (ResultDef.typ<>procvardef) then
                       ConvType:=tc_equal
                     else
                       ConvType:=tc_proc_2_procvar;

                     { ordinal constants can be resized to 1,2,4,8 bytes }
                     if (Left.NodeType=ordconstn) then
                       begin
                         { Insert typeconv for ordinal to the correct size first on left, after
                           that the other conversion can be done }
                         lDef:=nil;
                         case LongInt(ResultDef.Size) of
                           1 :
                             lDef:=S8IntType;
                           2 :
                             lDef:=S16IntType;
                           4 :
                             lDef:=S32IntType;
                           8 :
                             lDef:=S64IntType;
                         end;
                         { we need explicit, because it can also be an enum }
                         if Assigned(lDef) then
                           InsertTypeConv_Internal(Left,lDef)
                         else
                           CGMessage2(type_e_illegal_type_conversion,Left.ResultDef.TypeName,ResultDef.TypeName);
                       end;

                     { class/interface to class/interface, with checkobject support }
                     if Is_Class_Or_Interface_Or_ObjC(ResultDef) and
                        Is_Class_Or_Interface_Or_ObjC(Left.ResultDef) then
                       begin
                         { check if the types are related }
                         if not(nf_internal in Flags) and
                            (not(Def_Is_Related(TObjectDef(Left.ResultDef),TObjectDef(ResultDef)))) and
                            (not(Def_Is_Related(TObjectDef(ResultDef),TObjectDef(Left.ResultDef)))) then
                           begin
                             { Give an error when typecasting class to interface, this is compatible
                               with delphi }
                             if Is_Interface(ResultDef) and
                                not Is_Interface(Left.ResultDef) then
                               CGMessage2(type_e_classes_not_related,
                                 FullTypeName(Left.ResultDef,ResultDef),
                                 FullTypeName(ResultDef,Left.ResultDef))
                             else
                               CGMessage2(type_w_classes_not_related,
                                 FullTypeName(Left.ResultDef,ResultDef),
                                 FullTypeName(ResultDef,Left.ResultDef))
                           end;

                         { Add runtime check? }
                         if not Is_ObjC_Class_Or_Protocol(ResultDef) and
                            not Is_ObjC_Class_Or_Protocol(Left.ResultDef) and
                            (cs_check_object in CurrentSettings.LocalSwitches) and
                            not(nf_internal in Flags) then
                           begin
                             { we can translate the typeconvnode to 'as' when
                               typecasting to a class or interface }
                             { we need to make sure the result can still be
                               passed as a var parameter                    }
                             lNewBlock:=InternalStatements(lNewStatement);
                             if (Valid_For_Var(Left,false)) then
                               begin
                                 lTempNode:=CTempCreateNode.Create(VoidPointerType,VoidPointerType.Size,tt_persistent,true);
                                 AddStatement(lNewStatement,lTempNode);
                                 AddStatement(lNewStatement,CAssignmentNode.Create(
                                   CTempRefNode.Create(lTempNode),
                                   CAddrNode.Create_Internal(Left)));
                                 Left:=CTypeConvNode.Create_Internal(CDerefNode.Create(CTempRefNode.Create(lTempNode)),Left.ResultDef);
                               end
                             else
                               begin
                                 lTempNode:=CTempCreateNode.Create(Left.ResultDef,Left.ResultDef.Size,tt_persistent,true);
                                 AddStatement(lNewStatement,lTempNode);
                                 AddStatement(lNewStatement,CAssignmentNode.Create(
                                   CTempRefNode.Create(lTempNode),
                                   Left));
                                 Left:=CTempRefNode.Create(lTempNode);
                               end;
                             AddStatement(lNewStatement,CAsNode.Create(Left.GetCopy,CLoadVMTAddrNode.Create(CTypeNode.Create(ResultDef))));
                             AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lTempNode));
                             AddStatement(lNewStatement,CTypeConvNode.Create_Internal(Left,ResultDef));
                             Left:=nil;
                             Result:=lNewBlock;
                             exit;
                           end;
                       end

                      else
                       begin
                         { only if the same size or formal def, and }
                         { don't allow type casting of constants to }
                         { structured types                         }
                         if not(
                                (Left.ResultDef.typ=formaldef) or
                                (
                                 Is_Void(Left.ResultDef)  and
                                 (Left.NodeType=derefn)
                                ) or
                                (
                                 not(Is_Open_Array(Left.ResultDef)) and
                                 not(Is_Array_Constructor(Left.ResultDef)) and
                                 not(Is_Array_Of_Const(Left.ResultDef)) and
                                 { if the from type is an anonymous function then
                                   don't blindly convert it if the size is the same
                                   as compare_defs_ext already determined that the
                                   anonymous function is not compatible }
                                 not(
                                   (Left.ResultDef.typ=procdef) and
                                   (po_anonymous in TProcDef(Left.ResultDef).ProcOptions)
                                 ) and
                                 (Left.ResultDef.Size=ResultDef.Size) and
                                 { disallow casts of const nodes }
                                 (not Is_ConstNode(Left) or
                                   { however, there are some exceptions }
                                   (not(ResultDef.typ in [arraydef,recorddef,setdef,stringdef,
                                                          filedef,variantdef,objectdef]) or
                                   Is_Class_Or_Interface_Or_ObjC(ResultDef)
                                 ))
                                )
                               ) then
                           CGMessage2(type_e_illegal_type_conversion,Left.ResultDef.TypeName,ResultDef.TypeName)
                         else
                           begin
                             { perform target-specific explicit typecast
                               checks }
                             if Target_Specific_Explicit_TypeConv then
                               begin
                                 Result:=Simplify(false);
                                 exit;
                               end;
                           end;
                       end;
                   end
                  else
                   IncompatibleTypes(Left.ResultDef,ResultDef);
                end;
            end;
          end;
        { Give hint or warning for unportable code, exceptions are
           - typecasts from constants
           - void }
        if not(nf_internal in Flags) and
           (Left.NodeType<>ordconstn) and
           not(Is_Void(Left.ResultDef)) and
           (((Left.ResultDef.typ=orddef) and
             (ResultDef.typ in [pointerdef,procvardef,classrefdef])) or
            ((ResultDef.typ=orddef) and
             (Left.ResultDef.typ in [pointerdef,procvardef,classrefdef]))) then
          begin
            {Converting pointers to signed integers is a bad idea. Warn.}
            WarnPointerToSigned:=(ResultDef.typ=orddef) and (TOrdDef(ResultDef).OrdType in [s8bit,s16bit,s32bit,s64bit]);
            { Give a warning when sizes don't match, because then info will be lost }
            if Left.ResultDef.Size=ResultDef.Size then
              CGMessage(type_h_pointer_to_longint_conv_not_portable)
            else
              CGMessage(type_w_pointer_to_longint_conv_not_portable);
          end;

        { tc_cord_2_pointer still requires a type check, which
          simplify does not do }
        if (ConvType<>tc_cord_2_pointer) then
          begin
            Result := Simplify(false);
            if Assigned(Result) then
              exit;
          end;

        { now call the resultdef helper to do constant folding }
        Result:=TypeCheck_Call_Helper(ConvType);
      end;

{ some code generators for 64 bit CPUs might not support 32 bit operations, so we can
  disable the following optimization in fpcdefs.inc. Currently the only CPU for which
  this applies is powerpc64
}
{$ifndef CPUNO32BITOPS}
    { checks whether we can safely remove typeconversions to bigger types
      in case range and overflow checking are off, and in case
      the result of this node tree is downcasted again to a
      smaller type value afterwards,

      the smaller types being allowed are described by validints, ordinal constants must fit into l..h

      We do this on 64 bit CPUs as well, they benefit from it as well }

    function CheckRemoveBigIntTypeConvs(ANode: TNode; out AHasSignedInt: Boolean;AValidInts : TOrdTypeSet;const ALowValue,AHighValue : TConstExprInt): Boolean;
      var
        lHasMinus1,
        lHasSigned,
        lHasUnsigned,
        lHasDivMod: Boolean;

      { checks whether a node has an accepted resultdef, or originally
        had one but was implicitly converted to s64bit                 }
      function WasOriginallySmallerInt(ANode: TNode): Boolean;
        begin
          if (ANode.ResultDef.typ<>orddef) then
            exit(false);
          lHasSigned:=lHasSigned or Is_Signed(ANode.ResultDef);
          lHasUnsigned:=lHasUnsigned or not(Is_Signed(ANode.ResultDef));
          { actually, we should only check right (denominator) nodes here, but
            setting it always is a safe approximation }
          if ((ANode.NodeType=ordconstn) and
            (TOrdConstNode(ANode).Value=-1)) then
            lHasMinus1:=true;
          if (TOrdDef(ANode.ResultDef).OrdType in AValidInts) then
            begin
              if Is_Signed(ANode.ResultDef) then
                AHasSignedInt:=true;
              exit(true);
            end;
          { type conv to a bigger int, we do not like to use? }
          if (TOrdDef(ANode.ResultDef).OrdType in ([s8bit,u8bit,s16bit,u16bit,s32bit,u32bit,s64bit,u64bit]-AValidInts)) and
             { nf_explicit is also set for explicitly typecasted }
             { ordconstn's                                       }
             ([nf_internal,nf_explicit]*ANode.Flags=[]) and
             { either a typeconversion node coming from a smaller type }
             (((ANode.NodeType=typeconvn) and
               (TTypeConvNode(ANode).Left.ResultDef.typ=orddef) and
               (TOrdDef(TTypeConvNode(ANode).Left.ResultDef).OrdType in AValidInts)) or
             { or an ordconstnode which has a smaller type}
              ((ANode.NodeType=ordconstn) and
               (TOrdConstNode(ANode).Value>=ALowValue) and
               (TOrdConstNode(ANode).Value<=AHighValue))) then
            begin
              if ((ANode.NodeType=typeconvn) and
                  Is_Signed(TTypeConvNode(ANode).Left.ResultDef)) or
                 ((ANode.NodeType=ordconstn) and
                  (TOrdConstNode(ANode).Value<0)) then
                begin
                  AHasSignedInt:=true;
                  lHasSigned:=true;
                end
              else
                lHasUnsigned:=true;
              exit(true);
            end;
          Result:=false;
        end;


      function DoCheckRemoveIntTypeConvs(ANode: TNode): Boolean;
        begin
          if WasOriginallySmallerInt(ANode) then
            exit(true);
          case ANode.NodeType of
            subn,orn,xorn:
              begin
                { the result could become negative in this case }
                if ANode.NodeType=subn then
                  AHasSignedInt:=true;
                Result:=
                  DoCheckRemoveIntTypeConvs(TBinaryNode(ANode).Left) and
                  DoCheckRemoveIntTypeConvs(TBinaryNode(ANode).Right);
              end;
            unaryminusn:
              begin
                AHasSignedInt:=true;
                Result:=DoCheckRemoveIntTypeConvs(TUnaryNode(ANode).Left);
              end;
            shrn:
              begin
                Result:=WasOriginallySmallerInt(TBinaryNode(ANode).Left) and
                  DoCheckRemoveIntTypeConvs(TBinaryNode(ANode).Right);
              end;
            notn:
              Result:=DoCheckRemoveIntTypeConvs(TUnaryNode(ANode).Left);
            addn,muln,divn,modn,andn,shln:
              begin
                if ANode.NodeType in [divn,modn] then
                  lHasDivMod:=true;
                Result:=
                  (DoCheckRemoveIntTypeConvs(TBinaryNode(ANode).Left) and
                   DoCheckRemoveIntTypeConvs(TBinaryNode(ANode).Right) and

                   (not(ANode.NodeType in [modn,divn]) or (not(lHasMinus1)))
                  ) or
                  (
                    (ANode.NodeType=andn) and
                    (
                      { Right node is more likely to be a constant, so check
                        this one first }
                      WasOriginallySmallerInt(TBinaryNode(ANode).Right) or
                      WasOriginallySmallerInt(TBinaryNode(ANode).Left)
                    )
                  );
              end;
            else
              Result:=false;
          end;
        end;

      begin { checkremove64bittypeconvs }
        lHasDivMod:=false;
        AHasSignedInt:=false;
        lHasMinus1:=false;
        lHasSigned:=false;
        lHasUnsigned:=false;
        Result:=
          DoCheckRemoveIntTypeConvs(ANode) and
          (not(lHasDivMod) or (lHasSigned xor lHasUnsigned));
      end;


    { remove int type conversions and set the result to the given type }
    procedure DoRemoveIntTypeConvs(ALevel : DWord;var ANode: TNode; AToDef: TDef; AForceUnsigned: Boolean; ASignedType,AUnsignedType : TDef);

      function SmallerOrSigned(ADef: TDef): Boolean;
        begin
          Result := (ADef.Size < ASignedType.Size) or
            (
              (ADef.Size = ASignedType.Size) and
              Is_Signed(ADef)
            )
        end;

      var
        lNewBlock: TBlockNode;
        lNewStatements: TStatementNode;
        lOriginalDivTree: TNode;
        lTempNode: TTempCreateNode;
        lNeedMinus1Check: Boolean;
      begin
        { we may not recurse into shr nodes:

          dword1:=dword1+((dword2+dword3) shr 2);

          while we can remove an extension on the outermost addition, we cannot
          remove it from the shr
        }
        { Don't downsize into a division operation either, as the numerator can
          be much larger than the result and non-linear properties prevent
          accurate truncation; fixes #39646 [Kit] }
        if (ANode.NodeType in [shrn,divn,modn]) and (ALevel<>0) then
          begin
            InsertTypeConv_Internal(ANode,AToDef);
            exit;
          end;
        case ANode.NodeType of
          subn,addn,muln,divn,modn,xorn,andn,orn,shln,shrn:
            begin
              exclude(ANode.Flags,nf_internal);
              if not AForceUnsigned and
                 Is_Signed(ANode.ResultDef) then
                begin
                  lOriginalDivTree:=nil;
                  lNeedMinus1Check:=False;

                  if ANode.NodeType in [divn,modn] then
                    begin
                      { If the DIV operation is being downsized, we must explicitly check for a divisor of -1 }
                      lNeedMinus1Check := True;

                      { If the operand size is equal or smaller, the -1 check isn't necessary }
                      if (
                          SmallerOrSigned(TBinaryNode(ANode).Left.ResultDef) or
                          (
                            (TBinaryNode(ANode).Left.NodeType = typeconvn) and
                            SmallerOrSigned(TTypeConvNode(TBinaryNode(ANode).Left).Left.ResultDef)
                          )
                        ) and
                        (
                          SmallerOrSigned(TBinaryNode(ANode).Right.ResultDef) or
                          (
                            (TBinaryNode(ANode).Right.NodeType = typeconvn) and
                            SmallerOrSigned(TTypeConvNode(TBinaryNode(ANode).Right).Left.ResultDef)
                          )
                        ) then
                        lNeedMinus1Check := False;
                    end;


                  if lNeedMinus1Check then
                    lOriginalDivTree:=ANode.GetCopy;

                  DoRemoveIntTypeConvs(ALevel+1,TBinaryNode(ANode).Left,ASignedType,false,ASignedType,AUnsignedType);
                  DoRemoveIntTypeConvs(ALevel+1,TBinaryNode(ANode).Right,ASignedType,false,ASignedType,AUnsignedType);
                  ANode.ResultDef:=ASignedType;

                  if lNeedMinus1Check then
                    begin
                      lNewBlock:=InternalStatements(lNewStatements);
                      lTempNode:=CTempCreateNode.Create(ANode.ResultDef,ANode.ResultDef.Size,tt_persistent,true);
                      AddStatement(lNewStatements,lTempNode);
                      AddStatement(lNewStatements,CIfNode.Create_Internal(
                        CAddNode.Create_Internal(EqualN,TBinaryNode(ANode).Right.GetCopy,COrdConstNode.Create(-1,ANode.ResultDef,false)),
                          CAssignmentNode.Create_Internal(
                            CTempRefNode.Create(lTempNode),
                            CModDivNode.Create(ANode.NodeType,TBinaryNode(lOriginalDivTree).Left.GetCopy,COrdConstNode.Create(-1,TBinaryNode(lOriginalDivTree).Right.ResultDef,false))
                          ),
                          CAssignmentNode.Create_Internal(
                            CTempRefNode.Create(lTempNode),ANode
                          )
                        )
                      );
                      AddStatement(lNewStatements,CTempDeleteNode.Create_Normal_Temp(lTempNode));
                      AddStatement(lNewStatements,CTempRefNode.Create(lTempNode));
                      ANode:=lNewBlock;
                      DoTypeCheckPass(ANode);
                      lOriginalDivTree.free;
                      lOriginalDivTree := nil;
                    end;
                end
              else
                begin
                  DoRemoveIntTypeConvs(ALevel+1,TBinaryNode(ANode).Left,AUnsignedType,AForceUnsigned,ASignedType,AUnsignedType);
                  DoRemoveIntTypeConvs(ALevel+1,TBinaryNode(ANode).Right,AUnsignedType,AForceUnsigned,ASignedType,AUnsignedType);
                  ANode.ResultDef:=AUnsignedType;
                end;
              //if ((n.nodetype=andn) and (tbinarynode(n).left.nodetype=ordconstn) and
              //    ((tordconstnode(tbinarynode(n).left).value and $7fffffff)=tordconstnode(tbinarynode(n).left).value)
              //   ) then
              //  inserttypeconv_internal(tbinarynode(n).right,n.resultdef)
              //else if (n.nodetype=andn) and (tbinarynode(n).right.nodetype=ordconstn) and
              //  ((tordconstnode(tbinarynode(n).right).value and $7fffffff)=tordconstnode(tbinarynode(n).right).value) then
              //  inserttypeconv_internal(tbinarynode(n).left,n.resultdef);
            end;
          unaryminusn,notn:
            begin
              exclude(ANode.Flags,nf_internal);
              if not AForceUnsigned and
                 Is_Signed(ANode.ResultDef) then
                begin
                  DoRemoveIntTypeConvs(ALevel+1,TUnaryNode(ANode).Left,ASignedType,false,ASignedType,AUnsignedType);
                  ANode.ResultDef:=ASignedType;
                end
              else
                begin
                  DoRemoveIntTypeConvs(ALevel+1,TUnaryNode(ANode).Left,AUnsignedType,AForceUnsigned,ASignedType,AUnsignedType);
                  ANode.ResultDef:=AUnsignedType;
                end;
            end;
          typeconvn:
            begin
              TTypeConvNode(ANode).ToTypeDef:=AToDef;
              { may change the type conversion, e.g. if the old conversion was
                from 64 bit to a 64 bit, and now becomes 64 bit to 32 bit }
              ANode.ResultDef:=nil;
              TTypeConvNode(ANode).ConvType:=tc_none;
              TypeCheckPass(ANode);
            end;
          else
            InsertTypeConv_Internal(ANode,AToDef);
        end;
      end;
{$endif not CPUNO32BITOPS}

    procedure SwapConstValue (var AValue : TConstExprInt; ASize : LongInt);
      begin
        case ASize of
          1 : {do nothing };
          2 : if AValue.signed then
                AValue.svalue:=swapendian(smallint(AValue.svalue))
              else
                AValue.uvalue:=swapendian(Word(AValue.uvalue));
          4 : if AValue.signed then
                AValue.svalue:=swapendian(LongInt(AValue.svalue))
              else
                AValue.uvalue:=swapendian(QWord(AValue.uvalue));
          8 : if AValue.signed then
                AValue.svalue:=swapendian(Int64(AValue.svalue))
              else
                AValue.uvalue:=swapendian(QWord(AValue.uvalue));
	  else
            InternalError(2014111201);
        end;
      end;

    function TTypeConvNode.Simplify(AForInline : Boolean): TNode;
      var
        lNode: TNode;
        lValue: TConstExprInt;
        lRealValue: BestReal;
{$ifndef CPUNO32BITOPS}
        lFoundSignedInt: Boolean;
{$endif not CPUNO32BITOPS}
      begin
        Result := nil;
        { Constant folding and other node transitions to
          remove the typeconv node }
        case Left.NodeType of
          stringconstn :
            if (ResultDef.typ=stringdef) and
               ((ConvType=tc_equal) or
                ((ConvType=tc_string_2_string) and
                 (
                  ((not Is_WideCharArray(Left.ResultDef) and
                    not Is_Wide_Or_Unicode_String(Left.ResultDef)) or
                   (TStringDef(ResultDef).StringType in [st_widestring,st_unicodestring,st_ansistring])
                  )
                 )
                )
               ) then
              begin
                { output string consts in local ansistring encoding }
                if Is_AnsiString(ResultDef) and
                  { do not mess with the result type for internally created nodes }
                  not(nf_internal in Flags) and
                  ((TStringDef(ResultDef).encoding=0) or (TStringDef(ResultDef).encoding=Globals.CP_NONE)) then
                  TStringConstNode(Left).ChangeStringType(GetAnsiStringDef)
                else
                  TStringConstNode(Left).ChangeStringType(ResultDef);
                Result:=Left;
                Left:=nil;
                exit;
              end
            else if
              (ConvType<>tc_cstring_2_pchar)  and
              Is_DynamicString(Left.ResultDef) and
              (TStringConstNode(Left).len=0) and
              (ResultDef.typ=pointerdef) and
              CStringConstNode.EmptyDynStrNil then
            begin
              Result:=CNilNode.Create;
              exit;
            end;

          realconstn :
            begin
              if (ConvType = tc_real_2_currency) then
                Result := TypeCheck_Real_To_Currency
              else if (ConvType = tc_real_2_real) then
                Result := TypeCheck_Real_To_Real
              else
                exit;
              if not(Assigned(Result)) then
                begin
                  Result := Left;
                  Left := nil;
                end;
              if (Result.NodeType = realconstn) then
                begin
                  lNode:=Result;
                  Result:=CRealConstNode.Create(TRealConstNode(lNode).ValueReal,ResultDef);
                  if nf_is_currency in lNode.Flags then
                    include(Result.Flags,nf_is_currency);
                  if ([nf_explicit,nf_internal] * Flags <> []) then
                    include(Result.Flags, nf_explicit);
                  lNode.free;
                  lNode := nil;
                end;
            end;

          niln :
            begin
              { nil to ordinal node }
              if (ResultDef.typ=orddef) then
               begin
                 lNode:=COrdConstNode.Create(0,ResultDef,true);
                 if ([nf_explicit,nf_internal] * Flags <> []) then
                   include(lNode.Flags, nf_explicit);
                 Result:=lNode;
                 exit;
               end
              else
               { fold nil to any pointer type }
               if (ResultDef.typ=pointerdef) then
                begin
                  lNode:=CNilNode.Create;
                  lNode.ResultDef:=ResultDef;
                  if ([nf_explicit,nf_internal] * Flags <> []) then
                    include(lNode.Flags, nf_explicit);
                  Result:=lNode;
                  exit;
                end
              else
               { remove typeconv after niln, but not when the result is a
                 methodpointer. The typeconv of the methodpointer will then
                 take care of updating size of niln to OS_64 }
               if not((ResultDef.typ=procvardef) and
                      not(TProcVarDef(ResultDef).Is_AddressOnly)) and
                  { converting (dynamic array) nil to a an open array is not allowed }
                  not Is_Open_Array(ResultDef) then
                 begin
                   Left.ResultDef:=ResultDef;
                   if ([nf_explicit,nf_internal] * Flags <> []) then
                     include(Left.Flags, nf_explicit);
                   Result:=Left;
                   Left:=nil;
                   exit;
                 end;
            end;

          ordconstn :
            begin
              { ordinal constants can be directly converted }
              { but not char to char because it is a widechar to char or via versa }
              { which needs extra code to do the code page transistion             }
              { constant ordinal to pointer }
              if (ResultDef.typ=pointerdef) and
                 (ConvType<>tc_cchar_2_pchar) then
                begin
                   lNode:=CPointerConstNode.Create(TConstPtrUInt(TOrdConstNode(Left).Value.uvalue),ResultDef);
                   if ([nf_explicit,nf_internal] * Flags <> []) then
                     include(lNode.Flags, nf_explicit);
                   Result:=lNode;
                   exit;
                end
              else if Is_Ordinal(ResultDef) and
                      not(ConvType=tc_char_2_char) then
                begin
                   { replace the resultdef and recheck the range }
                   if ([nf_explicit,nf_absolute, nf_internal] * Flags <> []) then
                     include(Left.Flags, nf_explicit)
                   else
                     { no longer an ordconst with an explicit typecast }
                     exclude(Left.Flags, nf_explicit);
                   { when converting from one boolean type to another, force }
                   { booleans to 0/1, and byte/word/long/qwordbool to 0/-1   }
                   { (Delphi-compatible)                                     }
                   if Is_Boolean(Left.ResultDef) and
                      Is_Boolean(ResultDef) and
                      (Is_CBool(Left.ResultDef) or
                       Is_CBool(ResultDef)) then
                     begin
                       if Is_PasBool(ResultDef) then
                         TOrdConstNode(Left).Value:=ord(TOrdConstNode(Left).Value<>0)
                       else
                         TOrdConstNode(Left).Value:=-ord(TOrdConstNode(Left).Value<>0);
                     end
                   else
                     begin
                       { for constant values on absolute variables, swapping is required }
                       if not(nf_generic_para in Flags) then
                          AdaptRange(
                            ResultDef,TOrdConstNode(Left).Value,
                            { when evaluating an explicit typecast during inlining, don't warn about
                              lost bits; only warn if someone literally typed e.g. byte($1ff) }
                            (([nf_internal,nf_absolute]*Flags)<>[]) or (AForInline and (nf_explicit in Flags)),
                            nf_explicit in Flags,
                            cs_check_range in LocalSwitches);
                       { swap value back, but according to new type }

                       { cut off the new value? }
                       if ResultDef.Size<Left.ResultDef.Size then
                         case ResultDef.Size of
                           1:
                             if Is_Signed(ResultDef) then
                               TOrdConstNode(Left).Value:=TOrdConstNode(Left).Value and shortint($ff)
                             else
                               TOrdConstNode(Left).Value:=TOrdConstNode(Left).Value and Byte($ff);
                           2:
                             if Is_Signed(ResultDef) then
                               TOrdConstNode(Left).Value:=TOrdConstNode(Left).Value and smallint($ffff)
                             else
                               TOrdConstNode(Left).Value:=TOrdConstNode(Left).Value and Word($ffff);
                           4:
                             if Is_Signed(ResultDef) then
                               TOrdConstNode(Left).Value:=TOrdConstNode(Left).Value and LongInt($ffffffff)
                             else
                               TOrdConstNode(Left).Value:=TOrdConstNode(Left).Value and DWord($ffffffff);
                         end;
                     end;
                   Left.ResultDef:=ResultDef;
                   TOrdConstNode(Left).TypeDef:=ResultDef;
                   if Is_Signed(ResultDef) then
                     TOrdConstNode(Left).Value.signed:=true
                   else
                     TOrdConstNode(Left).Value.signed:=false;
                   Result:=Left;
                   Left:=nil;
                   exit;
                end
              else if (ConvType=tc_int_2_int) and
                Is_Currency(ResultDef) then
                begin
                  lValue:=TOrdConstNode(Left).Value;
                  if (nf_is_currency in Flags) and not(nf_internal in Flags) and not(nf_is_currency in Left.Flags) then
                    begin
                      Result:=COrdConstNode.Create(lValue*10000,ResultDef,false);
                      Include(Result.Flags, nf_is_currency);
                    end
                  else
                    Result:=COrdConstNode.Create(lValue,ResultDef,false);
                  exit;
                end
              else if (ConvType=tc_int_2_real) and
                Is_Currency(ResultDef) then
                begin
                  if (ResultDef.typ<>floatdef) then
                    { It should be a floating-point-based Currency if int-to-real was selected }
                    InternalError(2024091801);

                  lRealValue := BestReal(TOrdConstNode(Left).Value);
                  if not(nf_internal in Flags) and not(nf_is_currency in Left.Flags) then
                    begin
                      Result:=CRealConstNode.Create(lRealValue*BestReal(10000.0),ResultDef);
                      Include(Result.Flags,nf_is_currency);
                    end
                  else
                    Result:=CRealConstNode.Create(lRealValue,ResultDef);
                  exit;
                end;
            end;

          pointerconstn :
            begin
              { pointerconstn to any pointer is folded too }
              if (ResultDef.typ=pointerdef) then
                begin
                   Left.ResultDef:=ResultDef;
                   if ([nf_explicit,nf_internal] * Flags <> []) then
                     include(Left.Flags, nf_explicit)
                   else
                     { no longer an ordconst with an explicit typecast }
                     exclude(Left.Flags, nf_explicit);
                   Result:=Left;
                   Left:=nil;
                   exit;
                end
              { constant pointer to ordinal }
              else if Is_Ordinal(ResultDef) then
                begin
                   lNode:=COrdConstNode.Create(TConstExprInt(TPointerConstNode(Left).Value),
                     ResultDef,not(nf_explicit in Flags));
                   if ([nf_explicit,nf_internal] * Flags <> []) then
                     include(lNode.Flags, nf_explicit);
                   Result:=lNode;
                   exit;
                end;
            end;
          else
            ;
        end;
{$ifndef CPUNO32BITOPS}
        { must be done before code below, because we need the
          typeconversions for ordconstn's as well }
        case ConvType of
          tc_bool_2_int,
          tc_int_2_bool,
          tc_int_2_int:
            begin
              if (LocalSwitches * [cs_check_range,cs_check_overflow] = []) and
                 (ResultDef.typ in [pointerdef,orddef,enumdef]) then
                begin
                  { avoid unnecessary widening of intermediary calculations
                    to 64 bit                                               }
                  if (ResultDef.Size <= 4) and
                    Is_64BitInt(Left.ResultDef) and
                    (Left.NodeType in [subn,addn,muln,divn,modn,xorn,andn,orn,notn,unaryminusn,shln,shrn]) and
                    CheckRemoveBigIntTypeConvs(Left,lFoundSignedInt,[s8bit,u8bit,s16bit,u16bit,s32bit,u32bit],Int64(low(LongInt)),high(Cardinal)) then
                    DoRemoveIntTypeConvs(0,Left,GenErrorDef,not lFoundSignedInt,S32IntType,U32IntType);


                  { the above simplification may have left a redundant equal
                    typeconv (e.g. int32 to int32). If that's the case, we remove it }
                  if Equal_Defs(Left.ResultDef,ResultDef) then
                    begin
                      Result:=Left;
                      Left:=nil;
                      exit;
                    end;
                  if (ConvType=tc_int_2_int) and (Left.NodeType=typeconvn) and (TTypeConvNode(Left).ConvType=tc_bool_2_int) then
                    begin
                      TTypeConvNode(Left).ToTypeDef:=ResultDef;
                      TTypeConvNode(Left).ResultDef:=ResultDef;
                      Result:=Left;
                      Left:=nil;
                      exit;
                    end;
                end;
            end;
          else
            ;
        end;
{$endif not CPUNO32BITOPS}
      end;


    procedure TTypeConvNode.Mark_Write;
      begin
        if not(ConvType=tc_pointer_2_array) then
          Left.Mark_Write;
      end;

    function TTypeConvNode.First_COrd_To_Pointer : TNode;

      begin
        Result:=nil;
        InternalError(200104043);
      end;


    function TTypeConvNode.First_Int_To_Int : TNode;

      begin
        First_Int_To_Int:=nil;
        ExpectLoc:=Left.ExpectLoc;
        if not Is_Void(Left.ResultDef) then
          begin
            if (Left.ExpectLoc<>LOC_REGISTER) and
                ((ResultDef.Size>Left.ResultDef.Size) or
                 (Left.ExpectLoc in [LOC_SUBSETREF,LOC_CSUBSETREF,LOC_SUBSETREG,LOC_CSUBSETREG])) then
              ExpectLoc:=LOC_REGISTER
            else
              if (Left.ExpectLoc=LOC_CREGISTER) and
                 (ResultDef.Size<Left.ResultDef.Size) then
                ExpectLoc:=LOC_REGISTER;
          end;
      end;


    function TTypeConvNode.First_CString_To_PChar : TNode;

      begin
         Result:=nil;
         ExpectLoc:=LOC_REGISTER;
      end;


    function TTypeConvNode.First_CString_To_Int : TNode;

      begin
        Result:=nil;
        InternalError(200510014);
      end;


    function TTypeConvNode.First_String_To_CharArray : TNode;

      begin
         First_String_To_CharArray:=nil;
         ExpectLoc:=Left.ExpectLoc;
      end;


    function TTypeConvNode.First_Char_To_String : TNode;

      begin
         First_Char_To_String:=nil;
         if TStringDef(ResultDef).StringType=st_shortstring then
           inc(CurrentProcInfo.EstimatedTempSize,256);
         ExpectLoc:=LOC_REFERENCE;
      end;


    function TTypeConvNode.First_Char_To_CharArray : TNode;

      begin
        if ResultDef.Size <> 1 then
          begin
            { convert first to string, then to chararray }
            InsertTypeConv(Left,CShortStringType);
            InsertTypeConv(Left,ResultDef);
            Result:=Left;
            Left := nil;
            exit;
          end;
        Result := nil;
      end;


    function TTypeConvNode.First_Nothing : TNode;
      begin
         First_Nothing:=nil;
      end;


    function TTypeConvNode.First_Array_To_Pointer : TNode;

      begin
         First_Array_To_Pointer:=nil;
         Make_Not_Regable(Left,[ra_addr_regable]);
         ExpectLoc:=LOC_REGISTER;
      end;


    function TTypeConvNode.First_Int_To_Real: TNode;
      var
        lFunctionName: string[32];
      begin
        begin
            { converting a 64bit integer to a float requires a helper }
            if Is_64BitInt(Left.ResultDef) or
              Is_Currency(Left.ResultDef) then
              begin
                { hack to avoid double division by 10000, as it's
                  already done by typecheckpass.resultdef_int_to_real }
                if Is_Currency(Left.ResultDef) then
                  Left.ResultDef := S64IntType;
                if Is_Signed(Left.ResultDef) then
                  lFunctionName:='int64_to_'
                else
                  { we can't do better currently }
                  lFunctionName:='qword_to_';
              end
            else
              { other integers are supposed to be 32 bit }
              begin
                if Is_Signed(Left.ResultDef) then
                  lFunctionName:='int32_to_'
                else
                  lFunctionName:='int64_to_';
                FirstPass(Left);
              end;
            if TFloatDef(ResultDef).FloatType=S64Real then
              lFunctionName:=lFunctionName+'float64'
            else
              lFunctionName:=lFunctionName+'float32';
            Result:=CTypeConvNode.Create_Internal(CCallNode.CreateIntern(lFunctionName,CCallParaNode.Create(
              Left,nil)),ResultDef);
            Left:=nil;
            FirstPass(Result);
            exit;
          end;
      end;


    function TTypeConvNode.First_Real_To_Real : TNode;
      begin
        First_Real_To_Real:=nil;
        if not Use_VectorFPU(ResultDef) then
          ExpectLoc:=LOC_FPUREGISTER
        else
          ExpectLoc:=LOC_MMREGISTER;
      end;


    function TTypeConvNode.First_Pointer_To_Array : TNode;

      begin
         First_Pointer_To_Array:=nil;
         ExpectLoc:=LOC_REFERENCE;
      end;


    function TTypeConvNode.First_CChar_To_PChar : TNode;

      begin
         First_CChar_To_PChar:=nil;
         InternalError(200104021);
      end;


    function TTypeConvNode.First_Bool_To_Int : TNode;

      begin
         First_Bool_To_Int:=nil;
         { byte(boolean) or word(wordbool) or longint(longbool) must
           be accepted for var parameters }
         if (nf_explicit in Flags) and
            (Left.ResultDef.Size=ResultDef.Size) and
            (Left.ExpectLoc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_CREGISTER]) then
           begin
             ExpectLoc:=Left.ExpectLoc;
             exit;
           end;
         ExpectLoc:=LOC_REGISTER;
      end;


    function TTypeConvNode.First_Int_To_Bool : TNode;

      begin
         First_Int_To_Bool:=nil;
         { byte(boolean) or word(wordbool) or longint(longbool) must
           be accepted for var parameters }
         if (nf_explicit in Flags) and
            (Left.ResultDef.Size=ResultDef.Size) and
            (Left.ExpectLoc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_CREGISTER]) then
           begin
             ExpectLoc:=Left.ExpectLoc;
             exit;
           end;
         { when converting 64bit int to C-ctyle boolean, first convert to an int32 and then }
         { convert to a boolean (only necessary for 32bit processors) }
         { note: not if left is already a bool (qwordbool that is true, even if
             only because the highest bit is set, must remain true if it is
             --implicitly, unlike integers-- converted to another type of bool),
             Left can already be a bool because this routine can also be called
             from first_bool_to_bool }
         if not Is_Boolean(Left.ResultDef) and
            (Left.ResultDef.Size > sizeof(aint)) and
            (Left.ResultDef.Size<>ResultDef.Size)
            and Is_CBool(ResultDef) then
           begin
             Left:=CTypeConvNode.Create_Internal(Left,S32IntType);
             FirstPass(Left);
             exit;
           end;
         ExpectLoc:=LOC_REGISTER;
      end;


    function TTypeConvNode.First_Bool_To_Bool : TNode;
      begin
         First_Bool_To_Bool:=nil;
         if (Left.ExpectLoc in [LOC_FLAGS,LOC_JUMP]) and
            not Is_CBool(ResultDef) then
           ExpectLoc := Left.ExpectLoc
         { the following cases use the code generation for bool_to_int/
           int_to_bool -> also set their expectlocs }
         else if (ResultDef.Size=Left.ResultDef.Size) and
            (Is_CBool(ResultDef)=Is_CBool(Left.ResultDef)) then
           Result:=First_Bool_To_Int
         else
           Result:=First_Int_To_Bool
      end;


    function TTypeConvNode.First_Char_To_Char : TNode;
      var
        lFunctionName: string[18];
      begin
        if (TOrdDef(ResultDef).OrdType=uchar) and
           (TOrdDef(Left.ResultDef).OrdType=uwidechar) then
          lFunctionName := 'fpc_uchar_to_char'
        else if (TOrdDef(ResultDef).OrdType=uwidechar) and
           (TOrdDef(Left.ResultDef).OrdType=uchar) then
          lFunctionName := 'fpc_char_to_uchar'
        else
          InternalError(2007081201);

        Result := CCallNode.CreateIntern(lFunctionName,CCallParaNode.Create(Left,nil));
        Left:=nil;
        FirstPass(Result);
      end;


    function TTypeConvNode.First_Proc_To_ProcVar : TNode;
      begin
         First_Proc_To_ProcVar:=nil;
         { if we take the address of a nested function, the current function/
           procedure needs a stack frame since it's required to construct
           the nested procvar }
         if Is_Nested_PD(TProcVarDef(ResultDef)) and
            (
              not (po_anonymous in TProcDef(Left.ResultDef).ProcOptions) or
              (po_delphi_nested_cc in TProcVarDef(ResultDef).ProcOptions)
            ) then
           include(CurrentProcInfo.Flags,pi_needs_stackframe);
         if TAbstractProcDef(ResultDef).Is_AddressOnly then
           ExpectLoc:=LOC_REGISTER
         else
           ExpectLoc:=Left.ExpectLoc;
      end;


    function TTypeConvNode.First_Nil_To_MethodProcVar : TNode;
      begin
        First_Nil_To_MethodProcVar:=nil;
        ExpectLoc:=LOC_REGISTER;
      end;


    function TTypeConvNode.First_Set_To_Set : TNode;
      var
        lNewStatement : TStatementNode;
        lTemp         : TTempCreateNode;
      begin
        { in theory, we should do range checking here,
          but Delphi doesn't do it either (FK) }

        if Left.NodeType=setconstn then
          begin
            Left.ResultDef:=ResultDef;
            Result:=Left;
            Left:=nil;
          end
        { equal sets for the code generator? }
        else if (Left.ResultDef.Size=ResultDef.Size) and
                (TSetDef(Left.ResultDef).SetBase=TSetDef(ResultDef).SetBase) then
          { TODO: This causes wrong (but Delphi-compatible) results for disjoint subsets}
          { e.g., this prints true because of this:
              var
                sa: set of 1..2;
                sb: set of 5..6;
                b: byte;
              begin
                b:=1;
                sa:=[1..2];
                sb:=sa;
                writeln(b in sb);
              end.
          }
          begin
            Result:=Left;
            Left:=nil;
          end
        else
          begin
            Result:=InternalStatements(lNewStatement);

            { in case left is a smallset expression, it can be an addn or so. }
            { fpc_varset_load expects a formal const parameter, which doesn't }
            { accept set addn's -> assign to a temp first and pass the temp   }
            if not(Left.ExpectLoc in [LOC_REFERENCE,LOC_CREFERENCE]) then
              begin
                lTemp:=CTempCreateNode.Create(Left.ResultDef,Left.ResultDef.Size,tt_persistent,false);
                AddStatement(lNewStatement,lTemp);
                { temp := left }
                AddStatement(lNewStatement,CAssignmentNode.Create(
                  CTempRefNode.Create(lTemp),Left));
                AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lTemp));
                AddStatement(lNewStatement,CTempRefNode.Create(lTemp));
                Left:=Result;
                FirstPass(Left);
                { recreate the result's internalstatements list }
                Result:=InternalStatements(lNewStatement);
              end;

            { create temp for result }
            lTemp:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,true);
            AddStatement(lNewStatement,lTemp);

            AddStatement(lNewStatement,CCallNode.CreateIntern('fpc_varset_load',
              CCallParaNode.Create(COrdConstNode.Create(TSetDef(Left.ResultDef).SetBase div 8 - TSetDef(ResultDef).SetBase div 8,SIntType,false),
              CCallParaNode.Create(COrdConstNode.Create(ResultDef.Size,SIntType,false),
              CCallParaNode.Create(CTempRefNode.Create(lTemp),
              CCallParaNode.Create(COrdConstNode.Create(Left.ResultDef.Size,SIntType,false),
              CCallParaNode.Create(Left,nil))))))
            );
            AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lTemp));
            AddStatement(lNewStatement,CTempRefNode.Create(lTemp));
            Left:=nil;
          end;
      end;


    function TTypeConvNode.First_AnsiString_To_PChar : TNode;
      begin
         First_AnsiString_To_PChar:=nil;
         ExpectLoc:=LOC_REGISTER;
      end;


    function TTypeConvNode.First_ArrayConstructor_To_Set : TNode;
      begin
        First_ArrayConstructor_To_Set:=nil;
        InternalError(200104022);
      end;


    function TTypeConvNode.First_Class_To_Intf : TNode;
      var
        lObjectDef : TObjectDef;
        lImplementedInterface : TImplementedInterface;
      begin
         Result:=nil;
         ExpectLoc:=LOC_REGISTER;
         lObjectDef:=TObjectDef(Left.ResultDef);
         while Assigned(lObjectDef) do
           begin
             lImplementedInterface:=Find_Implemented_Interface(lObjectDef,TObjectDef(ResultDef));
             if Assigned(lImplementedInterface) then
               begin
                 case lImplementedInterface.IType of
                   etStandard:
                     { handle in pass 2 }
                     ;
                   etFieldValue, etFieldValueClass:
                     if Is_Interface(TObjectDef(ResultDef)) then
                       begin
                         Result:=Left;
                         PropAccessList_To_Node(Result,TPropertySym(lImplementedInterface.implementsgetter).owner,TPropertySym(lImplementedInterface.implementsgetter).PropAccessList[palt_read]);
                         { this ensures proper refcounting when field is of class type }
                         if not Is_Interface(Result.ResultDef) then
                           InsertTypeConv(Result, ResultDef);
                         Left:=nil;
                       end
                     else
                       begin
                         InternalError(200802213);
                       end;
                   etStaticMethodResult, etStaticMethodClass,
                   etVirtualMethodResult, etVirtualMethodClass:
                     if Is_Interface(TObjectDef(ResultDef)) then
                       begin
                         { TODO: generating a call to TObject.GetInterface instead could yield
                           smaller code size. OTOH, refcounting gotchas are possible that way. }
                         { constructor create(l:tnode; v : tprocsym;st : TSymtable; mp: tnode; callflags:tcallnodeflags); }
                         Result:=CCallNode.Create(nil,TProcSym(TPropertySym(lImplementedInterface.implementsgetter).PropAccessList[palt_read].FirstSym^.sym),
                           TProcSym(TPropertySym(lImplementedInterface.implementsgetter).PropAccessList[palt_read].FirstSym^.sym).owner,
                           Left,[],nil);
                         AddSymRef(TPropertySym(lImplementedInterface.implementsgetter).PropAccessList[palt_read].FirstSym^.sym);
                         { if it is a class, process it further in a similar way }
                         if not Is_Interface(Result.ResultDef) then
                           InsertTypeConv(Result, ResultDef);
                         Left:=nil;
                       end
                     else if Is_Class(TObjectDef(ResultDef)) then
                       begin
                         InternalError(200802211);
                       end
                     else
                       InternalError(200802231);
                 end;
                 break;
               end;
             lObjectDef:=lObjectDef.ChildOf;
           end;
         if lObjectDef=nil then
           InternalError(200802164);
      end;


    function TTypeConvNode.First_String_To_String : TNode;
      var
        lProcName: string[31];
        lNewBlock : TBlockNode;
        lNewStatement  : TStatementNode;
        lResultTemp  : TTempCreateNode;
      begin
        { get the correct procedure name }
        lProcName := 'fpc_'+TStringDef(Left.ResultDef).StringTypName+
                    '_to_'+TStringDef(ResultDef).StringTypName;

        if TStringDef(ResultDef).StringType=st_shortstring then
          begin
            lNewBlock:=InternalStatements(lNewStatement);
            lResultTemp:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,false);
            AddStatement(lNewStatement,lResultTemp);
            AddStatement(lNewStatement,CCallNode.CreateIntern(lProcName,CCallParaNode.Create(Left,CCallParaNode.Create(
              CTempRefNode.Create(lResultTemp),nil))));
            AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lResultTemp));
            AddStatement(lNewStatement,CTempRefNode.Create(lResultTemp));
            Result:=lNewBlock;
          end
        { encoding parameter required? }
        else if (TStringDef(ResultDef).StringType=st_ansistring) and
                (TStringDef(Left.ResultDef).StringType in [st_widestring,st_unicodestring,st_shortstring,st_ansistring]) then
            Result:=CCallNode.CreateInternRes(lProcName,
              CCallParaNode.Create(COrdConstNode.Create(GetParaEncoding(ResultDef),U16IntType,true),
              CCallParaNode.Create(Left,nil)),ResultDef)
        else
          Result:=CCallNode.CreateInternRes(lProcName,CCallParaNode.Create(Left,nil),ResultDef);

        Left:=nil;
      end;


    function TTypeConvNode.DispatchFirstIntToInt : TNode;
      begin
         Result:=First_Int_To_Int;
      end;

    function TTypeConvNode.DispatchFirstCStringToPChar : TNode;
      begin
         Result:=First_CString_To_PChar;
      end;

    function TTypeConvNode.DispatchFirstCStringToInt : TNode;
      begin
         Result:=First_CString_To_Int;
      end;

    function TTypeConvNode.DispatchFirstStringToCharArray : TNode;
      begin
         Result:=First_String_To_CharArray;
      end;

    function TTypeConvNode.DispatchFirstCharToString : TNode;
      begin
         Result:=First_Char_To_String;
      end;

    function TTypeConvNode.DispatchFirstCharToCharArray: TNode;
      begin
        Result:=First_Char_To_CharArray;
      end;

    function TTypeConvNode.DispatchFirstNothing : TNode;
      begin
         Result:=First_Nothing;
      end;

    function TTypeConvNode.DispatchFirstArrayToPointer : TNode;
      begin
         Result:=First_Array_To_Pointer;
      end;

    function TTypeConvNode.DispatchFirstIntToReal : TNode;
      begin
         Result:=First_Int_To_Real;
      end;

    function TTypeConvNode.DispatchFirstRealToReal : TNode;
      begin
         Result:=First_Real_To_Real;
      end;

    function TTypeConvNode.DispatchFirstPointerToArray : TNode;
      begin
         Result:=First_Pointer_To_Array;
      end;

    function TTypeConvNode.DispatchFirstCCharToPChar : TNode;
      begin
         Result:=First_CChar_To_PChar;
      end;

    function TTypeConvNode.DispatchFirstBoolToInt : TNode;
      begin
         Result:=First_Bool_To_Int;
      end;

    function TTypeConvNode.DispatchFirstIntToBool : TNode;
      begin
         Result:=First_Int_To_Bool;
      end;

    function TTypeConvNode.DispatchFirstBoolToBool : TNode;
      begin
         Result:=First_Bool_To_Bool;
      end;

    function TTypeConvNode.DispatchFirstProcToProcVar : TNode;
      begin
         Result:=First_Proc_To_ProcVar;
      end;

    function TTypeConvNode.DispatchFirstNilToMethodProcVar : TNode;
      begin
         Result:=First_Nil_To_MethodProcVar;
      end;

    function TTypeConvNode.DispatchFirstSetToSet : TNode;
      begin
         Result:=First_Set_To_Set;
      end;

    function TTypeConvNode.DispatchFirstCOrdToPointer : TNode;
      begin
         Result:=First_COrd_To_Pointer;
      end;

    function TTypeConvNode.DispatchFirstAnsiStringToPChar : TNode;
      begin
         Result:=First_AnsiString_To_PChar;
      end;

    function TTypeConvNode.DispatchFirstArrayConstructorToSet : TNode;
      begin
         Result:=First_ArrayConstructor_To_Set;
      end;

    function TTypeConvNode.DispatchFirstClassToIntf : TNode;
      begin
         Result:=First_Class_To_Intf;
      end;

    function TTypeConvNode.DispatchFirstCharToChar : TNode;
      begin
         Result:=First_Char_To_Char;
      end;

    function TTypeConvNode.DispatchFirstStringToString : TNode;
      begin
        Result:=First_String_To_String;
      end;

    function TTypeConvNode.First_Call_Helper(AConvertType : TConvertType) : TNode;

      const
         FirstConvert : array[TConvertType] of Pointer = (
           nil, { none }
           @TTypeConvNode.DispatchFirstNothing, {equal}
           @TTypeConvNode.DispatchFirstNothing, {not_possible}
           @TTypeConvNode.DispatchFirstStringToString,
           @TTypeConvNode.DispatchFirstCharToString,
           @TTypeConvNode.DispatchFirstCharToCharArray,
           nil, { removed in typecheck_chararray_to_string }
           @TTypeConvNode.DispatchFirstCCharToPChar,
           @TTypeConvNode.DispatchFirstCStringToPChar,
           @TTypeConvNode.DispatchFirstCStringToInt,
           @TTypeConvNode.DispatchFirstAnsiStringToPChar,
           @TTypeConvNode.DispatchFirstStringToCharArray,
           nil, { removed in typecheck_chararray_to_string }
           @TTypeConvNode.DispatchFirstArrayToPointer,
           @TTypeConvNode.DispatchFirstPointerToArray,
           @TTypeConvNode.DispatchFirstIntToInt,
           @TTypeConvNode.DispatchFirstIntToBool,
           @TTypeConvNode.DispatchFirstBoolToBool,
           @TTypeConvNode.DispatchFirstBoolToInt,
           @TTypeConvNode.DispatchFirstRealToReal,
           @TTypeConvNode.DispatchFirstIntToReal,
           nil, { removed in typecheck_real_to_currency }
           @TTypeConvNode.DispatchFirstProcToProcVar,
           @TTypeConvNode.DispatchFirstNilToMethodProcVar,
           @TTypeConvNode.DispatchFirstArrayConstructorToSet,
           @TTypeConvNode.DispatchFirstSetToSet,
           @TTypeConvNode.DispatchFirstCOrdToPointer,
           @TTypeConvNode.DispatchFirstNothing,
           @TTypeConvNode.DispatchFirstNothing,
           @TTypeConvNode.DispatchFirstClassToIntf,
           @TTypeConvNode.DispatchFirstCharToChar,
           @TTypeConvNode.DispatchFirstNothing,
           @TTypeConvNode.DispatchFirstNothing,
           nil,
           nil,
           nil,
           nil,
           nil,
           nil,
           nil,
           @TTypeConvNode.DispatchFirstNothing,
           @TTypeConvNode.DispatchFirstNothing,
           @TTypeConvNode.DispatchFirstNothing,
           nil,
           nil
         );
      type
         TProcedureOfObject = function : TNode of object;
      var
         lMethod : TMethod;
      begin
         { this is a little bit dirty but it works }
         { and should be quite portable too        }
         lMethod.Code:=FirstConvert[AConvertType];
         lMethod.Data:=Self;
         if not Assigned(lMethod.Code) then
           InternalError(200312081);
         First_Call_Helper:=TProcedureOfObject(lMethod)()
      end;


    function TTypeConvNode.Pass_1 : TNode;
      begin
        if WarnPointerToSigned then
          CGMessage(type_w_pointer_to_signed);
        Result:=nil;
        FirstPass(Left);
        if CodeGenError then
         exit;
        ExpectLoc:=Left.ExpectLoc;

        if nf_explicit in Flags then
          { check if the result could be in a register }
          if (not(TStoredDef(ResultDef).Is_IntRegable) and
              not(TStoredDef(ResultDef).Is_Const_IntRegable) and
              not(TStoredDef(ResultDef).Is_FPURegable)) or
             ((Left.ResultDef.typ = floatdef) and
              (ResultDef.typ <> floatdef))  then
            Make_Not_Regable(Left,[ra_addr_regable]);

        Result:=First_Call_Helper(ConvType);
      end;


    function TTypeConvNode.Retains_Value_Location:Boolean;
      begin
        Result:=Assigned(Left.ResultDef) and
                (
                (ConvType=tc_equal) or
                { typecasting from void is always allowed }
                Is_Void(Left.ResultDef) or
                (Left.ResultDef.typ=formaldef) or
                { int 2 int with same size reuses same location }
                (
                 (ConvType=tc_int_2_int) and
                 (
                  not Is_BitPacked_Access(Left) and
                  (ResultDef.Size=Left.ResultDef.Size)
                 )
                ) or
                { int 2 bool/bool 2 int, explicit typecast, see also nx86cnv }
                ((ConvType in [tc_int_2_bool,tc_bool_2_int,tc_bool_2_bool]) and
                 (nf_explicit in Flags) and
                 (ResultDef.Size=Left.ResultDef.Size)) or
                { on managed platforms, converting an element to an open array
                  involves creating an actual array -> value location changes }
                (ConvType=tc_elem_2_openarray)
                );
      end;


    function TTypeConvNode.Assign_Allowed:Boolean;
      begin
        Result:=Retains_Value_Location;

        { When using only a part of the value it can't be in a register since
          that will load the value in a new register first }
        { the same goes for changing the sign of equal-sized values which
          are smaller than an entire register }
        if Result and
           { don't try to check the size of an open array or an array of const }
           (Is_Open_Array(ResultDef) or
            Is_Open_Array(Left.ResultDef) or
            Is_Array_Of_Const(ResultDef) or
            Is_Array_Of_Const(Left.ResultDef) or
            (ResultDef.Size<Left.ResultDef.Size) or
            ((ResultDef.Size=Left.ResultDef.Size) and
             (Left.ResultDef.Size<sizeof(aint)) and
             (Is_Signed(ResultDef) xor Is_Signed(Left.ResultDef)))) then
          Make_Not_Regable(Left,[ra_addr_regable]);
      end;


    function TTypeConvNode.DoCompare(ANode: TNode) : Boolean;
      begin
        DoCompare :=
          inherited DoCompare(ANode) and
          (ConvType = TTypeConvNode(ANode).ConvType) and
          (ConvNodeFlags = TTypeConvNode(ANode).ConvNodeFlags) and
          Equal_Defs(ToTypeDef,TTypeConvNode(ANode).ToTypeDef);
      end;


    procedure TTypeConvNode._Second_Int_To_Int;
      begin
        Second_Int_To_Int;
      end;


    procedure TTypeConvNode._Second_String_To_String;
      begin
        Second_String_To_String;
      end;


    procedure TTypeConvNode._Second_CString_To_PChar;
      begin
        Second_CString_To_PChar;
      end;


    procedure TTypeConvNode._Second_CString_To_Int;
      begin
        Second_CString_To_Int;
      end;


    procedure TTypeConvNode._Second_String_To_CharArray;
      begin
        Second_String_To_CharArray;
      end;


    procedure TTypeConvNode._Second_Array_To_Pointer;
      begin
        Second_Array_To_Pointer;
      end;


    procedure TTypeConvNode._Second_Pointer_To_Array;
      begin
        Second_Pointer_To_Array;
      end;


    procedure TTypeConvNode._Second_CharArray_To_String;
      begin
        Second_CharArray_To_String;
      end;


    procedure TTypeConvNode._Second_Char_To_String;
      begin
        Second_Char_To_String;
      end;


    procedure TTypeConvNode._Second_Int_To_Real;
      begin
        Second_Int_To_Real;
      end;


    procedure TTypeConvNode._Second_Real_To_Real;
      begin
        Second_Real_To_Real;
      end;


    procedure TTypeConvNode._Second_COrd_To_Pointer;
      begin
        Second_COrd_To_Pointer;
      end;


    procedure TTypeConvNode._Second_Proc_To_ProcVar;
      begin
        Second_Proc_To_ProcVar;
      end;

    procedure TTypeConvNode._Second_Nil_To_MethodProcVar;
      begin
        Second_Nil_To_MethodProcVar;
      end;

    procedure TTypeConvNode._Second_Bool_To_Int;
      begin
        Second_Bool_To_Int;
      end;


    procedure TTypeConvNode._Second_Int_To_Bool;
      begin
        Second_Int_To_Bool;
      end;


    procedure TTypeConvNode._Second_Bool_To_Bool;
      begin
        Second_Bool_To_Bool;
      end;


    procedure TTypeConvNode._Second_Set_To_Set;
      begin
        Second_Set_To_Set;
      end;


    procedure TTypeConvNode._Second_AnsiString_To_PChar;
      begin
        Second_AnsiString_To_PChar;
      end;


    procedure TTypeConvNode._Second_Class_To_Intf;
      begin
        Second_Class_To_Intf;
      end;


    procedure TTypeConvNode._Second_Char_To_Char;
      begin
        Second_Char_To_Char;
      end;


    procedure TTypeConvNode._Second_Elem_To_OpenArray;
      begin
        Second_Elem_To_OpenArray;
      end;


    procedure TTypeConvNode._Second_Nothing;
      begin
        Second_Nothing;
      end;


    procedure TTypeConvNode.Second_Call_Helper(AConvertType : TConvertType);
      const
         SecondConvert : array[TConvertType] of Pointer = (
           @TTypeConvNode._Second_Nothing, {none}
           @TTypeConvNode._Second_Nothing, {equal}
           @TTypeConvNode._Second_Nothing, {not_possible}
           @TTypeConvNode._Second_Nothing, {second_string_to_string, handled in resultdef pass }
           @TTypeConvNode._Second_Char_To_String,
           @TTypeConvNode._Second_Nothing, {char_to_charray}
           @TTypeConvNode._Second_Nothing, { pchar_to_string, handled in resultdef pass }
           @TTypeConvNode._Second_Nothing, {cchar_to_pchar}
           @TTypeConvNode._Second_CString_To_PChar,
           @TTypeConvNode._Second_CString_To_Int,
           @TTypeConvNode._Second_AnsiString_To_PChar,
           @TTypeConvNode._Second_String_To_CharArray,
           @TTypeConvNode._Second_Nothing, { chararray_to_string, handled in resultdef pass }
           @TTypeConvNode._Second_Array_To_Pointer,
           @TTypeConvNode._Second_Pointer_To_Array,
           @TTypeConvNode._Second_Int_To_Int,
           @TTypeConvNode._Second_Int_To_Bool,
           @TTypeConvNode._Second_Bool_To_Bool,
           @TTypeConvNode._Second_Bool_To_Int,
           @TTypeConvNode._Second_Real_To_Real,
           @TTypeConvNode._Second_Int_To_Real,
           @TTypeConvNode._Second_Nothing, { real_to_currency, handled in resultdef pass }
           @TTypeConvNode._Second_Proc_To_ProcVar,
           @TTypeConvNode._Second_Nil_To_MethodProcVar,
           @TTypeConvNode._Second_Nothing, { arrayconstructor_to_set }
           @TTypeConvNode._Second_Nothing, { second_set_to_set, handled in first pass }
           @TTypeConvNode._Second_COrd_To_Pointer,
           @TTypeConvNode._Second_Nothing, { interface 2 string }
           @TTypeConvNode._Second_Nothing, { interface 2 guid   }
           @TTypeConvNode._Second_Class_To_Intf,
           @TTypeConvNode._Second_Char_To_Char,
           @TTypeConvNode._Second_Nothing,  { dynarray_2_openarray }
           @TTypeConvNode._Second_Nothing,  { pwchar_2_string }
           @TTypeConvNode._Second_Nothing,  { variant_2_dynarray }
           @TTypeConvNode._Second_Nothing,  { dynarray_2_variant}
           @TTypeConvNode._Second_Nothing,  { variant_2_enum }
           @TTypeConvNode._Second_Nothing,  { enum_2_variant }
           @TTypeConvNode._Second_Nothing,  { variant_2_interface }
           @TTypeConvNode._Second_Nothing,  { interface_2_variant }
           @TTypeConvNode._Second_Nothing,  { array_2_dynarray }
           @TTypeConvNode._Second_Elem_To_OpenArray,  { elem_2_openarray }
           @TTypeConvNode._Second_Nothing,  { arrayconstructor_2_dynarray }
           @TTypeConvNode._Second_Nothing,  { arrayconstructor_2_array }
           @TTypeConvNode._Second_Nothing,  { anonproc_2_funcref }
           @TTypeConvNode._Second_Nothing   { procvar_2_funcref }
         );
      type
         TProcedureOfObject = procedure of object;

      var
         lMethod : TMethod;

      begin
         { this is a little bit dirty but it works }
         { and should be quite portable too        }
         lMethod.Code:=SecondConvert[AConvertType];
         lMethod.Data:=Self;
         TProcedureOfObject(lMethod)();
      end;

{*****************************************************************************
                                TASNODE
*****************************************************************************}

    function TAsIsNode.Target_Specific_TypeCheck: Boolean;
      begin
        Result:=false;
      end;


    function TAsIsNode.Pass_TypeCheck: TNode;
      var
        lNode : TNode;
      begin
        Result:=nil;
        TypeCheckPass(Right);
        TypeCheckPass(Left);

        Set_VarState(Right,vs_read,[vsf_must_be_valid]);
        Set_VarState(Left,vs_read,[vsf_must_be_valid]);

        if CodeGenError then
          exit;

        if Target_Specific_TypeCheck then
          begin
            // ok
          end
        else if (Right.ResultDef.typ=classrefdef) then
          begin
            { left maybe an interface reference }
            if Is_InterfaceCOM(Left.ResultDef) then
              begin
                { relation checks are not possible }
              end
            { or left must be a class }
            else if Is_Class(Left.ResultDef) then
              begin
                { the operands must be related }
                if (not(Def_Is_Related(TObjectDef(Left.ResultDef),
                   TObjectDef(TClassRefDef(Right.ResultDef).PointedDef)))) and
                   (not(Def_Is_Related(TObjectDef(TClassRefDef(Right.ResultDef).PointedDef),
                   TObjectDef(Left.ResultDef)))) then
                  CGMessage2(type_e_classes_not_related,
                     FullTypeName(Left.ResultDef,TClassRefDef(Right.ResultDef).PointedDef),
                     FullTypeName(TClassRefDef(Right.ResultDef).PointedDef,Left.ResultDef));
              end
            else
              CGMessage1(type_e_class_or_cominterface_type_expected,Left.ResultDef.TypeName);
            case NodeType of
              isn:
                ResultDef:=PasBool1Type;
              asn:
                ResultDef:=TClassRefDef(Right.ResultDef).PointedDef;
              else
                ;
            end;
          end
        else if Is_Interface(Right.ResultDef) or
                Is_DispInterface(Right.ResultDef) then
          begin
           case NodeType of
             isn:
               ResultDef:=PasBool1Type;
             asn:
               ResultDef:=Right.ResultDef;
             else
               ;
           end;

            { left is a class or interface }
            if not(Is_Class(Left.ResultDef) or
                   Is_InterfaceCOM(Left.ResultDef)) then
              CGMessage1(type_e_class_or_cominterface_type_expected,Left.ResultDef.TypeName)
            else
              begin

                { load the GUID of the interface }
                if (Right.NodeType=typen) then
                  begin
                    if TObjectDef(Right.ResultDef).ObjectType=odt_interfacecorba then
                      begin
                        if Assigned(TObjectDef(Right.ResultDef).IIDStr) then
                          begin
                            if not(oo_has_valid_guid in TObjectDef(Right.ResultDef).ObjectOptions) and not Is_TypeParam(Right.ResultDef) then
                              CGMessage1(type_e_interface_has_no_name,TObjectDef(Right.ResultDef).TypeName);
                            lNode:=CStringConstNode.CreateStr(TObjectDef(Right.ResultDef).IIDStr^);
                            TStringConstNode(lNode).ChangeStringType(CShortStringType);
                            Right.free;
                            Right:=lNode;
                          end
                        else
                          InternalError(201006131);
                      end
                    else
                      begin
                        if Assigned(TObjectDef(Right.ResultDef).IIDGUID) then
                          begin
                            if not(oo_has_valid_guid in TObjectDef(Right.ResultDef).ObjectOptions) and not Is_TypeParam(Right.ResultDef) then
                              CGMessage1(type_e_interface_has_no_guid,TObjectDef(Right.ResultDef).TypeName);
                            lNode:=CGUIDConstNode.Create(TObjectDef(Right.ResultDef).IIDGUID^);
                            Right.free;
                            Right:=lNode;
                          end
                        else
                          InternalError(201006132);
                      end;
                    TypeCheckPass(Right);
                  end;
              end;
          end
        else
          CGMessage1(type_e_class_or_interface_type_expected,Right.ResultDef.TypeName);
      end;

{*****************************************************************************
                                TISNODE
*****************************************************************************}

    constructor TIsNode.Create(ALeft,ARight : TNode);

      begin
         inherited Create(isn,ALeft,ARight);
      end;


    constructor TIsNode.Create_Internal(ALeft, ARight: TNode);

      begin
        Create(ALeft,ARight);
        include(Flags,nf_internal);
      end;


    function TIsNode.Pass_1 : TNode;
      var
        lProcName: string;
        lStatement : TStatementNode;
        lTempNode : TTempCreateNode;
      begin
        Result:=nil;
        { Passing a class type to an "is" expression cannot result in a class
          of that type to be constructed.
        }
        include(Right.Flags,nf_ignore_for_wpo);

        if Is_Class(Left.ResultDef) and
           (Right.ResultDef.typ=classrefdef) then
          begin
            if (Right.NodeType=loadvmtaddrn) and
              (TLoadVMTAddrNode(Right).Left.NodeType=typen) and
              (oo_is_sealed in TObjectDef(TLoadVMTAddrNode(Right).Left.ResultDef).ObjectOptions) and
              Equal_Defs(Left.ResultDef,TClassRefDef(Right.ResultDef).PointedDef) then
              begin
                if Might_Have_SideEffects(Left) or
                  (Node_Complexity(Left)>2) then
                  begin
                    Result:=InternalStatements(lStatement);
                    lTempNode:=CTempCreateNode.Create(Left.ResultDef,Left.ResultDef.Size,tt_persistent,true);
                    AddStatement(lStatement,lTempNode);
                    AddStatement(lStatement,CAssignmentNode.Create_Internal(CTempRefNode.Create(lTempNode),Left));
                    AddStatement(lStatement,CAddNode.Create_Internal(andn,
                      CAddNode.Create_Internal(unequaln,CTempRefNode.Create(lTempNode),CNilNode.Create),
                      CAddNode.Create_Internal(EqualN,CLoadVMTAddrNode.Create(CTempRefNode.Create(lTempNode)),Right)
                      )
                    );

                    Left:=nil;
                    Right:=nil;
                  end
                else
                  begin
                    Result:=CAddNode.Create_Internal(andn,
                      CAddNode.Create_Internal(unequaln,Left.GetCopy,CNilNode.Create),
                      CAddNode.Create_Internal(EqualN,CLoadVMTAddrNode.Create(Left.GetCopy),Right)
                      );
                    Right:=nil;
                  end;
              end
            else
              Result := CCallNode.CreateInternRes('fpc_do_is',
                CCallParaNode.Create(Left,CCallParaNode.Create(Right,nil)),
                ResultDef);
          end
        else
          begin
            if Is_Class(Left.ResultDef) then
              if Is_ShortString(Right.ResultDef) then
                lProcName := 'fpc_class_is_corbaintf'
              else
                lProcName := 'fpc_class_is_intf'
            else
              if Right.ResultDef.typ=classrefdef then
                lProcName := 'fpc_intf_is_class'
              else
                lProcName := 'fpc_intf_is';
            Result := CTypeConvNode.Create_Internal(CCallNode.CreateIntern(lProcName,
               CCallParaNode.Create(Right,CCallParaNode.Create(Left,nil))),ResultDef);
          end;
        Left := nil;
        Right := nil;
        //firstpass(call);
        if CodeGenError then
          exit;
      end;

    { dummy pass_2, it will never be called, but we need one since }
    { you can't instantiate an abstract class                      }
    procedure TIsNode.Pass_Generate_Code;
      begin
      end;


{*****************************************************************************
                                TASNODE
*****************************************************************************}

    constructor TAsNode.Create(ALeft,ARight : TNode);

      begin
         inherited Create(asn,ALeft,ARight);
         Call := nil;
      end;


    constructor TAsNode.Create_Internal(ALeft,ARight : TNode);

      begin
        Create(ALeft,ARight);
        include(Flags,nf_internal);
      end;


    destructor TAsNode.Destroy;

      begin
        Call.free;
        Call := nil;
        inherited Destroy;
      end;


    function TAsNode.DoGetCopy: TNode;
      begin
        Result := inherited DoGetCopy;
        if Assigned(Call) then
          TAsNode(Result).Call := Call.GetCopy
        else
          TAsNode(Result).Call := nil;
      end;


    function TAsNode.DoCompare(ANode: TNode): Boolean;
      begin
        Result:=
          inherited DoCompare(ANode) and
          TAsNode(ANode).Call.IsEqual(Call);
      end;


    function TAsNode.Pass_1 : TNode;
      var
        lProcName: string;
      begin
        Result:=nil;
        { Passing a class type to an "as" expression cannot result in a class
          of that type to be constructed.

          We could put this inside the if-block below, but this way it is
          safe for sure even if the code below changes
        }
        if Assigned(Right) then
          include(Right.Flags,nf_ignore_for_wpo);

        if not Assigned(Call) then
          begin
            if Is_Class(Left.ResultDef) and
               (Right.ResultDef.typ=classrefdef) then
              Call := CCallNode.CreateInternRes('fpc_do_as',
                CCallParaNode.Create(Left,CCallParaNode.Create(Right,nil)),
                ResultDef)
            else
              begin
                if Is_Class(Left.ResultDef) then
                  if Is_ShortString(Right.ResultDef) then
                    lProcName := 'fpc_class_as_corbaintf'
                  else
                    lProcName := 'fpc_class_as_intf'
                else
                  if Right.ResultDef.typ=classrefdef then
                    lProcName := 'fpc_intf_as_class'
                  else
                    lProcName := 'fpc_intf_as';
                Call := CTypeConvNode.Create_Internal(CCallNode.CreateIntern(lProcName,
                   CCallParaNode.Create(Right,CCallParaNode.Create(Left,nil))),ResultDef);
              end;
            Left := nil;
            Right := nil;
            FirstPass(Call);
            if CodeGenError then
              exit;
           ExpectLoc:=Call.ExpectLoc;
         end;
      end;

end.
