{
    Copyright (c) 1998-2010 by Florian Klaempfl and Jonas Maebe
    Member of the Free Pascal development team

    This unit implements the high level code generator object for targets that
    only use the low-level code generator

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
{# @abstract(High level code generator to low level)
  This class passes the high level code generator methods through to the
  low level code generator.
}
unit hlcg2ll;

{$i fpcdefs.inc}

{ define hlcginline}

  interface

    uses
       GlobType,ConstExp,
       cpubase,cgbase,cgutils,parabase,
       aasmbase,aasmtai,AAsmData,aasmcpu,
       symconst,symtype,symdef,
       node,hlcgobj
       ;

    type
       {# @abstract(Abstract high level code generator)
          This class implements an abstract instruction generator. All
          methods of this class are generic and are mapped to low level code
          generator methods by default. They have to be overridden for higher
          level targets
       }

       { thlcg2ll }

       THLCG2LL = class(THLCGObj)
       public
          {************************************************}
          {                 basic routines                 }
          procedure Init_Register_Allocators;override;
          {# Clean up the register allocators needed for the codegenerator.}
          procedure Done_Register_Allocators;override;
          {# Set whether live_start or live_end should be updated when allocating registers, needed when e.g. generating initcode after the rest of the code. }
          procedure Set_RegAlloc_Live_Range_Direction(dir: TRADirection);override;

          {# Gets a register suitable to do integer operations on.}
          function GetIntRegister(list:TAsmList;size:TDef):TRegister;override;
          {# Gets a register suitable to do integer operations on.}
          function GetAddressRegister(list:TAsmList;size:TDef):TRegister;override;
          function GetFPURegister(list:TAsmList;size:TDef):TRegister;override;
          { warning: only works correctly for fpu types currently }
          function GetMMRegister(list:TAsmList;size:TDef):TRegister;override;
          function GetFlagRegister(list:TAsmList;size:TDef):TRegister;override;
          {Does the generic cg need SIMD registers, like getmmxregister? Or should
           the cpu specific child cg object have such a method?}

          function  Uses_Registers(rt:TRegisterType):boolean; inline;

          procedure Do_Register_Allocation(list:TAsmList;headertai:TAI); inline;
          procedure Translate_Register(var reg : TRegister); inline;

          {# Allocates register r by inserting a pai_realloc record }
          procedure A_Reg_Alloc(list : TAsmList;r : TRegister); inline;
          {# Deallocates register r by inserting a pa_regdealloc record}
          procedure A_Reg_Dealloc(list : TAsmList;r : TRegister); inline;
          { Synchronize register, make sure it is still valid }
          procedure A_Reg_Sync(list : TAsmList;r : TRegister); inline;

          {# Pass a parameter, which is located in a register, to a routine.

             This routine should push/send the parameter to the routine, as
             required by the specific processor ABI and routine modifiers.
             It must generate register allocation information for the cgpara in
             case it consists of cpuregisters.

             @param(size size of the operand in the register)
             @param(r register source of the operand)
             @param(cgpara where the parameter will be stored)
          }
          procedure A_Load_Reg_CGPara(list : TAsmList;size : TDef;r : TRegister;const cgpara : TCGPara);override;
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
          procedure A_Load_Const_CGPara(list : TAsmList;tosize : TDef;a : TCGInt;const cgpara : TCGPara);override;
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
          procedure A_Load_Ref_CGPara(list : TAsmList;size : TDef;const r : TReference;const cgpara : TCGPara);override;
          {# Pass the value of a parameter, which can be located either in a register or memory location,
             to a routine.

             A generic version is provided.

             @param(l location of the operand to send)
             @param(nr parameter number (starting from one) of routine (from left to right))
             @param(cgpara where the parameter will be stored)
          }
          procedure A_Load_Loc_CGPara(list : TAsmList;size : TDef; const l : TLocation;const cgpara : TCGPara);override;
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
          procedure A_LoadAddr_Ref_CGPara(list : TAsmList;fromsize : TDef;const r : TReference;const cgpara : TCGPara);override;

          function A_Call_Name(list: TAsmList; pd: TProcDef; const s: TSymStr; const paras: array of PCGPara; forceresdef: TDef; weak: boolean): TCGPara; override;
          function A_Call_Reg(list : TAsmList;pd : TAbstractProcDef;reg : TRegister; const paras: array of PCGPara): TCGPara;override;
          { same as a_call_name, might be overridden on certain architectures to emit
            static calls without usage of a got trampoline }
          function A_Call_Name_Static(list: TAsmList; pd: TProcDef; const s: TSymStr; const paras: array of PCGPara; forceresdef: TDef): TCGPara; override;

          { move instructions }
          procedure A_Load_Const_Reg(list : TAsmList;tosize : TDef;a : TCGInt;register : TRegister);override;
          procedure A_Load_Const_Ref(list : TAsmList;tosize : TDef;a : TCGInt;const ref : TReference);override;
          procedure A_Load_Const_Loc(list : TAsmList;tosize : TDef;a : TCGInt;const loc : TLocation);override;
          procedure A_Load_Reg_Ref(list : TAsmList;fromsize, tosize : TDef;register : TRegister;const ref : TReference);override;
          procedure A_Load_Reg_Ref_Unaligned(list : TAsmList;fromsize, tosize : TDef;register : TRegister;const ref : TReference);override;
          procedure A_Load_Reg_Reg(list : TAsmList;fromsize, tosize : TDef;reg1,reg2 : TRegister);override;
          procedure A_Load_Reg_Loc(list : TAsmList;fromsize, tosize : TDef;reg : TRegister;const loc: TLocation);override;
          procedure A_Load_Ref_Reg(list : TAsmList;fromsize, tosize : TDef;const ref : TReference;register : TRegister);override;
          procedure A_Load_Ref_Reg_Unaligned(list : TAsmList;fromsize, tosize : TDef;const ref : TReference;register : TRegister);override;
          procedure A_Load_Ref_Ref(list : TAsmList;fromsize, tosize : TDef;const sref : TReference;const dref : TReference);override;
          procedure A_Load_Loc_Reg(list : TAsmList;fromsize, tosize : TDef; const loc: TLocation; reg : TRegister);override;
          procedure A_Load_Loc_Ref(list : TAsmList;fromsize, tosize: TDef; const loc: TLocation; const ref : TReference);override;
          procedure A_LoadAddr_Ref_Reg(list : TAsmList;fromsize, tosize : TDef;const ref : TReference;r : TRegister);override;

          { bit scan instructions }
          procedure A_Bit_Scan_Reg_Reg(list: TAsmList; reverse,not_zero: boolean; srcsize, dstsize: TDef; src, dst: TRegister); override;

          { fpu move instructions }
          procedure A_LoadFPU_Reg_Reg(list: TAsmList; fromsize, tosize: TDef; reg1, reg2: TRegister); override;
          procedure A_LoadFPU_Ref_Reg(list: TAsmList; fromsize, tosize: TDef; const ref: TReference; reg: TRegister); override;
          procedure A_LoadFPU_Reg_Ref(list: TAsmList; fromsize, tosize: TDef; reg: TRegister; const ref: TReference); override;
          procedure A_LoadFPU_Ref_Ref(list: TAsmList; fromsize, tosize: TDef; const ref1,ref2: TReference);override;
          procedure A_LoadFPU_Loc_Reg(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; const reg: TRegister);override;
          procedure A_LoadFPU_Reg_Loc(list: TAsmList; fromsize, tosize: TDef; const reg: TRegister; const loc: TLocation);override;
          procedure A_LoadFPU_Reg_CGPara(list : TAsmList;fromsize: TDef;const r : TRegister;const cgpara : TCGPara);override;
          procedure A_LoadFPU_Ref_CGPara(list : TAsmList;fromsize : TDef;const ref : TReference;const cgpara : TCGPara);override;

          { vector register move instructions }
          procedure A_LoadMM_Reg_Reg(list: TAsmList; fromsize, tosize: TDef;reg1, reg2: TRegister;shuffle : PMMShuffle); override;
          procedure A_LoadMM_Ref_Reg(list: TAsmList; fromsize, tosize: TDef;const ref: TReference; reg: TRegister;shuffle : PMMShuffle); override;
          procedure A_LoadMM_Reg_Ref(list: TAsmList; fromsize, tosize: TDef;reg: TRegister; const ref: TReference;shuffle : PMMShuffle); override;
          procedure A_LoadMM_Loc_Reg(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; const reg: TRegister;shuffle : PMMShuffle);override;
          procedure A_LoadMM_Reg_Loc(list: TAsmList; fromsize, tosize: TDef; const reg: TRegister; const loc: TLocation;shuffle : PMMShuffle);override;
          procedure A_LoadMM_Reg_CGPara(list: TAsmList; fromsize: TDef; reg: TRegister;const cgpara : TCGPara;shuffle : PMMShuffle); override;
          procedure A_LoadMM_Ref_CGPara(list: TAsmList; fromsize: TDef; const ref: TReference;const cgpara : TCGPara;shuffle : PMMShuffle); override;
          procedure A_LoadMM_Loc_CGPara(list: TAsmList; fromsize: TDef; const loc: TLocation; const cgpara : TCGPara;shuffle : PMMShuffle); override;
          procedure A_OpMM_Reg_Reg(list: TAsmList; Op: TOpCG; size : TDef;src,dst: TRegister;shuffle : PMMShuffle); override;
          procedure A_OpMM_Ref_Reg(list: TAsmList; Op: TOpCG; size : TDef;const ref: TReference; reg: TRegister;shuffle : PMMShuffle); override;
          procedure A_OpMM_Loc_Reg(list: TAsmList; Op: TOpCG; size : TDef;const loc: TLocation; reg: TRegister;shuffle : PMMShuffle); override;
          procedure A_OpMM_Reg_Ref(list: TAsmList; Op: TOpCG; size : TDef;reg: TRegister;const ref: TReference; shuffle : PMMShuffle); override;
          procedure A_LoadMM_IntReg_Reg(list: TAsmList; fromsize, tosize : TDef; intreg, mmreg: TRegister; shuffle: PMMShuffle); override;
          procedure A_LoadMM_Reg_IntReg(list: TAsmList; fromsize, tosize : TDef; mmreg, intreg: TRegister; shuffle : PMMShuffle); override;

          { basic arithmetic operations }
          { note: for operators which require only one argument (not, neg), use }
          { the op_reg_reg, op_reg_ref or op_reg_loc methods and keep in mind   }
          { that in this case the *second* operand is used as both source and   }
          { destination (JM)                                                    }
          procedure A_Op_Const_Reg(list : TAsmList; Op: TOpCG; size: TDef; a: TCGInt; reg: TRegister); override;
          procedure A_Op_Const_Ref(list : TAsmList; Op: TOpCG; size: TDef; a: TCGInt; const ref: TReference); override;
          procedure A_Op_Const_Loc(list : TAsmList; Op: TOpCG; size: TDef; a: TCGInt; const loc: TLocation);override;
          procedure A_Op_Reg_Reg(list : TAsmList; Op: TOpCG; size: TDef; reg1, reg2: TRegister); override;
          procedure A_Op_Reg_Ref(list : TAsmList; Op: TOpCG; size: TDef; reg: TRegister; const ref: TReference); override;
          procedure A_Op_Ref_Reg(list : TAsmList; Op: TOpCG; size: TDef; const ref: TReference; reg: TRegister); override;
          procedure A_Op_Reg_Loc(list : TAsmList; Op: TOpCG; size: TDef; reg: TRegister; const loc: TLocation);override;
          procedure A_Op_Ref_Loc(list : TAsmList; Op: TOpCG; size: TDef; const ref: TReference; const loc: TLocation);override;

          { trinary operations for processors that support them, 'emulated' }
          { on others. None with "ref" arguments since I don't think there  }
          { are any processors that support it (JM)                         }
          procedure A_Op_Const_Reg_Reg(list: TAsmList; op: TOpCG; size: TDef; a: TCGInt; src, dst: TRegister); override;
          procedure A_Op_Reg_Reg_Reg(list: TAsmList; op: TOpCG; size: TDef; src1, src2, dst: TRegister); override;
          procedure A_Op_Const_Reg_Reg_CheckOverflow(list: TAsmList; op: TOpCG; size: TDef; a: TCGInt; src, dst: TRegister;setflags : boolean;var ovloc : TLocation); override;
          procedure A_Op_Reg_Reg_Reg_CheckOverflow(list: TAsmList; op: TOpCG; size: TDef; src1, src2, dst: TRegister;setflags : boolean;var ovloc : TLocation); override;

          { unary operations (not, neg) }
          procedure A_Op_Reg(list : TAsmList; Op: TOpCG; size: TDef; reg: TRegister); override;
          procedure A_Op_Ref(list : TAsmList; Op: TOpCG; size: TDef; const ref: TReference); override;
          procedure A_Op_Loc(list : TAsmList; Op: TOpCG; size: TDef;  const loc: TLocation); override;

          {  comparison operations }
          procedure A_Cmp_Const_Reg_Label(list : TAsmList;size : TDef;cmp_op : TOpCmp;a : TCGInt;reg : TRegister;
            l : TAsmLabel);override;
          procedure A_Cmp_Const_Ref_Label(list : TAsmList;size : TDef;cmp_op : TOpCmp;a : TCGInt;const ref : TReference;
            l : TAsmLabel); override;
          procedure A_Cmp_Const_Loc_Label(list: TAsmList; size: TDef;cmp_op: TOpCmp; a: TCGInt; const loc: TLocation;
            l : TAsmLabel);override;
          procedure A_Cmp_Reg_Reg_Label(list : TAsmList;size : TDef;cmp_op : TOpCmp;reg1,reg2 : TRegister;l : TAsmLabel); override;
          procedure A_Cmp_Ref_Reg_Label(list : TAsmList;size : TDef;cmp_op : TOpCmp; const ref: TReference; reg : TRegister; l : TAsmLabel); override;
          procedure A_Cmp_Reg_Ref_Label(list : TAsmList;size : TDef;cmp_op : TOpCmp;reg : TRegister; const ref: TReference; l : TAsmLabel); override;

          procedure A_Cmp_Loc_Reg_Label(list : TAsmList;size : TDef;cmp_op : TOpCmp; const loc: TLocation; reg : TRegister; l : TAsmLabel);override;
          procedure A_Cmp_Ref_Loc_Label(list: TAsmList; size: TDef;cmp_op: TOpCmp; const ref: TReference; const loc: TLocation; l : TAsmLabel);override;

          procedure A_Jmp_Always(list : TAsmList;l: TAsmLabel); override;
{$ifdef cpuflags}
          procedure A_Jmp_Flags(list : TAsmList;const f : TResFlags;l: TAsmLabel); override;

          {# Depending on the value to check in the flags, either sets the register reg to one (if the flag is set)
             or zero (if the flag is cleared). The size parameter indicates the destination size register.
          }
          procedure G_Flags2Reg(list: TAsmList; size: TDef; const f: TResFlags; reg: TRegister); override;
          procedure G_Flags2Ref(list: TAsmList; size: TDef; const f: TResFlags; const ref:TReference); override;
{$endif cpuflags}

//          procedure g_maybe_testvmt(list : TAsmList;reg:tregister;objdef:tobjectdef);
          {# This should emit the opcode to copy len bytes from the source
             to destination.

             It must be overridden for each new target processor.

             @param(source Source reference of copy)
             @param(dest Destination reference of copy)

          }
          procedure G_ConcatCopy(list : TAsmList;size: TDef; const source,dest : TReference);override;
          {# This should emit the opcode to copy len bytes from the an unaligned source
             to destination.

             It must be overridden for each new target processor.

             @param(source Source reference of copy)
             @param(dest Destination reference of copy)

          }
          procedure G_ConcatCopy_Unaligned(list : TAsmList;size: TDef; const source,dest : TReference);override;

          {# Generates overflow checking code for a node }
          procedure G_OverflowCheck(list: TAsmList; const Loc:TLocation; def:TDef); override;
          procedure G_OverflowCheck_Loc(List:TAsmList;const Loc:TLocation;def:TDef;var ovloc : TLocation);override;

          {# Emits instruction for allocating @var(size) bytes at the stackpointer

             @param(size Number of bytes to allocate)
          }
          procedure G_StackPointer_Alloc(list : TAsmList;size : LongInt);override;
          {# Emits instruction for allocating the locals in entry
             code of a routine. This is one of the first
             routine called in @var(genentrycode).

             @param(localsize Number of bytes to allocate as locals)
          }
          procedure G_Proc_Entry(list : TAsmList;localsize : LongInt;nostackframe:boolean);override;
          {# Emits instructions for returning from a subroutine.
             Should also restore the framepointer and stack.

             @param(parasize  Number of bytes of parameters to deallocate from stack)
          }
          procedure G_Proc_Exit(list : TAsmList;parasize:LongInt;nostackframe:boolean);override;

          procedure G_Adjust_Self_Value(list:TAsmList;procdef: TProcDef;ioffset: aint);override;

          { Generate code to exit an unwind-protected region. The default implementation
            produces a simple jump to destination label. }
          procedure G_Local_Unwind(list: TAsmList; l: TAsmLabel);override;

          procedure Location_Force_Reg(list:TAsmList;var l:TLocation;src_size,dst_size:TDef;maybeconst:boolean);override;
          procedure Location_Force_Mem(list:TAsmList;var l:TLocation;size:TDef);override;
          procedure Location_Force_MMRegScalar(list:TAsmList;var l: TLocation;var size:TDef;maybeconst:boolean);override;
//          procedure location_force_mmreg(list:TAsmList;var l: tlocation;size:tdef;maybeconst:boolean);override;

          procedure MakeToJumpBoolLabels(list: TAsmList; p: TNode; TrueLabel, FalseLabel: TAsmLabel); override;

          procedure Gen_Load_Para_Value(list:TAsmList);override;
         protected
          procedure Gen_LoadFPU_Loc_CGPara(list: TAsmList; size: TDef; const l: TLocation;const cgpara: TCGPara;locintsize: LongInt);override;
         public


          procedure Gen_Load_Loc_CGPara(list: TAsmList; vardef: TDef; const l: TLocation; const cgpara: TCGPara); override;
          procedure Gen_Load_CGPara_Loc(list: TAsmList; vardef: TDef; const para: TCGPara; var destloc: TLocation; reusepara: boolean); override;

         protected
          { returns the equivalent MM size for a vector register that contains
            a record, because in that case "size" will contain a cgsize
            representing an integer size}
          function getintmmcgsize(reg: TRegister; size: TCgSize): TCgSize; virtual;
       end;


implementation

    uses
       Globals,Systems,
       Verbose,defutil,SymSym,
       ProcInfo,paramgr,
       cgobj,tgobj,CUtils,
       ncgutil;

  { thlcg2ll }

  procedure THLCG2LL.Init_Register_Allocators;
    begin
      cg.Init_Register_Allocators;
    end;

  procedure THLCG2LL.Done_Register_Allocators;
    begin
      cg.Done_Register_Allocators;
    end;

  procedure THLCG2LL.Set_RegAlloc_Live_Range_Direction(dir: TRADirection);
    begin
      cg.Set_RegAlloc_Live_Range_Direction(dir);
    end;

  function THLCG2LL.GetIntRegister(list: TAsmList; size: TDef): TRegister;
    begin
      result:=cg.GetIntRegister(list,Def_CGSize(size));
    end;


  function THLCG2LL.GetAddressRegister(list: TAsmList; size: TDef): TRegister;
    begin
      result:=cg.GetAddressRegister(list);
    end;

  function THLCG2LL.GetFPURegister(list: TAsmList; size: TDef): TRegister;
    begin
      result:=cg.GetFPURegister(list,Def_CGSize(size));
    end;

  function THLCG2LL.GetMMRegister(list: TAsmList; size: TDef): TRegister;
    begin
      result:=cg.GetMMRegister(list,Def_CGSize(size));
    end;

(*
  function thlcg2ll.getmmregister(list: TAsmList; size: tdef): Tregister;
    begin
      result:=cg.getmmregister(list,def_cgsize(size));
    end;
*)
  function THLCG2LL.GetFlagRegister(list: TAsmList; size: TDef): TRegister;
    begin
      result:=cg.GetFlagRegister(list,Def_CGSize(size));
    end;

  function THLCG2LL.Uses_Registers(rt: TRegisterType): boolean;
    begin
       result:=cg.Uses_Registers(rt);
    end;

  procedure THLCG2LL.Do_Register_Allocation(list: TAsmList; headertai: TAI);
    begin
      cg.Do_Register_Allocation(list,headertai);
    end;

  procedure THLCG2LL.Translate_Register(var reg: TRegister);
    begin
      cg.Translate_Register(reg);
    end;

  procedure THLCG2LL.A_Reg_Alloc(list: TAsmList; r: TRegister);
    begin
      cg.A_Reg_Alloc(list,r);
    end;

  procedure THLCG2LL.A_Reg_Dealloc(list: TAsmList; r: TRegister);
    begin
      cg.A_Reg_Dealloc(list,r);
    end;

  procedure THLCG2LL.A_Reg_Sync(list: TAsmList; r: TRegister);
    begin
      cg.A_Reg_Sync(list,r);
    end;

  procedure THLCG2LL.A_Load_Reg_CGPara(list: TAsmList; size: TDef; r: TRegister; const cgpara: TCGPara);
    begin
      cg.A_Load_Reg_CGPara(list,Def_CGSize(size),r,cgpara);
    end;

  procedure THLCG2LL.A_Load_Const_CGPara(list: TAsmList; tosize: TDef; a: TCGInt; const cgpara: TCGPara);
    begin
      cg.A_Load_Const_CGPara(list,Def_CGSize(tosize),a,cgpara);
    end;

  procedure THLCG2LL.A_Load_Ref_CGPara(list: TAsmList; size: TDef; const r: TReference; const cgpara: TCGPara);
    begin
      cg.A_Load_Ref_CGPara(list,Def_CGSize(size),r,cgpara);
    end;

  procedure THLCG2LL.A_Load_Loc_CGPara(list: TAsmList; size: TDef; const l: TLocation; const cgpara: TCGPara);
    begin
      cg.A_Load_Loc_CGPara(list,l,cgpara);
    end;

  procedure THLCG2LL.A_LoadAddr_Ref_CGPara(list: TAsmList; fromsize: TDef; const r: TReference; const cgpara: TCGPara);
    begin
      cg.A_LoadAddr_Ref_CGPara(list,r,cgpara);
    end;

  function THLCG2LL.A_Call_Name(list: TAsmList; pd: TProcDef; const s: TSymStr; const paras: array of PCGPara; forceresdef: TDef; weak: boolean): TCGPara;
    begin
      cg.A_Call_Name(list,s,weak);
      result:=Get_Call_Result_CGPara(pd,forceresdef);
    end;

  function THLCG2LL.A_Call_Reg(list: TAsmList; pd: TAbstractProcDef; reg: TRegister; const paras: array of PCGPara): TCGPara;
    begin
      cg.A_Call_Reg(list,reg);
      result:=Get_Call_Result_CGPara(pd,nil);
    end;

  function THLCG2LL.A_Call_Name_Static(list: TAsmList; pd: TProcDef; const s: TSymStr; const paras: array of PCGPara; forceresdef: TDef): TCGPara;
    begin
      cg.A_Call_Name_Static(list,s);
      result:=Get_Call_Result_CGPara(pd,forceresdef);
    end;

  procedure THLCG2LL.A_Load_Const_Reg(list: TAsmList; tosize: TDef; a: TCGInt; register: TRegister);
    begin
      cg.A_Load_Const_Reg(list,Def_CGSize(tosize),a,register);
    end;

  procedure THLCG2LL.A_Load_Const_Ref(list: TAsmList; tosize: TDef; a: TCGInt; const ref: TReference);
    begin
       cg.A_Load_Const_Ref(list,Def_CGSize(tosize),a,ref);
    end;

  procedure THLCG2LL.A_Load_Const_Loc(list: TAsmList; tosize: TDef; a: TCGInt; const loc: TLocation);
    begin
      case loc.Loc of
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          inherited
        else
          cg.A_Load_Const_Loc(list,a,loc);
      end;
    end;

  procedure THLCG2LL.A_Load_Reg_Ref(list: TAsmList; fromsize, tosize: TDef; register: TRegister; const ref: TReference);
    begin
      cg.A_Load_Reg_Ref(list,Def_CGSize(fromsize),Def_CGSize(tosize),register,ref);
    end;

  procedure THLCG2LL.A_Load_Reg_Ref_Unaligned(list: TAsmList; fromsize, tosize: TDef; register: TRegister; const ref: TReference);
    begin
      cg.A_Load_Reg_Ref_Unaligned(list,Def_CGSize(fromsize),Def_CGSize(tosize),register,ref);
    end;

  procedure THLCG2LL.A_Load_Reg_Reg(list: TAsmList; fromsize, tosize: TDef; reg1, reg2: TRegister);
    begin
      cg.A_Load_Reg_Reg(list,Def_CGSize(fromsize),Def_CGSize(tosize),reg1,reg2);
    end;

  procedure THLCG2LL.A_Load_Reg_Loc(list: TAsmList; fromsize, tosize: TDef; reg: TRegister; const loc: TLocation);
    var
      fromcgsize: TCgSize;
    begin
      case loc.Loc of
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          inherited;
        else
          begin
            { avoid problems with 3-byte records and the like }
            if (fromsize.typ<>floatdef) and
               (fromsize=tosize) then
              fromcgsize:=loc.Size
            else
              { fromsize can be a floatdef (in case the destination is an
                MMREGISTER) -> use int_cgsize rather than def_cgsize to get the
                corresponding integer cgsize of the def }
              fromcgsize:=Int_CGSize(fromsize.Size);
            cg.A_Load_Reg_Loc(list,fromcgsize,reg,loc);
          end;
      end;
    end;

  procedure THLCG2LL.A_Load_Ref_Reg(list: TAsmList; fromsize, tosize: TDef; const ref: TReference; register: TRegister);
    begin
      cg.A_Load_Ref_Reg(list,Def_CGSize(fromsize),Def_CGSize(tosize),ref,register);
    end;

  procedure THLCG2LL.A_Load_Ref_Reg_Unaligned(list: TAsmList; fromsize, tosize: TDef; const ref: TReference; register: TRegister);
    begin
      cg.A_Load_Ref_Reg_Unaligned(list,Def_CGSize(fromsize),Def_CGSize(tosize),ref,register);
    end;

  procedure THLCG2LL.A_Load_Ref_Ref(list: TAsmList; fromsize, tosize: TDef; const sref: TReference; const dref: TReference);
    begin
      cg.A_Load_Ref_Ref(list,Def_CGSize(fromsize),Def_CGSize(tosize),sref,dref);
    end;

  procedure THLCG2LL.A_Load_Loc_Reg(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; reg: TRegister);
    var
      tocgsize: TCgSize;
    begin
      case loc.Loc of
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          inherited
        else
          begin
            { avoid problems with 3-byte records and the like }
            if fromsize=tosize then
              tocgsize:=loc.Size
            else
              tocgsize:=Def_CGSize(tosize);
            cg.A_Load_Loc_Reg(list,tocgsize,loc,reg);
          end;
      end;
    end;

  procedure THLCG2LL.A_Load_Loc_Ref(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; const ref: TReference);
    var
      tocgsize: TCgSize;
    begin
      case loc.Loc of
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          inherited
        else
          begin
            { avoid problems with 3-byte records and the like }
            if fromsize=tosize then
              tocgsize:=loc.Size
            else
              tocgsize:=Def_CGSize(tosize);
            cg.A_Load_Loc_Ref(list,tocgsize,loc,ref);
          end;
      end;
    end;

  procedure THLCG2LL.A_LoadAddr_Ref_Reg(list: TAsmList; fromsize, tosize: TDef; const ref: TReference; r: TRegister);
    begin
      cg.A_LoadAddr_Ref_Reg(list,ref,r);
    end;

  procedure THLCG2LL.A_Bit_Scan_Reg_Reg(list: TAsmList; reverse,not_zero: boolean; srcsize, dstsize: TDef; src, dst: TRegister);
    begin
      cg.A_Bit_Scan_Reg_Reg(list,reverse,not_zero,Def_CGSize(srcsize),Def_CGSize(dstsize),src,dst);
    end;

  procedure THLCG2LL.A_LoadFPU_Reg_Reg(list: TAsmList; fromsize, tosize: TDef; reg1, reg2: TRegister);
    begin
      cg.A_LoadFPU_Reg_Reg(list,Def_CGSize(fromsize),Def_CGSize(tosize),reg1,reg2);
    end;

  procedure THLCG2LL.A_LoadFPU_Ref_Reg(list: TAsmList; fromsize, tosize: TDef; const ref: TReference; reg: TRegister);
    begin
      cg.A_LoadFPU_Ref_Reg(list,Def_CGSize(fromsize),Def_CGSize(tosize),ref,reg);
    end;

  procedure THLCG2LL.A_LoadFPU_Reg_Ref(list: TAsmList; fromsize, tosize: TDef; reg: TRegister; const ref: TReference);
    begin
      cg.A_LoadFPU_Reg_Ref(list,Def_CGSize(fromsize),Def_CGSize(tosize),reg,ref);
    end;

  procedure THLCG2LL.A_LoadFPU_Ref_Ref(list: TAsmList; fromsize, tosize: TDef; const ref1, ref2: TReference);
    begin
      cg.A_LoadFPU_Ref_Ref(list,Def_CGSize(fromsize),Def_CGSize(tosize),ref1,ref2);
    end;

  procedure THLCG2LL.A_LoadFPU_Loc_Reg(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; const reg: TRegister);
    begin
{$ifdef extdebug}
      if Def_CGSize(fromsize)<>loc.Size then
        InternalError(2010112102);
{$endif}
      cg.A_LoadFPU_Loc_Reg(list,Def_CGSize(tosize),loc,reg);
    end;

  procedure THLCG2LL.A_LoadFPU_Reg_Loc(list: TAsmList; fromsize, tosize: TDef; const reg: TRegister; const loc: TLocation);
    var
      usesize: TCgSize;
    begin
{$ifdef extdebug}
      if Def_CGSize(tosize)<>loc.Size then
        InternalError(2010112101);
{$endif}
      { on some platforms, certain records are passed/returned in floating point
        registers -> def_cgsize() won't give us the result we need -> translate
        to corresponding fpu size }
      usesize:=Def_CGSize(fromsize);
      if not(usesize in [OS_F32..OS_F128]) then
        usesize:=Int_Float_CGSize(TCgSize2Size[usesize]);
      cg.A_LoadFPU_Reg_Loc(list,usesize,reg,loc);
    end;

  procedure THLCG2LL.A_LoadFPU_Reg_CGPara(list: TAsmList; fromsize: TDef; const r: TRegister; const cgpara: TCGPara);
    begin
      cg.A_LoadFPU_Reg_CGPara(list,Def_CGSize(fromsize),r,cgpara);
    end;

  procedure THLCG2LL.A_LoadFPU_Ref_CGPara(list: TAsmList; fromsize: TDef; const ref: TReference; const cgpara: TCGPara);
    begin
      cg.A_LoadFPU_Ref_CGPara(list,Def_CGSize(fromsize),ref,cgpara);
    end;

  procedure THLCG2LL.A_LoadMM_Loc_Reg(list: TAsmList; fromsize, tosize: TDef; const loc: TLocation; const reg: TRegister;shuffle : PMMShuffle);
    var
      tmpreg: TRegister;
      tocgsize: TCgSize;
    begin
      if Def_CGMMSize(fromsize)<>loc.Size then
        InternalError(2012071226);
      tocgsize:=getintmmcgsize(reg,Def_CGMMSize(tosize));
      case loc.Loc of
        LOC_CONSTANT,
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          begin
            tmpreg:=cg.GetIntRegister(list,loc.Size);
            A_Load_Loc_Reg(list,fromsize,fromsize,loc,tmpreg);
            { integer register -> no def_cgmmsize but plain }
            cg.A_LoadMM_IntReg_Reg(list,Def_CGSize(fromsize),tocgsize,tmpreg,reg,shuffle);
          end
        else
          cg.A_LoadMM_Loc_Reg(list,tocgsize,loc,reg,shuffle);
      end;
    end;

  procedure THLCG2LL.A_LoadMM_Reg_Reg(list: TAsmList; fromsize, tosize: TDef; reg1, reg2: TRegister; shuffle: PMMShuffle);
    var
      fromcgsize: TCgSize;
      tocgsize: TCgSize;
    begin
      fromcgsize:=getintmmcgsize(reg1,Def_CGMMSize(fromsize));
      tocgsize:=getintmmcgsize(reg2,Def_CGMMSize(tosize));
      { records may be stored in mmregisters, but def_cgsize will return an
        integer size for them... }
      cg.A_LoadMM_Reg_Reg(list,fromcgsize,tocgsize,reg1,reg2,shuffle);
    end;

  procedure THLCG2LL.A_LoadMM_Ref_Reg(list: TAsmList; fromsize, tosize: TDef; const ref: TReference; reg: TRegister; shuffle: PMMShuffle);
    var
      tocgsize: TCgSize;
    begin
      { records may be stored in mmregisters, but def_cgsize will return an
        integer size for them... }
      tocgsize:=getintmmcgsize(reg,Def_CGMMSize(tosize));
      cg.A_LoadMM_Ref_Reg(list,Def_CGMMSize(fromsize),tocgsize,ref,reg,shuffle);
    end;

  procedure THLCG2LL.A_LoadMM_Reg_Ref(list: TAsmList; fromsize, tosize: TDef; reg: TRegister; const ref: TReference; shuffle: PMMShuffle);
    var
      fromcgsize: TCgSize;
    begin
      { records may be stored in mmregisters, but def_cgsize will return an
        integer size for them... }
      fromcgsize:=getintmmcgsize(reg,Def_CGMMSize(fromsize));
      cg.A_LoadMM_Reg_Ref(list,fromcgsize,Def_CGMMSize(tosize),reg,ref,shuffle);
    end;

  procedure THLCG2LL.A_LoadMM_Reg_Loc(list: TAsmList; fromsize, tosize: TDef; const reg: TRegister; const loc: TLocation; shuffle: PMMShuffle);
    var
      fromcgsize: TCgSize;
    begin
      { sanity check }
      if Def_CGMMSize(tosize)<>loc.Size then
        InternalError(2012071216);
      { records may be stored in mmregisters, but def_cgsize will return an
        integer size for them... }
      fromcgsize:=getintmmcgsize(reg,Def_CGMMSize(fromsize));
      cg.A_LoadMM_Reg_Loc(list,fromcgsize,reg,loc,shuffle);
    end;

  procedure THLCG2LL.A_LoadMM_Reg_CGPara(list: TAsmList; fromsize: TDef; reg: TRegister; const cgpara: TCGPara; shuffle: PMMShuffle);
    var
      fromcgsize: TCgSize;
    begin
      { records may be stored in mmregisters, but def_cgsize will return an
        integer size for them... }
      fromcgsize:=getintmmcgsize(reg,Def_CGMMSize(fromsize));
      cg.A_LoadMM_Reg_CGPara(list,fromcgsize,reg,cgpara,shuffle);
    end;

  procedure THLCG2LL.A_LoadMM_Ref_CGPara(list: TAsmList; fromsize: TDef; const ref: TReference; const cgpara: TCGPara; shuffle: PMMShuffle);
    begin
      cg.A_LoadMM_Ref_CGPara(list,Def_CGMMSize(fromsize),ref,cgpara,shuffle);
    end;

  procedure THLCG2LL.A_LoadMM_Loc_CGPara(list: TAsmList; fromsize: TDef; const loc: TLocation; const cgpara: TCGPara; shuffle: PMMShuffle);
    begin
      { sanity check }
      if Def_CGMMSize(fromsize)<>loc.Size then
        InternalError(2012071220);
      cg.A_LoadMM_Loc_CGPara(list,loc,cgpara,shuffle);
    end;

  procedure THLCG2LL.A_OpMM_Reg_Reg(list: TAsmList; Op: TOpCG; size: TDef; src, dst: TRegister; shuffle: PMMShuffle);
    begin
      cg.A_OpMM_Reg_Reg(list,op,Def_CGMMSize(size),src,dst,shuffle);
    end;

  procedure THLCG2LL.A_OpMM_Ref_Reg(list: TAsmList; Op: TOpCG; size: TDef; const ref: TReference; reg: TRegister; shuffle: PMMShuffle);
    begin
      cg.A_OpMM_Ref_Reg(list,op,Def_CGMMSize(size),ref,reg,shuffle);
    end;

  procedure THLCG2LL.A_OpMM_Loc_Reg(list: TAsmList; Op: TOpCG; size: TDef; const loc: TLocation; reg: TRegister; shuffle: PMMShuffle);
    begin
      cg.A_OpMM_Loc_Reg(list,op,Def_CGMMSize(size),loc,reg,shuffle);
    end;

  procedure THLCG2LL.A_OpMM_Reg_Ref(list: TAsmList; Op: TOpCG; size: TDef; reg: TRegister; const ref: TReference; shuffle: PMMShuffle);
    begin
      cg.A_OpMM_Reg_Ref(list,op,Def_CGMMSize(size),reg,ref,shuffle);
    end;

  procedure THLCG2LL.A_LoadMM_IntReg_Reg(list: TAsmList; fromsize, tosize: TDef; intreg, mmreg: TRegister; shuffle: PMMShuffle);
    var
      tocgsize: TCgSize;
    begin
      { records may be stored in mmregisters, but def_cgmmsize will return an
        integer size for them... }
      tocgsize:=getintmmcgsize(mmreg,Def_CGMMSize(tosize));
      cg.A_LoadMM_IntReg_Reg(list,Def_CGSize(fromsize),tocgsize,intreg,mmreg,shuffle);
    end;

  procedure THLCG2LL.A_LoadMM_Reg_IntReg(list: TAsmList; fromsize, tosize: TDef; mmreg, intreg: TRegister; shuffle: PMMShuffle);
    var
      fromcgsize: TCgSize;
    begin
      { records may be stored in mmregisters, but def_cgsize will return an
        integer size for them... }
      fromcgsize:=getintmmcgsize(mmreg,Def_CGMMSize(fromsize));
      cg.A_LoadMM_Reg_IntReg(list,fromcgsize,Def_CGSize(tosize),mmreg,intreg,shuffle);
    end;

  procedure THLCG2LL.A_Op_Const_Reg(list: TAsmList; Op: TOpCG; size: TDef; a: TCGInt; reg: TRegister);
    begin
      cg.A_Op_Const_Reg(list,op,Def_CGSize(size),a,reg);
    end;

  procedure THLCG2LL.A_Op_Const_Ref(list: TAsmList; Op: TOpCG; size: TDef; a: TCGInt; const ref: TReference);
    begin
      cg.A_Op_Const_Ref(list,op,Def_CGSize(size),a,ref);
    end;

  procedure THLCG2LL.A_Op_Const_Loc(list: TAsmList; Op: TOpCG; size: TDef; a: TCGInt; const loc: TLocation);
    begin
{$ifdef extdebug}
      if Def_CGSize(size)<>loc.Size then
        InternalError(2010112106);
{$endif}
      case loc.Loc of
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          inherited
        else
          cg.A_Op_Const_Loc(list,op,a,loc);
      end;
    end;

  procedure THLCG2LL.A_Op_Reg_Reg(list: TAsmList; Op: TOpCG; size: TDef; reg1, reg2: TRegister);
    begin
      cg.A_Op_Reg_Reg(list,op,Def_CGSize(size),reg1,reg2);
    end;

  procedure THLCG2LL.A_Op_Reg_Ref(list: TAsmList; Op: TOpCG; size: TDef; reg: TRegister; const ref: TReference);
    begin
      cg.A_Op_Reg_Ref(list,op,Def_CGSize(size),reg,ref);
    end;

  procedure THLCG2LL.A_Op_Ref_Reg(list: TAsmList; Op: TOpCG; size: TDef; const ref: TReference; reg: TRegister);
    begin
      cg.A_Op_Ref_Reg(list,op,Def_CGSize(size),ref,reg);
    end;

  procedure THLCG2LL.A_Op_Reg_Loc(list: TAsmList; Op: TOpCG; size: TDef; reg: TRegister; const loc: TLocation);
    begin
{$ifdef extdebug}
      if Def_CGSize(size)<>loc.Size then
        InternalError(2010112107);
{$endif}
      case loc.Loc of
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          inherited
        else
          cg.A_Op_Reg_Loc(list,op,reg,loc)
      end;
    end;

  procedure THLCG2LL.A_Op_Ref_Loc(list: TAsmList; Op: TOpCG; size: TDef; const ref: TReference; const loc: TLocation);
    begin
{$ifdef extdebug}
      if Def_CGSize(size)<>loc.Size then
        InternalError(2010112103);
{$endif}
      case loc.Loc of
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          inherited
        else
          cg.A_Op_Ref_Loc(list,op,ref,loc);
      end;
    end;

  procedure THLCG2LL.A_Op_Const_Reg_Reg(list: TAsmList; op: TOpCG; size: TDef; a: TCGInt; src, dst: TRegister);
    begin
      cg.A_Op_Const_Reg_Reg(list,op,Def_CGSize(size),a,src,dst);
    end;

  procedure THLCG2LL.A_Op_Reg_Reg_Reg(list: TAsmList; op: TOpCG; size: TDef; src1, src2, dst: TRegister);
    begin
      cg.A_Op_Reg_Reg_Reg(list,op,Def_CGSize(size),src1,src2,dst);
    end;

  procedure THLCG2LL.A_Op_Const_Reg_Reg_CheckOverflow(list: TAsmList; op: TOpCG; size: TDef; a: TCGInt; src, dst: TRegister; setflags: boolean; var ovloc: TLocation);
    begin
      cg.A_Op_Const_Reg_Reg_CheckOverflow(list,op,Def_CGSize(size),a,src,dst,setflags,ovloc);
    end;

  procedure THLCG2LL.A_Op_Reg_Reg_Reg_CheckOverflow(list: TAsmList; op: TOpCG; size: TDef; src1, src2, dst: TRegister; setflags: boolean; var ovloc: TLocation);
    begin
      cg.A_Op_Reg_Reg_Reg_CheckOverflow(list,op,Def_CGSize(size),src1,src2,dst,setflags,ovloc);
    end;

  procedure THLCG2LL.A_Op_Reg(list: TAsmList; Op: TOpCG; size: TDef; reg: TRegister);
    begin
      cg.A_Op_Reg(list,op,Def_CGSize(size),reg);
    end;

  procedure THLCG2LL.A_Op_Ref(list: TAsmList; Op: TOpCG; size: TDef; const ref: TReference);
    begin
      cg.A_Op_Ref(list,op,Def_CGSize(size),ref);
    end;

  procedure THLCG2LL.A_Op_Loc(list: TAsmList; Op: TOpCG; size: TDef; const loc: TLocation);
    begin
{$ifdef extdebug}
      if Def_CGSize(size)<>loc.Size then
        InternalError(2020050704);
{$endif}
      case loc.Loc of
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          inherited
        else
          cg.A_Op_Loc(list,op,loc);
      end;
    end;

  procedure THLCG2LL.A_Cmp_Const_Reg_Label(list: TAsmList; size: TDef; cmp_op: TOpCmp; a: TCGInt; reg: TRegister; l: TAsmLabel);
    begin
      cg.A_Cmp_Const_Reg_Label(list,Def_CGSize(size),cmp_op,a,reg,l);
    end;

  procedure THLCG2LL.A_Cmp_Const_Ref_Label(list: TAsmList; size: TDef; cmp_op: TOpCmp; a: TCGInt; const ref: TReference; l: TAsmLabel);
    begin
      cg.A_Cmp_Const_Ref_Label(list,Def_CGSize(size),cmp_op,a,ref,l);
    end;

  procedure THLCG2LL.A_Cmp_Const_Loc_Label(list: TAsmList; size: TDef; cmp_op: TOpCmp; a: TCGInt; const loc: TLocation; l: TAsmLabel);
    begin
      case loc.Loc of
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          inherited
        else
          cg.A_Cmp_Const_Loc_Label(list,Def_CGSize(size),cmp_op,a,loc,l);
      end;
    end;

  procedure THLCG2LL.A_Cmp_Reg_Reg_Label(list: TAsmList; size: TDef; cmp_op: TOpCmp; reg1, reg2: TRegister; l: TAsmLabel);
    begin
       cg.A_Cmp_Reg_Reg_Label(list,Def_CGSize(size),cmp_op,reg1,reg2,l);
    end;

  procedure THLCG2LL.A_Cmp_Ref_Reg_Label(list: TAsmList; size: TDef; cmp_op: TOpCmp; const ref: TReference; reg: TRegister; l: TAsmLabel);
    begin
      cg.A_Cmp_Ref_Reg_Label(list,Def_CGSize(size),cmp_op,ref,reg,l);
    end;

  procedure THLCG2LL.A_Cmp_Reg_Ref_Label(list: TAsmList; size: TDef; cmp_op: TOpCmp; reg: TRegister; const ref: TReference; l: TAsmLabel);
    begin
      cg.A_Cmp_Reg_Ref_Label(list,Def_CGSize(size),cmp_op,reg,ref,l);
    end;

  procedure THLCG2LL.A_Cmp_Loc_Reg_Label(list: TAsmList; size: TDef; cmp_op: TOpCmp; const loc: TLocation; reg: TRegister; l: TAsmLabel);
    begin
      case loc.Loc of
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          inherited
        else
          cg.A_Cmp_Loc_Reg_Label(list,Def_CGSize(size),cmp_op,loc,reg,l);
      end;
    end;

  procedure THLCG2LL.A_Cmp_Ref_Loc_Label(list: TAsmList; size: TDef; cmp_op: TOpCmp; const ref: TReference; const loc: TLocation; l: TAsmLabel);
    begin
      case loc.Loc of
        LOC_SUBSETREG,LOC_CSUBSETREG,
        LOC_SUBSETREF,LOC_CSUBSETREF:
          inherited
        else
          cg.A_Cmp_Ref_Loc_Label(list,Def_CGSize(size),cmp_op,ref,loc,l);
      end;
    end;

  procedure THLCG2LL.A_Jmp_Always(list: TAsmList; l: TAsmLabel);
    begin
      cg.A_Jmp_Always(list,l);
    end;

{$ifdef cpuflags}
  procedure THLCG2LL.A_Jmp_Flags(list: TAsmList; const f: TResFlags; l: TAsmLabel);
    begin
      cg.A_Jmp_Flags(list,f,l);
    end;

  procedure THLCG2LL.G_Flags2Reg(list: TAsmList; size: TDef; const f: TResFlags; reg: TRegister);
    begin
      cg.G_Flags2Reg(list,Def_CGSize(size),f,reg);
    end;

  procedure THLCG2LL.G_Flags2Ref(list: TAsmList; size: TDef; const f: TResFlags; const ref: TReference);
    begin
      cg.G_Flags2Ref(list,Def_CGSize(size),f,ref);
    end;

{$endif cpuflags}

  procedure THLCG2LL.G_ConcatCopy(list: TAsmList; size: TDef; const source, dest: TReference);
    begin
      cg.G_ConcatCopy(list,source,dest,size.Size);
    end;

  procedure THLCG2LL.G_ConcatCopy_Unaligned(list: TAsmList; size: TDef; const source, dest: TReference);
    begin
      cg.G_ConcatCopy_Unaligned(list,source,dest,size.Size);
    end;

  procedure THLCG2LL.G_OverflowCheck(list: TAsmList; const Loc: TLocation; def: TDef);
    begin
      cg.G_OverflowCheck(list,loc,def);
    end;

  procedure THLCG2LL.G_OverflowCheck_Loc(List: TAsmList; const Loc: TLocation; def: TDef; var ovloc: TLocation);
    begin
      cg.G_OverflowCheck_Loc(list,loc,def,ovloc);
    end;

  procedure THLCG2LL.G_StackPointer_Alloc(list: TAsmList; size: LongInt);
    begin
      cg.G_StackPointer_Alloc(list,size);
    end;

  procedure THLCG2LL.G_Proc_Entry(list: TAsmList; localsize: LongInt; nostackframe: boolean);
    begin
      cg.G_Proc_Entry(list,localsize,nostackframe);
    end;

  procedure THLCG2LL.G_Proc_Exit(list: TAsmList; parasize: LongInt; nostackframe: boolean);
    begin
      cg.G_Proc_Exit(list,parasize,nostackframe);
    end;

  procedure THLCG2LL.G_Adjust_Self_Value(list: TAsmList; procdef: TProcDef; ioffset: aint);
    begin
      cg.G_Adjust_Self_Value(list,procdef,ioffset);
    end;

  procedure THLCG2LL.G_Local_Unwind(list: TAsmList; l: TAsmLabel);
    begin
      cg.G_Local_Unwind(list, l);
    end;

  procedure THLCG2LL.Location_Force_Reg(list: TAsmList; var l: TLocation; src_size, dst_size: TDef; maybeconst: boolean);
    var
{$ifndef cpu64bitalu}
      hregisterhi,
{$endif}
      hregister : TRegister;
{$ifndef cpu64bitalu}
      hreg64 : TRegister64;
{$endif}
      hl: TAsmLabel;
      oldloc : TLocation;
      const_location: boolean;
      dst_cgsize,tmpsize: TCgSize;
    begin
      oldloc:=l;
      dst_cgsize:=Def_CGSize(dst_size);
{$ifndef cpu64bitalu}
      { handle transformations to 64bit separate }
      if dst_cgsize in [OS_64,OS_S64] then
       begin
         if not (l.Size in [OS_64,OS_S64]) then
          begin
            { load a smaller size to OS_64 }
            if l.Loc=LOC_REGISTER then
             begin

               hregister:=cg.MakeRegSize(list,l.Register64.RegLo,OS_32);

             end
            else
             hregister:=cg.GetIntRegister(list,OS_32);
            { load value in low register }
            case l.Loc of
{$ifdef cpuflags}
              LOC_FLAGS :
                begin
                  cg.G_Flags2Reg(list,OS_32,l.ResFlags,hregister);
                  cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
                end;
{$endif cpuflags}
              LOC_JUMP :
                begin
                  cg.A_Label(list,l.TrueLabel);
                  cg.A_Load_Const_Reg(list,OS_INT,1,hregister);
                  CurrentAsmData.getjumplabel(hl);
                  cg.A_Jmp_Always(list,hl);
                  cg.A_Label(list,l.FalseLabel);
                  cg.A_Load_Const_Reg(list,OS_INT,0,hregister);
                  cg.A_Label(list,hl);

                end;
              else
                A_Load_Loc_Reg(list,src_size,U32IntType,l,hregister);
            end;
            { reset hi part, take care of the signed bit of the current value }
            hregisterhi:=cg.GetIntRegister(list,OS_32);
            if (l.Size in [OS_S8,OS_S16,OS_S32]) then
             begin
               if l.Loc=LOC_CONSTANT then
                begin
                  if (LongInt(l.Value)<0) then
                   cg.A_Load_Const_Reg(list,OS_32,LongInt($ffffffff),hregisterhi)
                  else
                   cg.A_Load_Const_Reg(list,OS_32,0,hregisterhi);
                end
               else
                begin
                  cg.A_Op_Const_Reg_Reg(list,OP_SAR,OS_32,31,hregister,
                    hregisterhi);
                end;
             end
            else
             cg.A_Load_Const_Reg(list,OS_32,0,hregisterhi);
            Location_Reset(l,LOC_REGISTER,dst_cgsize);
            l.Register64.RegLo:=hregister;
            l.Register64.RegHi:=hregisterhi;
          end
         else
          begin
            { 64bit to 64bit }
            if ((l.Loc=LOC_CREGISTER) and maybeconst) then
             begin
               hregister:=l.Register64.RegLo;
               hregisterhi:=l.Register64.RegHi;
               const_location := true;
             end
            else
             begin
               hregister:=cg.GetIntRegister(list,OS_32);
               hregisterhi:=cg.GetIntRegister(list,OS_32);
               const_location := false;
             end;
            hreg64.RegLo:=hregister;
            hreg64.RegHi:=hregisterhi;
            { load value in new register }
            cg64.A_Load64_Loc_Reg(list,l,hreg64);
            if not const_location then
              Location_Reset(l,LOC_REGISTER,dst_cgsize)
            else
              Location_Reset(l,LOC_CREGISTER,dst_cgsize);
            l.Register64.RegLo:=hregister;
            l.Register64.RegHi:=hregisterhi;
          end;
       end
      else
{$endif cpu64bitalu}
        begin
          {Do not bother to recycle the existing register. The register
           allocator eliminates unnecessary moves, so it's not needed
           and trying to recycle registers can cause problems because
           the registers changes size and may need additional constraints.

           Not if it's about LOC_CREGISTER's (JM)
           }
          const_location :=
             (maybeconst) and
             (l.Loc = LOC_CREGISTER) and
             (TCgSize2Size[l.Size] = TCgSize2Size[dst_cgsize]) and
             ((l.Size = dst_cgsize) or
              (TCgSize2Size[l.Size] = sizeof(aint)));
          if not const_location then
            hregister:=hlcg.GetRegisterForDef(list,dst_size)
          else
            hregister := l.Register;
          { load value in new register }
          case l.Loc of
{$ifdef cpuflags}
            LOC_FLAGS :
              begin
                cg.G_Flags2Reg(list,dst_cgsize,l.ResFlags,hregister);
                cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
              end;
{$endif cpuflags}
            LOC_JUMP :
              begin
                tmpsize:=dst_cgsize;

                cg.A_Label(list,l.TrueLabel);
                cg.A_Load_Const_Reg(list,tmpsize,1,hregister);
                CurrentAsmData.getjumplabel(hl);
                cg.A_Jmp_Always(list,hl);
                cg.A_Label(list,l.FalseLabel);
                cg.A_Load_Const_Reg(list,tmpsize,0,hregister);
                cg.A_Label(list,hl);

              end;
            else
              begin
                { load_loc_reg can only handle size >= l.size, when the
                  new size is smaller then we need to adjust the size
                  of the original and maybe recalculate l.register for i386 }
                if (TCgSize2Size[dst_cgsize]<TCgSize2Size[l.Size]) then
                 begin
                   if (l.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
                     begin

                         l.Register:=cg.MakeRegSize(list,l.Register,dst_cgsize);
                     end;

                   { be increased in this case, since they have the      }
                   { MSB first in memory and e.g. byte(word_var) should  }
                   { return  the second byte in this case (JM)           }
{$ifdef x86}
                   if not (l.Loc in [LOC_SUBSETREG,LOC_CSUBSETREG]) then
                     begin
                       l.Size:=dst_cgsize;
                       src_size:=dst_size;
                     end;
{$endif x86}
                 end;
                A_Load_Loc_Reg(list,src_size,dst_size,l,hregister);
                if (TCgSize2Size[dst_cgsize]<TCgSize2Size[l.Size])
{$ifdef x86}
                   and (l.Loc in [LOC_SUBSETREG,LOC_CSUBSETREG])
{$endif x86}
                  then
                    l.Size:=dst_cgsize;
              end;
          end;
          if not const_location then
            Location_Reset(l,LOC_REGISTER,dst_cgsize)
          else
            Location_Reset(l,LOC_CREGISTER,dst_cgsize);
          l.Register:=hregister;
        end;
      { Release temp when it was a reference }
      if oldloc.Loc=LOC_REFERENCE then
          Location_FreeTemp(list,oldloc);
    end;

  procedure THLCG2LL.Location_Force_Mem(list: TAsmList; var l: TLocation; size: TDef);
    var
      r: TReference;
    begin
      case l.Loc of
        LOC_FPUREGISTER,
        LOC_CFPUREGISTER :
          begin
            { implement here using tcg because some platforms store records
              in fpu registers in some cases, and a_loadfpu* can't deal with
              record "size" parameters }
            TG.GetHLTemp(list,size,size.Size,tt_normal,r);
            cg.A_LoadFPU_Reg_Ref(list,l.Size,l.Size,l.Register,r);
            Location_Reset_Ref(l,LOC_REFERENCE,l.Size,size.Alignment,[]);
            l.Reference:=r;
          end;
        LOC_MMREGISTER,
        LOC_CMMREGISTER:
          begin
            TG.GetHLTemp(list,size,size.Size,tt_normal,r);
            cg.A_LoadMM_Reg_Ref(list,l.Size,l.Size,l.Register,r,MMS_MoveScalar);
            Location_Reset_Ref(l,LOC_REFERENCE,l.Size,size.Alignment,[]);
            l.Reference:=r;
          end;
        LOC_CONSTANT,
        LOC_REGISTER,
        LOC_CREGISTER :
          begin
            TG.GetHLTemp(list,size,size.Size,tt_normal,r);
{$ifdef cpu64bitalu}
            if l.Size in [OS_128,OS_S128] then
              cg128.A_Load128_Loc_Ref(list,l,r)
            else
{$else cpu64bitalu}
            if l.Size in [OS_64,OS_S64] then
              cg64.A_Load64_Loc_Ref(list,l,r)
            else
{$endif cpu64bitalu}
              A_Load_Loc_Ref(list,size,size,l,r);
            Location_Reset_Ref(l,LOC_REFERENCE,l.Size,size.Alignment,[]);
            l.Reference:=r;
          end;
        else
          inherited;
      end;
    end;

  procedure THLCG2LL.Location_Force_MMRegScalar(list: TAsmList; var l: TLocation; var size: TDef; maybeconst: boolean);
    var
      reg : TRegister;
      href : TReference;
      newsize : TDef;
    begin
      if (l.Loc<>LOC_MMREGISTER)  and
         ((l.Loc<>LOC_CMMREGISTER) or (not maybeconst)) then
        begin
          { if it's in an fpu register, store to memory first }
          if (l.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
            begin
              TG.GetTemp(list,TCgSize2Size[l.Size],TCgSize2Size[l.Size],tt_normal,href);
              cg.A_LoadFPU_Reg_Ref(list,l.Size,l.Size,l.Register,href);
              Location_Reset_Ref(l,LOC_REFERENCE,l.Size,size.Alignment,[]);
              l.Reference:=href;
            end;
{$ifndef cpu64bitalu}
          if (l.Loc in [LOC_REGISTER,LOC_CREGISTER]) and
             (l.Size in [OS_64,OS_S64]) then
            begin
              reg:=cg.GetMMRegister(list,OS_F64);
              cg64.A_LoadMM_IntReg64_Reg(list,OS_F64,l.Register64,reg);
              l.Size:=OS_F64;
              size:=S64FloatType;
            end
          else
{$endif not cpu64bitalu}
            begin
               { on ARM, CFP values may be located in integer registers,
                 and its second_int_to_real() also uses this routine to
                 force integer (memory) values in an mmregister }
               if (l.Size in [OS_32,OS_S32]) then
                 begin
                   size:=CGSize_OrdDef(l.Size);
                   newsize:=S32FloatType;
                 end
               else if (l.Size in [OS_64,OS_S64]) then
                 begin
                   size:=CGSize_OrdDef(l.Size);
                   newsize:=S64FloatType;
                 end
               else
                 newsize:=size;
               reg:=GetMMRegister(list,newsize);
               A_LoadMM_Loc_Reg(list,size,newsize,l,reg,MMS_MoveScalar);
               l.Size:=Def_CGSize(newsize);
               size:=newsize;
             end;
          Location_FreeTemp(list,l);
          Location_Reset(l,LOC_MMREGISTER,l.Size);
          l.Register:=reg;
        end;
    end;

(*
  procedure thlcg2ll.location_force_mmreg(list: TAsmList; var l: tlocation; size: tdef; maybeconst: boolean);
    begin
      ncgutil.location_force_mmreg(list,l,maybeconst);
    end;
*)
  procedure THLCG2LL.MakeToJumpBoolLabels(list: TAsmList; p: TNode; TrueLabel, FalseLabel: TAsmLabel);
    begin
      { loadregvars parameter is no longer used, should be removed from
         ncgutil version as well }
      ncgutil.MakeToJumpBoolLabels(list,p,TrueLabel,FalseLabel);
    end;

  procedure THLCG2LL.Gen_Load_Para_Value(list: TAsmList);

    procedure get_para(const ParaLoc:TCGParaLocation);
      begin
         case ParaLoc.Loc of
           LOC_REGISTER :
             begin
               if GetSupReg(ParaLoc.Register)<first_int_imreg then
                 cg.GetCPURegister(list,ParaLoc.Register);
             end;
           LOC_MMREGISTER :
             begin
               if GetSupReg(ParaLoc.Register)<first_mm_imreg then
                 cg.GetCPURegister(list,ParaLoc.Register);
             end;
           LOC_FPUREGISTER :
             begin
               if GetSupReg(ParaLoc.Register)<first_fpu_imreg then
                 cg.GetCPURegister(list,ParaLoc.Register);
             end;
           else
             ;
         end;
      end;

   var
     i : LongInt;
     currpara : TParaVarSym;
     ParaLoc  : PCGParaLocation;
   begin
     if (po_assembler in CurrentProcInfo.procdef.ProcOptions) or
     { exceptfilters have a single hidden 'parentfp' parameter, which
       is handled by tcg.g_proc_entry. }
        (CurrentProcInfo.procdef.ProcTypeOption=potype_exceptfilter) then
       exit;

     { Allocate registers used by parameters }
     for i:=0 to CurrentProcInfo.procdef.paras.count-1 do
       begin
         currpara:=TParaVarSym(CurrentProcInfo.procdef.paras[i]);
         ParaLoc:=currpara.ParaLoc[calleeside].Location;
         while Assigned(ParaLoc) do
           begin
             if ParaLoc^.Loc in [LOC_REGISTER,LOC_FPUREGISTER,LOC_MMREGISTER] then
               get_para(ParaLoc^);
             ParaLoc:=ParaLoc^.next;
           end;
       end;

     { Copy parameters to local references/registers }
     for i:=0 to CurrentProcInfo.procdef.paras.count-1 do
       begin
         currpara:=TParaVarSym(CurrentProcInfo.procdef.paras[i]);
         { don't use currpara.vardef, as this will be wrong in case of
           call-by-reference parameters (it won't contain the pointerdef) }
         Gen_Load_CGPara_Loc(list,currpara.ParaLoc[calleeside].def,currpara.ParaLoc[calleeside],currpara.InitialLoc,ParaManager.Param_Use_ParaLoc(currpara.ParaLoc[calleeside]));
         { gen_load_cgpara_loc() already allocated the initialloc
           -> don't allocate again }
         if currpara.InitialLoc.Loc in [LOC_CREGISTER,LOC_CFPUREGISTER,LOC_CMMREGISTER] then
           begin
             Gen_Alloc_RegVar(list,currpara,false);
             hlcg.VarSym_Set_LocAlloc(list,currpara);
           end;
       end;

     { generate copies of call by value parameters, must be done before
       the initialization and body is parsed because the refcounts are
       incremented using the local copies }
     CurrentProcInfo.procdef.ParaST.SymList.ForEachCall(@hlcg.G_CopyValueParas,list);
     if not(po_assembler in CurrentProcInfo.procdef.ProcOptions) then
       begin
         { initialize refcounted paras, and trash others. Needed here
           instead of in gen_initialize_code, because when a reference is
           initialized or trashed while the pointer to that reference is kept
           in a regvar, we add a register move and that one again has to
           come after the parameter loading code as far as the register
           allocator is concerned }
         CurrentProcInfo.procdef.ParaST.SymList.ForEachCall(@Init_Paras,list);
       end;
   end;

  procedure THLCG2LL.Gen_LoadFPU_Loc_CGPara(list: TAsmList; size: TDef; const l: TLocation; const cgpara: TCGPara; locintsize: LongInt);
    var
      locsize : TCgSize;
      tmploc : TLocation;
    begin
      if not(l.Size in [OS_32,OS_S32,OS_64,OS_S64,OS_128,OS_S128]) then
        locsize:=l.Size
      else
        locsize:=Int_Float_CGSize(TCgSize2Size[l.Size]);
      case l.Loc of
        LOC_MMREGISTER,
        LOC_CMMREGISTER:
          case cgpara.Location^.Loc of
            LOC_REFERENCE,
            LOC_CREFERENCE,
            LOC_MMREGISTER,
            LOC_CMMREGISTER,
            LOC_REGISTER,
            LOC_CREGISTER :
              cg.A_LoadMM_Reg_CGPara(list,locsize,l.Register,cgpara,MMS_MoveScalar);
            LOC_FPUREGISTER,
            LOC_CFPUREGISTER:
              begin
                tmploc:=l;
                Location_Force_FPUReg(list,tmploc,size,false);
                cg.A_LoadFPU_Reg_CGPara(list,tmploc.Size,tmploc.Register,cgpara);
              end;
            else
              InternalError(200204249);
          end;
        LOC_FPUREGISTER,
        LOC_CFPUREGISTER:
          case cgpara.Location^.Loc of
            LOC_MMREGISTER,
            LOC_CMMREGISTER:
              begin
                tmploc:=l;
                Location_Force_MMRegScalar(list,tmploc,size,false);
                cg.A_LoadMM_Reg_CGPara(list,tmploc.Size,tmploc.Register,cgpara,MMS_MoveScalar);
              end;
            { Some targets pass floats in normal registers }
            LOC_REGISTER,
            LOC_CREGISTER,
            LOC_REFERENCE,
            LOC_CREFERENCE,
            LOC_FPUREGISTER,
            LOC_CFPUREGISTER:
              cg.A_LoadFPU_Reg_CGPara(list,locsize,l.Register,cgpara);
            else
              InternalError(2002042433);
          end;
        LOC_REFERENCE,
        LOC_CREFERENCE:
          case cgpara.Location^.Loc of
            LOC_MMREGISTER,
            LOC_CMMREGISTER:
              cg.A_LoadMM_Ref_CGPara(list,locsize,l.Reference,cgpara,MMS_MoveScalar);
            { Some targets pass floats in normal registers }
            LOC_REFERENCE,
            LOC_CREFERENCE:
              if Use_VectorFPU(size) then
                cg.A_LoadMM_Ref_CGPara(list,locsize,l.Reference,cgpara,MMS_MoveScalar)
              else
                cg.A_LoadFPU_Ref_CGPara(list,locsize,l.Reference,cgpara);
            LOC_REGISTER,
            LOC_CREGISTER,
            LOC_FPUREGISTER,
            LOC_CFPUREGISTER:
              cg.A_LoadFPU_Ref_CGPara(list,locsize,l.Reference,cgpara);
            else
              InternalError(2002042431);
          end;
        LOC_REGISTER,
        LOC_CREGISTER :
          begin
{$ifndef cpu64bitalu}
             { Only a_load_ref_cgpara supports multiple locations, when the
               value is still a const or in a register then write it
               to a reference first. This situation can be triggered
               by typecasting an int64 constant to a record of 8 bytes }
             if locsize = OS_F64 then
               begin
                 if (cgpara.Location^.Next=nil) and (l.Size in [OS_64,OS_S64]) and
                   (cgpara.Size in [OS_64,OS_S64]) then
                   cg64.A_Load64_Reg_CGPara(list,l.Register64,cgpara)
                 else
                   begin
                     tmploc:=l;
                     Location_Force_Mem(list,tmploc,size);
                     cg.A_Load_Loc_CGPara(list,tmploc,cgpara);
                     Location_FreeTemp(list,tmploc);
                   end;
               end
             else
{$endif not cpu64bitalu}
             case cgpara.Location^.Loc of
               LOC_FPUREGISTER,
               LOC_CFPUREGISTER:
                 begin
                   tmploc:=l;
                   Location_Force_Mem(list,tmploc,size);
                   cg.A_LoadFPU_Ref_CGPara(list,locsize,tmploc.Reference,cgpara);
                 end;
               LOC_MMREGISTER,
               LOC_CMMREGISTER:
                 begin
                   tmploc:=l;
                   Location_Force_Mem(list,tmploc,size);
                   cg.A_LoadMM_Ref_CGPara(list,locsize,tmploc.Reference,cgpara,MMS_MoveScalar);
                 end;
               else
                 cg.A_Load_Loc_CGPara(list,l,cgpara);
             end;
          end;
        else
          InternalError(2002042432);
      end;
    end;

  procedure THLCG2LL.Gen_Load_Loc_CGPara(list: TAsmList; vardef: TDef; const l: TLocation; const cgpara: TCGPara);
    var
      tmploc: TLocation;
    begin
      { skip e.g. empty records }
      if (cgpara.Location^.Loc = LOC_VOID) then
        exit;

      { Handle Floating point types differently

        This doesn't depend on emulator settings, emulator settings should
        be handled by cpupara }
      if (vardef.typ=floatdef) or
         { some ABIs return certain records in an fpu register }
         (l.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER]) or
         (Assigned(cgpara.Location) and
          (cgpara.Location^.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER])) then
        begin
          Gen_LoadFPU_Loc_CGPara(list,vardef,l,cgpara,vardef.Size);
          exit;
        end;

      case l.Loc of
        LOC_CONSTANT,
        LOC_REGISTER,
        LOC_CREGISTER,
        LOC_REFERENCE,
        LOC_CREFERENCE :
          begin
{$ifdef cpu64bitalu}
            { use cg128 only if no "chained" location is used }
            if Is_MethodPointer(cgpara.def) and (l.Size in [OS_128,OS_S128]) and (cgpara.Size in [OS_128,OS_S128]) then
              cg128.A_Load128_Loc_CGPara(list,l,cgpara)
            else
{$else cpu64bitalu}
            { use cg64 only for int64, not for 8 byte records; in particular,
              filter out records passed in fpu/mm register}
            if (l.Size in [OS_64,OS_S64]) and (cgpara.Size in [OS_64,OS_S64]) and (cgpara.Location^.Loc in [LOC_REGISTER,LOC_REFERENCE]) then
              cg64.A_Load64_Loc_CGPara(list,l,cgpara)
            else
{$endif cpu64bitalu}
              begin

                { Only a_load_ref_cgpara supports multiple locations, when the
                  value is still a const or in a register then write it
                  to a reference first. This situation can be triggered
                  by typecasting an int64 constant to a record of 8 bytes }
{$ifdef cpu64bitalu}
                if l.Size in [OS_128,OS_S128] then
{$else cpu64bitalu}
                if l.Size in [OS_64,OS_S64] then
{$endif cpu64bitalu}
                  begin
                    tmploc:=l;
                    Location_Force_Mem(list,tmploc,vardef);
                    A_Load_Loc_CGPara(list,vardef,tmploc,cgpara);
                    { do not free the tmploc in case the original value was
                      already in memory, because the caller (ncgcal) will then
                      free it again later }
                    if not(l.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                      Location_FreeTemp(list,tmploc);
                  end
                else
                  A_Load_Loc_CGPara(list,vardef,l,cgpara);
              end;
          end;
        LOC_MMREGISTER,
        LOC_CMMREGISTER:
          begin
            case l.Size of
              OS_F32,
              OS_F64:
                cg.A_LoadMM_Loc_CGPara(list,l,cgpara,MMS_MoveScalar);
              else
                cg.A_LoadMM_Loc_CGPara(list,l,cgpara,nil);
            end;
          end;
        else
          InternalError(200204241);
      end;
    end;

  procedure THLCG2LL.Gen_Load_CGPara_Loc(list: TAsmList; vardef: TDef; const para: TCGPara; var destloc: TLocation; reusepara: boolean);

    procedure unget_para(const ParaLoc:TCGParaLocation);
      begin
         case ParaLoc.Loc of
           LOC_REGISTER :
             begin
               if GetSupReg(ParaLoc.Register)<first_int_imreg then
                 cg.UngetCPURegister(list,ParaLoc.Register);
             end;
           LOC_MMREGISTER :
             begin
               if GetSupReg(ParaLoc.Register)<first_mm_imreg then
                 cg.UngetCPURegister(list,ParaLoc.Register);
             end;
           LOC_FPUREGISTER :
             begin
               if GetSupReg(ParaLoc.Register)<first_fpu_imreg then
                 cg.UngetCPURegister(list,ParaLoc.Register);
             end;
           else
             ;
         end;
      end;

    var
      ParaLoc   : PCGParaLocation;
      href      : TReference;
      sizeleft  : aint;
      tempref   : TReference;
      loadsize  : TCGInt;
      tempreg  : TRegister;
{$ifndef cpu64bitalu}
      reg64    : TRegister64;

{$endif not cpu64bitalu}
    begin
      ParaLoc:=para.Location;
      if not Assigned(ParaLoc) then
        InternalError(200408203);
      { skip e.g. empty records }
      if (ParaLoc^.Loc = LOC_VOID) then
        exit;
      case destloc.Loc of
        LOC_REFERENCE :
          begin
            { If the parameter location is reused we don't need to copy
              anything }
            if not reusepara then
              begin
                href:=destloc.Reference;
                sizeleft:=para.IntSize;
                while Assigned(ParaLoc) do
                  begin
                    if (ParaLoc^.Size=OS_NO) then
                      begin
                        { Can only be a reference that contains the rest
                          of the parameter }
                        if (ParaLoc^.Loc<>LOC_REFERENCE) or
                           Assigned(ParaLoc^.next) then
                          InternalError(2005013010);
                        cg.A_Load_CGParaLoc_Ref(list,ParaLoc^,href,sizeleft,destloc.Reference.Alignment);
                        inc(href.Offset,sizeleft);
                        sizeleft:=0;
                      end
                    else
                      begin

                        if TCgSize2Size[destloc.Size]<>0 then
                          loadsize:=min(min(TCgSize2Size[ParaLoc^.Size],TCgSize2Size[destloc.Size]),sizeleft)
                        else
                          loadsize:=min(TCgSize2Size[ParaLoc^.Size],sizeleft);

                        cg.A_Load_CGParaLoc_Ref(list,ParaLoc^,href,loadsize,destloc.Reference.Alignment);
                        inc(href.Offset,loadsize);
                        dec(sizeleft,loadsize);
                      end;
                    unget_para(ParaLoc^);
                    ParaLoc:=ParaLoc^.next;
                  end;
              end;
          end;
        LOC_REGISTER,
        LOC_CREGISTER :
          begin
{$ifdef cpu64bitalu}
            if (para.Size in [OS_128,OS_S128,OS_F128]) and
               ({ in case of fpu emulation, or abi's that pass fpu values
                  via integer registers }
                (vardef.typ=floatdef) or
                 Is_MethodPointer(vardef) or
                 Is_Record(vardef)) then
              begin
                case ParaLoc^.Loc of
                  LOC_REGISTER,
                  LOC_MMREGISTER:
                    begin
                      if not Assigned(ParaLoc^.next) then
                        InternalError(200410104);
                      case TCgSize2Size[ParaLoc^.Size] of
                        8:
                          begin
                            begin
                                { paraloc^ -> low
                                  paraloc^.next -> high }
                                unget_para(ParaLoc^);
                                Gen_Alloc_RegLoc(list,destloc,vardef);
                                cg.A_Load_CGParaLoc_AnyReg(list,OS_64,ParaLoc^,destloc.Register128.RegLo,8);
                                unget_para(ParaLoc^.next^);
                                cg.A_Load_CGParaLoc_AnyReg(list,OS_64,ParaLoc^.next^,destloc.Register128.RegHi,8);
                              end;
                          end;
                        4:
                          begin
                            { The 128-bit parameter is located in 4 32-bit MM registers.
                              It is needed to copy them to 2 64-bit int registers.
                              A code generator or a target cpu must support loading of a 32-bit MM register to
                              a 64-bit int register, zero extending it. }
                            Gen_Alloc_RegLoc(list,destloc,vardef);
                            tempreg:=cg.GetIntRegister(list,OS_64);
                            // Low part of the 128-bit param
                            unget_para(ParaLoc^);
                            cg.A_Load_CGParaLoc_AnyReg(list,OS_64,ParaLoc^,tempreg,4);
                            ParaLoc:=ParaLoc^.next;
                            if ParaLoc=nil then
                              InternalError(2018101703);
                            unget_para(ParaLoc^);
                            cg.A_Load_CGParaLoc_AnyReg(list,OS_64,ParaLoc^,destloc.Register128.RegLo,4);
                            cg.A_Op_Const_Reg(list,OP_SHL,OS_64,32,destloc.Register128.RegLo);
                            cg.A_Op_Reg_Reg(list,OP_OR,OS_64,tempreg,destloc.Register128.RegLo);
                            // High part of the 128-bit param
                            ParaLoc:=ParaLoc^.next;
                            if ParaLoc=nil then
                              InternalError(2018101704);
                            unget_para(ParaLoc^);
                            cg.A_Load_CGParaLoc_AnyReg(list,OS_64,ParaLoc^,tempreg,4);
                            ParaLoc:=ParaLoc^.next;
                            if ParaLoc=nil then
                              InternalError(2018101705);
                            unget_para(ParaLoc^);
                            cg.A_Load_CGParaLoc_AnyReg(list,OS_64,ParaLoc^,destloc.Register128.RegHi,4);
                            cg.A_Op_Const_Reg(list,OP_SHL,OS_64,32,destloc.Register128.RegHi);
                            cg.A_Op_Reg_Reg(list,OP_OR,OS_64,tempreg,destloc.Register128.RegHi);
                          end
                        else
                          InternalError(2018101701);
                      end;
                    end;
                  LOC_REFERENCE:
                    begin
                      Gen_Alloc_RegLoc(list,destloc,vardef);
                      Reference_Reset_Base(href,CPointerDef.getreusable(vardef),ParaLoc^.Reference.Index,ParaLoc^.Reference.Offset,CTempPosInvalid,para.Alignment,[]);
                      cg128.A_Load128_Ref_Reg(list,href,destloc.Register128);
                      unget_para(ParaLoc^);
                    end;
                  else
                    InternalError(2012090607);
                end
              end
            else
{$else cpu64bitalu}
            if (para.Size in [OS_64,OS_S64,OS_F64]) and
               (Is_64Bit(vardef) or
                { in case of fpu emulation, or abi's that pass fpu values
                  via integer registers }
                (vardef.typ=floatdef) or
                 Is_MethodPointer(vardef) or
                 Is_Record(vardef)) then
              begin
                case ParaLoc^.Loc of
                  LOC_REGISTER:
                    begin
                      case para.Locations_Count of


                        2:
                          begin
                              { paraloc^ -> low
                                paraloc^.next -> high }
                              unget_para(ParaLoc^);
                              Gen_Alloc_RegLoc(list,destloc,vardef);
                              cg.A_Load_CGParaLoc_AnyReg(list,OS_32,ParaLoc^,destloc.Register64.RegLo,4);
                              unget_para(ParaLoc^.next^);
                              cg.A_Load_CGParaLoc_AnyReg(list,OS_32,ParaLoc^.next^,destloc.Register64.RegHi,4);
                            end;
                        else
                          { unexpected number of paralocs }
                          InternalError(200410104);
                      end;
                    end;
                  LOC_REFERENCE:
                    begin
                      Gen_Alloc_RegLoc(list,destloc,vardef);
                      Reference_Reset_Base(href,CPointerDef.getreusable(vardef),ParaLoc^.Reference.Index,ParaLoc^.Reference.Offset,CTempPosInvalid,para.Alignment,[]);
                      cg64.A_Load64_Ref_Reg(list,href,destloc.Register64);
                      unget_para(ParaLoc^);
                    end;
                  else
                    InternalError(2005101501);
                end
              end
            else
{$endif cpu64bitalu}
              begin
                if Assigned(ParaLoc^.next) then
                  begin
                    if (destloc.Size in [OSPair,OSSPair]) and
                      (para.Size in [OSPair,OSSPair]) then
                      begin
                        unget_para(ParaLoc^);
                        Gen_Alloc_RegLoc(list,destloc,vardef);
                        cg.A_Load_CGParaLoc_AnyReg(list,OS_INT,ParaLoc^,destloc.Register,sizeof(aint));
                        unget_para(ParaLoc^.Next^);

                          cg.A_Load_CGParaLoc_AnyReg(list,OS_INT,ParaLoc^.Next^,destloc.RegisterHi,sizeof(aint));

                      end

                    else
                      begin
                        { this can happen if a parameter is spread over
                          multiple paralocs, e.g. if a record with two single
                          fields must be passed in two single precision
                          registers }
                        { does it fit in the register of destloc? }
                        sizeleft:=para.IntSize;
                        if sizeleft<>vardef.Size then
                          InternalError(2014122806);
                        if sizeleft<>TCgSize2Size[destloc.Size] then
                          InternalError(200410105);
                        { store everything first to memory, then load it in
                          destloc }
                        TG.GetTemp(list,sizeleft,sizeleft,tt_persistent,tempref);
                        Gen_Alloc_RegLoc(list,destloc,vardef);
                        while sizeleft>0 do
                          begin
                            if not Assigned(ParaLoc) then
                              InternalError(2014122807);
                            unget_para(ParaLoc^);
                            cg.A_Load_CGParaLoc_Ref(list,ParaLoc^,tempref,sizeleft,NewAlignment(para.Alignment,para.IntSize-sizeleft));
                            if (ParaLoc^.Size=OS_NO) and
                               Assigned(ParaLoc^.next) then
                              InternalError(2014122805);
                            inc(tempref.Offset,TCgSize2Size[ParaLoc^.Size]);
                            dec(sizeleft,TCgSize2Size[ParaLoc^.Size]);
                            ParaLoc:=ParaLoc^.next;
                          end;
                        dec(tempref.Offset,para.IntSize);
                        cg.A_Load_Ref_Reg(list,para.Size,para.Size,tempref,destloc.Register);
                        TG.UnGetTemp(list,tempref);
                      end;
                  end
                else
                  begin
                    unget_para(ParaLoc^);
                    Gen_Alloc_RegLoc(list,destloc,vardef);
                    cg.A_Load_CGParaLoc_AnyReg(list,destloc.Size,ParaLoc^,destloc.Register,sizeof(aint));
                  end;
              end;
          end;
        LOC_FPUREGISTER,
        LOC_CFPUREGISTER :
          begin
            unget_para(ParaLoc^);
            Gen_Alloc_RegLoc(list,destloc,vardef);
            { from register to register -> alignment is irrelevant }
            cg.A_Load_CGParaLoc_AnyReg(list,destloc.Size,ParaLoc^,destloc.Register,0);
            if Assigned(ParaLoc^.next) then
              InternalError(200410109);
          end;
        LOC_MMREGISTER,
        LOC_CMMREGISTER :
          begin
{$ifndef cpu64bitalu}
            { ARM vfp floats are passed in integer registers }
            if (para.Size=OS_F64) and
               (ParaLoc^.Size in [OS_32,OS_S32]) and
               Use_VectorFPU(vardef) then
              begin
                { we need 2x32bit reg }
                if not Assigned(ParaLoc^.next) or
                   Assigned(ParaLoc^.next^.next) then
                  InternalError(2009112421);
                unget_para(ParaLoc^.next^);
                case ParaLoc^.next^.Loc of
                  LOC_REGISTER:
                    tempreg:=ParaLoc^.next^.Register;
                  LOC_REFERENCE:
                    begin
                      tempreg:=cg.GetIntRegister(list,OS_32);
                      cg.A_Load_CGParaLoc_AnyReg(list,OS_32,ParaLoc^.next^,tempreg,4);
                    end;
                  else
                    InternalError(2012051301);
                end;
                { don't free before the above, because then the getintregister
                  could reallocate this register and overwrite it }
                unget_para(ParaLoc^);
                Gen_Alloc_RegLoc(list,destloc,vardef);
                reg64:=JoinReg64(ParaLoc^.Register,tempreg);
                cg64.A_LoadMM_IntReg64_Reg(list,OS_F64,reg64,destloc.Register);
              end
            else
{$endif not cpu64bitalu}
              begin
                if not Assigned(ParaLoc^.next) then
                  begin
                    unget_para(ParaLoc^);
                    Gen_Alloc_RegLoc(list,destloc,vardef);
                    { from register to register -> alignment is irrelevant }
                    cg.A_Load_CGParaLoc_AnyReg(list,destloc.Size,ParaLoc^,destloc.Register,0);
                  end
                else
                  begin
                    InternalError(200410108);
                  end;
                { data could come in two memory locations, for now
                  we simply ignore the sanity check (FK)
                if assigned(paraloc^.next) then
                  internalerror(200410108);
                }
              end;
          end;
        else
          InternalError(2010052903);
      end;
    end;

  function THLCG2LL.getintmmcgsize(reg: TRegister; size: TCgSize): TCgSize;
    begin
      result:=size;
      if GetRegType(reg)=R_MMREGISTER then
        begin
          case size of
            OS_32:
              result:=OS_F32;
            OS_64:
              result:=OS_F64;
            OS_128:
              result:=OS_M128;
            else
              ;
          end;
        end;
    end;


end.
