{
    Copyright (c) 2000-2005 by Florian Klaempfl

    Type checking and register allocation for math nodes

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
unit nmat;

{$i fpcdefs.inc}

interface

    uses
       TPCompilerReal,
       node,symtype;

    type
       TModDivNodeFlag = (
         mdnf_isomod
       );

       TModDivNodeFlags = set of TModDivNodeFlag;

       TModDivNode = class(TBinOpNode)
          moddivnodeflags : TModDivNodeFlags;
          constructor create(t:TNodeType;l,r : TNode); override;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function simplify(forinline : boolean) : TNode;override;
          function dogetcopy : TNode;override;
    {$ifdef DEBUG_NODE_XML}
          procedure XMLPrintNodeInfo(var T: Text); override;
    {$endif DEBUG_NODE_XML}
         protected
          { override the following if you want to implement }
          { parts explicitely in the code generator (JM)    }
          function use_moddiv64bitint_helper: boolean; virtual;
          function first_moddiv64bitint: TNode; virtual;
          function firstoptimize: TNode; virtual;
          function first_moddivint: TNode; virtual;
       end;
       TModDivNodeClass = class of TModDivNode;

       TShlShrNode = class(TBinOpNode)
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function simplify(forinline : boolean) : TNode;override;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
          { override the following if you want to implement }
          { parts explicitely in the code generator (CEC)
            Should return nil, if everything will be handled
            in the code generator
          }
          function first_shlshr64bitint: TNode; virtual;
{$endif not cpu64bitalu and not cpuhighleveltarget}
       end;
       TShlShrNodeClass = class of TShlShrNode;

       TUnaryMinusNode = class(TUnaryNode)
          constructor create(expr : TNode);virtual;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function simplify(forinline : boolean) : TNode;override;
       end;
       TUnaryMinusNodeClass = class of TUnaryMinusNode;

       TUnaryPlusNode = class(TUnaryNode)
         constructor create(expr : TNode);virtual;
         function pass_1 : TNode;override;
         function pass_typecheck:TNode;override;
       end;
       TUnaryPlusNodeClass = class of TUnaryPlusNode;

       TNotNode = class(TUnaryNode)
          constructor create(expr : TNode);virtual;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function simplify(forinline : boolean) : TNode;override;
       {$ifdef state_tracking}
          function track_state_pass(exec_known:boolean):boolean;override;
       {$endif}
       end;
       TNotNodeClass = class of TNotNode;

    var
       CModDivNode : TModDivNodeClass = TModDivNode;
       CShlShrNode : TShlShrNodeClass = TShlShrNode;
       CUnaryMinusNode : TUnaryMinusNodeClass = TUnaryMinusNode;
       CUnaryPlusNode : TUnaryPlusNodeClass = TUnaryPlusNode;
       CNotNode : TNotNodeClass = TNotNode;

implementation

    uses
      Systems,
      Verbose,Globals,CUtils,compinnr,
      GlobType,ConstExp,
      symconst,symdef,symcpu,
      defcmp,defutil,
      htypechk,pass_1,
      cgbase,
      ncon,ncnv,ncal,nadd,nld,nbas,nflw,ninl,
      nutils,PPU;

{****************************************************************************
                              TMODDIVNODE
 ****************************************************************************}


    constructor TModDivNode.create(t:TNodeType;l,r : TNode);
      begin
        inherited create(t, l, r);
        moddivnodeflags:=[];
      end;


    constructor TModDivNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t, ppufile);
        ppufile.GetSet(TPPUSet1(moddivnodeflags));
      end;


    procedure TModDivNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutSet(TPPUSet1(moddivnodeflags));
      end;


    function TModDivNode.simplify(forinline : boolean):TNode;
      var
        rv,lv : TConstExprInt;
        hp: TNode;
      begin
        result:=nil;

        if is_constintnode(right) then
          begin
            rv:=TOrdConstNode(right).value;
            if rv = 1 then
              begin
                case nodetype of
                  modn:
                    result := COrdConstNode.create(0,left.resultdef,true);
                  divn:
                    result := left.getcopy;
                  else
                    InternalError(2019050518);
                end;
                exit;
              end;
            if rv = 0 then
              begin
                { if the node is derived from a generic const parameter
                  then don't issue an error }
                if not (nf_generic_para in flags) then
                  Message(parser_e_division_by_zero);
                { recover }
                TOrdConstNode(right).value := 1;
              end;
            { the following simplification is also required for correctness
              on x86, as its transformation of divisions by constants to
              multiplications and shifts does not handle -1 correctly }
            if (rv=-1) and
               (nodetype=divn) then
              begin
                result:=CUnaryMinusNode.create(left);
                left:=nil;
                exit;
              end;
            if (mdnf_isomod in moddivnodeflags) and
              (rv<=0) then
               begin
                 Message(cg_e_mod_only_defined_for_pos_quotient);
                 { recover }
                 TOrdConstNode(right).value := 1;
               end
            else if (rv=-1) and
              (nodetype=modn) then
              begin
                result:=COrdConstNode.create(0,left.resultdef,true);
                left:=nil;
                exit;
              end;
            if (nodetype=divn) and (left.nodetype=divn) and is_constintnode(TModDivNode(left).right) and
              { we need a type and the types must be consistent }
              Assigned(resultdef) and
              (compare_defs(resultdef,left.resultdef,nothingn)=te_exact) then
              begin
                { re-use the current node so we get the result type right }
                right:=CAddNode.create_internal(muln,right,TModDivNode(left).right.getcopy);
                hp:=TModDivNode(left).left.getcopy;
                left.Free;
                left:=hp;
                Result:=getcopy;
                Result.resultdef:=nil;
                Result:=CTypeConvNode.create_internal(Result,resultdef);
                exit;
              end;

            { pointer subtractions generate nodes dividing pointer (constants) }
            if is_constintnode(left) or is_constpointernode(left) then
              begin
                { load values }
                lv:=get_int_value(left);
                rv:=get_int_value(right);

                case nodetype of
                  modn:
                    if mdnf_isomod in moddivnodeflags then
                      begin
                        if lv>=0 then
                          result:=create_simplified_ord_const(lv mod rv,resultdef,forinline,false)
                        else
                          if ((-lv) mod rv)=0 then
                            result:=create_simplified_ord_const((-lv) mod rv,resultdef,forinline,false)
                          else
                            result:=create_simplified_ord_const(rv-((-lv) mod rv),resultdef,forinline,false);
                      end
                    else
                      result:=create_simplified_ord_const(lv mod rv,resultdef,forinline,false);
                  divn:
                    result:=create_simplified_ord_const(lv div rv,resultdef,forinline,cs_check_overflow in LocalSwitches);
                  else
                    InternalError(2019050519);
                end;
             end;
          end;
      end;


    function TModDivNode.dogetcopy: TNode;
      var
        n: TModDivNode;
      begin
        n:=TModDivNode(inherited dogetcopy);
        n.moddivnodeflags:=moddivnodeflags;
        result:=n;
      end;


    function TModDivNode.use_moddiv64bitint_helper: boolean;
      begin
        { Decide whether this operand combination requires a runtime helper. }
{$if defined(cpu64bitalu) or defined(cpuhighleveltarget)}
        result:=false;
{$else cpu64bitalu or cpuhighleveltarget}
        result:=
          (left.resultdef.typ=orddef) and
          (right.resultdef.typ=orddef) and
          { include currency as well }
          (is_64bit(left.resultdef) or is_64bit(right.resultdef));
{$endif cpu64bitalu or cpuhighleveltarget}
      end;


    function TModDivNode.pass_typecheck:TNode;
      var
        else_block,
        hp,t : TNode;
        rd,ld : TOrdDef;
        else_statements,
        statements : TStatementNode;
        result_data : TTempCreateNode;
        nd : TOrdDef;
      begin
         result:=nil;
         TypeCheckPass(left);
         TypeCheckPass(right);

         { avoid any problems with type parameters later on }
         if is_typeparam(left.resultdef) or is_typeparam(right.resultdef) then
           begin
             resultdef:=cundefinedtype;
             exit;
           end;

         set_varstate(left,vs_read,[vsf_must_be_valid]);
         set_varstate(right,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         { tp procvar support }
         maybe_call_procvar(left,true);
         maybe_call_procvar(right,true);

         { allow operator overloading }
         t:=self;
         if isbinaryoverloaded(t,[]) then
           begin
              result:=t;
              exit;
           end;

         if not(nf_internal in flags) and
            (is_currency(left.resultdef) or is_currency(right.resultdef)) then
           begin
             { Divide the stored fixed-point integers. The quotient needs its
               Currency scale restored; the remainder already has that scale. }
             inserttypeconv(left,s64currencytype);
             inserttypeconv(right,s64currencytype);
             if CodeGenError then
               exit;
             hp:=CModDivNode.create(nodetype,
               CTypeConvNode.create_internal(left,s64inttype),
               CTypeConvNode.create_internal(right,s64inttype));
             TModDivNode(hp).moddivnodeflags:=moddivnodeflags;
             left:=nil;
             right:=nil;
             if nodetype=divn then
               hp:=CAddNode.create_internal(muln,hp,COrdConstNode.create(10000,s64inttype,false));
             result:=CTypeConvNode.create_internal(hp,s64currencytype);
             TypeCheckPass(result);
             include(result.flags,nf_is_currency);
             exit;
           end;

         { we need 2 orddefs always }
         if (left.resultdef.typ<>orddef) then
           inserttypeconv(left,sinttype);
         if (right.resultdef.typ<>orddef) then
           inserttypeconv(right,sinttype);
         if CodeGenError then
           exit;

         { Try only now to simply constant
           as otherwise you might create
           tconstnode with return type that are
           not compatible with tconst node
           as in bug report 21566 PM }

         result:=simplify(false);
         if Assigned(result) then
           exit;

         rd:=TOrdDef(right.resultdef);
         ld:=TOrdDef(left.resultdef);

         { if one operand is a cardinal and the other is a positive constant, convert the }
         { constant to a cardinal as well so we don't have to do a 64bit division (JM)    }
         { Do the same for qwords and positive constants as well, otherwise things like   }
         { "qword mod 10" are evaluated with int64 as result, which is wrong if the       }
         { "qword" was > high(int64) (JM)                                                 }
         { Additionally, do the same for cardinal/qwords and other positive types, but    }
         { always in a way that a smaller type is converted to a bigger type              }
         { (tbs/tw8870)                                                                }
         if (rd.ordtype in [u8bit,u16bit,u32bit,u64bit]) and
            ((is_constintnode(left) and
              (TOrdConstNode(left).value >= 0) and
              (TOrdConstNode(left).value <= get_max_value(rd))) or
             (not is_signed(ld) and
              (rd.size >= ld.size))) then
           begin
             if rd.size<uinttype.size then
               begin
                 inserttypeconv(left,uinttype);
                 inserttypeconv(right,uinttype);
               end
             else
               inserttypeconv(left,rd);
             resultdef:=right.resultdef;
           end
         else if (ld.ordtype in [u8bit,u16bit,u32bit,u64bit]) and
            ((is_constintnode(right) and
              (TOrdConstNode(right).value >= 0) and
              (TOrdConstNode(right).value <= get_max_value(ld))) or
             (not is_signed(rd) and
              (ld.size >= rd.size))) then
           begin
             if ld.size<uinttype.size then
               begin
                 inserttypeconv(left,uinttype);
                 inserttypeconv(right,uinttype);
               end
             else
               inserttypeconv(right,ld);
             resultdef:=left.resultdef;
           end
         else

         { when there is one currency value, everything is done
           using currency }
         if (ld.ordtype=scurrency) or
            (rd.ordtype=scurrency) then
           begin
             if (ld.ordtype<>scurrency) then
              inserttypeconv(left,s64currencytype);
             if (rd.ordtype<>scurrency) then
              inserttypeconv(right,s64currencytype);
             resultdef:=left.resultdef;
           end
         else
          { when there is one 64bit value, everything is done
            in 64bit }
          if (is_64bitint(left.resultdef) or
              is_64bitint(right.resultdef)) then
           begin
             if is_signed(rd) or is_signed(ld) then
               begin
                  if (ld.ordtype<>s64bit) then
                    inserttypeconv(left,s64inttype);
                  if (rd.ordtype<>s64bit) then
                    inserttypeconv(right,s64inttype);
               end
             else
               begin
                  if (ld.ordtype<>u64bit) then
                    inserttypeconv(left,u64inttype);
                  if (rd.ordtype<>u64bit) then
                    inserttypeconv(right,u64inttype);
               end;
             resultdef:=left.resultdef;
           end
         else
          { is there a larger than the native int? }
          if is_oversizedint(ld) or is_oversizedint(rd) then
           begin
             nd:=get_common_intdef(ld,rd,false);
             if (ld.ordtype<>nd.ordtype) then
               inserttypeconv(left,nd);
             if (rd.ordtype<>nd.ordtype) then
               inserttypeconv(right,nd);
             resultdef:=left.resultdef;
           end
         else
          { when mixing unsigned and signed native ints, convert everything to a larger signed type (JM) }
          if (is_nativeuint(rd) and
              is_signed(ld)) or
             (is_nativeuint(ld) and
              is_signed(rd)) then
           begin
              CGMessage(type_h_mixed_signed_unsigned);
              { get a signed int, larger than the native int }
              nd:=get_common_intdef(TOrdDef(sinttype),TOrdDef(uinttype),false);
              if (ld.ordtype<>nd.ordtype) then
                inserttypeconv(left,nd);
              if (rd.ordtype<>nd.ordtype) then
                inserttypeconv(right,nd);
              resultdef:=left.resultdef;
           end
         else
           begin
              { Make everything always default signed int }
              if not(rd.ordtype in [TOrdDef(sinttype).ordtype,TOrdDef(uinttype).ordtype]) then
                inserttypeconv(right,sinttype);
              if not(ld.ordtype in [TOrdDef(sinttype).ordtype,TOrdDef(uinttype).ordtype]) then
                inserttypeconv(left,sinttype);
              resultdef:=right.resultdef;
           end;

         result:=simplify(false);
         if Assigned(result) then
           exit;

         if (nodetype=modn) and (mdnf_isomod in moddivnodeflags) then
           begin
             result:=internalstatements(statements);
             else_block:=internalstatements(else_statements);
             result_data:=CTempCreateNode.create(resultdef,resultdef.size,tt_persistent,true);

             { right <=0? }
             addstatement(statements,CIfNode.create_internal(CAddNode.create_internal(lten,right.getcopy,COrdConstNode.create(0,resultdef,false)),
               { then: result:=left mod right }
               CCallNode.createintern('fpc_divbyzero',nil),
               nil
               ));

             { prepare else block }
             { result:=(-left) mod right }
             addstatement(else_statements,CAssignmentNode.create(CTempRefNode.create(result_data),CModDivNode.create(modn,CUnaryMinusNode.create(left.getcopy),right.getcopy)));
             { result<>0? }
             addstatement(else_statements,CIfNode.create_internal(CAddNode.create_internal(unequaln,CTempRefNode.create(result_data),COrdConstNode.create(0,resultdef,false)),
               { then: result:=right-result }
               CAssignmentNode.create_internal(CTempRefNode.create(result_data),CAddNode.create_internal(subn,right.getcopy,CTempRefNode.create(result_data))),
               nil
               ));

             addstatement(statements,result_data);
             { if left>=0 }
             addstatement(statements,CIfNode.create_internal(CAddNode.create_internal(gten,left.getcopy,COrdConstNode.create(0,resultdef,false)),
               { then: result:=left mod right }
               CAssignmentNode.create_internal(CTempRefNode.create(result_data),CModDivNode.create(modn,left.getcopy,right.getcopy)),
               { else block }
               else_block
               ));

             addstatement(statements,CTempDeleteNode.create_normal_temp(result_data));
             addstatement(statements,CTempRefNode.create(result_data));
           end;
      end;


    function TModDivNode.first_moddivint: TNode;
{$ifdef cpuneedsdivhelper}
      var
        procname: string[31];
      begin
        result := nil;

        { otherwise create a call to a helper }
        if nodetype = divn then
          procname := 'fpc_div_'
        else
          procname := 'fpc_mod_';

        { only qword needs the unsigned code, the
          signed code is also used for currency }
        case TOrdDef(resultdef).ordtype of
          u8bit:
            procname := procname + 'byte';
          s8bit:
            procname := procname + 'shortint';
          u16bit:
            procname := procname + 'word';
          s16bit:
            procname := procname + 'smallint';
          u32bit:
            procname := procname + 'dword';
          s32bit:
            procname := procname + 'longint';
          scurrency:
            procname := procname + 'currency';
          else
            InternalError(2015070501);
        end;

        result := CCallNode.createintern(procname,CCallParaNode.create(left,
          CCallParaNode.create(right,nil)));
        left := nil;
        right := nil;
        FirstPass(result);

        if result.resultdef.typ<>orddef then
          InternalError(2013031701);
        if resultdef.typ<>orddef then
          InternalError(2013031702);
        if TOrdDef(result.resultdef).ordtype <> TOrdDef(resultdef).ordtype then
          inserttypeconv(result,resultdef);
      end;
{$else cpuneedsdivhelper}
      begin
        result:=nil;
      end;
{$endif cpuneedsdiv32helper}


    function TModDivNode.first_moddiv64bitint: TNode;
      var
        procname: string[31];
      begin
        result := nil;

        { when currency is used set the result of the
          parameters to s64bit, so they are not converted }
        if nf_is_currency in flags then
          begin
            left.resultdef:=s64inttype;
            right.resultdef:=s64inttype;
          end;

        { otherwise create a call to a helper }
        if nodetype = divn then
          procname := 'fpc_div_'
        else
          procname := 'fpc_mod_';
        { only qword needs the unsigned code, the
          signed code is also used for currency }
        if is_signed(resultdef) then
          procname := procname + 'int64'
        else
          procname := procname + 'qword';

        result := CCallNode.createintern(procname,CCallParaNode.create(left,
          CCallParaNode.create(right,nil)));
        left := nil;
        right := nil;
        FirstPass(result);
      end;


    function TModDivNode.firstoptimize: TNode;
      var
        power,shiftval : LongInt;
        statements : TStatementNode;
        temp,resulttemp : TTempCreateNode;
        masknode : TNode;
        invertsign: Boolean;
      begin
        result := nil;
        { divide/mod a number by a constant which is a power of 2? }
        if (right.nodetype = ordconstn) and
          IsAbsPowerOf2(TOrdConstNode(right).value,power) and
{$if defined(cpu64bitalu) or defined(cpuhighleveltarget)}
          { for 64 bit, we leave the optimization to the cg }
            (not is_signed(resultdef)) then
{$else cpu64bitalu or cpuhighleveltarget}
           (((nodetype=divn) and is_oversizedord(resultdef)) or
            (nodetype=modn) or
            not is_signed(resultdef)) then
{$endif cpu64bitalu or cpuhighleveltarget}
          begin
            if nodetype=divn then
              begin
                if is_signed(resultdef) then
                  begin
                    invertsign:=TOrdConstNode(right).value<0;
                    if is_64bitint(left.resultdef) then
                      if not (cs_opt_size in CurrentSettings.OptimizerSwitches) then
                        shiftval:=63
                      else
                        { the shift code is a lot bigger than the call to }
                        { the divide helper                               }
                        exit
                    else
                      shiftval:=left.resultdef.size*8-1;

                    result:=internalstatements(statements);
                    temp:=CTempCreateNode.create(left.resultdef,left.resultdef.size,tt_persistent,true);
                    resulttemp:=CTempCreateNode.create(resultdef,resultdef.size,tt_persistent,true);
                    addstatement(statements,resulttemp);
                    addstatement(statements,temp);
                    addstatement(statements,CAssignmentNode.create(CTempRefNode.create(temp),
                     left));
                    left:=nil;

                    { masknode is (sar(temp,shiftval) and ((1 shl power)-1))
                      for power=1 (i.e. division by 2), masknode is simply (temp shr shiftval)}
                    if power=1 then
                      masknode:=
                        CShlShrNode.create(shrn,
                          CTempRefNode.create(temp),
                          COrdConstNode.create(shiftval,u8inttype,false)
                        )
                    else
                      masknode:=
                        CAddNode.create(andn,
                          CInlineNode.create(in_sar_x_y,false,
                            CCallParaNode.create(COrdConstNode.create(shiftval,u8inttype,false),
                            CCallParaNode.create(CTempRefNode.create(temp),nil))
                          ),
                          COrdConstNode.create(TCGInt((qword(1) shl power)-1),
                            right.resultdef,false)
                        );

                    if invertsign then
                      addstatement(statements,CAssignmentNode.create(CTempRefNode.create(resulttemp),
                        CUnaryMinusNode.create(
                          CInlineNode.create(in_sar_x_y,false,
                            CCallParaNode.create(COrdConstNode.create(power,u8inttype,false),
                            CCallParaNode.create(CAddNode.create(addn,CTempRefNode.create(temp),
                              masknode),nil
                            )))))
                      )
                    else
                      addstatement(statements,CAssignmentNode.create(CTempRefNode.create(resulttemp),
                        CInlineNode.create(in_sar_x_y,false,
                          CCallParaNode.create(COrdConstNode.create(power,u8inttype,false),
                          CCallParaNode.create(CAddNode.create(addn,CTempRefNode.create(temp),
                            masknode),nil
                          ))))
                      );
                    addstatement(statements,CTempDeleteNode.create(temp));
                    addstatement(statements,CTempDeleteNode.create_normal_temp(resulttemp));
                    addstatement(statements,CTempRefNode.create(resulttemp));
                    right.Free;
                    right := nil;
                  end
                else
                  begin
                    TOrdConstNode(right).value:=power;
                    result:=CShlShrNode.create(shrn,left,right)
                  end;
              end
            else if is_signed(resultdef) then    { signed modulus }
              begin
                if (cs_opt_size in CurrentSettings.OptimizerSwitches) then
                  exit;

                shiftval:=left.resultdef.size*8-1;
                TOrdConstNode(right).value.uvalue:=qword((qword(1) shl power)-1);

                result:=internalstatements(statements);
                temp:=CTempCreateNode.create(left.resultdef,left.resultdef.size,tt_persistent,true);
                resulttemp:=CTempCreateNode.create(resultdef,resultdef.size,tt_persistent,true);
                addstatement(statements,resulttemp);
                addstatement(statements,temp);
                addstatement(statements,CAssignmentNode.create(CTempRefNode.create(temp),left));
                { mask:=sar(left,sizeof(left)*8-1) and ((1 shl power)-1); }
                if power=1 then
                  masknode:=
                    CShlShrNode.create(shrn,
                      CTempRefNode.create(temp),
                      COrdConstNode.create(shiftval,u8inttype,false)
                    )
                else
                  masknode:=
                    CAddNode.create(andn,
                      CInlineNode.create(in_sar_x_y,false,
                        CCallParaNode.create(COrdConstNode.create(shiftval,u8inttype,false),
                        CCallParaNode.create(CTempRefNode.create(temp),nil))
                      ),
                      COrdConstNode.create(TCGInt((qword(1) shl power)-1),
                        right.resultdef,false)
                    );
                addstatement(statements,CAssignmentNode.create(CTempRefNode.create(resulttemp),masknode));

                { result:=((left+mask) and right)-mask; }
                addstatement(statements,CAssignmentNode.create(CTempRefNode.create(resulttemp),
                  CAddNode.create(subn,
                    CAddNode.create(andn,
                      right,
                      CAddNode.create(addn,
                        CTempRefNode.create(temp),
                        CTempRefNode.create(resulttemp))),
                  CTempRefNode.create(resulttemp))
                ));

                addstatement(statements,CTempDeleteNode.create(temp));
                addstatement(statements,CTempDeleteNode.create_normal_temp(resulttemp));
                addstatement(statements,CTempRefNode.create(resulttemp));
              end
            else
              begin
                TOrdConstNode(right).value.uvalue:=qword((qword(1) shl power)-1);
                result := CAddNode.create(andn,left,right);
              end;
            { left and right are reused }
            left := nil;
            right := nil;
            FirstPass(result);
            exit;
          end;
      end;


    function TModDivNode.pass_1 : TNode;
      begin
         result:=nil;
         FirstPass(left);
         FirstPass(right);
         if CodeGenError then
           exit;

         { Try to optimize mod/div }
         result := firstoptimize;
         if Assigned(result) then
           exit;

         { 64bit }
         if use_moddiv64bitint_helper then
           begin
             result := first_moddiv64bitint;
             if Assigned(result) then
               exit;
             expectloc:=LOC_REGISTER;
           end
         else
           begin
             result := first_moddivint;
             if Assigned(result) then
               exit;
           end;
         expectloc:=LOC_REGISTER;
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TModDivNode.XMLPrintNodeInfo(var T: Text);
      var
        i: TModDivNodeFlag;
        First: Boolean;
      begin
        inherited XMLPrintNodeInfo(T);
        First := True;
        for i in moddivnodeflags do
          begin
            if First then
              begin
                Write(T, ' moddivnodeflags="', i);
                First := False;
              end
            else
              Write(T, ',', i)
          end;
        if not First then
          Write(T, '"');
      end;
{$endif DEBUG_NODE_XML}

{****************************************************************************
                              TSHLSHRNODE
 ****************************************************************************}

    function TShlShrNode.simplify(forinline : boolean):TNode;
      var
        lvalue, rvalue, mask : TConstExprInt;
        rangedef: TDef;
        size: LongInt;
      begin
        result:=nil;
        { constant folding }
        if is_constintnode(right) then
          begin
            if forinline then
              begin
                case resultdef.size of
                  1,2,4:
                    rvalue:=TOrdConstNode(right).value and byte($1f);
                  8:
                    rvalue:=TOrdConstNode(right).value and byte($3f);
                  else
                    InternalError(2013122302);
                end;
              end
            else
              rvalue:=TOrdConstNode(right).value;
            if is_constintnode(left) then
               begin
                 lvalue:=TOrdConstNode(left).value;
                 getrangedefmasksize(resultdef, rangedef, mask, size);
                 { shr is an unsigned operation, so cut off upper bits }
                 if forinline then
                   lvalue:=lvalue and mask;
                 case nodetype of
                    shrn:
                      lvalue:=lvalue shr rvalue;
                    shln:
                      lvalue:=lvalue shl rvalue;
                    else
                      InternalError(2019050517);
                 end;
                 { discard shifted-out bits (shl never triggers overflow/range errors) }
                 if forinline and
                    (nodetype=shln) then
                   lvalue:=lvalue and mask;
                 result:=create_simplified_ord_const(lvalue,resultdef,forinline,false);
               end
            else if rvalue=0 then
              begin
                result:=left;
                left:=nil;
              end
            { optimize "a shl n1 shl n2" and "a shr n1 shr n2" }
            else if (nodetype=left.nodetype) and is_constintnode(TShlShrNode(left).right) and
              { do not overflow the variable being shifted }
              (TOrdConstNode(right).value+TOrdConstNode(TShlShrNode(left).right).value<TShlShrNode(left).left.resultdef.size*8) then
              begin
                result:=left;
                left:=nil;
                TOrdConstNode(TShlShrNode(result).right).value:=TOrdConstNode(TShlShrNode(result).right).value+TOrdConstNode(right).value;
              end;
          end
        else if is_constintnode(left) then
          begin
            lvalue:=TOrdConstNode(left).value;
            if forinline then
              begin
                getrangedefmasksize(resultdef, rangedef, mask, size);
                lvalue:=lvalue and mask;
              end;
            { '0 shl x' and '0 shr x' are 0 }
            if (lvalue=0) and
               ((cs_opt_level4 in CurrentSettings.OptimizerSwitches) or
                not might_have_sideeffects(right)) then
              result:=COrdConstNode.create(0,resultdef,true);
          end;
      end;


    function TShlShrNode.pass_typecheck:TNode;
      var
         t : TNode;
      begin
         result:=nil;
         TypeCheckPass(left);
         TypeCheckPass(right);

         { avoid any problems with type parameters later on }
         if is_typeparam(left.resultdef) or is_typeparam(right.resultdef) then
           begin
             resultdef:=cundefinedtype;
             exit;
           end;

         set_varstate(right,vs_read,[vsf_must_be_valid]);
         set_varstate(left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         { tp procvar support }
         maybe_call_procvar(left,true);
         maybe_call_procvar(right,true);

         { allow operator overloading }
         t:=self;
         if isbinaryoverloaded(t,[]) then
           begin
              result:=t;
              exit;
           end;

{$ifdef SUPPORT_MMX}
         if (cs_mmx in CurrentSettings.LocalSwitches) and
           is_mmx_able_array(left.resultdef) and
           ((is_mmx_able_array(right.resultdef) and
             equal_defs(left.resultdef,right.resultdef)
            ) or is_constintnode(right)) then
           begin
             if not(mmx_type(left.resultdef) in [mmxu16bit,mmxs16bit,mmxfixed16,mmxu32bit,mmxs32bit,mmxu64bit,mmxs64bit]) then
               CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),left.resultdef.typename,right.resultdef.typename);
             if not(is_mmx_able_array(right.resultdef)) then
               inserttypeconv(right,sinttype);
           end
         else
{$endif SUPPORT_MMX}
           begin
             { calculations for ordinals < 32 bit have to be done in
               32 bit for backwards compatibility. That way 'shl 33' is
               the same as 'shl 1'. It's ugly but compatible with delphi/tp/gcc }
             if (not is_64bit(left.resultdef)) and
                (TOrdDef(left.resultdef).ordtype<>u32bit) then
               begin
                 { keep signedness of original type }
                 if is_signed(left.resultdef) then
                   begin
{$if defined(cpu64bitalu) or defined(cpu32bitalu)}
                     inserttypeconv(left,s32inttype)
{$else}
                     InternalError(2013031301);
{$endif}
                   end
                 else
                   begin
{$if defined(cpu64bitalu) or defined(cpu32bitalu)}
                     inserttypeconv(left,u32inttype);
{$else}
                     InternalError(2013031302);
{$endif}
                   end
               end;

             inserttypeconv(right,sinttype);
           end;

         resultdef:=left.resultdef;

         result:=simplify(false);
         if Assigned(result) then
           exit;
      end;


{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
    function TShlShrNode.first_shlshr64bitint: TNode;
      var
        procname: string[31];
      begin
        result := nil;
        { Normally already done below, but called again,
          just in case it is called directly }
        FirstPass(left);
        { otherwise create a call to a helper }
        if is_signed(left.resultdef) then
          procname:='int64'
        else
          procname:='qword';
        if nodetype = shln then
          procname := 'fpc_shl_'+procname
        else
          procname := 'fpc_shr_'+procname;
        { this order of parameters works at least for the arm,
          however it should work for any calling conventions (FK) }
        result := CCallNode.createintern(procname,CCallParaNode.create(right,
          CCallParaNode.create(left,nil)));
        left := nil;
        right := nil;
        FirstPass(result);
      end;
{$endif not cpu64bitalu and not cpuhighleveltarget}


    function TShlShrNode.pass_1 : TNode;
      begin
         result:=nil;
         FirstPass(left);
         FirstPass(right);
         if CodeGenError then
           exit;

         expectloc:=LOC_REGISTER;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         { 64 bit ints have their own shift handling }
         if is_64bit(left.resultdef) then
           result := first_shlshr64bitint;
{$endif not cpu64bitalu and not cpuhighleveltarget}
      end;


{****************************************************************************
                            TUNARYMINUSNODE
 ****************************************************************************}

    constructor TUnaryMinusNode.create(expr : TNode);
      begin
        inherited create(unaryminusn,expr);
      end;


    function TUnaryMinusNode.simplify(forinline : boolean):TNode;
      begin
        result:=nil;
        { constant folding }
        if is_constintnode(left) then
          begin
             result:=create_simplified_ord_const(-TOrdConstNode(left).value,resultdef,forinline,cs_check_overflow in LocalSwitches);
             exit;
          end;
        if is_constrealnode(left) then
          begin
             TRealConstNode(left).NegateValue;
             result:=left;
             left:=nil;
             exit;
          end;
        if is_real(left.resultdef) then
          begin
            {
              -(left-right) => right-left

              As this result in -(1.0-1.0)=0.0 instead of 0.0, this is only valid in fastmath mode
            }
            if (cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and (left.nodetype=subn) then
              begin
                result:=CAddNode.create(subn,TAddNode(left).right.getcopy,TAddNode(left).left.getcopy);
                exit;
              end;

            {
              -(-left*right) or -(left*-right) => right*left

              this operation is always valid as reals do not use a two's complement representation for negative
              numbers, -real means just flip the sign bit
            }
            if (left.nodetype=muln) and ((TAddNode(left).left.nodetype=unaryminusn)) then
              begin
                result:=CAddNode.create(muln,TUnaryMinusNode(TAddNode(left).left).left.getcopy,TAddNode(left).right.getcopy);
                exit;
              end;
            if (left.nodetype=muln) and ((TAddNode(left).right.nodetype=unaryminusn)) then
              begin
                result:=CAddNode.create(muln,TAddNode(left).left.getcopy,TUnaryMinusNode(TAddNode(left).right).left.getcopy);
                exit;
              end;

            {
              -(-left/right) or -(left/-right) => right/left

              this operation is always valid as reals do not use a two's complement representation for negative
              numbers, -real means just flip the sign bit
            }
            if (left.nodetype=slashn) and ((TAddNode(left).left.nodetype=unaryminusn)) then
              begin
                result:=CAddNode.create(slashn,TUnaryMinusNode(TAddNode(left).left).left.getcopy,TAddNode(left).right.getcopy);
                exit;
              end;
            if (left.nodetype=slashn) and ((TAddNode(left).right.nodetype=unaryminusn)) then
              begin
                result:=CAddNode.create(slashn,TAddNode(left).left.getcopy,TUnaryMinusNode(TAddNode(left).right).left.getcopy);
                exit;
              end;

            { --node => node
              this operation is always valid as reals do not use a two's complement representation for negative
              numbers, -real means just flip the sign bit
            }
            if left.nodetype=unaryminusn then
              begin
                result:=TUnaryNode(left).left.getcopy;
                exit;
              end;
          end
        { transform -(x+1) or -(1+x) into not(x) }
        else if is_integer(left.resultdef) and is_signed(left.resultdef) and (left.nodetype=addn) and ((LocalSwitches*[cs_check_overflow,cs_check_range])=[]) then
          begin
            if is_constintnode(TAddNode(left).right) and (TOrdConstNode(TAddNode(left).right).value=1) then
              begin
                result:=CNotNode.create(TAddNode(left).left.getcopy);
                exit;
              end
            else if is_constintnode(TAddNode(left).left) and (TOrdConstNode(TAddNode(left).left).value=1) then
              begin
                result:=CNotNode.create(TAddNode(left).right.getcopy);
                exit;
              end;
          end;
      end;


    function TUnaryMinusNode.pass_typecheck : TNode;
      var
         t : TNode;
      begin
         result:=nil;
         TypeCheckPass(left);

         { avoid any problems with type parameters later on }
         if is_typeparam(left.resultdef) then
           begin
             resultdef:=cundefinedtype;
             exit;
           end;

         set_varstate(left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         result:=simplify(false);
         if Assigned(result) then
           exit;

         resultdef:=left.resultdef;
         if is_currency(left.resultdef) then
           begin
             { negating a currency value does not change its scaling, so the
               result is scaled exactly like the operand }
             if nf_is_currency in left.flags then
               Include(flags,nf_is_currency);
           end
         else if left.resultdef.typ=floatdef then
           begin
             if not(TFloatDef(left.resultdef).floattype in [s64comp,s64currency]) and
               (cs_excessprecision in CurrentSettings.LocalSwitches) then
               begin
                 inserttypeconv(left,pbestrealtype^);
                 resultdef:=left.resultdef
               end;
           end
{$ifdef SUPPORT_MMX}
         else if (cs_mmx in CurrentSettings.LocalSwitches) and
           is_mmx_able_array(left.resultdef) then
             begin
               { if saturation is on, left.resultdef isn't
                 "mmx able" (FK)
               if (cs_mmx_saturation in current_settings.localswitches^) and
                 (torddef(tarraydef(resultdef).definition).typ in
                 [s32bit,u32bit]) then
                 CGMessage(type_e_mismatch);
               }
             end
{$endif SUPPORT_MMX}
         else if is_oversizedord(left.resultdef) then
           begin
             if is_64bit(left.resultdef) then
               inserttypeconv(left,s64inttype)
             else if is_32bit(left.resultdef) then
               inserttypeconv(left,s32inttype)
             else if is_16bit(left.resultdef) then
               inserttypeconv(left,s16inttype)
             else
               InternalError(2013040701);
             resultdef:=left.resultdef;
           end
         else if (left.resultdef.typ=orddef) then
           begin
             inserttypeconv(left,sinttype);
             resultdef:=left.resultdef
           end
         else
           begin
             { allow operator overloading }
             t:=self;
             if isunaryoverloaded(t,[]) then
               begin
                  result:=t;
                  exit;
               end;

             CGMessage(type_e_mismatch);
           end;
      end;

    { generic code     }
    { overridden by:   }
    {   i386           }
    function TUnaryMinusNode.pass_1 : TNode;
      begin
        result:=nil;
        FirstPass(left);
        if CodeGenError then
          exit;

        if (left.resultdef.typ=floatdef) then
          expectloc:=LOC_FPUREGISTER
{$ifdef SUPPORT_MMX}
        else if (cs_mmx in CurrentSettings.LocalSwitches) and
          is_mmx_able_array(left.resultdef) then
          expectloc:=LOC_MMXREGISTER
{$endif SUPPORT_MMX}
        else if (left.resultdef.typ=orddef) then
          expectloc:=LOC_REGISTER;
      end;

{****************************************************************************
                             TUNARYPLUSNODE
 ****************************************************************************}

    constructor TUnaryPlusNode.create(expr: TNode);
      begin
        inherited create(unaryplusn,expr);
      end;

    function TUnaryPlusNode.pass_1: TNode;
      begin
        result:=nil;
        { can never happen because all the conversions happen
          in pass_typecheck }
        InternalError(201012250);
      end;

    function TUnaryPlusNode.pass_typecheck: TNode;
      var
        t:TNode;
      begin
        result:=nil;
        TypeCheckPass(left);

        { avoid any problems with type parameters later on }
        if is_typeparam(left.resultdef) then
          begin
            resultdef:=cundefinedtype;
            exit;
          end;

        set_varstate(left,vs_read,[vsf_must_be_valid]);
        if CodeGenError then
          exit;

        if is_constintnode(left) or
           is_constrealnode(left) or
           (left.resultdef.typ=floatdef) or
           is_currency(left.resultdef)
{$ifdef SUPPORT_MMX}
           or ((cs_mmx in CurrentSettings.LocalSwitches) and
                is_mmx_able_array(left.resultdef))
{$endif SUPPORT_MMX}
        then
          begin
            result:=left;
            left:=nil;
          end
        else if is_oversizedord(left.resultdef) then
          begin
            if is_64bit(left.resultdef) then
              inserttypeconv(left,s64inttype)
            else if is_32bit(left.resultdef) then
              inserttypeconv(left,s32inttype)
            else if is_16bit(left.resultdef) then
              inserttypeconv(left,s16inttype)
            else
              InternalError(2013040702);
            result:=left;
            left:=nil;
          end
        else if (left.resultdef.typ=orddef) then
          begin
            inserttypeconv(left,sinttype);
            result:=left;
            left:=nil;
          end
        else
          begin
            { allow operator overloading }
            t:=self;
            if isunaryoverloaded(t,[]) then
              begin
                result:=t;
                exit;
             end;

             CGMessage(type_e_mismatch);
           end;
      end;


{****************************************************************************
                               TNOTNODE
 ****************************************************************************}

    const
      boolean_reverse:array[ltn..unequaln] of TNodeType=(
        gten,gtn,lten,ltn,unequaln,equaln
      );

    constructor TNotNode.create(expr : TNode);
      begin
         inherited create(notn,expr);
      end;


    function TNotNode.simplify(forinline : boolean):TNode;
      var
        v : TConstExprInt;
        t : TNode;
        def : TDef;
      begin
        result:=nil;
        { Try optimizing ourself away }
        if left.nodetype=notn then
          begin
            { Double not. Remove both }
            result:=TNotNode(left).left;
            TNotNode(left).left:=nil;
            exit;
          end;

        if (left.nodetype in [ltn,lten,equaln,unequaln,gtn,gten]) then
         begin
           { Not of boolean expression. Turn around the operator and remove
             the not. This is not allowed for sets with the gten/lten,
             because there is no ltn/gtn support }
           if (TAddNode(left).left.resultdef.typ<>setdef) or
              (left.nodetype in [equaln,unequaln]) then
            begin
              result:=left;
              left.nodetype:=boolean_reverse[left.nodetype];
              left:=nil;
              exit;
            end;
         end;

        { constant folding }
        if (left.nodetype=ordconstn) and
          (left.resultdef.typ=orddef) then
          begin
             v:=TOrdConstNode(left).value;
             def:=left.resultdef;
             if not calc_not_ordvalue(v,def) then
               CGMessage(type_e_mismatch);
             { not-nodes are not range checked by the code generator -> also
               don't range check while inlining; the resultdef is a bit tricky
               though: the node's resultdef gets changed in most cases compared
               to left, but the not-operation itself is carried out in the code
               generator using the size of left
               }
             if not(forinline) then
               t:=COrdConstNode.create(v,def,false)
             else
               begin
                 { cut off the value if necessary }
                 t:=COrdConstNode.create(v,left.resultdef,false);
                 { now convert to node's resultdef }
                 inserttypeconv_explicit(t,def);
               end;
             result:=t;
             exit;
          end;
      end;


    function TNotNode.pass_typecheck : TNode;
      var
         t : TNode;
      begin
         result:=nil;
         TypeCheckPass(left);

         { avoid any problems with type parameters later on }
         if is_typeparam(left.resultdef) then
           begin
             resultdef:=cundefinedtype;
             exit;
           end;

         set_varstate(left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         { tp procvar support }
         maybe_call_procvar(left,true);

         resultdef:=left.resultdef;

         result:=simplify(false);
         if Assigned(result) then
           exit;

         if is_boolean(resultdef) then
           begin
           end
         else
{$ifdef SUPPORT_MMX}
           if (cs_mmx in CurrentSettings.LocalSwitches) and
             is_mmx_able_array(left.resultdef) then
             begin
             end
         else
{$endif SUPPORT_MMX}
{$ifndef cpu64bitaddr}
           if is_64bitint(left.resultdef) then
             begin
             end
         else
{$endif not cpu64bitaddr}
           if is_integer(left.resultdef) then
             begin
             end
         else
           begin
             { allow operator overloading }
             t:=self;
             if isunaryoverloaded(t,[]) then
               begin
                  result:=t;
                  exit;
               end;

             CGMessage(type_e_mismatch);
           end;
      end;


    function TNotNode.pass_1 : TNode;
      begin
         result:=nil;
         FirstPass(left);
         if CodeGenError then
           exit;

         expectloc:=left.expectloc;
         if is_boolean(resultdef) then
           begin
             if (expectloc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_CREGISTER]) then
               expectloc:=LOC_REGISTER;
             { xtensa has boolean registers which are treated as flags but they
               are not used for boolean expressions }
{$if defined(cpuflags)}
             if left.expectloc<>LOC_JUMP then
               expectloc:=LOC_FLAGS;
{$endif defined(cpuflags) and not(defined(xtensa)}
           end
         else
{$ifdef SUPPORT_MMX}
           if (cs_mmx in CurrentSettings.LocalSwitches) and
             is_mmx_able_array(left.resultdef) then
             expectloc:=LOC_MMXREGISTER
         else
{$endif SUPPORT_MMX}
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
           if is_64bit(left.resultdef) then
             begin
                if (expectloc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_CREGISTER]) then
                  expectloc:=LOC_REGISTER;
             end
         else
{$endif not cpu64bitalu and not cpuhighleveltarget}
           if is_integer(left.resultdef) then
             expectloc:=LOC_REGISTER;
      end;

{$ifdef state_tracking}
    function TNotNode.track_state_pass(exec_known:boolean):boolean;
      begin
        track_state_pass:=true;
        if left.track_state_pass(exec_known) then
          begin
            left.resultdef:=nil;
            DoTypeCheckPass(left);
          end;
      end;
{$endif}

end.
