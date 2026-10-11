{ Consolidated generics regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tdefault9.pp }
{$push}
{ default can be used with generic type parameters as well }




type
  generic tdefault9_TTest<T> = class
    f: T;
    constructor Create;
  end;

{ TTest }

constructor tdefault9_TTest.Create;
begin
  f := Default(T);
end;

type
  tdefault9_TLongIntSpez = specialize tdefault9_TTest<LongInt>;
  tdefault9_TAnsiStringSpez = specialize tdefault9_TTest<AnsiString>;
  tdefault9_TObjectSpez = specialize tdefault9_TTest<TObject>;

var
  tdefault9_si: tdefault9_TLongIntSpez;
  tdefault9_sa: tdefault9_TAnsiStringSpez;
  tdefault9_so: tdefault9_TObjectSpez;

{$pop}

{ Case tgeneric1.pp }
{$push}


type
   generic tgeneric1_TList<_T>=class(TObject)
     data : _T;
     procedure Add(item: _T);
   end;

procedure tgeneric1_TList.Add(item: _T);
begin
  data:=item;
end;

type
  tgeneric1_TMyIntList = specialize tgeneric1_TList<integer>;
  tgeneric1_TMyIntList2 = specialize tgeneric1_TList<integer>;
  tgeneric1_TMyStringList = specialize tgeneric1_TList<string>;

var
  tgeneric1_ilist : tgeneric1_TMyIntList;
  tgeneric1_ilist2 : tgeneric1_TMyIntList2;
  tgeneric1_slist : tgeneric1_TMyStringList;
  tgeneric1_someInt : integer;

{$pop}

{ Case tgeneric107.pp }
{$push}




type generic tgeneric107_G<T> = class
    var X: T;
    // EXPECTED: gets compiled
    // ACTUAL: 'Error: Generics without specialization cannot be used as a type for a variable'
    class var F: function(const X: T) : specialize tgeneric107_G<T> of object;
    function Foo(const aX: T): specialize tgeneric107_G<T>;
end;

function tgeneric107_G.Foo(const aX: T): specialize tgeneric107_G<T>;
begin
    result := specialize tgeneric107_G<T>.Create;
    result.X := aX
end;


{$pop}

{ Case tgeneric11.pp }
{$push}


type
   generic tgeneric11_TList<_T>=class(TObject)
   public
     var
       data : _T;
     procedure Add(item: _T);
     procedure Assign(Source: specialize tgeneric11_TList<_T>);
   end;

procedure tgeneric11_TList.Add(item: _T);
begin
  data:=item;
end;

procedure tgeneric11_TList.Assign(Source: specialize tgeneric11_TList<_T>);
begin
  data:=Source.data;
end;

type
  tgeneric11_TMyIntList = specialize tgeneric11_TList<integer>;
  tgeneric11_TMyStringList = specialize tgeneric11_TList<string>;

var
  tgeneric11_ilist1, tgeneric11_ilist2 : tgeneric11_TMyIntList;
  tgeneric11_slist1, tgeneric11_slist2 : tgeneric11_TMyStringList;

{$pop}

{ Case tgeneric112.pp }
{$push}
{$H+}

type
  generic tgeneric112_TTest<T:class> = class(T)
  public
    function Foo:Integer;override;
  end;

function tgeneric112_TTest.Foo:Integer;
begin
  Result:=42;
end;


{$pop}

{ Case tgeneric113.pp }
{$push}
{$H+}

type
  tgeneric113_TBase = class
  public
    function Foo:Integer;virtual;abstract;
  end;

  generic tgeneric113_TTest<T:class> = class(T)
  public
    function Foo:Integer;override;
  end;

function tgeneric113_TTest.Foo:Integer;
begin
  Result:=42;
end;

var
  tgeneric113_b: tgeneric113_TBase;

{$pop}

{ Case tgeneric115.pp }
{$push}
{$H+}

