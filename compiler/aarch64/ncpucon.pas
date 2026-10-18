{
    Copyright (c) 2005 by Florian Klaempfl

    Code generation for const nodes on the AArch64

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
unit ncpucon;

{$i fpcdefs.inc}

interface

    uses
      TPCompilerReal,
      node,ncgcon,cpubase;

    type
      TAArch64RealConstNode = class(TCGRealConstNode)
        function Pass_1 : TNode;override;
        procedure Pass_Generate_Code;override;
      end;

  implementation

    uses
      Verbose,
      GlobType,Globals,
      CPUInfo,
      aasmbase,aasmtai,AAsmData,aasmcpu,
      symdef,
      defutil,
      cgbase,cgutils,cgobj,
      ProcInfo,
      ncon;

{*****************************************************************************
                           TARMREALCONSTNODE
*****************************************************************************}

    function TAArch64RealConstNode.Pass_1 : TNode;
      begin
        Result:=nil;
        if IsFloatImmediate(TFloatDef(ResultDef).FloatType,ValueReal) then
           expectloc:=LOC_MMREGISTER
         else
           Result:=Inherited Pass_1;
      end;


    procedure TAArch64RealConstNode.Pass_Generate_Code;
      var
        lReg : TRegister;
      begin
        if IsFloatImmediate(TFloatDef(ResultDef).FloatType,ValueReal) then
          begin
            Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));
            Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_realconst(A_FMOV,
              Location.Register,ValueReal));
          end
        { cast and compare the bit pattern as we cannot handle -0.0 }
        else if IsPosZero(ValueReal) then
          begin
            Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));
            Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
            lReg:=NewReg(R_MMREGISTER,GetSupReg(Location.Register),R_SUBMM16B);
            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_EOR,
              lReg,lReg,lReg));
          end
        else
          Inherited Pass_Generate_Code;
      end;

begin
  CRealConstNode:=TAArch64RealConstNode;
end.
