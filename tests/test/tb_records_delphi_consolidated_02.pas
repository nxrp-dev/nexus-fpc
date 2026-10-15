{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case terecs10.pas }
{$push}


{$ifdef fpc}
  
{$endif}

type
  terecs10_TTest = record
    function GetTest(Index: Integer): Integer;
    property Test[Index: Integer]: Integer read GetTest; default;
  end;

function terecs10_TTest.GetTest(Index: Integer): Integer;
begin
  Result := Index;
end;

var
  terecs10_t: terecs10_TTest;

{$pop}

{ Case terecs16.pas }
{$push}



type
  terecs16_TRec = record
    l: longint;
    constructor Create(a: longint);
  end;


var
  terecs16_r: terecs16_TRec;

  constructor terecs16_TRec.Create(a: longint);
  begin
    l := a;
    terecs16_r.l := 4;
    if l <> a then
      halt(1);
    l := 5;
    if terecs16_r.l <> 4 then
      halt(2);
    terecs16_r.l := 6;
  end;


{$pop}

{ Case tisconstvalue2.pas }
{$push}




// example taken from https://stackoverflow.com/a/30417597

type
  tisconstvalue2_TFlavor = (tisconstvalue2_Tasty, tisconstvalue2_Nasty);

  tisconstvalue2_TIntegerHelper = record helper for Integer
  private
    function GetTastyPoint: Integer;
    function GetNastyPoint: Integer;
  public
    function GetSomething(Flavor: tisconstvalue2_TFlavor): Integer; inline;
  end;

  function tisconstvalue2_TIntegerHelper.GetTastyPoint: Integer;
  begin
    Result := 10;
  end;

  function tisconstvalue2_TIntegerHelper.GetNastyPoint: Integer;
  begin
    Result := -10;
  end;

  function tisconstvalue2_TIntegerHelper.GetSomething(Flavor: tisconstvalue2_TFlavor): Integer;
  begin
    if IsConstValue(Flavor) then
    begin
      if Flavor = tisconstvalue2_Tasty then
        Result := Self.GetTastyPoint
      else
        Result := Self.GetNastyPoint;
    end
    else
    begin
      Result := 0;
    end;
  end;

var
  tisconstvalue2_i: Integer;
  tisconstvalue2_n: tisconstvalue2_TFlavor;


{$pop}

{ Case trecreg3.pas }
{$push}

const
  trecreg3_RS_CR0 = 1;
  trecreg3_RS_CR1 = 2;
  trecreg3_RS_CR2 = 3;
  trecreg3_RS_CR3 = 4;
  trecreg3_RS_CR4 = 5;
  trecreg3_RS_CR5 = 6;
  trecreg3_RS_CR6 = 7;
  trecreg3_RS_CR7 = 8;
type
  trecreg3_TResFlagsEnum = (trecreg3_F_EQ, trecreg3_F_NE, trecreg3_F_LT, trecreg3_F_LE, trecreg3_F_GT, trecreg3_F_GE, trecreg3_F_SO, trecreg3_F_FX, trecreg3_F_FEX, trecreg3_F_VX,
    trecreg3_F_OX);
  trecreg3_TResFlags = record
    cr: trecreg3_RS_CR0..trecreg3_RS_CR7;
    flag: trecreg3_TResFlagsEnum;
  end;

type
  trecreg3_TAsmCondFlag = (trecreg3_C_None { unconditional jumps },
    { conditions when not using ctr decrement etc }
    trecreg3_C_LT, trecreg3_C_LE, trecreg3_C_EQ, trecreg3_C_GE, trecreg3_C_GT, trecreg3_C_NL, trecreg3_C_NE, trecreg3_C_NG, trecreg3_C_SO, trecreg3_C_NS, trecreg3_C_UN, trecreg3_C_NU,
    { conditions when using ctr decrement etc }
    trecreg3_C_T, trecreg3_C_F, trecreg3_C_DNZ, trecreg3_C_DNZT, trecreg3_C_DNZF, trecreg3_C_DZ, trecreg3_C_DZT, trecreg3_C_DZF);

  trecreg3_TDirHint = (trecreg3_DH_None, trecreg3_DH_Minus, trecreg3_DH_Plus);

const
  { these are in the XER, but when moved to CR_x they correspond with the }
  { bits below                                                            }
  trecreg3_C_OV = trecreg3_C_GT;
  trecreg3_C_CA = trecreg3_C_EQ;
  trecreg3_C_NO = trecreg3_C_NG;
  trecreg3_C_NC = trecreg3_C_NE;


