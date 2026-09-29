unit nxworkgraph;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TNXWorkState = Integer;
  TNXTransitionID = Integer;

  TNXWorkItem = class;

  TNXTransitionMethod = procedure of object;

  TNXDependency = class
  private
    FWorkItem: TNXWorkItem;
    FRequiredState: TNXWorkState;
  public
    constructor Create(AWorkItem: TNXWorkItem; ARequiredState: TNXWorkState);

    function Satisfied: Boolean;

    property WorkItem: TNXWorkItem read FWorkItem;
    property RequiredState: TNXWorkState read FRequiredState;
  end;

  TNXTransition = class
  private
    FID: TNXTransitionID;
    FFromState: TNXWorkState;
    FToState: TNXWorkState;
    FMethod: TNXTransitionMethod;
  public
    constructor Create(
      AID: TNXTransitionID;
      AFromState: TNXWorkState;
      AToState: TNXWorkState;
      AMethod: TNXTransitionMethod
    );

    procedure Execute;

    property ID: TNXTransitionID read FID;
    property FromState: TNXWorkState read FFromState;
    property ToState: TNXWorkState read FToState;
  end;

  TNXWorkItem = class
  private
    FState: TNXWorkState;
    FInitialState: TNXWorkState;
    FFinalState: TNXWorkState;
    FDependencies: array of TNXDependency;
    FTransitions: array of TNXTransition;

    function GetDependency(AIndex: Integer): TNXDependency;
    function GetDependencyCount: Integer;
    function GetTransition(AIndex: Integer): TNXTransition;
    function GetTransitionCount: Integer;
    function DependenciesSatisfied: Boolean;
    function FindTransition(AFromState: TNXWorkState): TNXTransition;
  protected
    constructor Create(
      AInitialState: TNXWorkState;
      AFinalState: TNXWorkState
    );

    procedure AddDependency(
      AWorkItem: TNXWorkItem;
      ARequiredState: TNXWorkState
    );

    procedure RegisterTransition(
      AID: TNXTransitionID;
      AFromState: TNXWorkState;
      AToState: TNXWorkState;
      AMethod: TNXTransitionMethod
    );

    procedure Commit(AState: TNXWorkState); virtual;
  public
    destructor Destroy; override;

    function Ready: Boolean;
    function Started: Boolean;
    function Completed: Boolean;
    function Advance: Boolean;

    property State: TNXWorkState read FState;
    property InitialState: TNXWorkState read FInitialState;
    property FinalState: TNXWorkState read FFinalState;

    property DependencyCount: Integer read GetDependencyCount;
    property Dependencies[AIndex: Integer]: TNXDependency read GetDependency;

    property TransitionCount: Integer read GetTransitionCount;
    property Transitions[AIndex: Integer]: TNXTransition read GetTransition;
  end;

  TNXWorkList = class
  private
    FItems: array of TNXWorkItem;

    function GetCount: Integer;
    function GetItem(AIndex: Integer): TNXWorkItem;
  public
    procedure Add(AWorkItem: TNXWorkItem);
    function RunReadyOnce: Integer;

    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TNXWorkItem read GetItem; default;
  end;

  { Example compiler specialization }

  TNXCompileState = (
    csNotStarted,
    csInterfaceParsed,
    csInterfaceReady,
    csImplementationReady,
    csCodeGenerated,
    csCompleted
  );

  TNXCompileTransition = (
    ctParseInterface,
    ctResolveInterface,
    ctResolveImplementation,
    ctGenerateCode,
    ctFinalize
  );

  TNXPublishedUnit = class
  public
    procedure UpdateFrom(AWorkingUnit: TObject); virtual;
  end;

  TNXWorkingUnit = class
  public
    procedure ParseInterface; virtual;
    procedure ResolveInterface; virtual;
    procedure ResolveImplementation; virtual;
    procedure GenerateCode; virtual;
    procedure FinalizeUnit; virtual;
  end;

  TNXCompileUnit = class(TNXWorkItem)
  private
    FPublished: TNXPublishedUnit;
    FWorking: TNXWorkingUnit;

    procedure ParseInterface;
    procedure ResolveInterface;
    procedure ResolveImplementation;
    procedure GenerateCode;
    procedure FinalizeUnit;
  protected
    procedure Commit(AState: TNXWorkState); override;
  public
    constructor Create;
    destructor Destroy; override;

    procedure RequireInterface(AUnit: TNXCompileUnit);

    property Published: TNXPublishedUnit read FPublished;
    property Working: TNXWorkingUnit read FWorking;
  end;

