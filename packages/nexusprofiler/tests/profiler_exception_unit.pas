unit profiler_exception_unit;

{$mode objfpc}{$H+}

interface

procedure SameFrameCatch; noinline;
procedure CatchOneFrame; noinline;
procedure CatchMultiFrame; noinline;
procedure CatchRethrow; noinline;
procedure CatchFinally; noinline;
procedure CatchNested; noinline;
procedure CatchAccessViolation; noinline;
procedure CallSafe; noinline;
function FinalizerCount: LongInt;

implementation

uses
  SysUtils;

var
  GFinalizerCount: LongInt;

procedure RaiseObject; noinline;
begin
  raise TObject.Create;
end;

procedure SameFrameCatch;
begin
  try
    raise TObject.Create;
  except
  end;
end;

procedure OneFrame; noinline;
begin
  RaiseObject;
end;

procedure CatchOneFrame;
begin
  try OneFrame; except end;
end;

procedure Multi2; noinline;
begin
  RaiseObject;
end;

procedure Multi1; noinline;
begin
  Multi2;
end;

procedure CatchMultiFrame;
begin
  try Multi1; except end;
end;

procedure Rethrower; noinline;
begin
  try RaiseObject; except raise; end;
end;

procedure CatchRethrow;
begin
  try Rethrower; except end;
end;

procedure Finalizer; noinline;
begin
  Inc(GFinalizerCount);
end;

procedure ThroughFinally; noinline;
begin
  try RaiseObject; finally Finalizer; end;
end;

procedure CatchFinally;
begin
  try ThroughFinally; except end;
end;

procedure NestedRaise; noinline;
begin
  try
    RaiseObject;
  except
    try RaiseObject; except end;
    raise;
  end;
end;

procedure CatchNested;
begin
  try NestedRaise; except end;
end;

procedure CatchAccessViolation;
begin
  try PLongInt(PtrUInt(1))^ := 1; except end;
end;

procedure SafeRaise; safecall;
begin
  raise Exception.Create('safecall');
end;

procedure CallSafe;
begin
  try SafeRaise; except end;
end;

function FinalizerCount: LongInt;
begin
  Result := GFinalizerCount;
end;

end.
