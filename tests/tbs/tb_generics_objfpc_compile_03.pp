{ Generics regression cases; original case IDs are retained below. }
{ %NORUN }

{ Case tb0726.pp }
{$push}
{$mode objfpc}{$H+}

type
  generic tb0726_ttest1<T> = class
    procedure tb0726_test;
  end;

  generic tb0726_ttest2<T> = class
    procedure tb0726_test;
  end;

procedure tb0726_ttest1.tb0726_test;
begin
end;

procedure tb0726_test;
type
  tb0726_tarr = packed array [0..1] of Single;
  tb0726_ttest1arr = specialize tb0726_ttest1<tb0726_tarr>;
  tb0726_ttest2arr = specialize tb0726_ttest2<tb0726_tarr>;
var
  tb0726_a: tb0726_ttest1arr;
  tb0726_b: tb0726_ttest2arr;
begin
  tb0726_a := tb0726_ttest1arr.Create;
  tb0726_a.Free;
  tb0726_b := tb0726_ttest2arr.Create;
  tb0726_b.Free;
end;

procedure tb0726_ttest2.tb0726_test;
begin
end;
{$pop}

{ Case tw28832.pp }
{$push}
{$mode objfpc}{$H+}

generic procedure tw28832_test<T>(AValue : T);
begin
  WriteLn(Low(AValue));
  WriteLn(Low(T));
  WriteLn(High(AValue));
  WriteLn(High(T));
end;
{$pop}

{ Case tw36496b.pp }
{$push}
(*
  testing application for
  https://forum.lazarus.freepascal.org/index.php/topic,47936.0.html
*)

{$Mode objfpc}{$H+}

generic function tw36496b_testgenrecurse<T>(const AInput : T) : Boolean;
begin
  //Result := False;

  (*
    below, if uncommented will fail to compile
    tester.lpr(12,19) Error: Identifier not found "TestGenRecurse$1"
  *)
  specialize tw36496b_testgenrecurse<T>(AInput);
  specialize tw36496b_testgenrecurse<String>('test');
  specialize tw36496b_testgenrecurse<LongInt>(42);
end;

generic procedure tw36496b_testgenrecurseproc<T>(const AInput : T);
begin
  (*
    below method calls compile fine
  *)
  specialize tw36496b_testgenrecurseproc<T>(AInput);
  specialize tw36496b_testgenrecurseproc<String>('test');
  specialize tw36496b_testgenrecurseproc<LongInt>(42);
end;
{$pop}

begin
  { Case tw28832.pp }
  {$push}

  begin
specialize tw28832_test<Integer>(0);
  end;
  {$pop}

  { Case tw36496b.pp }
  {$push}

  begin
specialize tw36496b_testgenrecurse<String>('testing');
  specialize tw36496b_testgenrecurseproc<String>('testing');
  end;
  {$pop}

end.
