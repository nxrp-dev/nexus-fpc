{ Consolidated classes regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case talign.pp }
{$push}


{ This is just a small file used to verify the alignment of different
  structures. Only the assembler output should be checked.
}



type
  talign_tmyclass = class
    s: ansistring;
    f: real;
  end;
{$M+}
  talign_tmyotherclass = class(talign_tmyclass)
  public
    procedure tito(var Msg); message 'hello';
    procedure tita(var Msg); message 'h';
    procedure titi(var Msg); message 12;
  published
    procedure published_method;
  end;

  procedure talign_tmyotherclass.tito(var Msg);
   begin
   end;

  procedure talign_tmyotherclass.tita(var Msg);
   begin
   end;

  procedure talign_tmyotherclass.titi(var Msg);
   begin
   end;

  procedure talign_tmyotherclass.published_method;
   begin
   end;


var
 talign_c: talign_tmyclass;

{$pop}

{ Case tchlp3.pp }
{$push}


{ this tests that helpers can introduce instance methods for classes - mode
  ObjFPC }


{$ifdef fpc}
  
{$endif}

type
  tchlp3_TTest = class

  end;

  tchlp3_TTestHelper = class helper for tchlp3_TTest
    procedure Test;
  end;

procedure tchlp3_TTestHelper.Test;
begin

end;

var
  tchlp3_t: tchlp3_TTest;

{$pop}

{ Case tchlp43.pp }
{$push}


{ for helpers Self always refers to the extended class }


{$ifdef fpc}
  
{$endif}

type
  tchlp43_TTest = class
    procedure DoTest(aTest: tchlp43_TTest);
  end;

  tchlp43_TTestHelper = class helper for tchlp43_TTest
    procedure Test;
  end;

procedure tchlp43_TTest.DoTest(aTest: tchlp43_TTest);
begin

end;

procedure tchlp43_TTestHelper.Test;
begin
  DoTest(Self);
end;

var
  tchlp43_t: tchlp43_TTest;

{$pop}

begin

{ Case talign.pp }
{$push}

{$M+}
Begin
end;
{$pop}

{ Case tchlp3.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tchlp3_t.Test;
end;
{$pop}

{ Case tchlp43.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tchlp43_t := tchlp43_TTest.Create;
  tchlp43_t.Test;
end;
{$pop}

end.
