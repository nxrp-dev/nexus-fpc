{ Consolidated classes regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tw25917.pp }
{$push}




{$APPTYPE CONSOLE}


type
  tw25917_TA<T1, T2> = class
  end;

  tw25917_TB<T1, T2> = class
  private
    type
      T3 = record end;

      TC = class(tw25917_TA<T1, T3>)
      public
        procedure Foo;
      end;
  end;

procedure tw25917_TB<T1, T2>.TC.Foo;
var
  L: tw25917_TB<T1, T2>.T3;
begin
end;

var
  tw25917_x: tw25917_TB<Pointer, Pointer>;


{$pop}

{ Case tchlp37.pp }
{$push}


{ helpers of a parent are available in a subclass as well }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp37_TTest = class

  end;

  tchlp37_TTestSub = class(tchlp37_TTest)

  end;

  tchlp37_TTestHelper = class helper for tchlp37_TTest
    procedure Test;
  end;

procedure tchlp37_TTestHelper.Test;
begin

end;

var
  tchlp37_t: tchlp37_TTestSub;

{$pop}

{ Case tchlp45.pp }
{$push}


{ tests whether the methods of a parent helper are usable in a derived helper }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tchlp45_TTest = class

  end;

  tchlp45_TTestHelper = class helper for tchlp45_TTest
    procedure Test;
  end;

  tchlp45_TTestHelperSub = class helper(tchlp45_TTestHelper) for tchlp45_TTest
    procedure AccessTest;
  end;

procedure tchlp45_TTestHelper.Test;
begin

end;

procedure tchlp45_TTestHelperSub.AccessTest;
begin
  Test;
end;


{$pop}

begin

{ Case tw25917.pp }
{$push}
{$APPTYPE CONSOLE}

begin
end;
{$pop}

{ Case tchlp37.pp }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tchlp37_t.Test;
end;
{$pop}

{ Case tchlp45.pp }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
end;
{$pop}

end.