type
  trecreg3_TAsmCond = packed record
    dirhint: trecreg3_tdirhint;
    case simple: boolean of
      false: (BO, BI: byte);
      true: (
        cond: trecreg3_TAsmCondFlag;
        case byte of
          0: ();
          { specifies in which part of the cr the bit has to be }
          { tested for blt,bgt,beq,..,bnu                       }
          1: (cr: trecreg3_RS_CR0..trecreg3_RS_CR7);
          { specifies the bit to test for bt,bf,bdz,..,bdzf }
          2: (crbit: byte)
          );
  end;

procedure trecreg3_error(err : int64);
begin
  writeln('Error: ', err);
  halt(1);
end;


function trecreg3_flags_to_cond(const f: trecreg3_TResFlags): trecreg3_TAsmCond;
const
  flag_2_cond: array[trecreg3_F_EQ..trecreg3_F_SO] of trecreg3_TAsmCondFlag =
  (trecreg3_C_EQ, trecreg3_C_NE, trecreg3_C_LT, trecreg3_C_LE, trecreg3_C_GT, trecreg3_C_GE, trecreg3_C_SO);
begin
  if f.flag > high(flag_2_cond) then
    trecreg3_error(1);
  case f.flag of
    trecreg3_F_EQ, trecreg3_F_NE, trecreg3_F_LT, trecreg3_F_LE, trecreg3_F_GT, trecreg3_F_GE, trecreg3_F_SO, trecreg3_F_FX, trecreg3_F_FEX, trecreg3_F_VX,
    trecreg3_F_OX:
      ;
  else
    trecreg3_error(2);
  end;
  result.simple := true;
  result.cr := f.cr;
  result.cond := flag_2_cond[f.flag];
end;

var trecreg3_flags : trecreg3_TResFlags;

{$pop}

{ Case trhlp12.pas }
{$push}
{ constructors in record helpers }


{$ifdef fpc}
  
{$endif}

type
  trhlp12_TTest = record

  end;

  trhlp12_TTestHelper = record helper for trhlp12_TTest
    constructor CreateHelped(aTest: Integer);
  end;

constructor trhlp12_TTestHelper.CreateHelped(aTest: Integer);
begin

end;


{$pop}

{ Case trhlp27.pas }
{$push}
{ record helpers hide methods of the extended record }


{$ifdef fpc}
  
{$endif}

type
  trhlp27_TTest = record
    function Test: Integer;
  end;

  trhlp27_TTestHelper = record helper for trhlp27_TTest
    function Test: Integer;
  end;

function trhlp27_TTest.Test: Integer;
begin
  Result := 1;
end;

function trhlp27_TTestHelper.Test: Integer;
begin
  Result := 2;
end;

var
  trhlp27_t: trhlp27_TTest;
  trhlp27_res: Integer;

{$pop}

{ Case trhlp45.pas }
{$push}




type
  trhlp45_TRec = record
    X: Integer;
  end;

  trhlp45_THelpRec = record helper for trhlp45_TRec
    constructor Create(AX: Integer);
  end;


{ THelpRec }

constructor trhlp45_THelpRec.Create(AX: Integer);
begin
  X := AX;
end;

var
  trhlp45_R: trhlp45_TRec;

{$pop}

begin

{ Case terecs10.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  if terecs10_t[42] <> 42 then
    halt(1);
end;
{$pop}

{ Case terecs16.pas }
{$push}

begin
  terecs16_r := terecs16_TRec.Create(10);
  if terecs16_r.l <> 5 then
    halt(3);
end;
{$pop}

{ Case tisconstvalue2.pas }
{$push}

begin
  tisconstvalue2_i := 100000.GetSomething(tisconstvalue2_Tasty);
  if tisconstvalue2_i <> 10 then
    Halt(1);

  tisconstvalue2_n := tisconstvalue2_Tasty;
  tisconstvalue2_i := 100000.GetSomething(tisconstvalue2_Nasty);
  if tisconstvalue2_i <> -10 then
    Halt(2);

  tisconstvalue2_i := 100000.GetSomething(tisconstvalue2_n);
  if tisconstvalue2_i <> 0 then
    Halt(3);

  Writeln('Ok');
end;
{$pop}

{ Case trecreg3.pas }
{$push}

begin
   trecreg3_flags.cr := trecreg3_RS_CR7;
   trecreg3_flags.flag := trecreg3_F_EQ;
   trecreg3_flags_to_cond(trecreg3_flags);
   writeln('Passed');
end;
{$pop}

{ Case trhlp12.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case trhlp27.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  trhlp27_res := trhlp27_t.Test;
  Writeln('t.Test: ', trhlp27_res);
  if trhlp27_res <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case trhlp45.pas }
{$push}

begin
  trhlp45_R := trhlp45_TRec.Create(1);
  if trhlp45_R.X <> 1 then
    halt(1);
end;
{$pop}

end.
