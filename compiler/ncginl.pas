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
          procedure Pass_Generate_Code;override;
          procedure Pass_Generate_Code_CPU;virtual;
          procedure Second_SizeOfTypeOf;virtual;
          procedure Second_Length;virtual;
          procedure Second_PredSucc;virtual;
          procedure Second_IncDec;virtual;
          procedure Second_AndOrXorShiftRot_Assign;virtual;
          procedure Second_NegNot_Assign;virtual;
          procedure Second_TypeInfo;virtual;
          procedure Second_IncludeExclude;virtual;
          procedure Second_Pi; virtual;
          procedure Second_ArcTan_Real; virtual;
          procedure Second_Abs_Real; virtual;
          procedure Second_Sqr_Real; virtual;
          procedure Second_Sqrt_Real; virtual;
          procedure Second_Ln_Real; virtual;
          procedure Second_Cos_Real; virtual;
          procedure Second_Sin_Real; virtual;
          procedure Second_Assigned; virtual;
          procedure Second_Get_Frame;virtual;
          procedure Second_Get_Caller_Frame;virtual;
          procedure Second_Get_Caller_Addr;virtual;
          procedure Second_Prefetch; virtual;
          procedure Second_Round_Real; virtual;
          procedure Second_Trunc_Real; virtual;
          procedure Second_Int_Real; virtual;
          procedure Second_Abs_Long; virtual;
          procedure Second_ROX_SAR; virtual;
          procedure Second_BsfBsr; virtual;
          procedure Second_New; virtual;
          procedure Second_SetLength; virtual; abstract;
          procedure Second_Box; virtual; abstract;
          procedure Second_PopCnt; virtual;
          procedure Second_Seg; virtual; abstract;
          procedure Second_FMA; virtual;
          procedure Second_Frac_Real; virtual;
          procedure Second_High; virtual;
          procedure Second_MinMax; virtual;
       protected
          function  Second_IncDec_TempRegDef: TDef;virtual;
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


    procedure TCGInlineNode.Pass_Generate_Code;
      begin
         Location_Reset(Location,LOC_VOID,OS_NO);

         case InlineNumber of
            in_sizeof_x,
            in_typeof_x :
              Second_SizeOfTypeOf;
            in_length_x :
              Second_Length;
            in_pred_x,
            in_succ_x:
               Second_PredSucc;
            in_dec_x,
            in_inc_x :
              Second_IncDec;
            in_typeinfo_x:
              Second_TypeInfo;
            in_include_x_y,
            in_exclude_x_y:
              Second_IncludeExclude;
            in_pi_real:
              Second_Pi;
            in_sin_real:
              Second_Sin_Real;
            in_arctan_real:
              Second_ArcTan_Real;
            in_abs_real:
              Second_Abs_Real;
            in_abs_long:
              Second_Abs_Long;
            in_round_real:
              Second_Round_Real;
            in_trunc_real:
              Second_Trunc_Real;
            in_int_real:
              Second_Int_Real;
            in_sqr_real:
              Second_Sqr_Real;
            in_sqrt_real:
              Second_Sqrt_Real;
            in_ln_real:
              Second_Ln_Real;
            in_cos_real:
               Second_Cos_Real;
            in_frac_real:
              Second_Frac_Real;
            in_prefetch_var:
              Second_Prefetch;
            in_assigned_x:
              Second_Assigned;
            in_get_frame:
              Second_Get_Frame;
            in_get_caller_frame:
              Second_Get_Caller_Frame;
            in_get_caller_addr:
              Second_Get_Caller_Addr;
            in_unaligned_x:
              begin
                SecondPass(TCallParaNode(Left).Left);
                Location:=TCallParaNode(Left).Left.Location;
                if Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE] then
                  Location.Reference.Alignment:=1
                else
                  message(parser_w_unaligned_useless);
              end;
            in_aligned_x:
              begin
                SecondPass(TCallParaNode(Left).Left);
                Location:=TCallParaNode(Left).Left.Location;
                if Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE] then
                  Location.Reference.Alignment:=ResultDef.Alignment
                else
                  message(parser_w_aligned_useless);
              end;
            in_volatile_x:
              begin
                SecondPass(TCallParaNode(Left).Left);
                Location:=TCallParaNode(Left).Left.Location;
                if Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE,LOC_SUBSETREF,LOC_CSUBSETREF] then
                  Location.Reference.Volatility:=[vol_read,vol_write];
              end;
            in_rol_x,
            in_rol_x_y,
            in_ror_x,
            in_ror_x_y,
            in_sar_x,
            in_sar_x_y:
              Second_ROX_SAR;
            in_bsf_x,
            in_bsr_x:
               Second_BsfBsr;
            in_new_x:
               Second_New;
            in_setlength_x:
               Second_SetLength;
            in_box_x:
               Second_Box;
            in_popcnt_x:
               Second_PopCnt;
            in_seg_x:
               Second_Seg;
            in_fma_single,
            in_fma_double,
            in_fma_extended:
               Second_FMA;
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
               Second_MinMax;
            in_and_assign_x_y,
            in_or_assign_x_y,
            in_xor_assign_x_y,
            in_sar_assign_x_y,
            in_shl_assign_x_y,
            in_shr_assign_x_y,
            in_rol_assign_x_y,
            in_ror_assign_x_y:
               Second_AndOrXorShiftRot_Assign;
            in_neg_assign_x,
            in_not_assign_x:
               Second_NegNot_Assign;
            in_high_x:
              Second_High;
            else
               Pass_Generate_Code_CPU;
         end;
      end;


    procedure TCGInlineNode.Pass_Generate_Code_CPU;
      begin
        InternalError(2017110103);
      end;