type
  tgeneric115_TBase = class
  public
    function Foo:Integer;virtual;abstract;
  end;

  generic tgeneric115_TTest<T:class> = class(T)
  public
    function Foo:Integer;override;
  end;

  generic tgeneric115_TTest2<T:class> = class(specialize tgeneric115_TTest<T>)
  public
  end;

function tgeneric115_TTest.Foo:Integer;
begin
  Result:=42;
end;

var
  tgeneric115_b: tgeneric115_TBase;

{$pop}

{ Case tgeneric116.pp }
{$push}
{$H+}

type
  tgeneric116_TBase = class
  public
    function Foo:Integer;virtual;abstract;
  end;

  generic tgeneric116_TTest<T:class> = class(T)
  public
  end;

  generic tgeneric116_TTest2<T:class> = class(specialize tgeneric116_TTest<T>)
  public
    function Foo:Integer;override;
  end;

function tgeneric116_TTest2.Foo:Integer;
begin
  Result:=42;
end;

var
  tgeneric116_b: tgeneric116_TBase;

{$pop}

{ Case tgeneric12.pp }
{$push}


type
  tgeneric12_TSList = class(TObject)
    procedure Test; virtual;
  end;

   generic tgeneric12_TList<_T> = class(tgeneric12_TSList)
     data : _T;
     procedure Add(item: _T);
     procedure Test; override;
   end;

  tgeneric12_TListCompareFunc = function(Item1, Item2: Integer): Integer;

procedure tgeneric12_TSList.Test;
begin
  writeln('should call TList!');
  halt(1);
end;

procedure tgeneric12_TList.Add(item: _T);
begin
  data:=item;
end;

procedure tgeneric12_TList.Test;
begin
  if data <> 10 then
    halt(1);
  writeln('ok');
end;

type
  tgeneric12_TMyIntList = specialize tgeneric12_TList<Integer>;

var
  tgeneric12_ilist: tgeneric12_TMyIntList;
  tgeneric12_list: tgeneric12_TSList;

{$pop}

{ Case tgeneric122.pp }
{$push}


// test that the check on published property is performed during specialization
// The below should work.

type
  {$M+}
  generic tgeneric122_myclass<T> = class
  Private
    FData : T;
  published
    property Data : T read FData;
  end;

  tgeneric122_TA = specialize tgeneric122_myclass<integer>;
//  TB = specialize myclass<text>;


{$pop}

{ Case tgeneric17.pp }
{$push}
{$H+}

type
  generic tgeneric17_TGListItem<T> = class(TObject)
  public
    FNext: tgeneric17_TGListItem;
    procedure Assign(Source: tgeneric17_TGListItem);
  end;

procedure tgeneric17_TGListItem.Assign(Source: tgeneric17_TGListItem);
begin
  FNext := Source;
end;

type
  tgeneric17_TIntListItem = specialize tgeneric17_TGListItem<Integer>;

var
  tgeneric17_A, tgeneric17_B: tgeneric17_TIntListItem;

{$pop}

{ Case tgeneric18.pp }
{$push}


{$H+}

type

  { TFirstGeneric }

  generic tgeneric18_TFirstGeneric<T> = class(TObject)
  end;

  { TSecondGeneric }

  generic tgeneric18_TSecondGeneric<T> = class(TObject)
  public
    type
      TFirstGenericType = specialize tgeneric18_TFirstGeneric<T>;
  end;

var
  tgeneric18_Second: specialize tgeneric18_TSecondGeneric<string>;

{$pop}

{ Case tgeneric22.pp }
{$push}
{$H+}

type
  generic tgeneric22_TGListItem<T> = class(TObject)
  public var
    FValue: T;
    FNext: tgeneric22_TGListItem;
    procedure SetValue(Value: T);
    function GetValue: T;
    procedure Assign(Source: tgeneric22_TGListItem);
    function Merge(Other: tgeneric22_TGListItem): tgeneric22_TGListItem;
  end;

procedure tgeneric22_TGListItem.SetValue(Value: T);
begin
  FValue := Value;
end;

