unit nxmodule;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  nxworkgraph,
  nxPasTokenTypes,
  nxPasDirectives,
  nxPasTokenizer,
  nxPasConditionals;

type
  TNXModuleKind = (
    nmkUnit,
    nmkProgram,
    nmkLibrary,
    nmkPackage
  );

  TNXModulePhase = (
    nmpStartTokenizing,
    nmpContinueTokenizing,
    nmpProcessConditionals,
    nmpProgramDeclarations,
    nmpInterfaceDeclarations,
    nmpImplementation,
    nmpFinishCompile,
    nmpFinalizeCRC,
    nmpFinishUnit,
    nmpMarkProcessed
  );

  TNXModuleDefinition = class
  private
    FIdentity: string;
    FModuleName: string;
    FSourceName: string;
    FSourceText: string;
    FKind: TNXModuleKind;
  public
    constructor Create(
      const AIdentity: string;
      const AModuleName: string;
      const ASourceName: string;
      const ASourceText: string;
      AKind: TNXModuleKind
    );

    property Identity: string read FIdentity;
    property ModuleName: string read FModuleName;
    property SourceName: string read FSourceName;
    property SourceText: string read FSourceText;
    property Kind: TNXModuleKind read FKind;
  end;

  { Base class for mutable, phase-specific state that must survive a blocked
    transition.  Parser, resolver and code-generation implementations can
    derive their own state holders without adding those details to the work
    scheduler or to the published module snapshot. }
  TNXModulePhaseData = class
  end;

  TNXModulePhaseWorkspace = class
  private
    FStarted: Boolean;
    FCompleted: Boolean;
    FCursor: QWord;
    FData: TNXModulePhaseData;
  public
    destructor Destroy; override;

    procedure BeginWork;
    procedure Advance(ACount: QWord = 1);
    procedure CompleteWork;
    procedure ReplaceData(AData: TNXModulePhaseData);

    property Started: Boolean read FStarted;
    property Completed: Boolean read FCompleted;
    property Cursor: QWord read FCursor;
    property Data: TNXModulePhaseData read FData;
  end;

  TNXModulePhaseSnapshot = record
    Started: Boolean;
    Completed: Boolean;
    Cursor: QWord;
  end;

  TNXPublishedTokenStream = class
  private
    FTokens: nxPasTokenTypes.TNXTokenBuffer;
    FIdentifiers: array of string;
    FLiterals: array of string;
    FDirectiveTexts: array of string;
    procedure CopyPools(ATokenizer: TNXTokenizer);
  public
    constructor CreatePhysical(ATokenizer: TNXTokenizer);
    constructor CreateEffective(
      AProcessor: TNXConditionalProcessor;
      ATokenizer: TNXTokenizer
    );
    function Clone: TNXPublishedTokenStream;

    function TokenCount: Integer;
    function GetToken(AIndex: Integer): nxPasTokenTypes.TNXToken;
    function IdentifierText(AID: LongWord): string;
    function LiteralText(AID: LongWord): string;
    function DirectiveText(AID: LongWord): string;
  end;

  TNXModuleWorkspace = class
  private
    FTokenizer: TNXTokenizer;
    FConditionalProcessor: TNXConditionalProcessor;
    FSemanticResolver: TNXSemanticDirectiveResolver;
    FTokenizerStarted: Boolean;
    FPhases: array[TNXModulePhase] of TNXModulePhaseWorkspace;

    function GetPhase(APhase: TNXModulePhase): TNXModulePhaseWorkspace;
  public
    constructor Create(
      ASemanticResolver: TNXSemanticDirectiveResolver
    );
    destructor Destroy; override;

    procedure StartTokenizer(ADefinition: TNXModuleDefinition);
    procedure StartConditionalProcessor;

    property Tokenizer: TNXTokenizer read FTokenizer;
    property ConditionalProcessor: TNXConditionalProcessor
      read FConditionalProcessor;
    property TokenizerStarted: Boolean read FTokenizerStarted;
    property Phase[APhase: TNXModulePhase]: TNXModulePhaseWorkspace
      read GetPhase;
  end;

  TNXModuleSnapshot = class
  private
    FIdentity: string;
    FModuleName: string;
    FSourceName: string;
    FKind: TNXModuleKind;
    FRevision: QWord;
    FState: TNXCompileState;
    FPhases: array[TNXModulePhase] of TNXModulePhaseSnapshot;
    FPhysicalTokens: TNXPublishedTokenStream;
    FEffectiveTokens: TNXPublishedTokenStream;

    function GetPhase(APhase: TNXModulePhase): TNXModulePhaseSnapshot;
  public
    constructor Create(ADefinition: TNXModuleDefinition);
    destructor Destroy; override;

    function Clone: TNXModuleSnapshot;
    procedure UpdateFrom(
      AWorkspace: TNXModuleWorkspace;
      ANewState: TNXCompileState
    );

    property Identity: string read FIdentity;
    property ModuleName: string read FModuleName;
    property SourceName: string read FSourceName;
    property Kind: TNXModuleKind read FKind;
    property Revision: QWord read FRevision;
    property State: TNXCompileState read FState;
    property Phase[APhase: TNXModulePhase]: TNXModulePhaseSnapshot
      read GetPhase;
    property PhysicalTokens: TNXPublishedTokenStream read FPhysicalTokens;
    property EffectiveTokens: TNXPublishedTokenStream read FEffectiveTokens;
  end;

  TNXModule = class(TNXWorkItem)
  private
    FDefinition: TNXModuleDefinition;
    FWorkspace: TNXModuleWorkspace;

    function StartTokenizing: TNXTransitionResult;
    function ContinueTokenizing: TNXTransitionResult;
    function ProcessConditionals: TNXTransitionResult;
    function ProcessProgramDeclarations: TNXTransitionResult;
    function ParseInterfaceDeclarations: TNXTransitionResult;
    function ProcessImplementation: TNXTransitionResult;
    function FinishCompile: TNXTransitionResult;
    function FinalizeCRC: TNXTransitionResult;
    function FinishUnit: TNXTransitionResult;
    function MarkProcessed: TNXTransitionResult;

    function RunPhase(APhase: TNXModulePhase): TNXTransitionResult;
    procedure AddStateDependency(
      AFromState: TNXCompileState;
      AModule: TNXModule;
      ARequiredState: TNXCompileState
    );
  protected
    function ExecutePhase(
      APhase: TNXModulePhase;
      AWorkspace: TNXModulePhaseWorkspace
    ): TNXTransitionResult; virtual;

    procedure BlockCurrentPhaseOn(
      AModule: TNXModule;
      ARequiredState: TNXCompileState
    );

    function CloneDataValue(AData: Pointer): Pointer; override;
    procedure FreeDataValue(AData: Pointer); override;
    procedure Commit(
      ANewData: Pointer;
      ANewState: TNXWorkState
    ); override;
  public
    constructor Create(
      AStateMap: TNXStateMap;
      const AIdentity: string;
      const AModuleName: string;
      const ASourceName: string;
      const ASourceText: string;
      AKind: TNXModuleKind;
      ASemanticResolver: TNXSemanticDirectiveResolver = nil
    );
    destructor Destroy; override;

    procedure RequireTokenized(AModule: TNXModule);
    procedure RequireProgramDeclarations(AModule: TNXModule);
    procedure RequireInterface(AModule: TNXModule);
    procedure RequireImplementation(AModule: TNXModule);
    procedure RequireFinish(AModule: TNXModule);
    procedure RequireCRC(AModule: TNXModule);

    function ClonePublished: TNXModuleSnapshot;
    function WorkingPhase(APhase: TNXModulePhase): TNXModulePhaseWorkspace;

    property Definition: TNXModuleDefinition read FDefinition;
  end;

