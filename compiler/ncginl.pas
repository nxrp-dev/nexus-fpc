{
    Copyright (c) 1998-2002 by Florian Klaempfl and Carl Eric Codere

    Generate generic inline nodes

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
unit ncginl;

{$i fpcdefs.inc}

interface

    uses
       node,ninl,symtype;

    type
       TCGInlineNode = class(TInlineNode)
          procedure pass_generate_code;override;
          procedure pass_generate_code_cpu;virtual;
          procedure second_sizeoftypeof;virtual;
          procedure second_length;virtual;
          procedure second_predsucc;virtual;
          procedure second_incdec;virtual;
          procedure second_AndOrXorShiftRot_assign;virtual;
          procedure second_NegNot_assign;virtual;
          procedure second_typeinfo;virtual;
          procedure second_includeexclude;virtual;
          procedure second_pi; virtual;
          procedure second_arctan_real; virtual;
          procedure second_abs_real; virtual;
          procedure second_sqr_real; virtual;
          procedure second_sqrt_real; virtual;
          procedure second_ln_real; virtual;
          procedure second_cos_real; virtual;
          procedure second_sin_real; virtual;
          procedure second_assigned; virtual;
          procedure second_get_frame;virtual;
          procedure second_get_caller_frame;virtual;
          procedure second_get_caller_addr;virtual;
          procedure second_prefetch; virtual;
          procedure second_round_real; virtual;
          procedure second_trunc_real; virtual;
          procedure second_int_real; virtual;
          procedure second_abs_long; virtual;
          procedure second_rox_sar; virtual;
          procedure second_bsfbsr; virtual;
          procedure second_new; virtual;
          procedure second_setlength; virtual; abstract;
          procedure second_box; virtual; abstract;
          procedure second_popcnt; virtual;
          procedure second_seg; virtual; abstract;
          procedure second_fma; virtual;
          procedure second_frac_real; virtual;
          procedure second_high; virtual;
          procedure second_minmax; virtual;
       protected
          function  second_incdec_tempregdef: TDef;virtual;
       end;

implementation

    uses
      GlobType,ConstExp,
      Verbose,Globals,compinnr,
      symconst,symdef,defutil,
      aasmbase,AAsmData,
      cgbase,pass_2,
      cpubase,ProcInfo,
      nadd,ncon,ncal,nutils,
      tgobj,ncgutil,
      cgutils,cgobj,hlcgobj,
      defcmp
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
      ,cg64f32
{$endif not cpu64bitalu and not cpuhighleveltarget}
      ;


{*****************************************************************************
                              TCGINLINENODE
*****************************************************************************}


    procedure TCGInlineNode.pass_generate_code;
      begin
         Location_Reset(location,LOC_VOID,OS_NO);

         case inlinenumber of
            in_sizeof_x,
            in_typeof_x :
              second_SizeofTypeOf;
            in_length_x :
              second_Length;
            in_pred_x,
            in_succ_x:
               second_PredSucc;
            in_dec_x,
            in_inc_x :
              second_IncDec;
            in_typeinfo_x:
              second_TypeInfo;
            in_include_x_y,
            in_exclude_x_y:
              second_IncludeExclude;
            in_pi_real:
              second_pi;
            in_sin_real:
              second_sin_real;
            in_arctan_real:
              second_arctan_real;
            in_abs_real:
              second_abs_real;
            in_abs_long:
              second_abs_long;
            in_round_real:
              second_round_real;
            in_trunc_real:
              second_trunc_real;
            in_int_real:
              second_int_real;
            in_sqr_real:
              second_sqr_real;
            in_sqrt_real:
              second_sqrt_real;
            in_ln_real:
              second_ln_real;
            in_cos_real:
               second_cos_real;
            in_frac_real:
              second_frac_real;
            in_prefetch_var:
              second_prefetch;
            in_assigned_x:
              second_assigned;
            in_get_frame:
              second_get_frame;
            in_get_caller_frame:
              second_get_caller_frame;
            in_get_caller_addr:
              second_get_caller_addr;
            in_unaligned_x:
              begin
                SecondPass(TCallParaNode(left).left);
                location:=TCallParaNode(left).left.Location;
                if location.Loc in [LOC_CREFERENCE,LOC_REFERENCE] then
                  location.Reference.Alignment:=1
                else
                  message(parser_w_unaligned_useless);
              end;
            in_aligned_x:
              begin
                SecondPass(TCallParaNode(left).left);
                location:=TCallParaNode(left).left.Location;
                if location.Loc in [LOC_CREFERENCE,LOC_REFERENCE] then
                  location.Reference.Alignment:=resultdef.Alignment
                else
                  message(parser_w_aligned_useless);
              end;
            in_volatile_x:
              begin
                SecondPass(TCallParaNode(left).left);
                location:=TCallParaNode(left).left.Location;
                if location.Loc in [LOC_CREFERENCE,LOC_REFERENCE,LOC_SUBSETREF,LOC_CSUBSETREF] then
                  location.Reference.Volatility:=[vol_read,vol_write];
              end;
            in_rol_x,
            in_rol_x_y,
            in_ror_x,
            in_ror_x_y,
            in_sar_x,
            in_sar_x_y:
              second_rox_sar;
            in_bsf_x,
            in_bsr_x:
               second_BsfBsr;
            in_new_x:
               second_new;
            in_setlength_x:
               second_setlength;
            in_box_x:
               second_box;
            in_popcnt_x:
               second_popcnt;
            in_seg_x:
               second_seg;
            in_fma_single,
            in_fma_double,
            in_fma_extended:
               second_fma;
            in_max_longint,
            in_max_dword,
            in_min_longint,
            in_min_dword,
            in_min_int64,
            in_min_qword,
            in_max_int64,
            in_max_qword,
            in_min_single,
            in_min_double,
            in_max_single,
            in_max_double:
               second_minmax;
            in_and_assign_x_y,
            in_or_assign_x_y,
            in_xor_assign_x_y,
            in_sar_assign_x_y,
            in_shl_assign_x_y,
            in_shr_assign_x_y,
            in_rol_assign_x_y,
            in_ror_assign_x_y:
               second_AndOrXorShiftRot_assign;
            in_neg_assign_x,
            in_not_assign_x:
               second_NegNot_assign;
            in_high_x:
              second_high;
            else
               pass_generate_code_cpu;
         end;
      end;


    procedure TCGInlineNode.pass_generate_code_cpu;
      begin
        InternalError(2017110103);
      end;

{*****************************************************************************
                          SIZEOF / TYPEOF GENERIC HANDLING
*****************************************************************************}

    { second_handle_ the sizeof and typeof routines }
    procedure TCGInlineNode.second_SizeOfTypeOf;
      begin
        { handled in pass 1 }
        InternalError(2015122701);
     end;


{*****************************************************************************
                          LENGTH GENERIC HANDLING
*****************************************************************************}

    procedure TCGInlineNode.second_Length;
      var
        lengthlab : TAsmLabel;
        hregister : TRegister;
        lendef : TDef;
        href : TReference;
      begin
        SecondPass(left);
        if Is_ShortString(left.resultdef) then
         begin
           Location_Copy(location,left.Location);
           location.Size:=OS_8;
         end
        else
         begin
           { length in ansi/wide strings and high in dynamic arrays is at offset -sizeof(pint) }
           hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,false);
           CurrentAsmData.getjumplabel(lengthlab);
           hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,left.resultdef,OC_EQ,0,left.Location.Register,lengthlab);
           { the length of a widestring is a 32 bit unsigned int. Since every
             character occupies 2 bytes, on a 32 bit platform you can express
             the maximum length using 31 bits. On a 64 bit platform, it may be
             32 bits. This means that regardless of the platform, a location
             with size OS_SINT/ossinttype can hold the length without
             overflowing (this code returns an ossinttype value) }
           if Is_WideString(left.resultdef) then
             lendef:=U32IntType
           else
             lendef:=SizeSIntType;
           { volatility of the ansistring/widestring refers to the volatility of the
             string pointer, not of the string data }
           hlcg.Reference_Reset_Base(href,left.resultdef,left.Location.Register,-lendef.Size,CTempPosInvalid,lendef.Alignment,[]);
           { if the string pointer is nil, the length is 0 -> reuse the register
             that originally held the string pointer for the length, so that we
             can keep the original nil/0 as length in that case }
           hregister:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,left.Location.Register,Def_CGSize(resultdef));
           hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,lendef,resultdef,href,hregister);
           if Is_WideString(left.resultdef) then
             hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SHR,resultdef,1,hregister);

           { Dynamic arrays do not have their length attached but their maximum index }
           if Is_Dynamic_Array(left.resultdef) then
             hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_ADD,resultdef,1,hregister);

           cg.A_Label(CurrentAsmData.CurrAsmList,lengthlab);
           Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
           location.Register:=hregister;
         end;
      end;

