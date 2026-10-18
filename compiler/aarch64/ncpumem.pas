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
      procedure Pass_Generate_Code; override;
    end;

    TAArch64VecNode = class(TCGVecNode)
     protected
      function Valid_Index_Size(ASize: TCgSize): Boolean; override;
     public
       procedure Update_Reference_Reg_Mul(AIndexReg: TRegister; ARegSize: TDef; AElementSize: AInt); override;
    end;

implementation

  uses
    CUtils,Verbose,
    defutil,
    AAsmData,cpubase,
    cgutils,
    cgobj;

  { taarch64loadparentfpnode }

  procedure TAArch64LoadParentFPNode.Pass_Generate_Code;
    begin
      inherited Pass_Generate_Code;
      { see the comments in tcgaarch64.g_proc_entry }
      if (Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) and
         (Location.Register=NR_STACK_POINTER_REG) then
        if (Kind=lpf_forpara) then
          Location.Register:=NR_FRAME_POINTER_REG
        else
          begin
            { load stack pointer in a different register, as many instructions
              cannot directly work with the stack pointer. The register
              allocator can merge them if possible }
            Location.Register:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
            cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,NR_STACK_POINTER_REG,Location.Register);
            Location.Loc:=LOC_REGISTER;
          end;
    end;


  { taarch64vecnode }

  function TAArch64VecNode.Valid_Index_Size(ASize: TCgSize): Boolean;
    begin
      { all sizes are ok if we handle the "reference reg mul", because
         a) we use a 64 bit register for 64 bit values, and a 32 bit one (that
            we can sign/zero-extend inside the reference) for smaller values
         b) for values < 32 bit, the entire 32 bit register always contains the
            sign/zero-extended version of the value }
      Result:=
        not Is_Packed_Array(Left.ResultDef) and
        (Get_Mul_Size in [1,2,4,8,16]);
    end;


  procedure TAArch64VecNode.Update_Reference_Reg_Mul(AIndexReg: TRegister; ARegSize: TDef; AElementSize: AInt);
    var
      lBaseReg: TRegister;
      lOldOffset: ASizeInt;
      lShift: Byte;
    begin
      { we can only scale the index by shl 0..4 }
      if not(AElementSize in [1,2,4,8,16]) then
        begin
          inherited;
          exit;
        end;
      { we need a base set and an index available }
      if (Location.Reference.Base=NR_NO) or
         (Location.Reference.Index<>NR_NO) then
        begin
          { don't integrate the offset yet, make_simple_ref() may be able to
            handle it more efficiently later (unless an offset is all we have
            -> optimization for someone that wants to add support for AArch64
            embedded targets) }
          lOldOffset:=Location.Reference.Offset;
          Location.Reference.Offset:=0;
          lBaseReg:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
          cg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,Location.Reference,lBaseReg);
          Reference_Reset_Base(Location.Reference,lBaseReg,lOldOffset,Location.Reference.TempPos,Location.Reference.Alignment,Location.Reference.Volatility);
        end;
      lShift:=BsfDWord(AElementSize);
      Location.Reference.Index:=AIndexReg;
      { sign/zero-extend? }
      if ARegSize.Size=8 then
        if lShift<>0 then
          Location.Reference.ShiftMode:=SM_LSL
        else
          Location.Reference.ShiftMode:=SM_NONE
      else if Is_Signed(ARegSize) then
        Location.Reference.ShiftMode:=SM_SXTW
      else if lShift<>0 then
        Location.Reference.ShiftMode:=SM_UXTW
      else
        { the upper 32 bits are always already zero-extended -> just use 64 bit
          register }
        Location.Reference.Index:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,Location.Reference.Index,OS_64);
      Location.Reference.ShiftImm:=lShift;
      Location.Reference.Alignment:=NewAlignment(Location.Reference.Alignment,AElementSize);
    end;


begin
  CLoadParentFPNode:=TAArch64LoadParentFPNode;
  CVecNode:=TAArch64VecNode;
end.
