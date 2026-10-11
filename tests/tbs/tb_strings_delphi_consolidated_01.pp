{ Consolidated strings regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tb_open_parameters_delphi_compile_01.pp }
{$push}

{ Overloaded open arrays and Delphi open ShortString parameters. }
{ Original case IDs and variable scopes are retained below. }



{ Case tb0576.pp }
{$push}
type tb0576_bytearray = array of byte;

procedure tb0576_zeromemory(var tb0576_x: array of byte; tb0576_startindex, tb0576_count: integer); overload;
begin
end;

procedure tb0576_zeromemory(var tb0576_x: array of tb0576_bytearray; tb0576_startindex, tb0576_count: integer); overload;
begin
end;

var
  tb0576_buffer: array of byte;
{$pop}

{ Case tb0698.pp }
{$push}
{ Open Strings is by default enabled in mode Delphi }



procedure tb0698_test(var tb0698_aarg: ShortString);
begin
end;

var
  tb0698_s: String[5];
{$pop}


{$pop}

{ Case tw21073.pp }
{$push}






TYPE tw21073_TGetCurrentProcess = function : THandle; stdcall;
     tw21073_TGetProcAddress = function(const hModule : THandle; const lpProcName : PAnsiChar) : Pointer; stdcall;

function tw21073_GetProcAddress(const hModule : THandle;const lpProcName : PAnsiChar) : Pointer; stdcall;
begin
  result:=nil;
end;

function tw21073_GetModuleHandle(const lpModuleName : PWideChar) : THandle; stdcall;
begin
  result:=thandle(-1);
end;

var tw21073_proc_GetCurrentProcess : tw21073_TGetCurrentProcess;
    tw21073_proc_GetProcAddress : tw21073_TGetProcAddress;


{$pop}

{ Case tw30203.pp }
{$push}





{$POINTERMATH ON}

procedure tw30203_QuickSort<T>(var A: Array of T; const Index, Count: Integer);
var
  I, J: Integer;
  Temp, Pivot: T;
begin
  if Index < Count then
  begin
    Pivot := A[Random(Count - Index) + Index + 1];
    I := Index - 1;
    J := Count + 1;
    repeat
      repeat Inc(I) until A[I] >= Pivot;
      repeat Dec(J) until A[J] <= Pivot;
      Temp := A[I];
      A[I] := A[J];
      A[J] := Temp;
    until I >= J;
    A[J] := A[I];
    A[I] := Temp;
    tw30203_QuickSort<T>(A, Index, I - 1);
    tw30203_QuickSort<T>(A, I, Count);
  end;
end;

var
  tw30203_arri: array of LongInt;
  tw30203_arrs: array of String;

{$pop}

{ Case tw30498.pp }
{$push}




{$IFDEF FPC}

{$ENDIF}

  procedure tw30498_Test(const AItems: TArray<string>);
  begin
  end;


{$pop}

{ Case tw36496a.pp }
{$push}


(*
  testing application for
  https://forum.lazarus.freepascal.org/index.php/topic,47936.0.html
*)




function tw36496a_TestGenRecurse<T>(const AInput : T) : Boolean;
begin
  //Result := False;

  (*
    below, if uncommented will fail to compile
    tester.lpr(12,19) Error: Identifier not found "TestGenRecurse$1"
  *)
  tw36496a_TestGenRecurse<T>(AInput);
  tw36496a_TestGenRecurse<String>('test');
  tw36496a_TestGenRecurse<LongInt>(42);
end;

procedure tw36496a_TestGenRecurseProc<T>(const AInput : T);
begin
  (*
    below method calls compile fine
  *)
  tw36496a_TestGenRecurseProc<T>(AInput);
  tw36496a_TestGenRecurseProc<String>('test');
  tw36496a_TestGenRecurseProc<LongInt>(42);
end;


{$pop}

begin

{ Case tb_open_parameters_delphi_compile_01.pp }
{$push}

{$push}
{$pop}
{$push}
{$pop}
begin
  { Case tb0576.pp }
  {$push}
begin
  tb0576_zeromemory(tb0576_buffer, 0, Length(tb0576_buffer));
end;
  {$pop}

  { Case tb0698.pp }
  {$push}
begin
  tb0698_s := 'Test';
  tb0698_test(tb0698_s);
end;
  {$pop}

end;
{$pop}

{ Case tw21073.pp }
{$push}

begin
 {no error} tw21073_proc_GetCurrentProcess:=tw21073_GetProcAddress(tw21073_GetModuleHandle('Kernel32'),'GetCurrentProcess');
 {error ??} tw21073_proc_GetProcAddress:=   tw21073_GetProcAddress(tw21073_GetModuleHandle('Kernel32'),'GetProcAddress');
end;
{$pop}

{ Case tw30203.pp }
{$push}

{$POINTERMATH ON}
begin
  SetLength(tw30203_arri, 4);
  tw30203_arri[0] := 4;
  tw30203_arri[1] := 2;
  tw30203_arri[2] := 6;
  tw30203_arri[3] := 1;
  SetLength(tw30203_arrs, 4);
  tw30203_arrs[0] := 'World';
  tw30203_arrs[1] := 'Alpha';
  tw30203_arrs[2] := 'Hello';
  tw30203_arrs[3] := 'Foo';
  tw30203_QuickSort<LongInt>(tw30203_arri, Low(tw30203_arri), High(tw30203_arri));
  tw30203_QuickSort<String>(tw30203_arrs, Low(tw30203_arrs), High(tw30203_arrs));
end;
{$pop}

{ Case tw30498.pp }
{$push}
{$IFDEF FPC}

{$ENDIF}
begin
  tw30498_Test(['foo', 'bar']);
end;
{$pop}

{ Case tw36496a.pp }
{$push}

begin
  tw36496a_TestGenRecurse<String>('testing');
  tw36496a_TestGenRecurseProc<String>('testing');
end;
{$pop}

end.