function tgeneric22_TGListItem.GetValue: T;
begin
  Result := FValue;
end;

procedure tgeneric22_TGListItem.Assign(Source: tgeneric22_TGListItem);
begin
  FNext := Source;
end;

function tgeneric22_TGListItem.Merge(Other: tgeneric22_TGListItem): tgeneric22_TGListItem;
var
  Temp: tgeneric22_TGListItem;
begin
  Temp := tgeneric22_TGListItem.Create;
  Temp.SetValue(FNext.GetValue + Other.FNext.GetValue);
  Result := Temp;
end;

type
  tgeneric22_TIntListItem = specialize tgeneric22_TGListItem<Integer>;

var
  tgeneric22_A, tgeneric22_A2, tgeneric22_B, tgeneric22_B2: tgeneric22_TIntListItem;

{$pop}

{ Case tgeneric25.pp }
{$push}


{$H+}

type
  generic tgeneric25_TArr<T> = array[0..2] of T;
  generic tgeneric25_TDynamicArr<T> = array of T;
  generic tgeneric25_TRecArr<T> = array[0..1] of record
    A: T;
    B: String;
  end;

var
  tgeneric25_ArrInt: specialize tgeneric25_TArr<Integer>;
  tgeneric25_ArrStr: specialize tgeneric25_TArr<String>;
  tgeneric25_DynArrInt: specialize tgeneric25_TDynamicArr<Integer>;
  tgeneric25_RecArr: specialize tgeneric25_TRecArr<Integer>;

{$pop}

{ Case tgeneric26.pp }
{$push}


{$H+}
type
  generic tgeneric26_TRecArr<T> = array[0..1] of record
    case enum:(tgeneric26_one, tgeneric26_two, tgeneric26_three) of
      tgeneric26_one: (F: T); // can't use type parameter here
      tgeneric26_two: (Z: T);
      tgeneric26_three: (Y: T);
  end;


{$pop}

{ Case tgeneric27.pp }
{$push}


{ check that specialization does not add enum members to the static symtable and reuses the generic enum definition }

{$H+}
type
  generic tgeneric27_TRecArr<T> = array[0..1] of record
    case enum:(tgeneric27_one, tgeneric27_two, tgeneric27_three) of
      tgeneric27_one: (F: Integer);
      tgeneric27_two: (Z: Byte);
      tgeneric27_three: (Y: PChar);
  end;

var
  tgeneric27_A: specialize tgeneric27_TRecArr<Integer>;
  tgeneric27_B: specialize tgeneric27_TRecArr<String>;

{$pop}

{ Case tgeneric33.pp }
{$push}


{$H+}
type
  // regular procdef
  generic tgeneric33_TProc1<T> = function(Value: T): T;
  // object procdef
  generic tgeneric33_TProc2<T> = function(Value: T): T of object;

  tgeneric33_TFoo = class
    function Test2(Value: Integer): Integer;
  end;

function tgeneric33_Test1(Value: Integer): Integer;
begin
  Result := Value + 1;
end;

function tgeneric33_TFoo.Test2(Value: Integer): Integer;
begin
  Result := Value - 1;
end;

var
  tgeneric33_Foo: tgeneric33_TFoo;
  tgeneric33_Proc1: specialize tgeneric33_TProc1<Integer>;
  tgeneric33_Proc2: specialize tgeneric33_TProc2<Integer>;

{$pop}

{ Case tgeneric6.pp }
{$push}


type
   generic tgeneric6_TList<_T>=class(TObject)
     type
       PListItem = ^TListItem;
       TListItem = record
         data : _T;
         next : PListItem;
       end;
     var
       first,last : PListItem;
     procedure Add(item: _T);
   end;

procedure tgeneric6_TList.Add(item: _T);
var
  newitem : PListItem;
begin
  new(newitem);
  newitem^.data:=item;
  newitem^.next:=first;
  first:=newitem;
end;

type
  tgeneric6_TMyIntList = specialize tgeneric6_TList<integer>;
  tgeneric6_TMyStringList = specialize tgeneric6_TList<string>;
