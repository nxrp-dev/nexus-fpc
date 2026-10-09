{ Generics regression cases; original case IDs are retained below. }

{ Case tb0188a.pp }
{$push}
{$mode objfpc}

type
  generic tb0188a_tmyarray<T> = array[0..10] of longint;

var
  tb0188a_myarr: specialize tb0188a_tmyarray<String>;
{$pop}

{ Case tb0672.pp }
{$push}
{$mode objfpc}

type
  generic tb0672_ttest<T> = class
    class function tb0672_test(aArg: T): LongInt;
  end;

class function tb0672_ttest.tb0672_test(aArg: T): LongInt;
begin
  Result := Ord(aArg);
end;

type
  tb0672_tenum = (teOne, teTwo, teThree);

  tb0672_ttestboolean = specialize tb0672_ttest<Boolean>;
  tb0672_ttestchar = specialize tb0672_ttest<Char>;
  tb0672_ttestwidechar = specialize tb0672_ttest<WideChar>;
  tb0672_ttestenum = specialize tb0672_ttest<tb0672_tenum>;
{$pop}

{ Case tw37020.pp }
{$push}
{$mode objfpc}

type
 tw37020_titem = (A, B, C);
 tw37020_titems = set of tw37020_titem;
 generic tw37020_gtype<const T: tw37020_titems> = class
 end;

const
 tw37020_totheritems = [];   // no problems here

type
 // error: Incompatible types: got "Empty Set" expected "TItems"
 tw37020_ttype = specialize tw37020_gtype<[]>;
{$pop}

{ Case tw38012.pp }
{$push}
{$mode objfpc}

generic procedure tw38012_dothis<T>(msg: T);
begin
end;

generic procedure tw38012_dothis<T>(a: array of T);
begin
end;
{$pop}

{ Case tw39030.pp }
{$push}
{$mode objfpc}

generic function tw39030_conststring<const P,Q,tw39030_s: string>: PChar;
var
  tw39030_size: Integer;
begin
  tw39030_size := SizeOf(P) + SizeOf(Q) + SizeOf(tw39030_s);
  writeln(tw39030_size);

  Result := P+Q+tw39030_s;
end;

var
  tw39030_s: PChar;
{$pop}

{ Case tw40890.pp }
{$push}
{$mode objfpc}
generic procedure tw40890_foo<T>;
begin
  WriteLn('Bar');
end;
{$pop}

{ Case tw40979.pp }
{$push}
{$mode ObjFPC}

procedure tw40979_addgroup(out aArg: Integer);

  generic procedure tw40979_add<T>(const X : T; const tw40979_y : T; out Z : T);
  begin
    Z:=X+tw40979_y;
  end;

  var
    tw40979_r : integer;

  begin
    specialize tw40979_add<integer>(4,5,tw40979_r);
    aArg := tw40979_r;
  end;

var
   tw40979_r : integer;
{$pop}

{ Case tw9827.pp }
{$push}
{$mode objfpc}

type
  generic tw9827_glist<_T> = class
    private
      var
        tw9827_i : integer;
    function tw9827_some_func(): integer;
  end;

function tw9827_glist.tw9827_some_func(): integer;
begin
  tw9827_i := -1;
  Result := -1;
end { some_func };

type
  tw9827_ta = specialize tw9827_glist<integer>;
var
  tw9827_a : tw9827_ta;
{$pop}

begin
  { Case tb0188a.pp }
  {$push}

  begin
tb0188a_myarr[0] := 1;
  end;
  {$pop}

  { Case tb0672.pp }
  {$push}

  begin
if tb0672_ttestboolean.tb0672_test(True) <> Ord(True) then
    Halt(1);
  if tb0672_ttestchar.tb0672_test(#42) <> Ord(#42) then
    Halt(2);
  if tb0672_ttestwidechar.tb0672_test(#1234) <> Ord(#1234) then
    Halt(3);
  if tb0672_ttestenum.tb0672_test(teTwo) <> Ord(teTwo) then
    Halt(4);
  Writeln('ok');
  end;
  {$pop}

  { Case tw39030.pp }
  {$push}

  begin
tw39030_s := specialize tw39030_conststring<'Hello', ' world', '!'>; // error gentest.lpr(16,50) Error: Incompatible types: got "Char" expected "AnsiString"
  if tw39030_s<>'Hello world!' then
    halt(1);
  writeln(tw39030_s);
  end;
  {$pop}

  { Case tw40890.pp }
  {$push}

  begin
try
    specialize tw40890_foo<Integer>; // this one works
  except
    specialize tw40890_foo<Integer>; // Error: Identifier not found "specialize"
  end;
  end;
  {$pop}

  { Case tw40979.pp }
  {$push}

  begin
tw40979_addgroup(tw40979_r);
   if tw40979_r <> 9 then
     Halt(1);
  end;
  {$pop}

  { Case tw9827.pp }
  {$push}

  begin
tw9827_a:=tw9827_ta.Create;
  if tw9827_a.tw9827_some_func<>-1 then
    halt(1);
  writeln('ok');
  end;
  {$pop}

end.
