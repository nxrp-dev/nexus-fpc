{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
program VariantsByRefNegation;

{$mode objfpc}{$H+}

uses SysUtils, Variants;

var
  lManager: TVariantManager;
  lChecks: LongInt;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  Inc(lChecks);
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure TestReference(AType, AExpectedType: TVarType; ASource: Pointer;
  AExpected: Int64);
var
  lVariant: Variant;
begin
  TVarData(lVariant).VType := AType or varByRef;
  TVarData(lVariant).VPointer := ASource;
  try
    lManager.VarNeg(lVariant);
    Check(VarType(lVariant) = AExpectedType,
      'type ' + IntToStr(AType) + ': wrong result subtype');
    Check(Int64(lVariant) = AExpected,
      'type ' + IntToStr(AType) + ': expected ' + IntToStr(AExpected) +
      ', got ' + IntToStr(Int64(lVariant)));
  finally
    VarClear(lVariant);
  end;
end;

procedure Run;
const
  cSigned: array[0..4] of Int64 = (-32767, -7, 0, 7, 32767);
  cWide: array[0..4] of Int64 = (-High(Int64), -2147483647, 0,
    2147483647, High(Int64));
  cUnsigned: array[0..7] of LongWord = (0, 7, 255, 65535,
    $7FFFFFFF, $80000000, $80000001, $FFFFFFFF);
var
  lIndex: LongInt;
  lSmall: SmallInt;
  lInteger: LongInt;
  lLarge: Int64;
  lUnsigned: LongWord;
  lByte: Byte;
  lWord: Word;
  lQWord: QWord;
  lSingle: Single;
  lDouble: Double;
  lCurrency: Currency;
  lVariant: Variant;
  lExpectedType: TVarType;
begin
  GetVariantManager(lManager);
  for lIndex := Low(cSigned) to High(cSigned) do
  begin
    lSmall := cSigned[lIndex];
    TestReference(varSmallInt, varSmallInt, @lSmall, -cSigned[lIndex]);
    Check(lSmall = cSigned[lIndex], 'SmallInt source changed');
    lInteger := cSigned[lIndex];
    TestReference(varInteger, varInteger, @lInteger, -cSigned[lIndex]);
    Check(lInteger = cSigned[lIndex], 'Integer source changed');
    lSingle := cSigned[lIndex];
    TestReference(varSingle, varSingle, @lSingle, -cSigned[lIndex]);
    Check(lSingle = cSigned[lIndex], 'Single source changed');
    lDouble := cSigned[lIndex];
    TestReference(varDouble, varDouble, @lDouble, -cSigned[lIndex]);
    Check(lDouble = cSigned[lIndex], 'Double source changed');
    lCurrency := cSigned[lIndex];
    TestReference(varCurrency, varCurrency, @lCurrency, -cSigned[lIndex]);
    Check(lCurrency = cSigned[lIndex], 'Currency source changed');
    lVariant := cSigned[lIndex];
    lManager.VarNeg(lVariant);
    Check(Int64(lVariant) = -cSigned[lIndex], 'ordinary Variant negation');
  end;
  for lIndex := Low(cWide) to High(cWide) do
  begin
    lLarge := cWide[lIndex];
    TestReference(varInt64, varInt64, @lLarge, -cWide[lIndex]);
    Check(lLarge = cWide[lIndex], 'Int64 source changed');
  end;
  for lIndex := Low(cUnsigned) to High(cUnsigned) do
  begin
    lUnsigned := cUnsigned[lIndex];
    if lUnsigned <= High(LongInt) then
      lExpectedType := varInteger
    else
      lExpectedType := varInt64;
    TestReference(varLongWord, lExpectedType, @lUnsigned, -Int64(lUnsigned));
    Check(lUnsigned = cUnsigned[lIndex], 'LongWord source changed');
    lVariant := lUnsigned;
    lManager.VarNeg(lVariant);
    Check(VarType(lVariant) = lExpectedType, 'ordinary LongWord result subtype');
    Check(Int64(lVariant) = -Int64(lUnsigned), 'ordinary LongWord negation');
    lQWord := cUnsigned[lIndex];
    TestReference(varQWord, varInt64, @lQWord, -Int64(lQWord));
    Check(lQWord = cUnsigned[lIndex], 'QWord source changed');
    if cUnsigned[lIndex] <= High(Word) then
    begin
      lWord := cUnsigned[lIndex];
      TestReference(varWord, varInteger, @lWord, -Int64(lWord));
      Check(lWord = cUnsigned[lIndex], 'Word source changed');
    end;
    if cUnsigned[lIndex] <= High(Byte) then
    begin
      lByte := cUnsigned[lIndex];
      TestReference(varByte, varSmallInt, @lByte, -Int64(lByte));
      Check(lByte = cUnsigned[lIndex], 'Byte source changed');
    end;
  end;
end;

begin
  try
    Run;
    WriteLn('PASS: ', lChecks, ' Variant negation checks');
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
