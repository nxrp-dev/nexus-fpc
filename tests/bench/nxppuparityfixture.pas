unit NXPPUParityFixture;

{$mode objfpc}

interface

type
  TNXParityEnum = (peZero, peOne, peTwo);
  TNXParityRecord = record
    Number: Int64;
    Name: AnsiString;
    Values: array[0..7] of Word;
  end;

const
  NXParityText = 'NexusFPC PPU parity';

function NXParityValue(AValue: LongInt): Int64;

implementation

function NXParityValue(AValue: LongInt): Int64;
begin
  Result:=Int64(AValue)*17+3;
end;

end.
