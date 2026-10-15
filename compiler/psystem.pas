{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Load the system unit, create required defs for systemunit

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
unit psystem;

{$i fpcdefs.inc}

interface

    uses
      SymBase;

    procedure create_intern_symbols;
    procedure create_intern_types;

    procedure load_intern_types;

    procedure registernodes;
    procedure registertais;


implementation

    uses
      Globals,GlobType,Verbose,ConstExp,CPUInfo,compinnr,
      Systems,
      symconst,symtype,SymSym,symdef,symcpu,SymTable,
      aasmtai,aasmcpu,
      FModule,
      node,nbas,nflw,nset,ncon,ncnv,nld,nmem,ncal,nmat,nadd,ninl;


    procedure create_intern_symbols;
      {
        all intern procedures for the system unit
      }
      begin
        systemunit.insertsym(CSysSym.create('Concat',in_concat_x));
        systemunit.insertsym(CSysSym.create('Write',in_write_x));
        systemunit.insertsym(CSysSym.create('WriteLn',in_writeln_x));
        systemunit.insertsym(CSysSym.create('WriteStr',in_writestr_x));
        systemunit.insertsym(CSysSym.create('Assigned',in_assigned_x));
        systemunit.insertsym(CSysSym.create('Read',in_read_x));
        systemunit.insertsym(CSysSym.create('ReadLn',in_readln_x));
        systemunit.insertsym(CSysSym.create('ReadStr',in_readstr_x));
        systemunit.insertsym(CSysSym.create('Ofs',in_ofs_x));
        systemunit.insertsym(CSysSym.create('SizeOf',in_sizeof_x));
        systemunit.insertsym(CSysSym.create('BitSizeOf',in_bitsizeof_x));
        systemunit.insertsym(CSysSym.create('TypeOf',in_typeof_x));
        systemunit.insertsym(CSysSym.create('Low',in_low_x));
        systemunit.insertsym(CSysSym.create('High',in_high_x));
        systemunit.insertsym(CSysSym.create('Slice',in_slice_x));
        systemunit.insertsym(CSysSym.create('Seg',in_seg_x));
        systemunit.insertsym(CSysSym.create('Ord',in_ord_x));
        systemunit.insertsym(CSysSym.create('Chr',in_chr_byte));
        systemunit.insertsym(CSysSym.create('Pred',in_pred_x));
        systemunit.insertsym(CSysSym.create('Succ',in_succ_x));
        systemunit.insertsym(CSysSym.create('Exclude',in_exclude_x_y));
        systemunit.insertsym(CSysSym.create('Include',in_include_x_y));
        systemunit.insertsym(CSysSym.create('Pack',in_pack_x_y_z));
        systemunit.insertsym(CSysSym.create('Unpack',in_unpack_x_y_z));
        systemunit.insertsym(CSysSym.create('Break',in_break));
        systemunit.insertsym(CSysSym.create('Exit',in_exit));
        systemunit.insertsym(CSysSym.create('Continue',in_continue));
        systemunit.insertsym(CSysSym.create('Leave',in_leave)); {macpas only}
        systemunit.insertsym(CSysSym.create('Cycle',in_cycle)); {macpas only}
        systemunit.insertsym(CSysSym.create('Dec',in_dec_x));
        systemunit.insertsym(CSysSym.create('Inc',in_inc_x));
        systemunit.insertsym(CSysSym.create('Str',in_str_x_string));
        systemunit.insertsym(CSysSym.create('Assert',in_assert_x_y));
        systemunit.insertsym(CSysSym.create('Val',in_val_x));
        systemunit.insertsym(CSysSym.create('Addr',in_addr_x));

        systemunit.insertsym(CSysSym.create('TypeInfo',in_typeinfo_x));
        systemunit.insertsym(CSysSym.create('SetLength',in_setlength_x));
        systemunit.insertsym(CSysSym.create('Copy',in_copy_x));
        systemunit.insertsym(CSysSym.create('Initialize',in_initialize_x));
        systemunit.insertsym(CSysSym.create('Finalize',in_finalize_x));
        systemunit.insertsym(CSysSym.create('Length',in_length_x));
        systemunit.insertsym(CSysSym.create('New',in_new_x));
        systemunit.insertsym(CSysSym.create('Dispose',in_dispose_x));
{$ifdef SUPPORT_GET_FRAME}
        systemunit.insertsym(CSysSym.create('Get_Frame',in_get_frame));
{$endif SUPPORT_GET_FRAME}
        systemunit.insertsym(CSysSym.create('Unaligned',in_unaligned_x));
        systemunit.insertsym(CSysSym.create('Aligned',in_aligned_x));
        systemunit.insertsym(CSysSym.create('Volatile',in_volatile_x));
        systemunit.insertsym(CSysSym.create('ObjCSelector',in_objc_selector_x)); { objc only }
        systemunit.insertsym(CSysSym.create('ObjCEncode',in_objc_encode_x)); { objc only }
        systemunit.insertsym(CSysSym.create('Default',in_default_x));
        systemunit.insertsym(CSysSym.create('SetString',in_setstring_x_y_z));
        systemunit.insertsym(CSysSym.create('Insert',in_insert_x_y_z));
        systemunit.insertsym(CSysSym.create('Delete',in_delete_x_y_z));
        systemunit.insertsym(CSysSym.create('GetTypeKind',in_gettypekind_x));
        systemunit.insertsym(CSysSym.create('IsManagedType',in_ismanagedtype_x));
        systemunit.insertsym(CSysSym.create('IsConstValue',in_isconstvalue_x));
        systemunit.insertsym(CSysSym.create('NameOf',in_nameof_x));
        systemunit.insertsym(CSysSym.create('fpc_eh_return_data_regno', in_const_eh_return_data_regno));
        systemunit.insertsym(CSysSym.create('AtomicIncrement',in_atomic_inc));
        systemunit.insertsym(CSysSym.create('AtomicDecrement',in_atomic_dec));
        systemunit.insertsym(CSysSym.create('AtomicExchange',in_atomic_xchg));
        systemunit.insertsym(CSysSym.create('AtomicCmpExchange',in_atomic_cmp_xchg));
        systemunit.insertsym(CConstSym.create_ord('False',constord,0,pasbool1type));
        systemunit.insertsym(CConstSym.create_ord('True',constord,1,pasbool1type));
      end;


    procedure set_default_int_types;
      begin
{$ifdef cpu64bitalu}
        aluuinttype:=u64inttype;
        alusinttype:=s64inttype;
{$endif cpu64bitalu}
{$ifdef cpu64bitaddr}
        sizeuinttype:=u64inttype;
        sizesinttype:=s64inttype;
        uinttype:=u64inttype;
        sinttype:=s64inttype;
{$endif cpu64bitaddr}
{$ifdef cpu32bitaddr}
        sizeuinttype:=u32inttype;
        sizesinttype:=s32inttype;
        uinttype:=u32inttype;
        sinttype:=s32inttype;
{$endif cpu32bitaddr}
{$ifdef cpu32bitalu}
        uinttype:=u32inttype;
        sinttype:=s32inttype;
        aluuinttype:=u32inttype;
        alusinttype:=s32inttype;
{$endif cpu32bitalu}




        osuinttype:=uinttype;
        ossinttype:=sinttype;
      end;


    procedure set_default_ptr_types;
      begin

        voidcodepointertype:=voidpointertype;
        voidstackpointertype:=voidpointertype;

        case voidcodepointertype.size of
          2:
            begin
              codeptruinttype:=u16inttype;
              codeptrsinttype:=s16inttype;
            end;
          4:
            begin
              codeptruinttype:=u32inttype;
              codeptrsinttype:=s32inttype;
            end;
          8:
            begin
              codeptruinttype:=u64inttype;
              codeptrsinttype:=s64inttype;
            end;
          else
            InternalError(2015112106);
        end;
        case voidpointertype.size of
          2:
            begin
              ptruinttype:=u16inttype;
              ptrsinttype:=s16inttype;
            end;
          4:
            begin
              ptruinttype:=u32inttype;
              ptrsinttype:=s32inttype;
            end;
          8:
            begin
              ptruinttype:=u64inttype;
              ptrsinttype:=s64inttype;
            end;
          else
            InternalError(2016100301);
        end;
      end;

    procedure create_intern_types;
      {
        all the types inserted into the system unit
      }

        function addtype(const s:string;def:TDef):TTypeSym;
        begin
          result:=CTypeSym.create(s,def);
          systemunit.insertsym(result);
        end;

        procedure addfield(recst:TAbstractRecordSymTable;sym:TFieldVarSym);
        begin
          recst.insertsym(sym);
          recst.addfield(sym,vis_hidden);
        end;

        procedure create_fpu_types;
        begin
          if InitSettings.FPUType<>fpu_none then
            begin
              s32floattype:=CFloatDef.create(S32Real,true);
              s64floattype:=CFloatDef.create(S64Real,true);
              s80floattype:=CFloatDef.create(s80real,true);
              sc80floattype:=CFloatDef.create(sc80real,true);
            end
          else
            begin
              s32floattype:=nil;
              s64floattype:=nil;
              s80floattype:=nil;
              sc80floattype:=nil;
            end;
        end;

      var
        hrecst : TRecordSymTable;
	pvmt_name : shortstring;
      begin
        SymTableStack.push(systemunit);
        cundefinedtype:=CUndefinedDef.create(true);
        cformaltype:=CFormalDef.create(false);
        ctypedformaltype:=CFormalDef.create(true);
        voidtype:=COrdDef.create(uvoid,0,0,true);
        voidpointertype:=CPointerDef.create(voidtype);
        u8inttype:=COrdDef.create(u8bit,0,255,true);
        s8inttype:=COrdDef.create(s8bit,int64(-128),127,true);
        u16inttype:=COrdDef.create(u16bit,0,65535,true);
        s16inttype:=COrdDef.create(s16bit,int64(-32768),32767,true);
        s24inttype:=COrdDef.create(customint,-(int64(1) shl 23),1 shl 23 - 1,true);
        u24inttype:=COrdDef.create(customint,0,1 shl 24 - 1,true);
        u32inttype:=COrdDef.create(u32bit,0,high(LongWord),true);
        s32inttype:=COrdDef.create(s32bit,int64(low(LongInt)),int64(high(LongInt)),true);
        s40inttype:=COrdDef.create(customint,-(int64(1) shl 39),int64(1) shl 39 - 1,true);
        u40inttype:=COrdDef.create(customint,0,int64(1) shl 40 - 1,true);
        s48inttype:=COrdDef.create(customint,-(int64(1) shl 47),int64(1) shl 47 - 1,true);
        u48inttype:=COrdDef.create(customint,0,int64(1) shl 48 - 1,true);
        s56inttype:=COrdDef.create(customint,-(int64(1) shl 55),int64(1) shl 55 - 1,true);
        u56inttype:=COrdDef.create(customint,0,int64(1) shl 56 - 1,true);
        u64inttype:=COrdDef.create(u64bit,low(qword),high(qword),true);
        s64inttype:=COrdDef.create(s64bit,low(int64),high(int64),true);
        { upper/lower bound not yet properly set for 128 bit types, as we don't
          support them yet at the Pascal level (nor for tconstexprint); they're
          only used internally by the high level code generator for LLVM to
          implement overflow checking }
        u128inttype:=COrdDef.create(u128bit,0,0,true);
        s128inttype:=COrdDef.create(s128bit,0,0,true);
        pasbool1type:=COrdDef.create(pasbool1,0,1,true);
        pasbool8type:=COrdDef.create(pasbool8,0,1,true);
        pasbool16type:=COrdDef.create(pasbool16,0,1,true);
        pasbool32type:=COrdDef.create(pasbool32,0,1,true);
        pasbool64type:=COrdDef.create(pasbool64,0,1,true);
        bool8type:=COrdDef.create(bool8bit,low(int64),high(int64),true);
        bool16type:=COrdDef.create(bool16bit,low(int64),high(int64),true);
        bool32type:=COrdDef.create(bool32bit,low(int64),high(int64),true);
        bool64type:=COrdDef.create(bool64bit,low(int64),high(int64),true);

        cansichartype:=COrdDef.create(uchar,0,255,true);
        cwidechartype:=COrdDef.create(uwidechar,0,65535,true);
        cshortstringtype:=CStringDef.createshort(255,true);
        { should we give a length to the default long and ansi string definition ?? }
        clongstringtype:=CStringDef.createlong(-1,true);
        cansistringtype:=CStringDef.createansi(0,true);
        if TargetInfo.system in systems_windows then
          cwidestringtype:=CStringDef.createwide(true)
        else
          cwidestringtype:=CStringDef.createunicode(true);
        cunicodestringtype:=CStringDef.createunicode(true);
        { length=0 for shortstring is open string (needed for readln(string) }
        openshortstringtype:=CStringDef.createshort(0,true);
        pvmt_name:='pvmt';
 {$ifdef x86}
        create_fpu_types;
        if TargetInfo.system=system_x86_64_win64 then
          s64currencytype:=COrdDef.create(scurrency,low(int64),high(int64),true)
        else
          s64currencytype:=CFloatDef.create(s64currency,true);
{$endif x86}
{$ifdef aarch64}
        create_fpu_types;
        s64currencytype:=COrdDef.create(scurrency,low(int64),high(int64),true);
{$endif aarch64}

        set_default_int_types;
        { some other definitions }
        charpointertype:=CPointerDef.create(cansichartype);
        widecharpointertype:=CPointerDef.create(cwidechartype);

        parentfpvoidpointertype:=CPointerDef.create(voidtype);

{$ifdef x86}
        voidnearpointertype:=TCPUPointerDefClass(CPointerDef).createx86(voidtype,x86pt_near);
        voidnearcspointertype:=TCPUPointerDefClass(CPointerDef).createx86(voidtype,x86pt_near_cs);
        voidneardspointertype:=TCPUPointerDefClass(CPointerDef).createx86(voidtype,x86pt_near_ds);
        voidnearsspointertype:=TCPUPointerDefClass(CPointerDef).createx86(voidtype,x86pt_near_ss);
        voidnearespointertype:=TCPUPointerDefClass(CPointerDef).createx86(voidtype,x86pt_near_es);
        voidnearfspointertype:=TCPUPointerDefClass(CPointerDef).createx86(voidtype,x86pt_near_fs);
        voidneargspointertype:=TCPUPointerDefClass(CPointerDef).createx86(voidtype,x86pt_near_gs);

        x86_m64type:=CArrayDef.create_vector(0,1,s32inttype);
        x86_m128type:=CArrayDef.create_vector(0,3,s32inttype);
        x86_m128dtype:=CArrayDef.create_vector(0,1,s32inttype);
        x86_m128itype:=CArrayDef.create_vector(0,3,s32inttype);
        x86_m256type:=CArrayDef.create_vector(0,7,s32inttype);
        x86_m256dtype:=CArrayDef.create_vector(0,3,s32inttype);
        x86_m256itype:=CArrayDef.create_vector(0,7,s32inttype);

        TArrayDef(x86_m64type).elementdef:=s32floattype;
        TArrayDef(x86_m128type).elementdef:=s32floattype;
        TArrayDef(x86_m128dtype).elementdef:=s64floattype;
        TArrayDef(x86_m128itype).elementdef:=s32floattype;
        TArrayDef(x86_m256type).elementdef:=s32floattype;
        TArrayDef(x86_m256dtype).elementdef:=s64floattype;
        TArrayDef(x86_m256itype).elementdef:=s32floattype;
{$endif x86}
        set_default_ptr_types;
        openchararraytype:=CArrayDef.create_openarray;
        TArrayDef(openchararraytype).elementdef:=cansichartype;
        cfiletype:=CFileDef.createuntyped;
        if f_variants in Features then
          begin
            CVariantType:=CVariantDef.create(vt_normalvariant);
            colevarianttype:=CVariantDef.create(vt_olevariant);
          end;

        if InitSettings.FPUType<>fpu_none then
          begin
            addtype('Single',s32floattype);
            addtype('Double',s64floattype);
            { extended size is the best real type for the target }
            addtype('Extended',pbestrealtype^);
            { CExtended corresponds to the C version of the Extended type
              (either "long double" or "double") }
            if TargetInfo.system in (systems_android+[system_x86_64_win64]) then
              { Microsoft C and Android x86 use Double at this boundary. }
              addtype('CExtended',s64floattype)
            else
              if TFloatDef(pbestrealtype^).floattype=s80real then
                addtype('CExtended',sc80floattype)
              else
                addtype('CExtended',pbestrealtype^);
          end;
{$ifdef x86}
        if TargetInfo.system<>system_x86_64_win64 then
          addtype('Comp',CFloatDef.create(s64comp,true));
{$endif x86}
        addtype('Currency',s64currencytype);
        addtype('Pointer',voidpointertype);
{$ifdef x86}
        addtype('NearPointer',voidnearpointertype);
        addtype('NearCsPointer',voidnearcspointertype);
        addtype('NearDsPointer',voidneardspointertype);
        addtype('NearSsPointer',voidnearsspointertype);
        addtype('NearEsPointer',voidnearespointertype);
        addtype('NearFsPointer',voidnearfspointertype);
        addtype('NearGsPointer',voidneargspointertype);

        addtype('__m64',x86_m64type);
        addtype('__m128', x86_m128type);
        addtype('__m128d',x86_m128dtype);
        addtype('__m128i',x86_m128itype);
        addtype('__m256', x86_m256type);
        addtype('__m256d',x86_m256dtype);
        addtype('__m256i',x86_m256itype);
{$endif x86}
        addtype('ShortString',cshortstringtype);
{$ifdef support_longstring}
        addtype('LongString',clongstringtype);
{$endif support_longstring}
        addtype('AnsiString',cansistringtype);
        addtype('WideString',cwidestringtype);
        addtype('UnicodeString',cunicodestringtype);

        addtype('OpenString',openshortstringtype);
        addtype('Boolean',pasbool1type);
        addtype('Boolean8',pasbool8type);
        addtype('Boolean16',pasbool16type);
        addtype('Boolean32',pasbool32type);
        addtype('Boolean64',pasbool64type);
        addtype('ByteBool',bool8type);
        addtype('WordBool',bool16type);
        addtype('LongBool',bool32type);
        addtype('QWordBool',bool64type);

        addtype('Byte',u8inttype);
        addtype('ShortInt',s8inttype);
        addtype('Word',u16inttype);
        addtype('SmallInt',s16inttype);
        addtype('LongWord',u32inttype);
        addtype('LongInt',s32inttype);
        addtype('QWord',u64inttype);
        addtype('Int64',s64inttype);
        addtype('AnsiChar',cansichartype);
        addtype('WideChar',cwidechartype);
        addtype('Text',CFileDef.createtext);
        addtype('TypedFile',CFileDef.createtyped(voidtype));
        if f_variants in Features then
          begin
            addtype('Variant',CVariantType);
            addtype('OleVariant',colevarianttype);
          end;
        { Internal types }
        addtype('$undefined',cundefinedtype);
        addtype('$formal',cformaltype);
        addtype('$typedformal',ctypedformaltype);
        addtype('$void',voidtype);
        addtype('$void_pointer',voidpointertype);
        addtype('$byte',u8inttype);
        addtype('$shortint',s8inttype);
        addtype('$word',u16inttype);
        addtype('$smallint',s16inttype);
        addtype('$sint24',s24inttype);
        addtype('$uint24',u24inttype);
        addtype('$ulong',u32inttype);
        addtype('$longint',s32inttype);
        addtype('$sint40',s40inttype);
        addtype('$uint40',u40inttype);
        addtype('$sint48',s48inttype);
        addtype('$uint48',u48inttype);
        addtype('$sint56',s56inttype);
        addtype('$uint56',u56inttype);
        addtype('$qword',u64inttype);
        addtype('$int64',s64inttype);
        addtype('$uint128',u128inttype);
        addtype('$int128',s128inttype);
        addtype('$ansichar',cansichartype);
        addtype('$widechar',cwidechartype);
        addtype('$shortstring',cshortstringtype);
        addtype('$longstring',clongstringtype);
        addtype('$ansistring',cansistringtype);
        addtype('$widestring',cwidestringtype);
        addtype('$unicodestring',cunicodestringtype);
        addtype('$openshortstring',openshortstringtype);
        addtype('$boolean',pasbool1type);
        addtype('$boolean8',pasbool8type);
        addtype('$boolean16',pasbool16type);
        addtype('$boolean32',pasbool32type);
        addtype('$boolean64',pasbool64type);
        addtype('$bytebool',bool8type);
        addtype('$wordbool',bool16type);
        addtype('$longbool',bool32type);
        addtype('$qwordbool',bool64type);

        addtype('$char_pointer',charpointertype);
        addtype('$widechar_pointer',widecharpointertype);
        addtype('$parentfp_void_pointer',parentfpvoidpointertype);
{$ifdef x86}
        addtype('$void_nearpointer',voidnearpointertype);
        addtype('$void_nearcspointer',voidnearcspointertype);
        addtype('$void_neardspointer',voidneardspointertype);
        addtype('$void_nearsspointer',voidnearsspointertype);
        addtype('$void_nearespointer',voidnearespointertype);
        addtype('$void_nearfspointer',voidnearfspointertype);
        addtype('$void_neargspointer',voidneargspointertype);

        addtype('$__m64',  x86_m64type);
        addtype('$__m128', x86_m128type);
        addtype('$__m128d',x86_m128dtype);
        addtype('$__m128i',x86_m128itype);
        addtype('$__m256', x86_m256type);
        addtype('$__m256d',x86_m256dtype);
        addtype('$__m256i',x86_m256itype);
{$endif x86}
        addtype('$openchararray',openchararraytype);
        addtype('$file',cfiletype);
        if f_variants in Features then
          begin
            addtype('$variant',CVariantType);
            addtype('$olevariant',colevarianttype);
          end;
        if InitSettings.FPUType<>fpu_none then
          begin
            addtype('$s32real',s32floattype);
            addtype('$s64real',s64floattype);
            addtype('$s80real',s80floattype);
            addtype('$sc80real',sc80floattype);
          end;
        addtype('$s64currency',s64currencytype);
          begin
            { Add a type for virtual method tables }
            hrecst:=TRecordSymTable.create('',CurrentSettings.PackRecords,CurrentSettings.alignment.RecordAlignMin);
            vmttype:=CRecordDef.create('',hrecst);
            pvmttype:=CPointerDef.create(vmttype);
            { can't use addtype for pvmt because the rtti of the pointed
              type is not available. The rtti for pvmt will be written implicitly
              by thev tblarray below }
            systemunit.insertsym(CTypeSym.create('$'+pvmt_name,pvmttype));
            addfield(hrecst,CFieldVarSym.create('$length',vs_value,sizesinttype,[]));
            addfield(hrecst,CFieldVarSym.create('$mlength',vs_value,sizesinttype,[]));
            addfield(hrecst,CFieldVarSym.create('$parent',vs_value,pvmttype,[]));
            { it seems vmttype is used both for TP objects and Delphi classes,
              so the next entry could either be the first virtual method (vm1)
              (object) or the class name (class). We can't easily create separate
              vtable formats for both, as gdb is hard coded to search for
              __vtbl_ptr_type in all cases (JM) }
            addfield(hrecst,CFieldVarSym.create('$vm1_or_classname',vs_value,CPointerDef.create(cshortstringtype),[]));
            vmtarraytype:=CArrayDef.create(0,0,s32inttype);
            TArrayDef(vmtarraytype).elementdef:=voidpointertype;
            addfield(hrecst,CFieldVarSym.create('$__pfn',vs_value,vmtarraytype,[]));
            addtype('$__vtbl_ptr_type',vmttype);
            vmtarraytype:=CArrayDef.create(0,1,s32inttype);
            TArrayDef(vmtarraytype).elementdef:=pvmttype;
            addtype('$vtblarray',vmtarraytype);
          end;
        { Add a type for methodpointers }
        hrecst:=TRecordSymTable.create('',1,CurrentSettings.alignment.RecordAlignMin);
        addfield(hrecst,CFieldVarSym.create('$proc',vs_value,voidcodepointertype,[]));
        addfield(hrecst,CFieldVarSym.create('$self',vs_value,voidpointertype,[]));
        methodpointertype:=CRecordDef.create('',hrecst);
        addtype('$methodpointer',methodpointertype);
        { Add a type for nested proc pointers }
        hrecst:=TRecordSymTable.create('',1,CurrentSettings.alignment.RecordAlignMin);
        addfield(hrecst,CFieldVarSym.create('$proc',vs_value,voidcodepointertype,[]));
        addfield(hrecst,CFieldVarSym.create('$parentfp',vs_value,parentfpvoidpointertype,[]));
        nestedprocpointertype:=CRecordDef.create('',hrecst);
        addtype('$nestedprocpointer',nestedprocpointertype);
        SymTableStack.pop(systemunit);
      end;


    procedure load_intern_types;
      {
        Load all default definitions for consts from the system unit
      }

        procedure loadtype(const s:string;var def:TDef);
        var
          srsym : TTypeSym;
        begin
          srsym:=search_system_type(s);
          def:=srsym.typedef;
        end;

      var
        oldcurrentmodule : TModule;
        pvmt_name : shortstring;
      begin
        oldcurrentmodule:=CurrentModule;
        SetCurrentModule(nil);
        loadtype('byte',u8inttype);
        loadtype('shortint',s8inttype);
        loadtype('word',u16inttype);
        loadtype('smallint',s16inttype);
        loadtype('uint24',u24inttype);
        loadtype('sint24',s24inttype);
        loadtype('ulong',u32inttype);
        loadtype('longint',s32inttype);
        loadtype('uint40',u40inttype);
        loadtype('sint40',s40inttype);
        loadtype('uint48',u48inttype);
        loadtype('sint48',s48inttype);
        loadtype('uint56',u56inttype);
        loadtype('sint56',s56inttype);
        loadtype('qword',u64inttype);
        loadtype('int64',s64inttype);
        loadtype('uint128',u128inttype);
        loadtype('int128',s128inttype);
        loadtype('undefined',cundefinedtype);
        loadtype('formal',cformaltype);
        loadtype('typedformal',ctypedformaltype);
        loadtype('void',voidtype);
        loadtype('void_pointer',voidpointertype);
        loadtype('ansichar',cansichartype);
        loadtype('widechar',cwidechartype);
        loadtype('shortstring',cshortstringtype);
        loadtype('longstring',clongstringtype);
        loadtype('ansistring',cansistringtype);
        loadtype('widestring',cwidestringtype);
        loadtype('unicodestring',cunicodestringtype);
        loadtype('openshortstring',openshortstringtype);
        loadtype('openchararray',openchararraytype);
        if InitSettings.FPUType <> fpu_none then
          begin
            loadtype('s32real',s32floattype);
            loadtype('s64real',s64floattype);
            loadtype('s80real',s80floattype);
            loadtype('sc80real',sc80floattype);
          end;
        loadtype('s64currency',s64currencytype);
        loadtype('boolean',pasbool1type);
        loadtype('boolean8',pasbool8type);
        loadtype('boolean16',pasbool16type);
        loadtype('boolean32',pasbool32type);
        loadtype('boolean64',pasbool64type);
        loadtype('bytebool',bool8type);
        loadtype('wordbool',bool16type);
        loadtype('longbool',bool32type);
        loadtype('qwordbool',bool64type);
        loadtype('char_pointer',charpointertype);
        loadtype('widechar_pointer',widecharpointertype);
        loadtype('parentfp_void_pointer',parentfpvoidpointertype);
{$ifdef x86}
        loadtype('void_nearpointer',voidnearpointertype);
        loadtype('void_nearcspointer',voidnearcspointertype);
        loadtype('void_neardspointer',voidneardspointertype);
        loadtype('void_nearsspointer',voidnearsspointertype);
        loadtype('void_nearespointer',voidnearespointertype);
        loadtype('void_nearfspointer',voidnearfspointertype);
        loadtype('void_neargspointer',voidneargspointertype);

        loadtype('__m64',  x86_m64type);
        loadtype('__m128', x86_m128type);
        loadtype('__m128d',x86_m128dtype);
        loadtype('__m128i',x86_m128itype);
        loadtype('__m256', x86_m256type);
        loadtype('__m256d',x86_m256dtype);
        loadtype('__m256i',x86_m256itype);
{$endif x86}

        loadtype('file',cfiletype);
        pvmt_name:='pvmt';
        loadtype(pvmt_name,pvmttype);
        loadtype('vtblarray',vmtarraytype);
        loadtype('__vtbl_ptr_type',vmttype);
        if f_variants in Features then
          begin
            loadtype('variant',CVariantType);
            loadtype('olevariant',colevarianttype);
          end;
        loadtype('methodpointer',methodpointertype);
        loadtype('nestedprocpointer',nestedprocpointertype);
        loadtype('HRESULT',hresultdef);
        loadtype('TTYPEKIND',typekindtype);
        set_default_int_types;
        set_default_ptr_types;
        SetCurrentModule(oldcurrentmodule);
      end;


    procedure registernodes;
      {
        Register all possible nodes in the nodeclass array that
        will be used for loading the nodes from a ppu
      }
      begin
        nodeclass[addn]:=CAddNode;
        nodeclass[muln]:=CAddNode;
        nodeclass[subn]:=CAddNode;
        nodeclass[divn]:=CModDivNode;
        nodeclass[symdifn]:=CAddNode;
        nodeclass[modn]:=CModDivNode;
        nodeclass[assignn]:=CAssignmentNode;
        nodeclass[loadn]:=CLoadNode;
        nodeclass[rangen]:=CRangeNode;
        nodeclass[ltn]:=CAddNode;
        nodeclass[lten]:=CAddNode;
        nodeclass[gtn]:=CAddNode;
        nodeclass[gten]:=CAddNode;
        nodeclass[equaln]:=CAddNode;
        nodeclass[unequaln]:=CAddNode;
        nodeclass[inn]:=CInNode;
        nodeclass[orn]:=CAddNode;
        nodeclass[xorn]:=CAddNode;
        nodeclass[shrn]:=CShlShrNode;
        nodeclass[shln]:=CShlShrNode;
        nodeclass[slashn]:=CAddNode;
        nodeclass[andn]:=CAddNode;
        nodeclass[subscriptn]:=CSubscriptNode;
        nodeclass[derefn]:=CDerefNode;
        nodeclass[addrn]:=CAddrNode;
        nodeclass[ordconstn]:=COrdConstNode;
        nodeclass[typeconvn]:=CTypeConvNode;
        nodeclass[calln]:=CCallNode;
        nodeclass[callparan]:=CCallParaNode;
        nodeclass[realconstn]:=CRealConstNode;
        nodeclass[unaryminusn]:=CUnaryMinusNode;
        nodeclass[unaryplusn]:=CUnaryPlusNode;
        nodeclass[asmn]:=CAsmNode;
        nodeclass[vecn]:=CVecNode;
        nodeclass[pointerconstn]:=CPointerConstNode;
        nodeclass[stringconstn]:=CStringConstNode;
        nodeclass[notn]:=CNotNode;
        nodeclass[inlinen]:=CInlineNode;
        nodeclass[niln]:=CNilNode;
        nodeclass[errorn]:=CErrorNode;
        nodeclass[typen]:=CTypeNode;
        nodeclass[setelementn]:=CSetElementNode;
        nodeclass[setconstn]:=CSetConstNode;
        nodeclass[blockn]:=CBlockNode;
        nodeclass[statementn]:=CStatementNode;
        nodeclass[ifn]:=CIfNode;
        nodeclass[breakn]:=CBreakNode;
        nodeclass[continuen]:=CContinueNode;
        nodeclass[whilerepeatn]:=CWhileRepeatNode;
        nodeclass[forn]:=CForNode;
        nodeclass[exitn]:=CExitNode;
        nodeclass[casen]:=CCaseNode;
        nodeclass[labeln]:=CLabelNode;
        nodeclass[goton]:=CGotoNode;
        nodeclass[tryexceptn]:=CTryExceptNode;
        nodeclass[raisen]:=CRaiseNode;
        nodeclass[tryfinallyn]:=CTryFinallyNode;
        nodeclass[onn]:=COnNode;
        nodeclass[isn]:=CIsNode;
        nodeclass[asn]:=CAsNode;
        nodeclass[starstarn]:=CAddNode;
        nodeclass[arrayconstructorn]:=CArrayConstructorNode;
        nodeclass[arrayconstructorrangen]:=CArrayConstructorRangeNode;
        nodeclass[tempcreaten]:=CTempCreateNode;
        nodeclass[temprefn]:=CTempRefNode;
        nodeclass[tempdeleten]:=CTempDeleteNode;
        nodeclass[addoptn]:=CAddNode;
        nodeclass[nothingn]:=CNothingNode;
        nodeclass[loadvmtaddrn]:=CLoadVMTAddrNode;
        nodeclass[guidconstn]:=CGUIDConstNode;
        nodeclass[rttin]:=CRTTINode;
        nodeclass[loadparentfpn]:=CLoadParentFPNode;
      end;


    procedure registertais;
      {
        Register all possible tais in the taiclass array that
        will be used for loading the tais from a ppu
      }
      begin
        aiclass[ait_none]:=nil;
        aiclass[ait_align]:=TAIAlign;
        aiclass[ait_section]:=TAISection;
        aiclass[ait_comment]:=TAIComment;
        aiclass[ait_string]:=TAIString;
        aiclass[ait_instruction]:=TAICPU;
        aiclass[ait_datablock]:=TAIDataBlock;
        aiclass[ait_symbol]:=TAISymbol;
        aiclass[ait_symbol_end]:=TAISymbolEnd;
        aiclass[ait_directive]:=TAIDirective;
        aiclass[ait_label]:=TAILabel;
        aiclass[ait_const]:=TAIConst;
        aiclass[ait_realconst]:=TAIRealConst;
        aiclass[ait_force_line]:=TAIForceLine;
        aiclass[ait_function_name]:=TAIFunctionName;
        aiclass[ait_symbolpair]:=TAISymbolPair;
        aiclass[ait_cutobject]:=TAICutObject;
        aiclass[ait_regalloc]:=TAIRegAlloc;
        aiclass[ait_tempalloc]:=TAITempAlloc;
        aiclass[ait_marker]:=TAIMarker;
        aiclass[ait_seh_directive]:=TAISEHDirective;
      end;

end.
