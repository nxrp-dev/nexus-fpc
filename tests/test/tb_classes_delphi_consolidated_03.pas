{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tchlp35.pas }
{$push}
{ helper methods also influence calls to a parent's method in a derived class }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp35_TTest = class
    function Test: Integer;
  end;

  tchlp35_TTestSub = class(tchlp35_TTest)
    function AccessTest: Integer;
  end;

  tchlp35_TTestHelper = class helper for tchlp35_TTest
    function Test: Integer;
  end;

function tchlp35_TTest.Test: Integer;
begin
  Result := 1;
end;

function tchlp35_TTestSub.AccessTest: Integer;
begin
  Result := Test;
end;

function tchlp35_TTestHelper.Test: Integer;
begin
  Result := 2;
end;

var
  tchlp35_t: tchlp35_TTestSub;
  tchlp35_res: Integer;

{$pop}

{ Case tchlp36.pas }
{$push}
{ helper methods also influence calls to a parent's method in a derived class }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp36_TTest = class
    function Test: Integer;
  end;

  tchlp36_TTestSub = class(tchlp36_TTest)
    function AccessTest: Integer;
  end;

  tchlp36_TTestHelper = class helper for tchlp36_TTest
    function Test: Integer;
  end;

function tchlp36_TTest.Test: Integer;
begin
  Result := 1;
end;

function tchlp36_TTestSub.AccessTest: Integer;
begin
  Result := inherited Test;
end;

function tchlp36_TTestHelper.Test: Integer;
begin
  Result := 2;
end;

var
  tchlp36_t: tchlp36_TTestSub;
  tchlp36_res: Integer;

{$pop}

{ Case tchlp38.pas }
{$push}
{ a helper of a parent class hides the parent's methods }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp38_TTest = class
    function Test: Integer;
  end;

  tchlp38_TTestSub = class(tchlp38_TTest)

  end;

  tchlp38_TTestHelper = class helper for tchlp38_TTest
    function Test: Integer;
  end;

function tchlp38_TTest.Test: Integer;
begin
  Result := 1;
end;

function tchlp38_TTestHelper.Test: Integer;
begin
  Result := 2;
end;

var
  tchlp38_t: tchlp38_TTestSub;
  tchlp38_res: Integer;

{$pop}

{ Case tchlp39.pas }
{$push}
{ a helper of a parent class hides methods in the child class if its also a
  parent of the helper for the child class }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp39_TTest = class
    function Test: Integer;
  end;

  tchlp39_TTestSub = class(tchlp39_TTest)
     function Test: Integer;
  end;

  tchlp39_TTestHelper = class helper for tchlp39_TTest
    function Test: Integer;
  end;

  tchlp39_TTestSubHelper = class helper(tchlp39_TTestHelper) for tchlp39_TTestSub
  end;

function tchlp39_TTest.Test: Integer;
begin
  Result := 1;
end;

function tchlp39_TTestSub.Test: Integer;
begin
  Result := 4;
end;

function tchlp39_TTestHelper.Test: Integer;
begin
  Result := 2;
end;

var
  tchlp39_t: tchlp39_TTestSub;
  tchlp39_res: Integer;

{$pop}

{ Case tchlp40.pas }
{$push}
{ methods of the extended class can be called using "inherited" }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp40_TTest = class
    function Test(aRecurse: Boolean): Integer;
  end;

  tchlp40_TTestHelper = class helper for tchlp40_TTest
    function Test(aRecurse: Boolean): Integer;
  end;

function tchlp40_TTest.Test(aRecurse: Boolean): Integer;
begin
  Result := 1;
end;

function tchlp40_TTestHelper.Test(aRecurse: Boolean): Integer;
begin
  if aRecurse then
    Result := inherited Test(False)
  else
    Result := 2;
end;

var
  tchlp40_t: tchlp40_TTest;
  tchlp40_res: Integer;

{$pop}

{ Case tchlp41.pas }
{$push}
{ the extended class has higher priority than the parent class when
  searching for symbols }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp41_TTest = class
    function Test(aRecurse: Boolean): Integer;
  end;

  tchlp41_TTestHelper = class helper for tchlp41_TTest
    function Test(aRecurse: Boolean): Integer;
  end;

  tchlp41_TTestHelperSub = class helper(tchlp41_TTestHelper) for tchlp41_TTest
    function Test(aRecurse: Boolean): Integer;
  end;

function tchlp41_TTest.Test(aRecurse: Boolean): Integer;
begin
  Result := 1;
end;

function tchlp41_TTestHelper.Test(aRecurse: Boolean): Integer;
begin
  Result := 2;
end;

function tchlp41_TTestHelperSub.Test(aRecurse: Boolean): Integer;
begin
  if aRecurse then
    Result := inherited Test(False)
  else
    Result := 3;
end;

var
  tchlp41_t: tchlp41_TTest;
  tchlp41_res: Integer;

{$pop}

{ Case tchlp42.pas }
{$push}
{ the extended type is searched first for a inherited method even if it's
  defined as "override" }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp42_TTest = class
    function Test(aRecurse: Boolean): Integer; virtual;
  end;

  tchlp42_TObjectHelper = class helper for TObject
    function Test(aRecurse: Boolean): Integer; virtual;
  end;

  tchlp42_TTestHelper = class helper(tchlp42_TObjectHelper) for tchlp42_TTest
    function Test(aRecurse: Boolean): Integer; override;
  end;

function tchlp42_TTest.Test(aRecurse: Boolean): Integer;
begin
  Result := 1;
end;

function tchlp42_TObjectHelper.Test(aRecurse: Boolean): Integer;
begin
  Result := 2;
end;

function tchlp42_TTestHelper.Test(aRecurse: Boolean): Integer;
begin
  if aRecurse then
    Result := inherited Test(False)
  else
    Result := 3;
end;

var
  tchlp42_t: tchlp42_TTest;
  tchlp42_res: Integer;

{$pop}

{ Case tchlp44.pas }
{$push}
{ in a class helper Self always is of the type of the extended class }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp44_TTest = class
    function Test: Integer;
  end;

  tchlp44_TTestSub = class(tchlp44_TTest)
    function Test: Integer;
  end;

  tchlp44_TTestHelper = class helper for tchlp44_TTest
    function AccessTest: Integer;
  end;

  tchlp44_TTestSubHelper = class helper(tchlp44_TTestHelper) for tchlp44_TTestSub
  end;

function tchlp44_TTest.Test: Integer;
begin
  Result := 1;
end;

function tchlp44_TTestSub.Test: Integer;
begin
  Result := 2;
end;

function tchlp44_TTestHelper.AccessTest: Integer;
begin
  Result := Test;
end;

var
  tchlp44_t: tchlp44_TTestSub;
  tchlp44_res: Integer;

{$pop}

{ Case tchlp46.pas }
{$push}
{ test that helpers can access the methods of the parent helper using
  "inherited" }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp46_TTest = class

  end;

  tchlp46_TTestHelper = class helper for tchlp46_TTest
    function Test(aRecurse: Boolean): Integer;
  end;

  tchlp46_TTestHelperSub = class helper(tchlp46_TTestHelper) for tchlp46_TTest
    function Test(aRecurse: Boolean): Integer;
  end;

function tchlp46_TTestHelper.Test(aRecurse: Boolean): Integer;
begin
  Result := 1;
end;

function tchlp46_TTestHelperSub.Test(aRecurse: Boolean): Integer;
begin
  if aRecurse then
    Result := inherited Test(False)
  else
    Result := 2;
end;

var
  tchlp46_t: tchlp46_TTest;
  tchlp46_res: Integer;

{$pop}

{ Case tchlp47.pas }
{$push}
{ a method defined in a parent helper has higher priority than a method defined
  in the parent of the extended class - test 1}


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp47_TTest = class
    function Test: Integer;
  end;

  tchlp47_TTestSub = class(tchlp47_TTest)
  end;

  tchlp47_TTestSubHelper = class helper for tchlp47_TTestSub
    function Test: Integer;
  end;

  tchlp47_TTestSubHelperSub = class helper(tchlp47_TTestSubHelper) for tchlp47_TTestSub
    function AccessTest: Integer;
  end;

function tchlp47_TTest.Test: Integer;
begin
  Result := 1;
end;

function tchlp47_TTestSubHelper.Test: Integer;
begin
  Result := 2;
end;

function tchlp47_TTestSubHelperSub.AccessTest: Integer;
begin
  Result := Test;
end;

var
  tchlp47_t: tchlp47_TTestSub;
  tchlp47_res: Integer;

{$pop}

{ Case tchlp48.pas }
{$push}
{ a method defined in a parent helper has higher priority than a method defined
  in the parent of the extended class - test 2 }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp48_TTest = class
    function Test: Integer;
  end;

  tchlp48_TTestSub = class(tchlp48_TTest)
  end;

  tchlp48_TTestSubHelper = class helper for tchlp48_TTestSub
    function Test: Integer;
  end;

  tchlp48_TTestSubHelperSub = class helper(tchlp48_TTestSubHelper) for tchlp48_TTestSub
    function AccessTest: Integer;
  end;

function tchlp48_TTest.Test: Integer;
begin
  Result := 1;
end;

function tchlp48_TTestSubHelper.Test: Integer;
begin
  Result := 2;
end;

function tchlp48_TTestSubHelperSub.AccessTest: Integer;
begin
  Result := inherited Test;
end;

var
  tchlp48_t: tchlp48_TTestSub;
  tchlp48_res: Integer;

{$pop}

{ Case tchlp49.pas }
{$push}
{ a class helper can access methods defined in the parent of the extended
  class }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp49_TTest = class
    function Test(aRecurse: Boolean): Integer;
  end;

  tchlp49_TTestSub = class(tchlp49_TTest)
  end;

  tchlp49_TTestSubHelper = class helper for tchlp49_TTestSub
    function Test(aRecurse: Boolean): Integer;
  end;

function tchlp49_TTest.Test(aRecurse: Boolean): Integer;
begin
  Result := 1;
end;

function tchlp49_TTestSubHelper.Test(aRecurse: Boolean): Integer;
begin
  if aRecurse then
    Result := inherited Test(False)
  else
    Result := 2;
end;

var
  tchlp49_t: tchlp49_TTestSub;
  tchlp49_res: Integer;

{$pop}

{ Case tchlp5.pas }
{$push}
{ the size of a class helper is equivalent to that of a pointer }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp5_TTest = class
    s: String;
    i32: Integer;
    b: Boolean;
    i64: Int64;
  end;

  tchlp5_TTestHelper = class helper for tchlp5_TTest
  end;

var
  tchlp5_res: Integer;

{$pop}

{ Case tchlp50.pas }
{$push}
{ without "inherited" the methods of the helper are called first }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp50_TTest = class
    function Test(aRecurse: Boolean): Integer;
  end;

  tchlp50_TTestHelper = class helper for tchlp50_TTest
    function Test(aRecurse: Boolean): Integer;
  end;

function tchlp50_TTest.Test(aRecurse: Boolean): Integer;
begin
  Result := 1;
end;

function tchlp50_TTestHelper.Test(aRecurse: Boolean): Integer;
begin
  if aRecurse then
    Result := Test(False)
  else
    Result := 2;
end;

var
  tchlp50_t: tchlp50_TTest;
  tchlp50_res: Integer;

{$pop}

{ Case tchlp51.pas }
{$push}
{ methods defined in a helper have higher priority than those defined in the
  extended type }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp51_TTest = class
    function Test: Integer;
  end;

  tchlp51_TTestHelper = class helper for tchlp51_TTest
  private
    function Test: Integer;
  public
    function AccessTest: Integer;
  end;

function tchlp51_TTest.Test: Integer;
begin
  Result := 1;
end;

function tchlp51_TTestHelper.Test: Integer;
begin
  Result := 2;
end;

function tchlp51_TTestHelper.AccessTest: Integer;
begin
  Result := Test;
end;

var
  tchlp51_t: tchlp51_TTest;
  tchlp51_res: Integer;

{$pop}

{ Case tchlp53.pas }
{$push}
{ a helper hides an existing enumerator }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp53_TContainerEnum = class;

  tchlp53_TContainer = class
    Contents: array[0..5] of Integer;
    function GetEnumerator: tchlp53_TContainerEnum;
    constructor Create;
  end;

  tchlp53_TContainerEnum = class
  private
    fIndex: Integer;
    fContainer: tchlp53_TContainer;
    fForward: Boolean;
  public
    constructor Create(aContainer: tchlp53_TContainer; aForward: Boolean);
    function GetCurrent: Integer;
    function MoveNext: Boolean;
    property Current: Integer read GetCurrent;
  end;

  tchlp53_TContainerHelper = class helper for tchlp53_TContainer
    function GetEnumerator: tchlp53_TContainerEnum;
  end;

{ TContainer }

constructor tchlp53_TContainer.Create;
var
  tchlp53_i: Integer;
begin
  for tchlp53_i := Low(Contents) to High(Contents) do
    Contents[tchlp53_i] := tchlp53_i;
end;

function tchlp53_TContainer.GetEnumerator: tchlp53_TContainerEnum;
begin
  Result := tchlp53_TContainerEnum.Create(Self, True);
end;

{ TContainerHelper }

function tchlp53_TContainerHelper.GetEnumerator: tchlp53_TContainerEnum;
begin
  Result := tchlp53_TContainerEnum.Create(Self, False);
end;

{ TContainerEnum }

constructor tchlp53_TContainerEnum.Create(aContainer: tchlp53_TContainer; aForward: Boolean);
begin
  fContainer := aContainer;
  fForward := aForward;
  if fForward then
    fIndex := Low(fContainer.Contents) - 1
  else
    fIndex := High(fContainer.Contents) + 1;
end;

function tchlp53_TContainerEnum.GetCurrent: Integer;
begin
  Result := fContainer.Contents[fIndex];
end;

function tchlp53_TContainerEnum.MoveNext: Boolean;
begin
  if fForward then begin
    Inc(fIndex);
    Result := fIndex <= High(fContainer.Contents);
  end else begin
    Dec(fIndex);
    Result := fIndex >= Low(fContainer.Contents);
  end;
end;

var
  tchlp53_cont: tchlp53_TContainer;
  tchlp53_i, tchlp53_c: Integer;

{$pop}

{ Case tchlp54.pas }
{$push}
{ this example tests combinations of class and helpers hierarchies }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp54_TTest1 = class
  end;

  tchlp54_TTest2 = class(tchlp54_TTest1)
    class function Test3: Integer;
  end;

  tchlp54_TTest3 = class(tchlp54_TTest2)
    class function Test1: Integer;
    class function Test2: Integer;
  end;

  tchlp54_TTest4 = class(tchlp54_TTest3)
  end;

  tchlp54_TTest1Helper = class helper for tchlp54_TTest1
    class function Test1: Integer;
    class function Test3: Integer;
    class function Test4: Integer;
  end;

  tchlp54_TTest3Helper = class helper for tchlp54_TTest3
    class function Test2: Integer;
    class function Test4: Integer;
  end;

  tchlp54_TTest4Helper = class helper(tchlp54_TTest1Helper) for tchlp54_TTest4
    class function DoTest1: Integer;
    class function DoTest2: Integer;
    class function DoTest3: Integer;
    class function DoTest4: Integer;
  end;

class function tchlp54_TTest2.Test3: Integer;
begin
  Result := 1;
end;

class function tchlp54_TTest3.Test1: Integer;
begin
  Result := 1;
end;

class function tchlp54_TTest3.Test2: Integer;
begin
  Result := 1;
end;

class function tchlp54_TTest1Helper.Test1: Integer;
begin
  Result := 2;
end;

class function tchlp54_TTest1Helper.Test3: Integer;
begin
  Result := 2;
end;

class function tchlp54_TTest1Helper.Test4: Integer;
begin
  Result := 1;
end;

class function tchlp54_TTest3Helper.Test2: Integer;
begin
  Result := 2;
end;

class function tchlp54_TTest3Helper.Test4: Integer;
begin
  Result := 2;
end;

class function tchlp54_TTest4Helper.DoTest1: Integer;
begin
  Result := Test1;
end;

class function tchlp54_TTest4Helper.DoTest2: Integer;
begin
  Result := Test2;
end;

class function tchlp54_TTest4Helper.DoTest3: Integer;
begin
  Result := Test3;
end;

class function tchlp54_TTest4Helper.DoTest4: Integer;
begin
  Result := Test4;
end;

var
  tchlp54_res: Integer;

{$pop}

{ Case tchlp6.pas }
{$push}
{ helpers may introduce new default properties }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp6_TTest = class

  end;

  tchlp6_TTestHelper = class helper for tchlp6_TTest
    function GetTest(aIndex: Integer): Integer;
    property Test[Index: Integer]: Integer read GetTest; default;
  end;

function tchlp6_TTestHelper.GetTest(aIndex: Integer): Integer;
begin
  Result := aIndex;
end;

var
  tchlp6_t: tchlp6_TTest;
  tchlp6_res: Integer;

{$pop}

{ Case tchlp7.pas }
{$push}
{ helpers may override existing default properties }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp7_TTest = class
  private
    function GetTest(aIndex: Integer): Integer;
  public
    property Test[Index: Integer]: Integer read GetTest; default;
  end;

  tchlp7_TTestHelper = class helper for tchlp7_TTest
    function GetTest(aIndex: Integer): Integer;
    property Test[Index: Integer]: Integer read GetTest; default;
  end;

function tchlp7_TTest.GetTest(aIndex: Integer): Integer;
begin
  Result := - aIndex;
end;

function tchlp7_TTestHelper.GetTest(aIndex: Integer): Integer;
begin
  Result := aIndex;
end;

var
  tchlp7_t: tchlp7_TTest;
  tchlp7_res: Integer;

{$pop}

{ Case tchlp8.pas }
{$push}
{ helpers may introduce new default properties (includes default properties
  introduced by the helper's parent) }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp8_TTest = class

  end;

  tchlp8_TTestHelper = class helper for tchlp8_TTest
    function GetTest(aIndex: Integer): Integer;
    property Test[Index: Integer]: Integer read GetTest; default;
  end;

  tchlp8_TTestHelperSub = class helper(tchlp8_TTestHelper) for tchlp8_TTest
  end;

function tchlp8_TTestHelper.GetTest(aIndex: Integer): Integer;
begin
  Result := aIndex;
end;

var
  tchlp8_t: tchlp8_TTest;
  tchlp8_res: Integer;

{$pop}

{ Case tclass11a.pas }
{$push}

{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tclass11a_TSomeClass = class
  strict private
    type
      TPrivateNestedClass = class
      public
        procedure DoSomething;
      end;
  public
    type
      TNestedClass = class
      public
        procedure DoSomething;
      end;
    class procedure Test; virtual;
  end;

  tclass11a_TDescendant = class(tclass11a_TSomeClass)
  public
    class procedure Test; override;
  end;

procedure tclass11a_TSomeClass.TPrivateNestedClass.DoSomething;
begin
  WriteLn('TSomeClass.TPrivateNestedClass.DoSomething: ok');
end;

procedure tclass11a_TSomeClass.TNestedClass.DoSomething;
begin
  WriteLn('TSomeClass.TNestedClass.DoSomething: ok');
end;

class procedure tclass11a_TSomeClass.Test;
var
  P: TPrivateNestedClass;
  N: TNestedClass;
begin
  P := TPrivateNestedClass.Create;
  P.DoSomething;
  P.Free;
  N := TNestedClass.Create;
  N.DoSomething;
  N.Free;
end;

class procedure tclass11a_TDescendant.Test;
var
  N: TNestedClass;
begin
  N := TNestedClass.Create;
  N.DoSomething;
  N.Free;
end;


{$pop}

{ Case tclass12a.pas }
{$push}

{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tclass12a_TSomeClass = class
  strict private
    const
      PrivateConst = 3.14;
  public
    class procedure WritePrivateConst; static;
  end;

  class procedure tclass12a_TSomeClass.WritePrivateConst;
  begin
    WriteLn(PrivateConst);
  end;


{$pop}

{ Case tclass12c.pas }
{$push}

{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tclass12c_TSomeClass = class
  strict private
    const
      PrivateConst = 1;
    type
      PrivateType = type Integer;
    var
      FPrivateField: PrivateType;
  public
    procedure DoSomething(Value: PrivateType = PrivateConst);
    function ReturnSomething: PrivateType;
    property SomeProp: PrivateType read FPrivateField write FPrivateField default PrivateConst;
  end;

  procedure tclass12c_TSomeClass.DoSomething(Value: PrivateType = PrivateConst);
  begin
  end;

  function tclass12c_TSomeClass.ReturnSomething: PrivateType;
  begin
    Result := PrivateConst;
  end;


{$pop}

{ Case tclass12d.pas }
{$push}

{$APPTYPE console}
{$ifdef fpc}
  {$H+}
{$endif}

type
  tclass12d_TR = class
  private
    type
      TSomeType = integer;
    const
      SomeValue: TSomeType = 1;
    class function GetSomeProp: TSomeType; static;
  public
    class property SomeProp: TSomeType read GetSomeProp;
  end;

class function tclass12d_TR.GetSomeProp: TSomeType;
begin
  Result := SomeValue;
end;


{$pop}

{ Case tclass9.pas }
{$push}


{$ifdef fpc}
  {$H+}
{$endif}
{$APPTYPE CONSOLE}

type
  tclass9_TSomeClass = class
  private
    type
      TSomeType = type integer;    // an internal type
    class var
      FSomeClassVar: TSomeType;    // class variable belongs to class, not an instance
    var
      FSomeIntanceVar: TSomeType;  // instance variable belongs to instance. it is a usual field
    class procedure SetSomeClassVar(const AValue: TSomeType); static;
  public
    class property SomeProperty: TSomeType read FSomeClassVar write SetSomeClassVar; // class property - belongs to class
    property SomeInstanceProp: TSomeType read FSomeIntanceVar;
  end;

{ TSomeClass }

class procedure tclass9_TSomeClass.SetSomeClassVar(const AValue: TSomeType);
begin
   FSomeClassVar := AValue;
end;

var
  tclass9_SomeClass: tclass9_TSomeClass;

{$pop}

{ Case tobject6.pas }
{$push}

{$APPTYPE console}
{$ifdef fpc}
  {$H+}
{$endif}

type
  tobject6_TR = object
  private
    type
      tsometype = integer;
    class var
      ffield1: tsometype;
    var
      ffield2: string;
    const
      somevalue = 1;
    class procedure SetField1(const Value: tsometype); static;
  public
    class property field1: tsometype read ffield1 write SetField1;
  end;

{ TR }

class procedure tobject6_TR.SetField1(const Value: tsometype);
begin
  ffield1 := Value;
end;


{$pop}

{ Case tobject7.pas }
{$push}

{$APPTYPE console}
{$ifdef fpc}
  {$H+}
{$endif}

type
  tobject7_TR = object
  private
    type
      TSomeType = integer;
    const
      SomeValue: TSomeType = 1;
    class function GetSomeProp: TSomeType; static;
  public
    class property SomeProp: TSomeType read GetSomeProp;
  end;

class function tobject7_TR.GetSomeProp: TSomeType;
begin
  Result := SomeValue;
end;


{$pop}

{ Case trhlp41.pas }
{$push}
{ a helper hides an existing enumerator }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  trhlp41_PContainer = ^trhlp41_TContainer;

  trhlp41_TContainerEnum = class
  private
    fIndex: Integer;
    fContainer: trhlp41_PContainer;
    fForward: Boolean;
  public
    constructor Create(aContainer: trhlp41_PContainer; aForward: Boolean);
    function GetCurrent: Integer;
    function MoveNext: Boolean;
    property Current: Integer read GetCurrent;
  end;

  trhlp41_TContainer = record
    Contents: array[0..5] of Integer;
    function GetEnumerator: trhlp41_TContainerEnum;
    procedure Init;
  end;

  trhlp41_TContainerHelper = record helper for trhlp41_TContainer
    function GetEnumerator: trhlp41_TContainerEnum;
  end;

{ TContainer }

procedure trhlp41_TContainer.Init;
var
  trhlp41_i: Integer;
begin
  for trhlp41_i := Low(Contents) to High(Contents) do
    Contents[trhlp41_i] := trhlp41_i;
end;

function trhlp41_TContainer.GetEnumerator: trhlp41_TContainerEnum;
begin
  Result := trhlp41_TContainerEnum.Create(@Self, True);
end;

{ TContainerHelper }

function trhlp41_TContainerHelper.GetEnumerator: trhlp41_TContainerEnum;
begin
  Result := trhlp41_TContainerEnum.Create(@Self, False);
end;

{ TContainerEnum }

constructor trhlp41_TContainerEnum.Create(aContainer: trhlp41_PContainer; aForward: Boolean);
begin
  fContainer := aContainer;
  fForward := aForward;
  if fForward then
    fIndex := Low(fContainer^.Contents) - 1
  else
    fIndex := High(fContainer^.Contents) + 1;
end;

function trhlp41_TContainerEnum.GetCurrent: Integer;
begin
  Result := fContainer^.Contents[fIndex];
end;

function trhlp41_TContainerEnum.MoveNext: Boolean;
begin
  if fForward then begin
    Inc(fIndex);
    Result := fIndex <= High(fContainer^.Contents);
  end else begin
    Dec(fIndex);
    Result := fIndex >= Low(fContainer^.Contents);
  end;
end;

var
  trhlp41_cont: trhlp41_TContainer;
  trhlp41_i, trhlp41_c: Integer;

{$pop}

{ Case tstatic1.pas }
{$push}

{$APPTYPE console}
{$ifdef fpc}
  {$H+}
{$endif}

type
  tstatic1_TSomeClass = class
  private
    class var
      FSomethingStatic: Integer;
  public
    class procedure SomeClassMethod(A: Integer);
    class procedure SomeStaticMethod(A: Integer); inline; static;
  end;

{ TSomeClass }

class procedure tstatic1_TSomeClass.SomeClassMethod(A: Integer);
begin
  WriteLn('TSomeClass.SomeClassMethod: ', A);
end;

// for now fpc requires 'static' modifiers also in the class implementation
class procedure tstatic1_TSomeClass.SomeStaticMethod(A: Integer);
begin
  WriteLn('TSomeClass.SomeStaticMethod: ', A);
  WriteLn('TSomeClass.FSomethingStatic: ', FSomethingStatic);
  SomeClassMethod(A + 1);
end;


{$pop}

{ Case tstatic2.pas }
{$push}

{$APPTYPE console}
{$ifdef fpc}
  {$H+}
{$endif}

type
  tstatic2_TSomeClass = class
  private
    class var
      FSomethingStatic: Integer;
  public
    class procedure SetSomethingStatic(AValue: Integer); static;
    class property SomethingStatic: Integer read FSomethingStatic write SetSomethingStatic;
  end;

  tstatic2_TAnotherClass = class(tstatic2_TSomeClass)
  end;

{ TSomeClass }

class procedure tstatic2_TSomeClass.SetSomethingStatic(AValue: Integer);
begin
  FSomethingStatic := AValue;
  WriteLn('SomethingStatic:', SomethingStatic);
end;


{$pop}

{ Case tstatic5.pas }
{$push}

{$APPTYPE console}
{$ifdef fpc}
  {$H+}
{$endif}

type

  { TSomeClass }

  tstatic5_TSomeClass = class
  public
    class var
      FSomethingStatic: Integer;
      FSomethingStatic1: String;
    class procedure SetSomethingStatic(AValue: Integer); static;
    var
      FSomeRegularField: Integer;
      FSomeRegularField1: String;
    class var
      FSomethingStatic2: byte;
    class property SomethingStatic: Integer read FSomethingStatic write SetSomethingStatic;
    class property SomethingStatic1: String read FSomethingStatic1 write FSomethingStatic1;
    class property SomethingStatic2: byte read FSomethingStatic2 write FSomethingStatic2;
    property SomethingRegular: Integer read FSomeRegularField write FSomeRegularField;
    property SomethingRegular1: String read FSomeRegularField1 write FSomeRegularField1;
  end;

{ TSomeClass }

class procedure tstatic5_TSomeClass.SetSomethingStatic(AValue: Integer);
begin
  FSomethingStatic := AValue;
end;


{$pop}

begin

{ Case tchlp35.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp35_t := tchlp35_TTestSub.Create;
  tchlp35_res := tchlp35_t.AccessTest;
  Writeln('f.AccessTest: ', tchlp35_res);
  if tchlp35_res <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp36.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp36_t := tchlp36_TTestSub.Create;
  tchlp36_res := tchlp36_t.AccessTest;
  Writeln('f.AccessTest: ', tchlp36_res);
  if tchlp36_res <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp38.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp38_t := tchlp38_TTestSub.Create;
  tchlp38_res := tchlp38_t.Test;
  Writeln('b.TestFoo: ', tchlp38_res);
  if tchlp38_res <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp39.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp39_t := tchlp39_TTestSub.Create;
  tchlp39_res := tchlp39_t.Test;
  Writeln('b.TestFoo: ', tchlp39_res);
  if tchlp39_res <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp40.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp40_t := tchlp40_TTest.Create;
  tchlp40_res := tchlp40_t.Test(True);
  Writeln('t.Test: ', tchlp40_res);
  if tchlp40_res <> 1 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp41.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp41_t := tchlp41_TTest.Create;
  tchlp41_res := tchlp41_t.Test(True);
  Writeln('t.Test: ', tchlp41_res);
  if tchlp41_res <> 1 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp42.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp42_t := tchlp42_TTest.Create;
  tchlp42_res := tchlp42_t.Test(True);
  Writeln('t.Test: ', tchlp42_res);
  if tchlp42_res <> 1 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp44.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp44_t := tchlp44_TTestSub.Create;
  tchlp44_res := tchlp44_t.AccessTest;
  Writeln('t.AccessTest: ', tchlp44_res);
  if tchlp44_res <> 1 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp46.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp46_t := tchlp46_TTest.Create;
  tchlp46_res := tchlp46_t.Test(True);
  Writeln('t.Test: ', tchlp46_res);
  if tchlp46_res <> 1 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp47.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp47_t := tchlp47_TTestSub.Create;
  tchlp47_res := tchlp47_t.AccessTest;
  Writeln('t.AccessTest: ', tchlp47_res);
  if tchlp47_res <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp48.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp48_t := tchlp48_TTestSub.Create;
  tchlp48_res := tchlp48_t.AccessTest;
  Writeln('t.AccessTest: ', tchlp48_res);
  if tchlp48_res <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp49.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp49_t := tchlp49_TTestSub.Create;
  tchlp49_res := tchlp49_t.Test(True);
  Writeln('t.Test: ', tchlp49_res);
  if tchlp49_res <> 1 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp5.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp5_res := SizeOf(tchlp5_TTestHelper);
  Writeln('SizeOf(TTest): ', SizeOf(tchlp5_TTest));
  Writeln('SizeOf(TTestHelper): ', tchlp5_res);
  if tchlp5_res <> SizeOf(Pointer) then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp50.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp50_t := tchlp50_TTest.Create;
  tchlp50_res := tchlp50_t.Test(True);
  Writeln('t.Test: ', tchlp50_res);
  if tchlp50_res <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp51.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp51_t := tchlp51_TTest.Create;
  tchlp51_res := tchlp51_t.AccessTest;
  Writeln('t.AccessTest: ', tchlp51_res);
  if tchlp51_res <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp53.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp53_cont := tchlp53_TContainer.Create;
  tchlp53_c := 5;
  for tchlp53_i in tchlp53_cont do begin
    if tchlp53_c <> tchlp53_i then
      Halt(1);
    Writeln(tchlp53_i);
    Dec(tchlp53_c);
  end;
  Writeln('ok');
end;
{$pop}

{ Case tchlp54.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp54_res := tchlp54_TTest4.DoTest1;
  Writeln('TTest4.DoTest1: ', tchlp54_res);
  if tchlp54_res <> 2 then
    Halt(1);
  tchlp54_res := tchlp54_TTest4.DoTest2;
  Writeln('TTest4.DoTest2: ', tchlp54_res);
  if tchlp54_res <> 2 then
    Halt(2);
  tchlp54_res := tchlp54_TTest4.DoTest3;
  Writeln('TTest4.DoTest3: ', tchlp54_res);
  if tchlp54_res <> 2 then
    Halt(3);
  tchlp54_res := tchlp54_TTest4.DoTest4;
  Writeln('TTest4.DoTest4: ', tchlp54_res);
  if tchlp54_res <> 1 then
    Halt(4);
  Writeln('ok');
end;
{$pop}

{ Case tchlp6.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp6_t := tchlp6_TTest.Create;
  tchlp6_res := tchlp6_t[3];
  Writeln('value: ', tchlp6_res);
  if tchlp6_res <> 3 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp7.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp7_t := tchlp7_TTest.Create;
  tchlp7_res := tchlp7_t[3];
  Writeln('value: ', tchlp7_res);
  if tchlp7_res <> 3 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp8.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp8_t := tchlp8_TTest.Create;
  tchlp8_res := tchlp8_t[3];
  Writeln('value: ', tchlp8_res);
  if tchlp8_res <> 3 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tclass11a.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tclass11a_TSomeClass.Test;
  tclass11a_TDescendant.Test;
end;
{$pop}

{ Case tclass12a.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tclass12a_TSomeClass.WritePrivateConst;
end;
{$pop}

{ Case tclass12c.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
end;
{$pop}

{ Case tclass12d.pas }
{$push}
{$APPTYPE console}
{$ifdef fpc}

{$H+}
{$endif}
begin
  if tclass12d_TR.SomeValue <> 1 then
    halt(1);
  if tclass12d_TR.SomeProp <> 1 then
    halt(1);
  WriteLn('ok');
end;
{$pop}

{ Case tclass9.pas }
{$push}
{$ifdef fpc}

{$H+}
{$endif}
{$APPTYPE CONSOLE}
begin
  tclass9_SomeClass.SomeProperty := 1;
  WriteLn(tclass9_SomeClass.SomeProperty);
end;
{$pop}

{ Case tobject6.pas }
{$push}
{$APPTYPE console}
{$ifdef fpc}

{$H+}
{$endif}
begin
  tobject6_TR.field1 := 10;
  if tobject6_TR.field1 <> 10 then
    halt(1);
  WriteLn(tobject6_TR.somevalue);
  if tobject6_TR.somevalue <> 1 then
    halt(2);
  WriteLn('ok');
end;
{$pop}

{ Case tobject7.pas }
{$push}
{$APPTYPE console}
{$ifdef fpc}

{$H+}
{$endif}
begin
  if tobject7_TR.SomeValue <> 1 then
    halt(1);
  if tobject7_TR.SomeProp <> 1 then
    halt(1);
  WriteLn('ok');
end;
{$pop}

{ Case trhlp41.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  trhlp41_cont.Init;
  trhlp41_c := 5;
  for trhlp41_i in trhlp41_cont do begin
    if trhlp41_c <> trhlp41_i then
      Halt(1);
    Writeln(trhlp41_i);
    Dec(trhlp41_c);
  end;
  Writeln('ok');
end;
{$pop}

{ Case tstatic1.pas }
{$push}
{$APPTYPE console}
{$ifdef fpc}

{$H+}
{$endif}
begin
  tstatic1_TSomeClass.FSomethingStatic := 4;
  tstatic1_TSomeClass.SomeStaticMethod(1);
end;
{$pop}

{ Case tstatic2.pas }
{$push}
{$APPTYPE console}
{$ifdef fpc}

{$H+}
{$endif}
begin
  tstatic2_TSomeClass.SomethingStatic := 4;
  if tstatic2_TSomeClass.SomethingStatic <> 4 then
    halt(1);
  tstatic2_TAnotherClass.SomethingStatic := 10;
  if tstatic2_TSomeClass.SomethingStatic <> 10 then
    halt(2); // outputs 10
end;
{$pop}

{ Case tstatic5.pas }
{$push}
{$APPTYPE console}
{$ifdef fpc}

{$H+}
{$endif}
begin
end;
{$pop}

end.
