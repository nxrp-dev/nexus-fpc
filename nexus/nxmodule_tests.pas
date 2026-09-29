program nxmodule_tests;

{$mode objfpc}{$H+}

uses
  SysUtils,
  nxworkgraph,
  nxPasTokenTypes,
  nxPasDirectives,
  nxPasTokenizer,
  nxPasConditionals,
  nxmodule;

type
  TNXTestSemanticResolver = class(TNXSemanticDirectiveResolver)
  private
    FStateMap: TNXStateMap;
    FBlockingWorkID: TNXWorkID;
    FRequiredState: TNXCompileState;
  public
    constructor Create(
      AStateMap: TNXStateMap;
      ABlockingWorkID: TNXWorkID;
      ARequiredState: TNXCompileState
    );

    function EvaluateConditional(
      const AExpression: string;
      out AValue: Boolean;
      out ABlocker: TNXBlockInfo
    ): Boolean; override;
  end;

  TNXTestBlockingModule = class(TNXModule)
  private
    FBlockingModule: TNXModule;
    FBlockingPhase: TNXModulePhase;
    FRequiredState: TNXCompileState;
    FHasBlocked: Boolean;
  protected
    function ExecutePhase(
      APhase: TNXModulePhase;
      AWorkspace: TNXModulePhaseWorkspace
    ): TNXTransitionResult; override;
  public
    procedure ConfigureBlock(
      APhase: TNXModulePhase;
      ABlockingModule: TNXModule;
      ARequiredState: TNXCompileState
    );
  end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function Tokenize(const ASource: string): TNXTokenizer;
begin
  Result := TNXTokenizer.Create;
  try
    Result.Start('test.pas', ASource);
    Check(
      Result.Continue = tsComplete,
      'Physical tokenization unexpectedly blocked'
    );
  except
    Result.Free;
    raise;
  end;
end;

function CountTokenKind(
  const ATokens: TNXTokenBuffer;
  AKind: TNXTokenKind
): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(ATokens) do
    if ATokens[I].Kind = AKind then
      Inc(Result);
end;

function CountSymbol(
  const ATokens: TNXTokenBuffer;
  ASymbol: TNXSymbol
): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(ATokens) do
    if (ATokens[I].Kind = tkSymbol) and
       (ATokens[I].Variant = Ord(ASymbol)) then
      Inc(Result);
end;

function HasIdentifier(
  ATokenizer: TNXTokenizer;
  const ATokens: TNXTokenBuffer;
  const AName: string
): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(ATokens) do
    if (ATokens[I].Kind in [tkIdentifier, tkKeyword]) and
       SameText(ATokenizer.IdentifierText(ATokens[I].Value), AName) then
      Exit(True);

  Result := False;
end;

procedure CheckSamePhysicalTokens(
  ALeftTokenizer: TNXTokenizer;
  ARightTokenizer: TNXTokenizer
);
var
  I: Integer;
  LeftTokens: TNXTokenBuffer;
  RightTokens: TNXTokenBuffer;
begin
  LeftTokens := ALeftTokenizer.Tokens;
  RightTokens := ARightTokenizer.Tokens;
  Check(Length(LeftTokens) = Length(RightTokens), 'Token counts differ');

  for I := 0 to High(LeftTokens) do
  begin
    Check(LeftTokens[I].Kind = RightTokens[I].Kind, 'Token kind differs');
    Check(LeftTokens[I].Variant = RightTokens[I].Variant, 'Token variant differs');
    Check(LeftTokens[I].Value = RightTokens[I].Value, 'Token value differs');
    Check(LeftTokens[I].SourceID = RightTokens[I].SourceID, 'Source ID differs');
    Check(LeftTokens[I].Offset = RightTokens[I].Offset, 'Token offset differs');
    Check(LeftTokens[I].Length = RightTokens[I].Length, 'Token length differs');
    Check(LeftTokens[I].Line = RightTokens[I].Line, 'Token line differs');
    Check(LeftTokens[I].Column = RightTokens[I].Column, 'Token column differs');
    Check(LeftTokens[I].Flags = RightTokens[I].Flags, 'Token flags differ');
  end;
end;

