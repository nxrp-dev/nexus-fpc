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

unit tests.generics.arrayhelper;

{$mode delphi}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, Generics.Defaults, Generics.Collections;

type

  { TTestArrayHelper }

  TTestArrayHelper = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  protected
    procedure CheckBinarySearch(const AArray: TArray<Integer>;
      AValue: Integer; AExpectedResult: boolean; out ASearchResult: TBinarySearchResult);
    procedure CheckSearchResult(const ASearchResult: TBinarySearchResult;
      AValue: Integer; ACandidateIndex, AFoundIndex: SizeInt; ACompareResult: Boolean);
  public
    procedure Test_BinarySearch_Integers;
    procedure Test_BinarySearch_EmptyArray;
    procedure Test_IndexOf;
    procedure Test_FirstIndexOf;
    procedure Test_LastIndexOf;
    procedure Test_Min;
    procedure Test_Max;
    procedure Test_Contains;
    procedure Test_Reverse;
  end;

procedure RegistertestsgenericsarrayhelperTests(ARegistry: TNXTestRegistry);

implementation

{ TTestArrayHelper }

procedure TTestArrayHelper.CheckBinarySearch(const AArray: TArray<Integer>;
  AValue: Integer; AExpectedResult: boolean; out
  ASearchResult: TBinarySearchResult);
begin
  TestContext.AssertTrue((AExpectedResult)=(TArrayHelper<Integer>.BinarySearch(AArray,AValue,ASearchResult)), 'Wrong BinarySearch result for ' + AValue.ToString);
end;

procedure TTestArrayHelper.CheckSearchResult(const
  ASearchResult: TBinarySearchResult; AValue: Integer; ACandidateIndex,
  AFoundIndex: SizeInt; ACompareResult: Boolean);
begin
  with ASearchResult do
  begin
    TestContext.AssertTrue((ACandidateIndex)=(CandidateIndex), 'Wrong binary search result (CandidateIndex) for ' + AValue.ToString);
    TestContext.AssertTrue((AFoundIndex)=(FoundIndex), 'Wrong binary search result (FoundIndex) for ' + AValue.ToString);
    TestContext.AssertTrue(ACompareResult, 'Wrong binary search result (CompareResult) for ' + AValue.ToString);
  end;
end;

procedure TTestArrayHelper.Test_BinarySearch_Integers;
var
  a: TArray<Integer>;
  LSearchResult: TBinarySearchResult;
begin
  a := TArray<Integer>.Create(1,3,5,7,9,11,13,15,20);

  CheckBinarySearch(a, 10, False, LSearchResult);
  CheckSearchResult(LSearchResult, 10, 5, -1, LSearchResult.CompareResult>0);

  CheckBinarySearch(a, 20, True, LSearchResult);
  CheckSearchResult(LSearchResult, 20, 8, 8, LSearchResult.CompareResult=0);
end;

procedure TTestArrayHelper.Test_BinarySearch_EmptyArray;
var
  LSearchResult: TBinarySearchResult;
begin
  CheckBinarySearch(nil, 1, False, LSearchResult);
  CheckSearchResult(LSearchResult, 1, -1, -1, LSearchResult.CompareResult=0);
end;

procedure TTestArrayHelper.Test_IndexOf;
var
  a: TArray<Integer>;
begin
  a := TArray<Integer>.Create(1,3,5,7,9,11,13,15,20);
  TestContext.AssertTrue((4)=(TArrayHelper<Integer>.IndexOf(A,9,TComparer<Integer>.Default)), 'Correct find result for 9');
  TestContext.AssertTrue((-1)=(TArrayHelper<Integer>.IndexOf(A,33,TComparer<Integer>.Default)), 'Correctfind result for 33');
  TestContext.AssertTrue((4)=(TArrayHelper<Integer>.IndexOf(A,9)), 'Correct find result for 9 using default comparer');
end;

procedure TTestArrayHelper.Test_FirstIndexOf;

var
  a: TArray<Integer>;
