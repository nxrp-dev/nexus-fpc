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
      function MakeRegSize(list: TAsmList; reg: TRegister; size: TCgSize): TRegister; override;
      procedure G_Save_Registers(list:TAsmList);override;
      procedure G_Restore_Registers(list:TAsmList);override;
      procedure G_StackPointer_Alloc(list: TAsmList; size: LongInt); override;
      procedure G_Proc_Exit(list: TAsmList; parasize: LongInt; nostackframe: boolean); override;
      procedure G_Proc_Entry(list: TAsmList; localsize: LongInt; nostackframe: boolean); override;
      procedure G_OverflowCheck(list: TAsmList; const Loc: TLocation; def: TDef); override;
{$ifdef cpuflags}
      procedure G_Flags2Reg(list: TAsmList; size: TCgSize; const f: TResFlags; reg: TRegister); override;
      procedure A_Jmp_Flags(list: TAsmList; const f: TResFlags; l: TAsmLabel); override;
{$endif}
      procedure G_ConcatCopy(list: TAsmList; const source, dest: TReference; len: TCGInt); override;
      procedure A_Op_Reg_Reg(list: TAsmList; Op: TOpCG; size: TCgSize; reg1, reg2: TRegister); override;
      procedure A_Op_Const_Reg(list: TAsmList; Op: TOpCG; size: TCgSize; a: TCGInt; reg: TRegister); override;
      procedure A_Load_Reg_Reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister); override;
      procedure A_Load_Reg_Ref(list: TAsmList; fromsize, tosize: TCgSize; register: TRegister; const ref: TReference); override;
      procedure A_Load_Ref_Reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; register: TRegister); override;
      procedure A_Load_Const_Reg(list: TAsmList; size: TCgSize; a: TCGInt; register: TRegister); override;
      procedure A_LoadFPU_Reg_Reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister); override;
      procedure A_LoadFPU_Reg_Ref(list: TAsmList; fromsize, tosize: TCgSize; reg: TRegister; const ref: TReference); override;
      procedure A_LoadFPU_Ref_Reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; reg: TRegister); override;
      procedure A_LoadAddr_Ref_Reg(list: TAsmList; const ref: TReference; r: TRegister); override;
      procedure A_Jmp_Name(list: TAsmList; const s: string); override;
      procedure A_Jmp_Always(list: TAsmList; l: TAsmLabel); override;
      procedure A_Cmp_Reg_Reg_Label(list: TAsmList; size: TCgSize; cmp_op: TOpCmp; reg1, reg2: TRegister; l: TAsmLabel); override;
      procedure A_Call_Reg(list: TAsmList; reg: TRegister); override;
      procedure A_Call_Name(list: TAsmList; const s: string; weak: boolean); override;
      procedure A_Bit_Scan_Reg_Reg(list: TAsmList; reverse,not_zero: boolean; srcsize, dstsize: TCgSize; src, dst: TRegister); override;
    end;

implementation

   { thlbasecgcpu }

    procedure THLBaseCGCPU.A_Bit_Scan_Reg_Reg(list: TAsmList; reverse,not_zero: boolean; srcsize, dstsize: TCgSize; src, dst: TRegister);
      begin
        InternalError(2012042801);
      end;


    procedure THLBaseCGCPU.A_Call_Name(list: TAsmList; const s: string; weak: boolean);
      begin
        InternalError(2012042802);
      end;


    procedure THLBaseCGCPU.A_Call_Reg(list: TAsmList; reg: TRegister);
      begin
        InternalError(2012042803);
      end;


    procedure THLBaseCGCPU.A_Cmp_Reg_Reg_Label(list: TAsmList; size: TCgSize; cmp_op: TOpCmp; reg1, reg2: TRegister; l: TAsmLabel);
      begin
        InternalError(2012042804);
      end;


    procedure THLBaseCGCPU.A_Jmp_Always(list: TAsmList; l: TAsmLabel);
      begin
        InternalError(2012042805);
      end;

