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
         function typecheck_int_to_real: TNode; override;
         function first_int_to_real: TNode; override;

        { procedure second_int_to_int;override; }
        { procedure second_string_to_string;override; }
        { procedure second_cstring_to_pchar;override; }
        { procedure second_string_to_chararray;override; }
        { procedure second_array_to_pointer;override; }
        { procedure second_pointer_to_array;override; }
        { procedure second_chararray_to_string;override; }
        { procedure second_char_to_string;override; }
         procedure second_int_to_real;override;
        { procedure second_real_to_real;override; }
        { procedure second_cord_to_pointer;override; }
        { procedure second_proc_to_procvar;override; }
        { procedure second_bool_to_int;override; }
         procedure second_int_to_bool;override;
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

  function TAArch64TypeConvNode.typecheck_int_to_real: TNode;
    begin
      { aarch64 supports converting everything to floating point, even fixed
        point! Unfortunately, it only supports fixed point with a power-of-2
        fraction, which is not the case for currency.

        Generate the division by 10000 via nodes so the 10000.0 constant can
        be reused. }
      if is_currency(resultdef) and
         not(nf_is_currency in flags) then
        begin
          { convert the equivalent int64 value to double without conversion
            (internal typecast -> will set nf_is_currency flag) }
          result:=CTypeConvNode.Create_Internal(left,S64FloatType);
          { turn into currency with conversion, which will divide by 10000
            (regular typecast) }
          result:=CTypeConvNode.create(result,S64CurrencyType);
          exit;
        end;
      { The only other thing we have to take care of: convert values < 32 bit
        to 32 bit }
      if left.resultdef.size<4 then
        begin
          if is_signed(left.resultdef) then
            inserttypeconv(left,S32IntType)
          else
            inserttypeconv(left,U32IntType)
        end;
      result:=inherited;
    end;


  function TAArch64TypeConvNode.first_int_to_real: TNode;
    begin
      result:=nil;
      expectloc:=LOC_MMREGISTER;
    end;


{*****************************************************************************
                             SecondTypeConv
*****************************************************************************}

  procedure TAArch64TypeConvNode.second_int_to_real;
    var
      op: TAsmOp;
    begin
      location_reset(location,LOC_MMREGISTER,def_cgsize(resultdef));
      location.register:=cg.getmmregister(CurrentAsmData.CurrAsmList,location.size);
      hlcg.location_force_reg(CurrentAsmData.CurrAsmList,left.location,left.resultdef,left.resultdef,true);
      if not(left.location.loc in [LOC_REGISTER,LOC_CREGISTER]) then
        InternalError(2014120401);
      case left.location.size of
        OS_32,
        OS_64:
          op:=A_UCVTF;
        OS_S32,
        OS_S64,
        { for currency and comp }
        OS_F64:
          op:=A_SCVTF;
        else
          InternalError(2014120402);
      end;
      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(op,location.register,left.location.register));
      { no scaling for currency, that's handled in pass_typecheck }
    end;


  procedure TAArch64TypeConvNode.second_int_to_bool;
    var
      resflags: TResFlags;
    begin
      if (nf_explicit in flags) and
         not(left.expectloc in [LOC_FLAGS,LOC_JUMP]) then
        begin
          inherited;
          exit;
        end;

      { can't use the generic code, as it assumes that OP_OR automatically sets
        the flags. We can also do things more efficiently directly }

      SecondPass(left);
      if CodeGenError then
       exit;

      case left.location.loc of
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
             hlcg.location_force_reg(CurrentAsmData.CurrAsmList,left.location,left.resultdef,left.resultdef,true);
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_const(A_CMP,left.location.register,0));
             resflags:=F_NE;
          end;
        LOC_FLAGS :
          resflags:=left.location.resflags;
        else
          InternalError(2014122902);
      end;
      { load flags to register }
      location_reset(location,LOC_REGISTER,def_cgsize(resultdef));
      location.register:=cg.getintregister(CurrentAsmData.CurrAsmList,location.size);
      if is_cbool(resultdef) then
        begin
          CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_cond(A_CSETM,location.register,flags_to_cond(resflags)));
            { truncate? (in case cbools are ever made unsigned) }
            if resultdef.size<4 then
              cg.a_load_reg_reg(CurrentAsmData.CurrAsmList,OS_32,location.size,location.register,location.register);
        end
      else
        cg.g_flags2reg(CurrentAsmData.CurrAsmList,location.size,resflags,location.register);
      cg.a_reg_dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
    end;


begin
   CTypeConvNode:=TAArch64TypeConvNode;
end.