implementation

constructor TNXModuleDefinition.Create(
  const AIdentity: string;
  const AModuleName: string;
  const ASourceName: string;
  const ASourceText: string;
  AKind: TNXModuleKind
);
begin
  inherited Create;

  if Trim(AIdentity) = '' then
    raise Exception.Create('Module identity cannot be empty');
  if Trim(AModuleName) = '' then
    raise Exception.Create('Module name cannot be empty');
  if Trim(ASourceName) = '' then
    raise Exception.Create('Module source name cannot be empty');

  FIdentity := AIdentity;
  FModuleName := AModuleName;
  FSourceName := ASourceName;
  FSourceText := ASourceText;
  FKind := AKind;
end;

destructor TNXModulePhaseWorkspace.Destroy;
begin
  FData.Free;
  inherited Destroy;
end;

procedure TNXModulePhaseWorkspace.BeginWork;
begin
  if FCompleted then
    raise Exception.Create('Completed phase cannot be restarted');

  FStarted := True;
end;

procedure TNXModulePhaseWorkspace.Advance(ACount: QWord);
begin
  if not FStarted then
    raise Exception.Create('Phase must be started before it can advance');
  if FCompleted then
    raise Exception.Create('Completed phase cannot advance');

  Inc(FCursor, ACount);
end;

