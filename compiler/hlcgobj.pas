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
       CPUBase,CGBase,CGUtils,ParaBase,
       AAsmBase,AAsmTAI,AAsmData,AAsmCPU,
       SymConst,SymBase,SymType,SymSym,SymDef,
       Node,NUtils,
       TGObj
       ;

    type
       TSubsetLoadOpt = (SL_REG,SL_REGNOSRCMASK,SL_SETZERO,SL_SETMAX);

       PReplaceRegRec = ^TReplaceRegRec;
       TReplaceRegRec = record
         Old, New: TRegister;
         OldHi, NewHi: TRegister;
         ResSym: TSym;
         { moved sym }
         Sym : TAbstractNormalVarSym;
       end;

       { thlcgobj methods that may have to be overridden by non-descendants }
       THLCGObjHelpers = class
         class procedure Gen_Proc_Symbol(List:TAsmList);virtual;
         { queue the code/data generated for a procedure for writing out to
           the assembler/object file }
         class procedure Record_Generated_Code_For_ProcDef(PD: TProcDef; Code, Data: TAsmList); virtual;
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
        FPHLCGObjHelper: THLCGObjHelpersClass;
       public
          {************************************************}
          {                 basic routines                 }
          constructor Create; virtual;
          constructor Create(HLCGObjHelpers: THLCGObjHelpersClass);

          {# Initialize the register allocators needed for the codegenerator.}
          procedure Init_Register_Allocators;virtual;
          {# Clean up the register allocators needed for the codegenerator.}
          procedure Done_Register_Allocators;virtual;
          {# Set whether live_start or live_end should be updated when allocating registers, needed when e.g. generating initcode after the rest of the code. }
          procedure Set_RegAlloc_Live_Range_Direction(Dir: TRADirection);virtual;
          {# Gets a register suitable to do integer operations on.}
          function GetIntRegister(List:TAsmList;Size:TDef):TRegister;virtual;
          {# Gets a register suitable to do integer operations on.}
          function GetAddressRegister(List:TAsmList;Size:TDef):TRegister;virtual;
          function GetFPURegister(List:TAsmList;Size:TDef):TRegister;virtual;
          { warning: only works correctly for fpu types currently }
          function GetMMRegister(List:TAsmList;Size:TDef):TRegister;virtual;
          function GetFlagRegister(List:TAsmList;Size:TDef):TRegister;virtual;
          function GetTempRegister(List:TAsmList;Size:TDef):TRegister;virtual;
          function GetRegisterForDef(List: TAsmList;Size:TDef):TRegister;virtual;
          {Does the generic cg need SIMD registers, like getmmxregister? Or should
           the cpu specific child cg object have such a method?}

          function  Uses_Registers(RT:TRegisterType):Boolean; inline;
          {# Get a specific register.}
          procedure GetCPURegister(List:TAsmList;R:TRegister);virtual;
          procedure UngetCPURegister(List:TAsmList;R:TRegister);virtual;
          {# Get multiple registers specified.}
          procedure AllocCPURegisters(List:TAsmList;RT:TRegisterType;const R:TCPURegisterSet);virtual;
          {# Free multiple registers specified.}
          procedure DeallocCPURegisters(List:TAsmList;RT:TRegisterType;const R:TCPURegisterSet);virtual;

          procedure AllocAllCPURegisters(List:TAsmList);virtual;
          procedure DeallocAllCPURegisters(List:TAsmList);virtual;

          procedure Do_Register_Allocation(List:TAsmList;HeaderTAI:TAI); inline;
          procedure Translate_Register(var Reg : TRegister); inline;

          {# Returns the kind of register this type should be loaded in (it does not
             check whether this is actually possible, but if it's loaded in a register
             by the compiler for any purpose other than parameter passing/function
             result loading, this is the register type used) }
          class function Def2RegTyp(Def: TDef): TRegisterType; virtual;

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
          procedure Reference_Reset_Base(var Ref: TReference; RegSize: TDef; Reg: TRegister; Offset: LongInt; TempPos: TRefTempPos; Alignment: LongInt; Volatility: TVolatilitySet); virtual;

          {# Emit a label to the instruction stream. }
          procedure A_Label(List : TAsmList;L : TAsmLabel); inline;
          {# Emit a label that can be a target of a Pascal goto statement to the instruction stream. }
          procedure A_Label_Pascal_Goto_Target(List : TAsmList;L : TAsmLabel); inline;

          {# Allocates register r by inserting a pai_realloc record }
          procedure A_Reg_Alloc(List : TAsmList;R : TRegister); inline;
          {# Deallocates register r by inserting a pa_regdealloc record}
          procedure A_Reg_Dealloc(List : TAsmList;R : TRegister); inline;
          { Synchronize register, make sure it is still valid }
          procedure A_Reg_Sync(List : TAsmList;R : TRegister); inline;

          {# Pass a parameter, which is located in a register, to a routine.

             This routine should push/send the parameter to the routine, as
             required by the specific processor ABI and routine modifiers.
             It must generate register allocation information for the cgpara in
             case it consists of cpuregisters.

             @param(size size of the operand in the register)
             @param(r register source of the operand)
             @param(cgpara where the parameter will be stored)
          }
          procedure A_Load_Reg_CGPara(List : TAsmList;Size : TDef;R : TRegister;const CGPara : TCGPara);virtual;
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
          procedure A_Load_Const_CGPara(List : TAsmList;ToSize : TDef;A : TCGInt;const CGPara : TCGPara);virtual;
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
          procedure A_Load_Ref_CGPara(List : TAsmList;Size : TDef;const R : TReference;const CGPara : TCGPara);virtual;
          {# Pass the value of a parameter, which can be located either in a register or memory location,
             to a routine.

             A generic version is provided.

             @param(l location of the operand to send)
             @param(nr parameter number (starting from one) of routine (from left to right))
             @param(cgpara where the parameter will be stored)
          }
          procedure A_Load_Loc_CGPara(List : TAsmList;Size : TDef; const L : TLocation;const CGPara : TCGPara);virtual;
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
          procedure A_LoadAddr_Ref_CGPara(List : TAsmList;FromSize : TDef;const R : TReference;const CGPara : TCGPara);virtual;
          {# Pass an undefined value as a parameter to a routine.
             A generic version is provided and passes the 0/nil value
             if the parameter's location is not a register.
          }
          procedure A_Load_Undefined_CGPara(List : TAsmList;Size : TDef;const CGPara : TCGPara);virtual;

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
          function A_Call_Name(List : TAsmList;PD : TProcDef;const S : TSymStr; const Paras: array of PCGPara; ForceResDef: TDef; Weak: Boolean): TCGPara;virtual;abstract;
          function A_Call_Reg(List : TAsmList;PD : TAbstractProcDef;Reg : TRegister; const Paras: array of PCGPara): TCGPara;virtual;abstract;
          { same as a_call_name, might be overridden on certain architectures to emit
            static calls without usage of a got trampoline }
          function A_Call_Name_Static(List : TAsmList;PD : TProcDef;const S : TSymStr; const Paras: array of PCGPara; ForceResDef: TDef): TCGPara;virtual;
          { same as a_call_name, might be overridden on certain architectures to emit
            special static calls for inherited methods }
          function A_Call_Name_Inherited(List : TAsmList;PD : TProcDef;const S : TSymStr; const Paras: array of PCGPara): TCGPara;virtual;

          { move instructions }
          procedure A_Load_Const_Reg(List : TAsmList;ToSize : TDef;A : TCGInt;Register : TRegister);virtual;abstract;
          procedure A_Load_Const_Ref(List : TAsmList;ToSize : TDef;A : TCGInt;const Ref : TReference);virtual;
          procedure A_Load_Const_Loc(List : TAsmList;ToSize : TDef;A : TCGInt;const Loc : TLocation);virtual;
          procedure A_Load_Reg_Ref(List : TAsmList;FromSize, ToSize : TDef;Register : TRegister;const Ref : TReference);virtual;abstract;
          procedure A_Load_Reg_Ref_Unaligned(List : TAsmList;FromSize, ToSize : TDef;Register : TRegister;const Ref : TReference);virtual;
          procedure A_Load_Reg_Reg(List : TAsmList;FromSize, ToSize : TDef;Reg1,Reg2 : TRegister);virtual;abstract;
          procedure A_Load_Reg_Loc(List : TAsmList;FromSize, ToSize : TDef;Reg : TRegister;const Loc: TLocation);virtual;
          procedure A_Load_Ref_Reg(List : TAsmList;FromSize, ToSize : TDef;const Ref : TReference;Register : TRegister);virtual;abstract;
          procedure A_Load_Ref_Reg_Unaligned(List : TAsmList;FromSize, ToSize : TDef;const Ref : TReference;Register : TRegister);virtual;
          procedure A_Load_Ref_Ref(List : TAsmList;FromSize, ToSize : TDef;const SRef : TReference;const DRef : TReference);virtual;
          procedure A_Load_Loc_Reg(List : TAsmList;FromSize, ToSize : TDef; const Loc: TLocation; Reg : TRegister);virtual;
          procedure A_Load_Loc_Ref(List : TAsmList;FromSize, ToSize: TDef; const Loc: TLocation; const Ref : TReference);virtual;
          procedure A_Load_Loc_SubsetReg(List : TAsmList;FromSize, ToSubsetSize: TDef; const Loc: TLocation; const SReg : TSubsetRegister);virtual;
          procedure A_Load_Loc_SubsetRef(List : TAsmList;FromSize, ToSubsetSize: TDef; const Loc: TLocation; const SRef : TSubsetReference);virtual;
          procedure A_LoadAddr_Ref_Reg(List : TAsmList;FromSize, ToSize : TDef;const Ref : TReference;R : TRegister);virtual;abstract;

          { For subsetreg/ref, the def is the size of the packed element. The
            size of the register that holds the data is a tcgsize, and hence
            always must be an orddef of the corresponding size in practice }
          procedure A_Load_SubsetReg_Reg(List : TAsmList; SubsetSize, ToSize: TDef; const SReg: TSubsetRegister; DestReg: TRegister); virtual;
          procedure A_Load_Reg_SubsetReg(List : TAsmList; FromSize, ToSubsetSize: TDef; FromReg: TRegister; const SReg: TSubsetRegister); virtual;
          procedure A_Load_SubsetReg_SubsetReg(List: TAsmList; FromSubsetSize, ToSubsetSize : TDef; const FromSReg, ToSReg: TSubsetRegister); virtual;
          procedure A_Load_SubsetReg_Ref(List : TAsmList; FromSubsetSize, ToSize: TDef; const SReg: TSubsetRegister; const DestRef: TReference); virtual;
          procedure A_Load_Ref_SubsetReg(List : TAsmList; FromSize, ToSubsetSize: TDef; const FromRef: TReference; const SReg: TSubsetRegister); virtual;
          procedure A_Load_Const_SubsetReg(List: TAsmList; ToSubsetSize: TDef; A: TCGInt; const SReg: TSubsetRegister); virtual;
          procedure A_Load_SubsetReg_Loc(List: TAsmList; FromSubsetSize, ToSize: TDef; const SReg: TSubsetRegister; const Loc: TLocation); virtual;

          procedure A_Load_SubsetRef_Reg(List : TAsmList; FromSubsetSize, ToSize: TDef; const SRef: TSubsetReference; DestReg: TRegister); virtual;
          procedure A_Load_Reg_SubsetRef(List : TAsmList; FromSize, ToSubsetSize: TDef; FromReg: TRegister; const SRef: TSubsetReference); virtual;
          procedure A_Load_SubsetRef_SubsetRef(List: TAsmList; FromSubsetSize, ToSubsetSize : TDef; const FromSRef, ToSRef: TSubsetReference); virtual;
          procedure A_Load_SubsetRef_Ref(List : TAsmList; FromSubsetSize, ToSize: TDef; const SRef: TSubsetReference; const DestRef: TReference); virtual;
          procedure A_Load_Ref_SubsetRef(List : TAsmList; FromSize, ToSubsetSize: TDef; const FromRef: TReference; const SRef: TSubsetReference); virtual;
          procedure A_Load_Const_SubsetRef(List: TAsmList; ToSubsetSize: TDef; A: TCGInt; const SRef: TSubsetReference); virtual;
          procedure A_Load_SubsetRef_Loc(List: TAsmList; FromSubsetSize, ToSize: TDef; const SRef: TSubsetReference; const Loc: TLocation); virtual;
          procedure A_Load_SubsetRef_SubsetReg(List: TAsmList; FromSubsetSize, ToSubsetSize : TDef; const FromSRef: TSubsetReference; const ToSReg: TSubsetRegister); virtual;
          procedure A_Load_SubsetReg_SubsetRef(List: TAsmList; FromSubsetSize, ToSubsetSize : TDef; const FromSReg: TSubsetRegister; const ToSRef: TSubsetReference); virtual;

          { bit test instructions }
          procedure A_Bit_Test_Reg_Reg_Reg(List : TAsmList; BitNumberSize,ValueSize,DestSize: TDef;BitNumber,Value,DestReg: TRegister); virtual;
          procedure A_Bit_Test_Const_Ref_Reg(List: TAsmList; FromSize, DestSize: TDef; BitNumber: AInt; const Ref: TReference; DestReg: TRegister); virtual;
          procedure A_Bit_Test_Const_Reg_Reg(List: TAsmList; SetRegSize, DestSize: TDef; BitNumber: AInt; SetReg, DestReg: TRegister); virtual;
          procedure A_Bit_Test_Const_SubsetReg_Reg(List: TAsmList; FromSubsetSize, DestSize: TDef; BitNumber: AInt; const SetReg: TSubsetRegister; DestReg: TRegister); virtual;
          procedure A_Bit_Test_Reg_Ref_Reg(List: TAsmList; BitNumberSize, RefSize, DestSize: TDef; BitNumber: TRegister; const Ref: TReference; DestReg: TRegister); virtual;
          procedure A_Bit_Test_Reg_Loc_Reg(List: TAsmList; BitNumberSize, LocSize, DestSize: TDef; BitNumber: TRegister; const Loc: TLocation; DestReg: TRegister);virtual;
          procedure A_Bit_Test_Const_Loc_Reg(List: TAsmList; LocSize, DestSize: TDef; BitNumber: AInt; const Loc: TLocation; DestReg: TRegister);virtual;

          { bit set/clear instructions }
          procedure A_Bit_Set_Reg_Reg(List : TAsmList; DoSet: Boolean; BitNumberSize, DestSize: TDef; BitNumber,Dest: TRegister); virtual;
          procedure A_Bit_Set_Const_Ref(List: TAsmList; DoSet: Boolean;DestSize: TDef; BitNumber: TCGInt; const Ref: TReference); virtual;
          procedure A_Bit_Set_Const_Reg(List: TAsmList; DoSet: Boolean; DestSize: TDef; BitNumber: TCGInt; DestReg: TRegister); virtual;
          procedure A_Bit_Set_Const_SubsetReg(List: TAsmList; DoSet: Boolean; DestSize: TDef; BitNumber: TCGInt; const DestReg: TSubsetRegister); virtual;
          procedure A_Bit_Set_Reg_Ref(List: TAsmList; DoSet: Boolean; FromSize, ToSize: TDef; BitNumber: TRegister; const Ref: TReference); virtual;
          procedure A_Bit_Set_Reg_Loc(List: TAsmList; DoSet: Boolean; RegSize, ToSize: TDef; BitNumber: TRegister; const Loc: TLocation);virtual;
          procedure A_Bit_Set_Const_Loc(List: TAsmList; DoSet: Boolean; ToSize: TDef; BitNumber: TCGInt; const Loc: TLocation);virtual;

          function  Get_Call_Result_CGPara(PD: TAbstractProcDef; ForceResDef: TDef): TCGPara; virtual;
         protected
           procedure Get_SubsetRef_Load_Info(const SRef: TSubsetReference; out LoadSize: TOrdDef; out ExtraLoad: Boolean);
           procedure A_Load_SubsetRef_Regs_NoIndex(List: TAsmList; SubsetSize: TDef; LoadBitSize: Byte; const SRef: TSubsetReference; ValueReg, ExtraValueReg: TRegister); virtual;
           procedure A_Load_SubsetRef_Regs_Index(List: TAsmList; SubsetSize: TDef; LoadBitSize: Byte; const SRef: TSubsetReference; ValueReg: TRegister); virtual;

           procedure A_Load_RegConst_SubsetRef_Intern(List : TAsmList; FromSize, SubsetSize: TDef; FromReg: TRegister; const SRef: TSubsetReference; SlOpt: TSubsetLoadOpt); virtual;
           procedure A_Load_RegConst_SubsetReg_Intern(List : TAsmList; FromSize, SubsetSize: TDef; FromReg: TRegister; const SReg: TSubsetRegister; SlOpt: TSubsetLoadOpt); virtual;

           { return a subsetref that represents bit "bitnumber" in ref, if ref
             has the type "refdef". The subsetref must be addressable via
             (unsigned) 8 bit access, unless all the *_bit_* methods are
             overloaded and use something else. }
           function Get_Bit_Const_Ref_SRef(BitNumber: TCGInt; RefDef: TDef; const Ref: TReference): TSubsetReference;
           function Get_Bit_Const_Reg_SReg(SetRegSize: TDef; BitNumber: TCGInt; SetReg: TRegister): TSubsetRegister;
           function Get_Bit_Reg_Ref_SRef(List: TAsmList; BitNumberSize, RefSize: TDef; BitNumber: TRegister; const Ref: TReference): TSubsetReference;
         public

          { bit scan instructions (still need transformation to thlcgobj) }
          procedure A_Bit_Scan_Reg_Reg(List: TAsmList; Reverse,NotZero: Boolean; SrcSize, DstSize: TDef; Src, Dst: TRegister); virtual; abstract;

          { fpu move instructions }
          procedure A_LoadFPU_Reg_Reg(List: TAsmList; FromSize, ToSize: TDef; Reg1, Reg2: TRegister); virtual; abstract;
          procedure A_LoadFPU_Ref_Reg(List: TAsmList; FromSize, ToSize: TDef; const Ref: TReference; Reg: TRegister); virtual; abstract;
          procedure A_LoadFPU_Reg_Ref(List: TAsmList; FromSize, ToSize: TDef; Reg: TRegister; const Ref: TReference); virtual; abstract;
          procedure A_LoadFPU_Ref_Ref(List: TAsmList; FromSize, ToSize: TDef; const Ref1,Ref2: TReference);virtual;
          procedure A_LoadFPU_Loc_Reg(List: TAsmList; FromSize, ToSize: TDef; const Loc: TLocation; const Reg: TRegister);virtual;
          procedure A_LoadFPU_Loc_Ref(List: TAsmList; FromSize, ToSize: TDef; const Loc: TLocation; const Ref: TReference);virtual;
          procedure A_LoadFPU_Reg_Loc(List: TAsmList; FromSize, ToSize: TDef; const Reg: TRegister; const Loc: TLocation);virtual;
          procedure A_LoadFPU_Reg_CGPara(List : TAsmList;FromSize: TDef;const R : TRegister;const CGPara : TCGPara);virtual;
          procedure A_LoadFPU_Ref_CGPara(List : TAsmList;FromSize : TDef;const Ref : TReference;const CGPara : TCGPara);virtual;

          { vector register move instructions }
          procedure A_LoadMM_Reg_Reg(List: TAsmList; FromSize, ToSize: TDef;Reg1, Reg2: TRegister;Shuffle : PMMShuffle); virtual; abstract;
          procedure A_LoadMM_Ref_Reg(List: TAsmList; FromSize, ToSize: TDef;const Ref: TReference; Reg: TRegister;Shuffle : PMMShuffle); virtual; abstract;
          procedure A_LoadMM_Reg_Ref(List: TAsmList; FromSize, ToSize: TDef;Reg: TRegister; const Ref: TReference;Shuffle : PMMShuffle); virtual; abstract;
          procedure A_LoadMM_Ref_Ref(List: TAsmList; FromSize, ToSize: TDef; const FromRef, ToRef: TReference; Shuffle: PMMShuffle); virtual;
          { required for subsetreg/ref; still tcgsize rather than tdef because of reason mentioned above }
          procedure A_LoadMM_Loc_Reg(List: TAsmList; FromSize, ToSize: TDef; const Loc: TLocation; const Reg: TRegister; Shuffle : PMMShuffle);virtual;
          procedure A_LoadMM_Reg_Loc(List: TAsmList; FromSize, ToSize: TDef; const Reg: TRegister; const Loc: TLocation;Shuffle : PMMShuffle);virtual;
          procedure A_LoadMM_Loc_Ref(List: TAsmList; FromSize, ToSize: TDef; const Loc: TLocation; const Ref: TReference; Shuffle : PMMShuffle);virtual;
          procedure A_LoadMM_Reg_CGPara(List: TAsmList; FromSize: TDef; Reg: TRegister;const CGPara : TCGPara;Shuffle : PMMShuffle); virtual;
          procedure A_LoadMM_Ref_CGPara(List: TAsmList; FromSize: TDef; const Ref: TReference;const CGPara : TCGPara;Shuffle : PMMShuffle); virtual;
          procedure A_LoadMM_Loc_CGPara(List: TAsmList; FromSize: TDef; const Loc: TLocation; const CGPara : TCGPara;Shuffle : PMMShuffle); virtual;
          procedure A_OpMM_Reg_Reg(List: TAsmList; Op: TOpCG; Size : TDef;Src,Dst: TRegister;Shuffle : PMMShuffle); virtual; abstract;
          procedure A_OpMM_Ref_Reg(List: TAsmList; Op: TOpCG; Size : TDef;const Ref: TReference; Reg: TRegister;Shuffle : PMMShuffle); virtual;
          procedure A_OpMM_Loc_Reg(List: TAsmList; Op: TOpCG; Size : TDef;const Loc: TLocation; Reg: TRegister;Shuffle : PMMShuffle); virtual;
          procedure A_OpMM_Reg_Ref(List: TAsmList; Op: TOpCG; Size : TDef;Reg: TRegister;const Ref: TReference; Shuffle : PMMShuffle); virtual;
          { requires a temp that is interpreted in two different ways, and we
            don't have a way (yet) to tag a treference with tdef information so
            targets like LLVM can insert the necessary bitcast
          }
          procedure A_LoadMM_IntReg_Reg(List: TAsmList; FromSize, ToSize : TDef; IntReg, MMReg: TRegister; Shuffle: PMMShuffle); virtual; abstract;
          procedure A_LoadMM_Reg_IntReg(List: TAsmList; FromSize, ToSize : TDef; MMReg, IntReg: TRegister; Shuffle : PMMShuffle); virtual; abstract;

          { basic arithmetic operations }
          procedure A_Op_Const_Reg(List : TAsmList; Op: TOpCG; Size: TDef; A: TCGInt; Reg: TRegister); virtual; abstract;
          procedure A_Op_Const_Ref(List : TAsmList; Op: TOpCG; Size: TDef; A: TCGInt; const Ref: TReference); virtual;
          procedure A_Op_Const_SubsetReg(List : TAsmList; Op : TOpCG; Size, SubsetSize : TDef; A : TCGInt; const SReg: TSubsetRegister); virtual;
          procedure A_Op_Const_SubsetRef(List : TAsmList; Op : TOpCG; Size, SubsetSize : TDef; A : TCGInt; const SRef: TSubsetReference); virtual;
          procedure A_Op_Const_Loc(List : TAsmList; Op: TOpCG; Size: TDef; A: TCGInt; const Loc: TLocation);virtual;
          procedure A_Op_Reg_Reg(List : TAsmList; Op: TOpCG; Size: TDef; Reg1, Reg2: TRegister); virtual; abstract;
          procedure A_Op_Reg_Ref(List : TAsmList; Op: TOpCG; Size: TDef; Reg: TRegister; const Ref: TReference); virtual;
          procedure A_Op_Ref_Reg(List : TAsmList; Op: TOpCG; Size: TDef; const Ref: TReference; Reg: TRegister); virtual;
          procedure A_Op_Reg_SubsetReg(List: TAsmList; Op: TOpCG; OpSize, DestSubsetSize: TDef; Reg: TRegister; const SReg: TSubsetRegister); virtual;
          procedure A_Op_Reg_SubsetRef(List: TAsmList; Op: TOpCG; OpSize, DestSubsetSize: TDef; Reg: TRegister; const SRef: TSubsetReference); virtual;
          procedure A_Op_Reg_Loc(List : TAsmList; Op: TOpCG; Size: TDef; Reg: TRegister; const Loc: TLocation);virtual;
          procedure A_Op_Ref_Loc(List : TAsmList; Op: TOpCG; Size: TDef; const Ref: TReference; const Loc: TLocation);virtual;

          { trinary operations for processors that support them, 'emulated' }
          { on others. None with "ref" arguments since I don't think there  }
          { are any processors that support it (JM)                         }
          procedure A_Op_Const_Reg_Reg(List: TAsmList; Op: TOpCG; Size: TDef; A: TCGInt; Src, Dst: TRegister); virtual;
          procedure A_Op_Reg_Reg_Reg(List: TAsmList; Op: TOpCG; Size: TDef; Src1, Src2, Dst: TRegister); virtual;
          procedure A_Op_Const_Reg_Reg_CheckOverflow(List: TAsmList; Op: TOpCG; Size: TDef; A: TCGInt; Src, Dst: TRegister;SetFlags : Boolean;var OVLoc : TLocation); virtual;
          procedure A_Op_Reg_Reg_Reg_CheckOverflow(List: TAsmList; Op: TOpCG; Size: TDef; Src1, Src2, Dst: TRegister;SetFlags : Boolean;var OVLoc : TLocation); virtual;

          { unary operations (not, neg) }
          procedure A_Op_Reg(List : TAsmList; Op: TOpCG; Size: TDef; Reg: TRegister); virtual;
          procedure A_Op_Ref(List : TAsmList; Op: TOpCG; Size: TDef; const Ref: TReference); virtual;
          procedure A_Op_SubsetReg(List: TAsmList; Op: TOpCG; DestSubsetSize: TDef; const SReg: TSubsetRegister); virtual;
          procedure A_Op_SubsetRef(List: TAsmList; Op: TOpCG; DestSubsetSize: TDef; const SRef: TSubsetReference); virtual;
          procedure A_Op_Loc(List : TAsmList; Op: TOpCG; Size: TDef;  const Loc: TLocation); virtual;

          {  comparison operations }
          procedure A_Cmp_Const_Reg_Label(List : TAsmList;Size : TDef;CmpOp : TOpCmp;A : TCGInt;Reg : TRegister;
            L : TAsmLabel);virtual;
          procedure A_Cmp_Const_Ref_Label(List : TAsmList;Size : TDef;CmpOp : TOpCmp;A : TCGInt;const Ref : TReference;
            L : TAsmLabel); virtual;
          procedure A_Cmp_Const_Loc_Label(List: TAsmList; Size: TDef;CmpOp: TOpCmp; A: TCGInt; const Loc: TLocation;
            L : TAsmLabel);virtual;
          procedure A_Cmp_Reg_Reg_Label(List : TAsmList;Size : TDef;CmpOp : TOpCmp;Reg1,Reg2 : TRegister;L : TAsmLabel); virtual; abstract;
          procedure A_Cmp_Ref_Reg_Label(List : TAsmList;Size : TDef;CmpOp : TOpCmp; const Ref: TReference; Reg : TRegister; L : TAsmLabel); virtual;
          procedure A_Cmp_Reg_Ref_Label(List : TAsmList;Size : TDef;CmpOp : TOpCmp;Reg : TRegister; const Ref: TReference; L : TAsmLabel); virtual;
          procedure A_Cmp_SubsetReg_Reg_Label(List: TAsmList; FromSubsetSize, CmpSize: TDef; CmpOp: TOpCmp; const SReg: TSubsetRegister; Reg: TRegister; L: TAsmLabel); virtual;
          procedure A_Cmp_SubsetRef_Reg_Label(List: TAsmList; FromSubsetSize, CmpSize: TDef; CmpOp: TOpCmp; const SRef: TSubsetReference; Reg: TRegister; L: TAsmLabel); virtual;

          procedure A_Cmp_Loc_Reg_Label(List : TAsmList;Size : TDef;CmpOp : TOpCmp; const Loc: TLocation; Reg : TRegister; L : TAsmLabel);virtual;
          procedure A_Cmp_Reg_Loc_Label(List : TAsmList;Size : TDef;CmpOp : TOpCmp; Reg: TRegister; const Loc: TLocation; L : TAsmLabel);
          procedure A_Cmp_Ref_Loc_Label(List: TAsmList; Size: TDef;CmpOp: TOpCmp; const Ref: TReference; const Loc: TLocation; L : TAsmLabel);virtual;

          procedure A_Jmp_Always(List : TAsmList;L: TAsmLabel); virtual;abstract;
          procedure A_Jmp_Always_Pascal_Goto(List : TAsmList;L: TAsmLabel);virtual;
{$ifdef cpuflags}
          procedure A_Jmp_Flags(List : TAsmList;const F : TResFlags;L: TAsmLabel); virtual; abstract;

          {# Depending on the value to check in the flags, either sets the register reg to one (if the flag is set)
             or zero (if the flag is cleared). The size parameter indicates the destination size register.
          }
          procedure G_Flags2Reg(List: TAsmList; Size: TDef; const F: TResFlags; Reg: TRegister); virtual; abstract;
          procedure G_Flags2Ref(List: TAsmList; Size: TDef; const F: TResFlags; const Ref:TReference); virtual; abstract;
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
          procedure Optimize_Op_Const(Size: TDef; var Op: TOpCG; var A : TCGInt);virtual;

          {#
              This routine is used in exception management nodes. It should
              save the exception reason currently in the reg. The
              save should be done either to a temp (pointed to by href).
              or on the stack (pushing the value on the stack).
           }
          procedure G_Exception_Reason_Save(List : TAsmList; FromSize, ToSize: TDef; Reg: TRegister; const HRef : TReference);virtual;

          {#
              This routine is used in exception management nodes. It should
              save the exception reason constant. The
              save should be done either to a temp (pointed to by href).
              or on the stack (pushing the value on the stack).

              The size of the value to save is OS_S32. The default version
              saves the exception reason to a temp. memory area.
           }
          procedure G_Exception_Reason_Save_Const(List: TAsmList; Size: TDef; A: TCGInt; const HRef: TReference);virtual;

          {#
              This routine is used in exception management nodes. It should
              load the exception reason to reg. The saved value
              should either be in the temp. area (pointed to by href , href should
              *NOT* be freed) or on the stack (the value should be popped).

              The size of the value to save is OS_S32. The default version
              saves the exception reason to a temp. memory area.
           }
          procedure G_Exception_Reason_Load(List : TAsmList; FromSize, ToSize: TDef; const HRef : TReference; Reg: TRegister);virtual;
          {#
              This routine is called when the current exception reason can be
              discarded. On platforms that use push/pop, it causes the current
              value to be popped. On other platforms it doesn't do anything
          }
          procedure G_Exception_Reason_Discard(List : TAsmList; Size: TDef; HRef: TReference); virtual;

          {#
              This routine is called after g_call_system_proc to a system proc,
              that might raise an exception. It is used on platforms, that need
              to manually check an 'exception raised' flag, like WebAssembly in
              branchful exceptions mode.
          }
          procedure G_Maybe_CheckForExceptions(List : TAsmList); virtual;

          {#
              Call when the current location should never be reached
          }
          procedure G_Unreachable(List: TAsmList); virtual;

          procedure G_Maybe_TestSelf(List : TAsmList; SelfType: TDef; Reg:TRegister);
//          procedure g_maybe_testvmt(list : TAsmList;reg:tregister;objdef:tobjectdef);
          {# This should emit the opcode to copy len bytes from the source
             to destination.

             It must be overridden for each new target processor.

             @param(source Source reference of copy)
             @param(dest Destination reference of copy)

          }
          procedure G_ConcatCopy(List : TAsmList;Size: TDef; const Source,Dest : TReference);virtual;
          {# This should emit the opcode to copy len bytes from the an unaligned source
             to destination.

             It must be overridden for each new target processor.

             @param(source Source reference of copy)
             @param(dest Destination reference of copy)

          }
          procedure G_ConcatCopy_Unaligned(List : TAsmList;Size: TDef; const Source,Dest : TReference);virtual;
          {# This should emit the opcode to a shortrstring from the source
             to destination.

             @param(source Source reference of copy)
             @param(dest Destination reference of copy)

          }
          procedure G_CopyShortString(List : TAsmList;const Source,Dest : TReference;StrDef:TStringDef);virtual;
          procedure G_CopyVariant(List : TAsmList;const Source,Dest : TReference;VarDef:TVariantDef);virtual;

          procedure G_IncrRefCount(List : TAsmList;T: TDef; const Ref: TReference);virtual;
          procedure G_Initialize(List : TAsmList;T : TDef;const Ref : TReference);virtual;
          procedure G_Finalize(List : TAsmList;T : TDef;const Ref : TReference);virtual;
          procedure G_Array_RTTI_Helper(List: TAsmList; T: TDef; const Ref: TReference; const HighLoc: TLocation;
            const Name: string);virtual;
         protected
          { helper called by g_incrrefcount, g_initialize, g_finalize and
            g_array_rtti_helper to determine whether the RTTI symbol representing
            t needs to be loaded using the indirect symbol }
          function Def_Needs_Indirect(T:TDef):Boolean;
         public

          {# Generates range checking code. It is to note
             that this routine does not need to be overridden,
             as it takes care of everything.

             @param(p Node which contains the value to check)
             @param(todef Type definition of node to range check)
          }
          procedure G_RangeCheck(List: TAsmList; const L:TLocation; FromDef,ToDef: TDef); virtual;

          {# Generates overflow checking code for a node }
          procedure G_OverflowCheck(List: TAsmList; const Loc:TLocation; Def:TDef); virtual; abstract;
          procedure G_OverflowCheck_Loc(List:TAsmList;const Loc:TLocation;Def:TDef;var OVLoc : TLocation);virtual; abstract;

          procedure G_CopyValuePara_OpenArray(List : TAsmList;const Ref:TReference;const LenLoc:TLocation;ArrDef: TArrayDef;DestReg:TRegister);virtual;
          procedure G_ReleaseValuePara_OpenArray(List : TAsmList;ArrDef: TArrayDef;const L:TLocation);virtual;

          {# Emits instruction for allocating @var(size) bytes at the stackpointer

             @param(size Number of bytes to allocate)
          }
          procedure G_StackPointer_Alloc(List : TAsmList;Size : LongInt);virtual; abstract;
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
          procedure G_Proc_Exit(List : TAsmList;ParaSize:LongInt;NoStackFrame:Boolean);virtual; abstract;

          procedure G_Intf_Wrapper(List: TAsmList; ProcDef: TProcDef; const LabelName: string; IOffset: LongInt);virtual; abstract;
          procedure G_Adjust_Self_Value(List:TAsmList;ProcDef: TProcDef;IOffset: AInt);virtual; abstract;

         protected
          procedure A_Jmp_External_Name(List: TAsmList; const ExternalName: TSymStr); virtual;
         public
          { generate a stub which only purpose is to pass control the given external method,
          setting up any additional environment before doing so (if required).

          The default implementation issues a jump instruction to the external name. }
          procedure G_External_Wrapper(List : TAsmList; ProcDef: TProcDef; const WrapperName, ExternalName: string; Global: Boolean); virtual;

         protected
          procedure G_AllocLoad_Reg_Reg(List: TAsmList; RegSize: TDef; const FromReg: TRegister; out ToReg: TRegister; RegTyp: TRegisterType);
         public
          { create "safe copy" of a tlocation that can be used later: all
            registers used in the tlocation are copied to new ones, so that
            even if the original ones change, things stay the same (except if
            the original location was already a register, then the register is
            kept). Must only be used on lvalue locations.
            It's intended as some kind of replacement for a_loadaddr_ref_reg()
            for targets without pointers. }
          procedure G_Reference_Loc(List: TAsmList; Def: TDef; const FromLoc: TLocation; out ToLoc: TLocation); virtual;

          { typecasts the pointer in reg to a new pointer. By default it does
            nothing, only required for type-aware platforms like LLVM.
            fromdef/todef are not typed as pointerdef, because they may also be
            a procvardef or classrefdef. Replaces reg with a new register if
            necessary }
          procedure G_PtrTypeCast_Reg(List: TAsmList; FromDef, ToDef: TDef; var Reg: TRegister); virtual;
          { same but for a treference (considers the reference itself, not the
            value stored at that place in memory). Replaces ref with a new
            reference if necessary. fromdef needs to be a pointerdef because
            it may have to be passed as fromdef to a_loadaddr_ref_reg, which
            needs the "pointeddef" of fromdef }
          procedure G_PtrTypeCast_Ref(List: TAsmList; FromDef, ToDef: TDef; var Ref: TReference); virtual;

          { update a reference pointing to the start address of a record/object/
            class (contents) so it refers to the indicated field }
          procedure G_Set_Addr_NonBitPacked_Field_Ref(List: TAsmList; RecDef: TAbstractRecordDef; Field: TFieldVarSym; var RecRef: TReference); virtual;

          { tell the code generator that while this register's contents may be
            undefined, it will be masked/cleaned up afterwards before its
            contents are used if that is the case.

            Needed for LLVM in case of e.g. a potential shift of more bits
            than the width of the register }
          procedure G_Undefined_Ok(List: TAsmList; Size: TDef; Reg: TRegister); virtual;
         protected
          { load a register/constant into a record field by name }
          procedure G_Setup_Load_Field_By_Name(List: TAsmList; RecDef: TRecordDef; const Name: TIDString; const RecRef: TReference; out FRef: TReference; out FieldDef: TDef);
         public
          procedure G_Load_Reg_Field_By_Name(List: TAsmList; RegSize: TDef; RecDef: TRecordDef; Reg: TRegister; const Name: TIDString; const RecRef: TReference);
          procedure G_Load_Const_Field_By_Name(List: TAsmList; RecDef: TRecordDef; A: TCGInt; const Name: TIDString; const RecRef: TReference);
          { laod a named field into a register }
          procedure G_Load_Field_Reg_By_Name(List: TAsmList; RecDef: TRecordDef; RegSize: TDef; const Name: TIDString; const RecRef: TReference; Reg: TRegister);
          { same as above, but allocates the register and determines the def
            based on the type of the field }
          procedure G_Force_Field_Reg_By_Name(List: TAsmList; RecDef: TRecordDef; const Name: TIDString; const RecRef: TReference; out RegDef: TDef; out Reg: TRegister);

          { routines migrated from ncgutil }

          procedure Location_Force_Reg(List:TAsmList;var L:TLocation;SourceType,DestType:TDef;MaybeConst:Boolean);virtual;
          procedure Location_Force_FPUReg(List:TAsmList;var L: TLocation;Size: TDef;MaybeConst:Boolean);virtual;
          procedure Location_Force_Mem(List:TAsmList;var L:TLocation;Size:TDef);virtual;
          procedure Location_Force_MMRegScalar(List:TAsmList;var L: TLocation;var Size:TDef;MaybeConst:Boolean);virtual;
//          procedure location_force_mmreg(list:TAsmList;var l: tlocation;size:tdef;maybeconst:boolean);virtual;abstract;

          { Retrieve the location of the data pointed to in location l, when the location is
            a register it is expected to contain the address of the data }
          procedure Location_Get_Data_Ref(List:TAsmList;Def: TDef; const L:TLocation;var Ref:TReference;LoadRef:Boolean; Alignment: LongInt);virtual;

          { if p is a boolean expression, turns p.location into a LOC_JUMP with
            jumps to generated true and false labels; otherwise internalerrors }
          procedure MakeToJumpBool(List: TAsmList; P: TNode);
          { same as above, but using predefined true/false labels instead of
            by generating new ones }
          procedure MakeToJumpBoolLabels(List: TAsmList; P: TNode; TrueLabel, FalseLabel: TAsmLabel);virtual;
          { if the result of n is a LOC_C(..)REGISTER, try to find the corresponding
            loadn and change its location to a new register (= SSA). In case reload
            is true, transfer the old to the new register                            }
          procedure Maybe_Change_Load_Node_Reg(List: TAsmList; var N: TNode; Reload: Boolean); virtual;
         private
          function Do_Replace_Node_Regs(var N: TNode; Para: Pointer): TForEachNodeResult; virtual;
         public

          procedure Gen_Proc_Symbol(List:TAsmList);
          procedure Gen_Proc_Symbol_End(List:TAsmList);virtual;
          procedure Handle_External_Proc(List: TAsmList; PD: TProcDef; const ImportName: TSymStr); virtual;

          procedure Gen_Initialize_Code(List:TAsmList);virtual;
          procedure Gen_Finalize_Code(List:TAsmList);virtual;

          procedure Gen_Entry_Code(List:TAsmList);virtual;
          procedure Gen_Exit_Code(List:TAsmList);virtual;
          procedure Gen_Nexus_Profile_Call(List:TAsmList; const HookName:TIDString);
          procedure Emit_Nexus_Profile_Descriptor;
          procedure Gen_Nexus_Profile_Module_Call(List:TAsmList;
            const HookName:TIDString);
          procedure Emit_Nexus_Profile_Module_Data;

         protected
          { helpers called by gen_initialize_code/gen_finalize_code }
          procedure InitTempVariables(List:TAsmList);virtual;
          procedure FinalizeTempVariables(List:TAsmList;ForFinalization:Boolean);virtual;
          procedure Initialize_RegVars(P:TObject;Arg:Pointer);virtual;
          { generates the code for decrementing the reference count of parameters }
          procedure Final_Paras(P:TObject;Arg:Pointer);
         public
          { helper called by gen_alloc_symtable }
          procedure VarSym_Set_LocAlloc(List: TAsmList; VS:TAbstractNormalVarSym); virtual;
          { helper called by gen_alloc_symtable }
          procedure ParaVarSym_Set_InitialLoc_To_ParaLoc(VS: TParaVarSym); virtual;

          procedure Gen_Load_Para_Value(List:TAsmList);virtual;
          { helpers called by gen_load_para_value }
          procedure G_CopyValueParas(P:TObject;Arg:Pointer);virtual;

          { allocate a local temp to serve as storage for a para/localsym }
          procedure GetLocal(List: TAsmList; Sym: TSym; Size: ASizeInt; Alignment: ShortInt; Def: TDef; out Ref : TReference);
          { the symbol is stored at this location from now on }
          procedure RecordNewSymLoc(List: TAsmList; Sym: TSym; Def: TDef; const Ref: TReference; Initial: Boolean); virtual;
         protected
          procedure Gen_LoadFPU_Loc_CGPara(List: TAsmList; Size: TDef; const L: TLocation;const CGPara: TCGPara;LocIntSize: LongInt);virtual;
          procedure Init_Paras(P:TObject;Arg:Pointer);
         protected
          { Some targets have to put "something" in the function result
            location if it's not initialised by the Pascal code, e.g.
            stack-based architectures. By default it does nothing }
          procedure Gen_Load_Uninitialized_Function_Result(List: TAsmList; PD: TProcDef; ResDef: TDef; const ResLoc: TCGPara);virtual;
          procedure Gen_Load_Loc_Function_Result(List: TAsmList; VarDef: TDef; const L: TLocation);virtual;
         public
          { load a tlocation into a cgpara }
          procedure Gen_Load_Loc_CGPara(List: TAsmList; VarDef: TDef; const L: TLocation; const CGPara: TCGPara);virtual;

          { load a cgpara into a tlocation }
          procedure Gen_Load_CGPara_Loc(List: TAsmList; VarDef: TDef; const Para: TCGPara; var DestLoc: TLocation; ReusePara: Boolean);virtual;

          { load the function return value into the ABI-defined function return location }
          procedure Gen_Load_Return_Value(List:TAsmList);virtual;

          { extras refactored from other units }
          procedure Gen_Stack_Check_Size_Para(List:TAsmList); virtual;
          procedure Gen_Stack_Check_Call(List:TAsmList); virtual;

          { queue the code/data generated for a procedure for writing out to
            the assembler/object file }
          procedure Record_Generated_Code_For_ProcDef(PD: TProcDef; Code, Data: TAsmList); virtual;

          { generate a call to a routine in the system unit }
          function G_Call_System_Proc(List: TAsmList; const ProcName: string; const Paras: array of PCGPara; ForceResDef: TDef): TCGPara;
          function G_Call_System_Proc(List: TAsmList; PD: TProcDef; const Paras: array of PCGPara; ForceResDef: TDef): TCGPara;
         protected
          function G_Call_System_Proc_Intern(List: TAsmList; PD: TProcDef; const Paras: array of PCGPara; ForceResDef: TDef): TCGPara; virtual;
         public


          { Generate code to exit an unwind-protected region. The default implementation
            produces a simple jump to destination label. }
          procedure G_Local_Unwind(List: TAsmList; L: TAsmLabel);virtual;abstract;

         strict protected
          FHLCGObjHelpers: THLCGObjHelpersClass;
         public
          property HLCGObjHelpers: THLCGObjHelpersClass write FHLCGObjHelpers;
       end;
     THLCGObjClass = class of THLCGObj;

     TCreateHLCGCodeGen = procedure(lcgobjhelper: THLCGObjHelpersClass);

    var
       {# Main high level code generator class }
       HLCG : THLCGObj;
       { class type of high level code generator class (also valid when hlcg is
         nil, in order to be able to call its virtual class methods) }
       CHLCGObj: THLCGObjClass;
       Create_HLCodeGen: TCreateHLCGCodeGen;

    procedure Destroy_HLCodeGen;

implementation

    uses
       Globals,Systems,
       FinPut,FModule,
       Verbose,DefUtil,ParaMgr,
       SymTable,
       NBas,NCon,NLd,NMem,
       NCGRTTI,pass_2,
       CGObj,CUtils,ProcInfo,AAsmCnst,
       NGenUtil,
{$ifdef x86}
       CGX86,
{$endif x86}
       NCGUtil;


    procedure Destroy_HLCodeGen;
      begin
        HLCG.Free;
        HLCG:=nil;
        Destroy_CodeGen;
      end;


    class procedure THLCGObjHelpers.Gen_Proc_Symbol(List: TAsmList);
      var
        FirstItem,
        Item: TCmdStrListItem;
        Global: Boolean;
      begin
        Item:=TCmdStrListItem(CurrentProcInfo.ProcDef.AliasNames.First);
        FirstItem:=Item;
        Global:=CurrentProcInfo.ProcDef.NeedsGlobalAsmSym;
        while Assigned(Item) do
          begin
            { Record emitted entry points, rather than declarations: generic
              templates can have assembler names without executable bodies. }
            if Global and (tf_supports_packages in TargetInfo.Flags) then
              CurrentModule.Add_Public_AsmSym(Item.Str,AB_GLOBAL,AT_FUNCTION);
            { alias procedure entry symbols via ".set" on Darwin, otherwise
              they can be interpreted as all different starting symbols of
              subsections and be reordered }
            if (Item<>FirstItem) and
               (TargetInfo.System in systems_darwin) then
              begin
                { the .set already defines the symbol, so can't emit a tai_symbol as that will redefine it }
                if Global then
                  begin
                    List.Concat(TAISymbolPair.Create(spk_set_global,Item.Str,FirstItem.Str));
                  end
                else
                  begin
                    List.Concat(TAISymbolPair.Create(spk_set,Item.Str,FirstItem.Str));
                  end;
              end
            else
              begin
                if Global then
                  List.Concat(TAISymbol.createname_global(Item.Str,AT_FUNCTION,0,CurrentProcInfo.ProcDef))
                else
                  List.Concat(TAISymbol.Createname_hidden(Item.Str,AT_FUNCTION,0,CurrentProcInfo.ProcDef));
                List.Concat(TAIFunctionName.Create(Item.Str));
              end;
            Item:=TCmdStrListItem(Item.Next);
          end;
        CurrentProcInfo.ProcDef.ProcStartTAI:=TAI(List.Last);
      end;

    class procedure THLCGObjHelpers.Record_Generated_Code_For_ProcDef(PD: TProcDef; Code, Data: TAsmList);
      var
        Alt: TAsmListType;
        ProcSection: TAISection;
      begin
        ProcSection:=nil;
        if not(po_assembler in PD.ProcOptions) then
          Alt:=al_procedures
        else
          Alt:=al_pure_assembler;
        { add the procedure to the al_procedures }
        maybe_new_object_file(CurrentAsmData.AsmLists[Alt]);
  {$ifdef symansistr}
        if PD.Section<>'' then
          ProcSection:=new_proc_section(CurrentAsmData.AsmLists[Alt],sec_user,Lower(PD.Section),GetProcAlign)
  {$else symansistr}
        if Assigned(PD.Section) then
          ProcSection:=new_proc_section(CurrentAsmData.AsmLists[Alt],sec_user,Lower(PD.Section^),GetProcAlign)
  {$endif symansistr}
        else
          ProcSection:=new_section(CurrentAsmData.AsmLists[Alt],sec_code,Lower(PD.MangledName),GetProcAlign);
        if Assigned(CurrentProcInfo) and (CurrentProcInfo.ProcDef=PD) then
          begin
            if not Assigned(ProcSection) then
              ProcSection:=TAISection(CurrentAsmData.AsmLists[Alt].Last);
            if Assigned(CurrentProcInfo.nexus_profile_section) then
              CurrentProcInfo.nexus_profile_section.AssociativeSection:=ProcSection;
          end;
        CurrentAsmData.AsmLists[Alt].ConcatList(Code);
        { save local data (castable) also in the same file }
        if Assigned(Data) and
           (not Data.Empty) then
          CurrentAsmData.AsmLists[Alt].ConcatList(Data);
      end;


  { thlcgobj }

  constructor THLCGObj.Create;
    begin
      if not Assigned(FPHLCGObjHelper) then
        FPHLCGObjHelper:=THLCGObjHelpers;
    end;

  constructor THLCGObj.Create(HLCGObjHelpers: THLCGObjHelpersClass);
    begin
      FPHLCGObjHelper:=HLCGObjHelpers;
      Create;
    end;

  procedure THLCGObj.Init_Register_Allocators;
    begin
      CG.Init_Register_Allocators;
    end;

  procedure THLCGObj.Done_Register_Allocators;
    begin
      CG.Done_Register_Allocators;
    end;

  procedure THLCGObj.Set_RegAlloc_Live_Range_Direction(Dir: TRADirection);
    begin
      CG.Set_RegAlloc_Live_Range_Direction(Dir);
    end;

  function THLCGObj.GetIntRegister(List: TAsmList; Size: TDef): TRegister;
    begin
      Result:=CG.GetIntRegister(List,Def_CGSize(Size));
    end;

  function THLCGObj.GetAddressRegister(List: TAsmList; Size: TDef): TRegister;
    begin
      Result:=CG.GetAddressRegister(List);
    end;

  function THLCGObj.GetFPURegister(List: TAsmList; Size: TDef): TRegister;
    begin
      Result:=CG.GetFPURegister(List,Def_CGSize(Size));
    end;

  function THLCGObj.GetMMRegister(List: TAsmList; Size: TDef): TRegister;
    begin
      Result:=CG.GetMMRegister(List,Def_CGSize(Size));
    end;

  function THLCGObj.GetFlagRegister(List: TAsmList; Size: TDef): TRegister;
    begin
      Result:=CG.GetFlagRegister(List,Def_CGSize(Size));
    end;

  function THLCGObj.GetTempRegister(List: TAsmList; Size: TDef): TRegister;
    begin
      { doesn't make sense to try to translate this size to tcgsize, temps
        can have any size }
      Result:=CG.GetTempRegister(List);
    end;

    function THLCGObj.GetRegisterForDef(List: TAsmList; Size: TDef): TRegister;
      begin
        case Def2RegTyp(Size) of
          R_INTREGISTER:
            Result:=GetIntRegister(List,Size);
          R_ADDRESSREGISTER:
            Result:=GetAddressRegister(List,Size);
          R_FPUREGISTER:
            Result:=GetFPURegister(List,Size);
          R_MMREGISTER:
            Result:=GetMMRegister(List,Size);
          else
            InternalError(2010122901);
        end;
      end;

  function THLCGObj.Uses_Registers(RT: TRegisterType): Boolean;
    begin
       Result:=CG.Uses_Registers(RT);
    end;

  procedure THLCGObj.GetCPURegister(List: TAsmList; R: TRegister);
    begin
      CG.GetCPURegister(List,R);
    end;

  procedure THLCGObj.UngetCPURegister(List: TAsmList; R: TRegister);
    begin
      CG.UngetCPURegister(List,R);
    end;

  procedure THLCGObj.AllocCPURegisters(List: TAsmList; RT: TRegisterType; const R: TCPURegisterSet);
    begin
      CG.AllocCPURegisters(List,RT,R);
    end;

  procedure THLCGObj.DeallocCPURegisters(List: TAsmList; RT: TRegisterType; const R: TCPURegisterSet);
    begin
      CG.DeallocCPURegisters(List,RT,R);
    end;

  procedure THLCGObj.AllocAllCPURegisters(List: TAsmList);
    begin
      CG.AllocAllCPURegisters(List);
    end;

  procedure THLCGObj.DeallocAllCPURegisters(List: TAsmList);
    begin
      CG.DeallocAllCPURegisters(List);
    end;

  procedure THLCGObj.Do_Register_Allocation(List: TAsmList; HeaderTAI: TAI);
    begin
      CG.Do_Register_Allocation(List,HeaderTAI);
    end;

  procedure THLCGObj.Translate_Register(var Reg: TRegister);
    begin
      CG.Translate_Register(Reg);
    end;

  class function THLCGObj.Def2RegTyp(Def: TDef): TRegisterType;
    begin
        case Def.Typ of
          EnumDef,
          OrdDef,
          RecordDef,
          SetDef:
            Result:=R_INTREGISTER;
          ProcVarDef:

            { getaddressregister cannot handle if multiple registers
              are required for a single element }
            if Is_MethodPointer(Def) then
              Result:=R_INTREGISTER
            else

              Result:=R_ADDRESSREGISTER;
          StringDef,
          PointerDef,
          ClassRefDef,
          ObjectDef,
          ProcDef,
          FormalDef:
            Result:=R_ADDRESSREGISTER;
          ArrayDef:
            if TArrayDef(Def).Is_HWVector then
              Result:=R_MMREGISTER
            else if TStoredDef(Def).Is_IntRegable then
              Result:=R_INTREGISTER
            else
              Result:=R_ADDRESSREGISTER;
          FloatDef:
            if Use_VectorFPU(Def) then
              Result:=R_MMREGISTER
            else
              Result:=R_FPUREGISTER;
          FileDef,
          VariantDef,
          ForwardDef,
          UndefinedDef:
            Result:=R_INVALIDREGISTER;
        else
          InternalError(2010120506);
        end;
    end;

  procedure THLCGObj.Reference_Reset_Base(var Ref: TReference; RegSize: TDef;
    Reg: TRegister; Offset: LongInt; TempPos: TRefTempPos; Alignment: LongInt; Volatility: TVolatilitySet);
    begin
      Reference_Reset(Ref,Alignment,Volatility);
      Ref.Base:=Reg;
      Ref.Offset:=Offset;
      Ref.TempPos:=TempPos;
    end;

  procedure THLCGObj.A_Label(List: TAsmList; L: TAsmLabel); inline;
    begin
      CG.A_Label(List,L);
    end;

  procedure THLCGObj.A_Label_Pascal_Goto_Target(List : TAsmList;L : TAsmLabel); inline;
    begin
      CG.A_Label_Pascal_Goto_Target(List,L);
    end;

  procedure THLCGObj.A_Reg_Alloc(List: TAsmList; R: TRegister);
    begin
      CG.A_Reg_Alloc(List,R);
    end;

  procedure THLCGObj.A_Reg_Dealloc(List: TAsmList; R: TRegister);
    begin
      CG.A_Reg_Dealloc(List,R);
    end;

  procedure THLCGObj.A_Reg_Sync(List: TAsmList; R: TRegister);
    begin
      CG.A_Reg_Sync(List,R);
    end;

  procedure THLCGObj.A_Load_Reg_CGPara(List: TAsmList; Size: TDef; R: TRegister; const CGPara: TCGPara);
    var
      Ref: TReference;
      TmpReg : TRegister;
    begin
      CGPara.Check_Simple_Location;
      ParaManager.AllocCGPara(List,CGPara);
      if CGPara.Location^.ShiftVal<0 then
        begin
          TmpReg:=GetIntRegister(List,CGPara.Location^.Def);
          A_Op_Const_Reg_Reg(List,OP_SHL,CGPara.Location^.Def,-CGPara.Location^.ShiftVal,R,TmpReg);
          R:=TmpReg;
        end;
      case CGPara.Location^.Loc of
         LOC_REGISTER,LOC_CREGISTER:
           A_Load_Reg_Reg(List,Size,CGPara.Location^.Def,R,CGPara.Location^.Register);
         LOC_REFERENCE,LOC_CREFERENCE:
           begin
              Reference_Reset_Base(Ref,VoidStackPointerType,CGPara.Location^.Reference.Index,CGPara.Location^.Reference.Offset,CTempPosInvalid,CGPara.Alignment,[]);
              A_Load_Reg_Ref(List,Size,CGPara.Location^.Def,R,Ref);
           end;
         LOC_MMREGISTER,LOC_CMMREGISTER:
           A_LoadMM_IntReg_Reg(List,Size,CGPara.Location^.Def,R,CGPara.Location^.Register,MMS_MoveScalar);
         LOC_FPUREGISTER,LOC_CFPUREGISTER:
           begin
             TG.GetHLTemp(List,Size,Size.Size,tt_normal,Ref);
             A_Load_Reg_Ref(List,Size,CGPara.Location^.Def,R,Ref);
             A_LoadFPU_Ref_CGPara(List,CGPara.Location^.Def,Ref,CGPara);
             TG.UngetTemp(List,Ref);
           end
         else
           InternalError(2010120415);
      end;
    end;

  procedure THLCGObj.A_Load_Const_CGPara(List: TAsmList; ToSize: TDef; A: TCGInt; const CGPara: TCGPara);
    var
       Ref : TReference;
    begin
       CGPara.Check_Simple_Location;
       ParaManager.AllocCGPara(List,CGPara);
      if CGPara.Location^.ShiftVal<0 then
        A:=A shl -CGPara.Location^.ShiftVal;
       case CGPara.Location^.Loc of
          LOC_REGISTER,LOC_CREGISTER:
            A_Load_Const_Reg(List,CGPara.Location^.Def,A,CGPara.Location^.Register);
          LOC_REFERENCE,LOC_CREFERENCE:
            begin
               Reference_Reset_Base(Ref,VoidStackPointerType,CGPara.Location^.Reference.Index,CGPara.Location^.Reference.Offset,CTempPosInvalid,CGPara.Alignment,[]);
               A_Load_Const_Ref(List,CGPara.Location^.Def,A,Ref);
            end
          else
            InternalError(2010120416);
       end;
    end;

  procedure THLCGObj.A_Load_Ref_CGPara(List: TAsmList; Size: TDef; const R: TReference; const CGPara: TCGPara);
    var
      TmpRef, Ref: TReference;
      TmpReg: TRegister;
      Location: PCGParaLocation;
      OrgSizeLeft,
      SizeLeft: TCGInt;
      RegHasValue: Boolean;
    begin
      Location:=CGPara.Location;
      TmpRef:=R;
      SizeLeft:=CGPara.IntSize;
      while Assigned(Location) do
        begin
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
                 if (Def_CGSize(Size)<>OS_NO) and
                    (Size.Size<=SizeOf(AInt)) then
                   begin
                     CGPara.Check_Simple_Location;
                     A_Load_Ref_Reg(List,Size,Location^.Def,TmpRef,Location^.Register);
                     if Location^.ShiftVal<0 then
                       A_Op_Const_Reg(List,OP_SHL,Location^.Def,-Location^.ShiftVal,Location^.Register);
                   end
                 { there's a lot more data left, and the current paraloc's
                   register is entirely filled with part of that data }
                 else if (SizeLeft>SizeOf(AInt)) then
                   begin
                     A_Load_Ref_Reg(List,Location^.Def,Location^.Def,TmpRef,Location^.Register);
                   end
                 { we're at the end of the data, and it can be loaded into
                   the current location's register with a single regular
                   load }
                 else if SizeLeft in [1,2,4,8] then
                   begin
                     { don't use cgsize_orddef(int_cgsize(sizeleft)) as fromdef,
                       because that may be larger than location^.register in
                       case of padding at the end of a record }
                     A_Load_Ref_Reg(List,Location^.Def,Location^.Def,TmpRef,Location^.Register);
                     if Location^.ShiftVal<0 then
                       A_Op_Const_Reg(List,OP_SHL,Location^.Def,-Location^.ShiftVal,Location^.Register);
                   end
                 { we're at the end of the data, and we need multiple loads
                   to get it in the register because it's an irregular size }
                 else
                   begin
                     { should be the last part }
                     if Assigned(Location^.Next) then
                       InternalError(2010052902);
                     { load the value piecewise to get it into the register }
                     OrgSizeLeft:=SizeLeft;
                     RegHasValue:=False;
{$if defined(cpu64bitalu) or defined(cpuhighleveltarget)}
                     if SizeLeft>=4 then
                       begin
                         A_Load_Ref_Reg(List,U32IntType,Location^.Def,TmpRef,Location^.Register);
                         Dec(SizeLeft,4);
                         if TargetInfo.Endian=endian_big then
                           A_Op_Const_Reg(List,OP_SHL,Location^.Def,SizeLeft*8,Location^.Register);
                         Inc(TmpRef.Offset,4);
                         RegHasValue:=True;
                       end;
{$endif defined(cpu64bitalu) or defined(cpuhighleveltarget)}
                     if SizeLeft>=2 then
                       begin
                         TmpReg:=GetIntRegister(List,Location^.Def);
                         A_Load_Ref_Reg(List,U16IntType,Location^.Def,TmpRef,TmpReg);
                         Dec(SizeLeft,2);
                         if RegHasValue then
                           begin
                             if TargetInfo.Endian=endian_big then
                               A_Op_Const_Reg(List,OP_SHL,Location^.Def,SizeLeft*8,TmpReg)
                             else
                               A_Op_Const_Reg(List,OP_SHL,Location^.Def,(OrgSizeLeft-(SizeLeft+2))*8,TmpReg);
                             A_Op_Reg_Reg(List,OP_OR,Location^.Def,TmpReg,Location^.Register);
                           end
                         else
                           begin
                             if TargetInfo.Endian=endian_big then
                               A_Op_Const_Reg_Reg(List,OP_SHL,Location^.Def,SizeLeft*8,TmpReg,Location^.Register)
                             else
                               A_Load_Reg_Reg(List,Location^.Def,Location^.Def,TmpReg,Location^.Register);
                           end;
                         Inc(TmpRef.Offset,2);
                         RegHasValue:=True;
                       end;
                     if SizeLeft=1 then
                       begin
                         TmpReg:=GetIntRegister(List,Location^.Def);
                         A_Load_Ref_Reg(List,U8IntType,Location^.Def,TmpRef,TmpReg);
                         Dec(SizeLeft,1);
                         if RegHasValue then
                           begin
                             if TargetInfo.Endian=endian_little then
                               A_Op_Const_Reg(List,OP_SHL,Location^.Def,(OrgSizeLeft-(SizeLeft+1))*8,TmpReg);
                             A_Op_Reg_Reg(List,OP_OR,Location^.Def,TmpReg,Location^.Register)
                           end
                         else
                           A_Load_Reg_Reg(List,Location^.Def,Location^.Def,TmpReg,Location^.Register);
                         Inc(TmpRef.Offset);
                       end;
                     if Location^.ShiftVal<0 then
                       A_Op_Const_Reg(List,OP_SHL,Location^.Def,-Location^.ShiftVal,Location^.Register);
                     { the loop will already adjust the offset and sizeleft }
                     Dec(TmpRef.Offset,OrgSizeLeft);
                     SizeLeft:=OrgSizeLeft;
                   end;
              end;
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                 if Assigned(Location^.Next) then
                   InternalError(2017073001);
                 Reference_Reset_Base(Ref,VoidStackPointerType,Location^.Reference.Index,Location^.Reference.Offset,CTempPosInvalid,NewAlignment(CGPara.Alignment,CGPara.IntSize-SizeLeft),[]);
                 if (Def_CGSize(Size)<>OS_NO) and
                    (Size.Size=SizeLeft) and
                    (SizeLeft<=SizeOf(AInt)) then
                   A_Load_Ref_Ref(List,Size,Location^.Def,TmpRef,Ref)
                 else
                   { use concatcopy, because the parameter can be larger than }
                   { what the OS_* constants can handle                       }
                   G_ConcatCopy(List,Location^.Def,TmpRef,Ref);
              end;
            LOC_MMREGISTER,LOC_CMMREGISTER:
              begin
                 case Location^.Size of
                   OS_F32,
                   OS_F64,
                   OS_F128:
                     A_LoadMM_Ref_Reg(List,Location^.Def,Location^.Def,TmpRef,Location^.Register,MMS_MoveScalar);
                   OS_M8..OS_M128:
                     A_LoadMM_Ref_Reg(List,Location^.Def,Location^.Def,TmpRef,Location^.Register,nil);
                   else
                     InternalError(2010053103);
                 end;
              end
            else
              InternalError(2014032101);
          end;
          Inc(TmpRef.Offset,TCgSize2Size[Location^.Size]);
          Dec(SizeLeft,TCgSize2Size[Location^.Size]);
          Location:=Location^.Next;
        end;
    end;


  procedure THLCGObj.A_Load_Loc_CGPara(List: TAsmList; Size: TDef; const L: TLocation; const CGPara: TCGPara);
    begin
      case L.Loc of
        LOC_REGISTER,
        LOC_CREGISTER :
          A_Load_Reg_CGPara(List,Size,L.Register,CGPara);
        LOC_CONSTANT :
          A_Load_Const_CGPara(List,Size,L.Value,CGPara);
        LOC_CREFERENCE,
        LOC_REFERENCE :
          A_Load_Ref_CGPara(List,Size,L.Reference,CGPara);
        else
          InternalError(2010120419);
      end;
    end;

  procedure THLCGObj.A_LoadAddr_Ref_CGPara(List: TAsmList; FromSize: TDef; const R: TReference; const CGPara: TCGPara);
    var
       HR : TRegister;
    begin
       CGPara.Check_Simple_Location;
       if CGPara.Location^.Loc in [LOC_CREGISTER,LOC_REGISTER] then
         begin
           ParaManager.AllocParaLoc(List,CGPara.Location);
           A_LoadAddr_Ref_Reg(List,FromSize,CGPara.Location^.Def,R,CGPara.Location^.Register)
         end
       else
         begin
           HR:=GetAddressRegister(List,CGPara.Def);
           A_LoadAddr_Ref_Reg(List,FromSize,CGPara.Location^.Def,R,HR);
           A_Load_Reg_CGPara(List,CGPara.Def,HR,CGPara);
         end;
    end;

  procedure THLCGObj.A_Load_Undefined_CGPara(List: TAsmList; Size: TDef; const CGPara: TCGPara);
    begin
      if not (CGPara.Location^.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
        A_Load_Const_CGPara(List,Size,0,CGPara);
    end;

  function THLCGObj.A_Call_Name_Static(List: TAsmList; PD: TProcDef; const S: TSymStr; const Paras: array of PCGPara; ForceResDef: TDef): TCGPara;
    begin
      Result:=A_Call_Name(List,PD,S,Paras,ForceResDef,False);
    end;

  function THLCGObj.A_Call_Name_Inherited(List: TAsmList; PD: TProcDef; const S: TSymStr; const Paras: array of PCGPara): TCGPara;
    begin
      Result:=A_Call_Name(List,PD,S,Paras,nil,False);
    end;

  procedure THLCGObj.A_Load_Const_Ref(List: TAsmList; ToSize: TDef; A: TCGInt; const Ref: TReference);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetIntRegister(List,ToSize);
      A_Load_Const_Reg(List,ToSize,A,TmpReg);
      A_Load_Reg_Ref(List,ToSize,ToSize,TmpReg,Ref);
    end;

  procedure THLCGObj.A_Load_Const_Loc(List: TAsmList; ToSize: TDef; A: TCGInt; const Loc: TLocation);
    begin
      case Loc.Loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          A_Load_Const_Ref(List,ToSize,A,Loc.Reference);
        LOC_REGISTER,LOC_CREGISTER:
          A_Load_Const_Reg(List,ToSize,A,Loc.Register);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          A_Load_Const_SubsetReg(List,ToSize,A,Loc.SReg);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          A_Load_Const_SubsetRef(List,ToSize,A,Loc.SRef);
        else
          InternalError(2010120401);
      end;
    end;

  procedure THLCGObj.A_Load_Reg_Ref_Unaligned(List: TAsmList; FromSize, ToSize: TDef; Register: TRegister; const Ref: TReference);
    begin
      A_Load_Reg_Ref(List,FromSize,ToSize,Register,Ref);
    end;

  procedure THLCGObj.A_Load_Reg_Loc(List: TAsmList; FromSize, ToSize: TDef; Reg: TRegister; const Loc: TLocation);
    begin
      case Loc.Loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          A_Load_Reg_Ref(List,FromSize,ToSize,Reg,Loc.Reference);
        LOC_REGISTER,LOC_CREGISTER:
          A_Load_Reg_Reg(List,FromSize,ToSize,Reg,Loc.Register);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          A_Load_Reg_SubsetReg(List,FromSize,ToSize,Reg,Loc.SReg);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          A_Load_Reg_SubsetRef(List,FromSize,ToSize,Reg,Loc.SRef);
        LOC_MMREGISTER,LOC_CMMREGISTER:
          A_LoadMM_IntReg_Reg(List,FromSize,ToSize,Reg,Loc.Register,MMS_MoveScalar);
        else
          InternalError(2010120402);
      end;
    end;

  procedure THLCGObj.A_Load_Ref_Reg_Unaligned(List: TAsmList; FromSize, ToSize: TDef; const Ref: TReference; Register: TRegister);
    begin
      A_Load_Ref_Reg(List,FromSize,ToSize,Ref,Register);
    end;

  procedure THLCGObj.A_Load_Ref_Ref(List: TAsmList; FromSize, ToSize: TDef; const SRef: TReference; const DRef: TReference);
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

  procedure THLCGObj.A_Load_Loc_Reg(List: TAsmList; FromSize, ToSize: TDef; const Loc: TLocation; Reg: TRegister);
    begin
      case Loc.Loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          A_Load_Ref_Reg(List,FromSize,ToSize,Loc.Reference,Reg);
        LOC_REGISTER,LOC_CREGISTER:
          A_Load_Reg_Reg(List,FromSize,ToSize,Loc.Register,Reg);
        LOC_CONSTANT:
          A_Load_Const_Reg(List,ToSize,Loc.Value,Reg);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          A_Load_SubsetReg_Reg(List,FromSize,ToSize,Loc.SReg,Reg);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          A_Load_SubsetRef_Reg(List,FromSize,ToSize,Loc.SRef,Reg);
        else
          InternalError(2010120201);
      end;
    end;

  procedure THLCGObj.A_Load_Loc_Ref(List: TAsmList; FromSize, ToSize: TDef; const Loc: TLocation; const Ref: TReference);
    begin
      case Loc.Loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          A_Load_Ref_Ref(List,FromSize,ToSize,Loc.Reference,Ref);
        LOC_REGISTER,LOC_CREGISTER:
          A_Load_Reg_Ref(List,FromSize,ToSize,Loc.Register,Ref);
        LOC_CONSTANT:
          A_Load_Const_Ref(List,ToSize,Loc.Value,Ref);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          A_Load_SubsetReg_Ref(List,FromSize,ToSize,Loc.SReg,Ref);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          A_Load_SubsetRef_Ref(List,FromSize,ToSize,Loc.SRef,Ref);
        else
          InternalError(2010120403);
      end;
    end;

  procedure THLCGObj.A_Load_Loc_SubsetReg(List: TAsmList; FromSize, ToSubsetSize: TDef; const Loc: TLocation; const SReg: TSubsetRegister);
    begin
      case Loc.Loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          A_Load_Ref_SubsetReg(List,FromSize,ToSubsetSize,Loc.Reference,SReg);
        LOC_REGISTER,LOC_CREGISTER:
          A_Load_Reg_SubsetReg(List,FromSize,ToSubsetSize,Loc.Register,SReg);
        LOC_CONSTANT:
          A_Load_Const_SubsetReg(List,ToSubsetSize,Loc.Value,SReg);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          A_Load_SubsetReg_SubsetReg(List,FromSize,ToSubsetSize,Loc.SReg,SReg);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          A_Load_SubsetRef_SubsetReg(List,FromSize,ToSubsetSize,Loc.SRef,SReg);
        else
          InternalError(2010120404);
      end;
    end;

  procedure THLCGObj.A_Load_Loc_SubsetRef(List: TAsmList; FromSize, ToSubsetSize: TDef; const Loc: TLocation; const SRef: TSubsetReference);
    begin
      case Loc.Loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          A_Load_Ref_SubsetRef(List,FromSize,ToSubsetSize,Loc.Reference,SRef);
        LOC_REGISTER,LOC_CREGISTER:
          A_Load_Reg_SubsetRef(List,FromSize,ToSubsetSize,Loc.Register,SRef);
        LOC_CONSTANT:
          A_Load_Const_SubsetRef(List,ToSubsetSize,Loc.Value,SRef);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          A_Load_SubsetReg_SubsetRef(List,FromSize,ToSubsetSize,Loc.SReg,SRef);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          A_Load_SubsetRef_SubsetRef(List,FromSize,ToSubsetSize,Loc.SRef,SRef);
        else
          InternalError(2010120405);
      end;
    end;

{$push}
{$r-,q-}

  procedure THLCGObj.A_Load_SubsetReg_Reg(List: TAsmList; SubsetSize, ToSize: TDef; const SReg: TSubsetRegister; DestReg: TRegister);

    function GetRegBitSize: Integer;
      begin
        case GetSubReg(SReg.SubsetReg) of
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
      SubsetRegDef: TOrdDef;
      BitMask: AWord;
      TmpReg,
      SubsetSizeReg: TRegister;
      StopBit: Byte;
    begin
      SubsetRegDef:=CGSize_OrdDef(SReg.SubsetRegSize);
      TmpReg:=GetIntRegister(List,SubsetRegDef);
      { insert shifts only if it changes bits being accessed later on }
      if (SReg.StartBit<>0) or
        (ToSize.Size*8>SReg.BitLen) then
        begin
          if Is_Signed(SubsetSize) then
            begin
              { sign extend in case the value has a bitsize mod 8 <> 0 }
              { both instructions will be optimized away if not        }
              A_Op_Const_Reg_Reg(List,OP_SHL,SubsetRegDef,(TCgSize2Size[SReg.SubsetRegSize]*8)-SReg.StartBit-SReg.BitLen,SReg.SubsetReg,TmpReg);
              A_Op_Const_Reg(List,OP_SAR,SubsetRegDef,(TCgSize2Size[SReg.SubsetRegSize]*8)-SReg.BitLen,TmpReg);
            end
          else
            begin
              A_Op_Const_Reg_Reg(List,OP_SHR,SubsetRegDef,SReg.StartBit,SReg.SubsetReg,TmpReg);
              StopBit:=SReg.StartBit+SReg.BitLen;
              { If stopbit = (tcgsize2size[sreg.subsetregsize] * 8), then an
                AND mask is unnecessary }
              if (StopBit < GetRegBitSize()) then
                begin
                  { on x86(64), 1 shl 32(64) = 1 instead of 0
                    use aword to prevent overflow with 1 shl 31 }
                  if (StopBit-SReg.StartBit<>AIntBits) then
                    BitMask:=(AWord(1) shl (StopBit-SReg.StartBit))-1
                  else
                    BitMask:=High(AWord);
                  A_Op_Const_Reg(List,OP_AND,SubsetRegDef,TCGInt(BitMask),TmpReg);
                end;
            end;
        end
      else
        A_Load_Reg_Reg(List,SubsetRegDef,SubsetRegDef,SReg.SubsetReg,TmpReg);
      SubsetSizeReg:=GetIntRegister(List,SubsetSize);
      A_Load_Reg_Reg(List,SubsetRegDef,SubsetSize,TmpReg,SubsetSizeReg);
      A_Load_Reg_Reg(List,SubsetSize,ToSize,SubsetSizeReg,DestReg);
    end;

  procedure THLCGObj.A_Load_Reg_SubsetReg(List: TAsmList; FromSize, ToSubsetSize: TDef; FromReg: TRegister; const SReg: TSubsetRegister);
    begin
      A_Load_RegConst_SubsetReg_Intern(List,FromSize,ToSubsetSize,FromReg,SReg,SL_REG);
    end;

  procedure THLCGObj.A_Load_SubsetReg_SubsetReg(List: TAsmList; FromSubsetSize, ToSubsetSize: TDef; const FromSReg, ToSReg: TSubsetRegister);
    var
      FromSubsetRegDef,
      ToSubsetRegDef: TOrdDef;
      TmpReg, TmpReg2: TRegister;
      BitMask: AWord;
      StopBit: Byte;
    begin
      if (FromSReg.BitLen>=ToSReg.BitLen) then
        begin
          FromSubsetRegDef:=CGSize_OrdDef(FromSReg.SubsetRegSize);
          ToSubsetRegDef:=CGSize_OrdDef(ToSReg.SubsetRegSize);
          if (FromSReg.StartBit<=ToSReg.StartBit) then
            begin
              { tosreg may be larger -> use its size to perform the shift }
              TmpReg:=GetIntRegister(List,ToSubsetRegDef);
              A_Load_Reg_Reg(List,FromSubsetRegDef,ToSubsetRegDef,FromSReg.SubsetReg,TmpReg);
              A_Op_Const_Reg(List,OP_SHL,ToSubsetRegDef,ToSReg.StartBit-FromSReg.StartBit,TmpReg)
            end
          else
            begin
              { fromsreg may be larger -> use its size to perform the shift }
              TmpReg:=GetIntRegister(List,FromSubsetRegDef);
              A_Op_Const_Reg_Reg(List,OP_SHR,FromSubsetRegDef,FromSReg.StartBit-ToSReg.StartBit,FromSReg.SubsetReg,TmpReg);
              TmpReg2:=GetIntRegister(List,ToSubsetRegDef);
              A_Load_Reg_Reg(List,FromSubsetRegDef,ToSubsetRegDef,TmpReg,TmpReg2);
              TmpReg:=TmpReg2;
            end;
          StopBit:=ToSReg.StartBit + ToSReg.BitLen;
          // on x86(64), 1 shl 32(64) = 1 instead of 0
          if (StopBit<>AIntBits) then
            BitMask:=not(((AWord(1) shl StopBit)-1) xor ((AWord(1) shl ToSReg.StartBit)-1))
           else
             BitMask:=(AWord(1) shl ToSReg.StartBit) - 1;
          A_Op_Const_Reg(List,OP_AND,ToSubsetRegDef,TCGInt(BitMask),ToSReg.SubsetReg);
          A_Op_Const_Reg(List,OP_AND,ToSubsetRegDef,TCGInt(not(BitMask)),TmpReg);
          A_Op_Reg_Reg(List,OP_OR,ToSubsetRegDef,TmpReg,ToSReg.SubsetReg);
        end
      else
        begin
          TmpReg:=GetIntRegister(List,ToSubsetSize);
          A_Load_SubsetReg_Reg(List,FromSubsetSize,ToSubsetSize,FromSReg,TmpReg);
          A_Load_Reg_SubsetReg(List,ToSubsetSize,ToSubsetSize,TmpReg,ToSReg);
        end;
    end;

  procedure THLCGObj.A_Load_SubsetReg_Ref(List: TAsmList; FromSubsetSize, ToSize: TDef; const SReg: TSubsetRegister; const DestRef: TReference);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetIntRegister(List,ToSize);
      A_Load_SubsetReg_Reg(List,FromSubsetSize,ToSize,SReg,TmpReg);
      A_Load_Reg_Ref(List,ToSize,ToSize,TmpReg,DestRef);
    end;

  procedure THLCGObj.A_Load_Ref_SubsetReg(List: TAsmList; FromSize, ToSubsetSize: TDef; const FromRef: TReference; const SReg: TSubsetRegister);
    var
      TmpReg: TRegister;
    begin
      TmpReg := GetIntRegister(List,ToSubsetSize);
      A_Load_Ref_Reg(List,FromSize,ToSubsetSize,FromRef,TmpReg);
      A_Load_Reg_SubsetReg(List,ToSubsetSize,ToSubsetSize,TmpReg,SReg);
    end;

  procedure THLCGObj.A_Load_Const_SubsetReg(List: TAsmList; ToSubsetSize: TDef; A: TCGInt; const SReg: TSubsetRegister);
    var
      SubsetRegDef: TOrdDef;
      BitMask: AWord;
      StopBit: Byte;
    begin
       SubsetRegDef:=CGSize_OrdDef(SReg.SubsetRegSize);
       StopBit:=SReg.StartBit+SReg.BitLen;
       // on x86(64), 1 shl 32(64) = 1 instead of 0
       if (StopBit<>AIntBits) then
         BitMask:=not(((AWord(1) shl StopBit)-1) xor ((AWord(1) shl SReg.StartBit)-1))
       else
         BitMask:=(AWord(1) shl SReg.StartBit)-1;
       if (((AWord(A) shl SReg.StartBit) and not BitMask)<>not BitMask) then
         A_Op_Const_Reg(List,OP_AND,SubsetRegDef,TCGInt(BitMask),SReg.SubsetReg);
       A_Op_Const_Reg(List,OP_OR,SubsetRegDef,TCGInt((AWord(A) shl SReg.StartBit) and not(BitMask)),SReg.SubsetReg);
    end;

  procedure THLCGObj.A_Load_SubsetReg_Loc(List: TAsmList; FromSubsetSize, ToSize: TDef; const SReg: TSubsetRegister; const Loc: TLocation);
    begin
      case Loc.Loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          A_Load_SubsetReg_Ref(List,FromSubsetSize,ToSize,SReg,Loc.Reference);
        LOC_REGISTER,LOC_CREGISTER:
          A_Load_SubsetReg_Reg(List,FromSubsetSize,ToSize,SReg,Loc.Register);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          A_Load_SubsetReg_SubsetReg(List,FromSubsetSize,ToSize,SReg,Loc.SReg);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          A_Load_SubsetReg_SubsetRef(List,FromSubsetSize,ToSize,SReg,Loc.SRef);
        else
          InternalError(2010120406);
      end;
    end;

  procedure THLCGObj.A_Load_SubsetRef_Reg(List: TAsmList; FromSubsetSize, ToSize: TDef; const SRef: TSubsetReference; DestReg: TRegister);
    var
      TmpRef: TReference;
      ValueReg,ExtraValueReg, TmpReg: TRegister;
      ToSReg: TSubsetRegister;
      LoadSize: TOrdDef;
      LoadBitSize: Byte;
      ExtraLoad: Boolean;
      TmpSRef: TSubsetReference;
    begin
      if SRef.BitLen>AIntBits then
        begin
          TmpSRef:=SRef;
          TmpSRef.BitLen:=AIntBits;
          ValueReg:=HLCG.GetIntRegister(List,ToSize);
          A_Load_SubsetRef_Reg(List,SIntType,ToSize,TmpSRef,ValueReg);
          TmpSRef.BitLen:=SRef.BitLen-AIntBits;
          Inc(TmpSRef.Ref.Offset,AIntBits div 8);
          ExtraValueReg:=HLCG.GetIntRegister(List,ToSize);
          A_Load_SubsetRef_Reg(List,SIntType,ToSize,TmpSRef,ExtraValueReg);
          { can't use a_load_reg_subsetreg to merge the results, as that one
            does not support sizes > AIntBits either }
          TmpReg:=HLCG.GetIntRegister(List,ToSize);
          if TargetInfo.Endian=endian_big then
            begin
              A_Op_Const_Reg_Reg(List,OP_SHL,ToSize,SRef.BitLen-AIntBits,ValueReg,TmpReg);
              if Is_Signed(FromSubsetSize) then
                begin
                  ValueReg:=TmpReg;
                  TmpReg:=HLCG.GetIntRegister(List,ToSize);
                  A_Op_Const_Reg_Reg(List,OP_AND,ToSize,(TCGInt(1) shl (SRef.BitLen-AIntBits))-1,ExtraValueReg,TmpReg);
                  ValueReg:=TmpReg;
                end
            end
          else
            begin
              A_Op_Const_Reg_Reg(List,OP_SHL,ToSize,AIntBits,ExtraValueReg,TmpReg);
              if Is_Signed(FromSubsetSize) then
                begin
                  ExtraValueReg:=HLCG.GetIntRegister(List,ToSize);
                  A_Op_Const_Reg_Reg(List,OP_AND,ToSize,(TCGInt(1) shl AIntBits)-1,ValueReg,ExtraValueReg);
                  ValueReg:=ExtraValueReg;
                end
            end;
          if Is_Signed(FromSubsetSize) then
            begin
              ExtraValueReg:=HLCG.GetIntRegister(List,ToSize);
              A_Op_Const_Reg_Reg(List,OP_AND,ToSize,(TCGInt(1) shl AIntBits)-1,ValueReg,ExtraValueReg);
              ValueReg:=ExtraValueReg;
            end;
          A_Op_Reg_Reg_Reg(List,OP_OR,ToSize,ValueReg,TmpReg,DestReg);
          Exit;
        end;

      Get_SubsetRef_Load_Info(SRef,LoadSize,ExtraLoad);
      LoadBitSize:=LoadSize.Size*8;

      { load the (first part) of the bit sequence }
      ValueReg:=GetIntRegister(List,ALUUIntType);
      A_Load_Ref_Reg(List,LoadSize,ALUUIntType,SRef.Ref,ValueReg);

      if not ExtraLoad then
        begin
          { everything is guaranteed to be in a single register of loadsize }
          if (SRef.BitIndexReg=NR_NO) then
            begin
              { use subsetreg routine, it may have been overridden with an optimized version }
              ToSReg.SubsetReg:=ValueReg;
              ToSReg.SubsetRegSize:=Def_CGSize(ALUUIntType);
              { subsetregs always count bits from right to left }
              if (TargetInfo.Endian=endian_big) then
                ToSReg.StartBit:=LoadBitSize-(SRef.StartBit+SRef.BitLen)
              else
                ToSReg.StartBit:=SRef.StartBit;
              ToSReg.BitLen:=SRef.BitLen;
              A_Load_SubsetReg_Reg(List,FromSubsetSize,ToSize,ToSReg,DestReg);
              Exit;
            end
          else
            begin
              if (SRef.StartBit<>0) then
                InternalError(2006081510);
              if (TargetInfo.Endian=endian_big) then
                begin
                  A_Op_Reg_Reg(List,OP_SHL,ALUUIntType,SRef.BitIndexReg,ValueReg);
                  if Is_Signed(FromSubsetSize) then
                    begin
                      { sign extend to entire register }
                      A_Op_Const_Reg(List,OP_SHL,ALUUIntType,AIntBits-LoadBitSize,ValueReg);
                      A_Op_Const_Reg(List,OP_SAR,ALUUIntType,AIntBits-SRef.BitLen,ValueReg);
                    end
                  else
                    A_Op_Const_Reg(List,OP_SHR,ALUUIntType,LoadBitSize-SRef.BitLen,ValueReg);
                end
              else
                begin
                  A_Op_Reg_Reg(List,OP_SHR,ALUUIntType,SRef.BitIndexReg,ValueReg);
                  if Is_Signed(FromSubsetSize) then
                    begin
                      A_Op_Const_Reg(List,OP_SHL,ALUUIntType,AIntBits-SRef.BitLen,ValueReg);
                      A_Op_Const_Reg(List,OP_SAR,ALUUIntType,AIntBits-SRef.BitLen,ValueReg);
                    end
                end;
              { mask other bits/sign extend }
              if not Is_Signed(FromSubsetSize) then
                A_Op_Const_Reg(List,OP_AND,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen)-1),ValueReg);
            end
        end
      else
        begin
          { load next value as well }
          ExtraValueReg:=GetIntRegister(List,ALUUIntType);

          if (SRef.BitIndexReg=NR_NO) then
            begin
              TmpRef:=SRef.Ref;
              Inc(TmpRef.Offset,LoadBitSize div 8);
              A_Load_Ref_Reg(List,LoadSize,ALUUIntType,TmpRef,ExtraValueReg);
              { can be overridden to optimize }
              A_Load_SubsetRef_Regs_NoIndex(List,FromSubsetSize,LoadBitSize,SRef,ValueReg,ExtraValueReg)
            end
          else
            begin
              if (SRef.StartBit<>0) then
                InternalError(2006080610);
              A_Load_SubsetRef_Regs_Index(List,FromSubsetSize,LoadBitSize,SRef,ValueReg);
            end;
        end;

      { store in destination }
{$ifndef cpuhighleveltarget}
      { avoid unnecessary sign extension and zeroing }
      ValueReg:=CG.MakeRegSize(List,ValueReg,OS_INT);
      DestReg:=CG.MakeRegSize(List,DestReg,OS_INT);
      CG.A_Load_Reg_Reg(List,OS_INT,OS_INT,ValueReg,DestReg);
      DestReg:=CG.MakeRegSize(List,DestReg,Def_CGSize(ToSize));
{$else}
      { can't juggle with register sizes, they are actually typed entities
        here }
      A_Load_Reg_Reg(List,ALUUIntType,ToSize,ValueReg,DestReg);
{$endif}
    end;

  procedure THLCGObj.A_Load_Reg_SubsetRef(List: TAsmList; FromSize, ToSubsetSize: TDef; FromReg: TRegister; const SRef: TSubsetReference);
    var
      TmpSRef: TSubsetReference;
      FromReg1: TRegister;
    begin
      if SRef.BitLen>AIntBits then
        begin
          if ((SRef.BitLen mod AIntBits)<>0) then
            InternalError(2019052901);
          TmpSRef:=SRef;
          TmpSRef.BitLen:=AIntBits;
          FromReg1:=HLCG.GetIntRegister(List,ALUUIntType);
          A_Load_Reg_Reg(List,FromSize,ALUUIntType,FromReg,FromReg1);
          if TargetInfo.Endian=endian_big then
            begin
              Inc(TmpSRef.Ref.Offset,SRef.BitLen-AIntBits);
            end;
          A_Load_Reg_SubsetRef(List,ALUUIntType,ALUUIntType,FromReg1,TmpSRef);
          if TargetInfo.Endian=endian_big then
            begin
              TmpSRef.Ref.Offset:=SRef.Ref.Offset;
            end
          else
            begin
              Inc(TmpSRef.Ref.Offset,AIntBits div 8);
            end;
          TmpSRef.BitLen:=SRef.BitLen-AIntBits;
          FromReg1:=HLCG.GetIntRegister(List,FromSize);
          HLCG.A_Op_Const_Reg_Reg(List,OP_SHR,FromSize,AIntBits,FromReg,FromReg1);
          A_Load_Reg_SubsetRef(List,FromSize,ToSubsetSize,FromReg1,TmpSRef);
          Exit;
        end;
      A_Load_RegConst_SubsetRef_Intern(List,FromSize,ToSubsetSize,FromReg,SRef,SL_REG);
    end;

  procedure THLCGObj.A_Load_SubsetRef_SubsetRef(List: TAsmList; FromSubsetSize, ToSubsetSize: TDef; const FromSRef, ToSRef: TSubsetReference);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetIntRegister(List,ToSubsetSize);
      A_Load_SubsetRef_Reg(List,FromSubsetSize,ToSubsetSize,FromSRef,TmpReg);
      A_Load_Reg_SubsetRef(List,ToSubsetSize,ToSubsetSize,TmpReg,ToSRef);
    end;

  procedure THLCGObj.A_Load_SubsetRef_Ref(List: TAsmList; FromSubsetSize, ToSize: TDef; const SRef: TSubsetReference; const DestRef: TReference);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetIntRegister(List,ToSize);
      A_Load_SubsetRef_Reg(List,FromSubsetSize,ToSize,SRef,TmpReg);
      A_Load_Reg_Ref(List,ToSize,ToSize,TmpReg,DestRef);
    end;

  procedure THLCGObj.A_Load_Ref_SubsetRef(List: TAsmList; FromSize, ToSubsetSize: TDef; const FromRef: TReference; const SRef: TSubsetReference);
    var
      TmpReg: TRegister;
    begin
      TmpReg := GetIntRegister(List,ToSubsetSize);
      A_Load_Ref_Reg(List,FromSize,ToSubsetSize,FromRef,TmpReg);
      A_Load_Reg_SubsetRef(List,ToSubsetSize,ToSubsetSize,TmpReg,SRef);
    end;

  procedure THLCGObj.A_Load_Const_SubsetRef(List: TAsmList; ToSubsetSize: TDef; A: TCGInt; const SRef: TSubsetReference);
    var
      TmpSRef: TSubsetReference;
      TmpReg: TRegister;
      SlOpt: TSubsetLoadOpt;
    begin
      if SRef.BitLen>AIntBits then
        begin
          if ((SRef.BitLen mod AIntBits)<>0) then
            InternalError(2019052902);
          TmpSRef:=SRef;
          TmpSRef.BitLen:=AIntBits;
          if TargetInfo.Endian=endian_big then
            begin
              Inc(TmpSRef.Ref.Offset,SRef.BitLen-AIntBits);
            end;
          A_Load_Const_SubsetRef(List,ToSubsetSize,AInt(A),TmpSRef);
          if TargetInfo.Endian=endian_big then
            begin
              TmpSRef.Ref.Offset:=SRef.Ref.Offset;
            end
          else
            begin
              Inc(TmpSRef.Ref.Offset,AIntBits div 8);
            end;
          TmpSRef.BitLen:=SRef.BitLen-AIntBits;
          A_Load_Const_SubsetRef(List,ToSubsetSize,A shr AIntBits,TmpSRef);
          Exit;
        end;
      { perform masking of the source value in advance }
      SlOpt:=SL_REGNOSRCMASK;
      if (SRef.BitLen<>AIntBits) then
        A:=TCGInt(AWord(A) and ((AWord(1) shl SRef.BitLen) -1));
      if (
          { broken x86 "x shl regbitsize = x" }
          ((SRef.BitLen<>AIntBits) and
           ((AWord(A) and ((AWord(1) shl SRef.BitLen)-1))=(AWord(1) shl SRef.BitLen)-1)) or
          ((SRef.BitLen=AIntBits) and
           (A=-1))
         ) then
        SlOpt:=SL_SETMAX
      else if (A=0) then
        SlOpt:=SL_SETZERO;
      if not(SlOpt in [SL_SETZERO,SL_SETMAX]) then
        begin
          TmpReg:=GetIntRegister(List,ToSubsetSize);
          A_Load_Const_Reg(List,ToSubsetSize,A,TmpReg);
        end
      else
        TmpReg:=NR_NO;
      A_Load_RegConst_SubsetRef_Intern(List,ToSubsetSize,ToSubsetSize,TmpReg,SRef,SlOpt);
    end;

  procedure THLCGObj.A_Load_SubsetRef_Loc(List: TAsmList; FromSubsetSize, ToSize: TDef; const SRef: TSubsetReference; const Loc: TLocation);
    begin
      case Loc.Loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          A_Load_SubsetRef_Ref(List,FromSubsetSize,ToSize,SRef,Loc.Reference);
        LOC_REGISTER,LOC_CREGISTER:
          A_Load_SubsetRef_Reg(List,FromSubsetSize,ToSize,SRef,Loc.Register);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          A_Load_SubsetRef_SubsetReg(List,FromSubsetSize,ToSize,SRef,Loc.SReg);
        LOC_SUBSETREF,LOC_CSUBSETREF:
          A_Load_SubsetRef_SubsetRef(List,FromSubsetSize,ToSize,SRef,Loc.SRef);
        else
          InternalError(2010120407);
      end;
    end;

  procedure THLCGObj.A_Load_SubsetRef_SubsetReg(List: TAsmList; FromSubsetSize, ToSubsetSize: TDef; const FromSRef: TSubsetReference; const ToSReg: TSubsetRegister);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetIntRegister(List,ToSubsetSize);
      A_Load_SubsetRef_Reg(List,FromSubsetSize,ToSubsetSize,FromSRef,TmpReg);
      A_Load_Reg_SubsetReg(List,ToSubsetSize,ToSubsetSize,TmpReg,ToSReg);
    end;

  procedure THLCGObj.A_Load_SubsetReg_SubsetRef(List: TAsmList; FromSubsetSize, ToSubsetSize: TDef; const FromSReg: TSubsetRegister; const ToSRef: TSubsetReference);
    var
      TmpReg: TRegister;
    begin
      TmpReg := GetIntRegister(List,ToSubsetSize);
      A_Load_SubsetReg_Reg(List,FromSubsetSize,ToSubsetSize,FromSReg,TmpReg);
      A_Load_Reg_SubsetRef(List,ToSubsetSize,ToSubsetSize,TmpReg,ToSRef);
    end;

  procedure THLCGObj.A_Bit_Test_Reg_Reg_Reg(List: TAsmList; BitNumberSize, ValueSize, DestSize: TDef; BitNumber, Value, DestReg: TRegister);
    var
      TmpValue: TRegister;
    begin
      TmpValue:=GetIntRegister(List,ValueSize);

      if (TargetInfo.Endian=endian_little) then
        begin
          { rotate value register "bitnumber" bits to the right }
          A_Op_Reg_Reg_Reg(List,OP_SHR,ValueSize,BitNumber,Value,TmpValue);
          { extract the bit we want }
          A_Op_Const_Reg(List,OP_AND,ValueSize,1,TmpValue);
        end
      else
        begin
          { highest (leftmost) bit = bit 0 -> shl bitnumber results in wanted }
          { bit in uppermost position, then move it to the lowest position    }
          { "and" is not necessary since combination of shl/shr will clear    }
          { all other bits                                                    }
          A_Op_Reg_Reg_Reg(List,OP_SHL,ValueSize,BitNumber,Value,TmpValue);
          A_Op_Const_Reg(List,OP_SHR,ValueSize,ValueSize.Size*8-1,TmpValue);
        end;
      A_Load_Reg_Reg(List,ValueSize,DestSize,TmpValue,DestReg);
    end;

  procedure THLCGObj.A_Bit_Test_Const_Ref_Reg(List: TAsmList; FromSize, DestSize: TDef; BitNumber: AInt; const Ref: TReference; DestReg: TRegister);
    var
      HRef: TReference;
    begin
      HRef:=Ref;
      G_PtrTypeCast_Ref(List,CPointerDef.GetReusable(FromSize),CPointerDef.GetReusable(U8IntType),HRef);
      A_Load_SubsetRef_Reg(List,U8IntType,DestSize,Get_Bit_Const_Ref_SRef(BitNumber,FromSize,HRef),DestReg);
    end;

  procedure THLCGObj.A_Bit_Test_Const_Reg_Reg(List: TAsmList; SetRegSize, DestSize: TDef; BitNumber: AInt; SetReg, DestReg: TRegister);
    begin
      A_Load_SubsetReg_Reg(List,SetRegSize,DestSize,Get_Bit_Const_Reg_SReg(SetRegSize,BitNumber,SetReg),DestReg);
    end;

  procedure THLCGObj.A_Bit_Test_Const_SubsetReg_Reg(List: TAsmList; FromSubsetSize, DestSize: TDef; BitNumber: AInt; const SetReg: TSubsetRegister; DestReg: TRegister);
    var
      TmpSReg: TSubsetRegister;
    begin
      { the first parameter is used to calculate the bit offset in }
      { case of big endian, and therefore must be the size of the  }
      { set and not of the whole subsetreg                         }
      TmpSReg:=Get_Bit_Const_Reg_SReg(FromSubsetSize,BitNumber,SetReg.SubsetReg);
      { now fix the size of the subsetreg }
      TmpSReg.SubsetRegSize:=SetReg.SubsetRegSize;
      { correct offset of the set in the subsetreg }
      Inc(TmpSReg.StartBit,SetReg.StartBit);
      A_Load_SubsetReg_Reg(List,FromSubsetSize,DestSize,TmpSReg,DestReg);
    end;

  procedure THLCGObj.A_Bit_Test_Reg_Ref_Reg(List: TAsmList; BitNumberSize, RefSize, DestSize: TDef; BitNumber: TRegister; const Ref: TReference; DestReg: TRegister);
    var
      HRef: TReference;
    begin
      HRef:=Ref;
      G_PtrTypeCast_Ref(List,CPointerDef.GetReusable(RefSize),CPointerDef.GetReusable(U8IntType),HRef);
      A_Load_SubsetRef_Reg(List,U8IntType,DestSize,Get_Bit_Reg_Ref_SRef(List,BitNumberSize,RefSize,BitNumber,HRef),DestReg);
    end;

  procedure THLCGObj.A_Bit_Test_Reg_Loc_Reg(List: TAsmList; BitNumberSize, LocSize, DestSize: TDef; BitNumber: TRegister; const Loc: TLocation; DestReg: TRegister);
    var
      TmpReg: TRegister;
    begin
      case Loc.Loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          A_Bit_Test_Reg_Ref_Reg(List,BitNumberSize,LocSize,DestSize,BitNumber,Loc.Reference,DestReg);
        LOC_REGISTER,LOC_CREGISTER,
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_CONSTANT:
          begin
            case Loc.Loc of
              LOC_REGISTER,LOC_CREGISTER:
                TmpReg:=Loc.Register;
              LOC_SUBSETREG,LOC_CSUBSETREG:
                begin
                  TmpReg:=GetIntRegister(List,LocSize);
                  A_Load_SubsetReg_Reg(List,LocSize,LocSize,Loc.SReg,TmpReg);
                end;
              LOC_CONSTANT:
                begin
                  TmpReg:=GetIntRegister(List,LocSize);
                  A_Load_Const_Reg(List,LocSize,Loc.Value,TmpReg);
                end;
              else
                InternalError(2013112909);
            end;
            A_Bit_Test_Reg_Reg_Reg(List,BitNumberSize,LocSize,DestSize,BitNumber,TmpReg,DestReg);
          end;
        { LOC_SUBSETREF is not possible, because sets are not (yet) bitpacked }
        else
          InternalError(2010120411);
      end;
    end;

  procedure THLCGObj.A_Bit_Test_Const_Loc_Reg(List: TAsmList; LocSize, DestSize: TDef; BitNumber: AInt; const Loc: TLocation; DestReg: TRegister);
    begin
      case Loc.Loc of
        LOC_REFERENCE,LOC_CREFERENCE:
          A_Bit_Test_Const_Ref_Reg(List,LocSize,DestSize,BitNumber,Loc.Reference,DestReg);
        LOC_REGISTER,LOC_CREGISTER:
          A_Bit_Test_Const_Reg_Reg(List,LocSize,DestSize,BitNumber,Loc.Register,DestReg);
        LOC_SUBSETREG,LOC_CSUBSETREG:
          A_Bit_Test_Const_SubsetReg_Reg(List,LocSize,DestSize,BitNumber,Loc.SReg,DestReg);
        { LOC_SUBSETREF is not possible, because sets are not (yet) bitpacked }
        else
          InternalError(2010120410);
      end;
    end;

  procedure THLCGObj.A_Bit_Set_Reg_Reg(List: TAsmList; DoSet: Boolean; BitNumberSize, DestSize: TDef; BitNumber, Dest: TRegister);
    var
      TmpValue: TRegister;
    begin
      TmpValue:=GetIntRegister(List,DestSize);

      if (TargetInfo.Endian=endian_little) then
        begin
          A_Load_Const_Reg(List,DestSize,1,TmpValue);
          { rotate bit "bitnumber" bits to the left }
          A_Op_Reg_Reg(List,OP_SHL,DestSize,BitNumber,TmpValue);
        end
      else
        begin
          { highest (leftmost) bit = bit 0 -> "$80/$8000/$80000000/ ... }
          { shr bitnumber" results in correct mask                      }
          A_Load_Const_Reg(List,DestSize,1 shl (DestSize.Size*8-1),TmpValue);
          A_Op_Reg_Reg(List,OP_SHR,DestSize,BitNumber,TmpValue);
        end;
      { set/clear the bit we want }
      if DoSet then
        A_Op_Reg_Reg(List,OP_OR,DestSize,TmpValue,Dest)
      else
        begin
          A_Op_Reg_Reg(List,OP_NOT,DestSize,TmpValue,TmpValue);
          A_Op_Reg_Reg(List,OP_AND,DestSize,TmpValue,Dest)
        end;
    end;

  procedure THLCGObj.A_Bit_Set_Const_Ref(List: TAsmList; DoSet: Boolean; DestSize: TDef; BitNumber: TCGInt; const Ref: TReference);
    var
      HRef: TReference;
    begin
      HRef:=Ref;
      G_PtrTypeCast_Ref(List,CPointerDef.GetReusable(DestSize),CPointerDef.GetReusable(U8IntType),HRef);
      A_Load_Const_SubsetRef(List,U8IntType,Ord(DoSet),Get_Bit_Const_Ref_SRef(BitNumber,DestSize,HRef));
    end;

  procedure THLCGObj.A_Bit_Set_Const_Reg(List: TAsmList; DoSet: Boolean; DestSize: TDef; BitNumber: TCGInt; DestReg: TRegister);
    begin
      G_PtrTypeCast_Reg(List,CPointerDef.GetReusable(DestSize),CPointerDef.GetReusable(U8IntType),DestReg);
      A_Load_Const_SubsetReg(List,U8IntType,Ord(DoSet),Get_Bit_Const_Reg_SReg(DestSize,BitNumber,DestReg));
    end;

  procedure THLCGObj.A_Bit_Set_Const_SubsetReg(List: TAsmList; DoSet: Boolean; DestSize: TDef; BitNumber: TCGInt; const DestReg: TSubsetRegister);
    var
      TmpSReg: TSubsetRegister;
    begin
      { the first parameter is used to calculate the bit offset in }
      { case of big endian, and therefore must be the size of the  }
      { set and not of the whole subsetreg                         }
      TmpSReg:=Get_Bit_Const_Reg_SReg(DestSize,BitNumber,DestReg.SubsetReg);
      { now fix the size of the subsetreg }
      TmpSReg.SubsetRegSize:=DestReg.SubsetRegSize;
      { correct offset of the set in the subsetreg }
      Inc(TmpSReg.StartBit,DestReg.StartBit);
      A_Load_Const_SubsetReg(List,U8IntType,Ord(DoSet),TmpSReg);
    end;

  procedure THLCGObj.A_Bit_Set_Reg_Ref(List: TAsmList; DoSet: Boolean; FromSize, ToSize: TDef; BitNumber: TRegister; const Ref: TReference);
    var
      HRef: TReference;
    begin
      HRef:=Ref;
      G_PtrTypeCast_Ref(List,CPointerDef.GetReusable(ToSize),CPointerDef.GetReusable(U8IntType),HRef);
      A_Load_Const_SubsetRef(List,U8IntType,Ord(DoSet),Get_Bit_Reg_Ref_SRef(List,FromSize,ToSize,BitNumber,HRef));
    end;

  procedure THLCGObj.A_Bit_Set_Reg_Loc(List: TAsmList; DoSet: Boolean; RegSize, ToSize: TDef; BitNumber: TRegister; const Loc: TLocation);
    var
      TmpReg: TRegister;
    begin
      case Loc.Loc of
        LOC_REFERENCE:
          A_Bit_Set_Reg_Ref(List,DoSet,RegSize,ToSize,BitNumber,Loc.Reference);
        LOC_CREGISTER:
          A_Bit_Set_Reg_Reg(List,DoSet,RegSize,ToSize,BitNumber,Loc.Register);
        { e.g. a 2-byte set in a record regvar }
        LOC_CSUBSETREG:
          begin
            { hard to do in-place in a generic way, so operate on a copy }
            TmpReg:=GetIntRegister(List,ToSize);
            A_Load_SubsetReg_Reg(List,ToSize,ToSize,Loc.SReg,TmpReg);
            A_Bit_Set_Reg_Reg(List,DoSet,RegSize,ToSize,BitNumber,TmpReg);
            A_Load_Reg_SubsetReg(List,ToSize,ToSize,TmpReg,Loc.SReg);
          end;
        { LOC_SUBSETREF is not possible, because sets are not (yet) bitpacked }
        else
          InternalError(2010120408)
      end;
    end;

  procedure THLCGObj.A_Bit_Set_Const_Loc(List: TAsmList; DoSet: Boolean; ToSize: TDef; BitNumber: TCGInt; const Loc: TLocation);
    begin
      case Loc.Loc of
        LOC_REFERENCE:
          A_Bit_Set_Const_Ref(List,DoSet,ToSize,BitNumber,Loc.Reference);
        LOC_CREGISTER:
          A_Bit_Set_Const_Reg(List,DoSet,ToSize,BitNumber,Loc.Register);
        LOC_CSUBSETREG:
          A_Bit_Set_Const_SubsetReg(List,DoSet,ToSize,BitNumber,Loc.SReg);
        { LOC_SUBSETREF is not possible, because sets are not (yet) bitpacked }
        else
          InternalError(2010120409)
      end;
    end;


  function THLCGObj.Get_Call_Result_CGPara(PD: TAbstractProcDef; ForceResDef: TDef): TCGPara;
    begin
      if PD.Generate_SafeCall_Wrapper then
        begin
          if Assigned(ForceResDef) then
            InternalError(2019112403);
          Result:=ParaManager.Get_SafeCallResult_FuncRetLoc(PD,CallerSide)
        end
      else if not Assigned(ForceResDef) then
        begin
          PD.Init_ParaLoc_Info(CallerSide);
          Result:=PD.FuncRetLoc[CallerSide];
        end
      else
        Result:=ParaManager.Get_FuncRetLoc(PD,CallerSide,ForceResDef);
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

  procedure THLCGObj.Get_SubsetRef_Load_Info(const SRef: TSubsetReference; out LoadSize: TOrdDef; out ExtraLoad: Boolean);
    var
      IntLoadSize: TCGInt;
    begin
      IntLoadSize:=PackedBitsLoadSize(SRef.BitLen);

      if (IntLoadSize=0) then
        InternalError(2006081310);

      if (IntLoadSize>SizeOf(AInt)) then
        IntLoadSize:=SizeOf(AInt);
      LoadSize:=CGSize_OrdDef(Int_CGSize(IntLoadSize));

      if (SRef.BitLen>SizeOf(AInt)*8) then
        InternalError(2006081312);

      ExtraLoad:=
        (SRef.BitLen<>1) and
        ((SRef.BitIndexReg<>NR_NO) or
         (Byte(SRef.StartBit+SRef.BitLen)>Byte(IntLoadSize*8)));
    end;

  procedure THLCGObj.A_Load_SubsetRef_Regs_NoIndex(List: TAsmList; SubsetSize: TDef; LoadBitSize: Byte; const SRef: TSubsetReference; ValueReg, ExtraValueReg: TRegister);
    var
      RestBits: Byte;
    begin
      if (TargetInfo.Endian=endian_big) then
        begin
          { valuereg contains the upper bits, extra_value_reg the lower }
          RestBits:=(SRef.BitLen-(LoadBitSize-SRef.StartBit));
          if Is_Signed(SubsetSize) then
            begin
              { sign extend }
              A_Op_Const_Reg(List,OP_SHL,ALUUIntType,AIntBits-LoadBitSize+SRef.StartBit,ValueReg);
              A_Op_Const_Reg(List,OP_SAR,ALUUIntType,AIntBits-SRef.BitLen,ValueReg);
            end
          else
            begin
              A_Op_Const_Reg(List,OP_SHL,ALUUIntType,RestBits,ValueReg);
              { mask other bits }
              if (SRef.BitLen<>AIntBits) then
                A_Op_Const_Reg(List,OP_AND,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen)-1),ValueReg);
            end;
          A_Op_Const_Reg(List,OP_SHR,ALUUIntType,LoadBitSize-RestBits,ExtraValueReg)
        end
      else
        begin
          { valuereg contains the lower bits, extra_value_reg the upper }
          A_Op_Const_Reg(List,OP_SHR,ALUUIntType,SRef.StartBit,ValueReg);
          if Is_Signed(SubsetSize) then
            begin
              A_Op_Const_Reg(List,OP_SHL,ALUUIntType,AIntBits-SRef.BitLen+LoadBitSize-SRef.StartBit,ExtraValueReg);
              A_Op_Const_Reg(List,OP_SAR,ALUUIntType,AIntBits-SRef.BitLen,ExtraValueReg);
            end
          else
            begin
              A_Op_Const_Reg(List,OP_SHL,ALUUIntType,LoadBitSize-SRef.StartBit,ExtraValueReg);
              { mask other bits }
              if (SRef.BitLen <> AIntBits) then
                A_Op_Const_Reg(List,OP_AND,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen)-1),ExtraValueReg);
            end;
        end;
      { merge }
      A_Op_Reg_Reg(List,OP_OR,ALUUIntType,ExtraValueReg,ValueReg);
    end;

  procedure THLCGObj.A_Load_SubsetRef_Regs_Index(List: TAsmList; SubsetSize: TDef; LoadBitSize: Byte; const SRef: TSubsetReference; ValueReg: TRegister);
    var
      HL: TAsmLabel;
      TmpRef: TReference;
      ExtraValueReg,
      TmpReg: TRegister;
    begin
      TmpReg:=GetIntRegister(List,ALUUIntType);
      TmpRef:=SRef.Ref;
      Inc(TmpRef.Offset,LoadBitSize div 8);
      ExtraValueReg:=GetIntRegister(List,ALUUIntType);

      if (TargetInfo.Endian=endian_big) then
        begin
          { since this is a dynamic index, it's possible that the value   }
          { is entirely in valuereg.                                      }

          { get the data in valuereg in the right place }
          A_Op_Reg_Reg(List,OP_SHL,ALUUIntType,SRef.BitIndexReg,ValueReg);
          if Is_Signed(SubsetSize) then
            begin
              A_Op_Const_Reg(List,OP_SHL,ALUUIntType,AIntBits-LoadBitSize,ValueReg);
              A_Op_Const_Reg(List,OP_SAR,ALUUIntType,AIntBits-SRef.BitLen,ValueReg)
            end
          else
            begin
              A_Op_Const_Reg(List,OP_SHR,ALUUIntType,LoadBitSize-SRef.BitLen,ValueReg);
              if (LoadBitSize<>AIntBits) then
                { mask left over bits }
                A_Op_Const_Reg(List,OP_AND,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen)-1),ValueReg);
            end;
          TmpReg := GetIntRegister(List,ALUUIntType);

          { ensure we don't load anything past the end of the array }
          CurrentAsmData.GetJumpLabel(HL);
          A_Cmp_Const_Reg_Label(List,ALUUIntType,OC_BE,LoadBitSize-SRef.BitLen,SRef.BitIndexReg,HL);

          { the bits in extra_value_reg (if any) start at the most significant bit =>         }
          { extra_value_reg must be shr by (loadbitsize-sref.bitlen)+(loadsize-sref.bitindex) }
          { => = -(sref.bitindex+(sref.bitlen-2*loadbitsize))                                 }
          A_Op_Const_Reg_Reg(List,OP_ADD,ALUUIntType,SRef.BitLen-2*LoadBitSize,SRef.BitIndexReg,TmpReg);
          A_Op_Reg_Reg(List,OP_NEG,ALUUIntType,TmpReg,TmpReg);

          { load next "loadbitsize" bits of the array }
          A_Load_Ref_Reg(List,CGSize_OrdDef(Int_CGSize(LoadBitSize div 8)),ALUUIntType,TmpRef,ExtraValueReg);

          A_Op_Reg_Reg(List,OP_SHR,ALUUIntType,TmpReg,ExtraValueReg);
          { if there are no bits in extra_value_reg, then sref.bitindex was      }
          { < loadsize-sref.bitlen, and therefore tmpreg will now be >= loadsize }
          { => extra_value_reg is now 0                                          }
          { merge }
          A_Op_Reg_Reg(List,OP_OR,ALUUIntType,ExtraValueReg,ValueReg);
          { no need to mask, necessary masking happened earlier on }
          A_Label(List,HL);
        end
      else
        begin
          A_Op_Reg_Reg(List,OP_SHR,ALUUIntType,SRef.BitIndexReg,ValueReg);

          { ensure we don't load anything past the end of the array }
          CurrentAsmData.GetJumpLabel(HL);
          A_Cmp_Const_Reg_Label(List,ALUUIntType,OC_BE,LoadBitSize-SRef.BitLen,SRef.BitIndexReg,HL);

          { Y-x = -(Y-x) }
          A_Op_Const_Reg_Reg(List,OP_SUB,ALUUIntType,LoadBitSize,SRef.BitIndexReg,TmpReg);
          A_Op_Reg_Reg(List,OP_NEG,ALUUIntType,TmpReg,TmpReg);

          { load next "loadbitsize" bits of the array }
          A_Load_Ref_Reg(List,CGSize_OrdDef(Int_CGSize(LoadBitSize div 8)),ALUUIntType,TmpRef,ExtraValueReg);

          { tmpreg is in the range 1..<cpu_bitsize>-1 -> always ok }
          A_Op_Reg_Reg(List,OP_SHL,ALUUIntType,TmpReg,ExtraValueReg);
          { merge }
          A_Op_Reg_Reg(List,OP_OR,ALUUIntType,ExtraValueReg,ValueReg);
          A_Label(List,HL);
          { sign extend or mask other bits }
          if Is_Signed(SubsetSize) then
            begin
              A_Op_Const_Reg(List,OP_SHL,ALUUIntType,AIntBits-SRef.BitLen,ValueReg);
              A_Op_Const_Reg(List,OP_SAR,ALUUIntType,AIntBits-SRef.BitLen,ValueReg);
            end
          else
            A_Op_Const_Reg(List,OP_AND,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen)-1),ValueReg);
        end;
    end;

  procedure THLCGObj.A_Load_RegConst_SubsetRef_Intern(List: TAsmList; FromSize, SubsetSize: TDef; FromReg: TRegister; const SRef: TSubsetReference; SlOpt: TSubsetLoadOpt);
    var
      HL: TAsmLabel;
      TmpReg, TmpIndexReg, ValueReg, ExtraValueReg, MaskReg: TRegister;
      ToSReg, FromSReg: TSubsetRegister;
      TmpRef: TReference;
      BitMask: AWord;
      LoadSize: TOrdDef;
      LoadBitSize: Byte;
      ExtraLoad: Boolean;
    begin
      { the register must be able to contain the requested value }
      if (FromSize.Size*8<SRef.BitLen) then
        InternalError(2006081613);

      Get_SubsetRef_Load_Info(SRef,LoadSize,ExtraLoad);
      LoadBitSize:=LoadSize.Size*8;

      { load the (first part) of the bit sequence }
      ValueReg:=GetIntRegister(List,ALUUIntType);
      A_Load_Ref_Reg(List,LoadSize,ALUUIntType,SRef.Ref,ValueReg);

      { constant offset of bit sequence? }
      if not ExtraLoad then
        begin
          if (SRef.BitIndexReg=NR_NO) then
            begin
              { use subsetreg routine, it may have been overridden with an optimized version }
              ToSReg.SubsetReg:=ValueReg;
              ToSReg.SubsetRegSize:=Def_CGSize(ALUUIntType);
              { subsetregs always count bits from right to left }
              if (TargetInfo.Endian=endian_big) then
                ToSReg.StartBit:=LoadBitSize-(SRef.StartBit+SRef.BitLen)
              else
                ToSReg.StartBit:=SRef.StartBit;
              ToSReg.BitLen:=SRef.BitLen;
              A_Load_RegConst_SubsetReg_Intern(List,FromSize,SubsetSize,FromReg,ToSReg,SlOpt);
            end
          else
            begin
              if (SRef.StartBit<>0) then
                InternalError(2006081710);
              { should be handled by normal code and will give wrong result }
              { on x86 for the '1 shl bitlen' below                         }
              if (SRef.BitLen=AIntBits) then
                InternalError(2006081711);

              { zero the bits we have to insert }
              if (SlOpt<>SL_SETMAX) then
                begin
                  if (SlOpt=SL_SETZERO) and (SRef.BitLen=1) and (TargetInfo.Endian=endian_little) then
                    begin
                      A_Bit_Set_Reg_Reg(List,False,ALUUIntType,ALUUIntType,SRef.BitIndexReg,ValueReg);

                      { store back to memory }
                      TmpReg:=GetIntRegister(List,LoadSize);
                      A_Load_Reg_Reg(List,ALUUIntType,LoadSize,ValueReg,TmpReg);
                      A_Load_Reg_Ref(List,LoadSize,LoadSize,TmpReg,SRef.Ref);
                      Exit;
                    end
                  else
                    begin
                      MaskReg:=GetIntRegister(List,ALUUIntType);
                      if (TargetInfo.Endian = endian_big) then
                        begin
                          A_Load_Const_Reg(List,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen)-1) shl (LoadBitSize-SRef.BitLen),MaskReg);
                          A_Op_Reg_Reg(List,OP_SHR,ALUUIntType,SRef.BitIndexReg,MaskReg);
                        end
                      else
                        begin
                          A_Load_Const_Reg(List,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen)-1),MaskReg);
                          A_Op_Reg_Reg(List,OP_SHL,ALUUIntType,SRef.BitIndexReg,MaskReg);
                        end;
                      A_Op_Reg_Reg(List,OP_NOT,ALUUIntType,MaskReg,MaskReg);
                      A_Op_Reg_Reg(List,OP_AND,ALUUIntType,MaskReg,ValueReg);
                    end;
                end;

              { insert the value }
              if (SlOpt<>SL_SETZERO) then
                begin
                  TmpReg:=GetIntRegister(List,ALUUIntType);
                  if (SlOpt<>SL_SETMAX) then
                    A_Load_Reg_Reg(List,FromSize,ALUUIntType,FromReg,TmpReg)
                  { setting of a single bit?
                    then we might take advantage of the CPU's bit set instruction }
                  else if (SRef.BitLen=1) and (TargetInfo.Endian=endian_little) then
                    begin
                      A_Bit_Set_Reg_Reg(List,True,ALUUIntType,ALUUIntType,SRef.BitIndexReg,ValueReg);

                      { store back to memory }
                      TmpReg:=GetIntRegister(List,LoadSize);
                      A_Load_Reg_Reg(List,ALUUIntType,LoadSize,ValueReg,TmpReg);
                      A_Load_Reg_Ref(List,LoadSize,LoadSize,TmpReg,SRef.Ref);
                      Exit;
                    end
                  else if (SRef.BitLen<>AIntBits) then
                    A_Load_Const_Reg(List,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen)-1), TmpReg)
                  else
                    A_Load_Const_Reg(List,ALUUIntType,-1,TmpReg);
                  if (TargetInfo.Endian=endian_big) then
                    begin
                      A_Op_Const_Reg(List,OP_SHL,ALUUIntType,LoadBitSize-SRef.BitLen,TmpReg);
                      if not(SlOpt in [SL_REGNOSRCMASK,SL_SETMAX]) then
                        begin
                          if (LoadBitSize<>AIntBits) then
                            BitMask:=(((AWord(1) shl LoadBitSize)-1) xor ((AWord(1) shl (LoadBitSize-SRef.BitLen))-1))
                          else
                            BitMask:=(High(AWord) xor ((AWord(1) shl (LoadBitSize-SRef.BitLen))-1));
                          A_Op_Const_Reg(List,OP_AND,ALUUIntType,BitMask,TmpReg);
                        end;
                      A_Op_Reg_Reg(List,OP_SHR,ALUUIntType,SRef.BitIndexReg,TmpReg);
                    end
                  else
                    begin
                      if not(SlOpt in [SL_REGNOSRCMASK,SL_SETMAX]) then
                        A_Op_Const_Reg(List,OP_AND,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen)-1),TmpReg);
                      A_Op_Reg_Reg(List,OP_SHL,ALUUIntType,SRef.BitIndexReg,TmpReg);
                    end;
                  A_Op_Reg_Reg(List,OP_OR,ALUUIntType,TmpReg,ValueReg);
                end;
            end;
          { store back to memory }
          TmpReg:=GetIntRegister(List,LoadSize);
          A_Load_Reg_Reg(List,ALUUIntType,LoadSize,ValueReg,TmpReg);
          A_Load_Reg_Ref(List,LoadSize,LoadSize,TmpReg,SRef.Ref);
          Exit;
        end
      else
        begin
          { load next value }
          ExtraValueReg:=GetIntRegister(List,ALUUIntType);
          TmpRef:=SRef.Ref;
          Inc(TmpRef.Offset,LoadBitSize div 8);

          { should maybe be taken out too, can be done more efficiently }
          { on e.g. i386 with shld/shrd                                 }
          if (SRef.BitIndexReg = NR_NO) then
            begin
              A_Load_Ref_Reg(List,LoadSize,ALUUIntType,TmpRef,ExtraValueReg);

              FromSReg.SubsetReg:=FromReg;
              FromSReg.SubsetRegSize:=Def_CGSize(FromSize);
              ToSReg.SubsetReg:=ValueReg;
              ToSReg.SubsetRegSize:=Def_CGSize(ALUUIntType);

              { transfer first part }
              FromSReg.BitLen:=LoadBitSize-SRef.StartBit;
              ToSReg.BitLen:=FromSReg.BitLen;
              if (TargetInfo.Endian=endian_big) then
                begin
                  { valuereg must contain the upper bits of the value at bits [0..loadbitsize-startbit] }

                  { upper bits of the value ... }
                  FromSReg.StartBit:=SRef.BitLen-(LoadBitSize-SRef.StartBit);
                  { ... to bit 0 }
                  ToSReg.StartBit:=0
                end
              else
                begin
                  { valuereg must contain the lower bits of the value at bits [startbit..loadbitsize] }

                  { lower bits of the value ... }
                  FromSReg.StartBit:=0;
                  { ... to startbit }
                  ToSReg.StartBit:=SRef.StartBit;
                end;
              case SlOpt of
                SL_SETZERO,
                SL_SETMAX:
                  A_Load_RegConst_SubsetReg_Intern(List,FromSize,SubsetSize,FromReg,ToSReg,SlOpt);
                else
                  A_Load_SubsetReg_SubsetReg(List,SubsetSize,SubsetSize,FromSReg,ToSReg);
              end;
{$ifndef cpuhighleveltarget}
              ValueReg:=CG.MakeRegSize(List,ValueReg,Def_CGSize(LoadSize));
              A_Load_Reg_Ref(List,LoadSize,LoadSize,ValueReg,SRef.Ref);
{$else}
              TmpReg:=GetIntRegister(List,LoadSize);
              A_Load_Reg_Reg(List,ALUUIntType,LoadSize,ValueReg,TmpReg);
              A_Load_Reg_Ref(List,LoadSize,LoadSize,TmpReg,SRef.Ref);
{$endif}

              { transfer second part }
              if (TargetInfo.Endian = endian_big) then
                begin
                  { extra_value_reg must contain the lower bits of the value at bits  }
                  { [(loadbitsize-(bitlen-(loadbitsize-startbit)))..loadbitsize]  }
                  { (loadbitsize-(bitlen-(loadbitsize-startbit))) = 2*loadbitsize }
                  { - bitlen - startbit }

                  FromSReg.StartBit:=0;
                  ToSReg.StartBit:=2*LoadBitSize-SRef.BitLen-SRef.StartBit
                end
              else
                begin
                  { extra_value_reg must contain the upper bits of the value at bits [0..bitlen-(loadbitsize-startbit)] }

                  FromSReg.StartBit:=FromSReg.BitLen;
                  ToSReg.StartBit:=0;
                end;
              ToSReg.SubsetReg:=ExtraValueReg;
              FromSReg.BitLen:=SRef.BitLen-FromSReg.BitLen;
              ToSReg.BitLen:=FromSReg.BitLen;

              case SlOpt of
                SL_SETZERO,
                SL_SETMAX:
                  A_Load_RegConst_SubsetReg_Intern(List,FromSize,SubsetSize,FromReg,ToSReg,SlOpt);
                else
                  A_Load_SubsetReg_SubsetReg(List,SubsetSize,SubsetSize,FromSReg,ToSReg);
              end;
              TmpReg:=GetIntRegister(List,LoadSize);
              A_Load_Reg_Reg(List,ALUUIntType,LoadSize,ExtraValueReg,TmpReg);
              A_Load_Reg_Ref(List,LoadSize,LoadSize,TmpReg,TmpRef);
              Exit;
            end
          else
            begin
              if (SRef.StartBit <> 0) then
                InternalError(2006081812);
              { should be handled by normal code and will give wrong result }
              { on x86 for the '1 shl bitlen' below                         }
              if (SRef.BitLen = AIntBits) then
                InternalError(2006081713);

              { generate mask to zero the bits we have to insert }
              if (SlOpt <> SL_SETMAX) then
                begin
                  MaskReg := GetIntRegister(List,ALUUIntType);
                  if (TargetInfo.Endian = endian_big) then
                    begin
                      A_Load_Const_Reg(List,ALUUIntType,TCGInt(((AWord(1) shl SRef.BitLen)-1) shl (LoadBitSize-SRef.BitLen)),MaskReg);
                      A_Op_Reg_Reg(List,OP_SHR,ALUUIntType,SRef.BitIndexReg,MaskReg);
                    end
                  else
                    begin
                      A_Load_Const_Reg(List,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen)-1),MaskReg);
                      A_Op_Reg_Reg(List,OP_SHL,ALUUIntType,SRef.BitIndexReg,MaskReg);
                    end;

                  A_Op_Reg_Reg(List,OP_NOT,ALUUIntType,MaskReg,MaskReg);
                  A_Op_Reg_Reg(List,OP_AND,ALUUIntType,MaskReg,ValueReg);
                end;

              { insert the value }
              if (SlOpt <> SL_SETZERO) then
                begin
                  TmpReg := GetIntRegister(List,ALUUIntType);
                  if (SlOpt <> SL_SETMAX) then
                    A_Load_Reg_Reg(List,FromSize,ALUUIntType,FromReg,TmpReg)
                  else if (SRef.BitLen <> AIntBits) then
                    A_Load_Const_Reg(List,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen) - 1), TmpReg)
                  else
                    A_Load_Const_Reg(List,ALUUIntType,-1,TmpReg);
                  if (TargetInfo.Endian = endian_big) then
                    begin
                      A_Op_Const_Reg(List,OP_SHL,ALUUIntType,LoadBitSize-SRef.BitLen,TmpReg);
                      if not(SlOpt in [SL_REGNOSRCMASK,SL_SETMAX]) then
                        { mask left over bits }
                        A_Op_Const_Reg(List,OP_AND,ALUUIntType,TCGInt(((AWord(1) shl SRef.BitLen)-1) shl (LoadBitSize-SRef.BitLen)),TmpReg);
                      A_Op_Reg_Reg(List,OP_SHR,ALUUIntType,SRef.BitIndexReg,TmpReg);
                    end
                  else
                    begin
                      if not(SlOpt in [SL_REGNOSRCMASK,SL_SETMAX]) then
                        { mask left over bits }
                        A_Op_Const_Reg(List,OP_AND,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen)-1),TmpReg);
                      A_Op_Reg_Reg(List,OP_SHL,ALUUIntType,SRef.BitIndexReg,TmpReg);
                    end;
                  A_Op_Reg_Reg(List,OP_OR,ALUUIntType,TmpReg,ValueReg);
                end;
              TmpReg:=GetIntRegister(List,LoadSize);
              A_Load_Reg_Reg(List,ALUUIntType,LoadSize,ValueReg,TmpReg);
              A_Load_Reg_Ref(List,LoadSize,LoadSize,TmpReg,SRef.Ref);

              { make sure we do not read/write past the end of the array }
              CurrentAsmData.GetJumpLabel(HL);
              A_Cmp_Const_Reg_Label(List,ALUUIntType,OC_BE,LoadBitSize-SRef.BitLen,SRef.BitIndexReg,HL);

              A_Load_Ref_Reg(List,LoadSize,ALUUIntType,TmpRef,ExtraValueReg);
              TmpIndexReg:=GetIntRegister(List,ALUUIntType);

              { load current array value }
              if (SlOpt<>SL_SETZERO) then
                begin
                  TmpReg:=GetIntRegister(List,ALUUIntType);
                  if (SlOpt<>SL_SETMAX) then
                     A_Load_Reg_Reg(List,FromSize,ALUUIntType,FromReg,TmpReg)
                  else if (SRef.BitLen<>AIntBits) then
                    A_Load_Const_Reg(List,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen) - 1), TmpReg)
                  else
                    A_Load_Const_Reg(List,ALUUIntType,-1,TmpReg);
                end;

              { generate mask to zero the bits we have to insert }
              if (SlOpt<>SL_SETMAX) then
                begin
                  MaskReg:=GetIntRegister(List,ALUUIntType);
                  if (TargetInfo.Endian=endian_big) then
                    begin
                      A_Op_Const_Reg_Reg(List,OP_ADD,ALUUIntType,SRef.BitLen-2*LoadBitSize,SRef.BitIndexReg,TmpIndexReg);
                      A_Op_Reg_Reg(List,OP_NEG,ALUUIntType,TmpIndexReg,TmpIndexReg);
                      A_Load_Const_Reg(List,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen)-1),MaskReg);
                      A_Op_Reg_Reg(List,OP_SHL,ALUUIntType,TmpIndexReg,MaskReg);
                    end
                  else
                    begin
                      { Y-x = -(x-Y) }
                      A_Op_Const_Reg_Reg(List,OP_SUB,ALUUIntType,LoadBitSize,SRef.BitIndexReg,TmpIndexReg);
                      A_Op_Reg_Reg(List,OP_NEG,ALUUIntType,TmpIndexReg,TmpIndexReg);
                      A_Load_Const_Reg(List,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen)-1),MaskReg);
                      A_Op_Reg_Reg(List,OP_SHR,ALUUIntType,TmpIndexReg,MaskReg);
                    end;

                  A_Op_Reg_Reg(List,OP_NOT,ALUUIntType,MaskReg,MaskReg);
                  A_Op_Reg_Reg(List,OP_AND,ALUUIntType,MaskReg,ExtraValueReg);
                end;

              if (SlOpt<>SL_SETZERO) then
                begin
                  if (TargetInfo.Endian=endian_big) then
                    A_Op_Reg_Reg(List,OP_SHL,ALUUIntType,TmpIndexReg,TmpReg)
                  else
                    begin
                      if not(SlOpt in [SL_REGNOSRCMASK,SL_SETMAX]) then
                        A_Op_Const_Reg(List,OP_AND,ALUUIntType,TCGInt((AWord(1) shl SRef.BitLen)-1),TmpReg);
                      A_Op_Reg_Reg(List,OP_SHR,ALUUIntType,TmpIndexReg,TmpReg);
                    end;
                  A_Op_Reg_Reg(List,OP_OR,ALUUIntType,TmpReg,ExtraValueReg);
                end;
{$ifndef cpuhighleveltarget}
              ExtraValueReg:=CG.MakeRegSize(List,ExtraValueReg,Def_CGSize(LoadSize));
              A_Load_Reg_Ref(List,LoadSize,LoadSize,ExtraValueReg,TmpRef);
{$else}
              TmpReg:=GetIntRegister(List,LoadSize);
              A_Load_Reg_Reg(List,ALUUIntType,LoadSize,ExtraValueReg,TmpReg);
              A_Load_Reg_Ref(List,LoadSize,LoadSize,TmpReg,TmpRef);
{$endif}

              A_Label(List,HL);
            end;
        end;
    end;

  procedure THLCGObj.A_Load_RegConst_SubsetReg_Intern(List: TAsmList; FromSize, SubsetSize: TDef; FromReg: TRegister; const SReg: TSubsetRegister; SlOpt: TSubsetLoadOpt);
    var
      BitMask: AWord;
      TmpReg: TRegister;
      SubsetRegDef: TOrdDef;
      StopBit: Byte;

    begin
      TmpReg:=NR_NO;
      SubsetRegDef:=CGSize_OrdDef(SReg.SubsetRegSize);
      StopBit:=SReg.StartBit+SReg.BitLen;
      // on x86(64), 1 shl 32(64) = 1 instead of 0
      if (StopBit<>AIntBits) then
        BitMask:=not(((AWord(1) shl StopBit)-1) xor ((AWord(1) shl SReg.StartBit)-1))
      else
        BitMask:=not(High(AWord) xor ((AWord(1) shl SReg.StartBit)-1));
      if not(SlOpt in [SL_SETZERO,SL_SETMAX]) then
        begin
          TmpReg:=GetIntRegister(List,SubsetRegDef);
          A_Load_Reg_Reg(List,FromSize,SubsetRegDef,FromReg,TmpReg);
          A_Op_Const_Reg(List,OP_SHL,SubsetRegDef,SReg.StartBit,TmpReg);
           if (SlOpt<>SL_REGNOSRCMASK) then
            A_Op_Const_Reg(List,OP_AND,SubsetRegDef,TCGInt(not(BitMask)),TmpReg);
        end;

      if (SlOpt<>SL_SETMAX) and
      { the "and" is not needed if the whole register is modified (except for SL_SETZERO),
        because later on we do a move in this case instead of an or }
        ((SReg.BitLen<>AIntBits) or (SlOpt=SL_SETZERO)) then
          begin
            { shl could wrap around in this case }
            if SubsetRegDef.Size=SizeOf(AWord) then
              A_Op_Const_Reg(List,OP_AND,SubsetRegDef,TCGInt(BitMask),SReg.SubsetReg)
            else
              A_Op_Const_Reg(List,OP_AND,SubsetRegDef,TCGInt(BitMask) and AWord((AWord(1) shl (SubsetRegDef.Size*8))-1),SReg.SubsetReg);
          end;

      case SlOpt of
        SL_SETZERO : ;
        SL_SETMAX :
          if (SReg.BitLen<>AIntBits) then
            A_Op_Const_Reg(List,OP_OR,SubsetRegDef,
              TCGInt(((AWord(1) shl SReg.BitLen)-1) shl SReg.StartBit),
              SReg.SubsetReg)
          else
            A_Load_Const_Reg(List,SubsetRegDef,-1,SReg.SubsetReg);
        { if the whole register is modified, no "or" is needed }
        else if SReg.BitLen=AIntBits then
          A_Load_Reg_Reg(List,SubsetRegDef,SubsetRegDef,TmpReg,SReg.SubsetReg)
        else
          A_Op_Reg_Reg(List,OP_OR,SubsetRegDef,TmpReg,SReg.SubsetReg)
       end;
    end;

  {$pop}

  function THLCGObj.Get_Bit_Const_Ref_SRef(BitNumber: TCGInt; RefDef: TDef; const Ref: TReference): TSubsetReference;
    begin
      Result.Ref:=Ref;
      Inc(Result.Ref.Offset,BitNumber div 8);
      Result.Ref.Alignment:=NewAlignment(Result.Ref.Alignment,BitNumber div 8);
      Result.BitIndexReg:=NR_NO;
      Result.StartBit:=BitNumber mod 8;
      Result.BitLen:=1;
    end;

  function THLCGObj.Get_Bit_Const_Reg_SReg(SetRegSize: TDef; BitNumber: TCGInt; SetReg: TRegister): TSubsetRegister;
    begin
      Result.SubsetReg:=SetReg;
      Result.SubsetRegSize:=Def_CGSize(SetRegSize);
      { subsetregs always count from the least significant to the most significant bit }
      if (TargetInfo.Endian=endian_big) then
        Result.StartBit:=(SetRegSize.Size*8)-BitNumber-1
      else
        Result.StartBit:=BitNumber;
      Result.BitLen:=1;
    end;

  function THLCGObj.Get_Bit_Reg_Ref_SRef(List: TAsmList; BitNumberSize, RefSize: TDef; BitNumber: TRegister; const Ref: TReference): TSubsetReference;
    var
      RefPtrDef: TDef;
      TmpReg,
      NewBase: TRegister;
    begin
      Result.Ref:=Ref;
      Result.StartBit:=0;
      Result.BitLen:=1;

      TmpReg:=GetIntRegister(List,PtrUIntType);
      A_Load_Reg_Reg(List,BitNumberSize,PtrUIntType,BitNumber,TmpReg);
      A_Op_Const_Reg(List,OP_SHR,PtrUIntType,3,TmpReg);

      { don't assign to ref.base, that one is for pointers and this is an index
        (important for platforms like LLVM) }
      if Result.Ref.Index<>NR_NO then
        begin
          { don't just add to ref.index, as it may be scaled }
          RefPtrDef:=CPointerDef.GetReusable(RefSize);
          NewBase:=GetAddressRegister(List,RefPtrDef);
          A_LoadAddr_Ref_Reg(List,RefSize,RefPtrDef,Ref,NewBase);
          Reference_Reset_Base(Result.Ref,RefPtrDef,NewBase,0,Result.Ref.TempPos,Result.Ref.Alignment,[]);
        end;
      Result.Ref.Index:=TmpReg;
      TmpReg:=GetIntRegister(List,ALUUIntType);
      A_Load_Reg_Reg(List,BitNumberSize,ALUUIntType,BitNumber,TmpReg);
      A_Op_Const_Reg(List,OP_AND,ALUUIntType,7,TmpReg);
      Result.BitIndexReg:=TmpReg;
    end;

  procedure THLCGObj.A_LoadFPU_Ref_Ref(List: TAsmList; FromSize, ToSize: TDef; const Ref1, Ref2: TReference);
    var
      Reg: TRegister;
      RegSize: TDef;
    begin
      if (FromSize.Size>=ToSize.Size) then
        RegSize:=FromSize
      else
        RegSize:=ToSize;
      Reg:=GetFPURegister(List,RegSize);
      A_LoadFPU_Ref_Reg(List,FromSize,RegSize,Ref1,Reg);
      A_LoadFPU_Reg_Ref(List,RegSize,ToSize,Reg,Ref2);
    end;

  procedure THLCGObj.A_LoadFPU_Loc_Reg(List: TAsmList; FromSize, ToSize: TDef; const Loc: TLocation; const Reg: TRegister);
    begin
      case Loc.Loc of
        LOC_REFERENCE, LOC_CREFERENCE:
          A_LoadFPU_Ref_Reg(List,FromSize,ToSize,Loc.Reference,Reg);
        LOC_FPUREGISTER, LOC_CFPUREGISTER:
          A_LoadFPU_Reg_Reg(List,FromSize,ToSize,Loc.Register,Reg);
        else
          InternalError(2010120412);
      end;
    end;

  procedure THLCGObj.A_LoadFPU_Loc_Ref(List: TAsmList; FromSize, ToSize: TDef; const Loc: TLocation; const Ref: TReference);
    var
      Reg: TRegister;
    begin
      case Loc.Loc of
        LOC_REFERENCE, LOC_CREFERENCE:
          begin
            Reg:=GetFPURegister(List,ToSize);
            A_LoadFPU_Ref_Reg(List,FromSize,ToSize,Loc.Reference,Reg);
            A_LoadFPU_Reg_Ref(List,ToSize,ToSize,Reg,Ref);
          end;
        LOC_FPUREGISTER, LOC_CFPUREGISTER:
          begin
            A_LoadFPU_Reg_Ref(List,FromSize,ToSize,Loc.Register,Ref);
          end;
        else
          InternalError(2014080802);
      end;
    end;

  procedure THLCGObj.A_LoadFPU_Reg_Loc(List: TAsmList; FromSize, ToSize: TDef; const Reg: TRegister; const Loc: TLocation);
    begin
      case Loc.Loc of
        LOC_REFERENCE, LOC_CREFERENCE:
          A_LoadFPU_Reg_Ref(List,FromSize,ToSize,Reg,Loc.Reference);
        LOC_FPUREGISTER, LOC_CFPUREGISTER:
          A_LoadFPU_Reg_Reg(List,FromSize,ToSize,Reg,Loc.Register);
        else
          InternalError(2010120413);
       end;
    end;

  procedure THLCGObj.A_LoadFPU_Reg_CGPara(List: TAsmList; FromSize: TDef; const R: TRegister; const CGPara: TCGPara);
      var
         Ref : TReference;
      begin
        ParaManager.AllocCGPara(List,CGPara);
        case CGPara.Location^.Loc of
          LOC_FPUREGISTER,LOC_CFPUREGISTER:
            begin
              CGPara.Check_Simple_Location;
              A_LoadFPU_Reg_Reg(List,FromSize,CGPara.Def,R,CGPara.Location^.Register);
            end;
          LOC_REFERENCE,LOC_CREFERENCE:
            begin
              CGPara.Check_Simple_Location;
              Reference_Reset_Base(Ref,VoidStackPointerType,CGPara.Location^.Reference.Index,CGPara.Location^.Reference.Offset,CTempPosInvalid,CGPara.Alignment,[]);
              A_LoadFPU_Reg_Ref(List,FromSize,CGPara.Def,R,Ref);
            end;
          LOC_REGISTER,LOC_CREGISTER:
            begin
              { paramfpu_ref does the check_simple_location check here if necessary }
              TG.GetHLTemp(List,FromSize,FromSize.Size,tt_normal,Ref);
              A_LoadFPU_Reg_Ref(List,FromSize,FromSize,R,Ref);
              A_LoadFPU_Ref_CGPara(List,FromSize,Ref,CGPara);
              TG.UngetTemp(List,Ref);
            end;
          else
            InternalError(2010120422);
        end;
      end;

  procedure THLCGObj.A_LoadFPU_Ref_CGPara(List: TAsmList; FromSize: TDef; const Ref: TReference; const CGPara: TCGPara);
    var
       HReg : TRegister;
       HRef : TReference;
       IntPtrDef: TDef;
    begin
       case CGPara.Location^.Loc of
        LOC_FPUREGISTER,LOC_CFPUREGISTER:
          begin
            CGPara.Check_Simple_Location;
            ParaManager.AllocCGPara(List,CGPara);
            A_LoadFPU_Ref_Reg(List,FromSize,CGPara.Location^.Def,Ref,CGPara.Location^.Register);
          end;
        LOC_REFERENCE,LOC_CREFERENCE:
          begin
            CGPara.Check_Simple_Location;
            Reference_Reset_Base(HRef,VoidStackPointerType,CGPara.Location^.Reference.Index,CGPara.Location^.Reference.Offset,CTempPosInvalid,CGPara.Alignment,[]);
            { concatcopy should choose the best way to copy the data }
            G_ConcatCopy(List,FromSize,Ref,HRef);
          end;
        LOC_REGISTER,LOC_CREGISTER:
          begin
            CGPara.Check_Simple_Location;
            if FromSize.Size<>CGPara.Location^.Def.Size then
              InternalError(2014080603);
            { convert the reference from a floating point location to an
              integer location, and load that }
            IntPtrDef:=CPointerDef.GetReusable(CGPara.Location^.Def);
            HReg:=GetAddressRegister(List,IntPtrDef);
            A_LoadAddr_Ref_Reg(List,FromSize,IntPtrDef,Ref,HReg);
            Reference_Reset_Base(HRef,IntPtrDef,HReg,0,Ref.TempPos,Ref.Alignment,[]);
            A_Load_Ref_CGPara(List,CGPara.Location^.Def,Ref,CGPara);
          end
        else
          InternalError(2010120423);
      end;
    end;

  procedure THLCGObj.A_LoadMM_Ref_Ref(List: TAsmList; FromSize, ToSize: TDef; const FromRef, ToRef: TReference; Shuffle: PMMShuffle);
    var
      Reg: TRegister;
    begin
      Reg:=GetMMRegister(List,ToSize);
      A_LoadMM_Ref_Reg(List,FromSize,ToSize,FromRef,Reg,Shuffle);
      A_LoadMM_Reg_Ref(List,ToSize,ToSize,Reg,ToRef,Shuffle);
    end;

  procedure THLCGObj.A_LoadMM_Loc_Reg(List: TAsmList; FromSize, ToSize: TDef; const Loc: TLocation; const Reg: TRegister; Shuffle: PMMShuffle);
    var
      TmpReg: TRegister;
    begin
      case Loc.Loc of
        LOC_MMREGISTER,LOC_CMMREGISTER:
          A_LoadMM_Reg_Reg(List,FromSize,ToSize,Loc.Register,Reg,Shuffle);
        LOC_REFERENCE,LOC_CREFERENCE:
          A_LoadMM_Ref_Reg(List,FromSize,ToSize,Loc.Reference,Reg,Shuffle);
        LOC_REGISTER,LOC_CREGISTER:
          A_LoadMM_IntReg_Reg(List,FromSize,ToSize,Loc.Register,Reg,Shuffle);
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          begin
            TmpReg:=GetIntRegister(List,FromSize);
            A_Load_Loc_Reg(List,FromSize,FromSize,Loc,TmpReg);
            A_LoadMM_IntReg_Reg(List,FromSize,ToSize,TmpReg,Reg,Shuffle);
          end
        else
          InternalError(2010120414);
      end;
    end;

  procedure THLCGObj.A_LoadMM_Reg_Loc(List: TAsmList; FromSize, ToSize: TDef; const Reg: TRegister; const Loc: TLocation; Shuffle: PMMShuffle);
    begin
      case Loc.Loc of
        LOC_MMREGISTER,LOC_CMMREGISTER:
          A_LoadMM_Reg_Reg(List,FromSize,ToSize,Reg,Loc.Register,Shuffle);
        LOC_REFERENCE,LOC_CREFERENCE:
          A_LoadMM_Reg_Ref(List,FromSize,ToSize,Reg,Loc.Reference,Shuffle);
        else
          InternalError(2010120417);
      end;
    end;

  procedure THLCGObj.A_LoadMM_Loc_Ref(List: TAsmList; FromSize, ToSize: TDef; const Loc: TLocation; const Ref: TReference; Shuffle: PMMShuffle);
    var
      IntReg, Reg: TRegister;
    begin
      case Loc.Loc of
        LOC_MMREGISTER,LOC_CMMREGISTER:
          A_LoadMM_Reg_Ref(List,FromSize,ToSize,Loc.Register,Ref,Shuffle);
        LOC_REFERENCE,LOC_CREFERENCE:
          begin
            Reg:=GetMMRegister(List,ToSize);
            A_LoadMM_Ref_Reg(List,FromSize,ToSize,Loc.Reference,Reg,Shuffle);
            A_LoadMM_Reg_Ref(List,ToSize,ToSize,Reg,Ref,Shuffle);
          end;
        LOC_REGISTER,LOC_CREGISTER:
          begin
            Reg:=GetMMRegister(List,ToSize);
            A_LoadMM_IntReg_Reg(List,FromSize,ToSize,Loc.Register,Reg,Shuffle);
            A_LoadMM_Reg_Ref(List,ToSize,ToSize,Reg,Ref,Shuffle);
          end;
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          begin
            IntReg:=GetIntRegister(List,FromSize);
            Reg:=GetMMRegister(List,ToSize);
            A_Load_Loc_Reg(List,FromSize,FromSize,Loc,IntReg);
            A_LoadMM_IntReg_Reg(List,FromSize,ToSize,IntReg,Reg,Shuffle);
            A_LoadMM_Reg_Ref(List,ToSize,ToSize,Reg,Ref,Shuffle);
          end
        else
          InternalError(2014080803);
      end;
    end;

  procedure THLCGObj.A_LoadMM_Reg_CGPara(List: TAsmList; FromSize: TDef; Reg: TRegister; const CGPara: TCGPara; Shuffle: PMMShuffle);
    var
      HRef  : TReference;
    begin
       CGPara.Check_Simple_Location;
       ParaManager.AllocCGPara(List,CGPara);
       case CGPara.Location^.Loc of
        LOC_MMREGISTER,LOC_CMMREGISTER:
          A_LoadMM_Reg_Reg(List,FromSize,CGPara.Def,Reg,CGPara.Location^.Register,Shuffle);
        LOC_REFERENCE,LOC_CREFERENCE:
          begin
            Reference_Reset_Base(HRef,VoidStackPointerType,CGPara.Location^.Reference.Index,CGPara.Location^.Reference.Offset,CTempPosInvalid,CGPara.Alignment,[]);
            A_LoadMM_Reg_Ref(List,FromSize,CGPara.Def,Reg,HRef,Shuffle);
          end;
        LOC_REGISTER,LOC_CREGISTER:
          begin
            if Assigned(Shuffle) and
               not ShuffleScalar(Shuffle) then
              InternalError(2012071205);
             A_LoadMM_Reg_IntReg(List,FromSize,CGPara.Def,Reg,CGPara.Location^.Register,MMS_MoveScalar);
          end
        else
          InternalError(2012071204);
      end;
    end;

  procedure THLCGObj.A_LoadMM_Ref_CGPara(List: TAsmList; FromSize: TDef; const Ref: TReference; const CGPara: TCGPara; Shuffle: PMMShuffle);
    var
       HR : TRegister;
       HS : TMMShuffle;
    begin
       CGPara.Check_Simple_Location;
       HR:=GetMMRegister(List,CGPara.Def);
       A_LoadMM_Ref_Reg(List,FromSize,CGPara.Def,Ref,HR,Shuffle);
       if RealShuffle(Shuffle) then
         begin
           HS:=Shuffle^;
           RemoveShuffles(HS);
           A_LoadMM_Reg_CGPara(List,CGPara.Def,HR,CGPara,@HS);
         end
       else
         A_LoadMM_Reg_CGPara(List,CGPara.Def,HR,CGPara,Shuffle);
    end;

  procedure THLCGObj.A_LoadMM_Loc_CGPara(List: TAsmList; FromSize: TDef; const Loc: TLocation; const CGPara: TCGPara; Shuffle: PMMShuffle);
    begin
{$ifdef extdebug}
      if Def_CGSize(FromSize)<>Loc.Size then
        InternalError(2012071203);
{$endif}
      case Loc.Loc of
        LOC_MMREGISTER,LOC_CMMREGISTER:
          A_LoadMM_Reg_CGPara(List,FromSize,Loc.Register,CGPara,Shuffle);
        LOC_REFERENCE,LOC_CREFERENCE:
          A_LoadMM_Ref_CGPara(List,FromSize,Loc.Reference,CGPara,Shuffle);
        else
          InternalError(2012071202);
      end;
    end;

  procedure THLCGObj.A_OpMM_Ref_Reg(List: TAsmList; Op: TOpCG; Size: TDef; const Ref: TReference; Reg: TRegister; Shuffle: PMMShuffle);
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

  procedure THLCGObj.A_OpMM_Loc_Reg(List: TAsmList; Op: TOpCG; Size: TDef; const Loc: TLocation; Reg: TRegister; Shuffle: PMMShuffle);
    begin
      case Loc.Loc of
        LOC_CMMREGISTER,LOC_MMREGISTER:
          A_OpMM_Reg_Reg(List,Op,Size,Loc.Register,Reg,Shuffle);
        LOC_CREFERENCE,LOC_REFERENCE:
          A_OpMM_Ref_Reg(List,Op,Size,Loc.Reference,Reg,Shuffle);
        else
          InternalError(2012071201);
      end;
    end;

  procedure THLCGObj.A_OpMM_Reg_Ref(List: TAsmList; Op: TOpCG; Size: TDef; Reg: TRegister; const Ref: TReference; Shuffle: PMMShuffle);
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
  procedure THLCGObj.A_Op_Const_Ref(List: TAsmList; Op: TOpCG; Size: TDef; A: TCGInt; const Ref: TReference);
    var
      TmpReg : TRegister;
    begin
      TmpReg:=GetIntRegister(List,Size);
      A_Load_Ref_Reg(List,Size,Size,Ref,TmpReg);
      A_Op_Const_Reg(List,Op,Size,A,TmpReg);
      A_Load_Reg_Ref(List,Size,Size,TmpReg,Ref);
    end;

  procedure THLCGObj.A_Op_Const_SubsetReg(List: TAsmList; Op: TOpCG; Size, SubsetSize: TDef; A: TCGInt; const SReg: TSubsetRegister);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetIntRegister(List,Size);
      A_Load_SubsetReg_Reg(List,SubsetSize,Size,SReg,TmpReg);
      A_Op_Const_Reg(List,Op,Size,A,TmpReg);
      A_Load_Reg_SubsetReg(List,Size,SubsetSize,TmpReg,SReg);
    end;

  procedure THLCGObj.A_Op_Const_SubsetRef(List: TAsmList; Op: TOpCG; Size, SubsetSize: TDef; A: TCGInt; const SRef: TSubsetReference);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetIntRegister(List,Size);
      A_Load_SubsetRef_Reg(List,SubsetSize,Size,SRef,TmpReg);
      A_Op_Const_Reg(List,Op,Size,A,TmpReg);
      A_Load_Reg_SubsetRef(List,Size,SubsetSize,TmpReg,SRef);
    end;

  procedure THLCGObj.A_Op_Const_Loc(List: TAsmList; Op: TOpCG; Size: TDef; A: TCGInt; const Loc: TLocation);
    begin
      case Loc.Loc of
        LOC_REGISTER, LOC_CREGISTER:
          A_Op_Const_Reg(List,Op,Size,A,Loc.Register);
        LOC_REFERENCE, LOC_CREFERENCE:
          A_Op_Const_Ref(List,Op,Size,A,Loc.Reference);
        LOC_SUBSETREG, LOC_CSUBSETREG:
          A_Op_Const_SubsetReg(List,Op,Size,Size,A,Loc.SReg);
        LOC_SUBSETREF, LOC_CSUBSETREF:
          A_Op_Const_SubsetRef(List,Op,Size,Size,A,Loc.SRef);
        else
          InternalError(2010120428);
      end;
    end;

  procedure THLCGObj.A_Op_Reg_Ref(List: TAsmList; Op: TOpCG; Size: TDef; Reg: TRegister; const Ref: TReference);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetIntRegister(List,Size);
      A_Load_Ref_Reg(List,Size,Size,Ref,TmpReg);
      case Op of
        OP_NOT,OP_NEG:
          begin
            A_Op_Reg_Reg(List,Op,Size,TmpReg,TmpReg);
          end;
        else
          begin
            A_Op_Reg_Reg(List,Op,Size,Reg,TmpReg);
          end;
      end;
      A_Load_Reg_Ref(List,Size,Size,TmpReg,Ref);
    end;

  procedure THLCGObj.A_Op_Ref_Reg(List: TAsmList; Op: TOpCG; Size: TDef; const Ref: TReference; Reg: TRegister);
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

  procedure THLCGObj.A_Op_Reg_SubsetReg(List: TAsmList; Op: TOpCG; OpSize, DestSubsetSize: TDef; Reg: TRegister; const SReg: TSubsetRegister);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetIntRegister(List,OpSize);
      A_Load_SubsetReg_Reg(List,DestSubsetSize,OpSize,SReg,TmpReg);
      A_Op_Reg_Reg(List,Op,OpSize,Reg,TmpReg);
      A_Load_Reg_SubsetReg(List,OpSize,DestSubsetSize,TmpReg,SReg);
    end;

  procedure THLCGObj.A_Op_Reg_SubsetRef(List: TAsmList; Op: TOpCG; OpSize, DestSubsetSize: TDef; Reg: TRegister; const SRef: TSubsetReference);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetIntRegister(List,OpSize);
      A_Load_SubsetRef_Reg(List,DestSubsetSize,OpSize,SRef,TmpReg);
      A_Op_Reg_Reg(List,Op,OpSize,Reg,TmpReg);
      A_Load_Reg_SubsetRef(List,OpSize,DestSubsetSize,TmpReg,SRef);
    end;

  procedure THLCGObj.A_Op_Reg_Loc(List: TAsmList; Op: TOpCG; Size: TDef; Reg: TRegister; const Loc: TLocation);
    begin
      case Loc.Loc of
        LOC_REGISTER, LOC_CREGISTER:
          A_Op_Reg_Reg(List,Op,Size,Reg,Loc.Register);
        LOC_REFERENCE, LOC_CREFERENCE:
          A_Op_Reg_Ref(List,Op,Size,Reg,Loc.Reference);
        LOC_SUBSETREG, LOC_CSUBSETREG:
          A_Op_Reg_SubsetReg(List,Op,Size,Size,Reg,Loc.SReg);
        LOC_SUBSETREF, LOC_CSUBSETREF:
          A_Op_Reg_SubsetRef(List,Op,Size,Size,Reg,Loc.SRef);
        else
          InternalError(2010120429);
      end;
    end;

  procedure THLCGObj.A_Op_Ref_Loc(List: TAsmList; Op: TOpCG; Size: TDef; const Ref: TReference; const Loc: TLocation);
    var
      TmpReg: TRegister;
    begin
      case Loc.Loc of
        LOC_REGISTER,LOC_CREGISTER:
          A_Op_Ref_Reg(List,Op,Size,Ref,Loc.Register);
        LOC_REFERENCE,LOC_CREFERENCE:
          begin
            TmpReg:=GetIntRegister(List,Size);
            A_Load_Ref_Reg(List,Size,Size,Ref,TmpReg);
            A_Op_Reg_Ref(List,Op,Size,TmpReg,Loc.Reference);
          end;
        LOC_SUBSETREG, LOC_CSUBSETREG:
          begin
            TmpReg:=GetIntRegister(List,Size);
            A_Load_SubsetReg_Reg(List,Size,Size,Loc.SReg,TmpReg);
            A_Op_Ref_Reg(List,Op,Size,Ref,TmpReg);
            A_Load_Reg_SubsetReg(List,Size,Size,TmpReg,Loc.SReg);
          end;
        LOC_SUBSETREF, LOC_CSUBSETREF:
          begin
            TmpReg:=GetIntRegister(List,Size);
            A_Load_SubsetRef_Reg(List,Size,Size,Loc.SRef,TmpReg);
            A_Op_Ref_Reg(List,Op,Size,Ref,TmpReg);
            A_Load_Reg_SubsetRef(List,Size,Size,TmpReg,Loc.SRef);
          end;
        else
          InternalError(2010120418);
      end;
    end;

  procedure THLCGObj.A_Op_Const_Reg_Reg(List: TAsmList; Op: TOpCG; Size: TDef; A: TCGInt; Src, Dst: TRegister);
    begin
      A_Load_Reg_Reg(List,Size,Size,Src,Dst);
      A_Op_Const_Reg(List,Op,Size,A,Dst);
    end;

  procedure THLCGObj.A_Op_Reg_Reg_Reg(List: TAsmList; Op: TOpCG; Size: TDef; Src1, Src2, Dst: TRegister);
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

  procedure THLCGObj.A_Op_Const_Reg_Reg_CheckOverflow(List: TAsmList; Op: TOpCG; Size: TDef; A: TCGInt; Src, Dst: TRegister; SetFlags: Boolean; var OVLoc: TLocation);
    begin
      OVLoc.Loc:=LOC_VOID;
      if not SetFlags then
        A_Op_Const_Reg_Reg(List,Op,Size,A,Src,Dst)
      else
        InternalError(2010122910);
    end;

  procedure THLCGObj.A_Op_Reg_Reg_Reg_CheckOverflow(List: TAsmList; Op: TOpCG; Size: TDef; Src1, Src2, Dst: TRegister; SetFlags: Boolean; var OVLoc: TLocation);
    begin
      OVLoc.Loc:=LOC_VOID;
      if not SetFlags then
        A_Op_Reg_Reg_Reg(List,Op,Size,Src1,Src2,Dst)
      else
        InternalError(2010122911);
    end;

  procedure THLCGObj.A_Op_Reg(List: TAsmList; Op: TOpCG; Size: TDef; Reg: TRegister);
    begin
      if not (Op in [OP_NOT,OP_NEG]) then
        InternalError(2020050711);
      A_Op_Reg_Reg(List,Op,Size,Reg,Reg);
    end;

  procedure THLCGObj.A_Op_Ref(List: TAsmList; Op: TOpCG; Size: TDef; const Ref: TReference);
    var
      TmpReg: TRegister;
    begin
      if not (Op in [OP_NOT,OP_NEG]) then
        InternalError(2020050712);
      TmpReg:=GetIntRegister(List,Size);
      A_Load_Ref_Reg(List,Size,Size,Ref,TmpReg);
      A_Op_Reg_Reg(List,Op,Size,TmpReg,TmpReg);
      A_Load_Reg_Ref(List,Size,Size,TmpReg,Ref);
    end;

  procedure THLCGObj.A_Op_SubsetReg(List: TAsmList; Op: TOpCG; DestSubsetSize: TDef; const SReg: TSubsetRegister);
    var
      TmpReg: TRegister;
      SubsetRegDef: TOrdDef;
    begin
      SubsetRegDef:=CGSize_OrdDef(SReg.SubsetRegSize);
      TmpReg:=GetIntRegister(List,SubsetRegDef);
      A_Load_SubsetReg_Reg(List,DestSubsetSize,SubsetRegDef,SReg,TmpReg);
      A_Op_Reg(List,Op,SubsetRegDef,TmpReg);
      A_Load_Reg_SubsetReg(List,SubsetRegDef,DestSubsetSize,TmpReg,SReg);
    end;

  procedure THLCGObj.A_Op_SubsetRef(List: TAsmList; Op: TOpCG; DestSubsetSize: TDef; const SRef: TSubsetReference);
    var
      TmpReg: TRegister;
      SubsetRegDef: TOrdDef;
    begin
      SubsetRegDef:=CGSize_OrdDef(Def_CGSize(DestSubsetSize));
      TmpReg:=GetIntRegister(List,SubsetRegDef);
      A_Load_SubsetRef_Reg(List,DestSubsetSize,SubsetRegDef,SRef,TmpReg);
      A_Op_Reg(List,Op,SubsetRegDef,TmpReg);
      A_Load_Reg_SubsetRef(List,SubsetRegDef,DestSubsetSize,TmpReg,SRef);
    end;

  procedure THLCGObj.A_Op_Loc(List: TAsmList; Op: TOpCG; Size: TDef; const Loc: TLocation);
    begin
      case Loc.Loc of
        LOC_REGISTER, LOC_CREGISTER:
          A_Op_Reg(List,Op,Size,Loc.Register);
        LOC_REFERENCE, LOC_CREFERENCE:
          A_Op_Ref(List,Op,Size,Loc.Reference);
        LOC_SUBSETREG, LOC_CSUBSETREG:
          A_Op_SubsetReg(List,Op,Size,Loc.SReg);
        LOC_SUBSETREF, LOC_CSUBSETREF:
          A_Op_SubsetRef(List,Op,Size,Loc.SRef);
        else
          InternalError(2020050703);
      end;
    end;

  procedure THLCGObj.A_Cmp_Const_Reg_Label(List: TAsmList; Size: TDef; CmpOp: TOpCmp; A: TCGInt; Reg: TRegister; L: TAsmLabel);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetRegisterForDef(List,Size);
      A_Load_Const_Reg(List,Size,A,TmpReg);
      A_Cmp_Reg_Reg_Label(List,Size,CmpOp,TmpReg,Reg,L);
    end;

  procedure THLCGObj.A_Cmp_Const_Ref_Label(List: TAsmList; Size: TDef; CmpOp: TOpCmp; A: TCGInt; const Ref: TReference; L: TAsmLabel);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetRegisterForDef(List,Size);
      A_Load_Ref_Reg(List,Size,Size,Ref,TmpReg);
      A_Cmp_Const_Reg_Label(List,Size,CmpOp,A,TmpReg,L);
    end;

  procedure THLCGObj.A_Cmp_Const_Loc_Label(List: TAsmList; Size: TDef; CmpOp: TOpCmp; A: TCGInt; const Loc: TLocation; L: TAsmLabel);
    var
      TmpReg: TRegister;
    begin
      case Loc.Loc of
        LOC_REGISTER,LOC_CREGISTER:
          A_Cmp_Const_Reg_Label(List,Size,CmpOp,A,Loc.Register,L);
        LOC_REFERENCE,LOC_CREFERENCE:
          A_Cmp_Const_Ref_Label(List,Size,CmpOp,A,Loc.Reference,L);
        LOC_SUBSETREG, LOC_CSUBSETREG:
          begin
            TmpReg:=GetIntRegister(List,Size);
            A_Load_SubsetReg_Reg(List,Size,Size,Loc.SReg,TmpReg);
            A_Cmp_Const_Reg_Label(List,Size,CmpOp,A,TmpReg,L);
          end;
        LOC_SUBSETREF, LOC_CSUBSETREF:
          begin
            TmpReg:=GetIntRegister(List,Size);
            A_Load_SubsetRef_Reg(List,Size,Size,Loc.SRef,TmpReg);
            A_Cmp_Const_Reg_Label(List,Size,CmpOp,A,TmpReg,L);
          end;
        else
          InternalError(2010120430);
      end;
    end;

  procedure THLCGObj.A_Cmp_Ref_Reg_Label(List: TAsmList; Size: TDef; CmpOp: TOpCmp; const Ref: TReference; Reg: TRegister; L: TAsmLabel);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetIntRegister(List,Size);
      A_Load_Ref_Reg(List,Size,Size,Ref,TmpReg);
      A_Cmp_Reg_Reg_Label(List,Size,CmpOp,TmpReg,Reg,L);
    end;

  procedure THLCGObj.A_Cmp_Reg_Ref_Label(List: TAsmList; Size: TDef; CmpOp: TOpCmp; Reg: TRegister; const Ref: TReference; L: TAsmLabel);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetIntRegister(List,Size);
      A_Load_Ref_Reg(List,Size,Size,Ref,TmpReg);
      A_Cmp_Reg_Reg_Label(List,Size,CmpOp,Reg,TmpReg,L);
    end;

  procedure THLCGObj.A_Cmp_SubsetReg_Reg_Label(List: TAsmList; FromSubsetSize, CmpSize: TDef; CmpOp: TOpCmp; const SReg: TSubsetRegister; Reg: TRegister; L: TAsmLabel);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetIntRegister(List,CmpSize);
      A_Load_SubsetReg_Reg(List,FromSubsetSize,CmpSize,SReg,TmpReg);
      A_Cmp_Reg_Reg_Label(List,CmpSize,CmpOp,TmpReg,Reg,L);
    end;

  procedure THLCGObj.A_Cmp_SubsetRef_Reg_Label(List: TAsmList; FromSubsetSize, CmpSize: TDef; CmpOp: TOpCmp; const SRef: TSubsetReference; Reg: TRegister; L: TAsmLabel);
    var
      TmpReg: TRegister;
    begin
      TmpReg:=GetIntRegister(List,CmpSize);
      A_Load_SubsetRef_Reg(List,FromSubsetSize,CmpSize,SRef,TmpReg);
      A_Cmp_Reg_Reg_Label(List,CmpSize,CmpOp,TmpReg,Reg,L);
    end;

  procedure THLCGObj.A_Cmp_Loc_Reg_Label(List: TAsmList; Size: TDef; CmpOp: TOpCmp; const Loc: TLocation; Reg: TRegister; L: TAsmLabel);
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
        LOC_SUBSETREG,
        LOC_CSUBSETREG:
          A_Cmp_SubsetReg_Reg_Label(List,Size,Size,CmpOp,Loc.SReg,Reg,L);
        LOC_SUBSETREF,
        LOC_CSUBSETREF:
          A_Cmp_SubsetRef_Reg_Label(List,Size,Size,CmpOp,Loc.SRef,Reg,L);
        else
          InternalError(2010120431);
      end;
    end;

  procedure THLCGObj.A_Cmp_Reg_Loc_Label(List: TAsmList; Size: TDef; CmpOp: TOpCmp; Reg: TRegister; const Loc: TLocation; L: TAsmLabel);
    begin
      A_Cmp_Loc_Reg_Label(List,Size,Swap_OpCmp(CmpOp),Loc,Reg,L);
    end;

  procedure THLCGObj.A_Cmp_Ref_Loc_Label(List: TAsmList; Size: TDef; CmpOp: TOpCmp; const Ref: TReference; const Loc: TLocation; L: TAsmLabel);
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
        LOC_CONSTANT:
          begin
            A_Cmp_Const_Ref_Label(List,Size,Swap_OpCmp(CmpOp),Loc.Value,Ref,L);
          end;
        LOC_SUBSETREG, LOC_CSUBSETREG:
          begin
            TmpReg:=GetIntRegister(List,Size);
            A_Load_Ref_Reg(List,Size,Size,Loc.Reference,TmpReg);
            A_Cmp_SubsetReg_Reg_Label(List,Size,Size,Swap_OpCmp(CmpOp),Loc.SReg,TmpReg,L);
          end;
        LOC_SUBSETREF, LOC_CSUBSETREF:
          begin
            TmpReg:=GetIntRegister(List,Size);
            A_Load_Ref_Reg(List,Size,Size,Loc.Reference,TmpReg);
            A_Cmp_SubsetRef_Reg_Label(List,Size,Size,Swap_OpCmp(CmpOp),Loc.SRef,TmpReg,L);
          end;
        else
          InternalError(2010120432);
      end;
    end;


  procedure THLCGObj.A_Jmp_Always_Pascal_Goto(List : TAsmList;L: TAsmLabel);
    begin
      A_Jmp_Always(List,L);
    end;

  procedure THLCGObj.Optimize_Op_Const(Size: TDef; var Op: TOpCG; var A: TCGInt);
    var
      PowerVal : LongInt;
      SignExtA, ZeroExtA: TCGInt;
      CGSize: TCgSize;
    begin
      CGSize:=Def_CGSize(Size);
      case CGSize of
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
          case CGSize of
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

  procedure THLCGObj.G_Exception_Reason_Save(List: TAsmList; FromSize, ToSize: TDef; Reg: TRegister; const HRef: TReference);
    begin
      A_Load_Reg_Ref(List,FromSize,ToSize,Reg,HRef);
    end;

  procedure THLCGObj.G_Exception_Reason_Save_Const(List: TAsmList; Size: TDef; A: TCGInt; const HRef: TReference);
    begin
      A_Load_Const_Ref(List,Size,A,HRef);
    end;


  procedure THLCGObj.G_Exception_Reason_Load(List: TAsmList; FromSize, ToSize: TDef; const HRef: TReference; Reg: TRegister);
    begin
      A_Load_Ref_Reg(List,FromSize,ToSize,HRef,Reg);
    end;


  procedure THLCGObj.G_Exception_Reason_Discard(List: TAsmList; Size: TDef; HRef: TReference);
    begin
      { do nothing by default }
    end;


  procedure THLCGObj.G_Maybe_CheckForExceptions(List : TAsmList);
    begin
      { do nothing by default }
    end;


  procedure THLCGObj.G_Unreachable(List: TAsmList);
    begin
      { nothing }
    end;


  procedure THLCGObj.G_Maybe_TestSelf(List: TAsmList; SelfType: TDef; Reg: TRegister);
    var
      OkLabel : TAsmLabel;
      CGPara1 : TCGPara;
      PD      : TProcDef;
    begin
      if (cs_check_object in CurrentSettings.LocalSwitches) or
         (cs_check_range in CurrentSettings.LocalSwitches) then
       begin
         PD:=Search_System_Proc('fpc_handleerror');
         CurrentAsmData.GetJumpLabel(OkLabel);
         A_Cmp_Const_Reg_Label(List,SelfType,OC_NE,0,Reg,OkLabel);
         CGPara1.Init;
         ParaManager.GetCGTempParaLoc(List,PD,1,CGPara1);
         A_Load_Const_CGPara(List,S32IntType,AInt(210),CGPara1);
         ParaManager.FreeCGPara(List,CGPara1);
         G_Call_System_Proc(List,PD,[@CGPara1],nil).ResetIfTemp;
         CGPara1.Done;
         A_Label(List,OkLabel);
       end;
    end;

  procedure THLCGObj.G_ConcatCopy(List: TAsmList; Size: TDef; const Source, Dest: TReference);
    begin
      if Use_VectorFPU(Size) then
        A_LoadMM_Ref_Ref(List,Size,Size,Source,Dest,MMS_MoveScalar)
      else if Size.Typ<>FloatDef then
        A_Load_Ref_Ref(List,Size,Size,Source,Dest)
      else
        A_LoadFPU_Ref_Ref(List,Size,Size,Source,Dest);
    end;

  procedure THLCGObj.G_ConcatCopy_Unaligned(List: TAsmList; Size: TDef; const Source, Dest: TReference);
    begin
      G_ConcatCopy(List,Size,Source,Dest);
    end;

  procedure THLCGObj.G_CopyShortString(List: TAsmList; const Source, Dest: TReference; StrDef: TStringDef);
    var
      CGPara1,CGPara2,CGPara3 : TCGPara;
      PD : TProcDef;
    begin
      PD:=Search_System_Proc('fpc_shortstr_to_shortstr');
      CGPara1.Init;
      CGPara2.Init;
      CGPara3.Init;
      ParaManager.GetCGTempParaLoc(List,PD,1,CGPara1);
      ParaManager.GetCGTempParaLoc(List,PD,2,CGPara2);
      ParaManager.GetCGTempParaLoc(List,PD,3,CGPara3);
      if PD.Is_PushLeftRight then
        begin
          A_LoadAddr_Ref_CGPara(List,StrDef,Dest,CGPara1);
          A_Load_Const_CGPara(List,S32IntType,StrDef.Len,CGPara2);
          A_LoadAddr_Ref_CGPara(List,StrDef,Source,CGPara3);
        end
      else
        begin
          A_LoadAddr_Ref_CGPara(List,StrDef,Source,CGPara3);
          A_Load_Const_CGPara(List,S32IntType,StrDef.Len,CGPara2);
          A_LoadAddr_Ref_CGPara(List,StrDef,Dest,CGPara1);
        end;
      ParaManager.FreeCGPara(List,CGPara3);
      ParaManager.FreeCGPara(List,CGPara2);
      ParaManager.FreeCGPara(List,CGPara1);
      G_Call_System_Proc(List,PD,[@CGPara1,@CGPara2,@CGPara3],nil).ResetIfTemp;
      CGPara3.Done;
      CGPara2.Done;
      CGPara1.Done;
    end;

  procedure THLCGObj.G_CopyVariant(List: TAsmList; const Source, Dest: TReference; VarDef: TVariantDef);
    var
      CGPara1,CGPara2 : TCGPara;
      PD : TProcDef;
    begin
      PD:=Search_System_Proc('fpc_variant_copy_overwrite');
      CGPara1.Init;
      CGPara2.Init;
      ParaManager.GetCGTempParaLoc(List,PD,1,CGPara1);
      ParaManager.GetCGTempParaLoc(List,PD,2,CGPara2);
      if PD.Is_PushLeftRight then
        begin
          A_LoadAddr_Ref_CGPara(List,VarDef,Source,CGPara1);
          A_LoadAddr_Ref_CGPara(List,VarDef,Dest,CGPara2);
        end
      else
        begin
          A_LoadAddr_Ref_CGPara(List,VarDef,Dest,CGPara2);
          A_LoadAddr_Ref_CGPara(List,VarDef,Source,CGPara1);
        end;
      ParaManager.FreeCGPara(List,CGPara2);
      ParaManager.FreeCGPara(List,CGPara1);
      G_Call_System_Proc(List,PD,[@CGPara1,@CGPara2],nil).ResetIfTemp;
      CGPara2.Done;
      CGPara1.Done;
    end;

  procedure THLCGObj.G_IncrRefCount(List: TAsmList; T: TDef; const Ref: TReference);
    var
      HRef : TReference;
      IncrFunc : string;
      CGPara1,CGPara2 : TCGPara;
      PD : TProcDef;
    begin
       CGPara1.Init;
       CGPara2.Init;
       if Is_InterfaceCOM_Or_DispInterface(T) then
         IncrFunc:='fpc_intf_incr_ref'
       else if Is_AnsiString(T) then
         IncrFunc:='fpc_ansistr_incr_ref'
       else if Is_WideString(T) then
         IncrFunc:='fpc_widestr_incr_ref'
       else if Is_UnicodeString(T) then
         IncrFunc:='fpc_unicodestr_incr_ref'
       else if Is_Dynamic_Array(T) then
         IncrFunc:='fpc_dynarray_incr_ref'
       else
        IncrFunc:='';
       { call the special incr function or the generic addref }
       if IncrFunc<>'' then
        begin
          PD:=Search_System_Proc(IncrFunc);
          ParaManager.GetCGTempParaLoc(List,PD,1,CGPara1);
          { widestrings aren't ref. counted on all platforms so we need the address
            to create a real copy }
          if Is_WideString(T) then
            A_LoadAddr_Ref_CGPara(List,T,Ref,CGPara1)
          else
            { these functions get the pointer by value }
            A_Load_Ref_CGPara(List,T,Ref,CGPara1);
          ParaManager.FreeCGPara(List,CGPara1);
          G_Call_System_Proc(List,PD,[@CGPara1],nil).ResetIfTemp;
        end
       else
        begin
          PD:=Search_System_Proc('fpc_addref');
          ParaManager.GetCGTempParaLoc(List,PD,1,CGPara1);
          ParaManager.GetCGTempParaLoc(List,PD,2,CGPara2);
          if Is_Open_Array(T) then
            InternalError(201103054);
          Reference_Reset_Symbol(HRef,RTTIWriter.get_rtti_label(T,InitRTTI,Def_Needs_Indirect(T)),0,SizeOf(PInt),[]);
          if PD.Is_PushLeftRight then
            begin
              A_LoadAddr_Ref_CGPara(List,T,Ref,CGPara1);
              A_LoadAddr_Ref_CGPara(List,VoidPointerType,HRef,CGPara2);
            end
          else
            begin
              A_LoadAddr_Ref_CGPara(List,VoidPointerType,HRef,CGPara2);
              A_LoadAddr_Ref_CGPara(List,T,Ref,CGPara1);
            end;
          ParaManager.FreeCGPara(List,CGPara1);
          ParaManager.FreeCGPara(List,CGPara2);
          G_Call_System_Proc(List,PD,[@CGPara1,@CGPara2],nil).ResetIfTemp;
        end;
       CGPara2.Done;
       CGPara1.Done;
    end;

  procedure THLCGObj.G_Initialize(List: TAsmList; T: TDef; const Ref: TReference);
    var
       HRef : TReference;
       CGPara1,CGPara2 : TCGPara;
       PD : TProcDef;
    begin
       CGPara1.Init;
       CGPara2.Init;
       if Is_AnsiString(T) or
          Is_WideString(T) or
          Is_UnicodeString(T) or
          Is_InterfaceCOM_Or_DispInterface(T) or
          Is_Dynamic_Array(T) then
         A_Load_Const_Ref(List,T,0,Ref)
       else if T.Typ=VariantDef then
         begin
           PD:=Search_System_Proc('fpc_variant_init');
           ParaManager.GetCGTempParaLoc(List,PD,1,CGPara1);
           A_LoadAddr_Ref_CGPara(List,T,Ref,CGPara1);
           ParaManager.FreeCGPara(List,CGPara1);
          G_Call_System_Proc(List,PD,[@CGPara1],nil).ResetIfTemp;
         end
       else
         begin
            if Is_Open_Array(T) then
              InternalError(201103052);
            PD:=Search_System_Proc('fpc_initialize');
            ParaManager.GetCGTempParaLoc(List,PD,1,CGPara1);
            ParaManager.GetCGTempParaLoc(List,PD,2,CGPara2);
            Reference_Reset_Symbol(HRef,RTTIWriter.get_rtti_label(T,InitRTTI,Def_Needs_Indirect(T)),0,SizeOf(PInt),[]);
            if PD.Is_PushLeftRight then
              begin
                A_LoadAddr_Ref_CGPara(List,T,Ref,CGPara1);
                A_LoadAddr_Ref_CGPara(List,VoidPointerType,HRef,CGPara2);
              end
            else
              begin
                A_LoadAddr_Ref_CGPara(List,VoidPointerType,HRef,CGPara2);
                A_LoadAddr_Ref_CGPara(List,T,Ref,CGPara1);
              end;
            ParaManager.FreeCGPara(List,CGPara1);
            ParaManager.FreeCGPara(List,CGPara2);
            G_Call_System_Proc(List,PD,[@CGPara1,@CGPara2],nil).ResetIfTemp;
         end;
       CGPara1.Done;
       CGPara2.Done;
    end;

  procedure THLCGObj.G_Finalize(List: TAsmList; T: TDef; const Ref: TReference);
    var
       HRef : TReference;
       CGPara1,CGPara2 : TCGPara;
       PD : TProcDef;
       DecrFunc : string;
    begin
      if Is_InterfaceCOM_Or_DispInterface(T) then
        DecrFunc:='fpc_intf_decr_ref'
      else if Is_AnsiString(T) then
        DecrFunc:='fpc_ansistr_decr_ref'
      else if Is_WideString(T) then
        DecrFunc:='fpc_widestr_decr_ref'
      else if Is_UnicodeString(T) then
        DecrFunc:='fpc_unicodestr_decr_ref'
      else if T.Typ=VariantDef then
        DecrFunc:='fpc_variant_clear'
      else
        begin
          CGPara1.Init;
          CGPara2.Init;
          if Is_Open_Array(T) then
            InternalError(201103051);
          { fpc_finalize takes a pointer value parameter, fpc_dynarray_clear a
            pointer var parameter }
          if Is_Dynamic_Array(T) then
            PD:=Search_System_Proc('fpc_dynarray_clear')
          else
            PD:=Search_System_Proc('fpc_finalize');
          ParaManager.GetCGTempParaLoc(List,PD,1,CGPara1);
          ParaManager.GetCGTempParaLoc(List,PD,2,CGPara2);
          Reference_Reset_Symbol(HRef,RTTIWriter.get_rtti_label(T,InitRTTI,Def_Needs_Indirect(T)),0,SizeOf(PInt),[]);
          if PD.Is_PushLeftRight then
            begin
              A_LoadAddr_Ref_CGPara(List,T,Ref,CGPara1);
              A_LoadAddr_Ref_CGPara(List,VoidPointerType,HRef,CGPara2);
            end
          else
            begin
              A_LoadAddr_Ref_CGPara(List,VoidPointerType,HRef,CGPara2);
              A_LoadAddr_Ref_CGPara(List,T,Ref,CGPara1);
            end;
          ParaManager.FreeCGPara(List,CGPara1);
          ParaManager.FreeCGPara(List,CGPara2);
          G_Call_System_Proc(List,PD,[@CGPara1,@CGPara2],nil).ResetIfTemp;
          CGPara1.Done;
          CGPara2.Done;
          Exit;
        end;
      PD:=Search_System_Proc(DecrFunc);
      CGPara1.Init;
      ParaManager.GetCGTempParaLoc(List,PD,1,CGPara1);
      A_LoadAddr_Ref_CGPara(List,T,Ref,CGPara1);
      ParaManager.FreeCGPara(List,CGPara1);
      G_Call_System_Proc(List,PD,[@CGPara1],nil).ResetIfTemp;
      CGPara1.Done;
    end;

  procedure THLCGObj.G_Array_RTTI_Helper(List: TAsmList; T: TDef; const Ref: TReference; const HighLoc: TLocation; const Name: string);
    var
      CGPara1,CGPara2,CGPara3: TCGPara;
      HRef: TReference;
      HReg, LenReg: TRegister;
      PD: TProcDef;
    begin
      CGPara1.Init;
      CGPara2.Init;
      CGPara3.Init;
      PD:=Search_System_Proc(Name);
      ParaManager.GetCGTempParaLoc(List,PD,1,CGPara1);
      ParaManager.GetCGTempParaLoc(List,PD,2,CGPara2);
      ParaManager.GetCGTempParaLoc(List,PD,3,CGPara3);

      Reference_Reset_Symbol(HRef,RTTIWriter.get_rtti_label(T,InitRTTI,Def_Needs_Indirect(T)),0,SizeOf(PInt),[]);
      { if calling convention is left to right, push parameters 1 and 2 }
      if PD.Is_PushLeftRight then
        begin
          A_LoadAddr_Ref_CGPara(List,T,Ref,CGPara1);
          A_LoadAddr_Ref_CGPara(List,VoidPointerType,HRef,CGPara2);
        end;

      { push parameter 3 }
      if HighLoc.Loc=LOC_CONSTANT then
        A_Load_Const_CGPara(List,SizeSIntType,HighLoc.Value+1,CGPara3)
      else
        begin
          if HighLoc.Loc in [LOC_REGISTER,LOC_CREGISTER] then
            HReg:=HighLoc.Register
          else
            begin
              HReg:=GetIntRegister(List,SizeSIntType);
              A_Load_Loc_Reg(List,SizeSIntType,SizeSIntType,HighLoc,HReg);
            end;
          { increment, converts high(x) to length(x) }
          LenReg:=GetIntRegister(List,SizeSIntType);
          A_Op_Const_Reg_Reg(List,OP_ADD,SizeSIntType,1,HReg,LenReg);
          A_Load_Reg_CGPara(List,SizeSIntType,LenReg,CGPara3);
        end;

      { if calling convention is right to left, push parameters 2 and 1 }
      if not PD.Is_PushLeftRight then
        begin
          A_LoadAddr_Ref_CGPara(List,VoidPointerType,HRef,CGPara2);
          A_LoadAddr_Ref_CGPara(List,T,Ref,CGPara1);
        end;
      ParaManager.FreeCGPara(List,CGPara1);
      ParaManager.FreeCGPara(List,CGPara2);
      ParaManager.FreeCGPara(List,CGPara3);
      G_Call_System_Proc(List,PD,[@CGPara1,@CGPara2,@CGPara3],nil).ResetIfTemp;

      CGPara3.Done;
      CGPara2.Done;
      CGPara1.Done;
    end;

  function THLCGObj.Def_Needs_Indirect(T:TDef):Boolean;
    begin
      Result:=(tf_supports_packages in TargetInfo.Flags) and
                (TargetInfo.System in systems_indirect_var_imports) and
                (FindUnitSymTable(T.Owner).ModuleID<>CurrentModule.ModuleID);
    end;

  procedure THLCGObj.G_RangeCheck(List: TAsmList; const L: TLocation; FromDef, ToDef: TDef);
    var
{$if defined(cpuhighleveltarget)}
      AIntMax: TCGInt;
{$elseif defined(cpu64bitalu) or defined(cpu32bitalu)}
      AIntMax: AInt;
{$else}
      AIntMax: LongInt;
{$endif}
      NegLabel : TAsmLabel;
      HReg : TRegister;
      LTo,HTo,
      LFrom,HFrom : TConstExprInt;
      FromSize, ToSize: Cardinal;
      MaxDef: TDef;
      FromSigned, ToSigned: Boolean;
    begin
      { range checking on and range checkable value? }
      if not(cs_check_range in CurrentSettings.LocalSwitches) or
         not(FromDef.Typ in [OrdDef,EnumDef]) or
         { C-style booleans can't really fail range checks, }
         { all values are always valid                      }
         Is_CBool(ToDef) then
        Exit;
{$if not defined(cpuhighleveltarget) and not defined(cpu64bitalu)}
        { handle 64bit rangechecks separate for 32bit processors }
        if Is_64Bit(FromDef) or Is_64Bit(ToDef) then
          begin
             CG64.G_RangeCheck64(List,L,FromDef,ToDef);
             Exit;
          end;
{$endif ndef cpuhighleveltarget and ndef cpu64bitalu}
      { only check when assigning to scalar, subranges are different, }
      { when todef=fromdef then the check is always generated         }
      GetRange(FromDef,LFrom,HFrom);
      GetRange(ToDef,LTo,HTo);
      FromSigned := Is_Signed(FromDef);
      ToSigned := Is_Signed(ToDef);
      { check the rangedef of the array, not the array itself }
      { (only change now, since getrange needs the arraydef)   }
      if (ToDef.Typ = ArrayDef) then
        ToDef := TArrayDef(ToDef).RangeDef;
      { no range check if from and to are equal and are both longint/dword }
      { (if we have a 32bit processor) or int64/qword, since such          }
      { operations can at most cause overflows (JM)                        }
      { Note that these checks are mostly processor independent, they only }
      { have to be changed once we introduce 64bit subrange types          }
{$if defined(cpuhighleveltarget) or defined(cpu64bitalu)}
      if (FromDef=ToDef) and
         (FromDef.Typ=OrdDef) and
         (((((TOrdDef(FromDef).OrdType=S64Bit) and
             (LFrom = Low(Int64)) and
             (HFrom = High(Int64))) or
            ((TOrdDef(FromDef).OrdType=U64Bit) and
             (LFrom = Low(QWord)) and
             (HFrom = High(QWord))) or
            ((TOrdDef(FromDef).OrdType=SCurrency) and
             (LFrom = Low(Int64)) and
             (HFrom = High(Int64)))))) then
        Exit;
{$endif cpuhighleveltarget or cpu64bitalu}
      { 32 bit operations are automatically widened to 64 bit on 64 bit addr
        targets }
{$ifdef cpu32bitaddr}
      if (FromDef = ToDef) and
         (FromDef.Typ=OrdDef) and
         (((((TOrdDef(FromDef).OrdType = S32Bit) and
             (LFrom = Int64(Low(LongInt))) and
             (HFrom = Int64(High(LongInt)))) or
            ((TOrdDef(FromDef).OrdType = U32Bit) and
             (LFrom = Low(Cardinal)) and
             (HFrom = High(Cardinal)))))) then
        Exit;
{$endif cpu32bitaddr}

      { optimize some range checks away in safe cases }
      FromSize := FromDef.Size;
      ToSize := ToDef.Size;
      if ((FromSigned = ToSigned) or
          (not FromSigned)) and
         (LTo<=LFrom) and (HTo>=HFrom) and
         (FromSize <= ToSize) then
        begin
          { if fromsize < tosize, and both have the same signed-ness or }
          { fromdef is unsigned, then all bit patterns from fromdef are }
          { valid for todef as well                                     }
          if (FromSize < ToSize) then
            Exit;
          if (FromSize = ToSize) and
             (FromSigned = ToSigned) then
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
              if ToSigned then
                begin
                  { calculation of the low/high ranges must not overflow 64 bit
                   otherwise we end up comparing with zero for 64 bit data types on
                   64 bit processors }
                  if (LTo = (Int64(-1) << (ToSize * 8 - 1))) and
                     (HTo = (-((Int64(-1) << (ToSize * 8 - 1))+1))) then
                    Exit
                end
              else
                begin
                  { calculation of the low/high ranges must not overflow 64 bit
                   otherwise we end up having all zeros for 64 bit data types on
                   64 bit processors }
                  if (LTo = 0) and
                     (QWord(HTo) = (QWord(-1) >> (64-(ToSize * 8))) ) then
                    Exit
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
      if FromSize=8 then
        MaxDef:=FromDef
      else
        MaxDef:=ToDef;
{$if defined(cpuhighleveltarget) or defined(cpu64bitalu)}
      if MaxDef.Size=8 then
        AIntMax:=High(Int64)
      else
{$endif}
        begin
          AIntMax:=High(LongInt);
          MaxDef:=U32IntType;
        end;

      { generate the rangecheck code for the def where we are going to }
      { store the result                                               }

      { use the trick that                                                 }
      { a <= x <= b <=> 0 <= x-a <= b-a <=> unsigned(x-a) <= unsigned(b-a) }

      { To be able to do that, we have to make sure however that either    }
      { fromdef and todef are both signed or unsigned, or that we leave    }
      { the parts < 0 and > maxlongint out                                 }

      if FromSigned xor ToSigned then
        begin
           if FromSigned then
             { from is signed, to is unsigned }
             begin
               { if high(from) < 0 -> always range error }
               if (HFrom < 0) or
                  { if low(to) > maxlongint also range error }
                  (LTo > AIntMax) then
                 begin
                   G_Call_System_Proc(List,'fpc_rangeerror',[],nil).ResetIfTemp;
                   Exit
                 end;
               { from is signed and to is unsigned -> when looking at to }
               { as an signed value, it must be < maxaint (otherwise     }
               { it will become negative, which is invalid since "to" is unsigned) }
               if HTo > AIntMax then
                 HTo := AIntMax;
             end
           else
             { from is unsigned, to is signed }
             begin
               if (LFrom > AIntMax) or
                  (HTo < 0) then
                 begin
                   G_Call_System_Proc(List,'fpc_rangeerror',[],nil).ResetIfTemp;
                   Exit
                 end;
               { from is unsigned and to is signed -> when looking at to }
               { as an unsigned value, it must be >= 0 (since negative   }
               { values are the same as values > maxlongint)             }
               if LTo < 0 then
                 LTo := 0;
             end;
        end;
      HReg:=GetIntRegister(List,MaxDef);
      A_Load_Loc_Reg(List,FromDef,MaxDef,L,HReg);
      A_Op_Const_Reg(List,OP_SUB,MaxDef,TCGInt(Int64(LTo)),HReg);
      CurrentAsmData.GetJumpLabel(NegLabel);
      {
      if from_signed then
        a_cmp_const_reg_label(list,OS_INT,OC_GTE,aint(hto-lto),hreg,neglabel)
      else
      }
      CG.A_Reg_Alloc(List, NR_DEFAULTFLAGS);
      if QWord(HTo-LTo)>QWord(AIntMax) then
        A_Cmp_Const_Reg_Label(List,MaxDef,OC_BE,AIntMax,HReg,NegLabel)
      else
        A_Cmp_Const_Reg_Label(List,MaxDef,OC_BE,TCGInt(Int64(HTo-LTo)),HReg,NegLabel);
      CG.A_Reg_Dealloc(List, NR_DEFAULTFLAGS);
      G_Call_System_Proc(List,'fpc_rangeerror',[],nil).ResetIfTemp;
      A_Label(List,NegLabel);
    end;

  procedure THLCGObj.G_CopyValuePara_OpenArray(List: TAsmList; const Ref: TReference; const LenLoc: TLocation; ArrDef: TArrayDef; DestReg: TRegister);
    var
      SizeReg,SourceReg,LenReg : TRegister;
      CGPara1,CGPara2,CGPara3 : TCGPara;
      PtrArrDef : TDef;
      PD : TProcDef;
      GetMemRes : TCGPara;
      DestLoc : TLocation;
    begin
      { because some abis don't support dynamic stack allocation properly
        open array value parameters are copied onto the heap
      }
      Include(CurrentProcInfo.Flags, pi_has_open_array_parameter);

      { calculate necessary memory }

      { read/write operations on one register make the life of the register allocator hard }
      if not(LenLoc.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
        begin
          LenReg:=GetIntRegister(List,SIntType);
          A_Load_Loc_Reg(List,SIntType,SIntType,LenLoc,LenReg);
        end
      else
        LenReg:=LenLoc.Register;

      SizeReg:=GetIntRegister(List,SIntType);
      A_Op_Const_Reg_Reg(List,OP_ADD,SIntType,1,LenReg,SizeReg);
      A_Op_Const_Reg(List,OP_IMUL,SIntType,ArrDef.EleSize,SizeReg);
      { load source }
      PtrArrDef:=CPointerDef.GetReusable(ArrDef);
      SourceReg:=GetAddressRegister(List,PtrArrDef);
      A_LoadAddr_Ref_Reg(List,ArrDef,PtrArrDef,Ref,SourceReg);

      { do getmem call }
      PD:=Search_System_Proc('fpc_getmem');
      CGPara1.Init;
      ParaManager.GetCGTempParaLoc(List,PD,1,CGPara1);
      A_Load_Reg_CGPara(List,SIntType,SizeReg,CGPara1);
      ParaManager.FreeCGPara(List,CGPara1);
      GetMemRes:=G_Call_System_Proc(List,PD,[@CGPara1],PtrArrDef);
      CGPara1.Done;
      { return the new address }
      Location_Reset(DestLoc,LOC_REGISTER,OS_ADDR);
      DestLoc.Register:=DestReg;
      Gen_Load_CGPara_Loc(List,PtrArrDef,GetMemRes,DestLoc,False);

      { do move call }
      PD:=Search_System_Proc('MOVE');
      CGPara1.Init;
      CGPara2.Init;
      CGPara3.Init;
      ParaManager.GetCGTempParaLoc(List,PD,1,CGPara1);
      ParaManager.GetCGTempParaLoc(List,PD,2,CGPara2);
      ParaManager.GetCGTempParaLoc(List,PD,3,CGPara3);
      if PD.Is_PushLeftRight then
        begin
          { load source }
          A_Load_Reg_CGPara(List,PtrArrDef,SourceReg,CGPara1);
          { load destination }
          A_Load_Reg_CGPara(List,PtrArrDef,DestReg,CGPara2);
          { load size }
          A_Load_Reg_CGPara(List,SizeSIntType,SizeReg,CGPara3);
        end
      else
        begin
          { load size }
          A_Load_Reg_CGPara(List,SizeSIntType,SizeReg,CGPara3);
          { load destination }
          A_Load_Reg_CGPara(List,PtrArrDef,DestReg,CGPara2);
          { load source }
          A_Load_Reg_CGPara(List,PtrArrDef,SourceReg,CGPara1);
        end;
      ParaManager.FreeCGPara(List,CGPara3);
      ParaManager.FreeCGPara(List,CGPara2);
      ParaManager.FreeCGPara(List,CGPara1);
      G_Call_System_Proc(List,PD,[@CGPara1,@CGPara2,@CGPara3],nil).ResetIfTemp;
      CGPara3.Done;
      CGPara2.Done;
      CGPara1.Done;
      GetMemRes.ResetIfTemp;
    end;

  procedure THLCGObj.G_ReleaseValuePara_OpenArray(List: TAsmList; ArrDef: TArrayDef; const L: TLocation);
    var
      CGPara1 : TCGPara;
      PD : TProcDef;
    begin
      { do freemem call }
      PD:=Search_System_Proc('fpc_freemem');
      CGPara1.Init;
      ParaManager.GetCGTempParaLoc(List,PD,1,CGPara1);
      { load source }
      A_Load_Loc_CGPara(List,CPointerDef.GetReusable(ArrDef),L,CGPara1);
      ParaManager.FreeCGPara(List,CGPara1);
      G_Call_System_Proc(List,PD,[@CGPara1],nil).ResetIfTemp;
      CGPara1.Done;
    end;

  procedure THLCGObj.A_Jmp_External_Name(List: TAsmList; const ExternalName: TSymStr);
    begin
      CG.A_Jmp_Name(List,ExternalName);
    end;

  procedure THLCGObj.G_External_Wrapper(List: TAsmList; ProcDef: TProcDef; const WrapperName, ExternalName: string; Global: Boolean);
    var
      Sym: TAsmSymbol;
    begin
      maybe_new_object_file(List);
      new_section(List,sec_code,WrapperName,TargetInfo.Alignment.ProcAlign);
      if Global then
        begin
          Sym:=CurrentAsmData.DefineAsmSymbol(WrapperName,AB_GLOBAL,AT_FUNCTION,ProcDef);
          List.Concat(TAISymbol.Create_global(Sym,0));
        end
      else
        begin
          Sym:=CurrentAsmData.DefineAsmSymbol(WrapperName,AB_PRIVATE_EXTERN,AT_FUNCTION,ProcDef);
          List.Concat(TAISymbol.Create(Sym,0));
        end;
      A_Jmp_External_Name(List,ExternalName);
      List.Concat(TAISymbolEnd.Create(Sym));
    end;

  procedure THLCGObj.G_AllocLoad_Reg_Reg(List: TAsmList; RegSize: TDef; const FromReg: TRegister; out ToReg: TRegister; RegTyp: TRegisterType);
    begin
      case RegTyp of
        R_INTREGISTER:
          ToReg:=GetIntRegister(List,RegSize);
        R_ADDRESSREGISTER:
          ToReg:=GetAddressRegister(List,RegSize);
        R_FPUREGISTER:
          ToReg:=GetFPURegister(List,RegSize);
        else
          InternalError(2013112910);
      end;
      A_Load_Reg_Reg(List,RegSize,RegSize,FromReg,ToReg);
    end;

  procedure THLCGObj.G_Reference_Loc(List: TAsmList; Def: TDef; const FromLoc: TLocation; out ToLoc: TLocation);

    procedure HandleRegMove(RegSize: TDef; const FromReg: TRegister; out ToReg: TRegister; RegTyp: TRegisterType);
      begin
        case RegTyp of
          R_INTREGISTER:
            ToReg:=GetIntRegister(List,RegSize);
          R_ADDRESSREGISTER:
            ToReg:=GetAddressRegister(List,RegSize);
          R_FPUREGISTER:
            ToReg:=GetFPURegister(List,RegSize);
        else
          InternalError(2013112915);
        end;
        A_Load_Reg_Reg(List,RegSize,RegSize,FromReg,ToReg);
      end;

    begin
      ToLoc:=FromLoc;
      case FromLoc.Loc of
        { volatile location, can't get a permanent reference }
        LOC_REGISTER,
        LOC_FPUREGISTER:
          InternalError(2012012702);
        LOC_CONSTANT:
          { finished }
          ;
        LOC_CREGISTER:
          HandleRegMove(Def,FromLoc.Reference.Index,ToLoc.Reference.Index,R_INTREGISTER);
        LOC_CFPUREGISTER:
          HandleRegMove(Def,FromLoc.Reference.Index,ToLoc.Reference.Index,R_FPUREGISTER);
        { although LOC_CREFERENCE cannot be an lvalue, we may want to take a
          reference to such a location for multiple reading }
        LOC_CREFERENCE,
        LOC_REFERENCE:
          begin
            if (FromLoc.Reference.Base<>NR_NO) and
               (FromLoc.Reference.Base<>CurrentProcInfo.FramePointer) and
               (FromLoc.Reference.Base<>NR_STACK_POINTER_REG) then
              HandleRegMove(VoidPointerType,FromLoc.Reference.Base,ToLoc.Reference.Base,GetRegType(FromLoc.Reference.Base));
            if (FromLoc.Reference.Index<>NR_NO) and
               (FromLoc.Reference.Index<>CurrentProcInfo.FramePointer) and
               (FromLoc.Reference.Index<>NR_STACK_POINTER_REG) then
              HandleRegMove(VoidPointerType,FromLoc.Reference.Index,ToLoc.Reference.Index,GetRegType(FromLoc.Reference.Index));
          end;
        else
          InternalError(2012012701);
      end;
    end;

  procedure THLCGObj.G_PtrTypeCast_Reg(List: TAsmList; FromDef, ToDef: TDef; var Reg: TRegister);
    begin
      { nothing to do }
    end;

  procedure THLCGObj.G_PtrTypeCast_Ref(List: TAsmList; FromDef, ToDef: TDef; var Ref: TReference);
    begin
      { nothing to do }
    end;

  procedure THLCGObj.G_Set_Addr_NonBitPacked_Field_Ref(List: TAsmList; RecDef: TAbstractRecordDef; Field: TFieldVarSym; var RecRef: TReference);
    begin
      Inc(RecRef.Offset,Field.FieldOffset);
      RecRef.Alignment:=NewAlignment(RecRef.Alignment,Field.FieldOffset);
    end;


  procedure THLCGObj.G_Undefined_Ok(List: TAsmList; Size: TDef; Reg: TRegister);
    begin
      { nothing by default }
    end;


  procedure THLCGObj.G_Setup_Load_Field_By_Name(List: TAsmList; RecDef: TRecordDef; const Name: TIDString; const RecRef: TReference; out FRef: TReference; out FieldDef: TDef);
    var
      Sym: TSym;
      Field: TFieldVarSym;
    begin
      Sym:=Search_Struct_Member(RecDef,Name);
      if not Assigned(Sym) or
         (Sym.Typ<>FieldVarSym) then
        InternalError(2015111901);
      Field:=TFieldVarSym(Sym);
      FRef:=RecRef;
      FieldDef:=Field.VarDef;
      G_Set_Addr_NonBitPacked_Field_Ref(List,RecDef,Field,FRef);
    end;


  procedure THLCGObj.G_Load_Reg_Field_By_Name(List: TAsmList; RegSize: TDef; RecDef: TRecordDef; Reg: TRegister; const Name: TIDString; const RecRef: TReference);
    var
      FRef: TReference;
      FieldDef: TDef;
    begin
      G_Setup_Load_Field_By_Name(List,RecDef,Name,RecRef,FRef,FieldDef);
      A_Load_Reg_Ref(List,RegSize,FieldDef,Reg,FRef);
    end;


  procedure THLCGObj.G_Load_Const_Field_By_Name(List: TAsmList; RecDef: TRecordDef; A: TCGInt; const Name: TIDString; const RecRef: TReference);
    var
      FRef: TReference;
      FieldDef: TDef;
    begin
      G_Setup_Load_Field_By_Name(List,RecDef,Name,RecRef,FRef,FieldDef);
      A_Load_Const_Ref(List,FieldDef,A,FRef);
    end;


  procedure THLCGObj.G_Load_Field_Reg_By_Name(List: TAsmList; RecDef: TRecordDef; RegSize: TDef; const Name: TIDString; const RecRef: TReference; Reg: TRegister);
    var
      FRef: TReference;
      FieldDef: TDef;
    begin
      G_Setup_Load_Field_By_Name(List,RecDef,Name,RecRef,FRef,FieldDef);
      A_Load_Ref_Reg(List,FieldDef,RegSize,FRef,Reg);
    end;


  procedure THLCGObj.G_Force_Field_Reg_By_Name(List: TAsmList; RecDef: TRecordDef; const Name: TIDString; const RecRef: TReference; out RegDef: TDef; out Reg: TRegister);
    var
      FRef: TReference;
    begin
      G_Setup_Load_Field_By_Name(List,RecDef,Name,RecRef,FRef,RegDef);
      Reg:=GetRegisterForDef(List,RegDef);
      A_Load_Ref_Reg(List,RegDef,RegDef,FRef,Reg);
    end;


  procedure THLCGObj.Location_Force_Reg(List: TAsmList; var L: TLocation; SourceType, DestType: TDef; MaybeConst: Boolean);
    var
      HRegister,
      HRegister2: TRegister;
      HL : TAsmLabel;
      OldLoc : TLocation;
    begin
      OldLoc:=L;
      HRegister:=GetRegisterForDef(List,DestType);
      { load value in new register }
      case L.Loc of
{$ifdef cpuflags}
        LOC_FLAGS :
          begin
            G_Flags2Reg(List,DestType,L.ResFlags,HRegister);
            CG.A_Reg_Dealloc(List,NR_DEFAULTFLAGS);
          end;
{$endif cpuflags}
        LOC_JUMP :
          begin
            A_Label(List,L.TrueLabel);
            if Is_CBool(SourceType) then
              A_Load_Const_Reg(List,DestType,-1,HRegister)
            else
              A_Load_Const_Reg(List,DestType,1,HRegister);
            CurrentAsmData.GetJumpLabel(HL);
            A_Jmp_Always(List,HL);
            A_Label(List,L.FalseLabel);
            A_Load_Const_Reg(List,DestType,0,HRegister);
            A_Label(List,HL);
          end;
        else
          begin
            { load_loc_reg can only handle size >= l.size, when the
              new size is smaller then we need to adjust the size
              of the original and maybe recalculate l.register for i386 }
            if (DestType.Size<SourceType.Size) then
              begin
                HRegister2:=GetRegisterForDef(List,SourceType);

                A_Load_Loc_Reg(List,SourceType,SourceType,L,HRegister2);
                A_Load_Reg_Reg(List,SourceType,DestType,HRegister2,HRegister);
              end
            else
              A_Load_Loc_Reg(List,SourceType,DestType,L,HRegister);
          end;
      end;
      if (L.Loc <> LOC_CREGISTER) or
         not MaybeConst then
        Location_Reset(L,LOC_REGISTER,Def_CGSize(DestType))
      else
        Location_Reset(L,LOC_CREGISTER,Def_CGSize(DestType));
      L.Register:=HRegister;
      { Release temp if it was a reference }
      if OldLoc.Loc=LOC_REFERENCE then
        location_freetemp(List,OldLoc);
    end;

  procedure THLCGObj.Location_Force_FPUReg(List: TAsmList; var L: TLocation; Size: TDef; MaybeConst: Boolean);
    var
      Reg : TRegister;
    begin
      if (L.Loc<>LOC_FPUREGISTER)  and
         ((L.Loc<>LOC_CFPUREGISTER) or (not MaybeConst)) then
        begin
          { if it's in an mm register, store to memory first }
          if (L.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
            Location_Force_Mem(List,L,Size);
          Reg:=GetFPURegister(List,Size);
          A_LoadFPU_Loc_Reg(List,Size,Size,L,Reg);
          location_freetemp(List,L);
          Location_Reset(L,LOC_FPUREGISTER,L.Size);
          L.Register:=Reg;
        end;
    end;

  procedure THLCGObj.Location_Force_Mem(List: TAsmList; var L: TLocation; Size: TDef);
    var
      R : TReference;
      ForceSize: AInt;
      HRegister: TRegister;
      HL: TAsmLabel;
    begin
      case L.Loc of
        LOC_FPUREGISTER,
        LOC_CFPUREGISTER :
          begin
            TG.GetHLTemp(List,Size,Size.Size,tt_normal,R);
            A_LoadFPU_Reg_Ref(List,Size,Size,L.Register,R);
            Location_Reset_Ref(L,LOC_REFERENCE,L.Size,Size.Alignment,[]);
            L.Reference:=R;
          end;
        LOC_MMREGISTER,
        LOC_CMMREGISTER:
          begin
            { vectors can't be represented yet using tdef }
            if Size.Typ<>FloatDef then
              InternalError(2012062302);
            TG.GetHLTemp(List,Size,Size.Size,tt_normal,R);
            A_LoadMM_Reg_Ref(List,Size,Size,L.Register,R,MMS_MoveScalar);
            Location_Reset_Ref(L,LOC_REFERENCE,L.Size,Size.Alignment,[]);
            L.Reference:=R;
          end;
{$ifdef cpuflags}
        LOC_FLAGS :
          begin
            HRegister:=GetRegisterForDef(List,Size);
            G_Flags2Reg(List,Size,L.ResFlags,HRegister);
            CG.A_Reg_Dealloc(List,NR_DEFAULTFLAGS);
            TG.GetHLTemp(List,Size,Size.Size,tt_normal,R);
            A_Load_Reg_Ref(List,Size,Size,HRegister,R);
            Location_Reset_Ref(L,LOC_REFERENCE,L.Size,Size.Alignment,[]);
            L.Reference:=R;
          end;
{$endif cpuflags}
        LOC_JUMP :
          begin
            A_Label(List,L.TrueLabel);
            TG.GetHLTemp(List,Size,Size.Size,tt_normal,R);
            if Is_CBool(Size) then
              A_Load_Const_Ref(List,Size,-1,R)
            else
              A_Load_Const_Ref(List,Size,1,R);
            CurrentAsmData.GetJumpLabel(HL);
            A_Jmp_Always(List,HL);
            A_Label(List,L.FalseLabel);
            A_Load_Const_Ref(List,Size,0,R);
            A_Label(List,HL);

            Location_Reset_Ref(L,LOC_REFERENCE,L.Size,Size.Alignment,[]);
            L.Reference:=R;
          end;
        LOC_CONSTANT,
        LOC_REGISTER,
        LOC_CREGISTER,
        LOC_SUBSETREG,
        LOC_CSUBSETREG,
        LOC_SUBSETREF,
        LOC_CSUBSETREF:
          begin
            if not Is_Dynamic_Array(Size) and
               not Is_Open_Array(Size) then
              ForceSize:=Size.Size
            else
              ForceSize:=SizeOf(PInt);
            TG.GetHLTemp(List,Size,ForceSize,tt_normal,R);
            A_Load_Loc_Ref(List,Size,Size,L,R);
            Location_Reset_Ref(L,LOC_REFERENCE,L.Size,Size.Alignment,[]);
            L.Reference:=R;
          end;
        LOC_CREFERENCE,
        LOC_REFERENCE : ;
        else
          InternalError(2011010304);
      end;
    end;

  procedure THLCGObj.Location_Force_MMRegScalar(List: TAsmList; var L: TLocation; var Size: TDef; MaybeConst: Boolean);
    var
      Reg : TRegister;
      HRef : TReference;
      NewSize : TDef;
    begin
      if (L.Loc<>LOC_MMREGISTER)  and
         ((L.Loc<>LOC_CMMREGISTER) or (not MaybeConst)) then
        begin
          { if it's in an fpu register, store to memory first }
          if (L.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
            begin
              TG.GetHLTemp(List,Size,-1,tt_normal,HRef);
              HLCG.A_LoadFPU_Reg_Ref(List,Size,Size,L.Register,HRef);
              Location_Reset_Ref(L,LOC_REFERENCE,L.Size,Size.Alignment,[]);
              L.Reference:=HRef;
            end;
          { on ARM, CFP values may be located in integer registers,
            and its second_int_to_real() also uses this routine to
            force integer (memory) values in an mmregister }
          if (L.Size in [OS_32,OS_S32]) then
            begin
              Size:=CGSize_OrdDef(L.Size);
              NewSize:=S32FloatType;
            end
          else if (L.Size in [OS_64,OS_S64]) then
            begin
              Size:=CGSize_OrdDef(L.Size);
              NewSize:=S64FloatType;
            end
          else
            NewSize:=Size;
          case Size.Size of
            4:
              NewSize:=S32FloatType;
            8:
              NewSize:=S64FloatType;
            else
              NewSize:=Size;
          end;
          Reg:=HLCG.GetMMRegister(List,NewSize);
          HLCG.A_LoadMM_Loc_Reg(List,Size,NewSize,L,Reg,MMS_MoveScalar);
          L.Size:=Def_CGSize(NewSize);
          location_freetemp(List,L);
          Location_Reset(L,LOC_MMREGISTER,L.Size);
          Size:=NewSize;
          L.Register:=Reg;
        end;
    end;

    procedure THLCGObj.Location_Get_Data_Ref(List: TAsmList; Def: TDef; const L: TLocation; var Ref: TReference; LoadRef: Boolean; Alignment: LongInt);
      var
        PDef: TDef;
      begin
        case L.Loc of
          LOC_REGISTER,
          LOC_CREGISTER :
            begin
              if not LoadRef then
                InternalError(200410231);
              Reference_Reset_Base(Ref,CPointerDef.GetReusable(Def),L.Register,0,CTempPosInvalid,Alignment,[]);
            end;
          LOC_REFERENCE,
          LOC_CREFERENCE :
            begin
              if LoadRef then
                begin
                  PDef:=CPointerDef.GetReusable(Def);
                  Reference_Reset_Base(Ref,PDef,GetAddressRegister(List,VoidPointerType),0,CTempPosInvalid,Alignment,[]);
                  { it's a pointer to def }
                  A_Load_Ref_Reg(List,PDef,PDef,L.Reference,Ref.Base);
                end
              else
                Ref:=L.Reference;
            end;
          else
            InternalError(200309181);
        end;
      end;


  procedure THLCGObj.MakeToJumpBool(List: TAsmList; P: TNode);
    var
      TrueLabel,
      FalseLabel: TAsmLabel;
    begin
       if P.Location.Loc<>LOC_JUMP then
         begin
           CurrentAsmData.GetJumpLabel(TrueLabel);
           CurrentAsmData.GetJumpLabel(FalseLabel);
         end
       else
         begin
           TrueLabel:=P.Location.TrueLabel;
           FalseLabel:=P.Location.FalseLabel;
         end;
       MakeToJumpBoolLabels(List,P,TrueLabel,FalseLabel);
    end;


  procedure THLCGObj.MakeToJumpBoolLabels(List: TAsmList; P: TNode; TrueLabel, FalseLabel: TAsmLabel);
    var
      StorePos : TFilePosInfo;
    begin
       if tnf_error in P.TransientFlags then
         Exit;
       StorePos:=CurrentFilePos;
       CurrentFilePos:=P.FileInfo;
       if Is_Boolean(P.ResultDef) then
         begin
            if is_constboolnode(P) then
              begin
                 if TOrdConstNode(P).Value.UValue<>0 then
                   A_Jmp_Always(List,TrueLabel)
                 else
                   A_Jmp_Always(List,FalseLabel)
              end
            else
              begin
                 case P.Location.Loc of
                   LOC_SUBSETREG,LOC_CSUBSETREG,
                   LOC_SUBSETREF,LOC_CSUBSETREF,
                   LOC_CREGISTER,LOC_REGISTER,LOC_CREFERENCE,LOC_REFERENCE :
                     begin
                       A_Cmp_Const_Loc_Label(List,P.ResultDef,OC_NE,0,P.Location,TrueLabel);
{$ifdef x86} { x86 always uses the flags in some way for conditional jumps }
                       A_Reg_Dealloc(List,NR_DEFAULTFLAGS);
{$endif x86}
                       A_Jmp_Always(List,FalseLabel);
                     end;
                   LOC_JUMP:
                     begin
                       if TrueLabel<>P.Location.TrueLabel then
                         begin
                           A_Label(List,P.Location.TrueLabel);
                           A_Jmp_Always(List,TrueLabel);
                         end;
                       if FalseLabel<>P.Location.FalseLabel then
                         begin
                           A_Label(List,P.Location.FalseLabel);
                           A_Jmp_Always(List,FalseLabel);
                         end;
                     end;
{$ifdef cpuflags}
                   LOC_FLAGS :
                     begin
                       A_Jmp_Flags(List,P.Location.ResFlags,TrueLabel);
                       A_Reg_Dealloc(List,NR_DEFAULTFLAGS);
                       A_Jmp_Always(List,FalseLabel);
                     end;
{$endif cpuflags}
                   else
                     InternalError(2011010418);
                 end;
              end;
            Location_Reset_Jump(P.Location,TrueLabel,FalseLabel);
         end
       else
         InternalError(2011010419);
       CurrentFilePos:=StorePos;
    end;


  procedure THLCGObj.Maybe_Change_Load_Node_Reg(List: TAsmList; var N: TNode; Reload: Boolean);
    var
      RR: TReplaceRegRec;
      VarLoc : TAIVarLoc;
    begin
      if not (N.Location.Loc in [LOC_CREGISTER,LOC_CFPUREGISTER,LOC_CMMXREGISTER,LOC_CMMREGISTER]) or
        ([fc_inflowcontrol,fc_gotolabel,fc_lefthandled] * FlowControl <> []) then
        Exit;
      RR.Old := N.Location.Register;
      RR.ResSym := nil;
      RR.Sym := nil;
      RR.OldHi := NR_NO;
      case N.Location.Loc of
        LOC_CREGISTER:
          begin
{$ifdef cpu64bitalu}
            if (N.Location.Size in [OS_128,OS_S128]) then
              begin
                RR.OldHi := N.Location.Register128.RegHi;
                RR.New := CG.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
                RR.NewHi := CG.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
              end
            else
{$else cpu64bitalu}
            if (N.Location.Size in [OS_64,OS_S64]) then
              begin
                RR.OldHi := N.Location.Register64.RegHi;
                RR.New := CG.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                RR.NewHi := CG.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
              end
            else
{$endif cpu64bitalu}
              if GetRegType(RR.Old)=R_ADDRESSREGISTER then
                RR.New := HLCG.GetAddressRegister(CurrentAsmData.CurrAsmList,N.ResultDef)
              else
                RR.New := CG.GetIntRegister(CurrentAsmData.CurrAsmList,N.Location.Size);
          end;
        LOC_CFPUREGISTER:
          RR.New := CG.GetFPURegister(CurrentAsmData.CurrAsmList,N.Location.Size);
{$ifdef SUPPORT_MMX}
        LOC_CMMXREGISTER:
          RR.New := TCGX86(CG).GetMMXRegister(CurrentAsmData.CurrAsmList);
{$endif SUPPORT_MMX}
        LOC_CMMREGISTER:
          RR.New := CG.GetMMRegister(CurrentAsmData.CurrAsmList,N.Location.Size);
        else
          Exit;
      end;

      { self is implicitly returned from constructors, even if there are no
        references to it; additionally, funcretsym is not set for constructor
        procdefs }
      if (CurrentProcInfo.ProcDef.ProcTypeOption=potype_constructor) then
        RR.ResSym:=TSym(CurrentProcInfo.ProcDef.ParaST.Find('self'))
      else if not Is_Void(CurrentProcInfo.ProcDef.ReturnDef) and
         Assigned(CurrentProcInfo.ProcDef.FuncRetSym) and
         (TAbstractVarSym(CurrentProcInfo.ProcDef.FuncRetSym).Refs <> 0) then
        RR.ResSym:=CurrentProcInfo.ProcDef.FuncRetSym;

      if not ForEachNode(N,@Do_Replace_Node_Regs,@RR) then
        Exit;

      if Reload then
        case N.Location.Loc of
          LOC_CREGISTER:
            begin
{$ifdef cpu64bitalu}
              if (N.Location.Size in [OS_128,OS_S128]) then
                CG128.A_Load128_Reg_Reg(List,N.Location.Register128,JoinReg128(RR.New,RR.NewHi))
              else
{$else cpu64bitalu}
              if (N.Location.Size in [OS_64,OS_S64]) then
                CG64.A_Load64_Reg_Reg(List,N.Location.Register64,JoinReg64(RR.New,RR.NewHi))
              else
{$endif cpu64bitalu}
                A_Load_Reg_Reg(List,N.ResultDef,N.ResultDef,N.Location.Register,RR.New);
            end;
          LOC_CFPUREGISTER:
            CG.A_LoadFPU_Reg_Reg(List,N.Location.Size,N.Location.Size,N.Location.Register,RR.New);
{$ifdef SUPPORT_MMX}
          LOC_CMMXREGISTER:
            CG.A_LoadMM_Reg_Reg(List,OS_M64,OS_M64,N.Location.Register,RR.New,nil);
{$endif SUPPORT_MMX}
          LOC_CMMREGISTER:
            A_LoadMM_Reg_Reg(List,N.ResultDef,N.ResultDef,N.Location.Register,RR.New,nil);
          else
            InternalError(2006090920);
        end;

      { now that we've change the loadn/temp, also change the node result location }
{$ifdef cpu64bitalu}
      if (N.Location.Size in [OS_128,OS_S128]) then
        begin
          N.Location.Register128.RegLo := RR.New;
          N.Location.Register128.RegHi := RR.NewHi;
          if Assigned(RR.Sym) then
            begin
              VarLoc:=TAIVarLoc.Create128(RR.Sym,RR.New,RR.NewHi);
              List.Concat(VarLoc);
            end;
        end
      else
{$else cpu64bitalu}
      if (N.Location.Size in [OS_64,OS_S64]) then
        begin
          N.Location.Register64.RegLo := RR.New;
          N.Location.Register64.RegHi := RR.NewHi;
          if Assigned(RR.Sym) then
            begin
              VarLoc:=TAIVarLoc.Create64(RR.Sym,RR.New,RR.NewHi);
              List.Concat(VarLoc);
            end;
        end
      else
{$endif cpu64bitalu}
        begin
          N.Location.Register := RR.New;
          if Assigned(RR.Sym) then
            begin
              VarLoc:=TAIVarLoc.Create(RR.Sym,RR.New);
              List.Concat(VarLoc);
            end;
        end;
    end;


  function THLCGObj.Do_Replace_Node_Regs(var N: TNode; Para: Pointer): TForEachNodeResult;
    var
      RR: PReplaceRegRec absolute Para;
    begin
      Result := fen_false;
      if (nf_is_funcret in N.Flags) and (fc_exit in FlowControl) then
        Exit;
      case N.NodeType of
        LoadN:
          begin
            if (TLoadNode(N).SymTableEntry.Typ in [LocalVarSym,ParaVarSym,StaticVarSym]) and
               (TAbstractVarSym(TLoadNode(N).SymTableEntry).VarOptions * [vo_is_dll_var, vo_is_thread_var] = []) and
               not Assigned(TLoadNode(N).Left) and
               ((TLoadNode(N).SymTableEntry <> RR^.ResSym) or
                not(fc_exit in FlowControl)
               ) and
               (TAbstractNormalVarSym(TLoadNode(N).SymTableEntry).LocAlloc.Loc in [LOC_CREGISTER,LOC_CFPUREGISTER,LOC_CMMXREGISTER,LOC_CMMREGISTER]) and
               (TAbstractNormalVarSym(TLoadNode(N).SymTableEntry).LocAlloc.Register = RR^.Old) then
              begin
{$ifdef cpu64bitalu}
                { it's possible a 128 bit location was shifted and/xor typecasted }
                { in a 64 bit value, so only 1 register was left in the location }
                if (TAbstractNormalVarSym(TLoadNode(N).SymTableEntry).LocAlloc.Size in [OS_128,OS_S128]) then
                  if (TAbstractNormalVarSym(TLoadNode(N).SymTableEntry).LocAlloc.Register128.RegHi = RR^.OldHi) then
                    TAbstractNormalVarSym(TLoadNode(N).SymTableEntry).LocAlloc.Register128.RegHi := RR^.NewHi
                  else
                    Exit;
{$else cpu64bitalu}
                { it's possible a 64 bit location was shifted and/xor typecasted }
                { in a 32 bit value, so only 1 register was left in the location }
                if (TAbstractNormalVarSym(TLoadNode(N).SymTableEntry).LocAlloc.Size in [OS_64,OS_S64]) then
                  if (TAbstractNormalVarSym(TLoadNode(N).SymTableEntry).LocAlloc.Register64.RegHi = RR^.OldHi) then
                    TAbstractNormalVarSym(TLoadNode(N).SymTableEntry).LocAlloc.Register64.RegHi := RR^.NewHi
                  else
                    Exit;
{$endif cpu64bitalu}
                TAbstractNormalVarSym(TLoadNode(N).SymTableEntry).LocAlloc.Register := RR^.New;
                RR^.Sym := TAbstractNormalVarSym(TLoadNode(N).SymTableEntry);
                Result := fen_norecurse_true;
              end;
          end;
        TempRefN:
          begin
            if (ti_valid in TTempRefNode(N).TempFlags) and
               (TTempRefNode(N).TempInfo^.Location.Loc in [LOC_CREGISTER,LOC_CFPUREGISTER,LOC_CMMXREGISTER,LOC_CMMREGISTER]) and
               (TTempRefNode(N).TempInfo^.Location.Register = RR^.Old) then
              begin
{$ifdef cpu64bitalu}
                { it's possible a 128 bit location was shifted and/xor typecasted }
                { in a 64 bit value, so only 1 register was left in the location }
                if (TTempRefNode(N).TempInfo^.Location.Size in [OS_128,OS_S128]) then
                  if (TTempRefNode(N).TempInfo^.Location.Register128.RegHi = RR^.OldHi) then
                    TTempRefNode(N).TempInfo^.Location.Register128.RegHi := RR^.NewHi
                  else
                    Exit;
{$else cpu64bitalu}
                { it's possible a 64 bit location was shifted and/xor typecasted }
                { in a 32 bit value, so only 1 register was left in the location }
                if (TTempRefNode(N).TempInfo^.Location.Size in [OS_64,OS_S64]) then
                  if (TTempRefNode(N).TempInfo^.Location.Register64.RegHi = RR^.OldHi) then
                    TTempRefNode(N).TempInfo^.Location.Register64.RegHi := RR^.NewHi
                  else
                    Exit;
{$endif cpu64bitalu}
                TTempRefNode(N).TempInfo^.Location.Register := RR^.New;
                Result := fen_norecurse_true;
              end;
          end;
        { optimize the searching a bit }
        DerefN,AddrN,
        CallN,InlineN,CaseN,
        AddN,SubN,MulN,
        AndN,OrN,XorN,
        LtN,LteN,GtN,GteN,EqualN,UnequalN,
        SlashN,DivN,ShrN,ShlN,NotN,
        InN,
        ASN,IsN:
          Result := fen_norecurse_false;
        VecN:
          { we cannot do SSA during partial writes to arrays which span multiple registers, see also tw39325 }
          if (TVecNode(N).Left.Location.Loc in [LOC_CREGISTER,LOC_CFPUREGISTER,LOC_CMMXREGISTER,LOC_CMMREGISTER]) and
            (TCgSize2Size[reg_cgsize(TVecNode(N).Left.Location.Register)]<>TVecNode(N).Left.ResultDef.Size) then
            Result := fen_norecurse_false;
        else
          ;
      end;
    end;


  procedure THLCGObj.Gen_Proc_Symbol(List: TAsmList);
    begin
      FPHLCGObjHelper.Gen_Proc_Symbol(List);
    end;

  procedure THLCGObj.Gen_Proc_Symbol_End(List: TAsmList);
    begin
      if nexus_profile_proc_eligible(CurrentProcInfo) then
        begin
          if not Assigned(CurrentProcInfo.nexus_profile_endlabel) then
            CurrentAsmData.GetJumpLabel(CurrentProcInfo.nexus_profile_endlabel);
          List.Concat(TAILabel.Create(CurrentProcInfo.nexus_profile_endlabel));
          Emit_Nexus_Profile_Descriptor;
        end;
      if (CurrentProcInfo.ProcDef.ProcTypeOption=potype_proginit) and
         (cs_nexus_profile in CurrentSettings.ModuleSwitches) and
         (TargetInfo.System=system_x86_64_win64) and
         not CurrentModule.IsLibrary then
        Emit_Nexus_Profile_Module_Data;
      List.Concat(TAISymbolEnd.Createname(CurrentProcInfo.ProcDef.MangledName));
      CurrentProcInfo.ProcDef.ProcEndTAI:=TAI(List.Last);
    end;


  procedure THLCGObj.Handle_External_Proc(List: TAsmList; PD: TProcDef; const ImportName: TSymStr);
    begin
      { External declared in implementation, and there was already a
        forward (or interface) declaration then we need to generate
        a stub that calls the external routine }
      if (not PD.ForwardDef) and
         (PD.HasForward) then
        begin
          if ImportName<>'' then
            begin
             { add the procedure to the al_procedures }
             G_External_Wrapper(List,PD,PD.MangledName,ImportName,True);
            end;
          { remove the external stuff, so that the interface crc
            doesn't change. This makes the function calls less
            efficient, but it means that the interface doesn't
            change if the function is ever redirected to another
            function or implemented in the unit. }
          PD.ProcOptions:=PD.ProcOptions-[po_external,po_has_importname,po_has_importdll];
          StringDispose(PD.ImportName);
          StringDispose(PD.ImportDLL);
          PD.ImportNr:=0;
        end;
    end;


  procedure THLCGObj.Gen_Initialize_Code(List: TAsmList);
    begin
      { initialize global register variables }
      case CurrentProcInfo.ProcDef.ProcTypeOption of
        potype_unitinit,
        potype_proginit:
          TSymTable(CurrentModule.LocalSymTable).SymList.ForEachCall(@Initialize_RegVars,List);
        else
          ;
      end;

      { initialises temp. ansi/wide string data }
      if (CurrentProcInfo.ProcDef.ProcTypeOption<>potype_exceptfilter) or
         (TargetInfo.System=system_aarch64_win64) then
        InitTempVariables(List);
    end;

  procedure THLCGObj.Gen_Finalize_Code(List: TAsmList);
    var
      OldCurrentProcInfo: TProcInfo;
      ForFinalization: Boolean;
    begin
      OldCurrentProcInfo:=CurrentProcInfo;
      ForFinalization:=False;
      if (CurrentProcInfo.ProcDef.ProcTypeOption=potype_exceptfilter) then
        begin
          if (CurrentProcInfo.Parent.finalize_procinfo<>CurrentProcInfo) then
            Exit;
          CurrentProcInfo:=CurrentProcInfo.Parent;
          ForFinalization:=True;
        end;

      { finalize paras data }
      if Assigned(CurrentProcInfo.ProcDef.ParaST) and
         not(po_assembler in CurrentProcInfo.ProcDef.ProcOptions) then
        CurrentProcInfo.ProcDef.ParaST.SymList.ForEachCall(@Final_Paras,List);

      { finalize temporary data }
      FinalizeTempVariables(List,ForFinalization);

      CurrentProcInfo:=OldCurrentProcInfo;
    end;

  procedure THLCGObj.VarSym_Set_LocAlloc(List: TAsmList; VS: TAbstractNormalVarSym);
    begin
      if cs_asm_source in CurrentSettings.GlobalSwitches then
        begin
          case VS.InitialLoc.Loc of
            LOC_REFERENCE :
              begin
                if not Assigned(VS.InitialLoc.Reference.Symbol) then
                  List.Concat(TAIComment.Create(StrPNew('Var '+VS.RealName+' located at '+
                     std_regname(VS.InitialLoc.Reference.Base)+ToStr_With_Plus(VS.InitialLoc.Reference.Offset)+
                     ', size='+TCgSize2Str(VS.InitialLoc.Size))));
              end;
            else
              ;
          end;
        end;
      VS.LocAlloc:=VS.InitialLoc;
    end;

  procedure THLCGObj.ParaVarSym_Set_InitialLoc_To_ParaLoc(VS: TParaVarSym);
    begin
      Reference_Reset_Base(VS.InitialLoc.Reference,VoidStackPointerType,TParaVarSym(VS).ParaLoc[CalleeSide].Location^.Reference.Index,
          TParaVarSym(VS).ParaLoc[CalleeSide].Location^.Reference.Offset,CTempPosInvalid,
          TParaVarSym(VS).ParaLoc[CalleeSide].Alignment,[]);
    end;

  procedure THLCGObj.Gen_Entry_Code(List: TAsmList);
    begin
      { call startup helpers from main program }
      if (CurrentProcInfo.ProcDef.ProcTypeOption=potype_proginit) then
       begin
         if cs_nexus_profile in CurrentSettings.ModuleSwitches then
           Gen_Nexus_Profile_Module_Call(List,'nxp_module_register');
         { initialize units }
         if not(CurrentModule.IsLibrary) then
           begin
             if tf_init_final_units_by_calls in TargetInfo.Flags then
               begin
                 { Only insert call if there are init functions }
                 if CNodeUtils.has_init_list then
                   CG.A_Call_Name(List,'FPC_INIT_FUNC_TABLE',False);
               end
             else
               G_Call_System_Proc(List,'fpc_initializeunits',[],nil).ResetIfTemp;
           end
         else
           G_Call_System_Proc(List,'fpc_libinitializeunits',[],nil).ResetIfTemp;
       end;

      { The program body starts after its units. The image was already
        registered before unit initialization. }
      if nexus_profile_proc_eligible(CurrentProcInfo) then
        Gen_Nexus_Profile_Call(List,'nxp_enter');

      List.Concat(TAIForceLine.Create);
    end;

  procedure THLCGObj.Gen_Exit_Code(List: TAsmList);
    begin
      { TODO: create high level version (create compilerproc in system unit,
          look up procdef, use hlcgobj.a_call_name()) }

      if nexus_profile_proc_eligible(CurrentProcInfo) then
        Gen_Nexus_Profile_Call(List,'nxp_leave');

      { call __EXIT for main program }
      if (not CurrentModule.IsLibrary) and
         (CurrentProcInfo.ProcDef.ProcTypeOption=potype_proginit) then
        G_Call_System_Proc(List,'fpc_do_exit',[],nil).ResetIfTemp;
    end;

{$push}{$Q-}
  function NexusProfileHash64(const S: AnsiString): QWord;
    var
      I: SizeInt;
    begin
      Result:=QWord($CBF29CE484222325);
      for I:=1 to Length(S) do
        begin
          Result:=Result xor Byte(S[I]);
          Result:=Result*QWord($100000001B3);
        end;
    end;
{$pop}

  procedure EnsureNexusProfileDescriptorSymbol;
    var
      SymName: string;
    begin
      if Assigned(CurrentProcInfo.nexus_profile_descsym) then
        Exit;
      SymName:='NXP_DESC_'+CurrentModule.ModuleName^+'_'+
        CurrentProcInfo.ProcDef.UniqueIDStr;
      CurrentProcInfo.nexus_profile_descsym:=CurrentAsmData.DefineAsmSymbol(
        SymName,AB_LOCAL,AT_DATA,VoidPointerType);
    end;

  procedure THLCGObj.Gen_Nexus_Profile_Call(List:TAsmList; const HookName:TIDString);
    var
      Para: TCGPara;
      ParaLoc: PCGParaLocation;
      HRef: TReference;
    begin
      EnsureNexusProfileDescriptorSymbol;
{$ifdef x86_64}
      CurrentModule.Add_Extern_AsmSym(HookName,AB_EXTERNAL,AT_FUNCTION);
      Para.Init;
      Para.Def:=VoidPointerType;
      Para.Size:=OS_ADDR;
      Para.IntSize:=SizeOf(PInt);
      ParaLoc:=Para.Add_Location;
      ParaLoc^.Def:=VoidPointerType;
      ParaLoc^.Size:=OS_ADDR;
      ParaLoc^.Loc:=LOC_REGISTER;
      ParaLoc^.Register:=NR_RCX;
      Reference_Reset_Symbol(HRef,CurrentProcInfo.nexus_profile_descsym,0,
        SizeOf(PInt),[]);
      A_LoadAddr_Ref_CGPara(List,VoidPointerType,HRef,Para);
      AllocAllCPURegisters(List);
      CG.A_Call_Name(List,HookName,False);
      DeallocAllCPURegisters(List);
      Para.Done;
{$else x86_64}
      InternalError(2026092301);
{$endif x86_64}
    end;

  procedure THLCGObj.Gen_Nexus_Profile_Module_Call(List:TAsmList;
    const HookName:TIDString);
    var
      Para: TCGPara;
      ParaLoc: PCGParaLocation;
      HRef: TReference;
      ModuleSym: TAsmSymbol;
    begin
{$ifdef x86_64}
      CurrentModule.Add_Extern_AsmSym(HookName,AB_EXTERNAL,AT_FUNCTION);
      ModuleSym:=CurrentAsmData.RefAsmSymbol('__NXP_module_descriptor',AT_DATA);
      Para.Init;
      Para.Def:=VoidPointerType;
      Para.Size:=OS_ADDR;
      Para.IntSize:=SizeOf(PInt);
      ParaLoc:=Para.Add_Location;
      ParaLoc^.Def:=VoidPointerType;
      ParaLoc^.Size:=OS_ADDR;
      ParaLoc^.Loc:=LOC_REGISTER;
      ParaLoc^.Register:=NR_RCX;
      Reference_Reset_Symbol(HRef,ModuleSym,0,SizeOf(PInt),[]);
      A_LoadAddr_Ref_CGPara(List,VoidPointerType,HRef,Para);
      AllocAllCPURegisters(List);
      CG.A_Call_Name(List,HookName,False);
      DeallocAllCPURegisters(List);
      Para.Done;
{$else x86_64}
      InternalError(2026092302);
{$endif x86_64}
    end;

  procedure THLCGObj.Emit_Nexus_Profile_Descriptor;
    const
      NXP_DESC_MAGIC = $4450584E; { NXPD }
      NXP_DESC_ABI = 1;
      NXP_DESC_SIZE = 72;
    var
      PD: TProcDef;
      Key,Name,ProfUnitName,Source: AnsiString;
      StableID: QWord;
      NameLabel,UnitLabel,SourceLabel: TAsmLabOfs;
      SourceFile: TInputFile;
      Section: TAISection;
      TCB: TTAITypedConstBuilder;
    begin
      EnsureNexusProfileDescriptorSymbol;
      PD:=CurrentProcInfo.ProcDef;
      Name:=PD.FullProcName(True);
      ProfUnitName:=CurrentModule.RealModuleName^;
      SourceFile:=Get_Source_File(CurrentProcInfo.EntryPos.ModuleIndex,
        CurrentProcInfo.EntryPos.FileIndex);
      if Assigned(SourceFile) then
        Source:=SourceFile.Path+SourceFile.Name
      else
        Source:='';
      Key:=ProfUnitName+'|'+Name+'|'+PD.MangledName+'|'+PD.UniqueIDStr;
      StableID:=NexusProfileHash64(Key);
      TCB:=CTAITypedConstBuilder.Create([]);
      if Name='' then
        NameLabel:=TCB.emit_ansistring_const(CurrentAsmData.AsmLists[al_const],
          nil,0,GetAnsiStringCodePage)
      else
        NameLabel:=TCB.emit_ansistring_const(CurrentAsmData.AsmLists[al_const],
          @Name[1],Length(Name),GetAnsiStringCodePage);
      if ProfUnitName='' then
        UnitLabel:=TCB.emit_ansistring_const(CurrentAsmData.AsmLists[al_const],
          nil,0,GetAnsiStringCodePage)
      else
        UnitLabel:=TCB.emit_ansistring_const(CurrentAsmData.AsmLists[al_const],
          @ProfUnitName[1],Length(ProfUnitName),GetAnsiStringCodePage);
      if Source='' then
        SourceLabel:=TCB.emit_ansistring_const(CurrentAsmData.AsmLists[al_const],
          nil,0,GetAnsiStringCodePage)
      else
        SourceLabel:=TCB.emit_ansistring_const(CurrentAsmData.AsmLists[al_const],
          @Source[1],Length(Source),GetAnsiStringCodePage);
      TCB.Free;
      Section:=new_section(CurrentProcInfo.AktLocalData,sec_user,
        '.nxprof$M_'+HexStr(Int64(StableID),16),3);
      CurrentProcInfo.nexus_profile_section:=Section;
      CurrentProcInfo.AktLocalData.Concat(TAISymbol.Create(
        CurrentProcInfo.nexus_profile_descsym,NXP_DESC_SIZE));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_32bit(NXP_DESC_MAGIC));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_16bit(NXP_DESC_ABI));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_16bit(0));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_32bit(0));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_32bit(0));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_64bit(Int64(StableID)));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_sym(
        CurrentAsmData.RefAsmSymbol(PD.MangledName,AT_FUNCTION)));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_sym(
        CurrentProcInfo.nexus_profile_endlabel));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_sym_offset(
        NameLabel.Lab,NameLabel.Ofs));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_sym_offset(
        UnitLabel.Lab,UnitLabel.Ofs));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_sym_offset(
        SourceLabel.Lab,SourceLabel.Ofs));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_32bit(
        CurrentProcInfo.EntryPos.Line));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_32bit(
        CurrentProcInfo.EntryPos.Column));
    end;

  procedure THLCGObj.Emit_Nexus_Profile_Module_Data;
    const
      NXP_MODULE_MAGIC = $4D50584E; { NXPM }
      NXP_MODULE_ABI = 1;
      NXP_MODULE_SIZE = 32;
    var
      StartSection,EndSection,ModuleSection: TAISection;
      StartSym,EndSym,ModuleSym: TAsmSymbol;
    begin
      StartSym:=CurrentAsmData.DefineAsmSymbol('__NXP_descriptor_start',
        AB_GLOBAL,AT_DATA,VoidPointerType);
      EndSym:=CurrentAsmData.DefineAsmSymbol('__NXP_descriptor_end',
        AB_GLOBAL,AT_DATA,VoidPointerType);
      ModuleSym:=CurrentAsmData.DefineAsmSymbol('__NXP_module_descriptor',
        AB_GLOBAL,AT_DATA,VoidPointerType);

      ModuleSection:=new_section(CurrentProcInfo.AktLocalData,sec_user,
        '.nxprof$0',3);
      CurrentProcInfo.AktLocalData.Concat(TAISymbol.create_global(ModuleSym,
        NXP_MODULE_SIZE));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_32bit(
        NXP_MODULE_MAGIC));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_16bit(
        NXP_MODULE_ABI));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_16bit(0));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_32bit(0));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_32bit(0));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_sym_offset(
        StartSym,SizeOf(QWord)));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_sym(EndSym));

      StartSection:=new_section(CurrentProcInfo.AktLocalData,sec_user,
        '.nxprof$A',3);
      CurrentProcInfo.AktLocalData.Concat(TAISymbol.create_global(StartSym,
        SizeOf(QWord)));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_64bit(0));

      EndSection:=new_section(CurrentProcInfo.AktLocalData,sec_user,
        '.nxprof$Z',3);
      CurrentProcInfo.AktLocalData.Concat(TAISymbol.create_global(EndSym,
        SizeOf(QWord)));
      CurrentProcInfo.AktLocalData.Concat(TAIConst.create_64bit(0));
      { Keep the locals assigned so builds with internal consistency checks can
        verify all three explicit sections were created. }
      if not Assigned(ModuleSection) or not Assigned(StartSection) or
         not Assigned(EndSection) then
        InternalError(2026092303);
    end;

  procedure THLCGObj.InitTempVariables(List: TAsmList);
    var
      HP : PTempRecord;
      HRef : TReference;
    begin
      HP:=TG.TempList;
      while Assigned(HP) do
       begin
         if HP^.Fini and
            Assigned(HP^.Def) and
            Is_Managed_Type(HP^.Def) then
          begin
            TG.temp_to_ref(HP,HRef);
            { On AArch64-Win64 exceptfilters have their own SP-relative temps
              but share the parent's temp allocator. Parent temps are already
              initialised by the parent; only handler-local temps need zeroing.
              adjust_exceptfilter_ref converts parent temps to FP-relative,
              so if the base changed from the framepointer it is a parent temp. }
            if (CurrentProcInfo.ProcDef.ProcTypeOption=potype_exceptfilter) then
              begin
                CG.Adjust_ExceptFilter_Ref(HRef,False);
                if HRef.Base<>CurrentProcInfo.FramePointer then
                  begin
                    HP:=HP^.Next;
                    Continue;
                  end;
              end;
            G_Initialize(List,HP^.Def,HRef);
          end;
         HP:=HP^.Next;
       end;
    end;

  procedure THLCGObj.FinalizeTempVariables(List: TAsmList;ForFinalization:Boolean);
    var
      HP : PTempRecord;
      HRef : TReference;
    begin
      HP:=TG.TempList;
      while Assigned(HP) do
       begin
         if HP^.Fini and
            Assigned(HP^.Def) and
            Is_Managed_Type(HP^.Def) then
          begin
            Include(CurrentProcInfo.Flags,pi_needs_implicit_finally);
            TG.temp_to_ref(HP,HRef);
            if ForFinalization then
              CG.Adjust_ExceptFilter_Ref(HRef,True);
            G_Finalize(List,HP^.Def,HRef);
          end;
         HP:=HP^.Next;
       end;
    end;

  procedure THLCGObj.Initialize_RegVars(P: TObject; Arg: Pointer);
    var
      HRef : TReference;
      MMReg : TRegister;
    begin
      if (TSym(P).Typ=StaticVarSym) and not(TStaticVarSym(P).NoRegVarInitNeeded) then
       begin
         { Static variables can have the initialloc only set to LOC_CxREGISTER
           or LOC_INVALID, for explanation see gen_alloc_symtable (PFV) }
         case TStaticVarSym(P).InitialLoc.Loc of
           LOC_CREGISTER :
             begin
{$ifdef cpu64bitalu}
               if (TStaticVarSym(P).InitialLoc.Size in [OS_128,OS_S128]) then
                 CG128.A_Load128_Const_Reg(TAsmList(Arg),0,0,TStaticVarSym(P).InitialLoc.Register128)
               else
{$else cpu64bitalu}
               if (TStaticVarSym(P).InitialLoc.Size in [OS_64,OS_S64]) then
                 CG64.A_Load64_Const_Reg(TAsmList(Arg),0,TStaticVarSym(P).InitialLoc.Register64)
               else
{$endif cpu64bitalu}
                 A_Load_Const_Reg(TAsmList(Arg),TStaticVarSym(P).VarDef,0,
                     TStaticVarSym(P).InitialLoc.Register);
             end;
           LOC_CMMREGISTER :
             begin
               { clear the whole register }
               MMReg:=NewReg(R_MMREGISTER,GetSupReg(TStaticVarSym(P).InitialLoc.Register),R_SUBMMWHOLE);
               A_OpMM_Reg_Reg(TAsmList(Arg),OP_XOR,TStaticVarSym(P).VarDef, MMReg, MMReg,
                 { as we pass shuffle=nil, we have to pass a full register }
                 nil);
             end;
           LOC_CFPUREGISTER :
             begin
               { initialize fpu regvar by loading from memory }
               Reference_Reset_Symbol(HRef,
                 CurrentAsmData.RefAsmSymbol(TStaticVarSym(P).MangledName,AT_DATA), 0,
                 Var_Align(TStaticVarSym(P).VarDef.Alignment),[]);
               A_LoadFPU_Ref_Reg(TAsmList(Arg), TStaticVarSym(P).VarDef,
                 TStaticVarSym(P).VarDef, HRef, TStaticVarSym(P).InitialLoc.Register);
             end;
           LOC_INVALID :
             ;
           else
             InternalError(200410124);
         end;
       end;
    end;

  procedure THLCGObj.Final_Paras(P: TObject; Arg: Pointer);
    var
      List : TAsmList;
      HRef : TReference;
      HSym : TParaVarSym;
      ElDef : TDef;
      HighLoc : TLocation;
    begin
      if not(TSym(P).Typ=ParaVarSym) then
        Exit;
      List:=TAsmList(Arg);
      if Is_Managed_Type(TParaVarSym(P).VarDef) then
       begin
         if (TParaVarSym(P).VarSpez=vs_value) then
          begin
            Include(CurrentProcInfo.Flags,pi_needs_implicit_finally);
            Location_Get_Data_Ref(List,TParaVarSym(P).VarDef,TParaVarSym(P).LocAlloc,HRef,
              Is_Open_Array(TParaVarSym(P).VarDef) or
              ((TargetInfo.System in systems_caller_copy_addr_value_para) and
               ParaManager.Push_Addr_Param(vs_value,TParaVarSym(P).VarDef,CurrentProcInfo.ProcDef.ProcCallOption)),
              SizeOf(PInt));
            if Is_Open_Array(TParaVarSym(P).VarDef) then
              begin
                if ParaManager.Push_High_Param(TParaVarSym(P).VarSpez,TParaVarSym(P).VarDef,CurrentProcInfo.ProcDef.ProcCallOption) then
                  begin
                    HSym:=TParaVarSym(Get_High_Value_Sym(TParaVarSym(P)));
                    if not Assigned(HSym) then
                      InternalError(201003032);
                    HighLoc:=HSym.InitialLoc;
                    { adjust high bound reference for exceptfilter finalization }
                    if Assigned(CurrentProcInfo.finalize_procinfo) and
                       (CurrentProcInfo.finalize_procinfo.ProcDef.ProcTypeOption=potype_exceptfilter) and
                       (HighLoc.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                      CG.Adjust_ExceptFilter_Ref(HighLoc.Reference,True);
                  end
                else
                  HighLoc.Loc:=LOC_INVALID;
                ElDef:=TArrayDef(TParaVarSym(P).VarDef).ElementDef;
                G_PtrTypeCast_Ref(List,CPointerDef.GetReusable(TParaVarSym(P).VarDef),CPointerDef.GetReusable(ElDef),HRef);
                G_Array_RTTI_Helper(List,ElDef,HRef,HighLoc,'fpc_finalize_array');
              end
            else
              G_Finalize(List,TParaVarSym(P).VarDef,HRef);
          end;
       end;
      { open arrays can contain elements requiring init/final code, so the else has been removed here }
      if not(TargetInfo.System in systems_caller_copy_addr_value_para) and
         (TParaVarSym(P).VarSpez=vs_value) and
         (Is_Open_Array(TParaVarSym(P).VarDef) or
          Is_Array_Of_Const(TParaVarSym(P).VarDef)) then
        begin
          { cdecl functions don't have a high pointer so it is not possible to generate
            a local copy }
          if not(CurrentProcInfo.ProcDef.ProcCallOption in CDecl_PoCalls) then
            G_ReleaseValuePara_OpenArray(List,TArrayDef(TParaVarSym(P).VarDef),TParaVarSym(P).LocAlloc);
        end;
    end;


{ generates the code for incrementing the reference count of parameters and
  initialize out parameters }
  { generates the code for incrementing the reference count of parameters and
    initialize out parameters }
  procedure THLCGObj.Init_Paras(P:TObject;Arg:Pointer);
    var
      HRef : TReference;
      HSym : TParaVarSym;
      ElDef : TDef;
      List : TAsmList;
      HighLoc : TLocation;
      NeedsInitTable  : Boolean;
    begin
      List:=TAsmList(Arg);
      if (TSym(P).Typ=ParaVarSym) then
       begin
         NeedsInitTable:=Is_Managed_Type(TParaVarSym(P).VarDef);
         case TParaVarSym(P).VarSpez of
           vs_value :
             if NeedsInitTable then
               begin
                 { variants are already handled by the call to fpc_variant_copy_overwrite if
                   they are passed by reference }
                 if not((TParaVarSym(P).VarDef.Typ=VariantDef) and
                   ParaManager.Push_Addr_Param(TParaVarSym(P).VarSpez,TParaVarSym(P).VarDef,CurrentProcInfo.ProcDef.ProcCallOption)) then
                   begin
                     Location_Get_Data_Ref(List,TParaVarSym(P).VarDef,TParaVarSym(P).InitialLoc,HRef,
                       Is_Open_Array(TParaVarSym(P).VarDef) or
                       ((TargetInfo.System in systems_caller_copy_addr_value_para) and
                        ParaManager.Push_Addr_Param(vs_value,TParaVarSym(P).VarDef,CurrentProcInfo.ProcDef.ProcCallOption)),
                       SizeOf(PInt));
                     if Is_Open_Array(TParaVarSym(P).VarDef) then
                       begin
                         if ParaManager.Push_High_Param(TParaVarSym(P).VarSpez,TParaVarSym(P).VarDef,CurrentProcInfo.ProcDef.ProcCallOption) then
                           begin
                             HSym:=TParaVarSym(Get_High_Value_Sym(TParaVarSym(P)));
                             if not Assigned(HSym) then
                               InternalError(2010030303);
                             HighLoc:=HSym.InitialLoc
                           end
                         else
                           HighLoc.Loc:=LOC_INVALID;
                         { open arrays do not contain correct element count in their rtti,
                           the actual count must be passed separately. }
                         ElDef:=TArrayDef(TParaVarSym(P).VarDef).ElementDef;
                         G_PtrTypeCast_Ref(List,CPointerDef.GetReusable(TParaVarSym(P).VarDef),CPointerDef.GetReusable(ElDef),HRef);
                         G_Array_RTTI_Helper(List,ElDef,HRef,HighLoc,'fpc_addref_array');
                       end
                     else
                      G_IncrRefCount(List,TParaVarSym(P).VarDef,HRef);
                   end;
               end;
           vs_out :
             begin
               if NeedsInitTable then
                 begin
                   { we have no idea about the alignment at the callee side,
                     and the user also cannot specify "unaligned" here, so
                     assume worst case }
                   Location_Get_Data_Ref(List,TParaVarSym(P).VarDef,TParaVarSym(P).InitialLoc,HRef,True,1);
                   if NeedsInitTable then
                     begin
                       if Is_Open_Array(TParaVarSym(P).VarDef) then
                         begin
                           if ParaManager.Push_High_Param(TParaVarSym(P).VarSpez,TParaVarSym(P).VarDef,CurrentProcInfo.ProcDef.ProcCallOption) then
                             begin
                               HSym:=TParaVarSym(Get_High_Value_Sym(TParaVarSym(P)));
                               if not Assigned(HSym) then
                                 InternalError(2010030304);
                               HighLoc:=HSym.InitialLoc
                             end
                           else
                             HighLoc.Loc:=LOC_INVALID;
                           ElDef:=TArrayDef(TParaVarSym(P).VarDef).ElementDef;
                           G_PtrTypeCast_Ref(List,CPointerDef.GetReusable(TParaVarSym(P).VarDef),CPointerDef.GetReusable(ElDef),HRef);
                           G_Array_RTTI_Helper(List,ElDef,HRef,HighLoc,'fpc_initialize_array');
                         end
                       else
                         G_Initialize(List,TParaVarSym(P).VarDef,HRef);
                     end;
                 end;
             end;
           else
             ;
         end;
       end;
    end;

  procedure THLCGObj.Gen_Load_Para_Value(List: TAsmList);
    var
      I: LongInt;
      CurrPara: TParaVarSym;
    begin
      if (po_assembler in CurrentProcInfo.ProcDef.ProcOptions) or
      { exceptfilters have a single hidden 'parentfp' parameter, which
        is handled by tcg.g_proc_entry. }
         (CurrentProcInfo.ProcDef.ProcTypeOption=potype_exceptfilter) then
        Exit;

      { Copy parameters to local references/registers }
      for I:=0 to CurrentProcInfo.ProcDef.Paras.Count-1 do
        begin
          CurrPara:=TParaVarSym(CurrentProcInfo.ProcDef.Paras[I]);
          if not CurrPara.Is_Used then
            Continue;
          { don't use currpara.vardef, as this will be wrong in case of
            call-by-reference parameters (it won't contain the pointer) }
          Gen_Load_CGPara_Loc(List,CurrPara.ParaLoc[CalleeSide].Def,CurrPara.ParaLoc[CalleeSide],CurrPara.InitialLoc,ParaManager.Param_Use_ParaLoc(CurrPara.ParaLoc[CalleeSide]));
        end;

      { generate copies of call by value parameters, must be done before
        the initialization and body is parsed because the refcounts are
        incremented using the local copies }
      CurrentProcInfo.ProcDef.ParaST.SymList.ForEachCall(@G_CopyValueParas,List);

      if not(po_assembler in CurrentProcInfo.ProcDef.ProcOptions) then
        begin
          { initialize refcounted paras, and trash others. Needed here
            instead of in gen_initialize_code, because when a reference is
            initialized or trashed while the pointer to that reference is kept
            in a regvar, we add a register move and that one again has to
            come after the parameter loading code as far as the register
            allocator is concerned }
          CurrentProcInfo.ProcDef.ParaST.SymList.ForEachCall(@Init_Paras,List);
        end;
    end;

  procedure THLCGObj.G_CopyValueParas(P: TObject; Arg: Pointer);
    var
      HRef : TReference;
      HReg : TRegister;
      List : TAsmList;
      HSym : TParaVarSym;
      L    : LongInt;
      HighLoc,
      LocalCopyLoc : TLocation;
    begin
      List:=TAsmList(Arg);
      if (TSym(P).Typ=ParaVarSym) and
         (TParaVarSym(P).Is_Used) and
         ((vo_has_local_copy in TParaVarSym(P).VarOptions) or
          (not(TargetInfo.System in systems_caller_copy_addr_value_para) and
           (Is_Open_Array(TParaVarSym(P).VarDef) or
            Is_Array_Of_Const(TParaVarSym(P).VarDef)) and
           (TParaVarSym(P).VarSpez=vs_value))) then
        begin
          { we have no idea about the alignment at the caller side }
          Location_Get_Data_Ref(List,TParaVarSym(P).VarDef,TParaVarSym(P).InitialLoc,HRef,True,1);
          if Is_Open_Array(TParaVarSym(P).VarDef) or
             Is_Array_Of_Const(TParaVarSym(P).VarDef) then
            begin
              { cdecl functions don't have a high pointer so it is not possible to generate
                a local copy }
              if not(CurrentProcInfo.ProcDef.ProcCallOption in CDecl_PoCalls) then
                begin
                  if ParaManager.Push_High_Param(TParaVarSym(P).VarSpez,TParaVarSym(P).VarDef,CurrentProcInfo.ProcDef.ProcCallOption) then
                    begin
                      HSym:=TParaVarSym(Get_High_Value_Sym(TParaVarSym(P)));
                      if not Assigned(HSym) then
                        InternalError(2011020506);
                      HighLoc:=HSym.InitialLoc
                    end
                  else
                    HighLoc.Loc:=LOC_INVALID;
                  HReg:=GetAddressRegister(List,VoidPointerType);
                  if not Is_Packed_Array(TParaVarSym(P).VarDef) then
                    G_CopyValuePara_OpenArray(List,HRef,HighLoc,TArrayDef(TParaVarSym(P).VarDef),HReg)
                  else
                    InternalError(2011020507);
//                      cg.g_copyvaluepara_packedopenarray(list,href,hsym.intialloc,tarraydef(tparavarsym(p).vardef).elepackedbitsize,hreg);
                  A_Load_Reg_Loc(List,CPointerDef.GetReusable(TParaVarSym(P).VarDef),CPointerDef.GetReusable(TParaVarSym(P).VarDef),HReg,TParaVarSym(P).InitialLoc);
                end;
            end
          else
            begin
              { Allocate space for the local copy }
              L:=TParaVarSym(P).GetSize;
              LocalCopyLoc.Loc:=LOC_REFERENCE;
              LocalCopyLoc.Size:=Int_CGSize(L);
              GetLocal(List,TParaVarSym(P),L,TParaVarSym(P).VarDef.Alignment,TParaVarSym(P).VarDef,LocalCopyLoc.Reference);
              { Copy data }
              if Is_ShortString(TParaVarSym(P).VarDef) then
                begin
                  { this code is only executed before the code for the body and the entry/exit code is generated
                    so we're allowed to include pi_do_call here; after pass1 is run, this isn't allowed anymore
                  }
                  Include(CurrentProcInfo.Flags,pi_do_call);
                  G_CopyShortString(List,HRef,LocalCopyLoc.Reference,TStringDef(TParaVarSym(P).VarDef))
                end
              else if TParaVarSym(P).VarDef.Typ=VariantDef then
                begin
                  { this code is only executed before the code for the body and the entry/exit code is generated
                    so we're allowed to include pi_do_call here; after pass1 is run, this isn't allowed anymore
                  }
                  Include(CurrentProcInfo.Flags,pi_do_call);
                  G_CopyVariant(List,HRef,LocalCopyLoc.Reference,TVariantDef(TParaVarSym(P).VarDef))
                end
              else
                begin
                  G_ConcatCopy(List,TParaVarSym(P).VarDef,HRef,LocalCopyLoc.Reference);
                end;
              { update localloc of varsym }
              if TParaVarSym(P).LocAlloc.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
                TG.Ungetlocal(List,TParaVarSym(P).LocAlloc.Reference);
              TParaVarSym(P).LocAlloc:=LocalCopyLoc;
              TParaVarSym(P).InitialLoc:=LocalCopyLoc;
            end;
        end;
    end;


  procedure THLCGObj.GetLocal(List: TAsmList; Sym: TSym; Size: ASizeInt; Alignment: ShortInt; Def: TDef; out Ref: TReference);
    var
      ExplicitAlign : ShortInt;
    begin
      if Def.InheritsFrom(TAbstractRecordDef) and (Def.Typ in [RecordDef]) then
        ExplicitAlign:=TAbstractRecordSymTable(TAbstractRecordDef(Def).SymTable).ExplicitRecordAlignment
      else
        ExplicitAlign:=0;
      TG.GetLocal(List,Size,Alignment,ExplicitAlign,Def,Sym,Ref);
      RecordNewSymLoc(List,Sym,Def,Ref,True);
    end;

  procedure THLCGObj.RecordNewSymLoc(List: TAsmList; Sym: TSym; Def: TDef; const Ref: TReference; Initial: Boolean);
    begin
      // do nothing
    end;


  procedure THLCGObj.Gen_LoadFPU_Loc_CGPara(List: TAsmList; Size: TDef; const L: TLocation; const CGPara: TCGPara; LocIntSize: LongInt);
    var
      TmpLoc: TLocation;
    begin
      case L.Loc of
        LOC_MMREGISTER,
        LOC_CMMREGISTER:
          case CGPara.Location^.Loc of
            LOC_REFERENCE,
            LOC_CREFERENCE,
            LOC_MMREGISTER,
            LOC_CMMREGISTER,
            LOC_REGISTER,
            LOC_CREGISTER :
              A_LoadMM_Reg_CGPara(List,Size,L.Register,CGPara,MMS_MoveScalar);
            LOC_FPUREGISTER,
            LOC_CFPUREGISTER:
              begin
                TmpLoc:=L;
                Location_Force_FPUReg(List,TmpLoc,Size,False);
                A_LoadFPU_Reg_CGPara(List,Size,TmpLoc.Register,CGPara);
              end;
            else
              InternalError(2002042402);
          end;
        LOC_FPUREGISTER,
        LOC_CFPUREGISTER:
          case CGPara.Location^.Loc of
            LOC_MMREGISTER,
            LOC_CMMREGISTER:
              begin
                TmpLoc:=L;
                Location_Force_MMRegScalar(List,TmpLoc,Size,False);
                A_LoadMM_Reg_CGPara(List,Size,TmpLoc.Register,CGPara,MMS_MoveScalar);
              end;
            { Some targets pass floats in normal registers }
            LOC_REGISTER,
            LOC_CREGISTER,
            LOC_REFERENCE,
            LOC_CREFERENCE,
            LOC_FPUREGISTER,
            LOC_CFPUREGISTER:
              A_LoadFPU_Reg_CGPara(List,Size,L.Register,CGPara);
            else
              InternalError(2011010210);
          end;
        LOC_REFERENCE,
        LOC_CREFERENCE:
          case CGPara.Location^.Loc of
            LOC_MMREGISTER,
            LOC_CMMREGISTER:
              A_LoadMM_Ref_CGPara(List,Size,L.Reference,CGPara,MMS_MoveScalar);
            { Some targets pass floats in normal registers }
            LOC_REGISTER,
            LOC_CREGISTER,
            LOC_REFERENCE,
            LOC_CREFERENCE,
            LOC_FPUREGISTER,
            LOC_CFPUREGISTER:
              A_LoadFPU_Ref_CGPara(List,Size,L.Reference,CGPara);
            else
              InternalError(2011010211);
          end;
        LOC_REGISTER,
        LOC_CREGISTER :
          A_Load_Loc_CGPara(List,Size,L,CGPara);
         else
           InternalError(2011010212);
      end;
    end;

  procedure THLCGObj.Gen_Load_Uninitialized_Function_Result(List: TAsmList; PD: TProcDef; ResDef: TDef; const ResLoc: TCGPara);
    begin
      { do nothing by default }
    end;

  procedure THLCGObj.Gen_Load_Loc_Function_Result(List: TAsmList; VarDef: TDef; const L: TLocation);
    var
      SafeCallRetPara: TCGPara;
    begin
      if not CurrentProcInfo.ProcDef.Generate_SafeCall_Wrapper then
        Gen_Load_Loc_CGPara(List,VarDef,L,CurrentProcInfo.ProcDef.FuncRetLoc[CalleeSide])
      else
        begin
          SafeCallRetPara:=ParaManager.Get_SafeCallResult_FuncRetLoc(CurrentProcInfo.ProcDef,CalleeSide);
          Gen_Load_Loc_CGPara(List,VarDef,L,SafeCallRetPara);
          SafeCallRetPara.ResetIfTemp;
        end;
    end;

  procedure THLCGObj.Gen_Load_Loc_CGPara(List: TAsmList; VarDef: TDef; const L: TLocation; const CGPara: TCGPara);
    var
      TmpLoc: TLocation;
    begin
      { skip e.g. empty records }
      if (CGPara.Location^.Loc = LOC_VOID) then
        Exit;

      { Handle Floating point types differently

        This doesn't depend on emulator settings, emulator settings should
        be handled by cpupara }
      if (VarDef.Typ=FloatDef) or
         { some ABIs return certain records in an fpu register }
         (L.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) or
         (Assigned(CGPara.Location) and
          (CGPara.Location^.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER])) then
        begin
          Gen_LoadFPU_Loc_CGPara(List,VarDef,L,CGPara,VarDef.Size);
          Exit;
        end;

      { in case of multiple locations, force the source to memory as only
        a_load_ref_cgpara supports multiple locations }
      if Assigned(CGPara.Location^.Next) and
         not(L.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
        begin
          TmpLoc:=L;
          Location_Force_Mem(List,TmpLoc,VarDef);
          A_Load_Loc_CGPara(List,VarDef,TmpLoc,CGPara);
          location_freetemp(List,TmpLoc);
          Exit;
        end;

      case L.Loc of
        LOC_CONSTANT,
        LOC_REGISTER,
        LOC_CREGISTER,
        LOC_REFERENCE,
        LOC_CREFERENCE :
          begin
            A_Load_Loc_CGPara(List,VarDef,L,CGPara);
          end;
        LOC_MMREGISTER,
        LOC_CMMREGISTER:
          begin
            if Use_VectorFPU(VarDef) then
              A_LoadMM_Loc_CGPara(List,VarDef,L,CGPara,MMS_MoveScalar)
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

  procedure THLCGObj.Gen_Load_CGPara_Loc(List: TAsmList; VarDef: TDef; const Para: TCGPara; var DestLoc: TLocation; ReusePara: Boolean);
    var
      HRef     : TReference;
    begin
      Para.Check_Simple_Location;
      { skip e.g. empty records }
      if (Para.Location^.Loc = LOC_VOID) then
        Exit;
      case DestLoc.Loc of
        LOC_REFERENCE :
          begin
            { If the parameter location is reused we don't need to copy
              anything }
            if not ReusePara then
              begin
                case Para.Location^.Loc of
                  LOC_REFERENCE,LOC_CREFERENCE:
                    begin
                      Reference_Reset_Base(HRef,VoidStackPointerType,Para.Location^.Reference.Index,Para.Location^.Reference.Offset,CTempPosInvalid,Para.Alignment,[]);
                      A_Load_Ref_Ref(List,Para.Def,Para.Def,HRef,DestLoc.Reference);
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

  procedure THLCGObj.Gen_Load_Return_Value(List: TAsmList);
    var
      ResSym : TSym;
      RetDef : TDef;
    begin
      { Is the loading needed? }
      if (Is_Void(CurrentProcInfo.ProcDef.ReturnDef) and
          not CurrentProcInfo.ProcDef.Generate_SafeCall_Wrapper) or
         (
          (po_assembler in CurrentProcInfo.ProcDef.ProcOptions) and
          (CurrentProcInfo.ProcDef.Generate_SafeCall_Wrapper or
           not Assigned(CurrentProcInfo.ProcDef.FuncRetSym) or
           (TAbstractVarSym(CurrentProcInfo.ProcDef.FuncRetSym).Refs=0) or
           (po_nostackframe in CurrentProcInfo.ProcDef.ProcOptions)
          )
         ) then
        begin
          ResSym:=CurrentProcInfo.ProcDef.FuncRetSym;
          if not Assigned(ResSym) then
            Exit;
        end
      else
        begin
          { constructors return self }
          if CurrentProcInfo.ProcDef.Generate_SafeCall_Wrapper then
            begin
              if not CurrentProcInfo.ProcDef.Get_SafeCall_FuncRetSym_Info(ResSym,RetDef) then
                InternalError(2019112402);
              Gen_Load_Loc_Function_Result(List,RetDef,TAbstractNormalVarSym(ResSym).LocAlloc);
            end
          else
            begin
              if not CurrentProcInfo.ProcDef.Get_FuncRetSym_Info(ResSym,RetDef) then
                InternalError(2018122501);
              if (ResSym.Refs>0) or
                 Is_Managed_Type(RetDef) then
                begin
                  { was: don't do anything if funcretloc.loc in [LOC_INVALID,LOC_REFERENCE] }
                  if not ParaManager.Ret_In_Param(CurrentProcInfo.ProcDef.ReturnDef,CurrentProcInfo.ProcDef) then
                    Gen_Load_Loc_Function_Result(List,RetDef,TAbstractNormalVarSym(ResSym).LocAlloc);
                end
              else
                Gen_Load_Uninitialized_Function_Result(List,CurrentProcInfo.ProcDef,RetDef,CurrentProcInfo.ProcDef.FuncRetLoc[CalleeSide]);
            end;
        end;

      if TAbstractNormalVarSym(ResSym).LocAlloc.Loc=LOC_REFERENCE then
        TG.UnGetLocal(List,TAbstractNormalVarSym(ResSym).LocAlloc.Reference);
    end;

  procedure THLCGObj.Gen_Stack_Check_Size_Para(List: TAsmList);
    var
      ParaLoc1 : TCGPara;
      PD       : TProcDef;
    begin
      PD:=Search_System_Proc('fpc_stackcheck');
      ParaLoc1.Init;
      ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,PD,1,ParaLoc1);
      HLCG.A_Load_Const_CGPara(List,ParaLoc1.Def,CurrentProcInfo.calc_stackframe_size,ParaLoc1);
      ParaManager.FreeCGPara(List,ParaLoc1);
      ParaLoc1.Done;
    end;

  procedure THLCGObj.Gen_Stack_Check_Call(List: TAsmList);
    var
      ParaLoc1 : TCGPara;
      PD       : TProcDef;
    begin
      PD:=Search_System_Proc('fpc_stackcheck');
      ParaLoc1.Init;
      { The parameter to fpc_stackcheck is loaded separately via
        gen_stack_check_size_para() }
      ParaManager.GetCGTempParaLoc(List,PD,1,ParaLoc1);
      ParaManager.FreeCGPara(List,ParaLoc1);
      { Call the helper }
      G_Call_System_Proc(List,PD,[@ParaLoc1],nil).ResetIfTemp;
      ParaLoc1.Done;
    end;

  procedure THLCGObj.Record_Generated_Code_For_ProcDef(PD: TProcDef; Code, Data: TAsmList);
    begin
      FPHLCGObjHelper.Record_Generated_Code_For_ProcDef(PD, Code, Data);
    end;

  function THLCGObj.G_Call_System_Proc(List: TAsmList; const ProcName: string; const Paras: array of PCGPara; ForceResDef: TDef): TCGPara;
    var
      PD: TProcDef;
    begin
      PD:=Search_System_Proc(ProcName);
      PD.Init_ParaLoc_Info(CallerSide);
      if SystemUnit<>CurrentModule.GlobalSymTable then
        CurrentModule.AddImportedSym(PD.ProcSym);
      Result:=G_Call_System_Proc_Intern(List,PD,Paras,ForceResDef);
    end;

  function THLCGObj.G_Call_System_Proc(List: TAsmList; PD: TProcDef; const Paras: array of PCGPara; ForceResDef: TDef): TCGPara;
    begin
      { separate non-virtual routine to make it clear that the routine to
        override, if any, is g_call_system_proc_intern (and that none of
        the g_call_system_proc variants should be made virtual) }
      PD.Init_ParaLoc_Info(CallerSide);
      if SystemUnit<>CurrentModule.GlobalSymTable then
        CurrentModule.AddImportedSym(PD.ProcSym);
      Result:=G_Call_System_Proc_Intern(List,PD,Paras,ForceResDef);
    end;

  function THLCGObj.G_Call_System_Proc_Intern(List: TAsmList; PD: TProcDef; const Paras: array of PCGPara; ForceResDef: TDef): TCGPara;
    begin
      AllocAllCPURegisters(List);
      Result:=A_Call_Name(List,PD,PD.MangledName,Paras,ForceResDef,False);
      DeallocAllCPURegisters(List);
    end;



end.
