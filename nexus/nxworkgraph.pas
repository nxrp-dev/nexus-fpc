unit nxworkgraph;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TNXWorkID = QWord;
  TNXWorkState = Integer;
  TNXWorkItem = class;
  TNXStateMap = class;

  TNXTransitionResult = (trCompleted, trBlocked);
  TNXWorkResult = (wrCompleted, wrBlocked);
  TNXTransitionMethod = function: TNXTransitionResult of object;

  TNXStateEntry = class
  private
    FWorkID: TNXWorkID;
    FIdentity: string;
    FState: TNXWorkState;
  public
    constructor Create(AWorkID: TNXWorkID; const AIdentity: string;
      AInitialState: TNXWorkState);
    property WorkID: TNXWorkID read FWorkID;
    property Identity: string read FIdentity;
    property State: TNXWorkState read FState write FState;
  end;

  TNXStateBlocker = class
  private
    FWorkID: TNXWorkID;
    FFromState: TNXWorkState;
    FBlockingWorkID: TNXWorkID;
    FRequiredState: TNXWorkState;
  public
    constructor Create(AWorkID: TNXWorkID; AFromState: TNXWorkState;
      ABlockingWorkID: TNXWorkID; ARequiredState: TNXWorkState);
    property WorkID: TNXWorkID read FWorkID;
    property FromState: TNXWorkState read FFromState;
    property BlockingWorkID: TNXWorkID read FBlockingWorkID;
    property RequiredState: TNXWorkState read FRequiredState;
  end;

  TNXStateMap = class
  private
    FStates: array of TNXStateEntry;
    FBlockers: array of TNXStateBlocker;

    function FindState(AWorkID: TNXWorkID): TNXStateEntry;
    function FindBlocker(
      AWorkID: TNXWorkID;
      AFromState: TNXWorkState;
      ABlockingWorkID: TNXWorkID;
      ARequiredState: TNXWorkState
    ): TNXStateBlocker;
  public
    destructor Destroy; override;

    function GetWorkID(const AIdentity: string): TNXWorkID;

    procedure RegisterWork(
      AWorkID: TNXWorkID;
      const AIdentity: string;
      AInitialState: TNXWorkState
    ); overload;
    procedure RegisterWork(
      const AIdentity: string;
      AInitialState: TNXWorkState
    ); overload;

    function GetState(AWorkID: TNXWorkID): TNXWorkState; overload;
    function GetState(const AIdentity: string): TNXWorkState; overload;

    procedure TransitionTo(
      AWorkID: TNXWorkID;
      AState: TNXWorkState
    ); overload;
    procedure TransitionTo(
      const AIdentity: string;
      AState: TNXWorkState
    ); overload;

    procedure BlockOn(
      AWorkID: TNXWorkID;
      AFromState: TNXWorkState;
      ABlockingWorkID: TNXWorkID;
      ARequiredState: TNXWorkState
    ); overload;
    procedure BlockOn(
      const AIdentity: string;
      AFromState: TNXWorkState;
      const ABlockingIdentity: string;
      ARequiredState: TNXWorkState
    ); overload;

    function CanAdvance(
      AWorkID: TNXWorkID;
      AFromState: TNXWorkState;
      out ABlockingWorkID: TNXWorkID
    ): Boolean; overload;
    function CanAdvance(
      const AIdentity: string;
      AFromState: TNXWorkState;
      out ABlockingWorkID: TNXWorkID
    ): Boolean; overload;
  end;

  TNXWorkItem = class
  private
    FIdentity: string;
    FWorkID: TNXWorkID;
    FStateMap: TNXStateMap;
    FInitialState: TNXWorkState;
    FFinalState: TNXWorkState;
    FTransitions: array of TNXTransitionMethod;
    FBlockedBy: TNXWorkID;
    FData: Pointer;

    function GetState: TNXWorkState;
    function GetTransition(AState: TNXWorkState): TNXTransitionMethod;
    procedure SetTransition(AState: TNXWorkState; AMethod: TNXTransitionMethod);
  protected
    procedure BlockOn(
      ABlockingWorkID: TNXWorkID;
      ARequiredState: TNXWorkState
    );

    procedure BeginDataRead; virtual;
    procedure EndDataRead; virtual;
    procedure BeginDataWrite; virtual;
    procedure EndDataWrite; virtual;

    function CloneDataValue(AData: Pointer): Pointer; virtual; abstract;
    procedure FreeDataValue(AData: Pointer); virtual; abstract;

    procedure Commit(
      ANewData: Pointer;
      ANewState: TNXWorkState
    ); virtual;
  public
    constructor Create(
      AStateMap: TNXStateMap;
      const AIdentity: string;
      AInitialState: TNXWorkState;
      AFinalState: TNXWorkState
    );
    destructor Destroy; override;

    function BeginReadData: Pointer;
    procedure EndReadData;
    function CloneData: Pointer;

    function Started: Boolean;
    function Completed: Boolean;
    function CanAdvance: Boolean;
    function Process: TNXWorkResult;

    property Identity: string read FIdentity;
    property WorkID: TNXWorkID read FWorkID;
    property State: TNXWorkState read GetState;
    property InitialState: TNXWorkState read FInitialState;
    property FinalState: TNXWorkState read FFinalState;
    property BlockedBy: TNXWorkID read FBlockedBy;
    property StateMap: TNXStateMap read FStateMap;

    property Transition[AState: TNXWorkState]: TNXTransitionMethod
      read GetTransition write SetTransition;
  end;

  TNXBlockedWork = class
  private
    FWork: TNXWorkItem;
    FBlockingWorkID: TNXWorkID;
  public
    constructor Create(AWork: TNXWorkItem; ABlockingWorkID: TNXWorkID);
    property Work: TNXWorkItem read FWork;
    property BlockingWorkID: TNXWorkID read FBlockingWorkID;
  end;

  TNXAssignment = class
  private
    FStateMap: TNXStateMap;
    FQueued: array of TNXWorkItem;
    FBlocked: array of TNXBlockedWork;
    function FindQueued(AWork: TNXWorkItem): Integer;
    function FindBlocked(AWork: TNXWorkItem): Integer;
    function BlockingPriority(AWorkID: TNXWorkID): Integer;
    procedure RemoveQueued(AIndex: Integer);
    procedure RemoveBlocked(AIndex: Integer);
    procedure RefreshBlocked;
  public
    constructor Create(AStateMap: TNXStateMap);
    destructor Destroy; override;

    procedure Add(AWork: TNXWorkItem);
    function Next(out AWork: TNXWorkItem): Boolean;
    procedure ReturnWork(AWork: TNXWorkItem; AResult: TNXWorkResult);

    function QueuedCount: Integer;
    function BlockedCount: Integer;
  end;

  { Legacy compiler example

    This example predates NXLR-0001 and is retained only because
    TNXCompileState is still shared with TNXModule. Its tokenizer/directive
    comments and TNXCompileUnit behavior are not the current frontend design.
    TNXModule, TNXTokenizer and TNXConditionalProcessor are authoritative.

    The compiler work flow is intentionally linear.  Each state represents
    completed progress, except for csTokenizing which is explicitly resumable.

    Tokenization rules:

      * Directives are consumed by tokenization and do not become parser tokens.
      * Includes are expanded by the tokenizer into one logical token stream.
      * Most directives can be resolved immediately from tokenizer/compiler
        configuration state.
      * A semantic directive such as SizeOf(SomeType) may require information
        that has not yet been published by another compilation work item.
      * In that case tokenization MUST NOT throw away work already performed.
        The tokenizer retains its current token buffer plus enough operational
        state to resume later, records the blocker, and returns.
      * Partial tokenization is operational data and is not published to
        consumers.  csTokenizing therefore means "tokenization is in progress
        and may be resumed".  Consumers normally depend on csTokenized, which
        means the complete immutable token stream has been committed.

    This keeps "paused" or "blocked" out of the state enum.  Blocking is an
    assignment/state-map concern, not semantic progress.

    After tokenization, the remaining states mirror the important dependency
    barriers in FPC's ctask/pmodules source-compilation path:

      csCompile
        -> compile-module entry

      csCompilingWait
        -> equivalent to usedunitsloaded(true)

      csCompilingWaitIntf
        -> equivalent to usedunitsloaded(true)

      csCompilingWaitImpl
        -> equivalent to usedunitsloaded(false)

      csCompilingWaitFinish
        -> equivalent to nowaitingforunits()

      csCompiledWaitCRC
        -> equivalent to usedunitsfinalcrc()

    PPU loading/recompile/error recovery are intentionally not modeled here.
    They are alternate work paths and should not force branching semantics into
    this deliberately linear source-compilation example.
  }

  TNXCompileState = (
    csNotStarted,
    csTokenizing,
    csTokenized,
    csCompile,
    csCompilingWait,
    csCompilingWaitIntf,
    csCompilingWaitImpl,
    csCompilingWaitFinish,
    csCompiledWaitCRC,
    csCompiled,
    csProcessed
  );

  TNXToken = record
    TokenType: Word;
    Variant: Word;
    Value: LongWord;
    Source: LongWord;
  end;

  TNXTokenBuffer = array of TNXToken;

  TNXTokenizerState = class
  public
    Tokens: TNXTokenBuffer;

    { These fields represent the minimum kind of state that must survive a
      semantic-directive blocker.  The real compiler implementation will
      replace/expand these placeholders with its actual source/include,
      directive/conditional, mode/settings and source-position state. }
    SourcePosition: LongWord;
    IncludeDepth: Integer;
    DirectiveDepth: Integer;

    function Clone: TNXTokenizerState; virtual;
  end;

  TNXPublishedUnit = class
  public
    Tokenizer: TNXTokenizerState;

    constructor Create;
    destructor Destroy; override;

    procedure UpdateFrom(AWorkingUnit: TObject); virtual;
    function Clone: TNXPublishedUnit; virtual;
  end;

  TNXWorkingUnit = class
  public
    Tokenizer: TNXTokenizerState;

    constructor Create;
    destructor Destroy; override;
  end;

  TNXCompileUnit = class(TNXWorkItem)
  private
    FPublished: TNXPublishedUnit;
    FWorking: TNXWorkingUnit;

    function StartTokenizing: TNXTransitionResult;
    function ContinueTokenizing: TNXTransitionResult;
    function BeginCompile: TNXTransitionResult;
    function ProcessProgramDeclarations: TNXTransitionResult;
    function ParseInterfaceDeclarations: TNXTransitionResult;
    function ProcessImplementation: TNXTransitionResult;
    function FinishCompile: TNXTransitionResult;
    function FinalizeCRC: TNXTransitionResult;
    function FinishUnit: TNXTransitionResult;
    function MarkProcessed: TNXTransitionResult;
  protected
    function CloneDataValue(AData: Pointer): Pointer; override;
    procedure FreeDataValue(AData: Pointer); override;
    procedure Commit(
      ANewData: Pointer;
      ANewState: TNXWorkState
    ); override;
  public
    constructor Create(
      AStateMap: TNXStateMap;
      const AUnitIdentity: string
    );
    destructor Destroy; override;

    { Called when tokenization reaches a semantic directive that requires
      another work item to have published sufficient semantic state.

      The tokenizer keeps its current token buffer and resumable tokenizer
      state as private operational data.  Nothing partial is published.  The
      work item remains csTokenizing and will later continue from that saved
      point instead of restarting from source position zero. }
    procedure BlockTokenizingOn(
      AUnit: TNXCompileUnit;
      ARequiredState: TNXCompileState
    );

    { Normal consumers should depend on this milestone, not csTokenizing. }
    procedure BlockOnTokenized(AUnit: TNXCompileUnit);

    procedure BlockProgramDeclarationsOn(AUnit: TNXCompileUnit);
    procedure BlockInterfaceOn(AUnit: TNXCompileUnit);
    procedure BlockImplementationOn(AUnit: TNXCompileUnit);
    procedure BlockFinishOn(AUnit: TNXCompileUnit);
    procedure BlockCRCOn(AUnit: TNXCompileUnit);

    property Published: TNXPublishedUnit read FPublished;
    property Working: TNXWorkingUnit read FWorking;
  end;

