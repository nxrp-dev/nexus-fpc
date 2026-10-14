unit uextendedabi;
{$mode objfpc}{$H-}
interface
type
  TExtendedRecord = record
    Before: QWord;
    Value: Extended;
    After: QWord;
  end;
  TExtendedCallback = function(AValue: Extended): Extended; cdecl;
function Mixed(AFirst: LongInt; ASecond: Double; AThird: Extended;
  AFourth: QWord; AFifth: Extended; ASixth: Single): Extended; cdecl;
function CallExtended(ACallback: TExtendedCallback; AValue: Extended): Extended; cdecl;
function RecordResult(AValue: TExtendedRecord): TExtendedRecord;
procedure UpdateExtended(var AValue: Extended; const ADelta: Extended);
implementation
function Mixed(AFirst: LongInt; ASecond: Double; AThird: Extended;
  AFourth: QWord; AFifth: Extended; ASixth: Single): Extended; cdecl;
begin
  if (AFirst<>17) or (ASecond<>2.5) or (AFourth<>QWord($FEDCBA9876543210)) or
     (ASixth<>3.25) then
    begin
      WriteLn('Mixed arguments: ',AFirst,' ',ASecond,' ',AThird,' ',
        HexStr(AFourth,16),' ',AFifth,' ',ASixth);
      Halt(31);
    end;
  Result:=AThird+AFifth;
end;
function CallExtended(ACallback: TExtendedCallback; AValue: Extended): Extended; cdecl;
begin Result:=ACallback(AValue); end;
function RecordResult(AValue: TExtendedRecord): TExtendedRecord;
begin
  Result:=AValue;
  Result.Value:=Result.Value*2;
end;
procedure UpdateExtended(var AValue: Extended; const ADelta: Extended);
begin AValue:=AValue+ADelta; end;
end.
