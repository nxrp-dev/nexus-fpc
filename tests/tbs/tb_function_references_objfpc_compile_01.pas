{ %norun }
{ Anonymous captured parameters and generic nested function references. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

{ Case tw39736.pas }
{$push}
{$H+}
{$ModeSwitch functionreferences}
{$ModeSwitch anonymousfunctions}

{$warn 5028 error}

type
  tw39736_tproc = reference to procedure;

var
  tw39736_p: tw39736_tproc;
procedure tw39736_fly(tw39736_w: word);
begin
  tw39736_p:=procedure
    begin
      writeln('TBird.Fly w=',tw39736_w);
    end;
  tw39736_p();
end;
{$pop}

{ Case tw39742.pas }
{$push}
{$H+}
{$ModeSwitch nestedprocvars}
{$ModeSwitch functionreferences}

type
  tw39742_tintfunction = reference to function: Integer;

// Works
function tw39742_fourtytwo(const tw39742_aparam: Integer): tw39742_tintfunction;
function tw39742_helper: Integer;
begin
  Result := 42;
end;
begin
  Result := @tw39742_helper
end;

// Error
generic function tw39742_genericfourtytwo<T>: tw39742_tintfunction;
function tw39742_helper: Integer;
begin
  Result := 42;
end;
begin
  Result := @tw39742_helper
end;
{$pop}

begin
  { Case tw39736.pas }
  {$push}
begin
  tw39736_fly(3);
end;
  {$pop}

  { Case tw39742.pas }
  {$push}
begin
end;
  {$pop}

end.