implementation

constructor TNXDependency.Create(AWorkItem: TNXWorkItem;
  ARequiredState: TNXWorkState);
begin
  inherited Create;

  if AWorkItem = nil then
    raise Exception.Create('AWorkItem cannot be nil');

  FWorkItem := AWorkItem;
  FRequiredState := ARequiredState;
end;

function TNXDependency.Satisfied: Boolean;
begin
  Result := FWorkItem.State >= FRequiredState;
end;

constructor TNXTransition.Create(
  AID: TNXTransitionID;
  AFromState: TNXWorkState;
  AToState: TNXWorkState;
  AMethod: TNXTransitionMethod
);
begin
  inherited Create;

  if not Assigned(AMethod) then
    raise Exception.Create('Transition method cannot be nil');

  FID := AID;
  FFromState := AFromState;
  FToState := AToState;
  FMethod := AMethod;
end;

procedure TNXTransition.Execute;
begin
  FMethod;
end;

constructor TNXWorkItem.Create(
  AInitialState: TNXWorkState;
  AFinalState: TNXWorkState
);
begin
  inherited Create;

  if AFinalState < AInitialState then
    raise Exception.Create('Final state cannot precede initial state');

  FInitialState := AInitialState;
  FFinalState := AFinalState;
  FState := AInitialState;
end;

destructor TNXWorkItem.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FDependencies) do
    FDependencies[I].Free;

  for I := 0 to High(FTransitions) do
    FTransitions[I].Free;

  inherited Destroy;
end;

function TNXWorkItem.GetDependency(AIndex: Integer): TNXDependency;
begin
  if (AIndex < 0) or (AIndex >= Length(FDependencies)) then
    raise ERangeError.CreateFmt('Dependency index %d out of range', [AIndex]);

  Result := FDependencies[AIndex];
end;

function TNXWorkItem.GetDependencyCount: Integer;
begin
  Result := Length(FDependencies);
end;

function TNXWorkItem.GetTransition(AIndex: Integer): TNXTransition;
begin
  if (AIndex < 0) or (AIndex >= Length(FTransitions)) then
    raise ERangeError.CreateFmt('Transition index %d out of range', [AIndex]);

  Result := FTransitions[AIndex];
end;

function TNXWorkItem.GetTransitionCount: Integer;
begin
  Result := Length(FTransitions);
end;

function TNXWorkItem.DependenciesSatisfied: Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FDependencies) do
    if not FDependencies[I].Satisfied then
      Exit(False);

  Result := True;
end;

function TNXWorkItem.FindTransition(AFromState: TNXWorkState): TNXTransition;
var
  I: Integer;
begin
  for I := 0 to High(FTransitions) do
    if FTransitions[I].FromState = AFromState then
      Exit(FTransitions[I]);

  Result := nil;
end;

procedure TNXWorkItem.AddDependency(
  AWorkItem: TNXWorkItem;
  ARequiredState: TNXWorkState
);
var
  Index: Integer;
begin
  if AWorkItem = nil then
    raise Exception.Create('AWorkItem cannot be nil');

  Index := Length(FDependencies);
  SetLength(FDependencies, Index + 1);
  FDependencies[Index] := TNXDependency.Create(
    AWorkItem,
    ARequiredState
  );
end;

procedure TNXWorkItem.RegisterTransition(
  AID: TNXTransitionID;
  AFromState: TNXWorkState;
  AToState: TNXWorkState;
  AMethod: TNXTransitionMethod
);
var
  Index: Integer;
begin
  if AFromState < FInitialState then
    raise Exception.Create('Transition starts before initial state');

  if AToState > FFinalState then
    raise Exception.Create('Transition ends after final state');

  if AToState <> AFromState + 1 then
    raise Exception.CreateFmt(
      'Linear transition must advance exactly one state (%d -> %d)',
      [AFromState, AToState]
    );

  if FindTransition(AFromState) <> nil then
    raise Exception.CreateFmt(
      'A transition is already registered from state %d',
      [AFromState]
    );

  Index := Length(FTransitions);
  SetLength(FTransitions, Index + 1);
  FTransitions[Index] := TNXTransition.Create(
    AID,
    AFromState,
    AToState,
    AMethod
  );
end;

