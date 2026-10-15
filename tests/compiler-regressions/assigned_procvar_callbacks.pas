{ Compile with -O2. Assigned must never invoke the callbacks being tested. }
program assigned_procvar_callbacks;

{$mode delphi}

type
  TCallback = function: NativeUInt;
  TArgumentCallback = function(Value: Integer): Integer;
  TMethod = function: NativeUInt of object;
  TReceiver = class
    function Run: NativeUInt;
  end;

var
  Calls: Integer;

function Callback: NativeUInt;
begin
  Inc(Calls);
  Result := 0;
end;

function ArgumentCallback(Value: Integer): Integer;
begin
  Inc(Calls);
  Result := Value;
end;

function TReceiver.Run: NativeUInt;
begin
  Inc(Calls);
  Result := 0;
end;

function BothMissing(A, B: TCallback): Boolean;
begin
  Result := not Assigned(A) and not Assigned(B);
end;

function BothArgumentsMissing(A, B: TArgumentCallback): Boolean;
begin
  Result := not Assigned(A) and not Assigned(B);
end;

function BothMethodsMissing(A, B: TMethod): Boolean;
begin
  Result := not Assigned(A) and not Assigned(B);
end;

var
  A, B: TCallback;
  C, D: TArgumentCallback;
  M, N: TMethod;
  Receiver: TReceiver;
  I: Integer;
begin
  Receiver := TReceiver.Create;
  try
    for I := 0 to 3 do
    begin
      A := nil;
      B := nil;
      C := nil;
      D := nil;
      M := nil;
      N := nil;
      if (I and 1) <> 0 then
      begin
        A := Callback;
        C := ArgumentCallback;
        M := Receiver.Run;
      end;
      if (I and 2) <> 0 then
      begin
        B := Callback;
        D := ArgumentCallback;
        N := Receiver.Run;
      end;
      if BothMissing(A, B) <> (I = 0) then
        Halt(10 + I);
      if BothArgumentsMissing(C, D) <> (I = 0) then
        Halt(20 + I);
      if BothMethodsMissing(M, N) <> (I = 0) then
        Halt(30 + I);
      if Calls <> 0 then
        Halt(40 + I);
    end;
  finally
    Receiver.Free;
  end;
  WriteLn('PASS: 12 callback checks; zero callback calls');
end.