{$ifdef cpuflags}
    procedure THLBaseCGCPU.A_Jmp_Flags(list: TAsmList; const f: TResFlags; l: TAsmLabel);
      begin
        InternalError(2012042806);
      end;
{$endif}

    procedure THLBaseCGCPU.A_Jmp_Name(list: TAsmList; const s: string);
      begin
        InternalError(2012042807);
      end;


    procedure THLBaseCGCPU.A_LoadAddr_Ref_Reg(list: TAsmList; const ref: TReference; r: TRegister);
      begin
        InternalError(2012042808);
      end;

    procedure THLBaseCGCPU.A_LoadFPU_Ref_Reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; reg: TRegister);
      begin
        InternalError(2012042809);
      end;


    procedure THLBaseCGCPU.A_LoadFPU_Reg_Ref(list: TAsmList; fromsize, tosize: TCgSize; reg: TRegister; const ref: TReference);
      begin
        InternalError(2012042810);
      end;


    procedure THLBaseCGCPU.A_LoadFPU_Reg_Reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister);
      begin
        InternalError(2012042811);
      end;


    procedure THLBaseCGCPU.A_Load_Const_Reg(list: TAsmList; size: TCgSize; a: TCGInt; register: TRegister);
      begin
        InternalError(2012042812);
      end;


    procedure THLBaseCGCPU.A_Load_Ref_Reg(list: TAsmList; fromsize, tosize: TCgSize; const ref: TReference; register: TRegister);
      begin
        InternalError(2012042813);
      end;


    procedure THLBaseCGCPU.A_Load_Reg_Ref(list: TAsmList; fromsize, tosize: TCgSize; register: TRegister; const ref: TReference);
      begin
        InternalError(2012042814);
      end;


    procedure THLBaseCGCPU.A_Load_Reg_Reg(list: TAsmList; fromsize, tosize: TCgSize; reg1, reg2: TRegister);
      begin
        InternalError(2012042815);
      end;


    procedure THLBaseCGCPU.A_Op_Const_Reg(list: TAsmList; Op: TOpCG; size: TCgSize; a: TCGInt; reg: TRegister);
      begin
        InternalError(2012042816);
      end;


    procedure THLBaseCGCPU.A_Op_Reg_Reg(list: TAsmList; Op: TOpCG; size: TCgSize; reg1, reg2: TRegister);
      begin
        InternalError(2012042817);
      end;


    procedure THLBaseCGCPU.G_ConcatCopy(list: TAsmList; const source, dest: TReference; len: TCGInt);
      begin
        InternalError(2012042818);
      end;

{$ifdef cpuflags}
    procedure THLBaseCGCPU.G_Flags2Reg(list: TAsmList; size: TCgSize; const f: TResFlags; reg: TRegister);
      begin
        InternalError(2012042819);
      end;
{$endif}

    procedure THLBaseCGCPU.G_OverflowCheck(list: TAsmList; const Loc: TLocation; def: TDef);
      begin
        InternalError(2012042820);
      end;


    procedure THLBaseCGCPU.G_Proc_Entry(list: TAsmList; localsize: LongInt; nostackframe: boolean);
      begin
        InternalError(2012042821);
      end;


    procedure THLBaseCGCPU.G_Proc_Exit(list: TAsmList; parasize: LongInt; nostackframe: boolean);
      begin
        InternalError(2012042822);
      end;


    function THLBaseCGCPU.MakeRegSize(list: TAsmList; reg: TRegister; size: TCgSize): TRegister;
      begin
        { you can't just change the size of a (virtual) register on high level
          targets, you have to allocate a new register of the right size and
          move the data there }
        InternalError(2014081201);
        { suppress warning }
        result:=NR_NO;
      end;

    procedure THLBaseCGCPU.G_Save_Registers(list: TAsmList);
      begin
        { do nothing }
      end;

    procedure THLBaseCGCPU.G_Restore_Registers(list: TAsmList);
      begin
        { do nothing }
      end;

    procedure THLBaseCGCPU.G_StackPointer_Alloc(list: TAsmList; size: LongInt);
      begin
        InternalError(2012042823);
      end;


end.

