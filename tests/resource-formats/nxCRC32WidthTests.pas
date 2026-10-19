program NXCRC32WidthTests;

{$mode objfpc}{$H+}{$asmmode intel}

uses SysUtils, CPU, obNXTestRegistry, obNXTestContext, utNXTestConsole;
var TestContext: TNXTestContext;

function ReadByte(ASeed: Cardinal; ABuffer: PByte): Cardinal; assembler; nostackframe;
asm
  mov eax, ASeed
  crc32 eax, byte ptr [ABuffer]
end;

function ReadWord(ASeed: Cardinal; ABuffer: PByte): Cardinal; assembler; nostackframe;
asm
  mov eax, ASeed
  crc32 eax, word ptr [ABuffer]
end;

function ReadDWord(ASeed: Cardinal; ABuffer: PByte): Cardinal; assembler; nostackframe;
asm
  mov eax, ASeed
  crc32 eax, dword ptr [ABuffer]
end;

{$ifdef cpux86_64}
function ReadQWord(ASeed: Cardinal; ABuffer: PByte): Cardinal; assembler; nostackframe;
asm
  mov eax, ASeed
  crc32 rax, qword ptr [ABuffer]
end;

function ReadByte64(ASeed: Cardinal; ABuffer: PByte): Cardinal; assembler; nostackframe;
asm
  mov eax, ASeed
  crc32 rax, byte ptr [ABuffer]
end;
{$endif}

function ReferenceCRC(ASeed: Cardinal; ABuffer: PByte; ACount: Integer): Cardinal;
var lIndex, lBit: Integer;
begin
  Result := ASeed;
  for lIndex := 0 to ACount - 1 do
  begin
    Result := Result xor ABuffer[lIndex];
    for lBit := 0 to 7 do
      if Odd(Result) then Result := (Result shr 1) xor $82F63B78
      else Result := Result shr 1;
  end;
end;

var
  lData: array[0..79] of Byte;
  lOffset, lVariant, lIndex, lChecks: Integer;
  lSeed: Cardinal;

procedure Check(AActual, AExpected: Cardinal; const AWidth: string);
begin
  if AActual <> AExpected then
    TestContext.Fail(Format('CRC32 %s differs at offset %d, variant %d',
      [AWidth, lOffset, lVariant]));
  Inc(lChecks);
end;

procedure CRC32Widths(AContext: TNXTestContext);
begin
  TestContext := AContext;
  if not SSE42Support then
  begin
    AContext.Skip('CPU lacks SSE4.2; instruction encodings are checked independently');
  end;
  for lVariant := 0 to 7 do
  begin
    for lIndex := Low(lData) to High(lData) do
      lData[lIndex] := Byte((lIndex * 19 + lVariant * 37) and 255);
    lSeed := Cardinal(lVariant) * $1020304;
    for lOffset := 0 to 31 do
    begin
      Check(ReadByte(lSeed, @lData[lOffset]), ReferenceCRC(lSeed, @lData[lOffset], 1), 'byte');
      Check(ReadWord(lSeed, @lData[lOffset]), ReferenceCRC(lSeed, @lData[lOffset], 2), 'word');
      Check(ReadDWord(lSeed, @lData[lOffset]), ReferenceCRC(lSeed, @lData[lOffset], 4), 'dword');
{$ifdef cpux86_64}
      Check(ReadByte64(lSeed, @lData[lOffset]), ReferenceCRC(lSeed, @lData[lOffset], 1), 'byte/64');
      Check(ReadQWord(lSeed, @lData[lOffset]), ReferenceCRC(lSeed, @lData[lOffset], 8), 'qword');
{$endif}
    end;
  end;
  WriteLn('PASS ', lChecks, ' CRC32 source-width checks');
end;
procedure ReferenceVector(AContext: TNXTestContext);
const cText: RawByteString = '123456789';
begin
  AContext.AssertTrue((ReferenceCRC($FFFFFFFF, @cText[1], Length(cText)) xor $FFFFFFFF) = $E3069283,
    'Independent CRC32C check vector');
end;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lRegistry.AddSuite('Compiler.X86.Instructions').AddTest('CRC32CReference', @ReferenceVector, 'compiler-instructions');
    lRegistry.AddSuite('Compiler.X86.Instructions').AddTest('CRC32SourceWidths', @CRC32Widths, 'compiler-instructions');
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