var
  tgeneric6_ilist : tgeneric6_TMyIntList;
  tgeneric6_slist : tgeneric6_TMyStringList;
  tgeneric6_someInt : integer;

{$pop}

{ Case tgeneric8.pp }
{$push}


type
   generic tgeneric8_TList<_T>=class(TObject)
     type
       PListItem = ^TListItem;
       TListItem = record
         data : _T;
         next : PListItem;
       end;
       TIterator = PListItem;
     var
       first : PListItem;

     function GetFirst : TIterator; inline;
     function GetNext(i : TIterator) : TIterator; inline;
     procedure Add(item: _T);
   end;

procedure tgeneric8_TList.Add(item: _T);
var
  newitem : PListItem;
begin
  new(newitem);
  newitem^.data:=item;
  newitem^.next:=first;
  first:=newitem;
end;


function tgeneric8_TList.GetFirst : TIterator; inline;
  begin
    result:=first;
  end;


function tgeneric8_TList.GetNext(i : TIterator) : TIterator; inline;
  begin
    result:=i^.next;
  end;

type
  tgeneric8_TMyIntList = specialize tgeneric8_TList<integer>;
  tgeneric8_TMyStringList = specialize tgeneric8_TList<string>;
var
  tgeneric8_ilist : tgeneric8_TMyIntList;
  tgeneric8_slist : tgeneric8_TMyStringList;
  tgeneric8_someInt : integer;
  tgeneric8_iterator : tgeneric8_TMyIntList.TIterator;

{$pop}

{ Case tgeneric87.pp }
{$push}




type
  generic tgeneric87_TTest<T> = record

  end;

const
  tgeneric87_TestLongIntNil: ^specialize tgeneric87_TTest<LongInt> = Nil;
  tgeneric87_TestBooleanNil: ^specialize tgeneric87_TTest<Boolean> = Nil;


{$pop}

{ Case tgeneric88.pp }
{$push}




type
  generic tgeneric88_TTest<T> = record

  end;

  tgeneric88_PTestLongInt = ^specialize tgeneric88_TTest<LongInt>;
  tgeneric88_PTestBoolean = ^specialize tgeneric88_TTest<Boolean>;


{$pop}

{ Case tgeneric9.pp }
{$push}


type
  generic tgeneric9_TMap<TK, TD> = class(TObject)
    Key: TK;
    Data: TD;
    procedure Add(const AKey: TK; const AData: TD);
  end;

procedure tgeneric9_TMap.Add(const AKey: TK; const AData: TD);
begin
  Key := AKey;
  Data := AData;
end;

type
  tgeneric9_TMyStringList = specialize tgeneric9_TMap<string, TObject>;

var
  tgeneric9_slist: tgeneric9_TMyStringList;

{$pop}

{ Case tgenfunc1.pp }
{$push}
{ test syntax of a global generic function in mode objfpc }





generic function tgenfunc1_Add<T>(aLeft, aRight: T): T;
begin
  Result := aLeft + aRight;
end;


{$pop}

{ Case tgenfunc23.pp }
{$push}




var
  tgenfunc23_TestTCalled: LongInt;
  tgenfunc23_TestArrayOfTCalled: LongInt;

generic procedure tgenfunc23_Test<T>(const aArg: T);
begin
  Inc(tgenfunc23_TestTCalled);
end;

generic procedure tgenfunc23_Test<T>(const aArg: array of T);
var
  i: SizeInt;
begin
  for i := 0 to High(aArg) do begin
    specialize tgenfunc23_Test<T>(aArg[i]);
  end;
  Inc(tgenfunc23_TestArrayOfTCalled);
end;


{$pop}

{ Case tgenfunc5.pp }
{$push}
{ test syntax of a generic method in mode objfpc }





type
  tgenfunc5_TTest = class
    generic function Add<tgenfunc5_T>(aLeft, aRight: tgenfunc5_T): tgenfunc5_T;
  end;

