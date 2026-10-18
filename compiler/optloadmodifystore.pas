{
    Copyright (c) 2017 by Nikolay Nikolov

    Optimizations for making use of load-modify-store operations in CISC-like
    instruction set architectures (such as x86)

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

unit optloadmodifystore;

{$i fpcdefs.inc}

{$if defined(i386) or defined(x86_64)}
  {$define enable_shl_shr_assign_x_y}
{$endif}
{$if defined(i386) or defined(x86_64)}
  {$define enable_sar_assign_x_y}
{$endif}
{$if defined(i386) or defined(x86_64)}
  {$define enable_rox_assign_x_y}
{$endif}

  interface

    uses
      node,nld;

    procedure do_optloadmodifystore(var rootnode : TNode);
    function try_opt_assignmentnode(assignmentnode : TAssignmentNode): TNode;

  implementation

    uses
      GlobType,Globals,Verbose,nutils,compinnr,
      defutil,defcmp,htypechk,Pass_1,ConstExp,
      nadd,ncal,ncon,ncnv,ninl,nmat,
      symdef;

    function try_opt_assignmentnode(assignmentnode: TAssignmentNode): TNode;

      var
        newinlinenodetype: TInlineNumber;

      begin
        result:=nil;

        with assignmentnode do
          begin
            { *** Here are simple optimizations which are performed
              when -O2 (via a call from tassignmentnode.simplify) or
              when cs_opt_use_load_modify_store is enabled (in a separate pass).
            }
            { replace i:=succ/pred(i) by inc/dec(i)? }
            if (right.nodetype=inlinen) and
              ((TInlineNode(right).InlineNumber=in_succ_x) or (TInlineNode(right).InlineNumber=in_pred_x)) and
              (TInlineNode(right).left.IsEqual(left)) and
              ((LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
              ((right.LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
              Valid_For_Var(TInlineNode(right).left,false) and
              not(Might_Have_SideEffects(TInlineNode(right).left)) then
              begin
                if TInlineNode(right).InlineNumber=in_succ_x then
                  newinlinenodetype:=in_inc_x
                else
                  newinlinenodetype:=in_dec_x;
                result:=CInlineNode.CreateIntern(
                  newinlinenodetype,false,CCallParaNode.Create(
                  TInlineNode(right).left,nil));
                result.LocalSwitches:=LocalSwitches;
                result.fileinfo:=fileinfo;
                result.verbosity:=verbosity;
                TInlineNode(right).left:=nil;
                exit;
              end;
            { replace i:=i+k by inc(i,k)
                      i:=i-k by dec(i,k)
                      i:=i and/or/xor k  by in_[and/or/xor]_assign_x_y(i,k)

              this handles the case, where there are no implicit type conversions }
            if (right.nodetype in [addn,subn,andn,orn,xorn]) and
              (TAddNode(right).left.IsEqual(left)) and
              Is_Integer(TAddNode(right).left.resultdef) and
              Is_Integer(TAddNode(right).right.resultdef) and
              ((LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
              ((right.LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
              Valid_For_Var(TAddNode(right).left,false) and
              not(Might_Have_SideEffects(TAddNode(right).left)) then
              begin
                case right.nodetype of
                  addn:
                    newinlinenodetype:=in_inc_x;
                  subn:
                    newinlinenodetype:=in_dec_x;
                  andn:
                    newinlinenodetype:=in_and_assign_x_y;
                  orn:
                    newinlinenodetype:=in_or_assign_x_y;
                  xorn:
                    newinlinenodetype:=in_xor_assign_x_y;
                  else
                    InternalError(2017032901);
                end;
                if right.nodetype in [addn,subn] then
                  result:=CInlineNode.CreateIntern(
                    newinlinenodetype,false,CCallParaNode.Create(
                    TAddNode(right).left,CCallParaNode.Create(TAddNode(right).right,nil)))
                else
                  result:=CInlineNode.CreateIntern(
                    newinlinenodetype,false,CCallParaNode.Create(
                    TAddNode(right).right,CCallParaNode.Create(TAddNode(right).left,nil)));
                result.LocalSwitches:=LocalSwitches;
                result.fileinfo:=fileinfo;
                result.verbosity:=verbosity;
                TAddNode(right).left:=nil;
                TAddNode(right).right:=nil;
                exit;
              end;
            { replace i:=i+k by inc(i,k)
                      i:=i-k by dec(i,k)
                      i:=i and/or/xor k  by in_[and/or/xor]_assign_x_y(i,k)

              this handles the case with two conversions (outer and inner):
                   outer typeconv: right
               add/sub/and/or/xor: ttypeconvnode(right).left
                   inner typeconv: taddnode(ttypeconvnode(right).left).left
                   right side 'i': ttypeconvnode(taddnode(ttypeconvnode(right).left).left).left
                   right side 'k': taddnode(ttypeconvnode(right).left).right }
            if (right.nodetype=typeconvn) and
               (TTypeConvNode(right).ConvType=tc_int_2_int) and
               (TTypeConvNode(right).left.nodetype in [addn,subn,andn,orn,xorn]) and
               Is_Integer(TTypeConvNode(right).left.resultdef) and
               (right.resultdef.Size<=TTypeConvNode(right).left.resultdef.Size) and
               (TAddNode(TTypeConvNode(right).left).left.nodetype=typeconvn) and
               (TTypeConvNode(TAddNode(TTypeConvNode(right).left).left).ConvType=tc_int_2_int) and
               Are_Equal_Ints(right.resultdef,TTypeConvNode(TAddNode(TTypeConvNode(right).left).left).left.resultdef) and
               TTypeConvNode(TAddNode(TTypeConvNode(right).left).left).left.IsEqual(left) and
               Is_Integer(TAddNode(TTypeConvNode(right).left).left.resultdef) and
               Is_Integer(TAddNode(TTypeConvNode(right).left).right.resultdef) and
               Is_Integer(TTypeConvNode(TAddNode(TTypeConvNode(right).left).left).left.resultdef) and
               ((LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               ((right.LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               Valid_For_Var(TTypeConvNode(TAddNode(TTypeConvNode(right).left).left).left,false) and
               not(Might_Have_SideEffects(TTypeConvNode(TAddNode(TTypeConvNode(right).left).left).left)) then
              begin
                case TTypeConvNode(right).left.nodetype of
                  addn:
                    newinlinenodetype:=in_inc_x;
                  subn:
                    newinlinenodetype:=in_dec_x;
                  andn:
                    newinlinenodetype:=in_and_assign_x_y;
                  orn:
                    newinlinenodetype:=in_or_assign_x_y;
                  xorn:
                    newinlinenodetype:=in_xor_assign_x_y;
                  else
                    InternalError(2017032903);
                end;
                InsertTypeConv_Internal(TAddNode(TTypeConvNode(right).left).right,left.resultdef);
                if TTypeConvNode(right).left.nodetype in [addn,subn] then
                  result:=CInlineNode.CreateIntern(
                    newinlinenodetype,false,CCallParaNode.Create(
                    TTypeConvNode(TAddNode(TTypeConvNode(right).left).left).left,CCallParaNode.Create(TAddNode(TTypeConvNode(right).left).right,nil)))
                else
                  result:=CInlineNode.CreateIntern(
                    newinlinenodetype,false,CCallParaNode.Create(
                    TAddNode(TTypeConvNode(right).left).right,CCallParaNode.Create(TTypeConvNode(TAddNode(TTypeConvNode(right).left).left).left,nil)));
                result.LocalSwitches:=LocalSwitches;
                result.fileinfo:=fileinfo;
                result.verbosity:=verbosity;
                TTypeConvNode(TAddNode(TTypeConvNode(right).left).left).left:=nil;
                TAddNode(TTypeConvNode(right).left).right:=nil;
                exit;
              end;
            { replace i:=k+i by inc(i,k)
                      i:=k and/or/xor i  by in_[and/or/xor]_assign_x_y(i,k)

              this handles the case, where there are no implicit type conversions }
            if (right.nodetype in [addn,andn,orn,xorn]) and
              (TAddNode(right).right.IsEqual(left)) and
              Is_Integer(TAddNode(right).left.resultdef) and
              Is_Integer(TAddNode(right).right.resultdef) and
              ((LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
              ((right.LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
              Valid_For_Var(TAddNode(right).right,false) and
              not(Might_Have_SideEffects(TAddNode(right).right)) then
              begin
                case right.nodetype of
                  addn:
                    newinlinenodetype:=in_inc_x;
                  andn:
                    newinlinenodetype:=in_and_assign_x_y;
                  orn:
                    newinlinenodetype:=in_or_assign_x_y;
                  xorn:
                    newinlinenodetype:=in_xor_assign_x_y;
                  else
                    InternalError(2017032902);
                end;
                if right.nodetype=addn then
                  result:=CInlineNode.CreateIntern(
                    newinlinenodetype,false,CCallParaNode.Create(
                    TAddNode(right).right,CCallParaNode.Create(TAddNode(right).left,nil)))
                else
                  result:=CInlineNode.CreateIntern(
                    newinlinenodetype,false,CCallParaNode.Create(
                    TAddNode(right).left,CCallParaNode.Create(TAddNode(right).right,nil)));
                result.LocalSwitches:=LocalSwitches;
                result.fileinfo:=fileinfo;
                result.verbosity:=verbosity;
                TAddNode(right).right:=nil;
                TAddNode(right).left:=nil;
                exit;
              end;
            { replace i:=k+i by inc(i,k)
                      i:=k and/or/xor i  by in_[and/or/xor]_assign_x_y(i,k)

              this handles the case with two conversions (outer and inner):
                   outer typeconv: right
                   add/and/or/xor: ttypeconvnode(right).left
                   inner typeconv: taddnode(ttypeconvnode(right).left).right
                   right side 'i': ttypeconvnode(taddnode(ttypeconvnode(right).left).right).left
                   right side 'k': taddnode(ttypeconvnode(right).left).left }
            if (right.nodetype=typeconvn) and
               (TTypeConvNode(right).ConvType=tc_int_2_int) and
               (TTypeConvNode(right).left.nodetype in [addn,andn,orn,xorn]) and
               Is_Integer(TTypeConvNode(right).left.resultdef) and
               (right.resultdef.Size<=TTypeConvNode(right).left.resultdef.Size) and
               (TAddNode(TTypeConvNode(right).left).right.nodetype=typeconvn) and
               (TTypeConvNode(TAddNode(TTypeConvNode(right).left).right).ConvType=tc_int_2_int) and
               Are_Equal_Ints(right.resultdef,TTypeConvNode(TAddNode(TTypeConvNode(right).left).right).left.resultdef) and
               TTypeConvNode(TAddNode(TTypeConvNode(right).left).right).left.IsEqual(left) and
               Is_Integer(TAddNode(TTypeConvNode(right).left).left.resultdef) and
               Is_Integer(TAddNode(TTypeConvNode(right).left).right.resultdef) and
               Is_Integer(TTypeConvNode(TAddNode(TTypeConvNode(right).left).right).left.resultdef) and
               ((LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               ((right.LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               Valid_For_Var(TTypeConvNode(TAddNode(TTypeConvNode(right).left).right).left,false) and
               not(Might_Have_SideEffects(TTypeConvNode(TAddNode(TTypeConvNode(right).left).right).left)) then
              begin
                case TTypeConvNode(right).left.nodetype of
                  addn:
                    newinlinenodetype:=in_inc_x;
                  andn:
                    newinlinenodetype:=in_and_assign_x_y;
                  orn:
                    newinlinenodetype:=in_or_assign_x_y;
                  xorn:
                    newinlinenodetype:=in_xor_assign_x_y;
                  else
                    InternalError(2017051101);
                end;
                InsertTypeConv_Internal(TAddNode(TTypeConvNode(right).left).left,left.resultdef);
                if TTypeConvNode(right).left.nodetype=addn then
                  result:=CInlineNode.CreateIntern(
                    newinlinenodetype,false,CCallParaNode.Create(
                    TTypeConvNode(TAddNode(TTypeConvNode(right).left).right).left,CCallParaNode.Create(TAddNode(TTypeConvNode(right).left).left,nil)))
                else
                  result:=CInlineNode.CreateIntern(
                    newinlinenodetype,false,CCallParaNode.Create(
                    TAddNode(TTypeConvNode(right).left).left,CCallParaNode.Create(TTypeConvNode(TAddNode(TTypeConvNode(right).left).right).left,nil)));
                result.LocalSwitches:=LocalSwitches;
                result.fileinfo:=fileinfo;
                result.verbosity:=verbosity;
                TTypeConvNode(TAddNode(TTypeConvNode(right).left).right).left:=nil;
                TAddNode(TTypeConvNode(right).left).left:=nil;
                exit;
              end;
            { replace i:=not i  by in_not_assign_x(i)
                      i:=-i     by in_neg_assign_x(i)

              this handles the case, where there are no implicit type conversions }
            if (right.nodetype in [notn,unaryminusn]) and
              (TUnaryNode(right).left.IsEqual(left)) and
              Is_Integer(TUnaryNode(right).left.resultdef) and
              ((LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
              ((right.LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
              Valid_For_Var(TUnaryNode(right).left,false) and
              not(Might_Have_SideEffects(TUnaryNode(right).left)) then
              begin
                if right.nodetype=notn then
                  newinlinenodetype:=in_not_assign_x
                else
                  newinlinenodetype:=in_neg_assign_x;
                result:=CInlineNode.CreateIntern(
                  newinlinenodetype,false,TUnaryNode(right).left);
                result.LocalSwitches:=LocalSwitches;
                result.fileinfo:=fileinfo;
                result.verbosity:=verbosity;
                TUnaryNode(right).left:=nil;
                exit;
              end;
            { replace i:=not i  by in_not_assign_x(i)
                      i:=-i     by in_neg_assign_x(i)

              this handles the case with type conversions:
                   outer typeconv: right
                          neg/not: ttypeconvnode(right).left
                   inner typeconv: tunarynode(ttypeconvnode(right).left).left
                   right side 'i': ttypeconvnode(tunarynode(ttypeconvnode(right).left).left).left }
            if (right.nodetype=typeconvn) and
               (TTypeConvNode(right).ConvType=tc_int_2_int) and
               (TTypeConvNode(right).left.nodetype in [notn,unaryminusn]) and
               Is_Integer(TTypeConvNode(right).left.resultdef) and
               (right.resultdef.Size<=TTypeConvNode(right).left.resultdef.Size) and
               (TUnaryNode(TTypeConvNode(right).left).left.nodetype=typeconvn) and
               (TTypeConvNode(TUnaryNode(TTypeConvNode(right).left).left).ConvType=tc_int_2_int) and
               Are_Equal_Ints(right.resultdef,TTypeConvNode(TUnaryNode(TTypeConvNode(right).left).left).left.resultdef) and
               TTypeConvNode(TUnaryNode(TTypeConvNode(right).left).left).left.IsEqual(left) and
               Is_Integer(TTypeConvNode(TUnaryNode(TTypeConvNode(right).left).left).left.resultdef) and
               ((LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               ((right.LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               Valid_For_Var(TTypeConvNode(TUnaryNode(TTypeConvNode(right).left).left).left,false) and
               not(Might_Have_SideEffects(TTypeConvNode(TUnaryNode(TTypeConvNode(right).left).left).left)) then
              begin
                if TTypeConvNode(right).left.nodetype=notn then
                  newinlinenodetype:=in_not_assign_x
                else
                  newinlinenodetype:=in_neg_assign_x;
                result:=CInlineNode.CreateIntern(
                  newinlinenodetype,false,TTypeConvNode(TUnaryNode(TTypeConvNode(right).left).left).left);
                result.LocalSwitches:=LocalSwitches;
                result.fileinfo:=fileinfo;
                result.verbosity:=verbosity;
                TTypeConvNode(TUnaryNode(TTypeConvNode(right).left).left).left:=nil;
                exit;
              end;

            if not (cs_opt_use_load_modify_store in CurrentSettings.OptimizerSwitches) then
              exit;
            { *** Here are more complex optimizations which are performed only
              when cs_opt_use_load_modify_store is enabled.
            }
{$ifdef enable_shl_shr_assign_x_y}
            { replace i:=i shl k by in_shl_assign_x_y(i,k)
                      i:=i shr k by in_shr_assign_x_y(i,k)

              this handles the case, where there are no implicit type conversions }
            if (right.nodetype in [shln,shrn]) and
              (TShlShrNode(right).left.IsEqual(left)) and
              Is_Integer(TShlShrNode(right).left.resultdef) and
              Is_Integer(TShlShrNode(right).right.resultdef) and
{$if not defined(cpu64bitalu) and not defined(cpucg64shiftsupport)}
              not(Is_64BitInt(TShlShrNode(right).left.resultdef)) and
{$endif}
              ((LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
              ((right.LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
              Valid_For_Var(TShlShrNode(right).left,false) and
              not(Might_Have_SideEffects(TShlShrNode(right).left)) then
              begin
                case right.nodetype of
                  shln:
                    newinlinenodetype:=in_shl_assign_x_y;
                  shrn:
                    newinlinenodetype:=in_shr_assign_x_y;
                  else
                    InternalError(2017051201);
                end;
                result:=CInlineNode.CreateIntern(
                  newinlinenodetype,false,CCallParaNode.Create(
                  TShlShrNode(right).right,CCallParaNode.Create(TShlShrNode(right).left,nil)));
                result.LocalSwitches:=LocalSwitches;
                result.fileinfo:=fileinfo;
                result.verbosity:=verbosity;
                TShlShrNode(right).left:=nil;
                TShlShrNode(right).right:=nil;
                exit;
              end;
            { replace i:=i shl k by in_shl_assign_x_y(i,k)
                      i:=i shr k by in_shr_assign_x_y(i,k)

              this handles the case with two conversions (outer and inner):
                   outer typeconv: right
                          shl/shr: ttypeconvnode(right).left
                   inner typeconv: tshlshrnode(ttypeconvnode(right).left).left
                   right side 'i': ttypeconvnode(tshlshrnode(ttypeconvnode(right).left).left).left
                   right side 'k': tshlshrnode(ttypeconvnode(right).left).right }
            if (right.nodetype=typeconvn) and
               (TTypeConvNode(right).ConvType=tc_int_2_int) and
               (TTypeConvNode(right).left.nodetype in [shln,shrn]) and
               Is_Integer(TTypeConvNode(right).left.resultdef) and
{$if not defined(cpu64bitalu) and not defined(cpucg64shiftsupport)}
               not(Is_64BitInt(TTypeConvNode(right).left.resultdef)) and
{$endif}
               (right.resultdef.Size<=TTypeConvNode(right).left.resultdef.Size) and
               (TShlShrNode(TTypeConvNode(right).left).left.nodetype=typeconvn) and
               (TTypeConvNode(TShlShrNode(TTypeConvNode(right).left).left).ConvType=tc_int_2_int) and
               Are_Equal_Ints(right.resultdef,TTypeConvNode(TShlShrNode(TTypeConvNode(right).left).left).left.resultdef) and
               TTypeConvNode(TShlShrNode(TTypeConvNode(right).left).left).left.IsEqual(left) and
               Is_Integer(TShlShrNode(TTypeConvNode(right).left).left.resultdef) and
               Is_Integer(TShlShrNode(TTypeConvNode(right).left).right.resultdef) and
               Is_Integer(TTypeConvNode(TShlShrNode(TTypeConvNode(right).left).left).left.resultdef) and
               ((LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               ((right.LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               Valid_For_Var(TTypeConvNode(TShlShrNode(TTypeConvNode(right).left).left).left,false) and
               not(Might_Have_SideEffects(TTypeConvNode(TShlShrNode(TTypeConvNode(right).left).left).left)) then
              begin
                case TTypeConvNode(right).left.nodetype of
                  shln:
                    newinlinenodetype:=in_shl_assign_x_y;
                  shrn:
                    newinlinenodetype:=in_shr_assign_x_y;
                  else
                    InternalError(2017051202);
                end;
                InsertTypeConv_Internal(TShlShrNode(TTypeConvNode(right).left).right,left.resultdef);
                result:=CInlineNode.CreateIntern(
                  newinlinenodetype,false,CCallParaNode.Create(
                  TShlShrNode(TTypeConvNode(right).left).right,CCallParaNode.Create(TTypeConvNode(TShlShrNode(TTypeConvNode(right).left).left).left,nil)));
                result.LocalSwitches:=LocalSwitches;
                result.fileinfo:=fileinfo;
                result.verbosity:=verbosity;
                TTypeConvNode(TShlShrNode(TTypeConvNode(right).left).left).left:=nil;
                TShlShrNode(TTypeConvNode(right).left).right:=nil;
                exit;
              end;
{$endif enable_shl_shr_assign_x_y}
{$if defined(enable_sar_assign_x_y) or defined(enable_rox_assign_x_y)}
            { replace i:=sar(i) by in_sar_assign_x_y(i,1)
                      i:=rol(i) by in_rol_assign_x_y(i,1)
                      i:=ror(i) by in_ror_assign_x_y(i,1)

              this handles the case, where there are no implicit type conversions }
            if (right.nodetype=inlinen) and
               (TInlineNode(right).InlineNumber in [
{$ifdef enable_sar_assign_x_y}
                   in_sar_x{$ifdef enable_rox_assign_x_y},{$endif}
{$endif enable_sar_assign_x_y}
{$ifdef enable_rox_assign_x_y}
                   in_rol_x,in_ror_x
{$endif enable_rox_assign_x_y}
                 ]) and
               (TInlineNode(right).left.IsEqual(left)) and
               Is_Integer(TInlineNode(right).left.resultdef) and
{$if not defined(cpu64bitalu) and not defined(cpucg64shiftsupport)}
               not(Is_64BitInt(TInlineNode(right).left.resultdef)) and
{$endif}
               ((LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               ((right.LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               Valid_For_Var(TInlineNode(right).left,false) and
               not(Might_Have_SideEffects(TInlineNode(right).left)) then
              begin
                case TInlineNode(right).InlineNumber of
                  in_sar_x:
                    newinlinenodetype:=in_sar_assign_x_y;
                  in_rol_x:
                    newinlinenodetype:=in_rol_assign_x_y;
                  in_ror_x:
                    newinlinenodetype:=in_ror_assign_x_y;
                  else
                    InternalError(2017071701);
                end;
                result:=CInlineNode.CreateIntern(
                  newinlinenodetype,false,CCallParaNode.Create(
                  COrdConstNode.Create(1,U8IntType,false),CCallParaNode.Create(TInlineNode(right).left,nil)));
                result.LocalSwitches:=LocalSwitches;
                result.fileinfo:=fileinfo;
                result.verbosity:=verbosity;
                TInlineNode(right).left:=nil;
                exit;
              end;
            { replace i:=sar(i) by in_sar_assign_x_y(i,1)
                      i:=rol(i) by in_rol_assign_x_y(i,1)
                      i:=ror(i) by in_ror_assign_x_y(i,1)

              this handles the case with type conversions:
                   outer typeconv: right
          sar/rol/ror inline node: ttypeconvnode(right).left
                   inner typeconv: tinlinenode(ttypeconvnode(right).left).left
                   right side 'i': ttypeconvnode(tinlinenode(ttypeconvnode(right).left).left).left }
            if (right.nodetype=typeconvn) and
               (TTypeConvNode(right).ConvType=tc_int_2_int) and
               (TTypeConvNode(right).left.nodetype=inlinen) and
               (TInlineNode(TTypeConvNode(right).left).InlineNumber in [
{$ifdef enable_sar_assign_x_y}
                   in_sar_x{$ifdef enable_rox_assign_x_y},{$endif}
{$endif enable_sar_assign_x_y}
{$ifdef enable_rox_assign_x_y}
                   in_rol_x,in_ror_x
{$endif enable_rox_assign_x_y}
                 ]) and
               Is_Integer(TTypeConvNode(right).left.resultdef) and
               (right.resultdef.Size=TTypeConvNode(right).left.resultdef.Size) and
               (TInlineNode(TTypeConvNode(right).left).left.nodetype=typeconvn) and
               (TTypeConvNode(TInlineNode(TTypeConvNode(right).left).left).ConvType=tc_int_2_int) and
               Are_Equal_Ints(right.resultdef,TTypeConvNode(TInlineNode(TTypeConvNode(right).left).left).left.resultdef) and
               TTypeConvNode(TInlineNode(TTypeConvNode(right).left).left).left.IsEqual(left) and
               Is_Integer(TTypeConvNode(TInlineNode(TTypeConvNode(right).left).left).left.resultdef) and
               ((LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               ((right.LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               Valid_For_Var(TTypeConvNode(TInlineNode(TTypeConvNode(right).left).left).left,false) and
               not(Might_Have_SideEffects(TTypeConvNode(TInlineNode(TTypeConvNode(right).left).left).left)) then
              begin
                case TInlineNode(TTypeConvNode(right).left).InlineNumber of
                  in_sar_x:
                    newinlinenodetype:=in_sar_assign_x_y;
                  in_rol_x:
                    newinlinenodetype:=in_rol_assign_x_y;
                  in_ror_x:
                    newinlinenodetype:=in_ror_assign_x_y;
                  else
                    InternalError(2017071801);
                end;
                result:=CInlineNode.CreateIntern(
                  newinlinenodetype,false,CCallParaNode.Create(
                  COrdConstNode.Create(1,U8IntType,false),CCallParaNode.Create(
                  TTypeConvNode(TInlineNode(TTypeConvNode(right).left).left).left,nil)));
                result.LocalSwitches:=LocalSwitches;
                result.fileinfo:=fileinfo;
                result.verbosity:=verbosity;
                TTypeConvNode(TInlineNode(TTypeConvNode(right).left).left).left:=nil;
                exit;
              end;
            { replace i:=sar(i,k) by in_sar_assign_x_y(i,k)
                      i:=rol(i,k) by in_rol_assign_x_y(i,k)
                      i:=ror(i,k) by in_ror_assign_x_y(i,k)

              this handles the case, where there are no implicit type conversions }
            if (right.nodetype=inlinen) and
               (TInlineNode(right).InlineNumber in [
{$ifdef enable_sar_assign_x_y}
                   in_sar_x_y{$ifdef enable_rox_assign_x_y},{$endif}
{$endif enable_sar_assign_x_y}
{$ifdef enable_rox_assign_x_y}
                   in_rol_x_y,in_ror_x_y
{$endif enable_rox_assign_x_y}
                 ]) and
               (TInlineNode(right).left.nodetype=callparan) and
               TCallParaNode(TCallParaNode(TInlineNode(right).left).right).left.IsEqual(left) and
               Is_Integer(TCallParaNode(TCallParaNode(TInlineNode(right).left).right).left.resultdef) and
{$if not defined(cpu64bitalu) and not defined(cpucg64shiftsupport)}
               not(Is_64BitInt(TCallParaNode(TCallParaNode(TInlineNode(right).left).right).left.resultdef)) and
{$endif}
               ((LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               ((right.LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               Valid_For_Var(TCallParaNode(TCallParaNode(TInlineNode(right).left).right).left,false) and
               not(Might_Have_SideEffects(TCallParaNode(TCallParaNode(TInlineNode(right).left).right).left)) then
              begin
                case TInlineNode(right).InlineNumber of
                  in_sar_x_y:
                    newinlinenodetype:=in_sar_assign_x_y;
                  in_rol_x_y:
                    newinlinenodetype:=in_rol_assign_x_y;
                  in_ror_x_y:
                    newinlinenodetype:=in_ror_assign_x_y;
                  else
                    InternalError(2017071702);
                end;
                result:=CInlineNode.CreateIntern(
                  newinlinenodetype,false,CCallParaNode.Create(
                  TCallParaNode(TInlineNode(right).left).left,
                  CCallParaNode.Create(TCallParaNode(TCallParaNode(TInlineNode(right).left).right).left,nil)));
                result.LocalSwitches:=LocalSwitches;
                result.fileinfo:=fileinfo;
                result.verbosity:=verbosity;
                TCallParaNode(TInlineNode(right).left).left:=nil;
                TCallParaNode(TCallParaNode(TInlineNode(right).left).right).left:=nil;
                exit;
              end;
            { replace i:=sar(i,k) by in_sar_assign_x_y(i,k)
                      i:=rol(i,k) by in_rol_assign_x_y(i,k)
                      i:=ror(i,k) by in_ror_assign_x_y(i,k)

              this handles the case with two conversions (outer and inner):
                   outer typeconv: right
          sar/rol/ror inline node: ttypeconvnode(right).left
                   inner typeconv: tcallparanode(tcallparanode(tinlinenode(ttypeconvnode(right).left).left).right).left
                   right side 'i': ttypeconvnode(tcallparanode(tcallparanode(tinlinenode(ttypeconvnode(right).left).left).right).left).left
                   right side 'k': tcallparanode(tinlinenode(ttypeconvnode(right).left).left).left }
            if (right.nodetype=typeconvn) and
               (TTypeConvNode(right).ConvType=tc_int_2_int) and
               (TTypeConvNode(right).left.nodetype=inlinen) and
               (TInlineNode(TTypeConvNode(right).left).InlineNumber in [
{$ifdef enable_sar_assign_x_y}
                   in_sar_x_y{$ifdef enable_rox_assign_x_y},{$endif}
{$endif enable_sar_assign_x_y}
{$ifdef enable_rox_assign_x_y}
                   in_rol_x_y,in_ror_x_y
{$endif enable_rox_assign_x_y}
                 ]) and
               Is_Integer(TTypeConvNode(right).left.resultdef) and
               (right.resultdef.Size=TTypeConvNode(right).left.resultdef.Size) and
               (TInlineNode(TTypeConvNode(right).left).left.nodetype=callparan) and
               (TCallParaNode(TCallParaNode(TInlineNode(TTypeConvNode(right).left).left).right).left.nodetype=typeconvn) and
               (TTypeConvNode(TCallParaNode(TCallParaNode(TInlineNode(TTypeConvNode(right).left).left).right).left).ConvType=tc_int_2_int) and
               Are_Equal_Ints(right.resultdef,TTypeConvNode(TCallParaNode(TCallParaNode(TInlineNode(TTypeConvNode(right).left).left).right).left).left.resultdef) and
               TTypeConvNode(TCallParaNode(TCallParaNode(TInlineNode(TTypeConvNode(right).left).left).right).left).left.IsEqual(left) and
               Is_Integer(TTypeConvNode(TCallParaNode(TCallParaNode(TInlineNode(TTypeConvNode(right).left).left).right).left).left.resultdef) and
               ((LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               ((right.LocalSwitches*[cs_check_overflow,cs_check_range])=[]) and
               Valid_For_Var(TTypeConvNode(TCallParaNode(TCallParaNode(TInlineNode(TTypeConvNode(right).left).left).right).left).left,false) and
               not(Might_Have_SideEffects(TTypeConvNode(TCallParaNode(TCallParaNode(TInlineNode(TTypeConvNode(right).left).left).right).left).left)) then
              begin
                case TInlineNode(TTypeConvNode(right).left).InlineNumber of
                  in_sar_x_y:
                    newinlinenodetype:=in_sar_assign_x_y;
                  in_rol_x_y:
                    newinlinenodetype:=in_rol_assign_x_y;
                  in_ror_x_y:
                    newinlinenodetype:=in_ror_assign_x_y;
                  else
                    InternalError(2017072002);
                end;
                result:=CInlineNode.CreateIntern(
                  newinlinenodetype,false,CCallParaNode.Create(
                  TCallParaNode(TInlineNode(TTypeConvNode(right).left).left).left,
                  CCallParaNode.Create(TTypeConvNode(TCallParaNode(TCallParaNode(TInlineNode(TTypeConvNode(right).left).left).right).left).left,nil)));
                result.LocalSwitches:=LocalSwitches;
                result.fileinfo:=fileinfo;
                result.verbosity:=verbosity;
                TCallParaNode(TInlineNode(TTypeConvNode(right).left).left).left:=nil;
                TTypeConvNode(TCallParaNode(TCallParaNode(TInlineNode(TTypeConvNode(right).left).left).right).left).left:=nil;
                exit;
              end;
{$endif enable_sar_assign_x_y or enable_rox_assign_x_y}
          end;

      end;

    function try_opt_node(var n: TNode; arg: pointer): TForEachNodeResult;
      var
        hn : TNode;
      begin
        result:=fen_false;
        if n.nodetype=assignn then
          begin
            hn:=try_opt_assignmentnode(TAssignmentNode(n));
            if Assigned(hn) then
              begin
                n.free;
                n:=hn;
                TypeCheckPass(n);
                DoFirstPass(n);
              end;
          end;
      end;


    procedure do_optloadmodifystore(var rootnode : TNode);
      begin

        ForEachNodeStatic(pm_postprocess,rootnode,@try_opt_node,nil);

      end;

end.

