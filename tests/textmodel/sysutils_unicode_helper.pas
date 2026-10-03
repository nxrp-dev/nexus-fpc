program SysUtilsUnicodeHelper;

{$mode objfpc}

uses
  SysUtils;

procedure Check(Condition: Boolean; const Name: AnsiString);
begin
  if not Condition then
    begin
      WriteLn('FAIL: ', Name);
      Halt(1);
    end;
end;

var
  First, Second, Text, Quoted: UnicodeString;
  QuoteChar: UnicodeChar;
  SourceChars: array[0..1] of UnicodeChar;
  ResultChars: TUnicodeCharArray;
begin
  First:=UnicodeString(WideChar($4E2D));
  Second:=UnicodeString(WideChar($65E5));
  QuoteChar:=UnicodeChar($300C);

  Check(UnicodeString.CompareText(First,Second)<>0,'CompareText distinct characters');
  Check(UnicodeString.CompareText('A'+First,'a'+First)=0,'CompareText ignore case');
  Check(not UnicodeString.EndsText(Second,'x'+First),'EndsText distinct characters');
  Check(UnicodeString.Format(First+'=%s',[Second])=First+'='+Second,'Format preserves Unicode');

  Text:=First+'x';
  Check(not Text.Equals(Second+'X',True),'Equals distinct characters');
  Check(not Text.StartsWith(Second,True),'StartsWith distinct characters');
  Text:='x'+First;
  Check(not Text.EndsWith(Second,True),'EndsWith distinct characters');

  Text:='a'+First+'b';
  Check(Text.IsDelimiter(First,1),'IsDelimiter Unicode match');
  Check(not Text.IsDelimiter(Second,1),'IsDelimiter Unicode mismatch');
  Check(Text.LastDelimiter(First)=1,'LastDelimiter Unicode match');
  Check(Text.LastDelimiter(Second)=-1,'LastDelimiter Unicode mismatch');

  Text:=First;
  Check(Text.QuotedString=''''+First+'''','QuotedString preserves Unicode');
  Text:=First+QuoteChar+Second;
  Quoted:=Text.QuotedString(QuoteChar);
  Check(Quoted=QuoteChar+First+QuoteChar+QuoteChar+Second+QuoteChar,
    'QuotedString Unicode quote');

  SourceChars[0]:=UnicodeChar($4E2D);
  SourceChars[1]:=UnicodeChar($65E5);
  Text:=UnicodeString.Create(SourceChars);
  Check(Text=First+Second,'Create copies complete Unicode characters');
  ResultChars:=Text.ToCharArray;
  Check((Length(ResultChars)=2) and (ResultChars[0]=SourceChars[0]) and
    (ResultChars[1]=SourceChars[1]),'ToCharArray preserves Unicode characters');
end.
