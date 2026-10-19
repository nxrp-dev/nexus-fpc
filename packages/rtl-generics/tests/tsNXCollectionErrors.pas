// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
unit tsNXCollectionErrors;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterNXCollectionErrorTests(ARegistry: TNXTestRegistry);
implementation
uses Classes, SysUtils, Generics.Collections, obNXTestContext, obNXTestSuite;

procedure TestDictionaryMissingKey(AContext: TNXTestContext);
var
  lMap: specialize TDictionary<Integer, Integer>;
  lValue: Integer;
begin
  lMap := specialize TDictionary<Integer, Integer>.Create;
  try
    try
      lValue := lMap[42];
      AContext.AssertTrue(False, 'A missing key must raise an exception.');
    except
      on lError: EListError do
        AContext.AssertEquals('Dictionary key does not exist', lError.Message);
    end;
  finally
    lMap.Free;
  end;
end;

procedure TestCuckooMissingKey(AContext: TNXTestContext);
var
  lMap: specialize THashMap<Integer, Integer>;
  lValue: Integer;
begin
  lMap := specialize THashMap<Integer, Integer>.Create;
  try
    try
      lValue := lMap[42];
      AContext.AssertTrue(False, 'A missing key must raise an exception.');
    except
      on lError: EListError do
        AContext.AssertEquals('Dictionary key does not exist', lError.Message);
    end;
  finally
    lMap.Free;
  end;
end;

procedure TestTreeMissingKey(AContext: TNXTestContext);
var
  lMap: specialize TAVLTreeMap<Integer, Integer>;
  lValue: Integer;
begin
  lMap := specialize TAVLTreeMap<Integer, Integer>.Create;
  try
    try
      lValue := lMap[42];
      AContext.AssertTrue(False, 'A missing key must raise an exception.');
    except
      on lError: EAVLTree do
        AContext.AssertEquals('Dictionary key does not exist', lError.Message);
    end;
  finally
    lMap.Free;
  end;
end;

procedure RegisterNXCollectionErrorTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('Collections.MissingKeys');
  lSuite.AddTest('Dictionary', @TestDictionaryMissingKey, 'generics');
  lSuite.AddTest('CuckooMap', @TestCuckooMissingKey, 'generics');
  lSuite.AddTest('AVLTree', @TestTreeMissingKey, 'generics');
end;
end.
