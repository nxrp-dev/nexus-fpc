{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Helper routines for the i386 code generator

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

unit cga;

{$i fpcdefs.inc}

interface

    uses
       GlobType,
       cpubase,cgbase,cgutils,
       aasmbase,AAsmData,aasmcpu;

    procedure emit_none(i : TAsmOp;s : TOpSize);

    procedure emit_reg(i : TAsmOp;s : TOpSize;reg : TRegister);
    procedure emit_ref(i : TAsmOp;s : TOpSize;ref : TReference);

    procedure emit_const_reg(i : TAsmOp;s : TOpSize;c : aint;reg : TRegister);
    procedure emit_const_ref(i : TAsmOp;s : TOpSize;c : aint;ref : TReference);
    procedure emit_ref_reg(i : TAsmOp;s : TOpSize;ref : TReference;reg : TRegister);
    procedure emit_reg_ref(i : TAsmOp;s : TOpSize;reg : TRegister;ref : TReference);
    procedure emit_reg_reg(i : TAsmOp;s : TOpSize;reg1,reg2 : TRegister);

    procedure emit_const_reg_reg(i : TAsmOp;s : TOpSize;c : LongInt;reg1,reg2 : TRegister);
    procedure emit_reg_reg_reg(i : TAsmOp;s : TOpSize;reg1,reg2,reg3 : TRegister);
    procedure emit_ref_reg_reg(i : TAsmOp;s : TOpSize;ref : TReference;reg1,reg2 : TRegister);
    procedure emit_reg_ref_reg(i : TAsmOp;s : TOpSize; reg1 : TRegister; ref : TReference; reg2 : TRegister);

    procedure emit_sym(i : TAsmOp;s : TOpSize;op : TAsmSymbol);


implementation

    uses
       Verbose,
       cgobj,cgx86;


{*****************************************************************************
                              Emit Assembler
*****************************************************************************}

    procedure emit_none(i : TAsmOp;s : TOpSize);
      begin
         CurrentAsmData.CurrAsmList.concat(TAICPU.Op_none(i,s));
      end;

    procedure emit_reg(i : TAsmOp;s : TOpSize;reg : TRegister);
      begin
         CurrentAsmData.CurrAsmList.concat(TAICPU.Op_reg(i,s,reg));
      end;

    procedure emit_ref(i : TAsmOp;s : TOpSize;ref : TReference);
      begin
        TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,ref);
        CurrentAsmData.CurrAsmList.concat(TAICPU.Op_ref(i,s,ref));
      end;

    procedure emit_const_reg(i : TAsmOp;s : TOpSize;c : aint;reg : TRegister);
      begin
         CurrentAsmData.CurrAsmList.concat(TAICPU.Op_const_reg(i,s,c,reg));
      end;

    procedure emit_const_ref(i : TAsmOp;s : TOpSize;c : aint;ref : TReference);
      begin
        TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,ref);
        CurrentAsmData.CurrAsmList.concat(TAICPU.Op_const_ref(i,s,c,ref));
      end;

    procedure emit_ref_reg(i : TAsmOp;s : TOpSize;ref : TReference;reg : TRegister);
      begin
        TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,ref);
        CurrentAsmData.CurrAsmList.concat(TAICPU.Op_ref_reg(i,s,ref,reg));
      end;

    procedure emit_reg_ref(i : TAsmOp;s : TOpSize;reg : TRegister;ref : TReference);
      begin
        TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,ref);
        CurrentAsmData.CurrAsmList.concat(TAICPU.Op_reg_ref(i,s,reg,ref));
      end;

    procedure emit_reg_reg(i : TAsmOp;s : TOpSize;reg1,reg2 : TRegister);

    var instr:TAICPU;

    begin
      if not ((reg1=reg2) and (i=A_MOV)) then
        begin
          instr:=TAICPU.op_reg_reg(i,s,reg1,reg2);
          CurrentAsmData.CurrAsmList.concat(instr);
          if i=A_MOV then
            cg.Add_Move_Instruction(instr);
        end;
    end;

    procedure emit_const_reg_reg(i : TAsmOp;s : TOpSize;c : LongInt;reg1,reg2 : TRegister);
      begin
         CurrentAsmData.CurrAsmList.concat(TAICPU.Op_const_reg_reg(i,s,c,reg1,reg2));
      end;

    procedure emit_reg_reg_reg(i : TAsmOp;s : TOpSize;reg1,reg2,reg3 : TRegister);
      begin
         CurrentAsmData.CurrAsmList.concat(TAICPU.Op_reg_reg_reg(i,s,reg1,reg2,reg3));
      end;

    procedure emit_ref_reg_reg(i : TAsmOp;s : TOpSize;ref : TReference;reg1,reg2 : TRegister);
      begin
        TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,ref);
        CurrentAsmData.CurrAsmList.concat(TAICPU.Op_ref_reg_reg(i,s,ref,reg1,reg2));
      end;

    procedure emit_reg_ref_reg(i : TAsmOp;s : TOpSize; reg1 : TRegister; ref : TReference; reg2 : TRegister);
      begin
        TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,ref);
        CurrentAsmData.CurrAsmList.concat(TAICPU.Op_reg_ref_reg(i,s,reg1,ref,reg2));
      end;

    procedure emit_sym(i : TAsmOp;s : TOpSize;op : TAsmSymbol);
      begin
        CurrentAsmData.CurrAsmList.concat(TAICPU.Op_sym(i,s,op));
      end;

end.
