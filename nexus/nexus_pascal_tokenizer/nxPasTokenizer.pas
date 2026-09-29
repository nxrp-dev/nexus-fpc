unit nxPasTokenizer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  nxPasTokenTypes,
  nxPasKeywords,
  nxPasSources,
  nxPasDirectives;

type
  TNXTokenizer = class
  private
    FSources: TNXSourceStack;
    FKeywordPolicy: TNXKeywordPolicy;
    FOwnKeywordPolicy: Boolean;

    FTokens: TNXTokenBuilder;
    FIdentifiers: TNXStringPool;
    FLiterals: TNXStringPool;
    FDirectiveTexts: TNXStringPool;

    FBlocked: TNXBlockInfo;
    FStarted: Boolean;
    FComplete: Boolean;

    function Source: TNXSource;
    function Current: Char;
    function Peek(AOffset: Integer = 1): Char;
    procedure Advance;

    function IsIdentifierStart(C: Char): Boolean;
    function IsIdentifierChar(C: Char): Boolean;
    function IsDigitForBase(C: Char; ABase: Integer): Boolean;

    procedure AddToken(
      AKind: TNXTokenKind;
      AVariant: Word;
      AValue: LongWord;
      ASource: TNXSource;
      AOffset: LongWord;
      ALength: LongWord;
      ALine: LongWord;
      AColumn: LongWord;
      AFlags: TNXTokenFlags
    );

    procedure SkipLineComment;
    procedure SkipBraceComment;
    procedure SkipParenStarComment;
    function ReadDirectiveBrace: string;
    function ReadDirectiveParenStar: string;
    procedure AddDirectiveToken(
      const ADirective: string;
      ASource: TNXSource;
      AOffset: LongWord;
      ALength: LongWord;
      ALine: LongWord;
      AColumn: LongWord
    );

    procedure ReadIdentifier;
    procedure ReadNumber;
    procedure ReadQuotedString;
    procedure ReadCharCode;
    procedure ReadOperatorOrSymbol;

    function ContinueTokenizing: TNXTokenizeStatus;
  public
    constructor Create(AKeywordPolicy: TNXKeywordPolicy = nil);
    destructor Destroy; override;

    procedure Start(
      const ASourceName: string;
      const ASourceText: string
    );

    function Continue: TNXTokenizeStatus;

    function Tokens: TNXTokenBuffer;
    function IdentifierText(AID: LongWord): string;
    function LiteralText(AID: LongWord): string;
    function DirectiveText(AID: LongWord): string;
    function IdentifierCount: Integer;
    function LiteralCount: Integer;
    function DirectiveTextCount: Integer;

    property Blocked: TNXBlockInfo read FBlocked;
    property Complete: Boolean read FComplete;
  end;

implementation

constructor TNXTokenizer.Create(AKeywordPolicy: TNXKeywordPolicy);
begin
  inherited Create;

  FSources := TNXSourceStack.Create;
  FTokens := TNXTokenBuilder.Create;
  FIdentifiers := TNXStringPool.Create;
  FLiterals := TNXStringPool.Create;
  FDirectiveTexts := TNXStringPool.Create;

  if AKeywordPolicy = nil then
  begin
    FKeywordPolicy := TNXKeywordPolicy.Create;
    FOwnKeywordPolicy := True;
  end
  else
    FKeywordPolicy := AKeywordPolicy;
end;

destructor TNXTokenizer.Destroy;
begin
  if FOwnKeywordPolicy then
    FKeywordPolicy.Free;

  FDirectiveTexts.Free;
  FLiterals.Free;
  FIdentifiers.Free;
  FTokens.Free;
  FSources.Free;

  inherited Destroy;
end;

procedure TNXTokenizer.Start(
  const ASourceName: string;
  const ASourceText: string
);
begin
  if FStarted then
    raise Exception.Create('Tokenizer instances are single-use');

  FSources.Push(
    ASourceName,
    ASourceText,
    False
  );

  FBlocked.Clear;
  FStarted := True;
  FComplete := False;
