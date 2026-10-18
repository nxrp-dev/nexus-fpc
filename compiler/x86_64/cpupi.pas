{
    Copyright (c) 2002-2006 by Florian Klaempfl

    This unit contains the CPU specific part of tprocinfo

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

{ This unit contains the CPU specific part of tprocinfo. }
unit cpupi;

{$i fpcdefs.inc}

interface

    uses
       GlobType,
       psub,
       ProcInfo,psabiehpi,
       aasmbase,AAsmData;

    type
       TCPUProcInfo = class(TPSABIEHProcInfo)
       private
         FScopes: TAsmList;
         FScopeCount: LongInt;
         FUnwindFlags: byte;
       public
         procedure Set_First_Temp_Offset;override;
         procedure Generate_Parameter_Info;override;
         function Calc_StackFrame_Size:LongInt;override;
         procedure Add_Finally_Scope(AStartLabel,AEndLabel,AHandler:TAsmSymbol;AImplicit:Boolean);
         procedure Add_Except_Scope(ATryLabel,AExceptLabel,AEndLabel,AFilter:TAsmSymbol);
         procedure Dump_Scopes(AList:TAsmList);
         destructor Destroy;override;
       end;

    function X86_64_Use_MS_ABI(AProcCall: TProcCallOption): boolean;

implementation

    uses
      Systems,
      Globals,
      CUtils,
      symconst,
      SymTable,
      aasmtai,
      tgobj,
      FModule;

    const
      cScopeFinally=0;
      cScopeCatchAll=1;
      cScopeImplicit=2;

    procedure TCPUProcInfo.Set_First_Temp_Offset;
      begin
        if TargetInfo.system=system_x86_64_win64 then
          begin
            { Compiler-injected profiler hooks are physical calls and need the
              normal Win64 shadow space and unwind description. }
            if Nexus_Profile_Proc_Eligible(self) then
              include(Flags,pi_do_call);
            { Fixes the case when there are calls done by low-level means
              (cg.a_call_name) but no child callnode }
            if (pi_do_call in Flags) and
              not (po_nostackframe in ProcDef.ProcOptions) then
              Allocate_Push_ParaSize(32);

            if not(po_assembler in ProcDef.ProcOptions) and
              (TG.Direction > 0) then
            { maxpushedparasize already contains 32 bytes of spilling area }
              TG.SetFirstTemp(TG.Direction*MaxPushedParaSize);
          end
        else
          TG.SetFirstTemp(TG.Direction*MaxPushedParaSize);
      end;


    procedure TCPUProcInfo.Generate_Parameter_Info;
      begin
        inherited Generate_Parameter_Info;
        if TargetInfo.system=system_x86_64_win64 then
          ParaStackSize:=0;
      end;


    function TCPUProcInfo.Calc_StackFrame_Size:LongInt;
      begin
        MaxPushedParaSize:=align(MaxPushedParaSize,max(CurrentSettings.Alignment.LocalAlignMin,16));
        { Note 1: when tg.direction>0, tg.lasttemp is already offset by maxpushedparasize
                  (because tg.setfirsttemp also sets lasttemp)
          Note 2: Align to 8 bytes here. The final 16-byte alignment is handled in
                  tcgx86.g_proc_entry, which considers saved rbp and the misalignment
                  caused by the call itself. }
        if (TG.Direction>0) then
          Result:=Align(TG.LastTemp,8)
        else
          Result:=Align(TG.Direction*TG.LastTemp+MaxPushedParaSize,8);
      end;

    procedure TCPUProcInfo.Add_Finally_Scope(AStartLabel,AEndLabel,AHandler:TAsmSymbol;AImplicit:Boolean);
      begin
        FUnwindFlags:=FUnwindFlags or 2;
        if AImplicit then  { also needs catch functionality }
          FUnwindFlags:=FUnwindFlags or 1;
        inc(FScopeCount);
        if FScopes=nil then
          FScopes:=TAsmList.Create;

        if AImplicit then
          FScopes.concat(TAIConst.create_32bit(cScopeImplicit))
        else
          FScopes.concat(TAIConst.create_32bit(cScopeFinally));
        FScopes.concat(TAIConst.create_rva_sym(AStartLabel));
        FScopes.concat(TAIConst.create_rva_sym(AEndLabel));
        FScopes.concat(TAIConst.create_rva_sym(AHandler));
      end;

    procedure TCPUProcInfo.Add_Except_Scope(ATryLabel,AExceptLabel,AEndLabel,AFilter:TAsmSymbol);
      begin
        FUnwindFlags:=FUnwindFlags or 3;
        inc(FScopeCount);
        if FScopes=nil then
          FScopes:=TAsmList.Create;

        if Assigned(AFilter) then
          FScopes.concat(TAIConst.create_rva_sym(AFilter))
        else
          FScopes.concat(TAIConst.create_32bit(cScopeCatchAll));
        FScopes.concat(TAIConst.create_rva_sym(ATryLabel));
        FScopes.concat(TAIConst.create_rva_sym(AExceptLabel));
        FScopes.concat(TAIConst.create_rva_sym(AEndLabel));
      end;

    procedure TCPUProcInfo.Dump_Scopes(AList: TAsmList);
      var
        lHandlerDirective: TAISEHDirective;
        lProfiled: boolean;
      begin
        lProfiled:=Nexus_Profile_Proc_Eligible(self);
        if (FScopeCount=0) and not lProfiled then
          exit;
        if lProfiled then
          begin
            lHandlerDirective:=CAISEHDirective.create_name(ash_handler,'__NXP_specific_handler');
            CurrentModule.Add_Extern_AsmSym('__NXP_specific_handler',AB_EXTERNAL,AT_FUNCTION);
            CurrentModule.Add_Extern_AsmSym('nxp_unwind',AB_EXTERNAL,AT_FUNCTION);
            lHandlerDirective.data.Flags:=FUnwindFlags or 2;
          end
        else
          begin
            lHandlerDirective:=CAISEHDirective.create_name(ash_handler,'__FPC_specific_handler');
            if not SystemUnit.IsCurrentUnit then
              CurrentModule.Add_Extern_AsmSym('__FPC_specific_handler',AB_EXTERNAL,AT_FUNCTION);
            lHandlerDirective.data.Flags:=FUnwindFlags;
          end;
        AList.concat(lHandlerDirective);
        AList.concat(CAISEHDirective.Create(ash_handlerdata));
        inc(AList.section_count);
        AList.concat(TAIConst.create_32bit(FScopeCount));
        if Assigned(FScopes) then
          AList.ConcatList(FScopes);
        if lProfiled then
          begin
            { Versioned trailer following the untouched FPC scope table. }
            AList.concat(TAIConst.create_32bit($4850584E)); { NXPH }
            AList.concat(TAIConst.create_32bit(1));
            AList.concat(TAIConst.create_sym(NexusProfileDescSym));
            AList.concat(TAIConst.create_sym(
              CurrentAsmData.RefAsmSymbol('nxp_unwind',AT_FUNCTION)));
          end;
        { return to text, required for GAS compatibility }
        { This creates a tai_align which is redundant here (although harmless) }
        new_section(AList,sec_code,lower(ProcDef.MangledName),0);
      end;

    destructor TCPUProcInfo.Destroy;
      begin
        FScopes.free;
        inherited Destroy;
      end;


    function X86_64_Use_MS_ABI(AProcCall: TProcCallOption): boolean;
      begin
        Result:=
          ((TargetInfo.system=system_x86_64_win64) and
            not(AProcCall in [pocall_sysv_abi_default,pocall_sysv_abi_cdecl])) or
          (AProcCall in [pocall_ms_abi_default,pocall_ms_abi_cdecl]);
      end;


begin
   CProcInfo:=TCPUProcInfo;
end.