begin
  a := TArray<Integer>.Create(1,3,5,7,9,11,13,9,20);
  TestContext.AssertTrue((4)=(TArrayHelper<Integer>.FirstIndexOf(A,9,TComparer<Integer>.Default)), 'Correct find result for 9');
  TestContext.AssertTrue((4)=(TArrayHelper<Integer>.FirstIndexOf(A,9)), 'Correct find result for 9 using default comparer');
end;

procedure TTestArrayHelper.Test_LastIndexOf;
var
  a: TArray<Integer>;
begin
  a := TArray<Integer>.Create(1,3,5,7,9,11,13,9,20);
  TestContext.AssertTrue((7)=(TArrayHelper<Integer>.LastIndexOf(A,9,TComparer<Integer>.Default)), 'Correct find result for 9');
  TestContext.AssertTrue((7)=(TArrayHelper<Integer>.LastIndexOf(A,9)), 'Correct find result for 9 using default comparer');
end;

procedure TTestArrayHelper.Test_Min;
var
  a: TArray<Integer>;
begin
  a := TArray<Integer>.Create(1,3,5,7,9,11,13,15,20);
  TestContext.AssertTrue((1)=(TArrayHelper<Integer>.Min(A,TComparer<Integer>.Default,-1)), 'Correct min');
  TestContext.AssertTrue((1)=(TArrayHelper<Integer>.Min(A,-1)), 'Correct min using default comparer');
  a:=[];
  TestContext.AssertTrue((-1)=(TArrayHelper<Integer>.Min(A,TComparer<Integer>.Default,-1)), 'No min');
  TestContext.AssertTrue((-1)=(TArrayHelper<Integer>.Min(A,-1)), 'No min using default comparer');
end;

procedure TTestArrayHelper.Test_Max;
var
  a: TArray<Integer>;
begin
  a := TArray<Integer>.Create(1,3,5,7,9,11,13,15,20);
  TestContext.AssertTrue((20)=(TArrayHelper<Integer>.Max(A,TComparer<Integer>.Default,-1)), 'Correct max');
  TestContext.AssertTrue((20)=(TArrayHelper<Integer>.Max(A,-1)), 'Correct max using default comparer');
  a:=[];
  TestContext.AssertTrue((-1)=(TArrayHelper<Integer>.Max(A,TComparer<Integer>.Default,-1)), 'No max ');
  TestContext.AssertTrue((-1)=(TArrayHelper<Integer>.Max(A,-1)), 'No max using default comparer');
end;

procedure TTestArrayHelper.Test_Contains;
var
  a: TArray<Integer>;
begin
  a := TArray<Integer>.Create(1,3,5,7,9,11,13,15,20);
  TestContext.AssertTrue(TArrayHelper<Integer>.Contains(A,15,TComparer<Integer>.Default), 'Have 15');
  TestContext.AssertTrue(not (TArrayHelper<Integer>.Contains(A,14,TComparer<Integer>.Default)), 'Does not have 15');
  a:=[];
  TestContext.AssertTrue(not (TArrayHelper<Integer>.Contains(A,15,TComparer<Integer>.Default)), 'Empty does not have 15');
end;

procedure TTestArrayHelper.Test_Reverse;
var
  b,a: TArray<Integer>;
  len,I : integer;
begin
  a := TArray<Integer>.Create(1,3,5,7,9,11,13,15,20);
  len:=Length(a);
  TArrayHelper<Integer>.Reverse(a,b);
  for I:=0 to Length(a)-1 do
    TestContext.AssertTrue((a[len-i-1])=(b[i]), 'At index i');
  a := TArray<Integer>.Create(1,3,5,7,9,11,13,15,20);
  b:=a;
  len:=Length(a);
  TArrayHelper<Integer>.Reverse(a,a);
  for I:=0 to Length(b)-1 do
    TestContext.AssertTrue((a[len-i-1])=(b[i]), 'At index i');
end;


constructor TTestArrayHelper.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestArrayHelperTest_BinarySearch_Integers(AContext: TNXTestContext);
var lFixture: TTestArrayHelper;
begin
  lFixture:=TTestArrayHelper.Create(AContext, 'Test_BinarySearch_Integers');
  try
    lFixture.Test_BinarySearch_Integers;
  finally lFixture.Free; end;
