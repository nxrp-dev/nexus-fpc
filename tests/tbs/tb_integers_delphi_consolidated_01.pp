{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tw0815.pp }
{$push}


function tw0815_T: Integer;
begin
  for Result:=0 to 10 do ;
end;


{$pop}

{ Case tw17430.pp }
{$push}


{$H+}

var
  tw17430_p:pointer;

{$pop}

{ Case tw1907.pp }
{$push}
{ Source provided for Free Pascal Bug Report 1907 }
{ Submitted by "Michail A.Baikov" on  2002-03-31 }
{ e-mail: russia@freepascal.org }
{$ifdef fpc}{$endif}

function tw1907_f:pointer;
begin
  tw1907_f:=nil;
end;

function tw1907_f1(k:byte):Pointer; cdecl;
begin
  result:=tw1907_f;
end;

var
    tw1907_a:function (k:byte):Pointer; cdecl;
    tw1907_b:function:Pointer;

{$pop}

{ Case tw2030.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2030 }
{ Submitted by "Michalis Kamburelis" on  2002-07-06 }
{ e-mail: mkambi@poczta.onet.pl }



{under objfpc mode there will be no bug}

const
  tw2030_err : boolean = true;

procedure tw2030_p;            overload; forward;
procedure tw2030_p(a:integer); overload; forward;

{ it doesn't matter if we add clause "overload"
  to p's definitions below; the error will still
  prevent this code from compiling }

procedure tw2030_p;
begin
  tw2030_err:=false;
end;

procedure tw2030_p(a:integer); overload;
begin end;


{$pop}

{ Case tw2260.pp }
{$push}



procedure tw2260_test(x: integer = 2);
begin
 writeln(x);
end;


{$pop}

{ Case tw23849.pp }
{$push}

{$q+}

function tw23849_F(N: integer) : integer;
var NN : integer;
begin
    NN := N;
    if NN < 0 then NN := 0 - NN;
    result := NN;
end;

procedure tw23849_Crash; cdecl;
var
    N, M : integer;
begin
    N := -10;
    M := tw23849_F(N) div 4;
end;


{$pop}

{ Case tw2778.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2778 }
{ Submitted by "Michael Van Canneyt" on  2003-11-09 }
{ e-mail: michael.vancanneyt@wisa.be }



type
  tw2778_TMyFunc = Procedure (I : Integer = 10);

Procedure tw2778_MyRealFunc(I : Integer = 20);

begin
  Writeln('Function received : ',I);
  if i<>10 then
    halt(1);
end;

Var
  tw2778_M : tw2778_TMyFunc;


{$pop}

{ Case tw29444.pp }
{$push}


procedure tw29444_proc(a: Integer); overload;
  begin
  end;


procedure tw29444_proc(a : NativeInt); overload;
  begin
  end;




{$pop}

{ Case tw32046.pp }
{$push}




function tw32046_add(a, b : Integer) : Int64;
begin
 result := Int64(a) * $FFFFFFFF + b;
end;


{$pop}

{ Case tw38164.pp }
{$push}


const
   tw38164_a = int64($100000000);
 var
   tw38164_b: int64 = 123;
   tw38164_c: int64;

{$pop}

{ Case tw39748a.pp }
{$push}

type
  tw39748a_glenum=word;
  tw39748a_TglGetError = function(): tw39748a_GLenum; cdecl;

function tw39748a_test: tw39748a_glenum; cdecl;
begin
  result:=42;
end;

procedure tw39748a_call(e: longint); overload;
begin
  writeln('longint');
  halt(1);
end;

procedure tw39748a_call(p :tw39748a_tglgeterror); overload;
begin
  writeln('procvar');
end;

var tw39748a_glgeterror : tw39748a_TGlGeterror;

{$pop}

{ Case tw4223.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4223 }
{ Submitted by "Phil Hess" on  2005-07-25 }
{ e-mail: pjhess@purdue.edu }



{$R+}

var
  tw4223_AnInt : Integer;

{$pop}

{ Case tw4922.pp }
{$push}


type
  tw4922_TStream = pointer;
  tw4922_EncodingMemoryProc = function ( pIN, pOUT: PByte; Size: integer; MIMELine: integer = 0): integer;
  tw4922_DecodingMemoryProc = function ( pIN, pOUT: PByte; Size: integer): integer;
var
  tw4922_err : boolean;

