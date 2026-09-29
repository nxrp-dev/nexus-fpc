unit nxPasTokenTypes;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils;

type
  TNXTokenKind = (
    tkInvalid,
    tkEOF,
    tkIdentifier,
    tkKeyword,
    tkOperator,
    tkSymbol,
    tkInteger,
    tkReal,
    tkString,
    tkChar,
    tkDirective
  );

  TNXDirectiveKind = (
    dkUnknown,
    dkIfDef,
    dkIfNDef,
    dkIf,
    dkIfOpt,
    dkElse,
    dkElseIf,
    dkEndIf,
    dkIfEnd,
    dkDefine,
    dkUndefine,
    dkInclude,
    dkError,
    dkFatal
  );

  TNXOperator = (
    opNone,
    opPlus,
    opMinus,
    opMultiply,
    opDivide,
    opEqual,
    opGreater,
    opLess,
    opGreaterEqual,
    opLessEqual,
    opNotEqual,
    opSymmetricDifference,
    opPower,
    opAssign,
    opPlusAssign,
    opMinusAssign,
    opAndAssign,
    opOrAssign,
    opMultiplyAssign,
    opDivideAssign
  );

  TNXSymbol = (
    syNone,
    syCaret,
    syLeftBracket,
    syRightBracket,
    syDot,
    syComma,
    syLeftParen,
    syRightParen,
    syColon,
    sySemicolon,
    syAt,
    syRange,
    syEllipsis,
    syPipe,
    syAmpersand,
    syHash
  );

  TNXTokenFlags = set of (
    tfEscapedIdentifier,
    tfFromInclude,
    tfSynthetic
  );

  TNXToken = record
    Kind: TNXTokenKind;
    Variant: Word;
    Value: LongWord;
    SourceID: LongWord;
    Offset: LongWord;
    Length: LongWord;
    Line: LongWord;
    Column: LongWord;
    Flags: TNXTokenFlags;
  end;

  TNXTokenBuffer = array of TNXToken;

  TNXTokenizeStatus = (
    tsComplete,
    tsBlocked
  );

  TNXBlockInfo = record
    WorkID: QWord;
    RequiredState: Integer;
    Reason: string;
    procedure Clear;
    function Assigned: Boolean;
  end;

  TNXStringPool = class
  private
    FValues: array of string;
  public
    function Add(const AValue: string): LongWord;
    function Intern(const AValue: string): LongWord;
    function Get(AIndex: LongWord): string;
    function Count: Integer;
  end;

  TNXTokenBuilder = class
  private
    FTokens: TNXTokenBuffer;
    FCount: Integer;
    procedure Grow;
  public
    procedure Clear;
    procedure Add(const AToken: TNXToken);
    function ToArray: TNXTokenBuffer;
    function Count: Integer;
  end;

implementation

procedure TNXBlockInfo.Clear;
begin
  WorkID := 0;
  RequiredState := 0;
  Reason := '';
end;

function TNXBlockInfo.Assigned: Boolean;
begin
  Result := WorkID <> 0;
end;

function TNXStringPool.Add(const AValue: string): LongWord;
var
  I: Integer;
begin
  I := Length(FValues);
  SetLength(FValues, I + 1);
  FValues[I] := AValue;
  Result := LongWord(I);
end;

function TNXStringPool.Intern(const AValue: string): LongWord;
var
  I: Integer;
begin
  { Deliberately boring for the first implementation. Replace this with the
    Nexus fixed-width/open-addressed hash table once that container exists. }
  for I := 0 to High(FValues) do
    if FValues[I] = AValue then
      Exit(LongWord(I));

  Result := Add(AValue);
end;

function TNXStringPool.Get(AIndex: LongWord): string;
begin
  if AIndex >= LongWord(Length(FValues)) then
    raise ERangeError.CreateFmt('String-pool index %d is out of range', [AIndex]);

  Result := FValues[AIndex];
end;

function TNXStringPool.Count: Integer;
begin
  Result := Length(FValues);
end;

procedure TNXTokenBuilder.Grow;
var
  NewLength: Integer;
begin
  NewLength := Length(FTokens);

  if NewLength = 0 then
    NewLength := 1024
  else
    NewLength := NewLength * 2;

  SetLength(FTokens, NewLength);
end;

procedure TNXTokenBuilder.Clear;
begin
  FCount := 0;
end;

procedure TNXTokenBuilder.Add(const AToken: TNXToken);
begin
  if FCount = Length(FTokens) then
    Grow;

  FTokens[FCount] := AToken;
  Inc(FCount);
end;

function TNXTokenBuilder.ToArray: TNXTokenBuffer;
begin
  Result := Copy(FTokens, 0, FCount);
end;

function TNXTokenBuilder.Count: Integer;
begin
  Result := FCount;
end;

end.