end;

function TNXTokenizer.Source: TNXSource;
begin
  Result := FSources.Current;
end;

function TNXTokenizer.Current: Char;
begin
  if Source = nil then
    Result := #0
  else
    Result := Source.Current;
end;

function TNXTokenizer.Peek(AOffset: Integer): Char;
begin
  if Source = nil then
    Result := #0
  else
    Result := Source.Peek(AOffset);
end;

procedure TNXTokenizer.Advance;
begin
  if Source <> nil then
    Source.Advance;
end;

function TNXTokenizer.IsIdentifierStart(C: Char): Boolean;
begin
  Result :=
    (C = '_') or
    (C in ['A'..'Z', 'a'..'z']) or
    (Ord(C) >= 128);
end;

function TNXTokenizer.IsIdentifierChar(C: Char): Boolean;
begin
  Result := IsIdentifierStart(C) or (C in ['0'..'9']);
end;

function TNXTokenizer.IsDigitForBase(C: Char; ABase: Integer): Boolean;
begin
  case ABase of
    2:
      Result := C in ['0', '1'];

    8:
      Result := C in ['0'..'7'];

    10:
      Result := C in ['0'..'9'];

    16:
      Result := C in ['0'..'9', 'A'..'F', 'a'..'f'];
  else
    Result := False;
  end;
end;

procedure TNXTokenizer.AddToken(
  AKind: TNXTokenKind;
  AVariant: Word;
  AValue: LongWord;
  ASource: TNXSource;
  AOffset: LongWord;
  ALength: LongWord;
  ALine: LongWord;
  AColumn: LongWord;
  AFlags: TNXTokenFlags
);
var
  Token: TNXToken;
begin
  FillChar(Token, SizeOf(Token), 0);

  Token.Kind := AKind;
  Token.Variant := AVariant;
  Token.Value := AValue;
  Token.SourceID := ASource.ID;
  Token.Offset := AOffset;
  Token.Length := ALength;
  Token.Line := ALine;
  Token.Column := AColumn;
  Token.Flags := AFlags;

  if ASource.FromInclude then
    Include(Token.Flags, tfFromInclude);

  FTokens.Add(Token);
end;

