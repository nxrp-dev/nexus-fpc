{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tw16328.pas }
{$push}



{$r+,q+}
{$inline on}

const
  tw16328_DBIDMASK = $FFFFFFFFFFFF;

type
  tw16328_TmydbID = type Longword;
  tw16328_TmydbCLSID = type Word;
  tw16328_TmydbDBID   = 0..(qword(1) shl 48)-1;  // Unique ID of the database
  tw16328_TmydbDBTYPE = type Byte;

  tw16328_tarr = bitpacked array[0..10] of tw16328_TmydbDBID;

  tw16328_TmydbUID = bitpacked record
    DBID  : tw16328_TmydbDBID;            // Database Identifier
    PROID : tw16328_TmydbID;              // Profile Identifier
    OID   : tw16328_TmydbID;              // Object Identifier
    CLSID : tw16328_TmydbCLSID;           // Object Class
  end;

function tw16328_mydbMakeUID(const DBID: tw16328_TmydbDBID; const PROID: tw16328_TmydbID; const CLSID: tw16328_TmydbCLSID; const OID: tw16328_TmydbID): tw16328_TmydbUID; inline;
begin
  Result.CLSID := CLSID;
  Result.DBID := DBID and tw16328_DBIDMASK;
  Result.PROID := PROID;
  Result.OID := OID;
end;

var
  tw16328_uid: tw16328_TmydbUID;
  tw16328_arr: tw16328_tarr;
  tw16328_i: longint;

{$pop}

{ Case tw21674.pas }
{$push}
{$optimization on}


{$H+}

type
 tw21674_TMyArray = record
  Stuff: array of Longword;
 end;

Var
 tw21674_MyArray: tw21674_TMyArray;
 tw21674_I: Integer;

procedure tw21674_WriteNumbers(A: tw21674_TMyArray);
begin
 for tw21674_I := 0 to High(A.Stuff) do WriteLn(A.Stuff[tw21674_I]);
end;


{$pop}

{ Case tassign2.pas }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{  By Carl Eric Codere                                           }
{****************************************************************}
{ NODE TESTED : secondassign()                                   }
{****************************************************************}
{ DEFINES:                                                       }
{            FPC     = Target is FreePascal compiler             }
{****************************************************************}
{ REMARKS : Tested with Delphi 3 as reference implementation     }
{****************************************************************}


