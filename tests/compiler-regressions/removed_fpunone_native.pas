{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
program RemovedFPUNoneNative;
{$mode objfpc}{$H+}
{$if defined(FPUNONE)}
  {$fatal A supported target must provide floating-point support}
{$endif}
{$if not defined(FPC_HAS_TYPE_SINGLE) or not defined(FPC_HAS_TYPE_DOUBLE)}
  {$fatal The compiler must advertise Single and Double}
{$endif}

uses SysUtils, Classes, Math, obNXTestRegistry, obNXTestContext, utNXTestConsole;
var TestContext: TNXTestContext;

const
  cHalf = 1 / 2;
  cCurrencyStorage: array[0..6] of Int64 =
    (0, 1, -1, 6250, -6250, Low(Int64), High(Int64));

procedure CheckCurrencyRoundTrip(const ARaw: Int64);
var
  lValue, lActual: Currency;
  lActualRaw: Int64;
  lStream: TMemoryStream;
  lWriter: TWriter;
  lReader: TReader;
begin
  Move(ARaw, lValue, SizeOf(lValue));
  lStream := TMemoryStream.Create;
  try
    lWriter := TWriter.Create(lStream, 256);
    try
      lWriter.WriteCurrency(lValue);
    finally
      lWriter.Free;
    end;
    lStream.Position := 0;
    lReader := TReader.Create(lStream, 256);
    try
      lActual := lReader.ReadCurrency;
    finally
      lReader.Free;
    end;
    Move(lActual, lActualRaw, SizeOf(lActualRaw));
    TestContext.AssertTrue(lActualRaw = ARaw, 'Exact Currency storage: ' + IntToStr(ARaw));
  finally
    lStream.Free;
  end;
end;

procedure MixedSequence(AContext: TNXTestContext);
var
  lSingle: Single;
  lDouble: Double;
  lExtended: Extended;
  lCurrency: Currency;
  lFormatSettings: TFormatSettings;
  lStream: TMemoryStream;
  lWriter: TWriter;
  lReader: TReader;
begin
  lSingle := cHalf;
  lDouble := lSingle + 0.75;
  lExtended := lDouble / 2;
  lCurrency := lExtended;
  AContext.AssertTrue((lSingle = 0.5) and (lDouble = 1.25) and
    (lExtended = 0.625) and (lCurrency = 0.625), 'Floating arithmetic and conversion');
  AContext.AssertTrue(Sqrt(4.0) = 2.0, 'Floating format/stream check 2');
  lFormatSettings := DefaultFormatSettings;
  lFormatSettings.DecimalSeparator := '.';
  AContext.AssertTrue(StrToFloat('1.25', lFormatSettings) = lDouble, 'Floating format/stream check 3');
  AContext.AssertTrue(FloatToStrF(lDouble, ffFixed, 15, 2, lFormatSettings) = '1.25', 'Floating format/stream check 7');
  lStream := TMemoryStream.Create;
  try
    lWriter := TWriter.Create(lStream, 256);
    try
      lWriter.WriteFloat(lExtended);
      lWriter.WriteSingle(lSingle);
      lWriter.WriteCurrency(lCurrency);
    finally
      lWriter.Free;
    end;
    lStream.Position := 0;
    lReader := TReader.Create(lStream, 256);
    try
      AContext.AssertTrue(lReader.ReadFloat = lExtended, 'Floating format/stream check 4');
      AContext.AssertTrue(lReader.ReadSingle = lSingle, 'Floating format/stream check 5');
      AContext.AssertTrue(lReader.ReadCurrency = lCurrency, 'Floating format/stream check 6');
    finally
      lReader.Free;
    end;
  finally
    lStream.Free;
  end;
end;

procedure CurrencyBounds(AContext: TNXTestContext);
var lIndex: SizeInt;
begin
  TestContext := AContext;
  try
    for lIndex := Low(cCurrencyStorage) to High(cCurrencyStorage) do
      CheckCurrencyRoundTrip(cCurrencyStorage[lIndex]);
  finally TestContext := nil; end;
end;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    with lRegistry.AddSuite('RTL.Streaming.Numeric') do
    begin
      AddTest('MixedSequence', @MixedSequence, 'rtl-streaming');
      AddTest('CurrencyBounds', @CurrencyBounds, 'rtl-streaming');
    end;
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