procedure TNXModulePhaseWorkspace.CompleteWork;
begin
  if not FStarted then
    raise Exception.Create('Phase must be started before it can complete');

  FCompleted := True;
end;

procedure TNXModulePhaseWorkspace.ReplaceData(AData: TNXModulePhaseData);
begin
  if FData = AData then
    Exit;

  FData.Free;
  FData := AData;
end;

procedure TNXPublishedTokenStream.CopyPools(ATokenizer: TNXTokenizer);
var
  I: Integer;
begin
  if ATokenizer = nil then
    raise Exception.Create('ATokenizer cannot be nil');
  if not ATokenizer.Complete then
    raise Exception.Create('Cannot publish an incomplete token stream');

  SetLength(FIdentifiers, ATokenizer.IdentifierCount);
  for I := 0 to High(FIdentifiers) do
    FIdentifiers[I] := ATokenizer.IdentifierText(I);

  SetLength(FLiterals, ATokenizer.LiteralCount);
  for I := 0 to High(FLiterals) do
    FLiterals[I] := ATokenizer.LiteralText(I);

  SetLength(FDirectiveTexts, ATokenizer.DirectiveTextCount);
  for I := 0 to High(FDirectiveTexts) do
    FDirectiveTexts[I] := ATokenizer.DirectiveText(I);
end;

constructor TNXPublishedTokenStream.CreatePhysical(
  ATokenizer: TNXTokenizer
);
begin
  inherited Create;
  CopyPools(ATokenizer);
  FTokens := ATokenizer.Tokens;
end;

constructor TNXPublishedTokenStream.CreateEffective(
  AProcessor: TNXConditionalProcessor;
  ATokenizer: TNXTokenizer
);
begin
  inherited Create;

  if AProcessor = nil then
    raise Exception.Create('AProcessor cannot be nil');
  if not AProcessor.Complete then
    raise Exception.Create('Cannot publish incomplete effective tokens');

  CopyPools(ATokenizer);
  FTokens := AProcessor.Tokens;
end;

function TNXPublishedTokenStream.Clone: TNXPublishedTokenStream;
begin
  Result := TNXPublishedTokenStream.Create;
  Result.FTokens := Copy(FTokens);
  Result.FIdentifiers := Copy(FIdentifiers);
  Result.FLiterals := Copy(FLiterals);
  Result.FDirectiveTexts := Copy(FDirectiveTexts);
end;

function TNXPublishedTokenStream.TokenCount: Integer;
begin
  Result := Length(FTokens);
end;

function TNXPublishedTokenStream.GetToken(
  AIndex: Integer
): nxPasTokenTypes.TNXToken;
begin
  if (AIndex < 0) or (AIndex >= Length(FTokens)) then
    raise ERangeError.CreateFmt('Token index %d is out of range', [AIndex]);

  Result := FTokens[AIndex];
end;

function TNXPublishedTokenStream.IdentifierText(AID: LongWord): string;
begin
  if AID >= LongWord(Length(FIdentifiers)) then
    raise ERangeError.CreateFmt('Identifier index %d is out of range', [AID]);

  Result := FIdentifiers[AID];
end;

function TNXPublishedTokenStream.LiteralText(AID: LongWord): string;
begin
  if AID >= LongWord(Length(FLiterals)) then
    raise ERangeError.CreateFmt('Literal index %d is out of range', [AID]);

  Result := FLiterals[AID];
end;

function TNXPublishedTokenStream.DirectiveText(AID: LongWord): string;
begin
  if AID >= LongWord(Length(FDirectiveTexts)) then
    raise ERangeError.CreateFmt('Directive index %d is out of range', [AID]);

  Result := FDirectiveTexts[AID];
