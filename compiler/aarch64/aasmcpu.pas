{
    Copyright (c) 2003-2012 by Florian Klaempfl and others

    Contains the assembler object for Aarch64

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
unit aasmcpu;

{$i fpcdefs.inc}

interface

uses
  TPCompilerReal,
  CClasses,GlobType,Globals,Verbose,
  aasmbase,aasmtai,AAsmData,aasmsym,
  ogbase,
  symtype,
  cpubase,CPUInfo,cgbase,cgutils;

    const
      { "mov reg,reg" source operand number }
      O_MOV_SOURCE = 1;
      { "mov reg,reg" source operand number }
      O_MOV_DEST = 0;

      { Operand types }
      OT_NONE      = $00000000;

      OT_BITS8     = $00000001;  { size, and other attributes, of the operand  }
      OT_BITS16    = $00000002;
      OT_BITS32    = $00000004;
      OT_BITS64    = $00000008;  { FPU only  }
      OT_BITS80    = $00000010;
      OT_FAR       = $00000020;  { this means 16:16 or 16:32, like in CALL/JMP }
      OT_NEAR      = $00000040;
      OT_SHORT     = $00000080;
      OT_BITSTINY  = $00000100;  { fpu constant }
      OT_BITSSHIFTER =
                     $00000200;

      OT_SIZE_MASK = $000003FF;  { all the size attributes  }
      OT_NON_SIZE  = LongInt(not OT_SIZE_MASK);

      OT_SIGNED    = $00000100;  { the operand need to be signed -128-127 }

      OT_TO        = $00000200;  { operand is followed by a colon  }
                                 { reverse effect in FADD, FSUB &c  }
      OT_COLON     = $00000400;

      OT_SHIFTEROP = $00000800;
      OT_REGISTER  = $00001000;
      OT_IMMEDIATE = $00002000;
      OT_REGLIST   = $00008000;
      OT_IMM8      = $00002001;
      OT_IMM24     = $00002002;
      OT_IMM32     = $00002004;
      OT_IMM64     = $00002008;
      OT_IMM80     = $00002010;
      OT_IMMTINY   = $00002100;
      OT_IMMSHIFTER= $00002200;
      OT_IMMEDIATE24 = OT_IMM24;
      OT_SHIFTIMM  = OT_SHIFTEROP or OT_IMMSHIFTER;
      OT_SHIFTIMMEDIATE = OT_SHIFTIMM;
      OT_IMMEDIATESHIFTER = OT_IMMSHIFTER;

      OT_IMMEDIATEFPU = OT_IMMTINY;

      OT_REGMEM    = $00200000;  { for r/m, ie EA, operands  }
      OT_REGNORM   = $00201000;  { 'normal' reg, qualifies as EA  }
      OT_REG8      = $00201001;
      OT_REG16     = $00201002;
      OT_REG32     = $00201004;
      OT_REG64     = $00201008;
      OT_VREG      = $00201010;  { vector register }
      OT_REGF      = $00201020;  { coproc register }
      OT_MEMORY    = $00204000;  { register number in 'basereg'  }
      OT_MEM8      = $00204001;
      OT_MEM16     = $00204002;
      OT_MEM32     = $00204004;
      OT_MEM64     = $00204008;
      OT_MEM80     = $00204010;
      { word/byte load/store }
      OT_AM2       = $00010000;
      { misc ld/st operations }
      OT_AM3       = $00020000;
      { multiple ld/st operations }
      OT_AM4       = $00040000;
      { co proc. ld/st operations }
      OT_AM5       = $00080000;
      OT_AMMASK    = $000f0000;
      { IT instruction }
      OT_CONDITION = $00100000;

      OT_MEMORYAM2 = OT_MEMORY or OT_AM2;
      OT_MEMORYAM3 = OT_MEMORY or OT_AM3;
      OT_MEMORYAM4 = OT_MEMORY or OT_AM4;
      OT_MEMORYAM5 = OT_MEMORY or OT_AM5;

      OT_FPUREG    = $01000000;  { floating point stack registers  }
      OT_REG_SMASK = $00070000;  { special register operands: these may be treated differently  }
                                 { a mask for the following  }

      OT_MEM_OFFS  = $00604000;  { special type of EA  }
                                 { simple [address] offset  }
      OT_ONENESS   = $00800000;  { special type of immediate operand  }
                                 { so UNITY == IMMEDIATE | ONENESS  }
      OT_UNITY     = $00802000;  { for shift/rotate instructions  }

      instabentries = {$i a64nop.inc}

      maxinfolen = 5;

      IF_NONE   = $00000000;

      IF_ARMMASK    = $000F0000;
      IF_ARM7       = $00070000;
      IF_FPMASK     = $00F00000;
      IF_FPA        = $00100000;

      { if the instruction can change in a second pass }
      IF_PASS2  = LongInt($80000000);

    type
      TInsTabCache=array[TAsmOp] of LongInt;
      PInsTabCache=^TInsTabCache;

      TInsEntry = record
        opcode  : TAsmOp;
        ops     : byte;
        optypes : array[0..3] of LongInt;
        code    : array[0..maxinfolen] of char;
        flags   : LongInt;
      end;

      PInsEntry=^TInsEntry;

    var
      InsTabCache : PInsTabCache;

    type
      TAICPU = class(TAICPUAbstractSym)
         oppostfix : TOpPostfix;
         procedure loadshifterop(opidx:LongInt;const so:TShifterOp);
         procedure loadconditioncode(opidx: LongInt; const c: TAsmCond);
         procedure loadrealconst(opidx: LongInt; const _value: BestReal);
         procedure loadregset(opidx: LongInt; _basereg: TRegister; _nregs: byte; _regsetindex: byte = 255);
         procedure loadindexedreg(opidx: LongInt; _indexedreg: TRegister; _regindex: byte);

         constructor op_none(op : TAsmOp);

         constructor op_reg(op : TAsmOp;_op1 : TRegister);
         constructor op_ref(op : TAsmOp;const _op1 : TReference);
         constructor op_const(op : TAsmOp;_op1 : LongInt);

         constructor op_reg_reg(op : TAsmOp;_op1,_op2 : TRegister);
         constructor op_reg_ref(op : TAsmOp;_op1 : TRegister;const _op2 : TReference);
         constructor op_reg_cond(op: TAsmOp; _op1: TRegister; _op2: TAsmCond);
         constructor op_reg_const(op:TAsmOp; _op1: TRegister; _op2: aint);
         constructor op_reg_const_shifterop(op : TAsmOp;_op1: TRegister; _op2: aint;_op3 : TShifterOp);
         constructor op_reg_realconst(op: TAsmOp; _op1: TRegister; _op2: BestReal);

         constructor op_indexedreg_reg(op : TAsmOp;_op1: TRegister; _op1index: byte; _op2 : TRegister);
         constructor op_reg_indexedreg(op : TAsmOp;_op1: TRegister; _op2 : TRegister; _op2index: byte);

         constructor op_reg_reg_reg(op : TAsmOp;_op1,_op2,_op3 : TRegister);
         constructor op_reg_reg_reg_reg(op : TAsmOp;_op1,_op2,_op3,_op4 : TRegister);
         constructor op_reg_reg_const(op : TAsmOp;_op1,_op2 : TRegister; _op3: aint);
         constructor op_reg_reg_const_const(op : TAsmOp;_op1,_op2 : TRegister; _op3, _op4: aint);
         constructor op_reg_reg_const_shifterop(op : TAsmOp;_op1,_op2 : TRegister; _op3: aint; const _op4 : TShifterOp);
         constructor op_reg_reg_sym_ofs(op : TAsmOp;_op1,_op2 : TRegister; _op3: TAsmSymbol;_op3ofs: LongInt);
         constructor op_reg_reg_ref(op : TAsmOp;_op1,_op2 : TRegister; const _op3: TReference);
         constructor op_reg_reg_shifterop(op : TAsmOp;_op1,_op2 : TRegister;_op3 : TShifterOp);
         constructor op_reg_reg_reg_shifterop(op : TAsmOp;_op1,_op2,_op3 : TRegister; const _op4 : TShifterOp);
         constructor op_reg_reg_reg_cond(op : TAsmOp;_op1,_op2,_op3 : TRegister; const _op4: TAsmCond);
         constructor op_reg_const_ref(op: TAsmOp; _op1: TRegister; _op2: aint; _op3: TReference);

         constructor op_const_ref(op:TAsmOp; _op1: aint; _op2: TReference);

         { this is for Jmp instructions }
         constructor op_cond_sym(op : TAsmOp;cond:TAsmCond;_op1 : TAsmSymbol);

         { ldN(r)/stN }
         constructor op_regset_reg_ref(op: TAsmOp; basereg: TRegister; nregs: byte; const ref: TReference);

         constructor op_sym(op : TAsmOp;_op1 : TAsmSymbol);
         constructor op_sym_ofs(op : TAsmOp;_op1 : TAsmSymbol;_op1ofs:LongInt);
         constructor op_reg_sym_ofs(op : TAsmOp;_op1 : TRegister;_op2:TAsmSymbol;_op2ofs : LongInt);
         constructor op_sym_ofs_ref(op : TAsmOp;_op1 : TAsmSymbol;_op1ofs:LongInt;const _op2 : TReference);

         function is_same_reg_move(RegType: TRegisterType):boolean; override;

         function spilling_get_operation_type(opnr: LongInt): TOperType;override;
         function spilling_get_operation_type_ref(opnr: LongInt; reg: TRegister): TOperType;override;

         { assembler }
      public
         { the next will reset all instructions that can change in pass 2 }
         procedure ResetPass1;override;
         procedure ResetPass2;override;
         function  CheckIfValid:boolean;
         function GetString:string;
         function  Pass1(objdata:TObjData):LongInt;override;
         procedure Pass2(objdata:TObjData);override;
      protected
         procedure ppuloadoper(ppufile:TCompilerPPUFile;var o:TOper);override;
         procedure ppuwriteoper(ppufile:TCompilerPPUFile;const o:TOper);override;
         procedure ppubuildderefimploper(var o:TOper);override;
         procedure ppuderefoper(var o:TOper);override;
      end;

      TAIAlign = class(TAIAlignAbstract)
        { nothing to add }
      end;

    type
      TSimpleRefType =
         { valid reference }
        (sr_simple,
         { invalid reference, should not be generated by the code generator (but
           can be encountered via inline assembly, where it must be rejected) }
         sr_internal_illegal,
         { invalid reference, may be generated by the code generator and then
           must be simplified (also rejected in inline assembly) }
         sr_complex);

    function simple_ref_type(op: TAsmOp; size:TCgSize; oppostfix: TOpPostfix; const ref: TReference): TSimpleRefType;
    function can_be_shifter_operand(opc: TAsmOp; opnr: LongInt): boolean;
    function valid_shifter_operand(opc: TAsmOp; useszr, usessp, is64bit: boolean; sm: TShiftMode; ShiftImm: LongInt): boolean;

    function spilling_create_load(const ref: TReference; r: TRegister): TAICPU;
    function spilling_create_store(r: TRegister; const ref: TReference): TAICPU;

    function setoppostfix(i : TAICPU;pf : TOpPostfix) : TAICPU;
    function setcondition(i : TAICPU;c : TAsmCond) : TAICPU;

    { inserts pc relative symbols at places where they are reachable
      and transforms special instructions to valid instruction encodings }
    procedure finalizearmcode(list,listtoinsert : TAsmList);

    procedure InitAsm;
    procedure DoneAsm;


implementation

  uses
    CUtils,rgobj,itcpugas,aoptcpu;


    procedure TAICPU.loadshifterop(opidx:LongInt;const so:TShifterOp);
      begin
        allocate_oper(opidx+1);
        with oper[opidx]^ do
          begin
            if typ<>top_shifterop then
              begin
                clearop(opidx);
                new(shifterop);
              end;
            shifterop^:=so;
            typ:=top_shifterop;
          end;
      end;


    procedure TAICPU.loadconditioncode(opidx: LongInt; const c: TAsmCond);
      begin
        allocate_oper(opidx+1);
        with oper[opidx]^ do
          begin
            if typ<>top_conditioncode then
              begin
                clearop(opidx);
              end;
            cc:=c;
            typ:=top_conditioncode;
          end;
      end;


    procedure TAICPU.loadrealconst(opidx:LongInt;const _value:BestReal);
      begin
        allocate_oper(opidx+1);
        with oper[opidx]^ do
          begin
            if typ<>top_realconst then
              clearop(opidx);
            val_real:=_value;
            typ:=top_realconst;
          end;
      end;


    procedure TAICPU.loadregset(opidx: LongInt; _basereg: TRegister; _nregs: byte; _regsetindex: byte = 255);
      begin
        allocate_oper(opidx+1);
        with oper[opidx]^ do
          begin
            if typ<>top_regset then
              clearop(opidx);
            basereg:=_basereg;
            nregs:=_nregs;
            regsetindex:=_regsetindex;
            typ:=top_regset;
          end;
      end;


    procedure TAICPU.loadindexedreg(opidx: LongInt; _indexedreg: TRegister; _regindex: byte);
      begin
        allocate_oper(opidx+1);
        with oper[opidx]^ do
          begin
            if typ<>top_indexedreg then
              clearop(opidx);
            indexedreg:=_indexedreg;
            RegIndex:=_regindex;
            typ:=top_indexedreg;
          end;
      end;


{*****************************************************************************
                                 taicpu Constructors
*****************************************************************************}

    constructor TAICPU.op_none(op : TAsmOp);
      begin
         inherited create(op);
      end;


    { for pld }
    constructor TAICPU.op_ref(op : TAsmOp;const _op1 : TReference);
      begin
         inherited create(op);
         ops:=1;
         loadref(0,_op1);
      end;


    constructor TAICPU.op_reg(op : TAsmOp;_op1 : TRegister);
      begin
         inherited create(op);
         ops:=1;
         LoadReg(0,_op1);
      end;


    constructor TAICPU.op_const(op : TAsmOp;_op1 : LongInt);
      begin
         inherited create(op);
         ops:=1;
         loadconst(0,aint(_op1));
      end;


    constructor TAICPU.op_reg_reg(op : TAsmOp;_op1,_op2 : TRegister);
      begin
         inherited create(op);
         ops:=2;
         LoadReg(0,_op1);
         LoadReg(1,_op2);
      end;


    constructor TAICPU.op_reg_const(op:TAsmOp; _op1: TRegister; _op2: aint);
      begin
         inherited create(op);
         ops:=2;
         LoadReg(0,_op1);
         loadconst(1,aint(_op2));
      end;


    constructor TAICPU.op_reg_const_shifterop(op: TAsmOp; _op1: TRegister; _op2: aint; _op3: TShifterOp);
      begin
        inherited create(op);
        ops:=3;
        LoadReg(0,_op1);
        loadconst(1,_op2);
        loadshifterop(2,_op3);
      end;


    constructor TAICPU.op_reg_ref(op : TAsmOp;_op1 : TRegister;const _op2 : TReference);
      begin
         inherited create(op);
         ops:=2;
         LoadReg(0,_op1);
         loadref(1,_op2);
      end;


    constructor TAICPU.op_reg_cond(op: TAsmOp; _op1: TRegister; _op2: TAsmCond);
      begin
        inherited create(op);
        ops:=2;
        LoadReg(0,_op1);
        loadconditioncode(1,_op2);
      end;


    constructor TAICPU.op_reg_reg_reg(op : TAsmOp;_op1,_op2,_op3 : TRegister);
      begin
         inherited create(op);
         ops:=3;
         LoadReg(0,_op1);
         LoadReg(1,_op2);
         LoadReg(2,_op3);
      end;


    constructor TAICPU.op_reg_reg_reg_reg(op : TAsmOp;_op1,_op2,_op3,_op4 : TRegister);
      begin
         inherited create(op);
         ops:=4;
         LoadReg(0,_op1);
         LoadReg(1,_op2);
         LoadReg(2,_op3);
         LoadReg(3,_op4);
      end;


    constructor TAICPU.op_reg_realconst(op : TAsmOp; _op1 : TRegister; _op2 : BestReal);
      begin
         inherited create(op);
         ops:=2;
         LoadReg(0,_op1);
         loadrealconst(1,_op2);
      end;


    constructor TAICPU.op_indexedreg_reg(op: TAsmOp; _op1: TRegister; _op1index: byte; _op2: TRegister);
      begin
        inherited create(op);
        ops:=2;
        loadindexedreg(0,_op1,_op1index);
        LoadReg(1,_op2);
      end;


    constructor TAICPU.op_reg_indexedreg(op: TAsmOp; _op1: TRegister; _op2: TRegister; _op2index: byte);
      begin
        inherited create(op);
        ops:=2;
        LoadReg(0,_op1);
        loadindexedreg(1,_op2,_op2index);
      end;


     constructor TAICPU.op_reg_reg_const(op : TAsmOp;_op1,_op2 : TRegister; _op3: aint);
       begin
         inherited create(op);
         ops:=3;
         LoadReg(0,_op1);
         LoadReg(1,_op2);
         loadconst(2,aint(_op3));
      end;


     constructor TAICPU.op_reg_reg_const_const(op: TAsmOp; _op1, _op2: TRegister; _op3, _op4: aint);
       begin
         inherited create(op);
         ops:=4;
         LoadReg(0,_op1);
         LoadReg(1,_op2);
         loadconst(2,aint(_op3));
         loadconst(3,aint(_op4));
       end;


     constructor TAICPU.op_reg_reg_const_shifterop(op: TAsmOp; _op1, _op2: TRegister; _op3: aint; const _op4: TShifterOp);
       begin
         inherited create(op);
         ops:=4;
         LoadReg(0,_op1);
         LoadReg(1,_op2);
         loadconst(2,aint(_op3));
         loadshifterop(3,_op4);
       end;


     constructor TAICPU.op_reg_reg_sym_ofs(op : TAsmOp;_op1,_op2 : TRegister; _op3: TAsmSymbol;_op3ofs: LongInt);
       begin
         inherited create(op);
         ops:=3;
         LoadReg(0,_op1);
         LoadReg(1,_op2);
         loadsymbol(2,_op3,_op3ofs);
      end;


     constructor TAICPU.op_reg_reg_ref(op : TAsmOp;_op1,_op2 : TRegister; const _op3: TReference);
       begin
         inherited create(op);
         ops:=3;
         LoadReg(0,_op1);
         LoadReg(1,_op2);
         loadref(2,_op3);
      end;


     constructor TAICPU.op_reg_reg_shifterop(op : TAsmOp;_op1,_op2 : TRegister;_op3 : TShifterOp);
      begin
         inherited create(op);
         ops:=3;
         LoadReg(0,_op1);
         LoadReg(1,_op2);
         loadshifterop(2,_op3);
      end;


     constructor TAICPU.op_reg_reg_reg_shifterop(op : TAsmOp;_op1,_op2,_op3 : TRegister; const _op4 : TShifterOp);
      begin
         inherited create(op);
         ops:=4;
         LoadReg(0,_op1);
         LoadReg(1,_op2);
         LoadReg(2,_op3);
         loadshifterop(3,_op4);
      end;

     constructor TAICPU.op_reg_reg_reg_cond(op: TAsmOp; _op1, _op2, _op3: TRegister; const _op4: TAsmCond);
       begin
         inherited create(op);
         ops:=4;
         LoadReg(0,_op1);
         LoadReg(1,_op2);
         LoadReg(2,_op3);
         loadconditioncode(3,_op4);
       end;


     constructor TAICPU.op_const_ref(op : TAsmOp; _op1 : aint; _op2 : TReference);
      begin
         inherited create(op);
         ops:=2;
         loadconst(0,_op1);
         loadref(1,_op2);
      end;


    constructor TAICPU.op_cond_sym(op : TAsmOp;cond:TAsmCond;_op1 : TAsmSymbol);
      begin
         inherited create(op);
         condition:=cond;
         ops:=1;
         loadsymbol(0,_op1,0);
      end;


    constructor TAICPU.op_regset_reg_ref(op: TAsmOp; basereg: TRegister; nregs: byte; const ref: TReference);
      begin
        inherited create(op);
        ops:=2;
        loadregset(0,basereg,nregs);
        loadref(1, ref);
      end;


    constructor TAICPU.op_sym(op : TAsmOp;_op1 : TAsmSymbol);
      begin
         inherited create(op);
         ops:=1;
         loadsymbol(0,_op1,0);
      end;


    constructor TAICPU.op_sym_ofs(op : TAsmOp;_op1 : TAsmSymbol;_op1ofs:LongInt);
      begin
         inherited create(op);
         ops:=1;
         loadsymbol(0,_op1,_op1ofs);
      end;


     constructor TAICPU.op_reg_sym_ofs(op : TAsmOp;_op1 : TRegister;_op2:TAsmSymbol;_op2ofs : LongInt);
      begin
         inherited create(op);
         ops:=2;
         LoadReg(0,_op1);
         loadsymbol(1,_op2,_op2ofs);
      end;


    constructor TAICPU.op_sym_ofs_ref(op : TAsmOp;_op1 : TAsmSymbol;_op1ofs:LongInt;const _op2 : TReference);
      begin
         inherited create(op);
         ops:=2;
         loadsymbol(0,_op1,_op1ofs);
         loadref(1,_op2);
      end;


    constructor TAICPU.op_reg_const_ref(op : TAsmOp;_op1 : TRegister;_op2 : aint;_op3 : TReference);
      begin
         inherited create(op);
         ops:=3;
         LoadReg(0,_op1);
         loadconst(1,_op2);
         loadref(2,_op3);
      end;


    function TAICPU.is_same_reg_move(RegType: TRegisterType):boolean;
      begin
        { allow the register allocator to remove unnecessary moves }
        result:=(
                  ((opcode=A_MOV) and (RegType = R_INTREGISTER)) or
                  ((opcode=A_FMOV) and (RegType = R_MMREGISTER))
                ) and
                (oppostfix in [PF_None]) and
                (condition=C_None) and
                (ops=2) and
                (oper[0]^.typ=top_reg) and
                (oper[1]^.typ=top_reg) and
                (oper[0]^.reg=oper[1]^.reg);
      end;


    function spilling_create_op(op: TAsmOp; const ref: TReference; r: TRegister): TAICPU;
      const
        { invalid sizes for aarch64 are 0 }
        subreg2bytesize: array[TSubRegister] of byte =
          (0,0,0,0,4,8,0,0,0,4,8,0,0,0,0,0,0,0,0,0,0,0,0,8,16,0,16,16,16,16,16,16,16,16,16,16);
      var
        ScaleFactor: byte;
      begin
        ScaleFactor:=subreg2bytesize[GetSubReg(r)];
        if ScaleFactor=0 then
          InternalError(2014120301);
        if (ref.Offset>4095*ScaleFactor) or
           ((ref.Offset>255) and
            ((ref.Offset mod ScaleFactor)<>0)) or
           (ref.Offset<-256) then
          InternalError(2014120302);
        case GetRegType(r) of
          R_INTREGISTER,
          R_MMREGISTER:
            result:=TAICPU.op_reg_ref(op,r,ref);
          else
            InternalError(2004010407);
        end;
      end;


    function is_valid_load_symbol(op: TAsmOp; oppostfix: TOpPostfix; const ref: TReference): TSimpleRefType;
      begin
        result:=sr_complex;
        if not Assigned(ref.SymbolData) and
           not(ref.RefAddr in [addr_pic,addr_gotpageoffset,addr_gotpage,addr_pageoffset,addr_page]) then
          exit;
        { can't use pre-/post-indexed mode here (makes no sense either) }
        if ref.AddressMode<>AM_OFFSET then
          exit;
        { "ldr literal" must be a 32/64 bit LDR and have a symbol }
        if (ref.RefAddr=addr_pic) and
           (not (op in [A_LDR,A_B,A_BL,A_ADR]) or
            not(oppostfix in [PF_NONE,PF_W,PF_SW]) or
            (not Assigned(ref.Symbol) and
             not Assigned(ref.SymbolData))) then
          exit;
        { if this is a (got) page offset load, we must have a base register and a
          symbol (except if we have an ADD with a non-got page offset load) }
        if (ref.RefAddr in [addr_gotpageoffset,addr_pageoffset]) and
           (
             (
               (
                 (op<>A_ADD) or
                 (ref.RefAddr=addr_gotpageoffset)
               ) and
               (
                 not Assigned(ref.Symbol) or
                 (ref.Base=NR_NO)
               )
             ) or
             (
               (
                 (op=A_ADD) and
                 (ref.RefAddr=addr_pageoffset)
               ) and
               not Assigned(ref.Symbol) and
               (ref.Base=NR_NO)
             ) or
            (ref.Index<>NR_NO) or
            (ref.Offset<>0)) then
          begin
            result:=sr_internal_illegal;
            exit;
          end;
        { cannot have base or index register (we generate these kind of
          references internally, they should never end up here with an
          extra base or offset) }
        if (ref.RefAddr in [addr_gotpage,addr_page]) and
           ((ref.Base<>NR_NO) or
            (ref.Index<>NR_NO)) then
          begin
            result:=sr_internal_illegal;
            exit;
          end;
        result:=sr_simple;
      end;


    function simple_ref_type(op: TAsmOp; size:TCgSize; oppostfix: TOpPostfix; const ref: TReference): TSimpleRefType;
      var
        accesssize: LongInt;
      begin
        result:=sr_internal_illegal;
        { post-indexed is only allowed for vector and immediate loads/stores }
        if (ref.AddressMode=AM_POSTINDEXED) and
           not((op = A_LD1) or (op = A_LD2) or (op = A_LD3) or (op = A_LD4) or
               (op = A_LD1R) or (op = A_LD2R) or (op = A_LD3R) or (op = A_LD4R) or
               (op = A_ST1) or (op = A_ST2) or (op = A_ST3) or (op = A_ST4)) and
           (not(op in [A_LDR,A_STR,A_LDP,A_STP]) or
            (ref.Base=NR_NO) or
            (ref.Index<>NR_NO)) then
          exit;

        { can only have a shift mode if we have an index }
        if (ref.Index=NR_NO) and
           (ref.ShiftMode<>SM_None) then
          exit;

        { the index can never be the stack pointer }
        if ref.Index=NR_SP then
          exit;

        { no instruction supports an index without a base }
        if (ref.Base=NR_NO) and
           (ref.Index<>NR_NO) then
          begin
            result:=sr_complex;
            exit;
          end;

        { LDR literal or GOT entry: 32 or 64 bit, label }
        if Assigned(ref.SymbolData) or
           Assigned(ref.Symbol) then
          begin
            { we generate these kind of references internally; at least for now,
              they should never end up here with an extra base or offset or so }
            result:=is_valid_load_symbol(op,oppostfix,ref);
            exit;
          end;

        { any other reference cannot be gotpage/gotpageoffset/pic }
        if ref.RefAddr in [addr_gotpage,addr_gotpageoffset,addr_page,addr_pageoffset,addr_pic] then
          exit;

        { base & index:
            * index cannot be the stack pointer
            * offset must be 0
            * can scale with the size of the access
            * can zero/sign extend 32 bit index register, and/or multiple by
              access size
            * no pre/post-indexing except for ldN(r)/stN
        }
        if (ref.Base<>NR_NO) and
           (ref.Index<>NR_NO) then
          begin
            case op of
              { this holds for both integer and fpu/vector loads }
              A_LDR,A_STR:
                begin
                  if ref.AddressMode in [AM_PREINDEXED,AM_POSTINDEXED] then
                    exit;
                  if (ref.Offset=0) and
                     (((ref.ShiftMode=SM_None) and
                       (ref.ShiftImm=0)) or
                      ((ref.ShiftMode in [SM_LSL,SM_UXTW,SM_SXTW]) and
                       (ref.ShiftImm=tcgsizep2size[size]))) then
                    result:=sr_simple
                  else
                    result:=sr_complex;
                end;
              A_LD1,A_LD2,A_LD3,A_LD4,
              A_LD1R,A_LD2R,A_LD3R,A_LD4R,
              A_ST1,A_ST2,A_ST3,A_ST4:
                begin
                  if ref.AddressMode in [AM_PREINDEXED] then
                    exit;
                  if (ref.Offset=0) and
                     (ref.AddressMode=AM_POSTINDEXED) then
                    result:=sr_simple
                  else
                   result:=sr_complex;
                end;
              { these don't support base+index }
              A_LDUR,A_STUR,
              A_LDP,A_STP:
                begin
                  if ref.AddressMode in [AM_PREINDEXED,AM_POSTINDEXED] then
                    exit;
                  result:=sr_complex;
                end
              else
                { nothing: result is already sr_internal_illegal };
            end;
            exit;
          end;

        { base + immediate offset. Variants:
            * LDR*/STR*:
              - pre- or post-indexed with signed 9 bit immediate
              - regular with unsigned scaled immediate (multiple of access
                size), in the range 0 to (12 bit * access_size)-1
            * LDP/STP
              - pre- or post-indexed with signed 9 bit immediate
              - regular with signed 9 bit immediate
            * LDUR*/STUR*:
              - regular with signed 9 bit immediate
            * ldN(r)/stN
              - 0 or with postindex
        }
        if ref.Base<>NR_NO then
          begin
            accesssize:=1 shl tcgsizep2size[size];
            case op of
              A_LDR,A_STR:
                begin
                  if (ref.AddressMode=AM_OFFSET) and
                     (ref.Offset>=0) and
                     (ref.Offset<(((1 shl 12)-1)*accesssize)) and
                     ((ref.Offset mod accesssize)=0) then
                    result:=sr_simple
                  else if (ref.Offset>=-256) and
                     (ref.Offset<=255) then
                    begin
                      { non pre-/post-indexed regular loads/stores can only be
                        performed using LDUR/STUR }
                      if ref.AddressMode in [AM_PREINDEXED,AM_POSTINDEXED] then
                        result:=sr_simple
                      else
                        result:=sr_complex
                    end
                  else
                    result:=sr_complex;
                end;
              A_LDP,A_LDNP,
              A_STP,A_STNP:
                begin
                  { only supported for 32/64 bit }
                  if not(oppostfix in [PF_W,PF_SW,PF_None]) then
                    exit;
                  { offset must be a multiple of the access size }
                  if (ref.Offset mod accesssize)<>0 then
                    exit;
                  { offset must fit in a signed 7 bit offset }
                  if (ref.Offset>=-(1 shl (6+tcgsizep2size[size]))) and
                     (ref.Offset<=(1 shl (6+tcgsizep2size[size]))-1) then
                    result:=sr_simple
                  else
                    result:=sr_complex;
                end;
              A_LDUR,A_STUR:
                begin
                  if ref.AddressMode in [AM_PREINDEXED,AM_POSTINDEXED] then
                    exit;
                  if (ref.Offset>=-256) and
                     (ref.Offset<=255) then
                    result:=sr_simple
                  else
                    result:=sr_complex;
                end;
              A_LD1,A_LD2,A_LD3,A_LD4,
              A_LD1R,A_LD2R,A_LD3R,A_LD4R,
              A_ST1,A_ST2,A_ST3,A_ST4:
                begin
                  if ref.AddressMode in [AM_PREINDEXED] then
                    exit;
                  if (ref.Offset=0) or
                     ((ref.AddressMode=AM_POSTINDEXED) and
                      { to check the validity of the offset, we'd have to analyse the regset argument }
                      (ref.Offset>0)) then
                    result:=sr_simple
                  else
                    result:=sr_complex;
                end;
              A_LDADD,
              A_LDADDA,
              A_LDADDAL,
              A_LDADDL,

              A_SWP,
              A_SWPA,
              A_SWPAL,
              A_SWPL,

              A_CAS,
              A_CASA,
              A_CASAL,
              A_CASL,

              A_STADD,
              A_LDAR,
              A_LDAXR,
              A_LDXR,
              A_LDXP,

              A_STLR,
              A_STLXR,
              A_STLXP,
              A_STXP,
              A_STXR:
                begin
                  if (ref.AddressMode=AM_OFFSET) and
                     (ref.Offset=0) then
                    result:=sr_simple;
                end
              else
                { nothing: result is already sr_internal_illegal };
            end;
            exit;
          end;
        { absolute addresses are not supported, have to load them first into
          a register }
        result:=sr_complex;
      end;


    function can_be_shifter_operand(opc: TAsmOp; opnr: LongInt): boolean;
      begin
        case opc of
          A_ADD,
          A_AND,
          A_BIC,
          A_EON,
          A_EOR,
          A_ORN,
          A_ORR,
          A_SUB:
            result:=opnr=3;
          A_CMN,
          A_CMP,
          A_MOVK,
          A_MOVZ,
          A_MOVN,
          A_MVN,
          A_NEG,
          A_TST:
            result:=opnr=2;
          else
            result:=false;
        end;
      end;


    function valid_shifter_operand(opc: TAsmOp; useszr, usessp, is64bit: boolean; sm: TShiftMode; ShiftImm: LongInt): boolean;
      begin
        case opc of
          A_ADD,
          A_SUB,
          A_CMN,
          A_CMP:
            begin
              result:=false;
              if not useszr then
                result:=
                  (sm in shiftedregmodes) and
                  (ShiftImm in [0..31*(ord(is64bit)+1)+ord(is64bit)]);
              if not usessp then
                result:=
                  result or
                  ((sm in extendedregmodes) and
                   (ShiftImm in [0..31*(ord(is64bit)+1)+ord(is64bit)]));
            end;
          A_AND,
          A_BIC,
          A_EON,
          A_EOR,
          A_MVN,
          A_NEG,
          A_ORN,
          A_ORR,
          A_TST:
            result:=
              (sm in logicalshiftedregmodes) and
              (ShiftImm in [0..31*(ord(is64bit)+1)+ord(is64bit)]);
          A_MOVK,
          A_MOVZ,
          A_MOVN:
            result:=
              (sm=SM_LSL) and
              ((ShiftImm in [0,16]) or
               (is64bit and
                (ShiftImm in [32,48])));
          else
            result:=false;
        end;
      end;


    function spilling_create_load(const ref: TReference; r: TRegister): TAICPU;
      var
        op: TAsmOp;
      begin
        if (ref.Index<>NR_NO) or
           (ref.Offset<-256) or
           (ref.Offset>255) then
          op:=A_LDR
        else
          op:=A_LDUR;
        result:=spilling_create_op(op,ref,r);
      end;


    function spilling_create_store(r: TRegister; const ref: TReference): TAICPU;
      var
        op: TAsmOp;
      begin
        if (ref.Index<>NR_NO) or
           (ref.Offset<-256) or
           (ref.Offset>255) then
          op:=A_STR
        else
          op:=A_STUR;
        result:=spilling_create_op(op,ref,r);
      end;


    function TAICPU.spilling_get_operation_type(opnr: LongInt): TOperType;
      begin
        case opcode of
          A_B,A_BL,A_BR,A_BLR,
          A_CMN,A_CMP,
          A_CCMN,A_CCMP,
          A_TST,
          A_FCMP,A_FCMPE,
          A_CBZ,A_CBNZ,
          A_PRFM,A_PRFUM,
          A_RET:
            result:=operand_read;
          A_STR,A_STUR:
            if opnr=0 then
              result:=operand_read
            else
              { check for pre/post indexed in spilling_get_operation_type_ref }
              result:=operand_read;
          A_STP:
            begin
              if opnr in [0,1] then
                result:=operand_read
              else
                { check for pre/post indexed in spilling_get_operation_type_ref }
                result:=operand_read;
            end;
           A_LDP,
           A_LDXP:
             begin
               if opnr in [0,1] then
                 result:=operand_write
               else
                 { check for pre/post indexed in spilling_get_operation_type_ref }
                 result:=operand_read;
             end;
           A_MOVK,
           A_BFI:
             begin
               if opnr=0 then
                 result:=operand_readwrite
               else
                 result:=operand_read;
             end;
{$ifdef EXTDEBUG}
           { play save to avoid hard to find bugs, better fail at compile time }
           A_ADD,
           A_ADRP,
           A_AND,
           A_ASR,
           A_ASRV,
           A_BFXIL,
           A_BIC,
           A_CLZ,
           A_CSEL,
           A_CSET,
           A_CSETM,
           A_FABS,
           A_EON,
           A_EOR,
           A_FADD,
           A_FCSEL,
           A_FCVT,
           A_FDIV,
           A_FMADD,
           A_FMOV,
           A_FMSUB,
           A_FMUL,
           A_FNEG,
           A_FNMADD,
           A_FNMSUB,
           A_FRINTX,
           A_FRINTZ,
           A_FSQRT,
           A_FSUB,
           A_ORR,
           A_LSL,
           A_LSLV,
           A_LSR,
           A_LSRV,
           A_MOV,
           A_MOVN,
           A_MOVZ,
           A_MSUB,
           A_MUL,
           A_MVN,
           A_NEG,
           A_LDR,
           A_LDUR,
           A_RBIT,
           A_ROR,
           A_RORV,
           A_SBFX,
           A_SCVTF,
           A_FCVTZS,
           A_SDIV,
           A_SMULL,
           A_SMULH,
           A_STLXP,
           A_STLXR,
           A_STXP,
           A_STXR,
           A_SUB,
           A_SXTB,
           A_SXTH,
           A_SXTW,
           A_UBFIZ,
           A_UBFX,
           A_UCVTF,
           A_UDIV,
           A_UMULL,
           A_UMULH,
           A_UXTB,
           A_UXTH,
           A_MRS:
             if opnr=0 then
               result:=operand_write
             else
               result:=operand_read;
           else
             InternalError(2019090803);
{$else EXTDEBUG}
           else
             if opnr=0 then
               result:=operand_write
             else
               result:=operand_read;
{$endif EXTDEBUG}
        end;
      end;


    function TAICPU.spilling_get_operation_type_ref(opnr: LongInt; reg: TRegister): TOperType;
      begin
        result:=operand_read;
        if (oper[opnr]^.Ref^.Base = reg) and
          (oper[opnr]^.Ref^.AddressMode in [AM_PREINDEXED,AM_POSTINDEXED]) then
           result:=operand_readwrite;
      end;


    procedure BuildInsTabCache;
//      var
//        i : longint;
      begin
(*        new(instabcache);
        FillChar(instabcache^,sizeof(tinstabcache),$ff);
        i:=0;
        while (i<InsTabEntries) do
          begin
            if InsTabCache^[InsTab[i].Opcode]=-1 then
              InsTabCache^[InsTab[i].Opcode]:=i;
            inc(i);
          end; *)
      end;


    procedure InitAsm;
      begin
        if not Assigned(instabcache) then
          BuildInsTabCache;
      end;


    procedure DoneAsm;
      begin
        if Assigned(instabcache) then
          begin
            dispose(instabcache);
            instabcache:=nil;
          end;
      end;


    function setoppostfix(i : TAICPU;pf : TOpPostfix) : TAICPU;
      begin
        i.oppostfix:=pf;
        result:=i;
      end;


    function setcondition(i : TAICPU;c : TAsmCond) : TAICPU;
      begin
        i.condition:=c;
        result:=i;
      end;


    Function SimpleGetNextInstruction(Current: TAI; Var Next: TAI): Boolean;
      Begin
        Current:=TAI(Current.Next);
        While Assigned(Current) And (Current.typ In SkipInstr) Do
          Current:=TAI(Current.Next);
        Next:=Current;
        If Assigned(Next) And Not(Next.typ In SkipInstr) Then
           Result:=True
          Else
            Begin
              Next:=Nil;
              Result:=False;
            End;
      End;


(*
    function armconstequal(hp1,hp2: tai): boolean;
      begin
        result:=false;
        if hp1.typ<>hp2.typ then
          exit;
        case hp1.typ of
          tai_const:
            result:=
              (tai_const(hp2).sym=tai_const(hp).sym) and
              (tai_const(hp2).value=tai_const(hp).value) and
              (tai(hp2.previous).typ=ait_label);
            tai_const:
              result:=
                (tai_const(hp2).sym=tai_const(hp).sym) and
                (tai_const(hp2).value=tai_const(hp).value) and
                (tai(hp2.previous).typ=ait_label);
        end;
      end;
*)

    procedure insertpcrelativedata(list,listtoinsert : TAsmList);
(*
      var
        curinspos,
        penalty,
        lastinspos,
        { increased for every data element > 4 bytes inserted }
        currentsize,
        extradataoffset,
        limit: longint;
        curop : longint;
        curtai : tai;
        curdatatai,hp,hp2 : tai;
        curdata : TAsmList;
        l : tasmlabel;
        doinsert,
        removeref : boolean;
*)
      begin
(*
        curdata:=TAsmList.create;
        lastinspos:=-1;
        curinspos:=0;
        extradataoffset:=0;
        limit:=1016;
        curtai:=tai(list.first);
        doinsert:=false;
        while assigned(curtai) do
          begin
            { instruction? }
            case curtai.typ of
              ait_instruction:
                begin
                  { walk through all operand of the instruction }
                  for curop:=0 to taicpu(curtai).ops-1 do
                    begin
                      { reference? }
                      if (taicpu(curtai).oper[curop]^.typ=top_ref) then
                        begin
                          { pc relative symbol? }
                          curdatatai:=tai(taicpu(curtai).oper[curop]^.ref^.symboldata);
                          if assigned(curdatatai) and
                            { move only if we're at the first reference of a label }
                            not(tai_label(curdatatai).moved) then
                            begin
                              tai_label(curdatatai).moved:=true;
                              { check if symbol already used. }
                              { if yes, reuse the symbol }
                              hp:=tai(curdatatai.next);
                              removeref:=false;
                              if assigned(hp) then
                                begin
                                  case hp.typ of
                                    ait_const:
                                      begin
                                        if (tai_const(hp).consttype=aitconst_64bit) then
                                          inc(extradataoffset);
                                      end;
                                    ait_realconst:
                                      begin
                                        inc(extradataoffset,((tai_realconst(hp).savesize-4+3) div 4));
                                      end;
                                  end;
                                  if (hp.typ=ait_const) then
                                    begin
                                      hp2:=tai(curdata.first);
                                      while assigned(hp2) do
                                        begin
    {                                      if armconstequal(hp2,hp) then }
                                          if (hp2.typ=ait_const) and (tai_const(hp2).sym=tai_const(hp).sym)
                                            and (tai_const(hp2).value=tai_const(hp).value) and (tai(hp2.previous).typ=ait_label)
                                          then
                                            begin
                                              with taicpu(curtai).oper[curop]^.ref^ do
                                                begin
                                                  symboldata:=hp2.previous;
                                                  symbol:=tai_label(hp2.previous).labsym;
                                                end;
                                              removeref:=true;
                                              break;
                                            end;
                                          hp2:=tai(hp2.next);
                                        end;
                                    end;
                                end;
                              { move or remove symbol reference }
                              repeat
                                hp:=tai(curdatatai.next);
                                listtoinsert.remove(curdatatai);
                                if removeref then
                                  curdatatai.free
                                else
                                  curdata.concat(curdatatai);
                                curdatatai:=hp;
                              until (curdatatai=nil) or (curdatatai.typ=ait_label);
                              if lastinspos=-1 then
                                lastinspos:=curinspos;
                            end;
                        end;
                    end;
                  inc(curinspos);
                end;
              ait_align:
                begin
                  { code is always 4 byte aligned, so we don't have to take care of .align 2 which would
                    requires also incrementing curinspos by 1 }
                  inc(curinspos,(tai_align(curtai).aligntype div 4));
                end;
              ait_const:
                begin
                  inc(curinspos);
                  if (tai_const(curtai).consttype=aitconst_64bit) then
                    inc(curinspos);
                end;
              ait_realconst:
                begin
                  inc(curinspos,(tai_realconst(hp).savesize+3) div 4);
                end;
            end;
            { special case for case jump tables }
            if SimpleGetNextInstruction(curtai,hp) and
              (tai(hp).typ=ait_instruction) and
              (taicpu(hp).opcode=A_LDR) and
              (taicpu(hp).oper[0]^.typ=top_reg) and
              (taicpu(hp).oper[0]^.reg=NR_PC) then
              begin
                penalty:=1;
                hp:=tai(hp.next);
                { skip register allocations and comments inserted by the optimizer }
                while assigned(hp) and (hp.typ in [ait_comment,ait_regalloc]) do
                  hp:=tai(hp.next);
                while assigned(hp) and (hp.typ=ait_const) do
                  begin
                    inc(penalty);
                    hp:=tai(hp.next);
                  end;
              end
            else
              penalty:=0;

            { FLD/FST VFP instructions have a limit of +/- 1024, not 4096 }
            if SimpleGetNextInstruction(curtai,hp) and
               (tai(hp).typ=ait_instruction) and
               ((taicpu(hp).opcode=A_FLDS) or
                (taicpu(hp).opcode=A_FLDD)) then
              limit:=254;

            { don't miss an insert }
            doinsert:=doinsert or
              (not(curdata.empty) and
               (curinspos-lastinspos+penalty+extradataoffset>limit));

            { split only at real instructions else the test below fails }
            if doinsert and (curtai.typ=ait_instruction) and
              (
                { don't split loads of pc to lr and the following move }
                not(
                    (taicpu(curtai).opcode=A_MOV) and
                    (taicpu(curtai).oper[0]^.typ=top_reg) and
                    (taicpu(curtai).oper[0]^.reg=NR_R14) and
                    (taicpu(curtai).oper[1]^.typ=top_reg) and
                    (taicpu(curtai).oper[1]^.reg=NR_PC)
                   )
              ) then
              begin
                lastinspos:=-1;
                extradataoffset:=0;
                limit:=1016;
                doinsert:=false;
                hp:=tai(curtai.next);
                current_asmdata.getjumplabel(l);
                curdata.insert(taicpu.op_sym(A_B,l));
                curdata.concat(tai_label.create(l));
                list.insertlistafter(curtai,curdata);
                curtai:=hp;
              end
            else
              curtai:=tai(curtai.next);
          end;
        list.concatlist(curdata);
        curdata.free;
*)
      end;


    procedure finalizearmcode(list, listtoinsert: TAsmList);
      begin
        insertpcrelativedata(list, listtoinsert);
      end;

(*
      Floating point instruction format information, taken from the linux kernel
      ARM Floating Point Instruction Classes
      | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | |
      |c o n d|1 1 0 P|U|u|W|L|   Rn  |v|  Fd |0|0|0|1|  o f f s e t  | CPDT
      |c o n d|1 1 0 P|U|w|W|L|   Rn  |x|  Fd |0|0|1|0|  o f f s e t  | CPDT (copro 2)
      | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | |
      |c o n d|1 1 1 0|a|b|c|d|e|  Fn |j|  Fd |0|0|0|1|f|g|h|0|i|  Fm | CPDO
      |c o n d|1 1 1 0|a|b|c|L|e|  Fn |   Rd  |0|0|0|1|f|g|h|1|i|  Fm | CPRT
      |c o n d|1 1 1 0|a|b|c|1|e|  Fn |1|1|1|1|0|0|0|1|f|g|h|1|i|  Fm | comparisons
      | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | | |

      CPDT            data transfer instructions
                      LDF, STF, LFM (copro 2), SFM (copro 2)

      CPDO            dyadic arithmetic instructions
                      ADF, MUF, SUF, RSF, DVF, RDF,
                      POW, RPW, RMF, FML, FDV, FRD, POL

      CPDO            monadic arithmetic instructions
                      MVF, MNF, ABS, RND, SQT, LOG, LGN, EXP,
                      SIN, COS, TAN, ASN, ACS, ATN, URD, NRM

      CPRT            joint arithmetic/data transfer instructions
                      FIX (arithmetic followed by load/store)
                      FLT (load/store followed by arithmetic)
                      CMF, CNF CMFE, CNFE (comparisons)
                      WFS, RFS (write/read floating point status register)
                      WFC, RFC (write/read floating point control register)

      cond            condition codes
      P               pre/post index bit: 0 = postindex, 1 = preindex
      U               up/down bit: 0 = stack grows down, 1 = stack grows up
      W               write back bit: 1 = update base register (Rn)
      L               load/store bit: 0 = store, 1 = load
      Rn              base register
      Rd              destination/source register
      Fd              floating point destination register
      Fn              floating point source register
      Fm              floating point source register or floating point constant

      uv              transfer length (TABLE 1)
      wx              register count (TABLE 2)
      abcd            arithmetic opcode (TABLES 3 & 4)
      ef              destination size (rounding precision) (TABLE 5)
      gh              rounding mode (TABLE 6)
      j               dyadic/monadic bit: 0 = dyadic, 1 = monadic
      i               constant bit: 1 = constant (TABLE 6)
      */

      /*
      TABLE 1
      +-------------------------+---+---+---------+---------+
      |  Precision              | u | v | FPSR.EP | length  |
      +-------------------------+---+---+---------+---------+
      | Single                  | 0 | 0 |    x    | 1 words |
      | Double                  | 1 | 1 |    x    | 2 words |
      | Extended                | 1 | 1 |    x    | 3 words |
      | Packed decimal          | 1 | 1 |    0    | 3 words |
      | Expanded packed decimal | 1 | 1 |    1    | 4 words |
      +-------------------------+---+---+---------+---------+
      Note: x = don't care
      */

      /*
      TABLE 2
      +---+---+---------------------------------+
      | w | x | Number of registers to transfer |
      +---+---+---------------------------------+
      | 0 | 1 |  1                              |
      | 1 | 0 |  2                              |
      | 1 | 1 |  3                              |
      | 0 | 0 |  4                              |
      +---+---+---------------------------------+
      */

      /*
      TABLE 3: Dyadic Floating Point Opcodes
      +---+---+---+---+----------+-----------------------+-----------------------+
      | a | b | c | d | Mnemonic | Description           | Operation             |
      +---+---+---+---+----------+-----------------------+-----------------------+
      | 0 | 0 | 0 | 0 | ADF      | Add                   | Fd := Fn + Fm         |
      | 0 | 0 | 0 | 1 | MUF      | Multiply              | Fd := Fn * Fm         |
      | 0 | 0 | 1 | 0 | SUF      | Subtract              | Fd := Fn - Fm         |
      | 0 | 0 | 1 | 1 | RSF      | Reverse subtract      | Fd := Fm - Fn         |
      | 0 | 1 | 0 | 0 | DVF      | Divide                | Fd := Fn / Fm         |
      | 0 | 1 | 0 | 1 | RDF      | Reverse divide        | Fd := Fm / Fn         |
      | 0 | 1 | 1 | 0 | POW      | Power                 | Fd := Fn ^ Fm         |
      | 0 | 1 | 1 | 1 | RPW      | Reverse power         | Fd := Fm ^ Fn         |
      | 1 | 0 | 0 | 0 | RMF      | Remainder             | Fd := IEEE rem(Fn/Fm) |
      | 1 | 0 | 0 | 1 | FML      | Fast Multiply         | Fd := Fn * Fm         |
      | 1 | 0 | 1 | 0 | FDV      | Fast Divide           | Fd := Fn / Fm         |
      | 1 | 0 | 1 | 1 | FRD      | Fast reverse divide   | Fd := Fm / Fn         |
      | 1 | 1 | 0 | 0 | POL      | Polar angle (ArcTan2) | Fd := arctan2(Fn,Fm)  |
      | 1 | 1 | 0 | 1 |          | undefined instruction | trap                  |
      | 1 | 1 | 1 | 0 |          | undefined instruction | trap                  |
      | 1 | 1 | 1 | 1 |          | undefined instruction | trap                  |
      +---+---+---+---+----------+-----------------------+-----------------------+
      Note: POW, RPW, POL are deprecated, and are available for backwards
            compatibility only.
      */

      /*
      TABLE 4: Monadic Floating Point Opcodes
      +---+---+---+---+----------+-----------------------+-----------------------+
      | a | b | c | d | Mnemonic | Description           | Operation             |
      +---+---+---+---+----------+-----------------------+-----------------------+
      | 0 | 0 | 0 | 0 | MVF      | Move                  | Fd := Fm              |
      | 0 | 0 | 0 | 1 | MNF      | Move negated          | Fd := - Fm            |
      | 0 | 0 | 1 | 0 | ABS      | Absolute value        | Fd := abs(Fm)         |
      | 0 | 0 | 1 | 1 | RND      | Round to integer      | Fd := int(Fm)         |
      | 0 | 1 | 0 | 0 | SQT      | Square root           | Fd := sqrt(Fm)        |
      | 0 | 1 | 0 | 1 | LOG      | Log base 10           | Fd := log10(Fm)       |
      | 0 | 1 | 1 | 0 | LGN      | Log base e            | Fd := ln(Fm)          |
      | 0 | 1 | 1 | 1 | EXP      | Exponent              | Fd := e ^ Fm          |
      | 1 | 0 | 0 | 0 | SIN      | Sine                  | Fd := sin(Fm)         |
      | 1 | 0 | 0 | 1 | COS      | Cosine                | Fd := cos(Fm)         |
      | 1 | 0 | 1 | 0 | TAN      | Tangent               | Fd := tan(Fm)         |
      | 1 | 0 | 1 | 1 | ASN      | Arc Sine              | Fd := arcsin(Fm)      |
      | 1 | 1 | 0 | 0 | ACS      | Arc Cosine            | Fd := arccos(Fm)      |
      | 1 | 1 | 0 | 1 | ATN      | Arc Tangent           | Fd := arctan(Fm)      |
      | 1 | 1 | 1 | 0 | URD      | Unnormalized round    | Fd := int(Fm)         |
      | 1 | 1 | 1 | 1 | NRM      | Normalize             | Fd := norm(Fm)        |
      +---+---+---+---+----------+-----------------------+-----------------------+
      Note: LOG, LGN, EXP, SIN, COS, TAN, ASN, ACS, ATN are deprecated, and are
            available for backwards compatibility only.
      */

      /*
      TABLE 5
      +-------------------------+---+---+
      |  Rounding Precision     | e | f |
      +-------------------------+---+---+
      | IEEE Single precision   | 0 | 0 |
      | IEEE Double precision   | 0 | 1 |
      | IEEE Extended precision | 1 | 0 |
      | undefined (trap)        | 1 | 1 |
      +-------------------------+---+---+
      */

      /*
      TABLE 5
      +---------------------------------+---+---+
      |  Rounding Mode                  | g | h |
      +---------------------------------+---+---+
      | Round to nearest (default)      | 0 | 0 |
      | Round toward plus infinity      | 0 | 1 |
      | Round toward negative infinity  | 1 | 0 |
      | Round toward zero               | 1 | 1 |
      +---------------------------------+---+---+
*)
    function TAICPU.GetString:string;
      var
        i : LongInt;
        s : string;
        addsize : boolean;
      begin
        s:='['+gas_op2str[opcode];
        for i:=0 to ops-1 do
         begin
           with oper[i]^ do
             begin
               if i=0 then
                s:=s+' '
               else
                s:=s+',';
               { type }
               addsize:=false;
               if (ot and OT_VREG)=OT_VREG then
                s:=s+'vreg'
               else
                 if (ot and OT_FPUREG)=OT_FPUREG then
                  s:=s+'fpureg'
               else
                if (ot and OT_REGISTER)=OT_REGISTER then
                 begin
                   s:=s+'reg';
                   addsize:=true;
                 end
               else
                if (ot and OT_REGLIST)=OT_REGLIST then
                 begin
                   s:=s+'reglist';
                   addsize:=false;
                 end
               else
                if (ot and OT_IMMEDIATE)=OT_IMMEDIATE then
                 begin
                   s:=s+'imm';
                   addsize:=true;
                 end
               else
                if (ot and OT_MEMORY)=OT_MEMORY then
                 begin
                   s:=s+'mem';
                   addsize:=true;
                   if (ot and OT_AM2)<>0 then
                     s:=s+' am2 ';
                 end
               else
                 s:=s+'???';
               { size }
               if addsize then
                begin
                  if (ot and OT_BITS8)<>0 then
                    s:=s+'8'
                  else
                   if (ot and OT_BITS16)<>0 then
                    s:=s+'24'
                  else
                   if (ot and OT_BITS32)<>0 then
                    s:=s+'32'
                  else
                   if (ot and OT_BITSSHIFTER)<>0 then
                    s:=s+'shifter'
                  else
                    s:=s+'??';
                  { signed }
                  if (ot and OT_SIGNED)<>0 then
                   s:=s+'s';
                end;
             end;
         end;
        GetString:=s+']';
      end;


    procedure TAICPU.ResetPass1;
      begin
        { we need to reset everything here, because the choosen insentry
          can be invalid for a new situation where the previously optimized
          insentry is not correct }
      end;


    procedure TAICPU.ResetPass2;
      begin
        { we are here in a second pass, check if the instruction can be optimized }
      end;


    function TAICPU.CheckIfValid:boolean;
      begin
        Result:=False; { unimplemented }
      end;


    function TAICPU.Pass1(objdata:TObjData):LongInt;
      begin
        Pass1:=0;
      end;


    procedure TAICPU.Pass2(objdata:TObjData);
      begin
        { error in pass1 ? }
        CurrentFilePos:=fileinfo;
        { Generate the instruction }
        { GenCode(objdata); }
      end;


    procedure TAICPU.ppuloadoper(ppufile:TCompilerPPUFile;var o:TOper);
      begin
      end;


    procedure TAICPU.ppuwriteoper(ppufile:TCompilerPPUFile;const o:TOper);
      begin
      end;


    procedure TAICPU.ppubuildderefimploper(var o:TOper);
      begin
      end;


    procedure TAICPU.ppuderefoper(var o:TOper);
      begin
      end;


begin
  CAIAlign:=TAIAlign;
end.

