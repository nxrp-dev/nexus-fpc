{ Consolidated classes regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tchlp1.pas }
{$push}


{ this tests that helpers can introduce instance methods for classes - mode
  Delphi }


{$ifdef fpc}
  
{$endif}

type
  tchlp1_TTest = class

  end;

  tchlp1_TTestHelper = class helper for tchlp1_TTest
    procedure Test;
  end;

procedure tchlp1_TTestHelper.Test;
begin

end;

var
  tchlp1_t: tchlp1_TTest;

{$pop}

{ Case tchlp10.pas }
{$push}


{ method modifiers of the extended class are completly irrelevant }


{$ifdef fpc}
  
{$endif}

type
  tchlp10_TTest = class
    procedure Test; virtual;
  end;

  tchlp10_TTestHelper = class helper for tchlp10_TTest
    procedure Test; virtual;
  end;

  tchlp10_TTestHelperSub = class helper(tchlp10_TTestHelper) for tchlp10_TTest
    procedure Test; override;
  end;

procedure tchlp10_TTest.Test;
begin

end;

procedure tchlp10_TTestHelper.Test;
begin

end;

procedure tchlp10_TTestHelperSub.Test;
begin

end;


{$pop}

{ Case tchlp2.pas }
{$push}


{ this tests that helpers can introduce class methods for classes - mode
  Delphi }


{$ifdef fpc}
  
{$endif}

type
  tchlp2_TTest = class

  end;

  tchlp2_TTestHelper = class helper for tchlp2_TTest
    class procedure Test;
  end;

class procedure tchlp2_TTestHelper.Test;
begin

end;


{$pop}

{ Case tchlp33.pas }
{$push}


{ overloading needs to be enabled explicitly }


{$ifdef fpc}
  
{$endif}

type
  tchlp33_TTest = class
    procedure Test(const aTest: String);
  end;

  tchlp33_TTestHelper = class helper for tchlp33_TTest
    procedure Test; overload;
  end;

procedure tchlp33_TTest.Test(const aTest: String);
begin

end;

procedure tchlp33_TTestHelper.Test;
begin

end;

var
  tchlp33_t: tchlp33_TTest;

{$pop}

{ Case tchlp34.pas }
{$push}