end;

constructor TNXModuleWorkspace.Create(
  ASemanticResolver: TNXSemanticDirectiveResolver
);
var
  CurrentPhase: TNXModulePhase;
begin
  inherited Create;

  FTokenizer := TNXTokenizer.Create;
  FSemanticResolver := ASemanticResolver;

  for CurrentPhase := Low(TNXModulePhase) to High(TNXModulePhase) do
    FPhases[CurrentPhase] := TNXModulePhaseWorkspace.Create;
end;

destructor TNXModuleWorkspace.Destroy;
var
  CurrentPhase: TNXModulePhase;
begin
  for CurrentPhase := Low(TNXModulePhase) to High(TNXModulePhase) do
    FPhases[CurrentPhase].Free;

  FConditionalProcessor.Free;
  FTokenizer.Free;
  inherited Destroy;
end;

function TNXModuleWorkspace.GetPhase(
  APhase: TNXModulePhase
): TNXModulePhaseWorkspace;
begin
  Result := FPhases[APhase];
end;

procedure TNXModuleWorkspace.StartTokenizer(
  ADefinition: TNXModuleDefinition
);
begin
  if FTokenizerStarted then
    Exit;
  if ADefinition = nil then
    raise Exception.Create('ADefinition cannot be nil');

  FTokenizer.Start(
    ADefinition.SourceName,
    ADefinition.SourceText
  );
  FTokenizerStarted := True;
end;

procedure TNXModuleWorkspace.StartConditionalProcessor;
begin
  if FConditionalProcessor <> nil then
    Exit;

  FConditionalProcessor := TNXConditionalProcessor.Create(
    FTokenizer,
    FSemanticResolver
  );
end;

constructor TNXModuleSnapshot.Create(ADefinition: TNXModuleDefinition);
begin
  inherited Create;

  FState := Low(TNXCompileState);

  if ADefinition <> nil then
  begin
    FIdentity := ADefinition.Identity;
    FModuleName := ADefinition.ModuleName;
    FSourceName := ADefinition.SourceName;
    FKind := ADefinition.Kind;
  end;
end;

destructor TNXModuleSnapshot.Destroy;
begin
  FEffectiveTokens.Free;
  FPhysicalTokens.Free;
  inherited Destroy;
end;

function TNXModuleSnapshot.GetPhase(
  APhase: TNXModulePhase
): TNXModulePhaseSnapshot;
begin
  Result := FPhases[APhase];
end;

function TNXModuleSnapshot.Clone: TNXModuleSnapshot;
begin
  Result := TNXModuleSnapshot.Create(nil);
  Result.FIdentity := FIdentity;
  Result.FModuleName := FModuleName;
  Result.FSourceName := FSourceName;
  Result.FKind := FKind;
  Result.FRevision := FRevision;
  Result.FState := FState;
  Result.FPhases := FPhases;

  if FPhysicalTokens <> nil then
    Result.FPhysicalTokens := FPhysicalTokens.Clone;

  if FEffectiveTokens <> nil then
    Result.FEffectiveTokens := FEffectiveTokens.Clone;
end;

procedure TNXModuleSnapshot.UpdateFrom(
  AWorkspace: TNXModuleWorkspace;
  ANewState: TNXCompileState
);
var
  CurrentPhase: TNXModulePhase;
  WorkspacePhase: TNXModulePhaseWorkspace;
begin
  if AWorkspace = nil then
    raise Exception.Create('AWorkspace cannot be nil');

  Inc(FRevision);
  FState := ANewState;

  for CurrentPhase := Low(TNXModulePhase) to High(TNXModulePhase) do
  begin
    WorkspacePhase := AWorkspace.Phase[CurrentPhase];
    FPhases[CurrentPhase].Started := WorkspacePhase.Started;
    FPhases[CurrentPhase].Completed := WorkspacePhase.Completed;
    FPhases[CurrentPhase].Cursor := WorkspacePhase.Cursor;
  end;

  if (FPhysicalTokens = nil) and AWorkspace.Tokenizer.Complete then
    FPhysicalTokens := TNXPublishedTokenStream.CreatePhysical(
      AWorkspace.Tokenizer
    );

  if (FEffectiveTokens = nil) and
     (AWorkspace.ConditionalProcessor <> nil) and
     AWorkspace.ConditionalProcessor.Complete then
    FEffectiveTokens := TNXPublishedTokenStream.CreateEffective(
      AWorkspace.ConditionalProcessor,
      AWorkspace.Tokenizer
    );
