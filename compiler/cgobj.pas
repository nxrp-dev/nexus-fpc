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
       cpubase,cgbase,cgutils,parabase,
       aasmbase,aasmtai,AAsmData,aasmcpu,
       symconst,symtype,symdef,rgobj
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
          executionweight : LongInt;
          alignment : TAlignment;
          rg        : array[TRegisterType] of TRGObj;

       {$ifdef flowgraph}
          aktflownode:word;
       {$endif}
          {************************************************}
          {                 basic routines                 }
          constructor create;

          {# Initialize the register allocators needed for the codegenerator.}
          procedure init_register_allocators;virtual;
          {# Clean up the register allocators needed for the codegenerator.}
          procedure done_register_allocators;virtual;
          {# Set whether live_start or live_end should be updated when allocating registers, needed when e.g. generating initcode after the rest of the code. }
          procedure set_regalloc_live_range_direction(dir: TRADirection);

       {$ifdef flowgraph}
          procedure init_flowgraph;
          procedure done_flowgraph;
       {$endif}
          {# Gets a register suitable to do integer operations on.}
          function getintregister(list:TAsmList;size:TCgSize):TRegister;virtual;
          {# Gets a register suitable to do integer operations on.}
          function getaddressregister(list:TAsmList):TRegister;virtual;
          function getfpuregister(list:TAsmList;size:TCgSize):TRegister;virtual;
          function getmmregister(list:TAsmList;size:TCgSize):TRegister;virtual;
          function getflagregister(list:TAsmList;size:TCgSize):TRegister;virtual;
          function gettempregister(list:TAsmList):TRegister;virtual;
          {Does the generic cg need SIMD registers, like getmmxregister? Or should
           the cpu specific child cg object have such a method?}




          procedure add_reg_instruction(instr:TAI;r:TRegister);virtual;
          procedure add_move_instruction(instr:TAICPU);virtual;

          function  uses_registers(rt:TRegisterType):boolean;virtual;
          {# Get a specific register.}
          procedure getcpuregister(list:TAsmList;r:TRegister);virtual;
          procedure ungetcpuregister(list:TAsmList;r:TRegister);virtual;
          {# Get multiple registers specified.}
          procedure alloccpuregisters(list:TAsmList;rt:TRegisterType;const r:TCPURegisterSet);virtual;
          {# Free multiple registers specified.}
          procedure dealloccpuregisters(list:TAsmList;rt:TRegisterType;const r:TCPURegisterSet);virtual;

          procedure allocallcpuregisters(list:TAsmList);virtual;
          procedure deallocallcpuregisters(list:TAsmList);virtual;
          procedure do_register_allocation(list:TAsmList;headertai:TAI);virtual;
          procedure translate_register(var reg : TRegister);

          function makeregsize(list:TAsmList;reg:TRegister;size:TCgSize):TRegister; virtual;

          {# Emit a label to the instruction stream. }
          procedure a_label(list : TAsmList;l : TAsmLabel);virtual;
          {# Emit a label that can be a target of a Pascal goto statement to the instruction stream. }
          procedure a_label_pascal_goto_target(list : TAsmList;l : TAsmLabel);virtual;

          {# Allocates register r by inserting a pai_realloc record }
          procedure a_reg_alloc(list : TAsmList;r : TRegister);
          {# Deallocates register r by inserting a pa_regdealloc record}
          procedure a_reg_dealloc(list : TAsmList;r : TRegister);
          { Synchronize register, make sure it is still valid }
          procedure a_reg_sync(list : TAsmList;r : TRegister);

          {# Pass a parameter, which is located in a register, to a routine.

             This routine should push/send the parameter to the routine, as
             required by the specific processor ABI and routine modifiers.
             It must generate register allocation information for the cgpara in
             case it consists of cpuregisters.

             @param(size size of the operand in the register)
             @param(r register source of the operand)
             @param(cgpara where the parameter will be stored)
          }
          procedure a_load_reg_cgpara(list : TAsmList;size : TCgSize;r : TRegister;const cgpara : TCGPara);virtual;
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
          procedure a_load_const_cgpara(list : TAsmList;size : TCgSize;a : TCGInt;const cgpara : TCGPara);virtual;
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
          procedure a_load_ref_cgpara(list : TAsmList;size : TCgSize;const r : TReference;const cgpara : TCGPara);virtual;
         protected
          procedure a_load_ref_cgparalocref(list: TAsmList; sourcesize: TCgSize; sizeleft: TCGInt; const ref, paralocref: TReference; const cgpara: TCGPara; const location: PCGParaLocation); virtual;
         public
          {# Pass the value of a parameter, which can be located either in a register or memory location,
             to a routine.

             A generic version is provided.

             @param(l location of the operand to send)
             @param(nr parameter number (starting from one) of routine (from left to right))
             @param(cgpara where the parameter will be stored)
          }
          procedure a_load_loc_cgpara(list : TAsmList;const l : TLocation;const cgpara : TCGPara);
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
          procedure a_loadaddr_ref_cgpara(list : TAsmList;const r : TReference;const cgpara : TCGPara);virtual;

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
          procedure a_load_cgparaloc_ref(list : TAsmList;const paraloc : TCGParaLocation;const ref : TReference;sizeleft : TCGInt;align : LongInt);

          {# Load a cgparaloc into any kind of register (int, fp, mm).

           @param(regsize the size of the destination register)
           @param(paraloc the source parameter sublocation)
           @param(reg the destination register)
           @param(align the alignment of the paraloc in case it's a reference)
          }
          procedure a_load_cgparaloc_anyreg(list : TAsmList;regsize : TCgSize;const paraloc : TCGParaLocation;reg : TRegister;align : LongInt);

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
          procedure a_call_name(list : TAsmList;const s : string; weak: boolean);virtual; abstract;
          procedure a_call_reg(list : TAsmList;reg : TRegister);virtual; abstract;
          { same as a_call_name, might be overridden on certain architectures to emit
            static calls without usage of a got trampoline }
          procedure a_call_name_static(list : TAsmList;const s : string);virtual;

          { move instructions }
          procedure a_load_const_reg(list : TAsmList;size : TCgSize;a : TCGInt;register : TRegister);virtual; abstract;
          procedure a_load_const_ref(list : TAsmList;size : TCgSize;a : TCGInt;const ref : TReference);virtual;
          procedure a_load_const_loc(list : TAsmList;a : TCGInt;const loc : TLocation);
          procedure a_load_reg_ref(list : TAsmList;fromsize,tosize : TCgSize;register : TRegister;const ref : TReference);virtual; abstract;
          procedure a_load_reg_ref_unaligned(list : TAsmList;fromsize,tosize : TCgSize;register : TRegister;const ref : TReference);virtual;
          procedure a_load_reg_reg(list : TAsmList;fromsize,tosize : TCgSize;reg1,reg2 : TRegister);virtual; abstract;
          procedure a_load_reg_loc(list : TAsmList;fromsize : TCgSize;reg : TRegister;const loc: TLocation);
          procedure a_load_ref_reg(list : TAsmList;fromsize,tosize : TCgSize;const ref : TReference;register : TRegister);virtual; abstract;
          procedure a_load_ref_reg_unaligned(list : TAsmList;fromsize,tosize : TCgSize;const ref : TReference;register : TRegister);virtual;
          procedure a_load_ref_ref(list : TAsmList;fromsize,tosize : TCgSize;const sref : TReference;const dref : TReference);virtual;
          procedure a_load_loc_reg(list : TAsmList;tosize: TCgSize; const loc: TLocation; reg : TRegister);
          procedure a_load_loc_ref(list : TAsmList;tosize: TCgSize; const loc: TLocation; const ref : TReference);
          procedure a_loadaddr_ref_reg(list : TAsmList;const ref : TReference;r : TRegister);virtual; abstract;

          { bit scan instructions }
          procedure a_bit_scan_reg_reg(list: TAsmList; reverse,not_zero: boolean; srcsize, dstsize: TCgSize; src, dst: TRegister); virtual;

          { Multiplication with doubling result size.
            dstlo or dsthi may be NR_NO, in which case corresponding half of result is discarded. }
          procedure a_mul_reg_reg_pair(list: TAsmList; size: TCgSize; src1,src2,dstlo,dsthi: TRegister);virtual;

          { fpu move instructions }
          procedure a_loadfpu_reg_reg(list: TAsmList; fromsize, tosize:TCgSize; reg1, reg2: TRegister); virtual; abstract;
          procedure a_loadfpu_ref_reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; reg: TRegister); virtual; abstract;
          procedure a_loadfpu_reg_ref(list: TAsmList; fromsize, tosize: TCgSize; reg: TRegister; const ref: TReference); virtual; abstract;
          procedure a_loadfpu_ref_ref(list: TAsmList; fromsize, tosize: TCgSize; const ref1,ref2: TReference);
          procedure a_loadfpu_loc_reg(list: TAsmList; tosize: TCgSize; const loc: TLocation; const reg: TRegister);
          procedure a_loadfpu_reg_loc(list: TAsmList; fromsize: TCgSize; const reg: TRegister; const loc: TLocation);
          procedure a_loadfpu_reg_cgpara(list : TAsmList;size : TCgSize;const r : TRegister;const cgpara : TCGPara);virtual;
          procedure a_loadfpu_ref_cgpara(list : TAsmList;size : TCgSize;const ref : TReference;const cgpara : TCGPara);virtual;

          procedure a_loadfpu_intreg_reg(list: TAsmList; fromsize, tosize : TCgSize; intreg, fpureg: TRegister); virtual;
          procedure a_loadfpu_reg_intreg(list: TAsmList; fromsize, tosize: TCgSize; fpureg, intreg: TRegister); virtual;

          { vector register move instructions }
          procedure a_loadmm_reg_reg(list: TAsmList; fromsize, tosize : TCgSize;reg1, reg2: TRegister;shuffle : PMMShuffle); virtual;
          procedure a_loadmm_ref_reg(list: TAsmList; fromsize, tosize : TCgSize;const ref: TReference; reg: TRegister;shuffle : PMMShuffle); virtual;
          procedure a_loadmm_reg_ref(list: TAsmList; fromsize, tosize : TCgSize;reg: TRegister; const ref: TReference;shuffle : PMMShuffle); virtual;
          procedure a_loadmm_loc_reg(list: TAsmList; size: TCgSize; const loc: TLocation; const reg: TRegister;shuffle : PMMShuffle);
          procedure a_loadmm_reg_loc(list: TAsmList; size: TCgSize; const reg: TRegister; const loc: TLocation;shuffle : PMMShuffle);
          procedure a_loadmm_reg_cgpara(list: TAsmList; size: TCgSize; reg: TRegister;const cgpara : TCGPara;shuffle : PMMShuffle); virtual;
          procedure a_loadmm_ref_cgpara(list: TAsmList; size: TCgSize; const ref: TReference;const cgpara : TCGPara;shuffle : PMMShuffle); virtual;
          procedure a_loadmm_loc_cgpara(list: TAsmList; const loc: TLocation; const cgpara : TCGPara;shuffle : PMMShuffle); virtual;
          procedure a_opmm_reg_reg(list: TAsmList; Op: TOpCG; size : TCgSize;src,dst: TRegister;shuffle : PMMShuffle); virtual;
          procedure a_opmm_ref_reg(list: TAsmList; Op: TOpCG; size : TCgSize;const ref: TReference; reg: TRegister;shuffle : PMMShuffle); virtual;
          procedure a_opmm_loc_reg(list: TAsmList; Op: TOpCG; size : TCgSize;const loc: TLocation; reg: TRegister;shuffle : PMMShuffle); virtual;
          procedure a_opmm_reg_ref(list: TAsmList; Op: TOpCG; size : TCgSize;reg: TRegister;const ref: TReference; shuffle : PMMShuffle); virtual;
          procedure a_opmm_loc_reg_reg(list: TAsmList;Op : TOpCG;size : TCgSize;const loc : TLocation;src,dst : TRegister;shuffle : PMMShuffle); virtual;
          procedure a_opmm_reg_reg_reg(list: TAsmList; Op: TOpCG; size : TCgSize;src1,src2,dst: TRegister;shuffle : PMMShuffle); virtual;
          procedure a_opmm_ref_reg_reg(list: TAsmList; Op: TOpCG; size : TCgSize;const ref: TReference; src,dst: TRegister;shuffle : PMMShuffle); virtual;

          procedure a_loadmm_intreg_reg(list: TAsmList; fromsize, tosize : TCgSize; intreg, mmreg: TRegister; shuffle: PMMShuffle); virtual;
          procedure a_loadmm_reg_intreg(list: TAsmList; fromsize, tosize : TCgSize; mmreg, intreg: TRegister; shuffle : PMMShuffle); virtual;

          { basic arithmetic operations }
          procedure a_op_const_reg(list : TAsmList; Op: TOpCG; size: TCgSize; a: TCGInt; reg: TRegister); virtual; abstract;
          procedure a_op_const_ref(list : TAsmList; Op: TOpCG; size: TCgSize; a: TCGInt; const ref: TReference); virtual;
          procedure a_op_const_loc(list : TAsmList; Op: TOpCG; a: TCGInt; const loc: TLocation);
          procedure a_op_reg_reg(list : TAsmList; Op: TOpCG; size: TCgSize; reg1, reg2: TRegister); virtual; abstract;
          procedure a_op_reg_ref(list : TAsmList; Op: TOpCG; size: TCgSize; reg: TRegister; const ref: TReference); virtual;
          procedure a_op_ref_reg(list : TAsmList; Op: TOpCG; size: TCgSize; const ref: TReference; reg: TRegister); virtual;
          procedure a_op_reg_loc(list : TAsmList; Op: TOpCG; reg: TRegister; const loc: TLocation);
          procedure a_op_loc_reg(list : TAsmList; Op: TOpCG; size: TCgSize; const loc: TLocation; reg: TRegister);
          procedure a_op_ref_loc(list : TAsmList; Op: TOpCG; const ref: TReference; const loc: TLocation);

          { trinary operations for processors that support them, 'emulated' }
          { on others. None with "ref" arguments since I don't think there  }
          { are any processors that support it (JM)                         }
          procedure a_op_const_reg_reg(list: TAsmList; op: TOpCG; size: TCgSize; a: TCGInt; src, dst: TRegister); virtual;
          procedure a_op_reg_reg_reg(list: TAsmList; op: TOpCG; size: TCgSize; src1, src2, dst: TRegister); virtual;
          procedure a_op_const_reg_reg_checkoverflow(list: TAsmList; op: TOpCG; size: TCgSize; a: TCGInt; src, dst: TRegister;setflags : boolean;var ovloc : TLocation); virtual;
          procedure a_op_reg_reg_reg_checkoverflow(list: TAsmList; op: TOpCG; size: TCgSize; src1, src2, dst: TRegister;setflags : boolean;var ovloc : TLocation); virtual;

          { unary operations (not, neg) }
          procedure a_op_reg(list : TAsmList; Op: TOpCG; size: TCgSize; reg: TRegister); virtual;
          procedure a_op_ref(list : TAsmList; Op: TOpCG; size: TCgSize; const ref: TReference); virtual;
          procedure a_op_loc(list : TAsmList; Op: TOpCG; const loc: TLocation);

          {  comparison operations }
          procedure a_cmp_const_reg_label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;a : TCGInt;reg : TRegister;
            l : TAsmLabel); virtual;
          procedure a_cmp_const_ref_label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;a : TCGInt;const ref : TReference;
            l : TAsmLabel); virtual;
          procedure a_cmp_const_loc_label(list: TAsmList; size: TCgSize;cmp_op: TOpCmp; a: TCGInt; const loc: TLocation;
            l : TAsmLabel);
          procedure a_cmp_reg_reg_label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;reg1,reg2 : TRegister;l : TAsmLabel); virtual; abstract;
          procedure a_cmp_ref_reg_label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp; const ref: TReference; reg : TRegister; l : TAsmLabel); virtual;
          procedure a_cmp_reg_ref_label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;reg : TRegister; const ref: TReference; l : TAsmLabel); virtual;

          procedure a_cmp_loc_reg_label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp; const loc: TLocation; reg : TRegister; l : TAsmLabel);
          procedure a_cmp_reg_loc_label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp; reg: TRegister; const loc: TLocation; l : TAsmLabel);
          procedure a_cmp_ref_loc_label(list: TAsmList; size: TCgSize;cmp_op: TOpCmp; const ref: TReference; const loc: TLocation;
            l : TAsmLabel);

          procedure a_jmp_name(list : TAsmList;const s : string); virtual; abstract;
          procedure a_jmp_always(list : TAsmList;l: TAsmLabel); virtual; abstract;
{$ifdef cpuflags}
          procedure a_jmp_flags(list : TAsmList;const f : TResFlags;l: TAsmLabel); virtual; abstract;

          {# Depending on the value to check in the flags, either sets the register reg to one (if the flag is set)
             or zero (if the flag is cleared). The size parameter indicates the destination size register.
          }
          procedure g_flags2reg(list: TAsmList; size: TCgSize; const f: TResFlags; reg: TRegister); virtual; abstract;
          procedure g_flags2ref(list: TAsmList; size: TCgSize; const f: TResFlags; const ref:TReference); virtual;
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
          procedure optimize_op_const(size: TCgSize; var op: TOpCG; var a : TCGInt);virtual;


          {# This emits code to copy len bytes from the source using the move procedure

             @param(source Source reference of copy)
             @param(dest Destination reference of copy)

          }
          procedure g_concatcopy_move(list : TAsmList;const source,dest : TReference;len : TCGInt);virtual;

          {# This should emit the opcode to copy len bytes from the source
             to destination.

             It must be overridden for each new target processor.

             @param(source Source reference of copy)
             @param(dest Destination reference of copy)

          }
          procedure g_concatcopy(list : TAsmList;const source,dest : TReference;len : TCGInt);virtual; abstract;
          {# This should emit the opcode to copy len bytes from the an unaligned source
             to destination.

             It must be overridden for each new target processor.

             @param(source Source reference of copy)
             @param(dest Destination reference of copy)

          }
          procedure g_concatcopy_unaligned(list : TAsmList;const source,dest : TReference;len : TCGInt);virtual;

          {# Generates overflow checking code for a node }
          procedure g_overflowcheck(list: TAsmList; const Loc:TLocation; def:TDef); virtual;abstract;
          procedure g_overflowCheck_loc(List:TAsmList;const Loc:TLocation;def:TDef;ovloc : TLocation);virtual;

          {# Emits instruction for allocating @var(size) bytes at the stackpointer

             @param(size Number of bytes to allocate)
          }
          procedure g_stackpointer_alloc(list : TAsmList;size : LongInt);virtual;
          {# Emits instruction for allocating the locals in entry
             code of a routine. This is one of the first
             routine called in @var(genentrycode).

             @param(localsize Number of bytes to allocate as locals)
          }
          procedure g_proc_entry(list : TAsmList;localsize : LongInt;nostackframe:boolean);virtual; abstract;
          {# Emits instructions for returning from a subroutine.
             Should also restore the framepointer and stack.

             @param(parasize  Number of bytes of parameters to deallocate from stack)
          }
          procedure g_proc_exit(list : TAsmList;parasize:LongInt;nostackframe:boolean);virtual;abstract;
          {# This routine is called when generating the code for the entry point
             of a routine. It should save all registers which are not used in this
             routine, and which should be declared as saved in the std_saved_registers
             set.

             This routine is mainly used when linking to code which is generated
             by ABI-compliant compilers (like GCC), to make sure that the reserved
             registers of that ABI are not clobbered.

             @param(usedinproc Registers which are used in the code of this routine)
          }
          procedure g_save_registers(list:TAsmList);virtual;
          {# This routine is called when generating the code for the exit point
             of a routine. It should restore all registers which were previously
             saved in @var(g_save_standard_registers).

             @param(usedinproc Registers which are used in the code of this routine)
          }
          procedure g_restore_registers(list:TAsmList);virtual;

          procedure g_adjust_self_value(list:TAsmList;procdef: TProcDef;ioffset: TCGInt);virtual;

          { initialize the pic/got register }
          procedure g_maybe_got_init(list: TAsmList); virtual;
          { initialize the tls register if needed }
          procedure g_maybe_tls_init(list : TAsmList); virtual;
          { allocallcpuregisters, a_call_name, deallocallcpuregisters sequence }
          procedure g_call(list: TAsmList; const s: string);
          { Generate code to exit an unwind-protected region. The default implementation
            produces a simple jump to destination label. }
          procedure g_local_unwind(list: TAsmList; l: TAsmLabel);virtual;
          { Generate code for integer division by constant,
            generic version is suitable for 3-address CPUs }
          procedure g_div_const_reg_reg(list:TAsmList; size: TCgSize; a: TCGInt; src,dst: TRegister); virtual;

          { some CPUs do not support hardware fpu exceptions, this procedure is called after instructions which
            might set FPU exception related flags, so it has to check these flags if needed and throw an exeception }
          procedure g_check_for_fpu_exception(list : TAsmList; force,clear : boolean); virtual;
          procedure maybe_check_for_fpu_exception(list: TAsmList);

          { Called to adjust references in exceptfilter handlers. Override
            in CPU-specific code generator for platforms that need special handling
            (e.g., AArch64-Win64 where SP-relative references must be converted to FP-relative).
            Set for_finalization=true when called during finalization of parent's temps
            for an exceptfilter (current_procinfo is parent, finalize_procinfo is exceptfilter). }
          procedure adjust_exceptfilter_ref(var ref: TReference; for_finalization: boolean); virtual;

         protected
          function g_indirect_sym_load(list:TAsmList;const symname: string; const flags: TIndSymFlags): TRegister;virtual;
       end;

{$ifdef cpu64bitalu}
    {  This class implements an abstract code generator class
       for 128 Bit operations, it applies currently only to 64 Bit CPUs and supports only simple operations
    }
    TCG128 = class
        procedure a_load128_reg_reg(list : TAsmList;regsrc,regdst : TRegister128);virtual;
        procedure a_load128_reg_ref(list : TAsmList;reg : TRegister128;const ref : TReference);virtual;
        procedure a_load128_ref_reg(list : TAsmList;const ref : TReference;reg : TRegister128);virtual;
        procedure a_load128_loc_ref(list : TAsmList;const l : TLocation;const ref : TReference);virtual;
        procedure a_load128_reg_loc(list : TAsmList;reg : TRegister128;const l : TLocation);virtual;
        procedure a_load128_const_reg(list : TAsmList;valuelo,valuehi : int64;reg : TRegister128);virtual;

        procedure a_load128_loc_cgpara(list : TAsmList;const l : TLocation;const paraloc : TCGPara);virtual;
        procedure a_load128_ref_cgpara(list: TAsmList; const r: TReference;const paraloc: TCGPara);
        procedure a_load128_reg_cgpara(list: TAsmList; reg: TRegister128;const paraloc: TCGPara);
    end;

    { Creates a tregister128 record from 2 64 Bit registers. }
    function joinreg128(reglo,reghi : TRegister) : TRegister128;

{$else cpu64bitalu}
    {# @abstract(Abstract code generator for 64 Bit operations)
       This class implements an abstract code generator class
       for 64 Bit operations.
    }
    TCG64 = class
        procedure a_load64_const_ref(list : TAsmList;value : int64;const ref : TReference);virtual;abstract;
        procedure a_load64_reg_ref(list : TAsmList;reg : TRegister64;const ref : TReference);virtual;abstract;
        procedure a_load64_ref_reg(list : TAsmList;const ref : TReference;reg : TRegister64);virtual;abstract;
        procedure a_load64_reg_reg(list : TAsmList;regsrc,regdst : TRegister64);virtual;abstract;
        procedure a_load64_const_reg(list : TAsmList;value : int64;reg : TRegister64);virtual;abstract;
        procedure a_load64_loc_reg(list : TAsmList;const l : TLocation;reg : TRegister64);virtual;abstract;
        procedure a_load64_loc_ref(list : TAsmList;const l : TLocation;const ref : TReference);virtual;abstract;
        procedure a_load64_const_loc(list : TAsmList;value : int64;const l : TLocation);virtual;abstract;
        procedure a_load64_reg_loc(list : TAsmList;reg : TRegister64;const l : TLocation);virtual;abstract;

        procedure a_load64_subsetref_reg(list : TAsmList; const sref: TSubsetReference; destreg: TRegister64);virtual;abstract;
        procedure a_load64_reg_subsetref(list : TAsmList; fromreg: TRegister64; const sref: TSubsetReference);virtual;abstract;
        procedure a_load64_const_subsetref(list: TAsmList; a: int64; const sref: TSubsetReference);virtual;abstract;
        procedure a_load64_ref_subsetref(list : TAsmList; const fromref: TReference; const sref: TSubsetReference);virtual;abstract;
        procedure a_load64_subsetref_subsetref(list: TAsmList; const fromsref, tosref: TSubsetReference); virtual;abstract;
        procedure a_load64_subsetref_ref(list : TAsmList; const sref: TSubsetReference; const destref: TReference); virtual;abstract;
        procedure a_load64_loc_subsetref(list : TAsmList; const l: TLocation; const sref : TSubsetReference);
        procedure a_load64_subsetref_loc(list: TAsmList; const sref: TSubsetReference; const l: TLocation);

        procedure a_load64high_reg_ref(list : TAsmList;reg : TRegister;const ref : TReference);virtual;abstract;
        procedure a_load64low_reg_ref(list : TAsmList;reg : TRegister;const ref : TReference);virtual;abstract;
        procedure a_load64high_ref_reg(list : TAsmList;const ref : TReference;reg : TRegister);virtual;abstract;
        procedure a_load64low_ref_reg(list : TAsmList;const ref : TReference;reg : TRegister);virtual;abstract;
        procedure a_load64high_loc_reg(list : TAsmList;const l : TLocation;reg : TRegister);virtual;abstract;
        procedure a_load64low_loc_reg(list : TAsmList;const l : TLocation;reg : TRegister);virtual;abstract;

        procedure a_op64_ref_reg(list : TAsmList;op:TOpCG;size : TCgSize;const ref : TReference;reg : TRegister64);virtual;abstract;
        procedure a_op64_reg_reg(list : TAsmList;op:TOpCG;size : TCgSize;regsrc,regdst : TRegister64);virtual;abstract;
        procedure a_op64_reg_ref(list : TAsmList;op:TOpCG;size : TCgSize;regsrc : TRegister64;const ref : TReference);virtual;abstract;
        procedure a_op64_const_reg(list : TAsmList;op:TOpCG;size : TCgSize;value : int64;regdst : TRegister64);virtual;abstract;
        procedure a_op64_const_ref(list : TAsmList;op:TOpCG;size : TCgSize;value : int64;const ref : TReference);virtual;abstract;
        procedure a_op64_const_loc(list : TAsmList;op:TOpCG;size : TCgSize;value : int64;const l: TLocation);virtual;abstract;
        procedure a_op64_reg_loc(list : TAsmList;op:TOpCG;size : TCgSize;reg : TRegister64;const l : TLocation);virtual;abstract;
        procedure a_op64_ref_loc(list : TAsmList;op:TOpCG;size : TCgSize;const ref : TReference;const l : TLocation);virtual;abstract;
        procedure a_op64_loc_reg(list : TAsmList;op:TOpCG;size : TCgSize;const l : TLocation;reg64 : TRegister64);virtual;abstract;
        procedure a_op64_const_reg_reg(list: TAsmList;op:TOpCG;size : TCgSize;value : int64;regsrc,regdst : TRegister64);virtual;
        procedure a_op64_reg_reg_reg(list: TAsmList;op:TOpCG;size : TCgSize;regsrc1,regsrc2,regdst : TRegister64);virtual;
        procedure a_op64_const_reg_reg_checkoverflow(list: TAsmList;op:TOpCG;size : TCgSize;value : int64;regsrc,regdst : TRegister64;setflags : boolean;var ovloc : TLocation);virtual;
        procedure a_op64_reg_reg_reg_checkoverflow(list: TAsmList;op:TOpCG;size : TCgSize;regsrc1,regsrc2,regdst : TRegister64;setflags : boolean;var ovloc : TLocation);virtual;
        procedure a_op64_reg(list : TAsmList;op:TOpCG;size : TCgSize;regdst : TRegister64);virtual;
        procedure a_op64_ref(list : TAsmList;op:TOpCG;size : TCgSize;const ref : TReference);virtual;
        procedure a_op64_loc(list : TAsmList;op:TOpCG;size : TCgSize;const l : TLocation);virtual;

        procedure a_op64_const_subsetref(list : TAsmList; Op : TOpCG; size : TCgSize; a : int64; const sref: TSubsetReference);
        procedure a_op64_reg_subsetref(list : TAsmList; Op : TOpCG; size : TCgSize; reg: TRegister64; const sref: TSubsetReference);
        procedure a_op64_ref_subsetref(list : TAsmList; Op : TOpCG; size : TCgSize; const ref: TReference; const sref: TSubsetReference);
        procedure a_op64_subsetref_subsetref(list : TAsmList; Op : TOpCG; size : TCgSize; const ssref,dsref: TSubsetReference);

        procedure a_load64_reg_cgpara(list : TAsmList;reg64 : TRegister64;const loc : TCGPara);virtual;abstract;
        procedure a_load64_const_cgpara(list : TAsmList;value : int64;const loc : TCGPara);virtual;abstract;
        procedure a_load64_ref_cgpara(list : TAsmList;const r : TReference;const loc : TCGPara);virtual;abstract;
        procedure a_load64_loc_cgpara(list : TAsmList;const l : TLocation;const loc : TCGPara);virtual;abstract;

        procedure a_loadmm_intreg64_reg(list: TAsmList; mmsize: TCgSize; intreg: TRegister64; mmreg: TRegister); virtual;abstract;
        procedure a_loadmm_reg_intreg64(list: TAsmList; mmsize: TCgSize; mmreg: TRegister; intreg: TRegister64); virtual;abstract;
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
        function optimize64_op_const_reg(list: TAsmList; var op: TOpCG; var a : int64; var reg: TRegister64): boolean;virtual;abstract;


        { override to catch 64bit rangechecks }
        procedure g_rangecheck64(list: TAsmList; const l:TLocation; fromdef,todef: TDef);virtual;abstract;
    end;

    { Creates a tregister64 record from 2 32 Bit registers. }
    function joinreg64(reglo,reghi : TRegister) : TRegister64;
{$endif cpu64bitalu}

    var
       { Main code generator class }
       cg : TCG;
{$ifdef cpu64bitalu}
       { Code generator class for all operations working with 128-Bit operands }
       cg128 : TCG128;
{$else cpu64bitalu}
       { Code generator class for all operations working with 64-Bit operands }
       cg64 : TCG64;
{$endif cpu64bitalu}

    function asmsym2indsymflags(sym: TAsmSymbol): TIndSymFlags;

    procedure destroy_codegen;

implementation

    uses
       Globals,Systems,FModule,
       Verbose,paramgr,SymSym,SymTable,
       tgobj,CUtils,ProcInfo,
       CPUInfo;

{*****************************************************************************
                            basic functionality
******************************************************************************}

    constructor TCG.create;
      begin
      end;


{*****************************************************************************
                                register allocation
******************************************************************************}


    procedure TCG.init_register_allocators;
      begin

        fillchar(rg,sizeof(rg),0);
        add_reg_instruction_hook:=@add_reg_instruction;
        executionweight:=100;
      end;


    procedure TCG.done_register_allocators;
      begin
        { Safety }
        fillchar(rg,sizeof(rg),0);
        add_reg_instruction_hook:=nil;

      end;

    {$ifdef flowgraph}
    procedure TCG.init_flowgraph;

    begin
      aktflownode:=0;
    end;

    procedure TCG.done_flowgraph;

    begin
    end;
    {$endif}

    function TCG.getintregister(list:TAsmList;size:TCgSize):TRegister;

      begin
        if not Assigned(rg[R_INTREGISTER]) then
          InternalError(200312122);
{$if defined(cpu32bitalu) or defined(cpu64bitalu)}
        result:=rg[R_INTREGISTER].getregister(list,cgsize2subreg(R_INTREGISTER,size));
{$endif}
      end;


    function TCG.getfpuregister(list:TAsmList;size:TCgSize):TRegister;
      begin
        if not Assigned(rg[R_FPUREGISTER]) then
          InternalError(200312123);
        result:=rg[R_FPUREGISTER].getregister(list,cgsize2subreg(R_FPUREGISTER,size));
      end;


    function TCG.getmmregister(list:TAsmList;size:TCgSize):TRegister;
      begin
        if not Assigned(rg[R_MMREGISTER]) then
          InternalError(2003121214);
        result:=rg[R_MMREGISTER].getregister(list,cgsize2subreg(R_MMREGISTER,size));
      end;


    function TCG.getaddressregister(list:TAsmList):TRegister;
      begin
        if Assigned(rg[R_ADDRESSREGISTER]) then
          result:=rg[R_ADDRESSREGISTER].getregister(list,R_SUBWHOLE)
        else
          begin
            if not Assigned(rg[R_INTREGISTER]) then
              InternalError(200312121);
            result:=rg[R_INTREGISTER].getregister(list,R_SUBWHOLE);
          end;
      end;


    function TCG.gettempregister(list: TAsmList): TRegister;
      begin
        result:=rg[R_TEMPREGISTER].getregister(list,R_SUBWHOLE);
      end;





    function TCG.makeregsize(list:TAsmList;reg:TRegister;size:TCgSize):TRegister;
      var
        subreg:TSubRegister;
      begin
        subreg:=cgsize2subreg(getregtype(reg),size);
        result:=reg;
        setsubreg(result,subreg);
        { notify RA }
        if result<>reg then
          list.concat(TAIRegAlloc.resize(result));
      end;


    procedure TCG.getcpuregister(list:TAsmList;r:TRegister);
      begin
        if not Assigned(rg[getregtype(r)]) then
          InternalError(200312125);
        rg[getregtype(r)].getcpuregister(list,r);
      end;


    procedure TCG.ungetcpuregister(list:TAsmList;r:TRegister);
      begin
        if not Assigned(rg[getregtype(r)]) then
          InternalError(200312126);
        rg[getregtype(r)].ungetcpuregister(list,r);
      end;


    procedure TCG.alloccpuregisters(list:TAsmList;rt:TRegisterType;const r:TCPURegisterSet);
      begin
        if Assigned(rg[rt]) then
          rg[rt].alloccpuregisters(list,r)
        else
          InternalError(200310092);
      end;


    procedure TCG.allocallcpuregisters(list:TAsmList);
      begin
        alloccpuregisters(list,R_INTREGISTER,paramanager.get_volatile_registers_int(pocall_default));
        if uses_registers(R_ADDRESSREGISTER) then
          alloccpuregisters(list,R_ADDRESSREGISTER,paramanager.get_volatile_registers_address(pocall_default));
{$if not(defined(i386))}
        if uses_registers(R_FPUREGISTER) then
          alloccpuregisters(list,R_FPUREGISTER,paramanager.get_volatile_registers_fpu(pocall_default));
{$ifdef cpumm}
        if uses_registers(R_MMREGISTER) then
          alloccpuregisters(list,R_MMREGISTER,paramanager.get_volatile_registers_mm(pocall_default));
{$endif cpumm}
{$endif not(defined(i386))}
      end;


    procedure TCG.dealloccpuregisters(list:TAsmList;rt:TRegisterType;const r:TCPURegisterSet);
      begin
        if Assigned(rg[rt]) then
          rg[rt].dealloccpuregisters(list,r)
        else
          InternalError(200310093);
      end;


    procedure TCG.deallocallcpuregisters(list:TAsmList);
      begin
        dealloccpuregisters(list,R_INTREGISTER,paramanager.get_volatile_registers_int(pocall_default));
        if uses_registers(R_ADDRESSREGISTER) then
          dealloccpuregisters(list,R_ADDRESSREGISTER,paramanager.get_volatile_registers_address(pocall_default));
{$if not(defined(i386))}
        if uses_registers(R_FPUREGISTER) then
          dealloccpuregisters(list,R_FPUREGISTER,paramanager.get_volatile_registers_fpu(pocall_default));
{$ifdef cpumm}
        if uses_registers(R_MMREGISTER) then
          dealloccpuregisters(list,R_MMREGISTER,paramanager.get_volatile_registers_mm(pocall_default));
{$endif cpumm}
{$endif not(defined(i386))}
      end;


    function TCG.uses_registers(rt:TRegisterType):boolean;
      begin
        if Assigned(rg[rt]) then
          result:=rg[rt].uses_registers
        else
          result:=false;
      end;


    procedure TCG.add_reg_instruction(instr:TAI;r:TRegister);
      var
        rt : TRegisterType;
      begin
        rt:=getregtype(r);
        { Only add it when a register allocator is configured.
          No IE can be generated, because the VMT is written
          without a valid rg[] }
        if Assigned(rg[rt]) then
          rg[rt].add_reg_instruction(instr,r,executionweight);
      end;


    procedure TCG.add_move_instruction(instr:TAICPU);
      var
        rt : TRegisterType;
      begin
        rt:=getregtype(instr.oper[O_MOV_SOURCE]^.reg);
        if Assigned(rg[rt]) then
          rg[rt].add_move_instruction(instr)
        else
          InternalError(200310095);
      end;


    procedure TCG.set_regalloc_live_range_direction(dir: TRADirection);
      var
        rt : TRegisterType;
      begin
        for rt:=low(rg) to high(rg) do
          begin
            if Assigned(rg[rt]) then
              rg[rt].live_range_direction:=dir;
          end;
      end;


    procedure TCG.do_register_allocation(list:TAsmList;headertai:TAI);
      var
        rt : TRegisterType;
      begin
        for rt:=R_FPUREGISTER to R_SPECIALREGISTER do
          begin
            if Assigned(rg[rt]) then
              rg[rt].do_register_allocation(list,headertai);
          end;
         { running the other register allocator passes could require addition int/addr. registers
           when spilling so run int/addr register allocation at the end }
         if Assigned(rg[R_INTREGISTER]) then
           rg[R_INTREGISTER].do_register_allocation(list,headertai);
         if Assigned(rg[R_ADDRESSREGISTER]) then
           rg[R_ADDRESSREGISTER].do_register_allocation(list,headertai);
      end;


    procedure TCG.translate_register(var reg : TRegister);
      var
        rt: TRegisterType;
      begin
        { Getting here without assigned rg is possible for an "assembler nostackframe"
          function returning x87 float, compiler tries to translate NR_ST which is used for
          result.  }
        rt:=getregtype(reg);
        if Assigned(rg[rt]) then
          rg[rt].translate_register(reg);
      end;


    procedure TCG.a_reg_alloc(list : TAsmList;r : TRegister);
      begin
         list.concat(TAIRegAlloc.alloc(r,nil));
      end;


    procedure TCG.a_reg_dealloc(list : TAsmList;r : TRegister);
      begin
        if (r<>NR_NO) then
          list.concat(TAIRegAlloc.dealloc(r,nil));
      end;


    procedure TCG.a_reg_sync(list : TAsmList;r : TRegister);
      var
        instr : TAI;
      begin
        instr:=TAIRegAlloc.sync(r);
        list.concat(instr);
        add_reg_instruction(instr,r);
      end;


    procedure TCG.a_label(list : TAsmList;l : TAsmLabel);
      begin
         list.concat(TAILabel.create(l));
      end;


    procedure TCG.a_label_pascal_goto_target(list : TAsmList;l : TAsmLabel);
      begin
        a_label(list,l);
      end;


{*****************************************************************************
          for better code generation these methods should be overridden
******************************************************************************}

    procedure TCG.a_load_reg_cgpara(list : TAsmList;size : TCgSize;r : TRegister;const cgpara : TCGPara);
      var
         ref : TReference;
         tmpreg : TRegister;
      begin
         if Assigned(cgpara.location^.next) then
           begin
             tg.gethltemp(list,cgpara.def,cgpara.def.size,tt_persistent,ref);
             a_load_reg_ref(list,size,size,r,ref);
             a_load_ref_cgpara(list,size,ref,cgpara);
             tg.ungettemp(list,ref);
             exit;
           end;
         paramanager.alloccgpara(list,cgpara);
         if cgpara.location^.shiftval<0 then
           begin
             tmpreg:=getintregister(list,cgpara.location^.size);
             a_op_const_reg_reg(list,OP_SHL,cgpara.location^.size,-cgpara.location^.shiftval,r,tmpreg);
             r:=tmpreg;
           end;
         case cgpara.location^.loc of
            LOC_REGISTER,LOC_CREGISTER:
              a_load_reg_reg(list,size,cgpara.location^.size,r,cgpara.location^.register);
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                 reference_reset_base(ref,cgpara.location^.reference.index,cgpara.location^.reference.offset,ctempposinvalid,cgpara.alignment,[]);
                 a_load_reg_ref(list,size,cgpara.location^.size,r,ref);
              end;
            LOC_MMREGISTER,LOC_CMMREGISTER:
              a_loadmm_intreg_reg(list,size,cgpara.location^.size,r,cgpara.location^.register,mms_movescalar);
            LOC_FPUREGISTER,LOC_CFPUREGISTER:
              begin
                tg.GetTemp(list,TCGSize2Size[size],TCGSize2Size[size],tt_normal,ref);
                a_load_reg_ref(list,size,size,r,ref);
                a_loadfpu_ref_cgpara(list,cgpara.location^.size,ref,cgpara);
                tg.Ungettemp(list,ref);
              end
            else
              InternalError(2002071004);
         end;
      end;


    procedure TCG.a_load_const_cgpara(list : TAsmList;size : TCgSize;a : TCGInt;const cgpara : TCGPara);
      var
         ref : TReference;
      begin
         cgpara.check_simple_location;
         paramanager.alloccgpara(list,cgpara);
         if cgpara.location^.shiftval<0 then
           a:=a shl -cgpara.location^.shiftval;
         case cgpara.location^.loc of
            LOC_REGISTER,LOC_CREGISTER:
              a_load_const_reg(list,cgpara.location^.size,a,cgpara.location^.register);
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                 reference_reset_base(ref,cgpara.location^.reference.index,cgpara.location^.reference.offset,ctempposinvalid,cgpara.alignment,[]);
                 a_load_const_ref(list,cgpara.location^.size,a,ref);
              end
            else
              InternalError(2010053109);
         end;
      end;


    procedure TCG.a_load_ref_cgpara(list : TAsmList;size : TCgSize;const r : TReference;const cgpara : TCGPara);
      var
        tmpref, ref: TReference;
        tmpreg: TRegister;
        location: PCGParaLocation;
        orgsizeleft,
        sizeleft: TCGInt;
        usesize: TCgSize;
        reghasvalue: boolean;
      begin
        location:=cgpara.location;
        tmpref:=r;
        sizeleft:=cgpara.intsize;
        repeat
          paramanager.allocparaloc(list,location);
          case location^.loc of
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
                 if (size<>OS_NO) and
                    (tcgsize2size[size]<=sizeof(aint)) then
                   begin
                     cgpara.check_simple_location;
                     a_load_ref_reg(list,size,location^.size,tmpref,location^.register);
                     if location^.shiftval<0 then
                       a_op_const_reg(list,OP_SHL,location^.size,-location^.shiftval,location^.register);
                   end
                 { there's a lot more data left, and the current paraloc's
                   register is entirely filled with part of that data }
                 else if (sizeleft>sizeof(aint)) then
                   begin
                     a_load_ref_reg(list,location^.size,location^.size,tmpref,location^.register);
                   end
                 { we're at the end of the data, and it can be loaded into
                   the current location's register with a single regular
                   load }
                 else if sizeleft in [1,2,4,8] then
                   begin
                     a_load_ref_reg(list,int_cgsize(sizeleft),location^.size,tmpref,location^.register);
                     if location^.shiftval<0 then
                       a_op_const_reg(list,OP_SHL,location^.size,-location^.shiftval,location^.register);
                   end
                 { we're at the end of the data, and we need multiple loads
                   to get it in the register because it's an irregular size }
                 else
                   begin
                     { should be the last part }
                     if Assigned(location^.next) then
                       InternalError(2010052907);
                     { load the value piecewise to get it into the register }
                     orgsizeleft:=sizeleft;
                     reghasvalue:=false;
{$ifdef cpu64bitalu}
                     if sizeleft>=4 then
                       begin
                         a_load_ref_reg(list,OS_32,location^.size,tmpref,location^.register);
                         dec(sizeleft,4);
                         if TargetInfo.endian=endian_big then
                           a_op_const_reg(list,OP_SHL,location^.size,sizeleft*8,location^.register);
                         inc(tmpref.offset,4);
                         reghasvalue:=true;
                       end;
{$endif cpu64bitalu}
                     if sizeleft>=2 then
                       begin
                         tmpreg:=getintregister(list,location^.size);
                         a_load_ref_reg(list,OS_16,location^.size,tmpref,tmpreg);
                         dec(sizeleft,2);
                         if reghasvalue then
                           begin
                             if TargetInfo.endian=endian_big then
                               a_op_const_reg(list,OP_SHL,location^.size,sizeleft*8,tmpreg)
                             else
                               a_op_const_reg(list,OP_SHL,location^.size,(orgsizeleft-(sizeleft+2))*8,tmpreg);
                             a_op_reg_reg(list,OP_OR,location^.size,tmpreg,location^.register);
                           end
                         else
                           begin
                             if TargetInfo.endian=endian_big then
                               a_op_const_reg_reg(list,OP_SHL,location^.size,sizeleft*8,tmpreg,location^.register)
                             else
                               a_load_reg_reg(list,location^.size,location^.size,tmpreg,location^.register);
                           end;
                         inc(tmpref.offset,2);
                         reghasvalue:=true;
                       end;
                     if sizeleft=1 then
                       begin
                         tmpreg:=getintregister(list,location^.size);
                         a_load_ref_reg(list,OS_8,location^.size,tmpref,tmpreg);
                         dec(sizeleft,1);
                         if reghasvalue then
                           begin
                             if TargetInfo.endian=endian_little then
                               a_op_const_reg(list,OP_SHL,location^.size,(orgsizeleft-(sizeleft+1))*8,tmpreg);
                             a_op_reg_reg(list,OP_OR,location^.size,tmpreg,location^.register)
                           end
                         else
                           a_load_reg_reg(list,location^.size,location^.size,tmpreg,location^.register);
                         inc(tmpref.offset);
                       end;
                     if location^.shiftval<0 then
                       a_op_const_reg(list,OP_SHL,location^.size,-location^.shiftval,location^.register);
                     { the loop will already adjust the offset and sizeleft }
                     dec(tmpref.offset,orgsizeleft);
                     sizeleft:=orgsizeleft;
                   end;
              end;
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                reference_reset_base(ref,location^.reference.index,location^.reference.offset,ctempposinvalid,NewAlignment(cgpara.alignment,cgpara.intsize-sizeleft),[]);
                a_load_ref_cgparalocref(list,size,sizeleft,tmpref,ref,cgpara,location);
              end;
            LOC_MMREGISTER,LOC_CMMREGISTER:
              begin
                 case location^.size of
                   OS_F32,
                   OS_F64,
                   OS_F128:
                     a_loadmm_ref_reg(list,location^.size,location^.size,tmpref,location^.register,mms_movescalar);
                   OS_M8..OS_M512:
                     a_loadmm_ref_reg(list,location^.size,location^.size,tmpref,location^.register,nil);
                   else
                     InternalError(2010053101);
                 end;
              end;
            LOC_FPUREGISTER,LOC_CFPUREGISTER:
              begin
                { can be not a float size in case of a record passed in fpu registers }
                { the size comparison is to catch F128 passed in two 64 bit floating point registers }
                if is_float_cgsize(size) and
                   (tcgsize2size[location^.size]>=tcgsize2size[size]) then
                  usesize:=size
                else
                  usesize:=location^.size;
                a_loadfpu_ref_reg(list,usesize,location^.size,tmpref,location^.register);
              end
            else
              InternalError(2010053111);
          end;
          inc(tmpref.offset,tcgsize2size[location^.size]);
          dec(sizeleft,tcgsize2size[location^.size]);
          location:=location^.next;
        until not Assigned(location);
      end;

    procedure TCG.a_load_ref_cgparalocref(list: TAsmList; sourcesize: TCgSize; sizeleft: TCGInt; const ref, paralocref: TReference; const cgpara: TCGPara; const location: PCGParaLocation);
      begin
        if Assigned(location^.next) then
          InternalError(2010052906);
        if (sourcesize<>OS_NO) and
           (tcgsize2size[sourcesize]<=sizeof(aint)) then
           a_load_ref_ref(list,sourcesize,location^.size,ref,paralocref)
        else
          { use concatcopy, because the parameter can be larger than }
          { what the OS_* constants can handle                       }
          g_concatcopy(list,ref,paralocref,sizeleft);
       end;


    procedure TCG.a_load_loc_cgpara(list : TAsmList;const l:TLocation;const cgpara : TCGPara);
      begin
        case l.loc of
          LOC_REGISTER,
          LOC_CREGISTER :
            a_load_reg_cgpara(list,l.size,l.register,cgpara);
          LOC_CONSTANT :
            a_load_const_cgpara(list,l.size,l.value,cgpara);
          LOC_CREFERENCE,
          LOC_REFERENCE :
            a_load_ref_cgpara(list,l.size,l.reference,cgpara);
          else
            InternalError(2002032211);
        end;
      end;


    procedure TCG.a_loadaddr_ref_cgpara(list : TAsmList;const r : TReference;const cgpara : TCGPara);
      var
         hr : TRegister;
      begin
         cgpara.check_simple_location;
         if cgpara.location^.loc in [LOC_CREGISTER,LOC_REGISTER] then
           begin
             paramanager.allocparaloc(list,cgpara.location);
             a_loadaddr_ref_reg(list,r,cgpara.location^.register)
           end
         else
           begin
             hr:=getaddressregister(list);
             a_loadaddr_ref_reg(list,r,hr);
             a_load_reg_cgpara(list,OS_ADDR,hr,cgpara);
           end;
      end;


    procedure TCG.a_load_cgparaloc_ref(list : TAsmList;const paraloc : TCGParaLocation;const ref : TReference;sizeleft : TCGInt;align : LongInt);
      var
        href : TReference;
        hreg : TRegister;
        cgsize: TCgSize;
      begin
        case paraloc.loc of
          LOC_REGISTER :
            begin
              hreg:=paraloc.register;
              cgsize:=paraloc.size;
              if (paraloc.shiftval>0) and
	        not ((TargetInfo.endian=endian_big) and (sizeleft in [3,5,6,7])) then
                a_op_const_reg_reg(list,OP_SHL,OS_INT,paraloc.shiftval,paraloc.register,paraloc.register)
              { in case the original size was 3 or 5/6/7 bytes, the value was
                shifted to the top of the to 4 resp. 8 byte register on the
                caller side and needs to be stored with those bytes at the
                start of the reference -> don't shift right }
              else if (paraloc.shiftval<0)
{$ifdef LIMIT_NEG_SHIFTVALUES}
{$ifdef CPU64BITALU}
                      and ((-paraloc.shiftval) in [56{for byte},48{for two bytes},32{for four bytes}])
{$else}
                      and ((-paraloc.shiftval) in [24{for byte},16{for two bytes}])
{$endif}
{$endif}
                  then
                begin
                  a_op_const_reg_reg(list,OP_SHR,OS_INT,-paraloc.shiftval,paraloc.register,paraloc.register);
                  { convert to a register of 1/2/4 bytes in size, since the
                    original register had to be made larger to be able to hold
                    the shifted value }
                  cgsize:=int_cgsize(tcgsize2size[OS_INT]-(-paraloc.shiftval div 8));
                  if cgsize=OS_NO then
                    cgsize:=OS_INT;
                  hreg:=getintregister(list,cgsize);
                  a_load_reg_reg(list,OS_INT,cgsize,paraloc.register,hreg);
                end;
              { use the exact size to avoid overwriting of adjacent data }
              if tcgsize2size[cgsize]<=sizeleft then
                a_load_reg_ref(list,paraloc.size,cgsize,hreg,ref)
              else
                case sizeleft of
                  1,2,4,8:
                    a_load_reg_ref(list,paraloc.size,int_cgsize(sizeleft),hreg,ref);
                  3:
                    begin
                      if TargetInfo.endian=endian_big then
                        begin
                          href:=ref;
                          inc(href.offset,2);
                          a_load_reg_ref(list,paraloc.size,OS_8,hreg,href);
                          a_op_const_reg_reg(list,OP_SHR,OS_INT,8,hreg,hreg);
                          a_load_reg_ref(list,paraloc.size,OS_16,hreg,ref);
                        end
                      else
                        begin
                          a_load_reg_ref(list,paraloc.size,OS_16,hreg,ref);
                          href:=ref;
                          inc(href.offset,2);
                          a_op_const_reg_reg(list,OP_SHR,cgsize,16,hreg,hreg);
                          a_load_reg_ref(list,paraloc.size,OS_8,hreg,href);
                        end
                    end;
                  5:
                    begin
                      if TargetInfo.endian=endian_big then
                        begin
                          href:=ref;
                          inc(href.offset,4);
                          a_load_reg_ref(list,paraloc.size,OS_8,hreg,href);
                          a_op_const_reg_reg(list,OP_SHR,OS_INT,8,hreg,hreg);
                          a_load_reg_ref(list,paraloc.size,OS_32,hreg,ref);
                        end
                      else
                       begin
                          a_load_reg_ref(list,paraloc.size,OS_32,hreg,ref);
                          href:=ref;
                          inc(href.offset,4);
                          a_op_const_reg_reg(list,OP_SHR,cgsize,32,hreg,hreg);
                          a_load_reg_ref(list,paraloc.size,OS_8,hreg,href);
                        end
                    end;
                  6:
                    begin
                      if TargetInfo.endian=endian_big then
                        begin
                          href:=ref;
                          inc(href.offset,4);
                          a_load_reg_ref(list,paraloc.size,OS_16,hreg,href);
                          a_op_const_reg_reg(list,OP_SHR,OS_INT,16,hreg,hreg);
                          a_load_reg_ref(list,paraloc.size,OS_32,hreg,ref);
                        end
                      else
                       begin
                          a_load_reg_ref(list,paraloc.size,OS_32,hreg,ref);
                          href:=ref;
                          inc(href.offset,4);
                          a_op_const_reg_reg(list,OP_SHR,cgsize,32,hreg,hreg);
                          a_load_reg_ref(list,paraloc.size,OS_16,hreg,href);
                        end
                    end;
                  7:
                    begin
                      if TargetInfo.endian=endian_big then
                        begin
                          href:=ref;
                          inc(href.offset,6);
                          a_load_reg_ref(list,paraloc.size,OS_8,hreg,href);

                          a_op_const_reg_reg(list,OP_SHR,OS_INT,8,hreg,hreg);
                          href:=ref;
                          inc(href.offset,4);
                          a_load_reg_ref(list,paraloc.size,OS_16,hreg,href);

                          a_op_const_reg_reg(list,OP_SHR,OS_INT,16,hreg,hreg);
                          a_load_reg_ref(list,paraloc.size,OS_32,hreg,ref);
                        end
                      else
                       begin
                          a_load_reg_ref(list,paraloc.size,OS_32,hreg,ref);

                          href:=ref;
                          inc(href.offset,4);
                          a_op_const_reg_reg(list,OP_SHR,cgsize,32,hreg,hreg);
                          a_load_reg_ref(list,paraloc.size,OS_16,hreg,href);

                          inc(href.offset,2);
                          a_op_const_reg_reg(list,OP_SHR,cgsize,16,hreg,hreg);
                          a_load_reg_ref(list,paraloc.size,OS_8,hreg,href);
                        end
                    end;
                  else
                    { other sizes not allowed }
                    InternalError(2017080901);
                end;
            end;
          LOC_MMREGISTER :
            begin
              case paraloc.size of
                OS_F32,
                OS_F64,
                OS_F128:
                  a_loadmm_reg_ref(list,paraloc.size,paraloc.size,paraloc.register,ref,mms_movescalar);
                OS_M8..OS_M512:
                  a_loadmm_reg_ref(list,paraloc.size,paraloc.size,paraloc.register,ref,nil);
                else
                  InternalError(2010053102);
              end;
            end;
          LOC_FPUREGISTER :
            a_loadfpu_reg_ref(list,paraloc.size,paraloc.size,paraloc.register,ref);
          LOC_REFERENCE :
            begin
              reference_reset_base(href,paraloc.reference.index,paraloc.reference.offset,ctempposinvalid,align,[]);
              { use concatcopy, because it can also be a float which fails when
                load_ref_ref is used. Don't copy data when the references are equal }
              if not((href.base=ref.base) and (href.offset=ref.offset)) then
                g_concatcopy(list,href,ref,sizeleft);
            end;
          else
            InternalError(2002081302);
        end;
      end;


    procedure TCG.a_load_cgparaloc_anyreg(list: TAsmList;regsize: TCgSize;const paraloc: TCGParaLocation;reg: TRegister;align: LongInt);
      var
        href : TReference;
      begin
         case paraloc.loc of
           LOC_REGISTER :
             begin
               if paraloc.shiftval<0 then
                 a_op_const_reg_reg(list,OP_SHR,OS_INT,-paraloc.shiftval,paraloc.register,paraloc.register);
               case getregtype(reg) of
                 R_ADDRESSREGISTER,
                 R_INTREGISTER:
                   a_load_reg_reg(list,paraloc.size,regsize,paraloc.register,reg);
                 R_MMREGISTER:
                   a_loadmm_intreg_reg(list,paraloc.size,regsize,paraloc.register,reg,mms_movescalar);
                 R_FPUREGISTER:
                   a_loadfpu_intreg_reg(list,paraloc.size,regsize,paraloc.register,reg);
                 else
                   InternalError(2009112422);
               end;
             end;
           LOC_MMREGISTER :
             begin
               case getregtype(reg) of
                 R_ADDRESSREGISTER,
                 R_INTREGISTER:
                   a_loadmm_reg_intreg(list,paraloc.size,regsize,paraloc.register,reg,mms_movescalar);
                 R_MMREGISTER:
                   begin
                     case paraloc.size of
                       OS_F32,
                       OS_F64,
                       OS_F128:
                        a_loadmm_reg_reg(list,paraloc.size,regsize,paraloc.register,reg,mms_movescalar);
                       OS_M8..OS_M512:
                         a_loadmm_reg_reg(list,paraloc.size,paraloc.size,paraloc.register,reg,nil);
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
               case getregtype(reg) of
                 R_FPUREGISTER:
                   a_loadfpu_reg_reg(list,paraloc.size,regsize,paraloc.register,reg);
                 R_INTREGISTER:
                   a_loadfpu_reg_intreg(list,paraloc.size,regsize,paraloc.register,reg);
                 else
                   InternalError(2015031401);
                 end;
             end;
           LOC_REFERENCE :
             begin
               reference_reset_base(href,paraloc.reference.index,paraloc.reference.offset,ctempposinvalid,align,[]);
               case getregtype(reg) of
                 R_ADDRESSREGISTER,
                 R_INTREGISTER :
                   a_load_ref_reg(list,paraloc.size,regsize,href,reg);
                 R_FPUREGISTER :
                   a_loadfpu_ref_reg(list,paraloc.size,regsize,href,reg);
                 R_MMREGISTER :
                   { not paraloc.size, because it may be OS_64 instead of
                     OS_F64 in case the parameter is passed using integer
                     conventions (e.g., on ARM) }
                   a_loadmm_ref_reg(list,regsize,regsize,href,reg,mms_movescalar);
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

    procedure TCG.a_load_reg_ref_unaligned(list : TAsmList;fromsize,tosize : TCgSize;register : TRegister;const ref : TReference);
      var
        tmpref : TReference;
        tmpreg : TRegister;
        i : LongInt;
      begin
        if ref.alignment<tcgsize2size[fromsize] then
          begin
            tmpref:=ref;
            { we take care of the alignment now }
            tmpref.alignment:=0;
            case FromSize of
              OS_16,OS_S16:
                begin
                  tmpreg:=getintregister(list,OS_16);
                  a_load_reg_reg(list,fromsize,OS_16,register,tmpreg);
                  if TargetInfo.endian=endian_big then
                    inc(tmpref.offset);
                  tmpreg:=makeregsize(list,tmpreg,OS_8);
                  a_load_reg_ref(list,OS_8,OS_8,tmpreg,tmpref);
                  tmpreg:=makeregsize(list,tmpreg,OS_16);
                  a_op_const_reg(list,OP_SHR,OS_16,8,tmpreg);
                  if TargetInfo.endian=endian_big then
                    dec(tmpref.offset)
                  else
                    inc(tmpref.offset);
                  tmpreg:=makeregsize(list,tmpreg,OS_8);
                  a_load_reg_ref(list,OS_8,OS_8,tmpreg,tmpref);
                end;
              OS_32,OS_S32:
                begin
                  { could add an optimised case for ref.alignment=2 }
                  tmpreg:=getintregister(list,OS_32);
                  a_load_reg_reg(list,fromsize,OS_32,register,tmpreg);
                  if TargetInfo.endian=endian_big then
                    inc(tmpref.offset,3);
                  tmpreg:=makeregsize(list,tmpreg,OS_8);
                  a_load_reg_ref(list,OS_8,OS_8,tmpreg,tmpref);
                  tmpreg:=makeregsize(list,tmpreg,OS_32);
                  for i:=1 to 3 do
                    begin
                      a_op_const_reg(list,OP_SHR,OS_32,8,tmpreg);
                      if TargetInfo.endian=endian_big then
                        dec(tmpref.offset)
                      else
                        inc(tmpref.offset);
                      tmpreg:=makeregsize(list,tmpreg,OS_8);
                      a_load_reg_ref(list,OS_8,OS_8,tmpreg,tmpref);
                      tmpreg:=makeregsize(list,tmpreg,OS_32);
                    end;
                end
              else
                a_load_reg_ref(list,fromsize,tosize,register,tmpref);
            end;
          end
        else
          a_load_reg_ref(list,fromsize,tosize,register,ref);
      end;


    procedure TCG.a_load_ref_reg_unaligned(list : TAsmList;fromsize,tosize : TCgSize;const ref : TReference;register : TRegister);
      var
        tmpref : TReference;
        tmpreg,
        tmpreg2 : TRegister;
        i : LongInt;
        hisize : TCgSize;
      begin
        if ref.alignment in [1,2] then
          begin
            tmpref:=ref;
            { we take care of the alignment now }
            tmpref.alignment:=0;
            case FromSize of
              OS_16,OS_S16:
                if ref.alignment=2 then
                  a_load_ref_reg(list,fromsize,tosize,tmpref,register)
                else
                  begin
                    if FromSize=OS_16 then
                      hisize:=OS_8
                    else
                      hisize:=OS_S8;
                    { first load in tmpreg, because the target register }
                    { may be used in ref as well                        }
                    if TargetInfo.endian=endian_little then
                      inc(tmpref.offset);
                    tmpreg:=getintregister(list,OS_8);
                    a_load_ref_reg(list,hisize,hisize,tmpref,tmpreg);
                    tmpreg:=makeregsize(list,tmpreg,FromSize);
                    a_op_const_reg(list,OP_SHL,FromSize,8,tmpreg);
                    if TargetInfo.endian=endian_little then
                      dec(tmpref.offset)
                    else
                      inc(tmpref.offset);
                    tmpreg2:=makeregsize(list,register,OS_16);
                    a_load_ref_reg(list,OS_8,OS_16,tmpref,tmpreg2);
                    a_op_reg_reg(list,OP_OR,OS_16,tmpreg,tmpreg2);
                    a_load_reg_reg(list,fromsize,tosize,tmpreg2,register);
                  end;
              OS_32,OS_S32:
                if ref.alignment=2 then
                  begin
                    if TargetInfo.endian=endian_little then
                      inc(tmpref.offset,2);
                    tmpreg:=getintregister(list,OS_32);
                    a_load_ref_reg(list,OS_16,OS_32,tmpref,tmpreg);
                    a_op_const_reg(list,OP_SHL,OS_32,16,tmpreg);
                    if TargetInfo.endian=endian_little then
                      dec(tmpref.offset,2)
                    else
                      inc(tmpref.offset,2);
                    tmpreg2:=makeregsize(list,register,OS_32);
                    a_load_ref_reg(list,OS_16,OS_32,tmpref,tmpreg2);
                    a_op_reg_reg(list,OP_OR,OS_32,tmpreg,tmpreg2);
                    a_load_reg_reg(list,fromsize,tosize,tmpreg2,register);
                  end
                else
                  begin
                    if TargetInfo.endian=endian_little then
                      inc(tmpref.offset,3);
                    tmpreg:=getintregister(list,OS_32);
                    a_load_ref_reg(list,OS_8,OS_32,tmpref,tmpreg);
                    tmpreg2:=getintregister(list,OS_32);
                    for i:=1 to 3 do
                      begin
                        a_op_const_reg(list,OP_SHL,OS_32,8,tmpreg);
                        if TargetInfo.endian=endian_little then
                          dec(tmpref.offset)
                        else
                          inc(tmpref.offset);
                        a_load_ref_reg(list,OS_8,OS_32,tmpref,tmpreg2);
                        a_op_reg_reg(list,OP_OR,OS_32,tmpreg2,tmpreg);
                      end;
                    a_load_reg_reg(list,fromsize,tosize,tmpreg,register);
                  end
              else
                a_load_ref_reg(list,fromsize,tosize,tmpref,register);
            end;
          end
        else
          a_load_ref_reg(list,fromsize,tosize,ref,register);
      end;


    procedure TCG.a_load_ref_ref(list : TAsmList;fromsize,tosize : TCgSize;const sref : TReference;const dref : TReference);
      var
        tmpreg: TRegister;
      begin
        { verify if we have the same reference }
        if references_equal(sref,dref) then
          exit;
        tmpreg:=getintregister(list,tosize);
        a_load_ref_reg(list,fromsize,tosize,sref,tmpreg);
        a_load_reg_ref(list,tosize,tosize,tmpreg,dref);
      end;


    procedure TCG.a_load_const_ref(list : TAsmList;size : TCgSize;a : TCGInt;const ref : TReference);
      var
        tmpreg: TRegister;
      begin
        tmpreg:=getintregister(list,size);
        a_load_const_reg(list,size,a,tmpreg);
        a_load_reg_ref(list,size,size,tmpreg,ref);
      end;


    procedure TCG.a_load_const_loc(list : TAsmList;a : TCGInt;const loc: TLocation);
      begin
        case loc.loc of
          LOC_REFERENCE,LOC_CREFERENCE:
            a_load_const_ref(list,loc.size,a,loc.reference);
          LOC_REGISTER,LOC_CREGISTER:
            a_load_const_reg(list,loc.size,a,loc.register);
          else
            InternalError(200203272);
        end;
      end;


    procedure TCG.a_load_reg_loc(list : TAsmList;fromsize : TCgSize;reg : TRegister;const loc: TLocation);
      begin
        case loc.loc of
          LOC_REFERENCE,LOC_CREFERENCE:
            a_load_reg_ref(list,fromsize,loc.size,reg,loc.reference);
          LOC_REGISTER,LOC_CREGISTER:
            a_load_reg_reg(list,fromsize,loc.size,reg,loc.register);
          LOC_MMREGISTER,LOC_CMMREGISTER:
            a_loadmm_intreg_reg(list,fromsize,loc.size,reg,loc.register,mms_movescalar);
          else
            InternalError(200203271);
        end;
      end;


    procedure TCG.a_load_loc_reg(list : TAsmList; tosize: TCgSize; const loc: TLocation; reg : TRegister);
      begin
        case loc.loc of
          LOC_REFERENCE,LOC_CREFERENCE:
            a_load_ref_reg(list,loc.size,tosize,loc.reference,reg);
          LOC_REGISTER,LOC_CREGISTER:
            a_load_reg_reg(list,loc.size,tosize,loc.register,reg);
          LOC_CONSTANT:
            a_load_const_reg(list,tosize,loc.value,reg);
          LOC_MMREGISTER,LOC_CMMREGISTER:
            a_loadmm_reg_intreg(list,loc.size,tosize,loc.register,reg,mms_movescalar);
          else
            InternalError(200109092);
        end;
      end;


    procedure TCG.a_load_loc_ref(list : TAsmList;tosize: TCgSize; const loc: TLocation; const ref : TReference);
      begin
        case loc.loc of
          LOC_REFERENCE,LOC_CREFERENCE:
            a_load_ref_ref(list,loc.size,tosize,loc.reference,ref);
          LOC_REGISTER,LOC_CREGISTER:
            a_load_reg_ref(list,loc.size,tosize,loc.register,ref);
          LOC_CONSTANT:
            a_load_const_ref(list,tosize,loc.value,ref);
          else
            InternalError(200109302);
        end;
      end;


    procedure TCG.optimize_op_const(size: TCgSize; var op: TOpCG; var a : TCGInt);
      var
        powerval : LongInt;
        signext_a, zeroext_a: TCGInt;
      begin
        case size of
          OS_64,OS_S64:
            begin
              signext_a:=int64(a);
              zeroext_a:=int64(a);
            end;
          OS_32,OS_S32:
            begin
              signext_a:=LongInt(a);
              zeroext_a:=dword(a);
            end;
          OS_16,OS_S16:
            begin
              signext_a:=smallint(a);
              zeroext_a:=word(a);
            end;
          OS_8,OS_S8:
            begin
              signext_a:=shortint(a);
              zeroext_a:=byte(a);
            end
          else
            begin
              { Should we internalerror() here instead? }
              signext_a:=a;
              zeroext_a:=a;
            end;
        end;
        case op of
          OP_OR :
            begin
              { or with zero returns same result }
              if a = 0 then
                op:=OP_NONE
              else
              { or with max returns max }
                if signext_a = -1 then
                  op:=OP_MOVE;
            end;
          OP_AND :
            begin
              { and with max returns same result }
              if (signext_a = -1) then
                op:=OP_NONE
              else
              { and with 0 returns 0 }
                if a=0 then
                  op:=OP_MOVE;
            end;
          OP_XOR :
            begin
              { xor with zero returns same result }
              if a = 0 then
                op:=OP_NONE;
            end;
          OP_DIV :
            begin
              { division by 1 returns result }
              if a = 1 then
                op:=OP_NONE
              else if IsPowerOf2(int64(zeroext_a), powerval) and not(cs_check_overflow in CurrentSettings.LocalSwitches) then
                begin
                  a := powerval;
                  op:= OP_SHR;
                end;
            end;
          OP_IDIV:
            begin
              if a = 1 then
                op:=OP_NONE;
            end;
         OP_MUL,OP_IMUL:
            begin
               if a = 1 then
                 op:=OP_NONE
               else
                 if a=0 then
                   op:=OP_MOVE
               else if IsPowerOf2(int64(zeroext_a), powerval) and not(cs_check_overflow in CurrentSettings.LocalSwitches)  then
                 begin
                   a := powerval;
                   op:= OP_SHL;
                 end;
            end;
        OP_ADD,OP_SUB:
            begin
               if a = 0 then
                 op:=OP_NONE;
            end;
        OP_SAR,OP_SHL,OP_SHR:
           begin
             if a = 0 then
               op:=OP_NONE;
           end;
        OP_ROL,OP_ROR:
          begin
            case size of
              OS_64,OS_S64:
                a:=a and 63;
              OS_32,OS_S32:
                a:=a and 31;
              OS_16,OS_S16:
                a:=a and 15;
              OS_8,OS_S8:
                a:=a and 7;
              else
                InternalError(2019050521);
            end;
            if a = 0 then
              op:=OP_NONE;
          end;
        else
          ;
        end;
      end;


    procedure TCG.a_loadfpu_loc_reg(list: TAsmList; tosize: TCgSize; const loc: TLocation; const reg: TRegister);
      begin
        case loc.loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            a_loadfpu_ref_reg(list,loc.size,tosize,loc.reference,reg);
          LOC_FPUREGISTER, LOC_CFPUREGISTER:
            a_loadfpu_reg_reg(list,loc.size,tosize,loc.register,reg);
          else
            InternalError(200203301);
        end;
      end;


    procedure TCG.a_loadfpu_reg_loc(list: TAsmList; fromsize: TCgSize; const reg: TRegister; const loc: TLocation);
      begin
        case loc.loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            a_loadfpu_reg_ref(list,fromsize,loc.size,reg,loc.reference);
          LOC_FPUREGISTER, LOC_CFPUREGISTER:
            a_loadfpu_reg_reg(list,fromsize,loc.size,reg,loc.register);
          else
            InternalError(48991);
         end;
      end;


    procedure TCG.a_loadfpu_ref_ref(list: TAsmList; fromsize, tosize: TCgSize; const ref1,ref2: TReference);
      var
        reg: TRegister;
        regsize: TCgSize;
      begin
        if (fromsize>=tosize) then
          regsize:=fromsize
        else
          regsize:=tosize;
        reg:=getfpuregister(list,regsize);
        a_loadfpu_ref_reg(list,fromsize,regsize,ref1,reg);
        a_loadfpu_reg_ref(list,regsize,tosize,reg,ref2);
      end;


    procedure TCG.a_loadfpu_reg_cgpara(list : TAsmList;size : TCgSize;const r : TRegister;const cgpara : TCGPara);
      var
         ref : TReference;
      begin
        paramanager.alloccgpara(list,cgpara);
         case cgpara.location^.loc of
            LOC_FPUREGISTER,LOC_CFPUREGISTER:
              begin
                cgpara.check_simple_location;
                a_loadfpu_reg_reg(list,size,size,r,cgpara.location^.register);
              end;
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                cgpara.check_simple_location;
                reference_reset_base(ref,cgpara.location^.reference.index,cgpara.location^.reference.offset,ctempposinvalid,cgpara.alignment,[]);
                a_loadfpu_reg_ref(list,size,size,r,ref);
              end;
            LOC_REGISTER,LOC_CREGISTER:
              begin
                { paramfpu_ref does the check_simple_location check here if necessary }
                tg.GetTemp(list,TCGSize2Size[size],TCGSize2Size[size],tt_normal,ref);
                a_loadfpu_reg_ref(list,size,size,r,ref);
                a_loadfpu_ref_cgpara(list,size,ref,cgpara);
                tg.Ungettemp(list,ref);
              end;
            else
              InternalError(2010053112);
         end;
      end;


    procedure TCG.a_loadfpu_ref_cgpara(list : TAsmList;size : TCgSize;const ref : TReference;const cgpara : TCGPara);
      var
        srcref,
        href : TReference;
        srcsize,
        hsize: TCgSize;
        paraloc: PCGParaLocation;
        sizeleft: TCGInt;
      begin
        sizeleft:=cgpara.intsize;
        paraloc:=cgpara.location;
        paramanager.alloccgpara(list,cgpara);
        srcref:=ref;
        repeat
          case paraloc^.loc of
            LOC_FPUREGISTER,LOC_CFPUREGISTER:
              begin
                { destination: can be something different in case of a record passed in fpu registers }
                if is_float_cgsize(paraloc^.size) then
                  hsize:=paraloc^.size
                else
                  hsize:=int_float_cgsize(tcgsize2size[paraloc^.size]);
                { source: the size comparison is to catch F128 passed in two 64 bit floating point registers }
                if is_float_cgsize(size) and
                   (tcgsize2size[size]<=tcgsize2size[paraloc^.size]) then
                  srcsize:=size
                else
                  srcsize:=hsize;
                a_loadfpu_ref_reg(list,srcsize,hsize,srcref,paraloc^.register);
              end;
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                if Assigned(paraloc^.next) then
                  InternalError(2020050101);
                reference_reset_base(href,paraloc^.reference.index,paraloc^.reference.offset,ctempposinvalid,NewAlignment(cgpara.alignment,cgpara.intsize-sizeleft),[]);
                { concatcopy should choose the best way to copy the data }
                g_concatcopy(list,srcref,href,sizeleft);
              end;
            LOC_REGISTER,LOC_CREGISTER:
              begin
                { force integer size }
                hsize:=int_cgsize(tcgsize2size[paraloc^.size]);
  {$ifndef cpu64bitalu}
                if (hsize in [OS_S64,OS_64]) then
                  begin
                    { if this is not a simple location, we'll have to add support to cg64 to load parts of a cgpara }
                    cgpara.check_simple_location;
                    cg64.a_load64_ref_cgpara(list,srcref,cgpara)
                  end
                else
  {$endif not cpu64bitalu}
                  begin
                    a_load_ref_reg(list,hsize,hsize,srcref,paraloc^.register)
                  end;
              end
            else
              InternalError(200402201);
          end;
          inc(srcref.offset,tcgsize2size[paraloc^.size]);
          dec(sizeleft,tcgsize2size[paraloc^.size]);
          paraloc:=paraloc^.next;
        until not Assigned(paraloc);
      end;


    procedure TCG.a_loadfpu_intreg_reg(list : TAsmList; fromsize,tosize : TCgSize; intreg,fpureg : TRegister);
      var
        tmpref: TReference;
      begin
        if not(tcgsize2size[fromsize] in [4,8]) or
           not(tcgsize2size[tosize] in [4,8]) or
           (tcgsize2size[fromsize]<>tcgsize2size[tosize]) then
          InternalError(2017070902);
        tg.gettemp(list,tcgsize2size[fromsize],tcgsize2size[fromsize],tt_normal,tmpref);
        a_load_reg_ref(list,fromsize,fromsize,intreg,tmpref);
        a_loadfpu_ref_reg(list,tosize,tosize,tmpref,fpureg);
        tg.ungettemp(list,tmpref);
      end;


    procedure TCG.a_loadfpu_reg_intreg(list : TAsmList; fromsize,tosize : TCgSize; fpureg,intreg : TRegister);
      var
        tmpref: TReference;
      begin
        if not(tcgsize2size[fromsize] in [4,8]) or
           not(tcgsize2size[tosize] in [4,8]) or
           (tcgsize2size[fromsize]<>tcgsize2size[tosize]) then
          InternalError(2020091201);
        tg.gettemp(list,tcgsize2size[fromsize],tcgsize2size[fromsize],tt_normal,tmpref);
        a_loadfpu_reg_ref(list,fromsize,fromsize,fpureg,tmpref);
        a_load_ref_reg(list,tosize,tosize,tmpref,intreg);
        tg.ungettemp(list,tmpref);
      end;


    procedure TCG.a_op_const_ref(list : TAsmList; Op: TOpCG; size: TCgSize; a: TCGInt; const ref: TReference);
      var
        tmpreg : TRegister;
        tmpref : TReference;
      begin
        if Assigned(ref.symbol) then
          begin
            tmpreg:=getaddressregister(list);
            a_loadaddr_ref_reg(list,ref,tmpreg);
            reference_reset_base(tmpref,tmpreg,0,ref.temppos,ref.alignment,[]);
          end
        else
          tmpref:=ref;
        tmpreg:=getintregister(list,size);
        a_load_ref_reg(list,size,size,tmpref,tmpreg);
        a_op_const_reg(list,op,size,a,tmpreg);
        a_load_reg_ref(list,size,size,tmpreg,tmpref);
      end;


    procedure TCG.a_op_const_loc(list : TAsmList; Op: TOpCG; a: TCGInt; const loc: TLocation);
      begin
        case loc.loc of
          LOC_REGISTER, LOC_CREGISTER:
            a_op_const_reg(list,op,loc.size,a,loc.register);
          LOC_REFERENCE, LOC_CREFERENCE:
            a_op_const_ref(list,op,loc.size,a,loc.reference);
          else
            InternalError(200109061);
        end;
      end;


    procedure TCG.a_op_reg_ref(list : TAsmList; Op: TOpCG; size: TCgSize;reg: TRegister;  const ref: TReference);
      var
        tmpreg : TRegister;
        tmpref : TReference;
      begin
        if Assigned(ref.symbol) then
          begin
            tmpreg:=getaddressregister(list);
            a_loadaddr_ref_reg(list,ref,tmpreg);
            reference_reset_base(tmpref,tmpreg,0,ref.temppos,ref.alignment,[]);
          end
        else
          tmpref:=ref;
        if op in [OP_NEG,OP_NOT] then
          begin
            tmpreg:=getintregister(list,size);
            a_op_reg_reg(list,op,size,reg,tmpreg);
            a_load_reg_ref(list,size,size,tmpreg,tmpref);
          end
        else
          begin
            tmpreg:=getintregister(list,size);
            a_load_ref_reg(list,size,size,tmpref,tmpreg);
            a_op_reg_reg(list,op,size,reg,tmpreg);
            a_load_reg_ref(list,size,size,tmpreg,tmpref);
          end;
      end;


    procedure TCG.a_op_ref_reg(list : TAsmList; Op: TOpCG; size: TCgSize; const ref: TReference; reg: TRegister);

      var
        tmpreg: TRegister;

      begin
        case op of
          OP_NOT,OP_NEG:
            { handle it as "load ref,reg; op reg" }
            begin
              a_load_ref_reg(list,size,size,ref,reg);
              a_op_reg_reg(list,op,size,reg,reg);
            end;
          else
            begin
              tmpreg:=getintregister(list,size);
              a_load_ref_reg(list,size,size,ref,tmpreg);
              a_op_reg_reg(list,op,size,tmpreg,reg);
            end;
        end;
      end;


    procedure TCG.a_op_reg_loc(list : TAsmList; Op: TOpCG; reg: TRegister; const loc: TLocation);

      begin
        case loc.loc of
          LOC_REGISTER, LOC_CREGISTER:
            a_op_reg_reg(list,op,loc.size,reg,loc.register);
          LOC_REFERENCE, LOC_CREFERENCE:
            a_op_reg_ref(list,op,loc.size,reg,loc.reference);
          else
            InternalError(2001090602);
        end;
      end;


    procedure TCG.a_op_loc_reg(list : TAsmList; Op : TOpCG; size: TCgSize; const loc : TLocation; reg : TRegister);

      begin
        case loc.loc of
          LOC_REGISTER, LOC_CREGISTER:
            a_op_reg_reg(list,op,size,loc.register,reg);
          LOC_REFERENCE, LOC_CREFERENCE:
            a_op_ref_reg(list,op,size,loc.reference,reg);
          LOC_CONSTANT:
            a_op_const_reg(list,op,size,loc.value,reg);
          else
            InternalError(2018031101);
        end;
      end;


    procedure TCG.a_op_ref_loc(list : TAsmList; Op: TOpCG; const ref: TReference; const loc: TLocation);

      var
        tmpreg: TRegister;

      begin
        case loc.loc of
          LOC_REGISTER,LOC_CREGISTER:
            a_op_ref_reg(list,op,loc.size,ref,loc.register);
          LOC_REFERENCE,LOC_CREFERENCE:
            begin
              tmpreg:=getintregister(list,loc.size);
              a_load_ref_reg(list,loc.size,loc.size,ref,tmpreg);
              a_op_reg_ref(list,op,loc.size,tmpreg,loc.reference);
            end;
          else
            InternalError(2001090603);
        end;
      end;


    procedure TCG.a_op_const_reg_reg(list:TAsmList;op:TOpCG;size:TCgSize;
                                     a:TCGInt;src,dst:TRegister);
    begin
      optimize_op_const(size, op, a);
      case op of
        OP_NONE:
          begin
            if src <> dst then
              a_load_reg_reg(list, size, size, src, dst);
            exit;
          end;
        OP_MOVE:
          begin
            a_load_const_reg(list, size, a, dst);
            exit;
          end;


        else
          ;
      end;
      a_load_reg_reg(list,size,size,src,dst);
      a_op_const_reg(list,op,size,a,dst);
    end;

    procedure TCG.a_op_reg_reg_reg(list: TAsmList; op: TOpCG;
        size: TCgSize; src1, src2, dst: TRegister);
      var
        tmpreg: TRegister;
      begin
        if (dst<>src1) then
          begin
            a_load_reg_reg(list,size,size,src2,dst);
            a_op_reg_reg(list,op,size,src1,dst);
          end
        else
          begin
            { can we do a direct operation on the target register ? }
            if op in [OP_ADD,OP_MUL,OP_AND,OP_MOVE,OP_XOR,OP_IMUL,OP_OR] then
              a_op_reg_reg(list,op,size,src2,dst)
            else
              begin
                tmpreg:=getintregister(list,size);
                a_load_reg_reg(list,size,size,src2,tmpreg);
                a_op_reg_reg(list,op,size,src1,tmpreg);
                a_load_reg_reg(list,size,size,tmpreg,dst);
              end;
          end;
      end;


    procedure TCG.a_op_const_reg_reg_checkoverflow(list: TAsmList; op: TOpCG; size: TCgSize; a: TCGInt; src, dst: TRegister;setflags : boolean;var ovloc : TLocation);
      begin
        a_op_const_reg_reg(list,op,size,a,src,dst);
        ovloc.loc:=LOC_VOID;
      end;


    procedure TCG.a_op_reg_reg_reg_checkoverflow(list: TAsmList; op: TOpCG; size: TCgSize; src1, src2, dst: TRegister;setflags : boolean;var ovloc : TLocation);
      begin
        a_op_reg_reg_reg(list,op,size,src1,src2,dst);
        ovloc.loc:=LOC_VOID;
      end;


    procedure TCG.a_op_reg(list: TAsmList; Op: TOpCG; size: TCgSize; reg: TRegister);
      begin
        if not (Op in [OP_NOT,OP_NEG]) then
          InternalError(2020050701);
        a_op_reg_reg(list,op,size,reg,reg);
      end;


    procedure TCG.a_op_ref(list: TAsmList; Op: TOpCG; size: TCgSize; const ref: TReference);
      var
        tmpreg: TRegister;
        tmpref: TReference;
      begin
        if not (Op in [OP_NOT,OP_NEG]) then
          InternalError(2020050710);
        if Assigned(ref.symbol) then
          begin
            tmpreg:=getaddressregister(list);
            a_loadaddr_ref_reg(list,ref,tmpreg);
            reference_reset_base(tmpref,tmpreg,0,ref.temppos,ref.alignment,[]);
          end
        else
          tmpref:=ref;
        tmpreg:=getintregister(list,size);
        a_load_ref_reg(list,size,size,tmpref,tmpreg);
        a_op_reg_reg(list,op,size,tmpreg,tmpreg);
        a_load_reg_ref(list,size,size,tmpreg,tmpref);
      end;


    procedure TCG.a_op_loc(list: TAsmList; Op: TOpCG; const loc: TLocation);
      begin
        case loc.loc of
          LOC_REGISTER, LOC_CREGISTER:
            a_op_reg(list,op,loc.size,loc.register);
          LOC_REFERENCE, LOC_CREFERENCE:
            a_op_ref(list,op,loc.size,loc.reference);
          else
            InternalError(2020050702);
        end;
      end;


    procedure TCG.a_cmp_const_reg_label(list: TAsmList; size: TCgSize;
      cmp_op: TOpCmp; a: TCGInt; reg: TRegister; l: TAsmLabel);
      var
        tmpreg: TRegister;
      begin
        tmpreg:=getintregister(list,size);
        a_load_const_reg(list,size,a,tmpreg);
        a_cmp_reg_reg_label(list,size,cmp_op,tmpreg,reg,l);
      end;


    procedure TCG.a_cmp_const_ref_label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;a : TCGInt;const ref : TReference;
      l : TAsmLabel);
      var
        tmpreg: TRegister;
      begin
        tmpreg:=getintregister(list,size);
        a_load_ref_reg(list,size,size,ref,tmpreg);
        a_cmp_const_reg_label(list,size,cmp_op,a,tmpreg,l);
      end;


    procedure TCG.a_cmp_const_loc_label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;a : TCGInt;const loc : TLocation;
      l : TAsmLabel);
      begin
        case loc.loc of
          LOC_REGISTER,LOC_CREGISTER:
            a_cmp_const_reg_label(list,size,cmp_op,a,loc.register,l);
          LOC_REFERENCE,LOC_CREFERENCE:
            a_cmp_const_ref_label(list,size,cmp_op,a,loc.reference,l);
          else
            InternalError(2001090604);
        end;
      end;


    procedure TCG.a_cmp_ref_reg_label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp; const ref: TReference; reg : TRegister; l : TAsmLabel);
      var
        tmpreg: TRegister;
      begin
        tmpreg:=getintregister(list,size);
        a_load_ref_reg(list,size,size,ref,tmpreg);
        a_cmp_reg_reg_label(list,size,cmp_op,tmpreg,reg,l);
      end;


    procedure TCG.a_cmp_reg_ref_label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp; reg : TRegister; const ref: TReference; l : TAsmLabel);
      var
        tmpreg: TRegister;
      begin
        tmpreg:=getintregister(list,size);
        a_load_ref_reg(list,size,size,ref,tmpreg);
        a_cmp_reg_reg_label(list,size,cmp_op,reg,tmpreg,l);
      end;


    procedure TCG.a_cmp_reg_loc_label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp; reg: TRegister; const loc: TLocation; l : TAsmLabel);
      begin
        a_cmp_loc_reg_label(list,size,swap_opcmp(cmp_op),loc,reg,l);
      end;


    procedure TCG.a_cmp_loc_reg_label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp; const loc: TLocation; reg : TRegister; l : TAsmLabel);
      begin
        case loc.loc of
          LOC_REGISTER,
          LOC_CREGISTER:
            a_cmp_reg_reg_label(list,size,cmp_op,loc.register,reg,l);
          LOC_REFERENCE,
          LOC_CREFERENCE :
            a_cmp_ref_reg_label(list,size,cmp_op,loc.reference,reg,l);
          LOC_CONSTANT:
            a_cmp_const_reg_label(list,size,cmp_op,loc.value,reg,l);
          else
            InternalError(200203231);
        end;
      end;


    procedure TCG.a_cmp_ref_loc_label(list : TAsmList;size : TCgSize;cmp_op : TOpCmp;const ref: TReference;const loc : TLocation;
      l : TAsmLabel);
      var
        tmpreg: TRegister;
      begin
        case loc.loc of
          LOC_REGISTER,LOC_CREGISTER:
            a_cmp_ref_reg_label(list,size,cmp_op,ref,loc.register,l);
          LOC_REFERENCE,LOC_CREFERENCE:
            begin
              tmpreg:=getintregister(list,size);
              a_load_ref_reg(list,size,size,loc.reference,tmpreg);
              a_cmp_ref_reg_label(list,size,cmp_op,ref,tmpreg,l);
            end;
          else
            InternalError(2001090605);
        end;
      end;


    procedure TCG.a_loadmm_loc_reg(list: TAsmList; size: TCgSize; const loc: TLocation; const reg: TRegister;shuffle : PMMShuffle);
      begin
        case loc.loc of
          LOC_MMREGISTER,LOC_CMMREGISTER:
            a_loadmm_reg_reg(list,loc.size,size,loc.register,reg,shuffle);
          LOC_REFERENCE,LOC_CREFERENCE:
            a_loadmm_ref_reg(list,loc.size,size,loc.reference,reg,shuffle);
          LOC_REGISTER,LOC_CREGISTER:
            a_loadmm_intreg_reg(list,loc.size,size,loc.register,reg,shuffle);
          else
            InternalError(200310121);
        end;
      end;


    procedure TCG.a_loadmm_reg_loc(list: TAsmList; size: TCgSize; const reg: TRegister; const loc: TLocation;shuffle : PMMShuffle);
      begin
        case loc.loc of
          LOC_MMREGISTER,LOC_CMMREGISTER:
            a_loadmm_reg_reg(list,size,loc.size,reg,loc.register,shuffle);
          LOC_REFERENCE,LOC_CREFERENCE:
            a_loadmm_reg_ref(list,size,loc.size,reg,loc.reference,shuffle);
          else
            InternalError(200310122);
        end;
      end;


    procedure TCG.a_loadmm_reg_cgpara(list: TAsmList; size: TCgSize; reg: TRegister;const cgpara : TCGPara;shuffle : PMMShuffle);
      var
        href  : TReference;
{$ifndef cpu64bitalu}
        tmpreg : TRegister;
        reg64 : TRegister64;
{$endif not cpu64bitalu}
      begin
{$ifndef cpu64bitalu}
         if not(cgpara.location^.loc in [LOC_REGISTER,LOC_CREGISTER]) or
            (size<>OS_F64) then
{$endif not cpu64bitalu}
           cgpara.check_simple_location;
         paramanager.alloccgpara(list,cgpara);
         case cgpara.location^.loc of
          LOC_MMREGISTER,LOC_CMMREGISTER:
            a_loadmm_reg_reg(list,size,cgpara.location^.size,reg,cgpara.location^.register,shuffle);
          LOC_REFERENCE,LOC_CREFERENCE:
            begin
              reference_reset_base(href,cgpara.location^.reference.index,cgpara.location^.reference.offset,ctempposinvalid,cgpara.alignment,[]);
              a_loadmm_reg_ref(list,size,cgpara.location^.size,reg,href,shuffle);
            end;
          LOC_REGISTER,LOC_CREGISTER:
            begin
              if Assigned(shuffle) and
                 not shufflescalar(shuffle) then
                InternalError(2009112510);
{$ifndef cpu64bitalu}
              if (size=OS_F64) then
                begin
                  if not Assigned(cgpara.location^.next) or
                     Assigned(cgpara.location^.next^.next) then
                    InternalError(2009112512);
                  case cgpara.location^.next^.loc of
                    LOC_REGISTER,LOC_CREGISTER:
                      tmpreg:=cgpara.location^.next^.register;
                    LOC_REFERENCE,LOC_CREFERENCE:
                      tmpreg:=getintregister(list,OS_32);
                    else
                      InternalError(2009112910);
                  end;
                  if (TargetInfo.endian=ENDIAN_BIG) then
                    begin
                      { paraloc^ -> high
                        paraloc^.next -> low }
                      reg64.reghi:=cgpara.location^.register;
                      reg64.reglo:=tmpreg;
                    end
                  else
                    begin
                      { paraloc^ -> low
                        paraloc^.next -> high }
                      reg64.reglo:=cgpara.location^.register;
                      reg64.reghi:=tmpreg;
                    end;
                  cg64.a_loadmm_reg_intreg64(list,size,reg,reg64);
                  if (cgpara.location^.next^.loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                    begin
                      if not(cgpara.location^.next^.size in [OS_32,OS_S32]) then
                        InternalError(2009112911);
                      reference_reset_base(href,cgpara.location^.next^.reference.index,cgpara.location^.next^.reference.offset,ctempposinvalid,cgpara.alignment,[]);
                      a_load_reg_ref(list,OS_32,cgpara.location^.next^.size,tmpreg,href);
                    end;
                end
              else
{$endif not cpu64bitalu}
                a_loadmm_reg_intreg(list,size,cgpara.location^.size,reg,cgpara.location^.register,mms_movescalar);
            end
          else
            InternalError(200310123);
        end;
      end;


    procedure TCG.a_loadmm_ref_cgpara(list: TAsmList; size: TCgSize;const ref: TReference;const cgpara : TCGPara;shuffle : PMMShuffle);
      var
         hr : TRegister;
         hs : TMMShuffle;
         lRegisterSize: TCgSize;
      begin
         cgpara.check_simple_location;
         lRegisterSize:=cgpara.location^.size;
         { An ABI may carry a scalar float in an integer argument slot, e.g.
           Win64 C varargs. Its temporary SSE register still needs a float size. }
         if lRegisterSize in [OS_32,OS_S32,OS_64,OS_S64] then
           lRegisterSize:=int_float_cgsize(tcgsize2size[lRegisterSize]);
         hr:=getmmregister(list,lRegisterSize);
         a_loadmm_ref_reg(list,size,lRegisterSize,ref,hr,shuffle);
         if realshuffle(shuffle) then
           begin
             hs:=shuffle^;
             removeshuffles(hs);
             a_loadmm_reg_cgpara(list,lRegisterSize,hr,cgpara,@hs);
           end
         else
           a_loadmm_reg_cgpara(list,lRegisterSize,hr,cgpara,shuffle);
      end;


    procedure TCG.a_loadmm_loc_cgpara(list: TAsmList;const loc: TLocation; const cgpara : TCGPara;shuffle : PMMShuffle);
      begin
        case loc.loc of
          LOC_MMREGISTER,LOC_CMMREGISTER:
            a_loadmm_reg_cgpara(list,loc.size,loc.register,cgpara,shuffle);
          LOC_REFERENCE,LOC_CREFERENCE:
            a_loadmm_ref_cgpara(list,loc.size,loc.reference,cgpara,shuffle);
          else
            InternalError(2003101204);
        end;
      end;


    procedure TCG.a_opmm_ref_reg(list: TAsmList; Op: TOpCG; size : TCgSize;const ref: TReference; reg: TRegister;shuffle : PMMShuffle);
      var
         hr : TRegister;
         hs : TMMShuffle;
      begin
         hr:=getmmregister(list,size);
         a_loadmm_ref_reg(list,size,size,ref,hr,shuffle);
         if realshuffle(shuffle) then
           begin
             hs:=shuffle^;
             removeshuffles(hs);
             a_opmm_reg_reg(list,op,size,hr,reg,@hs);
           end
         else
           a_opmm_reg_reg(list,op,size,hr,reg,shuffle);
      end;


    procedure TCG.a_opmm_reg_ref(list: TAsmList; Op: TOpCG; size : TCgSize;reg: TRegister; const ref: TReference; shuffle : PMMShuffle);
      var
         hr : TRegister;
         hs : TMMShuffle;
      begin
         hr:=getmmregister(list,size);
         a_loadmm_ref_reg(list,size,size,ref,hr,shuffle);
         if realshuffle(shuffle) then
           begin
             hs:=shuffle^;
             removeshuffles(hs);
             a_opmm_reg_reg(list,op,size,reg,hr,@hs);
             a_loadmm_reg_ref(list,size,size,hr,ref,@hs);
           end
         else
           begin
             a_opmm_reg_reg(list,op,size,reg,hr,shuffle);
             a_loadmm_reg_ref(list,size,size,hr,ref,shuffle);
           end;
      end;


    procedure TCG.a_loadmm_intreg_reg(list: TAsmList; fromsize,tosize: TCgSize; intreg,mmreg: TRegister; shuffle: PMMShuffle);
      var
        tmpref: TReference;
      begin
        if (tcgsize2size[fromsize]<>4) or
           (tcgsize2size[tosize]<>4) then
          InternalError(2009112503);
        tg.gettemp(list,4,4,tt_normal,tmpref);
        a_load_reg_ref(list,fromsize,fromsize,intreg,tmpref);
        a_loadmm_ref_reg(list,tosize,tosize,tmpref,mmreg,shuffle);
        tg.ungettemp(list,tmpref);
      end;


    procedure TCG.a_loadmm_reg_intreg(list: TAsmList; fromsize,tosize: TCgSize; mmreg,intreg: TRegister; shuffle: PMMShuffle);
      var
        tmpref: TReference;
      begin
        if (tcgsize2size[fromsize]<>4) or
           (tcgsize2size[tosize]<>4) then
          InternalError(2009112504);
        tg.gettemp(list,8,8,tt_normal,tmpref);
        a_loadmm_reg_ref(list,fromsize,fromsize,mmreg,tmpref,shuffle);
        a_load_ref_reg(list,tosize,tosize,tmpref,intreg);
        tg.ungettemp(list,tmpref);
      end;


    procedure TCG.a_opmm_loc_reg(list: TAsmList; Op: TOpCG; size : TCgSize;const loc: TLocation; reg: TRegister;shuffle : PMMShuffle);
      begin
        case loc.loc of
          LOC_CMMREGISTER,LOC_MMREGISTER:
            a_opmm_reg_reg(list,op,size,loc.register,reg,shuffle);
          LOC_CREFERENCE,LOC_REFERENCE:
            a_opmm_ref_reg(list,op,size,loc.reference,reg,shuffle);
          else
            InternalError(200312232);
        end;
      end;


    procedure TCG.a_opmm_loc_reg_reg(list: TAsmList; Op: TOpCG; size : TCgSize;const loc: TLocation; src,dst: TRegister;shuffle : PMMShuffle);
      begin
        case loc.loc of
          LOC_CMMREGISTER,LOC_MMREGISTER:
            a_opmm_reg_reg_reg(list,op,size,loc.register,src,dst,shuffle);
          LOC_CREFERENCE,LOC_REFERENCE:
            a_opmm_ref_reg_reg(list,op,size,loc.reference,src,dst,shuffle);
          else
            InternalError(2003122304);
        end;
      end;


    procedure TCG.a_opmm_reg_reg_reg(list : TAsmList;Op : TOpCG;size : TCgSize;
      src1,src2,dst : TRegister;shuffle : PMMShuffle);
      begin
        InternalError(2013061102);
      end;


    procedure TCG.a_opmm_ref_reg_reg(list : TAsmList;Op : TOpCG;size : TCgSize;
      const ref : TReference;src,dst : TRegister;shuffle : PMMShuffle);
      begin
        InternalError(2013061101);
      end;


    procedure TCG.g_concatcopy_move(list : TAsmList;const source,dest : TReference;len : TCGInt);
      var
        paraloc1,paraloc2,paraloc3 : TCGPara;
        pd : TProcDef;
      begin
        pd:=search_system_proc('MOVE');
        paraloc1.init;
        paraloc2.init;
        paraloc3.init;
        paramanager.getcgtempparaloc(list,pd,1,paraloc1);
        paramanager.getcgtempparaloc(list,pd,2,paraloc2);
        paramanager.getcgtempparaloc(list,pd,3,paraloc3);
        a_load_const_cgpara(list,OS_SINT,len,paraloc3);
        a_loadaddr_ref_cgpara(list,dest,paraloc2);
        a_loadaddr_ref_cgpara(list,source,paraloc1);
        paramanager.freecgpara(list,paraloc3);
        paramanager.freecgpara(list,paraloc2);
        paramanager.freecgpara(list,paraloc1);
        allocallcpuregisters(list);
        a_call_name(list,'FPC_MOVE',false);
        deallocallcpuregisters(list);
        paraloc3.done;
        paraloc2.done;
        paraloc1.done;
      end;


    procedure TCG.g_concatcopy_unaligned(list : TAsmList;const source,dest : TReference;len : TCGInt);
      begin
        g_concatcopy(list,source,dest,len);
      end;


    procedure TCG.g_overflowCheck_loc(List:TAsmList;const Loc:TLocation;def:TDef;ovloc : TLocation);
      begin
        g_overflowCheck(list,loc,def);
      end;


{$ifdef cpuflags}
    procedure TCG.g_flags2ref(list: TAsmList; size: TCgSize; const f: TResFlags; const ref:TReference);

      var
        tmpreg : TRegister;
      begin
        tmpreg:=getintregister(list,size);
        g_flags2reg(list,size,f,tmpreg);
        a_load_reg_ref(list,size,size,tmpreg,ref);
      end;
{$endif cpuflags}


{*****************************************************************************
                            Entry/Exit Code Functions
*****************************************************************************}


    procedure TCG.g_save_registers(list:TAsmList);
      var
        href : TReference;
        size : LongInt;
        r : integer;
        regs_to_save_int,
        regs_to_save_address,
        regs_to_save_mm : TCPURegisterArray;
      begin
        regs_to_save_int:=paramanager.get_saved_registers_int(CurrentProcInfo.procdef.proccalloption);
        regs_to_save_address:=paramanager.get_saved_registers_address(CurrentProcInfo.procdef.proccalloption);
        regs_to_save_mm:=paramanager.get_saved_registers_mm(CurrentProcInfo.procdef.proccalloption);
        { calculate temp. size }
        size:=0;
        for r:=low(regs_to_save_int) to high(regs_to_save_int) do
          if regs_to_save_int[r] in rg[R_INTREGISTER].used_in_proc then
            inc(size,sizeof(aint));
        if uses_registers(R_ADDRESSREGISTER) then
          for r:=low(regs_to_save_int) to high(regs_to_save_int) do
            if regs_to_save_int[r] in rg[R_ADDRESSREGISTER].used_in_proc then
              inc(size,sizeof(aint));

        { mm registers }
        if uses_registers(R_MMREGISTER) then
          begin
            { Make sure we reserve enough space to do the alignment based on the offset
              later on. We can't use the size for this, because the alignment of the start
              of the temp is smaller than needed for an OS_VECTOR }
            inc(size,tcgsize2size[OS_VECTOR]);

            for r:=low(regs_to_save_mm) to high(regs_to_save_mm) do
              if regs_to_save_mm[r] in rg[R_MMREGISTER].used_in_proc then
                inc(size,tcgsize2size[OS_VECTOR]);
          end;

        if size>0 then
          begin
            tg.GetTemp(list,size,sizeof(aint),tt_noreuse,CurrentProcInfo.save_regs_ref);
            include(CurrentProcInfo.flags,pi_has_saved_regs);

            { Copy registers to temp }
            href:=CurrentProcInfo.save_regs_ref;
            for r:=low(regs_to_save_int) to high(regs_to_save_int) do
              begin
                if regs_to_save_int[r] in rg[R_INTREGISTER].used_in_proc then
                  begin
                    a_load_reg_ref(list,OS_ADDR,OS_ADDR,newreg(R_INTREGISTER,regs_to_save_int[r],R_SUBWHOLE),href);
                    inc(href.offset,sizeof(aint));
                    include(rg[R_INTREGISTER].preserved_by_proc,regs_to_save_int[r]);
                  end;
              end;
            CurrentProcInfo.saved_regs_int := rg[R_INTREGISTER].preserved_by_proc;

            if uses_registers(R_ADDRESSREGISTER) then
              begin
                for r:=low(regs_to_save_address) to high(regs_to_save_address) do
                  begin
                    if regs_to_save_address[r] in rg[R_ADDRESSREGISTER].used_in_proc then
                      begin
                        a_load_reg_ref(list,OS_ADDR,OS_ADDR,newreg(R_ADDRESSREGISTER,regs_to_save_address[r],R_SUBWHOLE),href);
                        inc(href.offset,sizeof(aint));
                        include(rg[R_ADDRESSREGISTER].preserved_by_proc,regs_to_save_address[r]);
                      end;
                  end;

                CurrentProcInfo.saved_regs_mm := rg[R_MMREGISTER].preserved_by_proc;
              end;

            if uses_registers(R_MMREGISTER) then
              begin
                if (href.offset mod tcgsize2size[OS_VECTOR])<>0 then
                  inc(href.offset,tcgsize2size[OS_VECTOR]-(href.offset mod tcgsize2size[OS_VECTOR]));

                for r:=low(regs_to_save_mm) to high(regs_to_save_mm) do
                  begin
                    { the array has to be declared even if no MM registers are saved
                      (such as with SSE on i386), and since 0-element arrays don't
                      exist, they contain a single RS_INVALID element in that case
                    }
                    if regs_to_save_mm[r]<>RS_INVALID then
                      begin
                        if regs_to_save_mm[r] in rg[R_MMREGISTER].used_in_proc then
                          begin
                            a_loadmm_reg_ref(list,OS_VECTOR,OS_VECTOR,newreg(R_MMREGISTER,regs_to_save_mm[r],R_SUBMMWHOLE),href,nil);
                            inc(href.offset,tcgsize2size[OS_VECTOR]);
                            include(rg[R_MMREGISTER].preserved_by_proc,regs_to_save_mm[r]);
                          end;
                      end;
                  end;

                CurrentProcInfo.saved_regs_mm := rg[R_MMREGISTER].preserved_by_proc;
              end;
          end;
      end;


    procedure TCG.g_restore_registers(list:TAsmList);
      var
        href     : TReference;
        r        : integer;
        hreg     : TRegister;
        regs_to_save_int,
        regs_to_save_address,
        regs_to_save_mm : TCPURegisterArray;
      begin
        if not(pi_has_saved_regs in CurrentProcInfo.flags) then
          exit;
        regs_to_save_int:=paramanager.get_saved_registers_int(CurrentProcInfo.procdef.proccalloption);
        regs_to_save_address:=paramanager.get_saved_registers_address(CurrentProcInfo.procdef.proccalloption);
        regs_to_save_mm:=paramanager.get_saved_registers_mm(CurrentProcInfo.procdef.proccalloption);
        { Copy registers from temp }
        href:=CurrentProcInfo.save_regs_ref;
        for r:=low(regs_to_save_int) to high(regs_to_save_int) do
          if regs_to_save_int[r] in rg[R_INTREGISTER].used_in_proc then
            begin
              hreg:=newreg(R_INTREGISTER,regs_to_save_int[r],R_SUBWHOLE);
              { Allocate register so the optimizer does not remove the load }
              a_reg_alloc(list,hreg);
              a_load_ref_reg(list,OS_ADDR,OS_ADDR,href,hreg);
              inc(href.offset,sizeof(aint));
            end;

        if uses_registers(R_ADDRESSREGISTER) then
          for r:=low(regs_to_save_address) to high(regs_to_save_address) do
            if regs_to_save_address[r] in rg[R_ADDRESSREGISTER].used_in_proc then
              begin
                hreg:=newreg(R_ADDRESSREGISTER,regs_to_save_address[r],R_SUBWHOLE);
                { Allocate register so the optimizer does not remove the load }
                a_reg_alloc(list,hreg);
                a_load_ref_reg(list,OS_ADDR,OS_ADDR,href,hreg);
                inc(href.offset,sizeof(aint));
              end;

        if uses_registers(R_MMREGISTER) then
          begin
            if (href.offset mod tcgsize2size[OS_VECTOR])<>0 then
              inc(href.offset,tcgsize2size[OS_VECTOR]-(href.offset mod tcgsize2size[OS_VECTOR]));

            for r:=low(regs_to_save_mm) to high(regs_to_save_mm) do
              begin
                if regs_to_save_mm[r] in rg[R_MMREGISTER].used_in_proc then
                  begin
                    hreg:=newreg(R_MMREGISTER,regs_to_save_mm[r],R_SUBMMWHOLE);
                    { Allocate register so the optimizer does not remove the load }
                    a_reg_alloc(list,hreg);
                    a_loadmm_ref_reg(list,OS_VECTOR,OS_VECTOR,href,hreg,nil);
                    inc(href.offset,tcgsize2size[OS_VECTOR]);
                  end;
              end;
          end;
        tg.UnGetTemp(list,CurrentProcInfo.save_regs_ref);
      end;


    procedure TCG.g_adjust_self_value(list:TAsmList;procdef: TProcDef;ioffset: TCGInt);
      var
        hsym : TSym;
        href : TReference;
        paraloc : PCGParaLocation;
      begin
        { calculate the parameter info for the procdef }
        procdef.init_paraloc_info(callerside);
        hsym:=TSym(procdef.parast.Find('self'));
        if not(Assigned(hsym) and
               (hsym.typ=paravarsym)) then
          InternalError(200305251);
        paraloc:=TParaVarSym(hsym).paraloc[callerside].location;
        while paraloc<>nil do
          with paraloc^ do
            begin
              case loc of
                LOC_REGISTER:
                  a_op_const_reg(list,OP_SUB,size,ioffset,register);
                LOC_REFERENCE:
                  begin
                    { offset in the wrapper needs to be adjusted for the stored
                      return address }
                    reference_reset_base(href,reference.index,reference.offset+sizeof(PInt),ctempposinvalid,sizeof(PInt),[]);
                    a_op_const_ref(list,OP_SUB,size,ioffset,href);
                  end
                else
                  InternalError(200309189);
              end;
              paraloc:=next;
            end;
      end;


    procedure TCG.a_call_name_static(list : TAsmList;const s : string);
      begin
        a_call_name(list,s,false);
      end;


   function TCG.g_indirect_sym_load(list:TAsmList;const symname: string; const flags: TIndSymFlags): TRegister;
      var
        l: TAsmSymbol;
        ref: TReference;
        nlsymname: string;
        symtyp: TAsmsymtype;
      begin
        result := NR_NO;
        case TargetInfo.system of
          system_i386_darwin,
          system_i386_iphonesim:
            begin
              nlsymname:='L'+symname+'$non_lazy_ptr';
              l:=CurrentAsmData.getasmsymbol(nlsymname);
              if not(Assigned(l)) then
                begin
                  if is_data in flags then
                    symtyp:=AT_DATA
                  else
                    symtyp:=AT_FUNCTION;
                  new_section(CurrentAsmData.asmlists[al_picdata],sec_data_nonlazy,'',sizeof(PInt));
                  l:=CurrentAsmData.DefineAsmSymbol(nlsymname,AB_LOCAL,AT_DATA,voidpointertype);
                  CurrentAsmData.asmlists[al_picdata].concat(TAISymbol.create(l,0));
                  if not(is_weak in flags) then
                    CurrentAsmData.asmlists[al_picdata].concat(TAIDirective.Create(asd_indirect_symbol,CurrentAsmData.RefAsmSymbol(symname,symtyp).Name))
                  else
                    CurrentAsmData.asmlists[al_picdata].concat(TAIDirective.Create(asd_indirect_symbol,CurrentAsmData.WeakRefAsmSymbol(symname,symtyp).Name));
{$ifdef cpu64bitaddr}
                  CurrentAsmData.asmlists[al_picdata].concat(TAIConst.create_64bit(0));
{$else cpu64bitaddr}
                  CurrentAsmData.asmlists[al_picdata].concat(TAIConst.create_32bit(0));
{$endif cpu64bitaddr}
                end;
              result := getaddressregister(list);
              reference_reset_symbol(ref,l,0,sizeof(PInt),[]);
              { a_load_ref_reg will turn this into a pic-load if needed }
              a_load_ref_reg(list,OS_ADDR,OS_ADDR,ref,result);
            end;
          else
            ;
        end;
      end;


    procedure TCG.g_maybe_got_init(list: TAsmList);
      begin
      end;


    procedure TCG.g_maybe_tls_init(list: TAsmList);
      begin
      end;


    procedure TCG.g_call(list: TAsmList;const s: string);
      begin
        allocallcpuregisters(list);
        if systemunit<>CurrentModule.GlobalSymTable then
          CurrentModule.add_extern_asmsym(s,AB_EXTERNAL,AT_FUNCTION);
        a_call_name(list,s,false);
        deallocallcpuregisters(list);
      end;

    procedure TCG.g_local_unwind(list: TAsmList; l: TAsmLabel);
      begin
        a_jmp_always(list,l);
      end;

    procedure TCG.a_loadmm_reg_reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister; shuffle: PMMShuffle);
      begin
        InternalError(200807231);
      end;


    procedure TCG.a_loadmm_ref_reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; reg: TRegister; shuffle: PMMShuffle);
      begin
        InternalError(200807232);
      end;


    procedure TCG.a_loadmm_reg_ref(list: TAsmList; fromsize, tosize: TCgSize; reg: TRegister; const ref: TReference; shuffle: PMMShuffle);
      begin
        InternalError(200807233);
      end;


    procedure TCG.a_opmm_reg_reg(list: TAsmList; Op: TOpCG; size: TCgSize; src, dst: TRegister; shuffle: PMMShuffle);
      begin
        InternalError(200807234);
      end;


    function TCG.getflagregister(list: TAsmList; size: TCgSize): TRegister;
      begin
        Result:=TRegister(0);
        InternalError(200807238);
      end;


    procedure TCG.a_bit_scan_reg_reg(list: TAsmList; reverse,not_zero: boolean; srcsize, dstsize: TCgSize; src, dst: TRegister);
      begin
        InternalError(2014070601);
      end;


    procedure TCG.g_stackpointer_alloc(list: TAsmList; size: LongInt);
      begin
        InternalError(2014070602);
      end;


    procedure TCG.a_mul_reg_reg_pair(list: TAsmList; size: TCgSize; src1,src2,dstlo,dsthi: TRegister);
      begin
        InternalError(2014060801);
      end;


    procedure TCG.g_div_const_reg_reg(list:TAsmList; size: TCgSize; a: TCGInt; src,dst: TRegister);
      var
        divreg: TRegister;
        magic: aInt;
        u_magic: aWord;
        u_shift: byte;
        u_add: boolean;
      begin
        divreg:=getintregister(list,OS_INT);
        if (size in [OS_S32,OS_S64]) then
          begin
            calc_divconst_magic_signed(tcgsize2size[size]*8,a,magic,u_shift);
            { load magic value }
            a_load_const_reg(list,OS_INT,magic,divreg);
            { multiply, discarding low bits }
            a_mul_reg_reg_pair(list,size,src,divreg,NR_NO,dst);
            { add/subtract numerator }
            if (a>0) and (magic<0) then
              a_op_reg_reg_reg(list,OP_ADD,OS_INT,src,dst,dst)
            else if (a<0) and (magic>0) then
              a_op_reg_reg_reg(list,OP_SUB,OS_INT,src,dst,dst);
            { shift shift places to the right (arithmetic) }
            a_op_const_reg_reg(list,OP_SAR,OS_INT,u_shift,dst,dst);
            { extract and add sign bit }
            if (a>=0) then
              a_op_const_reg_reg(list,OP_SHR,OS_INT,tcgsize2size[size]*8-1,src,divreg)
            else
              a_op_const_reg_reg(list,OP_SHR,OS_INT,tcgsize2size[size]*8-1,dst,divreg);
            a_op_reg_reg_reg(list,OP_ADD,OS_INT,dst,divreg,dst);
          end
        else if (size in [OS_32,OS_64]) then
          begin
            calc_divconst_magic_unsigned(tcgsize2size[size]*8,a,u_magic,u_add,u_shift);
            { load magic in divreg }
            a_load_const_reg(list,OS_INT,TCGInt(u_magic),divreg);
            { multiply, discarding low bits }
            a_mul_reg_reg_pair(list,size,src,divreg,NR_NO,dst);
            if (u_add) then
              begin
                { Calculate "(numerator+result) shr u_shift", avoiding possible overflow }
                a_op_reg_reg_reg(list,OP_SUB,OS_INT,dst,src,divreg);
                { divreg=(numerator-result) }
                a_op_const_reg_reg(list,OP_SHR,OS_INT,1,divreg,divreg);
                { divreg=(numerator-result)/2 }
                a_op_reg_reg_reg(list,OP_ADD,OS_INT,divreg,dst,divreg);
                { divreg=(numerator+result)/2, already shifted by 1, so decrease u_shift. }
                a_op_const_reg_reg(list,OP_SHR,OS_INT,u_shift-1,divreg,dst);
              end
            else
              a_op_const_reg_reg(list,OP_SHR,OS_INT,u_shift,dst,dst);
          end
        else
          InternalError(2014060601);
      end;


    procedure TCG.g_check_for_fpu_exception(list: TAsmList;force,clear : boolean);
      begin
        { empty by default }
      end;


    procedure TCG.maybe_check_for_fpu_exception(list: TAsmList);
      begin
        CurrentProcInfo.FPUExceptionCheckNeeded:=true;
        g_check_for_fpu_exception(list,false,true);
      end;


    procedure TCG.adjust_exceptfilter_ref(var ref: TReference; for_finalization: boolean);
      begin
        { empty by default, override in CPU-specific code generator }
      end;

{*****************************************************************************
                                    TCG64
*****************************************************************************}

{$ifndef cpu64bitalu}
    function joinreg64(reglo,reghi : TRegister) : TRegister64;
      begin
         result.reglo:=reglo;
         result.reghi:=reghi;
      end;


    procedure TCG64.a_op64_const_reg_reg(list: TAsmList;op:TOpCG;size : TCgSize;value : int64; regsrc,regdst : TRegister64);
      begin
        a_load64_reg_reg(list,regsrc,regdst);
        a_op64_const_reg(list,op,size,value,regdst);
      end;


    procedure TCG64.a_op64_reg_reg_reg(list: TAsmList;op:TOpCG;size : TCgSize;regsrc1,regsrc2,regdst : TRegister64);
      var
        tmpreg64 : TRegister64;
      begin
        { when src1=dst then we need to first create a temp to prevent
          overwriting src1 with src2 }
        if (regsrc1.reghi=regdst.reghi) or
           (regsrc1.reglo=regdst.reghi) or
           (regsrc1.reghi=regdst.reglo) or
           (regsrc1.reglo=regdst.reglo) then
          begin
            tmpreg64.reglo:=cg.getintregister(list,OS_32);
            tmpreg64.reghi:=cg.getintregister(list,OS_32);
            a_load64_reg_reg(list,regsrc2,tmpreg64);
            a_op64_reg_reg(list,op,size,regsrc1,tmpreg64);
            a_load64_reg_reg(list,tmpreg64,regdst);
          end
        else
          begin
            a_load64_reg_reg(list,regsrc2,regdst);
            a_op64_reg_reg(list,op,size,regsrc1,regdst);
          end;
      end;


    procedure TCG64.a_op64_const_subsetref(list : TAsmList; Op : TOpCG; size : TCgSize; a : int64; const sref: TSubsetReference);
      var
        tmpreg64 : TRegister64;
      begin
        tmpreg64.reglo:=cg.getintregister(list,OS_32);
        tmpreg64.reghi:=cg.getintregister(list,OS_32);
        a_load64_subsetref_reg(list,sref,tmpreg64);
        a_op64_const_reg(list,op,size,a,tmpreg64);
        a_load64_reg_subsetref(list,tmpreg64,sref);
      end;


    procedure TCG64.a_op64_reg_subsetref(list : TAsmList; Op : TOpCG; size : TCgSize; reg: TRegister64; const sref: TSubsetReference);
      var
        tmpreg64 : TRegister64;
      begin
        tmpreg64.reglo:=cg.getintregister(list,OS_32);
        tmpreg64.reghi:=cg.getintregister(list,OS_32);
        a_load64_subsetref_reg(list,sref,tmpreg64);
        a_op64_reg_reg(list,op,size,reg,tmpreg64);
        a_load64_reg_subsetref(list,tmpreg64,sref);
      end;


    procedure TCG64.a_op64_ref_subsetref(list : TAsmList; Op : TOpCG; size : TCgSize; const ref: TReference; const sref: TSubsetReference);
      var
        tmpreg64 : TRegister64;
      begin
        tmpreg64.reglo:=cg.getintregister(list,OS_32);
        tmpreg64.reghi:=cg.getintregister(list,OS_32);
        a_load64_subsetref_reg(list,sref,tmpreg64);
        a_op64_ref_reg(list,op,size,ref,tmpreg64);
        a_load64_reg_subsetref(list,tmpreg64,sref);
      end;


    procedure TCG64.a_op64_subsetref_subsetref(list : TAsmList; Op : TOpCG; size : TCgSize; const ssref,dsref: TSubsetReference);
      var
        tmpreg64 : TRegister64;
      begin
        tmpreg64.reglo:=cg.getintregister(list,OS_32);
        tmpreg64.reghi:=cg.getintregister(list,OS_32);
        a_load64_subsetref_reg(list,ssref,tmpreg64);
        a_op64_reg_subsetref(list,op,size,tmpreg64,dsref);
      end;


    procedure TCG64.a_op64_const_reg_reg_checkoverflow(list: TAsmList;op:TOpCG;size : TCgSize;value : int64;regsrc,regdst : TRegister64;setflags : boolean;var ovloc : TLocation);
      begin
        a_op64_const_reg_reg(list,op,size,value,regsrc,regdst);
        ovloc.loc:=LOC_VOID;
      end;


    procedure TCG64.a_op64_reg_reg_reg_checkoverflow(list: TAsmList;op:TOpCG;size : TCgSize;regsrc1,regsrc2,regdst : TRegister64;setflags : boolean;var ovloc : TLocation);
      begin
        a_op64_reg_reg_reg(list,op,size,regsrc1,regsrc2,regdst);
        ovloc.loc:=LOC_VOID;
      end;


    procedure TCG64.a_op64_reg(list: TAsmList; op: TOpCG; size: TCgSize; regdst: TRegister64);
      begin
        if not (op in [OP_NOT,OP_NEG]) then
          InternalError(2020050706);
        a_op64_reg_reg(list,op,size,regdst,regdst);
      end;


    procedure TCG64.a_op64_ref(list: TAsmList; op: TOpCG; size: TCgSize; const ref: TReference);
      var
        tempreg: TRegister64;
      begin
        if not (op in [OP_NOT,OP_NEG]) then
          InternalError(2020050713);
        tempreg.reghi:=cg.getintregister(list,OS_32);
        tempreg.reglo:=cg.getintregister(list,OS_32);
        a_load64_ref_reg(list,ref,tempreg);
        a_op64_reg_reg(list,op,size,tempreg,tempreg);
        a_load64_reg_ref(list,tempreg,ref);
      end;


    procedure TCG64.a_op64_loc(list: TAsmList; op: TOpCG; size: TCgSize; const l: TLocation);
      begin
        case l.loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            a_op64_ref(list,op,size,l.reference);
          LOC_REGISTER,LOC_CREGISTER:
            a_op64_reg(list,op,size,l.register64);
          else
            InternalError(2020050707);
        end;
      end;


    procedure TCG64.a_load64_loc_subsetref(list : TAsmList;const l: TLocation; const sref : TSubsetReference);
      begin
        case l.loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            a_load64_ref_subsetref(list,l.reference,sref);
          LOC_REGISTER,LOC_CREGISTER:
            a_load64_reg_subsetref(list,l.register64,sref);
          LOC_CONSTANT :
            a_load64_const_subsetref(list,l.value64,sref);
          LOC_SUBSETREF,LOC_CSUBSETREF:
            a_load64_subsetref_subsetref(list,l.sref,sref);
          else
            InternalError(2006082210);
        end;
      end;


    procedure TCG64.a_load64_subsetref_loc(list: TAsmList; const sref: TSubsetReference; const l: TLocation);
      begin
        case l.loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            a_load64_subsetref_ref(list,sref,l.reference);
          LOC_REGISTER,LOC_CREGISTER:
            a_load64_subsetref_reg(list,sref,l.register64);
          LOC_SUBSETREF,LOC_CSUBSETREF:
            a_load64_subsetref_subsetref(list,sref,l.sref);
          else
            InternalError(2006082211);
        end;
      end;
{$else cpu64bitalu}

    function joinreg128(reglo, reghi: TRegister): TRegister128;
      begin
        result.reglo:=reglo;
        result.reghi:=reghi;
      end;


    procedure splitparaloc128(const cgpara:TCGPara;var cgparalo,cgparahi:TCGPara);
      var
        paraloclo,
        paralochi : PCGParaLocation;
      begin
        if not(cgpara.size in [OS_128,OS_S128]) then
          InternalError(2012090604);
        if not Assigned(cgpara.location) then
          InternalError(2012090605);
        { init lo/hi para }
        cgparahi.reset;
        if cgpara.size=OS_S128 then
          cgparahi.size:=OS_S64
        else
          cgparahi.size:=OS_64;
        cgparahi.intsize:=8;
        cgparahi.alignment:=cgpara.alignment;
        paralochi:=cgparahi.add_location;
        cgparalo.reset;
        cgparalo.size:=OS_64;
        cgparalo.intsize:=8;
        cgparalo.alignment:=cgpara.alignment;
        paraloclo:=cgparalo.add_location;
        { 2 parameter fields? }
        if Assigned(cgpara.location^.next) then
          begin
            { Order for multiple locations is always
                paraloc^ -> high
                paraloc^.next -> low }
            if (TargetInfo.endian=ENDIAN_BIG) then
              begin
                { paraloc^ -> high
                  paraloc^.next -> low }
                move(cgpara.location^,paralochi^,sizeof(paralochi^));
                move(cgpara.location^.next^,paraloclo^,sizeof(paraloclo^));
              end
            else
              begin
                { paraloc^ -> low
                  paraloc^.next -> high }
                move(cgpara.location^,paraloclo^,sizeof(paraloclo^));
                move(cgpara.location^.next^,paralochi^,sizeof(paralochi^));
              end;
          end
        else
          begin
            { single parameter, this can only be in memory }
            if cgpara.location^.loc<>LOC_REFERENCE then
              InternalError(2012090606);
            move(cgpara.location^,paraloclo^,sizeof(paraloclo^));
            move(cgpara.location^,paralochi^,sizeof(paralochi^));
            { for big endian low is at +8, for little endian high }
            if TargetInfo.endian = endian_big then
              begin
                inc(cgparalo.location^.reference.offset,8);
                cgparalo.alignment:=NewAlignment(cgparalo.alignment,8);
              end
            else
              begin
                inc(cgparahi.location^.reference.offset,8);
                cgparahi.alignment:=NewAlignment(cgparahi.alignment,8);
              end;
          end;
        { fix size }
        paraloclo^.size:=cgparalo.size;
        paraloclo^.next:=nil;
        paralochi^.size:=cgparahi.size;
        paralochi^.next:=nil;
      end;


    procedure TCG128.a_load128_reg_reg(list: TAsmList; regsrc,
      regdst: TRegister128);
      begin
        cg.a_load_reg_reg(list,OS_64,OS_64,regsrc.reglo,regdst.reglo);
        cg.a_load_reg_reg(list,OS_64,OS_64,regsrc.reghi,regdst.reghi);
      end;


    procedure TCG128.a_load128_reg_ref(list: TAsmList; reg: TRegister128;
      const ref: TReference);
      var
        tmpreg: TRegister;
        tmpref: TReference;
      begin
        if TargetInfo.endian = endian_big then
          begin
            tmpreg:=reg.reglo;
            reg.reglo:=reg.reghi;
            reg.reghi:=tmpreg;
          end;
        cg.a_load_reg_ref(list,OS_64,OS_64,reg.reglo,ref);
        tmpref := ref;
        inc(tmpref.offset,8);
        cg.a_load_reg_ref(list,OS_64,OS_64,reg.reghi,tmpref);
      end;


    procedure TCG128.a_load128_ref_reg(list: TAsmList; const ref: TReference;
      reg: TRegister128);
      var
        tmpreg: TRegister;
        tmpref: TReference;
      begin
        if TargetInfo.endian = endian_big then
          begin
            tmpreg := reg.reglo;
            reg.reglo := reg.reghi;
            reg.reghi := tmpreg;
          end;
        tmpref := ref;
        if (tmpref.base=reg.reglo) then
         begin
           tmpreg:=cg.getaddressregister(list);
           cg.a_load_reg_reg(list,OS_ADDR,OS_ADDR,tmpref.base,tmpreg);
           tmpref.base:=tmpreg;
         end
        else
         { this works only for the i386, thus the i386 needs to override  }
         { this method and this method must be replaced by a more generic }
         { implementation FK                                              }
         if (tmpref.index=reg.reglo) then
          begin
            tmpreg:=cg.getaddressregister(list);
            cg.a_load_reg_reg(list,OS_ADDR,OS_ADDR,tmpref.index,tmpreg);
            tmpref.index:=tmpreg;
          end;
        cg.a_load_ref_reg(list,OS_64,OS_64,tmpref,reg.reglo);
        inc(tmpref.offset,8);
        cg.a_load_ref_reg(list,OS_64,OS_64,tmpref,reg.reghi);
      end;


    procedure TCG128.a_load128_loc_ref(list: TAsmList; const l: TLocation;
      const ref: TReference);
      begin
        case l.loc of
          LOC_REGISTER,LOC_CREGISTER:
            a_load128_reg_ref(list,l.register128,ref);
          { not yet implemented:
          LOC_CONSTANT :
            a_load128_const_ref(list,l.value128,ref);
          LOC_SUBSETREF, LOC_CSUBSETREF:
            a_load64_subsetref_ref(list,l.sref,ref); }
          else
            InternalError(201209061);
        end;
      end;


    procedure TCG128.a_load128_reg_loc(list: TAsmList; reg: TRegister128;
      const l: TLocation);
      begin
        case l.loc of
          LOC_REFERENCE, LOC_CREFERENCE:
            a_load128_reg_ref(list,reg,l.reference);
          LOC_REGISTER,LOC_CREGISTER:
            a_load128_reg_reg(list,reg,l.register128);
          { not yet implemented:
          LOC_SUBSETREF, LOC_CSUBSETREF:
            a_load64_reg_subsetref(list,reg,l.sref);
          LOC_MMREGISTER, LOC_CMMREGISTER:
            a_loadmm_intreg64_reg(list,l.size,reg,l.register); }
          else
            InternalError(201209062);
        end;
      end;

    procedure TCG128.a_load128_const_reg(list: TAsmList; valuelo,
     valuehi: int64; reg: TRegister128);
     begin
       cg.a_load_const_reg(list,OS_64,aint(valuelo),reg.reglo);
       cg.a_load_const_reg(list,OS_64,aint(valuehi),reg.reghi);
     end;


    procedure TCG128.a_load128_loc_cgpara(list: TAsmList; const l: TLocation;
      const paraloc: TCGPara);
      begin
        case l.loc of
          LOC_REGISTER,
          LOC_CREGISTER :
            a_load128_reg_cgpara(list,l.register128,paraloc);
          {not yet implemented:
          LOC_CONSTANT :
            a_load128_const_cgpara(list,l.value64,paraloc);
          }
          LOC_CREFERENCE,
          LOC_REFERENCE :
            a_load128_ref_cgpara(list,l.reference,paraloc);
          else
            InternalError(2012090603);
        end;
      end;


    procedure TCG128.a_load128_reg_cgpara(list : TAsmList;reg : TRegister128;const paraloc : TCGPara);
      var
        tmplochi,tmploclo: TCGPara;
      begin
        tmploclo.init;
        tmplochi.init;
        splitparaloc128(paraloc,tmploclo,tmplochi);
        cg.a_load_reg_cgpara(list,OS_64,reg.reghi,tmplochi);
        cg.a_load_reg_cgpara(list,OS_64,reg.reglo,tmploclo);
        tmploclo.done;
        tmplochi.done;
      end;


    procedure TCG128.a_load128_ref_cgpara(list : TAsmList;const r : TReference;const paraloc : TCGPara);
      var
        tmprefhi,tmpreflo : TReference;
        tmploclo,tmplochi : TCGPara;
      begin
        tmploclo.init;
        tmplochi.init;
        splitparaloc128(paraloc,tmploclo,tmplochi);
        tmprefhi:=r;
        tmpreflo:=r;
        if TargetInfo.endian=endian_big then
          inc(tmpreflo.offset,8)
        else
          inc(tmprefhi.offset,8);
        cg.a_load_ref_cgpara(list,OS_64,tmprefhi,tmplochi);
        cg.a_load_ref_cgpara(list,OS_64,tmpreflo,tmploclo);
        tmploclo.done;
        tmplochi.done;
      end;
{$endif cpu64bitalu}

    function asmsym2indsymflags(sym: TAsmSymbol): TIndSymFlags;
      begin
        result:=[];
        if sym.typ<>AT_FUNCTION then
          include(result,is_data);
        if sym.bind=AB_WEAK_EXTERNAL then
          include(result,is_weak);
      end;

    procedure destroy_codegen;
      begin
        cg.free;
        cg:=nil;
{$ifdef cpu64bitalu}
        cg128.free;
        cg128:=nil;
{$else cpu64bitalu}
        cg64.free;
        cg64:=nil;
{$endif cpu64bitalu}
      end;

end.
