{ Interfaces regression cases; original case IDs are retained below. }

{ Case tb0351.pp }
{$push}
{$mode objfpc}
type
   tb0351_i = interface;

   tb0351_i = interface
   end;
{$pop}

{ Case tb0372.pp }
{$push}
{$ifdef fpc}{$mode objfpc}{$endif}
{$J+}

type
   tb0372_imyinterface = interface
      // this program isn't supposed to run so the guid doesn't matter }
      ['{00000000-0000-0000-0000-000000000000}']
      procedure tb0372_p;
   end;

const
   tb0372_iid_imyinterface = tb0372_imyinterface;
   tb0372_iid2 : tguid = '{00000000-0000-0000-0000-000000000000}';

var
   tb0372_g : tguid;
{$pop}

{ Case tb0375.pp }
{$push}
{$ifdef fpc}{$mode objfpc}{$endif}

type
   tb0375_i1 = interface
      procedure tb0375_intfp;
   end;

   tb0375_tc1 = class(tinterfacedobject,tb0375_i1)
      procedure tb0375_i1.tb0375_intfp = tb0375_p;
      procedure tb0375_p;
   end;

procedure tb0375_tc1.tb0375_p;

  begin
  end;
{$pop}

{ Case tb0459.pp }
{$push}
{$mode objfpc}
Type
  tb0459_imyinterface = Interface
    Function tb0459_myfunc : Integer;
  end;

  tb0459_tmyclass = Class(TInterfacedObject,tb0459_imyinterface)
    Function tb0459_myotherfunction : Integer;
    // The following fails in FPC.
    Function tb0459_imyinterface.tb0459_myfunc = tb0459_myotherfunction;
  end;

Function tb0459_tmyclass.tb0459_myotherfunction : Integer;

begin
  Result:=23;
end;

Var
  tb0459_a : tb0459_tmyclass;
  tb0459_m : tb0459_imyinterface;
  tb0459_i : Integer;
{$pop}

{ Case tw1825.pp }
{$push}
{$mode objfpc}

{ Source provided for Free Pascal Bug Report 1825 }
{ Submitted by "marcov" on  2002-02-19 }
{ e-mail: marco@freepascal.org }

Type
    tw1825_ienummoniker = Interface (IUnknown)
       ['{00000102-0000-0000-C000-000000000046}']
       End;
{$pop}

{ Case tw25269.pp }
{$push}
{$MODE objfpc}

type
  tw25269_imyinterface = interface
    procedure tw25269_test(a, b: Integer);
  end;
  tw25269_tmybaseclass = class(TInterfacedObject, tw25269_imyinterface)
    procedure tw25269_test(a, b: Integer); virtual; abstract;
  end;
  tw25269_tdescendent = class(tw25269_tmybaseclass)
    procedure tw25269_test(a, b: Integer); override;
  end;

var
  tw25269_global_a, tw25269_global_b: Integer;

procedure tw25269_tdescendent.tw25269_test(a, b: Integer);
begin
  tw25269_global_a := a;
  tw25269_global_b := b;
end;

var
  tw25269_q: tw25269_imyinterface;
{$pop}

begin
  { Case tb0372.pp }
  {$push}
{$ifdef fpc}
{$endif}
{$J+}
  begin
tb0372_g:=tb0372_imyinterface;
   tb0372_g:=tb0372_iid_imyinterface;
   tb0372_g:=tb0372_iid2;
   tb0372_iid2:=tb0372_iid_imyinterface;
  end;
  {$pop}

  { Case tb0459.pp }
  {$push}

  begin
tb0459_a:=tb0459_tmyclass.Create;
  tb0459_m:=tb0459_a;
  tb0459_i:=tb0459_m.tb0459_myfunc;
  If (tb0459_i<>23) then
    begin
    Writeln('Error calling interface');
    Halt(1);
    end;
  end;
  {$pop}

  { Case tw25269.pp }
  {$push}

  begin
tw25269_q := tw25269_tdescendent.Create;
  tw25269_q.tw25269_test(18, 42);
  if (tw25269_global_a <> 18) or (tw25269_global_b <> 42) then
    halt(1);
  Writeln('Ok!');
  end;
  {$pop}

end.