end;

constructor TNXModule.Create(
  AStateMap: TNXStateMap;
  const AIdentity: string;
  const AModuleName: string;
  const ASourceName: string;
  const ASourceText: string;
  AKind: TNXModuleKind;
  ASemanticResolver: TNXSemanticDirectiveResolver
);
begin
  inherited Create(
    AStateMap,
    AIdentity,
    Ord(Low(TNXCompileState)),
    Ord(High(TNXCompileState))
  );

  FDefinition := TNXModuleDefinition.Create(
    AIdentity,
    AModuleName,
    ASourceName,
    ASourceText,
    AKind
  );
  FWorkspace := TNXModuleWorkspace.Create(
    ASemanticResolver
  );

  Transition[Ord(csNotStarted)] := @StartTokenizing;
  Transition[Ord(csTokenizing)] := @ContinueTokenizing;
  Transition[Ord(csTokenized)] := @ProcessConditionals;
  Transition[Ord(csCompile)] := @ProcessProgramDeclarations;
  Transition[Ord(csCompilingWait)] := @ParseInterfaceDeclarations;
  Transition[Ord(csCompilingWaitIntf)] := @ProcessImplementation;
  Transition[Ord(csCompilingWaitImpl)] := @FinishCompile;
  Transition[Ord(csCompilingWaitFinish)] := @FinalizeCRC;
  Transition[Ord(csCompiledWaitCRC)] := @FinishUnit;
  Transition[Ord(csCompiled)] := @MarkProcessed;
end;

destructor TNXModule.Destroy;
begin
  FWorkspace.Free;
  FDefinition.Free;
  inherited Destroy;
end;

function TNXModule.RunPhase(
  APhase: TNXModulePhase
): TNXTransitionResult;
var
  PhaseWorkspace: TNXModulePhaseWorkspace;
begin
  PhaseWorkspace := FWorkspace.Phase[APhase];
  PhaseWorkspace.BeginWork;

  Result := ExecutePhase(APhase, PhaseWorkspace);

  if Result = trCompleted then
    PhaseWorkspace.CompleteWork;
end;

function TNXModule.ExecutePhase(
  APhase: TNXModulePhase;
  AWorkspace: TNXModulePhaseWorkspace
): TNXTransitionResult;
begin
  AWorkspace.Advance;
  Result := trCompleted;
end;

procedure TNXModule.BlockCurrentPhaseOn(
  AModule: TNXModule;
  ARequiredState: TNXCompileState
);
begin
  if AModule = nil then
    raise Exception.Create('AModule cannot be nil');

  BlockOn(AModule.WorkID, Ord(ARequiredState));
end;

function TNXModule.StartTokenizing: TNXTransitionResult;
var
  PhaseWorkspace: TNXModulePhaseWorkspace;
begin
  PhaseWorkspace := FWorkspace.Phase[nmpStartTokenizing];
  PhaseWorkspace.BeginWork;
  FWorkspace.StartTokenizer(FDefinition);
  PhaseWorkspace.Advance;
  PhaseWorkspace.CompleteWork;
  Result := trCompleted;
end;

function TNXModule.ContinueTokenizing: TNXTransitionResult;
var
  PhaseWorkspace: TNXModulePhaseWorkspace;
  Status: TNXTokenizeStatus;
begin
  PhaseWorkspace := FWorkspace.Phase[nmpContinueTokenizing];
  PhaseWorkspace.BeginWork;
  PhaseWorkspace.Advance;

  Status := FWorkspace.Tokenizer.Continue;
  if Status = tsBlocked then
    raise Exception.Create('Physical tokenization must not block');

  PhaseWorkspace.CompleteWork;
  Result := trCompleted;
end;

function TNXModule.ProcessConditionals: TNXTransitionResult;
var
  PhaseWorkspace: TNXModulePhaseWorkspace;
  Status: TNXConditionalProcessStatus;
  Blocker: TNXBlockInfo;