function NewUnit(
  AStateMap: TNXStateMap;
  const AName: string
): TNXModule;
begin
  Result := TNXModule.Create(
    AStateMap,
    'unit:' + LowerCase(AName),
    AName,
    AName + '.pas',
    'unit ' + AName + '; interface implementation end.',
    nmkUnit
  );
end;

procedure CompleteNext(AQueue: TNXAssignment; AExpected: TNXWorkItem);
var
  Work: TNXWorkItem;
  WorkResult: TNXWorkResult;
begin
  Check(AQueue.Next(Work), 'Expected queued work');
  Check(Work = AExpected, 'Scheduler selected unexpected work');
  WorkResult := Work.Process;
  AQueue.ReturnWork(Work, WorkResult);
  Check(WorkResult = wrCompleted, 'Expected work to complete');
end;

constructor TNXTestSemanticResolver.Create(
  AStateMap: TNXStateMap;
  ABlockingWorkID: TNXWorkID;
  ARequiredState: TNXCompileState
);
begin
  inherited Create;
  FStateMap := AStateMap;
  FBlockingWorkID := ABlockingWorkID;
  FRequiredState := ARequiredState;
end;

function TNXTestSemanticResolver.EvaluateConditional(
  const AExpression: string;
  out AValue: Boolean;
  out ABlocker: TNXBlockInfo
): Boolean;
begin
  ABlocker.Clear;

  if FStateMap.GetState(FBlockingWorkID) < Ord(FRequiredState) then
  begin
    AValue := False;
    ABlocker.WorkID := FBlockingWorkID;
    ABlocker.RequiredState := Ord(FRequiredState);
    ABlocker.Reason := AExpression;
    Exit(False);
  end;

  AValue := True;
  Result := True;
end;

procedure TNXTestBlockingModule.ConfigureBlock(
  APhase: TNXModulePhase;
  ABlockingModule: TNXModule;
  ARequiredState: TNXCompileState
);
begin
  FBlockingPhase := APhase;
  FBlockingModule := ABlockingModule;
  FRequiredState := ARequiredState;
end;

function TNXTestBlockingModule.ExecutePhase(
  APhase: TNXModulePhase;
  AWorkspace: TNXModulePhaseWorkspace
): TNXTransitionResult;
begin
  if (APhase = FBlockingPhase) and not FHasBlocked then
  begin
    AWorkspace.Advance;
    FHasBlocked := True;
    BlockCurrentPhaseOn(FBlockingModule, FRequiredState);
    Exit(trBlocked);
  end;

  Result := inherited ExecutePhase(APhase, AWorkspace);
end;

procedure TestPhysicalConditionalTokens;
var
  Buffer: TNXTokenBuffer;
  I: Integer;
  SawElse: Boolean;
  SawEndIf: Boolean;
  SawIfDef: Boolean;
  Tokenizer: TNXTokenizer;
begin
  Tokenizer := Tokenize(
    '{$IFDEF X}' + LineEnding +
    'Foo;' + LineEnding +
    '{$ELSE}' + LineEnding +
    'Bar;' + LineEnding +
    '{$ENDIF}'
  );
  try
    Buffer := Tokenizer.Tokens;
    Check(HasIdentifier(Tokenizer, Buffer, 'Foo'), 'Foo was not tokenized');
    Check(HasIdentifier(Tokenizer, Buffer, 'Bar'), 'Bar was not tokenized');
    Check(
      CountTokenKind(Buffer, tkDirective) = 3,
      'Conditional directives were not emitted as tokens'
    );

    SawIfDef := False;
    SawElse := False;
    SawEndIf := False;
    for I := 0 to High(Buffer) do
      if Buffer[I].Kind = tkDirective then
        case TNXDirectiveKind(Buffer[I].Variant) of
          dkIfDef:
            begin
              SawIfDef := True;
              Check(Buffer[I].Line = 1, 'IFDEF source line was lost');
              Check(Buffer[I].Column = 1, 'IFDEF source column was lost');
              Check(Buffer[I].Length > 0, 'IFDEF source length was lost');
              Check(
                SameText(
                  Tokenizer.DirectiveText(Buffer[I].Value),
                  'IFDEF X'
                ),
                'IFDEF directive text was lost'
              );
            end;
          dkElse: SawElse := True;
          dkEndIf: SawEndIf := True;
        end;

    Check(SawIfDef, 'IFDEF directive was not classified');
    Check(SawElse, 'ELSE directive was not classified');
    Check(SawEndIf, 'ENDIF directive was not classified');
  finally
    Tokenizer.Free;
  end;
