program UnicodeRTLCompareProbe;

{$mode objfpc}

uses
  SysUtils, Classes;

var
  First, Second: UnicodeString;
  Failures: Integer;
  Items: TStringList;

begin
  First := UnicodeString(WideChar($0100));
  Second := UnicodeString(WideChar($0200));
  Failures := 0;

  if CompareStr(First, Second) = 0 then
    begin
      WriteLn('CompareStr treated distinct Unicode characters as equal');
      Inc(Failures);
    end;
  if CompareText(First, Second) = 0 then
    begin
      WriteLn('CompareText treated distinct Unicode characters as equal');
      Inc(Failures);
    end;
  if SameStr(First, Second) then
    begin
      WriteLn('SameStr treated distinct Unicode characters as equal');
      Inc(Failures);
    end;
  if SameText(First, Second) then
    begin
      WriteLn('SameText treated distinct Unicode characters as equal');
      Inc(Failures);
    end;
  Items := TStringList.Create;
  try
    Items.Add(First);
    Items.Add(Second);
    if Items.IndexOf(Second) <> 1 then
      begin
        WriteLn('TStringList found the wrong Unicode item');
        Inc(Failures);
      end;
  finally
    Items.Free;
  end;

  First := UnicodeString(WideChar($00FF));
  Second := UnicodeString(WideChar($0100));
  if CompareStr(First, Second) >= 0 then
    begin
      WriteLn('CompareStr did not order Unicode code units correctly');
      Inc(Failures);
    end;
  if CompareText(First, Second) >= 0 then
    begin
      WriteLn('CompareText did not order Unicode code units correctly');
      Inc(Failures);
    end;
  if CompareStr(Second, First) <= 0 then
    begin
      WriteLn('CompareStr reverse Unicode order is incorrect');
      Inc(Failures);
    end;

  First := 'a';
  Second := 'A';
  if (CompareText(First, Second) <> 0) or
     (CompareStr(First, Second) = 0) then
    begin
      WriteLn('ASCII case handling changed');
      Inc(Failures);
    end;
  if Failures <> 0 then
    Halt(Failures);
end.
