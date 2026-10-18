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
      FScopes: TAsmList;
      FScopeCount: LongInt;
      FUnwindFlags: byte;
    public
      { Total stack frame size including saved registers (for SEH on AArch64-Win64).
        This is the offset from FP to SP after the prolog completes. }
      TotalStackFrameSize: LongInt;
      constructor Create(AParent: TProcInfo); override;
      destructor Destroy; override;
      procedure Set_First_Temp_Offset; override;
      procedure Add_Finally_Scope(AStartLabel,AEndLabel,AHandler:TAsmSymbol;AImplicit:Boolean);
      procedure Add_Except_Scope(ATryLabel,AExceptLabel,AEndLabel,AFilter:TAsmSymbol);
      procedure Dump_Scopes(AList:TAsmList);
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
    cScopeFinally=0;
    cScopeCatchAll=1;
    cScopeImplicit=2;

  constructor TCPUProcInfo.Create(AParent: TProcInfo);
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
      FramePointer:=NR_STACK_POINTER_REG;
    end;

  destructor TCPUProcInfo.Destroy;
    begin
      FScopes.free;
      inherited Destroy;
    end;

  procedure TCPUProcInfo.Set_First_Temp_Offset;
    begin
     { leave room for allocated parameters }
     TG.SetFirstTemp(align(MaxPushedParaSize,16));
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
    begin
      if (FScopeCount=0) then
        exit;
      lHandlerDirective:=CAISEHDirective.create_name(ash_handler,'__FPC_specific_handler');
      if not SystemUnit.IsCurrentUnit then
        CurrentModule.Add_Extern_AsmSym('__FPC_specific_handler',AB_EXTERNAL,AT_FUNCTION);
      lHandlerDirective.data.Flags:=FUnwindFlags;
      AList.concat(lHandlerDirective);
      AList.concat(CAISEHDirective.Create(ash_handlerdata));
      inc(AList.section_count);
      AList.concat(TAIConst.create_32bit(FScopeCount));
      AList.ConcatList(FScopes);
      { return to text, required for GAS compatibility }
      { This creates a tai_align which is redundant here (although harmless) }
      new_section(AList,sec_code,lower(ProcDef.MangledName),0);
    end;


begin
  CProcInfo:=TCPUProcInfo;
end.