function GetWorkID(const AIdentity: string): TNXWorkID;

implementation

{$push}
{$Q-}
function GetWorkID(const AIdentity: string): TNXWorkID;
const
  FNVOffsetBasis: QWord = QWord($CBF29CE484222325);
  FNVPrime: QWord = QWord($00000100000001B3);
var
  Data: RawByteString;
  I: Integer;
begin
  Data := UTF8Encode(AIdentity);
  Result := FNVOffsetBasis;
  for I := 1 to Length(Data) do
  begin
    Result := Result xor Byte(Data[I]);
    Result := Result * FNVPrime;
  end;
  if Result = 0 then
    Result := 1;
end;
{$pop}

constructor TNXStateEntry.Create(AWorkID: TNXWorkID; const AIdentity: string;
  AInitialState: TNXWorkState);
begin
  inherited Create;
  FWorkID := AWorkID;
  FIdentity := AIdentity;
  FState := AInitialState;
end;

constructor TNXStateBlocker.Create(AWorkID: TNXWorkID;
  AFromState: TNXWorkState; ABlockingWorkID: TNXWorkID;
  ARequiredState: TNXWorkState);
begin
  inherited Create;
  FWorkID := AWorkID;
  FFromState := AFromState;
  FBlockingWorkID := ABlockingWorkID;
  FRequiredState := ARequiredState;
