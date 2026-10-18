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
         function IntToRealMMLocation: Boolean;
       protected
         function First_Real_To_Real : TNode;override;
         { procedure second_int_to_int;override; }
         { procedure second_string_to_string;override; }
         { procedure second_cstring_to_pchar;override; }
         { procedure second_string_to_chararray;override; }
         { procedure second_array_to_pointer;override; }
         { procedure second_pointer_to_array;override; }
         { procedure second_chararray_to_string;override; }
         { procedure second_char_to_string;override; }
         function First_Int_To_Real: TNode; override;
         procedure Second_Int_To_Real;override;
         { procedure second_real_to_real;override; }
         { procedure second_cord_to_pointer;override; }
         { procedure second_proc_to_procvar;override; }
         { procedure second_bool_to_int;override; }
           procedure Second_Int_To_Bool;override;
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
      cgbase,cga,Pass_1,pass_2,
      CPUInfo,
      ncnv,
      cpubase,
      cgutils,cgobj,hlcgobj,cgx86,
      tgobj;


    function TX86TypeConvNode.First_Real_To_Real : TNode;
      begin
         First_Real_To_Real:=nil;
         if Use_VectorFPU(ResultDef) then
           ExpectLoc:=LOC_MMREGISTER
         else
           ExpectLoc:=LOC_FPUREGISTER;
      end;


    procedure TX86TypeConvNode.Second_Int_To_Bool;
      var
{$ifndef cpu64bitalu}
        lRegister2,
        lRegister : TRegister;
        lReference      : TReference;
        lIndex         : Integer;
{$endif not cpu64bitalu}
        lResFlags  : TResFlags;
        lLabel    : TAsmLabel;
        lNewSize   : TCgSize;
      begin
         SecondPass(Left);
         if CodeGenError then
          exit;
         { Explicit typecasts from any ordinal type to a boolean type }
         { must not change the ordinal value                          }
         if (nf_explicit in Flags) and
            not(Left.Location.Loc in [LOC_FLAGS,LOC_JUMP]) then
           begin
              Location_Copy(Location,Left.Location);
              lNewSize:=Def_CGSize(ResultDef);
              { change of size? change sign only if location is LOC_(C)REGISTER? Then we have to sign/zero-extend }
              if (TCgSize2Size[lNewSize]<>TCgSize2Size[Left.Location.Size]) or
                 ((lNewSize<>Left.Location.Size) and (Location.Loc in [LOC_REGISTER,LOC_CREGISTER])) then
                hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Location,Left.ResultDef,ResultDef,true)
              else
                Location.Size:=lNewSize;
              exit;
           end;

         { Load left node into flag F_NE/F_E }
         lResFlags:=F_NE;

         if (Left.Location.Loc in [LOC_SUBSETREG,LOC_CSUBSETREG,LOC_SUBSETREF,LOC_CSUBSETREF]) then
           hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,true);

         case Left.Location.Loc of
            LOC_CREFERENCE,
            LOC_REFERENCE :
              begin
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
{$ifndef cpu64bitalu}
                if Left.Location.Size in [OS_64,OS_S64] then
                 begin
                   lRegister:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
                   cg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OS_INT,OS_INT,Left.Location.Reference,lRegister);
                   lReference:=Left.Location.Reference;
                   for lIndex:=2 to TCgSize2Size[Left.Location.Size] div TCgSize2Size[OS_INT] do
                     begin
                       inc(lReference.Offset,TCgSize2Size[OS_INT]);
                       cg.A_Op_Ref_Reg(CurrentAsmData.CurrAsmList,OP_OR,OS_INT,lReference,lRegister);
                     end;
                 end
                else
{$endif not cpu64bitalu}
                 begin
                   hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,true);
                   cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,Left.Location.Size,Left.Location.Register,Left.Location.Register);
                 end;
              end;
            LOC_FLAGS :
              begin
                lResFlags:=Left.Location.ResFlags;
              end;
            LOC_REGISTER,LOC_CREGISTER :
              begin
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
{$if defined(cpu32bitalu)}
                if Left.Location.Size in [OS_64,OS_S64] then
                 begin
                   lRegister:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                   cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_32,OS_32,Left.Location.Register64.RegLo,lRegister);
                   cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,OS_32,Left.Location.Register64.RegHi,lRegister);
                 end
                else
{$endif}
                  cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_OR,Left.Location.Size,Left.Location.Register,Left.Location.Register);
              end;
            LOC_JUMP :
              begin
                Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
                Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Location.Size);
                CurrentAsmData.getjumplabel(lLabel);
                cg.A_Label(CurrentAsmData.CurrAsmList,Left.Location.TrueLabel);
                if not(Is_CBool(ResultDef)) then
                  cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,Location.Size,1,Location.Register)
                else
                  cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,Location.Size,-1,Location.Register);
                cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lLabel);
                cg.A_Label(CurrentAsmData.CurrAsmList,Left.Location.FalseLabel);
                cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,Location.Size,0,Location.Register);
                cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
              end;
            else
              InternalError(10062);
         end;
         if (Left.Location.Loc<>LOC_JUMP) then
           begin
             { load flags to register }
             Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
{$ifndef cpu64bitalu}
              if (Location.Size in [OS_64,OS_S64]) then
                begin
                  lRegister2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                  cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,OS_32,lResFlags,lRegister2);
                  cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                  if (Is_CBool(ResultDef)) then
                    cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NEG,OS_32,lRegister2,lRegister2);
                  Location.Register64.RegLo:=lRegister2;
                  Location.Register64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                  if (Is_CBool(ResultDef)) then
                    { reglo is either 0 or -1 -> reghi has to become the same }
                    cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_32,OS_32,Location.Register64.RegLo,Location.Register64.RegHi)
                  else
                    { unsigned }
                    cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_32,0,Location.Register64.RegHi);
                end
             else
{$endif not cpu64bitalu}
               begin
                 Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Location.Size);
                 cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,Location.Size,lResFlags,Location.Register);
                 cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                 if (Is_CBool(ResultDef)) then
                   cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NEG,Location.Size,Location.Register,Location.Register);
               end
           end;
       end;


    function TX86TypeConvNode.IntToRealMMLocation : Boolean;
      begin
        Result:=Use_VectorFPU(ResultDef) and
{$ifdef cpu64bitalu}
           ((TOrdDef(Left.ResultDef).OrdType in [s32bit,s64bit]) or
            ((TOrdDef(Left.ResultDef).OrdType in [u32bit,u64bit]) and
             (FPUX86_HAS_AVX512F in fpu_capabilities[CurrentSettings.FPUType]))
           );
{$else cpu64bitalu}
           ((TOrdDef(Left.ResultDef).OrdType=s32bit)
{$ifdef i386}
            or ((TOrdDef(Left.ResultDef).OrdType=u32bit) and
             (FPUX86_HAS_AVX512F in fpu_capabilities[CurrentSettings.FPUType]))
{$endif i386}
           );
{$endif cpu64bitalu}
      end;


    function TX86TypeConvNode.First_Int_To_Real : TNode;
      begin
        First_Int_To_Real:=nil;
        if (Left.ResultDef.Size<4) then
          begin
            InsertTypeConv(Left,S32IntType);
            FirstPass(Left)
          end;

        if IntToRealMMLocation then
          ExpectLoc:=LOC_MMREGISTER
        else
          ExpectLoc:=LOC_FPUREGISTER;
      end;


    procedure TX86TypeConvNode.Second_Int_To_Real;
      var
         lLeftReference,
         lReference : TReference;
         lDataLabel,lJumpLabel : TAsmLabel;
         lAsmOp: TAsmOp;
         lOpSize: TOpSize;
         lSignTested : Boolean;
         lUseBitTest: Boolean;  { true = use BT (386+), false = use TEST (286-) }
      begin

        lUseBitTest:=true;

        if not(Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_REFERENCE,LOC_CREFERENCE]) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,false);
        if IntToRealMMLocation then
          begin
            Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));
            Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
            if UseAVX then
              case Location.Size of
                OS_F32:
                  if TOrdDef(Left.ResultDef).OrdType in [s32bit,s64bit] then
                    lAsmOp:=A_VCVTSI2SS
                  else
                    lAsmOp:=A_VCVTUSI2SS;
                OS_F64:
                  if TOrdDef(Left.ResultDef).OrdType in [s32bit,s64bit] then
                    lAsmOp:=A_VCVTSI2SD
                  else
                    lAsmOp:=A_VCVTUSI2SD;
                else
                  InternalError(2007120902);
              end
            else
              begin
                { do not use is_signed here as it checks the boundaries instead
                  of the ordtype }
                if not(TOrdDef(Left.ResultDef).OrdType in [s32bit,s64bit]) then
                  InternalError(2020101001);
                case Location.Size of
                  OS_F32:
                    lAsmOp:=A_CVTSI2SS;
                  OS_F64:
                    lAsmOp:=A_CVTSI2SD;
                  else
                    InternalError(2007120904);
                end;
              end;

            { don't use left.location.size, because that one may be OS_32/OS_64
              if the lower bound of the orddef >= 0
            }
            case TOrdDef(Left.ResultDef).OrdType of
              s32bit,u32bit:
                lOpSize:=S_L;
              s64bit,u64bit:
                lOpSize:=S_Q;
              else
                InternalError(2007120903);
            end;
            case Left.Location.Loc of
              LOC_REFERENCE,
              LOC_CREFERENCE:
                begin
                  lReference:=Left.Location.Reference;
                  TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,lReference);
                  if UseAVX then
                    { VCVTSI2.. requires a second source operand to copy bits 64..127 }
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg_reg(lAsmOp,lOpSize,lReference,Location.Register,Location.Register))
                  else
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(lAsmOp,lOpSize,lReference,Location.Register));
                end;
              LOC_REGISTER,
              LOC_CREGISTER:
                if UseAVX then
                    { VCVTSI2.. requires a second source operand to copy bits 64..127 }
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(lAsmOp,lOpSize,Left.Location.Register,Location.Register,Location.Register))
                else
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(lAsmOp,lOpSize,Left.Location.Register,Location.Register));
              else
                InternalError(2019050708);
            end;
          end
        else
          begin
            Location_Reset(Location,LOC_FPUREGISTER,Def_CGSize(ResultDef));
            if (Left.Location.Loc=LOC_REGISTER) and (TOrdDef(Left.ResultDef).OrdType=u64bit) then
              begin
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                if lUseBitTest then
                  begin
    {$if defined(cpu64bitalu)}
                    emit_const_reg(A_BT,S_Q,63,Left.Location.Register);
    {$elseif defined(cpu32bitalu)}
                    emit_const_reg(A_BT,S_L,31,Left.Location.Register64.RegHi);
    {$endif}
                  end
                else
                  begin

                    InternalError(2013052510);

                  end;
                lSignTested:=true;
              end
            else
              lSignTested:=false;

            { We need to load from a reference }
            hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef);
            { don't change left.location.reference, because if it's a temp we
              need the original location at the end so we can free it }
            lLeftReference:=Left.Location.Reference;
            TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,lLeftReference);

            { For u32bit we need to load it as comp and need to
              make it 64bits }
            if (TOrdDef(Left.ResultDef).OrdType=u32bit) then
              begin
                TG.GetTemp(CurrentAsmData.CurrAsmList,8,8,tt_normal,lReference);
                Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);
                cg.A_Load_Ref_Ref(CurrentAsmData.CurrAsmList,Left.Location.Size,OS_32,lLeftReference,lReference);
                inc(lReference.Offset,4);
                cg.A_Load_Const_Ref(CurrentAsmData.CurrAsmList,OS_32,0,lReference);
                dec(lReference.Offset,4);
                { could be a temp with an offset > 32 bit on x86_64 }
                TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,lReference);
                lLeftReference:=lReference;
              end;

            { Load from reference to fpu reg }
            case TOrdDef(Left.ResultDef).OrdType of
              u32bit,
              scurrency,
              s64bit:
                begin
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref(A_FILD,S_IQ,lLeftReference));
                end;
              u64bit:
                begin
                   { unsigned 64 bit ints are harder to handle:
                     we load bits 0..62 and then check bit 63:
                     if it is 1 then we add 2**64 as float.
                     Since 2**64 can be represented exactly, use a single-precision
                     constant to save space. }
                   CurrentAsmData.getdatalabel(lDataLabel);
                   CurrentAsmData.getjumplabel(lJumpLabel);
                   if not(lSignTested) then
                     begin
                       if lUseBitTest then
                         begin
           {$if defined(cpu64bitalu) or defined(cpu32bitalu)}
                           inc(lLeftReference.Offset,4);
                           cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                           emit_const_ref(A_BT,S_L,31,lLeftReference);
                           dec(lLeftReference.Offset,4);
           {$endif}
                         end
                       else
                         begin

                           InternalError(2013052511);

                         end;
                     end;

                   CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref(A_FILD,S_IQ,lLeftReference));
                   if lUseBitTest then
                     cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NC,lJumpLabel)
                   else
                     cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_E,lJumpLabel);
                   cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                   new_section(CurrentAsmData.asmlists[al_typedconsts],sec_rodata_norel,lDataLabel.name,Const_Align(sizeof(PInt)));
                   CurrentAsmData.asmlists[al_typedconsts].concat(TAILabel.Create(lDataLabel));
                   { I got this constant from a test program (FK) }
                   { It's actually the bit representation of 2^64 as a Single [Kit] }
                   CurrentAsmData.asmlists[al_typedconsts].concat(TAIConst.Create_32bit($5f800000));
                   Reference_Reset_Symbol(lReference,lDataLabel,0,4,[]);
                   TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,lReference);
                   CurrentAsmData.CurrAsmList.concat(TAICPU.Op_ref(A_FADD,S_FS,lReference));
                   cg.A_Label(CurrentAsmData.CurrAsmList,lJumpLabel);
                end
              else
                begin
                  if Left.ResultDef.Size<4 then
                    InternalError(2007120901);
                 CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref(A_FILD,S_IL,lLeftReference));
                end;
            end;
            TCGX86(cg).inc_fpu_stack;
            Location.Register:=NR_ST;
            TG.UnGetIfTemp(CurrentAsmData.CurrAsmList,lLeftReference);
          end;
      end;

begin
  CTypeConvNode:=TX86TypeConvNode
end.
