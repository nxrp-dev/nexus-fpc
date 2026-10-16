{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate x86-64 assembler for type converting nodes

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
unit nx64cnv;

{$i fpcdefs.inc}

interface

    uses
      node,defutil,pass_1,
      nx86cnv;

    type
       TX8664TypeConvNode = class(TX86TypeConvNode)
         protected
         function first_nothing : TNode;override;
         { procedure second_int_to_int;override; }
         { procedure second_string_to_string;override; }
         { procedure second_cstring_to_pchar;override; }
         { procedure second_string_to_chararray;override; }
         { procedure second_array_to_pointer;override; }
         { procedure second_pointer_to_array;override; }
         { procedure second_chararray_to_string;override; }
         { procedure second_char_to_string;override; }
         { function first_int_to_real: tnode; override; }
         function first_int_to_real : TNode;override;
         procedure second_int_to_real;override;
         { procedure second_real_to_real;override; }
         { procedure second_cord_to_pointer;override; }
         { procedure second_proc_to_procvar;override; }
         { procedure second_bool_to_int;override; }
         { procedure second_int_to_bool;override; }
         { procedure second_load_smallset;override;  }
         { procedure second_ansistring_to_pchar;override; }
         { procedure second_pchar_to_string;override; }
         { procedure second_class_to_intf;override;  }
         { procedure second_char_to_char;override; }
       end;


implementation

    uses
      Verbose,Globals,GlobType,
      aasmbase,aasmtai,AAsmData,aasmcpu,
      symconst,symdef,
      cgbase,cga,
      ncnv,
      cpubase,CPUInfo,
      cgutils,cgobj,hlcgobj,cgx86;


    function TX8664TypeConvNode.first_nothing : TNode;
      begin
        result:=nil;
        { If typecasting between a Single or Double and a record of equal size,
          we can use MOVD and MOVQ }
        if (resultdef.typ in [recorddef,orddef]) and
          Use_VectorFPU(left.resultdef) and
          (resultdef.Size=left.resultdef.Size) then
          expectloc:=LOC_MMREGISTER
        else if (left.resultdef.typ in [recorddef,orddef]) and
          Use_VectorFPU(resultdef) and
          (resultdef.Size=left.resultdef.Size) then
          expectloc:=LOC_REGISTER
        else
          result:=inherited first_nothing;
      end;


    function TX8664TypeConvNode.first_int_to_real : TNode;
      begin
        result:=nil;
        if Use_VectorFPU(resultdef) and
           (TOrdDef(left.resultdef).OrdType=u32bit) and
           not(FPUX86_HAS_AVX512F in fpu_capabilities[CurrentSettings.FPUType]) then
          begin
            inserttypeconv(left,S64IntType);
            FirstPass(left);
          end
        else
          result:=inherited first_int_to_real;
       if Use_VectorFPU(resultdef) then
         expectloc:=LOC_MMREGISTER;
      end;


    procedure TX8664TypeConvNode.second_int_to_real;
      var
         href : TReference;
         l1,l2 : TAsmLabel;
         op : TAsmOp;
      begin
        if Use_VectorFPU(resultdef) and not(FPUX86_HAS_AVX512F in fpu_capabilities[CurrentSettings.FPUType]) then
          begin
            if Is_Double(resultdef) then
              op:=A_CVTSI2SD
            else if Is_Single(resultdef) then
              op:=A_CVTSI2SS
            else
              InternalError(200506061);

            Location_Reset(location,LOC_MMREGISTER,Def_CGSize(resultdef));
            location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);

            case TOrdDef(left.resultdef).OrdType of
              u64bit:
                begin
                   { unsigned 64 bit ints are harder to handle:
                     we load bits 0..62 and then check bit 63:
                     if it is 1 then we add $80000000 000000000
                     as double                                  }
                   CurrentAsmData.getdatalabel(l1);
                   CurrentAsmData.getjumplabel(l2);

                   { Get sign bit }
                   if not(left.Location.Loc in [LOC_REGISTER,LOC_REFERENCE]) then
                     hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,false);
                   case left.Location.Loc of
                     LOC_REGISTER :
                       begin
                         cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                         emit_const_reg(A_BT,S_Q,63,left.Location.Register);
                         CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(op,S_Q,left.Location.Register,location.Register));
                       end;
                     LOC_REFERENCE :
                       begin
                         href:=left.Location.Reference;
                         TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,href);
                         inc(href.Offset,4);
                         cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                         emit_const_ref(A_BT,S_L,31,href);
                         dec(href.Offset,4);
                         CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(op,S_Q,href,location.Register));
                       end;
                     else
                       InternalError(200710181);
                   end;

                   cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NC,l2);
                   cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                   new_section(CurrentAsmData.asmlists[al_typedconsts],sec_rodata_norel,l1.name,Const_Align(sizeof(PInt)));
                   CurrentAsmData.asmlists[al_typedconsts].concat(TAILabel.Create(l1));
                   Reference_Reset_Symbol(href,l1,0,4,[]);
                   { simplify for PIC }
                   TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,href);

                   { I got these constant from a test program (FK) }
                   if Is_Double(resultdef) then
                     begin
                       { double (2^64) }
                       CurrentAsmData.asmlists[al_typedconsts].concat(TAIConst.Create_32bit(0));
                       CurrentAsmData.asmlists[al_typedconsts].concat(TAIConst.Create_32bit($43f00000));
                       TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,href);
                       CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(A_ADDSD,S_NO,href,location.Register));
                     end
                   else if Is_Single(resultdef) then
                     begin
                       { single(2^64) }
                       CurrentAsmData.asmlists[al_typedconsts].concat(TAIConst.Create_32bit($5f800000));
                       CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(A_ADDSS,S_NO,href,location.Register));
                     end
                   else
                     InternalError(200506071);
                   cg.A_Label(CurrentAsmData.CurrAsmList,l2);
                end
              else
                inherited second_int_to_real;
            end;
          end
        else
          inherited second_int_to_real;
      end;


begin
   CTypeConvNode:=TX8664TypeConvNode;
end.
