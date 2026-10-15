{
    Copyright (c) 1998-2010 by Florian Klaempfl and Jonas Maebe
    Member of the Free Pascal development team

    This unit implements the basic high level code generator object

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
   Abstract high level code generator unit. This contains the base class
   that either lowers most code to the regular code generator, or that
   has to be implemented/overridden for higher level targets (such as LLVM).
}
unit hlcgobj;

{$i fpcdefs.inc}

{ define hlcginline}

  interface

    uses
       CClasses,GlobType,ConstExp,
       cpubase,cgbase,cgutils,parabase,
       aasmbase,aasmtai,AAsmData,aasmcpu,
       symconst,SymBase,symtype,SymSym,symdef,
       node,nutils,
       tgobj
       ;

    type
       TSubsetLoadOpt = (SL_REG,SL_REGNOSRCMASK,SL_SETZERO,SL_SETMAX);

       PReplaceRegRec = ^TReplaceRegRec;
       TReplaceRegRec = record
         old, new: TRegister;
         oldhi, newhi: TRegister;
         ressym: TSym;
         { moved sym }
         sym : TAbstractNormalVarSym;
       end;

       { thlcgobj methods that may have to be overridden by non-descendants }
       THLCGObjHelpers = class
         class procedure gen_proc_symbol(list:TAsmList);virtual;
         { queue the code/data generated for a procedure for writing out to
           the assembler/object file }
         class procedure record_generated_code_for_procdef(pd: TProcDef; code, data: TAsmList); virtual;
       end;
       THLCGObjHelpersClass = class of THLCGObjHelpers;

       {# @abstract(Abstract high level code generator)
          This class implements an abstract instruction generator. All
          methods of this class are generic and are mapped to low level code
          generator methods by default. They have to be overridden for higher
          level targets
       }

       { thlcgobj }

       THLCGObj = class
       protected
        fphlcgobjhelper: THLCGObjHelpersClass;
       public
          {************************************************}
          {                 basic routines                 }
          constructor create; virtual;
          constructor create(hlcgobjhelpers: THLCGObjHelpersClass);

          {# Initialize the register allocators needed for the codegenerator.}
          procedure init_register_allocators;virtual;
          {# Clean up the register allocators needed for the codegenerator.}
          procedure done_register_allocators;virtual;
          {# Set whether live_start or live_end should be updated when allocating registers, needed when e.g. generating initcode after the rest of the code. }
          procedure set_regalloc_live_range_direction(dir: TRADirection);virtual;
          {# Gets a register suitable to do integer operations on.}
          function getintregister(list:TAsmList;size:TDef):TRegister;virtual;
          {# Gets a register suitable to do integer operations on.}
          function getaddressregister(list:TAsmList;size:TDef):TRegister;virtual;
          function getfpuregister(list:TAsmList;size:TDef):TRegister;virtual;
          { warning: only works correctly for fpu types currently }
          function getmmregister(list:TAsmList;size:TDef):TRegister;virtual;
          function getflagregister(list:TAsmList;size:TDef):TRegister;virtual;
          function gettempregister(list:TAsmList;size:TDef):TRegister;virtual;
          function getregisterfordef(list: TAsmList;size:TDef):TRegister;virtual;
          {Does the generic cg need SIMD registers, like getmmxregister? Or should
           the cpu specific child cg object have such a method?}

          function  uses_registers(rt:TRegisterType):boolean; inline;
          {# Get a specific register.}
          procedure getcpuregister(list:TAsmList;r:TRegister);virtual;
          procedure ungetcpuregister(list:TAsmList;r:TRegister);virtual;
          {# Get multiple registers specified.}
          procedure alloccpuregisters(list:TAsmList;rt:TRegisterType;const r:TCPURegisterSet);virtual;
          {# Free multiple registers specified.}
          procedure dealloccpuregisters(list:TAsmList;rt:TRegisterType;const r:TCPURegisterSet);virtual;

          procedure allocallcpuregisters(list:TAsmList);virtual;
          procedure deallocallcpuregisters(list:TAsmList);virtual;

          procedure do_register_allocation(list:TAsmList;headertai:TAI); inline;
          procedure translate_register(var reg : TRegister); inline;

          {# Returns the kind of register this type should be loaded in (it does not
             check whether this is actually possible, but if it's loaded in a register
             by the compiler for any purpose other than parameter passing/function
             result loading, this is the register type used) }
          class function def2regtyp(def: TDef): TRegisterType; virtual;

          {# Returns a reference with its base address set from a pointer that
             has been loaded in a register.

             A generic version is provided. This routine should be overridden
             on platforms which support pointers with different sizes (for
             example i8086 near and far pointers) or require some other sort of
             special consideration when converting a pointer in a register to a
             reference.

             @param(ref where the result is returned)
             @param(regsize the type of the pointer, contained in the reg parameter)
             @param(reg register containing the value of a pointer)
          }
          procedure reference_reset_base(var ref: TReference; regsize: TDef; reg: TRegister; offset: LongInt; temppos: TRefTempPos; alignment: LongInt; volatility: TVolatilitySet); virtual;

          {# Emit a label to the instruction stream. }
          procedure a_label(list : TAsmList;l : TAsmLabel); inline;
          {# Emit a label that can be a target of a Pascal goto statement to the instruction stream. }
          procedure a_label_pascal_goto_target(list : TAsmList;l : TAsmLabel); inline;

          {# Allocates register r by inserting a pai_realloc record }
          procedure a_reg_alloc(list : TAsmList;r : TRegister); inline;
          {# Deallocates register r by inserting a pa_regdealloc record}
          procedure a_reg_dealloc(list : TAsmList;r : TRegister); inline;
          { Synchronize register, make sure it is still valid }
          procedure a_reg_sync(list : TAsmList;r : TRegister); inline;

          {# Pass a parameter, which is located in a register, to a routine.

             This routine should push/send the parameter to the routine, as
             required by the specific processor ABI and routine modifiers.
             It must generate register allocation information for the cgpara in
             case it consists of cpuregisters.

             @param(size size of the operand in the register)
             @param(r register source of the operand)
             @param(cgpara where the parameter will be stored)
          }
          procedure a_load_reg_cgpara(list : TAsmList;size : TDef;r : TRegister;const cgpara : TCGPara);virtual;
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
          procedure a_load_const_cgpara(list : TAsmList;tosize : TDef;a : TCGInt;const cgpara : TCGPara);virtual;
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
          procedure a_load_ref_cgpara(list : TAsmList;size : TDef;const r : TReference;const cgpara : TCGPara);virtual;
          {# Pass the value of a parameter, which can be located either in a register or memory location,
             to a routine.

             A generic version is provided.

             @param(l location of the operand to send)
             @param(nr parameter number (starting from one) of routine (from left to right))
             @param(cgpara where the parameter will be stored)
          }
          procedure a_load_loc_cgpara(list : TAsmList;size : TDef; const l : TLocation;const cgpara : TCGPara);virtual;
          {# Pass the address of a reference to a routine. This routine
             will calculate the address of the reference, and pass this
             calculated address as a parameter.
             It must generate register allocation information for the cgpara in
             case it consists of cpuregisters.

             A generic version is provided. This routine should
             be overridden for optimization purposes if the cpu
             permits directly sending this type of parameter.

             @param(fromsize type of the reference we are taking the address of)
             @param(tosize type of the pointer that we get as a result)
             @param(r reference to get address from)
          }
          procedure a_loadaddr_ref_cgpara(list : TAsmList;fromsize : TDef;const r : TReference;const cgpara : TCGPara);virtual;
          {# Pass an undefined value as a parameter to a routine.
             A generic version is provided and passes the 0/nil value
             if the parameter's location is not a register.
          }
          procedure a_load_undefined_cgpara(list : TAsmList;size : TDef;const cgpara : TCGPara);virtual;

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
             Returns the function result location.
             This routine must be overridden for each new target cpu.
          }
          function a_call_name(list : TAsmList;pd : TProcDef;const s : TSymStr; const paras: array of PCGPara; forceresdef: TDef; weak: boolean): TCGPara;virtual;abstract;
          function a_call_reg(list : TAsmList;pd : TAbstractProcDef;reg : TRegister; const paras: array of PCGPara): TCGPara;virtual;abstract;
          { same as a_call_name, might be overridden on certain architectures to emit
            static calls without usage of a got trampoline }
          function a_call_name_static(list : TAsmList;pd : TProcDef;const s : TSymStr; const paras: array of PCGPara; forceresdef: TDef): TCGPara;virtual;
          { same as a_call_name, might be overridden on certain architectures to emit
            special static calls for inherited methods }
          function a_call_name_inherited(list : TAsmList;pd : TProcDef;const s : TSymStr; const paras: array of PCGPara): TCGPara;virtual;

          { move instructions }
          procedure a_load_const_reg(list : TAsmList;tosize : TDef;a : TCGInt;register : TRegister);virtual;abstract;
          procedure a_load_const_ref(list : TAsmList;tosize : TDef;a : TCGInt;const ref : TReference);virtual;
          procedure a_load_const_loc(list : TAsmList;tosize : TDef;a : TCGInt;const loc : TLocation);virtual;
          procedure a_load_reg_ref(list : TAsmList;fromsize, tosize : TDef;register : TRegister;const ref : TReference);virtual;abstract;
          procedure a_load_reg_ref_unaligned(list : TAsmList;fromsize, tosize : TDef;register : TRegister;const ref : TReference);virtual;
          procedure a_load_reg_reg(list : TAsmList;fromsize, tosize : TDef;reg1,reg2 : TRegister);virtual;abstract;
          procedure a_load_reg_loc(list : TAsmList;fromsize, tosize : TDef;reg : TRegister;const loc: TLocation);virtual;
          procedure a_load_ref_reg(list : TAsmList;fromsize, tosize : TDef;const ref : TReference;register : TRegister);virtual;abstract;
          procedure a_load_ref_reg_unaligned(list : TAsmList;fromsize, tosize : TDef;const ref : TReference;register : TRegister);virtual;
          procedure a_load_ref_ref(list : TAsmList;fromsize, tosize : TDef;const sref : TReference;const dref : TReference);virtual;
          procedure a_load_loc_reg(list : TAsmList;fromsize, tosize : TDef; const loc: TLocation; reg : TRegister);virtual;
          procedure a_load_loc_ref(list : TAsmList;fromsize, tosize: TDef; const loc: TLocation; const ref : TReference);virtual;
          procedure a_load_loc_subsetreg(list : TAsmList;fromsize, tosubsetsize: TDef; const loc: TLocation; const sreg : TSubsetRegister);virtual;
          procedure a_load_loc_subsetref(list : TAsmList;fromsize, tosubsetsize: TDef; const loc: TLocation; const sref : TSubsetReference);virtual;
          procedure a_loadaddr_ref_reg(list : TAsmList;fromsize, tosize : TDef;const ref : TReference;r : TRegister);virtual;abstract;

          { For subsetreg/ref, the def is the size of the packed element. The
            size of the register that holds the data is a tcgsize, and hence
            always must be an orddef of the corresponding size in practice }
          procedure a_load_subsetreg_reg(list : TAsmList; subsetsize, tosize: TDef; const sreg: TSubsetRegister; destreg: TRegister); virtual;
          procedure a_load_reg_subsetreg(list : TAsmList; fromsize, tosubsetsize: TDef; fromreg: TRegister; const sreg: TSubsetRegister); virtual;
          procedure a_load_subsetreg_subsetreg(list: TAsmList; fromsubsetsize, tosubsetsize : TDef; const fromsreg, tosreg: TSubsetRegister); virtual;
          procedure a_load_subsetreg_ref(list : TAsmList; fromsubsetsize, tosize: TDef; const sreg: TSubsetRegister; const destref: TReference); virtual;
          procedure a_load_ref_subsetreg(list : TAsmList; fromsize, tosubsetsize: TDef; const fromref: TReference; const sreg: TSubsetRegister); virtual;
          procedure a_load_const_subsetreg(list: TAsmList; tosubsetsize: TDef; a: TCGInt; const sreg: TSubsetRegister); virtual;
          procedure a_load_subsetreg_loc(list: TAsmList; fromsubsetsize, tosize: TDef; const sreg: TSubsetRegister; const loc: TLocation); virtual;

          procedure a_load_subsetref_reg(list : TAsmList; fromsubsetsize, tosize: TDef; const sref: TSubsetReference; destreg: TRegister); virtual;
          procedure a_load_reg_subsetref(list : TAsmList; fromsize, tosubsetsize: TDef; fromreg: TRegister; const sref: TSubsetReference); virtual;
          procedure a_load_subsetref_subsetref(list: TAsmList; fromsubsetsize, tosubsetsize : TDef; const fromsref, tosref: TSubsetReference); virtual;
          procedure a_load_subsetref_ref(list : TAsmList; fromsubsetsize, tosize: TDef; const sref: TSubsetReference; const destref: TReference); virtual;
          procedure a_load_ref_subsetref(list : TAsmList; fromsize, tosubsetsize: TDef; const fromref: TReference; const sref: TSubsetReference); virtual;
          procedure a_load_const_subsetref(list: TAsmList; tosubsetsize: TDef; a: TCGInt; const sref: TSubsetReference); virtual;
          procedure a_load_subsetref_loc(list: TAsmList; fromsubsetsize, tosize: TDef; const sref: TSubsetReference; const loc: TLocation); virtual;
          procedure a_load_subsetref_subsetreg(list: TAsmList; fromsubsetsize, tosubsetsize : TDef; const fromsref: TSubsetReference; const tosreg: TSubsetRegister); virtual;
          procedure a_load_subsetreg_subsetref(list: TAsmList; fromsubsetsize, tosubsetsize : TDef; const fromsreg: TSubsetRegister; const tosref: TSubsetReference); virtual;

          { bit test instructions }
          procedure a_bit_test_reg_reg_reg(list : TAsmList; bitnumbersize,valuesize,destsize: TDef;bitnumber,value,destreg: TRegister); virtual;
          procedure a_bit_test_const_ref_reg(list: TAsmList; fromsize, destsize: TDef; bitnumber: aint; const ref: TReference; destreg: TRegister); virtual;
          procedure a_bit_test_const_reg_reg(list: TAsmList; setregsize, destsize: TDef; bitnumber: aint; setreg, destreg: TRegister); virtual;
          procedure a_bit_test_const_subsetreg_reg(list: TAsmList; fromsubsetsize, destsize: TDef; bitnumber: aint; const setreg: TSubsetRegister; destreg: TRegister); virtual;
          procedure a_bit_test_reg_ref_reg(list: TAsmList; bitnumbersize, refsize, destsize: TDef; bitnumber: TRegister; const ref: TReference; destreg: TRegister); virtual;
          procedure a_bit_test_reg_loc_reg(list: TAsmList; bitnumbersize, locsize, destsize: TDef; bitnumber: TRegister; const loc: TLocation; destreg: TRegister);virtual;
          procedure a_bit_test_const_loc_reg(list: TAsmList; locsize, destsize: TDef; bitnumber: aint; const loc: TLocation; destreg: TRegister);virtual;

          { bit set/clear instructions }
          procedure a_bit_set_reg_reg(list : TAsmList; doset: boolean; bitnumbersize, destsize: TDef; bitnumber,dest: TRegister); virtual;
          procedure a_bit_set_const_ref(list: TAsmList; doset: boolean;destsize: TDef; bitnumber: TCGInt; const ref: TReference); virtual;
          procedure a_bit_set_const_reg(list: TAsmList; doset: boolean; destsize: TDef; bitnumber: TCGInt; destreg: TRegister); virtual;
          procedure a_bit_set_const_subsetreg(list: TAsmList; doset: boolean; destsize: TDef; bitnumber: TCGInt; const destreg: TSubsetRegister); virtual;
          procedure a_bit_set_reg_ref(list: TAsmList; doset: boolean; fromsize, tosize: TDef; bitnumber: TRegister; const ref: TReference); virtual;
          procedure a_bit_set_reg_loc(list: TAsmList; doset: boolean; regsize, tosize: TDef; bitnumber: TRegister; const loc: TLocation);virtual;
          procedure a_bit_set_const_loc(list: TAsmList; doset: boolean; tosize: TDef; bitnumber: TCGInt; const loc: TLocation);virtual;

          function  get_call_result_cgpara(pd: TAbstractProcDef; forceresdef: TDef): TCGPara; virtual;
         protected
           procedure get_subsetref_load_info(const sref: TSubsetReference; out loadsize: TOrdDef; out extra_load: boolean);
           procedure a_load_subsetref_regs_noindex(list: TAsmList; subsetsize: TDef; loadbitsize: byte; const sref: TSubsetReference; valuereg, extra_value_reg: TRegister); virtual;
           procedure a_load_subsetref_regs_index(list: TAsmList; subsetsize: TDef; loadbitsize: byte; const sref: TSubsetReference; valuereg: TRegister); virtual;

           procedure a_load_regconst_subsetref_intern(list : TAsmList; fromsize, subsetsize: TDef; fromreg: TRegister; const sref: TSubsetReference; slopt: TSubsetLoadOpt); virtual;
           procedure a_load_regconst_subsetreg_intern(list : TAsmList; fromsize, subsetsize: TDef; fromreg: TRegister; const sreg: TSubsetRegister; slopt: TSubsetLoadOpt); virtual;

           { return a subsetref that represents bit "bitnumber" in ref, if ref
             has the type "refdef". The subsetref must be addressable via
             (unsigned) 8 bit access, unless all the *_bit_* methods are
             overloaded and use something else. }
           function get_bit_const_ref_sref(bitnumber: TCGInt; refdef: TDef; const ref: TReference): TSubsetReference;
           function get_bit_const_reg_sreg(setregsize: TDef; bitnumber: TCGInt; setreg: TRegister): TSubsetRegister;
           function get_bit_reg_ref_sref(list: TAsmList; bitnumbersize, refsize: TDef; bitnumber: TRegister; const ref: TReference): TSubsetReference;
         public

          { bit scan instructions (still need transformation to thlcgobj) }
          procedure a_bit_scan_reg_reg(list: TAsmList; reverse,not_zero: boolean; srcsize, dstsize: TDef; src, dst: TRegister); virtual; abstract;

          { fpu move instructions }
          procedure a_loadfpu_reg_reg(list: TAsmList; fromsize, tosize: TDef; reg1, reg2: TRegister); virtual; abstract;
          procedure a_loadfpu_ref_reg(list: TAsmList; fromsize, tosize: TDef; const ref: TReference; reg: TRegister); virtual; abstract;
          procedure a_loadfpu_reg_ref(list: TAsmList; fromsize, tosize: TDef; reg: TRegister; const ref: TReference); virtual; abstract;
          procedure a_loadfpu_ref_ref(list: TAsmList; fromsize, tosize: TDef; const ref1,ref2: TReference);virtual;
          procedure a_loadfpu_loc_reg(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; const reg: TRegister);virtual;
          procedure a_loadfpu_loc_ref(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; const ref: TReference);virtual;
          procedure a_loadfpu_reg_loc(list: TAsmList; fromsize, tosize: TDef; const reg: TRegister; const loc: TLocation);virtual;
          procedure a_loadfpu_reg_cgpara(list : TAsmList;fromsize: TDef;const r : TRegister;const cgpara : TCGPara);virtual;
          procedure a_loadfpu_ref_cgpara(list : TAsmList;fromsize : TDef;const ref : TReference;const cgpara : TCGPara);virtual;

          { vector register move instructions }
          procedure a_loadmm_reg_reg(list: TAsmList; fromsize, tosize: TDef;reg1, reg2: TRegister;shuffle : PMMShuffle); virtual; abstract;
          procedure a_loadmm_ref_reg(list: TAsmList; fromsize, tosize: TDef;const ref: TReference; reg: TRegister;shuffle : PMMShuffle); virtual; abstract;
          procedure a_loadmm_reg_ref(list: TAsmList; fromsize, tosize: TDef;reg: TRegister; const ref: TReference;shuffle : PMMShuffle); virtual; abstract;
          procedure a_loadmm_ref_ref(list: TAsmList; fromsize, tosize: TDef; const fromref, toref: TReference; shuffle: PMMShuffle); virtual;
          { required for subsetreg/ref; still tcgsize rather than tdef because of reason mentioned above }
          procedure a_loadmm_loc_reg(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; const reg: TRegister; shuffle : PMMShuffle);virtual;
          procedure a_loadmm_reg_loc(list: TAsmList; fromsize, tosize: TDef; const reg: TRegister; const loc: TLocation;shuffle : PMMShuffle);virtual;
          procedure a_loadmm_loc_ref(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; const ref: TReference; shuffle : PMMShuffle);virtual;
          procedure a_loadmm_reg_cgpara(list: TAsmList; fromsize: TDef; reg: TRegister;const cgpara : TCGPara;shuffle : PMMShuffle); virtual;
          procedure a_loadmm_ref_cgpara(list: TAsmList; fromsize: TDef; const ref: TReference;const cgpara : TCGPara;shuffle : PMMShuffle); virtual;
          procedure a_loadmm_loc_cgpara(list: TAsmList; fromsize: TDef; const loc: TLocation; const cgpara : TCGPara;shuffle : PMMShuffle); virtual;
          procedure a_opmm_reg_reg(list: TAsmList; Op: TOpCG; size : TDef;src,dst: TRegister;shuffle : PMMShuffle); virtual; abstract;
          procedure a_opmm_ref_reg(list: TAsmList; Op: TOpCG; size : TDef;const ref: TReference; reg: TRegister;shuffle : PMMShuffle); virtual;
          procedure a_opmm_loc_reg(list: TAsmList; Op: TOpCG; size : TDef;const loc: TLocation; reg: TRegister;shuffle : PMMShuffle); virtual;
          procedure a_opmm_reg_ref(list: TAsmList; Op: TOpCG; size : TDef;reg: TRegister;const ref: TReference; shuffle : PMMShuffle); virtual;
          { requires a temp that is interpreted in two different ways, and we
            don't have a way (yet) to tag a treference with tdef information so
            targets like LLVM can insert the necessary bitcast
          }
          procedure a_loadmm_intreg_reg(list: TAsmList; fromsize, tosize : TDef; intreg, mmreg: TRegister; shuffle: PMMShuffle); virtual; abstract;
          procedure a_loadmm_reg_intreg(list: TAsmList; fromsize, tosize : TDef; mmreg, intreg: TRegister; shuffle : PMMShuffle); virtual; abstract;

          { basic arithmetic operations }
          procedure a_op_const_reg(list : TAsmList; Op: TOpCG; size: TDef; a: TCGInt; reg: TRegister); virtual; abstract;
          procedure a_op_const_ref(list : TAsmList; Op: TOpCG; size: TDef; a: TCGInt; const ref: TReference); virtual;
          procedure a_op_const_subsetreg(list : TAsmList; Op : TOpCG; size, subsetsize : TDef; a : TCGInt; const sreg: TSubsetRegister); virtual;
          procedure a_op_const_subsetref(list : TAsmList; Op : TOpCG; size, subsetsize : TDef; a : TCGInt; const sref: TSubsetReference); virtual;
          procedure a_op_const_loc(list : TAsmList; Op: TOpCG; size: TDef; a: TCGInt; const loc: TLocation);virtual;
          procedure a_op_reg_reg(list : TAsmList; Op: TOpCG; size: TDef; reg1, reg2: TRegister); virtual; abstract;
          procedure a_op_reg_ref(list : TAsmList; Op: TOpCG; size: TDef; reg: TRegister; const ref: TReference); virtual;
          procedure a_op_ref_reg(list : TAsmList; Op: TOpCG; size: TDef; const ref: TReference; reg: TRegister); virtual;
          procedure a_op_reg_subsetreg(list: TAsmList; Op: TOpCG; opsize, destsubsetsize: TDef; reg: TRegister; const sreg: TSubsetRegister); virtual;
          procedure a_op_reg_subsetref(list: TAsmList; Op: TOpCG; opsize, destsubsetsize: TDef; reg: TRegister; const sref: TSubsetReference); virtual;
          procedure a_op_reg_loc(list : TAsmList; Op: TOpCG; size: TDef; reg: TRegister; const loc: TLocation);virtual;
          procedure a_op_ref_loc(list : TAsmList; Op: TOpCG; size: TDef; const ref: TReference; const loc: TLocation);virtual;

          { trinary operations for processors that support them, 'emulated' }
          { on others. None with "ref" arguments since I don't think there  }
          { are any processors that support it (JM)                         }
          procedure a_op_const_reg_reg(list: TAsmList; op: TOpCG; size: TDef; a: TCGInt; src, dst: TRegister); virtual;
          procedure a_op_reg_reg_reg(list: TAsmList; op: TOpCG; size: TDef; src1, src2, dst: TRegister); virtual;
          procedure a_op_const_reg_reg_checkoverflow(list: TAsmList; op: TOpCG; size: TDef; a: TCGInt; src, dst: TRegister;setflags : boolean;var ovloc : TLocation); virtual;
          procedure a_op_reg_reg_reg_checkoverflow(list: TAsmList; op: TOpCG; size: TDef; src1, src2, dst: TRegister;setflags : boolean;var ovloc : TLocation); virtual;

          { unary operations (not, neg) }
          procedure a_op_reg(list : TAsmList; Op: TOpCG; size: TDef; reg: TRegister); virtual;
          procedure a_op_ref(list : TAsmList; Op: TOpCG; size: TDef; const ref: TReference); virtual;
          procedure a_op_subsetreg(list: TAsmList; Op: TOpCG; destsubsetsize: TDef; const sreg: TSubsetRegister); virtual;
          procedure a_op_subsetref(list: TAsmList; Op: TOpCG; destsubsetsize: TDef; const sref: TSubsetReference); virtual;
          procedure a_op_loc(list : TAsmList; Op: TOpCG; size: TDef;  const loc: TLocation); virtual;

          {  comparison operations }
          procedure a_cmp_const_reg_label(list : TAsmList;size : TDef;cmp_op : TOpCmp;a : TCGInt;reg : TRegister;
            l : TAsmLabel);virtual;
          procedure a_cmp_const_ref_label(list : TAsmList;size : TDef;cmp_op : TOpCmp;a : TCGInt;const ref : TReference;
            l : TAsmLabel); virtual;
          procedure a_cmp_const_loc_label(list: TAsmList; size: TDef;cmp_op: TOpCmp; a: TCGInt; const loc: TLocation;
            l : TAsmLabel);virtual;
          procedure a_cmp_reg_reg_label(list : TAsmList;size : TDef;cmp_op : TOpCmp;reg1,reg2 : TRegister;l : TAsmLabel); virtual; abstract;
          procedure a_cmp_ref_reg_label(list : TAsmList;size : TDef;cmp_op : TOpCmp; const ref: TReference; reg : TRegister; l : TAsmLabel); virtual;
          procedure a_cmp_reg_ref_label(list : TAsmList;size : TDef;cmp_op : TOpCmp;reg : TRegister; const ref: TReference; l : TAsmLabel); virtual;
          procedure a_cmp_subsetreg_reg_label(list: TAsmList; fromsubsetsize, cmpsize: TDef; cmp_op: TOpCmp; const sreg: TSubsetRegister; reg: TRegister; l: TAsmLabel); virtual;
          procedure a_cmp_subsetref_reg_label(list: TAsmList; fromsubsetsize, cmpsize: TDef; cmp_op: TOpCmp; const sref: TSubsetReference; reg: TRegister; l: TAsmLabel); virtual;

          procedure a_cmp_loc_reg_label(list : TAsmList;size : TDef;cmp_op : TOpCmp; const loc: TLocation; reg : TRegister; l : TAsmLabel);virtual;
          procedure a_cmp_reg_loc_label(list : TAsmList;size : TDef;cmp_op : TOpCmp; reg: TRegister; const loc: TLocation; l : TAsmLabel);
          procedure a_cmp_ref_loc_label(list: TAsmList; size: TDef;cmp_op: TOpCmp; const ref: TReference; const loc: TLocation; l : TAsmLabel);virtual;

          procedure a_jmp_always(list : TAsmList;l: TAsmLabel); virtual;abstract;
          procedure a_jmp_always_pascal_goto(list : TAsmList;l: TAsmLabel);virtual;
{$ifdef cpuflags}
          procedure a_jmp_flags(list : TAsmList;const f : TResFlags;l: TAsmLabel); virtual; abstract;

          {# Depending on the value to check in the flags, either sets the register reg to one (if the flag is set)
             or zero (if the flag is cleared). The size parameter indicates the destination size register.
          }
          procedure g_flags2reg(list: TAsmList; size: TDef; const f: TResFlags; reg: TRegister); virtual; abstract;
          procedure g_flags2ref(list: TAsmList; size: TDef; const f: TResFlags; const ref:TReference); virtual; abstract;
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
          procedure optimize_op_const(size: TDef; var op: TOpCG; var a : TCGInt);virtual;

          {#
              This routine is used in exception management nodes. It should
              save the exception reason currently in the reg. The
              save should be done either to a temp (pointed to by href).
              or on the stack (pushing the value on the stack).
           }
          procedure g_exception_reason_save(list : TAsmList; fromsize, tosize: TDef; reg: TRegister; const href : TReference);virtual;

          {#
              This routine is used in exception management nodes. It should
              save the exception reason constant. The
              save should be done either to a temp (pointed to by href).
              or on the stack (pushing the value on the stack).

              The size of the value to save is OS_S32. The default version
              saves the exception reason to a temp. memory area.
           }
          procedure g_exception_reason_save_const(list: TAsmList; size: TDef; a: TCGInt; const href: TReference);virtual;

          {#
              This routine is used in exception management nodes. It should
              load the exception reason to reg. The saved value
              should either be in the temp. area (pointed to by href , href should
              *NOT* be freed) or on the stack (the value should be popped).

              The size of the value to save is OS_S32. The default version
              saves the exception reason to a temp. memory area.
           }
          procedure g_exception_reason_load(list : TAsmList; fromsize, tosize: TDef; const href : TReference; reg: TRegister);virtual;
          {#
              This routine is called when the current exception reason can be
              discarded. On platforms that use push/pop, it causes the current
              value to be popped. On other platforms it doesn't do anything
          }
          procedure g_exception_reason_discard(list : TAsmList; size: TDef; href: TReference); virtual;

          {#
              This routine is called after g_call_system_proc to a system proc,
              that might raise an exception. It is used on platforms, that need
              to manually check an 'exception raised' flag, like WebAssembly in
              branchful exceptions mode.
          }
          procedure g_maybe_checkforexceptions(list : TAsmList); virtual;

          {#
              Call when the current location should never be reached
          }
          procedure g_unreachable(list: TAsmList); virtual;

          procedure g_maybe_testself(list : TAsmList; selftype: TDef; reg:TRegister);
//          procedure g_maybe_testvmt(list : TAsmList;reg:tregister;objdef:tobjectdef);
          {# This should emit the opcode to copy len bytes from the source
             to destination.

             It must be overridden for each new target processor.

             @param(source Source reference of copy)
             @param(dest Destination reference of copy)

          }
          procedure g_concatcopy(list : TAsmList;size: TDef; const source,dest : TReference);virtual;
          {# This should emit the opcode to copy len bytes from the an unaligned source
             to destination.

             It must be overridden for each new target processor.

             @param(source Source reference of copy)
             @param(dest Destination reference of copy)

          }
          procedure g_concatcopy_unaligned(list : TAsmList;size: TDef; const source,dest : TReference);virtual;
          {# This should emit the opcode to a shortrstring from the source
             to destination.

             @param(source Source reference of copy)
             @param(dest Destination reference of copy)

          }
          procedure g_copyshortstring(list : TAsmList;const source,dest : TReference;strdef:TStringDef);virtual;
          procedure g_copyvariant(list : TAsmList;const source,dest : TReference;vardef:TVariantDef);virtual;

          procedure g_incrrefcount(list : TAsmList;t: TDef; const ref: TReference);virtual;
          procedure g_initialize(list : TAsmList;t : TDef;const ref : TReference);virtual;
          procedure g_finalize(list : TAsmList;t : TDef;const ref : TReference);virtual;
          procedure g_array_rtti_helper(list: TAsmList; t: TDef; const ref: TReference; const highloc: TLocation;
            const name: string);virtual;
         protected
          { helper called by g_incrrefcount, g_initialize, g_finalize and
            g_array_rtti_helper to determine whether the RTTI symbol representing
            t needs to be loaded using the indirect symbol }
          function def_needs_indirect(t:TDef):boolean;
         public

          {# Generates range checking code. It is to note
             that this routine does not need to be overridden,
             as it takes care of everything.

             @param(p Node which contains the value to check)
             @param(todef Type definition of node to range check)
          }
          procedure g_rangecheck(list: TAsmList; const l:TLocation; fromdef,todef: TDef); virtual;

          {# Generates overflow checking code for a node }
          procedure g_overflowcheck(list: TAsmList; const Loc:TLocation; def:TDef); virtual; abstract;
          procedure g_overflowCheck_loc(List:TAsmList;const Loc:TLocation;def:TDef;var ovloc : TLocation);virtual; abstract;

          procedure g_copyvaluepara_openarray(list : TAsmList;const ref:TReference;const lenloc:TLocation;arrdef: TArrayDef;destreg:TRegister);virtual;
          procedure g_releasevaluepara_openarray(list : TAsmList;arrdef: TArrayDef;const l:TLocation);virtual;

          {# Emits instruction for allocating @var(size) bytes at the stackpointer

             @param(size Number of bytes to allocate)
          }
          procedure g_stackpointer_alloc(list : TAsmList;size : LongInt);virtual; abstract;
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
          procedure g_proc_exit(list : TAsmList;parasize:LongInt;nostackframe:boolean);virtual; abstract;

          procedure g_intf_wrapper(list: TAsmList; procdef: TProcDef; const labelname: string; ioffset: LongInt);virtual; abstract;
          procedure g_adjust_self_value(list:TAsmList;procdef: TProcDef;ioffset: aint);virtual; abstract;

         protected
          procedure a_jmp_external_name(list: TAsmList; const externalname: TSymStr); virtual;
         public
          { generate a stub which only purpose is to pass control the given external method,
          setting up any additional environment before doing so (if required).

          The default implementation issues a jump instruction to the external name. }
          procedure g_external_wrapper(list : TAsmList; procdef: TProcDef; const wrappername, externalname: string; global: boolean); virtual;

         protected
          procedure g_allocload_reg_reg(list: TAsmList; regsize: TDef; const fromreg: TRegister; out toreg: TRegister; regtyp: TRegisterType);
         public
          { create "safe copy" of a tlocation that can be used later: all
            registers used in the tlocation are copied to new ones, so that
            even if the original ones change, things stay the same (except if
            the original location was already a register, then the register is
            kept). Must only be used on lvalue locations.
            It's intended as some kind of replacement for a_loadaddr_ref_reg()
            for targets without pointers. }
          procedure g_reference_loc(list: TAsmList; def: TDef; const fromloc: TLocation; out toloc: TLocation); virtual;

          { typecasts the pointer in reg to a new pointer. By default it does
            nothing, only required for type-aware platforms like LLVM.
            fromdef/todef are not typed as pointerdef, because they may also be
            a procvardef or classrefdef. Replaces reg with a new register if
            necessary }
          procedure g_ptrtypecast_reg(list: TAsmList; fromdef, todef: TDef; var reg: TRegister); virtual;
          { same but for a treference (considers the reference itself, not the
            value stored at that place in memory). Replaces ref with a new
            reference if necessary. fromdef needs to be a pointerdef because
            it may have to be passed as fromdef to a_loadaddr_ref_reg, which
            needs the "pointeddef" of fromdef }
          procedure g_ptrtypecast_ref(list: TAsmList; fromdef, todef: TDef; var ref: TReference); virtual;

          { update a reference pointing to the start address of a record/object/
            class (contents) so it refers to the indicated field }
          procedure g_set_addr_nonbitpacked_field_ref(list: TAsmList; recdef: TAbstractRecordDef; field: TFieldVarSym; var recref: TReference); virtual;

          { tell the code generator that while this register's contents may be
            undefined, it will be masked/cleaned up afterwards before its
            contents are used if that is the case.

            Needed for LLVM in case of e.g. a potential shift of more bits
            than the width of the register }
          procedure g_undefined_ok(list: TAsmList; size: TDef; reg: TRegister); virtual;
         protected
          { load a register/constant into a record field by name }
          procedure g_setup_load_field_by_name(list: TAsmList; recdef: TRecordDef; const name: TIDString; const recref: TReference; out fref: TReference; out fielddef: TDef);
         public
          procedure g_load_reg_field_by_name(list: TAsmList; regsize: TDef; recdef: TRecordDef; reg: TRegister; const name: TIDString; const recref: TReference);
          procedure g_load_const_field_by_name(list: TAsmList; recdef: TRecordDef; a: TCGInt; const name: TIDString; const recref: TReference);
          { laod a named field into a register }
          procedure g_load_field_reg_by_name(list: TAsmList; recdef: TRecordDef; regsize: TDef; const name: TIDString; const recref: TReference; reg: TRegister);
          { same as above, but allocates the register and determines the def
            based on the type of the field }
          procedure g_force_field_reg_by_name(list: TAsmList; recdef: TRecordDef; const name: TIDString; const recref: TReference; out regdef: TDef; out reg: TRegister);

          { routines migrated from ncgutil }

          procedure location_force_reg(list:TAsmList;var l:TLocation;src_size,dst_size:TDef;maybeconst:boolean);virtual;
          procedure location_force_fpureg(list:TAsmList;var l: TLocation;size: TDef;maybeconst:boolean);virtual;
          procedure location_force_mem(list:TAsmList;var l:TLocation;size:TDef);virtual;
          procedure location_force_mmregscalar(list:TAsmList;var l: TLocation;var size:TDef;maybeconst:boolean);virtual;
//          procedure location_force_mmreg(list:TAsmList;var l: tlocation;size:tdef;maybeconst:boolean);virtual;abstract;

          { Retrieve the location of the data pointed to in location l, when the location is
            a register it is expected to contain the address of the data }
          procedure location_get_data_ref(list:TAsmList;def: TDef; const l:TLocation;var ref:TReference;loadref:boolean; alignment: LongInt);virtual;

          { if p is a boolean expression, turns p.location into a LOC_JUMP with
            jumps to generated true and false labels; otherwise internalerrors }
          procedure maketojumpbool(list: TAsmList; p: TNode);
          { same as above, but using predefined true/false labels instead of
            by generating new ones }
          procedure maketojumpboollabels(list: TAsmList; p: TNode; truelabel, falselabel: TAsmLabel);virtual;
          { if the result of n is a LOC_C(..)REGISTER, try to find the corresponding
            loadn and change its location to a new register (= SSA). In case reload
            is true, transfer the old to the new register                            }
          procedure maybe_change_load_node_reg(list: TAsmList; var n: TNode; reload: boolean); virtual;
         private
          function do_replace_node_regs(var n: TNode; para: pointer): TForEachNodeResult; virtual;
         public

          procedure gen_proc_symbol(list:TAsmList);
          procedure gen_proc_symbol_end(list:TAsmList);virtual;
          procedure handle_external_proc(list: TAsmList; pd: TProcDef; const importname: TSymStr); virtual;

          procedure gen_initialize_code(list:TAsmList);virtual;
          procedure gen_finalize_code(list:TAsmList);virtual;

          procedure gen_entry_code(list:TAsmList);virtual;
          procedure gen_exit_code(list:TAsmList);virtual;
          procedure gen_nexus_profile_call(list:TAsmList; const hookname:TIDString);
          procedure emit_nexus_profile_descriptor;
          procedure gen_nexus_profile_module_call(list:TAsmList;
            const hookname:TIDString);
          procedure emit_nexus_profile_module_data;

         protected
          { helpers called by gen_initialize_code/gen_finalize_code }
          procedure inittempvariables(list:TAsmList);virtual;
          procedure finalizetempvariables(list:TAsmList;for_finalization:boolean);virtual;
          procedure initialize_regvars(p:TObject;arg:pointer);virtual;
          { generates the code for decrementing the reference count of parameters }
          procedure final_paras(p:TObject;arg:pointer);
         public
          { helper called by gen_alloc_symtable }
          procedure varsym_set_localloc(list: TAsmList; vs:TAbstractNormalVarSym); virtual;
          { helper called by gen_alloc_symtable }
          procedure paravarsym_set_initialloc_to_paraloc(vs: TParaVarSym); virtual;

          procedure gen_load_para_value(list:TAsmList);virtual;
          { helpers called by gen_load_para_value }
          procedure g_copyvalueparas(p:TObject;arg:pointer);virtual;

          { allocate a local temp to serve as storage for a para/localsym }
          procedure getlocal(list: TAsmList; sym: TSym; size: asizeint; alignment: shortint; def: TDef; out ref : TReference);
          { the symbol is stored at this location from now on }
          procedure recordnewsymloc(list: TAsmList; sym: TSym; def: TDef; const ref: TReference; initial: boolean); virtual;
         protected
          procedure gen_loadfpu_loc_cgpara(list: TAsmList; size: TDef; const l: TLocation;const cgpara: TCGPara;locintsize: LongInt);virtual;
          procedure init_paras(p:TObject;arg:pointer);
         protected
          { Some targets have to put "something" in the function result
            location if it's not initialised by the Pascal code, e.g.
            stack-based architectures. By default it does nothing }
          procedure gen_load_uninitialized_function_result(list: TAsmList; pd: TProcDef; resdef: TDef; const resloc: TCGPara);virtual;
          procedure gen_load_loc_function_result(list: TAsmList; vardef: TDef; const l: TLocation);virtual;
         public
          { load a tlocation into a cgpara }
          procedure gen_load_loc_cgpara(list: TAsmList; vardef: TDef; const l: TLocation; const cgpara: TCGPara);virtual;

          { load a cgpara into a tlocation }
          procedure gen_load_cgpara_loc(list: TAsmList; vardef: TDef; const para: TCGPara; var destloc: TLocation; reusepara: boolean);virtual;

          { load the function return value into the ABI-defined function return location }
          procedure gen_load_return_value(list:TAsmList);virtual;

          { extras refactored from other units }
          procedure gen_stack_check_size_para(list:TAsmList); virtual;
          procedure gen_stack_check_call(list:TAsmList); virtual;

          { queue the code/data generated for a procedure for writing out to
            the assembler/object file }
          procedure record_generated_code_for_procdef(pd: TProcDef; code, data: TAsmList); virtual;

          { generate a call to a routine in the system unit }
          function g_call_system_proc(list: TAsmList; const procname: string; const paras: array of PCGPara; forceresdef: TDef): TCGPara;
          function g_call_system_proc(list: TAsmList; pd: TProcDef; const paras: array of PCGPara; forceresdef: TDef): TCGPara;
         protected
          function g_call_system_proc_intern(list: TAsmList; pd: TProcDef; const paras: array of PCGPara; forceresdef: TDef): TCGPara; virtual;
         public


          { Generate code to exit an unwind-protected region. The default implementation
            produces a simple jump to destination label. }
          procedure g_local_unwind(list: TAsmList; l: TAsmLabel);virtual;abstract;

         strict protected
          fhlcgobjhelpers: THLCGObjHelpersClass;
         public
          property hlcgobjhelpers: THLCGObjHelpersClass write fhlcgobjhelpers;
       end;
     THLCGObjClass = class of THLCGObj;

     TCreateHLCGCodeGen = procedure(lcgobjhelper: THLCGObjHelpersClass);

    var
       {# Main high level code generator class }
       hlcg : THLCGObj;
       { class type of high level code generator class (also valid when hlcg is
         nil, in order to be able to call its virtual class methods) }
       CHLCGObj: THLCGObjClass;
       create_hlcodegen: TCreateHLCGCodeGen;

    procedure destroy_hlcodegen;

implementation

    uses
       Globals,Systems,
       FinPut,FModule,
       Verbose,defutil,paramgr,
       SymTable,
       nbas,ncon,nld,nmem,
       ncgrtti,pass_2,
       cgobj,CUtils,ProcInfo,aasmcnst,
       ngenutil,
{$ifdef x86}
       cgx86,
{$endif x86}
       ncgutil;


    procedure destroy_hlcodegen;
      begin
        hlcg.free;
        hlcg:=nil;
        destroy_codegen;
      end;


    class procedure THLCGObjHelpers.gen_proc_symbol(list: TAsmList);
      var
        firstitem,
        item: TCmdStrListItem;
        global: boolean;
      begin
        item:=TCmdStrListItem(CurrentProcInfo.procdef.aliasnames.first);
        firstitem:=item;
        global:=CurrentProcInfo.procdef.needsglobalasmsym;
        while Assigned(item) do
          begin
            { Record emitted entry points, rather than declarations: generic
              templates can have assembler names without executable bodies. }
            if global and (tf_supports_packages in TargetInfo.flags) then
              CurrentModule.add_public_asmsym(item.str,AB_GLOBAL,AT_FUNCTION);
            { alias procedure entry symbols via ".set" on Darwin, otherwise
              they can be interpreted as all different starting symbols of
              subsections and be reordered }
            if (item<>firstitem) and
               (TargetInfo.system in systems_darwin) then
              begin
                { the .set already defines the symbol, so can't emit a tai_symbol as that will redefine it }
                if global then
                  begin
                    list.concat(TAISymbolPair.create(spk_set_global,item.str,firstitem.str));
                  end
                else
                  begin
                    list.concat(TAISymbolPair.create(spk_set,item.str,firstitem.str));
                  end;
              end
            else
              begin
                if global then
                  list.concat(TAISymbol.createname_global(item.str,AT_FUNCTION,0,CurrentProcInfo.procdef))
                else
                  list.concat(TAISymbol.Createname_hidden(item.str,AT_FUNCTION,0,CurrentProcInfo.procdef));
                if not(af_stabs_use_function_absolute_addresses in TargetAsm.flags) then
                  list.concat(TAIFunctionName.create(item.str));
              end;
            item:=TCmdStrListItem(item.next);
          end;
        CurrentProcInfo.procdef.procstarttai:=TAI(list.last);
      end;

    class procedure THLCGObjHelpers.record_generated_code_for_procdef(pd: TProcDef; code, data: TAsmList);
      var
        alt: TAsmListType;
        procsection: TAISection;
      begin
        procsection:=nil;
        if not(po_assembler in pd.procoptions) then
          alt:=al_procedures
        else
          alt:=al_pure_assembler;
        { add the procedure to the al_procedures }
        maybe_new_object_file(CurrentAsmData.asmlists[alt]);
  {$ifdef symansistr}
        if pd.section<>'' then
          procsection:=new_proc_section(CurrentAsmData.asmlists[alt],sec_user,lower(pd.section),getprocalign)
  {$else symansistr}
        if Assigned(pd.section) then
          procsection:=new_proc_section(CurrentAsmData.asmlists[alt],sec_user,lower(pd.section^),getprocalign)
  {$endif symansistr}
        else
          procsection:=new_section(CurrentAsmData.asmlists[alt],sec_code,lower(pd.mangledname),getprocalign);
        if Assigned(CurrentProcInfo) and (CurrentProcInfo.procdef=pd) then
          begin
            if not Assigned(procsection) then
              procsection:=TAISection(CurrentAsmData.asmlists[alt].last);
            if Assigned(CurrentProcInfo.nexus_profile_section) then
              CurrentProcInfo.nexus_profile_section.AssociativeSection:=procsection;
          end;
        CurrentAsmData.asmlists[alt].ConcatList(code);
        { save local data (castable) also in the same file }
        if Assigned(data) and
           (not data.empty) then
          CurrentAsmData.asmlists[alt].ConcatList(data);
      end;


  { thlcgobj }

  constructor THLCGObj.create;
    begin
      if not Assigned(fphlcgobjhelper) then
        fphlcgobjhelper:=THLCGObjHelpers;
    end;

  constructor THLCGObj.create(hlcgobjhelpers: THLCGObjHelpersClass);
    begin
      fphlcgobjhelper:=hlcgobjhelpers;
      create;
    end;

  procedure THLCGObj.init_register_allocators;
    begin
      cg.init_register_allocators;
    end;

  procedure THLCGObj.done_register_allocators;
    begin
      cg.done_register_allocators;
    end;

  procedure THLCGObj.set_regalloc_live_range_direction(dir: TRADirection);
    begin
      cg.set_regalloc_live_range_direction(dir);
    end;

  function THLCGObj.getintregister(list: TAsmList; size: TDef): TRegister;
    begin
      result:=cg.getintregister(list,def_cgsize(size));
    end;

  function THLCGObj.getaddressregister(list: TAsmList; size: TDef): TRegister;
    begin
      result:=cg.getaddressregister(list);
    end;

  function THLCGObj.getfpuregister(list: TAsmList; size: TDef): TRegister;
    begin
      result:=cg.getfpuregister(list,def_cgsize(size));
    end;

  function THLCGObj.getmmregister(list: TAsmList; size: TDef): TRegister;
    begin
      result:=cg.getmmregister(list,def_cgsize(size));
    end;

  function THLCGObj.getflagregister(list: TAsmList; size: TDef): TRegister;
    begin
      result:=cg.getflagregister(list,def_cgsize(size));
    end;

  function THLCGObj.gettempregister(list: TAsmList; size: TDef): TRegister;
    begin
      { doesn't make sense to try to translate this size to tcgsize, temps
        can have any size }
      result:=cg.gettempregister(list);
    end;

    function THLCGObj.getregisterfordef(list: TAsmList; size: TDef): TRegister;
      begin
        case def2regtyp(size) of
          R_INTREGISTER:
            result:=getintregister(list,size);
          R_ADDRESSREGISTER:
            result:=getaddressregister(list,size);
          R_FPUREGISTER:
            result:=getfpuregister(list,size);
          R_MMREGISTER:
            result:=getmmregister(list,size);
          else
            InternalError(2010122901);
        end;
      end;

  function THLCGObj.uses_registers(rt: TRegisterType): boolean;
    begin
       result:=cg.uses_registers(rt);
    end;

  procedure THLCGObj.getcpuregister(list: TAsmList; r: TRegister);
    begin
      cg.getcpuregister(list,r);
    end;

  procedure THLCGObj.ungetcpuregister(list: TAsmList; r: TRegister);
    begin
      cg.ungetcpuregister(list,r);
    end;

  procedure THLCGObj.alloccpuregisters(list: TAsmList; rt: TRegisterType; const r: TCPURegisterSet);
    begin
      cg.alloccpuregisters(list,rt,r);
    end;

  procedure THLCGObj.dealloccpuregisters(list: TAsmList; rt: TRegisterType; const r: TCPURegisterSet);
    begin
      cg.dealloccpuregisters(list,rt,r);
    end;

  procedure THLCGObj.allocallcpuregisters(list: TAsmList);
    begin
      cg.allocallcpuregisters(list);
    end;

  procedure THLCGObj.deallocallcpuregisters(list: TAsmList);
    begin
      cg.deallocallcpuregisters(list);
    end;

  procedure THLCGObj.do_register_allocation(list: TAsmList; headertai: TAI);
    begin
      cg.do_register_allocation(list,headertai);
    end;

  procedure THLCGObj.translate_register(var reg: TRegister);
    begin
      cg.translate_register(reg);
    end;

  class function THLCGObj.def2regtyp(def: TDef): TRegisterType;
    begin
        case def.typ of
          enumdef,
          orddef,
          recorddef,
          setdef:
            result:=R_INTREGISTER;
          procvardef:

            { getaddressregister cannot handle if multiple registers
              are required for a single element }
            if is_methodpointer(def) then
              result:=R_INTREGISTER
            else

              result:=R_ADDRESSREGISTER;
          stringdef,
          pointerdef,
          classrefdef,
          objectdef,
          procdef,
          formaldef:
            result:=R_ADDRESSREGISTER;
          arraydef:
            if TArrayDef(def).is_hwvector then
              result:=R_MMREGISTER
            else if TStoredDef(def).is_intregable then
              result:=R_INTREGISTER
            else
              result:=R_ADDRESSREGISTER;
          floatdef:
            if use_vectorfpu(def) then
              result:=R_MMREGISTER
            else
              result:=R_FPUREGISTER;
          filedef,
          variantdef,
          forwarddef,
          undefineddef:
            result:=R_INVALIDREGISTER;
        else
          InternalError(2010120506);
        end;
    end;

  procedure THLCGObj.reference_reset_base(var ref: TReference; regsize: TDef;
    reg: TRegister; offset: LongInt; temppos: TRefTempPos; alignment: LongInt; volatility: TVolatilitySet);
    begin
      reference_reset(ref,alignment,volatility);
      ref.base:=reg;
      ref.offset:=offset;
      ref.temppos:=temppos;
    end;

  procedure THLCGObj.a_label(list: TAsmList; l: TAsmLabel); inline;
    begin
      cg.a_label(list,l);
    end;

  procedure THLCGObj.a_label_pascal_goto_target(list : TAsmList;l : TAsmLabel); inline;
    begin
      cg.a_label_pascal_goto_target(list,l);
    end;

  procedure THLCGObj.a_reg_alloc(list: TAsmList; r: TRegister);
    begin
      cg.a_reg_alloc(list,r);
    end;

  procedure THLCGObj.a_reg_dealloc(list: TAsmList; r: TRegister);
    begin
      cg.a_reg_dealloc(list,r);
    end;

  procedure THLCGObj.a_reg_sync(list: TAsmList; r: TRegister);
    begin
      cg.a_reg_sync(list,r);
    end;

  procedure THLCGObj.a_load_reg_cgpara(list: TAsmList; size: TDef; r: TRegister; const cgpara: TCGPara);
    var
      ref: TReference;
      tmpreg : TRegister;
    begin
      cgpara.check_simple_location;
      paramanager.alloccgpara(list,cgpara);
      if cgpara.location^.shiftval<0 then
        begin
          tmpreg:=getintregister(list,cgpara.location^.def);
          a_op_const_reg_reg(list,OP_SHL,cgpara.location^.def,-cgpara.location^.shiftval,r,tmpreg);
          r:=tmpreg;
        end;
      case cgpara.location^.loc of
         LOC_REGISTER,LOC_CREGISTER:
           a_load_reg_reg(list,size,cgpara.location^.def,r,cgpara.location^.register);
         LOC_REFERENCE,LOC_CREFERENCE:
           begin
              reference_reset_base(ref,voidstackpointertype,cgpara.location^.reference.index,cgpara.location^.reference.offset,ctempposinvalid,cgpara.alignment,[]);
              a_load_reg_ref(list,size,cgpara.location^.def,r,ref);
           end;
         LOC_MMREGISTER,LOC_CMMREGISTER:
           a_loadmm_intreg_reg(list,size,cgpara.location^.def,r,cgpara.location^.register,mms_movescalar);
         LOC_FPUREGISTER,LOC_CFPUREGISTER:
           begin
             tg.gethltemp(list,size,size.size,tt_normal,ref);
             a_load_reg_ref(list,size,cgpara.location^.def,r,ref);
             a_loadfpu_ref_cgpara(list,cgpara.location^.def,ref,cgpara);
             tg.ungettemp(list,ref);
           end
         else
           InternalError(2010120415);
      end;
    end;

  procedure THLCGObj.a_load_const_cgpara(list: TAsmList; tosize: TDef; a: TCGInt; const cgpara: TCGPara);
    var
       ref : TReference;
    begin
       cgpara.check_simple_location;
       paramanager.alloccgpara(list,cgpara);
      if cgpara.location^.shiftval<0 then
        a:=a shl -cgpara.location^.shiftval;
       case cgpara.location^.loc of
          LOC_REGISTER,LOC_CREGISTER:
            a_load_const_reg(list,cgpara.location^.def,a,cgpara.location^.register);
          LOC_REFERENCE,LOC_CREFERENCE:
            begin
               reference_reset_base(ref,voidstackpointertype,cgpara.location^.reference.index,cgpara.location^.reference.offset,ctempposinvalid,cgpara.alignment,[]);
               a_load_const_ref(list,cgpara.location^.def,a,ref);
            end
          else
            InternalError(2010120416);
       end;
    end;

  procedure THLCGObj.a_load_ref_cgpara(list: TAsmList; size: TDef; const r: TReference; const cgpara: TCGPara);
    var
      tmpref, ref: TReference;
      tmpreg: TRegister;
      location: PCGParaLocation;
      orgsizeleft,
      sizeleft: TCGInt;
      reghasvalue: boolean;
    begin
      location:=cgpara.location;
      tmpref:=r;
      sizeleft:=cgpara.intsize;
      while Assigned(location) do
        begin
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
                 if (def_cgsize(size)<>OS_NO) and
                    (size.size<=sizeof(aint)) then
                   begin
                     cgpara.check_simple_location;
                     a_load_ref_reg(list,size,location^.def,tmpref,location^.register);
                     if location^.shiftval<0 then
                       a_op_const_reg(list,OP_SHL,location^.def,-location^.shiftval,location^.register);
                   end
                 { there's a lot more data left, and the current paraloc's
                   register is entirely filled with part of that data }
                 else if (sizeleft>sizeof(aint)) then
                   begin
                     a_load_ref_reg(list,location^.def,location^.def,tmpref,location^.register);
                   end
                 { we're at the end of the data, and it can be loaded into
                   the current location's register with a single regular
                   load }
                 else if sizeleft in [1,2,4,8] then
                   begin
                     { don't use cgsize_orddef(int_cgsize(sizeleft)) as fromdef,
                       because that may be larger than location^.register in
                       case of padding at the end of a record }
                     a_load_ref_reg(list,location^.def,location^.def,tmpref,location^.register);
                     if location^.shiftval<0 then
                       a_op_const_reg(list,OP_SHL,location^.def,-location^.shiftval,location^.register);
                   end
                 { we're at the end of the data, and we need multiple loads
                   to get it in the register because it's an irregular size }
                 else
                   begin
                     { should be the last part }
                     if Assigned(location^.next) then
                       InternalError(2010052902);
                     { load the value piecewise to get it into the register }
                     orgsizeleft:=sizeleft;
                     reghasvalue:=false;
{$if defined(cpu64bitalu) or defined(cpuhighleveltarget)}
                     if sizeleft>=4 then
                       begin
                         a_load_ref_reg(list,u32inttype,location^.def,tmpref,location^.register);
                         dec(sizeleft,4);
                         if TargetInfo.endian=endian_big then
                           a_op_const_reg(list,OP_SHL,location^.def,sizeleft*8,location^.register);
                         inc(tmpref.offset,4);
                         reghasvalue:=true;
                       end;
{$endif defined(cpu64bitalu) or defined(cpuhighleveltarget)}
                     if sizeleft>=2 then
                       begin
                         tmpreg:=getintregister(list,location^.def);
                         a_load_ref_reg(list,u16inttype,location^.def,tmpref,tmpreg);
                         dec(sizeleft,2);
                         if reghasvalue then
                           begin
                             if TargetInfo.endian=endian_big then
                               a_op_const_reg(list,OP_SHL,location^.def,sizeleft*8,tmpreg)
                             else
                               a_op_const_reg(list,OP_SHL,location^.def,(orgsizeleft-(sizeleft+2))*8,tmpreg);
                             a_op_reg_reg(list,OP_OR,location^.def,tmpreg,location^.register);
                           end
                         else
                           begin
                             if TargetInfo.endian=endian_big then
                               a_op_const_reg_reg(list,OP_SHL,location^.def,sizeleft*8,tmpreg,location^.register)
                             else
                               a_load_reg_reg(list,location^.def,location^.def,tmpreg,location^.register);
                           end;
                         inc(tmpref.offset,2);
                         reghasvalue:=true;
                       end;
                     if sizeleft=1 then
                       begin
                         tmpreg:=getintregister(list,location^.def);
                         a_load_ref_reg(list,u8inttype,location^.def,tmpref,tmpreg);
                         dec(sizeleft,1);
                         if reghasvalue then
                           begin
                             if TargetInfo.endian=endian_little then
                               a_op_const_reg(list,OP_SHL,location^.def,(orgsizeleft-(sizeleft+1))*8,tmpreg);
                             a_op_reg_reg(list,OP_OR,location^.def,tmpreg,location^.register)
                           end
                         else
                           a_load_reg_reg(list,location^.def,location^.def,tmpreg,location^.register);
                         inc(tmpref.offset);
                       end;
                     if location^.shiftval<0 then
                       a_op_const_reg(list,OP_SHL,location^.def,-location^.shiftval,location^.register);
                     { the loop will already adjust the offset and sizeleft }
                     dec(tmpref.offset,orgsizeleft);
                     sizeleft:=orgsizeleft;
                   end;
              end;
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                 if Assigned(location^.next) then
                   InternalError(2017073001);
                 reference_reset_base(ref,voidstackpointertype,location^.reference.index,location^.reference.offset,ctempposinvalid,NewAlignment(cgpara.alignment,cgpara.intsize-sizeleft),[]);
                 if (def_cgsize(size)<>OS_NO) and
                    (size.size=sizeleft) and
                    (sizeleft<=sizeof(aint)) then
                   a_load_ref_ref(list,size,location^.def,tmpref,ref)
                 else
                   { use concatcopy, because the parameter can be larger than }
                   { what the OS_* constants can handle                       }
                   g_concatcopy(list,location^.def,tmpref,ref);
              end;
            LOC_MMREGISTER,LOC_CMMREGISTER:
              begin
                 case location^.size of
                   OS_F32,
                   OS_F64,
                   OS_F128:
                     a_loadmm_ref_reg(list,location^.def,location^.def,tmpref,location^.register,mms_movescalar);
                   OS_M8..OS_M128:
                     a_loadmm_ref_reg(list,location^.def,location^.def,tmpref,location^.register,nil);
                   else
                     InternalError(2010053103);
                 end;
              end
            else
              InternalError(2014032101);
          end;
          inc(tmpref.offset,tcgsize2size[location^.size]);
          dec(sizeleft,tcgsize2size[location^.size]);
          location:=location^.next;
        end;
    end;


  procedure THLCGObj.a_load_loc_cgpara(list: TAsmList; size: TDef; const l: TLocation; const cgpara: TCGPara);
    begin
      case l.loc of
        LOC_REGISTER,
        LOC_CREGISTER :
          a_load_reg_cgpara(list,size,l.register,cgpara);
        LOC_CONSTANT :
          a_load_const_cgpara(list,size,l.value,cgpara);
        LOC_CREFERENCE,
        LOC_REFERENCE :
          a_load_ref_cgpara(list,size,l.reference,cgpara);
        else
          InternalError(2010120419);
      end;
    end;

  procedure THLCGObj.a_loadaddr_ref_cgpara(list: TAsmList; fromsize: TDef; const r: TReference; const cgpara: TCGPara);
    var
       hr : TRegister;
    begin
       cgpara.check_simple_location;
       if cgpara.location^.loc in [LOC_CREGISTER,LOC_REGISTER] then
         begin
           paramanager.allocparaloc(list,cgpara.location);
           a_loadaddr_ref_reg(list,fromsize,cgpara.location^.def,r,cgpara.location^.register)
         end
       else
         begin
           hr:=getaddressregister(list,cgpara.def);
           a_loadaddr_ref_reg(list,fromsize,cgpara.location^.def,r,hr);
           a_load_reg_cgpara(list,cgpara.def,hr,cgpara);
         end;
    end;

  procedure THLCGObj.a_load_undefined_cgpara(list: TAsmList; size: TDef; const cgpara: TCGPara);
    begin
      if not (cgpara.Location^.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
        a_load_const_cgpara(list,size,0,cgpara);
    end;

  function THLCGObj.a_call_name_static(list: TAsmList; pd: TProcDef; const s: TSymStr; const paras: array of PCGPara; forceresdef: TDef): TCGPara;
    begin
      result:=a_call_name(list,pd,s,paras,forceresdef,false);
    end;

  function THLCGObj.a_call_name_inherited(list: TAsmList; pd: TProcDef; const s: TSymStr; const paras: array of PCGPara): TCGPara;
    begin
      result:=a_call_name(list,pd,s,paras,nil,false);
    end;

  procedure THLCGObj.a_load_const_ref(list: TAsmList; tosize: TDef; a: TCGInt; const ref: TReference);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getintregister(list,tosize);
      a_load_const_reg(list,tosize,a,tmpreg);
      a_load_reg_ref(list,tosize,tosize,tmpreg,ref);
    end;

  procedure THLCGObj.a_load_const_loc(list: TAsmList; tosize: TDef; a: TCGInt; const loc: TLocation);
    begin
      case loc.loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          a_load_const_ref(list,tosize,a,loc.reference);
        LOC_REGISTER,LOC_CREGISTER:
          a_load_const_reg(list,tosize,a,loc.register);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          a_load_const_subsetreg(list,tosize,a,loc.sreg);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          a_load_const_subsetref(list,tosize,a,loc.sref);
        else
          InternalError(2010120401);
      end;
    end;

  procedure THLCGObj.a_load_reg_ref_unaligned(list: TAsmList; fromsize, tosize: TDef; register: TRegister; const ref: TReference);
    begin
      a_load_reg_ref(list,fromsize,tosize,register,ref);
    end;

  procedure THLCGObj.a_load_reg_loc(list: TAsmList; fromsize, tosize: TDef; reg: TRegister; const loc: TLocation);
    begin
      case loc.loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          a_load_reg_ref(list,fromsize,tosize,reg,loc.reference);
        LOC_REGISTER,LOC_CREGISTER:
          a_load_reg_reg(list,fromsize,tosize,reg,loc.register);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          a_load_reg_subsetreg(list,fromsize,tosize,reg,loc.sreg);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          a_load_reg_subsetref(list,fromsize,tosize,reg,loc.sref);
        LOC_MMREGISTER,LOC_CMMREGISTER:
          a_loadmm_intreg_reg(list,fromsize,tosize,reg,loc.register,mms_movescalar);
        else
          InternalError(2010120402);
      end;
    end;

  procedure THLCGObj.a_load_ref_reg_unaligned(list: TAsmList; fromsize, tosize: TDef; const ref: TReference; register: TRegister);
    begin
      a_load_ref_reg(list,fromsize,tosize,ref,register);
    end;

  procedure THLCGObj.a_load_ref_ref(list: TAsmList; fromsize, tosize: TDef; const sref: TReference; const dref: TReference);
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

  procedure THLCGObj.a_load_loc_reg(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; reg: TRegister);
    begin
      case loc.loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          a_load_ref_reg(list,fromsize,tosize,loc.reference,reg);
        LOC_REGISTER,LOC_CREGISTER:
          a_load_reg_reg(list,fromsize,tosize,loc.register,reg);
        LOC_CONSTANT:
          a_load_const_reg(list,tosize,loc.value,reg);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          a_load_subsetreg_reg(list,fromsize,tosize,loc.sreg,reg);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          a_load_subsetref_reg(list,fromsize,tosize,loc.sref,reg);
        else
          InternalError(2010120201);
      end;
    end;

  procedure THLCGObj.a_load_loc_ref(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; const ref: TReference);
    begin
      case loc.loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          a_load_ref_ref(list,fromsize,tosize,loc.reference,ref);
        LOC_REGISTER,LOC_CREGISTER:
          a_load_reg_ref(list,fromsize,tosize,loc.register,ref);
        LOC_CONSTANT:
          a_load_const_ref(list,tosize,loc.value,ref);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          a_load_subsetreg_ref(list,fromsize,tosize,loc.sreg,ref);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          a_load_subsetref_ref(list,fromsize,tosize,loc.sref,ref);
        else
          InternalError(2010120403);
      end;
    end;

  procedure THLCGObj.a_load_loc_subsetreg(list: TAsmList; fromsize, tosubsetsize: TDef; const loc: TLocation; const sreg: TSubsetRegister);
    begin
      case loc.loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          a_load_ref_subsetreg(list,fromsize,tosubsetsize,loc.reference,sreg);
        LOC_REGISTER,LOC_CREGISTER:
          a_load_reg_subsetreg(list,fromsize,tosubsetsize,loc.register,sreg);
        LOC_CONSTANT:
          a_load_const_subsetreg(list,tosubsetsize,loc.value,sreg);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          a_load_subsetreg_subsetreg(list,fromsize,tosubsetsize,loc.sreg,sreg);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          a_load_subsetref_subsetreg(list,fromsize,tosubsetsize,loc.sref,sreg);
        else
          InternalError(2010120404);
      end;
    end;

  procedure THLCGObj.a_load_loc_subsetref(list: TAsmList; fromsize, tosubsetsize: TDef; const loc: TLocation; const sref: TSubsetReference);
    begin
      case loc.loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          a_load_ref_subsetref(list,fromsize,tosubsetsize,loc.reference,sref);
        LOC_REGISTER,LOC_CREGISTER:
          a_load_reg_subsetref(list,fromsize,tosubsetsize,loc.register,sref);
        LOC_CONSTANT:
          a_load_const_subsetref(list,tosubsetsize,loc.value,sref);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          a_load_subsetreg_subsetref(list,fromsize,tosubsetsize,loc.sreg,sref);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          a_load_subsetref_subsetref(list,fromsize,tosubsetsize,loc.sref,sref);
        else
          InternalError(2010120405);
      end;
    end;

{$push}
{$r-,q-}

  procedure THLCGObj.a_load_subsetreg_reg(list: TAsmList; subsetsize, tosize: TDef; const sreg: TSubsetRegister; destreg: TRegister);

    function GetRegBitSize: Integer;
      begin
        case getsubreg(sreg.subsetreg) of
          R_SUBL, R_SUBH:
            Result := 8;
          R_SUBW:
            Result := 16;
          R_SUBD:
            Result := 32;
          R_SUBQ:
            Result := 64;
          else
            { So (stopbit < regsize) will always return True }
            Result := High(Integer);
        end;
      end;

    var
      subsetregdef: TOrdDef;
      bitmask: aword;
      tmpreg,
      subsetsizereg: TRegister;
      stopbit: byte;
    begin
      subsetregdef:=cgsize_orddef(sreg.subsetregsize);
      tmpreg:=getintregister(list,subsetregdef);
      { insert shifts only if it changes bits being accessed later on }
      if (sreg.startbit<>0) or
        (tosize.size*8>sreg.bitlen) then
        begin
          if is_signed(subsetsize) then
            begin
              { sign extend in case the value has a bitsize mod 8 <> 0 }
              { both instructions will be optimized away if not        }
              a_op_const_reg_reg(list,OP_SHL,subsetregdef,(tcgsize2size[sreg.subsetregsize]*8)-sreg.startbit-sreg.bitlen,sreg.subsetreg,tmpreg);
              a_op_const_reg(list,OP_SAR,subsetregdef,(tcgsize2size[sreg.subsetregsize]*8)-sreg.bitlen,tmpreg);
            end
          else
            begin
              a_op_const_reg_reg(list,OP_SHR,subsetregdef,sreg.startbit,sreg.subsetreg,tmpreg);
              stopbit:=sreg.startbit+sreg.bitlen;
              { If stopbit = (tcgsize2size[sreg.subsetregsize] * 8), then an
                AND mask is unnecessary }
              if (stopbit < GetRegBitSize()) then
                begin
                  { on x86(64), 1 shl 32(64) = 1 instead of 0
                    use aword to prevent overflow with 1 shl 31 }
                  if (stopbit-sreg.startbit<>AIntBits) then
                    bitmask:=(aword(1) shl (stopbit-sreg.startbit))-1
                  else
                    bitmask:=high(aword);
                  a_op_const_reg(list,OP_AND,subsetregdef,TCGInt(bitmask),tmpreg);
                end;
            end;
        end
      else
        a_load_reg_reg(list,subsetregdef,subsetregdef,sreg.subsetreg,tmpreg);
      subsetsizereg:=getintregister(list,subsetsize);
      a_load_reg_reg(list,subsetregdef,subsetsize,tmpreg,subsetsizereg);
      a_load_reg_reg(list,subsetsize,tosize,subsetsizereg,destreg);
    end;

  procedure THLCGObj.a_load_reg_subsetreg(list: TAsmList; fromsize, tosubsetsize: TDef; fromreg: TRegister; const sreg: TSubsetRegister);
    begin
      a_load_regconst_subsetreg_intern(list,fromsize,tosubsetsize,fromreg,sreg,SL_REG);
    end;

  procedure THLCGObj.a_load_subsetreg_subsetreg(list: TAsmList; fromsubsetsize, tosubsetsize: TDef; const fromsreg, tosreg: TSubsetRegister);
    var
      fromsubsetregdef,
      tosubsetregdef: TOrdDef;
      tmpreg, tmpreg2: TRegister;
      bitmask: aword;
      stopbit: byte;
    begin
      if (fromsreg.bitlen>=tosreg.bitlen) then
        begin
          fromsubsetregdef:=cgsize_orddef(fromsreg.subsetregsize);
          tosubsetregdef:=cgsize_orddef(tosreg.subsetregsize);
          if (fromsreg.startbit<=tosreg.startbit) then
            begin
              { tosreg may be larger -> use its size to perform the shift }
              tmpreg:=getintregister(list,tosubsetregdef);
              a_load_reg_reg(list,fromsubsetregdef,tosubsetregdef,fromsreg.subsetreg,tmpreg);
              a_op_const_reg(list,OP_SHL,tosubsetregdef,tosreg.startbit-fromsreg.startbit,tmpreg)
            end
          else
            begin
              { fromsreg may be larger -> use its size to perform the shift }
              tmpreg:=getintregister(list,fromsubsetregdef);
              a_op_const_reg_reg(list,OP_SHR,fromsubsetregdef,fromsreg.startbit-tosreg.startbit,fromsreg.subsetreg,tmpreg);
              tmpreg2:=getintregister(list,tosubsetregdef);
              a_load_reg_reg(list,fromsubsetregdef,tosubsetregdef,tmpreg,tmpreg2);
              tmpreg:=tmpreg2;
            end;
          stopbit:=tosreg.startbit + tosreg.bitlen;
          // on x86(64), 1 shl 32(64) = 1 instead of 0
          if (stopbit<>AIntBits) then
            bitmask:=not(((aword(1) shl stopbit)-1) xor ((aword(1) shl tosreg.startbit)-1))
           else
             bitmask:=(aword(1) shl tosreg.startbit) - 1;
          a_op_const_reg(list,OP_AND,tosubsetregdef,TCGInt(bitmask),tosreg.subsetreg);
          a_op_const_reg(list,OP_AND,tosubsetregdef,TCGInt(not(bitmask)),tmpreg);
          a_op_reg_reg(list,OP_OR,tosubsetregdef,tmpreg,tosreg.subsetreg);
        end
      else
        begin
          tmpreg:=getintregister(list,tosubsetsize);
          a_load_subsetreg_reg(list,fromsubsetsize,tosubsetsize,fromsreg,tmpreg);
          a_load_reg_subsetreg(list,tosubsetsize,tosubsetsize,tmpreg,tosreg);
        end;
    end;

  procedure THLCGObj.a_load_subsetreg_ref(list: TAsmList; fromsubsetsize, tosize: TDef; const sreg: TSubsetRegister; const destref: TReference);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getintregister(list,tosize);
      a_load_subsetreg_reg(list,fromsubsetsize,tosize,sreg,tmpreg);
      a_load_reg_ref(list,tosize,tosize,tmpreg,destref);
    end;

  procedure THLCGObj.a_load_ref_subsetreg(list: TAsmList; fromsize, tosubsetsize: TDef; const fromref: TReference; const sreg: TSubsetRegister);
    var
      tmpreg: TRegister;
    begin
      tmpreg := getintregister(list,tosubsetsize);
      a_load_ref_reg(list,fromsize,tosubsetsize,fromref,tmpreg);
      a_load_reg_subsetreg(list,tosubsetsize,tosubsetsize,tmpreg,sreg);
    end;

  procedure THLCGObj.a_load_const_subsetreg(list: TAsmList; tosubsetsize: TDef; a: TCGInt; const sreg: TSubsetRegister);
    var
      subsetregdef: TOrdDef;
      bitmask: aword;
      stopbit: byte;
    begin
       subsetregdef:=cgsize_orddef(sreg.subsetregsize);
       stopbit:=sreg.startbit+sreg.bitlen;
       // on x86(64), 1 shl 32(64) = 1 instead of 0
       if (stopbit<>AIntBits) then
         bitmask:=not(((aword(1) shl stopbit)-1) xor ((aword(1) shl sreg.startbit)-1))
       else
         bitmask:=(aword(1) shl sreg.startbit)-1;
       if (((aword(a) shl sreg.startbit) and not bitmask)<>not bitmask) then
         a_op_const_reg(list,OP_AND,subsetregdef,TCGInt(bitmask),sreg.subsetreg);
       a_op_const_reg(list,OP_OR,subsetregdef,TCGInt((aword(a) shl sreg.startbit) and not(bitmask)),sreg.subsetreg);
    end;

  procedure THLCGObj.a_load_subsetreg_loc(list: TAsmList; fromsubsetsize, tosize: TDef; const sreg: TSubsetRegister; const loc: TLocation);
    begin
      case loc.loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          a_load_subsetreg_ref(list,fromsubsetsize,tosize,sreg,loc.reference);
        LOC_REGISTER,LOC_CREGISTER:
          a_load_subsetreg_reg(list,fromsubsetsize,tosize,sreg,loc.register);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          a_load_subsetreg_subsetreg(list,fromsubsetsize,tosize,sreg,loc.sreg);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          a_load_subsetreg_subsetref(list,fromsubsetsize,tosize,sreg,loc.sref);
        else
          InternalError(2010120406);
      end;
    end;

  procedure THLCGObj.a_load_subsetref_reg(list: TAsmList; fromsubsetsize, tosize: TDef; const sref: TSubsetReference; destreg: TRegister);
    var
      tmpref: TReference;
      valuereg,extra_value_reg, tmpreg: TRegister;
      tosreg: TSubsetRegister;
      loadsize: TOrdDef;
      loadbitsize: byte;
      extra_load: boolean;
      tmpsref: TSubsetReference;
    begin
      if sref.bitlen>AIntBits then
        begin
          tmpsref:=sref;
          tmpsref.bitlen:=AIntBits;
          valuereg:=hlcg.getintregister(list,tosize);
          a_load_subsetref_reg(list,sinttype,tosize,tmpsref,valuereg);
          tmpsref.bitlen:=sref.bitlen-AIntBits;
          inc(tmpsref.ref.offset,AIntBits div 8);
          extra_value_reg:=hlcg.getintregister(list,tosize);
          a_load_subsetref_reg(list,sinttype,tosize,tmpsref,extra_value_reg);
          { can't use a_load_reg_subsetreg to merge the results, as that one
            does not support sizes > AIntBits either }
          tmpreg:=hlcg.getintregister(list,tosize);
          if TargetInfo.endian=endian_big then
            begin
              a_op_const_reg_reg(list,OP_SHL,tosize,sref.bitlen-AIntBits,valuereg,tmpreg);
              if is_signed(fromsubsetsize) then
                begin
                  valuereg:=tmpreg;
                  tmpreg:=hlcg.getintregister(list,tosize);
                  a_op_const_reg_reg(list,OP_AND,tosize,(TCGInt(1) shl (sref.bitlen-AIntBits))-1,extra_value_reg,tmpreg);
                  valuereg:=tmpreg;
                end
            end
          else
            begin
              a_op_const_reg_reg(list,OP_SHL,tosize,AIntBits,extra_value_reg,tmpreg);
              if is_signed(fromsubsetsize) then
                begin
                  extra_value_reg:=hlcg.getintregister(list,tosize);
                  a_op_const_reg_reg(list,OP_AND,tosize,(TCGInt(1) shl AIntBits)-1,valuereg,extra_value_reg);
                  valuereg:=extra_value_reg;
                end
            end;
          if is_signed(fromsubsetsize) then
            begin
              extra_value_reg:=hlcg.getintregister(list,tosize);
              a_op_const_reg_reg(list,OP_AND,tosize,(TCGInt(1) shl AIntBits)-1,valuereg,extra_value_reg);
              valuereg:=extra_value_reg;
            end;
          a_op_reg_reg_reg(list,OP_OR,tosize,valuereg,tmpreg,destreg);
          exit;
        end;

      get_subsetref_load_info(sref,loadsize,extra_load);
      loadbitsize:=loadsize.size*8;

      { load the (first part) of the bit sequence }
      valuereg:=getintregister(list,aluuinttype);
      a_load_ref_reg(list,loadsize,aluuinttype,sref.ref,valuereg);

      if not extra_load then
        begin
          { everything is guaranteed to be in a single register of loadsize }
          if (sref.bitindexreg=NR_NO) then
            begin
              { use subsetreg routine, it may have been overridden with an optimized version }
              tosreg.subsetreg:=valuereg;
              tosreg.subsetregsize:=def_cgsize(aluuinttype);
              { subsetregs always count bits from right to left }
              if (TargetInfo.endian=endian_big) then
                tosreg.startbit:=loadbitsize-(sref.startbit+sref.bitlen)
              else
                tosreg.startbit:=sref.startbit;
              tosreg.bitlen:=sref.bitlen;
              a_load_subsetreg_reg(list,fromsubsetsize,tosize,tosreg,destreg);
              exit;
            end
          else
            begin
              if (sref.startbit<>0) then
                InternalError(2006081510);
              if (TargetInfo.endian=endian_big) then
                begin
                  a_op_reg_reg(list,OP_SHL,aluuinttype,sref.bitindexreg,valuereg);
                  if is_signed(fromsubsetsize) then
                    begin
                      { sign extend to entire register }
                      a_op_const_reg(list,OP_SHL,aluuinttype,AIntBits-loadbitsize,valuereg);
                      a_op_const_reg(list,OP_SAR,aluuinttype,AIntBits-sref.bitlen,valuereg);
                    end
                  else
                    a_op_const_reg(list,OP_SHR,aluuinttype,loadbitsize-sref.bitlen,valuereg);
                end
              else
                begin
                  a_op_reg_reg(list,OP_SHR,aluuinttype,sref.bitindexreg,valuereg);
                  if is_signed(fromsubsetsize) then
                    begin
                      a_op_const_reg(list,OP_SHL,aluuinttype,AIntBits-sref.bitlen,valuereg);
                      a_op_const_reg(list,OP_SAR,aluuinttype,AIntBits-sref.bitlen,valuereg);
                    end
                end;
              { mask other bits/sign extend }
              if not is_signed(fromsubsetsize) then
                a_op_const_reg(list,OP_AND,aluuinttype,TCGInt((aword(1) shl sref.bitlen)-1),valuereg);
            end
        end
      else
        begin
          { load next value as well }
          extra_value_reg:=getintregister(list,aluuinttype);

          if (sref.bitindexreg=NR_NO) then
            begin
              tmpref:=sref.ref;
              inc(tmpref.offset,loadbitsize div 8);
              a_load_ref_reg(list,loadsize,aluuinttype,tmpref,extra_value_reg);
              { can be overridden to optimize }
              a_load_subsetref_regs_noindex(list,fromsubsetsize,loadbitsize,sref,valuereg,extra_value_reg)
            end
          else
            begin
              if (sref.startbit<>0) then
                InternalError(2006080610);
              a_load_subsetref_regs_index(list,fromsubsetsize,loadbitsize,sref,valuereg);
            end;
        end;

      { store in destination }
{$ifndef cpuhighleveltarget}
      { avoid unnecessary sign extension and zeroing }
      valuereg:=cg.makeregsize(list,valuereg,OS_INT);
      destreg:=cg.makeregsize(list,destreg,OS_INT);
      cg.a_load_reg_reg(list,OS_INT,OS_INT,valuereg,destreg);
      destreg:=cg.makeregsize(list,destreg,def_cgsize(tosize));
{$else}
      { can't juggle with register sizes, they are actually typed entities
        here }
      a_load_reg_reg(list,aluuinttype,tosize,valuereg,destreg);
{$endif}
    end;

  procedure THLCGObj.a_load_reg_subsetref(list: TAsmList; fromsize, tosubsetsize: TDef; fromreg: TRegister; const sref: TSubsetReference);
    var
      tmpsref: TSubsetReference;
      fromreg1: TRegister;
    begin
      if sref.bitlen>AIntBits then
        begin
          if ((sref.bitlen mod AIntBits)<>0) then
            InternalError(2019052901);
          tmpsref:=sref;
          tmpsref.bitlen:=AIntBits;
          fromreg1:=hlcg.getintregister(list,aluuinttype);
          a_load_reg_reg(list,fromsize,aluuinttype,fromreg,fromreg1);
          if TargetInfo.endian=endian_big then
            begin
              inc(tmpsref.ref.offset,sref.bitlen-AIntBits);
            end;
          a_load_reg_subsetref(list,aluuinttype,aluuinttype,fromreg1,tmpsref);
          if TargetInfo.endian=endian_big then
            begin
              tmpsref.ref.offset:=sref.ref.offset;
            end
          else
            begin
              inc(tmpsref.ref.offset,AIntBits div 8);
            end;
          tmpsref.bitlen:=sref.bitlen-AIntBits;
          fromreg1:=hlcg.getintregister(list,fromsize);
          hlcg.a_op_const_reg_reg(list,OP_SHR,fromsize,AIntBits,fromreg,fromreg1);
          a_load_reg_subsetref(list,fromsize,tosubsetsize,fromreg1,tmpsref);
          exit;
        end;
      a_load_regconst_subsetref_intern(list,fromsize,tosubsetsize,fromreg,sref,SL_REG);
    end;

  procedure THLCGObj.a_load_subsetref_subsetref(list: TAsmList; fromsubsetsize, tosubsetsize: TDef; const fromsref, tosref: TSubsetReference);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getintregister(list,tosubsetsize);
      a_load_subsetref_reg(list,fromsubsetsize,tosubsetsize,fromsref,tmpreg);
      a_load_reg_subsetref(list,tosubsetsize,tosubsetsize,tmpreg,tosref);
    end;

  procedure THLCGObj.a_load_subsetref_ref(list: TAsmList; fromsubsetsize, tosize: TDef; const sref: TSubsetReference; const destref: TReference);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getintregister(list,tosize);
      a_load_subsetref_reg(list,fromsubsetsize,tosize,sref,tmpreg);
      a_load_reg_ref(list,tosize,tosize,tmpreg,destref);
    end;

  procedure THLCGObj.a_load_ref_subsetref(list: TAsmList; fromsize, tosubsetsize: TDef; const fromref: TReference; const sref: TSubsetReference);
    var
      tmpreg: TRegister;
    begin
      tmpreg := getintregister(list,tosubsetsize);
      a_load_ref_reg(list,fromsize,tosubsetsize,fromref,tmpreg);
      a_load_reg_subsetref(list,tosubsetsize,tosubsetsize,tmpreg,sref);
    end;

  procedure THLCGObj.a_load_const_subsetref(list: TAsmList; tosubsetsize: TDef; a: TCGInt; const sref: TSubsetReference);
    var
      tmpsref: TSubsetReference;
      tmpreg: TRegister;
      slopt: TSubsetLoadOpt;
    begin
      if sref.bitlen>AIntBits then
        begin
          if ((sref.bitlen mod AIntBits)<>0) then
            InternalError(2019052902);
          tmpsref:=sref;
          tmpsref.bitlen:=AIntBits;
          if TargetInfo.endian=endian_big then
            begin
              inc(tmpsref.ref.offset,sref.bitlen-AIntBits);
            end;
          a_load_const_subsetref(list,tosubsetsize,aint(a),tmpsref);
          if TargetInfo.endian=endian_big then
            begin
              tmpsref.ref.offset:=sref.ref.offset;
            end
          else
            begin
              inc(tmpsref.ref.offset,AIntBits div 8);
            end;
          tmpsref.bitlen:=sref.bitlen-AIntBits;
          a_load_const_subsetref(list,tosubsetsize,a shr AIntBits,tmpsref);
          exit;
        end;
      { perform masking of the source value in advance }
      slopt:=SL_REGNOSRCMASK;
      if (sref.bitlen<>AIntBits) then
        a:=TCGInt(aword(a) and ((aword(1) shl sref.bitlen) -1));
      if (
          { broken x86 "x shl regbitsize = x" }
          ((sref.bitlen<>AIntBits) and
           ((aword(a) and ((aword(1) shl sref.bitlen)-1))=(aword(1) shl sref.bitlen)-1)) or
          ((sref.bitlen=AIntBits) and
           (a=-1))
         ) then
        slopt:=SL_SETMAX
      else if (a=0) then
        slopt:=SL_SETZERO;
      if not(slopt in [SL_SETZERO,SL_SETMAX]) then
        begin
          tmpreg:=getintregister(list,tosubsetsize);
          a_load_const_reg(list,tosubsetsize,a,tmpreg);
        end
      else
        tmpreg:=NR_NO;
      a_load_regconst_subsetref_intern(list,tosubsetsize,tosubsetsize,tmpreg,sref,slopt);
    end;

  procedure THLCGObj.a_load_subsetref_loc(list: TAsmList; fromsubsetsize, tosize: TDef; const sref: TSubsetReference; const loc: TLocation);
    begin
      case loc.loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          a_load_subsetref_ref(list,fromsubsetsize,tosize,sref,loc.reference);
        LOC_REGISTER,LOC_CREGISTER:
          a_load_subsetref_reg(list,fromsubsetsize,tosize,sref,loc.register);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          a_load_subsetref_subsetreg(list,fromsubsetsize,tosize,sref,loc.sreg);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          a_load_subsetref_subsetref(list,fromsubsetsize,tosize,sref,loc.sref);
        else
          InternalError(2010120407);
      end;
    end;

  procedure THLCGObj.a_load_subsetref_subsetreg(list: TAsmList; fromsubsetsize, tosubsetsize: TDef; const fromsref: TSubsetReference; const tosreg: TSubsetRegister);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getintregister(list,tosubsetsize);
      a_load_subsetref_reg(list,fromsubsetsize,tosubsetsize,fromsref,tmpreg);
      a_load_reg_subsetreg(list,tosubsetsize,tosubsetsize,tmpreg,tosreg);
    end;

  procedure THLCGObj.a_load_subsetreg_subsetref(list: TAsmList; fromsubsetsize, tosubsetsize: TDef; const fromsreg: TSubsetRegister; const tosref: TSubsetReference);
    var
      tmpreg: TRegister;
    begin
      tmpreg := getintregister(list,tosubsetsize);
      a_load_subsetreg_reg(list,fromsubsetsize,tosubsetsize,fromsreg,tmpreg);
      a_load_reg_subsetref(list,tosubsetsize,tosubsetsize,tmpreg,tosref);
    end;

  procedure THLCGObj.a_bit_test_reg_reg_reg(list: TAsmList; bitnumbersize, valuesize, destsize: TDef; bitnumber, value, destreg: TRegister);
    var
      tmpvalue: TRegister;
    begin
      tmpvalue:=getintregister(list,valuesize);

      if (TargetInfo.endian=endian_little) then
        begin
          { rotate value register "bitnumber" bits to the right }
          a_op_reg_reg_reg(list,OP_SHR,valuesize,bitnumber,value,tmpvalue);
          { extract the bit we want }
          a_op_const_reg(list,OP_AND,valuesize,1,tmpvalue);
        end
      else
        begin
          { highest (leftmost) bit = bit 0 -> shl bitnumber results in wanted }
          { bit in uppermost position, then move it to the lowest position    }
          { "and" is not necessary since combination of shl/shr will clear    }
          { all other bits                                                    }
          a_op_reg_reg_reg(list,OP_SHL,valuesize,bitnumber,value,tmpvalue);
          a_op_const_reg(list,OP_SHR,valuesize,valuesize.size*8-1,tmpvalue);
        end;
      a_load_reg_reg(list,valuesize,destsize,tmpvalue,destreg);
    end;

  procedure THLCGObj.a_bit_test_const_ref_reg(list: TAsmList; fromsize, destsize: TDef; bitnumber: aint; const ref: TReference; destreg: TRegister);
    var
      href: TReference;
    begin
      href:=ref;
      g_ptrtypecast_ref(list,CPointerDef.getreusable(fromsize),CPointerDef.getreusable(u8inttype),href);
      a_load_subsetref_reg(list,u8inttype,destsize,get_bit_const_ref_sref(bitnumber,fromsize,href),destreg);
    end;

  procedure THLCGObj.a_bit_test_const_reg_reg(list: TAsmList; setregsize, destsize: TDef; bitnumber: aint; setreg, destreg: TRegister);
    begin
      a_load_subsetreg_reg(list,setregsize,destsize,get_bit_const_reg_sreg(setregsize,bitnumber,setreg),destreg);
    end;

  procedure THLCGObj.a_bit_test_const_subsetreg_reg(list: TAsmList; fromsubsetsize, destsize: TDef; bitnumber: aint; const setreg: TSubsetRegister; destreg: TRegister);
    var
      tmpsreg: TSubsetRegister;
    begin
      { the first parameter is used to calculate the bit offset in }
      { case of big endian, and therefore must be the size of the  }
      { set and not of the whole subsetreg                         }
      tmpsreg:=get_bit_const_reg_sreg(fromsubsetsize,bitnumber,setreg.subsetreg);
      { now fix the size of the subsetreg }
      tmpsreg.subsetregsize:=setreg.subsetregsize;
      { correct offset of the set in the subsetreg }
      inc(tmpsreg.startbit,setreg.startbit);
      a_load_subsetreg_reg(list,fromsubsetsize,destsize,tmpsreg,destreg);
    end;

  procedure THLCGObj.a_bit_test_reg_ref_reg(list: TAsmList; bitnumbersize, refsize, destsize: TDef; bitnumber: TRegister; const ref: TReference; destreg: TRegister);
    var
      href: TReference;
    begin
      href:=ref;
      g_ptrtypecast_ref(list,CPointerDef.getreusable(refsize),CPointerDef.getreusable(u8inttype),href);
      a_load_subsetref_reg(list,u8inttype,destsize,get_bit_reg_ref_sref(list,bitnumbersize,refsize,bitnumber,href),destreg);
    end;

  procedure THLCGObj.a_bit_test_reg_loc_reg(list: TAsmList; bitnumbersize, locsize, destsize: TDef; bitnumber: TRegister; const loc: TLocation; destreg: TRegister);
    var
      tmpreg: TRegister;
    begin
      case loc.loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          a_bit_test_reg_ref_reg(list,bitnumbersize,locsize,destsize,bitnumber,loc.reference,destreg);
        LOC_REGISTER,LOC_CREGISTER,
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_CONSTANT:
          begin
            case loc.loc of
              LOC_REGISTER,LOC_CREGISTER:
                tmpreg:=loc.register;
              LOC_SUBSETREG,LOC_CSUBSETREG:
                begin
                  tmpreg:=getintregister(list,locsize);
                  a_load_subsetreg_reg(list,locsize,locsize,loc.sreg,tmpreg);
                end;
              LOC_CONSTANT:
                begin
                  tmpreg:=getintregister(list,locsize);
                  a_load_const_reg(list,locsize,loc.value,tmpreg);
                end;
              else
                InternalError(2013112909);
            end;
            a_bit_test_reg_reg_reg(list,bitnumbersize,locsize,destsize,bitnumber,tmpreg,destreg);
          end;
        { LOC_SUBSETREF is not possible, because sets are not (yet) bitpacked }
        else
          InternalError(2010120411);
      end;
    end;

  procedure THLCGObj.a_bit_test_const_loc_reg(list: TAsmList; locsize, destsize: TDef; bitnumber: aint; const loc: TLocation; destreg: TRegister);
    begin
      case loc.loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          a_bit_test_const_ref_reg(list,locsize,destsize,bitnumber,loc.reference,destreg);
        LOC_REGISTER,LOC_CREGISTER:
          a_bit_test_const_reg_reg(list,locsize,destsize,bitnumber,loc.register,destreg);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          a_bit_test_const_subsetreg_reg(list,locsize,destsize,bitnumber,loc.sreg,destreg);
        { LOC_SUBSETREF is not possible, because sets are not (yet) bitpacked }
        else
          InternalError(2010120410);
      end;
    end;

  procedure THLCGObj.a_bit_set_reg_reg(list: TAsmList; doset: boolean; bitnumbersize, destsize: TDef; bitnumber, dest: TRegister);
    var
      tmpvalue: TRegister;
    begin
      tmpvalue:=getintregister(list,destsize);

      if (TargetInfo.endian=endian_little) then
        begin
          a_load_const_reg(list,destsize,1,tmpvalue);
          { rotate bit "bitnumber" bits to the left }
          a_op_reg_reg(list,OP_SHL,destsize,bitnumber,tmpvalue);
        end
      else
        begin
          { highest (leftmost) bit = bit 0 -> "$80/$8000/$80000000/ ... }
          { shr bitnumber" results in correct mask                      }
          a_load_const_reg(list,destsize,1 shl (destsize.size*8-1),tmpvalue);
          a_op_reg_reg(list,OP_SHR,destsize,bitnumber,tmpvalue);
        end;
      { set/clear the bit we want }
      if doset then
        a_op_reg_reg(list,OP_OR,destsize,tmpvalue,dest)
      else
        begin
          a_op_reg_reg(list,OP_NOT,destsize,tmpvalue,tmpvalue);
          a_op_reg_reg(list,OP_AND,destsize,tmpvalue,dest)
        end;
    end;

  procedure THLCGObj.a_bit_set_const_ref(list: TAsmList; doset: boolean; destsize: TDef; bitnumber: TCGInt; const ref: TReference);
    var
      href: TReference;
    begin
      href:=ref;
      g_ptrtypecast_ref(list,CPointerDef.getreusable(destsize),CPointerDef.getreusable(u8inttype),href);
      a_load_const_subsetref(list,u8inttype,ord(doset),get_bit_const_ref_sref(bitnumber,destsize,href));
    end;

  procedure THLCGObj.a_bit_set_const_reg(list: TAsmList; doset: boolean; destsize: TDef; bitnumber: TCGInt; destreg: TRegister);
    begin
      g_ptrtypecast_reg(list,CPointerDef.getreusable(destsize),CPointerDef.getreusable(u8inttype),destreg);
      a_load_const_subsetreg(list,u8inttype,ord(doset),get_bit_const_reg_sreg(destsize,bitnumber,destreg));
    end;

  procedure THLCGObj.a_bit_set_const_subsetreg(list: TAsmList; doset: boolean; destsize: TDef; bitnumber: TCGInt; const destreg: TSubsetRegister);
    var
      tmpsreg: TSubsetRegister;
    begin
      { the first parameter is used to calculate the bit offset in }
      { case of big endian, and therefore must be the size of the  }
      { set and not of the whole subsetreg                         }
      tmpsreg:=get_bit_const_reg_sreg(destsize,bitnumber,destreg.subsetreg);
      { now fix the size of the subsetreg }
      tmpsreg.subsetregsize:=destreg.subsetregsize;
      { correct offset of the set in the subsetreg }
      inc(tmpsreg.startbit,destreg.startbit);
      a_load_const_subsetreg(list,u8inttype,ord(doset),tmpsreg);
    end;

  procedure THLCGObj.a_bit_set_reg_ref(list: TAsmList; doset: boolean; fromsize, tosize: TDef; bitnumber: TRegister; const ref: TReference);
    var
      href: TReference;
    begin
      href:=ref;
      g_ptrtypecast_ref(list,CPointerDef.getreusable(tosize),CPointerDef.getreusable(u8inttype),href);
      a_load_const_subsetref(list,u8inttype,ord(doset),get_bit_reg_ref_sref(list,fromsize,tosize,bitnumber,href));
    end;

  procedure THLCGObj.a_bit_set_reg_loc(list: TAsmList; doset: boolean; regsize, tosize: TDef; bitnumber: TRegister; const loc: TLocation);
    var
      tmpreg: TRegister;
    begin
      case loc.loc of
        LOC_REFERENCE:
          a_bit_set_reg_ref(list,doset,regsize,tosize,bitnumber,loc.reference);
        LOC_CREGISTER:
          a_bit_set_reg_reg(list,doset,regsize,tosize,bitnumber,loc.register);
        { e.g. a 2-byte set in a record regvar }
        LOC_CSUBSETREG:
          begin
            { hard to do in-place in a generic way, so operate on a copy }
            tmpreg:=getintregister(list,tosize);
            a_load_subsetreg_reg(list,tosize,tosize,loc.sreg,tmpreg);
            a_bit_set_reg_reg(list,doset,regsize,tosize,bitnumber,tmpreg);
            a_load_reg_subsetreg(list,tosize,tosize,tmpreg,loc.sreg);
          end;
        { LOC_SUBSETREF is not possible, because sets are not (yet) bitpacked }
        else
          InternalError(2010120408)
      end;
    end;

  procedure THLCGObj.a_bit_set_const_loc(list: TAsmList; doset: boolean; tosize: TDef; bitnumber: TCGInt; const loc: TLocation);
    begin
      case loc.loc of
        LOC_REFERENCE:
          a_bit_set_const_ref(list,doset,tosize,bitnumber,loc.reference);
        LOC_CREGISTER:
          a_bit_set_const_reg(list,doset,tosize,bitnumber,loc.register);
        LOC_CSUBSETREG:
          a_bit_set_const_subsetreg(list,doset,tosize,bitnumber,loc.sreg);
        { LOC_SUBSETREF is not possible, because sets are not (yet) bitpacked }
        else
          InternalError(2010120409)
      end;
    end;


  function THLCGObj.get_call_result_cgpara(pd: TAbstractProcDef; forceresdef: TDef): TCGPara;
    begin
      if pd.generate_safecall_wrapper then
        begin
          if Assigned(forceresdef) then
            InternalError(2019112403);
          result:=paramanager.get_safecallresult_funcretloc(pd,callerside)
        end
      else if not Assigned(forceresdef) then
        begin
          pd.init_paraloc_info(callerside);
          result:=pd.funcretloc[callerside];
        end
      else
        result:=paramanager.get_funcretloc(pd,callerside,forceresdef);
    end;


  (*
    Subsetrefs are used for (bit)packed arrays and (bit)packed records stored
    in memory. They are like a regular reference, but contain an extra bit
    offset (either constant -startbit- or variable -bitindexreg-, always OS_INT)
    and a bit length (always constant).

    Bit packed values are stored differently in memory depending on whether we
    are on a big or a little endian system (compatible with at least GPC). The
    size of the basic working unit is always the smallest power-of-2 byte size
    which can contain the bit value (so 1..8 bits -> 1 byte, 9..16 bits -> 2
    bytes, 17..32 bits -> 4 bytes etc).

    On a big endian, 5-bit: values are stored like this:
      11111222 22333334 44445555 56666677 77788888
    The leftmost bit of each 5-bit value corresponds to the most significant
    bit.

    On little endian, it goes like this:
      22211111 43333322 55554444 77666665 88888777
    In this case, per byte the left-most bit is more significant than those on
    the right, but the bits in the next byte are all more significant than
    those in the previous byte (e.g., the 222 in the first byte are the low
    three bits of that value, while the 22 in the second byte are the upper
    two bits.

    Big endian, 9 bit values:
      11111111 12222222 22333333 33344444 ...

    Little endian, 9 bit values:
      11111111 22222221 33333322 44444333 ...
    This is memory representation and the 16 bit values are byteswapped.
    Similarly as in the previous case, the 2222222 string contains the lower
    bits of value 2 and the 22 string contains the upper bits. Once loaded into
    registers (two 16 bit registers in the current implementation, although a
    single 32 bit register would be possible too, in particular if 32 bit
    alignment can be guaranteed), this becomes:
      22222221 11111111 44444333 33333322 ...
      (l)ow  u     l     l    u     l   u

    The startbit/bitindex in a subsetreference always refers to
    a) on big endian: the most significant bit of the value
       (bits counted from left to right, both memory an registers)
    b) on little endian: the least significant bit when the value
       is loaded in a register (bit counted from right to left)

    Although a) results in more complex code for big endian systems, it's
    needed for compatibility both with GPC and with e.g. bitpacked arrays in
    Apple's universal interfaces which depend on these layout differences).

    Note: when changing the loadsize calculated in get_subsetref_load_info,
    make sure the appropriate alignment is guaranteed, at least in case of
    {$defined cpurequiresproperalignment}.
  *)

  procedure THLCGObj.get_subsetref_load_info(const sref: TSubsetReference; out loadsize: TOrdDef; out extra_load: boolean);
    var
      intloadsize: TCGInt;
    begin
      intloadsize:=PackedBitsLoadSize(sref.bitlen);

      if (intloadsize=0) then
        InternalError(2006081310);

      if (intloadsize>sizeof(aint)) then
        intloadsize:=sizeof(aint);
      loadsize:=cgsize_orddef(int_cgsize(intloadsize));

      if (sref.bitlen>sizeof(aint)*8) then
        InternalError(2006081312);

      extra_load:=
        (sref.bitlen<>1) and
        ((sref.bitindexreg<>NR_NO) or
         (byte(sref.startbit+sref.bitlen)>byte(intloadsize*8)));
    end;

  procedure THLCGObj.a_load_subsetref_regs_noindex(list: TAsmList; subsetsize: TDef; loadbitsize: byte; const sref: TSubsetReference; valuereg, extra_value_reg: TRegister);
    var
      restbits: byte;
    begin
      if (TargetInfo.endian=endian_big) then
        begin
          { valuereg contains the upper bits, extra_value_reg the lower }
          restbits:=(sref.bitlen-(loadbitsize-sref.startbit));
          if is_signed(subsetsize) then
            begin
              { sign extend }
              a_op_const_reg(list,OP_SHL,aluuinttype,AIntBits-loadbitsize+sref.startbit,valuereg);
              a_op_const_reg(list,OP_SAR,aluuinttype,AIntBits-sref.bitlen,valuereg);
            end
          else
            begin
              a_op_const_reg(list,OP_SHL,aluuinttype,restbits,valuereg);
              { mask other bits }
              if (sref.bitlen<>AIntBits) then
                a_op_const_reg(list,OP_AND,aluuinttype,TCGInt((aword(1) shl sref.bitlen)-1),valuereg);
            end;
          a_op_const_reg(list,OP_SHR,aluuinttype,loadbitsize-restbits,extra_value_reg)
        end
      else
        begin
          { valuereg contains the lower bits, extra_value_reg the upper }
          a_op_const_reg(list,OP_SHR,aluuinttype,sref.startbit,valuereg);
          if is_signed(subsetsize) then
            begin
              a_op_const_reg(list,OP_SHL,aluuinttype,AIntBits-sref.bitlen+loadbitsize-sref.startbit,extra_value_reg);
              a_op_const_reg(list,OP_SAR,aluuinttype,AIntBits-sref.bitlen,extra_value_reg);
            end
          else
            begin
              a_op_const_reg(list,OP_SHL,aluuinttype,loadbitsize-sref.startbit,extra_value_reg);
              { mask other bits }
              if (sref.bitlen <> AIntBits) then
                a_op_const_reg(list,OP_AND,aluuinttype,TCGInt((aword(1) shl sref.bitlen)-1),extra_value_reg);
            end;
        end;
      { merge }
      a_op_reg_reg(list,OP_OR,aluuinttype,extra_value_reg,valuereg);
    end;

  procedure THLCGObj.a_load_subsetref_regs_index(list: TAsmList; subsetsize: TDef; loadbitsize: byte; const sref: TSubsetReference; valuereg: TRegister);
    var
      hl: TAsmLabel;
      tmpref: TReference;
      extra_value_reg,
      tmpreg: TRegister;
    begin
      tmpreg:=getintregister(list,aluuinttype);
      tmpref:=sref.ref;
      inc(tmpref.offset,loadbitsize div 8);
      extra_value_reg:=getintregister(list,aluuinttype);

      if (TargetInfo.endian=endian_big) then
        begin
          { since this is a dynamic index, it's possible that the value   }
          { is entirely in valuereg.                                      }

          { get the data in valuereg in the right place }
          a_op_reg_reg(list,OP_SHL,aluuinttype,sref.bitindexreg,valuereg);
          if is_signed(subsetsize) then
            begin
              a_op_const_reg(list,OP_SHL,aluuinttype,AIntBits-loadbitsize,valuereg);
              a_op_const_reg(list,OP_SAR,aluuinttype,AIntBits-sref.bitlen,valuereg)
            end
          else
            begin
              a_op_const_reg(list,OP_SHR,aluuinttype,loadbitsize-sref.bitlen,valuereg);
              if (loadbitsize<>AIntBits) then
                { mask left over bits }
                a_op_const_reg(list,OP_AND,aluuinttype,TCGInt((aword(1) shl sref.bitlen)-1),valuereg);
            end;
          tmpreg := getintregister(list,aluuinttype);

          { ensure we don't load anything past the end of the array }
          CurrentAsmData.getjumplabel(hl);
          a_cmp_const_reg_label(list,aluuinttype,OC_BE,loadbitsize-sref.bitlen,sref.bitindexreg,hl);

          { the bits in extra_value_reg (if any) start at the most significant bit =>         }
          { extra_value_reg must be shr by (loadbitsize-sref.bitlen)+(loadsize-sref.bitindex) }
          { => = -(sref.bitindex+(sref.bitlen-2*loadbitsize))                                 }
          a_op_const_reg_reg(list,OP_ADD,aluuinttype,sref.bitlen-2*loadbitsize,sref.bitindexreg,tmpreg);
          a_op_reg_reg(list,OP_NEG,aluuinttype,tmpreg,tmpreg);

          { load next "loadbitsize" bits of the array }
          a_load_ref_reg(list,cgsize_orddef(int_cgsize(loadbitsize div 8)),aluuinttype,tmpref,extra_value_reg);

          a_op_reg_reg(list,OP_SHR,aluuinttype,tmpreg,extra_value_reg);
          { if there are no bits in extra_value_reg, then sref.bitindex was      }
          { < loadsize-sref.bitlen, and therefore tmpreg will now be >= loadsize }
          { => extra_value_reg is now 0                                          }
          { merge }
          a_op_reg_reg(list,OP_OR,aluuinttype,extra_value_reg,valuereg);
          { no need to mask, necessary masking happened earlier on }
          a_label(list,hl);
        end
      else
        begin
          a_op_reg_reg(list,OP_SHR,aluuinttype,sref.bitindexreg,valuereg);

          { ensure we don't load anything past the end of the array }
          CurrentAsmData.getjumplabel(hl);
          a_cmp_const_reg_label(list,aluuinttype,OC_BE,loadbitsize-sref.bitlen,sref.bitindexreg,hl);

          { Y-x = -(Y-x) }
          a_op_const_reg_reg(list,OP_SUB,aluuinttype,loadbitsize,sref.bitindexreg,tmpreg);
          a_op_reg_reg(list,OP_NEG,aluuinttype,tmpreg,tmpreg);

          { load next "loadbitsize" bits of the array }
          a_load_ref_reg(list,cgsize_orddef(int_cgsize(loadbitsize div 8)),aluuinttype,tmpref,extra_value_reg);

          { tmpreg is in the range 1..<cpu_bitsize>-1 -> always ok }
          a_op_reg_reg(list,OP_SHL,aluuinttype,tmpreg,extra_value_reg);
          { merge }
          a_op_reg_reg(list,OP_OR,aluuinttype,extra_value_reg,valuereg);
          a_label(list,hl);
          { sign extend or mask other bits }
          if is_signed(subsetsize) then
            begin
              a_op_const_reg(list,OP_SHL,aluuinttype,AIntBits-sref.bitlen,valuereg);
              a_op_const_reg(list,OP_SAR,aluuinttype,AIntBits-sref.bitlen,valuereg);
            end
          else
            a_op_const_reg(list,OP_AND,aluuinttype,TCGInt((aword(1) shl sref.bitlen)-1),valuereg);
        end;
    end;

  procedure THLCGObj.a_load_regconst_subsetref_intern(list: TAsmList; fromsize, subsetsize: TDef; fromreg: TRegister; const sref: TSubsetReference; slopt: TSubsetLoadOpt);
    var
      hl: TAsmLabel;
      tmpreg, tmpindexreg, valuereg, extra_value_reg, maskreg: TRegister;
      tosreg, fromsreg: TSubsetRegister;
      tmpref: TReference;
      bitmask: aword;
      loadsize: TOrdDef;
      loadbitsize: byte;
      extra_load: boolean;
    begin
      { the register must be able to contain the requested value }
      if (fromsize.size*8<sref.bitlen) then
        InternalError(2006081613);

      get_subsetref_load_info(sref,loadsize,extra_load);
      loadbitsize:=loadsize.size*8;

      { load the (first part) of the bit sequence }
      valuereg:=getintregister(list,aluuinttype);
      a_load_ref_reg(list,loadsize,aluuinttype,sref.ref,valuereg);

      { constant offset of bit sequence? }
      if not extra_load then
        begin
          if (sref.bitindexreg=NR_NO) then
            begin
              { use subsetreg routine, it may have been overridden with an optimized version }
              tosreg.subsetreg:=valuereg;
              tosreg.subsetregsize:=def_cgsize(aluuinttype);
              { subsetregs always count bits from right to left }
              if (TargetInfo.endian=endian_big) then
                tosreg.startbit:=loadbitsize-(sref.startbit+sref.bitlen)
              else
                tosreg.startbit:=sref.startbit;
              tosreg.bitlen:=sref.bitlen;
              a_load_regconst_subsetreg_intern(list,fromsize,subsetsize,fromreg,tosreg,slopt);
            end
          else
            begin
              if (sref.startbit<>0) then
                InternalError(2006081710);
              { should be handled by normal code and will give wrong result }
              { on x86 for the '1 shl bitlen' below                         }
              if (sref.bitlen=AIntBits) then
                InternalError(2006081711);

              { zero the bits we have to insert }
              if (slopt<>SL_SETMAX) then
                begin
                  if (slopt=SL_SETZERO) and (sref.bitlen=1) and (TargetInfo.endian=endian_little) then
                    begin
                      a_bit_set_reg_reg(list,false,aluuinttype,aluuinttype,sref.bitindexreg,valuereg);

                      { store back to memory }
                      tmpreg:=getintregister(list,loadsize);
                      a_load_reg_reg(list,aluuinttype,loadsize,valuereg,tmpreg);
                      a_load_reg_ref(list,loadsize,loadsize,tmpreg,sref.ref);
                      exit;
                    end
                  else
                    begin
                      maskreg:=getintregister(list,aluuinttype);
                      if (TargetInfo.endian = endian_big) then
                        begin
                          a_load_const_reg(list,aluuinttype,TCGInt((aword(1) shl sref.bitlen)-1) shl (loadbitsize-sref.bitlen),maskreg);
                          a_op_reg_reg(list,OP_SHR,aluuinttype,sref.bitindexreg,maskreg);
                        end
                      else
                        begin
                          a_load_const_reg(list,aluuinttype,TCGInt((aword(1) shl sref.bitlen)-1),maskreg);
                          a_op_reg_reg(list,OP_SHL,aluuinttype,sref.bitindexreg,maskreg);
                        end;
                      a_op_reg_reg(list,OP_NOT,aluuinttype,maskreg,maskreg);
                      a_op_reg_reg(list,OP_AND,aluuinttype,maskreg,valuereg);
                    end;
                end;

              { insert the value }
              if (slopt<>SL_SETZERO) then
                begin
                  tmpreg:=getintregister(list,aluuinttype);
                  if (slopt<>SL_SETMAX) then
                    a_load_reg_reg(list,fromsize,aluuinttype,fromreg,tmpreg)
                  { setting of a single bit?
                    then we might take advantage of the CPU's bit set instruction }
                  else if (sref.bitlen=1) and (TargetInfo.endian=endian_little) then
                    begin
                      a_bit_set_reg_reg(list,true,aluuinttype,aluuinttype,sref.bitindexreg,valuereg);

                      { store back to memory }
                      tmpreg:=getintregister(list,loadsize);
                      a_load_reg_reg(list,aluuinttype,loadsize,valuereg,tmpreg);
                      a_load_reg_ref(list,loadsize,loadsize,tmpreg,sref.ref);
                      exit;
                    end
                  else if (sref.bitlen<>AIntBits) then
                    a_load_const_reg(list,aluuinttype,TCGInt((aword(1) shl sref.bitlen)-1), tmpreg)
                  else
                    a_load_const_reg(list,aluuinttype,-1,tmpreg);
                  if (TargetInfo.endian=endian_big) then
                    begin
                      a_op_const_reg(list,OP_SHL,aluuinttype,loadbitsize-sref.bitlen,tmpreg);
                      if not(slopt in [SL_REGNOSRCMASK,SL_SETMAX]) then
                        begin
                          if (loadbitsize<>AIntBits) then
                            bitmask:=(((aword(1) shl loadbitsize)-1) xor ((aword(1) shl (loadbitsize-sref.bitlen))-1))
                          else
                            bitmask:=(high(aword) xor ((aword(1) shl (loadbitsize-sref.bitlen))-1));
                          a_op_const_reg(list,OP_AND,aluuinttype,bitmask,tmpreg);
                        end;
                      a_op_reg_reg(list,OP_SHR,aluuinttype,sref.bitindexreg,tmpreg);
                    end
                  else
                    begin
                      if not(slopt in [SL_REGNOSRCMASK,SL_SETMAX]) then
                        a_op_const_reg(list,OP_AND,aluuinttype,TCGInt((aword(1) shl sref.bitlen)-1),tmpreg);
                      a_op_reg_reg(list,OP_SHL,aluuinttype,sref.bitindexreg,tmpreg);
                    end;
                  a_op_reg_reg(list,OP_OR,aluuinttype,tmpreg,valuereg);
                end;
            end;
          { store back to memory }
          tmpreg:=getintregister(list,loadsize);
          a_load_reg_reg(list,aluuinttype,loadsize,valuereg,tmpreg);
          a_load_reg_ref(list,loadsize,loadsize,tmpreg,sref.ref);
          exit;
        end
      else
        begin
          { load next value }
          extra_value_reg:=getintregister(list,aluuinttype);
          tmpref:=sref.ref;
          inc(tmpref.offset,loadbitsize div 8);

          { should maybe be taken out too, can be done more efficiently }
          { on e.g. i386 with shld/shrd                                 }
          if (sref.bitindexreg = NR_NO) then
            begin
              a_load_ref_reg(list,loadsize,aluuinttype,tmpref,extra_value_reg);

              fromsreg.subsetreg:=fromreg;
              fromsreg.subsetregsize:=def_cgsize(fromsize);
              tosreg.subsetreg:=valuereg;
              tosreg.subsetregsize:=def_cgsize(aluuinttype);

              { transfer first part }
              fromsreg.bitlen:=loadbitsize-sref.startbit;
              tosreg.bitlen:=fromsreg.bitlen;
              if (TargetInfo.endian=endian_big) then
                begin
                  { valuereg must contain the upper bits of the value at bits [0..loadbitsize-startbit] }

                  { upper bits of the value ... }
                  fromsreg.startbit:=sref.bitlen-(loadbitsize-sref.startbit);
                  { ... to bit 0 }
                  tosreg.startbit:=0
                end
              else
                begin
                  { valuereg must contain the lower bits of the value at bits [startbit..loadbitsize] }

                  { lower bits of the value ... }
                  fromsreg.startbit:=0;
                  { ... to startbit }
                  tosreg.startbit:=sref.startbit;
                end;
              case slopt of
                SL_SETZERO,
                SL_SETMAX:
                  a_load_regconst_subsetreg_intern(list,fromsize,subsetsize,fromreg,tosreg,slopt);
                else
                  a_load_subsetreg_subsetreg(list,subsetsize,subsetsize,fromsreg,tosreg);
              end;
{$ifndef cpuhighleveltarget}
              valuereg:=cg.makeregsize(list,valuereg,def_cgsize(loadsize));
              a_load_reg_ref(list,loadsize,loadsize,valuereg,sref.ref);
{$else}
              tmpreg:=getintregister(list,loadsize);
              a_load_reg_reg(list,aluuinttype,loadsize,valuereg,tmpreg);
              a_load_reg_ref(list,loadsize,loadsize,tmpreg,sref.ref);
{$endif}

              { transfer second part }
              if (TargetInfo.endian = endian_big) then
                begin
                  { extra_value_reg must contain the lower bits of the value at bits  }
                  { [(loadbitsize-(bitlen-(loadbitsize-startbit)))..loadbitsize]  }
                  { (loadbitsize-(bitlen-(loadbitsize-startbit))) = 2*loadbitsize }
                  { - bitlen - startbit }

                  fromsreg.startbit:=0;
                  tosreg.startbit:=2*loadbitsize-sref.bitlen-sref.startbit
                end
              else
                begin
                  { extra_value_reg must contain the upper bits of the value at bits [0..bitlen-(loadbitsize-startbit)] }

                  fromsreg.startbit:=fromsreg.bitlen;
                  tosreg.startbit:=0;
                end;
              tosreg.subsetreg:=extra_value_reg;
              fromsreg.bitlen:=sref.bitlen-fromsreg.bitlen;
              tosreg.bitlen:=fromsreg.bitlen;

              case slopt of
                SL_SETZERO,
                SL_SETMAX:
                  a_load_regconst_subsetreg_intern(list,fromsize,subsetsize,fromreg,tosreg,slopt);
                else
                  a_load_subsetreg_subsetreg(list,subsetsize,subsetsize,fromsreg,tosreg);
              end;
              tmpreg:=getintregister(list,loadsize);
              a_load_reg_reg(list,aluuinttype,loadsize,extra_value_reg,tmpreg);
              a_load_reg_ref(list,loadsize,loadsize,tmpreg,tmpref);
              exit;
            end
          else
            begin
              if (sref.startbit <> 0) then
                InternalError(2006081812);
              { should be handled by normal code and will give wrong result }
              { on x86 for the '1 shl bitlen' below                         }
              if (sref.bitlen = AIntBits) then
                InternalError(2006081713);

              { generate mask to zero the bits we have to insert }
              if (slopt <> SL_SETMAX) then
                begin
                  maskreg := getintregister(list,aluuinttype);
                  if (TargetInfo.endian = endian_big) then
                    begin
                      a_load_const_reg(list,aluuinttype,TCGInt(((aword(1) shl sref.bitlen)-1) shl (loadbitsize-sref.bitlen)),maskreg);
                      a_op_reg_reg(list,OP_SHR,aluuinttype,sref.bitindexreg,maskreg);
                    end
                  else
                    begin
                      a_load_const_reg(list,aluuinttype,TCGInt((aword(1) shl sref.bitlen)-1),maskreg);
                      a_op_reg_reg(list,OP_SHL,aluuinttype,sref.bitindexreg,maskreg);
                    end;

                  a_op_reg_reg(list,OP_NOT,aluuinttype,maskreg,maskreg);
                  a_op_reg_reg(list,OP_AND,aluuinttype,maskreg,valuereg);
                end;

              { insert the value }
              if (slopt <> SL_SETZERO) then
                begin
                  tmpreg := getintregister(list,aluuinttype);
                  if (slopt <> SL_SETMAX) then
                    a_load_reg_reg(list,fromsize,aluuinttype,fromreg,tmpreg)
                  else if (sref.bitlen <> AIntBits) then
                    a_load_const_reg(list,aluuinttype,TCGInt((aword(1) shl sref.bitlen) - 1), tmpreg)
                  else
                    a_load_const_reg(list,aluuinttype,-1,tmpreg);
                  if (TargetInfo.endian = endian_big) then
                    begin
                      a_op_const_reg(list,OP_SHL,aluuinttype,loadbitsize-sref.bitlen,tmpreg);
                      if not(slopt in [SL_REGNOSRCMASK,SL_SETMAX]) then
                        { mask left over bits }
                        a_op_const_reg(list,OP_AND,aluuinttype,TCGInt(((aword(1) shl sref.bitlen)-1) shl (loadbitsize-sref.bitlen)),tmpreg);
                      a_op_reg_reg(list,OP_SHR,aluuinttype,sref.bitindexreg,tmpreg);
                    end
                  else
                    begin
                      if not(slopt in [SL_REGNOSRCMASK,SL_SETMAX]) then
                        { mask left over bits }
                        a_op_const_reg(list,OP_AND,aluuinttype,TCGInt((aword(1) shl sref.bitlen)-1),tmpreg);
                      a_op_reg_reg(list,OP_SHL,aluuinttype,sref.bitindexreg,tmpreg);
                    end;
                  a_op_reg_reg(list,OP_OR,aluuinttype,tmpreg,valuereg);
                end;
              tmpreg:=getintregister(list,loadsize);
              a_load_reg_reg(list,aluuinttype,loadsize,valuereg,tmpreg);
              a_load_reg_ref(list,loadsize,loadsize,tmpreg,sref.ref);

              { make sure we do not read/write past the end of the array }
              CurrentAsmData.getjumplabel(hl);
              a_cmp_const_reg_label(list,aluuinttype,OC_BE,loadbitsize-sref.bitlen,sref.bitindexreg,hl);

              a_load_ref_reg(list,loadsize,aluuinttype,tmpref,extra_value_reg);
              tmpindexreg:=getintregister(list,aluuinttype);

              { load current array value }
              if (slopt<>SL_SETZERO) then
                begin
                  tmpreg:=getintregister(list,aluuinttype);
                  if (slopt<>SL_SETMAX) then
                     a_load_reg_reg(list,fromsize,aluuinttype,fromreg,tmpreg)
                  else if (sref.bitlen<>AIntBits) then
                    a_load_const_reg(list,aluuinttype,TCGInt((aword(1) shl sref.bitlen) - 1), tmpreg)
                  else
                    a_load_const_reg(list,aluuinttype,-1,tmpreg);
                end;

              { generate mask to zero the bits we have to insert }
              if (slopt<>SL_SETMAX) then
                begin
                  maskreg:=getintregister(list,aluuinttype);
                  if (TargetInfo.endian=endian_big) then
                    begin
                      a_op_const_reg_reg(list,OP_ADD,aluuinttype,sref.bitlen-2*loadbitsize,sref.bitindexreg,tmpindexreg);
                      a_op_reg_reg(list,OP_NEG,aluuinttype,tmpindexreg,tmpindexreg);
                      a_load_const_reg(list,aluuinttype,TCGInt((aword(1) shl sref.bitlen)-1),maskreg);
                      a_op_reg_reg(list,OP_SHL,aluuinttype,tmpindexreg,maskreg);
                    end
                  else
                    begin
                      { Y-x = -(x-Y) }
                      a_op_const_reg_reg(list,OP_SUB,aluuinttype,loadbitsize,sref.bitindexreg,tmpindexreg);
                      a_op_reg_reg(list,OP_NEG,aluuinttype,tmpindexreg,tmpindexreg);
                      a_load_const_reg(list,aluuinttype,TCGInt((aword(1) shl sref.bitlen)-1),maskreg);
                      a_op_reg_reg(list,OP_SHR,aluuinttype,tmpindexreg,maskreg);
                    end;

                  a_op_reg_reg(list,OP_NOT,aluuinttype,maskreg,maskreg);
                  a_op_reg_reg(list,OP_AND,aluuinttype,maskreg,extra_value_reg);
                end;

              if (slopt<>SL_SETZERO) then
                begin
                  if (TargetInfo.endian=endian_big) then
                    a_op_reg_reg(list,OP_SHL,aluuinttype,tmpindexreg,tmpreg)
                  else
                    begin
                      if not(slopt in [SL_REGNOSRCMASK,SL_SETMAX]) then
                        a_op_const_reg(list,OP_AND,aluuinttype,TCGInt((aword(1) shl sref.bitlen)-1),tmpreg);
                      a_op_reg_reg(list,OP_SHR,aluuinttype,tmpindexreg,tmpreg);
                    end;
                  a_op_reg_reg(list,OP_OR,aluuinttype,tmpreg,extra_value_reg);
                end;
{$ifndef cpuhighleveltarget}
              extra_value_reg:=cg.makeregsize(list,extra_value_reg,def_cgsize(loadsize));
              a_load_reg_ref(list,loadsize,loadsize,extra_value_reg,tmpref);
{$else}
              tmpreg:=getintregister(list,loadsize);
              a_load_reg_reg(list,aluuinttype,loadsize,extra_value_reg,tmpreg);
              a_load_reg_ref(list,loadsize,loadsize,tmpreg,tmpref);
{$endif}

              a_label(list,hl);
            end;
        end;
    end;

  procedure THLCGObj.a_load_regconst_subsetreg_intern(list: TAsmList; fromsize, subsetsize: TDef; fromreg: TRegister; const sreg: TSubsetRegister; slopt: TSubsetLoadOpt);
    var
      bitmask: aword;
      tmpreg: TRegister;
      subsetregdef: TOrdDef;
      stopbit: byte;

    begin
      tmpreg:=NR_NO;
      subsetregdef:=cgsize_orddef(sreg.subsetregsize);
      stopbit:=sreg.startbit+sreg.bitlen;
      // on x86(64), 1 shl 32(64) = 1 instead of 0
      if (stopbit<>AIntBits) then
        bitmask:=not(((aword(1) shl stopbit)-1) xor ((aword(1) shl sreg.startbit)-1))
      else
        bitmask:=not(high(aword) xor ((aword(1) shl sreg.startbit)-1));
      if not(slopt in [SL_SETZERO,SL_SETMAX]) then
        begin
          tmpreg:=getintregister(list,subsetregdef);
          a_load_reg_reg(list,fromsize,subsetregdef,fromreg,tmpreg);
          a_op_const_reg(list,OP_SHL,subsetregdef,sreg.startbit,tmpreg);
           if (slopt<>SL_REGNOSRCMASK) then
            a_op_const_reg(list,OP_AND,subsetregdef,TCGInt(not(bitmask)),tmpreg);
        end;

      if (slopt<>SL_SETMAX) and
      { the "and" is not needed if the whole register is modified (except for SL_SETZERO),
        because later on we do a move in this case instead of an or }
        ((sreg.bitlen<>AIntBits) or (slopt=SL_SETZERO)) then
          begin
            { shl could wrap around in this case }
            if subsetregdef.size=sizeof(aword) then
              a_op_const_reg(list,OP_AND,subsetregdef,TCGInt(bitmask),sreg.subsetreg)
            else
              a_op_const_reg(list,OP_AND,subsetregdef,TCGInt(bitmask) and aword((aword(1) shl (subsetregdef.size*8))-1),sreg.subsetreg);
          end;

      case slopt of
        SL_SETZERO : ;
        SL_SETMAX :
          if (sreg.bitlen<>AIntBits) then
            a_op_const_reg(list,OP_OR,subsetregdef,
              TCGInt(((aword(1) shl sreg.bitlen)-1) shl sreg.startbit),
              sreg.subsetreg)
          else
            a_load_const_reg(list,subsetregdef,-1,sreg.subsetreg);
        { if the whole register is modified, no "or" is needed }
        else if sreg.bitlen=AIntBits then
          a_load_reg_reg(list,subsetregdef,subsetregdef,tmpreg,sreg.subsetreg)
        else
          a_op_reg_reg(list,OP_OR,subsetregdef,tmpreg,sreg.subsetreg)
       end;
    end;

  {$pop}

  function THLCGObj.get_bit_const_ref_sref(bitnumber: TCGInt; refdef: TDef; const ref: TReference): TSubsetReference;
    begin
      result.ref:=ref;
      inc(result.ref.offset,bitnumber div 8);
      result.ref.alignment:=NewAlignment(result.ref.alignment,bitnumber div 8);
      result.bitindexreg:=NR_NO;
      result.startbit:=bitnumber mod 8;
      result.bitlen:=1;
    end;

  function THLCGObj.get_bit_const_reg_sreg(setregsize: TDef; bitnumber: TCGInt; setreg: TRegister): TSubsetRegister;
    begin
      result.subsetreg:=setreg;
      result.subsetregsize:=def_cgsize(setregsize);
      { subsetregs always count from the least significant to the most significant bit }
      if (TargetInfo.endian=endian_big) then
        result.startbit:=(setregsize.size*8)-bitnumber-1
      else
        result.startbit:=bitnumber;
      result.bitlen:=1;
    end;

  function THLCGObj.get_bit_reg_ref_sref(list: TAsmList; bitnumbersize, refsize: TDef; bitnumber: TRegister; const ref: TReference): TSubsetReference;
    var
      refptrdef: TDef;
      tmpreg,
      newbase: TRegister;
    begin
      result.ref:=ref;
      result.startbit:=0;
      result.bitlen:=1;

      tmpreg:=getintregister(list,ptruinttype);
      a_load_reg_reg(list,bitnumbersize,ptruinttype,bitnumber,tmpreg);
      a_op_const_reg(list,OP_SHR,ptruinttype,3,tmpreg);

      { don't assign to ref.base, that one is for pointers and this is an index
        (important for platforms like LLVM) }
      if result.ref.index<>NR_NO then
        begin
          { don't just add to ref.index, as it may be scaled }
          refptrdef:=CPointerDef.getreusable(refsize);
          newbase:=getaddressregister(list,refptrdef);
          a_loadaddr_ref_reg(list,refsize,refptrdef,ref,newbase);
          reference_reset_base(result.ref,refptrdef,newbase,0,result.ref.temppos,result.ref.alignment,[]);
        end;
      result.ref.index:=tmpreg;
      tmpreg:=getintregister(list,aluuinttype);
      a_load_reg_reg(list,bitnumbersize,aluuinttype,bitnumber,tmpreg);
      a_op_const_reg(list,OP_AND,aluuinttype,7,tmpreg);
      result.bitindexreg:=tmpreg;
    end;

  procedure THLCGObj.a_loadfpu_ref_ref(list: TAsmList; fromsize, tosize: TDef; const ref1, ref2: TReference);
    var
      reg: TRegister;
      regsize: TDef;
    begin
      if (fromsize.size>=tosize.size) then
        regsize:=fromsize
      else
        regsize:=tosize;
      reg:=getfpuregister(list,regsize);
      a_loadfpu_ref_reg(list,fromsize,regsize,ref1,reg);
      a_loadfpu_reg_ref(list,regsize,tosize,reg,ref2);
    end;

  procedure THLCGObj.a_loadfpu_loc_reg(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; const reg: TRegister);
    begin
      case loc.loc of
        LOC_REFERENCE, LOC_CREFERENCE:
          a_loadfpu_ref_reg(list,fromsize,tosize,loc.reference,reg);
        LOC_FPUREGISTER, LOC_CFPUREGISTER:
          a_loadfpu_reg_reg(list,fromsize,tosize,loc.register,reg);
        else
          InternalError(2010120412);
      end;
    end;

  procedure THLCGObj.a_loadfpu_loc_ref(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; const ref: TReference);
    var
      reg: TRegister;
    begin
      case loc.loc of
        LOC_REFERENCE, LOC_CREFERENCE:
          begin
            reg:=getfpuregister(list,tosize);
            a_loadfpu_ref_reg(list,fromsize,tosize,loc.reference,reg);
            a_loadfpu_reg_ref(list,tosize,tosize,reg,ref);
          end;
        LOC_FPUREGISTER, LOC_CFPUREGISTER:
          begin
            a_loadfpu_reg_ref(list,fromsize,tosize,loc.register,ref);
          end;
        else
          InternalError(2014080802);
      end;
    end;

  procedure THLCGObj.a_loadfpu_reg_loc(list: TAsmList; fromsize, tosize: TDef; const reg: TRegister; const loc: TLocation);
    begin
      case loc.loc of
        LOC_REFERENCE, LOC_CREFERENCE:
          a_loadfpu_reg_ref(list,fromsize,tosize,reg,loc.reference);
        LOC_FPUREGISTER, LOC_CFPUREGISTER:
          a_loadfpu_reg_reg(list,fromsize,tosize,reg,loc.register);
        else
          InternalError(2010120413);
       end;
    end;

  procedure THLCGObj.a_loadfpu_reg_cgpara(list: TAsmList; fromsize: TDef; const r: TRegister; const cgpara: TCGPara);
      var
         ref : TReference;
      begin
        paramanager.alloccgpara(list,cgpara);
        case cgpara.location^.loc of
          LOC_FPUREGISTER,LOC_CFPUREGISTER:
            begin
              cgpara.check_simple_location;
              a_loadfpu_reg_reg(list,fromsize,cgpara.def,r,cgpara.location^.register);
            end;
          LOC_REFERENCE,LOC_CREFERENCE:
            begin
              cgpara.check_simple_location;
              reference_reset_base(ref,voidstackpointertype,cgpara.location^.reference.index,cgpara.location^.reference.offset,ctempposinvalid,cgpara.alignment,[]);
              a_loadfpu_reg_ref(list,fromsize,cgpara.def,r,ref);
            end;
          LOC_REGISTER,LOC_CREGISTER:
            begin
              { paramfpu_ref does the check_simple_location check here if necessary }
              tg.gethltemp(list,fromsize,fromsize.size,tt_normal,ref);
              a_loadfpu_reg_ref(list,fromsize,fromsize,r,ref);
              a_loadfpu_ref_cgpara(list,fromsize,ref,cgpara);
              tg.Ungettemp(list,ref);
            end;
          else
            InternalError(2010120422);
        end;
      end;

  procedure THLCGObj.a_loadfpu_ref_cgpara(list: TAsmList; fromsize: TDef; const ref: TReference; const cgpara: TCGPara);
    var
       hreg : TRegister;
       href : TReference;
       intptrdef: TDef;
    begin
       case cgpara.location^.loc of
        LOC_FPUREGISTER,LOC_CFPUREGISTER:
          begin
            cgpara.check_simple_location;
            paramanager.alloccgpara(list,cgpara);
            a_loadfpu_ref_reg(list,fromsize,cgpara.location^.def,ref,cgpara.location^.register);
          end;
        LOC_REFERENCE,LOC_CREFERENCE:
          begin
            cgpara.check_simple_location;
            reference_reset_base(href,voidstackpointertype,cgpara.location^.reference.index,cgpara.location^.reference.offset,ctempposinvalid,cgpara.alignment,[]);
            { concatcopy should choose the best way to copy the data }
            g_concatcopy(list,fromsize,ref,href);
          end;
        LOC_REGISTER,LOC_CREGISTER:
          begin
            cgpara.check_simple_location;
            if fromsize.size<>cgpara.location^.def.size then
              InternalError(2014080603);
            { convert the reference from a floating point location to an
              integer location, and load that }
            intptrdef:=CPointerDef.getreusable(cgpara.location^.def);
            hreg:=getaddressregister(list,intptrdef);
            a_loadaddr_ref_reg(list,fromsize,intptrdef,ref,hreg);
            reference_reset_base(href,intptrdef,hreg,0,ref.temppos,ref.alignment,[]);
            a_load_ref_cgpara(list,cgpara.location^.def,ref,cgpara);
          end
        else
          InternalError(2010120423);
      end;
    end;

  procedure THLCGObj.a_loadmm_ref_ref(list: TAsmList; fromsize, tosize: TDef; const fromref, toref: TReference; shuffle: PMMShuffle);
    var
      reg: TRegister;
    begin
      reg:=getmmregister(list,tosize);
      a_loadmm_ref_reg(list,fromsize,tosize,fromref,reg,shuffle);
      a_loadmm_reg_ref(list,tosize,tosize,reg,toref,shuffle);
    end;

  procedure THLCGObj.a_loadmm_loc_reg(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; const reg: TRegister; shuffle: PMMShuffle);
    var
      tmpreg: TRegister;
    begin
      case loc.loc of
        LOC_MMREGISTER,LOC_CMMREGISTER:
          a_loadmm_reg_reg(list,fromsize,tosize,loc.register,reg,shuffle);
        LOC_REFERENCE,LOC_CREFERENCE:
          a_loadmm_ref_reg(list,fromsize,tosize,loc.reference,reg,shuffle);
        LOC_REGISTER,LOC_CREGISTER:
          a_loadmm_intreg_reg(list,fromsize,tosize,loc.register,reg,shuffle);
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          begin
            tmpreg:=getintregister(list,fromsize);
            a_load_loc_reg(list,fromsize,fromsize,loc,tmpreg);
            a_loadmm_intreg_reg(list,fromsize,tosize,tmpreg,reg,shuffle);
          end
        else
          InternalError(2010120414);
      end;
    end;

  procedure THLCGObj.a_loadmm_reg_loc(list: TAsmList; fromsize, tosize: TDef; const reg: TRegister; const loc: TLocation; shuffle: PMMShuffle);
    begin
      case loc.loc of
        LOC_MMREGISTER,LOC_CMMREGISTER:
          a_loadmm_reg_reg(list,fromsize,tosize,reg,loc.register,shuffle);
        LOC_REFERENCE,LOC_CREFERENCE:
          a_loadmm_reg_ref(list,fromsize,tosize,reg,loc.reference,shuffle);
        else
          InternalError(2010120417);
      end;
    end;

  procedure THLCGObj.a_loadmm_loc_ref(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; const ref: TReference; shuffle: PMMShuffle);
    var
      intreg, reg: TRegister;
    begin
      case loc.loc of
        LOC_MMREGISTER,LOC_CMMREGISTER:
          a_loadmm_reg_ref(list,fromsize,tosize,loc.register,ref,shuffle);
        LOC_REFERENCE,LOC_CREFERENCE:
          begin
            reg:=getmmregister(list,tosize);
            a_loadmm_ref_reg(list,fromsize,tosize,loc.reference,reg,shuffle);
            a_loadmm_reg_ref(list,tosize,tosize,reg,ref,shuffle);
          end;
        LOC_REGISTER,LOC_CREGISTER:
          begin
            reg:=getmmregister(list,tosize);
            a_loadmm_intreg_reg(list,fromsize,tosize,loc.register,reg,shuffle);
            a_loadmm_reg_ref(list,tosize,tosize,reg,ref,shuffle);
          end;
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          begin
            intreg:=getintregister(list,fromsize);
            reg:=getmmregister(list,tosize);
            a_load_loc_reg(list,fromsize,fromsize,loc,intreg);
            a_loadmm_intreg_reg(list,fromsize,tosize,intreg,reg,shuffle);
            a_loadmm_reg_ref(list,tosize,tosize,reg,ref,shuffle);
          end
        else
          InternalError(2014080803);
      end;
    end;

  procedure THLCGObj.a_loadmm_reg_cgpara(list: TAsmList; fromsize: TDef; reg: TRegister; const cgpara: TCGPara; shuffle: PMMShuffle);
    var
      href  : TReference;
    begin
       cgpara.check_simple_location;
       paramanager.alloccgpara(list,cgpara);
       case cgpara.location^.loc of
        LOC_MMREGISTER,LOC_CMMREGISTER:
          a_loadmm_reg_reg(list,fromsize,cgpara.def,reg,cgpara.location^.register,shuffle);
        LOC_REFERENCE,LOC_CREFERENCE:
          begin
            reference_reset_base(href,voidstackpointertype,cgpara.location^.reference.index,cgpara.location^.reference.offset,ctempposinvalid,cgpara.alignment,[]);
            a_loadmm_reg_ref(list,fromsize,cgpara.def,reg,href,shuffle);
          end;
        LOC_REGISTER,LOC_CREGISTER:
          begin
            if Assigned(shuffle) and
               not shufflescalar(shuffle) then
              InternalError(2012071205);
             a_loadmm_reg_intreg(list,fromsize,cgpara.def,reg,cgpara.location^.register,mms_movescalar);
          end
        else
          InternalError(2012071204);
      end;
    end;

  procedure THLCGObj.a_loadmm_ref_cgpara(list: TAsmList; fromsize: TDef; const ref: TReference; const cgpara: TCGPara; shuffle: PMMShuffle);
    var
       hr : TRegister;
       hs : TMMShuffle;
    begin
       cgpara.check_simple_location;
       hr:=getmmregister(list,cgpara.def);
       a_loadmm_ref_reg(list,fromsize,cgpara.def,ref,hr,shuffle);
       if realshuffle(shuffle) then
         begin
           hs:=shuffle^;
           removeshuffles(hs);
           a_loadmm_reg_cgpara(list,cgpara.def,hr,cgpara,@hs);
         end
       else
         a_loadmm_reg_cgpara(list,cgpara.def,hr,cgpara,shuffle);
    end;

  procedure THLCGObj.a_loadmm_loc_cgpara(list: TAsmList; fromsize: TDef; const loc: TLocation; const cgpara: TCGPara; shuffle: PMMShuffle);
    begin
{$ifdef extdebug}
      if def_cgsize(fromsize)<>loc.size then
        InternalError(2012071203);
{$endif}
      case loc.loc of
        LOC_MMREGISTER,LOC_CMMREGISTER:
          a_loadmm_reg_cgpara(list,fromsize,loc.register,cgpara,shuffle);
        LOC_REFERENCE,LOC_CREFERENCE:
          a_loadmm_ref_cgpara(list,fromsize,loc.reference,cgpara,shuffle);
        else
          InternalError(2012071202);
      end;
    end;

  procedure THLCGObj.a_opmm_ref_reg(list: TAsmList; Op: TOpCG; size: TDef; const ref: TReference; reg: TRegister; shuffle: PMMShuffle);
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

  procedure THLCGObj.a_opmm_loc_reg(list: TAsmList; Op: TOpCG; size: TDef; const loc: TLocation; reg: TRegister; shuffle: PMMShuffle);
    begin
      case loc.loc of
        LOC_CMMREGISTER,LOC_MMREGISTER:
          a_opmm_reg_reg(list,op,size,loc.register,reg,shuffle);
        LOC_CREFERENCE,LOC_REFERENCE:
          a_opmm_ref_reg(list,op,size,loc.reference,reg,shuffle);
        else
          InternalError(2012071201);
      end;
    end;

  procedure THLCGObj.a_opmm_reg_ref(list: TAsmList; Op: TOpCG; size: TDef; reg: TRegister; const ref: TReference; shuffle: PMMShuffle);
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

(*
  procedure thlcgobj.a_loadmm_intreg_reg(list: TAsmList; fromsize, tosize: tdef; intreg, mmreg: tregister; shuffle: pmmshuffle);
    begin
      cg.a_loadmm_intreg_reg(list,def_cgsize(fromsize),def_cgsize(tosize),intreg,mmreg,shuffle);
    end;

  procedure thlcgobj.a_loadmm_reg_intreg(list: TAsmList; fromsize, tosize: tdef; mmreg, intreg: tregister; shuffle: pmmshuffle);
    begin
      cg.a_loadmm_reg_intreg(list,def_cgsize(fromsize),def_cgsize(tosize),mmreg,intreg,shuffle);
    end;
*)
  procedure THLCGObj.a_op_const_ref(list: TAsmList; Op: TOpCG; size: TDef; a: TCGInt; const ref: TReference);
    var
      tmpreg : TRegister;
    begin
      tmpreg:=getintregister(list,size);
      a_load_ref_reg(list,size,size,ref,tmpreg);
      a_op_const_reg(list,op,size,a,tmpreg);
      a_load_reg_ref(list,size,size,tmpreg,ref);
    end;

  procedure THLCGObj.a_op_const_subsetreg(list: TAsmList; Op: TOpCG; size, subsetsize: TDef; a: TCGInt; const sreg: TSubsetRegister);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getintregister(list,size);
      a_load_subsetreg_reg(list,subsetsize,size,sreg,tmpreg);
      a_op_const_reg(list,op,size,a,tmpreg);
      a_load_reg_subsetreg(list,size,subsetsize,tmpreg,sreg);
    end;

  procedure THLCGObj.a_op_const_subsetref(list: TAsmList; Op: TOpCG; size, subsetsize: TDef; a: TCGInt; const sref: TSubsetReference);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getintregister(list,size);
      a_load_subsetref_reg(list,subsetsize,size,sref,tmpreg);
      a_op_const_reg(list,op,size,a,tmpreg);
      a_load_reg_subsetref(list,size,subsetsize,tmpreg,sref);
    end;

  procedure THLCGObj.a_op_const_loc(list: TAsmList; Op: TOpCG; size: TDef; a: TCGInt; const loc: TLocation);
    begin
      case loc.loc of
        LOC_REGISTER, LOC_CREGISTER:
          a_op_const_reg(list,op,size,a,loc.register);
        LOC_REFERENCE, LOC_CREFERENCE:
          a_op_const_ref(list,op,size,a,loc.reference);
        LOC_SUBSETREG, LOC_CSUBSETREG:
          a_op_const_subsetreg(list,op,size,size,a,loc.sreg);
        LOC_SUBSETREF, LOC_CSUBSETREF:
          a_op_const_subsetref(list,op,size,size,a,loc.sref);
        else
          InternalError(2010120428);
      end;
    end;

  procedure THLCGObj.a_op_reg_ref(list: TAsmList; Op: TOpCG; size: TDef; reg: TRegister; const ref: TReference);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getintregister(list,size);
      a_load_ref_reg(list,size,size,ref,tmpreg);
      case op of
        OP_NOT,OP_NEG:
          begin
            a_op_reg_reg(list,op,size,tmpreg,tmpreg);
          end;
        else
          begin
            a_op_reg_reg(list,op,size,reg,tmpreg);
          end;
      end;
      a_load_reg_ref(list,size,size,tmpreg,ref);
    end;

  procedure THLCGObj.a_op_ref_reg(list: TAsmList; Op: TOpCG; size: TDef; const ref: TReference; reg: TRegister);
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

  procedure THLCGObj.a_op_reg_subsetreg(list: TAsmList; Op: TOpCG; opsize, destsubsetsize: TDef; reg: TRegister; const sreg: TSubsetRegister);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getintregister(list,opsize);
      a_load_subsetreg_reg(list,destsubsetsize,opsize,sreg,tmpreg);
      a_op_reg_reg(list,op,opsize,reg,tmpreg);
      a_load_reg_subsetreg(list,opsize,destsubsetsize,tmpreg,sreg);
    end;

  procedure THLCGObj.a_op_reg_subsetref(list: TAsmList; Op: TOpCG; opsize, destsubsetsize: TDef; reg: TRegister; const sref: TSubsetReference);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getintregister(list,opsize);
      a_load_subsetref_reg(list,destsubsetsize,opsize,sref,tmpreg);
      a_op_reg_reg(list,op,opsize,reg,tmpreg);
      a_load_reg_subsetref(list,opsize,destsubsetsize,tmpreg,sref);
    end;

  procedure THLCGObj.a_op_reg_loc(list: TAsmList; Op: TOpCG; size: TDef; reg: TRegister; const loc: TLocation);
    begin
      case loc.loc of
        LOC_REGISTER, LOC_CREGISTER:
          a_op_reg_reg(list,op,size,reg,loc.register);
        LOC_REFERENCE, LOC_CREFERENCE:
          a_op_reg_ref(list,op,size,reg,loc.reference);
        LOC_SUBSETREG, LOC_CSUBSETREG:
          a_op_reg_subsetreg(list,op,size,size,reg,loc.sreg);
        LOC_SUBSETREF, LOC_CSUBSETREF:
          a_op_reg_subsetref(list,op,size,size,reg,loc.sref);
        else
          InternalError(2010120429);
      end;
    end;

  procedure THLCGObj.a_op_ref_loc(list: TAsmList; Op: TOpCG; size: TDef; const ref: TReference; const loc: TLocation);
    var
      tmpreg: TRegister;
    begin
      case loc.loc of
        LOC_REGISTER,LOC_CREGISTER:
          a_op_ref_reg(list,op,size,ref,loc.register);
        LOC_REFERENCE,LOC_CREFERENCE:
          begin
            tmpreg:=getintregister(list,size);
            a_load_ref_reg(list,size,size,ref,tmpreg);
            a_op_reg_ref(list,op,size,tmpreg,loc.reference);
          end;
        LOC_SUBSETREG, LOC_CSUBSETREG:
          begin
            tmpreg:=getintregister(list,size);
            a_load_subsetreg_reg(list,size,size,loc.sreg,tmpreg);
            a_op_ref_reg(list,op,size,ref,tmpreg);
            a_load_reg_subsetreg(list,size,size,tmpreg,loc.sreg);
          end;
        LOC_SUBSETREF, LOC_CSUBSETREF:
          begin
            tmpreg:=getintregister(list,size);
            a_load_subsetref_reg(list,size,size,loc.sref,tmpreg);
            a_op_ref_reg(list,op,size,ref,tmpreg);
            a_load_reg_subsetref(list,size,size,tmpreg,loc.sref);
          end;
        else
          InternalError(2010120418);
      end;
    end;

  procedure THLCGObj.a_op_const_reg_reg(list: TAsmList; op: TOpCG; size: TDef; a: TCGInt; src, dst: TRegister);
    begin
      a_load_reg_reg(list,size,size,src,dst);
      a_op_const_reg(list,op,size,a,dst);
    end;

  procedure THLCGObj.a_op_reg_reg_reg(list: TAsmList; op: TOpCG; size: TDef; src1, src2, dst: TRegister);
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

  procedure THLCGObj.a_op_const_reg_reg_checkoverflow(list: TAsmList; op: TOpCG; size: TDef; a: TCGInt; src, dst: TRegister; setflags: boolean; var ovloc: TLocation);
    begin
      ovloc.loc:=LOC_VOID;
      if not setflags then
        a_op_const_reg_reg(list,op,size,a,src,dst)
      else
        InternalError(2010122910);
    end;

  procedure THLCGObj.a_op_reg_reg_reg_checkoverflow(list: TAsmList; op: TOpCG; size: TDef; src1, src2, dst: TRegister; setflags: boolean; var ovloc: TLocation);
    begin
      ovloc.loc:=LOC_VOID;
      if not setflags then
        a_op_reg_reg_reg(list,op,size,src1,src2,dst)
      else
        InternalError(2010122911);
    end;

  procedure THLCGObj.a_op_reg(list: TAsmList; Op: TOpCG; size: TDef; reg: TRegister);
    begin
      if not (Op in [OP_NOT,OP_NEG]) then
        InternalError(2020050711);
      a_op_reg_reg(list,op,size,reg,reg);
    end;

  procedure THLCGObj.a_op_ref(list: TAsmList; Op: TOpCG; size: TDef; const ref: TReference);
    var
      tmpreg: TRegister;
    begin
      if not (Op in [OP_NOT,OP_NEG]) then
        InternalError(2020050712);
      tmpreg:=getintregister(list,size);
      a_load_ref_reg(list,size,size,ref,tmpreg);
      a_op_reg_reg(list,op,size,tmpreg,tmpreg);
      a_load_reg_ref(list,size,size,tmpreg,ref);
    end;

  procedure THLCGObj.a_op_subsetreg(list: TAsmList; Op: TOpCG; destsubsetsize: TDef; const sreg: TSubsetRegister);
    var
      tmpreg: TRegister;
      subsetregdef: TOrdDef;
    begin
      subsetregdef:=cgsize_orddef(sreg.subsetregsize);
      tmpreg:=getintregister(list,subsetregdef);
      a_load_subsetreg_reg(list,destsubsetsize,subsetregdef,sreg,tmpreg);
      a_op_reg(list,op,subsetregdef,tmpreg);
      a_load_reg_subsetreg(list,subsetregdef,destsubsetsize,tmpreg,sreg);
    end;

  procedure THLCGObj.a_op_subsetref(list: TAsmList; Op: TOpCG; destsubsetsize: TDef; const sref: TSubsetReference);
    var
      tmpreg: TRegister;
      subsetregdef: TOrdDef;
    begin
      subsetregdef:=cgsize_orddef(def_cgsize(destsubsetsize));
      tmpreg:=getintregister(list,subsetregdef);
      a_load_subsetref_reg(list,destsubsetsize,subsetregdef,sref,tmpreg);
      a_op_reg(list,op,subsetregdef,tmpreg);
      a_load_reg_subsetref(list,subsetregdef,destsubsetsize,tmpreg,sref);
    end;

  procedure THLCGObj.a_op_loc(list: TAsmList; Op: TOpCG; size: TDef; const loc: TLocation);
    begin
      case loc.loc of
        LOC_REGISTER, LOC_CREGISTER:
          a_op_reg(list,op,size,loc.register);
        LOC_REFERENCE, LOC_CREFERENCE:
          a_op_ref(list,op,size,loc.reference);
        LOC_SUBSETREG, LOC_CSUBSETREG:
          a_op_subsetreg(list,op,size,loc.sreg);
        LOC_SUBSETREF, LOC_CSUBSETREF:
          a_op_subsetref(list,op,size,loc.sref);
        else
          InternalError(2020050703);
      end;
    end;

  procedure THLCGObj.a_cmp_const_reg_label(list: TAsmList; size: TDef; cmp_op: TOpCmp; a: TCGInt; reg: TRegister; l: TAsmLabel);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getregisterfordef(list,size);
      a_load_const_reg(list,size,a,tmpreg);
      a_cmp_reg_reg_label(list,size,cmp_op,tmpreg,reg,l);
    end;

  procedure THLCGObj.a_cmp_const_ref_label(list: TAsmList; size: TDef; cmp_op: TOpCmp; a: TCGInt; const ref: TReference; l: TAsmLabel);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getregisterfordef(list,size);
      a_load_ref_reg(list,size,size,ref,tmpreg);
      a_cmp_const_reg_label(list,size,cmp_op,a,tmpreg,l);
    end;

  procedure THLCGObj.a_cmp_const_loc_label(list: TAsmList; size: TDef; cmp_op: TOpCmp; a: TCGInt; const loc: TLocation; l: TAsmLabel);
    var
      tmpreg: TRegister;
    begin
      case loc.loc of
        LOC_REGISTER,LOC_CREGISTER:
          a_cmp_const_reg_label(list,size,cmp_op,a,loc.register,l);
        LOC_REFERENCE,LOC_CREFERENCE:
          a_cmp_const_ref_label(list,size,cmp_op,a,loc.reference,l);
        LOC_SUBSETREG, LOC_CSUBSETREG:
          begin
            tmpreg:=getintregister(list,size);
            a_load_subsetreg_reg(list,size,size,loc.sreg,tmpreg);
            a_cmp_const_reg_label(list,size,cmp_op,a,tmpreg,l);
          end;
        LOC_SUBSETREF, LOC_CSUBSETREF:
          begin
            tmpreg:=getintregister(list,size);
            a_load_subsetref_reg(list,size,size,loc.sref,tmpreg);
            a_cmp_const_reg_label(list,size,cmp_op,a,tmpreg,l);
          end;
        else
          InternalError(2010120430);
      end;
    end;

  procedure THLCGObj.a_cmp_ref_reg_label(list: TAsmList; size: TDef; cmp_op: TOpCmp; const ref: TReference; reg: TRegister; l: TAsmLabel);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getintregister(list,size);
      a_load_ref_reg(list,size,size,ref,tmpreg);
      a_cmp_reg_reg_label(list,size,cmp_op,tmpreg,reg,l);
    end;

  procedure THLCGObj.a_cmp_reg_ref_label(list: TAsmList; size: TDef; cmp_op: TOpCmp; reg: TRegister; const ref: TReference; l: TAsmLabel);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getintregister(list,size);
      a_load_ref_reg(list,size,size,ref,tmpreg);
      a_cmp_reg_reg_label(list,size,cmp_op,reg,tmpreg,l);
    end;

  procedure THLCGObj.a_cmp_subsetreg_reg_label(list: TAsmList; fromsubsetsize, cmpsize: TDef; cmp_op: TOpCmp; const sreg: TSubsetRegister; reg: TRegister; l: TAsmLabel);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getintregister(list,cmpsize);
      a_load_subsetreg_reg(list,fromsubsetsize,cmpsize,sreg,tmpreg);
      a_cmp_reg_reg_label(list,cmpsize,cmp_op,tmpreg,reg,l);
    end;

  procedure THLCGObj.a_cmp_subsetref_reg_label(list: TAsmList; fromsubsetsize, cmpsize: TDef; cmp_op: TOpCmp; const sref: TSubsetReference; reg: TRegister; l: TAsmLabel);
    var
      tmpreg: TRegister;
    begin
      tmpreg:=getintregister(list,cmpsize);
      a_load_subsetref_reg(list,fromsubsetsize,cmpsize,sref,tmpreg);
      a_cmp_reg_reg_label(list,cmpsize,cmp_op,tmpreg,reg,l);
    end;

  procedure THLCGObj.a_cmp_loc_reg_label(list: TAsmList; size: TDef; cmp_op: TOpCmp; const loc: TLocation; reg: TRegister; l: TAsmLabel);
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
        LOC_SUBSETREG,
        LOC_CSUBSETREG:
          a_cmp_subsetreg_reg_label(list,size,size,cmp_op,loc.sreg,reg,l);
        LOC_SUBSETREF,
        LOC_CSUBSETREF:
          a_cmp_subsetref_reg_label(list,size,size,cmp_op,loc.sref,reg,l);
        else
          InternalError(2010120431);
      end;
    end;

  procedure THLCGObj.a_cmp_reg_loc_label(list: TAsmList; size: TDef; cmp_op: TOpCmp; reg: TRegister; const loc: TLocation; l: TAsmLabel);
    begin
      a_cmp_loc_reg_label(list,size,swap_opcmp(cmp_op),loc,reg,l);
    end;

  procedure THLCGObj.a_cmp_ref_loc_label(list: TAsmList; size: TDef; cmp_op: TOpCmp; const ref: TReference; const loc: TLocation; l: TAsmLabel);
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
        LOC_CONSTANT:
          begin
            a_cmp_const_ref_label(list,size,swap_opcmp(cmp_op),loc.value,ref,l);
          end;
        LOC_SUBSETREG, LOC_CSUBSETREG:
          begin
            tmpreg:=getintregister(list,size);
            a_load_ref_reg(list,size,size,loc.reference,tmpreg);
            a_cmp_subsetreg_reg_label(list,size,size,swap_opcmp(cmp_op),loc.sreg,tmpreg,l);
          end;
        LOC_SUBSETREF, LOC_CSUBSETREF:
          begin
            tmpreg:=getintregister(list,size);
            a_load_ref_reg(list,size,size,loc.reference,tmpreg);
            a_cmp_subsetref_reg_label(list,size,size,swap_opcmp(cmp_op),loc.sref,tmpreg,l);
          end;
        else
          InternalError(2010120432);
      end;
    end;


  procedure THLCGObj.a_jmp_always_pascal_goto(list : TAsmList;l: TAsmLabel);
    begin
      a_jmp_always(list,l);
    end;

  procedure THLCGObj.optimize_op_const(size: TDef; var op: TOpCG; var a: TCGInt);
    var
      powerval : LongInt;
      signext_a, zeroext_a: TCGInt;
      cgsize: TCgSize;
    begin
      cgsize:=def_cgsize(size);
      case cgsize of
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
          case cgsize of
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

  procedure THLCGObj.g_exception_reason_save(list: TAsmList; fromsize, tosize: TDef; reg: TRegister; const href: TReference);
    begin
      a_load_reg_ref(list,fromsize,tosize,reg,href);
    end;

  procedure THLCGObj.g_exception_reason_save_const(list: TAsmList; size: TDef; a: TCGInt; const href: TReference);
    begin
      a_load_const_ref(list,size,a,href);
    end;


  procedure THLCGObj.g_exception_reason_load(list: TAsmList; fromsize, tosize: TDef; const href: TReference; reg: TRegister);
    begin
      a_load_ref_reg(list,fromsize,tosize,href,reg);
    end;


  procedure THLCGObj.g_exception_reason_discard(list: TAsmList; size: TDef; href: TReference);
    begin
      { do nothing by default }
    end;


  procedure THLCGObj.g_maybe_checkforexceptions(list : TAsmList);
    begin
      { do nothing by default }
    end;


  procedure THLCGObj.g_unreachable(list: TAsmList);
    begin
      { nothing }
    end;


  procedure THLCGObj.g_maybe_testself(list: TAsmList; selftype: TDef; reg: TRegister);
    var
      OKLabel : TAsmLabel;
      cgpara1 : TCGPara;
      pd      : TProcDef;
    begin
      if (cs_check_object in CurrentSettings.LocalSwitches) or
         (cs_check_range in CurrentSettings.LocalSwitches) then
       begin
         pd:=search_system_proc('fpc_handleerror');
         CurrentAsmData.getjumplabel(oklabel);
         a_cmp_const_reg_label(list,selftype,OC_NE,0,reg,oklabel);
         cgpara1.init;
         paramanager.getcgtempparaloc(list,pd,1,cgpara1);
         a_load_const_cgpara(list,s32inttype,aint(210),cgpara1);
         paramanager.freecgpara(list,cgpara1);
         g_call_system_proc(list,pd,[@cgpara1],nil).resetiftemp;
         cgpara1.done;
         a_label(list,oklabel);
       end;
    end;

  procedure THLCGObj.g_concatcopy(list: TAsmList; size: TDef; const source, dest: TReference);
    begin
      if use_vectorfpu(size) then
        a_loadmm_ref_ref(list,size,size,source,dest,mms_movescalar)
      else if size.typ<>floatdef then
        a_load_ref_ref(list,size,size,source,dest)
      else
        a_loadfpu_ref_ref(list,size,size,source,dest);
    end;

  procedure THLCGObj.g_concatcopy_unaligned(list: TAsmList; size: TDef; const source, dest: TReference);
    begin
      g_concatcopy(list,size,source,dest);
    end;

  procedure THLCGObj.g_copyshortstring(list: TAsmList; const source, dest: TReference; strdef: TStringDef);
    var
      cgpara1,cgpara2,cgpara3 : TCGPara;
      pd : TProcDef;
    begin
      pd:=search_system_proc('fpc_shortstr_to_shortstr');
      cgpara1.init;
      cgpara2.init;
      cgpara3.init;
      paramanager.getcgtempparaloc(list,pd,1,cgpara1);
      paramanager.getcgtempparaloc(list,pd,2,cgpara2);
      paramanager.getcgtempparaloc(list,pd,3,cgpara3);
      if pd.is_pushleftright then
        begin
          a_loadaddr_ref_cgpara(list,strdef,dest,cgpara1);
          a_load_const_cgpara(list,s32inttype,strdef.len,cgpara2);
          a_loadaddr_ref_cgpara(list,strdef,source,cgpara3);
        end
      else
        begin
          a_loadaddr_ref_cgpara(list,strdef,source,cgpara3);
          a_load_const_cgpara(list,s32inttype,strdef.len,cgpara2);
          a_loadaddr_ref_cgpara(list,strdef,dest,cgpara1);
        end;
      paramanager.freecgpara(list,cgpara3);
      paramanager.freecgpara(list,cgpara2);
      paramanager.freecgpara(list,cgpara1);
      g_call_system_proc(list,pd,[@cgpara1,@cgpara2,@cgpara3],nil).resetiftemp;
      cgpara3.done;
      cgpara2.done;
      cgpara1.done;
    end;

  procedure THLCGObj.g_copyvariant(list: TAsmList; const source, dest: TReference; vardef: TVariantDef);
    var
      cgpara1,cgpara2 : TCGPara;
      pd : TProcDef;
    begin
      pd:=search_system_proc('fpc_variant_copy_overwrite');
      cgpara1.init;
      cgpara2.init;
      paramanager.getcgtempparaloc(list,pd,1,cgpara1);
      paramanager.getcgtempparaloc(list,pd,2,cgpara2);
      if pd.is_pushleftright then
        begin
          a_loadaddr_ref_cgpara(list,vardef,source,cgpara1);
          a_loadaddr_ref_cgpara(list,vardef,dest,cgpara2);
        end
      else
        begin
          a_loadaddr_ref_cgpara(list,vardef,dest,cgpara2);
          a_loadaddr_ref_cgpara(list,vardef,source,cgpara1);
        end;
      paramanager.freecgpara(list,cgpara2);
      paramanager.freecgpara(list,cgpara1);
      g_call_system_proc(list,pd,[@cgpara1,@cgpara2],nil).resetiftemp;
      cgpara2.done;
      cgpara1.done;
    end;

  procedure THLCGObj.g_incrrefcount(list: TAsmList; t: TDef; const ref: TReference);
    var
      href : TReference;
      incrfunc : string;
      cgpara1,cgpara2 : TCGPara;
      pd : TProcDef;
    begin
       cgpara1.init;
       cgpara2.init;
       if is_interfacecom_or_dispinterface(t) then
         incrfunc:='fpc_intf_incr_ref'
       else if is_ansistring(t) then
         incrfunc:='fpc_ansistr_incr_ref'
       else if is_widestring(t) then
         incrfunc:='fpc_widestr_incr_ref'
       else if is_unicodestring(t) then
         incrfunc:='fpc_unicodestr_incr_ref'
       else if is_dynamic_array(t) then
         incrfunc:='fpc_dynarray_incr_ref'
       else
        incrfunc:='';
       { call the special incr function or the generic addref }
       if incrfunc<>'' then
        begin
          pd:=search_system_proc(incrfunc);
          paramanager.getcgtempparaloc(list,pd,1,cgpara1);
          { widestrings aren't ref. counted on all platforms so we need the address
            to create a real copy }
          if is_widestring(t) then
            a_loadaddr_ref_cgpara(list,t,ref,cgpara1)
          else
            { these functions get the pointer by value }
            a_load_ref_cgpara(list,t,ref,cgpara1);
          paramanager.freecgpara(list,cgpara1);
          g_call_system_proc(list,pd,[@cgpara1],nil).resetiftemp;
        end
       else
        begin
          pd:=search_system_proc('fpc_addref');
          paramanager.getcgtempparaloc(list,pd,1,cgpara1);
          paramanager.getcgtempparaloc(list,pd,2,cgpara2);
          if is_open_array(t) then
            InternalError(201103054);
          reference_reset_symbol(href,RTTIWriter.get_rtti_label(t,initrtti,def_needs_indirect(t)),0,sizeof(PInt),[]);
          if pd.is_pushleftright then
            begin
              a_loadaddr_ref_cgpara(list,t,ref,cgpara1);
              a_loadaddr_ref_cgpara(list,voidpointertype,href,cgpara2);
            end
          else
            begin
              a_loadaddr_ref_cgpara(list,voidpointertype,href,cgpara2);
              a_loadaddr_ref_cgpara(list,t,ref,cgpara1);
            end;
          paramanager.freecgpara(list,cgpara1);
          paramanager.freecgpara(list,cgpara2);
          g_call_system_proc(list,pd,[@cgpara1,@cgpara2],nil).resetiftemp;
        end;
       cgpara2.done;
       cgpara1.done;
    end;

  procedure THLCGObj.g_initialize(list: TAsmList; t: TDef; const ref: TReference);
    var
       href : TReference;
       cgpara1,cgpara2 : TCGPara;
       pd : TProcDef;
    begin
       cgpara1.init;
       cgpara2.init;
       if is_ansistring(t) or
          is_widestring(t) or
          is_unicodestring(t) or
          is_interfacecom_or_dispinterface(t) or
          is_dynamic_array(t) then
         a_load_const_ref(list,t,0,ref)
       else if t.typ=variantdef then
         begin
           pd:=search_system_proc('fpc_variant_init');
           paramanager.getcgtempparaloc(list,pd,1,cgpara1);
           a_loadaddr_ref_cgpara(list,t,ref,cgpara1);
           paramanager.freecgpara(list,cgpara1);
          g_call_system_proc(list,pd,[@cgpara1],nil).resetiftemp;
         end
       else
         begin
            if is_open_array(t) then
              InternalError(201103052);
            pd:=search_system_proc('fpc_initialize');
            paramanager.getcgtempparaloc(list,pd,1,cgpara1);
            paramanager.getcgtempparaloc(list,pd,2,cgpara2);
            reference_reset_symbol(href,RTTIWriter.get_rtti_label(t,initrtti,def_needs_indirect(t)),0,sizeof(PInt),[]);
            if pd.is_pushleftright then
              begin
                a_loadaddr_ref_cgpara(list,t,ref,cgpara1);
                a_loadaddr_ref_cgpara(list,voidpointertype,href,cgpara2);
              end
            else
              begin
                a_loadaddr_ref_cgpara(list,voidpointertype,href,cgpara2);
                a_loadaddr_ref_cgpara(list,t,ref,cgpara1);
              end;
            paramanager.freecgpara(list,cgpara1);
            paramanager.freecgpara(list,cgpara2);
            g_call_system_proc(list,pd,[@cgpara1,@cgpara2],nil).resetiftemp;
         end;
       cgpara1.done;
       cgpara2.done;
    end;

  procedure THLCGObj.g_finalize(list: TAsmList; t: TDef; const ref: TReference);
    var
       href : TReference;
       cgpara1,cgpara2 : TCGPara;
       pd : TProcDef;
       decrfunc : string;
    begin
      if is_interfacecom_or_dispinterface(t) then
        decrfunc:='fpc_intf_decr_ref'
      else if is_ansistring(t) then
        decrfunc:='fpc_ansistr_decr_ref'
      else if is_widestring(t) then
        decrfunc:='fpc_widestr_decr_ref'
      else if is_unicodestring(t) then
        decrfunc:='fpc_unicodestr_decr_ref'
      else if t.typ=variantdef then
        decrfunc:='fpc_variant_clear'
      else
        begin
          cgpara1.init;
          cgpara2.init;
          if is_open_array(t) then
            InternalError(201103051);
          { fpc_finalize takes a pointer value parameter, fpc_dynarray_clear a
            pointer var parameter }
          if is_dynamic_array(t) then
            pd:=search_system_proc('fpc_dynarray_clear')
          else
            pd:=search_system_proc('fpc_finalize');
          paramanager.getcgtempparaloc(list,pd,1,cgpara1);
          paramanager.getcgtempparaloc(list,pd,2,cgpara2);
          reference_reset_symbol(href,RTTIWriter.get_rtti_label(t,initrtti,def_needs_indirect(t)),0,sizeof(PInt),[]);
          if pd.is_pushleftright then
            begin
              a_loadaddr_ref_cgpara(list,t,ref,cgpara1);
              a_loadaddr_ref_cgpara(list,voidpointertype,href,cgpara2);
            end
          else
            begin
              a_loadaddr_ref_cgpara(list,voidpointertype,href,cgpara2);
              a_loadaddr_ref_cgpara(list,t,ref,cgpara1);
            end;
          paramanager.freecgpara(list,cgpara1);
          paramanager.freecgpara(list,cgpara2);
          g_call_system_proc(list,pd,[@cgpara1,@cgpara2],nil).resetiftemp;
          cgpara1.done;
          cgpara2.done;
          exit;
        end;
      pd:=search_system_proc(decrfunc);
      cgpara1.init;
      paramanager.getcgtempparaloc(list,pd,1,cgpara1);
      a_loadaddr_ref_cgpara(list,t,ref,cgpara1);
      paramanager.freecgpara(list,cgpara1);
      g_call_system_proc(list,pd,[@cgpara1],nil).resetiftemp;
      cgpara1.done;
    end;

  procedure THLCGObj.g_array_rtti_helper(list: TAsmList; t: TDef; const ref: TReference; const highloc: TLocation; const name: string);
    var
      cgpara1,cgpara2,cgpara3: TCGPara;
      href: TReference;
      hreg, lenreg: TRegister;
      pd: TProcDef;
    begin
      cgpara1.init;
      cgpara2.init;
      cgpara3.init;
      pd:=search_system_proc(name);
      paramanager.getcgtempparaloc(list,pd,1,cgpara1);
      paramanager.getcgtempparaloc(list,pd,2,cgpara2);
      paramanager.getcgtempparaloc(list,pd,3,cgpara3);

      reference_reset_symbol(href,RTTIWriter.get_rtti_label(t,initrtti,def_needs_indirect(t)),0,sizeof(PInt),[]);
      { if calling convention is left to right, push parameters 1 and 2 }
      if pd.is_pushleftright then
        begin
          a_loadaddr_ref_cgpara(list,t,ref,cgpara1);
          a_loadaddr_ref_cgpara(list,voidpointertype,href,cgpara2);
        end;

      { push parameter 3 }
      if highloc.loc=LOC_CONSTANT then
        a_load_const_cgpara(list,sizesinttype,highloc.value+1,cgpara3)
      else
        begin
          if highloc.loc in [LOC_REGISTER,LOC_CREGISTER] then
            hreg:=highloc.register
          else
            begin
              hreg:=getintregister(list,sizesinttype);
              a_load_loc_reg(list,sizesinttype,sizesinttype,highloc,hreg);
            end;
          { increment, converts high(x) to length(x) }
          lenreg:=getintregister(list,sizesinttype);
          a_op_const_reg_reg(list,OP_ADD,sizesinttype,1,hreg,lenreg);
          a_load_reg_cgpara(list,sizesinttype,lenreg,cgpara3);
        end;

      { if calling convention is right to left, push parameters 2 and 1 }
      if not pd.is_pushleftright then
        begin
          a_loadaddr_ref_cgpara(list,voidpointertype,href,cgpara2);
          a_loadaddr_ref_cgpara(list,t,ref,cgpara1);
        end;
      paramanager.freecgpara(list,cgpara1);
      paramanager.freecgpara(list,cgpara2);
      paramanager.freecgpara(list,cgpara3);
      g_call_system_proc(list,pd,[@cgpara1,@cgpara2,@cgpara3],nil).resetiftemp;

      cgpara3.done;
      cgpara2.done;
      cgpara1.done;
    end;

  function THLCGObj.def_needs_indirect(t:TDef):boolean;
    begin
      result:=(tf_supports_packages in TargetInfo.flags) and
                (TargetInfo.system in systems_indirect_var_imports) and
                (findunitsymtable(t.owner).ModuleID<>CurrentModule.ModuleID);
    end;

  procedure THLCGObj.g_rangecheck(list: TAsmList; const l: TLocation; fromdef, todef: TDef);
    var
{$if defined(cpuhighleveltarget)}
      aintmax: TCGInt;
{$elseif defined(cpu64bitalu) or defined(cpu32bitalu)}
      aintmax: aint;
{$else}
      aintmax: LongInt;
{$endif}
      neglabel : TAsmLabel;
      hreg : TRegister;
      lto,hto,
      lfrom,hfrom : TConstExprInt;
      fromsize, tosize: cardinal;
      maxdef: TDef;
      from_signed, to_signed: boolean;
    begin
      { range checking on and range checkable value? }
      if not(cs_check_range in CurrentSettings.LocalSwitches) or
         not(fromdef.typ in [orddef,enumdef]) or
         { C-style booleans can't really fail range checks, }
         { all values are always valid                      }
         is_cbool(todef) then
        exit;
{$if not defined(cpuhighleveltarget) and not defined(cpu64bitalu)}
        { handle 64bit rangechecks separate for 32bit processors }
        if is_64bit(fromdef) or is_64bit(todef) then
          begin
             cg64.g_rangecheck64(list,l,fromdef,todef);
             exit;
          end;
{$endif ndef cpuhighleveltarget and ndef cpu64bitalu}
      { only check when assigning to scalar, subranges are different, }
      { when todef=fromdef then the check is always generated         }
      getrange(fromdef,lfrom,hfrom);
      getrange(todef,lto,hto);
      from_signed := is_signed(fromdef);
      to_signed := is_signed(todef);
      { check the rangedef of the array, not the array itself }
      { (only change now, since getrange needs the arraydef)   }
      if (todef.typ = arraydef) then
        todef := TArrayDef(todef).rangedef;
      { no range check if from and to are equal and are both longint/dword }
      { (if we have a 32bit processor) or int64/qword, since such          }
      { operations can at most cause overflows (JM)                        }
      { Note that these checks are mostly processor independent, they only }
      { have to be changed once we introduce 64bit subrange types          }
{$if defined(cpuhighleveltarget) or defined(cpu64bitalu)}
      if (fromdef=todef) and
         (fromdef.typ=orddef) and
         (((((TOrdDef(fromdef).ordtype=s64bit) and
             (lfrom = low(int64)) and
             (hfrom = high(int64))) or
            ((TOrdDef(fromdef).ordtype=u64bit) and
             (lfrom = low(qword)) and
             (hfrom = high(qword))) or
            ((TOrdDef(fromdef).ordtype=scurrency) and
             (lfrom = low(int64)) and
             (hfrom = high(int64)))))) then
        exit;
{$endif cpuhighleveltarget or cpu64bitalu}
      { 32 bit operations are automatically widened to 64 bit on 64 bit addr
        targets }
{$ifdef cpu32bitaddr}
      if (fromdef = todef) and
         (fromdef.typ=orddef) and
         (((((TOrdDef(fromdef).ordtype = s32bit) and
             (lfrom = int64(low(LongInt))) and
             (hfrom = int64(high(LongInt)))) or
            ((TOrdDef(fromdef).ordtype = u32bit) and
             (lfrom = low(cardinal)) and
             (hfrom = high(cardinal)))))) then
        exit;
{$endif cpu32bitaddr}

      { optimize some range checks away in safe cases }
      fromsize := fromdef.size;
      tosize := todef.size;
      if ((from_signed = to_signed) or
          (not from_signed)) and
         (lto<=lfrom) and (hto>=hfrom) and
         (fromsize <= tosize) then
        begin
          { if fromsize < tosize, and both have the same signed-ness or }
          { fromdef is unsigned, then all bit patterns from fromdef are }
          { valid for todef as well                                     }
          if (fromsize < tosize) then
            exit;
          if (fromsize = tosize) and
             (from_signed = to_signed) then
            { only optimize away if all bit patterns which fit in fromsize }
            { are valid for the todef                                      }
            begin
{$ifopt Q+}
{$define overflowon}
{$Q-}
{$endif}
{$ifopt R+}
{$define rangeon}
{$R-}
{$endif}
              if to_signed then
                begin
                  { calculation of the low/high ranges must not overflow 64 bit
                   otherwise we end up comparing with zero for 64 bit data types on
                   64 bit processors }
                  if (lto = (int64(-1) << (tosize * 8 - 1))) and
                     (hto = (-((int64(-1) << (tosize * 8 - 1))+1))) then
                    exit
                end
              else
                begin
                  { calculation of the low/high ranges must not overflow 64 bit
                   otherwise we end up having all zeros for 64 bit data types on
                   64 bit processors }
                  if (lto = 0) and
                     (qword(hto) = (qword(-1) >> (64-(tosize * 8))) ) then
                    exit
                end;
{$ifdef overflowon}
{$Q+}
{$undef overflowon}
{$endif}
{$ifdef rangeon}
{$R+}
{$undef rangeon}
{$endif}
            end
        end;

      { depending on the types involved, we perform the range check for 64 or
        for 32 bit }
      if fromsize=8 then
        maxdef:=fromdef
      else
        maxdef:=todef;
{$if defined(cpuhighleveltarget) or defined(cpu64bitalu)}
      if maxdef.size=8 then
        aintmax:=high(int64)
      else
{$endif}
        begin
          aintmax:=high(LongInt);
          maxdef:=u32inttype;
        end;

      { generate the rangecheck code for the def where we are going to }
      { store the result                                               }

      { use the trick that                                                 }
      { a <= x <= b <=> 0 <= x-a <= b-a <=> unsigned(x-a) <= unsigned(b-a) }

      { To be able to do that, we have to make sure however that either    }
      { fromdef and todef are both signed or unsigned, or that we leave    }
      { the parts < 0 and > maxlongint out                                 }

      if from_signed xor to_signed then
        begin
           if from_signed then
             { from is signed, to is unsigned }
             begin
               { if high(from) < 0 -> always range error }
               if (hfrom < 0) or
                  { if low(to) > maxlongint also range error }
                  (lto > aintmax) then
                 begin
                   g_call_system_proc(list,'fpc_rangeerror',[],nil).resetiftemp;
                   exit
                 end;
               { from is signed and to is unsigned -> when looking at to }
               { as an signed value, it must be < maxaint (otherwise     }
               { it will become negative, which is invalid since "to" is unsigned) }
               if hto > aintmax then
                 hto := aintmax;
             end
           else
             { from is unsigned, to is signed }
             begin
               if (lfrom > aintmax) or
                  (hto < 0) then
                 begin
                   g_call_system_proc(list,'fpc_rangeerror',[],nil).resetiftemp;
                   exit
                 end;
               { from is unsigned and to is signed -> when looking at to }
               { as an unsigned value, it must be >= 0 (since negative   }
               { values are the same as values > maxlongint)             }
               if lto < 0 then
                 lto := 0;
             end;
        end;
      hreg:=getintregister(list,maxdef);
      a_load_loc_reg(list,fromdef,maxdef,l,hreg);
      a_op_const_reg(list,OP_SUB,maxdef,TCGInt(int64(lto)),hreg);
      CurrentAsmData.getjumplabel(neglabel);
      {
      if from_signed then
        a_cmp_const_reg_label(list,OS_INT,OC_GTE,aint(hto-lto),hreg,neglabel)
      else
      }
      cg.a_reg_alloc(list, NR_DEFAULTFLAGS);
      if qword(hto-lto)>qword(aintmax) then
        a_cmp_const_reg_label(list,maxdef,OC_BE,aintmax,hreg,neglabel)
      else
        a_cmp_const_reg_label(list,maxdef,OC_BE,TCGInt(int64(hto-lto)),hreg,neglabel);
      cg.a_reg_dealloc(list, NR_DEFAULTFLAGS);
      g_call_system_proc(list,'fpc_rangeerror',[],nil).resetiftemp;
      a_label(list,neglabel);
    end;

  procedure THLCGObj.g_copyvaluepara_openarray(list: TAsmList; const ref: TReference; const lenloc: TLocation; arrdef: TArrayDef; destreg: TRegister);
    var
      sizereg,sourcereg,lenreg : TRegister;
      cgpara1,cgpara2,cgpara3 : TCGPara;
      ptrarrdef : TDef;
      pd : TProcDef;
      getmemres : TCGPara;
      destloc : TLocation;
    begin
      { because some abis don't support dynamic stack allocation properly
        open array value parameters are copied onto the heap
      }
      include(CurrentProcInfo.flags, pi_has_open_array_parameter);

      { calculate necessary memory }

      { read/write operations on one register make the life of the register allocator hard }
      if not(lenloc.loc in [LOC_REGISTER,LOC_CREGISTER]) then
        begin
          lenreg:=getintregister(list,sinttype);
          a_load_loc_reg(list,sinttype,sinttype,lenloc,lenreg);
        end
      else
        lenreg:=lenloc.register;

      sizereg:=getintregister(list,sinttype);
      a_op_const_reg_reg(list,OP_ADD,sinttype,1,lenreg,sizereg);
      a_op_const_reg(list,OP_IMUL,sinttype,arrdef.elesize,sizereg);
      { load source }
      ptrarrdef:=CPointerDef.getreusable(arrdef);
      sourcereg:=getaddressregister(list,ptrarrdef);
      a_loadaddr_ref_reg(list,arrdef,ptrarrdef,ref,sourcereg);

      { do getmem call }
      pd:=search_system_proc('fpc_getmem');
      cgpara1.init;
      paramanager.getcgtempparaloc(list,pd,1,cgpara1);
      a_load_reg_cgpara(list,sinttype,sizereg,cgpara1);
      paramanager.freecgpara(list,cgpara1);
      getmemres:=g_call_system_proc(list,pd,[@cgpara1],ptrarrdef);
      cgpara1.done;
      { return the new address }
      location_reset(destloc,LOC_REGISTER,OS_ADDR);
      destloc.register:=destreg;
      gen_load_cgpara_loc(list,ptrarrdef,getmemres,destloc,false);

      { do move call }
      pd:=search_system_proc('MOVE');
      cgpara1.init;
      cgpara2.init;
      cgpara3.init;
      paramanager.getcgtempparaloc(list,pd,1,cgpara1);
      paramanager.getcgtempparaloc(list,pd,2,cgpara2);
      paramanager.getcgtempparaloc(list,pd,3,cgpara3);
      if pd.is_pushleftright then
        begin
          { load source }
          a_load_reg_cgpara(list,ptrarrdef,sourcereg,cgpara1);
          { load destination }
          a_load_reg_cgpara(list,ptrarrdef,destreg,cgpara2);
          { load size }
          a_load_reg_cgpara(list,sizesinttype,sizereg,cgpara3);
        end
      else
        begin
          { load size }
          a_load_reg_cgpara(list,sizesinttype,sizereg,cgpara3);
          { load destination }
          a_load_reg_cgpara(list,ptrarrdef,destreg,cgpara2);
          { load source }
          a_load_reg_cgpara(list,ptrarrdef,sourcereg,cgpara1);
        end;
      paramanager.freecgpara(list,cgpara3);
      paramanager.freecgpara(list,cgpara2);
      paramanager.freecgpara(list,cgpara1);
      g_call_system_proc(list,pd,[@cgpara1,@cgpara2,@cgpara3],nil).resetiftemp;
      cgpara3.done;
      cgpara2.done;
      cgpara1.done;
      getmemres.resetiftemp;
    end;

  procedure THLCGObj.g_releasevaluepara_openarray(list: TAsmList; arrdef: TArrayDef; const l: TLocation);
    var
      cgpara1 : TCGPara;
      pd : TProcDef;
    begin
      { do freemem call }
      pd:=search_system_proc('fpc_freemem');
      cgpara1.init;
      paramanager.getcgtempparaloc(list,pd,1,cgpara1);
      { load source }
      a_load_loc_cgpara(list,CPointerDef.getreusable(arrdef),l,cgpara1);
      paramanager.freecgpara(list,cgpara1);
      g_call_system_proc(list,pd,[@cgpara1],nil).resetiftemp;
      cgpara1.done;
    end;

  procedure THLCGObj.a_jmp_external_name(list: TAsmList; const externalname: TSymStr);
    begin
      cg.a_jmp_name(list,externalname);
    end;

  procedure THLCGObj.g_external_wrapper(list: TAsmList; procdef: TProcDef; const wrappername, externalname: string; global: boolean);
    var
      sym: TAsmSymbol;
    begin
      maybe_new_object_file(list);
      new_section(list,sec_code,wrappername,TargetInfo.alignment.ProcAlign);
      if global then
        begin
          sym:=CurrentAsmData.DefineAsmSymbol(wrappername,AB_GLOBAL,AT_FUNCTION,procdef);
          list.concat(TAISymbol.Create_global(sym,0));
        end
      else
        begin
          sym:=CurrentAsmData.DefineAsmSymbol(wrappername,AB_PRIVATE_EXTERN,AT_FUNCTION,procdef);
          list.concat(TAISymbol.Create(sym,0));
        end;
      a_jmp_external_name(list,externalname);
      list.concat(TAISymbolEnd.Create(sym));
    end;

  procedure THLCGObj.g_allocload_reg_reg(list: TAsmList; regsize: TDef; const fromreg: TRegister; out toreg: TRegister; regtyp: TRegisterType);
    begin
      case regtyp of
        R_INTREGISTER:
          toreg:=getintregister(list,regsize);
        R_ADDRESSREGISTER:
          toreg:=getaddressregister(list,regsize);
        R_FPUREGISTER:
          toreg:=getfpuregister(list,regsize);
        else
          InternalError(2013112910);
      end;
      a_load_reg_reg(list,regsize,regsize,fromreg,toreg);
    end;

  procedure THLCGObj.g_reference_loc(list: TAsmList; def: TDef; const fromloc: TLocation; out toloc: TLocation);

    procedure handle_reg_move(regsize: TDef; const fromreg: TRegister; out toreg: TRegister; regtyp: TRegisterType);
      begin
        case regtyp of
          R_INTREGISTER:
            toreg:=getintregister(list,regsize);
          R_ADDRESSREGISTER:
            toreg:=getaddressregister(list,regsize);
          R_FPUREGISTER:
            toreg:=getfpuregister(list,regsize);
        else
          InternalError(2013112915);
        end;
        a_load_reg_reg(list,regsize,regsize,fromreg,toreg);
      end;

    begin
      toloc:=fromloc;
      case fromloc.loc of
        { volatile location, can't get a permanent reference }
        LOC_REGISTER,
        LOC_FPUREGISTER:
          InternalError(2012012702);
        LOC_CONSTANT:
          { finished }
          ;
        LOC_CREGISTER:
          handle_reg_move(def,fromloc.reference.index,toloc.reference.index,R_INTREGISTER);
        LOC_CFPUREGISTER:
          handle_reg_move(def,fromloc.reference.index,toloc.reference.index,R_FPUREGISTER);
        { although LOC_CREFERENCE cannot be an lvalue, we may want to take a
          reference to such a location for multiple reading }
        LOC_CREFERENCE,
        LOC_REFERENCE:
          begin
            if (fromloc.reference.base<>NR_NO) and
               (fromloc.reference.base<>CurrentProcInfo.framepointer) and
               (fromloc.reference.base<>NR_STACK_POINTER_REG) then
              handle_reg_move(voidpointertype,fromloc.reference.base,toloc.reference.base,getregtype(fromloc.reference.base));
            if (fromloc.reference.index<>NR_NO) and
               (fromloc.reference.index<>CurrentProcInfo.framepointer) and
               (fromloc.reference.index<>NR_STACK_POINTER_REG) then
              handle_reg_move(voidpointertype,fromloc.reference.index,toloc.reference.index,getregtype(fromloc.reference.index));
          end;
        else
          InternalError(2012012701);
      end;
    end;

  procedure THLCGObj.g_ptrtypecast_reg(list: TAsmList; fromdef, todef: TDef; var reg: TRegister);
    begin
      { nothing to do }
    end;

  procedure THLCGObj.g_ptrtypecast_ref(list: TAsmList; fromdef, todef: TDef; var ref: TReference);
    begin
      { nothing to do }
    end;

  procedure THLCGObj.g_set_addr_nonbitpacked_field_ref(list: TAsmList; recdef: TAbstractRecordDef; field: TFieldVarSym; var recref: TReference);
    begin
      inc(recref.offset,field.fieldoffset);
      recref.alignment:=NewAlignment(recref.alignment,field.fieldoffset);
    end;


  procedure THLCGObj.g_undefined_ok(list: TAsmList; size: TDef; reg: TRegister);
    begin
      { nothing by default }
    end;


  procedure THLCGObj.g_setup_load_field_by_name(list: TAsmList; recdef: TRecordDef; const name: TIDString; const recref: TReference; out fref: TReference; out fielddef: TDef);
    var
      sym: TSym;
      field: TFieldVarSym;
    begin
      sym:=search_struct_member(recdef,name);
      if not Assigned(sym) or
         (sym.typ<>fieldvarsym) then
        InternalError(2015111901);
      field:=TFieldVarSym(sym);
      fref:=recref;
      fielddef:=field.vardef;
      g_set_addr_nonbitpacked_field_ref(list,recdef,field,fref);
    end;


  procedure THLCGObj.g_load_reg_field_by_name(list: TAsmList; regsize: TDef; recdef: TRecordDef; reg: TRegister; const name: TIDString; const recref: TReference);
    var
      fref: TReference;
      fielddef: TDef;
    begin
      g_setup_load_field_by_name(list,recdef,name,recref,fref,fielddef);
      a_load_reg_ref(list,regsize,fielddef,reg,fref);
    end;


  procedure THLCGObj.g_load_const_field_by_name(list: TAsmList; recdef: TRecordDef; a: TCGInt; const name: TIDString; const recref: TReference);
    var
      fref: TReference;
      fielddef: TDef;
    begin
      g_setup_load_field_by_name(list,recdef,name,recref,fref,fielddef);
      a_load_const_ref(list,fielddef,a,fref);
    end;


  procedure THLCGObj.g_load_field_reg_by_name(list: TAsmList; recdef: TRecordDef; regsize: TDef; const name: TIDString; const recref: TReference; reg: TRegister);
    var
      fref: TReference;
      fielddef: TDef;
    begin
      g_setup_load_field_by_name(list,recdef,name,recref,fref,fielddef);
      a_load_ref_reg(list,fielddef,regsize,fref,reg);
    end;


  procedure THLCGObj.g_force_field_reg_by_name(list: TAsmList; recdef: TRecordDef; const name: TIDString; const recref: TReference; out regdef: TDef; out reg: TRegister);
    var
      fref: TReference;
    begin
      g_setup_load_field_by_name(list,recdef,name,recref,fref,regdef);
      reg:=getregisterfordef(list,regdef);
      a_load_ref_reg(list,regdef,regdef,fref,reg);
    end;


  procedure THLCGObj.location_force_reg(list: TAsmList; var l: TLocation; src_size, dst_size: TDef; maybeconst: boolean);
    var
      hregister,
      hregister2: TRegister;
      hl : TAsmLabel;
      oldloc : TLocation;
    begin
      oldloc:=l;
      hregister:=getregisterfordef(list,dst_size);
      { load value in new register }
      case l.loc of
{$ifdef cpuflags}
        LOC_FLAGS :
          begin
            g_flags2reg(list,dst_size,l.resflags,hregister);
            cg.a_reg_dealloc(list,NR_DEFAULTFLAGS);
          end;
{$endif cpuflags}
        LOC_JUMP :
          begin
            a_label(list,l.truelabel);
            if is_cbool(src_size) then
              a_load_const_reg(list,dst_size,-1,hregister)
            else
              a_load_const_reg(list,dst_size,1,hregister);
            CurrentAsmData.getjumplabel(hl);
            a_jmp_always(list,hl);
            a_label(list,l.falselabel);
            a_load_const_reg(list,dst_size,0,hregister);
            a_label(list,hl);
          end;
        else
          begin
            { load_loc_reg can only handle size >= l.size, when the
              new size is smaller then we need to adjust the size
              of the original and maybe recalculate l.register for i386 }
            if (dst_size.size<src_size.size) then
              begin
                hregister2:=getregisterfordef(list,src_size);
                { prevent problems with memory locations -- at this high
                  level we cannot twiddle with the reference offset, since
                  that may not mean anything (e.g., it refers to fixed-sized
                  stack slots on Java) }
                a_load_loc_reg(list,src_size,src_size,l,hregister2);
                a_load_reg_reg(list,src_size,dst_size,hregister2,hregister);
              end
            else
              a_load_loc_reg(list,src_size,dst_size,l,hregister);
          end;
      end;
      if (l.loc <> LOC_CREGISTER) or
         not maybeconst then
        location_reset(l,LOC_REGISTER,def_cgsize(dst_size))
      else
        location_reset(l,LOC_CREGISTER,def_cgsize(dst_size));
      l.register:=hregister;
      { Release temp if it was a reference }
      if oldloc.loc=LOC_REFERENCE then
        location_freetemp(list,oldloc);
    end;

  procedure THLCGObj.location_force_fpureg(list: TAsmList; var l: TLocation; size: TDef; maybeconst: boolean);
    var
      reg : TRegister;
    begin
      if (l.loc<>LOC_FPUREGISTER)  and
         ((l.loc<>LOC_CFPUREGISTER) or (not maybeconst)) then
        begin
          { if it's in an mm register, store to memory first }
          if (l.loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
            location_force_mem(list,l,size);
          reg:=getfpuregister(list,size);
          a_loadfpu_loc_reg(list,size,size,l,reg);
          location_freetemp(list,l);
          location_reset(l,LOC_FPUREGISTER,l.size);
          l.register:=reg;
        end;
    end;

  procedure THLCGObj.location_force_mem(list: TAsmList; var l: TLocation; size: TDef);
    var
      r : TReference;
      forcesize: aint;
      hregister: TRegister;
      hl: TAsmLabel;
    begin
      case l.loc of
        LOC_FPUREGISTER,
        LOC_CFPUREGISTER :
          begin
            tg.gethltemp(list,size,size.size,tt_normal,r);
            a_loadfpu_reg_ref(list,size,size,l.register,r);
            location_reset_ref(l,LOC_REFERENCE,l.size,size.alignment,[]);
            l.reference:=r;
          end;
        LOC_MMREGISTER,
        LOC_CMMREGISTER:
          begin
            { vectors can't be represented yet using tdef }
            if size.typ<>floatdef then
              InternalError(2012062302);
            tg.gethltemp(list,size,size.size,tt_normal,r);
            a_loadmm_reg_ref(list,size,size,l.register,r,mms_movescalar);
            location_reset_ref(l,LOC_REFERENCE,l.size,size.alignment,[]);
            l.reference:=r;
          end;
{$ifdef cpuflags}
        LOC_FLAGS :
          begin
            hregister:=getregisterfordef(list,size);
            g_flags2reg(list,size,l.resflags,hregister);
            cg.a_reg_dealloc(list,NR_DEFAULTFLAGS);
            tg.gethltemp(list,size,size.size,tt_normal,r);
            a_load_reg_ref(list,size,size,hregister,r);
            location_reset_ref(l,LOC_REFERENCE,l.size,size.alignment,[]);
            l.reference:=r;
          end;
{$endif cpuflags}
        LOC_JUMP :
          begin
            a_label(list,l.truelabel);
            tg.gethltemp(list,size,size.size,tt_normal,r);
            if is_cbool(size) then
              a_load_const_ref(list,size,-1,r)
            else
              a_load_const_ref(list,size,1,r);
            CurrentAsmData.getjumplabel(hl);
            a_jmp_always(list,hl);
            a_label(list,l.falselabel);
            a_load_const_ref(list,size,0,r);
            a_label(list,hl);

            location_reset_ref(l,LOC_REFERENCE,l.size,size.alignment,[]);
            l.reference:=r;
          end;
        LOC_CONSTANT,
        LOC_REGISTER,
        LOC_CREGISTER,
        LOC_SUBSETREG,
        LOC_CSUBSETREG,
        LOC_SUBSETREF,
        LOC_CSUBSETREF:
          begin
            if not is_dynamic_array(size) and
               not is_open_array(size) then
              forcesize:=size.size
            else
              forcesize:=sizeof(PInt);
            tg.gethltemp(list,size,forcesize,tt_normal,r);
            a_load_loc_ref(list,size,size,l,r);
            location_reset_ref(l,LOC_REFERENCE,l.size,size.alignment,[]);
            l.reference:=r;
          end;
        LOC_CREFERENCE,
        LOC_REFERENCE : ;
        else
          InternalError(2011010304);
      end;
    end;

  procedure THLCGObj.location_force_mmregscalar(list: TAsmList; var l: TLocation; var size: TDef; maybeconst: boolean);
    var
      reg : TRegister;
      href : TReference;
      newsize : TDef;
    begin
      if (l.loc<>LOC_MMREGISTER)  and
         ((l.loc<>LOC_CMMREGISTER) or (not maybeconst)) then
        begin
          { if it's in an fpu register, store to memory first }
          if (l.loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
            begin
              tg.gethltemp(list,size,-1,tt_normal,href);
              hlcg.a_loadfpu_reg_ref(list,size,size,l.register,href);
              location_reset_ref(l,LOC_REFERENCE,l.size,size.alignment,[]);
              l.reference:=href;
            end;
          { on ARM, CFP values may be located in integer registers,
            and its second_int_to_real() also uses this routine to
            force integer (memory) values in an mmregister }
          if (l.size in [OS_32,OS_S32]) then
            begin
              size:=cgsize_orddef(l.size);
              newsize:=s32floattype;
            end
          else if (l.size in [OS_64,OS_S64]) then
            begin
              size:=cgsize_orddef(l.size);
              newsize:=s64floattype;
            end
          else
            newsize:=size;
          case size.size of
            4:
              newsize:=s32floattype;
            8:
              newsize:=s64floattype;
            else
              newsize:=size;
          end;
          reg:=hlcg.getmmregister(list,newsize);
          hlcg.a_loadmm_loc_reg(list,size,newsize,l,reg,mms_movescalar);
          l.size:=def_cgsize(newsize);
          location_freetemp(list,l);
          location_reset(l,LOC_MMREGISTER,l.size);
          size:=newsize;
          l.register:=reg;
        end;
    end;

    procedure THLCGObj.location_get_data_ref(list: TAsmList; def: TDef; const l: TLocation; var ref: TReference; loadref: boolean; alignment: LongInt);
      var
        pdef: TDef;
      begin
        case l.loc of
          LOC_REGISTER,
          LOC_CREGISTER :
            begin
              if not loadref then
                InternalError(200410231);
              reference_reset_base(ref,CPointerDef.getreusable(def),l.register,0,ctempposinvalid,alignment,[]);
            end;
          LOC_REFERENCE,
          LOC_CREFERENCE :
            begin
              if loadref then
                begin
                  pdef:=CPointerDef.getreusable(def);
                  reference_reset_base(ref,pdef,getaddressregister(list,voidpointertype),0,ctempposinvalid,alignment,[]);
                  { it's a pointer to def }
                  a_load_ref_reg(list,pdef,pdef,l.reference,ref.base);
                end
              else
                ref:=l.reference;
            end;
          else
            InternalError(200309181);
        end;
      end;


  procedure THLCGObj.maketojumpbool(list: TAsmList; p: TNode);
    var
      truelabel,
      falselabel: TAsmLabel;
    begin
       if p.location.loc<>LOC_JUMP then
         begin
           CurrentAsmData.getjumplabel(truelabel);
           CurrentAsmData.getjumplabel(falselabel);
         end
       else
         begin
           truelabel:=p.location.truelabel;
           falselabel:=p.location.falselabel;
         end;
       maketojumpboollabels(list,p,truelabel,falselabel);
    end;


  procedure THLCGObj.maketojumpboollabels(list: TAsmList; p: TNode; truelabel, falselabel: TAsmLabel);
    var
      storepos : TFilePosInfo;
    begin
       if tnf_error in p.transientflags then
         exit;
       storepos:=CurrentFilePos;
       CurrentFilePos:=p.fileinfo;
       if is_boolean(p.resultdef) then
         begin
            if is_constboolnode(p) then
              begin
                 if TOrdConstNode(p).value.uvalue<>0 then
                   a_jmp_always(list,truelabel)
                 else
                   a_jmp_always(list,falselabel)
              end
            else
              begin
                 case p.location.loc of
                   LOC_SUBSETREG,LOC_CSUBSETREG,
                   LOC_SUBSETREF,LOC_CSUBSETREF,
                   LOC_CREGISTER,LOC_REGISTER,LOC_CREFERENCE,LOC_REFERENCE :
                     begin
                       a_cmp_const_loc_label(list,p.resultdef,OC_NE,0,p.location,truelabel);
{$ifdef x86} { x86 always uses the flags in some way for conditional jumps }
                       a_reg_dealloc(list,NR_DEFAULTFLAGS);
{$endif x86}
                       a_jmp_always(list,falselabel);
                     end;
                   LOC_JUMP:
                     begin
                       if truelabel<>p.location.truelabel then
                         begin
                           a_label(list,p.location.truelabel);
                           a_jmp_always(list,truelabel);
                         end;
                       if falselabel<>p.location.falselabel then
                         begin
                           a_label(list,p.location.falselabel);
                           a_jmp_always(list,falselabel);
                         end;
                     end;
{$ifdef cpuflags}
                   LOC_FLAGS :
                     begin
                       a_jmp_flags(list,p.location.resflags,truelabel);
                       a_reg_dealloc(list,NR_DEFAULTFLAGS);
                       a_jmp_always(list,falselabel);
                     end;
{$endif cpuflags}
                   else
                     InternalError(2011010418);
                 end;
              end;
            location_reset_jump(p.location,truelabel,falselabel);
         end
       else
         InternalError(2011010419);
       CurrentFilePos:=storepos;
    end;


  procedure THLCGObj.maybe_change_load_node_reg(list: TAsmList; var n: TNode; reload: boolean);
    var
      rr: TReplaceRegRec;
      varloc : TAIVarLoc;
    begin
      if not (n.location.loc in [LOC_CREGISTER,LOC_CFPUREGISTER,LOC_CMMXREGISTER,LOC_CMMREGISTER]) or
        ([fc_inflowcontrol,fc_gotolabel,fc_lefthandled] * flowcontrol <> []) then
        exit;
      rr.old := n.location.register;
      rr.ressym := nil;
      rr.sym := nil;
      rr.oldhi := NR_NO;
      case n.location.loc of
        LOC_CREGISTER:
          begin
{$ifdef cpu64bitalu}
            if (n.location.size in [OS_128,OS_S128]) then
              begin
                rr.oldhi := n.location.register128.reghi;
                rr.new := cg.getintregister(CurrentAsmData.CurrAsmList,OS_INT);
                rr.newhi := cg.getintregister(CurrentAsmData.CurrAsmList,OS_INT);
              end
            else
{$else cpu64bitalu}
            if (n.location.size in [OS_64,OS_S64]) then
              begin
                rr.oldhi := n.location.register64.reghi;
                rr.new := cg.getintregister(CurrentAsmData.CurrAsmList,OS_32);
                rr.newhi := cg.getintregister(CurrentAsmData.CurrAsmList,OS_32);
              end
            else
{$endif cpu64bitalu}
              if getregtype(rr.old)=R_ADDRESSREGISTER then
                rr.new := hlcg.getaddressregister(CurrentAsmData.CurrAsmList,n.resultdef)
              else
                rr.new := cg.getintregister(CurrentAsmData.CurrAsmList,n.location.size);
          end;
        LOC_CFPUREGISTER:
          rr.new := cg.getfpuregister(CurrentAsmData.CurrAsmList,n.location.size);
{$ifdef SUPPORT_MMX}
        LOC_CMMXREGISTER:
          rr.new := TCGX86(cg).getmmxregister(CurrentAsmData.CurrAsmList);
{$endif SUPPORT_MMX}
        LOC_CMMREGISTER:
          rr.new := cg.getmmregister(CurrentAsmData.CurrAsmList,n.location.size);
        else
          exit;
      end;

      { self is implicitly returned from constructors, even if there are no
        references to it; additionally, funcretsym is not set for constructor
        procdefs }
      if (CurrentProcInfo.procdef.proctypeoption=potype_constructor) then
        rr.ressym:=TSym(CurrentProcInfo.procdef.parast.Find('self'))
      else if not is_void(CurrentProcInfo.procdef.returndef) and
         Assigned(CurrentProcInfo.procdef.funcretsym) and
         (TAbstractVarSym(CurrentProcInfo.procdef.funcretsym).refs <> 0) then
        rr.ressym:=CurrentProcInfo.procdef.funcretsym;

      if not foreachnode(n,@do_replace_node_regs,@rr) then
        exit;

      if reload then
        case n.location.loc of
          LOC_CREGISTER:
            begin
{$ifdef cpu64bitalu}
              if (n.location.size in [OS_128,OS_S128]) then
                cg128.a_load128_reg_reg(list,n.location.register128,joinreg128(rr.new,rr.newhi))
              else
{$else cpu64bitalu}
              if (n.location.size in [OS_64,OS_S64]) then
                cg64.a_load64_reg_reg(list,n.location.register64,joinreg64(rr.new,rr.newhi))
              else
{$endif cpu64bitalu}
                a_load_reg_reg(list,n.resultdef,n.resultdef,n.location.register,rr.new);
            end;
          LOC_CFPUREGISTER:
            cg.a_loadfpu_reg_reg(list,n.location.size,n.location.size,n.location.register,rr.new);
{$ifdef SUPPORT_MMX}
          LOC_CMMXREGISTER:
            cg.a_loadmm_reg_reg(list,OS_M64,OS_M64,n.location.register,rr.new,nil);
{$endif SUPPORT_MMX}
          LOC_CMMREGISTER:
            a_loadmm_reg_reg(list,n.resultdef,n.resultdef,n.location.register,rr.new,nil);
          else
            InternalError(2006090920);
        end;

      { now that we've change the loadn/temp, also change the node result location }
{$ifdef cpu64bitalu}
      if (n.location.size in [OS_128,OS_S128]) then
        begin
          n.location.register128.reglo := rr.new;
          n.location.register128.reghi := rr.newhi;
          if Assigned(rr.sym) then
            begin
              varloc:=TAIVarLoc.create128(rr.sym,rr.new,rr.newhi);
              list.concat(varloc);
            end;
        end
      else
{$else cpu64bitalu}
      if (n.location.size in [OS_64,OS_S64]) then
        begin
          n.location.register64.reglo := rr.new;
          n.location.register64.reghi := rr.newhi;
          if Assigned(rr.sym) then
            begin
              varloc:=TAIVarLoc.create64(rr.sym,rr.new,rr.newhi);
              list.concat(varloc);
            end;
        end
      else
{$endif cpu64bitalu}
        begin
          n.location.register := rr.new;
          if Assigned(rr.sym) then
            begin
              varloc:=TAIVarLoc.create(rr.sym,rr.new);
              list.concat(varloc);
            end;
        end;
    end;


  function THLCGObj.do_replace_node_regs(var n: TNode; para: pointer): TForEachNodeResult;
    var
      rr: PReplaceRegRec absolute para;
    begin
      result := fen_false;
      if (nf_is_funcret in n.flags) and (fc_exit in flowcontrol) then
        exit;
      case n.nodetype of
        loadn:
          begin
            if (TLoadNode(n).symtableentry.typ in [localvarsym,paravarsym,staticvarsym]) and
               (TAbstractVarSym(TLoadNode(n).symtableentry).varoptions * [vo_is_dll_var, vo_is_thread_var] = []) and
               not Assigned(TLoadNode(n).left) and
               ((TLoadNode(n).symtableentry <> rr^.ressym) or
                not(fc_exit in flowcontrol)
               ) and
               (TAbstractNormalVarSym(TLoadNode(n).symtableentry).localloc.loc in [LOC_CREGISTER,LOC_CFPUREGISTER,LOC_CMMXREGISTER,LOC_CMMREGISTER]) and
               (TAbstractNormalVarSym(TLoadNode(n).symtableentry).localloc.register = rr^.old) then
              begin
{$ifdef cpu64bitalu}
                { it's possible a 128 bit location was shifted and/xor typecasted }
                { in a 64 bit value, so only 1 register was left in the location }
                if (TAbstractNormalVarSym(TLoadNode(n).symtableentry).localloc.size in [OS_128,OS_S128]) then
                  if (TAbstractNormalVarSym(TLoadNode(n).symtableentry).localloc.register128.reghi = rr^.oldhi) then
                    TAbstractNormalVarSym(TLoadNode(n).symtableentry).localloc.register128.reghi := rr^.newhi
                  else
                    exit;
{$else cpu64bitalu}
                { it's possible a 64 bit location was shifted and/xor typecasted }
                { in a 32 bit value, so only 1 register was left in the location }
                if (TAbstractNormalVarSym(TLoadNode(n).symtableentry).localloc.size in [OS_64,OS_S64]) then
                  if (TAbstractNormalVarSym(TLoadNode(n).symtableentry).localloc.register64.reghi = rr^.oldhi) then
                    TAbstractNormalVarSym(TLoadNode(n).symtableentry).localloc.register64.reghi := rr^.newhi
                  else
                    exit;
{$endif cpu64bitalu}
                TAbstractNormalVarSym(TLoadNode(n).symtableentry).localloc.register := rr^.new;
                rr^.sym := TAbstractNormalVarSym(TLoadNode(n).symtableentry);
                result := fen_norecurse_true;
              end;
          end;
        temprefn:
          begin
            if (ti_valid in TTempRefNode(n).tempflags) and
               (TTempRefNode(n).tempinfo^.location.loc in [LOC_CREGISTER,LOC_CFPUREGISTER,LOC_CMMXREGISTER,LOC_CMMREGISTER]) and
               (TTempRefNode(n).tempinfo^.location.register = rr^.old) then
              begin
{$ifdef cpu64bitalu}
                { it's possible a 128 bit location was shifted and/xor typecasted }
                { in a 64 bit value, so only 1 register was left in the location }
                if (TTempRefNode(n).tempinfo^.location.size in [OS_128,OS_S128]) then
                  if (TTempRefNode(n).tempinfo^.location.register128.reghi = rr^.oldhi) then
                    TTempRefNode(n).tempinfo^.location.register128.reghi := rr^.newhi
                  else
                    exit;
{$else cpu64bitalu}
                { it's possible a 64 bit location was shifted and/xor typecasted }
                { in a 32 bit value, so only 1 register was left in the location }
                if (TTempRefNode(n).tempinfo^.location.size in [OS_64,OS_S64]) then
                  if (TTempRefNode(n).tempinfo^.location.register64.reghi = rr^.oldhi) then
                    TTempRefNode(n).tempinfo^.location.register64.reghi := rr^.newhi
                  else
                    exit;
{$endif cpu64bitalu}
                TTempRefNode(n).tempinfo^.location.register := rr^.new;
                result := fen_norecurse_true;
              end;
          end;
        { optimize the searching a bit }
        derefn,addrn,
        calln,inlinen,casen,
        addn,subn,muln,
        andn,orn,xorn,
        ltn,lten,gtn,gten,equaln,unequaln,
        slashn,divn,shrn,shln,notn,
        inn,
        asn,isn:
          result := fen_norecurse_false;
        vecn:
          { we cannot do SSA during partial writes to arrays which span multiple registers, see also tw39325 }
          if (TVecNode(n).left.location.loc in [LOC_CREGISTER,LOC_CFPUREGISTER,LOC_CMMXREGISTER,LOC_CMMREGISTER]) and
            (tcgsize2size[reg_cgsize(TVecNode(n).left.location.register)]<>TVecNode(n).left.resultdef.size) then
            result := fen_norecurse_false;
        else
          ;
      end;
    end;


  procedure THLCGObj.gen_proc_symbol(list: TAsmList);
    begin
      fphlcgobjhelper.gen_proc_symbol(list);
    end;

  procedure THLCGObj.gen_proc_symbol_end(list: TAsmList);
    begin
      if nexus_profile_proc_eligible(CurrentProcInfo) then
        begin
          if not Assigned(CurrentProcInfo.nexus_profile_endlabel) then
            CurrentAsmData.getjumplabel(CurrentProcInfo.nexus_profile_endlabel);
          list.concat(TAILabel.create(CurrentProcInfo.nexus_profile_endlabel));
          emit_nexus_profile_descriptor;
        end;
      if (CurrentProcInfo.procdef.proctypeoption=potype_proginit) and
         (cs_nexus_profile in CurrentSettings.ModuleSwitches) and
         (TargetInfo.system=system_x86_64_win64) and
         not CurrentModule.IsLibrary then
        emit_nexus_profile_module_data;
      list.concat(TAISymbolEnd.Createname(CurrentProcInfo.procdef.mangledname));
      CurrentProcInfo.procdef.procendtai:=TAI(list.last);
    end;


  procedure THLCGObj.handle_external_proc(list: TAsmList; pd: TProcDef; const importname: TSymStr);
    begin
      { External declared in implementation, and there was already a
        forward (or interface) declaration then we need to generate
        a stub that calls the external routine }
      if (not pd.forwarddef) and
         (pd.hasforward) then
        begin
          if importname<>'' then
            begin
             { add the procedure to the al_procedures }
             g_external_wrapper(list,pd,pd.mangledname,importname,true);
            end;
          { remove the external stuff, so that the interface crc
            doesn't change. This makes the function calls less
            efficient, but it means that the interface doesn't
            change if the function is ever redirected to another
            function or implemented in the unit. }
          pd.procoptions:=pd.procoptions-[po_external,po_has_importname,po_has_importdll];
          StringDispose(pd.import_name);
          StringDispose(pd.import_dll);
          pd.import_nr:=0;
        end;
    end;


  procedure THLCGObj.gen_initialize_code(list: TAsmList);
    begin
      { initialize global register variables }
      case CurrentProcInfo.procdef.proctypeoption of
        potype_unitinit,
        potype_proginit:
          TSymTable(CurrentModule.localsymtable).SymList.ForEachCall(@initialize_regvars,list);
        else
          ;
      end;

      { initialises temp. ansi/wide string data }
      if (CurrentProcInfo.procdef.proctypeoption<>potype_exceptfilter) or
         (TargetInfo.system=system_aarch64_win64) then
        inittempvariables(list);
    end;

  procedure THLCGObj.gen_finalize_code(list: TAsmList);
    var
      old_current_procinfo: TProcInfo;
      for_finalization: boolean;
    begin
      old_current_procinfo:=CurrentProcInfo;
      for_finalization:=false;
      if (CurrentProcInfo.procdef.proctypeoption=potype_exceptfilter) then
        begin
          if (CurrentProcInfo.parent.finalize_procinfo<>CurrentProcInfo) then
            exit;
          CurrentProcInfo:=CurrentProcInfo.parent;
          for_finalization:=true;
        end;

      { finalize paras data }
      if Assigned(CurrentProcInfo.procdef.parast) and
         not(po_assembler in CurrentProcInfo.procdef.procoptions) then
        CurrentProcInfo.procdef.parast.SymList.ForEachCall(@final_paras,list);

      { finalize temporary data }
      finalizetempvariables(list,for_finalization);

      CurrentProcInfo:=old_current_procinfo;
    end;

  procedure THLCGObj.varsym_set_localloc(list: TAsmList; vs: TAbstractNormalVarSym);
    begin
      if cs_asm_source in CurrentSettings.GlobalSwitches then
        begin
          case vs.initialloc.loc of
            LOC_REFERENCE :
              begin
                if not Assigned(vs.initialloc.reference.symbol) then
                  list.concat(TAIComment.Create(StrPNew('Var '+vs.realname+' located at '+
                     std_regname(vs.initialloc.reference.base)+ToStr_With_Plus(vs.initialloc.reference.offset)+
                     ', size='+tcgsize2str(vs.initialloc.size))));
              end;
            else
              ;
          end;
        end;
      vs.localloc:=vs.initialloc;
    end;

  procedure THLCGObj.paravarsym_set_initialloc_to_paraloc(vs: TParaVarSym);
    begin
      reference_reset_base(vs.initialloc.reference,voidstackpointertype,TParaVarSym(vs).paraloc[calleeside].location^.reference.index,
          TParaVarSym(vs).paraloc[calleeside].location^.reference.offset,ctempposinvalid,
          TParaVarSym(vs).paraloc[calleeside].alignment,[]);
    end;

  procedure THLCGObj.gen_entry_code(list: TAsmList);
    begin
      { call startup helpers from main program }
      if (CurrentProcInfo.procdef.proctypeoption=potype_proginit) then
       begin
         if cs_nexus_profile in CurrentSettings.ModuleSwitches then
           gen_nexus_profile_module_call(list,'nxp_module_register');
         { initialize units }
         if not(CurrentModule.IsLibrary) then
           begin
             if tf_init_final_units_by_calls in TargetInfo.flags then
               begin
                 { Only insert call if there are init functions }
                 if CNodeUtils.has_init_list then
                   cg.a_call_name(list,'FPC_INIT_FUNC_TABLE',false);
               end
             else
               g_call_system_proc(list,'fpc_initializeunits',[],nil).resetiftemp;
           end
         else
           g_call_system_proc(list,'fpc_libinitializeunits',[],nil).resetiftemp;
       end;

      { The program body starts after its units. The image was already
        registered before unit initialization. }
      if nexus_profile_proc_eligible(CurrentProcInfo) then
        gen_nexus_profile_call(list,'nxp_enter');

      list.concat(TAIForceLine.Create);
    end;

  procedure THLCGObj.gen_exit_code(list: TAsmList);
    begin
      { TODO: create high level version (create compilerproc in system unit,
          look up procdef, use hlcgobj.a_call_name()) }

      if nexus_profile_proc_eligible(CurrentProcInfo) then
        gen_nexus_profile_call(list,'nxp_leave');

      { call __EXIT for main program }
      if (not CurrentModule.IsLibrary) and
         (CurrentProcInfo.procdef.proctypeoption=potype_proginit) then
        g_call_system_proc(list,'fpc_do_exit',[],nil).resetiftemp;
    end;

{$push}{$Q-}
  function nexus_profile_hash64(const s: AnsiString): qword;
    var
      i: SizeInt;
    begin
      result:=qword($CBF29CE484222325);
      for i:=1 to length(s) do
        begin
          result:=result xor byte(s[i]);
          result:=result*qword($100000001B3);
        end;
    end;
{$pop}

  procedure ensure_nexus_profile_descriptor_symbol;
    var
      symname: string;
    begin
      if Assigned(CurrentProcInfo.nexus_profile_descsym) then
        exit;
      symname:='NXP_DESC_'+CurrentModule.ModuleName^+'_'+
        CurrentProcInfo.procdef.UniqueIDStr;
      CurrentProcInfo.nexus_profile_descsym:=CurrentAsmData.DefineAsmSymbol(
        symname,AB_LOCAL,AT_DATA,voidpointertype);
    end;

  procedure THLCGObj.gen_nexus_profile_call(list:TAsmList; const hookname:TIDString);
    var
      para: TCGPara;
      paraloc: PCGParaLocation;
      href: TReference;
    begin
      ensure_nexus_profile_descriptor_symbol;
{$ifdef x86_64}
      CurrentModule.add_extern_asmsym(hookname,AB_EXTERNAL,AT_FUNCTION);
      para.init;
      para.def:=voidpointertype;
      para.size:=OS_ADDR;
      para.intsize:=sizeof(PInt);
      paraloc:=para.add_location;
      paraloc^.def:=voidpointertype;
      paraloc^.size:=OS_ADDR;
      paraloc^.loc:=LOC_REGISTER;
      paraloc^.register:=NR_RCX;
      reference_reset_symbol(href,CurrentProcInfo.nexus_profile_descsym,0,
        sizeof(PInt),[]);
      a_loadaddr_ref_cgpara(list,voidpointertype,href,para);
      allocallcpuregisters(list);
      cg.a_call_name(list,hookname,false);
      deallocallcpuregisters(list);
      para.done;
{$else x86_64}
      InternalError(2026092301);
{$endif x86_64}
    end;

  procedure THLCGObj.gen_nexus_profile_module_call(list:TAsmList;
    const hookname:TIDString);
    var
      para: TCGPara;
      paraloc: PCGParaLocation;
      href: TReference;
      modulesym: TAsmSymbol;
    begin
{$ifdef x86_64}
      CurrentModule.add_extern_asmsym(hookname,AB_EXTERNAL,AT_FUNCTION);
      modulesym:=CurrentAsmData.RefAsmSymbol('__NXP_module_descriptor',AT_DATA);
      para.init;
      para.def:=voidpointertype;
      para.size:=OS_ADDR;
      para.intsize:=sizeof(PInt);
      paraloc:=para.add_location;
      paraloc^.def:=voidpointertype;
      paraloc^.size:=OS_ADDR;
      paraloc^.loc:=LOC_REGISTER;
      paraloc^.register:=NR_RCX;
      reference_reset_symbol(href,modulesym,0,sizeof(PInt),[]);
      a_loadaddr_ref_cgpara(list,voidpointertype,href,para);
      allocallcpuregisters(list);
      cg.a_call_name(list,hookname,false);
      deallocallcpuregisters(list);
      para.done;
{$else x86_64}
      InternalError(2026092302);
{$endif x86_64}
    end;

  procedure THLCGObj.emit_nexus_profile_descriptor;
    const
      NXP_DESC_MAGIC = $4450584E; { NXPD }
      NXP_DESC_ABI = 1;
      NXP_DESC_SIZE = 72;
    var
      pd: TProcDef;
      key,name,profunitname,source: AnsiString;
      stableid: qword;
      namelabel,unitlabel,sourcelabel: TAsmLabOfs;
      sourcefile: TInputFile;
      section: TAISection;
      tcb: TTAITypedConstBuilder;
    begin
      ensure_nexus_profile_descriptor_symbol;
      pd:=CurrentProcInfo.procdef;
      name:=pd.fullprocname(true);
      profunitname:=CurrentModule.RealModuleName^;
      sourcefile:=get_source_file(CurrentProcInfo.entrypos.moduleindex,
        CurrentProcInfo.entrypos.fileindex);
      if Assigned(sourcefile) then
        source:=sourcefile.path+sourcefile.name
      else
        source:='';
      key:=profunitname+'|'+name+'|'+pd.mangledname+'|'+pd.UniqueIDStr;
      stableid:=nexus_profile_hash64(key);
      tcb:=CTAITypedConstBuilder.create([]);
      if name='' then
        namelabel:=tcb.emit_ansistring_const(CurrentAsmData.asmlists[al_const],
          nil,0,getansistringcodepage)
      else
        namelabel:=tcb.emit_ansistring_const(CurrentAsmData.asmlists[al_const],
          @name[1],length(name),getansistringcodepage);
      if profunitname='' then
        unitlabel:=tcb.emit_ansistring_const(CurrentAsmData.asmlists[al_const],
          nil,0,getansistringcodepage)
      else
        unitlabel:=tcb.emit_ansistring_const(CurrentAsmData.asmlists[al_const],
          @profunitname[1],length(profunitname),getansistringcodepage);
      if source='' then
        sourcelabel:=tcb.emit_ansistring_const(CurrentAsmData.asmlists[al_const],
          nil,0,getansistringcodepage)
      else
        sourcelabel:=tcb.emit_ansistring_const(CurrentAsmData.asmlists[al_const],
          @source[1],length(source),getansistringcodepage);
      tcb.free;
      section:=new_section(CurrentProcInfo.aktlocaldata,sec_user,
        '.nxprof$M_'+HexStr(int64(stableid),16),3);
      CurrentProcInfo.nexus_profile_section:=section;
      CurrentProcInfo.aktlocaldata.concat(TAISymbol.create(
        CurrentProcInfo.nexus_profile_descsym,NXP_DESC_SIZE));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_32bit(NXP_DESC_MAGIC));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_16bit(NXP_DESC_ABI));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_16bit(0));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_32bit(0));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_32bit(0));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_64bit(int64(stableid)));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_sym(
        CurrentAsmData.RefAsmSymbol(pd.mangledname,AT_FUNCTION)));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_sym(
        CurrentProcInfo.nexus_profile_endlabel));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_sym_offset(
        namelabel.lab,namelabel.ofs));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_sym_offset(
        unitlabel.lab,unitlabel.ofs));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_sym_offset(
        sourcelabel.lab,sourcelabel.ofs));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_32bit(
        CurrentProcInfo.entrypos.line));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_32bit(
        CurrentProcInfo.entrypos.column));
    end;

  procedure THLCGObj.emit_nexus_profile_module_data;
    const
      NXP_MODULE_MAGIC = $4D50584E; { NXPM }
      NXP_MODULE_ABI = 1;
      NXP_MODULE_SIZE = 32;
    var
      startsection,endsection,modulesection: TAISection;
      startsym,endsym,modulesym: TAsmSymbol;
    begin
      startsym:=CurrentAsmData.DefineAsmSymbol('__NXP_descriptor_start',
        AB_GLOBAL,AT_DATA,voidpointertype);
      endsym:=CurrentAsmData.DefineAsmSymbol('__NXP_descriptor_end',
        AB_GLOBAL,AT_DATA,voidpointertype);
      modulesym:=CurrentAsmData.DefineAsmSymbol('__NXP_module_descriptor',
        AB_GLOBAL,AT_DATA,voidpointertype);

      modulesection:=new_section(CurrentProcInfo.aktlocaldata,sec_user,
        '.nxprof$0',3);
      CurrentProcInfo.aktlocaldata.concat(TAISymbol.create_global(modulesym,
        NXP_MODULE_SIZE));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_32bit(
        NXP_MODULE_MAGIC));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_16bit(
        NXP_MODULE_ABI));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_16bit(0));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_32bit(0));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_32bit(0));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_sym_offset(
        startsym,sizeof(QWord)));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_sym(endsym));

      startsection:=new_section(CurrentProcInfo.aktlocaldata,sec_user,
        '.nxprof$A',3);
      CurrentProcInfo.aktlocaldata.concat(TAISymbol.create_global(startsym,
        sizeof(QWord)));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_64bit(0));

      endsection:=new_section(CurrentProcInfo.aktlocaldata,sec_user,
        '.nxprof$Z',3);
      CurrentProcInfo.aktlocaldata.concat(TAISymbol.create_global(endsym,
        sizeof(QWord)));
      CurrentProcInfo.aktlocaldata.concat(TAIConst.create_64bit(0));
      { Keep the locals assigned so builds with internal consistency checks can
        verify all three explicit sections were created. }
      if not Assigned(modulesection) or not Assigned(startsection) or
         not Assigned(endsection) then
        InternalError(2026092303);
    end;

  procedure THLCGObj.inittempvariables(list: TAsmList);
    var
      hp : PTempRecord;
      href : TReference;
    begin
      hp:=tg.templist;
      while Assigned(hp) do
       begin
         if hp^.fini and
            Assigned(hp^.def) and
            is_managed_type(hp^.def) then
          begin
            tg.temp_to_ref(hp,href);
            { On AArch64-Win64 exceptfilters have their own SP-relative temps
              but share the parent's temp allocator. Parent temps are already
              initialised by the parent; only handler-local temps need zeroing.
              adjust_exceptfilter_ref converts parent temps to FP-relative,
              so if the base changed from the framepointer it is a parent temp. }
            if (CurrentProcInfo.procdef.proctypeoption=potype_exceptfilter) then
              begin
                cg.adjust_exceptfilter_ref(href,false);
                if href.base<>CurrentProcInfo.framepointer then
                  begin
                    hp:=hp^.next;
                    continue;
                  end;
              end;
            g_initialize(list,hp^.def,href);
          end;
         hp:=hp^.next;
       end;
    end;

  procedure THLCGObj.finalizetempvariables(list: TAsmList;for_finalization:boolean);
    var
      hp : PTempRecord;
      href : TReference;
    begin
      hp:=tg.templist;
      while Assigned(hp) do
       begin
         if hp^.fini and
            Assigned(hp^.def) and
            is_managed_type(hp^.def) then
          begin
            include(CurrentProcInfo.flags,pi_needs_implicit_finally);
            tg.temp_to_ref(hp,href);
            if for_finalization then
              cg.adjust_exceptfilter_ref(href,true);
            g_finalize(list,hp^.def,href);
          end;
         hp:=hp^.next;
       end;
    end;

  procedure THLCGObj.initialize_regvars(p: TObject; arg: pointer);
    var
      href : TReference;
      mmreg : TRegister;
    begin
      if (TSym(p).typ=staticvarsym) and not(TStaticVarSym(p).noregvarinitneeded) then
       begin
         { Static variables can have the initialloc only set to LOC_CxREGISTER
           or LOC_INVALID, for explanation see gen_alloc_symtable (PFV) }
         case TStaticVarSym(p).initialloc.loc of
           LOC_CREGISTER :
             begin
{$ifdef cpu64bitalu}
               if (TStaticVarSym(p).initialloc.size in [OS_128,OS_S128]) then
                 cg128.a_load128_const_reg(TAsmList(arg),0,0,TStaticVarSym(p).initialloc.register128)
               else
{$else cpu64bitalu}
               if (TStaticVarSym(p).initialloc.size in [OS_64,OS_S64]) then
                 cg64.a_load64_const_reg(TAsmList(arg),0,TStaticVarSym(p).initialloc.register64)
               else
{$endif cpu64bitalu}
                 a_load_const_reg(TAsmList(arg),TStaticVarSym(p).vardef,0,
                     TStaticVarSym(p).initialloc.register);
             end;
           LOC_CMMREGISTER :
             begin
               { clear the whole register }
               mmreg:=newreg(R_MMREGISTER,getsupreg(TStaticVarSym(p).initialloc.register),R_SUBMMWHOLE);
               a_opmm_reg_reg(TAsmList(arg),OP_XOR,TStaticVarSym(p).vardef, mmreg, mmreg,
                 { as we pass shuffle=nil, we have to pass a full register }
                 nil);
             end;
           LOC_CFPUREGISTER :
             begin
               { initialize fpu regvar by loading from memory }
               reference_reset_symbol(href,
                 CurrentAsmData.RefAsmSymbol(TStaticVarSym(p).mangledname,AT_DATA), 0,
                 Var_Align(TStaticVarSym(p).vardef.alignment),[]);
               a_loadfpu_ref_reg(TAsmList(arg), TStaticVarSym(p).vardef,
                 TStaticVarSym(p).vardef, href, TStaticVarSym(p).initialloc.register);
             end;
           LOC_INVALID :
             ;
           else
             InternalError(200410124);
         end;
       end;
    end;

  procedure THLCGObj.final_paras(p: TObject; arg: pointer);
    var
      list : TAsmList;
      href : TReference;
      hsym : TParaVarSym;
      eldef : TDef;
      highloc : TLocation;
    begin
      if not(TSym(p).typ=paravarsym) then
        exit;
      list:=TAsmList(arg);
      if is_managed_type(TParaVarSym(p).vardef) then
       begin
         if (TParaVarSym(p).varspez=vs_value) then
          begin
            include(CurrentProcInfo.flags,pi_needs_implicit_finally);
            location_get_data_ref(list,TParaVarSym(p).vardef,TParaVarSym(p).localloc,href,
              is_open_array(TParaVarSym(p).vardef) or
              ((TargetInfo.system in systems_caller_copy_addr_value_para) and
               paramanager.push_addr_param(vs_value,TParaVarSym(p).vardef,CurrentProcInfo.procdef.proccalloption)),
              sizeof(PInt));
            if is_open_array(TParaVarSym(p).vardef) then
              begin
                if paramanager.push_high_param(TParaVarSym(p).varspez,TParaVarSym(p).vardef,CurrentProcInfo.procdef.proccalloption) then
                  begin
                    hsym:=TParaVarSym(get_high_value_sym(TParaVarSym(p)));
                    if not Assigned(hsym) then
                      InternalError(201003032);
                    highloc:=hsym.initialloc;
                    { adjust high bound reference for exceptfilter finalization }
                    if Assigned(CurrentProcInfo.finalize_procinfo) and
                       (CurrentProcInfo.finalize_procinfo.procdef.proctypeoption=potype_exceptfilter) and
                       (highloc.loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                      cg.adjust_exceptfilter_ref(highloc.reference,true);
                  end
                else
                  highloc.loc:=LOC_INVALID;
                eldef:=TArrayDef(TParaVarSym(p).vardef).elementdef;
                g_ptrtypecast_ref(list,CPointerDef.getreusable(TParaVarSym(p).vardef),CPointerDef.getreusable(eldef),href);
                g_array_rtti_helper(list,eldef,href,highloc,'fpc_finalize_array');
              end
            else
              g_finalize(list,TParaVarSym(p).vardef,href);
          end;
       end;
      { open arrays can contain elements requiring init/final code, so the else has been removed here }
      if not(TargetInfo.system in systems_caller_copy_addr_value_para) and
         (TParaVarSym(p).varspez=vs_value) and
         (is_open_array(TParaVarSym(p).vardef) or
          is_array_of_const(TParaVarSym(p).vardef)) then
        begin
          { cdecl functions don't have a high pointer so it is not possible to generate
            a local copy }
          if not(CurrentProcInfo.procdef.proccalloption in cdecl_pocalls) then
            g_releasevaluepara_openarray(list,TArrayDef(TParaVarSym(p).vardef),TParaVarSym(p).localloc);
        end;
    end;


{ generates the code for incrementing the reference count of parameters and
  initialize out parameters }
  { generates the code for incrementing the reference count of parameters and
    initialize out parameters }
  procedure THLCGObj.init_paras(p:TObject;arg:pointer);
    var
      href : TReference;
      hsym : TParaVarSym;
      eldef : TDef;
      list : TAsmList;
      highloc : TLocation;
      NeedsInitTable  : boolean;
    begin
      list:=TAsmList(arg);
      if (TSym(p).typ=paravarsym) then
       begin
         NeedsInitTable:=is_managed_type(TParaVarSym(p).vardef);
         case TParaVarSym(p).varspez of
           vs_value :
             if NeedsInitTable then
               begin
                 { variants are already handled by the call to fpc_variant_copy_overwrite if
                   they are passed by reference }
                 if not((TParaVarSym(p).vardef.typ=variantdef) and
                   paramanager.push_addr_param(TParaVarSym(p).varspez,TParaVarSym(p).vardef,CurrentProcInfo.procdef.proccalloption)) then
                   begin
                     location_get_data_ref(list,TParaVarSym(p).vardef,TParaVarSym(p).initialloc,href,
                       is_open_array(TParaVarSym(p).vardef) or
                       ((TargetInfo.system in systems_caller_copy_addr_value_para) and
                        paramanager.push_addr_param(vs_value,TParaVarSym(p).vardef,CurrentProcInfo.procdef.proccalloption)),
                       sizeof(PInt));
                     if is_open_array(TParaVarSym(p).vardef) then
                       begin
                         if paramanager.push_high_param(TParaVarSym(p).varspez,TParaVarSym(p).vardef,CurrentProcInfo.procdef.proccalloption) then
                           begin
                             hsym:=TParaVarSym(get_high_value_sym(TParaVarSym(p)));
                             if not Assigned(hsym) then
                               InternalError(2010030303);
                             highloc:=hsym.initialloc
                           end
                         else
                           highloc.loc:=LOC_INVALID;
                         { open arrays do not contain correct element count in their rtti,
                           the actual count must be passed separately. }
                         eldef:=TArrayDef(TParaVarSym(p).vardef).elementdef;
                         g_ptrtypecast_ref(list,CPointerDef.getreusable(TParaVarSym(p).vardef),CPointerDef.getreusable(eldef),href);
                         g_array_rtti_helper(list,eldef,href,highloc,'fpc_addref_array');
                       end
                     else
                      g_incrrefcount(list,TParaVarSym(p).vardef,href);
                   end;
               end;
           vs_out :
             begin
               if NeedsInitTable then
                 begin
                   { we have no idea about the alignment at the callee side,
                     and the user also cannot specify "unaligned" here, so
                     assume worst case }
                   location_get_data_ref(list,TParaVarSym(p).vardef,TParaVarSym(p).initialloc,href,true,1);
                   if NeedsInitTable then
                     begin
                       if is_open_array(TParaVarSym(p).vardef) then
                         begin
                           if paramanager.push_high_param(TParaVarSym(p).varspez,TParaVarSym(p).vardef,CurrentProcInfo.procdef.proccalloption) then
                             begin
                               hsym:=TParaVarSym(get_high_value_sym(TParaVarSym(p)));
                               if not Assigned(hsym) then
                                 InternalError(2010030304);
                               highloc:=hsym.initialloc
                             end
                           else
                             highloc.loc:=LOC_INVALID;
                           eldef:=TArrayDef(TParaVarSym(p).vardef).elementdef;
                           g_ptrtypecast_ref(list,CPointerDef.getreusable(TParaVarSym(p).vardef),CPointerDef.getreusable(eldef),href);
                           g_array_rtti_helper(list,eldef,href,highloc,'fpc_initialize_array');
                         end
                       else
                         g_initialize(list,TParaVarSym(p).vardef,href);
                     end;
                 end;
             end;
           else
             ;
         end;
       end;
    end;

  procedure THLCGObj.gen_load_para_value(list: TAsmList);
    var
      i: LongInt;
      currpara: TParaVarSym;
    begin
      if (po_assembler in CurrentProcInfo.procdef.procoptions) or
      { exceptfilters have a single hidden 'parentfp' parameter, which
        is handled by tcg.g_proc_entry. }
         (CurrentProcInfo.procdef.proctypeoption=potype_exceptfilter) then
        exit;

      { Copy parameters to local references/registers }
      for i:=0 to CurrentProcInfo.procdef.paras.count-1 do
        begin
          currpara:=TParaVarSym(CurrentProcInfo.procdef.paras[i]);
          if not currpara.is_used then
            continue;
          { don't use currpara.vardef, as this will be wrong in case of
            call-by-reference parameters (it won't contain the pointer) }
          gen_load_cgpara_loc(list,currpara.paraloc[calleeside].def,currpara.paraloc[calleeside],currpara.initialloc,paramanager.param_use_paraloc(currpara.paraloc[calleeside]));
        end;

      { generate copies of call by value parameters, must be done before
        the initialization and body is parsed because the refcounts are
        incremented using the local copies }
      CurrentProcInfo.procdef.parast.SymList.ForEachCall(@g_copyvalueparas,list);

      if not(po_assembler in CurrentProcInfo.procdef.procoptions) then
        begin
          { initialize refcounted paras, and trash others. Needed here
            instead of in gen_initialize_code, because when a reference is
            initialized or trashed while the pointer to that reference is kept
            in a regvar, we add a register move and that one again has to
            come after the parameter loading code as far as the register
            allocator is concerned }
          CurrentProcInfo.procdef.parast.SymList.ForEachCall(@init_paras,list);
        end;
    end;

  procedure THLCGObj.g_copyvalueparas(p: TObject; arg: pointer);
    var
      href : TReference;
      hreg : TRegister;
      list : TAsmList;
      hsym : TParaVarSym;
      l    : LongInt;
      highloc,
      localcopyloc : TLocation;
    begin
      list:=TAsmList(arg);
      if (TSym(p).typ=paravarsym) and
         (TParaVarSym(p).is_used) and
         ((vo_has_local_copy in TParaVarSym(p).varoptions) or
          (not(TargetInfo.system in systems_caller_copy_addr_value_para) and
           (is_open_array(TParaVarSym(p).vardef) or
            is_array_of_const(TParaVarSym(p).vardef)) and
           (TParaVarSym(p).varspez=vs_value))) then
        begin
          { we have no idea about the alignment at the caller side }
          location_get_data_ref(list,TParaVarSym(p).vardef,TParaVarSym(p).initialloc,href,true,1);
          if is_open_array(TParaVarSym(p).vardef) or
             is_array_of_const(TParaVarSym(p).vardef) then
            begin
              { cdecl functions don't have a high pointer so it is not possible to generate
                a local copy }
              if not(CurrentProcInfo.procdef.proccalloption in cdecl_pocalls) then
                begin
                  if paramanager.push_high_param(TParaVarSym(p).varspez,TParaVarSym(p).vardef,CurrentProcInfo.procdef.proccalloption) then
                    begin
                      hsym:=TParaVarSym(get_high_value_sym(TParaVarSym(p)));
                      if not Assigned(hsym) then
                        InternalError(2011020506);
                      highloc:=hsym.initialloc
                    end
                  else
                    highloc.loc:=LOC_INVALID;
                  hreg:=getaddressregister(list,voidpointertype);
                  if not is_packed_array(TParaVarSym(p).vardef) then
                    g_copyvaluepara_openarray(list,href,highloc,TArrayDef(TParaVarSym(p).vardef),hreg)
                  else
                    InternalError(2011020507);
//                      cg.g_copyvaluepara_packedopenarray(list,href,hsym.intialloc,tarraydef(tparavarsym(p).vardef).elepackedbitsize,hreg);
                  a_load_reg_loc(list,CPointerDef.getreusable(TParaVarSym(p).vardef),CPointerDef.getreusable(TParaVarSym(p).vardef),hreg,TParaVarSym(p).initialloc);
                end;
            end
          else
            begin
              { Allocate space for the local copy }
              l:=TParaVarSym(p).getsize;
              localcopyloc.loc:=LOC_REFERENCE;
              localcopyloc.size:=int_cgsize(l);
              getlocal(list,TParaVarSym(p),l,TParaVarSym(p).vardef.alignment,TParaVarSym(p).vardef,localcopyloc.reference);
              { Copy data }
              if is_shortstring(TParaVarSym(p).vardef) then
                begin
                  { this code is only executed before the code for the body and the entry/exit code is generated
                    so we're allowed to include pi_do_call here; after pass1 is run, this isn't allowed anymore
                  }
                  include(CurrentProcInfo.flags,pi_do_call);
                  g_copyshortstring(list,href,localcopyloc.reference,TStringDef(TParaVarSym(p).vardef))
                end
              else if TParaVarSym(p).vardef.typ=variantdef then
                begin
                  { this code is only executed before the code for the body and the entry/exit code is generated
                    so we're allowed to include pi_do_call here; after pass1 is run, this isn't allowed anymore
                  }
                  include(CurrentProcInfo.flags,pi_do_call);
                  g_copyvariant(list,href,localcopyloc.reference,TVariantDef(TParaVarSym(p).vardef))
                end
              else
                begin
                  g_concatcopy(list,TParaVarSym(p).vardef,href,localcopyloc.reference);
                end;
              { update localloc of varsym }
              if TParaVarSym(p).localloc.loc in [LOC_REFERENCE,LOC_CREFERENCE] then
                tg.Ungetlocal(list,TParaVarSym(p).localloc.reference);
              TParaVarSym(p).localloc:=localcopyloc;
              TParaVarSym(p).initialloc:=localcopyloc;
            end;
        end;
    end;


  procedure THLCGObj.getlocal(list: TAsmList; sym: TSym; size: asizeint; alignment: shortint; def: TDef; out ref: TReference);
    var
      explicitalign : shortint;
    begin
      if def.inheritsfrom(TAbstractRecordDef) and (def.typ in [recorddef]) then
        explicitalign:=TAbstractRecordSymTable(TAbstractRecordDef(def).SymTable).explicitrecordalignment
      else
        explicitalign:=0;
      tg.getlocal(list,size,alignment,explicitalign,def,sym,ref);
      recordnewsymloc(list,sym,def,ref,true);
    end;

  procedure THLCGObj.recordnewsymloc(list: TAsmList; sym: TSym; def: TDef; const ref: TReference; initial: boolean);
    begin
      // do nothing
    end;


  procedure THLCGObj.gen_loadfpu_loc_cgpara(list: TAsmList; size: TDef; const l: TLocation; const cgpara: TCGPara; locintsize: LongInt);
    var
      tmploc: TLocation;
    begin
      case l.loc of
        LOC_MMREGISTER,
        LOC_CMMREGISTER:
          case cgpara.location^.loc of
            LOC_REFERENCE,
            LOC_CREFERENCE,
            LOC_MMREGISTER,
            LOC_CMMREGISTER,
            LOC_REGISTER,
            LOC_CREGISTER :
              a_loadmm_reg_cgpara(list,size,l.register,cgpara,mms_movescalar);
            LOC_FPUREGISTER,
            LOC_CFPUREGISTER:
              begin
                tmploc:=l;
                location_force_fpureg(list,tmploc,size,false);
                a_loadfpu_reg_cgpara(list,size,tmploc.register,cgpara);
              end;
            else
              InternalError(2002042402);
          end;
        LOC_FPUREGISTER,
        LOC_CFPUREGISTER:
          case cgpara.location^.loc of
            LOC_MMREGISTER,
            LOC_CMMREGISTER:
              begin
                tmploc:=l;
                location_force_mmregscalar(list,tmploc,size,false);
                a_loadmm_reg_cgpara(list,size,tmploc.register,cgpara,mms_movescalar);
              end;
            { Some targets pass floats in normal registers }
            LOC_REGISTER,
            LOC_CREGISTER,
            LOC_REFERENCE,
            LOC_CREFERENCE,
            LOC_FPUREGISTER,
            LOC_CFPUREGISTER:
              a_loadfpu_reg_cgpara(list,size,l.register,cgpara);
            else
              InternalError(2011010210);
          end;
        LOC_REFERENCE,
        LOC_CREFERENCE:
          case cgpara.location^.loc of
            LOC_MMREGISTER,
            LOC_CMMREGISTER:
              a_loadmm_ref_cgpara(list,size,l.reference,cgpara,mms_movescalar);
            { Some targets pass floats in normal registers }
            LOC_REGISTER,
            LOC_CREGISTER,
            LOC_REFERENCE,
            LOC_CREFERENCE,
            LOC_FPUREGISTER,
            LOC_CFPUREGISTER:
              a_loadfpu_ref_cgpara(list,size,l.reference,cgpara);
            else
              InternalError(2011010211);
          end;
        LOC_REGISTER,
        LOC_CREGISTER :
          a_load_loc_cgpara(list,size,l,cgpara);
         else
           InternalError(2011010212);
      end;
    end;

  procedure THLCGObj.gen_load_uninitialized_function_result(list: TAsmList; pd: TProcDef; resdef: TDef; const resloc: TCGPara);
    begin
      { do nothing by default }
    end;

  procedure THLCGObj.gen_load_loc_function_result(list: TAsmList; vardef: TDef; const l: TLocation);
    var
      safecallretpara: TCGPara;
    begin
      if not CurrentProcInfo.procdef.generate_safecall_wrapper then
        gen_load_loc_cgpara(list,vardef,l,CurrentProcInfo.procdef.funcretloc[calleeside])
      else
        begin
          safecallretpara:=paramanager.get_safecallresult_funcretloc(CurrentProcInfo.procdef,calleeside);
          gen_load_loc_cgpara(list,vardef,l,safecallretpara);
          safecallretpara.resetiftemp;
        end;
    end;

  procedure THLCGObj.gen_load_loc_cgpara(list: TAsmList; vardef: TDef; const l: TLocation; const cgpara: TCGPara);
    var
      tmploc: TLocation;
    begin
      { skip e.g. empty records }
      if (cgpara.location^.loc = LOC_VOID) then
        exit;

      { Handle Floating point types differently

        This doesn't depend on emulator settings, emulator settings should
        be handled by cpupara }
      if (vardef.typ=floatdef) or
         { some ABIs return certain records in an fpu register }
         (l.loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) or
         (Assigned(cgpara.location) and
          (cgpara.Location^.loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER])) then
        begin
          gen_loadfpu_loc_cgpara(list,vardef,l,cgpara,vardef.size);
          exit;
        end;

      { in case of multiple locations, force the source to memory as only
        a_load_ref_cgpara supports multiple locations }
      if Assigned(cgpara.location^.next) and
         not(l.loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
        begin
          tmploc:=l;
          location_force_mem(list,tmploc,vardef);
          a_load_loc_cgpara(list,vardef,tmploc,cgpara);
          location_freetemp(list,tmploc);
          exit;
        end;

      case l.loc of
        LOC_CONSTANT,
        LOC_REGISTER,
        LOC_CREGISTER,
        LOC_REFERENCE,
        LOC_CREFERENCE :
          begin
            a_load_loc_cgpara(list,vardef,l,cgpara);
          end;
        LOC_MMREGISTER,
        LOC_CMMREGISTER:
          begin
            if use_vectorfpu(vardef) then
              a_loadmm_loc_cgpara(list,vardef,l,cgpara,mms_movescalar)
            else
              { no vector support yet }
              InternalError(2012071212);
              {
              cg.a_loadmm_loc_cgpara(list,l,cgpara,nil);
              }
          end;
        else
          InternalError(2011010213);
      end;
    end;

  procedure THLCGObj.gen_load_cgpara_loc(list: TAsmList; vardef: TDef; const para: TCGPara; var destloc: TLocation; reusepara: boolean);
    var
      href     : TReference;
    begin
      para.check_simple_location;
      { skip e.g. empty records }
      if (para.location^.loc = LOC_VOID) then
        exit;
      case destloc.loc of
        LOC_REFERENCE :
          begin
            { If the parameter location is reused we don't need to copy
              anything }
            if not reusepara then
              begin
                case para.location^.loc of
                  LOC_REFERENCE,LOC_CREFERENCE:
                    begin
                      reference_reset_base(href,voidstackpointertype,para.location^.reference.index,para.location^.reference.offset,ctempposinvalid,para.alignment,[]);
                      a_load_ref_ref(list,para.def,para.def,href,destloc.reference);
                    end;
                  else
                    InternalError(2013102305);
                end;
              end;
          end;
        { TODO other possible locations }
        else
          InternalError(2011010308);
      end;
    end;

  procedure THLCGObj.gen_load_return_value(list: TAsmList);
    var
      ressym : TSym;
      retdef : TDef;
    begin
      { Is the loading needed? }
      if (is_void(CurrentProcInfo.procdef.returndef) and
          not CurrentProcInfo.procdef.generate_safecall_wrapper) or
         (
          (po_assembler in CurrentProcInfo.procdef.procoptions) and
          (CurrentProcInfo.procdef.generate_safecall_wrapper or
           not Assigned(CurrentProcInfo.procdef.funcretsym) or
           (TAbstractVarSym(CurrentProcInfo.procdef.funcretsym).refs=0) or
           (po_nostackframe in CurrentProcInfo.procdef.procoptions)
          )
         ) then
        begin
          ressym:=CurrentProcInfo.procdef.funcretsym;
          if not Assigned(ressym) then
            exit;
        end
      else
        begin
          { constructors return self }
          if CurrentProcInfo.procdef.generate_safecall_wrapper then
            begin
              if not CurrentProcInfo.procdef.get_safecall_funcretsym_info(ressym,retdef) then
                InternalError(2019112402);
              gen_load_loc_function_result(list,retdef,TAbstractNormalVarSym(ressym).localloc);
            end
          else
            begin
              if not CurrentProcInfo.procdef.get_funcretsym_info(ressym,retdef) then
                InternalError(2018122501);
              if (ressym.refs>0) or
                 is_managed_type(retdef) then
                begin
                  { was: don't do anything if funcretloc.loc in [LOC_INVALID,LOC_REFERENCE] }
                  if not paramanager.ret_in_param(CurrentProcInfo.procdef.returndef,CurrentProcInfo.procdef) then
                    gen_load_loc_function_result(list,retdef,TAbstractNormalVarSym(ressym).localloc);
                end
              else
                gen_load_uninitialized_function_result(list,CurrentProcInfo.procdef,retdef,CurrentProcInfo.procdef.funcretloc[calleeside]);
            end;
        end;

      if TAbstractNormalVarSym(ressym).localloc.loc=LOC_REFERENCE then
        tg.UnGetLocal(list,TAbstractNormalVarSym(ressym).localloc.reference);
    end;

  procedure THLCGObj.gen_stack_check_size_para(list: TAsmList);
    var
      paraloc1 : TCGPara;
      pd       : TProcDef;
    begin
      pd:=search_system_proc('fpc_stackcheck');
      paraloc1.init;
      paramanager.getcgtempparaloc(CurrentAsmData.CurrAsmList,pd,1,paraloc1);
      hlcg.a_load_const_cgpara(list,paraloc1.def,CurrentProcInfo.calc_stackframe_size,paraloc1);
      paramanager.freecgpara(list,paraloc1);
      paraloc1.done;
    end;

  procedure THLCGObj.gen_stack_check_call(list: TAsmList);
    var
      paraloc1 : TCGPara;
      pd       : TProcDef;
    begin
      pd:=search_system_proc('fpc_stackcheck');
      paraloc1.init;
      { The parameter to fpc_stackcheck is loaded separately via
        gen_stack_check_size_para() }
      paramanager.getcgtempparaloc(list,pd,1,paraloc1);
      paramanager.freecgpara(list,paraloc1);
      { Call the helper }
      g_call_system_proc(list,pd,[@paraloc1],nil).resetiftemp;
      paraloc1.done;
    end;

  procedure THLCGObj.record_generated_code_for_procdef(pd: TProcDef; code, data: TAsmList);
    begin
      fphlcgobjhelper.record_generated_code_for_procdef(pd, code, data);
    end;

  function THLCGObj.g_call_system_proc(list: TAsmList; const procname: string; const paras: array of PCGPara; forceresdef: TDef): TCGPara;
    var
      pd: TProcDef;
    begin
      pd:=search_system_proc(procname);
      pd.init_paraloc_info(callerside);
      if systemunit<>CurrentModule.GlobalSymTable then
        CurrentModule.addimportedsym(pd.procsym);
      result:=g_call_system_proc_intern(list,pd,paras,forceresdef);
    end;

  function THLCGObj.g_call_system_proc(list: TAsmList; pd: TProcDef; const paras: array of PCGPara; forceresdef: TDef): TCGPara;
    begin
      { separate non-virtual routine to make it clear that the routine to
        override, if any, is g_call_system_proc_intern (and that none of
        the g_call_system_proc variants should be made virtual) }
      pd.init_paraloc_info(callerside);
      if systemunit<>CurrentModule.GlobalSymTable then
        CurrentModule.addimportedsym(pd.procsym);
      result:=g_call_system_proc_intern(list,pd,paras,forceresdef);
    end;

  function THLCGObj.g_call_system_proc_intern(list: TAsmList; pd: TProcDef; const paras: array of PCGPara; forceresdef: TDef): TCGPara;
    begin
      allocallcpuregisters(list);
      result:=a_call_name(list,pd,pd.mangledname,paras,forceresdef,false);
      deallocallcpuregisters(list);
    end;



end.
