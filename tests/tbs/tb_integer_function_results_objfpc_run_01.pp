{ Integer result-width branches and nested access to Result and parent locals. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

{ Case tb0605.pp }
{$push}
type
  tb0605_aint = longint;

function tb0605_getint64: int64;
begin
  Result := 64;
end;

function tb0605_getlongint: longint;
begin
  Result := 32;
end;

function tb0605_getword: word;
begin
  result := 16;
end;

function tb0605_getbyte: byte;
begin
  result := 8;
end;

function tb0605_getaint: longint;
begin
  result:=4;
  case sizeof(tb0605_aint) of
    8: result:=tb0605_getint64;
    4: result:=tb0605_getlongint;
    2: result:=smallint(tb0605_getword);
    1: result:=shortint(tb0605_getbyte);
  end;
end;
{$pop}

{ Case tb0622.pp }
{$push}
function tb0622_test: longint;

  var
    tb0622_l: longint;

  procedure tb0622_nest;
    begin
      if result<>111 then
        halt(1);
      if tb0622_l<>222 then
        halt(2);
      tb0622_l:=1231;
      result:=555;
    end;

begin
  result:=111;
  tb0622_l:=222;
  tb0622_nest;
  if tb0622_l<>1231 then
    halt(3);
  if result=555 then
    exit;
  result:=666;
end;
{$pop}

begin
  { Case tb0605.pp }
  {$push}
begin
  if tb0605_getaint <> 32 then
    Halt(1);
end;
  {$pop}

  { Case tb0622.pp }
  {$push}
begin
  if tb0622_test<>555 then
    halt(4);
end;
  {$pop}

end.
