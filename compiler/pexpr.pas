{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Does parsing of expression for Free Pascal

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
unit pexpr;

{$i fpcdefs.inc}

interface

    uses
      TPCompilerReal,
      symtype,symdef,SymBase,
      node,ncal,compinnr,
      tokens,GlobType,Globals,ConstExp,
      pgentype,pstatmnt;

    type
      TExprFlag = (
        efAcceptEqual,
        efTypeOnly,
        efHadSpecialize,
        efCheckAttrSuffix
      );
      TExprFlags = set of TExprFlag;

    { reads a whole expression }
    function Expr(ADoTypeCheck:Boolean) : TNode;

    { reads an expression without assignments and .. }
    function CompExpr(AFlags:TExprFlags):TNode;

    { reads a single factor }
    function Factor(AGetAddr:Boolean;AFlags:TExprFlags) : TNode;

    procedure StringDec(var ADef: TDef; AAllowTypeDef: Boolean);

    function ParseParas(AColon,ANamedPara : Boolean;AEndOfParas : TToken) : TNode;

    { the ID token has to be consumed before calling this function }
    procedure DoMemberRead(AStruct:TAbstractRecordDef;AGetAddr:Boolean;ASym:TSym;var ANode:TNode;var AAgain:Boolean;ACallFlags:TCallNodeFlags;ASpecializationContext:TSpecializationContext);

    function GetIntConst:TConstExprInt;
    function GetStringConst:String;

    { Does some postprocessing for a generic type (especially when nested types
      of the specialization are used) }
    procedure PostCompExprGenDef(var ADef: TDef);

implementation

    uses
       { common }
       CUtils,CClasses,
       { global }
       Verbose,
       Systems,WideStr,
       { symtable }
       symconst,SymTable,SymSym,symcpu,defutil,defcmp,
       { module }
       FModule,PPU,
       { pass 1 }
       Pass_1,
       nmat,nadd,nmem,nset,ncnv,ninl,ncon,nld,nflw,nbas,nutils,
       { parser }
       Scanner,
       pbase,pinline,ptype,pgenutil,psub,ProcInfo,CPUInfo
       ;

    function SubExpr(APrecedence:TOperatorPrecedence;AFlags:TExprFlags;AFactorNode:TNode):TNode;forward;

    var
       { true, if the inherited call is anonymous }
       AnonInherited : Boolean = false;
       { last def found, only used by anon. inherited calls to insert proper type casts }
       SRDef : TDef = nil;
       { true while parsing the argument of NameOf }
       NameOfActive : Boolean = false;
       { last symbol found while parsing the argument of NameOf }
       NameOfSym : TSym = nil;
       { position of the token following nameof_sym }
       NameOfNextPos : TFilePosInfo;

    procedure NameOfRecordSym(ASym:TSym);
      begin
        if not NameOfActive or not Assigned(ASym) then
          exit;
        NameOfSym:=ASym;
        NameOfNextPos:=CurrentFilePos;
      end;

    { returns the declared name of sym without generic parameters }
    function NameOfSymName(ASym:TSym):String;
      var
        lIndex : LongInt;
      begin
        if (ASym.typ in [absolutevarsym,localvarsym,paravarsym]) and
           (vo_is_funcret in TAbstractVarSym(ASym).VarOptions) then
          begin
            { the function result symbols are stored uppercase }
            if vo_is_result in TAbstractVarSym(ASym).VarOptions then
              exit('Result');
            if Assigned(ASym.owner.DefOwner) and
               (TDef(ASym.owner.DefOwner).typ=procdef) then
              exit(TProcDef(ASym.owner.DefOwner).ProcSym.realname);
          end;
        { use the declared unit name, e.g. the implicit system unit is stored uppercase }
        if (ASym.typ=UnitSym) and
           Assigned(TUnitSym(ASym).module) and
           Assigned(TModule(TUnitSym(ASym).module).RealModuleName) then
          exit(TModule(TUnitSym(ASym).module).RealModuleName^);
        Result:=ASym.realname;
        for lIndex:=1 to length(Result) do
          if Result[lIndex] in ['$','<'] then
            begin
              if lIndex>1 then
                SetLength(Result,lIndex-1);
              break;
            end;
      end;

    procedure StringDec(var ADef:TDef; AAllowTypeDef: Boolean);
    { reads a string type with optional length }
    { and returns a pointer to the string      }
    { definition                               }
      var
         lNode : TNode;
      begin
         ADef:=CShortStringType;
         Consume(_STRING);
         if CurrentScanner.FToken=_LECKKLAMMER then
           begin
             if not(AAllowTypeDef) then
               Message(parser_e_no_local_para_def);
             Consume(_LECKKLAMMER);
             lNode:=CompExpr([efAcceptEqual]);
             if not Is_ConstIntNode(lNode) then
               begin
                 Message(parser_e_illegal_expression);
                 { error recovery }
                 Consume(_RECKKLAMMER);
               end
             else
               begin
                { the node is a generic param while parsing a generic def
                  so disable the range checking for the string }
                if ParseGeneric and
                  (nf_generic_para in lNode.flags) then
                  TOrdConstNode(lNode).Value:=255;
                if TOrdConstNode(lNode).Value<=0 then
                  begin
                     Message(parser_e_invalid_string_size);
                     TOrdConstNode(lNode).Value:=255;
                  end;
                if TOrdConstNode(lNode).Value>255 then
                  begin
                    { longstring is currently unsupported (CEC)! }
{                    t:=cstringdef.createlong(tordconstnode(p).value))}
                    Message(parser_e_invalid_string_size);
                    TOrdConstNode(lNode).Value:=255;
                    ADef:=CStringDef.CreateShort(Int64(TOrdConstNode(lNode).Value),true);
                  end
                else
                  if TOrdConstNode(lNode).Value<>255 then
                    ADef:=CStringDef.CreateShort(Int64(TOrdConstNode(lNode).Value),true);
                Consume(_RECKKLAMMER);
              end;
             lNode.free;
             lNode := nil;
           end
          else
            begin
             // string[x] is allowed in system unit since it is a shortstring.
             if cs_compilesystem in CurrentSettings.ModuleSwitches then
               Message(parser_e_nostringaliasinsystem);
              if cs_refcountedstrings in CurrentSettings.LocalSwitches then
                begin
                  if m_default_unicodestring in CurrentSettings.ModeSwitches then
                    ADef:=CUnicodeStringType
                  else
                    ADef:=CAnsiStringType
                end
              else
                ADef:=CShortStringType;
            end;
       end;


    function ParseParas(AColon,ANamedPara : Boolean;AEndOfParas : TToken) : TNode;
      var
         lNode,lLastNode,lArgName : TNode;
         lPrevInArgs,
         lOldNamedArgsAllowed : Boolean;
      begin
         if CurrentScanner.FToken=AEndOfParas then
           begin
              ParseParas:=nil;
              exit;
           end;
         { save old values }
         lPrevInArgs:=InArgs;
         lOldNamedArgsAllowed:=NamedArgsAllowed;
         { set para parsing values }
         InArgs:=true;
         NamedArgsAllowed:=false;
         lLastNode:=nil;
         repeat
           if ANamedPara then
             begin
               if CurrentScanner.FToken=_COMMA then
                 begin
                   { empty parameter }
                   lLastNode:=CCallParaNode.Create(CNothingNode.Create,lLastNode);
                 end
               else
                 begin
                   NamedArgsAllowed:=true;
                   lNode:=CompExpr([efAcceptEqual]);
                   NamedArgsAllowed:=false;
                   if FoundArgName then
                     begin
                       lArgName:=lNode;
                       lNode:=CompExpr([efAcceptEqual]);
                       lLastNode:=CCallParaNode.Create(lNode,lLastNode);
                       TCallParaNode(lLastNode).ParameterName:=lArgName;
                     end
                   else
                     lLastNode:=CCallParaNode.Create(lNode,lLastNode);
                   FoundArgName:=false;
                 end;
             end
           else
             begin
               lNode:=CompExpr([efAcceptEqual]);
               lLastNode:=CCallParaNode.Create(lNode,lLastNode);
             end;
           { it's for the str(l:5,s); }
           if AColon and (CurrentScanner.FToken=_COLON) then
             begin
               Consume(_COLON);
               lNode:=CompExpr([efAcceptEqual]);
               lLastNode:=CCallParaNode.Create(lNode,lLastNode);
               include(TCallParaNode(lLastNode).CallParaFlags,cpf_is_colon_para);
               if TryToConsume(_COLON) then
                 begin
                   lNode:=CompExpr([efAcceptEqual]);
                   lLastNode:=CCallParaNode.Create(lNode,lLastNode);
                   include(TCallParaNode(lLastNode).CallParaFlags,cpf_is_colon_para);
                 end
             end;
         until not TryToConsume(_COMMA);
         InArgs:=lPrevInArgs;
         NamedArgsAllowed:=lOldNamedArgsAllowed;
         ParseParas:=lLastNode;
      end;


     function GenCStyleOperator(ANodeType:TNodeType;ALeft,ARight:TNode) : TNode;
       var
         lDef  : TDef;
         lTemp  : TTempCreateNode;
         lStatement : TStatementNode;
       begin
         { Properties are not allowed, because the write can
           be different from the read }
         if (nf_isproperty in ALeft.flags) then
           begin
             Message(type_e_variable_id_expected);
             { We can continue with the loading,
               it'll not create errors. Only the expected
               result can be wrong }
           end;

         if Might_Have_SideEffects(ALeft,[]) then
           begin
             TypeCheckPass(ALeft);
             Result:=InternalStatements(lStatement);
             lDef:=CPointerDef.getreusable(ALeft.resultdef);
             lTemp:=CTempCreateNode.Create(lDef,sizeof(PInt),tt_persistent,false);
             AddStatement(lStatement,lTemp);
             AddStatement(lStatement,CAssignmentNode.Create(CTempRefNode.Create(lTemp),CAddrNode.Create_Internal(ALeft)));
             AddStatement(lStatement,CAssignmentNode.Create(
                 CDerefNode.Create(CTempRefNode.Create(lTemp)),
                 CAddNode.Create(ANodeType,
                     CDerefNode.Create(CTempRefNode.Create(lTemp)),
                     ARight)));
             AddStatement(lStatement,CTempDeleteNode.Create(lTemp));
           end
         else
           Result:=CAssignmentNode.Create(ALeft,CAddNode.Create(ANodeType,ALeft.GetCopy,ARight));
       end;


     function StatementSysSym(AInlineNumber : TInlineNumber) : TNode;
      var
        lNode,lSecondNode,lParas  : TNode;
        lError,
        lPrevInArgs : Boolean;
        lDef : TDef;
        lExitProcInfo: TProcInfo;
        lOldNameOfActive,
        lNameOfOK : Boolean;
        lOldNameOfSym : TSym;
        lOldNameOfNextPos : TFilePosInfo;
      begin
        lPrevInArgs:=InArgs;
        case AInlineNumber of

          in_new_x :
            begin
              if AfterAssignment or InArgs then
               StatementSysSym:=New_Function
              else
               StatementSysSym:=New_Dispose_Statement(true);
            end;

          in_dispose_x :
            begin
              StatementSysSym:=New_Dispose_Statement(false);
            end;

          in_ord_x,
          in_chr_byte:
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              Consume(_RKLAMMER);
              lNode:=GenInlineNode(AInlineNumber,false,lNode);
              StatementSysSym := lNode;
            end;

          in_exit :
            begin
              StatementSysSym:=nil;
              if TryToConsume(_LKLAMMER) then
                begin
                  if not (m_mac in CurrentSettings.ModeSwitches) then
                    begin
                      if not(TryToConsume(_RKLAMMER)) then
                        begin
                          lNode:=CompExpr([efAcceptEqual]);
                          Consume(_RKLAMMER);
                          if not Assigned(CurrentProcInfo) or
                             (CurrentProcInfo.procdef.ProcTypeOption in [potype_constructor,potype_destructor]) or
                             Is_Void(CurrentProcInfo.procdef.ReturnDef) then
                            begin
                              Message(parser_e_void_function);
                              { recovery }
                              lNode.free;
                              lNode:=nil;
                            end;
                        end
                      else
                        lNode:=nil;
                    end
                  else
                    begin
                      { non local exit ? }
                      if CurrentProcInfo.procdef.ProcSym.name<>CurrentScanner.FPattern then
                        begin
                          lExitProcInfo:=CurrentProcInfo.parent;
                          while Assigned(lExitProcInfo) do
                            begin
                              if lExitProcInfo.procdef.ProcSym.name=CurrentScanner.FPattern then
                                break;
                              lExitProcInfo:=lExitProcInfo.parent;
                            end;
                          if Assigned(lExitProcInfo) then
                            begin
                              if not(Assigned(lExitProcInfo.NestedExitLabel)) then
                                begin
                                  include(CurrentProcInfo.flags,pi_has_nested_exit);
                                  exclude(CurrentProcInfo.procdef.ProcOptions,po_inline);
                                  if Is_Nested_PD(CurrentProcInfo.procdef) then
                                    CurrentProcInfo.Set_Needs_ParentFP(lExitProcInfo.procdef.ParaST.SymTableLevel);

                                  lExitProcInfo.NestedExitLabel:=CLabelSym.Create('$nestedexit');

                                  { the compiler is responsible to define this label }
                                  lExitProcInfo.NestedExitLabel.defined:=true;
                                  lExitProcInfo.NestedExitLabel.used:=true;

                                  lExitProcInfo.NestedExitLabel.JumpBuf:=CLocalVarSym.Create('LABEL$_'+lExitProcInfo.NestedExitLabel.name,vs_value,Rec_Jmp_Buf,[]);
                                  lExitProcInfo.procdef.LocalST.InsertSym(lExitProcInfo.NestedExitLabel);
                                  lExitProcInfo.procdef.LocalST.InsertSym(lExitProcInfo.NestedExitLabel.JumpBuf);
                                end;

                              StatementSysSym:=CGotoNode.Create(lExitProcInfo.NestedExitLabel);
                              TGotoNode(StatementSysSym).LabelSym:=lExitProcInfo.NestedExitLabel;
                            end
                          else
                            Message(parser_e_macpas_exit_wrong_param);
                        end;
                      Consume(_ID);
                      Consume(_RKLAMMER);
                      lNode:=nil;
                    end
                end
              else
                lNode:=nil;
              if not Assigned(StatementSysSym) then
                StatementSysSym:=CExitNode.Create(lNode);
            end;

          in_break :
            begin
              StatementSysSym:=CBreakNode.Create
            end;

          in_continue :
            begin
              StatementSysSym:=CContinueNode.Create
            end;

          in_leave :
            begin
              if m_mac in CurrentSettings.ModeSwitches then
                StatementSysSym:=CBreakNode.Create
              else
                begin
                  Message1(sym_e_id_not_found, CurrentScanner.FOrgPattern);
                  StatementSysSym:=CErrorNode.Create;
                end;
            end;

          in_cycle :
            begin
              if m_mac in CurrentSettings.ModeSwitches then
                StatementSysSym:=CContinueNode.Create
              else
                begin
                  Message1(sym_e_id_not_found, CurrentScanner.FOrgPattern);
                  StatementSysSym:=CErrorNode.Create;
                end;
            end;

          in_typeof_x :
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              Consume(_RKLAMMER);
              if lNode.nodetype=typen then
                TTypeNode(lNode).allowed:=true;
              { Allow classrefdef, which is required for
                Typeof(self) in static class methods }
              if not(Is_ObjC_Class_Or_Protocol(lNode.resultdef)) and
                 ((lNode.resultdef.typ = objectdef) or
                  (Assigned(CurrentProcInfo) and
                   ((po_classmethod in CurrentProcInfo.procdef.ProcOptions) or
                    (po_staticmethod in CurrentProcInfo.procdef.ProcOptions)) and
                   (lNode.resultdef.typ=classrefdef))) then
               StatementSysSym:=GenInlineNode(in_typeof_x,false,lNode)
              else
               begin
                 Message(parser_e_class_id_expected);
                 lNode.free;
                 lNode := nil;
                 StatementSysSym:=CErrorNode.Create;
               end;
            end;

          in_sizeof_x,
          in_bitsizeof_x :
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              Consume(_RKLAMMER);
              if ((lNode.nodetype<>typen) and
                 (
                  (Is_Object(lNode.resultdef) and
                   (oo_has_constructor in TObjectDef(lNode.resultdef).ObjectOptions)) or
                  Is_Open_Array(lNode.resultdef) or
                  Is_Array_Of_Const(lNode.resultdef) or
                  Is_Open_String(lNode.resultdef)
                 )) or
                 { keep the function call if it is a type parameter to avoid arithmetic errors due to constant folding }
                 Is_TypeParam(lNode.resultdef) then
                begin
                  StatementSysSym:=GenInlineNode(in_sizeof_x,false,lNode);
                  { no packed bit support for these things }
                  if AInlineNumber=in_bitsizeof_x then
                    StatementSysSym:=CAddNode.Create(muln,StatementSysSym,COrdConstNode.Create(8,SizeSIntType,true));
                  { type sym is a generic parameter }
                  if Assigned(lNode.resultdef.TypeSym) and (sp_generic_para in lNode.resultdef.TypeSym.SymOptions) then
                    include(StatementSysSym.flags,nf_generic_para);
                end
              else
               begin
                 { allow helpers for SizeOf and BitSizeOf }
                 if lNode.nodetype=typen then
                   TTypeNode(lNode).HelperAllowed:=true;
                 if (lNode.resultdef.typ=ForwardDef) then
                   Message1(type_e_type_is_not_completly_defined,TForwardDef(lNode.resultdef).ToSymName^);
                 if (AInlineNumber = in_sizeof_x) or
                    (not((lNode.nodetype = vecn) and
                         Is_Packed_Array(TVecNode(lNode).left.resultdef)) and
                     not((lNode.nodetype = subscriptn) and
                         Is_Packed_Record_Or_Object(TSubscriptNode(lNode).left.resultdef))) then
                   begin
                     StatementSysSym:=GenIntConstNode(lNode.resultdef.Size,SizeSIntType);
                     if (AInlineNumber = in_bitsizeof_x) then
                       StatementSysSym:=CAddNode.Create(muln,StatementSysSym,COrdConstNode.Create(8,SizeSIntType,true));
                   end
                 else
                   StatementSysSym:=GenIntConstNode(lNode.resultdef.PackedBitSize,SizeSIntType);
                 { type def is a struct with generic fields }
                 if df_has_generic_fields in lNode.resultdef.DefOptions then
                    include(StatementSysSym.flags,nf_generic_para);
                 { p1 not needed !}
                 lNode.free;
                 lNode := nil;
               end;
            end;

          in_typeinfo_x,
          in_objc_encode_x,
          in_gettypekind_x,
          in_ismanagedtype_x:
            begin
              if (AInlineNumber in [in_typeinfo_x,in_gettypekind_x,in_ismanagedtype_x]) or
                 (m_objectivec1 in CurrentSettings.ModeSwitches) then
                begin
                  Consume(_LKLAMMER);
                  InArgs:=true;
                  lNode:=CompExpr([efAcceptEqual]);
                  { When reading a class type it is parsed as loadvmtaddrn,
                    typeinfo only needs the type so we remove the loadvmtaddrn }
                  if lNode.nodetype=loadvmtaddrn then
                    begin
                      lSecondNode:=TLoadVMTAddrNode(lNode).left;
                      TLoadVMTAddrNode(lNode).left:=nil;
                      lNode.free;
                      lNode:=lSecondNode;
                    end;
                  if lNode.nodetype=typen then
                  begin
                    TTypeNode(lNode).allowed:=true;
                    { allow helpers for TypeInfo }
                    if AInlineNumber in [in_typeinfo_x,in_gettypekind_x,in_ismanagedtype_x] then
                      TTypeNode(lNode).HelperAllowed:=true;
                  end;
    {              else
                    begin
                       p1.free;
                       p1:=cerrornode.create;
                       Message(parser_e_illegal_parameter_list);
                    end;}
                  Consume(_RKLAMMER);
                  lSecondNode:=GenInlineNode(AInlineNumber,false,lNode);
                  StatementSysSym:=lSecondNode;
                end
              else
                begin
                  Message1(sym_e_id_not_found, CurrentScanner.FOrgPattern);
                  StatementSysSym:=CErrorNode.Create;
                end;
            end;

          in_isconstvalue_x:
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              Consume(_RKLAMMER);
              lSecondNode:=GenInlineNode(AInlineNumber,false,lNode);
              StatementSysSym:=lSecondNode;
            end;

          in_aligned_x,
          in_unaligned_x,
          in_volatile_x:
            begin
              lError:=false;
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              lSecondNode:=CCallParaNode.Create(lNode,nil);
              lSecondNode:=GenInlineNode(AInlineNumber,false,lSecondNode);
              Consume(_RKLAMMER);
              StatementSysSym:=lSecondNode;
            end;

          in_assigned_x :
            begin
              lError:=false;
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              { When reading a class type it is parsed as loadvmtaddrn,
                typeinfo only needs the type so we remove the loadvmtaddrn }
              if lNode.nodetype=loadvmtaddrn then
                begin
                  lSecondNode:=TLoadVMTAddrNode(lNode).left;
                  TLoadVMTAddrNode(lNode).left:=nil;
                  lNode.free;
                  lNode:=lSecondNode;
                end;
              if not CodeGenError then
               begin
                 case lNode.resultdef.typ of
                   procdef, { procvar }
                   pointerdef,
                   procvardef,
                   classrefdef : ;
                   objectdef :
                     if not Is_Implicit_Pointer_Object_Type(lNode.resultdef) then
                       begin
                         Message(parser_e_illegal_parameter_list);
                         lError:=true;
                       end;
                   arraydef :
                     if not Is_Dynamic_Array(lNode.resultdef) then
                       begin
                         Message(parser_e_illegal_parameter_list);
                         lError:=true;
                       end;
                   else
                     if lNode.resultdef.typ<>undefineddef then
                       begin
                         Message(parser_e_illegal_parameter_list);
                         lError:=true;
                       end;
                 end;
               end
              else
               lError:=true;
              if not lError then
               begin
                 lSecondNode:=CCallParaNode.Create(lNode,nil);
                 lSecondNode:=GenInlineNode(in_assigned_x,false,lSecondNode);
               end
              else
               begin
                 lNode.free;
                 lNode := nil;
                 lSecondNode:=CErrorNode.Create;
               end;
              Consume(_RKLAMMER);
              StatementSysSym:=lSecondNode;
            end;

          in_addr_x :
            begin
              Consume(_LKLAMMER);
              GotAddrN:=true;
              lNode:=Factor(true,[]);
              { inside parentheses a full expression is allowed, see also tests\tbs\tb27517.pas }
              if CurrentScanner.FToken<>_RKLAMMER then
                lNode:=SubExpr(opcompare,[efAcceptEqual],lNode);
              lNode:=CAddrNode.Create(lNode);
              GotAddrN:=false;
              Consume(_RKLAMMER);
              StatementSysSym:=lNode;
            end;



          in_ofs_x :
            begin
              Consume(_LKLAMMER);
              GotAddrN:=true;
              lNode:=Factor(true,[]);
              { inside parentheses a full expression is allowed, see also tests\tbs\tb27517.pas }
              if CurrentScanner.FToken<>_RKLAMMER then
                lNode:=SubExpr(opcompare,[efAcceptEqual],lNode);
              lNode:=CAddrNode.Create(lNode);
              include(TAddrNode(lNode).AddrNodeFlags,anf_ofs);
              GotAddrN:=false;
              { Ofs() returns a cardinal/qword, not a pointer }
              InsertTypeConv_Internal(lNode,UIntType);
              Consume(_RKLAMMER);
              StatementSysSym:=lNode;
            end;

          in_seg_x :
            begin
              Consume(_LKLAMMER);
              GotAddrN:=true;
              lNode:=Factor(true,[]);
              { inside parentheses a full expression is allowed, see also tests\tbs\tb27517.pas }
              if CurrentScanner.FToken<>_RKLAMMER then
                lNode:=SubExpr(opcompare,[efAcceptEqual],lNode);
              lNode:=GenInlineNode(in_seg_x,false,lNode);
              GotAddrN:=false;
              Consume(_RKLAMMER);
              StatementSysSym:=lNode;
            end;

          in_high_x,
          in_low_x :
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              lSecondNode:=GenInlineNode(AInlineNumber,false,lNode);
              Consume(_RKLAMMER);
              StatementSysSym:=lSecondNode;
            end;

          in_succ_x,
          in_pred_x :
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              lSecondNode:=GenInlineNode(AInlineNumber,false,lNode);
              Consume(_RKLAMMER);
              StatementSysSym:=lSecondNode;
            end;

          in_inc_x,
          in_dec_x :
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              if TryToConsume(_COMMA) then
                lSecondNode:=CCallParaNode.Create(CompExpr([efAcceptEqual]),nil)
              else
                lSecondNode:=nil;
              lSecondNode:=CCallParaNode.Create(lNode,lSecondNode);
              StatementSysSym:=GenInlineNode(AInlineNumber,false,lSecondNode);
              Consume(_RKLAMMER);
            end;

          in_slice_x:
            begin
              if not(InArgs) then
                begin
                  message(parser_e_illegal_slice);
                  Consume(_LKLAMMER);
                  InArgs:=true;
                  CompExpr([efAcceptEqual]).free; // no nil needed
                  if TryToConsume(_COMMA) then
                    CompExpr([efAcceptEqual]).free; // no nil needed
                  StatementSysSym:=CErrorNode.Create;
                  Consume(_RKLAMMER);
                end
              else
                begin
                  Consume(_LKLAMMER);
                  InArgs:=true;
                  lNode:=CompExpr([efAcceptEqual]);
                  Consume(_COMMA);
                  if not(CodeGenError) then
                    lSecondNode:=CCallParaNode.Create(CompExpr([efAcceptEqual]),nil)
                  else
                    lSecondNode:=CErrorNode.Create;
                  lSecondNode:=CCallParaNode.Create(lNode,lSecondNode);
                  StatementSysSym:=GenInlineNode(AInlineNumber,false,lSecondNode);
                  Consume(_RKLAMMER);
                end;
            end;

          in_initialize_x:
            begin
              StatementSysSym:=Inline_Initialize;
            end;

          in_finalize_x:
            begin
              StatementSysSym:=Inline_Finalize;
            end;

          in_copy_x:
            begin
              StatementSysSym:=Inline_Copy;
            end;

          in_concat_x :
            begin
              StatementSysSym:=Inline_Concat;
            end;

          in_read_x,
          in_readln_x,
          in_readstr_x:
            begin
              if TryToConsume(_LKLAMMER) then
               begin
                 lParas:=ParseParas(false,false,_RKLAMMER);
                 Consume(_RKLAMMER);
               end
              else
               lParas:=nil;
              lNode:=GenInlineNode(AInlineNumber,false,lParas);
              StatementSysSym := lNode;
            end;

          in_setlength_x:
            begin
              StatementSysSym := Inline_SetLength;
            end;

          in_objc_selector_x:
            begin
              if (m_objectivec1 in CurrentSettings.ModeSwitches) then
                begin
                  Consume(_LKLAMMER);
                  InArgs:=true;
                  { don't turn procsyms into calls (getaddr = true) }
                  lNode:=Factor(true,[]);
                  lSecondNode:=GenInlineNode(AInlineNumber,false,lNode);
                  Consume(_RKLAMMER);
                  StatementSysSym:=lSecondNode;
                end
              else
                begin
                  Message1(sym_e_id_not_found, CurrentScanner.FOrgPattern);
                  StatementSysSym:=CErrorNode.Create;
                end;
            end;

          in_length_x:
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              lSecondNode:=GenInlineNode(AInlineNumber,false,lNode);
              Consume(_RKLAMMER);
              StatementSysSym:=lSecondNode;
            end;

          in_write_x,
          in_writeln_x,
          in_writestr_x :
            begin
              if TryToConsume(_LKLAMMER) then
               begin
                 lParas:=ParseParas(true,false,_RKLAMMER);
                 Consume(_RKLAMMER);
               end
              else
               lParas:=nil;
              lNode := GenInlineNode(AInlineNumber,false,lParas);
              StatementSysSym := lNode;
            end;

          in_str_x_string :
            begin
              Consume(_LKLAMMER);
              lParas:=ParseParas(true,false,_RKLAMMER);
              Consume(_RKLAMMER);
              lNode := GenInlineNode(AInlineNumber,false,lParas);
              StatementSysSym := lNode;
            end;

          in_val_x:
            Begin
              Consume(_LKLAMMER);
              InArgs := true;
              lNode:= CCallParaNode.Create(CompExpr([efAcceptEqual]), nil);
              Consume(_COMMA);
              lSecondNode := CCallParaNode.Create(CompExpr([efAcceptEqual]),lNode);
              if TryToConsume(_COMMA) then
                lSecondNode := CCallParaNode.Create(CompExpr([efAcceptEqual]),lSecondNode);
              Consume(_RKLAMMER);
              lSecondNode := GenInlineNode(AInlineNumber,false,lSecondNode);
              StatementSysSym := lSecondNode;
            End;

          in_include_x_y,
          in_exclude_x_y :
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              Consume(_COMMA);
              lSecondNode:=CompExpr([efAcceptEqual]);
              StatementSysSym:=GenInlineNode(AInlineNumber,false,CCallParaNode.Create(lNode,CCallParaNode.Create(lSecondNode,nil)));
              Consume(_RKLAMMER);
            end;

          in_pack_x_y_z,
          in_unpack_x_y_z :
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              Consume(_COMMA);
              lSecondNode:=CompExpr([efAcceptEqual]);
              Consume(_COMMA);
              lParas:=CompExpr([efAcceptEqual]);
              StatementSysSym:=GenInlineNode(AInlineNumber,false,CCallParaNode.Create(lNode,CCallParaNode.Create(lSecondNode,CCallParaNode.Create(lParas,nil))));
              Consume(_RKLAMMER);
            end;

          in_assert_x_y :
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              if TryToConsume(_COMMA) then
                 lSecondNode:=CompExpr([efAcceptEqual])
              else
               begin
                 { then insert an empty string }
                 lSecondNode:=CStringConstNode.CreateStr('');
               end;
              StatementSysSym:=GenInlineNode(AInlineNumber,false,CCallParaNode.Create(lNode,CCallParaNode.Create(lSecondNode,nil)));
              Consume(_RKLAMMER);
            end;
          in_get_frame:
            begin
              StatementSysSym:=GenInlineNode(AInlineNumber,false,nil);
            end;
(*
          in_get_caller_frame:
            begin
              if try_to_consume(_LKLAMMER) then
                begin
                  {You used to call get_caller_frame as get_caller_frame(get_frame),
                   however, as a stack frame may not exist, it does more harm than
                   good, so ignore it.}
                  in_args:=true;
                  p1:=comp_expr([ef_accept_equal]);
                  p1.free;
                  p1 := nil;
                  consume(_RKLAMMER);
                end;
              statement_syssym:=geninlinenode(l,false,nil);
            end;
*)
          in_default_x:
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lDef:=nil;
              SingleType(lDef,[stoAllowSpecialization]);
              StatementSysSym:=CErrorNode.Create;
              if lDef<>GenErrorDef then
                { "type expected" error is already done by single_type }
                if lDef.typ=ForwardDef then
                  Message1(type_e_type_is_not_completly_defined,TForwardDef(lDef).ToSymName^)
                else
                  begin
                    StatementSysSym.free;
                    StatementSysSym:=GenInlineNode(in_default_x,false,CTypeNode.Create(lDef));
                  end;
              { consume the right bracket here for a nicer error position }
              Consume(_RKLAMMER);
            end;

          in_nameof_x:
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              { save the state: e.g. NameOf(TGen<byte>) may parse NameOf while specializing }
              lOldNameOfActive:=NameOfActive;
              lOldNameOfSym:=NameOfSym;
              lOldNameOfNextPos:=NameOfNextPos;
              NameOfActive:=true;
              NameOfSym:=nil;
              { only an identifier or a dotted identifier chain is allowed }
              lNameOfOK:=CurrentScanner.FToken=_ID;
              if CurrentScanner.FToken=_RKLAMMER then
                { NameOf() }
                lNode:=CNothingNode.Create
              else
                { getaddr: do not turn a procedure into a call }
                lNode:=Factor(true,[]);
              if CurrentScanner.FToken<>_RKLAMMER then
                begin
                  { e.g. inline specialization TBird<Boolean> }
                  lNode:=SubExpr(opcompare,[efAcceptEqual],lNode);
                  if lNode.nodetype in [addn,subn,muln,slashn,divn,modn,symdifn,starstarn,
                      EqualN,unequaln,ltn,lten,gtn,gten,inn,isn,asn,orn,andn,xorn,
                      shln,shrn,notn,assignn] then
                    lNameOfOK:=false;
                end;
              { the last found identifier must be directly followed by ")" }
              lNameOfOK:=lNameOfOK and
                Assigned(NameOfSym) and
                (NameOfSym.typ<>errorsym) and
                (NameOfNextPos.line=CurrentFilePos.line) and
                (NameOfNextPos.column=CurrentFilePos.column) and
                (NameOfNextPos.fileindex=CurrentFilePos.fileindex) and
                (NameOfNextPos.moduleindex=CurrentFilePos.moduleindex);
              if lNameOfOK then
                StatementSysSym:=CStringConstNode.CreateStr(NameOfSymName(NameOfSym))
              else
                begin
                  if lNode.nodetype<>errorn then
                    Message(parser_e_illegal_expression);
                  StatementSysSym:=CErrorNode.Create;
                end;
              lNode.free;
              NameOfActive:=lOldNameOfActive;
              NameOfSym:=lOldNameOfSym;
              NameOfNextPos:=lOldNameOfNextPos;
              Consume(_RKLAMMER);
            end;

          in_setstring_x_y_z:
            begin
              StatementSysSym := Inline_SetString;
            end;

          in_delete_x_y_z:
            begin
              StatementSysSym:=Inline_Delete;
            end;

          in_insert_x_y_z:
            begin
              StatementSysSym:=Inline_Insert;
            end;
          in_const_eh_return_data_regno:
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              lSecondNode:=GenInlineNode(AInlineNumber,true,lNode);
              Consume(_RKLAMMER);
              StatementSysSym:=lSecondNode;
            end;

          in_atomic_inc,
          in_atomic_dec:
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              if TryToConsume(_COMMA) then
                begin
                  lSecondNode:=CCallParaNode.Create(CompExpr([efAcceptEqual]),nil);
                end
              else
                lSecondNode:=nil;
              StatementSysSym:=GenInlineNode(AInlineNumber,false,CCallParaNode.Create(lNode,lSecondNode));
              Consume(_RKLAMMER);
            end;

          in_atomic_xchg:
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lNode:=CompExpr([efAcceptEqual]);
              Consume(_COMMA);
              lSecondNode:=CompExpr([efAcceptEqual]);
              StatementSysSym:=GenInlineNode(AInlineNumber,false,CCallParaNode.Create(lNode,CCallParaNode.Create(lSecondNode,nil)));
              Consume(_RKLAMMER);
            end;

          in_atomic_cmp_xchg:
            begin
              Consume(_LKLAMMER);
              InArgs:=true;
              lParas:=CCallParaNode.Create(CompExpr([efAcceptEqual]),nil);
              Consume(_COMMA);
              TCallParaNode(lParas).right:=CCallParaNode.Create(CompExpr([efAcceptEqual]),nil);
              Consume(_COMMA);
              TCallParaNode(TCallParaNode(lParas).right).right:=CCallParaNode.Create(CompExpr([efAcceptEqual]),nil);
              if TryToConsume(_COMMA) then
                begin
                  TCallParaNode(TCallParaNode(TCallParaNode(lParas).right).right).right:=CCallParaNode.Create(CompExpr([efAcceptEqual]),nil);
                end;
              StatementSysSym:=GenInlineNode(AInlineNumber,false,lParas);
              Consume(_RKLAMMER);
            end;

          else
            InternalError(15);

        end;
        InArgs:=lPrevInArgs;
      end;


    function MaybeLoadMethodPointer(ASymTable:TSymTable;var ANode:TNode):Boolean;
      var
        lProcDef: TProcDef;
      begin
        MaybeLoadMethodPointer:=false;
        if not Assigned(ANode) then
         begin
           case ASymTable.SymTableType of
             withsymtable :
               begin
                 if (ASymTable.DefOwner.typ=objectdef) then
                   ANode:=TNode(TWithSymTable(ASymTable).WithRefNode).GetCopy;
               end;
             ObjectSymtable,
             recordsymtable:
               begin
                 { Escape nested procedures }
                 if Assigned(CurrentProcInfo) then
                   begin
                     lProcDef:=CurrentProcInfo.Get_Normal_Proc.procdef;
                     { We are calling from the static class method which has no self node }
                     if Assigned(lProcDef) and lProcDef.No_Self_Node then
                       if ASymTable.SymTableType=recordsymtable then
                         ANode:=CTypeNode.Create(lProcDef.struct)
                       else
                         ANode:=CLoadVMTAddrNode.Create(CTypeNode.Create(lProcDef.struct))
                     else
                       ANode:=Load_Self_Node;
                   end
                 else
                   ANode:=Load_Self_Node;
                 { don't try to call the invokable again }
                 if Is_Invokable(TDef(ASymTable.DefOwner)) then
                   include(ANode.flags,nf_load_procvar);
                 { We are calling a member }
                 MaybeLoadMethodPointer:=true;
               end;
             else
               ;
           end;
         end;
      end;


    { reads the parameter for a subroutine call }
    procedure DoProcCall(ASym:TSym;ASymTable:TSymTable;AObjectDef:TAbstractRecordDef;AGetAddr:Boolean;var AAgain : Boolean;var ANode:TNode;ACallFlags:TCallNodeFlags;ASpecializationContext:TSpecializationContext);
      var
         lMemberCall,
         lPrevAfterAssignment : Boolean;
         lIndex        : Integer;
         lParaNode,lCallNode  : TNode;
         lCurrentPara : TParaVarSym;
         lProcDef : TProcDef;
      begin
         lPrevAfterAssignment:=AfterAssignment;
         AfterAssignment:=false;
         lMemberCall:=false;
         lProcDef:=nil;

         { when it is a call to a member we need to load the
           methodpointer first
         }
         lMemberCall:=MaybeLoadMethodPointer(ASymTable,ANode);

         { When we are expecting a procvar we also need
           to get the address in some cases }
         if Assigned(GetProcVarDef) or Assigned(GetFuncRefDef) then
          begin
            if (Block_Type=bt_const) or
               AGetAddr then
             begin
               if Assigned(GetFuncRefDef) then
                 lProcDef:=TProcSym(ASym).Find_ProcDef_ByFuncRefDef(GetFuncRefDef)
               else
                 lProcDef:=TProcSym(ASym).Find_ProcDef_ByProcVarDef(GetProcVarDef);
               AGetAddr:=true;
             end
            else
             if ((m_tp_procvar in CurrentSettings.ModeSwitches) or
                 (m_mac_procvar in CurrentSettings.ModeSwitches)) and
                not(CurrentScanner.FToken in [_CARET,_POINT,_LKLAMMER]) then
              begin
                if Assigned(GetFuncRefDef) then
                  lProcDef:=TProcSym(ASym).Find_ProcDef_ByFuncRefDef(GetFuncRefDef)
                else
                  lProcDef:=TProcSym(ASym).Find_ProcDef_ByProcVarDef(GetProcVarDef);
                if Assigned(lProcDef) then
                 AGetAddr:=true;
              end;
          end;

         { only need to get the address of the procedure? Check token because
           in the case of opening parenthesis is possible to get pointer to
           function result (lack of checking for token was the reason of
           tw10933.pas test failure) }
         if AGetAddr and (CurrentScanner.FToken<>_LKLAMMER) then
           begin
             { for now we don't support pointers to generic functions, but since
               this is only temporary we use a non translated message }
             if Assigned(ASpecializationContext) then
               begin
                 if NameOfActive then
                   { NameOf(GenericFunc<T>) only needs the name }
                   ANode:=CNothingNode.Create
                 else
                   begin
                     comment(VError, 'Pointers to generics functions not implemented');
                     ANode:=CErrorNode.Create;
                   end;
                 ASpecializationContext.free;
                 ASpecializationContext := nil;
                 exit;
               end;

             { Retrieve info which procvar to call. For tp_procvar the
               aprocdef is already loaded above so we can reuse it }
             if not Assigned(lProcDef) and
                Assigned(GetProcVarDef) then
               lProcDef:=TProcSym(ASym).Find_ProcDef_ByProcVarDef(GetProcVarDef);
             if not Assigned(lProcDef) and
                Assigned(GetFuncRefDef) then
               lProcDef:=TProcSym(ASym).Find_ProcDef_ByFuncRefDef(GetFuncRefDef);

             { ensure that the correct function is considered as captured }
             if Assigned(CurrentProcInfo) and
                 Assigned(lProcDef) and
                 (lProcDef.ParaST.SymTableLevel<=CurrentProcInfo.procdef.ParaST.SymTableLevel) and
                 (lProcDef.ParaST.SymTableLevel>NormalFunctionLevel) and
                 (CurrentProcInfo.procdef.ParaST.SymTableLevel>NormalFunctionLevel) then
               CurrentProcInfo.Add_Captured_Sym(ASym,lProcDef,CurrentFilePos);

             { generate a methodcallnode or proccallnode }
             { we shouldn't convert things like @tcollection.load }
             lCallNode:=CLoadNode.Create_ProcVar(ASym,lProcDef,ASymTable);
             if Assigned(ANode) then
              begin
                { for loading methodpointer of an inherited function
                  we use self as instance and load the address of
                  the function directly and not through the vmt (PFV) }
                if (cnf_inherited in ACallFlags) then
                  begin
                    include(TLoadNode(lCallNode).LoadNodeFlags,loadnf_inherited);
                    ANode.free;
                    ANode:=Load_Self_Node;
                  end;
                if (ANode.nodetype<>typen) then
                  TLoadNode(lCallNode).Set_MP(ANode)
                else
                  begin
                    TypeCheckPass(ANode);
                    if (ANode.resultdef.typ=classrefdef) and
                       (
                         Assigned(GetProcVarDef) or
                         Assigned(GetFuncRefDef)
                       ) then
                      begin
                        ANode:=CLoadVMTAddrNode.Create(ANode);
                        TLoadNode(lCallNode).Set_MP(ANode);
                      end
                    else if (ANode.resultdef.typ=objectdef) then
                      { so we can create the correct  method pointer again in case
                        this is a "objectprocvar:=@classname.method" expression }
                      TLoadNode(lCallNode).SymTable:=TObjectDef(ANode.resultdef).SymTable
                    else
                      ANode.free; // no nil needed
                  end;
              end;
             ANode:=lCallNode;

             { no postfix operators }
             AAgain:=false;
           end
         else
           begin
             lParaNode:=nil;
             if AnonInherited then
              begin
                if not Assigned(CurrentProcInfo) then
                  InternalError(200305054);
                for lIndex:=0 to CurrentProcInfo.procdef.paras.count-1 do
                  begin
                    lCurrentPara:=TParaVarSym(CurrentProcInfo.procdef.paras[lIndex]);
                    if not(vo_is_hidden_para in lCurrentPara.VarOptions) then
                      begin
                        { inheritance by msgint? }
                        if Assigned(SRDef) then
                          { anonymous inherited via msgid calls only require a var parameter for
                            both methods, so we need some type casting here }
                          lParaNode:=CCallParaNode.Create(CTypeConvNode.Create_Internal(CTypeConvNode.Create_Internal(
                            CLoadNode.Create(lCurrentPara,lCurrentPara.owner),CFormalType),TParaVarSym(TProcDef(SRDef).paras[lIndex]).vardef),
                          lParaNode)
                        else
                          lParaNode:=CCallParaNode.Create(CLoadNode.Create(lCurrentPara,lCurrentPara.owner),lParaNode);
                      end;
                 end;
              end
             else
              begin
                if TryToConsume(_LKLAMMER) then
                 begin
                   lParaNode:=ParseParas(false,false,_RKLAMMER);
                   Consume(_RKLAMMER);
                 end;
              end;
             { indicate if this call was generated by a member and
               no explicit self is used, this is needed to determine
               how to handle a destructor call (PFV) }
             if lMemberCall then
               include(ACallFlags,cnf_member_call);
             if Assigned(AObjectDef) then
               begin
                 if not (ASymTable.SymTableType in [ObjectSymtable,recordsymtable]) then
                   InternalError(200310031);
                 ANode:=CCallNode.Create(lParaNode,TProcSym(ASym),AObjectDef.SymTable,ANode,ACallFlags,ASpecializationContext);
               end
             else
               ANode:=CCallNode.Create(lParaNode,TProcSym(ASym),ASymTable,ANode,ACallFlags,ASpecializationContext);
             { in case of calling an anonymous function we already know the concrete
               procdef that is going to be called }
             if (TProcSym(ASym).ProcdefList.count=1) and (po_anonymous in TProcDef(TProcSym(ASym).procdeflist[0]).ProcOptions) then
               TCallNode(ANode).ProcDefinition:=TProcDef(TProcSym(ASym).procdeflist[0]);
           end;
         AfterAssignment:=lPrevAfterAssignment;
      end;


    procedure HandleProcVar(AProcVarDef : TProcVarDef;var ANode : TNode);
      var
        lNode,lLoadNode : TNode;
        lNodeSlot    : ^TNode;
        lCurrentProcDef : TProcDef;
      begin
        if not Assigned(AProcVarDef) then
         InternalError(200301121);
        if (m_tp_procvar in CurrentSettings.ModeSwitches) or
           (m_mac_procvar in CurrentSettings.ModeSwitches) then
         begin
           lNode:=ANode;
           lNodeSlot:=@ANode;
           while Assigned(lNode) and
                 (lNode.nodetype=typeconvn) do
            begin
              lNode:=TTypeConvNode(lNode).left;
              { save original address of the old tree so we can replace the node }
              lNodeSlot:=@lNode;
            end;
           if (lNode.nodetype=calln) and
              { a procvar can't have parameters! }
              not Assigned(TCallNode(lNode).left) then
            begin
              lCurrentProcDef:=TCallNode(lNode).SymTableProcEntry.Find_ProcDef_ByProcVarDef(AProcVarDef);
              if Assigned(lCurrentProcDef) then
               begin
                 lLoadNode:=CLoadNode.Create_ProcVar(TProcSym(TCallNode(lNode).SymTableProcEntry),lCurrentProcDef,TCallNode(lNode).SymTableProc);
                 if (po_methodpointer in AProcVarDef.ProcOptions) then
                   TLoadNode(lLoadNode).Set_MP(TCallNode(lNode).MethodPointer.GetCopy);
                 lNode.free;
                 lNode := nil;
                 { replace the old callnode with the new loadnode }
                 lNodeSlot^:=lLoadNode;
               end;
            end;
         end;
      end;


    procedure HandleFuncRef(AFuncRefDef:TObjectDef;var ANode:TNode);
      var
        lNode,lLoadNode : TNode;
        lNodeSlot    : ^TNode;
        lCurrentProcDef : TProcDef;
      begin
        if not Assigned(AFuncRefDef) then
          InternalError(2022032401);
        if not Is_Invokable(AFuncRefDef) then
          InternalError(2022032402);
        if (m_tp_procvar in CurrentSettings.ModeSwitches) or
           (m_mac_procvar in CurrentSettings.ModeSwitches) then
         begin
           lNode:=ANode;
           lNodeSlot:=@ANode;
           while Assigned(lNode) and
                 (lNode.nodetype=typeconvn) do
            begin
              lNode:=TTypeConvNode(lNode).left;
              { save original address of the old tree so we can replace the node }
              lNodeSlot:=@lNode;
            end;
           if (lNode.nodetype=calln) and
              { a procvar can't have parameters! }
              not Assigned(TCallNode(lNode).left) then
            begin
              lCurrentProcDef:=TCallNode(lNode).SymTableProcEntry.Find_ProcDef_ByFuncRefDef(AFuncRefDef);
              if Assigned(lCurrentProcDef) then
               begin
                 lLoadNode:=CLoadNode.Create_ProcVar(TProcSym(TCallNode(lNode).SymTableProcEntry),lCurrentProcDef,TCallNode(lNode).SymTableProc);
                 lNode.free;
                 lNode := nil;
                 { replace the old callnode with the new loadnode }
                 lNodeSlot^:=lLoadNode;
               end;
            end;
         end;
      end;


    { the following procedure handles the access to a property symbol }
    procedure HandlePropertySym(APropertySym : TPropertySym;ASymTable : TSymTable;var ANode : TNode);
      var
         lParas : TNode;
         lValueNode    : TNode;
         lMemberCall : Boolean;
         lCallFlags  : TCallNodeFlags;
         lPropAccessList : TPropAccessList;
         lSym: TSym;
      begin
         { NameOf(property) needs neither parameters nor read access }
         if NameOfActive and (CurrentScanner.FToken=_RKLAMMER) then
           begin
             ANode.free;
             ANode:=CNothingNode.Create;
             exit;
           end;
         { property parameters? read them only if the property really }
         { has parameters                                             }
         lParas:=nil;
         if (ppo_hasparameters in APropertySym.PropOptions) then
           begin
             if TryToConsume(_LECKKLAMMER) then
               begin
                 lParas:=ParseParas(false,false,_RECKKLAMMER);
                 Consume(_RECKKLAMMER);
               end;
           end;
         { indexed property }
         if (ppo_indexed in APropertySym.PropOptions) then
           begin
             lValueNode:=COrdConstNode.Create(APropertySym.Index,APropertySym.IndexDef,true);
             lParas:=CCallParaNode.Create(lValueNode,lParas);
           end;
         { we need only a write property if a := follows }
         { if not(afterassignment) and not(in_args) then }
         if CurrentScanner.FToken=_ASSIGNMENT then
           begin
              if APropertySym.GetPropAccessList(palt_write,lPropAccessList) then
                begin
                   lSym:=lPropAccessList.FirstSym^.sym;
                   case lSym.typ of
                     ProcSym :
                       begin
                         lCallFlags:=[];
                         { generate the method call }
                         lMemberCall:=MaybeLoadMethodPointer(ASymTable,ANode);
                         if lMemberCall then
                           include(lCallFlags,cnf_member_call);
                         ANode:=CCallNode.Create(lParas,TProcSym(lSym),ASymTable,ANode,lCallFlags,nil);
                         AddSymRef(lSym);
                         lParas:=nil;
                         Consume(_ASSIGNMENT);
                         { read the expression }
                         if APropertySym.PropDef.typ=procvardef then
                           GetProcVarDef:=TProcVarDef(APropertySym.PropDef)
                         else if Is_Invokable(APropertySym.PropDef) then
                           GetFuncRefDef:=TObjectDef(APropertySym.PropDef);
                         lValueNode:=CompExpr([efAcceptEqual]);
                         if Assigned(GetProcVarDef) then
                           HandleProcVar(GetProcVarDef,lValueNode)
                         else if Assigned(GetFuncRefDef) then
                           HandleFuncRef(GetFuncRefDef,lValueNode);
                         TCallNode(ANode).left:=CCallParaNode.Create(lValueNode,TCallNode(ANode).left);
                         { mark as property, both the tcallnode and the real call block }
                         include(ANode.flags,nf_isproperty);
                         GetProcVarDef:=nil;
                         GetFuncRefDef:=nil;
                       end;
                     FieldVarSym :
                       begin
                         { generate access code }
                         if not Handle_StaticField_Access(lSym,ANode) then
                           PropAccessList_To_Node(ANode,ASymTable,lPropAccessList);
                         include(ANode.flags,nf_isproperty);
                         Consume(_ASSIGNMENT);
                         { read the expression }
                         if APropertySym.PropDef.typ=procvardef then
                           GetProcVarDef:=TProcVarDef(APropertySym.PropDef)
                         else if Is_Invokable(APropertySym.PropDef) then
                           GetFuncRefDef:=TObjectDef(APropertySym.PropDef);
                         lValueNode:=CompExpr([efAcceptEqual]);
                         if Assigned(GetProcVarDef) then
                           HandleProcVar(GetProcVarDef,lValueNode)
                         else if Assigned(GetFuncRefDef) then
                           HandleFuncRef(GetFuncRefDef,lValueNode);
                         GetProcVarDef:=nil;
                         GetFuncRefDef:=nil;
                         ANode:=CAssignmentNode.Create(ANode,lValueNode);
                      end
                    else
                      begin
                        ANode:=CErrorNode.Create;
                        Message(parser_e_no_procedure_to_access_property);
                      end;
                  end;
                end
              else
                begin
                   ANode:=CErrorNode.Create;
                   Message(parser_e_no_procedure_to_access_property);
                end;
           end
         else
           begin
              if APropertySym.GetPropAccessList(palt_read,lPropAccessList) then
                begin
                   lSym := lPropAccessList.FirstSym^.sym;
                   case lSym.typ of
                     FieldVarSym :
                       begin
                         { generate access code }
                         if not Handle_StaticField_Access(lSym,ANode) then
                           PropAccessList_To_Node(ANode,ASymTable,lPropAccessList);
                         include(ANode.flags,nf_isproperty);
                         { catch expressions like "(propx):=1;" }
                         include(ANode.flags,nf_no_lvalue);
                       end;
                     ProcSym :
                       begin
                          lCallFlags:=[];
                          { generate the method call }
                          lMemberCall:=MaybeLoadMethodPointer(ASymTable,ANode);
                          if lMemberCall then
                            include(lCallFlags,cnf_member_call);
                          ANode:=CCallNode.Create(lParas,TProcSym(lSym),ASymTable,ANode,lCallFlags,nil);
                          lParas:=nil;
                          include(ANode.flags,nf_isproperty);
                          include(ANode.flags,nf_no_lvalue);
                       end
                     else
                       begin
                          ANode:=CErrorNode.Create;
                          Message(type_e_mismatch);
                       end;
                  end;
                end
              else
                begin
                   { error, no function to read property }
                   ANode:=CErrorNode.Create;
                   Message(parser_e_no_procedure_to_access_property);
                end;
           end;
        { release paras if not used }
        if Assigned(lParas) then
          lParas.free; // no nil needed
      end;


    { the ID token has to be consumed before calling this function }
    procedure DoMemberRead(AStruct:TAbstractRecordDef;AGetAddr:Boolean;ASym:TSym;var ANode:TNode;var AAgain:Boolean;ACallFlags:TCallNodeFlags;ASpecializationContext:TSpecializationContext);
      var
        lIsClassRef:Boolean;
        lIsRecordType:Boolean;
        lIsObjectType:Boolean;
        lIsHelperType:Boolean;
      begin
         if ASym=nil then
           begin
              { current_scanner.pattern is still valid unless
              there is another ID just after the ID of sym }
              Message1(sym_e_id_no_member,CurrentScanner.FOrgPattern);
              ANode.free;
              ANode:=CErrorNode.Create;
              { try to clean up }
              ASpecializationContext.free;
              ASpecializationContext := nil;
              AAgain:=false;
           end
         else
           begin
              NameOfRecordSym(ASym);
              if Assigned(ANode) then
               begin
                 if not Assigned(ANode.resultdef) then
                   DoTypeCheckPass(ANode);
                 lIsClassRef:=(ANode.resultdef.typ=classrefdef);
                 lIsRecordType:=(ANode.nodetype=typen) and (ANode.resultdef.typ=recorddef);
                 lIsObjectType:=(ANode.nodetype=typen) and Is_Object(ANode.resultdef);
                 lIsHelperType:=Is_ObjectPascal_Helper(TDef(ASym.owner.DefOwner)) and
                               (ANode.nodetype=typen) and
                               not Is_ObjectPascal_Helper(ANode.resultdef)
                                {and
                               not (cnf_inherited in callflags)};
               end
              else
                begin
                  lIsClassRef:=false;
                  lIsRecordType:=false;
                  lIsObjectType:=false;
                  lIsHelperType:=false;
                end;

              if Assigned(ASpecializationContext) and not (ASym.typ=ProcSym) then
                InternalError(2015091801);

              { we assume, that only procsyms and varsyms are in an object }
              { symbol table, for classes, properties are allowed          }
              case ASym.typ of
                 ProcSym:
                   begin
                      DoProcCall(ASym,ASym.owner,AStruct,
                                   (AGetAddr and not(CurrentScanner.FToken in [_CARET,_POINT])),
                                   AAgain,ANode,ACallFlags,ASpecializationContext);
                      { we need to know which procedure is called }
                      DoTypeCheckPass(ANode);

                      { We are loading... }
                      if ANode.nodetype=loadn then
                       begin
                         { an instance method }
                         if not (po_classmethod in TLoadNode(ANode).procdef.ProcOptions) and
                             { into a method pointer (not just taking a code address) }
                             not AGetAddr and
                             { and the selfarg is... }
                             (
                               { either a record/object/helper type, }
                               not Assigned(TLoadNode(ANode).left) or
                               { or a class/metaclass type, or a class reference }
                               (TLoadNode(ANode).left.resultdef.typ=classrefdef)
                             ) then
                           Message(parser_e_only_class_members_via_class_ref);
                       end
                      { calling using classref? }
                      else if (
                            lIsClassRef or
                            (
                              (lIsObjectType or
                               lIsRecordType or
                               lIsHelperType) and
                              not (cnf_inherited in ACallFlags)
                            )
                          ) and
                         (ANode.nodetype=calln) and
                         Assigned(TCallNode(ANode).ProcDefinition) then
                        begin
                          if not lIsObjectType then
                            begin
                              if not(po_classmethod in TCallNode(ANode).ProcDefinition.ProcOptions) and
                                 not(TCallNode(ANode).ProcDefinition.ProcTypeOption=potype_constructor) then
                                Message(parser_e_only_class_members_via_class_ref);
                            end
                          else
                            begin
                              { with objects, you can also do this:
                                  type
                                    tparent = object
                                      procedure test;
                                    end;

                                    tchild = object(tchild)
                                      procedure test;
                                    end;

                                    procedure tparent.test;
                                      begin
                                      end;

                                    procedure tchild.test;
                                      begin
                                        tparent.test;
                                      end;
                              }
                              if (TCallNode(ANode).ProcDefinition.ProcTypeOption<>potype_constructor) and
                                 not(po_staticmethod in TCallNode(ANode).ProcDefinition.ProcOptions) and
                                 (not Assigned(CurrentStructDef) or
                                  not Def_Is_Related(CurrentStructDef,AStruct)) then
                                begin
                                  ANode.free;
                                  ANode:=CErrorNode.Create;
                                  Message(parser_e_only_static_members_via_object_type);
                                  exit;
                                end;
                            end;

                          { Provide a warning if we try to create an instance of a
                            abstract class using the type name of that class. We
                            must not provide a warning if we use a "class of"
                            variable of that type though as we don't know the
                            type of the class
                            Note: structh might be Nil in case of a type helper }
                          if Assigned(AStruct) and
                              (TCallNode(ANode).ProcDefinition.ProcTypeOption=potype_constructor) and
                              (oo_is_abstract in AStruct.ObjectOptions) and
                              Assigned(TCallNode(ANode).MethodPointer) and
                              (TCallNode(ANode).MethodPointer.nodetype=loadvmtaddrn) then
                            Message1(type_w_instance_abstract_class,AStruct.RTTIName);
                        end
                   end;
                 FieldVarSym:
                   begin
                      if not Handle_StaticField_Access(ASym,ANode) then
                        begin
                          if lIsClassRef then
                            if Assigned(ANode) and
                              (
                                Is_Self_Node(ANode) or
                                (Assigned(CurrentProcInfo) and (CurrentProcInfo.Get_Normal_Proc.procdef.No_Self_Node) and
                                (CurrentProcInfo.procdef.struct=AStruct))) then
                              Message(parser_e_only_class_members)
                            else
                              Message(parser_e_only_class_members_via_class_ref);
                          ANode:=CSubscriptNode.Create(ASym,ANode);
                        end;
                   end;
                 propertysym:
                   begin
                      if lIsClassRef and not (sp_static in ASym.SymOptions) then
                        Message(parser_e_only_class_members_via_class_ref);
                      HandlePropertySym(TPropertySym(ASym),ASym.owner,ANode);
                   end;
                 TypeSym:
                   begin
                     ANode.free;
                     if TryToConsume(_LKLAMMER) then
                      begin
                        ANode:=CompExpr([efAcceptEqual]);
                        Consume(_RKLAMMER);
                        ANode:=CTypeConvNode.Create_Explicit(ANode,TTypeSym(ASym).TypeDef);
                      end
                     else
                       begin
                         ANode:=CTypeNode.Create(TTypeSym(ASym).TypeDef);
                         if (Is_Class(TTypeSym(ASym).TypeDef) or
                             Is_ObjCClass(TTypeSym(ASym).TypeDef)) and
                            not(Block_Type in [bt_type,bt_const_type,bt_var_type]) then
                           ANode:=CLoadVMTAddrNode.Create(ANode);
                       end;
                   end;
                 constsym:
                   begin
                     ANode.free;
                     ANode:=GenConstSymTree(TConstSym(ASym));
                   end;
                 staticvarsym:
                   begin
                     { typed constant is a staticvarsym
                       now they are absolutevarsym }
                     ANode.free;
                     ANode:=CLoadNode.Create(ASym,ASym.Owner);
                   end;
                 absolutevarsym:
                   begin
                     ANode.free;
                     ANode:=nil;
                     { typed constants are absolutebarsyms now to handle storage properly }
                     PropAccessList_To_Node(ANode,nil,TAbsoluteVarSym(ASym).Ref);
                   end
                 else
                   InternalError(16);
              end;
           end;
      end;


    function HandleSpecializeInlineSpecialization(var ASym:TSym;AEnforceUnit:Boolean;out ASymTable:TSymTable;out ASpecializationContext:TSpecializationContext):Boolean;
      var
        lSpecializeDef : TDef;
      begin
        Result:=false;
        ASpecializationContext:=nil;
        ASymTable:=nil;
        if not Assigned(ASym) then
          message1(sym_e_id_no_member,CurrentScanner.FOrgPattern)
        else
          if not (ASym.typ in [TypeSym,ProcSym]) then
            message(type_e_type_id_expected)
          else
            begin
              if ASym.typ=TypeSym then
                lSpecializeDef:=TTypeSym(ASym).TypeDef
              else if TProcSym(ASym).procdeflist.count>0 then
                lSpecializeDef:=TDef(TProcSym(ASym).procdeflist[0])
              else
                lSpecializeDef:=nil;
              lSpecializeDef:=GenerateSpecializationPhase1(ASpecializationContext,lSpecializeDef,AEnforceUnit,ASym.realname,ASym.owner);
              case lSpecializeDef.typ of
                errordef:
                  begin
                    ASpecializationContext.free;
                    ASpecializationContext:=nil;
                    ASym:=GenErrorSym;
                  end;
                procdef:
                  begin
                    if Block_Type<>bt_body then
                      begin
                        message(parser_e_illegal_expression);
                        ASpecializationContext.free;
                        ASpecializationContext:=nil;
                        ASym:=GenErrorSym;
                      end
                    else
                      begin
                        ASym:=TProcDef(lSpecializeDef).ProcSym;
                        ASymTable:=ASym.owner;
                        NameOfRecordSym(ASym);
                        Result:=true;
                      end;
                  end;
                objectdef,
                recorddef,
                arraydef,
                procvardef:
                  begin
                    lSpecializeDef:=GenerateSpecializationPhase2(ASpecializationContext,TStoredDef(lSpecializeDef),false,'');
                    ASpecializationContext.free;
                    ASpecializationContext:=nil;
                    if lSpecializeDef<>GenErrorDef then
                      begin
                        ASym:=lSpecializeDef.TypeSym;
                        ASymTable:=ASym.owner;
                        Check_Hints(ASym,ASym.SymOptions,ASym.DeprecatedMsg);
                        NameOfRecordSym(ASym);
                        Result:=true;
                      end;
                  end;
                else
                  InternalError(2015070302);
              end;
            end;
      end;


    function HandleFactorTypeNode(ADef:TDef;AGetAddr:Boolean;var AAgain:Boolean;ASym:TSym;ATypeOnly:Boolean):TNode;
      var
        lSearchSym : TSym;
        lSearchSymTable : TSymTable;
        lErrorOutResult,
        lIsSpecialize : Boolean;
        lSpecializationContext : TSpecializationContext;
        lSavedFilePos : TFilePosInfo;
      begin
         lSpecializationContext:=nil;
         if ASym=nil then
           ASym:=ADef.TypeSym;
         { allow Ordinal(Value) for type declarations since it
           can be an enumeration declaration or a set lke:
           (OrdinalType(const1)..OrdinalType(const2) }
         if (not ATypeOnly or Is_Ordinal(ADef)) and
            TryToConsume(_LKLAMMER) then
          begin
            Result:=CompExpr([efAcceptEqual]);
            Consume(_RKLAMMER);
            { type casts to class helpers aren't allowed }
            if Is_ObjectPascal_Helper(ADef) then
              Message(parser_e_no_category_as_types)
              { recovery by not creating a conversion node }
            else
              begin
                Result:=CTypeConvNode.Create_Explicit(Result,ADef);
                if Is_Currency(ADef) then
                  { Make sure currency types are correctly scaled }
                  Include(Result.flags,nf_is_currency);
              end;
          end
         { not LKLAMMER }
         else if (CurrentScanner.FToken=_POINT) and
            (Is_Object(ADef) or Is_Record(ADef)) then
           begin
             Consume(_POINT);
             { handles calling methods declared in parent objects
               using "parentobject.methodname()" }
             if Assigned(CurrentStructDef) and
                not(AGetAddr) and
                Def_Is_Related(CurrentStructDef,ADef) then
               begin
                 Result:=CTypeNode.Create(ADef);
                 TTypeNode(Result).TypeSym:=ASym;
                 if not (m_delphi in CurrentSettings.ModeSwitches) and
                     (Block_Type in cInlineSpecializationBlockTypes) and
                     (CurrentScanner.FToken=_ID) and
                     (CurrentScanner.FIDToken=_SPECIALIZE) then
                   begin
                     Consume(_ID);
                     if CurrentScanner.FToken<>_ID then
                       message(type_e_type_id_expected);
                     lIsSpecialize:=true;
                   end
                 else
                   lIsSpecialize:=false;
                 { search also in inherited methods }
                 SearchSym_In_Class(TObjectDef(ADef),TObjectDef(CurrentStructDef),CurrentScanner.FPattern,lSearchSym,lSearchSymTable,[ssf_search_helper]);
                 if lIsSpecialize then
                   begin
                     Consume(_ID);
                     if not HandleSpecializeInlineSpecialization(lSearchSym,false,lSearchSymTable,lSpecializationContext) then
                       begin
                         Result.free;
                         Result:=CErrorNode.Create;
                       end;
                   end
                 else
                   begin
                     if Assigned(lSearchSym) then
                       Check_Hints(lSearchSym,lSearchSym.SymOptions,lSearchSym.DeprecatedMsg);
                     Consume(_ID);
                   end;
                 if Result.nodetype<>errorn then
                   DoMemberRead(TAbstractRecordDef(ADef),false,lSearchSym,Result,AAgain,[],lSpecializationContext)
                 else begin
                   lSpecializationContext.free;
                   lSpecializationContext := nil;
                 end;
               end
             else
              begin
                { handles:
                    * @TObject.Load
                    * static methods and variables }
                Result:=CTypeNode.Create(ADef);
                TTypeNode(Result).TypeSym:=ASym;
                if not (m_delphi in CurrentSettings.ModeSwitches) and
                    (Block_Type in cInlineSpecializationBlockTypes) and
                    (CurrentScanner.FToken=_ID) and
                    (CurrentScanner.FIDToken=_SPECIALIZE) then
                  begin
                    Consume(_ID);
                    if CurrentScanner.FToken<>_ID then
                      message(type_e_type_id_expected);
                    lIsSpecialize:=true;
                  end
                else
                  lIsSpecialize:=false;
                lErrorOutResult:=true;
                { TP allows also @TMenu.Load if Load is only }
                { defined in an ancestor class               }
                lSearchSym:=Search_Struct_Member(TAbstractRecordDef(ADef),CurrentScanner.FPattern);
                if lIsSpecialize and Assigned(lSearchSym) then
                  begin
                    Consume(_ID);
                    if HandleSpecializeInlineSpecialization(lSearchSym,false,lSearchSymTable,lSpecializationContext) then
                      lErrorOutResult:=false;
                  end
                else
                  begin
                    if Assigned(lSearchSym) then
                      begin
                        lSavedFilePos:=CurrentFilePos;
                        Consume(_ID);
                        if not (sp_generic_dummy in lSearchSym.SymOptions) or
                            not (CurrentScanner.FToken in [_LT,_LSHARPBRACKET]) then
                          Check_Hints(lSearchSym,lSearchSym.SymOptions,lSearchSym.DeprecatedMsg,lSavedFilePos)
                        else
                          Result:=CSpecializeNode.Create(Result,AGetAddr,lSearchSym,false);
                        lErrorOutResult:=false;
                      end
                    else
                      Message1(sym_e_id_no_member,CurrentScanner.FOrgPattern);
                  end;
                if lErrorOutResult then
                  begin
                    Result.free;
                    Result:=CErrorNode.Create;
                  end
                else
                  if Result.nodetype<>specializen then
                    DoMemberRead(TAbstractRecordDef(ADef),AGetAddr,lSearchSym,Result,AAgain,[],lSpecializationContext);
              end;
           end
         else
          begin
            { Normally here would be the check against the usage
              of "TClassHelper.Something", but as that might be
              used inside of system symbols like sizeof and
              typeinfo this check is put into ttypenode.pass_1
              (for "TClassHelper" alone) and tcallnode.pass_1
              (for "TClassHelper.Something") }
            { class reference ? }
            if Is_Class(ADef) or
               Is_ObjCClass(ADef) then
             begin
               if AGetAddr and (CurrentScanner.FToken=_POINT) then
                begin
                  Consume(_POINT);
                  { allows @Object.Method }
                  { also allows static methods and variables }
                  Result:=CTypeNode.Create(ADef);
                  TTypeNode(Result).TypeSym:=ASym;
                  { TP allows also @TMenu.Load if Load is only }
                  { defined in an ancestor class               }
                  lSearchSym:=Search_Struct_Member(TObjectDef(ADef),CurrentScanner.FPattern);
                  if Assigned(lSearchSym) then
                   begin
                     Check_Hints(lSearchSym,lSearchSym.SymOptions,lSearchSym.DeprecatedMsg);
                     Consume(_ID);
                     { in case of @Object.Method1.Method2, we have to call
                       Method1 -> create a loadvmtaddr node as self instead of
                       a typen (the typenode would be changed to self of the
                       current method in case Method1 is a constructor, see
                       mantis #24844) }
                     if not(Block_Type in [bt_type,bt_const_type,bt_var_type]) and
                        (lSearchSym.typ=ProcSym) and
                        (CurrentScanner.FToken in [_CARET,_POINT]) then
                       Result:=CLoadVMTAddrNode.Create(Result);
                     DoMemberRead(TAbstractRecordDef(ADef),AGetAddr,lSearchSym,Result,AAgain,[],nil);
                   end
                  else
                   begin
                     Message1(sym_e_id_no_member,CurrentScanner.FOrgPattern);
                     Consume(_ID);
                   end;
                end
               else
                begin
                  Result:=CTypeNode.Create(ADef);
                  TTypeNode(Result).TypeSym:=ASym;
                  { For a type block we simply return only
                    the type. For all other blocks we return
                    a loadvmt node }
                  if not(Block_Type in [bt_type,bt_const_type,bt_var_type]) then
                    Result:=CLoadVMTAddrNode.Create(Result);
                end;
             end
            else
              begin
                Result:=CTypeNode.Create(ADef);
                TTypeNode(Result).TypeSym:=ASym;
              end;
          end;
      end;

{****************************************************************************
                               Factor
****************************************************************************}

{$push} {$R-}{$Q-} { Need to protect against integer overflows }
    function RealConstNodeFromPattern(const AText:String):TNode;
      var
        lRealValue : BestReal;
        lCode : Integer;
      begin
        Val(AText,lRealValue,lCode);
        if lCode<>0 then
         begin
           Message(parser_e_error_in_real);
           lRealValue:=1.0;
         end;
        if (CurrentSettings.MinFPConstPrec=S32Real) and
           (lRealValue = Single(lRealValue)) then
          Result:=CRealConstNode.Create(lRealValue,S32FloatType)
        else if (CurrentSettings.MinFPConstPrec=S64Real) and
                (lRealValue = Double(lRealValue)) then
          Result:=CRealConstNode.Create(lRealValue,S64FloatType)
        else
          Result:=CRealConstNode.Create(lRealValue,PBestRealType^);
        TRealConstNode(Result).SetCurrencyLiteral(AText);
      end;
{$pop}

{---------------------------------------------
               PostFixOperators
---------------------------------------------}

    { returns whether or not p1 has been changed }
    function PostfixOperators(var AOperand:TNode;var AAgain:Boolean;AGetAddr:Boolean): Boolean;

      { tries to avoid syntax errors after invalid qualifiers }
      procedure RecoverConsumePostfixOps;
       begin
         repeat
           if not TryToConsume(_CARET) then
             if TryToConsume(_POINT) then
               TryToConsume(_ID)
             else if TryToConsume(_LECKKLAMMER) then
               begin
                 repeat
                   CompExpr([efAcceptEqual]);
                 until not TryToConsume(_COMMA);
                 Consume(_RECKKLAMMER);
               end
             else if TryToConsume(_LKLAMMER) and not TryToConsume(_RKLAMMER) then
               begin
                 repeat
                   CompExpr([efAcceptEqual]);
                 until not TryToConsume(_COMMA);
                 Consume(_RKLAMMER);
               end
             else
               break;
         until false;
       end;


      procedure HandleVariantArray;
       var
         lIndexNode : TNode;
         lStatement : TStatementNode;
         lResultVariantTemp,
         lTemp    : TTempCreateNode;
         lParas : TCallParaNode;
         lBlock : TNode;
         lIndexCount : LongInt;
         lElements: TFPList;
         lArrayDef: TDef;
       begin
         { create statements with call initialize the arguments and
           call fpc_dynarr_setlength }
         lBlock:=InternalStatements(lStatement);

         { store all indices in a temporary array }
         lIndexCount:=0;
         lElements:=TFPList.Create;
         repeat
           lIndexNode:=CompExpr([efAcceptEqual]);
           lElements.add(lIndexNode);
         until not TryToConsume(_COMMA);

         lArrayDef:=CArrayDef.getreusable(S32IntType,lElements.count);
         lTemp:=CTempCreateNode.Create(lArrayDef,lArrayDef.Size,tt_persistent,false);
         AddStatement(lStatement,lTemp);
         for lIndexCount:=0 to lElements.count-1 do
           begin
             AddStatement(lStatement,
               CAssignmentNode.Create(
                 CVecNode.Create(
                   CTempRefNode.Create(lTemp),
                   GenIntConstNode(lIndexCount)
                 ),
                 TNode(lElements[lIndexCount])
               )
             );
           end;
         lIndexCount:=lElements.count;
         lElements.free;
         lElements := nil;

         Consume(_RECKKLAMMER);

         { we need only a write access if a := follows }
         if CurrentScanner.FToken=_ASSIGNMENT then
           begin
             Consume(_ASSIGNMENT);
             lIndexNode:=CompExpr([efAcceptEqual]);

             { create call to fpc_vararray_put }
             lParas:=CCallParaNode.Create(COrdConstNode.Create
                   (lIndexCount,S32IntType,true),
                CCallParaNode.Create(CAddrNode.Create_Internal
               (CVecNode.Create(CTempRefNode.Create(lTemp),GenIntConstNode(0))),
                CCallParaNode.Create(CTypeConvNode.Create_Internal(lIndexNode,CVariantType),
                CCallParaNode.Create(CTypeConvNode.Create_Internal(AOperand,CVariantType)
                  ,nil))));

             AddStatement(lStatement,CCallNode.CreateIntern('fpc_vararray_put',lParas));
             AddStatement(lStatement,CTempDeleteNode.Create(lTemp));
           end
         else
           begin
             { create temp for result }
             lResultVariantTemp:=CTempCreateNode.Create(CVariantType,CVariantType.Size,tt_persistent,true);
             AddStatement(lStatement,lResultVariantTemp);

             { create call to fpc_vararray_get }
             lParas:=CCallParaNode.Create(COrdConstNode.Create
                   (lIndexCount,S32IntType,true),
                CCallParaNode.Create(CAddrNode.Create_Internal
               (CTempRefNode.Create(lTemp)),
                CCallParaNode.Create(AOperand,
                CCallParaNode.Create(
                    CTempRefNode.Create(lResultVariantTemp)
                  ,nil))));

             AddStatement(lStatement,CCallNode.CreateIntern('fpc_vararray_get',lParas));
             AddStatement(lStatement,CTempDeleteNode.Create(lTemp));
             { the last statement should return the value as
               location and type, this is done be referencing the
               temp and converting it first from a persistent temp to
               normal temp }
             AddStatement(lStatement,CTempDeleteNode.Create_Normal_Temp(lResultVariantTemp));
             AddStatement(lStatement,CTempRefNode.Create(lResultVariantTemp));
           end;
         AOperand:=lBlock;
       end;

      function ParseArrayConstructor(AArrayDef:TArrayDef): TNode;
        var
          lStatement,lAssignmentStatement:TStatementNode;
          lArrayTemp:TTempCreateNode;
          lTempNode:TTempCreateNode;
          lAssignmentNode:TNode;
          lParaCount:Integer;
        begin
          Result:=InternalStatements(lStatement);
          { create temp for result }
          lArrayTemp:=CTempCreateNode.Create(AArrayDef,AArrayDef.Size,tt_persistent,true);
          AddStatement(lStatement,lArrayTemp);

          lParaCount:=0;
          { check arguments and create an assignment calls }
          if TryToConsume(_LKLAMMER) then
            begin
              lAssignmentNode:=InternalStatements(lAssignmentStatement);
              repeat
                { arr[i] := param_i }
                AddStatement(lAssignmentStatement,
                  CAssignmentNode.Create(
                    CVecNode.Create(
                      CTempRefNode.Create(lArrayTemp),
                      COrdConstNode.Create(lParaCount,AArrayDef.RangeDef,false)),
                    CompExpr([efAcceptEqual])));
                inc(lParaCount);
              until not TryToConsume(_COMMA);
              Consume(_RKLAMMER);
            end
          else
            lAssignmentNode:=nil;

          { get temp for array of lengths }
          lTempNode:=CTempCreateNode.Create(SIntType,SIntType.Size,tt_persistent,false);
          AddStatement(lStatement,lTempNode);

          { one dimensional }
          AddStatement(lStatement,CAssignmentNode.Create(
              CTempRefNode.Create(lTempNode),
              COrdConstNode.Create
                 (lParaCount,S32IntType,true)));
          { create call to fpc_dynarr_setlength }
          AddStatement(lStatement,CCallNode.CreateIntern('fpc_dynarray_setlength',
              CCallParaNode.Create(CAddrNode.Create_Internal
                    (CTempRefNode.Create(lTempNode)),
                 CCallParaNode.Create(COrdConstNode.Create
                    (1,S32IntType,true),
                 CCallParaNode.Create(CAddrNode.Create_Internal
                    (CRTTINode.Create(TStoredDef(AArrayDef),initrtti,rdt_normal)),
                 CCallParaNode.Create(
                   CTypeConvNode.Create_Internal(
                     CTempRefNode.Create(lArrayTemp),VoidPointerType),
                   nil))))

            ));
          { add assignment statements }
          AddStatement(lStatement,CTempDeleteNode.Create(lTempNode));
          if Assigned(lAssignmentNode) then
            AddStatement(lStatement,lAssignmentNode);
          { the last statement should return the value as
            location and type, this is done be referencing the
            temp and converting it first from a persistent temp to
            normal temp }
          AddStatement(lStatement,CTempDeleteNode.Create_Normal_Temp(lArrayTemp));
          AddStatement(lStatement,CTempRefNode.Create(lArrayTemp));
        end;

      function TryTypeHelper(var ANode:TNode;ADef:TDef):Boolean;
        var
          lSearchSym : TSym;
          lSearchSymTable : TSymTable;
          lNode : TNode;
          lStatement : TStatementNode;
          lTemp : TTempCreateNode;
          lExtendedDef : TDef;
        begin
          Result:=false;
          if (CurrentScanner.FToken=_ID) and (Block_Type in [bt_body,bt_general,bt_except,bt_const]) then
            begin
              if not Assigned(ADef) then
                if ANode.nodetype=addrn then
                  { always use the pointer type for addr nodes as otherwise
                    we'll have an anonymous pointertype with no name }
                  ADef:=VoidPointerType
                else
                  ADef:=ANode.resultdef;
              Result:=Search_ObjectPascal_Helper(ADef,nil,CurrentScanner.FPattern,lSearchSym,lSearchSymTable);
              if Result then
                begin
                  if not (lSearchSymTable.SymTableType=objectsymtable) or
                      not Is_ObjectPascal_Helper(TDef(lSearchSymTable.DefOwner)) then
                    InternalError(2013011401);
                  { convert const node to temp node of the extended type }
                  if ANode.nodetype in (cNodeTypeConst+[addrn]) then
                    begin
                      lExtendedDef:=TObjectDef(lSearchSymTable.DefOwner).ExtendedDef;
                      lStatement:=nil;
                      lNode:=InternalStatements(lStatement);
                      lTemp:=CTempCreateNode.Create(lExtendedDef,lExtendedDef.Size,tt_persistent,false);
                      AddStatement(lStatement,lTemp);
                      AddStatement(lStatement,CAssignmentNode.Create(CTempRefNode.Create(lTemp),ANode));
                      AddStatement(lStatement,CTempDeleteNode.Create_Normal_Temp(lTemp));
                      AddStatement(lStatement,CTempRefNode.Create(lTemp));
                      ANode:=lNode;
                      DoTypeCheckPass(ANode)
                    end;
                  Check_Hints(lSearchSym,lSearchSym.SymOptions,lSearchSym.DeprecatedMsg);
                  Consume(_ID);
                  DoMemberRead(nil,AGetAddr,lSearchSym,ANode,AAgain,[],nil);
                end;
            end;
        end;

    var
     lPropertySym  : TPropertySym;
     lSecondNode,lThirdNode  : TNode;
     lSearchSym  : TSym;
     lSearchSymTable : TSymTable;
     lStruct    : TAbstractRecordDef;
     { shouldn't be used that often, so the extra overhead is ok to save
       stack space }
     lDispatchString : AnsiString;
     lAutoDeref,
     lErrorOutOperand,
     lAllowSpecialize,
     lIsSpecialize,
     lFound,
     lHadError,
     lNodeChanged    : Boolean;
     lCallType: TDispCallType;
     lValueString,lExponentString : String;
     lIntValue : QWord;
     lCode : Integer;
     lStringDef : TDef;
     lSpecializationContext : TSpecializationContext;
     lOldCurrentFilePos : TFilePosInfo;
    label
     SkipRecKlammerCheck,
     SkipPointDefCheck;
    begin
     Result:=false;
     AAgain:=true;
     while AAgain do
      begin
        lSpecializationContext:=nil;
        { we need the resultdef }
        DoTypeCheckPassChanged(AOperand,lNodeChanged);
        Result:=Result or lNodeChanged;

        if CodeGenError then
         begin
           RecoverConsumePostfixOps;
           exit;
         end;
        { handle token }
        case CurrentScanner.FToken of
          _CARET:
             begin
               Consume(_CARET);

               { support in tp/mac procvar mode procvar^ if the procvar returns a
                 pointer type }
               if ((m_tp_procvar in CurrentSettings.ModeSwitches) or
                   (m_mac_procvar in CurrentSettings.ModeSwitches)) and
                  (AOperand.resultdef.typ=procvardef) and
                  (TProcVarDef(AOperand.resultdef).ReturnDef.typ=pointerdef) then
                 begin
                   AOperand:=CCallNode.Create_ProcVar(nil,AOperand);
                   TypeCheckPass(AOperand);
                 end;

               { iso file buf access? }
               if (m_isolike_io in CurrentSettings.ModeSwitches) and
                 (AOperand.resultdef.typ=filedef) then
                 begin
                   case TFileDef(AOperand.resultdef).FileTyp of
                     ft_text:
                       begin
                         AOperand:=CDerefNode.Create(CCallNode.CreateIntern('fpc_getbuf_text',CCallParaNode.Create(AOperand,nil)));
                         TypeCheckPass(AOperand);
                       end;
                     ft_typed:
                       begin
                         AOperand:=CDerefNode.Create(CTypeConvNode.Create_Internal(CCallNode.CreateIntern('fpc_getbuf_typedfile',CCallParaNode.Create(AOperand,nil)),
                           CPointerDef.getreusable(TFileDef(AOperand.resultdef).TypedFileDef)));
                         TypeCheckPass(AOperand);
                       end;
                     else
                       InternalError(2019050530);
                   end;
                 end
               else if not(AOperand.resultdef.typ in [pointerdef,undefineddef]) then
                 begin
                    { ^ as binary operator is a problem!!!! (FK) }
                    AAgain:=false;
                    Message(parser_e_invalid_qualifier);
                    RecoverConsumePostfixOps;
                    AOperand.free;
                    AOperand:=CErrorNode.Create;
                 end
               else
                 AOperand:=CDerefNode.Create(AOperand);
             end;

          _LECKKLAMMER:
             begin
               { support in tp/mac procvar mode procvar[] if the procvar returns an
                 array type }
               if ((m_tp_procvar in CurrentSettings.ModeSwitches) or
                   (m_mac_procvar in CurrentSettings.ModeSwitches)) and
                  (AOperand.resultdef.typ=procvardef) and
                  (TProcVarDef(AOperand.resultdef).ReturnDef.typ=arraydef) then
                 begin
                   AOperand:=CCallNode.Create_ProcVar(nil,AOperand);
                   TypeCheckPass(AOperand);
                 end;

               if Is_Class_Or_Interface_Or_Object(AOperand.resultdef) or
                  Is_DispInterface(AOperand.resultdef) or
                  Is_Record(AOperand.resultdef) then
                 begin
                   { default property }
                   lPropertySym:=Search_Default_Property(TAbstractRecordDef(AOperand.resultdef));
                   if not(Assigned(lPropertySym)) then
                     begin
                        AOperand.free;
                        AOperand:=CErrorNode.Create;
                        AAgain:=false;
                        message(parser_e_no_default_property_available);
                     end
                   else
                     begin
                       { The property symbol is referenced indirect }
                       lPropertySym.IncRefCount;
                       HandlePropertySym(lPropertySym,lPropertySym.owner,AOperand);
                     end;
                 end
               else
                 begin
                   Consume(_LECKKLAMMER);
                   repeat
                     { in all of the cases below, p1 is changed }
                     case AOperand.resultdef.typ of
                       pointerdef:
                         begin
                            { support delphi autoderef }
                            if (TPointerDef(AOperand.resultdef).PointedDef.typ=arraydef) and
                               (m_autoderef in CurrentSettings.ModeSwitches) then
                              AOperand:=CDerefNode.Create(AOperand);
                            lSecondNode:=CompExpr([efAcceptEqual]);
                            { Support Pbytevar[0..9] which returns array [0..9].}
                            if TryToConsume(_POINTPOINT) then
                              lSecondNode:=CRangeNode.Create(lSecondNode,CompExpr([efAcceptEqual]));
                            AOperand:=CVecNode.Create(AOperand,lSecondNode);
                         end;
                       variantdef:
                         begin
                           HandleVariantArray;
                           { the RECKKLAMMER is already read }
                           goto SkipRecKlammerCheck;
                         end;
                       stringdef :
                         begin
                           lSecondNode:=CompExpr([efAcceptEqual]);
                           { Support string[0..9] which returns array [0..9] of char.}
                           if TryToConsume(_POINTPOINT) then
                             lSecondNode:=CRangeNode.Create(lSecondNode,CompExpr([efAcceptEqual]));
                           AOperand:=CVecNode.Create(AOperand,lSecondNode);
                         end;
                       arraydef:
                         begin
                           lSecondNode:=CompExpr([efAcceptEqual]);
                           if TryToConsume(_POINTPOINT) then
                             { Support arrayvar[0..9] which returns array [0..9] of arraytype.}
                             lSecondNode:=CRangeNode.Create(lSecondNode,CompExpr([efAcceptEqual]));
                           AOperand:=CVecNode.Create(AOperand,lSecondNode);
                         end;
                       else
                         begin
                           if AOperand.resultdef.typ<>undefineddef then
                             Message(parser_e_invalid_qualifier);
                           AOperand.free;
                           AOperand:=CErrorNode.Create;
                           CompExpr([efAcceptEqual]);
                           AAgain:=false;
                         end;
                     end;
                     DoTypeCheckPass(AOperand);
                   until not TryToConsume(_COMMA);
                   Consume(_RECKKLAMMER);
                   { handle_variantarray eats the RECKKLAMMER and jumps here }
                 SkipRecKlammerCheck:
                 end;
             end;

          _POINT :
             begin
               Consume(_POINT);
               lAllowSpecialize:=not (m_delphi in CurrentSettings.ModeSwitches) and (Block_Type in cInlineSpecializationBlockTypes);
               if lAllowSpecialize and (CurrentScanner.FToken=_ID) and (CurrentScanner.FIDToken=_SPECIALIZE) then
                 begin
                   //consume(_ID);
                   lIsSpecialize:=true;
                 end
               else
                 lIsSpecialize:=false;
               lAutoDeref:=false;
               if (AOperand.resultdef.typ=pointerdef) and
                  (m_autoderef in CurrentSettings.ModeSwitches) and
                  { don't auto-deref objc.id, because then the code
                    below for supporting id.anyobjcmethod isn't triggered }
                  (AOperand.resultdef<>ObjC_IDType) then
                 begin
                   AOperand:=CDerefNode.Create(AOperand);
                   DoTypeCheckPass(AOperand);
                   lAutoDeref:=true;
                 end;
               { procvar.<something> can never mean anything so always
                 try to call it in case it returns a record/object/... }
               Maybe_Call_ProcVar(AOperand,Is_Invokable(AOperand.resultdef) and not Is_FuncRef(AOperand.resultdef));

               if (AOperand.nodetype=ordconstn) and
                   not Is_Boolean(AOperand.resultdef) and
                   not Is_Enum(AOperand.resultdef) then
                 begin
                   { type helpers are checked first }
                   if (CurrentScanner.FToken=_ID) and TryTypeHelper(AOperand,nil) then
                     goto SkipPointDefCheck;
                   { only an "e" or "E" can follow an intconst with a ".", the
                     other case (another intconst) is handled by the scanner }
                   if (CurrentScanner.FToken=_ID) and (CurrentScanner.FPattern[1]='E') then
                     begin
                       lHadError:=false;
                       if length(CurrentScanner.FPattern)>1 then
                         begin
                           lExponentString:=copy(CurrentScanner.FPattern,2,length(CurrentScanner.FPattern)-1);
                           val(lExponentString,lIntValue,lCode);
                           if lCode<>0 then
                             begin
                               lHadError:=true;
                               lIntValue:=lIntValue; // Hackfix the "var assigned but never used" note.
                             end;
                         end
                       else
                         lExponentString:='';
                       Consume(CurrentScanner.FToken);
                       if TOrdConstNode(AOperand).Value.signed then
                         str(TOrdConstNode(AOperand).Value.svalue,lValueString)
                       else
                         str(TOrdConstNode(AOperand).Value.uvalue,lValueString);
                       lValueString:=lValueString+'.0E';
                       if lExponentString='' then
                         case CurrentScanner.FToken of
                           _MINUS:
                             begin
                               Consume(CurrentScanner.FToken);
                               if CurrentScanner.FToken=_INTCONST then
                                 begin
                                   lValueString:=lValueString+'-'+CurrentScanner.FPattern;
                                   Consume(CurrentScanner.FToken);
                                 end
                               else
                                 lHadError:=true;
                             end;
                           _PLUS:
                             begin
                               Consume(CurrentScanner.FToken);
                               if CurrentScanner.FToken=_INTCONST then
                                 begin
                                   lValueString:=lValueString+CurrentScanner.FPattern;
                                   Consume(CurrentScanner.FToken);
                                 end
                               else
                                 lHadError:=true;
                             end;
                           _INTCONST:
                             begin
                               lValueString:=lValueString+CurrentScanner.FPattern;
                               Consume(_INTCONST);
                             end;
                           else
                             lHadError:=true;
                         end
                       else
                         lValueString:=lValueString+lExponentString;
                       if lHadError then
                         begin
                           Message(parser_e_error_in_real);
                           lSecondNode:=CErrorNode.Create;
                         end
                       else
                         lSecondNode:=RealConstNodeFromPattern(lValueString);
                       AOperand.free;
                       AOperand:=lSecondNode;
                       AAgain:=false;
                       goto SkipPointDefCheck;
                     end
                   else
                     begin
                       { just convert the ordconst to a realconst }
                       lSecondNode:=CRealConstNode.Create(TOrdConstNode(AOperand).Value,PBestRealType^);
                       AOperand.free;
                       AOperand:=lSecondNode;
                       AAgain:=false;
                       goto SkipPointDefCheck;
                     end;
                 end;

               if (AOperand.nodetype=stringconstn) and (CurrentScanner.FToken=_ID) then
                 begin
                   lStringDef:=nil;
                   { the def of a string const is an array }
                   case TStringConstNode(AOperand).ConstStringType of
                     cst_conststring:
                       if cs_refcountedstrings in CurrentSettings.LocalSwitches then
                         if m_default_unicodestring in CurrentSettings.ModeSwitches then
                           lStringDef:=CUnicodeStringType
                         else
                           lStringDef:=CAnsiStringType
                       else
                         lStringDef:=CShortStringType;
                     cst_shortstring:
                       lStringDef:=CShortStringType;
                     cst_ansistring:
                       { use getansistringdef? }
                       lStringDef:=CAnsiStringType;
                     cst_widestring:
                       lStringDef:=CWideStringType;
                     cst_unicodestring:
                       lStringDef:=CUnicodeStringType;
                     cst_longstring:
                       { let's see when someone stumbles upon this...}
                       InternalError(201301111);
                   end;
                   if TryTypeHelper(AOperand,lStringDef) then
                     goto SkipPointDefCheck;
                 end;

               { this is skipped if label skippointdefcheck is used }
               case AOperand.resultdef.typ of
                 recorddef:
                   begin
                     if lIsSpecialize or (CurrentScanner.FToken=_ID) then
                       begin
                         lErrorOutOperand:=true;
                         lSearchSym:=nil;
                         lStruct:=TAbstractRecordDef(AOperand.resultdef);
                         if lIsSpecialize then
                           begin
                             { consume the specialize }
                             Consume(_ID);
                             if CurrentScanner.FToken<>_ID then
                               Consume(_ID)
                             else
                               begin
                                 SearchSym_In_Record(lStruct,CurrentScanner.FPattern,lSearchSym,lSearchSymTable);
                                 Consume(_ID);
                                 if HandleSpecializeInlineSpecialization(lSearchSym,false,lSearchSymTable,lSpecializationContext) then
                                   lErrorOutOperand:=false;
                               end;
                           end
                         else
                           begin
                             SearchSym_In_Record(lStruct,CurrentScanner.FPattern,lSearchSym,lSearchSymTable);
                             if Assigned(lSearchSym) then
                               begin
                                 lOldCurrentFilePos:=CurrentFilePos;
                                 Consume(_ID);
                                 if not (sp_generic_dummy in lSearchSym.SymOptions) or
                                     not (CurrentScanner.FToken in [_LT,_LSHARPBRACKET]) then
                                   Check_Hints(lSearchSym,lSearchSym.SymOptions,lSearchSym.DeprecatedMsg,lOldCurrentFilePos)
                                 else
                                   AOperand:=CSpecializeNode.Create(AOperand,AGetAddr,lSearchSym,false);
                                 lErrorOutOperand:=false;
                               end
                             else
                               begin
                                 Message1(sym_e_id_no_member,CurrentScanner.FOrgPattern);
                                 { try to clean up }
                                 Consume(_ID);
                               end;
                           end;
                         if lErrorOutOperand then
                           begin
                             AOperand.free;
                             AOperand:=CErrorNode.Create;
                           end
                         else
                           if AOperand.nodetype<>specializen then
                             DoMemberRead(lStruct,AGetAddr,lSearchSym,AOperand,AAgain,[],lSpecializationContext);
                       end
                     else
                     Consume(_ID);
                   end;
                 enumdef:
                   begin
                     if CurrentScanner.FToken=_ID then
                       begin
                         lSearchSym:=TSym(TEnumDef(AOperand.resultdef).SymTable.Find(CurrentScanner.FPattern));
                         if Assigned(lSearchSym) and (lSearchSym.typ=enumsym) and (AOperand.nodetype=typen) then
                           begin
                             AOperand.free;
                             Check_Hints(lSearchSym,lSearchSym.SymOptions,lSearchSym.DeprecatedMsg);
                             AOperand:=GenEnumNode(TEnumSym(lSearchSym));
                             Consume(_ID);
                             NameOfRecordSym(lSearchSym);
                           end
                         else
                           if not TryTypeHelper(AOperand,nil) then
                             begin
                               AOperand.free;
                               Message1(sym_e_id_no_member,CurrentScanner.FOrgPattern);
                               AOperand:=CErrorNode.Create;
                               Consume(_ID);
                             end;
                       end
                     else
                       begin
                         AOperand.free;
                         AOperand:=CErrorNode.Create;
                         Consume(_ID);
                       end
                   end;
                 arraydef:
                   begin
                     if Is_Dynamic_Array(AOperand.resultdef) then
                       begin
                         if CurrentScanner.FToken=_ID then
                           begin
                             if not TryTypeHelper(AOperand,nil) then
                               begin
                                 if AOperand.nodetype=typen then
                                   begin
                                     if CurrentScanner.FPattern='CREATE' then
                                       begin
                                         Consume(_ID);
                                         lSecondNode:=ParseArrayConstructor(TArrayDef(AOperand.resultdef));
                                         AOperand.free;
                                         AOperand:=lSecondNode;
                                       end
                                     else
                                       begin
                                         Message2(scan_f_syn_expected,'CREATE',CurrentScanner.FPattern);
                                         AOperand.free;
                                         AOperand:=CErrorNode.Create;
                                         Consume(_ID);
                                       end;
                                   end
                                 else
                                   begin
                                     Message(parser_e_invalid_qualifier);
                                     AOperand.free;
                                     AOperand:=CErrorNode.Create;
                                     Consume(_ID);
                                   end;
                               end;
                           end
                         else
                           begin
                             Message(parser_e_invalid_qualifier);
                             AOperand.free;
                             AOperand:=CErrorNode.Create;
                             Consume(_ID);
                           end;
                       end
                     else
                       if (CurrentScanner.FToken<>_ID) or not TryTypeHelper(AOperand,nil) then
                         begin
                           Message(parser_e_invalid_qualifier);
                           AOperand.free;
                           AOperand:=CErrorNode.Create;
                           Consume(_ID);
                         end;
                   end;
                  variantdef:
                    begin
                      { dispatch call? }
                      { lhs := v.ident[parameters] -> property get
                        lhs := v.ident(parameters) -> method call
                        v.ident[parameters] := rhs -> property put
                        v.ident(parameters) := rhs -> also property put }
                      if CurrentScanner.FToken=_ID then
                        begin
                          if not TryTypeHelper(AOperand,nil) then
                            begin
                              lDispatchString:=CurrentScanner.FOrgPattern;
                              Consume(_ID);
                              lCallType:=dct_method;
                              if TryToConsume(_LKLAMMER) then
                                begin
                                  lSecondNode:=ParseParas(false,true,_RKLAMMER);
                                  Consume(_RKLAMMER);
                                end
                              else if TryToConsume(_LECKKLAMMER) then
                                begin
                                  lSecondNode:=ParseParas(false,true,_RECKKLAMMER);
                                  Consume(_RECKKLAMMER);
                                  lCallType:=dct_propget;
                                end
                              else
                                lSecondNode:=nil;
                              { property setter? }
                              if (CurrentScanner.FToken=_ASSIGNMENT) and not(AfterAssignment) then
                                begin
                                  Consume(_ASSIGNMENT);
                                  { read the expression }
                                  lThirdNode:=CompExpr([efAcceptEqual]);
                                  { concat value parameter too }
                                  lSecondNode:=CCallParaNode.Create(lThirdNode,lSecondNode);
                                  AOperand:=Translate_Disp_Call(AOperand,lSecondNode,dct_propput,lDispatchString,0,VoidType);
                                end
                              else
                              { this is only an approximation
                                setting useresult if not necessary is only a waste of time, no more, no less (FK) }
                              if AfterAssignment or InArgs or (CurrentScanner.FToken<>_SEMICOLON) then
                                AOperand:=Translate_Disp_Call(AOperand,lSecondNode,lCallType,lDispatchString,0,CVariantType)
                              else
                                AOperand:=Translate_Disp_Call(AOperand,lSecondNode,lCallType,lDispatchString,0,VoidType);
                            end;
                        end
                      else { Error }
                        Consume(_ID);
                     end;
                  classrefdef:
                    begin
                      lErrorOutOperand:=true;
                      if CurrentScanner.FToken=_ID then
                        begin
                          lSearchSym:=nil;
                          lStruct:=TObjectDef(TClassRefDef(AOperand.resultdef).PointedDef);
                          if lIsSpecialize then
                            begin
                              { consume the specialize }
                              Consume(_ID);
                              if CurrentScanner.FToken<>_ID then
                                Consume(_ID)
                              else
                                begin
                                  SearchSym_In_Class(TObjectDef(lStruct),TObjectDef(lStruct),CurrentScanner.FPattern,lSearchSym,lSearchSymTable,[ssf_search_helper]);
                                  Consume(_ID);
                                  if HandleSpecializeInlineSpecialization(lSearchSym,false,lSearchSymTable,lSpecializationContext) then
                                    lErrorOutOperand:=false;
                                end;
                            end
                          else
                            begin
                              SearchSym_In_Class(TObjectDef(lStruct),TObjectDef(lStruct),CurrentScanner.FPattern,lSearchSym,lSearchSymTable,[ssf_search_helper]);
                              if Assigned(lSearchSym) then
                                begin
                                  lOldCurrentFilePos:=CurrentFilePos;
                                  Consume(_ID);
                                  if not (sp_generic_dummy in lSearchSym.SymOptions) or
                                      not (CurrentScanner.FToken in [_LT,_LSHARPBRACKET]) then
                                    Check_Hints(lSearchSym,lSearchSym.SymOptions,lSearchSym.DeprecatedMsg,lOldCurrentFilePos)
                                  else
                                    AOperand:=CSpecializeNode.Create(AOperand,AGetAddr,lSearchSym,false);
                                  lErrorOutOperand:=false;
                                end
                              else
                                begin
                                  Message1(sym_e_id_no_member,CurrentScanner.FOrgPattern);
                                  { try to clean up }
                                  Consume(_ID);
                                end;
                            end;
                          if lErrorOutOperand then
                            begin
                              AOperand.free;
                              AOperand:=CErrorNode.Create;
                            end
                          else
                            if AOperand.nodetype<>specializen then
                              DoMemberRead(lStruct,AGetAddr,lSearchSym,AOperand,AAgain,[],lSpecializationContext);
                        end
                      else { Error }
                        Consume(_ID);
                    end;
                  objectdef:
                    begin
                      if lIsSpecialize or (CurrentScanner.FToken=_ID) then
                        begin
                          lErrorOutOperand:=true;
                          lSearchSym:=nil;
                          lStruct:=TObjectDef(AOperand.resultdef);
                          if lIsSpecialize then
                            begin
                              { consume the "specialize" }
                              Consume(_ID);
                              if CurrentScanner.FToken<>_ID then
                                Consume(_ID)
                              else
                                begin
                                  SearchSym_In_Class(TObjectDef(lStruct),TObjectDef(lStruct),CurrentScanner.FPattern,lSearchSym,lSearchSymTable,[ssf_search_helper]);
                                  Consume(_ID);
                                  if HandleSpecializeInlineSpecialization(lSearchSym,false,lSearchSymTable,lSpecializationContext) then
                                    lErrorOutOperand:=false;
                                end;
                            end
                          else
                            begin
                              SearchSym_In_Class(TObjectDef(lStruct),TObjectDef(lStruct),CurrentScanner.FPattern,lSearchSym,lSearchSymTable,[ssf_search_helper]);
                              if Assigned(lSearchSym) then
                                begin
                                   lOldCurrentFilePos:=CurrentFilePos;
                                   Consume(_ID);
                                   if not (sp_generic_dummy in lSearchSym.SymOptions) or
                                       not (CurrentScanner.FToken in [_LT,_LSHARPBRACKET]) then
                                     Check_Hints(lSearchSym,lSearchSym.SymOptions,lSearchSym.DeprecatedMsg,lOldCurrentFilePos)
                                   else
                                     AOperand:=CSpecializeNode.Create(AOperand,AGetAddr,lSearchSym,false);
                                   lErrorOutOperand:=false;
                                end
                              else
                                begin
                                   Message1(sym_e_id_no_member,CurrentScanner.FOrgPattern);
                                   { try to clean up }
                                   Consume(_ID);
                                end;
                            end;
                          if lErrorOutOperand then
                            begin
                              AOperand.free;
                              AOperand:=CErrorNode.Create;
                            end
                          else
                            if AOperand.nodetype<>specializen then
                              DoMemberRead(lStruct,AGetAddr,lSearchSym,AOperand,AAgain,[],lSpecializationContext);
                        end
                      else { Error }
                        Consume(_ID);
                    end;
                  pointerdef:
                    begin
                      if (AOperand.resultdef=ObjC_IDType) then
                        begin
                          { objc's id type can be used to call any
                            Objective-C method of any Objective-C class
                            type that's currently in scope }
                          if Search_ObjC_Method(CurrentScanner.FPattern,lSearchSym,lSearchSymTable) then
                            begin
                              Consume(_ID);
                              DoProcCall(lSearchSym,lSearchSymTable,nil,
                                (AGetAddr and not(CurrentScanner.FToken in [_CARET,_POINT])),
                                AAgain,AOperand,[cnf_objc_id_call],nil);
                              { we need to know which procedure is called }
                              DoTypeCheckPass(AOperand);
                            end
                          else
                            begin
                              Consume(_ID);
                              Message(parser_e_methode_id_expected);
                            end;
                        end
                      else
                        begin
                          if not TryTypeHelper(AOperand,nil) then
                            begin
                              Message(parser_e_invalid_qualifier);
                              if TPointerDef(AOperand.resultdef).PointedDef.typ in [recorddef,objectdef,classrefdef] then
                                Message(parser_h_maybe_deref_caret_missing);
                            end;
                        end
                    end;
                  else
                    begin
                      if lAutoDeref then
                        begin
                          { always try with the not dereferenced node }
                          lSecondNode:=TDerefNode(AOperand).left;
                          lFound:=TryTypeHelper(lSecondNode,nil);
                          if lFound then
                            begin
                              TDerefNode(AOperand).left:=nil;
                              AOperand.free;
                              AOperand:=lSecondNode;
                            end;
                        end
                      else
                        lFound:=TryTypeHelper(AOperand,nil);
                      if not lFound then
                        begin
                          if AOperand.resultdef.typ<>undefineddef then
                            Message(parser_e_invalid_qualifier);
                          AOperand.free;
                          AOperand:=CErrorNode.Create;
                          { Error }
                          Consume(_ID);
                        end;
                    end;
               end;
               { processing an ordconstnode avoids the resultdef check }
               SkipPointDefCheck:
             end;

          else
            begin
              { is this a procedure variable ? }
              if Is_Invokable(AOperand.resultdef) and
                  (CurrentScanner.FToken=_LKLAMMER) then
                begin
                  if not SearchSym_In_Class(TObjectDef(AOperand.resultdef),TObjectDef(AOperand.resultdef),MethodNameFuncRefInvokeFind,lSearchSym,lSearchSymTable,[]) then
                    InternalError(2021040202);
                  include(AOperand.flags,nf_load_procvar);
                  DoProcCall(lSearchSym,lSearchSymTable,TAbstractRecordDef(AOperand.resultdef),false,AAgain,AOperand,[],nil);
                end
              else if Assigned(AOperand.resultdef) and
                 (AOperand.resultdef.typ=procvardef) then
                begin
                  { Typenode for typecasting or expecting a procvar }
                  if (AOperand.nodetype=typen) or
                     (
                      Assigned(GetProcVarDef) and
                      Equal_Defs(AOperand.resultdef,GetProcVarDef)
                     ) or
                     (
                      Assigned(GetFuncRefDef) and
                      Equal_Defs(AOperand.resultdef,GetFuncRefDef)
                     ) then
                    begin
                      if TryToConsume(_LKLAMMER) then
                        begin
                          AOperand:=CompExpr([efAcceptEqual]);
                          Consume(_RKLAMMER);
                          AOperand:=CTypeConvNode.Create_Explicit(AOperand,AOperand.resultdef);
                        end
                      else
                        AAgain:=false
                    end
                  else
                    begin
                      if TryToConsume(_LKLAMMER) then
                        begin
                          lSecondNode:=ParseParas(false,false,_RKLAMMER);
                          Consume(_RKLAMMER);
                          AOperand:=CCallNode.Create_ProcVar(lSecondNode,AOperand);
                          { proc():= is never possible }
                          if CurrentScanner.FToken=_ASSIGNMENT then
                            begin
                              Message(parser_e_illegal_expression);
                              AOperand.free;
                              AOperand:=CErrorNode.Create;
                              AAgain:=false;
                            end;
                        end
                      else
                        AAgain:=false;
                    end;
                end
              else
                AAgain:=false;
             end;
        end;

        { we only try again if p1 was changed }
        if AAgain or
           (AOperand.nodetype=errorn) then
          Result:=true;
      end; { while again }
    end;

    function IsMemberRead(ASym: TSym; ASymTable: TSymTable; var ANode: TNode;
                            out AMemberParentDef: TDef): Boolean;
      var
        lDef : TDef;
      begin
        Result:=true;
        AMemberParentDef:=nil;

        case ASymTable.SymTableType of
          ObjectSymtable,
          recordsymtable:
            begin
              AMemberParentDef:=TDef(ASymTable.DefOwner);
              exit;
            end;
          WithSymtable:
            begin
              if Assigned(ANode) then
               InternalError(2007012002);

              lDef:=TNode(TWithSymTable(ASymTable).WithRefNode).resultdef;
              ANode:=TNode(TWithSymTable(ASymTable).WithRefNode).GetCopy;

              if not(lDef.typ in [objectdef,classrefdef]) then
                exit;

              if (lDef.typ=classrefdef) then
                lDef:=TClassRefDef(lDef).PointedDef;
              AMemberParentDef:=lDef;
            end;
          else
            Result:=false;
        end;
      end;

  {$maxfpuregisters 0}


    function FactorHandleSym(ASym:TSym;ASymTable:TSymTable;var AAgain:Boolean;AGetAddr:Boolean;AUnitFound:Boolean;AFlags:TExprFlags;var ASpecializationContext:TSpecializationContext):TNode;
      var
        lDef : TDef;
        lProcDef : TProcDef;
        lCallFlags : TCallNodeFlags;
        lTempGetAddr : Boolean;
      begin
        lDef:=nil;
        Result:=nil;
        case ASym.typ of
          absolutevarsym :
            begin
              if (TAbsoluteVarSym(ASym).AbsTyp=tovar) then
                begin
                  Result:=nil;
                  PropAccessList_To_Node(Result,nil,TAbsoluteVarSym(ASym).Ref);
                  Result:=CTypeConvNode.Create(Result,TAbsoluteVarSym(ASym).vardef);
                  include(Result.flags,nf_absolute);
                  if TAbsoluteVarSym(ASym).vardef=S64CurrencyType then
                    { If a Currency type is connected to another type, we have
                      to make sure a scalar is never applied }
                    include(Result.flags,nf_is_currency);
                end
              else
                Result:=CLoadNode.Create(ASym,ASymTable);
            end;

          staticvarsym,
          localvarsym,
          paravarsym,
          FieldVarSym :
            begin
              { check if we are reading a field of an object/class/   }
              { record. is_member_read() will deal with withsymtables }
              { if needed.                                            }
              Result:=nil;
              if IsMemberRead(ASym,ASymTable,Result,lDef) then
                begin
                  { if the field was originally found in an     }
                  { objectsymtable, it means it's part of self  }
                  { if only method from which it was called is  }
                  { not class static                            }
                  if (ASymTable.SymTableType in [ObjectSymtable,recordsymtable]) then
                    { if we are accessing a owner procsym from the nested }
                    { class we need to call it as a class member          }
                    if Assigned(CurrentStructDef) and
                        (((CurrentStructDef<>lDef) and Is_Owned_By(CurrentStructDef,lDef)) or
                         (sp_static in ASym.SymOptions)) then
                      if ASymTable.SymTableType=recordsymtable then
                        Result:=CTypeNode.Create(lDef)
                      else
                        Result:=CLoadVMTAddrNode.Create(CTypeNode.Create(lDef))
                    else
                      begin
                        if Assigned(CurrentProcInfo) then
                          begin
                            lProcDef:=CurrentProcInfo.Get_Normal_Proc.procdef;
                            if Assigned(lProcDef) and lProcDef.No_Self_Node then
                              Result:=CLoadVMTAddrNode.Create(CTypeNode.Create(lProcDef.struct))
                            else
                              Result:=Load_Self_Node;
                          end
                        else
                          Result:=Load_Self_Node;
                      end;
                  { now, if the field itself is part of an objectsymtab }
                  { (it can be even if it was found in a withsymtable,  }
                  {  e.g., "with classinstance do field := 5"), then    }
                  { let do_member_read handle it                        }
                  if (ASym.owner.SymTableType in [ObjectSymtable,recordsymtable]) then
                    DoMemberRead(TAbstractRecordDef(lDef),AGetAddr,ASym,Result,AAgain,[],nil)
                  else
                    { otherwise it's a regular record subscript }
                    Result:=CSubscriptNode.Create(ASym,Result);
                end
              else
                { regular non-field load }
                Result:=CLoadNode.Create(ASym,ASymTable);
            end;

          syssym :
            begin
              Result:=StatementSysSym(TSysSym(ASym).number);
            end;

          TypeSym :
            begin
              lDef:=TTypeSym(ASym).TypeDef;
              if not Assigned(lDef) then
               begin
                 AAgain:=false;
               end
              else
               begin
                 if (m_delphi in CurrentSettings.ModeSwitches) and
                     (sp_generic_dummy in ASym.SymOptions) and
                     (CurrentScanner.FToken in [_LT,_LSHARPBRACKET]) then
                   begin
                     if Block_Type in [bt_type,bt_const_type,bt_var_type] then
                       begin
                         if not HandleSpecializeInlineSpecialization(ASym,AUnitFound,ASymTable,ASpecializationContext) or (ASym.typ=ProcSym) then
                           begin
                             ASpecializationContext.free;
                             ASpecializationContext := nil;
                             Result:=CErrorNode.Create;
                             if TryToConsume(_LKLAMMER) then
                              begin
                                ParseParas(false,false,_RKLAMMER);
                                Consume(_RKLAMMER);
                              end;
                           end
                         else
                           begin
                             if ASym.typ<>TypeSym then
                               InternalError(2015071705);
                             lDef:=TTypeSym(ASym).TypeDef;
                             Result:=HandleFactorTypeNode(lDef,AGetAddr,AAgain,ASym,efTypeOnly in AFlags);
                           end;
                       end
                     else
                       Result:=CSpecializeNode.Create(nil,AGetAddr,ASym,AUnitFound)
                   end
                 else
                   begin
                     { We need to know if this unit uses Variants }
                     if ((lDef=CVariantType) or (lDef=COleVariantType)) and
                        not(cs_compilesystem in CurrentSettings.ModuleSwitches) then
                       include(CurrentModule.ModuleFlags,mf_uses_variants);
                     Result:=HandleFactorTypeNode(lDef,AGetAddr,AAgain,ASym,efTypeOnly in AFlags);
                   end;
               end;
            end;

          enumsym :
            begin
              Result:=GenEnumNode(TEnumSym(ASym));
            end;

          constsym :
            begin
              if TConstSym(ASym).ConstTyp in [constresourcestring,constwresourcestring]then
                begin
                  Result:=CLoadNode.Create(ASym,ASymTable);
                  DoTypeCheckPass(Result);
                  if Is_SystemUnit_Unicode then
                    Result.resultdef:=CStringDef.CreateUnicode(true)
                  else
                    Result.resultdef:=GetAnsiStringDef;
                end
              else
                Result:=GenConstSymTree(TConstSym(ASym));
            end;

          ProcSym :
            begin
              Result:=nil;
              if (m_delphi in CurrentSettings.ModeSwitches) and
                  (sp_generic_dummy in ASym.SymOptions) and
                  (CurrentScanner.FToken in [_LT,_LSHARPBRACKET]) then
                begin
                  Result:=CSpecializeNode.Create(nil,AGetAddr,ASym,AUnitFound)
                end
              { check if it's a method/class method }
              else if IsMemberRead(ASym,ASymTable,Result,lDef) then
                begin
                  { if we are accessing a owner procsym from the nested }
                  { class we need to call it as a class member          }
                  if (ASymTable.SymTableType in [ObjectSymtable,recordsymtable]) and
                    Assigned(CurrentStructDef) and (CurrentStructDef<>lDef) and Is_Owned_By(CurrentStructDef,lDef) then
                    Result:=CLoadVMTAddrNode.Create(CTypeNode.Create(lDef));
                  { not srsymtable.symtabletype since that can be }
                  { withsymtable as well                          }
                  if (ASym.owner.SymTableType in [ObjectSymtable,recordsymtable]) then
                    begin
                      DoMemberRead(TAbstractRecordDef(lDef),AGetAddr,ASym,Result,AAgain,[],ASpecializationContext);
                      ASpecializationContext:=nil;
                    end
                  else
                    { no procsyms in records (yet) }
                    InternalError(2007012006);
                end
              else
                begin
                  { regular procedure/function call }
                  if not AUnitFound then
                    lCallFlags:=[]
                  else
                    lCallFlags:=[cnf_unit_specified];
                  { TP7 ugliness: @proc^ is parsed as (@proc)^,
                    but @notproc^ is parsed as @(notproc^) }
                  if m_tp_procvar in CurrentSettings.ModeSwitches then
                    lTempGetAddr:=AGetAddr and not(CurrentScanner.FToken in [_POINT,_LECKKLAMMER])
                  else
                    lTempGetAddr:=AGetAddr and not(CurrentScanner.FToken in [_CARET,_POINT,_LECKKLAMMER]);
                  DoProcCall(ASym,ASymTable,nil,lTempGetAddr,
                               AAgain,Result,lCallFlags,ASpecializationContext);
                  ASpecializationContext:=nil;
                end;
            end;

          propertysym :
            begin
              Result:=nil;
              { property of a class/object? }
              if IsMemberRead(ASym,ASymTable,Result,lDef) then
                begin
                  if (ASymTable.SymTableType in [ObjectSymtable,recordsymtable]) then
                    { if we are accessing a owner procsym from the nested }
                    { class or from a static class method we need to call }
                    { it as a class member                                }
                    if (Assigned(CurrentStructDef) and (CurrentStructDef<>lDef) and Is_Owned_By(CurrentStructDef,lDef)) or
                       (Assigned(CurrentProcInfo) and CurrentProcInfo.Get_Normal_Proc.procdef.No_Self_Node) then
                      begin
                        Result:=CTypeNode.Create(lDef);
                        if not Is_Record(lDef) then
                          Result:=CLoadVMTAddrNode.Create(Result);
                      end
                    else
                      Result:=Load_Self_Node;
                  { not srsymtable.symtabletype since that can be }
                  { withsymtable as well                          }
                  if (ASym.owner.SymTableType in [ObjectSymtable,recordsymtable]) then
                    DoMemberRead(TAbstractRecordDef(lDef),AGetAddr,ASym,Result,AAgain,[],nil)
                  else
                    { no propertysyms in records (yet) }
                    InternalError(2009111510);
                end
              else
              { no method pointer }
                begin
                  HandlePropertySym(TPropertySym(ASym),ASymTable,Result);
                end;
            end;

          labelsym :
            begin
              { Support @label }
              if AGetAddr then
                begin
                  if ASym.owner<>CurrentProcInfo.procdef.LocalST then
                    CGMessage(parser_e_label_outside_proc);
                  Result:=CLoadNode.Create(ASym,ASym.owner)
                end
              else
                begin
                  Consume(_COLON);
                  if TLabelSym(ASym).defined then
                    Message(sym_e_label_already_defined);
                  if SymTableStack.top.SymTableLevel<>ASymTable.SymTableLevel then
                    begin
                      include(CurrentProcInfo.flags,pi_has_interproclabel);
                      if (CurrentProcInfo.procdef.ProcTypeOption in [potype_unitinit,potype_unitfinalize]) then
                        Message(sym_e_interprocgoto_into_init_final_code_not_allowed);
                    end;
                  TLabelSym(ASym).defined:=true;
                  Result:=CLabelNode.Create(nil,TLabelSym(ASym));
                  TLabelSym(ASym).code:=Result;
                end;
            end;

          undefinedsym :
            begin
              Result:=CNothingNode.Create;
              Result.resultdef:=CUndefinedDef.Create(true);
              { clean up previously created dummy symbol }
              ASym.free;
              ASym := nil;
            end;

          UnitSym,
          namespacesym :
            begin
              if NameOfActive then
                { NameOf(unitname) }
                Result:=CNothingNode.Create
              else
                begin
                  Result:=CErrorNode.Create;
                  Message(parser_e_illegal_expression);
                end;
            end;

          errorsym :
            begin
              Result:=CErrorNode.Create;
              if TryToConsume(_LKLAMMER) then
               begin
                 ParseParas(false,false,_RKLAMMER);
                 Consume(_RKLAMMER);
               end;
            end;

          else
            begin
              Result:=CErrorNode.Create;
              Message(parser_e_illegal_expression);
            end;
        end; { end case }
      end;


    function Factor(AGetAddr:Boolean;AFlags:TExprFlags) : TNode;

         {---------------------------------------------
                         Factor_read_id
         ---------------------------------------------}

       procedure FactorReadID(out ANode:TNode;out AAgain:Boolean);

         function FindWithSymTable : Boolean;
           var
             lStackItem : PSymTableStackItem;
           begin
             Result:=true;
             lStackItem:=SymTableStack.stack;
             while Assigned(lStackItem) do
               begin
                 if lStackItem^.SymTable.SymTableType=withsymtable then
                   exit;
                 lStackItem:=lStackItem^.next;
               end;
             Result:=false;
           end;

         var
           lSearchSym: TSym;
           lSearchSymTable: TSymTable;
           lDef: TDef;
           lSavedOrgPattern,
           lSavedPattern: String;
           lToken : TToken;
           lConsumeID,
           lWasGenericDummy,
           lAllowSpecialize,
           lIsSpecialize,
           lUnitFound : Boolean;
           lDummyPos,
           lTokenPos: TFilePosInfo;
           lSpecializationContext : TSpecializationContext;
           lUnitSymFlags : TConsumeUnitSymFlags;
         begin
           { allow post fix operators }
           AAgain:=true;

           { preinitalize tokenpos }
           lTokenPos:=CurrentFilePos;
           ANode:=nil;
           lSpecializationContext:=nil;

           { avoid warning }
           fillchar(lDummyPos,sizeof(lDummyPos),0);

           lAllowSpecialize:=not (m_delphi in CurrentSettings.ModeSwitches) and
                            not (efHadSpecialize in AFlags) and
                            (Block_Type in cInlineSpecializationBlockTypes);
           if lAllowSpecialize and (CurrentScanner.FToken=_ID) and (CurrentScanner.FIDToken=_SPECIALIZE) then
             begin
               Consume(_ID);
               lIsSpecialize:=true;
             end
           else
             lIsSpecialize:=efHadSpecialize in AFlags;

           { first check for identifier }
           if CurrentScanner.FToken<>_ID then
             begin
               lSearchSym:=GenErrorSym;
               lSearchSymTable:=nil;
               Consume(_ID);
               lUnitFound:=false;
             end
           else
             begin
               lSavedPattern:=CurrentScanner.FPattern;
               lSavedOrgPattern:=CurrentScanner.FOrgPattern;
               { store the position of the token before consuming it }
               lTokenPos:=CurrentFilePos;
               lConsumeID:=true;
               lSearchSym:=nil;
               if efCheckAttrSuffix in AFlags then
                 begin
                   if not (efTypeOnly in AFlags) then
                     InternalError(2019063001);
                   Consume(_ID);
                   lConsumeID:=false;
                   if CurrentScanner.FToken<>_POINT then
                     SearchSym_Type(lSavedPattern+CustomAttributeSuffix,lSearchSym,lSearchSymTable);
                 end;
               if not Assigned(lSearchSym) then
                 begin
                   if efTypeOnly in AFlags then
                     SearchSym_Type(lSavedPattern,lSearchSym,lSearchSymTable)
                   else
                     SearchSym(lSavedPattern,lSearchSym,lSearchSymTable);
                 end;
               { handle unit specification like System.Writeln }
               if not lIsSpecialize then
                 begin
                   lUnitSymFlags:=[];
                   if lConsumeID then
                     include(lUnitSymFlags,cufConsumeID);
                   if lAllowSpecialize then
                     include(lUnitSymFlags,cufAllowSpecialize);
                   if efCheckAttrSuffix in AFlags then
                     include(lUnitSymFlags,cufCheckAttrSuffix);
                   if NameOfActive then
                     include(lUnitSymFlags,cufAllowUnitOnly);
                   lUnitFound:=TryConsumeUnitSym(lSearchSym,lSearchSymTable,lToken,lUnitSymFlags,lIsSpecialize,CurrentScanner.FPattern);
                   if lUnitFound then
                     lConsumeID:=true;
                 end
               else
                 begin
                   lUnitFound:=false;
                   lToken:=_ID;
                 end;
               { NOTOKEN: NameOf(unitname), the unit name is already consumed }
               if lConsumeID and (lToken<>NOTOKEN) then
                 begin
                   lSavedPattern:=CurrentScanner.FPattern;
                   lSavedOrgPattern:=CurrentScanner.FOrgPattern;
                   { store the position of the token before consuming it }
                   lTokenPos:=CurrentFilePos;
                   Consume(lToken);
                 end;
               { named parameter support }
               FoundArgName:=false;

               if not(lUnitFound) and
                   not lIsSpecialize and
                  NamedArgsAllowed and
                  (CurrentScanner.FToken=_ASSIGNMENT) then
                  begin
                    FoundArgName:=true;
                    ANode:=CStringConstNode.CreateStr(lSavedOrgPattern);
                    Consume(_ASSIGNMENT);
                    exit;
                  end;

               if lIsSpecialize then
                 begin
                   if not Assigned(lSearchSym) then
                     begin
                       IdentifierNotFound(lSavedOrgPattern,lTokenPos);
                       lSearchSym:=GenErrorSym;
                       lSearchSymTable:=nil;
                     end
                   else
                     begin
                       if not lUnitFound then
                         lSearchSymTable:=nil;
                       {$push}
                       {$warn 5036 off}
                       lDef:=GenerateSpecializationPhase1(lSpecializationContext,nil,lUnitFound,nil,lSavedOrgPattern,lSearchSymTable,lDummyPos);
                       {$pop}
                       if lDef=GenErrorDef then
                         begin
                           lSpecializationContext.free;
                           lSpecializationContext:=nil;
                           lSearchSym:=GenErrorSym;
                           lSearchSymTable:=nil;
                         end
                       else
                         begin
                           if lDef.typ in [objectdef,recorddef,procvardef,arraydef] then
                             begin
                               lDef:=GenerateSpecializationPhase2(lSpecializationContext,TStoredDef(lDef),false,'');
                               lSpecializationContext.free;
                               lSpecializationContext:=nil;
                               if lDef<>GenErrorDef then
                                 begin
                                   lSearchSym:=lDef.TypeSym;
                                   lSearchSymTable:=lSearchSym.owner;
                                 end
                               else
                                 begin
                                   lSearchSym:=GenErrorSym;
                                   lSearchSymTable:=nil;
                                 end;
                             end
                           else
                             if lDef.typ=procdef then
                               begin
                                 if not(Block_Type in cInlineSpecializationBlockTypes) then
                                   message(parser_e_illegal_expression);
                                 lSearchSym:=TProcDef(lDef).ProcSym;
                                 if Assigned(lSpecializationContext.FSymTable) then
                                   lSearchSymTable:=lSpecializationContext.FSymTable
                                 else
                                   lSearchSymTable:=lSearchSym.owner;
                               end
                             else
                               InternalError(2015061204);
                         end;
                     end;
                 end;

               lWasGenericDummy:=false;
               if Assigned(lSearchSym) and
                   (sp_generic_dummy in lSearchSym.SymOptions) and
                   (lSearchSym.typ in [ProcSym,TypeSym]) and
                   (
                     (
                       (m_delphi in CurrentSettings.ModeSwitches) and
                       not (CurrentScanner.FToken in [_LT, _LSHARPBRACKET]) and
                       (
                         (
                           (lSearchSym.typ=TypeSym) and
                           (TTypeSym(lSearchSym).TypeDef.typ=undefineddef)
                         ) or (
                           (lSearchSym.typ=ProcSym) and
                           (TProcSym(lSearchSym).procdeflist.count=0)
                         )
                       )
                     )
                     or
                     (
                       not (m_delphi in CurrentSettings.ModeSwitches) and
                       not lIsSpecialize and
                       (
                         not ParseGeneric or
                         not (
                           Assigned(CurrentStructDef) and
                           Assigned(Get_Generic_In_Hierarchy_By_Name(lSearchSym,CurrentStructDef))
                         )
                       )
                     )
                   ) then
                 begin
                   lSearchSym:=ResolveGenericDummySym(lSearchSym.name);
                   if Assigned(lSearchSym) then
                     lSearchSymTable:=lSearchSym.owner
                   else
                     begin
                       lSearchSymTable:=nil;
                       lWasGenericDummy:=true;
                     end;
                 end;

               { check hints, but only if it isn't a potential generic symbol;
                 that is checked in sub_expr if it isn't a generic }
               if Assigned(lSearchSym) and
                   not (
                     (lSearchSym.typ=TypeSym) and
                     (
                       (TTypeSym(lSearchSym).TypeDef.typ in [recorddef,objectdef,arraydef,procvardef,undefineddef]) or
                       (
                         (TTypeSym(lSearchSym).TypeDef.typ=errordef) and
                         (sp_generic_dummy in lSearchSym.SymOptions)
                       )
                     ) and
                     not (sp_generic_para in lSearchSym.SymOptions) and
                     (CurrentScanner.FToken in [_LT, _LSHARPBRACKET])
                   ) then
                 Check_Hints(lSearchSym,lSearchSym.SymOptions,lSearchSym.DeprecatedMsg,lTokenPos);

               { if nothing found give error and return errorsym }
               if not Assigned(lSearchSym) or
                   { is this a generic dummy symbol? }
                   ((lSearchSym.typ=TypeSym) and
                   Assigned(TTypeSym(lSearchSym).TypeDef) and
                   (TTypeSym(lSearchSym).TypeDef.typ=undefineddef) and
                   not (sp_generic_para in lSearchSym.SymOptions) and
                   not (CurrentScanner.FToken in [_LT, _LSHARPBRACKET]) and
                   not (
                     { in non-Delphi modes the generic class' name without a
                       "specialization" or "<T>" may be used to identify the
                       current class }
                     (sp_generic_dummy in lSearchSym.SymOptions) and
                     Assigned(CurrentStructDef) and
                     (df_generic in CurrentStructDef.DefOptions) and
                     not (m_delphi in CurrentSettings.ModeSwitches) and
                     Assigned(Get_Generic_In_Hierarchy_By_Name(lSearchSym,CurrentStructDef))
                   )) and
                   { it could be a rename of a generic para }
                   { Note: if this generates false positives we'll need to
                           include a "basesym" to tsym to track the original
                           symbol }
                   not (sp_explicitrename in lSearchSym.SymOptions) then
                 begin
                   { if a generic is parsed and when we are inside an with block,
                     a symbol might not be defined }
                   if Assigned(CurrentProcInfo) and (df_generic in CurrentProcInfo.procdef.DefOptions) and
                      FindWithSymTable then
                     begin
                       { create dummy symbol, it will be freed later on }
                       lSearchSym:=TStoredSym.Create(undefinedsym,'$undefinedsym');
                       lSearchSymTable:=nil;
                     end
                   else
                     begin
                       if lWasGenericDummy then
                         messagepos(lTokenPos,parser_e_no_generics_as_types)
                       else
                         IdentifierNotFound(lSavedOrgPattern,lTokenPos);
                       lSearchSym:=GenErrorSym;
                       lSearchSymTable:=nil;
                     end;
                 end;
             end;

           { Access to funcret or need to call the function? }
           if (lSearchSym.typ in [absolutevarsym,localvarsym,paravarsym]) and
              (vo_is_funcret in TAbstractVarSym(lSearchSym).VarOptions) and
              { result(x) is not allowed }
              not(vo_is_result in TAbstractVarSym(lSearchSym).VarOptions) and
              (
               (CurrentScanner.FToken=_LKLAMMER) or
               (
                (([m_delphi,m_mac,m_iso] * CurrentSettings.ModeSwitches) <> []) and
                (AfterAssignment or InArgs)
               )
              ) then
            begin
              lDef:=TDef(lSearchSym.owner.DefOwner);
              if Assigned(lDef) and
                 (lDef.typ=procdef) then
                lSearchSym:=TProcDef(lDef).ProcSym
              else
                begin
                  Message(parser_e_illegal_expression);
                  lSearchSym:=GenErrorSym;
                end;
              lSearchSymTable:=lSearchSym.owner;
            end;

            begin
              NameOfRecordSym(lSearchSym);
              ANode:=FactorHandleSym(lSearchSym,lSearchSymTable,AAgain,AGetAddr,lUnitFound,AFlags,lSpecializationContext);

              if Assigned(lSpecializationContext) then
                InternalError(2015061207);

              if Assigned(ANode) and (ANode.nodetype<>errorn) then
                ANode.fileinfo:=lTokenPos;
            end;
         end;

         {---------------------------------------------
                         Factor_Read_Set
         ---------------------------------------------}

         { Read a set between [] }
         function FactorReadSet:TNode;
         var
           lElementNode,lRangeHighNode : TNode;
           lLastElement,
           lArrayConstructor : TArrayConstructorNode;
         begin
           lArrayConstructor:=nil;
           lLastElement:=nil;
         { be sure that a least one arrayconstructn is used, also for an
           empty [] }
           if CurrentScanner.FToken=_RECKKLAMMER then
             lArrayConstructor:=CArrayConstructorNode.Create(nil,lArrayConstructor)
           else
            repeat
              lElementNode:=CompExpr([efAcceptEqual]);
              if TryToConsume(_POINTPOINT) then
                begin
                  lRangeHighNode:=CompExpr([efAcceptEqual]);
                  lElementNode:=CArrayConstructorRangeNode.Create(lElementNode,lRangeHighNode);
                end;
               { insert at the end of the tree, to get the correct order }
             if not Assigned(lArrayConstructor) then
               begin
                 lArrayConstructor:=CArrayConstructorNode.Create(lElementNode,nil);
                 lLastElement:=lArrayConstructor;
               end
             else
               begin
                 lLastElement.right:=CArrayConstructorNode.Create(lElementNode,nil);
                 lLastElement:=TArrayConstructorNode(lLastElement.right);
               end;
           { there could be more elements }
           until not TryToConsume(_COMMA);
           if Block_Type in [bt_body,bt_except] then
             Include(lArrayConstructor.ArrayConstructorNodeFlags, acnf_allow_array_constructor);
           FactorReadSet:=lArrayConstructor;
         end;

         function CanLoadSelfNode: Boolean;
         begin
           Result:=false;
           if (Block_Type in [bt_const,bt_type,bt_const_type,bt_var_type]) or
              not Assigned(CurrentStructDef) or
              not Assigned(CurrentProcInfo) then
             exit;
           Result:=not CurrentProcInfo.Get_Normal_Proc.procdef.No_Self_Node;
         end;


      {---------------------------------------------
                      Factor (Main)
      ---------------------------------------------}

      var
         lLength          : LongInt;
         lIntConst         : Int64;
         lQWordConst         : QWord;
         lNode         : TNode;
         lCode       : Integer;
         lSearchSym      : TSym;
         lSearchSymTable : TSymTable;
         lProcDef         : TProcDef;
         lClassDef  : TObjectDef;
         lRealValue          : BestReal;
         lText,lOrgText   : String;
         lDef       : TDef;
         lFilePos    : TFilePosInfo;
         lCallFlags  : TCallNodeFlags;
         lIDString      : TIDString;
         lSpecializationContext : TSpecializationContext;
         lIsSpecialize,
         lMightBeGeneric,
         lUseSelf,
         lDoPostfix,
         lAgain,
         lUpdateFilePos,
         lNodeChanged  : Boolean;
         lOldProcVarDef : TProcVarDef;
         lOldFuncRefDef : TObjectDef;
      begin
        { can't keep a copy of p1 and compare pointers afterwards, because
          p1 may be freed and reallocated in the same place!  }
        lDoPostfix:=true;
        lUpdateFilePos:=false;
        lNode:=nil;
        lFilePos:=CurrentTokenPos;
        lAgain:=false;
        lProcDef:=nil;
        lIsSpecialize:=false;
        if CurrentScanner.FToken=_ID then
         begin
           lAgain:=true;
           { Handle references to self }
           if (CurrentScanner.FIDToken=_SELF) and CanLoadSelfNode then
             begin
               lNode:=Load_Self_Node;
               Consume(_ID);
               lAgain:=true;
             end
           else
             FactorReadID(lNode,lAgain);

           if Assigned(lNode) then
            begin
              { factor_read_id will set the filepos to after the id,
                and in case of _SELF the filepos will already be the
                same as filepos (so setting it again doesn't hurt).  }
              lNode.fileinfo:=lFilePos;
              lFilePos:=CurrentTokenPos;
            end;
           { handle post fix operators }
           if (lNode.nodetype=specializen) then
             { post fix operators are handled after specialization }
             lDoPostfix:=false
           else
             if (m_delphi in CurrentSettings.ModeSwitches) and
                 (Block_Type in cInlineSpecializationBlockTypes) and
                 (CurrentScanner.FToken in [_LT,_LSHARPBRACKET]) then
               begin
                 lIDString:='';
                 case lNode.nodetype of
                   typen:
                     lIDString:=TTypeNode(lNode).TypeSym.name;
                   loadvmtaddrn:
                     if TLoadVMTAddrNode(lNode).left.nodetype=typen then
                       lIDString:=TTypeNode(TLoadVMTAddrNode(lNode).left).TypeSym.name;
                   loadn:
                     lIDString:=TLoadNode(lNode).SymTableEntry.name;
                   calln:
                     lIDString:=TCallNode(lNode).SymTableProcEntry.name;
                   else
                     ;
                 end;
                 { if this is the case then the postfix handling is done in
                   sub_expr if necessary }
                 lDoPostfix:=not CouldBeGeneric(lIDString);
               end;
           { TP7 ugliness: @proc^ is parsed as (@proc)^, but @notproc^ is parsed
             as @(notproc^) }
           if (m_tp_procvar in CurrentSettings.ModeSwitches) and (CurrentScanner.FToken=_CARET) and
              AGetAddr and (lNode.nodetype=loadn) and (TLoadNode(lNode).SymTableEntry.typ=ProcSym) then
             lDoPostfix:=false;
           { maybe an additional parameter instead of misusing hadspezialize? }
           if lDoPostfix and not (efHadSpecialize in AFlags) then
             lUpdateFilePos:=PostfixOperators(lNode,lAgain,AGetAddr);
         end
        else
         begin
           lUpdateFilePos:=true;
           case CurrentScanner.FToken of
             _RETURN :
                begin
                  Consume(_RETURN);
                  lNode:=nil;
                  if not(CurrentScanner.FToken in [_SEMICOLON,_ELSE,_END]) then
                    begin
                      lNode:=CompExpr([efAcceptEqual]);
                      if not Assigned(CurrentProcInfo) or
                         (CurrentProcInfo.procdef.ProcTypeOption in [potype_constructor,potype_destructor]) or
                         Is_Void(CurrentProcInfo.procdef.ReturnDef) then
                        begin
                          Message(parser_e_void_function);
                          { recovery }
                          lNode.free;
                          lNode:=nil;
                        end;
                    end;
                  lNode := CExitNode.Create(lNode);
                end;
             _INHERITED :
               begin
                 lAgain:=true;
                 Consume(_INHERITED);
                 if Assigned(CurrentProcInfo) and
                    Assigned(CurrentStructDef) and
                    (CurrentStructDef.typ=objectdef) then
                  begin
                    { for record helpers in mode Delphi "inherited" is not
                      allowed }
                    if Is_ObjectPascal_Helper(CurrentStructDef) and
                        (m_delphi in CurrentSettings.ModeSwitches) and
                        (TObjectDef(CurrentStructDef).HelperType=ht_record) then
                      Message(parser_e_inherited_not_in_record);
                    lClassDef:=TObjectDef(CurrentStructDef).ChildOf;
                    { Objective-C categories *replace* methods in the class
                      they extend, or add methods to it. So calling an
                      inherited method always calls the method inherited from
                      the parent of the extended class }
                    if Is_ObjCCategory(CurrentStructDef) then
                      lClassDef:=lClassDef.ChildOf;
                    lSpecializationContext:=nil;
                    { if inherited; only then we need the method with
                      the same name }
                    if CurrentScanner.FToken <> _ID then
                     begin
                       lText:=CurrentProcInfo.procdef.ProcSym.name;
                       lOrgText:=CurrentProcInfo.procdef.ProcSym.realname;
                       AnonInherited:=true;
                       { For message methods we need to search using the message
                         number or string }
                       lProcDef:=TProcDef(TProcSym(CurrentProcInfo.procdef.ProcSym).ProcdefList[0]);
                       SRDef:=nil;
                       if (po_msgint in lProcDef.ProcOptions) then
                         SearchSym_In_Class_By_MsgInt(lClassDef,lProcDef.MessageInf.i,SRDef,lSearchSym,lSearchSymTable)
                       else
                        if (po_msgstr in lProcDef.ProcOptions) then
                          SearchSym_In_Class_By_MsgStr(lClassDef,lProcDef.MessageInf.str^,lSearchSym,lSearchSymTable)
                       else
                       { helpers have their own ways of dealing with inherited }
                       if Is_ObjectPascal_Helper(CurrentStructDef) then
                         SearchSym_In_Helper(TObjectDef(CurrentStructDef),TObjectDef(CurrentStructDef),lText,lSearchSym,lSearchSymTable,[ssf_has_inherited])
                       else
                         SearchSym_In_Class(lClassDef,CurrentStructDef,lText,lSearchSym,lSearchSymTable,[ssf_search_helper]);
                     end
                    else
                     begin
                       if not (m_delphi in CurrentSettings.ModeSwitches) and
                           (Block_Type in cInlineSpecializationBlockTypes) and
                           (CurrentScanner.FToken=_ID) and
                           (CurrentScanner.FIDToken=_SPECIALIZE) then
                         begin
                           Consume(_ID);
                           if CurrentScanner.FToken<>_ID then
                             message(parser_e_methode_id_expected);
                           lIsSpecialize:=true;
                         end
                       else
                         lIsSpecialize:=false;
                       lText:=CurrentScanner.FPattern;
                       lOrgText:=CurrentScanner.FOrgPattern;
                       Consume(_ID);
                       AnonInherited:=false;
                       { helpers have their own ways of dealing with inherited }
                       if Is_ObjectPascal_Helper(CurrentStructDef) then
                         SearchSym_In_Helper(TObjectDef(CurrentStructDef),TObjectDef(CurrentStructDef),lText,lSearchSym,lSearchSymTable,[ssf_has_inherited])
                       else
                         SearchSym_In_Class(lClassDef,CurrentStructDef,lText,lSearchSym,lSearchSymTable,[ssf_search_helper]);
                       if lIsSpecialize and Assigned(lSearchSym) then
                         begin
                           if not HandleSpecializeInlineSpecialization(lSearchSym,false,lSearchSymTable,lSpecializationContext) then
                             lSearchSym:=nil;
                         end;
                     end;
                    if Assigned(lSearchSym) then
                     begin
                       lMightBeGeneric:=(m_delphi in CurrentSettings.ModeSwitches) and
                                         (CurrentScanner.FToken in [_LT,_LSHARPBRACKET]) and
                                         (sp_generic_dummy in lSearchSym.SymOptions);
                       { load the procdef from the inherited class and
                         not from self }
                       case lSearchSym.typ of
                         TypeSym,
                         ProcSym:
                           begin
                             { typesym is only a valid choice if we're dealing
                               with a potential generic }
                             if (lSearchSym.typ=TypeSym) and not lMightBeGeneric then
                               begin
                                 Message(parser_e_methode_id_expected);
                                 lNode:=CErrorNode.Create;
                               end
                             else
                               begin
                                 lUseSelf:=false;
                                 if Is_ObjectPascal_Helper(CurrentStructDef) then
                                   begin
                                     { for a helper load the procdef either from the
                                       extended type, from the parent helper or from
                                       the extended type of the parent helper
                                       depending on the def the found symbol belongs
                                       to }
                                     if (lSearchSym.Owner.DefOwner.typ=objectdef) and
                                         Is_ObjectPascal_Helper(TObjectDef(lSearchSym.Owner.DefOwner)) then
                                       if Def_Is_Related(CurrentStructDef,TDef(lSearchSym.Owner.DefOwner)) and
                                           Assigned(TObjectDef(CurrentStructDef).ChildOf) then
                                         lDef:=TObjectDef(CurrentStructDef).ChildOf
                                       else
                                         begin
                                           lDef:=TObjectDef(lSearchSym.Owner.DefOwner).ExtendedDef;
                                           lUseSelf:=true;
                                         end
                                     else
                                       begin
                                         lDef:=TDef(lSearchSym.Owner.DefOwner);
                                         lUseSelf:=true;
                                       end;
                                   end
                                 else
                                   lDef:=lClassDef;
                                 if (po_classmethod in CurrentProcInfo.procdef.ProcOptions) or
                                    (po_staticmethod in CurrentProcInfo.procdef.ProcOptions) then
                                   lDef:=CClassRefDef.Create(lDef);
                                 if lUseSelf then
                                   begin
                                     lNode:=CTypeConvNode.Create_Internal(Load_Self_Node,lDef);
                                   end
                                 else
                                   begin
                                     lNode:=CTypeNode.Create(lDef);
                                     { we need to allow helpers here }
                                     TTypeNode(lNode).HelperAllowed:=true;
                                   end;
                               end;
                           end;
                         propertysym:
                           ;
                         else
                           begin
                             Message(parser_e_methode_id_expected);
                             lNode:=CErrorNode.Create;
                           end;
                       end;
                       if lMightBeGeneric then
                         begin
                           lNode:=CSpecializeNode.Create_Inherited(lNode,AGetAddr,lSearchSym,lClassDef);
                         end
                       else
                         begin
                           if not lIsSpecialize then
                             Check_Hints(lSearchSym,lSearchSym.SymOptions,lSearchSym.DeprecatedMsg);
                           lCallFlags:=[cnf_inherited];
                           include(CurrentProcInfo.flags,pi_has_inherited);
                           if AnonInherited then
                             include(lCallFlags,cnf_anon_inherited);
                           DoMemberRead(lClassDef,AGetAddr,lSearchSym,lNode,lAgain,lCallFlags,lSpecializationContext);
                         end;
                       if lNode.nodetype=errorn then
                       begin
                         lSpecializationContext.free;
                         lSpecializationContext := nil;
                       end;
                     end
                    else
                     begin
                       if AnonInherited then
                        begin
                          { For message methods we need to call DefaultHandler }
                          if (po_msgint in lProcDef.ProcOptions) or
                             (po_msgstr in lProcDef.ProcOptions) then
                            begin
                              SearchSym_In_Class(lClassDef,lClassDef,'DEFAULTHANDLER',lSearchSym,lSearchSymTable,[ssf_search_helper]);
                              if not Assigned(lSearchSym) or
                                 (lSearchSym.typ<>ProcSym) then
                                InternalError(200303171);
                              lNode:=nil;
                              DoProcCall(lSearchSym,lSearchSym.owner,lClassDef,false,lAgain,lNode,[],nil);
                            end
                          else
                            begin
                              { we need to ignore the inherited; }
                              lNode:=CNothingNode.Create;
                            end;
                        end
                       else
                        begin
                          Message1(sym_e_id_no_member,lOrgText);
                          lNode:=CErrorNode.Create;
                        end;
                       lAgain:=false;
                     end;
                    { turn auto inheriting off }
                    AnonInherited:=false;
                  end
                 else
                   begin
                     { in case of records we use a more clear error message }
                     if Assigned(CurrentStructDef) and
                         (CurrentStructDef.typ=recorddef) then
                       Message(parser_e_inherited_not_in_record)
                     else
                       Message(parser_e_generic_methods_only_in_methods);
                     lAgain:=false;
                     lNode:=CErrorNode.Create;
                   end;
                 if lNode.nodetype<>specializen then
                   PostfixOperators(lNode,lAgain,AGetAddr);
               end;

             _INTCONST :
               begin
                 {Try first wether the value fits in an int64.}
                 val(CurrentScanner.FPattern,lIntConst,lCode);
                 if lCode=0 then
                   begin
                      Consume(_INTCONST);
                      Int_To_Type(lIntConst,lDef);
                      lNode:=COrdConstNode.Create(lIntConst,lDef,true);
                   end
                 else
                   begin
                     { try qword next }
                     val(CurrentScanner.FPattern,lQWordConst,lCode);
                     if lCode=0 then
                       begin
                          Consume(_INTCONST);
                          Int_To_Type(lQWordConst,lDef);
                          lNode:=COrdConstNode.Create(lQWordConst,lDef,true);
                       end;
                   end;
                 if lCode<>0 then
                   begin
                     { finally float }
                     Val(CurrentScanner.FPattern,lRealValue,lCode);
                     if lCode<>0 then
                       begin
                          Message(parser_e_invalid_integer);
                          Consume(_INTCONST);
                          lLength:=1;
                          lNode:=COrdConstNode.Create(lLength,SIntType,true);
                       end
                     else
                       begin
                          Consume(_INTCONST);
                          lNode:=CRealConstNode.Create(lRealValue,PBestRealType^);
                       end;
                   end
                 else
                   { the necessary range checking has already been done by val }
                   TOrdConstNode(lNode).rangecheck:=false;
                 if CurrentScanner.FToken=_POINT then
                   begin
                     lAgain:=true;
                     PostfixOperators(lNode,lAgain,AGetAddr);
                   end;
               end;

             _REALNUMBER :
               begin
                 lNode:=RealConstNodeFromPattern(CurrentScanner.FPattern);
                 Consume(_REALNUMBER);
                 if CurrentScanner.FToken=_POINT then
                   begin
                     lAgain:=true;
                     PostfixOperators(lNode,lAgain,AGetAddr);
                   end;
               end;

             _STRING :
               begin
                 if cs_compilesystem in CurrentSettings.ModuleSwitches then
                   Message(parser_e_nostringaliasinsystem);
                 StringDec(lDef,true);
                 { STRING can be also a type cast }
                 if TryToConsume(_LKLAMMER) then
                  begin
                    lNode:=CompExpr([efAcceptEqual]);
                    Consume(_RKLAMMER);
                    lNode:=CTypeConvNode.Create_Explicit(lNode,lDef);
                    { handle postfix operators here e.g. string(a)[10] }
                    lAgain:=true;
                    PostfixOperators(lNode,lAgain,AGetAddr);
                  end
                 else
                   begin
                     lNode:=CTypeNode.Create(lDef);
                     if CurrentScanner.FToken=_POINT then
                       begin
                         lAgain:=true;
                         { handle type helpers here }
                         PostfixOperators(lNode,lAgain,AGetAddr);
                       end;
                   end;
               end;

             _FILE :
               begin
                 lDef:=CFileType;
                 Consume(_FILE);
                 { FILE can be also a type cast }
                 if TryToConsume(_LKLAMMER) then
                  begin
                    lNode:=CompExpr([efAcceptEqual]);
                    Consume(_RKLAMMER);
                    lNode:=CTypeConvNode.Create_Explicit(lNode,lDef);
                    { handle postfix operators here e.g. string(a)[10] }
                    lAgain:=true;
                    PostfixOperators(lNode,lAgain,AGetAddr);
                  end
                 else
                  begin
                    lNode:=CTypeNode.Create(lDef);
                  end;
               end;

             _CSTRING :
               begin
                 lNode:=CStringConstNode.CreatePChar(pchar(CurrentScanner.FCStringPattern),length(CurrentScanner.FCStringPattern),nil);
                 Consume(_CSTRING);
                 if CurrentScanner.FToken in postfixoperator_tokens then
                   begin
                     lAgain:=true;
                     PostfixOperators(lNode,lAgain,AGetAddr);
                   end;
               end;

             _CCHAR :
               begin
                 lNode:=COrdConstNode.Create(ord(CurrentScanner.FPattern[1]),CAnsiCharType,true);
                 Consume(_CCHAR);
                 if CurrentScanner.FToken=_POINT then
                   begin
                     lAgain:=true;
                     PostfixOperators(lNode,lAgain,AGetAddr);
                   end;
               end;

             _CWSTRING:
               begin
                 if GetLengthWideString(CurrentScanner.FPatternW)=1 then
                   lNode:=COrdConstNode.Create(ord(GetCharWideString(CurrentScanner.FPatternW,0)),CWideCharType,true)
                 else
                   lNode:=CStringConstNode.CreateUniStr(CurrentScanner.FPatternW);
                 Consume(_CWSTRING);
                 if CurrentScanner.FToken in postfixoperator_tokens then
                   begin
                     lAgain:=true;
                     PostfixOperators(lNode,lAgain,AGetAddr);
                   end;
               end;

             _CWCHAR:
               begin
                 lNode:=COrdConstNode.Create(ord(GetCharWideString(CurrentScanner.FPatternW,0)),CWideCharType,true);
                 Consume(_CWCHAR);
                 if CurrentScanner.FToken=_POINT then
                   begin
                     lAgain:=true;
                     PostfixOperators(lNode,lAgain,AGetAddr);
                   end;
               end;

             _KLAMMERAFFE :
               begin
                 Consume(_KLAMMERAFFE);
                 GotAddrN:=true;
                 { support both @<x> and @(<x>) }
                 if TryToConsume(_LKLAMMER) then
                  begin
                    lNode:=Factor(true,[]);
                    { inside parentheses a full expression is allowed, see also tests\tbs\tb27517.pas }
                    if CurrentScanner.FToken<>_RKLAMMER then
                      lNode:=SubExpr(opcompare,[efAcceptEqual],lNode);
                    Consume(_RKLAMMER);
                  end
                 else
                  lNode:=Factor(true,[]);
                 if (CurrentScanner.FToken in postfixoperator_tokens) and
                   { TP7 ugliness: @proc^ is parsed as (@proc)^, but @notproc^
                     is parsed as @(notproc^) }
                    not
                    (
                     (m_tp_procvar in CurrentSettings.ModeSwitches) and
                     (CurrentScanner.FToken=_CARET) and (lNode.nodetype=loadn) and (TLoadNode(lNode).SymTableEntry.typ=ProcSym)
                    )
                   then
                  begin
                    lAgain:=true;
                    PostfixOperators(lNode,lAgain,AGetAddr);
                  end;
                 GotAddrN:=false;
                 lNode:=CAddrNode.Create(lNode);
                 lNode.fileinfo:=lFilePos;
                 if cs_typed_addresses in CurrentSettings.LocalSwitches then
                   include(TAddrNode(lNode).AddrNodeFlags,anf_typedaddr);
                 { Store the procvar that we are expecting, the
                   addrn will use the information to find the correct
                   procdef or it will return an error }
                 if Assigned(GetProcVarDef) and
                    (TAddrNode(lNode).left.nodetype = loadn) then
                   TAddrNode(lNode).GetProcVarDef:=GetProcVarDef;
                 if (CurrentScanner.FToken in postfixoperator_tokens) then
                  begin
                    lAgain:=true;
                    PostfixOperators(lNode,lAgain,AGetAddr);
                  end;
               end;

             _LKLAMMER :
               begin
                 Consume(_LKLAMMER);
                 lNode:=CompExpr([efAcceptEqual]);
                 Consume(_RKLAMMER);
                 { it's not a good solution
                   but (a+b)^ makes some problems  }
                 if CurrentScanner.FToken in postfixoperator_tokens then
                  begin
                    lAgain:=true;
                    PostfixOperators(lNode,lAgain,AGetAddr);
                  end;
               end;

             _LECKKLAMMER :
               begin
                 Consume(_LECKKLAMMER);
                 lNode:=FactorReadSet;
                 Consume(_RECKKLAMMER);
               end;

             _PLUS :
               begin
                 Consume(_PLUS);
                 lNode:=Factor(false,[]);
                 lNode:=CUnaryPlusNode.Create(lNode);
               end;

             _MINUS :
               begin
                 Consume(_MINUS);
                 if (CurrentScanner.FToken = _INTCONST) and not(m_isolike_unary_minus in CurrentSettings.ModeSwitches) then
                    begin
                      { ugly hack, but necessary to be able to parse }
                      { -9223372036854775808 as int64 (JM)           }
                      CurrentScanner.FPattern := '-'+CurrentScanner.FPattern;
                      lNode:=SubExpr(oppower,[],nil);
                      {  -1 ** 4 should be - (1 ** 4) and not
                         (-1) ** 4
                         This was the reason of tw0869.pas test failure PM }
                      if lNode.nodetype=starstarn then
                        begin
                          if TBinaryNode(lNode).left.nodetype=ordconstn then
                            begin
                              TOrdConstNode(TBinaryNode(lNode).left).Value:=-TOrdConstNode(TBinaryNode(lNode).left).Value;
                              lNode:=CUnaryMinusNode.Create(lNode);
                            end
                          else if TBinaryNode(lNode).left.nodetype=realconstn then
                            begin
                              TRealConstNode(TBinaryNode(lNode).left).NegateValue;
                              lNode:=CUnaryMinusNode.Create(lNode);
                            end
                          else
                            InternalError(20021029);
                        end;
                    end
                 else
                   begin
                     if m_isolike_unary_minus in CurrentSettings.ModeSwitches then
                       lNode:=SubExpr(opmultiply,[],nil)
                     else
                       lNode:=SubExpr(oppower,[],nil);

                     lNode:=CUnaryMinusNode.Create(lNode);
                   end;
               end;

             _OP_NOT :
               begin
                 Consume(_OP_NOT);
                 lNode:=Factor(false,[]);
                 lNode:=CNotNode.Create(lNode);
               end;

             _NIL :
               begin
                 Consume(_NIL);
                 lNode:=CNilNode.Create;
                 { It's really ugly code nil^, but delphi allows it }
                 if CurrentScanner.FToken in [_CARET,_POINT] then
                  begin
                    lAgain:=true;
                    PostfixOperators(lNode,lAgain,AGetAddr);
                  end;
               end;
             _OBJCPROTOCOL:
               begin
                 { The @protocol keyword is used in two ways in Objective-C:
                     1) to declare protocols (~ Object Pascal interfaces)
                     2) to obtain the metaclass (~ Object Pascal) "class of")
                        of a declared protocol
                   This code is for handling the second case. Because of 1),
                   we cannot simply use a system unit symbol.
                 }
                 Consume(_OBJCPROTOCOL);
                 Consume(_LKLAMMER);
                 lNode:=Factor(false,[]);
                 Consume(_RKLAMMER);
                 lNode:=CInlineNode.Create(in_objc_protocol_x,false,lNode);
               end;

             _PROCEDURE,
             _FUNCTION:
               begin
                 if (Block_Type=bt_body) and
                     (m_anonymous_functions in CurrentSettings.ModeSwitches) then
                   begin
                     lFilePos:=CurrentFilePos;
                     lOldProcVarDef:=GetProcVarDef;
                     lOldFuncRefDef:=GetFuncRefDef;
                     GetProcVarDef:=nil;
                     GetFuncRefDef:=nil;
                     lProcDef:=Read_Proc([rpf_anonymous],nil);
                     GetProcVarDef:=lOldProcVarDef;
                     GetFuncRefDef:=lOldFuncRefDef;
                     { assume that we try to get the address except if certain
                       tokens follow that indicate a call }
                     DoProcCall(lProcDef.ProcSym,lProcDef.owner,nil,not (CurrentScanner.FToken in [_POINT,_CARET,_LECKKLAMMER]),
                                  lAgain,lNode,[],nil);
                     { don't allow @<anon func>, but keep the parsing for recovery }
                     if (lNode.nodetype<>errorn) and AGetAddr then
                       begin
                         lNode.free;
                         lNode:=CErrorNode.Create;
                         MessagePos(lFilePos,parser_e_illegal_expression);
                       end;
                   end
                 else
                   begin
                     Message(parser_e_illegal_expression);
                     lNode:=CErrorNode.Create;
                     { recover }
                     Consume(CurrentScanner.FToken);
                   end;
               end

             else if not StatementExpr(lNode) then
               begin
                 Message(parser_e_illegal_expression);
                 lNode:=CErrorNode.Create;
                 { recover }
                 Consume(CurrentScanner.FToken);
               end;
           end;
        end;

        { generate error node if no node is created }
        if not Assigned(lNode) then
         begin
{$ifdef EXTDEBUG}
           Comment(VWarning,'factor: p1=nil');
{$endif}
           lNode:=CErrorNode.Create;
           lUpdateFilePos:=true;
         end;

        { get the resultdef for the node if nothing stops us }
        if (not Assigned(lNode.resultdef)) and lDoPostfix then
          begin
            DoTypeCheckPassChanged(lNode,lNodeChanged);
            lUpdateFilePos:=lUpdateFilePos or lNodeChanged;
          end;

        if Assigned(lNode) and
           lUpdateFilePos then
          lNode.fileinfo:=lFilePos;
        Factor:=lNode;
      end;
  {$maxfpuregisters default}

    procedure PostCompExprGenDef(var ADef: TDef);
      var
        lNode : TNode;
        lAgain : Boolean;
      begin
        if not Assigned(ADef) then
          InternalError(2011053001);
        lAgain:=false;
        { handle potential typecasts, etc }
        lNode:=HandleFactorTypeNode(ADef,false,lAgain,nil,false);
        { parse postfix operators }
        PostfixOperators(lNode,lAgain,false);
        if Assigned(lNode) and (lNode.nodetype=typen) then
          ADef:=TTypeNode(lNode).TypeDef
        else
          ADef:=GenErrorDef;
      end;

{****************************************************************************
                             Sub_Expr
****************************************************************************}
    function SubExpr(APrecedence:TOperatorPrecedence;AFlags:TExprFlags;AFactorNode:TNode):TNode;
    {Reads a subexpression while the operators are of the current precedence
     level, or any higher level. Replaces the old term, simple_expr and
     simpl2_expr.}

      function IsTypeNode(ANode:TNode):Boolean;inline;
      { Checks whether the given node is a type node or a VMT node containing a
        typenode. This is used in the code for inline specializations in the
        _LT branch below }
        begin
          Result:=Assigned(ANode) and
                    (
                      (ANode.nodetype=typen) or
                      (
                        (ANode.nodetype=loadvmtaddrn) and
                        (TLoadVMTAddrNode(ANode).left.nodetype=typen)
                      )
                    );
        end;

      function GetTypeDef(ANode:TNode):TDef;inline;
      { This returns the typedef that belongs to the given typenode or
        loadvmtaddrnode. n must not be Nil! }
        begin
          if ANode.nodetype=typen then
            Result:=TTypeNode(ANode).TypeDef
          else
            Result:=TTypeNode(TLoadVMTAddrNode(ANode).left).TypeDef;
        end;

      function GetTypeDef(ASym:TSym):TDef;inline;
        begin
          Result:=nil;
          case ASym.typ of
            TypeSym:
              Result:=TTypeSym(ASym).TypeDef;
            ProcSym:
              if not (sp_generic_dummy in ASym.SymOptions) or (TProcSym(ASym).procdeflist.count>0) then
                Result:=TDef(TProcSym(ASym).procdeflist[0]);
            else
              InternalError(2015092701);
          end;
        end;

      function GetGenericSym(ANode:TNode;out ASym:TSym):Boolean;
        var
          lSearchSymTable : TSymTable;
        begin
          ASym:=nil;
          case ANode.nodetype of
            typen:
              ASym:=TTypeNode(ANode).TypeDef.TypeSym;
            loadvmtaddrn:
              ASym:=TTypeNode(TLoadVMTAddrNode(ANode).left).TypeDef.TypeSym;
            loadn:
              if not SearchSym_With_SymOption(TLoadNode(ANode).SymTableEntry.Name,ASym,lSearchSymTable,sp_generic_dummy) then
                ASym:=nil;
            calln:
              ASym:=TCallNode(ANode).SymTableProcEntry;
            specializen:
              ASym:=TSpecializeNode(ANode).sym;
            { TODO : handle const nodes }
            else
              ;
          end;
          Result:=Assigned(ASym);
        end;

      function GenerateInlineSpecialization(AGenDef:TDef;ANode:TNode;AFilePos:TFilePosInfo;AParsedDef:TDef;AGenSym:TSym;ARightNode:TNode):TNode;
        var
          lAgain,
          lGetAddr,
          lUnitSpecific : Boolean;
          lLoadNode : TNode;
          lSpecializationContext : TSpecializationContext;
          lOriginalGenSym : TSym;
          lStructDef,
          lInheritedDef : TAbstractRecordDef;
          lCallFlags : TCallNodeFlags;
        begin
          if not Assigned(AGenSym) then
            InternalError(2025103101);

          if ANode.nodetype=specializen then
            begin
              lGetAddr:=TSpecializeNode(ANode).GetAddr;
              lLoadNode:=TSpecializeNode(ANode).left;
              lInheritedDef:=TAbstractRecordDef(TSpecializeNode(ANode).InheritedDef);
              lUnitSpecific:=TSpecializeNode(ANode).UnitSpecific;
              TSpecializeNode(ANode).left:=nil;
            end
          else
            begin
              lGetAddr:=false;
              lLoadNode:=nil;
              lInheritedDef:=nil;
              lUnitSpecific:=false;
            end;

          if Assigned(AParsedDef) and Assigned(AGenSym) and Assigned(ARightNode) then
            AGenDef:=GenerateSpecializationPhase1(lSpecializationContext,AGenDef,lUnitSpecific,AParsedDef,AGenSym.realname,AGenSym.owner,ARightNode.fileinfo)
          else
            AGenDef:=GenerateSpecializationPhase1(lSpecializationContext,AGenDef,lUnitSpecific,AGenSym.realname,AGenSym.owner);
          lOriginalGenSym:=AGenSym;
          case AGenDef.typ of
            errordef:
              begin
                lSpecializationContext.free;
                lSpecializationContext:=nil;
                AGenSym:=GenErrorSym;
              end;
            objectdef,
            recorddef,
            procvardef,
            arraydef:
              begin
                AGenDef:=GenerateSpecializationPhase2(lSpecializationContext,TStoredDef(AGenDef),false,'');
                lSpecializationContext.free;
                lSpecializationContext:=nil;
                if AGenDef.typ=errordef then
                  AGenSym:=GenErrorSym
                else
                  AGenSym:=AGenDef.TypeSym;
              end;
            procdef:
              begin
                if not (Block_Type in [bt_body,bt_except]) then
                  begin
                    message(parser_e_illegal_expression);
                    AGenSym:=GenErrorSym;
                  end
                else
                  begin
                    AGenSym:=TProcDef(AGenDef).ProcSym;
                  end;
              end;
            else
              InternalError(2015092702);
          end;
          { the generic parameters are parsed and the specialization is done,
            NameOf uses the generic name }
          NameOfRecordSym(lOriginalGenSym);

          { in case of a class or a record the specialized generic
            is always a classrefdef }
          lAgain:=false;

          if Assigned(lLoadNode) then
            begin
              Result:=lLoadNode;
              TypeCheckPass(Result);
              lStructDef:=lInheritedDef;
              if not Assigned(lStructDef) then
                case Result.resultdef.typ of
                  objectdef,
                  recorddef:
                    begin
                      lStructDef:=TAbstractRecordDef(Result.resultdef);
                    end;
                  classrefdef:
                    begin
                      lStructDef:=TAbstractRecordDef(TClassRefDef(Result.resultdef).PointedDef);
                    end;
                  else
                    InternalError(2015092703);
                end;
              if not (lStructDef.typ in [recorddef,objectdef]) then
                InternalError(2018092101);
              if Assigned(lInheritedDef) then
                begin
                  lCallFlags:=[cnf_inherited];
                  include(CurrentProcInfo.flags,pi_has_inherited);
                end
              else
                lCallFlags:=[];
              DoMemberRead(lStructDef,lGetAddr,AGenSym,Result,lAgain,lCallFlags,lSpecializationContext);
              lSpecializationContext:=nil;
            end
          else
            begin
              if AGenSym.typ=ProcSym then
                begin
                  Result:=nil;
                  { check if it's a method/class method }
                  if IsMemberRead(AGenSym,AGenSym.owner,Result,AParsedDef) then
                    begin
                      { if we are accessing a owner procsym from the nested }
                      { class we need to call it as a class member }
                      if (AGenSym.owner.SymTableType in [ObjectSymtable,recordsymtable]) and
                          Assigned(CurrentStructDef) and (CurrentStructDef<>AParsedDef) and Is_Owned_By(CurrentStructDef,AParsedDef) then
                        Result:=CLoadVMTAddrNode.Create(CTypeNode.Create(AParsedDef));
                      { not srsymtable.symtabletype since that can be }
                      { withsymtable as well                          }
                      if (AGenSym.owner.SymTableType in [ObjectSymtable,recordsymtable]) then
                        begin
                          DoMemberRead(TAbstractRecordDef(AParsedDef),lGetAddr,AGenSym,Result,lAgain,[],lSpecializationContext);
                          lSpecializationContext:=nil;
                        end
                      else
                        { no procsyms in records (yet) }
                        InternalError(2015092704);
                    end
                  else
                    begin
                      { regular procedure/function call }
                      DoProcCall(AGenSym,AGenSym.owner,nil,
                                   (lGetAddr and not(CurrentScanner.FToken in [_CARET,_POINT,_LECKKLAMMER])),
                                   lAgain,Result,[],lSpecializationContext);
                      lSpecializationContext:=nil;
                    end;
                  end
                else
                  { handle potential typecasts, etc }
                  Result:=HandleFactorTypeNode(AGenDef,NameOfActive,lAgain,nil,false);
            end;

          { parse postfix operators, NameOf does not need an instance }
          if PostfixOperators(Result,lAgain,NameOfActive) then
            if Assigned(Result) then
              Result.fileinfo:=AFilePos
            else
              Result:=CErrorNode.Create;

          lSpecializationContext.free;
          lSpecializationContext := nil;
        end;

      function MaybeHandleSpecialization(var ALeftNode,ARightNode:TNode;AFilePos:TFilePosInfo):Boolean;
        var
          lGenSym : TSym;
          lParsedDef,
          lGenDef : TDef;
          lTempNode : TNode;
        begin
          Result:=false;
          { we need to decide whether we have an inline specialization
            (type nodes to the left and right of "<", mode Delphi and
            ">" or "," following) or a normal "<" comparison }
          { TODO : p1 could be a non type if e.g. a variable with the
                   same name is defined in the same unit where the
                   generic is defined (though "same unit" is not
                   necessarily needed) }
          if GetGenericSym(ALeftNode,lGenSym) and
             { Attention: when nested specializations are supported
                          p2 could be a loadn if a "<" follows }
             IsTypeNode(ARightNode) and
              (m_delphi in CurrentSettings.ModeSwitches) and
              { TODO : add _LT, _LSHARPBRACKET for nested specializations }
              (CurrentScanner.FToken in [_GT,_RSHARPBRACKET,_COMMA]) then
            begin
              { this is an inline specialization }

              { retrieve the defs of two nodes }
              if ALeftNode.nodetype=specializen then
                lGenDef:=GetTypeDef(TSpecializeNode(ALeftNode).sym)
              else
                lGenDef:=nil;
              lParsedDef:=GetTypeDef(ARightNode);

              { check the hints for parseddef }
              Check_Hints(lParsedDef.TypeSym,lParsedDef.TypeSym.SymOptions,lParsedDef.TypeSym.DeprecatedMsg,ALeftNode.fileinfo);

              lTempNode:=GenerateInlineSpecialization(lGenDef,ALeftNode,AFilePos,lParsedDef,lGenSym,ARightNode);

              { we don't need these nodes anymore }
              ALeftNode.free;
              ARightNode.free;
              ARightNode := nil;

              ALeftNode:=lTempNode;

              Result:=true;
            end;
        end;

      label
        SubExprStart;
      var
        lLeftNode,lRightNode,lTempNode : TNode;
        lOldToken    : TToken;
        lFilePos : TFilePosInfo;
        lGenDef : TDef;
        lGenSym : TSym;
        lGenList : TFPObjectList;
        lDummyAgain : Boolean;
        lDummySpecializationContext : TSpecializationContext;
      begin
        SubExprStart:
        if APrecedence=highest_precedence then
          begin
            if AFactorNode=nil then
              lLeftNode:=Factor(false,AFlags)
            else
              lLeftNode:=AFactorNode;
          end
        else
          lLeftNode:=SubExpr(succ(APrecedence),AFlags+[efAcceptEqual],AFactorNode);
        repeat
          if (CurrentScanner.FToken in [NOTOKEN..last_operator]) and
             (CurrentScanner.FToken in operator_levels[APrecedence]) and
             ((CurrentScanner.FToken<>_EQ) or (efAcceptEqual in AFlags)) then
           begin
             lOldToken:=CurrentScanner.FToken;
             lFilePos:=CurrentTokenPos;
             Consume(CurrentScanner.FToken);
             if APrecedence=highest_precedence then
               lRightNode:=Factor(false,[])
             else
               lRightNode:=SubExpr(succ(APrecedence),AFlags+[efAcceptEqual],nil);
             case lOldToken of
               _PLUS :
                 lLeftNode:=CAddNode.Create(addn,lLeftNode,lRightNode);
               _MINUS :
                 lLeftNode:=CAddNode.Create(subn,lLeftNode,lRightNode);
               _STAR :
                 lLeftNode:=CAddNode.Create(muln,lLeftNode,lRightNode);
               _SLASH :
                 lLeftNode:=CAddNode.Create(slashn,lLeftNode,lRightNode);
               _EQ:
                 lLeftNode:=CAddNode.Create(EqualN,lLeftNode,lRightNode);
               _GT :
                 lLeftNode:=CAddNode.Create(gtn,lLeftNode,lRightNode);
               _LT :
                 begin
                   if MaybeHandleSpecialization(lLeftNode,lRightNode,lFilePos) then
                     begin
                       { with p1 now set we are in reality directly behind the
                         call to "factor" thus we need to call down to that
                         again }
                       { This is disabled until specializations on the right
                         hand side work as well, because
                         "not working expressions" is better than "half working
                         expressions" }
                       {factornode:=p1;
                       goto SubExprStart;}
                     end
                   else
                     begin
                       { this is a normal "<" comparison }

                       { potential generic types that are followed by a "<": }

                       if lLeftNode.nodetype=specializen then
                         begin
                           lGenList:=TFPObjectList(CurrentModule.GenericDummySyms.find(TSpecializeNode(lLeftNode).sym.name));
                           if Assigned(lGenList) and (lGenList.count>0) then
                             begin
                               lGenSym:=TGenericDummyEntry(lGenList.last).ResolvedSym;
                               Check_Hints(lGenSym,lGenSym.SymOptions,lGenSym.DeprecatedMsg,lLeftNode.fileinfo);

                               lDummyAgain:=false;
                               lDummySpecializationContext:=nil;

                               lTempNode:=FactorHandleSym(lGenSym,
                                                       lGenSym.owner,
                                                       lDummyAgain,
                                                       TSpecializeNode(lLeftNode).GetAddr,
                                                       false,
                                                       AFlags,
                                                       lDummySpecializationContext);

                               if lDummyAgain then
                                 InternalError(2022012201);

                               lLeftNode.free;
                               lLeftNode:=lTempNode;
                             end
                           else
                             begin
                               IdentifierNotFound(TSpecializeNode(lLeftNode).sym.realname);
                               lLeftNode.free;
                               lLeftNode:=CErrorNode.Create;
                             end;
                         end;

                       { a) might not have their resultdef set }
                       if not Assigned(lLeftNode.resultdef) then
                         DoTypeCheckPass(lLeftNode);

                       { b) are not checked whether they are an undefined def,
                            but not a generic parameter }
                       if (lLeftNode.nodetype=typen) and
                           (TTypeNode(lLeftNode).TypeDef.typ=undefineddef) and
                           Assigned(TTypeNode(lLeftNode).TypeDef.TypeSym) and
                           not (sp_generic_para in TTypeNode(lLeftNode).TypeDef.TypeSym.SymOptions) then
                         begin
                           IdentifierNotFound(TTypeNode(lLeftNode).TypeDef.TypeSym.RealName);
                           lLeftNode.Free;
                           lLeftNode:=CErrorNode.Create;
                         end;

                       { c) don't have their hints checked }
                       if IsTypeNode(lLeftNode) then
                         begin
                           lGenDef:=GetTypeDef(lLeftNode);
                           if lGenDef.typ in [objectdef,recorddef,arraydef,procvardef] then
                             Check_Hints(lGenDef.TypeSym,lGenDef.TypeSym.SymOptions,lGenDef.TypeSym.DeprecatedMsg);
                         end;

                       { Note: the second part of the expression will be needed
                               for nested specializations }
                       if IsTypeNode(lRightNode) {and
                           not (current_scanner.token in [_LT, _LSHARPBRACKET])} then
                         begin
                           lGenDef:=GetTypeDef(lRightNode);
                           if lGenDef.typ in [objectdef,recorddef,arraydef,procvardef] then
                             Check_Hints(lGenDef.TypeSym,lGenDef.TypeSym.SymOptions,lGenDef.TypeSym.DeprecatedMsg);
                         end;

                       { create the comparison node for "<" }
                       lLeftNode:=CAddNode.Create(ltn,lLeftNode,lRightNode)
                     end;
                 end;
               _GTE :
                 lLeftNode:=CAddNode.Create(gten,lLeftNode,lRightNode);
               _LTE :
                 lLeftNode:=CAddNode.Create(lten,lLeftNode,lRightNode);
               _SYMDIF :
                 lLeftNode:=CAddNode.Create(symdifn,lLeftNode,lRightNode);
               _STARSTAR :
                 lLeftNode:=CAddNode.Create(starstarn,lLeftNode,lRightNode);
               _OP_AS,
               _OP_IS :
                 begin
                   if (m_delphi in CurrentSettings.ModeSwitches) and
                       (CurrentScanner.FToken in [_LT, _LSHARPBRACKET]) and
                       GetGenericSym(lRightNode,lGenSym) then
                     begin
                       { for now we're handling this as a generic declaration;
                         there could be cases though (because of operator
                         overloading) where this is the wrong decision... }
                       if lGenSym.typ=TypeSym then
                         lGenDef:=TTypeSym(lGenSym).TypeDef
                       else
                         if lGenSym.typ=ProcSym then
                           lGenDef:=TDef(TProcSym(lGenSym).procdeflist[0])
                         else
                           InternalError(2015072401);

                       lTempNode:=GenerateInlineSpecialization(lGenDef,lRightNode,lFilePos,nil,lGenSym,nil);

                       { we don't need the old p2 anymore }
                       lRightNode.Free;

                       lRightNode:=lTempNode;

                       { here we don't need to call back down to "factor", thus
                         no "goto" }
                     end;

                   { now generate the "is" or "as" node }
                   case lOldToken of
                     _OP_AS:
                       lLeftNode:=CAsNode.Create(lLeftNode,lRightNode);
                     _OP_IS:
                       lLeftNode:=CIsNode.Create(lLeftNode,lRightNode);
                     else
                       InternalError(2019050528);
                   end;
                 end;
               _OP_IN :
                 lLeftNode:=CInNode.Create(lLeftNode,lRightNode);
               _OP_OR,
               _PIPE {macpas only} :
                 begin
                   lLeftNode:=CAddNode.Create(orn,lLeftNode,lRightNode);
                   if (lOldToken = _PIPE) then
                     include(TAddNode(lLeftNode).AddNodeFlags,anf_short_bool);
                 end;
               _OP_AND,
               _AMPERSAND {macpas only} :
                 begin
                   lLeftNode:=CAddNode.Create(andn,lLeftNode,lRightNode);
                   if (lOldToken = _AMPERSAND) then
                     include(TAddNode(lLeftNode).AddNodeFlags,anf_short_bool);
                 end;
               _OP_DIV :
                 lLeftNode:=CModDivNode.Create(divn,lLeftNode,lRightNode);
               _OP_NOT :
                 lLeftNode:=CNotNode.Create(lLeftNode);
               _OP_MOD :
                 begin
                   lLeftNode:=CModDivNode.Create(modn,lLeftNode,lRightNode);
                   if m_isolike_mod in CurrentSettings.ModeSwitches then
                     include(TModDivNode(lLeftNode).ModDivNodeFlags,mdnf_isomod);
                 end;
               _OP_SHL :
                 lLeftNode:=CShlShrNode.Create(shln,lLeftNode,lRightNode);
               _OP_SHR :
                 lLeftNode:=CShlShrNode.Create(shrn,lLeftNode,lRightNode);
               _OP_XOR :
                 lLeftNode:=CAddNode.Create(xorn,lLeftNode,lRightNode);
               _ASSIGNMENT :
                 lLeftNode:=CAssignmentNode.Create(lLeftNode,lRightNode);
               _NE :
                 lLeftNode:=CAddNode.Create(unequaln,lLeftNode,lRightNode);
               else
                 InternalError(2019050529);
             end;
             lLeftNode.fileinfo:=lFilePos;
           end
          else
           break;
        until false;
        if (lLeftNode.nodetype=specializen) and
            (CurrentScanner.FToken=_LSHARPBRACKET) and
            (m_delphi in CurrentSettings.ModeSwitches) then
          begin
            lFilePos:=CurrentTokenPos;
            Consume(CurrentScanner.FToken);
            lRightNode:=Factor(false,[]);
            if MaybeHandleSpecialization(lLeftNode,lRightNode,lFilePos) then
              begin
                { with p1 now set we are in reality directly behind the
                  call to "factor" thus we need to call down to that
                  again }
                { This is disabled until specializations on the right
                  hand side work as well, because
                  "not working expressions" is better than "half working
                  expressions" }
                {factornode:=p1;
                goto SubExprStart;}
              end else
                message(parser_e_illegal_expression);
          end;
        SubExpr:=lLeftNode;
      end;


    function CompExpr(AFlags:TExprFlags):TNode;
      var
         lOldAfterAssignment : Boolean;
         lNode : TNode;
      begin
         lOldAfterAssignment:=AfterAssignment;
         AfterAssignment:=true;
         lNode:=SubExpr(opcompare,AFlags,nil);
         { get the resultdef for this expression }
         if not Assigned(lNode.resultdef) then
          DoTypeCheckPass(lNode);
         AfterAssignment:=lOldAfterAssignment;
         CompExpr:=lNode;
      end;


    function Expr(ADoTypeCheck : Boolean) : TNode;

      var
         lLeftNode,lRightNode : TNode;
         lFilePos : TFilePosInfo;
         lOldAfterAssignment,
         lUpdateFilePos          : Boolean;
         lOldFlags : TNodeFlags;
      begin
         lOldAfterAssignment:=AfterAssignment;
         lLeftNode:=SubExpr(opcompare,[efAcceptEqual],nil);
         { get the resultdef for this expression }
         if not Assigned(lLeftNode.resultdef) and
            ADoTypeCheck then
          DoTypeCheckPass(lLeftNode);
         lFilePos:=CurrentTokenPos;
         if CurrentScanner.FToken in [_ASSIGNMENT,_PLUSASN,_MINUSASN,_STARASN,_SLASHASN] then
           AfterAssignment:=true;
         lUpdateFilePos:=true;
         case CurrentScanner.FToken of
           _POINTPOINT :
             begin
                Consume(_POINTPOINT);
                lRightNode:=SubExpr(opcompare,[efAcceptEqual],nil);
                lLeftNode:=CRangeNode.Create(lLeftNode,lRightNode);
             end;
           _ASSIGNMENT :
             begin
                Consume(_ASSIGNMENT);
                if Assigned(lLeftNode.resultdef) then
                  if (lLeftNode.resultdef.typ=procvardef) then
                    GetProcVarDef:=TProcVarDef(lLeftNode.resultdef)
                  else if Is_Invokable(lLeftNode.resultdef) then
                    GetFuncRefDef:=TObjectDef(lLeftNode.resultdef);
                lRightNode:=SubExpr(opcompare,[efAcceptEqual],nil);
                if Assigned(GetProcVarDef) then
                  HandleProcVar(GetProcVarDef,lRightNode)
                else if Assigned(GetFuncRefDef) then
                  HandleFuncRef(GetFuncRefDef,lRightNode);
                GetProcVarDef:=nil;
                GetFuncRefDef:=nil;
                lLeftNode:=CAssignmentNode.Create(lLeftNode,lRightNode);
             end;
           _PLUSASN :
             begin
               if not(cs_support_c_operators in CurrentSettings.ModuleSwitches) then
                 Message(parser_e_coperators_off);
               Consume(_PLUSASN);
               lRightNode:=SubExpr(opcompare,[efAcceptEqual],nil);
               lLeftNode:=GenCStyleOperator(addn,lLeftNode,lRightNode);
            end;
          _MINUSASN :
            begin
               if not(cs_support_c_operators in CurrentSettings.ModuleSwitches) then
                 Message(parser_e_coperators_off);
               Consume(_MINUSASN);
               lRightNode:=SubExpr(opcompare,[efAcceptEqual],nil);
               lLeftNode:=GenCStyleOperator(subn,lLeftNode,lRightNode);
            end;
          _STARASN :
            begin
               if not(cs_support_c_operators in CurrentSettings.ModuleSwitches) then
                 Message(parser_e_coperators_off);
               Consume(_STARASN  );
               lRightNode:=SubExpr(opcompare,[efAcceptEqual],nil);
               lLeftNode:=GenCStyleOperator(muln,lLeftNode,lRightNode);
            end;
          _SLASHASN :
            begin
               if not(cs_support_c_operators in CurrentSettings.ModuleSwitches) then
                 Message(parser_e_coperators_off);
               Consume(_SLASHASN  );
               lRightNode:=SubExpr(opcompare,[efAcceptEqual],nil);
               lLeftNode:=GenCStyleOperator(slashn,lLeftNode,lRightNode);
            end;
          else
            lUpdateFilePos:=false;
         end;
         lOldFlags:=lLeftNode.flags;
         { get the resultdef for this expression }
         if not Assigned(lLeftNode.resultdef) and
            ADoTypeCheck then
          DoTypeCheckPass(lLeftNode);
         { transfer generic parameter flag }
         if nf_generic_para in lOldFlags then
           include(lLeftNode.flags,nf_generic_para);
         AfterAssignment:=lOldAfterAssignment;
         if lUpdateFilePos then
           lLeftNode.fileinfo:=lFilePos;
         Expr:=lLeftNode;
      end;

    function GetIntConst:TConstExprInt;
    {Reads an expression, tries to evaluate it and check if it is an integer
     constant. Then the constant is returned.}
    var
      lNode:TNode;
    begin
      Result:=0;
      lNode:=CompExpr([efAcceptEqual]);
      if not CodeGenError then
       begin
         if (lNode.nodetype<>ordconstn) or
            not(Is_Integer(lNode.resultdef)) then
          Message(parser_e_illegal_expression)
         else
          Result:=TOrdConstNode(lNode).Value;
       end;
      lNode.free;
      lNode := nil;
    end;


    function GetStringConst:String;
    {Reads an expression, tries to evaluate it and checks if it is a string
     constant. Then the constant is returned.}
    var
      lNode:TNode;
      lStringNode : TStringConstNode absolute lNode;
      lWideString : TCompilerWideString;
      lChars : PAnsiChar;
      lLength : Integer;

    begin
      GetStringConst:='';
      lNode:=CompExpr([efAcceptEqual]);
      if lNode.nodetype<>stringconstn then
        begin
          if (lNode.nodetype=ordconstn) and Is_Char(lNode.resultdef) then
            GetStringConst:=Char(TOrdConstNode(lNode).Value.svalue)
          else
            Message(parser_e_illegal_expression);
        end
      else if (TStringConstNode(lNode).ConstStringType in [cst_unicodestring,cst_widestring]) then
         begin
           lWideString:=lStringNode.ValueWS;
           lLength:=GetLengthWideString(lWideString);
           lChars:=GetMem(lLength+1);
           lChars[lLength]:=#0;
           Unicode2ASCII(lWideString,lChars,CurrentSettings.SourceCodePage);
           GetStringConst:=StrPas(lChars);
           FreeMem(lChars);
         end
      else
        GetStringConst:=lStringNode.AsRawByteString;
      lNode.free;
      lNode := nil;
    end;

end.