function tw4922_SZFullEncodeBase64(sIN, sOUT: tw4922_TStream; Size: integer=-1; MIMELine: integer = 0): integer; overload;
begin
end;

function tw4922_SZFullEncodeBase64(pIN, pOUT: PByte; Size: integer; MIMELine: integer = 0): integer; overload;
begin
  tw4922_err:=false;
  writeln('success');
end;

function tw4922_SZDecodeBase64(pIN, pOUT: PByte; Size: integer): integer; overload;
begin
end;

function tw4922_SZDecodeBase64(sIN, sOUT: tw4922_TStream): integer; overload;
begin
end;

function tw4922_DoEncodingMemory( Encoding: tw4922_EncodingMemoryProc; Decoding: tw4922_DecodingMemoryProc): integer;
begin
  Encoding(nil,nil,0);
end;



{$pop}

{ Case tw6686.pp }
{$push}


function tw6686_test: byte; forward;

function tw6686_test;
begin
  tw6686_test:=5;
end;


{$pop}

{ Case tw7200.pp }
{$push}


var tw7200_i : integer;

function tw7200_GetInt : integer;
begin
 Result := 10;
end;


 var tw7200_myfunc : function : integer;



{$pop}

begin

{ Case tw0815.pp }
{$push}

begin
  tw0815_T;
end;
{$pop}

{ Case tw17430.pp }
{$push}

{$H+}
begin
  returnnilifgrowheapfails:=true;
  { Use a bigger absolute value to avoid
    getting a overflow inside heaptrc
    if compiled with -gh option:
    -128 changed to -1024,
    which should be larger than typical
    size of extra memory used by heaptrc }
  GetMem(tw17430_p,ptruint(-1024));
  if assigned(tw17430_p) then
    halt(1);
end;
{$pop}

{ Case tw1907.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
    tw1907_a:=tw1907_f1;
    tw1907_b:=tw1907_a(0);
end;
{$pop}

{ Case tw2030.pp }
{$push}

begin
  tw2030_p;
  if tw2030_err then
   halt(1);
end;
{$pop}

{ Case tw2260.pp }
{$push}

begin
 tw2260_test(1);
 tw2260_test;
end;
{$pop}

{ Case tw23849.pp }
{$push}

{$q+}
begin
  tw23849_Crash;
end;
{$pop}

{ Case tw2778.pp }
{$push}

begin
  tw2778_M:=@tw2778_MyRealFunc;
  tw2778_M;
end;
{$pop}

{ Case tw29444.pp }
{$push}

begin
end;
{$pop}

{ Case tw32046.pp }
{$push}

begin

 writeLn(tw32046_add(200210, 1)); // Linux x86_64: 859895402131951
                          // Windows i386: -200209
 if tw32046_add(200210, 1)<>859895402131951 then
   halt(1);
end;
{$pop}

{ Case tw38164.pp }
{$push}

begin
  tw38164_c := tw38164_b mod tw38164_a;
  if tw38164_c <> 0 then
  begin
  end;
end;
{$pop}

{ Case tw39748a.pp }
{$push}

begin
  tw39748a_glgeterror:=tw39748a_test;
  tw39748a_call(tw39748a_glgeterror)
end;
{$pop}

{ Case tw4223.pp }
{$push}

{$R+}
begin

  tw4223_AnInt := -1;
  if tw4223_AnInt in [1,2,3] then
    WriteLn('In set')
  else
    WriteLn('Not in set');

end;
{$pop}

{ Case tw4922.pp }
{$push}

begin
  tw4922_err:=true;
  tw4922_DoEncodingMemory(
    tw4922_SZFullEncodeBase64,
    tw4922_SZDecodeBase64);
  if tw4922_err then
    begin
      writeln('Error!');
      halt(1);
    end;
end;
{$pop}

{ Case tw6686.pp }
{$push}

begin
end;
{$pop}

{ Case tw7200.pp }
{$push}

begin

 tw7200_myfunc := tw7200_GetInt;

 //i := integer(myfunc) div 2; //works
 //i := myfunc; i := i div 2; //works
 tw7200_i := tw7200_myfunc div 2; //does not work
 if (tw7200_i <> 5) then
   halt(1);

 tw7200_i := tw7200_myfunc shr 2;
 if tw7200_i <> 2 then
   halt(2);

 tw7200_i := not tw7200_myfunc;
 if tw7200_i <> not(integer(10)) then
   halt(3);

end;
{$pop}

end.
