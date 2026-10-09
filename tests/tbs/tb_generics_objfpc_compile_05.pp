{ Generics regression cases; original case IDs are retained below. }
{ %NORUN }

{ Case tw21179.pp }
{$push}
{$mode OBJFPC}
{$modeswitch ADVANCEDRECORDS}

type generic tw21179_gvec3<T> = record
  tw21179_d : Byte;
  class operator *( const A, B : tw21179_gvec3 ) : tw21179_gvec3;
  class operator *( const A : tw21179_gvec3; tw21179_scalar : T ) : tw21179_gvec3;
end;

class operator tw21179_gvec3.*( const A, B : tw21179_gvec3 ) : tw21179_gvec3;
begin
end;

class operator tw21179_gvec3.*( const A : tw21179_gvec3; tw21179_scalar : T ) : tw21179_gvec3;
begin
end;
{$pop}

{ Case tw30524b.pp }
{$push}
{$MODE objfpc}
{$modeswitch advancedrecords}

{uses
  Generics.Defaults;}

type
  generic tw30524b_tuple<tw30524b_t> = record
    tw30524b_item1: tw30524b_t;
    class operator =( a, b: specialize tw30524b_tuple<tw30524b_t> ): Boolean; // FPC Error: Compilation raised exception internally
    class operator <>( a, b: specialize tw30524b_tuple<tw30524b_t> ): Boolean;
  end;

  tw30524b_ttuple = record
    generic class function Create<tw30524b_t>( tw30524b_item1: tw30524b_t ): specialize tw30524b_tuple<tw30524b_t>; overload; static;
  end;

generic class function tw30524b_ttuple.Create<tw30524b_t>( tw30524b_item1: tw30524b_t ): specialize tw30524b_tuple<tw30524b_t>;
begin
  Result.tw30524b_item1 := tw30524b_item1;
end;

class operator tw30524b_tuple.=( a, b: specialize tw30524b_tuple<tw30524b_t> ): Boolean;
begin
  Result := False;//TEqualityComparer<T>.Default.Equals( a.Item1, b.Item1 );
end;

class operator tw30524b_tuple.<>( a, b: specialize tw30524b_tuple<tw30524b_t> ): Boolean;
begin
  Result := not( a = b );
end;

var
  tw30524b_t: specialize tw30524b_tuple<LongInt>;
{$pop}

{ Case tw34497a.pp }
{$push}
{$mode ObjFPC}
{$modeswitch AdvancedRecords}

type
  generic tw34497a_tgenrec<T1, T2> = record
    tw34497a_a: T1;
    tw34497a_b: T2;
    function tw34497a_funca(const T: T1): T1;
    function tw34497a_funca(const T: T2): T2;
    class operator :=(constref Rec: tw34497a_tgenrec): T1;
    class operator :=(constref Rec: tw34497a_tgenrec): T2;
  end;

  function tw34497a_tgenrec.tw34497a_funca(const T: T1): T1;
  begin
    Result := T;
  end;

  function tw34497a_tgenrec.tw34497a_funca(const T: T2): T2;
  begin
    Result := T;
  end;

  class operator tw34497a_tgenrec.:=(constref Rec: tw34497a_tgenrec): T1;
  begin
    Result := Rec.tw34497a_a;
  end;

  class operator tw34497a_tgenrec.:=(constref Rec: tw34497a_tgenrec): T2;
  begin
    Result := Rec.tw34497a_b;
  end;
{$pop}

{ Case tw38145b.pp }
{$push}
{$mode objfpc}{$modeswitch advancedrecords}
type
  generic tw38145b_tmywrap<T> = record
    tw38145b_value: T;
    class operator Explicit(const w: tw38145b_tmywrap): T;
    class operator :=(const w: tw38145b_tmywrap): T;
  end;

class operator tw38145b_tmywrap.Explicit(const w: tw38145b_tmywrap): T;
begin
  Result := w.tw38145b_value;
end;

class operator tw38145b_tmywrap.:=(const w: tw38145b_tmywrap): T;
begin
  Result := w.tw38145b_value;
end;

type
  //TString = string[255]; //compiles
  tw38145b_tstring = string[254]; //not compiles
var
  tw38145b_myspec: specialize tw38145b_tmywrap<tw38145b_tstring>;
{$pop}

begin
  { Case tw30524b.pp }
  {$push}

  begin
tw30524b_t := tw30524b_ttuple.specialize Create<LongInt>(42);
  end;
  {$pop}

end.
