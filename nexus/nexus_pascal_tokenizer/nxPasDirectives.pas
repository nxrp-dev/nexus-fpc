unit nxPasDirectives;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  nxPasTokenTypes;

type
  TNXDirectiveResult = (
    drHandled,
    drInclude,
    drBlocked
  );

  TNXSemanticDirectiveResolver = class
  public
    function EvaluateConditional(
      const AExpression: string;
      out AValue: Boolean;
      out ABlocker: TNXBlockInfo
    ): Boolean; virtual;
  end;

  TNXUnknownDirectiveMethod = procedure(
    const AName: string;
    const AArgument: string
  ) of object;

  TNXConditionalFrame = record
    ParentActive: Boolean;
    BranchActive: Boolean;
    BranchTaken: Boolean;
  end;

  TNXDirectiveState = class
  private
    FDefines: array of string;
    FConditionals: array of TNXConditionalFrame;
    FResolver: TNXSemanticDirectiveResolver;
    FOnUnknownDirective: TNXUnknownDirectiveMethod;

    function NormalizeName(const AName: string): string;
    function FindDefine(const AName: string): Integer;
    function CurrentParentActive: Boolean;
    procedure PushConditional(ACondition: Boolean);
    procedure ElseConditional;
    procedure ElseIfConditional(ACondition: Boolean);
    procedure PopConditional;

    function TryEvaluateLocalConditional(
      const AExpression: string;
      out AValue: Boolean
    ): Boolean;
  public
    constructor Create;
    function Clone: TNXDirectiveState;

    procedure Define(const AName: string);
    procedure Undefine(const AName: string);
    function IsDefined(const AName: string): Boolean;
    function IsActive: Boolean;
    function ConditionalDepth: Integer;

    function Process(
      const ADirective: string;
      out AIncludeName: string;
      out ABlocker: TNXBlockInfo
    ): TNXDirectiveResult;

    property Resolver: TNXSemanticDirectiveResolver
      read FResolver write FResolver;
    property OnUnknownDirective: TNXUnknownDirectiveMethod
      read FOnUnknownDirective write FOnUnknownDirective;
  end;

function ClassifyDirective(const ADirective: string): TNXDirectiveKind;
function DirectiveArgument(const ADirective: string): string;

implementation

procedure SplitDirective(
  const ADirective: string;
  out AName: string;
  out AArgument: string
);
var
  I: Integer;
  Text: string;
