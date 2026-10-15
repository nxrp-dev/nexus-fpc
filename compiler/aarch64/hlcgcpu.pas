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
    symtype,
    AAsmData,
    symdef,
    cgbase,cgutils,
    hlcgobj, hlcg2ll;

  type
    THLCGAArch64 = class(THLCG2LL)
      procedure a_load_subsetreg_reg(list: TAsmList; subsetsize, tosize: TDef; const sreg: TSubsetRegister; destreg: TRegister); override;
      procedure a_load_subsetreg_subsetreg(list: TAsmList; fromsubsetsize, tosubsetsize: TDef; const fromsreg, tosreg: TSubsetRegister); override;

      procedure g_intf_wrapper(list: TAsmList; procdef: TProcDef; const labelname: string; ioffset: LongInt);override;
     protected
      procedure a_load_regconst_subsetreg_intern(list: TAsmList; fromsize, subsetsize: TDef; fromreg: TRegister; const sreg: TSubsetRegister; slopt: TSubsetLoadOpt); override;
    end;

implementation

  uses
    Verbose,GlobType,FModule,
    aasmbase,aasmtai,
    symconst,SymSym,defutil,
    cpubase,aasmcpu,parabase,
    cgobj,cgcpu;

  procedure THLCGAArch64.a_load_subsetreg_reg(list: TAsmList; subsetsize, tosize: TDef; const sreg: TSubsetRegister; destreg: TRegister);
    var
      op: TAsmOp;
      tocgsize: TCgSize;
      tmpdestreg: TRegister;
    begin
      tocgsize:=def_cgsize(tosize);
      if (sreg.startbit<>0) or
         not((sreg.subsetregsize in [OS_32,OS_S32]) and
             (sreg.bitlen=32)) or
         not((sreg.subsetregsize in [OS_64,OS_S64]) and
             (sreg.bitlen=64)) then
        begin
          if is_signed(subsetsize) then
            op:=A_SBFX
          else
            op:=A_UBFX;
          { source and destination register of SBFX/UBFX have to be the same size }
          if (sreg.subsetregsize in [OS_64,OS_S64]) and
             not(tocgsize in [OS_64,OS_S64]) then
            tmpdestreg:=cg.getintregister(list,OS_64)
          else if not(sreg.subsetregsize in [OS_64,OS_S64]) and
             (tocgsize in [OS_64,OS_S64]) then
            tmpdestreg:=cg.getintregister(list,OS_32)
          else
            tmpdestreg:=destreg;
          list.concat(TAICPU.op_reg_reg_const_const(op,tmpdestreg,sreg.subsetreg,sreg.startbit,sreg.bitlen));
          { need to sign extend further or truncate? }
          if (sreg.subsetregsize=OS_S64) and
             not(tocgsize in [OS_64,OS_S64]) then
            cg.a_load_reg_reg(list,OS_S64,tocgsize,tmpdestreg,destreg)
          else if is_signed(subsetsize) and
             (tocgsize in [OS_8,OS_16]) then
            cg.a_load_reg_reg(list,OS_32,tocgsize,tmpdestreg,destreg)
          else if tmpdestreg<>destreg then
            cg.a_load_reg_reg(list,def_cgsize(subsetsize),tocgsize,tmpdestreg,destreg)
        end
      else
        cg.a_load_reg_reg(list,def_cgsize(subsetsize),tocgsize,sreg.subsetreg,destreg);
    end;


  procedure makeregssamesize(list: TAsmList; fromsize, tosize: TCgSize; orgfromreg, orgtoreg: TRegister; out newfromreg, newtoreg: TRegister);
    begin
      if (fromsize in [OS_S64,OS_64])<>
         (tosize in [OS_S64,OS_64]) then
        begin
          newfromreg:=cg.makeregsize(list,orgfromreg,OS_64);
          newtoreg:=cg.makeregsize(list,orgtoreg,OS_64);
        end
      else
        begin
          newfromreg:=orgfromreg;
          newtoreg:=orgtoreg;
        end;
    end;


  procedure THLCGAArch64.a_load_subsetreg_subsetreg(list: TAsmList; fromsubsetsize, tosubsetsize: TDef; const fromsreg, tosreg: TSubsetRegister);
    var
      fromreg, toreg: TRegister;

    begin
      { BFM can only insert a bitfield that starts at position 0 in the source
        source or destination register }
      if (tosreg.startbit=0) and
         (fromsreg.bitlen>=tosreg.bitlen) then
        begin
          makeregssamesize(list,fromsreg.subsetregsize,tosreg.subsetregsize,fromsreg.subsetreg,tosreg.subsetreg,fromreg,toreg);
          list.concat(TAICPU.op_reg_reg_const_const(A_BFXIL,toreg,fromreg,fromsreg.startbit,tosreg.bitlen))
        end
      else if (fromsreg.startbit=0) and
         (fromsreg.bitlen>=tosreg.bitlen) then
        begin
          makeregssamesize(list,fromsreg.subsetregsize,tosreg.subsetregsize,fromsreg.subsetreg,tosreg.subsetreg,fromreg,toreg);
          list.concat(TAICPU.op_reg_reg_const_const(A_BFI,toreg,fromreg,tosreg.startbit,tosreg.bitlen))
        end
      else
        inherited;
    end;


  procedure THLCGAArch64.g_intf_wrapper(list: TAsmList; procdef: TProcDef; const labelname: string; ioffset: LongInt);
    var
      make_global: boolean;
      href: TReference;
      hsym: TSym;
      ParaLoc: PCGParaLocation;
      op: TAsmOp;
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
      if (not CurrentModule.IsUnit) or create_smartlink_library or
         (procdef.owner.DefOwner.owner.SymTableType=GlobalSymTable) then
        make_global:=true;

      if make_global then
        list.concat(TAISymbol.Createname_global(labelname,AT_FUNCTION,0,procdef))
      else
        list.concat(TAISymbol.Createname_hidden(labelname,AT_FUNCTION,0,procdef));

      { set param1 interface to self  }
      procdef.Init_ParaLoc_Info(callerside);
      hsym:=TSym(procdef.ParaST.Find('self'));
      if not(Assigned(hsym) and
        (hsym.typ=paravarsym)) then
        InternalError(2010103101);
      ParaLoc:=TParaVarSym(hsym).ParaLoc[callerside].location;
      if Assigned(ParaLoc^.next) then
        InternalError(2013020101);

      case ParaLoc^.loc of
        LOC_REGISTER:
          TCGAArch64(cg).handle_reg_imm12_reg(list,A_SUB,ParaLoc^.size,ParaLoc^.register,ioffset,ParaLoc^.register,NR_IP0,false,true);
        else
          InternalError(2010103102);
      end;

      if (po_virtualmethod in procdef.ProcOptions) and
          not Is_ObjectPascal_Helper(procdef.struct) then
        begin
          if (procdef.ExtNumber=$ffff) then
            InternalError(2000061302);
          { mov  0(%rdi),%rax ; load vmt}
          reference_reset_base(href,VoidPointerType,ParaLoc^.register,0,ctempposinvalid,sizeof(PInt),[]);
          getcpuregister(list,NR_IP0);
          a_load_ref_reg(list,VoidPointerType,VoidPointerType,href,NR_IP0);
          { jmp *vmtoffs(%eax) ; method offs }
          reference_reset_base(href,VoidPointerType,NR_IP0,TObjectDef(procdef.struct).VMTMethodOffset(procdef.ExtNumber),ctempposinvalid,sizeof(PInt),[]);
          op:=A_LDR;
          TCGAArch64(cg).make_simple_ref(list,op,OS_ADDR,PF_None,href,NR_IP0);
          list.concat(TAICPU.op_reg_ref(op,NR_IP0,href));
          ungetcpuregister(list,NR_IP0);
          list.concat(TAICPU.op_reg(A_BR,NR_IP0));
        end
      else
        cg.a_jmp_name(list,procdef.MangledName);
      list.concat(TAISymbolEnd.Createname(labelname));
    end;


  procedure THLCGAArch64.a_load_regconst_subsetreg_intern(list: TAsmList; fromsize, subsetsize: TDef; fromreg: TRegister; const sreg: TSubsetRegister; slopt: TSubsetLoadOpt);
    var
      toreg: TRegister;
    begin
      if slopt in [SL_SETZERO,SL_SETMAX] then
        inherited
      else if not(sreg.bitlen in [32,64]) or
              (sreg.startbit<>0) or
              (getsubreg(fromreg)<getsubreg(sreg.subsetreg)) then
        begin
          makeregssamesize(list,def_cgsize(fromsize),sreg.subsetregsize,fromreg,sreg.subsetreg,fromreg,toreg);
          list.concat(TAICPU.op_reg_reg_const_const(A_BFI,toreg,fromreg,sreg.startbit,sreg.bitlen))
        end
      else
        a_load_reg_reg(list,fromsize,subsetsize,fromreg,sreg.subsetreg);
    end;


  procedure create_hlcodegen_cpu(hlcgobjhelpers: THLCGObjHelpersClass);
    begin
      hlcg:=THLCGAArch64.create(hlcgobjhelpers);
      create_codegen;
    end;


begin
  CHLCGObj:=THLCGAArch64;
  create_hlcodegen:=@create_hlcodegen_cpu;
end.
