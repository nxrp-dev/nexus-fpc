{ Consolidated routines regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tb_procedural_values_delphi_run_01.pp }
{$push}
{ Overload resolution for assigned procedure variables and empty function parameter lists. }
{ Original case IDs and variable scopes are retained below. }



{ Case tb0384.pp }
{$push}
var
  tb0384_count : longint;

procedure tb0384_p1(tb0384_w:word);overload;
begin
  writeln('word');
  tb0384_count:=tb0384_count or 1;
end;

procedure tb0384_p1(tb0384_l:longint);overload;
begin
  writeln('longint');
  tb0384_count:=tb0384_count or 2;
end;

var
  tb0384_f1 : procedure(tb0384_l:longint);
  tb0384_f2 : procedure(tb0384_w:word);
{$pop}

{ Case tb0354.pp }
{$push}
type
   tb0354_a = function ( ) : boolean;
{$pop}


{$pop}

{ Case tw1910.pp }
{$push}


type
  tw1910_tprocedure = procedure;

  procedure tw1910_testprocedure;
   begin
   end;


  procedure tw1910_proc(const buf);
  var
    p : tw1910_tprocedure;
  begin
    p:=tw1910_tprocedure(@buf);
  end;



{$pop}

{ Case tw3045.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3045 }
{ Submitted by "marco" on  2004-04-10 }
{ e-mail:  }


procedure tw3045_raiselastwin32error;

begin
end;

const tw3045_raiselastoserror : procedure = tw3045_raiselastwin32error;   // ok

var tw3045_varraiselastoserror : procedure = tw3045_raiselastwin32error;  // fail


{$pop}

{ Case tw35298.pp }
{$push}

{$RANGECHECKS OFF}
{$OVERFLOWCHECKS OFF}

function tw35298_SplitMix64(var X: UInt64) : UInt64;
var
  Z: UInt64;
begin
  Inc(X, UInt64($9E3779B97F4A7C15));
  Z := (X xor (X shr 30)) * UInt64($BF58476D1CE4E5B9);
  Z := (Z xor (Z shr 27)) * UInt64($94D049BB133111EB);
  Result := Z xor (Z shr 31);
end;


{$pop}

begin

{ Case tb_procedural_values_delphi_run_01.pp }
{$push}

{$push}
{$pop}
{$push}
{$pop}
begin
  { Case tb0384.pp }
  {$push}
begin
  tb0384_f1:=tb0384_p1;
  tb0384_f2:=tb0384_p1;
  tb0384_f1(1);
  tb0384_f2(1);
  if tb0384_count<>3 then
   begin
     writeln('ERROR!');
     halt(1);
   end;
end;
  {$pop}

  { Case tb0354.pp }
  {$push}
begin
end;
  {$pop}

end;
{$pop}

{ Case tw1910.pp }
{$push}

begin
  tw1910_proc(tw1910_testprocedure);
end;
{$pop}

{ Case tw3045.pp }
{$push}

begin
end;
{$pop}

{ Case tw35298.pp }
{$push}

{$RANGECHECKS OFF}
{$OVERFLOWCHECKS OFF}
begin
end;
{$pop}

end.
