{
    Copyright (c) 1998-2006 by Florian Klaempfl

    This unit provides some help routines for type handling

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
unit defutil;

{$i fpcdefs.inc}

interface

    uses
       GlobType,Globals,ConstExp,
       symconst,symtype,symdef,
       cgbase,cpubase;

    type
       TMMXType = (mmxno,mmxu8bit,mmxs8bit,mmxu16bit,mmxs16bit,
                   mmxu32bit,mmxs32bit,mmxfixed16,mmxsingle,mmxs64bit,mmxu64bit);


{*****************************************************************************
                          Basic type functions
 *****************************************************************************}

    {# Returns true, if definition defines an ordinal type }
    function is_ordinal(def : TDef) : boolean;

    {# Returns true, if definition defines a string type }
    function is_string(def : TDef): boolean;

    {# Returns True, if definition defines a type that behaves like a string,
       namely that can be joined and compared with another string-like type }
    function is_stringlike(def : TDef) : boolean;

    {# Returns the typedef for the char type that matches the stringlike }
    function chartype_for_stringlike(def : TDef) : TDef;

    {# Returns True, if definition defines an enumeration type }
    function is_enum(def : TDef) : boolean;

    {# Returns True, if definition defines a set type }
    function is_set(def : TDef) : boolean;

    {# Returns the minimal integer value of the type }
    function get_min_value(def : TDef) : TConstExprInt;

    {# Returns the maximal integer value of the type }
    function get_max_value(def : TDef) : TConstExprInt;

    {# Returns basetype of the specified integer range }
    function range_to_basetype(const l,h:TConstExprInt):TOrdType;

    procedure range_to_type(const l,h:TConstExprInt;var def:TDef);

    procedure int_to_type(const v:TConstExprInt;var def:TDef);

    {# Return true if the type (orddef or enumdef) spans its entire bitrange }
    function spans_entire_range(def: TDef): boolean;

    {# Returns true, if definition defines an integer type }
    function is_integer(def : TDef) : boolean;

    {# Returns true if definition is a boolean }
    function is_boolean(def : TDef) : boolean;

    {# Returns true if definition is a Pascal-style boolean (1 = true, zero = false) }
    function is_pasbool(def : TDef) : boolean;

    {# Returns true if definition is a C-style boolean (non-zero value = true, zero = false) }
    function is_cbool(def : TDef) : boolean;

    {# Returns true if definition is a char

       This excludes the unicode char.
    }
    function is_char(def : TDef) : boolean;

    {# Returns true if definition is a widechar }
    function is_widechar(def : TDef) : boolean;

    {# Returns true if definition is either an AnsiChar or a WideChar }
    function is_anychar(def : TDef) : boolean;

    {# Returns true if definition is a void}
    function is_void(def : TDef) : boolean;

    {# Returns true if definition is a smallset}
    function is_smallset(p : TDef) : boolean;

    {# Returns true, if def defines a signed data type
       (only for ordinal types)
    }
    function is_signed(def : TDef) : boolean;

    {# Returns an unsigned integer type of the same size as def; def must be
       an ordinal or enum }
    function get_unsigned_inttype(def: TDef): TOrdDef;

    {# Returns a signed integer type of the same size as def; def must be
       an ordinal or enum }
    function get_signed_inttype(def: TDef): TOrdDef;

    {# Returns whether def_from's range is comprised in def_to's if both are
      orddefs, false otherwise                                              }
    function is_in_limit(def_from,def_to : TDef) : boolean;

    {# Returns whether def is reference counted }
    function is_managed_type(def: TDef) : boolean;{$ifdef USEINLINE}inline;{$endif}

    { # Returns whether def is needs to load RTTI for reference counting }
    function is_rtti_managed_type(def: TDef) : boolean;

{    function is_in_limit_value(val_from:TConstExprInt;def_from,def_to : tdef) : boolean;}

{*****************************************************************************
                              Array helper functions
 *****************************************************************************}

    {# Returns true, if p points to a zero based (non special like open or
      dynamic array def).

      This is mainly used to see if the array
      is convertable to a pointer
    }
    function is_zero_based_array(p : TDef) : boolean;

    {# Returns true if p points to an open array definition }
    function is_open_array(p : TDef) : boolean;

    {# Returns true if p points to a dynamic array definition }
    function is_dynamic_array(p : TDef) : boolean;

    {# Returns true, if p points to an array of const definition }
    function is_array_constructor(p : TDef) : boolean;

    {# Returns true, if p points to a variant array }
    function is_variant_array(p : TDef) : boolean;

    {# Returns true, if p points to an array of const }
    function is_array_of_const(p : TDef) : boolean;

    {# Returns true if p is an arraydef that describes a constant string }
    function is_conststring_array(p : TDef) : boolean;

    {# Returns true, if p points any kind of special array

       That is if the array is an open array, a variant
       array, an array constants constructor, or an
       array of const.

       Bitpacked arrays aren't special in this regard though.
    }
    function is_special_array(p : TDef) : boolean;

    {# Returns true, if p points to a normal array, bitpacked arrays are included }
    function is_normal_array(p : TDef) : boolean;

    {# Returns true if p is a bitpacked array }
    function is_packed_array(p: TDef) : boolean;

    {# Returns true if p is a bitpacked record }
    function is_packed_record_or_object(p: TDef) : boolean;

    {# Returns true if p is a char array def }
    function is_chararray(p : TDef) : boolean;

    {# Returns true if p is a wide char array def }
    function is_widechararray(p : TDef) : boolean;

    {# Returns true if p is a open char array def }
    function is_open_chararray(p : TDef) : boolean;

    {# Returns true if p is a open wide char array def }
    function is_open_widechararray(p : TDef) : boolean;

{*****************************************************************************
                          String helper functions
 *****************************************************************************}

    {# Returns true if p points to an open string type }
    function is_open_string(p : TDef) : boolean;

    {# Returns true if p is an ansi string type }
    function is_ansistring(p : TDef) : boolean;

    {# Returns true if p is an ansi string type with codepage 0 }
    function is_rawbytestring(p : TDef) : boolean;

    {# Returns true if p is a long string type }
    function is_longstring(p : TDef) : boolean;

    {# returns true if p is a wide string type }
    function is_widestring(p : TDef) : boolean;

    {# true if p is an unicode string def }
    function is_unicodestring(p : TDef) : boolean;

    {# true if p is an unicode/wide/ansistring string def }
    function is_dynamicstring(p : TDef) : boolean;

    {# returns true if p is a wide or unicode string type }
    function is_wide_or_unicode_string(p : TDef) : boolean;

    {# Returns true if p is a short string type }
    function is_shortstring(p : TDef) : boolean;

    {# Returns true if p is any pointer def }
    function is_pointer(p : TDef) : boolean;

    {# Returns true p is an address: pointer, classref, ansistring, ... }
    function is_address(p : TDef) : boolean;

    {# Returns true if p is a pchar def }
    function is_pchar(p : TDef) : boolean;

    {# Returns true if p is a pwidechar def }
    function is_pwidechar(p : TDef) : boolean;

    {# Returns true if p is a voidpointer def }
    function is_voidpointer(p : TDef) : boolean;

    {# Returns true if p is a cyclic reference (refers to itself at some point via pointer or array) }
    function is_cyclic(p : TDef): Boolean; {$ifdef USEINLINE}inline;{$endif USEINLINE}

    {# Returns true, if definition is a float }
    function is_fpu(def : TDef) : boolean;

    {# Returns true, if def is a currency type }
    function is_currency(def : TDef) : boolean;

    {# Returns true, if def is a comp type (handled by the fpu) }
    function is_fpucomp(def : TDef) : boolean;

    {# Returns true, if def is a single type }
    function is_single(def : TDef) : boolean;

    {# Returns true, if def is a double type }
    function is_double(def : TDef) : boolean;

    {# Returns true, if def is an extended type }
    function is_extended(def : TDef) : boolean;

    {# Returns true, if definition is a "real" real (i.e. single/double/extended) }
    function is_real(def : TDef) : boolean;

    {# Returns true for single,double,extended and cextended }
    function is_real_or_cextended(def : TDef) : boolean;

    { true, if def is a 8 bit int type }
    function is_8bitint(def : TDef) : boolean;

    { true, if def is a 8 bit ordinal type }
    function is_8bit(def : TDef) : boolean;

    { true, if def is a 16 bit int type }
    function is_16bitint(def : TDef) : boolean;

    { true, if def is a 16 bit ordinal type }
    function is_16bit(def : TDef) : boolean;

    {# Returns true, if def is a 32 bit integer type }
    function is_32bitint(def : TDef) : boolean;

    {# Returns true, if def is a 32 bit ordinal type }
    function is_32bit(def : TDef) : boolean;

    {# Returns true, if def is a 64 bit integer type }
    function is_64bitint(def : TDef) : boolean;

    {# Returns true, if def is a 64 bit signed integer type }
    function is_s64bitint(def : TDef) : boolean;

    {# Returns true, if def is a qword type }
    function is_u64bitint(def : TDef) : boolean;

    {# Returns true, if def is a 64 bit ordinal type }
    function is_64bit(def : TDef) : boolean;

    { returns true, if def is a longint type }
    function is_s32bitint(def : TDef) : boolean;

    { returns true, if def is a dword type }
    function is_u32bitint(def : TDef) : boolean;

    { true, if def1 and def2 are both integers of the same bit size and sign }
    function are_equal_ints(def1, def2: TDef): boolean;

    { true, if def is an int type, larger than the processor's native int size }
    function is_oversizedint(def : TDef) : boolean;

    { true, if def is an ordinal type, larger than the processor's native int size }
    function is_oversizedord(def : TDef) : boolean;

    { true, if def is an int type, equal in size to the processor's native int size }
    function is_nativeint(def : TDef) : boolean;

    { true, if def is an ordinal type, equal in size to the processor's native int size }
    function is_nativeord(def : TDef) : boolean;

    { true, if def is an unsigned int type, equal in size to the processor's native int size }
    function is_nativeuint(def : TDef) : boolean;

    { true, if def is a signed int type, equal in size to the processor's native int size }
    function is_nativesint(def : TDef) : boolean;

    { true, if the char type is a widechar in the system unit }
    function is_systemunit_unicode : boolean;

  type
    TPerformRangeCheck = (
      rc_internal,  { nothing, internal conversion }
      rc_explicit,  { no, but this is an explicit user conversion and hence can still give warnings in some cases (or errors in case of enums) }
      rc_implicit,  { no, but this is an implicit conversion and hence can still give warnings/errors in some cases }
      rc_yes        { yes }
    );
    {# If @var(l) isn't in the range of todef a range check error (if not explicit) is generated and
      the value is placed within the range
    }
    procedure adaptrange(todef : TDef;var l : TConstExprInt; rangecheck: TPerformRangeCheck);
    { for when used with nf_explicit/nf_internal/cs_check_range nodeflags }
    procedure adaptrange(todef : TDef;var l : TConstExprInt; internal, explicit, rangecheckstate: boolean);

    {# Returns the range of def, where @var(l) is the low-range and @var(h) is
      the high-range.
    }
    procedure getrange(def : TDef;out l, h : TConstExprInt);
    procedure getrangedefmasksize(def: TDef; out rangedef: TDef; out mask: TConstExprInt; out size: LongInt);

    { Returns the range type of an ordinal type in the sense of ISO-10206 }
    function get_iso_range_type(def: TDef): TDef;

    { is the type a vector, or can it be transparently used as one? }
    function is_vector(p : TDef) : boolean;

    { return a real/hardware vectordef representing this def }
    function to_hwvectordef(p: TDef; nil_on_error: boolean): TDef;

    { some type helper routines for MMX support }
    function is_mmx_able_array(p : TDef) : boolean;

    {# returns the mmx type }
    function mmx_type(p : TDef) : TMMXType;

    { returns if the passed type (array) fits into an mm register }
    function fits_in_mm_register(p : TDef) : boolean;

    {# From a definition return the abstract code generator size enum. It is
       to note that the value returned can be @var(OS_NO) }
    function def_cgsize(def: TDef): TCgSize;

    { #Return an orddef (integer) corresponding to a tcgsize }
    function cgsize_orddef(size: TCgSize): TOrdDef;

    {# Same as def_cgsize, except that it will interpret certain arrays as
       vectors and return OS_M* sizes for them }
    function def_cgmmsize(def: TDef): TCgSize;

    {# returns true, if the type passed is can be used with windows automation }
    function is_automatable(p : TDef) : boolean;

    { # returns true if the procdef has no parameters and no specified return type }
    function is_bareprocdef(pd : TProcDef): boolean;

    { returns true if the procdef is a C-style variadic function }
    function is_c_variadic(pd: TAbstractProcDef): boolean; {$ifdef USEINLINE}inline;{$endif}

    { # returns the smallest base integer type whose range encompasses that of
        both ld and rd; if keep_sign_if_equal, then if ld and rd have the same
        signedness, the result will also get that signedness }
    function get_common_intdef(ld, rd: TOrdDef; keep_sign_if_equal: boolean): TOrdDef;

    { # calculates "not v" based on the provided def; returns true if the def
        was negligible, false otherwise }
    function calc_not_ordvalue(var v:TConstExprInt; var def:TDef):boolean;

    { # returns whether the type is potentially a valid type of/for an "univ" parameter
        (basically: it must have a compile-time size) }
    function is_valid_univ_para_type(def: TDef): boolean;

    { # returns whether the procdef/procvardef represents a nested procedure
        or not }
    function is_nested_pd(def: TAbstractProcDef): boolean;{$ifdef USEINLINE}inline;{$endif}

    { # returns whether def is a type parameter of a generic }
    function is_typeparam(def : TDef) : boolean;{$ifdef USEINLINE}inline;{$endif}

    { returns true of def is a methodpointer }
    function is_methodpointer(def : TDef) : boolean;

    { returns true if def is a function reference }
    function is_funcref(def:TDef):boolean;

    { returns true if def is an invokable interface }
    function is_invokable(def:TDef):boolean;

    { returns true if def is a C "block" }
    function is_block(def: TDef): boolean;

    { returns the TTypeKind value of the def }
    function get_typekind(def: TDef): byte;

    { returns the Invoke procdef of a function reference interface }
    function get_invoke_procdef(def:TObjectDef):TProcDef;

    { returns whether the invokable has an Invoke overload that can be called
      without arguments }
    function invokable_has_argless_invoke(def:TObjectDef):boolean;

implementation

    uses
       Verbose,CUtils,
       SymTable, // search_system_type
       SymSym,
       CPUInfo;

    { returns true, if def uses FPU }
    function is_fpu(def : TDef) : boolean;
      begin
         is_fpu:=(def.typ=floatdef);
      end;


    { returns true, if def is a currency type }
    function is_currency(def : TDef) : boolean;
      begin
         if not Assigned(def) then
           begin
             result:=False;
             Exit;
           end;

         case s64currencytype.typ of
           orddef :
             result:=(def.typ=orddef) and
                     (TOrdDef(s64currencytype).ordtype=TOrdDef(def).ordtype);
           floatdef :
             result:=(def.typ=floatdef) and
                     (TFloatDef(s64currencytype).floattype=TFloatDef(def).floattype);
           else
             InternalError(200304222);
         end;
      end;


    function is_fpucomp(def: TDef): boolean;
      begin
        result:=(def.typ=floatdef) and
           (TFloatDef(def).floattype=s64comp);
      end;

    { returns true, if def is a single type }
    function is_single(def : TDef) : boolean;
      begin
        result:=(def.typ=floatdef) and
          (TFloatDef(def).floattype=S32Real);
      end;


    { returns true, if def is a double type }
    function is_double(def : TDef) : boolean;
      begin
        result:=(def.typ=floatdef) and
          (TFloatDef(def).floattype=S64Real);
      end;


    { returns true, if def is an extended type }
    function is_extended(def : TDef) : boolean;
      begin
        result:=(def.typ=floatdef) and
          (TFloatDef(def).floattype in [s80real,sc80real]);
      end;


    { returns true, if definition is a "real" real (i.e. single/double/extended) }
    function is_real(def : TDef) : boolean;
      begin
        result:=(def.typ=floatdef) and
          (TFloatDef(def).floattype in [S32Real,S64Real,s80real]);
      end;


    function is_real_or_cextended(def: TDef): boolean;
      begin
        result:=(def.typ=floatdef) and
          (TFloatDef(def).floattype in [S32Real,S64Real,s80real,sc80real]);
      end;


    function range_to_basetype(const l,h:TConstExprInt):TOrdType;
      begin
        { prefer signed over unsigned }
        if (l>=int64(-128)) and (h<=127) then
         range_to_basetype:=s8bit
        else if (l>=0) and (h<=255) then
         range_to_basetype:=u8bit
        else if (l>=int64(-32768)) and (h<=32767) then
         range_to_basetype:=s16bit
        else if (l>=0) and (h<=65535) then
         range_to_basetype:=u16bit
        else if (l>=int64(low(LongInt))) and (h<=high(LongInt)) then
         range_to_basetype:=s32bit
        else if (l>=low(cardinal)) and (h<=high(cardinal)) then
         range_to_basetype:=u32bit
        else if (l>=low(int64)) and (h<=high(int64)) then
         range_to_basetype:=s64bit
        else
         range_to_basetype:=u64bit;
      end;


    procedure range_to_type(const l,h:TConstExprInt;var def:TDef);
      begin
        { prefer signed over unsigned }
        if (l>=int64(-128)) and (h<=127) then
         def:=s8inttype
        else if (l>=0) and (h<=255) then
         def:=u8inttype
        else if (l>=int64(-32768)) and (h<=32767) then
         def:=s16inttype
        else if (l>=0) and (h<=65535) then
         def:=u16inttype
        else if (l>=int64(low(LongInt))) and (h<=high(LongInt)) then
         def:=s32inttype
        else if (l>=low(cardinal)) and (h<=high(cardinal)) then
         def:=u32inttype
        else if (l>=low(int64)) and (h<=high(int64)) then
         def:=s64inttype
        else
         def:=u64inttype;
      end;


    procedure int_to_type(const v:TConstExprInt;var def:TDef);
      begin
        range_to_type(v,v,def);
      end;


    { true if p is an ordinal }
    function is_ordinal(def : TDef) : boolean;
      var
         dt : TOrdType;
      begin
         case def.typ of
           orddef :
             begin
               dt:=TOrdDef(def).ordtype;
               is_ordinal:=dt in [uchar,uwidechar,
                                  u8bit,u16bit,u32bit,u64bit,
                                  s8bit,s16bit,s32bit,s64bit,
                                  pasbool1,pasbool8,pasbool16,pasbool32,pasbool64,
                                  bool8bit,bool16bit,bool32bit,bool64bit,customint];
             end;
           enumdef :
             is_ordinal:=true;
           else
             is_ordinal:=false;
         end;
      end;

    { true if p is a string }
    function is_string(def : TDef) : boolean;
      begin
        is_string := (Assigned(def) and (def.typ = stringdef));
      end;

    function is_stringlike(def : TDef) : boolean;
      begin
        result := is_string(def) or
                  is_anychar(def) or
                  is_pchar(def) or
                  is_pwidechar(def) or
                  is_chararray(def) or
                  is_widechararray(def) or
                  is_open_chararray(def) or
                  is_open_widechararray(def);
      end;

    function chartype_for_stringlike(def : TDef) : TDef;
      begin
        if is_string(def) then
          result:=TStringDef(def).get_default_char_type
        else if is_anychar(def) then
          result:=def
        else if is_pchar(def) or is_chararray(def) or is_open_chararray(def) then
          result:=cansichartype
        else if is_pwidechar(def) or is_pwidechar(def) or is_open_widechararray(def) then
          result:=cwidechartype
        else
          InternalError(2023012501);
      end;

    function is_enum(def : TDef) : boolean;
      begin
        result:=def.typ=enumdef;
      end;

    function is_set(def : TDef) : boolean;
      begin
        result:=def.typ=setdef;
      end;

    { returns the min. value of the type }
    function get_min_value(def : TDef) : TConstExprInt;
      begin
         case def.typ of
           orddef:
             result:=TOrdDef(def).low;
           enumdef:
             result:=int64(TEnumDef(def).min);
           else
             result:=0;
         end;
      end;


    { returns the max. value of the type }
    function get_max_value(def : TDef) : TConstExprInt;
      begin
         case def.typ of
           orddef:
             result:=TOrdDef(def).high;
           enumdef:
             result:=TEnumDef(def).max;
           else
             result:=0;
         end;
      end;


    function spans_entire_range(def: TDef): boolean;
      var
         lv, hv: TConstExprInt;
         mask: qword;
         size: LongInt;
      begin
        case def.typ of
          orddef,
          enumdef:
            getrange(def,lv,hv);
          else
            InternalError(2019062203);
        end;
        size:=def.size;
        case size of
          1: mask:=$ff;
          2: mask:=$ffff;
          4: mask:=$ffffffff;
          8: mask:=qword(-1);
          else
            InternalError(2019062204);
        end;
        result:=false;
        if is_signed(def) then
          begin
            if (lv.uvalue and mask)<>(qword(1) shl (size*8-1)) then
              exit;
            if (hv.uvalue and mask)<>(mask shr 1) then
              exit;
          end
        else
          begin
            if lv<>0 then
              exit;
            if hv.uvalue<>mask then
              exit;
          end;
        result:=true;
      end;


    { true if p is an integer }
    function is_integer(def : TDef) : boolean;
      begin
        result:=(def.typ=orddef) and
                    (TOrdDef(def).ordtype in [u8bit,u16bit,u32bit,u64bit,
                                          s8bit,s16bit,s32bit,s64bit,
                                          customint]);
      end;


    { true if p is a boolean }
    function is_boolean(def : TDef) : boolean;
      begin
        result:=(def.typ=orddef) and
                    (TOrdDef(def).ordtype in [pasbool1,pasbool8,pasbool16,pasbool32,pasbool64,bool8bit,bool16bit,bool32bit,bool64bit]);
      end;


    function is_pasbool(def : TDef) : boolean;
      begin
        result:=(def.typ=orddef) and
                    (TOrdDef(def).ordtype in [pasbool1,pasbool8,pasbool16,pasbool32,pasbool64]);
      end;

    { true if def is a C-style boolean (non-zero value = true, zero = false) }
    function is_cbool(def : TDef) : boolean;
      begin
        result:=(def.typ=orddef) and
                    (TOrdDef(def).ordtype in [bool8bit,bool16bit,bool32bit,bool64bit]);
      end;


    { true if p is a void }
    function is_void(def : TDef) : boolean;
      begin
        result:=(def.typ=orddef) and
                 (TOrdDef(def).ordtype=uvoid);
      end;


    { true if p is a char }
    function is_char(def : TDef) : boolean;
      begin
        result:=(def.typ=orddef) and
                 (TOrdDef(def).ordtype=uchar);
      end;


    { true if p is a wchar }
    function is_widechar(def : TDef) : boolean;
      begin
        result:=(def.typ=orddef) and
                 (TOrdDef(def).ordtype=uwidechar);
      end;


    { true if p is a char or wchar }
    function is_anychar(def : TDef) : boolean;
      begin
        result:=(def.typ=orddef) and
                 (TOrdDef(def).ordtype in [uchar,uwidechar])
      end;


    { true if p is signed (integer) }
    function is_signed(def : TDef) : boolean;
      begin
         case def.typ of
           orddef :
             result:=TOrdDef(def).low < 0;
           enumdef :
             result:=TEnumDef(def).min < 0;
           arraydef :
             result:=is_signed(TArrayDef(def).rangedef);
           else
             result:=false;
         end;
      end;


    function get_unsigned_inttype(def: TDef): TOrdDef;
      begin
        case def.typ of
          orddef,
          enumdef:
            result:=cgsize_orddef(tcgsize2unsigned[def_cgsize(def)]);
          else
            InternalError(2016062001);
        end;
      end;


    function get_signed_inttype(def: TDef): TOrdDef;
      begin
        case def.typ of
          orddef,
          enumdef:
            result:=cgsize_orddef(tcgsize2signed[def_cgsize(def)]);
          else
            InternalError(2022093007);
        end;
      end;


    function is_in_limit(def_from,def_to : TDef) : boolean;

      begin
         if (def_from.typ<>def_to.typ) or
            not(def_from.typ in [orddef,enumdef,setdef]) then
           begin
             is_in_limit := false;
             exit;
           end;
         case def_from.typ of
           orddef:
             is_in_limit:=(TOrdDef(def_from).low>=TOrdDef(def_to).low) and
                          (TOrdDef(def_from).high<=TOrdDef(def_to).high);
           enumdef:
             is_in_limit:=(TEnumDef(def_from).min>=TEnumDef(def_to).min) and
                          (TEnumDef(def_from).max<=TEnumDef(def_to).max);
           setdef:
             is_in_limit:=(TSetDef(def_from).setlow>=TSetDef(def_to).setlow) and
                          (TSetDef(def_from).setmax<=TSetDef(def_to).setmax);
         else
           is_in_limit:=false;
         end;
      end;


    function is_managed_type(def: TDef): boolean;{$ifdef USEINLINE}inline;{$endif}
      begin
        result:=def.NeedsInitTable;
      end;


    function is_rtti_managed_type(def: TDef): boolean;
      begin
        result:=def.NeedsInitTable and not (
          is_interfacecom_or_dispinterface(def) or
          (def.typ=variantdef) or
          (
            (def.typ=stringdef) and
            (TStringDef(def).stringtype in [st_ansistring,st_widestring,st_unicodestring])
          )
        );
      end;


    { true, if p points to an open array def }
    function is_open_string(p : TDef) : boolean;
      begin
         is_open_string:=(p.typ=stringdef) and
                         (TStringDef(p).stringtype=st_shortstring) and
                         (TStringDef(p).len=0);
      end;


    { true, if p points to a zero based array def }
    function is_zero_based_array(p : TDef) : boolean;
      begin
         result:=(p.typ=arraydef) and
                 (TArrayDef(p).lowrange=0) and
                 not(is_special_array(p));
      end;

    { true if p points to a dynamic array def }
    function is_dynamic_array(p : TDef) : boolean;
      begin
         result:=(p.typ=arraydef) and
                 (ado_IsDynamicArray in TArrayDef(p).arrayoptions);
      end;


    { true, if p points to an open array def }
    function is_open_array(p : TDef) : boolean;
      begin
         { check for sizesinttype is needed, because for unsigned the high
           range is also -1 ! (PFV) }
         result:=(p.typ=arraydef) and
                 (TArrayDef(p).rangedef=sizesinttype) and
                 (ado_OpenArray in TArrayDef(p).arrayoptions) and
                 ((TArrayDef(p).arrayoptions * [ado_IsVariant,ado_IsArrayOfConst,ado_IsConstructor,ado_IsDynamicArray])=[]);
      end;

    { true, if p points to an array of const def }
    function is_array_constructor(p : TDef) : boolean;
      begin
         result:=(p.typ=arraydef) and
                 (ado_IsConstructor in TArrayDef(p).arrayoptions);
      end;

    { true, if p points to a variant array }
    function is_variant_array(p : TDef) : boolean;
      begin
         result:=(p.typ=arraydef) and
                 (ado_IsVariant in TArrayDef(p).arrayoptions);
      end;

    { true, if p points to an array of const }
    function is_array_of_const(p : TDef) : boolean;
      begin
         result:=(p.typ=arraydef) and
                 (ado_IsArrayOfConst in TArrayDef(p).arrayoptions) and
                 { consider it an array-of-const in the strict sense only if it
                   isn't an array constructor }
                 not (ado_IsConstructor in TArrayDef(p).arrayoptions);
      end;

    function is_conststring_array(p: TDef): boolean;
      begin
        result:=(p.typ=arraydef) and
                (ado_IsConstString in TArrayDef(p).arrayoptions);
      end;

    { true, if p points to a special array, bitpacked arrays aren't special in this regard though }
    function is_special_array(p : TDef) : boolean;
      begin
         result:=(p.typ=arraydef) and
                 (
                  ((TArrayDef(p).arrayoptions * [ado_IsVariant,ado_IsArrayOfConst,ado_IsConstructor,ado_IsDynamicArray])<>[]) or
                  is_open_array(p)
                 );
      end;

    { true, if p points to a normal array, bitpacked arrays are included }
    function is_normal_array(p : TDef) : boolean;
      begin
         result:=(p.typ=arraydef) and
                 ((TArrayDef(p).arrayoptions * [ado_IsVariant,ado_IsArrayOfConst,ado_IsConstructor,ado_IsDynamicArray])=[]) and
                 not(is_open_array(p));
      end;

    { true if p is an ansi string def }
    function is_ansistring(p : TDef) : boolean;
      begin
         is_ansistring:=(p.typ=stringdef) and
                        (TStringDef(p).stringtype=st_ansistring);
      end;

    { true if p is an ansi string def with codepage CP_NONE }
    function is_rawbytestring(p : TDef) : boolean;
      begin
        is_rawbytestring:=(p.typ=stringdef) and
                       (TStringDef(p).stringtype=st_ansistring) and
                       (TStringDef(p).encoding=Globals.CP_NONE);
      end;

    { true if p is an long string def }
    function is_longstring(p : TDef) : boolean;
      begin
         is_longstring:=(p.typ=stringdef) and
                        (TStringDef(p).stringtype=st_longstring);
      end;


    { true if p is an wide string def }
    function is_widestring(p : TDef) : boolean;
      begin
         is_widestring:=(p.typ=stringdef) and
                        (TStringDef(p).stringtype=st_widestring);
      end;


    function is_dynamicstring(p: TDef): boolean;
      begin
         is_dynamicstring:=(p.typ=stringdef) and
                        (TStringDef(p).stringtype in [st_ansistring,st_widestring,st_unicodestring]);
      end;


    { true if p is an wide string def }
    function is_wide_or_unicode_string(p : TDef) : boolean;
      begin
         is_wide_or_unicode_string:=(p.typ=stringdef) and
                        (TStringDef(p).stringtype in [st_widestring,st_unicodestring]);
      end;


    { true if p is an unicode string def }
    function is_unicodestring(p : TDef) : boolean;
      begin
         is_unicodestring:=(p.typ=stringdef) and
                        (TStringDef(p).stringtype=st_unicodestring);
      end;


    { true if p is an short string def }
    function is_shortstring(p : TDef) : boolean;
      begin
         is_shortstring:=(p.typ=stringdef) and
                         (TStringDef(p).stringtype=st_shortstring);
      end;


    { true if p is bit packed array def }
    function is_packed_array(p: TDef) : boolean;
      begin
        is_packed_array :=
           (p.typ = arraydef) and
           (ado_IsBitPacked in TArrayDef(p).arrayoptions);
      end;


    { true if p is bit packed record def }
    function is_packed_record_or_object(p: TDef) : boolean;
      begin
        is_packed_record_or_object :=
           (p.typ in [recorddef,objectdef]) and
           (TAbstractRecordDef(p).is_packed);
      end;


    { true if p is a char array def }
    function is_chararray(p : TDef) : boolean;
      begin
        is_chararray:=(p.typ=arraydef) and
                      is_char(TArrayDef(p).elementdef) and
                      not(is_special_array(p));
      end;

    { true if p is a widechar array def }
    function is_widechararray(p : TDef) : boolean;
      begin
        is_widechararray:=(p.typ=arraydef) and
                          is_widechar(TArrayDef(p).elementdef) and
                          not(is_special_array(p));
      end;


    { true if p is a open char array def }
    function is_open_chararray(p : TDef) : boolean;
      begin
        is_open_chararray:= is_open_array(p) and
                            is_char(TArrayDef(p).elementdef);
      end;

    { true if p is a open wide char array def }
    function is_open_widechararray(p : TDef) : boolean;
      begin
        is_open_widechararray:= is_open_array(p) and
                                is_widechar(TArrayDef(p).elementdef);
      end;

    { true if p is any pointer def }
    function is_pointer(p : TDef) : boolean;
      begin
        is_pointer:=(p.typ=pointerdef);
      end;

    function is_address(p: TDef): boolean;
      begin
        is_address:=
          (p.typ in [classrefdef,formaldef,undefineddef,procdef]) or
          is_pointer(p) or
          is_implicit_array_pointer(p) or
          is_implicit_pointer_object_type(p) or
          ((p.typ=procvardef) and
           (TProcVarDef(p).is_addressonly or
            is_block(p)
           )
          )
      end;

    { true if p is a pchar def }
    function is_pchar(p : TDef) : boolean;
      begin
        is_pchar:=(p.typ=pointerdef) and
                  (is_char(TPointerDef(p).pointeddef) or
                   (is_zero_based_array(TPointerDef(p).pointeddef) and
                    is_chararray(TPointerDef(p).pointeddef)));
      end;

    { true if p is a pwidechar def }
    function is_pwidechar(p : TDef) : boolean;
      begin
        is_pwidechar:=(p.typ=pointerdef) and
                      (is_widechar(TPointerDef(p).pointeddef) or
                       (is_zero_based_array(TPointerDef(p).pointeddef) and
                        is_widechararray(TPointerDef(p).pointeddef)));
      end;


    { true if p is a voidpointer def }
    function is_voidpointer(p : TDef) : boolean;
      begin
        is_voidpointer:=(p.typ=pointerdef) and
                        (TPointerDef(p).pointeddef.typ=orddef) and
                        (TOrdDef(TPointerDef(p).pointeddef).ordtype=uvoid);
      end;


    type
      PDefListItem = ^TDefListItem;
      TDefListItem = record
        Next: PDefListItem;
        Def: TDef;
      end;

    { See "is_cyclic" below }
    function is_cyclic_internal(const def: TDef; const first: PDefListItem): Boolean;
      var
        thisdef: TDefListItem;
        curitem: PDefListItem;
      begin
        if not (def.typ in [arraydef, pointerdef]) then
          Exit(False);

        curitem := first;
        while Assigned(curitem) do
          begin
            if curitem^.Def = def then
              Exit(True);
            curitem := curitem^.Next;
          end;

        thisdef.Next := first;
        thisdef.Def := def;

        case def.typ of
          arraydef:
            Result := is_cyclic_internal(TArrayDef(def).elementdef, @thisdef);
          pointerdef:
            Result := is_cyclic_internal(TAbstractPointerDef(def).pointeddef, @thisdef);
          else
            InternalError(2022120301);
        end;
      end;

    { true, if p is a cyclic reference (refers to itself at some point via pointer or array) }
    function is_cyclic(p : TDef): Boolean; {$ifdef USEINLINE}inline;{$endif USEINLINE}
      begin
        Result := is_cyclic_internal(p, nil);
      end;

    { true, if def is a 8 bit int type }
    function is_8bitint(def : TDef) : boolean;
      begin
         result:=(def.typ=orddef) and (TOrdDef(def).ordtype in [u8bit,s8bit])
      end;

    { true, if def is a 8 bit ordinal type }
    function is_8bit(def : TDef) : boolean;
      begin
         result:=(def.typ=orddef) and (TOrdDef(def).ordtype in [u8bit,s8bit,pasbool1,pasbool8,bool8bit,uchar])
      end;

    { true, if def is a 16 bit int type }
    function is_16bitint(def : TDef) : boolean;
      begin
         result:=(def.typ=orddef) and (TOrdDef(def).ordtype in [u16bit,s16bit])
      end;

    { true, if def is a 16 bit ordinal type }
    function is_16bit(def : TDef) : boolean;
      begin
         result:=(def.typ=orddef) and (TOrdDef(def).ordtype in [u16bit,s16bit,pasbool16,bool16bit,uwidechar])
      end;

    { true, if def is a 32 bit int type }
    function is_32bitint(def : TDef) : boolean;
      begin
         result:=(def.typ=orddef) and (TOrdDef(def).ordtype in [u32bit,s32bit])
      end;

    { true, if def is a 32 bit ordinal type }
    function is_32bit(def: TDef): boolean;
      begin
         result:=(def.typ=orddef) and (TOrdDef(def).ordtype in [u32bit,s32bit,pasbool32,bool32bit])
      end;


    { true, if def is a 64 bit int type }
    function is_64bitint(def : TDef) : boolean;
      begin
         is_64bitint:=(def.typ=orddef) and (TOrdDef(def).ordtype in [u64bit,s64bit])
      end;


    function is_s64bitint(def: TDef): boolean;
      begin
        is_s64bitint:=(def.typ=orddef) and (TOrdDef(def).ordtype=s64bit)
      end;


    function is_u64bitint(def: TDef): boolean;
      begin
        is_u64bitint:=(def.typ=orddef) and (TOrdDef(def).ordtype=u64bit)
      end;


    { true, if def is a 64 bit type }
    function is_64bit(def : TDef) : boolean;
      begin
         is_64bit:=(def.typ=orddef) and (TOrdDef(def).ordtype in [u64bit,s64bit,scurrency,pasbool64,bool64bit])
      end;


    { returns true, if def is a longint type }
    function is_s32bitint(def : TDef) : boolean;
      begin
        result:=(def.typ=orddef) and
          (TOrdDef(def).ordtype=s32bit);
      end;


    { returns true, if def is a dword type }
    function is_u32bitint(def : TDef) : boolean;
      begin
        result:=(def.typ=orddef) and
          (TOrdDef(def).ordtype=u32bit);
      end;


    { true, if def1 and def2 are both integers of the same bit size and sign }
    function are_equal_ints(def1, def2: TDef): boolean;
      begin
        result:=(def1.typ=orddef) and (def2.typ=orddef) and
          (TOrdDef(def1).ordtype in [u8bit,u16bit,u32bit,u64bit,
                                     s8bit,s16bit,s32bit,s64bit,customint]) and
          (TOrdDef(def1).ordtype=TOrdDef(def2).ordtype) and
          ((TOrdDef(def1).ordtype<>customint) or
           ((TOrdDef(def1).low=TOrdDef(def2).low) and
            (TOrdDef(def1).high=TOrdDef(def2).high)));
      end;


    { true, if def is an int type, larger than the processor's native int size }
    function is_oversizedint(def : TDef) : boolean;
      begin
{$if defined(cpu32bitaddr)}
         result:=is_64bitint(def);
{$elseif defined(cpu64bitaddr)}
         result:=false;
{$endif}
      end;

    { true, if def is an ordinal type, larger than the processor's native int size }
    function is_oversizedord(def : TDef) : boolean;
      begin
{$if defined(cpu32bitaddr)}
         result:=is_64bit(def);
{$elseif defined(cpu64bitaddr)}
         result:=false;
{$endif}
      end;


    { true, if def is an int type, equal in size to the processor's native int size }
    function is_nativeint(def: TDef): boolean;
      begin
{$if defined(cpu32bitaddr)}
         result:=is_32bitint(def);
{$elseif defined(cpu64bitaddr)}
         result:=is_64bitint(def);
{$endif}
      end;

    { true, if def is an ordinal type, equal in size to the processor's native int size }
    function is_nativeord(def: TDef): boolean;
      begin
{$if defined(cpu32bitaddr)}
         result:=is_32bit(def);
{$elseif defined(cpu64bitaddr)}
         result:=is_64bit(def);
{$endif}
      end;

    { true, if def is an unsigned int type, equal in size to the processor's native int size }
    function is_nativeuint(def: TDef): boolean;
      begin
         result:=is_nativeint(def) and (def.typ=orddef) and (TOrdDef(def).ordtype in [u64bit,u32bit,u16bit,u8bit]);
      end;

    { true, if def is a signed int type, equal in size to the processor's native int size }
    function is_nativesint(def: TDef): boolean;
      begin
         result:=is_nativeint(def) and (def.typ=orddef) and (TOrdDef(def).ordtype in [s64bit,s32bit,s16bit,s8bit]);
      end;

    function is_systemunit_unicode: boolean;

    var
      t : TTypeSym;

    begin
      if cchartype=nil then
        begin
          t:=search_system_type('CHAR');
          if t<>nil then
            cchartype:=t.typedef;
        end;
      if cchartype=nil then
        is_systemunit_unicode:=(sizeof(char)=2)
      else
        is_systemunit_unicode:=(cchartype.size=2);
    end;

    { if l isn't in the range of todef a range check error (if not explicit) is generated and
      the value is placed within the range }
    procedure adaptrange(todef : TDef;var l : TConstExprInt; rangecheck: TPerformRangeCheck);
      var
         lv,hv,oldval,sextval,mask: TConstExprInt;
         rangedef: TDef;
         rangedefsize: LongInt;
         warned: boolean;
      begin
         getrange(todef,lv,hv);
         if (l<lv) or (l>hv) then
           begin
             warned:=false;
             if rangecheck in [rc_implicit,rc_yes] then
               begin
                 if (rangecheck=rc_yes) or
                    (todef.typ=enumdef) then
                   Message3(type_e_range_check_error_bounds,ToStr(l),ToStr(lv),ToStr(hv))
                 else
                   Message3(type_w_range_check_error_bounds,ToStr(l),ToStr(lv),ToStr(hv));
                 warned:=true;
               end
             { give warnings about range errors with explicit typeconversions if the target
               type does not span the entire range that can be represented by its bits
               (subrange type or enum), because then the result is undefined }
             else if (rangecheck<>rc_internal) and
                     (not is_pasbool(todef) and
                      not spans_entire_range(todef)) then
               begin
                 Message3(type_w_range_check_error_bounds,ToStr(l),ToStr(lv),ToStr(hv));
                 warned:=true;
               end;

             { Fix the value to fit in the allocated space for this type of variable }
             oldval:=l;
             getrangedefmasksize(todef,rangedef,mask,rangedefsize);
             l:=l and mask;
             {reset sign, i.e. converting -1 to qword changes the value to high(qword)}
             l.signed:=false;
             sextval:=0;
             { do sign extension if necessary (JM) }
             case rangedefsize of
               1: sextval.svalue:=shortint(l.svalue);
               2: sextval.svalue:=smallint(l.svalue);
               4: sextval.svalue:=LongInt(l.svalue);
               8: sextval.svalue:=l.svalue;
               else
                 InternalError(201906230);
              end;
              sextval.signed:=true;
              { Detect if the type spans the entire range, but more bits were specified than
                the type can contain, e.g. shortint($fff).
                However, none of the following should result in a warning:
                  1) shortint($ff) (-> $ff -> $ff -> $ffff ffff ffff ffff)
                  2) shortint(longint(-1)) ($ffff ffff ffff ffff ffff -> $ff -> $ffff ffff ffff ffff
                  3) cardinal(-1) (-> $ffff ffff ffff ffff -> $ffff ffff)
              }
              if not warned and
                (rangecheck<>rc_internal) and
                (oldval.uvalue<>l.uvalue) and
                (oldval.uvalue<>sextval.uvalue) then
               begin
                 Message3(type_w_range_check_error_bounds,ToStr(oldval),ToStr(lv),ToStr(hv));
               end;
              if is_signed(rangedef) then
                l:=sextval;
           end;
      end;


    procedure adaptrange(todef: TDef; var l: TConstExprInt; internal, explicit, rangecheckstate: boolean);
      begin
        if internal then
          adaptrange(todef, l, rc_internal)
        else if explicit then
          adaptrange(todef, l, rc_explicit)
        else if not rangecheckstate then
          adaptrange(todef, l, rc_implicit)
        else
          adaptrange(todef, l, rc_yes)
      end;


    { return the range from def in l and h }
    procedure getrange(def : TDef;out l, h : TConstExprInt);
      begin
        case def.typ of
          orddef :
            begin
              l:=TOrdDef(def).low;
              h:=TOrdDef(def).high;
            end;
          enumdef :
            begin
              l:=int64(TEnumDef(def).min);
              h:=int64(TEnumDef(def).max);
            end;
          arraydef :
            begin
              l:=int64(TArrayDef(def).lowrange);
              h:=int64(TArrayDef(def).highrange);
            end;
          undefineddef:
            begin
              l:=TOrdDef(sizesinttype).low;
              h:=TOrdDef(sizesinttype).high;
            end;
          else
            InternalError(200611054);
        end;
      end;


    procedure getrangedefmasksize(def: TDef; out rangedef: TDef; out mask: TConstExprInt; out size: LongInt);
      begin
        case def.typ of
          orddef, enumdef:
            begin
              rangedef:=def;
              size:=def.size;
              case size of
                1: mask:=$ff;
                2: mask:=$ffff;
                4: mask:=$ffffffff;
                8: mask:=$ffffffffffffffff;
                else
                  InternalError(2019062305);
                end;
            end;
          arraydef:
            begin
              rangedef:=TArrayDef(def).rangedef;
              getrangedefmasksize(rangedef,rangedef,mask,size);
            end;
          undefineddef:
            begin
              rangedef:=sizesinttype;
              size:=rangedef.size;
              mask:=-1;
            end;
          else
            InternalError(2019062306);
        end;
      end;


    function mmx_type(p : TDef) : TMMXType;
      begin
         mmx_type:=mmxno;
         if is_mmx_able_array(p) then
           begin
              if TArrayDef(p).elementdef.typ=floatdef then
                case TFloatDef(TArrayDef(p).elementdef).floattype of
                  S32Real:
                    mmx_type:=mmxsingle;
                  else
                    ;
                end
              else
                case TOrdDef(TArrayDef(p).elementdef).ordtype of
                   u8bit:
                     mmx_type:=mmxu8bit;
                   s8bit:
                     mmx_type:=mmxs8bit;
                   u16bit:
                     mmx_type:=mmxu16bit;
                   s16bit:
                     mmx_type:=mmxs16bit;
                   u32bit:
                     mmx_type:=mmxu32bit;
                   s32bit:
                     mmx_type:=mmxs32bit;
                   else
                     ;
                end;
           end;
      end;


    { The range-type of an ordinal-type that is a subrange-type shall be the host-type (see 6.4.2.4) of the subrange-type.
      The range-type of an ordinal-type that is not a subrange-type shall be the ordinal-type.

      The subrange-bounds shall be of compatible ordinal-types, and the range-type (see 6.4.2.1) of the ordinal-types shall
      be designated the host-type of the subrange-type. }
    function get_iso_range_type(def: TDef): TDef;
      begin
        result:=nil;
        case def.typ of
           orddef:
             begin
               if is_integer(def) then
                 begin
                   if (TOrdDef(def).low>=TOrdDef(sinttype).low) and
                      (TOrdDef(def).high<=TOrdDef(sinttype).high) then
                     result:=sinttype
                   else
                     range_to_type(TOrdDef(def).low,TOrdDef(def).high,result);
                 end
               else case TOrdDef(def).ordtype of
                 pasbool1:
                   result:=pasbool1type;
                 pasbool8:
                   result:=pasbool8type;
                 pasbool16:
                   result:=pasbool16type;
                 pasbool32:
                   result:=pasbool32type;
                 pasbool64:
                   result:=pasbool64type;
                 bool8bit:
                   result:=bool8type;
                 bool16bit:
                   result:=bool16type;
                 bool32bit:
                   result:=bool32type;
                 bool64bit:
                   result:=bool64type;
                 uchar:
                   result:=cansichartype;
                 uwidechar:
                   result:=cwidechartype;
                 scurrency:
                   result:=s64currencytype;
                 else
                   InternalError(2018010901);
               end;
             end;
           enumdef:
             begin
               while Assigned(TEnumDef(def).basedef) do
                 def:=TEnumDef(def).basedef;
               result:=def;
             end
           else
             InternalError(2018010701);
        end;
      end;


    function is_vector(p : TDef) : boolean;
      begin
        result:=(p.typ=arraydef) and
                (TArrayDef(p).is_hwvector { or
                 (not(is_special_array(p)) and
                  (tarraydef(p).elementdef.typ in [floatdef,orddef]) and
                  (tarraydef(p).elementdef.typ=floatdef) and
                  (tfloatdef(tarraydef(p).elementdef).floattype in [s32real,s64real])
                 ) }
                );
      end;


    { returns if the passed type (array) fits into an mm register }
    function fits_in_mm_register(p : TDef) : boolean;
      begin
{$ifdef x86}
        result:= is_vector(p) and
                 (
                  (
                   (TArrayDef(p).elementdef.typ=floatdef) and
                   (
                    (TArrayDef(p).lowrange=0) and
                    ((TArrayDef(p).highrange=3) or
                     (UseAVX and (TArrayDef(p).highrange=7)) or
                     (UseAVX512 and (TArrayDef(p).highrange=15))
                    ) and
                    (TFloatDef(TArrayDef(p).elementdef).floattype=S32Real)
                   )
                  ) or

                  (
                   (TArrayDef(p).elementdef.typ=floatdef) and
                   (
                    (TArrayDef(p).lowrange=0) and
                    ((TArrayDef(p).highrange=1) or
                     (UseAVX and (TArrayDef(p).highrange=3)) or
                     (UseAVX512 and (TArrayDef(p).highrange=7))
                    )and
                    (TFloatDef(TArrayDef(p).elementdef).floattype=S64Real)
                   )
                  ) {or

                  // MMX registers
                  (
                   (tarraydef(p).elementdef.typ=floatdef) and
                   (
                    (tarraydef(p).lowrange=0) and
                    (tarraydef(p).highrange=1) and
                    (tfloatdef(tarraydef(p).elementdef).floattype=s32real)
                   )
                  ) or

                  (
                   (tarraydef(p).elementdef.typ=orddef) and
                   (
                    (tarraydef(p).lowrange=0) and
                    (tarraydef(p).highrange=1) and
                    (torddef(tarraydef(p).elementdef).ordtype in [s32bit,u32bit])
                   )
                  )  or

                  (
                   (tarraydef(p).elementdef.typ=orddef) and
                   (
                    (tarraydef(p).lowrange=0) and
                    (tarraydef(p).highrange=3) and
                    (torddef(tarraydef(p).elementdef).ordtype in [s16bit,u16bit])
                   )
                  ) or

                  (
                   (tarraydef(p).elementdef.typ=orddef) and
                   (
                    (tarraydef(p).lowrange=0) and
                    (tarraydef(p).highrange=7) and
                    (torddef(tarraydef(p).elementdef).ordtype in [s8bit,u8bit])
                   )
                  ) }
                 );
{$else x86}
        result:=false;
{$endif x86}
      end;


    function to_hwvectordef(p: TDef; nil_on_error: boolean): TDef;
      begin
        result:=nil;
        if p.typ=arraydef then
          begin
            if TArrayDef(p).is_hwvector then
              result:=p
            else if fits_in_mm_register(p) then
              result:=CArrayDef.getreusable_vector(TArrayDef(p).elementdef,TArrayDef(p).elecount)
            else if not nil_on_error then
              InternalError(2022090811);
          end
        else if not nil_on_error then
          InternalError(2022090810);
      end;


    function is_mmx_able_array(p : TDef) : boolean;
      begin
{$ifdef SUPPORT_MMX}
         if (cs_mmx_saturation in CurrentSettings.LocalSwitches) then
           begin
              is_mmx_able_array:=(p.typ=arraydef) and
                not(is_special_array(p)) and
                (
                 (
                  (TArrayDef(p).elementdef.typ=orddef) and
                  (
                   (
                    (TArrayDef(p).lowrange=0) and
                    (TArrayDef(p).highrange=1) and
                    (TOrdDef(TArrayDef(p).elementdef).ordtype in [u32bit,s32bit])
                   )
                   or
                   (
                    (TArrayDef(p).lowrange=0) and
                    (TArrayDef(p).highrange=3) and
                    (TOrdDef(TArrayDef(p).elementdef).ordtype in [u16bit,s16bit])
                   )
                  )
                 )
                 or
                (
                 (
                  (TArrayDef(p).elementdef.typ=floatdef) and
                  (
                   (TArrayDef(p).lowrange=0) and
                   (TArrayDef(p).highrange=1) and
                   (TFloatDef(TArrayDef(p).elementdef).floattype=S32Real)
                  )
                 )
                )
              );
           end
         else
           begin
              is_mmx_able_array:=(p.typ=arraydef) and
                (
                 (
                  (TArrayDef(p).elementdef.typ=orddef) and
                  (
                   (
                    (TArrayDef(p).lowrange=0) and
                    (TArrayDef(p).highrange=1) and
                    (TOrdDef(TArrayDef(p).elementdef).ordtype in [u32bit,s32bit])
                   )
                   or
                   (
                    (TArrayDef(p).lowrange=0) and
                    (TArrayDef(p).highrange=3) and
                    (TOrdDef(TArrayDef(p).elementdef).ordtype in [u16bit,s16bit])
                   )
                   or
                   (
                    (TArrayDef(p).lowrange=0) and
                    (TArrayDef(p).highrange=7) and
                    (TOrdDef(TArrayDef(p).elementdef).ordtype in [u8bit,s8bit])
                   )
                  )
                 )
                 or
                 (
                  (TArrayDef(p).elementdef.typ=floatdef) and
                  (
                   (TArrayDef(p).lowrange=0) and
                   (TArrayDef(p).highrange=1) and
                   (TFloatDef(TArrayDef(p).elementdef).floattype=S32Real)
                  )
                 )
                );
           end;
{$else SUPPORT_MMX}
         is_mmx_able_array:=false;
{$endif SUPPORT_MMX}
      end;


    function def_cgsize(def: TDef): TCgSize;
      begin
        case def.typ of
          orddef,
          enumdef,
          setdef:
            begin
              result:=int_cgsize(def.size);
              if is_signed(def) then
                result:=TCgSize(ord(result)+(ord(OS_S8)-ord(OS_8)));
            end;
          classrefdef,
          pointerdef:
            begin
              result:=int_cgsize(def.size);
              { can happen for far/huge pointers on non-i8086 }
              if result=OS_NO then
                InternalError(2013052201);
            end;
          formaldef:
            result := int_cgsize(voidpointertype.size);
          procvardef:
            result:=int_cgsize(def.size);
          stringdef :
            result:=int_cgsize(def.size);
          objectdef :
            result:=int_cgsize(def.size);
          floatdef:
              result:=tfloat2tcgsize[TFloatDef(def).floattype];
          recorddef :
              result:=int_cgsize(def.size);
          arraydef :
            begin
              if is_dynamic_array(def) or not is_special_array(def) then
                begin
                  if is_vector(def) and (TArrayDef(def).elementdef.typ = floatdef) then
                    begin
                      { Determine if, based on the floating-point type and the size
                        of the array, if it can be made into a vector }
                      case TFloatDef(TArrayDef(def).elementdef).floattype of
                        S32Real:
                          result := float_array_cgsize(def.size);
                        S64Real:
                          result := double_array_cgsize(def.size);
                        else
                          { If not, fall back }
                          result := int_cgsize(def.size);
                      end;
                    end
                  else
                    result := int_cgsize(def.size);
                end
              else
                result := OS_NO;
            end;
          else
            begin
              { undefined size }
              result:=OS_NO;
            end;
        end;
      end;

    function cgsize_orddef(size: TCgSize): TOrdDef;
      begin
        case size of
          OS_8:
            result:=TOrdDef(u8inttype);
          OS_S8:
            result:=TOrdDef(s8inttype);
          OS_16:
            result:=TOrdDef(u16inttype);
          OS_S16:
            result:=TOrdDef(s16inttype);
          OS_32:
            result:=TOrdDef(u32inttype);
          OS_S32:
            result:=TOrdDef(s32inttype);
          OS_64:
            result:=TOrdDef(u64inttype);
          OS_S64:
            result:=TOrdDef(s64inttype);
          else
            InternalError(2012050401);
        end;
      end;

    function def_cgmmsize(def: TDef): TCgSize;
      begin
        case def.typ of
          arraydef:
            begin
              case TArrayDef(def).elementdef.typ of
                orddef:
                  begin
                    { this is not correct, OS_MX normally mean that the vector
                      contains elements of size X. However, vectors themselves
                      can also have different sizes (e.g. a vector of 2 singles on
                      SSE) and the total size is currently more important }
                    case def.size of
                      1: result:=OS_M8;
                      2: result:=OS_M16;
                      4: result:=OS_M32;
                      8: result:=OS_M64;
                      16: result:=OS_M128;
                      32: result:=OS_M256;
                      64: result:=OS_M512;
                      else
                        InternalError(2013060103);
                    end;
                  end;
                floatdef:
                  begin
                    case TFloatDef(TArrayDef(def).elementdef).floattype of
                      S32Real:
                        case def.size of
                          4:  result:=OS_M32;
                          16: result:=OS_M128;
                          32: result:=OS_M256;
                          64: result:=OS_M512;
                          else
                            InternalError(2017121400);
                        end;
                      S64Real:
                        case def.size of
                          8:  result:=OS_M64;
                          16: result:=OS_M128;
                          32: result:=OS_M256;
                          64: result:=OS_M512;
                          else
                            InternalError(2017121401);
                        end;
                      else
                        InternalError(2017121402);
                    end;
                  end;
                else
                  result:=def_cgsize(def);
              end;
            end
          else
            result:=def_cgsize(def);
        end;
      end;

    { In Windows 95 era, ordinals were restricted to [u8bit,s32bit,s16bit,bool16bit]
      As of today, both signed and unsigned types from 8 to 64 bits are supported. }
    function is_automatable(p : TDef) : boolean;
      begin
        case p.typ of
          orddef:
            result:=TOrdDef(p).ordtype in [u8bit,s8bit,u16bit,s16bit,u32bit,s32bit,
              u64bit,s64bit,bool16bit,scurrency];
          floatdef:
            result:=TFloatDef(p).floattype in [s64currency,S64Real,S32Real];
          stringdef:
            result:=TStringDef(p).stringtype in [st_ansistring,st_widestring,st_unicodestring];
          variantdef:
            result:=true;
          objectdef:
            result:=TObjectDef(p).objecttype in [odt_interfacecom,odt_dispinterface,odt_interfacecorba];
          else
            result:=false;
        end;
      end;


    {# returns true, if the type passed is a varset }
    function is_smallset(p : TDef) : boolean;
      begin

          result:=(p.typ=setdef) and (p.size in [1,2,4])

      end;


    function is_bareprocdef(pd : TProcDef): boolean;
      begin
        result:=(pd.maxparacount=0) and
                (is_void(pd.returndef) or
                 (pd.proctypeoption = potype_constructor));
      end;

    function is_c_variadic(pd: TAbstractProcDef): boolean;
      begin
        result:=
          (po_varargs in pd.procoptions) or
          (po_variadic in pd.procoptions);
      end;

    function get_common_intdef(ld, rd: TOrdDef; keep_sign_if_equal: boolean): TOrdDef;
      var
        llow, lhigh: TConstExprInt;
      begin
        llow:=min(ld.low,rd.low);
        lhigh:=max(ld.high,rd.high);
        case range_to_basetype(llow,lhigh) of
          s8bit:
            result:=TOrdDef(s8inttype);
          u8bit:
            result:=TOrdDef(u8inttype);
          s16bit:
            result:=TOrdDef(s16inttype);
          u16bit:
            result:=TOrdDef(u16inttype);
          s32bit:
            result:=TOrdDef(s32inttype);
          u32bit:
            result:=TOrdDef(u32inttype);
          s64bit:
            result:=TOrdDef(s64inttype);
          u64bit:
            result:=TOrdDef(u64inttype);
          else
            begin
              { avoid warning }
              result:=nil;
              InternalError(200802291);
            end;
        end;
        if keep_sign_if_equal and
           (is_signed(ld)=is_signed(rd)) and
           (is_signed(result)<>is_signed(ld)) then
          case result.ordtype of
            s8bit:
              result:=TOrdDef(u8inttype);
            u8bit:
              result:=TOrdDef(s16inttype);
            s16bit:
              result:=TOrdDef(u16inttype);
            u16bit:
              result:=TOrdDef(s32inttype);
            s32bit:
              result:=TOrdDef(u32inttype);
            u32bit:
              result:=TOrdDef(s64inttype);
            s64bit:
              result:=TOrdDef(u64inttype);
            else
              ;
          end;
      end;


    function calc_not_ordvalue(var v:TConstExprInt;var def:TDef):boolean;
      begin
        if not Assigned(def) or (def.typ<>orddef) then
          exit(false);
        result:=true;
        case TOrdDef(def).ordtype of
          pasbool1,
          pasbool8,
          pasbool16,
          pasbool32,
          pasbool64:
            v:=byte(not(boolean(int64(v))));
          bool8bit,
          bool16bit,
          bool32bit,
          bool64bit:
            begin
              if v=0 then
                v:=-1
              else
                v:=0;
            end;
          uchar,
          uwidechar,
          u8bit,
          s8bit,
          u16bit,
          s16bit,
          s32bit,
          u32bit,
          s64bit,
          u64bit:
            begin
              { unsigned, equal or bigger than the native int size? }
              if (TOrdDef(def).ordtype in [u64bit,u32bit,u16bit,u8bit,uchar,uwidechar]) and
                 (is_nativeord(def) or is_oversizedord(def)) then
                begin
                  { Delphi-compatible: not dword = dword (not word = longint) }
                  { Extension: not qword = qword                              }
                  v:=qword(not qword(v));
                  { will be truncated by the ordconstnode for u32bit }
                end
              else
                begin
                  v:=int64(not int64(v));
                  def:=get_common_intdef(TOrdDef(def),TOrdDef(sinttype),false);
                end;
            end;
          else
            result:=false;
        end;
      end;

    function is_valid_univ_para_type(def: TDef): boolean;
      begin
        result:=
          not is_open_array(def) and
          not is_void(def) and
          (def.typ<>formaldef);
      end;


    function is_nested_pd(def: TAbstractProcDef): boolean;{$ifdef USEINLINE}inline;{$endif}
      begin
        result:=def.parast.symtablelevel>normal_function_level;
      end;


    function is_typeparam(def : TDef) : boolean;{$ifdef USEINLINE}inline;{$endif}
      begin
        result:=(def.typ=undefineddef) or (df_genconstraint in def.defoptions);
      end;


    function is_methodpointer(def: TDef): boolean;
      begin
        result:=(def.typ=procvardef) and (po_methodpointer in TProcVarDef(def).procoptions);
      end;


    function is_funcref(def:TDef):boolean;
      begin
        result:=(def.typ=objectdef) and (oo_is_funcref in TObjectDef(def).objectoptions);
      end;


    function is_invokable(def:TDef):boolean;
      begin
        result:=(def.typ=objectdef) and (oo_is_invokable in TObjectDef(def).objectoptions);
      end;


    function is_block(def: TDef): boolean;
      begin
        result:=(def.typ=procvardef) and (po_is_block in TProcVarDef(def).procoptions)
      end;


    function get_typekind(def:TDef):byte;
      begin
        case def.typ of
          arraydef:
            if ado_IsDynamicArray in TArrayDef(def).arrayoptions then
              result:=tkDynArray
            else
              result:=tkArray;
          recorddef:
            result:=tkRecord;
          pointerdef:
            result:=tkPointer;
          orddef:
            case TOrdDef(def).ordtype of
              u8bit,
              u16bit,
              u32bit,
              s8bit,
              s16bit,
              s32bit:
                result:=tkInteger;
              u64bit:
                result:=tkQWord;
              s64bit:
                result:=tkInt64;
              pasbool1,
              pasbool8,
              pasbool16,
              pasbool32,
              pasbool64,
              bool8bit,
              bool16bit,
              bool32bit,
              bool64bit:
                result:=tkBool;
              uchar:
                result:=tkChar;
              uwidechar:
                result:=tkWChar;
              scurrency:
                result:=tkFloat;
              else
                result:=tkUnknown;
            end;
          stringdef:
            case TStringDef(def).stringtype of
              st_shortstring:
                result:=tkSString;
              st_longstring:
                result:=tkLString;
              st_ansistring:
                result:=tkAString;
              st_widestring:
                result:=tkWString;
              st_unicodestring:
                result:=tkUString;
            end;
          enumdef:
            result:=tkEnumeration;
          objectdef:
            case TObjectDef(def).objecttype of
              odt_class:
                result:=tkClass;
              odt_object:
                result:=tkObject;
              odt_interfacecom,
              odt_dispinterface:
                result:=tkInterface;
              odt_interfacecorba:
                result:=tkInterfaceCorba;
              odt_helper:
                result:=tkHelper;
              else
                result:=tkUnknown;
            end;
          { currently tkFile is not used }
          {filedef:
            result:=tkFile;}
          setdef:
            result:=tkSet;
          procvardef:
            if TProcVarDef(def).is_methodpointer then
              result:=tkMethod
            else
              result:=tkProcVar;
          floatdef:
            result:=tkFloat;
          classrefdef:
            result:=tkClassRef;
          variantdef:
            result:=tkVariant;
          else
            result:=tkUnknown;
        end;
      end;


    function get_invoke_procdef(def:TObjectDef):TProcDef;
      var
        sym : TSym;
      begin
        repeat
          if not is_invokable(def) then
            InternalError(2022011701);
          sym:=TSym(def.SymTable.find(method_name_funcref_invoke_find));
          if Assigned(sym) and (sym.typ<>procsym) then
            sym:=nil;
          def:=def.childof;
        until Assigned(sym) or not Assigned(def);
        if not Assigned(sym) then
          InternalError(2021041001);
        if sym.typ<>procsym then
          InternalError(2021041002);
        if TProcSym(sym).procdeflist.count=0 then
          InternalError(2021041003);
        result:=TProcDef(TProcSym(sym).procdeflist[0]);
      end;


    function invokable_has_argless_invoke(def:TObjectDef):boolean;
      var
        i,j : LongInt;
        sym : TSym;
        pd : TProcDef;
        para : TParaVarSym;
        allok : boolean;
      begin
        result:=false;
        repeat
          if not is_invokable(def) then
            InternalError(2022020701);
          sym:=TSym(def.SymTable.find(method_name_funcref_invoke_find));
          if Assigned(sym) and (sym.typ=procsym) then
            begin
              for i:=0 to TProcSym(sym).procdeflist.count-1 do
                begin
                  pd:=TProcDef(TProcSym(sym).procdeflist[i]);
                  if (pd.paras.count=0) or
                      (
                        (pd.paras.count=1) and
                        (vo_is_result in TParaVarSym(pd.paras[0]).varoptions)
                      ) then
                    exit(true);
                  allok:=true;
                  for j:=0 to pd.paras.count-1 do
                    begin
                      para:=TParaVarSym(pd.paras[j]);
                      if vo_is_hidden_para in para.varoptions then
                        continue;
                      if Assigned(para.defaultconstsym) then
                        continue;
                      allok:=false;
                      break;
                    end;
                  if allok then
                    exit(true);
                end;
              if not (sp_has_overloaded in sym.symoptions) then
                break;
            end;
          def:=def.childof;
        until not Assigned(def);
      end;

end.
