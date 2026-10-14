{ Consolidated objects regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tdefault5.pas }
{$push}


{ In Delphi mode unsupported types like TextFile are ignored inside records
  and objects }




type
  tdefault5_TTestRecord = record
    f: TextFile;
  end;

  tdefault5_TTestObject = object
    f: TextFile;
  end;

var
  tdefault5_trec: tdefault5_TTestRecord;
  tdefault5_tobj: tdefault5_TTestObject;

{$pop}

{ Case tgeneric41.pas }
{$push}


{ in mode Delphi generic types might be overloaded - here: method vars only }


{$ifdef fpc}
  
{$endif}

type
  tgeneric41_TTest = procedure of object;

  tgeneric41_TTest<T> = procedure of object;

  tgeneric41_TTest<T, S> = procedure of object;


{$pop}

{ Case tgeneric47.pas }
{$push}


{ in mode Delphi generic types might be overloaded - here: method vars only
  Note: This tests a different code path than in the compiler than tgeneric39! }


{$ifdef fpc}
  
{$endif}

type
  tgeneric47_TTest<T> = procedure of object;

  tgeneric47_TTest = procedure of object;

  tgeneric47_TTest<T, S> = procedure of object;


{$pop}

{ Case tgeneric68.pas }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: object in object }


{$ifdef fpc}
  
{$endif}

type
  tgeneric68_TTest<tgeneric68_T> = object
  type
    TTestSub = object
      function Test(a: tgeneric68_T): tgeneric68_T;
    end;
  end;

function tgeneric68_TTest<tgeneric68_T>.TTestSub.Test(a: tgeneric68_T): tgeneric68_T;
begin
  Result := a;
end;

var
  tgeneric68_t: tgeneric68_TTest<Integer>.TTestSub;

{$pop}

begin

{ Case tdefault5.pas }
{$push}

begin
  tdefault5_trec := Default(tdefault5_TTestRecord);
  tdefault5_tobj := Default(tdefault5_TTestObject);
end;
{$pop}

{ Case tgeneric41.pas }
{$push}
{$ifdef fpc}

{$endif}
begin

end;
{$pop}

{ Case tgeneric47.pas }
{$push}
{$ifdef fpc}

{$endif}
begin

end;
{$pop}

{ Case tgeneric68.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  tgeneric68_t.Test(42);
end;
{$pop}

end.
