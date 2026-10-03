program AnsiCompareProbe;

{$mode objfpc}

uses
  SysUtils;

var
  First, Second: String;

begin
  First := AnsiString(AnsiChar($80));
  Second := AnsiString(AnsiChar($FF));
  if (CompareStr(First, Second) >= 0) or
     (CompareStr(Second, First) <= 0) or
     (CompareText(First, Second) >= 0) or
     SameStr(First, Second) or SameText(First, Second) then
    Halt(1);
  if (CompareStr('a', 'A') = 0) or
     (CompareText('a', 'A') <> 0) then
    Halt(2);
end.
