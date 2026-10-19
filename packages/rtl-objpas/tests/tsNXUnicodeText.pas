unit tsNXUnicodeText;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterUnicodeTextTests(ARegistry: TNXTestRegistry);
implementation
uses Classes, SysUtils, StrUtils, Types, obNXTestContext;

procedure AnsiComparison(AContext: TNXTestContext);
var First, Second: AnsiString;
begin
  First := AnsiChar($80);
  Second := AnsiChar($FF);
  AContext.AssertTrue((CompareStr(First, Second) < 0) and
    (CompareStr(Second, First) > 0) and (CompareText(First, Second) < 0) and
    not SameStr(First, Second) and not SameText(First, Second), 'High-byte ANSI ordering');
  AContext.AssertTrue((CompareStr('a', 'A') <> 0) and (CompareText('a', 'A') = 0), 'ASCII case rules');
end;

procedure ExplicitSearch(AContext: TNXTestContext);
var UpperA, LowerA, B, Text: UnicodeString;
begin
  UpperA := UnicodeString(#$0100);
  LowerA := UnicodeString(#$0101);
  B := UnicodeString(#$0102);
  Text := UpperA + B;
  AContext.AssertTrue(UnicodeStartsText(LowerA, Text), 'Case-insensitive prefix');
  AContext.AssertTrue(UnicodeEndsText(B, Text), 'Case-insensitive suffix');
  AContext.AssertTrue(UnicodeContainsText(Text, LowerA), 'Case-insensitive substring');
  AContext.AssertFalse(UnicodeContainsText(Text, UnicodeString(#$0104)), 'Absent substring');
  AContext.AssertTrue(UnicodeStartsText('', Text) and UnicodeEndsText('', Text), 'Empty search');
  AContext.AssertTrue(UnicodeStartsStr(UpperA, Text), 'Exact prefix');
  AContext.AssertFalse(UnicodeStartsStr(LowerA, Text), 'Exact prefix retains case');
  AContext.AssertTrue(UnicodeEndsStr(B, Text), 'Exact suffix');
  AContext.AssertTrue(UnicodeContainsStr(Text, B), 'Exact substring');
  AContext.AssertFalse(UnicodeContainsStr(Text, LowerA), 'Exact substring retains case');
end;

procedure ExplicitTransform(AContext: TNXTestContext);
var UpperA, LowerA, B, Text: UnicodeString; Parts: TUnicodeStringDynArray;
begin
  UpperA := UnicodeString(#$0100);
  LowerA := UnicodeString(#$0101);
  B := UnicodeString(#$0102);
  Text := UpperA + B;
  AContext.AssertTrue(UnicodeReplaceText(UpperA + LowerA, LowerA, B) = B + B, 'Case-insensitive replacement');
  AContext.AssertTrue(UnicodeReplaceStr(UpperA + LowerA, LowerA, B) = UpperA + B, 'Exact replacement');
  AContext.AssertTrue(UnicodeDupeString(Text, 3) = Text + Text + Text, 'Repetition');
  AContext.AssertTrue(UnicodeDupeString(Text, 0) = '', 'Zero repetitions');
  AContext.AssertTrue(UnicodeReverseString(Text) = B + UpperA, 'Reversal');
  AContext.AssertTrue(UnicodeStuffString(Text, 2, 1, LowerA) = UpperA + LowerA, 'Splice');
  Parts := UnicodeSplitString(UpperA + B + LowerA, B);
  AContext.AssertTrue((Length(Parts) = 2) and (Parts[0] = UpperA) and (Parts[1] = LowerA), 'Unicode delimiter split');
end;

procedure LegacyUnicodeSearch(AContext: TNXTestContext);
var A, B, LowerA: UnicodeString;
begin
  A := UnicodeString(#$0100); B := UnicodeString(#$0102); LowerA := UnicodeString(#$0101);
  AContext.AssertFalse(AnsiContainsStr(B, A), 'Legacy overload distinguishes Unicode characters');
  AContext.AssertTrue(AnsiContainsStr(A + B, B), 'Legacy overload finds Unicode substring');
  AContext.AssertFalse(AnsiEndsText(A, B), 'Legacy overload distinguishes suffixes');
  AContext.AssertTrue(AnsiEndsText(LowerA, A), 'Legacy overload folds Unicode case');
end;

procedure SearchBounds(AContext: TNXTestContext);
var A, B, C, S: UnicodeString;
begin
  A := UnicodeString(#$0100); B := UnicodeString(#$0102); C := UnicodeString(#$0104);
  S := A + B + A;
  AContext.AssertEquals(0, RPosEx(UnicodeChar(#$0104), S, 3), 'Absent character');
  AContext.AssertEquals(3, RPosEx(UnicodeChar(#$0100), S, 3), 'Last position');
  AContext.AssertEquals(1, RPosEx(UnicodeChar(#$0100), S, 2), 'Search before last position');
  AContext.AssertEquals(0, RPosEx(UnicodeChar(#$0100), S, 4), 'Out-of-bounds position');
  AContext.AssertEquals(0, RPos(UnicodeChar(#$0104), S), 'Absent reverse match');
  AContext.AssertEquals(1, RPosEx(A + B, S, 3), 'Reverse substring match');
  AContext.AssertTrue(AnsiStartsStr(A, A + B) and AnsiEndsStr(B, A + B), 'Unicode overload prefix/suffix');
  AContext.AssertFalse(AnsiStartsStr(C, A + B) or AnsiEndsStr(C, A + B), 'Unicode overload absent prefix/suffix');
end;

procedure StorageAndCommands(AContext: TNXTestContext);
var A, B, S, Original, Pair: UnicodeString; Args: TUnicodeStringArray;
begin
  A := UnicodeString(#$0100); B := UnicodeString(#$0102);
  S := UnicodeString(' ') + A + B + UnicodeString(' ');
  Original := S;
  RemovePadChars(S, [' ']);
  AContext.AssertTrue(S = A + B, 'Remove padding');
  AContext.AssertTrue(Original = UnicodeString(' ') + A + B + UnicodeString(' '), 'Copy-on-write preserves alias');
  Pair := UnicodeString(#$D83D) + UnicodeString(#$DE00);
  AContext.AssertTrue(UnicodeReverseString(A + Pair + B) = B + Pair + A, 'Surrogate pair survives reversal');
  AContext.AssertTrue(UnicodeReverseString('') = '', 'Empty reversal');
  AContext.AssertTrue(SecureCompare(A + B, A + B), 'Secure equal');
  AContext.AssertFalse(SecureCompare(A, B), 'Secure unequal');
  Args := SplitCommandLine(A + UnicodeString(' ') + B);
  AContext.AssertTrue((Length(Args) = 2) and (Args[0] = A) and (Args[1] = B), 'Unicode command arguments');
end;

procedure FormatBuffers(AContext: TNXTestContext);
var Settings: TFormatSettings; FormatText, Expected, Actual: UnicodeString;
  Buffer: array[0..63] of WideChar; Count, I: Cardinal;
begin
  Settings := TFormatSettings.Invariant;
  Settings.DecimalSeparator := ',';
  FormatText := UnicodeString(#$0100) + UnicodeString('%.2f');
  Expected := UnicodeFormat(FormatText, [1.25], Settings);
  AContext.AssertTrue((Expected[1] = WideChar($0100)) and
    (Pos(UnicodeString(','), Expected) <> 0), 'Unicode format and decimal separator');
  Count := UnicodeFormatBuf(Buffer[0], Length(Buffer), FormatText[1], Length(FormatText), [1.25], Settings);
  AContext.AssertTrue(Count = Cardinal(Length(Expected)), 'Formatted buffer length');
  for I := 1 to Count do AContext.AssertTrue(Buffer[I-1] = Expected[I], 'Formatted buffer character');
  UnicodeFmtStr(Actual, FormatText, [1.25], Settings);
  AContext.AssertTrue(Actual = Expected, 'FmtStr matches Format');
  AContext.AssertEquals(0, UnicodeFormatBuf(Buffer[0], 0, FormatText[1], Length(FormatText), [1.25], Settings), 'Zero buffer capacity');
end;

procedure CopyAndReplace(AContext: TNXTestContext);
var Buffer: array[0..63] of WideChar; Actual: UnicodeString; Replacements: Integer;
begin
  Buffer[0] := 'X';
  StrPLCopy(@Buffer[0], UnicodeString(''), Length(Buffer)-1);
  AContext.AssertTrue(Buffer[0] = #0, 'Empty copy terminates');
  StrPLCopy(@Buffer[0], UnicodeString(#$0100), Length(Buffer)-1);
  AContext.AssertTrue((Buffer[0] = WideChar(#$0100)) and (Buffer[1] = #0), 'Wide copy and terminator');
  Actual := UnicodeStringReplace(UnicodeString(#$0100#$0100), UnicodeString(#$0100), UnicodeString(#$0102), [rfReplaceAll], Replacements);
  AContext.AssertTrue((Actual = UnicodeString(#$0102#$0102)) and (Replacements = 2), 'Replacement count and Unicode content');
end;

procedure HelperComparison(AContext: TNXTestContext);
var First, Second, Text: UnicodeString;
begin
  First := UnicodeString(WideChar($4E2D)); Second := UnicodeString(WideChar($65E5));
  AContext.AssertTrue(UnicodeString.CompareText(First, Second) <> 0, 'Distinct characters');
  AContext.AssertTrue(UnicodeString.CompareText('A'+First, 'a'+First) = 0, 'Ignore case');
  AContext.AssertFalse(UnicodeString.EndsText(Second, 'x'+First), 'Distinct suffix');
  AContext.AssertTrue(UnicodeString.Format(First+'=%s', [Second]) = First+'='+Second, 'Helper formatting');
  Text := First+'x';
  AContext.AssertFalse(Text.Equals(Second+'X', True), 'Distinct Equals');
  AContext.AssertFalse(Text.StartsWith(Second, True), 'Distinct StartsWith');
  Text := 'x'+First;
  AContext.AssertFalse(Text.EndsWith(Second, True), 'Distinct EndsWith');
  Text := 'a'+First+'b';
  AContext.AssertTrue(Text.IsDelimiter(First, 1), 'Unicode delimiter match');
  AContext.AssertFalse(Text.IsDelimiter(Second, 1), 'Unicode delimiter mismatch');
  AContext.AssertEquals(1, Text.LastDelimiter(First), 'Unicode last delimiter');
  AContext.AssertEquals(-1, Text.LastDelimiter(Second), 'Missing last delimiter');
end;

procedure HelperConstruction(AContext: TNXTestContext);
var First, Second, Text, Quoted: UnicodeString; QuoteChar: UnicodeChar;
  SourceChars: array[0..1] of UnicodeChar; ResultChars: TUnicodeCharArray;
begin
  First := UnicodeString(WideChar($4E2D)); Second := UnicodeString(WideChar($65E5));
  QuoteChar := UnicodeChar($300C);
  Text := First;
  AContext.AssertTrue(Text.QuotedString = ''''+First+'''', 'Quoted Unicode content');
  Text := First+QuoteChar+Second; Quoted := Text.QuotedString(QuoteChar);
  AContext.AssertTrue(Quoted = QuoteChar+First+QuoteChar+QuoteChar+Second+QuoteChar, 'Escaped Unicode quote');
  SourceChars[0] := UnicodeChar($4E2D); SourceChars[1] := UnicodeChar($65E5);
  Text := UnicodeString.Create(SourceChars);
  AContext.AssertTrue(Text = First+Second, 'Construct complete characters');
  ResultChars := Text.ToCharArray;
  AContext.AssertTrue((Length(ResultChars) = 2) and (ResultChars[0] = SourceChars[0]) and
    (ResultChars[1] = SourceChars[1]), 'Copy complete characters');
end;

procedure UnicodeDefaults(AContext: TNXTestContext);
var
  First, Second: UnicodeString;
  Items: TStringList;

begin
  {$ifndef FPC_UNICODESTRINGS}
  AContext.Skip('TEXT-001: Requires a matching Unicode-default RTL and -MUNICODESTRINGS; see tests/NXTEST-FAILURES.md');
  {$endif}
  First := UnicodeString(WideChar($0100));
  Second := UnicodeString(WideChar($0200));
  AContext.AssertTrue(CompareStr(First, Second) <> 0, 'CompareStr distinguishes Unicode characters');
  AContext.AssertTrue(CompareText(First, Second) <> 0, 'CompareText distinguishes Unicode characters');
  AContext.AssertFalse(SameStr(First, Second), 'SameStr distinguishes Unicode characters');
  AContext.AssertFalse(SameText(First, Second), 'SameText distinguishes Unicode characters');
  Items := TStringList.Create;
  try
    Items.Add(First);
    Items.Add(Second);
    AContext.AssertEquals(1, Items.IndexOf(Second), 'TStringList Unicode item identity');
  finally
    Items.Free;
  end;

  First := UnicodeString(WideChar($00FF));
  Second := UnicodeString(WideChar($0100));
  AContext.AssertTrue(CompareStr(First, Second) < 0, 'Unicode code-unit order');
  AContext.AssertTrue(CompareText(First, Second) < 0, 'Unicode case-insensitive order');
  AContext.AssertTrue(CompareStr(Second, First) > 0, 'Reverse Unicode order');

  First := 'a';
  Second := 'A';
  AContext.AssertTrue((CompareText(First, Second) = 0) and
    (CompareStr(First, Second) <> 0), 'ASCII case handling');
end;

procedure RegisterUnicodeTextTests(ARegistry: TNXTestRegistry);
begin
  ARegistry.AddSuite('RTL.Text.UnicodeDefaults').AddTest('ComparisonAndStringList', @UnicodeDefaults, 'rtl-text-defaults');
  ARegistry.AddSuite('RTL.Text.Comparison').AddTest('AnsiHighBytes', @AnsiComparison, 'rtl-text-comparison');
  with ARegistry.AddSuite('RTL.Text.UnicodeStrings') do
  begin
    AddTest('ExplicitSearch', @ExplicitSearch, 'rtl-text-search');
    AddTest('ExplicitTransform', @ExplicitTransform, 'rtl-text-transform');
    AddTest('LegacyUnicodeSearch', @LegacyUnicodeSearch, 'rtl-text-search');
    AddTest('SearchBounds', @SearchBounds, 'rtl-text-search');
    AddTest('StorageAndCommands', @StorageAndCommands, 'rtl-text-storage');
  end;
  with ARegistry.AddSuite('RTL.Text.UnicodeFormatting') do
  begin
    AddTest('FormatBuffers', @FormatBuffers, 'rtl-text-formatting');
    AddTest('CopyAndReplace', @CopyAndReplace, 'rtl-text-buffers');
  end;
  with ARegistry.AddSuite('RTL.Text.UnicodeHelpers') do
  begin
    AddTest('Comparison', @HelperComparison, 'rtl-text-helpers');
    AddTest('Construction', @HelperConstruction, 'rtl-text-helpers');
  end;
end;
end.
