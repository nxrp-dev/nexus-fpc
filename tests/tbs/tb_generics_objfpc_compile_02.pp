{ Generics regression cases; original case IDs are retained below. }
{ %NORUN }

{ Case tw41254.pp }
{$push}
{$mode objfpc}

type
  generic tw41254_tt<T> = record
    tw41254_zz: ^specialize tw41254_tt<T>; // Error: Internal error 2019112401
  end;

  tw41254_ttint = specialize tw41254_tt<longint>;
{$pop}

{ Case tw41504a.pp }
{$push}
{$mode objFPC}

type
  tw41504a_tclassmain = class
    procedure tw41504a_method; virtual; abstract;
  end;

  generic tw41504a_tgenclass<T> = class
  type
    tw41504a_ttype = T;
    tw41504a_tself = tw41504a_tgenclass;
  end;

  tw41504a_ltype = type specialize tw41504a_tgenclass<tw41504a_tclassmain>.tw41504a_tself.tw41504a_ttype;
{$pop}

begin
end.
