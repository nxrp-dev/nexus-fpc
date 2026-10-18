{
    Copyright (c) 1998-2005 by Florian Klaempfl
    Member of the Free Pascal development team

    This unit implements the basic code generator object

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
{# @abstract(Abstract code generator unit)
   Abstract code generator unit. This contains the base class
   to implement for all new supported processors.

   WARNING: None of the routines implemented in these modules,
   or their descendants, should use the temp. allocator, as
   these routines may be called inside genentrycode, and the
   stack frame is already setup!
}
unit cgobj;

{$i fpcdefs.inc}

  interface

    uses
       GlobType,ConstExp,
       CPUBase,CGBase,CGUtils,ParaBase,
       AAsmBase,AAsmTAI,AAsmData,AAsmCPU,
       SymConst,SymType,SymDef,RGObj
       ;

    type
       TAlignment = (AM_NATURAL,AM_NONE,AM_2BYTE,AM_4BYTE,AM_8BYTE);

       {# @abstract(Abstract code generator)
          This class implements an abstract instruction generator. Some of
          the methods of this class are generic, while others must
          be overridden for all new processors which will be supported
          by Free Pascal. For 32-bit processors, the base class
          should be @link(tcg64f32) and not @var(tcg).
       }

       { tcg }

       TCG = class
          { how many times is this current code executed }
          ExecutionWeight : LongInt;
          Alignment : TAlignment;
          RG        : array[TRegisterType] of TRGObj;

       {$ifdef flowgraph}
          AktFlowNode:Word;
       {$endif}
          {************************************************}
          {                 basic routines                 }
          constructor Create;

          {# Initialize the register allocators needed for the codegenerator.}
          procedure Init_Register_Allocators;virtual;
          {# Clean up the register allocators needed for the codegenerator.}
          procedure Done_Register_Allocators;virtual;
          {# Set whether live_start or live_end should be updated when allocating registers, needed when e.g. generating initcode after the rest of the code. }
          procedure Set_RegAlloc_Live_Range_Direction(Dir: TRADirection);

       {$ifdef flowgraph}
          procedure Init_FlowGraph;
          procedure Done_FlowGraph;
       {$endif}
          {# Gets a register suitable to do integer operations on.}
          function GetIntRegister(List:TAsmList;Size:TCgSize):TRegister;virtual;
          {# Gets a register suitable to do integer operations on.}
          function GetAddressRegister(List:TAsmList):TRegister;virtual;
          function GetFPURegister(List:TAsmList;Size:TCgSize):TRegister;virtual;
          function GetMMRegister(List:TAsmList;Size:TCgSize):TRegister;virtual;
          function GetFlagRegister(List:TAsmList;Size:TCgSize):TRegister;virtual;
          function GetTempRegister(List:TAsmList):TRegister;virtual;
          {Does the generic cg need SIMD registers, like getmmxregister? Or should
           the cpu specific child cg object have such a method?}




          procedure Add_Reg_Instruction(Instr:TAI;R:TRegister);virtual;
          procedure Add_Move_Instruction(Instr:TAICPU);virtual;

          function  Uses_Registers(RT:TRegisterType):Boolean;virtual;
          {# Get a specific register.}
          procedure GetCPURegister(List:TAsmList;R:TRegister);virtual;
          procedure UngetCPURegister(List:TAsmList;R:TRegister);virtual;
          {# Get multiple registers specified.}
          procedure AllocCPURegisters(List:TAsmList;RT:TRegisterType;const R:TCPURegisterSet);virtual;
          {# Free multiple registers specified.}
          procedure DeallocCPURegisters(List:TAsmList;RT:TRegisterType;const R:TCPURegisterSet);virtual;

          procedure AllocAllCPURegisters(List:TAsmList);virtual;
          procedure DeallocAllCPURegisters(List:TAsmList);virtual;
          procedure Do_Register_Allocation(List:TAsmList;HeaderTAI:TAI);virtual;
          procedure Translate_Register(var Reg : TRegister);

          function MakeRegSize(List:TAsmList;Reg:TRegister;Size:TCgSize):TRegister; virtual;

          {# Emit a label to the instruction stream. }
          procedure A_Label(List : TAsmList;L : TAsmLabel);virtual;
          {# Emit a label that can be a target of a Pascal goto statement to the instruction stream. }
          procedure A_Label_Pascal_Goto_Target(List : TAsmList;L : TAsmLabel);virtual;

          {# Allocates register r by inserting a pai_realloc record }
          procedure A_Reg_Alloc(List : TAsmList;R : TRegister);
          {# Deallocates register r by inserting a pa_regdealloc record}
          procedure A_Reg_Dealloc(List : TAsmList;R : TRegister);
          { Synchronize register, make sure it is still valid }
          procedure A_Reg_Sync(List : TAsmList;R : TRegister);

          {# Pass a parameter, which is located in a register, to a routine.

             This routine should push/send the parameter to the routine, as
             required by the specific processor ABI and routine modifiers.
             It must generate register allocation information for the cgpara in
             case it consists of cpuregisters.

             @param(size size of the operand in the register)
             @param(r register source of the operand)
             @param(cgpara where the parameter will be stored)
          }
          procedure A_Load_Reg_CGPara(List : TAsmList;Size : TCgSize;R : TRegister;const CGPara : TCGPara);virtual;
          {# Pass a parameter, which is a constant, to a routine.

             A generic version is provided. This routine should
             be overridden for optimization purposes if the cpu
             permits directly sending this type of parameter.
             It must generate register allocation information for the cgpara in
             case it consists of cpuregisters.

             @param(size size of the operand in constant)
             @param(a value of constant to send)
             @param(cgpara where the parameter will be stored)
          }
          procedure A_Load_Const_CGPara(List : TAsmList;Size : TCgSize;A : TCGInt;const CGPara : TCGPara);virtual;
          {# Pass the value of a parameter, which is located in memory, to a routine.

             A generic version is provided. This routine should
             be overridden for optimization purposes if the cpu
             permits directly sending this type of parameter.
             It must generate register allocation information for the cgpara in
             case it consists of cpuregisters.

             @param(size size of the operand in constant)
             @param(r Memory reference of value to send)
             @param(cgpara where the parameter will be stored)
          }
          procedure A_Load_Ref_CGPara(List : TAsmList;Size : TCgSize;const R : TReference;const CGPara : TCGPara);virtual;
         protected
          procedure A_Load_Ref_CGParaLocRef(List: TAsmList; SourceSize: TCgSize; SizeLeft: TCGInt; const Ref, ParaLocRef: TReference; const CGPara: TCGPara; const Location: PCGParaLocation); virtual;
         public
          {# Pass the value of a parameter, which can be located either in a register or memory location,
             to a routine.

             A generic version is provided.

             @param(l location of the operand to send)
             @param(nr parameter number (starting from one) of routine (from left to right))
             @param(cgpara where the parameter will be stored)
          }
          procedure A_Load_Loc_CGPara(List : TAsmList;const L : TLocation;const CGPara : TCGPara);
          {# Pass the address of a reference to a routine. This routine
             will calculate the address of the reference, and pass this
             calculated address as a parameter.
             It must generate register allocation information for the cgpara in
             case it consists of cpuregisters.

             A generic version is provided. This routine should
             be overridden for optimization purposes if the cpu
             permits directly sending this type of parameter.

             @param(r reference to get address from)
             @param(nr parameter number (starting from one) of routine (from left to right))
          }
          procedure A_LoadAddr_Ref_CGPara(List : TAsmList;const R : TReference;const CGPara : TCGPara);virtual;

          {# Load a cgparaloc into a memory reference.
             It must generate register allocation information for the cgpara in
             case it consists of cpuregisters.

           @param(paraloc the source parameter sublocation)
           @param(ref the destination reference)
           @param(sizeleft indicates the total number of bytes left in all of
                  the remaining sublocations of this parameter (the current
                  sublocation and all of the sublocations coming after it).
                  In case this location is also a reference, it is assumed
                  to be the final part sublocation of the parameter and that it
                  contains all of the "sizeleft" bytes).)
           @param(align the alignment of the paraloc in case it's a reference)
          }
          procedure A_Load_CGParaLoc_Ref(List : TAsmList;const ParaLoc : TCGParaLocation;const Ref : TReference;SizeLeft : TCGInt;Align : LongInt);

          {# Load a cgparaloc into any kind of register (int, fp, mm).

           @param(regsize the size of the destination register)
           @param(paraloc the source parameter sublocation)
           @param(reg the destination register)
           @param(align the alignment of the paraloc in case it's a reference)
          }
          procedure A_Load_CGParaLoc_AnyReg(List : TAsmList;RegSize : TCgSize;const ParaLoc : TCGParaLocation;Reg : TRegister;Align : LongInt);

          { Remarks:
            * If a method specifies a size you have only to take care
              of that number of bits, i.e. load_const_reg with OP_8 must
              only load the lower 8 bit of the specified register
              the rest of the register can be undefined
              if  necessary the compiler will call a method
              to zero or sign extend the register
            * The a_load_XX_XX with OP_64 needn't to be
              implemented for 32 bit
              processors, the code generator takes care of that
            * the addr size is for work with the natural pointer
              size
            * the procedures without fpu/mm are only for integer usage
            * normally the first location is the source and the
              second the destination
          }

          {# Emits instruction to call the method specified by symbol name.
             This routine must be overridden for each new target cpu.
          }
          procedure A_Call_Name(List : TAsmList;const S : string; Weak: Boolean);virtual; abstract;
          procedure A_Call_Reg(List : TAsmList;Reg : TRegister);virtual; abstract;
          { same as a_call_name, might be overridden on certain architectures to emit
            static calls without usage of a got trampoline }
          procedure A_Call_Name_Static(List : TAsmList;const S : string);virtual;

          { move instructions }
          procedure A_Load_Const_Reg(List : TAsmList;Size : TCgSize;A : TCGInt;Register : TRegister);virtual; abstract;
          procedure A_Load_Const_Ref(List : TAsmList;Size : TCgSize;A : TCGInt;const Ref : TReference);virtual;
          procedure A_Load_Const_Loc(List : TAsmList;A : TCGInt;const Loc : TLocation);
          procedure A_Load_Reg_Ref(List : TAsmList;FromSize,ToSize : TCgSize;Register : TRegister;const Ref : TReference);virtual; abstract;
          procedure A_Load_Reg_Ref_Unaligned(List : TAsmList;FromSize,ToSize : TCgSize;Register : TRegister;const Ref : TReference);virtual;
          procedure A_Load_Reg_Reg(List : TAsmList;FromSize,ToSize : TCgSize;Reg1,Reg2 : TRegister);virtual; abstract;
          procedure A_Load_Reg_Loc(List : TAsmList;FromSize : TCgSize;Reg : TRegister;const Loc: TLocation);
          procedure A_Load_Ref_Reg(List : TAsmList;FromSize,ToSize : TCgSize;const Ref : TReference;Register : TRegister);virtual; abstract;
          procedure A_Load_Ref_Reg_Unaligned(List : TAsmList;FromSize,ToSize : TCgSize;const Ref : TReference;Register : TRegister);virtual;
          procedure A_Load_Ref_Ref(List : TAsmList;FromSize,ToSize : TCgSize;const SRef : TReference;const DRef : TReference);virtual;
          procedure A_Load_Loc_Reg(List : TAsmList;ToSize: TCgSize; const Loc: TLocation; Reg : TRegister);
          procedure A_Load_Loc_Ref(List : TAsmList;ToSize: TCgSize; const Loc: TLocation; const Ref : TReference);
          procedure A_LoadAddr_Ref_Reg(List : TAsmList;const Ref : TReference;R : TRegister);virtual; abstract;

          { bit scan instructions }
          procedure A_Bit_Scan_Reg_Reg(List: TAsmList; Reverse,NotZero: Boolean; SrcSize, DstSize: TCgSize; Src, Dst: TRegister); virtual;

          { Multiplication with doubling result size.
            dstlo or dsthi may be NR_NO, in which case corresponding half of result is discarded. }
          procedure A_Mul_Reg_Reg_Pair(List: TAsmList; Size: TCgSize; Src1,Src2,DstLo,DstHi: TRegister);virtual;

          { fpu move instructions }
          procedure A_LoadFPU_Reg_Reg(List: TAsmList; FromSize, ToSize:TCgSize; Reg1, Reg2: TRegister); virtual; abstract;
          procedure A_LoadFPU_Ref_Reg(List: TAsmList; FromSize, ToSize: TCgSize; const Ref: TReference; Reg: TRegister); virtual; abstract;
          procedure A_LoadFPU_Reg_Ref(List: TAsmList; FromSize, ToSize: TCgSize; Reg: TRegister; const Ref: TReference); virtual; abstract;
          procedure A_LoadFPU_Ref_Ref(List: TAsmList; FromSize, ToSize: TCgSize; const Ref1,Ref2: TReference);
          procedure A_LoadFPU_Loc_Reg(List: TAsmList; ToSize: TCgSize; const Loc: TLocation; const Reg: TRegister);
          procedure A_LoadFPU_Reg_Loc(List: TAsmList; FromSize: TCgSize; const Reg: TRegister; const Loc: TLocation);
          procedure A_LoadFPU_Reg_CGPara(List : TAsmList;Size : TCgSize;const R : TRegister;const CGPara : TCGPara);virtual;
          procedure A_LoadFPU_Ref_CGPara(List : TAsmList;Size : TCgSize;const Ref : TReference;const CGPara : TCGPara);virtual;

          procedure A_LoadFPU_IntReg_Reg(List: TAsmList; FromSize, ToSize : TCgSize; IntReg, FPUReg: TRegister); virtual;
          procedure A_LoadFPU_Reg_IntReg(List: TAsmList; FromSize, ToSize: TCgSize; FPUReg, IntReg: TRegister); virtual;

          { vector register move instructions }
          procedure A_LoadMM_Reg_Reg(List: TAsmList; FromSize, ToSize : TCgSize;Reg1, Reg2: TRegister;Shuffle : PMMShuffle); virtual;
          procedure A_LoadMM_Ref_Reg(List: TAsmList; FromSize, ToSize : TCgSize;const Ref: TReference; Reg: TRegister;Shuffle : PMMShuffle); virtual;
          procedure A_LoadMM_Reg_Ref(List: TAsmList; FromSize, ToSize : TCgSize;Reg: TRegister; const Ref: TReference;Shuffle : PMMShuffle); virtual;
          procedure A_LoadMM_Loc_Reg(List: TAsmList; Size: TCgSize; const Loc: TLocation; const Reg: TRegister;Shuffle : PMMShuffle);
          procedure A_LoadMM_Reg_Loc(List: TAsmList; Size: TCgSize; const Reg: TRegister; const Loc: TLocation;Shuffle : PMMShuffle);
          procedure A_LoadMM_Reg_CGPara(List: TAsmList; Size: TCgSize; Reg: TRegister;const CGPara : TCGPara;Shuffle : PMMShuffle); virtual;
          procedure A_LoadMM_Ref_CGPara(List: TAsmList; Size: TCgSize; const Ref: TReference;const CGPara : TCGPara;Shuffle : PMMShuffle); virtual;
          procedure A_LoadMM_Loc_CGPara(List: TAsmList; const Loc: TLocation; const CGPara : TCGPara;Shuffle : PMMShuffle); virtual;
          procedure A_OpMM_Reg_Reg(List: TAsmList; Op: TOpCG; Size : TCgSize;Src,Dst: TRegister;Shuffle : PMMShuffle); virtual;
          procedure A_OpMM_Ref_Reg(List: TAsmList; Op: TOpCG; Size : TCgSize;const Ref: TReference; Reg: TRegister;Shuffle : PMMShuffle); virtual;
          procedure A_OpMM_Loc_Reg(List: TAsmList; Op: TOpCG; Size : TCgSize;const Loc: TLocation; Reg: TRegister;Shuffle : PMMShuffle); virtual;
          procedure A_OpMM_Reg_Ref(List: TAsmList; Op: TOpCG; Size : TCgSize;Reg: TRegister;const Ref: TReference; Shuffle : PMMShuffle); virtual;
          procedure A_OpMM_Loc_Reg_Reg(List: TAsmList;Op : TOpCG;Size : TCgSize;const Loc : TLocation;Src,Dst : TRegister;Shuffle : PMMShuffle); virtual;
          procedure A_OpMM_Reg_Reg_Reg(List: TAsmList; Op: TOpCG; Size : TCgSize;Src1,Src2,Dst: TRegister;Shuffle : PMMShuffle); virtual;
          procedure A_OpMM_Ref_Reg_Reg(List: TAsmList; Op: TOpCG; Size : TCgSize;const Ref: TReference; Src,Dst: TRegister;Shuffle : PMMShuffle); virtual;

          procedure A_LoadMM_IntReg_Reg(List: TAsmList; FromSize, ToSize : TCgSize; IntReg, MMReg: TRegister; Shuffle: PMMShuffle); virtual;
          procedure A_LoadMM_Reg_IntReg(List: TAsmList; FromSize, ToSize : TCgSize; MMReg, IntReg: TRegister; Shuffle : PMMShuffle); virtual;

          { basic arithmetic operations }
          procedure A_Op_Const_Reg(List : TAsmList; Op: TOpCG; Size: TCgSize; A: TCGInt; Reg: TRegister); virtual; abstract;
          procedure A_Op_Const_Ref(List : TAsmList; Op: TOpCG; Size: TCgSize; A: TCGInt; const Ref: TReference); virtual;
          procedure A_Op_Const_Loc(List : TAsmList; Op: TOpCG; A: TCGInt; const Loc: TLocation);
          procedure A_Op_Reg_Reg(List : TAsmList; Op: TOpCG; Size: TCgSize; Reg1, Reg2: TRegister); virtual; abstract;
          procedure A_Op_Reg_Ref(List : TAsmList; Op: TOpCG; Size: TCgSize; Reg: TRegister; const Ref: TReference); virtual;
          procedure A_Op_Ref_Reg(List : TAsmList; Op: TOpCG; Size: TCgSize; const Ref: TReference; Reg: TRegister); virtual;
          procedure A_Op_Reg_Loc(List : TAsmList; Op: TOpCG; Reg: TRegister; const Loc: TLocation);
          procedure A_Op_Loc_Reg(List : TAsmList; Op: TOpCG; Size: TCgSize; const Loc: TLocation; Reg: TRegister);
          procedure A_Op_Ref_Loc(List : TAsmList; Op: TOpCG; const Ref: TReference; const Loc: TLocation);

          { trinary operations for processors that support them, 'emulated' }
          { on others. None with "ref" arguments since I don't think there  }
          { are any processors that support it (JM)                         }
          procedure A_Op_Const_Reg_Reg(List: TAsmList; Op: TOpCG; Size: TCgSize; A: TCGInt; Src, Dst: TRegister); virtual;
          procedure A_Op_Reg_Reg_Reg(List: TAsmList; Op: TOpCG; Size: TCgSize; Src1, Src2, Dst: TRegister); virtual;
          procedure A_Op_Const_Reg_Reg_CheckOverflow(List: TAsmList; Op: TOpCG; Size: TCgSize; A: TCGInt; Src, Dst: TRegister;SetFlags : Boolean;var OVLoc : TLocation); virtual;
          procedure A_Op_Reg_Reg_Reg_CheckOverflow(List: TAsmList; Op: TOpCG; Size: TCgSize; Src1, Src2, Dst: TRegister;SetFlags : Boolean;var OVLoc : TLocation); virtual;

          { unary operations (not, neg) }
          procedure A_Op_Reg(List : TAsmList; Op: TOpCG; Size: TCgSize; Reg: TRegister); virtual;
          procedure A_Op_Ref(List : TAsmList; Op: TOpCG; Size: TCgSize; const Ref: TReference); virtual;
          procedure A_Op_Loc(List : TAsmList; Op: TOpCG; const Loc: TLocation);

          {  comparison operations }
          procedure A_Cmp_Const_Reg_Label(List : TAsmList;Size : TCgSize;CmpOp : TOpCmp;A : TCGInt;Reg : TRegister;
            L : TAsmLabel); virtual;
          procedure A_Cmp_Const_Ref_Label(List : TAsmList;Size : TCgSize;CmpOp : TOpCmp;A : TCGInt;const Ref : TReference;
            L : TAsmLabel); virtual;
          procedure A_Cmp_Const_Loc_Label(List: TAsmList; Size: TCgSize;CmpOp: TOpCmp; A: TCGInt; const Loc: TLocation;
            L : TAsmLabel);
          procedure A_Cmp_Reg_Reg_Label(List : TAsmList;Size : TCgSize;CmpOp : TOpCmp;Reg1,Reg2 : TRegister;L : TAsmLabel); virtual; abstract;
          procedure A_Cmp_Ref_Reg_Label(List : TAsmList;Size : TCgSize;CmpOp : TOpCmp; const Ref: TReference; Reg : TRegister; L : TAsmLabel); virtual;
          procedure A_Cmp_Reg_Ref_Label(List : TAsmList;Size : TCgSize;CmpOp : TOpCmp;Reg : TRegister; const Ref: TReference; L : TAsmLabel); virtual;

          procedure A_Cmp_Loc_Reg_Label(List : TAsmList;Size : TCgSize;CmpOp : TOpCmp; const Loc: TLocation; Reg : TRegister; L : TAsmLabel);
          procedure A_Cmp_Reg_Loc_Label(List : TAsmList;Size : TCgSize;CmpOp : TOpCmp; Reg: TRegister; const Loc: TLocation; L : TAsmLabel);
          procedure A_Cmp_Ref_Loc_Label(List: TAsmList; Size: TCgSize;CmpOp: TOpCmp; const Ref: TReference; const Loc: TLocation;
            L : TAsmLabel);

          procedure A_Jmp_Name(List : TAsmList;const S : string); virtual; abstract;
          procedure A_Jmp_Always(List : TAsmList;L: TAsmLabel); virtual; abstract;
{$ifdef cpuflags}
          procedure A_Jmp_Flags(List : TAsmList;const F : TResFlags;L: TAsmLabel); virtual; abstract;

          {# Depending on the value to check in the flags, either sets the register reg to one (if the flag is set)
             or zero (if the flag is cleared). The size parameter indicates the destination size register.
          }
          procedure G_Flags2Reg(List: TAsmList; Size: TCgSize; const F: TResFlags; Reg: TRegister); virtual; abstract;
          procedure G_Flags2Ref(List: TAsmList; Size: TCgSize; const F: TResFlags; const Ref:TReference); virtual;
{$endif cpuflags}

          {
             This routine tries to optimize the op_const_reg/ref opcode, and should be
             called at the start of a_op_const_reg/ref. It returns the actual opcode
             to emit, and the constant value to emit. This function can opcode OP_NONE to
             remove the opcode and OP_MOVE to replace it with a simple load

             @param(size Size of the operand in constant)
             @param(op The opcode to emit, returns the opcode which must be emitted)
             @param(a  The constant which should be emitted, returns the constant which must
                    be emitted)
          }
          procedure Optimize_Op_Const(Size: TCgSize; var Op: TOpCG; var A : TCGInt);virtual;


          {# This emits code to copy len bytes from the source using the move procedure

             @param(source Source reference of copy)
             @param(dest Destination reference of copy)

          }
          procedure G_ConcatCopy_Move(List : TAsmList;const Source,Dest : TReference;Len : TCGInt);virtual;

          {# This should emit the opcode to copy len bytes from the source
             to destination.

             It must be overridden for each new target processor.

             @param(source Source reference of copy)
             @param(dest Destination reference of copy)

          }
          procedure G_ConcatCopy(List : TAsmList;const Source,Dest : TReference;Len : TCGInt);virtual; abstract;
          {# This should emit the opcode to copy len bytes from the an unaligned source
             to destination.

             It must be overridden for each new target processor.

             @param(source Source reference of copy)
             @param(dest Destination reference of copy)

          }
          procedure G_ConcatCopy_Unaligned(List : TAsmList;const Source,Dest : TReference;Len : TCGInt);virtual;

          {# Generates overflow checking code for a node }
          procedure G_OverflowCheck(List: TAsmList; const Loc:TLocation; Def:TDef); virtual;abstract;
          procedure G_OverflowCheck_Loc(List:TAsmList;const Loc:TLocation;Def:TDef;OVLoc : TLocation);virtual;

          {# Emits instruction for allocating @var(size) bytes at the stackpointer

             @param(size Number of bytes to allocate)
          }
          procedure G_StackPointer_Alloc(List : TAsmList;Size : LongInt);virtual;
          {# Emits instruction for allocating the locals in entry
             code of a routine. This is one of the first
             routine called in @var(genentrycode).

             @param(localsize Number of bytes to allocate as locals)
          }
          procedure G_Proc_Entry(List : TAsmList;LocalSize : LongInt;NoStackFrame:Boolean);virtual; abstract;
          {# Emits instructions for returning from a subroutine.
             Should also restore the framepointer and stack.

             @param(parasize  Number of bytes of parameters to deallocate from stack)
          }
          procedure G_Proc_Exit(List : TAsmList;ParaSize:LongInt;NoStackFrame:Boolean);virtual;abstract;
          {# This routine is called when generating the code for the entry point
             of a routine. It should save all registers which are not used in this
             routine, and which should be declared as saved in the std_saved_registers
             set.

             This routine is mainly used when linking to code which is generated
             by ABI-compliant compilers (like GCC), to make sure that the reserved
             registers of that ABI are not clobbered.

             @param(usedinproc Registers which are used in the code of this routine)
          }
          procedure G_Save_Registers(List:TAsmList);virtual;
          {# This routine is called when generating the code for the exit point
             of a routine. It should restore all registers which were previously
             saved in @var(g_save_standard_registers).

             @param(usedinproc Registers which are used in the code of this routine)
          }
          procedure G_Restore_Registers(List:TAsmList);virtual;

          procedure G_Adjust_Self_Value(List:TAsmList;ProcDef: TProcDef;IOffset: TCGInt);virtual;

          { initialize the pic/got register }
          procedure G_Maybe_Got_Init(List: TAsmList); virtual;
          { initialize the tls register if needed }
          procedure G_Maybe_TLS_Init(List : TAsmList); virtual;
          { allocallcpuregisters, a_call_name, deallocallcpuregisters sequence }
          procedure G_Call(List: TAsmList; const S: string);
          { Generate code to exit an unwind-protected region. The default implementation
            produces a simple jump to destination label. }
          procedure G_Local_Unwind(List: TAsmList; L: TAsmLabel);virtual;
          { Generate code for integer division by constant,
            generic version is suitable for 3-address CPUs }
          procedure G_Div_Const_Reg_Reg(List:TAsmList; Size: TCgSize; A: TCGInt; Src,Dst: TRegister); virtual;

          { some CPUs do not support hardware fpu exceptions, this procedure is called after instructions which
            might set FPU exception related flags, so it has to check these flags if needed and throw an exeception }
          procedure G_Check_For_FPU_Exception(List : TAsmList; Force,Clear : Boolean); virtual;
          procedure Maybe_Check_For_FPU_Exception(List: TAsmList);

          { Called to adjust references in exceptfilter handlers. Override
            in CPU-specific code generator for platforms that need special handling
            (e.g., AArch64-Win64 where SP-relative references must be converted to FP-relative).
            Set for_finalization=true when called during finalization of parent's temps
            for an exceptfilter (current_procinfo is parent, finalize_procinfo is exceptfilter). }
          procedure Adjust_ExceptFilter_Ref(var Ref: TReference; ForFinalization: Boolean); virtual;

         protected
          function G_Indirect_Sym_Load(List:TAsmList;const SymName: string; const Flags: TIndSymFlags): TRegister;virtual;
       end;

{$ifdef cpu64bitalu}
    {  This class implements an abstract code generator class
       for 128 Bit operations, it applies currently only to 64 Bit CPUs and supports only simple operations
    }
    TCG128 = class
        procedure A_Load128_Reg_Reg(List : TAsmList;RegSrc,RegDst : TRegister128);virtual;
        procedure A_Load128_Reg_Ref(List : TAsmList;Reg : TRegister128;const Ref : TReference);virtual;
        procedure A_Load128_Ref_Reg(List : TAsmList;const Ref : TReference;Reg : TRegister128);virtual;
        procedure A_Load128_Loc_Ref(List : TAsmList;const L : TLocation;const Ref : TReference);virtual;
        procedure A_Load128_Reg_Loc(List : TAsmList;Reg : TRegister128;const L : TLocation);virtual;
        procedure A_Load128_Const_Reg(List : TAsmList;ValueLo,ValueHi : Int64;Reg : TRegister128);virtual;

        procedure A_Load128_Loc_CGPara(List : TAsmList;const L : TLocation;const ParaLoc : TCGPara);virtual;
        procedure A_Load128_Ref_CGPara(List: TAsmList; const R: TReference;const ParaLoc: TCGPara);
        procedure A_Load128_Reg_CGPara(List: TAsmList; Reg: TRegister128;const ParaLoc: TCGPara);
    end;

    { Creates a tregister128 record from 2 64 Bit registers. }
    function JoinReg128(RegLo,RegHi : TRegister) : TRegister128;

{$else cpu64bitalu}
    {# @abstract(Abstract code generator for 64 Bit operations)
       This class implements an abstract code generator class
       for 64 Bit operations.
    }
    TCG64 = class
        procedure A_Load64_Const_Ref(List : TAsmList;Value : Int64;const Ref : TReference);virtual;abstract;
        procedure A_Load64_Reg_Ref(List : TAsmList;Reg : TRegister64;const Ref : TReference);virtual;abstract;
        procedure A_Load64_Ref_Reg(List : TAsmList;const Ref : TReference;Reg : TRegister64);virtual;abstract;
        procedure A_Load64_Reg_Reg(List : TAsmList;RegSrc,RegDst : TRegister64);virtual;abstract;
        procedure A_Load64_Const_Reg(List : TAsmList;Value : Int64;Reg : TRegister64);virtual;abstract;
        procedure A_Load64_Loc_Reg(List : TAsmList;const L : TLocation;Reg : TRegister64);virtual;abstract;
        procedure A_Load64_Loc_Ref(List : TAsmList;const L : TLocation;const Ref : TReference);virtual;abstract;
        procedure A_Load64_Const_Loc(List : TAsmList;Value : Int64;const L : TLocation);virtual;abstract;
        procedure A_Load64_Reg_Loc(List : TAsmList;Reg : TRegister64;const L : TLocation);virtual;abstract;

        procedure A_Load64_SubsetRef_Reg(List : TAsmList; const SRef: TSubsetReference; DestReg: TRegister64);virtual;abstract;
        procedure A_Load64_Reg_SubsetRef(List : TAsmList; FromReg: TRegister64; const SRef: TSubsetReference);virtual;abstract;
        procedure A_Load64_Const_SubsetRef(List: TAsmList; A: Int64; const SRef: TSubsetReference);virtual;abstract;
        procedure A_Load64_Ref_SubsetRef(List : TAsmList; const FromRef: TReference; const SRef: TSubsetReference);virtual;abstract;
        procedure A_Load64_SubsetRef_SubsetRef(List: TAsmList; const FromSRef, ToSRef: TSubsetReference); virtual;abstract;
        procedure A_Load64_SubsetRef_Ref(List : TAsmList; const SRef: TSubsetReference; const DestRef: TReference); virtual;abstract;
        procedure A_Load64_Loc_SubsetRef(List : TAsmList; const L: TLocation; const SRef : TSubsetReference);
        procedure A_Load64_SubsetRef_Loc(List: TAsmList; const SRef: TSubsetReference; const L: TLocation);

        procedure A_Load64High_Reg_Ref(List : TAsmList;Reg : TRegister;const Ref : TReference);virtual;abstract;
        procedure A_Load64Low_Reg_Ref(List : TAsmList;Reg : TRegister;const Ref : TReference);virtual;abstract;
        procedure A_Load64High_Ref_Reg(List : TAsmList;const Ref : TReference;Reg : TRegister);virtual;abstract;
        procedure A_Load64Low_Ref_Reg(List : TAsmList;const Ref : TReference;Reg : TRegister);virtual;abstract;
        procedure A_Load64High_Loc_Reg(List : TAsmList;const L : TLocation;Reg : TRegister);virtual;abstract;
        procedure A_Load64Low_Loc_Reg(List : TAsmList;const L : TLocation;Reg : TRegister);virtual;abstract;

        procedure A_Op64_Ref_Reg(List : TAsmList;Op:TOpCG;Size : TCgSize;const Ref : TReference;Reg : TRegister64);virtual;abstract;
        procedure A_Op64_Reg_Reg(List : TAsmList;Op:TOpCG;Size : TCgSize;RegSrc,RegDst : TRegister64);virtual;abstract;
        procedure A_Op64_Reg_Ref(List : TAsmList;Op:TOpCG;Size : TCgSize;RegSrc : TRegister64;const Ref : TReference);virtual;abstract;
        procedure A_Op64_Const_Reg(List : TAsmList;Op:TOpCG;Size : TCgSize;Value : Int64;RegDst : TRegister64);virtual;abstract;
        procedure A_Op64_Const_Ref(List : TAsmList;Op:TOpCG;Size : TCgSize;Value : Int64;const Ref : TReference);virtual;abstract;
        procedure A_Op64_Const_Loc(List : TAsmList;Op:TOpCG;Size : TCgSize;Value : Int64;const L: TLocation);virtual;abstract;
        procedure A_Op64_Reg_Loc(List : TAsmList;Op:TOpCG;Size : TCgSize;Reg : TRegister64;const L : TLocation);virtual;abstract;
        procedure A_Op64_Ref_Loc(List : TAsmList;Op:TOpCG;Size : TCgSize;const Ref : TReference;const L : TLocation);virtual;abstract;
        procedure A_Op64_Loc_Reg(List : TAsmList;Op:TOpCG;Size : TCgSize;const L : TLocation;Reg64 : TRegister64);virtual;abstract;
        procedure A_Op64_Const_Reg_Reg(List: TAsmList;Op:TOpCG;Size : TCgSize;Value : Int64;RegSrc,RegDst : TRegister64);virtual;
        procedure A_Op64_Reg_Reg_Reg(List: TAsmList;Op:TOpCG;Size : TCgSize;RegSrc1,RegSrc2,RegDst : TRegister64);virtual;
        procedure A_Op64_Const_Reg_Reg_CheckOverflow(List: TAsmList;Op:TOpCG;Size : TCgSize;Value : Int64;RegSrc,RegDst : TRegister64;SetFlags : Boolean;var OVLoc : TLocation);virtual;
        procedure A_Op64_Reg_Reg_Reg_CheckOverflow(List: TAsmList;Op:TOpCG;Size : TCgSize;RegSrc1,RegSrc2,RegDst : TRegister64;SetFlags : Boolean;var OVLoc : TLocation);virtual;
        procedure A_Op64_Reg(List : TAsmList;Op:TOpCG;Size : TCgSize;RegDst : TRegister64);virtual;
        procedure A_Op64_Ref(List : TAsmList;Op:TOpCG;Size : TCgSize;const Ref : TReference);virtual;
        procedure A_Op64_Loc(List : TAsmList;Op:TOpCG;Size : TCgSize;const L : TLocation);virtual;

        procedure A_Op64_Const_SubsetRef(List : TAsmList; Op : TOpCG; Size : TCgSize; A : Int64; const SRef: TSubsetReference);
        procedure A_Op64_Reg_SubsetRef(List : TAsmList; Op : TOpCG; Size : TCgSize; Reg: TRegister64; const SRef: TSubsetReference);
        procedure A_Op64_Ref_SubsetRef(List : TAsmList; Op : TOpCG; Size : TCgSize; const Ref: TReference; const SRef: TSubsetReference);
        procedure A_Op64_SubsetRef_SubsetRef(List : TAsmList; Op : TOpCG; Size : TCgSize; const SSRef,DSRef: TSubsetReference);

        procedure A_Load64_Reg_CGPara(List : TAsmList;Reg64 : TRegister64;const Loc : TCGPara);virtual;abstract;
        procedure A_Load64_Const_CGPara(List : TAsmList;Value : Int64;const Loc : TCGPara);virtual;abstract;
        procedure A_Load64_Ref_CGPara(List : TAsmList;const R : TReference;const Loc : TCGPara);virtual;abstract;
        procedure A_Load64_Loc_CGPara(List : TAsmList;const L : TLocation;const Loc : TCGPara);virtual;abstract;

        procedure A_LoadMM_IntReg64_Reg(List: TAsmList; MMSize: TCgSize; IntReg: TRegister64; MMReg: TRegister); virtual;abstract;
        procedure A_LoadMM_Reg_IntReg64(List: TAsmList; MMSize: TCgSize; MMReg: TRegister; IntReg: TRegister64); virtual;abstract;
        {
             This routine tries to optimize the const_reg opcode, and should be
             called at the start of a_op64_const_reg. It returns the actual opcode
             to emit, and the constant value to emit. If this routine returns
             TRUE, @var(no) instruction should be emitted (.eg : imul reg by 1 )

             @param(op The opcode to emit, returns the opcode which must be emitted)
             @param(a  The constant which should be emitted, returns the constant which must
                    be emitted)
             @param(reg The register to emit the opcode with, returns the register with
                   which the opcode will be emitted)
        }
        function Optimize64_Op_Const_Reg(List: TAsmList; var Op: TOpCG; var A : Int64; var Reg: TRegister64): Boolean;virtual;abstract;


        { override to catch 64bit rangechecks }
        procedure G_RangeCheck64(List: TAsmList; const L:TLocation; FromDef,ToDef: TDef);virtual;abstract;
    end;

    { Creates a tregister64 record from 2 32 Bit registers. }
    function JoinReg64(RegLo,RegHi : TRegister) : TRegister64;
{$endif cpu64bitalu}

    var
       { Main code generator class }
       CG : TCG;
{$ifdef cpu64bitalu}
       { Code generator class for all operations working with 128-Bit operands }
       CG128 : TCG128;
{$else cpu64bitalu}
       { Code generator class for all operations working with 64-Bit operands }
       CG64 : TCG64;
{$endif cpu64bitalu}

    function AsmSym2IndSymFlags(Sym: TAsmSymbol): TIndSymFlags;

    procedure Destroy_CodeGen;

implementation

    uses
       Globals,Systems,FModule,
       Verbose,ParaMgr,SymSym,SymTable,
       TGObj,CUtils,ProcInfo,
       CPUInfo;

{*****************************************************************************
                            basic functionality
******************************************************************************}

    constructor TCG.Create;
      begin
      end;


{*****************************************************************************
                                register allocation
******************************************************************************}


    procedure TCG.Init_Register_Allocators;
      begin

        FillChar(RG,SizeOf(RG),0);
        Add_Reg_Instruction_Hook:=@Add_Reg_Instruction;
        ExecutionWeight:=100;
      end;


    procedure TCG.Done_Register_Allocators;
      begin
        { Safety }
        FillChar(RG,SizeOf(RG),0);
        Add_Reg_Instruction_Hook:=nil;

      end;

    {$ifdef flowgraph}
    procedure TCG.Init_FlowGraph;

    begin
      AktFlowNode:=0;
    end;

    procedure TCG.Done_FlowGraph;

    begin
    end;
    {$endif}

    function TCG.GetIntRegister(List:TAsmList;Size:TCgSize):TRegister;

      begin
        if not Assigned(RG[R_INTREGISTER]) then
          InternalError(200312122);
{$if defined(cpu32bitalu) or defined(cpu64bitalu)}
        Result:=RG[R_INTREGISTER].GetRegister(List,CGSize2SubReg(R_INTREGISTER,Size));
{$endif}
      end;


    function TCG.GetFPURegister(List:TAsmList;Size:TCgSize):TRegister;
      begin
        if not Assigned(RG[R_FPUREGISTER]) then
          InternalError(200312123);
        Result:=RG[R_FPUREGISTER].GetRegister(List,CGSize2SubReg(R_FPUREGISTER,Size));
      end;


    function TCG.GetMMRegister(List:TAsmList;Size:TCgSize):TRegister;
      begin
        if not Assigned(RG[R_MMREGISTER]) then
          InternalError(2003121214);
        Result:=RG[R_MMREGISTER].GetRegister(List,CGSize2SubReg(R_MMREGISTER,Size));
      end;


    function TCG.GetAddressRegister(List:TAsmList):TRegister;
      begin
        if Assigned(RG[R_ADDRESSREGISTER]) then
          Result:=RG[R_ADDRESSREGISTER].GetRegister(List,R_SUBWHOLE)
        else
          begin
            if not Assigned(RG[R_INTREGISTER]) then
              InternalError(200312121);
            Result:=RG[R_INTREGISTER].GetRegister(List,R_SUBWHOLE);
          end;
      end;


    function TCG.GetTempRegister(List: TAsmList): TRegister;
      begin
        Result:=RG[R_TEMPREGISTER].GetRegister(List,R_SUBWHOLE);
      end;





    function TCG.MakeRegSize(List:TAsmList;Reg:TRegister;Size:TCgSize):TRegister;
      var
        SubReg:TSubRegister;
      begin
        SubReg:=CGSize2SubReg(GetRegType(Reg),Size);
        Result:=Reg;
        SetSubReg(Result,SubReg);
        { notify RA }
        if Result<>Reg then
          List.Concat(TAIRegAlloc.Resize(Result));
      end;


    procedure TCG.GetCPURegister(List:TAsmList;R:TRegister);
      begin
        if not Assigned(RG[GetRegType(R)]) then
          InternalError(200312125);
        RG[GetRegType(R)].GetCPURegister(List,R);
      end;


    procedure TCG.UngetCPURegister(List:TAsmList;R:TRegister);
      begin
        if not Assigned(RG[GetRegType(R)]) then
          InternalError(200312126);
        RG[GetRegType(R)].UngetCPURegister(List,R);
      end;


    procedure TCG.AllocCPURegisters(List:TAsmList;RT:TRegisterType;const R:TCPURegisterSet);
      begin
        if Assigned(RG[RT]) then
          RG[RT].AllocCPURegisters(List,R)
        else
          InternalError(200310092);
      end;


    procedure TCG.AllocAllCPURegisters(List:TAsmList);
      begin
        AllocCPURegisters(List,R_INTREGISTER,ParaManager.Get_Volatile_Registers_Int(pocall_default));
        if Uses_Registers(R_ADDRESSREGISTER) then
          AllocCPURegisters(List,R_ADDRESSREGISTER,ParaManager.Get_Volatile_Registers_Address(pocall_default));
{$if not(defined(i386))}
        if Uses_Registers(R_FPUREGISTER) then
          AllocCPURegisters(List,R_FPUREGISTER,ParaManager.Get_Volatile_Registers_FPU(pocall_default));
{$ifdef cpumm}
        if Uses_Registers(R_MMREGISTER) then
          AllocCPURegisters(List,R_MMREGISTER,ParaManager.Get_Volatile_Registers_MM(pocall_default));
{$endif cpumm}
{$endif not(defined(i386))}
      end;


    procedure TCG.DeallocCPURegisters(List:TAsmList;RT:TRegisterType;const R:TCPURegisterSet);
      begin
        if Assigned(RG[RT]) then
          RG[RT].DeallocCPURegisters(List,R)
        else
          InternalError(200310093);
      end;


    procedure TCG.DeallocAllCPURegisters(List:TAsmList);
      begin
        DeallocCPURegisters(List,R_INTREGISTER,ParaManager.Get_Volatile_Registers_Int(pocall_default));
        if Uses_Registers(R_ADDRESSREGISTER) then
          DeallocCPURegisters(List,R_ADDRESSREGISTER,ParaManager.Get_Volatile_Registers_Address(pocall_default));
{$if not(defined(i386))}
        if Uses_Registers(R_FPUREGISTER) then
          DeallocCPURegisters(List,R_FPUREGISTER,ParaManager.Get_Volatile_Registers_FPU(pocall_default));
{$ifdef cpumm}
        if Uses_Registers(R_MMREGISTER) then
          DeallocCPURegisters(List,R_MMREGISTER,ParaManager.Get_Volatile_Registers_MM(pocall_default));
{$endif cpumm}
{$endif not(defined(i386))}
      end;


    function TCG.Uses_Registers(RT:TRegisterType):Boolean;
      begin
        if Assigned(RG[RT]) then
          Result:=RG[RT].Uses_Registers
        else
          Result:=False;
      end;


    procedure TCG.Add_Reg_Instruction(Instr:TAI;R:TRegister);
      var
        RT : TRegisterType;
      begin
        RT:=GetRegType(R);
        { Only add it when a register allocator is configured.
          No IE can be generated, because the VMT is written
          without a valid rg[] }
        if Assigned(RG[RT]) then
          RG[RT].Add_Reg_Instruction(Instr,R,ExecutionWeight);
      end;


    procedure TCG.Add_Move_Instruction(Instr:TAICPU);
      var
        RT : TRegisterType;
      begin
        RT:=GetRegType(Instr.Oper[O_MOV_SOURCE]^.Reg);
        if Assigned(RG[RT]) then
          RG[RT].Add_Move_Instruction(Instr)
        else
          InternalError(200310095);
      end;


    procedure TCG.Set_RegAlloc_Live_Range_Direction(Dir: TRADirection);
      var
        RT : TRegisterType;
      begin
        for RT:=Low(RG) to High(RG) do
          begin
            if Assigned(RG[RT]) then
              RG[RT].LiveRangeDirection:=Dir;
          end;
      end;


    procedure TCG.Do_Register_Allocation(List:TAsmList;HeaderTAI:TAI);
      var
        RT : TRegisterType;
      begin
        for RT:=R_FPUREGISTER to R_SPECIALREGISTER do
          begin
            if Assigned(RG[RT]) then
              RG[RT].Do_Register_Allocation(List,HeaderTAI);
          end;
         { running the other register allocator passes could require addition int/addr. registers
           when spilling so run int/addr register allocation at the end }
         if Assigned(RG[R_INTREGISTER]) then
           RG[R_INTREGISTER].Do_Register_Allocation(List,HeaderTAI);
         if Assigned(RG[R_ADDRESSREGISTER]) then
           RG[R_ADDRESSREGISTER].Do_Register_Allocation(List,HeaderTAI);
      end;


    procedure TCG.Translate_Register(var Reg : TRegister);
      var
        RT: TRegisterType;
      begin
        { Getting here without assigned rg is possible for an "assembler nostackframe"
          function returning x87 float, compiler tries to translate NR_ST which is used for
          result.  }
        RT:=GetRegType(Reg);
        if Assigned(RG[RT]) then
          RG[RT].Translate_Register(Reg);
      end;


    procedure TCG.A_Reg_Alloc(List : TAsmList;R : TRegister);
      begin
         List.Concat(TAIRegAlloc.Alloc(R,nil));
      end;


    procedure TCG.A_Reg_Dealloc(List : TAsmList;R : TRegister);
      begin
        if (R<>NR_NO) then
          List.Concat(TAIRegAlloc.Dealloc(R,nil));
      end;


    procedure TCG.A_Reg_Sync(List : TAsmList;R : TRegister);
      var
        Instr : TAI;
      begin
        Instr:=TAIRegAlloc.Sync(R);
        List.Concat(Instr);
        Add_Reg_Instruction(Instr,R);
      end;


    procedure TCG.A_Label(List : TAsmList;L : TAsmLabel);
      begin
         List.Concat(TAILabel.Create(L));
      end;


    procedure TCG.A_Label_Pascal_Goto_Target(List : TAsmList;L : TAsmLabel);
      begin
        A_Label(List,L);
      end;


{*****************************************************************************
          for better code generation these methods should be overridden
******************************************************************************}

    procedure TCG.A_Load_Reg_CGPara(List : TAsmList;Size : TCgSize;R : TRegister;const CGPara : TCGPara);
      var
         Ref : TReference;
         TmpReg : TRegister;
      begin
         if Assigned(CGPara.Location^.Next) then
           begin
             TG.GetHLTemp(List,CGPara.Def,CGPara.Def.Size,tt_persistent,Ref);
             A_Load_Reg_Ref(List,Size,Size,R,Ref);
             A_Load_Ref_CGPara(List,Size,Ref,CGPara);
             TG.UnGetTemp(List,Ref);
             Exit;
           end;
         ParaManager.AllocCGPara(List,CGPara);
         if CGPara.Location^.ShiftVal<0 then
           begin
             TmpReg:=GetIntRegister(List,CGPara.Location^.Size);
             A_Op_Const_Reg_Reg(List,OP_SHL,CGPara.Location^.Size,-CGPara.Location^.ShiftVal,R,TmpReg);
             R:=TmpReg;
           end;
         case CGPara.Location^.Loc of
            LOC_REGISTER,LOC_CREGISTER:
              A_Load_Reg_Reg(List,Size,CGPara.Location^.Size,R,CGPara.Location^.Register);
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                 Reference_Reset_Base(Ref,CGPara.Location^.Reference.Index,CGPara.Location^.Reference.Offset,CTempPosInvalid,CGPara.Alignment,[]);
                 A_Load_Reg_Ref(List,Size,CGPara.Location^.Size,R,Ref);
              end;
            LOC_MMREGISTER,LOC_CMMREGISTER:
              A_LoadMM_IntReg_Reg(List,Size,CGPara.Location^.Size,R,CGPara.Location^.Register,MMS_MoveScalar);
            LOC_FPUREGISTER,LOC_CFPUREGISTER:
              begin
                TG.GetTemp(List,TCgSize2Size[Size],TCgSize2Size[Size],tt_normal,Ref);
                A_Load_Reg_Ref(List,Size,Size,R,Ref);
                A_LoadFPU_Ref_CGPara(List,CGPara.Location^.Size,Ref,CGPara);
                TG.UnGetTemp(List,Ref);
              end
            else
              InternalError(2002071004);
         end;
      end;


    procedure TCG.A_Load_Const_CGPara(List : TAsmList;Size : TCgSize;A : TCGInt;const CGPara : TCGPara);
      var
         Ref : TReference;
      begin
         CGPara.Check_Simple_Location;
         ParaManager.AllocCGPara(List,CGPara);
         if CGPara.Location^.ShiftVal<0 then
           A:=A shl -CGPara.Location^.ShiftVal;
         case CGPara.Location^.Loc of
            LOC_REGISTER,LOC_CREGISTER:
              A_Load_Const_Reg(List,CGPara.Location^.Size,A,CGPara.Location^.Register);
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                 Reference_Reset_Base(Ref,CGPara.Location^.Reference.Index,CGPara.Location^.Reference.Offset,CTempPosInvalid,CGPara.Alignment,[]);
                 A_Load_Const_Ref(List,CGPara.Location^.Size,A,Ref);
              end
            else
              InternalError(2010053109);
         end;
      end;


    procedure TCG.A_Load_Ref_CGPara(List : TAsmList;Size : TCgSize;const R : TReference;const CGPara : TCGPara);
      var
        TmpRef, Ref: TReference;
        TmpReg: TRegister;
        Location: PCGParaLocation;
        OrgSizeLeft,
        SizeLeft: TCGInt;
        UseSize: TCgSize;
        RegHasValue: Boolean;
      begin
        Location:=CGPara.Location;
        TmpRef:=R;
        SizeLeft:=CGPara.IntSize;
        repeat
          ParaManager.AllocParaLoc(List,Location);
          case Location^.Loc of
            LOC_REGISTER,LOC_CREGISTER:
              begin
                 { Parameter locations are often allocated in multiples of
                   entire registers. If a parameter only occupies a part of
                   such a register (e.g. a 16 bit int on a 32 bit
                   architecture), the size of this parameter can only be
                   determined by looking at the "size" parameter of this
                   method -> if the size parameter is <= sizeof(aint), then
                   we check that there is only one parameter location and
                   then use this "size" to load the value into the parameter
                   location }
                 if (Size<>OS_NO) and
                    (TCgSize2Size[Size]<=SizeOf(AInt)) then
                   begin
                     CGPara.Check_Simple_Location;
                     A_Load_Ref_Reg(List,Size,Location^.Size,TmpRef,Location^.Register);
                     if Location^.ShiftVal<0 then
                       A_Op_Const_Reg(List,OP_SHL,Location^.Size,-Location^.ShiftVal,Location^.Register);
                   end
                 { there's a lot more data left, and the current paraloc's
                   register is entirely filled with part of that data }
                 else if (SizeLeft>SizeOf(AInt)) then
                   begin
                     A_Load_Ref_Reg(List,Location^.Size,Location^.Size,TmpRef,Location^.Register);
                   end
                 { we're at the end of the data, and it can be loaded into
                   the current location's register with a single regular
                   load }
                 else if SizeLeft in [1,2,4,8] then
                   begin
                     A_Load_Ref_Reg(List,Int_CGSize(SizeLeft),Location^.Size,TmpRef,Location^.Register);
                     if Location^.ShiftVal<0 then
                       A_Op_Const_Reg(List,OP_SHL,Location^.Size,-Location^.ShiftVal,Location^.Register);
                   end
                 { we're at the end of the data, and we need multiple loads
                   to get it in the register because it's an irregular size }
                 else
                   begin
                     { should be the last part }
                     if Assigned(Location^.Next) then
                       InternalError(2010052907);
                     { load the value piecewise to get it into the register }
                     OrgSizeLeft:=SizeLeft;
                     RegHasValue:=False;
{$ifdef cpu64bitalu}
                     if SizeLeft>=4 then
                       begin
                         A_Load_Ref_Reg(List,OS_32,Location^.Size,TmpRef,Location^.Register);
                         Dec(SizeLeft,4);
                         if TargetInfo.Endian=endian_big then
                           A_Op_Const_Reg(List,OP_SHL,Location^.Size,SizeLeft*8,Location^.Register);
                         Inc(TmpRef.Offset,4);
                         RegHasValue:=True;
                       end;
{$endif cpu64bitalu}
                     if SizeLeft>=2 then
                       begin
                         TmpReg:=GetIntRegister(List,Location^.Size);
                         A_Load_Ref_Reg(List,OS_16,Location^.Size,TmpRef,TmpReg);
                         Dec(SizeLeft,2);
                         if RegHasValue then
                           begin
                             if TargetInfo.Endian=endian_big then
                               A_Op_Const_Reg(List,OP_SHL,Location^.Size,SizeLeft*8,TmpReg)
                             else
                               A_Op_Const_Reg(List,OP_SHL,Location^.Size,(OrgSizeLeft-(SizeLeft+2))*8,TmpReg);
                             A_Op_Reg_Reg(List,OP_OR,Location^.Size,TmpReg,Location^.Register);
                           end
                         else
                           begin
                             if TargetInfo.Endian=endian_big then
                               A_Op_Const_Reg_Reg(List,OP_SHL,Location^.Size,SizeLeft*8,TmpReg,Location^.Register)
                             else
                               A_Load_Reg_Reg(List,Location^.Size,Location^.Size,TmpReg,Location^.Register);
                           end;
                         Inc(TmpRef.Offset,2);
                         RegHasValue:=True;
                       end;
                     if SizeLeft=1 then
                       begin
                         TmpReg:=GetIntRegister(List,Location^.Size);
                         A_Load_Ref_Reg(List,OS_8,Location^.Size,TmpRef,TmpReg);
                         Dec(SizeLeft,1);
                         if RegHasValue then
                           begin
                             if TargetInfo.Endian=endian_little then
                               A_Op_Const_Reg(List,OP_SHL,Location^.Size,(OrgSizeLeft-(SizeLeft+1))*8,TmpReg);
                             A_Op_Reg_Reg(List,OP_OR,Location^.Size,TmpReg,Location^.Register)
                           end
                         else
                           A_Load_Reg_Reg(List,Location^.Size,Location^.Size,TmpReg,Location^.Register);
                         Inc(TmpRef.Offset);
                       end;
                     if Location^.ShiftVal<0 then
                       A_Op_Const_Reg(List,OP_SHL,Location^.Size,-Location^.ShiftVal,Location^.Register);
                     { the loop will already adjust the offset and sizeleft }
                     Dec(TmpRef.Offset,OrgSizeLeft);
                     SizeLeft:=OrgSizeLeft;
                   end;
              end;
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                Reference_Reset_Base(Ref,Location^.Reference.Index,Location^.Reference.Offset,CTempPosInvalid,NewAlignment(CGPara.Alignment,CGPara.IntSize-SizeLeft),[]);
                A_Load_Ref_CGParaLocRef(List,Size,SizeLeft,TmpRef,Ref,CGPara,Location);
              end;
            LOC_MMREGISTER,LOC_CMMREGISTER:
              begin
                 case Location^.Size of
                   OS_F32,
                   OS_F64,
                   OS_F128:
                     A_LoadMM_Ref_Reg(List,Location^.Size,Location^.Size,TmpRef,Location^.Register,MMS_MoveScalar);
                   OS_M8..OS_M512:
                     A_LoadMM_Ref_Reg(List,Location^.Size,Location^.Size,TmpRef,Location^.Register,nil);
                   else
                     InternalError(2010053101);
                 end;
              end;
            LOC_FPUREGISTER,LOC_CFPUREGISTER:
              begin
                { can be not a float size in case of a record passed in fpu registers }
                { the size comparison is to catch F128 passed in two 64 bit floating point registers }
                if Is_Float_CGSize(Size) and
                   (TCgSize2Size[Location^.Size]>=TCgSize2Size[Size]) then
                  UseSize:=Size
                else
                  UseSize:=Location^.Size;
                A_LoadFPU_Ref_Reg(List,UseSize,Location^.Size,TmpRef,Location^.Register);
              end
            else
              InternalError(2010053111);
          end;
          Inc(TmpRef.Offset,TCgSize2Size[Location^.Size]);
          Dec(SizeLeft,TCgSize2Size[Location^.Size]);
          Location:=Location^.Next;
        until not Assigned(Location);
      end;

    procedure TCG.A_Load_Ref_CGParaLocRef(List: TAsmList; SourceSize: TCgSize; SizeLeft: TCGInt; const Ref, ParaLocRef: TReference; const CGPara: TCGPara; const Location: PCGParaLocation);
      begin
        if Assigned(Location^.Next) then
          InternalError(2010052906);
        if (SourceSize<>OS_NO) and
           (TCgSize2Size[SourceSize]<=SizeOf(AInt)) then
           A_Load_Ref_Ref(List,SourceSize,Location^.Size,Ref,ParaLocRef)
        else
          { use concatcopy, because the parameter can be larger than }
          { what the OS_* constants can handle                       }
          G_ConcatCopy(List,Ref,ParaLocRef,SizeLeft);
       end;


    procedure TCG.A_Load_Loc_CGPara(List : TAsmList;const L:TLocation;const CGPara : TCGPara);
      begin
        case L.Loc of
          LOC_REGISTER,
          LOC_CREGISTER :
            A_Load_Reg_CGPara(List,L.Size,L.Register,CGPara);
          LOC_CONSTANT :
            A_Load_Const_CGPara(List,L.Size,L.Value,CGPara);
          LOC_CREFERENCE,
          LOC_REFERENCE :
            A_Load_Ref_CGPara(List,L.Size,L.Reference,CGPara);
          else
            InternalError(2002032211);
        end;
      end;


    procedure TCG.A_LoadAddr_Ref_CGPara(List : TAsmList;const R : TReference;const CGPara : TCGPara);
      var
         HR : TRegister;
      begin
         CGPara.Check_Simple_Location;
         if CGPara.Location^.Loc in [LOC_CREGISTER,LOC_REGISTER] then
           begin
             ParaManager.AllocParaLoc(List,CGPara.Location);
             A_LoadAddr_Ref_Reg(List,R,CGPara.Location^.Register)
           end
         else
           begin
             HR:=GetAddressRegister(List);
             A_LoadAddr_Ref_Reg(List,R,HR);
             A_Load_Reg_CGPara(List,OS_ADDR,HR,CGPara);
           end;
      end;


    procedure TCG.A_Load_CGParaLoc_Ref(List : TAsmList;const ParaLoc : TCGParaLocation;const Ref : TReference;SizeLeft : TCGInt;Align : LongInt);
      var
        HRef : TReference;
        HReg : TRegister;
        CGSize: TCgSize;
      begin
        case ParaLoc.Loc of
          LOC_REGISTER :
            begin
              HReg:=ParaLoc.Register;
              CGSize:=ParaLoc.Size;
              if (ParaLoc.ShiftVal>0) and
	        not ((TargetInfo.Endian=endian_big) and (SizeLeft in [3,5,6,7])) then
                A_Op_Const_Reg_Reg(List,OP_SHL,OS_INT,ParaLoc.ShiftVal,ParaLoc.Register,ParaLoc.Register)
              { in case the original size was 3 or 5/6/7 bytes, the value was
                shifted to the top of the to 4 resp. 8 byte register on the
                caller side and needs to be stored with those bytes at the
                start of the reference -> don't shift right }
              else if (ParaLoc.ShiftVal<0)
{$ifdef LIMIT_NEG_SHIFTVALUES}
{$ifdef CPU64BITALU}
                      and ((-ParaLoc.ShiftVal) in [56{for byte},48{for two bytes},32{for four bytes}])
{$else}
                      and ((-ParaLoc.ShiftVal) in [24{for byte},16{for two bytes}])
{$endif}
{$endif}
                  then
                begin
                  A_Op_Const_Reg_Reg(List,OP_SHR,OS_INT,-ParaLoc.ShiftVal,ParaLoc.Register,ParaLoc.Register);
                  { convert to a register of 1/2/4 bytes in size, since the
                    original register had to be made larger to be able to hold
                    the shifted value }
                  CGSize:=Int_CGSize(TCgSize2Size[OS_INT]-(-ParaLoc.ShiftVal div 8));
                  if CGSize=OS_NO then
                    CGSize:=OS_INT;
                  HReg:=GetIntRegister(List,CGSize);
                  A_Load_Reg_Reg(List,OS_INT,CGSize,ParaLoc.Register,HReg);
                end;
              { use the exact size to avoid overwriting of adjacent data }
              if TCgSize2Size[CGSize]<=SizeLeft then
                A_Load_Reg_Ref(List,ParaLoc.Size,CGSize,HReg,Ref)
              else
                case SizeLeft of
                  1,2,4,8:
                    A_Load_Reg_Ref(List,ParaLoc.Size,Int_CGSize(SizeLeft),HReg,Ref);
                  3:
                    begin
                      if TargetInfo.Endian=endian_big then
                        begin
                          HRef:=Ref;
                          Inc(HRef.Offset,2);
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_8,HReg,HRef);
                          A_Op_Const_Reg_Reg(List,OP_SHR,OS_INT,8,HReg,HReg);
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_16,HReg,Ref);
                        end
                      else
                        begin
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_16,HReg,Ref);
                          HRef:=Ref;
                          Inc(HRef.Offset,2);
                          A_Op_Const_Reg_Reg(List,OP_SHR,CGSize,16,HReg,HReg);
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_8,HReg,HRef);
                        end
                    end;
                  5:
                    begin
                      if TargetInfo.Endian=endian_big then
                        begin
                          HRef:=Ref;
                          Inc(HRef.Offset,4);
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_8,HReg,HRef);
                          A_Op_Const_Reg_Reg(List,OP_SHR,OS_INT,8,HReg,HReg);
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_32,HReg,Ref);
                        end
                      else
                       begin
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_32,HReg,Ref);
                          HRef:=Ref;
                          Inc(HRef.Offset,4);
                          A_Op_Const_Reg_Reg(List,OP_SHR,CGSize,32,HReg,HReg);
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_8,HReg,HRef);
                        end
                    end;
                  6:
                    begin
                      if TargetInfo.Endian=endian_big then
                        begin
                          HRef:=Ref;
                          Inc(HRef.Offset,4);
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_16,HReg,HRef);
                          A_Op_Const_Reg_Reg(List,OP_SHR,OS_INT,16,HReg,HReg);
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_32,HReg,Ref);
                        end
                      else
                       begin
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_32,HReg,Ref);
                          HRef:=Ref;
                          Inc(HRef.Offset,4);
                          A_Op_Const_Reg_Reg(List,OP_SHR,CGSize,32,HReg,HReg);
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_16,HReg,HRef);
                        end
                    end;
                  7:
                    begin
                      if TargetInfo.Endian=endian_big then
                        begin
                          HRef:=Ref;
                          Inc(HRef.Offset,6);
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_8,HReg,HRef);

                          A_Op_Const_Reg_Reg(List,OP_SHR,OS_INT,8,HReg,HReg);
                          HRef:=Ref;
                          Inc(HRef.Offset,4);
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_16,HReg,HRef);

                          A_Op_Const_Reg_Reg(List,OP_SHR,OS_INT,16,HReg,HReg);
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_32,HReg,Ref);
                        end
                      else
                       begin
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_32,HReg,Ref);

                          HRef:=Ref;
                          Inc(HRef.Offset,4);
                          A_Op_Const_Reg_Reg(List,OP_SHR,CGSize,32,HReg,HReg);
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_16,HReg,HRef);

                          Inc(HRef.Offset,2);
                          A_Op_Const_Reg_Reg(List,OP_SHR,CGSize,16,HReg,HReg);
                          A_Load_Reg_Ref(List,ParaLoc.Size,OS_8,HReg,HRef);
                        end
                    end;
                  else
                    { other sizes not allowed }
                    InternalError(2017080901);
                end;
            end;
          LOC_MMREGISTER :
            begin
              case ParaLoc.Size of
                OS_F32,
                OS_F64,
                OS_F128:
                  A_LoadMM_Reg_Ref(List,ParaLoc.Size,ParaLoc.Size,ParaLoc.Register,Ref,MMS_MoveScalar);
                OS_M8..OS_M512:
                  A_LoadMM_Reg_Ref(List,ParaLoc.Size,ParaLoc.Size,ParaLoc.Register,Ref,nil);
                else
                  InternalError(2010053102);
              end;
            end;
          LOC_FPUREGISTER :
            A_LoadFPU_Reg_Ref(List,ParaLoc.Size,ParaLoc.Size,ParaLoc.Register,Ref);
          LOC_REFERENCE :
            begin
              Reference_Reset_Base(HRef,ParaLoc.Reference.Index,ParaLoc.Reference.Offset,CTempPosInvalid,Align,[]);
              { use concatcopy, because it can also be a float which fails when
                load_ref_ref is used. Don't copy data when the references are equal }
              if not((HRef.Base=Ref.Base) and (HRef.Offset=Ref.Offset)) then
                G_ConcatCopy(List,HRef,Ref,SizeLeft);
            end;
          else
            InternalError(2002081302);
        end;
      end;


    procedure TCG.A_Load_CGParaLoc_AnyReg(List: TAsmList;RegSize: TCgSize;const ParaLoc: TCGParaLocation;Reg: TRegister;Align: LongInt);
      var
        HRef : TReference;
      begin
         case ParaLoc.Loc of
           LOC_REGISTER :
             begin
               if ParaLoc.ShiftVal<0 then
                 A_Op_Const_Reg_Reg(List,OP_SHR,OS_INT,-ParaLoc.ShiftVal,ParaLoc.Register,ParaLoc.Register);
               case GetRegType(Reg) of
                 R_ADDRESSREGISTER,
                 R_INTREGISTER:
                   A_Load_Reg_Reg(List,ParaLoc.Size,RegSize,ParaLoc.Register,Reg);
                 R_MMREGISTER:
                   A_LoadMM_IntReg_Reg(List,ParaLoc.Size,RegSize,ParaLoc.Register,Reg,MMS_MoveScalar);
                 R_FPUREGISTER:
                   A_LoadFPU_IntReg_Reg(List,ParaLoc.Size,RegSize,ParaLoc.Register,Reg);
                 else
                   InternalError(2009112422);
               end;
             end;
           LOC_MMREGISTER :
             begin
               case GetRegType(Reg) of
                 R_ADDRESSREGISTER,
                 R_INTREGISTER:
                   A_LoadMM_Reg_IntReg(List,ParaLoc.Size,RegSize,ParaLoc.Register,Reg,MMS_MoveScalar);
                 R_MMREGISTER:
                   begin
                     case ParaLoc.Size of
                       OS_F32,
                       OS_F64,
                       OS_F128:
                        A_LoadMM_Reg_Reg(List,ParaLoc.Size,RegSize,ParaLoc.Register,Reg,MMS_MoveScalar);
                       OS_M8..OS_M512:
                         A_LoadMM_Reg_Reg(List,ParaLoc.Size,ParaLoc.Size,ParaLoc.Register,Reg,nil);
                       else
                         InternalError(2010053106);
                     end;
                   end;
                 else
                   InternalError(2010053104);
               end;
             end;
           LOC_FPUREGISTER :
             begin
               case GetRegType(Reg) of
                 R_FPUREGISTER:
                   A_LoadFPU_Reg_Reg(List,ParaLoc.Size,RegSize,ParaLoc.Register,Reg);
                 R_INTREGISTER:
                   A_LoadFPU_Reg_IntReg(List,ParaLoc.Size,RegSize,ParaLoc.Register,Reg);
                 else
                   InternalError(2015031401);
                 end;
             end;
           LOC_REFERENCE :
             begin
               Reference_Reset_Base(HRef,ParaLoc.Reference.Index,ParaLoc.Reference.Offset,CTempPosInvalid,Align,[]);
               case GetRegType(Reg) of
                 R_ADDRESSREGISTER,
                 R_INTREGISTER :
                   A_Load_Ref_Reg(List,ParaLoc.Size,RegSize,HRef,Reg);
                 R_FPUREGISTER :
                   A_LoadFPU_Ref_Reg(List,ParaLoc.Size,RegSize,HRef,Reg);
                 R_MMREGISTER :
                   { not paraloc.size, because it may be OS_64 instead of
                     OS_F64 in case the parameter is passed using integer
                     conventions (e.g., on ARM) }
                   A_LoadMM_Ref_Reg(List,RegSize,RegSize,HRef,Reg,MMS_MoveScalar);
                 else
                   InternalError(2004101012);
               end;
             end;
           else
             InternalError(2002081303);
         end;
      end;


{****************************************************************************
                       some generic implementations
****************************************************************************}

    { memory/register loading }

    procedure TCG.A_Load_Reg_Ref_Unaligned(List : TAsmList;FromSize,ToSize : TCgSize;Register : TRegister;const Ref : TReference);
      var
        TmpRef : TReference;
        TmpReg : TRegister;
        I : LongInt;
      begin
        if Ref.Alignment<TCgSize2Size[FromSize] then
          begin
            TmpRef:=Ref;
            { we take care of the alignment now }
            TmpRef.Alignment:=0;
            case FromSize of
              OS_16,OS_S16:
                begin
                  TmpReg:=GetIntRegister(List,OS_16);
                  A_Load_Reg_Reg(List,FromSize,OS_16,Register,TmpReg);
                  if TargetInfo.Endian=endian_big then
                    Inc(TmpRef.Offset);
                  TmpReg:=MakeRegSize(List,TmpReg,OS_8);
                  A_Load_Reg_Ref(List,OS_8,OS_8,TmpReg,TmpRef);
                  TmpReg:=MakeRegSize(List,TmpReg,OS_16);
                  A_Op_Const_Reg(List,OP_SHR,OS_16,8,TmpReg);
                  if TargetInfo.Endian=endian_big then
                    Dec(TmpRef.Offset)
                  else
                    Inc(TmpRef.Offset);
                  TmpReg:=MakeRegSize(List,TmpReg,OS_8);
                  A_Load_Reg_Ref(List,OS_8,OS_8,TmpReg,TmpRef);
                end;
              OS_32,OS_S32:
                begin
                  { could add an optimised case for ref.alignment=2 }
                  TmpReg:=GetIntRegister(List,OS_32);
                  A_Load_Reg_Reg(List,FromSize,OS_32,Register,TmpReg);
                  if TargetInfo.Endian=endian_big then
                    Inc(TmpRef.Offset,3);
                  TmpReg:=MakeRegSize(List,TmpReg,OS_8);
                  A_Load_Reg_Ref(List,OS_8,OS_8,TmpReg,TmpRef);
                  TmpReg:=MakeRegSize(List,TmpReg,OS_32);
                  for I:=1 to 3 do
                    begin
                      A_Op_Const_Reg(List,OP_SHR,OS_32,8,TmpReg);
                      if TargetInfo.Endian=endian_big then
                        Dec(TmpRef.Offset)
                      else
                        Inc(TmpRef.Offset);
                      TmpReg:=MakeRegSize(List,TmpReg,OS_8);
                      A_Load_Reg_Ref(List,OS_8,OS_8,TmpReg,TmpRef);
                      TmpReg:=MakeRegSize(List,TmpReg,OS_32);
                    end;
                end
              else
                A_Load_Reg_Ref(List,FromSize,ToSize,Register,TmpRef);
            end;
          end
        else
          A_Load_Reg_Ref(List,FromSize,ToSize,Register,Ref);
      end;


    procedure TCG.A_Load_Ref_Reg_Unaligned(List : TAsmList;FromSize,ToSize : TCgSize;const Ref : TReference;Register : TRegister);
      var
        TmpRef : TReference;
        TmpReg,
        TmpReg2 : TRegister;
        I : LongInt;
        HiSize : TCgSize;
      begin
        if Ref.Alignment in [1,2] then
          begin
            TmpRef:=Ref;
            { we take care of the alignment now }
            TmpRef.Alignment:=0;
            case FromSize of
              OS_16,OS_S16:
                if Ref.Alignment=2 then
                  A_Load_Ref_Reg(List,FromSize,ToSize,TmpRef,Register)
                else
                  begin
                    if FromSize=OS_16 then
                      HiSize:=OS_8
                    else
                      HiSize:=OS_S8;
                    { first load in tmpreg, because the target register }
                    { may be used in ref as well                        }
                    if TargetInfo.Endian=endian_little then
                      Inc(TmpRef.Offset);
                    TmpReg:=GetIntRegister(List,OS_8);
                    A_Load_Ref_Reg(List,HiSize,HiSize,TmpRef,TmpReg);
                    TmpReg:=MakeRegSize(List,TmpReg,FromSize);
                    A_Op_Const_Reg(List,OP_SHL,FromSize,8,TmpReg);
                    if TargetInfo.Endian=endian_little then
                      Dec(TmpRef.Offset)
                    else
                      Inc(TmpRef.Offset);
                    TmpReg2:=MakeRegSize(List,Register,OS_16);
                    A_Load_Ref_Reg(List,OS_8,OS_16,TmpRef,TmpReg2);
                    A_Op_Reg_Reg(List,OP_OR,OS_16,TmpReg,TmpReg2);
                    A_Load_Reg_Reg(List,FromSize,ToSize,TmpReg2,Register);
                  end;
              OS_32,OS_S32:
                if Ref.Alignment=2 then
                  begin
                    if TargetInfo.Endian=endian_little then
                      Inc(TmpRef.Offset,2);
                    TmpReg:=GetIntRegister(List,OS_32);
                    A_Load_Ref_Reg(List,OS_16,OS_32,TmpRef,TmpReg);
                    A_Op_Const_Reg(List,OP_SHL,OS_32,16,TmpReg);
                    if TargetInfo.Endian=endian_little then
                      Dec(TmpRef.Offset,2)
                    else
                      Inc(TmpRef.Offset,2);
                    TmpReg2:=MakeRegSize(List,Register,OS_32);
                    A_Load_Ref_Reg(List,OS_16,OS_32,TmpRef,TmpReg2);
                    A_Op_Reg_Reg(List,OP_OR,OS_32,TmpReg,TmpReg2);
                    A_Load_Reg_Reg(List,FromSize,ToSize,TmpReg2,Register);
                  end
                else
                  begin
                    if TargetInfo.Endian=endian_little then
                      Inc(TmpRef.Offset,3);
                    TmpReg:=GetIntRegister(List,OS_32);
                    A_Load_Ref_Reg(List,OS_8,OS_32,TmpRef,TmpReg);
                    TmpReg2:=GetIntRegister(List,OS_32);
                    for I:=1 to 3 do
                      begin
                        A_Op_Const_Reg(List,OP_SHL,OS_32,8,TmpReg);
                        if TargetInfo.Endian=endian_little then
                          Dec(TmpRef.Offset)
                        else
                          Inc(TmpRef.Offset);
                        A_Load_Ref_Reg(List,OS_8,OS_32,TmpRef,TmpReg2);
                        A_Op_Reg_Reg(List,OP_OR,OS_32,TmpReg2,TmpReg);
                      end;
                    A_Load_Reg_Reg(List,FromSize,ToSize,TmpReg,Register);
                  end
              else
                A_Load_Ref_Reg(List,FromSize,ToSize,TmpRef,Register);
            end;
          end
        else
          A_Load_Ref_Reg(List,FromSize,ToSize,Ref,Register);
      end;


    procedure TCG.A_Load_Ref_Ref(List : TAsmList;FromSize,ToSize : TCgSize;const SRef : TReference;const DRef : TReference);
      var
        TmpReg: TRegister;
      begin
        { verify if we have the same reference }
        if References_Equal(SRef,DRef) then
          Exit;
        TmpReg:=GetIntRegister(List,ToSize);
        A_Load_Ref_Reg(List,FromSize,ToSize,SRef,TmpReg);
        A_Load_Reg_Ref(List,ToSize,ToSize,TmpReg,DRef);
      end;


    procedure TCG.A_Load_Const_Ref(List : TAsmList;Size : TCgSize;A : TCGInt;const Ref : TReference);
      var
        TmpReg: TRegister;
      begin
        TmpReg:=GetIntRegister(List,Size);
        A_Load_Const_Reg(List,Size,A,TmpReg);
        A_Load_Reg_Ref(List,Size,Size,TmpReg,Ref);
      end;


    procedure TCG.A_Load_Const_Loc(List : TAsmList;A : TCGInt;const Loc: TLocation);
      begin
        case Loc.Loc of
          LOC_REFERENCE,LOC_CREFERENCE:
            A_Load_Const_Ref(List,Loc.Size,A,Loc.Reference);
          LOC_REGISTER,LOC_CREGISTER:
            A_Load_Const_Reg(List,Loc.Size,A,Loc.Register);
          else
            InternalError(200203272);
        end;
      end;


    procedure TCG.A_Load_Reg_Loc(List : TAsmList;FromSize : TCgSize;Reg : TRegister;const Loc: TLocation);
      begin
        case Loc.Loc of
          LOC_REFERENCE,LOC_CREFERENCE:
            A_Load_Reg_Ref(List,FromSize,Loc.Size,Reg,Loc.Reference);
          LOC_REGISTER,LOC_CREGISTER:
            A_Load_Reg_Reg(List,FromSize,Loc.Size,Reg,Loc.Register);
          LOC_MMREGISTER,LOC_CMMREGISTER:
            A_LoadMM_IntReg_Reg(List,FromSize,Loc.Size,Reg,Loc.Register,MMS_MoveScalar);
          else
            InternalError(200203271);
        end;
      end;


    procedure TCG.A_Load_Loc_Reg(List : TAsmList; ToSize: TCgSize; const Loc: TLocation; Reg : TRegister);
      begin
        case Loc.Loc of
          LOC_REFERENCE,LOC_CREFERENCE:
            A_Load_Ref_Reg(List,Loc.Size,ToSize,Loc.Reference,Reg);
          LOC_REGISTER,LOC_CREGISTER:
            A_Load_Reg_Reg(List,Loc.Size,ToSize,Loc.Register,Reg);
          LOC_CONSTANT:
            A_Load_Const_Reg(List,ToSize,Loc.Value,Reg);
          LOC_MMREGISTER,LOC_CMMREGISTER:
            A_LoadMM_Reg_IntReg(List,Loc.Size,ToSize,Loc.Register,Reg,MMS_MoveScalar);
          else
            InternalError(200109092);
        end;
      end;


    procedure TCG.A_Load_Loc_Ref(List : TAsmList;ToSize: TCgSize; const Loc: TLocation; const Ref : TReference);
      begin
        case Loc.Loc of
          LOC_REFERENCE,LOC_CREFERENCE:
            A_Load_Ref_Ref(List,Loc.Size,ToSize,Loc.Reference,Ref);
          LOC_REGISTER,LOC_CREGISTER:
            A_Load_Reg_Ref(List,Loc.Size,ToSize,Loc.Register,Ref);
          LOC_CONSTANT:
            A_Load_Const_Ref(List,ToSize,Loc.Value,Ref);
          else
            InternalError(200109302);
        end;
      end;


    procedure TCG.Optimize_Op_Const(Size: TCgSize; var Op: TOpCG; var A : TCGInt);
      var
        PowerVal : LongInt;
        SignExtA, ZeroExtA: TCGInt;
      begin
        case Size of
          OS_64,OS_S64:
            begin
              SignExtA:=Int64(A);
              ZeroExtA:=Int64(A);
            end;
          OS_32,OS_S32:
            begin
              SignExtA:=LongInt(A);
              ZeroExtA:=DWord(A);
            end;
          OS_16,OS_S16:
            begin
              SignExtA:=SmallInt(A);
              ZeroExtA:=Word(A);
            end;
          OS_8,OS_S8:
            begin
              SignExtA:=ShortInt(A);
              ZeroExtA:=Byte(A);
            end
          else
            begin
              { Should we internalerror() here instead? }
              SignExtA:=A;
              ZeroExtA:=A;
            end;
        end;
        case Op of
          OP_OR :
            begin
              { or with zero returns same result }
              if A = 0 then
                Op:=OP_NONE
              else
              { or with max returns max }
                if SignExtA = -1 then
                  Op:=OP_MOVE;
            end;
          OP_AND :
            begin
              { and with max returns same result }
              if (SignExtA = -1) then
                Op:=OP_NONE
              else
              { and with 0 returns 0 }
                if A=0 then
                  Op:=OP_MOVE;
            end;
          OP_XOR :
            begin
              { xor with zero returns same result }
              if A = 0 then
                Op:=OP_NONE;
            end;
          OP_DIV :
            begin
              { division by 1 returns result }
              if A = 1 then
                Op:=OP_NONE
              else if IsPowerOf2(Int64(ZeroExtA), PowerVal) and not(cs_check_overflow in CurrentSettings.LocalSwitches) then
                begin
                  A := PowerVal;
                  Op:= OP_SHR;
                end;
            end;
          OP_IDIV:
            begin
              if A = 1 then
                Op:=OP_NONE;
            end;
         OP_MUL,OP_IMUL:
            begin
               if A = 1 then
                 Op:=OP_NONE
               else
                 if A=0 then
                   Op:=OP_MOVE
               else if IsPowerOf2(Int64(ZeroExtA), PowerVal) and not(cs_check_overflow in CurrentSettings.LocalSwitches)  then
                 begin
                   A := PowerVal;
                   Op:= OP_SHL;
                 end;
            end;
        OP_ADD,OP_SUB:
            begin
               if A = 0 then
                 Op:=OP_NONE;
            end;
        OP_SAR,OP_SHL,OP_SHR:
           begin
             if A = 0 then
               Op:=OP_NONE;
           end;
        OP_ROL,OP_ROR:
          begin
            case Size of
              OS_64,OS_S64:
                A:=A and 63;
              OS_32,OS_S32:
                A:=A and 31;
              OS_16,OS_S16:
                A:=A and 15;
              OS_8,OS_S8:
                A:=A and 7;
              else
                InternalError(2019050521);
            end;
            if A = 0 then
              Op:=OP_NONE;
          end;
        else
          ;
        end;
      end;


    procedure TCG.A_LoadFPU_Loc_Reg(List: TAsmList; ToSize: TCgSize; const Loc: TLocation; const Reg: TRegister);
      begin
        case Loc.Loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            A_LoadFPU_Ref_Reg(List,Loc.Size,ToSize,Loc.Reference,Reg);
          LOC_FPUREGISTER, LOC_CFPUREGISTER:
            A_LoadFPU_Reg_Reg(List,Loc.Size,ToSize,Loc.Register,Reg);
          else
            InternalError(200203301);
        end;
      end;


    procedure TCG.A_LoadFPU_Reg_Loc(List: TAsmList; FromSize: TCgSize; const Reg: TRegister; const Loc: TLocation);
      begin
        case Loc.Loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            A_LoadFPU_Reg_Ref(List,FromSize,Loc.Size,Reg,Loc.Reference);
          LOC_FPUREGISTER, LOC_CFPUREGISTER:
            A_LoadFPU_Reg_Reg(List,FromSize,Loc.Size,Reg,Loc.Register);
          else
            InternalError(48991);
         end;
      end;


    procedure TCG.A_LoadFPU_Ref_Ref(List: TAsmList; FromSize, ToSize: TCgSize; const Ref1,Ref2: TReference);
      var
        Reg: TRegister;
        RegSize: TCgSize;
      begin
        if (FromSize>=ToSize) then
          RegSize:=FromSize
        else
          RegSize:=ToSize;
        Reg:=GetFPURegister(List,RegSize);
        A_LoadFPU_Ref_Reg(List,FromSize,RegSize,Ref1,Reg);
        A_LoadFPU_Reg_Ref(List,RegSize,ToSize,Reg,Ref2);
      end;


    procedure TCG.A_LoadFPU_Reg_CGPara(List : TAsmList;Size : TCgSize;const R : TRegister;const CGPara : TCGPara);
      var
         Ref : TReference;
      begin
        ParaManager.AllocCGPara(List,CGPara);
         case CGPara.Location^.Loc of
            LOC_FPUREGISTER,LOC_CFPUREGISTER:
              begin
                CGPara.Check_Simple_Location;
                A_LoadFPU_Reg_Reg(List,Size,Size,R,CGPara.Location^.Register);
              end;
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                CGPara.Check_Simple_Location;
                Reference_Reset_Base(Ref,CGPara.Location^.Reference.Index,CGPara.Location^.Reference.Offset,CTempPosInvalid,CGPara.Alignment,[]);
                A_LoadFPU_Reg_Ref(List,Size,Size,R,Ref);
              end;
            LOC_REGISTER,LOC_CREGISTER:
              begin
                { paramfpu_ref does the check_simple_location check here if necessary }
                TG.GetTemp(List,TCgSize2Size[Size],TCgSize2Size[Size],tt_normal,Ref);
                A_LoadFPU_Reg_Ref(List,Size,Size,R,Ref);
                A_LoadFPU_Ref_CGPara(List,Size,Ref,CGPara);
                TG.UnGetTemp(List,Ref);
              end;
            else
              InternalError(2010053112);
         end;
      end;


    procedure TCG.A_LoadFPU_Ref_CGPara(List : TAsmList;Size : TCgSize;const Ref : TReference;const CGPara : TCGPara);
      var
        SrcRef,
        HRef : TReference;
        SrcSize,
        HSize: TCgSize;
        ParaLoc: PCGParaLocation;
        SizeLeft: TCGInt;
      begin
        SizeLeft:=CGPara.IntSize;
        ParaLoc:=CGPara.Location;
        ParaManager.AllocCGPara(List,CGPara);
        SrcRef:=Ref;
        repeat
          case ParaLoc^.Loc of
            LOC_FPUREGISTER,LOC_CFPUREGISTER:
              begin
                { destination: can be something different in case of a record passed in fpu registers }
                if Is_Float_CGSize(ParaLoc^.Size) then
                  HSize:=ParaLoc^.Size
                else
                  HSize:=Int_Float_CGSize(TCgSize2Size[ParaLoc^.Size]);
                { source: the size comparison is to catch F128 passed in two 64 bit floating point registers }
                if Is_Float_CGSize(Size) and
                   (TCgSize2Size[Size]<=TCgSize2Size[ParaLoc^.Size]) then
                  SrcSize:=Size
                else
                  SrcSize:=HSize;
                A_LoadFPU_Ref_Reg(List,SrcSize,HSize,SrcRef,ParaLoc^.Register);
              end;
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                if Assigned(ParaLoc^.Next) then
                  InternalError(2020050101);
                Reference_Reset_Base(HRef,ParaLoc^.Reference.Index,ParaLoc^.Reference.Offset,CTempPosInvalid,NewAlignment(CGPara.Alignment,CGPara.IntSize-SizeLeft),[]);
                { concatcopy should choose the best way to copy the data }
                G_ConcatCopy(List,SrcRef,HRef,SizeLeft);
              end;
            LOC_REGISTER,LOC_CREGISTER:
              begin
                { force integer size }
                HSize:=Int_CGSize(TCgSize2Size[ParaLoc^.Size]);
  {$ifndef cpu64bitalu}
                if (HSize in [OS_S64,OS_64]) then
                  begin
                    { if this is not a simple location, we'll have to add support to cg64 to load parts of a cgpara }
                    CGPara.Check_Simple_Location;
                    CG64.A_Load64_Ref_CGPara(List,SrcRef,CGPara)
                  end
                else
  {$endif not cpu64bitalu}
                  begin
                    A_Load_Ref_Reg(List,HSize,HSize,SrcRef,ParaLoc^.Register)
                  end;
              end
            else
              InternalError(200402201);
          end;
          Inc(SrcRef.Offset,TCgSize2Size[ParaLoc^.Size]);
          Dec(SizeLeft,TCgSize2Size[ParaLoc^.Size]);
          ParaLoc:=ParaLoc^.Next;
        until not Assigned(ParaLoc);
      end;


    procedure TCG.A_LoadFPU_IntReg_Reg(List : TAsmList; FromSize,ToSize : TCgSize; IntReg,FPUReg : TRegister);
      var
        TmpRef: TReference;
      begin
        if not(TCgSize2Size[FromSize] in [4,8]) or
           not(TCgSize2Size[ToSize] in [4,8]) or
           (TCgSize2Size[FromSize]<>TCgSize2Size[ToSize]) then
          InternalError(2017070902);
        TG.GetTemp(List,TCgSize2Size[FromSize],TCgSize2Size[FromSize],tt_normal,TmpRef);
        A_Load_Reg_Ref(List,FromSize,FromSize,IntReg,TmpRef);
        A_LoadFPU_Ref_Reg(List,ToSize,ToSize,TmpRef,FPUReg);
        TG.UnGetTemp(List,TmpRef);
      end;


    procedure TCG.A_LoadFPU_Reg_IntReg(List : TAsmList; FromSize,ToSize : TCgSize; FPUReg,IntReg : TRegister);
      var
        TmpRef: TReference;
      begin
        if not(TCgSize2Size[FromSize] in [4,8]) or
           not(TCgSize2Size[ToSize] in [4,8]) or
           (TCgSize2Size[FromSize]<>TCgSize2Size[ToSize]) then
          InternalError(2020091201);
        TG.GetTemp(List,TCgSize2Size[FromSize],TCgSize2Size[FromSize],tt_normal,TmpRef);
        A_LoadFPU_Reg_Ref(List,FromSize,FromSize,FPUReg,TmpRef);
        A_Load_Ref_Reg(List,ToSize,ToSize,TmpRef,IntReg);
        TG.UnGetTemp(List,TmpRef);
      end;


    procedure TCG.A_Op_Const_Ref(List : TAsmList; Op: TOpCG; Size: TCgSize; A: TCGInt; const Ref: TReference);
      var
        TmpReg : TRegister;
        TmpRef : TReference;
      begin
        if Assigned(Ref.Symbol) then
          begin
            TmpReg:=GetAddressRegister(List);
            A_LoadAddr_Ref_Reg(List,Ref,TmpReg);
            Reference_Reset_Base(TmpRef,TmpReg,0,Ref.TempPos,Ref.Alignment,[]);
          end
        else
          TmpRef:=Ref;
        TmpReg:=GetIntRegister(List,Size);
        A_Load_Ref_Reg(List,Size,Size,TmpRef,TmpReg);
        A_Op_Const_Reg(List,Op,Size,A,TmpReg);
        A_Load_Reg_Ref(List,Size,Size,TmpReg,TmpRef);
      end;


    procedure TCG.A_Op_Const_Loc(List : TAsmList; Op: TOpCG; A: TCGInt; const Loc: TLocation);
      begin
        case Loc.Loc of
          LOC_REGISTER, LOC_CREGISTER:
            A_Op_Const_Reg(List,Op,Loc.Size,A,Loc.Register);
          LOC_REFERENCE, LOC_CREFERENCE:
            A_Op_Const_Ref(List,Op,Loc.Size,A,Loc.Reference);
          else
            InternalError(200109061);
        end;
      end;


    procedure TCG.A_Op_Reg_Ref(List : TAsmList; Op: TOpCG; Size: TCgSize;Reg: TRegister;  const Ref: TReference);
      var
        TmpReg : TRegister;
        TmpRef : TReference;
      begin
        if Assigned(Ref.Symbol) then
          begin
            TmpReg:=GetAddressRegister(List);
            A_LoadAddr_Ref_Reg(List,Ref,TmpReg);
            Reference_Reset_Base(TmpRef,TmpReg,0,Ref.TempPos,Ref.Alignment,[]);
          end
        else
          TmpRef:=Ref;
        if Op in [OP_NEG,OP_NOT] then
          begin
            TmpReg:=GetIntRegister(List,Size);
            A_Op_Reg_Reg(List,Op,Size,Reg,TmpReg);
            A_Load_Reg_Ref(List,Size,Size,TmpReg,TmpRef);
          end
        else
          begin
            TmpReg:=GetIntRegister(List,Size);
            A_Load_Ref_Reg(List,Size,Size,TmpRef,TmpReg);
            A_Op_Reg_Reg(List,Op,Size,Reg,TmpReg);
            A_Load_Reg_Ref(List,Size,Size,TmpReg,TmpRef);
          end;
      end;


    procedure TCG.A_Op_Ref_Reg(List : TAsmList; Op: TOpCG; Size: TCgSize; const Ref: TReference; Reg: TRegister);

      var
        TmpReg: TRegister;

      begin
        case Op of
          OP_NOT,OP_NEG:
            { handle it as "load ref,reg; op reg" }
            begin
              A_Load_Ref_Reg(List,Size,Size,Ref,Reg);
              A_Op_Reg_Reg(List,Op,Size,Reg,Reg);
            end;
          else
            begin
              TmpReg:=GetIntRegister(List,Size);
              A_Load_Ref_Reg(List,Size,Size,Ref,TmpReg);
              A_Op_Reg_Reg(List,Op,Size,TmpReg,Reg);
            end;
        end;
      end;


    procedure TCG.A_Op_Reg_Loc(List : TAsmList; Op: TOpCG; Reg: TRegister; const Loc: TLocation);

      begin
        case Loc.Loc of
          LOC_REGISTER, LOC_CREGISTER:
            A_Op_Reg_Reg(List,Op,Loc.Size,Reg,Loc.Register);
          LOC_REFERENCE, LOC_CREFERENCE:
            A_Op_Reg_Ref(List,Op,Loc.Size,Reg,Loc.Reference);
          else
            InternalError(2001090602);
        end;
      end;


    procedure TCG.A_Op_Loc_Reg(List : TAsmList; Op : TOpCG; Size: TCgSize; const Loc : TLocation; Reg : TRegister);

      begin
        case Loc.Loc of
          LOC_REGISTER, LOC_CREGISTER:
            A_Op_Reg_Reg(List,Op,Size,Loc.Register,Reg);
          LOC_REFERENCE, LOC_CREFERENCE:
            A_Op_Ref_Reg(List,Op,Size,Loc.Reference,Reg);
          LOC_CONSTANT:
            A_Op_Const_Reg(List,Op,Size,Loc.Value,Reg);
          else
            InternalError(2018031101);
        end;
      end;


    procedure TCG.A_Op_Ref_Loc(List : TAsmList; Op: TOpCG; const Ref: TReference; const Loc: TLocation);

      var
        TmpReg: TRegister;

      begin
        case Loc.Loc of
          LOC_REGISTER,LOC_CREGISTER:
            A_Op_Ref_Reg(List,Op,Loc.Size,Ref,Loc.Register);
          LOC_REFERENCE,LOC_CREFERENCE:
            begin
              TmpReg:=GetIntRegister(List,Loc.Size);
              A_Load_Ref_Reg(List,Loc.Size,Loc.Size,Ref,TmpReg);
              A_Op_Reg_Ref(List,Op,Loc.Size,TmpReg,Loc.Reference);
            end;
          else
            InternalError(2001090603);
        end;
      end;


    procedure TCG.A_Op_Const_Reg_Reg(List:TAsmList;Op:TOpCG;Size:TCgSize;
                                     A:TCGInt;Src,Dst:TRegister);
    begin
      Optimize_Op_Const(Size, Op, A);
      case Op of
        OP_NONE:
          begin
            if Src <> Dst then
              A_Load_Reg_Reg(List, Size, Size, Src, Dst);
            Exit;
          end;
        OP_MOVE:
          begin
            A_Load_Const_Reg(List, Size, A, Dst);
            Exit;
          end;


        else
          ;
      end;
      A_Load_Reg_Reg(List,Size,Size,Src,Dst);
      A_Op_Const_Reg(List,Op,Size,A,Dst);
    end;

    procedure TCG.A_Op_Reg_Reg_Reg(List: TAsmList; Op: TOpCG;
        Size: TCgSize; Src1, Src2, Dst: TRegister);
      var
        TmpReg: TRegister;
      begin
        if (Dst<>Src1) then
          begin
            A_Load_Reg_Reg(List,Size,Size,Src2,Dst);
            A_Op_Reg_Reg(List,Op,Size,Src1,Dst);
          end
        else
          begin
            { can we do a direct operation on the target register ? }
            if Op in [OP_ADD,OP_MUL,OP_AND,OP_MOVE,OP_XOR,OP_IMUL,OP_OR] then
              A_Op_Reg_Reg(List,Op,Size,Src2,Dst)
            else
              begin
                TmpReg:=GetIntRegister(List,Size);
                A_Load_Reg_Reg(List,Size,Size,Src2,TmpReg);
                A_Op_Reg_Reg(List,Op,Size,Src1,TmpReg);
                A_Load_Reg_Reg(List,Size,Size,TmpReg,Dst);
              end;
          end;
      end;


    procedure TCG.A_Op_Const_Reg_Reg_CheckOverflow(List: TAsmList; Op: TOpCG; Size: TCgSize; A: TCGInt; Src, Dst: TRegister;SetFlags : Boolean;var OVLoc : TLocation);
      begin
        A_Op_Const_Reg_Reg(List,Op,Size,A,Src,Dst);
        OVLoc.Loc:=LOC_VOID;
      end;


    procedure TCG.A_Op_Reg_Reg_Reg_CheckOverflow(List: TAsmList; Op: TOpCG; Size: TCgSize; Src1, Src2, Dst: TRegister;SetFlags : Boolean;var OVLoc : TLocation);
      begin
        A_Op_Reg_Reg_Reg(List,Op,Size,Src1,Src2,Dst);
        OVLoc.Loc:=LOC_VOID;
      end;


    procedure TCG.A_Op_Reg(List: TAsmList; Op: TOpCG; Size: TCgSize; Reg: TRegister);
      begin
        if not (Op in [OP_NOT,OP_NEG]) then
          InternalError(2020050701);
        A_Op_Reg_Reg(List,Op,Size,Reg,Reg);
      end;


    procedure TCG.A_Op_Ref(List: TAsmList; Op: TOpCG; Size: TCgSize; const Ref: TReference);
      var
        TmpReg: TRegister;
        TmpRef: TReference;
      begin
        if not (Op in [OP_NOT,OP_NEG]) then
          InternalError(2020050710);
        if Assigned(Ref.Symbol) then
          begin
            TmpReg:=GetAddressRegister(List);
            A_LoadAddr_Ref_Reg(List,Ref,TmpReg);
            Reference_Reset_Base(TmpRef,TmpReg,0,Ref.TempPos,Ref.Alignment,[]);
          end
        else
          TmpRef:=Ref;
        TmpReg:=GetIntRegister(List,Size);
        A_Load_Ref_Reg(List,Size,Size,TmpRef,TmpReg);
        A_Op_Reg_Reg(List,Op,Size,TmpReg,TmpReg);
        A_Load_Reg_Ref(List,Size,Size,TmpReg,TmpRef);
      end;


    procedure TCG.A_Op_Loc(List: TAsmList; Op: TOpCG; const Loc: TLocation);
      begin
        case Loc.Loc of
          LOC_REGISTER, LOC_CREGISTER:
            A_Op_Reg(List,Op,Loc.Size,Loc.Register);
          LOC_REFERENCE, LOC_CREFERENCE:
            A_Op_Ref(List,Op,Loc.Size,Loc.Reference);
          else
            InternalError(2020050702);
        end;
      end;


    procedure TCG.A_Cmp_Const_Reg_Label(List: TAsmList; Size: TCgSize;
      CmpOp: TOpCmp; A: TCGInt; Reg: TRegister; L: TAsmLabel);
      var
        TmpReg: TRegister;
      begin
        TmpReg:=GetIntRegister(List,Size);
        A_Load_Const_Reg(List,Size,A,TmpReg);
        A_Cmp_Reg_Reg_Label(List,Size,CmpOp,TmpReg,Reg,L);
      end;


    procedure TCG.A_Cmp_Const_Ref_Label(List : TAsmList;Size : TCgSize;CmpOp : TOpCmp;A : TCGInt;const Ref : TReference;
      L : TAsmLabel);
      var
        TmpReg: TRegister;
      begin
        TmpReg:=GetIntRegister(List,Size);
        A_Load_Ref_Reg(List,Size,Size,Ref,TmpReg);
        A_Cmp_Const_Reg_Label(List,Size,CmpOp,A,TmpReg,L);
      end;


    procedure TCG.A_Cmp_Const_Loc_Label(List : TAsmList;Size : TCgSize;CmpOp : TOpCmp;A : TCGInt;const Loc : TLocation;
      L : TAsmLabel);
      begin
        case Loc.Loc of
          LOC_REGISTER,LOC_CREGISTER:
            A_Cmp_Const_Reg_Label(List,Size,CmpOp,A,Loc.Register,L);
          LOC_REFERENCE,LOC_CREFERENCE:
            A_Cmp_Const_Ref_Label(List,Size,CmpOp,A,Loc.Reference,L);
          else
            InternalError(2001090604);
        end;
      end;


    procedure TCG.A_Cmp_Ref_Reg_Label(List : TAsmList;Size : TCgSize;CmpOp : TOpCmp; const Ref: TReference; Reg : TRegister; L : TAsmLabel);
      var
        TmpReg: TRegister;
      begin
        TmpReg:=GetIntRegister(List,Size);
        A_Load_Ref_Reg(List,Size,Size,Ref,TmpReg);
        A_Cmp_Reg_Reg_Label(List,Size,CmpOp,TmpReg,Reg,L);
      end;


    procedure TCG.A_Cmp_Reg_Ref_Label(List : TAsmList;Size : TCgSize;CmpOp : TOpCmp; Reg : TRegister; const Ref: TReference; L : TAsmLabel);
      var
        TmpReg: TRegister;
      begin
        TmpReg:=GetIntRegister(List,Size);
        A_Load_Ref_Reg(List,Size,Size,Ref,TmpReg);
        A_Cmp_Reg_Reg_Label(List,Size,CmpOp,Reg,TmpReg,L);
      end;


    procedure TCG.A_Cmp_Reg_Loc_Label(List : TAsmList;Size : TCgSize;CmpOp : TOpCmp; Reg: TRegister; const Loc: TLocation; L : TAsmLabel);
      begin
        A_Cmp_Loc_Reg_Label(List,Size,Swap_OpCmp(CmpOp),Loc,Reg,L);
      end;


    procedure TCG.A_Cmp_Loc_Reg_Label(List : TAsmList;Size : TCgSize;CmpOp : TOpCmp; const Loc: TLocation; Reg : TRegister; L : TAsmLabel);
      begin
        case Loc.Loc of
          LOC_REGISTER,
          LOC_CREGISTER:
            A_Cmp_Reg_Reg_Label(List,Size,CmpOp,Loc.Register,Reg,L);
          LOC_REFERENCE,
          LOC_CREFERENCE :
            A_Cmp_Ref_Reg_Label(List,Size,CmpOp,Loc.Reference,Reg,L);
          LOC_CONSTANT:
            A_Cmp_Const_Reg_Label(List,Size,CmpOp,Loc.Value,Reg,L);
          else
            InternalError(200203231);
        end;
      end;


    procedure TCG.A_Cmp_Ref_Loc_Label(List : TAsmList;Size : TCgSize;CmpOp : TOpCmp;const Ref: TReference;const Loc : TLocation;
      L : TAsmLabel);
      var
        TmpReg: TRegister;
      begin
        case Loc.Loc of
          LOC_REGISTER,LOC_CREGISTER:
            A_Cmp_Ref_Reg_Label(List,Size,CmpOp,Ref,Loc.Register,L);
          LOC_REFERENCE,LOC_CREFERENCE:
            begin
              TmpReg:=GetIntRegister(List,Size);
              A_Load_Ref_Reg(List,Size,Size,Loc.Reference,TmpReg);
              A_Cmp_Ref_Reg_Label(List,Size,CmpOp,Ref,TmpReg,L);
            end;
          else
            InternalError(2001090605);
        end;
      end;


    procedure TCG.A_LoadMM_Loc_Reg(List: TAsmList; Size: TCgSize; const Loc: TLocation; const Reg: TRegister;Shuffle : PMMShuffle);
      begin
        case Loc.Loc of
          LOC_MMREGISTER,LOC_CMMREGISTER:
            A_LoadMM_Reg_Reg(List,Loc.Size,Size,Loc.Register,Reg,Shuffle);
          LOC_REFERENCE,LOC_CREFERENCE:
            A_LoadMM_Ref_Reg(List,Loc.Size,Size,Loc.Reference,Reg,Shuffle);
          LOC_REGISTER,LOC_CREGISTER:
            A_LoadMM_IntReg_Reg(List,Loc.Size,Size,Loc.Register,Reg,Shuffle);
          else
            InternalError(200310121);
        end;
      end;


    procedure TCG.A_LoadMM_Reg_Loc(List: TAsmList; Size: TCgSize; const Reg: TRegister; const Loc: TLocation;Shuffle : PMMShuffle);
      begin
        case Loc.Loc of
          LOC_MMREGISTER,LOC_CMMREGISTER:
            A_LoadMM_Reg_Reg(List,Size,Loc.Size,Reg,Loc.Register,Shuffle);
          LOC_REFERENCE,LOC_CREFERENCE:
            A_LoadMM_Reg_Ref(List,Size,Loc.Size,Reg,Loc.Reference,Shuffle);
          else
            InternalError(200310122);
        end;
      end;


    procedure TCG.A_LoadMM_Reg_CGPara(List: TAsmList; Size: TCgSize; Reg: TRegister;const CGPara : TCGPara;Shuffle : PMMShuffle);
      var
        HRef  : TReference;
{$ifndef cpu64bitalu}
        TmpReg : TRegister;
        Reg64 : TRegister64;
{$endif not cpu64bitalu}
      begin
{$ifndef cpu64bitalu}
         if not(CGPara.Location^.Loc in [LOC_REGISTER,LOC_CREGISTER]) or
            (Size<>OS_F64) then
{$endif not cpu64bitalu}
           CGPara.Check_Simple_Location;
         ParaManager.AllocCGPara(List,CGPara);
         case CGPara.Location^.Loc of
          LOC_MMREGISTER,LOC_CMMREGISTER:
            A_LoadMM_Reg_Reg(List,Size,CGPara.Location^.Size,Reg,CGPara.Location^.Register,Shuffle);
          LOC_REFERENCE,LOC_CREFERENCE:
            begin
              Reference_Reset_Base(HRef,CGPara.Location^.Reference.Index,CGPara.Location^.Reference.Offset,CTempPosInvalid,CGPara.Alignment,[]);
              A_LoadMM_Reg_Ref(List,Size,CGPara.Location^.Size,Reg,HRef,Shuffle);
            end;
          LOC_REGISTER,LOC_CREGISTER:
            begin
              if Assigned(Shuffle) and
                 not ShuffleScalar(Shuffle) then
                InternalError(2009112510);
{$ifndef cpu64bitalu}
              if (Size=OS_F64) then
                begin
                  if not Assigned(CGPara.Location^.Next) or
                     Assigned(CGPara.Location^.Next^.Next) then
                    InternalError(2009112512);
                  case CGPara.Location^.Next^.Loc of
                    LOC_REGISTER,LOC_CREGISTER:
                      TmpReg:=CGPara.Location^.Next^.Register;
                    LOC_REFERENCE,LOC_CREFERENCE:
                      TmpReg:=GetIntRegister(List,OS_32);
                    else
                      InternalError(2009112910);
                  end;
                  if (TargetInfo.Endian=ENDIAN_BIG) then
                    begin
                      { paraloc^ -> high
                        paraloc^.next -> low }
                      Reg64.RegHi:=CGPara.Location^.Register;
                      Reg64.RegLo:=TmpReg;
                    end
                  else
                    begin
                      { paraloc^ -> low
                        paraloc^.next -> high }
                      Reg64.RegLo:=CGPara.Location^.Register;
                      Reg64.RegHi:=TmpReg;
                    end;
                  CG64.A_LoadMM_Reg_IntReg64(List,Size,Reg,Reg64);
                  if (CGPara.Location^.Next^.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                    begin
                      if not(CGPara.Location^.Next^.Size in [OS_32,OS_S32]) then
                        InternalError(2009112911);
                      Reference_Reset_Base(HRef,CGPara.Location^.Next^.Reference.Index,CGPara.Location^.Next^.Reference.Offset,CTempPosInvalid,CGPara.Alignment,[]);
                      A_Load_Reg_Ref(List,OS_32,CGPara.Location^.Next^.Size,TmpReg,HRef);
                    end;
                end
              else
{$endif not cpu64bitalu}
                A_LoadMM_Reg_IntReg(List,Size,CGPara.Location^.Size,Reg,CGPara.Location^.Register,MMS_MoveScalar);
            end
          else
            InternalError(200310123);
        end;
      end;


    procedure TCG.A_LoadMM_Ref_CGPara(List: TAsmList; Size: TCgSize;const Ref: TReference;const CGPara : TCGPara;Shuffle : PMMShuffle);
      var
         HR : TRegister;
         HS : TMMShuffle;
         LRegisterSize: TCgSize;
      begin
         CGPara.Check_Simple_Location;
         LRegisterSize:=CGPara.Location^.Size;
         { An ABI may carry a scalar float in an integer argument slot, e.g.
           Win64 C varargs. Its temporary SSE register still needs a float size. }
         if LRegisterSize in [OS_32,OS_S32,OS_64,OS_S64] then
           LRegisterSize:=Int_Float_CGSize(TCgSize2Size[LRegisterSize]);
         HR:=GetMMRegister(List,LRegisterSize);
         A_LoadMM_Ref_Reg(List,Size,LRegisterSize,Ref,HR,Shuffle);
         if RealShuffle(Shuffle) then
           begin
             HS:=Shuffle^;
             RemoveShuffles(HS);
             A_LoadMM_Reg_CGPara(List,LRegisterSize,HR,CGPara,@HS);
           end
         else
           A_LoadMM_Reg_CGPara(List,LRegisterSize,HR,CGPara,Shuffle);
      end;


    procedure TCG.A_LoadMM_Loc_CGPara(List: TAsmList;const Loc: TLocation; const CGPara : TCGPara;Shuffle : PMMShuffle);
      begin
        case Loc.Loc of
          LOC_MMREGISTER,LOC_CMMREGISTER:
            A_LoadMM_Reg_CGPara(List,Loc.Size,Loc.Register,CGPara,Shuffle);
          LOC_REFERENCE,LOC_CREFERENCE:
            A_LoadMM_Ref_CGPara(List,Loc.Size,Loc.Reference,CGPara,Shuffle);
          else
            InternalError(2003101204);
        end;
      end;


    procedure TCG.A_OpMM_Ref_Reg(List: TAsmList; Op: TOpCG; Size : TCgSize;const Ref: TReference; Reg: TRegister;Shuffle : PMMShuffle);
      var
         HR : TRegister;
         HS : TMMShuffle;
      begin
         HR:=GetMMRegister(List,Size);
         A_LoadMM_Ref_Reg(List,Size,Size,Ref,HR,Shuffle);
         if RealShuffle(Shuffle) then
           begin
             HS:=Shuffle^;
             RemoveShuffles(HS);
             A_OpMM_Reg_Reg(List,Op,Size,HR,Reg,@HS);
           end
         else
           A_OpMM_Reg_Reg(List,Op,Size,HR,Reg,Shuffle);
      end;


    procedure TCG.A_OpMM_Reg_Ref(List: TAsmList; Op: TOpCG; Size : TCgSize;Reg: TRegister; const Ref: TReference; Shuffle : PMMShuffle);
      var
         HR : TRegister;
         HS : TMMShuffle;
      begin
         HR:=GetMMRegister(List,Size);
         A_LoadMM_Ref_Reg(List,Size,Size,Ref,HR,Shuffle);
         if RealShuffle(Shuffle) then
           begin
             HS:=Shuffle^;
             RemoveShuffles(HS);
             A_OpMM_Reg_Reg(List,Op,Size,Reg,HR,@HS);
             A_LoadMM_Reg_Ref(List,Size,Size,HR,Ref,@HS);
           end
         else
           begin
             A_OpMM_Reg_Reg(List,Op,Size,Reg,HR,Shuffle);
             A_LoadMM_Reg_Ref(List,Size,Size,HR,Ref,Shuffle);
           end;
      end;


    procedure TCG.A_LoadMM_IntReg_Reg(List: TAsmList; FromSize,ToSize: TCgSize; IntReg,MMReg: TRegister; Shuffle: PMMShuffle);
      var
        TmpRef: TReference;
      begin
        if (TCgSize2Size[FromSize]<>4) or
           (TCgSize2Size[ToSize]<>4) then
          InternalError(2009112503);
        TG.GetTemp(List,4,4,tt_normal,TmpRef);
        A_Load_Reg_Ref(List,FromSize,FromSize,IntReg,TmpRef);
        A_LoadMM_Ref_Reg(List,ToSize,ToSize,TmpRef,MMReg,Shuffle);
        TG.UnGetTemp(List,TmpRef);
      end;


    procedure TCG.A_LoadMM_Reg_IntReg(List: TAsmList; FromSize,ToSize: TCgSize; MMReg,IntReg: TRegister; Shuffle: PMMShuffle);
      var
        TmpRef: TReference;
      begin
        if (TCgSize2Size[FromSize]<>4) or
           (TCgSize2Size[ToSize]<>4) then
          InternalError(2009112504);
        TG.GetTemp(List,8,8,tt_normal,TmpRef);
        A_LoadMM_Reg_Ref(List,FromSize,FromSize,MMReg,TmpRef,Shuffle);
        A_Load_Ref_Reg(List,ToSize,ToSize,TmpRef,IntReg);
        TG.UnGetTemp(List,TmpRef);
      end;


    procedure TCG.A_OpMM_Loc_Reg(List: TAsmList; Op: TOpCG; Size : TCgSize;const Loc: TLocation; Reg: TRegister;Shuffle : PMMShuffle);
      begin
        case Loc.Loc of
          LOC_CMMREGISTER,LOC_MMREGISTER:
            A_OpMM_Reg_Reg(List,Op,Size,Loc.Register,Reg,Shuffle);
          LOC_CREFERENCE,LOC_REFERENCE:
            A_OpMM_Ref_Reg(List,Op,Size,Loc.Reference,Reg,Shuffle);
          else
            InternalError(200312232);
        end;
      end;


    procedure TCG.A_OpMM_Loc_Reg_Reg(List: TAsmList; Op: TOpCG; Size : TCgSize;const Loc: TLocation; Src,Dst: TRegister;Shuffle : PMMShuffle);
      begin
        case Loc.Loc of
          LOC_CMMREGISTER,LOC_MMREGISTER:
            A_OpMM_Reg_Reg_Reg(List,Op,Size,Loc.Register,Src,Dst,Shuffle);
          LOC_CREFERENCE,LOC_REFERENCE:
            A_OpMM_Ref_Reg_Reg(List,Op,Size,Loc.Reference,Src,Dst,Shuffle);
          else
            InternalError(2003122304);
        end;
      end;


    procedure TCG.A_OpMM_Reg_Reg_Reg(List : TAsmList;Op : TOpCG;Size : TCgSize;
      Src1,Src2,Dst : TRegister;Shuffle : PMMShuffle);
      begin
        InternalError(2013061102);
      end;


    procedure TCG.A_OpMM_Ref_Reg_Reg(List : TAsmList;Op : TOpCG;Size : TCgSize;
      const Ref : TReference;Src,Dst : TRegister;Shuffle : PMMShuffle);
      begin
        InternalError(2013061101);
      end;


    procedure TCG.G_ConcatCopy_Move(List : TAsmList;const Source,Dest : TReference;Len : TCGInt);
      var
        ParaLoc1,ParaLoc2,ParaLoc3 : TCGPara;
        PD : TProcDef;
      begin
        PD:=Search_System_Proc('MOVE');
        ParaLoc1.Init;
        ParaLoc2.Init;
        ParaLoc3.Init;
        ParaManager.GetCGTempParaLoc(List,PD,1,ParaLoc1);
        ParaManager.GetCGTempParaLoc(List,PD,2,ParaLoc2);
        ParaManager.GetCGTempParaLoc(List,PD,3,ParaLoc3);
        A_Load_Const_CGPara(List,OS_SINT,Len,ParaLoc3);
        A_LoadAddr_Ref_CGPara(List,Dest,ParaLoc2);
        A_LoadAddr_Ref_CGPara(List,Source,ParaLoc1);
        ParaManager.FreeCGPara(List,ParaLoc3);
        ParaManager.FreeCGPara(List,ParaLoc2);
        ParaManager.FreeCGPara(List,ParaLoc1);
        AllocAllCPURegisters(List);
        A_Call_Name(List,'FPC_MOVE',False);
        DeallocAllCPURegisters(List);
        ParaLoc3.Done;
        ParaLoc2.Done;
        ParaLoc1.Done;
      end;


    procedure TCG.G_ConcatCopy_Unaligned(List : TAsmList;const Source,Dest : TReference;Len : TCGInt);
      begin
        G_ConcatCopy(List,Source,Dest,Len);
      end;


    procedure TCG.G_OverflowCheck_Loc(List:TAsmList;const Loc:TLocation;Def:TDef;OVLoc : TLocation);
      begin
        G_OverflowCheck(List,Loc,Def);
      end;


{$ifdef cpuflags}
    procedure TCG.G_Flags2Ref(List: TAsmList; Size: TCgSize; const F: TResFlags; const Ref:TReference);

      var
        TmpReg : TRegister;
      begin
        TmpReg:=GetIntRegister(List,Size);
        G_Flags2Reg(List,Size,F,TmpReg);
        A_Load_Reg_Ref(List,Size,Size,TmpReg,Ref);
      end;
{$endif cpuflags}


{*****************************************************************************
                            Entry/Exit Code Functions
*****************************************************************************}


    procedure TCG.G_Save_Registers(List:TAsmList);
      var
        HRef : TReference;
        Size : LongInt;
        R : Integer;
        RegsToSaveInt,
        RegsToSaveAddress,
        RegsToSaveMM : TCPURegisterArray;
      begin
        RegsToSaveInt:=ParaManager.Get_Saved_Registers_Int(CurrentProcInfo.ProcDef.ProcCallOption);
        RegsToSaveAddress:=ParaManager.Get_Saved_Registers_Address(CurrentProcInfo.ProcDef.ProcCallOption);
        RegsToSaveMM:=ParaManager.Get_Saved_Registers_MM(CurrentProcInfo.ProcDef.ProcCallOption);
        { calculate temp. size }
        Size:=0;
        for R:=Low(RegsToSaveInt) to High(RegsToSaveInt) do
          if RegsToSaveInt[R] in RG[R_INTREGISTER].UsedInProc then
            Inc(Size,SizeOf(AInt));
        if Uses_Registers(R_ADDRESSREGISTER) then
          for R:=Low(RegsToSaveInt) to High(RegsToSaveInt) do
            if RegsToSaveInt[R] in RG[R_ADDRESSREGISTER].UsedInProc then
              Inc(Size,SizeOf(AInt));

        { mm registers }
        if Uses_Registers(R_MMREGISTER) then
          begin
            { Make sure we reserve enough space to do the alignment based on the offset
              later on. We can't use the size for this, because the alignment of the start
              of the temp is smaller than needed for an OS_VECTOR }
            Inc(Size,TCgSize2Size[OS_VECTOR]);

            for R:=Low(RegsToSaveMM) to High(RegsToSaveMM) do
              if RegsToSaveMM[R] in RG[R_MMREGISTER].UsedInProc then
                Inc(Size,TCgSize2Size[OS_VECTOR]);
          end;

        if Size>0 then
          begin
            TG.GetTemp(List,Size,SizeOf(AInt),tt_noreuse,CurrentProcInfo.SaveRegsRef);
            Include(CurrentProcInfo.Flags,pi_has_saved_regs);

            { Copy registers to temp }
            HRef:=CurrentProcInfo.SaveRegsRef;
            for R:=Low(RegsToSaveInt) to High(RegsToSaveInt) do
              begin
                if RegsToSaveInt[R] in RG[R_INTREGISTER].UsedInProc then
                  begin
                    A_Load_Reg_Ref(List,OS_ADDR,OS_ADDR,NewReg(R_INTREGISTER,RegsToSaveInt[R],R_SUBWHOLE),HRef);
                    Inc(HRef.Offset,SizeOf(AInt));
                    Include(RG[R_INTREGISTER].PreservedByProc,RegsToSaveInt[R]);
                  end;
              end;
            CurrentProcInfo.SavedRegsInt := RG[R_INTREGISTER].PreservedByProc;

            if Uses_Registers(R_ADDRESSREGISTER) then
              begin
                for R:=Low(RegsToSaveAddress) to High(RegsToSaveAddress) do
                  begin
                    if RegsToSaveAddress[R] in RG[R_ADDRESSREGISTER].UsedInProc then
                      begin
                        A_Load_Reg_Ref(List,OS_ADDR,OS_ADDR,NewReg(R_ADDRESSREGISTER,RegsToSaveAddress[R],R_SUBWHOLE),HRef);
                        Inc(HRef.Offset,SizeOf(AInt));
                        Include(RG[R_ADDRESSREGISTER].PreservedByProc,RegsToSaveAddress[R]);
                      end;
                  end;

                CurrentProcInfo.SavedRegsMM := RG[R_MMREGISTER].PreservedByProc;
              end;

            if Uses_Registers(R_MMREGISTER) then
              begin
                if (HRef.Offset mod TCgSize2Size[OS_VECTOR])<>0 then
                  Inc(HRef.Offset,TCgSize2Size[OS_VECTOR]-(HRef.Offset mod TCgSize2Size[OS_VECTOR]));

                for R:=Low(RegsToSaveMM) to High(RegsToSaveMM) do
                  begin
                    { the array has to be declared even if no MM registers are saved
                      (such as with SSE on i386), and since 0-element arrays don't
                      exist, they contain a single RS_INVALID element in that case
                    }
                    if RegsToSaveMM[R]<>RSInvalid then
                      begin
                        if RegsToSaveMM[R] in RG[R_MMREGISTER].UsedInProc then
                          begin
                            A_LoadMM_Reg_Ref(List,OS_VECTOR,OS_VECTOR,NewReg(R_MMREGISTER,RegsToSaveMM[R],R_SUBMMWHOLE),HRef,nil);
                            Inc(HRef.Offset,TCgSize2Size[OS_VECTOR]);
                            Include(RG[R_MMREGISTER].PreservedByProc,RegsToSaveMM[R]);
                          end;
                      end;
                  end;

                CurrentProcInfo.SavedRegsMM := RG[R_MMREGISTER].PreservedByProc;
              end;
          end;
      end;


    procedure TCG.G_Restore_Registers(List:TAsmList);
      var
        HRef     : TReference;
        R        : Integer;
        HReg     : TRegister;
        RegsToSaveInt,
        RegsToSaveAddress,
        RegsToSaveMM : TCPURegisterArray;
      begin
        if not(pi_has_saved_regs in CurrentProcInfo.Flags) then
          Exit;
        RegsToSaveInt:=ParaManager.Get_Saved_Registers_Int(CurrentProcInfo.ProcDef.ProcCallOption);
        RegsToSaveAddress:=ParaManager.Get_Saved_Registers_Address(CurrentProcInfo.ProcDef.ProcCallOption);
        RegsToSaveMM:=ParaManager.Get_Saved_Registers_MM(CurrentProcInfo.ProcDef.ProcCallOption);
        { Copy registers from temp }
        HRef:=CurrentProcInfo.SaveRegsRef;
        for R:=Low(RegsToSaveInt) to High(RegsToSaveInt) do
          if RegsToSaveInt[R] in RG[R_INTREGISTER].UsedInProc then
            begin
              HReg:=NewReg(R_INTREGISTER,RegsToSaveInt[R],R_SUBWHOLE);
              { Allocate register so the optimizer does not remove the load }
              A_Reg_Alloc(List,HReg);
              A_Load_Ref_Reg(List,OS_ADDR,OS_ADDR,HRef,HReg);
              Inc(HRef.Offset,SizeOf(AInt));
            end;

        if Uses_Registers(R_ADDRESSREGISTER) then
          for R:=Low(RegsToSaveAddress) to High(RegsToSaveAddress) do
            if RegsToSaveAddress[R] in RG[R_ADDRESSREGISTER].UsedInProc then
              begin
                HReg:=NewReg(R_ADDRESSREGISTER,RegsToSaveAddress[R],R_SUBWHOLE);
                { Allocate register so the optimizer does not remove the load }
                A_Reg_Alloc(List,HReg);
                A_Load_Ref_Reg(List,OS_ADDR,OS_ADDR,HRef,HReg);
                Inc(HRef.Offset,SizeOf(AInt));
              end;

        if Uses_Registers(R_MMREGISTER) then
          begin
            if (HRef.Offset mod TCgSize2Size[OS_VECTOR])<>0 then
              Inc(HRef.Offset,TCgSize2Size[OS_VECTOR]-(HRef.Offset mod TCgSize2Size[OS_VECTOR]));

            for R:=Low(RegsToSaveMM) to High(RegsToSaveMM) do
              begin
                if RegsToSaveMM[R] in RG[R_MMREGISTER].UsedInProc then
                  begin
                    HReg:=NewReg(R_MMREGISTER,RegsToSaveMM[R],R_SUBMMWHOLE);
                    { Allocate register so the optimizer does not remove the load }
                    A_Reg_Alloc(List,HReg);
                    A_LoadMM_Ref_Reg(List,OS_VECTOR,OS_VECTOR,HRef,HReg,nil);
                    Inc(HRef.Offset,TCgSize2Size[OS_VECTOR]);
                  end;
              end;
          end;
        TG.UnGetTemp(List,CurrentProcInfo.SaveRegsRef);
      end;


    procedure TCG.G_Adjust_Self_Value(List:TAsmList;ProcDef: TProcDef;IOffset: TCGInt);
      var
        HSym : TSym;
        HRef : TReference;
        ParaLoc : PCGParaLocation;
      begin
        { calculate the parameter info for the procdef }
        ProcDef.Init_ParaLoc_Info(CallerSide);
        HSym:=TSym(ProcDef.ParaST.Find('self'));
        if not(Assigned(HSym) and
               (HSym.Typ=ParaVarSym)) then
          InternalError(200305251);
        ParaLoc:=TParaVarSym(HSym).ParaLoc[CallerSide].Location;
        while ParaLoc<>nil do
          with ParaLoc^ do
            begin
              case Loc of
                LOC_REGISTER:
                  A_Op_Const_Reg(List,OP_SUB,Size,IOffset,Register);
                LOC_REFERENCE:
                  begin
                    { offset in the wrapper needs to be adjusted for the stored
                      return address }
                    Reference_Reset_Base(HRef,Reference.Index,Reference.Offset+SizeOf(PInt),CTempPosInvalid,SizeOf(PInt),[]);
                    A_Op_Const_Ref(List,OP_SUB,Size,IOffset,HRef);
                  end
                else
                  InternalError(200309189);
              end;
              ParaLoc:=Next;
            end;
      end;


    procedure TCG.A_Call_Name_Static(List : TAsmList;const S : string);
      begin
        A_Call_Name(List,S,False);
      end;


   function TCG.G_Indirect_Sym_Load(List:TAsmList;const SymName: string; const Flags: TIndSymFlags): TRegister;
      var
        L: TAsmSymbol;
        Ref: TReference;
        NLSymName: string;
        SymTyp: TAsmsymtype;
      begin
        Result := NR_NO;
        case TargetInfo.System of
          system_i386_darwin,
          system_i386_iphonesim:
            begin
              NLSymName:='L'+SymName+'$non_lazy_ptr';
              L:=CurrentAsmData.GetAsmSymbol(NLSymName);
              if not(Assigned(L)) then
                begin
                  if is_data in Flags then
                    SymTyp:=AT_DATA
                  else
                    SymTyp:=AT_FUNCTION;
                  new_section(CurrentAsmData.AsmLists[al_picdata],sec_data_nonlazy,'',SizeOf(PInt));
                  L:=CurrentAsmData.DefineAsmSymbol(NLSymName,AB_LOCAL,AT_DATA,VoidPointerType);
                  CurrentAsmData.AsmLists[al_picdata].Concat(TAISymbol.Create(L,0));
                  if not(is_weak in Flags) then
                    CurrentAsmData.AsmLists[al_picdata].Concat(TAIDirective.Create(asd_indirect_symbol,CurrentAsmData.RefAsmSymbol(SymName,SymTyp).Name))
                  else
                    CurrentAsmData.AsmLists[al_picdata].Concat(TAIDirective.Create(asd_indirect_symbol,CurrentAsmData.WeakRefAsmSymbol(SymName,SymTyp).Name));
{$ifdef cpu64bitaddr}
                  CurrentAsmData.AsmLists[al_picdata].Concat(TAIConst.create_64bit(0));
{$else cpu64bitaddr}
                  CurrentAsmData.AsmLists[al_picdata].Concat(TAIConst.create_32bit(0));
{$endif cpu64bitaddr}
                end;
              Result := GetAddressRegister(List);
              Reference_Reset_Symbol(Ref,L,0,SizeOf(PInt),[]);
              { a_load_ref_reg will turn this into a pic-load if needed }
              A_Load_Ref_Reg(List,OS_ADDR,OS_ADDR,Ref,Result);
            end;
          else
            ;
        end;
      end;


    procedure TCG.G_Maybe_Got_Init(List: TAsmList);
      begin
      end;


    procedure TCG.G_Maybe_TLS_Init(List: TAsmList);
      begin
      end;


    procedure TCG.G_Call(List: TAsmList;const S: string);
      begin
        AllocAllCPURegisters(List);
        if SystemUnit<>CurrentModule.GlobalSymTable then
          CurrentModule.Add_Extern_AsmSym(S,AB_EXTERNAL,AT_FUNCTION);
        A_Call_Name(List,S,False);
        DeallocAllCPURegisters(List);
      end;

    procedure TCG.G_Local_Unwind(List: TAsmList; L: TAsmLabel);
      begin
        A_Jmp_Always(List,L);
      end;

    procedure TCG.A_LoadMM_Reg_Reg(List: TAsmList; FromSize, ToSize: TCgSize; Reg1, Reg2: TRegister; Shuffle: PMMShuffle);
      begin
        InternalError(200807231);
      end;


    procedure TCG.A_LoadMM_Ref_Reg(List: TAsmList; FromSize, ToSize: TCgSize; const Ref: TReference; Reg: TRegister; Shuffle: PMMShuffle);
      begin
        InternalError(200807232);
      end;


    procedure TCG.A_LoadMM_Reg_Ref(List: TAsmList; FromSize, ToSize: TCgSize; Reg: TRegister; const Ref: TReference; Shuffle: PMMShuffle);
      begin
        InternalError(200807233);
      end;


    procedure TCG.A_OpMM_Reg_Reg(List: TAsmList; Op: TOpCG; Size: TCgSize; Src, Dst: TRegister; Shuffle: PMMShuffle);
      begin
        InternalError(200807234);
      end;


    function TCG.GetFlagRegister(List: TAsmList; Size: TCgSize): TRegister;
      begin
        Result:=TRegister(0);
        InternalError(200807238);
      end;


    procedure TCG.A_Bit_Scan_Reg_Reg(List: TAsmList; Reverse,NotZero: Boolean; SrcSize, DstSize: TCgSize; Src, Dst: TRegister);
      begin
        InternalError(2014070601);
      end;


    procedure TCG.G_StackPointer_Alloc(List: TAsmList; Size: LongInt);
      begin
        InternalError(2014070602);
      end;


    procedure TCG.A_Mul_Reg_Reg_Pair(List: TAsmList; Size: TCgSize; Src1,Src2,DstLo,DstHi: TRegister);
      begin
        InternalError(2014060801);
      end;


    procedure TCG.G_Div_Const_Reg_Reg(List:TAsmList; Size: TCgSize; A: TCGInt; Src,Dst: TRegister);
      var
        DivReg: TRegister;
        Magic: AInt;
        UMagic: AWord;
        UShift: Byte;
        UAdd: Boolean;
      begin
        DivReg:=GetIntRegister(List,OS_INT);
        if (Size in [OS_S32,OS_S64]) then
          begin
            Calc_DivConst_Magic_Signed(TCgSize2Size[Size]*8,A,Magic,UShift);
            { load magic value }
            A_Load_Const_Reg(List,OS_INT,Magic,DivReg);
            { multiply, discarding low bits }
            A_Mul_Reg_Reg_Pair(List,Size,Src,DivReg,NR_NO,Dst);
            { add/subtract numerator }
            if (A>0) and (Magic<0) then
              A_Op_Reg_Reg_Reg(List,OP_ADD,OS_INT,Src,Dst,Dst)
            else if (A<0) and (Magic>0) then
              A_Op_Reg_Reg_Reg(List,OP_SUB,OS_INT,Src,Dst,Dst);
            { shift shift places to the right (arithmetic) }
            A_Op_Const_Reg_Reg(List,OP_SAR,OS_INT,UShift,Dst,Dst);
            { extract and add sign bit }
            if (A>=0) then
              A_Op_Const_Reg_Reg(List,OP_SHR,OS_INT,TCgSize2Size[Size]*8-1,Src,DivReg)
            else
              A_Op_Const_Reg_Reg(List,OP_SHR,OS_INT,TCgSize2Size[Size]*8-1,Dst,DivReg);
            A_Op_Reg_Reg_Reg(List,OP_ADD,OS_INT,Dst,DivReg,Dst);
          end
        else if (Size in [OS_32,OS_64]) then
          begin
            Calc_DivConst_Magic_Unsigned(TCgSize2Size[Size]*8,A,UMagic,UAdd,UShift);
            { load magic in divreg }
            A_Load_Const_Reg(List,OS_INT,TCGInt(UMagic),DivReg);
            { multiply, discarding low bits }
            A_Mul_Reg_Reg_Pair(List,Size,Src,DivReg,NR_NO,Dst);
            if (UAdd) then
              begin
                { Calculate "(numerator+result) shr u_shift", avoiding possible overflow }
                A_Op_Reg_Reg_Reg(List,OP_SUB,OS_INT,Dst,Src,DivReg);
                { divreg=(numerator-result) }
                A_Op_Const_Reg_Reg(List,OP_SHR,OS_INT,1,DivReg,DivReg);
                { divreg=(numerator-result)/2 }
                A_Op_Reg_Reg_Reg(List,OP_ADD,OS_INT,DivReg,Dst,DivReg);
                { divreg=(numerator+result)/2, already shifted by 1, so decrease u_shift. }
                A_Op_Const_Reg_Reg(List,OP_SHR,OS_INT,UShift-1,DivReg,Dst);
              end
            else
              A_Op_Const_Reg_Reg(List,OP_SHR,OS_INT,UShift,Dst,Dst);
          end
        else
          InternalError(2014060601);
      end;


    procedure TCG.G_Check_For_FPU_Exception(List: TAsmList;Force,Clear : Boolean);
      begin
        { empty by default }
      end;


    procedure TCG.Maybe_Check_For_FPU_Exception(List: TAsmList);
      begin
        CurrentProcInfo.FPUExceptionCheckNeeded:=True;
        G_Check_For_FPU_Exception(List,False,True);
      end;


    procedure TCG.Adjust_ExceptFilter_Ref(var Ref: TReference; ForFinalization: Boolean);
      begin
        { empty by default, override in CPU-specific code generator }
      end;

{*****************************************************************************
                                    TCG64
*****************************************************************************}

{$ifndef cpu64bitalu}
    function JoinReg64(RegLo,RegHi : TRegister) : TRegister64;
      begin
         Result.RegLo:=RegLo;
         Result.RegHi:=RegHi;
      end;


    procedure TCG64.A_Op64_Const_Reg_Reg(List: TAsmList;Op:TOpCG;Size : TCgSize;Value : Int64; RegSrc,RegDst : TRegister64);
      begin
        A_Load64_Reg_Reg(List,RegSrc,RegDst);
        A_Op64_Const_Reg(List,Op,Size,Value,RegDst);
      end;


    procedure TCG64.A_Op64_Reg_Reg_Reg(List: TAsmList;Op:TOpCG;Size : TCgSize;RegSrc1,RegSrc2,RegDst : TRegister64);
      var
        TmpReg64 : TRegister64;
      begin
        { when src1=dst then we need to first create a temp to prevent
          overwriting src1 with src2 }
        if (RegSrc1.RegHi=RegDst.RegHi) or
           (RegSrc1.RegLo=RegDst.RegHi) or
           (RegSrc1.RegHi=RegDst.RegLo) or
           (RegSrc1.RegLo=RegDst.RegLo) then
          begin
            TmpReg64.RegLo:=CG.GetIntRegister(List,OS_32);
            TmpReg64.RegHi:=CG.GetIntRegister(List,OS_32);
            A_Load64_Reg_Reg(List,RegSrc2,TmpReg64);
            A_Op64_Reg_Reg(List,Op,Size,RegSrc1,TmpReg64);
            A_Load64_Reg_Reg(List,TmpReg64,RegDst);
          end
        else
          begin
            A_Load64_Reg_Reg(List,RegSrc2,RegDst);
            A_Op64_Reg_Reg(List,Op,Size,RegSrc1,RegDst);
          end;
      end;


    procedure TCG64.A_Op64_Const_SubsetRef(List : TAsmList; Op : TOpCG; Size : TCgSize; A : Int64; const SRef: TSubsetReference);
      var
        TmpReg64 : TRegister64;
      begin
        TmpReg64.RegLo:=CG.GetIntRegister(List,OS_32);
        TmpReg64.RegHi:=CG.GetIntRegister(List,OS_32);
        A_Load64_SubsetRef_Reg(List,SRef,TmpReg64);
        A_Op64_Const_Reg(List,Op,Size,A,TmpReg64);
        A_Load64_Reg_SubsetRef(List,TmpReg64,SRef);
      end;


    procedure TCG64.A_Op64_Reg_SubsetRef(List : TAsmList; Op : TOpCG; Size : TCgSize; Reg: TRegister64; const SRef: TSubsetReference);
      var
        TmpReg64 : TRegister64;
      begin
        TmpReg64.RegLo:=CG.GetIntRegister(List,OS_32);
        TmpReg64.RegHi:=CG.GetIntRegister(List,OS_32);
        A_Load64_SubsetRef_Reg(List,SRef,TmpReg64);
        A_Op64_Reg_Reg(List,Op,Size,Reg,TmpReg64);
        A_Load64_Reg_SubsetRef(List,TmpReg64,SRef);
      end;


    procedure TCG64.A_Op64_Ref_SubsetRef(List : TAsmList; Op : TOpCG; Size : TCgSize; const Ref: TReference; const SRef: TSubsetReference);
      var
        TmpReg64 : TRegister64;
      begin
        TmpReg64.RegLo:=CG.GetIntRegister(List,OS_32);
        TmpReg64.RegHi:=CG.GetIntRegister(List,OS_32);
        A_Load64_SubsetRef_Reg(List,SRef,TmpReg64);
        A_Op64_Ref_Reg(List,Op,Size,Ref,TmpReg64);
        A_Load64_Reg_SubsetRef(List,TmpReg64,SRef);
      end;


    procedure TCG64.A_Op64_SubsetRef_SubsetRef(List : TAsmList; Op : TOpCG; Size : TCgSize; const SSRef,DSRef: TSubsetReference);
      var
        TmpReg64 : TRegister64;
      begin
        TmpReg64.RegLo:=CG.GetIntRegister(List,OS_32);
        TmpReg64.RegHi:=CG.GetIntRegister(List,OS_32);
        A_Load64_SubsetRef_Reg(List,SSRef,TmpReg64);
        A_Op64_Reg_SubsetRef(List,Op,Size,TmpReg64,DSRef);
      end;


    procedure TCG64.A_Op64_Const_Reg_Reg_CheckOverflow(List: TAsmList;Op:TOpCG;Size : TCgSize;Value : Int64;RegSrc,RegDst : TRegister64;SetFlags : Boolean;var OVLoc : TLocation);
      begin
        A_Op64_Const_Reg_Reg(List,Op,Size,Value,RegSrc,RegDst);
        OVLoc.Loc:=LOC_VOID;
      end;


    procedure TCG64.A_Op64_Reg_Reg_Reg_CheckOverflow(List: TAsmList;Op:TOpCG;Size : TCgSize;RegSrc1,RegSrc2,RegDst : TRegister64;SetFlags : Boolean;var OVLoc : TLocation);
      begin
        A_Op64_Reg_Reg_Reg(List,Op,Size,RegSrc1,RegSrc2,RegDst);
        OVLoc.Loc:=LOC_VOID;
      end;


    procedure TCG64.A_Op64_Reg(List: TAsmList; Op: TOpCG; Size: TCgSize; RegDst: TRegister64);
      begin
        if not (Op in [OP_NOT,OP_NEG]) then
          InternalError(2020050706);
        A_Op64_Reg_Reg(List,Op,Size,RegDst,RegDst);
      end;


    procedure TCG64.A_Op64_Ref(List: TAsmList; Op: TOpCG; Size: TCgSize; const Ref: TReference);
      var
        TempReg: TRegister64;
      begin
        if not (Op in [OP_NOT,OP_NEG]) then
          InternalError(2020050713);
        TempReg.RegHi:=CG.GetIntRegister(List,OS_32);
        TempReg.RegLo:=CG.GetIntRegister(List,OS_32);
        A_Load64_Ref_Reg(List,Ref,TempReg);
        A_Op64_Reg_Reg(List,Op,Size,TempReg,TempReg);
        A_Load64_Reg_Ref(List,TempReg,Ref);
      end;


    procedure TCG64.A_Op64_Loc(List: TAsmList; Op: TOpCG; Size: TCgSize; const L: TLocation);
      begin
        case L.Loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            A_Op64_Ref(List,Op,Size,L.Reference);
          LOC_REGISTER,LOC_CREGISTER:
            A_Op64_Reg(List,Op,Size,L.Register64);
          else
            InternalError(2020050707);
        end;
      end;


    procedure TCG64.A_Load64_Loc_SubsetRef(List : TAsmList;const L: TLocation; const SRef : TSubsetReference);
      begin
        case L.Loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            A_Load64_Ref_SubsetRef(List,L.Reference,SRef);
          LOC_REGISTER,LOC_CREGISTER:
            A_Load64_Reg_SubsetRef(List,L.Register64,SRef);
          LOC_CONSTANT :
            A_Load64_Const_SubsetRef(List,L.Value64,SRef);
          LOC_SUBSETREF,LOC_CSUBSETREF:
            A_Load64_SubsetRef_SubsetRef(List,L.SRef,SRef);
          else
            InternalError(2006082210);
        end;
      end;


    procedure TCG64.A_Load64_SubsetRef_Loc(List: TAsmList; const SRef: TSubsetReference; const L: TLocation);
      begin
        case L.Loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            A_Load64_SubsetRef_Ref(List,SRef,L.Reference);
          LOC_REGISTER,LOC_CREGISTER:
            A_Load64_SubsetRef_Reg(List,SRef,L.Register64);
          LOC_SUBSETREF,LOC_CSUBSETREF:
            A_Load64_SubsetRef_SubsetRef(List,SRef,L.SRef);
          else
            InternalError(2006082211);
        end;
      end;
{$else cpu64bitalu}

    function JoinReg128(RegLo, RegHi: TRegister): TRegister128;
      begin
        Result.RegLo:=RegLo;
        Result.RegHi:=RegHi;
      end;


    procedure SplitParaLoc128(const CGPara:TCGPara;var CGParaLo,CGParaHi:TCGPara);
      var
        ParaLocLo,
        ParaLocHi : PCGParaLocation;
      begin
        if not(CGPara.Size in [OS_128,OS_S128]) then
          InternalError(2012090604);
        if not Assigned(CGPara.Location) then
          InternalError(2012090605);
        { init lo/hi para }
        CGParaHi.Reset;
        if CGPara.Size=OS_S128 then
          CGParaHi.Size:=OS_S64
        else
          CGParaHi.Size:=OS_64;
        CGParaHi.IntSize:=8;
        CGParaHi.Alignment:=CGPara.Alignment;
        ParaLocHi:=CGParaHi.Add_Location;
        CGParaLo.Reset;
        CGParaLo.Size:=OS_64;
        CGParaLo.IntSize:=8;
        CGParaLo.Alignment:=CGPara.Alignment;
        ParaLocLo:=CGParaLo.Add_Location;
        { 2 parameter fields? }
        if Assigned(CGPara.Location^.Next) then
          begin
            { Order for multiple locations is always
                paraloc^ -> high
                paraloc^.next -> low }
            if (TargetInfo.Endian=ENDIAN_BIG) then
              begin
                { paraloc^ -> high
                  paraloc^.next -> low }
                Move(CGPara.Location^,ParaLocHi^,SizeOf(ParaLocHi^));
                Move(CGPara.Location^.Next^,ParaLocLo^,SizeOf(ParaLocLo^));
              end
            else
              begin
                { paraloc^ -> low
                  paraloc^.next -> high }
                Move(CGPara.Location^,ParaLocLo^,SizeOf(ParaLocLo^));
                Move(CGPara.Location^.Next^,ParaLocHi^,SizeOf(ParaLocHi^));
              end;
          end
        else
          begin
            { single parameter, this can only be in memory }
            if CGPara.Location^.Loc<>LOC_REFERENCE then
              InternalError(2012090606);
            Move(CGPara.Location^,ParaLocLo^,SizeOf(ParaLocLo^));
            Move(CGPara.Location^,ParaLocHi^,SizeOf(ParaLocHi^));
            { for big endian low is at +8, for little endian high }
            if TargetInfo.Endian = endian_big then
              begin
                Inc(CGParaLo.Location^.Reference.Offset,8);
                CGParaLo.Alignment:=NewAlignment(CGParaLo.Alignment,8);
              end
            else
              begin
                Inc(CGParaHi.Location^.Reference.Offset,8);
                CGParaHi.Alignment:=NewAlignment(CGParaHi.Alignment,8);
              end;
          end;
        { fix size }
        ParaLocLo^.Size:=CGParaLo.Size;
        ParaLocLo^.Next:=nil;
        ParaLocHi^.Size:=CGParaHi.Size;
        ParaLocHi^.Next:=nil;
      end;


    procedure TCG128.A_Load128_Reg_Reg(List: TAsmList; RegSrc,
      RegDst: TRegister128);
      begin
        CG.A_Load_Reg_Reg(List,OS_64,OS_64,RegSrc.RegLo,RegDst.RegLo);
        CG.A_Load_Reg_Reg(List,OS_64,OS_64,RegSrc.RegHi,RegDst.RegHi);
      end;


    procedure TCG128.A_Load128_Reg_Ref(List: TAsmList; Reg: TRegister128;
      const Ref: TReference);
      var
        TmpReg: TRegister;
        TmpRef: TReference;
      begin
        if TargetInfo.Endian = endian_big then
          begin
            TmpReg:=Reg.RegLo;
            Reg.RegLo:=Reg.RegHi;
            Reg.RegHi:=TmpReg;
          end;
        CG.A_Load_Reg_Ref(List,OS_64,OS_64,Reg.RegLo,Ref);
        TmpRef := Ref;
        Inc(TmpRef.Offset,8);
        CG.A_Load_Reg_Ref(List,OS_64,OS_64,Reg.RegHi,TmpRef);
      end;


    procedure TCG128.A_Load128_Ref_Reg(List: TAsmList; const Ref: TReference;
      Reg: TRegister128);
      var
        TmpReg: TRegister;
        TmpRef: TReference;
      begin
        if TargetInfo.Endian = endian_big then
          begin
            TmpReg := Reg.RegLo;
            Reg.RegLo := Reg.RegHi;
            Reg.RegHi := TmpReg;
          end;
        TmpRef := Ref;
        if (TmpRef.Base=Reg.RegLo) then
         begin
           TmpReg:=CG.GetAddressRegister(List);
           CG.A_Load_Reg_Reg(List,OS_ADDR,OS_ADDR,TmpRef.Base,TmpReg);
           TmpRef.Base:=TmpReg;
         end
        else
         { this works only for the i386, thus the i386 needs to override  }
         { this method and this method must be replaced by a more generic }
         { implementation FK                                              }
         if (TmpRef.Index=Reg.RegLo) then
          begin
            TmpReg:=CG.GetAddressRegister(List);
            CG.A_Load_Reg_Reg(List,OS_ADDR,OS_ADDR,TmpRef.Index,TmpReg);
            TmpRef.Index:=TmpReg;
          end;
        CG.A_Load_Ref_Reg(List,OS_64,OS_64,TmpRef,Reg.RegLo);
        Inc(TmpRef.Offset,8);
        CG.A_Load_Ref_Reg(List,OS_64,OS_64,TmpRef,Reg.RegHi);
      end;


    procedure TCG128.A_Load128_Loc_Ref(List: TAsmList; const L: TLocation;
      const Ref: TReference);
      begin
        case L.Loc of
          LOC_REGISTER,LOC_CREGISTER:
            A_Load128_Reg_Ref(List,L.Register128,Ref);
          { not yet implemented:
          LOC_CONSTANT :
            a_load128_const_ref(list,l.value128,ref);
          LOC_SUBSETREF, LOC_CSUBSETREF:
            a_load64_subsetref_ref(list,l.sref,ref); }
          else
            InternalError(201209061);
        end;
      end;


    procedure TCG128.A_Load128_Reg_Loc(List: TAsmList; Reg: TRegister128;
      const L: TLocation);
      begin
        case L.Loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            A_Load128_Reg_Ref(List,Reg,L.Reference);
          LOC_REGISTER,LOC_CREGISTER:
            A_Load128_Reg_Reg(List,Reg,L.Register128);
          { not yet implemented:
          LOC_SUBSETREF, LOC_CSUBSETREF:
            a_load64_reg_subsetref(list,reg,l.sref);
          LOC_MMREGISTER, LOC_CMMREGISTER:
            a_loadmm_intreg64_reg(list,l.size,reg,l.register); }
          else
            InternalError(201209062);
        end;
      end;

    procedure TCG128.A_Load128_Const_Reg(List: TAsmList; ValueLo,
     ValueHi: Int64; Reg: TRegister128);
     begin
       CG.A_Load_Const_Reg(List,OS_64,AInt(ValueLo),Reg.RegLo);
       CG.A_Load_Const_Reg(List,OS_64,AInt(ValueHi),Reg.RegHi);
     end;


    procedure TCG128.A_Load128_Loc_CGPara(List: TAsmList; const L: TLocation;
      const ParaLoc: TCGPara);
      begin
        case L.Loc of
          LOC_REGISTER,
          LOC_CREGISTER :
            A_Load128_Reg_CGPara(List,L.Register128,ParaLoc);
          {not yet implemented:
          LOC_CONSTANT :
            a_load128_const_cgpara(list,l.value64,paraloc);
          }
          LOC_CREFERENCE,
          LOC_REFERENCE :
            A_Load128_Ref_CGPara(List,L.Reference,ParaLoc);
          else
            InternalError(2012090603);
        end;
      end;


    procedure TCG128.A_Load128_Reg_CGPara(List : TAsmList;Reg : TRegister128;const ParaLoc : TCGPara);
      var
        TmpLocHi,TmpLocLo: TCGPara;
      begin
        TmpLocLo.Init;
        TmpLocHi.Init;
        SplitParaLoc128(ParaLoc,TmpLocLo,TmpLocHi);
        CG.A_Load_Reg_CGPara(List,OS_64,Reg.RegHi,TmpLocHi);
        CG.A_Load_Reg_CGPara(List,OS_64,Reg.RegLo,TmpLocLo);
        TmpLocLo.Done;
        TmpLocHi.Done;
      end;


    procedure TCG128.A_Load128_Ref_CGPara(List : TAsmList;const R : TReference;const ParaLoc : TCGPara);
      var
        TmpRefHi,TmpRefLo : TReference;
        TmpLocLo,TmpLocHi : TCGPara;
      begin
        TmpLocLo.Init;
        TmpLocHi.Init;
        SplitParaLoc128(ParaLoc,TmpLocLo,TmpLocHi);
        TmpRefHi:=R;
        TmpRefLo:=R;
        if TargetInfo.Endian=endian_big then
          Inc(TmpRefLo.Offset,8)
        else
          Inc(TmpRefHi.Offset,8);
        CG.A_Load_Ref_CGPara(List,OS_64,TmpRefHi,TmpLocHi);
        CG.A_Load_Ref_CGPara(List,OS_64,TmpRefLo,TmpLocLo);
        TmpLocLo.Done;
        TmpLocHi.Done;
      end;
{$endif cpu64bitalu}

    function AsmSym2IndSymFlags(Sym: TAsmSymbol): TIndSymFlags;
      begin
        Result:=[];
        if Sym.Typ<>AT_FUNCTION then
          Include(Result,is_data);
        if Sym.Bind=AB_WEAK_EXTERNAL then
          Include(Result,is_weak);
      end;

    procedure Destroy_CodeGen;
      begin
        CG.Free;
        CG:=nil;
{$ifdef cpu64bitalu}
        CG128.Free;
        CG128:=nil;
{$else cpu64bitalu}
        CG64.Free;
        CG64:=nil;
{$endif cpu64bitalu}
      end;

end.
