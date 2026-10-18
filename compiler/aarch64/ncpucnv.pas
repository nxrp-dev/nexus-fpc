{
    Copyright (c) 2014 by Jonas Maebe

    Generate AArch64 assembler for type converting nodes

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

 ****************************************************************************}
unit ncpucnv;

{$i fpcdefs.inc}

interface

    uses
      node,ncnv,ncgcnv;

    type
      TAArch64TypeConvNode = class(TCGTypeConvNode)
        protected
         function TypeCheck_Int_To_Real: TNode; override;
         function First_Int_To_Real: TNode; override;

        { procedure second_int_to_int;override; }
        { procedure second_string_to_string;override; }
        { procedure second_cstring_to_pchar;override; }
        { procedure second_string_to_chararray;override; }
        { procedure second_array_to_pointer;override; }
        { procedure second_pointer_to_array;override; }
        { procedure second_chararray_to_string;override; }
        { procedure second_char_to_string;override; }
         procedure Second_Int_To_Real;override;
        { procedure second_real_to_real;override; }
        { procedure second_cord_to_pointer;override; }
        { procedure second_proc_to_procvar;override; }
        { procedure second_bool_to_int;override; }
         procedure Second_Int_To_Bool;override;
        { procedure second_load_smallset;override;  }
        { procedure second_ansistring_to_pchar;override; }
        { procedure second_pchar_to_string;override; }
        { procedure second_class_to_intf;override; }
        { procedure second_char_to_char;override; }
      end;

implementation

  uses
    Verbose,Globals,
    symdef,AAsmData,aasmbase,
    defutil,
    cgbase,cgutils,ProcInfo,
    cpubase,aasmcpu,
    pass_2,cgobj,
    hlcgobj;


{*****************************************************************************
                             FirstTypeConv
*****************************************************************************}

  function TAArch64TypeConvNode.TypeCheck_Int_To_Real: TNode;
    begin
      { aarch64 supports converting everything to floating point, even fixed
        point! Unfortunately, it only supports fixed point with a power-of-2
        fraction, which is not the case for currency.

        Generate the division by 10000 via nodes so the 10000.0 constant can
        be reused. }
      if Is_Currency(ResultDef) and
         not(nf_is_currency in Flags) then
        begin
          { convert the equivalent int64 value to double without conversion
            (internal typecast -> will set nf_is_currency flag) }
          Result:=CTypeConvNode.Create_Internal(Left,S64FloatType);
          { turn into currency with conversion, which will divide by 10000
            (regular typecast) }
          Result:=CTypeConvNode.Create(Result,S64CurrencyType);
          exit;
        end;
      { The only other thing we have to take care of: convert values < 32 bit
        to 32 bit }
      if Left.ResultDef.Size<4 then
        begin
          if Is_Signed(Left.ResultDef) then
            InsertTypeConv(Left,S32IntType)
          else
            InsertTypeConv(Left,U32IntType)
        end;
      Result:=inherited;
    end;


  function TAArch64TypeConvNode.First_Int_To_Real: TNode;
    begin
      Result:=nil;
      ExpectLoc:=LOC_MMREGISTER;
    end;


{*****************************************************************************
                             SecondTypeConv
*****************************************************************************}

  procedure TAArch64TypeConvNode.Second_Int_To_Real;
    var
      lAsmOp: TAsmOp;
    begin
      Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));
      Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
      hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,true);
      if not(Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
        InternalError(2014120401);
      case Left.Location.Size of
        OS_32,
        OS_64:
          lAsmOp:=A_UCVTF;
        OS_S32,
        OS_S64,
        { for currency and comp }
        OS_F64:
          lAsmOp:=A_SCVTF;
        else
          InternalError(2014120402);
      end;
      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lAsmOp,Location.Register,Left.Location.Register));
      { no scaling for currency, that's handled in pass_typecheck }
    end;


  procedure TAArch64TypeConvNode.Second_Int_To_Bool;
    var
      lResFlags: TResFlags;
    begin
      if (nf_explicit in Flags) and
         not(Left.ExpectLoc in [LOC_FLAGS,LOC_JUMP]) then
        begin
          inherited;
          exit;
        end;

      { can't use the generic code, as it assumes that OP_OR automatically sets
        the flags. We can also do things more efficiently directly }

      SecondPass(Left);
      if CodeGenError then
       exit;

      case Left.Location.Loc of
        LOC_SUBSETREG,
        LOC_CSUBSETREG,
        LOC_SUBSETREF,
        LOC_CSUBSETREF,
        LOC_CREFERENCE,
        LOC_REFERENCE,
        LOC_REGISTER,
        LOC_CREGISTER,
        LOC_JUMP:
          begin
             hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,true);
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_const(A_CMP,Left.Location.Register,0));
             lResFlags:=F_NE;
          end;
        LOC_FLAGS :
          lResFlags:=Left.Location.ResFlags;
        else
          InternalError(2014122902);
      end;
      { load flags to register }
      Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
      Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Location.Size);
      if Is_CBool(ResultDef) then
        begin
          CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_cond(A_CSETM,Location.Register,flags_to_cond(lResFlags)));
            { truncate? (in case cbools are ever made unsigned) }
            if ResultDef.Size<4 then
              cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_32,Location.Size,Location.Register,Location.Register);
        end
      else
        cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,Location.Size,lResFlags,Location.Register);
      cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
    end;


begin
   CTypeConvNode:=TAArch64TypeConvNode;
end.
