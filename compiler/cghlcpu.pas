{
    Copyright (c) 2012 by Jonas Maebe
    Member of the Free Pascal development team

    This unit replaces all abstract methods of cgobj that are unused for
    targets that are based on the high level code generator with stubs that
    result in an internalerror

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

unit cghlcpu;

{$i fpcdefs.inc}

interface

uses
  GlobType,Verbose,
  aasmbase,AAsmData,
  symtype,symdef,
  cpubase,cgbase,cgutils,cgobj;

  type
    THLBaseCGCPU = class(TCG)
     public
      function makeregsize(list: TAsmList; reg: TRegister; size: TCgSize): TRegister; override;
      procedure g_save_registers(list:TAsmList);override;
      procedure g_restore_registers(list:TAsmList);override;
      procedure g_stackpointer_alloc(list: TAsmList; size: LongInt); override;
      procedure g_proc_exit(list: TAsmList; parasize: LongInt; nostackframe: boolean); override;
      procedure g_proc_entry(list: TAsmList; localsize: LongInt; nostackframe: boolean); override;
      procedure g_overflowcheck(list: TAsmList; const Loc: TLocation; def: TDef); override;
{$ifdef cpuflags}
      procedure g_flags2reg(list: TAsmList; size: TCgSize; const f: TResFlags; reg: TRegister); override;
      procedure a_jmp_flags(list: TAsmList; const f: TResFlags; l: TAsmLabel); override;
{$endif}
      procedure g_concatcopy(list: TAsmList; const source, dest: TReference; len: TCGInt); override;
      procedure a_op_reg_reg(list: TAsmList; Op: TOpCG; size: TCgSize; reg1, reg2: TRegister); override;
      procedure a_op_const_reg(list: TAsmList; Op: TOpCG; size: TCgSize; a: TCGInt; reg: TRegister); override;
      procedure a_load_reg_reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister); override;
      procedure a_load_reg_ref(list: TAsmList; fromsize, tosize: TCgSize; register: TRegister; const ref: TReference); override;
      procedure a_load_ref_reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; register: TRegister); override;
      procedure a_load_const_reg(list: TAsmList; size: TCgSize; a: TCGInt; register: TRegister); override;
      procedure a_loadfpu_reg_reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister); override;
      procedure a_loadfpu_reg_ref(list: TAsmList; fromsize, tosize: TCgSize; reg: TRegister; const ref: TReference); override;
      procedure a_loadfpu_ref_reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; reg: TRegister); override;
      procedure a_loadaddr_ref_reg(list: TAsmList; const ref: TReference; r: TRegister); override;
      procedure a_jmp_name(list: TAsmList; const s: string); override;
      procedure a_jmp_always(list: TAsmList; l: TAsmLabel); override;
      procedure a_cmp_reg_reg_label(list: TAsmList; size: TCgSize; cmp_op: TOpCmp; reg1, reg2: TRegister; l: TAsmLabel); override;
      procedure a_call_reg(list: TAsmList; reg: TRegister); override;
      procedure a_call_name(list: TAsmList; const s: string; weak: boolean); override;
      procedure a_bit_scan_reg_reg(list: TAsmList; reverse,not_zero: boolean; srcsize, dstsize: TCgSize; src, dst: TRegister); override;
    end;

implementation

   { thlbasecgcpu }

    procedure THLBaseCGCPU.a_bit_scan_reg_reg(list: TAsmList; reverse,not_zero: boolean; srcsize, dstsize: TCgSize; src, dst: TRegister);
      begin
        InternalError(2012042801);
      end;


    procedure THLBaseCGCPU.a_call_name(list: TAsmList; const s: string; weak: boolean);
      begin
        InternalError(2012042802);
      end;


    procedure THLBaseCGCPU.a_call_reg(list: TAsmList; reg: TRegister);
      begin
        InternalError(2012042803);
      end;


    procedure THLBaseCGCPU.a_cmp_reg_reg_label(list: TAsmList; size: TCgSize; cmp_op: TOpCmp; reg1, reg2: TRegister; l: TAsmLabel);
      begin
        InternalError(2012042804);
      end;


    procedure THLBaseCGCPU.a_jmp_always(list: TAsmList; l: TAsmLabel);
      begin
        InternalError(2012042805);
      end;

