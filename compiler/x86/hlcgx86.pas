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

unit hlcgx86;

interface

{$i fpcdefs.inc}

  uses
    GlobType,
    AAsmData,
    cgbase,
    symtype,symdef,
    parabase,
    hlcgobj, hlcg2ll;

  type
    THLCGX86 = class(THLCG2LL)
     protected
      procedure gen_load_uninitialized_function_result(list: TAsmList; pd: TProcDef; resdef: TDef; const resloc: TCGPara); override;
      procedure a_jmp_external_name(list: TAsmList; const externalname: TSymStr); override;
     public
      procedure a_load_undefined_cgpara(list: TAsmList; size: TDef; const cgpara: TCGPara); override;
      procedure a_bit_set_reg_reg(list: TAsmList; doset: boolean; bitnumbersize, destsize: TDef; bitnumber, dest: TRegister); override;
    end;

implementation

  uses
    Globals,Systems,
    aasmbase,
    cgutils,

    cpubase,aasmcpu;

{ thlcgx86 }

  procedure THLCGX86.gen_load_uninitialized_function_result(list: TAsmList; pd: TProcDef; resdef: TDef; const resloc: TCGPara);
    begin
      { the caller will pop a value from the fpu stack }
      if Assigned(resloc.location) and
         (resloc.location^.loc=LOC_FPUREGISTER) then
        list.concat(TAICPU.op_none(A_FLDZ));
    end;


  procedure THLCGX86.a_jmp_external_name(list: TAsmList; const externalname: TSymStr);
    var
      ref : TReference;
      sym : TAsmSymbol;
    begin
     if (TargetInfo.system = system_i386_darwin) then
       begin
         { a_jmp_name jumps to a stub which is always pic-safe on darwin }
         inherited;
         exit;
       end;

      sym:=CurrentAsmData.RefAsmSymbol(externalname,AT_FUNCTION);
      reference_reset_symbol(ref,sym,0,sizeof(PInt),[]);

      { create pic'ed? }
      if (cs_create_pic in CurrentSettings.ModuleSwitches) and
         { darwin/x86_64's assembler doesn't want @PLT after call symbols }
         not(TargetInfo.system in [system_x86_64_darwin,system_i386_iphonesim,system_x86_64_iphonesim]) then
        ref.refaddr:=addr_pic
      else
        ref.refaddr:=addr_full;
      list.concat(TAICPU.op_ref(A_JMP,S_NO,ref));
    end;


  procedure THLCGX86.a_load_undefined_cgpara(list: TAsmList; size: TDef; const cgpara: TCGPara);
    begin
      if not (cgpara.Location^.Loc in [LOC_REGISTER,LOC_CREGISTER]) and
        (cgpara.size=OS_ADDR) then
        a_load_reg_cgpara(list,size,NR_FRAME_POINTER_REG,cgpara)
      else
        inherited;
    end;

  procedure THLCGX86.a_bit_set_reg_reg(list: TAsmList; doset: boolean; bitnumbersize, destsize: TDef; bitnumber, dest: TRegister);
    const
      bit_set_clr_instr: array[boolean] of TAsmOp = (A_BTR,A_BTS);
    begin

        list.concat(TAICPU.op_reg_reg(bit_set_clr_instr[doset],S_NO,bitnumber,dest));
    end;


end.
