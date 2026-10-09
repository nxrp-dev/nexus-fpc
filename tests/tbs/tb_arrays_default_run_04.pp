{ Arrays regression cases; original case IDs are retained below. }

{ Case tw1938.pp }
{$push}
{$inline on }

var tw1938_a: array [0..1] of Integer;

function tw1938_f: Integer; inline;
begin
  tw1938_f := tw1938_a[1];
end;
{$pop}

{ Case tw2280.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2280 }
{ Submitted by "Yakov Sudeikin" on  2002-12-23 }
{ e-mail: yashka@exebook.com }
var
 tw2280_a: array of string;
{$pop}

{ Case tw2525.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2525 }
{ Submitted by "Pavel V. Ozerski" on  2003-06-05 }
{ e-mail: ozerski@list.ru }
procedure tw2525_myproc(x:array of longint);
 begin
   writeln(high(x));
   if high(x)<>2 then
     halt(1);
 end;
type
 tw2525_tmyenum=(My1,My2,My3);
var
 tw2525_ar:array[tw2525_tmyenum]of longint;
{$pop}

{ Case tw25349.pp }
{$push}
procedure tw25349_trashstack;
var
  tw25349_a: array[0..high(word)] of byte;
begin
  fillchar(tw25349_a,sizeof(tw25349_a),$ff);
end;

procedure tw25349_test;
var
  tw25349_s1,tw25349_s2,tw25349_s3,tw25349_s4: ansistring;
begin
  tw25349_s2:='';
  tw25349_s3:='';
  tw25349_s4:='';
  tw25349_s1:=tw25349_s2+tw25349_s3+tw25349_s4;
  if tw25349_s1<>'' then
    halt(1);
end;
{$pop}

{ Case tw2561.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2561 }
{ Submitted by "Nikolay Nikolov" on  2003-07-06 }
{ e-mail: nickysn1983@netscape.net }
Procedure tw2561_tralala(Var tw2561_q);

Begin
  Writeln(SizeOf(tw2561_q));
  if sizeof(tw2561_q)<>0 then
    halt(1);
End;

Var
  tw2561_q : Integer;
  tw2561_w : Array[1..10] Of Integer;
{$pop}

{ Case tw2620.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2620 }
{ Submitted by "Louis Jean-Richard" on  2003-08-04 }
{ e-mail: l.jean-richard@bluewin.ch }
CONST
        tw2620_prime   : ARRAY[1 .. 4] OF cardinal =
        ( 536870909, 1073741789, 2147483647, 4294967291);
{$pop}

{ Case tw2803.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2803 }
{ Submitted by "C Western" on  2003-11-22 }
{ e-mail: mftq75@dsl.pipex.com }

{$T+}
var
  tw2803_a: array of Double;
{$pop}

{ Case tw2876.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2876 }
{ Submitted by "marco (gory bugs department)" on  2004-01-04 }
{ e-mail:  }
function tw2876_strtoppchar(const tw2876_args:array of ansistring):ppchar;

begin
end;

function tw2876_execl (filename:ansistring;const tw2876_args:array of ansistring):integer;

var tw2876_p:ppchar;

begin
 tw2876_p:=tw2876_strtoppchar(tw2876_args);
end;

procedure tw2876_myexec (filename:ansistring;const tw2876_args:array of ansistring);

begin
 tw2876_execl(filename,tw2876_args);
end;
{$pop}

{ Case tw2912.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2912 }
{ Submitted by "Bill Pearce" on  2004-01-19 }
{ e-mail: pearceg@post.queensu.ca }
procedure tw2912_setrowcount(n,m : integer);
var
  tw2912_tmp : array of array of string;
begin
  SetLength(tw2912_tmp, n, m);
end;
{$pop}

{ Case tw3012.pp }
{$push}
Type tw3012_char2=Array[1..2] of char;

var tw3012_c1,tw3012_c2:tw3012_char2;
    tw3012_st:string;

Procedure tw3012_writelength(s:string; tw3012_shouldbe: longint);
begin
  WriteLn(s+' ',Length(s));
  if length(s) <> tw3012_shouldbe then
    halt(1);
