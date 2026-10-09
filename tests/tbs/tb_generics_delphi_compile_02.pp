{ Generics regression cases; original case IDs are retained below. }
{ %NORUN }

{ Case tw29053.pp }
{$push}
{$mode delphi}

type
  tw29053_tmodelarray<T: class> = array of T;
{$pop}

{ Case tw30030.pp }
{$push}
{$mode delphi}

type
  tw30030_tacl<K, R, M> = Class
  End;

  tw30030_tassertion<K, R, M> = Function(Acl: tw30030_tacl<K, R, M>): Boolean Of Object;
{$pop}

{ Case tw30524a.pp }
{$push}
{$ifdef FPC}
{$MODE DELPHI}
{$endif}

{uses
  Generics.Defaults;}

type
  tw30524a_tuple<tw30524a_t> = record
    tw30524a_item1: tw30524a_t;
    class operator Equal( a, b: tw30524a_tuple<tw30524a_t> ): Boolean; // FPC Error: Compilation raised exception internally
    class operator NotEqual( a, b: tw30524a_tuple<tw30524a_t> ): Boolean;
  end;

  tw30524a_tuple = record
    class function Create<tw30524a_t>( tw30524a_item1: tw30524a_t ): tw30524a_tuple<tw30524a_t>; overload; static;
  end;

class function tw30524a_tuple.Create<tw30524a_t>( tw30524a_item1: tw30524a_t ): tw30524a_tuple<tw30524a_t>;
begin
  Result.tw30524a_item1 := tw30524a_item1;
end;

class operator tw30524a_tuple<tw30524a_t>.Equal( a, b: tw30524a_tuple<tw30524a_t> ): Boolean;
begin
  Result := False;//TEqualityComparer<T>.Default.Equals( a.Item1, b.Item1 );
end;

class operator tw30524a_tuple<tw30524a_t>.NotEqual( a, b: tw30524a_tuple<tw30524a_t> ): Boolean;
begin
  Result := not( a = b );
end;

var
  tw30524a_t: tw30524a_tuple<LongInt>;
{$pop}

{ Case tw30534.pp }
{$push}
{$MODE DELPHI}

type
  tw30534_tsmartptr<T: class> = record
    class operator Implicit(aValue: T): tw30534_tsmartptr<T>;
  end;

class operator tw30534_tsmartptr<T>.Implicit(aValue: T): tw30534_tsmartptr<T>;
begin
end;

var
  tw30534_sp: tw30534_tsmartptr<TObject>;
{$pop}

{ Case tw30830b.pp }
{$push}
{$mode delphi}

type
  tw30830b_tbase<T> = class
    procedure tw30830b_test1(const a: T);
  end;

  tw30830b_tderived<T> = class(tw30830b_tbase<T>)
    procedure tw30830b_test2(const a: T);
  end;

procedure tw30830b_tbase<T>.tw30830b_test1(const a: T);
begin
end;

procedure tw30830b_tderived<T>.tw30830b_test2(const a: T);
begin
end;

procedure tw30830b_test<T>(aIntf: tw30830b_tbase<T>); overload; // works
begin
end;

procedure tw30830b_test<T>(aIntf: tw30830b_tderived<T>); overload; // SIGSEGV :(
begin
end;

var
  tw30830b_b: tw30830b_tbase<LongInt>;
  tw30830b_d: tw30830b_tderived<LongInt>;
{$pop}

{ Case tw30939b.pp }
{$push}
{$MODE delphi}

Type
  tw30939b_tgdata<T> = record
    tw30939b_b: T
  end;

  tw30939b_tgwrapper<T> = record
    tw30939b_a: tw30939b_tgdata<T>
  end;

Function tw30939b_dosomething<T>: tw30939b_tgwrapper<T>;
  Begin
    result.tw30939b_a.tw30939b_b := default(T)
  End;
{$pop}

{ Case tw38145a.pp }
{$push}
{$mode delphi}
type
  tw38145a_tmywrap<T> = record
    tw38145a_value: T;
    class operator Explicit(const w: tw38145a_tmywrap<T>): T;
    class operator Implicit(const w: tw38145a_tmywrap<T>): T;
  end;

class operator tw38145a_tmywrap<T>.Explicit(const w: tw38145a_tmywrap<T>): T;
begin
  Result := w.tw38145a_value;
end;

class operator tw38145a_tmywrap<T>.Implicit(const w: tw38145a_tmywrap<T>): T;
begin
  Result := w.tw38145a_value;
end;

type
  //TString = string[255]; //compiles
  tw38145a_tstring = string[254]; //not compiles

var
  tw38145a_myspec: tw38145a_tmywrap<tw38145a_tstring>;
{$pop}

{ Case tw40712b.pp }
{$push}
{$mode delphi}
type
    tw40712b_tsomegeneric<T> = object
    type
      tw40712b_tmine = T;
    var
      tw40712b_data: record
        tw40712b_value: T;
      end;
  end;
  tw40712b_tsomegeneric2 = object(tw40712b_tsomegeneric<Integer>)
  end;
{$pop}

begin
  { Case tw30524a.pp }
  {$push}
{$ifdef FPC}
{$endif}
  begin
tw30524a_t := tw30524a_tuple.Create<LongInt>(42);
  end;
  {$pop}

  { Case tw30534.pp }
  {$push}

  begin
tw30534_sp := nil;
  end;
  {$pop}

  { Case tw30830b.pp }
  {$push}

  begin
tw30830b_test<LongInt>(tw30830b_b);
  tw30830b_test<LongInt>(tw30830b_d);
  end;
  {$pop}

  { Case tw30939b.pp }
  {$push}

  begin
tw30939b_dosomething<LongInt>;
  end;
  {$pop}

end.
