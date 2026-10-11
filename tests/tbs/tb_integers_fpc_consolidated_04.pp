{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}
uses sysutils;

{ Case tw1532.pp }
{$push}

 
 Var tw1532_I : Longint;
     tw1532_a:char;

 
{$pop}

{ Case tw2691.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2691 }
{ Submitted by "Luk Vandelaer" on  2003-09-22 }
{ e-mail: luk.vandelaer@wisa.be }




var
  tw2691_x : int64;


{$pop}

{ Case tw30166.pp }
{$push}
{ Test against Mantis #30166, an issue in the i386 fpc_div_int64 helper. }


Var tw30166_cc, tw30166_dd: int64;
    tw30166_a, tw30166_b: int64;


{$pop}

{ Case tw3235.pp }
{$push}

  

var tw3235_l: longint;

{$pop}

begin

{ Case tw1532.pp }
{$push}

begin
 tw1532_a:='A';
 tw1532_a:=upcase(tw1532_a);   //OK

 Writeln;
 Writeln (Lowercase('ABCDEFGHIJKLMNOPQRSTUVWXYZ')); //OK
 Writeln (Lowercase(tw1532_A)); // OK
 tw1532_a:=Lowercase(tw1532_A);        // ERROR
 Writeln (tw1532_a);
 end;
{$pop}

{ Case tw2691.pp }
{$push}

begin
  tw2691_x := $FFFF shl 32;
  writeln (format ('%d %d %d',
    [tw2691_x mod $10000, tw2691_x div $10000, tw2691_x div $10000]));
end;
{$pop}

{ Case tw30166.pp }
{$push}

Begin
 tw30166_dd:=int64($0000000A6BB38805);
 tw30166_cc:=int64($0000000000142E04);
 tw30166_cc:=tw30166_cc-2822400; { $FF11813BCCC3B114 }
 tw30166_dd:=tw30166_dd*tw30166_cc;

{ dd:=int64($FF11813BCCC3B114); }

 tw30166_a:=tw30166_dd div int64($00000000002B1100);
 tw30166_b:=int64($FF11813BCCC3B114) div int64($00000000002B1100);

 WriteLn(IntToHex(tw30166_cc,16));
 WriteLn(IntToHex(tw30166_dd,16));
 WriteLn('FF11813BCCC3B114:00000000002B1100='#9, IntToHex(tw30166_a,16));
 WriteLn('FF11813BCCC3B114:00000000002B1100='#9, IntToHex(tw30166_b,16));

 if tw30166_a<>tw30166_b then
  begin
    writeln('Failed!');
    halt(1);
  end
 else
  begin
    writeln('Passed!');
  end;
End;
{$pop}

{ Case tw3235.pp }
{$push}

begin
  tw3235_l := StrIComp('abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ');
  if (tw3235_l <> 0) then
    begin
      writeln('error: expected 0, got ',tw3235_l);
      halt(1);
    end;
  tw3235_l := StrIComp('ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz');
  if (tw3235_l <> 0) then
    begin
      writeln('error: expected 0, got ',tw3235_l);
      halt(1);
    end;
end;
{$pop}

end.