begin
  Text := Trim(ADirective);
  if (Text <> '') and (Text[1] = '$') then
    Delete(Text, 1, 1);

  Text := Trim(Text);
  I := 1;
  while (I <= Length(Text)) and not (Text[I] in [' ', #9, #10, #13]) do
    Inc(I);

  AName := UpperCase(Copy(Text, 1, I - 1));
  AArgument := Trim(Copy(Text, I, MaxInt));
end;

function ClassifyDirective(const ADirective: string): TNXDirectiveKind;
var
  Argument: string;
  Name: string;
begin
  SplitDirective(ADirective, Name, Argument);

  if Name = 'IFDEF' then
    Result := dkIfDef
  else if Name = 'IFNDEF' then
    Result := dkIfNDef
  else if Name = 'IF' then
    Result := dkIf
  else if Name = 'IFOPT' then
    Result := dkIfOpt
  else if Name = 'ELSE' then
    Result := dkElse
  else if (Name = 'ELSEIF') or (Name = 'ELIF') then
    Result := dkElseIf
  else if Name = 'ENDIF' then
    Result := dkEndIf
  else if Name = 'IFEND' then
    Result := dkIfEnd
  else if Name = 'DEFINE' then
    Result := dkDefine
  else if Name = 'UNDEF' then
    Result := dkUndefine
  else if (Name = 'I') or (Name = 'INCLUDE') then
    Result := dkInclude
  else if Name = 'ERROR' then
    Result := dkError
  else if Name = 'FATAL' then
    Result := dkFatal
  else
    Result := dkUnknown;
end;

function DirectiveArgument(const ADirective: string): string;
var
  Name: string;
begin
  SplitDirective(ADirective, Name, Result);
end;

function StripOuterParens(const S: string): string;
var
  T: string;
begin
  T := Trim(S);

  if (Length(T) >= 2) and (T[1] = '(') and (T[Length(T)] = ')') then
    Result := Trim(Copy(T, 2, Length(T) - 2))
  else
    Result := T;
end;

function ExtractCallArgument(
  const AExpression: string;
  const AName: string;
  out AArgument: string
): Boolean;
var
  T, Prefix: string;
begin
  T := Trim(AExpression);
  Prefix := UpperCase(AName) + '(';

  if Copy(UpperCase(T), 1, Length(Prefix)) <> Prefix then
    Exit(False);

  if (Length(T) < Length(Prefix) + 1) or
     (T[Length(T)] <> ')') then
    Exit(False);

  AArgument := Trim(Copy(
    T,
    Length(Prefix) + 1,
    Length(T) - Length(Prefix) - 1
  ));

  Result := AArgument <> '';
end;

function TNXSemanticDirectiveResolver.EvaluateConditional(
  const AExpression: string;
  out AValue: Boolean;
  out ABlocker: TNXBlockInfo
): Boolean;
begin
  AValue := False;
  ABlocker.Clear;
  Result := False;
end;

constructor TNXDirectiveState.Create;
begin
  inherited Create;
end;

function TNXDirectiveState.Clone: TNXDirectiveState;
begin
  Result := TNXDirectiveState.Create;
  Result.FDefines := Copy(FDefines, 0, Length(FDefines));
  Result.FConditionals := Copy(FConditionals, 0, Length(FConditionals));
  Result.FResolver := FResolver;
  Result.FOnUnknownDirective := FOnUnknownDirective;
end;

function TNXDirectiveState.NormalizeName(const AName: string): string;
begin
  Result := UpperCase(Trim(AName));
end;

function TNXDirectiveState.FindDefine(const AName: string): Integer;
var
  I: Integer;
  Name: string;
begin
  Name := NormalizeName(AName);

  for I := 0 to High(FDefines) do
    if FDefines[I] = Name then
      Exit(I);

  Result := -1;
end;

procedure TNXDirectiveState.Define(const AName: string);
var
  I: Integer;
begin
  if FindDefine(AName) >= 0 then
    Exit;

  I := Length(FDefines);
  SetLength(FDefines, I + 1);
  FDefines[I] := NormalizeName(AName);
end;

procedure TNXDirectiveState.Undefine(const AName: string);
var
  I, J: Integer;
begin
  I := FindDefine(AName);

  if I < 0 then
    Exit;

  for J := I to High(FDefines) - 1 do
    FDefines[J] := FDefines[J + 1];

  SetLength(FDefines, Length(FDefines) - 1);
end;

function TNXDirectiveState.IsDefined(const AName: string): Boolean;
begin
  Result := FindDefine(AName) >= 0;
end;

function TNXDirectiveState.CurrentParentActive: Boolean;
begin
  if Length(FConditionals) = 0 then
    Result := True
  else
    Result := FConditionals[High(FConditionals)].ParentActive and
      FConditionals[High(FConditionals)].BranchActive;
end;

function TNXDirectiveState.IsActive: Boolean;
begin
  Result := CurrentParentActive;
end;

procedure TNXDirectiveState.PushConditional(ACondition: Boolean);
var
  I: Integer;
  Parent: Boolean;
begin
  Parent := IsActive;
  I := Length(FConditionals);
  SetLength(FConditionals, I + 1);

  FConditionals[I].ParentActive := Parent;
  FConditionals[I].BranchActive := Parent and ACondition;
  FConditionals[I].BranchTaken := ACondition;
end;

procedure TNXDirectiveState.ElseConditional;
var
  I: Integer;
begin
  I := High(FConditionals);

  if I < 0 then
    raise Exception.Create('ELSE directive without matching IF');

  FConditionals[I].BranchActive :=
    FConditionals[I].ParentActive and
    not FConditionals[I].BranchTaken;

  FConditionals[I].BranchTaken := True;
end;

procedure TNXDirectiveState.ElseIfConditional(ACondition: Boolean);
var
  I: Integer;
begin
  I := High(FConditionals);

  if I < 0 then
    raise Exception.Create('ELSEIF directive without matching IF');

  if FConditionals[I].BranchTaken then
    FConditionals[I].BranchActive := False
  else
    FConditionals[I].BranchActive :=
      FConditionals[I].ParentActive and ACondition;

  if ACondition then
    FConditionals[I].BranchTaken := True;
end;

procedure TNXDirectiveState.PopConditional;
var
  I: Integer;
begin
  I := High(FConditionals);

  if I < 0 then
    raise Exception.Create('ENDIF directive without matching IF');

  SetLength(FConditionals, I);
end;

function TNXDirectiveState.ConditionalDepth: Integer;
begin
  Result := Length(FConditionals);
end;

function TNXDirectiveState.TryEvaluateLocalConditional(
  const AExpression: string;
  out AValue: Boolean
): Boolean;
var
  T, Arg: string;
  P: Integer;
  L, R: string;
  LV, RV: Boolean;
begin
  T := Trim(AExpression);

  if T = '' then
    Exit(False);

  if ExtractCallArgument(T, 'DEFINED', Arg) then
  begin
    AValue := IsDefined(Arg);
    Exit(True);
  end;

  if Copy(UpperCase(T), 1, 4) = 'NOT ' then
  begin
    Result := TryEvaluateLocalConditional(
      Trim(Copy(T, 5, MaxInt)),
      AValue
    );

    if Result then
      AValue := not AValue;

    Exit;
  end;

  P := Pos(' AND ', UpperCase(T));

  if P > 0 then
  begin
    L := Copy(T, 1, P - 1);
    R := Copy(T, P + 5, MaxInt);

    if TryEvaluateLocalConditional(L, LV) and
       TryEvaluateLocalConditional(R, RV) then
    begin
      AValue := LV and RV;
      Exit(True);
    end;

    Exit(False);
  end;

  P := Pos(' OR ', UpperCase(T));

  if P > 0 then
  begin
    L := Copy(T, 1, P - 1);
    R := Copy(T, P + 4, MaxInt);

    if TryEvaluateLocalConditional(L, LV) and
       TryEvaluateLocalConditional(R, RV) then
    begin
      AValue := LV or RV;
      Exit(True);
    end;

    Exit(False);
  end;

  T := StripOuterParens(T);

  if SameText(T, 'TRUE') then
  begin
    AValue := True;
    Exit(True);
  end;

  if SameText(T, 'FALSE') then
  begin
    AValue := False;
    Exit(True);
  end;

  if IsDefined(T) then
  begin
    AValue := True;
    Exit(True);
  end;

  Result := False;
end;

function TNXDirectiveState.Process(
  const ADirective: string;
  out AIncludeName: string;
  out ABlocker: TNXBlockInfo
): TNXDirectiveResult;
var
  Name, Arg: string;
  Condition: Boolean;
begin
  Result := drHandled;
  AIncludeName := '';
  ABlocker.Clear;

  SplitDirective(ADirective, Name, Arg);

  if (Name = 'IFDEF') or (Name = 'IFNDEF') then
  begin
    if not IsActive then
      Condition := False
    else
      Condition := IsDefined(Arg);

    if Name = 'IFNDEF' then
      Condition := not Condition;

    PushConditional(Condition);
    Exit;
  end;

  if (Name = 'IF') or (Name = 'IFOPT') then
  begin
    if not IsActive then
      Condition := False
    else if not TryEvaluateLocalConditional(Arg, Condition) then
    begin
      if (FResolver = nil) or
         not FResolver.EvaluateConditional(
           Arg,
           Condition,
           ABlocker
         ) then
      begin
        if ABlocker.Assigned then
          Exit(drBlocked);

        raise Exception.CreateFmt(
          'Unable to resolve conditional directive: %s',
          [Arg]
        );
      end;
    end;

    PushConditional(Condition);
    Exit;
  end;

  if (Name = 'ELSEIF') or (Name = 'ELIF') then
  begin
    if Length(FConditionals) = 0 then
      raise Exception.Create('ELSEIF directive without matching IF');

    if not FConditionals[High(FConditionals)].ParentActive or
       FConditionals[High(FConditionals)].BranchTaken then
      Condition := False
    else if not TryEvaluateLocalConditional(Arg, Condition) then
    begin
      if (FResolver = nil) or
         not FResolver.EvaluateConditional(
           Arg,
           Condition,
           ABlocker
         ) then
      begin
        if ABlocker.Assigned then
          Exit(drBlocked);

        raise Exception.CreateFmt(
          'Unable to resolve conditional directive: %s',
          [Arg]
        );
      end;
    end;

    ElseIfConditional(Condition);
    Exit;
  end;

  if Name = 'ELSE' then
  begin
    ElseConditional;
    Exit;
  end;

  if (Name = 'ENDIF') or (Name = 'IFEND') then
  begin
    PopConditional;
    Exit;
  end;

  if not IsActive then
    Exit;

  if Name = 'DEFINE' then
  begin
    Define(Arg);
    Exit;
  end;

  if Name = 'UNDEF' then
  begin
    Undefine(Arg);
    Exit;
  end;

  if (Name = 'I') or (Name = 'INCLUDE') then
  begin
    AIncludeName := Arg;

    if (Length(AIncludeName) >= 2) and
       (((AIncludeName[1] = #39) and
         (AIncludeName[Length(AIncludeName)] = #39)) or
        ((AIncludeName[1] = '"') and
         (AIncludeName[Length(AIncludeName)] = '"'))) then
      AIncludeName := Copy(
        AIncludeName,
        2,
        Length(AIncludeName) - 2
      );

    Result := drInclude;
    Exit;
  end;

  if Assigned(FOnUnknownDirective) then
    FOnUnknownDirective(Name, Arg);
end;

end.
