{
    Copyright (c) 1998-2005 by Florian Klaempfl

    This unit implements the common parts of the code generator for the i386 and the x86-64.

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
{ This unit implements the common parts of the code generator for the i386 and the x86-64.
}
unit cgx86;

{$i fpcdefs.inc}

  interface

    uses
       GlobType,
       cgbase,cgutils,cgobj,
       aasmbase,aasmtai,AAsmData,aasmcpu,
       cpubase,CPUInfo,rgx86,
       symconst,symtype,symdef,
       parabase;

    type
      TCopyMode=(copy_mov,copy_mmx,copy_string,copy_mm,copy_avx,copy_avx512,copy_fpc_move);

      TCGX86 = class(TCG)
        rgfpu   : TRGX86FPU;
        procedure Done_Register_Allocators;override;

        function GetFPURegister(list:TAsmList;size:TCgSize):TRegister;override;
        function GetMMXRegister(list:TAsmList):TRegister;
        function GetMMRegister(list:TAsmList;size:TCgSize):TRegister;override;

        procedure GetCPURegister(list:TAsmList;r:TRegister);override;
        procedure UngetCPURegister(list:TAsmList;r:TRegister);override;
        procedure AllocCPURegisters(list:TAsmList;rt:TRegisterType;const r:TCPURegisterSet);override;
        procedure DeallocCPURegisters(list:TAsmList;rt:TRegisterType;const r:TCPURegisterSet);override;
        function  Uses_Registers(rt:TRegisterType):boolean;override;
        procedure Add_Reg_Instruction(instr:TAI;r:TRegister);override;
        procedure dec_fpu_stack;
        procedure inc_fpu_stack;

        procedure A_Call_Name(list : TAsmList;const s : string; weak: boolean);override;
        procedure a_call_name_near(list : TAsmList;const s : string; weak: boolean);
        procedure A_Call_Name_Static(list : TAsmList;const s : string);override;
        procedure a_call_name_static_near(list : TAsmList;const s : string);
        procedure A_Call_Reg(list : TAsmList;reg : TRegister);override;
        procedure a_call_reg_near(list : TAsmList;reg : TRegister);

        procedure A_Op_Const_Reg(list : TAsmList; Op: TOpCG; size: TCgSize; a: TCGInt; reg: TRegister); override;
        procedure A_Op_Const_Ref(list : TAsmList; Op: TOpCG; size: TCgSize; a: TCGInt; const ref: TReference); override;
        procedure A_Op_Reg_Reg(list : TAsmList; Op: TOpCG; size: TCgSize; src, dst: TRegister); override;
        procedure A_Op_Ref_Reg(list : TAsmList; Op: TOpCG; size: TCgSize; const ref: TReference; reg: TRegister); override;
        procedure A_Op_Reg_Ref(list : TAsmList; Op: TOpCG; size: TCgSize;reg: TRegister; const ref: TReference); override;
        procedure A_Op_Ref(list : TAsmList; Op: TOpCG; size: TCgSize; const ref: TReference); override;


        procedure A_Op_Const_Reg_Reg(list : TAsmList; op : TOpCG; size : TCgSize; a : TCGInt; src,dst : TRegister); override;
        procedure A_Op_Reg_Reg_Reg(list : TAsmList; op : TOpCG; size : TCgSize; src1,src2,dst : TRegister); override;


        { move instructions }
        procedure A_Load_Const_Reg(list : TAsmList; tosize: TCgSize; a : TCGInt;reg : TRegister);override;
        procedure A_Load_Const_Ref(list : TAsmList; tosize: TCgSize; a : TCGInt;const ref : TReference);override;
        procedure A_Load_Reg_Ref(list : TAsmList;fromsize,tosize: TCgSize; reg : TRegister;const ref : TReference);override;
        { final as a_load_ref_reg_internal() should be overridden instead }
        procedure A_Load_Ref_Reg(list : TAsmList;fromsize,tosize: TCgSize;const ref : TReference;reg : TRegister);override;final;
        procedure A_Load_Reg_Reg(list : TAsmList;fromsize,tosize: TCgSize;reg1,reg2 : TRegister);override;
        procedure A_LoadAddr_Ref_Reg(list : TAsmList;const ref : TReference;r : TRegister);override;

        { bit scan instructions }
        procedure A_Bit_Scan_Reg_Reg(list: TAsmList; reverse,not_zero: boolean; srcsize, dstsize: TCgSize; src, dst: TRegister); override;

        { fpu move instructions }
        procedure A_LoadFPU_Reg_Reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister); override;
        procedure A_LoadFPU_Ref_Reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; reg: TRegister); override;
        procedure A_LoadFPU_Reg_Ref(list: TAsmList; fromsize, tosize: TCgSize; reg: TRegister; const ref: TReference); override;
        procedure A_LoadFPU_Ref_CGPara(list : TAsmList;size : TCgSize;const ref : TReference;const cgpara : TCGPara); override;

        { vector register move instructions }
        procedure A_LoadMM_Reg_Reg(list: TAsmList; fromsize, tosize : TCgSize;reg1, reg2: TRegister;shuffle : PMMShuffle); override;
        procedure A_LoadMM_Ref_Reg(list: TAsmList; fromsize, tosize : TCgSize;const ref: TReference; reg: TRegister;shuffle : PMMShuffle); override;
        procedure A_LoadMM_Reg_Ref(list: TAsmList; fromsize, tosize : TCgSize;reg: TRegister; const ref: TReference;shuffle : PMMShuffle); override;
        procedure A_OpMM_Ref_Reg(list: TAsmList; Op: TOpCG; size : TCgSize;const ref: TReference; reg: TRegister;shuffle : PMMShuffle); override;
        procedure A_OpMM_Reg_Reg(list: TAsmList; Op: TOpCG; size : TCgSize;src,dst: TRegister;shuffle : PMMShuffle);override;
        procedure A_OpMM_Ref_Reg_Reg(list : TAsmList;Op : TOpCG;size : TCgSize;const ref : TReference;src,dst : TRegister;shuffle : PMMShuffle);override;
        procedure A_OpMM_Reg_Reg_Reg(list : TAsmList;Op : TOpCG;size : TCgSize;src1,src2,dst : TRegister;shuffle : PMMShuffle);override;

        {  comparison operations }
        procedure A_Cmp_Const_Reg_Label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;a : TCGInt;reg : TRegister;
          l : TAsmLabel);override;
        procedure A_Cmp_Const_Ref_Label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;a : TCGInt;const ref : TReference;
          l : TAsmLabel);override;
        procedure A_Cmp_Reg_Reg_Label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;reg1,reg2 : TRegister;l : TAsmLabel); override;
        procedure A_Cmp_Ref_Reg_Label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;const ref: TReference; reg : TRegister; l : TAsmLabel); override;
        procedure A_Cmp_Reg_Ref_Label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;reg : TRegister; const ref: TReference; l : TAsmLabel); override;

        procedure A_Jmp_Name(list : TAsmList;const s : string);override;
        procedure A_Jmp_Always(list : TAsmList;l: TAsmLabel); override;
        procedure A_Jmp_Flags(list : TAsmList;const f : TResFlags;l: TAsmLabel); override;

        procedure G_Flags2Reg(list: TAsmList; size: TCgSize; const f: TResFlags; reg: TRegister); override;
        procedure G_Flags2Ref(list: TAsmList; size: TCgSize; const f: TResFlags; const ref: TReference); override;

        { returns the copy mode g_concatcopy will use depending on the length of the data, however, there is one except when this might be wrong:
          if the references contain a segment override g_concatcopy might use copy_string instead of other copying methods }
        class function getcopymode(len: TCGInt): TCopyMode;
        procedure G_ConcatCopy(list : TAsmList;const source,dest : TReference;len : TCGInt);override;

        { entry/exit code helpers }
        procedure G_StackPointer_Alloc(list : TAsmList;localsize : LongInt);override;
        procedure G_Proc_Entry(list : TAsmList;localsize : LongInt;nostackframe:boolean);override;
        procedure G_Save_Registers(list: TAsmList); override;
        procedure G_Restore_Registers(list: TAsmList); override;

        procedure G_OverflowCheck(list: TAsmList; const l:TLocation;def:TDef);override;

        procedure make_simple_ref(list:TAsmList;var ref: TReference);inline;
        procedure make_direct_ref(list:TAsmList;var ref: TReference);

        function get_darwin_call_stub(const s: string; weak: boolean): TAsmSymbol;

        procedure generate_leave(list : TAsmList);
      protected
        procedure a_load_ref_reg_internal(list : TAsmList;fromsize,tosize: TCgSize;const ref : TReference;reg : TRegister;isdirect:boolean);virtual;

        procedure a_jmp_cond(list : TAsmList;cond : TOpCmp;l: TAsmLabel);
        procedure check_register_size(size:TCgSize;reg:TRegister);

        procedure opmm_loc_reg(list: TAsmList; Op: TOpCG; size : TCgSize;loc : TLocation;dst: TRegister; shuffle : PMMShuffle);
        procedure opmm_loc_reg_reg(list : TAsmList;Op : TOpCG;size : TCgSize;loc : TLocation;src,dst : TRegister;shuffle : PMMShuffle);

        procedure sizes2load(s1,s2 : TCgSize;var op: TAsmOp; var s3: TOpSize);

        procedure floatload(list: TAsmList; t : TCgSize;const ref : TReference);
        procedure floatstore(list: TAsmList; t : TCgSize;const ref : TReference);
        procedure floatloadops(t : TCgSize;var op : TAsmOp;var s : TOpSize);
        procedure floatstoreops(t : TCgSize;var op : TAsmOp;var s : TOpSize);

        procedure internal_restore_regs(list: TAsmList; use_pop: boolean);

        procedure make_simple_ref(list:TAsmList;var ref: TReference;isdirect:boolean);
      end;

   const
{$if defined(x86_64)}
      TCGSize2OpSize: Array[TCgSize] of TOpSize =
        (S_NO,S_B,S_W,S_L,S_Q,S_XMM,S_B,S_W,S_L,S_Q,S_XMM,
         S_FS,S_FL,S_FX,S_IQ,S_FXX,
         S_NO,S_NO,S_NO,S_MD,S_XMM,S_YMM,S_ZMM);
{$elseif defined(i386)}
      TCGSize2OpSize: Array[TCgSize] of TOpSize =
        (S_NO,S_B,S_W,S_L,S_L,S_T,S_B,S_W,S_L,S_L,S_L,
         S_FS,S_FL,S_FX,S_IQ,S_FXX,
         S_NO,S_NO,S_NO,S_MD,S_XMM,S_YMM,S_ZMM);
{$endif}

{$ifndef NOTARGETWIN}
      winstackpagesize = 4096;
{$endif NOTARGETWIN}

    function UseIncDec: boolean;

    { returns true, if the compiler should use leave instead of mov/pop }
    function UseLeave: boolean;

    { Gets the byte alignment of a reference }
    function GetRefAlignment(ref: TReference): Byte; {$IFDEF USEINLINE}inline;{$ENDIF}

  implementation

    uses
       Globals,Verbose,Systems,CUtils,
       symcpu,
       paramgr,ProcInfo,
       tgobj,ncgutil;

    { modern CPUs prefer add/sub over inc/dec because add/sub break instructions dependencies on flags
      because they modify all flags }
    function UseIncDec: boolean;
      begin
{$if defined(x86_64)}
        Result:=cs_opt_size in CurrentSettings.OptimizerSwitches;
{$elseif defined(i386)}
        Result:=(cs_opt_size in CurrentSettings.OptimizerSwitches) or (CurrentSettings.CPUType in [cpu_386]);
{$endif}
      end;


    function UseLeave: boolean;
      begin
{$if defined(x86_64)}
        { Modern processors should be happy with mov;pop, maybe except older AMDs }
        Result:=cs_opt_size in CurrentSettings.OptimizerSwitches;
{$elseif defined(i386)}
        Result:=(cs_opt_size in CurrentSettings.OptimizerSwitches) or (CurrentSettings.OptimizeCPUType<cpu_Pentium2);
{$endif}
      end;

    function GetRefAlignment(ref: TReference): Byte; {$IFDEF USEINLINE}inline;{$ENDIF}
      begin
{$ifdef x86_64}
        { The stack pointer and base pointer will be aligned to 16-byte boundaries if the machine code is well-behaved }
        if (ref.Base = NR_STACK_POINTER_REG) or (ref.Base = CurrentProcInfo.framepointer) then
          begin
            if (ref.Index = NR_NO) and ((ref.Offset mod TargetInfo.stackalign) = 0) then
              Result := TargetInfo.stackalign
            else
              Result := ref.Alignment;
          end
        else
{$endif x86_64}
          Result := ref.Alignment;
      end;

    const
      TOpCG2AsmOp: Array[TOpCG] of TAsmOp = (A_NONE,A_MOV,A_ADD,A_AND,A_DIV,
                            A_IDIV,A_IMUL,A_MUL,A_NEG,A_NOT,A_OR,
                            A_SAR,A_SHL,A_SHR,A_SUB,A_XOR,A_ROL,A_ROR);

      TOpCmp2AsmCond: Array[TOpCmp] of TAsmCond = (C_NONE,
          C_E,C_G,C_L,C_GE,C_LE,C_NE,C_BE,C_B,C_AE,C_A);

    procedure TCGX86.Done_Register_Allocators;
      begin
        rg[R_INTREGISTER].free;
        rg[R_MMREGISTER].free;
        rg[R_MMXREGISTER].free;
        rgfpu.free;
        inherited Done_Register_Allocators;
      end;


    function TCGX86.GetFPURegister(list:TAsmList;size:TCgSize):TRegister;
      begin
        result:=rgfpu.GetRegisterFPU(list);
      end;


    function TCGX86.GetMMXRegister(list:TAsmList):TRegister;
      begin
        if not Assigned(rg[R_MMXREGISTER]) then
          InternalError(2003121204);
        result:=rg[R_MMXREGISTER].GetRegister(list,R_SUBNONE);
      end;


    function TCGX86.GetMMRegister(list:TAsmList;size:TCgSize):TRegister;
      begin
        if not Assigned(rg[R_MMREGISTER]) then
          InternalError(2003121234);
        case size of
          OS_F64:
            result:=rg[R_MMREGISTER].GetRegister(list,R_SUBMMD);
          OS_F32:
            result:=rg[R_MMREGISTER].GetRegister(list,R_SUBMMS);
          OS_M64:
            result:=rg[R_MMREGISTER].GetRegister(list,R_SUBQ);
          OS_128,
          OS_M128,
          OS_F128:
            result:=rg[R_MMREGISTER].GetRegister(list,R_SUBMMX); { R_SUBMMWHOLE seems a bit dangerous and ambiguous, so changed to R_SUBMMX. [Kit] }
          OS_M256:
            result:=rg[R_MMREGISTER].GetRegister(list,R_SUBMMY);
          OS_M512:
            result:=rg[R_MMREGISTER].GetRegister(list,R_SUBMMZ);
          else
            InternalError(200506041);
        end;
      end;


    procedure TCGX86.GetCPURegister(list:TAsmList;r:TRegister);
      begin
        if GetRegType(r)=R_FPUREGISTER then
          InternalError(2003121210)
        else
          inherited GetCPURegister(list,r);
      end;


    procedure TCGX86.UngetCPURegister(list:TAsmList;r:TRegister);
      begin
        if GetRegType(r)=R_FPUREGISTER then
          rgfpu.UngetRegisterFPU(list,r)
        else
          inherited UngetCPURegister(list,r);
      end;


    procedure TCGX86.AllocCPURegisters(list:TAsmList;rt:TRegisterType;const r:TCPURegisterSet);
      begin
        if rt<>R_FPUREGISTER then
          inherited AllocCPURegisters(list,rt,r);
      end;


    procedure TCGX86.DeallocCPURegisters(list:TAsmList;rt:TRegisterType;const r:TCPURegisterSet);
      begin
        if rt<>R_FPUREGISTER then
          inherited DeallocCPURegisters(list,rt,r);
      end;


    function  TCGX86.Uses_Registers(rt:TRegisterType):boolean;
      begin
        if rt=R_FPUREGISTER then
          result:=false
        else
          result:=inherited Uses_Registers(rt);
      end;


    procedure TCGX86.Add_Reg_Instruction(instr:TAI;r:TRegister);
      begin
        if GetRegType(r)<>R_FPUREGISTER then
          inherited Add_Reg_Instruction(instr,r);
      end;


    procedure TCGX86.dec_fpu_stack;
      begin
        if rgfpu.FPUVarOffset<=0 then
          InternalError(200604201);
        dec(rgfpu.FPUVarOffset);
      end;


    procedure TCGX86.inc_fpu_stack;
      begin
        if rgfpu.FPUVarOffset>=7 then
          InternalError(2012062901);
        inc(rgfpu.FPUVarOffset);
      end;


{ Range check must be disabled explicitly as the code serves
  on three different architecture sizes }
{$R-}

{****************************************************************************
                       This is private property, keep out! :)
