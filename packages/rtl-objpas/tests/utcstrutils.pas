unit utcstrutils;

{$mode ObjFPC}{$H+}
{$COPERATORS ON}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, sysutils, strutils;

Type

  { TTestStrUtils }

  TTestStrUtils = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  public
    Procedure TestNaturalCompareText;

  end;

procedure RegisterutcstrutilsTests(ARegistry: TNXTestRegistry);

implementation

{ TTestStrUtils }

type
  CaseRec = record
    a, b: string;
    expect: int8;
  end;

const
  Cases: array[0 .. 4] of CaseRec = (
      (a: '100000000000000000000'; b: '100000000000000000001'; expect: -1),
      (a: ' 10 hi';                b: '010 hi';                expect:  0),
      (a: 'score: 10';             b: 'score:010';             expect:  0),
      (a: '9';                     b: ' ';                     expect: -1),
      (a: 'A';                     b: '';                      expect: +1)
  );

procedure TTestStrUtils.TestNaturalCompareText;

var
  somethingFailed: boolean = false;

  function RandomString: string;

  const
    TextChars = 'abAB ';
    NumberChars = '012';
  var
    iComp, iSym: SizeInt;
  begin
    result := '';
    for iComp := 0 to random(5) do
      case random(2) of
        0:
          for iSym := 0 to random(3) do
            result += TextChars[1 + random(length(TextChars))];
        else
          for iSym := 0 to random(3) do
            result += NumberChars[1 + random(length(NumberChars))];
      end;
  end;
const
  NFuzzStrings = 200;

var
  cs: CaseRec;
  got, ab: integer;
  desc : string;
  fuzz: array of string;
  i, iA, iB, iC: SizeInt;
  comparisons: array[0 .. NFuzzStrings - 1, 0 .. NFuzzStrings - 1] of int8;

begin
  for cs in Cases do
  begin
    got := NaturalCompareText(cs.a, cs.b);
    Desc:=Format('a = ''%s'', b = ''%s'' ',[cs.a, cs.b]);
    TestContext.AssertTrue((cs.expect)=(got), Desc);
  end;
  SetLength(fuzz, NFuzzStrings);
  fuzz[0] := '';
  fuzz[1] := ' ';
  for i := 2 to High(fuzz) do
    fuzz[i] := RandomString;

  for iA := 0 to High(fuzz) do
    for iB := iA to High(fuzz) do
    begin
      comparisons[iA, iB] := NaturalCompareText(fuzz[iA], fuzz[iB]);
      comparisons[iB, iA] := NaturalCompareText(fuzz[iB], fuzz[iA]);
      Desc:=Format('Antisymmetry: a= ''%s'', b= ''%s'' ',[fuzz[iA],fuzz[iB]]);
      TestContext.AssertTrue((-comparisons[iB, iA])=(comparisons[iA, iB]), 'Expect '+Desc);
    end;

  for iA := 0 to High(fuzz) do
    for iB := iA to High(fuzz) do
    begin
      ab := comparisons[iA, iB];
      for iC := 0 to High(fuzz) do
        begin
          Desc:=Format('Transitivity: a= ''%s'', b= ''%s'' , c= ''%s'' ',[fuzz[iA], fuzz[iB], fuzz[iC]]);
          TestContext.AssertTrue(not ((comparisons[iB, iC] = ab) and (comparisons[iA, iC] <> ab)), Desc);
        end;
    end;
end;


constructor TTestStrUtils.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestStrUtilsTestNaturalCompareText(AContext: TNXTestContext);
var lFixture: TTestStrUtils;
begin
  lFixture:=TTestStrUtils.Create(AContext, 'TestNaturalCompareText');
  try
    lFixture.TestNaturalCompareText;
  finally lFixture.Free; end;
end;

procedure RegisterutcstrutilsTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('utcstrutils.TTestStrUtils');
  lSuite.AddTest('TestNaturalCompareText', @RunTTestStrUtilsTestNaturalCompareText);
end;

end.