end;

procedure TestConditionalPunctuationAndStableTokenization;
const
  SourceText =
    'Foo(A' + LineEnding +
    '{$IFDEF X}' + LineEnding +
    ', B' + LineEnding +
    '{$ENDIF}' + LineEnding +
    ');' + LineEnding +
    'Value := 1{$IFDEF X};{$ENDIF}';
var
  DefinedProcessor: TNXConditionalProcessor;
  DefinedTokens: TNXTokenBuffer;
  LeftTokenizer: TNXTokenizer;
  RightTokenizer: TNXTokenizer;
  UndefinedProcessor: TNXConditionalProcessor;
  UndefinedTokens: TNXTokenBuffer;
begin
  LeftTokenizer := Tokenize(SourceText);
  RightTokenizer := Tokenize(SourceText);
  DefinedProcessor := nil;
  UndefinedProcessor := nil;
  try
    CheckSamePhysicalTokens(LeftTokenizer, RightTokenizer);

    DefinedProcessor := TNXConditionalProcessor.Create(LeftTokenizer);
    DefinedProcessor.Define('X');
    Check(
      DefinedProcessor.Continue = cpsComplete,
      'Defined conditional processing did not complete'
    );
    DefinedTokens := DefinedProcessor.Tokens;

    UndefinedProcessor := TNXConditionalProcessor.Create(RightTokenizer);
    Check(
      UndefinedProcessor.Continue = cpsComplete,
      'Undefined conditional processing did not complete'
    );
    UndefinedTokens := UndefinedProcessor.Tokens;

    Check(
      CountTokenKind(DefinedTokens, tkDirective) = 0,
      'Conditional directives leaked into the effective stream'
    );
    Check(
      HasIdentifier(LeftTokenizer, DefinedTokens, 'B'),
      'Defined branch lost its parameter token'
    );
    Check(
      not HasIdentifier(RightTokenizer, UndefinedTokens, 'B'),
      'Undefined branch retained its parameter token'
    );
    Check(
      CountSymbol(DefinedTokens, syComma) = 1,
      'Defined branch lost its conditional comma'
    );
    Check(
      CountSymbol(UndefinedTokens, syComma) = 0,
      'Undefined branch retained its conditional comma'
    );
    Check(
      CountSymbol(DefinedTokens, sySemicolon) = 2,
      'Defined branch lost its conditional semicolon'
    );
    Check(
      CountSymbol(UndefinedTokens, sySemicolon) = 1,
      'Undefined branch retained its conditional semicolon'
    );
  finally
    UndefinedProcessor.Free;
    DefinedProcessor.Free;
    RightTokenizer.Free;
    LeftTokenizer.Free;
  end;
end;

procedure TestLexicalAndSyntaxBoundary;
var
  Buffer: TNXTokenBuffer;
  Processor: TNXConditionalProcessor;
  Tokenizer: TNXTokenizer;
begin
  Tokenizer := Tokenize(
    'Foo(A' + LineEnding +
    '{$IFDEF BROKEN_CONFIGURATION}' + LineEnding +
    'B' + LineEnding +
    '{$ENDIF}' + LineEnding +
    ');' + LineEnding +
    '{$IFDEF X}' + LineEnding +
    'UnknownIdentifierThatDoesNotExist;' + LineEnding +
    '{$ENDIF}'
  );
  Processor := nil;
  try
    Buffer := Tokenizer.Tokens;
    Check(
      HasIdentifier(Tokenizer, Buffer, 'B'),
      'Syntactically incomplete branch was not tokenized'
    );
    Check(
      HasIdentifier(Tokenizer, Buffer, 'UnknownIdentifierThatDoesNotExist'),
      'Tokenizer attempted semantic validation'
    );

    Processor := TNXConditionalProcessor.Create(Tokenizer);
    Processor.Define('BROKEN_CONFIGURATION');
    Check(
      Processor.Continue = cpsComplete,
      'Conditional processing attempted syntax validation'
    );
  finally
    Processor.Free;
    Tokenizer.Free;
  end;
end;

procedure TestMalformedInactiveBranchFailsTokenization;
var
  Failed: Boolean;
  Tokenizer: TNXTokenizer;