generic function tgenfunc5_TTest.Add<tgenfunc5_T>(aLeft, aRight: tgenfunc5_T): tgenfunc5_T;
begin
  Result := aLeft + aRight;
end;

var
  tgenfunc5_t: tgenfunc5_TTest;

{$pop}

{ Case trtti21.pp }
{$push}
{ GetTypeKind() of an enumeration with holes returns tkEnumeration and
  TypeInfo() returns Nil, but *only* inside a generic/specialization when used
  with a generic parameter }





type
  trtti21_TEnum = (trtti21_teOne = 1, trtti21_teTwo);

  generic trtti21_TTest<T> = class
    class function Test: Pointer;
  end;

class function trtti21_TTest.Test: Pointer;
begin
  Result := TypeInfo(T);
end;


{$pop}

begin

{ Case tdefault9.pp }
{$push}

begin
  tdefault9_si := tdefault9_TLongIntSpez.Create;
  if tdefault9_si.f <> 0 then
    Halt(1);
  tdefault9_sa := tdefault9_TAnsiStringSpez.Create;
  if tdefault9_sa.f <> '' then
    Halt(2);
  tdefault9_so := tdefault9_TObjectSpez.Create;
  if tdefault9_so.f <> Nil then
    Halt(3);
end;
{$pop}

{ Case tgeneric1.pp }
{$push}

begin
  tgeneric1_someInt:=10;
  tgeneric1_ilist := tgeneric1_TMyIntList.Create;
  tgeneric1_ilist.Add(tgeneric1_someInt);
  writeln(tgeneric1_ilist.data);
  if tgeneric1_ilist.data<>10 then
    halt(1);

  tgeneric1_someInt:=20;
  tgeneric1_ilist2 := tgeneric1_TMyIntList2.Create;
  tgeneric1_ilist2.Add(tgeneric1_someInt);
  writeln(tgeneric1_ilist2.data);
  if tgeneric1_ilist2.data<>20 then
    halt(1);

  tgeneric1_slist := tgeneric1_TMyStringList.Create;
  tgeneric1_slist.Add('Test');
  writeln(tgeneric1_slist.data);
  if tgeneric1_slist.data<>'Test' then
    halt(1);
end;
{$pop}

{ Case tgeneric107.pp }
{$push}

begin
    specialize tgeneric107_G<Integer>.F := @specialize tgeneric107_G<Integer>.Create.Foo;
    if specialize tgeneric107_G<Integer>.F(42).X <> 42 then
      halt(1);
end;
{$pop}

{ Case tgeneric11.pp }
{$push}

begin
  tgeneric11_ilist1 := tgeneric11_TMyIntList.Create;
  tgeneric11_ilist1.add(10);
  tgeneric11_ilist2 := tgeneric11_TMyIntList.Create;
  tgeneric11_ilist2.add(20);
  tgeneric11_ilist2.assign(tgeneric11_ilist1);
  if tgeneric11_ilist2.data <> 10 then
    halt(1);
  tgeneric11_slist1 := tgeneric11_TMyStringList.Create;
  tgeneric11_slist1.add('test');
  tgeneric11_slist2 := tgeneric11_TMyStringList.Create;
  tgeneric11_slist2.add('hello');
  tgeneric11_slist2.assign(tgeneric11_slist1);
  if tgeneric11_slist2.data <> 'test' then
    halt(1);
end;
{$pop}

{ Case tgeneric112.pp }
{$push}

{$H+}
begin
end;
{$pop}

{ Case tgeneric113.pp }
{$push}

{$H+}
begin
  tgeneric113_b:=specialize tgeneric113_TTest<tgeneric113_TBase>.Create;
  if tgeneric113_b.Foo<>42 then
    Halt(1);
  WriteLn('Ok');
end;
{$pop}

{ Case tgeneric115.pp }
{$push}

{$H+}
begin
  tgeneric115_b:=specialize tgeneric115_TTest2<tgeneric115_TBase>.Create;
  if tgeneric115_b.Foo<>42 then
    Halt(1);
  WriteLn('Ok');
