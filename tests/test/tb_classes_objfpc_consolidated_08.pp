{ Consolidated classes regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tmoperator1.pp }
{$push}





{$modeswitch advancedrecords}

type

  { TFoo }

  tmoperator1_TFoo = record
  private
    class operator Initialize(var aFoo: tmoperator1_TFoo);
    class operator Finalize(var aFoo: tmoperator1_TFoo);
  end;

{ TFoo }

class operator tmoperator1_TFoo.Initialize(var aFoo: tmoperator1_TFoo);
begin
end;

class operator tmoperator1_TFoo.Finalize(var aFoo: tmoperator1_TFoo);
begin
end;


{$pop}

{ Case toperator97.pp }
{$push}





{$modeswitch advancedrecords}

type
  toperator97_TTest = record
    class operator :=(aArg: toperator97_TTest): Pointer;
  end;

class operator toperator97_TTest.:=(aArg: toperator97_TTest): Pointer;
begin
end;

var
  toperator97_b: PByte;
  toperator97_t: toperator97_TTest;

{$pop}

{ Case trhlp4.pp }
{$push}


{ this tests that helpers can introduce class methods for records - mode
  ObjFPC }


{$ifdef fpc}
  
  {$modeswitch advancedrecords}
{$endif}

type
  trhlp4_TTest = record
  end;

  trhlp4_TTestHelper = record helper for trhlp4_TTest
    class procedure Test; static;
  end;

class procedure trhlp4_TTestHelper.Test;
begin

end;


{$pop}

begin

{ Case tmoperator1.pp }
{$push}

{$modeswitch advancedrecords}
begin
end;
{$pop}

{ Case toperator97.pp }
{$push}

{$modeswitch advancedrecords}
begin
  toperator97_b := toperator97_t;
end;
{$pop}

{ Case trhlp4.pp }
{$push}
{$ifdef fpc}

{$modeswitch advancedrecords}
{$endif}
begin
  trhlp4_TTest.Test;
end;
{$pop}

end.
