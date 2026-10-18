{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate i386 assembler for in call nodes

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
unit n386cal;

{$i fpcdefs.inc}

interface

{ $define AnsiStrRef}

    uses
      nx86cal,ncal;

    type
       TI386CallNode = class(TX86CallNode)
       protected
          procedure Pop_ParaSize(APopSize:LongInt);override;
          procedure Extra_Interrupt_Code;override;
       end;


implementation

    uses
      GlobType,Systems,
      CUtils,Verbose,Globals,
      cgbase,cgutils,
      cpubase,paramgr,
      aasmtai,AAsmData,aasmcpu,
      nbas,nmem,nld,ncnv,
      parabase,
      symdef,SymSym,symcpu,symconst,
      cga,cgobj,cgx86,
      CPUInfo;


{*****************************************************************************
                             TI386CALLNODE
*****************************************************************************}


    procedure TI386CallNode.Extra_Interrupt_Code;
      begin
        emit_none(A_PUSHF,S_L);
        emit_reg(A_PUSH,S_L,NR_CS);
      end;


    procedure TI386CallNode.Pop_ParaSize(APopSize:LongInt);
      var
        lReg : TRegister;
        lReference : TReference;
      begin
        if ParaManager.Use_Fixed_Stack then
          begin
            { very weird: in this case the callee does a "ret $4" and the }
            { caller immediately a "subl $4,%esp". Possibly this is for   }
            { use_fixed_stack code to be able to transparently call       }
            { old-style code (JM)                                         }
            dec(APopSize,FPushedParaSize);
            if APopSize<0 then
              begin
                Reference_Reset_Base(lReference,NR_STACK_POINTER_REG,APopSize,CTempPosInvalid,0,[]);
                { it is better to use lea here }
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(A_LEA,TCGSize2OpSize[OS_ADDR],lReference,NR_ESP));
              end;
            exit;
          end;

        { on win32, the caller is responsible for removing the funcret     }
        { pointer from the stack, unlike on Linux. Don't know about        }
        { elsewhere (except Darwin, handled above), but since the default  }
        { was "callee removes funcret pointer from stack" until now, we'll }
        { keep that default for everyone else (ncgcal decreases popsize by }
        { sizeof(aint) in case of ret_in_param())                          }
        { This is only correct if the hidden funcret parameter
          is not passed as a register.
          As it is inserted in parast after all other hidden parameters,
          it is always the first parameter (apart from hidden parentfp,
          but this one is never put into a register (vs_nonregable set)
          so funcret is always in EAX for register calling }
        if ((TargetInfo.system = system_i386_win32) and
            not (TargetInfo.abi=abi_old_win32_gnu)) and
            ParaManager.Ret_In_Param(ProcDefinition.ReturnDef,ProcDefinition) and
            not ((ProcDefinition.ProcCallOption=pocall_register) or
                 ((ProcDefinition.ProcCallOption=pocall_internproc) and
                  (pocall_default=pocall_register))) then
          inc(APopSize,sizeof(AInt));

        { better than an add on all processors }
        if APopSize=4 then
          begin
            lReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg(A_POP,S_L,lReg));
          end
        { the pentium has two pipes and pop reg is pairable }
        { but the registers must be different!        }
        else
          if (APopSize=8) and
             not(cs_opt_size in CurrentSettings.OptimizerSwitches) and
             (CurrentSettings.OptimizeCPUType=cpu_Pentium) then
            begin
               lReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
               CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg(A_POP,S_L,lReg));
               lReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
               CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg(A_POP,S_L,lReg));
            end
        else
          if APopSize<>0 then
            CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(A_ADD,S_L,APopSize,NR_ESP));
      end;


begin
  CCallNode:=TI386CallNode;
end.
