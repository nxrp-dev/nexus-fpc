{ Var-parameter casts and overload selection with ordinal arguments. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0159.pp }
{$push}
{ Old file: tbs0190.pp }
{ can't have typecast for var params ??                 OK 0.99.11 (PM) }

procedure tb0159_a(var tb0159_b: boolean);
begin
  tb0159_b:=true;
end;

var tb0159_c: byte;
{$pop}

{ Case tb0289.pp }
{$push}
{ Old file: tbs0341.pp }
{  }

procedure IncLimit(var tb0289_b: Byte; const Limit: Byte; const Incr: Byte);
begin
end;
procedure IncLimit(var tb0289_b: Longint; const Limit: Longint; const Incr: Longint);
begin
end;

var
  tb0289_b : byte;
{$pop}

{ Case tb0352.pp }
{$push}
procedure p(var tb0352_w:word);
begin
end;

var
  tb0352_i : smallint;
{$pop}

begin
  { Case tb0159.pp }
  {$push}
begin
  tb0159_a(boolean(tb0159_c));
end;
  {$pop}

  { Case tb0289.pp }
  {$push}
begin
  inclimit(tb0289_b,128,3);
end;
  {$pop}

  { Case tb0352.pp }
  {$push}
begin
  p(word(tb0352_i));
end;
  {$pop}

end.