begin
  PhaseWorkspace := FWorkspace.Phase[nmpProcessConditionals];
  PhaseWorkspace.BeginWork;
  PhaseWorkspace.Advance;
  FWorkspace.StartConditionalProcessor;

  Status := FWorkspace.ConditionalProcessor.Continue;
  if Status = cpsBlocked then
  begin
    Blocker := FWorkspace.ConditionalProcessor.Blocked;
    if not Blocker.Assigned then
      raise Exception.Create(
        'Conditional processor blocked without identifying a work item'
      );

    BlockOn(Blocker.WorkID, Blocker.RequiredState);
    Exit(trBlocked);
  end;

  PhaseWorkspace.CompleteWork;
  Result := trCompleted;
end;

function TNXModule.ProcessProgramDeclarations: TNXTransitionResult;
begin
  Result := RunPhase(nmpProgramDeclarations);
end;

function TNXModule.ParseInterfaceDeclarations: TNXTransitionResult;
begin
  Result := RunPhase(nmpInterfaceDeclarations);
end;

function TNXModule.ProcessImplementation: TNXTransitionResult;
begin
  Result := RunPhase(nmpImplementation);
end;

function TNXModule.FinishCompile: TNXTransitionResult;
begin
  Result := RunPhase(nmpFinishCompile);
end;

function TNXModule.FinalizeCRC: TNXTransitionResult;
begin
  Result := RunPhase(nmpFinalizeCRC);
end;

function TNXModule.FinishUnit: TNXTransitionResult;
begin
  Result := RunPhase(nmpFinishUnit);
end;

function TNXModule.MarkProcessed: TNXTransitionResult;
begin
  Result := RunPhase(nmpMarkProcessed);
end;

procedure TNXModule.AddStateDependency(
  AFromState: TNXCompileState;
  AModule: TNXModule;
  ARequiredState: TNXCompileState
);
begin
  if AModule = nil then
    raise Exception.Create('AModule cannot be nil');

  StateMap.BlockOn(
    WorkID,
    Ord(AFromState),
    AModule.WorkID,
    Ord(ARequiredState)
  );
end;

procedure TNXModule.RequireTokenized(AModule: TNXModule);
begin
  AddStateDependency(csTokenized, AModule, csTokenized);
end;

procedure TNXModule.RequireProgramDeclarations(AModule: TNXModule);
begin
  AddStateDependency(csCompile, AModule, csCompilingWaitIntf);
end;

procedure TNXModule.RequireInterface(AModule: TNXModule);
begin
  AddStateDependency(csCompilingWait, AModule, csCompilingWaitIntf);
end;

procedure TNXModule.RequireImplementation(AModule: TNXModule);
begin
  AddStateDependency(csCompilingWaitIntf, AModule, csCompilingWaitIntf);
end;

procedure TNXModule.RequireFinish(AModule: TNXModule);
begin
  AddStateDependency(csCompilingWaitImpl, AModule, csCompilingWaitImpl);
end;

procedure TNXModule.RequireCRC(AModule: TNXModule);
begin
  AddStateDependency(csCompiledWaitCRC, AModule, csCompiledWaitCRC);
end;

function TNXModule.CloneDataValue(AData: Pointer): Pointer;
begin
  if AData = nil then
    Result := TNXModuleSnapshot.Create(FDefinition)
  else
    Result := TNXModuleSnapshot(AData).Clone;
end;

procedure TNXModule.FreeDataValue(AData: Pointer);
begin
  TObject(AData).Free;
end;

procedure TNXModule.Commit(
  ANewData: Pointer;
  ANewState: TNXWorkState
);
begin
  TNXModuleSnapshot(ANewData).UpdateFrom(
    FWorkspace,
    TNXCompileState(ANewState)
  );

  inherited Commit(ANewData, ANewState);
end;

function TNXModule.ClonePublished: TNXModuleSnapshot;
begin
  if not Started then
    Exit(nil);

  Result := TNXModuleSnapshot(CloneData);
end;

function TNXModule.WorkingPhase(
  APhase: TNXModulePhase
): TNXModulePhaseWorkspace;
begin
  Result := FWorkspace.Phase[APhase];
end;

end.