end;
{$pop}

{ Case tgeneric116.pp }
{$push}

{$H+}
begin
  tgeneric116_b:=specialize tgeneric116_TTest2<tgeneric116_TBase>.Create;
  if tgeneric116_b.Foo<>42 then
    Halt(1);
  WriteLn('Ok');
end;
{$pop}

{ Case tgeneric12.pp }
{$push}

begin
  tgeneric12_ilist := tgeneric12_TMyIntList.Create;
  tgeneric12_list := tgeneric12_ilist;
  tgeneric12_ilist.add(10);
  tgeneric12_list.test;
end;
{$pop}

{ Case tgeneric122.pp }
{$push}

{$M+}
begin
end;
{$pop}

{ Case tgeneric17.pp }
{$push}

{$H+}
begin
  tgeneric17_A := tgeneric17_TIntListItem.Create;
  tgeneric17_B := tgeneric17_TIntListItem.Create;
  tgeneric17_A.Assign(tgeneric17_B);
  if tgeneric17_A.FNext <> tgeneric17_B then
    halt(1);
end;
{$pop}

{ Case tgeneric18.pp }
{$push}

{$H+}
begin
end;
{$pop}

{ Case tgeneric22.pp }
{$push}

{$H+}
begin
  tgeneric22_A := tgeneric22_TIntListItem.Create;
  tgeneric22_A2 := tgeneric22_TIntListItem.Create;
  tgeneric22_A.Assign(tgeneric22_A2);
  if tgeneric22_A.FNext <> tgeneric22_A2 then
    halt(1);

  tgeneric22_B := tgeneric22_TIntListItem.Create;
  tgeneric22_B2 := tgeneric22_TIntListItem.Create;
  tgeneric22_B.Assign(tgeneric22_B2);
  if tgeneric22_B.FNext <> tgeneric22_B2 then
    halt(1);

  tgeneric22_A2.SetValue(5);
  if tgeneric22_A2.GetValue <> 5 then
    halt(1);

  tgeneric22_B2.SetValue(7);
  if tgeneric22_B2.GetValue <> 7 then
    halt(1);

  if tgeneric22_A.Merge(tgeneric22_B).GetValue <> 12 then
    halt(1);
end;
{$pop}

{ Case tgeneric25.pp }
{$push}

{$H+}
begin
  tgeneric25_ArrInt[0] := 1;
  tgeneric25_ArrStr[0] := '1';
  SetLength(tgeneric25_DynArrInt, 1);
  tgeneric25_DynArrInt[0] := 2;
  tgeneric25_RecArr[0].A := 3;
  tgeneric25_RecArr[0].B := '3';
  if tgeneric25_ArrInt[0] <> 1 then
    halt(1);
  if tgeneric25_ArrStr[0] <> '1' then
    halt(2);
  if tgeneric25_DynArrInt[0] <> 2 then
    halt(3);
  if tgeneric25_RecArr[0].A <> 3 then
    halt(4);
end;
{$pop}

{ Case tgeneric26.pp }
{$push}

{$H+}
begin
end;
{$pop}

{ Case tgeneric27.pp }
{$push}

{$H+}
begin
  tgeneric27_A[0].enum := tgeneric27_one;
  tgeneric27_B[0].enum := tgeneric27_one;
  if tgeneric27_A[0].enum <> tgeneric27_B[0].enum then
    halt(1);
end;
{$pop}

{ Case tgeneric33.pp }
{$push}

{$H+}
begin
  tgeneric33_Proc1 := @tgeneric33_Test1;
  if tgeneric33_Proc1(1) <> 2 then
    halt(1);
  tgeneric33_Foo := tgeneric33_TFoo.Create;
  tgeneric33_Proc2 := @tgeneric33_Foo.Test2;
  if tgeneric33_Proc2(2) <> 1 then
    halt(2);
  tgeneric33_Foo.Free;
