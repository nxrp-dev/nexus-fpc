{
    This file isolates platform-specific routines which perform packing and
    unpacking of ValReal FP values during float <-> ASCII conversions.
    These routines, mostly, were gathered from various places of FPC RTL.

 ****************************************************************************
}
{
    Note about inlining: since unpack_float is used only once in str_real,
    it can be safely inlined; however pack_float is used several times in
    val_real, so its inlining does not seem practical.
}
// ---------------------------------------------------------------------
//
// single; format [MSB]: 1 sign bit, 8 bit exponent, 23 bit mantissa
//
// ---------------------------------------------------------------------
{$if defined(VALREAL_32) and not defined(VALREAL_PACK)}

function unpack_float( const f: ValReal; out minus: boolean ): TDIY_FP; {$ifdef grisu1_inline}inline;{$endif}
type
    TSplitFloat = packed record
      case byte of
        0: ( f: ValReal );
        1: ( b: array [ 0 .. 3 ] of byte );
        2: ( w: array [ 0 .. 1 ] of word );
        3: ( d: dword );
    end;
var
    split: TSplitFloat;
begin
    split.f := f;
    minus := ( split.b[3] and $80 <> 0 );
    unpack_float.e := ( split.w[1] shr 7 ) and $FF;
    unpack_float.f := split.d and $007FFFFF;
end;

{$endif unpack float32}

{$if defined(VALREAL_32) and defined(VALREAL_PACK)}

procedure pack_float( out f: ValReal; minus: boolean; exp: integer; m: dword ); // {$ifdef grisu1_inline}inline;{$endif}
type
    TSplitFloat = packed record
      case byte of
        0: ( f: ValReal );
        1: ( b: array [ 0 .. 3 ] of byte );
        2: ( w: array [ 0 .. 1 ] of word );
        3: ( d: dword );
    end;
var
    split: TSplitFloat;
begin
    split.d := m;
    split.w[1] := split.w[1] + ( exp and $FF ) shl 7;
    if minus then
        split.b[3] := split.b[3] or $80;
    f := split.f;
end;

{$endif pack float32}

// ---------------------------------------------------------------------
//
// double; format [MSB]: 1 sign bit, 11 bit exponent, 52 bit mantissa
//
// ---------------------------------------------------------------------
{$if defined(VALREAL_64) and not defined(VALREAL_PACK)}


function unpack_float( const f: ValReal; out minus: boolean ): TDIY_FP; {$ifdef grisu1_inline}inline;{$endif}
type
    TSplitFloat = packed record
      case byte of
        0: ( f: ValReal );
        1: ( b: array [ 0 .. 7 ] of byte );
        2: ( w: array [ 0 .. 3 ] of word );
        3: ( d: array [ 0 .. 1 ] of dword );
        4: ( l: qword );
    end;
var
    doublebits: TSplitFloat;
begin
    doublebits.f := f;
    minus := ( doublebits.b[7] and $80 <> 0 );
    unpack_float.e := ( doublebits.w[3] shr 4 ) and $7FF;
    unpack_float.f := doublebits.l and $000FFFFFFFFFFFFF;
end;

{$endif unpack float64}

{$if defined(VALREAL_64) and defined(VALREAL_PACK)}


procedure pack_float( out f: ValReal; minus: boolean; exp: integer; const m: qword ); // {$ifdef grisu1_inline}inline;{$endif}
type
    TSplitFloat = packed record
      case byte of
        0: ( f: ValReal );
        1: ( b: array [ 0 .. 7 ] of byte );
        2: ( w: array [ 0 .. 3 ] of word );
        3: ( d: array [ 0 .. 1 ] of dword );
        4: ( l: qword );
    end;
var
    doublebits: TSplitFloat;
begin
    doublebits.l := m;
    doublebits.w[3] := doublebits.w[3] + ( exp and $7FF ) shl 4;
    if minus then
        doublebits.b[7] := doublebits.b[7] or $80;
    f := doublebits.f;
end;

{$endif pack float64}

// ---------------------------------------------------------------------
//
// extended; format [MSB]: 1 Sign bit, 15 bit exponent, 64 bit mantissa (explicit integer bit is included)
//
// ---------------------------------------------------------------------
{$if defined(VALREAL_80) and not defined(VALREAL_PACK)}

function unpack_float( const f: ValReal; out minus: boolean ): TDIY_FP; {$ifdef grisu1_inline}inline;{$endif}
type
    TSplitFloat = packed record
      case byte of
        0: ( f: ValReal );
        1: ( b: array [ 0 .. 9 ] of byte );
        2: ( l: qword; e: word )
    end;
var
    split: TSplitFloat;
begin
    split.f := f;
    minus := ( split.b[9] and $80 <> 0 );
    unpack_float.e := split.e and $7FFF;
    unpack_float.f := split.l;
    unpack_float.fh := 0;
end;

{$endif unpack floatx80}

{$if defined(VALREAL_80) and defined(VALREAL_PACK)}

procedure pack_float( out f: ValReal; minus: boolean; exp: integer; const m: qword ); // {$ifdef grisu1_inline}inline;{$endif}
type
    TSplitFloat = packed record
      case byte of
        0: ( f: ValReal );
        1: ( b: array [ 0 .. 9 ] of byte );
        2: ( l: qword; e: word )
    end;
var
    split: TSplitFloat;
begin
    split.l := m;
    split.e := exp and $7FFF;
    if minus then
        split.b[9] := split.b[9] or $80;
    f := split.f;
end;

{$endif pack floatx80}