procedure TNXTokenizer.SkipLineComment;
begin
  Advance;
  Advance;

  while (Current <> #0) and
        not (Current in [#10, #13]) do
    Advance;
end;

procedure TNXTokenizer.SkipBraceComment;
var
  Depth: Integer;
begin
  Depth := 1;
  Advance;

  while (Source <> nil) and (Depth > 0) do
  begin
    if Current = #0 then
      raise Exception.CreateFmt(
        'Unterminated comment in %s',
        [Source.Name]
      );

    if Current = '{' then
      Inc(Depth)
    else if Current = '}' then
      Dec(Depth);

    Advance;
  end;
end;

procedure TNXTokenizer.SkipParenStarComment;
var
  Depth: Integer;
begin
  Depth := 1;
  Advance;
  Advance;

  while (Source <> nil) and (Depth > 0) do
  begin
    if Current = #0 then
      raise Exception.CreateFmt(
        'Unterminated comment in %s',
        [Source.Name]
      );

    if (Current = '(') and (Peek = '*') then
    begin
      Inc(Depth);
      Advance;
      Advance;
    end
    else if (Current = '*') and (Peek = ')') then
    begin
      Dec(Depth);
      Advance;
      Advance;
    end
    else
      Advance;
  end;
end;

function TNXTokenizer.ReadDirectiveBrace: string;
begin
  Result := '';

  Advance;
  if Current <> '$' then
    raise Exception.Create('Internal directive parser mismatch');

  Advance;

  while (Current <> #0) and (Current <> '}') do
  begin
    Result := Result + Current;
    Advance;
  end;

  if Current <> '}' then
    raise Exception.CreateFmt(
      'Unterminated compiler directive in %s',
      [Source.Name]
    );

  Advance;
end;

function TNXTokenizer.ReadDirectiveParenStar: string;
begin
  Result := '';

  Advance;
  Advance;

  if Current <> '$' then
    raise Exception.Create('Internal directive parser mismatch');

  Advance;

  while (Current <> #0) and
        not ((Current = '*') and (Peek = ')')) do
  begin
    Result := Result + Current;
    Advance;
  end;

  if Current = #0 then
    raise Exception.CreateFmt(
      'Unterminated compiler directive in %s',
      [Source.Name]
    );

  Advance;
  Advance;
end;

procedure TNXTokenizer.AddDirectiveToken(
  const ADirective: string;
  ASource: TNXSource;
  AOffset: LongWord;
  ALength: LongWord;
  ALine: LongWord;
  AColumn: LongWord
);
var
  DirectiveKind: TNXDirectiveKind;
begin
  DirectiveKind := ClassifyDirective(ADirective);
  AddToken(
    tkDirective,
    Ord(DirectiveKind),
    FDirectiveTexts.Add(Trim(ADirective)),
    ASource,
    AOffset,
    ALength,
    ALine,
    AColumn,
    []
  );
end;

procedure TNXTokenizer.ReadIdentifier;
var
  S: TNXSource;
  StartPosition: Integer;
  StartLine, StartColumn: LongWord;
  Text, Canonical: string;
  Info: TNXKeywordInfo;
  Value: LongWord;
  Flags: TNXTokenFlags;
  Escaped: Boolean;
begin
  S := Source;
  StartPosition := S.Position;
  StartLine := S.Line;
  StartColumn := S.Column;
  Flags := [];
  Escaped := False;

  if Current = '&' then
  begin
    Escaped := True;
    Include(Flags, tfEscapedIdentifier);
    Advance;
  end;

  Text := '';

  while IsIdentifierChar(Current) do
  begin
    Text := Text + Current;
    Advance;
  end;

  if Text = '' then
    raise Exception.CreateFmt(
      'Expected identifier at %s:%d:%d',
      [S.Name, StartLine, StartColumn]
    );

  Canonical := UpperCase(Text);
  Value := FIdentifiers.Intern(Canonical);

  if FindKeyword(Canonical, Info) then
  begin
    if (not Escaped) and FKeywordPolicy.IsKeyword(Info) then
      AddToken(
        tkKeyword,
        Info.ID,
        Value,
        S,
        StartPosition,
        S.Position - StartPosition,
        StartLine,
        StartColumn,
        Flags
      )
    else
      AddToken(
        tkIdentifier,
        Info.ID,
        Value,
        S,
        StartPosition,
        S.Position - StartPosition,
        StartLine,
        StartColumn,
        Flags
      );
  end
  else
    AddToken(
      tkIdentifier,
      0,
      Value,
      S,
      StartPosition,
      S.Position - StartPosition,
      StartLine,
      StartColumn,
      Flags
    );
end;

procedure TNXTokenizer.ReadNumber;
var
  S: TNXSource;
  StartPosition: Integer;
  StartLine, StartColumn: LongWord;
  Base: Integer;
  IsReal: Boolean;
  Text: string;
  Kind: TNXTokenKind;
begin
  S := Source;
  StartPosition := S.Position;
  StartLine := S.Line;
  StartColumn := S.Column;
  Text := '';
  IsReal := False;
  Base := 10;

  case Current of
    '$':
      begin
        Base := 16;
        Text := Text + Current;
        Advance;
      end;

    '%':
      begin
        Base := 2;
        Text := Text + Current;
        Advance;
      end;

    '&':
      begin
        Base := 8;
        Text := Text + Current;
        Advance;
      end;
  end;

  while IsDigitForBase(Current, Base) or (Current = '_') do
  begin
    if Current <> '_' then
      Text := Text + Current;

    Advance;
  end;

  if Base = 10 then
  begin
    if (Current = '.') and (Peek <> '.') then
    begin
      IsReal := True;
      Text := Text + '.';
      Advance;

      while (Current in ['0'..'9']) or (Current = '_') do
      begin
        if Current <> '_' then
          Text := Text + Current;

        Advance;
      end;
    end;

    if Current in ['E', 'e'] then
    begin
      IsReal := True;
      Text := Text + 'E';
      Advance;

      if Current in ['+', '-'] then
      begin
        Text := Text + Current;
        Advance;
      end;

      if not (Current in ['0'..'9']) then
        raise Exception.CreateFmt(
          'Malformed real literal at %s:%d:%d',
          [S.Name, StartLine, StartColumn]
        );

      while (Current in ['0'..'9']) or (Current = '_') do
      begin
        if Current <> '_' then
          Text := Text + Current;

        Advance;
      end;
    end;
  end;

  if IsReal then
    Kind := tkReal
  else
    Kind := tkInteger;

  AddToken(
    Kind,
    Base,
    FLiterals.Add(Text),
    S,
    StartPosition,
    S.Position - StartPosition,
    StartLine,
    StartColumn,
    []
  );
end;

procedure TNXTokenizer.ReadQuotedString;
var
  S: TNXSource;
  StartPosition: Integer;
  StartLine, StartColumn: LongWord;
  Value: string;
  Done: Boolean;
begin
  S := Source;
  StartPosition := S.Position;
  StartLine := S.Line;
  StartColumn := S.Column;
  Value := '';
  Done := False;

  Advance;

  while not Done do
  begin
    if Current = #0 then
      raise Exception.CreateFmt(
        'Unterminated string at %s:%d:%d',
        [S.Name, StartLine, StartColumn]
      );

    if Current in [#10, #13] then
      raise Exception.CreateFmt(
        'Line break in quoted string at %s:%d:%d',
        [S.Name, StartLine, StartColumn]
      );

    if Current = #39 then
    begin
      if Peek = #39 then
      begin
        Value := Value + #39;
        Advance;
        Advance;
      end
      else
      begin
        Advance;
        Done := True;
      end;
    end
    else
    begin
      Value := Value + Current;
      Advance;
    end;
  end;

  AddToken(
    tkString,
    0,
    FLiterals.Add(Value),
    S,
    StartPosition,
    S.Position - StartPosition,
    StartLine,
    StartColumn,
    []
  );
end;

procedure TNXTokenizer.ReadCharCode;
var
  S: TNXSource;
  StartPosition: Integer;
  StartLine, StartColumn: LongWord;
  Text: string;
  Base: Integer;
begin
  S := Source;
  StartPosition := S.Position;
  StartLine := S.Line;
  StartColumn := S.Column;
  Text := '';
  Base := 10;

  Advance;

  if Current = '$' then
  begin
    Base := 16;
    Text := '$';
    Advance;
  end;

  if Current = '&' then
  begin
    Base := 8;
    Text := '&';
    Advance;
  end;

  if not IsDigitForBase(Current, Base) then
    raise Exception.CreateFmt(
      'Malformed character code at %s:%d:%d',
      [S.Name, StartLine, StartColumn]
    );

  while IsDigitForBase(Current, Base) do
  begin
    Text := Text + Current;
    Advance;
  end;

  AddToken(
    tkChar,
    Base,
    FLiterals.Add(Text),
    S,
    StartPosition,
    S.Position - StartPosition,
    StartLine,
    StartColumn,
    []
  );
end;

procedure TNXTokenizer.ReadOperatorOrSymbol;
var
  S: TNXSource;
  StartPosition: Integer;
  StartLine, StartColumn: LongWord;
  Kind: TNXTokenKind;
  Variant: Word;
  Length: LongWord;
begin
  S := Source;
  StartPosition := S.Position;
  StartLine := S.Line;
  StartColumn := S.Column;
  Kind := tkInvalid;
  Variant := 0;
  Length := 1;

  case Current of
    '+':
      begin
        Kind := tkOperator;
        if Peek = '=' then
        begin
          Variant := Ord(opPlusAssign);
          Length := 2;
        end
        else
          Variant := Ord(opPlus);
      end;

    '-':
      begin
        Kind := tkOperator;
        if Peek = '=' then
        begin
          Variant := Ord(opMinusAssign);
          Length := 2;
        end
        else
          Variant := Ord(opMinus);
      end;

    '*':
      begin
        Kind := tkOperator;
        if Peek = '*' then
        begin
          Variant := Ord(opPower);
          Length := 2;
        end
        else if Peek = '=' then
        begin
          Variant := Ord(opMultiplyAssign);
          Length := 2;
        end
        else
          Variant := Ord(opMultiply);
      end;

    '/':
      begin
        Kind := tkOperator;
        if Peek = '=' then
        begin
          Variant := Ord(opDivideAssign);
          Length := 2;
        end
        else
          Variant := Ord(opDivide);
      end;

    '=':
      begin
        Kind := tkOperator;
        Variant := Ord(opEqual);
      end;

    '>':
      begin
        Kind := tkOperator;

        if Peek = '=' then
        begin
          Variant := Ord(opGreaterEqual);
          Length := 2;
        end
        else if Peek = '<' then
        begin
          Variant := Ord(opSymmetricDifference);
          Length := 2;
        end
        else
          Variant := Ord(opGreater);
      end;

    '<':
      begin
        Kind := tkOperator;

        if Peek = '=' then
        begin
          Variant := Ord(opLessEqual);
          Length := 2;
        end
        else if Peek = '>' then
        begin
          Variant := Ord(opNotEqual);
          Length := 2;
        end
        else
          Variant := Ord(opLess);
      end;

    ':':
      begin
        if Peek = '=' then
        begin
          Kind := tkOperator;
          Variant := Ord(opAssign);
          Length := 2;
        end
        else
        begin
          Kind := tkSymbol;
          Variant := Ord(syColon);
        end;
      end;

    '^':
      begin
        Kind := tkSymbol;
        Variant := Ord(syCaret);
      end;

    '[':
      begin
        Kind := tkSymbol;
        Variant := Ord(syLeftBracket);
      end;

    ']':
      begin
        Kind := tkSymbol;
        Variant := Ord(syRightBracket);
      end;

    '.':
      begin
        Kind := tkSymbol;

        if Peek = '.' then
        begin
          if S.Peek(2) = '.' then
          begin
            Variant := Ord(syEllipsis);
            Length := 3;
          end
          else
          begin
            Variant := Ord(syRange);
            Length := 2;
          end;
        end
        else
          Variant := Ord(syDot);
      end;

    ',':
      begin
        Kind := tkSymbol;
        Variant := Ord(syComma);
      end;

    '(':
      begin
        Kind := tkSymbol;
        Variant := Ord(syLeftParen);
      end;

    ')':
      begin
        Kind := tkSymbol;
        Variant := Ord(syRightParen);
      end;

    ';':
      begin
        Kind := tkSymbol;
        Variant := Ord(sySemicolon);
      end;

    '@':
      begin
        Kind := tkSymbol;
        Variant := Ord(syAt);
      end;

    '|':
      begin
        Kind := tkSymbol;
        Variant := Ord(syPipe);
      end;

    '&':
      begin
        Kind := tkSymbol;
        Variant := Ord(syAmpersand);
      end;

    '#':
      begin
        Kind := tkSymbol;
        Variant := Ord(syHash);
      end;
  end;

  if Kind = tkInvalid then
    raise Exception.CreateFmt(
      'Illegal character "%s" at %s:%d:%d',
      [Current, S.Name, StartLine, StartColumn]
    );

  while Length > 0 do
  begin
    Advance;
    Dec(Length);
  end;

  AddToken(
    Kind,
    Variant,
    0,
    S,
    StartPosition,
    S.Position - StartPosition,
    StartLine,
    StartColumn,
    []
  );
end;

function TNXTokenizer.ContinueTokenizing: TNXTokenizeStatus;
var
  Directive: string;
  DirectiveSource: TNXSource;
  DirectiveOffset: LongWord;
  DirectiveLine: LongWord;
  DirectiveColumn: LongWord;
begin
  if not FStarted then
    raise Exception.Create('Tokenizer has not been started');

  if FComplete then
    Exit(tsComplete);

  FBlocked.Clear;

  while Source <> nil do
  begin
    if Current = #0 then
    begin
      FSources.Pop;
    end
    else if Current in [' ', #9, #10, #13, #12] then
    begin
      Advance;
    end
    else if (Current = '/') and (Peek = '/') then
      SkipLineComment
    else if Current = '{' then
    begin
      if Peek = '$' then
      begin
        DirectiveSource := Source;
        DirectiveOffset := DirectiveSource.Position;
        DirectiveLine := DirectiveSource.Line;
        DirectiveColumn := DirectiveSource.Column;
        Directive := ReadDirectiveBrace;
        AddDirectiveToken(
          Directive,
          DirectiveSource,
          DirectiveOffset,
          DirectiveSource.Position - DirectiveOffset,
          DirectiveLine,
          DirectiveColumn
        );
      end
      else
        SkipBraceComment;
    end
    else if (Current = '(') and (Peek = '*') then
    begin
      if Source.Peek(2) = '$' then
      begin
        DirectiveSource := Source;
        DirectiveOffset := DirectiveSource.Position;
        DirectiveLine := DirectiveSource.Line;
        DirectiveColumn := DirectiveSource.Column;
        Directive := ReadDirectiveParenStar;
        AddDirectiveToken(
          Directive,
          DirectiveSource,
          DirectiveOffset,
          DirectiveSource.Position - DirectiveOffset,
          DirectiveLine,
          DirectiveColumn
        );
      end
      else
        SkipParenStarComment;
    end
    else if Current = #39 then
      ReadQuotedString
    else if Current = '#' then
    begin
      if Peek in ['0'..'9', '$', '&'] then
        ReadCharCode
      else
        ReadOperatorOrSymbol;
    end
    else if Current in ['0'..'9', '$', '%'] then
      ReadNumber
    else if Current = '&' then
    begin
      if Peek in ['0'..'7'] then
        ReadNumber
      else if IsIdentifierStart(Peek) then
        ReadIdentifier
      else
        ReadOperatorOrSymbol;
    end
    else if IsIdentifierStart(Current) then
      ReadIdentifier
    else
      ReadOperatorOrSymbol;
  end;

  FComplete := True;
  Result := tsComplete;
end;

function TNXTokenizer.Continue: TNXTokenizeStatus;
begin
  Result := ContinueTokenizing;
end;

function TNXTokenizer.Tokens: TNXTokenBuffer;
var
  Token: TNXToken;
  N: Integer;
begin
  if not FComplete then
    raise Exception.Create(
      'Token buffer is not publishable until tokenization completes'
    );

  Result := FTokens.ToArray;
  FillChar(Token, SizeOf(Token), 0);
  Token.Kind := tkEOF;

  N := Length(Result);
  SetLength(Result, N + 1);
  Result[N] := Token;
end;

function TNXTokenizer.IdentifierText(AID: LongWord): string;
begin
  Result := FIdentifiers.Get(AID);
end;

function TNXTokenizer.LiteralText(AID: LongWord): string;
begin
  Result := FLiterals.Get(AID);
end;

function TNXTokenizer.DirectiveText(AID: LongWord): string;
begin
  Result := FDirectiveTexts.Get(AID);
end;

function TNXTokenizer.IdentifierCount: Integer;
begin
  Result := FIdentifiers.Count;
end;

function TNXTokenizer.LiteralCount: Integer;
begin
  Result := FLiterals.Count;
end;

function TNXTokenizer.DirectiveTextCount: Integer;
begin
  Result := FDirectiveTexts.Count;
end;

end.
