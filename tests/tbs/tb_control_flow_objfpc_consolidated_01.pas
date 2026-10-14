{ Consolidated control flow regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tb0659c.pas }
{$push}




{$ifndef FPC_OBJFPC}
{$fatal FPC_OBJFPC not defined}
{$endif}
{$ifdef FPC_DELPHI}
{$fatal FPC_DELPHI defined}
{$endif}
{$ifdef FPC_MACPAS}
{$fatal FPC_MACPAS defined}
{$endif}
{$ifdef FPC_ISO}
{$fatal FPC_ISO defined}
{$endif}
{$ifdef FPC_EXTENDEDPASCAL}
{$fatal FPC_EXTENDEDPASCAL defined}
{$endif}


{$pop}

{ Case tb_finally_loops_objfpc_run_01.pas }
{$push}
{ Try/Finally inside For loops with variable and constant upper bounds. }
{ Original case IDs and variable scopes are retained below. }



{ Case tw37305a.pas }
{$push}
var
  tw37305a_i, tw37305a_j, tw37305a_c: Int32;
{$pop}

{ Case tw37305b.pas }
{$push}
var
  tw37305b_i, tw37305b_j: Int32;
{$pop}


{$pop}

{ Case tw12186.pas }
{$push}


{$pop}

{ Case tw15690.pas }
{$push}



{$pop}

{ Case tw20874b.pas }
{$push}


{$H+}

var
  tw20874b_A, tw20874b_B : Boolean64;

{$pop}

{ Case tw3028.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3028 }
{ Submitted by "Vincent Snijders" on  2004-03-28 }
{ e-mail: vslist@zonnet.nl }


{$H+}

const
  tw3028_c1 = -(551);
  tw3028_c2 = -551;


{$pop}

{ Case tw8156.pas }
{$push}


type
  tw8156_A = type IInterface;
  tw8156_B = type IInterface;


{$pop}

begin

{ Case tb0659c.pas }
{$push}

{$ifndef FPC_OBJFPC}
{$fatal FPC_OBJFPC not defined}
{$endif}
{$ifdef FPC_DELPHI}
{$fatal FPC_DELPHI defined}
{$endif}
{$ifdef FPC_MACPAS}
{$fatal FPC_MACPAS defined}
{$endif}
{$ifdef FPC_ISO}
{$fatal FPC_ISO defined}
{$endif}
{$ifdef FPC_EXTENDEDPASCAL}
{$fatal FPC_EXTENDEDPASCAL defined}
{$endif}
begin
end;
{$pop}

{ Case tb_finally_loops_objfpc_run_01.pas }
{$push}

{$push}
{$pop}
{$push}
{$pop}
begin
  { Case tw37305a.pas }
  {$push}
begin
  tw37305a_c := 1;
  for tw37305a_i := 0 to tw37305a_c do // SIGSEGV at runtime
  try
    tw37305a_j := tw37305a_i;
  finally
    if (tw37305a_j <> 0) then
      tw37305a_j := 0;
  end;
end;
  {$pop}

  { Case tw37305b.pas }
  {$push}
begin
  for tw37305b_i := 0 to 1 do // Error: Compilation raised exception internally
  try
    tw37305b_j := tw37305b_i;
  finally
    if (tw37305b_j <> 0) then
      tw37305b_j := 0;
  end;
end;
  {$pop}

end;
{$pop}

{ Case tw12186.pas }
{$push}

begin
writeln(13); // ok
writeln($d); // ok
writeln(&15); // ok
writeln(%1101); // ok
writeln(0000098); // ok
writeln(#$62); // ok
writeln(#&142); // error!
writeln(#%1100010); // error!
end;
{$pop}

{ Case tw15690.pas }
{$push}

begin
  if tobject.inheritsfrom(nil) then
    halt(1);
end;
{$pop}

{ Case tw20874b.pas }
{$push}

{$H+}
begin
  tw20874b_A := True;

  // here it fails: qwordbooltest.pas(12,3) Fatal: Internal error 200109227
  tw20874b_B := not tw20874b_A;

  if tw20874b_B then
    halt(1);

  writeln('ok');
end;
{$pop}

{ Case tw3028.pas }
{$push}

{$H+}
begin
  writeln(tw3028_c1,' $', hexstr(tw3028_c1, 8));
  writeln(tw3028_c2,' $', hexstr(tw3028_c2, 8));
  if (tw3028_c1<>tw3028_c2) then
  begin
    writeln('Failed');
    halt(1);
  end
  else writeln('OK');
end;
{$pop}

{ Case tw8156.pas }
{$push}

begin
end;
{$pop}

end.