{*****************************************************************************
                          SIZEOF / TYPEOF GENERIC HANDLING
*****************************************************************************}

    { second_handle_ the sizeof and typeof routines }
    procedure TCGInlineNode.Second_SizeOfTypeOf;
      begin
        { handled in pass 1 }
        InternalError(2015122701);
     end;


{*****************************************************************************
                          LENGTH GENERIC HANDLING
*****************************************************************************}

    procedure TCGInlineNode.Second_Length;
      var
        lLengthLabel : TAsmLabel;
        lReg : TRegister;
        lLengthDef : TDef;
        lReference : TReference;
      begin
        SecondPass(Left);
        if Is_ShortString(Left.ResultDef) then
         begin
           Location_Copy(Location,Left.Location);
           Location.Size:=OS_8;
         end
        else
         begin
           { length in ansi/wide strings and high in dynamic arrays is at offset -sizeof(pint) }
           hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,false);
           CurrentAsmData.getjumplabel(lLengthLabel);
           hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,Left.ResultDef,OC_EQ,0,Left.Location.Register,lLengthLabel);
           { the length of a widestring is a 32 bit unsigned int. Since every
             character occupies 2 bytes, on a 32 bit platform you can express
             the maximum length using 31 bits. On a 64 bit platform, it may be
             32 bits. This means that regardless of the platform, a location
             with size OS_SINT/ossinttype can hold the length without
             overflowing (this code returns an ossinttype value) }
           if Is_WideString(Left.ResultDef) then
             lLengthDef:=U32IntType
           else
             lLengthDef:=SizeSIntType;
           { volatility of the ansistring/widestring refers to the volatility of the
             string pointer, not of the string data }
           hlcg.Reference_Reset_Base(lReference,Left.ResultDef,Left.Location.Register,-lLengthDef.Size,CTempPosInvalid,lLengthDef.Alignment,[]);
           { if the string pointer is nil, the length is 0 -> reuse the register
             that originally held the string pointer for the length, so that we
             can keep the original nil/0 as length in that case }
           lReg:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,Left.Location.Register,Def_CGSize(ResultDef));
           hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,lLengthDef,ResultDef,lReference,lReg);
           if Is_WideString(Left.ResultDef) then
             hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SHR,ResultDef,1,lReg);

           { Dynamic arrays do not have their length attached but their maximum index }
           if Is_Dynamic_Array(Left.ResultDef) then
             hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_ADD,ResultDef,1,lReg);

           cg.A_Label(CurrentAsmData.CurrAsmList,lLengthLabel);
           Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
           Location.Register:=lReg;
         end;
      end;

{*****************************************************************************
                          HIGH(<dyn. array>) GENERIC HANDLING
*****************************************************************************}

    procedure TCGInlineNode.Second_High;
      var
        lLoadLabel, lNilLabel, lDoneLabel: TAsmLabel;
        lReg : TRegister;
        lReference : TReference;
      begin
        SecondPass(Left);
        if not(Is_Dynamic_Array(Left.ResultDef)) then
          InternalError(2019122801);
        { length in dynamic arrays is at offset -sizeof(pint) }
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,false);
        CurrentAsmData.getjumplabel(lLoadLabel);
        CurrentAsmData.getjumplabel(lNilLabel);
        CurrentAsmData.getjumplabel(lDoneLabel);
        hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,Left.ResultDef,OC_EQ,0,Left.Location.Register,lNilLabel);
        { volatility of the dyn. array refers to the volatility of the
          string pointer, not of the string data }
        hlcg.Reference_Reset_Base(lReference,Left.ResultDef,Left.Location.Register,-SizeSIntType.Size,CTempPosInvalid,OSSIntType.Alignment,[]);
        { if the string pointer is nil, the length is 0 -> reuse the register
          that originally held the string pointer for the length, so that we
          can keep the original nil/0 as length in that case }
        lReg:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,Left.Location.Register,Def_CGSize(ResultDef));
        hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,SizeSIntType,ResultDef,lReference,lReg);
        hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lDoneLabel);

        cg.A_Label(CurrentAsmData.CurrAsmList,lNilLabel);
        hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SUB,ResultDef,1,lReg);
        cg.A_Label(CurrentAsmData.CurrAsmList,lDoneLabel);
        Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
        Location.Register:=lReg;
      end;