{*****************************************************************************
                          HIGH(<dyn. array>) GENERIC HANDLING
*****************************************************************************}

    procedure TCGInlineNode.second_high;
      var
        loadlab, nillab, donelab: TAsmLabel;
        hregister : TRegister;
        href : TReference;
      begin
        SecondPass(left);
        if not(Is_Dynamic_Array(left.resultdef)) then
          InternalError(2019122801);
        { length in dynamic arrays is at offset -sizeof(pint) }
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,false);
        CurrentAsmData.getjumplabel(loadlab);
        CurrentAsmData.getjumplabel(nillab);
        CurrentAsmData.getjumplabel(donelab);
        hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,left.resultdef,OC_EQ,0,left.Location.Register,nillab);
        { volatility of the dyn. array refers to the volatility of the
          string pointer, not of the string data }
        hlcg.Reference_Reset_Base(href,left.resultdef,left.Location.Register,-SizeSIntType.Size,CTempPosInvalid,OSSIntType.Alignment,[]);
        { if the string pointer is nil, the length is 0 -> reuse the register
          that originally held the string pointer for the length, so that we
          can keep the original nil/0 as length in that case }
        hregister:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,left.Location.Register,Def_CGSize(resultdef));
        hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,SizeSIntType,resultdef,href,hregister);
        hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,donelab);

        cg.A_Label(CurrentAsmData.CurrAsmList,nillab);
        hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SUB,resultdef,1,hregister);
        cg.A_Label(CurrentAsmData.CurrAsmList,donelab);
        Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
        location.Register:=hregister;
      end;