begin
  Failed := False;
  Tokenizer := TNXTokenizer.Create;
  try
    Tokenizer.Start(
      'malformed.pas',
      '{$IFDEF X}' + LineEnding +
      'S := ' + #39 + 'unterminated' + LineEnding +
      '{$ENDIF}'
    );

    try
      Tokenizer.Continue;
    except
      on E: Exception do
        Failed := Pos('quoted string', LowerCase(E.Message)) > 0;
    end;

    Check(Failed, 'Malformed inactive string was not rejected lexically');
  finally
    Tokenizer.Free;
  end;
end;

procedure TestErrorDirectiveSelection;
var
  Failed: Boolean;
  SelectedProcessor: TNXConditionalProcessor;
  Tokenizer: TNXTokenizer;
  UnselectedProcessor: TNXConditionalProcessor;
begin
  Tokenizer := Tokenize(
    '{$IFDEF UNSUPPORTED}' + LineEnding +
    '{$ERROR ''This configuration is unsupported''}' + LineEnding +
    '{$ENDIF}'
  );
  SelectedProcessor := nil;
  UnselectedProcessor := nil;
  try
    UnselectedProcessor := TNXConditionalProcessor.Create(Tokenizer);
    Check(
      UnselectedProcessor.Continue = cpsComplete,
      'Inactive ERROR directive fired'
    );

    SelectedProcessor := TNXConditionalProcessor.Create(Tokenizer);
    SelectedProcessor.Define('UNSUPPORTED');
    Failed := False;
    try
      SelectedProcessor.Continue;
    except
      on E: Exception do
        Failed := Pos('ERROR', UpperCase(E.Message)) > 0;
    end;

    Check(Failed, 'Selected ERROR directive did not fire');
  finally
    UnselectedProcessor.Free;
    SelectedProcessor.Free;
    Tokenizer.Free;
  end;
end;

procedure TestNestedConditionalsAndElseIf;
var
  EffectiveTokens: TNXTokenBuffer;
  Processor: TNXConditionalProcessor;
  Tokenizer: TNXTokenizer;
begin
  Tokenizer := Tokenize(
    '{$IFDEF OUTER}' + LineEnding +
    '  {$IF SizeOf(TMissing) = 4}' + LineEnding +
    '  Bad;' + LineEnding +
    '  {$ENDIF}' + LineEnding +
    '{$ELSEIF DEFINED(B)}' + LineEnding +
    '  Good;' + LineEnding +
    '{$ELSE}' + LineEnding +
    '  Other;' + LineEnding +
    '{$ENDIF}'
  );
  Processor := TNXConditionalProcessor.Create(Tokenizer);
  try
    Processor.Define('B');
    Check(
      Processor.Continue = cpsComplete,
      'Inactive nested semantic condition blocked processing'
    );
    EffectiveTokens := Processor.Tokens;
    Check(
      HasIdentifier(Tokenizer, EffectiveTokens, 'Good'),
      'ELSEIF branch was not selected'
    );
    Check(
      not HasIdentifier(Tokenizer, EffectiveTokens, 'Bad'),
      'Inactive nested branch leaked into effective tokens'
    );
    Check(
      not HasIdentifier(Tokenizer, EffectiveTokens, 'Other'),
      'ELSE branch remained active after ELSEIF selection'
    );
  finally
    Processor.Free;
    Tokenizer.Free;
  end;
end;

procedure TestConstructionAndPublication;
var
  StateMap: TNXStateMap;
  Module: TNXModule;
  Snapshot: TNXModuleSnapshot;
begin
  StateMap := TNXStateMap.Create;
  Module := NewUnit(StateMap, 'Alpha');
  try
    Check(not Module.Started, 'New module must not be started');
    Check(Module.ClonePublished = nil, 'New module must not publish data');
    Check(Module.Process = wrCompleted, 'Module did not complete');

    Snapshot := Module.ClonePublished;
    try
      Check(Snapshot <> nil, 'Completed module has no snapshot');
      Check(Snapshot.Identity = 'unit:alpha', 'Snapshot identity changed');
      Check(Snapshot.ModuleName = 'Alpha', 'Snapshot module name changed');
      Check(Snapshot.State = csProcessed, 'Snapshot has wrong final state');
      Check(Snapshot.Revision = 10, 'Unexpected published revision count');
      Check(
        Snapshot.PhysicalTokens <> nil,
        'Physical token stream was not published'
      );
      Check(
        Snapshot.EffectiveTokens <> nil,
        'Effective token stream was not published'
      );
      Check(
        Snapshot.PhysicalTokens.TokenCount > 1,
        'Physical token stream is empty'
      );
      Check(
        Snapshot.Phase[nmpImplementation].Completed,
        'Implementation phase was not published as complete'
      );
    finally
      Snapshot.Free;
    end;
  finally
    Module.Free;
    StateMap.Free;
  end;