{*****************************************************************************
                         PRED/SUCC GENERIC HANDLING
*****************************************************************************}

    procedure TCGInlineNode.Second_PredSucc;
      var
         lCGOp : TOpCG;
      begin
        SecondPass(Left);
        if InlineNumber=in_pred_x then
           lCGOp:=OP_SUB
        else
           lCGOp:=OP_ADD;

        Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
        if not(Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,false);

{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
        if Def_CGSize(ResultDef) in [OS_64,OS_S64] then
          begin
            Location.Register64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
            Location.Register64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
            cg64.A_Op64_Const_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,Def_CGSize(ResultDef),1,Left.Location.Register64,Location.Register64);
          end
        else
{$endif not cpu64bitalu and not cpuhighleveltarget}
          begin
            Location.Register:=hlcg.GetRegisterForDef(CurrentAsmData.CurrAsmList,ResultDef);
            hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,ResultDef,1,Left.Location.Register,Location.Register);
          end;
      end;


{*****************************************************************************
                         INC/DEC GENERIC HANDLING
*****************************************************************************}
      function TCGInlineNode.Second_IncDec_TempRegDef: TDef;
        begin
          Second_IncDec_TempRegDef:=Left.ResultDef;
        end;

      procedure TCGInlineNode.Second_IncDec;
       const
         AddSubOp:array[in_inc_x..in_dec_x] of TOpCG=(OP_ADD,OP_SUB);
        var
         lAddValue : TConstExprInt;
         lAddConstant : Boolean;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         lRegHi,
{$endif not cpu64bitalu and not cpuhighleveltarget}
         lReg : TRegister;
        begin
          { set defaults }
          lAddConstant:=true;
          lReg:=NR_NO;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
          lRegHi:=NR_NO;
{$endif not cpu64bitalu and not cpuhighleveltarget}

          { first secondpass second argument, because if the first arg }
          { is used in that expression then SSL may move it to another }
          { register                                                   }
          if Assigned(TCallParaNode(Left).Right) then
            SecondPass(TCallParaNode(TCallParaNode(Left).Right).Left);
          { load first parameter, must be a reference }
          SecondPass(TCallParaNode(Left).Left);
          { get addvalue }
          case TCallParaNode(Left).Left.ResultDef.typ of
            orddef,
            enumdef :
                lAddValue:=1;
            pointerdef :
               begin
                 if Is_Void(TPointerDef(TCallParaNode(Left).Left.ResultDef).PointedDef) then
                   lAddValue:=1
                 else
                   lAddValue:=TPointerDef(TCallParaNode(Left).Left.ResultDef).PointedDef.Size;
               end;
           else
               InternalError(2020100814);
          end;
          { second_ argument specified?, must be a s32bit in register }
          if Assigned(TCallParaNode(Left).Right) then
            begin
              { when constant, just multiply the addvalue }
              if Is_ConstIntNode(TCallParaNode(TCallParaNode(Left).Right).Left) then
                 lAddValue:=lAddValue*Get_Ordinal_Value(TCallParaNode(TCallParaNode(Left).Right).Left)
              else if Is_ConstPointerNode(TCallParaNode(TCallParaNode(Left).Right).Left) then
                 lAddValue:=lAddValue*TPointerConstNode(TCallParaNode(TCallParaNode(Left).Right).Left).Value
              else
                begin
                  if not(TCallParaNode(TCallParaNode(Left).Right).Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_REFERENCE,LOC_CREFERENCE]) or (lAddValue>1) or
                    not(Equal_Defs(Left.ResultDef,TCallParaNode(TCallParaNode(Left).Right).Left.ResultDef)) then
                    begin
                      hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,TCallParaNode(TCallParaNode(Left).Right).Left.Location,TCallParaNode(TCallParaNode(Left).Right).Left.ResultDef,Second_IncDec_TempRegDef,lAddValue<=1);
                      lReg:=TCallParaNode(TCallParaNode(Left).Right).Left.Location.Register;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      lRegHi:=TCallParaNode(TCallParaNode(Left).Right).Left.Location.Register64.RegHi;
{$endif not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      { insert multiply with addvalue if its >1 }
                      if lAddValue>1 then
                        hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_IMUL,Left.ResultDef,lAddValue.svalue,lReg);
                    end
                  else if TCallParaNode(TCallParaNode(Left).Right).Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER] then
                    begin
                      lReg:=TCallParaNode(TCallParaNode(Left).Right).Left.Location.Register;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      lRegHi:=TCallParaNode(TCallParaNode(Left).Right).Left.Location.Register64.RegHi;
{$endif not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                    end;
                  lAddConstant:=false;
                end;
            end;
          { write the add instruction }
          if lAddConstant then
            begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
              if Def_CGSize(Left.ResultDef) in [OS_64,OS_S64] then
                { use addvalue.svalue here to avoid an internal error if addvalue is unsigned and overflows int64, see #35298,
                  we are only interested in the bit pattern here }
                cg64.A_Op64_Const_Loc(CurrentAsmData.CurrAsmList,AddSubOp[InlineNumber],Def_CGSize(Left.ResultDef),lAddValue.svalue,TCallParaNode(Left).Left.Location)
              else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                hlcg.A_Op_Const_Loc(CurrentAsmData.CurrAsmList,AddSubOp[InlineNumber],Left.ResultDef,
{$ifdef cpu64bitalu}
                  AInt(lAddValue.svalue),
{$else cpu64bitalu}
                  LongInt(lAddValue.svalue),  // can't use aint, because it breaks 16-bit and 8-bit CPUs
{$endif cpu64bitalu}
                  TCallParaNode(Left).Left.Location);
            end
           else
             begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
               if Def_CGSize(Left.ResultDef) in [OS_64,OS_S64] then
                 case TCallParaNode(TCallParaNode(Left).Right).Left.Location.Loc of
                   LOC_REFERENCE,LOC_CREFERENCE:
                     cg64.A_Op64_Ref_Loc(CurrentAsmData.CurrAsmList,AddSubOp[InlineNumber],Def_CGSize(Left.ResultDef),
                       TCallParaNode(TCallParaNode(Left).Right).Left.Location.Reference,TCallParaNode(Left).Left.Location);
                   LOC_REGISTER,LOC_CREGISTER:
                     cg64.A_Op64_Reg_Loc(CurrentAsmData.CurrAsmList,AddSubOp[InlineNumber],Def_CGSize(Left.ResultDef),
                       JoinReg64(lReg,lRegHi),TCallParaNode(Left).Left.Location);
                   else
                     InternalError(2020042801);
                 end
               else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                 case TCallParaNode(TCallParaNode(Left).Right).Left.Location.Loc of
                   LOC_REFERENCE,LOC_CREFERENCE:
                     hlcg.A_Op_Ref_Loc(CurrentAsmData.CurrAsmList,AddSubOp[InlineNumber],Left.ResultDef,
                       TCallParaNode(TCallParaNode(Left).Right).Left.Location.Reference,TCallParaNode(Left).Left.Location);
                   LOC_REGISTER,LOC_CREGISTER:
                     hlcg.A_Op_Reg_Loc(CurrentAsmData.CurrAsmList,AddSubOp[InlineNumber],Left.ResultDef,
                       lReg,TCallParaNode(Left).Left.Location);
                   else
                     InternalError(2020042802);
                 end;
             end;
          { no overflow checking for pointers (see ninl), and range checking }
          { is not applicable for them                                       }
          if (TCallParaNode(Left).Left.ResultDef.typ <> pointerdef) then
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
      procedure TCGInlineNode.Second_AndOrXorShiftRot_Assign;
        const
          AndOrXorOp:array[in_and_assign_x_y..in_ror_assign_x_y] of TOpCG=
            (OP_AND,OP_OR,OP_XOR,OP_SAR,OP_SHL,OP_SHR,OP_ROL,OP_ROR);
        var
          lMaskValue : TConstExprInt;
          lMaskConstant : Boolean;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
          lRegHi,
{$endif not cpu64bitalu and not cpuhighleveltarget}
          lReg : TRegister;
        begin
          { set defaults }
          lMaskConstant:=true;
          lReg:=NR_NO;
          lMaskValue:=0;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
          lRegHi:=NR_NO;
{$endif not cpu64bitalu and not cpuhighleveltarget}

          { first secondpass first argument, because if the second arg }
          { is used in that expression then SSL may move it to another }
          { register                                                   }
          SecondPass(TCallParaNode(Left).Left);
          { load second parameter, must be a reference }
          SecondPass(TCallParaNode(TCallParaNode(Left).Right).Left);

          { when constant, just get the maskvalue }
          if Is_ConstIntNode(TCallParaNode(Left).Left) then
             lMaskValue:=Get_Ordinal_Value(TCallParaNode(Left).Left)
          else
            begin
              { for shift/rotate the shift count can be of different size than the shifted variable }
              if InlineNumber in [in_sar_assign_x_y,in_shl_assign_x_y,in_shr_assign_x_y,in_rol_assign_x_y,in_ror_assign_x_y] then
                hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,TCallParaNode(Left).Left.Location,TCallParaNode(Left).Left.ResultDef,TCallParaNode(Left).Left.ResultDef,true)
              else
                hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,TCallParaNode(Left).Left.Location,TCallParaNode(Left).Left.ResultDef,TCallParaNode(Left).Right.ResultDef,true);
              lReg:=TCallParaNode(Left).Left.Location.Register;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
              lRegHi:=TCallParaNode(Left).Left.Location.Register64.RegHi;
{$endif not cpu64bitalu and not cpuhighleveltarget}
              lMaskConstant:=false;
            end;
          { write the and/or/xor/sar/shl/shr/rol/ror instruction }
          if lMaskConstant then
            begin
              if InlineNumber in [in_sar_assign_x_y,in_shl_assign_x_y,in_shr_assign_x_y,in_rol_assign_x_y,in_ror_assign_x_y] then
                if Def_CGSize(TCallParaNode(Left).Right.ResultDef) in [OS_64,OS_S64] then
                  lMaskValue:=lMaskValue and 63
                else
                  lMaskValue:=lMaskValue and 31;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
              if (Def_CGSize(TCallParaNode(Left).Right.ResultDef) in [OS_64,OS_S64]) and
                 (TCallParaNode(TCallParaNode(Left).Right).Left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_REGISTER,LOC_CREGISTER]) then
                cg64.A_Op64_Const_Loc(CurrentAsmData.CurrAsmList,AndOrXorOp[InlineNumber],Def_CGSize(TCallParaNode(Left).Right.ResultDef),lMaskValue.svalue,TCallParaNode(TCallParaNode(Left).Right).Left.Location)
              else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                hlcg.A_Op_Const_Loc(CurrentAsmData.CurrAsmList,AndOrXorOp[InlineNumber],TCallParaNode(Left).Right.ResultDef,
{$ifdef cpu64bitalu}
                  AInt(lMaskValue.svalue),
{$else cpu64bitalu}
                  LongInt(lMaskValue.svalue),  // can't use aint, because it breaks 16-bit and 8-bit CPUs
{$endif cpu64bitalu}
                  TCallParaNode(TCallParaNode(Left).Right).Left.Location);
            end
           else
             begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
               if (Def_CGSize(TCallParaNode(Left).Right.ResultDef) in [OS_64,OS_S64]) and
                  (TCallParaNode(TCallParaNode(Left).Right).Left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_REGISTER,LOC_CREGISTER]) then
                 cg64.A_Op64_Reg_Loc(CurrentAsmData.CurrAsmList,AndOrXorOp[InlineNumber],Def_CGSize(TCallParaNode(Left).Right.ResultDef),
                   JoinReg64(lReg,lRegHi),TCallParaNode(TCallParaNode(Left).Right).Left.Location)
               else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                 hlcg.A_Op_Reg_Loc(CurrentAsmData.CurrAsmList,AndOrXorOp[InlineNumber],TCallParaNode(Left).Right.ResultDef,
                   lReg,TCallParaNode(TCallParaNode(Left).Right).Left.Location);
             end;
        end;


