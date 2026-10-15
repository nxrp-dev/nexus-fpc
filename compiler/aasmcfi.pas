{
    Copyright (c) 2019 by Jonas Maebe, member of the
    Free Pascal Compiler development team

    Dwarf Call Frame Information directives

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
unit aasmcfi;

{$i fpcdefs.inc}

  interface

    uses
      GlobType,
      cgbase,
      aasmtai;

    type
      TCFIKind =
        (cfi_startproc,
         cfi_endproc,
         cfi_personality,
         cfi_personality_id,
         cfi_fde_data,
         cfi_lsda_encoding,
         cfi_inline_lsda,
         cfi_def_cfa,
         cfi_def_cfa_register,
         cfi_def_cfa_offset,
         cfi_adjust_cfa_offset,
         cfi_offset,
         cfi_val_offset,
         cfi_rel_offset,
         cfi_register,
         cfi_restore,
         cfi_undefined,
         cfi_same_value,
         cfi_remember_state,
         cfi_restore_state,
         cfi_return_column,
         cfi_signal_frame,
         cfi_window_save,
         cfi_escape,
         cfi_val_encoded_addr
        );

{$push}
{$j-}
      const
        cfi2str: array[TCFIKind] of string[length('.cfi_adjust_cfa_offset')] =
          ('.cfi_startproc',
           '.cfi_endproc',
           '.cfi_personality',
           '.cfi_personality_id',
           '.cfi_fde_data',
           '.cfi_lsda_encoding',
           '.cfi_inline_lsda',
           '.cfi_def_cfa',
           '.cfi_def_cfa_register',
           '.cfi_def_cfa_offset',
           '.cfi_adjust_cfa_offset',
           '.cfi_offset',
           '.cfi_val_offset',
           '.cfi_rel_offset',
           '.cfi_register',
           '.cfi_restore',
           '.cfi_undefined',
           '.cfi_same_value',
           '.cfi_remember_state',
           '.cfi_restore_state',
           '.cfi_return_column',
           '.cfi_signal_frame',
           '.cfi_window_save',
           '.cfi_escape',
           '.cfi_val_encoded_addr'
          );
{$pop}

    type
      TAICFIBase = class abstract(TAI)
        cfityp: TCFIKind;
        constructor create(ctyp: TCFIKind);
      end;

      TAICFIOpNone = class(TAICFIBase)
      end;

      TAICFIOpVal = class(TAICFIBase)
        val1: aint;
        constructor create(ctyp: TCFIKind; const a: aint);
      end;

      TAICFIOpString = class(TAICFIBase)
        s1: TSymStr;
        constructor create(ctyp: TCFIKind; const str1: TSymStr);
      end;

      TAICFIOpValString = class(TAICFIOpVal)
        s: TSymStr;
        constructor create(ctyp: TCFIKind; const a: aint; const str: TSymStr);
      end;

      TAICFIOpStringString = class(TAICFIOpString)
        s2: TSymStr;
        constructor create(ctyp: TCFIKind; const str1, str2: TSymStr);
      end;

      TAICFIOpReg = class(TAICFIBase)
        reg1: TRegister;
        constructor create(ctyp: TCFIKind; r: TRegister);
      end;

      TAICFIOpRegVal = class(TAICFIOpReg)
        val: aint;
        constructor create(ctyp: TCFIKind; r: TRegister; a: aint);
      end;

      TAICFIOpRegReg = class(TAICFIOpReg)
        reg2: TRegister;
        constructor create(ctyp: TCFIKind; r1, r2: TRegister);
      end;


  implementation

    constructor TAICFIBase.create(ctyp: TCFIKind);
      begin
        typ:=ait_cfi;
        cfityp:=ctyp;
      end;


    constructor TAICFIOpVal.create(ctyp: TCFIKind; const a: aint);
      begin
        inherited create(ctyp);
        val1:=a;
      end;


    constructor TAICFIOpString.create(ctyp: TCFIKind; const str1: TSymStr);
      begin
        inherited create(ctyp);
        s1:=str1;
      end;


    constructor TAICFIOpValString.create(ctyp: TCFIKind; const a: aint; const str: TSymStr);
      begin
        inherited create(ctyp,a);
        s:=str;
      end;


    constructor TAICFIOpStringString.create(ctyp: TCFIKind; const str1, str2: TSymStr);
      begin
        inherited create(ctyp,str1);
        s2:=str2;
      end;


    constructor TAICFIOpReg.create(ctyp: TCFIKind; r: TRegister);
      begin
        inherited create(ctyp);
        reg1:=r;
      end;


    constructor TAICFIOpRegVal.create(ctyp: TCFIKind; r: TRegister; a: aint);
      begin
        inherited create(ctyp,r);
        val:=a;
      end;


    constructor TAICFIOpRegReg.create(ctyp: TCFIKind; r1, r2: TRegister);
      begin
        inherited create(ctyp,r1);
        reg2:=r2;
      end;

end.