{*****************************************************************************
                         PRED/SUCC GENERIC HANDLING
*****************************************************************************}

    procedure TCGInlineNode.second_PredSucc;
      var
         cgop : TOpCG;
      begin
        SecondPass(left);
        if inlinenumber=in_pred_x then
           cgop:=OP_SUB
        else
           cgop:=OP_ADD;

        Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
        if not(left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,false);

{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
        if Def_CGSize(resultdef) in [OS_64,OS_S64] then
          begin
            location.Register64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
            location.Register64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
            cg64.A_Op64_Const_Reg_Reg(CurrentAsmData.CurrAsmList,cgop,Def_CGSize(resultdef),1,left.Location.Register64,location.Register64);
          end
        else
{$endif not cpu64bitalu and not cpuhighleveltarget}
          begin
            location.Register:=hlcg.GetRegisterForDef(CurrentAsmData.CurrAsmList,resultdef);
            hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,cgop,resultdef,1,left.Location.Register,location.Register);
          end;
      end;


{*****************************************************************************
                         INC/DEC GENERIC HANDLING
*****************************************************************************}
      function TCGInlineNode.second_incdec_tempregdef: TDef;
        begin
          second_incdec_tempregdef:=left.resultdef;
        end;

      procedure TCGInlineNode.second_IncDec;
       const
         addsubop:array[in_inc_x..in_dec_x] of TOpCG=(OP_ADD,OP_SUB);
        var
         addvalue : TConstExprInt;
         addconstant : boolean;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         hregisterhi,
{$endif not cpu64bitalu and not cpuhighleveltarget}
         hregister : TRegister;
        begin
          { set defaults }
          addconstant:=true;
          hregister:=NR_NO;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
          hregisterhi:=NR_NO;
{$endif not cpu64bitalu and not cpuhighleveltarget}

          { first secondpass second argument, because if the first arg }
          { is used in that expression then SSL may move it to another }
          { register                                                   }
          if Assigned(TCallParaNode(left).right) then
            SecondPass(TCallParaNode(TCallParaNode(left).right).left);
          { load first parameter, must be a reference }
          SecondPass(TCallParaNode(left).left);
          { get addvalue }
          case TCallParaNode(left).left.resultdef.typ of
            orddef,
            enumdef :
                addvalue:=1;
            pointerdef :
               begin
                 if Is_Void(TPointerDef(TCallParaNode(left).left.resultdef).PointedDef) then
                   addvalue:=1
                 else
                   addvalue:=TPointerDef(TCallParaNode(left).left.resultdef).PointedDef.Size;
               end;
           else
               InternalError(2020100814);
          end;
          { second_ argument specified?, must be a s32bit in register }
          if Assigned(TCallParaNode(left).right) then
            begin
              { when constant, just multiply the addvalue }
              if is_constintnode(TCallParaNode(TCallParaNode(left).right).left) then
                 addvalue:=addvalue*get_ordinal_value(TCallParaNode(TCallParaNode(left).right).left)
              else if is_constpointernode(TCallParaNode(TCallParaNode(left).right).left) then
                 addvalue:=addvalue*TPointerConstNode(TCallParaNode(TCallParaNode(left).right).left).Value
              else
                begin
                  if not(TCallParaNode(TCallParaNode(left).right).left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_REFERENCE,LOC_CREFERENCE]) or (addvalue>1) or
                    not(Equal_Defs(left.resultdef,TCallParaNode(TCallParaNode(left).right).left.resultdef)) then
                    begin
                      hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,TCallParaNode(TCallParaNode(left).right).left.Location,TCallParaNode(TCallParaNode(left).right).left.resultdef,second_incdec_tempregdef,addvalue<=1);
                      hregister:=TCallParaNode(TCallParaNode(left).right).left.Location.Register;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      hregisterhi:=TCallParaNode(TCallParaNode(left).right).left.Location.Register64.RegHi;
{$endif not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      { insert multiply with addvalue if its >1 }
                      if addvalue>1 then
                        hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_IMUL,left.resultdef,addvalue.svalue,hregister);
                    end
                  else if TCallParaNode(TCallParaNode(left).right).left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER] then
                    begin
                      hregister:=TCallParaNode(TCallParaNode(left).right).left.Location.Register;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      hregisterhi:=TCallParaNode(TCallParaNode(left).right).left.Location.Register64.RegHi;
{$endif not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                    end;
                  addconstant:=false;
                end;
            end;
          { write the add instruction }
          if addconstant then
            begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
              if Def_CGSize(left.resultdef) in [OS_64,OS_S64] then
                { use addvalue.svalue here to avoid an internal error if addvalue is unsigned and overflows int64, see #35298,
                  we are only interested in the bit pattern here }
                cg64.A_Op64_Const_Loc(CurrentAsmData.CurrAsmList,addsubop[inlinenumber],Def_CGSize(left.resultdef),addvalue.svalue,TCallParaNode(left).left.Location)
              else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                hlcg.A_Op_Const_Loc(CurrentAsmData.CurrAsmList,addsubop[inlinenumber],left.resultdef,
{$ifdef cpu64bitalu}
                  aint(addvalue.svalue),
{$else cpu64bitalu}
                  LongInt(addvalue.svalue),  // can't use aint, because it breaks 16-bit and 8-bit CPUs
{$endif cpu64bitalu}
                  TCallParaNode(left).left.Location);
            end
           else
             begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
               if Def_CGSize(left.resultdef) in [OS_64,OS_S64] then
                 case TCallParaNode(TCallParaNode(left).right).left.Location.Loc of
                   LOC_REFERENCE,LOC_CREFERENCE:
                     cg64.A_Op64_Ref_Loc(CurrentAsmData.CurrAsmList,addsubop[inlinenumber],Def_CGSize(left.resultdef),
                       TCallParaNode(TCallParaNode(left).right).left.Location.Reference,TCallParaNode(left).left.Location);
                   LOC_REGISTER,LOC_CREGISTER:
                     cg64.A_Op64_Reg_Loc(CurrentAsmData.CurrAsmList,addsubop[inlinenumber],Def_CGSize(left.resultdef),
                       JoinReg64(hregister,hregisterhi),TCallParaNode(left).left.Location);
                   else
                     InternalError(2020042801);
                 end
               else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                 case TCallParaNode(TCallParaNode(left).right).left.Location.Loc of
                   LOC_REFERENCE,LOC_CREFERENCE:
                     hlcg.A_Op_Ref_Loc(CurrentAsmData.CurrAsmList,addsubop[inlinenumber],left.resultdef,
                       TCallParaNode(TCallParaNode(left).right).left.Location.Reference,TCallParaNode(left).left.Location);
                   LOC_REGISTER,LOC_CREGISTER:
                     hlcg.A_Op_Reg_Loc(CurrentAsmData.CurrAsmList,addsubop[inlinenumber],left.resultdef,
                       hregister,TCallParaNode(left).left.Location);
                   else
                     InternalError(2020042802);
                 end;
             end;
          { no overflow checking for pointers (see ninl), and range checking }
          { is not applicable for them                                       }
          if (TCallParaNode(left).left.resultdef.typ <> pointerdef) then
            begin
              { things which can overflow must NOT pass via here, but have to be  }
              { handled via a regular add node (conversion in tinlinenode.pass_1) }
              { Or someone has to rewrite the above to use a_op_const_reg_reg_ov  }
              { and friends in case of overflow checking, and ask everyone to     }
              { implement these methods since they don't exist for all cpus (JM)  }
              { Similarly, range checking also has to be handled separately, }
              { see mantis #14841 (JM)                                       }
              if ([cs_check_overflow,cs_check_range] * CurrentSettings.LocalSwitches <> []) then
                InternalError(2006111010);
//              cg.g_overflowcheck(current_asmdata.CurrAsmList,tcallparanode(left).left.location,tcallparanode(left).resultdef);
//              cg.g_rangecheck(current_asmdata.CurrAsmList,tcallparanode(left).left.location,tcallparanode(left).left.resultdef,
//                 tcallparanode(left).left.resultdef);
            end;
        end;


{*****************************************************************************
              AND/OR/XOR/SHIFT/ROTATE ASSIGN GENERIC HANDLING
*****************************************************************************}
      procedure TCGInlineNode.second_AndOrXorShiftRot_assign;
        const
          andorxorop:array[in_and_assign_x_y..in_ror_assign_x_y] of TOpCG=
            (OP_AND,OP_OR,OP_XOR,OP_SAR,OP_SHL,OP_SHR,OP_ROL,OP_ROR);
        var
          maskvalue : TConstExprInt;
          maskconstant : boolean;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
          hregisterhi,
{$endif not cpu64bitalu and not cpuhighleveltarget}
          hregister : TRegister;
        begin
          { set defaults }
          maskconstant:=true;
          hregister:=NR_NO;
          maskvalue:=0;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
          hregisterhi:=NR_NO;
{$endif not cpu64bitalu and not cpuhighleveltarget}

          { first secondpass first argument, because if the second arg }
          { is used in that expression then SSL may move it to another }
          { register                                                   }
          SecondPass(TCallParaNode(left).left);
          { load second parameter, must be a reference }
          SecondPass(TCallParaNode(TCallParaNode(left).right).left);

          { when constant, just get the maskvalue }
          if is_constintnode(TCallParaNode(left).left) then
             maskvalue:=get_ordinal_value(TCallParaNode(left).left)
          else
            begin
              { for shift/rotate the shift count can be of different size than the shifted variable }
              if inlinenumber in [in_sar_assign_x_y,in_shl_assign_x_y,in_shr_assign_x_y,in_rol_assign_x_y,in_ror_assign_x_y] then
                hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,TCallParaNode(left).left.Location,TCallParaNode(left).left.resultdef,TCallParaNode(left).left.resultdef,true)
              else
                hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,TCallParaNode(left).left.Location,TCallParaNode(left).left.resultdef,TCallParaNode(left).right.resultdef,true);
              hregister:=TCallParaNode(left).left.Location.Register;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
              hregisterhi:=TCallParaNode(left).left.Location.Register64.RegHi;
{$endif not cpu64bitalu and not cpuhighleveltarget}
              maskconstant:=false;
            end;
          { write the and/or/xor/sar/shl/shr/rol/ror instruction }
          if maskconstant then
            begin
              if inlinenumber in [in_sar_assign_x_y,in_shl_assign_x_y,in_shr_assign_x_y,in_rol_assign_x_y,in_ror_assign_x_y] then
                if Def_CGSize(TCallParaNode(left).right.resultdef) in [OS_64,OS_S64] then
                  maskvalue:=maskvalue and 63
                else
                  maskvalue:=maskvalue and 31;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
              if (Def_CGSize(TCallParaNode(left).right.resultdef) in [OS_64,OS_S64]) and
                 (TCallParaNode(TCallParaNode(left).right).left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_REGISTER,LOC_CREGISTER]) then
                cg64.A_Op64_Const_Loc(CurrentAsmData.CurrAsmList,andorxorop[inlinenumber],Def_CGSize(TCallParaNode(left).right.resultdef),maskvalue.svalue,TCallParaNode(TCallParaNode(left).right).left.Location)
              else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                hlcg.A_Op_Const_Loc(CurrentAsmData.CurrAsmList,andorxorop[inlinenumber],TCallParaNode(left).right.resultdef,
{$ifdef cpu64bitalu}
                  aint(maskvalue.svalue),
{$else cpu64bitalu}
                  LongInt(maskvalue.svalue),  // can't use aint, because it breaks 16-bit and 8-bit CPUs
{$endif cpu64bitalu}
                  TCallParaNode(TCallParaNode(left).right).left.Location);
            end
           else
             begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
               if (Def_CGSize(TCallParaNode(left).right.resultdef) in [OS_64,OS_S64]) and
                  (TCallParaNode(TCallParaNode(left).right).left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_REGISTER,LOC_CREGISTER]) then
                 cg64.A_Op64_Reg_Loc(CurrentAsmData.CurrAsmList,andorxorop[inlinenumber],Def_CGSize(TCallParaNode(left).right.resultdef),
                   JoinReg64(hregister,hregisterhi),TCallParaNode(TCallParaNode(left).right).left.Location)
               else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                 hlcg.A_Op_Reg_Loc(CurrentAsmData.CurrAsmList,andorxorop[inlinenumber],TCallParaNode(left).right.resultdef,
                   hregister,TCallParaNode(TCallParaNode(left).right).left.Location);
             end;
        end;


