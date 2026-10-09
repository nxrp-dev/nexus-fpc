{ Arrays regression cases; original case IDs are retained below. }

{ Case tw30463.pp }
{$push}
{$mode objfpc}
{$modeswitch arrayoperators}
procedure tw30463_p1;
  var
    tw30463_a: array of Integer;
    tw30463_i: integer;
  begin
    tw30463_a := [];
    tw30463_a := tw30463_a + tw30463_a;
    tw30463_a := Concat(tw30463_a,[123456789]);
    tw30463_a := tw30463_a + [6];
    tw30463_a := tw30463_a + tw30463_a;

    if tw30463_a[0]<>123456789 then
      Halt(1);
    if tw30463_a[High(tw30463_a)]<>6 then
      Halt(1);
  end;

procedure tw30463_p2;
  var
    tw30463_a, tw30463_b, tw30463_c: array of Integer;

    tw30463_i: integer;
  begin
    tw30463_a := [];
    tw30463_a := tw30463_a + tw30463_a + tw30463_a;
    tw30463_a := Concat(tw30463_a,[123456789],[8]);
    tw30463_a := tw30463_a + [6] + tw30463_a;
    tw30463_a := tw30463_a + tw30463_a + tw30463_a;
    tw30463_b:=copy(tw30463_a);
    tw30463_c:=tw30463_b+tw30463_a;

    if tw30463_c[0]<>123456789 then
      Halt(1);
    if tw30463_c[High(tw30463_c)]<>8 then
      Halt(1);
    if tw30463_c[High(tw30463_c)-1]<>123456789 then
      Halt(1);
  end;
{$pop}

{ Case tw41087.pp }
{$push}
{ Strange bug while concatenating TBytes arrays }

{$mode objfpc}
{$modeswitch arrayoperators}

type
  tw41087_tbytes = array of Byte;

function tw41087_u8(v: Byte): tw41087_tbytes;
begin
  SetLength(Result, 1);
  Result[0] := v;
end;

var
  tw41087_r: tw41087_tbytes;
{$pop}

{ Case tw41798.pp }
{$push}
{ Failure in multiple-array concatenation }

{$mode objfpc}
{$modeswitch arrayoperators}

type
  tw41798_tintarr = array of PtrInt;

var
  tw41798_x, tw41798_y: tw41798_tintarr;
{$pop}

begin
  { Case tw30463.pp }
  {$push}

  begin
tw30463_p1;
  tw30463_p2;
  writeln('ok');
  end;
  {$pop}

  { Case tw41087.pp }
  {$push}

  begin
{ three function results in one + chain must not alias the last one }
  tw41087_r := tw41087_u8($11) + tw41087_u8($22) + tw41087_u8($33);
  if (Length(tw41087_r) <> 3) or (tw41087_r[0] <> $11) or (tw41087_r[1] <> $22) or (tw41087_r[2] <> $33) then
    halt(1);
  end;
  {$pop}

  { Case tw41798.pp }
  {$push}

  begin
tw41798_x := [1, 2];
  { the two literal temps must not alias the last one }
  tw41798_y := tw41798_x + [3, 4] + [5, 6];
  if (Length(tw41798_y) <> 6) or
     (tw41798_y[0] <> 1) or (tw41798_y[1] <> 2) or (tw41798_y[2] <> 3) or
     (tw41798_y[3] <> 4) or (tw41798_y[4] <> 5) or (tw41798_y[5] <> 6) then
    halt(1);
  end;
  {$pop}

end.
