{
    Copyright (c) 2014 by Jonas Maebe

    Generate AArch64 code for in memory related nodes

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
unit ncpumem;

{$i fpcdefs.inc}

interface

  uses
    GlobType,
    cgbase,
    symtype,
    node,nmem,ncgmem;

  type
    TAArch64LoadParentFPNode = class(TCGLoadParentFPNode)
      procedure pass_generate_code; override;
    end;

    TAArch64VecNode = class(TCGVecNode)
     protected
      function valid_index_size(size: TCgSize): boolean; override;
     public
       procedure update_reference_reg_mul(maybe_const_reg: TRegister; regsize: TDef; l: aint); override;
    end;

implementation

  uses
    CUtils,Verbose,
    defutil,
    AAsmData,cpubase,
    cgutils,
    cgobj;

  { taarch64loadparentfpnode }

  procedure TAArch64LoadParentFPNode.pass_generate_code;
    begin
      inherited pass_generate_code;
      { see the comments in tcgaarch64.g_proc_entry }
      if (location.Loc in [LOC_REGISTER,LOC_CREGISTER]) and
         (location.Register=NR_STACK_POINTER_REG) then
        if (kind=lpf_forpara) then
          location.Register:=NR_FRAME_POINTER_REG
        else
          begin
            { load stack pointer in a different register, as many instructions
              cannot directly work with the stack pointer. The register
              allocator can merge them if possible }
            location.Register:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
            cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,NR_STACK_POINTER_REG,location.Register);
            location.Loc:=LOC_REGISTER;
          end;
    end;


  { taarch64vecnode }

  function TAArch64VecNode.valid_index_size(size: TCgSize): boolean;
    begin
      { all sizes are ok if we handle the "reference reg mul", because
         a) we use a 64 bit register for 64 bit values, and a 32 bit one (that
            we can sign/zero-extend inside the reference) for smaller values
         b) for values < 32 bit, the entire 32 bit register always contains the
            sign/zero-extended version of the value }
      result:=
        not Is_Packed_Array(left.resultdef) and
        (get_mul_size in [1,2,4,8,16]);
    end;


  procedure TAArch64VecNode.update_reference_reg_mul(maybe_const_reg: TRegister; regsize: TDef; l: aint);
    var
      base: TRegister;
      oldoffset: asizeint;
      shift: byte;
    begin
      { we can only scale the index by shl 0..4 }
      if not(l in [1,2,4,8,16]) then
        begin
          inherited;
          exit;
        end;
      { we need a base set and an index available }
      if (location.Reference.Base=NR_NO) or
         (location.Reference.Index<>NR_NO) then
        begin
          { don't integrate the offset yet, make_simple_ref() may be able to
            handle it more efficiently later (unless an offset is all we have
            -> optimization for someone that wants to add support for AArch64
            embedded targets) }
          oldoffset:=location.Reference.Offset;
          location.Reference.Offset:=0;
          base:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
          cg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,location.Reference,base);
          Reference_Reset_Base(location.Reference,base,oldoffset,location.Reference.TempPos,location.Reference.Alignment,location.Reference.Volatility);
        end;
      shift:=BsfDWord(l);
      location.Reference.Index:=maybe_const_reg;
      { sign/zero-extend? }
      if regsize.Size=8 then
        if shift<>0 then
          location.Reference.ShiftMode:=SM_LSL
        else
          location.Reference.ShiftMode:=SM_NONE
      else if Is_Signed(regsize) then
        location.Reference.ShiftMode:=SM_SXTW
      else if shift<>0 then
        location.Reference.ShiftMode:=SM_UXTW
      else
        { the upper 32 bits are always already zero-extended -> just use 64 bit
          register }
        location.Reference.Index:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,location.Reference.Index,OS_64);
      location.Reference.ShiftImm:=shift;
      location.Reference.Alignment:=NewAlignment(location.Reference.Alignment,l);
    end;


begin
  CLoadParentFPNode:=TAArch64LoadParentFPNode;
  CVecNode:=TAArch64VecNode;
end.