end;

destructor TNXStateMap.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FBlockers) do
    FBlockers[I].Free;

  for I := 0 to High(FStates) do
    FStates[I].Free;

  inherited Destroy;
end;

function TNXStateMap.GetWorkID(const AIdentity: string): TNXWorkID;
begin
  Result := nxworkgraph.GetWorkID(AIdentity);
end;

function TNXStateMap.FindState(AWorkID: TNXWorkID): TNXStateEntry;
var
  I: Integer;
begin
  for I := 0 to High(FStates) do
    if FStates[I].WorkID = AWorkID then
      Exit(FStates[I]);

  Result := nil;
end;

function TNXStateMap.FindBlocker(
  AWorkID: TNXWorkID;
  AFromState: TNXWorkState;
  ABlockingWorkID: TNXWorkID;
  ARequiredState: TNXWorkState
): TNXStateBlocker;
var
  I: Integer;
  Blocker: TNXStateBlocker;
begin
  for I := 0 to High(FBlockers) do
  begin
    Blocker := FBlockers[I];

    if
      (Blocker.WorkID = AWorkID) and
      (Blocker.FromState = AFromState) and
      (Blocker.BlockingWorkID = ABlockingWorkID) and
      (Blocker.RequiredState = ARequiredState)
    then
      Exit(Blocker);
  end;

  Result := nil;
