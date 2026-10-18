{
    Copyright (c) 2002 by Florian Klaempfl

    Implements the x86-64 specific part of call nodes

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
unit nx64cal;

{$i fpcdefs.inc}

interface

    uses
      symdef,
      ncal,nx86cal;

    type
       TX8664CallNode = class(TX86CallNode)
       protected
         procedure Extra_Call_Code;override;
         procedure Set_Result_Location(ARealResultDef: TStoredDef);override;
       end;


implementation

    uses
      GlobType,
      Systems,Verbose,CUtils,
      cpubase,cgbase,cgutils,cgobj,
      symconst,symcpu,nld,
      aasmtai,AAsmData,aasmcpu,
      cpupi;

    procedure TX8664CallNode.Extra_Call_Code;
      var
        lMMRegCount : AInt;
      begin
        { x86_64 requires %al to contain the no. SSE regs passed }
        if (cnf_uses_varargs in CallNodeFlags) and not X86_64_Use_MS_ABI(ProcDefinition.ProcCallOption) then
          begin
            if Assigned(VarArgsParas) then
              lMMRegCount:=VarArgsParas.MMRegsUsed
            else
              lMMRegCount:=0;
            CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(A_MOV,S_Q,lMMRegCount,NR_RAX))
          end;
      end;


    procedure TX8664CallNode.Set_Result_Location(ARealResultDef: TStoredDef);
      begin
        { avoid useless "movq %xmm0,%rax" and "movq %rax,%xmm0" instructions
          (which moreover for some reason are not supported by the Darwin
           x86-64 assembler) }
        if Assigned(FResultParaLoc.Location) and
           not Assigned(FResultParaLoc.Location^.next) and
           (FResultParaLoc.Location^.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
          begin
            Location_Reset(Location,LOC_MMREGISTER,FResultParaLoc.Location^.Size);
            Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,FResultParaLoc.Location^.Size);
          end
        else
          inherited
      end;

begin
   CCallNode:=TX8664CallNode;
end.