end;
{$pop}

{ Case tw3113.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3113 }
{ Submitted by "Michalis Kamburelis" on  2004-05-23 }
{ e-mail: michalis@camelot.homedns.org }
type
  tw3113_tvector3 = array[0..2]of Integer;

procedure tw3113_p(const A:array of tw3113_tvector3);
var tw3113_i:Integer;
begin
 Writeln(High(A));

 if High(A)<>0 then
   begin
     writeln('Error!');
     halt(1);
   end;

 for tw3113_i:=0 to High(A) do
  Writeln('  ', A[tw3113_i][0], ' ', A[tw3113_i][1], ' ', A[tw3113_i][2]);
end;

const tw3113_a1:tw3113_tvector3 = (1, 2, 3);
{$pop}

{ Case tw33004.pp }
{$push}
const
  tw33004_inputs: array[0..2] of QWord = (500, $4563918244F40000,QWord($8AC7230489E80000));

var tw33004_x, tw33004_y: QWord; tw33004_c: Integer;
{$pop}

begin
  { Case tw1938.pp }
  {$push}
{$inline on }
  begin
tw1938_a[0] := 1234;
  tw1938_a[1] := 5678;
  WriteLn(tw1938_f); { writes 1234 }
  if tw1938_f<>5678 then
   begin
     Writeln('ERROR!');
     Halt(1);
   end;
  end;
  {$pop}

  { Case tw2280.pp }
  {$push}

  begin
tw2280_a := nil;
 if tw2280_a = nil then;
  end;
  {$pop}

  { Case tw2525.pp }
  {$push}

  begin
tw2525_myproc(tw2525_ar);
  end;
  {$pop}

  { Case tw25349.pp }
  {$push}

  begin
tw25349_trashstack;
  tw25349_test;
  end;
  {$pop}

  { Case tw2561.pp }
  {$push}

  begin
tw2561_tralala(tw2561_q);
  tw2561_tralala(tw2561_w);
  end;
  {$pop}

  { Case tw2620.pp }
  {$push}

  begin
WriteLn( 'HIGH(cardinal) = ', HIGH(cardinal) );
        WriteLn( '4294967291 < HIGH(cardinal) ', (4294967291 < HIGH(cardinal)) , ' !?');
    if not(4294967291 < HIGH(cardinal)) then
      halt(1);
        WriteLn(tw2620_prime[4])
  end;
  {$pop}

  { Case tw2803.pp }
  {$push}
{$T+}
  begin
SetLength(tw2803_a,100);
  end;
  {$pop}

  { Case tw2876.pp }
  {$push}

  begin
tw2876_myexec('',['','']);
  end;
  {$pop}

  { Case tw2912.pp }
  {$push}

  begin
tw2912_setrowcount(10,2);
  end;
  {$pop}

  { Case tw3012.pp }
  {$push}

  begin
tw3012_c1:=#0#65;
  tw3012_c2:=#66#0;
  tw3012_st:=tw3012_c1+tw3012_c2;
  tw3012_writelength(tw3012_st,4);	{BP:4; FP:1}
  tw3012_writelength(tw3012_c1,2);	{BP:2; FP:0}
  tw3012_writelength(tw3012_c2,2);	{BP:2; FP:1}
  tw3012_writelength(tw3012_c1+tw3012_c2,4);	{BP:4; FP:1}
  tw3012_writelength(tw3012_c2+tw3012_c1,4);	{BP:4; FP:1}
  end;
  {$pop}

  { Case tw3113.pp }
  {$push}

  begin
tw3113_p(tw3113_a1);
 { When changed to P([A1]), works OK. }
  end;
  {$pop}

  { Case tw33004.pp }
  {$push}

  begin
for tw33004_c := Low(tw33004_inputs) to High(tw33004_inputs) do
  begin
    tw33004_x := tw33004_inputs[tw33004_c];
    tw33004_y := tw33004_x div QWord($8AC7230489E80000);
    WriteLn(tw33004_x, ' div 10,000,000,000,000,000,000 = ', tw33004_y);
  end;
  end;
  {$pop}

end.