end;

procedure TNXStateMap.RegisterWork(
  AWorkID: TNXWorkID;
  const AIdentity: string;
  AInitialState: TNXWorkState
);
var
  Entry: TNXStateEntry;
  Index: Integer;
begin
  Entry := FindState(AWorkID);

  if Entry <> nil then
  begin
    if Entry.Identity <> AIdentity then
      raise Exception.CreateFmt(
        'Work ID collision between "%s" and "%s"',
        [Entry.Identity, AIdentity]
      );

    Exit;
  end;

  Index := Length(FStates);
  SetLength(FStates, Index + 1);

  FStates[Index] := TNXStateEntry.Create(
    AWorkID,
    AIdentity,
    AInitialState
  );
end;

procedure TNXStateMap.RegisterWork(
  const AIdentity: string;
  AInitialState: TNXWorkState
);
begin
  RegisterWork(
    GetWorkID(AIdentity),
    AIdentity,
    AInitialState
  );
end;

function TNXStateMap.GetState(AWorkID: TNXWorkID): TNXWorkState;
var
  Entry: TNXStateEntry;
begin
  Entry := FindState(AWorkID);

  if Entry = nil then
    raise Exception.CreateFmt(
      'Unknown work ID %u',
      [AWorkID]
    );

  Result := Entry.State;
end;

function TNXStateMap.GetState(const AIdentity: string): TNXWorkState;
begin
  Result := GetState(GetWorkID(AIdentity));
end;

procedure TNXStateMap.TransitionTo(
  AWorkID: TNXWorkID;
  AState: TNXWorkState
);
var
  Entry: TNXStateEntry;
begin
  Entry := FindState(AWorkID);

  if Entry = nil then
    raise Exception.CreateFmt(
      'Unknown work ID %u',
      [AWorkID]
    );

  if AState <> Entry.State + 1 then
    raise Exception.CreateFmt(
      'Linear work state must advance exactly one state (%d -> %d)',
      [Entry.State, AState]
    );

  Entry.State := AState;
end;

procedure TNXStateMap.TransitionTo(
  const AIdentity: string;
  AState: TNXWorkState
);
begin
  TransitionTo(
    GetWorkID(AIdentity),
    AState
  );
end;

procedure TNXStateMap.BlockOn(
  AWorkID: TNXWorkID;
  AFromState: TNXWorkState;
  ABlockingWorkID: TNXWorkID;
  ARequiredState: TNXWorkState
);
var
  Index: Integer;
begin
  if FindBlocker(
    AWorkID,
    AFromState,
    ABlockingWorkID,
    ARequiredState
  ) <> nil then
    Exit;

  Index := Length(FBlockers);
  SetLength(FBlockers, Index + 1);

  FBlockers[Index] := TNXStateBlocker.Create(
    AWorkID,
    AFromState,
    ABlockingWorkID,
    ARequiredState
  );
end;

procedure TNXStateMap.BlockOn(
  const AIdentity: string;
  AFromState: TNXWorkState;
  const ABlockingIdentity: string;
  ARequiredState: TNXWorkState
);
begin
  BlockOn(
    GetWorkID(AIdentity),
    AFromState,
    GetWorkID(ABlockingIdentity),
    ARequiredState
  );
end;

function TNXStateMap.CanAdvance(
  AWorkID: TNXWorkID;
  AFromState: TNXWorkState;
  out ABlockingWorkID: TNXWorkID
): Boolean;
var
  I: Integer;
  Blocker: TNXStateBlocker;
  BlockingState: TNXStateEntry;