end;
{$pop}

{ Case tgeneric6.pp }
{$push}

begin
  tgeneric6_someInt:=10;
  tgeneric6_ilist := tgeneric6_TMyIntList.Create;
  tgeneric6_ilist.Add(tgeneric6_someInt);
  tgeneric6_ilist.Add(tgeneric6_someInt+1);
  writeln(tgeneric6_ilist.first^.data);
  if tgeneric6_ilist.first^.data<>11 then
    halt(1);
  writeln(tgeneric6_ilist.first^.next^.data);
  if tgeneric6_ilist.first^.next^.data<>10 then
    halt(1);

  tgeneric6_slist := tgeneric6_TMyStringList.Create;
  tgeneric6_slist.Add('Test1');
  tgeneric6_slist.Add('Test2');
  writeln(tgeneric6_slist.first^.data);
  if tgeneric6_slist.first^.data<>'Test2' then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tgeneric8.pp }
{$push}

begin
  tgeneric8_someInt:=10;
  tgeneric8_ilist := tgeneric8_TMyIntList.Create;
  tgeneric8_ilist.Add(tgeneric8_someInt);
  tgeneric8_ilist.Add(tgeneric8_someInt+1);
  tgeneric8_iterator:=tgeneric8_ilist.GetFirst;
  writeln(tgeneric8_iterator^.data);
  if tgeneric8_iterator^.data<>11 then
    halt(1);
  tgeneric8_iterator:=tgeneric8_ilist.GetNext(tgeneric8_iterator);
  writeln(tgeneric8_iterator^.data);
  if tgeneric8_iterator^.data<>10 then
    halt(1);

  tgeneric8_slist := tgeneric8_TMyStringList.Create;
  tgeneric8_slist.Add('Test1');
  tgeneric8_slist.Add('Test2');
  writeln(tgeneric8_slist.first^.data);
  if tgeneric8_slist.first^.data<>'Test2' then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tgeneric87.pp }
{$push}

begin

end;
{$pop}

{ Case tgeneric88.pp }
{$push}

begin

end;
{$pop}

{ Case tgeneric9.pp }
{$push}

begin
  tgeneric9_slist := tgeneric9_TMyStringList.Create;
  tgeneric9_slist.Add('test', tgeneric9_slist);
  if tgeneric9_slist.Key <> 'test' then
    halt(1);
  if tgeneric9_slist.Data <> tgeneric9_slist then
    halt(1);
  tgeneric9_slist.Free;
end;
{$pop}

{ Case tgenfunc1.pp }
{$push}

begin
  if specialize tgenfunc1_Add<LongInt>(2, 3) <> 5 then
    Halt(1);
  if specialize tgenfunc1_Add<String>('Hello', 'World') <> 'HelloWorld' then
    Halt(2);
end;
{$pop}

{ Case tgenfunc23.pp }
{$push}

begin
  tgenfunc23_TestTCalled := 0;
  tgenfunc23_TestArrayOfTCalled := 0;
  specialize tgenfunc23_Test<LongInt>(1);
  if tgenfunc23_TestTCalled <> 1 then
    Halt(1);
  specialize tgenfunc23_Test<LongInt>([1, 2, 3]);
  if tgenfunc23_TestArrayOfTCalled <> 1 then
    Halt(2);
  if tgenfunc23_TestTCalled <> 4 then
    Halt(3);
end;
{$pop}

{ Case tgenfunc5.pp }
{$push}

begin
  if tgenfunc5_t.specialize Add<LongInt>(2, 3) <> 5 then
    Halt(1);
  if tgenfunc5_t.specialize Add<String>('Hello', 'World') <> 'HelloWorld' then
    Halt(2);
end;
{$pop}

{ Case trtti21.pp }
{$push}

begin
  if GetTypeKind(trtti21_TEnum) <> tkEnumeration then
    Halt(1);
  if specialize trtti21_TTest<trtti21_TEnum>.Test <> Nil then
    Halt(2);
end;
{$pop}

end.