end;

procedure TestStaticDependencyScheduling;
var
  StateMap: TNXStateMap;
  Queue: TNXAssignment;
  Consumer: TNXModule;
  Provider: TNXModule;
  Work: TNXWorkItem;
  WorkResult: TNXWorkResult;
begin
  StateMap := TNXStateMap.Create;
  Queue := TNXAssignment.Create(StateMap);
  Consumer := NewUnit(StateMap, 'Consumer');
  Provider := NewUnit(StateMap, 'Provider');
  try
    Consumer.RequireInterface(Provider);
    Queue.Add(Consumer);
    Queue.Add(Provider);

    Check(Queue.Next(Work), 'Expected consumer work');
    Check(Work = Consumer, 'Queue order changed before blocking');
    WorkResult := Work.Process;
    Check(WorkResult = wrBlocked, 'Consumer did not block');
    Queue.ReturnWork(Work, WorkResult);

    CompleteNext(Queue, Provider);
    CompleteNext(Queue, Consumer);

    Check(Queue.BlockedCount = 0, 'Blocked queue was not drained');
    Check(Consumer.Completed, 'Consumer did not complete');
  finally
    Provider.Free;
    Consumer.Free;
    Queue.Free;
    StateMap.Free;
  end;
end;

procedure TestConditionalProcessorResumeWithoutPartialPublication;
var
  StateMap: TNXStateMap;
  Queue: TNXAssignment;
  Provider: TNXModule;
  Consumer: TNXModule;
  Resolver: TNXTestSemanticResolver;
  Work: TNXWorkItem;
  WorkResult: TNXWorkResult;
  Snapshot: TNXModuleSnapshot;
begin
  StateMap := TNXStateMap.Create;
  Queue := TNXAssignment.Create(StateMap);
  Provider := NewUnit(StateMap, 'SemanticProvider');
  Resolver := TNXTestSemanticResolver.Create(
    StateMap,
    Provider.WorkID,
    csProcessed
  );
  Consumer := TNXModule.Create(
    StateMap,
    'unit:semanticconsumer',
    'SemanticConsumer',
    'SemanticConsumer.pas',
    'unit SemanticConsumer; interface ' +
    '{$if SizeOf(SemanticProvider.TValue) = 4}' +
    'const Answer = 42; {$endif} implementation end.',
    nmkUnit,
    Resolver
  );
  try
    Queue.Add(Consumer);
    Queue.Add(Provider);

    Check(Queue.Next(Work), 'Expected semantic consumer work');
    Check(Work = Consumer, 'Unexpected initial semantic work');
    WorkResult := Work.Process;
    Check(WorkResult = wrBlocked, 'Conditional processor did not block');
    Queue.ReturnWork(Work, WorkResult);

    Check(
      Consumer.State = Ord(csTokenized),
      'Blocked conditional processor advanced its semantic state'
    );
    Check(
      Consumer.WorkingPhase(nmpProcessConditionals).Cursor = 1,
      'Conditional working progress was not retained'
    );

    Snapshot := Consumer.ClonePublished;
    try
      Check(Snapshot <> nil, 'Tokenizing state was not published');
      Check(
        Snapshot.Phase[nmpProcessConditionals].Cursor = 0,
        'Partial conditional progress leaked into published data'
      );
      Check(
        Snapshot.EffectiveTokens = nil,
        'Partial effective token stream was published'
      );
      Check(
        Snapshot.PhysicalTokens <> nil,
        'Completed physical tokens were not published before blocking'
      );
    finally
      Snapshot.Free;
    end;

    CompleteNext(Queue, Provider);
    CompleteNext(Queue, Consumer);

    Snapshot := Consumer.ClonePublished;
    try
      Check(
        Snapshot.EffectiveTokens <> nil,
        'Completed effective tokens were not published'
      );
      Check(
        Snapshot.Phase[nmpProcessConditionals].Cursor = 2,
        'Conditional processor did not resume its retained work'
      );
    finally
      Snapshot.Free;
    end;
  finally
    Consumer.Free;
    Resolver.Free;
    Provider.Free;
    Queue.Free;
    StateMap.Free;
  end;