begin
  ABlockingWorkID := 0;

  for I := 0 to High(FBlockers) do
  begin
    Blocker := FBlockers[I];

    if
      (Blocker.WorkID <> AWorkID) or
      (Blocker.FromState <> AFromState)
    then
      Continue;

    BlockingState := FindState(Blocker.BlockingWorkID);

    if
      (BlockingState = nil) or
      (BlockingState.State < Blocker.RequiredState)
    then
    begin
      ABlockingWorkID := Blocker.BlockingWorkID;
      Exit(False);
    end;
  end;

  Result := True;
end;

function TNXStateMap.CanAdvance(
  const AIdentity: string;
  AFromState: TNXWorkState;
  out ABlockingWorkID: TNXWorkID
): Boolean;
begin
  Result := CanAdvance(
    GetWorkID(AIdentity),
    AFromState,
    ABlockingWorkID
  );
end;

constructor TNXWorkItem.Create(AStateMap: TNXStateMap;
  const AIdentity: string; AInitialState, AFinalState: TNXWorkState);
begin
  inherited Create;

  if AStateMap = nil then
    raise Exception.Create('AStateMap cannot be nil');
  if AFinalState < AInitialState then
    raise Exception.Create('Final state cannot precede initial state');

  FStateMap := AStateMap;
  FIdentity := AIdentity;
  FWorkID := FStateMap.GetWorkID(AIdentity);
  FInitialState := AInitialState;
  FFinalState := AFinalState;

  SetLength(FTransitions, FFinalState - FInitialState);

  FStateMap.RegisterWork(
    FWorkID,
    FIdentity,
    FInitialState
  );
end;

function TNXWorkItem.GetState: TNXWorkState;
begin
  Result := FStateMap.GetState(FWorkID);
end;

function TNXWorkItem.GetTransition(
  AState: TNXWorkState
): TNXTransitionMethod;
var
  Index: Integer;
begin
  Index := AState - FInitialState;

  if (Index < 0) or (Index >= Length(FTransitions)) then
    Exit(nil);

  Result := FTransitions[Index];
end;

procedure TNXWorkItem.SetTransition(
  AState: TNXWorkState;
  AMethod: TNXTransitionMethod
);
var
  Index: Integer;
begin
  Index := AState - FInitialState;

  if (Index < 0) or (Index >= Length(FTransitions)) then
    raise ERangeError.CreateFmt(
      'State %d does not have an outbound transition',
      [AState]
    );

  FTransitions[Index] := AMethod;
end;

procedure TNXWorkItem.BlockOn(
  ABlockingWorkID: TNXWorkID;
  ARequiredState: TNXWorkState
);
begin
  FBlockedBy := ABlockingWorkID;

  FStateMap.BlockOn(
    FWorkID,
    State,
    ABlockingWorkID,
    ARequiredState
  );
end;

procedure TNXWorkItem.BeginDataRead;
begin
end;

procedure TNXWorkItem.EndDataRead;
begin
end;

procedure TNXWorkItem.BeginDataWrite;
begin
end;

procedure TNXWorkItem.EndDataWrite;
begin
end;

destructor TNXWorkItem.Destroy;
begin
  if FData <> nil then
    FreeDataValue(FData);

  inherited Destroy;
end;

function TNXWorkItem.BeginReadData: Pointer;
begin
  BeginDataRead;
  Result := FData;
end;

procedure TNXWorkItem.EndReadData;
begin
  EndDataRead;
end;

function TNXWorkItem.CloneData: Pointer;
begin
  BeginDataRead;
  try
    Result := CloneDataValue(FData);
  finally
    EndDataRead;
  end;
end;

procedure TNXWorkItem.Commit(
  ANewData: Pointer;
  ANewState: TNXWorkState
);
var
  OldData: Pointer;
begin
  BeginDataWrite;
  try
    OldData := FData;
    FData := ANewData;
    FStateMap.TransitionTo(
      FWorkID,
      ANewState
    );
  finally
    EndDataWrite;
  end;

  if OldData <> nil then
    FreeDataValue(OldData);
end;

function TNXWorkItem.Started: Boolean;
begin
  Result := State > FInitialState;
end;

function TNXWorkItem.Completed: Boolean;
begin
  Result := State = FFinalState;
end;

function TNXWorkItem.CanAdvance: Boolean;
var
  BlockingWorkID: TNXWorkID;