{*****************************************************************************
                       NEG/NOT ASSIGN GENERIC HANDLING
*****************************************************************************}
      procedure TCGInlineNode.Second_NegNot_Assign;
        const
          NegNotOp:array[in_neg_assign_x..in_not_assign_x] of TOpCG=(OP_NEG,OP_NOT);
        begin
          { load parameter, must be a reference }
          SecondPass(Left);

          Location_Reset(Location,LOC_VOID,OS_NO);

{$if not defined(cpu64bitalu) } // and not defined(cpuhighleveltarget)}
          if (Def_CGSize(Left.ResultDef) in [OS_64,OS_S64]) and (Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_REFERENCE,LOC_CREFERENCE]) then
            cg64.A_Op64_Loc(CurrentAsmData.CurrAsmList,NegNotOp[InlineNumber],Def_CGSize(Left.ResultDef),Left.Location)
          else
{$endif not cpu64bitalu}
            hlcg.A_Op_Loc(CurrentAsmData.CurrAsmList,NegNotOp[InlineNumber],Left.ResultDef,Left.Location);
        end;


{*****************************************************************************
                         TYPEINFO GENERIC HANDLING
*****************************************************************************}
      procedure TCGInlineNode.Second_TypeInfo;
        begin
          InternalError(2013060301);
        end;


