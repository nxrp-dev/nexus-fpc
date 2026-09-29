unit nxPasSources;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TNXSourceProvider = class
  public
    function LoadInclude(
      const ACurrentSource: string;
      const AIncludeName: string;
      out AResolvedName: string;
      out AText: string
    ): Boolean; virtual; abstract;
  end;

  TNXSource = class
  private
    FID: LongWord;
    FName: string;
    FText: string;
    FPosition: Integer;
    FLine: LongWord;
    FColumn: LongWord;
    FFromInclude: Boolean;
  public
    constructor Create(
      AID: LongWord;
      const AName: string;
      const AText: string;
      AFromInclude: Boolean
    );

    function EOF: Boolean;
    function Current: Char;
    function Peek(AOffset: Integer = 1): Char;
    procedure Advance;

    property ID: LongWord read FID;
    property Name: string read FName;
    property Text: string read FText;
    property Position: Integer read FPosition write FPosition;
    property Line: LongWord read FLine write FLine;
    property Column: LongWord read FColumn write FColumn;
    property FromInclude: Boolean read FFromInclude;
  end;

  TNXSourceStack = class
  private
    FSources: array of TNXSource;
    FNextID: LongWord;
  public
    destructor Destroy; override;

    function Push(
      const AName: string;
      const AText: string;
      AFromInclude: Boolean
    ): TNXSource;

    procedure Pop;
    function Current: TNXSource;
    function Count: Integer;
  end;

implementation

constructor TNXSource.Create(
  AID: LongWord;
  const AName: string;
  const AText: string;
  AFromInclude: Boolean
);
begin
  inherited Create;

  FID := AID;
  FName := AName;
  FText := AText;
  FPosition := 1;
  FLine := 1;
  FColumn := 1;
  FFromInclude := AFromInclude;
end;

function TNXSource.EOF: Boolean;
begin
  Result := FPosition > Length(FText);
end;

function TNXSource.Current: Char;
begin
  if EOF then
    Result := #0
  else
    Result := FText[FPosition];
end;

function TNXSource.Peek(AOffset: Integer): Char;
var
  P: Integer;
begin
  P := FPosition + AOffset;

  if (P < 1) or (P > Length(FText)) then
    Result := #0
  else
    Result := FText[P];
end;

procedure TNXSource.Advance;
var
  C: Char;
begin
  if EOF then
    Exit;

  C := FText[FPosition];
  Inc(FPosition);

  if C = #13 then
  begin
    if (FPosition <= Length(FText)) and (FText[FPosition] = #10) then
      Inc(FPosition);

    Inc(FLine);
    FColumn := 1;
  end
  else if C = #10 then
  begin
    Inc(FLine);
    FColumn := 1;
  end
  else
    Inc(FColumn);
end;

destructor TNXSourceStack.Destroy;
begin
  while Length(FSources) > 0 do
    Pop;

  inherited Destroy;
end;

function TNXSourceStack.Push(
  const AName: string;
  const AText: string;
  AFromInclude: Boolean
): TNXSource;
var
  I: Integer;
begin
  Inc(FNextID);
  if FNextID = 0 then
    Inc(FNextID);

  Result := TNXSource.Create(
    FNextID,
    AName,
    AText,
    AFromInclude
  );

  I := Length(FSources);
  SetLength(FSources, I + 1);
  FSources[I] := Result;
end;

procedure TNXSourceStack.Pop;
var
  I: Integer;
begin
  I := High(FSources);

  if I < 0 then
    Exit;

  FSources[I].Free;
  SetLength(FSources, I);
end;

function TNXSourceStack.Current: TNXSource;
begin
  if Length(FSources) = 0 then
    Result := nil
  else
    Result := FSources[High(FSources)];
end;

function TNXSourceStack.Count: Integer;
begin
  Result := Length(FSources);
end;

end.