{ a helper can already be accessed when implementing a class' methods }


{$ifdef fpc}
  
{$endif}

type
  tchlp34_TTest = class
    procedure Test;
  end;

  tchlp34_TTestHelper = class helper for tchlp34_TTest
    procedure DoSomething;
  end;

procedure tchlp34_TTest.Test;
begin
  DoSomething;
end;

procedure tchlp34_TTestHelper.DoSomething;
begin

end;


{$pop}

{ Case tchlp4.pas }
{$push}


{ this tests that helpers can introduce class methods for classes - mode
  ObjFPC }


{$ifdef fpc}
  
{$endif}

type
  tchlp4_TTest = class

  end;

  tchlp4_TTestHelper = class helper for tchlp4_TTest
    class procedure Test;
  end;

class procedure tchlp4_TTestHelper.Test;
begin

end;


{$pop}

{ Case tchlp52.pas }
{$push}


{ a helper may introduce an enumerator }


{$ifdef fpc}
  
{$endif}

type
  tchlp52_TContainer = class
    Contents: array[0..5] of Integer;
    constructor Create;
  end;

  tchlp52_TContainerEnum = class
  private
    fIndex: Integer;
    fContainer: tchlp52_TContainer;
  public
    constructor Create(aContainer: tchlp52_TContainer);
    function GetCurrent: Integer;
    function MoveNext: Boolean;
    property Current: Integer read GetCurrent;
  end;

  tchlp52_TContainerHelper = class helper for tchlp52_TContainer
    function GetEnumerator: tchlp52_TContainerEnum;
  end;

{ TContainer }

constructor tchlp52_TContainer.Create;
var
  tchlp52_i: Integer;
begin
  for tchlp52_i := Low(Contents) to High(Contents) do
    Contents[tchlp52_i] := tchlp52_i;
end;

{ TContainerHelper }

function tchlp52_TContainerHelper.GetEnumerator: tchlp52_TContainerEnum;
begin
  Result := tchlp52_TContainerEnum.Create(Self);
end;

{ TContainerEnum }

constructor tchlp52_TContainerEnum.Create(aContainer: tchlp52_TContainer);
begin
  fContainer := aContainer;
  fIndex := Low(fContainer.Contents) - 1;
end;

function tchlp52_TContainerEnum.GetCurrent: Integer;
begin
  Result := fContainer.Contents[fIndex];
end;

function tchlp52_TContainerEnum.MoveNext: Boolean;
begin
  Inc(fIndex);
  Result := fIndex <= High(fContainer.Contents);
end;

var
  tchlp52_cont: tchlp52_TContainer;
  tchlp52_i: Integer;

{$pop}

{ Case tclass13a.pas }
{$push}



type
  tclass13a_tc = class
   type
    tnest = class
    end;
  end;
  tclass13a_td = class(tclass13a_tc)
   type
     tnest = class(tclass13a_tc.tnest)
     end;
  end;


{$pop}

{ Case tclass13b.pas }
{$push}




type
  tclass13b_tc = class
    type
      tforward = class;

      tnested = class
        type
          tforward = class;

          tforward = class
          end;
      end;

      tforward = class
      end;
  end;


{$pop}

{ Case tclass13d.pas }
{$push}



type
  tclass13d_TObj = class
  const
    Val = 1;
    V1: Integer = Val;
    V2: Integer = tclass13d_TObj.Val;
  end;


{$pop}

{ Case tdefault10.pas }
{$push}


{ Default also supports inline specializations }




type
  tdefault10_TTest<tdefault10_T> = class
    f: tdefault10_T;
  end;

var
  tdefault10_t: tdefault10_TTest<LongInt>;

{$pop}

{ Case thlp26.pas }
{$push}


{ a helper may extend specialized generics }
{ Note: this does currently not compile in Delphi }


{$ifdef fpc}
  
{$endif}

type
  thlp26_TFoo<T> = class
    Field: T;
  end;

  thlp26_TFooInteger = thlp26_TFoo<Integer>;

  thlp26_TFooHelper = class helper for thlp26_TFooInteger
  end;


{$pop}

{ Case thlp27.pas }
{$push}


{ a helper can extend the subclass of a specialized generic }


{$ifdef fpc}
  
{$endif}

type
  thlp27_TFoo<T> = class
    Field: T;
  end;

  thlp27_TFooInteger = thlp27_TFoo<Integer>;

  thlp27_TFooBar = class(thlp27_TFooInteger)

  end;

  thlp27_TFooHelper = class helper for thlp27_TFooBar
  end;


{$pop}

{ Case thlp29.pas }
{$push}


{ a helper may contain generic methods }


{$ifdef fpc}
  
{$endif}

type
  thlp29_TTest = class

  end;

  thlp29_TTestHelper = class helper for thlp29_TTest
    function Test<T>: T;
  end;

function thlp29_TTestHelper.Test<T>: T;
begin

end;


{$pop}

{ Case toperator93.pas }
{$push}






type
  toperator93_TString80 = String[80];
  toperator93_TString90 = String[90];
  toperator93_TString40 = String[40];
  toperator93_TString100 = String[100];

  toperator93_TTest = record
    class operator Implicit(const aArg: toperator93_TTest): toperator93_TString80;
  end;

class operator toperator93_TTest.Implicit(const aArg: toperator93_TTest): toperator93_TString80;
begin

end;

var
  toperator93_t: toperator93_TTest;
  toperator93_s: toperator93_TString80;

{$pop}

{ Case trhlp29.pas }
{$push}


{ overloading needs to be enabled explicitly }


{$ifdef fpc}
  
{$endif}

type
  trhlp29_TTest = class
    procedure Test(const aTest: String);
  end;

  trhlp29_TTestHelper = class helper for trhlp29_TTest
    procedure Test; overload;
  end;

procedure trhlp29_TTest.Test(const aTest: String);
begin

end;

procedure trhlp29_TTestHelper.Test;
begin

end;

var
  trhlp29_t: trhlp29_TTest;

{$pop}

{ Case trhlp3.pas }
{$push}


{ this tests that helpers can introduce class methods for records - mode
  Delphi }


{$ifdef fpc}
  
{$endif}

type
  trhlp3_TTest = record
  end;

  trhlp3_TTestHelper = record helper for trhlp3_TTest
    class procedure Test; static;
  end;

class procedure trhlp3_TTestHelper.Test;
begin

end;


{$pop}

{ Case trhlp30.pas }
{$push}


{ a helper can already be accessed when implementing a record's methods }


{$ifdef fpc}
  
{$endif}

type
  trhlp30_TTest = class
    procedure Test;
  end;

  trhlp30_TTestHelper = class helper for trhlp30_TTest
    procedure DoTest;
  end;

procedure trhlp30_TTest.Test;
begin
  DoTest;
end;

procedure trhlp30_TTestHelper.DoTest;
begin

end;


{$pop}

{ Case trhlp40.pas }
{$push}


{ a helper may introduce an enumerator }


{$ifdef fpc}
  
{$endif}

type
  trhlp40_TContainer = record
    Contents: array[0..5] of Integer;
    procedure Init;
  end;
  trhlp40_PContainer = ^trhlp40_TContainer;

  trhlp40_TContainerEnum = class
  private
    fIndex: Integer;
    fContainer: trhlp40_PContainer;
  public
    constructor Create(aContainer: trhlp40_PContainer);
    function GetCurrent: Integer;
    function MoveNext: Boolean;
    property Current: Integer read GetCurrent;
  end;

  trhlp40_TContainerHelper = record helper for trhlp40_TContainer
    function GetEnumerator: trhlp40_TContainerEnum;
  end;

{ TContainer }

procedure trhlp40_TContainer.Init;
var
  trhlp40_i: Integer;
begin
  for trhlp40_i := Low(Contents) to High(Contents) do
    Contents[trhlp40_i] := trhlp40_i;
end;

{ TContainerHelper }

function trhlp40_TContainerHelper.GetEnumerator: trhlp40_TContainerEnum;
begin
  Result := trhlp40_TContainerEnum.Create(@Self);
end;

{ TContainerEnum }

constructor trhlp40_TContainerEnum.Create(aContainer: trhlp40_PContainer);
begin
  fContainer := aContainer;
  fIndex := Low(fContainer^.Contents) - 1;
end;

function trhlp40_TContainerEnum.GetCurrent: Integer;
begin
  Result := fContainer^.Contents[fIndex];
end;

function trhlp40_TContainerEnum.MoveNext: Boolean;
begin
  Inc(fIndex);
  Result := fIndex <= High(fContainer^.Contents);
end;

var
  trhlp40_cont: trhlp40_TContainer;
  trhlp40_i: Integer;

{$pop}

begin

{ Case tchlp1.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  tchlp1_t.Test;
end;
{$pop}

{ Case tchlp10.pas }
{$push}
{$ifdef fpc}

{$endif}
begin

end;
{$pop}

{ Case tchlp2.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  tchlp2_TTest.Test;
end;
{$pop}

{ Case tchlp33.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  tchlp33_t := tchlp33_TTest.Create;
  tchlp33_t.Test;
  tchlp33_t.Test('Foo');
end;
{$pop}

{ Case tchlp34.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tchlp4.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  tchlp4_TTest.Test;
end;
{$pop}

{ Case tchlp52.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  tchlp52_cont := tchlp52_TContainer.Create;
  for tchlp52_i in tchlp52_cont do ;
end;
{$pop}

{ Case tclass13a.pas }
{$push}

begin
end;
{$pop}

{ Case tclass13b.pas }
{$push}

begin
end;
{$pop}

{ Case tclass13d.pas }
{$push}

begin
end;
{$pop}

{ Case tdefault10.pas }
{$push}

begin
  tdefault10_t := Default(tdefault10_TTest<LongInt>);
end;
{$pop}

{ Case thlp26.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case thlp27.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case thlp29.pas }
{$push}
{$ifdef fpc}

{$endif}
begin

end;
{$pop}

{ Case toperator93.pas }
{$push}

begin
  toperator93_s := toperator93_t;
end;
{$pop}

{ Case trhlp29.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  trhlp29_t := trhlp29_TTest.Create;
  trhlp29_t.Test;
  trhlp29_t.Test('Foo');
end;
{$pop}

{ Case trhlp3.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  trhlp3_TTest.Test;
end;
{$pop}

{ Case trhlp30.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case trhlp40.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  trhlp40_cont.Init;
  for trhlp40_i in trhlp40_cont do ;
end;
{$pop}

end.
