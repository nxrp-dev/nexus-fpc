{
    Copyright (c) 2014 by Jonas Maebe

    This unit implements the code generator for AArch64

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
unit cgcpu;

{$i fpcdefs.inc}

interface

    uses
       GlobType,parabase,
       cgbase,cgutils,cgobj,
       aasmbase,aasmtai,AAsmData,aasmcpu,
       cpubase,CPUInfo,
       node,symconst,SymType,symdef,
       rgcpu;

    type

      { tcgaarch64 }

      TCGAArch64=class(TCG)
       protected
        { changes register size without adding register allocation info }
        function MakeRegSize(reg: TRegister; size: TCgSize): TRegister; overload;
       public
        { simplifies "ref" so it can be used with "op". If "ref" can be used
          with a different load/Store operation that has the same meaning as the
          original one, "op" will be replaced with the alternative }
        procedure make_simple_ref(list:TAsmList; var op: TAsmOp; size: TCgSize; oppostfix: TOpPostfix; var ref: TReference; preferred_newbasereg: TRegister);
        function GetFPURegister(list: TAsmList; size: TCgSize): TRegister; override;
        procedure handle_reg_imm12_reg(list: TAsmList; op: TAsmOp; size: TCgSize; src: TRegister; a: TCGInt; dst: TRegister; tmpreg: TRegister; setflags, usedest: boolean);
        procedure Init_Register_Allocators;override;
        procedure Done_Register_Allocators;override;
        function  GetMMRegister(list:TAsmList;size:TCgSize):TRegister;override;
        function handle_load_store(list:TAsmList; op: TAsmOp; size: TCgSize; oppostfix: TOpPostfix; reg: TRegister; ref: TReference):TReference;
        procedure A_Call_Name(list:TAsmList;const s:string; weak: boolean);override;
        procedure A_Call_Reg(list:TAsmList;Reg:TRegister);override;
        { General purpose instructions }
        procedure maybeadjustresult(list: TAsmList; op: TOpCG; size: TCgSize; dst: TRegister);
        procedure A_Op_Const_Reg(list: TAsmList; op: TOpCG; size: TCgSize; a: TCGInt; reg: TRegister);override;
        procedure A_Op_Reg_Reg(list: TAsmList; op: TOpCG; size: TCgSize; src, dst: TRegister);override;
        procedure A_Op_Const_Reg_Reg(list: TAsmList; op: TOpCG; size: TCgSize; a: TCGInt; src, dst: TRegister);override;
        procedure A_Op_Reg_Reg_Reg(list: TAsmList; op: TOpCG; size: TCgSize; src1, src2, dst: TRegister);override;
        procedure A_Op_Const_Reg_Reg_CheckOverflow(list: TAsmList; op: TOpCG; size: TCgSize; a: TCGInt; src, dst: TRegister; setflags : boolean; var ovloc : TLocation);override;
        procedure A_Op_Reg_Reg_Reg_CheckOverflow(list: TAsmList; op: TOpCG; size: TCgSize; src1, src2, dst: TRegister; setflags : boolean; var ovloc : TLocation);override;
        { move instructions }
        procedure A_Load_Const_Reg(list: TAsmList; size: TCgSize; a: TCGInt; reg: TRegister);override;
        procedure A_Load_Const_Ref(list: TAsmList; size: TCgSize; a: TCGInt; const ref: TReference); override;
        procedure A_Load_Reg_Ref(list: TAsmList; fromsize, tosize: TCgSize; reg: TRegister;const ref: TReference);override;
        procedure A_Load_Reg_Ref_Unaligned(list: TAsmList; fromsize, tosize: TCgSize; register: TRegister; const ref: TReference); override;
        procedure A_Load_Ref_Reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; reg: TRegister);override;
        procedure A_Load_Ref_Reg_Unaligned(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; register: TRegister); override;
        procedure A_Load_Reg_Reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister);override;
        procedure A_LoadAddr_Ref_Reg(list: TAsmList; const ref: TReference; r: TRegister);override;
        { fpu move instructions (not used, all floating point is vector unit-based) }
        procedure A_LoadFPU_Reg_Reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister); override;
        procedure A_LoadFPU_Ref_Reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; reg: TRegister); override;
        procedure A_LoadFPU_Reg_Ref(list: TAsmList; fromsize, tosize: TCgSize; reg: TRegister; const ref: TReference); override;
        procedure A_LoadMM_Reg_Reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister;shuffle : PMMShuffle);override;
        procedure A_LoadMM_Ref_Reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; reg: TRegister; shuffle: PMMShuffle);override;
        procedure A_LoadMM_Reg_Ref(list: TAsmList; fromsize, tosize: TCgSize; reg: TRegister; const ref: TReference; shuffle: PMMShuffle);override;

        procedure A_LoadMM_IntReg_Reg(list: TAsmList; fromsize, tosize: TCgSize; intreg, mmreg: TRegister; shuffle: PMMShuffle); override;
        procedure A_LoadMM_Reg_IntReg(list: TAsmList; fromsize, tosize: TCgSize; mmreg, intreg: TRegister; shuffle: PMMShuffle); override;

        procedure A_OpMM_Reg_Reg(list: TAsmList; Op: TOpCG; size: TCgSize; src, dst: TRegister; shuffle: PMMShuffle); override;

        procedure A_Bit_Scan_Reg_Reg(list: TAsmList; reverse,not_zero: boolean; srcsize, dstsize: TCgSize; src, dst: TRegister); override;
        { comparison operations }
        procedure A_Cmp_Const_Reg_Label(list: TAsmList; size: TCgSize; cmp_op: TOpCmp; a: TCGInt; reg: TRegister; l: TAsmLabel);override;
        procedure A_Cmp_Reg_Reg_Label(list: TAsmList; size: TCgSize; cmp_op: TOpCmp; reg1, reg2: TRegister; l: TAsmLabel);override;
        procedure A_Jmp_Always(list: TAsmList; l: TAsmLabel);override;
        procedure A_Jmp_Name(list: TAsmList; const s: string);override;
        procedure a_jmp_cond(list: TAsmList; cond: TOpCmp; l: TAsmLabel);{ override;}
        procedure A_Jmp_Flags(list: TAsmList; const f: TResFlags; l: TAsmLabel);override;
        procedure G_Flags2Reg(list: TAsmList; size: TCgSize; const f:TResFlags; reg: TRegister);override;
        procedure G_OverflowCheck(list: TAsmList; const loc: TLocation; def: TDef);override;
        procedure G_OverflowCheck_Loc(list: TAsmList; const loc: TLocation; def: TDef; ovloc: TLocation);override;
        procedure G_StackPointer_Alloc(list: TAsmList; localsize: LongInt);override;
        procedure G_Proc_Entry(list: TAsmList; localsize: LongInt; nostackframe: boolean);override;
        procedure G_Proc_Exit(list: TAsmList; parasize: LongInt; nostackframe: boolean);override;
        procedure G_Maybe_Got_Init(list: TAsmList); override;
        procedure G_Restore_Registers(list: TAsmList);override;
        procedure G_Save_Registers(list: TAsmList);override;
        procedure G_ConcatCopy(list: TAsmList; const source, dest: TReference; len: TCGInt);override;
        procedure G_Adjust_Self_Value(list: TAsmList; procdef: TProcDef; ioffset: TCGInt);override;
        procedure G_Check_For_FPU_Exception(list: TAsmList; force, clear: boolean);override;
        procedure G_Local_Unwind(list: TAsmList; l: TAsmLabel);override;
        procedure Adjust_ExceptFilter_Ref(var ref: TReference; for_finalization: boolean);override;
       private
        function save_regs(list: TAsmList; rt: TRegisterType; lowsr, highsr: TSuperRegister; sub: TSubRegister): LongInt;
        procedure load_regs(list: TAsmList; rt: TRegisterType; lowsr, highsr: TSuperRegister; sub: TSubRegister);
      end;

    procedure create_codegen;

    const
      TOpCG2AsmOpReg: array[TOpCG] of TAsmOp = (
        A_NONE,A_MOV,A_ADD,A_AND,A_UDIV,A_SDIV,A_MUL,A_MUL,A_NEG,A_MVN,A_ORR,A_ASRV,A_LSLV,A_LSRV,A_SUB,A_EOR,A_NONE,A_RORV
      );
      TOpCG2AsmOpImm: array[TOpCG] of TAsmOp = (
        A_NONE,A_MOV,A_ADD,A_AND,A_UDIV,A_SDIV,A_MUL,A_MUL,A_NEG,A_MVN,A_ORR,A_ASR,A_LSL,A_LSR,A_SUB,A_EOR,A_NONE,A_ROR
      );
      TOpCmp2AsmCond: array[TOpCmp] of TAsmCond = (C_NONE,C_EQ,C_GT,
        C_LT,C_GE,C_LE,C_NE,C_LS,C_CC,C_CS,C_HI
      );

      winstackpagesize = 4096;

