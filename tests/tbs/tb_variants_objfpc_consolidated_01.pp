{ Consolidated variants regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses variants;

{ Case tw20873.pp }
{$push}




var tw20873_SomeArray : array[1..10] of DWord;
    tw20873_v         : Variant;
    tw20873_y: longint;

{$pop}

{ Case tw2763.pp }
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

{ Case tw3227a.pp }
{$push}



var
  tw3227a_a : array of longint;
  tw3227a_v : variant;

{$pop}

{ Case tw37339.pp }
{$push}



function tw37339_VarToObj(const Value: Variant): TObject;
begin
  Result := TObject(Pointer(NativeInt(Value)));
end;


{$pop}

{ Case tw7806.pp }
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

{ Case tw8055.pp }
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

begin

{ Case tw20873.pp }
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

{ Case tw2763.pp }
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

{ Case tw3227a.pp }
{$push}

begin
  setlength(tw3227a_a,1000);
  tw3227a_v:=tw3227a_a;
end;
{$pop}

{ Case tw37339.pp }
{$push}

begin
end;
{$pop}

{ Case tw7806.pp }
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

{ Case tw8055.pp }
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

end.
