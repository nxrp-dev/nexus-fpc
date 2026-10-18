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

uses SysUtils, Classes, Math;

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
    if lActualRaw <> ARaw then Halt(8);
  finally
    lStream.Free;
  end;
end;

var
  lIndex: SizeInt;
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
  if (lSingle <> 0.5) or (lDouble <> 1.25) or
     (lExtended <> 0.625) or (lCurrency <> 0.625) then Halt(1);
  if Sqrt(4.0) <> 2.0 then Halt(2);
  lFormatSettings := DefaultFormatSettings;
  lFormatSettings.DecimalSeparator := '.';
  if StrToFloat('1.25', lFormatSettings) <> lDouble then Halt(3);
  if FloatToStrF(lDouble, ffFixed, 15, 2, lFormatSettings) <> '1.25' then Halt(7);
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
      if lReader.ReadFloat <> lExtended then Halt(4);
      if lReader.ReadSingle <> lSingle then Halt(5);
      if lReader.ReadCurrency <> lCurrency then Halt(6);
    finally
      lReader.Free;
    end;
  finally
    lStream.Free;
  end;
  for lIndex := Low(cCurrencyStorage) to High(cCurrencyStorage) do
    CheckCurrencyRoundTrip(cCurrencyStorage[lIndex]);
  WriteLn('PASS: floating-point types, arithmetic, formatting and streaming');
end.
