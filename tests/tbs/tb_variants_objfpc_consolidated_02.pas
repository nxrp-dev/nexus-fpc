{ Consolidated variants regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses variants;

{ Case tb_variants_objfpc_consolidated_01.pas }
{$push}
{ Consolidated variants regressions; original case IDs and assertions are retained. }




{ Case tw20873.pas }
{$push}




var tw20873_SomeArray : array[1..10] of DWord;
    tw20873_v         : Variant;
    tw20873_y: longint;

{$pop}

{ Case tw2763.pas }
{$push}

{ Source provided for Free Pascal Bug Report 2763 }
{ Submitted by "Michael Van Canneyt" on  2003-11-04 }
{ e-mail: Michael.VanCanneyt@wisa.be }




Type
  tw2763_TMyEnum = (tw2763_One,tw2763_Two,tw2763_Three);

Var
  tw2763_V : Variant;
  tw2763_E : tw2763_TMyEnum;


{$pop}

{ Case tw3227a.pas }
{$push}



var
  tw3227a_a : array of longint;
  tw3227a_v : variant;

{$pop}

{ Case tw37339.pas }
{$push}



function tw37339_VarToObj(const Value: Variant): TObject;
begin
  Result := TObject(Pointer(NativeInt(Value)));
end;


{$pop}

{ Case tw7806.pas }
{$push}


{$H+}


function tw7806_MyFunc(tw7806_aVar : Variant) : Boolean;
begin
  WriteLn(VarToStr(tw7806_aVar[0]));
  Result := False;
end;

var
  tw7806_aVar : Variant;
  tw7806_I : Integer;

{$pop}

{ Case tw8055.pas }
{$push}





var
    tw8055_i: integer;
    tw8055_laenge: integer;
    tw8055_integerbuffer: integer;
    tw8055_integerarray: variant;
    tw8055_singlebuffer: single;
    tw8055_singlearray: variant;
    tw8055_error : boolean;

{$pop}


{$pop}

{ Case testv9.pas }
{$push}
{$ifdef fpc}

{$endif fpc}


var
  testv9_a,testv9_av : array of longint;
  testv9_a2,testv9_av2 : array of array of longint;
  testv9_v,testv9_v2 : variant;
  testv9_i,testv9_j : longint;

{$pop}

{ Case tw26370.pas }
{$push}



procedure tw26370_test;
var
  Bounds: Array [0..1] of TVarArrayBound;
  V1, V2: Variant;
begin
  Bounds[0].lowbound := 0;
  Bounds[0].elementcount := 1;
  Bounds[1].lowbound := 0;
  Bounds[1].elementcount := 0;
  V1 := VarArrayCreate(@Bounds, 2, varVariant);
  V2 := V1; // <- Exception EVariantBadIndexError!!!!!
end;


{$pop}

begin

{ Case tb_variants_objfpc_consolidated_01.pas }
{$push}

{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$H+}
{$pop}
{$push}
{$pop}
begin

{ Case tw20873.pas }
{$push}

begin
  for tw20873_y := 1 to 10 do tw20873_SomeArray[tw20873_y] := 0;
  tw20873_v := 7;
  tw20873_SomeArray[ tw20873_v ] := 1;
  for tw20873_y := 1 to 10 do Write( tw20873_SomeArray[tw20873_y] );
  writeln;
  if tw20873_somearray[tw20873_v]<>1 then
    halt(1);
end;
{$pop}

{ Case tw2763.pas }
{$push}

begin
  tw2763_E:=tw2763_Two;
  tw2763_V:=tw2763_E;
  if tw2763_v>1 then
    begin
      writeln('error 1');
      halt(1);
    end;
  tw2763_E:=tw2763_V;
  if ord(tw2763_e)<>1 then
    begin
      writeln('error 2');
      halt(1);
    end;
end;
{$pop}

{ Case tw3227a.pas }
{$push}

begin
  setlength(tw3227a_a,1000);
  tw3227a_v:=tw3227a_a;
end;
{$pop}

{ Case tw37339.pas }
{$push}

begin
end;
{$pop}

{ Case tw7806.pas }
{$push}

{$H+}
begin
  for tw7806_I := 0 to 10 do
  begin
    tw7806_aVar := VarArrayOf(['Test', 0]);
    tw7806_MyFunc(tw7806_aVar);
  end;
  writeln('ok');
end;
{$pop}

{ Case tw8055.pas }
{$push}

begin
    tw8055_laenge := 20;
    tw8055_integerarray := VarArrayCreate([1,tw8055_laenge],varInteger);
    tw8055_singlearray  := VarArrayCreate([1,tw8055_laenge],varSingle);
    for tw8055_i := 1 to tw8055_laenge do
    begin
	tw8055_integerbuffer := tw8055_i;
	tw8055_singlebuffer  := tw8055_i;
	tw8055_integerarray[tw8055_i] := tw8055_integerbuffer;
	tw8055_singlearray[tw8055_i]  := tw8055_singlebuffer;
    end;

    writeln ('** Program VariantTest **');
    writeln;
    writeln ('integerarray singlearray');
    writeln;
    tw8055_error:=false;
    for tw8055_i := 1 to tw8055_laenge do
    begin
	tw8055_integerbuffer := tw8055_integerarray[tw8055_i];
	tw8055_singlebuffer  := tw8055_singlearray[tw8055_i];
	writeln (tw8055_integerbuffer:12, tw8055_singlebuffer:12:7);
        tw8055_error:=tw8055_error or (tw8055_integerbuffer<>tw8055_singlebuffer);
    end;
    if tw8055_error then
      halt(1)
    else
      writeln('ok');
end;
{$pop}

end;
{$pop}

{ Case testv9.pas }
{$push}
{$ifdef fpc}

{$endif fpc}
begin
  setlength(testv9_a,1000);
  for testv9_i:=0 to high(testv9_a) do
    testv9_a[testv9_i]:=testv9_i;
  testv9_v:=testv9_a;
  for testv9_i:=0 to high(testv9_a) do
    if testv9_v[testv9_i]<>testv9_i then
      begin
        writeln('v[',testv9_i,']=',testv9_v[testv9_i]);
        halt(1);
      end;
  writeln('simple test ok');

  setlength(testv9_a2,10,30);
  for testv9_i:=0 to high(testv9_a2) do
    for testv9_j:=0 to high(testv9_a2[testv9_i]) do
      testv9_a2[testv9_i,testv9_j]:=testv9_i*testv9_j;
  writeln(length(testv9_a2));
  writeln(length(testv9_a2[0]));
  testv9_v2:=testv9_a2;
  for testv9_i:=0 to high(testv9_a2) do
    for testv9_j:=0 to high(testv9_a2[testv9_i]) do
    if testv9_v2[testv9_i,testv9_j]<>testv9_i*testv9_j then
      begin
        writeln('v2[',testv9_i,',',testv9_j,']=',testv9_v2[testv9_i,testv9_j]);
        halt(1);
      end;
  writeln('complex test ok');

  testv9_av:=testv9_v;
  writeln('1d dyn. array:=var. array ok');


  testv9_av2:=testv9_v2;
  if high(testv9_av2)<>VarArrayHighBound(testv9_v2,1) then
   halt(1);
  if high(testv9_av2[0])<>VarArrayHighBound(testv9_v2,2) then
   halt(1);
  writeln('2d dyn. array:=var. array ok');
  writeln('ok');
end;
{$pop}

{ Case tw26370.pas }
{$push}

begin
  tw26370_test;
end;
{$pop}

end.
