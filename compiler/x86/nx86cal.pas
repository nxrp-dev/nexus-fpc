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
         procedure do_release_unused_return_value;override;
         procedure set_result_location(realresdef: TStoredDef);override;
         function can_call_ref(var ref: TReference):boolean;override;
         function do_call_ref(ref: TReference): TCGPara;override;
       end;


implementation

    uses
      GlobType,cgobj,
      cgbase,cpubase,cgx86,cga,AAsmData,aasmcpu,
      hlcgobj;


{*****************************************************************************
                             TX86CALLNODE
*****************************************************************************}

    procedure TX86CallNode.do_release_unused_return_value;
      begin
        case location.loc of
          LOC_FPUREGISTER :
             begin
               { release FPU stack }
               emit_reg(A_FSTP,S_NO,NR_FPU_RESULT_REG);
               TCGX86(cg).dec_fpu_stack;
             end
          else
            inherited do_release_unused_return_value;
        end;
      end;


  procedure TX86CallNode.set_result_location(realresdef: TStoredDef);
    begin
      if (retloc.location^.loc=LOC_FPUREGISTER) then
        begin
          TCGX86(cg).inc_fpu_stack;
          location_reset(location,LOC_FPUREGISTER,retloc.location^.size);
          location.register:=retloc.location^.register;
        end
      else
        inherited set_result_location(realresdef);
    end;


  function TX86CallNode.can_call_ref(var ref: TReference): boolean;
    const
{$if defined(i386)}
      save_all_regs=[pocall_far16,pocall_oldfpccall];
{$else}
      save_all_regs=[];
{$endif}
    begin
      TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,ref);
      { do not use a ref. for calling conventions which allocate all registers, the reg. allocator cannot handle this, see
        also issue #28639, I were not able to create a simple example though to cause the resulting endless spilling }
      result:=((getsupreg(ref.base)<first_int_imreg) and (getsupreg(ref.index)<first_int_imreg)) or
              not(procdefinition.ProcCallOption in save_all_regs);
    end;


  function TX86CallNode.do_call_ref(ref: TReference): TCGPara;
    begin
      CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref(A_CALL,S_NO,ref));
      result:=hlcg.get_call_result_cgpara(procdefinition,typedef)
    end;

end.