{*****************************************************************************
                       NEG/NOT ASSIGN GENERIC HANDLING
*****************************************************************************}
      procedure TCGInlineNode.second_NegNot_assign;
        const
          negnotop:array[in_neg_assign_x..in_not_assign_x] of TOpCG=(OP_NEG,OP_NOT);
        begin
          { load parameter, must be a reference }
          SecondPass(left);

          Location_Reset(location,LOC_VOID,OS_NO);

{$if not defined(cpu64bitalu) } // and not defined(cpuhighleveltarget)}
          if (Def_CGSize(left.resultdef) in [OS_64,OS_S64]) and (left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_REFERENCE,LOC_CREFERENCE]) then
            cg64.A_Op64_Loc(CurrentAsmData.CurrAsmList,negnotop[inlinenumber],Def_CGSize(left.resultdef),left.Location)
          else
{$endif not cpu64bitalu}
            hlcg.A_Op_Loc(CurrentAsmData.CurrAsmList,negnotop[inlinenumber],left.resultdef,left.Location);
        end;


{*****************************************************************************
                         TYPEINFO GENERIC HANDLING
*****************************************************************************}
      procedure TCGInlineNode.second_typeinfo;
        begin
          InternalError(2013060301);
        end;


{*****************************************************************************
                     INCLUDE/EXCLUDE GENERIC HANDLING
*****************************************************************************}

      procedure TCGInlineNode.second_IncludeExclude;
        var
          setpara, elepara: TNode;
        begin
          { the set }
          SecondPass(TCallParaNode(left).left);
          { the element to set }
          SecondPass(TCallParaNode(TCallParaNode(left).right).left);

          setpara:=TCallParaNode(left).left;
          elepara:=TCallParaNode(TCallParaNode(left).right).left;

          if elepara.Location.Loc=LOC_CONSTANT then
            begin
              hlcg.A_Bit_Set_Const_Loc(CurrentAsmData.CurrAsmList,(inlinenumber=in_include_x_y),
                setpara.resultdef,elepara.Location.Value-TSetDef(setpara.resultdef).SetBase,setpara.Location);
            end
          else
            begin
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,elepara.Location,elepara.resultdef,U32IntType,true);
              register_maybe_adjust_setbase(CurrentAsmData.CurrAsmList,U32IntType,elepara.Location,TSetDef(setpara.resultdef).SetBase);
              hlcg.A_Bit_Set_Reg_Loc(CurrentAsmData.CurrAsmList,(inlinenumber=in_include_x_y),
                U32IntType,setpara.resultdef,elepara.Location.Register,setpara.Location);
            end;
        end;


