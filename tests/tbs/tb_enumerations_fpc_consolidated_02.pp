{ Consolidated enumerations regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tw14174.pp }
{$push}


type
  tw14174_TToken = (
    tw14174_tkNil,tw14174_tkEOF,tw14174_tkNumber,tw14174_tkOpenBrace,tw14174_tkCloseBrace,
    tw14174_tkPlus,tw14174_tkMinus,tw14174_tkTimes,tw14174_tkSlash,tw14174_tkCaret,tw14174_tkSemiColon
  );

function tw14174_TokenToStr(const Token: tw14174_TToken): String;

  function Quote(const S: String): String;
  inline; // comment out to avoid the internal error
  begin
    Quote:='"'+S+'"';
  end;

begin
  case Token of
    tw14174_tkNil : tw14174_TokenToStr:=Quote('Unknown');
    tw14174_tkEOF : tw14174_TokenToStr:=Quote('EOF');
    tw14174_tkNumber : tw14174_TokenToStr:=Quote('Number');
    tw14174_tkOpenBrace : tw14174_TokenToStr:=Quote('(');
    tw14174_tkCloseBrace: tw14174_TokenToStr:=Quote(')');
    tw14174_tkPlus : tw14174_TokenToStr:=Quote('+');
    tw14174_tkMinus : tw14174_TokenToStr:=Quote('-');
    tw14174_tkTimes : tw14174_TokenToStr:=Quote('*');
    tw14174_tkSlash : tw14174_TokenToStr:=Quote('/');
    tw14174_tkCaret : tw14174_TokenToStr:=Quote('^');
    tw14174_tkSemiColon : tw14174_TokenToStr:=Quote(';');
  end;
end;


{$pop}

{ Case tw15169.pp }
{$push}

type
  tw15169_TDragHandleStyle = (tw15169_dhDouble, tw15169_dhNone, tw15169_dhSingle);


var tw15169_b : boolean;
    tw15169_fdraghandlestyle : tw15169_TDraghandlestyle;
    tw15169_i : longint;

{$pop}

{ Case tw2267.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2267 }
{ Submitted by "Marco" on  2002-12-19 }
{ e-mail: marco@freepascal.org }
type tw2267_theenum=(tw2267_aa,tw2267_bb,tw2267_cc);

var tw2267_i,tw2267_j : integer;
    tw2267_k  :tw2267_theenum;


{$pop}

{ Case tw27256.pp }
{$push}


type
  tw27256_FullType = (tw27256_Unknown,tw27256_Stiletto,tw27256_Vanguard);
  tw27256_SubType = tw27256_Stiletto..tw27256_Vanguard;

const
  tw27256_full_choices: array[tw27256_FullType] of String = ('U','S','V');
  tw27256_sub_choices: array[tw27256_SubType] of String = ('S', 'V');

var
  tw27256_x : longint;

procedure tw27256_abc(choices: array of String);
begin
  inc(tw27256_x,high(choices));
end;


{$pop}

{ Case tw3666.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3666 }
{ Submitted by "marco" on  2005-02-17 }
{ e-mail:  }

Type
     tw3666_otherset = ( tw3666_bla =5, tw3666_bla2=9,tw3666_bla3=tw3666_bla+tw3666_bla2);


{$pop}

{ Case tw40908.pp }
{$push}
{$minenumsize 1}
type
	tw40908_MyEnum = (tw40908_a, tw40908_b, tw40908_c);
var
	tw40908_e: tw40908_MyEnum;

{$pop}

{ Case tw41019.pp }
{$push}
{$packenum 1}
type
  tw41019_tA = (tw41019_an1 = -1, tw41019_a255 = 255);
  tw41019_tB = (tw41019_bn1 = -1, tw41019_b128 = 128);
  tw41019_tC = (tw41019_cn127 = -127, tw41019_c128 = 128);
  tw41019_tD = (tw41019_dn1= -1, tw41019_d65535 = 65535);
var
  tw41019_a: tw41019_tA; tw41019_b: tw41019_tB; tw41019_c: tw41019_tC; tw41019_d: tw41019_tD;
  tw41019_size, tw41019_failures: integer;

{$pop}

begin

{ Case tw14174.pp }
{$push}

begin
  if (tw14174_TokenToStr(tw14174_tkNil)<>'"Unknown"') then
    halt(1);
end;
{$pop}

{ Case tw15169.pp }
{$push}

begin
  tw15169_i:=0;
  tw15169_FDraghandlestyle:=tw15169_dhDouble;
  for tw15169_B := False to (tw15169_FDragHandleStyle = tw15169_dhDouble) do
   inc(tw15169_i);
  if (tw15169_i<>2) then
    halt(1);
end;
{$pop}

{ Case tw2267.pp }
{$push}

begin
 tw2267_k:=tw2267_theenum(tw2267_i<tw2267_j);
end;
{$pop}

{ Case tw27256.pp }
{$push}

begin
  tw27256_abc(tw27256_full_choices);
  tw27256_abc(tw27256_sub_choices);
  if tw27256_x<>3 then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tw3666.pp }
{$push}

begin
end;
{$pop}

{ Case tw40908.pp }
{$push}
{$minenumsize 1}
begin
	tw40908_e := tw40908_MyEnum(random(0) = 0);
    if ord(tw40908_e)<>1 then
      halt(1);
	writeln('sizeof(e) = ', sizeof(tw40908_e), ', ord(e) = ', ord(tw40908_e));
end;
{$pop}

{ Case tw41019.pp }
{$push}
{$packenum 1}
begin
  tw41019_failures := 0;
  tw41019_size := sizeOf(tw41019_tA);
  if tw41019_size <> sizeof(smallint) then
    inc( tw41019_failures); // size = 1
  tw41019_a := tw41019_a255;
  if ord(tw41019_a) <> 255 then
    inc( tw41019_failures); // (a = -1)

  tw41019_size := sizeOf(tw41019_tB);
  if tw41019_size <> sizeof(smallint) then
    inc( tw41019_failures); // size = 1
  tw41019_b := tw41019_b128;
  if ord(tw41019_b) <> 128 then
    inc( tw41019_failures); // (b = -128)

  tw41019_size := sizeOf(tw41019_tC);
  if tw41019_size <> sizeof(smallint) then
    inc( tw41019_failures); // size = 1
  tw41019_c := tw41019_c128;
  if ord(tw41019_c) <> 128 then
    inc( tw41019_failures); // (c = -128)

  tw41019_size := sizeOf(tw41019_tD);
  if tw41019_size <> sizeof(longint) then
    inc( tw41019_failures); // size = 2
  tw41019_d := tw41019_d65535;
  if ord(tw41019_d) <> 65535 then
    inc( tw41019_failures); // (d = -1)

  assert( tw41019_failures = 0); // (failures = 8)
  if tw41019_failures>0 then
    halt(1);
  writeln('ok');
end;
{$pop}

end.
