{ Consolidated routines regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tfuncref52.pas }
{$push}
// Test to determine that function references are enabled in mode delphi

{ $modeswitch functionreferences}



Type
  tfuncref52_TProc = Reference to Procedure;

var
  tfuncref52_P : tfuncref52_TProc;

Procedure tfuncref52_Testit;

  Procedure SoSo;

  begin

  end;

begin
  tfuncref52_P:=SoSo;
  tfuncref52_P;
end;


{$pop}

{ Case tfuncref53.pas }
{$push}
// Test to determine that anonymous functions are enabled in mode delphi




Type
  tfuncref53_TProc = Reference to Procedure;

var
  tfuncref53_P : tfuncref53_TProc;

Procedure tfuncref53_Testit;

begin
  tfuncref53_P:=procedure
    begin

    end;
  tfuncref53_P;
end;


{$pop}

{ Case tgeneric39.pas }
{$push}


{ in mode Delphi generic types might be overloaded - here: procvars only }


{$ifdef fpc}
  
{$endif}

type
  tgeneric39_TTest = procedure;

  tgeneric39_TTest<T> = procedure;

  tgeneric39_TTest<T, S> = procedure;


{$pop}

{ Case tgeneric45.pas }
{$push}


{ in mode Delphi generic types might be overloaded - here: procvars only
  Note: This tests a different code path than in the compiler than tgeneric39! }


{$ifdef fpc}
  
{$endif}

type
  tgeneric45_TTest<T> = procedure;

  tgeneric45_TTest = procedure;

  tgeneric45_TTest<T, S> = procedure;


{$pop}

begin

{ Case tfuncref52.pas }
{$push}

begin
  tfuncref52_Testit;
end;
{$pop}

{ Case tfuncref53.pas }
{$push}

begin
  tfuncref53_Testit;
end;
{$pop}

{ Case tgeneric39.pas }
{$push}
{$ifdef fpc}

{$endif}
begin

end;
{$pop}

{ Case tgeneric45.pas }
{$push}
{$ifdef fpc}

{$endif}
begin

end;
{$pop}

end.
