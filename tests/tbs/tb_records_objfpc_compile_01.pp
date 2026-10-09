{ Records regression cases; original case IDs are retained below. }
{ %NORUN }

{ Case tw16163.pp }
{$push}
{$mode objfpc}

type
  tw16163_tfcolor = record
    tw16163_b, tw16163_g, tw16163_r : Byte;
    // m : Byte; // uncomment it to avoid InternalError 200301231
  end;

  tw16163_tfcolora = record
    tw16163_c : tw16163_tfcolor;
    tw16163_a : Byte;
    // adding some field here, or changing a type to Word or Integer
    // also fixed the problem.
  end;

function tw16163_fcolortofcolora(tw16163_c : tw16163_tfcolor) : tw16163_tfcolora;
begin
  Result.tw16163_c:=tw16163_c;
  Result.tw16163_a:=255;
end;

var
  tw16163_t : tw16163_tfcolor;
  tw16163_a : tw16163_tfcolor;
{$pop}

{ Case tw39464.pp }
{$push}
{$Mode ObjFPC}

type
  tw39464_ttestrec = packed record
    tw39464_empty: packed record end;
  end;

function tw39464_getemptyptr(R: tw39464_ttestrec): Pointer;
begin
  Result := @R.tw39464_empty;
end;
{$pop}

begin
  { Case tw16163.pp }
  {$push}

  begin
FillChar(tw16163_a, sizeof(tw16163_a), $55);
  tw16163_t:=tw16163_fcolortofcolora(tw16163_a).tw16163_c; // IE 200301231 why?
  if (tw16163_t.tw16163_b<>$55) or
     (tw16163_t.tw16163_r<>$55) or
     (tw16163_t.tw16163_g<>$55) then
    halt(1);
  end;
  {$pop}

end.
