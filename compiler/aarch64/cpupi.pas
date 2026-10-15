{
    Copyright (c) 2002 by Florian Klaempfl

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
unit cpupi;

{$i fpcdefs.inc}

interface

  uses
    ProcInfo,
    psub,
    AAsmData,aasmbase;

  type
    TCPUProcInfo=class(TCGProcInfo)
    private
      scopes: TAsmList;
      scopecount: LongInt;
      unwindflags: byte;
    public
      { Total stack frame size including saved registers (for SEH on AArch64-Win64).
        This is the offset from FP to SP after the prolog completes. }
      total_stackframe_size: LongInt;
      constructor create(aparent: TProcInfo); override;
      destructor Destroy; override;
      procedure set_first_temp_offset; override;
      procedure add_finally_scope(startlabel,endlabel,handler:TAsmSymbol;implicit:Boolean);
      procedure add_except_scope(trylabel,exceptlabel,endlabel,filter:TAsmSymbol);
      procedure dump_scopes(list:TAsmList);
    end;

implementation

  uses
    CUtils,
    FModule,
    SymTable,
    tgobj,
    cpubase,
    aasmtai;

  const
    SCOPE_FINALLY=0;
    SCOPE_CATCHALL=1;
    SCOPE_IMPLICIT=2;

  constructor TCPUProcInfo.create(aparent: TProcInfo);
    begin
      inherited;
      { use the stack pointer as framepointer, because
         1) we exactly know the offsets of the temps from the stack pointer
            after pass 1 (based on the require parameter stack size for called
            routines), while we don't know it for the frame pointer (it depends
            on the number of saved registers)
         2) temp offsets from the stack pointer are positive while those from
            the frame pointer are negative, and we can directly encode much
            bigger positive offsets in the instructions
      }
      framepointer:=NR_STACK_POINTER_REG;
    end;

  destructor TCPUProcInfo.Destroy;
    begin
      scopes.free;
      inherited Destroy;
    end;

  procedure TCPUProcInfo.set_first_temp_offset;
    begin
     { leave room for allocated parameters }
     tg.setfirsttemp(align(maxpushedparasize,16));
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
    begin
      if (scopecount=0) then
        exit;
      hdir:=CAISEHDirective.create_name(ash_handler,'__FPC_specific_handler');
      if not SystemUnit.IsCurrentUnit then
        CurrentModule.Add_Extern_AsmSym('__FPC_specific_handler',AB_EXTERNAL,AT_FUNCTION);
      hdir.data.flags:=unwindflags;
      list.concat(hdir);
      list.concat(CAISEHDirective.create(ash_handlerdata));
      inc(list.section_count);
      list.concat(TAIConst.create_32bit(scopecount));
      list.ConcatList(scopes);
      { return to text, required for GAS compatibility }
      { This creates a tai_align which is redundant here (although harmless) }
      new_section(list,sec_code,lower(procdef.MangledName),0);
    end;


begin
  CProcInfo:=TCPUProcInfo;
end.