{$ifdef cpuflags}
    procedure THLBaseCGCPU.a_jmp_flags(list: TAsmList; const f: TResFlags; l: TAsmLabel);
      begin
        InternalError(2012042806);
      end;
{$endif}

    procedure THLBaseCGCPU.a_jmp_name(list: TAsmList; const s: string);
      begin
        InternalError(2012042807);
      end;


    procedure THLBaseCGCPU.a_loadaddr_ref_reg(list: TAsmList; const ref: TReference; r: TRegister);
      begin
        InternalError(2012042808);
      end;

    procedure THLBaseCGCPU.a_loadfpu_ref_reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; reg: TRegister);
      begin
        InternalError(2012042809);
      end;


    procedure THLBaseCGCPU.a_loadfpu_reg_ref(list: TAsmList; fromsize, tosize: TCgSize; reg: TRegister; const ref: TReference);
      begin
        InternalError(2012042810);
      end;


    procedure THLBaseCGCPU.a_loadfpu_reg_reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister);
      begin
        InternalError(2012042811);
      end;


    procedure THLBaseCGCPU.a_load_const_reg(list: TAsmList; size: TCgSize; a: TCGInt; register: TRegister);
      begin
        InternalError(2012042812);
      end;


    procedure THLBaseCGCPU.a_load_ref_reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; register: TRegister);
      begin
        InternalError(2012042813);
      end;


    procedure THLBaseCGCPU.a_load_reg_ref(list: TAsmList; fromsize, tosize: TCgSize; register: TRegister; const ref: TReference);
      begin
        InternalError(2012042814);
      end;


    procedure THLBaseCGCPU.a_load_reg_reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister);
      begin
        InternalError(2012042815);
      end;


    procedure THLBaseCGCPU.a_op_const_reg(list: TAsmList; Op: TOpCG; size: TCgSize; a: TCGInt; reg: TRegister);
      begin
        InternalError(2012042816);
      end;


    procedure THLBaseCGCPU.a_op_reg_reg(list: TAsmList; Op: TOpCG; size: TCgSize; reg1, reg2: TRegister);
      begin
        InternalError(2012042817);
      end;


    procedure THLBaseCGCPU.g_concatcopy(list: TAsmList; const source, dest: TReference; len: TCGInt);
      begin
        InternalError(2012042818);
      end;

{$ifdef cpuflags}
    procedure THLBaseCGCPU.g_flags2reg(list: TAsmList; size: TCgSize; const f: TResFlags; reg: TRegister);
      begin
        InternalError(2012042819);
      end;
{$endif}

    procedure THLBaseCGCPU.g_overflowcheck(list: TAsmList; const Loc: TLocation; def: TDef);
      begin
        InternalError(2012042820);
      end;


    procedure THLBaseCGCPU.g_proc_entry(list: TAsmList; localsize: LongInt; nostackframe: boolean);
      begin
        InternalError(2012042821);
      end;


    procedure THLBaseCGCPU.g_proc_exit(list: TAsmList; parasize: LongInt; nostackframe: boolean);
      begin
        InternalError(2012042822);
      end;


    function THLBaseCGCPU.makeregsize(list: TAsmList; reg: TRegister; size: TCgSize): TRegister;
      begin
        { you can't just change the size of a (virtual) register on high level
          targets, you have to allocate a new register of the right size and
          move the data there }
        InternalError(2014081201);
        { suppress warning }
        result:=NR_NO;
      end;

    procedure THLBaseCGCPU.g_save_registers(list: TAsmList);
      begin
        { do nothing }
      end;

    procedure THLBaseCGCPU.g_restore_registers(list: TAsmList);
      begin
        { do nothing }
      end;

    procedure THLBaseCGCPU.g_stackpointer_alloc(list: TAsmList; size: LongInt);
      begin
        InternalError(2012042823);
      end;


end.

