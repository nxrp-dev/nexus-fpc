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
        SystemUnit.InsertSym(CSysSym.Create('Concat',in_concat_x));
        SystemUnit.InsertSym(CSysSym.Create('Write',in_write_x));
        SystemUnit.InsertSym(CSysSym.Create('WriteLn',in_writeln_x));
        SystemUnit.InsertSym(CSysSym.Create('WriteStr',in_writestr_x));
        SystemUnit.InsertSym(CSysSym.Create('Assigned',in_assigned_x));
        SystemUnit.InsertSym(CSysSym.Create('Read',in_read_x));
        SystemUnit.InsertSym(CSysSym.Create('ReadLn',in_readln_x));
        SystemUnit.InsertSym(CSysSym.Create('ReadStr',in_readstr_x));
        SystemUnit.InsertSym(CSysSym.Create('Ofs',in_ofs_x));
        SystemUnit.InsertSym(CSysSym.Create('SizeOf',in_sizeof_x));
        SystemUnit.InsertSym(CSysSym.Create('BitSizeOf',in_bitsizeof_x));
        SystemUnit.InsertSym(CSysSym.Create('TypeOf',in_typeof_x));
        SystemUnit.InsertSym(CSysSym.Create('Low',in_low_x));
        SystemUnit.InsertSym(CSysSym.Create('High',in_high_x));
        SystemUnit.InsertSym(CSysSym.Create('Slice',in_slice_x));
        SystemUnit.InsertSym(CSysSym.Create('Seg',in_seg_x));
        SystemUnit.InsertSym(CSysSym.Create('Ord',in_ord_x));
        SystemUnit.InsertSym(CSysSym.Create('Chr',in_chr_byte));
        SystemUnit.InsertSym(CSysSym.Create('Pred',in_pred_x));
        SystemUnit.InsertSym(CSysSym.Create('Succ',in_succ_x));
        SystemUnit.InsertSym(CSysSym.Create('Exclude',in_exclude_x_y));
        SystemUnit.InsertSym(CSysSym.Create('Include',in_include_x_y));
        SystemUnit.InsertSym(CSysSym.Create('Pack',in_pack_x_y_z));
        SystemUnit.InsertSym(CSysSym.Create('Unpack',in_unpack_x_y_z));
        SystemUnit.InsertSym(CSysSym.Create('Break',in_break));
        SystemUnit.InsertSym(CSysSym.Create('Exit',in_exit));
        SystemUnit.InsertSym(CSysSym.Create('Continue',in_continue));
        SystemUnit.InsertSym(CSysSym.Create('Leave',in_leave)); {macpas only}
        SystemUnit.InsertSym(CSysSym.Create('Cycle',in_cycle)); {macpas only}
        SystemUnit.InsertSym(CSysSym.Create('Dec',in_dec_x));
        SystemUnit.InsertSym(CSysSym.Create('Inc',in_inc_x));
        SystemUnit.InsertSym(CSysSym.Create('Str',in_str_x_string));
        SystemUnit.InsertSym(CSysSym.Create('Assert',in_assert_x_y));
        SystemUnit.InsertSym(CSysSym.Create('Val',in_val_x));
        SystemUnit.InsertSym(CSysSym.Create('Addr',in_addr_x));

        SystemUnit.InsertSym(CSysSym.Create('TypeInfo',in_typeinfo_x));
        SystemUnit.InsertSym(CSysSym.Create('SetLength',in_setlength_x));
        SystemUnit.InsertSym(CSysSym.Create('Copy',in_copy_x));
        SystemUnit.InsertSym(CSysSym.Create('Initialize',in_initialize_x));
        SystemUnit.InsertSym(CSysSym.Create('Finalize',in_finalize_x));
        SystemUnit.InsertSym(CSysSym.Create('Length',in_length_x));
        SystemUnit.InsertSym(CSysSym.Create('New',in_new_x));
        SystemUnit.InsertSym(CSysSym.Create('Dispose',in_dispose_x));
{$ifdef SUPPORT_GET_FRAME}
        SystemUnit.InsertSym(CSysSym.Create('Get_Frame',in_get_frame));
{$endif SUPPORT_GET_FRAME}
        SystemUnit.InsertSym(CSysSym.Create('Unaligned',in_unaligned_x));
        SystemUnit.InsertSym(CSysSym.Create('Aligned',in_aligned_x));
        SystemUnit.InsertSym(CSysSym.Create('Volatile',in_volatile_x));
        SystemUnit.InsertSym(CSysSym.Create('ObjCSelector',in_objc_selector_x)); { objc only }
        SystemUnit.InsertSym(CSysSym.Create('ObjCEncode',in_objc_encode_x)); { objc only }
        SystemUnit.InsertSym(CSysSym.Create('Default',in_default_x));
        SystemUnit.InsertSym(CSysSym.Create('SetString',in_setstring_x_y_z));
        SystemUnit.InsertSym(CSysSym.Create('Insert',in_insert_x_y_z));
        SystemUnit.InsertSym(CSysSym.Create('Delete',in_delete_x_y_z));
        SystemUnit.InsertSym(CSysSym.Create('GetTypeKind',in_gettypekind_x));
        SystemUnit.InsertSym(CSysSym.Create('IsManagedType',in_ismanagedtype_x));
        SystemUnit.InsertSym(CSysSym.Create('IsConstValue',in_isconstvalue_x));
        SystemUnit.InsertSym(CSysSym.Create('NameOf',in_nameof_x));
        SystemUnit.InsertSym(CSysSym.Create('fpc_eh_return_data_regno', in_const_eh_return_data_regno));
        SystemUnit.InsertSym(CSysSym.Create('AtomicIncrement',in_atomic_inc));
        SystemUnit.InsertSym(CSysSym.Create('AtomicDecrement',in_atomic_dec));
        SystemUnit.InsertSym(CSysSym.Create('AtomicExchange',in_atomic_xchg));
        SystemUnit.InsertSym(CSysSym.Create('AtomicCmpExchange',in_atomic_cmp_xchg));
        SystemUnit.InsertSym(CConstSym.Create_Ord('False',constord,0,PasBool1Type));
        SystemUnit.InsertSym(CConstSym.Create_Ord('True',constord,1,PasBool1Type));
      end;


    procedure set_default_int_types;
      begin
{$ifdef cpu64bitalu}
        ALUUIntType:=U64IntType;
        ALUSIntType:=S64IntType;
{$endif cpu64bitalu}
{$ifdef cpu64bitaddr}
        SizeUIntType:=U64IntType;
        SizeSIntType:=S64IntType;
        UIntType:=U64IntType;
        SIntType:=S64IntType;
{$endif cpu64bitaddr}
{$ifdef cpu32bitaddr}
        SizeUIntType:=U32IntType;
        SizeSIntType:=S32IntType;
        UIntType:=U32IntType;
        SIntType:=S32IntType;
{$endif cpu32bitaddr}
{$ifdef cpu32bitalu}
        UIntType:=U32IntType;
        SIntType:=S32IntType;
        ALUUIntType:=U32IntType;
        ALUSIntType:=S32IntType;
{$endif cpu32bitalu}




        OSUIntType:=UIntType;
        OSSIntType:=SIntType;
      end;


    procedure set_default_ptr_types;
      begin

        VoidCodePointerType:=VoidPointerType;
        VoidStackPointerType:=VoidPointerType;

        case VoidCodePointerType.Size of
          2:
            begin
              CodePtrUIntType:=U16IntType;
              CodePtrSIntType:=S16IntType;
            end;
          4:
            begin
              CodePtrUIntType:=U32IntType;
              CodePtrSIntType:=S32IntType;
            end;
          8:
            begin
              CodePtrUIntType:=U64IntType;
              CodePtrSIntType:=S64IntType;
            end;
          else
            InternalError(2015112106);
        end;
        case VoidPointerType.Size of
          2:
            begin
              PtrUIntType:=U16IntType;
              PtrSIntType:=S16IntType;
            end;
          4:
            begin
              PtrUIntType:=U32IntType;
              PtrSIntType:=S32IntType;
            end;
          8:
            begin
              PtrUIntType:=U64IntType;
              PtrSIntType:=S64IntType;
            end;
          else
            InternalError(2016100301);
        end;
      end;

    procedure create_intern_types;
      {
        all the types inserted into the system unit
      }

        function AddType(const s:string;def:TDef):TTypeSym;
        begin
          result:=CTypeSym.Create(s,def);
          SystemUnit.InsertSym(result);
        end;

        procedure AddField(recst:TAbstractRecordSymTable;sym:TFieldVarSym);
        begin
          recst.InsertSym(sym);
          recst.AddField(sym,vis_hidden);
        end;

        procedure create_fpu_types;
        begin
          S32FloatType:=CFloatDef.Create(S32Real,true);
          S64FloatType:=CFloatDef.Create(S64Real,true);
          S80FloatType:=CFloatDef.Create(s80real,true);
          SC80FloatType:=CFloatDef.Create(sc80real,true);
        end;

      var
        hrecst : TRecordSymTable;
	pvmt_name : shortstring;
      begin
        SymTableStack.push(SystemUnit);
        CUndefinedType:=CUndefinedDef.Create(true);
        CFormalType:=CFormalDef.Create(false);
        CTypedFormalType:=CFormalDef.Create(true);
        VoidType:=COrdDef.Create(uvoid,0,0,true);
        VoidPointerType:=CPointerDef.Create(VoidType);
        U8IntType:=COrdDef.Create(u8bit,0,255,true);
        S8IntType:=COrdDef.Create(s8bit,int64(-128),127,true);
        U16IntType:=COrdDef.Create(u16bit,0,65535,true);
        S16IntType:=COrdDef.Create(s16bit,int64(-32768),32767,true);
        S24IntType:=COrdDef.Create(customint,-(int64(1) shl 23),1 shl 23 - 1,true);
        U24IntType:=COrdDef.Create(customint,0,1 shl 24 - 1,true);
        U32IntType:=COrdDef.Create(u32bit,0,high(LongWord),true);
        S32IntType:=COrdDef.Create(s32bit,int64(low(LongInt)),int64(high(LongInt)),true);
        S40IntType:=COrdDef.Create(customint,-(int64(1) shl 39),int64(1) shl 39 - 1,true);
        U40IntType:=COrdDef.Create(customint,0,int64(1) shl 40 - 1,true);
        S48IntType:=COrdDef.Create(customint,-(int64(1) shl 47),int64(1) shl 47 - 1,true);
        U48IntType:=COrdDef.Create(customint,0,int64(1) shl 48 - 1,true);
        S56IntType:=COrdDef.Create(customint,-(int64(1) shl 55),int64(1) shl 55 - 1,true);
        U56IntType:=COrdDef.Create(customint,0,int64(1) shl 56 - 1,true);
        U64IntType:=COrdDef.Create(u64bit,low(qword),high(qword),true);
        S64IntType:=COrdDef.Create(s64bit,low(int64),high(int64),true);
        { upper/lower bound not yet properly set for 128 bit types, as we don't
          support them yet at the Pascal level (nor for tconstexprint); they're
          only used internally by the high level code generator for LLVM to
          implement overflow checking }
        U128IntType:=COrdDef.Create(u128bit,0,0,true);
        S128IntType:=COrdDef.Create(s128bit,0,0,true);
        PasBool1Type:=COrdDef.Create(pasbool1,0,1,true);
        PasBool8Type:=COrdDef.Create(pasbool8,0,1,true);
        PasBool16Type:=COrdDef.Create(pasbool16,0,1,true);
        PasBool32Type:=COrdDef.Create(pasbool32,0,1,true);
        PasBool64Type:=COrdDef.Create(pasbool64,0,1,true);
        Bool8Type:=COrdDef.Create(bool8bit,low(int64),high(int64),true);
        Bool16Type:=COrdDef.Create(bool16bit,low(int64),high(int64),true);
        Bool32Type:=COrdDef.Create(bool32bit,low(int64),high(int64),true);
        Bool64Type:=COrdDef.Create(bool64bit,low(int64),high(int64),true);

        CAnsiCharType:=COrdDef.Create(uchar,0,255,true);
        CWideCharType:=COrdDef.Create(uwidechar,0,65535,true);
        CShortStringType:=CStringDef.CreateShort(255,true);
        { should we give a length to the default long and ansi string definition ?? }
        CLongStringType:=CStringDef.CreateLong(-1,true);
        CAnsiStringType:=CStringDef.CreateAnsi(0,true);
        if TargetInfo.system in systems_windows then
          CWideStringType:=CStringDef.CreateWide(true)
        else
          CWideStringType:=CStringDef.CreateUnicode(true);
        CUnicodeStringType:=CStringDef.CreateUnicode(true);
        { length=0 for shortstring is open string (needed for readln(string) }
        OpenShortStringType:=CStringDef.CreateShort(0,true);
        pvmt_name:='pvmt';
 {$ifdef x86}
        create_fpu_types;
        if TargetInfo.system=system_x86_64_win64 then
          S64CurrencyType:=COrdDef.Create(scurrency,low(int64),high(int64),true)
        else
          S64CurrencyType:=CFloatDef.Create(s64currency,true);
{$endif x86}
{$ifdef aarch64}
        create_fpu_types;
        S64CurrencyType:=COrdDef.Create(scurrency,low(int64),high(int64),true);
{$endif aarch64}

        set_default_int_types;
        { some other definitions }
        CharPointerType:=CPointerDef.Create(CAnsiCharType);
        WideCharPointerType:=CPointerDef.Create(CWideCharType);

        ParentFPVoidPointerType:=CPointerDef.Create(VoidType);

{$ifdef x86}
        VoidNearPointerType:=TCPUPointerDefClass(CPointerDef).CreateX86(VoidType,x86pt_near);
        VoidNearCSPointerType:=TCPUPointerDefClass(CPointerDef).CreateX86(VoidType,x86pt_near_cs);
        VoidNearDSPointerType:=TCPUPointerDefClass(CPointerDef).CreateX86(VoidType,x86pt_near_ds);
        VoidNearSSPointerType:=TCPUPointerDefClass(CPointerDef).CreateX86(VoidType,x86pt_near_ss);
        VoidNearESPointerType:=TCPUPointerDefClass(CPointerDef).CreateX86(VoidType,x86pt_near_es);
        VoidNearFSPointerType:=TCPUPointerDefClass(CPointerDef).CreateX86(VoidType,x86pt_near_fs);
        VoidNearGSPointerType:=TCPUPointerDefClass(CPointerDef).CreateX86(VoidType,x86pt_near_gs);

        X86_M64Type:=CArrayDef.Create_Vector(0,1,S32IntType);
        X86_M128Type:=CArrayDef.Create_Vector(0,3,S32IntType);
        X86_M128DType:=CArrayDef.Create_Vector(0,1,S32IntType);
        X86_M128IType:=CArrayDef.Create_Vector(0,3,S32IntType);
        X86_M256Type:=CArrayDef.Create_Vector(0,7,S32IntType);
        X86_M256DType:=CArrayDef.Create_Vector(0,3,S32IntType);
        X86_M256IType:=CArrayDef.Create_Vector(0,7,S32IntType);

        TArrayDef(X86_M64Type).ElementDef:=S32FloatType;
        TArrayDef(X86_M128Type).ElementDef:=S32FloatType;
        TArrayDef(X86_M128DType).ElementDef:=S64FloatType;
        TArrayDef(X86_M128IType).ElementDef:=S32FloatType;
        TArrayDef(X86_M256Type).ElementDef:=S32FloatType;
        TArrayDef(X86_M256DType).ElementDef:=S64FloatType;
        TArrayDef(X86_M256IType).ElementDef:=S32FloatType;
{$endif x86}
        set_default_ptr_types;
        OpenCharArrayType:=CArrayDef.Create_OpenArray;
        TArrayDef(OpenCharArrayType).ElementDef:=CAnsiCharType;
        CFileType:=CFileDef.CreateUntyped;
        if f_variants in Features then
          begin
            CVariantType:=CVariantDef.Create(vt_normalvariant);
            COleVariantType:=CVariantDef.Create(vt_olevariant);
          end;

        AddType('Single',S32FloatType);
        AddType('Double',S64FloatType);
        { extended size is the best real type for the target }
        AddType('Extended',PBestRealType^);
        { CExtended corresponds to the C version of the Extended type
          (either "long double" or "double") }
        if TargetInfo.system in (systems_android+[system_x86_64_win64]) then
          { Microsoft C and Android x86 use Double at this boundary. }
          AddType('CExtended',S64FloatType)
        else
          if TFloatDef(PBestRealType^).FloatType=s80real then
            AddType('CExtended',SC80FloatType)
          else
            AddType('CExtended',PBestRealType^);
{$ifdef x86}
        if TargetInfo.system<>system_x86_64_win64 then
          AddType('Comp',CFloatDef.Create(s64comp,true));
{$endif x86}
        AddType('Currency',S64CurrencyType);
        AddType('Pointer',VoidPointerType);
{$ifdef x86}
        AddType('NearPointer',VoidNearPointerType);
        AddType('NearCsPointer',VoidNearCSPointerType);
        AddType('NearDsPointer',VoidNearDSPointerType);
        AddType('NearSsPointer',VoidNearSSPointerType);
        AddType('NearEsPointer',VoidNearESPointerType);
        AddType('NearFsPointer',VoidNearFSPointerType);
        AddType('NearGsPointer',VoidNearGSPointerType);

        AddType('__m64',X86_M64Type);
        AddType('__m128', X86_M128Type);
        AddType('__m128d',X86_M128DType);
        AddType('__m128i',X86_M128IType);
        AddType('__m256', X86_M256Type);
        AddType('__m256d',X86_M256DType);
        AddType('__m256i',X86_M256IType);
{$endif x86}
        AddType('ShortString',CShortStringType);
{$ifdef support_longstring}
        AddType('LongString',CLongStringType);
{$endif support_longstring}
        AddType('AnsiString',CAnsiStringType);
        AddType('WideString',CWideStringType);
        AddType('UnicodeString',CUnicodeStringType);

        AddType('OpenString',OpenShortStringType);
        AddType('Boolean',PasBool1Type);
        AddType('Boolean8',PasBool8Type);
        AddType('Boolean16',PasBool16Type);
        AddType('Boolean32',PasBool32Type);
        AddType('Boolean64',PasBool64Type);
        AddType('ByteBool',Bool8Type);
        AddType('WordBool',Bool16Type);
        AddType('LongBool',Bool32Type);
        AddType('QWordBool',Bool64Type);

        AddType('Byte',U8IntType);
        AddType('ShortInt',S8IntType);
        AddType('Word',U16IntType);
        AddType('SmallInt',S16IntType);
        AddType('LongWord',U32IntType);
        AddType('LongInt',S32IntType);
        AddType('QWord',U64IntType);
        AddType('Int64',S64IntType);
        AddType('AnsiChar',CAnsiCharType);
        AddType('WideChar',CWideCharType);
        AddType('Text',CFileDef.CreateText);
        AddType('TypedFile',CFileDef.CreateTyped(VoidType));
        if f_variants in Features then
          begin
            AddType('Variant',CVariantType);
            AddType('OleVariant',COleVariantType);
          end;
        { Internal types }
        AddType('$undefined',CUndefinedType);
        AddType('$formal',CFormalType);
        AddType('$typedformal',CTypedFormalType);
        AddType('$void',VoidType);
        AddType('$void_pointer',VoidPointerType);
        AddType('$byte',U8IntType);
        AddType('$shortint',S8IntType);
        AddType('$word',U16IntType);
        AddType('$smallint',S16IntType);
        AddType('$sint24',S24IntType);
        AddType('$uint24',U24IntType);
        AddType('$ulong',U32IntType);
        AddType('$longint',S32IntType);
        AddType('$sint40',S40IntType);
        AddType('$uint40',U40IntType);
        AddType('$sint48',S48IntType);
        AddType('$uint48',U48IntType);
        AddType('$sint56',S56IntType);
        AddType('$uint56',U56IntType);
        AddType('$qword',U64IntType);
        AddType('$int64',S64IntType);
        AddType('$uint128',U128IntType);
        AddType('$int128',S128IntType);
        AddType('$ansichar',CAnsiCharType);
        AddType('$widechar',CWideCharType);
        AddType('$shortstring',CShortStringType);
        AddType('$longstring',CLongStringType);
        AddType('$ansistring',CAnsiStringType);
        AddType('$widestring',CWideStringType);
        AddType('$unicodestring',CUnicodeStringType);
        AddType('$openshortstring',OpenShortStringType);
        AddType('$boolean',PasBool1Type);
        AddType('$boolean8',PasBool8Type);
        AddType('$boolean16',PasBool16Type);
        AddType('$boolean32',PasBool32Type);
        AddType('$boolean64',PasBool64Type);
        AddType('$bytebool',Bool8Type);
        AddType('$wordbool',Bool16Type);
        AddType('$longbool',Bool32Type);
        AddType('$qwordbool',Bool64Type);

        AddType('$char_pointer',CharPointerType);
        AddType('$widechar_pointer',WideCharPointerType);
        AddType('$parentfp_void_pointer',ParentFPVoidPointerType);
{$ifdef x86}
        AddType('$void_nearpointer',VoidNearPointerType);
        AddType('$void_nearcspointer',VoidNearCSPointerType);
        AddType('$void_neardspointer',VoidNearDSPointerType);
        AddType('$void_nearsspointer',VoidNearSSPointerType);
        AddType('$void_nearespointer',VoidNearESPointerType);
        AddType('$void_nearfspointer',VoidNearFSPointerType);
        AddType('$void_neargspointer',VoidNearGSPointerType);

        AddType('$__m64',  X86_M64Type);
        AddType('$__m128', X86_M128Type);
        AddType('$__m128d',X86_M128DType);
        AddType('$__m128i',X86_M128IType);
        AddType('$__m256', X86_M256Type);
        AddType('$__m256d',X86_M256DType);
        AddType('$__m256i',X86_M256IType);
{$endif x86}
        AddType('$openchararray',OpenCharArrayType);
        AddType('$file',CFileType);
        if f_variants in Features then
          begin
            AddType('$variant',CVariantType);
            AddType('$olevariant',COleVariantType);
          end;
        AddType('$s32real',S32FloatType);
        AddType('$s64real',S64FloatType);
        AddType('$s80real',S80FloatType);
        AddType('$sc80real',SC80FloatType);
        AddType('$s64currency',S64CurrencyType);
          begin
            { Add a type for virtual method tables }
            hrecst:=TRecordSymTable.Create('',CurrentSettings.PackRecords,CurrentSettings.Alignment.RecordAlignMin);
            VMTType:=CRecordDef.Create('',hrecst);
            PVMTType:=CPointerDef.Create(VMTType);
            { can't use addtype for pvmt because the rtti of the pointed
              type is not available. The rtti for pvmt will be written implicitly
              by thev tblarray below }
            SystemUnit.InsertSym(CTypeSym.Create('$'+pvmt_name,PVMTType));
            AddField(hrecst,CFieldVarSym.Create('$length',vs_value,SizeSIntType,[]));
            AddField(hrecst,CFieldVarSym.Create('$mlength',vs_value,SizeSIntType,[]));
            AddField(hrecst,CFieldVarSym.Create('$parent',vs_value,PVMTType,[]));
            { it seems vmttype is used both for TP objects and Delphi classes,
              so the next entry could either be the first virtual method (vm1)
              (object) or the class name (class). We can't easily create separate
              vtable formats for both, as gdb is hard coded to search for
              __vtbl_ptr_type in all cases (JM) }
            AddField(hrecst,CFieldVarSym.Create('$vm1_or_classname',vs_value,CPointerDef.Create(CShortStringType),[]));
            VMTArrayType:=CArrayDef.Create(0,0,S32IntType);
            TArrayDef(VMTArrayType).ElementDef:=VoidPointerType;
            AddField(hrecst,CFieldVarSym.Create('$__pfn',vs_value,VMTArrayType,[]));
            AddType('$__vtbl_ptr_type',VMTType);
            VMTArrayType:=CArrayDef.Create(0,1,S32IntType);
            TArrayDef(VMTArrayType).ElementDef:=PVMTType;
            AddType('$vtblarray',VMTArrayType);
          end;
        { Add a type for methodpointers }
        hrecst:=TRecordSymTable.Create('',1,CurrentSettings.Alignment.RecordAlignMin);
        AddField(hrecst,CFieldVarSym.Create('$proc',vs_value,VoidCodePointerType,[]));
        AddField(hrecst,CFieldVarSym.Create('$self',vs_value,VoidPointerType,[]));
        MethodPointerType:=CRecordDef.Create('',hrecst);
        AddType('$methodpointer',MethodPointerType);
        { Add a type for nested proc pointers }
        hrecst:=TRecordSymTable.Create('',1,CurrentSettings.Alignment.RecordAlignMin);
        AddField(hrecst,CFieldVarSym.Create('$proc',vs_value,VoidCodePointerType,[]));
        AddField(hrecst,CFieldVarSym.Create('$parentfp',vs_value,ParentFPVoidPointerType,[]));
        NestedProcPointerType:=CRecordDef.Create('',hrecst);
        AddType('$nestedprocpointer',NestedProcPointerType);
        SymTableStack.pop(SystemUnit);
      end;


    procedure load_intern_types;
      {
        Load all default definitions for consts from the system unit
      }

        procedure loadtype(const s:string;var def:TDef);
        var
          srsym : TTypeSym;
        begin
          srsym:=Search_System_Type(s);
          def:=srsym.TypeDef;
        end;

      var
        oldcurrentmodule : TModule;
        pvmt_name : shortstring;
      begin
        oldcurrentmodule:=CurrentModule;
        SetCurrentModule(nil);
        loadtype('byte',U8IntType);
        loadtype('shortint',S8IntType);
        loadtype('word',U16IntType);
        loadtype('smallint',S16IntType);
        loadtype('uint24',U24IntType);
        loadtype('sint24',S24IntType);
        loadtype('ulong',U32IntType);
        loadtype('longint',S32IntType);
        loadtype('uint40',U40IntType);
        loadtype('sint40',S40IntType);
        loadtype('uint48',U48IntType);
        loadtype('sint48',S48IntType);
        loadtype('uint56',U56IntType);
        loadtype('sint56',S56IntType);
        loadtype('qword',U64IntType);
        loadtype('int64',S64IntType);
        loadtype('uint128',U128IntType);
        loadtype('int128',S128IntType);
        loadtype('undefined',CUndefinedType);
        loadtype('formal',CFormalType);
        loadtype('typedformal',CTypedFormalType);
        loadtype('void',VoidType);
        loadtype('void_pointer',VoidPointerType);
        loadtype('ansichar',CAnsiCharType);
        loadtype('widechar',CWideCharType);
        loadtype('shortstring',CShortStringType);
        loadtype('longstring',CLongStringType);
        loadtype('ansistring',CAnsiStringType);
        loadtype('widestring',CWideStringType);
        loadtype('unicodestring',CUnicodeStringType);
        loadtype('openshortstring',OpenShortStringType);
        loadtype('openchararray',OpenCharArrayType);
        loadtype('s32real',S32FloatType);
        loadtype('s64real',S64FloatType);
        loadtype('s80real',S80FloatType);
        loadtype('sc80real',SC80FloatType);
        loadtype('s64currency',S64CurrencyType);
        loadtype('boolean',PasBool1Type);
        loadtype('boolean8',PasBool8Type);
        loadtype('boolean16',PasBool16Type);
        loadtype('boolean32',PasBool32Type);
        loadtype('boolean64',PasBool64Type);
        loadtype('bytebool',Bool8Type);
        loadtype('wordbool',Bool16Type);
        loadtype('longbool',Bool32Type);
        loadtype('qwordbool',Bool64Type);
        loadtype('char_pointer',CharPointerType);
        loadtype('widechar_pointer',WideCharPointerType);
        loadtype('parentfp_void_pointer',ParentFPVoidPointerType);
{$ifdef x86}
        loadtype('void_nearpointer',VoidNearPointerType);
        loadtype('void_nearcspointer',VoidNearCSPointerType);
        loadtype('void_neardspointer',VoidNearDSPointerType);
        loadtype('void_nearsspointer',VoidNearSSPointerType);
        loadtype('void_nearespointer',VoidNearESPointerType);
        loadtype('void_nearfspointer',VoidNearFSPointerType);
        loadtype('void_neargspointer',VoidNearGSPointerType);

        loadtype('__m64',  X86_M64Type);
        loadtype('__m128', X86_M128Type);
        loadtype('__m128d',X86_M128DType);
        loadtype('__m128i',X86_M128IType);
        loadtype('__m256', X86_M256Type);
        loadtype('__m256d',X86_M256DType);
        loadtype('__m256i',X86_M256IType);
{$endif x86}

        loadtype('file',CFileType);
        pvmt_name:='pvmt';
        loadtype(pvmt_name,PVMTType);
        loadtype('vtblarray',VMTArrayType);
        loadtype('__vtbl_ptr_type',VMTType);
        if f_variants in Features then
          begin
            loadtype('variant',CVariantType);
            loadtype('olevariant',COleVariantType);
          end;
        loadtype('methodpointer',MethodPointerType);
        loadtype('nestedprocpointer',NestedProcPointerType);
        loadtype('HRESULT',HResultDef);
        loadtype('TTYPEKIND',TypeKindType);
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
        NodeClass[addn]:=CAddNode;
        NodeClass[muln]:=CAddNode;
        NodeClass[subn]:=CAddNode;
        NodeClass[divn]:=CModDivNode;
        NodeClass[symdifn]:=CAddNode;
        NodeClass[modn]:=CModDivNode;
        NodeClass[assignn]:=CAssignmentNode;
        NodeClass[loadn]:=CLoadNode;
        NodeClass[rangen]:=CRangeNode;
        NodeClass[ltn]:=CAddNode;
        NodeClass[lten]:=CAddNode;
        NodeClass[gtn]:=CAddNode;
        NodeClass[gten]:=CAddNode;
        NodeClass[EqualN]:=CAddNode;
        NodeClass[unequaln]:=CAddNode;
        NodeClass[inn]:=CInNode;
        NodeClass[orn]:=CAddNode;
        NodeClass[xorn]:=CAddNode;
        NodeClass[shrn]:=CShlShrNode;
        NodeClass[shln]:=CShlShrNode;
        NodeClass[slashn]:=CAddNode;
        NodeClass[andn]:=CAddNode;
        NodeClass[subscriptn]:=CSubscriptNode;
        NodeClass[derefn]:=CDerefNode;
        NodeClass[addrn]:=CAddrNode;
        NodeClass[ordconstn]:=COrdConstNode;
        NodeClass[typeconvn]:=CTypeConvNode;
        NodeClass[calln]:=CCallNode;
        NodeClass[callparan]:=CCallParaNode;
        NodeClass[realconstn]:=CRealConstNode;
        NodeClass[unaryminusn]:=CUnaryMinusNode;
        NodeClass[unaryplusn]:=CUnaryPlusNode;
        NodeClass[asmn]:=CAsmNode;
        NodeClass[vecn]:=CVecNode;
        NodeClass[pointerconstn]:=CPointerConstNode;
        NodeClass[stringconstn]:=CStringConstNode;
        NodeClass[notn]:=CNotNode;
        NodeClass[inlinen]:=CInlineNode;
        NodeClass[niln]:=CNilNode;
        NodeClass[errorn]:=CErrorNode;
        NodeClass[typen]:=CTypeNode;
        NodeClass[setelementn]:=CSetElementNode;
        NodeClass[setconstn]:=CSetConstNode;
        NodeClass[blockn]:=CBlockNode;
        NodeClass[statementn]:=CStatementNode;
        NodeClass[ifn]:=CIfNode;
        NodeClass[breakn]:=CBreakNode;
        NodeClass[continuen]:=CContinueNode;
        NodeClass[whilerepeatn]:=CWhileRepeatNode;
        NodeClass[forn]:=CForNode;
        NodeClass[exitn]:=CExitNode;
        NodeClass[casen]:=CCaseNode;
        NodeClass[labeln]:=CLabelNode;
        NodeClass[goton]:=CGotoNode;
        NodeClass[tryexceptn]:=CTryExceptNode;
        NodeClass[raisen]:=CRaiseNode;
        NodeClass[tryfinallyn]:=CTryFinallyNode;
        NodeClass[onn]:=COnNode;
        NodeClass[isn]:=CIsNode;
        NodeClass[asn]:=CAsNode;
        NodeClass[starstarn]:=CAddNode;
        NodeClass[arrayconstructorn]:=CArrayConstructorNode;
        NodeClass[arrayconstructorrangen]:=CArrayConstructorRangeNode;
        NodeClass[tempcreaten]:=CTempCreateNode;
        NodeClass[temprefn]:=CTempRefNode;
        NodeClass[tempdeleten]:=CTempDeleteNode;
        NodeClass[addoptn]:=CAddNode;
        NodeClass[nothingn]:=CNothingNode;
        NodeClass[loadvmtaddrn]:=CLoadVMTAddrNode;
        NodeClass[guidconstn]:=CGUIDConstNode;
        NodeClass[rttin]:=CRTTINode;
        NodeClass[loadparentfpn]:=CLoadParentFPNode;
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