{*****************************************************************************
                     INCLUDE/EXCLUDE GENERIC HANDLING
*****************************************************************************}

      procedure TCGInlineNode.Second_IncludeExclude;
        var
          lSetPara, lElementPara: TNode;
        begin
          { the set }
          SecondPass(TCallParaNode(Left).Left);
          { the element to set }
          SecondPass(TCallParaNode(TCallParaNode(Left).Right).Left);

          lSetPara:=TCallParaNode(Left).Left;
          lElementPara:=TCallParaNode(TCallParaNode(Left).Right).Left;

          if lElementPara.Location.Loc=LOC_CONSTANT then
            begin
              hlcg.A_Bit_Set_Const_Loc(CurrentAsmData.CurrAsmList,(InlineNumber=in_include_x_y),
                lSetPara.ResultDef,lElementPara.Location.Value-TSetDef(lSetPara.ResultDef).SetBase,lSetPara.Location);
            end
          else
            begin
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,lElementPara.Location,lElementPara.ResultDef,U32IntType,true);
              Register_Maybe_Adjust_SetBase(CurrentAsmData.CurrAsmList,U32IntType,lElementPara.Location,TSetDef(lSetPara.ResultDef).SetBase);
              hlcg.A_Bit_Set_Reg_Loc(CurrentAsmData.CurrAsmList,(InlineNumber=in_include_x_y),
                U32IntType,lSetPara.ResultDef,lElementPara.Location.Register,lSetPara.Location);
            end;
        end;


