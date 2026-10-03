program SysUtilsUnicodeCore;

{$mode objfpc}

uses
  SysUtils;

var
  Settings: TFormatSettings;
  FormatText, Expected, Actual: UnicodeString;
  Buffer: array[0..63] of WideChar;
  Count, I: Cardinal;
  Replacements: Integer;

begin
  Settings := TFormatSettings.Invariant;
  Settings.DecimalSeparator := ',';
  FormatText := UnicodeString(#$0100) + UnicodeString('%.2f');
  Expected := UnicodeFormat(FormatText, [1.25], Settings);
  if (Expected[1] <> WideChar($0100)) or
     (Pos(UnicodeString(','), Expected) = 0) then Halt(1);

  Count := UnicodeFormatBuf(Buffer[0], Length(Buffer), FormatText[1],
    Length(FormatText), [1.25], Settings);
  if Count <> Cardinal(Length(Expected)) then Halt(2);
  for I := 1 to Count do
    if Buffer[I-1] <> Expected[I] then Halt(3);

  UnicodeFmtStr(Actual, FormatText, [1.25], Settings);
  if Actual <> Expected then Halt(4);
  if UnicodeFormatBuf(Buffer[0], 0, FormatText[1], Length(FormatText),
    [1.25], Settings) <> 0 then Halt(5);

  Buffer[0] := 'X';
  StrPLCopy(@Buffer[0], UnicodeString(''), Length(Buffer)-1);
  if Buffer[0] <> #0 then Halt(6);
  StrPLCopy(@Buffer[0], UnicodeString(#$0100), Length(Buffer)-1);
  if (Buffer[0] <> WideChar(#$0100)) or (Buffer[1] <> #0) then Halt(7);

  Actual := UnicodeStringReplace(UnicodeString(#$0100#$0100),
    UnicodeString(#$0100), UnicodeString(#$0102), [rfReplaceAll],
    Replacements);
  if (Actual <> UnicodeString(#$0102#$0102)) or (Replacements <> 2) then
    Halt(8);
end.
