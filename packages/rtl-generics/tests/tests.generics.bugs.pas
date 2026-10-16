{
    This file is part of the Free Pascal/NewPascal run time library.
    Copyright (c) 2018 by Maciej Izak (hnb),
    member of the NewPascal development team (http://newpascal.org)

    Copyright(c) 2004-2018 DaThoX

    It contains tests for the Free Pascal generics library

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

    Acknowledgment

    Thanks to Sphere 10 Software (http://sphere10.com) for sponsoring
    many new types, tests and major refactoring of entire library

 **********************************************************************}

unit tests.generics.bugs;

{$mode delphi}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, Generics.Collections, Generics.Defaults;

type

  { TTestBugs }

  TTestBugs = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  public
    procedure Test_QuadraticProbing_InfinityLoop;
    procedure Test_GetEqualityComparer;
    procedure TestBinaryOrdering;
    procedure TestAnsiStringBinaryOrdering;
    Procedure TestDictionaryWithStringKeys;
    Procedure TestListIndexOf;
    Procedure TestContainsValue;
  end;

procedure RegistertestsgenericsbugsTests(ARegistry: TNXTestRegistry);

implementation

{ TTestBugs }

procedure TTestBugs.Test_QuadraticProbing_InfinityLoop;
// https://github.com/maciej-izak/generics.collections/issues/4
var
  LMap: TOpenAddressingQP<string, pointer, TDelphiHashFactory>;
begin
  LMap := TOpenAddressingQP<string, pointer, TDelphiHashFactory>.Create();
  LMap.Add(#178#178#107#141#143#151#168#39#172#38#83#194#130#90#101, nil);
  LMap.Add(#193#190#172#41#144#231#52#62#45#117#108#45#217#71#77, nil);
  LMap.Add(#49#116#202#160#38#131#41#37#217#171#227#215#122#151#71, nil);
  LMap.Add(#148#159#199#71#198#97#69#201#116#45#195#184#178#129#200, nil);
  TestContext.AssertTrue((false)=(LMap.ContainsKey(#$E6'h=fzb'#$E5#$B4#$A0#$C4#$E6'B6r>')), '');
  LMap.Free;
end;

procedure TTestBugs.Test_GetEqualityComparer;
begin
  TDelphiQuadrupleHashFactory.GetHashService.LookupEqualityComparer(TypeInfo(Integer), SizeOf(Integer));
end;

procedure TTestBugs.TestBinaryOrdering;
{ Binary comparison means 'Z' (90) < 'a' (97).
  Locale-aware comparison would sort 'a' before 'Z'. }
var
  Cmp: IComparer<string>;
begin
  Cmp := TComparer<string>.Default;
  TestContext.AssertTrue(Cmp.Compare('Z', 'a') < 0, 'Z < a in binary order');
  TestContext.AssertTrue(Cmp.Compare('a', 'Z') > 0, 'a > Z in binary order');
  TestContext.AssertTrue(Cmp.Compare('hello', 'hello') = 0, 'equal strings');
  TestContext.AssertTrue(Cmp.Compare('', '') = 0, 'empty = empty');
  TestContext.AssertTrue(Cmp.Compare('', 'a') < 0, 'empty < non-empty');
  TestContext.AssertTrue(Cmp.Compare('a', '') > 0, 'non-empty > empty');
  TestContext.AssertTrue(Cmp.Compare('abc', 'abcd') < 0, 'shorter prefix < longer');
end;

procedure TTestBugs.TestAnsiStringBinaryOrdering;
var
  Cmp: IComparer<AnsiString>;
begin
  Cmp := TComparer<AnsiString>.Default;
  TestContext.AssertTrue(Cmp.Compare('Z', 'a') < 0, 'AnsiString: Z < a');
  TestContext.AssertTrue(Cmp.Compare('test', 'test') = 0, 'AnsiString: equal');
  TestContext.AssertTrue(Cmp.Compare('abc', 'abd') < 0, 'AnsiString: abc < abd');
end;

procedure TTestBugs.TestDictionaryWithStringKeys;
var
  Dict: TDictionary<string, Integer>;
begin
  Dict := TDictionary<string, Integer>.Create;
  try
    Dict.Add('alpha', 1);
    Dict.Add('beta', 2);
    Dict.Add('gamma', 3);
    TestContext.AssertTrue(Dict.ContainsKey('alpha'), 'Dict contains alpha');
    TestContext.AssertTrue(Dict.ContainsKey('beta'), 'Dict contains beta');
    TestContext.AssertTrue(not Dict.ContainsKey('delta'), 'Dict does not contain delta');
    TestContext.AssertTrue(Dict['alpha'] = 1, 'Dict[alpha] = 1');
    TestContext.AssertTrue(Dict['gamma'] = 3, 'Dict[gamma] = 3');
  finally
    Dict.Free;
  end;
end;

procedure TTestBugs.TestListIndexOf;
var
  List: TList<string>;
begin
  List := TList<string>.Create;
  try
    List.Add('first');
    List.Add('second');
    List.Add('third');
    TestContext.AssertTrue(List.IndexOf('first') = 0, 'IndexOf first = 0');
    TestContext.AssertTrue(List.IndexOf('third') = 2, 'IndexOf third = 2');
    TestContext.AssertTrue(List.IndexOf('missing') = -1, 'IndexOf missing = -1');
  finally
    List.Free;
  end;
end;

procedure TTestBugs.TestContainsValue;
var
  Dict: TDictionary<Integer, string>;
begin
  Dict := TDictionary<Integer, string>.Create;
  try
    Dict.Add(1, 'one');
    Dict.Add(2, 'two');
    Dict.Add(3, 'three');
    TestContext.AssertTrue(Dict.ContainsValue('one'), 'ContainsValue one');
    TestContext.AssertTrue(Dict.ContainsValue('three'), 'ContainsValue three');
    TestContext.AssertTrue(not Dict.ContainsValue('four'), 'Not ContainsValue four');
  finally
    Dict.Free;
  end;
end;


constructor TTestBugs.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestBugsTest_QuadraticProbing_InfinityLoop(AContext: TNXTestContext);
var lFixture: TTestBugs;
begin
  lFixture:=TTestBugs.Create(AContext, 'Test_QuadraticProbing_InfinityLoop');
  try
    lFixture.Test_QuadraticProbing_InfinityLoop;
  finally lFixture.Free; end;
end;

procedure RunTTestBugsTest_GetEqualityComparer(AContext: TNXTestContext);
var lFixture: TTestBugs;
begin
  lFixture:=TTestBugs.Create(AContext, 'Test_GetEqualityComparer');
  try
    lFixture.Test_GetEqualityComparer;
  finally lFixture.Free; end;
end;

procedure RunTTestBugsTestBinaryOrdering(AContext: TNXTestContext);
var lFixture: TTestBugs;
begin
  lFixture:=TTestBugs.Create(AContext, 'TestBinaryOrdering');
  try
    lFixture.TestBinaryOrdering;
  finally lFixture.Free; end;
end;

procedure RunTTestBugsTestAnsiStringBinaryOrdering(AContext: TNXTestContext);
var lFixture: TTestBugs;
begin
  lFixture:=TTestBugs.Create(AContext, 'TestAnsiStringBinaryOrdering');
  try
    lFixture.TestAnsiStringBinaryOrdering;
  finally lFixture.Free; end;
end;

procedure RunTTestBugsTestDictionaryWithStringKeys(AContext: TNXTestContext);
var lFixture: TTestBugs;
begin
  lFixture:=TTestBugs.Create(AContext, 'TestDictionaryWithStringKeys');
  try
    lFixture.TestDictionaryWithStringKeys;
  finally lFixture.Free; end;
end;

procedure RunTTestBugsTestListIndexOf(AContext: TNXTestContext);
var lFixture: TTestBugs;
begin
  lFixture:=TTestBugs.Create(AContext, 'TestListIndexOf');
  try
    lFixture.TestListIndexOf;
  finally lFixture.Free; end;
end;

procedure RunTTestBugsTestContainsValue(AContext: TNXTestContext);
var lFixture: TTestBugs;
begin
  lFixture:=TTestBugs.Create(AContext, 'TestContainsValue');
  try
    lFixture.TestContainsValue;
  finally lFixture.Free; end;
end;

procedure RegistertestsgenericsbugsTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tests.generics.bugs.TTestBugs');
  lSuite.AddTest('Test_QuadraticProbing_InfinityLoop', @RunTTestBugsTest_QuadraticProbing_InfinityLoop);
  lSuite.AddTest('Test_GetEqualityComparer', @RunTTestBugsTest_GetEqualityComparer);
  lSuite.AddTest('TestBinaryOrdering', @RunTTestBugsTestBinaryOrdering);
  lSuite.AddTest('TestAnsiStringBinaryOrdering', @RunTTestBugsTestAnsiStringBinaryOrdering);
  lSuite.AddTest('TestDictionaryWithStringKeys', @RunTTestBugsTestDictionaryWithStringKeys);
  lSuite.AddTest('TestListIndexOf', @RunTTestBugsTestListIndexOf);
  lSuite.AddTest('TestContainsValue', @RunTTestBugsTestContainsValue);
end;

end.
