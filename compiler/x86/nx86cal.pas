{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Common x86 support for call nodes

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
unit nx86cal;

{$i fpcdefs.inc}

interface

{ $define AnsiStrRef}

    uses
      symdef,
      cgutils,
      ncgcal,parabase;

    type

       { tx86callnode }

       TX86CallNode = class(TCGCallNode)
        protected
         procedure Do_Release_Unused_Return_Value;override;
         procedure Set_Result_Location(ARealResultDef: TStoredDef);override;
         function Can_Call_Ref(var AReference: TReference):Boolean;override;
         function Do_Call_Ref(AReference: TReference): TCGPara;override;
       end;


implementation

    uses
      GlobType,cgobj,
      cgbase,cpubase,cgx86,cga,AAsmData,aasmcpu,
      hlcgobj;


{*****************************************************************************
                             TX86CALLNODE
*****************************************************************************}

    procedure TX86CallNode.Do_Release_Unused_Return_Value;
      begin
        case Location.Loc of
          LOC_FPUREGISTER :
             begin
               { release FPU stack }
               emit_reg(A_FSTP,S_NO,NR_FPU_RESULT_REG);
               TCGX86(cg).dec_fpu_stack;
             end
          else
            inherited Do_Release_Unused_Return_Value;
        end;
      end;


  procedure TX86CallNode.Set_Result_Location(ARealResultDef: TStoredDef);
    begin
      if (FResultParaLoc.Location^.Loc=LOC_FPUREGISTER) then
        begin
          TCGX86(cg).inc_fpu_stack;
          Location_Reset(Location,LOC_FPUREGISTER,FResultParaLoc.Location^.Size);
          Location.Register:=FResultParaLoc.Location^.Register;
        end
      else
        inherited Set_Result_Location(ARealResultDef);
    end;


  function TX86CallNode.Can_Call_Ref(var AReference: TReference): Boolean;
    const
{$if defined(i386)}
      cSaveAllRegs=[pocall_far16,pocall_oldfpccall];
{$else}
      cSaveAllRegs=[];
{$endif}
    begin
      TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,AReference);
      { do not use a ref. for calling conventions which allocate all registers, the reg. allocator cannot handle this, see
        also issue #28639, I were not able to create a simple example though to cause the resulting endless spilling }
      Result:=((GetSupReg(AReference.Base)<first_int_imreg) and (GetSupReg(AReference.Index)<first_int_imreg)) or
              not(ProcDefinition.ProcCallOption in cSaveAllRegs);
    end;


  function TX86CallNode.Do_Call_Ref(AReference: TReference): TCGPara;
    begin
      CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref(A_CALL,S_NO,AReference));
      Result:=hlcg.Get_Call_Result_CGPara(ProcDefinition,TypeDef)
    end;

end.