end;

procedure TestNonTokenizerPhaseResume;
var
  StateMap: TNXStateMap;
  Queue: TNXAssignment;
  Provider: TNXModule;
  Consumer: TNXTestBlockingModule;
  Work: TNXWorkItem;
  WorkResult: TNXWorkResult;
  BlockedSnapshot: TNXModuleSnapshot;
  CompletedSnapshot: TNXModuleSnapshot;
begin
  StateMap := TNXStateMap.Create;
  Queue := TNXAssignment.Create(StateMap);
  Provider := NewUnit(StateMap, 'PhaseProvider');
  BlockedSnapshot := nil;
  CompletedSnapshot := nil;
  Consumer := TNXTestBlockingModule.Create(
    StateMap,
    'unit:phaseconsumer',
    'PhaseConsumer',
    'PhaseConsumer.pas',
    'unit PhaseConsumer; interface implementation end.',
    nmkUnit
  );
  try
    Consumer.ConfigureBlock(
      nmpImplementation,
      Provider,
      csProcessed
    );
    Queue.Add(Consumer);
    Queue.Add(Provider);

    Check(Queue.Next(Work), 'Expected phase consumer work');
    Check(Work = Consumer, 'Unexpected initial phase work');
    WorkResult := Work.Process;
    Check(WorkResult = wrBlocked, 'Implementation phase did not block');
    Queue.ReturnWork(Work, WorkResult);

    Check(
      Consumer.WorkingPhase(nmpImplementation).Cursor = 1,
      'Private implementation progress was not retained'
    );

    BlockedSnapshot := Consumer.ClonePublished;
    Check(
      BlockedSnapshot.Phase[nmpImplementation].Cursor = 0,
      'Partial implementation progress was published'
    );
    Check(
      BlockedSnapshot.State = csCompilingWaitIntf,
      'Blocked implementation advanced module state'
    );

    CompleteNext(Queue, Provider);
    CompleteNext(Queue, Consumer);

    CompletedSnapshot := Consumer.ClonePublished;
    Check(
      CompletedSnapshot.Phase[nmpImplementation].Cursor = 2,
      'Implementation work did not resume from retained progress'
    );
    Check(
      CompletedSnapshot.Phase[nmpImplementation].Completed,
      'Resumed implementation phase did not complete'
    );
    Check(
      BlockedSnapshot.Phase[nmpImplementation].Cursor = 0,
      'A previously published snapshot changed after a later commit'
    );
    Check(
      BlockedSnapshot.State = csCompilingWaitIntf,
      'A previously published state changed after a later commit'
    );
  finally
    CompletedSnapshot.Free;
    BlockedSnapshot.Free;
    Consumer.Free;
    Provider.Free;
    Queue.Free;
    StateMap.Free;
  end;
end;

begin
  TestPhysicalConditionalTokens;
  WriteLn('PASS physical conditional tokens');

  TestConditionalPunctuationAndStableTokenization;
  WriteLn('PASS conditional punctuation and stable tokenization');

  TestLexicalAndSyntaxBoundary;
  WriteLn('PASS lexical and syntax boundary');

  TestMalformedInactiveBranchFailsTokenization;
  WriteLn('PASS malformed inactive branch rejection');

  TestErrorDirectiveSelection;
  WriteLn('PASS ERROR directive selection');

  TestNestedConditionalsAndElseIf;
  WriteLn('PASS nested conditionals and ELSEIF');

  TestConstructionAndPublication;
  WriteLn('PASS construction and publication');

  TestStaticDependencyScheduling;
  WriteLn('PASS static dependency scheduling');

  TestConditionalProcessorResumeWithoutPartialPublication;
  WriteLn('PASS conditional processing resume and publication isolation');

  TestNonTokenizerPhaseResume;
  WriteLn('PASS non-tokenizer phase resume and publication isolation');

  WriteLn('All nxmodule tests passed.');
end.
