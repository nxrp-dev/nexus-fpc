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
         scopes: TAsmList;
         scopecount: LongInt;
         unwindflags: byte;
       public
         procedure set_first_temp_offset;override;
         procedure generate_parameter_info;override;
         function calc_stackframe_size:LongInt;override;
         procedure add_finally_scope(startlabel,endlabel,handler:TAsmSymbol;implicit:Boolean);
         procedure add_except_scope(trylabel,exceptlabel,endlabel,filter:TAsmSymbol);
         procedure dump_scopes(list:TAsmList);
         destructor Destroy;override;
       end;

    function x86_64_use_ms_abi(proccall: TProcCallOption): boolean;

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
      SCOPE_FINALLY=0;
      SCOPE_CATCHALL=1;
      SCOPE_IMPLICIT=2;

    procedure TCPUProcInfo.set_first_temp_offset;
      begin
        if TargetInfo.system=system_x86_64_win64 then
          begin
            { Compiler-injected profiler hooks are physical calls and need the
              normal Win64 shadow space and unwind description. }
            if nexus_profile_proc_eligible(self) then
              include(flags,pi_do_call);
            { Fixes the case when there are calls done by low-level means
              (cg.a_call_name) but no child callnode }
            if (pi_do_call in flags) and
              not (po_nostackframe in procdef.ProcOptions) then
              allocate_push_parasize(32);

            if not(po_assembler in procdef.ProcOptions) and
              (tg.direction > 0) then
            { maxpushedparasize already contains 32 bytes of spilling area }
              tg.setfirsttemp(tg.direction*maxpushedparasize);
          end
        else
          tg.setfirsttemp(tg.direction*maxpushedparasize);
      end;


    procedure TCPUProcInfo.generate_parameter_info;
      begin
        inherited generate_parameter_info;
        if TargetInfo.system=system_x86_64_win64 then
          para_stack_size:=0;
      end;


    function TCPUProcInfo.calc_stackframe_size:LongInt;
      begin
        maxpushedparasize:=align(maxpushedparasize,max(CurrentSettings.Alignment.LocalAlignMin,16));
        { Note 1: when tg.direction>0, tg.lasttemp is already offset by maxpushedparasize
                  (because tg.setfirsttemp also sets lasttemp)
          Note 2: Align to 8 bytes here. The final 16-byte alignment is handled in
                  tcgx86.g_proc_entry, which considers saved rbp and the misalignment
                  caused by the call itself. }
        if (tg.direction>0) then
          result:=Align(tg.lasttemp,8)
        else
          result:=Align(tg.direction*tg.lasttemp+maxpushedparasize,8);
      end;

    procedure TCPUProcInfo.add_finally_scope(startlabel,endlabel,handler:TAsmSymbol;implicit:Boolean);
      begin
        unwindflags:=unwindflags or 2;
        if implicit then  { also needs catch functionality }
          unwindflags:=unwindflags or 1;
        inc(scopecount);
        if scopes=nil then
          scopes:=TAsmList.Create;

        if implicit then
          scopes.concat(TAIConst.create_32bit(SCOPE_IMPLICIT))
        else
          scopes.concat(TAIConst.create_32bit(SCOPE_FINALLY));
        scopes.concat(TAIConst.create_rva_sym(startlabel));
        scopes.concat(TAIConst.create_rva_sym(endlabel));
        scopes.concat(TAIConst.create_rva_sym(handler));
      end;

    procedure TCPUProcInfo.add_except_scope(trylabel,exceptlabel,endlabel,filter:TAsmSymbol);
      begin
        unwindflags:=unwindflags or 3;
        inc(scopecount);
        if scopes=nil then
          scopes:=TAsmList.Create;

        if Assigned(filter) then
          scopes.concat(TAIConst.create_rva_sym(filter))
        else
          scopes.concat(TAIConst.create_32bit(SCOPE_CATCHALL));
        scopes.concat(TAIConst.create_rva_sym(trylabel));
        scopes.concat(TAIConst.create_rva_sym(exceptlabel));
        scopes.concat(TAIConst.create_rva_sym(endlabel));
      end;

    procedure TCPUProcInfo.dump_scopes(list: TAsmList);
      var
        hdir: TAISEHDirective;
        profiled: boolean;
      begin
        profiled:=nexus_profile_proc_eligible(self);
        if (scopecount=0) and not profiled then
          exit;
        if profiled then
          begin
            hdir:=CAISEHDirective.create_name(ash_handler,'__NXP_specific_handler');
            CurrentModule.Add_Extern_AsmSym('__NXP_specific_handler',AB_EXTERNAL,AT_FUNCTION);
            CurrentModule.Add_Extern_AsmSym('nxp_unwind',AB_EXTERNAL,AT_FUNCTION);
            hdir.data.flags:=unwindflags or 2;
          end
        else
          begin
            hdir:=CAISEHDirective.create_name(ash_handler,'__FPC_specific_handler');
            if not SystemUnit.IsCurrentUnit then
              CurrentModule.Add_Extern_AsmSym('__FPC_specific_handler',AB_EXTERNAL,AT_FUNCTION);
            hdir.data.flags:=unwindflags;
          end;
        list.concat(hdir);
        list.concat(CAISEHDirective.create(ash_handlerdata));
        inc(list.section_count);
        list.concat(TAIConst.create_32bit(scopecount));
        if Assigned(scopes) then
          list.ConcatList(scopes);
        if profiled then
          begin
            { Versioned trailer following the untouched FPC scope table. }
            list.concat(TAIConst.create_32bit($4850584E)); { NXPH }
            list.concat(TAIConst.create_32bit(1));
            list.concat(TAIConst.create_sym(nexus_profile_descsym));
            list.concat(TAIConst.create_sym(
              CurrentAsmData.RefAsmSymbol('nxp_unwind',AT_FUNCTION)));
          end;
        { return to text, required for GAS compatibility }
        { This creates a tai_align which is redundant here (although harmless) }
        new_section(list,sec_code,lower(procdef.MangledName),0);
      end;

    destructor TCPUProcInfo.Destroy;
      begin
        scopes.free;
        inherited Destroy;
      end;


    function x86_64_use_ms_abi(proccall: TProcCallOption): boolean;
      begin
        result:=
          ((TargetInfo.system=system_x86_64_win64) and
            not(proccall in [pocall_sysv_abi_default,pocall_sysv_abi_cdecl])) or
          (proccall in [pocall_ms_abi_default,pocall_ms_abi_cdecl]);
      end;


begin
   CProcInfo:=TCPUProcInfo;
end.
