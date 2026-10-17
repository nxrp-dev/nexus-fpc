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
       SymConst,SymType,SymDef,
       CGBase,CPUBase;


{*****************************************************************************
                          Basic type functions
 *****************************************************************************}

    {# Returns true, if definition defines an ordinal type }
    function Is_Ordinal(Def : TDef) : Boolean;

    {# Returns true, if definition defines a string type }
    function Is_String(Def : TDef): Boolean;

    {# Returns True, if definition defines a type that behaves like a string,
       namely that can be joined and compared with another string-like type }
    function Is_StringLike(Def : TDef) : Boolean;

    {# Returns the typedef for the char type that matches the stringlike }
    function CharType_For_StringLike(Def : TDef) : TDef;

    {# Returns True, if definition defines an enumeration type }
    function Is_Enum(Def : TDef) : Boolean;

    {# Returns True, if definition defines a set type }
    function Is_Set(Def : TDef) : Boolean;

    {# Returns the minimal integer value of the type }
    function Get_Min_Value(Def : TDef) : TConstExprInt;

    {# Returns the maximal integer value of the type }
    function Get_Max_Value(Def : TDef) : TConstExprInt;

    {# Returns basetype of the specified integer range }
    function Range_To_BaseType(const L,H:TConstExprInt):TOrdType;

    procedure Range_To_Type(const L,H:TConstExprInt;var Def:TDef);

    procedure Int_To_Type(const V:TConstExprInt;var Def:TDef);

    {# Return true if the type (orddef or enumdef) spans its entire bitrange }
    function Spans_Entire_Range(Def: TDef): Boolean;

    {# Returns true, if definition defines an integer type }
    function Is_Integer(Def : TDef) : Boolean;

    {# Returns true if definition is a boolean }
    function Is_Boolean(Def : TDef) : Boolean;

    {# Returns true if definition is a Pascal-style boolean (1 = true, zero = false) }
    function Is_PasBool(Def : TDef) : Boolean;

    {# Returns true if definition is a C-style boolean (non-zero value = true, zero = false) }
    function Is_CBool(Def : TDef) : Boolean;

    {# Returns true if definition is a char

       This excludes the unicode char.
    }
    function Is_Char(Def : TDef) : Boolean;

    {# Returns true if definition is a widechar }
    function Is_WideChar(Def : TDef) : Boolean;

    {# Returns true if definition is either an AnsiChar or a WideChar }
    function Is_AnyChar(Def : TDef) : Boolean;

    {# Returns true if definition is a void}
    function Is_Void(Def : TDef) : Boolean;

    {# Returns true if definition is a smallset}
    function Is_SmallSet(P : TDef) : Boolean;

    {# Returns true, if def defines a signed data type
       (only for ordinal types)
    }
    function Is_Signed(Def : TDef) : Boolean;

    {# Returns an unsigned integer type of the same size as def; def must be
       an ordinal or enum }
    function Get_Unsigned_IntType(Def: TDef): TOrdDef;

    {# Returns a signed integer type of the same size as def; def must be
       an ordinal or enum }
    function Get_Signed_IntType(Def: TDef): TOrdDef;

    {# Returns whether def_from's range is comprised in def_to's if both are
      orddefs, false otherwise                                              }
    function Is_In_Limit(DefFrom,DefTo : TDef) : Boolean;

    {# Returns whether def is reference counted }
    function Is_Managed_Type(Def: TDef) : Boolean;{$ifdef USEINLINE}inline;{$endif}

    { # Returns whether def is needs to load RTTI for reference counting }
    function Is_RTTI_Managed_Type(Def: TDef) : Boolean;

{    function is_in_limit_value(val_from:TConstExprInt;def_from,def_to : tdef) : boolean;}

{*****************************************************************************
                              Array helper functions
 *****************************************************************************}

    {# Returns true, if p points to a zero based (non special like open or
      dynamic array def).

      This is mainly used to see if the array
      is convertable to a pointer
    }
    function Is_Zero_Based_Array(P : TDef) : Boolean;

    {# Returns true if p points to an open array definition }
    function Is_Open_Array(P : TDef) : Boolean;

    {# Returns true if p points to a dynamic array definition }
    function Is_Dynamic_Array(P : TDef) : Boolean;

    {# Returns true, if p points to an array of const definition }
    function Is_Array_Constructor(P : TDef) : Boolean;

    {# Returns true, if p points to a variant array }
    function Is_Variant_Array(P : TDef) : Boolean;

    {# Returns true, if p points to an array of const }
    function Is_Array_Of_Const(P : TDef) : Boolean;

    {# Returns true if p is an arraydef that describes a constant string }
    function Is_ConstString_Array(P : TDef) : Boolean;

    {# Returns true, if p points any kind of special array

       That is if the array is an open array, a variant
       array, an array constants constructor, or an
       array of const.

       Bitpacked arrays aren't special in this regard though.
    }
    function Is_Special_Array(P : TDef) : Boolean;

    {# Returns true, if p points to a normal array, bitpacked arrays are included }
    function Is_Normal_Array(P : TDef) : Boolean;

    {# Returns true if p is a bitpacked array }
    function Is_Packed_Array(P: TDef) : Boolean;

    {# Returns true if p is a bitpacked record }
    function Is_Packed_Record_Or_Object(P: TDef) : Boolean;

    {# Returns true if p is a char array def }
    function Is_CharArray(P : TDef) : Boolean;

    {# Returns true if p is a wide char array def }
    function Is_WideCharArray(P : TDef) : Boolean;

    {# Returns true if p is a open char array def }
    function Is_Open_CharArray(P : TDef) : Boolean;

    {# Returns true if p is a open wide char array def }
    function Is_Open_WideCharArray(P : TDef) : Boolean;

{*****************************************************************************
                          String helper functions
 *****************************************************************************}

    {# Returns true if p points to an open string type }
    function Is_Open_String(P : TDef) : Boolean;

    {# Returns true if p is an ansi string type }
    function Is_AnsiString(P : TDef) : Boolean;

    {# Returns true if p is an ansi string type with codepage 0 }
    function Is_RawByteString(P : TDef) : Boolean;

    {# Returns true if p is a long string type }
    function Is_LongString(P : TDef) : Boolean;

    {# returns true if p is a wide string type }
    function Is_WideString(P : TDef) : Boolean;

    {# true if p is an unicode string def }
    function Is_UnicodeString(P : TDef) : Boolean;

    {# true if p is an unicode/wide/ansistring string def }
    function Is_DynamicString(P : TDef) : Boolean;

    {# returns true if p is a wide or unicode string type }
    function Is_Wide_Or_Unicode_String(P : TDef) : Boolean;

    {# Returns true if p is a short string type }
    function Is_ShortString(P : TDef) : Boolean;

    {# Returns true if p is any pointer def }
    function Is_Pointer(P : TDef) : Boolean;

    {# Returns true p is an address: pointer, classref, ansistring, ... }
    function Is_Address(P : TDef) : Boolean;

    {# Returns true if p is a pchar def }
    function Is_PChar(P : TDef) : Boolean;

    {# Returns true if p is a pwidechar def }
    function Is_PWideChar(P : TDef) : Boolean;

    {# Returns true if p is a voidpointer def }
    function Is_VoidPointer(P : TDef) : Boolean;

    {# Returns true if p is a cyclic reference (refers to itself at some point via pointer or array) }
    function Is_Cyclic(P : TDef): Boolean; {$ifdef USEINLINE}inline;{$endif USEINLINE}

    {# Returns true, if definition is a float }
    function Is_FPU(Def : TDef) : Boolean;

    {# Returns true, if def is a currency type }
    function Is_Currency(Def : TDef) : Boolean;

    {# Returns true, if def is a comp type (handled by the fpu) }
    function Is_FPUComp(Def : TDef) : Boolean;

    {# Returns true, if def is a single type }
    function Is_Single(Def : TDef) : Boolean;

    {# Returns true, if def is a double type }
    function Is_Double(Def : TDef) : Boolean;

    {# Returns true, if def is an extended type }
    function Is_Extended(Def : TDef) : Boolean;

    {# Returns true, if definition is a "real" real (i.e. single/double/extended) }
    function Is_Real(Def : TDef) : Boolean;

    {# Returns true for single,double,extended and cextended }
    function Is_Real_Or_CExtended(Def : TDef) : Boolean;

    { true, if def is a 8 bit int type }
    function Is_8BitInt(Def : TDef) : Boolean;

    { true, if def is a 8 bit ordinal type }
    function Is_8Bit(Def : TDef) : Boolean;

    { true, if def is a 16 bit int type }
    function Is_16BitInt(Def : TDef) : Boolean;

    { true, if def is a 16 bit ordinal type }
    function Is_16Bit(Def : TDef) : Boolean;

    {# Returns true, if def is a 32 bit integer type }
    function Is_32BitInt(Def : TDef) : Boolean;

    {# Returns true, if def is a 32 bit ordinal type }
    function Is_32Bit(Def : TDef) : Boolean;

    {# Returns true, if def is a 64 bit integer type }
    function Is_64BitInt(Def : TDef) : Boolean;

    {# Returns true, if def is a 64 bit signed integer type }
    function Is_S64BitInt(Def : TDef) : Boolean;

    {# Returns true, if def is a qword type }
    function Is_U64BitInt(Def : TDef) : Boolean;

    {# Returns true, if def is a 64 bit ordinal type }
    function Is_64Bit(Def : TDef) : Boolean;

    { returns true, if def is a longint type }
    function Is_S32BitInt(Def : TDef) : Boolean;

    { returns true, if def is a dword type }
    function Is_U32BitInt(Def : TDef) : Boolean;

    { true, if def1 and def2 are both integers of the same bit size and sign }
    function Are_Equal_Ints(Def1, Def2: TDef): Boolean;

    { true, if def is an int type, larger than the processor's native int size }
    function Is_OversizedInt(Def : TDef) : Boolean;

    { true, if def is an ordinal type, larger than the processor's native int size }
    function Is_OversizedOrd(Def : TDef) : Boolean;

    { true, if def is an int type, equal in size to the processor's native int size }
    function Is_NativeInt(Def : TDef) : Boolean;

    { true, if def is an ordinal type, equal in size to the processor's native int size }
    function Is_NativeOrd(Def : TDef) : Boolean;

    { true, if def is an unsigned int type, equal in size to the processor's native int size }
    function Is_NativeUInt(Def : TDef) : Boolean;

    { true, if def is a signed int type, equal in size to the processor's native int size }
    function Is_NativeSInt(Def : TDef) : Boolean;

    { true, if the char type is a widechar in the system unit }
    function Is_SystemUnit_Unicode : Boolean;

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
    procedure AdaptRange(ToDef : TDef;var L : TConstExprInt; RangeCheck: TPerformRangeCheck);
    { for when used with nf_explicit/nf_internal/cs_check_range nodeflags }
    procedure AdaptRange(ToDef : TDef;var L : TConstExprInt; Internal, Explicit, RangeCheckState: Boolean);

    {# Returns the range of def, where @var(l) is the low-range and @var(h) is
      the high-range.
    }
    procedure GetRange(Def : TDef;out L, H : TConstExprInt);
    procedure GetRangeDefMaskSize(Def: TDef; out RangeDef: TDef; out Mask: TConstExprInt; out Size: LongInt);

    { Returns the range type of an ordinal type in the sense of ISO-10206 }
    function Get_Iso_Range_Type(Def: TDef): TDef;

    { is the type a vector, or can it be transparently used as one? }
    function Is_Vector(P : TDef) : Boolean;

    { return a real/hardware vectordef representing this def }
    function To_HWVectorDef(P: TDef; NilOnError: Boolean): TDef;

    { returns if the passed type (array) fits into an mm register }
    function Fits_In_MM_Register(P : TDef) : Boolean;

    {# From a definition return the abstract code generator size enum. It is
       to note that the value returned can be @var(OS_NO) }
    function Def_CGSize(Def: TDef): TCgSize;

    { #Return an orddef (integer) corresponding to a tcgsize }
    function CGSize_OrdDef(Size: TCgSize): TOrdDef;

    {# Same as def_cgsize, except that it will interpret certain arrays as
       vectors and return OS_M* sizes for them }
    function Def_CGMMSize(Def: TDef): TCgSize;

    {# returns true, if the type passed is can be used with windows automation }
    function Is_Automatable(P : TDef) : Boolean;

    { # returns true if the procdef has no parameters and no specified return type }
    function Is_BareProcDef(PD : TProcDef): Boolean;

    { returns true if the procdef is a C-style variadic function }
    function Is_C_Variadic(PD: TAbstractProcDef): Boolean; {$ifdef USEINLINE}inline;{$endif}

    { # returns the smallest base integer type whose range encompasses that of
        both ld and rd; if keep_sign_if_equal, then if ld and rd have the same
        signedness, the result will also get that signedness }
    function Get_Common_IntDef(LD, RD: TOrdDef; KeepSignIfEqual: Boolean): TOrdDef;

    { # calculates "not v" based on the provided def; returns true if the def
        was negligible, false otherwise }
    function Calc_Not_OrdValue(var V:TConstExprInt; var Def:TDef):Boolean;

    { # returns whether the type is potentially a valid type of/for an "univ" parameter
        (basically: it must have a compile-time size) }
    function Is_Valid_Univ_Para_Type(Def: TDef): Boolean;

    { # returns whether the procdef/procvardef represents a nested procedure
        or not }
    function Is_Nested_PD(Def: TAbstractProcDef): Boolean;{$ifdef USEINLINE}inline;{$endif}

    { # returns whether def is a type parameter of a generic }
    function Is_TypeParam(Def : TDef) : Boolean;{$ifdef USEINLINE}inline;{$endif}

    { returns true of def is a methodpointer }
    function Is_MethodPointer(Def : TDef) : Boolean;

    { returns true if def is a function reference }
    function Is_FuncRef(Def:TDef):Boolean;

    { returns true if def is an invokable interface }
    function Is_Invokable(Def:TDef):Boolean;

    { returns true if def is a C "block" }
    function Is_Block(Def: TDef): Boolean;

    { returns the TTypeKind value of the def }
    function Get_TypeKind(Def: TDef): Byte;

    { returns the Invoke procdef of a function reference interface }
    function Get_Invoke_ProcDef(Def:TObjectDef):TProcDef;

    { returns whether the invokable has an Invoke overload that can be called
      without arguments }
    function Invokable_Has_Argless_Invoke(Def:TObjectDef):Boolean;

implementation

    uses
       Verbose,CUtils,
       SymTable, // search_system_type
       SymSym,
       CPUInfo;

    { returns true, if def uses FPU }
    function Is_FPU(Def : TDef) : Boolean;
      begin
         Is_FPU:=(Def.Typ=FloatDef);
      end;


    { returns true, if def is a currency type }
    function Is_Currency(Def : TDef) : Boolean;
      begin
         if not Assigned(Def) then
           begin
             Result:=False;
             Exit;
           end;

         case S64CurrencyType.Typ of
           OrdDef :
             Result:=(Def.Typ=OrdDef) and
                     (TOrdDef(S64CurrencyType).OrdType=TOrdDef(Def).OrdType);
           FloatDef :
             Result:=(Def.Typ=FloatDef) and
                     (TFloatDef(S64CurrencyType).FloatType=TFloatDef(Def).FloatType);
           else
             InternalError(200304222);
         end;
      end;


    function Is_FPUComp(Def: TDef): Boolean;
      begin
        Result:=(Def.Typ=FloatDef) and
           (TFloatDef(Def).FloatType=S64Comp);
      end;

    { returns true, if def is a single type }
    function Is_Single(Def : TDef) : Boolean;
      begin
        Result:=(Def.Typ=FloatDef) and
          (TFloatDef(Def).FloatType=S32Real);
      end;


    { returns true, if def is a double type }
    function Is_Double(Def : TDef) : Boolean;
      begin
        Result:=(Def.Typ=FloatDef) and
          (TFloatDef(Def).FloatType=S64Real);
      end;


    { returns true, if def is an extended type }
    function Is_Extended(Def : TDef) : Boolean;
      begin
        Result:=(Def.Typ=FloatDef) and
          (TFloatDef(Def).FloatType in [S80Real,SC80Real]);
      end;


    { returns true, if definition is a "real" real (i.e. single/double/extended) }
    function Is_Real(Def : TDef) : Boolean;
      begin
        Result:=(Def.Typ=FloatDef) and
          (TFloatDef(Def).FloatType in [S32Real,S64Real,S80Real]);
      end;


    function Is_Real_Or_CExtended(Def: TDef): Boolean;
      begin
        Result:=(Def.Typ=FloatDef) and
          (TFloatDef(Def).FloatType in [S32Real,S64Real,S80Real,SC80Real]);
      end;


    function Range_To_BaseType(const L,H:TConstExprInt):TOrdType;
      begin
        { prefer signed over unsigned }
        if (L>=Int64(-128)) and (H<=127) then
         Range_To_BaseType:=S8Bit
        else if (L>=0) and (H<=255) then
         Range_To_BaseType:=U8Bit
        else if (L>=Int64(-32768)) and (H<=32767) then
         Range_To_BaseType:=S16Bit
        else if (L>=0) and (H<=65535) then
         Range_To_BaseType:=U16Bit
        else if (L>=Int64(Low(LongInt))) and (H<=High(LongInt)) then
         Range_To_BaseType:=S32Bit
        else if (L>=Low(Cardinal)) and (H<=High(Cardinal)) then
         Range_To_BaseType:=U32Bit
        else if (L>=Low(Int64)) and (H<=High(Int64)) then
         Range_To_BaseType:=S64Bit
        else
         Range_To_BaseType:=U64Bit;
      end;


    procedure Range_To_Type(const L,H:TConstExprInt;var Def:TDef);
      begin
        { prefer signed over unsigned }
        if (L>=Int64(-128)) and (H<=127) then
         Def:=S8IntType
        else if (L>=0) and (H<=255) then
         Def:=U8IntType
        else if (L>=Int64(-32768)) and (H<=32767) then
         Def:=S16IntType
        else if (L>=0) and (H<=65535) then
         Def:=U16IntType
        else if (L>=Int64(Low(LongInt))) and (H<=High(LongInt)) then
         Def:=S32IntType
        else if (L>=Low(Cardinal)) and (H<=High(Cardinal)) then
         Def:=U32IntType
        else if (L>=Low(Int64)) and (H<=High(Int64)) then
         Def:=S64IntType
        else
         Def:=U64IntType;
      end;


    procedure Int_To_Type(const V:TConstExprInt;var Def:TDef);
      begin
        Range_To_Type(V,V,Def);
      end;


    { true if p is an ordinal }
    function Is_Ordinal(Def : TDef) : Boolean;
      var
         DT : TOrdType;
      begin
         case Def.Typ of
           OrdDef :
             begin
               DT:=TOrdDef(Def).OrdType;
               Is_Ordinal:=DT in [UChar,UWideChar,
                                  U8Bit,U16Bit,U32Bit,U64Bit,
                                  S8Bit,S16Bit,S32Bit,S64Bit,
                                  PasBool1,PasBool8,PasBool16,PasBool32,PasBool64,
                                  Bool8Bit,Bool16Bit,Bool32Bit,Bool64Bit,CustomInt];
             end;
           EnumDef :
             Is_Ordinal:=True;
           else
             Is_Ordinal:=False;
         end;
      end;

    { true if p is a string }
    function Is_String(Def : TDef) : Boolean;
      begin
        Is_String := (Assigned(Def) and (Def.Typ = StringDef));
      end;

    function Is_StringLike(Def : TDef) : Boolean;
      begin
        Result := Is_String(Def) or
                  Is_AnyChar(Def) or
                  Is_PChar(Def) or
                  Is_PWideChar(Def) or
                  Is_CharArray(Def) or
                  Is_WideCharArray(Def) or
                  Is_Open_CharArray(Def) or
                  Is_Open_WideCharArray(Def);
      end;

    function CharType_For_StringLike(Def : TDef) : TDef;
      begin
        if Is_String(Def) then
          Result:=TStringDef(Def).Get_Default_Char_Type
        else if Is_AnyChar(Def) then
          Result:=Def
        else if Is_PChar(Def) or Is_CharArray(Def) or Is_Open_CharArray(Def) then
          Result:=CAnsiCharType
        else if Is_PWideChar(Def) or Is_PWideChar(Def) or Is_Open_WideCharArray(Def) then
          Result:=CWideCharType
        else
          InternalError(2023012501);
      end;

    function Is_Enum(Def : TDef) : Boolean;
      begin
        Result:=Def.Typ=EnumDef;
      end;

    function Is_Set(Def : TDef) : Boolean;
      begin
        Result:=Def.Typ=SetDef;
      end;

    { returns the min. value of the type }
    function Get_Min_Value(Def : TDef) : TConstExprInt;
      begin
         case Def.Typ of
           OrdDef:
             Result:=TOrdDef(Def).Low;
           EnumDef:
             Result:=Int64(TEnumDef(Def).Min);
           else
             Result:=0;
         end;
      end;


    { returns the max. value of the type }
    function Get_Max_Value(Def : TDef) : TConstExprInt;
      begin
         case Def.Typ of
           OrdDef:
             Result:=TOrdDef(Def).High;
           EnumDef:
             Result:=TEnumDef(Def).Max;
           else
             Result:=0;
         end;
      end;


    function Spans_Entire_Range(Def: TDef): Boolean;
      var
         LV, HV: TConstExprInt;
         Mask: QWord;
         Size: LongInt;
      begin
        case Def.Typ of
          OrdDef,
          EnumDef:
            GetRange(Def,LV,HV);
          else
            InternalError(2019062203);
        end;
        Size:=Def.Size;
        case Size of
          1: Mask:=$ff;
          2: Mask:=$ffff;
          4: Mask:=$ffffffff;
          8: Mask:=QWord(-1);
          else
            InternalError(2019062204);
        end;
        Result:=False;
        if Is_Signed(Def) then
          begin
            if (LV.UValue and Mask)<>(QWord(1) shl (Size*8-1)) then
              Exit;
            if (HV.UValue and Mask)<>(Mask shr 1) then
              Exit;
          end
        else
          begin
            if LV<>0 then
              Exit;
            if HV.UValue<>Mask then
              Exit;
          end;
        Result:=True;
      end;


    { true if p is an integer }
    function Is_Integer(Def : TDef) : Boolean;
      begin
        Result:=(Def.Typ=OrdDef) and
                    (TOrdDef(Def).OrdType in [U8Bit,U16Bit,U32Bit,U64Bit,
                                          S8Bit,S16Bit,S32Bit,S64Bit,
                                          CustomInt]);
      end;


    { true if p is a boolean }
    function Is_Boolean(Def : TDef) : Boolean;
      begin
        Result:=(Def.Typ=OrdDef) and
                    (TOrdDef(Def).OrdType in [PasBool1,PasBool8,PasBool16,PasBool32,PasBool64,Bool8Bit,Bool16Bit,Bool32Bit,Bool64Bit]);
      end;


    function Is_PasBool(Def : TDef) : Boolean;
      begin
        Result:=(Def.Typ=OrdDef) and
                    (TOrdDef(Def).OrdType in [PasBool1,PasBool8,PasBool16,PasBool32,PasBool64]);
      end;

    { true if def is a C-style boolean (non-zero value = true, zero = false) }
    function Is_CBool(Def : TDef) : Boolean;
      begin
        Result:=(Def.Typ=OrdDef) and
                    (TOrdDef(Def).OrdType in [Bool8Bit,Bool16Bit,Bool32Bit,Bool64Bit]);
      end;


    { true if p is a void }
    function Is_Void(Def : TDef) : Boolean;
      begin
        Result:=(Def.Typ=OrdDef) and
                 (TOrdDef(Def).OrdType=UVoid);
      end;


    { true if p is a char }
    function Is_Char(Def : TDef) : Boolean;
      begin
        Result:=(Def.Typ=OrdDef) and
                 (TOrdDef(Def).OrdType=UChar);
      end;


    { true if p is a wchar }
    function Is_WideChar(Def : TDef) : Boolean;
      begin
        Result:=(Def.Typ=OrdDef) and
                 (TOrdDef(Def).OrdType=UWideChar);
      end;


    { true if p is a char or wchar }
    function Is_AnyChar(Def : TDef) : Boolean;
      begin
        Result:=(Def.Typ=OrdDef) and
                 (TOrdDef(Def).OrdType in [UChar,UWideChar])
      end;


    { true if p is signed (integer) }
    function Is_Signed(Def : TDef) : Boolean;
      begin
         case Def.Typ of
           OrdDef :
             Result:=TOrdDef(Def).Low < 0;
           EnumDef :
             Result:=TEnumDef(Def).Min < 0;
           ArrayDef :
             Result:=Is_Signed(TArrayDef(Def).RangeDef);
           else
             Result:=False;
         end;
      end;


    function Get_Unsigned_IntType(Def: TDef): TOrdDef;
      begin
        case Def.Typ of
          OrdDef,
          EnumDef:
            Result:=CGSize_OrdDef(TCgSize2Unsigned[Def_CGSize(Def)]);
          else
            InternalError(2016062001);
        end;
      end;


    function Get_Signed_IntType(Def: TDef): TOrdDef;
      begin
        case Def.Typ of
          OrdDef,
          EnumDef:
            Result:=CGSize_OrdDef(TCgSize2Signed[Def_CGSize(Def)]);
          else
            InternalError(2022093007);
        end;
      end;


    function Is_In_Limit(DefFrom,DefTo : TDef) : Boolean;

      begin
         if (DefFrom.Typ<>DefTo.Typ) or
            not(DefFrom.Typ in [OrdDef,EnumDef,SetDef]) then
           begin
             Is_In_Limit := False;
             Exit;
           end;
         case DefFrom.Typ of
           OrdDef:
             Is_In_Limit:=(TOrdDef(DefFrom).Low>=TOrdDef(DefTo).Low) and
                          (TOrdDef(DefFrom).High<=TOrdDef(DefTo).High);
           EnumDef:
             Is_In_Limit:=(TEnumDef(DefFrom).Min>=TEnumDef(DefTo).Min) and
                          (TEnumDef(DefFrom).Max<=TEnumDef(DefTo).Max);
           SetDef:
             Is_In_Limit:=(TSetDef(DefFrom).SetLow>=TSetDef(DefTo).SetLow) and
                          (TSetDef(DefFrom).SetMax<=TSetDef(DefTo).SetMax);
         else
           Is_In_Limit:=False;
         end;
      end;


    function Is_Managed_Type(Def: TDef): Boolean;{$ifdef USEINLINE}inline;{$endif}
      begin
        Result:=Def.NeedsInitTable;
      end;


    function Is_RTTI_Managed_Type(Def: TDef): Boolean;
      begin
        Result:=Def.NeedsInitTable and not (
          Is_InterfaceCOM_Or_DispInterface(Def) or
          (Def.Typ=VariantDef) or
          (
            (Def.Typ=StringDef) and
            (TStringDef(Def).StringType in [st_ansistring,st_widestring,st_unicodestring])
          )
        );
      end;


    { true, if p points to an open array def }
    function Is_Open_String(P : TDef) : Boolean;
      begin
         Is_Open_String:=(P.Typ=StringDef) and
                         (TStringDef(P).StringType=st_shortstring) and
                         (TStringDef(P).Len=0);
      end;


    { true, if p points to a zero based array def }
    function Is_Zero_Based_Array(P : TDef) : Boolean;
      begin
         Result:=(P.Typ=ArrayDef) and
                 (TArrayDef(P).LowRange=0) and
                 not(Is_Special_Array(P));
      end;

    { true if p points to a dynamic array def }
    function Is_Dynamic_Array(P : TDef) : Boolean;
      begin
         Result:=(P.Typ=ArrayDef) and
                 (ado_IsDynamicArray in TArrayDef(P).ArrayOptions);
      end;


    { true, if p points to an open array def }
    function Is_Open_Array(P : TDef) : Boolean;
      begin
         { check for sizesinttype is needed, because for unsigned the high
           range is also -1 ! (PFV) }
         Result:=(P.Typ=ArrayDef) and
                 (TArrayDef(P).RangeDef=SizeSIntType) and
                 (ado_OpenArray in TArrayDef(P).ArrayOptions) and
                 ((TArrayDef(P).ArrayOptions * [ado_IsVariant,ado_IsArrayOfConst,ado_IsConstructor,ado_IsDynamicArray])=[]);
      end;

    { true, if p points to an array of const def }
    function Is_Array_Constructor(P : TDef) : Boolean;
      begin
         Result:=(P.Typ=ArrayDef) and
                 (ado_IsConstructor in TArrayDef(P).ArrayOptions);
      end;

    { true, if p points to a variant array }
    function Is_Variant_Array(P : TDef) : Boolean;
      begin
         Result:=(P.Typ=ArrayDef) and
                 (ado_IsVariant in TArrayDef(P).ArrayOptions);
      end;

    { true, if p points to an array of const }
    function Is_Array_Of_Const(P : TDef) : Boolean;
      begin
         Result:=(P.Typ=ArrayDef) and
                 (ado_IsArrayOfConst in TArrayDef(P).ArrayOptions) and
                 { consider it an array-of-const in the strict sense only if it
                   isn't an array constructor }
                 not (ado_IsConstructor in TArrayDef(P).ArrayOptions);
      end;

    function Is_ConstString_Array(P: TDef): Boolean;
      begin
        Result:=(P.Typ=ArrayDef) and
                (ado_IsConstString in TArrayDef(P).ArrayOptions);
      end;

    { true, if p points to a special array, bitpacked arrays aren't special in this regard though }
    function Is_Special_Array(P : TDef) : Boolean;
      begin
         Result:=(P.Typ=ArrayDef) and
                 (
                  ((TArrayDef(P).ArrayOptions * [ado_IsVariant,ado_IsArrayOfConst,ado_IsConstructor,ado_IsDynamicArray])<>[]) or
                  Is_Open_Array(P)
                 );
      end;

    { true, if p points to a normal array, bitpacked arrays are included }
    function Is_Normal_Array(P : TDef) : Boolean;
      begin
         Result:=(P.Typ=ArrayDef) and
                 ((TArrayDef(P).ArrayOptions * [ado_IsVariant,ado_IsArrayOfConst,ado_IsConstructor,ado_IsDynamicArray])=[]) and
                 not(Is_Open_Array(P));
      end;

    { true if p is an ansi string def }
    function Is_AnsiString(P : TDef) : Boolean;
      begin
         Is_AnsiString:=(P.Typ=StringDef) and
                        (TStringDef(P).StringType=st_ansistring);
      end;

    { true if p is an ansi string def with codepage CP_NONE }
    function Is_RawByteString(P : TDef) : Boolean;
      begin
        Is_RawByteString:=(P.Typ=StringDef) and
                       (TStringDef(P).StringType=st_ansistring) and
                       (TStringDef(P).Encoding=Globals.CP_NONE);
      end;

    { true if p is an long string def }
    function Is_LongString(P : TDef) : Boolean;
      begin
         Is_LongString:=(P.Typ=StringDef) and
                        (TStringDef(P).StringType=st_longstring);
      end;


    { true if p is an wide string def }
    function Is_WideString(P : TDef) : Boolean;
      begin
         Is_WideString:=(P.Typ=StringDef) and
                        (TStringDef(P).StringType=st_widestring);
      end;


    function Is_DynamicString(P: TDef): Boolean;
      begin
         Is_DynamicString:=(P.Typ=StringDef) and
                        (TStringDef(P).StringType in [st_ansistring,st_widestring,st_unicodestring]);
      end;


    { true if p is an wide string def }
    function Is_Wide_Or_Unicode_String(P : TDef) : Boolean;
      begin
         Is_Wide_Or_Unicode_String:=(P.Typ=StringDef) and
                        (TStringDef(P).StringType in [st_widestring,st_unicodestring]);
      end;


    { true if p is an unicode string def }
    function Is_UnicodeString(P : TDef) : Boolean;
      begin
         Is_UnicodeString:=(P.Typ=StringDef) and
                        (TStringDef(P).StringType=st_unicodestring);
      end;


    { true if p is an short string def }
    function Is_ShortString(P : TDef) : Boolean;
      begin
         Is_ShortString:=(P.Typ=StringDef) and
                         (TStringDef(P).StringType=st_shortstring);
      end;


    { true if p is bit packed array def }
    function Is_Packed_Array(P: TDef) : Boolean;
      begin
        Is_Packed_Array :=
           (P.Typ = ArrayDef) and
           (ado_IsBitPacked in TArrayDef(P).ArrayOptions);
      end;


    { true if p is bit packed record def }
    function Is_Packed_Record_Or_Object(P: TDef) : Boolean;
      begin
        Is_Packed_Record_Or_Object :=
           (P.Typ in [RecordDef,ObjectDef]) and
           (TAbstractRecordDef(P).Is_Packed);
      end;


    { true if p is a char array def }
    function Is_CharArray(P : TDef) : Boolean;
      begin
        Is_CharArray:=(P.Typ=ArrayDef) and
                      Is_Char(TArrayDef(P).ElementDef) and
                      not(Is_Special_Array(P));
      end;

    { true if p is a widechar array def }
    function Is_WideCharArray(P : TDef) : Boolean;
      begin
        Is_WideCharArray:=(P.Typ=ArrayDef) and
                          Is_WideChar(TArrayDef(P).ElementDef) and
                          not(Is_Special_Array(P));
      end;


    { true if p is a open char array def }
    function Is_Open_CharArray(P : TDef) : Boolean;
      begin
        Is_Open_CharArray:= Is_Open_Array(P) and
                            Is_Char(TArrayDef(P).ElementDef);
      end;

    { true if p is a open wide char array def }
    function Is_Open_WideCharArray(P : TDef) : Boolean;
      begin
        Is_Open_WideCharArray:= Is_Open_Array(P) and
                                Is_WideChar(TArrayDef(P).ElementDef);
      end;

    { true if p is any pointer def }
    function Is_Pointer(P : TDef) : Boolean;
      begin
        Is_Pointer:=(P.Typ=PointerDef);
      end;

    function Is_Address(P: TDef): Boolean;
      begin
        Is_Address:=
          (P.Typ in [ClassRefDef,FormalDef,UndefinedDef,ProcDef]) or
          Is_Pointer(P) or
          Is_Implicit_Array_Pointer(P) or
          Is_Implicit_Pointer_Object_Type(P) or
          ((P.Typ=ProcVarDef) and
           (TProcVarDef(P).Is_AddressOnly or
            Is_Block(P)
           )
          )
      end;

    { true if p is a pchar def }
    function Is_PChar(P : TDef) : Boolean;
      begin
        Is_PChar:=(P.Typ=PointerDef) and
                  (Is_Char(TPointerDef(P).PointedDef) or
                   (Is_Zero_Based_Array(TPointerDef(P).PointedDef) and
                    Is_CharArray(TPointerDef(P).PointedDef)));
      end;

    { true if p is a pwidechar def }
    function Is_PWideChar(P : TDef) : Boolean;
      begin
        Is_PWideChar:=(P.Typ=PointerDef) and
                      (Is_WideChar(TPointerDef(P).PointedDef) or
                       (Is_Zero_Based_Array(TPointerDef(P).PointedDef) and
                        Is_WideCharArray(TPointerDef(P).PointedDef)));
      end;


    { true if p is a voidpointer def }
    function Is_VoidPointer(P : TDef) : Boolean;
      begin
        Is_VoidPointer:=(P.Typ=PointerDef) and
                        (TPointerDef(P).PointedDef.Typ=OrdDef) and
                        (TOrdDef(TPointerDef(P).PointedDef).OrdType=UVoid);
      end;


    type
      PDefListItem = ^TDefListItem;
      TDefListItem = record
        Next: PDefListItem;
        Def: TDef;
      end;

    { See "is_cyclic" below }
    function IsCyclicInternal(const Def: TDef; const First: PDefListItem): Boolean;
      var
        ThisDef: TDefListItem;
        CurItem: PDefListItem;
      begin
        if not (Def.Typ in [ArrayDef, PointerDef]) then
          Exit(False);

        CurItem := First;
        while Assigned(CurItem) do
          begin
            if CurItem^.Def = Def then
              Exit(True);
            CurItem := CurItem^.Next;
          end;

        ThisDef.Next := First;
        ThisDef.Def := Def;

        case Def.Typ of
          ArrayDef:
            Result := IsCyclicInternal(TArrayDef(Def).ElementDef, @ThisDef);
          PointerDef:
            Result := IsCyclicInternal(TAbstractPointerDef(Def).PointedDef, @ThisDef);
          else
            InternalError(2022120301);
        end;
      end;

    { true, if p is a cyclic reference (refers to itself at some point via pointer or array) }
    function Is_Cyclic(P : TDef): Boolean; {$ifdef USEINLINE}inline;{$endif USEINLINE}
      begin
        Result := IsCyclicInternal(P, nil);
      end;

    { true, if def is a 8 bit int type }
    function Is_8BitInt(Def : TDef) : Boolean;
      begin
         Result:=(Def.Typ=OrdDef) and (TOrdDef(Def).OrdType in [U8Bit,S8Bit])
      end;

    { true, if def is a 8 bit ordinal type }
    function Is_8Bit(Def : TDef) : Boolean;
      begin
         Result:=(Def.Typ=OrdDef) and (TOrdDef(Def).OrdType in [U8Bit,S8Bit,PasBool1,PasBool8,Bool8Bit,UChar])
      end;

    { true, if def is a 16 bit int type }
    function Is_16BitInt(Def : TDef) : Boolean;
      begin
         Result:=(Def.Typ=OrdDef) and (TOrdDef(Def).OrdType in [U16Bit,S16Bit])
      end;

    { true, if def is a 16 bit ordinal type }
    function Is_16Bit(Def : TDef) : Boolean;
      begin
         Result:=(Def.Typ=OrdDef) and (TOrdDef(Def).OrdType in [U16Bit,S16Bit,PasBool16,Bool16Bit,UWideChar])
      end;

    { true, if def is a 32 bit int type }
    function Is_32BitInt(Def : TDef) : Boolean;
      begin
         Result:=(Def.Typ=OrdDef) and (TOrdDef(Def).OrdType in [U32Bit,S32Bit])
      end;

    { true, if def is a 32 bit ordinal type }
    function Is_32Bit(Def: TDef): Boolean;
      begin
         Result:=(Def.Typ=OrdDef) and (TOrdDef(Def).OrdType in [U32Bit,S32Bit,PasBool32,Bool32Bit])
      end;


    { true, if def is a 64 bit int type }
    function Is_64BitInt(Def : TDef) : Boolean;
      begin
         Is_64BitInt:=(Def.Typ=OrdDef) and (TOrdDef(Def).OrdType in [U64Bit,S64Bit])
      end;


    function Is_S64BitInt(Def: TDef): Boolean;
      begin
        Is_S64BitInt:=(Def.Typ=OrdDef) and (TOrdDef(Def).OrdType=S64Bit)
      end;


    function Is_U64BitInt(Def: TDef): Boolean;
      begin
        Is_U64BitInt:=(Def.Typ=OrdDef) and (TOrdDef(Def).OrdType=U64Bit)
      end;


    { true, if def is a 64 bit type }
    function Is_64Bit(Def : TDef) : Boolean;
      begin
         Is_64Bit:=(Def.Typ=OrdDef) and (TOrdDef(Def).OrdType in [U64Bit,S64Bit,SCurrency,PasBool64,Bool64Bit])
      end;


    { returns true, if def is a longint type }
    function Is_S32BitInt(Def : TDef) : Boolean;
      begin
        Result:=(Def.Typ=OrdDef) and
          (TOrdDef(Def).OrdType=S32Bit);
      end;


    { returns true, if def is a dword type }
    function Is_U32BitInt(Def : TDef) : Boolean;
      begin
        Result:=(Def.Typ=OrdDef) and
          (TOrdDef(Def).OrdType=U32Bit);
      end;


    { true, if def1 and def2 are both integers of the same bit size and sign }
    function Are_Equal_Ints(Def1, Def2: TDef): Boolean;
      begin
        Result:=(Def1.Typ=OrdDef) and (Def2.Typ=OrdDef) and
          (TOrdDef(Def1).OrdType in [U8Bit,U16Bit,U32Bit,U64Bit,
                                     S8Bit,S16Bit,S32Bit,S64Bit,CustomInt]) and
          (TOrdDef(Def1).OrdType=TOrdDef(Def2).OrdType) and
          ((TOrdDef(Def1).OrdType<>CustomInt) or
           ((TOrdDef(Def1).Low=TOrdDef(Def2).Low) and
            (TOrdDef(Def1).High=TOrdDef(Def2).High)));
      end;


    { true, if def is an int type, larger than the processor's native int size }
    function Is_OversizedInt(Def : TDef) : Boolean;
      begin
{$if defined(cpu32bitaddr)}
         Result:=Is_64BitInt(Def);
{$elseif defined(cpu64bitaddr)}
         Result:=False;
{$endif}
      end;

    { true, if def is an ordinal type, larger than the processor's native int size }
    function Is_OversizedOrd(Def : TDef) : Boolean;
      begin
{$if defined(cpu32bitaddr)}
         Result:=Is_64Bit(Def);
{$elseif defined(cpu64bitaddr)}
         Result:=False;
{$endif}
      end;


    { true, if def is an int type, equal in size to the processor's native int size }
    function Is_NativeInt(Def: TDef): Boolean;
      begin
{$if defined(cpu32bitaddr)}
         Result:=Is_32BitInt(Def);
{$elseif defined(cpu64bitaddr)}
         Result:=Is_64BitInt(Def);
{$endif}
      end;

    { true, if def is an ordinal type, equal in size to the processor's native int size }
    function Is_NativeOrd(Def: TDef): Boolean;
      begin
{$if defined(cpu32bitaddr)}
         Result:=Is_32Bit(Def);
{$elseif defined(cpu64bitaddr)}
         Result:=Is_64Bit(Def);
{$endif}
      end;

    { true, if def is an unsigned int type, equal in size to the processor's native int size }
    function Is_NativeUInt(Def: TDef): Boolean;
      begin
         Result:=Is_NativeInt(Def) and (Def.Typ=OrdDef) and (TOrdDef(Def).OrdType in [U64Bit,U32Bit,U16Bit,U8Bit]);
      end;

    { true, if def is a signed int type, equal in size to the processor's native int size }
    function Is_NativeSInt(Def: TDef): Boolean;
      begin
         Result:=Is_NativeInt(Def) and (Def.Typ=OrdDef) and (TOrdDef(Def).OrdType in [S64Bit,S32Bit,S16Bit,S8Bit]);
      end;

    function Is_SystemUnit_Unicode: Boolean;

    var
      T : TTypeSym;

    begin
      if CCharType=nil then
        begin
          T:=Search_System_Type('CHAR');
          if T<>nil then
            CCharType:=T.TypeDef;
        end;
      if CCharType=nil then
        Is_SystemUnit_Unicode:=(SizeOf(Char)=2)
      else
        Is_SystemUnit_Unicode:=(CCharType.Size=2);
    end;

    { if l isn't in the range of todef a range check error (if not explicit) is generated and
      the value is placed within the range }
    procedure AdaptRange(ToDef : TDef;var L : TConstExprInt; RangeCheck: TPerformRangeCheck);
      var
         LV,HV,OldVal,SExtVal,Mask: TConstExprInt;
         RangeDef: TDef;
         RangeDefSize: LongInt;
         Warned: Boolean;
      begin
         GetRange(ToDef,LV,HV);
         if (L<LV) or (L>HV) then
           begin
             Warned:=False;
             if RangeCheck in [rc_implicit,rc_yes] then
               begin
                 if (RangeCheck=rc_yes) or
                    (ToDef.Typ=EnumDef) then
                   Message3(type_e_range_check_error_bounds,ToStr(L),ToStr(LV),ToStr(HV))
                 else
                   Message3(type_w_range_check_error_bounds,ToStr(L),ToStr(LV),ToStr(HV));
                 Warned:=True;
               end
             { give warnings about range errors with explicit typeconversions if the target
               type does not span the entire range that can be represented by its bits
               (subrange type or enum), because then the result is undefined }
             else if (RangeCheck<>rc_internal) and
                     (not Is_PasBool(ToDef) and
                      not Spans_Entire_Range(ToDef)) then
               begin
                 Message3(type_w_range_check_error_bounds,ToStr(L),ToStr(LV),ToStr(HV));
                 Warned:=True;
               end;

             { Fix the value to fit in the allocated space for this type of variable }
             OldVal:=L;
             GetRangeDefMaskSize(ToDef,RangeDef,Mask,RangeDefSize);
             L:=L and Mask;
             {reset sign, i.e. converting -1 to qword changes the value to high(qword)}
             L.Signed:=False;
             SExtVal:=0;
             { do sign extension if necessary (JM) }
             case RangeDefSize of
               1: SExtVal.SValue:=ShortInt(L.SValue);
               2: SExtVal.SValue:=SmallInt(L.SValue);
               4: SExtVal.SValue:=LongInt(L.SValue);
               8: SExtVal.SValue:=L.SValue;
               else
                 InternalError(201906230);
              end;
              SExtVal.Signed:=True;
              { Detect if the type spans the entire range, but more bits were specified than
                the type can contain, e.g. shortint($fff).
                However, none of the following should result in a warning:
                  1) shortint($ff) (-> $ff -> $ff -> $ffff ffff ffff ffff)
                  2) shortint(longint(-1)) ($ffff ffff ffff ffff ffff -> $ff -> $ffff ffff ffff ffff
                  3) cardinal(-1) (-> $ffff ffff ffff ffff -> $ffff ffff)
              }
              if not Warned and
                (RangeCheck<>rc_internal) and
                (OldVal.UValue<>L.UValue) and
                (OldVal.UValue<>SExtVal.UValue) then
               begin
                 Message3(type_w_range_check_error_bounds,ToStr(OldVal),ToStr(LV),ToStr(HV));
               end;
              if Is_Signed(RangeDef) then
                L:=SExtVal;
           end;
      end;


    procedure AdaptRange(ToDef: TDef; var L: TConstExprInt; Internal, Explicit, RangeCheckState: Boolean);
      begin
        if Internal then
          AdaptRange(ToDef, L, rc_internal)
        else if Explicit then
          AdaptRange(ToDef, L, rc_explicit)
        else if not RangeCheckState then
          AdaptRange(ToDef, L, rc_implicit)
        else
          AdaptRange(ToDef, L, rc_yes)
      end;


    { return the range from def in l and h }
    procedure GetRange(Def : TDef;out L, H : TConstExprInt);
      begin
        case Def.Typ of
          OrdDef :
            begin
              L:=TOrdDef(Def).Low;
              H:=TOrdDef(Def).High;
            end;
          EnumDef :
            begin
              L:=Int64(TEnumDef(Def).Min);
              H:=Int64(TEnumDef(Def).Max);
            end;
          ArrayDef :
            begin
              L:=Int64(TArrayDef(Def).LowRange);
              H:=Int64(TArrayDef(Def).HighRange);
            end;
          UndefinedDef:
            begin
              L:=TOrdDef(SizeSIntType).Low;
              H:=TOrdDef(SizeSIntType).High;
            end;
          else
            InternalError(200611054);
        end;
      end;


    procedure GetRangeDefMaskSize(Def: TDef; out RangeDef: TDef; out Mask: TConstExprInt; out Size: LongInt);
      begin
        case Def.Typ of
          OrdDef, EnumDef:
            begin
              RangeDef:=Def;
              Size:=Def.Size;
              case Size of
                1: Mask:=$ff;
                2: Mask:=$ffff;
                4: Mask:=$ffffffff;
                8: Mask:=$ffffffffffffffff;
                else
                  InternalError(2019062305);
                end;
            end;
          ArrayDef:
            begin
              RangeDef:=TArrayDef(Def).RangeDef;
              GetRangeDefMaskSize(RangeDef,RangeDef,Mask,Size);
            end;
          UndefinedDef:
            begin
              RangeDef:=SizeSIntType;
              Size:=RangeDef.Size;
              Mask:=-1;
            end;
          else
            InternalError(2019062306);
        end;
      end;


    { The range-type of an ordinal-type that is a subrange-type shall be the host-type (see 6.4.2.4) of the subrange-type.
      The range-type of an ordinal-type that is not a subrange-type shall be the ordinal-type.

      The subrange-bounds shall be of compatible ordinal-types, and the range-type (see 6.4.2.1) of the ordinal-types shall
      be designated the host-type of the subrange-type. }
    function Get_Iso_Range_Type(Def: TDef): TDef;
      begin
        Result:=nil;
        case Def.Typ of
           OrdDef:
             begin
               if Is_Integer(Def) then
                 begin
                   if (TOrdDef(Def).Low>=TOrdDef(SIntType).Low) and
                      (TOrdDef(Def).High<=TOrdDef(SIntType).High) then
                     Result:=SIntType
                   else
                     Range_To_Type(TOrdDef(Def).Low,TOrdDef(Def).High,Result);
                 end
               else case TOrdDef(Def).OrdType of
                 PasBool1:
                   Result:=PasBool1Type;
                 PasBool8:
                   Result:=PasBool8Type;
                 PasBool16:
                   Result:=PasBool16Type;
                 PasBool32:
                   Result:=PasBool32Type;
                 PasBool64:
                   Result:=PasBool64Type;
                 Bool8Bit:
                   Result:=Bool8Type;
                 Bool16Bit:
                   Result:=Bool16Type;
                 Bool32Bit:
                   Result:=Bool32Type;
                 Bool64Bit:
                   Result:=Bool64Type;
                 UChar:
                   Result:=CAnsiCharType;
                 UWideChar:
                   Result:=CWideCharType;
                 SCurrency:
                   Result:=S64CurrencyType;
                 else
                   InternalError(2018010901);
               end;
             end;
           EnumDef:
             begin
               while Assigned(TEnumDef(Def).BaseDef) do
                 Def:=TEnumDef(Def).BaseDef;
               Result:=Def;
             end
           else
             InternalError(2018010701);
        end;
      end;


    function Is_Vector(P : TDef) : Boolean;
      begin
        Result:=(P.Typ=ArrayDef) and
                (TArrayDef(P).Is_HWVector { or
                 (not(is_special_array(p)) and
                  (tarraydef(p).elementdef.typ in [floatdef,orddef]) and
                  (tarraydef(p).elementdef.typ=floatdef) and
                  (tfloatdef(tarraydef(p).elementdef).floattype in [s32real,s64real])
                 ) }
                );
      end;


    { returns if the passed type (array) fits into an mm register }
    function Fits_In_MM_Register(P : TDef) : Boolean;
      begin
{$ifdef x86}
        Result:= Is_Vector(P) and
                 (
                  (
                   (TArrayDef(P).ElementDef.Typ=FloatDef) and
                   (
                    (TArrayDef(P).LowRange=0) and
                    ((TArrayDef(P).HighRange=3) or
                     (UseAVX and (TArrayDef(P).HighRange=7)) or
                     (UseAVX512 and (TArrayDef(P).HighRange=15))
                    ) and
                    (TFloatDef(TArrayDef(P).ElementDef).FloatType=S32Real)
                   )
                  ) or

                  (
                   (TArrayDef(P).ElementDef.Typ=FloatDef) and
                   (
                    (TArrayDef(P).LowRange=0) and
                    ((TArrayDef(P).HighRange=1) or
                     (UseAVX and (TArrayDef(P).HighRange=3)) or
                     (UseAVX512 and (TArrayDef(P).HighRange=7))
                    )and
                    (TFloatDef(TArrayDef(P).ElementDef).FloatType=S64Real)
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
        Result:=False;
{$endif x86}
      end;


    function To_HWVectorDef(P: TDef; NilOnError: Boolean): TDef;
      begin
        Result:=nil;
        if P.Typ=ArrayDef then
          begin
            if TArrayDef(P).Is_HWVector then
              Result:=P
            else if Fits_In_MM_Register(P) then
              Result:=CArrayDef.GetReusable_Vector(TArrayDef(P).ElementDef,TArrayDef(P).EleCount)
            else if not NilOnError then
              InternalError(2022090811);
          end
        else if not NilOnError then
          InternalError(2022090810);
      end;


    function Def_CGSize(Def: TDef): TCgSize;
      begin
        case Def.Typ of
          OrdDef,
          EnumDef,
          SetDef:
            begin
              Result:=Int_CGSize(Def.Size);
              if Is_Signed(Def) then
                Result:=TCgSize(Ord(Result)+(Ord(OS_S8)-Ord(OS_8)));
            end;
          ClassRefDef,
          PointerDef:
            begin
              Result:=Int_CGSize(Def.Size);
              { can happen for far/huge pointers on non-i8086 }
              if Result=OS_NO then
                InternalError(2013052201);
            end;
          FormalDef:
            Result := Int_CGSize(VoidPointerType.Size);
          ProcVarDef:
            Result:=Int_CGSize(Def.Size);
          StringDef :
            Result:=Int_CGSize(Def.Size);
          ObjectDef :
            Result:=Int_CGSize(Def.Size);
          FloatDef:
              Result:=TFloat2TCgSize[TFloatDef(Def).FloatType];
          RecordDef :
              Result:=Int_CGSize(Def.Size);
          ArrayDef :
            begin
              if Is_Dynamic_Array(Def) or not Is_Special_Array(Def) then
                begin
                  if Is_Vector(Def) and (TArrayDef(Def).ElementDef.Typ = FloatDef) then
                    begin
                      { Determine if, based on the floating-point type and the size
                        of the array, if it can be made into a vector }
                      case TFloatDef(TArrayDef(Def).ElementDef).FloatType of
                        S32Real:
                          Result := Float_Array_CGSize(Def.Size);
                        S64Real:
                          Result := Double_Array_CGSize(Def.Size);
                        else
                          { If not, fall back }
                          Result := Int_CGSize(Def.Size);
                      end;
                    end
                  else
                    Result := Int_CGSize(Def.Size);
                end
              else
                Result := OS_NO;
            end;
          else
            begin
              { undefined size }
              Result:=OS_NO;
            end;
        end;
      end;

    function CGSize_OrdDef(Size: TCgSize): TOrdDef;
      begin
        case Size of
          OS_8:
            Result:=TOrdDef(U8IntType);
          OS_S8:
            Result:=TOrdDef(S8IntType);
          OS_16:
            Result:=TOrdDef(U16IntType);
          OS_S16:
            Result:=TOrdDef(S16IntType);
          OS_32:
            Result:=TOrdDef(U32IntType);
          OS_S32:
            Result:=TOrdDef(S32IntType);
          OS_64:
            Result:=TOrdDef(U64IntType);
          OS_S64:
            Result:=TOrdDef(S64IntType);
          else
            InternalError(2012050401);
        end;
      end;

    function Def_CGMMSize(Def: TDef): TCgSize;
      begin
        case Def.Typ of
          ArrayDef:
            begin
              case TArrayDef(Def).ElementDef.Typ of
                OrdDef:
                  begin
                    { this is not correct, OS_MX normally mean that the vector
                      contains elements of size X. However, vectors themselves
                      can also have different sizes (e.g. a vector of 2 singles on
                      SSE) and the total size is currently more important }
                    case Def.Size of
                      1: Result:=OS_M8;
                      2: Result:=OS_M16;
                      4: Result:=OS_M32;
                      8: Result:=OS_M64;
                      16: Result:=OS_M128;
                      32: Result:=OS_M256;
                      64: Result:=OS_M512;
                      else
                        InternalError(2013060103);
                    end;
                  end;
                FloatDef:
                  begin
                    case TFloatDef(TArrayDef(Def).ElementDef).FloatType of
                      S32Real:
                        case Def.Size of
                          4:  Result:=OS_M32;
                          16: Result:=OS_M128;
                          32: Result:=OS_M256;
                          64: Result:=OS_M512;
                          else
                            InternalError(2017121400);
                        end;
                      S64Real:
                        case Def.Size of
                          8:  Result:=OS_M64;
                          16: Result:=OS_M128;
                          32: Result:=OS_M256;
                          64: Result:=OS_M512;
                          else
                            InternalError(2017121401);
                        end;
                      else
                        InternalError(2017121402);
                    end;
                  end;
                else
                  Result:=Def_CGSize(Def);
              end;
            end
          else
            Result:=Def_CGSize(Def);
        end;
      end;

    { In Windows 95 era, ordinals were restricted to [u8bit,s32bit,s16bit,bool16bit]
      As of today, both signed and unsigned types from 8 to 64 bits are supported. }
    function Is_Automatable(P : TDef) : Boolean;
      begin
        case P.Typ of
          OrdDef:
            Result:=TOrdDef(P).OrdType in [U8Bit,S8Bit,U16Bit,S16Bit,U32Bit,S32Bit,
              U64Bit,S64Bit,Bool16Bit,SCurrency];
          FloatDef:
            Result:=TFloatDef(P).FloatType in [S64Currency,S64Real,S32Real];
          StringDef:
            Result:=TStringDef(P).StringType in [st_ansistring,st_widestring,st_unicodestring];
          VariantDef:
            Result:=True;
          ObjectDef:
            Result:=TObjectDef(P).ObjectType in [odt_interfacecom,odt_dispinterface,odt_interfacecorba];
          else
            Result:=False;
        end;
      end;


    {# returns true, if the type passed is a varset }
    function Is_SmallSet(P : TDef) : Boolean;
      begin

          Result:=(P.Typ=SetDef) and (P.Size in [1,2,4])

      end;


    function Is_BareProcDef(PD : TProcDef): Boolean;
      begin
        Result:=(PD.MaxParaCount=0) and
                (Is_Void(PD.ReturnDef) or
                 (PD.ProcTypeOption = potype_constructor));
      end;

    function Is_C_Variadic(PD: TAbstractProcDef): Boolean;
      begin
        Result:=
          (po_varargs in PD.ProcOptions) or
          (po_variadic in PD.ProcOptions);
      end;

    function Get_Common_IntDef(LD, RD: TOrdDef; KeepSignIfEqual: Boolean): TOrdDef;
      var
        LLow, LHigh: TConstExprInt;
      begin
        LLow:=Min(LD.Low,RD.Low);
        LHigh:=Max(LD.High,RD.High);
        case Range_To_BaseType(LLow,LHigh) of
          S8Bit:
            Result:=TOrdDef(S8IntType);
          U8Bit:
            Result:=TOrdDef(U8IntType);
          S16Bit:
            Result:=TOrdDef(S16IntType);
          U16Bit:
            Result:=TOrdDef(U16IntType);
          S32Bit:
            Result:=TOrdDef(S32IntType);
          U32Bit:
            Result:=TOrdDef(U32IntType);
          S64Bit:
            Result:=TOrdDef(S64IntType);
          U64Bit:
            Result:=TOrdDef(U64IntType);
          else
            begin
              { avoid warning }
              Result:=nil;
              InternalError(200802291);
            end;
        end;
        if KeepSignIfEqual and
           (Is_Signed(LD)=Is_Signed(RD)) and
           (Is_Signed(Result)<>Is_Signed(LD)) then
          case Result.OrdType of
            S8Bit:
              Result:=TOrdDef(U8IntType);
            U8Bit:
              Result:=TOrdDef(S16IntType);
            S16Bit:
              Result:=TOrdDef(U16IntType);
            U16Bit:
              Result:=TOrdDef(S32IntType);
            S32Bit:
              Result:=TOrdDef(U32IntType);
            U32Bit:
              Result:=TOrdDef(S64IntType);
            S64Bit:
              Result:=TOrdDef(U64IntType);
            else
              ;
          end;
      end;


    function Calc_Not_OrdValue(var V:TConstExprInt;var Def:TDef):Boolean;
      begin
        if not Assigned(Def) or (Def.Typ<>OrdDef) then
          Exit(False);
        Result:=True;
        case TOrdDef(Def).OrdType of
          PasBool1,
          PasBool8,
          PasBool16,
          PasBool32,
          PasBool64:
            V:=Byte(not(Boolean(Int64(V))));
          Bool8Bit,
          Bool16Bit,
          Bool32Bit,
          Bool64Bit:
            begin
              if V=0 then
                V:=-1
              else
                V:=0;
            end;
          UChar,
          UWideChar,
          U8Bit,
          S8Bit,
          U16Bit,
          S16Bit,
          S32Bit,
          U32Bit,
          S64Bit,
          U64Bit:
            begin
              { unsigned, equal or bigger than the native int size? }
              if (TOrdDef(Def).OrdType in [U64Bit,U32Bit,U16Bit,U8Bit,UChar,UWideChar]) and
                 (Is_NativeOrd(Def) or Is_OversizedOrd(Def)) then
                begin
                  { Delphi-compatible: not dword = dword (not word = longint) }
                  { Extension: not qword = qword                              }
                  V:=QWord(not QWord(V));
                  { will be truncated by the ordconstnode for u32bit }
                end
              else
                begin
                  V:=Int64(not Int64(V));
                  Def:=Get_Common_IntDef(TOrdDef(Def),TOrdDef(SIntType),False);
                end;
            end;
          else
            Result:=False;
        end;
      end;

    function Is_Valid_Univ_Para_Type(Def: TDef): Boolean;
      begin
        Result:=
          not Is_Open_Array(Def) and
          not Is_Void(Def) and
          (Def.Typ<>FormalDef);
      end;


    function Is_Nested_PD(Def: TAbstractProcDef): Boolean;{$ifdef USEINLINE}inline;{$endif}
      begin
        Result:=Def.ParaST.SymTableLevel>NormalFunctionLevel;
      end;


    function Is_TypeParam(Def : TDef) : Boolean;{$ifdef USEINLINE}inline;{$endif}
      begin
        Result:=(Def.Typ=UndefinedDef) or (df_genconstraint in Def.DefOptions);
      end;


    function Is_MethodPointer(Def: TDef): Boolean;
      begin
        Result:=(Def.Typ=ProcVarDef) and (po_methodpointer in TProcVarDef(Def).ProcOptions);
      end;


    function Is_FuncRef(Def:TDef):Boolean;
      begin
        Result:=(Def.Typ=ObjectDef) and (oo_is_funcref in TObjectDef(Def).ObjectOptions);
      end;


    function Is_Invokable(Def:TDef):Boolean;
      begin
        Result:=(Def.Typ=ObjectDef) and (oo_is_invokable in TObjectDef(Def).ObjectOptions);
      end;


    function Is_Block(Def: TDef): Boolean;
      begin
        Result:=(Def.Typ=ProcVarDef) and (po_is_block in TProcVarDef(Def).ProcOptions)
      end;


    function Get_TypeKind(Def:TDef):Byte;
      begin
        case Def.Typ of
          ArrayDef:
            if ado_IsDynamicArray in TArrayDef(Def).ArrayOptions then
              Result:=TkDynArray
            else
              Result:=TkArray;
          RecordDef:
            Result:=TkRecord;
          PointerDef:
            Result:=TkPointer;
          OrdDef:
            case TOrdDef(Def).OrdType of
              U8Bit,
              U16Bit,
              U32Bit,
              S8Bit,
              S16Bit,
              S32Bit:
                Result:=TkInteger;
              U64Bit:
                Result:=TkQWord;
              S64Bit:
                Result:=TkInt64;
              PasBool1,
              PasBool8,
              PasBool16,
              PasBool32,
              PasBool64,
              Bool8Bit,
              Bool16Bit,
              Bool32Bit,
              Bool64Bit:
                Result:=TkBool;
              UChar:
                Result:=TkChar;
              UWideChar:
                Result:=TkWChar;
              SCurrency:
                Result:=TkFloat;
              else
                Result:=TkUnknown;
            end;
          StringDef:
            case TStringDef(Def).StringType of
              st_shortstring:
                Result:=TkSString;
              st_longstring:
                Result:=TkLString;
              st_ansistring:
                Result:=TkAString;
              st_widestring:
                Result:=TkWString;
              st_unicodestring:
                Result:=TkUString;
            end;
          EnumDef:
            Result:=TkEnumeration;
          ObjectDef:
            case TObjectDef(Def).ObjectType of
              odt_class:
                Result:=TkClass;
              odt_object:
                Result:=TkObject;
              odt_interfacecom,
              odt_dispinterface:
                Result:=TkInterface;
              odt_interfacecorba:
                Result:=TkInterfaceCORBA;
              odt_helper:
                Result:=TkHelper;
              else
                Result:=TkUnknown;
            end;
          { currently tkFile is not used }
          {filedef:
            result:=tkFile;}
          SetDef:
            Result:=TkSet;
          ProcVarDef:
            if TProcVarDef(Def).Is_MethodPointer then
              Result:=TkMethod
            else
              Result:=TkProcVar;
          FloatDef:
            Result:=TkFloat;
          ClassRefDef:
            Result:=TkClassRef;
          VariantDef:
            Result:=TkVariant;
          else
            Result:=TkUnknown;
        end;
      end;


    function Get_Invoke_ProcDef(Def:TObjectDef):TProcDef;
      var
        Sym : TSym;
      begin
        repeat
          if not Is_Invokable(Def) then
            InternalError(2022011701);
          Sym:=TSym(Def.SymTable.Find(MethodNameFuncRefInvokeFind));
          if Assigned(Sym) and (Sym.Typ<>ProcSym) then
            Sym:=nil;
          Def:=Def.ChildOf;
        until Assigned(Sym) or not Assigned(Def);
        if not Assigned(Sym) then
          InternalError(2021041001);
        if Sym.Typ<>ProcSym then
          InternalError(2021041002);
        if TProcSym(Sym).ProcDefList.Count=0 then
          InternalError(2021041003);
        Result:=TProcDef(TProcSym(Sym).ProcDefList[0]);
      end;


    function Invokable_Has_Argless_Invoke(Def:TObjectDef):Boolean;
      var
        I,J : LongInt;
        Sym : TSym;
        PD : TProcDef;
        Para : TParaVarSym;
        AllOK : Boolean;
      begin
        Result:=False;
        repeat
          if not Is_Invokable(Def) then
            InternalError(2022020701);
          Sym:=TSym(Def.SymTable.Find(MethodNameFuncRefInvokeFind));
          if Assigned(Sym) and (Sym.Typ=ProcSym) then
            begin
              for I:=0 to TProcSym(Sym).ProcDefList.Count-1 do
                begin
                  PD:=TProcDef(TProcSym(Sym).ProcDefList[I]);
                  if (PD.Paras.Count=0) or
                      (
                        (PD.Paras.Count=1) and
                        (vo_is_result in TParaVarSym(PD.Paras[0]).VarOptions)
                      ) then
                    Exit(True);
                  AllOK:=True;
                  for J:=0 to PD.Paras.Count-1 do
                    begin
                      Para:=TParaVarSym(PD.Paras[J]);
                      if vo_is_hidden_para in Para.VarOptions then
                        Continue;
                      if Assigned(Para.DefaultConstSym) then
                        Continue;
                      AllOK:=False;
                      Break;
                    end;
                  if AllOK then
                    Exit(True);
                end;
              if not (sp_has_overloaded in Sym.SymOptions) then
                Break;
            end;
          Def:=Def.ChildOf;
        until not Assigned(Def);
      end;

end.