{$ifdef fpc}
{$warning Will only work on 32-bit cpu's}

{$endif}

const
  tassign2_RESULT_STRING = 'Hello world';
  tassign2_RESULT_S64BIT = -12;
  tassign2_RESULT_S32BIT = -124356;
  tassign2_RESULT_U32BIT = 654321;
  tassign2_RESULT_U8BIT  = $55;
  tassign2_RESULT_S16BIT = -12124;
  tassign2_RESULT_REAL   = 12.12;

  { adjusts the size of the bigrecord }
  tassign2_MAX_INDEX = 7;

type
  {
    the size of this record should *at least* be the size
    of a natural register for the target processor
  }
  tassign2_tbigrecord = record
   x : cardinal;
   y : cardinal;
   z : array[0..tassign2_MAX_INDEX] of byte;
  end;


    procedure tassign2_fail;
    begin
      WriteLn('Failure.');
      halt(1);
    end;



    function tassign2_getresults64bit: int64;
     begin
       tassign2_getresults64bit := tassign2_RESULT_S64BIT;
     end;

    function tassign2_getresults32bit : longint;
     begin
       tassign2_getresults32bit := tassign2_RESULT_S32BIT;
     end;

    function tassign2_getresultu8bit : byte;
      begin
        tassign2_getresultu8bit := tassign2_RESULT_U8BIT;
      end;

    function tassign2_getresults16bit : smallint;
      begin
        tassign2_getresults16bit := tassign2_RESULT_S16BIT;
      end;

    function tassign2_getresultreal : real;
      begin
        tassign2_getresultreal := tassign2_RESULT_REAL;
      end;

var
 tassign2_failed : boolean;
 tassign2_s64bit : int64;
 tassign2_s32bit : longint;
 tassign2_s16bit : smallint;
 tassign2_u8bit : byte;
 tassign2_boolval : boolean;
 tassign2_real_val : real;
 tassign2_bigrecord1, tassign2_bigrecord2 : tassign2_tbigrecord;
 tassign2_i: integer;

{$pop}

{ Case treg4.pas }
{$push}
{$inline on}


type
  treg4_tr = record
    case byte of
      1: (l: longint);
      2: (b1,b2,b3,b4: byte);
  end;

function treg4_f: treg4_tr; inline;
begin
  treg4_f.l := 5;
  treg4_f.b3 := 6;
end;

procedure treg4_t(const r1: treg4_tr);
begin
  if (r1.b3 <> 6) or
     ((r1.l and 255) <> 5) then
    halt(1);
end;

procedure treg4_t2(out treg4_r: treg4_tr); inline;
begin
  treg4_r.l := 7;
  treg4_r.b2 := 31;
end;

procedure treg4_t3(out treg4_r: treg4_tr); inline;
begin
  treg4_r.l := 88;
  treg4_r.b2 := 9;
end;

procedure treg4_t4(out treg4_r: treg4_tr);
begin
  treg4_t3(treg4_r);
end;


var
  treg4_r: treg4_tr;

{$pop}

{ Case toperator6.pas }
{$push}

{$R+}

type  toperator6_Tconstexprint=record
        overflow:boolean;
        case signed:boolean of
          false:
            (uvalue:qword);
          true:
            (svalue:int64);
      end;

operator := (const u:qword):toperator6_Tconstexprint;
begin
  if (u<>high(int64)+100) then
    halt(1);
  result.overflow:=false;
  result.signed:=false;
  result.uvalue:=u;
end;

operator := (const s:int64):toperator6_Tconstexprint;
begin
  if (s<>-128) then
    halt(2);
  result.overflow:=false;
  result.signed:=true;
  result.svalue:=s;
end;


var
  toperator6_value : toperator6_tconstexprint;

{$pop}

{ Case ttypedrecord1.pas }
{$push}


type ttypedrecord1_RGB = record red, green, blue:	integer end;
const ttypedrecord1_kRGBBlack: ttypedrecord1_RGB = ( red: 0; green: 0; blue: 0);

{$pop}

begin

{ Case tw16328.pas }
{$push}

{$r+,q+}
{$inline on}
begin
  tw16328_uid:=tw16328_mydbMakeUID($987654321654,$12345678,$5432,$18273645);
  if (tw16328_uid.CLSID<>$5432) then
    halt(1);
  if (tw16328_uid.DBID<>($987654321654 and tw16328_DBIDMASK)) then
    halt(2);
  if (tw16328_uid.PROID<>$12345678) then
    halt(3);
  if (tw16328_uid.OID<>$18273645) then
    halt(4);
  tw16328_i:=2;
  tw16328_arr[2]:=$987654321654;
  if (tw16328_arr[tw16328_i]<>$987654321654) or
     (tw16328_arr[1]<>0) or
     (tw16328_arr[3]<>0) then
    halt(5);
  tw16328_arr[2]:=0;
  tw16328_arr[tw16328_i]:=$987654321654;
  if (tw16328_arr[tw16328_i]<>$987654321654) or
     (tw16328_arr[1]<>0) or
     (tw16328_arr[3]<>0) then
    halt(6);
end;
{$pop}

{ Case tw21674.pas }
{$push}
{$optimization on}

{$H+}
begin
 SetLength(tw21674_MyArray.Stuff, 100);
 for tw21674_I := 0 to High(tw21674_MyArray.Stuff) do tw21674_MyArray.Stuff[tw21674_I] := tw21674_I;
 tw21674_WriteNumbers(tw21674_MyArray);
end;
{$pop}

{ Case tassign2.pas }
{$push}
{$ifdef fpc}
{$warning Will only work on 32-bit cpu's}

{$endif}
Begin
  WriteLn('secondassign node testing.');
  tassign2_failed := false;
  { possibilities : left : any, right : LOC_REFERENCE, LOC_REGISTER,
    LOC_FPUREGISTER, LOC_CONSTANT, LOC_JUMP and LOC_FLAGS }
  Write('left : LOC_REFERENCE, right : LOC_CONSTANT tests..');
  tassign2_s64bit := tassign2_RESULT_S64BIT;
  if tassign2_s64bit <> tassign2_RESULT_S64BIT then
    tassign2_failed := true;

  tassign2_s32bit := tassign2_RESULT_S32BIT;
  if tassign2_s32bit <> tassign2_RESULT_S32BIT then
    tassign2_failed := true;

  if tassign2_failed then
    tassign2_fail
  else
    WriteLn('Success!');

  Write('left : LOC_REFERENCE, right : LOC_REGISTER tests..');
  tassign2_failed := false;

  tassign2_s64bit := tassign2_getresults64bit;
  if tassign2_s64bit <> tassign2_RESULT_S64BIT then
    tassign2_failed := true;

  tassign2_s32bit := tassign2_getresults32bit;
  if tassign2_s32bit <> tassign2_RESULT_S32BIT then
    tassign2_failed := true;

  tassign2_s16bit := tassign2_getresults16bit;
  if tassign2_s16bit <> tassign2_RESULT_S16BIT then
    tassign2_failed := true;

  tassign2_u8bit := tassign2_getresultu8bit;
  if tassign2_u8bit <> tassign2_RESULT_U8BIT then
    tassign2_failed := true;

  if tassign2_failed then
    tassign2_fail
  else
    WriteLn('Success!');

  Write('left : LOC_REFERENCE, right : LOC_FPUREGISTER tests..');
  tassign2_failed := false;

  tassign2_real_val := tassign2_getresultreal;
  if trunc(tassign2_real_val) <> trunc(tassign2_RESULT_REAL) then
    tassign2_failed := true;

  if tassign2_failed then
    tassign2_fail
  else
    WriteLn('Success!');

  Write('left : LOC_REFERENCE, right : LOC_REFERENCE tests..');
  tassign2_failed := false;

  tassign2_bigrecord1.x := tassign2_RESULT_U32BIT;
  tassign2_bigrecord1.y := tassign2_RESULT_U32BIT;
  for tassign2_i:=0 to tassign2_MAX_INDEX do
    tassign2_bigrecord1.z[tassign2_i] := tassign2_RESULT_U8BIT;

  fillchar(tassign2_bigrecord2, sizeof(tassign2_bigrecord2),#0);

  tassign2_bigrecord2 := tassign2_bigrecord1;

  if tassign2_bigrecord2.x <> tassign2_RESULT_U32BIT then
    tassign2_failed := true;
  if tassign2_bigrecord2.y <> tassign2_RESULT_U32BIT then
    tassign2_failed := true;
  for tassign2_i:=0 to tassign2_MAX_INDEX do
    begin
       if tassign2_bigrecord2.z[tassign2_i] <> tassign2_RESULT_U8BIT then
         begin
           tassign2_failed := true;
           break;
         end;
    end;


  if tassign2_failed then
    tassign2_fail
  else
    WriteLn('Success!');

  Write('left : LOC_REFERENCE, right : LOC_JUMP tests (32-bit cpus only!)..');
  {!!!!! This test will only work on 32-bit CPU's probably, on 64-bit CPUs
    the location should be in LOC_FLAGS
  }
  tassign2_failed := false;

  tassign2_s64bit := tassign2_RESULT_S64BIT;
  tassign2_boolval := tassign2_s64bit = tassign2_RESULT_S64BIT;
  if tassign2_boolval = FALSE then
    tassign2_failed := true;

  if tassign2_failed then
    tassign2_fail
  else
    WriteLn('Success!');


  Write('left : LOC_REFERENCE, right : LOC_FLAGS tests..');
  tassign2_failed := false;

  tassign2_s32bit := tassign2_RESULT_S32BIT;
  tassign2_boolval := tassign2_s32bit = tassign2_RESULT_S32BIT;
  if tassign2_boolval = FALSE then
    tassign2_failed := true;


  if tassign2_failed then
    tassign2_fail
  else
    WriteLn('Success!');


end;
{$pop}

{ Case treg4.pas }
{$push}
{$inline on}

begin
  treg4_t(treg4_f);
  treg4_t2(treg4_r);
  if ((treg4_r.l and 255) <> 7) or
     (treg4_r.b2 <> 31) then
    halt(1);
  treg4_t4(treg4_r);
  if ((treg4_r.l and 255) <> 88) or
     (treg4_r.b2 <> 9) then
    halt(1);
end;
{$pop}

{ Case toperator6.pas }
{$push}

{$R+}
begin
  // Here it should choose the int64 code instead of qword
  toperator6_value:=-128;
  // Here it should choose the qword
  toperator6_value:=high(int64)+100;
end;
{$pop}

{ Case ttypedrecord1.pas }
{$push}

begin
end;
{$pop}

end.