{*****************************************************************************
                            FLOAT GENERIC HANDLING
*****************************************************************************}

{
  These routines all call internal RTL routines, so if they are
  called here, they give an internal error
}
    procedure TCGInlineNode.Second_Pi;
      begin
        InternalError(2002071801);
      end;

    procedure TCGInlineNode.Second_ArcTan_Real;
      begin
        InternalError(2002071802);
      end;

    procedure TCGInlineNode.Second_Abs_Real;
      begin
        InternalError(2002071803);
      end;

    procedure TCGInlineNode.Second_Round_Real;
      begin
        InternalError(2002071804);
      end;

    procedure TCGInlineNode.Second_Trunc_Real;
      begin
        InternalError(2002071805);
      end;

    procedure TCGInlineNode.Second_Int_Real;
      begin
        InternalError(2016112702);
      end;

    procedure TCGInlineNode.Second_Sqr_Real;
      begin
        InternalError(2002071806);
      end;

    procedure TCGInlineNode.Second_Sqrt_Real;
      begin
        InternalError(2002071807);
      end;

    procedure TCGInlineNode.Second_Ln_Real;
      begin
        InternalError(2002071808);
      end;

    procedure TCGInlineNode.Second_Cos_Real;
      begin
        InternalError(2002071809);
      end;

    procedure TCGInlineNode.Second_Sin_Real;
      begin
        InternalError(2002071810);
      end;


    procedure TCGInlineNode.Second_Prefetch;
      begin
      end;

    procedure TCGInlineNode.Second_Frac_Real;
      begin
        InternalError(2017052104);
      end;

    procedure TCGInlineNode.Second_Abs_Long;
      var
        lTempReg1, lTempReg2: TRegister;
{$if not(defined(cpu64bitalu)) and not defined(cpuhighleveltarget)}
        lTempReg64: TRegister64;
{$endif not(defined(cpu64bitalu)) and not defined(cpuhighleveltarget)}
        lOverflowLoc: TLocation;
      begin
        SecondPass(Left);
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,false);
        Location:=Left.Location;
{$if not(defined(cpu64bitalu)) and not defined(cpuhighleveltarget)}
        if Is_64BitInt(Left.ResultDef) then
          begin
            Location:=Left.Location;
            Location.Register64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
            Location.Register64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
            cg64.A_Load64_Reg_Reg(CurrentAsmData.CurrAsmList,Left.Location.Register64,Location.Register64);
            cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SAR,OS_32,31,Left.Location.Register64.RegHi);
            lTempReg64.RegHi:=Left.Location.Register64.RegHi;
            lTempReg64.RegLo:=Left.Location.Register64.RegHi;
            cg64.A_Op64_Reg_Reg(CurrentAsmData.CurrAsmList,OP_XOR,Def_CGSize(ResultDef),lTempReg64,Location.Register64);
            if cs_check_overflow in CurrentSettings.LocalSwitches then
              begin
                cg64.A_Op64_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmList,OP_SUB,Def_CGSize(ResultDef),lTempReg64,Location.Register64,Location.Register64,true,lOverflowLoc);
                hlcg.G_OverflowCheck_Loc(CurrentAsmData.CurrAsmList,Location,ResultDef,lOverflowLoc);
              end
            else
              cg64.A_Op64_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SUB,Def_CGSize(ResultDef),lTempReg64,Location.Register64,Location.Register64);
          end
        else
{$endif not(defined(cpu64bitalu)) and not defined(cpuhighleveltarget)}
          begin
            Location.Register:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,Left.ResultDef);

            lTempReg1:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,Left.ResultDef);
            lTempReg2:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,Left.ResultDef);

            hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SAR,Left.ResultDef,Left.ResultDef.Size*8-1,Left.Location.Register,lTempReg1);
            hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,OP_XOR,Left.ResultDef,Left.Location.Register,lTempReg1,lTempReg2);

            if cs_check_overflow in CurrentSettings.LocalSwitches then
              begin
                hlcg.A_Op_Reg_Reg_Reg_CheckOverflow(CurrentAsmData.CurrAsmlist,OP_SUB,ResultDef,lTempReg1,lTempReg2,Location.Register,true,lOverflowLoc);
                hlcg.G_OverflowCheck_Loc(CurrentAsmData.CurrAsmList,Location,ResultDef,lOverflowLoc);
              end
            else
              hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmlist,OP_SUB,ResultDef,lTempReg1,lTempReg2,Location.Register);
          end;
      end;


