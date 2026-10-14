{ Consolidated records regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode delphi}

{ Case trhlp1.pas }
{$push}


{ this tests that helpers can introduce instance methods for records - mode
  Delphi }


{$ifdef fpc}
  
{$endif}

type
  trhlp1_TTest = record
  end;

  trhlp1_TTestHelper = record helper for trhlp1_TTest
    procedure Test;
  end;

procedure trhlp1_TTestHelper.Test;
begin

end;

var
  trhlp1_t: trhlp1_TTest;

{$pop}

{ Case trhlp20.pas }
{$push}


{ although records can't have (strict) protected, record helpers can }


{$ifdef fpc}
  
{$endif}

type
  trhlp20_TTest = record

  end;

  trhlp20_TTestHelper = record helper for trhlp20_TTest
  strict protected
    procedure Test;
  end;

procedure trhlp20_TTestHelper.Test;
begin

end;


{$pop}

{ Case trhlp21.pas }
{$push}


{ although records can't have (strict) protected, record helpers can }


{$ifdef fpc}
  
{$endif}

type
  trhlp21_TTest = record

  end;

  trhlp21_TTestHelper = record helper for trhlp21_TTest
  protected
    procedure Test;
  end;

procedure trhlp21_TTestHelper.Test;
begin

end;


{$pop}

{ Case trhlp22.pas }
{$push}


{ although records can't use published members, record helpers can }


{$ifdef fpc}
  
{$endif}

type
  trhlp22_TTest = record

  end;

{$M+}
  trhlp22_TTestHelper = record helper for trhlp22_TTest
  private
    function GetTest: Integer;
  published
    property Test: Integer read GetTest;
  end;
{$M-}

function trhlp22_TTestHelper.GetTest: Integer;
begin

end;


{$pop}

{ Case trhlp35.pas }
{$push}


{ for helpers Self always refers to the extended record }


{$ifdef fpc}
  
{$endif}

type
  trhlp35_TTest = record
    procedure DoTest(aTest: trhlp35_TTest);
  end;

  trhlp35_TTestHelper = record helper for trhlp35_TTest
    procedure Test;
  end;

procedure trhlp35_TTest.DoTest(aTest: trhlp35_TTest);
begin

end;

procedure trhlp35_TTestHelper.Test;
begin
  DoTest(Self);
end;

var
  trhlp35_t: trhlp35_TTest;

{$pop}

{ Case trhlp44.pas }
{$push}






type
  trhlp44_TTest = record

  end;

  trhlp44_TTestHelper = record helper for trhlp44_TTest
    procedure SayHello(const I: Integer); overload;
    procedure SayHello(const S: string); overload;
  end;

procedure trhlp44_TTestHelper.SayHello(const I: Integer); overload;
begin
  Writeln('Hello ', I);
end;

procedure trhlp44_TTestHelper.SayHello(const S: string); overload;
begin
  Writeln('Hello ', S);
end;

var
  trhlp44_Obj: trhlp44_TTest;

{$pop}

{ Case tthlp22.pas }
{$push}


{ type helpers are not parsed if modeswitch typehelpers is not set (mode Delphi) }





type
  tthlp22_TTest = record helper for LongInt
  end;


{$pop}

{ Case tthlp28.pas }
{$push}






type
  tthlp28_TPLongIntHelper = record helper for PLongInt
    procedure Test;
  end;

procedure tthlp28_TPLongIntHelper.Test;
begin

end;

var
  tthlp28_p: PLongInt;

{$pop}

begin

{ Case trhlp1.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  trhlp1_t.Test;
end;
{$pop}

{ Case trhlp20.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case trhlp21.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case trhlp22.pas }
{$push}
{$ifdef fpc}

{$endif}
{$M+}
{$M-}
begin
end;
{$pop}

{ Case trhlp35.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  trhlp35_t.Test;
end;
{$pop}

{ Case trhlp44.pas }
{$push}

begin
  trhlp44_Obj.SayHello('FPC');
end;
{$pop}

{ Case tthlp22.pas }
{$push}

begin

end;
{$pop}

{ Case tthlp28.pas }
{$push}

begin
  tthlp28_p.Test;
end;
{$pop}

end.