{*****************************************************************************
                            FLOAT GENERIC HANDLING
*****************************************************************************}

{
  These routines all call internal RTL routines, so if they are
  called here, they give an internal error
}
    procedure TCGInlineNode.second_pi;
      begin
        InternalError(2002071801);
      end;

    procedure TCGInlineNode.second_arctan_real;
      begin
        InternalError(2002071802);
      end;

    procedure TCGInlineNode.second_abs_real;
      begin
        InternalError(2002071803);
      end;

    procedure TCGInlineNode.second_round_real;
      begin
        InternalError(2002071804);
      end;

    procedure TCGInlineNode.second_trunc_real;
      begin
        InternalError(2002071805);
      end;

    procedure TCGInlineNode.second_int_real;
      begin
        InternalError(2016112702);
      end;

    procedure TCGInlineNode.second_sqr_real;
      begin
        InternalError(2002071806);
      end;

    procedure TCGInlineNode.second_sqrt_real;
      begin
        InternalError(2002071807);
      end;

    procedure TCGInlineNode.second_ln_real;
      begin
        InternalError(2002071808);
      end;

    procedure TCGInlineNode.second_cos_real;
      begin
        InternalError(2002071809);
      end;

    procedure TCGInlineNode.second_sin_real;
      begin
        InternalError(2002071810);
      end;


    procedure TCGInlineNode.second_prefetch;
      begin
      end;

    procedure TCGInlineNode.second_frac_real;
      begin
        InternalError(2017052104);
      end;

    procedure TCGInlineNode.second_abs_long;
      var
        tempreg1, tempreg2: TRegister;
{$if not(defined(cpu64bitalu)) and not defined(cpuhighleveltarget)}
        tempreg64: TRegister64;
{$endif not(defined(cpu64bitalu)) and not defined(cpuhighleveltarget)}
        ovloc: TLocation;
      begin
        SecondPass(left);
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,false);
        location:=left.Location;
{$if not(defined(cpu64bitalu)) and not defined(cpuhighleveltarget)}
        if Is_64BitInt(left.resultdef) then
          begin
            location:=left.Location;
            location.Register64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
            location.Register64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
            cg64.A_Load64_Reg_Reg(CurrentAsmData.CurrAsmList,left.Location.Register64,location.Register64);
            cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SAR,OS_32,31,left.Location.Register64.RegHi);
            tempreg64.RegHi:=left.Location.Register64.RegHi;
            tempreg64.RegLo:=left.Location.Register64.RegHi;
            cg64.A_Op64_Reg_Reg(CurrentAsmData.CurrAsmList,OP_XOR,Def_CGSize(resultdef),tempreg64,location.Register64);
            if cs_check_overflow in CurrentSettings.LocalSwitches then
              begin
                cg64.A_Op64_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,Def_CGSize(resultdef),tempreg64,location.Register64,location.Register64,true,ovloc);
                hlcg.G_OverflowCheck_Loc(CurrentAsmData.CurrAsmList,Location,resultdef,ovloc);
              end
            else
              cg64.A_Op64_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SUB,Def_CGSize(resultdef),tempreg64,location.Register64,location.Register64);
          end
        else
{$endif not(defined(cpu64bitalu)) and not defined(cpuhighleveltarget)}
          begin
            location.Register:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,left.resultdef);

            tempreg1:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,left.resultdef);
            tempreg2:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,left.resultdef);

            hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SAR,left.resultdef,left.resultdef.Size*8-1,left.Location.Register,tempreg1);
            hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,OP_XOR,left.resultdef,left.Location.Register,tempreg1,tempreg2);

            if cs_check_overflow in CurrentSettings.LocalSwitches then
              begin
                hlcg.A_Op_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmlist,OP_SUB,resultdef,tempreg1,tempreg2,location.Register,true,ovloc);
                hlcg.G_OverflowCheck_Loc(CurrentAsmData.CurrAsmList,Location,resultdef,ovloc);
              end
            else
              hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmlist,OP_SUB,resultdef,tempreg1,tempreg2,location.Register);
          end;
      end;


