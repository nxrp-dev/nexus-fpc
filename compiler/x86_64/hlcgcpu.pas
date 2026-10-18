{
    Copyright (c) 1998-2010 by Florian Klaempfl and Jonas Maebe
    Member of the Free Pascal development team

    This unit contains routines to create a pass-through high-level code
    generator. This is used by most regular code generators.

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

unit hlcgcpu;

{$i fpcdefs.inc}

interface

  uses
    AAsmData,
    symdef,
    hlcgx86;

  type
    THLCGCPU = class(THLCGX86)
     procedure G_Intf_Wrapper(list: TAsmList; procdef: TProcDef; const labelname: string; ioffset: LongInt);override;
    end;

implementation

  uses
    GlobType,Globals,Verbose,
    FModule,Systems,
    aasmbase,aasmtai,aasmcpu,
    symconst,
    hlcgobj,
    cgbase,cgutils,cgobj,cpubase,cgcpu,cpupi;

  procedure THLCGCPU.G_Intf_Wrapper(list: TAsmList; procdef: TProcDef; const labelname: string; ioffset: LongInt);
    var
      make_global : boolean;
      href : TReference;
      sym : TAsmSymbol;
      r : TReference;
    begin
      if not(procdef.ProcTypeOption in [potype_function,potype_procedure]) then
        InternalError(200006137);
      if not Assigned(procdef.struct) or
         (procdef.ProcOptions*[po_classmethod, po_staticmethod,
           po_methodpointer, po_interrupt, po_iocheck]<>[]) then
        InternalError(200006138);
      if procdef.owner.SymTableType<>ObjectSymtable then
        InternalError(200109191);

      make_global:=false;
      if (not CurrentModule.IsUnit) or create_smartlink or
         (procdef.owner.DefOwner.owner.SymTableType=GlobalSymTable) then
        make_global:=true;

      if make_global then
        List.concat(TAISymbol.Createname_global(labelname,AT_FUNCTION,0,procdef))
      else
        List.concat(TAISymbol.Createname_hidden(labelname,AT_FUNCTION,0,procdef));

      { set param1 interface to self  }
      G_Adjust_Self_Value(list,procdef,ioffset);

      if (po_virtualmethod in procdef.ProcOptions) and
          not Is_ObjectPascal_Helper(procdef.struct) then
        begin
          if (procdef.ExtNumber=$ffff) then
            InternalError(2000061301);
          { load vmt from first parameter }
          { win64 uses a different abi }
          if X86_64_Use_MS_ABI(procdef.ProcCallOption) then
            Reference_Reset_Base(href,VoidPointerType,NR_RCX,0,CTempPosInvalid,sizeof(PInt),[])
          else
            Reference_Reset_Base(href,VoidPointerType,NR_RDI,0,CTempPosInvalid,sizeof(PInt),[]);
          cg.A_Load_Ref_Reg(list,OS_ADDR,OS_ADDR,href,NR_RAX);
          { jmp *vmtoffs(%eax) ; method offs }
          Reference_Reset_Base(href,VoidPointerType,NR_RAX,TObjectDef(procdef.struct).VMTMethodOffset(procdef.ExtNumber),CTempPosInvalid,sizeof(PInt),[]);
          list.concat(TAICPU.op_ref(A_JMP,S_Q,href));
        end
      else
        begin
          sym:=CurrentAsmData.RefAsmSymbol(procdef.MangledName,AT_FUNCTION);
          Reference_Reset_Symbol(r,sym,0,sizeof(PInt),[]);
          if (cs_create_pic in CurrentSettings.ModuleSwitches) and
             { darwin/x86_64's assembler doesn't want @PLT after call symbols }
             not(TargetInfo.system in systems_darwin) then
            r.RefAddr:=addr_pic
          else
            r.RefAddr:=addr_full;

          list.concat(TAICPU.op_ref(A_JMP,S_NO,r));
        end;

      List.concat(TAISymbolEnd.Createname(labelname));
    end;


  procedure create_hlcodegen_cpu(hlcgobjhelpers: THLCGObjHelpersClass);
    begin
      hlcg:=THLCGCPU.Create(hlcgobjhelpers);
      create_codegen;
    end;

begin
  CHLCGObj:=THLCGCPU;
  Create_HLCodeGen:=@create_hlcodegen_cpu;
end.