implementation

  uses
    Globals,Verbose,Systems,CUtils,CClasses,
    paramgr,FModule,
    SymTable,SymSym,
    tgobj,
    ncgutil,
    ProcInfo,cpupi,psub;


    procedure TCGAArch64.make_simple_ref(list:TAsmList; var op: TAsmOp; size: TCgSize; oppostfix: TOpPostfix; var ref: TReference; preferred_newbasereg: TRegister);
      var
        href: TReference;
        so: TShifterOp;
        accesssize: LongInt;
      begin
        if (ref.Base=NR_NO) then
          begin
            if ref.ShiftMode<>SM_None then
              InternalError(2014110701);
            ref.Base:=ref.Index;
            ref.Index:=NR_NO;
          end;
        { no arbitrary scale factor support (the generic code doesn't set it,
          AArch-specific code shouldn't either) }
        if not(ref.ScaleFactor in [0,1]) then
          InternalError(2014111002);

        case simple_ref_type(op,size,oppostfix,ref) of
          sr_simple:
            exit;
          sr_internal_illegal:
            InternalError(2014121702);
          sr_complex:
            { continue } ;
        end;

        if Assigned(ref.Symbol) then
          begin
            { internal "load symbol" instructions should already be valid }
            if Assigned(ref.SymbolData) or
               (ref.RefAddr in [addr_pic,addr_gotpage,addr_gotpageoffset,addr_page,addr_pageoffset]) then
              InternalError(2014110802);
            { no relative symbol support (needed) yet }
            if Assigned(ref.RelSymbol) then
              InternalError(2014111001);
            { loading a symbol address (whether it's in the GOT or not) consists
              of two parts: first load the page on which it is located, then
              either the offset in the page or load the value at that offset in
              the page. This final GOT-load can be relaxed by the linker in case
              the variable itself can be stored directly in the GOT }
            if (preferred_newbasereg=NR_NO) or
               (ref.Base=preferred_newbasereg) or
               (ref.Index=preferred_newbasereg) then
              preferred_newbasereg:=GetAddressRegister(list);
            { load the (GOT) page }
            Reference_Reset_Symbol(href,ref.Symbol,0,8,[]);
            if ((ref.Symbol.typ in [AT_FUNCTION,AT_LABEL,AT_DATA]) and
                (ref.Symbol.bind in [AB_LOCAL,AB_GLOBAL])) or
               ((ref.Symbol.typ=AT_DATA) and
                (ref.Symbol.bind=AB_LOCAL)) or
               (TargetInfo.system=system_aarch64_win64) then
              href.RefAddr:=addr_page
            else
              href.RefAddr:=addr_gotpage;
            list.concat(TAICPU.op_reg_ref(A_ADRP,preferred_newbasereg,href));
            { load the GOT entry (= address of the variable) }
            Reference_Reset_Base(href,preferred_newbasereg,0,CTempPosInvalid,sizeof(PInt),[]);
            href.Symbol:=ref.Symbol;
            { code symbols defined in the current compilation unit do not
              have to be accessed via the GOT }
            if ((ref.Symbol.typ in [AT_FUNCTION,AT_LABEL,AT_DATA]) and
                (ref.Symbol.bind in [AB_LOCAL,AB_GLOBAL])) or
               ((ref.Symbol.typ=AT_DATA) and
                (ref.Symbol.bind=AB_LOCAL)) or
               (TargetInfo.system=system_aarch64_win64) then
              begin
                href.Base:=NR_NO;
                href.RefAddr:=addr_pageoffset;
                list.concat(TAICPU.op_reg_reg_ref(A_ADD,preferred_newbasereg,preferred_newbasereg,href));
              end
            else
              begin
                href.RefAddr:=addr_gotpageoffset;
                { use a_load_ref_reg() rather than directly encoding the LDR,
                  so that we'll check the validity of the reference }
                A_Load_Ref_Reg(list,OS_ADDR,OS_ADDR,href,preferred_newbasereg);
              end;
            { set as new base register }
            if ref.Base=NR_NO then
              ref.Base:=preferred_newbasereg
            else if ref.Index=NR_NO then
              ref.Index:=preferred_newbasereg
            else
              begin
                { make sure it's valid in case ref.base is SP -> make it
                  the second operand}
                A_Op_Reg_Reg_Reg(list,OP_ADD,OS_ADDR,preferred_newbasereg,ref.Base,preferred_newbasereg);
                ref.Base:=preferred_newbasereg
              end;
            ref.Symbol:=nil;
          end;

        { base & index }
        if (ref.Base<>NR_NO) and
           (ref.Index<>NR_NO) then
          begin
            case op of
              A_LDR, A_STR:
                begin
                  if (ref.ShiftMode=SM_None) and
                     (ref.ShiftImm<>0) then
                    InternalError(2014110805);
                  { wrong shift? (possible in case of something like
                     array_of_2byte_rec[x].bytefield -> shift will be set 1, but
                     the final load is a 1 byte -> can't use shift after all }
                  if (ref.ShiftMode in [SM_LSL,SM_UXTW,SM_SXTW]) and
                     ((ref.ShiftImm<>BsfDWord(tcgsizep2size[size])) or
                      (ref.Offset<>0)) then
                    begin
                      if preferred_newbasereg=NR_NO then
                        preferred_newbasereg:=GetAddressRegister(list);
                      { "add" supports a superset of the shift modes supported by
                        load/store instructions }
                      shifterop_reset(so);
                      so.ShiftMode:=ref.ShiftMode;
                      so.ShiftImm:=ref.ShiftImm;
                      list.concat(TAICPU.op_reg_reg_reg_shifterop(A_ADD,preferred_newbasereg,ref.Base,ref.Index,so));
                      Reference_Reset_Base(ref,preferred_newbasereg,ref.Offset,ref.TempPos,ref.Alignment,ref.Volatility);
                      { possibly still an invalid offset -> fall through }
                    end
                  else if ref.Offset<>0 then
                    begin
                      if (preferred_newbasereg=NR_NO) or
                         { we keep ref.index, so it must not be overwritten }
                         (ref.Index=preferred_newbasereg) then
                        preferred_newbasereg:=GetAddressRegister(list);
                      { add to the base and not to the index, because the index
                        may be scaled; this works even if the base is SP }
                      A_Op_Const_Reg_Reg(list,OP_ADD,OS_ADDR,ref.Offset,ref.Base,preferred_newbasereg);
                      ref.Offset:=0;
                      ref.Base:=preferred_newbasereg;
                      { finished }
                      exit;
                    end
                  else
                    { valid -> exit }
                    exit;
                end;
              { todo }
              A_LD1,A_LD2,A_LD3,A_LD4,
              A_ST1,A_ST2,A_ST3,A_ST4:
                InternalError(2014110702);
              { these don't support base+index }
              A_LDUR,A_STUR,
              A_LDP,A_STP:
                begin
                  { these either don't support pre-/post-indexing, or don't
                    support it with base+index }
                  if ref.AddressMode<>AM_OFFSET then
                    InternalError(2014110911);
                  if preferred_newbasereg=NR_NO then
                    preferred_newbasereg:=GetAddressRegister(list);
                  if ref.ShiftMode<>SM_None then
                    begin
                      { "add" supports a superset of the shift modes supported by
                        load/store instructions }
                      shifterop_reset(so);
                      so.ShiftMode:=ref.ShiftMode;
                      so.ShiftImm:=ref.ShiftImm;
                      list.concat(TAICPU.op_reg_reg_reg_shifterop(A_ADD,preferred_newbasereg,ref.Base,ref.Index,so));
                    end
                  else
                    A_Op_Reg_Reg_Reg(list,OP_ADD,OS_ADDR,ref.Index,ref.Base,preferred_newbasereg);
                  Reference_Reset_Base(ref,preferred_newbasereg,ref.Offset,ref.TempPos,ref.Alignment,ref.Volatility);
                  { fall through to the handling of base + offset, since the
                    offset may still be too big }
                end;
              else
                InternalError(2014110903);
            end;
          end;

        { base + offset }
        if ref.Base<>NR_NO then
          begin
            if ref.Offset=0 then
              exit;

            { valid offset for LDUR/STUR -> use that }
            if (ref.AddressMode=AM_OFFSET) and
               (op in [A_LDR,A_STR]) and
               (ref.Offset>=-256) and
               (ref.Offset<=255) then
              begin
                if op=A_LDR then
                  op:=A_LDUR
                else
                  op:=A_STUR
              end
            { if it's not a valid LDUR/STUR, use LDR/STR }
            else if (op in [A_LDUR,A_STUR]) and
               ((ref.Offset<-256) or
                (ref.Offset>255) or
                (ref.AddressMode<>AM_OFFSET)) then
              begin
                if op=A_LDUR then
                  op:=A_LDR
                else
                  op:=A_STR
              end;
            case op of
              A_LDR,A_STR:
                begin
                  case ref.AddressMode of
                    AM_PREINDEXED:
                      begin
                        { since the loaded/stored register cannot be the same
                          as the base register, we can safely add the
                          offset to the base if it doesn't fit}
                        if (ref.Offset<-256) or
                            (ref.Offset>255) then
                          begin
                            A_Op_Const_Reg(list,OP_ADD,OS_ADDR,ref.Offset,ref.Base);
                            ref.Offset:=0;
                          end;
                      end;
                    AM_POSTINDEXED:
                      begin
                        { cannot emulate post-indexing if we have to fold the
                          offset into the base register }
                        if (ref.Offset<-256) or
                            (ref.Offset>255) then
                          InternalError(2014110909);
                        { ok }
                      end;
                    AM_OFFSET:
                      begin
                        { unsupported offset -> fold into base register }
                        accesssize:=1 shl tcgsizep2size[size];
                        if (ref.Offset<0) or
                           (ref.Offset>(((1 shl 12)-1)*accesssize)) or
                           ((ref.Offset mod accesssize)<>0) then
                          begin
                            if preferred_newbasereg=NR_NO then
                              preferred_newbasereg:=GetAddressRegister(list);
                            { can we split the offset between an
                              "add/sub (imm12 shl 12)" and the load (also an
                              imm12)?
                              -- the offset from the load will always be added,
                                that's why the lower bound has a smaller range
                                than the upper bound; it must also be a multiple
                                of the access size }
                            if (ref.Offset>=-(((1 shl 12)-1) shl 12)) and
                               (ref.Offset<=((1 shl 12)-1) shl 12 + ((1 shl 12)-1)) and
                               ((ref.Offset mod accesssize)=0) then
                              begin
                                A_Op_Const_Reg_Reg(list,OP_ADD,OS_ADDR,(ref.Offset shr 12) shl 12,ref.Base,preferred_newbasereg);
                                ref.Offset:=ref.Offset-(ref.Offset shr 12) shl 12;
                              end
                            else
                              begin
                                A_Op_Const_Reg_Reg(list,OP_ADD,OS_ADDR,ref.Offset,ref.Base,preferred_newbasereg);
                                ref.Offset:=0;
                              end;
                            Reference_Reset_Base(ref,preferred_newbasereg,ref.Offset,ref.TempPos,ref.Alignment,ref.Volatility);
                          end;
                      end
                  end;
                end;
              A_LDP,A_STP:
                begin
                  { unsupported offset -> fold into base register (these
                    instructions support all addressmodes) }
                  if (ref.Offset<-(1 shl (6+tcgsizep2size[size]))) or
                     (ref.Offset>(1 shl (6+tcgsizep2size[size]))-1) then
                    begin
                      case ref.AddressMode of
                        AM_POSTINDEXED:
                          { don't emulate post-indexing if we have to fold the
                            offset into the base register }
                          InternalError(2014110910);
                        AM_PREINDEXED:
                          { this means the offset must be added to the current
                            base register }
                          preferred_newbasereg:=ref.Base;
                        AM_OFFSET:
                          if preferred_newbasereg=NR_NO then
                            preferred_newbasereg:=GetAddressRegister(list);
                      end;
                      A_Op_Const_Reg_Reg(list,OP_ADD,OS_ADDR,ref.Offset,ref.Base,preferred_newbasereg);
                      Reference_Reset_Base(ref,preferred_newbasereg,0,ref.TempPos,ref.Alignment,ref.Volatility);
                    end
                end;
              A_LDUR,A_STUR:
                begin
                  { valid, checked above }
                end;
              { todo }
              A_LD1,A_LD2,A_LD3,A_LD4,
              A_ST1,A_ST2,A_ST3,A_ST4:
                InternalError(2014110908);
              else
                InternalError(2014110708);
            end;
            { done }
            exit;
          end;

        { only an offset -> change to base (+ offset 0) }
        if preferred_newbasereg=NR_NO then
          preferred_newbasereg:=GetAddressRegister(list);
        A_Load_Const_Reg(list,OS_ADDR,ref.Offset,preferred_newbasereg);
        Reference_Reset_Base(ref,preferred_newbasereg,0,ref.TempPos,NewAlignment(8,ref.Offset),ref.Volatility);
      end;


    function TCGAArch64.MakeRegSize(reg: TRegister; size: TCgSize): TRegister;
      var
        SubReg:TSubRegister;
      begin
        SubReg:=cgsize2subreg(GetRegType(reg),size);
        result:=reg;
        SetSubReg(result,SubReg);
      end;


    function TCGAArch64.GetFPURegister(list: TAsmList; size: TCgSize): TRegister;
      begin
        InternalError(2014122110);
        { squash warning }
        result:=NR_NO;
      end;


    function TCGAArch64.handle_load_store(list: TAsmList; op: TAsmOp; size: TCgSize; oppostfix: TOpPostfix; reg: TRegister; ref: TReference):TReference;
      begin
        make_simple_ref(list,op,size,oppostfix,ref,NR_NO);
        list.concat(setoppostfix(TAICPU.op_reg_ref(op,reg,ref),oppostfix));
        result:=ref;
      end;


    procedure TCGAArch64.handle_reg_imm12_reg(list: TAsmList; op: TAsmOp; size: TCgSize; src: TRegister; a: TCGInt; dst: TRegister; tmpreg: TRegister; setflags, usedest: boolean);
      var
        instr: TAICPU;
        so: TShifterOp;
        hadtmpreg: boolean;
      begin
        { imm12 }
        if (a>=0) and
           (a<=((1 shl 12)-1)) then
          if usedest then
            instr:=TAICPU.op_reg_reg_const(op,dst,src,a)
          else
            instr:=TAICPU.op_reg_const(op,src,a)
        { imm12 lsl 12 }
        else if (a and not(((TCGInt(1) shl 12)-1) shl 12))=0 then
          begin
            so.ShiftMode:=SM_LSL;
            so.ShiftImm:=12;
            if usedest then
              instr:=TAICPU.op_reg_reg_const_shifterop(op,dst,src,a shr 12,so)
            else
              instr:=TAICPU.op_reg_const_shifterop(op,src,a shr 12,so)
          end
        else
          begin
            { todo: other possible optimizations (e.g. load 16 bit constant in
                register and then add/sub/cmp/cmn shifted the rest) }
            if tmpreg=NR_NO then
              begin
                hadtmpreg:=false;
                tmpreg:=GetIntRegister(list,size);
              end
            else
              begin
                hadtmpreg:=true;
                GetCPURegister(list,tmpreg);
              end;
            A_Load_Const_Reg(list,size,a,tmpreg);
            if usedest then
              instr:=TAICPU.op_reg_reg_reg(op,dst,src,tmpreg)
            else
              instr:=TAICPU.op_reg_reg(op,src,tmpreg);
            if hadtmpreg then
              UngetCPURegister(list,tmpreg);
          end;
        if setflags then
          setoppostfix(instr,PF_S);
        list.concat(instr);
      end;


{****************************************************************************
                              Assembler code
****************************************************************************}

    procedure TCGAArch64.Init_Register_Allocators;
      begin
        inherited Init_Register_Allocators;

        rg[R_INTREGISTER]:=TRGIntCPU.Create(R_INTREGISTER,R_SUBWHOLE,
            [RS_X0,RS_X1,RS_X2,RS_X3,RS_X4,RS_X5,RS_X6,RS_X7,RS_X8,
             RS_X9,RS_X10,RS_X11,RS_X12,RS_X13,RS_X14,RS_X15,RS_X16,RS_X17,
             RS_X19,RS_X20,RS_X21,RS_X22,RS_X23,RS_X24,RS_X25,RS_X26,RS_X27,RS_X28
             { maybe we can enable this in the future for leaf functions (it's
               the frame pointer)
             ,RS_X29 }],
            first_int_imreg,[]);

        rg[R_MMREGISTER]:=TRGCPU.Create(R_MMREGISTER,R_SUBMMD,
            [RS_Q0,RS_Q1,RS_Q2,RS_Q3,RS_Q4,RS_Q5,RS_Q6,RS_Q7,
             RS_Q8,RS_Q9,RS_Q10,RS_Q11,RS_Q12,RS_Q13,RS_Q14,RS_Q15,
             RS_Q16,RS_Q17,RS_Q18,RS_Q19,RS_Q20,RS_Q21,RS_Q22,RS_Q23,
             RS_Q24,RS_Q25,RS_Q26,RS_Q27,RS_Q28,RS_Q29,RS_Q30,RS_Q31],
            first_mm_imreg,[]);
      end;


    procedure TCGAArch64.Done_Register_Allocators;
      begin
        rg[R_INTREGISTER].free;
        rg[R_FPUREGISTER].free;
        rg[R_MMREGISTER].free;
        inherited Done_Register_Allocators;
      end;


    function TCGAArch64.GetMMRegister(list: TAsmList; size: TCgSize):TRegister;
      begin
        case size of
          OS_F32:
            result:=rg[R_MMREGISTER].GetRegister(list,R_SUBMMS);
          OS_F64:
            result:=rg[R_MMREGISTER].GetRegister(list,R_SUBMMD)
          else
            InternalError(2014102701);
        end;
      end;


    procedure TCGAArch64.A_Call_Name(list: TAsmList; const s: string; weak: boolean);
      begin
        if not weak then
          list.concat(TAICPU.op_sym(A_BL,CurrentAsmData.RefAsmSymbol(s,AT_FUNCTION)))
        else
          list.concat(TAICPU.op_sym(A_BL,CurrentAsmData.WeakRefAsmSymbol(s,AT_FUNCTION)));
      end;


    procedure TCGAArch64.A_Call_Reg(list:TAsmList;Reg:TRegister);
      begin
        list.concat(TAICPU.op_reg(A_BLR,reg));
      end;


    {********************** load instructions ********************}

    procedure TCGAArch64.A_Load_Const_Reg(list: TAsmList; size: TCgSize; a: TCGInt; reg : TRegister);
      var
        opc: TAsmOp;
        shift: byte;
        so: TShifterOp;
        reginited,doinverted,extendedsize: boolean;
        manipulated_a: TCGInt;
        leftover_a: word;
      begin
{$ifdef extdebug}
        list.concat(TAIComment.Create(StrPNew('Generating constant ' + ToStr(a) + ' / $' + HexStr(a, 16))));
{$endif extdebug}
        extendedsize := (size in [OS_64,OS_S64]);

        case a of
          { Small positive number }
          $0..$FFFF:
            begin
              list.concat(TAICPU.op_reg_const(A_MOVZ, reg, a));
              Exit;
            end;
          { Small negative number }
          -65536..-1:
            begin
              list.concat(TAICPU.op_reg_const(A_MOVN, reg, Word(not a)));
              Exit;
            end;
          { Can be represented as a negative number more compactly }
          $FFFF0000..$FFFFFFFF:
            begin
              { if we load a value into a 32 bit register, it is automatically
                zero-extended to 64 bit }
              list.concat(TAICPU.op_reg_const(A_MOVN, MakeRegSize(reg,OS_32), Word(not a)));
              Exit;
            end;
          else
            begin
              if not extendedsize then
                { Mostly so programmers don't get confused when they view the disassembly and
                  'a' is sign-extended to 64-bit, say, but also avoids potential problems with
                  third-party assemblers if the number is out of bounds for a given size }
                a := Cardinal(a);

              { Check to see if a is a valid shifter constant that can be encoded in ORR as is }
              if is_shifter_const(a,size) then
                begin
                  { Use synthetic "MOV" instruction instead of "ORR reg,wzr,#a" (an alias),
                    since AArch64 conventions prefer this, and it's clearer in the
                    disassembly }
                  list.concat(TAICPU.op_reg_const(A_MOV,reg,a));
                  Exit;
                end;

              { If the value of a fits into 32 bits, it's fastest to use movz/movk regardless }
              if extendedsize and ((a shr 32) <> 0) then
                begin
                  { This determines whether this write can be performed with an ORR followed by MOVK
                    by copying the 3nd word to the 1st word for the ORR constant, then overwriting
                    the 1st word.  The alternative would require 4 instructions.  This sequence is
                    common when division reciprocals are calculated (e.g. 3 produces AAAAAAAAAAAAAAAB). }
                  leftover_a := word(a and $FFFF);
                  manipulated_a := (a and $FFFFFFFFFFFF0000) or ((a shr 32) and $FFFF);
                  { if manipulated_a = a, don't check, because is_shifter_const was already
                    called for a and it returned False.  Reduces processing time. [Kit] }
                  if (manipulated_a <> a) and is_shifter_const(manipulated_a, OS_64) then
                    begin
                      { Encode value as:
                          orr  reg,xzr,manipulated_a
                          movk reg,#(leftover_a)

                        Use "orr" instead of "mov" here for the assembly dump so it better
                        implies that something special is happening with the number arrangement.
                      }
                      list.concat(TAICPU.op_reg_reg_const(A_ORR, reg, NR_XZR, manipulated_a));
                      list.concat(TAICPU.op_reg_const(A_MOVK, reg, leftover_a));
                      Exit;
                    end;

                  { This determines whether this write can be performed with an ORR followed by MOVK
                    by copying the 2nd word to the 4th word for the ORR constant, then overwriting
                    the 4th word.  The alternative would require 3 instructions }
                  leftover_a := word(a shr 48);
                  manipulated_a := (a and $0000FFFFFFFFFFFF);

                  if manipulated_a = $0000FFFFFFFFFFFF then
                    begin
                      { This is even better, as we can just use a single MOVN on the last word }
                      shifterop_reset(so);
                      so.ShiftMode := SM_LSL;
                      so.ShiftImm := 48;
                      list.concat(TAICPU.op_reg_const_shifterop(A_MOVN, reg, word(not leftover_a), so));
                      Exit;
                    end;

                  manipulated_a := manipulated_a or (((a shr 16) and $FFFF) shl 48);
                  { if manipulated_a = a, don't check, because is_shifter_const was already
                    called for a and it returned False.  Reduces processing time. [Kit] }
                  if (manipulated_a <> a) and is_shifter_const(manipulated_a, OS_64) then
                    begin
                      { Encode value as:
                          orr  reg,xzr,manipulated_a
                          movk reg,#(leftover_a),lsl #48

                        Use "orr" instead of "mov" here for the assembly dump so it better
                        implies that something special is happening with the number arrangement.
                      }
                      list.concat(TAICPU.op_reg_reg_const(A_ORR, reg, NR_XZR, manipulated_a));
                      shifterop_reset(so);
                      so.ShiftMode := SM_LSL;
                      so.ShiftImm := 48;
                      list.concat(TAICPU.op_reg_const_shifterop(A_MOVK, reg, leftover_a, so));
                      Exit;
                    end;

                  case a of
                    { If a is in the given negative range, it can be stored
                      more efficiently if it is inverted.  }
                    TCGInt($FFFF000000000000)..-65537:
                      begin
                        { NOTE: This excluded range can be more efficiently
                          stored as the first 16 bits followed by a shifter constant }
                        case a of
                          TCGInt($FFFF0000FFFF0000)..TCGInt($FFFF0000FFFFFFFF):
                            doinverted := False;
                          else
                            begin
                              doinverted := True;
                              a := not a;
                            end;
                        end;
                      end;

                    else
                      doinverted := False;
                  end;
                end
              else
                doinverted:=False;
            end;
        end;

        reginited:=false;
        shift:=0;

        if doinverted then
          opc:=A_MOVN
        else
          opc:=A_MOVZ;

        repeat
          { leftover is shifterconst? (don't check if we can represent it just
            as effectively with movz/movk, as this check is expensive) }
          if (word(a)<>0) then
            begin

              if not doinverted and
                ((shift<TCgSize2Size[size]*(8 div 2)) and
                  ((a shr 16)<>0)) and
                 is_shifter_const(a shl shift,size) then
                begin
                  if reginited then
                    list.concat(TAICPU.op_reg_reg_const(A_ORR,reg,reg,a shl shift))
                  else
                    list.concat(TAICPU.op_reg_reg_const(A_ORR,reg,MakeRegSize(NR_XZR,size),a shl shift));

                  exit;
                end;

              { set all 16 bit parts <> 0 }
              if shift=0 then
                begin
                  list.concat(TAICPU.op_reg_const(opc,reg,word(a)));
                  reginited:=true;
                end
              else
                begin
                  shifterop_reset(so);
                  so.ShiftMode:=SM_LSL;
                  so.ShiftImm:=shift;
                  if not reginited then
                    begin
                      list.concat(TAICPU.op_reg_const_shifterop(opc,reg,word(a),so));
                      reginited:=true;
                    end
                  else
                    begin
                      if doinverted then
                        list.concat(TAICPU.op_reg_const_shifterop(A_MOVK,reg,word(not a),so))
                      else
                        list.concat(TAICPU.op_reg_const_shifterop(A_MOVK,reg,word(a),so));
                    end;
                end;
            end;

          a:=a shr 16;
          inc(shift,16);
        until a = 0;

        if not reginited then
          InternalError(2014102702);
      end;


    procedure TCGAArch64.A_Load_Const_Ref(list: TAsmList; size: TCgSize; a: TCGInt; const ref: TReference);
      var
        reg: TRegister;
        href: TReference;
        i: Integer;
      begin
        { use the zero register if possible }
        if a=0 then
          begin
            href:=ref;
            inc(href.Offset,TCgSize2Size[size]-1);
            if (TCgSize2Size[size]>1) and (ref.Alignment=1) and (simple_ref_type(A_STUR,OS_8,PF_None,ref)=sr_simple) and
              (simple_ref_type(A_STUR,OS_8,PF_None,href)=sr_simple) then
              begin
                href:=ref;
                for i:=0 to TCgSize2Size[size]-1 do
                  begin
                    A_Load_Const_Ref(list,OS_8,0,href);
                    inc(href.Offset);
                  end;
              end
            else
              begin
                if size in [OS_64,OS_S64] then
                  reg:=NR_XZR
                else
                  reg:=NR_WZR;
                A_Load_Reg_Ref(list,size,size,reg,ref);
              end;
          end
        else
          inherited;
      end;


    procedure TCGAArch64.A_Load_Reg_Ref(list: TAsmList; fromsize, tosize: TCgSize; reg: TRegister; const ref: TReference);
      var
        oppostfix:TOpPostfix;
        hreg: TRegister;
      begin
        if TCgSize2Size[fromsize]>=TCgSize2Size[tosize] then
          begin
            fromsize:=tosize;
            reg:=MakeRegSize(list,reg,fromsize);
          end
        { have a 32 bit register but need a 64 bit one? }
        else if tosize in [OS_64,OS_S64] then
          begin
            { sign extend if necessary }
            if fromsize in [OS_S8,OS_S16,OS_S32] then
              begin
                { can't overwrite reg, may be a constant reg }
                hreg:=GetIntRegister(list,tosize);
                A_Load_Reg_Reg(list,fromsize,tosize,reg,hreg);
                reg:=hreg;
              end
            else
              { top 32 bit are zero by default }
              reg:=MakeRegSize(reg,OS_64);
            fromsize:=tosize;
          end;
        if not(TargetInfo.system=system_aarch64_darwin) and (ref.Alignment<>0) and
           (ref.Alignment<TCgSize2Size[tosize]) then
          begin
            A_Load_Reg_Ref_Unaligned(list,fromsize,tosize,reg,ref);
          end
        else
          begin
            case tosize of
              { signed integer registers }
              OS_8,
              OS_S8:
                oppostfix:=PF_B;
              OS_16,
              OS_S16:
                oppostfix:=PF_H;
              OS_32,
              OS_S32,
              OS_64,
              OS_S64:
                oppostfix:=PF_None;
              else
                InternalError(200308299);
            end;
            handle_load_store(list,A_STR,tosize,oppostfix,reg,ref);
          end;
      end;


    procedure TCGAArch64.A_Load_Ref_Reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; reg: TRegister);
      var
        oppostfix:TOpPostfix;
      begin
        if TCgSize2Size[fromsize]>=TCgSize2Size[tosize] then
          fromsize:=tosize;
        { ensure that all bits of the 32/64 register are always correctly set:
           * default behaviour is always to zero-extend to the entire (64 bit)
             register -> unsigned 8/16/32 bit loads only exist with a 32 bit
             target register, as the upper 32 bit will be zeroed implicitly
             -> always make target register 32 bit
           * signed loads exist both with 32 and 64 bit target registers,
             depending on whether the value should be sign extended to 32 or
             to 64 bit (if sign extended to 32 bit, the upper 32 bits of the
             corresponding 64 bit register are again zeroed) -> no need to
             change anything (we only have 32 and 64 bit registers), except that
             when loading an OS_S32 to a 32 bit register, we don't need/can't
             use sign extension
        }
        if fromsize in [OS_8,OS_16,OS_32] then
          reg:=MakeRegSize(reg,OS_32);
        if not(TargetInfo.system=system_aarch64_darwin) and (ref.Alignment<>0) and
           (ref.Alignment<TCgSize2Size[fromsize]) then
          begin
            A_Load_Ref_Reg_Unaligned(list,fromsize,tosize,ref,reg);
            exit;
          end;
        case fromsize of
          { signed integer registers }
          OS_8:
            oppostfix:=PF_B;
          OS_S8:
            oppostfix:=PF_SB;
          OS_16:
            oppostfix:=PF_H;
          OS_S16:
            oppostfix:=PF_SH;
          OS_S32:
            if GetSubReg(reg)=R_SUBD then
              oppostfix:=PF_NONE
            else
              oppostfix:=PF_SW;
          OS_32,
          OS_64,
          OS_S64:
            oppostfix:=PF_None;
          else
            InternalError(200308297);
        end;
        handle_load_store(list,A_LDR,fromsize,oppostfix,reg,ref);

        { clear upper 16 bits if the value was negative }
        if (fromsize=OS_S8) and (tosize=OS_16) then
          A_Load_Reg_Reg(list,fromsize,tosize,reg,reg);
      end;


    procedure TCGAArch64.A_Load_Ref_Reg_Unaligned(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; register: TRegister);
      var
        href: TReference;
        hreg1, hreg2, tmpreg,tmpreg2: TRegister;
        i : Integer;
      begin
        case fromsize of
          OS_64,OS_S64:
            begin
              { split into two 32 bit loads }
              hreg1:=GetIntRegister(list,OS_32);
              hreg2:=GetIntRegister(list,OS_32);
              { can we use LDP? }
              if (ref.Alignment=4) and
                 (simple_ref_type(A_LDP,OS_32,PF_None,ref)=sr_simple) then
                list.concat(TAICPU.op_reg_reg_ref(A_LDP,hreg1,hreg2,ref))
              else
                begin
                  A_Load_Ref_Reg(list,OS_32,OS_32,ref,hreg1);
                  href:=ref;
                  inc(href.Offset,4);
                  A_Load_Ref_Reg(list,OS_32,OS_32,href,hreg2);
                end;
              A_Load_Reg_Reg(list,OS_32,OS_64,hreg1,register);
              list.concat(TAICPU.op_reg_reg_const_const(A_BFI,register,MakeRegSize(hreg2,OS_64),32,32));
            end;
          OS_16,OS_S16,
          OS_32,OS_S32:
            begin
              if ref.Alignment=2 then
                begin
                  href:=ref;
                  tmpreg:=GetIntRegister(list,OS_32);
                  A_Load_Ref_Reg(list,OS_16,OS_32,href,tmpreg);
                  tmpreg2:=GetIntRegister(list,OS_32);
                  for i:=1 to (TCgSize2Size[fromsize]-1) div 2 do
                    begin
                      inc(href.Offset,2);
                      A_Load_Ref_Reg(list,OS_16,OS_32,href,tmpreg2);
                      list.concat(TAICPU.op_reg_reg_const_const(A_BFI,tmpreg,tmpreg2,i*16,16));
                    end;
                  A_Load_Reg_Reg(list,fromsize,tosize,tmpreg,register);
                end
              else
                begin
                  href:=ref;
                  tmpreg:=GetIntRegister(list,OS_32);
                  A_Load_Ref_Reg(list,OS_8,OS_32,href,tmpreg);
                  tmpreg2:=GetIntRegister(list,OS_32);
                  for i:=1 to TCgSize2Size[fromsize]-1 do
                    begin
                      inc(href.Offset);
                      A_Load_Ref_Reg(list,OS_8,OS_32,href,tmpreg2);
                      list.concat(TAICPU.op_reg_reg_const_const(A_BFI,tmpreg,tmpreg2,i*8,8));
                    end;
                  A_Load_Reg_Reg(list,fromsize,tosize,tmpreg,register);
                end;
            end;
          else
            inherited;
        end;
      end;


    procedure TCGAArch64.A_Load_Reg_Reg(list:TAsmList;fromsize,tosize:TCgSize;reg1,reg2:TRegister);
      var
        instr: TAICPU;
      begin
        { we use both 32 and 64 bit registers -> insert conversion when when
          we have to truncate/sign extend inside the (32 or 64 bit) register
          holding the value, and when we sign extend from a 32 to a 64 bit
          register }
        if (TCgSize2Size[fromsize]>TCgSize2Size[tosize]) or
           ((TCgSize2Size[fromsize]=TCgSize2Size[tosize]) and
            (fromsize<>tosize) and
            not(fromsize in [OS_32,OS_S32,OS_64,OS_S64])) or
           ((fromsize in [OS_S8,OS_S16,OS_S32]) and
            (tosize in [OS_64,OS_S64])) or
           ((fromsize in [OS_S8,OS_S16]) and
            (tosize in [OS_32,OS_S32])) or
           { needs to mask out the sign in the top 16 bits }
           ((fromsize=OS_S8) and
            (tosize=OS_16)) then
          begin
            case tosize of
              OS_8:
                list.concat(TAICPU.op_reg_reg(A_UXTB,reg2,MakeRegSize(reg1,OS_32)));
              OS_16:
                list.concat(TAICPU.op_reg_reg(A_UXTH,reg2,MakeRegSize(reg1,OS_32)));
              OS_S8:
                list.concat(TAICPU.op_reg_reg(A_SXTB,reg2,MakeRegSize(reg1,OS_32)));
              OS_S16:
                list.concat(TAICPU.op_reg_reg(A_SXTH,reg2,MakeRegSize(reg1,OS_32)));
              { while "mov wN, wM" automatically inserts a zero-extension and
                hence we could encode a 64->32 bit move like that, the problem
                is that we then can't distinguish 64->32 from 32->32 moves, and
                the 64->32 truncation could be removed altogether... So use a
                different instruction }
              OS_32,
              OS_S32:
                case fromsize of
                  OS_S8:
                    list.concat(TAICPU.op_reg_reg(A_SXTB,reg2,MakeRegSize(reg1,OS_32)));
                  OS_S16:
                    list.concat(TAICPU.op_reg_reg(A_SXTH,reg2,MakeRegSize(reg1,OS_32)));
                  else
                    { in theory, reg1 should be 64 bit here (since fromsize>tosize),
                      but because of the way location_force_register() tries to
                      avoid superfluous zero/sign extensions, it's not always the
                      case -> also force reg1 to to 64 bit }
                    list.concat(TAICPU.op_reg_reg_const_const(A_UBFIZ,MakeRegSize(reg2,OS_64),MakeRegSize(reg1,OS_64),0,32));
                end;
              OS_64,
              OS_S64:
                case fromsize of
                  OS_8:
                    list.concat(TAICPU.op_reg_reg(A_UXTB,reg2,MakeRegSize(reg1,OS_64)));
                  OS_S8:
                    list.concat(TAICPU.op_reg_reg(A_SXTB,reg2,MakeRegSize(reg1,OS_32)));
                  OS_16:
                    list.concat(TAICPU.op_reg_reg(A_UXTH,reg2,MakeRegSize(reg1,OS_64)));
                  OS_S16:
                    list.concat(TAICPU.op_reg_reg(A_SXTH,reg2,MakeRegSize(reg1,OS_32)));
                  OS_32:
                    list.concat(TAICPU.op_reg_reg_const_const(A_UBFIZ,MakeRegSize(reg2,OS_64),MakeRegSize(reg1,OS_64),0,32));
                  OS_S32:
                    list.concat(TAICPU.op_reg_reg(A_SXTW,reg2,MakeRegSize(reg1,OS_32)));
                  else
                    InternalError(2024070701);
                end;
              else
                InternalError(2002090901);
            end;
          end
        else
          begin
            { 32 -> 32 bit move implies zero extension (sign extensions have
              been handled above) -> also use for 32 <-> 64 bit moves }
            if not(fromsize in [OS_64,OS_S64]) or
               not(tosize in [OS_64,OS_S64]) then
              instr:=TAICPU.op_reg_reg(A_MOV,MakeRegSize(reg2,OS_32),MakeRegSize(reg1,OS_32))
            else
              instr:=TAICPU.op_reg_reg(A_MOV,reg2,reg1);
            list.Concat(instr);
            { Notify the register allocator that we have written a move instruction so
             it can try to eliminate it. }
            Add_Move_Instruction(instr);
          end;
      end;


    procedure TCGAArch64.A_LoadAddr_Ref_Reg(list: TAsmList; const ref: TReference; r: TRegister);
      var
         href: TReference;
         so: TShifterOp;
         op: TAsmOp;
      begin
        op:=A_LDR;
        href:=ref;
        { simplify as if we're going to perform a regular 64 bit load, using
          "r" as the new base register if possible/necessary }
        make_simple_ref(list,op,OS_ADDR,PF_None,href,r);
        { load literal? }
        if Assigned(href.Symbol) then
          begin
            if (href.Base<>NR_NO) or
               (href.Index<>NR_NO) or
               not Assigned(href.SymbolData) then
              InternalError(2014110912);
            list.concat(TAICPU.op_reg_sym_ofs(A_ADR,r,href.Symbol,href.Offset));
          end
        else
          begin
            if href.Index<>NR_NO then
              begin
                if href.ShiftMode<>SM_None then
                  begin
                    { "add" supports a supperset of the shift modes supported by
                      load/store instructions }
                    shifterop_reset(so);
                    so.ShiftMode:=href.ShiftMode;
                    so.ShiftImm:=href.ShiftImm;
                    list.concat(TAICPU.op_reg_reg_reg_shifterop(A_ADD,r,href.Base,href.Index,so));
                  end
                else
                  A_Op_Reg_Reg_Reg(list,OP_ADD,OS_ADDR,href.Index,href.Base,r);
              end
            else if href.Offset<>0 then
              A_Op_Const_Reg_Reg(list,OP_ADD,OS_ADDR,href.Offset,href.Base,r)
            else
              A_Load_Reg_Reg(list,OS_ADDR,OS_ADDR,href.Base,r);
          end;
      end;


    procedure TCGAArch64.A_LoadFPU_Reg_Reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister);
      begin
        InternalError(2014122107)
      end;


    procedure TCGAArch64.A_LoadFPU_Ref_Reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; reg: TRegister);
      begin
        InternalError(2014122108)
      end;


    procedure TCGAArch64.A_LoadFPU_Reg_Ref(list: TAsmList; fromsize, tosize: TCgSize; reg: TRegister; const ref: TReference);
      begin
        InternalError(2014122109)
      end;


    procedure TCGAArch64.A_LoadMM_Reg_Reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister; shuffle: PMMShuffle);
      var
        instr: TAICPU;
      begin
        if Assigned(shuffle) and
           not ShuffleScalar(shuffle) then
          InternalError(2014122104);
        if fromsize=tosize then
          begin
            instr:=TAICPU.op_reg_reg(A_FMOV,reg2,reg1);
            { Notify the register allocator that we have written a move
              instruction so it can try to eliminate it. }
            Add_Move_Instruction(instr);
            { FMOV cannot generate a floating point exception }
          end
        else
          begin
            if (reg_cgsize(reg1)<>fromsize) or
               (reg_cgsize(reg2)<>tosize) then
              InternalError(2014110913);
            instr:=TAICPU.op_reg_reg(A_FCVT,reg2,reg1);
            Maybe_Check_For_FPU_Exception(list);
          end;
        list.Concat(instr);
      end;


    procedure TCGAArch64.A_LoadMM_Ref_Reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; reg: TRegister; shuffle: PMMShuffle);
       var
         tmpreg: TRegister;
       begin
         if Assigned(shuffle) and
            not ShuffleScalar(shuffle) then
           InternalError(2014122105);
         tmpreg:=NR_NO;
         if (fromsize<>tosize) then
           begin
             tmpreg:=reg;
             reg:=GetMMRegister(list,fromsize);
           end;
         handle_load_store(list,A_LDR,fromsize,PF_None,reg,ref);
         if (fromsize<>tosize) then
           A_LoadMM_Reg_Reg(list,fromsize,tosize,reg,tmpreg,nil);
       end;


     procedure TCGAArch64.A_LoadMM_Reg_Ref(list: TAsmList; fromsize, tosize: TCgSize; reg: TRegister; const ref: TReference; shuffle: PMMShuffle);
       var
         tmpreg: TRegister;
       begin
         if Assigned(shuffle) and
            not ShuffleScalar(shuffle) then
           InternalError(2014122106);
         if (fromsize<>tosize) then
           begin
             tmpreg:=GetMMRegister(list,tosize);
             A_LoadMM_Reg_Reg(list,fromsize,tosize,reg,tmpreg,nil);
             reg:=tmpreg;
           end;
         handle_load_store(list,A_STR,tosize,PF_NONE,reg,ref);
       end;


     procedure TCGAArch64.A_LoadMM_IntReg_Reg(list: TAsmList; fromsize, tosize: TCgSize; intreg, mmreg: TRegister; shuffle: PMMShuffle);
       begin
         if not ShuffleScalar(shuffle) then
           InternalError(2014122801);
         if TCgSize2Size[fromsize]<>TCgSize2Size[tosize] then
           InternalError(2014122803);
         case TCgSize2Size[tosize] of
           4:
             SetSubReg(mmreg,R_SUBMMS);
           8:
             SetSubReg(mmreg,R_SUBMMD);
           else
             InternalError(2020101310);
         end;
         list.concat(TAICPU.op_indexedreg_reg(A_INS,mmreg,0,intreg));
       end;


     procedure TCGAArch64.A_LoadMM_Reg_IntReg(list: TAsmList; fromsize, tosize: TCgSize; mmreg, intreg: TRegister; shuffle: PMMShuffle);
       var
         r : TRegister;
       begin
         if not ShuffleScalar(shuffle) then
           InternalError(2014122802);
         if TCgSize2Size[fromsize]>TCgSize2Size[tosize] then
           InternalError(2014122804);
         case TCgSize2Size[fromsize] of
           4:
             SetSubReg(mmreg,R_SUBMMS);
           8:
             SetSubReg(mmreg,R_SUBMMD);
           else
             InternalError(2020101311);
           end;
         if TCgSize2Size[fromsize]<TCgSize2Size[tosize] then
           r:=MakeRegSize(intreg,fromsize)
         else
           r:=intreg;
         list.concat(TAICPU.op_reg_reg(A_FMOV,r,mmreg));
       end;


    procedure TCGAArch64.A_OpMM_Reg_Reg(list: TAsmList; Op: TOpCG; size: TCgSize; src, dst: TRegister; shuffle: PMMShuffle);
      begin
        case op of
          { "xor Vx,Vx" is used to initialize global regvars to 0 }
          OP_XOR:
            begin
              if shuffle=nil then
                begin
                  dst:=NewReg(R_MMREGISTER,GetSupReg(dst),R_SUBMM16B);
                  src:=NewReg(R_MMREGISTER,GetSupReg(src),R_SUBMM16B);
                  list.concat(TAICPU.op_reg_reg_reg(A_EOR,dst,dst,src))
                end
              else if (src<>dst) or
                 (reg_cgsize(src)<>size) or
                 Assigned(shuffle) then
                InternalError(2015011401)
              else
                case size of
                  OS_F32,
                  OS_F64:
                    list.concat(TAICPU.op_reg_const(A_MOVI,MakeRegSize(dst,OS_F64),0));
                  else
                    InternalError(2015011402);
                end;
            end
          else
            InternalError(2015011403);
        end;
      end;


    procedure TCGAArch64.A_Bit_Scan_Reg_Reg(list: TAsmList; reverse,not_zero: boolean; srcsize, dstsize: TCgSize; src, dst: TRegister);
      var
        bitsize: LongInt;
      begin
        if srcsize in [OS_64,OS_S64] then
          bitsize:=64
        else
          bitsize:=32;
        if not(not_zero) then
          { source is 0 -> dst will have to become 255 }
          list.concat(TAICPU.op_reg_const(A_CMP,src,0));
        if reverse then
          begin
            list.Concat(TAICPU.op_reg_reg(A_CLZ,MakeRegSize(dst,srcsize),src));
            { xor 31/63 is the same as setting the lower 5/6 bits to
              "31/63-(lower 5/6 bits of dst)" }
            list.Concat(TAICPU.op_reg_reg_const(A_EOR,dst,dst,bitsize-1));
          end
        else
          begin
            list.Concat(TAICPU.op_reg_reg(A_RBIT,MakeRegSize(dst,srcsize),src));
            list.Concat(TAICPU.op_reg_reg(A_CLZ,dst,dst));
          end;
        { set dst to -1 if src was 0 }
        if not(not_zero) then
          begin
            list.Concat(TAICPU.op_reg_reg_reg_cond(A_CSINV,dst,dst,MakeRegSize(NR_XZR,dstsize),C_NE));
            { mask the -1 to 255 if src was 0 (anyone find a two-instruction
              branch-free version? All of mine are 3...) }
            list.Concat(TAICPU.op_reg_reg(A_UXTB,MakeRegSize(dst,OS_32),MakeRegSize(dst,OS_32)));
          end;
      end;


    procedure TCGAArch64.A_Load_Reg_Ref_Unaligned(list: TAsmList; fromsize, tosize: TCgSize; register: TRegister; const ref: TReference);
      var
        href: TReference;
        hreg1, hreg2, tmpreg: TRegister;
      begin
        if fromsize in [OS_64,OS_S64] then
          begin
            { split into two 32 bit stores }
            hreg1:=GetIntRegister(list,OS_32);
            hreg2:=GetIntRegister(list,OS_32);
            A_Load_Reg_Reg(list,OS_32,OS_32,MakeRegSize(register,OS_32),hreg1);
            A_Op_Const_Reg_Reg(list,OP_SHR,OS_64,32,register,MakeRegSize(hreg2,OS_64));
            { can we use STP? }
            if (ref.Alignment=4) and
               (simple_ref_type(A_STP,OS_32,PF_None,ref)=sr_simple) then
              list.concat(TAICPU.op_reg_reg_ref(A_STP,hreg1,hreg2,ref))
            else
              begin
                A_Load_Reg_Ref(list,OS_32,OS_32,hreg1,ref);
                href:=ref;
                inc(href.Offset,4);
                A_Load_Reg_Ref(list,OS_32,OS_32,hreg2,href);
              end;
          end
       else
         inherited;
      end;


    procedure TCGAArch64.maybeadjustresult(list: TAsmList; op: TOpCG; size: TCgSize; dst: TRegister);
      const
        overflowops = [OP_MUL,OP_IMUL,OP_SHL,OP_ADD,OP_SUB,OP_NOT,OP_NEG];
      begin
        if (op in overflowops) and
           (size in [OS_8,OS_S8,OS_16,OS_S16]) then
          A_Load_Reg_Reg(list,OS_32,size,MakeRegSize(dst,OS_32),MakeRegSize(dst,OS_32))
      end;


    procedure TCGAArch64.A_Op_Const_Reg(list: TAsmList; op: TOpCG; size: TCgSize; a: TCGInt; reg: TRegister);
      begin
        Optimize_Op_Const(size,op,a);
        case op of
          OP_NONE:
            exit;
          OP_MOVE:
            A_Load_Const_Reg(list,size,a,reg);
          OP_NEG,OP_NOT:
            InternalError(200306011);
          else
            A_Op_Const_Reg_Reg(list,op,size,a,reg,reg);
        end;
      end;


    procedure TCGAArch64.A_Op_Reg_Reg(list:TAsmList;op:TOpCG;size:TCgSize;src,dst:TRegister);
      begin
        Case op of
          OP_NEG,
          OP_NOT:
            begin
              if (op=OP_NOT) and (size in [OS_8,OS_S8]) then
                list.concat(TAICPU.op_reg_reg_const(A_EOR,dst,src,255))
              else
                begin
                  list.concat(TAICPU.op_reg_reg(TOpCG2AsmOpReg[op],dst,src));
                  maybeadjustresult(list,op,size,dst);
                end;
            end
          else
            A_Op_Reg_Reg_Reg(list,op,size,src,dst,dst);
        end;
      end;


    procedure TCGAArch64.A_Op_Const_Reg_Reg(list: TAsmList; op: TOpCG; size: TCgSize; a: TCGInt; src, dst: TRegister);
      var
        l: TLocation;
      begin
        A_Op_Const_Reg_Reg_CheckOverflow(list,op,size,a,src,dst,false,l);
      end;


    procedure TCGAArch64.A_Op_Reg_Reg_Reg(list: TAsmList; op: TOpCG; size: TCgSize; src1, src2, dst: TRegister);
      var
        hreg: TRegister;
      begin
        { no ROLV opcode... }
        if op=OP_ROL then
          begin
            case size of
              OS_32,OS_S32,
              OS_64,OS_S64:
                begin
                  hreg:=GetIntRegister(list,size);
                  A_Load_Const_Reg(list,size,TCgSize2Size[size]*8,hreg);
                  A_Op_Reg_Reg(list,OP_SUB,size,src1,hreg);
                  A_Op_Reg_Reg_Reg(list,OP_ROR,size,hreg,src2,dst);
                  exit;
                end;
              else
                InternalError(2014111005);
            end;
          end
        else if (op=OP_ROR) and
           not(size in [OS_32,OS_S32,OS_64,OS_S64]) then
          InternalError(2014111006);
        if TOpCG2AsmOpReg[op]=A_NONE then
          InternalError(2014111007);
        list.concat(TAICPU.op_reg_reg_reg(TOpCG2AsmOpReg[op],dst,src2,src1));
        maybeadjustresult(list,op,size,dst);
      end;


    procedure TCGAArch64.A_Op_Const_Reg_Reg_CheckOverflow(list: TAsmList; op: TOpCG; size: TCgSize; a: TCGInt; src, dst: TRegister; setflags : boolean; var ovloc : TLocation);
      var
        shiftcountmask: LongInt;
        constreg: TRegister;
      begin
        { add/sub instructions have only positive immediate operands }
        if (op in [OP_ADD,OP_SUB]) and
           (a<0) and
           { this might result in a false positive overflow in case of a+0 }
           (a<>$8000000000000000) then
          begin
            if op=OP_ADD then
              op:=op_SUB
            else
              op:=OP_ADD;
            { avoid range/overflow error in case a = low(tcgint) }
{$push}{$r-}{$q-}
            a:=-a;
{$pop}
          end;
        ovloc.Loc:=LOC_VOID;
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
        case op of
          OP_ADD,
          OP_SUB:
            begin
              handle_reg_imm12_reg(list,TOpCG2AsmOpImm[op],size,src,a,dst,NR_NO,setflags,true);
              { on a 64 bit target, overflows with smaller data types
                are handled via range errors }
              if setflags and
                 (size in [OS_64,OS_S64]) then
                begin
                  Location_Reset(ovloc,LOC_FLAGS,OS_8);
                  if size=OS_64 then
                    if op=OP_ADD then
                      ovloc.ResFlags:=F_CS
                    else
                      ovloc.ResFlags:=F_CC
                  else
                    ovloc.ResFlags:=F_VS;
                end;
            end;
          OP_OR,
          OP_AND,
          OP_XOR:
            begin
              if not(size in [OS_64,OS_S64]) then
                a:=cardinal(a);
              if is_shifter_const(a,size) then
                list.concat(TAICPU.op_reg_reg_const(TOpCG2AsmOpReg[op],dst,src,a))
              else
                begin
                  constreg:=GetIntRegister(list,size);
                  A_Load_Const_Reg(list,size,a,constreg);
                  A_Op_Reg_Reg_Reg(list,op,size,constreg,src,dst);
                end;
            end;
          OP_SHL,
          OP_SHR,
          OP_SAR:
            begin
              if size in [OS_64,OS_S64] then
                shiftcountmask:=63
              else
                shiftcountmask:=31;
              if (a and shiftcountmask)<>0 Then
                list.concat(TAICPU.op_reg_reg_const(
                  TOpCG2AsmOpImm[Op],dst,src,a and shiftcountmask))
              else
                A_Load_Reg_Reg(list,size,size,src,dst);
              if (a and not(TCGInt(shiftcountmask)))<>0 then
                InternalError(2014112101);
            end;
          OP_ROL,
          OP_ROR:
            begin
              case size of
                OS_32,OS_S32:
                  if (a and not(TCGInt(31)))<>0 then
                    InternalError(2014112102);
                OS_64,OS_S64:
                  if (a and not(TCGInt(63)))<>0 then
                    InternalError(2014112103);
                else
                  InternalError(2014112104);
              end;
              { there's only a ror opcode }
              if op=OP_ROL then
                a:=(TCgSize2Size[size]*8)-a;
              list.concat(TAICPU.op_reg_reg_const(A_ROR,dst,src,a));
            end;
          OP_MUL,
          OP_IMUL,
          OP_DIV,
          OP_IDIV:
            begin
              constreg:=GetIntRegister(list,size);
              A_Load_Const_Reg(list,size,a,constreg);
              A_Op_Reg_Reg_Reg_CheckOverflow(list,op,size,constreg,src,dst,setflags,ovloc);
            end;
          else
            InternalError(2014111403);
        end;
        maybeadjustresult(list,op,size,dst);
      end;


    procedure TCGAArch64.A_Op_Reg_Reg_Reg_CheckOverflow(list: TAsmList; op: TOpCG; size: TCgSize; src1, src2, dst: TRegister; setflags : boolean; var ovloc : TLocation);
      var
        tmpreg1, tmpreg2: TRegister;
      begin
        ovloc.Loc:=LOC_VOID;
        { overflow can only occur with 64 bit calculations on 64 bit cpus }
        if setflags and
           (size in [OS_64,OS_S64]) then
          begin
            case op of
              OP_ADD,
              OP_SUB:
                begin
                  list.concat(setoppostfix(TAICPU.op_reg_reg_reg(TOpCG2AsmOpReg[op],dst,src2,src1),PF_S));
                  ovloc.Loc:=LOC_FLAGS;
                  if size=OS_64 then
                    if op=OP_ADD then
                      ovloc.ResFlags:=F_CS
                    else
                      ovloc.ResFlags:=F_CC
                  else
                    ovloc.ResFlags:=F_VS;
                  { finished }
                  exit;
                end;
              OP_MUL:
                begin
                  { check whether the upper 64 bit of the 128 bit product is 0 }
                  tmpreg1:=GetIntRegister(list,OS_64);
                  list.concat(TAICPU.op_reg_reg_reg(A_UMULH,tmpreg1,src2,src1));
                  list.concat(TAICPU.op_reg_const(A_CMP,tmpreg1,0));
                  ovloc.Loc:=LOC_FLAGS;
                  ovloc.ResFlags:=F_NE;
                  { still have to perform the actual multiplication  }
                end;
              OP_IMUL:
                begin
                  { check whether the upper 64 bits of the 128 bit multiplication
                    result have the same value as the replicated sign bit of the
                    lower 64 bits }
                  tmpreg1:=GetIntRegister(list,OS_64);
                  list.concat(TAICPU.op_reg_reg_reg(A_SMULH,tmpreg1,src2,src1));
                  { calculate lower 64 bits (afterwards, because dst may be
                    equal to src1 or src2) }
                  A_Op_Reg_Reg_Reg(list,op,size,src1,src2,dst);
                  { replicate sign bit }
                  tmpreg2:=GetIntRegister(list,OS_64);
                  A_Op_Const_Reg_Reg(list,OP_SAR,OS_S64,63,dst,tmpreg2);
                  list.concat(TAICPU.op_reg_reg(A_CMP,tmpreg1,tmpreg2));
                  ovloc.Loc:=LOC_FLAGS;
                  ovloc.ResFlags:=F_NE;
                  { finished }
                  exit;
                end;
              OP_IDIV,
              OP_DIV:
                begin
                  { not handled here, needs div-by-zero check (dividing by zero
                    just gives a 0 result on aarch64), and low(int64) div -1
                    check for overflow) }
                  InternalError(2014122101);
                end;
              else
                InternalError(2019050936);
            end;
          end;
        A_Op_Reg_Reg_Reg(list,op,size,src1,src2,dst);
      end;



  {*************** compare instructions ****************}

    procedure TCGAArch64.A_Cmp_Const_Reg_Label(list: TAsmList; size: TCgSize; cmp_op: TOpCmp; a: TCGInt; reg: TRegister; l: TAsmLabel);
      var
        op: TAsmOp;
      begin
        if a>=0 then
          op:=A_CMP
        else
          op:=A_CMN;
        { avoid range/overflow error in case a=low(tcgint) }
{$push}{$r-}{$q-}
        handle_reg_imm12_reg(list,op,size,reg,abs(a),NR_XZR,NR_NO,false,false);
{$pop}
        a_jmp_cond(list,cmp_op,l);
      end;


    procedure TCGAArch64.A_Cmp_Reg_Reg_Label(list: TAsmList; size: TCgSize; cmp_op: TOpCmp; reg1,reg2: TRegister; l: TAsmLabel);
      begin
        list.concat(TAICPU.op_reg_reg(A_CMP,reg2,reg1));
        a_jmp_cond(list,cmp_op,l);
      end;


    procedure TCGAArch64.A_Jmp_Always(list: TAsmList; l: TAsmLabel);
      var
        ai: TAICPU;
      begin
        ai:=TAICPU.op_sym(A_B,CurrentAsmData.RefAsmSymbol(l.name,AT_FUNCTION));
        ai.is_jmp:=true;
        list.Concat(ai);
      end;


    procedure TCGAArch64.A_Jmp_Name(list: TAsmList; const s: string);
      var
        ai: TAICPU;
      begin
        ai:=TAICPU.op_sym(A_B,CurrentAsmData.RefAsmSymbol(s,AT_FUNCTION));
        ai.is_jmp:=true;
        list.Concat(ai);
      end;


    procedure TCGAArch64.a_jmp_cond(list: TAsmList; cond: TOpCmp; l: TAsmLabel);
      var
        ai: TAICPU;
      begin
        ai:=TAICPU.op_sym(A_B,l);
        ai.is_jmp:=true;
        ai.SetCondition(TOpCmp2AsmCond[cond]);
        list.Concat(ai);
      end;


    procedure TCGAArch64.A_Jmp_Flags(list: TAsmList; const f: TResFlags; l: TAsmLabel);
      var
        ai : TAICPU;
      begin
        ai:=TAICPU.op_sym(A_B,l);
        ai.is_jmp:=true;
        ai.SetCondition(flags_to_cond(f));
        list.Concat(ai);
      end;


    procedure TCGAArch64.G_Flags2Reg(list: TAsmList; size: TCgSize; const f: TResFlags; reg: TRegister);
      begin
        list.concat(TAICPU.op_reg_cond(A_CSET,reg,flags_to_cond(f)));
      end;


    procedure TCGAArch64.G_OverflowCheck(list: TAsmList; const loc: TLocation; def: TDef);
      begin
        { we need an explicit overflow location, because there are many
          possibilities (not just the overflow flag, which is only used for
          signed add/sub) }
        InternalError(2014112303);
      end;


    procedure TCGAArch64.G_OverflowCheck_Loc(list: TAsmList; const loc: TLocation; def: TDef; ovloc : TLocation);
      var
        hl : TAsmLabel;
        hflags : TResFlags;
      begin
        if not(cs_check_overflow in CurrentSettings.LocalSwitches) then
          exit;
        CurrentAsmData.getjumplabel(hl);
        case ovloc.Loc of
          LOC_FLAGS:
            begin
              hflags:=ovloc.ResFlags;
              inverse_flags(hflags);
              cg.A_Jmp_Flags(list,hflags,hl);
            end;
          else
            InternalError(2014112304);
        end;
        A_Call_Name(list,'FPC_OVERFLOW',false);
        A_Label(list,hl);
      end;

  { *********** entry/exit code and address loading ************ }

    function TCGAArch64.save_regs(list: TAsmList; rt: TRegisterType; lowsr, highsr: TSuperRegister; sub: TSubRegister): LongInt;
      var
        ref: TReference;
        sr: TSuperRegister;
        pairreg: TRegister;
        sehreg,sehregp : TAsmSehDirective;
      begin
        result:=0;
        Reference_Reset_Base(ref,NR_SP,-16,CTempPosInvalid,16,[]);
        ref.AddressMode:=AM_PREINDEXED;
        pairreg:=NR_NO;
        { for SEH on Win64 we can only store consecutive register pairs, others
          need to be stored with STR }
        if TargetInfo.system=system_aarch64_win64 then
          begin
            if rt=R_INTREGISTER then
              begin
                sehreg:=ash_savereg_x;
                sehregp:=ash_saveregp_x;
              end
            else if rt=R_MMREGISTER then
              begin
                sehreg:=ash_savefreg_x;
                sehregp:=ash_savefregp_x;
              end
            else
              InternalError(2020041304);
            for sr:=lowsr to highsr do
              if sr in rg[rt].UsedInProc then
                if pairreg=NR_NO then
                  pairreg:=NewReg(rt,sr,sub)
                else
                  begin
                    inc(result,16);
                    if GetSupReg(pairreg)=sr-1 then
                      begin
                        list.concat(TAICPU.op_reg_reg_ref(A_STP,pairreg,NewReg(rt,sr,sub),ref));
                        list.concat(CAISEHDirective.create_reg_offset(sehregp,pairreg,16));
                        pairreg:=NR_NO;
                      end
                    else
                      begin
                        list.concat(TAICPU.op_reg_ref(A_STR,pairreg,ref));
                        list.concat(CAISEHDirective.create_reg_offset(sehreg,pairreg,16));
                        pairreg:=NewReg(rt,sr,sub);
                      end;
                  end;
            if pairreg<>NR_NO then
              begin
                inc(result,16);
                list.concat(TAICPU.op_reg_ref(A_STR,pairreg,ref));
                list.concat(CAISEHDirective.create_reg_offset(sehreg,pairreg,16));
              end;
          end
        else
          begin
            { store all used registers pairwise }
            for sr:=lowsr to highsr do
              if sr in rg[rt].UsedInProc then
                if pairreg=NR_NO then
                  pairreg:=NewReg(rt,sr,sub)
                else
                  begin
                    inc(result,16);
                    list.concat(TAICPU.op_reg_reg_ref(A_STP,pairreg,NewReg(rt,sr,sub),ref));
                    pairreg:=NR_NO
                  end;
            { one left -> store twice (stack must be 16 bytes aligned) }
            if pairreg<>NR_NO then
              begin
                list.concat(TAICPU.op_reg_reg_ref(A_STP,pairreg,pairreg,ref));
                inc(result,16);
              end;
          end;
      end;


    procedure FixupOffsets(p:TObject;arg:pointer);
      var
        sym: TAbstractNormalVarSym absolute p;
      begin
        if (TSym(p).typ in [paravarsym,localvarsym]) and
          (sym.LocAlloc.Loc=LOC_REFERENCE) and
          (sym.LocAlloc.Reference.Base=NR_STACK_POINTER_REG) then
          begin
            sym.LocAlloc.Reference.Base:=NR_FRAME_POINTER_REG;
            dec(sym.LocAlloc.Reference.Offset,PLongInt(arg)^);
          end;
      end;


    procedure TCGAArch64.G_StackPointer_Alloc(list : TAsmList;localsize : LongInt);
      var
        href : TReference;
        i : integer;
        again : TAsmLabel;
      begin
        if localsize>0 then
         begin
           { windows guards only a few pages for stack growing,
             so we have to access every page first              }
           if (TargetInfo.system=system_aarch64_win64) and
              (localsize>=winstackpagesize) then
             begin
               if localsize div winstackpagesize<=4 then
                 begin
                   handle_reg_imm12_reg(list,A_SUB,OS_ADDR,NR_SP,localsize,NR_SP,NR_IP0,false,true);
                   for i:=1 to localsize div winstackpagesize do
                     begin
                       Reference_Reset_Base(href,NR_SP,localsize-i*winstackpagesize+4,CTempPosInvalid,4,[]);
                       list.concat(TAICPU.op_reg_ref(A_STR,NR_WZR,href));
                     end;
                   Reference_Reset_Base(href,NR_SP,0,CTempPosInvalid,4,[]);
                   list.concat(TAICPU.op_reg_ref(A_STR,NR_WZR,href));
                 end
               else
                 begin
                    CurrentAsmData.getjumplabel(again);
                    GetCPURegister(list,NR_IP0);
                    A_Load_Const_Reg(list,OS_ADDR,localsize div winstackpagesize,NR_IP0);
                    A_Label(list,again);
                    handle_reg_imm12_reg(list,A_SUB,OS_ADDR,NR_SP,winstackpagesize,NR_SP,NR_IP1,false,true);
                    Reference_Reset_Base(href,NR_SP,0,CTempPosInvalid,4,[]);
                    list.concat(TAICPU.op_reg_ref(A_STR,NR_WZR,href));
                    list.concat(setoppostfix(TAICPU.op_reg_reg_const(A_SUB,NR_IP0,NR_IP0,1),PF_S));
                    a_jmp_cond(list,OC_NE,again);
                    handle_reg_imm12_reg(list,A_SUB,OS_ADDR,NR_SP,localsize mod winstackpagesize,NR_SP,NR_IP1,false,true);
                    UngetCPURegister(list,NR_IP0);
                 end
             end
           else
             begin
               handle_reg_imm12_reg(list,A_SUB,OS_ADDR,NR_SP,localsize,NR_SP,NR_IP0,false,true);
             end;
           { the allocation has to be described whichever way it was performed:
             without this the .xdata is missing the frame size, and a function
             that needs no other directive gets no .pdata entry at all, so
             Windows treats it as a frameless leaf }
           if TargetInfo.system=system_aarch64_win64 then
             list.concat(CAISEHDirective.create_offset(ash_stackalloc,localsize));
         end;
      end;


    procedure TCGAArch64.G_Proc_Entry(list: TAsmList; localsize: LongInt; nostackframe: boolean);
      var
        hitem: TLinkedListItem;
        seh_proc: TAISEHDirective;
        TempList: TAsmList;
        genloadframeforexcept,
        suppress_endprologue: boolean;
        ref: TReference;
        totalstackframesize: LongInt;
      begin
        { on aarch64, we need to store the link register and the generate a frame pointer if the subroutine either
          - receives parameters on the stack
          - is not a leaf procedure
          - has nested procedures
          - helpers retrieve the stack pointer
        }

        hitem:=list.last;
        { pi_has_unwind_info may already be set at this point if there are
          SEH directives in assembler body. In this case, .seh_endprologue
          is expected to be one of those directives, and not generated here. }
        suppress_endprologue:=(pi_has_unwind_info in CurrentProcInfo.flags);
        genloadframeforexcept:=false;

        if not nostackframe then
          begin
            { stack pointer has to be aligned to 16 bytes at all times }
            localsize:=align(localsize,16);

            if TargetInfo.system=system_aarch64_win64 then
              include(CurrentProcInfo.flags,pi_has_unwind_info);
            if not(pi_no_framepointer_needed in CurrentProcInfo.flags) then
              begin
                { save stack pointer and return address }
                Reference_Reset_Base(ref,NR_SP,-16,CTempPosInvalid,16,[]);
                ref.AddressMode:=AM_PREINDEXED;
                list.concat(TAICPU.op_reg_reg_ref(A_STP,NR_FP,NR_LR,ref));
                CurrentAsmData.asmcfi.cfa_def_cfa_offset(list,2*sizeof(PInt));
                CurrentAsmData.asmcfi.cfa_offset(list,NR_FP,-16);
                CurrentAsmData.asmcfi.cfa_offset(list,NR_LR,-8);
                if TargetInfo.system=system_aarch64_win64 then
                  list.concat(CAISEHDirective.create_offset(ash_savefplr_x,16));
                { initialise frame pointer }
                if CurrentProcInfo.procdef.ProcTypeOption<>potype_exceptfilter then
                  begin
                    A_Load_Reg_Reg(list,OS_ADDR,OS_ADDR,NR_SP,NR_FP);
                    CurrentAsmData.asmcfi.cfa_def_cfa_register(list,NR_FP);
                    if TargetInfo.system=system_aarch64_win64 then
                      list.concat(CAISEHDirective.Create(ash_setfp));
                  end
                else
                  begin
                    { do this after the prologue is done for aarch64-win64 as
                      there is no SEH directive for setting FP to a register }
                    if TargetInfo.system<>system_aarch64_win64 then
                      Gen_Load_Frame_For_ExceptFilter(list)
                    else
                      genloadframeforexcept:=true;
                    { On AArch64-Win64, the exceptfilter handler's own temps
                      are SP-relative (not mapped to parent frame). Allocate
                      enough stack for all handler temps (calc_stackframe_size)
                      and also for the handler's outgoing call parameters. }
                    if TargetInfo.system=system_aarch64_win64 then
                      begin
                        localsize:=CurrentProcInfo.Calc_StackFrame_Size;
                        if Align(CurrentProcInfo.MaxPushedParaSize,16)>localsize then
                          localsize:=Align(CurrentProcInfo.MaxPushedParaSize,16);
                      end
                    else
                      localsize:=CurrentProcInfo.MaxPushedParaSize;
                  end;
              end;

            totalstackframesize:=0;
            { save modified integer registers }
            inc(totalstackframesize,
              save_regs(list,R_INTREGISTER,RS_X19,RS_X28,R_SUBWHOLE));
            { only the lower 64 bits of the modified vector registers need to be
              saved; if the caller needs the upper 64 bits, it has to save them
              itself }
            inc(totalstackframesize,
              save_regs(list,R_MMREGISTER,RS_D8,RS_D15,R_SUBMMD));

            { allocate stack space }
            if localsize<>0 then
              begin
                localsize:=align(localsize,16);
                CurrentProcInfo.FinalLocalSize:=localsize;
                G_StackPointer_Alloc(list,localsize);
                inc(totalstackframesize,localsize);
              end;

            { Store total stack frame size for use by exceptfilter temp access.
              This is the offset from FP to SP after prolog completes, including
              saved registers and local variables. }
            TCPUProcInfo(CurrentProcInfo).TotalStackFrameSize:=totalstackframesize;
            { By default, we use the frame pointer to access parameters passed via
              the stack and the stack pointer to address local variables and temps
              because
               a) we can use bigger positive than negative offsets (so accessing
                  locals via negative offsets from the frame pointer would be less
                  efficient)
               b) we don't know the local size while generating the code, so
                  accessing the parameters via the stack pointer is not possible
                  without copying them
              The problem with this is the get_frame() intrinsic:
               a) it must return the same value as what we pass as parentfp
                  parameter, since that's how it's used in the TP-style objects unit
               b) its return value must usable to access all local data from a
                  routine (locals and parameters), since it's all the nested
                  routines have access to
               c) its return value must be usable to construct a backtrace, as it's
                  also used by the exception handling routines

              The solution we use here, based on something similar that's done in
              the MIPS port, is to generate all accesses to locals in the routine
              itself SP-relative, and then after the code is generated and the local
              size is known (namely, here), we change all SP-relative variables/
              parameters into FP-relative ones. This means that they'll be accessed
              less efficiently from nested routines, but those accesses are indirect
              anyway and at least this way they can be accessed at all
            }
            if CurrentProcInfo.Has_NestedProcs or
               (
                 (TargetInfo.system=system_aarch64_win64) and
                 (CurrentProcInfo.flags*[pi_has_implicit_finally,pi_needs_implicit_finally,pi_uses_exceptions]<>[])
               ) then
              begin
                CurrentProcInfo.procdef.LocalST.SymList.ForEachCall(@FixupOffsets,@totalstackframesize);
                CurrentProcInfo.procdef.ParaST.SymList.ForEachCall(@FixupOffsets,@totalstackframesize);
              end;
          end;

        if not (pi_has_unwind_info in CurrentProcInfo.flags) then
          begin
            if genloadframeforexcept then
              Gen_Load_Frame_For_ExceptFilter(list);
            exit;
          end;

        { Generate unwind data for aarch64-win64 }
        seh_proc:=CAISEHDirective.create_name(ash_proc,CurrentProcInfo.procdef.MangledName);
        if Assigned(hitem) then
          list.insertafter(seh_proc,hitem)
        else
          list.insert(seh_proc);
        { the directive creates another section }
        inc(list.section_count);
        TempList:=TAsmList.Create;

        if not suppress_endprologue then
          begin
            TempList.concat(CAISEHDirective.Create(ash_endprologue));
          end;
        if Assigned(CurrentProcInfo.EndPrologueAI) then
          CurrentProcInfo.AktProcCode.InsertListAfter(CurrentProcInfo.EndPrologueAI,TempList)
        else
          list.ConcatList(TempList);
        TempList.free;

        if genloadframeforexcept then
          Gen_Load_Frame_For_ExceptFilter(list);
      end;


    procedure TCGAArch64.G_Maybe_Got_Init(list : TAsmList);
      begin
        { nothing to do on Darwin or Linux }
      end;


    procedure TCGAArch64.G_Restore_Registers(list:TAsmList);
      begin
        { done in g_proc_exit }
      end;


    procedure TCGAArch64.load_regs(list: TAsmList; rt: TRegisterType; lowsr, highsr: TSuperRegister; sub: TSubRegister);
      var
        ref: TReference;
        sr, highestsetsr: TSuperRegister;
        pairreg: TRegister;
        i,
        regcount: LongInt;
        aiarr : array of TAI;
      begin
        Reference_Reset_Base(ref,NR_SP,16,CTempPosInvalid,16,[]);
        ref.AddressMode:=AM_POSTINDEXED;
        regcount:=0;
        { due to SEH on Win64 we can only load consecutive registers and single
          ones are done using LDR, so we need to handle this differently there }
        if TargetInfo.system=system_aarch64_win64 then
          begin
            SetLength(aiarr,highsr-lowsr+1);
            pairreg:=NR_NO;
            for sr:=lowsr to highsr do
              if sr in rg[rt].UsedInProc then
                begin
                  if pairreg=NR_NO then
                    pairreg:=NewReg(rt,sr,sub)
                  else
                    begin
                      if GetSupReg(pairreg)=sr-1 then
                        begin
                          aiarr[regcount]:=TAICPU.op_reg_reg_ref(A_LDP,pairreg,NewReg(rt,sr,sub),ref);
                          inc(regcount);
                          pairreg:=NR_NO;
                        end
                      else
                        begin
                          aiarr[regcount]:=TAICPU.op_reg_ref(A_LDR,pairreg,ref);
                          inc(regcount);
                          pairreg:=NewReg(rt,sr,sub);
                        end;
                    end;
                end;
            if pairreg<>NR_NO then
              begin
                aiarr[regcount]:=TAICPU.op_reg_ref(A_LDR,pairreg,ref);
                inc(regcount);
                pairreg:=NR_NO;
              end;
            for i:=regcount-1 downto 0 do
              list.concat(aiarr[i]);
          end
        else
          begin
            { highest reg stored twice? }
            highestsetsr:=RS_NO;
            for sr:=lowsr to highsr do
              if sr in rg[rt].UsedInProc then
                begin
                  inc(regcount);
                  highestsetsr:=sr;
                end;
            if odd(regcount) then
              begin
                list.concat(TAICPU.op_reg_ref(A_LDR,NewReg(rt,highestsetsr,sub),ref));
                highestsetsr:=pred(highestsetsr);
              end;
            { load all (other) used registers pairwise }
            pairreg:=NR_NO;
            for sr:=highestsetsr downto lowsr do
              if sr in rg[rt].UsedInProc then
                if pairreg=NR_NO then
                  pairreg:=NewReg(rt,sr,sub)
                else
                  begin
                    list.concat(TAICPU.op_reg_reg_ref(A_LDP,NewReg(rt,sr,sub),pairreg,ref));
                    pairreg:=NR_NO
                  end;
          end;
        { There can't be any register left }
        if pairreg<>NR_NO then
          InternalError(2014112602);
      end;


    procedure TCGAArch64.G_Proc_Exit(list : TAsmList;parasize:LongInt;nostackframe:boolean);
      var
        ref: TReference;
        regsstored: boolean;
        sr: TSuperRegister;
      begin
        if not(nostackframe) and
          { we do not need an exit stack frame when we never return

            * the final ret is left so the peephole optimizer can easily do call/ret -> jmp or call conversions
            * the entry stack frame must be normally generated because the subroutine could be still left by
              an exception and then the unwinding code might need to restore the registers stored by the entry code
          }
          not(po_noreturn in CurrentProcInfo.procdef.ProcOptions) then
          begin
            { if no registers have been stored, we don't have to subtract the
              allocated temp space from the stack pointer }
            regsstored:=false;
            for sr:=RS_X19 to RS_X28 do
              if sr in rg[R_INTREGISTER].UsedInProc then
                begin
                  regsstored:=true;
                  break;
                end;
            if not regsstored then
              for sr:=RS_D8 to RS_D15 do
                if sr in rg[R_MMREGISTER].UsedInProc then
                  begin
                    regsstored:=true;
                    break;
                  end;
            { restore registers (and stack pointer) }
            if regsstored then
              begin
                if CurrentProcInfo.FinalLocalSize<>0 then
                  handle_reg_imm12_reg(list,A_ADD,OS_ADDR,NR_SP,CurrentProcInfo.FinalLocalSize,NR_SP,NR_IP0,false,true);
                load_regs(list,R_MMREGISTER,RS_D8,RS_D15,R_SUBMMD);
                load_regs(list,R_INTREGISTER,RS_X19,RS_X28,R_SUBWHOLE);
                { on Windows also restore SP even if the add should be enough
                  to have matching exit sequence to the entry sequence.
                  Skip for exceptfilters where FP points to parent's frame, not local frame. }
                if (TargetInfo.system=system_aarch64_win64) and
                   (CurrentProcInfo.procdef.ProcTypeOption<>potype_exceptfilter) then
                  A_Load_Reg_Reg(list,OS_ADDR,OS_ADDR,NR_FP,NR_SP);
              end
            else if CurrentProcInfo.FinalLocalSize<>0 then
              begin
                { restore stack pointer }
                { Note: for Windows we need to restore the stack using an ADD
                        and to set FP back to SP }
                if TargetInfo.system=system_aarch64_win64 then
                  begin
                    handle_reg_imm12_reg(list,A_ADD,OS_ADDR,CurrentProcInfo.FramePointer,CurrentProcInfo.FinalLocalSize,
                      CurrentProcInfo.FramePointer,NR_IP0,false,true);
                    { Skip mov sp,fp for exceptfilters where FP points to parent's frame }
                    if not (pi_no_framepointer_needed in CurrentProcInfo.flags) and
                       (CurrentProcInfo.procdef.ProcTypeOption<>potype_exceptfilter) then
                      A_Load_Reg_Reg(list,OS_ADDR,OS_ADDR,NR_FP,NR_SP);
                  end
                else if pi_no_framepointer_needed in CurrentProcInfo.flags then
                  handle_reg_imm12_reg(list,A_ADD,OS_ADDR,CurrentProcInfo.FramePointer,CurrentProcInfo.FinalLocalSize,
                    CurrentProcInfo.FramePointer,NR_IP0,false,true)
                else if CurrentProcInfo.procdef.ProcTypeOption<>potype_exceptfilter then
                  { Skip for exceptfilters where FP points to parent's frame }
                  A_Load_Reg_Reg(list,OS_ADDR,OS_ADDR,NR_FP,NR_SP);
              end;

            if not(pi_no_framepointer_needed in CurrentProcInfo.flags) then
              begin
                { restore framepointer and return address }
                Reference_Reset_Base(ref,NR_SP,16,CTempPosInvalid,16,[]);
                ref.AddressMode:=AM_POSTINDEXED;
                list.concat(TAICPU.op_reg_reg_ref(A_LDP,NR_FP,NR_LR,ref));
              end;
          end;

        { return }
        list.concat(TAICPU.op_none(A_RET));
        if (pi_has_unwind_info in CurrentProcInfo.flags) then
          begin
            TCPUProcInfo(CurrentProcInfo).Dump_Scopes(list);
            list.concat(CAISEHDirective.Create(ash_endproc));
          end;
      end;


    procedure TCGAArch64.G_Save_Registers(list : TAsmList);
      begin
        { done in g_proc_entry }
      end;


    procedure TCGAArch64.G_ConcatCopy(list: TAsmList; const source, dest: TReference; len: TCGInt);

      var
        sourcebasereplaced, destbasereplaced: boolean;

      { get optimal memory operation to use for loading/storing data
        in an unrolled loop }
      procedure getmemop(scaledop, unscaledop: TAsmOp; const startref, endref: TReference; opsize: TCgSize; postfix: TOpPostfix; out memop: TAsmOp; out needsimplify: boolean);
        begin
          if (simple_ref_type(scaledop,opsize,postfix,startref)=sr_simple) and
             (simple_ref_type(scaledop,opsize,postfix,endref)=sr_simple) then
            begin
              memop:=unscaledop;
              needsimplify:=true;
            end
          else if (unscaledop<>A_NONE) and
             (simple_ref_type(unscaledop,opsize,postfix,startref)=sr_simple) and
             (simple_ref_type(unscaledop,opsize,postfix,endref)=sr_simple) then
            begin
              memop:=unscaledop;
              needsimplify:=false;
            end
          else
            begin
              memop:=scaledop;
              needsimplify:=true;
            end;
        end;

      { adjust the offset and/or addressing mode after a load/store so it's
        correct for the next one of the same size }
      procedure updaterefafterloadstore(var ref: TReference; oplen: LongInt);
        begin
          case ref.AddressMode of
            AM_OFFSET:
              inc(ref.Offset,oplen);
            AM_POSTINDEXED:
              { base register updated by instruction, next offset can remain
                the same }
              ;
            AM_PREINDEXED:
              begin
                { base register updated by instruction -> next instruction can
                  use post-indexing with offset = sizeof(operation) }
                ref.Offset:=0;
                ref.AddressMode:=AM_OFFSET;
              end;
          end;
        end;

      { generate a load/store and adjust the reference offset to the next
        memory location if necessary }
      procedure genloadstore(list: TAsmList; op: TAsmOp; reg: TRegister; var ref: TReference; postfix: TOpPostfix; opsize: TCgSize);
        begin
          list.concat(setoppostfix(TAICPU.op_reg_ref(op,reg,ref),postfix));
          updaterefafterloadstore(ref,TCgSize2Size[opsize]);
        end;

      { generate a dual load/store (ldp/stp) and adjust the reference offset to
        the next memory location if necessary }
      procedure gendualloadstore(list: TAsmList; op: TAsmOp; reg1, reg2: TRegister; var ref: TReference; postfix: TOpPostfix; opsize: TCgSize);
        begin
          list.concat(setoppostfix(TAICPU.op_reg_reg_ref(op,reg1,reg2,ref),postfix));
          updaterefafterloadstore(ref,TCgSize2Size[opsize]*2);
        end;

      { turn a reference into a pre- or post-indexed reference for use in a
        load/store of a particular size }
      procedure makesimpleforcopy(list: TAsmList; var scaledop: TAsmOp; opsize: TCgSize; postfix: TOpPostfix; forcepostindexing: boolean; var ref: TReference; var basereplaced: boolean);
        var
          tmpreg: TRegister;
          scaledoffset: LongInt;
          orgaddressmode: TAddressMode;
        begin
          scaledoffset:=TCgSize2Size[opsize];
          if scaledop in [A_LDP,A_STP] then
            scaledoffset:=scaledoffset*2;
          { can we use the reference as post-indexed without changes? }
          if forcepostindexing then
            begin
              orgaddressmode:=ref.AddressMode;
              ref.AddressMode:=AM_POSTINDEXED;
              if (orgaddressmode=AM_POSTINDEXED) or
                 ((ref.Offset=0) and
                  (simple_ref_type(scaledop,opsize,postfix,ref)=sr_simple)) then
                begin
                  { just change the post-indexed offset to the access size }
                  ref.Offset:=scaledoffset;
                  { and replace the base register if that didn't happen yet
                    (could be sp or a regvar) }
                  if not basereplaced then
                    begin
                      tmpreg:=GetAddressRegister(list);
                      A_Load_Reg_Reg(list,OS_ADDR,OS_ADDR,ref.Base,tmpreg);
                      ref.Base:=tmpreg;
                      basereplaced:=true;
                    end;
                  exit;
                end;
              ref.AddressMode:=orgaddressmode;
            end;
          if not forcepostindexing then
            begin
              ref.AddressMode:=AM_OFFSET;
              make_simple_ref(list,scaledop,opsize,postfix,ref,NR_NO);
              { this may still cause problems if the final offset is no longer
                a simple ref; it's a bit complicated to pass all information
                through at all places and check that here, so play safe: we
                currently never generate unrolled copies for more than 64
                bytes (32 with non-double-register copies) }
              if ref.Index=NR_NO then
                begin
                  if ((scaledop in [A_LDP,A_STP]) and
                      (ref.Offset<((64-8)*TCgSize2Size[opsize]))) or
                     ((scaledop in [A_LDUR,A_STUR]) and
                      (ref.Offset<(255-8*TCgSize2Size[opsize]))) or
                     ((scaledop in [A_LDR,A_STR]) and
                      (ref.Offset<((4096-8)*TCgSize2Size[opsize]))) then
                    exit;
                end;
            end;
          tmpreg:=GetAddressRegister(list);
          A_LoadAddr_Ref_Reg(list,ref,tmpreg);
          basereplaced:=true;
          if forcepostindexing then
            begin
              Reference_Reset_Base(ref,tmpreg,scaledoffset,ref.TempPos,ref.Alignment,ref.Volatility);
              ref.AddressMode:=AM_POSTINDEXED;
            end
          else
            begin
              Reference_Reset_Base(ref,tmpreg,0,ref.TempPos,ref.Alignment,ref.Volatility);
              ref.AddressMode:=AM_OFFSET;
            end
        end;

      { prepare a reference for use by gencopy. This is done both after the
        unrolled and regular copy loop -> get rid of post-indexing mode, make
        sure ref is valid }
      procedure preparecopy(list: TAsmList; scaledop, unscaledop: TAsmOp; var ref: TReference; opsize: TCgSize; postfix: TOpPostfix; out op: TAsmOp; var basereplaced: boolean);
        var
          Simplify: boolean;
        begin
          if ref.AddressMode=AM_POSTINDEXED then
            ref.Offset:=TCgSize2Size[opsize];
          getmemop(scaledop,scaledop,ref,ref,opsize,postfix,op,Simplify);
          if Simplify then
            begin
              makesimpleforcopy(list,scaledop,opsize,postfix,false,ref,basereplaced);
              op:=scaledop;
            end;
        end;

      { generate a copy from source to dest of size opsize/postfix }
      procedure gencopy(list: TAsmList; var source, dest: TReference; postfix: TOpPostfix; opsize: TCgSize);
        var
          reg: TRegister;
          loadop, storeop: TAsmOp;
        begin
          preparecopy(list,A_LDR,A_LDUR,source,opsize,postfix,loadop,sourcebasereplaced);
          preparecopy(list,A_STR,A_STUR,dest,opsize,postfix,storeop,destbasereplaced);
          reg:=GetIntRegister(list,opsize);
          genloadstore(list,loadop,reg,source,postfix,opsize);
          genloadstore(list,storeop,reg,dest,postfix,opsize);
        end;


      { copy the leftovers after an unrolled or regular copy loop }
      procedure gencopyleftovers(list: TAsmList; var source, dest: TReference; len: LongInt);
        begin
          { stop post-indexing if we did so in the loop, since in that case all
            offsets definitely can be represented now }
          if source.AddressMode=AM_POSTINDEXED then
            begin
              source.AddressMode:=AM_OFFSET;
              source.Offset:=0;
            end;
          if dest.AddressMode=AM_POSTINDEXED then
            begin
              dest.AddressMode:=AM_OFFSET;
              dest.Offset:=0;
            end;
          { transfer the leftovers }
          if len>=8 then
            begin
              dec(len,8);
              gencopy(list,source,dest,PF_NONE,OS_64);
            end;
          if len>=4 then
            begin
              dec(len,4);
              gencopy(list,source,dest,PF_NONE,OS_32);
            end;
          if len>=2 then
            begin
              dec(len,2);
              gencopy(list,source,dest,PF_H,OS_16);
            end;
          if len>=1 then
            begin
              dec(len);
              gencopy(list,source,dest,PF_B,OS_8);
            end;
        end;


      const
        { load_length + loop dec + cbnz }
        loopoverhead=12;
        { loop overhead + load + store }
        totallooplen=loopoverhead + 8;
      var
        totalalign: LongInt;
        maxlenunrolled: TCGInt;
        loadop, storeop: TAsmOp;
        opsize: TCgSize;
        postfix: TOpPostfix;
        tmpsource, tmpdest: TReference;
        scaledstoreop, unscaledstoreop,
        scaledloadop, unscaledloadop: TAsmOp;
        regs: array[1..8] of TRegister;
        countreg: TRegister;
        i, regcount: LongInt;
        hl: TAsmLabel;
        simplifysource, simplifydest: boolean;
      begin
        if len=0 then
          exit;
        sourcebasereplaced:=false;
        destbasereplaced:=false;
        { maximum common alignment }
        totalalign:=max(1,NewAlignment(source.Alignment,dest.Alignment));
        { use a simple load/store? }
        if (len in [1,2,4,8]) and
           ((totalalign>=(len div 2)) or
            (source.Alignment=len) or
            (dest.Alignment=len)) then
          begin
            opsize:=Int_CGSize(len);
            A_Load_Ref_Ref(list,opsize,opsize,source,dest);
            exit;
          end;

        { alignment > length is not useful, and would break some checks below }
        while totalalign>len do
          totalalign:=totalalign div 2;

        { operation sizes to use based on common alignment }
        case totalalign of
          1:
            begin
              postfix:=PF_B;
              opsize:=OS_8;
            end;
          2:
            begin
              postfix:=PF_H;
              opsize:=OS_16;
            end;
          4:
            begin
              postfix:=PF_None;
              opsize:=OS_32;
            end
          else
            begin
              totalalign:=8;
              postfix:=PF_None;
              opsize:=OS_64;
            end;
        end;
        { maximum length to handled with an unrolled loop (4 loads + 4 stores) }
        maxlenunrolled:=min(totalalign,8)*4;
        { ldp/stp -> 2 registers per instruction }
        if (totalalign>=4) and
           (len>=totalalign*2) then
          begin
            maxlenunrolled:=maxlenunrolled*2;
            scaledstoreop:=A_STP;
            scaledloadop:=A_LDP;
            unscaledstoreop:=A_NONE;
            unscaledloadop:=A_NONE;
          end
        else
          begin
            scaledstoreop:=A_STR;
            scaledloadop:=A_LDR;
            unscaledstoreop:=A_STUR;
            unscaledloadop:=A_LDUR;
          end;
        { we only need 4 instructions extra to call FPC_MOVE }
        if cs_opt_size in CurrentSettings.OptimizerSwitches then
          maxlenunrolled:=maxlenunrolled div 2;
        if (len>maxlenunrolled) and
           (len>totalalign*8) and
           (pi_do_call in CurrentProcInfo.flags) then
          begin
            G_ConcatCopy_Move(list,source,dest,len);
            exit;
          end;

        simplifysource:=true;
        simplifydest:=true;
        tmpsource:=source;
        tmpdest:=dest;
        { can we directly encode all offsets in an unrolled loop? }
        if len<=maxlenunrolled then
          begin
{$ifdef extdebug}
            list.concat(TAIComment.Create(StrPNew('concatcopy unrolled loop; len/opsize/align: '+ToStr(len)+'/'+ToStr(TCgSize2Size[opsize])+'/'+ToStr(totalalign))));
{$endif extdebug}
            { the leftovers will be handled separately -> -(len mod opsize) }
            inc(tmpsource.Offset,len-(len mod TCgSize2Size[opsize]));
            { additionally, the last regular load/store will be at
              offset+len-opsize (if len-(len mod opsize)>len) }
            if tmpsource.Offset>source.Offset then
              dec(tmpsource.Offset,TCgSize2Size[opsize]);
            getmemop(scaledloadop,unscaledloadop,source,tmpsource,opsize,postfix,loadop,simplifysource);
            inc(tmpdest.Offset,len-(len mod TCgSize2Size[opsize]));
            if tmpdest.Offset>dest.Offset then
              dec(tmpdest.Offset,TCgSize2Size[opsize]);
            getmemop(scaledstoreop,unscaledstoreop,dest,tmpdest,opsize,postfix,storeop,simplifydest);
            tmpsource:=source;
            tmpdest:=dest;
            { if we can't directly encode all offsets, simplify }
            if simplifysource then
              begin
                loadop:=scaledloadop;
                makesimpleforcopy(list,loadop,opsize,postfix,false,tmpsource,sourcebasereplaced);
              end;
            if simplifydest then
              begin
                storeop:=scaledstoreop;
                makesimpleforcopy(list,storeop,opsize,postfix,false,tmpdest,destbasereplaced);
              end;
            regcount:=len div TCgSize2Size[opsize];
            { in case we transfer two registers at a time, we copy an even
              number of registers }
            if loadop=A_LDP then
              regcount:=regcount and not(1);
            { initialise for dfa }
            regs[low(regs)]:=NR_NO;
            { max 4 loads/stores -> max 8 registers (in case of ldp/stdp) }
            for i:=1 to regcount do
              regs[i]:=GetIntRegister(list,opsize);
            if loadop=A_LDP then
              begin
                { load registers }
                for i:=1 to (regcount div 2) do
                  gendualloadstore(list,loadop,regs[i*2-1],regs[i*2],tmpsource,postfix,opsize);
                { store registers }
                for i:=1 to (regcount div 2) do
                  gendualloadstore(list,storeop,regs[i*2-1],regs[i*2],tmpdest,postfix,opsize);
              end
            else
              begin
                for i:=1 to regcount do
                  genloadstore(list,loadop,regs[i],tmpsource,postfix,opsize);
                for i:=1 to regcount do
                  genloadstore(list,storeop,regs[i],tmpdest,postfix,opsize);
              end;
            { leftover }
            len:=len-regcount*TCgSize2Size[opsize];
{$ifdef extdebug}
            list.concat(TAIComment.Create(StrPNew('concatcopy unrolled loop leftover: '+ToStr(len))));
{$endif extdebug}
          end
        else
          begin
{$ifdef extdebug}
            list.concat(TAIComment.Create(StrPNew('concatcopy regular loop; len/align: '+ToStr(len)+'/'+ToStr(totalalign))));
{$endif extdebug}
            { regular loop -> definitely use post-indexing }
            loadop:=scaledloadop;
            makesimpleforcopy(list,loadop,opsize,postfix,true,tmpsource,sourcebasereplaced);
            storeop:=scaledstoreop;
            makesimpleforcopy(list,storeop,opsize,postfix,true,tmpdest,destbasereplaced);
            CurrentAsmData.getjumplabel(hl);
            countreg:=GetIntRegister(list,OS_32);
            if loadop=A_LDP then
              A_Load_Const_Reg(list,OS_32,len div (TCgSize2Size[opsize]*2),countreg)
            else
              A_Load_Const_Reg(list,OS_32,len div TCgSize2Size[opsize],countreg);
            A_Label(list,hl);
            A_Op_Const_Reg(list,OP_SUB,OS_32,1,countreg);
            if loadop=A_LDP then
              begin
                regs[1]:=GetIntRegister(list,opsize);
                regs[2]:=GetIntRegister(list,opsize);
                gendualloadstore(list,loadop,regs[1],regs[2],tmpsource,postfix,opsize);
                gendualloadstore(list,storeop,regs[1],regs[2],tmpdest,postfix,opsize);
              end
            else
              begin
                regs[1]:=GetIntRegister(list,opsize);
                genloadstore(list,loadop,regs[1],tmpsource,postfix,opsize);
                genloadstore(list,storeop,regs[1],tmpdest,postfix,opsize);
              end;
            list.concat(TAICPU.op_reg_sym_ofs(A_CBNZ,countreg,hl,0));
            if loadop=A_LDP then
              len:=len mod (TCgSize2Size[opsize]*2)
            else
              len:=len mod TCgSize2Size[opsize];
          end;
        gencopyleftovers(list,tmpsource,tmpdest,len);
      end;


    procedure TCGAArch64.G_Adjust_Self_Value(list:TAsmList;procdef: TProcDef;ioffset: TCGInt);
      begin
        { This method is integrated into g_intf_wrapper and shouldn't be called separately }
        InternalError(2013020102);
      end;


    procedure TCGAArch64.G_Check_For_FPU_Exception(list: TAsmList;force,clear : boolean);
      var
        r, tmpreg: TRegister;
        ai: TAICPU;
        l1,l2: TAsmLabel;
      begin
        { so far, we assume all flavours of AArch64 need explicit floating point exception checking }
        if ((cs_check_fpu_exceptions in CurrentSettings.LocalSwitches) and
            (force or CurrentProcInfo.FPUExceptionCheckNeeded)) then
          begin
            r:=GetIntRegister(list,OS_INT);
            tmpreg:=GetIntRegister(list,OS_INT);
            list.concat(TAICPU.op_reg_reg(A_MRS,r,NR_FPSR));
            list.concat(TAICPU.op_reg_reg_const(A_AND,tmpreg,r,$1f));
            CurrentAsmData.getjumplabel(l1);
            CurrentAsmData.getjumplabel(l2);
            ai:=TAICPU.op_reg_sym_ofs(A_CBNZ,tmpreg,l1,0);
            ai.is_jmp:=true;
            list.concat(ai);
            list.concat(TAICPU.op_reg_reg_const(A_AND,tmpreg,r,$80));
            ai:=TAICPU.op_reg_sym_ofs(A_CBZ,tmpreg,l2,0);
            ai.is_jmp:=true;
            list.concat(ai);
            A_Label(list,l1);
            AllocCPURegisters(list,R_INTREGISTER,ParaManager.Get_Volatile_Registers_Int(pocall_default));
            cg.A_Call_Name(list,'FPC_THROWFPUEXCEPTION',false);
            DeallocCPURegisters(list,R_INTREGISTER,ParaManager.Get_Volatile_Registers_Int(pocall_default));
            A_Label(list,l2);
            if clear then
              CurrentProcInfo.FPUExceptionCheckNeeded:=false;
          end;
      end;


    procedure TCGAArch64.G_Local_Unwind(list: TAsmList; l: TAsmLabel);
      var
        para1,para2: TCGPara;
        pd: TProcDef;
        reg: TRegister;
        href: TReference;
      begin
        if TargetInfo.system<>system_aarch64_win64 then
          begin
            inherited G_Local_Unwind(list,l);
            exit;
          end;
        pd:=Search_System_Proc('_fpc_local_unwind');
        para1.init;
        para2.init;
        ParaManager.GetCGTempParaLoc(list,pd,1,para1);
        ParaManager.GetCGTempParaLoc(list,pd,2,para2);
        { On AArch64-Win64, pass FP+16 as TargetFrame for RtlUnwindEx.
          Windows ARM64 computes EstablisherFrame as SP-at-function-entry.
          Since the standard prolog saves FP/LR with "stp fp,lr,[sp,#-16]!",
          SP-at-entry = FP + 16. RtlUnwindEx validates TargetFrame >= EstablisherFrame,
          so passing FP alone fails (FP is 16 bytes below EstablisherFrame).
          Passing FP+16 satisfies the validation and matches the frame correctly. }
        reg:=GetAddressRegister(list);
        A_Op_Const_Reg_Reg(list,OP_ADD,OS_ADDR,16,NR_FRAME_POINTER_REG,reg);
        A_Load_Reg_CGPara(list,OS_ADDR,reg,para1);
        { pass target label address }
        para2.Check_Simple_Location;
        if para2.Location^.Loc in [LOC_CREGISTER,LOC_REGISTER] then
          begin
            ParaManager.AllocParaLoc(list,para2.Location);
            reg:=para2.Location^.Register;
          end
        else
          reg:=GetAddressRegister(list);
        { ADR is simpler and doesn't require symbol table entries (±1MB range is sufficient for local labels) }
        Reference_Reset_Symbol(href,l,0,sizeof(PInt),[]);
        list.concat(TAICPU.op_reg_ref(A_ADR,reg,href));
        if not(para2.Location^.Loc in [LOC_CREGISTER,LOC_REGISTER]) then
          A_Load_Reg_CGPara(list,OS_ADDR,reg,para2);
        ParaManager.FreeCGPara(list,para2);
        ParaManager.FreeCGPara(list,para1);
        G_Call(list,'_FPC_local_unwind');
        para2.done;
        para1.done;
      end;


    procedure TCGAArch64.Adjust_ExceptFilter_Ref(var ref: TReference; for_finalization: boolean);
      var
        stackframe_size: LongInt;
      begin
        { Convert SP-relative temps to FP-relative for exceptfilter on AArch64-Win64.
          The exceptfilter ($fin$) has its own SP but receives parent's FP as x0
          and sets its FP (x29) to that value. Temps were allocated with SP-relative
          offsets in the parent function, so accessing them via SP in the exceptfilter
          would fail. Convert to FP-relative using the parent's total stack frame size.
          After parent's prolog: FP points to saved x29/x30, SP = FP - totalstackframesize.
          A temp at [SP + X] is at [FP - totalstackframesize + X] = [FP + (X - totalstackframesize)].

          This is called from two places:
          1. ncgbas.pas (temprefnode) - during normal code gen for exceptfilter procs
             for_finalization=false, current_procinfo IS the exceptfilter
          2. hlcgobj.pas (finalizetempvariables) - during finalization for parent procs
             for_finalization=true, current_procinfo is parent with exceptfilter finalize_procinfo }
        if TargetInfo.system<>system_aarch64_win64 then
          exit;

        if for_finalization then
          begin
            { Finalization context: current_procinfo is the parent,
              finalize_procinfo is the exceptfilter we're generating finalization for }
            if not Assigned(CurrentProcInfo.FinalizeProcInfo) then
              exit;
            if CurrentProcInfo.FinalizeProcInfo.procdef.ProcTypeOption<>potype_exceptfilter then
              exit;
            if ref.Base<>CurrentProcInfo.FramePointer then
              exit;
            if CurrentProcInfo.FramePointer=NR_FRAME_POINTER_REG then
              exit;
            stackframe_size:=TCPUProcInfo(CurrentProcInfo).TotalStackFrameSize;
          end
        else
          begin
            { Normal code gen context: current_procinfo IS the exceptfilter.
              Distinguish parent temps from handler temps using the boundary
              saved in generate_code_exceptfilters. Parent temps (offset below
              the boundary) must be converted to FP-relative to access the
              parent's stack frame. Handler temps (offset at or above the
              boundary) stay SP-relative in the handler's own stack frame. }
            if CurrentProcInfo.procdef.ProcTypeOption<>potype_exceptfilter then
              exit;
            if ref.Base<>NR_STACK_POINTER_REG then
              exit;
            if ref.Offset>=TCGProcInfo(CurrentProcInfo.parent).ExceptFilterParentTempEnd then
              exit;
            stackframe_size:=TCPUProcInfo(CurrentProcInfo.parent).TotalStackFrameSize;
          end;

        ref.Base:=NR_FRAME_POINTER_REG;
        dec(ref.Offset, stackframe_size);
      end;


    procedure create_codegen;
      begin
        cg:=TCGAArch64.Create;
        cg128:=TCG128.Create;
      end;

end.
