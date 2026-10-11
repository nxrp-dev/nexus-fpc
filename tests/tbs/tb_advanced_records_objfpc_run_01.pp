{ Generic advanced-record method side effects and managed class-field initialization. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}
{$modeswitch advancedrecords}

{ Case tb0665.pp }
{$push}
{$modeswitch advancedrecords}

type
  TTest = record
    b: Boolean;
    function Test(aArg: Pointer): Boolean; inline;
    generic function Test<tb0665_t>: Boolean; inline;
  end;

function TTest.Test(aArg: Pointer): Boolean;
begin
  b := True;
  Result := True;
end;

generic function TTest.Test<tb0665_t>: Boolean;
begin
  Result := Test(Nil);
end;

var
  tb0665_t: TTest;
{$pop}

{ Case tb0695.pp }
{$push}
{$APPTYPE CONSOLE}
{$IFDEF FPC}
  
  {$MODESWITCH ADVANCEDRECORDS}
{$ENDIF}

type
  TState = record
  strict private
    FState: LongWord;
    class operator Initialize({$IFDEF FPC}var{$ELSE}out{$ENDIF} Instance: TState);
  public
    property State: LongWord read FState;
  end;

var
  initdone: Boolean = False;

class operator TState.Initialize({$IFDEF FPC}var{$ELSE}out{$ENDIF} Instance: TState);
begin
  Writeln('TState now being initialised');
  initdone := True;
  Instance.FState := 1;
end;

type
  TSys0 = class(TObject)
    FItem: TState;
    constructor Create;
  end;

  TSys = class(TSys0)
    //FItem2: TState;
  end;

constructor TSys0.Create;
begin
  inherited;
  Writeln(ClassName + ' now being created');
  Writeln('State=', FItem.State);
end;

var
  tb0695_c: TSys;
{$pop}

begin
  { Case tb0665.pp }
  {$push}
begin
  tb0665_t.b := False;
  { check for side effects to ensure that the code was correctly generated }
  tb0665_t.specialize Test<LongInt>;
  if not tb0665_t.b then
    Halt(1);
  Writeln('ok');
end;
  {$pop}

  { Case tb0695.pp }
  {$push}
begin
  Writeln('Create instance of TSys...');
  tb0695_c := TSys.Create;
  if not InitDone then
    Halt(1);
  tb0695_c.Free;
end;
  {$pop}

end.