{*****************************************************************************
                         ASSIGNED GENERIC HANDLING
*****************************************************************************}

    procedure TCGInlineNode.Second_Assigned;
      begin
        InternalError(2013091602);
      end;

    procedure TCGInlineNode.Second_Get_Frame;

    begin
{$if defined(x86)}
      if CurrentProcInfo.FramePointer=NR_STACK_POINTER_REG then
        begin
          Location_Reset(Location,LOC_CONSTANT,OS_ADDR);
          Location.Value:=0;
        end
      else
{$endif}
        begin
          Location_Reset(Location,LOC_CREGISTER,OS_ADDR);
          Location.Register:=CurrentProcInfo.FramePointer;
        end;
    end;

    procedure TCGInlineNode.Second_Get_Caller_Frame;

    var
      lFrameReg:TRegister;
      lUseFramePointer:Boolean;

    begin
      lFrameReg:=NR_NO;

      if Left<>nil then
        begin
          SecondPass(Left);
          if Left.Location.Loc=LOC_CONSTANT then
            lUseFramePointer:=true
          else
            begin
              hlcg.Location_Force_Reg(CurrentAsmData.currasmlist,Left.Location,Left.ResultDef,VoidPointerType,false);
              lFrameReg:=Left.Location.Register;
              lUseFramePointer:=false;
            end
        end
      else
        begin
          lUseFramePointer:=CurrentProcInfo.FramePointer=NR_STACK_POINTER_REG;
          lFrameReg:=CurrentProcInfo.FramePointer;
        end;

      if lUseFramePointer then
        begin
          Location_Reset(Location,LOC_CREGISTER,OS_ADDR);
          Location.Register:=NR_FRAME_POINTER_REG;
        end
      else
        begin
          Location_Reset_Ref(Location,LOC_REFERENCE,OS_ADDR,sizeof(PInt),[]);
          Location.Reference.Base:=lFrameReg;
        end;
    end;

    procedure TCGInlineNode.Second_Get_Caller_Addr;
      var
        lFrameReference:TReference;
      begin
        if CurrentProcInfo.FramePointer=NR_STACK_POINTER_REG then
          begin
            Location_Reset(Location,LOC_REGISTER,OS_ADDR);
            Location.Register:=cg.GetAddressRegister(CurrentAsmData.currasmlist);
            Reference_Reset_Base(lFrameReference,NR_STACK_POINTER_REG,{current_procinfo.calc_stackframe_size}TG.LastTemp,CTempPosInvalid,sizeof(PInt),[]);
            cg.A_Load_Ref_Reg(CurrentAsmData.currasmlist,OS_ADDR,OS_ADDR,lFrameReference,Location.Register);
          end
        else
          begin
            Location_Reset(Location,LOC_REGISTER,OS_ADDR);
            Location.Register:=cg.GetAddressRegister(CurrentAsmData.currasmlist);
            Reference_Reset_Base(lFrameReference,CurrentProcInfo.FramePointer,sizeof(PInt),CTempPosInvalid,sizeof(PInt),[]);
            cg.A_Load_Ref_Reg(CurrentAsmData.currasmlist,OS_ADDR,OS_ADDR,lFrameReference,Location.Register);
          end;
      end;


    procedure TCGInlineNode.Second_ROX_SAR;
      var
        lOp : TOpCG;
        lOperand1,lOperand2 : TNode;
      begin
        { one or two parameters? }
        if (Left.NodeType=callparan) and
           Assigned(TCallParaNode(Left).Right) then
          begin
            lOperand1:=TCallParaNode(TCallParaNode(Left).Right).Left;
            lOperand2:=TCallParaNode(Left).Left;
            SecondPass(lOperand2);
          end
        else
          begin
            lOperand1:=Left;
            lOperand2:=nil;
          end;

        SecondPass(lOperand1);
        case InlineNumber of
          in_ror_x,
          in_ror_x_y:
            lOp:=OP_ROR;
          in_rol_x,
          in_rol_x_y:
            lOp:=OP_ROL;
          in_sar_x,
          in_sar_x_y:
            lOp:=OP_SAR;
          else
            InternalError(2013120110);
        end;

        if not(lOperand1.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,lOperand1.Location,lOperand1.ResultDef,ResultDef,true);

        Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
        if Def_CGSize(ResultDef) in [OS_64,OS_S64] then
          begin
            Location.Register64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
            Location.Register64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
          end
        else
{$endif not cpu64bitalu and not cpuhighleveltarget}
          Location.Register:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ResultDef);

        if Assigned(lOperand2) then
          begin
             { rotating by a constant directly coded: }
             if lOperand2.NodeType=ordconstn then
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
               if Def_CGSize(ResultDef) in [OS_64,OS_S64] then
                 cg64.A_Op64_Const_Reg_Reg(CurrentAsmData.CurrAsmList,lOp,Def_CGSize(ResultDef),
                   TOrdConstNode(lOperand2).Value.uvalue and (ResultDef.Size*8-1),
                   lOperand1.Location.Register64, Location.Register64)
               else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                 hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,lOp,ResultDef,
                   TOrdConstNode(lOperand2).Value.uvalue and (ResultDef.Size*8-1),
                   lOperand1.Location.Register, Location.Register)
             else
               begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                 if Def_CGSize(ResultDef) in [OS_64,OS_S64] then
                   begin
                     if not(lOperand2.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) or
                       not(Equal_Defs(lOperand2.ResultDef,ALUSIntType)) then
                       hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,lOperand2.Location,
                                               lOperand2.ResultDef,ALUSIntType,true);
                     cg64.A_Op64_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,lOp,Def_CGSize(ResultDef),
                                             JoinReg64(lOperand2.Location.Register,NR_NO),lOperand1.Location.Register64,
                                             Location.Register64);
                   end
                 else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                   begin
                     if not(lOperand2.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) or
                       not(Equal_Defs(lOperand2.ResultDef,ResultDef)) then
                       hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,lOperand2.Location,
                                               lOperand2.ResultDef,ResultDef,true);
                     hlcg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,lOp,ResultDef,
                                           lOperand2.Location.Register,lOperand1.Location.Register,
                                           Location.Register);
                   end;
               end;
          end
        else
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
          if Def_CGSize(ResultDef) in [OS_64,OS_S64] then
            cg64.A_Op64_Const_Reg_Reg(CurrentAsmData.CurrAsmList,lOp,Def_CGSize(ResultDef),1,
                                      lOperand1.Location.Register64,Location.Register64)
          else
{$endif not cpu64bitalu and not cpuhighleveltarget}
            hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,lOp,ResultDef,1,
                                    lOperand1.Location.Register,Location.Register);
      end;


    procedure TCGInlineNode.Second_BsfBsr;
    var
      lReverse: Boolean;
      lOpSize: TCgSize;
    begin
      SecondPass(Left);

      lOpSize:=TCgSize2Unsigned[Left.Location.Size];
      if not(Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,CGSize_OrdDef(lOpSize),true);

      Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
      Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Location.Size);
      cg.A_Bit_Scan_Reg_Reg(CurrentAsmData.CurrAsmList,InlineNumber=in_bsr_x,Node_Not_Zero(Left),lOpSize,Location.Size,Left.Location.Register,Location.Register);
    end;


    procedure TCGInlineNode.Second_New;
      begin
        InternalError(2011012202);
      end;


    procedure TCGInlineNode.Second_PopCnt;
      begin
        InternalError(2012082602);
      end;


    procedure TCGInlineNode.Second_FMA;
      begin
        InternalError(2014032701);
      end;


    procedure TCGInlineNode.Second_MinMax;
      begin
        InternalError(2020120510);
      end;

begin
   CInlineNode:=TCGInlineNode;
end.
