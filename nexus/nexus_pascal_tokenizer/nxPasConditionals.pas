unit nxPasConditionals;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  nxPasTokenTypes,
  nxPasDirectives,
  nxPasTokenizer;

type
  TNXConditionalProcessStatus = (
    cpsComplete,
    cpsBlocked
  );

  TNXConditionalProcessor = class
  private
    FTokenizer: TNXTokenizer;
    FState: TNXDirectiveState;
    FInput: TNXTokenBuffer;
    FOutput: TNXTokenBuilder;
    FPosition: Integer;
    FBlocked: TNXBlockInfo;
    FComplete: Boolean;

    function ProcessDirectiveToken(
      const AToken: TNXToken
    ): TNXConditionalProcessStatus;
  public
    constructor Create(
      ATokenizer: TNXTokenizer;
      ASemanticResolver: TNXSemanticDirectiveResolver = nil
    );
    destructor Destroy; override;

    procedure Define(const AName: string);
    procedure Undefine(const AName: string);
    function Continue: TNXConditionalProcessStatus;
    function Tokens: TNXTokenBuffer;

    property Blocked: TNXBlockInfo read FBlocked;
    property Complete: Boolean read FComplete;
  end;

implementation

constructor TNXConditionalProcessor.Create(
  ATokenizer: TNXTokenizer;
  ASemanticResolver: TNXSemanticDirectiveResolver
);
begin
  inherited Create;

  if ATokenizer = nil then
    raise Exception.Create('ATokenizer cannot be nil');
  if not ATokenizer.Complete then
    raise Exception.Create(
      'Conditional processing requires a complete physical token stream'
    );

  FTokenizer := ATokenizer;
  FState := TNXDirectiveState.Create;
  FState.Resolver := ASemanticResolver;
  FInput := ATokenizer.Tokens;
  FOutput := TNXTokenBuilder.Create;
end;

destructor TNXConditionalProcessor.Destroy;
begin
  FOutput.Free;
  FState.Free;
  inherited Destroy;
end;

procedure TNXConditionalProcessor.Define(const AName: string);
begin
  if FPosition <> 0 then
    raise Exception.Create('Defines cannot change after processing starts');

  FState.Define(AName);
end;

procedure TNXConditionalProcessor.Undefine(const AName: string);
begin
  if FPosition <> 0 then
    raise Exception.Create('Defines cannot change after processing starts');

  FState.Undefine(AName);
end;

function TNXConditionalProcessor.ProcessDirectiveToken(
  const AToken: TNXToken
): TNXConditionalProcessStatus;
var
  DirectiveKind: TNXDirectiveKind;
  DirectiveResult: TNXDirectiveResult;
  DirectiveText: string;
  IncludeName: string;
begin
  if AToken.Variant > Ord(High(TNXDirectiveKind)) then
    raise Exception.CreateFmt(
      'Invalid directive kind %d at line %d, column %d',
      [AToken.Variant, AToken.Line, AToken.Column]
    );

  DirectiveKind := TNXDirectiveKind(AToken.Variant);
  DirectiveText := FTokenizer.DirectiveText(AToken.Value);

  if DirectiveKind in [dkError, dkFatal] then
  begin
    if FState.IsActive then
      raise Exception.CreateFmt(
        'Selected compiler directive at line %d, column %d: %s',
        [AToken.Line, AToken.Column, DirectiveText]
      );

    Exit(cpsComplete);
  end;

  DirectiveResult := FState.Process(
    DirectiveText,
    IncludeName,
    FBlocked
  );

  if DirectiveResult = drBlocked then
    Exit(cpsBlocked);

  if (DirectiveKind in [dkUnknown, dkInclude]) and FState.IsActive then
    FOutput.Add(AToken);

  Result := cpsComplete;
end;

function TNXConditionalProcessor.Continue: TNXConditionalProcessStatus;
var
  Token: TNXToken;
begin
  if FComplete then
    Exit(cpsComplete);

  FBlocked.Clear;

  while FPosition < Length(FInput) do
  begin
    Token := FInput[FPosition];

    if Token.Kind = tkDirective then
    begin
      if ProcessDirectiveToken(Token) = cpsBlocked then
        Exit(cpsBlocked);
    end
    else if Token.Kind = tkEOF then
    begin
      if FState.ConditionalDepth <> 0 then
        raise Exception.Create('Unterminated conditional directive block');

      FOutput.Add(Token);
    end
    else if FState.IsActive then
      FOutput.Add(Token);

    Inc(FPosition);
  end;

  FComplete := True;
  Result := cpsComplete;
end;

function TNXConditionalProcessor.Tokens: TNXTokenBuffer;
begin
  if not FComplete then
    raise Exception.Create(
      'Effective token buffer is not publishable until processing completes'
    );

  Result := FOutput.ToArray;
end;

end.
