{ Consolidated floating point regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tb0209.pp }
{$push}
{ Old file: tbs0247.pp }
{ var with initial value not supported (Delphi var x : integer = 5;) allowed in -Sd mode OK 0.99.11 (PM) }



var
 tb0209_x : integer = 34;
{ this is the way Delphi creates initialized vars
  ++ its much more logical then BP
  typed const !!
  -- its incompatible with BP !! (PM) }

 tb0209_y : array[0..2] of real = (0.0,1.23,2.56);

{ these are true const in Delphi mode and thus
  it should not be possible to change ! }

const
 tb0209_z : real = 45.2;


{$pop}

{ Case tw1901.pp }
{$push}

{$ifdef fpc}

{$endif}

{ Range and overflow checks need to be off }

{$Q-}
{$R-}

const tw1901_Inf=extended(1/0);
      tw1901_NaN=extended(0/0);
      tw1901_MinusInf=extended(-tw1901_Inf);

function tw1901_make_str( tail: string ): string;
var
    float: extended;
    test: string;
    n_test, n_tail: integer;
begin
    float := 0;
    str( float, test );
    n_test := length( test );
    n_tail := length( tail );
    if ( n_test <= n_tail ) then
        tw1901_make_str := tail
    else
      begin
        fillchar( test[ 1 ], n_test - n_tail, ' ' );
        move( tail[ 1 ], test[ n_test - n_tail + 1 ], n_tail );
        tw1901_make_str := test;
      end;
end;

var
  tw1901_s : string;
  tw1901_error : boolean;
  tw1901_s1, tw1901_s2, tw1901_s3 : string;

{$pop}

{ Case tw7195.pp }
{$push}


Function tw7195_Test(S : single) : single;
begin
  Result := sqrt(s);
end;

Function tw7195_Test2(S : single) : single;
begin
  Result := sqr(s);
end;


{$pop}

{ Case tw8225.pp }
{$push}



const
	tw8225_factor	:	double	=	1.0;


function tw8225_CheckLongint(count,wcount:longint):double;
begin
	result:=(count+wcount)*tw8225_factor;
end;


function tw8225_CheckCardinal(count,wcount:cardinal):double;
begin
	result:=(count+wcount)*tw8225_factor;
end;



{$pop}

{ Case tw8677.pp }
{$push}


function tw8677_REGVAR(InputBuffer : Pointer): double;
var
  x: integer;
  temp, y: double;
begin
  x := 1;
  y := 1;

  temp := exp((x/y));

  Result:= Temp;
end;

var
   tw8677_Ptr1: pointer;

{$pop}

begin

{ Case tb0209.pp }
{$push}

begin
 tb0209_y[2]:=tb0209_z;
 { this should be refused ! }
 tb0209_z:=tb0209_y[1];
end;
{$pop}

{ Case tw1901.pp }
{$push}
{$ifdef fpc}

{$endif}
{$Q-}
{$R-}
begin
  tw1901_s1 := tw1901_make_str( '+Inf' );
  tw1901_s2 := tw1901_make_str( 'Nan' );
  tw1901_s3 := tw1901_make_str( '-Inf' );
  tw1901_error:=false;
  str(tw1901_Inf,tw1901_s);
  writeln('Inf: "',tw1901_s,'"');
  if tw1901_s<>tw1901_s1 then
   tw1901_error:=true;
  str(tw1901_NaN,tw1901_s);
  writeln('Nan: "',tw1901_s,'"');
  if tw1901_s<>tw1901_s2 then
   tw1901_error:=true;
  str(tw1901_MinusInf,tw1901_s);
  writeln('MinusInf: "',tw1901_s,'"');
  if tw1901_s<>tw1901_s3 then
   tw1901_error:=true;
  if tw1901_error then
   begin
     writeln('ERROR!');
     halt(1);
   end;
end;
{$pop}

{ Case tw7195.pp }
{$push}

begin
 writeln(tw7195_Test(0.123445));
 writeln(tw7195_Test2(0.123445));
end;
{$pop}

{ Case tw8225.pp }
{$push}

begin
	writeln('LONGINT:  ',tw8225_CheckLongint(3,1));
	writeln('CARDINAL: ',tw8225_CheckCardinal(3,1));
end;
{$pop}

{ Case tw8677.pp }
{$push}

begin
    tw8677_Ptr1 := 0;
    tw8677_REGVAR(tw8677_Ptr1);
    writeln('Test Complete.');
end;
{$pop}

end.
