{ Objects regression cases; original case IDs are retained below. }
{ %NORUN }

{ Case tb0626.pp }
{$push}
{$MODE OBJFPC}

type
  tb0626_tnonmanagedobj = object
    tb0626_d: double;
  end;

var
  tb0626_p: Pointer;
{$pop}

{ Case tw35149.pp }
{$push}
{$mode objfpc}
type
  tw35149_testobject = object
  var
    tw35149_testnested: Integer;
  end;
{$pop}

begin
  { Case tb0626.pp }
  {$push}

  begin
tb0626_p := TypeInfo(tb0626_tnonmanagedobj);
  end;
  {$pop}

  { Case tw35149.pp }
  {$push}

  begin
writeln(SizeOf(tw35149_testobject.tw35149_testnested));
  end;
  {$pop}

end.