end;

procedure RunTTestArrayHelperTest_BinarySearch_EmptyArray(AContext: TNXTestContext);
var lFixture: TTestArrayHelper;
begin
  lFixture:=TTestArrayHelper.Create(AContext, 'Test_BinarySearch_EmptyArray');
  try
    lFixture.Test_BinarySearch_EmptyArray;
  finally lFixture.Free; end;
end;

procedure RunTTestArrayHelperTest_IndexOf(AContext: TNXTestContext);
var lFixture: TTestArrayHelper;
begin
  lFixture:=TTestArrayHelper.Create(AContext, 'Test_IndexOf');
  try
    lFixture.Test_IndexOf;
  finally lFixture.Free; end;
end;

procedure RunTTestArrayHelperTest_FirstIndexOf(AContext: TNXTestContext);
var lFixture: TTestArrayHelper;
begin
  lFixture:=TTestArrayHelper.Create(AContext, 'Test_FirstIndexOf');
  try
    lFixture.Test_FirstIndexOf;
  finally lFixture.Free; end;
end;

procedure RunTTestArrayHelperTest_LastIndexOf(AContext: TNXTestContext);
var lFixture: TTestArrayHelper;
begin
  lFixture:=TTestArrayHelper.Create(AContext, 'Test_LastIndexOf');
  try
    lFixture.Test_LastIndexOf;
  finally lFixture.Free; end;
end;

procedure RunTTestArrayHelperTest_Min(AContext: TNXTestContext);
var lFixture: TTestArrayHelper;
begin
  lFixture:=TTestArrayHelper.Create(AContext, 'Test_Min');
  try
    lFixture.Test_Min;
  finally lFixture.Free; end;
end;

procedure RunTTestArrayHelperTest_Max(AContext: TNXTestContext);
var lFixture: TTestArrayHelper;
begin
  lFixture:=TTestArrayHelper.Create(AContext, 'Test_Max');
  try
    lFixture.Test_Max;
  finally lFixture.Free; end;
end;

procedure RunTTestArrayHelperTest_Contains(AContext: TNXTestContext);
var lFixture: TTestArrayHelper;
begin
  lFixture:=TTestArrayHelper.Create(AContext, 'Test_Contains');
  try
    lFixture.Test_Contains;
  finally lFixture.Free; end;
end;

procedure RunTTestArrayHelperTest_Reverse(AContext: TNXTestContext);
var lFixture: TTestArrayHelper;
begin
  lFixture:=TTestArrayHelper.Create(AContext, 'Test_Reverse');
  try
    lFixture.Test_Reverse;
  finally lFixture.Free; end;
end;

procedure RegistertestsgenericsarrayhelperTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tests.generics.arrayhelper.TTestArrayHelper');
  lSuite.AddTest('Test_BinarySearch_Integers', @RunTTestArrayHelperTest_BinarySearch_Integers, 'generics');
  lSuite.AddTest('Test_BinarySearch_EmptyArray', @RunTTestArrayHelperTest_BinarySearch_EmptyArray, 'generics');
  lSuite.AddTest('Test_IndexOf', @RunTTestArrayHelperTest_IndexOf, 'generics');
  lSuite.AddTest('Test_FirstIndexOf', @RunTTestArrayHelperTest_FirstIndexOf, 'generics');
  lSuite.AddTest('Test_LastIndexOf', @RunTTestArrayHelperTest_LastIndexOf, 'generics');
  lSuite.AddTest('Test_Min', @RunTTestArrayHelperTest_Min, 'generics');
  lSuite.AddTest('Test_Max', @RunTTestArrayHelperTest_Max, 'generics');
  lSuite.AddTest('Test_Contains', @RunTTestArrayHelperTest_Contains, 'generics');
  lSuite.AddTest('Test_Reverse', @RunTTestArrayHelperTest_Reverse, 'generics');
end;

end.
