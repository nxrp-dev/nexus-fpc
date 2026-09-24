unit profiler_core_unit;

{$mode objfpc}{$H+}
{$modeswitch anonymousfunctions}

interface

function ExitWork(Value: LongInt): LongInt; noinline;
function RecursiveWork(Value: LongInt): LongInt; noinline;
function Overloaded(Value: LongInt): LongInt; overload; noinline;
function Overloaded(const Value: AnsiString): LongInt; overload; noinline;
function InlineWork(Value: LongInt): LongInt; inline;
procedure NestedWork(var Value: LongInt); noinline;
procedure AnonymousWork(var Value: LongInt); noinline;
procedure AssemblyExcluded;

type
  TProfiledObject = class
  public
    constructor Create;
    destructor Destroy; override;
  end;

function ConstructedCount: LongInt;
function FinalizedCount: LongInt;

implementation

var
  GConstructed: LongInt;
  GFinalized: LongInt;

function ExitWork(Value: LongInt): LongInt;
begin
  if Value > 0 then
    Exit(Value + 1);
  Result := 0;
end;

function RecursiveWork(Value: LongInt): LongInt;
begin
  if Value <= 0 then
    Exit(1);
  Result := RecursiveWork(Value - 1) + 1;
end;

function Overloaded(Value: LongInt): LongInt;
begin
  Result := Value + 2;
end;

function Overloaded(const Value: AnsiString): LongInt;
begin
  Result := Length(Value);
end;

function InlineWork(Value: LongInt): LongInt;
begin
  Result := Value + 3;
end;

procedure NestedWork(var Value: LongInt);
  procedure Increment; noinline;
  begin
    Inc(Value);
  end;
begin
  Increment;
end;

procedure AnonymousWork(var Value: LongInt);
begin
  procedure begin Inc(Value); end();
end;

procedure AssemblyExcluded; assembler; nostackframe;
asm
  nop
end;

constructor TProfiledObject.Create;
begin
  inherited Create;
  Inc(GConstructed);
end;

destructor TProfiledObject.Destroy;
begin
  Dec(GConstructed);
  inherited Destroy;
end;

function ConstructedCount: LongInt;
begin
  Result := GConstructed;
end;

function FinalizedCount: LongInt;
begin
  Result := GFinalized;
end;

procedure UnitInit; noinline;
begin
  Inc(GFinalized);
end;

procedure UnitFinal; noinline;
begin
  Inc(GFinalized);
end;

initialization
  UnitInit;
finalization
  UnitFinal;
end.
