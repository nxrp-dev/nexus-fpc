program NXCRC32WidthTests;

{$mode objfpc}{$H+}{$asmmode intel}

uses SysUtils, CPU;

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
    raise Exception.CreateFmt('CRC32 %s differs at offset %d, variant %d',
      [AWidth, lOffset, lVariant]);
  Inc(lChecks);
end;

begin
  if not SSE42Support then
  begin
    WriteLn('SKIP execution: CPU lacks SSE4.2; retain instruction-encoding checks');
    Halt(77);
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
end.
