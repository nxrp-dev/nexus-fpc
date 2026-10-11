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

{ Case tb0707.pp }
{$push}
{$modeswitch advancedrecords}
var
	tb0707_initialized: boolean = false;

type
	tb0707_innerrec = record
		class operator Initialize(var self: tb0707_innerrec);
	end;

	tb0707_outerrec = record
		tb0707_inner: tb0707_innerrec;
		class operator Initialize(var self: tb0707_outerrec);
	end;

	class operator tb0707_innerrec.Initialize(var self: tb0707_innerrec);
	begin
		tb0707_initialized := true;
	end;

	class operator tb0707_outerrec.Initialize(var self: tb0707_outerrec);
	begin
	end;
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

  { Case tb0707.pp }
  {$push}
begin
	Initialize(tb0707_outerrec(nil^));
	if not tb0707_initialized then
	begin
		writeln('Inner record not initialized.');
		halt(1);
	end;
	writeln('ok');
end;
  {$pop}

end.
