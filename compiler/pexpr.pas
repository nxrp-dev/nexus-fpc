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
        ef_accept_equal,
        ef_type_only,
        ef_had_specialize,
        ef_check_attr_suffix
      );
      TExprFlags = set of TExprFlag;

    { reads a whole expression }
    function expr(dotypecheck:boolean) : TNode;

    { reads an expression without assignments and .. }
    function comp_expr(flags:TExprFlags):TNode;

    { reads a single factor }
    function factor(getaddr:boolean;flags:TExprFlags) : TNode;

    procedure string_dec(var def: TDef; allowtypedef: boolean);

    function parse_paras(__colon,__namedpara : boolean;end_of_paras : TToken) : TNode;

    { the ID token has to be consumed before calling this function }
    procedure do_member_read(structh:TAbstractRecordDef;getaddr:boolean;sym:TSym;var p1:TNode;var again:boolean;callflags:TCallNodeFlags;spezcontext:TSpecializationContext);

    function get_intconst:TConstExprInt;
    function get_stringconst:string;

    { Does some postprocessing for a generic type (especially when nested types
      of the specialization are used) }
    procedure post_comp_expr_gendef(var def: TDef);

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
       pass_1,
       nmat,nadd,nmem,nset,ncnv,ninl,ncon,nld,nflw,nbas,nutils,
       { parser }
       Scanner,
       pbase,pinline,ptype,pgenutil,psub,ProcInfo,CPUInfo
       ;

    function sub_expr(pred_level:TOperatorPrecedence;flags:TExprFlags;factornode:TNode):TNode;forward;

    var
       { true, if the inherited call is anonymous }
       anon_inherited : boolean = false;
       { last def found, only used by anon. inherited calls to insert proper type casts }
       srdef : TDef = nil;
       { true while parsing the argument of NameOf }
       nameof_active : boolean = false;
       { last symbol found while parsing the argument of NameOf }
       nameof_sym : TSym = nil;
       { position of the token following nameof_sym }
       nameof_nextpos : TFilePosInfo;

    procedure nameof_record_sym(sym:TSym);
      begin
        if not nameof_active or not Assigned(sym) then
          exit;
        nameof_sym:=sym;
        nameof_nextpos:=CurrentFilePos;
      end;

    { returns the declared name of sym without generic parameters }
    function nameof_symname(sym:TSym):string;
      var
        i : LongInt;
      begin
        if (sym.typ in [absolutevarsym,localvarsym,paravarsym]) and
           (vo_is_funcret in TAbstractVarSym(sym).VarOptions) then
          begin
            { the function result symbols are stored uppercase }
            if vo_is_result in TAbstractVarSym(sym).VarOptions then
              exit('Result');
            if Assigned(sym.owner.DefOwner) and
               (TDef(sym.owner.DefOwner).typ=procdef) then
              exit(TProcDef(sym.owner.DefOwner).ProcSym.realname);
          end;
        { use the declared unit name, e.g. the implicit system unit is stored uppercase }
        if (sym.typ=UnitSym) and
           Assigned(TUnitSym(sym).module) and
           Assigned(TModule(TUnitSym(sym).module).RealModuleName) then
          exit(TModule(TUnitSym(sym).module).RealModuleName^);
        result:=sym.realname;
        for i:=1 to length(result) do
          if result[i] in ['$','<'] then
            begin
              if i>1 then
                SetLength(result,i-1);
              break;
            end;
      end;

    procedure string_dec(var def:TDef; allowtypedef: boolean);
    { reads a string type with optional length }
    { and returns a pointer to the string      }
    { definition                               }
      var
         p : TNode;
      begin
         def:=CShortStringType;
         consume(_STRING);
         if CurrentScanner.token=_LECKKLAMMER then
           begin
             if not(allowtypedef) then
               Message(parser_e_no_local_para_def);
             consume(_LECKKLAMMER);
             p:=comp_expr([ef_accept_equal]);
             if not is_constintnode(p) then
               begin
                 Message(parser_e_illegal_expression);
                 { error recovery }
                 consume(_RECKKLAMMER);
               end
             else
               begin
                { the node is a generic param while parsing a generic def
                  so disable the range checking for the string }
                if parse_generic and
                  (nf_generic_para in p.flags) then
                  TOrdConstNode(p).value:=255;
                if TOrdConstNode(p).value<=0 then
                  begin
                     Message(parser_e_invalid_string_size);
                     TOrdConstNode(p).value:=255;
                  end;
                if TOrdConstNode(p).value>255 then
                  begin
                    { longstring is currently unsupported (CEC)! }
{                    t:=cstringdef.createlong(tordconstnode(p).value))}
                    Message(parser_e_invalid_string_size);
                    TOrdConstNode(p).value:=255;
                    def:=CStringDef.CreateShort(int64(TOrdConstNode(p).value),true);
                  end
                else
                  if TOrdConstNode(p).value<>255 then
                    def:=CStringDef.CreateShort(int64(TOrdConstNode(p).value),true);
                consume(_RECKKLAMMER);
              end;
             p.free;
             p := nil;
           end
          else
            begin
             // string[x] is allowed in system unit since it is a shortstring.
             if cs_compilesystem in CurrentSettings.ModuleSwitches then
               Message(parser_e_nostringaliasinsystem);
              if cs_refcountedstrings in CurrentSettings.LocalSwitches then
                begin
                  if m_default_unicodestring in CurrentSettings.ModeSwitches then
                    def:=CUnicodeStringType
                  else
                    def:=CAnsiStringType
                end
              else
                def:=CShortStringType;
            end;
       end;


    function parse_paras(__colon,__namedpara : boolean;end_of_paras : TToken) : TNode;
      var
         p1,p2,argname : TNode;
         prev_in_args,
         old_named_args_allowed : boolean;
      begin
         if CurrentScanner.token=end_of_paras then
           begin
              parse_paras:=nil;
              exit;
           end;
         { save old values }
         prev_in_args:=in_args;
         old_named_args_allowed:=named_args_allowed;
         { set para parsing values }
         in_args:=true;
         named_args_allowed:=false;
         p2:=nil;
         repeat
           if __namedpara then
             begin
               if CurrentScanner.token=_COMMA then
                 begin
                   { empty parameter }
                   p2:=CCallParaNode.create(CNothingNode.create,p2);
                 end
               else
                 begin
                   named_args_allowed:=true;
                   p1:=comp_expr([ef_accept_equal]);
                   named_args_allowed:=false;
                   if found_arg_name then
                     begin
                       argname:=p1;
                       p1:=comp_expr([ef_accept_equal]);
                       p2:=CCallParaNode.create(p1,p2);
                       TCallParaNode(p2).parametername:=argname;
                     end
                   else
                     p2:=CCallParaNode.create(p1,p2);
                   found_arg_name:=false;
                 end;
             end
           else
             begin
               p1:=comp_expr([ef_accept_equal]);
               p2:=CCallParaNode.create(p1,p2);
             end;
           { it's for the str(l:5,s); }
           if __colon and (CurrentScanner.token=_COLON) then
             begin
               consume(_COLON);
               p1:=comp_expr([ef_accept_equal]);
               p2:=CCallParaNode.create(p1,p2);
               include(TCallParaNode(p2).callparaflags,cpf_is_colon_para);
               if try_to_consume(_COLON) then
                 begin
                   p1:=comp_expr([ef_accept_equal]);
                   p2:=CCallParaNode.create(p1,p2);
                   include(TCallParaNode(p2).callparaflags,cpf_is_colon_para);
                 end
             end;
         until not try_to_consume(_COMMA);
         in_args:=prev_in_args;
         named_args_allowed:=old_named_args_allowed;
         parse_paras:=p2;
      end;


     function gen_c_style_operator(ntyp:TNodeType;p1,p2:TNode) : TNode;
       var
         hdef  : TDef;
         temp  : TTempCreateNode;
         newstatement : TStatementNode;
       begin
         { Properties are not allowed, because the write can
           be different from the read }
         if (nf_isproperty in p1.flags) then
           begin
             Message(type_e_variable_id_expected);
             { We can continue with the loading,
               it'll not create errors. Only the expected
               result can be wrong }
           end;

         if might_have_sideeffects(p1,[]) then
           begin
             TypeCheckPass(p1);
             result:=internalstatements(newstatement);
             hdef:=CPointerDef.getreusable(p1.resultdef);
             temp:=CTempCreateNode.create(hdef,sizeof(PInt),tt_persistent,false);
             addstatement(newstatement,temp);
             addstatement(newstatement,CAssignmentNode.create(CTempRefNode.create(temp),CAddrNode.Create_Internal(p1)));
             addstatement(newstatement,CAssignmentNode.create(
                 CDerefNode.create(CTempRefNode.create(temp)),
                 CAddNode.create(ntyp,
                     CDerefNode.create(CTempRefNode.create(temp)),
                     p2)));
             addstatement(newstatement,CTempDeleteNode.create(temp));
           end
         else
           result:=CAssignmentNode.create(p1,CAddNode.create(ntyp,p1.GetCopy,p2));
       end;


     function statement_syssym(l : TInlineNumber) : TNode;
      var
        p1,p2,paras  : TNode;
        err,
        prev_in_args : boolean;
        def : TDef;
        exit_procinfo: TProcInfo;
        old_nameof_active,
        nameof_ok : boolean;
        old_nameof_sym : TSym;
        old_nameof_nextpos : TFilePosInfo;
      begin
        prev_in_args:=in_args;
        case l of

          in_new_x :
            begin
              if afterassignment or in_args then
               statement_syssym:=new_function
              else
               statement_syssym:=new_dispose_statement(true);
            end;

          in_dispose_x :
            begin
              statement_syssym:=new_dispose_statement(false);
            end;

          in_ord_x,
          in_chr_byte:
            begin
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              consume(_RKLAMMER);
              p1:=geninlinenode(l,false,p1);
              statement_syssym := p1;
            end;

          in_exit :
            begin
              statement_syssym:=nil;
              if try_to_consume(_LKLAMMER) then
                begin
                  if not (m_mac in CurrentSettings.ModeSwitches) then
                    begin
                      if not(try_to_consume(_RKLAMMER)) then
                        begin
                          p1:=comp_expr([ef_accept_equal]);
                          consume(_RKLAMMER);
                          if not Assigned(CurrentProcInfo) or
                             (CurrentProcInfo.procdef.ProcTypeOption in [potype_constructor,potype_destructor]) or
                             is_void(CurrentProcInfo.procdef.ReturnDef) then
                            begin
                              Message(parser_e_void_function);
                              { recovery }
                              p1.free;
                              p1:=nil;
                            end;
                        end
                      else
                        p1:=nil;
                    end
                  else
                    begin
                      { non local exit ? }
                      if CurrentProcInfo.procdef.ProcSym.name<>CurrentScanner.pattern then
                        begin
                          exit_procinfo:=CurrentProcInfo.parent;
                          while Assigned(exit_procinfo) do
                            begin
                              if exit_procinfo.procdef.ProcSym.name=CurrentScanner.pattern then
                                break;
                              exit_procinfo:=exit_procinfo.parent;
                            end;
                          if Assigned(exit_procinfo) then
                            begin
                              if not(Assigned(exit_procinfo.nestedexitlabel)) then
                                begin
                                  include(CurrentProcInfo.flags,pi_has_nested_exit);
                                  exclude(CurrentProcInfo.procdef.ProcOptions,po_inline);
                                  if is_nested_pd(CurrentProcInfo.procdef) then
                                    CurrentProcInfo.set_needs_parentfp(exit_procinfo.procdef.ParaST.SymTableLevel);

                                  exit_procinfo.nestedexitlabel:=CLabelSym.create('$nestedexit');

                                  { the compiler is responsible to define this label }
                                  exit_procinfo.nestedexitlabel.defined:=true;
                                  exit_procinfo.nestedexitlabel.used:=true;

                                  exit_procinfo.nestedexitlabel.JumpBuf:=CLocalVarSym.create('LABEL$_'+exit_procinfo.nestedexitlabel.name,vs_value,Rec_Jmp_Buf,[]);
                                  exit_procinfo.procdef.LocalST.InsertSym(exit_procinfo.nestedexitlabel);
                                  exit_procinfo.procdef.LocalST.InsertSym(exit_procinfo.nestedexitlabel.JumpBuf);
                                end;

                              statement_syssym:=CGotoNode.create(exit_procinfo.nestedexitlabel);
                              TGotoNode(statement_syssym).labelsym:=exit_procinfo.nestedexitlabel;
                            end
                          else
                            Message(parser_e_macpas_exit_wrong_param);
                        end;
                      consume(_ID);
                      consume(_RKLAMMER);
                      p1:=nil;
                    end
                end
              else
                p1:=nil;
              if not Assigned(statement_syssym) then
                statement_syssym:=CExitNode.create(p1);
            end;

          in_break :
            begin
              statement_syssym:=CBreakNode.create
            end;

          in_continue :
            begin
              statement_syssym:=CContinueNode.create
            end;

          in_leave :
            begin
              if m_mac in CurrentSettings.ModeSwitches then
                statement_syssym:=CBreakNode.create
              else
                begin
                  Message1(sym_e_id_not_found, CurrentScanner.orgpattern);
                  statement_syssym:=CErrorNode.create;
                end;
            end;

          in_cycle :
            begin
              if m_mac in CurrentSettings.ModeSwitches then
                statement_syssym:=CContinueNode.create
              else
                begin
                  Message1(sym_e_id_not_found, CurrentScanner.orgpattern);
                  statement_syssym:=CErrorNode.create;
                end;
            end;

          in_typeof_x :
            begin
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              consume(_RKLAMMER);
              if p1.nodetype=typen then
                TTypeNode(p1).allowed:=true;
              { Allow classrefdef, which is required for
                Typeof(self) in static class methods }
              if not(Is_ObjC_Class_Or_Protocol(p1.resultdef)) and
                 ((p1.resultdef.typ = objectdef) or
                  (Assigned(CurrentProcInfo) and
                   ((po_classmethod in CurrentProcInfo.procdef.ProcOptions) or
                    (po_staticmethod in CurrentProcInfo.procdef.ProcOptions)) and
                   (p1.resultdef.typ=classrefdef))) then
               statement_syssym:=geninlinenode(in_typeof_x,false,p1)
              else
               begin
                 Message(parser_e_class_id_expected);
                 p1.free;
                 p1 := nil;
                 statement_syssym:=CErrorNode.create;
               end;
            end;

          in_sizeof_x,
          in_bitsizeof_x :
            begin
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              consume(_RKLAMMER);
              if ((p1.nodetype<>typen) and
                 (
                  (Is_Object(p1.resultdef) and
                   (oo_has_constructor in TObjectDef(p1.resultdef).ObjectOptions)) or
                  is_open_array(p1.resultdef) or
                  is_array_of_const(p1.resultdef) or
                  is_open_string(p1.resultdef)
                 )) or
                 { keep the function call if it is a type parameter to avoid arithmetic errors due to constant folding }
                 is_typeparam(p1.resultdef) then
                begin
                  statement_syssym:=geninlinenode(in_sizeof_x,false,p1);
                  { no packed bit support for these things }
                  if l=in_bitsizeof_x then
                    statement_syssym:=CAddNode.create(muln,statement_syssym,COrdConstNode.create(8,SizeSIntType,true));
                  { type sym is a generic parameter }
                  if Assigned(p1.resultdef.TypeSym) and (sp_generic_para in p1.resultdef.TypeSym.SymOptions) then
                    include(statement_syssym.flags,nf_generic_para);
                end
              else
               begin
                 { allow helpers for SizeOf and BitSizeOf }
                 if p1.nodetype=typen then
                   TTypeNode(p1).helperallowed:=true;
                 if (p1.resultdef.typ=ForwardDef) then
                   Message1(type_e_type_is_not_completly_defined,TForwardDef(p1.resultdef).ToSymName^);
                 if (l = in_sizeof_x) or
                    (not((p1.nodetype = vecn) and
                         is_packed_array(TVecNode(p1).left.resultdef)) and
                     not((p1.nodetype = subscriptn) and
                         is_packed_record_or_object(TSubscriptNode(p1).left.resultdef))) then
                   begin
                     statement_syssym:=genintconstnode(p1.resultdef.size,SizeSIntType);
                     if (l = in_bitsizeof_x) then
                       statement_syssym:=CAddNode.create(muln,statement_syssym,COrdConstNode.create(8,SizeSIntType,true));
                   end
                 else
                   statement_syssym:=genintconstnode(p1.resultdef.PackedBitSize,SizeSIntType);
                 { type def is a struct with generic fields }
                 if df_has_generic_fields in p1.resultdef.DefOptions then
                    include(statement_syssym.flags,nf_generic_para);
                 { p1 not needed !}
                 p1.free;
                 p1 := nil;
               end;
            end;

          in_typeinfo_x,
          in_objc_encode_x,
          in_gettypekind_x,
          in_ismanagedtype_x:
            begin
              if (l in [in_typeinfo_x,in_gettypekind_x,in_ismanagedtype_x]) or
                 (m_objectivec1 in CurrentSettings.ModeSwitches) then
                begin
                  consume(_LKLAMMER);
                  in_args:=true;
                  p1:=comp_expr([ef_accept_equal]);
                  { When reading a class type it is parsed as loadvmtaddrn,
                    typeinfo only needs the type so we remove the loadvmtaddrn }
                  if p1.nodetype=loadvmtaddrn then
                    begin
                      p2:=TLoadVMTAddrNode(p1).left;
                      TLoadVMTAddrNode(p1).left:=nil;
                      p1.free;
                      p1:=p2;
                    end;
                  if p1.nodetype=typen then
                  begin
                    TTypeNode(p1).allowed:=true;
                    { allow helpers for TypeInfo }
                    if l in [in_typeinfo_x,in_gettypekind_x,in_ismanagedtype_x] then
                      TTypeNode(p1).helperallowed:=true;
                  end;
    {              else
                    begin
                       p1.free;
                       p1:=cerrornode.create;
                       Message(parser_e_illegal_parameter_list);
                    end;}
                  consume(_RKLAMMER);
                  p2:=geninlinenode(l,false,p1);
                  statement_syssym:=p2;
                end
              else
                begin
                  Message1(sym_e_id_not_found, CurrentScanner.orgpattern);
                  statement_syssym:=CErrorNode.create;
                end;
            end;

          in_isconstvalue_x:
            begin
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              consume(_RKLAMMER);
              p2:=geninlinenode(l,false,p1);
              statement_syssym:=p2;
            end;

          in_aligned_x,
          in_unaligned_x,
          in_volatile_x:
            begin
              err:=false;
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              p2:=CCallParaNode.create(p1,nil);
              p2:=geninlinenode(l,false,p2);
              consume(_RKLAMMER);
              statement_syssym:=p2;
            end;

          in_assigned_x :
            begin
              err:=false;
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              { When reading a class type it is parsed as loadvmtaddrn,
                typeinfo only needs the type so we remove the loadvmtaddrn }
              if p1.nodetype=loadvmtaddrn then
                begin
                  p2:=TLoadVMTAddrNode(p1).left;
                  TLoadVMTAddrNode(p1).left:=nil;
                  p1.free;
                  p1:=p2;
                end;
              if not CodeGenError then
               begin
                 case p1.resultdef.typ of
                   procdef, { procvar }
                   pointerdef,
                   procvardef,
                   classrefdef : ;
                   objectdef :
                     if not Is_Implicit_Pointer_Object_Type(p1.resultdef) then
                       begin
                         Message(parser_e_illegal_parameter_list);
                         err:=true;
                       end;
                   arraydef :
                     if not is_dynamic_array(p1.resultdef) then
                       begin
                         Message(parser_e_illegal_parameter_list);
                         err:=true;
                       end;
                   else
                     if p1.resultdef.typ<>undefineddef then
                       begin
                         Message(parser_e_illegal_parameter_list);
                         err:=true;
                       end;
                 end;
               end
              else
               err:=true;
              if not err then
               begin
                 p2:=CCallParaNode.create(p1,nil);
                 p2:=geninlinenode(in_assigned_x,false,p2);
               end
              else
               begin
                 p1.free;
                 p1 := nil;
                 p2:=CErrorNode.create;
               end;
              consume(_RKLAMMER);
              statement_syssym:=p2;
            end;

          in_addr_x :
            begin
              consume(_LKLAMMER);
              got_addrn:=true;
              p1:=factor(true,[]);
              { inside parentheses a full expression is allowed, see also tests\tbs\tb27517.pas }
              if CurrentScanner.token<>_RKLAMMER then
                p1:=sub_expr(opcompare,[ef_accept_equal],p1);
              p1:=CAddrNode.create(p1);
              got_addrn:=false;
              consume(_RKLAMMER);
              statement_syssym:=p1;
            end;



          in_ofs_x :
            begin
              consume(_LKLAMMER);
              got_addrn:=true;
              p1:=factor(true,[]);
              { inside parentheses a full expression is allowed, see also tests\tbs\tb27517.pas }
              if CurrentScanner.token<>_RKLAMMER then
                p1:=sub_expr(opcompare,[ef_accept_equal],p1);
              p1:=CAddrNode.create(p1);
              include(TAddrNode(p1).addrnodeflags,anf_ofs);
              got_addrn:=false;
              { Ofs() returns a cardinal/qword, not a pointer }
              inserttypeconv_internal(p1,UIntType);
              consume(_RKLAMMER);
              statement_syssym:=p1;
            end;

          in_seg_x :
            begin
              consume(_LKLAMMER);
              got_addrn:=true;
              p1:=factor(true,[]);
              { inside parentheses a full expression is allowed, see also tests\tbs\tb27517.pas }
              if CurrentScanner.token<>_RKLAMMER then
                p1:=sub_expr(opcompare,[ef_accept_equal],p1);
              p1:=geninlinenode(in_seg_x,false,p1);
              got_addrn:=false;
              consume(_RKLAMMER);
              statement_syssym:=p1;
            end;

          in_high_x,
          in_low_x :
            begin
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              p2:=geninlinenode(l,false,p1);
              consume(_RKLAMMER);
              statement_syssym:=p2;
            end;

          in_succ_x,
          in_pred_x :
            begin
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              p2:=geninlinenode(l,false,p1);
              consume(_RKLAMMER);
              statement_syssym:=p2;
            end;

          in_inc_x,
          in_dec_x :
            begin
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              if try_to_consume(_COMMA) then
                p2:=CCallParaNode.create(comp_expr([ef_accept_equal]),nil)
              else
                p2:=nil;
              p2:=CCallParaNode.create(p1,p2);
              statement_syssym:=geninlinenode(l,false,p2);
              consume(_RKLAMMER);
            end;

          in_slice_x:
            begin
              if not(in_args) then
                begin
                  message(parser_e_illegal_slice);
                  consume(_LKLAMMER);
                  in_args:=true;
                  comp_expr([ef_accept_equal]).free; // no nil needed
                  if try_to_consume(_COMMA) then
                    comp_expr([ef_accept_equal]).free; // no nil needed
                  statement_syssym:=CErrorNode.create;
                  consume(_RKLAMMER);
                end
              else
                begin
                  consume(_LKLAMMER);
                  in_args:=true;
                  p1:=comp_expr([ef_accept_equal]);
                  Consume(_COMMA);
                  if not(CodeGenError) then
                    p2:=CCallParaNode.create(comp_expr([ef_accept_equal]),nil)
                  else
                    p2:=CErrorNode.create;
                  p2:=CCallParaNode.create(p1,p2);
                  statement_syssym:=geninlinenode(l,false,p2);
                  consume(_RKLAMMER);
                end;
            end;

          in_initialize_x:
            begin
              statement_syssym:=inline_initialize;
            end;

          in_finalize_x:
            begin
              statement_syssym:=inline_finalize;
            end;

          in_copy_x:
            begin
              statement_syssym:=inline_copy;
            end;

          in_concat_x :
            begin
              statement_syssym:=inline_concat;
            end;

          in_read_x,
          in_readln_x,
          in_readstr_x:
            begin
              if try_to_consume(_LKLAMMER) then
               begin
                 paras:=parse_paras(false,false,_RKLAMMER);
                 consume(_RKLAMMER);
               end
              else
               paras:=nil;
              p1:=geninlinenode(l,false,paras);
              statement_syssym := p1;
            end;

          in_setlength_x:
            begin
              statement_syssym := inline_setlength;
            end;

          in_objc_selector_x:
            begin
              if (m_objectivec1 in CurrentSettings.ModeSwitches) then
                begin
                  consume(_LKLAMMER);
                  in_args:=true;
                  { don't turn procsyms into calls (getaddr = true) }
                  p1:=factor(true,[]);
                  p2:=geninlinenode(l,false,p1);
                  consume(_RKLAMMER);
                  statement_syssym:=p2;
                end
              else
                begin
                  Message1(sym_e_id_not_found, CurrentScanner.orgpattern);
                  statement_syssym:=CErrorNode.create;
                end;
            end;

          in_length_x:
            begin
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              p2:=geninlinenode(l,false,p1);
              consume(_RKLAMMER);
              statement_syssym:=p2;
            end;

          in_write_x,
          in_writeln_x,
          in_writestr_x :
            begin
              if try_to_consume(_LKLAMMER) then
               begin
                 paras:=parse_paras(true,false,_RKLAMMER);
                 consume(_RKLAMMER);
               end
              else
               paras:=nil;
              p1 := geninlinenode(l,false,paras);
              statement_syssym := p1;
            end;

          in_str_x_string :
            begin
              consume(_LKLAMMER);
              paras:=parse_paras(true,false,_RKLAMMER);
              consume(_RKLAMMER);
              p1 := geninlinenode(l,false,paras);
              statement_syssym := p1;
            end;

          in_val_x:
            Begin
              consume(_LKLAMMER);
              in_args := true;
              p1:= CCallParaNode.create(comp_expr([ef_accept_equal]), nil);
              consume(_COMMA);
              p2 := CCallParaNode.create(comp_expr([ef_accept_equal]),p1);
              if try_to_consume(_COMMA) then
                p2 := CCallParaNode.create(comp_expr([ef_accept_equal]),p2);
              consume(_RKLAMMER);
              p2 := geninlinenode(l,false,p2);
              statement_syssym := p2;
            End;

          in_include_x_y,
          in_exclude_x_y :
            begin
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              consume(_COMMA);
              p2:=comp_expr([ef_accept_equal]);
              statement_syssym:=geninlinenode(l,false,CCallParaNode.create(p1,CCallParaNode.create(p2,nil)));
              consume(_RKLAMMER);
            end;

          in_pack_x_y_z,
          in_unpack_x_y_z :
            begin
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              consume(_COMMA);
              p2:=comp_expr([ef_accept_equal]);
              consume(_COMMA);
              paras:=comp_expr([ef_accept_equal]);
              statement_syssym:=geninlinenode(l,false,CCallParaNode.create(p1,CCallParaNode.create(p2,CCallParaNode.create(paras,nil))));
              consume(_RKLAMMER);
            end;

          in_assert_x_y :
            begin
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              if try_to_consume(_COMMA) then
                 p2:=comp_expr([ef_accept_equal])
              else
               begin
                 { then insert an empty string }
                 p2:=CStringConstNode.createstr('');
               end;
              statement_syssym:=geninlinenode(l,false,CCallParaNode.create(p1,CCallParaNode.create(p2,nil)));
              consume(_RKLAMMER);
            end;
          in_get_frame:
            begin
              statement_syssym:=geninlinenode(l,false,nil);
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
              consume(_LKLAMMER);
              in_args:=true;
              def:=nil;
              single_type(def,[stoAllowSpecialization]);
              statement_syssym:=CErrorNode.create;
              if def<>GenErrorDef then
                { "type expected" error is already done by single_type }
                if def.typ=ForwardDef then
                  Message1(type_e_type_is_not_completly_defined,TForwardDef(def).ToSymName^)
                else
                  begin
                    statement_syssym.free;
                    statement_syssym:=geninlinenode(in_default_x,false,CTypeNode.create(def));
                  end;
              { consume the right bracket here for a nicer error position }
              consume(_RKLAMMER);
            end;

          in_nameof_x:
            begin
              consume(_LKLAMMER);
              in_args:=true;
              { save the state: e.g. NameOf(TGen<byte>) may parse NameOf while specializing }
              old_nameof_active:=nameof_active;
              old_nameof_sym:=nameof_sym;
              old_nameof_nextpos:=nameof_nextpos;
              nameof_active:=true;
              nameof_sym:=nil;
              { only an identifier or a dotted identifier chain is allowed }
              nameof_ok:=CurrentScanner.token=_ID;
              if CurrentScanner.token=_RKLAMMER then
                { NameOf() }
                p1:=CNothingNode.create
              else
                { getaddr: do not turn a procedure into a call }
                p1:=factor(true,[]);
              if CurrentScanner.token<>_RKLAMMER then
                begin
                  { e.g. inline specialization TBird<Boolean> }
                  p1:=sub_expr(opcompare,[ef_accept_equal],p1);
                  if p1.nodetype in [addn,subn,muln,slashn,divn,modn,symdifn,starstarn,
                      equaln,unequaln,ltn,lten,gtn,gten,inn,isn,asn,orn,andn,xorn,
                      shln,shrn,notn,assignn] then
                    nameof_ok:=false;
                end;
              { the last found identifier must be directly followed by ")" }
              nameof_ok:=nameof_ok and
                Assigned(nameof_sym) and
                (nameof_sym.typ<>errorsym) and
                (nameof_nextpos.line=CurrentFilePos.line) and
                (nameof_nextpos.column=CurrentFilePos.column) and
                (nameof_nextpos.fileindex=CurrentFilePos.fileindex) and
                (nameof_nextpos.moduleindex=CurrentFilePos.moduleindex);
              if nameof_ok then
                statement_syssym:=CStringConstNode.createstr(nameof_symname(nameof_sym))
              else
                begin
                  if p1.nodetype<>errorn then
                    Message(parser_e_illegal_expression);
                  statement_syssym:=CErrorNode.create;
                end;
              p1.free;
              nameof_active:=old_nameof_active;
              nameof_sym:=old_nameof_sym;
              nameof_nextpos:=old_nameof_nextpos;
              consume(_RKLAMMER);
            end;

          in_setstring_x_y_z:
            begin
              statement_syssym := inline_setstring;
            end;

          in_delete_x_y_z:
            begin
              statement_syssym:=inline_delete;
            end;

          in_insert_x_y_z:
            begin
              statement_syssym:=inline_insert;
            end;
          in_const_eh_return_data_regno:
            begin
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              p2:=geninlinenode(l,true,p1);
              consume(_RKLAMMER);
              statement_syssym:=p2;
            end;

          in_atomic_inc,
          in_atomic_dec:
            begin
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              if try_to_consume(_COMMA) then
                begin
                  p2:=CCallParaNode.create(comp_expr([ef_accept_equal]),nil);
                end
              else
                p2:=nil;
              statement_syssym:=geninlinenode(l,false,CCallParaNode.create(p1,p2));
              consume(_RKLAMMER);
            end;

          in_atomic_xchg:
            begin
              consume(_LKLAMMER);
              in_args:=true;
              p1:=comp_expr([ef_accept_equal]);
              consume(_COMMA);
              p2:=comp_expr([ef_accept_equal]);
              statement_syssym:=geninlinenode(l,false,CCallParaNode.create(p1,CCallParaNode.create(p2,nil)));
              consume(_RKLAMMER);
            end;

          in_atomic_cmp_xchg:
            begin
              consume(_LKLAMMER);
              in_args:=true;
              paras:=CCallParaNode.create(comp_expr([ef_accept_equal]),nil);
              consume(_COMMA);
              TCallParaNode(paras).right:=CCallParaNode.create(comp_expr([ef_accept_equal]),nil);
              consume(_COMMA);
              TCallParaNode(TCallParaNode(paras).right).right:=CCallParaNode.create(comp_expr([ef_accept_equal]),nil);
              if try_to_consume(_COMMA) then
                begin
                  TCallParaNode(TCallParaNode(TCallParaNode(paras).right).right).right:=CCallParaNode.create(comp_expr([ef_accept_equal]),nil);
                end;
              statement_syssym:=geninlinenode(l,false,paras);
              consume(_RKLAMMER);
            end;

          else
            InternalError(15);

        end;
        in_args:=prev_in_args;
      end;


    function maybe_load_methodpointer(st:TSymTable;var p1:TNode):boolean;
      var
        pd: TProcDef;
      begin
        maybe_load_methodpointer:=false;
        if not Assigned(p1) then
         begin
           case st.SymTableType of
             withsymtable :
               begin
                 if (st.DefOwner.typ=objectdef) then
                   p1:=TNode(TWithSymTable(st).WithRefNode).GetCopy;
               end;
             ObjectSymtable,
             recordsymtable:
               begin
                 { Escape nested procedures }
                 if Assigned(CurrentProcInfo) then
                   begin
                     pd:=CurrentProcInfo.get_normal_proc.procdef;
                     { We are calling from the static class method which has no self node }
                     if Assigned(pd) and pd.No_Self_Node then
                       if st.SymTableType=recordsymtable then
                         p1:=CTypeNode.create(pd.struct)
                       else
                         p1:=CLoadVMTAddrNode.create(CTypeNode.create(pd.struct))
                     else
                       p1:=load_self_node;
                   end
                 else
                   p1:=load_self_node;
                 { don't try to call the invokable again }
                 if is_invokable(TDef(st.DefOwner)) then
                   include(p1.flags,nf_load_procvar);
                 { We are calling a member }
                 maybe_load_methodpointer:=true;
               end;
             else
               ;
           end;
         end;
      end;


    { reads the parameter for a subroutine call }
    procedure do_proc_call(sym:TSym;st:TSymTable;obj:TAbstractRecordDef;getaddr:boolean;var again : boolean;var p1:TNode;callflags:TCallNodeFlags;spezcontext:TSpecializationContext);
      var
         membercall,
         prevafterassn : boolean;
         i        : integer;
         para,p2  : TNode;
         currpara : TParaVarSym;
         aprocdef : TProcDef;
      begin
         prevafterassn:=afterassignment;
         afterassignment:=false;
         membercall:=false;
         aprocdef:=nil;

         { when it is a call to a member we need to load the
           methodpointer first
         }
         membercall:=maybe_load_methodpointer(st,p1);

         { When we are expecting a procvar we also need
           to get the address in some cases }
         if Assigned(getprocvardef) or Assigned(getfuncrefdef) then
          begin
            if (Block_Type=bt_const) or
               getaddr then
             begin
               if Assigned(getfuncrefdef) then
                 aprocdef:=TProcSym(sym).Find_ProcDef_ByFuncRefDef(getfuncrefdef)
               else
                 aprocdef:=TProcSym(sym).Find_ProcDef_ByProcVarDef(getprocvardef);
               getaddr:=true;
             end
            else
             if ((m_tp_procvar in CurrentSettings.ModeSwitches) or
                 (m_mac_procvar in CurrentSettings.ModeSwitches)) and
                not(CurrentScanner.token in [_CARET,_POINT,_LKLAMMER]) then
              begin
                if Assigned(getfuncrefdef) then
                  aprocdef:=TProcSym(sym).Find_ProcDef_ByFuncRefDef(getfuncrefdef)
                else
                  aprocdef:=TProcSym(sym).Find_ProcDef_ByProcVarDef(getprocvardef);
                if Assigned(aprocdef) then
                 getaddr:=true;
              end;
          end;

         { only need to get the address of the procedure? Check token because
           in the case of opening parenthesis is possible to get pointer to
           function result (lack of checking for token was the reason of
           tw10933.pas test failure) }
         if getaddr and (CurrentScanner.token<>_LKLAMMER) then
           begin
             { for now we don't support pointers to generic functions, but since
               this is only temporary we use a non translated message }
             if Assigned(spezcontext) then
               begin
                 if nameof_active then
                   { NameOf(GenericFunc<T>) only needs the name }
                   p1:=CNothingNode.create
                 else
                   begin
                     comment(VError, 'Pointers to generics functions not implemented');
                     p1:=CErrorNode.create;
                   end;
                 spezcontext.free;
                 spezcontext := nil;
                 exit;
               end;

             { Retrieve info which procvar to call. For tp_procvar the
               aprocdef is already loaded above so we can reuse it }
             if not Assigned(aprocdef) and
                Assigned(getprocvardef) then
               aprocdef:=TProcSym(sym).Find_ProcDef_ByProcVarDef(getprocvardef);
             if not Assigned(aprocdef) and
                Assigned(getfuncrefdef) then
               aprocdef:=TProcSym(sym).Find_ProcDef_ByFuncRefDef(getfuncrefdef);

             { ensure that the correct function is considered as captured }
             if Assigned(CurrentProcInfo) and
                 Assigned(aprocdef) and
                 (aprocdef.ParaST.SymTableLevel<=CurrentProcInfo.procdef.ParaST.SymTableLevel) and
                 (aprocdef.ParaST.SymTableLevel>normal_function_level) and
                 (CurrentProcInfo.procdef.ParaST.SymTableLevel>normal_function_level) then
               CurrentProcInfo.Add_Captured_Sym(sym,aprocdef,CurrentFilePos);

             { generate a methodcallnode or proccallnode }
             { we shouldn't convert things like @tcollection.load }
             p2:=CLoadNode.create_procvar(sym,aprocdef,st);
             if Assigned(p1) then
              begin
                { for loading methodpointer of an inherited function
                  we use self as instance and load the address of
                  the function directly and not through the vmt (PFV) }
                if (cnf_inherited in callflags) then
                  begin
                    include(TLoadNode(p2).loadnodeflags,loadnf_inherited);
                    p1.free;
                    p1:=load_self_node;
                  end;
                if (p1.nodetype<>typen) then
                  TLoadNode(p2).set_mp(p1)
                else
                  begin
                    TypeCheckPass(p1);
                    if (p1.resultdef.typ=classrefdef) and
                       (
                         Assigned(getprocvardef) or
                         Assigned(getfuncrefdef)
                       ) then
                      begin
                        p1:=CLoadVMTAddrNode.create(p1);
                        TLoadNode(p2).set_mp(p1);
                      end
                    else if (p1.resultdef.typ=objectdef) then
                      { so we can create the correct  method pointer again in case
                        this is a "objectprocvar:=@classname.method" expression }
                      TLoadNode(p2).SymTable:=TObjectDef(p1.resultdef).SymTable
                    else
                      p1.free; // no nil needed
                  end;
              end;
             p1:=p2;

             { no postfix operators }
             again:=false;
           end
         else
           begin
             para:=nil;
             if anon_inherited then
              begin
                if not Assigned(CurrentProcInfo) then
                  InternalError(200305054);
                for i:=0 to CurrentProcInfo.procdef.paras.count-1 do
                  begin
                    currpara:=TParaVarSym(CurrentProcInfo.procdef.paras[i]);
                    if not(vo_is_hidden_para in currpara.VarOptions) then
                      begin
                        { inheritance by msgint? }
                        if Assigned(srdef) then
                          { anonymous inherited via msgid calls only require a var parameter for
                            both methods, so we need some type casting here }
                          para:=CCallParaNode.create(CTypeConvNode.Create_Internal(CTypeConvNode.Create_Internal(
                            CLoadNode.create(currpara,currpara.owner),CFormalType),TParaVarSym(TProcDef(srdef).paras[i]).vardef),
                          para)
                        else
                          para:=CCallParaNode.create(CLoadNode.create(currpara,currpara.owner),para);
                      end;
                 end;
              end
             else
              begin
                if try_to_consume(_LKLAMMER) then
                 begin
                   para:=parse_paras(false,false,_RKLAMMER);
                   consume(_RKLAMMER);
                 end;
              end;
             { indicate if this call was generated by a member and
               no explicit self is used, this is needed to determine
               how to handle a destructor call (PFV) }
             if membercall then
               include(callflags,cnf_member_call);
             if Assigned(obj) then
               begin
                 if not (st.SymTableType in [ObjectSymtable,recordsymtable]) then
                   InternalError(200310031);
                 p1:=CCallNode.create(para,TProcSym(sym),obj.SymTable,p1,callflags,spezcontext);
               end
             else
               p1:=CCallNode.create(para,TProcSym(sym),st,p1,callflags,spezcontext);
             { in case of calling an anonymous function we already know the concrete
               procdef that is going to be called }
             if (TProcSym(sym).ProcdefList.count=1) and (po_anonymous in TProcDef(TProcSym(sym).procdeflist[0]).ProcOptions) then
               TCallNode(p1).procdefinition:=TProcDef(TProcSym(sym).procdeflist[0]);
           end;
         afterassignment:=prevafterassn;
      end;


    procedure handle_procvar(pv : TProcVarDef;var p2 : TNode);
      var
        hp,hp2 : TNode;
        hpp    : ^TNode;
        currprocdef : TProcDef;
      begin
        if not Assigned(pv) then
         InternalError(200301121);
        if (m_tp_procvar in CurrentSettings.ModeSwitches) or
           (m_mac_procvar in CurrentSettings.ModeSwitches) then
         begin
           hp:=p2;
           hpp:=@p2;
           while Assigned(hp) and
                 (hp.nodetype=typeconvn) do
            begin
              hp:=TTypeConvNode(hp).left;
              { save original address of the old tree so we can replace the node }
              hpp:=@hp;
            end;
           if (hp.nodetype=calln) and
              { a procvar can't have parameters! }
              not Assigned(TCallNode(hp).left) then
            begin
              currprocdef:=TCallNode(hp).symtableprocentry.Find_ProcDef_ByProcVarDef(pv);
              if Assigned(currprocdef) then
               begin
                 hp2:=CLoadNode.create_procvar(TProcSym(TCallNode(hp).symtableprocentry),currprocdef,TCallNode(hp).symtableproc);
                 if (po_methodpointer in pv.ProcOptions) then
                   TLoadNode(hp2).set_mp(TCallNode(hp).methodpointer.GetCopy);
                 hp.free;
                 hp := nil;
                 { replace the old callnode with the new loadnode }
                 hpp^:=hp2;
               end;
            end;
         end;
      end;


    procedure handle_funcref(fr:TObjectDef;var p2:TNode);
      var
        hp,hp2 : TNode;
        hpp    : ^TNode;
        currprocdef : TProcDef;
      begin
        if not Assigned(fr) then
          InternalError(2022032401);
        if not is_invokable(fr) then
          InternalError(2022032402);
        if (m_tp_procvar in CurrentSettings.ModeSwitches) or
           (m_mac_procvar in CurrentSettings.ModeSwitches) then
         begin
           hp:=p2;
           hpp:=@p2;
           while Assigned(hp) and
                 (hp.nodetype=typeconvn) do
            begin
              hp:=TTypeConvNode(hp).left;
              { save original address of the old tree so we can replace the node }
              hpp:=@hp;
            end;
           if (hp.nodetype=calln) and
              { a procvar can't have parameters! }
              not Assigned(TCallNode(hp).left) then
            begin
              currprocdef:=TCallNode(hp).symtableprocentry.Find_ProcDef_ByFuncRefDef(fr);
              if Assigned(currprocdef) then
               begin
                 hp2:=CLoadNode.create_procvar(TProcSym(TCallNode(hp).symtableprocentry),currprocdef,TCallNode(hp).symtableproc);
                 hp.free;
                 hp := nil;
                 { replace the old callnode with the new loadnode }
                 hpp^:=hp2;
               end;
            end;
         end;
      end;


    { the following procedure handles the access to a property symbol }
    procedure handle_propertysym(propsym : TPropertySym;st : TSymTable;var p1 : TNode);
      var
         paras : TNode;
         p2    : TNode;
         membercall : boolean;
         callflags  : TCallNodeFlags;
         PropAccessList : TPropAccessList;
         sym: TSym;
      begin
         { NameOf(property) needs neither parameters nor read access }
         if nameof_active and (CurrentScanner.token=_RKLAMMER) then
           begin
             p1.free;
             p1:=CNothingNode.create;
             exit;
           end;
         { property parameters? read them only if the property really }
         { has parameters                                             }
         paras:=nil;
         if (ppo_hasparameters in propsym.PropOptions) then
           begin
             if try_to_consume(_LECKKLAMMER) then
               begin
                 paras:=parse_paras(false,false,_RECKKLAMMER);
                 consume(_RECKKLAMMER);
               end;
           end;
         { indexed property }
         if (ppo_indexed in propsym.PropOptions) then
           begin
             p2:=COrdConstNode.create(propsym.index,propsym.IndexDef,true);
             paras:=CCallParaNode.create(p2,paras);
           end;
         { we need only a write property if a := follows }
         { if not(afterassignment) and not(in_args) then }
         if CurrentScanner.token=_ASSIGNMENT then
           begin
              if propsym.GetPropAccessList(palt_write,PropAccessList) then
                begin
                   sym:=PropAccessList.FirstSym^.sym;
                   case sym.typ of
                     ProcSym :
                       begin
                         callflags:=[];
                         { generate the method call }
                         membercall:=maybe_load_methodpointer(st,p1);
                         if membercall then
                           include(callflags,cnf_member_call);
                         p1:=CCallNode.create(paras,TProcSym(sym),st,p1,callflags,nil);
                         AddSymRef(sym);
                         paras:=nil;
                         consume(_ASSIGNMENT);
                         { read the expression }
                         if propsym.PropDef.typ=procvardef then
                           getprocvardef:=TProcVarDef(propsym.PropDef)
                         else if is_invokable(propsym.PropDef) then
                           getfuncrefdef:=TObjectDef(propsym.PropDef);
                         p2:=comp_expr([ef_accept_equal]);
                         if Assigned(getprocvardef) then
                           handle_procvar(getprocvardef,p2)
                         else if Assigned(getfuncrefdef) then
                           handle_funcref(getfuncrefdef,p2);
                         TCallNode(p1).left:=CCallParaNode.create(p2,TCallNode(p1).left);
                         { mark as property, both the tcallnode and the real call block }
                         include(p1.flags,nf_isproperty);
                         getprocvardef:=nil;
                         getfuncrefdef:=nil;
                       end;
                     FieldVarSym :
                       begin
                         { generate access code }
                         if not handle_staticfield_access(sym,p1) then
                           propaccesslist_to_node(p1,st,PropAccessList);
                         include(p1.flags,nf_isproperty);
                         consume(_ASSIGNMENT);
                         { read the expression }
                         if propsym.PropDef.typ=procvardef then
                           getprocvardef:=TProcVarDef(propsym.PropDef)
                         else if is_invokable(propsym.PropDef) then
                           getfuncrefdef:=TObjectDef(propsym.PropDef);
                         p2:=comp_expr([ef_accept_equal]);
                         if Assigned(getprocvardef) then
                           handle_procvar(getprocvardef,p2)
                         else if Assigned(getfuncrefdef) then
                           handle_funcref(getfuncrefdef,p2);
                         getprocvardef:=nil;
                         getfuncrefdef:=nil;
                         p1:=CAssignmentNode.create(p1,p2);
                      end
                    else
                      begin
                        p1:=CErrorNode.create;
                        Message(parser_e_no_procedure_to_access_property);
                      end;
                  end;
                end
              else
                begin
                   p1:=CErrorNode.create;
                   Message(parser_e_no_procedure_to_access_property);
                end;
           end
         else
           begin
              if propsym.GetPropAccessList(palt_read,PropAccessList) then
                begin
                   sym := PropAccessList.FirstSym^.sym;
                   case sym.typ of
                     FieldVarSym :
                       begin
                         { generate access code }
                         if not handle_staticfield_access(sym,p1) then
                           propaccesslist_to_node(p1,st,PropAccessList);
                         include(p1.flags,nf_isproperty);
                         { catch expressions like "(propx):=1;" }
                         include(p1.flags,nf_no_lvalue);
                       end;
                     ProcSym :
                       begin
                          callflags:=[];
                          { generate the method call }
                          membercall:=maybe_load_methodpointer(st,p1);
                          if membercall then
                            include(callflags,cnf_member_call);
                          p1:=CCallNode.create(paras,TProcSym(sym),st,p1,callflags,nil);
                          paras:=nil;
                          include(p1.flags,nf_isproperty);
                          include(p1.flags,nf_no_lvalue);
                       end
                     else
                       begin
                          p1:=CErrorNode.create;
                          Message(type_e_mismatch);
                       end;
                  end;
                end
              else
                begin
                   { error, no function to read property }
                   p1:=CErrorNode.create;
                   Message(parser_e_no_procedure_to_access_property);
                end;
           end;
        { release paras if not used }
        if Assigned(paras) then
          paras.free; // no nil needed
      end;


    { the ID token has to be consumed before calling this function }
    procedure do_member_read(structh:TAbstractRecordDef;getaddr:boolean;sym:TSym;var p1:TNode;var again:boolean;callflags:TCallNodeFlags;spezcontext:TSpecializationContext);
      var
        isclassref:boolean;
        isrecordtype:boolean;
        isobjecttype:boolean;
        ishelpertype:boolean;
      begin
         if sym=nil then
           begin
              { current_scanner.pattern is still valid unless
              there is another ID just after the ID of sym }
              Message1(sym_e_id_no_member,CurrentScanner.orgpattern);
              p1.free;
              p1:=CErrorNode.create;
              { try to clean up }
              spezcontext.free;
              spezcontext := nil;
              again:=false;
           end
         else
           begin
              nameof_record_sym(sym);
              if Assigned(p1) then
               begin
                 if not Assigned(p1.resultdef) then
                   DoTypeCheckPass(p1);
                 isclassref:=(p1.resultdef.typ=classrefdef);
                 isrecordtype:=(p1.nodetype=typen) and (p1.resultdef.typ=recorddef);
                 isobjecttype:=(p1.nodetype=typen) and Is_Object(p1.resultdef);
                 ishelpertype:=Is_ObjectPascal_Helper(TDef(sym.owner.DefOwner)) and
                               (p1.nodetype=typen) and
                               not Is_ObjectPascal_Helper(p1.resultdef)
                                {and
                               not (cnf_inherited in callflags)};
               end
              else
                begin
                  isclassref:=false;
                  isrecordtype:=false;
                  isobjecttype:=false;
                  ishelpertype:=false;
                end;

              if Assigned(spezcontext) and not (sym.typ=ProcSym) then
                InternalError(2015091801);

              { we assume, that only procsyms and varsyms are in an object }
              { symbol table, for classes, properties are allowed          }
              case sym.typ of
                 ProcSym:
                   begin
                      do_proc_call(sym,sym.owner,structh,
                                   (getaddr and not(CurrentScanner.token in [_CARET,_POINT])),
                                   again,p1,callflags,spezcontext);
                      { we need to know which procedure is called }
                      DoTypeCheckPass(p1);

                      { We are loading... }
                      if p1.nodetype=loadn then
                       begin
                         { an instance method }
                         if not (po_classmethod in TLoadNode(p1).procdef.ProcOptions) and
                             { into a method pointer (not just taking a code address) }
                             not getaddr and
                             { and the selfarg is... }
                             (
                               { either a record/object/helper type, }
                               not Assigned(TLoadNode(p1).left) or
                               { or a class/metaclass type, or a class reference }
                               (TLoadNode(p1).left.resultdef.typ=classrefdef)
                             ) then
                           Message(parser_e_only_class_members_via_class_ref);
                       end
                      { calling using classref? }
                      else if (
                            isclassref or
                            (
                              (isobjecttype or
                               isrecordtype or
                               ishelpertype) and
                              not (cnf_inherited in callflags)
                            )
                          ) and
                         (p1.nodetype=calln) and
                         Assigned(TCallNode(p1).procdefinition) then
                        begin
                          if not isobjecttype then
                            begin
                              if not(po_classmethod in TCallNode(p1).procdefinition.ProcOptions) and
                                 not(TCallNode(p1).procdefinition.ProcTypeOption=potype_constructor) then
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
                              if (TCallNode(p1).procdefinition.ProcTypeOption<>potype_constructor) and
                                 not(po_staticmethod in TCallNode(p1).procdefinition.ProcOptions) and
                                 (not Assigned(CurrentStructDef) or
                                  not def_is_related(CurrentStructDef,structh)) then
                                begin
                                  p1.free;
                                  p1:=CErrorNode.create;
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
                          if Assigned(structh) and
                              (TCallNode(p1).procdefinition.ProcTypeOption=potype_constructor) and
                              (oo_is_abstract in structh.ObjectOptions) and
                              Assigned(TCallNode(p1).methodpointer) and
                              (TCallNode(p1).methodpointer.nodetype=loadvmtaddrn) then
                            Message1(type_w_instance_abstract_class,structh.RTTIName);
                        end
                   end;
                 FieldVarSym:
                   begin
                      if not handle_staticfield_access(sym,p1) then
                        begin
                          if isclassref then
                            if Assigned(p1) and
                              (
                                is_self_node(p1) or
                                (Assigned(CurrentProcInfo) and (CurrentProcInfo.get_normal_proc.procdef.No_Self_Node) and
                                (CurrentProcInfo.procdef.struct=structh))) then
                              Message(parser_e_only_class_members)
                            else
                              Message(parser_e_only_class_members_via_class_ref);
                          p1:=CSubscriptNode.create(sym,p1);
                        end;
                   end;
                 propertysym:
                   begin
                      if isclassref and not (sp_static in sym.SymOptions) then
                        Message(parser_e_only_class_members_via_class_ref);
                      handle_propertysym(TPropertySym(sym),sym.owner,p1);
                   end;
                 TypeSym:
                   begin
                     p1.free;
                     if try_to_consume(_LKLAMMER) then
                      begin
                        p1:=comp_expr([ef_accept_equal]);
                        consume(_RKLAMMER);
                        p1:=CTypeConvNode.create_explicit(p1,TTypeSym(sym).typedef);
                      end
                     else
                       begin
                         p1:=CTypeNode.create(TTypeSym(sym).typedef);
                         if (Is_Class(TTypeSym(sym).typedef) or
                             Is_ObjCClass(TTypeSym(sym).typedef)) and
                            not(Block_Type in [bt_type,bt_const_type,bt_var_type]) then
                           p1:=CLoadVMTAddrNode.create(p1);
                       end;
                   end;
                 constsym:
                   begin
                     p1.free;
                     p1:=genconstsymtree(TConstSym(sym));
                   end;
                 staticvarsym:
                   begin
                     { typed constant is a staticvarsym
                       now they are absolutevarsym }
                     p1.free;
                     p1:=CLoadNode.create(sym,sym.Owner);
                   end;
                 absolutevarsym:
                   begin
                     p1.free;
                     p1:=nil;
                     { typed constants are absolutebarsyms now to handle storage properly }
                     propaccesslist_to_node(p1,nil,TAbsoluteVarSym(sym).ref);
                   end
                 else
                   InternalError(16);
              end;
           end;
      end;


    function handle_specialize_inline_specialization(var srsym:TSym;enforce_unit:boolean;out srsymtable:TSymTable;out spezcontext:TSpecializationContext):boolean;
      var
        spezdef : TDef;
      begin
        result:=false;
        spezcontext:=nil;
        srsymtable:=nil;
        if not Assigned(srsym) then
          message1(sym_e_id_no_member,CurrentScanner.orgpattern)
        else
          if not (srsym.typ in [TypeSym,ProcSym]) then
            message(type_e_type_id_expected)
          else
            begin
              if srsym.typ=TypeSym then
                spezdef:=TTypeSym(srsym).typedef
              else if TProcSym(srsym).procdeflist.count>0 then
                spezdef:=TDef(TProcSym(srsym).procdeflist[0])
              else
                spezdef:=nil;
              spezdef:=generate_specialization_phase1(spezcontext,spezdef,enforce_unit,srsym.realname,srsym.owner);
              case spezdef.typ of
                errordef:
                  begin
                    spezcontext.free;
                    spezcontext:=nil;
                    srsym:=GenErrorSym;
                  end;
                procdef:
                  begin
                    if Block_Type<>bt_body then
                      begin
                        message(parser_e_illegal_expression);
                        spezcontext.free;
                        spezcontext:=nil;
                        srsym:=GenErrorSym;
                      end
                    else
                      begin
                        srsym:=TProcDef(spezdef).ProcSym;
                        srsymtable:=srsym.owner;
                        nameof_record_sym(srsym);
                        result:=true;
                      end;
                  end;
                objectdef,
                recorddef,
                arraydef,
                procvardef:
                  begin
                    spezdef:=generate_specialization_phase2(spezcontext,TStoredDef(spezdef),false,'');
                    spezcontext.free;
                    spezcontext:=nil;
                    if spezdef<>GenErrorDef then
                      begin
                        srsym:=spezdef.TypeSym;
                        srsymtable:=srsym.owner;
                        Check_Hints(srsym,srsym.SymOptions,srsym.DeprecatedMsg);
                        nameof_record_sym(srsym);
                        result:=true;
                      end;
                  end;
                else
                  InternalError(2015070302);
              end;
            end;
      end;


    function handle_factor_typenode(hdef:TDef;getaddr:boolean;var again:boolean;sym:TSym;typeonly:boolean):TNode;
      var
        srsym : TSym;
        srsymtable : TSymTable;
        erroroutresult,
        isspecialize : boolean;
        spezcontext : TSpecializationContext;
        savedfilepos : TFilePosInfo;
      begin
         spezcontext:=nil;
         if sym=nil then
           sym:=hdef.TypeSym;
         { allow Ordinal(Value) for type declarations since it
           can be an enumeration declaration or a set lke:
           (OrdinalType(const1)..OrdinalType(const2) }
         if (not typeonly or is_ordinal(hdef)) and
            try_to_consume(_LKLAMMER) then
          begin
            result:=comp_expr([ef_accept_equal]);
            consume(_RKLAMMER);
            { type casts to class helpers aren't allowed }
            if Is_ObjectPascal_Helper(hdef) then
              Message(parser_e_no_category_as_types)
              { recovery by not creating a conversion node }
            else
              begin
                result:=CTypeConvNode.create_explicit(result,hdef);
                if is_currency(hdef) then
                  { Make sure currency types are correctly scaled }
                  Include(result.flags,nf_is_currency);
              end;
          end
         { not LKLAMMER }
         else if (CurrentScanner.token=_POINT) and
            (Is_Object(hdef) or Is_Record(hdef)) then
           begin
             consume(_POINT);
             { handles calling methods declared in parent objects
               using "parentobject.methodname()" }
             if Assigned(CurrentStructDef) and
                not(getaddr) and
                def_is_related(CurrentStructDef,hdef) then
               begin
                 result:=CTypeNode.create(hdef);
                 TTypeNode(result).TypeSym:=sym;
                 if not (m_delphi in CurrentSettings.ModeSwitches) and
                     (Block_Type in inline_specialization_block_types) and
                     (CurrentScanner.token=_ID) and
                     (CurrentScanner.idtoken=_SPECIALIZE) then
                   begin
                     consume(_ID);
                     if CurrentScanner.token<>_ID then
                       message(type_e_type_id_expected);
                     isspecialize:=true;
                   end
                 else
                   isspecialize:=false;
                 { search also in inherited methods }
                 SearchSym_In_Class(TObjectDef(hdef),TObjectDef(CurrentStructDef),CurrentScanner.pattern,srsym,srsymtable,[ssf_search_helper]);
                 if isspecialize then
                   begin
                     consume(_ID);
                     if not handle_specialize_inline_specialization(srsym,false,srsymtable,spezcontext) then
                       begin
                         result.free;
                         result:=CErrorNode.create;
                       end;
                   end
                 else
                   begin
                     if Assigned(srsym) then
                       Check_Hints(srsym,srsym.SymOptions,srsym.DeprecatedMsg);
                     consume(_ID);
                   end;
                 if result.nodetype<>errorn then
                   do_member_read(TAbstractRecordDef(hdef),false,srsym,result,again,[],spezcontext)
                 else begin
                   spezcontext.free;
                   spezcontext := nil;
                 end;
               end
             else
              begin
                { handles:
                    * @TObject.Load
                    * static methods and variables }
                result:=CTypeNode.create(hdef);
                TTypeNode(result).TypeSym:=sym;
                if not (m_delphi in CurrentSettings.ModeSwitches) and
                    (Block_Type in inline_specialization_block_types) and
                    (CurrentScanner.token=_ID) and
                    (CurrentScanner.idtoken=_SPECIALIZE) then
                  begin
                    consume(_ID);
                    if CurrentScanner.token<>_ID then
                      message(type_e_type_id_expected);
                    isspecialize:=true;
                  end
                else
                  isspecialize:=false;
                erroroutresult:=true;
                { TP allows also @TMenu.Load if Load is only }
                { defined in an ancestor class               }
                srsym:=Search_Struct_Member(TAbstractRecordDef(hdef),CurrentScanner.pattern);
                if isspecialize and Assigned(srsym) then
                  begin
                    consume(_ID);
                    if handle_specialize_inline_specialization(srsym,false,srsymtable,spezcontext) then
                      erroroutresult:=false;
                  end
                else
                  begin
                    if Assigned(srsym) then
                      begin
                        savedfilepos:=CurrentFilePos;
                        consume(_ID);
                        if not (sp_generic_dummy in srsym.SymOptions) or
                            not (CurrentScanner.token in [_LT,_LSHARPBRACKET]) then
                          Check_Hints(srsym,srsym.SymOptions,srsym.DeprecatedMsg,savedfilepos)
                        else
                          result:=CSpecializeNode.create(result,getaddr,srsym,false);
                        erroroutresult:=false;
                      end
                    else
                      Message1(sym_e_id_no_member,CurrentScanner.orgpattern);
                  end;
                if erroroutresult then
                  begin
                    result.free;
                    result:=CErrorNode.create;
                  end
                else
                  if result.nodetype<>specializen then
                    do_member_read(TAbstractRecordDef(hdef),getaddr,srsym,result,again,[],spezcontext);
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
            if Is_Class(hdef) or
               Is_ObjCClass(hdef) then
             begin
               if getaddr and (CurrentScanner.token=_POINT) then
                begin
                  consume(_POINT);
                  { allows @Object.Method }
                  { also allows static methods and variables }
                  result:=CTypeNode.create(hdef);
                  TTypeNode(result).TypeSym:=sym;
                  { TP allows also @TMenu.Load if Load is only }
                  { defined in an ancestor class               }
                  srsym:=Search_Struct_Member(TObjectDef(hdef),CurrentScanner.pattern);
                  if Assigned(srsym) then
                   begin
                     Check_Hints(srsym,srsym.SymOptions,srsym.DeprecatedMsg);
                     consume(_ID);
                     { in case of @Object.Method1.Method2, we have to call
                       Method1 -> create a loadvmtaddr node as self instead of
                       a typen (the typenode would be changed to self of the
                       current method in case Method1 is a constructor, see
                       mantis #24844) }
                     if not(Block_Type in [bt_type,bt_const_type,bt_var_type]) and
                        (srsym.typ=ProcSym) and
                        (CurrentScanner.token in [_CARET,_POINT]) then
                       result:=CLoadVMTAddrNode.create(result);
                     do_member_read(TAbstractRecordDef(hdef),getaddr,srsym,result,again,[],nil);
                   end
                  else
                   begin
                     Message1(sym_e_id_no_member,CurrentScanner.orgpattern);
                     consume(_ID);
                   end;
                end
               else
                begin
                  result:=CTypeNode.create(hdef);
                  TTypeNode(result).TypeSym:=sym;
                  { For a type block we simply return only
                    the type. For all other blocks we return
                    a loadvmt node }
                  if not(Block_Type in [bt_type,bt_const_type,bt_var_type]) then
                    result:=CLoadVMTAddrNode.create(result);
                end;
             end
            else
              begin
                result:=CTypeNode.create(hdef);
                TTypeNode(result).TypeSym:=sym;
              end;
          end;
      end;

{****************************************************************************
                               Factor
****************************************************************************}

{$push} {$R-}{$Q-} { Need to protect against integer overflows }
    function real_const_node_from_pattern(const s:string):TNode;
      var
        d : BestReal;
        code : integer;
      begin
        Val(s,d,code);
        if code<>0 then
         begin
           Message(parser_e_error_in_real);
           d:=1.0;
         end;
        if CurrentSettings.FPUType=fpu_none then
          begin
            Message(parser_e_unsupported_real);
            result:=CErrorNode.create;
            exit;
          end;
        if (CurrentSettings.MinFPConstPrec=S32Real) and
           (d = Single(d)) then
          result:=CRealConstNode.create(d,S32FloatType)
        else if (CurrentSettings.MinFPConstPrec=S64Real) and
                (d = Double(d)) then
          result:=CRealConstNode.create(d,S64FloatType)
        else
          result:=CRealConstNode.create(d,pbestrealtype^);
        TRealConstNode(result).SetCurrencyLiteral(s);
      end;
{$pop}

{---------------------------------------------
               PostFixOperators
---------------------------------------------}

    { returns whether or not p1 has been changed }
    function postfixoperators(var p1:TNode;var again:boolean;getaddr:boolean): boolean;

      { tries to avoid syntax errors after invalid qualifiers }
      procedure recoverconsume_postfixops;
       begin
         repeat
           if not try_to_consume(_CARET) then
             if try_to_consume(_POINT) then
               try_to_consume(_ID)
             else if try_to_consume(_LECKKLAMMER) then
               begin
                 repeat
                   comp_expr([ef_accept_equal]);
                 until not try_to_consume(_COMMA);
                 consume(_RECKKLAMMER);
               end
             else if try_to_consume(_LKLAMMER) and not try_to_consume(_RKLAMMER) then
               begin
                 repeat
                   comp_expr([ef_accept_equal]);
                 until not try_to_consume(_COMMA);
                 consume(_RKLAMMER);
               end
             else
               break;
         until false;
       end;


      procedure handle_variantarray;
       var
         p4 : TNode;
         newstatement : TStatementNode;
         tempresultvariant,
         temp    : TTempCreateNode;
         paras : TCallParaNode;
         newblock : TNode;
         countindices : LongInt;
         elements: TFPList;
         arraydef: TDef;
       begin
         { create statements with call initialize the arguments and
           call fpc_dynarr_setlength }
         newblock:=internalstatements(newstatement);

         { store all indices in a temporary array }
         countindices:=0;
         elements:=TFPList.Create;
         repeat
           p4:=comp_expr([ef_accept_equal]);
           elements.add(p4);
         until not try_to_consume(_COMMA);

         arraydef:=CArrayDef.getreusable(S32IntType,elements.count);
         temp:=CTempCreateNode.create(arraydef,arraydef.size,tt_persistent,false);
         addstatement(newstatement,temp);
         for countindices:=0 to elements.count-1 do
           begin
             addstatement(newstatement,
               CAssignmentNode.create(
                 CVecNode.create(
                   CTempRefNode.create(temp),
                   genintconstnode(countindices)
                 ),
                 TNode(elements[countindices])
               )
             );
           end;
         countindices:=elements.count;
         elements.free;
         elements := nil;

         consume(_RECKKLAMMER);

         { we need only a write access if a := follows }
         if CurrentScanner.token=_ASSIGNMENT then
           begin
             consume(_ASSIGNMENT);
             p4:=comp_expr([ef_accept_equal]);

             { create call to fpc_vararray_put }
             paras:=CCallParaNode.create(COrdConstNode.create
                   (countindices,S32IntType,true),
                CCallParaNode.create(CAddrNode.Create_Internal
               (CVecNode.create(CTempRefNode.create(temp),genintconstnode(0))),
                CCallParaNode.create(CTypeConvNode.Create_Internal(p4,CVariantType),
                CCallParaNode.create(CTypeConvNode.Create_Internal(p1,CVariantType)
                  ,nil))));

             addstatement(newstatement,CCallNode.createintern('fpc_vararray_put',paras));
             addstatement(newstatement,CTempDeleteNode.create(temp));
           end
         else
           begin
             { create temp for result }
             tempresultvariant:=CTempCreateNode.create(CVariantType,CVariantType.size,tt_persistent,true);
             addstatement(newstatement,tempresultvariant);

             { create call to fpc_vararray_get }
             paras:=CCallParaNode.create(COrdConstNode.create
                   (countindices,S32IntType,true),
                CCallParaNode.create(CAddrNode.Create_Internal
               (CTempRefNode.create(temp)),
                CCallParaNode.create(p1,
                CCallParaNode.create(
                    CTempRefNode.create(tempresultvariant)
                  ,nil))));

             addstatement(newstatement,CCallNode.createintern('fpc_vararray_get',paras));
             addstatement(newstatement,CTempDeleteNode.create(temp));
             { the last statement should return the value as
               location and type, this is done be referencing the
               temp and converting it first from a persistent temp to
               normal temp }
             addstatement(newstatement,CTempDeleteNode.create_normal_temp(tempresultvariant));
             addstatement(newstatement,CTempRefNode.create(tempresultvariant));
           end;
         p1:=newblock;
       end;

      function parse_array_constructor(arrdef:TArrayDef): TNode;
        var
          newstatement,assstatement:TStatementNode;
          arrnode:TTempCreateNode;
          temp2:TTempCreateNode;
          assnode:TNode;
          paracount:integer;
        begin
          result:=internalstatements(newstatement);
          { create temp for result }
          arrnode:=CTempCreateNode.create(arrdef,arrdef.size,tt_persistent,true);
          addstatement(newstatement,arrnode);

          paracount:=0;
          { check arguments and create an assignment calls }
          if try_to_consume(_LKLAMMER) then
            begin
              assnode:=internalstatements(assstatement);
              repeat
                { arr[i] := param_i }
                addstatement(assstatement,
                  CAssignmentNode.create(
                    CVecNode.create(
                      CTempRefNode.create(arrnode),
                      COrdConstNode.create(paracount,arrdef.RangeDef,false)),
                    comp_expr([ef_accept_equal])));
                inc(paracount);
              until not try_to_consume(_COMMA);
              consume(_RKLAMMER);
            end
          else
            assnode:=nil;

          { get temp for array of lengths }
          temp2:=CTempCreateNode.create(SIntType,SIntType.size,tt_persistent,false);
          addstatement(newstatement,temp2);

          { one dimensional }
          addstatement(newstatement,CAssignmentNode.create(
              CTempRefNode.create(temp2),
              COrdConstNode.create
                 (paracount,S32IntType,true)));
          { create call to fpc_dynarr_setlength }
          addstatement(newstatement,CCallNode.createintern('fpc_dynarray_setlength',
              CCallParaNode.create(CAddrNode.Create_Internal
                    (CTempRefNode.create(temp2)),
                 CCallParaNode.create(COrdConstNode.create
                    (1,S32IntType,true),
                 CCallParaNode.create(CAddrNode.Create_Internal
                    (CRTTINode.create(TStoredDef(arrdef),initrtti,rdt_normal)),
                 CCallParaNode.create(
                   CTypeConvNode.Create_Internal(
                     CTempRefNode.create(arrnode),VoidPointerType),
                   nil))))

            ));
          { add assignment statements }
          addstatement(newstatement,CTempDeleteNode.create(temp2));
          if Assigned(assnode) then
            addstatement(newstatement,assnode);
          { the last statement should return the value as
            location and type, this is done be referencing the
            temp and converting it first from a persistent temp to
            normal temp }
          addstatement(newstatement,CTempDeleteNode.create_normal_temp(arrnode));
          addstatement(newstatement,CTempRefNode.create(arrnode));
        end;

      function try_type_helper(var node:TNode;def:TDef):boolean;
        var
          srsym : TSym;
          srsymtable : TSymTable;
          n : TNode;
          newstatement : TStatementNode;
          temp : TTempCreateNode;
          extdef : TDef;
        begin
          result:=false;
          if (CurrentScanner.token=_ID) and (Block_Type in [bt_body,bt_general,bt_except,bt_const]) then
            begin
              if not Assigned(def) then
                if node.nodetype=addrn then
                  { always use the pointer type for addr nodes as otherwise
                    we'll have an anonymous pointertype with no name }
                  def:=VoidPointerType
                else
                  def:=node.resultdef;
              result:=Search_ObjectPascal_Helper(def,nil,CurrentScanner.pattern,srsym,srsymtable);
              if result then
                begin
                  if not (srsymtable.SymTableType=objectsymtable) or
                      not Is_ObjectPascal_Helper(TDef(srsymtable.DefOwner)) then
                    InternalError(2013011401);
                  { convert const node to temp node of the extended type }
                  if node.nodetype in (nodetype_const+[addrn]) then
                    begin
                      extdef:=TObjectDef(srsymtable.DefOwner).ExtendedDef;
                      newstatement:=nil;
                      n:=internalstatements(newstatement);
                      temp:=CTempCreateNode.create(extdef,extdef.size,tt_persistent,false);
                      addstatement(newstatement,temp);
                      addstatement(newstatement,CAssignmentNode.create(CTempRefNode.create(temp),node));
                      addstatement(newstatement,CTempDeleteNode.create_normal_temp(temp));
                      addstatement(newstatement,CTempRefNode.create(temp));
                      node:=n;
                      DoTypeCheckPass(node)
                    end;
                  Check_Hints(srsym,srsym.SymOptions,srsym.DeprecatedMsg);
                  consume(_ID);
                  do_member_read(nil,getaddr,srsym,node,again,[],nil);
                end;
            end;
        end;

    var
     protsym  : TPropertySym;
     p2,p3  : TNode;
     srsym  : TSym;
     srsymtable : TSymTable;
     structh    : TAbstractRecordDef;
     { shouldn't be used that often, so the extra overhead is ok to save
       stack space }
     dispatchstring : AnsiString;
     autoderef,
     erroroutp1,
     allowspecialize,
     isspecialize,
     found,
     haderror,
     nodechanged    : boolean;
     calltype: TDispCallType;
     valstr,expstr : string;
     intval : qword;
     code : integer;
     strdef : TDef;
     spezcontext : TSpecializationContext;
     old_current_filepos : TFilePosInfo;
    label
     skipreckklammercheck,
     skippointdefcheck;
    begin
     result:=false;
     again:=true;
     while again do
      begin
        spezcontext:=nil;
        { we need the resultdef }
        DoTypeCheckPassChanged(p1,nodechanged);
        result:=result or nodechanged;

        if CodeGenError then
         begin
           recoverconsume_postfixops;
           exit;
         end;
        { handle token }
        case CurrentScanner.token of
          _CARET:
             begin
               consume(_CARET);

               { support in tp/mac procvar mode procvar^ if the procvar returns a
                 pointer type }
               if ((m_tp_procvar in CurrentSettings.ModeSwitches) or
                   (m_mac_procvar in CurrentSettings.ModeSwitches)) and
                  (p1.resultdef.typ=procvardef) and
                  (TProcVarDef(p1.resultdef).ReturnDef.typ=pointerdef) then
                 begin
                   p1:=CCallNode.create_procvar(nil,p1);
                   TypeCheckPass(p1);
                 end;

               { iso file buf access? }
               if (m_isolike_io in CurrentSettings.ModeSwitches) and
                 (p1.resultdef.typ=filedef) then
                 begin
                   case TFileDef(p1.resultdef).FileTyp of
                     ft_text:
                       begin
                         p1:=CDerefNode.create(CCallNode.createintern('fpc_getbuf_text',CCallParaNode.create(p1,nil)));
                         TypeCheckPass(p1);
                       end;
                     ft_typed:
                       begin
                         p1:=CDerefNode.create(CTypeConvNode.Create_Internal(CCallNode.createintern('fpc_getbuf_typedfile',CCallParaNode.create(p1,nil)),
                           CPointerDef.getreusable(TFileDef(p1.resultdef).TypedFileDef)));
                         TypeCheckPass(p1);
                       end;
                     else
                       InternalError(2019050530);
                   end;
                 end
               else if not(p1.resultdef.typ in [pointerdef,undefineddef]) then
                 begin
                    { ^ as binary operator is a problem!!!! (FK) }
                    again:=false;
                    Message(parser_e_invalid_qualifier);
                    recoverconsume_postfixops;
                    p1.free;
                    p1:=CErrorNode.create;
                 end
               else
                 p1:=CDerefNode.create(p1);
             end;

          _LECKKLAMMER:
             begin
               { support in tp/mac procvar mode procvar[] if the procvar returns an
                 array type }
               if ((m_tp_procvar in CurrentSettings.ModeSwitches) or
                   (m_mac_procvar in CurrentSettings.ModeSwitches)) and
                  (p1.resultdef.typ=procvardef) and
                  (TProcVarDef(p1.resultdef).ReturnDef.typ=arraydef) then
                 begin
                   p1:=CCallNode.create_procvar(nil,p1);
                   TypeCheckPass(p1);
                 end;

               if Is_Class_Or_Interface_Or_Object(p1.resultdef) or
                  Is_DispInterface(p1.resultdef) or
                  Is_Record(p1.resultdef) then
                 begin
                   { default property }
                   protsym:=Search_Default_Property(TAbstractRecordDef(p1.resultdef));
                   if not(Assigned(protsym)) then
                     begin
                        p1.free;
                        p1:=CErrorNode.create;
                        again:=false;
                        message(parser_e_no_default_property_available);
                     end
                   else
                     begin
                       { The property symbol is referenced indirect }
                       protsym.IncRefCount;
                       handle_propertysym(protsym,protsym.owner,p1);
                     end;
                 end
               else
                 begin
                   consume(_LECKKLAMMER);
                   repeat
                     { in all of the cases below, p1 is changed }
                     case p1.resultdef.typ of
                       pointerdef:
                         begin
                            { support delphi autoderef }
                            if (TPointerDef(p1.resultdef).PointedDef.typ=arraydef) and
                               (m_autoderef in CurrentSettings.ModeSwitches) then
                              p1:=CDerefNode.create(p1);
                            p2:=comp_expr([ef_accept_equal]);
                            { Support Pbytevar[0..9] which returns array [0..9].}
                            if try_to_consume(_POINTPOINT) then
                              p2:=CRangeNode.create(p2,comp_expr([ef_accept_equal]));
                            p1:=CVecNode.create(p1,p2);
                         end;
                       variantdef:
                         begin
                           handle_variantarray;
                           { the RECKKLAMMER is already read }
                           goto skipreckklammercheck;
                         end;
                       stringdef :
                         begin
                           p2:=comp_expr([ef_accept_equal]);
                           { Support string[0..9] which returns array [0..9] of char.}
                           if try_to_consume(_POINTPOINT) then
                             p2:=CRangeNode.create(p2,comp_expr([ef_accept_equal]));
                           p1:=CVecNode.create(p1,p2);
                         end;
                       arraydef:
                         begin
                           p2:=comp_expr([ef_accept_equal]);
                           if try_to_consume(_POINTPOINT) then
                             { Support arrayvar[0..9] which returns array [0..9] of arraytype.}
                             p2:=CRangeNode.create(p2,comp_expr([ef_accept_equal]));
                           p1:=CVecNode.create(p1,p2);
                         end;
                       else
                         begin
                           if p1.resultdef.typ<>undefineddef then
                             Message(parser_e_invalid_qualifier);
                           p1.free;
                           p1:=CErrorNode.create;
                           comp_expr([ef_accept_equal]);
                           again:=false;
                         end;
                     end;
                     DoTypeCheckPass(p1);
                   until not try_to_consume(_COMMA);
                   consume(_RECKKLAMMER);
                   { handle_variantarray eats the RECKKLAMMER and jumps here }
                 skipreckklammercheck:
                 end;
             end;

          _POINT :
             begin
               consume(_POINT);
               allowspecialize:=not (m_delphi in CurrentSettings.ModeSwitches) and (Block_Type in inline_specialization_block_types);
               if allowspecialize and (CurrentScanner.token=_ID) and (CurrentScanner.idtoken=_SPECIALIZE) then
                 begin
                   //consume(_ID);
                   isspecialize:=true;
                 end
               else
                 isspecialize:=false;
               autoderef:=false;
               if (p1.resultdef.typ=pointerdef) and
                  (m_autoderef in CurrentSettings.ModeSwitches) and
                  { don't auto-deref objc.id, because then the code
                    below for supporting id.anyobjcmethod isn't triggered }
                  (p1.resultdef<>ObjC_IDType) then
                 begin
                   p1:=CDerefNode.create(p1);
                   DoTypeCheckPass(p1);
                   autoderef:=true;
                 end;
               { procvar.<something> can never mean anything so always
                 try to call it in case it returns a record/object/... }
               maybe_call_procvar(p1,is_invokable(p1.resultdef) and not is_funcref(p1.resultdef));

               if (p1.nodetype=ordconstn) and
                   not is_boolean(p1.resultdef) and
                   not is_enum(p1.resultdef) then
                 begin
                   { type helpers are checked first }
                   if (CurrentScanner.token=_ID) and try_type_helper(p1,nil) then
                     goto skippointdefcheck;
                   { only an "e" or "E" can follow an intconst with a ".", the
                     other case (another intconst) is handled by the scanner }
                   if (CurrentScanner.token=_ID) and (CurrentScanner.pattern[1]='E') then
                     begin
                       haderror:=false;
                       if length(CurrentScanner.pattern)>1 then
                         begin
                           expstr:=copy(CurrentScanner.pattern,2,length(CurrentScanner.pattern)-1);
                           val(expstr,intval,code);
                           if code<>0 then
                             begin
                               haderror:=true;
                               intval:=intval; // Hackfix the "var assigned but never used" note.
                             end;
                         end
                       else
                         expstr:='';
                       consume(CurrentScanner.token);
                       if TOrdConstNode(p1).value.signed then
                         str(TOrdConstNode(p1).value.svalue,valstr)
                       else
                         str(TOrdConstNode(p1).value.uvalue,valstr);
                       valstr:=valstr+'.0E';
                       if expstr='' then
                         case CurrentScanner.token of
                           _MINUS:
                             begin
                               consume(CurrentScanner.token);
                               if CurrentScanner.token=_INTCONST then
                                 begin
                                   valstr:=valstr+'-'+CurrentScanner.pattern;
                                   consume(CurrentScanner.token);
                                 end
                               else
                                 haderror:=true;
                             end;
                           _PLUS:
                             begin
                               consume(CurrentScanner.token);
                               if CurrentScanner.token=_INTCONST then
                                 begin
                                   valstr:=valstr+CurrentScanner.pattern;
                                   consume(CurrentScanner.token);
                                 end
                               else
                                 haderror:=true;
                             end;
                           _INTCONST:
                             begin
                               valstr:=valstr+CurrentScanner.pattern;
                               consume(_INTCONST);
                             end;
                           else
                             haderror:=true;
                         end
                       else
                         valstr:=valstr+expstr;
                       if haderror then
                         begin
                           Message(parser_e_error_in_real);
                           p2:=CErrorNode.create;
                         end
                       else
                         p2:=real_const_node_from_pattern(valstr);
                       p1.free;
                       p1:=p2;
                       again:=false;
                       goto skippointdefcheck;
                     end
                   else
                     begin
                       { just convert the ordconst to a realconst }
                       p2:=CRealConstNode.create(TOrdConstNode(p1).value,pbestrealtype^);
                       p1.free;
                       p1:=p2;
                       again:=false;
                       goto skippointdefcheck;
                     end;
                 end;

               if (p1.nodetype=stringconstn) and (CurrentScanner.token=_ID) then
                 begin
                   strdef:=nil;
                   { the def of a string const is an array }
                   case TStringConstNode(p1).cst_type of
                     cst_conststring:
                       if cs_refcountedstrings in CurrentSettings.LocalSwitches then
                         if m_default_unicodestring in CurrentSettings.ModeSwitches then
                           strdef:=CUnicodeStringType
                         else
                           strdef:=CAnsiStringType
                       else
                         strdef:=CShortStringType;
                     cst_shortstring:
                       strdef:=CShortStringType;
                     cst_ansistring:
                       { use getansistringdef? }
                       strdef:=CAnsiStringType;
                     cst_widestring:
                       strdef:=CWideStringType;
                     cst_unicodestring:
                       strdef:=CUnicodeStringType;
                     cst_longstring:
                       { let's see when someone stumbles upon this...}
                       InternalError(201301111);
                   end;
                   if try_type_helper(p1,strdef) then
                     goto skippointdefcheck;
                 end;

               { this is skipped if label skippointdefcheck is used }
               case p1.resultdef.typ of
                 recorddef:
                   begin
                     if isspecialize or (CurrentScanner.token=_ID) then
                       begin
                         erroroutp1:=true;
                         srsym:=nil;
                         structh:=TAbstractRecordDef(p1.resultdef);
                         if isspecialize then
                           begin
                             { consume the specialize }
                             consume(_ID);
                             if CurrentScanner.token<>_ID then
                               consume(_ID)
                             else
                               begin
                                 SearchSym_In_Record(structh,CurrentScanner.pattern,srsym,srsymtable);
                                 consume(_ID);
                                 if handle_specialize_inline_specialization(srsym,false,srsymtable,spezcontext) then
                                   erroroutp1:=false;
                               end;
                           end
                         else
                           begin
                             SearchSym_In_Record(structh,CurrentScanner.pattern,srsym,srsymtable);
                             if Assigned(srsym) then
                               begin
                                 old_current_filepos:=CurrentFilePos;
                                 consume(_ID);
                                 if not (sp_generic_dummy in srsym.SymOptions) or
                                     not (CurrentScanner.token in [_LT,_LSHARPBRACKET]) then
                                   Check_Hints(srsym,srsym.SymOptions,srsym.DeprecatedMsg,old_current_filepos)
                                 else
                                   p1:=CSpecializeNode.create(p1,getaddr,srsym,false);
                                 erroroutp1:=false;
                               end
                             else
                               begin
                                 Message1(sym_e_id_no_member,CurrentScanner.orgpattern);
                                 { try to clean up }
                                 consume(_ID);
                               end;
                           end;
                         if erroroutp1 then
                           begin
                             p1.free;
                             p1:=CErrorNode.create;
                           end
                         else
                           if p1.nodetype<>specializen then
                             do_member_read(structh,getaddr,srsym,p1,again,[],spezcontext);
                       end
                     else
                     consume(_ID);
                   end;
                 enumdef:
                   begin
                     if CurrentScanner.token=_ID then
                       begin
                         srsym:=TSym(TEnumDef(p1.resultdef).SymTable.Find(CurrentScanner.pattern));
                         if Assigned(srsym) and (srsym.typ=enumsym) and (p1.nodetype=typen) then
                           begin
                             p1.free;
                             Check_Hints(srsym,srsym.SymOptions,srsym.DeprecatedMsg);
                             p1:=genenumnode(TEnumSym(srsym));
                             consume(_ID);
                             nameof_record_sym(srsym);
                           end
                         else
                           if not try_type_helper(p1,nil) then
                             begin
                               p1.free;
                               Message1(sym_e_id_no_member,CurrentScanner.orgpattern);
                               p1:=CErrorNode.create;
                               consume(_ID);
                             end;
                       end
                     else
                       begin
                         p1.free;
                         p1:=CErrorNode.create;
                         consume(_ID);
                       end
                   end;
                 arraydef:
                   begin
                     if is_dynamic_array(p1.resultdef) then
                       begin
                         if CurrentScanner.token=_ID then
                           begin
                             if not try_type_helper(p1,nil) then
                               begin
                                 if p1.nodetype=typen then
                                   begin
                                     if CurrentScanner.pattern='CREATE' then
                                       begin
                                         consume(_ID);
                                         p2:=parse_array_constructor(TArrayDef(p1.resultdef));
                                         p1.free;
                                         p1:=p2;
                                       end
                                     else
                                       begin
                                         Message2(scan_f_syn_expected,'CREATE',CurrentScanner.pattern);
                                         p1.free;
                                         p1:=CErrorNode.create;
                                         consume(_ID);
                                       end;
                                   end
                                 else
                                   begin
                                     Message(parser_e_invalid_qualifier);
                                     p1.free;
                                     p1:=CErrorNode.create;
                                     consume(_ID);
                                   end;
                               end;
                           end
                         else
                           begin
                             Message(parser_e_invalid_qualifier);
                             p1.free;
                             p1:=CErrorNode.create;
                             consume(_ID);
                           end;
                       end
                     else
                       if (CurrentScanner.token<>_ID) or not try_type_helper(p1,nil) then
                         begin
                           Message(parser_e_invalid_qualifier);
                           p1.free;
                           p1:=CErrorNode.create;
                           consume(_ID);
                         end;
                   end;
                  variantdef:
                    begin
                      { dispatch call? }
                      { lhs := v.ident[parameters] -> property get
                        lhs := v.ident(parameters) -> method call
                        v.ident[parameters] := rhs -> property put
                        v.ident(parameters) := rhs -> also property put }
                      if CurrentScanner.token=_ID then
                        begin
                          if not try_type_helper(p1,nil) then
                            begin
                              dispatchstring:=CurrentScanner.orgpattern;
                              consume(_ID);
                              calltype:=dct_method;
                              if try_to_consume(_LKLAMMER) then
                                begin
                                  p2:=parse_paras(false,true,_RKLAMMER);
                                  consume(_RKLAMMER);
                                end
                              else if try_to_consume(_LECKKLAMMER) then
                                begin
                                  p2:=parse_paras(false,true,_RECKKLAMMER);
                                  consume(_RECKKLAMMER);
                                  calltype:=dct_propget;
                                end
                              else
                                p2:=nil;
                              { property setter? }
                              if (CurrentScanner.token=_ASSIGNMENT) and not(afterassignment) then
                                begin
                                  consume(_ASSIGNMENT);
                                  { read the expression }
                                  p3:=comp_expr([ef_accept_equal]);
                                  { concat value parameter too }
                                  p2:=CCallParaNode.create(p3,p2);
                                  p1:=translate_disp_call(p1,p2,dct_propput,dispatchstring,0,VoidType);
                                end
                              else
                              { this is only an approximation
                                setting useresult if not necessary is only a waste of time, no more, no less (FK) }
                              if afterassignment or in_args or (CurrentScanner.token<>_SEMICOLON) then
                                p1:=translate_disp_call(p1,p2,calltype,dispatchstring,0,CVariantType)
                              else
                                p1:=translate_disp_call(p1,p2,calltype,dispatchstring,0,VoidType);
                            end;
                        end
                      else { Error }
                        Consume(_ID);
                     end;
                  classrefdef:
                    begin
                      erroroutp1:=true;
                      if CurrentScanner.token=_ID then
                        begin
                          srsym:=nil;
                          structh:=TObjectDef(TClassRefDef(p1.resultdef).PointedDef);
                          if isspecialize then
                            begin
                              { consume the specialize }
                              consume(_ID);
                              if CurrentScanner.token<>_ID then
                                consume(_ID)
                              else
                                begin
                                  SearchSym_In_Class(TObjectDef(structh),TObjectDef(structh),CurrentScanner.pattern,srsym,srsymtable,[ssf_search_helper]);
                                  consume(_ID);
                                  if handle_specialize_inline_specialization(srsym,false,srsymtable,spezcontext) then
                                    erroroutp1:=false;
                                end;
                            end
                          else
                            begin
                              SearchSym_In_Class(TObjectDef(structh),TObjectDef(structh),CurrentScanner.pattern,srsym,srsymtable,[ssf_search_helper]);
                              if Assigned(srsym) then
                                begin
                                  old_current_filepos:=CurrentFilePos;
                                  consume(_ID);
                                  if not (sp_generic_dummy in srsym.SymOptions) or
                                      not (CurrentScanner.token in [_LT,_LSHARPBRACKET]) then
                                    Check_Hints(srsym,srsym.SymOptions,srsym.DeprecatedMsg,old_current_filepos)
                                  else
                                    p1:=CSpecializeNode.create(p1,getaddr,srsym,false);
                                  erroroutp1:=false;
                                end
                              else
                                begin
                                  Message1(sym_e_id_no_member,CurrentScanner.orgpattern);
                                  { try to clean up }
                                  consume(_ID);
                                end;
                            end;
                          if erroroutp1 then
                            begin
                              p1.free;
                              p1:=CErrorNode.create;
                            end
                          else
                            if p1.nodetype<>specializen then
                              do_member_read(structh,getaddr,srsym,p1,again,[],spezcontext);
                        end
                      else { Error }
                        Consume(_ID);
                    end;
                  objectdef:
                    begin
                      if isspecialize or (CurrentScanner.token=_ID) then
                        begin
                          erroroutp1:=true;
                          srsym:=nil;
                          structh:=TObjectDef(p1.resultdef);
                          if isspecialize then
                            begin
                              { consume the "specialize" }
                              consume(_ID);
                              if CurrentScanner.token<>_ID then
                                consume(_ID)
                              else
                                begin
                                  SearchSym_In_Class(TObjectDef(structh),TObjectDef(structh),CurrentScanner.pattern,srsym,srsymtable,[ssf_search_helper]);
                                  consume(_ID);
                                  if handle_specialize_inline_specialization(srsym,false,srsymtable,spezcontext) then
                                    erroroutp1:=false;
                                end;
                            end
                          else
                            begin
                              SearchSym_In_Class(TObjectDef(structh),TObjectDef(structh),CurrentScanner.pattern,srsym,srsymtable,[ssf_search_helper]);
                              if Assigned(srsym) then
                                begin
                                   old_current_filepos:=CurrentFilePos;
                                   consume(_ID);
                                   if not (sp_generic_dummy in srsym.SymOptions) or
                                       not (CurrentScanner.token in [_LT,_LSHARPBRACKET]) then
                                     Check_Hints(srsym,srsym.SymOptions,srsym.DeprecatedMsg,old_current_filepos)
                                   else
                                     p1:=CSpecializeNode.create(p1,getaddr,srsym,false);
                                   erroroutp1:=false;
                                end
                              else
                                begin
                                   Message1(sym_e_id_no_member,CurrentScanner.orgpattern);
                                   { try to clean up }
                                   consume(_ID);
                                end;
                            end;
                          if erroroutp1 then
                            begin
                              p1.free;
                              p1:=CErrorNode.create;
                            end
                          else
                            if p1.nodetype<>specializen then
                              do_member_read(structh,getaddr,srsym,p1,again,[],spezcontext);
                        end
                      else { Error }
                        Consume(_ID);
                    end;
                  pointerdef:
                    begin
                      if (p1.resultdef=ObjC_IDType) then
                        begin
                          { objc's id type can be used to call any
                            Objective-C method of any Objective-C class
                            type that's currently in scope }
                          if Search_ObjC_Method(CurrentScanner.pattern,srsym,srsymtable) then
                            begin
                              consume(_ID);
                              do_proc_call(srsym,srsymtable,nil,
                                (getaddr and not(CurrentScanner.token in [_CARET,_POINT])),
                                again,p1,[cnf_objc_id_call],nil);
                              { we need to know which procedure is called }
                              DoTypeCheckPass(p1);
                            end
                          else
                            begin
                              consume(_ID);
                              Message(parser_e_methode_id_expected);
                            end;
                        end
                      else
                        begin
                          if not try_type_helper(p1,nil) then
                            begin
                              Message(parser_e_invalid_qualifier);
                              if TPointerDef(p1.resultdef).PointedDef.typ in [recorddef,objectdef,classrefdef] then
                                Message(parser_h_maybe_deref_caret_missing);
                            end;
                        end
                    end;
                  else
                    begin
                      if autoderef then
                        begin
                          { always try with the not dereferenced node }
                          p2:=TDerefNode(p1).left;
                          found:=try_type_helper(p2,nil);
                          if found then
                            begin
                              TDerefNode(p1).left:=nil;
                              p1.free;
                              p1:=p2;
                            end;
                        end
                      else
                        found:=try_type_helper(p1,nil);
                      if not found then
                        begin
                          if p1.resultdef.typ<>undefineddef then
                            Message(parser_e_invalid_qualifier);
                          p1.free;
                          p1:=CErrorNode.create;
                          { Error }
                          consume(_ID);
                        end;
                    end;
               end;
               { processing an ordconstnode avoids the resultdef check }
               skippointdefcheck:
             end;

          else
            begin
              { is this a procedure variable ? }
              if is_invokable(p1.resultdef) and
                  (CurrentScanner.token=_LKLAMMER) then
                begin
                  if not SearchSym_In_Class(TObjectDef(p1.resultdef),TObjectDef(p1.resultdef),method_name_funcref_invoke_find,srsym,srsymtable,[]) then
                    InternalError(2021040202);
                  include(p1.flags,nf_load_procvar);
                  do_proc_call(srsym,srsymtable,TAbstractRecordDef(p1.resultdef),false,again,p1,[],nil);
                end
              else if Assigned(p1.resultdef) and
                 (p1.resultdef.typ=procvardef) then
                begin
                  { Typenode for typecasting or expecting a procvar }
                  if (p1.nodetype=typen) or
                     (
                      Assigned(getprocvardef) and
                      equal_defs(p1.resultdef,getprocvardef)
                     ) or
                     (
                      Assigned(getfuncrefdef) and
                      equal_defs(p1.resultdef,getfuncrefdef)
                     ) then
                    begin
                      if try_to_consume(_LKLAMMER) then
                        begin
                          p1:=comp_expr([ef_accept_equal]);
                          consume(_RKLAMMER);
                          p1:=CTypeConvNode.create_explicit(p1,p1.resultdef);
                        end
                      else
                        again:=false
                    end
                  else
                    begin
                      if try_to_consume(_LKLAMMER) then
                        begin
                          p2:=parse_paras(false,false,_RKLAMMER);
                          consume(_RKLAMMER);
                          p1:=CCallNode.create_procvar(p2,p1);
                          { proc():= is never possible }
                          if CurrentScanner.token=_ASSIGNMENT then
                            begin
                              Message(parser_e_illegal_expression);
                              p1.free;
                              p1:=CErrorNode.create;
                              again:=false;
                            end;
                        end
                      else
                        again:=false;
                    end;
                end
              else
                again:=false;
             end;
        end;

        { we only try again if p1 was changed }
        if again or
           (p1.nodetype=errorn) then
          result:=true;
      end; { while again }
    end;

    function is_member_read(sym: TSym; st: TSymTable; var p1: TNode;
                            out memberparentdef: TDef): boolean;
      var
        hdef : TDef;
      begin
        result:=true;
        memberparentdef:=nil;

        case st.SymTableType of
          ObjectSymtable,
          recordsymtable:
            begin
              memberparentdef:=TDef(st.DefOwner);
              exit;
            end;
          WithSymtable:
            begin
              if Assigned(p1) then
               InternalError(2007012002);

              hdef:=TNode(TWithSymTable(st).WithRefNode).resultdef;
              p1:=TNode(TWithSymTable(st).WithRefNode).GetCopy;

              if not(hdef.typ in [objectdef,classrefdef]) then
                exit;

              if (hdef.typ=classrefdef) then
                hdef:=TClassRefDef(hdef).PointedDef;
              memberparentdef:=hdef;
            end;
          else
            result:=false;
        end;
      end;

  {$maxfpuregisters 0}


    function factor_handle_sym(srsym:TSym;srsymtable:TSymTable;var again:boolean;getaddr:boolean;unit_found:boolean;flags:TExprFlags;var spezcontext:TSpecializationContext):TNode;
      var
        hdef : TDef;
        pd : TProcDef;
        callflags : TCallNodeFlags;
        tmpgetaddr : boolean;
      begin
        hdef:=nil;
        result:=nil;
        case srsym.typ of
          absolutevarsym :
            begin
              if (TAbsoluteVarSym(srsym).AbsTyp=tovar) then
                begin
                  result:=nil;
                  propaccesslist_to_node(result,nil,TAbsoluteVarSym(srsym).ref);
                  result:=CTypeConvNode.create(result,TAbsoluteVarSym(srsym).vardef);
                  include(result.flags,nf_absolute);
                  if TAbsoluteVarSym(srsym).vardef=S64CurrencyType then
                    { If a Currency type is connected to another type, we have
                      to make sure a scalar is never applied }
                    include(result.flags,nf_is_currency);
                end
              else
                result:=CLoadNode.create(srsym,srsymtable);
            end;

          staticvarsym,
          localvarsym,
          paravarsym,
          FieldVarSym :
            begin
              { check if we are reading a field of an object/class/   }
              { record. is_member_read() will deal with withsymtables }
              { if needed.                                            }
              result:=nil;
              if is_member_read(srsym,srsymtable,result,hdef) then
                begin
                  { if the field was originally found in an     }
                  { objectsymtable, it means it's part of self  }
                  { if only method from which it was called is  }
                  { not class static                            }
                  if (srsymtable.SymTableType in [ObjectSymtable,recordsymtable]) then
                    { if we are accessing a owner procsym from the nested }
                    { class we need to call it as a class member          }
                    if Assigned(CurrentStructDef) and
                        (((CurrentStructDef<>hdef) and Is_Owned_By(CurrentStructDef,hdef)) or
                         (sp_static in srsym.SymOptions)) then
                      if srsymtable.SymTableType=recordsymtable then
                        result:=CTypeNode.create(hdef)
                      else
                        result:=CLoadVMTAddrNode.create(CTypeNode.create(hdef))
                    else
                      begin
                        if Assigned(CurrentProcInfo) then
                          begin
                            pd:=CurrentProcInfo.get_normal_proc.procdef;
                            if Assigned(pd) and pd.No_Self_Node then
                              result:=CLoadVMTAddrNode.create(CTypeNode.create(pd.struct))
                            else
                              result:=load_self_node;
                          end
                        else
                          result:=load_self_node;
                      end;
                  { now, if the field itself is part of an objectsymtab }
                  { (it can be even if it was found in a withsymtable,  }
                  {  e.g., "with classinstance do field := 5"), then    }
                  { let do_member_read handle it                        }
                  if (srsym.owner.SymTableType in [ObjectSymtable,recordsymtable]) then
                    do_member_read(TAbstractRecordDef(hdef),getaddr,srsym,result,again,[],nil)
                  else
                    { otherwise it's a regular record subscript }
                    result:=CSubscriptNode.create(srsym,result);
                end
              else
                { regular non-field load }
                result:=CLoadNode.create(srsym,srsymtable);
            end;

          syssym :
            begin
              result:=statement_syssym(TSysSym(srsym).number);
            end;

          TypeSym :
            begin
              hdef:=TTypeSym(srsym).typedef;
              if not Assigned(hdef) then
               begin
                 again:=false;
               end
              else
               begin
                 if (m_delphi in CurrentSettings.ModeSwitches) and
                     (sp_generic_dummy in srsym.SymOptions) and
                     (CurrentScanner.token in [_LT,_LSHARPBRACKET]) then
                   begin
                     if Block_Type in [bt_type,bt_const_type,bt_var_type] then
                       begin
                         if not handle_specialize_inline_specialization(srsym,unit_found,srsymtable,spezcontext) or (srsym.typ=ProcSym) then
                           begin
                             spezcontext.free;
                             spezcontext := nil;
                             result:=CErrorNode.create;
                             if try_to_consume(_LKLAMMER) then
                              begin
                                parse_paras(false,false,_RKLAMMER);
                                consume(_RKLAMMER);
                              end;
                           end
                         else
                           begin
                             if srsym.typ<>TypeSym then
                               InternalError(2015071705);
                             hdef:=TTypeSym(srsym).typedef;
                             result:=handle_factor_typenode(hdef,getaddr,again,srsym,ef_type_only in flags);
                           end;
                       end
                     else
                       result:=CSpecializeNode.create(nil,getaddr,srsym,unit_found)
                   end
                 else
                   begin
                     { We need to know if this unit uses Variants }
                     if ((hdef=CVariantType) or (hdef=COleVariantType)) and
                        not(cs_compilesystem in CurrentSettings.ModuleSwitches) then
                       include(CurrentModule.ModuleFlags,mf_uses_variants);
                     result:=handle_factor_typenode(hdef,getaddr,again,srsym,ef_type_only in flags);
                   end;
               end;
            end;

          enumsym :
            begin
              result:=genenumnode(TEnumSym(srsym));
            end;

          constsym :
            begin
              if TConstSym(srsym).ConstTyp in [constresourcestring,constwresourcestring]then
                begin
                  result:=CLoadNode.create(srsym,srsymtable);
                  DoTypeCheckPass(result);
                  if is_systemunit_unicode then
                    result.resultdef:=CStringDef.CreateUnicode(true)
                  else
                    result.resultdef:=GetAnsiStringDef;
                end
              else
                result:=genconstsymtree(TConstSym(srsym));
            end;

          ProcSym :
            begin
              result:=nil;
              if (m_delphi in CurrentSettings.ModeSwitches) and
                  (sp_generic_dummy in srsym.SymOptions) and
                  (CurrentScanner.token in [_LT,_LSHARPBRACKET]) then
                begin
                  result:=CSpecializeNode.create(nil,getaddr,srsym,unit_found)
                end
              { check if it's a method/class method }
              else if is_member_read(srsym,srsymtable,result,hdef) then
                begin
                  { if we are accessing a owner procsym from the nested }
                  { class we need to call it as a class member          }
                  if (srsymtable.SymTableType in [ObjectSymtable,recordsymtable]) and
                    Assigned(CurrentStructDef) and (CurrentStructDef<>hdef) and Is_Owned_By(CurrentStructDef,hdef) then
                    result:=CLoadVMTAddrNode.create(CTypeNode.create(hdef));
                  { not srsymtable.symtabletype since that can be }
                  { withsymtable as well                          }
                  if (srsym.owner.SymTableType in [ObjectSymtable,recordsymtable]) then
                    begin
                      do_member_read(TAbstractRecordDef(hdef),getaddr,srsym,result,again,[],spezcontext);
                      spezcontext:=nil;
                    end
                  else
                    { no procsyms in records (yet) }
                    InternalError(2007012006);
                end
              else
                begin
                  { regular procedure/function call }
                  if not unit_found then
                    callflags:=[]
                  else
                    callflags:=[cnf_unit_specified];
                  { TP7 ugliness: @proc^ is parsed as (@proc)^,
                    but @notproc^ is parsed as @(notproc^) }
                  if m_tp_procvar in CurrentSettings.ModeSwitches then
                    tmpgetaddr:=getaddr and not(CurrentScanner.token in [_POINT,_LECKKLAMMER])
                  else
                    tmpgetaddr:=getaddr and not(CurrentScanner.token in [_CARET,_POINT,_LECKKLAMMER]);
                  do_proc_call(srsym,srsymtable,nil,tmpgetaddr,
                               again,result,callflags,spezcontext);
                  spezcontext:=nil;
                end;
            end;

          propertysym :
            begin
              result:=nil;
              { property of a class/object? }
              if is_member_read(srsym,srsymtable,result,hdef) then
                begin
                  if (srsymtable.SymTableType in [ObjectSymtable,recordsymtable]) then
                    { if we are accessing a owner procsym from the nested }
                    { class or from a static class method we need to call }
                    { it as a class member                                }
                    if (Assigned(CurrentStructDef) and (CurrentStructDef<>hdef) and Is_Owned_By(CurrentStructDef,hdef)) or
                       (Assigned(CurrentProcInfo) and CurrentProcInfo.get_normal_proc.procdef.No_Self_Node) then
                      begin
                        result:=CTypeNode.create(hdef);
                        if not Is_Record(hdef) then
                          result:=CLoadVMTAddrNode.create(result);
                      end
                    else
                      result:=load_self_node;
                  { not srsymtable.symtabletype since that can be }
                  { withsymtable as well                          }
                  if (srsym.owner.SymTableType in [ObjectSymtable,recordsymtable]) then
                    do_member_read(TAbstractRecordDef(hdef),getaddr,srsym,result,again,[],nil)
                  else
                    { no propertysyms in records (yet) }
                    InternalError(2009111510);
                end
              else
              { no method pointer }
                begin
                  handle_propertysym(TPropertySym(srsym),srsymtable,result);
                end;
            end;

          labelsym :
            begin
              { Support @label }
              if getaddr then
                begin
                  if srsym.owner<>CurrentProcInfo.procdef.LocalST then
                    CGMessage(parser_e_label_outside_proc);
                  result:=CLoadNode.create(srsym,srsym.owner)
                end
              else
                begin
                  consume(_COLON);
                  if TLabelSym(srsym).defined then
                    Message(sym_e_label_already_defined);
                  if SymTableStack.top.SymTableLevel<>srsymtable.SymTableLevel then
                    begin
                      include(CurrentProcInfo.flags,pi_has_interproclabel);
                      if (CurrentProcInfo.procdef.ProcTypeOption in [potype_unitinit,potype_unitfinalize]) then
                        Message(sym_e_interprocgoto_into_init_final_code_not_allowed);
                    end;
                  TLabelSym(srsym).defined:=true;
                  result:=CLabelNode.create(nil,TLabelSym(srsym));
                  TLabelSym(srsym).code:=result;
                end;
            end;

          undefinedsym :
            begin
              result:=CNothingNode.Create;
              result.resultdef:=CUndefinedDef.create(true);
              { clean up previously created dummy symbol }
              srsym.free;
              srsym := nil;
            end;

          UnitSym,
          namespacesym :
            begin
              if nameof_active then
                { NameOf(unitname) }
                result:=CNothingNode.create
              else
                begin
                  result:=CErrorNode.create;
                  Message(parser_e_illegal_expression);
                end;
            end;

          errorsym :
            begin
              result:=CErrorNode.create;
              if try_to_consume(_LKLAMMER) then
               begin
                 parse_paras(false,false,_RKLAMMER);
                 consume(_RKLAMMER);
               end;
            end;

          else
            begin
              result:=CErrorNode.create;
              Message(parser_e_illegal_expression);
            end;
        end; { end case }
      end;


    function factor(getaddr:boolean;flags:TExprFlags) : TNode;

         {---------------------------------------------
                         Factor_read_id
         ---------------------------------------------}

       procedure factor_read_id(out p1:TNode;out again:boolean);

         function findwithsymtable : boolean;
           var
             hp : PSymTableStackItem;
           begin
             result:=true;
             hp:=SymTableStack.stack;
             while Assigned(hp) do
               begin
                 if hp^.SymTable.SymTableType=withsymtable then
                   exit;
                 hp:=hp^.next;
               end;
             result:=false;
           end;

         var
           srsym: TSym;
           srsymtable: TSymTable;
           hdef: TDef;
           orgstoredpattern,
           storedpattern: string;
           t : TToken;
           consumeid,
           wasgenericdummy,
           allowspecialize,
           isspecialize,
           unit_found : boolean;
           dummypos,
           tokenpos: TFilePosInfo;
           spezcontext : TSpecializationContext;
           cufflags : TConsumeUnitSymFlags;
         begin
           { allow post fix operators }
           again:=true;

           { preinitalize tokenpos }
           tokenpos:=CurrentFilePos;
           p1:=nil;
           spezcontext:=nil;

           { avoid warning }
           fillchar(dummypos,sizeof(dummypos),0);

           allowspecialize:=not (m_delphi in CurrentSettings.ModeSwitches) and
                            not (ef_had_specialize in flags) and
                            (Block_Type in inline_specialization_block_types);
           if allowspecialize and (CurrentScanner.token=_ID) and (CurrentScanner.idtoken=_SPECIALIZE) then
             begin
               consume(_ID);
               isspecialize:=true;
             end
           else
             isspecialize:=ef_had_specialize in flags;

           { first check for identifier }
           if CurrentScanner.token<>_ID then
             begin
               srsym:=GenErrorSym;
               srsymtable:=nil;
               consume(_ID);
               unit_found:=false;
             end
           else
             begin
               storedpattern:=CurrentScanner.pattern;
               orgstoredpattern:=CurrentScanner.orgpattern;
               { store the position of the token before consuming it }
               tokenpos:=CurrentFilePos;
               consumeid:=true;
               srsym:=nil;
               if ef_check_attr_suffix in flags then
                 begin
                   if not (ef_type_only in flags) then
                     InternalError(2019063001);
                   consume(_ID);
                   consumeid:=false;
                   if CurrentScanner.token<>_POINT then
                     SearchSym_Type(storedpattern+CustomAttributeSuffix,srsym,srsymtable);
                 end;
               if not Assigned(srsym) then
                 begin
                   if ef_type_only in flags then
                     SearchSym_Type(storedpattern,srsym,srsymtable)
                   else
                     SearchSym(storedpattern,srsym,srsymtable);
                 end;
               { handle unit specification like System.Writeln }
               if not isspecialize then
                 begin
                   cufflags:=[];
                   if consumeid then
                     include(cufflags,cuf_consume_id);
                   if allowspecialize then
                     include(cufflags,cuf_allow_specialize);
                   if ef_check_attr_suffix in flags then
                     include(cufflags,cuf_check_attr_suffix);
                   if nameof_active then
                     include(cufflags,cuf_allow_unit_only);
                   unit_found:=try_consume_unitsym(srsym,srsymtable,t,cufflags,isspecialize,CurrentScanner.pattern);
                   if unit_found then
                     consumeid:=true;
                 end
               else
                 begin
                   unit_found:=false;
                   t:=_ID;
                 end;
               { NOTOKEN: NameOf(unitname), the unit name is already consumed }
               if consumeid and (t<>NOTOKEN) then
                 begin
                   storedpattern:=CurrentScanner.pattern;
                   orgstoredpattern:=CurrentScanner.orgpattern;
                   { store the position of the token before consuming it }
                   tokenpos:=CurrentFilePos;
                   consume(t);
                 end;
               { named parameter support }
               found_arg_name:=false;

               if not(unit_found) and
                   not isspecialize and
                  named_args_allowed and
                  (CurrentScanner.token=_ASSIGNMENT) then
                  begin
                    found_arg_name:=true;
                    p1:=CStringConstNode.createstr(orgstoredpattern);
                    consume(_ASSIGNMENT);
                    exit;
                  end;

               if isspecialize then
                 begin
                   if not Assigned(srsym) then
                     begin
                       identifier_not_found(orgstoredpattern,tokenpos);
                       srsym:=GenErrorSym;
                       srsymtable:=nil;
                     end
                   else
                     begin
                       if not unit_found then
                         srsymtable:=nil;
                       {$push}
                       {$warn 5036 off}
                       hdef:=generate_specialization_phase1(spezcontext,nil,unit_found,nil,orgstoredpattern,srsymtable,dummypos);
                       {$pop}
                       if hdef=GenErrorDef then
                         begin
                           spezcontext.free;
                           spezcontext:=nil;
                           srsym:=GenErrorSym;
                           srsymtable:=nil;
                         end
                       else
                         begin
                           if hdef.typ in [objectdef,recorddef,procvardef,arraydef] then
                             begin
                               hdef:=generate_specialization_phase2(spezcontext,TStoredDef(hdef),false,'');
                               spezcontext.free;
                               spezcontext:=nil;
                               if hdef<>GenErrorDef then
                                 begin
                                   srsym:=hdef.TypeSym;
                                   srsymtable:=srsym.owner;
                                 end
                               else
                                 begin
                                   srsym:=GenErrorSym;
                                   srsymtable:=nil;
                                 end;
                             end
                           else
                             if hdef.typ=procdef then
                               begin
                                 if not(Block_Type in inline_specialization_block_types) then
                                   message(parser_e_illegal_expression);
                                 srsym:=TProcDef(hdef).ProcSym;
                                 if Assigned(spezcontext.SymTable) then
                                   srsymtable:=spezcontext.SymTable
                                 else
                                   srsymtable:=srsym.owner;
                               end
                             else
                               InternalError(2015061204);
                         end;
                     end;
                 end;

               wasgenericdummy:=false;
               if Assigned(srsym) and
                   (sp_generic_dummy in srsym.SymOptions) and
                   (srsym.typ in [ProcSym,TypeSym]) and
                   (
                     (
                       (m_delphi in CurrentSettings.ModeSwitches) and
                       not (CurrentScanner.token in [_LT, _LSHARPBRACKET]) and
                       (
                         (
                           (srsym.typ=TypeSym) and
                           (TTypeSym(srsym).typedef.typ=undefineddef)
                         ) or (
                           (srsym.typ=ProcSym) and
                           (TProcSym(srsym).procdeflist.count=0)
                         )
                       )
                     )
                     or
                     (
                       not (m_delphi in CurrentSettings.ModeSwitches) and
                       not isspecialize and
                       (
                         not parse_generic or
                         not (
                           Assigned(CurrentStructDef) and
                           Assigned(Get_Generic_In_Hierarchy_By_Name(srsym,CurrentStructDef))
                         )
                       )
                     )
                   ) then
                 begin
                   srsym:=resolve_generic_dummysym(srsym.name);
                   if Assigned(srsym) then
                     srsymtable:=srsym.owner
                   else
                     begin
                       srsymtable:=nil;
                       wasgenericdummy:=true;
                     end;
                 end;

               { check hints, but only if it isn't a potential generic symbol;
                 that is checked in sub_expr if it isn't a generic }
               if Assigned(srsym) and
                   not (
                     (srsym.typ=TypeSym) and
                     (
                       (TTypeSym(srsym).typedef.typ in [recorddef,objectdef,arraydef,procvardef,undefineddef]) or
                       (
                         (TTypeSym(srsym).typedef.typ=errordef) and
                         (sp_generic_dummy in srsym.SymOptions)
                       )
                     ) and
                     not (sp_generic_para in srsym.SymOptions) and
                     (CurrentScanner.token in [_LT, _LSHARPBRACKET])
                   ) then
                 Check_Hints(srsym,srsym.SymOptions,srsym.DeprecatedMsg,tokenpos);

               { if nothing found give error and return errorsym }
               if not Assigned(srsym) or
                   { is this a generic dummy symbol? }
                   ((srsym.typ=TypeSym) and
                   Assigned(TTypeSym(srsym).typedef) and
                   (TTypeSym(srsym).typedef.typ=undefineddef) and
                   not (sp_generic_para in srsym.SymOptions) and
                   not (CurrentScanner.token in [_LT, _LSHARPBRACKET]) and
                   not (
                     { in non-Delphi modes the generic class' name without a
                       "specialization" or "<T>" may be used to identify the
                       current class }
                     (sp_generic_dummy in srsym.SymOptions) and
                     Assigned(CurrentStructDef) and
                     (df_generic in CurrentStructDef.DefOptions) and
                     not (m_delphi in CurrentSettings.ModeSwitches) and
                     Assigned(Get_Generic_In_Hierarchy_By_Name(srsym,CurrentStructDef))
                   )) and
                   { it could be a rename of a generic para }
                   { Note: if this generates false positives we'll need to
                           include a "basesym" to tsym to track the original
                           symbol }
                   not (sp_explicitrename in srsym.SymOptions) then
                 begin
                   { if a generic is parsed and when we are inside an with block,
                     a symbol might not be defined }
                   if Assigned(CurrentProcInfo) and (df_generic in CurrentProcInfo.procdef.DefOptions) and
                      findwithsymtable then
                     begin
                       { create dummy symbol, it will be freed later on }
                       srsym:=TStoredSym.create(undefinedsym,'$undefinedsym');
                       srsymtable:=nil;
                     end
                   else
                     begin
                       if wasgenericdummy then
                         messagepos(tokenpos,parser_e_no_generics_as_types)
                       else
                         identifier_not_found(orgstoredpattern,tokenpos);
                       srsym:=GenErrorSym;
                       srsymtable:=nil;
                     end;
                 end;
             end;

           { Access to funcret or need to call the function? }
           if (srsym.typ in [absolutevarsym,localvarsym,paravarsym]) and
              (vo_is_funcret in TAbstractVarSym(srsym).VarOptions) and
              { result(x) is not allowed }
              not(vo_is_result in TAbstractVarSym(srsym).VarOptions) and
              (
               (CurrentScanner.token=_LKLAMMER) or
               (
                (([m_delphi,m_mac,m_iso,m_extpas] * CurrentSettings.ModeSwitches) <> []) and
                (afterassignment or in_args)
               )
              ) then
            begin
              hdef:=TDef(srsym.owner.DefOwner);
              if Assigned(hdef) and
                 (hdef.typ=procdef) then
                srsym:=TProcDef(hdef).ProcSym
              else
                begin
                  Message(parser_e_illegal_expression);
                  srsym:=GenErrorSym;
                end;
              srsymtable:=srsym.owner;
            end;

            begin
              nameof_record_sym(srsym);
              p1:=factor_handle_sym(srsym,srsymtable,again,getaddr,unit_found,flags,spezcontext);

              if Assigned(spezcontext) then
                InternalError(2015061207);

              if Assigned(p1) and (p1.nodetype<>errorn) then
                p1.fileinfo:=tokenpos;
            end;
         end;

         {---------------------------------------------
                         Factor_Read_Set
         ---------------------------------------------}

         { Read a set between [] }
         function factor_read_set:TNode;
         var
           p1,p2 : TNode;
           lastp,
           buildp : TArrayConstructorNode;
         begin
           buildp:=nil;
           lastp:=nil;
         { be sure that a least one arrayconstructn is used, also for an
           empty [] }
           if CurrentScanner.token=_RECKKLAMMER then
             buildp:=CArrayConstructorNode.create(nil,buildp)
           else
            repeat
              p1:=comp_expr([ef_accept_equal]);
              if try_to_consume(_POINTPOINT) then
                begin
                  p2:=comp_expr([ef_accept_equal]);
                  p1:=CArrayConstructorRangeNode.create(p1,p2);
                end;
               { insert at the end of the tree, to get the correct order }
             if not Assigned(buildp) then
               begin
                 buildp:=CArrayConstructorNode.create(p1,nil);
                 lastp:=buildp;
               end
             else
               begin
                 lastp.right:=CArrayConstructorNode.create(p1,nil);
                 lastp:=TArrayConstructorNode(lastp.right);
               end;
           { there could be more elements }
           until not try_to_consume(_COMMA);
           if Block_Type in [bt_body,bt_except] then
             Include(buildp.arrayconstructornodeflags, acnf_allow_array_constructor);
           factor_read_set:=buildp;
         end;

         function can_load_self_node: boolean;
         begin
           result:=false;
           if (Block_Type in [bt_const,bt_type,bt_const_type,bt_var_type]) or
              not Assigned(CurrentStructDef) or
              not Assigned(CurrentProcInfo) then
             exit;
           result:=not CurrentProcInfo.get_normal_proc.procdef.No_Self_Node;
         end;


      {---------------------------------------------
                      Factor (Main)
      ---------------------------------------------}

      var
         l          : LongInt;
         ic         : int64;
         qc         : qword;
         p1         : TNode;
         code       : integer;
         srsym      : TSym;
         srsymtable : TSymTable;
         pd         : TProcDef;
         hclassdef  : TObjectDef;
         d          : BestReal;
         hs,hsorg   : string;
         hdef       : TDef;
         filepos    : TFilePosInfo;
         callflags  : TCallNodeFlags;
         idstr      : TIDString;
         spezcontext : TSpecializationContext;
         isspecialize,
         mightbegeneric,
         useself,
         dopostfix,
         again,
         updatefpos,
         nodechanged  : boolean;
         oldprocvardef : TProcVarDef;
         oldfuncrefdef : TObjectDef;
      begin
        { can't keep a copy of p1 and compare pointers afterwards, because
          p1 may be freed and reallocated in the same place!  }
        dopostfix:=true;
        updatefpos:=false;
        p1:=nil;
        filepos:=CurrentTokenPos;
        again:=false;
        pd:=nil;
        isspecialize:=false;
        if CurrentScanner.token=_ID then
         begin
           again:=true;
           { Handle references to self }
           if (CurrentScanner.idtoken=_SELF) and can_load_self_node then
             begin
               p1:=load_self_node;
               consume(_ID);
               again:=true;
             end
           else
             factor_read_id(p1,again);

           if Assigned(p1) then
            begin
              { factor_read_id will set the filepos to after the id,
                and in case of _SELF the filepos will already be the
                same as filepos (so setting it again doesn't hurt).  }
              p1.fileinfo:=filepos;
              filepos:=CurrentTokenPos;
            end;
           { handle post fix operators }
           if (p1.nodetype=specializen) then
             { post fix operators are handled after specialization }
             dopostfix:=false
           else
             if (m_delphi in CurrentSettings.ModeSwitches) and
                 (Block_Type in inline_specialization_block_types) and
                 (CurrentScanner.token in [_LT,_LSHARPBRACKET]) then
               begin
                 idstr:='';
                 case p1.nodetype of
                   typen:
                     idstr:=TTypeNode(p1).TypeSym.name;
                   loadvmtaddrn:
                     if TLoadVMTAddrNode(p1).left.nodetype=typen then
                       idstr:=TTypeNode(TLoadVMTAddrNode(p1).left).TypeSym.name;
                   loadn:
                     idstr:=TLoadNode(p1).symtableentry.name;
                   calln:
                     idstr:=TCallNode(p1).symtableprocentry.name;
                   else
                     ;
                 end;
                 { if this is the case then the postfix handling is done in
                   sub_expr if necessary }
                 dopostfix:=not could_be_generic(idstr);
               end;
           { TP7 ugliness: @proc^ is parsed as (@proc)^, but @notproc^ is parsed
             as @(notproc^) }
           if (m_tp_procvar in CurrentSettings.ModeSwitches) and (CurrentScanner.token=_CARET) and
              getaddr and (p1.nodetype=loadn) and (TLoadNode(p1).symtableentry.typ=ProcSym) then
             dopostfix:=false;
           { maybe an additional parameter instead of misusing hadspezialize? }
           if dopostfix and not (ef_had_specialize in flags) then
             updatefpos:=postfixoperators(p1,again,getaddr);
         end
        else
         begin
           updatefpos:=true;
           case CurrentScanner.token of
             _RETURN :
                begin
                  consume(_RETURN);
                  p1:=nil;
                  if not(CurrentScanner.token in [_SEMICOLON,_ELSE,_END]) then
                    begin
                      p1:=comp_expr([ef_accept_equal]);
                      if not Assigned(CurrentProcInfo) or
                         (CurrentProcInfo.procdef.ProcTypeOption in [potype_constructor,potype_destructor]) or
                         is_void(CurrentProcInfo.procdef.ReturnDef) then
                        begin
                          Message(parser_e_void_function);
                          { recovery }
                          p1.free;
                          p1:=nil;
                        end;
                    end;
                  p1 := CExitNode.create(p1);
                end;
             _INHERITED :
               begin
                 again:=true;
                 consume(_INHERITED);
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
                    hclassdef:=TObjectDef(CurrentStructDef).ChildOf;
                    { Objective-C categories *replace* methods in the class
                      they extend, or add methods to it. So calling an
                      inherited method always calls the method inherited from
                      the parent of the extended class }
                    if Is_ObjCCategory(CurrentStructDef) then
                      hclassdef:=hclassdef.ChildOf;
                    spezcontext:=nil;
                    { if inherited; only then we need the method with
                      the same name }
                    if CurrentScanner.token <> _ID then
                     begin
                       hs:=CurrentProcInfo.procdef.ProcSym.name;
                       hsorg:=CurrentProcInfo.procdef.ProcSym.realname;
                       anon_inherited:=true;
                       { For message methods we need to search using the message
                         number or string }
                       pd:=TProcDef(TProcSym(CurrentProcInfo.procdef.ProcSym).ProcdefList[0]);
                       srdef:=nil;
                       if (po_msgint in pd.ProcOptions) then
                         SearchSym_In_Class_By_MsgInt(hclassdef,pd.MessageInf.i,srdef,srsym,srsymtable)
                       else
                        if (po_msgstr in pd.ProcOptions) then
                          SearchSym_In_Class_By_MsgStr(hclassdef,pd.MessageInf.str^,srsym,srsymtable)
                       else
                       { helpers have their own ways of dealing with inherited }
                       if Is_ObjectPascal_Helper(CurrentStructDef) then
                         SearchSym_In_Helper(TObjectDef(CurrentStructDef),TObjectDef(CurrentStructDef),hs,srsym,srsymtable,[ssf_has_inherited])
                       else
                         SearchSym_In_Class(hclassdef,CurrentStructDef,hs,srsym,srsymtable,[ssf_search_helper]);
                     end
                    else
                     begin
                       if not (m_delphi in CurrentSettings.ModeSwitches) and
                           (Block_Type in inline_specialization_block_types) and
                           (CurrentScanner.token=_ID) and
                           (CurrentScanner.idtoken=_SPECIALIZE) then
                         begin
                           consume(_ID);
                           if CurrentScanner.token<>_ID then
                             message(parser_e_methode_id_expected);
                           isspecialize:=true;
                         end
                       else
                         isspecialize:=false;
                       hs:=CurrentScanner.pattern;
                       hsorg:=CurrentScanner.orgpattern;
                       consume(_ID);
                       anon_inherited:=false;
                       { helpers have their own ways of dealing with inherited }
                       if Is_ObjectPascal_Helper(CurrentStructDef) then
                         SearchSym_In_Helper(TObjectDef(CurrentStructDef),TObjectDef(CurrentStructDef),hs,srsym,srsymtable,[ssf_has_inherited])
                       else
                         SearchSym_In_Class(hclassdef,CurrentStructDef,hs,srsym,srsymtable,[ssf_search_helper]);
                       if isspecialize and Assigned(srsym) then
                         begin
                           if not handle_specialize_inline_specialization(srsym,false,srsymtable,spezcontext) then
                             srsym:=nil;
                         end;
                     end;
                    if Assigned(srsym) then
                     begin
                       mightbegeneric:=(m_delphi in CurrentSettings.ModeSwitches) and
                                         (CurrentScanner.token in [_LT,_LSHARPBRACKET]) and
                                         (sp_generic_dummy in srsym.SymOptions);
                       { load the procdef from the inherited class and
                         not from self }
                       case srsym.typ of
                         TypeSym,
                         ProcSym:
                           begin
                             { typesym is only a valid choice if we're dealing
                               with a potential generic }
                             if (srsym.typ=TypeSym) and not mightbegeneric then
                               begin
                                 Message(parser_e_methode_id_expected);
                                 p1:=CErrorNode.create;
                               end
                             else
                               begin
                                 useself:=false;
                                 if Is_ObjectPascal_Helper(CurrentStructDef) then
                                   begin
                                     { for a helper load the procdef either from the
                                       extended type, from the parent helper or from
                                       the extended type of the parent helper
                                       depending on the def the found symbol belongs
                                       to }
                                     if (srsym.Owner.DefOwner.typ=objectdef) and
                                         Is_ObjectPascal_Helper(TObjectDef(srsym.Owner.DefOwner)) then
                                       if def_is_related(CurrentStructDef,TDef(srsym.Owner.DefOwner)) and
                                           Assigned(TObjectDef(CurrentStructDef).ChildOf) then
                                         hdef:=TObjectDef(CurrentStructDef).ChildOf
                                       else
                                         begin
                                           hdef:=TObjectDef(srsym.Owner.DefOwner).ExtendedDef;
                                           useself:=true;
                                         end
                                     else
                                       begin
                                         hdef:=TDef(srsym.Owner.DefOwner);
                                         useself:=true;
                                       end;
                                   end
                                 else
                                   hdef:=hclassdef;
                                 if (po_classmethod in CurrentProcInfo.procdef.ProcOptions) or
                                    (po_staticmethod in CurrentProcInfo.procdef.ProcOptions) then
                                   hdef:=CClassRefDef.create(hdef);
                                 if useself then
                                   begin
                                     p1:=CTypeConvNode.Create_Internal(load_self_node,hdef);
                                   end
                                 else
                                   begin
                                     p1:=CTypeNode.create(hdef);
                                     { we need to allow helpers here }
                                     TTypeNode(p1).helperallowed:=true;
                                   end;
                               end;
                           end;
                         propertysym:
                           ;
                         else
                           begin
                             Message(parser_e_methode_id_expected);
                             p1:=CErrorNode.create;
                           end;
                       end;
                       if mightbegeneric then
                         begin
                           p1:=CSpecializeNode.create_inherited(p1,getaddr,srsym,hclassdef);
                         end
                       else
                         begin
                           if not isspecialize then
                             Check_Hints(srsym,srsym.SymOptions,srsym.DeprecatedMsg);
                           callflags:=[cnf_inherited];
                           include(CurrentProcInfo.flags,pi_has_inherited);
                           if anon_inherited then
                             include(callflags,cnf_anon_inherited);
                           do_member_read(hclassdef,getaddr,srsym,p1,again,callflags,spezcontext);
                         end;
                       if p1.nodetype=errorn then
                       begin
                         spezcontext.free;
                         spezcontext := nil;
                       end;
                     end
                    else
                     begin
                       if anon_inherited then
                        begin
                          { For message methods we need to call DefaultHandler }
                          if (po_msgint in pd.ProcOptions) or
                             (po_msgstr in pd.ProcOptions) then
                            begin
                              SearchSym_In_Class(hclassdef,hclassdef,'DEFAULTHANDLER',srsym,srsymtable,[ssf_search_helper]);
                              if not Assigned(srsym) or
                                 (srsym.typ<>ProcSym) then
                                InternalError(200303171);
                              p1:=nil;
                              do_proc_call(srsym,srsym.owner,hclassdef,false,again,p1,[],nil);
                            end
                          else
                            begin
                              { we need to ignore the inherited; }
                              p1:=CNothingNode.create;
                            end;
                        end
                       else
                        begin
                          Message1(sym_e_id_no_member,hsorg);
                          p1:=CErrorNode.create;
                        end;
                       again:=false;
                     end;
                    { turn auto inheriting off }
                    anon_inherited:=false;
                  end
                 else
                   begin
                     { in case of records we use a more clear error message }
                     if Assigned(CurrentStructDef) and
                         (CurrentStructDef.typ=recorddef) then
                       Message(parser_e_inherited_not_in_record)
                     else
                       Message(parser_e_generic_methods_only_in_methods);
                     again:=false;
                     p1:=CErrorNode.create;
                   end;
                 if p1.nodetype<>specializen then
                   postfixoperators(p1,again,getaddr);
               end;

             _INTCONST :
               begin
                 {Try first wether the value fits in an int64.}
                 val(CurrentScanner.pattern,ic,code);
                 if code=0 then
                   begin
                      consume(_INTCONST);
                      int_to_type(ic,hdef);
                      p1:=COrdConstNode.create(ic,hdef,true);
                   end
                 else
                   begin
                     { try qword next }
                     val(CurrentScanner.pattern,qc,code);
                     if code=0 then
                       begin
                          consume(_INTCONST);
                          int_to_type(qc,hdef);
                          p1:=COrdConstNode.create(qc,hdef,true);
                       end;
                   end;
                 if code<>0 then
                   begin
                     { finally float }
                     Val(CurrentScanner.pattern,d,code);
                     if code<>0 then
                       begin
                          Message(parser_e_invalid_integer);
                          consume(_INTCONST);
                          l:=1;
                          p1:=COrdConstNode.create(l,SIntType,true);
                       end
                     else
                       begin
                          consume(_INTCONST);
                          p1:=CRealConstNode.create(d,pbestrealtype^);
                       end;
                   end
                 else
                   { the necessary range checking has already been done by val }
                   TOrdConstNode(p1).rangecheck:=false;
                 if CurrentScanner.token=_POINT then
                   begin
                     again:=true;
                     postfixoperators(p1,again,getaddr);
                   end;
               end;

             _REALNUMBER :
               begin
                 p1:=real_const_node_from_pattern(CurrentScanner.pattern);
                 consume(_REALNUMBER);
                 if CurrentScanner.token=_POINT then
                   begin
                     again:=true;
                     postfixoperators(p1,again,getaddr);
                   end;
               end;

             _STRING :
               begin
                 if cs_compilesystem in CurrentSettings.ModuleSwitches then
                   Message(parser_e_nostringaliasinsystem);
                 string_dec(hdef,true);
                 { STRING can be also a type cast }
                 if try_to_consume(_LKLAMMER) then
                  begin
                    p1:=comp_expr([ef_accept_equal]);
                    consume(_RKLAMMER);
                    p1:=CTypeConvNode.create_explicit(p1,hdef);
                    { handle postfix operators here e.g. string(a)[10] }
                    again:=true;
                    postfixoperators(p1,again,getaddr);
                  end
                 else
                   begin
                     p1:=CTypeNode.create(hdef);
                     if CurrentScanner.token=_POINT then
                       begin
                         again:=true;
                         { handle type helpers here }
                         postfixoperators(p1,again,getaddr);
                       end;
                   end;
               end;

             _FILE :
               begin
                 hdef:=CFileType;
                 consume(_FILE);
                 { FILE can be also a type cast }
                 if try_to_consume(_LKLAMMER) then
                  begin
                    p1:=comp_expr([ef_accept_equal]);
                    consume(_RKLAMMER);
                    p1:=CTypeConvNode.create_explicit(p1,hdef);
                    { handle postfix operators here e.g. string(a)[10] }
                    again:=true;
                    postfixoperators(p1,again,getaddr);
                  end
                 else
                  begin
                    p1:=CTypeNode.create(hdef);
                  end;
               end;

             _CSTRING :
               begin
                 p1:=CStringConstNode.createpchar(pchar(CurrentScanner.cstringpattern),length(CurrentScanner.cstringpattern),nil);
                 consume(_CSTRING);
                 if CurrentScanner.token in postfixoperator_tokens then
                   begin
                     again:=true;
                     postfixoperators(p1,again,getaddr);
                   end;
               end;

             _CCHAR :
               begin
                 p1:=COrdConstNode.create(ord(CurrentScanner.pattern[1]),CAnsiCharType,true);
                 consume(_CCHAR);
                 if CurrentScanner.token=_POINT then
                   begin
                     again:=true;
                     postfixoperators(p1,again,getaddr);
                   end;
               end;

             _CWSTRING:
               begin
                 if GetLengthWideString(CurrentScanner.patternw)=1 then
                   p1:=COrdConstNode.create(ord(GetCharWideString(CurrentScanner.patternw,0)),CWideCharType,true)
                 else
                   p1:=CStringConstNode.createunistr(CurrentScanner.patternw);
                 consume(_CWSTRING);
                 if CurrentScanner.token in postfixoperator_tokens then
                   begin
                     again:=true;
                     postfixoperators(p1,again,getaddr);
                   end;
               end;

             _CWCHAR:
               begin
                 p1:=COrdConstNode.create(ord(GetCharWideString(CurrentScanner.patternw,0)),CWideCharType,true);
                 consume(_CWCHAR);
                 if CurrentScanner.token=_POINT then
                   begin
                     again:=true;
                     postfixoperators(p1,again,getaddr);
                   end;
               end;

             _KLAMMERAFFE :
               begin
                 consume(_KLAMMERAFFE);
                 got_addrn:=true;
                 { support both @<x> and @(<x>) }
                 if try_to_consume(_LKLAMMER) then
                  begin
                    p1:=factor(true,[]);
                    { inside parentheses a full expression is allowed, see also tests\tbs\tb27517.pas }
                    if CurrentScanner.token<>_RKLAMMER then
                      p1:=sub_expr(opcompare,[ef_accept_equal],p1);
                    consume(_RKLAMMER);
                  end
                 else
                  p1:=factor(true,[]);
                 if (CurrentScanner.token in postfixoperator_tokens) and
                   { TP7 ugliness: @proc^ is parsed as (@proc)^, but @notproc^
                     is parsed as @(notproc^) }
                    not
                    (
                     (m_tp_procvar in CurrentSettings.ModeSwitches) and
                     (CurrentScanner.token=_CARET) and (p1.nodetype=loadn) and (TLoadNode(p1).symtableentry.typ=ProcSym)
                    )
                   then
                  begin
                    again:=true;
                    postfixoperators(p1,again,getaddr);
                  end;
                 got_addrn:=false;
                 p1:=CAddrNode.create(p1);
                 p1.fileinfo:=filepos;
                 if cs_typed_addresses in CurrentSettings.LocalSwitches then
                   include(TAddrNode(p1).addrnodeflags,anf_typedaddr);
                 { Store the procvar that we are expecting, the
                   addrn will use the information to find the correct
                   procdef or it will return an error }
                 if Assigned(getprocvardef) and
                    (TAddrNode(p1).left.nodetype = loadn) then
                   TAddrNode(p1).getprocvardef:=getprocvardef;
                 if (CurrentScanner.token in postfixoperator_tokens) then
                  begin
                    again:=true;
                    postfixoperators(p1,again,getaddr);
                  end;
               end;

             _LKLAMMER :
               begin
                 consume(_LKLAMMER);
                 p1:=comp_expr([ef_accept_equal]);
                 consume(_RKLAMMER);
                 { it's not a good solution
                   but (a+b)^ makes some problems  }
                 if CurrentScanner.token in postfixoperator_tokens then
                  begin
                    again:=true;
                    postfixoperators(p1,again,getaddr);
                  end;
               end;

             _LECKKLAMMER :
               begin
                 consume(_LECKKLAMMER);
                 p1:=factor_read_set;
                 consume(_RECKKLAMMER);
               end;

             _PLUS :
               begin
                 consume(_PLUS);
                 p1:=factor(false,[]);
                 p1:=CUnaryPlusNode.create(p1);
               end;

             _MINUS :
               begin
                 consume(_MINUS);
                 if (CurrentScanner.token = _INTCONST) and not(m_isolike_unary_minus in CurrentSettings.ModeSwitches) then
                    begin
                      { ugly hack, but necessary to be able to parse }
                      { -9223372036854775808 as int64 (JM)           }
                      CurrentScanner.pattern := '-'+CurrentScanner.pattern;
                      p1:=sub_expr(oppower,[],nil);
                      {  -1 ** 4 should be - (1 ** 4) and not
                         (-1) ** 4
                         This was the reason of tw0869.pas test failure PM }
                      if p1.nodetype=starstarn then
                        begin
                          if TBinaryNode(p1).left.nodetype=ordconstn then
                            begin
                              TOrdConstNode(TBinaryNode(p1).left).value:=-TOrdConstNode(TBinaryNode(p1).left).value;
                              p1:=CUnaryMinusNode.create(p1);
                            end
                          else if TBinaryNode(p1).left.nodetype=realconstn then
                            begin
                              TRealConstNode(TBinaryNode(p1).left).NegateValue;
                              p1:=CUnaryMinusNode.create(p1);
                            end
                          else
                            InternalError(20021029);
                        end;
                    end
                 else
                   begin
                     if m_isolike_unary_minus in CurrentSettings.ModeSwitches then
                       p1:=sub_expr(opmultiply,[],nil)
                     else
                       p1:=sub_expr(oppower,[],nil);

                     p1:=CUnaryMinusNode.create(p1);
                   end;
               end;

             _OP_NOT :
               begin
                 consume(_OP_NOT);
                 p1:=factor(false,[]);
                 p1:=CNotNode.create(p1);
               end;

             _NIL :
               begin
                 consume(_NIL);
                 p1:=CNilNode.create;
                 { It's really ugly code nil^, but delphi allows it }
                 if CurrentScanner.token in [_CARET,_POINT] then
                  begin
                    again:=true;
                    postfixoperators(p1,again,getaddr);
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
                 consume(_OBJCPROTOCOL);
                 consume(_LKLAMMER);
                 p1:=factor(false,[]);
                 consume(_RKLAMMER);
                 p1:=CInlineNode.create(in_objc_protocol_x,false,p1);
               end;

             _PROCEDURE,
             _FUNCTION:
               begin
                 if (Block_Type=bt_body) and
                     (m_anonymous_functions in CurrentSettings.ModeSwitches) then
                   begin
                     filepos:=CurrentFilePos;
                     oldprocvardef:=getprocvardef;
                     oldfuncrefdef:=getfuncrefdef;
                     getprocvardef:=nil;
                     getfuncrefdef:=nil;
                     pd:=read_proc([rpf_anonymous],nil);
                     getprocvardef:=oldprocvardef;
                     getfuncrefdef:=oldfuncrefdef;
                     { assume that we try to get the address except if certain
                       tokens follow that indicate a call }
                     do_proc_call(pd.ProcSym,pd.owner,nil,not (CurrentScanner.token in [_POINT,_CARET,_LECKKLAMMER]),
                                  again,p1,[],nil);
                     { don't allow @<anon func>, but keep the parsing for recovery }
                     if (p1.nodetype<>errorn) and getaddr then
                       begin
                         p1.free;
                         p1:=CErrorNode.create;
                         MessagePos(filepos,parser_e_illegal_expression);
                       end;
                   end
                 else
                   begin
                     Message(parser_e_illegal_expression);
                     p1:=CErrorNode.create;
                     { recover }
                     consume(CurrentScanner.token);
                   end;
               end

             else if not statement_expr(p1) then
               begin
                 Message(parser_e_illegal_expression);
                 p1:=CErrorNode.create;
                 { recover }
                 consume(CurrentScanner.token);
               end;
           end;
        end;

        { generate error node if no node is created }
        if not Assigned(p1) then
         begin
{$ifdef EXTDEBUG}
           Comment(VWarning,'factor: p1=nil');
{$endif}
           p1:=CErrorNode.create;
           updatefpos:=true;
         end;

        { get the resultdef for the node if nothing stops us }
        if (not Assigned(p1.resultdef)) and dopostfix then
          begin
            DoTypeCheckPassChanged(p1,nodechanged);
            updatefpos:=updatefpos or nodechanged;
          end;

        if Assigned(p1) and
           updatefpos then
          p1.fileinfo:=filepos;
        factor:=p1;
      end;
  {$maxfpuregisters default}

    procedure post_comp_expr_gendef(var def: TDef);
      var
        p1 : TNode;
        again : boolean;
      begin
        if not Assigned(def) then
          InternalError(2011053001);
        again:=false;
        { handle potential typecasts, etc }
        p1:=handle_factor_typenode(def,false,again,nil,false);
        { parse postfix operators }
        postfixoperators(p1,again,false);
        if Assigned(p1) and (p1.nodetype=typen) then
          def:=TTypeNode(p1).typedef
        else
          def:=GenErrorDef;
      end;

{****************************************************************************
                             Sub_Expr
****************************************************************************}
    function sub_expr(pred_level:TOperatorPrecedence;flags:TExprFlags;factornode:TNode):TNode;
    {Reads a subexpression while the operators are of the current precedence
     level, or any higher level. Replaces the old term, simple_expr and
     simpl2_expr.}

      function istypenode(n:TNode):boolean;inline;
      { Checks whether the given node is a type node or a VMT node containing a
        typenode. This is used in the code for inline specializations in the
        _LT branch below }
        begin
          result:=Assigned(n) and
                    (
                      (n.nodetype=typen) or
                      (
                        (n.nodetype=loadvmtaddrn) and
                        (TLoadVMTAddrNode(n).left.nodetype=typen)
                      )
                    );
        end;

      function gettypedef(n:TNode):TDef;inline;
      { This returns the typedef that belongs to the given typenode or
        loadvmtaddrnode. n must not be Nil! }
        begin
          if n.nodetype=typen then
            result:=TTypeNode(n).typedef
          else
            result:=TTypeNode(TLoadVMTAddrNode(n).left).typedef;
        end;

      function gettypedef(sym:TSym):TDef;inline;
        begin
          result:=nil;
          case sym.typ of
            TypeSym:
              result:=TTypeSym(sym).typedef;
            ProcSym:
              if not (sp_generic_dummy in sym.SymOptions) or (TProcSym(sym).procdeflist.count>0) then
                result:=TDef(TProcSym(sym).procdeflist[0]);
            else
              InternalError(2015092701);
          end;
        end;

      function getgenericsym(n:TNode;out srsym:TSym):boolean;
        var
          srsymtable : TSymTable;
        begin
          srsym:=nil;
          case n.nodetype of
            typen:
              srsym:=TTypeNode(n).typedef.TypeSym;
            loadvmtaddrn:
              srsym:=TTypeNode(TLoadVMTAddrNode(n).left).typedef.TypeSym;
            loadn:
              if not SearchSym_With_SymOption(TLoadNode(n).symtableentry.Name,srsym,srsymtable,sp_generic_dummy) then
                srsym:=nil;
            calln:
              srsym:=TCallNode(n).symtableprocentry;
            specializen:
              srsym:=TSpecializeNode(n).sym;
            { TODO : handle const nodes }
            else
              ;
          end;
          result:=Assigned(srsym);
        end;

      function generate_inline_specialization(gendef:TDef;n:TNode;filepos:TFilePosInfo;parseddef:TDef;gensym:TSym;p2:TNode):TNode;
        var
          again,
          getaddr,
          unitspecific : boolean;
          pload : TNode;
          spezcontext : TSpecializationContext;
          orggensym : TSym;
          structdef,
          inheriteddef : TAbstractRecordDef;
          callflags : TCallNodeFlags;
        begin
          if not Assigned(gensym) then
            InternalError(2025103101);

          if n.nodetype=specializen then
            begin
              getaddr:=TSpecializeNode(n).getaddr;
              pload:=TSpecializeNode(n).left;
              inheriteddef:=TAbstractRecordDef(TSpecializeNode(n).inheriteddef);
              unitspecific:=TSpecializeNode(n).unit_specific;
              TSpecializeNode(n).left:=nil;
            end
          else
            begin
              getaddr:=false;
              pload:=nil;
              inheriteddef:=nil;
              unitspecific:=false;
            end;

          if Assigned(parseddef) and Assigned(gensym) and Assigned(p2) then
            gendef:=generate_specialization_phase1(spezcontext,gendef,unitspecific,parseddef,gensym.realname,gensym.owner,p2.fileinfo)
          else
            gendef:=generate_specialization_phase1(spezcontext,gendef,unitspecific,gensym.realname,gensym.owner);
          orggensym:=gensym;
          case gendef.typ of
            errordef:
              begin
                spezcontext.free;
                spezcontext:=nil;
                gensym:=GenErrorSym;
              end;
            objectdef,
            recorddef,
            procvardef,
            arraydef:
              begin
                gendef:=generate_specialization_phase2(spezcontext,TStoredDef(gendef),false,'');
                spezcontext.free;
                spezcontext:=nil;
                if gendef.typ=errordef then
                  gensym:=GenErrorSym
                else
                  gensym:=gendef.TypeSym;
              end;
            procdef:
              begin
                if not (Block_Type in [bt_body,bt_except]) then
                  begin
                    message(parser_e_illegal_expression);
                    gensym:=GenErrorSym;
                  end
                else
                  begin
                    gensym:=TProcDef(gendef).ProcSym;
                  end;
              end;
            else
              InternalError(2015092702);
          end;
          { the generic parameters are parsed and the specialization is done,
            NameOf uses the generic name }
          nameof_record_sym(orggensym);

          { in case of a class or a record the specialized generic
            is always a classrefdef }
          again:=false;

          if Assigned(pload) then
            begin
              result:=pload;
              TypeCheckPass(result);
              structdef:=inheriteddef;
              if not Assigned(structdef) then
                case result.resultdef.typ of
                  objectdef,
                  recorddef:
                    begin
                      structdef:=TAbstractRecordDef(result.resultdef);
                    end;
                  classrefdef:
                    begin
                      structdef:=TAbstractRecordDef(TClassRefDef(result.resultdef).PointedDef);
                    end;
                  else
                    InternalError(2015092703);
                end;
              if not (structdef.typ in [recorddef,objectdef]) then
                InternalError(2018092101);
              if Assigned(inheriteddef) then
                begin
                  callflags:=[cnf_inherited];
                  include(CurrentProcInfo.flags,pi_has_inherited);
                end
              else
                callflags:=[];
              do_member_read(structdef,getaddr,gensym,result,again,callflags,spezcontext);
              spezcontext:=nil;
            end
          else
            begin
              if gensym.typ=ProcSym then
                begin
                  result:=nil;
                  { check if it's a method/class method }
                  if is_member_read(gensym,gensym.owner,result,parseddef) then
                    begin
                      { if we are accessing a owner procsym from the nested }
                      { class we need to call it as a class member }
                      if (gensym.owner.SymTableType in [ObjectSymtable,recordsymtable]) and
                          Assigned(CurrentStructDef) and (CurrentStructDef<>parseddef) and Is_Owned_By(CurrentStructDef,parseddef) then
                        result:=CLoadVMTAddrNode.create(CTypeNode.create(parseddef));
                      { not srsymtable.symtabletype since that can be }
                      { withsymtable as well                          }
                      if (gensym.owner.SymTableType in [ObjectSymtable,recordsymtable]) then
                        begin
                          do_member_read(TAbstractRecordDef(parseddef),getaddr,gensym,result,again,[],spezcontext);
                          spezcontext:=nil;
                        end
                      else
                        { no procsyms in records (yet) }
                        InternalError(2015092704);
                    end
                  else
                    begin
                      { regular procedure/function call }
                      do_proc_call(gensym,gensym.owner,nil,
                                   (getaddr and not(CurrentScanner.token in [_CARET,_POINT,_LECKKLAMMER])),
                                   again,result,[],spezcontext);
                      spezcontext:=nil;
                    end;
                  end
                else
                  { handle potential typecasts, etc }
                  result:=handle_factor_typenode(gendef,nameof_active,again,nil,false);
            end;

          { parse postfix operators, NameOf does not need an instance }
          if postfixoperators(result,again,nameof_active) then
            if Assigned(result) then
              result.fileinfo:=filepos
            else
              result:=CErrorNode.create;

          spezcontext.free;
          spezcontext := nil;
        end;

      function maybe_handle_specialization(var p1,p2:TNode;filepos:TFilePosInfo):boolean;
        var
          gensym : TSym;
          parseddef,
          gendef : TDef;
          ptmp : TNode;
        begin
          result:=false;
          { we need to decide whether we have an inline specialization
            (type nodes to the left and right of "<", mode Delphi and
            ">" or "," following) or a normal "<" comparison }
          { TODO : p1 could be a non type if e.g. a variable with the
                   same name is defined in the same unit where the
                   generic is defined (though "same unit" is not
                   necessarily needed) }
          if getgenericsym(p1,gensym) and
             { Attention: when nested specializations are supported
                          p2 could be a loadn if a "<" follows }
             istypenode(p2) and
              (m_delphi in CurrentSettings.ModeSwitches) and
              { TODO : add _LT, _LSHARPBRACKET for nested specializations }
              (CurrentScanner.token in [_GT,_RSHARPBRACKET,_COMMA]) then
            begin
              { this is an inline specialization }

              { retrieve the defs of two nodes }
              if p1.nodetype=specializen then
                gendef:=gettypedef(TSpecializeNode(p1).sym)
              else
                gendef:=nil;
              parseddef:=gettypedef(p2);

              { check the hints for parseddef }
              Check_Hints(parseddef.TypeSym,parseddef.TypeSym.SymOptions,parseddef.TypeSym.DeprecatedMsg,p1.fileinfo);

              ptmp:=generate_inline_specialization(gendef,p1,filepos,parseddef,gensym,p2);

              { we don't need these nodes anymore }
              p1.free;
              p2.free;
              p2 := nil;

              p1:=ptmp;

              result:=true;
            end;
        end;

      label
        SubExprStart;
      var
        p1,p2,ptmp : TNode;
        oldt    : TToken;
        filepos : TFilePosInfo;
        gendef : TDef;
        gensym : TSym;
        genlist : TFPObjectList;
        dummyagain : boolean;
        dummyspezctxt : TSpecializationContext;
      begin
        SubExprStart:
        if pred_level=highest_precedence then
          begin
            if factornode=nil then
              p1:=factor(false,flags)
            else
              p1:=factornode;
          end
        else
          p1:=sub_expr(succ(pred_level),flags+[ef_accept_equal],factornode);
        repeat
          if (CurrentScanner.token in [NOTOKEN..last_operator]) and
             (CurrentScanner.token in operator_levels[pred_level]) and
             ((CurrentScanner.token<>_EQ) or (ef_accept_equal in flags)) then
           begin
             oldt:=CurrentScanner.token;
             filepos:=CurrentTokenPos;
             consume(CurrentScanner.token);
             if pred_level=highest_precedence then
               p2:=factor(false,[])
             else
               p2:=sub_expr(succ(pred_level),flags+[ef_accept_equal],nil);
             case oldt of
               _PLUS :
                 p1:=CAddNode.create(addn,p1,p2);
               _MINUS :
                 p1:=CAddNode.create(subn,p1,p2);
               _STAR :
                 p1:=CAddNode.create(muln,p1,p2);
               _SLASH :
                 p1:=CAddNode.create(slashn,p1,p2);
               _EQ:
                 p1:=CAddNode.create(equaln,p1,p2);
               _GT :
                 p1:=CAddNode.create(gtn,p1,p2);
               _LT :
                 begin
                   if maybe_handle_specialization(p1,p2,filepos) then
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

                       if p1.nodetype=specializen then
                         begin
                           genlist:=TFPObjectList(CurrentModule.GenericDummySyms.find(TSpecializeNode(p1).sym.name));
                           if Assigned(genlist) and (genlist.count>0) then
                             begin
                               gensym:=TGenericDummyEntry(genlist.last).ResolvedSym;
                               Check_Hints(gensym,gensym.SymOptions,gensym.DeprecatedMsg,p1.fileinfo);

                               dummyagain:=false;
                               dummyspezctxt:=nil;

                               ptmp:=factor_handle_sym(gensym,
                                                       gensym.owner,
                                                       dummyagain,
                                                       TSpecializeNode(p1).getaddr,
                                                       false,
                                                       flags,
                                                       dummyspezctxt);

                               if dummyagain then
                                 InternalError(2022012201);

                               p1.free;
                               p1:=ptmp;
                             end
                           else
                             begin
                               identifier_not_found(TSpecializeNode(p1).sym.realname);
                               p1.free;
                               p1:=CErrorNode.create;
                             end;
                         end;

                       { a) might not have their resultdef set }
                       if not Assigned(p1.resultdef) then
                         DoTypeCheckPass(p1);

                       { b) are not checked whether they are an undefined def,
                            but not a generic parameter }
                       if (p1.nodetype=typen) and
                           (TTypeNode(p1).typedef.typ=undefineddef) and
                           Assigned(TTypeNode(p1).typedef.TypeSym) and
                           not (sp_generic_para in TTypeNode(p1).typedef.TypeSym.SymOptions) then
                         begin
                           identifier_not_found(TTypeNode(p1).typedef.TypeSym.RealName);
                           p1.Free;
                           p1:=CErrorNode.create;
                         end;

                       { c) don't have their hints checked }
                       if istypenode(p1) then
                         begin
                           gendef:=gettypedef(p1);
                           if gendef.typ in [objectdef,recorddef,arraydef,procvardef] then
                             Check_Hints(gendef.TypeSym,gendef.TypeSym.SymOptions,gendef.TypeSym.DeprecatedMsg);
                         end;

                       { Note: the second part of the expression will be needed
                               for nested specializations }
                       if istypenode(p2) {and
                           not (current_scanner.token in [_LT, _LSHARPBRACKET])} then
                         begin
                           gendef:=gettypedef(p2);
                           if gendef.typ in [objectdef,recorddef,arraydef,procvardef] then
                             Check_Hints(gendef.TypeSym,gendef.TypeSym.SymOptions,gendef.TypeSym.DeprecatedMsg);
                         end;

                       { create the comparison node for "<" }
                       p1:=CAddNode.create(ltn,p1,p2)
                     end;
                 end;
               _GTE :
                 p1:=CAddNode.create(gten,p1,p2);
               _LTE :
                 p1:=CAddNode.create(lten,p1,p2);
               _SYMDIF :
                 p1:=CAddNode.create(symdifn,p1,p2);
               _STARSTAR :
                 p1:=CAddNode.create(starstarn,p1,p2);
               _OP_AS,
               _OP_IS :
                 begin
                   if (m_delphi in CurrentSettings.ModeSwitches) and
                       (CurrentScanner.token in [_LT, _LSHARPBRACKET]) and
                       getgenericsym(p2,gensym) then
                     begin
                       { for now we're handling this as a generic declaration;
                         there could be cases though (because of operator
                         overloading) where this is the wrong decision... }
                       if gensym.typ=TypeSym then
                         gendef:=TTypeSym(gensym).typedef
                       else
                         if gensym.typ=ProcSym then
                           gendef:=TDef(TProcSym(gensym).procdeflist[0])
                         else
                           InternalError(2015072401);

                       ptmp:=generate_inline_specialization(gendef,p2,filepos,nil,gensym,nil);

                       { we don't need the old p2 anymore }
                       p2.Free;

                       p2:=ptmp;

                       { here we don't need to call back down to "factor", thus
                         no "goto" }
                     end;

                   { now generate the "is" or "as" node }
                   case oldt of
                     _OP_AS:
                       p1:=CAsNode.create(p1,p2);
                     _OP_IS:
                       p1:=CIsNode.create(p1,p2);
                     else
                       InternalError(2019050528);
                   end;
                 end;
               _OP_IN :
                 p1:=CInNode.create(p1,p2);
               _OP_OR,
               _PIPE {macpas only} :
                 begin
                   p1:=CAddNode.create(orn,p1,p2);
                   if (oldt = _PIPE) then
                     include(TAddNode(p1).addnodeflags,anf_short_bool);
                 end;
               _OP_AND,
               _AMPERSAND {macpas only} :
                 begin
                   p1:=CAddNode.create(andn,p1,p2);
                   if (oldt = _AMPERSAND) then
                     include(TAddNode(p1).addnodeflags,anf_short_bool);
                 end;
               _OP_DIV :
                 p1:=CModDivNode.create(divn,p1,p2);
               _OP_NOT :
                 p1:=CNotNode.create(p1);
               _OP_MOD :
                 begin
                   p1:=CModDivNode.create(modn,p1,p2);
                   if m_isolike_mod in CurrentSettings.ModeSwitches then
                     include(TModDivNode(p1).moddivnodeflags,mdnf_isomod);
                 end;
               _OP_SHL :
                 p1:=CShlShrNode.create(shln,p1,p2);
               _OP_SHR :
                 p1:=CShlShrNode.create(shrn,p1,p2);
               _OP_XOR :
                 p1:=CAddNode.create(xorn,p1,p2);
               _ASSIGNMENT :
                 p1:=CAssignmentNode.create(p1,p2);
               _NE :
                 p1:=CAddNode.create(unequaln,p1,p2);
               else
                 InternalError(2019050529);
             end;
             p1.fileinfo:=filepos;
           end
          else
           break;
        until false;
        if (p1.nodetype=specializen) and
            (CurrentScanner.token=_LSHARPBRACKET) and
            (m_delphi in CurrentSettings.ModeSwitches) then
          begin
            filepos:=CurrentTokenPos;
            consume(CurrentScanner.token);
            p2:=factor(false,[]);
            if maybe_handle_specialization(p1,p2,filepos) then
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
        sub_expr:=p1;
      end;


    function comp_expr(flags:TExprFlags):TNode;
      var
         oldafterassignment : boolean;
         p1 : TNode;
      begin
         oldafterassignment:=afterassignment;
         afterassignment:=true;
         p1:=sub_expr(opcompare,flags,nil);
         { get the resultdef for this expression }
         if not Assigned(p1.resultdef) then
          DoTypeCheckPass(p1);
         afterassignment:=oldafterassignment;
         comp_expr:=p1;
      end;


    function expr(dotypecheck : boolean) : TNode;

      var
         p1,p2 : TNode;
         filepos : TFilePosInfo;
         oldafterassignment,
         updatefpos          : boolean;
         oldflags : TNodeFlags;
      begin
         oldafterassignment:=afterassignment;
         p1:=sub_expr(opcompare,[ef_accept_equal],nil);
         { get the resultdef for this expression }
         if not Assigned(p1.resultdef) and
            dotypecheck then
          DoTypeCheckPass(p1);
         filepos:=CurrentTokenPos;
         if CurrentScanner.token in [_ASSIGNMENT,_PLUSASN,_MINUSASN,_STARASN,_SLASHASN] then
           afterassignment:=true;
         updatefpos:=true;
         case CurrentScanner.token of
           _POINTPOINT :
             begin
                consume(_POINTPOINT);
                p2:=sub_expr(opcompare,[ef_accept_equal],nil);
                p1:=CRangeNode.create(p1,p2);
             end;
           _ASSIGNMENT :
             begin
                consume(_ASSIGNMENT);
                if Assigned(p1.resultdef) then
                  if (p1.resultdef.typ=procvardef) then
                    getprocvardef:=TProcVarDef(p1.resultdef)
                  else if is_invokable(p1.resultdef) then
                    getfuncrefdef:=TObjectDef(p1.resultdef);
                p2:=sub_expr(opcompare,[ef_accept_equal],nil);
                if Assigned(getprocvardef) then
                  handle_procvar(getprocvardef,p2)
                else if Assigned(getfuncrefdef) then
                  handle_funcref(getfuncrefdef,p2);
                getprocvardef:=nil;
                getfuncrefdef:=nil;
                p1:=CAssignmentNode.create(p1,p2);
             end;
           _PLUSASN :
             begin
               if not(cs_support_c_operators in CurrentSettings.ModuleSwitches) then
                 Message(parser_e_coperators_off);
               consume(_PLUSASN);
               p2:=sub_expr(opcompare,[ef_accept_equal],nil);
               p1:=gen_c_style_operator(addn,p1,p2);
            end;
          _MINUSASN :
            begin
               if not(cs_support_c_operators in CurrentSettings.ModuleSwitches) then
                 Message(parser_e_coperators_off);
               consume(_MINUSASN);
               p2:=sub_expr(opcompare,[ef_accept_equal],nil);
               p1:=gen_c_style_operator(subn,p1,p2);
            end;
          _STARASN :
            begin
               if not(cs_support_c_operators in CurrentSettings.ModuleSwitches) then
                 Message(parser_e_coperators_off);
               consume(_STARASN  );
               p2:=sub_expr(opcompare,[ef_accept_equal],nil);
               p1:=gen_c_style_operator(muln,p1,p2);
            end;
          _SLASHASN :
            begin
               if not(cs_support_c_operators in CurrentSettings.ModuleSwitches) then
                 Message(parser_e_coperators_off);
               consume(_SLASHASN  );
               p2:=sub_expr(opcompare,[ef_accept_equal],nil);
               p1:=gen_c_style_operator(slashn,p1,p2);
            end;
          else
            updatefpos:=false;
         end;
         oldflags:=p1.flags;
         { get the resultdef for this expression }
         if not Assigned(p1.resultdef) and
            dotypecheck then
          DoTypeCheckPass(p1);
         { transfer generic parameter flag }
         if nf_generic_para in oldflags then
           include(p1.flags,nf_generic_para);
         afterassignment:=oldafterassignment;
         if updatefpos then
           p1.fileinfo:=filepos;
         expr:=p1;
      end;

    function get_intconst:TConstExprInt;
    {Reads an expression, tries to evaluate it and check if it is an integer
     constant. Then the constant is returned.}
    var
      p:TNode;
    begin
      result:=0;
      p:=comp_expr([ef_accept_equal]);
      if not CodeGenError then
       begin
         if (p.nodetype<>ordconstn) or
            not(is_integer(p.resultdef)) then
          Message(parser_e_illegal_expression)
         else
          result:=TOrdConstNode(p).value;
       end;
      p.free;
      p := nil;
    end;


    function get_stringconst:string;
    {Reads an expression, tries to evaluate it and checks if it is a string
     constant. Then the constant is returned.}
    var
      p:TNode;
      snode : TStringConstNode absolute p;
      pw : TCompilerWideString;
      pc : PAnsiChar;
      len : Integer;

    begin
      get_stringconst:='';
      p:=comp_expr([ef_accept_equal]);
      if p.nodetype<>stringconstn then
        begin
          if (p.nodetype=ordconstn) and is_char(p.resultdef) then
            get_stringconst:=char(TOrdConstNode(p).value.svalue)
          else
            Message(parser_e_illegal_expression);
        end
      else if (TStringConstNode(p).cst_type in [cst_unicodestring,cst_widestring]) then
         begin
           pw:=snode.ValueWS;
           len:=GetLengthWideString(pw);
           pc:=GetMem(Len+1);
           pc[len]:=#0;
           Unicode2ASCII(pw,pc,CurrentSettings.SourceCodePage);
           get_stringconst:=StrPas(pc);
           FreeMem(pc);
         end
      else
        get_stringconst:=snode.asrawbytestring;
      p.free;
      p := nil;
    end;

end.
