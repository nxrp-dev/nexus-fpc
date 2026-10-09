{ Classes regression cases; original case IDs are retained below. }

{ Case tb0595.pp }
{$push}
{$mode delphi}{$h+}

type
  tb0595_tc = class
    class procedure tb0595_test; static;
  end;

  tb0595_tp = procedure;

var
  tb0595_global: longint;

  class procedure tb0595_tc.tb0595_test;
    begin
      tb0595_global:=1;
    end;

var
  tb0595_p: tb0595_tp;
{$pop}

{ Case tw2220.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2220 }
{ Submitted by "marco" on  2002-11-06 }
{ e-mail: marcov@freepascal.org }
{$H+}
{$ifdef fpc}{$MODE DELPHI}{$endif}
// NO OUTPUT, GDB SHOWS SIGSEGV IN DECR_REF

type tw2220_bla=class
        tw2220_freceivebuffer : array[0..4095] of char;
        tw2220_flastresponse  : String;
        procedure tw2220_themethod;
        end;

procedure tw2220_bla.tw2220_themethod;
        var tw2220_i : longint;
        begin
         tw2220_i:=12;
         tw2220_flastresponse:=copy(tw2220_freceivebuffer,1,tw2220_i-1);
         writeln('point 1: ',tw2220_flastresponse);
        end;

var tw2220_x : tw2220_bla;
{$pop}

begin
  { Case tb0595.pp }
  {$push}

  begin
tb0595_p:=tb0595_tp(tb0595_tc.tb0595_test);
  tb0595_p();
  if tb0595_global<>1 then
    halt(1);
  end;
  {$pop}

  { Case tw2220.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tw2220_x:=tw2220_bla.create;
  tw2220_x.tw2220_freceivebuffer:='test string is wrong!';
  tw2220_x.tw2220_themethod;
  writeln('point 2');
  end;
  {$pop}

end.