procedure TNXWorkItem.Commit(AState: TNXWorkState);
begin
  if AState <> FState + 1 then
    raise Exception.CreateFmt(
      'Linear work state must advance exactly one state (%d -> %d)',
      [FState, AState]
    );

  if AState > FFinalState then
    raise Exception.CreateFmt(
      'Cannot advance beyond final state %d',
      [FFinalState]
    );

  FState := AState;
end;

function TNXWorkItem.Ready: Boolean;
begin
  Result :=
    not Completed and
    DependenciesSatisfied and
    (FindTransition(FState) <> nil);
end;

function TNXWorkItem.Started: Boolean;
begin
  Result := FState > FInitialState;
end;

function TNXWorkItem.Completed: Boolean;
begin
  Result := FState = FFinalState;
end;

function TNXWorkItem.Advance: Boolean;
var
  Transition: TNXTransition;
begin
  Result := False;

  if not Ready then
    Exit;

  Transition := FindTransition(FState);
  Transition.Execute;
  Commit(Transition.ToState);

  Result := True;
end;

procedure TNXWorkList.Add(AWorkItem: TNXWorkItem);
var
  Index: Integer;
begin
  if AWorkItem = nil then
    raise Exception.Create('AWorkItem cannot be nil');

  Index := Length(FItems);
  SetLength(FItems, Index + 1);
  FItems[Index] := AWorkItem;
end;

function TNXWorkList.GetCount: Integer;
begin
  Result := Length(FItems);
end;

function TNXWorkList.GetItem(AIndex: Integer): TNXWorkItem;
begin
  if (AIndex < 0) or (AIndex >= Length(FItems)) then
    raise ERangeError.CreateFmt('Work index %d out of range', [AIndex]);

  Result := FItems[AIndex];
end;

function TNXWorkList.RunReadyOnce: Integer;
var
  I: Integer;
begin
  Result := 0;

  for I := 0 to High(FItems) do
    if FItems[I].Advance then
      Inc(Result);
end;

procedure TNXPublishedUnit.UpdateFrom(AWorkingUnit: TObject);
begin
end;

procedure TNXWorkingUnit.ParseInterface;
begin
end;

procedure TNXWorkingUnit.ResolveInterface;
begin
end;

procedure TNXWorkingUnit.ResolveImplementation;
begin
end;

procedure TNXWorkingUnit.GenerateCode;
begin
end;

procedure TNXWorkingUnit.FinalizeUnit;
begin
end;

constructor TNXCompileUnit.Create;
begin
  inherited Create(
    Ord(Low(TNXCompileState)),
    Ord(High(TNXCompileState))
  );

  FPublished := TNXPublishedUnit.Create;
  FWorking := TNXWorkingUnit.Create;

  RegisterTransition(
    Ord(ctParseInterface),
    Ord(csNotStarted),
    Ord(csInterfaceParsed),
    @ParseInterface
  );

  RegisterTransition(
    Ord(ctResolveInterface),
    Ord(csInterfaceParsed),
    Ord(csInterfaceReady),
    @ResolveInterface
  );

  RegisterTransition(
    Ord(ctResolveImplementation),
    Ord(csInterfaceReady),
    Ord(csImplementationReady),
    @ResolveImplementation
  );

  RegisterTransition(
    Ord(ctGenerateCode),
    Ord(csImplementationReady),
    Ord(csCodeGenerated),
    @GenerateCode
  );

  RegisterTransition(
    Ord(ctFinalize),
    Ord(csCodeGenerated),
    Ord(csCompleted),
    @FinalizeUnit
  );
end;

destructor TNXCompileUnit.Destroy;
begin
  FWorking.Free;
  FPublished.Free;

  inherited Destroy;
end;

procedure TNXCompileUnit.RequireInterface(AUnit: TNXCompileUnit);
begin
  AddDependency(
    AUnit,
    Ord(csInterfaceReady)
  );
end;

procedure TNXCompileUnit.ParseInterface;
begin
  FWorking.ParseInterface;
end;

procedure TNXCompileUnit.ResolveInterface;
begin
  FWorking.ResolveInterface;
end;

procedure TNXCompileUnit.ResolveImplementation;
begin
  FWorking.ResolveImplementation;
end;

procedure TNXCompileUnit.GenerateCode;
begin
  FWorking.GenerateCode;
end;

procedure TNXCompileUnit.FinalizeUnit;
begin
  FWorking.FinalizeUnit;
end;

procedure TNXCompileUnit.Commit(AState: TNXWorkState);
begin
  FPublished.UpdateFrom(FWorking);
  inherited Commit(AState);
end;

end.