{*****************************************************************************
                         ASSIGNED GENERIC HANDLING
*****************************************************************************}

    procedure TCGInlineNode.second_assigned;
      begin
        InternalError(2013091602);
      end;

    procedure TCGInlineNode.second_get_frame;

    begin
{$if defined(x86)}
      if CurrentProcInfo.framepointer=NR_STACK_POINTER_REG then
        begin
          Location_Reset(location,LOC_CONSTANT,OS_ADDR);
          location.Value:=0;
        end
      else
{$endif}
        begin
          Location_Reset(location,LOC_CREGISTER,OS_ADDR);
          location.Register:=CurrentProcInfo.framepointer;
        end;
    end;

    procedure TCGInlineNode.second_get_caller_frame;

    var
      frame_reg:TRegister;
      use_frame_pointer:boolean;

    begin
      frame_reg:=NR_NO;

      if left<>nil then
        begin
          SecondPass(left);
          if left.Location.Loc=LOC_CONSTANT then
            use_frame_pointer:=true
          else
            begin
              hlcg.Location_Force_Reg(CurrentAsmData.currasmlist,left.Location,left.resultdef,VoidPointerType,false);
              frame_reg:=left.Location.Register;
              use_frame_pointer:=false;
            end
        end
      else
        begin
          use_frame_pointer:=CurrentProcInfo.framepointer=NR_STACK_POINTER_REG;
          frame_reg:=CurrentProcInfo.framepointer;
        end;

      if use_frame_pointer then
        begin
          Location_Reset(location,LOC_CREGISTER,OS_ADDR);
          location.Register:=NR_FRAME_POINTER_REG;
        end
      else
        begin
          Location_Reset_Ref(location,LOC_REFERENCE,OS_ADDR,sizeof(PInt),[]);
          location.Reference.Base:=frame_reg;
        end;
    end;

    procedure TCGInlineNode.second_get_caller_addr;
      var
        frame_ref:TReference;
      begin
        if CurrentProcInfo.framepointer=NR_STACK_POINTER_REG then
          begin
            Location_Reset(location,LOC_REGISTER,OS_ADDR);
            location.Register:=cg.GetAddressRegister(CurrentAsmData.currasmlist);
            Reference_Reset_Base(frame_ref,NR_STACK_POINTER_REG,{current_procinfo.calc_stackframe_size}tg.lasttemp,CTempPosInvalid,sizeof(PInt),[]);
            cg.A_Load_Ref_Reg(CurrentAsmData.currasmlist,OS_ADDR,OS_ADDR,frame_ref,location.Register);
          end
        else
          begin
            Location_Reset(location,LOC_REGISTER,OS_ADDR);
            location.Register:=cg.GetAddressRegister(CurrentAsmData.currasmlist);
            Reference_Reset_Base(frame_ref,CurrentProcInfo.framepointer,sizeof(PInt),CTempPosInvalid,sizeof(PInt),[]);
            cg.A_Load_Ref_Reg(CurrentAsmData.currasmlist,OS_ADDR,OS_ADDR,frame_ref,location.Register);
          end;
      end;


    procedure TCGInlineNode.second_rox_sar;
      var
        op : TOpCG;
        op1,op2 : TNode;
      begin
        { one or two parameters? }
        if (left.nodetype=callparan) and
           Assigned(TCallParaNode(left).right) then
          begin
            op1:=TCallParaNode(TCallParaNode(left).right).left;
            op2:=TCallParaNode(left).left;
            SecondPass(op2);
          end
        else
          begin
            op1:=left;
            op2:=nil;
          end;

        SecondPass(op1);
        case inlinenumber of
          in_ror_x,
          in_ror_x_y:
            op:=OP_ROR;
          in_rol_x,
          in_rol_x_y:
            op:=OP_ROL;
          in_sar_x,
          in_sar_x_y:
            op:=OP_SAR;
          else
            InternalError(2013120110);
        end;

        if not(op1.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,op1.Location,op1.resultdef,resultdef,true);

        Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
        if Def_CGSize(resultdef) in [OS_64,OS_S64] then
          begin
            location.Register64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
            location.Register64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
          end
        else
{$endif not cpu64bitalu and not cpuhighleveltarget}
          location.Register:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,resultdef);

        if Assigned(op2) then
          begin
             { rotating by a constant directly coded: }
             if op2.nodetype=ordconstn then
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
               if Def_CGSize(resultdef) in [OS_64,OS_S64] then
                 cg64.A_Op64_Const_Reg_Reg(CurrentAsmData.CurrAsmList,op,Def_CGSize(resultdef),
                   TOrdConstNode(op2).Value.uvalue and (resultdef.Size*8-1),
                   op1.Location.Register64, location.Register64)
               else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                 hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,op,resultdef,
                   TOrdConstNode(op2).Value.uvalue and (resultdef.Size*8-1),
                   op1.Location.Register, location.Register)
             else
               begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                 if Def_CGSize(resultdef) in [OS_64,OS_S64] then
                   begin
                     if not(op2.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) or
                       not(Equal_Defs(op2.resultdef,ALUSIntType)) then
                       hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,op2.Location,
                                               op2.resultdef,ALUSIntType,true);
                     cg64.A_Op64_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,op,Def_CGSize(resultdef),
                                             JoinReg64(op2.Location.Register,NR_NO),op1.Location.Register64,
                                             location.Register64);
                   end
                 else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                   begin
                     if not(op2.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) or
                       not(Equal_Defs(op2.resultdef,resultdef)) then
                       hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,op2.Location,
                                               op2.resultdef,resultdef,true);
                     hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,op,resultdef,
                                           op2.Location.Register,op1.Location.Register,
                                           location.Register);
                   end;
               end;
          end
        else
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
          if Def_CGSize(resultdef) in [OS_64,OS_S64] then
            cg64.A_Op64_Const_Reg_Reg(CurrentAsmData.CurrAsmList,op,Def_CGSize(resultdef),1,
                                      op1.Location.Register64,location.Register64)
          else
{$endif not cpu64bitalu and not cpuhighleveltarget}
            hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,op,resultdef,1,
                                    op1.Location.Register,location.Register);
      end;


    procedure TCGInlineNode.second_BsfBsr;
    var
      reverse: boolean;
      opsize: TCgSize;
    begin
      SecondPass(left);

      opsize:=TCgSize2Unsigned[left.Location.Size];
      if not(left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,CGSize_OrdDef(opsize),true);

      Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
      location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,location.Size);
      cg.A_Bit_Scan_Reg_Reg(CurrentAsmData.CurrAsmList,inlinenumber=in_bsr_x,node_not_zero(left),opsize,location.Size,left.Location.Register,location.Register);
    end;


    procedure TCGInlineNode.second_new;
      begin
        InternalError(2011012202);
      end;


    procedure TCGInlineNode.second_popcnt;
      begin
        InternalError(2012082602);
      end;


    procedure TCGInlineNode.second_fma;
      begin
        InternalError(2014032701);
      end;


    procedure TCGInlineNode.second_minmax;
      begin
        InternalError(2020120510);
      end;

begin
   CInlineNode:=TCGInlineNode;
end.