begin
  if Completed then
    Exit(False);

  if not Assigned(Transition[State]) then
    Exit(False);

  Result := FStateMap.CanAdvance(
    FWorkID,
    State,
    BlockingWorkID
  );
end;

function TNXWorkItem.Process: TNXWorkResult;
var
  Method: TNXTransitionMethod;
  BlockingWorkID: TNXWorkID;
  WorkingData: Pointer;
begin
  FBlockedBy := 0;

  while not Completed do
  begin
    if not FStateMap.CanAdvance(
      FWorkID,
      State,
      BlockingWorkID
    ) then
    begin
      FBlockedBy := BlockingWorkID;
      Exit(wrBlocked);
    end;

    Method := Transition[State];

    if not Assigned(Method) then
      raise Exception.CreateFmt(
        'No transition method is registered for state %d',
        [State]
      );

    WorkingData := CloneData;
    try
      if Method() = trBlocked then
      begin
        if FBlockedBy = 0 then
          raise Exception.Create(
            'Transition reported blocked without identifying a blocker'
          );

        Exit(wrBlocked);
      end;

      Commit(
        WorkingData,
        State + 1
      );
      WorkingData := nil;
    finally
      if WorkingData <> nil then
        FreeDataValue(WorkingData);
    end;

    FBlockedBy := 0;
  end;

  Result := wrCompleted;
end;

constructor TNXBlockedWork.Create(AWork: TNXWorkItem;
  ABlockingWorkID: TNXWorkID);
begin
  inherited Create;
  FWork := AWork;
  FBlockingWorkID := ABlockingWorkID;
end;

constructor TNXAssignment.Create(AStateMap: TNXStateMap);
begin
  inherited Create;
  if AStateMap = nil then
    raise Exception.Create('AStateMap cannot be nil');
  FStateMap := AStateMap;
end;

destructor TNXAssignment.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FBlocked) do
    FBlocked[I].Free;
  inherited Destroy;
end;

function TNXAssignment.FindQueued(AWork: TNXWorkItem): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FQueued) do
    if FQueued[I] = AWork then
      Exit(I);
  Result := -1;
end;

function TNXAssignment.FindBlocked(AWork: TNXWorkItem): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FBlocked) do
    if FBlocked[I].Work = AWork then
      Exit(I);
  Result := -1;
end;

function TNXAssignment.BlockingPriority(AWorkID: TNXWorkID): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(FBlocked) do
    if FBlocked[I].BlockingWorkID = AWorkID then
      Inc(Result);
end;

procedure TNXAssignment.RemoveQueued(AIndex: Integer);
var
  I: Integer;
begin
  for I := AIndex to High(FQueued) - 1 do
    FQueued[I] := FQueued[I + 1];
  SetLength(FQueued, Length(FQueued) - 1);
end;

procedure TNXAssignment.RemoveBlocked(AIndex: Integer);
var
  I: Integer;
begin
  FBlocked[AIndex].Free;
  for I := AIndex to High(FBlocked) - 1 do
    FBlocked[I] := FBlocked[I + 1];
  SetLength(FBlocked, Length(FBlocked) - 1);
end;

procedure TNXAssignment.RefreshBlocked;
var
  I: Integer;
  Work: TNXWorkItem;
begin
  I := 0;
  while I < Length(FBlocked) do
  begin
    Work := FBlocked[I].Work;
    if Work.CanAdvance then
    begin
      RemoveBlocked(I);
      Add(Work);
    end
    else
      Inc(I);
  end;
end;

procedure TNXAssignment.Add(AWork: TNXWorkItem);
var
  Index: Integer;
begin
  if AWork = nil then
    raise Exception.Create('AWork cannot be nil');
  if AWork.Completed then
    Exit;
  if FindQueued(AWork) >= 0 then
    Exit;
  if FindBlocked(AWork) >= 0 then
    Exit;

  Index := Length(FQueued);
  SetLength(FQueued, Index + 1);
  FQueued[Index] := AWork;
end;

function TNXAssignment.Next(out AWork: TNXWorkItem): Boolean;
var
  I: Integer;
  BestIndex: Integer;
  BestPriority: Integer;
  Priority: Integer;
begin
  RefreshBlocked;

  AWork := nil;
  BestIndex := -1;
  BestPriority := -1;

  for I := 0 to High(FQueued) do
  begin
    Priority := BlockingPriority(FQueued[I].WorkID);
    if Priority > BestPriority then
    begin
      BestPriority := Priority;
      BestIndex := I;
    end;
  end;

  if BestIndex < 0 then
    Exit(False);

  AWork := FQueued[BestIndex];
  RemoveQueued(BestIndex);
  Result := True;
end;

