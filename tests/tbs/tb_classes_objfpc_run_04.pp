{ Classes regression cases; original case IDs are retained below. }

{ Case tw8028.pp }
{$push}
{$mode objfpc}
{$inline on}

type
  tw8028_ttest = procedure of object;

  tw8028_tmyrecord = record
    tw8028_test: tw8028_ttest;
  end;

  tw8028_tmyobject = class
    procedure tw8028_test;
  end;

function tw8028_tmyrecordmake(const tw8028_test: tw8028_ttest): tw8028_tmyrecord; inline;
begin
  Result.tw8028_test := tw8028_test;
end;

procedure tw8028_tmyobject.tw8028_test;
begin
  tw8028_tmyrecordmake(nil);
end;
{$pop}

{ Case tw9919.pp }
{$push}
{$mode objfpc}

type
  tw9919_tform1 = class
    function tw9919_crash(n:integer):real;
  end;

function tw9919_tform1.tw9919_crash(n:integer):real;
begin
  case n of
  0: Result:=0;
  1..100: Result:=tw9919_crash(n-1)+tw9919_crash(n-1);
  end;
end;

var
  tw9919_f : tw9919_tform1;
{$pop}

begin
  { Case tw9919.pp }
  {$push}

  begin
tw9919_f:=tw9919_tform1.create;
  writeln(tw9919_f.tw9919_crash(15));
  tw9919_f.Free;
  end;
  {$pop}

end.