****************************************************************************}

    procedure TCGX86.sizes2load(s1,s2 : TCgSize; var op: TAsmOp; var s3: TOpSize);

       begin
         { ensure to have always valid sizes }
         if s1=OS_NO then
           s1:=s2;
         if s2=OS_NO then
           s2:=s1;
         case s2 of
           OS_8,OS_S8 :
             if S1 in [OS_8,OS_S8] then
               s3 := S_B
             else
               InternalError(200109221);
           OS_16,OS_S16:
             case s1 of
               OS_8,OS_S8:
                 s3 := S_BW;
               OS_16,OS_S16:
                 s3 := S_W;
               else
                 InternalError(200109222);
             end;
           OS_32,OS_S32:
             case s1 of
               OS_8,OS_S8:
                 s3 := S_BL;
               OS_16,OS_S16:
                 s3 := S_WL;
               OS_32,OS_S32:
                 s3 := S_L;
               else
                 InternalError(200109223);
             end;
{$ifdef x86_64}
           OS_64,OS_S64:
             case s1 of
               OS_8:
                 s3 := S_BL;
               OS_S8:
                 s3 := S_BQ;
               OS_16:
                 s3 := S_WL;
               OS_S16:
                 s3 := S_WQ;
               OS_32:
                 s3 := S_L;
               OS_S32:
                 s3 := S_LQ;
               OS_64,OS_S64:
                 s3 := S_Q;
               else
                 InternalError(200304302);
             end;
{$endif x86_64}
           else
             InternalError(200109227);
         end;
         if s3 in [S_B,S_W,S_L,S_Q] then
           op := A_MOV
         else if s1 in [OS_8,OS_16,OS_32,OS_64] then
           op := A_MOVZX
         else
{$ifdef x86_64}
           if s3 in [S_LQ] then
             op := A_MOVSXD
         else
{$endif x86_64}
           op := A_MOVSX;
       end;


    procedure TCGX86.make_simple_ref(list:TAsmList;var ref: TReference);
      begin
        make_simple_ref(list,ref,false);
      end;


    procedure TCGX86.make_simple_ref(list:TAsmList;var ref: TReference;isdirect:boolean);
      var

        hreg : TRegister;

        href : TReference;
{$ifdef i386}
        add_hreg: boolean;
{$endif i386}
      begin

        hreg:=NR_NO;

        { make_simple_ref() may have already been called earlier, and in that
          case make sure we don't perform the PIC-simplifications twice }
        if (ref.RefAddr in [addr_pic,addr_pic_no_got]) then
          exit;

        { handle indirect symbols first }
        if not isdirect then
            make_direct_ref(list,ref);

{$if defined(x86_64)}
        { Only 32bit is allowed }
        { Note that this isn't entirely correct: for RIP-relative targets/memory models,
          it is actually (offset+@symbol-RIP) that should fit into 32 bits. Since two last
          members aren't known until link time, ABIs place very pessimistic limits
          on offset values, e.g. SysV AMD64 allows +/-$1000000 (16 megabytes) }
        if ((ref.Offset<low(LongInt)) or (ref.Offset>high(LongInt))) or
           ((cs_large in CurrentSettings.GlobalSwitches) and Assigned(ref.Symbol)) or
           { absolute address is not a common thing in x64, but nevertheless a possible one }
           ((ref.Base=NR_NO) and (ref.Index=NR_NO) and (ref.Symbol=nil)) then
          begin
            { Load constant value to register }
            hreg:=GetAddressRegister(list);
            if (cs_large in CurrentSettings.GlobalSwitches) and Assigned(ref.Symbol) then
              begin
                list.concat(TAICPU.op_sym_ofs_reg(A_MOVABS,S_Q,ref.Symbol,ref.Offset+10,hreg));
                ref.Symbol:=nil;
              end
            else
              list.concat(TAICPU.op_const_reg(A_MOV,S_Q,ref.Offset,hreg));
            ref.Offset:=0;
            {if assigned(ref.symbol) then
              begin
                list.concat(taicpu.op_sym_ofs_reg(A_ADD,S_Q,ref.symbol,0,hreg));
                ref.symbol:=nil;
              end;}
            { Add register to reference }
            if ref.Base=NR_NO then
              ref.Base:=hreg
            else if ref.Index=NR_NO then
              ref.Index:=hreg
            else
              begin
                { don't use add, as the flags may contain a value }
                Reference_Reset_Base(href,hreg,0,ref.TempPos,ref.Alignment,[]);
                href.Index:=ref.Index;
                href.ScaleFactor:=ref.ScaleFactor;
                list.concat(TAICPU.op_ref_reg(A_LEA,S_Q,href,hreg));
                ref.Index:=hreg;
                ref.ScaleFactor:=1;
               end;
          end;

        if Assigned(ref.Symbol) then
          begin
            if cs_create_pic in CurrentSettings.ModuleSwitches then
              begin
                { Local symbols must not be accessed via the GOT }
                if (ref.Symbol.bind=AB_LOCAL) then
                  begin
                    { unfortunately, RIP-based addresses don't support an index }
                    if (ref.Base<>NR_NO) or
                       (ref.Index<>NR_NO) then
                      begin
                        Reference_Reset_Symbol(href,ref.Symbol,0,ref.Alignment,[]);
                        hreg:=GetAddressRegister(list);
                        href.RefAddr:=addr_pic_no_got;
                        href.Base:=NR_RIP;
                        list.concat(TAICPU.op_ref_reg(A_LEA,S_Q,href,hreg));
                        ref.Symbol:=nil;
                      end
                    else
                      begin
                        ref.RefAddr:=addr_pic_no_got;
                        hreg:=NR_NO;
                        ref.Base:=NR_RIP;
                      end;
                  end
                else
                  begin
                    Reference_Reset_Symbol(href,ref.Symbol,0,ref.Alignment,[]);
                    hreg:=GetAddressRegister(list);
                    href.RefAddr:=addr_pic;
                    href.Base:=NR_RIP;
                    list.concat(TAICPU.op_ref_reg(A_MOV,S_Q,href,hreg));
                    ref.Symbol:=nil;
                  end;

                if ref.Base=NR_NO then
                  ref.Base:=hreg
                else if ref.Index=NR_NO then
                  begin
                    ref.Index:=hreg;
                    ref.ScaleFactor:=1;
                  end
                else
                  begin
                    { don't use add, as the flags may contain a value }
                    Reference_Reset_Base(href,ref.Base,0,ref.TempPos,ref.Alignment,[]);
                    href.Index:=hreg;
                    ref.Base:=GetAddressRegister(list);
                    list.concat(TAICPU.op_ref_reg(A_LEA,S_Q,href,ref.Base));
                  end;
              end
            else
              { Always use RIP relative symbol addressing for Windows and Darwin targets. }
              if (TargetInfo.system in (systems_all_windows+[system_x86_64_darwin,system_x86_64_iphonesim])) and (ref.Base<>NR_RIP) then
                begin
                  if (ref.RefAddr=addr_no) and (ref.Base=NR_NO) and (ref.Index=NR_NO) then
                    begin
                      { Set RIP relative addressing for simple symbol references }
                      ref.Base:=NR_RIP;
                      ref.RefAddr:=addr_pic_no_got
                    end
                  else
                    begin
                      { Use temp register to load calculated 64-bit symbol address for complex references }
                      Reference_Reset_Symbol(href,ref.Symbol,0,sizeof(PInt),[]);
                      href.Base:=NR_RIP;
                      href.RefAddr:=addr_pic_no_got;
                      hreg:=GetAddressRegister(list);
                      list.concat(TAICPU.op_ref_reg(A_LEA,S_Q,href,hreg));
                      ref.Symbol:=nil;
                      if ref.Base=NR_NO then
                        ref.Base:=hreg
                      else if ref.Index=NR_NO then
                        begin
                          ref.Index:=hreg;
                          ref.ScaleFactor:=0;
                        end
                      else
                        begin
                          { don't use add, as the flags may contain a value }
                          Reference_Reset_Base(href,ref.Base,0,ref.TempPos,ref.Alignment,[]);
                          href.Index:=hreg;
                          ref.Base:=GetAddressRegister(list);
                          list.concat(TAICPU.op_ref_reg(A_LEA,S_Q,href,ref.Base));
                        end;
                    end;

                end;
          end;
{$elseif defined(i386)}
        add_hreg:=false;
        if (TargetInfo.system in [system_i386_darwin,system_i386_iphonesim]) then
          begin
            if Assigned(ref.Symbol) and
               not(Assigned(ref.RelSymbol)) and
               ((ref.Symbol.bind in [AB_EXTERNAL,AB_WEAK_EXTERNAL,AB_PRIVATE_EXTERN]) or
                (cs_create_pic in CurrentSettings.ModuleSwitches)) then
             begin
               if ref.Symbol.bind in [AB_EXTERNAL,AB_WEAK_EXTERNAL,AB_PRIVATE_EXTERN] then
                 begin
                   hreg:=G_Indirect_Sym_Load(list,ref.Symbol.name,asmsym2indsymflags(ref.Symbol));
                   ref.Symbol:=nil;
                 end
               else
                 begin
                   include(CurrentProcInfo.flags,pi_needs_got);
                   { make a copy of the got register, hreg can get modified }
                   hreg:=GetAddressRegister(list);
                   A_Load_Reg_Reg(list,OS_ADDR,OS_ADDR,CurrentProcInfo.got,hreg);
                   ref.RelSymbol:=CurrentProcInfo.CurrGOTLabel;
                 end;
               add_hreg:=true
             end
          end
        else if (cs_create_pic in CurrentSettings.ModuleSwitches) and
           Assigned(ref.Symbol) then
          begin
            Reference_Reset_Symbol(href,ref.Symbol,0,sizeof(PInt),[]);
            href.Base:=CurrentProcInfo.got;
            href.RefAddr:=addr_pic;
            include(CurrentProcInfo.flags,pi_needs_got);
            hreg:=GetAddressRegister(list);
            list.concat(TAICPU.op_ref_reg(A_MOV,S_L,href,hreg));
            ref.Symbol:=nil;
            add_hreg:=true;
          end;

        if add_hreg then
          begin
            if ref.Base=NR_NO then
              ref.Base:=hreg
            else if ref.Index=NR_NO then
              begin
                ref.Index:=hreg;
                ref.ScaleFactor:=1;
              end
            else
              begin
                { don't use add, as the flags may contain a value }
                Reference_Reset_Base(href,ref.Base,0,ref.TempPos,ref.Alignment,[]);
                href.Index:=hreg;
                list.concat(TAICPU.op_ref_reg(A_LEA,S_L,href,hreg));
                ref.Base:=hreg;
              end;
          end;
{$endif}
      end;


    procedure TCGX86.make_direct_ref(list:TAsmList;var ref:TReference);
      var
        href : TReference;
        hreg : TRegister;
      begin
        if Assigned(ref.Symbol) and (ref.Symbol.bind in asmsymbindindirect) then
          begin
            { load the symbol into a register }
            hreg:=GetAddressRegister(list);
            Reference_Reset_Symbol(href,ref.Symbol,0,sizeof(PInt),[]);
            { tell make_simple_ref that we are loading the symbol address via an indirect
              symbol and that hence it should not call make_direct_ref() again }
            a_load_ref_reg_internal(list,OS_ADDR,OS_ADDR,href,hreg,true);
            if ref.Base<>NR_NO then
              begin
                { fold symbol register into base register }
                Reference_Reset_Base(href,hreg,0,CTempPosInvalid,ref.Alignment,[]);
                href.Index:=ref.Base;
                hreg:=GetAddressRegister(list);
                A_LoadAddr_Ref_Reg(list,href,hreg);
              end;
            { we're done }
            ref.Symbol:=nil;
            ref.Base:=hreg;
          end;
      end;


    procedure TCGX86.floatloadops(t : TCgSize;var op : TAsmOp;var s : TOpSize);
      begin
         case t of
            OS_F32 :
              begin
                 op:=A_FLD;
                 s:=S_FS;
              end;
            OS_F64 :
              begin
                 op:=A_FLD;
                 s:=S_FL;
              end;
            OS_F80 :
              begin
                 op:=A_FLD;
                 s:=S_FX;
              end;
            OS_C64 :
              begin
                 op:=A_FILD;
                 s:=S_IQ;
              end;
            else
              InternalError(200204043);
         end;
      end;


    procedure TCGX86.floatload(list: TAsmList; t : TCgSize;const ref : TReference);

      var
         op : TAsmOp;
         s : TOpSize;
         tmpref : TReference;
      begin
         tmpref:=ref;
         make_simple_ref(list,tmpref);
         floatloadops(t,op,s);
         list.concat(TAICPU.Op_ref(op,s,tmpref));
         inc_fpu_stack;
      end;


    procedure TCGX86.floatstoreops(t : TCgSize;var op : TAsmOp;var s : TOpSize);

      begin
         case t of
            OS_F32 :
              begin
                 op:=A_FSTP;
                 s:=S_FS;
              end;
            OS_F64 :
              begin
                 op:=A_FSTP;
                 s:=S_FL;
              end;
            OS_F80 :
              begin
                  op:=A_FSTP;
                  s:=S_FX;
               end;
            OS_C64 :
               begin
                  op:=A_FISTP;
                  s:=S_IQ;
               end;
            else
               InternalError(200204042);
         end;
      end;


    procedure TCGX86.floatstore(list: TAsmList; t : TCgSize;const ref : TReference);

      var
         op : TAsmOp;
         s : TOpSize;
         tmpref : TReference;
      begin
         tmpref:=ref;
         make_simple_ref(list,tmpref);
         floatstoreops(t,op,s);
         list.concat(TAICPU.Op_ref(op,s,tmpref));
         { storing non extended floats can cause a floating point overflow }
         if ((t<>OS_F80) and (cs_fpu_fwait in CurrentSettings.LocalSwitches))

           then
           list.concat(TAICPU.Op_none(A_FWAIT,S_NO));
         dec_fpu_stack;
      end;


    procedure TCGX86.check_register_size(size:TCgSize;reg:TRegister);
      begin
        if TCGSize2OpSize[size]<>TCGSize2OpSize[reg_cgsize(reg)] then
          InternalError(200306031);
      end;


{****************************************************************************
                              Assembler code
****************************************************************************}

    procedure TCGX86.A_Jmp_Name(list : TAsmList;const s : string);
      var
        r: TReference;
      begin
        if (TargetInfo.system <> system_i386_darwin) then
          list.concat(TAICPU.op_sym(A_JMP,S_NO,CurrentAsmData.RefAsmSymbol(s,AT_FUNCTION)))
        else
          begin
            Reference_Reset_Symbol(r,get_darwin_call_stub(s,false),0,sizeof(PInt),[]);
            r.RefAddr:=addr_full;
            list.concat(TAICPU.op_ref(A_JMP,S_NO,r));
          end;
      end;


    procedure TCGX86.A_Jmp_Always(list : TAsmList;l: TAsmLabel);
      begin
        a_jmp_cond(list, OC_NONE, l);
      end;


    function TCGX86.get_darwin_call_stub(const s: string; weak: boolean): TAsmSymbol;
      var
        stubname: string;
      begin
        stubname := 'L'+s+'$stub';
        result := CurrentAsmData.GetAsmSymbol(stubname);
        if Assigned(result) then
          exit;

        if CurrentAsmData.asmlists[al_imports]=nil then
          CurrentAsmData.asmlists[al_imports]:=TAsmList.create;

        new_section(CurrentAsmData.asmlists[al_imports],sec_stub,'',0);
        result := CurrentAsmData.DefineAsmSymbol(stubname,AB_LOCAL,AT_FUNCTION,VoidCodePointerType);
        CurrentAsmData.asmlists[al_imports].concat(TAISymbol.Create(result,0));
        { register as a weak symbol if necessary }
        if weak then
          CurrentAsmData.weakrefasmsymbol(s,AT_FUNCTION);
        CurrentAsmData.asmlists[al_imports].concat(TAIDirective.create(asd_indirect_symbol,s));
        CurrentAsmData.asmlists[al_imports].concat(TAICPU.op_none(A_HLT));
        CurrentAsmData.asmlists[al_imports].concat(TAICPU.op_none(A_HLT));
        CurrentAsmData.asmlists[al_imports].concat(TAICPU.op_none(A_HLT));
        CurrentAsmData.asmlists[al_imports].concat(TAICPU.op_none(A_HLT));
        CurrentAsmData.asmlists[al_imports].concat(TAICPU.op_none(A_HLT));
      end;


    procedure TCGX86.A_Call_Name(list : TAsmList;const s : string; weak: boolean);
      begin
        a_call_name_near(list,s,weak);
      end;


    procedure TCGX86.a_call_name_near(list : TAsmList;const s : string; weak: boolean);
      var
        sym : TAsmSymbol;
        r : TReference;
      begin

        if (TargetInfo.system <> system_i386_darwin) then
          begin
            if not(weak) then
              sym:=CurrentAsmData.RefAsmSymbol(s,AT_FUNCTION)
            else
              sym:=CurrentAsmData.WeakRefAsmSymbol(s,AT_FUNCTION);
            Reference_Reset_Symbol(r,sym,0,sizeof(PInt),[]);
            if (cs_create_pic in CurrentSettings.ModuleSwitches) and
               { darwin's assembler doesn't want @PLT after call symbols }
               not(TargetInfo.system in [system_x86_64_darwin,system_i386_iphonesim,system_x86_64_iphonesim]) then
              begin
                r.RefAddr:=addr_pic;
              end
            else
              r.RefAddr:=addr_full;
          end
        else
          begin
            Reference_Reset_Symbol(r,get_darwin_call_stub(s,weak),0,sizeof(PInt),[]);
            r.RefAddr:=addr_full;
          end;
        list.concat(TAICPU.op_ref(A_CALL,S_NO,r));
      end;


    procedure TCGX86.A_Call_Name_Static(list : TAsmList;const s : string);
      begin
        a_call_name_static_near(list,s);
      end;


    procedure TCGX86.a_call_name_static_near(list : TAsmList;const s : string);
      var
        sym : TAsmSymbol;
        r : TReference;
      begin
        sym:=CurrentAsmData.RefAsmSymbol(s,AT_FUNCTION);
        Reference_Reset_Symbol(r,sym,0,sizeof(PInt),[]);
        r.RefAddr:=addr_full;
        list.concat(TAICPU.op_ref(A_CALL,S_NO,r));
      end;


    procedure TCGX86.A_Call_Reg(list : TAsmList;reg : TRegister);
      begin
        a_call_reg_near(list,reg);
      end;


    procedure TCGX86.a_call_reg_near(list: TAsmList; reg: TRegister);
      begin
        list.concat(TAICPU.op_reg(A_CALL,S_NO,reg));
      end;


{********************** load instructions ********************}

    procedure TCGX86.A_Load_Const_Reg(list : TAsmList; tosize: TCgSize; a : TCGInt; reg : TRegister);

      begin
        check_register_size(tosize,reg);
        { the optimizer will change it to "xor reg,reg" when loading zero, }
        { no need to do it here too (JM)                                   }
        list.concat(TAICPU.op_const_reg(A_MOV,TCGSize2OpSize[tosize],a,reg))
      end;


    procedure TCGX86.A_Load_Const_Ref(list : TAsmList; tosize: TCgSize; a : TCGInt;const ref : TReference);
      var
        tmpref : TReference;
        tmpreg: TRegister;
      begin
        tmpref:=ref;
        make_simple_ref(list,tmpref);
{$ifdef x86_64}
        { x86_64 only supports signed 32 bits constants directly }
        if (tosize in [OS_S64,OS_64]) and
           ((a<low(LongInt)) or (a>high(LongInt))) then
          begin
            tmpreg:=GetIntRegister(list,tosize);
            A_Load_Const_Reg(list,tosize,a,tmpreg);
            A_Load_Reg_Ref(list,tosize,tosize,tmpreg,tmpref);
          end
        else
{$endif x86_64}
          list.concat(TAICPU.op_const_ref(A_MOV,TCGSize2OpSize[tosize],a,tmpref));
      end;


    procedure TCGX86.A_Load_Reg_Ref(list : TAsmList; fromsize,tosize: TCgSize; reg : TRegister;const ref : TReference);
      var
        op: TAsmOp;
        s: TOpSize;
        tmpsize : TCgSize;
        tmpreg  : TRegister;
        tmpref  : TReference;
      begin
        tmpref:=ref;
        make_simple_ref(list,tmpref);
        if TCgSize2Size[fromsize]>TCgSize2Size[tosize] then
          begin
            fromsize:=tosize;
            reg:=MakeRegSize(list,reg,fromsize);
          end;
        check_register_size(fromsize,reg);
        sizes2load(fromsize,tosize,op,s);
        case s of
{$ifdef x86_64}
          S_BQ,S_WQ,S_LQ,
{$endif x86_64}
          S_BW,S_BL,S_WL :
            begin
              tmpreg:=GetIntRegister(list,tosize);
{$ifdef x86_64}
              { zero extensions to 64 bit on the x86_64 are simply done by writting to the lower 32 bit
                which clears the upper 64 bit too, so it could be that s is S_L while the reg is
                64 bit (FK) }
              if s in [S_BL,S_WL,S_L] then
                begin
                  tmpreg:=MakeRegSize(list,tmpreg,OS_32);
                  tmpsize:=OS_32;
                end
              else
{$endif x86_64}
                tmpsize:=tosize;
              list.concat(TAICPU.op_reg_reg(op,s,reg,tmpreg));
              A_Load_Reg_Ref(list,tmpsize,tosize,tmpreg,tmpref);
            end;
        else
          list.concat(TAICPU.op_reg_ref(op,s,reg,tmpref));
        end;
      end;


    procedure TCGX86.A_Load_Ref_Reg(list : TAsmList;fromsize,tosize : TCgSize;const ref: TReference;reg : TRegister);
      begin
        a_load_ref_reg_internal(list,fromsize,tosize,ref,reg,false);
      end;


    procedure TCGX86.a_load_ref_reg_internal(list : TAsmList;fromsize,tosize : TCgSize;const ref: TReference;reg : TRegister;isdirect:boolean);
      var
        op: TAsmOp;
        s: TOpSize;
        tmpref  : TReference;
      begin
        tmpref:=ref;
        make_simple_ref(list,tmpref,isdirect);
        check_register_size(tosize,reg);
        sizes2load(fromsize,tosize,op,s);
 {$ifdef x86_64}
        { zero extensions to 64 bit on the x86_64 are simply done by writting to the lower 32 bit
          which clears the upper 64 bit too, so it could be that s is S_L while the reg is
          64 bit (FK) }
        if s in [S_BL,S_WL,S_L] then
          reg:=MakeRegSize(list,reg,OS_32);
{$endif x86_64}
        list.concat(TAICPU.op_ref_reg(op,s,tmpref,reg));
      end;


    procedure TCGX86.A_Load_Reg_Reg(list : TAsmList;fromsize,tosize : TCgSize;reg1,reg2 : TRegister);
      var
        op: TAsmOp;
        s: TOpSize;
        instr:TAICPU;
      begin
        check_register_size(fromsize,reg1);
        check_register_size(tosize,reg2);
        if TCgSize2Size[fromsize]>TCgSize2Size[tosize] then
          begin
            reg1:=MakeRegSize(list,reg1,tosize);
            s:=tcgsize2opsize[tosize];
            op:=A_MOV;
          end
        else
          sizes2load(fromsize,tosize,op,s);
{$ifdef x86_64}
        { zero extensions to 64 bit on the x86_64 are simply done by writting to the lower 32 bit
          which clears the upper 64 bit too, so it could be that s is S_L while the reg is
          64 bit (FK)
        }
        if s in [S_BL,S_WL,S_L] then
          reg2:=MakeRegSize(list,reg2,OS_32);
{$endif x86_64}
        if (reg1<>reg2) then
          begin
            instr:=TAICPU.op_reg_reg(op,s,reg1,reg2);
            { Notify the register allocator that we have written a move instruction so
              it can try to eliminate it. }
            if (reg1<>CurrentProcInfo.framepointer) and (reg1<>NR_STACK_POINTER_REG) then
              Add_Move_Instruction(instr);
            list.concat(instr);
          end;
{$ifdef x86_64}
        { avoid merging of registers and killing the zero extensions (FK) }
        if (tosize in [OS_64,OS_S64]) and (s=S_L) then
          list.concat(TAICPU.op_const_reg(A_AND,S_L,$ffffffff,reg2));
{$endif x86_64}
      end;


    procedure TCGX86.A_LoadAddr_Ref_Reg(list : TAsmList;const ref : TReference;r : TRegister);
      var
        dirref,tmpref : TReference;

        tmpreg : TRegister;

      begin
        dirref:=ref;

        { this could probably done in a more optimized way, but for now this
          is sufficient }
        make_direct_ref(list,dirref);

        with dirref do
          begin
{$ifdef i386}
            if RefAddr=addr_ntpoff then
              begin
                { Convert thread local address to a process global address
                  as we cannot handle far pointers.}
                case TargetInfo.system of
                  system_i386_linux,system_i386_android:
                    if segment=NR_GS then
                      begin
                        Reference_Reset(tmpref,1,[]);
                        tmpref.Segment:=NR_GS;
                        tmpreg:=GetAddressRegister(list);
                        A_Load_Ref_Reg(list,OS_ADDR,OS_ADDR,tmpref,tmpreg);
                        Reference_Reset(tmpref,1,[]);
                        tmpref.Symbol:=symbol;
                        tmpref.RefAddr:=RefAddr;
                        tmpref.Base:=tmpreg;
                        if base<>NR_NO then
                          tmpref.Index:=base;
                        list.concat(TAICPU.op_ref_reg(A_LEA,tcgsize2opsize[OS_ADDR],tmpref,tmpreg));
                        segment:=NR_NO;
                        base:=tmpreg;
                        symbol:=nil;
                        RefAddr:=addr_no;
                      end
                    else
                      InternalError(2018110402);
                  else
                    InternalError(2018110403);
                end;
              end;
{$endif i386}
{$ifdef x86_64}
            if RefAddr=addr_tpoff then
              begin
                { Convert thread local address to a process global address
                  as we cannot handle far pointers.}
                case TargetInfo.system of
                  system_x86_64_linux:
                    if segment=NR_FS then
                      begin
                        Reference_Reset(tmpref,1,[]);
                        tmpref.Segment:=NR_FS;
                        tmpreg:=GetAddressRegister(list);
                        A_Load_Ref_Reg(list,OS_ADDR,OS_ADDR,tmpref,tmpreg);
                        Reference_Reset(tmpref,1,[]);
                        tmpref.Symbol:=symbol;
                        tmpref.RefAddr:=RefAddr;
                        tmpref.Base:=tmpreg;
                        if base<>NR_NO then
                          tmpref.Index:=base;
                        list.concat(TAICPU.op_ref_reg(A_LEA,tcgsize2opsize[OS_ADDR],tmpref,tmpreg));
                        segment:=NR_NO;
                        base:=tmpreg;
                        symbol:=nil;
                        RefAddr:=addr_no;
                      end
                    else
                      InternalError(2019012003);
                  else
                    InternalError(2019012004);
                end;
              end;
{$endif x86_64}
            if (base=NR_NO) and (index=NR_NO) then
              begin
                if Assigned(dirref.Symbol) then
                  begin
                    if (TargetInfo.system in [system_i386_darwin,system_i386_iphonesim]) and
                       ((dirref.Symbol.bind in [AB_EXTERNAL,AB_WEAK_EXTERNAL]) or
                        (cs_create_pic in CurrentSettings.ModuleSwitches)) then
                      begin
                        if (dirref.Symbol.bind in [AB_EXTERNAL,AB_WEAK_EXTERNAL]) or
                           ((cs_create_pic in CurrentSettings.ModuleSwitches) and
                            (dirref.Symbol.bind in [AB_COMMON,AB_GLOBAL,AB_PRIVATE_EXTERN])) then
                          begin
                             Reference_Reset_Base(tmpref,
                               G_Indirect_Sym_Load(list,dirref.Symbol.name,asmsym2indsymflags(dirref.Symbol)),
                               offset,CTempPosInvalid,sizeof(PInt),[]);
                             A_LoadAddr_Ref_Reg(list,tmpref,r);
                          end
                       else
                         begin
                           include(CurrentProcInfo.flags,pi_needs_got);
                           Reference_Reset_Base(tmpref,CurrentProcInfo.got,offset,dirref.TempPos,dirref.Alignment,[]);
                           tmpref.Symbol:=symbol;
                           tmpref.RelSymbol:=CurrentProcInfo.CurrGOTLabel;
                           list.concat(TAICPU.op_ref_reg(A_LEA,tcgsize2opsize[OS_ADDR],tmpref,r));
                         end;
                      end
                    else if (cs_create_pic in CurrentSettings.ModuleSwitches)
{$ifdef x86_64}
                             and not(dirref.Symbol.bind=AB_LOCAL)
{$endif x86_64}
                            then
                      begin
{$ifdef x86_64}
                        Reference_Reset_Symbol(tmpref,dirref.Symbol,0,sizeof(PInt),[]);
                        tmpref.RefAddr:=addr_pic;
                        tmpref.Base:=NR_RIP;
                        list.concat(TAICPU.op_ref_reg(A_MOV,S_Q,tmpref,r));
{$else x86_64}
                        Reference_Reset_Symbol(tmpref,dirref.Symbol,0,sizeof(PInt),[]);
                        tmpref.RefAddr:=addr_pic;
                        tmpref.Base:=CurrentProcInfo.got;
                        include(CurrentProcInfo.flags,pi_needs_got);
                        list.concat(TAICPU.op_ref_reg(A_MOV,S_L,tmpref,r));
{$endif x86_64}
                        if offset<>0 then
                          A_Op_Const_Reg(list,OP_ADD,OS_ADDR,offset,r);
                      end
{$ifdef x86_64}
                    else if (TargetInfo.system in (systems_all_windows+[system_x86_64_darwin,system_x86_64_iphonesim]))
			 or (cs_create_pic in CurrentSettings.ModuleSwitches)
			 then
                      begin
                        { Win64 and Darwin/x86_64 always require RIP-relative addressing }
                        tmpref:=dirref;
                        tmpref.Base:=NR_RIP;
                        tmpref.RefAddr:=addr_pic_no_got;
                        list.concat(TAICPU.op_ref_reg(A_LEA,S_Q,tmpref,r));
                      end
{$endif x86_64}
                    else
                      begin
                        tmpref:=dirref;
                        tmpref.RefAddr:=ADDR_FULL;
                        list.concat(TAICPU.op_ref_reg(A_MOV,tcgsize2opsize[OS_ADDR],tmpref,r));
                      end
                  end
                else
                  A_Load_Const_Reg(list,OS_ADDR,offset,r)
              end
            else if (base=NR_NO) and (index<>NR_NO) and
                    (offset=0) and (ScaleFactor=0) and (symbol=nil) then
              A_Load_Reg_Reg(list,OS_ADDR,OS_ADDR,index,r)
            else if (base<>NR_NO) and (index=NR_NO) and
                    (offset=0) and (symbol=nil) then
                A_Load_Reg_Reg(list,OS_ADDR,OS_ADDR,base,r)
            else
              begin
                tmpref:=dirref;
                make_simple_ref(list,tmpref);
                list.concat(TAICPU.op_ref_reg(A_LEA,tcgsize2opsize[OS_ADDR],tmpref,r));
              end;
            if segment<>NR_NO then
              begin

                CGMessage(cg_e_cant_use_far_pointer_there);

              end;
          end;
      end;


    { all fpu load routines expect that R_ST[0-7] means an fpu regvar and }
    { R_ST means "the current value at the top of the fpu stack" (JM)     }
    procedure TCGX86.A_LoadFPU_Reg_Reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister);

       var
         href: TReference;
         op: TAsmOp;
         s: TOpSize;
       begin
         if (reg1<>NR_ST) then
           begin
             floatloadops(tosize,op,s);
             list.concat(TAICPU.op_reg(op,s,rgfpu.Correct_FPURegister(reg1,rgfpu.FPUVarOffset)));
             inc_fpu_stack;
           end;
         if (reg2<>NR_ST) then
           begin
             floatstoreops(tosize,op,s);
             list.concat(TAICPU.op_reg(op,s,rgfpu.Correct_FPURegister(reg2,rgfpu.FPUVarOffset)));
             dec_fpu_stack;
           end;
         { OS_F80 < OS_C64, but OS_C64 fits perfectly in OS_F80 }
         if (reg1=NR_ST) and
            (reg2=NR_ST) and
            (tosize<>OS_F80) and
            (tosize<fromsize) then
           begin
             { can't round down to lower precision in x87 :/ }
             tg.gettemp(list,TCgSize2Size[tosize],TCgSize2Size[tosize],tt_normal,href);
             A_LoadFPU_Reg_Ref(list,fromsize,tosize,NR_ST,href);
             A_LoadFPU_Ref_Reg(list,tosize,tosize,href,NR_ST);
             tg.ungettemp(list,href);
           end;
       end;


    procedure TCGX86.A_LoadFPU_Ref_Reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; reg: TRegister);
       var
         tmpref : TReference;
       begin
         tmpref:=ref;
         make_simple_ref(list,tmpref);
         floatload(list,fromsize,tmpref);
         A_LoadFPU_Reg_Reg(list,fromsize,tosize,NR_ST,reg);
       end;


    procedure TCGX86.A_LoadFPU_Reg_Ref(list: TAsmList; fromsize,tosize: TCgSize; reg: TRegister; const ref: TReference);
       var
         tmpref : TReference;
       begin
         tmpref:=ref;
         make_simple_ref(list,tmpref);
         { in case a record returned in a floating point register
           (LOC_FPUREGISTER with OS_F32/OS_F64) is stored in memory
           (LOC_REFERENCE with OS_32/OS_64), we have to adjust the
           tosize }
        if (fromsize in [OS_F32,OS_F64]) and
           (TCgSize2Size[fromsize]=TCgSize2Size[tosize]) then
          case tosize of
            OS_32:
              tosize:=OS_F32;
            OS_64:
              tosize:=OS_F64;
            else
              ;
          end;
         if reg<>NR_ST then
           A_LoadFPU_Reg_Reg(list,fromsize,tosize,reg,NR_ST);
         floatstore(list,tosize,tmpref);
       end;


    procedure TCGX86.A_LoadFPU_Ref_CGPara(list: TAsmList; size: TCgSize; const ref: TReference; const cgpara: TCGPara);
      var
        href: TReference;
      begin
        if cgpara.Location^.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
          begin
            cgpara.Check_Simple_Location;
            Reference_Reset_Base(href,cgpara.Location^.Reference.Index,cgpara.Location^.Reference.Offset,CTempPosInvalid,cgpara.Alignment,[]);
            floatload(list,size,ref);
            floatstore(list,size,href);
          end
        else
          inherited A_LoadFPU_Ref_CGPara(list, size, ref, cgpara);
      end;


    function get_scalar_mm_op(fromsize,tosize : TCgSize;aligned : boolean) : TAsmOp;
      const
        convertopsse : array[OS_F32..OS_F128,OS_F32..OS_F128] of TAsmOp = (
          (A_MOVSS,A_CVTSS2SD,A_NONE,A_NONE,A_NONE),
          (A_CVTSD2SS,A_MOVSD,A_NONE,A_NONE,A_NONE),
          (A_NONE,A_NONE,A_NONE,A_NONE,A_NONE),
          (A_NONE,A_NONE,A_NONE,A_MOVQ,A_NONE),
          (A_NONE,A_NONE,A_NONE,A_NONE,A_MOVAPS));
        convertopavx : array[OS_F32..OS_F128,OS_F32..OS_F128] of TAsmOp = (
          (A_VMOVSS,A_VCVTSS2SD,A_NONE,A_NONE,A_NONE),
          (A_VCVTSD2SS,A_VMOVSD,A_NONE,A_NONE,A_NONE),
          (A_NONE,A_NONE,A_NONE,A_NONE,A_NONE),
          (A_NONE,A_NONE,A_NONE,A_MOVQ,A_NONE),
          (A_NONE,A_NONE,A_NONE,A_NONE,A_VMOVAPS));
      begin
        { we can have OS_F32/OS_F64 (record in function result/LOC_MMREGISTER) to
          OS_32/OS_64 (record in memory/LOC_REFERENCE) }
        if (fromsize in [OS_F32,OS_F64]) and
           (TCgSize2Size[fromsize]=TCgSize2Size[tosize]) then
          case tosize of
            OS_32:
              tosize:=OS_F32;
            OS_64:
              tosize:=OS_F64;
            else
              ;
          end;
        if (fromsize in [low(convertopsse)..high(convertopsse)]) and
           (tosize in [low(convertopsse)..high(convertopsse)]) then
          begin
            if UseAVX then
              result:=convertopavx[fromsize,tosize]
            else
              result:=convertopsse[fromsize,tosize];
          end
        { we can have OS_M64 (record in function result/LOC_MMREGISTER) to
          OS_64 (record in memory/LOC_REFERENCE) }
        else if (TCgSize2Size[fromsize]=TCgSize2Size[tosize]) then
          begin
            case fromsize of
              OS_M64:
                { we can have OS_M64 (record in function result/LOC_MMREGISTER) to
                  OS_64 (record in memory/LOC_REFERENCE) }
                if UseAVX then
                  result:=A_VMOVQ
                else
                  result:=A_MOVQ;
              OS_M128:
                { 128-bit aligned vector }
                if UseAVX then
                  begin
                    if aligned then
                      result:=A_VMOVAPS
                    else
                      result:=A_VMOVUPS;
                  end
                else if aligned then
                  result:=A_MOVAPS
                else
                  result:=A_MOVUPS;
              OS_M256,
              OS_M512:
                { 256-bit aligned vector }
                if UseAVX then
                  begin
                    if aligned then
                      result:=A_VMOVAPS
                    else
                      result:=A_VMOVUPS;
                  end
                else
                  { SSE does not support 256-bit or 512-bit vectors }
                  InternalError(2018012930);
              else
                InternalError(2018012920);
            end;
          end
        else if (TCgSize2Size[fromsize]=TCgSize2Size[tosize]) and
          (fromsize=OS_M128) then
          begin
            if UseAVX then
              result:=A_VMOVDQU
            else
              result:=A_MOVDQU;
          end
        else
          InternalError(2010060104);
        if result=A_NONE then
          InternalError(200312205);
      end;


    procedure TCGX86.A_LoadMM_Reg_Reg(list: TAsmList; fromsize, tosize : TCgSize;reg1, reg2: TRegister;shuffle : PMMShuffle);
      var
        instr : TAICPU;
        op : TAsmOp;
      begin
        if shuffle=nil then
          begin
            if fromsize=tosize then
              { needs correct size in case of spilling }
              case fromsize of
                OS_F32:
                  if UseAVX then
                    instr:=TAICPU.op_reg_reg(A_VMOVAPS,S_NO,reg1,reg2)
                  else
                    instr:=TAICPU.op_reg_reg(A_MOVAPS,S_NO,reg1,reg2);
                OS_F64:
                  if UseAVX then
                    instr:=TAICPU.op_reg_reg(A_VMOVAPD,S_NO,reg1,reg2)
                  else
                    instr:=TAICPU.op_reg_reg(A_MOVAPD,S_NO,reg1,reg2);
                OS_M64:
                  if UseAVX then
                    instr:=TAICPU.op_reg_reg(A_VMOVQ,S_NO,reg1,reg2)
                  else
                    instr:=TAICPU.op_reg_reg(A_MOVQ,S_NO,reg1,reg2);
                OS_M128:
                  if UseAVX then
                    instr:=TAICPU.op_reg_reg(A_VMOVDQA,S_NO,reg1,reg2)
                  else
                    instr:=TAICPU.op_reg_reg(A_MOVDQA,S_NO,reg1,reg2);
                OS_M256,
                OS_M512:
                  if UseAVX then
                    instr:=TAICPU.op_reg_reg(A_VMOVDQA,S_NO,reg1,reg2)
                  else
                    { SSE doesn't support 512-bit vectors }
                    InternalError(2018012933);
                else
                  InternalError(2006091201);
              end
            else
              InternalError(200312202);
            Add_Move_Instruction(instr);
          end
        else if ShuffleScalar(shuffle) then
          begin
            op:=get_scalar_mm_op(fromsize,tosize,true);

            { MOVAPD/MOVAPS are normally faster }
            if op=A_MOVSD then
              op:=A_MOVAPD
            else if op=A_MOVSS then
              op:=A_MOVAPS
            { VMOVSD/SS is not available with two register operands }
            else if op=A_VMOVSD then
              op:=A_VMOVAPD
            else if op=A_VMOVSS then
              op:=A_VMOVAPS;

            { A_VCVTSD2SS and A_VCVTSS2SD require always three operands }
            if (op=A_VCVTSD2SS) or (op=A_VCVTSS2SD) then
              instr:=TAICPU.op_reg_reg_reg(op,S_NO,reg1,reg1,reg2)
            else
              instr:=TAICPU.op_reg_reg(op,S_NO,reg1,reg2);

            case op of
              A_VMOVAPD,
              A_VMOVAPS,
              A_VMOVSS,
              A_VMOVSD,
              A_VMOVQ,
              A_MOVAPD,
              A_MOVAPS,
              A_MOVSS,
              A_MOVSD,
              A_MOVQ:
                Add_Move_Instruction(instr);
              else
                ;
            end;
          end
        else
          InternalError(200312201);
        list.concat(instr);
      end;


    procedure TCGX86.A_LoadMM_Ref_Reg(list: TAsmList; fromsize, tosize : TCgSize;const ref: TReference; reg: TRegister;shuffle : PMMShuffle);
       var
         tmpref  : TReference;
         op : TAsmOp;
       begin
         tmpref:=ref;
         make_simple_ref(list,tmpref);
         if shuffle=nil then
           begin
             case fromsize of
               OS_F32:
                 if UseAVX then
                   op := A_VMOVSS
                 else
                   op := A_MOVSS;
               OS_F64:
                 if UseAVX then
                   op := A_VMOVSD
                 else
                   op := A_MOVSD;
               OS_M32, OS_32, OS_S32:
                 if UseAVX then
                   op := A_VMOVD
                 else
                   op := A_MOVD;
               OS_M64, OS_64, OS_S64:
                 { there is no VMOVQ for MMX registers }
                 if UseAVX and (GetRegType(reg)<>R_MMXREGISTER) then
                   op := A_VMOVQ
                 else
                   op := A_MOVQ;
               OS_128,
               OS_M128:
                 { Use XMM integer transfer }
                 if UseAVX then
                   begin
                     if GetRefAlignment(tmpref) = 16 then
                       op := A_VMOVDQA
                     else
                       op := A_VMOVDQU;
                   end
                 else
                   begin
                     if GetRefAlignment(tmpref) = 16 then
                       op := A_MOVDQA
                     else
                       op := A_MOVDQU;
                   end;
               OS_M256:
                 { Use YMM integer transfer }
                 if UseAVX then
                   begin
                     if GetRefAlignment(tmpref) = 32 then
                       op := A_VMOVDQA
                     else
                       op := A_VMOVDQU;
                   end
                 else
                   { SSE doesn't support 256-bit vectors }
                   InternalError(2020010401);
               OS_M512:
                 { Use ZMM integer transfer }
                 if UseAVX then
                   begin
                     if GetRefAlignment(tmpref) = 64 then
                       op := A_VMOVDQA64
                     else
                       op := A_VMOVDQU64;
                   end
                 else
                   { SSE doesn't support 512-bit vectors }
                   InternalError(2018012939);
               else
                 { No valid transfer command available }
                 InternalError(2017121410);
             end;
             list.concat(TAICPU.op_ref_reg(op,S_NO,tmpref,reg));
           end
         else if ShuffleScalar(shuffle) then
           begin
             op:=get_scalar_mm_op(fromsize,tosize,TCgSize2Size[fromsize]=ref.Alignment);

             { A_VCVTSD2SS and A_VCVTSS2SD require always three operands }
             if (op=A_VCVTSD2SS) or (op=A_VCVTSS2SD) then
               list.concat(TAICPU.op_ref_reg_reg(op,S_NO,tmpref,reg,reg))
             else
               list.concat(TAICPU.op_ref_reg(op,S_NO,tmpref,reg))
           end
         else
           InternalError(200312252);
       end;


    procedure TCGX86.A_LoadMM_Reg_Ref(list: TAsmList; fromsize, tosize : TCgSize;reg: TRegister; const ref: TReference;shuffle : PMMShuffle);
       var
         hreg : TRegister;
         tmpref  : TReference;
         op : TAsmOp;

       begin
         tmpref:=ref;
         make_simple_ref(list,tmpref);
         if shuffle=nil then
           begin
             case fromsize of
               OS_F32:
                 if UseAVX then
                   op := A_VMOVSS
                 else
                   op := A_MOVSS;
               OS_F64:
                 if UseAVX then
                   op := A_VMOVSD
                 else
                   op := A_MOVSD;
               OS_M32, OS_32, OS_S32:
                 if UseAVX then
                   op := A_VMOVD
                 else
                   op := A_MOVD;
               OS_M64, OS_64, OS_S64:
                 { there is no VMOVQ for MMX registers }
                 if UseAVX and (GetRegType(reg)<>R_MMXREGISTER) then
                   op := A_VMOVQ
                 else
                   op := A_MOVQ;
               OS_M128:
                 { Use XMM integer transfer }
                 if UseAVX then
                 begin
                   if GetRefAlignment(tmpref) = 16 then
                     op := A_VMOVDQA
                   else
                     op := A_VMOVDQU;
                 end else
                 begin
                   if GetRefAlignment(tmpref) = 16 then
                     op := A_MOVDQA
                   else
                     op := A_MOVDQU;
                 end;
               OS_M256:
                 { Use XMM integer transfer }
                 if UseAVX then
                 begin
                   if GetRefAlignment(tmpref) = 32 then
                     op := A_VMOVDQA
                   else
                     op := A_VMOVDQU;
                 end else
                   { SSE doesn't support 256-bit vectors }
                   InternalError(2018012942);
               OS_M512:
                 { Use XMM integer transfer }
                 if UseAVX then
                 begin
                   if GetRefAlignment(tmpref) = 64 then
                     op := A_VMOVDQA64
                   else
                     op := A_VMOVDQU64;
                 end else
                   { SSE doesn't support 512-bit vectors }
                   InternalError(2018012945);
               else
                 { No valid transfer command available }
                 InternalError(2017121411);
             end;
             list.concat(TAICPU.op_reg_ref(op,S_NO,reg,tmpref));
           end
         else if ShuffleScalar(shuffle) then
           begin
             if TCgSize2Size[tosize]<>TCgSize2Size[fromsize] then
               begin
                 hreg:=GetMMRegister(list,tosize);
                 op:=get_scalar_mm_op(fromsize,tosize,TCgSize2Size[tosize]=ref.Alignment);

                 { A_VCVTSD2SS and A_VCVTSS2SD require always three operands }
                 if (op=A_VCVTSD2SS) or (op=A_VCVTSS2SD) then
                   list.concat(TAICPU.op_reg_reg_reg(op,S_NO,reg,reg,hreg))
                 else
                   list.concat(TAICPU.op_reg_reg(op,S_NO,reg,hreg));

                 list.concat(TAICPU.op_reg_ref(get_scalar_mm_op(tosize,tosize,TCgSize2Size[tosize]=tmpref.Alignment),S_NO,hreg,tmpref))
               end
             else
               list.concat(TAICPU.op_reg_ref(get_scalar_mm_op(fromsize,tosize,TCgSize2Size[tosize]=tmpref.Alignment),S_NO,reg,tmpref));
           end
         else
           InternalError(2003122501);
       end;


    procedure TCGX86.A_OpMM_Ref_Reg(list: TAsmList; Op: TOpCG; size : TCgSize;const ref: TReference; reg: TRegister;shuffle : PMMShuffle);
      var
        l : TLocation;
      begin
        l.Loc:=LOC_REFERENCE;
        l.Reference:=ref;
        l.Size:=size;
        opmm_loc_reg(list,op,size,l,reg,shuffle);
      end;


    procedure TCGX86.A_OpMM_Reg_Reg(list: TAsmList; Op: TOpCG; size : TCgSize;src,dst: TRegister;shuffle : PMMShuffle);
     var
       l : TLocation;
     begin
       l.Loc:=LOC_MMREGISTER;
       l.Register:=src;
       l.Size:=size;
       opmm_loc_reg(list,op,size,l,dst,shuffle);
     end;


    procedure TCGX86.opmm_loc_reg_reg(list: TAsmList; Op: TOpCG; size : TCgSize;loc : TLocation;src,dst: TRegister; shuffle : PMMShuffle);
      const
        opmm2asmop : array[0..1,OS_F32..OS_F64,TOpCG] of TAsmOp = (
          ( { scalar }
            ( { OS_F32 }
              A_NOP,A_NOP,A_VADDSS,A_NOP,A_VDIVSS,A_NOP,A_NOP,A_VMULSS,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_VSUBSS,A_NOP,A_NOP,A_NOP
            ),
            ( { OS_F64 }
              A_NOP,A_NOP,A_VADDSD,A_NOP,A_VDIVSD,A_NOP,A_NOP,A_VMULSD,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_VSUBSD,A_NOP,A_NOP,A_NOP
            )
          ),
          ( { vectorized/packed }
            { because the logical packed single instructions have shorter op codes, we use always
              these
            }
            ( { OS_F32 }
              A_NOP,A_NOP,A_VADDPS,A_NOP,A_VDIVPS,A_NOP,A_NOP,A_VMULPS,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_VSUBPS,A_VXORPS,A_NOP,A_NOP
            ),
            ( { OS_F64 }
              A_NOP,A_NOP,A_VADDPD,A_NOP,A_VDIVPD,A_NOP,A_NOP,A_VMULPD,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_VSUBPD,A_VXORPD,A_NOP,A_NOP
            )
          )
        );

      var
        resultreg : TRegister;
        asmop : TAsmOp;
      begin
        { this is an internally used procedure so the parameters have
          some constrains
        }
        if loc.Size<>size then
          InternalError(2013061108);
        resultreg:=dst;
        { deshuffle }
        //!!!
        if (shuffle<>nil) and not(ShuffleScalar(shuffle)) then
          begin
            InternalError(2013061107);
          end
        else if (shuffle=nil) then
          asmop:=opmm2asmop[1,size,op]
        else if ShuffleScalar(shuffle) then
          begin
            asmop:=opmm2asmop[0,size,op];
            { no scalar operation available? }
            if asmop=A_NOP then
              begin
                { do vectorized and shuffle finally }
                InternalError(2010060103);
              end;
          end
        else
          InternalError(2013061106);
        if asmop=A_NOP then
          InternalError(2013061105);
        case loc.Loc of
          LOC_CREFERENCE,LOC_REFERENCE:
            begin
              make_simple_ref(CurrentAsmData.CurrAsmList,loc.Reference);
              list.concat(TAICPU.op_ref_reg_reg(asmop,S_NO,loc.Reference,src,resultreg));
            end;
          LOC_CMMREGISTER,LOC_MMREGISTER:
            list.concat(TAICPU.op_reg_reg_reg(asmop,S_NO,loc.Register,src,resultreg));
          else
            InternalError(2013061104);
        end;
        { shuffle }
        if resultreg<>dst then
          begin
            InternalError(2013061103);
          end;
      end;


    procedure TCGX86.A_OpMM_Reg_Reg_Reg(list: TAsmList; Op: TOpCG; size : TCgSize;src1,src2,dst: TRegister;shuffle : PMMShuffle);
      var
        l : TLocation;
      begin
        l.Loc:=LOC_MMREGISTER;
        l.Register:=src1;
        l.Size:=size;
        opmm_loc_reg_reg(list,op,size,l,src2,dst,shuffle);
      end;


    procedure TCGX86.A_OpMM_Ref_Reg_Reg(list: TAsmList; Op: TOpCG; size : TCgSize;const ref: TReference; src,dst: TRegister;shuffle : PMMShuffle);
      var
        l : TLocation;
      begin
        l.Loc:=LOC_REFERENCE;
        l.Reference:=ref;
        l.Size:=size;
        opmm_loc_reg_reg(list,op,size,l,src,dst,shuffle);
      end;


    procedure TCGX86.opmm_loc_reg(list: TAsmList; Op: TOpCG; size : TCgSize;loc : TLocation;dst: TRegister; shuffle : PMMShuffle);
      const
        opmm2asmop : array[0..1,OS_F32..OS_F64,TOpCG] of TAsmOp = (
          ( { scalar }
            ( { OS_F32 }
              A_NOP,A_NOP,A_ADDSS,A_NOP,A_DIVSS,A_NOP,A_NOP,A_MULSS,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_SUBSS,A_XORPS,A_NOP,A_NOP
            ),
            ( { OS_F64 }
              A_NOP,A_NOP,A_ADDSD,A_NOP,A_DIVSD,A_NOP,A_NOP,A_MULSD,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_SUBSD,A_XORPD,A_NOP,A_NOP
            )
          ),
          ( { vectorized/packed }
            { because the logical packed single instructions have shorter op codes, we use always
              these
            }
            ( { OS_F32 }
              A_NOP,A_NOP,A_ADDPS,A_NOP,A_DIVPS,A_NOP,A_NOP,A_MULPS,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_SUBPS,A_XORPS,A_NOP,A_NOP
            ),
            ( { OS_F64 }
              A_NOP,A_NOP,A_ADDPD,A_NOP,A_DIVPD,A_NOP,A_NOP,A_MULPD,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_SUBPD,A_XORPD,A_NOP,A_NOP
            )
          )
        );
        opmm2asmop_avx : array[0..1,OS_F32..OS_F64,TOpCG] of TAsmOp = (
          ( { scalar }
            ( { OS_F32 }
              A_NOP,A_NOP,A_VADDSS,A_NOP,A_VDIVSS,A_NOP,A_NOP,A_VMULSS,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_VSUBSS,A_VXORPS,A_NOP,A_NOP
            ),
            ( { OS_F64 }
              A_NOP,A_NOP,A_VADDSD,A_NOP,A_VDIVSD,A_NOP,A_NOP,A_VMULSD,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_VSUBSD,A_VXORPD,A_NOP,A_NOP
            )
          ),
          ( { vectorized/packed }
            { because the logical packed single instructions have shorter op codes, we use always
              these
            }
            ( { OS_F32 }
              A_NOP,A_NOP,A_VADDPS,A_NOP,A_VDIVPS,A_NOP,A_NOP,A_VMULPS,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_VSUBPS,A_VXORPS,A_NOP,A_NOP
            ),
            ( { OS_F64 }
              A_NOP,A_NOP,A_VADDPD,A_NOP,A_VDIVPD,A_NOP,A_NOP,A_VMULPD,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_VSUBPD,A_VXORPD,A_NOP,A_NOP
            )
          )
        );
        opmm2asmop_full : array[TOpCG] of TAsmOp = (
          A_NOP,A_NOP,A_NOP,A_PAND,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_POR,A_NOP,A_NOP,A_NOP,A_NOP,A_PXOR,A_NOP,A_NOP
        );
        opmm2asmop_full_avx : array[TOpCG] of TAsmOp = (
          A_NOP,A_NOP,A_NOP,A_VPAND,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_NOP,A_VPOR,A_NOP,A_NOP,A_NOP,A_NOP,A_VPXOR,A_NOP,A_NOP
        );
      var
        resultreg : TRegister;
        asmop : TAsmOp;
      begin
        { this is an internally used procedure so the parameters have
          some constrains
        }
        if loc.Size<>size then
          InternalError(200312213);
        resultreg:=dst;
        { deshuffle }
        //!!!
        if (shuffle<>nil) and not(ShuffleScalar(shuffle)) then
          begin
            InternalError(2010060101);
          end
        else if shuffle=nil then
          begin
            if UseAVX then
              begin
                asmop:=opmm2asmop_full_avx[op];
{$ifdef x86_64}
                { A_VPXOR does not support the upper 16 registers }
                if (asmop=A_VPXOR) and (FPUX86_HAS_32MMREGS in fpu_capabilities[CurrentSettings.FPUType]) then
                  asmop:=A_VPXORD;
{$endif x86_64}
                if size in [OS_M256,OS_M512] then
                  Include(CurrentProcInfo.flags,pi_uses_ymm);
              end
            else if size in [OS_F32,OS_F64] then
              asmop:=opmm2asmop[0,size,op]
            else
              asmop:=opmm2asmop_full[op];
          end
        else if ShuffleScalar(shuffle) then
          begin
            if UseAVX then
              begin
                asmop:=opmm2asmop_avx[0,size,op];
                if size in [OS_M256,OS_M512] then
                  Include(CurrentProcInfo.flags,pi_uses_ymm);
              end
            else
              asmop:=opmm2asmop[0,size,op];
          end
        else
          InternalError(200312211);
        if asmop=A_NOP then
          InternalError(200312216);
        case loc.Loc of
          LOC_CREFERENCE,LOC_REFERENCE:
            begin
              make_simple_ref(CurrentAsmData.CurrAsmList,loc.Reference);
              if UseAVX then
                list.concat(TAICPU.op_ref_reg_reg(asmop,S_NO,loc.Reference,resultreg,resultreg))
              else
                list.concat(TAICPU.op_ref_reg(asmop,S_NO,loc.Reference,resultreg));
            end;
          LOC_CMMREGISTER,LOC_MMREGISTER:
            if UseAVX then
              list.concat(TAICPU.op_reg_reg_reg(asmop,S_NO,loc.Register,resultreg,resultreg))
            else
              list.concat(TAICPU.op_reg_reg(asmop,S_NO,loc.Register,resultreg));
          else
            InternalError(200312214);
        end;
        { shuffle }
        if resultreg<>dst then
          begin
            InternalError(200312212);
          end;
      end;



    procedure TCGX86.A_Op_Const_Reg_Reg(list:TAsmList;op:TOpCG;size:TCgSize;
                                        a:TCGInt;src,dst:TRegister);
      var
        power,al  : LongInt;
        href : TReference;
      begin
        power:=0;
        Optimize_Op_Const(size,op,a);
        case op of
          OP_NONE:
            begin
              A_Load_Reg_Reg(list,size,size,src,dst);
              exit;
            end;
          OP_MOVE:
            begin
              A_Load_Const_Reg(list,size,a,dst);
              exit;
            end;
          else
            ;
        end;
        if (op in [OP_MUL,OP_IMUL]) and (size in [OS_32,OS_S32,OS_64,OS_S64]) and
          not(cs_check_overflow in CurrentSettings.LocalSwitches) and
          (a>1) and IsPowerOf2(int64(a-1),power) and (power in [1..3]) then
          begin
            Reference_Reset_Base(href,src,0,CTempPosInvalid,0,[]);
            href.Index:=src;
            href.ScaleFactor:=a-1;
            list.concat(TAICPU.op_ref_reg(A_LEA,TCgSize2OpSize[size],href,dst));
          end
        else if (op in [OP_MUL,OP_IMUL]) and (size in [OS_32,OS_S32,OS_64,OS_S64]) and
          not(cs_check_overflow in CurrentSettings.LocalSwitches) and
          (a>1) and IsPowerOf2(int64(a),power) and (power in [1..3]) then
          begin
            Reference_Reset_Base(href,NR_NO,0,CTempPosInvalid,0,[]);
            href.Index:=src;
            href.ScaleFactor:=a;
            list.concat(TAICPU.op_ref_reg(A_LEA,TCgSize2OpSize[size],href,dst));
          end
        else if (op in [OP_MUL,OP_IMUL]) and (size in [OS_16,OS_S16,OS_32,OS_S32,OS_64,OS_S64]) and
          (a>1) and (a<=maxLongint) and not IsPowerOf2(int64(a),power) then
          begin
            { MUL with overflow checking should be handled specifically in the code generator }
            if (op=OP_MUL) and (cs_check_overflow in CurrentSettings.LocalSwitches) then
              InternalError(2014011801);
            list.concat(TAICPU.op_const_reg_reg(A_IMUL,TCgSize2OpSize[size],a,src,dst));
          end
        else if (op=OP_ADD) and
          ((size in [OS_32,OS_S32]) or
           { lea supports only 32 bit signed displacements }
           ((size=OS_64) and (a>=0) and (a<=maxLongint)) or
           ((size=OS_S64) and (a>=-maxLongint) and (a<=maxLongint))
          ) and
          not(cs_check_overflow in CurrentSettings.LocalSwitches) then
          begin
            { a might still be in the range 0x80000000 to 0xffffffff
              which might trigger a range check error as
              reference_reset_base expects a longint value. }
{$push} {$R-}{$Q-}
            al := LongInt (a);
{$pop}
            Reference_Reset_Base(href,src,al,CTempPosInvalid,0,[]);
            list.concat(TAICPU.op_ref_reg(A_LEA,TCgSize2OpSize[size],href,dst));
          end
        else if (op=OP_SHL) and (size in [OS_32,OS_S32,OS_64,OS_S64]) and
          (int64(a)>=1) and (int64(a)<=3) then
          begin
            Reference_Reset_Base(href,NR_NO,0,CTempPosInvalid,0,[]);
            href.Index:=src;
            href.ScaleFactor:=1 shl LongInt(a);
            list.concat(TAICPU.op_ref_reg(A_LEA,TCgSize2OpSize[size],href,dst));
          end
        else if (op=OP_SUB) and
          ((size in [OS_32,OS_S32]) or
           { lea supports only 32 bit signed displacements }
           ((size=OS_64) and (a>=0) and (a<=maxLongint)) or
           ((size=OS_S64) and (a>=-maxLongint) and (a<=maxLongint))
          ) and
          not(cs_check_overflow in CurrentSettings.LocalSwitches) then
          begin
            Reference_Reset_Base(href,src,-a,CTempPosInvalid,0,[]);
            list.concat(TAICPU.op_ref_reg(A_LEA,TCgSize2OpSize[size],href,dst));
          end
        else if (op in [OP_ROR,OP_ROL]) and
          (CPUX86_HAS_BMI2 in cpu_capabilities[CurrentSettings.CPUType]) and
          (size in [OS_32,OS_S32
{$ifdef x86_64}
            ,OS_64,OS_S64
{$endif x86_64}
          ]) then
          begin
            if op=OP_ROR then
              list.concat(TAICPU.op_const_reg_reg(A_RORX,TCgSize2OpSize[size], a,src,dst))
            else
              list.concat(TAICPU.op_const_reg_reg(A_RORX,TCgSize2OpSize[size],TCgSize2Size[size]*8-a,src,dst));
          end
        else
          inherited A_Op_Const_Reg_Reg(list,op,size,a,src,dst);
      end;


    procedure TCGX86.A_Op_Reg_Reg_Reg(list: TAsmList; op: TOpCG;
      size: TCgSize; src1, src2, dst: TRegister);
      var
        href : TReference;
      begin
        if (op=OP_ADD) and (size in [OS_32,OS_S32,OS_64,OS_S64]) and
          not(cs_check_overflow in CurrentSettings.LocalSwitches) then
          begin
            Reference_Reset_Base(href,src1,0,CTempPosInvalid,0,[]);
            href.Index:=src2;
            list.concat(TAICPU.op_ref_reg(A_LEA,TCgSize2OpSize[size],href,dst));
          end
        else if (op in [OP_SAR,OP_SHR,OP_SHL]) and
          (CPUX86_HAS_BMI2 in cpu_capabilities[CurrentSettings.CPUType]) and
          (size in [OS_32,OS_S32
{$ifdef x86_64}
            ,OS_64,OS_S64
{$endif x86_64}
          ]) then
          begin
            case op of
              OP_SAR:
                list.concat(TAICPU.op_reg_reg_reg(A_SARX,TCgSize2OpSize[size],src1,src2,dst));
              OP_SHL:
                list.concat(TAICPU.op_reg_reg_reg(A_SHLX,TCgSize2OpSize[size],src1,src2,dst));
              else
                list.concat(TAICPU.op_reg_reg_reg(A_SHRX,TCgSize2OpSize[size],src1,src2,dst));
            end;
          end
        else
          inherited A_Op_Reg_Reg_Reg(list,op,size,src1,src2,dst);
      end;



    procedure TCGX86.A_Op_Const_Reg(list : TAsmList; Op: TOpCG; size: TCgSize; a: TCGInt; reg: TRegister);
{$ifdef x86_64}
      var
        tmpreg : TRegister;
{$endif x86_64}
      begin
        Optimize_Op_Const(size, op, a);
{$ifdef x86_64}
        { x86_64 only supports signed 32 bits constants directly }
        if not(op in [OP_NONE,OP_MOVE]) and
           (size in [OS_S64,OS_64]) and
            ((a<low(LongInt)) or (a>high(LongInt))) then
          begin
            tmpreg:=GetIntRegister(list,size);
            A_Load_Const_Reg(list,size,a,tmpreg);
            A_Op_Reg_Reg(list,op,size,tmpreg,reg);
            exit;
          end;
{$endif x86_64}
        check_register_size(size,reg);
        case op of
          OP_NONE :
            begin
              { Opcode is optimized away }
            end;
          OP_MOVE :
            begin
              { Optimized, replaced with a simple load }
              A_Load_Const_Reg(list,size,a,reg);
            end;
          OP_DIV, OP_IDIV:
            begin
              { should be handled specifically in the code               }
              { generator because of the silly register usage restraints }
              InternalError(200109224);
            end;
          OP_MUL,OP_IMUL:
            begin
              if not (cs_check_overflow in CurrentSettings.LocalSwitches) then
                op:=OP_IMUL;
              if op = OP_IMUL then
                list.concat(TAICPU.op_const_reg(A_IMUL,TCgSize2OpSize[size],a,reg))
              else
                { OP_MUL should be handled specifically in the code        }
                { generator because of the silly register usage restraints }
                InternalError(200109225);
            end;
          OP_ADD, OP_SUB:
            if not(cs_check_overflow in CurrentSettings.LocalSwitches) and
               (a = 1) and
               UseIncDec then
              begin
                if op = OP_ADD then
                  list.concat(TAICPU.op_reg(A_INC,TCgSize2OpSize[size],reg))
                else
                  list.concat(TAICPU.op_reg(A_DEC,TCgSize2OpSize[size],reg))
              end
            else
              list.concat(TAICPU.op_const_reg(TOpCG2AsmOp[op],TCgSize2OpSize[size],ImmInt(a),reg));

          OP_AND,OP_OR:
            list.concat(TAICPU.op_const_reg(TOpCG2AsmOp[op],TCgSize2OpSize[size],ImmInt(a),reg));

          OP_XOR:
            if (aword(a)=high(aword)) then
              list.concat(TAICPU.op_reg(A_NOT,TCgSize2OpSize[size],reg))
            else
              list.concat(TAICPU.op_const_reg(TOpCG2AsmOp[op],TCgSize2OpSize[size],ImmInt(a),reg));

          OP_SHL,OP_SHR,OP_SAR,OP_ROL,OP_ROR:
            begin
{$if defined(x86_64)}
              if (a and 63) <> 0 Then
                list.concat(TAICPU.op_const_reg(TOpCG2AsmOp[op],TCgSize2OpSize[size],a and 63,reg));
              if (a shr 6) <> 0 Then
                InternalError(200609073);
{$elseif defined(i386)}
              if (a and 31) <> 0 Then
                list.concat(TAICPU.op_const_reg(TOpCG2AsmOp[op],TCgSize2OpSize[size],a and 31,reg));
              if (a shr 5) <> 0 Then
                InternalError(200609071);
{$endif}
            end
          else InternalError(200609072);
        end;
      end;


    procedure TCGX86.A_Op_Const_Ref(list : TAsmList; Op: TOpCG; size: TCgSize; a: TCGInt; const ref: TReference);
      var
{$ifdef x86_64}
        tmpreg : TRegister;
{$endif x86_64}
        tmpref  : TReference;
      begin
        Optimize_Op_Const(size, op, a);
        if op in [OP_NONE,OP_MOVE] then
          begin
            if (op=OP_MOVE) then
              A_Load_Const_Ref(list,size,a,ref);
            exit;
          end;

{$ifdef x86_64}
        { x86_64 only supports signed 32 bits constants directly }
        if (size in [OS_S64,OS_64]) and
            ((a<low(LongInt)) or (a>high(LongInt))) then
          begin
            tmpreg:=GetIntRegister(list,size);
            A_Load_Const_Reg(list,size,a,tmpreg);
            A_Op_Reg_Ref(list,op,size,tmpreg,ref);
            exit;
          end;
{$endif x86_64}

        tmpref:=ref;
        make_simple_ref(list,tmpref);

        Case Op of
          OP_DIV, OP_IDIV:
            Begin
              { should be handled specifically in the code               }
              { generator because of the silly register usage restraints }
              InternalError(200109231);
            End;
          OP_MUL,OP_IMUL:
            begin
              if not (cs_check_overflow in CurrentSettings.LocalSwitches) then
                op:=OP_IMUL;
              { can't multiply a memory location directly with a constant }
              if op = OP_IMUL then
                inherited A_Op_Const_Ref(list,op,size,a,tmpref)
              else
                { OP_MUL should be handled specifically in the code        }
                { generator because of the silly register usage restraints }
                InternalError(200109232);
            end;
          OP_ADD, OP_SUB:
            if not(cs_check_overflow in CurrentSettings.LocalSwitches) and
               (a = 1) and
               UseIncDec then
              begin
                if op = OP_ADD then
                  list.concat(TAICPU.op_ref(A_INC,TCgSize2OpSize[size],tmpref))
                else
                  list.concat(TAICPU.op_ref(A_DEC,TCgSize2OpSize[size],tmpref))
              end
            else
              list.concat(TAICPU.op_const_ref(TOpCG2AsmOp[op],TCgSize2OpSize[size],a,tmpref));

          OP_AND,OP_OR:
            list.concat(TAICPU.op_const_ref(TOpCG2AsmOp[op],TCgSize2OpSize[size],a,tmpref));

          OP_XOR:
            if (aword(a)=high(aword)) then
              list.concat(TAICPU.op_ref(A_NOT,TCgSize2OpSize[size],tmpref))
            else
              list.concat(TAICPU.op_const_ref(TOpCG2AsmOp[op],TCgSize2OpSize[size],a,tmpref));

          OP_SHL,OP_SHR,OP_SAR,OP_ROL,OP_ROR:
            begin
{$if defined(x86_64)}
              if (a and 63) <> 0 Then
                list.concat(TAICPU.op_const_ref(TOpCG2AsmOp[op],TCgSize2OpSize[size],a and 63,tmpref));
              if (a shr 6) <> 0 Then
                InternalError(2013111003);
{$elseif defined(i386)}
              if (a and 31) <> 0 Then
                list.concat(TAICPU.op_const_ref(TOpCG2AsmOp[op],TCgSize2OpSize[size],a and 31,tmpref));
              if (a shr 5) <> 0 Then
                InternalError(2013111002);
{$endif}
            end
          else InternalError(68992);
        end;
      end;


    procedure TCGX86.A_Op_Reg_Reg(list : TAsmList; Op: TOpCG; size: TCgSize; src, dst: TRegister);
      const
{$if defined(cpu64bitalu)}
        REGCX=NR_CL;
        REGCX_Size = OS_8;
{$elseif defined(cpu32bitalu)}
        REGCX=NR_ECX;
        REGCX_Size = OS_32;
{$endif}
      var
        dstsize: TOpSize;
        instr:TAICPU;
      begin
        if not(Op in [OP_SHR,OP_SHL,OP_SAR,OP_ROL,OP_ROR]) then
          check_register_size(size,src);
        check_register_size(size,dst);
        dstsize := tcgsize2opsize[size];
        if (op=OP_MUL) and not (cs_check_overflow in CurrentSettings.LocalSwitches) then
          op:=OP_IMUL;
        case op of
          OP_NEG,OP_NOT:
            begin
              if src<>dst then
                A_Load_Reg_Reg(list,size,size,src,dst);
              list.concat(TAICPU.op_reg(TOpCG2AsmOp[op],dstsize,dst));
            end;
          OP_MUL,OP_DIV,OP_IDIV:
            { special stuff, needs separate handling inside code }
            { generator                                          }
            InternalError(200109233);
          OP_SHR,OP_SHL,OP_SAR,OP_ROL,OP_ROR:
            begin
              { Use ecx to load the value, that allows better coalescing }
              GetCPURegister(list,REGCX);
              A_Load_Reg_Reg(list,reg_cgsize(src),REGCX_Size,src,REGCX);
              { Deallocate right before the instruction - it will be corrected
                later by the register allocator (not correcting it will cause
                it to be deallocated one instruction too late) }
              UngetCPURegister(list,REGCX);
              list.concat(TAICPU.op_reg_reg(Topcg2asmop[op],tcgsize2opsize[size],NR_CL,dst));
            end;
          else
            begin
              if reg2opsize(src) <> dstsize then
                InternalError(200109226);
              { x86 does not have an 8 Bit imul, so do 16 Bit multiplication
                we do not need to zero/sign extend as we discard the upper bits anyways }
              if (TOpCG2AsmOp[op]=A_IMUL) and (size in [OS_8,OS_S8]) then
                begin
                  { this might only happen if no overflow checking is done }
                  if cs_check_overflow in CurrentSettings.LocalSwitches then
                    InternalError(2021011601);
                  src:=MakeRegSize(list,src,OS_16);
                  dst:=MakeRegSize(list,dst,OS_16);
                  dstsize:=S_W;
                end;
              instr:=TAICPU.op_reg_reg(TOpCG2AsmOp[op],dstsize,src,dst);
              list.concat(instr);
            end;
        end;
      end;


    procedure TCGX86.A_Op_Ref_Reg(list : TAsmList; Op: TOpCG; size: TCgSize; const ref: TReference; reg: TRegister);
      var
        tmpref  : TReference;
      begin
        tmpref:=ref;
        make_simple_ref(list,tmpref);
        check_register_size(size,reg);
        if (op=OP_MUL) and not (cs_check_overflow in CurrentSettings.LocalSwitches) then
          op:=OP_IMUL;
        case op of
          OP_NEG,OP_NOT:
            begin
              inherited A_Op_Ref_Reg(list,op,size,tmpref,reg);
            end;
          OP_MUL,OP_DIV,OP_IDIV:
            { special stuff, needs separate handling inside code }
            { generator                                          }
            InternalError(200109239);
          else
            begin
              reg := MakeRegSize(list,reg,size);
              list.concat(TAICPU.op_ref_reg(TOpCG2AsmOp[op],tcgsize2opsize[size],tmpref,reg));
            end;
        end;
      end;


    procedure TCGX86.A_Op_Reg_Ref(list : TAsmList; Op: TOpCG; size: TCgSize;reg: TRegister; const ref: TReference);
      const
{$if defined(cpu64bitalu)}
        REGCX=NR_CL;
        REGCX_Size = OS_8;
{$elseif defined(cpu32bitalu)}
        REGCX=NR_ECX;
        REGCX_Size = OS_32;
{$endif}
      var
        tmpref  : TReference;
      begin
        tmpref:=ref;
        make_simple_ref(list,tmpref);
        { we don't check the register size for some operations, for the following reasons:
          SHR,SHL,SAR,ROL,ROR:
            We allow the register size to differ from the destination size.
            This allows generating better code when performing, for example, a
            shift/rotate in place (x:=x shl y) of a byte variable. In this case,
            we allow the shift count (y) to be located in a 32-bit register,
            even though x is a byte. This:
              - reduces register pressure on i386 (because only EAX,EBX,ECX and
                EDX have 8-bit subregisters)
              - avoids partial register writes, which can cause various
                performance issues on modern out-of-order execution x86 CPUs }
        if not (op in [OP_SHR,OP_SHL,OP_SAR,OP_ROL,OP_ROR]) then
          check_register_size(size,reg);
        if (op=OP_MUL) and not (cs_check_overflow in CurrentSettings.LocalSwitches) then
          op:=OP_IMUL;
        case op of
          OP_NEG,OP_NOT:
            inherited;
          OP_SHR,OP_SHL,OP_SAR,OP_ROL,OP_ROR:
            begin
              { Use ecx to load the value, that allows better coalescing }
              GetCPURegister(list,REGCX);
              A_Load_Reg_Reg(list,reg_cgsize(reg),REGCX_Size,reg,REGCX);
              { Deallocate right before the instruction - it will be corrected
                later by the register allocator (not correcting it will cause
                it to be deallocated one instruction too late) }
              UngetCPURegister(list,REGCX);
              list.concat(TAICPU.op_reg_ref(TOpCG2AsmOp[op],tcgsize2opsize[size],NR_CL,tmpref));
            end;
          OP_IMUL:
            begin
              { this one needs a load/imul/store, which is the default }
              inherited A_Op_Ref_Reg(list,op,size,tmpref,reg);
            end;
          OP_MUL,OP_DIV,OP_IDIV:
            { special stuff, needs separate handling inside code }
            { generator                                          }
            InternalError(200109238);
          else
            begin
              list.concat(TAICPU.op_reg_ref(TOpCG2AsmOp[op],tcgsize2opsize[size],reg,tmpref));
            end;
        end;
      end;

    procedure TCGX86.A_Op_Ref(list: TAsmList; Op: TOpCG; size: TCgSize; const ref: TReference);
      var
        tmpref: TReference;
      begin
        if not (Op in [OP_NOT,OP_NEG]) then
          InternalError(2020050705);
        tmpref:=ref;
        make_simple_ref(list,tmpref);
        list.concat(TAICPU.op_ref(TOpCG2AsmOp[op],tcgsize2opsize[size],tmpref));
      end;

     procedure TCGX86.A_Bit_Scan_Reg_Reg(list: TAsmList; reverse,not_zero: boolean; srcsize, dstsize: TCgSize; src, dst: TRegister);
     var
       tmpreg: TRegister;
       opsize: TOpSize;
       l : TAsmLabel;
     begin
       { no bsf/bsr for byte }
       if srcsize in [OS_8,OS_S8] then
         begin
           tmpreg:=GetIntRegister(list,OS_INT);
           A_Load_Reg_Reg(list,srcsize,OS_INT,src,tmpreg);
           src:=tmpreg;
           srcsize:=OS_INT;
         end;
       { source and destination register must have the same size }
       if TCgSize2Size[srcsize]<>TCgSize2Size[dstsize] then
         tmpreg:=GetIntRegister(list,srcsize)
       else
         tmpreg:=dst;
       opsize:=tcgsize2opsize[srcsize];

       { AMD docs: BSF/R dest, 0 “sets ZF to 1 and does not change the contents of the destination register.”
         Intel docs: “If the content source operand is 0, the content of the destination operand is undefined.”
         (However, Intel silently implements the same behavior as AMD, which is understandable.)

         If relying on this behavior, do

         mov tmpreg, $FF
         bsx tmpreg, src

         If not relying, do

         bsx tmpreg, src
         jnz .LDone
         mov tmpreg, $FF
.LDone:

         If not_zero: just a lone bsx suffices. }

       if (not not_zero) and (CPUX86_HINT_BSX_DEST_UNCHANGED_ON_ZF_1 in cpu_optimization_hints[CurrentSettings.OptimizeCPUType]) then
         begin
           list.concat(TAICPU.op_const_reg(A_MOV,opsize,$ff,tmpreg));
           A_Reg_Alloc(list,NR_DEFAULTFLAGS);
         end;

       if not reverse then
         list.concat(TAICPU.op_reg_reg(A_BSF,opsize,src,tmpreg))
       else
         list.concat(TAICPU.op_reg_reg(A_BSR,opsize,src,tmpreg));

       if (not not_zero) and not (CPUX86_HINT_BSX_DEST_UNCHANGED_ON_ZF_1 in cpu_optimization_hints[CurrentSettings.OptimizeCPUType]) then
         begin
           CurrentAsmData.getjumplabel(l);
           a_jmp_cond(list,OC_NE,l);
           A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
           list.concat(TAICPU.op_const_reg(A_MOV,opsize,$ff,tmpreg));
           A_Label(list,l);
         end;

       if tmpreg<>dst then
         A_Load_Reg_Reg(list,srcsize,dstsize,tmpreg,dst);
     end;

{*************** compare instructions ****************}

    procedure TCGX86.A_Cmp_Const_Reg_Label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;a : TCGInt;reg : TRegister;
      l : TAsmLabel);

{$ifdef x86_64}
      var
        tmpreg : TRegister;
{$endif x86_64}
      begin
{$ifdef x86_64}
        { x86_64 only supports signed 32 bits constants directly }
        if (size in [OS_S64,OS_64]) and
            ((a<low(LongInt)) or (a>high(LongInt))) then
          begin
            tmpreg:=GetIntRegister(list,size);
            A_Load_Const_Reg(list,size,a,tmpreg);
            A_Cmp_Reg_Reg_Label(list,size,cmp_op,tmpreg,reg,l);
            exit;
          end;
{$endif x86_64}
        cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
        list.concat(TAICPU.op_const_reg(A_CMP,tcgsize2opsize[size],a,reg));
        a_jmp_cond(list,cmp_op,l);
        cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
      end;


    procedure TCGX86.A_Cmp_Const_Ref_Label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;a : TCGInt;const ref : TReference;
      l : TAsmLabel);

      var
{$ifdef x86_64}
        tmpreg : TRegister;
{$endif x86_64}
        tmpref  : TReference;
      begin
        tmpref:=ref;
        make_simple_ref(list,tmpref);
{$ifdef x86_64}
        { x86_64 only supports signed 32 bits constants directly }
        if (size in [OS_S64,OS_64]) and
           ((a<low(LongInt)) or (a>high(LongInt))) then
          begin
            tmpreg:=GetIntRegister(list,size);
            A_Load_Const_Reg(list,size,a,tmpreg);
            A_Cmp_Reg_Ref_Label(list,size,cmp_op,tmpreg,tmpref,l);
            exit;
          end;
{$endif x86_64}
        cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
        list.concat(TAICPU.op_const_ref(A_CMP,TCgSize2OpSize[size],a,tmpref));
        a_jmp_cond(list,cmp_op,l);
        cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
      end;


    procedure TCGX86.A_Cmp_Reg_Reg_Label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;
      reg1,reg2 : TRegister;l : TAsmLabel);

      begin
        check_register_size(size,reg1);
        check_register_size(size,reg2);
        cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
        list.concat(TAICPU.op_reg_reg(A_CMP,TCgSize2OpSize[size],reg1,reg2));
        a_jmp_cond(list,cmp_op,l);
        cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
      end;


    procedure TCGX86.A_Cmp_Ref_Reg_Label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;const ref: TReference; reg : TRegister;l : TAsmLabel);
      var
        tmpref  : TReference;
      begin
        tmpref:=ref;
        make_simple_ref(list,tmpref);
        check_register_size(size,reg);
        cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
        list.concat(TAICPU.op_ref_reg(A_CMP,TCgSize2OpSize[size],tmpref,reg));
        a_jmp_cond(list,cmp_op,l);
        cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
      end;


    procedure TCGX86.A_Cmp_Reg_Ref_Label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;reg : TRegister;const ref: TReference; l : TAsmLabel);
      var
        tmpref  : TReference;
      begin
        tmpref:=ref;
        make_simple_ref(list,tmpref);
        check_register_size(size,reg);
        cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
        list.concat(TAICPU.op_reg_ref(A_CMP,TCgSize2OpSize[size],reg,tmpref));
        a_jmp_cond(list,cmp_op,l);
        cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
      end;


    procedure TCGX86.a_jmp_cond(list : TAsmList;cond : TOpCmp;l: TAsmLabel);
      var
        ai : TAICPU;
      begin
        if cond=OC_None then
          ai := TAICPU.Op_sym(A_JMP,S_NO,l)
        else
          begin
            ai:=TAICPU.Op_sym(A_Jcc,S_NO,l);
            ai.SetCondition(TOpCmp2AsmCond[cond]);
          end;
        ai.is_jmp:=true;
        list.concat(ai);
      end;


     procedure TCGX86.A_Jmp_Flags(list : TAsmList;const f : TResFlags;l: TAsmLabel);
       var
         ai : TAICPU;
         hl : TAsmLabel;
         f2 : TResFlags;
       begin
         hl:=nil;
         f2:=f;
         case f of
           F_FNE:
             begin
               ai:=TAICPU.op_sym(A_Jcc,S_NO,l);
               ai.SetCondition(C_P);
               ai.is_jmp:=true;
               list.concat(ai);
               f2:=F_NE;
             end;
           F_FE,F_FA,F_FAE,F_FB,F_FBE:
             begin
               { JP before JA/JAE is redundant, but it must be generated here
                 and left for peephole optimizer to remove. }
               CurrentAsmData.getjumplabel(hl);
               ai:=TAICPU.op_sym(A_Jcc,S_NO,hl);
               ai.SetCondition(C_P);
               ai.is_jmp:=true;
               list.concat(ai);
               f2:=FPUFlags2Flags[f];
             end;
           else
             ;
         end;
         ai := TAICPU.op_sym(A_Jcc,S_NO,l);
         ai.SetCondition(flags_to_cond(f2));
         ai.is_jmp := true;
         list.concat(ai);
         if Assigned(hl) then
           A_Label(list,hl);
       end;


    procedure TCGX86.G_Flags2Reg(list: TAsmList; size: TCgSize; const f: TResFlags; reg: TRegister);
      var
        ai : TAICPU;
        f2 : TResFlags;
        hreg,hreg2 : TRegister;
        op: TAsmOp;
      begin
        hreg2:=NR_NO;
        op:=A_AND;
        f2:=f;
        case f of
          F_FE,F_FNE,F_FB,F_FBE:
            begin
              hreg2:=GetIntRegister(list,OS_8);
              ai:=TAICPU.op_reg(A_SETcc,S_B,hreg2);
              if (f=F_FNE) then       { F_FNE means "PF or (not ZF)" }
                begin
                  ai.setcondition(C_P);
                  op:=A_OR;
                end
              else
                ai.setcondition(C_NP);
              list.concat(ai);
              f2:=FPUFlags2Flags[f];
            end;
          F_FA,F_FAE:                 { These do not need PF check }
            f2:=FPUFlags2Flags[f];
          else
            ;
        end;
        hreg:=MakeRegSize(list,reg,OS_8);
        ai:=TAICPU.op_reg(A_SETcc,S_B,hreg);
        ai.setcondition(flags_to_cond(f2));
        list.concat(ai);
        if (hreg2<>NR_NO) then
          list.concat(TAICPU.op_reg_reg(op,S_B,hreg2,hreg));
        if reg<>hreg then
          A_Load_Reg_Reg(list,OS_8,size,hreg,reg);
      end;


    procedure TCGX86.G_Flags2Ref(list: TAsmList; size: TCgSize; const f: TResFlags; const ref: TReference);
      var
        ai : TAICPU;
        tmpref  : TReference;
        f2 : TResFlags;
      begin
        f2:=f;
        case f of
          F_FE,F_FNE,F_FB,F_FBE:
            begin
              inherited G_Flags2Ref(list,size,f,ref);
              exit;
            end;
          F_FA,F_FAE:
            f2:=FPUFlags2Flags[f];
          else
            ;
        end;
         tmpref:=ref;
         make_simple_ref(list,tmpref);
         if not(size in [OS_8,OS_S8]) then
           A_Load_Const_Ref(list,size,0,tmpref);
         ai:=TAICPU.op_ref(A_SETcc,S_B,tmpref);
         ai.setcondition(flags_to_cond(f2));
         list.concat(ai);
{$ifndef cpu64bitalu}
         if size in [OS_S64,OS_64] then
           begin
             inc(tmpref.Offset,4);
             A_Load_Const_Ref(list,OS_32,0,tmpref);
           end;
{$endif cpu64bitalu}
      end;


    class function TCGX86.getcopymode(len: TCGInt): TCopyMode;
      const
{$if defined(cpu64bitalu)}
        copy_len_sizes = [1, 2, 4, 8];
{$elseif defined(cpu32bitalu)}
        copy_len_sizes = [1, 2, 4];
{$endif}
      var
        helpsize: TCGInt;
      begin
        result:=copy_mov;
        helpsize:=3*sizeof(aword);
        if cs_opt_size in CurrentSettings.OptimizerSwitches then
          helpsize:=2*sizeof(aword);

        { avx helps only to reduce size, using it in general does at least not help on
          an i7-4770
          but using the xmm registers reduces register pressure (FK) }
        if (FPUX86_HAS_AVXUNIT in fpu_capabilities[CurrentSettings.FPUType]) and
          ((len mod 4)=0) and (len<=48) {$ifndef i386}and (len>=16){$endif i386} then
          result:=copy_avx
        else if (FPUX86_HAS_AVX512F in fpu_capabilities[CurrentSettings.FPUType]) and
          ((len mod 4)=0) and (len<=128) {$ifndef i386}and (len>=16){$endif i386} then
          result:=copy_avx512
        else
        { I'am not sure what CPUs would benefit from using sse instructions for moves
          but using the xmm registers reduces register pressure (FK) }
        if
  {$ifdef x86_64}
          ((CurrentSettings.FPUType>=fpu_sse64)
  {$else x86_64}
          ((CurrentSettings.FPUType>=fpu_sse)
  {$endif x86_64}
            or (CPUX86_HAS_SSE2 in cpu_capabilities[CurrentSettings.CPUType])) and
           ({$ifdef i386}(len=8) or {$endif i386}(len=16) or (len=24) or (len=32) or (len=40) or (len=48)) then
           result:=copy_mm
        else

        if (cs_mmx in CurrentSettings.LocalSwitches) and
           not(pi_uses_fpu in CurrentProcInfo.flags) and
           ({$ifdef i386}(len=8) or {$endif i386}(len=16) or (len=24) or (len=32)) then
          result:=copy_mmx
        else
          if len>helpsize then
            result:=copy_string;

        if (result=copy_string) and not(CPUX86_HINT_FAST_SHORT_REP_MOVS in cpu_optimization_hints[CurrentSettings.OptimizeCPUType]) and
          { we can use the move variant only if the subroutine does another call }
          (pi_do_call in CurrentProcInfo.flags) then
          result:=copy_fpc_move;

        if (cs_opt_size in CurrentSettings.OptimizerSwitches) and
           not((len<=16) and (result in [copy_mmx,copy_mm,copy_avx])) and
           not(len in copy_len_sizes) then
          result:=copy_string;
      end;


{ ************* concatcopy ************ }

    procedure TCGX86.G_ConcatCopy(list:TAsmList;const source,dest:TReference;len:TCGInt);

    const
{$if defined(cpu64bitalu)}
        REGCX=NR_RCX;
        REGSI=NR_RSI;
        REGDI=NR_RDI;
        push_segment_size = S_L;
{$elseif defined(cpu32bitalu)}
        REGCX=NR_ECX;
        REGSI=NR_ESI;
        REGDI=NR_EDI;
        push_segment_size = S_L;
{$endif}

    var
      srcref,dstref,tmpref:TReference;
      r,r0,r1,r2,r3:TRegister;
      copysize:byte;
      cgsize:TCgSize;
      cm:TCopyMode;
      saved_ds,saved_es: Boolean;
      hlist: TAsmList;
      helpsize: TCGInt;
    begin
      srcref:=source;
      dstref:=dest;

      make_simple_ref(list,srcref);
      make_simple_ref(list,dstref);

{$ifdef i386}
      { we could handle "far" pointers here, but reloading es/ds is probably much slower
        than just resolving the tls segment }
      if (srcref.RefAddr=addr_ntpoff) and (srcref.Segment=NR_GS) then
        begin
          r:=GetAddressRegister(list);
          A_LoadAddr_Ref_Reg(list,srcref,r);
          Reference_Reset(srcref,srcref.Alignment,srcref.Volatility);
          srcref.Base:=r;
        end;
       if (dstref.RefAddr=addr_ntpoff) and (dstref.Segment=NR_GS) then
         begin
           r:=GetAddressRegister(list);
           A_LoadAddr_Ref_Reg(list,dstref,r);
           Reference_Reset(dstref,dstref.Alignment,dstref.Volatility);
           dstref.Base:=r;
         end;
{$endif i386}
{$ifdef x86_64}
      { we could handle "far" pointers here, but reloading es/ds is probably much slower
        than just resolving the tls segment }
      if (srcref.RefAddr=addr_tpoff) and (srcref.Segment=NR_FS) then
        begin
          r:=GetAddressRegister(list);
          A_LoadAddr_Ref_Reg(list,srcref,r);
          Reference_Reset(srcref,srcref.Alignment,srcref.Volatility);
          srcref.Base:=r;
        end;
       if (dstref.RefAddr=addr_tpoff) and (dstref.Segment=NR_FS) then
         begin
           r:=GetAddressRegister(list);
           A_LoadAddr_Ref_Reg(list,dstref,r);
           Reference_Reset(dstref,dstref.Alignment,dstref.Volatility);
           dstref.Base:=r;
         end;
{$endif x86_64}
      cm:=getcopymode(len);

      { using %fs and %gs as segment prefixes is perfectly valid }
      if ((srcref.Segment<>NR_NO) and (srcref.Segment<>NR_FS) and (srcref.Segment<>NR_GS)) or
         ((dstref.Segment<>NR_NO) and (dstref.Segment<>NR_FS) and (dstref.Segment<>NR_GS)) then
        cm:=copy_string;

      case cm of
        copy_mov:
          begin
            copysize:=sizeof(aint);
            cgsize:=Int_CGSize(copysize);
            while len<>0 do
              begin
                if len<2 then
                  begin
                    copysize:=1;
                    cgsize:=OS_8;
                  end
                else if len<4 then
                  begin
                    copysize:=2;
                    cgsize:=OS_16;
                  end
{$if defined(cpu32bitalu) or defined(cpu64bitalu)}
                else if len<8 then
                  begin
                    copysize:=4;
                    cgsize:=OS_32;
                  end
{$endif cpu32bitalu or cpu64bitalu}
{$ifdef cpu64bitalu}
                else if len<16 then
                  begin
                    copysize:=8;
                    cgsize:=OS_64;
                  end
{$endif}
                ;
                dec(len,copysize);
                r:=GetIntRegister(list,cgsize);
                A_Load_Ref_Reg(list,cgsize,cgsize,srcref,r);
                A_Load_Reg_Ref(list,cgsize,cgsize,r,dstref);
                inc(srcref.Offset,copysize);
                inc(dstref.Offset,copysize);
              end;
          end;

        copy_mmx:
          begin
            r0:=GetMMXRegister(list);
            r1:=NR_NO;
            r2:=NR_NO;
            r3:=NR_NO;
            A_LoadMM_Ref_Reg(list,OS_M64,OS_M64,srcref,r0,nil);
            if len>=16 then
              begin
                inc(srcref.Offset,8);
                r1:=GetMMXRegister(list);
                A_LoadMM_Ref_Reg(list,OS_M64,OS_M64,srcref,r1,nil);
              end;
            if len>=24 then
              begin
                inc(srcref.Offset,8);
                r2:=GetMMXRegister(list);
                A_LoadMM_Ref_Reg(list,OS_M64,OS_M64,srcref,r2,nil);
              end;
            if len>=32 then
              begin
                inc(srcref.Offset,8);
                r3:=GetMMXRegister(list);
                A_LoadMM_Ref_Reg(list,OS_M64,OS_M64,srcref,r3,nil);
              end;
            A_LoadMM_Reg_Ref(list,OS_M64,OS_M64,r0,dstref,nil);
            if len>=16 then
              begin
                inc(dstref.Offset,8);
                A_LoadMM_Reg_Ref(list,OS_M64,OS_M64,r1,dstref,nil);
              end;
            if len>=24 then
              begin
                inc(dstref.Offset,8);
                A_LoadMM_Reg_Ref(list,OS_M64,OS_M64,r2,dstref,nil);
              end;
            if len>=32 then
              begin
                inc(dstref.Offset,8);
                A_LoadMM_Reg_Ref(list,OS_M64,OS_M64,r3,dstref,nil);
              end;
          end;

        copy_mm:
          begin
            r0:=NR_NO;
            r1:=NR_NO;
            r2:=NR_NO;
            r3:=NR_NO;
            if len>=16 then
              begin
                r0:=GetMMRegister(list,OS_M128);
                A_LoadMM_Ref_Reg(list,OS_M128,OS_M128,srcref,r0,nil);
                inc(srcref.Offset,16);
              end;
            if len>=32 then
              begin
                r1:=GetMMRegister(list,OS_M128);
                A_LoadMM_Ref_Reg(list,OS_M128,OS_M128,srcref,r1,nil);
                inc(srcref.Offset,16);
              end;
            if len>=48 then
              begin
                r2:=GetMMRegister(list,OS_M128);
                A_LoadMM_Ref_Reg(list,OS_M128,OS_M128,srcref,r2,nil);
                inc(srcref.Offset,16);
              end;
            if (len=8) or (len=24) or (len=40) then
              begin
                r3:=GetMMRegister(list,OS_M64);
                A_LoadMM_Ref_Reg(list,OS_M64,OS_M64,srcref,r3,nil);
              end;

            if len>=16 then
              begin
                A_LoadMM_Reg_Ref(list,OS_M128,OS_M128,r0,dstref,nil);
                inc(dstref.Offset,16);
              end;
            if len>=32 then
              begin
                A_LoadMM_Reg_Ref(list,OS_M128,OS_M128,r1,dstref,nil);
                inc(dstref.Offset,16);
              end;
            if len>=48 then
              begin
                A_LoadMM_Reg_Ref(list,OS_M128,OS_M128,r2,dstref,nil);
                inc(dstref.Offset,16);
              end;
            if (len=8) or (len=24) or (len=40) then
              begin
                A_LoadMM_Reg_Ref(list,OS_M64,OS_M64,r3,dstref,nil);
              end;
          end;

        copy_avx512,
        copy_avx:
          begin
            hlist:=TAsmList.create;
            if cm=copy_avx512 then
              while len>=64 do
                begin
                  r0:=GetMMRegister(list,OS_M512);
                  A_LoadMM_Ref_Reg(list,OS_M512,OS_M512,srcref,r0,nil);
                  A_LoadMM_Reg_Ref(hlist,OS_M512,OS_M512,r0,dstref,nil);
                  inc(srcref.Offset,64);
                  inc(dstref.Offset,64);
                  dec(len,64);
                  Include(CurrentProcInfo.flags,pi_uses_ymm);
                end;
            while len>=32 do
              begin
                r0:=GetMMRegister(list,OS_M256);
                A_LoadMM_Ref_Reg(list,OS_M256,OS_M256,srcref,r0,nil);
                A_LoadMM_Reg_Ref(hlist,OS_M256,OS_M256,r0,dstref,nil);
                inc(srcref.Offset,32);
                inc(dstref.Offset,32);
                dec(len,32);
                Include(CurrentProcInfo.flags,pi_uses_ymm);
              end;
            while len>=16 do
              begin
                r0:=GetMMRegister(list,OS_M128);
                A_LoadMM_Ref_Reg(list,OS_M128,OS_M128,srcref,r0,nil);
                A_LoadMM_Reg_Ref(hlist,OS_M128,OS_M128,r0,dstref,nil);
                inc(srcref.Offset,16);
                inc(dstref.Offset,16);
                dec(len,16);
              end;
            if len>=8 then
              begin
                r0:=GetMMRegister(list,OS_M64);
                A_LoadMM_Ref_Reg(list,OS_M64,OS_M64,srcref,r0,nil);
                A_LoadMM_Reg_Ref(hlist,OS_M64,OS_M64,r0,dstref,nil);
                inc(srcref.Offset,8);
                inc(dstref.Offset,8);
                dec(len,8);
              end;
            if len>=4 then
              begin
                r0:=GetIntRegister(list,OS_32);
                A_Load_Ref_Reg(list,OS_32,OS_32,srcref,r0);
                A_Load_Reg_Ref(hlist,OS_32,OS_32,r0,dstref);
                inc(srcref.Offset,4);
                inc(dstref.Offset,4);
                dec(len,4);
              end;
            list.ConcatList(hlist);
            hlist.free;
          end;

        copy_string:
          begin
            GetCPURegister(list,REGDI);
            if (dstref.Segment=NR_NO) and
               (segment_regs_equal(NR_SS,NR_DS) or ((dstref.Base<>NR_BP) and (dstref.Base<>NR_SP))) then
              begin
                A_LoadAddr_Ref_Reg(list,dstref,REGDI);
                saved_es:=false;
{$ifdef volatile_es}
                list.concat(TAICPU.op_reg(A_PUSH,push_segment_size,NR_DS));
                list.concat(TAICPU.op_reg(A_POP,push_segment_size,NR_ES));
{$endif volatile_es}
              end
            else
              begin
                { load offset of dest. reference }
                tmpref:=dstref;
                tmpref.Segment:=NR_NO;
                A_LoadAddr_Ref_Reg(list,tmpref,REGDI);
{$ifdef volatile_es}
                saved_es:=false;
{$else volatile_es}
                list.concat(TAICPU.op_reg(A_PUSH,push_segment_size,NR_ES));
                saved_es:=true;
{$endif volatile_es}
                if dstref.Segment<>NR_NO then
                  list.concat(TAICPU.op_reg(A_PUSH,push_segment_size,dstref.Segment))
                else if (dstref.Base=NR_BP) or (dstref.Base=NR_SP) then
                  list.concat(TAICPU.op_reg(A_PUSH,push_segment_size,NR_SS))
                else
                  InternalError(2014040401);
                list.concat(TAICPU.op_reg(A_POP,push_segment_size,NR_ES));
              end;
            GetCPURegister(list,REGSI);

            if ((srcref.Segment=NR_NO) and (segment_regs_equal(NR_SS,NR_DS) or ((srcref.Base<>NR_BP) and (srcref.Base<>NR_SP)))) or
               (is_segment_reg(srcref.Segment) and segment_regs_equal(srcref.Segment,NR_DS)) then
              begin
                srcref.Segment:=NR_NO;
                A_LoadAddr_Ref_Reg(list,srcref,REGSI);
                saved_ds:=false;
              end
            else
              begin
                { load offset of source reference }
                tmpref:=srcref;
                tmpref.Segment:=NR_NO;
                A_LoadAddr_Ref_Reg(list,tmpref,REGSI);
                list.concat(TAICPU.op_reg(A_PUSH,push_segment_size,NR_DS));
                saved_ds:=true;
                if srcref.Segment<>NR_NO then
                  list.concat(TAICPU.op_reg(A_PUSH,push_segment_size,srcref.Segment))
                else if (srcref.Base=NR_BP) or (srcref.Base=NR_SP) then
                  list.concat(TAICPU.op_reg(A_PUSH,push_segment_size,NR_SS))
                else
                  InternalError(2014040402);
                list.concat(TAICPU.op_reg(A_POP,push_segment_size,NR_DS));
              end;

            GetCPURegister(list,REGCX);
            if ts_cld in CurrentSettings.TargetSwitches then
              list.concat(TAICPU.op_none(A_CLD,S_NO));
            if ((cs_opt_size in CurrentSettings.OptimizerSwitches) and
               (len>sizeof(aint)+(sizeof(aint) div 2))) or
               ((len<=128) and (CPUX86_HINT_FAST_SHORT_REP_MOVS in cpu_optimization_hints[CurrentSettings.OptimizeCPUType])) then
              begin
                A_Load_Const_Reg(list,OS_INT,len,REGCX);
                list.concat(TAICPU.op_none(A_REP,S_NO));
                list.concat(TAICPU.op_none(A_MOVSB,S_NO));
              end
            else
              begin
                helpsize:=len div sizeof(aint);
                len:=len mod sizeof(aint);
                if helpsize>1 then
                  begin
                    A_Load_Const_Reg(list,OS_INT,helpsize,REGCX);
                    list.concat(TAICPU.op_none(A_REP,S_NO));
                  end;
                if helpsize>0 then
                  begin
{$if defined(cpu64bitalu)}
                    list.concat(TAICPU.op_none(A_MOVSQ,S_NO))
{$elseif defined(cpu32bitalu)}
                    list.concat(TAICPU.op_none(A_MOVSD,S_NO));
{$endif}
                  end;
                if len>=4 then
                  begin
                    dec(len,4);
                    list.concat(TAICPU.op_none(A_MOVSD,S_NO));
                  end;
                if len>=2 then
                  begin
                    dec(len,2);
                    list.concat(TAICPU.op_none(A_MOVSW,S_NO));
                  end;
                if len=1 then
                  list.concat(TAICPU.op_none(A_MOVSB,S_NO));
              end;
            UngetCPURegister(list,REGCX);
            UngetCPURegister(list,REGSI);
            UngetCPURegister(list,REGDI);
            if saved_ds then
              list.concat(TAICPU.op_reg(A_POP,push_segment_size,NR_DS));
            if saved_es then
              list.concat(TAICPU.op_reg(A_POP,push_segment_size,NR_ES));
          end
        else
          { copy by using move, should be a good fallback in all other cases }
          G_ConcatCopy_Move(list,source,dest,len);
        end;
    end;


{****************************************************************************
                              Entry/Exit Code Helpers
****************************************************************************}

    procedure TCGX86.G_StackPointer_Alloc(list : TAsmList;localsize : LongInt);

      procedure decrease_sp(a : TCGInt);
        var
          href : TReference;
        begin
{$ifdef x86_64}
          if localsize=8 then
            list.concat(TAICPU.op_reg(A_PUSH,TCGSize2OpSize[OS_ADDR],NR_RAX))
          else
{$endif x86_64}
            begin
              Reference_Reset_Base(href,NR_STACK_POINTER_REG,-a,CTempPosInvalid,0,[]);
              { normally, lea is a better choice than a sub to adjust the stack pointer }
              list.concat(TAICPU.op_ref_reg(A_LEA,TCGSize2OpSize[OS_ADDR],href,NR_STACK_POINTER_REG));
            end;
        end;

{$ifdef x86}
{$ifndef NOTARGETWIN}

      var
        href : TReference;
        i : integer;
        again : TAsmLabel;

{$endif NOTARGETWIN}
{$endif x86}
      begin
        if localsize>0 then
         begin
{$ifdef i386}
{$ifndef NOTARGETWIN}
           { windows guards only a few pages for stack growing,
             so we have to access every page first              }
           if (TargetInfo.system=system_i386_win32) and
              (localsize>=winstackpagesize) then
             begin
               if localsize div winstackpagesize<=5 then
                 begin
                    decrease_sp(localsize-4);
                    for i:=1 to localsize div winstackpagesize do
                      begin
                         Reference_Reset_Base(href,NR_ESP,localsize-i*winstackpagesize,CTempPosInvalid,4,[]);
                         list.concat(TAICPU.op_reg_ref(A_MOV,S_L,NR_EAX,href));
                      end;
                    list.concat(TAICPU.op_reg(A_PUSH,S_L,NR_EAX));
                 end
               else
                 begin
                    CurrentAsmData.getjumplabel(again);
                    { Using a_reg_alloc instead of getcpuregister, so this procedure
                      does not change "used_in_proc" state of EDI and therefore can be
                      called after saving registers with "push" instruction
                      without creating an unbalanced "pop edi" in epilogue }
                    A_Reg_Alloc(list,NR_EDI);
                    list.concat(TAICPU.op_reg(A_PUSH,S_L,NR_EDI));
                    list.concat(TAICPU.op_const_reg(A_MOV,S_L,localsize div winstackpagesize,NR_EDI));
                    A_Label(list,again);
                    decrease_sp(winstackpagesize-4);
                    list.concat(TAICPU.op_reg(A_PUSH,S_L,NR_EAX));
                    if UseIncDec then
                      list.concat(TAICPU.op_reg(A_DEC,S_L,NR_EDI))
                    else
                      list.concat(TAICPU.op_const_reg(A_SUB,S_L,1,NR_EDI));
                    a_jmp_cond(list,OC_NE,again);
                    decrease_sp(localsize mod winstackpagesize-4);
                    Reference_Reset_Base(href,NR_ESP,localsize-4,CTempPosInvalid,4,[]);
                    list.concat(TAICPU.op_ref_reg(A_MOV,S_L,href,NR_EDI));
                    A_Reg_Dealloc(list,NR_EDI);
                 end
             end
           else
{$endif NOTARGETWIN}
{$endif i386}
{$ifdef x86_64}
{$ifndef NOTARGETWIN}
           { windows guards only a few pages for stack growing,
             so we have to access every page first              }
           if (TargetInfo.system=system_x86_64_win64) and
              (localsize>=winstackpagesize) then
             begin
               if localsize div winstackpagesize<=5 then
                 begin
                    decrease_sp(localsize);
                    for i:=1 to localsize div winstackpagesize do
                      begin
                         Reference_Reset_Base(href,NR_RSP,localsize-i*winstackpagesize+4,CTempPosInvalid,4,[]);
                         list.concat(TAICPU.op_reg_ref(A_MOV,S_L,NR_EAX,href));
                      end;
                    Reference_Reset_Base(href,NR_RSP,0,CTempPosInvalid,4,[]);
                    list.concat(TAICPU.op_reg_ref(A_MOV,S_L,NR_EAX,href));
                 end
               else
                 begin
                    CurrentAsmData.getjumplabel(again);
                    GetCPURegister(list,NR_R10);
                    list.concat(TAICPU.op_const_reg(A_MOV,S_Q,localsize div winstackpagesize,NR_R10));
                    A_Label(list,again);
                    decrease_sp(winstackpagesize);
                    Reference_Reset_Base(href,NR_RSP,0,CTempPosInvalid,4,[]);
                    list.concat(TAICPU.op_reg_ref(A_MOV,S_L,NR_EAX,href));
                    if UseIncDec then
                      list.concat(TAICPU.op_reg(A_DEC,S_Q,NR_R10))
                    else
                      list.concat(TAICPU.op_const_reg(A_SUB,S_Q,1,NR_R10));
                    a_jmp_cond(list,OC_NE,again);
                    decrease_sp(localsize mod winstackpagesize);
                    UngetCPURegister(list,NR_R10);
                 end
             end
           else
{$endif NOTARGETWIN}
{$endif x86_64}
            decrease_sp(localsize);
         end;
      end;


    procedure TCGX86.G_Proc_Entry(list : TAsmList;localsize : LongInt;nostackframe:boolean);
      var
        stackmisalignment: LongInt;
        regsize: LongInt;


      procedure push_regs;
        var
          r: LongInt;
          usedregs: TCPURegisterSet;
          regs_to_save_int: TCPURegisterArray;
          hreg: TRegister;
        begin
          regsize:=0;
          usedregs:=rg[R_INTREGISTER].UsedInProc-ParaManager.Get_Volatile_Registers_Int(CurrentProcInfo.procdef.ProcCallOption);
          regs_to_save_int:=ParaManager.Get_Saved_Registers_Int(CurrentProcInfo.procdef.ProcCallOption);
          for r := low(regs_to_save_int) to high(regs_to_save_int) do
            if regs_to_save_int[r] in usedregs then
              begin
                inc(regsize,sizeof(aint));
                hreg:=NewReg(R_INTREGISTER,regs_to_save_int[r],R_SUBWHOLE);
                list.concat(TAICPU.Op_reg(A_PUSH,tcgsize2opsize[OS_ADDR],hreg));
                if CurrentProcInfo.framepointer<>NR_STACK_POINTER_REG then
                  CurrentAsmData.asmcfi.cfa_offset(list,hreg,-(regsize+sizeof(PInt)*2+localsize))
                else
                  begin
                    CurrentAsmData.asmcfi.cfa_offset(list,hreg,-(regsize+sizeof(PInt)+localsize));
                    CurrentAsmData.asmcfi.cfa_def_cfa_offset(list,regsize+localsize+sizeof(PInt));
                  end;
              end;
        end;

      begin
        regsize:=0;
        stackmisalignment:=0;
        list.concat(TAIRegAlloc.alloc(NR_STACK_POINTER_REG,nil));

{$ifdef i386}
        { interrupt support for i386 }
        if (po_interrupt in CurrentProcInfo.procdef.ProcOptions) then
          begin
            { .... also the segment registers }
            list.concat(TAICPU.Op_reg(A_PUSH,S_W,NR_GS));
            list.concat(TAICPU.Op_reg(A_PUSH,S_W,NR_FS));
            list.concat(TAICPU.Op_reg(A_PUSH,S_W,NR_ES));
            list.concat(TAICPU.Op_reg(A_PUSH,S_W,NR_DS));
            { save the registers of an interrupt procedure }
            list.concat(TAICPU.Op_reg(A_PUSH,S_L,NR_EDI));
            list.concat(TAICPU.Op_reg(A_PUSH,S_L,NR_ESI));
            list.concat(TAICPU.Op_reg(A_PUSH,S_L,NR_EDX));
            list.concat(TAICPU.Op_reg(A_PUSH,S_L,NR_ECX));
            list.concat(TAICPU.Op_reg(A_PUSH,S_L,NR_EBX));
            list.concat(TAICPU.Op_reg(A_PUSH,S_L,NR_EAX));
            { pushf, push %cs, 4*selector registers, 6*general purpose registers }
            inc(stackmisalignment,4+4+4*2+6*4);
          end;
{$endif i386}

        { save old framepointer }
        if not nostackframe then
          begin
            { return address }
            inc(stackmisalignment,sizeof(PInt));
            if CurrentProcInfo.framepointer=NR_STACK_POINTER_REG then
              begin
{$ifdef i386}
                if (not ParaManager.Use_Fixed_Stack) then
                  push_regs;
{$endif i386}
                CGMessage(cg_d_stackframe_omited);
              end
            else
              begin
                list.concat(TAIRegAlloc.alloc(CurrentProcInfo.framepointer,nil));

                { push <frame_pointer> }
                inc(stackmisalignment,sizeof(PInt));
                include(rg[R_INTREGISTER].PreservedByProc,RS_FRAME_POINTER_REG);
                list.concat(TAICPU.op_reg(A_PUSH,tcgsize2opsize[OS_ADDR],NR_FRAME_POINTER_REG));
                { Return address and FP are both on stack }
                CurrentAsmData.asmcfi.cfa_def_cfa_offset(list,2*sizeof(PInt));
                CurrentAsmData.asmcfi.cfa_offset(list,NR_FRAME_POINTER_REG,-(2*sizeof(PInt)));
                if CurrentProcInfo.procdef.ProcTypeOption<>potype_exceptfilter then
                  list.concat(TAICPU.op_reg_reg(A_MOV,tcgsize2opsize[OS_ADDR],NR_STACK_POINTER_REG,NR_FRAME_POINTER_REG))
                else
                  begin
                    push_regs;
                    gen_load_frame_for_exceptfilter(list);
                    { Need only as much stack space as necessary to do the calls.
                      Exception filters don't have own local vars, and temps are 'mapped'
                      to the parent procedure.
                      maxpushedparasize is already aligned at least on x86_64. }
                    localsize:=CurrentProcInfo.maxpushedparasize;
                  end;
                CurrentAsmData.asmcfi.cfa_def_cfa_register(list,NR_FRAME_POINTER_REG);
              end;

            { allocate stackframe space }
            if (localsize<>0) or
               ((TargetInfo.stackalign>sizeof(PInt)) and
                (stackmisalignment <> 0) and
                ((pi_do_call in CurrentProcInfo.flags) or
                 (po_assembler in CurrentProcInfo.procdef.ProcOptions))) then
              begin
                if TargetInfo.stackalign>sizeof(PInt) then
                  localsize := align(localsize+stackmisalignment,TargetInfo.stackalign)-stackmisalignment;
                G_StackPointer_Alloc(list,localsize);
                if CurrentProcInfo.framepointer=NR_STACK_POINTER_REG then
                  CurrentAsmData.asmcfi.cfa_def_cfa_offset(list,regsize+localsize+sizeof(PInt));
                CurrentProcInfo.final_localsize:=localsize;
              end

              ;



{$ifdef i386}
            if (not ParaManager.Use_Fixed_Stack) and
               (CurrentProcInfo.framepointer<>NR_STACK_POINTER_REG) and
               (CurrentProcInfo.procdef.ProcTypeOption<>potype_exceptfilter) then
              begin
                regsize:=0;
                push_regs;
                Reference_Reset_Base(CurrentProcInfo.save_regs_ref,
                  CurrentProcInfo.framepointer,
                  -(localsize+regsize),CTempPosInvalid,sizeof(aint),[]);
              end;
{$endif i386}
          end;
      end;


    procedure TCGX86.G_Save_Registers(list: TAsmList);
      begin
{$ifdef i386}
        if ParaManager.Use_Fixed_Stack then
{$endif i386}
          inherited G_Save_Registers(list);
      end;


    procedure TCGX86.G_Restore_Registers(list: TAsmList);
      begin
{$ifdef i386}
        if ParaManager.Use_Fixed_Stack then
{$endif i386}
          inherited G_Restore_Registers(list);
      end;


    procedure TCGX86.internal_restore_regs(list: TAsmList; use_pop: boolean);
      var
        r: LongInt;
        hreg: TRegister;
        href: TReference;
        usedregs: TCPURegisterSet;
        regs_to_save_int: TCPURegisterArray;
      begin
        href:=CurrentProcInfo.save_regs_ref;
        usedregs:=rg[R_INTREGISTER].UsedInProc-ParaManager.Get_Volatile_Registers_Int(CurrentProcInfo.procdef.ProcCallOption);
        regs_to_save_int:=ParaManager.Get_Saved_Registers_Int(CurrentProcInfo.procdef.ProcCallOption);
        for r:=high(regs_to_save_int) downto low(regs_to_save_int) do
          if regs_to_save_int[r] in usedregs then
            begin
              hreg:=NewReg(R_INTREGISTER,regs_to_save_int[r],R_SUBWHOLE);
              { Allocate register so the optimizer does not remove the load }
              A_Reg_Alloc(list,hreg);
              if use_pop then
                list.concat(TAICPU.Op_reg(A_POP,tcgsize2opsize[OS_ADDR],hreg))
              else
                begin
                  A_Load_Ref_Reg(list,OS_ADDR,OS_ADDR,href,hreg);
                  inc(href.Offset,sizeof(aint));
                end;
              CurrentAsmData.asmcfi.cfa_restore(list,hreg);
            end;
      end;


    procedure TCGX86.generate_leave(list: TAsmList);
      begin
        if UseLeave then
          list.concat(TAICPU.op_none(A_LEAVE,S_NO))
        else
          begin
{$if defined(x86_64)}
            CurrentAsmData.asmcfi.cfa_def_cfa_register(list,NR_RSP);
            list.Concat(TAICPU.op_reg_reg(A_MOV,S_Q,NR_RBP,NR_RSP));
            CurrentAsmData.asmcfi.cfa_restore(list,NR_RBP);
            CurrentAsmData.asmcfi.cfa_def_cfa_offset(list,8);
            list.Concat(TAICPU.op_reg(A_POP,S_Q,NR_RBP));
{$elseif defined(i386)}
            CurrentAsmData.asmcfi.cfa_def_cfa_register(list,NR_ESP);
            list.Concat(TAICPU.op_reg_reg(A_MOV,S_L,NR_EBP,NR_ESP));
            CurrentAsmData.asmcfi.cfa_restore(list,NR_EBP);
            CurrentAsmData.asmcfi.cfa_def_cfa_offset(list,4);
            list.Concat(TAICPU.op_reg(A_POP,S_L,NR_EBP));
{$endif}
          end;
      end;


    { produces if necessary overflowcode }
    procedure TCGX86.G_OverflowCheck(list: TAsmList; const l:TLocation;def:TDef);
      var
         hl : TAsmLabel;
         ai : TAICPU;
         cond : TAsmCond;
      begin
         if not(cs_check_overflow in CurrentSettings.LocalSwitches) then
          exit;
         CurrentAsmData.getjumplabel(hl);
         if not ((def.typ=pointerdef) or
                ((def.typ=orddef) and
                 (TOrdDef(def).OrdType in [u64bit,u16bit,u32bit,u8bit,uchar,
                                           pasbool1,pasbool8,pasbool16,pasbool32,pasbool64]))) then
           cond:=C_NO
         else
           cond:=C_NB;
         ai:=TAICPU.Op_Sym(A_Jcc,S_NO,hl);
         ai.SetCondition(cond);
         ai.is_jmp:=true;
         list.concat(ai);

         A_Reg_Dealloc(list, NR_DEFAULTFLAGS);
         A_Call_Name(list,'FPC_OVERFLOW',false);
         A_Label(list,hl);
      end;

end.
