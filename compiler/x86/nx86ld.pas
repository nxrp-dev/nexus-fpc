{
    Copyright (c) 1998-2002,2015 by Florian Klaempfl

    Generate x86 assembler for in load nodes

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
unit nx86ld;

{$i fpcdefs.inc}

interface
    uses
      GlobType,
      symtype,SymSym,
      node,nld,ncgld;

    type
      TX86LoadNode = class(TCGLoadNode)
       protected
         procedure generate_threadvar_access(gvs: TStaticVarSym); override;
      end;

implementation

    uses
      Globals,
      CUtils,Verbose,Systems,
      aasmbase,aasmtai,AAsmData,aasmcpu,
      cgutils,cgobj,
      symconst,symdef,SymTable,
      cgbase,cpubase,parabase,paramgr,
      ProcInfo;

{*****************************************************************************
                           TX86LOADNODE
*****************************************************************************}

    procedure TX86LoadNode.generate_threadvar_access(gvs: TStaticVarSym);
      var
        paraloc1 : TCGPara;
        pd: TProcDef;
        href: TReference;
        hregister : TRegister;
        handled: boolean;
      begin
        handled:=false;
        if (tf_section_threadvars in TargetInfo.flags) then
          begin
            if TargetInfo.system in [system_i386_win32,system_x86_64_win64] then
              begin
                paraloc1.init;
                pd:=Search_System_Proc('fpc_tls_add');
                paramanager.getcgtempparaloc(CurrentAsmData.CurrAsmList,pd,1,paraloc1);
                if not(vo_is_weak_external in gvs.VarOptions) then
                  reference_reset_symbol(href,CurrentAsmData.RefAsmSymbol(gvs.MangledName,AT_DATA,use_indirect_symbol(gvs)),0,sizeof(PInt),[])
                else
                  reference_reset_symbol(href,CurrentAsmData.WeakRefAsmSymbol(gvs.MangledName,AT_DATA),0,sizeof(PInt),[]);
                cg.a_loadaddr_ref_cgpara(CurrentAsmData.CurrAsmList,href,paraloc1);
                paramanager.freecgpara(CurrentAsmData.CurrAsmList,paraloc1);
                paraloc1.done;

                cg.g_call(CurrentAsmData.CurrAsmList,'FPC_TLS_ADD');
                cg.ungetcpuregister(CurrentAsmData.CurrAsmList,NR_FUNCTION_RESULT_REG);
                hregister:=cg.getaddressregister(CurrentAsmData.CurrAsmList);
                cg.a_load_reg_reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,NR_FUNCTION_RESULT_REG,hregister);
                location.reference.base:=hregister;
                handled:=true;
              end;
          end;

        if not handled then
          inherited;

        if (tf_section_threadvars in TargetInfo.flags) then
          begin
{$ifdef i386}
            case TargetInfo.system of
              system_i386_linux,system_i386_android:
                begin
                  case CurrentSettings.TLSModel of
                    tlsm_local_exec:
                      begin
                        location.reference.segment:=NR_GS;
                        location.reference.refaddr:=addr_ntpoff;
                      end;
                    tlsm_global_dynamic:
                      begin
                        include(CurrentProcInfo.flags,pi_needs_got);
                        reference_reset(href,0,[]);
                        location.reference.index:=CurrentProcInfo.got;
                        location.reference.scalefactor:=1;
                        location.reference.refaddr:=addr_tlsgd;
                        cg.getcpuregister(CurrentAsmData.CurrAsmList,NR_EAX);
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(A_LEA,S_L,location.reference,NR_EAX));
                        cg.g_call(CurrentAsmData.CurrAsmList,'___tls_get_addr');
                        cg.ungetcpuregister(CurrentAsmData.CurrAsmList,NR_EAX);
                        hregister:=cg.getaddressregister(CurrentAsmData.CurrAsmList);
                        cg.a_load_reg_reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,NR_EAX,hregister);
                        reference_reset(location.reference,location.reference.alignment,location.reference.volatility);
                        location.reference.base:=hregister;
                      end;
                    else
                      InternalError(2018110401);
                  end;
                end;
              else
                ;
            end;
{$endif i386}
{$ifdef x86_64}
            case TargetInfo.system of
              system_x86_64_linux:
                begin
                  case CurrentSettings.TLSModel of
                    tlsm_local_exec:
                      begin
                        location.reference.segment:=NR_FS;
                        location.reference.refaddr:=addr_tpoff;
                      end;
                    tlsm_global_dynamic:
                      begin
                        CurrentAsmData.CurrAsmList.concat(TAIConst.Create_8bit($66));
                        reference_reset(href,0,[]);
                        location.reference.base:=NR_RIP;
                        location.reference.scalefactor:=1;
                        location.reference.refaddr:=addr_tlsgd;
                        cg.getcpuregister(CurrentAsmData.CurrAsmList,NR_RDI);
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_ref_reg(A_LEA,S_Q,location.reference,NR_RDI));
                        CurrentAsmData.CurrAsmList.concat(TAIConst.Create_8bit($66));
                        CurrentAsmData.CurrAsmList.concat(TAIConst.Create_8bit($66));
                        CurrentAsmData.CurrAsmList.concat(TAIConst.Create_8bit($48));
                        cg.g_call(CurrentAsmData.CurrAsmList,'__tls_get_addr');
                        cg.ungetcpuregister(CurrentAsmData.CurrAsmList,NR_RDI);
                        cg.ungetcpuregister(CurrentAsmData.CurrAsmList,NR_EAX);
                        hregister:=cg.getaddressregister(CurrentAsmData.CurrAsmList);
                        cg.a_load_reg_reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,NR_RAX,hregister);
                        reference_reset(location.reference,location.reference.alignment,location.reference.volatility);
                        location.reference.base:=hregister;
                      end;
                    else
                      InternalError(2019012002);
                  end;
                end;
              else
                ;
            end;
{$endif x86_64}
          end;
      end;


begin
   CLoadNode:=TX86LoadNode;
end.