procedure TNXAssignment.ReturnWork(AWork: TNXWorkItem;
  AResult: TNXWorkResult);
var
  Index: Integer;
begin
  if AWork = nil then
    raise Exception.Create('AWork cannot be nil');

  case AResult of
    wrCompleted:
      Exit;

    wrBlocked:
      begin
        if AWork.BlockedBy = 0 then
          raise Exception.Create(
            'Blocked work does not identify its blocker'
          );

        if FindBlocked(AWork) >= 0 then
          Exit;

        Index := Length(FBlocked);
        SetLength(FBlocked, Index + 1);
        FBlocked[Index] := TNXBlockedWork.Create(
          AWork, AWork.BlockedBy
        );
      end;
  end;
end;

function TNXAssignment.QueuedCount: Integer;
begin
  Result := Length(FQueued);
end;

function TNXAssignment.BlockedCount: Integer;
begin
  Result := Length(FBlocked);
end;

function TNXTokenizerState.Clone: TNXTokenizerState;
begin
  Result := TNXTokenizerState.Create;
  Result.Tokens := Copy(Tokens);
  Result.SourcePosition := SourcePosition;
  Result.IncludeDepth := IncludeDepth;
  Result.DirectiveDepth := DirectiveDepth;
end;

constructor TNXPublishedUnit.Create;
begin
  inherited Create;
  Tokenizer := TNXTokenizerState.Create;
end;

destructor TNXPublishedUnit.Destroy;
begin
  Tokenizer.Free;
  inherited Destroy;
end;

procedure TNXPublishedUnit.UpdateFrom(AWorkingUnit: TObject);
var
  WorkingUnit: TNXWorkingUnit;
begin
  if not (AWorkingUnit is TNXWorkingUnit) then
    Exit;

  WorkingUnit := TNXWorkingUnit(AWorkingUnit);

  Tokenizer.Free;
  Tokenizer := WorkingUnit.Tokenizer.Clone;
end;

function TNXPublishedUnit.Clone: TNXPublishedUnit;
begin
  Result := TNXPublishedUnit.Create;

  Result.Tokenizer.Free;
  Result.Tokenizer := Tokenizer.Clone;
end;

constructor TNXWorkingUnit.Create;
begin
  inherited Create;
  Tokenizer := TNXTokenizerState.Create;
end;

destructor TNXWorkingUnit.Destroy;
begin
  Tokenizer.Free;
  inherited Destroy;
end;

constructor TNXCompileUnit.Create(
  AStateMap: TNXStateMap;
  const AUnitIdentity: string
);
begin
  inherited Create(
    AStateMap,
    AUnitIdentity,
    Ord(Low(TNXCompileState)),
    Ord(High(TNXCompileState))
  );

  FPublished := nil;
  FWorking := TNXWorkingUnit.Create;

  { csNotStarted -> csTokenizing establishes resumable tokenizer state. }
  Transition[Ord(csNotStarted)] := @StartTokenizing;

  { csTokenizing -> csTokenized may run more than once operationally.
    If a semantic directive blocks, the work item remains csTokenizing.
    Once the entire effective token stream is complete, the transition
    succeeds and the published state advances to csTokenized. }
  Transition[Ord(csTokenizing)] := @ContinueTokenizing;

  Transition[Ord(csTokenized)] := @BeginCompile;
  Transition[Ord(csCompile)] := @ProcessProgramDeclarations;
  Transition[Ord(csCompilingWait)] := @ParseInterfaceDeclarations;
  Transition[Ord(csCompilingWaitIntf)] := @ProcessImplementation;
  Transition[Ord(csCompilingWaitImpl)] := @FinishCompile;
  Transition[Ord(csCompilingWaitFinish)] := @FinalizeCRC;
  Transition[Ord(csCompiledWaitCRC)] := @FinishUnit;
  Transition[Ord(csCompiled)] := @MarkProcessed;
end;

destructor TNXCompileUnit.Destroy;
begin
  FWorking.Free;
  inherited Destroy;
end;

procedure TNXCompileUnit.BlockTokenizingOn(
  AUnit: TNXCompileUnit;
  ARequiredState: TNXCompileState
);
begin
  if AUnit = nil then
    raise Exception.Create('AUnit cannot be nil');

  { Resumable tokenizer data already lives in FWorking and survives release
    of the worker.  BlockOn records only the scheduling/dependency relationship.
    State remains csTokenizing and no partial token data is published. }
  BlockOn(
    AUnit.WorkID,
    Ord(ARequiredState)
  );
end;

