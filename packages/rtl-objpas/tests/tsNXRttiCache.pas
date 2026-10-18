// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
unit tsNXRttiCache;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterNXRttiCacheTests(ARegistry: TNXTestRegistry);
implementation
uses Classes, Rtti, obNXTestContext, obNXTestSuite;

type
  TNXCacheFixture = class(TPersistent)
  private
    FValue: Integer;
  published
    property Value: Integer read FValue write FValue;
  end;

procedure TestCacheIdentity(AContext: TNXTestContext);
var
  lFirst, lSecond, lFull: TRttiContext;
  lType: TRttiType;
  lProperty: TRttiProperty;
  lObject: TNXCacheFixture;
begin
  lFirst := TRttiContext.Create(True);
  lSecond := TRttiContext.Create(True);
  lFull := TRttiContext.Create(False);
  lObject := TNXCacheFixture.Create;
  try
    lType := lFirst.GetType(TNXCacheFixture);
    AContext.AssertTrue(lType = lSecond.GetType(TNXCacheFixture),
      'Contexts with the same visibility must share type wrappers.');
    AContext.AssertTrue(lType <> lFull.GetType(TNXCacheFixture),
      'Published-only and full RTTI must retain separate pools.');
    lProperty := lType.GetProperty('Value');
    AContext.AssertTrue(Assigned(lProperty));
    AContext.AssertTrue(lProperty = lSecond.GetType(TNXCacheFixture).GetProperty('Value'),
      'Repeated member lookup must return the cached member.');
    lProperty.SetValue(lObject, TValue.FromOrdinal(TypeInfo(Integer), 42));
    AContext.AssertEquals(42, lProperty.GetValue(lObject).AsInteger);
  finally
    lObject.Free;
    lFull.Free;
    lSecond.Free;
    lFirst.Free;
  end;
end;

procedure TestCacheRebuild(AContext: TNXTestContext);
var
  lContext: TRttiContext;
  lObject: TNXCacheFixture;
  lProperty: TRttiProperty;
begin
  lContext := TRttiContext.Create(True);
  AContext.AssertTrue(Assigned(lContext.GetType(TNXCacheFixture).GetProperty('Value')));
  lContext.Free;
  TRttiContext.DropContext;
  lContext := TRttiContext.Create(True);
  lObject := TNXCacheFixture.Create;
  try
    lProperty := lContext.GetType(TNXCacheFixture).GetProperty('Value');
    AContext.AssertTrue(Assigned(lProperty));
    lProperty.SetValue(lObject, TValue.FromOrdinal(TypeInfo(Integer), 73));
    AContext.AssertEquals(73, lProperty.GetValue(lObject).AsInteger);
  finally
    lObject.Free;
    lContext.Free;
  end;
end;

procedure RegisterNXRttiCacheTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('Rtti.Cache');
  lSuite.AddTest('IdentityAndVisibility', @TestCacheIdentity);
  lSuite.AddTest('ClearAndRebuild', @TestCacheRebuild);
end;
end.
