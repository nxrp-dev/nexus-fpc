{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate for x86-64 and i386 assembler for type converting nodes

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
unit nx86cnv;

{$i fpcdefs.inc}

interface

    uses
      node,ncgcnv,defutil;

    type
       TX86TypeConvNode = class(TCGTypeConvNode)
       private
         function int_to_real_mm_location: boolean;
       protected
         function first_real_to_real : TNode;override;
         { procedure second_int_to_int;override; }
         { procedure second_string_to_string;override; }
         { procedure second_cstring_to_pchar;override; }
         { procedure second_string_to_chararray;override; }
         { procedure second_array_to_pointer;override; }
         { procedure second_pointer_to_array;override; }
         { procedure second_chararray_to_string;override; }
         { procedure second_char_to_string;override; }
         function first_int_to_real: TNode; override;
         procedure second_int_to_real;override;
         { procedure second_real_to_real;override; }
         { procedure second_cord_to_pointer;override; }
         { procedure second_proc_to_procvar;override; }
         { procedure second_bool_to_int;override; }
           procedure second_int_to_bool;override;
         { procedure second_set_to_set;override;  }
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
      cgbase,cga,pass_1,pass_2,
      CPUInfo,
      ncnv,
      cpubase,
      cgutils,cgobj,hlcgobj,cgx86,
      tgobj;


    function TX86TypeConvNode.first_real_to_real : TNode;
      begin
         first_real_to_real:=nil;
         if Use_VectorFPU(resultdef) then
           expectloc:=LOC_MMREGISTER
         else
           expectloc:=LOC_FPUREGISTER;
      end;


    procedure TX86TypeConvNode.second_int_to_bool;
      var
{$ifndef cpu64bitalu}
        hreg2,
        hregister : TRegister;
        href      : TReference;
        i         : integer;
{$endif not cpu64bitalu}
        ResFlags  : TResFlags;
        hlabel    : TAsmLabel;
        newsize   : TCgSize;
      begin
         SecondPass(left);
         if CodeGenError then
          exit;
         { Explicit typecasts from any ordinal type to a boolean type }
         { must not change the ordinal value                          }
         if (nf_explicit in flags) and
            not(left.Location.Loc in [LOC_FLAGS,LOC_JUMP]) then
           begin
              Location_Copy(location,left.Location);
              newsize:=Def_CGSize(resultdef);
              { change of size? change sign only if location is LOC_(C)REGISTER? Then we have to sign/zero-extend }
              if (TCgSize2Size[newsize]<>TCgSize2Size[left.Location.Size]) or
                 ((newsize<>left.Location.Size) and (location.Loc in [LOC_REGISTER,LOC_CREGISTER])) then
                hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,location,left.resultdef,resultdef,true)
              else
                location.Size:=newsize;
              exit;
           end;

         { Load left node into flag F_NE/F_E }
         ResFlags:=F_NE;

         if (left.Location.Loc in [LOC_SUBSETREG,LOC_CSUBSETREG,LOC_SUBSETREF,LOC_CSUBSETREF]) then
           hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,true);

         case left.Location.Loc of
            LOC_CREFERENCE,
            LOC_REFERENCE :
              begin
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
{$ifndef cpu64bitalu}
                if left.Location.Size in [OS_64,OS_S64] then
                 begin
                   hregister:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
                   cg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OS_INT,OS_INT,left.Location.Reference,hregister);
                   href:=left.Location.Reference;
                   for i:=2 to TCgSize2Size[left.Location.Size] div TCgSize2Size[OS_INT] do
                     begin
                       inc(href.Offset,TCgSize2Size[OS_INT]);
                       cg.A_Op_Ref_Reg(CurrentAsmData.CurrAsmList,OP_OR,OS_INT,href,hregister);
                     end;
                 end
                else
{$endif not cpu64bitalu}
                 begin
                   hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,true);
                   cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,left.Location.Size,left.Location.Register,left.Location.Register);
                 end;
              end;
            LOC_FLAGS :
              begin
                ResFlags:=left.Location.ResFlags;
              end;
            LOC_REGISTER,LOC_CREGISTER :
              begin
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
{$if defined(cpu32bitalu)}
                if left.Location.Size in [OS_64,OS_S64] then
                 begin
                   hregister:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                   cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_32,OS_32,left.Location.Register64.RegLo,hregister);
                   cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,OS_32,left.Location.Register64.RegHi,hregister);
                 end
                else
{$endif}
                  cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,left.Location.Size,left.Location.Register,left.Location.Register);
              end;
            LOC_JUMP :
              begin
                Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
                location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,location.Size);
                CurrentAsmData.getjumplabel(hlabel);
                cg.A_Label(CurrentAsmData.CurrAsmList,left.Location.TrueLabel);
                if not(Is_CBool(resultdef)) then
                  cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,location.Size,1,location.Register)
                else
                  cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,location.Size,-1,location.Register);
                cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,hlabel);
                cg.A_Label(CurrentAsmData.CurrAsmList,left.Location.FalseLabel);
                cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,location.Size,0,location.Register);
                cg.A_Label(CurrentAsmData.CurrAsmList,hlabel);
              end;
            else
              InternalError(10062);
         end;
         if (left.Location.Loc<>LOC_JUMP) then
           begin
             { load flags to register }
             Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
{$ifndef cpu64bitalu}
              if (location.Size in [OS_64,OS_S64]) then
                begin
                  hreg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                  cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,OS_32,ResFlags,hreg2);
                  cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                  if (Is_CBool(resultdef)) then
                    cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NEG,OS_32,hreg2,hreg2);
                  location.Register64.RegLo:=hreg2;
                  location.Register64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                  if (Is_CBool(resultdef)) then
                    { reglo is either 0 or -1 -> reghi has to become the same }
                    cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_32,OS_32,location.Register64.RegLo,location.Register64.RegHi)
                  else
                    { unsigned }
                    cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_32,0,location.Register64.RegHi);
                end
             else
{$endif not cpu64bitalu}
               begin
                 location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,location.Size);
                 cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,location.Size,ResFlags,location.Register);
                 cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                 if (Is_CBool(resultdef)) then
                   cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NEG,location.Size,location.Register,location.Register);
               end
           end;
       end;


    function TX86TypeConvNode.int_to_real_mm_location : boolean;
      begin
        result:=Use_VectorFPU(resultdef) and
{$ifdef cpu64bitalu}
           ((TOrdDef(left.resultdef).OrdType in [s32bit,s64bit]) or
            ((TOrdDef(left.resultdef).OrdType in [u32bit,u64bit]) and
             (FPUX86_HAS_AVX512F in fpu_capabilities[CurrentSettings.FPUType]))
           );
{$else cpu64bitalu}
           ((TOrdDef(left.resultdef).OrdType=s32bit)
{$ifdef i386}
            or ((TOrdDef(left.resultdef).OrdType=u32bit) and
             (FPUX86_HAS_AVX512F in fpu_capabilities[CurrentSettings.FPUType]))
{$endif i386}
           );
{$endif cpu64bitalu}
      end;


    function TX86TypeConvNode.first_int_to_real : TNode;
      begin
        first_int_to_real:=nil;
        if (left.resultdef.Size<4) then
          begin
            inserttypeconv(left,S32IntType);
            FirstPass(left)
          end;

        if int_to_real_mm_location then
          expectloc:=LOC_MMREGISTER
        else
          expectloc:=LOC_FPUREGISTER;
      end;


    procedure TX86TypeConvNode.second_int_to_real;
      var
         leftref,
         href : TReference;
         l1,l2 : TAsmLabel;
         op: TAsmOp;
         opsize: TOpSize;
         signtested : boolean;
         use_bt: boolean;  { true = use BT (386+), false = use TEST (286-) }
      begin

        use_bt:=true;

        if not(left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_REFERENCE,LOC_CREFERENCE]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,false);
        if int_to_real_mm_location then
          begin
            Location_Reset(location,LOC_MMREGISTER,Def_CGSize(resultdef));
            location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);
            if UseAVX then
              case location.Size of
                OS_F32:
                  if TOrdDef(left.resultdef).OrdType in [s32bit,s64bit] then
                    op:=A_VCVTSI2SS
                  else
                    op:=A_VCVTUSI2SS;
                OS_F64:
                  if TOrdDef(left.resultdef).OrdType in [s32bit,s64bit] then
                    op:=A_VCVTSI2SD
                  else
                    op:=A_VCVTUSI2SD;
                else
                  InternalError(2007120902);
              end
            else
              begin
                { do not use is_signed here as it checks the boundaries instead
                  of the ordtype }
                if not(TOrdDef(left.resultdef).OrdType in [s32bit,s64bit]) then
                  InternalError(2020101001);
                case location.Size of
                  OS_F32:
                    op:=A_CVTSI2SS;
                  OS_F64:
                    op:=A_CVTSI2SD;
                  else
                    InternalError(2007120904);
                end;
              end;

            { don't use left.location.size, because that one may be OS_32/OS_64
              if the lower bound of the orddef >= 0
            }
            case TOrdDef(left.resultdef).OrdType of
              s32bit,u32bit:
                opsize:=S_L;
              s64bit,u64bit:
                opsize:=S_Q;
              else
                InternalError(2007120903);
            end;
            case left.Location.Loc of
              LOC_REFERENCE,
              LOC_CREFERENCE:
                begin
                  href:=left.Location.Reference;
                  TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,href);
                  if UseAVX then
                    { VCVTSI2.. requires a second source operand to copy bits 64..127 }
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg_reg(op,opsize,href,location.Register,location.Register))
                  else
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(op,opsize,href,location.Register));
                end;
              LOC_REGISTER,
              LOC_CREGISTER:
                if UseAVX then
                    { VCVTSI2.. requires a second source operand to copy bits 64..127 }
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(op,opsize,left.Location.Register,location.Register,location.Register))
                else
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(op,opsize,left.Location.Register,location.Register));
              else
                InternalError(2019050708);
            end;
          end
        else
          begin
            Location_Reset(location,LOC_FPUREGISTER,Def_CGSize(resultdef));
            if (left.Location.Loc=LOC_REGISTER) and (TOrdDef(left.resultdef).OrdType=u64bit) then
              begin
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                if use_bt then
                  begin
    {$if defined(cpu64bitalu)}
                    emit_const_reg(A_BT,S_Q,63,left.Location.Register);
    {$elseif defined(cpu32bitalu)}
                    emit_const_reg(A_BT,S_L,31,left.Location.Register64.RegHi);
    {$endif}
                  end
                else
                  begin

                    InternalError(2013052510);

                  end;
                signtested:=true;
              end
            else
              signtested:=false;

            { We need to load from a reference }
            hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,left.Location,left.resultdef);
            { don't change left.location.reference, because if it's a temp we
              need the original location at the end so we can free it }
            leftref:=left.Location.Reference;
            TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,leftref);

            { For u32bit we need to load it as comp and need to
              make it 64bits }
            if (TOrdDef(left.resultdef).OrdType=u32bit) then
              begin
                tg.GetTemp(CurrentAsmData.CurrAsmList,8,8,tt_normal,href);
                location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
                cg.A_Load_Ref_Ref(CurrentAsmData.CurrAsmList,left.Location.Size,OS_32,leftref,href);
                inc(href.Offset,4);
                cg.A_Load_Const_Ref(CurrentAsmData.CurrAsmList,OS_32,0,href);
                dec(href.Offset,4);
                { could be a temp with an offset > 32 bit on x86_64 }
                TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,href);
                leftref:=href;
              end;

            { Load from reference to fpu reg }
            case TOrdDef(left.resultdef).OrdType of
              u32bit,
              scurrency,
              s64bit:
                begin
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref(A_FILD,S_IQ,leftref));
                end;
              u64bit:
                begin
                   { unsigned 64 bit ints are harder to handle:
                     we load bits 0..62 and then check bit 63:
                     if it is 1 then we add 2**64 as float.
                     Since 2**64 can be represented exactly, use a single-precision
                     constant to save space. }
                   CurrentAsmData.getdatalabel(l1);
                   CurrentAsmData.getjumplabel(l2);
                   if not(signtested) then
                     begin
                       if use_bt then
                         begin
           {$if defined(cpu64bitalu) or defined(cpu32bitalu)}
                           inc(leftref.Offset,4);
                           cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                           emit_const_ref(A_BT,S_L,31,leftref);
                           dec(leftref.Offset,4);
           {$endif}
                         end
                       else
                         begin

                           InternalError(2013052511);

                         end;
                     end;

                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref(A_FILD,S_IQ,leftref));
                   if use_bt then
                     cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NC,l2)
                   else
                     cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_E,l2);
                   cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                   new_section(CurrentAsmData.asmlists[al_typedconsts],sec_rodata_norel,l1.name,Const_Align(sizeof(PInt)));
                   CurrentAsmData.asmlists[al_typedconsts].concat(TAILabel.Create(l1));
                   { I got this constant from a test program (FK) }
                   { It's actually the bit representation of 2^64 as a Single [Kit] }
                   CurrentAsmData.asmlists[al_typedconsts].concat(TAIConst.Create_32bit($5f800000));
                   Reference_Reset_Symbol(href,l1,0,4,[]);
                   TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,href);
                   CurrentAsmData.CurrAsmList.concat(TAICPU.Op_ref(A_FADD,S_FS,href));
                   cg.A_Label(CurrentAsmData.CurrAsmList,l2);
                end
              else
                begin
                  if left.resultdef.Size<4 then
                    InternalError(2007120901);
                 CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref(A_FILD,S_IL,leftref));
                end;
            end;
            TCGX86(cg).inc_fpu_stack;
            location.Register:=NR_ST;
            tg.ungetiftemp(CurrentAsmData.CurrAsmList,leftref);
          end;
      end;

begin
  CTypeConvNode:=TX86TypeConvNode
end.