procedure TNXCompileUnit.BlockOnTokenized(AUnit: TNXCompileUnit);
begin
  if AUnit = nil then
    raise Exception.Create('AUnit cannot be nil');

  StateMap.BlockOn(
    WorkID,
    State,
    AUnit.WorkID,
    Ord(csTokenized)
  );
end;

procedure TNXCompileUnit.BlockProgramDeclarationsOn(AUnit: TNXCompileUnit);
begin
  if AUnit = nil then
    raise Exception.Create('AUnit cannot be nil');

  StateMap.BlockOn(
    WorkID,
    Ord(csCompile),
    AUnit.WorkID,
    Ord(csCompilingWaitIntf)
  );
end;

procedure TNXCompileUnit.BlockInterfaceOn(AUnit: TNXCompileUnit);
begin
  if AUnit = nil then
    raise Exception.Create('AUnit cannot be nil');

  StateMap.BlockOn(
    WorkID,
    Ord(csCompilingWait),
    AUnit.WorkID,
    Ord(csCompilingWaitIntf)
  );
end;

procedure TNXCompileUnit.BlockImplementationOn(AUnit: TNXCompileUnit);
begin
  if AUnit = nil then
    raise Exception.Create('AUnit cannot be nil');

  StateMap.BlockOn(
    WorkID,
    Ord(csCompilingWaitIntf),
    AUnit.WorkID,
    Ord(csCompilingWaitIntf)
  );
end;

procedure TNXCompileUnit.BlockFinishOn(AUnit: TNXCompileUnit);
begin
  if AUnit = nil then
    raise Exception.Create('AUnit cannot be nil');

  StateMap.BlockOn(
    WorkID,
    Ord(csCompilingWaitImpl),
    AUnit.WorkID,
    Ord(csCompilingWaitImpl)
  );
end;

procedure TNXCompileUnit.BlockCRCOn(AUnit: TNXCompileUnit);
begin
  if AUnit = nil then
    raise Exception.Create('AUnit cannot be nil');

  StateMap.BlockOn(
    WorkID,
    Ord(csCompiledWaitCRC),
    AUnit.WorkID,
    Ord(csCompiledWaitCRC)
  );
end;

function TNXCompileUnit.StartTokenizing: TNXTransitionResult;
begin
  { Real implementation will initialize the tokenizer from source and perform
    as much work as convenient before entering the resumable tokenizing state. }
  Result := trCompleted;
end;

function TNXCompileUnit.ContinueTokenizing: TNXTransitionResult;
begin
  { Placeholder for the real tokenizer.

    Intended behavior:

      while source remains do
        tokenize
        process directives immediately
        expand includes through the tokenizer source stack

        if a semantic directive cannot yet be resolved then
        begin
          retain current token buffer and tokenizer resume state in FWorking
          BlockTokenizingOn(...)
          Exit(trBlocked)
        end

      Result := trCompleted

    trCompleted is the only result that advances csTokenizing -> csTokenized.
    trBlocked leaves the work item in csTokenizing so it can resume later.
  }
  Result := trCompleted;
end;

function TNXCompileUnit.BeginCompile: TNXTransitionResult;
begin
  Result := trCompleted;
end;

function TNXCompileUnit.ProcessProgramDeclarations: TNXTransitionResult;
begin
  Result := trCompleted;
end;

function TNXCompileUnit.ParseInterfaceDeclarations: TNXTransitionResult;
begin
  Result := trCompleted;
end;

function TNXCompileUnit.ProcessImplementation: TNXTransitionResult;
begin
  Result := trCompleted;
end;

function TNXCompileUnit.FinishCompile: TNXTransitionResult;
begin
  Result := trCompleted;
end;

function TNXCompileUnit.FinalizeCRC: TNXTransitionResult;
begin
  Result := trCompleted;
end;

function TNXCompileUnit.FinishUnit: TNXTransitionResult;
begin
  Result := trCompleted;
end;

function TNXCompileUnit.MarkProcessed: TNXTransitionResult;
begin
  Result := trCompleted;
end;

function TNXCompileUnit.CloneDataValue(AData: Pointer): Pointer;
begin
  if AData = nil then
    Result := TNXPublishedUnit.Create
  else
    Result := TNXPublishedUnit(AData).Clone;
end;

procedure TNXCompileUnit.FreeDataValue(AData: Pointer);
begin
  TObject(AData).Free;
end;

procedure TNXCompileUnit.Commit(
  ANewData: Pointer;
  ANewState: TNXWorkState
);
begin
  TNXPublishedUnit(ANewData).UpdateFrom(FWorking);
  FPublished := TNXPublishedUnit(ANewData);

  inherited Commit(
    ANewData,
    ANewState
  );
end;

end.
