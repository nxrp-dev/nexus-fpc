{ Inherited overload dispatch, class-reference Is checks and repeated object destruction. }
{ Original case IDs and variable scopes are retained below. }

{$mode delphi}

uses SysUtils;

{ Case tb0577.pp }
{$push}
type
  tb0577_tc = class
    procedure tb0577_test(tb0577_b: byte);virtual;overload;
  end;

  tb0577_tc2 = class(tb0577_tc)
   strict protected
    procedure tb0577_test(tb0577_b: byte; tb0577_l: longint = 1234);virtual;overload;
   public
    procedure tb0577_test(tb0577_l: longint);virtual;overload;
  end;

  tb0577_tc3 = class(tb0577_tc2)
    procedure tb0577_test(tb0577_b: byte);override;overload;
  end;

var
  tb0577_glob: longint;

  procedure tb0577_tc.tb0577_test(tb0577_b: byte);
    begin
      tb0577_glob:=2;
    end;

  procedure tb0577_tc2.tb0577_test(tb0577_l: longint);
    begin
      tb0577_glob:=1;
    end;

  procedure tb0577_tc2.tb0577_test(tb0577_b: byte; tb0577_l: longint = 1234);
    begin
      tb0577_glob:=3;
    end;

  procedure tb0577_tc3.tb0577_test(tb0577_b: byte);
    begin
      inherited;
    end;

var
  tb0577_c: tb0577_tc;
{$pop}

{ Case tb0203.pp }
{$push}
{ Old file: tbs0239.pp }
{ No warning for uninitialized class in IS statements  OK 0.99.11 (PM) }
   type
     tb0203_ttest=class
     end;
     tb0203_ttest2 = class(tb0203_ttest)
     end;
     tb0203_ttestclass=class of tb0203_ttest;
   var
     tb0203_i,tb0203_j:tb0203_ttest;
     tb0203_tt:tclass;
{$pop}

{ Case tb0174.pp }
{$push}
{ Old file: tbs0207.pp }
{ a class destructor doesn't release the memory        OK 0.99.11 (FK) }



 var tb0174_i : longint;
{$pop}

begin
  { Case tb0577.pp }
  {$push}
begin
  tb0577_c:=tb0577_tc3.create;
  tb0577_c.tb0577_test(byte(4));
  if tb0577_glob<>2 then
    halt(1);
end;
  {$pop}

  { Case tb0203.pp }
  {$push}
begin
     tb0203_tt:=tb0203_ttest;
     tb0203_i:=tb0203_ttest.create;
     tb0203_j:=tb0203_ttest2.create;
     Writeln('tt is a class of ttest initialized by "tt:=ttest"');
     Writeln('i is a ttest class initialized by "i:=ttest.create"');
     Writeln('j is a ttest class initialized by "j:=ttest2.create"');
     writeln('i is tobject ',tb0203_i is tobject);
     if not(tb0203_i is tobject) then
       Halt(1);
     writeln('i is tt ',tb0203_i is tb0203_tt);
     if not(tb0203_i is tb0203_tt) then
       Halt(1);
     writeln('i is ttest ',tb0203_i is tb0203_ttest);
     if not(tb0203_i is tb0203_ttest) then
       Halt(1);
     writeln('i is ttest2 ',tb0203_i is tb0203_ttest2);
     if (tb0203_i is tb0203_ttest2) then
       Halt(1);
     writeln('j is tobject ',tb0203_j is tobject);
     if not(tb0203_j is tobject) then
       Halt(1);
     writeln('j is tt ',tb0203_j is tb0203_tt);
     if not(tb0203_j is tb0203_tt) then
       Halt(1);
     writeln('j is ttest ',tb0203_j is tb0203_ttest);
     if not(tb0203_j is tb0203_ttest) then
       Halt(1);
     writeln('j is ttest2 ',tb0203_j is tb0203_ttest2);
     if not(tb0203_j is tb0203_ttest2) then
       Halt(1);
   end;
  {$pop}

  { Case tb0174.pp }
  {$push}
begin
   for tb0174_i:=1 to 100 do
     tobject.create.free;
end;
  {$pop}

end.
